extends SceneTree

# Layout survey tool: boots the real app, forces each environment archetype,
# saves a screenshot plus the resolved interactable-object layout per archetype.
# Run windowed (not --headless): the capture reads the viewport texture.
#   .tools/godot-4.6-stable/<godot.exe> --path . --script res://tools/environment_layout_screenshots.gd -- --out=C:/absolute/output/dir

const MainScene := preload("res://scenes/main.tscn")
const CollectionItemResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const SequenceCatalogScript := preload("res://scripts/core/scenario_sequence_catalog.gd")
const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const ScenarioSequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const ScenarioSequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const FunctionOptionsScript := preload("res://scripts/core/function_options.gd")
const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const HarnessProductionFidelityScript := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const SEED_TEXT := "LAYOUT-SURVEY-QA"
const FIX06_31_SEED := "FIX06-31-AUDIT-BEFORE"
const FIX06_31_FLOOR_Y := {
	"beach": 180.0,
	"delta_queen": 246.0,
	"bar": 244.0,
	"gas_station_casino": 248.0,
	"small_underground_casino": 245.0,
}

var app: Control
var out_dir := "user://layout_survey"
var report := {}
var meta_home_review := false
var punchline_layer_review := false
var fix06_31_audit := false
var fix06_31_audit_phase := "before"
var fix06_31_scenario_filter := ""
var fix06_31_room_filter := ""
var fix06_31_skip_base := false
var fix06_31_surface_maps: Dictionary = {}
var rw06_1_contact_sheet := false
var rw06_1_static_report := "res://.tmp/rw06_1/static/slot_report.json"


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		elif argument == "--meta-home-review":
			meta_home_review = true
		elif argument == "--punchline-layers-only":
			punchline_layer_review = true
		elif argument == "--fix06-31-audit":
			fix06_31_audit = true
		elif argument == "--fix06-31-after":
			fix06_31_audit = true
			fix06_31_audit_phase = "after"
		elif argument.begins_with("--fix06-31-scenario="):
			fix06_31_scenario_filter = argument.trim_prefix("--fix06-31-scenario=")
		elif argument.begins_with("--fix06-31-room="):
			fix06_31_room_filter = argument.trim_prefix("--fix06-31-room=")
		elif argument == "--fix06-31-skip-base":
			fix06_31_skip_base = true
		elif argument == "--rw06-1-contact-sheet":
			rw06_1_contact_sheet = true
		elif argument.begins_with("--rw06-1-static-report="):
			rw06_1_static_report = argument.trim_prefix("--rw06-1-static-report=")
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	app = MainScene.instantiate()
	root.add_child(app)
	await _settle(4)
	if meta_home_review:
		await _run_meta_home_review()
		return
	app.call("start_foundation_run", SEED_TEXT, {})
	await _settle(6)
	var library: Variant = app.get("library")
	var run_state: Variant = app.get("run_state")
	if library == null or run_state == null:
		push_error("Layout survey could not start a run.")
		quit(1)
		return
	if fix06_31_audit:
		await _run_fix06_31_audit(library)
		return
	if rw06_1_contact_sheet:
		await _run_rw06_1_contact_sheet(library)
		return
	var archetypes: Array = library.environment_archetypes
	for archetype_value in archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		var archetype_id := str(archetype.get("id", ""))
		if archetype_id.is_empty():
			continue
		if punchline_layer_review and archetype_id != "small_underground_casino":
			continue
		await _capture_archetype(archetype, archetype_id, run_state, library)
	var file := FileAccess.open("%s/layout_report.json" % out_dir, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("LAYOUT_SURVEY_DONE %d environments -> %s" % [report.size(), out_dir])
	quit(0)


func _run_meta_home_review() -> void:
	var store_path := "%s/meta_home_review_store.json" % out_dir
	OS.set_environment("BTH_META_COLLECTION_PATH", store_path)
	if FileAccess.file_exists(store_path):
		DirAccess.remove_absolute(store_path)
	await _settle(2)
	app.call("open_meta_home")
	await _settle(8)
	await _capture_current_meta_room("back_alley")
	var service: Variant = app.get("meta_collection_service")
	if service == null:
		push_error("Meta-home screenshot review could not load MetaCollectionService.")
		quit(1)
		return
	_seed_meta_review_collection(service)
	service.call("add_gold", 2000)
	service.call("purchase_housing_upgrade")
	service.call("save")
	app.call("open_meta_home")
	await _settle(8)
	await _capture_current_meta_room("motel_room")
	service.call("purchase_housing_upgrade")
	service.call("save")
	app.call("open_meta_home")
	await _settle(8)
	await _capture_current_meta_room("apartment")
	service.call("purchase_housing_upgrade")
	service.call("save")
	app.call("open_meta_home")
	await _settle(8)
	await _capture_current_meta_room("house")
	app.call("_enter_meta_location", "pawn_shop")
	await _settle(8)
	await _capture_current_meta_room("pawn_shop")
	await _verify_meta_click_path()
	var file := FileAccess.open("%s/layout_report.json" % out_dir, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("META_HOME_LAYOUT_SURVEY_DONE %d rooms -> %s" % [report.size(), out_dir])
	quit(0)


func _verify_meta_click_path() -> void:
	var steps: Array = []
	app.call("open_meta_home")
	await _settle(4)
	if await _activate_first_object_with_prefix("meta_container:"):
		steps.append("home container opened")
		app.call("_hide_event_choice_popup")
	await _settle(2)
	if await _activate_first_object_with_prefix("meta_bag:"):
		steps.append("unopened bag opened")
		app.call("_hide_event_choice_popup")
	await _settle(2)
	if await _activate_first_object_with_prefix("meta_trade_up:"):
		steps.append("trade-up station opened")
		app.call("_hide_event_choice_popup")
	await _settle(2)
	if bool(app.call("activate_interactable_object", "travel:leave")):
		await _settle(2)
		var pawn_id := "pawn_shop"
		if bool(app.call("select_world_map_node", pawn_id)):
			app.call("confirm_world_map_travel")
			await _settle(4)
			steps.append("map traveled to pawn shop")
	if await _activate_first_object_with_prefix("meta_pawn_counter:"):
		steps.append("pawn sell counter opened")
		var service: Variant = app.get("meta_collection_service")
		var rows: Array = app.call("_meta_sale_rows")
		if not rows.is_empty() and typeof(rows[0]) == TYPE_DICTIONARY:
			var row: Dictionary = rows[0]
			app.call("_show_meta_sale_confirm", str(row.get("kind", "")), int(row.get("instance_id", 0)))
			await _settle(2)
			var service_snapshot: Variant = service.call("snapshot") if service != null else {}
			var pending: Dictionary = service_snapshot.get("pending_sale", {}) if typeof(service_snapshot) == TYPE_DICTIONARY else {}
			var token := str(pending.get("token", ""))
			if not token.is_empty():
				app.call("_confirm_meta_sale", token)
				await _settle(2)
				steps.append("pawn sale confirmed")
		app.call("_hide_event_choice_popup")
	await _settle(2)
	if bool(app.call("activate_interactable_object", "travel:leave")):
		await _settle(2)
		if bool(app.call("select_world_map_node", "home")):
			app.call("confirm_world_map_travel")
			await _settle(4)
			steps.append("returned home")
	report["click_path"] = steps


func _activate_first_object_with_prefix(prefix: String) -> bool:
	var snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	var objects: Array = snapshot.get("objects", []) if typeof(snapshot.get("objects", [])) == TYPE_ARRAY else []
	for object_value in objects:
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = object_value
		var object_id := str(object_data.get("object_id", ""))
		if object_id.begins_with(prefix):
			return bool(app.call("activate_interactable_object", object_id))
	return false


func _seed_meta_review_collection(service: Variant) -> void:
	var resolver: Variant = CollectionItemResolverScript.new()
	var collections: Array = resolver.collections()
	if collections.is_empty() or typeof(collections[0]) != TYPE_DICTIONARY:
		return
	var collection: Dictionary = collections[0]
	var bag_defs: Array = collection.get("bag_defs", []) if typeof(collection.get("bag_defs", [])) == TYPE_ARRAY else []
	if not bag_defs.is_empty() and typeof(bag_defs[0]) == TYPE_DICTIONARY:
		var bag_def: Dictionary = bag_defs[0]
		service.call("grant_bag", int(bag_def.get("itemdef_id", -1)), "meta-home-review-bag", {"source": "review", "source_id": "screenshot"})
	var blue_items: Array = resolver.item_definitions_for_collection_tier(str(collection.get("id", "")), "blue")
	if blue_items.is_empty():
		return
	var definition: Dictionary = blue_items[0] if typeof(blue_items[0]) == TYPE_DICTIONARY else {}
	var itemdef_id := int(definition.get("itemdef_id", -1))
	for index in range(5):
		var instance: Dictionary = resolver.roll_instance(itemdef_id, "meta-home-review-item-%d" % index)
		service.call("grant_instance", instance)
	service.call("save")


func _capture_current_meta_room(file_id: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [out_dir, file_id])
	var run_state: Variant = app.get("run_state")
	var environment: Dictionary = {}
	if run_state != null:
		environment = run_state.current_environment
	report[file_id] = {
		"name": str(environment.get("display_name", file_id)),
		"archetype_id": str(environment.get("archetype_id", "")),
		"meta_location": str(environment.get("meta_location", "")),
		"authored_layout": environment.get("layout", {}),
		"canvas_object_layout": _canvas_object_layout(),
	}


func _capture_archetype(archetype: Dictionary, archetype_id: String, run_state: Variant, library: Variant) -> void:
	var rng: Variant = run_state.create_rng()
	var environment: Variant = EnvironmentInstance.from_archetype(archetype, 1, rng, library, run_state.challenge_config)
	var data: Dictionary = environment.to_dict()
	data["world_node_id"] = archetype_id
	if str(archetype.get("kind", "")) == "home":
		var profile: Dictionary = archetype.get("home_profile", {}) if typeof(archetype.get("home_profile", {})) == TYPE_DICTIONARY else {}
		run_state.initialize_home_from_profile(archetype, archetype_id, profile)
		data["home_profile"] = profile.duplicate(true)
		data["home_containers"] = _survey_home_containers(profile)
		data["home_container_index"] = int((data["home_containers"] as Array).size())
		data["home_lost"] = false
	# Match production ordering: generated game state supplies room hooks (ticket
	# redeemers, attendants, and similar objects) before the final packing pass.
	# A capture that packs the raw archetype first can conceal the exact late-hook
	# collisions this audit is intended to catch.
	var generator := RunGeneratorScript.new(library)
	data["game_states"] = generator.call("_generated_game_states", run_state, data, rng)
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data, library)
	run_state.save_rng(rng)
	run_state.set_environment(data)
	app.call("_clear_selected_game_action")
	app.call("_refresh")
	await _settle(4)
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var default_layer_id := str(data.get("current_layer_id", "")).strip_edges()
	var file_id := "%s_%s" % [archetype_id, default_layer_id] if punchline_layer_review and not default_layer_id.is_empty() else archetype_id
	image.save_png("%s/%s.png" % [out_dir, file_id])
	report[file_id] = {
		"name": str(data.get("display_name", archetype_id)),
		"layer_id": default_layer_id,
		"scene_type": str((data.get("visual_context", {}) as Dictionary).get("scene_type", "")),
		"game_ids": data.get("game_ids", []),
		"event_ids": data.get("event_ids", []),
		"service_ids": data.get("service_ids", []),
		"lender_hooks": data.get("lender_hooks", []),
		"authored_layout": archetype.get("layout", {}),
		"generated_layout": {
			"object_rects": (data.get("layout", {}) as Dictionary).get("object_rects", {}),
			"placement_surfaces": (data.get("layout", {}) as Dictionary).get("placement_surfaces", {}),
			"placement_errors": (data.get("layout", {}) as Dictionary).get("placement_errors", []),
			"placement_fallback_ids": (data.get("layout", {}) as Dictionary).get("placement_fallback_ids", []),
		},
		"canvas_object_layout": _canvas_object_layout(),
		"direct_interaction_overlaps": _direct_interaction_overlaps(_canvas_object_layout()),
	}
	if punchline_layer_review:
		for layer_id_value in data.get("layer_ids", []):
			var layer_id := str(layer_id_value)
			if layer_id != default_layer_id:
				await _capture_archetype_layer(archetype, archetype_id, layer_id, run_state, library)


func _capture_archetype_layer(archetype: Dictionary, archetype_id: String, layer_id: String, run_state: Variant, library: Variant) -> void:
	var rng: Variant = run_state.create_rng("layout_survey_layer:%s:%s" % [archetype_id, layer_id])
	var environment: Variant = EnvironmentInstance.from_archetype_layer(archetype, layer_id, 1, rng, library, run_state.challenge_config)
	var data: Dictionary = environment.to_dict()
	data["world_node_id"] = archetype_id
	data["layer_discovery"] = {"club": true, "casino": true, "back_room": true}
	var generator := RunGeneratorScript.new(library)
	data["game_states"] = generator.call("_generated_game_states", run_state, data, rng)
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data, library)
	run_state.set_environment(data)
	app.call("_clear_selected_game_action")
	app.call("_refresh")
	await _settle(4)
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var file_id := "%s_%s" % [archetype_id, layer_id]
	image.save_png("%s/%s.png" % [out_dir, file_id])
	report[file_id] = {
		"name": str(data.get("display_name", archetype_id)),
		"layer_id": layer_id,
		"scene_type": str((data.get("visual_context", {}) as Dictionary).get("scene_type", "")),
		"game_ids": data.get("game_ids", []),
		"event_ids": data.get("event_ids", []),
		"service_ids": data.get("service_ids", []),
		"lender_hooks": data.get("lender_hooks", []),
		"authored_layout": data.get("layout", {}),
		"canvas_object_layout": _canvas_object_layout(),
		"direct_interaction_overlaps": _direct_interaction_overlaps(_canvas_object_layout()),
	}


func _canvas_object_layout() -> Dictionary:
	var canvas: Variant = app.get("environment_canvas")
	if canvas == null:
		return {}
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	return snapshot.get("object_layout", {})


func _direct_interaction_overlaps(layout: Dictionary) -> Array:
	var objects := _array(layout.get("objects", []))
	var overlaps: Array = []
	for a in range(objects.size()):
		var first := _dict(objects[a])
		var first_rect := _rect(first.get("interaction_rect", {}))
		if not first_rect.has_area():
			continue
		for b in range(a + 1, objects.size()):
			var second := _dict(objects[b])
			var second_rect := _rect(second.get("interaction_rect", {}))
			if not second_rect.has_area() or not first_rect.intersects(second_rect):
				continue
			var intersection := first_rect.intersection(second_rect)
			if intersection.has_area():
				overlaps.append({
					"a": str(first.get("id", "")),
					"b": str(second.get("id", "")),
					"area": intersection.get_area(),
				})
	return overlaps


func _run_rw06_1_contact_sheet(library: Variant) -> void:
	var failures: Array = []
	var static_report := _rw06_1_read_json(rw06_1_static_report)
	var selections := _array(static_report.get("contact_sheet", []))
	if selections.size() != 18:
		failures.append("rw06_1 contact-sheet manifest must contain 18 rooms; found %d." % selections.size())
	var definitions: Dictionary = {}
	for definition_value in _fix06_31_scenario_definitions(library):
		var definition := _dict(definition_value)
		definitions[str(definition.get("id", ""))] = definition
	var archetypes: Dictionary = {}
	for archetype_value in library.environment_archetypes:
		var archetype := _dict(archetype_value)
		archetypes[str(archetype.get("id", ""))] = archetype
	DirAccess.make_dir_recursive_absolute("%s/normal" % out_dir)
	DirAccess.make_dir_recursive_absolute("%s/expanded" % out_dir)
	var capture_rows: Array = []
	for selection_value in selections:
		var selection := _dict(selection_value)
		var archetype_id := str(selection.get("archetype_id", ""))
		var scenario_id := str(selection.get("scenario_id", ""))
		var prepared: Dictionary = {}
		if scenario_id.is_empty():
			prepared = await _rw06_1_prepare_base_room(_dict(archetypes.get(archetype_id, {})), library)
		else:
			prepared = await _rw06_1_prepare_scenario_peak(_dict(definitions.get(scenario_id, {})), selection, library)
		if not bool(prepared.get("ok", false)):
			failures.append_array(_array(prepared.get("errors", ["%s could not be prepared." % archetype_id])))
			continue
		var captured := await _rw06_1_capture_pair(selection)
		if not bool(captured.get("ok", false)):
			failures.append_array(_array(captured.get("errors", ["%s could not be captured." % archetype_id])))
			continue
		capture_rows.append(captured)
	var day2_rows: Array = []
	for row_value in capture_rows:
		var row := _dict(row_value)
		if bool(_dict(row.get("selection", {})).get("day2_sample", false)):
			day2_rows.append(row)
	var full_sheet := _rw06_1_build_sheet(capture_rows, "%s/all_rooms_contact_sheet.png" % out_dir, 3)
	var day2_sheet := _rw06_1_build_sheet(day2_rows, "%s/day2_contact_sheet.png" % out_dir, 1)
	if not bool(full_sheet.get("ok", false)):
		failures.append_array(_array(full_sheet.get("errors", [])))
	if not bool(day2_sheet.get("ok", false)):
		failures.append_array(_array(day2_sheet.get("errors", [])))
	var report_payload := {
		"schema": "rw06_1_fixed_slot_contact_sheet/v1",
		"source_static_report": rw06_1_static_report,
		"room_count": capture_rows.size(),
		"day2_room_count": day2_rows.size(),
		"captures": capture_rows,
		"all_rooms_sheet": full_sheet,
		"day2_sheet": day2_sheet,
		"failures": failures,
	}
	_write_fix06_31_json("%s/contact_sheet_report.json" % out_dir, report_payload)
	print("RW06_1_CONTACT_SHEET rooms=%d day2=%d failures=%d out=%s" % [capture_rows.size(), day2_rows.size(), failures.size(), out_dir])
	app.free()
	app = null
	await _settle(4)
	quit(0 if failures.is_empty() and capture_rows.size() == 18 and day2_rows.size() == 3 else 1)


func _rw06_1_prepare_base_room(archetype: Dictionary, library: Variant) -> Dictionary:
	var archetype_id := str(archetype.get("id", ""))
	if archetype_id.is_empty():
		return {"ok": false, "errors": ["rw06_1 base-room capture has no archetype definition."]}
	var run_state: Variant = app.get("run_state")
	var rng: Variant = run_state.create_rng("rw06_1_contact_base:%s" % archetype_id)
	var environment: Variant = EnvironmentInstance.from_archetype(archetype, 1, rng, library, run_state.challenge_config)
	var data: Dictionary = environment.to_dict()
	data["world_node_id"] = archetype_id
	if str(archetype.get("kind", "")) == "home":
		var profile := _dict(archetype.get("home_profile", {}))
		run_state.initialize_home_from_profile(archetype, archetype_id, profile)
		data["home_profile"] = profile.duplicate(true)
		data["home_containers"] = _survey_home_containers(profile)
		data["home_container_index"] = _array(data.get("home_containers", [])).size()
		data["home_lost"] = false
	var generator := RunGeneratorScript.new(library)
	data["game_states"] = generator.call("_generated_game_states", run_state, data, rng)
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data, library)
	run_state.save_rng(rng)
	run_state.set_environment(data)
	app.call("_clear_selected_game_action")
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_render_environment_screen")
	await _settle(3)
	return {"ok": true, "errors": []}


func _rw06_1_prepare_scenario_peak(definition: Dictionary, selection: Dictionary, library: Variant) -> Dictionary:
	var scenario_id := str(selection.get("scenario_id", ""))
	var archetype_id := str(selection.get("archetype_id", ""))
	var target_phase := str(selection.get("phase_id", ""))
	if definition.is_empty() or str(definition.get("id", "")) != scenario_id:
		return {"ok": false, "errors": ["rw06_1 contact definition is missing for %s." % scenario_id]}
	var original_pool: Array = _array(library.environment_scenarios.get(archetype_id, [])).duplicate(true)
	library.environment_scenarios[archetype_id] = [definition.duplicate(true)]
	var run_state := RunStateScript.new()
	run_state.start_new("RW06-1-CONTACT-%s" % scenario_id)
	var generator := RunGeneratorScript.new(library)
	var local_failures: Array = []
	var initial := HarnessProductionFidelityScript.generate_and_finalize(generator, run_state, local_failures, "%s initial" % scenario_id)
	var target_node := _fix06_31_node_for_archetype(run_state, archetype_id)
	var arrival: Dictionary = initial if str(run_state.current_environment.get("archetype_id", "")) == archetype_id else {}
	if bool(initial.get("ok", false)) and arrival.is_empty() and not target_node.is_empty():
		arrival = HarnessProductionFidelityScript.travel_and_finalize(generator, run_state, target_node, true, library, local_failures, "%s arrival" % scenario_id)
	library.environment_scenarios[archetype_id] = original_pool
	if not bool(arrival.get("ok", false)):
		return {"ok": false, "errors": local_failures if not local_failures.is_empty() else ["%s did not reach its host room." % scenario_id]}
	var initial_state := _dict(run_state.current_environment.get("scenario_sequence_state", {}))
	var phase_states := _rw06_1_reachable_phase_states(initial_state, definition, target_phase)
	var best: Dictionary = {}
	for state_value in phase_states:
		var resolved := _rw06_1_resolve_capture_state(run_state.current_environment, _dict(state_value), definition)
		if not bool(resolved.get("ok", false)):
			continue
		if best.is_empty() or int(resolved.get("scenario_binding_count", -1)) > int(best.get("scenario_binding_count", -1)):
			best = resolved
	if best.is_empty():
		return {"ok": false, "errors": ["%s has no resolvable reachable state at peak phase %s." % [scenario_id, target_phase]]}
	var expected_count := int(selection.get("binding_count", 0))
	if int(best.get("scenario_binding_count", -1)) != expected_count:
		return {"ok": false, "errors": ["%s peak %s rendered %d scenario bindings; static manifest requires %d." % [scenario_id, target_phase, int(best.get("scenario_binding_count", -1)), expected_count]]}
	run_state.current_environment = _dict(best.get("environment", {}))
	run_state.bankroll = maxi(run_state.bankroll, 10000)
	run_state.run_status = RunStateScript.RUN_STATUS_ACTIVE
	run_state.run_failure_reason = ""
	run_state.run_failure_message = ""
	app.set("run_state", run_state)
	app.set("generator", generator)
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_clear_selected_game_action")
	app.call("_render_environment_screen")
	await _settle(3)
	return {"ok": true, "errors": []}


func _rw06_1_resolve_capture_state(environment: Dictionary, state: Dictionary, definition: Dictionary) -> Dictionary:
	var candidate := environment.duplicate(true)
	candidate["scenario_sequence_state"] = state.duplicate(true)
	candidate[ScenarioEngineScript.TRUSTED_STATE_REFERENCE_KEY] = ScenarioSequenceRuntimeScript.content_fingerprint(state)
	var projection := ScenarioEngineScript.sequence_projection(candidate, definition)
	if projection.is_empty():
		return {"ok": false, "errors": ["Peak state did not produce a public projection."]}
	var layout_environment := candidate.duplicate(false)
	var layout_context := _dict(candidate.get("scenario_layout_context", {}))
	if not layout_context.is_empty():
		layout_environment["_scenario_layout_context"] = layout_context.duplicate(true)
	var layout_result := ScenarioLayoutResolverScript.resolve(_array(candidate.get("scenario_layout_base_records", [])), projection, layout_environment)
	if not bool(layout_result.get("ok", false)):
		return {"ok": false, "errors": _array(layout_result.get("errors", ["Peak layout resolution failed."]))}
	var renderer_snapshot := ScenarioLayoutResolverScript.sealed_renderer_snapshot(layout_result)
	if not bool(renderer_snapshot.get("ok", false)):
		return {"ok": false, "errors": _array(renderer_snapshot.get("errors", ["Peak renderer snapshot failed."]))}
	candidate["scenario_sequence_projection"] = _dict(layout_result.get("projection", projection))
	candidate["scenario_layout_authority"] = _dict(layout_result.get("layout_authority", {}))
	candidate["scenario_layout_audit"] = _dict(layout_result.get("layout_audit", {}))
	candidate["scenario_layout_authority_digest"] = str(layout_result.get("layout_authority_digest", ""))
	candidate["scenario_render_snapshot"] = renderer_snapshot.duplicate(true)
	var binding_count := 0
	for identity_value in _dict(candidate.get("scenario_layout_authority", {})).keys():
		if str(identity_value).begins_with("scenario::"):
			binding_count += 1
	return {"ok": true, "environment": candidate, "scenario_binding_count": binding_count, "errors": []}


func _rw06_1_reachable_phase_states(initial_state: Dictionary, definition: Dictionary, target_phase: String) -> Array:
	var result: Array = []
	var pending: Array = [initial_state.duplicate(true)]
	var visited: Dictionary = {}
	var serial := 0
	while not pending.is_empty() and serial < 256:
		var state := _dict(pending.pop_front())
		var state_key := ScenarioSequenceRuntimeScript.content_fingerprint(ScenarioSequenceRuntimeScript.public_projection(state, definition))
		if visited.has(state_key):
			continue
		visited[state_key] = true
		if str(state.get("status", "")) == ScenarioSequenceRuntimeScript.STATUS_ACTIVE and str(state.get("phase_id", "")) == target_phase:
			result.append(state.duplicate(true))
		var phase := ScenarioSequenceSchemaScript.phase(definition, str(state.get("phase_id", "")))
		var branch_index := 0
		for branch_value in _array(phase.get("branches", [])):
			var branch := _dict(branch_value)
			var condition := _dict(branch.get("condition", {}))
			var applied: Dictionary = {}
			if str(condition.get("type", "")) == "command":
				applied = _rw06_1_apply_trace_command(state, definition, str(condition.get("command_id", "")), serial, branch_index)
			elif str(condition.get("type", "")) == "fact":
				applied = _rw06_1_apply_trace_fact(state, definition, condition, serial, branch_index)
			if bool(applied.get("ok", false)):
				pending.append(_dict(applied.get("state", {})))
			branch_index += 1
		serial += 1
	return result


func _rw06_1_apply_trace_command(state: Dictionary, definition: Dictionary, command_id: String, serial: int, branch_index: int) -> Dictionary:
	var origin := _rw06_1_find_action_origin(state, command_id)
	if origin.is_empty():
		return {"ok": false, "errors": ["No action origin for %s." % command_id]}
	var owner_namespace := str(origin.get("owner_namespace", ""))
	var stable_object_id := str(origin.get("stable_object_id", ""))
	var descriptor := ScenarioSequenceRuntimeScript._command_descriptor(state, definition, owner_namespace, stable_object_id, command_id, {})
	var command := ScenarioSequenceRuntimeScript.command(FunctionOptionsScript.scenario_sequence_command(command_id, str(state.get("node_id", "")), str(state.get("phase_id", "")), "rw06_1:contact:%d:%d" % [serial, branch_index], {
		"payload": {},
		"owner_namespace": owner_namespace,
		"stable_object_id": stable_object_id,
		"action_origin_owner_namespace": str(descriptor.get("action_origin_owner_namespace", "")),
		"action_origin_stable_object_id": str(descriptor.get("action_origin_stable_object_id", "")),
		"action_origin_receipt_key": str(descriptor.get("action_origin_receipt_key", "")),
		"action_origin_boundary_id": str(descriptor.get("action_origin_boundary_id", "")),
		"action_origin_fingerprint": str(descriptor.get("action_origin_fingerprint", "")),
	}))
	return ScenarioSequenceRuntimeScript.apply_command(state, definition, command, {"available_funds": 100000})


func _rw06_1_find_action_origin(state: Dictionary, command_id: String) -> Dictionary:
	for interaction_value in _dict(_dict(state.get("semantic_state", {})).get("interactions", {})).values():
		var interaction := _dict(interaction_value)
		if not bool(interaction.get("enabled", false)):
			continue
		for action_value in _array(interaction.get("available_actions", [])):
			if str(_dict(action_value).get("id", "")) == command_id:
				return {"owner_namespace": str(interaction.get("owner_namespace", "")), "stable_object_id": str(interaction.get("stable_object_id", ""))}
	return {}


func _rw06_1_apply_trace_fact(state: Dictionary, definition: Dictionary, condition: Dictionary, serial: int, branch_index: int) -> Dictionary:
	var fact_type := str(condition.get("fact_type", ""))
	var boundary := int(state.get("boundary_serial", 0)) + 1
	var payload := _rw06_1_trace_fact_payload(fact_type, state)
	for key_value in _dict(condition.get("payload_equals", {})).keys():
		payload[str(key_value)] = _dict(condition.get("payload_equals", {})).get(key_value)
	var fact := ScenarioSequenceRuntimeScript.fact(fact_type, _rw06_1_trace_fact_producer(fact_type), str(state.get("node_id", "")), "rw06_1:contact:fact:%d:%d" % [serial, branch_index], 1, boundary, payload)
	var queued := ScenarioSequenceRuntimeScript.enqueue_fact(state, definition, fact)
	if not bool(queued.get("ok", false)):
		return queued
	var flushed := ScenarioSequenceRuntimeScript.flush_facts(_dict(queued.get("state", {})), definition, boundary)
	if bool(flushed.get("ok", false)) and str(_dict(flushed.get("state", {})).get("status", "")) == ScenarioSequenceRuntimeScript.STATUS_ACTIVE:
		var second_boundary := boundary + 1
		var second := ScenarioSequenceRuntimeScript.fact(fact_type, _rw06_1_trace_fact_producer(fact_type), str(state.get("node_id", "")), "rw06_1:contact:fact:%d:%d:second" % [serial, branch_index], 2, second_boundary, payload)
		var second_queued := ScenarioSequenceRuntimeScript.enqueue_fact(_dict(flushed.get("state", {})), definition, second)
		if bool(second_queued.get("ok", false)):
			flushed = ScenarioSequenceRuntimeScript.flush_facts(_dict(second_queued.get("state", {})), definition, second_boundary)
	return flushed


func _rw06_1_trace_fact_producer(fact_type: String) -> String:
	for producer_value in ScenarioSequenceRuntimeScript.FACT_TYPES_BY_PRODUCER.keys():
		if _array(ScenarioSequenceRuntimeScript.FACT_TYPES_BY_PRODUCER.get(producer_value, [])).has(fact_type):
			return str(producer_value)
	return "scenario"


func _rw06_1_trace_fact_payload(fact_type: String, state: Dictionary) -> Dictionary:
	match fact_type:
		"game_result": return {"game_id": "rw06_1_game", "action_id": "settled", "won": false, "ended": true, "bankroll_delta": 0, "chips_delta": 0, "applied_heat_delta": 0}
		"event_result": return {"event_id": "rw06_1_event", "choice_id": "leave", "resolved": false, "ok": true}
		"service_result": return {"kind": "rest", "service_id": "rw06_1_service", "ok": true, "action_id": "resolved"}
		"travel_departed", "travel_arrived": return {"source_id": "rw06_1_source", "target_id": "rw06_1_target", "travel_kind": "road"}
		"crew_changed": return {"member_id": "rw06_1_crew", "change": "trust", "value": 2}
		"crew_job_changed": return {"job_id": "rw06_1_job", "status": "active", "definition_id": "rw06_1_job", "member_id": "rw06_1_crew", "outcome": "complete"}
		"heat_changed": return {"previous": 2, "current": 4, "applied_delta": 2, "source": "rw06_1"}
		"heat_band_changed": return {"previous_band": "quiet", "current_band": "caution", "current": 25, "source": "rw06_1"}
		"sweep_changed": return {"action_index": 1, "node_id": str(state.get("node_id", "")), "segment_index": 1, "active": true}
		"town_transition": return {"action_index": 1, "weather": "storm", "day_type": "night", "happening_ids": ["rw06_1_weather"]}
		"world_boundary": return {"amount": 1, "action_index": 1}
		"scenario_command": return {"command_id": "rw06_1", "receipt_id": "rw06_1_command"}
	return {}


func _rw06_1_capture_pair(selection: Dictionary) -> Dictionary:
	var failures: Array = []
	var archetype_id := str(selection.get("archetype_id", ""))
	var canvas: Variant = app.get("environment_canvas")
	if canvas == null:
		return {"ok": false, "errors": ["%s has no production environment canvas." % archetype_id]}
	var layouts: Dictionary = {}
	for mode in ["normal", "expanded"]:
		canvas.call("set_small_screen_mode", mode == "expanded")
		canvas.call("queue_redraw")
		await _settle(3)
		await RenderingServer.frame_post_draw
		var image := root.get_viewport().get_texture().get_image()
		var path := "%s/%s/%s.png" % [out_dir, mode, archetype_id]
		var save_error := image.save_png(path)
		if save_error != OK:
			failures.append("%s %s capture could not be written (%s)." % [archetype_id, mode, error_string(save_error)])
		var object_layout := _canvas_object_layout()
		layouts[mode] = {
			"path": path,
			"sha256": FileAccess.get_sha256(path) if save_error == OK else "",
			"object_layout": object_layout,
			"direct_interaction_overlaps": _direct_interaction_overlaps(object_layout),
		}
	canvas.call("set_small_screen_mode", false)
	return {
		"ok": failures.is_empty(),
		"selection": selection.duplicate(true),
		"normal": _dict(layouts.get("normal", {})),
		"expanded": _dict(layouts.get("expanded", {})),
		"errors": failures,
	}


func _rw06_1_build_sheet(rows: Array, path: String, rooms_per_row: int) -> Dictionary:
	var failures: Array = []
	if rows.is_empty():
		return {"ok": false, "path": path, "errors": ["Contact sheet %s has no rows." % path], "cells": []}
	var cell_size := Vector2i(320, 180)
	var pair_size := Vector2i(cell_size.x * 2, cell_size.y)
	var row_count := ceili(float(rows.size()) / float(maxi(1, rooms_per_row)))
	var sheet := Image.create(pair_size.x * rooms_per_row, cell_size.y * row_count, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#10151f"))
	var cells: Array = []
	for index in range(rows.size()):
		var row := _dict(rows[index])
		var selection := _dict(row.get("selection", {}))
		var room_column := index % rooms_per_row
		var room_row := floori(float(index) / float(rooms_per_row))
		for mode_index in range(2):
			var mode := "normal" if mode_index == 0 else "expanded"
			var source_path := str(_dict(row.get(mode, {})).get("path", ""))
			var source := Image.load_from_file(source_path)
			if source == null or source.is_empty():
				failures.append("Contact sheet source is missing: %s." % source_path)
				continue
			source.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_LANCZOS)
			var destination := Vector2i(room_column * pair_size.x + mode_index * cell_size.x, room_row * cell_size.y)
			sheet.blit_rect(source, Rect2i(Vector2i.ZERO, cell_size), destination)
			var border_color := Color("#f5c451") if mode == "normal" else Color("#58c7ff")
			_rw06_1_image_border(sheet, Rect2i(destination, cell_size), border_color, 3)
			cells.append({
				"archetype_id": str(selection.get("archetype_id", "")),
				"scenario_id": str(selection.get("scenario_id", "")),
				"phase_id": str(selection.get("phase_id", "")),
				"mode": mode,
				"rect": {"x": destination.x, "y": destination.y, "w": cell_size.x, "h": cell_size.y},
			})
	var save_error := sheet.save_png(path)
	if save_error != OK:
		failures.append("Contact sheet could not be written to %s (%s)." % [path, error_string(save_error)])
	return {"ok": failures.is_empty(), "path": path, "sha256": FileAccess.get_sha256(path) if save_error == OK else "", "cells": cells, "errors": failures}


func _rw06_1_image_border(image: Image, rect: Rect2i, color: Color, width: int) -> void:
	image.fill_rect(Rect2i(rect.position.x, rect.position.y, rect.size.x, width), color)
	image.fill_rect(Rect2i(rect.position.x, rect.end.y - width, rect.size.x, width), color)
	image.fill_rect(Rect2i(rect.position.x, rect.position.y, width, rect.size.y), color)
	image.fill_rect(Rect2i(rect.end.x - width, rect.position.y, width, rect.size.y), color)


func _rw06_1_read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return _dict(parsed)


func _run_fix06_31_audit(library: Variant) -> void:
	var failures: Array = []
	fix06_31_surface_maps = _load_fix06_31_surface_maps(failures)
	var baseline_report: Dictionary = {}
	var audit_records: Array = []
	var floating_roots: Dictionary = {}
	DirAccess.make_dir_recursive_absolute("%s/base" % out_dir)
	DirAccess.make_dir_recursive_absolute("%s/states" % out_dir)
	DirAccess.make_dir_recursive_absolute("%s/floating_people" % out_dir)
	var run_state: Variant = app.get("run_state")
	for archetype_value in ([] if fix06_31_skip_base else library.environment_archetypes):
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype: Dictionary = archetype_value
		var archetype_id := str(archetype.get("id", ""))
		if archetype_id.is_empty():
			continue
		var prior_out := out_dir
		out_dir = "%s/base" % prior_out
		await _capture_archetype(archetype, archetype_id, run_state, library)
		out_dir = prior_out
		baseline_report[archetype_id] = report.get(archetype_id, {}).duplicate(true)
		_fix06_31_save_base_annotation(prior_out, archetype_id, archetype_id)
		if archetype_id == "small_underground_casino":
			for layer_id in ["club", "casino", "back_room"]:
				var layer_key := "%s_%s" % [archetype_id, layer_id]
				out_dir = "%s/base" % prior_out
				await _capture_archetype_layer(archetype, archetype_id, layer_id, run_state, library)
				out_dir = prior_out
				baseline_report[layer_key] = report.get(layer_key, {}).duplicate(true)
				_fix06_31_save_base_annotation(prior_out, layer_key, "%s:%s" % [archetype_id, layer_id])
	var definitions := _fix06_31_scenario_definitions(library)
	for definition_value in definitions:
		var definition := _dict(definition_value)
		var scenario_id := str(definition.get("id", ""))
		if not fix06_31_scenario_filter.is_empty() and scenario_id not in fix06_31_scenario_filter.split(",", false):
			continue
		var archetype_id := str(definition.get("archetype_id", ""))
		if not fix06_31_room_filter.is_empty() and archetype_id != fix06_31_room_filter:
			continue
		if fix06_31_audit_phase == "before":
			var environment := _dict(library.environment_archetype(archetype_id))
			var placements: Array = []
			_collect_fix06_31_placements(_dict(definition.get("sequence", {})), scenario_id, "sequence", placements)
			for placement_value in placements:
				var audited := _audit_fix06_31_placement(environment, archetype_id, _dict(placement_value))
				audit_records.append(audited)
				_record_fix06_31_floating_root(floating_roots, audited, scenario_id)
		await _capture_fix06_31_scenario_arrival(library, definition, failures, audit_records)
	var roots: Array = floating_roots.values()
	roots.sort_custom(func(a: Variant, b: Variant) -> bool: return str(_dict(a).get("root_key", "")) < str(_dict(b).get("root_key", "")))
	var verdict_counts: Dictionary = {}
	var class_counts: Dictionary = {}
	var room_counts: Dictionary = {}
	for record_value in audit_records:
		var record := _dict(record_value)
		var verdict := str(record.get("verdict", ""))
		var placement_class := str(record.get("placement_class", ""))
		var room_id := str(record.get("archetype_id", ""))
		verdict_counts[verdict] = int(verdict_counts.get(verdict, 0)) + 1
		class_counts[placement_class] = int(class_counts.get(placement_class, 0)) + 1
		var room := _dict(room_counts.get(room_id, {}))
		room[verdict] = int(room.get(verdict, 0)) + 1
		room_counts[room_id] = room
	_write_fix06_31_json("%s/floating_people_inventory_%s.json" % [out_dir, fix06_31_audit_phase], {"schema": "fix06_31_floating_people_inventory/v1", "root_count": roots.size(), "roots": roots})
	_write_fix06_31_json("%s/grounding_audit_%s.json" % [out_dir, fix06_31_audit_phase], {
		"schema": "fix06_31_environment_object_audit/v1",
		"phase": fix06_31_audit_phase,
		"production_scene": "res://scenes/main.tscn",
		"scenario_count": definitions.size(),
		"record_count": audit_records.size(),
		"verdict_counts": verdict_counts,
		"placement_class_counts": class_counts,
		"room_counts": room_counts,
		"baseline_rooms": baseline_report,
		"records": audit_records,
		"failures": failures,
	})
	print("FIX06_31_ENVIRONMENT_AUDIT %s scenarios=%d records=%d floating_roots=%d failures=%d out=%s" % [fix06_31_audit_phase.to_upper(), definitions.size(), audit_records.size(), roots.size(), failures.size(), out_dir])
	app.free()
	app = null
	await _settle(8)
	quit(0 if failures.is_empty() else 1)


func _capture_fix06_31_scenario_arrival(library: Variant, definition: Dictionary, failures: Array, audit_records: Array) -> void:
	var scenario_id := str(definition.get("id", ""))
	var archetype_id := str(definition.get("archetype_id", ""))
	var original_pool: Array = _array(library.environment_scenarios.get(archetype_id, [])).duplicate(true)
	library.environment_scenarios[archetype_id] = [definition.duplicate(true)]
	var run_state := RunStateScript.new()
	run_state.start_new("%s-%s" % [FIX06_31_SEED, scenario_id])
	var generator := RunGeneratorScript.new(library)
	var local_failures: Array = []
	var initial := HarnessProductionFidelityScript.generate_and_finalize(generator, run_state, local_failures, "%s initial" % scenario_id)
	var target_node := _fix06_31_node_for_archetype(run_state, archetype_id)
	var arrival: Dictionary = initial if str(run_state.current_environment.get("archetype_id", "")) == archetype_id else {}
	if bool(initial.get("ok", false)) and arrival.is_empty() and not target_node.is_empty():
		arrival = HarnessProductionFidelityScript.travel_and_finalize(generator, run_state, target_node, true, library, local_failures, "%s arrival" % scenario_id)
	if not bool(arrival.get("ok", false)):
		failures.append_array(local_failures)
		library.environment_scenarios[archetype_id] = original_pool
		return
	# The capture is a room-layout audit, not a run-loss test. Long graph routes can
	# legitimately consume the starter bankroll before the production canvas is
	# attached; keep that unrelated terminal screen from replacing the room under
	# inspection after arrival has already finalized successfully.
	run_state.bankroll = maxi(run_state.bankroll, 10000)
	run_state.run_status = RunStateScript.RUN_STATUS_ACTIVE
	run_state.run_failure_reason = ""
	run_state.run_failure_message = ""
	app.set("run_state", run_state)
	app.set("generator", generator)
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_clear_selected_game_action")
	# Arrival was already generated and finalized above. Render that exact room
	# directly so this visual audit does not run an unrelated stranded-state
	# evaluation before the screenshot is taken.
	app.call("_render_environment_screen")
	await _settle(3)
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var clean_path := "%s/states/%s_arrival_clean.png" % [out_dir, scenario_id]
	image.save_png(clean_path)
	var annotated := _fix06_31_annotated_image(image, archetype_id)
	annotated.save_png("%s/states/%s_arrival_annotated.png" % [out_dir, scenario_id])
	_fix06_31_save_live_floating_crops(image, scenario_id, archetype_id)
	if fix06_31_audit_phase == "after":
		_collect_fix06_31_live_records(run_state.current_environment, scenario_id, archetype_id, audit_records, failures)
	library.environment_scenarios[archetype_id] = original_pool


func _collect_fix06_31_live_records(environment: Dictionary, scenario_id: String, archetype_id: String, output: Array, failures: Array) -> void:
	var canvas: Variant = app.get("environment_canvas")
	var snapshot: Dictionary = canvas.call("current_view_snapshot") if canvas != null else {}
	var object_layout := _dict(snapshot.get("object_layout", {}))
	var rects_by_id: Dictionary = {}
	var rect_sources: Dictionary = {}
	for layout_value in _array(object_layout.get("objects", [])):
		var layout_entry := _dict(layout_value)
		var layout_id := str(layout_entry.get("id", ""))
		rects_by_id[layout_id] = _rect(layout_entry.get("rect", {}))
		rect_sources[layout_id] = "production_canvas"
	var generated_layout := _dict(environment.get("layout", {}))
	var placement_classes := _dict(generated_layout.get("placement_classes", {}))
	for object_id_value in _dict(generated_layout.get("object_rects", {})).keys():
		var object_id := str(object_id_value)
		rects_by_id[object_id] = _fix06_31_pixel_rect(_dict(generated_layout.get("object_rects", {})).get(object_id, {}))
		rect_sources[object_id] = "generated_layout"
	for authority_value in _dict(environment.get("scenario_layout_authority", {})).values():
		var authority := _dict(authority_value)
		var presentation_id := str(authority.get("presentation_object_id", authority.get("identity", "")))
		if not presentation_id.is_empty():
			rects_by_id[presentation_id] = _fix06_31_pixel_rect(authority.get("normalized_hit_rect", {}))
			rect_sources[presentation_id] = "sealed_scenario_authority"
	for error_value in _array(generated_layout.get("placement_errors", [])):
		failures.append("%s base placement error: %s" % [scenario_id, str(error_value)])
	for fallback_value in _array(generated_layout.get("placement_fallback_ids", [])):
		failures.append("%s base fallback placement: %s" % [scenario_id, str(fallback_value)])
	for object_value in _array(snapshot.get("objects", [])):
		var object_data := _dict(object_value)
		if not bool(object_data.get("visible", true)):
			continue
		var object_id := str(object_data.get("id", ""))
		var object_type := str(object_data.get("object_type", object_data.get("type", "")))
		if object_id == "scenario::presentation_failure":
			failures.append("%s production presentation fallback: %s" % [scenario_id, str(object_data.get("description", object_data.get("disabled_reason", "unknown presentation failure")))])
		var placement_class := str(object_data.get("placement_class", ""))
		if placement_classes.has(object_id):
			placement_class = str(placement_classes.get(object_id, ""))
		if placement_class not in EnvironmentPlacementScript.CLASSES:
			placement_class = EnvironmentPlacementScript.classify(object_data, object_type, object_id, str(object_data.get("prop", object_data.get("icon_key", ""))))
		var rect: Rect2 = rects_by_id.get(object_id, Rect2())
		var valid := EnvironmentPlacementScript.valid_rect(environment, placement_class, rect)
		var verdict := "OK" if valid else "WRONG_SURFACE"
		if not valid and placement_class in ["standing_person", "behind_counter_person", "seated_person", "group"]:
			verdict = "FLOATING"
			failures.append("%s live person %s is not on a valid %s surface." % [scenario_id, object_id, placement_class])
		elif not valid:
			failures.append("%s live object %s is not on a valid %s surface." % [scenario_id, object_id, placement_class])
		output.append({
			"scenario_id": scenario_id, "archetype_id": archetype_id, "state_path": "arrival",
			"stable_object_id": object_id, "label": str(object_data.get("label", "")),
			"placement_class": placement_class, "rect": {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y},
			"rect_source": str(rect_sources.get(object_id, "missing")), "contact_y": rect.end.y,
			"surface_id": str(_dict(generated_layout.get("placement_surfaces", {})).get(object_id, "")),
			"collision_displaced": bool(object_data.get("collision_adjusted", false)), "verdict": verdict,
		})


func _fix06_31_pixel_rect(value: Variant) -> Rect2:
	var rect := _rect(value)
	if rect.end.x <= 1.5 and rect.end.y <= 1.5:
		return Rect2(rect.position * Vector2(900.0, 430.0), rect.size * Vector2(900.0, 430.0))
	return rect


func _record_fix06_31_floating_root(floating_roots: Dictionary, audited: Dictionary, scenario_id: String) -> void:
	var placement_class := str(audited.get("placement_class", ""))
	var verdict := str(audited.get("verdict", ""))
	if placement_class not in ["standing_person", "behind_counter_person", "seated_person", "group"] or verdict not in ["FLOATING", "WRONG_SURFACE"]:
		return
	var root_key: String = "%s|%s|%s" % [str(audited.get("archetype_id", "")), str(audited.get("source_kind", "")), str(audited.get("source_id", ""))]
	if not floating_roots.has(root_key):
		floating_roots[root_key] = {
			"root_key": root_key, "archetype_id": str(audited.get("archetype_id", "")),
			"source_kind": str(audited.get("source_kind", "")), "source_id": str(audited.get("source_id", "")),
			"placement_class": placement_class, "verdict": verdict,
			"contact_y": float(audited.get("contact_y", 0.0)), "floor_y": float(audited.get("floor_y", 0.0)), "instances": [],
		}
	var root := _dict(floating_roots[root_key])
	var instances := _array(root.get("instances", []))
	instances.append({"scenario_id": scenario_id, "state_path": str(audited.get("state_path", "")), "stable_object_id": str(audited.get("stable_object_id", "")), "label": str(audited.get("label", ""))})
	root["instances"] = instances
	floating_roots[root_key] = root


func _fix06_31_save_base_annotation(root_dir: String, file_id: String, archetype_id: String) -> void:
	var clean_path := "%s/base/%s.png" % [root_dir, file_id]
	var image := Image.load_from_file(clean_path)
	if image == null or image.is_empty():
		return
	_fix06_31_annotated_image(image, archetype_id).save_png("%s/base/%s_annotated.png" % [root_dir, file_id])


func _fix06_31_save_live_floating_crops(image: Image, scenario_id: String, archetype_id: String) -> void:
	var canvas: Variant = app.get("environment_canvas")
	if canvas == null:
		return
	var transform: Transform2D = canvas.get_global_transform_with_canvas()
	var floor_y := _fix06_31_floor_y(archetype_id)
	var object_layout := _canvas_object_layout()
	for object_value in _array(object_layout.get("objects", [])):
		var object_data := _dict(object_value)
		var object_id := str(object_data.get("id", ""))
		if not object_id.begins_with("scenario::"):
			continue
		var rect := _rect(object_data.get("rect", {}))
		if rect.end.y >= floor_y:
			continue
		var top_left := transform * rect.position - Vector2(28.0, 44.0)
		var bottom_right := transform * rect.end + Vector2(28.0, 44.0)
		var crop := Rect2i(
			clampi(int(floor(top_left.x)), 0, image.get_width() - 1),
			clampi(int(floor(top_left.y)), 0, image.get_height() - 1),
			maxi(1, mini(int(ceil(bottom_right.x - top_left.x)), image.get_width() - clampi(int(floor(top_left.x)), 0, image.get_width() - 1))),
			maxi(1, mini(int(ceil(bottom_right.y - top_left.y)), image.get_height() - clampi(int(floor(top_left.y)), 0, image.get_height() - 1)))
		)
		var stable_id := object_id.trim_prefix("scenario::").validate_filename()
		image.get_region(crop).save_png("%s/floating_people/%s__%s.png" % [out_dir, scenario_id, stable_id])


func _fix06_31_annotated_image(source: Image, archetype_id: String) -> Image:
	var result := source.duplicate() as Image
	var canvas: Variant = app.get("environment_canvas")
	if canvas == null:
		return result
	var transform: Transform2D = canvas.get_global_transform_with_canvas()
	var floor_y := _fix06_31_floor_y(archetype_id)
	var left := transform * Vector2(0.0, floor_y)
	var right := transform * Vector2(900.0, floor_y)
	_fix06_31_image_line(result, left, right, Color("#00ff88"), 3)
	var surface_map := _dict(fix06_31_surface_maps.get(archetype_id, {}))
	for band_value in _array(_dict(surface_map.get("floor", {})).get("bands", [])):
		var band := _rect_from_array(band_value)
		_fix06_31_image_rect(result, Rect2(transform * band.position, transform * band.end - transform * band.position), Color("#00aa66"), 2)
	for counter_value in _array(surface_map.get("counters", [])):
		var counter := _dict(counter_value)
		_fix06_31_image_line(result, transform * Vector2(float(counter.get("x0", 0.0)), float(counter.get("top_y", 0.0))), transform * Vector2(float(counter.get("x1", 0.0)), float(counter.get("top_y", 0.0))), Color("#33aaff"), 3)
	for doorway_value in _array(surface_map.get("doorways", [])):
		var doorway := _rect_from_array(_dict(doorway_value).get("bounds", []))
		_fix06_31_image_rect(result, Rect2(transform * doorway.position, transform * doorway.end - transform * doorway.position), Color("#aa66ff"), 2)
	for void_value in _array(surface_map.get("void", [])):
		var void_rect := _rect_from_array(_dict(void_value).get("bounds", []))
		_fix06_31_image_rect(result, Rect2(transform * void_rect.position, transform * void_rect.end - transform * void_rect.position), Color("#ff3344"), 3)
	var object_layout := _canvas_object_layout()
	for object_value in _array(object_layout.get("objects", [])):
		var object_data := _dict(object_value)
		var rect := _rect(object_data.get("rect", {}))
		var top_left := transform * rect.position
		var bottom_right := transform * rect.end
		_fix06_31_image_rect(result, Rect2(top_left, bottom_right - top_left), Color("#ffcc33"), 2)
		var contact := transform * Vector2(rect.get_center().x, rect.end.y)
		result.fill_rect(Rect2i(int(contact.x) - 3, int(contact.y) - 3, 7, 7), Color("#ff3366"))
	return result


func _fix06_31_image_line(image: Image, from: Vector2, to: Vector2, color: Color, width: int) -> void:
	var x0 := int(round(from.x))
	var y0 := int(round(from.y))
	var x1 := int(round(to.x))
	var y1 := int(round(to.y))
	var steps := maxi(1, maxi(absi(x1 - x0), absi(y1 - y0)))
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var x := int(round(lerpf(float(x0), float(x1), t)))
		var y := int(round(lerpf(float(y0), float(y1), t)))
		image.fill_rect(Rect2i(x - width / 2, y - width / 2, width, width), color)


func _fix06_31_image_rect(image: Image, rect: Rect2, color: Color, width: int) -> void:
	var clean := Rect2i(int(rect.position.x), int(rect.position.y), maxi(1, int(rect.size.x)), maxi(1, int(rect.size.y)))
	image.fill_rect(Rect2i(clean.position.x, clean.position.y, clean.size.x, width), color)
	image.fill_rect(Rect2i(clean.position.x, clean.end.y - width, clean.size.x, width), color)
	image.fill_rect(Rect2i(clean.position.x, clean.position.y, width, clean.size.y), color)
	image.fill_rect(Rect2i(clean.end.x - width, clean.position.y, width, clean.size.y), color)


func _fix06_31_scenario_definitions(library: Variant) -> Array:
	var result: Array = []
	for pool_value in library.environment_scenarios.values():
		for definition_value in _array(pool_value):
			var definition := SequenceCatalogScript.apply_overlay(_dict(definition_value), library.scenario_sequence_catalog)
			if not _dict(definition.get("sequence", {})).is_empty():
				result.append(definition.duplicate(true))
	result.sort_custom(func(a: Variant, b: Variant) -> bool: return str(_dict(a).get("id", "")) < str(_dict(b).get("id", "")))
	return result


func _collect_fix06_31_placements(value: Variant, scenario_id: String, path: String, output: Array) -> void:
	if typeof(value) == TYPE_ARRAY:
		var values := value as Array
		for index in range(values.size()):
			_collect_fix06_31_placements(values[index], scenario_id, "%s[%d]" % [path, index], output)
		return
	if typeof(value) != TYPE_DICTIONARY:
		return
	var data := value as Dictionary
	for key_value in data.keys():
		var key := str(key_value)
		var child: Variant = data.get(key_value)
		if key in ["actor_ops", "scene_ops"] and typeof(child) == TYPE_ARRAY:
			var operations := child as Array
			for index in range(operations.size()):
				var operation := _dict(operations[index])
				var payload_key := "actor" if key == "actor_ops" else "object"
				var payload := _dict(operation.get(payload_key, {}))
				var anchor_id := str(operation.get("anchor_id", payload.get("anchor_id", "")))
				var zone_id := str(operation.get("zone_id", payload.get("zone_id", "")))
				if anchor_id.is_empty() and zone_id.is_empty() and not operation.has("position") and not payload.has("position"):
					continue
				output.append({"scenario_id": scenario_id, "state_path": "%s.%s[%d]" % [path, key, index], "family": key, "operation": operation, "payload": payload})
		else:
			_collect_fix06_31_placements(child, scenario_id, "%s.%s" % [path, key], output)


func _audit_fix06_31_placement(environment: Dictionary, archetype_id: String, placement: Dictionary) -> Dictionary:
	var operation := _dict(placement.get("operation", {}))
	var payload := _dict(placement.get("payload", {}))
	var family := str(placement.get("family", ""))
	var anchor_id := str(operation.get("anchor_id", payload.get("anchor_id", "")))
	var zone_id := str(operation.get("zone_id", payload.get("zone_id", "")))
	var center := ScenarioLayoutResolverScript._resolve_center(environment, anchor_id, zone_id)
	var position: Variant = operation.get("position", payload.get("position", null))
	if position != null:
		center = _vector(position, center)
	var default_size := Vector2(72.0, 80.0) if family == "actor_ops" else Vector2(48.0, 48.0)
	var bounds := _dict(payload.get("bounds", {}))
	var size := Vector2(float(bounds.get("w", default_size.x)), float(bounds.get("h", default_size.y)))
	var rect := ScenarioLayoutResolverScript._clamp_inside_board(Rect2(center - size * 0.5, size))
	var placement_class := EnvironmentPlacementScript.classify(payload.merged(operation, true), "actor" if family == "actor_ops" else "scene_object", str(operation.get("stable_object_id", "")), str(payload.get("prop", payload.get("icon_key", ""))))
	var floor_y := _fix06_31_floor_y(archetype_id)
	var verdict := _baseline_fix06_31_verdict(placement_class, rect, floor_y)
	return {
		"scenario_id": str(placement.get("scenario_id", "")),
		"archetype_id": archetype_id,
		"state_path": str(placement.get("state_path", "")),
		"family": family,
		"op": str(operation.get("op", "")),
		"stable_object_id": str(operation.get("stable_object_id", "")),
		"label": str(payload.get("label", "")),
		"role": str(payload.get("role", "")),
		"placement_class": placement_class,
		"source_kind": "anchor" if not anchor_id.is_empty() else "zone" if not zone_id.is_empty() else "position",
		"source_id": anchor_id if not anchor_id.is_empty() else zone_id if not zone_id.is_empty() else "explicit",
		"rect": {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y},
		"contact": "feet" if placement_class in ["standing_person", "behind_counter_person", "seated_person", "group"] else "base" if placement_class in ["floor_fixture", "ground_marker"] else "surface" if placement_class == "surface_item" else "mount" if placement_class in ["wall_mounted", "hanging"] else "edge",
		"contact_y": rect.end.y,
		"floor_y": floor_y,
		"collision_displaced": false,
		"verdict": verdict,
	}


func _baseline_fix06_31_verdict(placement_class: String, rect: Rect2, floor_y: float) -> String:
	if placement_class in ["standing_person", "group"]:
		return "FLOATING" if rect.end.y < floor_y else "OK"
	if placement_class in ["behind_counter_person", "seated_person"]:
		return "WRONG_SURFACE" if rect.end.y < 150.0 or rect.end.y > floor_y + 56.0 else "OK"
	if placement_class in ["floor_fixture", "ground_marker"]:
		return "WRONG_SURFACE" if rect.end.y < floor_y else "OK"
	if placement_class == "surface_item":
		return "FLOATING" if rect.end.y < 100.0 or rect.end.y > floor_y + 40.0 else "OK"
	if placement_class in ["wall_mounted", "hanging"]:
		return "WRONG_SURFACE" if rect.end.y > floor_y else "OK"
	if placement_class == "doorway":
		return "SEMANTIC_MISMATCH" if rect.get_center().x > 180.0 and rect.get_center().x < 720.0 else "OK"
	return "OK"


func _fix06_31_floor_y(archetype_id: String) -> float:
	var surface_map := _dict(fix06_31_surface_maps.get(archetype_id, {}))
	var bands := _array(_dict(surface_map.get("floor", {})).get("bands", []))
	if not bands.is_empty():
		return _rect_from_array(bands[0]).position.y
	return float(FIX06_31_FLOOR_Y.get(archetype_id, 246.0))


func _load_fix06_31_surface_maps(failures: Array) -> Dictionary:
	var file := FileAccess.open("res://data/environments/placement_surfaces.json", FileAccess.READ)
	if file == null:
		failures.append("Placement surface map data could not be opened.")
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("Placement surface map data is not a dictionary.")
		return {}
	var index: Dictionary = {}
	for map_value in _array(_dict(parsed).get("maps", [])):
		var surface_map := _dict(map_value)
		var map_id := str(surface_map.get("id", ""))
		if map_id.is_empty() or index.has(map_id):
			failures.append("Placement surface map id is empty or duplicated: %s." % map_id)
			continue
		index[map_id] = surface_map
	return index


func _fix06_31_node_for_archetype(run_state: Variant, archetype_id: String) -> String:
	for node_value in _array(run_state.world_map.get("nodes", [])):
		var node := _dict(node_value)
		if str(node.get("archetype_id", "")) == archetype_id:
			return str(node.get("id", ""))
	return ""


func _write_fix06_31_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))
		file.close()


func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []


func _vector(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value
	if typeof(value) == TYPE_ARRAY:
		var values := value as Array
		if values.size() >= 2:
			return Vector2(float(values[0]), float(values[1]))
	if typeof(value) == TYPE_DICTIONARY:
		var data := value as Dictionary
		return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))
	return fallback


func _rect(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value
	var data := _dict(value)
	return Rect2(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("w", 0.0)), float(data.get("h", 0.0)))


func _rect_from_array(value: Variant) -> Rect2:
	var values := _array(value)
	if values.size() < 4:
		return Rect2()
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


func _survey_home_containers(profile: Dictionary) -> Array:
	var containers: Array = []
	var index := 0
	var container_values: Array = profile.get("starting_containers", []) if typeof(profile.get("starting_containers", [])) == TYPE_ARRAY else []
	for container_value in container_values:
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = container_value
		var item_id := str(entry.get("item_id", entry.get("id", ""))).strip_edges()
		if item_id.is_empty():
			continue
		index += 1
		containers.append({
			"id": "%s_%02d" % [item_id, index],
			"item_id": item_id,
			"display_name": item_id.replace("_", " ").capitalize(),
			"capacity": maxi(0, int(entry.get("capacity", 0))),
			"items": [],
		})
	return containers


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame
