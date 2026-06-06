extends SimsTest
## Tests for the node-free simulation core: clock, needs, grid, utility AI.

func test_clock_advances_and_formats() -> void:
	var c := GameClock.new()
	c.advance(60.0)  # 60 real-seconds * 1 min/sec * speed 1 = 60 game-minutes
	eq(c.hour(), 1, "1 hour after 60 minutes")
	eq(c.day(), 0, "still day 0")
	c.advance(60.0 * 23.0)
	eq(c.day(), 1, "rolled into day 1 after 24h")

func test_clock_pause() -> void:
	var c := GameClock.new()
	c.set_paused(true)
	c.advance(100.0)
	approx(c.total_minutes, 0.0, "paused clock does not advance")
	ok(c.is_paused(), "is_paused true")

func test_clock_night() -> void:
	var c := GameClock.new()
	c.advance(23.0 * 60.0)  # 23:00
	ok(c.is_night(), "23:00 is night")
	c.total_minutes = 12.0 * 60.0
	ok(not c.is_night(), "noon is not night")

func test_needs_decay_and_clamp() -> void:
	var n := Needs.new(50.0)
	n.decay_over(100.0)
	gt(50.0, n.get_value("hunger"), "hunger decayed below 50")
	n.decay_over(100000.0)
	approx(n.get_value("hunger"), 0.0, "need clamps at 0")

func test_needs_gain_clamps_at_100() -> void:
	var n := Needs.new(90.0)
	n.apply_gains({"hunger": 5.0}, 100.0)
	approx(n.get_value("hunger"), 100.0, "gain clamps at 100")

func test_needs_mood() -> void:
	var n := Needs.new(100.0)
	approx(n.mood(), 100.0, "full needs => full mood")

func test_grid_roundtrip() -> void:
	var t := Vector2i(3, 5)
	var w := Grid.tile_to_world(t)
	eq(Grid.world_to_tile(w), t, "tile->world->tile roundtrip")
	approx(w.x, 3.5, "tile centre x")
	approx(w.z, 5.5, "tile centre z")

func test_grid_footprint_rotation() -> void:
	var f0 := Grid.footprint_tiles(Vector2i(0, 0), Vector2i(1, 2), 0)
	eq(f0.size(), 2, "1x2 occupies 2 tiles")
	var f1 := Grid.footprint_tiles(Vector2i(0, 0), Vector2i(1, 2), 1)
	ok(f1.has(Vector2i(0, 0)) and f1.has(Vector2i(1, 0)), "90deg rotation swaps to 2x1")

func test_grid_edge_keys_unique() -> void:
	var a := Grid.edge_key(Vector2i(1, 1), "h")
	var b := Grid.edge_key(Vector2i(1, 1), "v")
	ok(a != b, "h and v edges of same tile differ")

func test_utility_desire_monotonic() -> void:
	gt(UtilityAI.desire(0.0), UtilityAI.desire(50.0), "lower need => higher desire")
	gt(UtilityAI.desire(50.0), UtilityAI.desire(99.0), "desire decreases as need fills")

func test_utility_picks_most_urgent() -> void:
	var n := Needs.new(80.0)
	n.set_value("bladder", 5.0)   # desperate
	var options := [
		{"name": "Sleep",  "gains": {"energy": 0.2},  "duration": 60, "position": Vector3.ZERO},
		{"name": "Toilet", "gains": {"bladder": 9.0}, "duration": 10, "position": Vector3.ZERO},
	]
	var choice := UtilityAI.choose(n, options)
	eq(choice.get("name"), "Toilet", "desperate bladder -> chooses toilet")

func test_utility_empty_when_satisfied() -> void:
	var n := Needs.new(100.0)
	var options := [{"name": "Sleep", "gains": {"energy": 0.2}, "duration": 60}]
	var choice := UtilityAI.choose(n, options)
	ok(choice.is_empty(), "fully satisfied Sim chooses nothing")

func test_utility_distance_penalty() -> void:
	var n := Needs.new(40.0)
	var near := {"name": "near", "gains": {"fun": 0.5}, "duration": 60, "position": Vector3(1, 0, 0)}
	var far := {"name": "far", "gains": {"fun": 0.5}, "duration": 60, "position": Vector3(50, 0, 0)}
	var choice := UtilityAI.choose(n, [near, far], Vector3.ZERO)
	eq(choice.get("name"), "near", "prefers closer of two equal options")
