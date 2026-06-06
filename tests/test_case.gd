class_name SimsTest
extends RefCounted
## Minimal assertion base for headless tests. Each test file extends this and
## defines methods named test_*. Failures are collected, not fatal, so one run
## reports every problem.

var failures: Array[String] = []
var checks: int = 0

func _fail(msg: String) -> void:
	failures.append(msg)

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		_fail("FAIL: " + msg)

func eq(a, b, msg := "") -> void:
	checks += 1
	if a != b:
		_fail("FAIL: %s  (expected %s, got %s)" % [msg, str(b), str(a)])

func approx(a: float, b: float, msg := "", tol := 0.0001) -> void:
	checks += 1
	if absf(a - b) > tol:
		_fail("FAIL: %s  (expected ~%s, got %s)" % [msg, str(b), str(a)])

func gt(a: float, b: float, msg := "") -> void:
	checks += 1
	if not (a > b):
		_fail("FAIL: %s  (expected %s > %s)" % [msg, str(a), str(b)])

## Override to do per-test setup if needed.
func before() -> void:
	pass

## Override to release any non-RefCounted resources (e.g. Nodes) after a test.
func after() -> void:
	pass
