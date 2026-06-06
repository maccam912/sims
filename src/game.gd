class_name Game
extends Node3D
## Top-level orchestrator. Owns the clock, the Lot and its WorldView, the Sims,
## the camera, and build-mode placement. Builds the whole scene in code so there
## are no fragile .tscn dependencies.

enum Mode { LIVE, BUILD }
enum BuildTool { FLOOR, WALL, FURNITURE, DEMOLISH }

const SAVE_PATH := "user://save_lot.json"

var clock := GameClock.new()
var lot: Lot
var world: WorldView
var rig: CameraRig
var sims: Array[Sim] = []

var mode: int = Mode.LIVE
var tool: int = BuildTool.FURNITURE
var selected_furniture := "core.sofa"
var selected_floor := "core.floor_wood"
var selected_wall := "core.wall_drywall"
var place_rot := 0

var _ghost: Node3D
var _hover_tile := Vector2i.ZERO
var _hud  # HUD control (src/ui/hud.gd)

func _ready() -> void:
	_build_environment()
	lot = Lot.new(Vector2i(20, 20))
	world = WorldView.new()
	add_child(world)
	world.set_lot(lot)
	_make_starter_house()
	world.rebuild()
	_spawn_sims()
	rig = CameraRig.new()
	add_child(rig)
	rig.distance = 11.0
	rig.focus_on(Grid.tile_to_world(Vector2i(9, 8)))
	_hud = preload("res://src/ui/hud.gd").new()
	add_child(_hud)
	_hud.setup(self)

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-40), 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	add_child(sun)

## --- Starter content --------------------------------------------------------

func _make_starter_house() -> void:
	# A small furnished house in the middle of the lot.
	var ox := 5
	var oy := 5
	var w := 9
	var h := 7
	for x in range(w):
		for y in range(h):
			var fl := "core.floor_wood"
			if x >= 5:
				fl = "core.floor_tile"  # kitchen/bath side
			lot.set_floor(Vector2i(ox + x, oy + y), fl)
	# Perimeter walls.
	for x in range(w):
		lot.set_wall(Vector2i(ox + x, oy), "h", "core.wall_drywall")
		lot.set_wall(Vector2i(ox + x, oy + h), "h", "core.wall_drywall")
	for y in range(h):
		lot.set_wall(Vector2i(ox, oy + y), "v", "core.wall_drywall")
		lot.set_wall(Vector2i(ox + w, oy + y), "v", "core.wall_drywall")
	# Furniture (def_id, tile, rot).
	var plan := [
		["core.bed_double", Vector2i(ox + 1, oy + 1), 0],
		["core.side_table", Vector2i(ox + 3, oy + 1), 0],
		["core.sofa", Vector2i(ox + 1, oy + 4), 0],
		["core.tv", Vector2i(ox + 1, oy + 5), 2],
		["core.bookcase", Vector2i(ox + 3, oy + 5), 0],
		["core.fridge", Vector2i(ox + 6, oy + 1), 0],
		["core.stove", Vector2i(ox + 7, oy + 1), 0],
		["core.counter", Vector2i(ox + 5, oy + 1), 0],
		["core.dining_table", Vector2i(ox + 6, oy + 3), 0],
		["core.dining_chair", Vector2i(ox + 6, oy + 4), 0],
		["core.toilet", Vector2i(ox + 5, oy + 5), 0],
		["core.shower", Vector2i(ox + 7, oy + 5), 0],
		["core.plant", Vector2i(ox + 3, oy + 3), 0],
	]
	for p in plan:
		var def: FurnitureDef = Catalog.get_furniture(p[0])
		if def:
			lot.place_furniture(def.id, def.size, p[1], p[2])

func _spawn_sims() -> void:
	var names := ["Alex", "Sam"]
	var chars := ["res://assets/characters/character-a.glb", "res://assets/characters/character-b.glb"]
	for i in names.size():
		var s := Sim.new()
		add_child(s)
		s.setup(names[i], lot, chars[i], i + 1)
		s.global_position = Grid.tile_to_world(Vector2i(8 + i, 8))
		sims.append(s)

## --- Main loop --------------------------------------------------------------

func _process(delta: float) -> void:
	var before := clock.total_minutes
	clock.advance(delta)
	var game_minutes := clock.total_minutes - before
	if mode == Mode.LIVE:
		for s in sims:
			s.tick(game_minutes, delta)
	if _hud:
		_hud.refresh()
	if mode == Mode.BUILD:
		_update_ghost()

## --- Mode & tools (called by HUD) ------------------------------------------

func set_mode(m: int) -> void:
	mode = m
	clock.set_paused(mode == Mode.BUILD)
	if mode == Mode.BUILD:
		_ensure_ghost()
	else:
		_clear_ghost()
	if _hud:
		_hud.on_mode_changed(mode)

func set_tool(t: int) -> void:
	tool = t
	_ensure_ghost()

func set_speed(s: float) -> void:
	clock.speed = s

## --- Build placement --------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Global controls (work in any mode) — all rebindable via the InputMap.
	if event.is_action_pressed("toggle_build"):
		set_mode(Mode.LIVE if mode == Mode.BUILD else Mode.BUILD)
		return
	if event.is_action_pressed("speed_pause"):
		set_speed(0.0 if clock.speed != 0.0 else 1.0)
	elif event.is_action_pressed("speed_normal"):
		set_speed(1.0)
	elif event.is_action_pressed("speed_fast"):
		set_speed(2.0)
	elif event.is_action_pressed("speed_faster"):
		set_speed(4.0)

	if mode != Mode.BUILD:
		return
	if event.is_action_pressed("build_cancel"):
		set_mode(Mode.LIVE)
	elif event.is_action_pressed("build_rotate"):
		place_rot = (place_rot + 1) % 4
	elif event.is_action_pressed("build_place"):
		_do_place()

func _ground_point() -> Vector3:
	var mouse := get_viewport().get_mouse_position()
	var origin := rig.camera.project_ray_origin(mouse)
	var dir := rig.camera.project_ray_normal(mouse)
	var plane := Plane(Vector3.UP, 0.0)
	var hit = plane.intersects_ray(origin, dir)
	return hit if hit != null else Vector3.ZERO

func _ground_to_tile(p: Vector3) -> Vector2i:
	return Grid.world_to_tile(p)

func _do_place() -> void:
	var p := _ground_point()
	var tile := _ground_to_tile(p)
	match tool:
		BuildTool.FLOOR:
			lot.set_floor(tile, selected_floor)
			world.rebuild()
		BuildTool.WALL:
			var axis := _nearest_axis(p, tile)
			lot.set_wall(tile, axis, selected_wall)
			world.rebuild()
		BuildTool.FURNITURE:
			var def: FurnitureDef = Catalog.get_furniture(selected_furniture)
			if def:
				var uid := lot.place_furniture(def.id, def.size, tile, place_rot)
				if uid != -1:
					world.add_furniture(lot.get_furniture(uid))
		BuildTool.DEMOLISH:
			var uid := lot.furniture_at(tile)
			if uid != -1:
				lot.remove_furniture(uid)
				world.remove_furniture(uid)
			else:
				lot.clear_floor(tile)
				lot.clear_wall(tile, "h")
				lot.clear_wall(tile, "v")
				world.rebuild()

func _nearest_axis(p: Vector3, tile: Vector2i) -> String:
	var fx := p.x - tile.x  # 0..1 within tile
	var fz := p.z - tile.y
	# Distance to the -Z edge ("h") vs -X edge ("v").
	return "h" if minf(fz, 1.0 - fz) < minf(fx, 1.0 - fx) else "v"

## --- Ghost preview ----------------------------------------------------------

func _ensure_ghost() -> void:
	_clear_ghost()
	if mode != Mode.BUILD:
		return
	if tool == BuildTool.FURNITURE:
		var def: FurnitureDef = Catalog.get_furniture(selected_furniture)
		_ghost = WorldView.build_furniture_visual(def)
		_make_transparent(_ghost)
		add_child(_ghost)

func _clear_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null

func _update_ghost() -> void:
	if _ghost == null:
		return
	var p := _ground_point()
	var tile := _ground_to_tile(p)
	_hover_tile = tile
	var def: FurnitureDef = Catalog.get_furniture(selected_furniture)
	if def == null:
		return
	var rec := {"origin": tile, "size": def.size, "rot": place_rot}
	_ghost.position = WorldView.footprint_center(rec)
	_ghost.rotation.y = Grid.rot_steps_to_radians(place_rot)
	var ok := lot.can_place_furniture(def.size, tile, place_rot)
	_tint_ghost(Color(0.4, 1, 0.4, 0.5) if ok else Color(1, 0.4, 0.4, 0.5))

func select_furniture(id: String) -> void:
	selected_furniture = id
	if tool == BuildTool.FURNITURE:
		_ensure_ghost()

func _make_transparent(node: Node) -> void:
	for child in node.get_children():
		_make_transparent(child)
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.4, 1, 0.4, 0.5)
		node.material_override = mat

func _tint_ghost(c: Color) -> void:
	_tint_recursive(_ghost, c)

func _tint_recursive(node: Node, c: Color) -> void:
	if node is MeshInstance3D and node.material_override is StandardMaterial3D:
		node.material_override.albedo_color = c
	for child in node.get_children():
		_tint_recursive(child, c)

## --- Save / Load ------------------------------------------------------------

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(lot.to_dict(), "  "))
		print("[Game] saved to ", SAVE_PATH)

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		lot = Lot.from_dict(data)
		world.set_lot(lot)
		for s in sims:
			s.lot = lot
		print("[Game] loaded from ", SAVE_PATH)
