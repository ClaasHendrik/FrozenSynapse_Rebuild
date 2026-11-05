#!/usr/bin/env bash
# Run every test script headless. Usage: tests/run_all.sh [path-to-godot]
GODOT=${1:-${GODOT:-godot}}
cd "$(dirname "$0")/.."
rc=0
for t in tests/run_tests.gd tests/test_world.gd tests/test_ai.gd tests/test_ui_flow.gd; do
  echo "== $t"
  "$GODOT" --headless --path . -s "$t" 2>&1 | grep -v "^Godot Engine" || true
  [ "${PIPESTATUS[0]}" -eq 0 ] || rc=1
done
exit $rc
