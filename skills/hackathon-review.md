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

Build the list of PRs with no existing `agent: reviewing` comment (unclaimed).

**If there are no unclaimed `in-review` issues:** output `NOTHING_TO_DO` and stop.

---

## Phase 2 — Claim

Pick the oldest unclaimed `in-review` issue.

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

### 3c. Evaluate
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

1. Approve the PR via the GitHub MCP
2. Merge the PR via the GitHub MCP (squash preferred)
3. Confirm the issue was auto-closed (GitHub closes it because the PR body
   contains `Closes #<n>`). If not, close it manually via the GitHub MCP.
4. Delete the feature branch if the GitHub MCP supports it
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

---

## Stop

Output what happened:
- "PR #<n> merged. Issue #<n> closed." — if approved
- "PR #<n> has changes requested. Issue #<n> returned to ready." — if rejected

Do not pick up another review. Stop.

---

## Rules

- **One review per context.** Stop after the verdict.
- **Never merge without reading the diff and checking acceptance criteria.**
- **Never request changes for style.** Only for unmet acceptance criteria or clear bugs.
- **Be specific.** Vague feedback is not implementable by the next agent.
- **Return to `ready`, not `in-progress`.** The loop needs to be able to claim it.
- **Never fire MCP calls in parallel.**
