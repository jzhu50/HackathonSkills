---
description: Run the test suite and report results with expected vs actual output per test. Called by hackathon-session at baseline (before implementation) and throughout implementation. Also callable by humans.
allowed-tools: mcp__github__*, Read, Bash
---

# Skill: hackathon-test

**Reports results and returns — never makes decisions.** Runs the full test suite and
outputs what was expected, what actually happened, and which failures are new vs
pre-existing. The caller (`hackathon-session`) decides what to do with the results.

---

## GitHub MCP — required for all operations

Every GitHub operation **must** use the GitHub MCP (`mcp__github__*`).
Do not use `gh` CLI, `curl`, or Bash for anything the MCP can handle.
Make all MCP calls **sequentially, not in parallel.**

---

## Trigger

- `hackathon-session` at start of each task (mode: `baseline`)
- `hackathon-session` during or after implementation (mode: `check`)
- Human: "Run the tests", "Check what's failing", "What's the test status"

---

## Step 1 — Find the test command

Check in order:
1. `PLAN.md` Stack table — "Test command" row
2. `SPECS.md` — setup or environment section
3. Common defaults: `npm test`, `pytest`, `go test ./...`, `cargo test`, `bundle exec rspec`

If no test command can be determined: report "no test command found" and stop.
(A project with no test command should make establishing one its first task.)

---

## Step 2 — Run the suite

```bash
<test command>
```

Capture all output. For each test, extract:
- Test name or description
- Status: PASS or FAIL
- If FAIL: error message, assertion failure, file path, line number

---

## Step 3 — Report

Output the results in this format:

```
Test run — <mode: baseline / check>
Command: <test command>
Result: <N> passing, <M> failing, <K> skipped

[If M > 0:]
FAILING TESTS:
- <test name>
  Expected: <what the test asserts>
  Actual:   <what happened — error/assertion output>
  File:     <path:line if available>

- <test name>
  Expected: <what the test asserts>
  Actual:   <what happened>
  ...

[If mode is "check" and baseline exists:]
NEW FAILURES (were passing at baseline):
  <list of test names — these need debugging>

PRE-EXISTING FAILURES (also failing at baseline):
  <list of test names — not your responsibility unless the task covers them>
```

---

## Step 4 — Return result to caller

Do not file issues or make decisions.

Return the result summary to `hackathon-session`. The session skill decides:
- If new failures exist → call `hackathon-debug`
- If only pre-existing failures → note and continue
- If suite is green → proceed to PR

When called by a human directly: just present the report above and stop.

---

## Rules

- **Never** file issues, change labels, or take action on failures — report only.
- **Never** emit loop signals or close-out comments.
- **Always** distinguish new failures from pre-existing ones when a baseline exists.
- **Always** include file path and line number in failure output when available.
