# Hackathon Agent Template

AI agents write the code. You control how much they check with you.

Fill in the plan, configure your oversight level, and run setup — agents implement,
test, and open PRs. Every gate is configurable: from full human review at every step
to fully autonomous end-to-end execution.

**This repo is a template.** Create a repo using this as a template, fill in `PLAN.md`,
configure `hackathon.config.yml`, and follow the workflow below.

---

## How it works

GitHub Issues are the coordination layer. Agents have no memory between sessions —
everything they need lives in GitHub.

| Primitive | Role |
|---|---|
| Issues | Units of work — epics, tasks, bugs |
| Labels | The state machine — controls what AI can touch |
| PRs | The only way to close a task — every change goes through review |
| `PLAN.md` | Vision, stack, features, decisions — the project bible |
| `SPECS.md` | Optional: data models, API contracts, UI flows |
| `hackathon.config.yml` | Controls human oversight at every step |

---

## Configuring oversight

`hackathon.config.yml` at the repo root controls all human gates. Missing file = max oversight.

```yaml
gates:
  epic_breakdown:
    human_required: true   # approve proposed epics in chat before GitHub
    grilling: true         # recursive interrogation before scoping epics

  task_breakdown:
    human_required: true   # approve proposed tasks in chat before GitHub
    grilling: true         # recursive interrogation before decomposing each epic

  task_completion:
    human_required: true   # approve completed work in chat before PR opens

  code_review:
    human_required: true   # you trigger review and decide merge/changes on task PRs

  epic_review:
    human_required: true   # you review and merge the epic→main PR

quality:
  testing: required        # required | recommended | skip
  comments: verbose        # verbose | minimal

parallelism: false         # true = wave-based epic structure (foundations first, then integrations)
```

**When `human_required: true`:** the agent presents its output in chat and waits for
your approval before writing to GitHub. If you request changes, it applies them and
loops back for approval. GitHub only receives work you've approved.

**When all gates are `false`:** a single `/hackathon-goal` runs the entire pipeline
autonomously. Any failure (test regression, verify failure) always escalates to you
regardless of config.

### Gate reference

| Gate | On | Off |
|---|---|---|
| `epic_breakdown.grilling` | Recursive interrogation until zero ambiguities | Best-guess from PLAN.md |
| `epic_breakdown.human_required` | Chat approval before epics hit GitHub | Epics created immediately |
| `task_breakdown.grilling` | Interrogation before each epic is decomposed | Best-guess task breakdown |
| `task_breakdown.human_required` | Chat approval before tasks hit GitHub | Tasks created immediately |
| `task_completion.human_required` | Chat approval before PR opens | PR opens after tests pass |
| `code_review.human_required` | You trigger review, decide merge/changes | Auto-review, auto-merge on APPROVE |
| `epic_review.human_required` | You merge the epic→main PR | Auto-merges on clean verify |

### Testing levels

| Level | Behavior |
|---|---|
| `required` | Full path coverage enforced — hard stop before PR if any code path is uncovered |
| `recommended` | Main logic paths must be tested — missing edge coverage flagged but not blocking |
| `skip` | No test suite run, no test writing requirement |

---

## The state machine

Issues land on GitHub already labeled `ai-approved` (when `human_required: true`,
approval happened in chat first). `needs-human-review` is reserved for bug issues
and discovered-scope items that always require human judgment.

```
ai-approved  →  in-progress  →  in-review  →  closed
                                     │
                        request changes → ai-approved (fixed, re-reviewed)
```

| Label | Who sets it | Meaning |
|---|---|---|
| `needs-human-review` | AI | Bug or discovered scope — always needs human judgment |
| `ai-approved` | AI (after chat approval) or config | Ready for an agent to claim |
| `in-progress` | AI | Actively being worked |
| `in-review` | AI | PR open |
| `blocked` | AI | Waiting on a dependency — auto-clears when dependencies close |
| `epic` | AI | Parent issue — work happens in child tasks |
| `bug` | AI | Broken behavior — routed to the debug skill |

---

## Branch structure

One branch per epic. One branch per task, forked off its epic.

```
main
├── epic-1-auth
│   ├── 5-create-users-table
│   ├── 6-implement-login-endpoint
│   └── ↑ task PRs merge here; epic branch → main via verify PR
└── epic-2-dashboard
    └── ...
```

Task PRs target the epic branch. The final task per epic (verify) opens the
epic→main PR.

---

## Workflow

### 1 — Fill in the plan

Edit `PLAN.md`: vision, demo goal, stack, features, out-of-scope.
Set `hackathon.config.yml` to your preferred oversight level.
Then run `/hackathon-setup`.

### 2 — Setup scopes epics

If `grilling: true`, the agent interrogates you until every ambiguity is resolved
before proposing anything. If `grilling: false`, it proceeds immediately from PLAN.md.

If `parallelism: true`, epics are structured into waves:
- **Wave 1** — independent foundations, each built with stubs for cross-dependencies
- **Wave 2** — integration epics that wire the foundations together

If `epic_breakdown.human_required: true`, the agent presents proposed epics in chat
and waits for your approval (with re-presentation on changes) before creating GitHub
issues. If `false`, issues are created immediately.

### 3 — Decompose epics into tasks

Run `/hackathon-decompose`. For each epic:
- If `task_breakdown.grilling: true`: interrogates before decomposing
- If `task_breakdown.human_required: true`: presents tasks in chat for approval before creating issues
- Creates an epic branch (`epic-<n>-<slug>`) from main
- Appends a mandatory **verify task** as the final child

### 4 — Implement tasks

Run `/hackathon-session`. The agent loops through all `ai-approved` tasks:
- Runs baseline tests before touching anything (unless `testing: skip`)
- Implements on a branch off the epic branch
- Runs tests progressively, calls debug automatically on regressions
- Enforces coverage at the level configured in `testing`
- If `task_completion.human_required: true`: presents completed work in chat for
  approval before opening a PR. Applies changes, re-runs tests, re-presents until
  you approve.
- Opens a PR
- If `code_review.human_required: false`: immediately reviews and merges the PR,
  looping through any requested fixes until APPROVE

### 5 — Review PRs (if `code_review.human_required: true`)

Run `/hackathon-review` for each `in-review` PR. The agent reads the diff, checks
every acceptance criterion, and posts findings.

Say **"merge"** or **"request changes: [specifics]"**. On request-changes the task
returns to `ai-approved` and the session picks it up.

### 6 — Verify closes each epic

The session picks up the verify task automatically when all sibling tasks are merged:
- Rebases the epic branch onto the latest main
- Runs the full test suite
- Checks every acceptance criterion from the epic
- Opens a PR: epic branch → main
- If `epic_review.human_required: false`: merges immediately on clean verify
- Any failures file bug issues and always escalate to you regardless of config

### 7 — Repeat until done

Work through remaining epics. The project is complete when all epics are closed.

### Fully autonomous

With all gates off, a single command runs everything:

```
/hackathon-goal build <project name>
```

---

## Division of responsibility

What the agents always handle (regardless of config):
- Collision-safe task claiming for multi-machine teams
- Baseline testing before every implementation
- Progressive testing with expected-vs-actual output
- Auto-debugging regressions before opening a PR
- End-to-end epic verification before the final merge
- Escalating to human on any failure, always

What you control via config:
- Whether the agent interrogates before planning
- Whether you approve epics and tasks in chat before they hit GitHub
- Whether you sign off on completed work before PRs open
- Whether you trigger code reviews and decide merges
- Whether you merge the final epic→main PR

---

## File structure

```
skills/
  hackathon-setup.md       — run once: scopes epics, creates labels and issues
  hackathon-decompose.md   — loops through ai-approved epics, creates tasks + epic branches
  hackathon-session.md     — loops through ai-approved tasks, implements and opens PRs
  hackathon-review.md      — reviews one PR, posts findings, executes your decision
  hackathon-verify.md      — last task per epic: verifies E2E, opens epic→main PR
  hackathon-test.md        — runs test suite, reports expected vs actual + coverage
  hackathon-debug.md       — reproduces, fixes, and regression-tests a failure
  hackathon-grilling.md    — recursive interrogation until zero ambiguities (internal)
hackathon.config.yml       — oversight gates, testing level, comments verbosity, parallelism
make-claude-md.sh          — bootstrap script (installed as hackathon-bootstrap on Mac/Linux)
make-claude-md.ps1         — bootstrap script (installed as hackathon-bootstrap on Windows)
PLAN.md                    — fill this in before setup
SPECS.md                   — optional: data models, API routes, UI flows
AGENTS.md                  — coordination protocol (read by all harnesses)
HARNESS.md                 — setup guide for non-Claude Code harnesses
```

The bootstrap script generates these locally — gitignored, never committed:
```
CLAUDE.md                  — full skill content for interactive Claude Code
.claude/commands/          — /hackathon-* slash commands
.claude/settings.json      — GitHub MCP pre-approved
```

Regenerate after any skill change. Every teammate runs this after cloning.

---

## Setup

### 1 — Install hackathon-skills

```bash
# Mac/Linux
curl -fsSL https://raw.githubusercontent.com/Victor-Casado/HackathonSkills/main/install.sh | bash

# Windows (PowerShell)
irm https://raw.githubusercontent.com/Victor-Casado/HackathonSkills/main/install.ps1 | iex
```

This installs two commands:
- `hackathon-skills` — PTY runner that launches your AI CLI
- `hackathon-bootstrap` — project bootstrapper (run once per cloned project)

### 2 — Create your project from the template

Click **"Use this template"** on GitHub to create a new repo, then clone it:

```bash
git clone https://github.com/<you>/<project-name>
cd <project-name>
```

### 3 — Bootstrap the project

```bash
hackathon-bootstrap      # Mac/Linux
hackathon-bootstrap      # Windows
```

This generates `CLAUDE.md` and `.claude/` locally (gitignored). Re-run after any skill update or after cloning on a new machine.

### 4 — Fill in `PLAN.md`

Vision, demo goal, tech stack, core features, out-of-scope, open questions.

**The Test command row is required** unless you set `testing: skip`.
(`npm test`, `pytest`, `go test ./...`, `cargo test`, etc.)

### 5 — Configure oversight

Edit `hackathon.config.yml`. The defaults give you full oversight at every gate.
Turn gates off one at a time as you build confidence, or set everything to `false`
for autonomous mode.

### 6 — Configure GitHub MCP

Each teammate needs a Personal Access Token with `repo` scope (add `read:org` for
org repos) configured in their Claude Code MCP settings:

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
before merging). Do **not** also require approvals unless you have two distinct
accounts — GitHub won't let you approve your own PR.

### 7 — Run setup

```
/hackathon-setup
```

---

## Skills reference

| Slash command | What it does |
|---|---|
| `/hackathon-setup` | Run once — scopes epics (with optional grilling + approval), creates labels and issues |
| `/hackathon-decompose` | Loops through ai-approved epics, creates tasks (with optional grilling + approval) |
| `/hackathon-session` | Loops through ai-approved tasks, implements, opens PRs, optionally auto-merges |
| `/hackathon-review` | Reviews one PR, posts findings, executes your decision (or returns verdict internally) |
| `/hackathon-verify` | Auto-called as the last task of each epic — verifies E2E, merges if configured |
| `/hackathon-test` | Auto-called during tasks; also runnable by humans |
| `/hackathon-debug` | Auto-called on regressions; also runnable for bug issues |

`hackathon-grilling` is called internally — not directly.

Using a different agent CLI? See `HARNESS.md`.

---

## Requirements

- [Claude Code](https://docs.anthropic.com/claude-code)
- Docker (for the GitHub MCP server)
- GitHub Personal Access Token — one per teammate, `repo` scope
- GitHub repo with Issues enabled
