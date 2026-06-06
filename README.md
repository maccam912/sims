# Sims-style life simulation (Godot 4.6)

A moddable foundation for a Sims-like game: build a house on a grid, furnish it
from a data-driven catalog, and watch autonomous Sims satisfy their needs.

![screenshot](docs/screenshot.png)

## Run it

Open the project in Godot 4.6+ and press Play, or:

```bash
godot --path .            # play
tools/test.sh             # headless unit tests
tools/shot.sh out.png     # render a screenshot (needs a display)
tools/visual_test.sh      # gated oMLX "does it look right?" check
```

## Controls

- **WASD / arrows / middle-drag** — pan camera
- **Right-drag** — orbit · **Mouse wheel** — zoom
- **Build Mode** button — toggle build/live
- In build: pick a tool (Floor / Wall / Furn. / Demo) and an item, click to place.
  **R** rotates furniture. Demolish removes furniture, floors and walls.
- **Pause / 1x / 2x / 3x** — game speed · **Save / Load** — persist the lot

## Architecture

The simulation is deliberately split into **pure, node-free logic** (unit-tested
headlessly) and a thin rendering/UI layer on top.

```
src/
  core/        pure logic — no nodes, fully unit-tested
    game_clock.gd   in-game time & speed
    needs.gd        Sim motives, decay, gains
    grid.gd         tile/edge/footprint math
    utility_ai.gd   advertisement-based decision making
  defs/        moddable content schema (parsed from JSON)
    furniture_def.gd  floor_def.gd  wall_def.gd  interaction_def.gd
  registry/
    catalog.gd      scans content packs (autoload singleton "Catalog")
  world/
    lot.gd          buildable state (floors/walls/furniture) — unit-tested
    sim_agent.gd    a Sim's brain (needs + AI) — unit-tested
    world_view.gd   renders a Lot
    sim.gd          a Sim's 3D body
    camera_rig.gd   RTS camera
  ui/hud.gd      top bar + catalog-driven build palette
  game.gd        orchestrator (modes, placement, save/load)

content/core/    built-in furniture/floors/walls (JSON)
mods/example_mod/ template mod
assets/          Kenney Furniture Kit + Blocky Characters (CC0)
tests/           headless test runner + screenshot harness
tools/           test / screenshot / oMLX visual-check scripts
docs/MODDING.md  how to add content
```

## Modding

Content is plain JSON in content packs — no coding needed. See
[docs/MODDING.md](docs/MODDING.md). Drop a folder in `user://mods/` (or
`res://mods/`) with a `pack.json` and some definition files.

## Testing philosophy

- **Unit tests first** (`tools/test.sh`): clock, needs, grid, utility AI, lot
  placement/save-load, and a full catalog→agent integration test. All logic
  that matters is exercised without a renderer.
- **Screenshot harness** (`tests/screenshot.tscn`): boots the real game, runs
  it, and saves a PNG.
- **oMLX visual check** (`tools/visual_test.sh`): sends a render to a local
  vision model for a fuzzy "does it look right?" verdict. Gated — skips if the
  server isn't running.

## Credits

3D assets by [Kenney](https://kenney.nl) (CC0): Furniture Kit, Blocky Characters.
