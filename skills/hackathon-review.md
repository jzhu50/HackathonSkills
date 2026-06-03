---
description: Pick up one open PR, review it against the issue's acceptance criteria, and either merge it or request changes. Then stop. One context = one review.
allowed-tools: mcp__github__*
---

# Skill: hackathon-review

**One context, one review.** This skill runs exactly one review per invocation:
orient → find an unreviewed PR → claim it → read the diff → verdict → stop.

Use this skill when PRs are accumulating in `in-review` state and need to be
cleared before the team can move forward.

---

## GitHub MCP — required for all operations

Every operation in this skill **must** use the GitHub MCP (`mcp__github__*`).
Make all calls **sequentially, not in parallel.**

---

## Trigger

A human says something like:
- "Review"
- "Review a PR"
- "Merge what's ready"
- "Check the open PRs"
- Any instruction to review or merge pending work

---

## Phase 1 — Orient

### 1a. Load project context (same as session)
Using the GitHub MCP `get_file_contents`, read sequentially:
1. `AGENTS.md` — coordination protocol, label meanings
2. `PLAN.md` — vision and acceptance bar

### 1b. Find open PRs to review
Use the GitHub MCP to list issues with label `in-review`.
For each `in-review` issue, read its comments to extract the PR number
(the close-out comment format is: `agent: done — PR #<number> open for review`).

Alternatively, list open pull requests directly via the GitHub MCP if available.

Build a list of PRs that have no existing review claim comment.

If there are no `in-review` issues, tell the human and stop.

---

## Phase 2 — Claim a review

### 2a. Pick
Pick the oldest `in-review` issue (highest priority = longest waiting).

### 2b. Claim the review
Add a comment to the **PR** (not the issue) via the GitHub MCP:
```
agent: reviewing — [your github username] — [ISO timestamp]
```

### 2c. Collision check (multi-agent only)
Re-read the PR after posting. If two reviewing claims appear within 2 minutes,
comment `agent: review collision — backing off` and pick a different PR.

---

## Phase 3 — Review

### 3a. Read the linked issue
Get the full issue body and all comments via the GitHub MCP.
Extract:
- The **Goal** — what was this issue trying to do?
- The **Acceptance Criteria** — the specific verifiable checks
- The close-out comment — what did the agent say it built?

### 3b. Read the PR diff
Use the GitHub MCP to get the pull request files (diff).
Read through every changed file.

### 3c. Evaluate against acceptance criteria
For each acceptance criterion in the issue, verify it is satisfied by the code:
- Does the implementation match the stated goal?
- Are there obvious bugs, missing error handling at system boundaries, or broken logic?
- Does it conflict with anything in `PLAN.md` or `SPECS.md`?
- Does it introduce security issues (SQL injection, unsanitised input, exposed secrets)?

You are not doing a full code review — you are checking that the issue is actually done
and that the code doesn't break anything obvious.

---

## Phase 4 — Verdict

### If the PR is good — merge it

1. Approve the PR via the GitHub MCP
2. Merge the PR via the GitHub MCP (squash merge preferred for a clean history)
3. Confirm via the GitHub MCP that the linked issue was automatically closed
   (GitHub closes it on merge because the PR body contains `Closes #<n>`)
4. If the issue is still open after merge, close it manually via the GitHub MCP
5. Delete the feature branch if the GitHub MCP supports it
6. Comment on the original issue via the GitHub MCP:
   ```
   agent: reviewed and merged — PR #<number>

   Reviewer: [your github username]
   Verdict: approved — acceptance criteria met
   Merged: [ISO timestamp]
   ```

### If the PR has problems — request changes

1. Post a review via the GitHub MCP requesting changes. Be specific:
   - Quote the acceptance criterion that is not met
   - Point to the exact file and line (or describe the missing behaviour)
   - Suggest a fix where possible
2. Change the **issue** label from `in-review` → `in-progress` via the GitHub MCP
3. Re-assign the issue to the original assignee (from the claiming comment) via the GitHub MCP
4. Comment on the issue via the GitHub MCP:
   ```
   agent: review — changes requested

   Reviewer: [your github username]
   PR #<number> needs work before merge.
   See PR review comments for specifics.
   ```

### Phase 5 — Stop

Tell the human what happened:
- "PR #<number> merged. Issue #<n> closed." — if approved
- "PR #<number> has review comments. Issue #<n> returned to in-progress." — if rejected

Do not pick up another review in this context. Start a new session.

---

## Rules

- **One review per context.** Stop after the verdict. Start fresh for the next one.
- **Never merge without checking acceptance criteria.** "It runs" is not enough.
- **Never close a PR without reading the diff.** Even if the agent says it's done.
- **Be specific when requesting changes.** Vague feedback wastes the next agent's time.
- **Never fire MCP calls in parallel.** Sequential only.
