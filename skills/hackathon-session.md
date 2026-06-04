---
description: Loop through all ai-approved tasks — claim, test, implement, debug if needed, open PR. Runs until no ai-approved tasks remain. Context grows across tasks.
allowed-tools: mcp__github__*, Read, Write, Edit, Bash
---

# Skill: hackathon-session

**One growing context, all ai-approved tasks.** This skill orients once, then loops:
claim an `ai-approved` task → run baseline tests → implement → run tests throughout →
debug if tests fail unexpectedly → open PR → repeat until no tasks remain.

The context accumulates across tasks. This is intentional — the human controls the
pace by deciding which tasks to approve.

---

## GitHub MCP — required for all operations

Every GitHub operation **must** use the GitHub MCP (`mcp__github__*`).
Do not use `gh` CLI, `curl`, or Bash for anything the MCP can handle.
Make all MCP calls **sequentially, not in parallel.**

---

## Trigger

"Go", "Work on tasks", "Start implementing", or any instruction to do project work.

---

## Phase 1 — Orient (once, at session start)

**Git sync:**
```bash
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ] && [ -n "$(git status --porcelain)" ]; then
  git add -A && git commit -m "agent: checkpoint — session restart" || true
  git push -u origin "$CURRENT_BRANCH" || true
fi
git fetch origin && git remote prune origin
git checkout main && git merge --ff-only origin/main
```

If `--ff-only` fails: local main diverged. Comment on the tracking issue and stop.

Read sequentially via the GitHub MCP:
1. `AGENTS.md` — coordination protocol
2. `PLAN.md` — vision, stack, done criteria (note the Test command row)

**Dependency unblock sweep:** For each `blocked` issue, check if every issue in its
`## Blocked By` section is now closed. If all are closed, change label `blocked` →
`needs-human-review` and comment `agent: dependency closed — moved to needs-human-review`.

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

Pick **at random** from the available issues — not the oldest. If all issues are
one type, pick from that type.

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

Before writing any code, run the full test suite to establish what was already
broken before you touched anything:

```bash
<test command from PLAN.md>
```

Call `hackathon-test` with mode `baseline`. Record which tests were passing and
which were already failing. **Do not treat pre-existing failures as your problem**
unless the task explicitly asks you to fix them.

Comment on the issue:
```
agent: baseline test run complete
Passing: <N>  Failing: <M>  (pre-existing failures noted — not caused by this task)
```

#### N3. Implement

Reference `PLAN.md`, `SPECS.md`, and the issue body. When a design decision is
unclear, take the simpler path and document it in an issue comment.

**As you implement, run tests progressively.** After each meaningful piece of work:

```bash
<test command>
```

For each test, note:
- What you expected it to show
- What actually happened

If a test that was **passing at baseline** is now **failing**: stop implementing and
call `hackathon-debug`. Do not open a PR over a regression you introduced.

If a test is failing that was **already failing at baseline**: note it but continue.

#### N4. Capture discovered scope

When you find work outside this issue, create an issue via the GitHub MCP:
```
Title: [#<parent>] <short imperative description>
Labels: needs-human-review
Body: ## Parent / ## Goal / ## Context / ## Acceptance Criteria
```

#### N5. Run the full test suite before PR

```bash
<test command>
```

All tests that were passing at baseline must still be passing. If a regression remains
after debugging, note it explicitly in the PR body — do not hide it.

#### N6. Close out → Phase 3

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
3. Implement only the requested changes — do not re-implement the whole feature.
4. Run the full test suite. Fix any failures.
5. Push to the existing branch.
6. Comment on PR: `agent: changes implemented — re-requesting review`
7. Change issue label back to `in-review`.
8. Comment on issue: what was fixed.
9. Continue loop.

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
   - Base: the **epic branch** (e.g. `epic-<n>-<slug>`) — NOT main

3. Change the issue label to `in-review` via the GitHub MCP.

4. Comment on the issue:
   ```
   agent: done — PR #<number> open for review

   Branch: <branch-name>
   PR base: epic-<n>-<slug>
   What was built: <2–3 sentences>
   New issues created: <list or "none">
   Test suite: <N passing / N failing — any failures noted in PR>
   Reviewers should know: <gotchas or "none">
   ```

5. Return to Phase 2 — Task loop.

---

## Phase 4 — No more ai-approved tasks

When the task list is empty, report:

```
Session complete. No more ai-approved tasks.

PRs open for review: <list of in-review issues and their PR numbers>
Tasks still needs-human-review: <count>
Blocked tasks: <count>

Next steps for the human:
- Review open PRs with hackathon-review
- Approve more tasks with `ai-approved` label to continue implementation
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
Baseline test state: <what was passing/failing at start>
```

---

## Rules

- **Never commit to main or the epic branch directly.** Always branch.
- **Never open a PR against main** (except the verify task which opens the epic→main PR).
- **Never close an issue without a PR.**
- **Never let a regression go undetected.** Run baseline tests before starting.
- **Debug before PR if tests regressed.** Call hackathon-debug automatically.
- **Never edit PLAN.md in a task branch.** Create a plan-update issue instead.
- **Never fire MCP calls in parallel.**
- **Never let discovered scope stay uncaptured.** Issue first, then continue.
