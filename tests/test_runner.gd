extends SceneTree
## Headless test runner.
##   godot --headless --script res://tests/test_runner.gd
## Exits with code 0 if all tests pass, 1 otherwise.

const TEST_FILES := [
	"res://tests/test_core.gd",
	"res://tests/test_lot.gd",
	"res://tests/test_catalog_agent.gd",
]

func _init() -> void:
	var total := 0
	var passed := 0
	var failed := 0
	var all_failures: Array[String] = []

	for path in TEST_FILES:
		var script: GDScript = load(path)
		if script == null:
			push_error("Could not load test file: " + path)
			failed += 1
			continue
		var file_name: String = str(path).get_file()
		var probe: SimsTest = script.new()
		for method in probe.get_method_list():
			var m: String = method["name"]
			if not m.begins_with("test_"):
				continue
			# Reset state per test for isolation.
			var t: SimsTest = script.new()
			t.before()
			t.call(m)
			t.after()
			total += 1
			if t.failures.is_empty():
				passed += 1
				print("  PASS  %s::%s (%d checks)" % [file_name, m, t.checks])
			else:
				failed += 1
				print("  FAIL  %s::%s" % [file_name, m])
				for f in t.failures:
					print("        " + f)
					all_failures.append("%s::%s  %s" % [file_name, m, f])

	print("")
	print("==================================================")
	print("Tests: %d   Passed: %d   Failed: %d" % [total, passed, failed])
	print("==================================================")
	if failed > 0:
		print("FAILURES:")
		for f in all_failures:
			print("  " + f)
	quit(0 if failed == 0 else 1)
