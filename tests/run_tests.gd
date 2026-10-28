extends SceneTree
## Runs every tests/test_*.gd headless and exits non-zero on any failure:
##   godot --headless --path . -s res://tests/run_tests.gd [-- name_filter]
## Untyped and loading tests at runtime on purpose: -s compiles this file
## before the autoloads exist. Running under -s also keeps Save off disk.
## A script error inside a test aborts it silently, so engine errors are
## caught by a Logger and fail the test that raised them.


class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		errors.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> Array[String]:
		_mutex.lock()
		var taken := errors.duplicate()
		errors.clear()
		_mutex.unlock()
		return taken


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var save: Node = root.get_node("Save")
	if save.persistent():
		push_error("Tests would write the real save; aborting.")
		quit(2)
		return
	root.get_node("Settings").data.hints = false
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var only := ""
	if not OS.get_cmdline_user_args().is_empty():
		only = OS.get_cmdline_user_args()[0]
	var files := Array(DirAccess.get_files_at("res://tests")).filter(func(f: String) -> bool:
		return f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd" and (only == "" or only in f))
	files.sort()
	var passed := 0
	var failed_tests := 0
	var failed: Array[String] = []
	var started := Time.get_ticks_msec()
	for file: String in files:
		var case = load("res://tests/" + file).new()
		case.tree = self
		var names := []
		for method: Dictionary in case.get_method_list():
			if method.name.begins_with("test_"):
				names.append(method.name)
		for test_name: String in names:
			case.current = "%s %s" % [file.get_basename(), test_name]
			var before: int = case.failures.size()
			catcher.take()
			await case.before_each()
			await case.call(test_name)
			await case.after_each()
			for error in catcher.take():
				case.failures.append("%s: error: %s" % [case.current, error])
			if case.failures.size() == before:
				passed += 1
			else:
				failed_tests += 1
				failed.append_array(case.failures.slice(before))
	OS.remove_logger(catcher)
	for line in failed:
		print("FAIL ", line)
	print("%d passed, %d failed in %.1f s" % [passed, failed_tests, (Time.get_ticks_msec() - started) / 1000.0])
	quit(1 if failed_tests > 0 else 0)
