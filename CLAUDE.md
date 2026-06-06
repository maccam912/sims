# CLAUDE.md — working notes for this repo

Godot **4.6** project (Forward+, Jolt physics). A moddable Sims-like life sim.
Binary: `/Users/maccam912/.local/bin/godot` (or `godot` on PATH).

## Golden rules

1. **Keep logic node-free and tested.** Anything that can be a `RefCounted` in
   `src/core/` or a plain data class (`Lot`, `SimAgent`) should be, so it runs
   in the headless test runner. Rendering/UI is a thin layer on top.
2. **Content is data, not code.** New furniture/floors/walls go in JSON content
   packs (`content/`, `mods/`, `user://mods/`), never hard-coded. See
   `docs/MODDING.md`. The Catalog autoload loads them.
3. **Verify with the ladder:** unit tests → screenshot → (if visuals matter)
   oMLX visual check. Show passing output.

## Commands

```bash
godot --headless --import --path .                      # import (after adding scripts/assets)
godot --headless --script res://tests/test_runner.gd --path .   # unit tests
tools/test.sh                                           # ^ wrapper
tools/shot.sh /tmp/x.png 4 14 [--build]                 # screenshot (needs display)
tools/visual_test.sh                                    # gated oMLX check
```

After adding a script with a new `class_name`, run `--import` once so the global
class registers before tests/scenes reference it.

## Controls / input

All input goes through the **InputMap** (`[input]` in `project.godot`) so players can
rebind it — never read raw keycodes/buttons in game code. Use
`Input.is_action_pressed` / `event.is_action_pressed`. Actions:
`cam_pan_forward/back/left/right`, `cam_zoom_in/out`, `cam_orbit`, `cam_pan_drag`,
`build_place`, `build_rotate`, `toggle_build`, `build_cancel`,
`speed_pause/normal/fast/faster`. Defaults: WASD/arrows pan, E/Q (or `=`/`-`) zoom —
trackpad-friendly, no wheel needed (wheel/two-finger scroll still works as a bonus),
right-drag orbit, B/Tab toggle build, R rotate, Esc exit build. The HUD also has
on-screen **Zoom -/+** buttons (call `CameraRig.zoom_by`) and a persistent control
hint. When adding a new control, add an action first, then read it — don't hard-code keys.

## Gotchas learned

- GDScript `:=` can't infer from an untyped return (e.g. JSON helpers, autoload
  methods). Use an explicit type (`var x: FurnitureDef = ...`) or plain `=`.
- The headless `--script` runner needs class_names registered → import first.
- Kenney **Blocky Characters are ~9 units tall**; furniture is ~1 unit. `Sim`
  auto-normalises any character model to `TARGET_HEIGHT` (1.7m) at runtime.
- `--headless` can't render — the screenshot harness must run windowed (GPU).
- oMLX (`http://localhost:8000/v1`, key `0000`) Gemma models return their answer
  in `message.reasoning_content` when `content` is empty; `visual_check.py`
  handles both and auto-picks an available Gemma vision model.

## oMLX

Local vision model for fuzzy visual QA. Available models change; the tool lists
`/v1/models` and picks a Gemma `it` model (currently `gemma-4-31b-it-4bit`;
`gemma-4-12b` was removed). Always gate visual tests so missing oMLX never fails CI.

## Status / next ideas

Working: grid build mode (floors/walls/furniture/demolish), data-driven catalog
+ mods, utility-AI Sims with needs/decay/interactions, save/load, camera, HUD,
tests, screenshot + oMLX harness. Natural next steps: navmesh pathfinding (Sims
currently walk straight lines), need-decay tuning & a needs panel, multi-floor
houses (stairs exist as assets), social interactions between Sims, money/economy,
day/night lighting driven by the clock, runtime `user://` glb loading for mods.
```
