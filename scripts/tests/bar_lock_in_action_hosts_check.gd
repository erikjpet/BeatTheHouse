extends "res://scripts/tests/scenario_slot_layout_check.gd"

const PREFIX := "scenario::bar_lock_in_"
const PHASES := [
	["Check Shutter Latch", "left", "check_shutter_latch", "locked_shutters"],
	["Inspect Cellar Hatch", "right", "inspect_cellar_hatch", "cellar_hatch"],
	["Earn Host Token", "foreground", "earn_host_token", "lockin_host"],
	["Complete Private Task", "center", "complete_private_task", "private_bench"],
	["Signal Reopening", "background", "signal_reopening", "lockin_host"],
]

func _run() -> void:
	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV,
		ProjectSettings.globalize_path("res://.tmp/bar_lock_in_action_hosts_check/empty_user.json"))
	DeveloperPlacementStoreScript.reload()
	var surface := EnvironmentPlacementScript.surface_map(_environment_for_map("bar", "bar_lock_in"))
	_check(bool(EnvironmentSlotBinderScript.validate_slot_map(surface).get("ok", false)), "Lock In slot authority validates")
	for i in range(PHASES.size()):
		var phase: Array = PHASES[i]
		var task := PREFIX + "task_%d" % i
		var host := PREFIX + str(phase[3])
		var state := {"actors": {
			PREFIX + "lockin_host": _semantic("lockin_host", "Lock-in host", "right"),
			PREFIX + "afterhours_regular": _semantic("afterhours_regular", "After-hours regular", "background"),
		}, "scene_objects": {
			PREFIX + "locked_shutters": _semantic("locked_shutters", "Locked front shutters", "right"),
			PREFIX + "cellar_hatch": _semantic("cellar_hatch", "Quiet cellar hatch", "foreground"),
			PREFIX + "private_bench": _semantic("private_bench", "After-hours task bench", "service_lane"),
			PREFIX + "safe_exit": _semantic("safe_exit", "Marked clean exit", "exit_lane"),
			task: _semantic("task_%d" % i, str(phase[0]), str(phase[1])),
		}, "interactions": {
			task: {"available_actions": [{"id": phase[2], "label": phase[0]}], "enabled": true},
			PREFIX + "safe_exit": {"available_actions": [{"id": "refuse_bar_lock_in", "label": "Refuse the task"}], "enabled": true},
		}}
		# Work 4 retires the regular and hides the shutters. The surviving host
		# carries the final signal; attaching to the shutter would reject work 3.
		if i == 4:
			state.actors[PREFIX + "afterhours_regular"]["present"] = false
			state.scene_objects[PREFIX + "locked_shutters"]["visible"] = false
		var errors: Array = []
		var attached := ScenarioLayoutResolverScript._attach_abstract_actions_to_room_objects(state, surface, [], [], errors)
		_check(errors.is_empty(), "Phase %d attaches without errors" % i)
		var actions := _array(_dict(_dict(attached.get("interactions", {})).get(host, {})).get("available_actions", []))
		_check(not actions.is_empty() and str(_dict(actions[0]).get("id", "")) == str(phase[2]), "Phase %d primary action belongs to its named physical host" % i)
		if not actions.is_empty():
			_check(str(_dict(actions[0]).get("attached_stable_object_id", "")) == "bar_lock_in_task_%d" % i, "Phase %d preserves original task authority" % i)
		_check(_array(_dict(_dict(attached.get("interactions", {})).get(PREFIX + "safe_exit", {})).get("available_actions", [])).size() == 1, "Phase %d keeps refusal separate" % i)
		var hidden: Dictionary = state.duplicate(true)
		if hidden.actors.has(host): hidden.actors[host]["visible"] = false
		else: hidden.scene_objects[host]["visible"] = false
		var hidden_errors: Array = []
		var hidden_attached := ScenarioLayoutResolverScript._attach_abstract_actions_to_room_objects(hidden, surface, [], [], hidden_errors)
		_check(not hidden_errors.is_empty(), "Phase %d missing exact host fails closed" % i)
		var leaked := false
		for value in _dict(hidden_attached.get("interactions", {})).values():
			for action in _array(_dict(value).get("available_actions", [])):
				if str(_dict(action).get("id", "")) == str(phase[2]): leaked = true
		_check(not leaked, "Phase %d must not move to an unrelated fallback" % i)
	print("BAR_LOCK_IN_ACTION_HOSTS ", JSON.stringify({"phases": PHASES.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _semantic(stable: String, label: String, zone: String) -> Dictionary:
	return {"owner_namespace": "scenario", "stable_object_id": "bar_lock_in_" + stable, "label": label, "zone_id": zone, "present": true, "visible": true, "enabled": true}
