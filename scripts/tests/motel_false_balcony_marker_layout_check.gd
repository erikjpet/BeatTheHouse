extends SceneTree

const Host := preload("res://scripts/ui/foundation_main.gd")
const Placement := preload("res://scripts/core/environment_placement.gd")
const Binder := preload("res://scripts/core/environment_slot_binder.gd")
const Store := preload("res://scripts/core/developer_placement_store.gd")
const Controller := preload("res://scripts/ui/environment_interaction_controller.gd")
const MARKER := "scenario::motel_stakeout_aftermath_observers_misdirected"
const SLOT := "scenario.local_ground_marker_1"
const POSITION := Vector2(124, 278)
const BOARD := Rect2(0, 0, 900, 430)
var checks := 0
var failures: Array[String] = []
var facts := {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for key in ["BTH_DISTRIBUTION_DATA_ROOT", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH", "BTH_TARGET_OUTPUT", Store.USER_PATH_ENV, "BTH_VIS027_BASELINE_PLACEMENT", "BTH_CAPTURED_FIXTURE"]:
		if not check(OS.get_environment(key).is_absolute_path(), "isolated absolute persistence/input path required: " + key):
			_finish(); return
	Store.reload()
	_check_data_and_override_contract()
	if not _install_bundle():
		_finish(); return
	var reference: Variant = SaveService.new().load_run("foundation_ui_autosave")
	if not check(reference is RunState, "official unchanged copied save loads"):
		_finish(); return
	var expected := _protected(reference)
	check(reference.bankroll == 50 and reference.suspicion_level() == 0, "actual L fixture retains50cash/Heat0")
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	app.autosave_slot_id = "foundation_ui_autosave"
	if check(app.load_foundation_run(), "normal host Continue publishes exact scenario under current authority"):
		for frame in range(3): await process_frame
		# Trusted restore replays the causal journal and deliberately drops only
		# one-shot presentation delivery bookkeeping; it never re-emits effects.
		# ScenarioEngine._rebuild_receipted_semantic_mutations owns this behavior.
		facts["restore_presentation_delivery_counts"] = [reference.current_environment.get("scenario_sequence_state", {}).get("transition_delivery_receipts", []).size(), app.run_state.current_environment.get("scenario_sequence_state", {}).get("transition_delivery_receipts", []).size()]
		check(app.run_state.current_environment.get("scenario_sequence_state", {}).get("semantic_state", {}).get("transition_queue", []).is_empty(), "Continue never replays consumed one-shot presentation transitions")
		facts["initial_continue_difference_paths"] = _difference_paths(expected, _protected(app.run_state))
		check(_equal(_protected(app.run_state), expected), "Continue preserves complete protected gameplay/receipts/RNG")
		if OS.get_environment("BTH_VIS027_CASE") == "before":
			var choice_host := {}
			var choice := {}
			for record in app.room_catalog_snapshot():
				for action in record.get("scenario_sequence_actions", []):
					if str(action.get("id", "")) == "motel_stakeout_resolve_b":
						choice_host = record; choice = action
			if check(not choice.is_empty(), "actual pre-choice catalog exposes Observers misdirected"):
				var prior_receipts := _receipt_count(app.run_state)
				check(app._activate_scenario_sequence_action(choice_host, choice), "normal authored deferred callback accepts the one requested diagnostic choice")
				for frame in range(4): await process_frame
				check(_receipt_count(app.run_state) == prior_receipts + 1, "authored outcome adds exactly one command receipt")
				check(app.run_state.current_environment.get("scenario_sequence_state", {}).get("resolved_outcomes", []) == ["observers_misdirected"], "normal callback reaches exact aftermath once")
				check(app.run_state.bankroll == reference.bankroll and app.run_state.rng_state == reference.rng_state, "authored choice does not charge or reroll")
				expected = _protected(app.run_state)
		app.open_run_menu()
		for frame in range(3): await process_frame
		_check_marker(app, "initial")
		var before := app.run_state.to_save_snapshot()
		var records := Controller.prepare_room_catalog_at_boundary(app)
		check(_equal(app.run_state.to_save_snapshot(), before), "repeated reader/catalog composition leaves complete paused state unchanged")
		check(_record(records, MARKER).get("slot_id", "") == SLOT, "exact stable scenario binding retained")
		var publication := app.run_state.room_presentation_snapshot()
		var finalized: Dictionary = publication.get("finalized", {})
		check(not bool(finalized.get("inactive", true)), "authentic scenario presentation remains sealed")
		var incomplete: Array = finalized.get("records", []).duplicate(true)
		if not incomplete.is_empty(): incomplete.pop_back()
		check(not bool(Controller.project_finalized_sequence_interaction_result(incomplete, finalized).get("ok", false)), "strict missing sealed member rejection remains intact")
		app.save_service.wait_for_async_save()
		check(app.save_service.save_run(app.run_state, "vis027_roundtrip") == OK, "official private Save accepts corrected geometry")
		var fresh: Variant = SaveService.new().load_run("vis027_roundtrip")
		check(fresh is RunState and _equal(_protected(fresh), expected), "fresh SaveService preserves gameplay and exactly-once outcome receipts")
		app.autosave_slot_id = "vis027_roundtrip"
		check(app.load_foundation_run(), "same-host Continue accepts corrected private save")
		app.open_run_menu()
		for frame in range(3): await process_frame
		_check_marker(app, "saved_continue")
		check(_equal(_protected(app.run_state), expected), "Save/Continue never replays accepted outcome or changes protected campaign")
		facts["protected"] = {"cash":app.run_state.bankroll, "heat":app.run_state.suspicion_level(), "receipts":_receipt_count(app.run_state), "fingerprint":JSON.stringify(expected).sha256_text()}
		app.save_service.wait_for_async_save()
	app.queue_free()
	for frame in range(2): await process_frame
	_finish()

func _check_data_and_override_contract() -> void:
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BTH_VIS027_BASELINE_PLACEMENT")))
	var after: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Store.PROJECT_PATH))
	var old_positions: Dictionary = before.rooms.motel.scenario_layouts.motel_stakeout.slot_positions
	check(old_positions[SLOT] == [788.0, 176.0], "exact shipped baseline retained provisional right-side coordinate")
	old_positions[SLOT] = [POSITION.x, POSITION.y]
	check(before == after, "only one exact Motel scenario position changes; all other data/keysets remain identical")
	var env := {"id":"vis027_motel", "archetype_id":"motel", "scenario_id":"motel_stakeout", "scenario_state":{"id":"motel_stakeout"}}
	check(Store.user_slot_overrides(env).is_empty(), "private baseline has no machine-local user placement")
	var surface := Placement.surface_map(env)
	check(bool(Binder.validate_slot_map(surface).get("ok", false)), "effective full scenario slot map validates")
	var marker := _slot(surface, SLOT)
	check(marker.pos == [POSITION.x, POSITION.y] and marker.scenario_zone_ids == ["left"], "authored left semantic contract agrees with effective exact placement")
	var marker_rect := _array_rect(marker.hit_rect)
	check(BOARD.encloses(marker_rect) and marker_rect.end.x < BOARD.get_center().x, "complete marker target stays in left side and inside board")
	for other in Placement.all_slots(surface):
		if str(other.get("id", "")) != SLOT:
			check(not marker_rect.intersects(_array_rect(other.get("hit_rect", []))), "marker avoids shared/exact/runtime slot " + str(other.get("id", "")))
	check(_slot(surface, "scenario.local_standing_person_1").pos == [276.0,414.0] and _slot(surface, "scenario.local_standing_person_2").pos == [700.0,414.0], "qualified VIS020 standing actor positions remain unchanged")
	var previous := Store.capture_user_room_state(env)
	check(bool(Store.save_position(env, "slot_positions", SLOT, Vector2(200,260)).get("ok", false)), "explicit private user placement remains supported")
	check(_slot(Placement.surface_map(env), SLOT).pos == [200.0,260.0], "machine-local user placement still wins over shipped project position")
	check(bool(Store.restore_user_room_state(previous).get("ok", false)), "private user placement test restores prior authoring state")
	check(_slot(Placement.surface_map(env), SLOT).pos == [POSITION.x,POSITION.y], "restored user precedence returns to the corrected project default")

func _check_marker(app: Variant, tag: String) -> void:
	var records: Array = app.room_catalog_snapshot()
	var marker := _record(records, MARKER)
	check(not marker.is_empty(), tag + " authored aftermath marker is present")
	check(str(marker.get("slot_id", "")) == SLOT and str(marker.get("slot_family", "")) == "scenario", tag + " marker keeps stable exact scenario slot/family")
	var layout: Dictionary = app.environment_canvas.current_view_snapshot().get("object_layout", {})
	var rendered := _record(layout.get("objects", []), MARKER)
	var rect := _rect(rendered.get("rect", {}))
	var label := _rect(rendered.get("label_rect", {}))
	var hit := _rect(rendered.get("interaction_rect", {}))
	check(not rendered.is_empty() and rect.get_center().x < 450, tag + " actual Canvas places marker on left")
	check(BOARD.encloses(rect) and BOARD.encloses(label) and label.has_area(), tag + " visual and readable label fit board")
	check(hit.has_area() and BOARD.encloses(hit), tag + " selectable hit target remains usable")
	var count := 0
	for value in layout.get("objects", []):
		if str(value.get("id", "")) == MARKER: count += 1
	check(count == 1, tag + " marker is rendered once and not lost to duplicate-slot guard")
	check(not _record(records, "travel:leave").is_empty(), tag + " ordinary Leave remains available")
	var slots := {}
	for value in records:
		var slot_id := str(value.get("slot_id", ""))
		if slot_id.is_empty() or not bool(value.get("visible",true)) or str(value.get("presentation_mode","room")) != "room": continue
		check(not slots.has(slot_id), tag + " visible catalog has no shared slot collision " + slot_id)
		slots[slot_id] = str(value.get("object_id", ""))
	facts[tag] = {"marker":rendered, "slot_id":marker.get("slot_id", ""), "catalog_count":records.size(), "visible_slots":slots}

func _protected(run: RunState) -> Dictionary:
	var snapshot := run.to_save_snapshot()
	var result := {}
	for key in ["bankroll", "grand_casino_chips", "debt", "rng_seed", "rng_state", "game_clock_minutes", "simulation_msec", "inventory", "story_log", "story_log_archive_count", "story_money_archive", "story_flags", "suspicion", "event_cadence", "crew_state", "run_spending_score", "narrative_flags", "active_delivery_run", "numbers_state", "pending_bags", "run_status", "run_failure_reason"]:
		if snapshot.has(key): result[key] = snapshot[key]
	var environment := run.current_environment
	for key in ["turns", "resolved_event_ids", "event_ids", "game_ids", "game_states", "item_offers", "scenario_state", "scenario_phase_index", "scenario_phase_action_counter"]:
		if environment.has(key): result["environment/"+key] = environment[key]
	var sequence: Dictionary = environment.get("scenario_sequence_state", {}).duplicate(true)
	sequence.erase("semantic_state")
	sequence.erase("transition_delivery_receipts") # one-shot presentation only; all causal/outcome/transition journal records remain exact
	result["sequence_receipts_and_progress"] = sequence
	return result.duplicate(true)

func _receipt_count(run: RunState) -> int:
	return run.current_environment.get("scenario_sequence_state", {}).get("command_receipts", []).size()

func _install_bundle() -> bool:
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	var user := ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(saves)
	DirAccess.make_dir_recursive_absolute(user)
	for name in ["foundation_ui_autosave.json", "foundation_ui_autosave.json.bak"]:
		if FileAccess.file_exists(bundle.path_join(name)) and not check(not FileAccess.file_exists(saves.path_join(name)) and DirAccess.copy_absolute(bundle.path_join(name), saves.path_join(name)) == OK, "install unchanged copied save companion"): return false
	if not check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"), user.path_join(".crew_host_authority_v1")) == OK, "install unchanged copied authority companion"): return false
	for pair in [["profile_inventory.json","BTH_PROFILE_INVENTORY_PATH"],["meta_collection.json","BTH_META_COLLECTION_PATH"],["settings.json","BTH_USER_SETTINGS_PATH"]]:
		for suffix in ["", ".bak"]:
			var source := bundle.path_join(str(pair[0])+suffix)
			if FileAccess.file_exists(source) and not check(DirAccess.copy_absolute(source,OS.get_environment(pair[1])+suffix) == OK, "install unchanged copied profile companion"): return false
	return true

func _slot(surface: Dictionary, identity: String) -> Dictionary:
	for row in Placement.all_slots(surface):
		if str(row.get("id", "")) == identity: return row
	return {}

func _record(rows: Array, identity: String) -> Dictionary:
	for row in rows:
		if str(row.get("object_id", row.get("id", ""))) == identity: return row
	return {}

func _array_rect(value: Array) -> Rect2:
	return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3])) if value.size() >= 4 else Rect2()

func _rect(value: Variant) -> Rect2:
	if value is Rect2: return value
	if typeof(value) != TYPE_DICTIONARY: return Rect2()
	return Rect2(float(value.get("x",0)),float(value.get("y",0)),float(value.get("w",0)),float(value.get("h",0)))

func _equal(left: Variant, right: Variant) -> bool:
	if typeof(left) in [TYPE_INT,TYPE_FLOAT] and typeof(right) in [TYPE_INT,TYPE_FLOAT]: return left == right
	if typeof(left) != typeof(right): return false
	if typeof(left) in [TYPE_ARRAY,TYPE_DICTIONARY]:
		if left.size() != right.size(): return false
		for key in left.keys() if typeof(left) == TYPE_DICTIONARY else range(left.size()):
			if typeof(left) == TYPE_DICTIONARY and not right.has(key): return false
			if not _equal(left[key],right[key]): return false
		return true
	return left == right

func _difference_paths(left: Variant, right: Variant, path: String = "") -> Array:
	if _equal(left, right): return []
	if typeof(left) == TYPE_DICTIONARY and typeof(right) == TYPE_DICTIONARY:
		var keys: Array = left.keys()
		for key in right:
			if not keys.has(key): keys.append(key)
		keys.sort()
		var result := []
		for key in keys:
			var child := path + "/" + str(key)
			if not left.has(key) or not right.has(key): result.append(child)
			else: result.append_array(_difference_paths(left[key], right[key], child))
		return result
	if typeof(left) == TYPE_ARRAY and typeof(right) == TYPE_ARRAY and left.size() == right.size():
		var result := []
		for index in range(left.size()): result.append_array(_difference_paths(left[index],right[index],path+"/"+str(index)))
		return result
	return [path]

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok

func _finish() -> void:
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"facts":facts,"case":OS.get_environment("BTH_VIS027_CASE"),"fidelity":"Exact copied L36 normal deferred authored callback or accepted L37/L38 host Continue, actual Canvas geometry, official private Save and fresh service. No OS pointer/Web claim or original action replay."},"\t"))
	print("MOTEL_FALSE_BALCONY_LAYOUT checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
