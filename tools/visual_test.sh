#!/usr/bin/env bash
# Gated fuzzy visual test: render the game and ask a local oMLX vision model
# whether it looks right. Skips cleanly (exit 0) if oMLX isn't running, so it
# never blocks CI. Set SIMS_VISUAL=1 to require it.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
SHOT="/tmp/sims_visual.png"

if ! curl -s -m 3 http://localhost:8000/v1/models -H "Authorization: Bearer 0000" >/dev/null 2>&1; then
	echo "[visual_test] oMLX not reachable on :8000 — skipping."
	[ "${SIMS_VISUAL:-0}" = "1" ] && exit 1 || exit 0
fi

"$GODOT" --path . res://tests/screenshot.tscn -- --out="$SHOT" --seconds=5 --speed=16 >/dev/null 2>&1

python3 tools/visual_check.py --image "$SHOT" --prompt \
"This is a screenshot from a Sims-like life-simulation game (3/4 overhead view of a house with the roof removed). Answer strictly: does it show a coherent furnished house with walls, floors, furniture and at least one small human character, with no major rendering glitches? Reply with PASS or FAIL on the first line, then a one-sentence reason."
