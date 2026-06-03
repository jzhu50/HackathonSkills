---
description: One autonomous work unit — orient, claim the highest-value task or PR review, do the work, close out, then stop. Triggered by "Go". Designed to be called in a loop by run.sh.
allowed-tools: mcp__github__*, Read, Write, Edit, Bash
---

# Skill: hackathon-session

**One context, one unit of work.** This skill is designed to be called repeatedly by
`run.sh` in a tight loop. Each invocation:

1. Reads current GitHub state (fresh — no memory of previous invocations)
2. Routes to the highest-value work available
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
In automated mode this trigger comes from `run.sh` — proceed immediately without asking for clarification.

---

## Phase 1 — Orient

Read sequentially via the GitHub MCP:
1. `AGENTS.md` — coordination protocol
2. `PLAN.md` — vision, stack, done criteria (note the Test command row)

Then, sequentially via the GitHub MCP:
1. Search `[Project] Tracking is:open` — project overview
2. List `in-progress` issues — what is being worked right now
3. List `blocked` issues — anything you might unblock
4. List `ready` issues, no assignee — task candidates
5. List `needs-scoping` issues, no assignee — decomposition candidates
6. List `in-review` issues — PR reviews waiting

**Stale in-progress check:** For each `in-progress` issue, read its comments. If the most
recent agent comment is the original claiming comment (no subsequent progress updates) and
its timestamp is more than 2 hours ago, the issue is likely stalled. Note stalled issues —
they are reclaim candidates in Phase 2.

Synthesise: what is the team building, what's in flight, what is the most valuable thing
to do right now? State this in 2–3 sentences before acting.

---

## Phase 2 — Route to work

Choose exactly one path. Do not attempt more than one unit of work per invocation.

### Priority order

```
0  → epic with all children closed   (verify before starting new work)
A  → ready issue exists              (highest value)
A' → stalled in-progress exists      (crash recovery, only if no ready issues)
B  → needs-scoping issue exists      (unblock future work)
C  → in-review PR exists             (unblock merged value)
D  → none of the above               (run test suite to find bugs)
E  → test suite also clean           (NOTHING_TO_DO)
```

---

### Path 0 — Verify a completed epic

**Condition:** any `epic`-labeled issue is open AND all issues listed in its
`## Child Issues` checklist are closed.

Detection: during Phase 1 orient, read each open `epic` issue and its Child Issues
checklist. Compare each linked issue number against closed issues.

Follow `hackathon-verify` skill steps exactly. Stop after the verdict (pass or bug
filing). Do not pick up a ready task in the same invocation.

**Why this is highest priority:** a passing epic is a shippable unit. An unverified
epic can contain integration failures invisible at the task level. Verify before
adding more features.

---

### Path A — Do a task

**Condition:** at least one `ready` issue with no assignee.

Pick the oldest `ready` issue, or one that unblocks other work.

**Detect the task type by scanning issue labels and comments:**

| Signal | Type | Path |
|---|---|---|
| Comment `agent: merge conflict` | Rebase branch onto main | A3 |
| Comment `agent: review — changes requested` | Fix review feedback | A2 |
| Label `bug` | Debug and fix | A-bug |
| None of the above | New feature/task | A1 |

---

#### Path A1 — New task

1. Claim the issue (three sequential MCP calls, no other actions between):
   - Add yourself as assignee
   - Change label `ready` → `in-progress`
   - Comment: `agent: claiming — [github username] — [ISO timestamp]`

2. Collision check (multi-agent only): re-read the issue. Two assignees or two claiming comments
   within 2 minutes → unassign, comment `agent: collision — backing off`, pick a different issue.

3. Create a feature branch before writing any code:
   ```bash
   git checkout main && git pull origin main
   git checkout -b <issue-number>-<short-slug>
   ```

4. Check environment: if the issue involves native packages or build tools, verify they install
   cleanly before writing code. If a dependency fails, create a `blocked` issue before continuing.

5. Implement the issue. Reference `PLAN.md` and `SPECS.md` for intent. When a design decision is
   unclear, take the simpler path and document it in an issue comment via the GitHub MCP.

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

7. If blocked: change label to `blocked`, comment explaining what's blocking you, unassign, go
   back to Phase 2 and pick a different issue.

8. Close out → Phase 3.

---

#### Path A2 — Fix review feedback

The issue was returned from review. The previous PR is still open; add commits to it.

1. Claim the issue (same three-step sequence as Path A1).

2. Check out the existing branch (name is in the `agent: review — changes requested` comment):
   ```bash
   git fetch origin
   git checkout <branch-name>
   ```

3. Read all PR review comments via the GitHub MCP. Treat each as a specific requirement.

4. Implement only the requested changes — do not re-implement the whole feature.

5. Push to the existing branch (the open PR auto-updates — do not open a new PR):
   ```bash
   git push origin <branch-name>
   ```

6. Comment on the PR via the GitHub MCP: `agent: changes implemented — re-requesting review`

7. Change issue label back to `in-review` via the GitHub MCP.

8. Comment on the issue:
   ```
   agent: review feedback implemented

   Branch: <branch-name>
   PR: #<pr-number>
   Changes made: <what was fixed, one line per review comment addressed>
   ```

9. Stop. Do not merge — leave for a review session.

---

#### Path A3 — Rebase after merge conflict

The PR could not be merged because it conflicts with `main`. Rebase the branch and push.

1. Claim the issue (same three-step sequence as Path A1).

2. Check out the branch (name is in the `agent: merge conflict` comment):
   ```bash
   git fetch origin
   git checkout <branch-name>
   git rebase origin/main
   ```

3. If rebase has conflicts: resolve them file by file. When in doubt about intent, favour
   preserving the changes from this branch and note each resolution in the PR comment.

4. Push the rebased branch:
   ```bash
   git push --force-with-lease origin <branch-name>
   ```

5. Comment on the PR via the GitHub MCP: `agent: rebased onto main — conflicts resolved`

6. Change issue label back to `in-review` via the GitHub MCP.

7. Comment on the issue:
   ```
   agent: rebase complete

   Branch: <branch-name>
   PR: #<pr-number>
   Conflicts resolved: <list of files, or "none">
   ```

8. Stop. Do not merge — leave for a review session.

---

#### Path A-bug — Debug and fix a bug

The issue has the `bug` label. Follow `hackathon-debug` skill steps exactly:
reproduce → diagnose → fix → regression test → suite green → PR. Then stop.

---

### Path A' — Reclaim stalled work

**Condition:** no `ready` issues, but one or more `in-progress` issues appear stalled
(last agent comment is the claiming comment, timestamp > 2 hours ago).

Pick the stalest stalled issue.

1. Check whether the branch was pushed:
   ```bash
   git fetch origin
   git branch -r | grep <branch-name>
   ```

2. If no branch exists (agent crashed before pushing): reclaim the issue fresh as Path A1.
   Comment before starting: `agent: reclaiming stalled work — no branch found, restarting`

3. If the branch exists: check out the branch and continue where the previous agent left off.
   Read the issue comments for context on what was done and what remains.
   Comment: `agent: reclaiming stalled work — continuing from existing branch`

4. Complete the work and close out → Phase 3.

---

### Path B — Decompose an epic

**Condition:** no `ready` issues, no stalled work, but `needs-scoping` issues exist.

Follow `hackathon-decompose` skill steps exactly. After decomposition, stop — do not claim a
task in the same invocation.

---

### Path C — Do a PR review

**Condition:** no `ready` issues, no stalled work, no `needs-scoping` issues, but `in-review` PRs exist.

Follow `hackathon-review` skill steps exactly. Stop after the review.

---

### Path D — Run the test suite

**Condition:** no `ready` issues, no stalled work, no `needs-scoping` issues, no `in-review` PRs.

Follow `hackathon-test` skill steps exactly. If new bugs are found, the loop will pick them up
on the next invocation. Stop after reporting.

---

### Path E — Nothing to do

**Condition:** Path D test suite is fully green and no work exists in any state.

Report current state briefly. Then output exactly:

```
NOTHING_TO_DO
```

The run script uses this signal to decide whether to wait or exit.

---

## Phase 3 — Close out a task

**A PR is the only valid close-out path for completed work.**
Never close an issue directly. Never leave completed work without a PR.

**Before opening the PR — run the test suite:**
```bash
<test command from PLAN.md Stack table>
```

If tests fail: fix them before opening the PR. If you cannot fix them within reasonable
effort, open the PR anyway and note the failures explicitly in the PR body so the reviewer
is not surprised.

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
   Test suite: <passing / N failures noted in PR>
   Reviewers should know: <gotchas or "none">
   ```

5. If `PLAN.md` needs updating, create a `[Plan Update] <description>` issue labeled `ready`
   and comment on the tracking issue. Never modify `PLAN.md` in a task branch.

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

- **One unit of work per invocation.** Stop after Phase 3 or after Path B/C/D/E.
- **Never commit to `main` directly.** Branch first, always.
- **Never close an issue without a PR.** The PR is the audit trail.
- **`in-review` = PR open and unmerged.** Never apply it any other way.
- **Never edit `PLAN.md` in a task branch.** Create a plan-update issue instead.
- **Never fire MCP calls in parallel.** Sequential only.
- **Never go silent on a blocked issue.** Always comment and move on.
- **Never let discovered scope stay uncaptured.** Issue first, then continue.
- **Never use `gh` CLI or Bash for GitHub operations.** GitHub MCP only.
- **Run tests before opening a PR.** Note any failures explicitly — do not hide them.
