#!/usr/bin/env bash
#
# make-claude-md.sh - bootstrap a hackathon project for Claude Code
#
# Generates in the target project:
#   CLAUDE.md              - full skill content loaded by interactive Claude Code
#   .claude/commands/      - slash commands for interactive Claude Code
#   .claude/settings.json  - GitHub MCP pre-approved (no permission prompts)
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
  echo "Error: skills/ not found - run from inside a clone of the template repo" >&2; exit 1
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
  echo "  WARNING: .claude/settings.json exists - not overwriting. Ensure mcp__github__*, Bash(git:*), Read, Edit, Write are in permissions.allow."
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

# 3. CLAUDE.md - coordination header + full skill content
{
cat <<'HEADER'
# Hackathon Agent Coordination

> Auto-generated. Re-run the bootstrap script to update.

## Human-in-the-loop workflow

This project has a human review gate between every major AI step.
No AI agent merges anything without explicit human instruction.

Workflow:
  hackathon-setup       -> wizard: configure oversight, scaffold PLAN.md
  hackathon-plan        -> Phase 1: PLAN.md -> GitHub Projects + generate SPECS.md
  Human approves projects (ai-approved)
  hackathon-epics       -> Phase 2: Projects -> Epic issues on GitHub
  Human approves epics (ai-approved)
  hackathon-decompose   -> Phase 3: Epics -> Task issues + epic branches
  Human approves tasks (ai-approved)
  hackathon-session     -> Phase 4: Tasks -> code + PRs (in-review)
  Human triggers hackathon-review -> AI posts findings -> human decides
  hackathon-verify      -> last task per epic; opens epic->main PR
  hackathon-projects    -> track completion; close GitHub Project when all epics merge

## GitHub MCP - use for all GitHub operations

Use `mcp__github__*` for every GitHub operation: issues, labels, assignees,
comments, pull requests. Never use `gh`, `curl`, or Bash for GitHub operations.
Make all MCP calls **sequentially, not in parallel.**

## Branch discipline

Epic branches: epic/<n>-<slug> (created by hackathon-decompose from main)
Task branches: task/<n>-<slug> (created by hackathon-session from the epic branch)
Task PRs target the epic branch. The verify task opens the epic->main PR.
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

# 4. Generate AIDER.md, CODEX.md, ANTIGRAVITY.md, GEMINI.md for other harnesses
AGENTS_PATH="$SCRIPT_DIR/AGENTS.md"
if [ ! -f "$AGENTS_PATH" ]; then
  AGENTS_PATH="$TARGET_DIR/AGENTS.md"
fi

for name in AIDER.md CODEX.md ANTIGRAVITY.md GEMINI.md; do
  harness_path="$TARGET_DIR/$name"
  {
    cat <<'HARNESS_HEADER'
# Agent Coordination Context

> Auto-generated. Re-run the bootstrap script to update.

You are a software agent working on a hackathon project with human review at every
major step. GitHub is the coordination layer - all state lives in GitHub Issues
and GitHub Projects. You have no memory between sessions.

Four-phase workflow:
- hackathon-setup:      run once; configure oversight, scaffold PLAN.md
- hackathon-plan:       Phase 1 - PLAN.md -> GitHub Projects + generate SPECS.md
- hackathon-epics:      Phase 2 - Projects -> Epic issues on GitHub
- hackathon-decompose:  Phase 3 - Epics -> Task issues + epic branches
- hackathon-session:    Phase 4 - Tasks -> code + PRs (loops until queue empty)
- hackathon-add:        add features/hardening/refactoring to a running project
- hackathon-projects:   check completion; close GitHub Project when all epics merge
- hackathon-review:     human-triggered; review one PR, post findings, human decides merge/changes
- hackathon-debug/test/verify: called automatically by hackathon-session

Branch discipline:
  Epic branches: epic/<n>-<slug> (created by hackathon-decompose from main)
  Task branches: task/<n>-<slug> (created by hackathon-session from the epic branch)
  Task PRs target the epic branch. The verify task opens the epic->main PR.
  Never commit to main or an epic branch directly.

Labels:
  needs-human-review -> ai-approved -> in-progress -> in-review -> (merged)

Read AGENTS.md in full before acting.

---

HARNESS_HEADER
    if [ -f "$AGENTS_PATH" ]; then
      cat "$AGENTS_PATH"
      echo ""
      echo "---"
    fi
    for skill in "${skills[@]}"; do
      echo ""
      cat "$skill"
      echo ""
      echo "---"
    done
  } > "$harness_path"
  echo "  harness: $name written"
done


# Scaffold GitHub Actions workflows based on hackathon.config.yml
WORKFLOW_TEMPLATES_DIR="$SCRIPT_DIR/workflow-templates"
if [ ! -d "$WORKFLOW_TEMPLATES_DIR" ]; then
  WORKFLOW_TEMPLATES_DIR="$(pwd)/workflow-templates"
fi

if [ -d "$WORKFLOW_TEMPLATES_DIR" ] && [ -f "$TARGET_DIR/hackathon.config.yml" ]; then
  WORKFLOWS_OUT="$TARGET_DIR/.github/workflows"
  mkdir -p "$WORKFLOWS_OUT"

  scaffolded=()
  for pair in "gitleaks:gitleaks.yml" "codeql:codeql.yml" "dependency_review:dependency-review.yml" "actionlint:actionlint.yml" "markdownlint:markdownlint.yml" "contract:hackathon-contract.yml" "unblock_sweep:unblock-sweep.yml"; do
    key="${pair%%:*}"
    file="${pair##*:}"

    if grep -q "^actions:" "$TARGET_DIR/hackathon.config.yml"; then
      val=$(grep "  ${key}:" "$TARGET_DIR/hackathon.config.yml" | grep -c "true" || echo 0)
    else
      val=1
    fi

    if [ "$val" -gt 0 ]; then
      src="$WORKFLOW_TEMPLATES_DIR/$file"
      dst="$WORKFLOWS_OUT/$file"
      if [ -f "$dst" ]; then
        echo "  WARNING: $dst already exists - not overwriting"
      elif [ -f "$src" ]; then
        cp "$src" "$dst"
        scaffolded+=("$dst")
        echo "  workflow: .github/workflows/$file"
      fi
    fi
  done

  # Also copy .env.example and .markdownlint.yml if not present
  for f in .env.example .markdownlint.yml; do
    src="$SCRIPT_DIR/$f"
    dst="$TARGET_DIR/$f"
    if [ ! -f "$dst" ] && [ -f "$src" ]; then
      cp "$src" "$dst"
      scaffolded+=("$dst")
      echo "  config: $f"
    fi
  done

  # Commit scaffolded files
  if [ ${#scaffolded[@]} -gt 0 ]; then
    cd "$TARGET_DIR"
    if git rev-parse --git-dir > /dev/null 2>&1; then
      git add .github/workflows/ .env.example .markdownlint.yml 2>/dev/null || true
      if ! git diff --cached --quiet; then
        git commit -m "ci: scaffold repository contract workflows" || \
          echo "  WARNING: git commit failed (check git user.email config) - workflows are on disk but not committed"
      fi
    fi
    cd - > /dev/null
  fi
fi

echo ""
echo "Bootstrap complete -> $TARGET_DIR"
echo ""
echo "Interactive Claude Code: open the project - /hackathon-* commands available"
echo "Other agent CLIs:        see HARNESS.md"
exit 0
