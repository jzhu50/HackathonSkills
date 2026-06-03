---
description: Break a needs-scoping epic into concrete, ready task issues via the GitHub MCP. Called automatically by hackathon-session or triggered directly.
allowed-tools: mcp__github__*
---

# Skill: hackathon-decompose

Use this skill whenever an issue labeled `needs-scoping` needs to be broken into
concrete, workable tasks. This is what turns a vague epic into things agents can
actually pick up and complete in a single session.

This skill is called from within hackathon-session when no `ready` issues exist,
but can also be triggered directly by a human.

---

## GitHub MCP — required for all operations

Every GitHub operation in this skill **must** use the GitHub MCP (`mcp__github__*`):
reading issues, creating issues, updating issue bodies, adding labels, posting comments.

Do not use the `gh` CLI, `curl`, or any Bash command for anything the MCP can handle.

---

## Trigger

- The session skill reaches Phase 2 and finds no `ready` issues — only `needs-scoping`
- A human says something like:
  - "Break down this epic"
  - "Decompose issue #X"
  - "Turn this into tasks"
  - "What are the subtasks for #X?"

---

## Step 0 — Claim the epic before decomposing

Two machines can both see the same `needs-scoping` epic and both start decomposing,
producing duplicate task issues. Claim the epic first to prevent this.

Pick one `needs-scoping` epic at **random** from those available — not the oldest.

Three sequential MCP calls, no other actions between:
1. Add yourself as assignee to the epic
2. Add label `in-progress` to the epic (keep `needs-scoping` and `epic` labels for now)
3. Comment on the epic: `agent: decomposing — [github username] — [ISO timestamp]`

**Collision check:** re-read the epic. Two assignees or two decomposing comments within
2 minutes → unassign, comment `agent: collision — backing off`, pick a different epic.

---

## Step 1 — Load context

Read all of the following via the GitHub MCP before forming any tasks:

1. The epic issue itself — full body, all comments
2. `PLAN.md` — especially the relevant feature section and open questions
3. `SPECS.md` if it exists — data models, routes, UI flows relevant to this epic
4. Any issues referenced in the epic body (linked as `#X`)
5. If the epic touches existing code, use `get_file_contents` or `get_repository_tree`
   (GitHub MCP) to understand what already exists

Do not start decomposing until you have read all of the above.

---

## Step 2 — Identify tasks

A good task is:
- **Completable in one agent session** (a few hours of focused work)
- **Has a single clear output** — a file, a route, a component, a passing test
- **Has all the context needed to start cold** — the next agent reads only the issue
  and the linked PLAN.md/SPECS.md sections, nothing else
- **Has clear dependencies** — you know exactly what must be done before it can start

Break the epic into tasks along these lines. Use judgment:
- If a task would take more than one session → split it further
- If two tasks always need to happen together → merge them
- If a task depends on a genuinely unresolvable open question → label it `blocked`,
  not `ready`. **Do not stop to ask the human** — file a `blocked` issue, document
  what you need resolved, and continue decomposing the rest. The AFK loop cannot
  accommodate interactive clarification mid-run.

Common decomposition patterns:
- **Data layer first:** schema, migrations, models → then API → then UI
- **Happy path first:** core feature working end-to-end → then edge cases → then polish
- **Vertical slices:** one complete thin slice (data + API + UI) per task

**Always include a testing task** for each non-trivial feature. The test task may be
folded into the implementation task (when the implementation is small) or created as
its own task. Every task's acceptance criteria must include the testing bar.

---

## Step 3 — Create task issues

For each task, create a GitHub issue via the GitHub MCP:

**Title format:** `[#<epic number>] <short imperative description>`
Examples:
- `[#3] Create users table and migration`
- `[#3] Implement POST /api/auth/login endpoint`
- `[#3] Build login form component`

**Body format:**
```
## Parent
#<epic issue number>

## Goal
<One sentence. Start with a verb. "Implement...", "Create...", "Add...", "Fix...">
What does done look like? What can you verify when it's complete?

## Context
<Everything the next agent needs to start cold. Be specific:
- Relevant file paths
- Which part of PLAN.md / SPECS.md applies
- Decisions already made that constrain this task
- What the task above this one in the dependency chain will have left in place>

## Acceptance Criteria
- [ ] <specific, verifiable thing>
- [ ] <specific, verifiable thing>
- [ ] Tests written for new behavior (unit or integration, using the project's test framework)
- [ ] Full test suite passes (`<test command from PLAN.md>`)

## Blocked By
<If this task cannot start until another is done: "blocked-by: #<issue number>".
Otherwise delete this section.>
```

**Labels:**
- `ready` — if this task can be started immediately (no blockers)
- `blocked` — if it depends on another task that isn't done yet; add a comment:
  `blocked-by: #<issue number>`

**Do not assign** any tasks — agents claim them during session start.

---

## Step 4 — Update the epic issue

After all tasks are created, update the epic issue body via the GitHub MCP.

Add a `## Child Issues` section (or replace the placeholder if it exists):

```
## Child Issues
- [ ] #<n> [#<epic>] <task title>
- [ ] #<n> [#<epic>] <task title>
- [ ] #<n> [#<epic>] <task title>
```

Change the epic's labels via the GitHub MCP: remove `needs-scoping` and `in-progress`, keep `epic`. Unassign yourself from the epic.

Add a comment to the epic via the GitHub MCP:
```
agent: decomposed into <N> tasks
Tasks: #<n>, #<n>, #<n>
First task to start: #<n> — <title>
```

---

## Step 5 — Update the tracking issue

Find the `[Project] Tracking` issue via the GitHub MCP search.

Add a comment via the GitHub MCP:
```
Epic #<n> decomposed: <N> tasks created, <M> ready to start, <K> blocked pending prior work.
```

---

## Step 6 — Return to session

If this decomposition was triggered from within the session skill (no `ready` issues existed),
return to Phase 2 of hackathon-session. The tasks you just created are the new `ready`
pool — claim one.

---

## Quality bar for decomposition

Before finishing, verify every task you created:
- [ ] Can an agent start this with zero additional context beyond the issue + PLAN.md?
- [ ] Is the output of this task verifiable? (not "work on auth" but "POST /login returns JWT")
- [ ] Is the scope small enough to finish in one session?
- [ ] Are dependencies between tasks correct and complete?
- [ ] Does every task include test criteria in its acceptance criteria?
- [ ] Did you capture any open questions as `blocked` issues rather than leaving them implicit?

If any task fails these checks, revise it before finishing.
