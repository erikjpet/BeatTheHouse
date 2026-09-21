extends SceneTree

const EnvironmentRuntimeSchedulerScript := preload("res://scripts/core/environment_runtime_scheduler.gd")
const CageEconomyModelScript := preload("res://scripts/core/cage_economy_model.gd")
const CageAtmViewModelScript := preload("res://scripts/ui/cage_atm_view_model.gd")
const PlatformServicesScript := preload("res://scripts/core/platform_services.gd")
const TutorialFlowScript := preload("res://scripts/core/tutorial_flow.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_diagnostics()
	_check_atm_contract()
	_check_platform_contract()
	_check_legacy_tutorial_migration()
	if failures.is_empty():
		print("HEALTH06_1_DEAD_CODE PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_diagnostics() -> void:
	var scheduler := EnvironmentRuntimeSchedulerScript.new()
	scheduler.replace("room", [{"game_id": "slot", "state_key": "one", "due_msec": 10}], 0)
	var snapshot := scheduler.debug_snapshot("room")
	_expect(not snapshot.has("stale_pop_count"), "CH-17: scheduler still exposes a permanently-zero health signal.")
	_expect(str(scheduler.take_due("room", 10).get("game_id", "")) == "slot", "CH-17: removing the dead diagnostic changed due delivery.")


func _check_atm_contract() -> void:
	var preview := CageEconomyModelScript.borrow_preview(100, 50)
	_expect(bool(preview.get("ok", false)) and int(preview.get("cash_received", 0)) == 50 and int(preview.get("debt_after", 0)) == 150, "CH-19: removing the zero fee changed borrowing economics.")
	var run_state := RunStateScript.new()
	run_state.bankroll = 80
	var status := run_state.grand_casino_atm_status()
	var view := CageAtmViewModelScript.build(run_state)
	_expect(not status.has("origination_fee"), "CH-19: RunState status still advertises an unimplemented fee.")
	_expect(not view.has("origination_fee"), "CH-19: ATM view still advertises an unimplemented fee.")


func _check_platform_contract() -> void:
	var service := PlatformServicesScript.new()
	var result := service.unlock_achievement("health_fixture")
	_expect(bool(result.get("ok", false)) and str(result.get("achievement_id", "")) == "health_fixture", "CH-18: comment cleanup changed the local achievement adapter.")


func _check_legacy_tutorial_migration() -> void:
	var run_state := RunStateScript.new()
	run_state.challenge_config = {"id": TutorialFlowScript.CHALLENGE_ID, "tutorial": true}
	run_state.current_environment = {
		"id": "legacy_tutorial_underground",
		"archetype_id": TutorialFlowScript.UNDERGROUND_CASINO_ID,
		"game_states": {"blackjack": {"barred": true, "hands_played": 1}},
	}
	run_state.narrative_flags["tutorial_caught_continue"] = true
	run_state.narrative_flags["tutorial_lessons_completed"] = {"tutorial_blackjack_count_all": true}
	_expect(TutorialFlowScript.repair_legacy_tutorial_save(run_state), "CH-20: reachable 0.5.1 tutorial save was not repaired.")
	var table: Dictionary = run_state.current_environment.get("game_states", {}).get("blackjack", {})
	_expect(not bool(table.get("barred", true)) and int(table.get("hands_played", 0)) >= 2, "CH-20: retained migration did not restore the playable boundary.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
