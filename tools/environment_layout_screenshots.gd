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
const RW06_1_Q008_ARCHETYPE_IDS := ["bar", "corner_store", "grand_casino"]
const RW06_1_PHYSICAL_COUNT_KEYS := ["physical_room_count", "room_physical_count"]
const RW06_1_SLOT_MARKER_COLORS := {
	"base": Color("#58c7ff"),
	"stage": Color("#f5c451"),
	"exit": Color("#ff6fae"),
}


class SlotMarkerOverlay:
	extends Control

	var markers: Array = []
	var legend_origin := Vector2(16.0, 24.0)

	func configure(next_markers: Array, next_legend_origin: Vector2) -> void:
		markers = next_markers.duplicate(true)
		legend_origin = next_legend_origin
		queue_redraw()

	func _draw() -> void:
		for marker_value in markers:
			var marker := marker_value as Dictionary
			var color: Color = marker.get("color", Color.WHITE)
			var viewport_rect: Rect2 = marker.get("viewport_rect", Rect2())
			var viewport_position: Vector2 = marker.get("viewport_position", viewport_rect.get_center())
			if viewport_rect.has_area():
				draw_rect(viewport_rect, Color(color.r, color.g, color.b, 0.13), true)
				draw_rect(viewport_rect, color, false, 2.0)
			draw_circle(viewport_position, 12.0, Color("#080b12"))
			draw_circle(viewport_position, 12.0, color, false, 3.0)
			var number_text := str(marker.get("number", "?"))
			draw_string(ThemeDB.fallback_font, viewport_position + Vector2(-12.0, 4.0), number_text, HORIZONTAL_ALIGNMENT_CENTER, 24.0, 12, Color.WHITE)
		var legend_x := legend_origin.x
		for kind_value in ["base", "stage", "exit"]:
			var kind := str(kind_value)
			var color := Color("#58c7ff")
			if kind == "stage":
				color = Color("#f5c451")
			elif kind == "exit":
				color = Color("#ff6fae")
			draw_rect(Rect2(legend_x, legend_origin.y - 12.0, 14.0, 14.0), Color("#080b12"), true)
			draw_rect(Rect2(legend_x, legend_origin.y - 12.0, 14.0, 14.0), color, false, 2.0)
			draw_string(ThemeDB.fallback_font, Vector2(legend_x + 19.0, legend_origin.y), kind.capitalize(), HORIZONTAL_ALIGNMENT_LEFT, 58.0, 11, Color.WHITE)
			legend_x += 82.0

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
var rw06_1_day2_only := false
var rw06_1_static_report := "res://.tmp/rw06_1/static/slot_report.json"
var rw06_1_slot_markers := false
var rw06_1_q008 := false


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
		elif argument == "--rw06-1-day2-only":
			rw06_1_day2_only = true
		elif argument.begins_with("--rw06-1-static-report="):
			rw06_1_static_report = argument.trim_prefix("--rw06-1-static-report=")
		elif argument == "--rw06-1-slot-markers":
			rw06_1_slot_markers = true
		elif argument == "--rw06-1-q008":
			rw06_1_q008 = true
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
	if rw06_1_slot_markers:
		await _run_rw06_1_slot_markers(library)
		return
	if rw06_1_q008:
		await _run_rw06_1_q008(library)
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
	if rw06_1_day2_only:
		selections = selections.filter(func(selection_value: Variant) -> bool:
			return bool(_dict(selection_value).get("day2_sample", false))
		)
	var expected_room_count := 3 if rw06_1_day2_only else 18
	if selections.size() != expected_room_count:
		failures.append("rw06_1 contact-sheet manifest must contain %d rooms; found %d." % [expected_room_count, selections.size()])
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
	_rw06_1_remove_stale_contact_artifacts(selections)
	var capture_rows: Array = []
	var capture_attempts: Array = []
	var player_view_failure := false
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
		capture_attempts.append(captured.duplicate(true))
		if not bool(captured.get("player_view_clean", false)):
			player_view_failure = true
		if not bool(captured.get("ok", false)):
			failures.append_array(_array(captured.get("errors", ["%s could not be captured." % archetype_id])))
			continue
		capture_rows.append(captured)
	# One dirty source invalidates the whole player-view set. Do not leave a
	# partial 1/3 or 2/3 sample that could be mistaken for owner-review evidence.
	if player_view_failure:
		_rw06_1_remove_contact_source_images(selections)
		capture_rows.clear()
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
		"capture_attempts": capture_attempts,
		"player_view_cleanliness": {
			"required": true,
			"passed": not player_view_failure and capture_rows.size() == expected_room_count,
			"attempted_room_count": capture_attempts.size(),
			"accepted_room_count": capture_rows.size(),
			"accepted_source_capture_count": capture_rows.size() * 2,
			"fail_closed_zero_rows": player_view_failure and capture_rows.is_empty(),
		},
		"all_rooms_sheet": full_sheet,
		"day2_sheet": day2_sheet,
		"failures": failures,
	}
	_write_fix06_31_json("%s/contact_sheet_report.json" % out_dir, report_payload)
	print("RW06_1_CONTACT_SHEET rooms=%d day2=%d failures=%d out=%s" % [capture_rows.size(), day2_rows.size(), failures.size(), out_dir])
	app.free()
	app = null
	await _settle(4)
	quit(0 if failures.is_empty() and capture_rows.size() == expected_room_count and day2_rows.size() == 3 else 1)


func _run_rw06_1_q008(library: Variant) -> void:
	var failures: Array = []
	var static_report := _rw06_1_read_json(rw06_1_static_report)
	if static_report.is_empty():
		failures.append("Q-008 static report is missing or invalid: %s." % rw06_1_static_report)
	elif not bool(static_report.get("passed", false)):
		failures.append("Q-008 refuses to capture from a failing static report.")
	var selection_result := _rw06_1_q008_selections(static_report)
	failures.append_array(_array(selection_result.get("errors", [])))
	var selections := _array(selection_result.get("selections", []))
	var definitions: Dictionary = {}
	for definition_value in _fix06_31_scenario_definitions(library):
		var definition := _dict(definition_value)
		definitions[str(definition.get("id", ""))] = definition
	var archetypes: Dictionary = {}
	for archetype_value in library.environment_archetypes:
		var archetype := _dict(archetype_value)
		archetypes[str(archetype.get("id", ""))] = archetype
	DirAccess.make_dir_recursive_absolute("%s/q008_sources" % out_dir)
	_rw06_1_remove_q008_artifacts()
	var capture_attempts: Array = []
	var captures: Array = []
	if failures.is_empty():
		for selection_value in selections:
			var selection := _dict(selection_value)
			var archetype_id := str(selection.get("archetype_id", ""))
			var scenario_id := str(selection.get("scenario_id", ""))
			var base_selection := {
				"archetype_id": archetype_id,
				"map_id": archetype_id,
				"layer_id": "",
				"scenario_id": "",
				"phase_id": "base_inventory",
				"capture_role": "base",
			}
			var room_attempt := {
				"archetype_id": archetype_id,
				"selection": selection.duplicate(true),
				"base": {},
				"busiest_physical": {},
				"errors": [],
			}
			var prepared_base := await _rw06_1_prepare_base_room(_dict(archetypes.get(archetype_id, {})), library)
			if not bool(prepared_base.get("ok", false)):
				room_attempt["errors"] = _array(prepared_base.get("errors", ["%s base room could not be prepared." % archetype_id]))
				failures.append_array(_array(room_attempt.get("errors", [])))
				capture_attempts.append(room_attempt)
				continue
			var base_capture := await _rw06_1_capture_normal_source(
				base_selection,
				"%s/q008_sources/%s_base.png" % [out_dir, archetype_id]
			)
			room_attempt["base"] = base_capture
			if not bool(base_capture.get("ok", false)):
				room_attempt["errors"] = _array(room_attempt.get("errors", [])) + _array(base_capture.get("errors", []))
				failures.append_array(_array(base_capture.get("errors", [])))
				capture_attempts.append(room_attempt)
				continue
			var prepared_peak := await _rw06_1_prepare_scenario_peak(_dict(definitions.get(scenario_id, {})), selection, library)
			if not bool(prepared_peak.get("ok", false)):
				room_attempt["errors"] = _array(room_attempt.get("errors", [])) + _array(prepared_peak.get("errors", ["%s busiest physical scenario could not be prepared." % archetype_id]))
				failures.append_array(_array(prepared_peak.get("errors", [])))
				capture_attempts.append(room_attempt)
				continue
			var scenario_selection := selection.duplicate(true)
			scenario_selection["capture_role"] = "busiest_physical"
			var scenario_capture := await _rw06_1_capture_normal_source(
				scenario_selection,
				"%s/q008_sources/%s_busiest_physical.png" % [out_dir, archetype_id]
			)
			room_attempt["busiest_physical"] = scenario_capture
			if not bool(scenario_capture.get("ok", false)):
				room_attempt["errors"] = _array(room_attempt.get("errors", [])) + _array(scenario_capture.get("errors", []))
				failures.append_array(_array(scenario_capture.get("errors", [])))
			capture_attempts.append(room_attempt.duplicate(true))
			if _array(room_attempt.get("errors", [])).is_empty():
				captures.append(room_attempt)
	var complete_source_set := failures.is_empty() and captures.size() == RW06_1_Q008_ARCHETYPE_IDS.size()
	var sheet: Dictionary = {
		"ok": false,
		"path": "%s/q008_rooms.png" % out_dir,
		"errors": ["Q-008 source set is incomplete; sheet was not created."],
	}
	if complete_source_set:
		sheet = _rw06_1_build_q008_sheet(captures, "%s/q008_rooms.png" % out_dir)
		if not bool(sheet.get("ok", false)):
			failures.append_array(_array(sheet.get("errors", [])))
			complete_source_set = false
	if not complete_source_set:
		_rw06_1_remove_q008_source_images()
		_rw06_1_remove_file("%s/q008_rooms.png" % out_dir)
		captures.clear()
	var report_payload := {
		"schema": "rw06_1_q008_room_proof/v1",
		"generated_at_utc": Time.get_datetime_string_from_system(true),
		"project_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"source_static_report": rw06_1_static_report,
		"source_static_report_sha256": FileAccess.get_sha256(rw06_1_static_report) if FileAccess.file_exists(rw06_1_static_report) else "",
		"selection_source": str(selection_result.get("source_field", "")),
		"required_archetype_ids": RW06_1_Q008_ARCHETYPE_IDS.duplicate(),
		"normal_only": true,
		"grid": {"columns": 3, "rows": 2, "top_row": "base", "bottom_row": "busiest_physical"},
		"capture_source": "production_root_viewport_texture",
		"source_post_processed": false,
		"sheet_post_processed": true,
		"accepted_source_capture_count": captures.size() * 2,
		"captures": captures,
		"capture_attempts": capture_attempts,
		"sheet": sheet,
		"passed": complete_source_set and bool(sheet.get("ok", false)),
		"fail_closed_zero_rooms": not complete_source_set and captures.is_empty(),
		"failures": failures,
	}
	_write_fix06_31_json("%s/q008_rooms.json" % out_dir, report_payload)
	print("RW06_1_Q008 rooms=%d sources=%d failures=%d out=%s" % [captures.size(), captures.size() * 2, failures.size(), out_dir])
	app.free()
	app = null
	await _settle(4)
	quit(0 if bool(report_payload.get("passed", false)) else 1)


func _rw06_1_q008_selections(static_report: Dictionary) -> Dictionary:
	var failures: Array = []
	var source_field := ""
	var source_rows: Array = []
	for field_value in ["q008_rooms", "q008_contact_sheet", "contact_sheet"]:
		var field := str(field_value)
		var candidate := _array(static_report.get(field, []))
		if not candidate.is_empty():
			source_field = field
			source_rows = candidate
			break
	if source_rows.is_empty():
		return {"ok": false, "selections": [], "source_field": source_field, "errors": ["Static report contains no Q-008/contact-sheet selections."]}
	var selections: Array = []
	for archetype_value in RW06_1_Q008_ARCHETYPE_IDS:
		var archetype_id := str(archetype_value)
		var matches: Array = []
		for row_value in source_rows:
			var row := _dict(row_value)
			if str(row.get("archetype_id", "")) == archetype_id:
				matches.append(row)
		if matches.size() != 1:
			failures.append("Static report must contain exactly one Q-008 selection for %s; found %d." % [archetype_id, matches.size()])
			continue
		var selection := _dict(matches[0]).duplicate(true)
		var physical_count := _rw06_1_physical_room_count(selection)
		if physical_count < 0:
			failures.append("Static Q-008 selection for %s has no explicit physical_room_count." % archetype_id)
			continue
		if str(selection.get("scenario_id", "")).is_empty() or str(selection.get("phase_id", "")).is_empty():
			failures.append("Static Q-008 selection for %s has no scenario/phase." % archetype_id)
			continue
		selection["physical_room_count"] = physical_count
		selection["_capture_peak_metric"] = "scenario_room_physical_count"
		selection["_expected_peak_count"] = physical_count
		selection["_static_selection_source"] = source_field
		selections.append(selection)
	# The selected row alone is not proof that it is busiest. Recompute each room
	# maximum from the static report's per-scenario peaks and reject stale sheets.
	var summaries := _array(static_report.get("active_scenarios", []))
	for selection_value in selections:
		var selection := _dict(selection_value)
		var archetype_id := str(selection.get("archetype_id", ""))
		var candidates: Array = []
		for summary_value in summaries:
			var summary := _dict(summary_value)
			if str(summary.get("map_id", "")).split(":", true, 1)[0] != archetype_id:
				continue
			var peak := _dict(summary.get("peak", {}))
			var count := _rw06_1_physical_room_count(peak)
			if count >= 0:
				candidates.append({
					"map_id": str(summary.get("map_id", "")),
					"scenario_id": str(summary.get("scenario_id", "")),
					"phase_id": str(peak.get("phase_id", "")),
					"physical_room_count": count,
				})
		if candidates.is_empty():
			failures.append("Static report exposes no per-scenario physical peak census for %s." % archetype_id)
			continue
		var maximum := 0
		for candidate_value in candidates:
			maximum = maxi(maximum, int(_dict(candidate_value).get("physical_room_count", -1)))
		var selected_matches_peak := false
		for candidate_value in candidates:
			var candidate := _dict(candidate_value)
			if str(candidate.get("scenario_id", "")) == str(selection.get("scenario_id", "")) \
					and str(candidate.get("phase_id", "")) == str(selection.get("phase_id", "")) \
					and int(candidate.get("physical_room_count", -1)) == maximum:
				selected_matches_peak = true
				break
		if int(selection.get("physical_room_count", -1)) != maximum or not selected_matches_peak:
			failures.append("Static Q-008 selection for %s is not its busiest physical scenario (%d versus room maximum %d)." % [archetype_id, int(selection.get("physical_room_count", -1)), maximum])
	return {
		"ok": failures.is_empty() and selections.size() == RW06_1_Q008_ARCHETYPE_IDS.size(),
		"selections": selections,
		"source_field": source_field,
		"errors": failures,
	}


func _rw06_1_physical_room_count(value: Dictionary) -> int:
	for key_value in RW06_1_PHYSICAL_COUNT_KEYS:
		var key := str(key_value)
		if value.has(key):
			return int(value.get(key, -1))
	var peak := _dict(value.get("peak", {}))
	if not peak.is_empty():
		for key_value in RW06_1_PHYSICAL_COUNT_KEYS:
			var key := str(key_value)
			if peak.has(key):
				return int(peak.get(key, -1))
	return -1


func _rw06_1_capture_normal_source(selection: Dictionary, path: String) -> Dictionary:
	var archetype_id := str(selection.get("archetype_id", ""))
	var canvas: Variant = app.get("environment_canvas")
	if canvas == null:
		return {"ok": false, "player_view_clean": false, "path": path, "errors": ["%s has no production environment canvas." % archetype_id]}
	_rw06_1_clear_player_view_artifacts(canvas)
	canvas.call("set_small_screen_mode", false)
	canvas.call("queue_redraw")
	await _settle(3)
	_rw06_1_clear_player_view_artifacts(canvas)
	canvas.call("queue_redraw")
	await _settle(1)
	await RenderingServer.frame_post_draw
	var cleanliness := _rw06_1_player_view_cleanliness(canvas, archetype_id, "normal")
	var failures: Array = []
	if not bool(cleanliness.get("ok", false)):
		failures.append_array(_array(cleanliness.get("errors", ["%s normal player view is not clean." % archetype_id])))
	else:
		var image := root.get_viewport().get_texture().get_image()
		var save_error := image.save_png(path)
		if save_error != OK:
			failures.append("%s normal capture could not be written to %s (%s)." % [archetype_id, path, error_string(save_error)])
	if not failures.is_empty():
		_rw06_1_remove_file(path)
	var object_layout := _canvas_object_layout()
	return {
		"ok": failures.is_empty(),
		"player_view_clean": failures.is_empty() and bool(cleanliness.get("ok", false)),
		"selection": selection.duplicate(true),
		"mode": "normal",
		"path": path,
		"sha256": FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "",
		"capture_source": "production_root_viewport_texture",
		"post_processed": false,
		"player_view_cleanliness": cleanliness,
		"object_layout": object_layout,
		"direct_interaction_overlaps": _direct_interaction_overlaps(object_layout),
		"errors": failures,
	}


func _rw06_1_build_q008_sheet(captures: Array, path: String) -> Dictionary:
	var failures: Array = []
	if captures.size() != RW06_1_Q008_ARCHETYPE_IDS.size():
		return {"ok": false, "path": path, "errors": ["Q-008 sheet requires exactly three rooms."], "cells": []}
	var cell_size := Vector2i(320, 180)
	var sheet := Image.create(cell_size.x * 3, cell_size.y * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#10151f"))
	var cells: Array = []
	for column in range(captures.size()):
		var room := _dict(captures[column])
		for row in range(2):
			var capture_role := "base" if row == 0 else "busiest_physical"
			var source_record := _dict(room.get(capture_role, {}))
			var source_path := str(source_record.get("path", ""))
			var source := Image.load_from_file(source_path)
			if source == null or source.is_empty():
				failures.append("Q-008 source is missing: %s." % source_path)
				continue
			source.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_LANCZOS)
			var destination := Vector2i(column * cell_size.x, row * cell_size.y)
			sheet.blit_rect(source, Rect2i(Vector2i.ZERO, cell_size), destination)
			_rw06_1_image_border(sheet, Rect2i(destination, cell_size), Color("#58c7ff") if row == 0 else Color("#f5c451"), 3)
			var selection := _dict(source_record.get("selection", {}))
			cells.append({
				"archetype_id": str(room.get("archetype_id", "")),
				"capture_role": capture_role,
				"scenario_id": str(selection.get("scenario_id", "")),
				"phase_id": str(selection.get("phase_id", "")),
				"mode": "normal",
				"source_path": source_path,
				"source_sha256": str(source_record.get("sha256", "")),
				"rect": {"x": destination.x, "y": destination.y, "w": cell_size.x, "h": cell_size.y},
			})
	if not failures.is_empty():
		return {"ok": false, "path": path, "errors": failures, "cells": cells}
	var save_error := sheet.save_png(path)
	if save_error != OK:
		failures.append("Q-008 sheet could not be written to %s (%s)." % [path, error_string(save_error)])
	return {
		"ok": failures.is_empty(),
		"path": path,
		"sha256": FileAccess.get_sha256(path) if save_error == OK else "",
		"size": {"w": sheet.get_width(), "h": sheet.get_height()},
		"columns": 3,
		"rows": 2,
		"cells": cells,
		"errors": failures,
	}


func _rw06_1_remove_q008_artifacts() -> void:
	_rw06_1_remove_q008_source_images()
	_rw06_1_remove_file("%s/q008_rooms.png" % out_dir)
	_rw06_1_remove_file("%s/q008_rooms.json" % out_dir)


func _rw06_1_remove_q008_source_images() -> void:
	for archetype_value in RW06_1_Q008_ARCHETYPE_IDS:
		var archetype_id := str(archetype_value)
		_rw06_1_remove_file("%s/q008_sources/%s_base.png" % [out_dir, archetype_id])
		_rw06_1_remove_file("%s/q008_sources/%s_busiest_physical.png" % [out_dir, archetype_id])


func _run_rw06_1_slot_markers(library: Variant) -> void:
	var failures: Array = []
	var surface_data := _rw06_1_read_json("res://data/environments/placement_surfaces.json")
	var surface_maps := _array(surface_data.get("maps", []))
	if surface_maps.is_empty():
		failures.append("Slot-marker capture could not load any physical placement maps.")
	surface_maps.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		return str(_dict(left_value).get("id", "")) < str(_dict(right_value).get("id", ""))
	)
	var archetypes: Dictionary = {}
	for archetype_value in library.environment_archetypes:
		var archetype := _dict(archetype_value)
		archetypes[str(archetype.get("id", ""))] = archetype
	var seen_map_ids: Dictionary = {}
	for map_value in surface_maps:
		var map_id := str(_dict(map_value).get("id", ""))
		if map_id.is_empty() or seen_map_ids.has(map_id):
			failures.append("Physical placement map id is empty or duplicated: %s." % map_id)
		seen_map_ids[map_id] = true
	DirAccess.make_dir_recursive_absolute("%s/slot_markers" % out_dir)
	_rw06_1_remove_slot_marker_artifacts(surface_maps)
	var capture_attempts: Array = []
	var captures: Array = []
	if failures.is_empty():
		for map_value in surface_maps:
			var surface_map := _dict(map_value)
			var map_id := str(surface_map.get("id", ""))
			var archetype_id := str(surface_map.get("archetype_id", map_id))
			var archetype := _dict(archetypes.get(archetype_id, {}))
			if archetype.is_empty():
				var missing := {"ok": false, "map_id": map_id, "errors": ["%s names missing archetype %s." % [map_id, archetype_id]]}
				capture_attempts.append(missing)
				failures.append_array(_array(missing.get("errors", [])))
				continue
			var prepared := await _rw06_1_prepare_base_map(surface_map, archetype, library)
			if not bool(prepared.get("ok", false)):
				var preparation_failure := {
					"ok": false,
					"map_id": map_id,
					"errors": _array(prepared.get("errors", ["%s could not be prepared." % map_id])),
				}
				capture_attempts.append(preparation_failure)
				failures.append_array(_array(preparation_failure.get("errors", [])))
				continue
			var captured := await _rw06_1_capture_slot_markers(surface_map)
			capture_attempts.append(captured.duplicate(true))
			if not bool(captured.get("ok", false)):
				failures.append_array(_array(captured.get("errors", ["%s slot markers could not be captured." % map_id])))
				continue
			captures.append(captured)
	var complete_set := failures.is_empty() and captures.size() == surface_maps.size()
	if not complete_set:
		_rw06_1_remove_slot_marker_source_images(surface_maps)
		captures.clear()
	var report_payload := {
		"schema": "rw06_1_fixed_slot_marker_manifest/v1",
		"generated_at_utc": Time.get_datetime_string_from_system(true),
		"project_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"source_surface_data": "res://data/environments/placement_surfaces.json",
		"source_surface_data_sha256": FileAccess.get_sha256("res://data/environments/placement_surfaces.json"),
		"expected_map_count": surface_maps.size(),
		"captured_map_count": captures.size(),
		"capture_source": "production_root_viewport_texture_plus_capture_only_slot_overlay",
		"post_processed": false,
		"empty_room_interactable_count": 0,
		"captures": captures,
		"capture_attempts": capture_attempts,
		"passed": complete_set,
		"fail_closed_zero_maps": not complete_set and captures.is_empty(),
		"failures": failures,
	}
	_write_fix06_31_json("%s/slot_markers/slot_marker_manifest.json" % out_dir, report_payload)
	print("RW06_1_SLOT_MARKERS maps=%d failures=%d out=%s" % [captures.size(), failures.size(), out_dir])
	app.free()
	app = null
	await _settle(4)
	quit(0 if complete_set else 1)


func _rw06_1_prepare_base_map(surface_map: Dictionary, archetype: Dictionary, library: Variant) -> Dictionary:
	var layer_id := str(surface_map.get("layer_id", ""))
	if layer_id.is_empty():
		return await _rw06_1_prepare_base_room(archetype, library)
	var archetype_id := str(surface_map.get("archetype_id", archetype.get("id", "")))
	var run_state: Variant = app.get("run_state")
	var rng: Variant = run_state.create_rng("rw06_1_slot_markers:%s:%s" % [archetype_id, layer_id])
	var environment: Variant = EnvironmentInstance.from_archetype_layer(archetype, layer_id, 1, rng, library, run_state.challenge_config)
	var data: Dictionary = environment.to_dict()
	data["world_node_id"] = archetype_id
	data["layer_discovery"] = {"club": true, "casino": true, "back_room": true}
	var generator := RunGeneratorScript.new(library)
	data["game_states"] = generator.call("_generated_game_states", run_state, data, rng)
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data, library)
	run_state.save_rng(rng)
	run_state.set_environment(data)
	app.call("_clear_selected_game_action")
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_render_environment_screen")
	await _settle(3)
	if str(run_state.current_environment.get("current_layer_id", "")) != layer_id:
		return {"ok": false, "errors": ["%s prepared layer %s but runtime rendered %s." % [archetype_id, layer_id, str(run_state.current_environment.get("current_layer_id", ""))]]}
	return {"ok": true, "errors": []}


func _rw06_1_capture_slot_markers(surface_map: Dictionary) -> Dictionary:
	var failures: Array = []
	var map_id := str(surface_map.get("id", ""))
	var archetype_id := str(surface_map.get("archetype_id", map_id))
	var layer_id := str(surface_map.get("layer_id", ""))
	var canvas: Variant = app.get("environment_canvas")
	if canvas == null:
		return {"ok": false, "map_id": map_id, "errors": ["%s has no production environment canvas." % map_id]}
	var original_snapshot := _dict(canvas.get("foundation_snapshot")).duplicate(true)
	var original_small_screen := bool(canvas.get("small_screen_mode"))
	var original_records := _array(original_snapshot.get("interactable_objects", [])).duplicate(true)
	var empty_snapshot := _rw06_1_empty_room_snapshot(original_snapshot)
	_rw06_1_clear_player_view_artifacts(canvas)
	canvas.call("set_small_screen_mode", false)
	canvas.call("render_environment_snapshot", empty_snapshot)
	var action_list: Variant = app.get("room_action_list")
	if action_list != null and action_list.has_method("render"):
		action_list.call("render", [])
	await _settle(2)
	_rw06_1_clear_player_view_artifacts(canvas)
	canvas.call("queue_redraw")
	await _settle(1)
	var object_layout := _canvas_object_layout()
	var empty_objects := _array(object_layout.get("objects", []))
	if not empty_objects.is_empty():
		failures.append("%s empty-room marker source retained %d interactable objects." % [map_id, empty_objects.size()])
	var cleanliness := _rw06_1_player_view_cleanliness(canvas, archetype_id, "slot_markers")
	if not bool(cleanliness.get("ok", false)):
		failures.append_array(_array(cleanliness.get("errors", ["%s marker source is not clean before its capture-only overlay." % map_id])))
	var marker_result := _rw06_1_slot_marker_rows(surface_map, canvas)
	failures.append_array(_array(marker_result.get("errors", [])))
	var manifest_rows := _array(marker_result.get("manifest", []))
	var overlay_rows := _array(marker_result.get("overlay", []))
	var overlay: SlotMarkerOverlay = null
	var overlay_removed := true
	var marker_view := _dict(canvas.call("current_view_snapshot"))
	var path := "%s/slot_markers/%s.png" % [out_dir, _rw06_1_slot_marker_file_id(map_id)]
	if failures.is_empty():
		overlay = SlotMarkerOverlay.new()
		overlay.name = "RW06_1CaptureOnlySlotMarkers"
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.z_index = 4096
		root.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var legend_origin := (canvas as Control).get_global_rect().position + Vector2(14.0, 24.0)
		overlay.configure(overlay_rows, legend_origin)
		await _settle(2)
		await RenderingServer.frame_post_draw
		var image := root.get_viewport().get_texture().get_image()
		var save_error := image.save_png(path)
		if save_error != OK:
			failures.append("%s slot-marker capture could not be written to %s (%s)." % [map_id, path, error_string(save_error)])
	if overlay != null:
		root.remove_child(overlay)
		overlay.free()
		overlay_removed = not is_instance_valid(overlay)
	_rw06_1_restore_marker_canvas(canvas, original_snapshot, original_small_screen, original_records)
	await _settle(1)
	if not failures.is_empty():
		_rw06_1_remove_file(path)
	return {
		"ok": failures.is_empty(),
		"map_id": map_id,
		"archetype_id": archetype_id,
		"layer_id": layer_id,
		"art_key": str(surface_map.get("art_key", "")),
		"path": path,
		"sha256": FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "",
		"capture_source": "production_root_viewport_texture_plus_capture_only_slot_overlay",
		"post_processed": false,
		"capture_only_overlay_removed": overlay_removed,
		"empty_interactable_count": empty_objects.size(),
		"slot_count": manifest_rows.size(),
		"slot_number_manifest": manifest_rows,
		"player_view_cleanliness_before_overlay": cleanliness,
		"camera": {
			"board_scale": float(marker_view.get("board_scale", 0.0)),
			"camera_zoom": float(marker_view.get("camera_zoom", 1.0)),
			"camera_offset": _rw06_1_vector_snapshot(_vector(marker_view.get("camera_offset", Vector2.ZERO))),
		},
		"errors": failures,
	}


func _rw06_1_empty_room_snapshot(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	# A hidden overflow sentinel makes the composed interaction catalog authoritative
	# while producing no scene object; an empty array would activate legacy fallback
	# reconstruction from game/event/travel fields in PixelSceneCanvas.
	result["interactable_objects"] = [{
		"object_id": "rw06_1::empty_room_sentinel",
		"visible": false,
		"presentation_mode": "overflow",
	}]
	for field_value in ["game_ids", "event_ids", "service_ids", "lender_hooks", "travel_hooks", "next_archetypes", "item_offers", "crew_presence"]:
		result[str(field_value)] = []
	for field_value in ["scenario_presentation", "scenario_render_snapshot", "scenario_sequence_projection", "scenario_layout_authority", "scenario_layout_audit", "pit_boss_watch", "grand_casino_living_floor", "grand_casino_staffing", "linda_cage", "cage_gift_shop_state"]:
		result[str(field_value)] = {}
	result["scenario_layout_authority_digest"] = ""
	result["outcome_object_id"] = ""
	result["outcome_message"] = ""
	result["suspicion_level"] = 0
	result["drunk_level"] = 0
	result["reduce_motion"] = true
	return result


func _rw06_1_restore_marker_canvas(canvas: Variant, snapshot: Dictionary, small_screen: bool, records: Array) -> void:
	canvas.call("render_environment_snapshot", snapshot)
	canvas.call("set_small_screen_mode", small_screen)
	var action_list: Variant = app.get("room_action_list")
	if action_list != null and action_list.has_method("render"):
		action_list.call("render", records)
	canvas.call("queue_redraw")


func _rw06_1_slot_marker_rows(surface_map: Dictionary, canvas: Variant) -> Dictionary:
	var failures: Array = []
	var manifest_rows: Array = []
	var overlay_rows: Array = []
	var seen_slot_ids: Dictionary = {}
	var number := 1
	for field_value in ["base_slots", "stage_slots", "exit_slots"]:
		var field := str(field_value)
		var slots := _array(surface_map.get(field, [])).duplicate(true)
		slots.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
			var left := _dict(left_value)
			var right := _dict(right_value)
			var left_priority := int(left.get("priority", 0))
			var right_priority := int(right.get("priority", 0))
			return str(left.get("id", "")) < str(right.get("id", "")) if left_priority == right_priority else left_priority < right_priority
		)
		for slot_value in slots:
			var slot := _dict(slot_value)
			var slot_id := str(slot.get("id", ""))
			var kind := str(slot.get("kind", field.trim_suffix("_slots")))
			var board_rect := _rect_from_array(slot.get("hit_rect", []))
			var board_position := _vector(slot.get("pos", []), board_rect.get_center())
			if slot_id.is_empty() or seen_slot_ids.has(slot_id):
				failures.append("%s has an empty or duplicate slot id %s." % [str(surface_map.get("id", "")), slot_id])
				continue
			if kind not in RW06_1_SLOT_MARKER_COLORS or not board_rect.has_area():
				failures.append("%s.%s has invalid marker kind/geometry." % [str(surface_map.get("id", "")), slot_id])
				continue
			seen_slot_ids[slot_id] = true
			var viewport_rect := _rw06_1_board_rect_to_viewport(canvas, board_rect)
			var viewport_position := _rw06_1_board_point_to_viewport(canvas, board_position)
			var color: Color = RW06_1_SLOT_MARKER_COLORS.get(kind, Color.WHITE)
			manifest_rows.append({
				"number": number,
				"slot_id": slot_id,
				"kind": kind,
				"footprint_class": str(slot.get("footprint_class", "")),
				"support_id": str(slot.get("support_id", "")),
				"zone_id": str(slot.get("zone_id", "")),
				"board_position": {"x": board_position.x, "y": board_position.y},
				"board_hit_rect": {"x": board_rect.position.x, "y": board_rect.position.y, "w": board_rect.size.x, "h": board_rect.size.y},
				"viewport_position": {"x": viewport_position.x, "y": viewport_position.y},
				"viewport_rect": {"x": viewport_rect.position.x, "y": viewport_rect.position.y, "w": viewport_rect.size.x, "h": viewport_rect.size.y},
				"color": color.to_html(false),
			})
			overlay_rows.append({
				"number": number,
				"kind": kind,
				"color": color,
				"viewport_position": viewport_position,
				"viewport_rect": viewport_rect,
			})
			number += 1
	if manifest_rows.is_empty():
		failures.append("%s has no base/stage/exit slots to mark." % str(surface_map.get("id", "")))
	return {"ok": failures.is_empty(), "manifest": manifest_rows, "overlay": overlay_rows, "errors": failures}


func _rw06_1_board_point_to_viewport(canvas: Variant, board_position: Vector2) -> Vector2:
	var local_position: Vector2 = canvas.call("_board_to_local_position", board_position)
	var transform: Transform2D = canvas.get_global_transform_with_canvas()
	return transform * local_position


func _rw06_1_board_rect_to_viewport(canvas: Variant, board_rect: Rect2) -> Rect2:
	var top_left := _rw06_1_board_point_to_viewport(canvas, board_rect.position)
	var bottom_right := _rw06_1_board_point_to_viewport(canvas, board_rect.end)
	return Rect2(top_left, bottom_right - top_left).abs()


func _rw06_1_vector_snapshot(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _rw06_1_slot_marker_file_id(map_id: String) -> String:
	return map_id.replace(":", "__").validate_filename()


func _rw06_1_remove_slot_marker_artifacts(surface_maps: Array) -> void:
	_rw06_1_remove_slot_marker_source_images(surface_maps)
	_rw06_1_remove_file("%s/slot_markers/slot_marker_manifest.json" % out_dir)


func _rw06_1_remove_slot_marker_source_images(surface_maps: Array) -> void:
	for map_value in surface_maps:
		var map_id := str(_dict(map_value).get("id", ""))
		if not map_id.is_empty():
			_rw06_1_remove_file("%s/slot_markers/%s.png" % [out_dir, _rw06_1_slot_marker_file_id(map_id)])


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
	var reachable := _rw06_1_reachable_phase_states(initial_state, definition, target_phase)
	var phase_states := _array(reachable.get("states", []))
	var resolution_errors: Array = []
	var best: Dictionary = {}
	var peak_metric := str(selection.get("_capture_peak_metric", "scenario_binding_count"))
	if peak_metric not in ["scenario_binding_count", "scenario_room_physical_count"]:
		return {"ok": false, "errors": ["Unsupported rw06_1 capture peak metric %s." % peak_metric]}
	for state_value in phase_states:
		var resolved := _rw06_1_resolve_capture_state(run_state.current_environment, _dict(state_value), definition)
		if not bool(resolved.get("ok", false)):
			for error_value in _array(resolved.get("errors", ["Peak layout resolution failed without an error."])):
				_rw06_1_append_unique_error(resolution_errors, "%s peak %s layout: %s" % [scenario_id, target_phase, str(error_value)])
			continue
		if best.is_empty() or int(resolved.get(peak_metric, -1)) > int(best.get(peak_metric, -1)):
			best = resolved
	if best.is_empty():
		var peak_errors: Array = ["%s has no resolvable reachable state at peak phase %s (target states=%d, explored states=%d, traversal truncated=%s)." % [scenario_id, target_phase, phase_states.size(), int(reachable.get("explored_state_count", 0)), str(bool(reachable.get("truncated", false)))]]
		for error_value in _array(reachable.get("errors", [])):
			_rw06_1_append_unique_error(peak_errors, str(error_value))
		for error_value in resolution_errors:
			_rw06_1_append_unique_error(peak_errors, str(error_value))
		return {"ok": false, "errors": peak_errors}
	var expected_count := int(selection.get("_expected_peak_count", selection.get("binding_count", 0)))
	if int(best.get(peak_metric, -1)) != expected_count:
		return {"ok": false, "errors": ["%s peak %s rendered %d for %s; static manifest requires %d." % [scenario_id, target_phase, int(best.get(peak_metric, -1)), peak_metric, expected_count]]}
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
	return {
		"ok": true,
		"scenario_binding_count": int(best.get("scenario_binding_count", -1)),
		"scenario_room_physical_count": int(best.get("scenario_room_physical_count", -1)),
		"errors": [],
	}


func _rw06_1_resolve_capture_state(environment: Dictionary, state: Dictionary, definition: Dictionary) -> Dictionary:
	var candidate := environment.duplicate(true)
	candidate["scenario_sequence_state"] = state.duplicate(true)
	candidate[ScenarioEngineScript.TRUSTED_STATE_REFERENCE_KEY] = ScenarioSequenceRuntimeScript.content_fingerprint(state)
	# The trace only admits states returned by successful Runtime transactions (or
	# the already trusted initial RunState state). Mirror ScenarioEngine's commit
	# seam: those states are prevalidated, while re-entering sequence_projection()
	# would compare them against the arrival phase's still-materialized layout.
	var projection := ScenarioSequenceRuntimeScript.public_projection(state, definition, true)
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
	var room_physical_count := 0
	for identity_value in _dict(candidate.get("scenario_layout_authority", {})).keys():
		if str(identity_value).begins_with("scenario::"):
			binding_count += 1
			var authority := _dict(_dict(candidate.get("scenario_layout_authority", {})).get(identity_value, {}))
			if str(authority.get("presentation_mode", "room")) == "room":
				room_physical_count += 1
	return {
		"ok": true,
		"environment": candidate,
		"scenario_binding_count": binding_count,
		"scenario_room_physical_count": room_physical_count,
		"errors": [],
	}


func _rw06_1_reachable_phase_states(initial_state: Dictionary, definition: Dictionary, target_phase: String) -> Dictionary:
	var result: Array = []
	var errors: Array = []
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
			var condition_type := str(condition.get("type", ""))
			var applied: Dictionary = {}
			if condition_type == "command":
				applied = _rw06_1_apply_trace_command(state, definition, str(condition.get("command_id", "")), serial, branch_index)
			elif condition_type == "fact":
				applied = _rw06_1_apply_trace_fact(state, definition, condition, serial, branch_index)
			elif condition_type == "always" and str(state.get("status", "")) != ScenarioSequenceRuntimeScript.STATUS_ACTIVE:
				# Terminal outcome phases may retain their authored automatic branch;
				# the successful transaction already evaluated it before returning.
				branch_index += 1
				continue
			else:
				applied = {"ok": false, "errors": ["Unsupported trace condition type %s." % condition_type]}
			if bool(applied.get("ok", false)):
				pending.append(_dict(applied.get("state", {})))
			else:
				var trigger_id := str(condition.get("command_id", condition.get("fact_type", "<unsupported>")))
				var branch_errors := _array(applied.get("errors", ["trace branch returned no diagnostic"]))
				for error_value in branch_errors:
					_rw06_1_append_unique_error(errors, "%s phase %s branch %s: %s" % [str(definition.get("id", "<scenario>")), str(state.get("phase_id", "<phase>")), trigger_id, str(error_value)])
			branch_index += 1
		serial += 1
	return {
		"states": result,
		"errors": errors,
		"explored_state_count": visited.size(),
		"truncated": not pending.is_empty(),
	}


func _rw06_1_apply_trace_command(state: Dictionary, definition: Dictionary, command_id: String, serial: int, branch_index: int) -> Dictionary:
	var origin := _rw06_1_find_action_origin(state, definition, command_id)
	if origin.is_empty():
		return {"ok": false, "errors": ["No publicly available action origin for %s." % command_id]}
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


func _rw06_1_find_action_origin(state: Dictionary, definition: Dictionary, command_id: String) -> Dictionary:
	# Traverse the same closed, resolved action inventory presented to the player.
	# Raw semantic_state.interactions omits base interactions and can retain an
	# authored action whose public preconditions are not currently satisfied.
	var projection := ScenarioSequenceRuntimeScript.public_projection(state, definition)
	for interaction_value in _dict(_dict(projection.get("semantic_state", {})).get("interactions", {})).values():
		var interaction := _dict(interaction_value)
		if not bool(interaction.get("enabled", false)):
			continue
		for action_value in _array(interaction.get("available_actions", [])):
			if str(_dict(action_value).get("id", "")) == command_id:
				return {"owner_namespace": str(interaction.get("owner_namespace", "")), "stable_object_id": str(interaction.get("stable_object_id", ""))}
	return {}


func _rw06_1_append_unique_error(errors: Array, message: String) -> void:
	if not message.is_empty() and not errors.has(message):
		errors.append(message)


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
		return {
			"ok": false,
			"player_view_clean": false,
			"errors": ["%s has no production environment canvas." % archetype_id],
		}
	var layouts: Dictionary = {}
	for mode in ["normal", "expanded"]:
		_rw06_1_clear_player_view_artifacts(canvas)
		canvas.call("set_small_screen_mode", mode == "expanded")
		canvas.call("queue_redraw")
		await _settle(3)
		# Layout changes can re-evaluate tutorial focus. Clear once more, then let
		# the exact production viewport draw the state that will be persisted.
		_rw06_1_clear_player_view_artifacts(canvas)
		canvas.call("queue_redraw")
		await _settle(1)
		await RenderingServer.frame_post_draw
		var path := "%s/%s/%s.png" % [out_dir, mode, archetype_id]
		var cleanliness := _rw06_1_player_view_cleanliness(canvas, archetype_id, mode)
		layouts[mode] = {
			"path": path,
			"capture_source": "production_root_viewport_texture",
			"post_processed": false,
			"player_view_cleanliness": cleanliness,
		}
		if not bool(cleanliness.get("ok", false)):
			failures.append_array(_array(cleanliness.get("errors", ["%s %s player view is not clean." % [archetype_id, mode]])))
			continue
		var image := root.get_viewport().get_texture().get_image()
		var save_error := image.save_png(path)
		if save_error != OK:
			failures.append("%s %s capture could not be written (%s)." % [archetype_id, mode, error_string(save_error)])
		var object_layout := _canvas_object_layout()
		layouts[mode]["sha256"] = FileAccess.get_sha256(path) if save_error == OK else ""
		layouts[mode]["object_layout"] = object_layout
		layouts[mode]["direct_interaction_overlaps"] = _direct_interaction_overlaps(object_layout)
	canvas.call("set_small_screen_mode", false)
	var player_view_clean := true
	for mode in ["normal", "expanded"]:
		player_view_clean = player_view_clean and bool(_dict(_dict(layouts.get(mode, {})).get("player_view_cleanliness", {})).get("ok", false))
	if not player_view_clean:
		for mode in ["normal", "expanded"]:
			_rw06_1_remove_file("%s/%s/%s.png" % [out_dir, mode, archetype_id])
	return {
		"ok": failures.is_empty() and player_view_clean,
		"player_view_clean": player_view_clean,
		"selection": selection.duplicate(true),
		"normal": _dict(layouts.get("normal", {})),
		"expanded": _dict(layouts.get("expanded", {})),
		"errors": failures,
	}


func _rw06_1_clear_player_view_artifacts(canvas: Variant) -> void:
	canvas.call("set_developer_placement_mode", false)
	canvas.call("clear_developer_placement_preview")
	canvas.call("set_selected_object", "")
	canvas.call("_set_hovered_object", "")
	canvas.set("selected_info_badge_hit_entries", [])
	canvas.set("selected_info_badge_hover_text", "")
	var coach: Variant = app.get("coach_overlay")
	if coach != null:
		coach.call("suspend")
	app.call("_clear_selected_game_action")


func _rw06_1_player_view_cleanliness(canvas: Variant, archetype_id: String, mode: String) -> Dictionary:
	var failures: Array = []
	var placement := _dict(canvas.call("developer_placement_snapshot"))
	var view := _dict(canvas.call("current_view_snapshot"))
	var placement_panel := canvas.get("developer_placement_panel") as Control
	var badge_hits := _array(canvas.get("selected_info_badge_hit_entries"))
	var badge_hover_text := str(canvas.get("selected_info_badge_hover_text")).strip_edges()
	var telemetry: Variant = app.get("perf_telemetry_overlay")
	var coach: Variant = app.get("coach_overlay")
	var coach_control := coach as Control
	var coach_panel: Control = null
	var coach_focus_layer: Control = null
	var coach_snapshot: Dictionary = {}
	if coach != null:
		coach_panel = coach.get("panel") as Control
		coach_focus_layer = coach.get("focus_layer") as Control
		coach_snapshot = _dict(coach.call("current_snapshot"))
	var selected_info := _dict(view.get("selected_info", {}))
	var canvas_script: Variant = canvas.get_script()
	var assertions := {
		"production_environment_canvas": canvas_script != null and str(canvas_script.resource_path) == "res://scripts/ui/pixel_scene_canvas.gd",
		"direct_root_viewport": canvas.get_viewport() == root.get_viewport(),
		"developer_placement_mode_disabled": not bool(placement.get("enabled", true)),
		"developer_placement_panel_hidden": placement_panel == null or not placement_panel.is_visible_in_tree(),
		"developer_hit_preview_absent": not bool(placement.get("dragging", true))
			and not bool(placement.get("pending", true))
			and _array(placement.get("overlap_ids", [])).is_empty(),
		"telemetry_absent": telemetry == null,
		"coach_root_hidden": coach_control == null or not coach_control.is_visible_in_tree(),
		"coach_panel_hidden": coach_panel == null or not coach_panel.is_visible_in_tree(),
		"coach_focus_layer_hidden": coach_focus_layer == null or not coach_focus_layer.is_visible_in_tree(),
		"coach_snapshot_hidden": not bool(coach_snapshot.get("visible", true))
			and int(coach_snapshot.get("queued_count", 1)) == 0,
		"selection_absent": str(view.get("selected_object_id", "")).is_empty()
			and str(placement.get("selected_object_id", "")).is_empty()
			and not bool(selected_info.get("visible", true))
			and str(selected_info.get("object_id", "")).is_empty(),
		"hover_absent": str(view.get("hovered_object_id", "")).is_empty(),
		"hit_annotations_absent": badge_hits.is_empty() and badge_hover_text.is_empty(),
		"camera_debug_focus_absent": not bool(view.get("camera_focus_active", true)),
	}
	for assertion_value in assertions.keys():
		var assertion_name := str(assertion_value)
		if not bool(assertions.get(assertion_name, false)):
			failures.append("%s %s source capture failed player-view assertion: %s." % [archetype_id, mode, assertion_name])
	return {
		"ok": failures.is_empty(),
		"archetype_id": archetype_id,
		"mode": mode,
		"capture_source": "production_root_viewport_texture",
		"post_processed": false,
		"assertions": assertions,
		"developer_placement": placement,
		"coach": {
			"snapshot": coach_snapshot,
			"root_visible_in_tree": coach_control != null and coach_control.is_visible_in_tree(),
			"panel_visible_in_tree": coach_panel != null and coach_panel.is_visible_in_tree(),
			"focus_layer_visible_in_tree": coach_focus_layer != null and coach_focus_layer.is_visible_in_tree(),
		},
		"view_artifacts": {
			"selected_object_id": str(view.get("selected_object_id", "")),
			"hovered_object_id": str(view.get("hovered_object_id", "")),
			"camera_focus_active": bool(view.get("camera_focus_active", true)),
			"selected_info": selected_info,
			"badge_hit_count": badge_hits.size(),
			"badge_hover_text": badge_hover_text,
		},
		"telemetry_present": telemetry != null,
		"errors": failures,
	}


func _rw06_1_remove_stale_contact_artifacts(selections: Array) -> void:
	_rw06_1_remove_contact_source_images(selections)
	_rw06_1_remove_file("%s/all_rooms_contact_sheet.png" % out_dir)
	_rw06_1_remove_file("%s/day2_contact_sheet.png" % out_dir)
	_rw06_1_remove_file("%s/contact_sheet_report.json" % out_dir)


func _rw06_1_remove_contact_source_images(selections: Array) -> void:
	for selection_value in selections:
		var archetype_id := str(_dict(selection_value).get("archetype_id", ""))
		for mode in ["normal", "expanded"]:
			_rw06_1_remove_file("%s/%s/%s.png" % [out_dir, mode, archetype_id])


func _rw06_1_remove_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var absolute_path := path if path.is_absolute_path() else ProjectSettings.globalize_path(path)
	DirAccess.remove_absolute(absolute_path)


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
