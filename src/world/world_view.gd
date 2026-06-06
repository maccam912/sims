class_name WorldView
extends Node3D
## Renders a Lot: the ground, floor tiles, wall segments and furniture. Reads
## colours/meshes from the Catalog autoload. Rebuilds are cheap enough for a
## foundation (lots are small); incremental helpers keep editing snappy.

const WALL_HEIGHT := 1.4
const WALL_THICK := 0.12
const FLOOR_THICK := 0.06

var lot: Lot
var _floor_root: Node3D
var _wall_root: Node3D
var _furniture_root: Node3D
var _ground: MeshInstance3D
var _furniture_nodes: Dictionary = {}  ## uid -> Node3D

func _ready() -> void:
	_floor_root = Node3D.new()
	_floor_root.name = "Floors"
	_wall_root = Node3D.new()
	_wall_root.name = "Walls"
	_furniture_root = Node3D.new()
	_furniture_root.name = "Furniture"
	add_child(_floor_root)
	add_child(_wall_root)
	add_child(_furniture_root)

func set_lot(new_lot: Lot) -> void:
	lot = new_lot
	rebuild()

func rebuild() -> void:
	if lot == null:
		return
	_build_ground()
	_rebuild_floors()
	_rebuild_walls()
	_rebuild_furniture()

## --- Ground -----------------------------------------------------------------

func _build_ground() -> void:
	if _ground == null:
		_ground = MeshInstance3D.new()
		_ground.name = "Ground"
		add_child(_ground)
	var plane := PlaneMesh.new()
	plane.size = Vector2(lot.size.x, lot.size.y)
	_ground.mesh = plane
	_ground.position = Vector3(lot.size.x * 0.5, -0.02, lot.size.y * 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.42, 0.27)  # grass
	_ground.material_override = mat

## --- Floors -----------------------------------------------------------------

func _rebuild_floors() -> void:
	_clear(_floor_root)
	for key in lot.floors:
		var parts: PackedStringArray = key.split(",")
		var tile := Vector2i(int(parts[0]), int(parts[1]))
		_floor_root.add_child(_make_floor_tile(tile, lot.floors[key]))

func _make_floor_tile(tile: Vector2i, floor_id: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(Grid.TILE_SIZE, FLOOR_THICK, Grid.TILE_SIZE)
	mi.mesh = box
	mi.position = Grid.tile_to_world(tile) + Vector3(0, FLOOR_THICK * 0.5, 0)
	mi.material_override = _color_material(_floor_color(floor_id))
	return mi

func _floor_color(floor_id: String) -> Color:
	var def: FloorDef = Catalog.get_floor(floor_id)
	return def.color if def else Color(0.6, 0.6, 0.6)

## --- Walls ------------------------------------------------------------------

func _rebuild_walls() -> void:
	_clear(_wall_root)
	for key in lot.walls:
		var parts: PackedStringArray = key.split(",")
		var tile := Vector2i(int(parts[0]), int(parts[1]))
		var axis := parts[2]
		_wall_root.add_child(_make_wall(tile, axis, lot.walls[key]))

func _make_wall(tile: Vector2i, axis: String, wall_id: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(Grid.TILE_SIZE, WALL_HEIGHT, WALL_THICK)
	mi.mesh = box
	mi.position = Grid.edge_to_world(tile, axis) + Vector3(0, WALL_HEIGHT * 0.5, 0)
	mi.rotation.y = Grid.edge_rotation(axis)
	mi.material_override = _color_material(_wall_color(wall_id))
	return mi

func _wall_color(wall_id: String) -> Color:
	var def: WallDef = Catalog.get_wall(wall_id)
	return def.color if def else Color(0.9, 0.88, 0.82)

## --- Furniture --------------------------------------------------------------

func _rebuild_furniture() -> void:
	_clear(_furniture_root)
	_furniture_nodes.clear()
	for rec in lot.furniture:
		_add_furniture_node(rec)

func add_furniture(rec: Dictionary) -> void:
	_add_furniture_node(rec)

func remove_furniture(uid: int) -> void:
	if _furniture_nodes.has(uid):
		_furniture_nodes[uid].queue_free()
		_furniture_nodes.erase(uid)

func _add_furniture_node(rec: Dictionary) -> void:
	var def: FurnitureDef = Catalog.get_furniture(rec["def_id"])
	var node := build_furniture_visual(def)
	node.position = footprint_center(rec)
	node.rotation.y = Grid.rot_steps_to_radians(rec["rot"])
	_furniture_root.add_child(node)
	_furniture_nodes[rec["uid"]] = node

## World-space centre of a placed piece's footprint, at floor level.
static func footprint_center(rec: Dictionary) -> Vector3:
	var tiles := Grid.footprint_tiles(rec["origin"], rec["size"], rec["rot"])
	var sum := Vector3.ZERO
	for t in tiles:
		sum += Grid.tile_to_world(t)
	return sum / float(tiles.size())

## Build a visual for a furniture def: its GLB if available, else a tinted box
## placeholder (the "generic" fallback so modded entries without art still work).
static func build_furniture_visual(def: FurnitureDef) -> Node3D:
	if def != null and def.mesh_path != "" and ResourceLoader.exists(def.mesh_path):
		var packed: PackedScene = load(def.mesh_path)
		if packed:
			return packed.instantiate()
	# Placeholder box sized to footprint.
	var holder := Node3D.new()
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	var w := 1.0
	var h := 1.0
	if def != null:
		w = float(def.size.x)
		h = float(def.size.y)
	box.size = Vector3(w * 0.9, 0.6, h * 0.9)
	mi.mesh = box
	mi.position.y = 0.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = def.color if def else Color(0.8, 0.4, 0.8)
	mi.material_override = mat
	holder.add_child(mi)
	return holder

## --- Helpers ----------------------------------------------------------------

static func _color_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m

static func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
