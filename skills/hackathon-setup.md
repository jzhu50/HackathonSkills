---
description: Bootstrap a hackathon project — recursively interrogates the human until the plan is unambiguous, then creates GitHub labels and epic issues. Run once per hackathon.
allowed-tools: mcp__github__*
---

# Skill: hackathon-setup

Use this skill exactly once per hackathon, immediately after the repo is created and
`PLAN.md` has been filled in. This skill interrogates the human until the plan is fully
clear, then creates all labels and epics so agents can start working autonomously.

Do not run if issues already exist — it will create duplicates.

---

## GitHub MCP — required for all operations

Every GitHub operation **must** use the GitHub MCP (`mcp__github__*`).
Do not use `gh` CLI, `curl`, or Bash for anything the MCP can handle.
Make MCP calls sequentially, not in parallel.

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
are scoped, ordered, or implemented. This is a loop — keep asking until you are
genuinely confident that any agent could start working without asking a human.

**How the loop works:**

1. Analyse what you have read. For each feature and for the plan as a whole, identify
   everything that is ambiguous, contradictory, underspecified, or missing.
2. Write out all your questions in one message. Ask them all at once — do not trickle.
3. Wait for the human's answers.
4. Incorporate the answers into your working understanding of the plan.
5. Check: are there new ambiguities introduced by the answers? Are any previous
   questions still not fully resolved?
6. If yes — go back to step 1 and repeat with the remaining and new questions.
7. If no — proceed to Step 3.

**Never stop interrogating because you have "enough" questions — stop when you have
no remaining questions.** A half-understood plan produces bad epics.

**Types of ambiguity to surface (not an exhaustive list — use your judgment):**

- Done criteria: what does "done" look like for each feature, specifically enough
  that an agent can verify it without asking a human?
- Dependencies: which features must exist before others can start? Is there shared
  infrastructure (auth, DB schema, API base) that serialises work?
- Priority and cuts: if time runs out, what gets dropped first?
- Technical decisions still open: stack choices, library choices, service choices that
  would change how a feature is built
- Environment requirements: native packages, build tools, OS-specific dependencies
  that agents will need to resolve before coding
- Data and state: where does data live? Is it shared across machines? (e.g. SQLite
  is per-machine — is that intentional?)
- Scope boundaries: for each feature, what is explicitly out of scope?
- Integration points: which features share code, schemas, or API contracts?
- Acceptance bar: what would cause a PR review to fail for each feature?
- Test command: what command runs the full test suite? This is required — agents run
  it before every PR and when idle. If not decided, make this the first decision.

**When you are done interrogating**, summarise back to the human what you understood
before creating any issues. Ask for a final confirmation: "Does this capture everything
correctly?" If they correct anything, loop once more. Then proceed.

---

## Step 3 — Create labels

Attempt to create labels one at a time via the GitHub MCP label tool.
If the tool is missing: skip silently — GitHub auto-creates labels on first use.

Labels needed: `needs-scoping`, `ready`, `in-progress`, `blocked`, `in-review`,
`epic`, `bug`

---

## Step 4 — Create epic issues

For each feature in the plan, create one GitHub issue via the MCP — **one at a time,
sequentially**.

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
<other epics that must be complete or in-flight before this starts, or "None">

## Acceptance Bar
<what would cause a PR review to fail for this feature>

## Open Questions
<anything still unresolved, or "None — all decisions made">

## Child Issues
<!-- Agents fill this in during decomposition. Do not edit manually. -->
```

**Labels:** `epic`, `needs-scoping`

Create in priority order (dependency-first).

---

## Step 4b — Create the mandatory E2E Verification epic

After all feature epics are created, always create one final epic:

**Title:** `[Epic] End-to-End Verification`

**Body:**
```
## Goal
Verify that the complete project works end-to-end and the demo goal from PLAN.md
can be demonstrated without errors. This epic is the final gate before the project
is considered done.

## Demo Goal
<copy verbatim from PLAN.md>

## Context
All feature epics must be complete before this epic begins. This epic verifies the
integrated result — not individual features, but the full system working together.

## Dependencies
Depends on all other epics: #<n>, #<n>, ... (list every feature epic)

## Acceptance Bar
- Every acceptance criterion from every feature epic is met in the integrated system
- The demo goal can be demonstrated from start to finish without errors
- The full test suite passes on main with zero failures
- No `bug`-labeled issues are open
- Any edge cases identified during interrogation behave correctly end-to-end

## Open Questions
None — all decisions made during setup interrogation.

## Child Issues
<!-- Agents fill this in during decomposition. Do not edit manually. -->
```

**Labels:** `epic`, `needs-scoping`

This epic is always the last to be worked. Its decomposition will produce tasks such as:
- Write E2E tests covering the demo flow
- Set up E2E test runner (if not already present)
- Run and fix the full demo path
- Document any remaining edge cases

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
- [ ] #<n> [Epic] End-to-End Verification  ← mandatory final epic

## Dependency Map
<inter-epic dependencies. The E2E Verification epic always depends on all others.>

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
  #N · [Epic] End-to-End Verification  ← mandatory final gate
Tracking issue: #<N+1>

Recommended: enable branch protection on main
(Settings → Branches → Require a pull request before merging)

Start the loop on each machine:
  Mac/Linux: ./run.sh
  Windows:   .\run.ps1

For non-Claude Code harnesses: see HARNESS.md
```

---

## Error handling

- **Label tool missing:** skip, note in summary
- **Issue creation fails:** report it, continue with the rest
- **Plan is incomplete after interrogation:** document remaining gaps in the tracking
  issue Open Questions section and proceed — agents will create `blocked` issues
- **MCP auth error:** check PAT has `repo` scope and Docker is running
