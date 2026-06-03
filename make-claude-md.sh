#!/usr/bin/env bash
# make-claude-md.sh
# Concatenates all skill files from skills/ into .claude/CLAUDE.md in the target project.
# Usage (from inside target project):  /path/to/make-claude-md.sh
# Usage (from skills repo root):       ./make-claude-md.sh  or  ./make-claude-md.sh /path/to/project

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-$(pwd)}"
SKILLS_DIR="$SCRIPT_DIR/skills"
OUTPUT_DIR="$TARGET_DIR/.claude"
OUTPUT_FILE="$OUTPUT_DIR/CLAUDE.md"

if [ ! -d "$SKILLS_DIR" ]; then
  echo "Error: skills/ directory not found at: $SKILLS_DIR" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

skills=("$SKILLS_DIR"/*.md)
if [ ${#skills[@]} -eq 0 ] || [ ! -f "${skills[0]}" ]; then
  echo "Error: no .md files found in $SKILLS_DIR" >&2
  exit 1
fi

> "$OUTPUT_FILE"
for skill in "${skills[@]}"; do
  cat "$skill" >> "$OUTPUT_FILE"
  printf '\n' >> "$OUTPUT_FILE"
done

echo "Generated $OUTPUT_FILE from ${#skills[@]} skill(s):"
for skill in "${skills[@]}"; do
  echo "  - $(basename "$skill")"
done
