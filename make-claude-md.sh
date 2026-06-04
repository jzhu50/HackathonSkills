#!/usr/bin/env bash
#
# make-claude-md.sh — bootstrap a hackathon project for Claude Code
#
# Generates in the target project:
#   CLAUDE.md              — full skill content loaded by interactive Claude Code
#   .claude/commands/      — slash commands for interactive Claude Code
#   .claude/settings.json  — GitHub MCP pre-approved (no permission prompts)
#
# Usage:
#   ./make-claude-md.sh                  # targets current directory
#   ./make-claude-md.sh /path/to/project # targets a specific directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-$(pwd)}"
# When installed globally (e.g. ~/.local/bin/hackathon-bootstrap), the script lives
# outside the project. Fall back to the calling directory so bootstrap works from
# inside any clone of the template repo.
SKILLS_DIR="$SCRIPT_DIR/skills"
if [ ! -d "$SKILLS_DIR" ]; then
  SKILLS_DIR="$(pwd)/skills"
fi
COMMANDS_DIR="$TARGET_DIR/.claude/commands"
SETTINGS_PATH="$TARGET_DIR/.claude/settings.json"
CLAUDE_MD="$TARGET_DIR/CLAUDE.md"

if [ ! -d "$SKILLS_DIR" ]; then
  echo "Error: skills/ not found — run from inside a clone of the template repo" >&2; exit 1
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
  echo "  WARNING: .claude/settings.json exists — not overwriting. Ensure mcp__github__*, Bash(git:*), Read, Edit, Write are in permissions.allow."
else
  cat > "$SETTINGS_PATH" <<'SETTINGS'
{
  "permissions": {
    "allow": [
      "mcp__github__*",
      "Bash(git:*)",
      "Read",
      "Edit",
      "Write"
    ]
  }
}
SETTINGS
  echo "  settings: .claude/settings.json written"
fi

# 3. CLAUDE.md — coordination header + full skill content
{
cat <<'HEADER'
# Hackathon Agent Coordination

> Auto-generated. Re-run the bootstrap script to update.

## Human-in-the-loop workflow

This project has a human review gate between every major AI step.
No AI agent merges anything without explicit human instruction.

Workflow:
  hackathon-setup       → wizard: configure oversight, scaffold PLAN.md
  hackathon-plan        → Phase 1: PLAN.md → GitHub Projects + generate SPECS.md
  Human approves projects (ai-approved)
  hackathon-epics       → Phase 2: Projects → Epic issues on GitHub
  Human approves epics (ai-approved)
  hackathon-decompose   → Phase 3: Epics → Task issues + epic branches
  Human approves tasks (ai-approved)
  hackathon-session     → Phase 4: Tasks → code + PRs (in-review)
  Human triggers hackathon-review → AI posts findings → human decides
  hackathon-verify      → last task per epic; opens epic→main PR
  hackathon-projects    → track completion; close GitHub Project when all epics merge

## GitHub MCP — use for all GitHub operations

Use `mcp__github__*` for every GitHub operation: issues, labels, assignees,
comments, pull requests. Never use `gh`, `curl`, or Bash for GitHub operations.
Make all MCP calls **sequentially, not in parallel.**

## Branch discipline

Epic branches: epic-<n>-<slug> (created by hackathon-decompose from main)
Task branches: <n>-<slug> (created by hackathon-session from the epic branch)
Task PRs target the epic branch. The verify task opens the epic→main PR.
Never commit to `main` or an epic branch directly.

---

HEADER

for skill in "${skills[@]}"; do
  echo ""
  cat "$skill"
  echo ""
  echo "---"
done
} > "$CLAUDE_MD"

echo "  CLAUDE.md written"

echo ""
echo "Bootstrap complete → $TARGET_DIR"
echo ""
echo "Interactive Claude Code: open the project — /hackathon-* commands available"
echo "Other agent CLIs:        see HARNESS.md"
