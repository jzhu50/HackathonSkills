---
description: Run one complete task — orient from GitHub state, claim one issue, do the work on a feature branch, open a PR, then stop. Triggered by "Go". One context = one task.
allowed-tools: mcp__github__*, Read, Write, Edit, Bash
---

# Skill: hackathon-session

**One context, one task.** This skill runs exactly one task per invocation:
orient → claim one issue → work on a feature branch → open a PR → stop.

When the PR is open, this context ends. The human starts a new session for the next task.
This keeps each agent's context clean and prevents long-running sessions from accumulating
stale state about what other agents are doing.

---

## GitHub MCP — required for all GitHub operations

Every GitHub operation in this skill **must** use the GitHub MCP (`mcp__github__*`).
Do not use the `gh` CLI, `curl`, or any Bash command for GitHub operations the MCP
can handle. Use Bash only for local operations: branching, file edits, running tests.

Make MCP calls **sequentially, not in parallel.** Parallel calls stack at the permission
prompt and require a full retry cycle.

---

## Trigger

A human says something like:
- "Go"
- "Start working"
- "Pick up a task"
- "What should I work on?"
- Any instruction to begin coding on the shared project

---

## Phase 1 — Orient (every session, no exceptions)

### 1a. Load project context
Using the GitHub MCP `get_file_contents`, read sequentially:
1. `AGENTS.md` — the full coordination protocol for this repo
2. `PLAN.md` — vision, stack, features, decisions log

If either file is missing, stop and tell the human.

### 1b. Read current GitHub state
Use the GitHub MCP sequentially, one call at a time:

1. Search for `[Project] Tracking is:open` — read it for project overview
2. List issues with label `in-progress` — know what's actively being worked
3. List issues with label `blocked` — note anything you might unblock
4. List issues with label `ready`, no assignee — your candidate pool
5. List issues with label `needs-scoping`, no assignee — fallback if no `ready` issues

### 1c. Synthesise
State in 2–3 sentences: what is the team building, what's in flight, what you'll work on.
Say this out loud before doing anything.

---

## Phase 2 — Claim one issue

### 2a. Pick
Priority order:
1. Oldest `ready` issue with no assignee — prefer issues that unblock others
2. If none: pick a `needs-scoping` epic and decompose it first (`/hackathon-decompose`)
3. If nothing is ready or needs scoping: check `blocked` — can you resolve the blocker?
4. If genuinely nothing: tell the human, ask them to resolve open questions in tracking

### 2b. Claim — three steps, sequential, no other actions between them
1. Update the issue via the GitHub MCP — add yourself as assignee
2. Update the issue via the GitHub MCP — change label from `ready` → `in-progress`
3. Add a comment via the GitHub MCP:
   `agent: claiming — [your github username] — [ISO timestamp]`

### 2c. Collision check (multi-agent only — skip in single-agent sessions)
Re-read the issue via the GitHub MCP. If there are two assignees or two claiming
comments within 2 minutes: unassign yourself, comment `agent: collision — backing off`,
go back to 2a.

---

## Phase 3 — Work

### 3a. Create a feature branch — before writing any code
```bash
git checkout -b <issue-number>-<short-slug>
# e.g. git checkout -b 12-user-auth-endpoint
```
Never write code on `main`. This branch is what the PR will be based on.

### 3b. Check environment before coding
If the issue involves dependencies or native packages:
- Verify they install cleanly on this machine before writing code that depends on them
- If a dependency fails (e.g. native compilation), create a `[Blocked]` issue before
  continuing — do not silently switch to an alternative without capturing the decision

### 3c. Implement the issue
Reference `PLAN.md` and `SPECS.md` for intent. When in doubt about a design decision,
take the simpler path and document it in an issue comment via the GitHub MCP.

### Capture scope continuously
When you discover work outside this issue's scope, **stop and create an issue via the
GitHub MCP immediately** before continuing:

```
## Parent
#<current issue number>

## Goal
<one sentence starting with a verb>

## Context
<what you found, relevant file paths, decisions already made>
```
Label: `ready` / `needs-scoping` / `blocked` as appropriate.

### Track subtask progress
If the issue has a `## Subtasks` checklist, update it via the GitHub MCP as you go.

### If you get blocked
1. Change label to `blocked` via the GitHub MCP
2. Comment via the GitHub MCP — explain exactly what's blocking you
3. Unassign yourself via the GitHub MCP
4. Return to Phase 2 with a different issue

### PLAN.md is wrong — do NOT edit it inline
If you discover PLAN.md needs updating, **do not modify it in your task branch.**
Two agents editing PLAN.md on different branches = guaranteed merge conflict on the
most critical shared file.

Instead:
1. Create a `[Plan Update] <what changed>` issue via the GitHub MCP, labeled `ready`
2. Add a comment to the `[Project] Tracking` issue describing the proposed change
3. Continue your task with the current PLAN.md — the plan update is its own task

---

## Phase 4 — Close out

**A PR is the only valid close-out path for completed work.**
Never close an issue directly. Never leave completed work on a branch without a PR.

### 4a. Push the branch
```bash
git push -u origin <branch-name>
```

### 4b. Open a PR via the GitHub MCP
- Title: same as the issue title
- Body: `Closes #<issue number>` on its own line, then a summary of what was built
- Base: `main`
- Do not merge it yourself — leave it open for a review session

### 4c. Label the issue `in-review` via the GitHub MCP
`in-review` means exactly one thing: a PR is open and unmerged. Do not use it otherwise.

### 4d. Comment on the issue via the GitHub MCP
```
agent: done — PR #<number> open for review

What was built: <2-3 sentences>
New issues created: <list, or "none">
Reviewers should know: <gotchas, tradeoffs, or "none">
```

### 4e. Stop
This context is done. Tell the human: "PR #<number> is open. Start a new session to
pick up another task, or start a review session to merge this one."

Do not pick up another task in this same context. Start fresh.

---

## If the session ends before work is complete

### Push what exists so it isn't lost
```bash
git push -u origin <branch-name>
```

### Leave breadcrumbs via the GitHub MCP
- Leave issue labeled `in-progress`, yourself as assignee
- Add a comment:
  ```
  agent: session end — work in progress

  Branch: <branch-name>
  Done so far: <what's complete>
  Remaining: <what's left>
  Next agent should: <exact file paths, where to pick up, anything non-obvious>
  ```
- Update the `## Subtasks` checklist in the issue body

---

## If abandoning mid-session

### Push what exists
```bash
git push -u origin <branch-name>
```

### Release the issue via the GitHub MCP
- Unassign yourself, change label back to `ready`
- Add a comment:
  ```
  agent: abandoning — returning to ready

  Branch: <branch-name> (pushed, not merged)
  Reason: <why>
  Code state: <what changed, what's broken>
  Next agent should know: <context that saves them time>
  ```

---

## Rules

- **One task per context.** Stop after the PR. Start fresh for the next task.
- **Never commit to `main` directly.** Create a branch before touching any code.
- **Never close an issue without a PR.** The PR is the audit trail and review gate.
- **`in-review` = PR open and unmerged.** Never apply it in any other situation.
- **Never edit PLAN.md in a task branch.** Create a plan-update issue instead.
- **Never fire MCP calls in parallel.** Sequential only.
- **Never go silent on a blocked issue.** Always comment and move on.
- **Never let discovered scope stay uncaptured.** Issue first, then continue.
- **Never use `gh` CLI or Bash for GitHub operations.** GitHub MCP only.
