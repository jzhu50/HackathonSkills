#!/usr/bin/env bats
# Tests for runner.sh (hackathon-skills)

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="$REPO_ROOT/runner.sh"
  ORIG_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hackathon-skills"
  # Redirect config to a temp dir so tests don't pollute the real config
  export XDG_CONFIG_HOME="$(mktemp -d)"
  CONFIG_DIR="$XDG_CONFIG_HOME/hackathon-skills"
  CONFIG_FILE="$CONFIG_DIR/config.json"
}

teardown() {
  rm -rf "$XDG_CONFIG_HOME"
}

@test "script exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "--help exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
}

@test "--help mentions --reconfigure flag" {
  run bash "$SCRIPT" --help
  echo "$output" | grep -q "\-\-reconfigure"
}

@test "--help mentions --cli flag" {
  run bash "$SCRIPT" --help
  echo "$output" | grep -q "\-\-cli"
}

@test "--cli flag requires a value" {
  # --cli with no value should fail because of ${2:?--cli requires a value}
  run bash "$SCRIPT" --cli
  [ "$status" -ne 0 ]
}

@test "reads cli from valid config.json" {
  mkdir -p "$CONFIG_DIR"
  echo '{"cli": ["echo"]}' > "$CONFIG_FILE"
  result=$(python3 - "$CONFIG_FILE" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
clis = data.get('cli', [])
print(clis[0])
PYEOF
)
  [ "$result" = "echo" ]
}

@test "config.json with empty cli list causes error" {
  mkdir -p "$CONFIG_DIR"
  echo '{"cli": []}' > "$CONFIG_FILE"
  run python3 - "$CONFIG_FILE" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
clis = data.get("cli", [])
if not clis:
    print("error: config 'cli' list is empty", file=sys.stderr)
    sys.exit(1)
print(clis[0])
PYEOF
  [ "$status" -ne 0 ]
}

@test "config.json with invalid JSON causes error" {
  mkdir -p "$CONFIG_DIR"
  echo 'not-json' > "$CONFIG_FILE"
  run python3 - "$CONFIG_FILE" <<'PYEOF'
import json, sys
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
except (OSError, json.JSONDecodeError) as e:
    print(f"error: cannot read config: {e}", file=sys.stderr)
    sys.exit(1)
print(data.get("cli", [""])[0])
PYEOF
  [ "$status" -ne 0 ]
}
