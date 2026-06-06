#!/usr/bin/env bats
# Tests for hackathon.config.yml schema validity.
# Verifies all required keys exist and have valid values.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
CONFIG="$REPO_ROOT/hackathon.config.yml"

# ---------------------------------------------------------------------------
# Helper: extract a scalar value from the YAML using python3+PyYAML or grep
# ---------------------------------------------------------------------------

_yaml_get() {
  python3 - "$CONFIG" "$1" <<'PYEOF'
import sys
# minimal YAML scalar extraction without external deps
path = sys.argv[2].split(".")
lines = open(sys.argv[1]).readlines()
# Walk the path by tracking indent level
result = None
for i, line in enumerate(lines):
    stripped = line.rstrip()
    if not stripped or stripped.startswith("#"):
        continue
    key = stripped.lstrip().rstrip(":").split(":")[0].strip()
    if key == path[-1]:
        # grab value after colon on same line
        parts = stripped.split(":", 1)
        if len(parts) == 2 and parts[1].strip():
            result = parts[1].strip()
if result is None:
    sys.exit(1)
print(result)
PYEOF
}

# ---------------------------------------------------------------------------

@test "config file exists" {
  [ -f "$CONFIG" ]
}

@test "config contains gates section" {
  grep -q "^gates:" "$CONFIG"
}

@test "config contains quality section" {
  grep -q "^quality:" "$CONFIG"
}

@test "config contains parallelism key" {
  grep -q "^parallelism:" "$CONFIG"
}

@test "config contains actions section" {
  grep -q "^actions:" "$CONFIG"
}

@test "all six gate keys are present" {
  for key in project_breakdown epic_breakdown task_breakdown task_completion code_review epic_review; do
    grep -q "${key}:" "$CONFIG" \
      || { echo "MISSING gate key: $key"; false; }
  done
}

@test "human_required values are true or false" {
  python3 - "$CONFIG" <<'PYEOF'
import sys, re
text = open(sys.argv[1]).read()
for m in re.finditer(r'human_required:\s*(\S+)', text):
    val = m.group(1).lower().rstrip()
    assert val in ("true", "false"), f"invalid human_required value: {val}"
sys.exit(0)
PYEOF
}

@test "grilling values are true or false" {
  python3 - "$CONFIG" <<'PYEOF'
import sys, re
text = open(sys.argv[1]).read()
for m in re.finditer(r'grilling:\s*(\S+)', text):
    val = m.group(1).lower().rstrip()
    assert val in ("true", "false"), f"invalid grilling value: {val}"
sys.exit(0)
PYEOF
}

@test "quality.testing is required, recommended, or skip" {
  python3 - "$CONFIG" <<'PYEOF'
import sys, re
text = open(sys.argv[1]).read()
m = re.search(r'testing:\s*(\S+)', text)
assert m, "testing key not found"
# strip trailing punctuation/comments that may be on same token
val = re.sub(r'[^a-z]', '', m.group(1).lower())
assert val in ("required", "recommended", "skip"), f"invalid testing value: {val!r}"
sys.exit(0)
PYEOF
}

@test "quality.validation is autonomous-script" {
  grep -q "validation: autonomous-script" "$CONFIG"
}

@test "parallelism is true or false" {
  python3 - "$CONFIG" <<'PYEOF'
import sys, re
text = open(sys.argv[1]).read()
m = re.search(r'^parallelism:\s*(\S+)', text, re.MULTILINE)
assert m, "parallelism key not found"
val = m.group(1).lower().rstrip()
assert val in ("true", "false"), f"invalid parallelism value: {val}"
sys.exit(0)
PYEOF
}

@test "all actions keys are present" {
  for key in gitleaks codeql dependency_review actionlint markdownlint contract; do
    grep -q "${key}:" "$CONFIG" \
      || { echo "MISSING action key: $key"; false; }
  done
}

@test "actions values are true or false" {
  python3 - "$CONFIG" <<'PYEOF'
import sys, re
text = open(sys.argv[1]).read()
# only check lines after 'actions:' section
actions_start = text.find("actions:")
assert actions_start != -1, "actions section not found"
actions_text = text[actions_start:]
for m in re.finditer(r'^\s+\w[\w_]+:\s*(\S+)', actions_text, re.MULTILINE):
    val = m.group(1).lower().rstrip()
    assert val in ("true", "false"), f"invalid actions value: {val!r}"
sys.exit(0)
PYEOF
}
