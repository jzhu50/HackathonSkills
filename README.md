# Hackathon Agent Template

A template repo for running AI coding agents as a team with human review at every
major step. Fill in the plan, run setup, review epics, approve tasks, watch it build.

**This repo IS your project.** Clone or fork it, fill in `PLAN.md`, run setup, and
follow the human-in-the-loop workflow below.

---

## How it works

**GitHub is the shared brain.** All agents coordinate through GitHub Issues. No
shared filesystem, no message queue.

| Primitive | Role |
|---|---|
| Issues | Units of work — tasks, epics, bugs |
| Labels | State machine — see below |
| Assignees | Who is working on what right now |
| Comments | Handoff notes, blocker explanations, review findings |
| PRs | The only valid close-out path — audit trail and review gate |
| `PLAN.md` | Vision, stack, features, decisions |
| `SPECS.md` | Optional: data models, API contracts, UI flows |

---

## Label state machine

```
needs-human-review  →  ai-approved  →  in-progress  →  in-review  →  (merged/closed)
                                                             ↑
                                             on request-changes: back to ai-approved
```

| Label | Meaning |
|---|---|
| `needs-human-review` | AI produced output — human must review before AI continues |
| `ai-approved` | Human approved — AI can pick this up |
| `in-progress` | Actively being worked |
| `blocked` | Cannot proceed — comment explains why; will return to `needs-human-review` when unblocked |
| `in-review` | PR open — human triggers AI review |
| `epic` | Parent container — work happens in child task issues |
| `bug` | Something is broken |

---

## Branch structure

```
main
├── epic-1-auth
│   ├── 5-create-users-table          (task branch)
│   ├── 6-implement-login-endpoint    (task branch)
│   └── (epic branch → main via verify PR)
├── epic-2-dashboard
│   └── ...
```

- `hackathon-decompose` creates each epic branch from main
- `hackathon-session` creates task branches off the epic branch
- Task PRs merge into the epic branch (human reviews and merges)
- The verify task opens the epic→main PR

---

## Workflow

```
1. Human fills PLAN.md (vision, stack, features)
   ↓
2. Run: hackathon-setup
   → Interrogates human until plan is unambiguous
   → Creates epic issues (needs-human-review)
   ↓
3. Human: review each epic, add `ai-approved` label when satisfied
   ↓
4. Run: hackathon-decompose
   → Creates epic branches
   → Breaks each epic into tasks (needs-human-review)
   → Adds mandatory verify task as the last child of each epic
   ↓
5. Human: review each task, add `ai-approved` label when satisfied
   ↓
6. Run: hackathon-session
   → Runs baseline tests before each task
   → Implements each ai-approved task on a branch off the epic branch
   → Runs tests throughout; auto-calls hackathon-debug on regressions
   → Opens PRs targeting the epic branch (in-review)
   → Loops until no ai-approved tasks remain
   ↓
7. Human: for each in-review PR, trigger: hackathon-review
   → AI reviews diff and posts detailed findings
   → Human says "merge" or "request changes"
   → On merge: PR closes, task closes, epic branch accumulates work
   → On request-changes: task returns to ai-approved for fixes
   ↓
8. When all non-verify tasks are merged:
   hackathon-session picks up the verify task
   → Rebases epic branch onto latest main
   → Runs full test suite
   → Checks every epic acceptance criterion
   → Opens PR: epic branch → main
   ↓
9. Human: review and merge the epic→main PR
   → Epic is closed
   ↓
10. Repeat for remaining epics. Project is done when all epics are closed.
```

---

## What agents do automatically

- Read GitHub state and identify the highest-value `ai-approved` task
- Claim tasks safely (lightweight collision detection for multi-machine teams)
- Run the test suite before starting any implementation (baseline)
- Implement tasks on branches off the epic branch
- Run tests progressively; explain expected vs actual output
- Auto-invoke `hackathon-debug` when a previously-passing test regresses
- Open PRs with `Closes #N` for automatic issue close on merge
- Verify entire epics end-to-end before opening the epic→main PR
- Detect and reclaim stalled work from crashed agents

## What humans do

- Review and approve epics before decomposition
- Review and approve tasks before implementation
- Trigger PR reviews (`hackathon-review`)
- Decide: merge or request changes
- Merge the final epic→main PR

**No AI agent merges anything without explicit human instruction.**

---

## Repo structure

```
skills/
  hackathon-setup.md       — run once: interrogates human, creates labels and epics
  hackathon-decompose.md   — loop through ai-approved epics, create tasks
  hackathon-session.md     — loop through ai-approved tasks, implement and PR
  hackathon-review.md      — review one PR, post findings, await human decision
  hackathon-debug.md       — reproduce, fix, and regression-test a bug or regression
  hackathon-test.md        — run test suite, report expected vs actual
  hackathon-verify.md      — verify epic end-to-end, open epic→main PR
make-claude-md.sh          — bootstrap script (Mac/Linux): generates CLAUDE.md and .claude/
make-claude-md.ps1         — bootstrap script (Windows): generates CLAUDE.md and .claude/
PLAN.md                    — fill this in before setup
SPECS.md                   — optional: fill in as decisions get made
AGENTS.md                  — coordination protocol (all harnesses read this)
HARNESS.md                 — guide for non-Claude Code harnesses
.github/ISSUE_TEMPLATE/    — issue templates for epics and tasks
```

The bootstrap script generates these **locally** (gitignored — never committed):
```
CLAUDE.md                  — full skill content auto-loaded by claude interactive
.claude/commands/          — slash commands for interactive Claude Code sessions
.claude/settings.json      — GitHub MCP pre-approved (no permission prompts)
```

Every teammate must run the bootstrap script after cloning.

---

## Setup

### Step 1 — Clone or fork this repo as your project

```bash
git clone https://github.com/<org>/hackathon-agent-template <your-project-name>
cd <your-project-name>
git remote remove origin
git remote add origin https://github.com/<you>/<your-project-name>
git push -u origin main
```

### Step 2 — Fill in the plan (~10 minutes as a team)

Edit `PLAN.md`:
- Vision and demo goal
- Tech stack decisions (including **Test command** — required)
- Core features in priority order
- Out of scope
- Open questions

**The Test command row is mandatory.** Agents run it before every PR.
Examples: `npm test`, `pytest`, `go test ./...`, `cargo test`.

### Step 3 — Bootstrap each machine

```bash
# Mac/Linux
./make-claude-md.sh

# Windows
.\make-claude-md.ps1
```

This generates `CLAUDE.md`, `.claude/commands/`, and `.claude/settings.json`.
Re-run whenever skills are updated.

### Step 4 — Configure GitHub MCP on each machine

Each teammate needs the GitHub MCP server configured with their own PAT.

**Required PAT scopes:** `repo` (add `read:org` for org-owned repos)

**Recommended: enable branch protection on `main`**
(Settings → Branches → Require a pull request before merging)

**Docker-based GitHub MCP config:**

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

### Step 5 — Run setup (once per project)

In the project root, open Claude Code and say:

```
Set up the project
```

or use the slash command `/hackathon-setup`.

### Step 6 — Follow the workflow

After setup creates epics: review each one and add `ai-approved` when ready.
Then run `/hackathon-decompose` to break them into tasks.
Review tasks, add `ai-approved`, then run `/hackathon-session` to implement.

---

## Skills reference

| Skill | Trigger | What it does |
|---|---|---|
| `hackathon-setup` | "Set up the project" | Interrogates human, creates labels and epics |
| `hackathon-decompose` | "Decompose the epics" | Loops through ai-approved epics, creates tasks |
| `hackathon-session` | "Go", "Work on tasks" | Loops through ai-approved tasks, implements and PRs |
| `hackathon-review` | "Review PR #X" | Reviews PR, posts findings, awaits human decision |
| `hackathon-debug` | Auto (on regression) or "Fix bug #N" | Reproduces, fixes, regression-tests |
| `hackathon-test` | Auto (during tasks) or "Run the tests" | Runs suite, reports expected vs actual |
| `hackathon-verify` | Auto (last task of each epic) | Verifies epic E2E, opens epic→main PR |

In interactive Claude Code: `/hackathon-setup`, `/hackathon-session`, etc.

---

## Requirements

- Claude Code CLI (`claude`) — [install](https://docs.anthropic.com/claude-code)
- Docker — for the GitHub MCP server
- GitHub Personal Access Token per teammate (`repo` scope)
- GitHub repo with Issues enabled
