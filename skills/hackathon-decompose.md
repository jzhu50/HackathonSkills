---
description: Loop through all ai-approved epics and break each into concrete tasks. Reads config for grilling and human approval gates. Creates the epic branch and a mandatory verify task per epic. Run after setup.
allowed-tools: mcp__github__*, Bash, Read
---

# Skill: hackathon-decompose

**One growing context, all ai-approved epics.** Loops through every epic labeled
`ai-approved` whose dependencies are met, decomposes it into tasks, and continues
until none remain. Gate behavior depends on `hackathon.config.yml`.

---

## GitHub MCP - required for all operations

Every GitHub operation **must** use the GitHub MCP (`mcp__github__*`).
Do not use `gh` CLI, `curl`, or Bash for anything the MCP can handle.
Make all MCP calls **sequentially, not in parallel.**

---

## Trigger

- "Decompose the epics", "Break down the approved epics", "Create tasks"
- Or any instruction to decompose after setup has run.

---

## Phase 0 - Read config

Read `hackathon.config.yml`. Extract and hold for the entire skill:
- `gates.task_breakdown.human_required` (default: `true`)
- `gates.task_breakdown.grilling` (default: `true`)
- `quality.comments` (default: `verbose`)

---

## Phase 1 - Orient

Git sync:
```bash
git fetch origin && git remote prune origin
git checkout main && git merge --ff-only origin/main
```

If `--ff-only` fails: local main diverged. Comment on the tracking issue and stop.

Read sequentially via the GitHub MCP:
1. `AGENTS.md` - coordination protocol
2. `PLAN.md` - vision, stack, features

Then list all open `epic`-labeled issues:
- **Decomposable:** labeled `ai-approved`, AND every issue in `## Dependencies` is closed
- **Skip:** labeled `in-progress` (already decomposed or being decomposed)
- **Skip:** dependencies still open

If no decomposable epics exist: report state and stop.

---

## Phase 2 - Decompose loop

Repeat for each decomposable epic (Wave 1 first, then Wave 2, then Wave 3):

### Step 0 - Claim the epic

Three sequential MCP calls, no other actions between:
1. Add yourself as assignee
2. Change label `ai-approved` -> `in-progress` (keep `epic`)
3. Comment: `agent: decomposing - [github username] - [ISO timestamp]`

**Collision check:** re-read the epic. Two assignees or two decomposing comments
within 2 minutes -> both back off: unassign, reset label `in-progress` -> `ai-approved`,
comment `agent: collision - backing off`, skip to the next epic.

### Step 1 - Create the epic branch

```bash
git checkout main
git checkout -b epic-<n>-<slug>
git push -u origin epic-<n>-<slug>
```

**If `comments: verbose`:** post on the epic: `agent: epic branch created - epic-<n>-<slug>`
**If `comments: minimal`:** skip this comment.

### Step 2 - Load context

Read all of the following via the GitHub MCP before grilling or forming tasks:

1. The epic issue itself - full body, all comments
   - Note the `## Project` field: which GitHub Project this epic belongs to
2. `SPECS.md` if it exists - data models, routes, UI flows relevant to this epic
3. Any issues referenced in the epic body (linked as `#X`)
4. Existing code relevant to this epic (via `get_file_contents` or `get_repository_tree`)

(`PLAN.md` and `AGENTS.md` were already loaded in Phase 1.)

Include the project name in every task's `## Context` section so agents always know
which initiative they are contributing to.

### Step 3 - Grilling (conditional)

**If `grilling: true`:** call `hackathon-grilling` with context:
`"task breakdown for epic #<n>: <epic title>"`.
Use the returned brief when identifying tasks in Step 4.

**If `grilling: false`:** proceed immediately. Make best-guess decisions on ambiguities.

### Step 4 - Identify tasks

A good task is:
- **Completable in one agent session** (a few hours of focused work)
- **Has a single clear output** - a file, a route, a component, a passing test
- **Has all context needed to start cold** - the next agent reads only the issue
  and the linked PLAN.md/SPECS.md sections, nothing else
- **Has clear dependencies** - you know exactly what must be done before it can start

Break the epic into tasks. Use judgment:
- If a task would take more than one session -> split it further
- If two tasks always happen together -> merge them
- If a task depends on an unresolvable open question -> label it `blocked`

Common decomposition patterns:
- **Data layer first:** schema, migrations, models -> then API -> then UI
- **Happy path first:** core feature end-to-end -> then edge cases -> then polish
- **Vertical slices:** one thin slice (data + API + UI) per task

**Every non-trivial feature must have test criteria** folded into each implementation
task's Acceptance Criteria.

**Reserve the last task slot for the mandatory verify task** (Step 5 below).

### Step 5 - Human approval loop (conditional)

**If `human_required: true`:**

Present the proposed task breakdown in chat. Use this format:

```
Proposed tasks for Epic #<n>: <title>

Task 1: <title>
  Goal: <one sentence>
  Depends on: <task numbers or "none">
  Acceptance criteria: <bullet list>

Task 2: <title>
  ...

Verify task: [#<epic>] Verify epic end-to-end and merge to main
  Blocked by: all above tasks

Does this look right? Say "looks good" to proceed, or describe any changes.
```

Wait for the human's response.

- If **"looks good"** (or equivalent) -> proceed to Step 6.
- If **changes requested** -> apply changes to the task plan, then present the updated
  plan again with the same format. Loop until the human explicitly approves.
  Never create GitHub issues without explicit approval.

**If `human_required: false`:** skip this step entirely.

### Step 6 - Create the mandatory verify task

The last task for every epic is always the verify task. Create it first so its
issue number is known when creating sibling tasks' `## Blocked By` sections.

**Title:** `[#<epic>] Verify epic end-to-end and merge to main`

**Body:**
```
## Parent
#<epic issue number>

## Goal
Verify that the entire epic delivers its acceptance bar end-to-end on the epic branch,
then open a PR from the epic branch to main for human review and merge.

## Context
This is the final task for this epic. It runs after all other child tasks are merged
into the epic branch. Before opening the PR:
- Rebase the epic branch onto the latest main (to incorporate other merged epics)
- Run the full test suite on the rebased epic branch
- Verify every item in the epic's Acceptance Bar
- If anything fails: file bug issues (needs-human-review), add to epic Child Issues

Epic branch: epic-<n>-<slug>
Epic acceptance bar: (copy verbatim from the epic issue)

## Acceptance Criteria
- [ ] Epic branch rebased onto latest main
- [ ] Full test suite passes
- [ ] Every item in the epic's Acceptance Bar verified
- [ ] PR opened from epic branch to main with `Closes #<epic-number>` and `Closes #<verify-task-number>`

## Blocked By
blocked-by: #<task-1>, #<task-2>, ... (all other child tasks for this epic - fill in after creating them)
```

**Labels:** `ai-approved`

After creating sibling tasks (Step 7), update this verify task's `## Blocked By`
via the GitHub MCP to list all sibling task issue numbers.

### Step 7 - Create all other task issues

For each task identified in Step 4, create a GitHub issue via the GitHub MCP:

**Title format:** `[#<epic number>] <short imperative description>`
Examples:
- `[#3] Create users table and migration`
- `[#3] Implement POST /api/auth/login endpoint`

**Body format:**
```
## Parent
#<epic issue number>

## Goal
<One sentence starting with a verb. What does done look like?>

## Context
<Everything the next agent needs to start cold:
- Epic branch: epic-<n>-<slug>
- Relevant file paths
- Which part of PLAN.md / SPECS.md applies
- Decisions already made that constrain this task
- What the task above this one will have left in place
- Stub contracts this task depends on or must implement (if parallelism: true epic)>

## Acceptance Criteria
- [ ] <specific, verifiable thing>
- [ ] <specific, verifiable thing>
- [ ] Tests written for new behavior
- [ ] Full test suite passes

## Blocked By
<If blocked: blocked-by: #<issue number>. Otherwise delete this section.>
```

**Labels:**
- `ai-approved`
- If the task has a `## Blocked By` section: also add `blocked`

### Step 8 - Update verify task blocked-by

After all sibling tasks are created, update the verify task's `## Blocked By` section
via the GitHub MCP to include all sibling issue numbers.

### Step 9 - Update the epic issue

After all tasks are created, update the epic issue body via the GitHub MCP.

Add or replace `## Child Issues`:
```
## Child Issues
- [ ] #<n> [#<epic>] <task title>
- [ ] #<n> [#<epic>] <task title>
- [ ] #<n> [#<epic>] Verify epic end-to-end and merge to main
```

Epic label stays `in-progress` (children are being worked). Unassign yourself.

**If `comments: verbose`:**
```
agent: decomposed into <N> tasks
Epic branch: epic-<n>-<slug>
Tasks (all ai-approved): #<n>, #<n>, ...
Verify task (last, blocked by all): #<n>
```

**If `comments: minimal`:**
```
agent: decomposed into <N> tasks - #<list>
```

### Step 10 - Update the tracking issue

**If `comments: verbose`:** comment via the GitHub MCP:
```
Epic #<n> decomposed: <N> tasks created. All labeled ai-approved.
Epic branch: epic-<n>-<slug>
```

**If `comments: minimal`:** skip this comment.

---

## Phase 3 - After all epics decomposed

**If `comments: verbose`:**
```
Decomposition complete.

Epics processed: <list>
Total tasks created: <N> (all labeled ai-approved)

Next steps:
Run /hackathon-session to begin implementation.
```

**If `comments: minimal`:**
```
Decomposition complete. <N> tasks created across <M> epics.
```

---

## Rules

- **Never** decompose an epic before its `## Dependencies` are all closed.
- **Never** skip creating the verify task - it is mandatory for every epic.
- **Always** claim the epic before decomposing to prevent duplicate task creation.
- **Always** include the epic branch name in every task's `## Context` section.
- **Always** reset the label to `ai-approved` on collision back-off, not leave it `in-progress`.
- **When human_required: true and changes requested:** apply changes and re-present.
  Never create issues without explicit "looks good" or equivalent.

**Before finishing each epic's decomposition, verify every task:**
- Can an agent start this with zero additional context beyond the issue + PLAN.md?
- Is the output verifiable?
- Is the scope small enough to finish in one session?
- Are dependencies between tasks correct and complete?
- Does every task include test criteria?
- Is the verify task last, blocked by every other task?



