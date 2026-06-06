class_name Grid
extends RefCounted
## Static grid math for a Sims-style lot. The world is an X/Z grid of square
## tiles. Floors occupy tiles. Walls occupy the *edges* between adjacent tiles.
## Furniture occupies a rectangular footprint of tiles plus a rotation.
##
## All functions are static and node-free for easy testing.

const TILE_SIZE := 1.0  ## metres per tile

## --- Tile <-> world ---------------------------------------------------------

static func world_to_tile(world: Vector3) -> Vector2i:
	return Vector2i(int(floor(world.x / TILE_SIZE)), int(floor(world.z / TILE_SIZE)))

## Centre of a tile in world space (y = 0).
static func tile_to_world(tile: Vector2i) -> Vector3:
	return Vector3((tile.x + 0.5) * TILE_SIZE, 0.0, (tile.y + 0.5) * TILE_SIZE)

static func tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

## --- Wall edges -------------------------------------------------------------
## A wall sits on the boundary between two tiles. We identify an edge by its
## lower-coordinate tile plus an axis: "h" = the edge on that tile's -Z side,
## "v" = the edge on that tile's -X side. This gives every edge a unique key.

static func edge_key(tile: Vector2i, axis: String) -> String:
	return "%d,%d,%s" % [tile.x, tile.y, axis]

## World midpoint of an edge (y = 0), for placing wall meshes.
static func edge_to_world(tile: Vector2i, axis: String) -> Vector3:
	if axis == "h":  # edge along X, on the -Z side of the tile
		return Vector3((tile.x + 0.5) * TILE_SIZE, 0.0, tile.y * TILE_SIZE)
	else:            # "v": edge along Z, on the -X side of the tile
		return Vector3(tile.x * TILE_SIZE, 0.0, (tile.y + 0.5) * TILE_SIZE)

## Y-rotation (radians) a wall mesh needs to align with the edge.
static func edge_rotation(axis: String) -> float:
	return 0.0 if axis == "h" else PI / 2.0

## --- Footprints -------------------------------------------------------------
## Furniture has a base size in tiles (w x h) and a rotation in 90° steps.
## Returns the list of tiles it occupies when its origin tile is `origin`.

static func footprint_tiles(origin: Vector2i, size: Vector2i, rot_steps: int) -> Array[Vector2i]:
	var w := size.x
	var h := size.y
	if rot_steps % 2 == 1:  # 90 or 270 degrees swaps the dimensions
		var t := w
		w = h
		h = t
	var tiles: Array[Vector2i] = []
	for dx in range(w):
		for dz in range(h):
			tiles.append(Vector2i(origin.x + dx, origin.y + dz))
	return tiles

static func rot_steps_to_radians(rot_steps: int) -> float:
	return float(rot_steps % 4) * (PI / 2.0)

## True if every tile in the footprint is inside [0,size) on both axes.
static func footprint_in_bounds(origin: Vector2i, size: Vector2i, rot_steps: int, lot: Vector2i) -> bool:
	for t in footprint_tiles(origin, size, rot_steps):
		if t.x < 0 or t.y < 0 or t.x >= lot.x or t.y >= lot.y:
			return false
	return true
