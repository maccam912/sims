extends Node
## Screenshot harness. Loads the real game, lets it simulate for a moment, then
## saves a PNG and quits. Run windowed (needs a GPU):
##   godot --path . res://tests/screenshot.tscn -- --out=/tmp/sims_shot.png --seconds=4 --speed=12 --build
## Flags (after the `--`):
##   --out=PATH      output PNG path (default user://shot.png)
##   --seconds=N     real seconds to simulate before the shot (default 3)
##   --speed=N       game speed multiplier while simulating (default 8)
##   --build         start in build mode (shows the build UI/ghost)

var game

func _ready() -> void:
	var args := _parse_args()
	var out_path: String = args.get("out", "user://shot.png")
	var seconds := float(args.get("seconds", "3"))
	var speed := float(args.get("speed", "8"))

	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	game.set_speed(speed)
	if args.has("build"):
		game.set_mode(Game.Mode.BUILD)

	# Simulate for the requested wall-clock time.
	var elapsed := 0.0
	while elapsed < seconds:
		elapsed += get_process_delta_time()
		await get_tree().process_frame

	# Let the frame finish, then grab the framebuffer.
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(out_path)
	if err == OK:
		print("[screenshot] saved ", out_path, " (", img.get_width(), "x", img.get_height(), ")")
	else:
		push_error("[screenshot] failed to save %s (err %d)" % [out_path, err])
	get_tree().quit(0 if err == OK else 1)

func _parse_args() -> Dictionary:
	var out: Dictionary = {}
	for a in OS.get_cmdline_user_args():
		var s: String = a.lstrip("-")
		if "=" in s:
			var kv := s.split("=", true, 1)
			out[kv[0]] = kv[1]
		else:
			out[s] = true
	return out
