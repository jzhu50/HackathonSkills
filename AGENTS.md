# Agent Coordination Protocol

This file is the source of truth for how agents coordinate on this project.
All agent skills reference it. If you are not using Claude Code, read this file
in full as your system prompt before starting any session.

---

## Mental model

GitHub is the team's shared brain. You have no memory between sessions — GitHub does.
Every session starts by reading state from GitHub. Every session ends by writing state
back to GitHub. A teammate's agent (or your own, tomorrow) will reconstruct everything
it needs from what you leave behind.

The coordination primitives are:
- **Issues** = units of work
- **Labels** = issue state
- **Assignees** = who is working on what right now
- **Comments** = handoff notes, status updates, blockers, rationale
- **PLAN.md** = the living project brain
- **SPECS.md** = implementation detail

---

## GitHub MCP — required for all GitHub operations

Use the **GitHub MCP** (`mcp__github__*`) for every GitHub operation:
reading and writing issues, labels, assignees, comments, and pull requests.

Do **not** use `gh`, `curl`, the GitHub REST API directly, or any Bash command for
GitHub operations the MCP can handle. GitHub MCP calls are attributable and auditable;
ad-hoc CLI calls break the team's shared state.

This applies everywhere: session start, claiming, scope capture, close-out, and any
time you interact with GitHub.

---

## Label states

| Label | Meaning |
|---|---|
| `needs-scoping` | Too large or unclear to start — must be decomposed into tasks first |
| `ready` | Scoped, unblocked, no assignee — available to claim |
| `in-progress` | Actively being worked on — has an assignee |
| `blocked` | Cannot proceed — comment on the issue explains why |
| `in-review` | PR is open, waiting for review or merge |
| `epic` | Parent container — work happens in child task issues |
| `bug` | Something is broken |

An issue has exactly one of: `needs-scoping`, `ready`, `in-progress`, `blocked`, `in-review`.
`epic` and `bug` are additive — an epic can also be `in-progress`, a bug can be `ready`, etc.

---

## Session start sequence

Run these steps every session before touching any code.
All GitHub reads use the GitHub MCP.

1. Read `PLAN.md` via the GitHub MCP — understand vision, stack, current goals
2. Read `SPECS.md` via the GitHub MCP if it exists — data models, API contracts, UI flows
3. Search for `[Project] Tracking is:open` via the GitHub MCP — fast overview of epics and open questions
4. List `in-progress` issues via the GitHub MCP — know what teammates are actively doing
5. List `blocked` issues via the GitHub MCP — scan for anything you might unblock
6. List `ready` issues with no assignee via the GitHub MCP — your candidate pool
7. Synthesise: state out loud what the team is building and what you'll work on

---

## Claiming an issue

All claim steps use the GitHub MCP. Do all three immediately, in order:

1. Assign yourself + change label to `in-progress` — via the GitHub MCP
2. Comment: `agent: claiming — [your github username] — [ISO timestamp]` — via the GitHub MCP

**Then verify via the GitHub MCP:** re-read the issue. Two assignees or two claiming comments
within 2 minutes = collision. Back off: unassign, comment `agent: collision — backing off`,
pick a different issue.

Never start coding without completing this sequence.

---

## Creating issues during work

When you discover scope that isn't captured, create an issue via the GitHub MCP before continuing:

- Title: `[#parent] short imperative description`
- Body: parent reference, goal, context, acceptance criteria
- Label: `ready` / `needs-scoping` / `blocked` as appropriate

---

## Closing out

All close-out steps use the GitHub MCP.

**Work finished:**
- Open PR via the GitHub MCP with `Closes #<n>` in body
- Change label to `in-review` via the GitHub MCP
- Comment via the GitHub MCP: what was built, PR number, new issues created, anything reviewers need to know

**Session ending, work unfinished:**
- Stay assigned, label stays `in-progress`
- Comment via the GitHub MCP: what's done, what's left, exactly where to pick up

**Abandoning an issue:**
- Unassign, change label back to `ready` via the GitHub MCP
- Comment via the GitHub MCP: why, what state the code is in, what the next agent needs to know

---

## Updating PLAN.md

If your work reveals that `PLAN.md` is wrong or incomplete, update it via the GitHub MCP
and add a row to the Decisions Log. Never let the plan drift silently from the code.

---

## Non-Claude Code setup

If your agent CLI does not auto-load files from the repo, paste this file as a system
prompt before starting. Also paste the relevant skill file (hackathon-session, etc.)
as additional context. The session skill will instruct your agent to read this file —
that instruction is your cue.

---

## Bootstrap

Run the bootstrap script from the hackathon skills repo root before starting Claude Code:

- **Windows:** `.\make-claude-md.ps1` (or `.\make-claude-md.ps1 C:\path\to\project`)
- **Mac/Linux:** `./make-claude-md.sh` (or `./make-claude-md.sh /path/to/project`)

The script:
1. Copies each skill from `skills/` into `.claude/commands/` — these become Claude Code
   slash commands (`/hackathon-setup`, `/hackathon-session`, `/hackathon-decompose`)
2. Generates `CLAUDE.md` at the project root with the coordination context and GitHub MCP
   instructions, so Claude Code loads them automatically on startup

For other agent CLIs, paste `AGENTS.md` as a system prompt instead of running the script.
