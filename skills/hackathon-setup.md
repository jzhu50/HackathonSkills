---
description: Bootstrap a hackathon project — recursively interrogates the human until the plan is unambiguous, then creates GitHub labels and epic issues. Run once per hackathon.
allowed-tools: mcp__github__*
---

# Skill: hackathon-setup

**Run once per project.** This skill interrogates the human until every ambiguity in
`PLAN.md` is resolved, then creates all GitHub labels, epic issues, and a tracking
issue. Nothing is created until the plan is fully understood.

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

## Step 1 — Read the plan

Read `PLAN.md` and `SPECS.md` (if it exists) via the GitHub MCP.

Extract: vision, demo goal, stack, core features (these become epics), out of scope,
open questions.

---

## Step 2 — Recursive interrogation

Before creating a single issue, surface every ambiguity that would affect how epics
are scoped, ordered, or implemented. Keep asking until you are genuinely confident
that any agent could start working without asking a human.

**How the loop works:**

1. For each feature and for the plan as a whole, identify everything ambiguous,
   contradictory, underspecified, or missing.
2. Write all questions in one message — do not trickle them out one at a time.
3. Wait for the human's answers.
4. Incorporate the answers. Check: are there new ambiguities? Any questions still unresolved?
5. If yes → repeat from step 1. If no → proceed to Step 3.

**Never stop because you have "enough" questions — stop only when you have none.**
A half-understood plan produces bad epics.

**Types of ambiguity to surface:**

- Done criteria: what does "done" look like for each feature, specifically enough
  that an agent can verify it without asking a human?
- Dependencies: which features must exist before others can start?
- Priority and cuts: if time runs out, what gets dropped first?
- Technical decisions still open: stack, library, and service choices
- Environment requirements: native packages, build tools, OS-specific dependencies
- Data and state: where does data live? Is it shared across machines?
- Scope boundaries: for each feature, what is explicitly out of scope?
- Integration points: which features share code, schemas, or API contracts?
- Acceptance bar: what would cause a PR review to fail for each feature?
- Test command: what command runs the full test suite? This is required.

**When done interrogating**, summarise what you understood and ask: "Does this capture
everything correctly?" If the human corrects anything, loop once more. Then proceed.

---

## Step 3 — Create labels

Create labels one at a time via the GitHub MCP label tool.
If the tool is missing: skip silently — GitHub auto-creates labels on first use.

Labels needed: `needs-human-review`, `ai-approved`, `in-progress`, `blocked`,
`in-review`, `epic`, `bug`

---

## Step 4 — Create epic issues

For each feature in the plan, create one GitHub issue — **one at a time, sequentially**.

**Title:** `[Epic] <feature name>`

**Body:**
```
## Goal
<done criteria — specific enough for an agent to verify without asking>

## Context
<everything from PLAN.md, SPECS.md, and the interrogation that affects implementation:
stack choices, constraints, shared infrastructure, environment requirements,
decisions already made, integration points with other epics>

## Dependencies
<other epics that must be closed before this can be decomposed, as #<n>, or "None">

## Acceptance Bar
<what would cause a PR review to fail for this feature>

## Open Questions
<anything still unresolved, or "None — all decisions made">

## Child Issues
<!-- hackathon-decompose fills this in. Do not edit manually. -->
```

**Labels:** `epic`, `needs-human-review`

Create in priority order (dependency-first).

---

## Step 5 — Create tracking issue

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

## Dependency Map
<inter-epic dependencies>

## Out of Scope
<from PLAN.md>

## Open Questions
<remaining open questions, or "None — all decisions made">
```

**Labels:** `epic`

---

## Step 6 — Report

```
✓ Setup complete for <project name>

Epics created (<N> total):
  #1 · [Epic] <feature>
  ...

Tracking issue: #<N+1>

Next steps:
1. Review each epic issue (#1–#N).
2. Add `ai-approved` to any epic you are satisfied with.
3. Run /hackathon-decompose to break approved epics into tasks.

Recommended: enable branch protection on main
(Settings → Branches → Require a pull request before merging)
```

---

## Rules

- **Never** create issues before the interrogation loop completes.
- **Never** run if issues already exist — check first.
- **Always** create issues sequentially, one at a time.
- **Always** summarise your understanding and get confirmation before Step 3.
- **Label tool missing:** skip silently; GitHub auto-creates on first use.
- **Issue creation fails:** report it, continue with the rest.
- **MCP auth error:** check PAT has `repo` scope.
