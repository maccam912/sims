extends SimsTest
## Tests for the Lot placement model and save/load.

func test_floor_set_and_bounds() -> void:
	var lot := Lot.new(Vector2i(4, 4))
	ok(lot.set_floor(Vector2i(0, 0), "core.floor_wood"), "place floor in bounds")
	ok(not lot.set_floor(Vector2i(9, 9), "core.floor_wood"), "reject floor out of bounds")
	eq(lot.get_floor(Vector2i(0, 0)), "core.floor_wood", "floor stored")

func test_furniture_place_and_overlap() -> void:
	var lot := Lot.new(Vector2i(8, 8))
	var a := lot.place_furniture("core.bed_single", Vector2i(1, 2), Vector2i(0, 0), 0)
	gt(float(a), 0.0, "first piece placed")
	# Overlapping placement should fail.
	var b := lot.place_furniture("core.sofa", Vector2i(2, 1), Vector2i(0, 0), 0)
	eq(b, -1, "overlapping placement rejected")
	# Non-overlapping placement should succeed.
	var c := lot.place_furniture("core.sofa", Vector2i(2, 1), Vector2i(3, 3), 0)
	gt(float(c), 0.0, "non-overlapping placement ok")

func test_furniture_out_of_bounds() -> void:
	var lot := Lot.new(Vector2i(4, 4))
	var uid := lot.place_furniture("core.bed_double", Vector2i(2, 2), Vector2i(3, 3), 0)
	eq(uid, -1, "piece spilling off lot is rejected")

func test_furniture_remove_frees_tiles() -> void:
	var lot := Lot.new(Vector2i(8, 8))
	var uid := lot.place_furniture("core.sofa", Vector2i(2, 1), Vector2i(0, 0), 0)
	ok(lot.remove_furniture(uid), "removed")
	var uid2 := lot.place_furniture("core.sofa", Vector2i(2, 1), Vector2i(0, 0), 0)
	gt(float(uid2), 0.0, "can place again after removal")

func test_furniture_at_lookup() -> void:
	var lot := Lot.new(Vector2i(8, 8))
	var uid := lot.place_furniture("core.bed_single", Vector2i(1, 2), Vector2i(2, 2), 0)
	eq(lot.furniture_at(Vector2i(2, 3)), uid, "footprint tile maps to uid")
	eq(lot.furniture_at(Vector2i(5, 5)), -1, "empty tile maps to -1")

func test_save_load_roundtrip() -> void:
	var lot := Lot.new(Vector2i(10, 10))
	lot.set_floor(Vector2i(1, 1), "core.floor_tile")
	lot.set_wall(Vector2i(2, 2), "h", "core.wall_brick")
	var uid := lot.place_furniture("core.toilet", Vector2i(1, 1), Vector2i(4, 4), 1)
	var d := lot.to_dict()
	var lot2 := Lot.from_dict(d)
	eq(lot2.get_floor(Vector2i(1, 1)), "core.floor_tile", "floor survives roundtrip")
	eq(lot2.get_wall(Vector2i(2, 2), "h"), "core.wall_brick", "wall survives roundtrip")
	eq(lot2.furniture_at(Vector2i(4, 4)), uid, "furniture occupancy rebuilt after load")
	# And placement rules still hold on the loaded lot.
	ok(not lot2.can_place_furniture(Vector2i(1, 1), Vector2i(4, 4), 0), "loaded occupancy blocks overlap")
