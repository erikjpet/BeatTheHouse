extends "res://scripts/tests/scenario_slot_layout_check.gd"

const LECTERN_ID := "punchline_open_mic_night_signup_lectern"
const MOVED_ANCHOR := "punchline_open_mic_lectern_work_1"


func _run() -> void:
	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV,
		ProjectSettings.globalize_path("res://.tmp/open_mic_lectern_move_check/empty_user.json"))
	DeveloperPlacementStoreScript.reload()
	var environment := _environment_for_map("small_underground_casino:club", "punchline_open_mic_night")
	var surface := EnvironmentPlacementScript.surface_map(environment)
	var validation := EnvironmentSlotBinderScript.validate_slot_map(surface)
	_check(bool(validation.get("ok", false)), "Open Mic slot authority must validate: %s" % str(validation.get("errors", [])))
	var before := _lectern_binding(environment, "")
	var moved := _lectern_binding(environment, MOVED_ANCHOR)
	var before_rect := EnvironmentSlotBinderScript.rect_from_binding(before)
	var moved_rect := EnvironmentSlotBinderScript.rect_from_binding(moved)
	_check(before_rect.has_area() and moved_rect.has_area(), "Both lectern phases need physical geometry")
	_check(str(before.get("slot_id", "")) != str(moved.get("slot_id", "")),
		"The authored lectern move must not reuse its arrival slot")
	_check(not before_rect.intersects(moved_rect), "Moving the lectern must vacate its previous footprint")
	_check(str(before.get("placement_class", "")) == "floor_fixture" and str(moved.get("placement_class", "")) == "floor_fixture",
		"The move must retain the lectern's physical class")
	var position_key := "%s|%s|center|" % [LECTERN_ID, MOVED_ANCHOR]
	_check(str(surface.get("scenario_instance_slot_ids", {}).get(position_key, "")) == str(moved.get("slot_id", "")),
		"Moved geometry must come from its exact authored phase slot")
	print("OPEN_MIC_LECTERN_MOVE ", JSON.stringify({"failures": failures, "arrival_slot": before.get("slot_id"), "moved_slot": moved.get("slot_id")}))
	quit(0 if failures.is_empty() else 1)


func _lectern_binding(environment: Dictionary, anchor: String) -> Dictionary:
	var identity := "scenario::%s" % LECTERN_ID
	var semantic := {"owner_namespace": "scenario", "stable_object_id": LECTERN_ID,
		"label": "Open-mic signup lectern", "zone_id": "center", "anchor_id": anchor,
		"visible": true, "enabled": true, "present": true}
	var result := EnvironmentSlotBinderScript.bind_scenario_visuals(environment, [{
		"identity": identity, "semantic": semantic, "actor": false,
		"slot_family": "scenario", "placement_class": "floor_fixture"}])
	_check(bool(result.get("ok", false)), "Lectern phase must bind: %s" % str(result.get("errors", [])))
	return _dict(result.get("slot_bindings", {}).get(identity, {}))
