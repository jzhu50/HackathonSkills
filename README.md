# Hackathon Agent Template

A template repo for running autonomous AI coding agents as a parallel team. Fill in
the plan, run setup, start the loop — agents claim tasks, write code, open PRs, review
PRs, implement feedback, run tests, and verify epics until everything is done.

**This repo IS your project.** Clone or fork it, fill in `PLAN.md`, run the bootstrap
script, and start the loop. No separate skills repo required.

---

## How it works

**GitHub is the shared brain.** All agents — on all machines — coordinate through
GitHub Issues. No shared filesystem, no message queue, no real-time communication.

| Primitive | Role |
|---|---|
| Issues | Units of work — tasks, epics, bugs |
| Labels | State machine (`ready` → `in-progress` → `in-review` → closed) |
| Assignees | Who is working on what right now |
| Comments | Handoff notes, blocker explanations, review feedback |
| PRs | The only valid close-out path — audit trail and review gate |
| `PLAN.md` | Vision, stack, features, decisions |
| `SPECS.md` | Optional: data models, API contracts, UI flows |

**Each agent does one unit of work per invocation** — claim one task or one PR review,
finish it, stop. The `run.sh` loop restarts the agent fresh for the next unit. Parallel
machines run simultaneous agents without stepping on each other.

**Agent loop per machine:**
```
while work exists:
  claude -p "Go"    ← fresh context, one task or one review
```

---

## What agents do autonomously

- Read GitHub state and synthesise what's most valuable to do
- Claim tasks using a collision-safe sequence (two agents can't grab the same task)
- Decompose vague epics into concrete, scoped tasks
- Implement tasks on feature branches (never `main`)
- Run tests before opening a PR; report any failures explicitly
- Open PRs with `Closes #N` for automatic issue close on merge
- Review PRs against acceptance criteria; merge or request specific changes
- Handle merge conflicts by rebasing the branch and re-requesting review
- Fix review feedback on the existing branch (no new PR needed)
- Debug `bug`-labeled issues: reproduce → diagnose → fix → regression test → PR
- Run the test suite when idle to discover pre-existing failures
- Verify entire epics end-to-end after all child tasks merge
- Detect and reclaim stalled work from crashed agents
- Capture newly discovered scope as issues without interrupting current work

---

## Repo structure

```
skills/
  hackathon-setup.md       — run once: interrogates human, creates labels and epics
  hackathon-session.md     — one task or review per invocation; the main loop entry
  hackathon-decompose.md   — break a needs-scoping epic into concrete tasks
  hackathon-review.md      — review one PR, merge or request changes
  hackathon-debug.md       — reproduce, fix, and regression-test a bug issue
  hackathon-test.md        — run test suite when idle; create bug issues for failures
  hackathon-verify.md      — verify a completed epic end-to-end; close or file bugs
make-claude-md.sh          — bootstrap script (Mac/Linux)
make-claude-md.ps1         — bootstrap script (Windows)
PLAN.md                    — fill this in before setup
SPECS.md                   — optional: fill in as decisions get made
AGENTS.md                  — coordination protocol (all harnesses read this)
HARNESS.md                 — instructions for non-Claude Code harnesses
.gitignore                 — covers secrets, harness dirs, build output
```

The bootstrap script generates (do not edit these manually — re-run the script to update):
```
CLAUDE.md                  — full skill content auto-loaded by claude -p
.claude/commands/          — slash commands for interactive Claude Code
.claude/settings.json      — GitHub MCP pre-approved (no permission prompts)
run.sh / run.ps1           — the autonomous loop runner
```

---

## Setup

### Step 1 — Clone or fork this repo as your project

```bash
git clone https://github.com/<org>/hackathon-agent-template <your-project-name>
cd <your-project-name>
```

Remove the origin and add your own:
```bash
git remote remove origin
git remote add origin https://github.com/<you>/<your-project-name>
git push -u origin main
```

### Step 2 — Fill in the plan (~10 minutes as a team)

Edit `PLAN.md`:
- Vision and demo goal
- Tech stack decisions (including **Test command** — this is required)
- Core features in priority order
- Out of scope
- Open questions

Leave `SPECS.md` blank for now — fill it in as decisions get made during interrogation.

**The Test command row is mandatory.** Agents run it before every PR and when idle.
Examples: `npm test`, `pytest`, `go test ./...`, `cargo test`, `bundle exec rspec`.

### Step 3 — Bootstrap each machine

Run the bootstrap script once per machine from the project root:

```bash
# Mac/Linux
./make-claude-md.sh

# Windows
.\make-claude-md.ps1
```

This generates `CLAUDE.md`, `.claude/commands/`, `.claude/settings.json`, and
`run.sh`/`run.ps1`. Re-run it whenever skills are updated.

### Step 4 — Configure GitHub MCP on each machine

Each teammate needs the GitHub MCP server configured with their own Personal Access
Token (PAT). Use your own PAT — not a shared one — so agent actions are attributable.

**Required PAT scopes:** `repo`, `read:org`

**Recommended: enable branch protection on `main`** (Settings → Branches → Require a
pull request before merging).

**Docker-based GitHub MCP config** (add to Claude Code MCP settings):

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

See the [GitHub MCP Server docs](https://github.com/github/github-mcp-server) for
alternative configurations.

### Step 5 — Run setup (once per project, one person)

In the project root, open Claude Code and say:

```
Set up the project
```

The agent:
1. Reads `PLAN.md` and `SPECS.md`
2. **Recursively interrogates you** until every ambiguity is resolved — done criteria,
   dependencies, priorities, environment requirements, technical decisions, scope
   boundaries, testing expectations. It keeps asking until it has no remaining questions.
3. Creates GitHub labels
4. Creates epic issues for each feature
5. Creates a mandatory **End-to-End Verification** epic (always the final gate)
6. Creates a `[Project] Tracking` issue with dependency map

### Step 6 — Start the agent loop on each machine

```bash
# Mac/Linux
./run.sh

# Windows
.\run.ps1
```

**Run on every teammate's machine simultaneously** for parallel agents. Each machine
runs independent agents that coordinate through GitHub.

---

## Skills reference

| Skill | Trigger | What it does |
|---|---|---|
| `hackathon-setup` | "Set up the project" | Interrogates human, creates labels, epics, and tracking issue |
| `hackathon-session` | "Go" (automatic) | Routes to the highest-value work and executes one unit |
| `hackathon-decompose` | Automatic (via session) | Breaks a `needs-scoping` epic into concrete tasks |
| `hackathon-review` | Automatic (via session) | Reviews one PR; merges or requests changes |
| `hackathon-debug` | Automatic (via session) | Reproduces, fixes, and regression-tests a `bug` issue |
| `hackathon-test` | Automatic (via session) | Runs test suite when idle; files bug issues for failures |
| `hackathon-verify` | Automatic (via session) | Verifies a completed epic end-to-end |

In interactive Claude Code: `/hackathon-setup`, `/hackathon-session`, etc.
In autonomous mode (`run.sh`): everything routes through `hackathon-session`.

---

## Session routing (what agents decide each invocation)

```
0  Epic with all children closed   → verify end-to-end before starting new work
A  Ready issue available           → detect type and execute:
     - Merge conflict comment      → rebase branch onto main
     - Review feedback comment     → fix and push to existing branch
     - Bug label                   → reproduce, fix, regression test
     - Otherwise                   → implement new task
A' No ready issues, stalled work   → reclaim crashed agent's in-progress task
B  No ready, needs-scoping exists  → decompose epic into tasks
C  No tasks or epics, PR waiting   → review PR and merge or request changes
D  Nothing else                    → run test suite; file bug issues for failures
E  Test suite green, nothing left  → NOTHING_TO_DO (loop waits or exits)
```

---

## Non-Claude Code harnesses

See `HARNESS.md` for a full guide on adapting this repo for Aider, Cursor, Gemini CLI,
Codex, or any other agent harness. The coordination protocol (`AGENTS.md` + `skills/`)
is harness-agnostic — only the invocation and context loading change.

Multiple harnesses can coexist in the same repo. Each generates its own config files;
`.gitignore` keeps them separate.

---

## Requirements

- Claude Code CLI (`claude`) — [install](https://docs.anthropic.com/claude-code)
- Docker — for the GitHub MCP server
- GitHub Personal Access Token per teammate (`repo` scope)
- GitHub repo with Issues enabled
