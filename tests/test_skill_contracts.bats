#!/usr/bin/env bats
# Skill contract tests.
# Verifies that skill files enforce the label state machine defined in AGENTS.md,
# contain required structural sections, and cross-reference each other correctly.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SKILLS="$REPO_ROOT/skills"
MODULES="$REPO_ROOT/skills/modules"

# ---------------------------------------------------------------------------
# Structural: every skill must have MANDATES or be a module
# ---------------------------------------------------------------------------

@test "all top-level skills contain MANDATES section" {
  for f in "$SKILLS"/*.md; do
    grep -q "MANDATES" "$f" \
      || { echo "MISSING MANDATES: $f"; false; }
  done
}

@test "all top-level skills contain Caveman mandate" {
  for f in "$SKILLS"/*.md; do
    grep -q "Caveman" "$f" \
      || { echo "MISSING Caveman: $f"; false; }
  done
}

# ---------------------------------------------------------------------------
# Label state machine: verify transitions match AGENTS.md rules
# ---------------------------------------------------------------------------

@test "hackathon-session uses in-progress label for task claims" {
  grep -q "in-progress" "$SKILLS/hackathon-session.md"
}

@test "hackathon-session does not set review-ready before PR step" {
  # review-ready must only appear in PR step (step 8) and Phase 3
  # Verify it's not set before the PR block
  python3 - "$SKILLS/hackathon-session.md" <<'PYEOF'
import sys
lines = open(sys.argv[1]).readlines()
pr_step = next((i for i, l in enumerate(lines) if "**PR**" in l), None)
assert pr_step is not None, "PR step not found"
before_pr = "".join(lines[:pr_step])
# review-ready should not be *set* before the PR step
# (it may appear as a label name in descriptions, skip those)
import re
for m in re.finditer(r'Label.*review-ready', before_pr):
    print(f"review-ready set before PR step: {m.group()}")
    sys.exit(1)
sys.exit(0)
PYEOF
}

@test "hackathon-verify FAIL path removes in-progress before setting blocked" {
  grep -q "remove \`in-progress\`" "$SKILLS/hackathon-verify.md"
}

@test "hackathon-verify FAIL path sets ai-approved + blocked (not just blocked)" {
  grep -q "ai-approved.*blocked" "$SKILLS/hackathon-verify.md"
}

@test "hackathon-debug Mode B cannot-reproduce uses needs-human-review" {
  grep -q "needs-human-review" "$SKILLS/hackathon-debug.md"
}

@test "hackathon-debug Mode B cannot-reproduce does not use blocked for unreproduce" {
  # The word 'blocked' should not appear on the same line as 'Passes 3x'
  ! grep "Passes 3x" "$SKILLS/hackathon-debug.md" | grep -q "blocked"
}

@test "hackathon-review transitions review-ready to in-review on claim" {
  grep -q "in-review" "$SKILLS/hackathon-review.md"
}

@test "hackathon-review autonomous APPROVE uses squash for epic branch base" {
  grep -q "squash" "$SKILLS/hackathon-review.md"
}

@test "hackathon-review autonomous APPROVE uses regular merge for main base" {
  grep -q "regular merge commit" "$SKILLS/hackathon-review.md"
}

# ---------------------------------------------------------------------------
# Cross-references: skills that delegate must reference the correct module
# ---------------------------------------------------------------------------

@test "hackathon-session references skill-claim module" {
  grep -q "skill-claim" "$SKILLS/hackathon-session.md"
}

@test "hackathon-session references skill-sync module" {
  grep -q "skill-sync" "$SKILLS/hackathon-session.md"
}

@test "hackathon-session references skill-validate module" {
  grep -q "skill-validate" "$SKILLS/hackathon-session.md"
}

@test "hackathon-decompose references skill-claim module" {
  grep -q "skill-claim" "$SKILLS/hackathon-decompose.md"
}

@test "hackathon-verify references skill-sync module" {
  grep -q "skill-sync" "$SKILLS/hackathon-verify.md"
}

@test "hackathon-verify references hackathon-security-audit" {
  grep -q "hackathon-security-audit" "$SKILLS/hackathon-verify.md"
}

# ---------------------------------------------------------------------------
# Config gate references: every gated skill must check its config key
# ---------------------------------------------------------------------------

@test "hackathon-plan checks project_breakdown gate" {
  grep -q "project_breakdown" "$SKILLS/hackathon-plan.md"
}

@test "hackathon-epics checks epic_breakdown gate" {
  grep -q "epic_breakdown" "$SKILLS/hackathon-epics.md"
}

@test "hackathon-decompose checks task_breakdown gate" {
  grep -q "task_breakdown" "$SKILLS/hackathon-decompose.md"
}

@test "hackathon-session checks task_completion gate" {
  grep -q "task_completion" "$SKILLS/hackathon-session.md"
}

@test "hackathon-session checks code_review gate" {
  grep -q "code_review" "$SKILLS/hackathon-session.md"
}

@test "hackathon-verify checks epic_review gate" {
  grep -q "epic_review" "$SKILLS/hackathon-verify.md"
}

# ---------------------------------------------------------------------------
# SESSION_AUTO: verify auto-approve feature is consistently wired
# ---------------------------------------------------------------------------

@test "hackathon-session defines SESSION_AUTO variable" {
  grep -q "SESSION_AUTO" "$SKILLS/hackathon-session.md"
}

@test "hackathon-session task completion gate checks SESSION_AUTO" {
  grep "Task Completion Gate" "$SKILLS/hackathon-session.md" | grep -q "SESSION_AUTO"
}

@test "hackathon-session review sweep handles SESSION_AUTO true path" {
  grep -q "SESSION_AUTO: true" "$SKILLS/hackathon-session.md"
}

@test "hackathon-session review sweep handles SESSION_AUTO false path" {
  grep -q "SESSION_AUTO: false" "$SKILLS/hackathon-session.md"
}

@test "hackathon-session escalates merge conflicts to human in auto mode" {
  grep -q "conflicted" "$SKILLS/hackathon-session.md"
  grep "conflicted" "$SKILLS/hackathon-session.md" | grep -q "human"
}

# ---------------------------------------------------------------------------
# Branch naming conventions
# ---------------------------------------------------------------------------

@test "hackathon-decompose creates epic/ branches" {
  grep -q "epic/\[" "$SKILLS/hackathon-decompose.md"
}

@test "hackathon-session creates task/ branches" {
  grep -q "task/\[" "$SKILLS/hackathon-session.md"
}

@test "hackathon-verify PR targets main not epic branch" {
  grep "Open PR" "$SKILLS/hackathon-verify.md" | grep -q "Main"
}

# ---------------------------------------------------------------------------
# PR body requirements: Closes # lines
# ---------------------------------------------------------------------------

@test "hackathon-session PR body includes Closes #" {
  grep -q "Closes #" "$SKILLS/hackathon-session.md"
}

@test "hackathon-verify PR body includes Closes # for both epic and verify task" {
  # Both occurrences may be on the same line; count with grep -o
  count=$(grep -o "Closes #" "$SKILLS/hackathon-verify.md" | wc -l | tr -d ' ')
  [ "$count" -ge 2 ]
}

# ---------------------------------------------------------------------------
# Merge rules: no squash on epic->main
# ---------------------------------------------------------------------------

@test "hackathon-verify uses MERGE COMMIT not squash" {
  grep -q "MERGE COMMIT" "$SKILLS/hackathon-verify.md"
}

@test "hackathon-verify explicitly says DO NOT SQUASH or No squash" {
  grep -qi "no squash\|not.*squash\|DO NOT SQUASH" "$SKILLS/hackathon-verify.md"
}

# ---------------------------------------------------------------------------
# skill-validate: baseline rules
# ---------------------------------------------------------------------------

@test "skill-validate requires FAIL baseline before implementing" {
  grep -q "FAIL" "$MODULES/skill-validate.md"
}

@test "skill-validate has script error handling guidance" {
  grep -q "syntax\|missing deps\|Fix script" "$MODULES/skill-validate.md"
}

@test "skill-validate cleans up success_check.sh before PR" {
  grep -q "rm success_check" "$MODULES/skill-validate.md"
}

# ---------------------------------------------------------------------------
# hackathon-setup parallelism config comment correctness
# ---------------------------------------------------------------------------

@test "hackathon-setup parallelism comment maps Q3-B to wave-based (true)" {
  grep "parallelism:" "$SKILLS/hackathon-setup.md" | grep "true" | grep -q "Q3-B"
}

@test "hackathon-setup parallelism comment maps Q3-A to sequential (false)" {
  grep "parallelism:" "$SKILLS/hackathon-setup.md" | grep "false" | grep -q "Q3-A"
}
