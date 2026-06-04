---
description: Loop through all ai-approved epics and break each into concrete tasks with needs-human-review. Creates the epic branch and a mandatory verify task per epic. Run after human approves epics.
allowed-tools: mcp__github__*, Bash
---

# Skill: hackathon-decompose

**One growing context, all ai-approved epics.** This skill loops through every epic
labeled `ai-approved` whose dependencies are met, decomposes it into tasks, and
continues until none remain. Tasks are created with `needs-human-review` — a human
must approve them before the task worker can pick them up.

---

## GitHub MCP — required for all operations

Every GitHub operation **must** use the GitHub MCP (`mcp__github__*`).
Do not use `gh` CLI, `curl`, or Bash for anything the MCP can handle.
Make all MCP calls **sequentially, not in parallel.**

---

## Trigger

- "Decompose the epics", "Break down the approved epics", "Create tasks"
- Or any instruction to decompose after human has approved epics.

---

## Phase 1 — Orient

Git sync:
```bash
git fetch origin && git remote prune origin
git checkout main && git merge --ff-only origin/main
```

If `--ff-only` fails: local main diverged. Comment on the tracking issue and stop.

Read sequentially via the GitHub MCP:
1. `AGENTS.md` — coordination protocol
2. `PLAN.md` — vision, stack, features

Then list all open `epic`-labeled issues:
- **Decomposable:** labeled `ai-approved`, AND every issue in `## Dependencies` is closed
- **Skip:** labeled `needs-human-review` (awaiting human approval)
- **Skip:** labeled `in-progress` (already decomposed or being decomposed)
- **Skip:** dependencies still open

If no decomposable epics exist: report state and stop.

---

## Phase 2 — Decompose loop

Repeat for each decomposable epic (pick in dependency order, earliest deps first):

### Step 0 — Claim the epic

Three sequential MCP calls, no other actions between:
1. Add yourself as assignee
2. Change label `ai-approved` → `in-progress` (keep `epic`)
3. Comment: `agent: decomposing — [github username] — [ISO timestamp]`

**Collision check:** re-read the epic. Two assignees or two decomposing comments
within 2 minutes → both back off: unassign, reset label `in-progress` → `ai-approved`,
comment `agent: collision — backing off`, skip to the next epic.

### Step 1 — Create the epic branch

```bash
git checkout main
git checkout -b epic-<n>-<slug>
git push -u origin epic-<n>-<slug>
```

Post a comment on the epic via the GitHub MCP:
```
agent: epic branch created — epic-<n>-<slug>
```

### Step 2 — Load context

Read all of the following via the GitHub MCP before forming any tasks:

1. The epic issue itself — full body, all comments
2. `PLAN.md` — especially the relevant feature section and open questions
3. `SPECS.md` if it exists — data models, routes, UI flows relevant to this epic
4. Any issues referenced in the epic body (linked as `#X`)
5. Existing code relevant to this epic (via `get_file_contents` or `get_repository_tree`)

Do not start decomposing until you have read all of the above.

### Step 3 — Identify tasks

A good task is:
- **Completable in one agent session** (a few hours of focused work)
- **Has a single clear output** — a file, a route, a component, a passing test
- **Has all the context needed to start cold** — the next agent reads only the issue
  and the linked PLAN.md/SPECS.md sections, nothing else
- **Has clear dependencies** — you know exactly what must be done before it can start

Break the epic into tasks. Use judgment:
- If a task would take more than one session → split it further
- If two tasks always happen together → merge them
- If a task depends on an unresolvable open question → label it `blocked`

Common decomposition patterns:
- **Data layer first:** schema, migrations, models → then API → then UI
- **Happy path first:** core feature end-to-end → then edge cases → then polish
- **Vertical slices:** one thin slice (data + API + UI) per task

**Every non-trivial feature must have a test task** (or test criteria folded into
the implementation task). Every task's acceptance criteria must include the testing bar.

**Reserve the last task slot for the mandatory verify task** (Step 4 below).

### Step 4 — Create the mandatory verify task

The last task for every epic is always the verify task. Create it after all other
tasks are created, so its `## Blocked By` can reference all sibling tasks.

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
- [ ] PR opened from epic branch to main with `Closes #<verify-task-number>`

## Blocked By
blocked-by: #<task-1>, #<task-2>, ... (all other child tasks for this epic)
```

**Labels:** `needs-human-review`

### Step 5 — Create all other task issues

For each task (except the verify task), create a GitHub issue via the GitHub MCP:

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
- What the task above this one will have left in place>

## Acceptance Criteria
- [ ] <specific, verifiable thing>
- [ ] <specific, verifiable thing>
- [ ] Tests written for new behavior
- [ ] Full test suite passes

## Blocked By
<If blocked: blocked-by: #<issue number>. Otherwise delete this section.>
```

**Labels:**
- `needs-human-review` — all tasks start here; human approves before work begins

**Do not assign** any tasks — agents claim them during session start.

### Step 6 — Update the epic issue

After all tasks are created, update the epic issue body via the GitHub MCP.

Add or replace `## Child Issues`:

```
## Child Issues
- [ ] #<n> [#<epic>] <task title>
- [ ] #<n> [#<epic>] <task title>
- [ ] #<n> [#<epic>] Verify epic end-to-end and merge to main
```

Epic label stays `in-progress` (children are being worked). Unassign yourself.

Comment on the epic:
```
agent: decomposed into <N> tasks
Epic branch: epic-<n>-<slug>
Tasks (all need-human-review): #<n>, #<n>, ...
Verify task (last): #<n>
Human: review and approve tasks with `ai-approved` label when ready
```

### Step 7 — Update the tracking issue

Comment via the GitHub MCP:
```
Epic #<n> decomposed: <N> tasks created. All labeled needs-human-review.
Epic branch: epic-<n>-<slug>
```

---

## Phase 3 — After all epics decomposed

Report:

```
Decomposition complete.

Epics processed: <list>
Total tasks created: <N> (all labeled needs-human-review)

Next steps for the human:
Review each task issue and add `ai-approved` to any task ready to be implemented.
Blocked tasks will unblock automatically when their dependencies close; they will
then be moved to needs-human-review for your review.
```

---

## Rules

- **Never** decompose an epic before its `## Dependencies` are all closed.
- **Never** assign tasks — agents claim them when the session loop runs.
- **Never** skip creating the verify task — it is mandatory for every epic.
- **Always** claim the epic before decomposing to prevent duplicate task creation.
- **Always** include the epic branch name in every task's `## Context` section.
- **Always** reset the label to `ai-approved` on collision back-off, not leave it `in-progress`.

**Before finishing each epic's decomposition, verify every task:**
- Can an agent start this with zero additional context beyond the issue + PLAN.md?
- Is the output verifiable?
- Is the scope small enough to finish in one session?
- Are dependencies between tasks correct and complete?
- Does every task include test criteria?
- Is the verify task last, blocked by every other task?
