---
description: Debug and fix a bug-labeled ready issue — reproduce, diagnose, fix, write regression test, PR. Called from hackathon-session when a ready issue carries the `bug` label.
allowed-tools: mcp__github__*, Read, Write, Edit, Bash
---

# Skill: hackathon-debug

Fix one bug per invocation. Claim → reproduce → diagnose root cause → minimal fix → regression test → suite green → PR.

---

## GitHub MCP — required for all GitHub operations

Every GitHub operation must use the GitHub MCP (`mcp__github__*`).
Make all MCP calls sequentially, not in parallel.

---

## Trigger

- `hackathon-session` Phase 2 routes here when a `ready` issue carries the `bug` label
- Human: "Fix bug #N", "Debug this", "Pick up the bug"

---

## Step 1 — Claim

Three sequential MCP calls, no other actions between them:
1. Add yourself as assignee
2. Change label `ready` → `in-progress` (keep `bug` label)
3. Comment: `agent: claiming bug — [github username] — [ISO timestamp]`

Collision check (multi-agent only): re-read the issue. Two assignees or two claiming comments within 2 minutes → unassign, comment `agent: collision — backing off`, pick a different issue.

Create a branch:
```bash
git checkout main && git pull origin main
git checkout -b <issue-number>-bug-<short-slug>
```

---

## Step 2 — Understand the bug

Read the full issue body and all comments via the GitHub MCP.

Extract:
- Expected behavior
- Actual (broken) behavior
- Steps to reproduce or test that fails
- File paths or stack traces mentioned

Read the relevant source files. Trace the code path where the bug lives before touching anything.

---

## Step 3 — Reproduce

Before writing any fix, confirm the bug is reproducible:
- Run the steps from the issue, or run the failing test specifically
- If you cannot reproduce: comment explaining what you tried, change label to `blocked`, unassign, stop

---

## Step 4 — Diagnose

Identify the exact line(s) causing the failure. Fix the root cause, not the symptom.

Comment on the issue via the GitHub MCP before writing any code:
```
agent: reproducing — root cause identified

Root cause: <one sentence>
Fix approach: <one sentence>
Files to change: <list>
```

---

## Step 5 — Fix

Implement the minimal fix for the root cause. Do not refactor or expand scope beyond what is needed to fix this bug.

---

## Step 6 — Regression test

Write a test that:
1. Would have failed before your fix (proves the bug existed)
2. Passes after your fix (proves it's resolved)

Use the project's existing test framework. Check SPECS.md or existing test files for the framework in use. If no framework exists, write the test file and note in the PR that a framework needs to be added.

---

## Step 7 — Verify

Run the full test suite:
```bash
<test command from PLAN.md Stack table>
```

All tests must pass. If a pre-existing test is newly broken, fix it and note it in the PR body — do not ship a fix that breaks other things.

---

## Step 8 — Close out

Follow Phase 3 of `hackathon-session` exactly:
1. Push the branch
2. Open a PR via the GitHub MCP:
   - Title: `Fix: <bug title>`
   - Body: `Closes #<issue number>` on its own line, then: root cause, fix summary, regression test location
3. Change issue label to `in-review` via the GitHub MCP
4. Comment on the issue:
   ```
   agent: done — PR #<number> open for review

   Root cause: <one sentence>
   Fix: <one sentence>
   Regression test: <test name / file>
   PR: #<number>
   ```
5. Stop.

---

## Rules

- **Reproduce before fixing.** A fix without reproduction is a guess.
- **Root cause only.** Do not refactor surrounding code.
- **Regression test is not optional.** No regression test = the bug can come back silently.
- **Suite must be green before PR.** Fix collateral failures or stop and note them.
