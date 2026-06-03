# Adapting This Repo for Non-Claude Code Harnesses

This repo is designed for **Claude Code** (`claude -p "Go"` headless mode). If your
team uses a different agent harness (Aider, Cursor, Codex, Gemini CLI, custom LLM
runner, etc.), this document explains how to wire it up so you get the same autonomous
loop with your toolchain.

The coordination protocol (GitHub Issues as shared brain, label state machine, branch
per issue, PR-only close-out) is harness-agnostic. Only the invocation and context
loading need to change.

> **Fastest path:** paste the **Harness bootstrap prompt** from the README into your agent
> once. It performs Steps 1–4 below automatically — generating your context file, loop
> runner, and permission/auto-approve config — so you just run the produced script and walk
> away. This document is the long-form reference for what that prompt does and how to do it
> by hand.

---

## What stays the same (do not modify)

| File | Why |
|---|---|
| `AGENTS.md` | The coordination protocol — all harnesses follow this |
| `PLAN.md` | Project plan — filled in by the team, read by all agents |
| `SPECS.md` | Implementation detail — read by all agents |
| `skills/*.md` | Skill definitions — your harness loads these as prompts |
| `.gitignore` | Shared; add your harness directory to it (see below) |

---

## What you replace (harness-specific)

| Claude Code file | What it does | You create |
|---|---|---|
| `CLAUDE.md` | Context file auto-loaded by `claude` CLI | Your harness's equivalent context file |
| `run.sh` / `run.ps1` | Loop runner | Your harness's equivalent runner script |
| `.claude/settings.json` | Permission pre-approvals | Your harness's permission config |
| `.claude/commands/` | Slash commands | Your harness's equivalent (if any) |

**Do not commit your harness files with the same names as the Claude Code files.**
Use distinct names (e.g., `GEMINI.md`, `run-aider.sh`) so both harnesses can coexist
in the same repo without conflicts.

---

## Step 1 — Add your harness's local files to `.gitignore`

Open `.gitignore` and add your harness's config/cache directory **and** the context file and
loop runner you'll generate in Steps 2 and 4 (all local, per-machine — see "What to commit"):

```
# My harness
.your-harness-config-dir/
your-harness-cache/
YOURHARNESS.md          # generated context file (regenerate, don't commit)
run-yourharness.sh      # generated loop runner (regenerate, don't commit)
```

Commit this `.gitignore` change so teammates don't accidentally commit your harness files
either.

---

## Step 2 — Build your context file

Your harness needs to load the coordination protocol and all skills at the start of
each invocation. Concatenate the following into a single context file your harness
reads as a system prompt:

```
AGENTS.md
skills/hackathon-setup.md
skills/hackathon-session.md
skills/hackathon-decompose.md
skills/hackathon-review.md
skills/hackathon-debug.md
skills/hackathon-test.md
skills/hackathon-verify.md
```

**Header to prepend** (paste at the top of your combined context file):

```
# Agent Coordination Context

You are an autonomous software agent working on a hackathon project.
GitHub is the coordination layer — all state lives in GitHub Issues.
You have no memory between sessions.

Read AGENTS.md in full before acting. Then follow hackathon-session.

Trigger word: "Go"

Only hackathon-session Path E emits a loop signal, on its own line:
- WAITING_FOR_PEERS — nothing for you to claim, but peers are still working
- NOTHING_TO_DO — nothing in flight anywhere; the project is complete
```

Save this as a file your harness auto-loads (name it after your harness, e.g.,
`GEMINI.md`, `CODEX.md`, `AIDER.md`).

---

## Step 3 — Configure GitHub access

The skills assume the **GitHub MCP** (`mcp__github__*`) for all GitHub operations.
If your harness does not support MCP:

1. Replace every `mcp__github__*` instruction with equivalent `gh` CLI commands
2. Ensure `gh` is authenticated: `gh auth login`
3. The `gh` commands map as follows:

| MCP operation | gh CLI equivalent |
|---|---|
| Search issues | `gh issue list --label <label> --json number,title,assignees,labels` |
| Read issue | `gh issue view <number> --json body,comments,labels,assignees` |
| Create issue | `gh issue create --title "..." --body "..." --label "..."` |
| Update labels | `gh issue edit <number> --add-label "..." --remove-label "..."` |
| Add assignee | `gh issue edit <number> --add-assignee "@me"` |
| Add comment | `gh issue comment <number> --body "..."` |
| Create PR | `gh pr create --title "..." --body "..." --base main` |
| List PRs | `gh pr list --label in-review --json number,title,headRefName` |
| Get PR files | `gh pr diff <number>` |
| Merge PR | `gh pr merge <number> --squash --delete-branch` |
| PR review | `gh pr review <number> --approve` or `--request-changes -b "..."` |

**Make MCP/gh calls sequentially, not in parallel.** This rule holds regardless of harness.

---

## Step 4 — Build your loop runner

The loop must run **unattended**, so it has to invoke your harness with its auto-approve /
non-interactive flag (the equivalent of Claude Code's `--dangerously-skip-permissions`) —
otherwise the agent stalls at a permission prompt the loop can't answer. Find that flag for
your harness first; if it has none, unattended running is unsafe — stop and reconsider.

The loop branches on **three** outputs from `hackathon-session` Path E, in this order:

| Output contains | Meaning | Action |
|---|---|---|
| `NOTHING_TO_DO` | Project complete — nothing in flight anywhere | Count it; exit after `MAX_IDLE` consecutive; else wait `IDLE_WAIT` |
| `WAITING_FOR_PEERS` | Peers still working — a PR/task may appear soon | Reset count, wait `PEER_WAIT`, loop (NOT idle) |
| neither (did work) | A unit of work was done | Reset count, wait `WORK_WAIT`, loop |

Example for a generic harness (`my-agent run --auto-approve --context <file> --prompt "Go"`):

```bash
#!/usr/bin/env bash
set -euo pipefail

CONTEXT_FILE="YOUR_HARNESS.md"
AUTO_APPROVE="--auto-approve"   # your harness's skip-prompts flag — REQUIRED for AFK
IDLE=0
MAX_IDLE=3        # exit after this many consecutive NOTHING_TO_DO signals
IDLE_WAIT=60      # wait after NOTHING_TO_DO before re-checking
PEER_WAIT=30      # wait while peers are still working (not counted as idle)
WORK_WAIT=3       # wait between back-to-back units of real work

[ -f "$CONTEXT_FILE" ] || { echo "Missing $CONTEXT_FILE — run the bootstrap prompt first." >&2; exit 1; }

echo "Agent loop started. Press Ctrl-C to stop."
while true; do
  echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
  # || true: a transient harness failure must not kill the AFK loop via set -e.
  output=$(my-agent run $AUTO_APPROVE --context "$CONTEXT_FILE" --prompt "Go" 2>&1) || true
  printf '%s\n' "$output"

  if printf '%s' "$output" | grep -qF 'NOTHING_TO_DO'; then
    IDLE=$((IDLE + 1))
    [[ $IDLE -ge $MAX_IDLE ]] && { echo "Project complete — stopping."; break; }
    echo "Idle ($IDLE/$MAX_IDLE). Waiting ${IDLE_WAIT}s..."
    sleep "$IDLE_WAIT"
  elif printf '%s' "$output" | grep -qF 'WAITING_FOR_PEERS'; then
    IDLE=0
    echo "Peers still working. Waiting ${PEER_WAIT}s..."
    sleep "$PEER_WAIT"
  else
    IDLE=0
    sleep "$WORK_WAIT"
  fi
done
```

**Critical:** check `NOTHING_TO_DO` **before** `WAITING_FOR_PEERS`, and treat anything else
as real work. Only `NOTHING_TO_DO` counts toward the idle exit; `WAITING_FOR_PEERS` keeps the
machine in the pool so it picks up a peer's PR or newly-filed tasks instead of exiting early.

Name it distinctly (e.g., `run-gemini.sh`) and add it to `.gitignore` — it's a local,
per-machine file (see "What to commit" below).

---

## Step 5 — Configure GitHub MCP (if your harness supports it)

If your harness supports MCP servers, configure the GitHub MCP the same way as Claude
Code. The skills work identically with MCP on any harness that supports it.

---

## Step 6 — Update `.claude/settings.json` (optional)

If Claude Code users will also work on this repo, leave `.claude/settings.json`
as-is. Your harness's permissions config lives in its own file.

---

## Coexistence rules

If multiple harnesses are active on the same repo:

- Each harness reads the same `AGENTS.md` and `skills/*.md` — they coordinate through GitHub
- Each harness has its own runner script and context file — these do not conflict
- All agents obey the same collision-check protocol (re-read issue after claiming, back off on conflict)
- All agents follow the same branch discipline and PR-only close-out
- The issue state machine (labels) is the single source of truth — harness choice is invisible to GitHub

---

## What to commit

The context file and loop runner are **generated locally per machine**, exactly like Claude
Code's `CLAUDE.md` and `run.sh` — do not commit them. They are a concatenation of files that
already live in git (`AGENTS.md` + `skills/`), so committing them just creates a stale
duplicate, and CRLF/LF differences between Windows and Mac teammates cause conflicts on
identical source. Regenerate them with the bootstrap prompt after any skill change.

| Commit | Do not commit |
|---|---|
| `.gitignore` (updated with your harness dir, context file, and runner) | Your harness's config/cache dirs |
| Changes to shared source (`AGENTS.md`, `skills/`, `PLAN.md`) | `YOURHARNESS.md` context file (local, regenerate) |
| | `run-yourharness.sh` loop runner (local, regenerate) |
| | Secrets or PATs |
