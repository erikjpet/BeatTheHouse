extends SceneTree

# Private captured H22/H26 bundles stay outside the repository. Native map/menu
# callbacks exercise production generation, publication and transaction rollback.
const Host := preload("res://scripts/ui/foundation_main.gd")
const Publication := preload("res://scripts/core/room_presentation_publication.gd")
const Placement := preload("res://scripts/core/environment_placement.gd")
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var private_ready := true
	for key in ["BTH_DISTRIBUTION_DATA_ROOT", "BTH_JAZZ_BUNDLE", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH", "BTH_TARGET_OUTPUT"]:
		if OS.get_environment(key).is_empty():
			private_ready = false
	if not _check(private_ready, "private diagnostic roots and copied bundle are required") or not _install_bundle():
		_finish()
		return
	var mode := OS.get_environment("BTH_JAZZ_CHECK_MODE")
	facts["mode"] = mode
	print("JAZZ_CHECK stage=starting mode=" + mode)
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	app.autosave_slot_id = "foundation_ui_autosave"
	if not _check(app.load_foundation_run(), "normal host Continue loads unchanged captured bytes"):
		app.queue_free()
		_finish()
		return
	for frame in range(3): await process_frame
	print("JAZZ_CHECK stage=loaded")
	if mode == "recovery":
		_check(app.run_state.bankroll == 42 and app.run_state.current_world_node_id() == "gas_station_casino", "H26 recovery preserves historical cash42/Gas without a refund")
		var history := _travel_receipts(app.run_state)
		_check(history.size() >= 2 and int(history[-2].get("bankroll_delta", 0)) == -4 and int(history[-1].get("bankroll_delta", 0)) == -6, "H26 retains both originally accepted Jazz/Gas fares")
		_check(bool(Publication.validate(app.run_state.current_environment).get("ok", false)) and not app._room_recovery_active_for_current_room(), "historical recovery current room still publishes normally")
		facts["recovery"] = _state(app.run_state)
	else:
		_check(app.run_state.bankroll == 52 and app.run_state.current_world_node_id() == "corner_store", "H22 preserves original Store52 state")
		if mode == "midnight":
			# Labeled time-only variation matching the QA's observed departure;
			# H22 itself was saved earlier while the normal clock kept running.
			app.run_state.game_clock_minutes = 2880
			app._refresh()
		if mode == "rejected":
			# Explicit test fault: remove only the new slot from the process-local
			# authored cache, faithfully recreating the original missing-slot cause.
			# This survives the ordinary scenario retry's fresh RunState instance.
			Placement._ensure_surface_maps()
			var broken: Dictionary = Placement._surface_maps.jazz_club.duplicate(true)
			broken.event_slots = broken.event_slots.filter(func(slot: Dictionary) -> bool: return str(slot.get("id", "")) != "event.surface_item_1")
			Placement._surface_maps.jazz_club = broken
			Placement._effective_surface_maps.clear()
			Placement._runtime_surface_maps.clear()
		var before := app.run_state.to_save_snapshot()
		facts["before"] = _state(app.run_state)
		print("JAZZ_CHECK stage=map")
		_check(app.open_world_map(), "normal map opens")
		_check(app.select_world_map_node("jazz_club"), "normal map selects advertised Jazz route")
		for frame in range(2): await process_frame
		var choice := app._travel_choice("jazz_club")
		facts["route_card"] = app.world_map_detail_label.text
		facts["choice"] = choice
		_check(bool(choice.get("enabled", false)) and not app.world_map_confirm_button.disabled, "advertised route confirmation is enabled")
		_check(str(facts.route_card).contains("OPEN"), "Jazz is advertised OPEN at departure")
		print("JAZZ_CHECK stage=travel")
		# Exercise the public generator's own atomic failure boundary directly.
		# The host's separate scenario-overlay retry is outside this check.
		var travel: Dictionary = app.generator.travel_environment_result(app.run_state, "jazz_club", true) if mode == "rejected" else app.confirm_world_map_travel()
		print("JAZZ_CHECK stage=travel_returned ok=" + str(travel.get("ok")))
		for frame in range(240):
			await process_frame
			if frame > 5 and not app.travel_transition_active:
				break
		if app.world_map_overlay.visible:
			app.world_map_close_button.pressed.emit()
		for frame in range(8): await process_frame
		facts["travel_result"] = {"ok": travel.get("ok"), "errors": travel.get("errors", [])}
		facts["after"] = _state(app.run_state)
		print("JAZZ_CHECK stage=settled")
		if mode == "rejected":
			_check(not bool(travel.get("ok", true)), "missing destination publication rejects generator travel")
			facts["install_failure"] = app.generator.environment_install_failure_snapshot()
			_check(not bool(travel.get("ok", true)) and not travel.get("errors", []).is_empty(), "real missing-slot rejection is returned through the public generator facade")
			_check(_equal(app.run_state.to_save_snapshot(), before), "failed travel restores complete source snapshot, fare/clock/RNG/slips/receipts")
			_check(not app._room_recovery_active_for_current_room() and bool(Publication.validate(app.run_state.current_environment).get("ok", false)), "rejected destination leaves valid source controls and save boundary")
			Placement._surface_maps.clear()
			Placement._surface_maps_loaded = false
			Placement._effective_surface_maps.clear()
			Placement._runtime_surface_maps.clear()
		else:
			_check(bool(travel.get("ok", false)), "normal advertised Jazz travel succeeds")
			_check(app.run_state.bankroll == 48 and app.run_state.current_world_node_id() == "jazz_club", "exactly one4-dollar fare reaches Jazz48")
			_check(str(app.run_state.current_environment.get("scenario_id", "")) == "jazz_club_rent_party", "captured deterministic Rent Party context remains selected")
			var receipts := _travel_receipts(app.run_state)
			_check(receipts.size() == _travel_receipts_from_dict(before).size() + 1 and int(receipts[-1].get("route_cost", -1)) == 4 and int(receipts[-1].get("travel_minutes", -1)) == 30, "one original-priced30-minute receipt is committed")
			var proof := Publication.validate(app.run_state.current_environment)
			facts["proof"] = proof
			_check(bool(proof.get("ok", false)), "destination passes unchanged physical authority validation")
			_check(not app._room_recovery_active_for_current_room() and not app._room_publication_save_blocked(), "destination publishes playable controls without recovery/save block")
			var binding: Dictionary = app.run_state.current_environment.get("layout", {}).get("slot_bindings", {}).get("event:chain06_sal_trail_one", {})
			facts["paper_binding"] = binding
			_check(str(binding.get("slot_id", "")) == "event.surface_item_1", "Sal paper lead binds its authored event slot")
			var active := 0
			for row in app.environment_canvas.foundation_scene_objects:
				if bool(row.get("interactive", false)) and not bool(row.get("disabled", false)):
					active += 1
			_check(active > 0, "normal canvas publishes enabled room controls")
			var invalid := app.run_state.current_environment.duplicate(false)
			invalid["layout"] = app.run_state.current_environment.layout.duplicate(true)
			invalid.layout["slot_binding_digest"] = ""
			_check(not bool(Publication.validate(invalid).get("ok", true)), "missing binding proof is still rejected; no validator weakening")
			var detached := RunState.new()
			detached.current_environment = invalid
			var inactive_result := detached.scenario_finalize_installed_environment(app.library)
			facts["inactive_rejection"] = inactive_result
			_check(bool(inactive_result.get("inactive", false)) and not bool(inactive_result.get("ok", true)), "inactive finalizer propagates rejected publication")
			_check(not inactive_result.get("errors", []).is_empty(), "inactive finalizer preserves the real validator errors")
	var before_save := _state(app.run_state)
	print("JAZZ_CHECK stage=save")
	app.open_run_menu()
	_check(app.run_menu_save_button.is_visible_in_tree() and not app.run_menu_save_button.disabled, "normal menu Save control is available")
	app.run_menu_save_button.pressed.emit()
	app.save_service.wait_for_async_save()
	var persisted: Variant = SaveService.new().load_run(app.autosave_slot_id)
	_check(persisted != null and _equal(_state(persisted), before_save), "normal Save commits current state with identical fare/receipt/slip/RNG")
	app.save_service = SaveService.new()
	_check(app.load_foundation_run(), "fresh SaveService/normal host Continue restores the committed state")
	for frame in range(5): await process_frame
	_check(_equal(_state(app.run_state), before_save), "restore preserves accepted travel or exact rejected source state")
	_check(bool(Publication.validate(app.run_state.current_environment).get("ok", false)) and not app._room_recovery_active_for_current_room(), "restored current room remains playable and authenticated")
	facts["after_restore"] = _state(app.run_state)
	app.save_service.wait_for_async_save()
	app.queue_free()
	await process_frame
	_finish()


func _install_bundle() -> bool:
	var bundle := OS.get_environment("BTH_JAZZ_BUNDLE")
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	var user_dir := ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(saves)
	DirAccess.make_dir_recursive_absolute(user_dir)
	for name in ["foundation_ui_autosave.json", "foundation_ui_autosave.json.bak"]:
		if not _check(not FileAccess.file_exists(saves.path_join(name)) and DirAccess.copy_absolute(bundle.path_join(name), saves.path_join(name)) == OK, "install unchanged private " + name):
			return false
	if not _check(not FileAccess.file_exists(user_dir.path_join(".crew_host_authority_v1")) and DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"), user_dir.path_join(".crew_host_authority_v1")) == OK, "install unchanged private authority"):
		return false
	for pair in [["profile_inventory.json", "BTH_PROFILE_INVENTORY_PATH"], ["meta_collection.json", "BTH_META_COLLECTION_PATH"], ["settings.json", "BTH_USER_SETTINGS_PATH"]]:
		for suffix in ["", ".bak"]:
			var original := bundle.path_join(str(pair[0]) + suffix)
			if FileAccess.file_exists(original) and not _check(DirAccess.copy_absolute(original, OS.get_environment(pair[1]) + suffix) == OK, "install unchanged companion " + str(pair[0]) + suffix):
				return false
	return true


func _state(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "rng": run.rng_state, "clock": run.game_clock_minutes, "environment_id": run.current_environment.get("id"), "node": run.current_world_node_id(), "scenario": run.current_environment.get("scenario_id", ""), "inventory": run.inventory.duplicate(true), "numbers_state": run.to_save_snapshot().get("numbers_state", {}), "travel_receipts": _travel_receipts(run)}


func _travel_receipts(run: RunState) -> Array:
	return _travel_receipts_from_dict({"story_log": run.story_log})


func _travel_receipts_from_dict(data: Dictionary) -> Array:
	var result := []
	for row in data.get("story_log", []):
		if typeof(row) == TYPE_DICTIONARY and str(row.get("type", "")) == "travel":
			result.append(row.duplicate(true))
	return result


func _equal(left: Variant, right: Variant) -> bool:
	if typeof(left) in [TYPE_INT, TYPE_FLOAT] and typeof(right) in [TYPE_INT, TYPE_FLOAT]: return left == right
	if typeof(left) != typeof(right): return false
	if typeof(left) in [TYPE_ARRAY, TYPE_DICTIONARY]:
		if left.size() != right.size(): return false
		for key in left.keys() if typeof(left) == TYPE_DICTIONARY else range(left.size()):
			if typeof(left) == TYPE_DICTIONARY and not right.has(key): return false
			if not _equal(left[key], right[key]): return false
		return true
	return left == right


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok


func _finish() -> void:
	var report := {"checks": checks, "failures": failures, "facts": facts, "fidelity": "Official copied H22/H26 bytes with original companions; native public map/menu callbacks on arrival, public generator facade on rejection, actual generation and fresh SaveService/host restore in same engine. Midnight is explicitly time-adjusted; rejection mode removes the new authored slot in process-local test caches only. Host scenario-overlay retry is not qualified. No OS pointer/Web claim."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t")); file.close()
	print("JAZZ_ARRIVAL_PUBLICATION checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
