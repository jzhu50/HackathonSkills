# Agent Coordination Protocol

This file is the source of truth for how agents coordinate on this project.
All agent skills reference it. If you are not using Claude Code, read this file
in full as your system prompt before starting any session.

---

## Mental model

GitHub is the team's shared brain. You have no memory between sessions — GitHub does.
Every session starts by reading state from GitHub. Every session ends by writing state
back to GitHub. A teammate's agent (or your own, in a new context) will reconstruct
everything from what you leave behind.

The coordination primitives are:
- **Issues** = units of work
- **Labels** = issue state machine
- **Assignees** = who is working on what right now
- **Comments** = handoff notes, status updates, blockers, rationale
- **PRs** = the only valid close-out path for completed work
- **PLAN.md** = the living project brain (never modified during parallel work)
- **SPECS.md** = implementation detail

---

## One context, one task

Each agent session handles exactly one unit of work — one task or one PR review —
then stops. The human starts a new session for the next unit.

This keeps each context fresh (no stale state about what other agents did an hour ago),
makes parallel agents safe (each works on its own branch), and produces a clean
record of what each session accomplished.

**Never pick up a second task in the same context.**

---

## GitHub MCP — required for all GitHub operations

Use the **GitHub MCP** (`mcp__github__*`) for every GitHub operation:
reading and writing issues, labels, assignees, comments, and pull requests.

Do **not** use `gh`, `curl`, the GitHub REST API directly, or any Bash command for
GitHub operations the MCP can handle.

Make MCP calls **sequentially, not in parallel.** Parallel calls stack at the
permission prompt and require a full retry cycle.

---

## Label states

| Label | Meaning |
|---|---|
| `needs-scoping` | Too large or unclear to start — must be decomposed into tasks first |
| `ready` | Scoped, unblocked, no assignee — available to claim |
| `in-progress` | Actively being worked — has an assignee |
| `blocked` | Cannot proceed — comment on the issue explains why |
| `in-review` | PR is open and unmerged — waiting for a review session |
| `epic` | Parent container — work happens in child task issues |
| `bug` | Something is broken |

An issue has exactly one of: `needs-scoping`, `ready`, `in-progress`, `blocked`, `in-review`.
`epic` and `bug` are additive.

`in-review` means exactly one thing: a PR is open and unmerged. Do not apply this label
in any other situation. GitHub auto-removes it (by closing the issue) when the PR merges.

---

## Branch per issue — always

Every issue gets its own branch created before any code is written:
```bash
git checkout -b <issue-number>-<short-slug>
```

Never commit to `main` directly. With branch protection enabled on `main`
(recommended — Settings → Branches → require PR before merging), direct pushes will
be rejected automatically.

---

## Claiming an issue

Do all three steps **sequentially** via the GitHub MCP, with no other actions between them:

1. Assign yourself + change label to `in-progress`
2. Comment: `agent: claiming — [your github username] — [ISO timestamp]`

**Collision check (multi-agent concurrent sessions only):** Re-read the issue. Two
assignees or two claiming comments within 2 minutes = collision. Unassign, comment
`agent: collision — backing off`, pick a different issue.

---

## PLAN.md during parallel work

**Never modify PLAN.md in a task branch.** Two agents editing PLAN.md on separate
branches guarantees a merge conflict on the most critical shared file.

If your work reveals PLAN.md is wrong or incomplete:
1. Create a `[Plan Update] <description>` issue via the GitHub MCP, labeled `ready`
2. Add a comment to the `[Project] Tracking` issue describing the proposed change
3. Continue with the current PLAN.md — the update is its own sequential task

---

## Capturing scope during work

When you discover work outside your current issue, create an issue via the GitHub MCP
before continuing:

- Title: `[#parent] short imperative description`
- Body: parent reference, goal, context, acceptance criteria
- Label: `ready` / `needs-scoping` / `blocked` as appropriate

---

## Closing out a task

**A PR is the only valid close-out path.**

1. Push the feature branch
2. Open a PR via the GitHub MCP — body must include `Closes #<n>` on its own line
3. Change issue label to `in-review` via the GitHub MCP
4. Comment on the issue: what was built, PR number, new issues created, reviewer notes
5. Stop — do not pick up another task in this context

**Do not close the issue manually.** GitHub closes it automatically on merge.

---

## Session ending with work unfinished

1. Push the branch
2. Leave the issue `in-progress`, yourself as assignee
3. Comment via the GitHub MCP: branch name, what's done, what's left, exactly where to pick up

---

## Security notes

**PAT scope:** A personal access token covers all repos the account can access, not
just this one. Use fine-grained PATs scoped to this repo if your GitHub plan supports it.

**CLAUDE.md is agent-editable:** An agent with write access can modify `CLAUDE.md` and
`.claude/commands/`, rewriting skill instructions. Treat changes to these files in PRs
with the same scrutiny as code changes.

**Allowlist scope:** `mcp__github__*` covers all GitHub MCP tools, including destructive
ones. Review what your MCP server exposes and tighten the allowlist if possible.

---

## Non-Claude Code setup

If your agent CLI does not auto-load files from the repo, paste this file as a system
prompt before starting. Also paste the relevant skill file as additional context.

---

## Bootstrap

Run the bootstrap script from the hackathon skills repo root before starting Claude Code:

- **Windows:** `.\make-claude-md.ps1` (or `.\make-claude-md.ps1 C:\path\to\project`)
- **Mac/Linux:** `./make-claude-md.sh` (or `./make-claude-md.sh /path/to/project`)

The script:
1. Copies each skill into `.claude/commands/` → slash commands (`/hackathon-setup`,
   `/hackathon-session`, `/hackathon-decompose`, `/hackathon-review`)
2. Generates `CLAUDE.md` at the project root
3. Generates `.claude/settings.json` with `mcp__github__*` pre-approved

For other agent CLIs, paste `AGENTS.md` as a system prompt instead of running the script.
