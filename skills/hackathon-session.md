---
description: Run a full working session — orient from GitHub state, claim an issue, do the work, capture new scope, close out. Triggered by "Go".
allowed-tools: mcp__github__*, Read, Write, Edit, Bash
---

# Skill: hackathon-session

Use this skill at the start of every working session. It covers the full loop:
orient → claim → work → capture new scope → close out. Applies to any agent on
any teammate's machine. GitHub is the source of truth — this skill tells you how
to read and write it correctly so the team stays in sync.

---

## GitHub MCP — required for all GitHub operations

Every GitHub operation in this skill **must** use the GitHub MCP (`mcp__github__*`):
reading issues, writing issues, adding labels, assigning, commenting, opening PRs.

Do not use the `gh` CLI, `curl`, or any Bash command for GitHub operations the MCP
can handle. Use Bash only for local code operations: branching, editing files, running
tests. Never use Bash to interact with GitHub.

---

## Trigger

A human says something like:
- "Go"
- "Start working"
- "Pick up where we left off"
- "Continue the project"
- "What should I work on?"
- Any instruction to begin coding on the shared project

---

## Phase 1 — Orient (do this every session, no exceptions)

### 1a. Load project context
Read these files using the GitHub MCP `get_file_contents` tool:
1. `AGENTS.md` — the full coordination protocol for this repo
2. `PLAN.md` — vision, stack, features, decisions log

If either file is missing, stop and tell the human. The repo was not set up correctly.

### 1b. Read current project state
Use the GitHub MCP in this order. Make these calls **one at a time** — parallel MCP
calls can stack at the permission prompt and require a full retry:

1. **Find the tracking issue** — search for `[Project] Tracking is:open`
   Read it for a fast overview of epics and open questions.

2. **What's in flight** — list issues with label `in-progress`
   Know what teammates are actively doing. Do not duplicate their work.

3. **What's stuck** — list issues with label `blocked`
   Scan comments. If anything is blocked on work you're about to do, note it —
   you may be able to unblock it as a side effect.

4. **What's available** — list issues with label `ready`, no assignee
   These are your candidates. Sort by creation date (oldest first = highest priority)
   unless a milestone or explicit priority label says otherwise.

5. **What needs decomposing** — list issues with label `needs-scoping`, no assignee
   If there are no `ready` issues, you will decompose one of these instead.

### 1c. Synthesise before acting
Before touching anything, form a clear picture:
- What is the team trying to ship?
- What is actively being worked on right now?
- What is the most valuable thing I can do this session?

State this out loud (in your response to the human) in 2-3 sentences before proceeding.

---

## Phase 2 — Claim your work

### 2a. Pick an issue
Priority order:
1. A `ready` issue with no assignee — prefer oldest, prefer issues that unblock others
2. If none: pick a `needs-scoping` epic and decompose it (invoke `/hackathon-decompose`
   or follow the hackathon-decompose skill instructions directly)
3. If nothing is ready or needs scoping: check `blocked` issues — can you resolve any blocker?
4. If genuinely nothing to do: tell the human and ask them to resolve open questions in the
   tracking issue

### 2b. Claim atomically
Do all three immediately, in order, with no other actions between them.
Make each MCP call sequentially (not in parallel):

1. Update the issue via the GitHub MCP — add yourself as assignee
2. Update the issue via the GitHub MCP — change label from `ready` → `in-progress`
3. Add a comment via the GitHub MCP — post exactly:
   `agent: claiming — [your github username] — [ISO timestamp]`

### 2c. Check for collision
**Only relevant when multiple agents are running concurrently from different machines.**
In a single-agent session, skip this step.

If running in a multi-agent scenario: re-read the issue via the GitHub MCP after claiming.
If there are **two assignees** or **two claiming comments within 2 minutes of each other**:
- Remove yourself as assignee via the GitHub MCP
- Comment via the GitHub MCP: `agent: collision detected — backing off`
- Return to step 2a and pick a different issue

---

## Phase 3 — Work

### 3a. Create a feature branch — do this before writing a single line of code

```bash
git checkout -b <issue-number>-<short-slug>
# e.g. git checkout -b 7-login-endpoint
```

Never write code on `main`. Every issue gets its own branch. This is non-negotiable —
the PR at close-out requires a branch that isn't `main`.

### 3b. Implement the issue

Implement what the issue describes. Reference `PLAN.md` and `SPECS.md` for intent.
Use `get_file_contents` (GitHub MCP) to read repo files if needed; use local file
tools or Bash to write and test code. When in doubt about a design decision, make the
simpler choice and note it in a comment on the issue via the GitHub MCP.

### Capture scope continuously
Any time you discover work that isn't in the current issue, **stop and create an issue
via the GitHub MCP immediately** before continuing. Do not hold it in your head.

New issue labels:
- `needs-scoping` — large, unclear, multiple sessions of work
- `ready` — small, concrete, could be done in one session
- `blocked` — depends on something not yet done; add comment: `blocked-by: #<issue number>`

New issue body must include:
```
## Parent
#<current issue number>

## Goal
<one sentence: what does done look like?>

## Context
<what you discovered, relevant file paths, any decisions already made>
```

### Track subtask progress
If the issue has a `## Subtasks` checklist, update the issue body via the GitHub MCP
as you go. Teammates can see your progress without asking.

### If you get blocked
1. Change label to `blocked` via the GitHub MCP
2. Add a comment via the GitHub MCP — explain exactly what's blocking you, reference any related issue
3. Unassign yourself via the GitHub MCP
4. Return to Phase 2 and claim a different issue
5. Never sit idle on a blocked issue

---

## Phase 4 — Close out

### When the work is done

A PR is the **only** valid close-out path for completed work. Never close an issue
directly, and never leave completed work uncommitted on a branch without a PR.

1. Push the feature branch:
   ```bash
   git push -u origin <branch-name>
   ```

2. Open a PR via the GitHub MCP:
   - Title: same as the issue title
   - Body must include `Closes #<issue number>` on its own line (GitHub auto-closes
     the issue and removes labels when the PR merges)
   - Base: `main` (or whatever the default branch is)

3. Change the issue label to `in-review` via the GitHub MCP.
   `in-review` means exactly one thing: a PR is open and unmerged.
   Do not apply this label in any other situation.

4. Add a comment via the GitHub MCP on the issue:
   ```
   agent: done — PR #<number> open for review

   What was built: <2-3 sentences>
   New issues created: <list any, or "none">
   Anything reviewers should know: <gotchas, tradeoffs, or "none">
   ```

5. If the work revealed that `PLAN.md` is wrong or incomplete, update it now via the
   GitHub MCP `create_or_update_file` tool. Add a row to the Decisions Log with today's date.

6. **Do not manually close the issue.** GitHub closes it automatically when the PR
   merges. If you merge the PR yourself (solo or agreed team policy), confirm the issue
   closed and the branch was deleted. If waiting for human review, move on to your
   next issue.

### When the session ends but work is unfinished

1. Push the branch so it isn't lost:
   ```bash
   git push -u origin <branch-name>
   ```
2. Leave the issue labeled `in-progress`, leave yourself as assignee
3. Add a comment via the GitHub MCP:
   ```
   agent: session end — work in progress

   Branch: <branch-name>
   Done so far: <what's complete>
   Remaining: <what's left>
   Next agent should: <exactly where to pick up, file paths, anything non-obvious>
   ```
4. Update the `## Subtasks` checklist in the issue body via the GitHub MCP

### When abandoning an issue (switching to something else mid-session)

1. Push the branch so work isn't lost:
   ```bash
   git push -u origin <branch-name>
   ```
2. Remove yourself as assignee and change label back to `ready` via the GitHub MCP
3. Add a comment via the GitHub MCP:
   ```
   agent: abandoning — returning to ready

   Branch: <branch-name> (work pushed, not merged)
   Reason: <why>
   State left in: <what if anything was changed in the codebase>
   Next agent should know: <any context that will save them time>
   ```

---

## Rules (never break these)

- **Never commit to `main` directly.** Create a branch before touching any code.
- **Never close an issue without a PR.** The PR is the audit trail and the review gate.
- **Never label an issue `in-review` unless a PR is actually open and unmerged.**
- **Never start work without completing the claim sequence.** Collisions waste everyone's time.
- **Never go silent on a blocked issue.** Always comment and move on.
- **Never let discovered scope stay uncaptured.** Create the issue before continuing.
- **Never assume another agent's in-progress issue is abandoned.** Check the comments first.
- **Never update PLAN.md silently.** Always note what changed and why in the Decisions Log.
- **Never use Bash/gh CLI for GitHub operations.** Use the GitHub MCP for all of them.
- **Never fire multiple MCP calls in parallel.** Make them sequentially to avoid permission prompt storms.
