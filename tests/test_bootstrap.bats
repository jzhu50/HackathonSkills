#!/usr/bin/env bats
# Tests for make-claude-md.sh (hackathon-bootstrap)

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="$REPO_ROOT/make-claude-md.sh"
  TARGET="$(mktemp -d)"
  mkdir -p "$TARGET/skills"
  # Minimal skill file so the script has something to process
  echo "# Skill: test" > "$TARGET/skills/hackathon-test.md"
}

teardown() {
  rm -rf "$TARGET"
}

@test "script exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "generates CLAUDE.md in target dir" {
  SKILLS_DIR="$TARGET/skills" bash "$SCRIPT" "$TARGET"
  [ -f "$TARGET/CLAUDE.md" ]
}

@test "CLAUDE.md contains coordination header" {
  SKILLS_DIR="$TARGET/skills" bash "$SCRIPT" "$TARGET"
  grep -q "Hackathon Agent Coordination" "$TARGET/CLAUDE.md"
}

@test "CLAUDE.md contains skill content" {
  SKILLS_DIR="$TARGET/skills" bash "$SCRIPT" "$TARGET"
  # bootstrap reads from SCRIPT_DIR/skills (the real repo); check real skill names
  grep -q "hackathon-session\|hackathon-plan\|hackathon-epics" "$TARGET/CLAUDE.md"
}

@test "creates .claude/commands/ directory" {
  SKILLS_DIR="$TARGET/skills" bash "$SCRIPT" "$TARGET"
  [ -d "$TARGET/.claude/commands" ]
}

@test "copies skill files into .claude/commands/" {
  SKILLS_DIR="$TARGET/skills" bash "$SCRIPT" "$TARGET"
  [ -f "$TARGET/.claude/commands/hackathon-test.md" ]
}

@test "generates .claude/settings.json" {
  SKILLS_DIR="$TARGET/skills" bash "$SCRIPT" "$TARGET"
  [ -f "$TARGET/.claude/settings.json" ]
}

@test "settings.json contains mcp__github__ permission" {
  SKILLS_DIR="$TARGET/skills" bash "$SCRIPT" "$TARGET"
  grep -q "mcp__github__\*" "$TARGET/.claude/settings.json"
}

@test "settings.json is valid JSON" {
  SKILLS_DIR="$TARGET/skills" bash "$SCRIPT" "$TARGET"
  python3 -m json.tool "$TARGET/.claude/settings.json" > /dev/null
}

@test "generates GEMINI.md harness file" {
  SKILLS_DIR="$TARGET/skills" bash "$SCRIPT" "$TARGET"
  [ -f "$TARGET/GEMINI.md" ]
}

@test "generates AIDER.md harness file" {
  SKILLS_DIR="$TARGET/skills" bash "$SCRIPT" "$TARGET"
  [ -f "$TARGET/AIDER.md" ]
}

@test "harness files contain branch discipline section" {
  SKILLS_DIR="$TARGET/skills" bash "$SCRIPT" "$TARGET"
  grep -q "Branch discipline" "$TARGET/GEMINI.md"
}

@test "does not overwrite existing settings.json" {
  mkdir -p "$TARGET/.claude"
  echo '{"custom": true}' > "$TARGET/.claude/settings.json"
  SKILLS_DIR="$TARGET/skills" bash "$SCRIPT" "$TARGET"
  grep -q '"custom": true' "$TARGET/.claude/settings.json"
}

@test "fails with useful error when skills/ dir missing" {
  FAKEDIR="$(mktemp -d)"
  EMPTY="$(mktemp -d)"
  cp "$SCRIPT" "$FAKEDIR/bootstrap.sh"
  chmod +x "$FAKEDIR/bootstrap.sh"
  # Run from inside FAKEDIR so both SCRIPT_DIR and pwd have no skills/
  run bash -c "cd '$FAKEDIR' && bash bootstrap.sh '$EMPTY'"
  [ "$status" -ne 0 ]
  rm -rf "$FAKEDIR" "$EMPTY"
}
