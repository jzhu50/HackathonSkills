# hackathon-agent-skills

Coordination skills and bootstrap tooling for running autonomous AI coding agents
as a small team during a hackathon.

**The pitch:** fill in a plan, run a setup command, then say "Go" on each machine.
Agents claim tasks, write code, open PRs, review PRs, implement feedback, and repeat
until everything is done. Teammates are hands-off.

---

## What this repo is

This is the **skills repo** — it contains the agent instructions and the bootstrap
scripts. It lives on each teammate's machine and is NOT your hackathon project.

Your hackathon project is a separate repo that you create from a template. The
bootstrap script wires the two together.

---

## How it works

**GitHub is the shared brain.** All agents — on all machines — coordinate through
GitHub Issues. No shared filesystem, no message queue, no human in the loop.

| Primitive | Role |
|---|---|
| Issues | Units of work — tasks and epics |
| Labels | State machine (`ready` → `in-progress` → `in-review` → closed) |
| Assignees | Who is working on what right now |
| Comments | Handoff notes, blocker explanations, review feedback |
| PRs | The only valid close-out path — audit trail and review gate |
| `PLAN.md` | Vision, stack, features, decisions |
| `SPECS.md` | Optional: data models, API contracts, UI flows |

**Each agent does one unit of work per context** — claim one task or one PR review,
finish it, stop. Context is cleared automatically. The `run.sh` loop restarts the
agent for the next unit. This keeps state clean across parallel agents.

**Agent loop per machine:**
```
while work exists:
  claude -p "Go"    ← fresh context, one task or one PR review
```

---

## Repo structure

```
skills/
  hackathon-setup.md       — run once to bootstrap the project
  hackathon-session.md     — claim + do one task or review, then stop
  hackathon-decompose.md   — break a needs-scoping epic into tasks
  hackathon-review.md      — review one PR, merge or request changes
make-claude-md.sh          — bootstrap script (Mac/Linux)
make-claude-md.ps1         — bootstrap script (Windows)
PLAN.md                    — template: fill this in for each hackathon
SPECS.md                   — template: optional implementation detail
AGENTS.md                  — coordination protocol reference
```

The bootstrap script generates in your hackathon project:
```
CLAUDE.md                  — full skill content (loaded by claude -p automatically)
.claude/commands/          — slash commands for interactive Claude Code sessions
.claude/settings.json      — GitHub MCP pre-approved (no permission prompts)
run.sh / run.ps1           — the autonomous loop script
```

---

## Setup

### Step 1 — One time: clone this skills repo on each machine

```bash
git clone https://github.com/<org>/hackathon-agent-skills ~/hackathon-skills
```

### Step 2 — Per hackathon: create your project repo

Use the GitHub template or create a new repo. Copy `PLAN.md`, `SPECS.md`, and
`AGENTS.md` from this repo into the project root.

### Step 3 — Fill in the plan (~10 minutes as a team)

Edit `PLAN.md` in the project repo:
- Vision and demo goal
- Tech stack decisions
- Core features (these become epics)
- Out of scope

Leave `SPECS.md` blank for now — fill it in as decisions get made.

### Step 4 — Bootstrap each machine

Run the bootstrap script from this skills repo, pointing at your project:

```bash
# Mac/Linux
~/hackathon-skills/make-claude-md.sh /path/to/your/project

# Windows
~\hackathon-skills\make-claude-md.ps1 C:\path\to\your\project
```

This generates `CLAUDE.md`, `.claude/commands/`, `.claude/settings.json`, and
`run.sh`/`run.ps1` in your project. Run it on every teammate's machine.

### Step 5 — Configure GitHub MCP on each machine

Each teammate needs the GitHub MCP server configured with their own Personal Access
Token (PAT). Use your own PAT — not a shared one — so agent actions are attributable.

**Required PAT scopes:** `repo`, `read:org`

**Recommended: enable branch protection on `main`** in your project repo
(Settings → Branches → Require a pull request before merging). This prevents agents
from accidentally pushing directly to main.

**Docker-based GitHub MCP config** (add to your Claude Code MCP settings):

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

For other MCP configurations, see the
[GitHub MCP Server docs](https://github.com/github/github-mcp-server).

### Step 6 — Run setup (once per hackathon, one person)

In your project repo, open Claude Code and say:

```
Set up the project
```

The agent reads `PLAN.md`, interrogates you recursively until the plan is
unambiguous (asking about done criteria, dependencies, priorities, environment
requirements, etc.), then creates all GitHub labels and epic issues automatically.
No manual issue creation needed.

### Step 7 — Start the agent loop on each machine

```bash
# Mac/Linux
cd /path/to/your/project
./run.sh

# Windows
cd C:\path\to\your\project
.\run.ps1
```

That's it. Each machine now runs agents autonomously:

- Agents read GitHub state fresh each session
- They claim ready tasks using a collision-safe sequence
- They work on feature branches, never `main`
- They open PRs when done
- They pick up PR reviews and merge approved code
- If changes are requested, the issue returns to `ready` and the next agent implements the fixes
- When everything is done, the loop exits

**Run `run.sh` on every teammate's machine simultaneously** for parallel agents.

---

## Skills reference

| Skill | How it's used |
|---|---|
| `hackathon-setup` | Once — interrogates human, creates labels and epics |
| `hackathon-session` | Every loop iteration — one task or review, then stop |
| `hackathon-decompose` | Automatic — breaks `needs-scoping` epics into tasks |
| `hackathon-review` | Automatic — reviews one PR, merges or requests changes |

In interactive Claude Code sessions, these are available as `/hackathon-setup`,
`/hackathon-session`, `/hackathon-decompose`, `/hackathon-review`.

In autonomous mode (`run.sh`), the agent follows `hackathon-session` which routes
internally to decompose or review as needed.

---

## Non-Claude Code agents

`AGENTS.md` is the full coordination protocol. Paste it as a system prompt.
Paste individual skill files as additional context when invoking them.
The `run.sh` loop requires the `claude` CLI — adapt it for your agent's CLI equivalent.

---

## Requirements

- Claude Code CLI (`claude`) installed on each machine
- Docker (for the GitHub MCP server)
- GitHub Personal Access Token per teammate (`repo` scope)
- GitHub repo (public or private)
