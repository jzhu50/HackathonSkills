---
description: Loop through all ai-approved tasks — claim, test, implement, debug if needed, optionally pause for human approval, open PR, optionally auto-review and merge. Runs until no ai-approved tasks remain. Context grows across tasks.
allowed-tools: mcp__github__*, Read, Write, Edit, Bash
---

# Skill: hackathon-session

**One growing context, all ai-approved tasks.** This skill orients once, then loops:
claim an `ai-approved` task → run baseline tests → implement → run tests throughout →
debug if tests fail unexpectedly → apply task_completion gate → open PR → apply
code_review gate → repeat until no tasks remain.

Gate behavior depends on `hackathon.config.yml`.

---

## GitHub MCP — required for all operations

Every GitHub operation **must** use the GitHub MCP (`mcp__github__*`).
Do not use `gh` CLI, `curl`, or Bash for anything the MCP can handle.
Make all MCP calls **sequentially, not in parallel.**

---

## Trigger

"Go", "Work on tasks", "Start implementing", or any instruction to do project work.

---

## Phase 0 — Read config

Read `hackathon.config.yml`. Extract and hold for the entire session:
- `gates.task_completion.human_required` (default: `true`)
- `gates.code_review.human_required` (default: `true`)
- `quality.testing` (default: `required`)
- `quality.comments` (default: `verbose`)

---

## Phase 1 — Orient (once, at session start)

**Git sync:**
```bash
CURRENT_BRANCH=$(git branch --show-current)
if [ -n "$CURRENT_BRANCH" ] && [ "$CURRENT_BRANCH" != "main" ] && [ -n "$(git status --porcelain)" ]; then
  git add -A && git commit -m "agent: checkpoint — session restart" || true
  git push -u origin "$CURRENT_BRANCH" || true
fi
# Note: if CURRENT_BRANCH is empty (detached HEAD), skip — cannot push to a detached HEAD.
git fetch origin && git remote prune origin
git checkout main && git merge --ff-only origin/main
```

If `--ff-only` fails: local main diverged. Comment on the tracking issue and stop.

Read sequentially via the GitHub MCP:
1. `AGENTS.md` — coordination protocol
2. `PLAN.md` — vision, stack, done criteria (note the Test command row)

**Dependency unblock sweep:** For each `blocked` issue, check if every issue in its
`## Blocked By` section is now closed. If all are closed, **remove the `blocked` label**
(keep `needs-human-review` if present — do not add or change it). Comment:
`agent: dependency closed — removed blocked label, awaiting human review`.

---

## Phase 2 — Task loop

Repeat until no `ai-approved` tasks remain:

### Step 1 — Find and claim a task

List all `ai-approved` issues with no assignee via the GitHub MCP.

**Special routing by issue content:**

| Signal | Type | Action |
|---|---|---|
| Comment `agent: merge conflict` | Merge conflict | Path R — rebase |
| Comment `agent: review — changes requested` | Fix feedback | Path F — fix feedback |
| Label `bug` | Bug fix | Call hackathon-debug |
| Verify task title | Verify epic | Call hackathon-verify |
| None of the above | New task | Path N — new task |

Pick **at random** from the available issues — not the oldest.

**Claim the chosen issue** (three sequential MCP calls, no other actions between):
1. Add yourself as assignee
2. Change label `ai-approved` → `in-progress`
3. Comment: `agent: claiming — [github username] — [ISO timestamp]`

**Collision check:** re-read the issue. Two assignees or two claiming comments
within 2 minutes → both back off: unassign, reset label `in-progress` → `ai-approved`,
comment `agent: collision — backing off`, pick a different issue.

---

### Path N — New task

#### N1. Sync to the epic branch and create task branch

Read the task's `## Context` section to find the epic branch name (`epic-<n>-<slug>`).

```bash
git fetch origin
git checkout epic-<n>-<slug>
git merge --ff-only origin/epic-<n>-<slug>
git checkout -b <issue-number>-<short-slug> 2>/dev/null || git checkout <issue-number>-<short-slug>
```

If the epic branch does not exist locally or remotely: comment on the task that the
epic branch is missing, change label to `blocked`, unassign, and continue to the
next issue.

#### N2. Run baseline tests

**If `testing: skip`:** skip this step entirely. Record baseline as "skipped".

**Otherwise:** before writing any code, run the full test suite:

```bash
<test command from PLAN.md>
```

Call `hackathon-test` with mode `baseline`. Record which tests were passing and
which were already failing. Do not treat pre-existing failures as your problem
unless the task explicitly asks you to fix them.

**If `comments: verbose`:** comment on the issue and update the issue body to add:
```
## Status
Branch: <issue-number>-<short-slug>
Baseline: <N> passing, <M> pre-existing failures
```

**If `comments: minimal`:** skip the baseline comment.

#### N3. Implement

**Specialized skill dispatch.** Before writing any code, check the task title and
body for domain signals. If a match is found, call the corresponding skill first
and use its output as the implementation guide throughout this task.

| Signal in title or body | Call |
|---|---|
| `ui`, `component`, `page`, `screen`, `frontend`, `layout`, `design`, `responsive`, `navigation`, `dashboard`, `form`, `view` | `hackathon-frontend` |
| `auth`, `login`, `signup`, `logout`, `oauth`, `jwt`, `token`, `session`, `password`, `protected`, `permission`, `role` | `hackathon-auth` |
| `schema`, `migration`, `table`, `model`, `database`, `erd`, `create table`, `prisma model`, `drizzle`, `entity` | `hackathon-database-schema` |
| `deploy`, `dockerfile`, `ci/cd`, `github actions`, `production`, `host`, `vercel`, `railway`, `fly`, `render` | `hackathon-deploy` |
| `seed`, `demo data`, `fixture`, `populate`, `sample data`, `demo mode` | `hackathon-seed-demo-data` |

Multiple signals may match — call all applicable skills in sequence.
If no signals match, proceed with general implementation below.

Reference `PLAN.md`, `SPECS.md`, and the issue body. When a design decision is
unclear, take the simpler path and document it in an issue comment.

**If `testing: skip`:** implement without running tests. Skip all test steps below.

**Otherwise — run tests progressively.** After each meaningful piece of work:

```bash
<test command>
```

For each run, note:
- What you expected it to show
- What actually happened

If a test that was **passing at baseline** is now **failing**: stop implementing and
call `hackathon-debug`. Do not open a PR over a regression you introduced.

If a test was **already failing at baseline**: note it but continue.

#### N4. Write and verify tests

**If `testing: skip`:** skip this step.

**If `testing: recommended`:** tests must cover the main logic paths of all new code.
Missing edge-case coverage should be noted but is not blocking.

**If `testing: required`:** tests must achieve full path coverage of all new code —
every branch, every code path must be exercised. This is a hard stop before proceeding.

  After writing tests, run the suite:
  ```bash
  <test command>
  ```

  Check that:
  1. All new tests pass
  2. No previously passing tests regressed (call `hackathon-debug` if so)
  3. Coverage is complete (for `required`) — if gaps exist, write more tests and
     re-run. Do not proceed until coverage is satisfactory.

#### N5. Capture discovered scope

When you find work outside this issue, create an issue via the GitHub MCP:
```
Title: [#<parent>] <short imperative description>
Labels: needs-human-review
Body: ## Parent / ## Goal / ## Context / ## Acceptance Criteria
```

#### N6. Run the full test suite before close-out

**If `testing: skip`:** skip this step.

**Otherwise:**
```bash
<test command>
```

All tests that were passing at baseline must still be passing. If any are not,
call `hackathon-debug` before proceeding.

#### N7. Task completion gate (conditional)

**If `task_completion.human_required: false`:** skip to Phase 3.

**If `task_completion.human_required: true`:**

Present completed work in chat:
```
Task #<n> implementation complete. Ready for your review before I open the PR.

What was built: <2–3 sentences>
Files changed: <list>
Tests: <N passing> (<coverage note if testing: required>)
Discovered scope: <new issues created, or "none">
Anything to know: <gotchas or "none">

Say "looks good" to open the PR, or describe any changes needed.
```

Wait for the human's response.

- If **"looks good"** (or equivalent) → proceed to Phase 3.
- If **changes requested** → apply the changes, then:
  - If `testing` is not `skip`: re-run the full test suite. If new tests were written
    to satisfy the changes, verify they pass before continuing.
  - Present the updated summary again with the same format.
  - Loop until the human explicitly approves.
  Never open a PR without explicit approval.

---

### Path R — Rebase after merge conflict

The issue has an `agent: merge conflict` comment. Rebase the branch onto its target.

1. Read the comment for the branch name and PR number.
2. Check out and rebase:
   ```bash
   git fetch origin
   git checkout <branch-name>
   git rebase origin/<target-branch>   # epic branch, not main
   ```
3. Resolve conflicts file by file. Favour this branch's changes; note each resolution.
4. Push: `git push --force-with-lease origin <branch-name>`
5. Comment on PR: `agent: rebased — conflicts resolved`
6. Change issue label to `in-review` via the GitHub MCP.
7. Comment on issue: branch, PR, files resolved.
8. **Do not merge** — leave for review.
9. Continue loop.

---

### Path F — Fix review feedback

The issue has an `agent: review — changes requested` comment. Fix and push to the
existing branch (do not open a new PR).

1. Read the comment and the PR review comments for the exact changes needed.
2. Check out the existing branch.
3. **If `testing` is not `skip`:** run the full test suite to establish the current
   baseline before touching anything. Record which tests are passing now.
4. Implement only the requested changes — do not re-implement the whole feature.
5. **If `testing` is not `skip`:** run the full test suite. All tests passing at the
   pre-fix baseline must still pass. If new tests were required by the feedback,
   verify they pass.
6. **If `task_completion.human_required: true`:** present the fixes in chat before
   pushing, using the same approval loop as N7. Loop until approved.
7. Push to the existing branch.
8. Comment on PR: `agent: changes implemented — re-requesting review`
9. Change issue label back to `in-review`.
10. Comment on issue: what was fixed, test results before and after.
11. Continue loop.

---

## Phase 3 — Close out a task (Path N only)

**A PR is the only valid close-out path for completed work.**

1. Push the feature branch:
   ```bash
   git push -u origin <branch-name>
   ```

2. Open a PR via the GitHub MCP:
   - Title: same as the issue title
   - Body: `Closes #<issue number>` on its own line, then a 2–3 sentence summary
     including test results
   - Base: the **epic branch** (e.g. `epic-<n>-<slug>`) — NOT main

3. Change the issue label to `in-review` via the GitHub MCP.

4. **If `comments: verbose`:** update the issue body to add or update `## Status`:
   ```
   ## Status
   Branch: <branch-name>
   PR: #<number> (base: epic-<n>-<slug>)
   Tests: <N passing at baseline> → <N passing now>
   New issues: <list or "none">
   ```
   Comment on the issue:
   ```
   agent: done — PR #<number> open for review

   Branch: <branch-name>
   PR base: epic-<n>-<slug>
   What was built: <2–3 sentences>
   New issues created: <list or "none">
   Test suite: <N passing / N failing — any failures noted in PR>
   Reviewers should know: <gotchas or "none">
   ```

   **If `comments: minimal`:** comment on the issue:
   ```
   agent: done — PR #<number>
   ```

---

## Phase 3b — Code review gate

**If `code_review.human_required: true`:**
Leave the PR in `in-review`. Stop here and return to Phase 2.
The human will trigger `hackathon-review` when ready.

**If `code_review.human_required: false`:**
Immediately call `hackathon-review` internally for this PR.

- If verdict is **APPROVE** → merge the PR via the GitHub MCP (squash preferred).
  Confirm the issue was auto-closed. Remove the `in-review` label.
  Return to Phase 2.

- If verdict is **REQUEST CHANGES** → apply every requested fix on the existing
  branch. If `testing` is not `skip`, re-run the full suite and verify it passes.
  Push. Call `hackathon-review` again. Loop until the verdict is APPROVE.

---

## Phase 4 — No more ai-approved tasks

**First, check for stale `in-progress` tasks.** An `in-progress` issue is stalled if
its most recent agent comment is the original claiming comment (no subsequent progress
updates) and that comment is more than 30 minutes old. If any stalled issues exist:

- Check whether the branch was pushed:
  ```bash
  git fetch origin && git branch -r | grep <branch-name>
  ```
- If no branch: reclaim fresh — comment `agent: reclaiming stalled work — no branch found, restarting`, re-assign, route through the appropriate path.
- If branch exists: check it out, read issue comments for context, continue from where the previous agent left off.

Only proceed to the report below if no stalled tasks exist.

**If `comments: verbose`:**
```
Session complete. No more ai-approved tasks.

PRs open for review: <list of in-review issues and their PR numbers>
Tasks still needs-human-review: <count>
Blocked tasks: <count>

Next steps for the human:
- Review open PRs with hackathon-review
- Approve more tasks with `ai-approved` label to continue implementation
```

**If `comments: minimal`:**
```
Session complete. PRs open: <list>. Blocked: <count>.
```

Stop.

---

## Phase 5 — Session ended before task is complete

Push what exists so it isn't lost:
```bash
git push -u origin <branch-name>
```

Leave the issue `in-progress`, yourself as assignee. Comment:
```
agent: session end — work in progress

Branch: <branch-name>
Done so far: <what's complete>
Remaining: <what's left>
Next agent should: <file paths, where to pick up, anything non-obvious>
Baseline test state: <what was passing/failing at start, or "skipped">
```

---

## Rules

- **Never commit to main or the epic branch directly.** Always branch.
- **Never open a PR against main** (except the verify task which opens the epic→main PR).
- **Never close an issue without a PR.**
- **Never let a regression go undetected** (unless `testing: skip`). Run baseline tests before starting.
- **Debug before PR if tests regressed.** Call hackathon-debug automatically.
- **Never edit PLAN.md in a task branch.** Create a plan-update issue instead.
- **Never fire MCP calls in parallel.**
- **Never let discovered scope stay uncaptured.** Issue first, then continue.
- **When task_completion.human_required: true and changes requested:** apply changes,
  re-run tests, verify they pass, then re-present. Never open PR without explicit approval.
