---
description: One autonomous work unit — orient, claim the highest-value task or PR review, do the work, close out, then stop. Triggered by "Go". Designed to be called in a loop by run.sh.
allowed-tools: mcp__github__*, Read, Write, Edit, Bash
---

# Skill: hackathon-session

**One context, one unit of work.** This skill is designed to be called repeatedly by
`run.sh` in a tight loop. Each invocation:

1. Reads current GitHub state (fresh — no memory of previous invocations)
2. Routes to the highest-value work: task > review > nothing
3. Does exactly one task or one PR review
4. Closes out and stops

When there is genuinely nothing to do, it outputs `NOTHING_TO_DO` so the loop knows
to wait or exit. Context is automatically cleared between invocations because each
`claude -p "Go"` call is a separate process.

---

## GitHub MCP — required for all GitHub operations

Every GitHub operation **must** use the GitHub MCP (`mcp__github__*`).
Do not use `gh` CLI, `curl`, or Bash for GitHub operations.
Use Bash only for local operations: branching, editing files, running tests.
Make all MCP calls **sequentially, not in parallel.**

---

## Trigger

"Go", "Start working", "Pick up a task", or any instruction to do project work.
In automated mode this trigger comes from `run.sh` — the agent should proceed
immediately without asking for clarification.

---

## Phase 1 — Orient

Read sequentially via the GitHub MCP:
1. `AGENTS.md` — coordination protocol
2. `PLAN.md` — vision, stack, done criteria

Then, sequentially via the GitHub MCP:
1. Search `[Project] Tracking is:open` — project overview
2. List `in-progress` issues — what's being worked right now
3. List `blocked` issues — anything you might unblock
4. List `ready` issues, no assignee — task candidates
5. List `needs-scoping` issues, no assignee — decomposition candidates
6. List `in-review` issues — PR reviews waiting

Synthesise: what is the team building, what's in flight, what is the most valuable
thing to do right now? State this in 2–3 sentences before acting.

---

## Phase 2 — Route to work

Choose one path and follow it. Do not attempt more than one unit of work per invocation.

**Priority order:**

### Path A — Do a task (highest priority)

Condition: there is at least one `ready` issue with no assignee.

Pick the oldest `ready` issue, or one that unblocks other work.

**Before claiming:** check issue comments. If the issue has a comment of the form
`agent: review — changes requested. Branch: <branch>. PR: #<n>`, this is a
"fix review feedback" task — go to Path A2. Otherwise proceed to Path A1.

**Path A1 — New task**

1. Claim the issue (three sequential MCP calls, no other actions between):
   - Add yourself as assignee
   - Change label `ready` → `in-progress`
   - Comment: `agent: claiming — [github username] — [ISO timestamp]`

2. Collision check (multi-agent only — skip in single-agent sessions):
   Re-read the issue. Two assignees or two claiming comments within 2 minutes
   → unassign, comment `agent: collision — backing off`, pick a different issue.

3. Create a feature branch before writing any code:
   ```bash
   git checkout -b <issue-number>-<short-slug>
   ```

4. Check environment: if the issue involves native packages or build tools,
   verify they install cleanly before writing any code that depends on them.
   If a dependency fails, create a `blocked` issue before continuing.

5. Implement the issue. Reference `PLAN.md` and `SPECS.md` for intent. When a
   design decision is unclear, take the simpler path and document it in an issue
   comment via the GitHub MCP.

6. Capture any discovered scope immediately — create an issue before continuing:
   ```
   ## Parent
   #<current issue number>
   ## Goal
   <one sentence>
   ## Context
   <what you found>
   ```
   Label: `ready` / `needs-scoping` / `blocked`.

7. If you get blocked:
   - Change label to `blocked` via the GitHub MCP
   - Comment explaining exactly what's blocking you
   - Unassign yourself
   - Go back to Phase 2 and pick a different issue

8. Close out → go to Phase 3.

**Path A2 — Fix review feedback**

The issue was returned from review with specific changes requested. The previous
PR is still open and needs more commits.

1. Claim the issue (same three-step sequence as Path A1).

2. Check out the existing branch (name is in the "changes requested" comment):
   ```bash
   git fetch origin
   git checkout <branch-name>
   ```

3. Read the PR review comments via the GitHub MCP:
   - Get the PR number from the issue comment
   - Read all review comments on the PR
   - Treat each review comment as a specific requirement to satisfy

4. Implement the requested changes. Do not re-implement the whole feature —
   address only what the review identified.

5. Push the branch (the existing PR auto-updates — do not open a new PR):
   ```bash
   git push origin <branch-name>
   ```

6. Comment on the PR via the GitHub MCP:
   `agent: changes implemented — re-requesting review`

7. Change the issue label back to `in-review` via the GitHub MCP.

8. Comment on the issue via the GitHub MCP:
   ```
   agent: review feedback implemented

   Branch: <branch-name>
   PR: #<pr-number>
   Changes made: <what was fixed, one line per review comment addressed>
   ```

9. Stop. Do not merge — leave for a review session.

### Path B — Decompose an epic (if no ready tasks)

Condition: no `ready` issues, but there are `needs-scoping` issues.

Invoke `/hackathon-decompose` or follow the hackathon-decompose skill steps directly.
After decomposition, the new `ready` tasks will be picked up in the next invocation.
Stop after decomposition — do not claim a task in the same invocation.

### Path C — Do a PR review (if no tasks and no epics to decompose)

Condition: no `ready` issues, no `needs-scoping` issues, but there are `in-review` PRs.

Follow the hackathon-review skill steps exactly. Stop after the review.

### Path D — Nothing to do

Condition: no `ready` issues, no `needs-scoping` issues, no `in-review` PRs.

Report current state briefly (how many issues are `in-progress`, how many are
`blocked`, etc.). Then output exactly:

```
NOTHING_TO_DO
```

The run script uses this signal to decide whether to wait or exit.

---

## Phase 3 — Close out a task

**A PR is the only valid close-out path for completed work.**
Never close an issue directly. Never leave completed work without a PR.

1. Push the feature branch:
   ```bash
   git push -u origin <branch-name>
   ```

2. Open a PR via the GitHub MCP:
   - Title: same as the issue title
   - Body: `Closes #<issue number>` on its own line, then a 2–3 sentence summary
   - Base: `main`
   - Do not merge yourself

3. Change the issue label to `in-review` via the GitHub MCP.
   (`in-review` = PR open and unmerged. No other meaning.)

4. Comment on the issue via the GitHub MCP:
   ```
   agent: done — PR #<number> open for review

   Branch: <branch-name>
   What was built: <2–3 sentences>
   New issues created: <list or "none">
   Reviewers should know: <gotchas or "none">
   ```

5. If `PLAN.md` needs updating, create a `[Plan Update] <description>` issue
   labeled `ready` and comment on the tracking issue. Never modify `PLAN.md` in
   a task branch — it causes merge conflicts during parallel work.

6. Stop. Output nothing else. The loop will invoke a new session for the next task.

---

## Phase 4 — Session ended before work is complete

Push what exists so it isn't lost:
```bash
git push -u origin <branch-name>
```

Leave the issue `in-progress`, yourself as assignee. Comment via the GitHub MCP:
```
agent: session end — work in progress

Branch: <branch-name>
Done so far: <what's complete>
Remaining: <what's left>
Next agent should: <file paths, where to pick up, anything non-obvious>
```

Update the `## Subtasks` checklist if the issue has one.

---

## Rules

- **One unit of work per invocation.** Stop after Phase 3 or after Phase C/D.
- **Never commit to `main` directly.** Branch first, always.
- **Never close an issue without a PR.** The PR is the audit trail.
- **`in-review` = PR open and unmerged.** Never apply it any other way.
- **Never edit `PLAN.md` in a task branch.** Create a plan-update issue instead.
- **Never fire MCP calls in parallel.** Sequential only.
- **Never go silent on a blocked issue.** Always comment and move on.
- **Never let discovered scope stay uncaptured.** Issue first, then continue.
- **Never use `gh` CLI or Bash for GitHub operations.** GitHub MCP only.
