#!/usr/bin/env bash
# Run the headless unit test suite. Exits non-zero if any test fails.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
import_log="$(mktemp)"
trap 'rm -f "$import_log"' EXIT

if ! "$GODOT" --headless --import --path . >"$import_log" 2>&1; then
	cat "$import_log"
	exit 1
fi

# Godot can exit successfully even when an asset import fails.
if grep -Eq '^ERROR:|SCRIPT ERROR:|Parse Error:|Failed to load script' "$import_log"; then
	cat "$import_log"
	exit 1
fi

"$GODOT" --headless --script res://tests/test_runner.gd --path . 2>&1 | grep -v "^Godot Engine"
