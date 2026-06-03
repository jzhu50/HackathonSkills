# Skill: hackathon-session

Use this skill at the start of every working session. It covers the full loop:
orient → claim → work → capture new scope → close out. Applies to any agent on
any teammate's machine. GitHub is the source of truth — this skill tells you how
to read and write it correctly so the team stays in sync.

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
Read these files with `get_file_contents`:
1. `AGENTS.md` — the full coordination protocol for this repo
2. `PLAN.md` — vision, stack, features, decisions log

If either file is missing, stop and tell the human. The repo was not set up correctly.

### 1b. Read current project state
Use the GitHub MCP in this order:

1. **Find the tracking issue** — `search_issues` query: `[Project] Tracking is:open`
   Read it for a fast overview of epics and open questions.

2. **What's in flight** — `list_issues` with label `in-progress`
   Know what teammates are actively doing. Do not duplicate their work.

3. **What's stuck** — `list_issues` with label `blocked`
   Scan comments. If anything is blocked on work you're about to do, note it —
   you may be able to unblock it as a side effect.

4. **What's available** — `list_issues` with label `ready`, no assignee
   These are your candidates. Sort by creation date (oldest first = highest priority)
   unless a milestone or explicit priority label says otherwise.

5. **What needs decomposing** — `list_issues` with label `needs-scoping`, no assignee
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
2. If none: pick a `needs-scoping` epic and decompose it (see hackathon-decompose skill)
3. If nothing is ready or needs scoping: check `blocked` issues — can you resolve any blocker?
4. If genuinely nothing to do: tell the human and ask them to resolve open questions in the
   tracking issue

### 2b. Claim atomically
Do both of these immediately, back to back, with no other actions in between:

1. `issue_write` method `update` — add yourself as assignee
2. `issue_write` method `update` — change label from `ready` → `in-progress`
3. `add_issue_comment` — post exactly:
   `agent: claiming — [your github username] — [ISO timestamp]`

### 2c. Check for collision
After claiming, wait one moment then re-read the issue with `issue_read` method `get`.

If there are **two assignees** or **two claiming comments within 2 minutes of each other**:
- Remove yourself as assignee (`issue_write` update, set assignees to remove yourself)
- Comment: `agent: collision detected — backing off`
- Return to step 2a and pick a different issue

---

## Phase 3 — Work

### Do the work
Implement what the issue describes. Reference `PLAN.md` and `SPECS.md` for intent.
When in doubt about a design decision, make the simpler choice and note it in a comment.

### Capture scope continuously
Any time you discover work that isn't in the current issue, **stop and create an issue
immediately** before continuing. Do not hold it in your head.

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
If the issue has a `## Subtasks` checklist, update it as you go using `issue_write`
method `update` to edit the body. Teammates can see your progress without asking.

### If you get blocked
1. `issue_write` — change label to `blocked`
2. `add_issue_comment` — explain exactly what's blocking you, reference any related issue
3. Unassign yourself
4. Return to Phase 2 and claim a different issue
5. Never sit idle on a blocked issue

---

## Phase 4 — Close out

### When the work is done

1. Open a PR with `create_pull_request`:
   - Title: same as the issue title
   - Body must include `Closes #<issue number>` on its own line
   - Base: main (or whatever the default branch is)

2. `issue_write` method `update` — change label to `in-review`

3. `add_issue_comment` on the issue:
   ```
   agent: done
   
   What was built: <2-3 sentences>
   PR: #<pr number>
   New issues created: <list any, or "none">
   Anything reviewers should know: <gotchas, tradeoffs, or "none">
   ```

4. If the work revealed that `PLAN.md` is wrong or incomplete, update it now using
   `create_or_update_file`. Add a row to the Decisions Log with today's date.

### When the session ends but work is unfinished

1. Leave the issue labeled `in-progress`, leave yourself as assignee
2. `add_issue_comment`:
   ```
   agent: session end — work in progress
   
   Done so far: <what's complete>
   Remaining: <what's left>
   Next agent should: <exactly where to pick up, file paths, anything non-obvious>
   ```
3. Update the `## Subtasks` checklist in the issue body to reflect current state

### When abandoning an issue (switching to something else mid-session)

1. `issue_write` — remove yourself as assignee, change label back to `ready`
2. `add_issue_comment`:
   ```
   agent: abandoning — returning to ready
   
   Reason: <why>
   State left in: <what if anything was changed in the codebase>
   Next agent should know: <any context that will save them time>
   ```

---

## Rules (never break these)

- **Never start work without completing the claim sequence.** Collisions waste everyone's time.
- **Never go silent on a blocked issue.** Always comment and move on.
- **Never let discovered scope stay uncaptured.** Create the issue before continuing.
- **Never assume another agent's in-progress issue is abandoned.** Check the comments first.
- **Never update PLAN.md silently.** Always note what changed and why in the Decisions Log.
