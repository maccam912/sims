#!/usr/bin/env bash
# Run the headless unit test suite. Exits non-zero if any test fails.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --import --path . >/dev/null 2>&1 || true
"$GODOT" --headless --script res://tests/test_runner.gd --path . 2>&1 | grep -v "^Godot Engine"
