class_name CameraRig
extends Node3D
## RTS/Sims-style camera. The rig sits at a focus point on the ground; a gimbal
## child holds pitch; the camera sits back along the gimbal at `distance`.
## All controls are InputMap actions (rebindable in Project Settings > Input Map):
##   - cam_pan_forward/back/left/right (WASD / arrows) or cam_pan_drag (middle-drag): pan
##   - cam_orbit (right-drag): orbit (yaw + pitch)
##   - cam_zoom_in / cam_zoom_out (E / Q, = / -): zoom — trackpad friendly, no wheel needed
##   - mouse wheel / two-finger scroll: zoom (bonus, also calls zoom_by)
## UI buttons call zoom_by() directly.

@export var pan_speed := 8.0
@export var rotate_speed := 0.01
@export var zoom_speed := 1.5          ## distance change per wheel notch / UI click
@export var key_zoom_speed := 12.0     ## distance change per second while a zoom key is held
@export var min_distance := 3.0
@export var max_distance := 30.0

var yaw := 0.0
var pitch := 0.9          ## radians from horizontal-ish (looking down)
var distance := 14.0
var _gimbal: Node3D
var camera: Camera3D
var _rotating := false
var _panning := false

func _ready() -> void:
	_gimbal = Node3D.new()
	add_child(_gimbal)
	camera = Camera3D.new()
	camera.current = true
	_gimbal.add_child(camera)
	_apply()

func focus_on(point: Vector3) -> void:
	position = Vector3(point.x, 0.0, point.z)
	_apply()

func _apply() -> void:
	rotation.y = yaw
	_gimbal.rotation.x = -pitch
	camera.position = Vector3(0, 0, distance)

## Step zoom (negative = closer). Public so UI buttons / two-finger scroll can call it.
func zoom_by(steps: float) -> void:
	distance = clampf(distance + steps * zoom_speed, min_distance, max_distance)
	_apply()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cam_orbit"):
		_rotating = true
	elif event.is_action_released("cam_orbit"):
		_rotating = false
	elif event.is_action_pressed("cam_pan_drag"):
		_panning = true
	elif event.is_action_released("cam_pan_drag"):
		_panning = false

	# Mouse wheel / macOS two-finger scroll: a convenient extra zoom path.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(-1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.0)
	elif event is InputEventMouseMotion:
		if _rotating:
			yaw -= event.relative.x * rotate_speed
			pitch = clampf(pitch + event.relative.y * rotate_speed, 0.2, 1.45)
			_apply()
		elif _panning:
			_pan_by(event.relative)

func _process(delta: float) -> void:
	# Pan from rebindable actions, relative to current yaw so it feels screen-aligned.
	var dir := Vector3.ZERO
	dir.z += Input.get_action_strength("cam_pan_back") - Input.get_action_strength("cam_pan_forward")
	dir.x += Input.get_action_strength("cam_pan_right") - Input.get_action_strength("cam_pan_left")
	if dir != Vector3.ZERO:
		position += (Basis(Vector3.UP, yaw) * dir).normalized() * pan_speed * delta

	# Smooth held-key zoom — the trackpad-friendly path (no wheel required).
	var z := Input.get_action_strength("cam_zoom_out") - Input.get_action_strength("cam_zoom_in")
	if z != 0.0:
		distance = clampf(distance + z * key_zoom_speed * delta, min_distance, max_distance)
		_apply()

func _pan_by(rel: Vector2) -> void:
	var scale := distance * 0.0015
	var move := Basis(Vector3.UP, yaw) * Vector3(-rel.x * scale, 0, -rel.y * scale)
	position += move
