# Modding Guide

This game is **data-driven**: furniture, floors and walls are defined in plain
JSON files, not hard-coded. Adding content is just dropping files in a folder —
no Godot or coding required for basic items.

## Content packs

A *content pack* is a directory containing a `pack.json` manifest plus any
number of `*.json` definition files. Packs are discovered, in priority order,
from three roots (later packs can override earlier ones by reusing an `id`):

| Root | Purpose |
|------|---------|
| `res://content/` | Built-in game content (the `core` pack lives here). |
| `res://mods/`    | Mods shipped with / installed into the project. |
| `user://mods/`   | Mods the player drops in at runtime. On macOS this is `~/Library/Application Support/Godot/app_userdata/sims/mods/`. |

### `pack.json`

```json
{
  "id": "my_cool_mod",
  "name": "My Cool Mod",
  "author": "you",
  "version": "1.0.0",
  "description": "Adds a giant beanbag."
}
```

The fastest way to start: copy `mods/example_mod/`, rename the folder, change the
`id`, and edit the JSON.

## Definition files

Each `*.json` file (other than `pack.json`) holds a single definition object or
an **array** of them. Every object needs a `"type"`.

### Furniture

```json
{
  "type": "furniture",
  "id": "my_cool_mod.beanbag",     // must be globally unique; prefix with your pack id
  "name": "Giant Beanbag",
  "category": "comfort",            // comfort | kitchen | bathroom | electronics | decor | misc
  "price": 150,
  "mesh": "res://assets/furniture/loungeChair.glb",  // a .glb; omit for a placeholder box
  "color": "#cc4444",              // tint used for the placeholder box if mesh is missing
  "size": [1, 1],                  // footprint in tiles (width, depth) before rotation
  "interactions": [
    {
      "id": "lounge",
      "name": "Lounge",
      "duration": 90,              // in-game minutes the interaction lasts
      "gains": { "comfort": 0.6, "fun": 0.3 }   // need points gained per in-game minute
    }
  ]
}
```

**Needs** you can advertise in `gains`:
`hunger`, `energy`, `social`, `fun`, `hygiene`, `bladder`, `comfort`
(0 = desperate, 100 = full). Sims choose interactions with a utility AI: an
interaction is more appealing the more it raises a need the Sim is currently
low on, minus a small travel penalty.

`mesh` paths can be absolute (`res://...`) or relative to your pack folder
(e.g. `models/beanbag.glb` if you ship your own art). **If the mesh is missing
or omitted, the game draws a tinted placeholder box** sized to the footprint —
so your entry always works. This is the "generic variant": you can register
new content even before you have a model for it.

### Floors

```json
{ "type": "floor", "id": "my_cool_mod.lava", "name": "Lava Floor", "price": 20, "color": "#d23b1e" }
```

Optional `"texture": "path.png"` instead of / in addition to `color` (color is
the generic fallback).

### Walls

```json
{ "type": "wall", "id": "my_cool_mod.gold", "name": "Gold Leaf", "price": 80, "color": "#e8c14a" }
```

## Shipping your own 3D models

Drop `.glb`/`.gltf` files in your pack folder and reference them with a relative
`mesh` path. Models of any scale work — characters are auto-normalised to a
sane height, and furniture is centered on its footprint. (For `user://` packs,
runtime glTF loading is supported by Godot's importer when the project is run
from the editor; exported builds import `res://` packs at build time.)

## Testing your pack

Run the unit tests — `test_catalog_agent.gd` loads every pack found, so a
broken JSON file will surface there:

```bash
tools/test.sh
```

The Catalog also prints a summary line on startup:
`[Catalog] loaded N defs from M packs (...)`.
