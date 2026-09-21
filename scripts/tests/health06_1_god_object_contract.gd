extends SceneTree

const RunStateScript := preload("res://scripts/core/run_state.gd")
const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")

var _failures: Array[String] = []


func _init() -> void:
	var run: RunState = RunStateScript.new()
	run.start_new("HEALTH06-1-FACADES")
	var crew_facade = run.get("_crew_run_facade")
	var grand_facade = run.get("_grand_casino_run_facade")
	var delivery_facade = run.get("_delivery_run_facade")
	_expect(crew_facade != null and crew_facade.get("trust_by_member") == run.crew_trust_by_member, "CH-26: CrewRunFacade does not own the compatibility state.")
	_expect(grand_facade != null and grand_facade.get("room_states") == run.grand_casino_room_states, "CH-26: GrandCasinoRunFacade does not own room state.")
	_expect(delivery_facade != null and delivery_facade.get("active_run") == run.active_delivery_run, "CH-26: DeliveryRunFacade does not own active delivery state.")
	run.crew_trust_by_member["crew_switch"] = 7
	_expect(run.crew_trust("crew_switch") == 7, "CH-26: crew facade compatibility path changed trust behavior.")
	var snapshot := run.to_dict()
	var restored: RunState = RunStateScript.new()
	restored.from_dict(snapshot)
	_expect(restored.crew_trust("crew_switch") == 7, "CH-26: facade-backed state did not round-trip.")
	var app = FoundationMainScript.new()
	_expect(app.get("_sealed_action_host") != null, "CH-26: Foundation did not construct the sealed host owner.")
	app.free()
	if _failures.is_empty():
		print("HEALTH06_1_GOD_OBJECT PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
