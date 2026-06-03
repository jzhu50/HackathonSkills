---
description: Pick up one open PR, review it against acceptance criteria, merge it or request specific changes, then stop. Called by hackathon-session Path C or directly.
allowed-tools: mcp__github__*
---

# Skill: hackathon-review

**One context, one review.** Orient → find an unclaimed PR → review the diff →
approve and merge, or request specific changes → stop.

When changes are requested, the issue returns to `ready` so the autonomous loop
picks it up and a new agent implements the fixes.

---

## GitHub MCP — required for all operations

Every operation **must** use the GitHub MCP (`mcp__github__*`).
Make all calls sequentially, not in parallel.

---

## Trigger

"Review", "Merge what's ready", directly or via hackathon-session Path C.

---

## Phase 1 — Orient

Read sequentially via the GitHub MCP:
1. `AGENTS.md` — coordination protocol
2. `PLAN.md` — vision, done criteria, acceptance bar

List issues with label `in-review` via the GitHub MCP. For each, read comments to
extract the PR number from the close-out comment
(`agent: done — PR #<number> open for review`).

Build the list of **actionable** PRs. A PR is actionable if either:
- it has no `agent: reviewing` comment (never claimed), **or**
- its most recent `agent: reviewing` comment is **stale** — more than 30 minutes old with no
  verdict comment after it (`reviewed and merged` / `changes requested` / `merge conflict`).
  A stale claim means the reviewer crashed mid-review; without this the PR would sit in
  `in-review` forever and its epic could never complete. Treat it as reclaimable.

A PR whose `agent: reviewing` comment is **fresh** (< 30 min, no verdict yet) is being
reviewed by a peer right now — skip it.

**If there are no actionable PRs:** report "no PRs available to review" and stop. Do not emit
a loop signal — when this skill runs inside the loop, hackathon-session Path E owns the
`NOTHING_TO_DO` / `WAITING_FOR_PEERS` decision (so it can keep this machine in the pool while
peers finish).

---

## Phase 2 — Claim

Pick **at random** from the unclaimed `in-review` issues — not the oldest. Parallel
machines would otherwise all claim the same item and collide.

Add a comment to the **PR** (not the issue) via the GitHub MCP:
```
agent: reviewing — [github username] — [ISO timestamp]
```

Collision check (multi-agent only): re-read the PR. Two reviewing claims within
2 minutes → comment `agent: review collision — backing off`, pick a different PR.

---

## Phase 3 — Review

### 3a. Read the issue
Via the GitHub MCP: full issue body and all comments.
Extract: Goal, Acceptance Criteria, the agent's close-out summary.

### 3b. Read the diff
Via the GitHub MCP: get pull request files. Read every changed file.

### 3c. Check for merge conflicts

Check the PR's `mergeable` state via the GitHub MCP. If the PR cannot be merged cleanly
due to conflicts with `main`, do **not** attempt to merge. Go to Phase 4 — Conflict.

### 3d. Evaluate
For each acceptance criterion, does the code satisfy it?

Also check:
- Does the implementation match the stated goal?
- Obvious bugs or missing error handling at system boundaries?
- Conflicts with `PLAN.md` or `SPECS.md`?
- Security issues (SQL injection, unsanitised input, exposed secrets)?

This is not a full code review — it is checking the issue is actually done and
the code does not obviously break anything.

---

## Phase 4 — Verdict

### Approve and merge

1. Approve the PR via the GitHub MCP. **If approval fails because you are the PR author**
   (a solo dev running several machines on one PAT — GitHub forbids approving your own PR),
   skip the formal approval: your review comment plus the merge is the audit trail. Do not
   get stuck here.
2. Merge the PR via the GitHub MCP — squash preferred. If the merge fails because squash
   merging is disabled on the repo, retry with a standard merge commit.
   - If the merge is rejected by **branch protection requiring approvals** and you could not
     self-approve (step 1), the project is misconfigured for a single-PAT team. Comment on
     the PR `agent: cannot merge — branch protection requires an approval this account
     cannot give; see README branch-protection note`, leave the issue `in-review`, and stop.
3. Confirm the issue was auto-closed (GitHub closes it because the PR body contains
   `Closes #<n>`). If not, close it manually via the GitHub MCP.
4. **Remove the `in-review` label** from the (now closed) issue so a reopen never carries a
   stale state, and delete the feature branch if the GitHub MCP supports it.
5. Comment on the issue via the GitHub MCP:
   ```
   agent: reviewed and merged — PR #<number>

   Verdict: approved
   Merged: [ISO timestamp]
   ```

### Request changes

When the code does not satisfy an acceptance criterion, request specific changes.
Never request changes for style preferences or gold-plating — only for things that
would cause the feature to fail its stated acceptance criteria.

1. Post a review via the GitHub MCP requesting changes:
   - For each problem: quote the unmet criterion, point to the exact file/behaviour,
     suggest the specific fix
   - Be concrete enough that an agent can implement the fix without asking questions

2. Change the **issue** label from `in-review` → `ready` via the GitHub MCP.
   (Back to `ready`, not `in-progress` — so the autonomous loop can claim it.)

3. Unassign the issue via the GitHub MCP (the next agent will re-claim it).

4. Comment on the **issue** via the GitHub MCP:
   ```
   agent: review — changes requested

   Branch: <branch-name>
   PR: #<pr-number>
   What needs fixing: <one line per change requested — mirror the PR review comments>

   Next agent: check out branch <branch-name>, read PR #<pr-number> review comments,
   implement the fixes, push. Do not open a new PR — the existing one auto-updates.
   ```
   (The PR stays open. Pushing more commits to the branch will update it.)

### Conflict

The PR has merge conflicts and cannot be merged cleanly.

1. Post a comment on the **PR** via the GitHub MCP:
   ```
   agent: merge conflict — cannot merge cleanly into main. Branch must be rebased.
   ```

2. Change the **issue** label from `in-review` → `ready` via the GitHub MCP.

3. Unassign the issue via the GitHub MCP.

4. Comment on the **issue** via the GitHub MCP:
   ```
   agent: merge conflict

   Branch: <branch-name>
   PR: #<pr-number>

   Next agent: fetch origin, check out branch <branch-name>, run `git rebase origin/main`,
   resolve any conflicts, then `git push --force-with-lease origin <branch-name>`.
   Do not open a new PR — the existing one auto-updates.
   ```
   (The `hackathon-session` Path A3 handles this automatically on the next loop cycle.)

---

## Stop

Output what happened:
- "PR #<n> merged. Issue #<n> closed." — if approved
- "PR #<n> has changes requested. Issue #<n> returned to ready." — if rejected
- "PR #<n> has merge conflicts. Issue #<n> returned to ready for rebase." — if conflicted

Do not pick up another review. Stop.

---

## Rules

- **One review per context.** Stop after the verdict.
- **Check merge conflicts before approving.** Never approve a PR that cannot be merged.
- **Never merge without reading the diff and checking acceptance criteria.**
- **Never request changes for style.** Only for unmet acceptance criteria or clear bugs.
- **Be specific.** Vague feedback is not implementable by the next agent.
- **Return to `ready`, not `in-progress`.** The loop needs to be able to claim it.
- **Never fire MCP calls in parallel.**
