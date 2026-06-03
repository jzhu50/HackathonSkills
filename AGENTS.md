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

Run these steps every session before touching any code:

1. Read `PLAN.md` — understand vision, stack, current goals
2. Read `SPECS.md` if it exists — data models, API contracts, UI flows
3. Search for `[Project] Tracking is:open` — fast overview of epics and open questions
4. List `in-progress` issues — know what teammates are actively doing
5. List `blocked` issues — scan for anything you might unblock
6. List `ready` issues with no assignee — your candidate pool
7. Synthesise: state out loud what the team is building and what you'll work on

---

## Claiming an issue

**Both steps immediately, back to back:**
1. Assign yourself + change label to `in-progress`
2. Comment: `agent: claiming — [your github username] — [ISO timestamp]`

**Then verify:** re-read the issue. Two assignees or two claiming comments within
2 minutes = collision. Back off: unassign, comment `agent: collision — backing off`,
pick a different issue.

Never start coding without completing this sequence.

---

## Creating issues during work

When you discover scope that isn't captured, create an issue before continuing:

- Title: `[#parent] short imperative description`
- Body: parent reference, goal, context, acceptance criteria
- Label: `ready` / `needs-scoping` / `blocked` as appropriate

---

## Closing out

**Work finished:**
- Open PR with `Closes #<n>` in body
- Change label to `in-review`
- Comment: what was built, PR number, new issues created, anything reviewers need to know

**Session ending, work unfinished:**
- Stay assigned, label stays `in-progress`
- Comment: what's done, what's left, exactly where to pick up

**Abandoning an issue:**
- Unassign, change label back to `ready`
- Comment: why, what state the code is in, what the next agent needs to know

---

## Updating PLAN.md

If your work reveals that `PLAN.md` is wrong or incomplete, update it and add a row
to the Decisions Log. Never let the plan drift silently from the code.

---

## Non-Claude Code setup

If your agent CLI does not auto-load this file, paste the contents into your agent
as a system prompt before starting. The session skill (`hackathon-session.md` in
your skills repo) will instruct you to read this file — that instruction is your cue.
