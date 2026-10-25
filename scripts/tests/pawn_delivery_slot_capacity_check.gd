extends SceneTree

const Placement := preload("res://scripts/core/environment_placement.gd")
const Binder := preload("res://scripts/core/environment_slot_binder.gd")

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _run() -> void:
	# These four physical identities coexist in the captured failed courier
	# arrival. The authored scenario uses separate scenario-family slots.
	var entries: Array = []
	for identity in ["crew::package_handoff", "crew_presence:crew_mags", "event:chatty_clerk", "event:town_rumor_staff"]:
		entries.append({"object_id": identity, "object_type": "event", "family": "event", "placement_class": "standing_person"})
	for scenario_id in ["", "pawn_shop_sals_mood"]:
		var environment := {"archetype_id": "pawn_shop", "scenario_id": scenario_id}
		var surface := Placement.surface_map(environment)
		_check(bool(Binder.validate_slot_map(surface).get("ok", false)), "Pawn authored slot map is invalid")
		var result := Binder.bind_base_layout(environment, entries)
		_check(bool(result.get("ok", false)), "Four concurrent Pawn people rejected: %s" % str(result.get("errors", [])))
		var bindings: Dictionary = result.get("slot_bindings", {})
		_check(bindings.size() == entries.size(), "A concurrent person lost its physical binding")
		var slots: Array = []
		var rectangles: Array[Rect2] = []
		for entry in entries:
			var binding: Dictionary = bindings.get(entry["object_id"], {})
			var slot_id := str(binding.get("slot_id", ""))
			_check(not slot_id.is_empty() and not slots.has(slot_id), "People share or lack an authored slot")
			slots.append(slot_id)
			var rect := Binder.rect_from_binding(binding)
			_check(rect.size.x >= 44 and rect.size.y >= 44, "Person target is undersized")
			for previous in rectangles:
				_check(not rect.intersects(previous), "Concurrent person targets overlap")
			rectangles.append(rect)
		var repeated := Binder.bind_base_layout(environment, entries)
		_check(result.get("binding_digest", "") != "" and result.get("binding_digest") == repeated.get("binding_digest"), "Unchanged membership rebound nondeterministically")
		var over_capacity := entries.duplicate(true)
		over_capacity.append({"object_id": "event:unmapped_fifth_person", "object_type": "event", "family": "event", "placement_class": "standing_person"})
		_check(not bool(Binder.bind_base_layout(environment, over_capacity).get("ok", true)), "Unauthored overflow stopped failing closed")
	if failures.is_empty():
		print("PAWN_DELIVERY_SLOT_CAPACITY PASS checks=", checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
