#!/usr/bin/env bash
# Render a screenshot of the game. Needs a GPU/display (not headless).
# Usage: tools/shot.sh [out.png] [seconds] [speed] [--build]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="${1:-/tmp/sims_shot.png}"
SECONDS_="${2:-4}"
SPEED="${3:-14}"
BUILD="${4:-}"
"$GODOT" --path . res://tests/screenshot.tscn -- \
	--out="$OUT" --seconds="$SECONDS_" --speed="$SPEED" $BUILD
echo "wrote $OUT"
