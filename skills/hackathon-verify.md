---
description: Verify an epic end-to-end after all its child tasks are merged — runs the test suite, checks each acceptance criterion, then closes the epic or files bugs. Called when an epic's last task merges, or triggered directly.
allowed-tools: mcp__github__*, Read, Bash
---

# Skill: hackathon-verify

**One epic per invocation.** After all child tasks have been merged into `main`, verify
that the epic as a whole delivers what it promised. Individual tasks passing their own
tests is necessary but not sufficient — this checks the integrated result.

---

## GitHub MCP — required for all GitHub operations

Every GitHub operation must use the GitHub MCP (`mcp__github__*`).
Make all MCP calls sequentially, not in parallel.

---

## Trigger

- `hackathon-session` Phase 2: agent notices an `epic` issue whose Child Issues checklist
  is fully checked (all child tasks closed) but the epic itself is still open
- Human: "Verify epic #N", "Check epic #N is done", "Run acceptance tests for #N"

---

## Step 0 — Claim the epic before verifying

Verification is the **highest-priority** path, so the moment an epic's last child merges
every idle machine would otherwise pick the same epic and all run the suite, all file
duplicate bugs, and all try to close it. Claim first to serialise it.

Three sequential MCP calls, no other actions between:
1. Add yourself as assignee to the epic
2. Comment on the epic: `agent: verifying — [github username] — [ISO timestamp]`
3. Re-read the epic (collision check): another `agent: verifying` comment within 2 minutes,
   or one already present and < 30 min old from a different agent → back off: unassign,
   comment `agent: verify collision — backing off`, stop. (Do not add a label; the
   `agent: verifying` comment is the claim. A claim older than 30 minutes is treated as
   stale and the epic becomes verifiable again — that is the crash-recovery path.)

---

## Step 1 — Load the epic

Read via the GitHub MCP:
1. The epic issue — full body and all comments — extract: Goal, Context, Acceptance Bar,
   Child Issues list
2. `PLAN.md` — relevant feature section and done criteria
3. `SPECS.md` — any relevant contracts or flows for this feature

Confirm every child issue is closed. If any are still open (race with a just-merged PR),
comment `agent: verify — child issues still open: #<list>, releasing`, unassign yourself,
and stop. Do not emit a loop signal — return to hackathon-session, which owns that decision.

---

## Step 2 — Sync latest main

Use the same fetch + fast-forward form as the rest of the protocol (never a plain
`git pull`, which can create a merge commit):

```bash
git fetch origin
git checkout main
git merge --ff-only origin/main
```

---

## Step 3 — Run the full test suite

```bash
<test command from PLAN.md Stack table>
```

Note: pass, fail, and skip counts. If the suite cannot run (missing dependencies,
config error), treat it as a failure: follow the "Failures found" procedure in Step 5
(dedupe, file a `bug` + `ready` issue describing the setup problem, add it to the epic's
Child Issues, unassign yourself), then stop.

---

## Step 4 — Verify each acceptance criterion

For each criterion in the epic's **Acceptance Bar** section, verify it against the
current state of `main`. This may involve:
- Reading the implemented code
- Running a specific test or sub-command
- Checking that a route, page, or function exists and behaves as described

For each criterion, record: PASS or FAIL, and a one-line note.

---

## Step 5 — Verdict

### All criteria pass and suite is green

1. Comment on the epic via the GitHub MCP:
   ```
   agent: epic verified — all acceptance criteria met

   Test suite: <N> passing, 0 failing
   Criteria checked:
   - [PASS] <criterion 1>
   - [PASS] <criterion 2>
   ...

   Closing epic.
   ```
2. Close the epic issue via the GitHub MCP.
3. Comment on the `[Project] Tracking` issue:
   ```
   Epic #<n> verified and closed. All acceptance criteria met.
   ```
4. Stop.

### Failures found (test failures or unmet criteria)

For each failure:

1. **Deduplicate first.** Search open issues via the GitHub MCP for one that already
   describes this failure (by test name, criterion, or error keyword). If a matching open
   issue exists, do **not** file another — note its number and move on. (Without this,
   every machine that reaches Path 0 before the bug is fixed would file the same bug again.)

2. For each genuinely new failure, create a `bug` + `ready` GitHub issue via the GitHub MCP:
   **Title:** `[Epic #<n> verify] <short failure description>`
   **Body:**
   ```
   ## Linked Epic
   #<epic number>

   ## Failure
   <what failed — test name or acceptance criterion>

   ## Expected
   <what was required>

   ## Actual
   <what actually happened>
   ```

3. **Append the new bug issues to the epic's `## Child Issues` section** via the GitHub MCP,
   in the exact tracked format:
   ```
   - [ ] #<bug number> [Epic #<n> verify] <short description>
   ```
   This is essential: Path 0 re-fires only when **every** linked child issue is closed, so
   adding the open bugs as children makes the epic no longer "complete" and stops Path 0 from
   re-verifying on a loop. When the bugs are fixed and their PRs merge, the children are all
   closed again and Path 0 re-verifies automatically.

4. Comment on the epic:
   ```
   agent: epic verification failed

   Test suite: <N> passing, <M> failing
   Criteria:
   - [PASS] <criterion>
   - [FAIL] <criterion> — bug filed: #<issue number>
   ...

   Filed/linked bugs added to Child Issues. Epic remains open until they are resolved.
   ```

5. Unassign yourself from the epic (release the verifying claim). Do **not** close the epic —
   it stays open until the bug issues are resolved and verification re-runs. Stop.

---

## Integration into the session loop

`hackathon-session` Phase 1 should check for epics whose child issues are all closed
but the epic itself is still open. This is detected by reading each `epic`-labeled issue
and comparing its Child Issues checklist against closed issue state.

If such an epic is found, treat epic verification as the highest-value action — higher
priority than picking up a new task. A passing epic is worth more than a new feature
started.

Add to the session Phase 2 priority order, above Path A:

> **Path 0 — Verify completed epic** (before all other work)
> Condition: an `epic`-labeled issue is open AND all its child issues are closed.
> Follow `hackathon-verify` steps. Stop after verification.

---

## Rules

- **Never close an epic without running verification.** Closed child tasks ≠ working epic.
- **Never skip the test suite.** Even if all criteria appear met visually, run the suite.
- **One epic per invocation.** Stop after verdict.
- **File bugs — don't leave failures as comments.** Bugs must be tracked issues so the
  loop can pick them up.
