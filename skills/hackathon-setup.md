---
description: Bootstrap a hackathon project — interrogates the human to sharpen the plan, then creates GitHub labels and epic issues via the GitHub MCP. Run once per hackathon.
allowed-tools: mcp__github__*
---

# Skill: hackathon-setup

Use this skill exactly once per hackathon, immediately after the repo is created and
`PLAN.md` has been filled in by the team. This skill:

1. Reads the plan and interrogates the human to surface ambiguities
2. Creates GitHub labels
3. Creates epic issues from the sharpened plan

Do not run this skill if issues already exist in the repo — it will create duplicates.

---

## GitHub MCP — required for all operations

Every GitHub operation in this skill **must** use the GitHub MCP (`mcp__github__*`).
Do not use the `gh` CLI, `curl`, or any Bash command for anything the MCP can handle.

---

## Trigger

A human says something like:
- "Set up the project"
- "Bootstrap the repo"
- "Initialize the hackathon"
- "Create the epics"
- "We're ready to start, set everything up"

---

## Prerequisites (verify before proceeding)

Using the GitHub MCP, check:

1. `PLAN.md` exists in the repo root and is not empty / not just the template placeholder text
2. `AGENTS.md` exists in the repo root (it ships with the template — if missing, tell the
   human to use the hackathon template repo, not a blank repo)
3. The repo is accessible via the GitHub MCP with write permissions

If any check fails, stop and tell the human what's missing. Do not proceed.

---

## Step 1 — Read the plan

Use `get_file_contents` to read `PLAN.md` and `SPECS.md` (if it exists).

Extract:
- **Vision** — the one-paragraph description of what's being built
- **Demo goal** — the concrete "done" statement
- **Stack** — languages, frameworks, services
- **Core features** — the prioritised feature list (these become epics)
- **Out of scope** — explicit exclusions
- **Open questions** — anything unresolved

---

## Step 2 — Interrogate the human before creating anything

Before creating a single issue, surface every ambiguity that would affect how epics are
written or ordered. Ask all questions in one message — do not trickle them out one at a time.

Identify 3–7 questions from the list below that are actually unclear from the plan.
Skip any question the plan already answers specifically. Do not invent vague questions.

**Questions to ask (pick the ones that apply):**

- What does "done" look like for [feature X]? Be specific enough that an agent can
  verify it without asking a human.
- What is the dependency order? Which feature must ship before another can start?
- Which features are must-have for the demo vs. nice-to-have? If time runs short,
  what gets cut first?
- Are there any technical decisions still open that would change how a feature is built?
  (e.g. "we might use Postgres or SQLite — TBD")
- Is there any shared infrastructure (auth, database schema, API base) that must exist
  before parallel work can begin? Who owns it?
- Are there any environment dependencies or native packages agents will need?
  (Prevents "better-sqlite3 doesn't compile on Windows" surprises mid-session.)
- Should agents work in any particular order, or can all epics proceed in parallel once
  decomposed into tasks?

Wait for the human's answers before proceeding to Step 3.
Incorporate the answers into the epic bodies — that is the whole point of asking.

---

## Step 3 — Create labels

Attempt to create labels using the MCP's label management tool.
Create them **one at a time** (not in parallel).

- If the tool exists and succeeds: done
- If the tool does not exist or fails: skip silently — GitHub auto-creates labels
  (without colour) the first time they appear on an issue. Note this in the Step 5 summary.

Labels needed:

| name | meaning |
|---|---|
| `needs-scoping` | Too large or unclear — must be decomposed into tasks first |
| `ready` | Scoped, unblocked, no assignee — available to claim |
| `in-progress` | Actively being worked — has an assignee |
| `blocked` | Cannot proceed — comment on issue explains why |
| `in-review` | PR is open and unmerged, waiting for review |
| `epic` | Parent container — work happens in child issues |
| `bug` | Something is broken |

---

## Step 4 — Create epic issues

For each feature in **Core features**, create one GitHub issue using the MCP's issue
create tool. Create them **one at a time** — parallel creates can stack at the permission
prompt and require a full retry.

**Title format:** `[Epic] <feature name>`

**Body format:**
```
## Goal
<one sentence: what does done look like — specific enough for an agent to verify>

## Context
<2-4 sentences from PLAN.md, SPECS.md, and the human's answers in Step 2.
Include stack choices, constraints, shared infrastructure dependencies, environment
requirements, and any decisions that affect implementation.>

## Relevant Specs
<Paste relevant sections from SPECS.md verbatim. Leave blank if nothing applies.>

## Dependencies
<List any other epics that must be complete or in-flight before this one can start.
Format: "Blocked by: [Epic] <name>". Write "None" if this epic can start immediately.>

## Open Questions
<Unresolved questions from PLAN.md or Step 2 that affect this epic. Write "None" if clear.>

## Child Issues
<!-- Agents fill this in during decomposition. Do not edit manually. -->
```

**Labels:** `epic`, `needs-scoping`

**Priority ordering:** create epics in the order features appear in `PLAN.md`, which
should reflect the dependency order clarified in Step 2.

Note each epic's issue number — you'll need them for the tracking issue.

---

## Step 5 — Create a tracking issue

Create one final issue as the project dashboard:

**Title:** `[Project] Tracking — <project name from PLAN.md>`

**Body:**
```
## Vision
<paste vision from PLAN.md>

## Demo Goal
<paste demo goal from PLAN.md>

## Epics (in priority order)
<list each epic as: - [ ] #<number> [Epic] <feature name>>

## Dependency Map
<list inter-epic dependencies surfaced in Step 2, or "None — all epics can run in parallel">

## Out of Scope
<paste out of scope list from PLAN.md>

## Open Questions
<paste open questions, or "None — all decisions made" if none remain>
```

**Labels:** `epic`

---

## Step 6 — Report to the human

```
✓ Setup complete for <project name>

Labels: <"created" | "auto-created without colour (style via GitHub web UI if desired)">

Epics created (<N> total, in priority order):
  #1 · [Epic] <feature 1>
  #2 · [Epic] <feature 2>
  ...

Tracking issue: #<N>

Recommended: enable branch protection on main (Settings → Branches → require PR before merging).
This prevents agents from pushing directly to main and forces the PR workflow.

Next steps:
  1. Each teammate: configure GitHub MCP with your own PAT (see AGENTS.md)
  2. Each teammate: say "Go" to start a session — agent claims one task, works it, opens a PR, stops
  3. When PRs accumulate: say "Review" to start a review session — agent picks up a PR, reviews it, merges or requests changes, stops
  4. Humans: resolve any open questions in the tracking issue as they come up

No further setup needed. Agents take it from here.
```

---

## Error handling

- **Label tool missing:** skip, note in summary, continue
- **Issue creation fails:** report the specific title, continue with the rest
- **PLAN.md is incomplete:** list missing sections and stop — do not create partial epics
- **Human's Step 2 answers are still vague:** ask one follow-up, then proceed with best effort
  and add remaining ambiguity to the relevant epic's Open Questions section
- **MCP auth error:** tell the human to check their PAT has `repo` scope and Docker is running
