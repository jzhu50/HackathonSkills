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

## Step 1 — Load the epic

Read via the GitHub MCP:
1. The epic issue — full body and all comments — extract: Goal, Context, Acceptance Bar,
   Child Issues list
2. `PLAN.md` — relevant feature section and done criteria
3. `SPECS.md` — any relevant contracts or flows for this feature

Confirm every child issue is closed. If any are still open, stop: comment on the epic
`agent: verify — blocked, child issues still open: #<list>` and output `NOTHING_TO_DO`.

---

## Step 2 — Pull latest main

```bash
git checkout main
git pull origin main
```

---

## Step 3 — Run the full test suite

```bash
<test command from PLAN.md Stack table>
```

Note: pass, fail, and skip counts. If the suite cannot run (missing dependencies,
config error), create a `bug` + `ready` issue describing the setup problem and stop.

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
1. Create a `bug` + `ready` GitHub issue via the GitHub MCP:
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
2. After creating all bug issues, comment on the epic:
   ```
   agent: epic verification failed

   Test suite: <N> passing, <M> failing
   Criteria:
   - [PASS] <criterion>
   - [FAIL] <criterion> — bug filed: #<issue number>
   ...

   Epic remains open until bugs are resolved.
   ```
3. Do not close the epic — it stays open until the bug issues are resolved and
   verification is re-run.
4. Stop.

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
