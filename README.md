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

The bootstrap script generates these **locally** (gitignored — never committed):
```
CLAUDE.md                  — full skill content auto-loaded by claude -p
.claude/commands/          — slash commands for interactive Claude Code
.claude/settings.json      — GitHub MCP pre-approved (no permission prompts)
run.sh / run.ps1           — the autonomous loop runner
```

Every teammate must run the bootstrap script after cloning. The generated files stay
local to each machine — committing them causes CRLF conflicts between Windows and Mac.

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

**Required PAT scopes:** `repo` (add `read:org` for org-owned repos)

**Recommended: enable branch protection on `main`** (Settings → Branches → **Require a
pull request before merging**). Do **not** also enable *Require approvals* unless you have
two or more distinct GitHub accounts reviewing — GitHub forbids approving your own PR, so a
solo dev running several machines on one PAT would deadlock at the merge gate. With "require
PR" alone (no required approval), an agent can still merge its own reviewed PR.

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

Every session first does bookkeeping (sync `main`, sweep `blocked` issues whose
dependencies are now closed back to `ready`), then routes to exactly one path:

```
0  Epic done & unclaimed           → claim it, verify end-to-end before new work
A  Ready issue available           → detect type and execute:
     - Merge conflict comment      → rebase branch onto main
     - Review feedback comment     → fix and push to existing branch
     - Bug label                   → reproduce, fix, regression test
     - Otherwise                   → implement new task
A' No ready, stale claim exists    → reclaim crashed implementer OR crashed reviewer
B  No ready, decomposable epic     → decompose epic (deps-met epics only) into tasks
C  No tasks/epics, actionable PR   → review PR and merge or request changes
D  Nothing else                    → run test suite; file bug issues for failures
E  Nothing actionable, suite green → WAITING_FOR_PEERS (peers busy) or NOTHING_TO_DO (done)
```

Only Path E emits the two loop signals. `WAITING_FOR_PEERS` keeps the machine in the
pool (a peer may open a PR or file tasks); `NOTHING_TO_DO` — emitted only when nothing is
in flight anywhere — lets the loop exit after `MAX_IDLE` consecutive signals.

---

## Non-Claude Code harnesses

The coordination protocol (`AGENTS.md` + `skills/`) works with any agent harness.
Only the invocation and context-loading differ. See `HARNESS.md` for the full guide.

Multiple harnesses can coexist in the same repo — each generates its own config files
locally and `.gitignore` keeps them out of git.

### Harness bootstrap prompt (copy-paste once — it builds your walk-away setup)

The Claude Code path has a bootstrap script (`make-claude-md.*`) that generates the context
file, the loop runner, and the permission config. Other harnesses don't have that script —
so this prompt makes the agent **be its own bootstrap script**. Paste it once into your
harness. It does not do project work: it sets up the environment so that afterwards you run
**one** generated script and walk away.

Paste this into your harness (Aider, Codex, Gemini CLI, Cursor, a custom runner, etc.):

---

```
You are setting up an autonomous-agent loop in THIS repo for the harness you are running in.
Do NOT do any project work yet. Your only job is to produce a "run and walk away" setup, then
tell me the one command to start it. Work through this checklist and report what you created:

1. Identify your harness and its CLI: the exact non-interactive / headless invocation (the
   flag that runs a single prompt and exits) and the flag that AUTO-APPROVES tool use so it
   never pauses for a permission prompt (e.g. an --auto-approve / --yes / --full-auto /
   "skip confirmations" flag). The loop cannot answer prompts, so this flag is mandatory —
   if you cannot find one, say so explicitly and stop, because unattended running is unsafe
   without it.

2. Generate a CONTEXT FILE named after your harness (e.g. AGENT-CONTEXT.md) by concatenating,
   in order: a short header saying "You are an autonomous agent on a parallel team; GitHub
   Issues are the shared brain; you have no memory between sessions; follow hackathon-session;
   only Path E emits NOTHING_TO_DO or WAITING_FOR_PEERS", then AGENTS.md, then PLAN.md, then
   every file in skills/. This is the equivalent of CLAUDE.md. Make your harness auto-load it.

3. Configure GitHub access. If your harness supports MCP, configure the GitHub MCP server.
   If not, the skills' `mcp__github__*` steps map to `gh` CLI commands (table in HARNESS.md);
   ensure `gh auth login` is done. Either way: make all GitHub calls SEQUENTIALLY, never in
   parallel.

4. Generate a LOOP RUNNER script (e.g. run-<harness>.sh / .ps1) that:
   - guards that the context file from step 2 exists, and exits with a clear message if not;
   - in a loop, invokes your harness headless with the auto-approve flag from step 1, the
     context file from step 2, and the prompt "Go", capturing combined output;
   - tolerates a transient non-zero exit from the harness without dying (don't let one failed
     invocation kill the loop);
   - branches on the output, IN THIS ORDER:
       * contains "NOTHING_TO_DO"     → count it; after 3 consecutive, print "done" and exit;
                                         otherwise wait 60s and loop;
       * contains "WAITING_FOR_PEERS" → reset the count, wait 30s, loop (NOT counted as idle);
       * otherwise (did real work)    → reset the count, wait 3s, loop.

5. Update .gitignore: add your harness's config/cache directory AND the generated context file
   and runner from steps 2 and 4 (they are local, per-machine, and would cause CRLF conflicts
   across OSes — never commit them). Commit ONLY the .gitignore change, nothing else.

6. Report: the files you created, the GitHub access method, and the single command I run to
   start the loop and walk away.
```

---

After the agent finishes, you run the one script it generated — that's the walk-away loop.
`HARNESS.md` has the same steps in long form, a ready-made loop template, and the full
`gh` CLI equivalents for every GitHub MCP operation.

---

## Requirements

- Claude Code CLI (`claude`) — [install](https://docs.anthropic.com/claude-code)
- Docker — for the GitHub MCP server
- GitHub Personal Access Token per teammate (`repo` scope; add `read:org` for org-owned repos)
- GitHub repo with Issues enabled
