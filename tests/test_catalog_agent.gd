extends SimsTest
## Integration: load the real content packs, then drive a SimAgent against a Lot
## built from those defs. Verifies the data pipeline and AI end to end.

var catalog

func before() -> void:
	catalog = preload("res://src/registry/catalog.gd").new()
	catalog.load_all()

func after() -> void:
	if catalog:
		catalog.free()  # it's a Node, not RefCounted
		catalog = null

func test_core_pack_loaded() -> void:
	gt(float(catalog.furniture.size()), 10.0, "core furniture loaded")
	gt(float(catalog.floors.size()), 3.0, "core floors loaded")
	gt(float(catalog.walls.size()), 3.0, "core walls loaded")
	ok(catalog.get_furniture("core.fridge") != null, "fridge def present")
	ok(catalog.get_furniture("core.toilet") != null, "toilet def present")

func test_example_mod_loaded() -> void:
	ok(catalog.get_furniture("example_mod.gold_throne") != null, "mod furniture loaded")
	ok(catalog.get_floor("example_mod.floor_gold") != null, "mod floor loaded")

func test_furniture_def_parsing() -> void:
	var bed: FurnitureDef = catalog.get_furniture("core.bed_single")
	eq(bed.size, Vector2i(1, 2), "bed footprint parsed")
	ok(bed.has_interactions(), "bed has interactions")
	eq(bed.interactions[0].id, "sleep", "sleep interaction id")
	ok(bed.mesh_path.ends_with("bedSingle.glb"), "mesh path resolved")

func test_agent_picks_food_when_hungry() -> void:
	var lot := Lot.new(Vector2i(12, 12))
	var fridge: FurnitureDef = catalog.get_furniture("core.fridge")
	var bed: FurnitureDef = catalog.get_furniture("core.bed_single")
	lot.place_furniture(fridge.id, fridge.size, Vector2i(1, 1), 0)
	lot.place_furniture(bed.id, bed.size, Vector2i(6, 6), 0)
	var agent := SimAgent.new("Tester", 42)
	agent.needs.set_value("hunger", 8.0)   # starving
	agent.needs.set_value("energy", 75.0)  # fine
	var opts := agent.gather_options(lot, Callable(catalog, "get_furniture"))
	gt(float(opts.size()), 0.0, "options gathered from lot")
	var choice := agent.choose_action(opts, Vector3.ZERO, 0.0)
	eq(choice.get("object_id"), 1, "chose the fridge (uid 1)")
	eq(choice.get("interaction_id"), "snack", "chose the snack interaction")

func test_agent_interaction_raises_need() -> void:
	var lot := Lot.new(Vector2i(12, 12))
	var fridge: FurnitureDef = catalog.get_furniture("core.fridge")
	lot.place_furniture(fridge.id, fridge.size, Vector2i(1, 1), 0)
	var agent := SimAgent.new("Tester", 7)
	agent.needs.set_value("hunger", 10.0)
	var opts := agent.gather_options(lot, Callable(catalog, "get_furniture"))
	agent.choose_action(opts, Vector3.ZERO, 0.0)
	agent.begin_interaction()
	var before_h := agent.needs.get_value("hunger")
	var done := false
	for i in 100:
		done = agent.tick_interaction(1.0)
		if done:
			break
	gt(agent.needs.get_value("hunger"), before_h, "hunger rose during snack")
	ok(done, "interaction completed within its duration")
