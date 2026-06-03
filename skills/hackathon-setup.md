---
description: Bootstrap a hackathon project — reads PLAN.md and creates GitHub labels and epic issues via the GitHub MCP. Run once per hackathon.
allowed-tools: mcp__github__*
---

# Skill: hackathon-setup

Use this skill exactly once per hackathon, immediately after the repo is created and
`PLAN.md` has been filled in by the team. This skill bootstraps the entire project:
it reads the plan, creates GitHub labels, and generates all epic issues so agents can
start working without any further human input.

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

Use `get_file_contents` to read `PLAN.md`.

Extract:
- **Vision** — the one-paragraph description of what's being built
- **Demo goal** — the concrete "done" statement
- **Stack** — languages, frameworks, services
- **Core features** — the prioritised feature list (these become epics)
- **Out of scope** — explicit exclusions
- **Open questions** — anything unresolved

Also read `SPECS.md` if it exists — extract any data models, API routes, or UI flows
that are already defined, as these will enrich the epic bodies.

---

## Step 2 — Create labels

Use `label_write` (or the equivalent MCP tool) with method `create` to create each label.
If a label already exists, skip it silently (do not error).

| name | color | description |
|---|---|---|
| `needs-scoping` | `FBCA04` | Too large or unclear — must be decomposed into tasks first |
| `ready` | `0E8A16` | Scoped, unblocked, no assignee — available to claim |
| `in-progress` | `0075CA` | Actively being worked — has an assignee |
| `blocked` | `D93F0B` | Cannot proceed — see issue comment for reason |
| `in-review` | `5319E7` | PR open, waiting for review or merge |
| `epic` | `BFD4F2` | Parent container — work happens in child issues |
| `bug` | `CC0000` | Something is broken |

---

## Step 3 — Create epic issues

For each feature in the **Core features** section of `PLAN.md`, create one GitHub issue
using the MCP's issue create tool.

**Title format:** `[Epic] <feature name>`

**Body format:**
```
## Goal
<one sentence: what does done look like for this feature?>

## Context
<2-4 sentences synthesised from PLAN.md and SPECS.md relevant to this feature.
Include stack choices, constraints, or decisions that affect implementation.>

## Relevant Specs
<If SPECS.md has data models, routes, or flows that apply to this epic, paste
the relevant sections here verbatim. Leave blank if nothing applies.>

## Open Questions
<Any open questions from PLAN.md that block or affect this epic. If none, write "None".>

## Child Issues
<!-- Agents fill this in during decomposition. Do not edit manually. -->
```

**Labels:** `epic`, `needs-scoping`

**Priority ordering:** create epics in the same order features appear in `PLAN.md`.
The first epic created will be the first one agents decompose and work on.

After creating each epic, note its issue number — you'll need them for the summary.

---

## Step 4 — Create a tracking issue

Create one final issue that serves as the project dashboard:

**Title:** `[Project] Tracking — <project name from PLAN.md>`

**Body:**
```
## Vision
<paste vision from PLAN.md>

## Demo Goal
<paste demo goal from PLAN.md>

## Epics
<list each epic as: - [ ] #<number> <feature name>>

## Out of Scope
<paste out of scope list from PLAN.md>

## Open Questions
<paste open questions from PLAN.md — agents update this as questions are resolved>
If the Open Questions section of PLAN.md is empty or just a dash, write
"None — all decisions made" here explicitly rather than leaving it blank.
```

**Labels:** `epic`

Pin this issue mentally — agents read it during session start for a fast project overview.

---

## Step 5 — Report to the human

Reply with a setup summary in this format:

```
✓ Setup complete for <project name>

Labels created: needs-scoping, ready, in-progress, blocked, in-review, epic, bug

Epics created (<N> total):
  #1 · [Epic] <feature 1>
  #2 · [Epic] <feature 2>
  ...

Tracking issue: #<N>

Next steps:
  1. Each teammate: configure GitHub MCP with your own PAT (see AGENTS.md)
  2. Each teammate: tell your agent "Go" — it will read AGENTS.md and start working
  3. Humans: check back to resolve any open questions flagged in the tracking issue

No further setup needed. Agents take it from here.
```

---

## Error handling

- **Label already exists:** skip silently, continue
- **Issue creation fails:** report the specific issue title that failed, then continue with the rest
- **PLAN.md is incomplete:** list exactly which sections are missing and stop — do not create
  partial epics from an incomplete plan
- **MCP auth error:** tell the human to check their PAT has `repo` scope and Docker is running
