# Hackathon Agent Template

AI agents write the code. You control how much they check with you.

Run `/hackathon-setup` — it detects your project type, scans existing codebases,
and configures oversight interactively. Then step through four phases: scope the plan,
scope into epics, decompose into tasks, implement. Every gate is configurable from full
human approval at every step to fully autonomous end-to-end execution.

**This repo is a template.** Click "Use this template" on GitHub, clone it, and start
with `/hackathon-setup`.

---

## How it works

GitHub is the shared brain. Agents have no memory between sessions — everything they
need lives in GitHub Issues, Projects, and PRs.

The hierarchy is: **GitHub Project → Epics → Tasks**

| Primitive | Role |
|---|---|
| GitHub Projects | Initiative containers — group epics by named deliverable (MVP, v2, Security Hardening) |
| Issues | Units of work — epics, tasks, bugs |
| Labels | The state machine — controls what AI can touch |
| PRs | The only way to close a task — every change goes through review |
| `PLAN.md` | Vision, stack, projects, features, decisions — the project bible |
| `SPECS.md` | Auto-generated from grilling — data models, API routes, UI flows, business rules |
| `hackathon.config.yml` | Oversight gates — configured interactively by `/hackathon-setup` |

Work flows through four phases:

```
PLAN.md
  └─▶ /hackathon-plan        Phase 1 — scope into Projects + generate SPECS.md
        └─▶ /hackathon-epics     Phase 2 — scope Projects into Epic issues
              └─▶ /hackathon-decompose  Phase 3 — scope Epics into Task issues
                    └─▶ /hackathon-session    Phase 4 — implement Tasks, open PRs
```

---

## Getting started

### 1 — Install

```bash
# Mac/Linux
curl -fsSL https://raw.githubusercontent.com/Victor-Casado/HackathonSkills/main/install.sh | bash

# Windows (PowerShell)
irm https://raw.githubusercontent.com/Victor-Casado/HackathonSkills/main/install.ps1 | iex
```

Installs two commands:
- `hackathon-skills` — PTY runner that launches your AI CLI
- `hackathon-bootstrap` — project bootstrapper (run once per cloned repo)

### 2 — Create your repo from the template

Click **"Use this template"** on GitHub, create a new repo, then clone it:

```bash
git clone https://github.com/<you>/<project-name>
cd <project-name>
```

### 3 — Bootstrap locally

```bash
hackathon-bootstrap
```

Generates `CLAUDE.md` and `.claude/` locally (gitignored — never committed). Re-run
after any skill update or after a teammate clones on a new machine.

### 4 — Configure the GitHub MCP

Each teammate needs a Personal Access Token with `repo` scope (add `read:org` for
org repos) in their Claude Code MCP settings:

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

Enable branch protection on `main` (Settings → Branches → Require a pull request
before merging). Do **not** also require approvals unless you have two accounts —
GitHub won't let you approve your own PR.

### 5 — Run the setup wizard

```
/hackathon-setup
```

The wizard:
- Detects whether you have a **new project** or an **existing codebase**
- For existing codebases: scans the repo and drafts `PLAN.md` and `SPECS.md` from
  what's already there, then helps you describe what you want to add or improve
- For new projects: guides you through filling in `PLAN.md`
- Configures `hackathon.config.yml` interactively — 3 questions, no YAML editing needed
- Walks you through every prerequisite and explains what to run next

---

## Workflow

### Phase 1 — Scope the plan

```
/hackathon-plan
```

Reads `PLAN.md`, grills you until every boundary and decision is explicit, then:
- Scopes the work into named GitHub Projects
- Generates `SPECS.md` (data models, API routes, UI flows, business rules, env vars)
- Commits `SPECS.md` to main
- Creates the GitHub Project boards

Gate: `project_breakdown`

### Phase 2 — Scope each project into epics

```
/hackathon-epics
```

Reads the GitHub Projects from Phase 1, scopes each into epic issues, assigns every
epic to its project, and creates a tracking issue. Optionally grills before scoping.

Gate: `epic_breakdown`

If `parallelism: true`, epics are structured into waves:
- **Wave 1** — independent foundations, each with stubs for cross-dependencies
- **Wave 2** — integration epics that wire Wave 1 foundations together
- **Wave 3** — end-to-end verify

### Phase 3 — Decompose each epic into tasks

```
/hackathon-decompose
```

For each `ai-approved` epic: optionally grills, creates task issues with context,
creates the epic branch, and appends a mandatory verify task last.

Gate: `task_breakdown`

### Phase 4 — Implement

```
/hackathon-session
```

Loops through all `ai-approved` tasks:
- Runs baseline tests before touching anything
- Implements on a branch off the epic branch
- Tests progressively; calls `/hackathon-debug` automatically on regressions
- Presents completed work for approval (if configured), then opens a PR
- Optionally auto-reviews and merges

Gates: `task_completion`, `code_review`

### Reviewing PRs

```
/hackathon-review
```

Run for each `in-review` task PR (when `code_review.human_required: true`). The agent
reads the diff, checks every acceptance criterion, and posts findings.

Say **"merge"** or **"request changes: [specifics]"**. On request-changes the task
returns to `ai-approved` for the session to pick up.

### Verifying and closing each epic

The session automatically picks up the verify task once all sibling tasks are merged:
- Rebases the epic branch onto the latest main
- Runs the full test suite
- Checks every acceptance criterion from the epic
- Runs the security audit
- Opens a PR from the epic branch to main

Gate: `epic_review`

### Tracking project completion

```
/hackathon-projects
```

Shows the completion status of every GitHub Project at any time. When all epics in a
project merge, closes the GitHub Project board and auto-calls
`/hackathon-docs-demo-script` on the last project.

---

## Existing projects and adding scope

### Onboarding an existing codebase

`/hackathon-setup` handles this. When it detects existing code it:
1. Scans the repo — stack, data models, API surface, auth, test setup
2. Drafts `PLAN.md` from what it finds and asks you to confirm
3. Pre-seeds `SPECS.md` with the current state of the codebase
4. Asks what you want to add or improve, then runs the normal wizard flow

The pre-seeded `SPECS.md` becomes the baseline that `/hackathon-plan` extends when
planning new work.

### Adding features, hardening, or refactoring to a running project

```
/hackathon-add
```

Use this at any time after the framework is already running. It adds new scope without
disrupting active work:

- **New features** — a new GitHub Project with its own epics
- **Security hardening** — scans for OWASP gaps, unvalidated inputs, missing auth
  checks, then scopes a hardening project from actual findings
- **Refactoring / tech debt** — scans for duplication, large files, missing tests
- **Performance** — scans for N+1 queries, missing indexes, unoptimized paths
- **Accessibility** — scans for ARIA, keyboard nav, contrast, form label gaps

New epics land as `ai-approved` and the session picks them up in the normal loop.

---

## Configuring oversight

`hackathon.config.yml` controls all human gates. The easiest way to set it is via
the interactive wizard in `/hackathon-setup`. The file format for reference:

```yaml
gates:
  project_breakdown:
    human_required: true   # approve proposed projects before GitHub Projects are created
    grilling: true         # interrogation before scoping projects and generating SPECS.md

  epic_breakdown:
    human_required: true   # approve proposed epics before issues are created
    grilling: true         # interrogation before scoping epics

  task_breakdown:
    human_required: true   # approve proposed tasks before issues are created
    grilling: true         # interrogation before decomposing each epic

  task_completion:
    human_required: true   # approve completed work before PR opens

  code_review:
    human_required: true   # you trigger review and decide merge/changes on task PRs

  epic_review:
    human_required: true   # you review and merge the epic→main PR

quality:
  testing: required        # required | recommended | skip
  comments: verbose        # verbose | minimal

parallelism: false         # true = wave-based epic structure
```

Missing file or missing keys default to maximum oversight (all `true`, `testing: required`).

**When `human_required: true`:** the agent presents output in chat and waits for your
approval before writing to GitHub. GitHub only receives work you've approved.

**When all gates are `false`:** running `/hackathon-plan` kicks off the full pipeline
autonomously. Any failure always escalates to you regardless of config.

### Gate reference

| Gate | Governs | On | Off |
|---|---|---|---|
| `project_breakdown.grilling` | `hackathon-plan` | Interrogate before scoping projects | Best-guess from PLAN.md |
| `project_breakdown.human_required` | `hackathon-plan` | Chat approval before GitHub Projects created | Created immediately |
| `epic_breakdown.grilling` | `hackathon-epics` | Interrogate before scoping epics | Best-guess |
| `epic_breakdown.human_required` | `hackathon-epics` | Chat approval before epics hit GitHub | Created immediately |
| `task_breakdown.grilling` | `hackathon-decompose` | Interrogate before decomposing each epic | Best-guess |
| `task_breakdown.human_required` | `hackathon-decompose` | Chat approval before tasks hit GitHub | Created immediately |
| `task_completion.human_required` | `hackathon-session` | Chat approval before PR opens | PR opens after tests pass |
| `code_review.human_required` | `hackathon-session` | You trigger review, decide merge | Auto-review, auto-merge |
| `epic_review.human_required` | `hackathon-verify` | You merge the epic→main PR | Auto-merges on clean verify |

### Testing levels

| Level | Behavior |
|---|---|
| `required` | Full path coverage enforced — hard stop before any PR if code paths are uncovered |
| `recommended` | Main logic paths tested — missing edge coverage flagged but not blocking |
| `skip` | No test suite run, no test writing requirement |

---

## The state machine

Issues arrive on GitHub already labeled `ai-approved` (when `human_required: true`,
approval happened in chat first). `needs-human-review` is reserved for bugs and
discovered scope that always require human judgment regardless of config.

```
ai-approved  →  in-progress  →  in-review  →  closed
                                     │
                        request changes → ai-approved
```

| Label | Who sets it | Meaning |
|---|---|---|
| `needs-human-review` | AI | Bug or discovered scope — always needs human judgment |
| `ai-approved` | AI (after chat approval) or config | Ready for an agent to claim |
| `in-progress` | AI | Actively being worked |
| `in-review` | AI | PR is open and unmerged |
| `blocked` | AI | Waiting on a dependency — auto-clears when dependencies close |
| `epic` | AI | Parent container — work happens in child task issues |
| `bug` | AI | Broken behavior — routed to `hackathon-debug` |

---

## Branch structure

One branch per epic. One branch per task, forked off its epic branch.

```
main
├── epic-1-auth
│   ├── 5-create-users-table
│   ├── 6-implement-login-endpoint
│   └── ↑ task PRs merge here; epic branch → main via verify PR
└── epic-2-dashboard
    └── ...
```

Task PRs target the epic branch. The verify task opens the epic→main PR.
Epic branches are rebased onto the latest main before the verify PR opens.

---

## Division of responsibility

Agents always handle (regardless of config):
- Collision-safe task claiming for multi-machine teams
- Baseline testing before every implementation
- Progressive testing with expected-vs-actual output
- Auto-debugging regressions before opening a PR
- End-to-end epic verification and security audit before the final merge
- Escalating to human on any failure, always

You control via config:
- Whether agents interrogate before scoping projects, epics, and tasks
- Whether you approve projects, epics, and tasks before they hit GitHub
- Whether you sign off on completed work before PRs open
- Whether you trigger code reviews and decide merges
- Whether you merge the final epic→main PR

---

## Skills reference

**Getting started:**

| Slash command | What it does |
|---|---|
| `/hackathon-setup` | Start here — detects new vs existing project, scans codebase, configures oversight via wizard |

**The four phases:**

| Slash command | Phase | What it does |
|---|---|---|
| `/hackathon-plan` | 1 | Scope PLAN.md → Projects + generate SPECS.md + create GitHub Project boards |
| `/hackathon-epics` | 2 | Scope Projects → Epic issues on GitHub |
| `/hackathon-decompose` | 3 | Scope Epics → Task issues + epic branches |
| `/hackathon-session` | 4 | Implement Tasks → code + PRs |

**Adding scope:**

| Slash command | What it does |
|---|---|
| `/hackathon-add` | Add features, security hardening, refactoring, or any initiative to a running project |

**Review and tracking:**

| Slash command | What it does |
|---|---|
| `/hackathon-review` | Review one PR, post findings, execute merge or request-changes |
| `/hackathon-projects` | Project-level status; close a GitHub Project when all its epics merge |
| `/hackathon-test` | Run the test suite; also auto-called during tasks |
| `/hackathon-debug` | Reproduce, fix, and regression-test a failure; also auto-called on regressions |
| `/hackathon-docs-demo-script` | Generate README, API reference, and demo walkthrough; auto-called when all epics close |

**Auto-called internally (not triggered directly):**

| Skill | When |
|---|---|
| `hackathon-verify` | Last task of each epic — verifies E2E, runs security audit, opens epic→main PR |
| `hackathon-grilling` | By `hackathon-plan`, `hackathon-epics`, `hackathon-decompose`, `hackathon-add` when `grilling: true` |
| `hackathon-frontend` | By session when task involves UI, components, pages, layouts |
| `hackathon-auth` | By session when task involves auth, login, OAuth, JWT, permissions |
| `hackathon-database-schema` | By session when task involves schema, migrations, data models |
| `hackathon-deploy` | By session when task involves deployment, CI/CD, Docker, hosting |
| `hackathon-seed-demo-data` | By session when task involves seed data, demo data, fixtures |
| `hackathon-security-audit` | By `hackathon-verify` before every epic→main PR |

Using a different agent CLI? See `HARNESS.md`.

---

## File structure

```
skills/
  hackathon-setup.md            — start here: onboarding wizard, existing-project scan, config setup
  hackathon-plan.md             — Phase 1: PLAN.md → Projects + SPECS.md
  hackathon-epics.md            — Phase 2: Projects → Epic issues
  hackathon-decompose.md        — Phase 3: Epics → Task issues + epic branches
  hackathon-session.md          — Phase 4: Tasks → code + PRs
  hackathon-add.md              — add features / hardening / refactoring to a running project
  hackathon-projects.md         — project-level status and GitHub Project board close-out
  hackathon-review.md           — review one PR, post findings, execute decision
  hackathon-verify.md           — last task per epic: E2E verify, security audit, epic→main PR
  hackathon-test.md             — run test suite, report expected vs actual + coverage
  hackathon-debug.md            — reproduce, fix, and regression-test a failure
  hackathon-grilling.md         — recursive interrogation until zero ambiguities (internal)
  hackathon-frontend.md         — design system, component architecture, a11y, performance (internal)
  hackathon-auth.md             — JWT/session/OAuth patterns and security traps (internal)
  hackathon-database-schema.md  — schema design, indexing, FK constraints (internal)
  hackathon-deploy.md           — Dockerfile, CI/CD, env wiring, platform fast paths (internal)
  hackathon-seed-demo-data.md   — realistic fixtures, demo mode toggle (internal)
  hackathon-security-audit.md   — OWASP scan before every epic→main PR (internal)
  hackathon-docs-demo-script.md — README + API reference + demo walkthrough (auto on complete)
hackathon.config.yml            — oversight gates, testing level, comments verbosity, parallelism
make-claude-md.sh               — bootstrap script (installed as hackathon-bootstrap on Mac/Linux)
make-claude-md.ps1              — bootstrap script (installed as hackathon-bootstrap on Windows)
PLAN.md                         — fill in manually, or let hackathon-setup generate it
SPECS.md                        — auto-generated by hackathon-plan; do not edit during parallel work
AGENTS.md                       — agent coordination protocol (read by all harnesses)
HARNESS.md                      — setup guide for non-Claude Code harnesses
```

The bootstrap script generates these locally — gitignored, never committed:
```
CLAUDE.md                  — full skill content for Claude Code
.claude/commands/          — /hackathon-* slash commands
.claude/settings.json      — GitHub MCP pre-approved
```

Regenerate after any skill change. Every teammate runs this after cloning.

---

## Requirements

- [Claude Code](https://docs.anthropic.com/claude-code)
- Docker (for the GitHub MCP server)
- GitHub Personal Access Token — one per teammate, `repo` scope
- GitHub repo with Issues and Projects enabled
