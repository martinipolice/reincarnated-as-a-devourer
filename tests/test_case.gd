extends RefCounted
## Base for the test files in this folder (see run_tests.gd). Methods named
## test_* run in order, each with Save.data backed up and put back after,
## so no test leaks into the next. Checks record failures instead of
## stopping, so one run reports everything that broke.

const MAIN_SCENE := "res://scenes/main.tscn"

var tree: SceneTree
var failures: Array[String] = []
var current := ""
var _save_backup: Dictionary


func check(condition: bool, what: String) -> void:
	if not condition:
		failures.append("%s: %s" % [current, what])


func check_eq(actual: Variant, expected: Variant, what: String) -> void:
	check(actual == expected, "%s: expected %s, got %s" % [what, expected, actual])


func check_near(actual: float, expected: float, tolerance: float, what: String) -> void:
	check(absf(actual - expected) <= tolerance, "%s: expected %.3f, got %.3f" % [what, expected, actual])


func before_each() -> void:
	_save_backup = Save.data.duplicate(true)


func after_each() -> void:
	Save.data = _save_backup
	Save.resume = false
	tree.paused = false


## A fresh run of the main scene, or a resumed one from Save.data.journey.
func start_run(resume := false) -> Node:
	Save.resume = resume
	var main: Node = load(MAIN_SCENE).instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	return main


func end_run(main: Node) -> void:
	tree.paused = false
	main.queue_free()
	await tree.process_frame
