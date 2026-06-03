# Adapting This Repo for Non-Claude Code Harnesses

This repo is designed for **Claude Code** (`claude -p "Go"` headless mode). If your
team uses a different agent harness (Aider, Cursor, Codex, Gemini CLI, custom LLM
runner, etc.), this document explains how to wire it up so you get the same autonomous
loop with your toolchain.

The coordination protocol (GitHub Issues as shared brain, label state machine, branch
per issue, PR-only close-out) is harness-agnostic. Only the invocation and context
loading need to change.

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

## Step 1 — Add your harness directory to `.gitignore`

Open `.gitignore` and add any directories your harness generates locally:

```
# My harness
.your-harness-config-dir/
your-harness-cache/
```

Commit this change to `.gitignore` so teammates using Claude Code don't accidentally
commit your harness files either.

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

When there is nothing to do, output exactly: NOTHING_TO_DO
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

Create a script that:
1. Invokes your harness with the "Go" trigger and your context file
2. Checks the output for `NOTHING_TO_DO`
3. Loops until `MAX_IDLE` consecutive nothing-to-do responses

Example for a generic harness (`my-agent run --context <file> --prompt "Go"`):

```bash
#!/usr/bin/env bash
set -euo pipefail

CONTEXT_FILE="YOUR_HARNESS.md"
IDLE=0
MAX_IDLE=3     # exit after this many consecutive NOTHING_TO_DO signals
IDLE_WAIT=60   # seconds between idle retries (longer = less wasted context)

echo "Agent loop started. Press Ctrl-C to stop."
while true; do
  echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
  output=$(my-agent run --context "$CONTEXT_FILE" --prompt "Go" 2>&1)
  printf '%s\n' "$output"

  if printf '%s' "$output" | grep -qF 'NOTHING_TO_DO'; then
    IDLE=$((IDLE + 1))
    [[ $IDLE -ge $MAX_IDLE ]] && { echo "All done."; break; }
    echo "Idle ($IDLE/$MAX_IDLE). Waiting ${IDLE_WAIT}s..."
    sleep "$IDLE_WAIT"
  else
    # Waiting for peers is not idle — reset the counter.
    IDLE=0
    sleep 3
  fi
done
```

**Critical:** the session skill outputs "Waiting — N task(s) still in progress" (not
`NOTHING_TO_DO`) when peers still have work. Your loop must NOT increment the idle
counter on that output — only on a literal `NOTHING_TO_DO`. The grep above handles
this correctly since `grep -qF 'NOTHING_TO_DO'` won't match the waiting message.

Name it something distinct (e.g., `run-gemini.sh`) and add it to `.gitignore` if it
contains harness-specific configuration.

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

| Commit | Do not commit |
|---|---|
| `.gitignore` (updated with your harness dir) | Your harness's local config/cache dirs |
| `YOURHARNESS.md` (context file) | Secrets or PATs |
| `run-yourharness.sh` (loop runner) | Duplicate of `CLAUDE.md` or `run.sh` |
