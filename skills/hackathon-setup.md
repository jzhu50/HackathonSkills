---
description: Bootstrap a hackathon project — reads config, optionally grills for clarity, proposes epics (with optional human approval), then creates GitHub labels and epic issues. Run once per hackathon.
allowed-tools: mcp__github__*, Read
---

# Skill: hackathon-setup

**Run once per project.** Reads `hackathon.config.yml`, scopes epics from `PLAN.md`,
and creates GitHub labels and epic issues. Gate behavior depends on config.

Do not run if issues already exist — it will create duplicates.

---

## GitHub MCP — required for all operations

Every GitHub operation **must** use the GitHub MCP (`mcp__github__*`).
Do not use `gh` CLI, `curl`, or Bash for anything the MCP can handle.
Make all MCP calls **sequentially, not in parallel.**

---

## Trigger

"Set up the project", "Bootstrap the repo", "Initialize the hackathon",
"Create the epics", "We're ready to start"

---

## Step 0 — Read config

Read `hackathon.config.yml`. Extract and hold for the entire skill:
- `gates.epic_breakdown.human_required` (default: `true`)
- `gates.epic_breakdown.grilling` (default: `true`)
- `quality.comments` (default: `verbose`)
- `parallelism` (default: `false`)

---

## Step 1 — Read the plan

Read `PLAN.md` and `SPECS.md` (if it exists).

Extract: vision, demo goal, stack, core features, out of scope, open questions.

---

## Step 2 — Grilling (conditional)

**If `grilling: true`:** call `hackathon-grilling` with context:
`"epic breakdown for <project name from PLAN.md>"`.
Use the returned brief when scoping epics in Step 3.

**If `grilling: false`:** proceed immediately with best-guess interpretation of PLAN.md.
Do not ask any questions.

---

## Step 3 — Scope epics

Using PLAN.md, SPECS.md, and the grilling brief (if obtained):

**If `parallelism: false`:** scope epics in priority/dependency order. Each epic may
depend on earlier epics. This is the standard sequential structure.

**If `parallelism: true`:** structure epics into waves for maximum parallel execution:

  **Wave 1 — Independent foundations.**
  Each foundation epic builds one component independently, using stubs or hardcoded
  contracts wherever it would normally depend on another component.
  Examples: "Backend API (with in-memory stub data layer)", "Frontend (with hardcoded
  fixture data)", "Auth service (with stub token issuance)".
  Wave 1 epics have no dependencies on each other.

  **Wave 2 — Integration epics.**
  Each integration epic wires two or more Wave 1 foundations together, replacing stubs
  with real connections.
  Examples: "Wire backend to real database", "Connect frontend to live API", "Integrate
  auth tokens into backend middleware".
  Wave 2 epics depend only on the Wave 1 epics they integrate.

  **Wave 3 — End-to-end verify.**
  One epic that verifies the fully integrated system end-to-end.
  Depends on all Wave 2 epics.

  When scoping Wave 1 epics, explicitly define the stub contract each uses — this
  becomes the integration target for Wave 2. Include the stub contract in the epic's
  Context section.

For every epic regardless of wave strategy, define:
- A specific done criterion an agent can verify without asking a human
- Dependencies (other epic numbers that must close first)
- Acceptance bar (what would cause a PR review to fail)

---

## Step 4 — Human approval loop (conditional)

**If `human_required: true`:**

Present the proposed epics in chat. Use this format:

```
Proposed epics:

Epic 1: <title>
  Goal: <done criterion>
  Wave: <1 / 2 / 3 — or omit if parallelism: false>
  Depends on: <epic numbers or "none">
  Acceptance bar: <what causes PR failure>

Epic 2: <title>
  ...

Does this look right? Say "looks good" to proceed, or describe any changes.
```

Wait for the human's response.

- If **"looks good"** (or equivalent) → proceed to Step 5.
- If **changes requested** → apply changes to the epic plan, then present the updated
  plan again with the same format. Loop until the human explicitly approves.
  Never proceed to GitHub without explicit approval.

**If `human_required: false`:** skip this step entirely.

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
## Goal
<done criteria — specific enough for an agent to verify without asking>

## Context
<everything from PLAN.md, SPECS.md, grilling brief, and wave strategy that affects
implementation: stack choices, constraints, shared infrastructure, environment
requirements, decisions already made, integration points with other epics.
If parallelism: true, include the stub contract this epic uses or provides.>

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

---

## Step 7 — Create tracking issue

**Title:** `[Project] Tracking — <project name>`

**Body:**
```
## Vision
<from PLAN.md>

## Demo Goal
<from PLAN.md>

## Epics
- [ ] #<n> [Epic] <name>
- [ ] #<n> [Epic] <name>

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
✓ Setup complete for <project name>

Epics created (<N> total):
  #1 · [Epic] <feature> [Wave 1]
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
Setup complete. <N> epics created. Tracking issue: #<N+1>.
```

---

## Rules

- **Never** create issues before grilling completes (if grilling is on).
- **Never** create issues before human approval (if human_required is on).
- **Never** run if issues already exist — check first.
- **Always** create issues sequentially, one at a time.
- **When human_required: true and changes requested:** apply changes and re-present.
  Never proceed without explicit "looks good" or equivalent.
- **Label tool missing:** skip silently; GitHub auto-creates on first use.
- **Issue creation fails:** report it, continue with the rest.
- **MCP auth error:** check PAT has `repo` scope.
