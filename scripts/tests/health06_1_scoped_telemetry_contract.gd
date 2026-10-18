extends SceneTree

const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const NullPerfSinkScript := preload("res://scripts/ui/null_perf_sink.gd")

class RecordingSink:
	extends RefCounted
	var records: Array = []
	func is_live() -> bool:
		return true
	func begin_foundation_frame() -> void:
		pass
	func record_foundation_subsystem_usec(name: String, elapsed_usec: int) -> void:
		records.append({"name": name, "elapsed_usec": elapsed_usec})

var _calls := 0
var _failures: Array[String] = []


func _init() -> void:
	var app = FoundationMainScript.new()
	var null_sink = NullPerfSinkScript.new()
	_expect(not null_sink.is_live(), "CH-16: no-op sink reports itself live.")
	app.set("_foundation_perf_sink", null_sink)
	app.call("_timed", "fixture", Callable(self, "_count_call"))
	_expect(_calls == 1, "CH-16: disabled timed operation did not run exactly once.")
	var live_sink := RecordingSink.new()
	app.set("_foundation_perf_sink", live_sink)
	app.call("_timed", "fixture", Callable(self, "_count_call"))
	_expect(_calls == 2, "CH-16: enabled timed operation did not run exactly once.")
	_expect(live_sink.records.size() == 1 and str(live_sink.records[0].get("name", "")) == "fixture", "CH-16: live sink did not receive one scoped record.")
	app.free()
	if _failures.is_empty():
		print("HEALTH06_1_SCOPED_TELEMETRY PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _count_call() -> void:
	_calls += 1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
