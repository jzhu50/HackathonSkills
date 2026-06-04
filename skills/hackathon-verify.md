---
description: Verify a completed epic end-to-end - rebase epic branch onto main, run the full test suite, check every acceptance criterion, then open a PR from the epic branch to main. Called by hackathon-session when the verify task is ai-approved.
allowed-tools: mcp__github__*, Read, Bash
---

# Skill: hackathon-verify

**The final task for every epic.** Rebases the epic branch, runs the full test suite,
checks every acceptance criterion, then opens the epic->main PR. After all other child
tasks are merged into the epic branch, this task:
1. Rebases the epic branch onto latest main (incorporating any other merged epics)
2. Runs the full test suite
3. Verifies every item in the epic's Acceptance Bar
4. If all pass: opens a PR from the epic branch to main
5. If failures: files bug issues and adds them to the epic's Child Issues

This skill is invoked by `hackathon-session` when it claims a verify task.

---

## Trigger

Called automatically by `hackathon-session` when the claimed task title matches
`[#<epic>] Verify epic end-to-end and merge to main`. Not triggered directly.

---

## GitHub MCP - required for all operations

Every GitHub operation **must** use the GitHub MCP (`mcp__github__*`).
Do not use `gh` CLI, `curl`, or Bash for anything the MCP can handle.
Make all MCP calls **sequentially, not in parallel.**

---

## Step 0 - Read config and confirm claim

Read `hackathon.config.yml`. Extract:
- `gates.epic_review.human_required` (default: `true`)
- `quality.comments` (default: `verbose`)

The verify task issue is already `in-progress` with you as assignee when this
skill starts. Proceed directly to Step 1.

---

## Step 1 - Load the epic

Read via the GitHub MCP:
1. The verify task issue - full body and all comments
2. The parent epic issue (number from `## Parent`) - full body, all comments
   Extract: Goal, Acceptance Bar, Child Issues list
3. `PLAN.md` - relevant feature section and done criteria

Confirm every child issue (except this verify task) is closed. If any are still open:
comment `agent: verify - sibling tasks still open: #<list>. Cannot verify until complete.`
Change label back to `ai-approved`, unassign, stop. (They will be approved by the human
again when actually ready.)

---

## Step 2 - Rebase epic branch onto latest main

```bash
git fetch origin
git checkout epic-<n>-<slug>
git merge --ff-only origin/epic-<n>-<slug>    # get any task PRs merged since last sync
git rebase origin/main                          # incorporate other epics that merged
```

If the rebase has conflicts: resolve them. Favour the epic branch's changes.
After resolving:
```bash
git push --force-with-lease origin epic-<n>-<slug>
```

Comment on the verify task:
```
agent: rebased epic-<n>-<slug> onto main. Conflicts resolved: <list of files or "none">
```

---

## Step 3 - Run the full test suite

```bash
<test command from PLAN.md>
```

Note: pass, fail, and skip counts.

If the suite cannot run (missing deps, config error): treat it as a failure. Follow
the "Failures found" procedure in Step 5 - file a `needs-human-review` bug issue
describing the setup problem, add it to the epic's Child Issues, unassign, stop.

---

## Step 4 - Security audit

Call `hackathon-security-audit` on the epic branch. Review the returned findings report:

- **CRITICAL findings:** do not open the PR. For each CRITICAL finding, create a `bug`
  issue (labeled `needs-human-review`) with the finding details. Append to epic's
  `## Child Issues`. Comment on the verify task listing the blocking issues. Change
  verify task label back to `ai-approved`. Unassign. Stop.
- **HIGH / MEDIUM findings:** note them in the PR body under `## Security notes`.
  Do not block the PR.
- **LOW findings:** create `needs-human-review` issues for each. Do not block the PR.
- **All PASSED:** proceed normally, no additional PR note needed.

## Step 4b - Verify each acceptance criterion

For each criterion in the epic's **Acceptance Bar** section, verify it against the
current state of the epic branch. This may involve:
- Reading implemented code
- Running a specific test or sub-command
- Checking that a route, page, or function exists and behaves as described

For each criterion, record: PASS or FAIL and a one-line note.

---

## Step 5 - Verdict

### All criteria pass and suite is green

1. **If `comments: verbose`:** comment on the verify task:
   ```
   agent: epic verified - all acceptance criteria met

   Test suite: <N> passing, 0 failing
   Criteria checked:
   - [PASS] <criterion 1>
   - [PASS] <criterion 2>
   ...
   ```
   **If `comments: minimal`:** comment: `agent: epic verified - all criteria met, suite green`

2. Open a PR via the GitHub MCP:
   - Title: `[Epic #<n>] <epic title> - ready to merge`
   - Body:
     ```
     Closes #<epic-number>
     Closes #<verify-task-number>

     All acceptance criteria for Epic #<n> are met on the rebased epic branch.

     ## Verification summary
     Test suite: <N> passing, 0 failing
     - [PASS] <criterion 1>
     - [PASS] <criterion 2>
     ...

     ## What this merges
     <brief description of what this epic added to the project>
     ```
   - Base: `main`
   - Head: `epic-<n>-<slug>`

3. Change the verify task label to `in-review` via the GitHub MCP.

4. **If `epic_review.human_required: true`:**

   **If `comments: verbose`:** comment on the **epic** issue:
   ```
   agent: epic verified - PR #<pr-number> opened for merge to main.
   Human: review and merge the PR to close this epic.
   ```
   **If `comments: minimal`:** skip this comment.

   Stop. Return to hackathon-session.

5. **If `epic_review.human_required: false`:**

   Merge the PR via the GitHub MCP (squash preferred). If squash is disabled,
   retry with a standard merge commit.

   If merge is rejected by branch protection requiring approvals that this account
   cannot provide: comment `agent: cannot auto-merge - branch protection requires
   an approval this account cannot give`, leave `in-review`, escalate to human.

   Confirm the epic issue was auto-closed (via `Closes #<epic-number>` in the PR body).
   If not, close it manually via the GitHub MCP.

   Remove the `in-review` label from the (now closed) verify task.

   **If `comments: verbose`:** comment on the epic: `agent: epic merged to main - PR #<pr-number>`
   **If `comments: minimal`:** skip.

   Stop. Return to hackathon-session.

### Failures found (test failures or unmet criteria)

For each failure:

1. **Deduplicate first.** Search open issues for one that already describes this
   failure. If a matching open issue exists, note its number and skip creating a new one.

2. For each genuinely new failure, create a `bug` issue via the GitHub MCP:
   **Title:** `[Epic #<n> verify] <short failure description>`
   **Body:**
   ```
   ## Parent
   #<epic number>

   ## Context
   Epic branch: epic-<n>-<slug>
   Filed during verification of Epic #<n>.

   ## Failure
   <what failed - test name or acceptance criterion>

   ## Expected
   <what was required>

   ## Actual
   <what actually happened>
   ```
   **Labels:** `bug`, `needs-human-review`
   (Human reviews and approves the bug fix before the worker picks it up.)

3. **Append the bug issues to the epic's `## Child Issues` section** via the GitHub MCP:
   ```
   - [ ] #<bug number> [Epic #<n> verify] <short description>
   ```
   This prevents the verify task from re-triggering until the bugs are fixed.

4. Comment on the verify task:
   ```
   agent: epic verification failed

   Test suite: <N> passing, <M> failing
   Criteria:
   - [PASS] <criterion>
   - [FAIL] <criterion> - bug filed: #<issue number>
   ...

   Bug issues filed (needs-human-review): #<list>
   Epic remains in-progress. After bugs are fixed and merged, re-run verify.
   ```

5. Change the verify task label back to `ai-approved` (it will be re-worked after
   bugs are fixed). Unassign yourself from the verify task.

6. Return to hackathon-session. The session will see the verify task as `ai-approved`
   but Step 1 will immediately block on the open bug issues - it will then reach Phase 4
   and report to the human. This is expected: the human reviews and approves the bug
   fixes, the worker implements them, and verify runs again once all siblings are closed.

---

## Step 6 - Check if all epics are done

After a successful merge (or after opening the PR if `epic_review.human_required: true`
and the human has merged), list all open `epic`-labeled issues via the GitHub MCP.

If **all epics are now closed** (none remaining open):
- Call `hackathon-docs-demo-script` automatically.
- This generates the README update, API reference, and demo walkthrough script.

If epics remain open: skip this step and return to hackathon-session.

---

## Rules

- **Never open the epic->main PR without running verification.** Closed child tasks != working epic.
- **Always rebase onto main first.** The epic may be out of date with other merged epics.
- **Never skip the test suite.**
- **Never skip the security audit.** CRITICAL findings block the PR.
- **File bugs as needs-human-review.** Human decides priority before the worker picks them up.
- **Do not close the epic manually.** GitHub auto-closes it via `Closes #<epic-number>` in the PR body.



