# Hackathon Agent Template

AI agents write the code. Humans stay in control.

Fill in the plan, run setup, approve what you want built — agents implement, test,
and open PRs. You review every PR before anything merges.

**This repo is a template.** Create a repo using this as a template, fill in `PLAN.md`, and follow the
workflow below.

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

---

## The state machine

Every issue moves through this sequence. AI only acts on `ai-approved` items.

```
needs-human-review  →  ai-approved  →  in-progress  →  in-review  →  closed
                                                             │
                                             request changes → ai-approved (fixed, re-reviewed)
```

| Label | Who sets it | Meaning |
|---|---|---|
| `needs-human-review` | AI | Output ready — human must review before work continues |
| `ai-approved` | Human | Cleared for AI to pick up |
| `in-progress` | AI | Actively being worked |
| `in-review` | AI | PR open — human triggers review |
| `blocked` | AI | Waiting on a dependency — auto-returns to `needs-human-review` when resolved |
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
epic→main PR. You merge that to close the epic.

---

## Workflow

### 1 — Fill in the plan
Edit `PLAN.md` as a team: vision, demo goal, stack, features, out-of-scope.
Then run `/hackathon-setup`.

### 2 — Setup interrogates you
The agent asks questions until every ambiguity is resolved, then creates GitHub
labels and one epic issue per feature — all labeled `needs-human-review`.

### 3 — You approve epics
Read each epic. Add `ai-approved` to any you're satisfied with.
The agent won't touch an epic until you approve it.

### 4 — Decompose approved epics
Run `/hackathon-decompose`. For each approved epic the agent:
- Creates an epic branch (`epic-<n>-<slug>`) from main
- Breaks the epic into scoped tasks (each labeled `needs-human-review`)
- Appends a mandatory **verify task** as the final child

### 5 — You approve tasks
Read each task. Add `ai-approved` to any you're satisfied with.
Blocked tasks unblock automatically when their dependencies close and then
surface for your review.

### 6 — Implement approved tasks
Run `/hackathon-session`. The agent loops through all `ai-approved` tasks:
- Runs the test suite for a baseline before touching anything
- Implements on a branch off the epic branch
- Runs tests progressively — outputs expected vs actual
- Calls the debug skill automatically if a passing test starts failing
- Opens a PR targeting the epic branch

Loops until no approved tasks remain, then stops and reports.

### 7 — You review PRs
For each `in-review` PR, run `/hackathon-review`. The agent reads the diff,
checks every acceptance criterion, and posts detailed findings.

You decide: **"merge"** or **"request changes: [specifics]"**. The agent executes
your call. On request-changes the task returns to `ai-approved` and the session
picks it up on the next run.

**Nothing merges without your instruction.**

### 8 — Verify closes each epic
When all non-verify tasks are merged, the session picks up the verify task:
- Rebases the epic branch onto the latest main
- Runs the full test suite
- Checks every acceptance criterion from the epic
- Opens a PR: epic branch → main

You review and merge. That closes the epic.

### 9 — Repeat until done
Work through remaining epics. The project is complete when all epics are closed.

---

## Division of responsibility

**Agents handle:**
- Claiming tasks safely (collision-safe for multi-machine teams)
- Baseline testing before every implementation
- Progressive testing with expected-vs-actual output during implementation
- Auto-debugging regressions before opening a PR
- Opening PRs with `Closes #N` for automatic issue close on merge
- End-to-end epic verification before the final merge

**You handle:**
- Reviewing and approving epics
- Reviewing and approving tasks
- Triggering PR reviews
- Deciding: merge or request changes
- Merging the epic→main PR

---

## File structure

```
skills/
  hackathon-setup.md       — run once: interrogates human, creates labels and epics
  hackathon-decompose.md   — loops through ai-approved epics, creates tasks + epic branches
  hackathon-session.md     — loops through ai-approved tasks, implements and opens PRs
  hackathon-review.md      — reviews one PR, posts findings, executes your decision
  hackathon-verify.md      — last task per epic: verifies E2E, opens epic→main PR
  hackathon-test.md        — runs test suite, reports expected vs actual
  hackathon-debug.md       — reproduces, fixes, and regression-tests a failure
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

**The Test command row is required** — agents run it before every PR.
(`npm test`, `pytest`, `go test ./...`, `cargo test`, etc.)

### 5 — Configure GitHub MCP

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

### 6 — Run setup

```
/hackathon-setup
```

The agent interrogates you until the plan is airtight, then creates all labels and
epic issues.

---

## Skills reference

| Slash command | What it does |
|---|---|
| `/hackathon-setup` | Run once — interrogates human, creates labels and epics |
| `/hackathon-decompose` | Loops through ai-approved epics, creates tasks |
| `/hackathon-session` | Loops through ai-approved tasks, implements and opens PRs |
| `/hackathon-review` | Reviews one PR, posts findings, executes your decision |
| `/hackathon-verify` | Auto-called as the last task of each epic |
| `/hackathon-test` | Auto-called during tasks; also runnable by humans |
| `/hackathon-debug` | Auto-called on regressions; also runnable for bug issues |

Using a different agent CLI? See `HARNESS.md`.

---

## Requirements

- [Claude Code](https://docs.anthropic.com/claude-code)
- Docker (for the GitHub MCP server)
- GitHub Personal Access Token — one per teammate, `repo` scope
- GitHub repo with Issues enabled
