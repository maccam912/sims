class_name Lot
extends RefCounted
## The buildable state of a lot: floors per tile, walls per edge, and placed
## furniture with footprints. This is pure data (no nodes) so placement rules
## and save/load are unit-testable; WorldView renders it.

var size: Vector2i = Vector2i(16, 16)
var floors: Dictionary = {}        ## tile_key -> floor_id
var walls: Dictionary = {}         ## edge_key -> wall_id
var furniture: Array[Dictionary] = []  ## { uid, def_id, origin:Vector2i, size:Vector2i, rot:int }
var _next_uid: int = 1
var _occupied: Dictionary = {}     ## tile_key -> furniture uid

func _init(lot_size := Vector2i(16, 16)) -> void:
	size = lot_size

## --- Floors -----------------------------------------------------------------

func set_floor(tile: Vector2i, floor_id: String) -> bool:
	if not _in_bounds(tile):
		return false
	floors[Grid.tile_key(tile)] = floor_id
	return true

func clear_floor(tile: Vector2i) -> void:
	floors.erase(Grid.tile_key(tile))

func get_floor(tile: Vector2i) -> String:
	return floors.get(Grid.tile_key(tile), "")

## --- Walls ------------------------------------------------------------------

func set_wall(tile: Vector2i, axis: String, wall_id: String) -> void:
	walls[Grid.edge_key(tile, axis)] = wall_id

func clear_wall(tile: Vector2i, axis: String) -> void:
	walls.erase(Grid.edge_key(tile, axis))

func get_wall(tile: Vector2i, axis: String) -> String:
	return walls.get(Grid.edge_key(tile, axis), "")

## --- Furniture --------------------------------------------------------------

func can_place_furniture(size_tiles: Vector2i, origin: Vector2i, rot: int, ignore_uid := -1) -> bool:
	if not Grid.footprint_in_bounds(origin, size_tiles, rot, size):
		return false
	for t in Grid.footprint_tiles(origin, size_tiles, rot):
		var k := Grid.tile_key(t)
		if _occupied.has(k) and _occupied[k] != ignore_uid:
			return false
	return true

## Place a piece. Returns its new uid, or -1 if it doesn't fit.
func place_furniture(def_id: String, size_tiles: Vector2i, origin: Vector2i, rot: int) -> int:
	if not can_place_furniture(size_tiles, origin, rot):
		return -1
	var uid := _next_uid
	_next_uid += 1
	var rec := {
		"uid": uid, "def_id": def_id, "origin": origin,
		"size": size_tiles, "rot": rot,
	}
	furniture.append(rec)
	for t in Grid.footprint_tiles(origin, size_tiles, rot):
		_occupied[Grid.tile_key(t)] = uid
	return uid

func remove_furniture(uid: int) -> bool:
	for i in furniture.size():
		if furniture[i]["uid"] == uid:
			var rec: Dictionary = furniture[i]
			for t in Grid.footprint_tiles(rec["origin"], rec["size"], rec["rot"]):
				_occupied.erase(Grid.tile_key(t))
			furniture.remove_at(i)
			return true
	return false

func get_furniture(uid: int) -> Dictionary:
	for rec in furniture:
		if rec["uid"] == uid:
			return rec
	return {}

func furniture_at(tile: Vector2i) -> int:
	return _occupied.get(Grid.tile_key(tile), -1)

func _in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y

## --- Save / Load ------------------------------------------------------------

func to_dict() -> Dictionary:
	var furn: Array = []
	for rec in furniture:
		furn.append({
			"uid": rec["uid"], "def_id": rec["def_id"],
			"origin": [rec["origin"].x, rec["origin"].y],
			"size": [rec["size"].x, rec["size"].y],
			"rot": rec["rot"],
		})
	return {
		"size": [size.x, size.y],
		"floors": floors.duplicate(),
		"walls": walls.duplicate(),
		"furniture": furn,
		"next_uid": _next_uid,
	}

static func from_dict(d: Dictionary) -> Lot:
	var sz: Array = d.get("size", [16, 16])
	var lot := Lot.new(Vector2i(int(sz[0]), int(sz[1])))
	lot.floors = (d.get("floors", {}) as Dictionary).duplicate()
	lot.walls = (d.get("walls", {}) as Dictionary).duplicate()
	for rec in d.get("furniture", []):
		var o: Array = rec["origin"]
		var s: Array = rec["size"]
		var uid := int(rec["uid"])
		var entry := {
			"uid": uid, "def_id": str(rec["def_id"]),
			"origin": Vector2i(int(o[0]), int(o[1])),
			"size": Vector2i(int(s[0]), int(s[1])),
			"rot": int(rec["rot"]),
		}
		lot.furniture.append(entry)
		for t in Grid.footprint_tiles(entry["origin"], entry["size"], entry["rot"]):
			lot._occupied[Grid.tile_key(t)] = uid
	lot._next_uid = int(d.get("next_uid", lot.furniture.size() + 1))
	return lot
