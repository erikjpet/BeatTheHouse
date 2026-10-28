extends SceneTree

const Controller := preload("res://scripts/ui/environment_interaction_controller.gd")
const Binder := preload("res://scripts/core/environment_slot_binder.gd")
const Placement := preload("res://scripts/core/environment_placement.gd")
const Canvas := preload("res://scripts/ui/pixel_scene_canvas.gd")
const Host := preload("res://scripts/ui/foundation_main.gd")
const CASS := "event:chain06_cass_first_contact"
const KNUCKLES := "event:recruitment_knuckles"
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	_pure_cases()
	if not OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty(): await _captured()
	_finish()

func _environment() -> Dictionary:
	return {"id": "slot_collision_fixture", "archetype_id": "small_underground_casino", "current_layer_id": "club"}

func _actor(identity: String, slot: Dictionary) -> Dictionary:
	var binding := Binder._room_binding(identity, "standing_person", "event", slot)
	var rect := Binder.normalized_rect(Binder.rect_from_binding(binding))
	return {"object_id": identity, "object_type": "event", "source_id": identity.trim_prefix("event:"), "label": identity, "physical": true, "visual_type": "person", "visible": true, "interactive": true, "enabled": true, "presentation_mode": "room", "placement_class": "standing_person", "slot_family": "event", "slot_id": str(slot.id), "normalized_rect": rect, "focus_rect": rect.duplicate(true), "fixed_slot_geometry": true}

func _pure_cases() -> void:
	var environment := _environment()
	var slots: Array = []
	for slot in Placement.all_slots(Placement.surface_map(environment)):
		if str(slot.get("kind", "")) == "event" and str(slot.get("footprint_class", "")) == "standing_person": slots.append(slot)
	if not check(slots.size() >= 6, "authored Club has sufficient distinct actor slots"): return
	var pinned := [_actor("event:sealed_first", slots[0]), _actor(KNUCKLES, slots[1])]
	var live := [_actor(CASS, slots[1]), _actor("event:late_second", slots[1]), _actor("event:uncontested", slots[2])]
	var input_bytes := var_to_bytes([environment, pinned, live])
	var combined := Controller.append_unsealed_live_records(pinned, live, pinned, environment)
	check(combined.size() == 5 and _slot_map(combined).size() == 5, "all sealed and multiple live identities survive")
	check(_unique_slots(combined), "combined physical slots are unique")
	check(_find(combined, KNUCKLES) == pinned[1] and _find(combined, "event:sealed_first") == pinned[0], "sealed geometry and complete records remain exact")
	check(_find(combined, "event:uncontested") == live[2], "displaced actors cannot steal an uncontested live position")
	check(str(_find(combined, CASS).slot_id) != str(pinned[1].slot_id), "Cass relinquishes sealed Knuckles slot")
	var reversed := live.duplicate(true); reversed.reverse()
	check(_slot_map(Controller.append_unsealed_live_records(pinned, reversed, pinned, environment)) == _slot_map(combined), "multiple newcomer allocation is stable under input permutation")
	check(Controller.append_unsealed_live_records(combined, live, pinned, environment) == combined, "repeated composition does not append or move actors again")
	check(var_to_bytes([environment, pinned, live]) == input_bytes, "all input records and environment remain unchanged")
	var canvas := Canvas.new()
	var faulty: Array = pinned.duplicate(true); faulty.append_array(live)
	check(canvas.call("_objects_from_interactable_records", faulty).size() == 3, "existing Canvas duplicate-slot defense still rejects colliding records")
	check(canvas.call("_objects_from_interactable_records", combined).size() == 5, "corrected catalog reaches Canvas without actor loss")
	canvas.free()
	var tombstone := _actor("event:retired", slots[3])
	var sealed := pinned.duplicate(true); sealed.append(tombstone)
	var with_retired := live.duplicate(true); with_retired.append(tombstone)
	check(_find(Controller.append_unsealed_live_records(pinned, with_retired, sealed, environment), "event:retired").is_empty(), "sealed tombstone cannot be resurrected by live append")
	var departure := Controller.restore_live_presentation_fields([_actor(CASS, slots[1])], [], [])
	check(departure.is_empty(), "genuine absent live event remains retired before reconciliation")
	var too_many: Array = []
	for index in range(slots.size() + 1): too_many.append(_actor("event:excess_%02d" % index, slots[1]))
	var rejected := Controller.append_unsealed_live_records(pinned, too_many, pinned, environment)
	check(rejected.all(func(row): return str(row.get("presentation_mode", "")) == "overflow" and not row.has("normalized_rect")), "real authored capacity exhaustion fails closed without invented geometry")
	var routed := [_actor("event:routed", slots[1])]
	routed[0]["actor_route_stage"] = {"start_slot_id": str(slots[1].id), "end_slot_id": str(slots[2].id)}
	var route_live := [_actor(CASS, slots[2])]
	var routed_combined := Controller.append_unsealed_live_records(routed, route_live, routed, environment)
	check(str(_find(routed_combined, CASS).get("slot_id", "")) not in [str(slots[1].id), str(slots[2].id)], "projected actor reserves both route endpoints")
	check(_find(routed_combined, "event:routed") == routed[0], "sealed routed actor remains byte-equivalent")
	var fixed_slots := Placement.slots_for_family(Placement.surface_map(environment), "fixed")
	if not fixed_slots.is_empty():
		var fixed := _actor("event:sealed_fixed", fixed_slots[0])
		fixed["slot_family"] = "fixed"
		fixed["placement_class"] = str(fixed_slots[0].get("footprint_class", "standing_person"))
		var exact_live := fixed.duplicate(true); exact_live["object_id"] = "event:late_fixed"
		var fixed_before := var_to_bytes(fixed)
		var exact_rejected := Controller.append_unsealed_live_records([fixed], [exact_live], [fixed], environment)
		check(exact_rejected.all(func(row): return str(row.get("presentation_mode", "")) == "overflow"), "exact fixed conflict fails closed rather than relocating a fixed fixture")
		check(var_to_bytes(fixed) == fixed_before, "failed exact conflict preserves sealed source")
	facts["synthetic_mapping"] = _slot_map(combined)

func _captured() -> void:
	if not _install_bundle(): return
	var reference: Variant = SaveService.new().load_run("foundation_ui_autosave")
	if not check(reference is RunState, "official copied campaign save loads"): return
	var expected := _protected(reference)
	var should_have_cass := OS.get_environment("BTH_CASS_SLOT_CASE") != "departed"
	check(expected.action == (20 if should_have_cass else 24), "protected campaign action index is genuine fixture boundary")
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	app.autosave_slot_id = "foundation_ui_autosave"
	if check(app.load_foundation_run(), "normal Continue accepts campaign without replaying entry"):
		app.open_run_menu()
		for frame in range(3): await process_frame
		check(_equal(_protected(app.run_state), expected), "Continue preserves money/Crew/duties/debt/history/RNG")
		var before: Dictionary = app.run_state.to_save_snapshot()
		var publication: Dictionary = app.run_state.room_presentation_snapshot()
		var finalized: Dictionary = publication.get("finalized", {})
		var active_projection := not bool(finalized.get("inactive", true))
		var projected := {"ok": true, "records": []}
		if active_projection:
			projected = Controller.project_finalized_sequence_interaction_result(finalized.get("records", []), finalized)
		check(not should_have_cass or active_projection, "current Club fixture retains actual sealed projection")
		check(bool(projected.get("ok", false)), "authentic sealed projection remains valid")
		var catalog := Controller.prepare_room_catalog_at_boundary(app)
		_check_actors(app, catalog, projected.get("records", []), should_have_cass, "cold_initial")
		check(_slot_map(Controller.prepare_room_catalog_at_boundary(app)) == _slot_map(catalog), "repeat detached catalog has deterministic slots")
		check(app.run_state.to_save_snapshot() == before, "detached composition preserves full paused RunState snapshot")
		if should_have_cass and active_projection:
			var incomplete: Array = finalized.get("records", []).duplicate(true)
			if not incomplete.is_empty(): incomplete.pop_back()
			check(not bool(Controller.project_finalized_sequence_interaction_result(incomplete, finalized).get("ok", false)), "strict sealed coverage rejection remains enabled")
		app.save_service.wait_for_async_save()
		check(app.save_service.save_run(app.run_state, "foundation_ui_autosave") == OK, "normal private Save persists same campaign")
		var fresh: Variant = SaveService.new().load_run("foundation_ui_autosave")
		check(fresh is RunState and _equal(_protected(fresh), expected), "fresh service Save/restore preserves exact protected campaign")
		check(app.load_foundation_run(), "same-host Continue rebuilds after normal private Save")
		app.open_run_menu()
		for frame in range(3): await process_frame
		var rebuilt := app.room_catalog_snapshot()
		_check_actors(app, rebuilt, projected.get("records", []), should_have_cass, "saved_continue")
		check(_slot_map(rebuilt) == _slot_map(catalog), "warm and saved/cold rebuilds allocate identical physical slots")
		check(_equal(_protected(app.run_state), expected), "rebuild cannot replay choices/travel or alter finances/RNG")
		app.save_service.wait_for_async_save()
		_export_bundle(app)
	app.queue_free()
	for frame in range(2): await process_frame

func _check_actors(app: Variant, records: Array, projected: Array, present: bool, tag: String) -> void:
	check(_unique_slots(records), tag + " full catalog has unique physical slots")
	var cass := _find(records, CASS)
	var knuckles := _find(records, KNUCKLES)
	check(cass.is_empty() != present, tag + " Cass respects actual live membership")
	check(not present or not knuckles.is_empty(), tag + " eligible Knuckles survives")
	for row in projected:
		var actual := _find(records, str(row.get("object_id", "")))
		if actual.is_empty(): continue
		for field in ["slot_id", "normalized_rect", "focus_rect", "scenario_layout_authority_digest", "scenario_layout_authority_identity"]:
			check(_equal(actual.get(field), row.get(field)), tag + " retained sealed geometry/identity " + str(row.get("object_id", "")) + "/" + field)
	var converted: Array = app.environment_canvas.call("_objects_from_interactable_records", records)
	check(_find(converted, CASS).is_empty() != present and (knuckles.is_empty() or not _find(converted, KNUCKLES).is_empty()), tag + " eligible actors survive Canvas duplicate guard")
	check(_find(app.environment_canvas.foundation_scene_objects, CASS).is_empty() != present, tag + " actual rendered foundation agrees with detached catalog")
	if present:
		check(str(cass.slot_id) != str(knuckles.slot_id), tag + " Cass and Knuckles own distinct slots")
		check(not _rect(cass.get("normalized_rect", {})).intersects(_rect(knuckles.get("normalized_rect", {}))), tag + " actor interaction footprints do not overlap")
	facts[tag] = {"slots": _slot_map(records), "Cass": cass, "Knuckles": knuckles, "converted_count": converted.size()}

func _find(records: Array, identity: String) -> Dictionary:
	for row in records:
		if str(row.get("object_id", row.get("id", ""))) == identity: return row
	return {}

func _slot_map(records: Array) -> Dictionary:
	var result := {}
	for row in records:
		if bool(row.get("visible", true)) and str(row.get("presentation_mode", "room")) == "room" and not str(row.get("slot_id", "")).is_empty(): result[str(row.get("object_id", row.get("id", "")))] = str(row.slot_id)
	return result

func _unique_slots(records: Array) -> bool:
	var occupied := {}
	for identity in _slot_map(records):
		var slot_id: String = _slot_map(records)[identity]
		if occupied.has(slot_id): return false
		occupied[slot_id] = identity
	return true

func _rect(value: Variant) -> Rect2:
	if value is Rect2: return value
	if typeof(value) != TYPE_DICTIONARY: return Rect2()
	return Rect2(float(value.get("x", 0)), float(value.get("y", 0)), float(value.get("w", 0)), float(value.get("h", 0)))

func _protected(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "Crew": run.crew_reputation(), "crew_state": run.to_action_snapshot_without_world().get("crew_state", {}).duplicate(true), "delivery": run.active_delivery_run.duplicate(true), "debt": run.debt.duplicate(true), "story": run.story_log.duplicate(true), "inventory": run.inventory.duplicate(true), "rng": run.rng_state, "action": run.numbers_state.action_index, "flags": run.story_flags.duplicate(true)}

func _install_bundle() -> bool:
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	if not check(not bundle.is_empty() and OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_absolute_path(), "private fixture and persistence root required"): return false
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	var user := ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(saves); DirAccess.make_dir_recursive_absolute(user)
	for name in ["foundation_ui_autosave.json", "foundation_ui_autosave.json.bak"]:
		if FileAccess.file_exists(bundle.path_join(name)) and not check(not FileAccess.file_exists(saves.path_join(name)) and DirAccess.copy_absolute(bundle.path_join(name), saves.path_join(name)) == OK, "install private save companion"): return false
	if not check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"), user.path_join(".crew_host_authority_v1")) == OK, "install copied authority key"): return false
	for pair in [["profile_inventory.json", "BTH_PROFILE_INVENTORY_PATH"], ["meta_collection.json", "BTH_META_COLLECTION_PATH"], ["settings.json", "BTH_USER_SETTINGS_PATH"]]:
		for suffix in ["", ".bak"]:
			var source := bundle.path_join(str(pair[0]) + suffix)
			if FileAccess.file_exists(source) and not check(DirAccess.copy_absolute(source, OS.get_environment(pair[1]) + suffix) == OK, "install copied private profile"): return false
	return true

func _export_bundle(app: Variant) -> void:
	var target := OS.get_environment("BTH_TARGET_OUTPUT").get_base_dir().path_join("roundtrip-bundle")
	DirAccess.make_dir_recursive_absolute(target)
	for suffix in ["", ".bak"]:
		var source: String = app.save_service.run_save_path("foundation_ui_autosave") + suffix
		if FileAccess.file_exists(source): check(DirAccess.copy_absolute(source, target.path_join("foundation_ui_autosave.json" + suffix)) == OK, "export private roundtrip save")
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path("user://.crew_host_authority_v1"), target.path_join(".crew_host_authority_v1")) == OK, "export existing private authority companion")
	for pair in [["profile_inventory.json", "BTH_PROFILE_INVENTORY_PATH"], ["meta_collection.json", "BTH_META_COLLECTION_PATH"], ["settings.json", "BTH_USER_SETTINGS_PATH"]]:
		var source := OS.get_environment(pair[1])
		if FileAccess.file_exists(source): check(DirAccess.copy_absolute(source, target.path_join(pair[0])) == OK, "export existing private profile companion")

func _equal(left: Variant, right: Variant) -> bool:
	if typeof(left) in [TYPE_INT, TYPE_FLOAT] and typeof(right) in [TYPE_INT, TYPE_FLOAT]: return left == right
	if typeof(left) != typeof(right): return false
	if typeof(left) == TYPE_DICTIONARY:
		if left.size() != right.size(): return false
		for key in left:
			if not right.has(key) or not _equal(left[key], right[key]): return false
		return true
	if typeof(left) == TYPE_ARRAY:
		if left.size() != right.size(): return false
		for index in range(left.size()):
			if not _equal(left[index], right[index]): return false
		return true
	return left == right

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok

func _finish() -> void:
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty(): FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts, "scope": "Synthetic detached physical-catalog contracts and optional actual campaign Continue/Save/cold actor regression; no event choices, recruitment, count/eligibility edits or travel."}, "\t"))
	print("SEALED_LIVE_ACTOR_SLOT checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
