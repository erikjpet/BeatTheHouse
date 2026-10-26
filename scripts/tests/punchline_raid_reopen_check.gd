extends "res://scripts/tests/scenario_slot_layout_check.gd"

const TASK := "scenario::punchline_raid_jitters_task_4"
const BINS := "scenario::punchline_raid_jitters_clear_bins"
const EXIT := "scenario::punchline_raid_jitters_safe_exit"

func _run() -> void:
	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV,
		ProjectSettings.globalize_path("res://.tmp/punchline_raid_reopen_check/empty_user.json"))
	DeveloperPlacementStoreScript.reload()
	var surface := EnvironmentPlacementScript.surface_map(_environment_for_map("small_underground_casino:club", "punchline_raid_jitters"))
	_check(bool(EnvironmentSlotBinderScript.validate_slot_map(surface).get("ok", false)), "Raid reopening host authority validates")
	# Work4 hides the cart and despawns the steward. The surviving bins and safe
	# exit must expose separate success and abandonment controls on room cards.
	var state := {"actors": {}, "scene_objects": {
		TASK: _semantic("punchline_raid_jitters_task_4", "Reopen Safe Floor", "center", "task_station"),
		BINS: _semantic("punchline_raid_jitters_clear_bins", "Layer 2 clear bins", "service_lane", "storage"),
		EXIT: _semantic("punchline_raid_jitters_safe_exit", "Clear exit", "exit_lane", "exit"),
	}, "interactions": {
		TASK: {"available_actions": [{"id": "reopen_safe_floor", "label": "Reopen Safe Floor"}], "enabled": true},
		EXIT: {"available_actions": [{"id": "refuse_punchline_raid_jitters", "label": "Abandon The Raid Response"}], "enabled": true},
	}}
	var warnings: Array=[]
	var errors: Array=[]
	var attached := ScenarioLayoutResolverScript._attach_abstract_actions_to_room_objects(state, surface, [], warnings, errors)
	_check(errors.is_empty(), "Surviving reopening fixture must attach without errors")
	var bins_actions := _array(_dict(_dict(attached.get("interactions", {})).get(BINS, {})).get("available_actions", []))
	var exit_actions := _array(_dict(_dict(attached.get("interactions", {})).get(EXIT, {})).get("available_actions", []))
	_check(not bins_actions.is_empty() and str(_dict(bins_actions[0]).get("id", "")) == "reopen_safe_floor", "Reopen must be the bins card's visible primary action")
	_check(exit_actions.size() == 1 and str(_dict(exit_actions[0]).get("id", "")) == "refuse_punchline_raid_jitters", "Safe exit must retain abandonment without hiding success behind it")
	if not bins_actions.is_empty():
		_check(str(_dict(bins_actions[0]).get("attached_stable_object_id", "")) == "punchline_raid_jitters_task_4", "Attached success retains the original objective authority")
	var hidden := state.duplicate(true)
	hidden.scene_objects[BINS]["visible"] = false
	var hidden_errors: Array=[]
	var hidden_attached := ScenarioLayoutResolverScript._attach_abstract_actions_to_room_objects(hidden, surface, [], [], hidden_errors)
	_check(not hidden_errors.is_empty(), "Unavailable exact host must fail closed")
	_check(_array(_dict(_dict(hidden_attached.get("interactions", {})).get(EXIT, {})).get("available_actions", [])).size() == 1, "Missing bins must not fall back to the abandonment exit")
	print("PUNCHLINE_RAID_REOPEN ", JSON.stringify({"failures": failures, "bins_actions": bins_actions, "exit_actions": exit_actions}))
	quit(0 if failures.is_empty() else 1)

func _semantic(stable: String, label: String, zone: String, role: String) -> Dictionary:
	return {"owner_namespace": "scenario", "stable_object_id": stable, "label": label, "zone_id": zone, "role": role, "present": true, "visible": true, "enabled": true}
