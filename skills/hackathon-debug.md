---
description: Debug and fix a failing test or bug — reproduce, diagnose root cause, apply minimal fix, verify suite is green. Called automatically by hackathon-session when tests regress, or directly for bug-labeled issues.
allowed-tools: mcp__github__*, Read, Write, Edit, Bash
---

# Skill: hackathon-debug

**Reproduce → root cause → minimal fix → suite green.** Fix one failure per
invocation and return the result to the caller. Never expands scope beyond the
failing test or bug.

This skill is called automatically by `hackathon-session` when a test that was passing
at baseline starts failing. It is also the skill used for `bug`-labeled issues.

---

## GitHub MCP — required for all operations

Every GitHub operation **must** use the GitHub MCP (`mcp__github__*`).
Do not use `gh` CLI, `curl`, or Bash for anything the MCP can handle.
Make all MCP calls **sequentially, not in parallel.**

---

## Trigger

- `hackathon-session` calls this automatically when a new test failure is detected
  during implementation (a regression relative to the baseline)
- `hackathon-session` routes to this when a `ai-approved` issue has the `bug` label
- Human: "Fix bug #N", "Debug this failure", "What's causing this test to fail"

---

## Mode A — Regression during implementation (called by hackathon-session)

The session has detected a test that was passing at baseline is now failing. The
session passes the failing test name and the current branch state.

### A1. Reproduce

Run the specific failing test in isolation:
```bash
<test command targeting the specific test>
```

If you cannot reproduce: report `agent: debug — cannot reproduce; test may be flaky.
Re-running: <attempt count>`. Try up to 3 times. If still cannot reproduce, report
and return `INCONCLUSIVE` to the session.

### A2. Diagnose

Read the relevant source files and trace the code path where the failure originates.
Identify the exact line(s) causing the failure. Fix the root cause, not the symptom.

Report before touching code:
```
Root cause: <one sentence>
Fix approach: <one sentence>
Files to change: <list>
```

### A3. Fix

Implement the minimal fix for the root cause. Do not refactor or expand scope beyond
what is needed to fix this failure.

### A4. Verify

Run the full test suite:
```bash
<test command>
```

All tests that were passing at baseline must pass. If the fix introduced new failures:
repeat the diagnose/fix cycle for those. Do not return until the suite is clean
relative to the baseline.

### A5. Return result to hackathon-session

Report:
```
Debug complete — regression fixed.
Root cause: <one sentence>
Fix: <one sentence>
Files changed: <list>
Suite status: <N> passing (matches baseline)
```

If after reasonable effort (3 fix attempts) the regression cannot be fixed:
Report:
```
Debug failed — regression could not be fixed within 3 attempts.
Failing test: <name>
Last attempt: <what was tried and why it didn't work>
```
The session will then include this in the PR body as a known issue.

---

## Mode B — Bug-labeled issue (called by hackathon-session routing)

The issue is already claimed (`in-progress`) by hackathon-session. Proceed directly.

### B1. Understand the bug

Read the full issue body and all comments via the GitHub MCP.
Extract: expected behavior, actual behavior, steps to reproduce, file paths.
Read the relevant source files. Trace the code path before touching anything.

### B2. Reproduce

Before writing any fix, confirm the bug is reproducible:
```bash
<steps from the issue, or the failing test>
```

If you cannot reproduce: comment explaining what you tried, change label `in-progress`
→ `blocked`, unassign. Return to hackathon-session.

### B3. Diagnose

Comment on the issue via the GitHub MCP before writing code:
```
agent: reproducing — root cause identified

Root cause: <one sentence>
Fix approach: <one sentence>
Files to change: <list>
```

### B4. Fix

Implement the minimal fix. Do not refactor or expand scope.

### B5. Regression test

Write a test that:
1. Would have failed before your fix (proves the bug existed)
2. Passes after your fix (proves it's resolved)

Use the project's existing test framework.

### B6. Verify

Run the full test suite. All tests must pass. If a pre-existing test is newly broken,
fix it and note it in the PR body.

### B7. Close out

Follow hackathon-session Phase 3:
1. Push the branch
2. Open a PR via the GitHub MCP:
   - Title: `Fix: <bug title>`
   - Body: `Closes #<issue number>`, then: root cause, fix summary, regression test location
   - Base: the **epic branch** for this issue
3. Change issue label to `in-review`
4. Comment on the issue:
   ```
   agent: done — PR #<number> open for review

   Root cause: <one sentence>
   Fix: <one sentence>
   Regression test: <test name / file>
   PR: #<number>
   ```
5. Return to hackathon-session loop.

---

## Rules

- **Reproduce before fixing.** A fix without reproduction is a guess.
- **Root cause only.** Do not refactor surrounding code.
- **Regression test is mandatory for bug-labeled issues.** It proves the fix.
- **Suite must be clean relative to baseline before PR.**
- **Return result to caller in Mode A.** Do not close out or stop the session.
