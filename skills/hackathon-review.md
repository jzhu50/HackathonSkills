---
description: Review one PR. Check AC, post findings, decide merge/changes. Triggered internally or by human.
allowed-tools: mcp__github__*
---

# Skill: hackathon-review
Review one PR. Verify AC. Decide.

## Phase 0: Orient
- Load `hackathon.config.yml`. Gate: `code_review`.
- Load `AGENTS.md` and `PLAN.md`.

## Phase 1: Claim & Collision Check
1. **Refresh**: `mcp__github__get_issue` + `mcp__github__list_issue_comments`.
2. **Check**: Is it `review-ready`? Is there a claim < 120s? -> ABORT if yes.
3. **Act**: Change label `review-ready` -> `in-review`. Assign self.

## Phase 2: Review
- Read Issue: Goal, AC.
- Read PR: `mcp__github__get_pull_request_files`.
- **Mergeable?**: 
  - `null` -> Wait 10s -> Retry.
  - `conflicted` -> Comment `agent: merge conflict`. Label `in-review` -> `ai-approved`. Unassign. ABORT.
- **Evaluate**: 
  - Meets AC?
  - Matches goal?
  - Tests exist?
  - Security ok? (No SQLi, secrets).

## Phase 3: Verdict
- **PASS**: `APPROVE`.
- **FAIL**: `REQUEST CHANGES`. List specific file:line fixes.

## Phase 4: Execute
**If Human Mode:**
- Present findings. Wait for `merge` or `request changes`.

**If Autonomous:**
- `APPROVE` -> Merge PR (squash for tasks). Auto-close issue. Remove `in-review`.
- `REQUEST CHANGES` -> Post review. Label `in-review` -> `ai-approved`. Unassign. Comment instructions.
