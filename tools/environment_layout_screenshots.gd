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
const RW06_1_ROOM_REVIEW_SELECTIONS := [
	{
		"archetype_id": "bar",
		"scenario_id": "bar_fight_night",
		"phase_id": "work_3",
		"command_path": ["brace_exit", "warn_brawlers", "separate_sides"],
	},
	{
		"archetype_id": "corner_store",
		"scenario_id": "corner_store_delivery_day",
		"phase_id": "verification",
		"command_path": ["inspect_manifest", "shift_cartons"],
	},
	{
		"archetype_id": "grand_casino",
		"scenario_id": "grand_casino_gala_night",
		"phase_id": "work_2",
		"command_path": ["claim_coat_token", "verify_charity_badge"],
	},
]
const RW06_1_ALL_ROOM_REVIEW_SELECTIONS := [
	{"map_id": "back_alley", "archetype_id": "back_alley", "scenario_id": "back_alley_cruiser_parked", "phase_id": "work", "command_path": ["map_sightline"]},
	{"map_id": "bar", "archetype_id": "bar", "scenario_id": "bar_fight_night", "phase_id": "work_3", "command_path": ["brace_exit", "warn_brawlers", "separate_sides"]},
	{"map_id": "beach", "archetype_id": "beach", "scenario_id": "beach_festival_weekend", "phase_id": "safe_exit", "command_path": ["beach_festival_weekend_leave_safe"]},
	{"map_id": "corner_store", "archetype_id": "corner_store", "scenario_id": "corner_store_delivery_day", "phase_id": "verification", "command_path": ["inspect_manifest", "shift_cartons"]},
	{"map_id": "delta_queen", "archetype_id": "delta_queen", "scenario_id": "delta_queen_fog_delay", "phase_id": "work_1", "command_path": ["read_fog_signal"]},
	{"map_id": "gas_station_casino", "archetype_id": "gas_station_casino", "scenario_id": "gas_station_tour_bus_stop", "phase_id": "safe_exit", "command_path": ["gas_station_tour_bus_stop_leave_safe"]},
	{"map_id": "grand_casino", "archetype_id": "grand_casino", "scenario_id": "grand_casino_gala_night", "phase_id": "work_2", "command_path": ["claim_coat_token", "verify_charity_badge"]},
	{"map_id": "jazz_club", "archetype_id": "jazz_club", "scenario_id": "jazz_club_guest_legend", "phase_id": "work_3", "command_path": ["find_instrument_case", "open_backstage_lane", "inspect_missing_piece"]},
	{"map_id": "kitty_cat_lounge", "archetype_id": "kitty_cat_lounge", "scenario_id": "kitty_cat_lounge_amateur_night", "phase_id": "work_3", "command_path": ["register_amateur_act", "carry_costume_to_dressing", "set_stage_mark"]},
	{"map_id": "motel", "archetype_id": "motel", "scenario_id": "motel_stakeout", "phase_id": "safe_exit", "command_path": ["motel_stakeout_leave_safe"]},
	{"map_id": "pawn_shop", "archetype_id": "pawn_shop", "scenario_id": "pawn_shop_estate_lot_day", "phase_id": "work", "command_path": ["stage_lot"]},
	{"map_id": "small_underground_casino:casino", "archetype_id": "small_underground_casino", "scenario_id": "punchline_high_stakes_night", "phase_id": "work_3", "command_path": ["clear_ordinary_chairs", "mark_guard_sightline", "open_observer_rail"]},
	{"map_id": "small_underground_casino:club", "archetype_id": "small_underground_casino", "scenario_id": "punchline_bringer_show", "phase_id": "work_3", "command_path": ["open_first_crowd_rope", "usher_supporters_to_block", "count_minimum_seats"]},
]
const RW06_1_DAY2_ARCHETYPE_IDS := ["bar", "corner_store", "grand_casino"]
const RW06_1_PHYSICAL_COUNT_KEYS := ["physical_room_count", "room_physical_count"]
const RW06_1_CONTACT_ROOM_COUNT := 18
const RW06_1_SOURCE_CAPTURE_SIZE := Vector2i(1280, 720)
const RW06_1_Q008_SHEET_SIZE := Vector2i(960, 360)
const RW06_1_CAPTURE_BASE_PATH := "res://.tmp/rw06_1/visual_evidence"
const RW06_1_CAPTURE_OWNER_FILE := ".rw06_1_capture_owner"
const RW06_1_MIN_OPAQUE_SAMPLE_RATIO := 0.08
const RW06_1_MIN_OCCUPIED_GRID_CELLS := 8
const RW06_1_MIN_VARIANT_GRID_CELLS := 8
const RW06_1_MIN_COLOR_BUCKETS := 12
const RW06_1_MIN_LUMA_SPAN := 32
const RW06_1_OPAQUE_ALPHA_MIN := 192
const RW06_1_IMAGE_SAMPLE_STRIDE := 4
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
var rw06_1_slot_marker_maps := ""
var rw06_1_q008 := false
var rw06_1_room_review := false
var rw06_1_all_room_review := false
var rw06_1_capture_root_absolute := ""
var rw06_1_capture_owner_token := ""
var rw06_1_capture_owner_path := ""
var rw06_1_manifest_files: Dictionary = {}
var rw06_1_cleanup_failures: Array = []


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
		elif argument.begins_with("--rw06-1-slot-marker-maps="):
			rw06_1_slot_marker_maps = argument.trim_prefix("--rw06-1-slot-marker-maps=")
		elif argument == "--rw06-1-q008":
			rw06_1_q008 = true
		elif argument == "--rw06-1-room-review":
			rw06_1_room_review = true
		elif argument == "--rw06-1-all-room-review":
			rw06_1_all_room_review = true
	call_deferred("_run")


func _run() -> void:
	if rw06_1_contact_sheet or rw06_1_q008:
		var claim := _rw06_1_claim_capture_root()
		if not bool(claim.get("ok", false)):
			for error_value in _array(claim.get("errors", [])):
				push_error(str(error_value))
			quit(1)
			return
	else:
		var directory_error := DirAccess.make_dir_recursive_absolute(out_dir)
		if directory_error != OK and not DirAccess.dir_exists_absolute(out_dir):
			push_error("Layout survey could not create output directory %s (%s)." % [out_dir, error_string(directory_error)])
			quit(1)
			return
	app = MainScene.instantiate()
	if rw06_1_room_review or rw06_1_all_room_review:
		# This one-shot authoring capture loads its required game scripts on the
		# main thread. Do not let the start-menu prewarm worker race those same
		# ResourceLoader requests while the first base room is being composed.
		app.set("script_prewarm_stopping", true)
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
		if rw06_1_contact_sheet or rw06_1_q008:
			var owner_release := _rw06_1_release_capture_owner()
			for error_value in _array(owner_release.get("errors", [])):
				push_error(str(error_value))
		quit(1)
		return
	if fix06_31_audit:
		await _run_fix06_31_audit(library)
		return
	if rw06_1_slot_markers:
		await _run_rw06_1_slot_markers(library)
		return
	if rw06_1_room_review:
		await _run_rw06_1_room_review(library)
		return
	if rw06_1_all_room_review:
		await _run_rw06_1_all_room_review(library)
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


func _rw06_1_normalize_absolute_path(path: String) -> String:
	var absolute_path := path if path.is_absolute_path() else ProjectSettings.globalize_path(path)
	return absolute_path.replace("\\", "/").simplify_path().trim_suffix("/")


func _rw06_1_path_is_inside(path: String, parent: String, allow_equal: bool = false) -> bool:
	var normalized_path := _rw06_1_normalize_absolute_path(path).to_lower()
	var normalized_parent := _rw06_1_normalize_absolute_path(parent).to_lower()
	if normalized_path == normalized_parent:
		return allow_equal
	return normalized_path.begins_with("%s/" % normalized_parent)


func _rw06_1_path_has_link_boundary(path: String) -> bool:
	var normalized := _rw06_1_normalize_absolute_path(path)
	var current := ""
	var remainder := ""
	if normalized.length() >= 3 and normalized.substr(1, 2) == ":/":
		current = normalized.left(3)
		remainder = normalized.substr(3)
	elif normalized.begins_with("/"):
		current = "/"
		remainder = normalized.trim_prefix("/")
	else:
		return true
	for component_value in remainder.split("/", false):
		var component := str(component_value)
		var parent_directory := DirAccess.open(current)
		if parent_directory == null:
			return true
		if parent_directory.is_link(component):
			return true
		current = current.path_join(component)
	return false


func _rw06_1_claim_capture_root() -> Dictionary:
	var failures: Array = []
	var candidate := _rw06_1_normalize_absolute_path(out_dir)
	var allowed_base := _rw06_1_normalize_absolute_path(RW06_1_CAPTURE_BASE_PATH)
	if not _rw06_1_path_is_inside(candidate, allowed_base):
		failures.append("rw06_1 capture root must be a fresh descendant of %s; found %s." % [allowed_base, candidate])
	if not DirAccess.dir_exists_absolute(candidate):
		failures.append("rw06_1 capture root must already exist as a launcher-owned fresh directory: %s." % candidate)
	if failures.is_empty() and _rw06_1_path_has_link_boundary(candidate):
		failures.append("rw06_1 capture root crosses a symbolic-link, junction, or reparse boundary: %s." % candidate)
	if failures.is_empty():
		var directory := DirAccess.open(candidate)
		if directory == null:
			failures.append("rw06_1 capture root cannot be opened: %s." % candidate)
		else:
			var list_error := directory.list_dir_begin()
			if list_error != OK:
				failures.append("rw06_1 capture root cannot be enumerated (%s): %s." % [error_string(list_error), candidate])
			else:
				var first_entry := directory.get_next()
				directory.list_dir_end()
				if not first_entry.is_empty():
					failures.append("rw06_1 capture root is not fresh and empty: %s." % candidate)
	if not failures.is_empty():
		return {"ok": false, "errors": failures}
	rw06_1_capture_root_absolute = candidate
	rw06_1_capture_owner_token = "%s|%s|%s" % [str(OS.get_process_id()), str(Time.get_ticks_usec()), candidate]
	rw06_1_capture_owner_path = candidate.path_join(RW06_1_CAPTURE_OWNER_FILE)
	rw06_1_manifest_files = {rw06_1_capture_owner_path.to_lower(): rw06_1_capture_owner_path}
	rw06_1_cleanup_failures.clear()
	var owner_file := FileAccess.open(rw06_1_capture_owner_path, FileAccess.WRITE)
	if owner_file == null:
		return {"ok": false, "errors": ["rw06_1 could not create its capture ownership marker (%s)." % error_string(FileAccess.get_open_error())]}
	owner_file.store_string(rw06_1_capture_owner_token)
	owner_file.flush()
	var owner_write_error := owner_file.get_error()
	owner_file.close()
	var owner_text := ""
	if FileAccess.file_exists(rw06_1_capture_owner_path):
		var owner_reader := FileAccess.open(rw06_1_capture_owner_path, FileAccess.READ)
		if owner_reader != null:
			owner_text = owner_reader.get_as_text()
			owner_reader.close()
	if owner_write_error != OK or owner_text != rw06_1_capture_owner_token:
		failures.append("rw06_1 capture ownership marker could not be verified after write.")
		if FileAccess.file_exists(rw06_1_capture_owner_path):
			var marker_remove_error := DirAccess.remove_absolute(rw06_1_capture_owner_path)
			if marker_remove_error != OK:
				failures.append("rw06_1 could not remove its invalid owner marker (%s)." % error_string(marker_remove_error))
		if FileAccess.file_exists(rw06_1_capture_owner_path) or DirAccess.dir_exists_absolute(rw06_1_capture_owner_path):
			failures.append("rw06_1 invalid owner marker remains after cleanup.")
		return {"ok": false, "errors": failures}
	return {"ok": true, "root": candidate, "owner_path": rw06_1_capture_owner_path, "errors": []}


func _rw06_1_capture_ownership_is_valid() -> bool:
	if rw06_1_capture_root_absolute.is_empty() or rw06_1_capture_owner_path.is_empty() \
			or rw06_1_capture_owner_token.is_empty():
		return false
	if not _rw06_1_path_is_inside(rw06_1_capture_owner_path, rw06_1_capture_root_absolute):
		return false
	if _rw06_1_path_has_link_boundary(rw06_1_capture_owner_path):
		return false
	var owner_reader := FileAccess.open(rw06_1_capture_owner_path, FileAccess.READ)
	if owner_reader == null:
		return false
	var owner_text := owner_reader.get_as_text()
	owner_reader.close()
	return owner_text == rw06_1_capture_owner_token


func _rw06_1_ensure_owned_directory(relative_name: String) -> Dictionary:
	var failures: Array = []
	var path := rw06_1_capture_root_absolute.path_join(relative_name)
	if not _rw06_1_capture_ownership_is_valid() or not _rw06_1_path_is_inside(path, rw06_1_capture_root_absolute):
		failures.append("rw06_1 refused to create an unowned output directory: %s." % path)
	else:
		var create_error := DirAccess.make_dir_recursive_absolute(path)
		if create_error != OK and not DirAccess.dir_exists_absolute(path):
			failures.append("rw06_1 could not create output directory %s (%s)." % [path, error_string(create_error)])
		elif _rw06_1_path_has_link_boundary(path):
			failures.append("rw06_1 output directory crosses a link/reparse boundary: %s." % path)
	return {"ok": failures.is_empty(), "path": path, "errors": failures}


func _rw06_1_register_manifest_paths(paths: Array) -> Dictionary:
	var failures: Array = []
	for path_value in paths:
		var absolute_path := _rw06_1_normalize_absolute_path(str(path_value))
		if not _rw06_1_path_is_inside(absolute_path, rw06_1_capture_root_absolute):
			failures.append("rw06_1 manifest path escapes the owned capture root: %s." % absolute_path)
			continue
		if _rw06_1_path_has_link_boundary(absolute_path):
			failures.append("rw06_1 manifest path crosses a link/reparse boundary: %s." % absolute_path)
			continue
		rw06_1_manifest_files[absolute_path.to_lower()] = absolute_path
	return {"ok": failures.is_empty(), "errors": failures}


func _rw06_1_assert_paths_absent(paths: Array) -> Dictionary:
	var failures: Array = []
	for path_value in paths:
		var absolute_path := _rw06_1_normalize_absolute_path(str(path_value))
		if not rw06_1_manifest_files.has(absolute_path.to_lower()):
			failures.append("rw06_1 freshness check rejected a path outside its manifest: %s." % absolute_path)
		elif FileAccess.file_exists(absolute_path) or DirAccess.dir_exists_absolute(absolute_path):
			failures.append("rw06_1 fresh capture path already exists: %s." % absolute_path)
	return {"ok": failures.is_empty(), "errors": failures}


func _rw06_1_release_capture_owner() -> Dictionary:
	if rw06_1_capture_owner_path.is_empty():
		return {"ok": true, "absent": true, "errors": []}
	return _rw06_1_remove_file(rw06_1_capture_owner_path, true)


func _rw06_1_json_integer(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) \
		and is_finite(float(value)) and float(value) == floor(float(value))


func _rw06_1_read_json_evidence(path: String) -> Dictionary:
	var failures: Array = []
	var payload: Dictionary = {}
	if not FileAccess.file_exists(path):
		failures.append("Static evidence JSON is missing: %s." % path)
	else:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			failures.append("Static evidence JSON cannot be opened (%s): %s." % [error_string(FileAccess.get_open_error()), path])
		else:
			var text := file.get_as_text()
			var read_error := file.get_error()
			file.close()
			var parser := JSON.new()
			var parse_error := parser.parse(text)
			if read_error != OK:
				failures.append("Static evidence JSON read failed (%s): %s." % [error_string(read_error), path])
			elif parse_error != OK:
				failures.append("Static evidence JSON parse failed at line %d: %s." % [parser.get_error_line(), parser.get_error_message()])
			elif typeof(parser.data) != TYPE_DICTIONARY:
				failures.append("Static evidence JSON root must be an object.")
			else:
				payload = parser.data
	var sha256 := FileAccess.get_sha256(path) if failures.is_empty() else ""
	if failures.is_empty() and sha256.is_empty():
		failures.append("Static evidence JSON has no verifiable SHA-256: %s." % path)
	return {"ok": failures.is_empty(), "payload": payload, "sha256": sha256, "errors": failures}


func _rw06_1_validate_static_report(report: Dictionary) -> Dictionary:
	var failures: Array = []
	if typeof(report.get("tool", null)) != TYPE_STRING or str(report.get("tool", "")) != "environment_fixed_slot_static_check":
		failures.append("Static report tool identity is missing, mistyped, or unexpected.")
	if typeof(report.get("passed", null)) != TYPE_BOOL or not report.get("passed", false):
		failures.append("Static report passed must be native boolean true.")
	if not _rw06_1_json_integer(report.get("error_count", null)) or int(report.get("error_count", -1)) != 0:
		failures.append("Static report error_count must be native numeric integer zero.")
	if typeof(report.get("errors", null)) != TYPE_ARRAY or not _array(report.get("errors", [])).is_empty():
		failures.append("Static report errors must be a native empty array.")
	if typeof(report.get("contact_sheet", null)) != TYPE_ARRAY or _array(report.get("contact_sheet", [])).is_empty():
		failures.append("Static report contact_sheet must be a nonempty native array.")
	if typeof(report.get("active_scenarios", null)) != TYPE_ARRAY or _array(report.get("active_scenarios", [])).is_empty():
		failures.append("Static report active_scenarios must be a nonempty native array.")
	var counts_value: Variant = report.get("counts", null)
	if typeof(counts_value) != TYPE_DICTIONARY:
		failures.append("Static report counts must be a native object.")
	else:
		var counts: Dictionary = counts_value
		var exact_counts := {
			"archetypes": RW06_1_CONTACT_ROOM_COUNT,
			"scenarios": 55,
			"legal_hosts": 55,
			"historical_exact_seeds": 22,
			"base_scenario_conflicts": 0,
			"base_base_conflicts": 0,
		}
		for key_value in exact_counts.keys():
			var key := str(key_value)
			if not _rw06_1_json_integer(counts.get(key, null)) or int(counts.get(key, -1)) != int(exact_counts.get(key, -2)):
				failures.append("Static report count %s must be native integer %d." % [key, int(exact_counts.get(key, -2))])
		for key_value in ["maps", "active_snapshots", "active_bindings", "complete_snapshots"]:
			var key := str(key_value)
			if not _rw06_1_json_integer(counts.get(key, null)):
				failures.append("Static report count %s must be a native integer." % key)
		if _rw06_1_json_integer(counts.get("maps", null)) and int(counts.get("maps", 0)) < RW06_1_CONTACT_ROOM_COUNT:
			failures.append("Static report map coverage is below %d." % RW06_1_CONTACT_ROOM_COUNT)
		if _rw06_1_json_integer(counts.get("active_snapshots", null)) and int(counts.get("active_snapshots", 0)) <= 0:
			failures.append("Static report has no active snapshot coverage.")
		if _rw06_1_json_integer(counts.get("active_bindings", null)) and int(counts.get("active_bindings", 0)) <= 0:
			failures.append("Static report has no active binding coverage.")
		if _rw06_1_json_integer(counts.get("complete_snapshots", null)) \
				and _rw06_1_json_integer(counts.get("active_snapshots", null)) \
				and int(counts.get("complete_snapshots", 0)) < int(counts.get("active_snapshots", 0)):
			failures.append("Static report complete snapshot coverage is below active coverage.")
	return {"ok": failures.is_empty(), "errors": failures}


func _run_rw06_1_contact_sheet(library: Variant) -> void:
	var failures: Array = []
	var static_evidence := _rw06_1_read_json_evidence(rw06_1_static_report)
	failures.append_array(_array(static_evidence.get("errors", [])))
	var static_report := _dict(static_evidence.get("payload", {}))
	var static_report_sha256 := str(static_evidence.get("sha256", ""))
	if bool(static_evidence.get("ok", false)):
		var static_schema := _rw06_1_validate_static_report(static_report)
		failures.append_array(_array(static_schema.get("errors", [])))
	var definitions: Dictionary = {}
	for definition_value in _fix06_31_scenario_definitions(library):
		var definition := _dict(definition_value)
		definitions[str(definition.get("id", ""))] = definition
	var archetypes: Dictionary = {}
	for archetype_value in library.environment_archetypes:
		var archetype := _dict(archetype_value)
		archetypes[str(archetype.get("id", ""))] = archetype
	var contact_paths: Array = [
		"%s/all_rooms_contact_sheet.png" % out_dir,
		"%s/day2_contact_sheet.png" % out_dir,
		"%s/contact_sheet_report.json" % out_dir,
	]
	for archetype_value in archetypes.keys():
		var production_archetype_id := str(archetype_value)
		for mode in ["normal", "expanded"]:
			contact_paths.append("%s/%s/%s.png" % [out_dir, mode, production_archetype_id])
	for directory_name in ["normal", "expanded"]:
		var directory_result := _rw06_1_ensure_owned_directory(directory_name)
		failures.append_array(_array(directory_result.get("errors", [])))
	var manifest_result := _rw06_1_register_manifest_paths(contact_paths)
	failures.append_array(_array(manifest_result.get("errors", [])))
	var fresh_result := _rw06_1_assert_paths_absent(contact_paths)
	failures.append_array(_array(fresh_result.get("errors", [])))
	var selection_result: Dictionary = {"ok": false, "selections": [], "errors": []}
	if failures.is_empty():
		selection_result = _rw06_1_contact_selections(static_report, archetypes, definitions)
		failures.append_array(_array(selection_result.get("errors", [])))
	var all_selections := _array(selection_result.get("selections", []))
	var selections := all_selections.duplicate(true)
	if rw06_1_day2_only:
		selections = selections.filter(func(selection_value: Variant) -> bool:
			return bool(_dict(selection_value).get("day2_sample", false))
		)
	var expected_room_count := RW06_1_DAY2_ARCHETYPE_IDS.size() if rw06_1_day2_only else RW06_1_CONTACT_ROOM_COUNT
	if selections.size() != expected_room_count:
		failures.append("rw06_1 contact-sheet manifest must contain %d rooms; found %d." % [expected_room_count, selections.size()])
	var capture_rows: Array = []
	var capture_attempts: Array = []
	var player_view_failure := false
	if failures.is_empty():
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
	# Preserve the established player-view fail-closed seam explicitly. The
	# broader final cleanup below also removes every PNG for any other failure.
	if player_view_failure:
		var player_view_cleanup := _rw06_1_remove_contact_source_images(selections)
		if bool(player_view_cleanup.get("ok", false)) and bool(player_view_cleanup.get("all_absent", false)):
			capture_rows.clear()
		else:
			failures.append_array(_array(player_view_cleanup.get("errors", ["Player-view cleanup could not verify source-image absence."])))
	var day2_rows: Array = []
	for row_value in capture_rows:
		var row := _dict(row_value)
		if bool(_dict(row.get("selection", {})).get("day2_sample", false)):
			day2_rows.append(row)
	var generation_identity := _rw06_1_contact_generation_identity(capture_attempts)
	if not bool(generation_identity.get("ok", false)):
		failures.append_array(_array(generation_identity.get("errors", [])))
	var all_rooms_sheet_path := "%s/all_rooms_contact_sheet.png" % out_dir
	var day2_sheet_path := "%s/day2_contact_sheet.png" % out_dir
	var full_sheet: Dictionary = {"ok": false, "path": all_rooms_sheet_path, "errors": ["Contact source set is incomplete; sheet was not created."]}
	var day2_sheet: Dictionary = {"ok": false, "path": day2_sheet_path, "errors": ["Day-2 source set is incomplete; sheet was not created."]}
	var source_set_complete := failures.is_empty() \
		and capture_rows.size() == expected_room_count \
		and day2_rows.size() == RW06_1_DAY2_ARCHETYPE_IDS.size()
	if source_set_complete:
		full_sheet = _rw06_1_build_sheet(capture_rows, all_rooms_sheet_path, 3)
		if not bool(full_sheet.get("ok", false)):
			failures.append_array(_array(full_sheet.get("errors", [])))
		else:
			day2_sheet = _rw06_1_build_sheet(day2_rows, day2_sheet_path, 1)
			if not bool(day2_sheet.get("ok", false)):
				failures.append_array(_array(day2_sheet.get("errors", [])))
	var passed := source_set_complete and failures.is_empty() \
		and bool(full_sheet.get("ok", false)) \
		and bool(day2_sheet.get("ok", false))
	# Any failure invalidates every PNG in the set. Retain only the JSON failure
	# report so a prior complete sheet can never masquerade as current evidence.
	if not passed:
		var failed_png_paths := _rw06_1_manifest_capture_png_paths()
		failed_png_paths.append(all_rooms_sheet_path)
		failed_png_paths.append(day2_sheet_path)
		var failed_set_cleanup := _rw06_1_cleanup_paths(failed_png_paths)
		if bool(failed_set_cleanup.get("ok", false)) and bool(failed_set_cleanup.get("all_absent", false)):
			capture_rows.clear()
			day2_rows.clear()
			full_sheet["ok"] = false
			full_sheet["retained"] = false
			day2_sheet["ok"] = false
			day2_sheet["retained"] = false
		else:
			failures.append_array(_array(failed_set_cleanup.get("errors", ["Failed contact set could not be removed completely."])))
			full_sheet["retained"] = FileAccess.file_exists(all_rooms_sheet_path)
			day2_sheet["retained"] = FileAccess.file_exists(day2_sheet_path)
	var report_payload := {
		"schema": "rw06_1_fixed_slot_contact_sheet/v1",
		"source_static_report": rw06_1_static_report,
		"source_static_report_sha256": static_report_sha256,
		"generation_identity": generation_identity,
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
		"passed": passed,
		"fail_closed_zero_rows": not passed and capture_rows.is_empty(),
		"failures": failures,
		"cleanup_failures": rw06_1_cleanup_failures.duplicate(),
	}
	var report_path := "%s/contact_sheet_report.json" % out_dir
	var report_write := _write_fix06_31_json(report_path, report_payload)
	var final_success := passed and bool(report_write.get("ok", false))
	if not bool(report_write.get("ok", false)):
		failures.append_array(_array(report_write.get("errors", ["Contact report write was not verified."])))
		var write_failure_cleanup := _rw06_1_cleanup_paths(contact_paths)
		if not bool(write_failure_cleanup.get("ok", false)):
			failures.append_array(_array(write_failure_cleanup.get("errors", [])))
	var owner_release := _rw06_1_release_capture_owner()
	if not bool(owner_release.get("ok", false)) or not bool(owner_release.get("absent", false)):
		final_success = false
		failures.append_array(_array(owner_release.get("errors", ["Contact capture owner marker was not released."])))
		if _rw06_1_capture_ownership_is_valid():
			var owner_failure_cleanup := _rw06_1_cleanup_paths(contact_paths)
			failures.append_array(_array(owner_failure_cleanup.get("errors", [])))
			var owner_retry := _rw06_1_release_capture_owner()
			failures.append_array(_array(owner_retry.get("errors", [])))
	print("RW06_1_CONTACT_SHEET rooms=%d day2=%d failures=%d out=%s" % [capture_rows.size(), day2_rows.size(), failures.size(), out_dir])
	app.free()
	app = null
	await _settle(4)
	quit(0 if final_success else 1)


func _rw06_1_contact_selections(static_report: Dictionary, archetypes: Dictionary, definitions: Dictionary) -> Dictionary:
	var failures: Array = []
	var source_rows := _array(static_report.get("contact_sheet", []))
	var expected_archetype_ids: Array = archetypes.keys()
	expected_archetype_ids.sort()
	if expected_archetype_ids.size() != RW06_1_CONTACT_ROOM_COUNT:
		failures.append("Production content exposes %d room archetypes; contact evidence requires exactly %d." % [expected_archetype_ids.size(), RW06_1_CONTACT_ROOM_COUNT])
	if source_rows.size() != RW06_1_CONTACT_ROOM_COUNT:
		failures.append("Static contact manifest must contain exactly %d rows; found %d." % [RW06_1_CONTACT_ROOM_COUNT, source_rows.size()])
	var seen_archetype_ids: Dictionary = {}
	var seen_capture_identities: Dictionary = {}
	var seen_day2_ids: Array = []
	var selections: Array = []
	var active_summaries := _array(static_report.get("active_scenarios", []))
	for row_value in source_rows:
		var row := _dict(row_value).duplicate(true)
		var archetype_id := str(row.get("archetype_id", "")).strip_edges()
		var map_id := str(row.get("map_id", "")).strip_edges()
		var scenario_id := str(row.get("scenario_id", "")).strip_edges()
		var phase_id := str(row.get("phase_id", "")).strip_edges()
		var day2_sample := bool(row.get("day2_sample", false))
		for required_field in ["archetype_id", "map_id", "scenario_id", "phase_id", "day2_sample"]:
			if not row.has(required_field):
				failures.append("Static contact row for %s is missing explicit %s identity." % [archetype_id, required_field])
		if typeof(row.get("day2_sample", null)) != TYPE_BOOL:
			failures.append("Static contact row for %s has a non-boolean day2_sample identity." % archetype_id)
		if archetype_id.is_empty() or seen_archetype_ids.has(archetype_id):
			failures.append("Static contact archetype id is empty or duplicated: %s." % archetype_id)
		else:
			seen_archetype_ids[archetype_id] = true
		var map_parts := map_id.split(":", true, 1)
		var map_archetype_id := str(map_parts[0]) if not map_parts.is_empty() else ""
		var map_layer_id := str(map_parts[1]) if map_parts.size() > 1 else ""
		if map_id.is_empty() or map_archetype_id != archetype_id:
			failures.append("Static contact row %s requests mismatched map %s." % [archetype_id, map_id])
		if str(row.get("layer_id", "")) != map_layer_id:
			failures.append("Static contact row %s layer identity does not match map %s." % [archetype_id, map_id])
		if phase_id.is_empty():
			failures.append("Static contact row %s has no phase identity." % archetype_id)
		if scenario_id.is_empty():
			if phase_id != "base_inventory" or map_id != archetype_id or day2_sample:
				failures.append("Static contact base row %s has invalid map/phase/day2 identity." % archetype_id)
		elif not definitions.has(scenario_id):
			failures.append("Static contact row %s names unknown scenario %s." % [archetype_id, scenario_id])
		else:
			var definition := _dict(definitions.get(scenario_id, {}))
			if str(definition.get("archetype_id", "")) != archetype_id:
				failures.append("Static contact scenario %s is not hosted by %s." % [scenario_id, archetype_id])
			if ScenarioSequenceSchemaScript.phase(definition, phase_id).is_empty():
				failures.append("Static contact scenario %s has no phase %s." % [scenario_id, phase_id])
		var physical_count := _rw06_1_physical_room_count(row)
		if physical_count < 0:
			failures.append("Static contact row %s has no physical_room_count." % archetype_id)
		if not scenario_id.is_empty():
			var peak_candidates: Array = []
			for summary_value in active_summaries:
				var summary := _dict(summary_value)
				if str(summary.get("map_id", "")).split(":", true, 1)[0] != archetype_id:
					continue
				var peak := _dict(summary.get("peak", {}))
				var peak_count := _rw06_1_physical_room_count(peak)
				if peak_count >= 0:
					peak_candidates.append({
						"map_id": str(summary.get("map_id", "")),
						"scenario_id": str(summary.get("scenario_id", "")),
						"phase_id": str(peak.get("phase_id", "")),
						"physical_room_count": peak_count,
					})
			if peak_candidates.is_empty():
				failures.append("Static contact report exposes no physical peak census for %s." % archetype_id)
			else:
				var room_maximum := 0
				var selected_is_peak := false
				for candidate_value in peak_candidates:
					room_maximum = maxi(room_maximum, int(_dict(candidate_value).get("physical_room_count", -1)))
				for candidate_value in peak_candidates:
					var candidate := _dict(candidate_value)
					if str(candidate.get("map_id", "")) == map_id \
							and str(candidate.get("scenario_id", "")) == scenario_id \
							and str(candidate.get("phase_id", "")) == phase_id \
							and int(candidate.get("physical_room_count", -1)) == room_maximum:
						selected_is_peak = true
						break
				if physical_count != room_maximum or not selected_is_peak:
					failures.append("Static contact selection for %s is not its true physical-room peak (%d versus %d)." % [archetype_id, physical_count, room_maximum])
		row["physical_room_count"] = physical_count
		row["_capture_peak_metric"] = "scenario_room_physical_count"
		row["_expected_peak_count"] = physical_count
		var identity := "%s|%s|%s|%s|%s" % [archetype_id, map_id, scenario_id, phase_id, str(day2_sample)]
		if seen_capture_identities.has(identity):
			failures.append("Static contact capture identity is duplicated: %s." % identity)
		seen_capture_identities[identity] = true
		if day2_sample:
			seen_day2_ids.append(archetype_id)
		selections.append(row)
	var actual_archetype_ids: Array = seen_archetype_ids.keys()
	actual_archetype_ids.sort()
	seen_day2_ids.sort()
	if actual_archetype_ids != expected_archetype_ids:
		failures.append("Static contact room identities do not exactly match production archetypes.")
	if seen_day2_ids != RW06_1_DAY2_ARCHETYPE_IDS:
		failures.append("Static contact day-2 identities must be exactly %s; found %s." % [str(RW06_1_DAY2_ARCHETYPE_IDS), str(seen_day2_ids)])
	return {
		"ok": failures.is_empty() and selections.size() == RW06_1_CONTACT_ROOM_COUNT,
		"selections": selections,
		"errors": failures,
	}


func _rw06_1_review_definitions(library: Variant, selections: Array) -> Dictionary:
	var requested_scenarios: Dictionary = {}
	for selection_value in selections:
		var scenario_id := str(_dict(selection_value).get("scenario_id", ""))
		if not scenario_id.is_empty():
			requested_scenarios[scenario_id] = true
	var definitions: Dictionary = {}
	# Resolve only the requested owner-review scenarios. The legacy proof helper
	# resolves every scenario and repeatedly copies the complete overlay catalog,
	# which is unnecessary for these PNG-only authoring captures.
	for pool_value in library.environment_scenarios.values():
		for raw_definition_value in _array(pool_value):
			var raw_definition := _dict(raw_definition_value)
			var scenario_id := str(raw_definition.get("id", ""))
			if not requested_scenarios.has(scenario_id):
				continue
			var definition := SequenceCatalogScript.apply_overlay_readonly(
				raw_definition,
				library.scenario_sequence_catalog
			)
			if not _dict(definition.get("sequence", {})).is_empty():
				definitions[scenario_id] = definition
	return definitions


func _run_rw06_1_room_review(library: Variant) -> void:
	# Owner review is an authoring capture, not a test or evidence bundle. It
	# writes only six normal-view PNG sources and the two-row player-view sheet.
	var source_dir := "%s/q008_sources" % out_dir
	var directory_error := DirAccess.make_dir_recursive_absolute(source_dir)
	if directory_error != OK and not DirAccess.dir_exists_absolute(source_dir):
		push_error("Room review could not create %s (%s)." % [source_dir, error_string(directory_error)])
		quit(1)
		return
	var definitions := _rw06_1_review_definitions(library, RW06_1_ROOM_REVIEW_SELECTIONS)
	var archetypes: Dictionary = {}
	for archetype_value in library.environment_archetypes:
		var archetype := _dict(archetype_value)
		archetypes[str(archetype.get("id", ""))] = archetype
	var captures: Array = []
	for selection_value in RW06_1_ROOM_REVIEW_SELECTIONS:
		var selection := _dict(selection_value).duplicate(true)
		var archetype_id := str(selection.get("archetype_id", ""))
		var scenario_id := str(selection.get("scenario_id", ""))
		print("ROOM_REVIEW_BASE_BEGIN room=%s" % archetype_id)
		var base_preparation := await _rw06_1_prepare_base_room(_dict(archetypes.get(archetype_id, {})), library)
		if not bool(base_preparation.get("ok", false)):
			for error_value in _array(base_preparation.get("errors", [])):
				push_error(str(error_value))
			quit(1)
			return
		var base_path := "%s/%s_base.png" % [source_dir, archetype_id]
		var base_saved := await _rw06_1_save_review_png(base_path)
		if not base_saved:
			quit(1)
			return
		print("ROOM_REVIEW_BASE_SAVED room=%s" % archetype_id)
		print("ROOM_REVIEW_SCENARIO_BEGIN room=%s scenario=%s" % [archetype_id, scenario_id])
		var scenario_preparation := await _rw06_1_prepare_scenario_review(
			_dict(archetypes.get(archetype_id, {})),
			_dict(definitions.get(scenario_id, {})),
			selection,
			library
		)
		if not bool(scenario_preparation.get("ok", false)):
			for error_value in _array(scenario_preparation.get("errors", [])):
				push_error(str(error_value))
			quit(1)
			return
		var scenario_path := "%s/%s_busiest_physical.png" % [source_dir, archetype_id]
		var scenario_saved := await _rw06_1_save_review_png(scenario_path)
		if not scenario_saved:
			quit(1)
			return
		print("ROOM_REVIEW_SCENARIO_SAVED room=%s scenario=%s" % [archetype_id, scenario_id])
		captures.append({
			"archetype_id": archetype_id,
			"base_path": base_path,
			"scenario_path": scenario_path,
		})
	var sheet_path := "%s/q008_rooms.png" % out_dir
	if not _rw06_1_save_review_sheet(captures, sheet_path):
		quit(1)
		return
	print("RW06_1_ROOM_REVIEW rooms=%d out=%s" % [captures.size(), sheet_path])
	app.free()
	app = null
	await _settle(4)
	quit(0)


func _run_rw06_1_all_room_review(library: Variant) -> void:
	# Every-room authoring review stays PNG-only: normal production player views,
	# no marker overlay, manifest, hash, audit, or test-harness state injection.
	var source_dir := "%s/all_room_sources" % out_dir
	var directory_error := DirAccess.make_dir_recursive_absolute(source_dir)
	if directory_error != OK and not DirAccess.dir_exists_absolute(source_dir):
		push_error("All-room review could not create %s (%s)." % [source_dir, error_string(directory_error)])
		quit(1)
		return
	var surface_data := _rw06_1_read_json("res://data/environments/placement_surfaces.json")
	var surface_maps := _array(surface_data.get("maps", [])).duplicate(true)
	surface_maps.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		return str(_dict(left_value).get("id", "")) < str(_dict(right_value).get("id", ""))
	)
	var archetypes: Dictionary = {}
	for archetype_value in library.environment_archetypes:
		var archetype := _dict(archetype_value)
		archetypes[str(archetype.get("id", ""))] = archetype
	var selections_by_map: Dictionary = {}
	for selection_value in RW06_1_ALL_ROOM_REVIEW_SELECTIONS:
		var selection := _dict(selection_value)
		selections_by_map[str(selection.get("map_id", ""))] = selection
	var definitions := _rw06_1_review_definitions(library, RW06_1_ALL_ROOM_REVIEW_SELECTIONS)
	var captures: Array = []
	for map_value in surface_maps:
		var surface_map := _dict(map_value)
		var map_id := str(surface_map.get("id", ""))
		var archetype_id := str(surface_map.get("archetype_id", map_id))
		var archetype := _dict(archetypes.get(archetype_id, {}))
		if map_id.is_empty() or archetype.is_empty():
			continue
		# Old unlayered Punchline saves normalize onto their compatibility floor
		# before production rendering. Review the three reachable named floors below,
		# not the pre-migration placement alias that normal play cannot display.
		if str(surface_map.get("layer_id", "")).is_empty() \
				and not _dict(archetype.get("layers", {})).is_empty():
			print("ALL_ROOM_REVIEW_SKIP_MIGRATED_ALIAS map=%s" % map_id)
			continue
		print("ALL_ROOM_REVIEW_BASE_BEGIN map=%s" % map_id)
		var base_preparation := await _rw06_1_prepare_base_map(surface_map, archetype, library)
		if not bool(base_preparation.get("ok", false)):
			for error_value in _array(base_preparation.get("errors", [])):
				push_error(str(error_value))
			quit(1)
			return
		var file_id := _rw06_1_slot_marker_file_id(map_id)
		var base_path := "%s/%s_base.png" % [source_dir, file_id]
		var base_saved := await _rw06_1_save_review_png(base_path)
		if not base_saved:
			quit(1)
			return
		var scenario_path := base_path
		if selections_by_map.has(map_id):
			var selection := _dict(selections_by_map.get(map_id, {})).duplicate(true)
			var scenario_id := str(selection.get("scenario_id", ""))
			print("ALL_ROOM_REVIEW_SCENARIO_BEGIN map=%s scenario=%s" % [map_id, scenario_id])
			var scenario_preparation := await _rw06_1_prepare_scenario_review(
				archetype,
				_dict(definitions.get(scenario_id, {})),
				selection,
				library
			)
			if not bool(scenario_preparation.get("ok", false)):
				for error_value in _array(scenario_preparation.get("errors", [])):
					push_error(str(error_value))
				quit(1)
				return
			scenario_path = "%s/%s_busiest_physical.png" % [source_dir, file_id]
			var scenario_saved := await _rw06_1_save_review_png(scenario_path)
			if not scenario_saved:
				quit(1)
				return
		captures.append({"map_id": map_id, "base_path": base_path, "scenario_path": scenario_path})
		print("ALL_ROOM_REVIEW_SAVED map=%s" % map_id)
	var priority_captures: Array = []
	for capture_value in captures:
		var capture := _dict(capture_value)
		var captured_map_id := str(capture.get("map_id", ""))
		if captured_map_id in RW06_1_Q008_ARCHETYPE_IDS:
			priority_captures.append({
				"archetype_id": captured_map_id,
				"base_path": str(capture.get("base_path", "")),
				"scenario_path": str(capture.get("scenario_path", "")),
			})
	if not _rw06_1_save_review_sheet(priority_captures, "%s/q008_rooms.png" % out_dir):
		quit(1)
		return
	if not _rw06_1_save_review_sheet(priority_captures, "%s/rooms_A.png" % out_dir):
		quit(1)
		return
	var sheet_path := "%s/rooms_all.png" % out_dir
	if not _rw06_1_save_all_room_sheet(captures, sheet_path):
		quit(1)
		return
	print("RW06_1_ALL_ROOM_REVIEW rooms=%d out=%s" % [captures.size(), sheet_path])
	app.free()
	app = null
	await _settle(4)
	quit(0)


func _rw06_1_save_review_png(path: String) -> bool:
	var canvas: Variant = app.get("environment_canvas")
	if canvas == null:
		push_error("Room review has no production environment canvas.")
		return false
	_rw06_1_clear_player_view_artifacts(canvas)
	canvas.call("set_small_screen_mode", false)
	canvas.call("queue_redraw")
	await _settle(3)
	_rw06_1_clear_player_view_artifacts(canvas)
	canvas.call("queue_redraw")
	await _settle(1)
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var save_error := image.save_png(path)
	if save_error != OK:
		push_error("Room review could not write %s (%s)." % [path, error_string(save_error)])
		return false
	return true


func _rw06_1_save_review_sheet(captures: Array, path: String) -> bool:
	if captures.size() != RW06_1_ROOM_REVIEW_SELECTIONS.size():
		push_error("Room review source set is incomplete.")
		return false
	var cell_size := Vector2i(320, 180)
	var sheet := Image.create(cell_size.x * 3, cell_size.y * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#10151f"))
	for column in range(captures.size()):
		var room := _dict(captures[column])
		for row in range(2):
			var source_path := str(room.get("base_path" if row == 0 else "scenario_path", ""))
			var source := Image.load_from_file(source_path)
			if source == null or source.is_empty():
				push_error("Room review source is missing: %s." % source_path)
				return false
			source.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_LANCZOS)
			var destination := Vector2i(column * cell_size.x, row * cell_size.y)
			sheet.blit_rect(source, Rect2i(Vector2i.ZERO, cell_size), destination)
			_rw06_1_image_border(sheet, Rect2i(destination, cell_size), Color("#58c7ff") if row == 0 else Color("#f5c451"), 3)
	var save_error := sheet.save_png(path)
	if save_error != OK:
		push_error("Room review sheet could not be written to %s (%s)." % [path, error_string(save_error)])
		return false
	return true


func _rw06_1_save_all_room_sheet(captures: Array, path: String) -> bool:
	if captures.is_empty():
		push_error("All-room review has no player-view captures.")
		return false
	var view_size := Vector2i(320, 180)
	var card_size := Vector2i(view_size.x, view_size.y * 2)
	var columns := 4
	var rows := ceili(float(captures.size()) / float(columns))
	var sheet := Image.create(card_size.x * columns, card_size.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#10151f"))
	for index in range(captures.size()):
		var room := _dict(captures[index])
		var card_origin := Vector2i((index % columns) * card_size.x, int(index / columns) * card_size.y)
		for row in range(2):
			var source_path := str(room.get("base_path" if row == 0 else "scenario_path", ""))
			var source := Image.load_from_file(source_path)
			if source == null or source.is_empty():
				push_error("All-room review source is missing: %s." % source_path)
				return false
			source.resize(view_size.x, view_size.y, Image.INTERPOLATE_LANCZOS)
			var destination := card_origin + Vector2i(0, row * view_size.y)
			sheet.blit_rect(source, Rect2i(Vector2i.ZERO, view_size), destination)
			_rw06_1_image_border(sheet, Rect2i(destination, view_size), Color("#58c7ff") if row == 0 else Color("#f5c451"), 3)
	var save_error := sheet.save_png(path)
	if save_error != OK:
		push_error("All-room review sheet could not be written to %s (%s)." % [path, error_string(save_error)])
		return false
	return true


func _run_rw06_1_q008(library: Variant) -> void:
	var failures: Array = []
	var static_evidence := _rw06_1_read_json_evidence(rw06_1_static_report)
	failures.append_array(_array(static_evidence.get("errors", [])))
	var static_report := _dict(static_evidence.get("payload", {}))
	if bool(static_evidence.get("ok", false)):
		var static_schema := _rw06_1_validate_static_report(static_report)
		failures.append_array(_array(static_schema.get("errors", [])))
	var q008_paths: Array = ["%s/q008_rooms.png" % out_dir, "%s/q008_rooms.json" % out_dir]
	for archetype_value in RW06_1_Q008_ARCHETYPE_IDS:
		var production_archetype_id := str(archetype_value)
		q008_paths.append("%s/q008_sources/%s_base.png" % [out_dir, production_archetype_id])
		q008_paths.append("%s/q008_sources/%s_busiest_physical.png" % [out_dir, production_archetype_id])
	var directory_result := _rw06_1_ensure_owned_directory("q008_sources")
	failures.append_array(_array(directory_result.get("errors", [])))
	var manifest_result := _rw06_1_register_manifest_paths(q008_paths)
	failures.append_array(_array(manifest_result.get("errors", [])))
	var fresh_result := _rw06_1_assert_paths_absent(q008_paths)
	failures.append_array(_array(fresh_result.get("errors", [])))
	var selection_result: Dictionary = {"ok": false, "selections": [], "source_field": "", "errors": []}
	if failures.is_empty():
		selection_result = _rw06_1_q008_selections(static_report)
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
	var generation_identity := _rw06_1_q008_generation_identity(capture_attempts)
	if not bool(generation_identity.get("ok", false)):
		failures.append_array(_array(generation_identity.get("errors", [])))
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
		var failed_q008_paths: Array = []
		for path_value in q008_paths:
			if not str(path_value).ends_with("q008_rooms.json"):
				failed_q008_paths.append(path_value)
		var failed_set_cleanup := _rw06_1_cleanup_paths(failed_q008_paths)
		if bool(failed_set_cleanup.get("ok", false)) and bool(failed_set_cleanup.get("all_absent", false)):
			captures.clear()
			sheet["ok"] = false
			sheet["retained"] = false
		else:
			failures.append_array(_array(failed_set_cleanup.get("errors", ["Failed Q-008 set could not be removed completely."])))
			sheet["retained"] = FileAccess.file_exists("%s/q008_rooms.png" % out_dir)
	var report_payload := {
		"schema": "rw06_1_q008_room_proof/v1",
		"generated_at_utc": Time.get_datetime_string_from_system(true),
		"project_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"source_static_report": rw06_1_static_report,
		"source_static_report_sha256": str(static_evidence.get("sha256", "")),
		"generation_identity": generation_identity,
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
		"cleanup_failures": rw06_1_cleanup_failures.duplicate(),
	}
	var report_path := "%s/q008_rooms.json" % out_dir
	var report_write := _write_fix06_31_json(report_path, report_payload)
	var final_success := bool(report_payload.get("passed", false)) and bool(report_write.get("ok", false))
	if not bool(report_write.get("ok", false)):
		failures.append_array(_array(report_write.get("errors", ["Q-008 report write was not verified."])))
		var write_failure_cleanup := _rw06_1_cleanup_paths(q008_paths)
		if not bool(write_failure_cleanup.get("ok", false)):
			failures.append_array(_array(write_failure_cleanup.get("errors", [])))
	var owner_release := _rw06_1_release_capture_owner()
	if not bool(owner_release.get("ok", false)) or not bool(owner_release.get("absent", false)):
		final_success = false
		failures.append_array(_array(owner_release.get("errors", ["Q-008 capture owner marker was not released."])))
		if _rw06_1_capture_ownership_is_valid():
			var owner_failure_cleanup := _rw06_1_cleanup_paths(q008_paths)
			failures.append_array(_array(owner_failure_cleanup.get("errors", [])))
			var owner_retry := _rw06_1_release_capture_owner()
			failures.append_array(_array(owner_retry.get("errors", [])))
	print("RW06_1_Q008 rooms=%d sources=%d failures=%d out=%s" % [captures.size(), captures.size() * 2, failures.size(), out_dir])
	app.free()
	app = null
	await _settle(4)
	quit(0 if final_success else 1)


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
		var map_id := str(selection.get("map_id", "")).strip_edges()
		var map_parts := map_id.split(":", true, 1)
		var map_archetype_id := str(map_parts[0]) if not map_parts.is_empty() else ""
		var map_layer_id := str(map_parts[1]) if map_parts.size() > 1 else ""
		if map_archetype_id != archetype_id or str(selection.get("layer_id", "")) != map_layer_id:
			failures.append("Static Q-008 selection for %s has mismatched map/layer identity %s." % [archetype_id, map_id])
			continue
		if not bool(selection.get("day2_sample", false)):
			failures.append("Static Q-008 selection for %s is not marked as a day-2 identity." % archetype_id)
			continue
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


func _rw06_1_environment_map_id(environment: Dictionary) -> String:
	var archetype_id := str(environment.get("archetype_id", environment.get("id", ""))).strip_edges()
	var layer_id := str(environment.get("current_layer_id", environment.get("layer_id", ""))).strip_edges()
	return "%s:%s" % [archetype_id, layer_id] if not layer_id.is_empty() else archetype_id


func _rw06_1_strict_rect(value: Variant) -> Dictionary:
	var failures: Array = []
	if typeof(value) != TYPE_DICTIONARY:
		return {"ok": false, "rect": Rect2(), "errors": ["rectangle is not a native object"]}
	var snapshot: Dictionary = value
	var components: Array = []
	for key_value in ["x", "y", "w", "h"]:
		var key := str(key_value)
		var component: Variant = snapshot.get(key, null)
		if not (typeof(component) == TYPE_INT or typeof(component) == TYPE_FLOAT) or not is_finite(float(component)):
			failures.append("rectangle %s is missing or nonnumeric" % key)
		else:
			components.append(float(component))
	if not failures.is_empty():
		return {"ok": false, "rect": Rect2(), "errors": failures}
	var rect := Rect2(components[0], components[1], components[2], components[3])
	if not rect.has_area():
		failures.append("rectangle has zero or negative area")
	return {"ok": failures.is_empty(), "rect": rect, "errors": failures}


func _rw06_1_rect_pair_overlaps(entries: Array, rect_key: String) -> Array:
	var overlaps: Array = []
	for first_index in range(entries.size()):
		var first := _dict(entries[first_index])
		var first_result := _rw06_1_strict_rect(first.get(rect_key, null))
		if not bool(first_result.get("ok", false)):
			continue
		var first_rect: Rect2 = first_result.get("rect", Rect2())
		for second_index in range(first_index + 1, entries.size()):
			var second := _dict(entries[second_index])
			var second_result := _rw06_1_strict_rect(second.get(rect_key, null))
			if not bool(second_result.get("ok", false)):
				continue
			var second_rect: Rect2 = second_result.get("rect", Rect2())
			var intersection := first_rect.intersection(second_rect)
			if intersection.has_area():
				overlaps.append({
					"a": str(first.get("id", "")),
					"b": str(second.get("id", "")),
					"rect_key": rect_key,
					"area": intersection.get_area(),
				})
	return overlaps


func _rw06_1_validate_interaction_geometry(view_snapshot: Dictionary) -> Dictionary:
	var failures: Array = []
	var layout_value: Variant = view_snapshot.get("object_layout", null)
	var view_objects_value: Variant = view_snapshot.get("objects", null)
	if typeof(layout_value) != TYPE_DICTIONARY:
		failures.append("Active renderer object_layout is missing or mistyped.")
	if typeof(view_objects_value) != TYPE_ARRAY or _array(view_objects_value).is_empty():
		failures.append("Active renderer objects must be a nonempty native array.")
	var layout := _dict(layout_value)
	var objects_value: Variant = layout.get("objects", null)
	var objects := _array(objects_value)
	if typeof(objects_value) != TYPE_ARRAY or objects.is_empty():
		failures.append("Renderer object_layout.objects must be a nonempty native array.")
	var seen_ids: Dictionary = {}
	for index in range(objects.size()):
		if typeof(objects[index]) != TYPE_DICTIONARY:
			failures.append("Renderer layout object %d is not a native object." % index)
			continue
		var object_data: Dictionary = objects[index]
		var object_id := str(object_data.get("id", "")).strip_edges()
		if object_id.is_empty() or seen_ids.has(object_id):
			failures.append("Renderer layout object identity is empty or duplicated: %s." % object_id)
		else:
			seen_ids[object_id] = true
		for rect_key_value in ["interaction_rect", "label_rect"]:
			var rect_key := str(rect_key_value)
			var rect_result := _rw06_1_strict_rect(object_data.get(rect_key, null))
			if not bool(rect_result.get("ok", false)):
				failures.append("Renderer object %s has invalid %s: %s." % [object_id, rect_key, str(_array(rect_result.get("errors", [])))])
	var interaction_overlaps := _rw06_1_rect_pair_overlaps(objects, "interaction_rect")
	var label_overlaps := _rw06_1_rect_pair_overlaps(objects, "label_rect")
	if not interaction_overlaps.is_empty():
		failures.append("Renderer exposes %d overlapping interaction rectangles." % interaction_overlaps.size())
	if not label_overlaps.is_empty():
		failures.append("Renderer exposes %d overlapping label rectangles." % label_overlaps.size())
	var renderer_overlap_count: Variant = layout.get("overlap_count", null)
	var renderer_overlaps_value: Variant = layout.get("overlaps", null)
	if typeof(renderer_overlap_count) != TYPE_INT or int(renderer_overlap_count) < 0:
		failures.append("Renderer overlap_count must be a native nonnegative integer.")
	if typeof(renderer_overlaps_value) != TYPE_ARRAY:
		failures.append("Renderer overlaps must be a native array.")
	elif typeof(renderer_overlap_count) == TYPE_INT and int(renderer_overlap_count) != _array(renderer_overlaps_value).size():
		failures.append("Renderer overlap_count does not match overlaps array size.")
	if typeof(renderer_overlap_count) == TYPE_INT and int(renderer_overlap_count) != 0:
		failures.append("Renderer reports %d authored footprint overlaps." % int(renderer_overlap_count))
	var label_layout_value: Variant = layout.get("label_layout", null)
	if typeof(label_layout_value) != TYPE_DICTIONARY:
		failures.append("Renderer label_layout is missing or mistyped.")
	else:
		var label_layout: Dictionary = label_layout_value
		for key_value in ["label_count", "default_label_overlap_count", "resolved_label_overlap_count", "default_object_overlap_count", "resolved_object_overlap_count"]:
			var key := str(key_value)
			if typeof(label_layout.get(key, null)) != TYPE_INT or int(label_layout.get(key, -1)) < 0:
				failures.append("Renderer label_layout.%s must be a native nonnegative integer." % key)
		if typeof(label_layout.get("resolved_label_overlap_count", null)) == TYPE_INT \
				and int(label_layout.get("resolved_label_overlap_count", -1)) != 0:
			failures.append("Renderer reports unresolved label-to-label overlaps.")
		if typeof(label_layout.get("resolved_object_overlap_count", null)) == TYPE_INT \
				and int(label_layout.get("resolved_object_overlap_count", -1)) != 0:
			failures.append("Renderer reports unresolved label-to-object overlaps.")
	return {
		"ok": failures.is_empty(),
		"object_layout": layout.duplicate(true),
		"interaction_overlaps": interaction_overlaps,
		"label_overlaps": label_overlaps,
		"errors": failures,
	}


func _rw06_1_rendered_identity(selection: Dictionary, canvas: Variant, view_snapshot: Dictionary, expected_small_screen: bool) -> Dictionary:
	var failures: Array = []
	var run_state: Variant = app.get("run_state")
	var run_environment := _dict(run_state.current_environment) if run_state != null else {}
	var rendered_environment := _dict(canvas.get("foundation_snapshot")) if canvas != null else {}
	var expected_archetype_id := str(selection.get("archetype_id", "")).strip_edges()
	var expected_map_id := str(selection.get("map_id", "")).strip_edges()
	var expected_scenario_id := str(selection.get("scenario_id", "")).strip_edges()
	var expected_phase_id := str(selection.get("phase_id", "")).strip_edges()
	var run_state_identity := _dict(run_environment.get("scenario_sequence_state", {}))
	var rendered_state_identity := _dict(rendered_environment.get("scenario_sequence_state", {}))
	var run_map_id := _rw06_1_environment_map_id(run_environment)
	var rendered_map_id := _rw06_1_environment_map_id(rendered_environment)
	var visual_context := _dict(rendered_environment.get("visual_context", {}))
	var art_key := str(visual_context.get("art_key", expected_archetype_id)).strip_edges()
	var expected_environment_id := art_key if ["punchline_club", "punchline_back_room"].has(art_key) else expected_archetype_id
	var stored_digest := str(rendered_environment.get("scenario_layout_authority_digest", ""))
	var active_digest := str(view_snapshot.get("scenario_layout_authority_digest", ""))
	var active_object_ids: Array = []
	var layout_object_ids: Array = []
	for object_value in _array(view_snapshot.get("objects", [])):
		active_object_ids.append(str(_dict(object_value).get("id", "")).strip_edges())
	for object_value in _array(_dict(view_snapshot.get("object_layout", {})).get("objects", [])):
		layout_object_ids.append(str(_dict(object_value).get("id", "")).strip_edges())
	active_object_ids.sort()
	layout_object_ids.sort()
	var base_capture := expected_scenario_id.is_empty() and expected_phase_id == "base_inventory"
	var phase_matches := str(run_state_identity.get("phase_id", "")).is_empty() \
		and str(rendered_state_identity.get("phase_id", "")).is_empty()
	if not base_capture:
		phase_matches = str(run_state_identity.get("phase_id", "")) == expected_phase_id \
			and str(rendered_state_identity.get("phase_id", "")) == expected_phase_id
	var assertions := {
		"uses_foundation_snapshot": typeof(view_snapshot.get("uses_foundation_snapshot", null)) == TYPE_BOOL
			and bool(view_snapshot.get("uses_foundation_snapshot", false)),
		"request_map_matches_archetype": expected_map_id == expected_archetype_id
			or expected_map_id.begins_with("%s:" % expected_archetype_id),
		"run_environment_matches": not expected_map_id.is_empty() and run_map_id == expected_map_id,
		"rendered_environment_matches": not expected_map_id.is_empty() and rendered_map_id == expected_map_id,
		"scenario_matches": str(run_state_identity.get("scenario_id", "")) == expected_scenario_id
			and str(rendered_state_identity.get("scenario_id", "")) == expected_scenario_id,
		"phase_matches": phase_matches,
		"active_environment_matches": typeof(view_snapshot.get("environment_id", null)) == TYPE_STRING
			and str(view_snapshot.get("environment_id", "")) == expected_environment_id,
		"active_authority_digest_matches": active_digest == stored_digest
			and (expected_scenario_id.is_empty() or not active_digest.is_empty()),
		"active_object_identity_matches_layout": not active_object_ids.is_empty()
			and active_object_ids == layout_object_ids
			and not active_object_ids.has(""),
		"active_small_screen_mode_matches": typeof(view_snapshot.get("small_screen_mode", null)) == TYPE_BOOL
			and bool(view_snapshot.get("small_screen_mode", false)) == expected_small_screen,
	}
	for assertion_value in assertions.keys():
		var assertion_name := str(assertion_value)
		if not bool(assertions.get(assertion_name, false)):
			failures.append("%s capture identity failed %s (run=%s, rendered=%s, scenario=%s/%s, phase=%s/%s)." % [
				expected_archetype_id,
				assertion_name,
				run_map_id,
				rendered_map_id,
				str(run_state_identity.get("scenario_id", "")),
				str(rendered_state_identity.get("scenario_id", "")),
				str(run_state_identity.get("phase_id", "")),
				str(rendered_state_identity.get("phase_id", "")),
			])
	return {
		"ok": failures.is_empty(),
		"requested": {
			"archetype_id": expected_archetype_id,
			"map_id": expected_map_id,
			"scenario_id": expected_scenario_id,
			"phase_id": expected_phase_id,
		},
		"run": {
			"map_id": run_map_id,
			"scenario_id": str(run_state_identity.get("scenario_id", "")),
			"phase_id": str(run_state_identity.get("phase_id", "")),
		},
		"rendered": {
			"map_id": rendered_map_id,
			"environment_id": str(view_snapshot.get("environment_id", "")),
			"scenario_id": str(rendered_state_identity.get("scenario_id", "")),
			"phase_id": str(rendered_state_identity.get("phase_id", "")),
			"scenario_layout_authority_digest": active_digest,
			"object_ids": active_object_ids,
		},
		"assertions": assertions,
		"errors": failures,
	}


func _rw06_1_expected_capture_seed(selection: Dictionary) -> String:
	var archetype_id := str(selection.get("archetype_id", "")).strip_edges()
	var scenario_id := str(selection.get("scenario_id", "")).strip_edges()
	return "RW06-1-CONTACT-BASE:%s" % archetype_id if scenario_id.is_empty() else "RW06-1-CONTACT-%s" % scenario_id


func _rw06_1_generation_identity(run_state: Variant, selection: Dictionary) -> Dictionary:
	var failures: Array = []
	if run_state == null:
		return {"ok": false, "identity_key": "", "errors": ["Capture has no run state provenance."]}
	var environment := _dict(run_state.current_environment)
	var scenario_state := _dict(environment.get("scenario_sequence_state", {}))
	var world_map := _dict(run_state.world_map)
	var expected_seed_text := _rw06_1_expected_capture_seed(selection)
	var expected_map_id := str(selection.get("map_id", "")).strip_edges()
	var expected_scenario_id := str(selection.get("scenario_id", "")).strip_edges()
	var expected_phase_id := str(selection.get("phase_id", "")).strip_edges()
	var actual_seed_text := str(run_state.seed_text).strip_edges()
	var actual_world_seed_text := str(world_map.get("seed_text", "")).strip_edges()
	var actual_map_id := _rw06_1_environment_map_id(environment)
	var actual_scenario_id := str(scenario_state.get("scenario_id", "")).strip_edges()
	var actual_phase_id := str(scenario_state.get("phase_id", "")).strip_edges()
	var base_capture := expected_scenario_id.is_empty() and expected_phase_id == "base_inventory"
	var assertions := {
		"seed_text_exact": not expected_seed_text.is_empty() and actual_seed_text == expected_seed_text,
		"world_seed_text_exact_when_present": world_map.is_empty() or actual_world_seed_text == expected_seed_text,
		"seed_value_nonzero": int(run_state.seed_value) != 0,
		"rng_seed_nonzero": int(run_state.rng_seed) != 0,
		"rng_state_nonzero": int(run_state.rng_state) != 0,
		"environment_map_exact": not expected_map_id.is_empty() and actual_map_id == expected_map_id,
		"scenario_exact": actual_scenario_id == expected_scenario_id,
		"phase_exact": actual_phase_id.is_empty() if base_capture else actual_phase_id == expected_phase_id,
	}
	for assertion_value in assertions.keys():
		var assertion_name := str(assertion_value)
		if not bool(assertions.get(assertion_name, false)):
			failures.append("Capture provenance failed %s for %s." % [assertion_name, expected_map_id])
	var identity_key := "%s|%d|%d|%d|%s|%s|%s" % [
		actual_seed_text,
		int(run_state.seed_value),
		int(run_state.rng_seed),
		int(run_state.rng_state),
		actual_map_id,
		actual_scenario_id,
		expected_phase_id if base_capture else actual_phase_id,
	]
	if identity_key.strip_edges().is_empty():
		failures.append("Capture provenance identity key is empty.")
	return {
		"ok": failures.is_empty(),
		"identity_key": identity_key,
		"expected_seed_text": expected_seed_text,
		"seed_text": actual_seed_text,
		"seed_value": int(run_state.seed_value),
		"rng_seed": int(run_state.rng_seed),
		"rng_state": int(run_state.rng_state),
		"world_map_seed_text": actual_world_seed_text,
		"environment_map_id": actual_map_id,
		"scenario_id": actual_scenario_id,
		"phase_id": actual_phase_id,
		"assertions": assertions,
		"errors": failures,
	}


func _rw06_1_contact_generation_identity(capture_attempts: Array) -> Dictionary:
	var captures: Array = []
	var failures: Array = []
	var seen_identity_keys: Dictionary = {}
	for attempt_value in capture_attempts:
		var attempt := _dict(attempt_value)
		var identity := _dict(attempt.get("generation_identity", {}))
		var identity_key := str(identity.get("identity_key", "")).strip_edges()
		if not bool(identity.get("ok", false)):
			failures.append_array(_array(identity.get("errors", ["Contact capture provenance is invalid."])))
		if identity_key.is_empty() or seen_identity_keys.has(identity_key):
			failures.append("Contact capture provenance identity is empty or duplicated: %s." % identity_key)
		seen_identity_keys[identity_key] = true
		captures.append({
			"selection": _dict(attempt.get("selection", {})).duplicate(true),
			"generation_identity": identity.duplicate(true),
		})
	if captures.size() != (RW06_1_DAY2_ARCHETYPE_IDS.size() if rw06_1_day2_only else RW06_1_CONTACT_ROOM_COUNT):
		failures.append("Contact provenance count does not match the requested capture count.")
	return {
		"ok": failures.is_empty(),
		"strategy": "independent_named_seed_per_capture",
		"capture_count": captures.size(),
		"captures": captures,
		"errors": failures,
	}


func _rw06_1_q008_generation_identity(capture_attempts: Array) -> Dictionary:
	var captures: Array = []
	var failures: Array = []
	var seen_identity_keys: Dictionary = {}
	for attempt_value in capture_attempts:
		var attempt := _dict(attempt_value)
		for role in ["base", "busiest_physical"]:
			var capture := _dict(attempt.get(role, {}))
			if capture.is_empty():
				continue
			var identity := _dict(capture.get("generation_identity", {}))
			var identity_key := str(identity.get("identity_key", "")).strip_edges()
			if not bool(identity.get("ok", false)):
				failures.append_array(_array(identity.get("errors", ["Q-008 capture provenance is invalid."])))
			if identity_key.is_empty() or seen_identity_keys.has(identity_key):
				failures.append("Q-008 capture provenance identity is empty or duplicated: %s." % identity_key)
			seen_identity_keys[identity_key] = true
			captures.append({
				"archetype_id": str(attempt.get("archetype_id", "")),
				"capture_role": role,
				"generation_identity": identity.duplicate(true),
			})
	if captures.size() != RW06_1_Q008_ARCHETYPE_IDS.size() * 2:
		failures.append("Q-008 provenance must contain exactly six unique captures.")
	return {
		"ok": failures.is_empty(),
		"strategy": "independent_named_seed_per_capture",
		"capture_count": captures.size(),
		"captures": captures,
		"errors": failures,
	}


func _rw06_1_capture_normal_source(selection: Dictionary, path: String) -> Dictionary:
	var archetype_id := str(selection.get("archetype_id", ""))
	var initial_cleanup := _rw06_1_remove_file(path)
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
	var view_snapshot := _dict(canvas.call("current_view_snapshot"))
	var cleanliness := _rw06_1_player_view_cleanliness(canvas, archetype_id, "normal")
	var rendered_identity := _rw06_1_rendered_identity(selection, canvas, view_snapshot, false)
	var geometry_validation := _rw06_1_validate_interaction_geometry(view_snapshot)
	var generation_identity := _rw06_1_generation_identity(app.get("run_state"), selection)
	var object_layout := _dict(view_snapshot.get("object_layout", {}))
	var direct_interaction_overlaps := _array(geometry_validation.get("interaction_overlaps", []))
	var failures: Array = _array(initial_cleanup.get("errors", [])).duplicate()
	if not bool(cleanliness.get("ok", false)):
		failures.append_array(_array(cleanliness.get("errors", ["%s normal player view is not clean." % archetype_id])))
	if not bool(rendered_identity.get("ok", false)):
		failures.append_array(_array(rendered_identity.get("errors", ["%s normal capture rendered the wrong environment." % archetype_id])))
	if not bool(geometry_validation.get("ok", false)):
		failures.append_array(_array(geometry_validation.get("errors", ["%s normal capture geometry is invalid." % archetype_id])))
	if not bool(generation_identity.get("ok", false)):
		failures.append_array(_array(generation_identity.get("errors", ["%s normal capture provenance is invalid." % archetype_id])))
	var image_validation: Dictionary = {
		"ok": false,
		"path": path,
		"expected_size": _rw06_1_size_snapshot(RW06_1_SOURCE_CAPTURE_SIZE),
		"errors": ["Source image was not written because pre-capture validation failed."],
	}
	if failures.is_empty():
		var image := root.get_viewport().get_texture().get_image()
		var save_error := image.save_png(path)
		if save_error != OK:
			failures.append("%s normal capture could not be written to %s (%s)." % [archetype_id, path, error_string(save_error)])
		else:
			image_validation = _rw06_1_validate_png(path, RW06_1_SOURCE_CAPTURE_SIZE)
			if not bool(image_validation.get("ok", false)):
				failures.append_array(_array(image_validation.get("errors", [])))
	if not failures.is_empty():
		var failed_capture_cleanup := _rw06_1_remove_file(path)
		if not bool(failed_capture_cleanup.get("ok", false)) or not bool(failed_capture_cleanup.get("absent", false)):
			failures.append_array(_array(failed_capture_cleanup.get("errors", ["Failed Q-008 source image was not removed."])))
	return {
		"ok": failures.is_empty(),
		"player_view_clean": failures.is_empty() and bool(cleanliness.get("ok", false)),
		"selection": selection.duplicate(true),
		"mode": "normal",
		"path": path,
		"sha256": FileAccess.get_sha256(path) if failures.is_empty() and FileAccess.file_exists(path) else "",
		"capture_source": "production_root_viewport_texture",
		"post_processed": false,
		"generation_identity": generation_identity,
		"rendered_identity": rendered_identity,
		"geometry_validation": geometry_validation,
		"image_validation": image_validation,
		"player_view_cleanliness": cleanliness,
		"object_layout": object_layout,
		"direct_interaction_overlaps": direct_interaction_overlaps,
		"errors": failures,
	}


func _rw06_1_build_q008_sheet(captures: Array, path: String) -> Dictionary:
	var initial_cleanup := _rw06_1_remove_file(path)
	var failures: Array = _array(initial_cleanup.get("errors", [])).duplicate()
	if captures.size() != RW06_1_Q008_ARCHETYPE_IDS.size():
		failures.append("Q-008 sheet requires exactly three rooms.")
		return {"ok": false, "path": path, "expected_size": _rw06_1_size_snapshot(RW06_1_Q008_SHEET_SIZE), "errors": failures, "cells": []}
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
			var source_validation := _rw06_1_validate_png(source_path, RW06_1_SOURCE_CAPTURE_SIZE)
			if not bool(source_validation.get("ok", false)):
				failures.append_array(_array(source_validation.get("errors", [])))
				continue
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
		var failed_source_cleanup := _rw06_1_remove_file(path)
		if not bool(failed_source_cleanup.get("ok", false)) or not bool(failed_source_cleanup.get("absent", false)):
			failures.append_array(_array(failed_source_cleanup.get("errors", ["Incomplete Q-008 sheet was not removed."])))
		return {"ok": false, "path": path, "expected_size": _rw06_1_size_snapshot(RW06_1_Q008_SHEET_SIZE), "errors": failures, "cells": cells}
	var save_error := sheet.save_png(path)
	if save_error != OK:
		failures.append("Q-008 sheet could not be written to %s (%s)." % [path, error_string(save_error)])
	var image_validation := _rw06_1_validate_png(path, RW06_1_Q008_SHEET_SIZE) if save_error == OK else {
		"ok": false,
		"path": path,
		"expected_size": _rw06_1_size_snapshot(RW06_1_Q008_SHEET_SIZE),
		"errors": ["Q-008 sheet save failed before validation."],
	}
	if not bool(image_validation.get("ok", false)):
		failures.append_array(_array(image_validation.get("errors", [])))
	if not failures.is_empty():
		var failed_sheet_cleanup := _rw06_1_remove_file(path)
		if not bool(failed_sheet_cleanup.get("ok", false)) or not bool(failed_sheet_cleanup.get("absent", false)):
			failures.append_array(_array(failed_sheet_cleanup.get("errors", ["Invalid Q-008 sheet was not removed."])))
	return {
		"ok": failures.is_empty(),
		"path": path,
		"sha256": FileAccess.get_sha256(path) if failures.is_empty() else "",
		"size": {"w": sheet.get_width(), "h": sheet.get_height()},
		"expected_size": _rw06_1_size_snapshot(RW06_1_Q008_SHEET_SIZE),
		"image_validation": image_validation,
		"columns": 3,
		"rows": 2,
		"cells": cells,
		"errors": failures,
	}


func _rw06_1_remove_q008_artifacts() -> Dictionary:
	var paths: Array = ["%s/q008_rooms.png" % out_dir, "%s/q008_rooms.json" % out_dir]
	for archetype_value in RW06_1_Q008_ARCHETYPE_IDS:
		var archetype_id := str(archetype_value)
		paths.append("%s/q008_sources/%s_base.png" % [out_dir, archetype_id])
		paths.append("%s/q008_sources/%s_busiest_physical.png" % [out_dir, archetype_id])
	return _rw06_1_cleanup_paths(paths)


func _rw06_1_remove_q008_source_images() -> Dictionary:
	var paths: Array = []
	for archetype_value in RW06_1_Q008_ARCHETYPE_IDS:
		var archetype_id := str(archetype_value)
		paths.append("%s/q008_sources/%s_base.png" % [out_dir, archetype_id])
		paths.append("%s/q008_sources/%s_busiest_physical.png" % [out_dir, archetype_id])
	return _rw06_1_cleanup_paths(paths)


func _run_rw06_1_slot_markers(library: Variant) -> void:
	var failures: Array = []
	var surface_data := _rw06_1_read_json("res://data/environments/placement_surfaces.json")
	var surface_maps := _array(surface_data.get("maps", []))
	var draft_mode := not rw06_1_slot_marker_maps.is_empty()
	if not rw06_1_slot_marker_maps.is_empty():
		var requested: Dictionary = {}
		for map_id_value in rw06_1_slot_marker_maps.split(",", false):
			var map_id := str(map_id_value).strip_edges()
			if not map_id.is_empty():
				requested[map_id] = true
		var selected_maps: Array = []
		for map_value in surface_maps:
			var surface_map := _dict(map_value)
			if requested.has(str(surface_map.get("id", ""))):
				selected_maps.append(surface_map)
		surface_maps = selected_maps
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
			var captured := await _rw06_1_capture_slot_markers(surface_map, draft_mode)
			capture_attempts.append(captured.duplicate(true))
			if not bool(captured.get("ok", false)):
				failures.append_array(_array(captured.get("errors", ["%s slot markers could not be captured." % map_id])))
				continue
			captures.append(captured)
	var complete_set := failures.is_empty() and captures.size() == surface_maps.size()
	if not complete_set:
		_rw06_1_remove_slot_marker_source_images(surface_maps)
		captures.clear()
	if draft_mode:
		# The selected-map authoring loop is deliberately PNG-only. It is a visual
		# placement aid, not a test, audit, evidence bundle, or hash manifest.
		print("RW06_1_SLOT_MARKER_DRAFT maps=%d out=%s" % [captures.size(), out_dir])
	else:
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
		var base_archetype := archetype
		# Layered rooms retain an unqualified placement map for legacy saves that
		# predate current_layer_id. Render that compatibility surface from the
		# archetype's flat fields instead of silently selecting its default layer.
		if not _dict(archetype.get("layers", {})).is_empty():
			base_archetype = archetype.duplicate(true)
			for metadata_key in ["layers", "default_layer_id", "layer_discovery_defaults", "compatibility_primary_layer_id", "environment_layer_schema_version"]:
				base_archetype.erase(metadata_key)
		return await _rw06_1_prepare_base_room(base_archetype, library)
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


func _rw06_1_capture_slot_markers(surface_map: Dictionary, draft_mode: bool = false) -> Dictionary:
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
	var empty_objects: Array = []
	var cleanliness: Dictionary = {}
	if not draft_mode:
		var object_layout := _canvas_object_layout()
		empty_objects = _array(object_layout.get("objects", []))
		if not empty_objects.is_empty():
			failures.append("%s empty-room marker source retained %d interactable objects." % [map_id, empty_objects.size()])
		cleanliness = _rw06_1_player_view_cleanliness(canvas, archetype_id, "slot_markers")
		if not bool(cleanliness.get("ok", false)):
			failures.append_array(_array(cleanliness.get("errors", ["%s marker source is not clean before its capture-only overlay." % map_id])))
	var marker_result := _rw06_1_slot_marker_rows(surface_map, canvas)
	if not draft_mode:
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
		_rw06_1_remove_slot_marker_file(path)
	return {
		"ok": failures.is_empty(),
		"map_id": map_id,
		"archetype_id": archetype_id,
		"layer_id": layer_id,
		"art_key": str(surface_map.get("art_key", "")),
		"path": path,
		"sha256": "" if draft_mode or not FileAccess.file_exists(path) else FileAccess.get_sha256(path),
		"capture_source": "production_root_viewport_texture_plus_capture_only_slot_overlay",
		"post_processed": false,
		"capture_only_overlay_removed": overlay_removed,
		"empty_interactable_count": empty_objects.size(),
		"slot_count": manifest_rows.size(),
		"slot_number_manifest": [] if draft_mode else manifest_rows,
		"player_view_cleanliness_before_overlay": {} if draft_mode else cleanliness,
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


func _rw06_1_remove_slot_marker_file(path: String) -> Dictionary:
	var failures: Array = []
	var absolute_path := _rw06_1_normalize_absolute_path(path)
	var absolute_output_root := _rw06_1_normalize_absolute_path(out_dir)
	if not _rw06_1_path_is_inside(absolute_path, absolute_output_root):
		failures.append("Slot-marker cleanup refused a path outside its output root: %s." % absolute_path)
	elif _rw06_1_path_has_link_boundary(absolute_path):
		failures.append("Slot-marker cleanup refused a link/reparse path: %s." % absolute_path)
	elif FileAccess.file_exists(absolute_path) or DirAccess.dir_exists_absolute(absolute_path):
		var remove_error := DirAccess.remove_absolute(absolute_path)
		if remove_error != OK:
			failures.append("Slot-marker cleanup failed for %s (%s)." % [absolute_path, error_string(remove_error)])
	if FileAccess.file_exists(absolute_path) or DirAccess.dir_exists_absolute(absolute_path):
		failures.append("Slot-marker cleanup could not verify absence: %s." % absolute_path)
	return {"ok": failures.is_empty(), "absent": failures.is_empty(), "errors": failures}


func _rw06_1_remove_slot_marker_artifacts(surface_maps: Array) -> void:
	_rw06_1_remove_slot_marker_source_images(surface_maps)
	_rw06_1_remove_slot_marker_file("%s/slot_markers/slot_marker_manifest.json" % out_dir)


func _rw06_1_remove_slot_marker_source_images(surface_maps: Array) -> void:
	for map_value in surface_maps:
		var map_id := str(_dict(map_value).get("id", ""))
		if not map_id.is_empty():
			_rw06_1_remove_slot_marker_file("%s/slot_markers/%s.png" % [out_dir, _rw06_1_slot_marker_file_id(map_id)])


func _rw06_1_prepare_base_room(archetype: Dictionary, library: Variant) -> Dictionary:
	var archetype_id := str(archetype.get("id", ""))
	if archetype_id.is_empty():
		return {"ok": false, "errors": ["rw06_1 base-room capture has no archetype definition."]}
	# Base captures must not inherit RNG, world, or scenario state from the room
	# captured immediately before them. Each room starts from its own named seed.
	var run_state := RunStateScript.new()
	run_state.start_new("RW06-1-CONTACT-BASE:%s" % archetype_id)
	var generator := RunGeneratorScript.new(library)
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
	data["game_states"] = generator.call("_generated_game_states", run_state, data, rng)
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data, library)
	run_state.save_rng(rng)
	run_state.set_environment(data)
	app.set("run_state", run_state)
	app.set("generator", generator)
	app.call("_clear_selected_game_action")
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_render_environment_screen")
	await _settle(3)
	var rendered_environment := _dict(run_state.current_environment)
	if str(rendered_environment.get("archetype_id", "")) != archetype_id \
			or not str(rendered_environment.get("current_layer_id", "")).is_empty():
		return {"ok": false, "errors": ["Base-room request %s prepared mismatched environment %s." % [archetype_id, _rw06_1_environment_map_id(rendered_environment)]]}
	var base_selection := {"archetype_id": archetype_id, "map_id": archetype_id, "scenario_id": "", "phase_id": "base_inventory"}
	return {"ok": true, "generation_identity": _rw06_1_generation_identity(run_state, base_selection), "errors": []}


func _rw06_1_prepare_scenario_review(archetype: Dictionary, definition: Dictionary, selection: Dictionary, library: Variant) -> Dictionary:
	var archetype_id := str(archetype.get("id", ""))
	var scenario_id := str(definition.get("id", ""))
	if archetype_id.is_empty() or scenario_id.is_empty() or str(definition.get("archetype_id", "")) != archetype_id:
		return {"ok": false, "errors": ["Room review scenario definition does not match its room."]}
	# Build and install the room through the normal production generation seam,
	# then perform one exact authored action path to the known busiest phase. This
	# is an owner-review playthrough, not a test harness, trace search, or audit.
	var run_state := RunStateScript.new()
	run_state.start_new("RW06-1-ROOM-REVIEW:%s" % scenario_id)
	var generator := RunGeneratorScript.new(library)
	var rng: Variant = run_state.create_rng("rw06_1_room_review:%s" % scenario_id)
	var scenario_layer_id := str(definition.get("layer_id", "")).strip_edges()
	var environment: Variant
	if scenario_layer_id.is_empty():
		environment = EnvironmentInstance.from_archetype(
			archetype,
			1,
			rng,
			library,
			run_state.challenge_config,
			definition
		)
	else:
		environment = EnvironmentInstance.from_archetype_layer(
			archetype,
			scenario_layer_id,
			1,
			rng,
			library,
			run_state.challenge_config,
			definition
		)
	var data: Dictionary = environment.to_dict()
	data["world_node_id"] = archetype_id
	data["game_states"] = generator.call("_generated_game_states", run_state, data, rng)
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data, library)
	run_state.save_rng(rng)
	var installed := _dict(generator.call("_install_environment", run_state, data))
	if not bool(installed.get("ok", false)):
		return {"ok": false, "errors": _array(installed.get("errors", ["Room review could not install the scenario room."]))}
	print("ROOM_REVIEW_SCENARIO_INSTALLED scenario=%s" % scenario_id)
	run_state.bankroll = maxi(run_state.bankroll, 100000)
	var command_index := 0
	for command_id_value in _array(selection.get("command_path", [])):
		var command_id := str(command_id_value)
		print("ROOM_REVIEW_COMMAND_BEGIN scenario=%s command=%s" % [scenario_id, command_id])
		var applied := _rw06_1_apply_review_command(
			run_state,
			definition,
			command_id,
			"rw06_1_room_review:%s:%d" % [scenario_id, command_index]
		)
		if not bool(applied.get("ok", false)):
			return {"ok": false, "errors": _array(applied.get("errors", ["Room review could not perform %s." % command_id]))}
		print("ROOM_REVIEW_COMMAND_DONE scenario=%s command=%s" % [scenario_id, command_id])
		command_index += 1
	var projection := _dict(run_state.current_environment.get("scenario_sequence_projection", {}))
	var target_phase := str(selection.get("phase_id", ""))
	if str(projection.get("phase_id", "")) != target_phase:
		return {"ok": false, "errors": ["Room review reached %s instead of %s for %s." % [str(projection.get("phase_id", "")), target_phase, scenario_id]]}
	app.set("run_state", run_state)
	app.set("generator", generator)
	app.call("_clear_selected_game_action")
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_render_environment_screen")
	await _settle(3)
	print("ROOM_REVIEW_SCENARIO_RENDERED scenario=%s phase=%s" % [scenario_id, target_phase])
	return {"ok": true, "errors": []}


func _rw06_1_apply_review_command(run_state: Variant, definition: Dictionary, command_id: String, receipt_id: String) -> Dictionary:
	var state := _dict(run_state.current_environment.get("scenario_sequence_state", {}))
	var origin := _rw06_1_find_action_origin(state, definition, command_id)
	if origin.is_empty():
		return {"ok": false, "errors": ["Room review has no available action origin for %s." % command_id]}
	var owner_namespace := str(origin.get("owner_namespace", ""))
	var stable_object_id := str(origin.get("stable_object_id", ""))
	var descriptor := ScenarioSequenceRuntimeScript._command_descriptor(
		state,
		definition,
		owner_namespace,
		stable_object_id,
		command_id,
		{}
	)
	return _dict(run_state.scenario_sequence_command(
		command_id,
		receipt_id,
		{},
		owner_namespace,
		stable_object_id,
		{},
		str(descriptor.get("action_origin_owner_namespace", "")),
		str(descriptor.get("action_origin_stable_object_id", "")),
		str(descriptor.get("action_origin_receipt_key", "")),
		str(descriptor.get("action_origin_boundary_id", "")),
		str(descriptor.get("action_origin_fingerprint", ""))
	))


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
		"generation_identity": _rw06_1_generation_identity(run_state, selection),
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
		var path := "%s/%s/%s.png" % [out_dir, mode, archetype_id]
		var initial_cleanup := _rw06_1_remove_file(path)
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
		var view_snapshot := _dict(canvas.call("current_view_snapshot"))
		var cleanliness := _rw06_1_player_view_cleanliness(canvas, archetype_id, mode)
		var rendered_identity := _rw06_1_rendered_identity(selection, canvas, view_snapshot, mode == "expanded")
		var geometry_validation := _rw06_1_validate_interaction_geometry(view_snapshot)
		var generation_identity := _rw06_1_generation_identity(app.get("run_state"), selection)
		var object_layout := _dict(view_snapshot.get("object_layout", {}))
		var direct_interaction_overlaps := _array(geometry_validation.get("interaction_overlaps", []))
		var mode_failures: Array = _array(initial_cleanup.get("errors", [])).duplicate()
		layouts[mode] = {
			"path": path,
			"capture_source": "production_root_viewport_texture",
			"post_processed": false,
			"generation_identity": generation_identity,
			"rendered_identity": rendered_identity,
			"geometry_validation": geometry_validation,
			"player_view_cleanliness": cleanliness,
			"object_layout": object_layout,
			"direct_interaction_overlaps": direct_interaction_overlaps,
		}
		if not bool(cleanliness.get("ok", false)):
			mode_failures.append_array(_array(cleanliness.get("errors", ["%s %s player view is not clean." % [archetype_id, mode]])))
		if not bool(rendered_identity.get("ok", false)):
			mode_failures.append_array(_array(rendered_identity.get("errors", ["%s %s capture rendered the wrong environment." % [archetype_id, mode]])))
		if not bool(geometry_validation.get("ok", false)):
			mode_failures.append_array(_array(geometry_validation.get("errors", ["%s %s capture geometry is invalid." % [archetype_id, mode]])))
		if not bool(generation_identity.get("ok", false)):
			mode_failures.append_array(_array(generation_identity.get("errors", ["%s %s capture provenance is invalid." % [archetype_id, mode]])))
		var image_validation: Dictionary = {
			"ok": false,
			"path": path,
			"expected_size": _rw06_1_size_snapshot(RW06_1_SOURCE_CAPTURE_SIZE),
			"errors": ["Source image was not written because pre-capture validation failed."],
		}
		if mode_failures.is_empty():
			var image := root.get_viewport().get_texture().get_image()
			var save_error := image.save_png(path)
			if save_error != OK:
				mode_failures.append("%s %s capture could not be written (%s)." % [archetype_id, mode, error_string(save_error)])
			else:
				image_validation = _rw06_1_validate_png(path, RW06_1_SOURCE_CAPTURE_SIZE)
				if not bool(image_validation.get("ok", false)):
					mode_failures.append_array(_array(image_validation.get("errors", [])))
		layouts[mode]["image_validation"] = image_validation
		layouts[mode]["sha256"] = FileAccess.get_sha256(path) if mode_failures.is_empty() and FileAccess.file_exists(path) else ""
		layouts[mode]["errors"] = mode_failures
		if not mode_failures.is_empty():
			var failed_mode_cleanup := _rw06_1_remove_file(path)
			if not bool(failed_mode_cleanup.get("ok", false)) or not bool(failed_mode_cleanup.get("absent", false)):
				mode_failures.append_array(_array(failed_mode_cleanup.get("errors", ["Failed contact source image was not removed."])))
			failures.append_array(mode_failures)
	canvas.call("set_small_screen_mode", false)
	var player_view_clean := true
	for mode in ["normal", "expanded"]:
		player_view_clean = player_view_clean and bool(_dict(_dict(layouts.get(mode, {})).get("player_view_cleanliness", {})).get("ok", false))
	if not failures.is_empty() or not player_view_clean:
		var pair_cleanup_paths: Array = []
		for mode in ["normal", "expanded"]:
			pair_cleanup_paths.append("%s/%s/%s.png" % [out_dir, mode, archetype_id])
		var pair_cleanup := _rw06_1_cleanup_paths(pair_cleanup_paths)
		if not bool(pair_cleanup.get("ok", false)) or not bool(pair_cleanup.get("all_absent", false)):
			failures.append_array(_array(pair_cleanup.get("errors", ["Failed contact image pair was not removed."])))
	return {
		"ok": failures.is_empty() and player_view_clean,
		"player_view_clean": player_view_clean,
		"selection": selection.duplicate(true),
		"generation_identity": _rw06_1_generation_identity(app.get("run_state"), selection),
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


func _rw06_1_manifest_capture_png_paths() -> Array:
	var paths: Array = []
	for path_value in rw06_1_manifest_files.values():
		var path := str(path_value)
		if path.ends_with(".png") and (path.contains("/normal/") or path.contains("/expanded/")):
			paths.append(path)
	paths.sort()
	return paths


func _rw06_1_cleanup_paths(paths: Array) -> Dictionary:
	var failures: Array = []
	var results: Array = []
	for path_value in paths:
		var removal := _rw06_1_remove_file(str(path_value))
		results.append(removal)
		if not bool(removal.get("ok", false)) or not bool(removal.get("absent", false)):
			failures.append_array(_array(removal.get("errors", ["rw06_1 cleanup did not verify absence for %s." % str(path_value)])))
	return {"ok": failures.is_empty(), "all_absent": failures.is_empty(), "results": results, "errors": failures}


func _rw06_1_remove_contact_source_images(_selections: Array) -> Dictionary:
	return _rw06_1_cleanup_paths(_rw06_1_manifest_capture_png_paths())


func _rw06_1_remove_file(path: String, owner_marker: bool = false) -> Dictionary:
	var failures: Array = []
	var absolute_path := _rw06_1_normalize_absolute_path(path)
	var manifest_key := absolute_path.to_lower()
	if rw06_1_capture_root_absolute.is_empty():
		failures.append("rw06_1 refused cleanup without a claimed fresh capture root.")
	elif not _rw06_1_path_is_inside(absolute_path, rw06_1_capture_root_absolute):
		failures.append("rw06_1 refused cleanup outside its owned root: %s." % absolute_path)
	elif not rw06_1_manifest_files.has(manifest_key):
		failures.append("rw06_1 refused cleanup outside its expected-file manifest: %s." % absolute_path)
	elif owner_marker and absolute_path.to_lower() != rw06_1_capture_owner_path.to_lower():
		failures.append("rw06_1 owner-marker cleanup targeted the wrong file: %s." % absolute_path)
	elif not owner_marker and absolute_path.to_lower() == rw06_1_capture_owner_path.to_lower():
		failures.append("rw06_1 owner marker requires the explicit release path.")
	elif not _rw06_1_capture_ownership_is_valid():
		failures.append("rw06_1 refused cleanup because capture ownership is not valid.")
	elif _rw06_1_path_has_link_boundary(absolute_path):
		failures.append("rw06_1 refused cleanup across a link/reparse boundary: %s." % absolute_path)
	if failures.is_empty() and (FileAccess.file_exists(absolute_path) or DirAccess.dir_exists_absolute(absolute_path)):
		var remove_error := DirAccess.remove_absolute(absolute_path)
		if remove_error != OK:
			failures.append("rw06_1 could not remove %s (%s)." % [absolute_path, error_string(remove_error)])
	if FileAccess.file_exists(absolute_path) or DirAccess.dir_exists_absolute(absolute_path):
		failures.append("rw06_1 could not verify cleanup absence: %s." % absolute_path)
	if not failures.is_empty():
		rw06_1_cleanup_failures.append_array(failures)
	return {"ok": failures.is_empty(), "path": absolute_path, "absent": failures.is_empty(), "errors": failures}


func _rw06_1_size_snapshot(size: Vector2i) -> Dictionary:
	return {"w": size.x, "h": size.y}


func _rw06_1_validate_png(path: String, expected_size: Vector2i) -> Dictionary:
	var failures: Array = []
	var decoded := false
	var nonblank := false
	var coverage: Dictionary = {"ok": false, "errors": ["PNG was not decoded."]}
	var actual_size := Vector2i.ZERO
	if not FileAccess.file_exists(path):
		failures.append("PNG evidence is missing: %s." % path)
	else:
		var image := Image.load_from_file(path)
		decoded = image != null and not image.is_empty()
		if not decoded:
			failures.append("PNG evidence could not be decoded: %s." % path)
		else:
			actual_size = Vector2i(image.get_width(), image.get_height())
			if actual_size != expected_size:
				failures.append("PNG evidence %s is %dx%d; expected %dx%d." % [path, actual_size.x, actual_size.y, expected_size.x, expected_size.y])
			coverage = _rw06_1_image_coverage(image)
			nonblank = bool(coverage.get("ok", false))
			if not nonblank:
				failures.append("PNG evidence lacks distributed opaque variation: %s." % path)
				failures.append_array(_array(coverage.get("errors", [])))
	return {
		"ok": failures.is_empty(),
		"path": path,
		"decoded": decoded,
		"nonblank": nonblank,
		"coverage": coverage,
		"expected_size": _rw06_1_size_snapshot(expected_size),
		"actual_size": _rw06_1_size_snapshot(actual_size),
		"sha256": FileAccess.get_sha256(path) if failures.is_empty() else "",
		"errors": failures,
}


func _rw06_1_image_coverage(source: Image) -> Dictionary:
	var failures: Array = []
	if source == null or source.is_empty():
		return {"ok": false, "errors": ["Image is null or empty."]}
	var image := source.duplicate() as Image
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var pixel_bytes := image.get_data()
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0 or pixel_bytes.size() < width * height * 4:
		return {"ok": false, "errors": ["Image pixel buffer is incomplete."]}
	var grid_columns := 4
	var grid_rows := 3
	var cell_opaque_counts: Array = []
	var cell_min_luma: Array = []
	var cell_max_luma: Array = []
	var cell_color_buckets: Array = []
	for _cell in range(grid_columns * grid_rows):
		cell_opaque_counts.append(0)
		cell_min_luma.append(256)
		cell_max_luma.append(-1)
		cell_color_buckets.append({})
	var global_color_buckets: Dictionary = {}
	var sample_count := 0
	var opaque_count := 0
	var min_luma := 256
	var max_luma := -1
	for y in range(0, height, RW06_1_IMAGE_SAMPLE_STRIDE):
		for x in range(0, width, RW06_1_IMAGE_SAMPLE_STRIDE):
			var offset := (y * width + x) * 4
			sample_count += 1
			var alpha := int(pixel_bytes[offset + 3])
			if alpha < RW06_1_OPAQUE_ALPHA_MIN:
				continue
			opaque_count += 1
			var red := int(pixel_bytes[offset])
			var green := int(pixel_bytes[offset + 1])
			var blue := int(pixel_bytes[offset + 2])
			var luma := int(round(0.2126 * red + 0.7152 * green + 0.0722 * blue))
			var color_bucket := (red >> 4) << 8 | (green >> 4) << 4 | (blue >> 4)
			global_color_buckets[color_bucket] = true
			min_luma = mini(min_luma, luma)
			max_luma = maxi(max_luma, luma)
			var grid_x := mini(grid_columns - 1, int(float(x) * grid_columns / float(width)))
			var grid_y := mini(grid_rows - 1, int(float(y) * grid_rows / float(height)))
			var cell_index := grid_y * grid_columns + grid_x
			cell_opaque_counts[cell_index] = int(cell_opaque_counts[cell_index]) + 1
			cell_min_luma[cell_index] = mini(int(cell_min_luma[cell_index]), luma)
			cell_max_luma[cell_index] = maxi(int(cell_max_luma[cell_index]), luma)
			var cell_buckets := _dict(cell_color_buckets[cell_index])
			cell_buckets[color_bucket] = true
			cell_color_buckets[cell_index] = cell_buckets
	var opaque_ratio := float(opaque_count) / float(maxi(1, sample_count))
	var occupied_grid_cells := 0
	var variant_grid_cells := 0
	for cell_index in range(cell_opaque_counts.size()):
		if int(cell_opaque_counts[cell_index]) <= 0:
			continue
		occupied_grid_cells += 1
		if _dict(cell_color_buckets[cell_index]).size() >= 2 \
				and int(cell_max_luma[cell_index]) - int(cell_min_luma[cell_index]) >= 8:
			variant_grid_cells += 1
	var luma_span := maxi(0, max_luma - min_luma) if opaque_count > 0 else 0
	if opaque_ratio < RW06_1_MIN_OPAQUE_SAMPLE_RATIO:
		failures.append("Opaque sample ratio %.4f is below %.4f." % [opaque_ratio, RW06_1_MIN_OPAQUE_SAMPLE_RATIO])
	if occupied_grid_cells < RW06_1_MIN_OCCUPIED_GRID_CELLS:
		failures.append("Opaque pixels occupy only %d grid cells; require %d." % [occupied_grid_cells, RW06_1_MIN_OCCUPIED_GRID_CELLS])
	if variant_grid_cells < RW06_1_MIN_VARIANT_GRID_CELLS:
		failures.append("Meaningful variation occupies only %d grid cells; require %d." % [variant_grid_cells, RW06_1_MIN_VARIANT_GRID_CELLS])
	if global_color_buckets.size() < RW06_1_MIN_COLOR_BUCKETS:
		failures.append("Image has only %d quantized color buckets; require %d." % [global_color_buckets.size(), RW06_1_MIN_COLOR_BUCKETS])
	if luma_span < RW06_1_MIN_LUMA_SPAN:
		failures.append("Image luminance span is only %d; require %d." % [luma_span, RW06_1_MIN_LUMA_SPAN])
	return {
		"ok": failures.is_empty(),
		"sample_stride": RW06_1_IMAGE_SAMPLE_STRIDE,
		"sample_count": sample_count,
		"opaque_sample_count": opaque_count,
		"opaque_sample_ratio": opaque_ratio,
		"occupied_grid_cells": occupied_grid_cells,
		"variant_grid_cells": variant_grid_cells,
		"color_bucket_count": global_color_buckets.size(),
		"luma_span": luma_span,
		"errors": failures,
	}


func _rw06_1_image_is_nonblank(source: Image) -> bool:
	return bool(_rw06_1_image_coverage(source).get("ok", false))


func _rw06_1_build_sheet(rows: Array, path: String, rooms_per_row: int) -> Dictionary:
	var initial_cleanup := _rw06_1_remove_file(path)
	var failures: Array = _array(initial_cleanup.get("errors", [])).duplicate()
	if rows.is_empty():
		failures.append("Contact sheet %s has no rows." % path)
		return {"ok": false, "path": path, "expected_size": _rw06_1_size_snapshot(Vector2i.ZERO), "errors": failures, "cells": []}
	var cell_size := Vector2i(320, 180)
	var pair_size := Vector2i(cell_size.x * 2, cell_size.y)
	var row_count := ceili(float(rows.size()) / float(maxi(1, rooms_per_row)))
	var expected_size := Vector2i(pair_size.x * rooms_per_row, cell_size.y * row_count)
	var sheet := Image.create(expected_size.x, expected_size.y, false, Image.FORMAT_RGBA8)
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
			var source_validation := _rw06_1_validate_png(source_path, RW06_1_SOURCE_CAPTURE_SIZE)
			if not bool(source_validation.get("ok", false)):
				failures.append_array(_array(source_validation.get("errors", [])))
				continue
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
	if not failures.is_empty():
		var failed_source_cleanup := _rw06_1_remove_file(path)
		if not bool(failed_source_cleanup.get("ok", false)) or not bool(failed_source_cleanup.get("absent", false)):
			failures.append_array(_array(failed_source_cleanup.get("errors", ["Incomplete contact sheet was not removed."])))
		return {"ok": false, "path": path, "expected_size": _rw06_1_size_snapshot(expected_size), "cells": cells, "errors": failures}
	var save_error := sheet.save_png(path)
	if save_error != OK:
		failures.append("Contact sheet could not be written to %s (%s)." % [path, error_string(save_error)])
	var image_validation := _rw06_1_validate_png(path, expected_size) if save_error == OK else {
		"ok": false,
		"path": path,
		"expected_size": _rw06_1_size_snapshot(expected_size),
		"errors": ["Contact sheet save failed before validation."],
	}
	if not bool(image_validation.get("ok", false)):
		failures.append_array(_array(image_validation.get("errors", [])))
	if not failures.is_empty():
		var failed_sheet_cleanup := _rw06_1_remove_file(path)
		if not bool(failed_sheet_cleanup.get("ok", false)) or not bool(failed_sheet_cleanup.get("absent", false)):
			failures.append_array(_array(failed_sheet_cleanup.get("errors", ["Invalid contact sheet was not removed."])))
	return {
		"ok": failures.is_empty(),
		"path": path,
		"sha256": FileAccess.get_sha256(path) if failures.is_empty() else "",
		"size": _rw06_1_size_snapshot(expected_size),
		"expected_size": _rw06_1_size_snapshot(expected_size),
		"image_validation": image_validation,
		"cells": cells,
		"errors": failures,
	}


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


func _write_fix06_31_json(path: String, payload: Dictionary) -> Dictionary:
	var failures: Array = []
	var encoded := JSON.stringify(payload, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "path": path, "sha256": "", "errors": ["JSON output could not be opened (%s): %s." % [error_string(FileAccess.get_open_error()), path]]}
	file.store_string(encoded)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		failures.append("JSON output write failed (%s): %s." % [error_string(write_error), path])
	var stored_text := ""
	if not FileAccess.file_exists(path):
		failures.append("JSON output is absent after write: %s." % path)
	else:
		var reader := FileAccess.open(path, FileAccess.READ)
		if reader == null:
			failures.append("JSON output cannot be reopened (%s): %s." % [error_string(FileAccess.get_open_error()), path])
		else:
			stored_text = reader.get_as_text()
			var read_error := reader.get_error()
			reader.close()
			if read_error != OK:
				failures.append("JSON output verification read failed (%s): %s." % [error_string(read_error), path])
	if stored_text != encoded:
		failures.append("JSON output bytes do not match the encoded payload: %s." % path)
	var parser := JSON.new()
	if not stored_text.is_empty() and parser.parse(stored_text) != OK:
		failures.append("JSON output cannot be parsed after write: %s." % path)
	elif not stored_text.is_empty() and typeof(parser.data) != TYPE_DICTIONARY:
		failures.append("JSON output root is not an object after write: %s." % path)
	var sha256 := FileAccess.get_sha256(path) if failures.is_empty() else ""
	if failures.is_empty() and sha256.is_empty():
		failures.append("JSON output has no verifiable SHA-256: %s." % path)
	return {"ok": failures.is_empty(), "path": path, "sha256": sha256, "errors": failures}


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
