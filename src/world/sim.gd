class_name Sim
extends Node3D
## The 3D body of a Sim. Owns a SimAgent (the brain), renders a character model,
## and walks to interaction targets. Real-time movement; game-time needs.

const MOVE_SPEED := 2.5  ## metres per real second
const ARRIVE_DIST := 0.35
const TARGET_HEIGHT := 1.7  ## metres; character models are normalised to this

var agent: SimAgent
var lot: Lot
var target_pos: Vector3
var _visual: Node3D
var _label: Label3D

func setup(sim_name: String, lot_ref: Lot, character_path: String, seed_ := 0) -> void:
	agent = SimAgent.new(sim_name, seed_)
	lot = lot_ref
	_build_visual(character_path)

func _build_visual(character_path: String) -> void:
	if character_path != "" and ResourceLoader.exists(character_path):
		var packed: PackedScene = load(character_path)
		if packed:
			_visual = packed.instantiate()
	if _visual == null:
		_visual = _placeholder_capsule()
	else:
		_normalize_visual(_visual, TARGET_HEIGHT)
	add_child(_visual)
	_label = Label3D.new()
	_label.text = agent.sim_name
	_label.position = Vector3(0, 2.0, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.005
	add_child(_label)

func _placeholder_capsule() -> Node3D:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.6
	mi.mesh = cap
	mi.position.y = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.7, 0.5)
	mi.material_override = mat
	return mi

## Scale an arbitrary character model to a sensible height and plant its feet
## on the floor. Works for any model regardless of its authored units.
static func _normalize_visual(node: Node3D, target_height: float) -> void:
	var ab := _combined_aabb(node)
	if ab.size.y <= 0.0001:
		return
	var s := target_height / ab.size.y
	node.scale = Vector3(s, s, s)
	# After scaling, lift so the lowest point rests at y = 0.
	node.position.y = -ab.position.y * s

static func _combined_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for mi in _mesh_instances(node):
		var a: AABB = mi.get_aabb()
		if first:
			result = a
			first = false
		else:
			result = result.merge(a)
	return result

static func _mesh_instances(node: Node, out: Array = []) -> Array:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_mesh_instances(c, out)
	return out

## Advance one frame. game_minutes is elapsed in-game time; real_delta is the
## wall-clock delta used for movement.
func tick(game_minutes: float, real_delta: float) -> void:
	if agent == null:
		return
	agent.decay(game_minutes)
	match agent.state:
		SimAgent.State.IDLE:
			_decide()
		SimAgent.State.MOVING:
			_move(real_delta)
		SimAgent.State.INTERACTING:
			if agent.tick_interaction(game_minutes):
				pass  # back to IDLE next frame
	if _label:
		_label.modulate = _mood_color(agent.needs.mood())

func _decide() -> void:
	var options := agent.gather_options(lot, Callable(Catalog, "get_furniture"))
	var choice := agent.choose_action(options, global_position)
	if not choice.is_empty():
		target_pos = choice["position"]

func _move(real_delta: float) -> void:
	var flat_target := Vector3(target_pos.x, global_position.y, target_pos.z)
	global_position = global_position.move_toward(flat_target, MOVE_SPEED * real_delta)
	# Face direction of travel.
	var dir := flat_target - global_position
	if dir.length() > 0.05:
		look_at(global_position + dir, Vector3.UP)
	if global_position.distance_to(flat_target) <= ARRIVE_DIST:
		agent.begin_interaction()

static func _mood_color(mood: float) -> Color:
	# Green when happy, red when miserable.
	var t := clampf(mood / 100.0, 0.0, 1.0)
	return Color(1.0 - t, t, 0.2).lerp(Color.WHITE, 0.3)
