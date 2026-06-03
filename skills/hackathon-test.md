---
description: Run the test suite when the loop is idle — discovers bugs and creates ready issues for each failure. Called from hackathon-session Path D when no tasks, epics, or PRs exist.
allowed-tools: mcp__github__*, Read, Bash
---

# Skill: hackathon-test

When the agent loop has nothing to claim (no `ready` tasks, no `needs-scoping` epics, no `in-review` PRs), run the full test suite to proactively discover broken behavior. Create a `bug` + `ready` issue for each new failure.

---

## GitHub MCP — required for all GitHub operations

Every GitHub operation must use the GitHub MCP (`mcp__github__*`).
Make all MCP calls sequentially, not in parallel.

---

## Trigger

- `hackathon-session` Phase 2 Path D (nothing else to do)
- Human: "Run the tests", "Check for bugs", "What's broken"

---

## Step 1 — Find the test command

Check in order:
1. PLAN.md Stack table — "Test command" row
2. SPECS.md — setup or environment section
3. Common defaults: `npm test`, `pytest`, `go test ./...`, `cargo test`, `bundle exec rspec`

If no test command can be determined: report "no test command found — cannot run the suite"
and stop. Do not emit a loop signal — hackathon-session Path E owns the `NOTHING_TO_DO` /
`WAITING_FOR_PEERS` decision. (A project with no test command should make establishing one
its first task — see AGENTS.md Testing protocol.)

---

## Step 2 — Clean baseline

Use fetch + fast-forward (never a plain `git pull`, which can create a merge commit):

```bash
git fetch origin
git checkout main
git merge --ff-only origin/main
```

---

## Step 3 — Run the suite

```bash
<test command>
```

Capture all output. For each failing test, extract:
- Test name or description
- Error message and assertion failure
- File path and line number (if shown)

---

## Step 4 — Deduplicate against existing issues

For each failing test, search via the GitHub MCP for an existing open issue that already describes this failure (to avoid duplicates). Search by test name or error keyword.

---

## Step 5 — Create bug issues

For each new failure (no existing open issue), create one GitHub issue via the GitHub MCP:

**Title:** `[Bug] <test name or short failure description>`

**Body:**
```
## Symptom
<test name, assertion that failed, error message>

## Steps to reproduce
Run: `<test command>`
Test: `<failing test name>`

## Expected
<what the test asserts should happen>

## Actual
<what actually happened — error output verbatim>

## Source context
<file path and line number if available>
```

**Labels:** `bug`, `ready`

One issue per distinct failure.

---

## Step 6 — Report

After creating all issues (or confirming no new failures), output:

```
Test run complete.
  Command: <test command>
  Result: <N> passing, <M> failing
  New bug issues created: <list of #N titles, or "none">
```

**Do not emit a loop signal from this skill.** When run inside the loop, return this result
to hackathon-session: if new bugs were filed, that was the unit of work (the loop claims them
next cycle); if the suite is fully green with no new bugs, Path E decides between
`WAITING_FOR_PEERS` (peers still working) and `NOTHING_TO_DO` (project complete). Emitting
`NOTHING_TO_DO` here would wrongly signal "done" while a peer is mid-task.

Stop after reporting — do not claim any of the newly created bug issues in this invocation.
