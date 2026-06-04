---
description: Phase 2 — scope each GitHub Project into epic issues. Reads PLAN.md and SPECS.md, optionally grills for clarity, proposes epics with human approval, creates GitHub labels and epic issues assigned to their project. Run after hackathon-plan.
allowed-tools: mcp__github__*, Read, Bash
---

# Skill: hackathon-epics

**Phase 2 of 4.** Takes the GitHub Projects created by `hackathon-plan` and scopes each
one into epic issues. Gate behavior depends on `hackathon.config.yml`.

Run after `/hackathon-plan`. Do not run if epic issues already exist — it will create duplicates.

---

## GitHub MCP — required for all operations

Every GitHub operation **must** use the GitHub MCP (`mcp__github__*`).
Do not use `gh` CLI, `curl`, or Bash for anything the MCP can handle.
Make all MCP calls **sequentially, not in parallel.**

---

## Trigger

"Create the epics", "Scope the epics", "Break projects into epics", "We're ready for epics"

---

## Step 0 — Read config

Read `hackathon.config.yml`. Extract and hold for the entire skill:
- `gates.epic_breakdown.human_required` (default: `true`)
- `gates.epic_breakdown.grilling` (default: `true`)
- `quality.comments` (default: `verbose`)
- `parallelism` (default: `false`)

---

## Step 1 — Read context

Read `PLAN.md` and `SPECS.md`.

Extract: vision, demo goal, stack, projects (each with goal and feature list),
out of scope, open questions, and all decisions already captured in SPECS.md.

Then via the GitHub MCP, list all GitHub Projects in this repo — these were created by
`hackathon-plan` and are the containers epics will be assigned to.

If no GitHub Projects exist: stop and tell the user to run `/hackathon-plan` first.

---

## Step 2 — Grilling (conditional)

**If `grilling: true`:** call `hackathon-grilling` with context:
`"epic breakdown for <project name from PLAN.md>"`.
Use the returned brief when scoping epics in Step 3.

**If `grilling: false`:** proceed immediately with best-guess interpretation.
Do not ask any questions.

---

## Step 3 — Scope epics

Using PLAN.md, SPECS.md, and the grilling brief (if obtained), scope epics for each project.

**If `parallelism: false`:** scope epics in priority/dependency order within each project.

**If `parallelism: true`:** structure epics into waves across the project:

  **Wave 1 — Independent foundations.**
  Each foundation epic builds one component independently, using stubs or hardcoded
  contracts wherever it would normally depend on another component.
  Wave 1 epics have no dependencies on each other.

  **Wave 2 — Integration epics.**
  Each integration epic wires two or more Wave 1 foundations together, replacing stubs
  with real connections. Depend only on the Wave 1 epics they integrate.

  **Wave 3 — End-to-end verify.**
  One epic that verifies the fully integrated system end-to-end.
  Depends on all Wave 2 epics.

  When scoping Wave 1 epics, explicitly define the stub contract each uses — this
  becomes the integration target for Wave 2. Include it in the epic's Context section.

For every epic, define:
- A specific done criterion an agent can verify without asking a human
- Which GitHub Project it belongs to
- Dependencies (other epic numbers that must close first)
- Acceptance bar (what would cause a PR review to fail)

---

## Step 4 — Human approval loop (conditional)

**If `epic_breakdown.human_required: true`:**

Present the proposed epics in chat:

```
Proposed epics:

Epic 1: <title>
  Project: <project name>
  Goal: <done criterion>
  Wave: <1 / 2 / 3 — or omit if parallelism: false>
  Depends on: <epic numbers or "none">
  Acceptance bar: <what causes PR failure>

Epic 2: <title>
  ...

Does this look right? Say "looks good" to proceed, or describe any changes.
```

Wait for the human's response. Loop (apply changes → re-present) until explicit approval.
Never create GitHub issues without approval.

**If `epic_breakdown.human_required: false`:** skip this step.

---

## Step 5 — Create labels

Create labels one at a time via the GitHub MCP.
If the tool is missing: skip silently — GitHub auto-creates labels on first use.

Labels needed: `needs-human-review`, `ai-approved`, `in-progress`, `blocked`,
`in-review`, `epic`, `bug`

---

## Step 6 — Create epic issues

For each approved epic, create one GitHub issue — **one at a time, sequentially**.

**Title:** `[Epic] <feature name>`

**Body:**
```
## Project
<GitHub Project name this epic belongs to>

## Goal
<done criteria — specific enough for an agent to verify without asking>

## Context
<everything from PLAN.md, SPECS.md, grilling brief, and wave strategy that affects
implementation: stack choices, constraints, shared infrastructure, environment
requirements, decisions already made, integration points with other epics.
If parallelism: true, include the stub contract this epic uses or provides.
Reference the relevant SPECS.md section(s) by heading name.>

## Wave
<Wave 1 / Wave 2 / Wave 3 — omit if parallelism: false>

## Dependencies
<other epics that must be closed before this can be decomposed, as #<n>, or "None">

## Acceptance Bar
<what would cause a PR review to fail for this feature>

## Open Questions
<anything still unresolved, or "None — all decisions made">

## Child Issues
<!-- hackathon-decompose fills this in. Do not edit manually. -->
```

**Labels:** `epic`, `ai-approved`

Create in wave order (Wave 1 first, then Wave 2, then Wave 3).
Within a wave, create in any order.

**After creating each epic issue:** add it to its GitHub Project board via the GitHub MCP.

---

## Step 7 — Create tracking issue

**Title:** `[Project] Tracking — <project name>`

**Body:**
```
## Vision
<from PLAN.md>

## Demo Goal
<from PLAN.md>

## Projects
### <Project 1 name>
Goal: <project goal>
GitHub Project: <URL>
Epics:
- [ ] #<n> [Epic] <name>
- [ ] #<n> [Epic] <name>

### <Project 2 name>  (if applicable)
...

## Wave Structure
<wave assignments if parallelism: true, or "Sequential" if false>

## Dependency Map
<inter-epic dependencies>

## Out of Scope
<from PLAN.md>

## Open Questions
<remaining open questions, or "None — all decisions made">
```

**Labels:** `epic`

---

## Step 8 — Report

**If `comments: verbose`:**
```
✓ Epics created for <project name>

Epics (<N> total):
  #1 · [Epic] <feature> [Project: <name>] [Wave 1]
  ...

Tracking issue: #<N+1>

Next steps:
1. Run /hackathon-decompose to break epics into tasks.
   (Epics are already ai-approved — no label step needed.)

Recommended: enable branch protection on main
(Settings → Branches → Require a pull request before merging)
```

**If `comments: minimal`:**
```
Epics created. <N> issues. Tracking: #<N+1>.
```

---

## Rules

- **Prerequisite:** GitHub Projects must already exist (created by `/hackathon-plan`). Stop if none found.
- **Never** create issues before grilling completes (if `grilling` is on).
- **Never** create issues before human approval (if `human_required` is on).
- **Never** run if epic issues already exist — check first.
- **Always** create issues sequentially, one at a time.
- **Always** add each epic issue to its GitHub Project board after creation.
- **Always** reference the relevant SPECS.md sections in each epic's Context.
- **When human_required: true and changes requested:** apply changes and re-present.
  Never create issues without explicit "looks good" or equivalent.
- **Label tool missing:** skip silently; GitHub auto-creates on first use.
- **MCP auth error:** check PAT has `repo` scope.
