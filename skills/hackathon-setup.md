---
description: Onboarding guide - detects new vs existing project, scans existing codebases to pre-populate PLAN.md and SPECS.md, configures hackathon.config.yml interactively, and walks the user through the full workflow. Run this first.
allowed-tools: Read, Write, Glob, Grep, Bash
---

# Skill: hackathon-setup

**Start here.** This skill orients you to the repo and walks you through the full
workflow from blank template to running code. Nothing is written to GitHub - this
is a guided orientation.

---

## What this repo does

This is an AI agent template for building software fast. You fill in a plan. Agents
decompose it, implement it, test it, and open PRs. You control how much they check
with you at each step via `hackathon.config.yml`.

The work is organised in four phases:

```
PLAN.md
  |-> /hackathon-plan       Phase 1: scope PLAN.md into Projects + generate SPECS.md
        |-> /hackathon-epics   Phase 2: scope each Project into Epic issues on GitHub
              |-> /hackathon-decompose  Phase 3: break each Epic into Task issues
                    |-> /hackathon-session   Phase 4: implement Tasks, open PRs
```

---

## Step 0 - Detect context

Before doing anything, ask:

> "Are you starting a new project from scratch, or do you have an existing codebase
> you want to bring into this framework?"

**If new project:** continue to Step 1.

**If existing codebase:** run the existing-project flow below before Step 1.

---

## Existing codebase flow

When the codebase already exists, the agent reads it and helps the user populate
`PLAN.md` and pre-seeds `SPECS.md` before planning begins.

### Scan the codebase

Read the repo to understand what's already built:
- List all top-level directories and key files
- Read `README.md`, existing `PLAN.md`, `SPECS.md`, and any docs if present
- Identify: tech stack, data models, API surface, auth mechanism, test setup
- Note what is already working vs what is incomplete or missing

### Draft PLAN.md from findings

Propose a `PLAN.md` prefilled with what was discovered:
- **Vision:** inferred from README / existing code - ask user to confirm or rewrite
- **Demo Goal:** ask the user - "What's the most important thing you want to demo?"
- **Stack:** filled from what was detected
- **Projects:** ask - "What are you trying to add or improve?
    A) New features
    B) Security hardening
    C) Refactoring / tech debt
    D) Performance improvements
    E) Something else"
  Create one project per goal area.
- **Out of Scope:** prefill with "existing functionality already implemented"
- **Open Questions:** any gaps or ambiguities found in the scan

Show the draft to the user and ask for confirmation before writing it.
Loop on changes until the user approves. Write `PLAN.md` on explicit approval.

### Pre-seed SPECS.md

From the codebase scan, draft a `SPECS.md` that documents the *current* state:
- Data models as they exist in the code (schemas, types, migrations)
- API routes as they exist
- Known business rules found in the code
- Existing env vars (from `.env.example`, README, config files - never actual secrets)

Show the draft. The user may add, remove, or correct. Write on approval.

This becomes the baseline SPECS.md that `/hackathon-plan` will then *extend* (not
replace) when planning new work.

### Then continue from Step 1

After PLAN.md and baseline SPECS.md are written, continue with Step 1 (prerequisites)
and skip Step 3 (PLAN.md is already filled in).

---

## Step 1 - Prerequisites

Before doing anything, make sure you have:

- [ ] **Claude Code** installed (`claude` in your terminal)
- [ ] **Docker** running (needed for the GitHub MCP server)
- [ ] **GitHub Personal Access Token** with `repo` scope
      (for org repos also add `read:org`)
      -> Settings -> Developer settings -> Personal access tokens -> Fine-grained
- [ ] **GitHub MCP configured** in your Claude Code MCP settings:

```json
{
  "mcpServers": {
    "github": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "-e", "GITHUB_PERSONAL_ACCESS_TOKEN",
               "ghcr.io/github/github-mcp-server"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "YOUR_PAT_HERE"
      }
    }
  }
}
```

- [ ] **Branch protection on `main`** enabled
      -> GitHub repo -> Settings -> Branches -> Add rule -> Require a pull request before merging
      (Do NOT require approvals unless you have two distinct accounts - GitHub won't let
      you approve your own PR.)

---

## Step 2 - Bootstrap the project locally

Run the bootstrap script once per cloned repo. It generates `CLAUDE.md` and
`.claude/` locally (these are gitignored - never committed):

```bash
# Mac/Linux
hackathon-bootstrap

# Windows
hackathon-bootstrap
```

Re-run this after any skill update or after a teammate clones the repo.

---

## Step 3 - Fill in `PLAN.md`

Open `PLAN.md` and fill in every section:

| Section | What to write |
|---|---|
| **Vision** | One paragraph - what are you building and why? |
| **Demo Goal** | One sentence - exactly what you want to demo. Format: "A user can [X] and [see Y]." |
| **Stack** | Fill in what's decided. Leave rows blank only if genuinely undecided. |
| **Projects** | Group your features into named deliverables. One project = one GitHub Project board. |
| **Out of Scope** | Explicitly list what you are NOT building. As important as the feature list. |
| **Open Questions** | Anything genuinely undecided. Agents will not guess - they block and wait. |

**The Test command row in Stack is required** unless you set `testing: skip`.

**SPECS.md** - do not create this manually. It is auto-generated by `/hackathon-plan`
from the grilling session. If you have existing API contracts or data models you want
included, add them to `PLAN.md` under Open Questions or a note in the Vision section -
grilling will surface them.

---

## Step 4 - Configure oversight

Ask the user the following questions **one at a time** and write their answers to
`hackathon.config.yml`. Read the current file first; preserve any keys already set.

**Question 1 - Oversight style**
> "How much do you want to stay in control?
>   A) Full control - approve every proposal before anything hits GitHub (default)
>   B) Approve only big decisions - projects and epics need approval, tasks are automatic
>   C) Autonomous - agents run the whole pipeline, you only review PRs
>   D) Custom - let me answer each gate individually"

Map answers A/B/C to gate presets below. For D, ask each gate question in turn.

**Preset A - Full control**
```yaml
gates:
  project_breakdown: { human_required: true,  grilling: true  }
  epic_breakdown:    { human_required: true,  grilling: true  }
  task_breakdown:    { human_required: true,  grilling: true  }
  task_completion:   { human_required: true  }
  code_review:       { human_required: true  }
  epic_review:       { human_required: true  }
```

**Preset B - Approve big decisions**
```yaml
gates:
  project_breakdown: { human_required: true,  grilling: true  }
  epic_breakdown:    { human_required: true,  grilling: false }
  task_breakdown:    { human_required: false, grilling: false }
  task_completion:   { human_required: false }
  code_review:       { human_required: true  }
  epic_review:       { human_required: true  }
```

**Preset C - Autonomous**
```yaml
gates:
  project_breakdown: { human_required: false, grilling: false }
  epic_breakdown:    { human_required: false, grilling: false }
  task_breakdown:    { human_required: false, grilling: false }
  task_completion:   { human_required: false }
  code_review:       { human_required: false }
  epic_review:       { human_required: false }
```

**Question 2 - Testing level**
> "How strictly should tests be enforced?
>   A) Required - hard stop before any PR if code paths are uncovered (default)
>   B) Recommended - missing edge coverage flagged but not blocking
>   C) Skip - no tests required"

**Question 3 - Parallelism**
> "Should epics be structured into parallel waves (foundations first, then integrations)?
>   A) No - sequential priority order (default)
>   B) Yes - wave-based parallel structure"

After collecting answers, write `hackathon.config.yml` with the chosen values.
Show the final config to the user and confirm before writing:

```
Here's your config:

[config content]

Write this to hackathon.config.yml? Say "yes" to confirm or describe any changes.
```

Wait for confirmation. Apply changes and re-show if requested. Write on explicit approval.

The written config format:

```yaml
# hackathon.config.yml
gates:
  project_breakdown:
    human_required: <true|false>
    grilling: <true|false>
  epic_breakdown:
    human_required: <true|false>
    grilling: <true|false>
  task_breakdown:
    human_required: <true|false>
    grilling: <true|false>
  task_completion:
    human_required: <true|false>
  code_review:
    human_required: <true|false>
  epic_review:
    human_required: <true|false>
quality:
  testing: <required|recommended|skip>
  comments: verbose
parallelism: <true|false>
```

**Fully autonomous mode (Preset C + testing: skip):** run `/hackathon-plan` and the
full pipeline runs end-to-end without pausing. Any failure always escalates to you.

---

## Step 5 - Run the four phases in order

### Phase 1 - Scope the plan
```
/hackathon-plan
```
Grills you on the plan, scopes it into named Projects, generates `SPECS.md`,
and creates the GitHub Project boards.

### Phase 2 - Scope into epics
```
/hackathon-epics
```
Takes the GitHub Projects and scopes each one into epic issues on GitHub.

### Phase 3 - Decompose epics into tasks
```
/hackathon-decompose
```
Breaks each epic into task-sized issues with branches.

### Phase 4 - Implement
```
/hackathon-session
```
Loops through all `ai-approved` tasks: implements, tests, opens PRs.

---

## Step 6 - During implementation

**Reviewing PRs** (if `code_review.human_required: true`):
```
/hackathon-review
```
Run this for each `in-review` PR. The agent reads the diff, posts findings.
Say "merge" or "request changes: [specifics]".

**Bugs:** the session auto-calls `/hackathon-debug` on test regressions.
You can also run it manually on any `bug`-labeled issue.

**Tracking project completion:**
```
/hackathon-projects
```
Shows project-level status. Closes a GitHub Project when all its epics merge.

---

## Step 7 - When a project is done

When all epics in a project close, the agent auto-calls `/hackathon-docs-demo-script`
to generate the README, API reference, and demo walkthrough.

Run `/hackathon-projects` to formally close the GitHub Project board.

---

## File reference

| File | What it is |
|---|---|
| `PLAN.md` | Fill this in - vision, stack, projects, features |
| `SPECS.md` | Auto-generated by `/hackathon-plan` - do not edit during parallel work |
| `hackathon.config.yml` | Oversight gates, testing level, comments verbosity |
| `AGENTS.md` | Coordination protocol - read by all agent harnesses |
| `HARNESS.md` | Setup guide for non-Claude Code harnesses (Cursor, Aider, etc.) |

---

## Quick-start checklist

```
[ ] Docker running
[ ] PAT configured in Claude Code MCP settings
[ ] Branch protection enabled on main
[ ] hackathon-bootstrap run
[ ] PLAN.md filled in
[ ] hackathon.config.yml configured
[ ] /hackathon-plan
[ ] /hackathon-epics
[ ] /hackathon-decompose
[ ] /hackathon-session
```



