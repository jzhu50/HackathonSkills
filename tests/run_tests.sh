#!/usr/bin/env bash
# Run the full test suite.
# Usage: ./tests/run_tests.sh [--filter <pattern>]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="$REPO_ROOT/tests"

if ! command -v bats &>/dev/null; then
  echo "error: bats-core not found. Install with: brew install bats-core" >&2
  exit 1
fi

FILTER="${1:-}"
FILES=(
  "$TESTS_DIR/test_config.bats"
  "$TESTS_DIR/test_skill_contracts.bats"
  "$TESTS_DIR/test_bootstrap.bats"
  "$TESTS_DIR/test_runner.bats"
)

if [[ -n "$FILTER" ]]; then
  bats --filter "$FILTER" "${FILES[@]}"
else
  bats "${FILES[@]}"
fi
