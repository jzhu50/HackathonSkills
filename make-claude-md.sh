#!/usr/bin/env bash
#
# make-claude-md.sh — bootstrap a hackathon project for autonomous agent use
#
# Generates in the target project:
#   CLAUDE.md              — full skill content for headless mode (claude -p "Go")
#   .claude/commands/      — slash commands for interactive Claude Code
#   .claude/settings.json  — GitHub MCP pre-approved (no permission prompts)
#   run.sh                 — autonomous loop: runs until all tasks and reviews are done
#
# Usage:
#   ./make-claude-md.sh                  # targets current directory
#   ./make-claude-md.sh /path/to/project # targets a specific directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-$(pwd)}"
SKILLS_DIR="$SCRIPT_DIR/skills"
COMMANDS_DIR="$TARGET_DIR/.claude/commands"
SETTINGS_PATH="$TARGET_DIR/.claude/settings.json"
CLAUDE_MD="$TARGET_DIR/CLAUDE.md"
RUN_SH="$TARGET_DIR/run.sh"

if [ ! -d "$SKILLS_DIR" ]; then
  echo "Error: skills/ not found at $SKILLS_DIR" >&2; exit 1
fi

skills=("$SKILLS_DIR"/*.md)
if [ ! -f "${skills[0]}" ]; then
  echo "Error: no .md files in $SKILLS_DIR" >&2; exit 1
fi

mkdir -p "$COMMANDS_DIR"

# 1. Slash commands (interactive Claude Code)
for skill in "${skills[@]}"; do
  name="$(basename "$skill")"
  cp "$skill" "$COMMANDS_DIR/$name"
  echo "  command: .claude/commands/$name"
done

# 2. settings.json
if [ -f "$SETTINGS_PATH" ]; then
  echo "  WARNING: .claude/settings.json exists — not overwriting. Ensure mcp__github__* is in permissions.allow."
else
  cat > "$SETTINGS_PATH" <<'SETTINGS'
{
  "permissions": {
    "allow": [
      "mcp__github__*"
    ]
  }
}
SETTINGS
  echo "  settings: .claude/settings.json written"
fi

# 3. CLAUDE.md — coordination header + full skill content (for headless claude -p)
{
cat <<'HEADER'
# Hackathon Agent Coordination

> Auto-generated. Re-run the bootstrap script to update.

## GitHub MCP — use for all GitHub operations

Use `mcp__github__*` for every GitHub operation: issues, labels, assignees,
comments, pull requests. Never use `gh`, `curl`, or Bash for GitHub operations.
Make all MCP calls **sequentially, not in parallel.**

## Branch discipline

Every issue gets its own branch before any code is written.
`main` is protected — merge via PR only. Never commit to `main` directly.

## One unit of work per context

Each `claude -p "Go"` invocation does exactly one task or one PR review, then stops.
Context is fresh each time. The `run.sh` loop handles repetition.

---

HEADER

for skill in "${skills[@]}"; do
  echo ""
  cat "$skill"
  echo ""
  echo "---"
done
} > "$CLAUDE_MD"

echo "  CLAUDE.md written (full skill content for headless mode)"

# 4. run.sh — autonomous loop
cat > "$RUN_SH" <<'RUNSH'
#!/usr/bin/env bash
#
# run.sh — autonomous hackathon agent loop
#
# Say "Go" once. Agents claim tasks, open PRs, review PRs, implement
# feedback, and repeat until everything is done. Context is cleared
# automatically between each unit of work.
#
# Run this on each teammate's machine in parallel for multi-agent mode.
# Press Ctrl-C to stop early.

set -euo pipefail

IDLE=0
MAX_IDLE=3      # stop after this many consecutive NOTHING_TO_DO signals
IDLE_WAIT=60    # seconds between idle retries

echo "Hackathon agent loop started. Press Ctrl-C to stop."
echo ""

while true; do
  echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
  output=$(claude -p "Go" 2>&1)
  printf '%s\n' "$output"
  echo ""

  if printf '%s' "$output" | grep -qF 'NOTHING_TO_DO'; then
    IDLE=$((IDLE + 1))
    if [[ $IDLE -ge $MAX_IDLE ]]; then
      echo "Nothing to do for $MAX_IDLE consecutive checks. All done."
      break
    fi
    echo "Idle ($IDLE/$MAX_IDLE). Waiting ${IDLE_WAIT}s..."
    sleep "$IDLE_WAIT"
  else
    # "Waiting for peers" output resets idle — only NOTHING_TO_DO counts.
    IDLE=0
    sleep 3
  fi
done
RUNSH

chmod +x "$RUN_SH"
echo "  run.sh written and made executable"

echo ""
echo "Bootstrap complete → $TARGET_DIR"
echo ""
echo "For Claude Code (interactive):  open the project — /hackathon-* commands available"
echo "For autonomous mode:            ./run.sh  (each teammate runs this independently)"
echo "For other agent CLIs:           paste AGENTS.md as system prompt"
