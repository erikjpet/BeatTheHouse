extends "res://scripts/tests/scenario_slot_layout_check.gd"

const CART := "punchline_raid_jitters_hide_cart"
const STEWARD := "punchline_raid_jitters_reopen_steward"

func _run() -> void:
	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV,
		ProjectSettings.globalize_path("res://.tmp/punchline_raid_move_check/empty_user.json"))
	DeveloperPlacementStoreScript.reload()
	var environment := _environment_for_map("small_underground_casino:club", "punchline_raid_jitters")
	var surface := EnvironmentPlacementScript.surface_map(environment)
	var validation := EnvironmentSlotBinderScript.validate_slot_map(surface)
	_check(bool(validation.get("ok", false)), "Raid slot authority must validate: %s" % str(validation.get("errors", [])))
	var observations: Dictionary = {}
	for row in [
		[CART, "", "punchline_raid_cart_work_1", "center", "", "floor_fixture"],
		[STEWARD, "punchline_raid_steward_arrival", "punchline_raid_reopen_steward", "background", "punchline_raid_jitters_lane_clear_position", "standing_person"],
	]:
		var before := _phase_binding(environment, row[0], row[1], row[3], "", row[5])
		var after := _phase_binding(environment, row[0], row[2], row[3], row[4], row[5])
		var before_rect := EnvironmentSlotBinderScript.rect_from_binding(before)
		var after_rect := EnvironmentSlotBinderScript.rect_from_binding(after)
		_check(before_rect.has_area() and after_rect.has_area(), "%s phases need physical geometry" % row[0])
		_check(str(before.get("slot_id", "")) != str(after.get("slot_id", "")), "%s authored move must leave its arrival slot" % row[0])
		_check(not before_rect.intersects(after_rect), "%s move must vacate its old footprint" % row[0])
		_check(str(before.get("placement_class", "")) == row[5] and str(after.get("placement_class", "")) == row[5], "%s retains physical class" % row[0])
		var key := "%s|%s|%s|%s" % [row[0], row[2], row[3], row[4]]
		_check(str(surface.get("scenario_instance_slot_ids", {}).get(key, "")) == str(after.get("slot_id", "")), "%s uses its exact authored phase endpoint" % row[0])
		observations[row[0]] = {"before": before.get("slot_id"), "after": after.get("slot_id")}
	print("PUNCHLINE_RAID_MOVE ", JSON.stringify({"failures": failures, "bindings": observations}))
	quit(0 if failures.is_empty() else 1)

func _phase_binding(environment: Dictionary, stable: String, anchor: String, zone: String, route_receipt: String, placement_class: String) -> Dictionary:
	var identity := "scenario::%s" % stable
	var semantic := {"owner_namespace": "scenario", "stable_object_id": stable, "label": stable,
		"zone_id": zone, "anchor_id": anchor, "authored_position_route_id": route_receipt,
		"visible": true, "enabled": true, "present": true}
	var result := EnvironmentSlotBinderScript.bind_scenario_visuals(environment, [{
		"identity": identity, "semantic": semantic, "actor": placement_class == "standing_person",
		"slot_family": "scenario", "placement_class": placement_class}])
	_check(bool(result.get("ok", false)), "%s phase binds: %s" % [stable, str(result.get("errors", []))])
	return _dict(result.get("slot_bindings", {}).get(identity, {}))
