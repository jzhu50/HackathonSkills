---
description: Review one PR - read the diff, check acceptance criteria, post findings, and either present verdict to human or return it to the calling skill. Triggered by human or called internally by hackathon-session when code_review.human_required is false.
allowed-tools: mcp__github__*
---

# Skill: hackathon-review

**One PR per invocation.** Reviews the specified PR against its acceptance criteria,
posts findings, and either presents the verdict to the human (human-triggered mode)
or returns the verdict to the calling skill (internal mode).

**Human-triggered mode:** human invokes this skill directly. Skill presents verdict
and waits for the human's merge/reject decision.

**Internal mode:** called by `hackathon-session` when `code_review.human_required: false`.
Skill returns the verdict (`APPROVE` or `REQUEST CHANGES: [list]`) to the session
instead of waiting for a human. Session acts on the verdict.

---

## GitHub MCP - required for all operations

Every GitHub operation **must** use the GitHub MCP (`mcp__github__*`).
Do not use `gh` CLI, `curl`, or Bash for anything the MCP can handle.
Make all MCP calls **sequentially, not in parallel.**

---

## Trigger

**Human-triggered:** "Review PR #X", "Review the open PRs", or any instruction from the human to review.
**Internal:** called by `hackathon-session` with a specific PR number and `mode: internal`.

---

## Phase 0 - Determine mode and read config

Read `hackathon.config.yml`. Extract:
- `quality.comments` (default: `verbose`)

**Mode:** if called by a human -> human-triggered mode.
If called internally by hackathon-session -> internal mode.

---

## Phase 1 - Orient

Read sequentially via the GitHub MCP:
1. `AGENTS.md` - coordination protocol
2. `PLAN.md` - vision, done criteria, acceptance bar

**Human-triggered:** if the human specified a PR number, use that.
If not: list all `in-review` issues via the GitHub MCP and ask which to review.

**Internal mode:** PR number is provided by the caller. Use it directly.

---

## Phase 2 - Review

### 2a. Read the issue

Via the GitHub MCP: full issue body and all comments.
Extract: Goal, Acceptance Criteria, the agent's close-out summary.

### 2b. Read the diff

Via the GitHub MCP: get pull request files. Read every changed file in full.
Note the PR's base branch (epic branch or main).

### 2c. Check for merge conflicts

Check the PR's `mergeable` state via the GitHub MCP.

- If **`null` or `UNKNOWN`** (GitHub is still computing): wait 10 seconds and re-check
  once. If still null after the retry, report to the human:
  `"PR #<n> mergeability is still computing - re-run review in a moment."` and stop.
- If **conflicted**:
  - Post on PR: `agent: merge conflict - branch must be rebased onto <base>`
  - Change issue label `in-review` -> `ai-approved`
  - Unassign the issue
  - Comment on issue:
    ```
    agent: merge conflict

    Branch: <branch-name>
    PR: #<pr-number>
    Base: <epic-branch or main>

    Next agent: fetch origin, checkout <branch-name>, rebase onto <base>,
    push --force-with-lease, then return this issue to in-review.
    ```
  - Stop. Report the conflict to the human.
- If **clean**: proceed to 2d.

### 2d. Evaluate

For each acceptance criterion in the issue, does the code satisfy it?

Also check:
- Does the implementation match the stated goal?
- Obvious bugs or missing error handling at system boundaries?
- Missing test coverage for the new behavior?
- Conflicts with `PLAN.md` or `SPECS.md`?
- Security issues (SQL injection, unsanitised input, exposed secrets)?

This is not a style review. Only flag things that would cause the feature to fail
its stated acceptance criteria or introduce clear defects.

---

## Phase 3 - Post findings

**If `comments: verbose`:** post a detailed review comment on the **PR** via the GitHub MCP:

```
## Review findings

**Issue:** #<n> - <title>
**PR base:** <epic branch or main>

### Acceptance criteria
- [PASS/FAIL] <criterion 1> - <note if relevant>
- [PASS/FAIL] <criterion 2> - <note if relevant>
...

### Additional findings
<bugs, missing tests, security issues - one per bullet, with file:line reference>
<If none: "No additional findings.">

### Verdict
APPROVE - all criteria met, no blocking issues.
 - or -
REQUEST CHANGES - <N> issues must be fixed before merge:
1. <specific thing to fix - file:line + what to change>
2. ...
```

**If `comments: minimal`:** post only the verdict line on the PR:
```
agent: APPROVE - all criteria met.
 - or -
agent: REQUEST CHANGES - <N> issues: 1. <issue> 2. <issue> ...
```

---

## Phase 4 - Return verdict or present to human

**Internal mode:**

Return the verdict directly to the calling skill (hackathon-session). Do not wait.
Format:
```
APPROVE
 - or -
REQUEST CHANGES:
1. <specific thing to fix - file:line + what to change>
2. ...
```

Stop. The session will act on this verdict.

**Human-triggered mode:**

Summarise findings clearly:

```
Review complete for PR #<n> (<issue title>).

Verdict: APPROVE / REQUEST CHANGES

[If approving:]
All <N> acceptance criteria met. No blocking issues found.
Ready to merge. Say "merge" to merge, or "leave" to keep open.

[If requesting changes:]
<M> issues must be fixed:
1. <one-line summary of each issue>

Say "request changes" to send this back to the worker, or "override and merge" to
merge despite the findings.
```

Stop here and wait for the human's decision.

---

## Phase 5 - Execute the human's decision

The human will respond with one of the following. Execute immediately:

### "merge" (or "approve and merge")

1. Approve the PR via the GitHub MCP.
   - If approval fails because you are the PR author (GitHub forbids self-approval):
     skip the formal approval; your review comment is the audit trail.
2. Merge the PR via the GitHub MCP - squash preferred. If squash is disabled on the
   repo, retry with a standard merge commit.
   - If merge is rejected by branch protection requiring approvals and you cannot
     self-approve: comment `agent: cannot merge - branch protection requires an
     approval this account cannot give`, leave `in-review`, stop.
3. Confirm the issue was auto-closed (via `Closes #n` in the PR body). If not, close
   it manually via the GitHub MCP.
4. Remove the `in-review` label from the (now closed) issue.
5. Report: `PR #<n> merged. Issue #<n> closed.`

### "request changes" (or "request changes: [specifics]")

1. Post a review via the GitHub MCP requesting changes.
   - If the human specified additional specifics beyond the AI findings: include those.
   - For each problem: quote the unmet criterion, point to the exact file/behaviour,
     suggest the specific fix. Be concrete enough for the next agent to implement
     without questions.
2. Change the **issue** label `in-review` -> `ai-approved`.
   (Back to `ai-approved` - this was already human-approved work, it just needs fixes.)
3. Unassign the issue.
4. Comment on the **issue**:
   ```
   agent: review - changes requested

   Branch: <branch-name>
   PR: #<pr-number>
   What needs fixing: <one line per change - mirror the PR review comments>

   Next agent: check out branch <branch-name>, read PR #<pr-number> review comments,
   implement the fixes, push. Do not open a new PR - the existing one auto-updates.
   ```
5. Report: `PR #<n> has changes requested. Issue #<n> returned to ai-approved.`

### "override and merge"

Same as "merge" - no additional validation required. Human has decided.

### "leave" (or "skip")

Leave the PR as-is in `in-review`. Report: `PR #<n> left open.`

---

## Rules

- **Never trigger this skill automatically.** Human-triggered only.
- **One review per invocation.** Stop after the verdict is executed.
- **Check merge conflicts before approving.** Never approve a PR that cannot be merged.
- **Never request changes for style.** Only for unmet acceptance criteria or clear bugs.
- **Be specific.** Vague feedback is not implementable by the next agent.
- **Never fire MCP calls in parallel.**



