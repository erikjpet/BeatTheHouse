extends SceneTree

# Focused player-facing proof for the Quarter Falls one-platform copy fix.
# This does not update or compare any unrelated golden image. It captures the
# production room inspection and untouched initial game surface in each
# supported presentation mode, while recording the exact text-path evidence.

const MainScene := preload("res://scenes/main.tscn")
const FoundationActionViewModelScript := preload("res://scripts/ui/foundation_action_view_model.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const OUTPUT_DIR := "res://.tmp/coin_pusher_copy_visual_probe"
const FIXTURE_SEED := "QUARTER-FALLS-COPY-PROOF"
const FIXTURE_ID := "coin_pusher_copy_visual_probe"
const EXPECTED_DESCRIPTION := "Aim. Read the pile. Walk the alarm line."
const EXPECTED_INTRO := "One platform shoves a pile somebody else started."
const EXPECTED_VARIATION_INTRO := "Quarter Falls moves one platform under a pile that remembers every coin."
const FORBIDDEN_COPY := ["shelves", "two shelf"]
const CONFIGURATIONS := [
	{"id": "desktop_normal", "size": Vector2i(1280, 720), "small_screen": false, "reduce_motion": false},
	{"id": "desktop_reduced_motion", "size": Vector2i(1280, 720), "small_screen": false, "reduce_motion": true},
	{"id": "small_screen_normal", "size": Vector2i(640, 360), "small_screen": true, "reduce_motion": false},
	{"id": "small_screen_reduced_motion", "size": Vector2i(640, 360), "small_screen": true, "reduce_motion": true},
]

class CopyFallbackHost:
	extends RefCounted
	var current_game: GameModule

var out_dir := OUTPUT_DIR
var golden_full_out := ""
var captures: Array[Dictionary] = []
var failed := false


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=").strip_edges()
		elif argument.begins_with("--golden-full-out="):
			golden_full_out = argument.trim_prefix("--golden-full-out=").strip_edges()
	call_deferred("_run")


func _run() -> void:
	if not golden_full_out.is_empty():
		await _write_full_golden_capture()
		quit(1 if failed else 0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	for configuration_value in CONFIGURATIONS:
		await _capture_configuration(configuration_value as Dictionary)
	_write_manifest()
	print("COIN_PUSHER_COPY_VISUAL_PROBE_%s captures=%d out=%s" % ["FAIL" if failed else "PASS", captures.size(), ProjectSettings.globalize_path(out_dir)])
	quit(1 if failed else 0)


func _capture_configuration(configuration: Dictionary) -> void:
	var configuration_id := str(configuration.get("id", ""))
	var capture_size: Vector2i = configuration.get("size", Vector2i(1280, 720))
	_isolate_profile("visual_%s" % configuration_id)
	root.size = capture_size
	root.content_scale_size = capture_size
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(capture_size)
	var app := MainScene.instantiate() as Control
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "coin_pusher_copy_probe_%s" % configuration_id)
	root.add_child(app)
	await _settle(6)
	app.call("start_foundation_run", FIXTURE_SEED)
	await _settle(8)
	var logical_viewport_size := app.get_viewport_rect().size
	_require(logical_viewport_size.is_equal_approx(Vector2(capture_size)), "%s logical viewport is %s instead of %s." % [configuration_id, str(logical_viewport_size), str(capture_size)])
	if not _install_fixture_environment(app, configuration_id):
		app.queue_free()
		await process_frame
		return
	var settings: Variant = app.get("user_settings")
	if settings == null:
		_fail("%s could not access user settings." % configuration_id)
	else:
		settings.play_on_small_screen = bool(configuration.get("small_screen", false))
		settings.reduce_motion = bool(configuration.get("reduce_motion", false))
		settings.coach_tips_enabled = false
		app.call("_on_settings_applied")
	await _settle(8)

	var library := app.get("library") as ContentLibrary
	var definition := library.game("coin_pusher") if library != null else {}
	var authored_intro := str(definition.get("intro", ""))
	var authored_description := str(definition.get("description", ""))
	var generic_module := GameModule.new()
	generic_module.setup(definition, library)
	var run_state := app.get("run_state") as RunState
	var generic_enter_message := str(generic_module.enter(run_state, run_state.current_environment).get("message", ""))
	var fallback_definition := definition.duplicate(true)
	fallback_definition.erase("description")
	var fallback_module := GameModule.new()
	fallback_module.setup(fallback_definition, library)
	var fallback_host := CopyFallbackHost.new()
	fallback_host.current_game = fallback_module
	var authored_fallback_description := FoundationActionViewModelScript.current_game_description(fallback_host)
	_require(authored_intro == EXPECTED_INTRO, "%s generic authored intro is stale: %s" % [configuration_id, authored_intro])
	_require(generic_enter_message == EXPECTED_INTRO, "%s generic enter path did not publish the authored intro: %s" % [configuration_id, generic_enter_message])
	_require(authored_fallback_description == EXPECTED_INTRO, "%s current-game fallback did not publish the authored intro: %s" % [configuration_id, authored_fallback_description])
	_require(authored_description == EXPECTED_DESCRIPTION, "%s authored inspection description is stale: %s" % [configuration_id, authored_description])

	var focused := bool(app.call("focus_interactable_object", "game:coin_pusher"))
	await _settle(5)
	var room_canvas := app.get("environment_canvas") as Control
	var room_snapshot: Dictionary = room_canvas.call("current_view_snapshot") if room_canvas != null and room_canvas.has_method("current_view_snapshot") else {}
	var selected_info: Dictionary = room_snapshot.get("selected_info", {}) if typeof(room_snapshot.get("selected_info", {})) == TYPE_DICTIONARY else {}
	var selected_lines := _string_array(selected_info.get("lines", []))
	var selected_copy := " ".join(selected_lines)
	var summary_label := app.get("summary_label") as Label
	var room_summary := summary_label.text if summary_label != null else ""
	var room_composition_rect: Rect2 = room_canvas.call("global_rect_for_selected_composition") if room_canvas != null and room_canvas.has_method("global_rect_for_selected_composition") else Rect2()
	var room_card_fits := room_composition_rect.has_area() and Rect2(Vector2.ZERO, Vector2(capture_size)).encloses(room_composition_rect)
	var room_copy_valid := focused \
		and str(selected_info.get("object_id", "")) == "game:coin_pusher" \
		and selected_copy.contains(EXPECTED_DESCRIPTION) \
		and room_summary.contains(EXPECTED_DESCRIPTION) \
		and room_card_fits
	_require(room_copy_valid, "%s room inspection/current-game description was missing or clipped: selected=%s summary=%s" % [configuration_id, selected_copy, room_summary])
	_require(not _contains_forbidden_copy([definition, generic_enter_message, authored_fallback_description, selected_info, room_summary]), "%s room/generic copy retained stale plural-shelf wording." % configuration_id)
	var room_file := "%s_room_inspection.png" % configuration_id
	var room_saved := await _save_viewport(room_file, capture_size)
	captures.append({
		"id": "%s_room_inspection" % configuration_id,
		"file": room_file,
		"saved": room_saved,
		"viewport": _size_record(capture_size),
		"logical_viewport": _vector_record(logical_viewport_size),
		"small_screen": bool(configuration.get("small_screen", false)),
		"reduce_motion": bool(configuration.get("reduce_motion", false)),
		"authored_description": authored_description,
		"room_summary": room_summary,
		"selected_info_lines": selected_lines,
		"selected_info_visual_rect": selected_info.get("visual_rect", {}),
		"room_canvas_size": _vector_record(room_canvas.size if room_canvas != null else Vector2.ZERO),
		"room_composition_rect": _rect_record(room_composition_rect),
		"room_card_fits": room_card_fits,
		"copy_valid": room_copy_valid,
	})

	var entered := bool(app.call("enter_game", "coin_pusher"))
	await _settle(8)
	var surface_canvas := app.get("game_surface_canvas") as Control
	var surface_state: Dictionary = surface_canvas.call("realtime_surface_state") if surface_canvas != null and surface_canvas.has_method("realtime_surface_state") else {}
	var variation_intro := str(surface_state.get("coin_pusher_last_message", ""))
	var game_summary := summary_label.text if summary_label != null else ""
	var surface_runtime: Dictionary = surface_canvas.call("surface_runtime_status") if surface_canvas != null and surface_canvas.has_method("surface_runtime_status") else {}
	var surface_fits := _control_fits_viewport(surface_canvas, capture_size)
	var coach_overlay := app.get("coach_overlay") as Control
	var coach_overlay_hidden := coach_overlay == null or not coach_overlay.visible
	var game_copy_valid := entered \
		and str(surface_state.get("surface_renderer", "")) == "coin_pusher" \
		and variation_intro == EXPECTED_VARIATION_INTRO \
		and game_summary == EXPECTED_DESCRIPTION \
		and bool(surface_runtime.get("reduce_motion", false)) == bool(configuration.get("reduce_motion", false)) \
		and surface_fits \
		and coach_overlay_hidden
	_require(game_copy_valid, "%s initial Quarter Falls copy was missing or clipped: intro=%s summary=%s" % [configuration_id, variation_intro, game_summary])
	_require(not _contains_forbidden_copy([surface_state, game_summary]), "%s initial Quarter Falls surface retained stale plural-shelf wording." % configuration_id)
	var game_file := "%s_initial_quarter_falls.png" % configuration_id
	var game_saved := await _save_viewport(game_file, capture_size)
	captures.append({
		"id": "%s_initial_quarter_falls" % configuration_id,
		"file": game_file,
		"saved": game_saved,
		"viewport": _size_record(capture_size),
		"logical_viewport": _vector_record(logical_viewport_size),
		"small_screen": bool(configuration.get("small_screen", false)),
		"reduce_motion": bool(configuration.get("reduce_motion", false)),
		"authored_intro": authored_intro,
		"generic_enter_message": generic_enter_message,
		"authored_fallback_description": authored_fallback_description,
		"variation_intro_before_action": variation_intro,
		"current_game_description": game_summary,
		"surface_rect": _rect_record(surface_canvas.get_global_rect() if surface_canvas != null else Rect2()),
		"surface_fits": surface_fits,
		"coach_overlay_hidden": coach_overlay_hidden,
		"copy_valid": game_copy_valid,
	})

	app.queue_free()
	await process_frame


func _install_fixture_environment(app: Control, configuration_id: String) -> bool:
	var run_state := app.get("run_state") as RunState
	var library := app.get("library") as ContentLibrary
	if run_state == null or library == null:
		_fail("%s could not access the run state or content library." % configuration_id)
		return false
	var archetype := library.environment_archetype("bar")
	if archetype.is_empty():
		_fail("%s could not load the Bar archetype." % configuration_id)
		return false
	var environment := EnvironmentInstance.from_archetype(archetype, 0, run_state.create_rng("copy_probe:%s:environment" % configuration_id), library).to_dict()
	environment["id"] = FIXTURE_ID
	environment["archetype_id"] = "bar"
	environment["world_node_id"] = "bar"
	environment["game_ids"] = ["coin_pusher"]
	environment["event_ids"] = []
	environment["resolved_event_ids"] = []
	environment["item_offers"] = []
	environment["service_ids"] = []
	environment["lender_hooks"] = []
	environment["object_fixtures"] = []
	environment["scenario_game_modifiers"] = {"coin_pusher": {"variation_id": "quarter_falls"}}
	var definition := library.game("coin_pusher")
	var module: Variant = app.call("_create_game_module", definition)
	if module == null or not module is GameModule:
		_fail("%s could not create the production Coin Pusher module." % configuration_id)
		return false
	var state := (module as GameModule).generate_environment_state(run_state, environment, run_state.create_rng("copy_probe:%s:state" % configuration_id))
	environment["game_states"] = {"coin_pusher": state.duplicate(true)}
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)
	run_state.set_environment(environment)
	run_state.bankroll = 500
	run_state.drunk_level = 0
	run_state.pending_drunk_absorption = []
	app.call("back_to_environment")
	app.call("_refresh")
	return not state.is_empty()


func _save_viewport(file_name: String, expected_size: Vector2i) -> bool:
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	if image == null:
		_fail("Viewport capture is unavailable for %s; run the helper windowed." % file_name)
		return false
	if image.get_size() != expected_size:
		image.resize(expected_size.x, expected_size.y, Image.INTERPOLATE_NEAREST)
	var error := image.save_png("%s/%s" % [out_dir, file_name])
	if error != OK:
		_fail("Could not save %s (error %d)." % [file_name, error])
		return false
	return true


func _write_manifest() -> void:
	var required_capture_count := CONFIGURATIONS.size() * 2
	var all_saved := captures.size() == required_capture_count
	var all_copy_valid := captures.size() == required_capture_count
	for capture in captures:
		all_saved = all_saved and bool(capture.get("saved", false))
		all_copy_valid = all_copy_valid and bool(capture.get("copy_valid", false))
	var passed := not failed and all_saved and all_copy_valid
	if not passed:
		_fail("Quarter Falls copy proof did not satisfy all %d required captures." % required_capture_count)
	var manifest := {
		"tool": "coin_pusher_copy_visual_probe",
		"fixture_seed": FIXTURE_SEED,
		"fixture_id": FIXTURE_ID,
		"smallest_supported_fixture": {"width": 640, "height": 360, "play_on_small_screen": true},
		"expected": {
			"description": EXPECTED_DESCRIPTION,
			"authored_intro": EXPECTED_INTRO,
			"quarter_falls_variation_intro": EXPECTED_VARIATION_INTRO,
			"forbidden_copy": FORBIDDEN_COPY,
		},
		"required_capture_count": required_capture_count,
		"saved_capture_count": captures.filter(func(capture): return bool((capture as Dictionary).get("saved", false))).size(),
		"passed": passed,
		"captures": captures,
	}
	var file := FileAccess.open("%s/manifest.json" % out_dir, FileAccess.WRITE)
	if file == null:
		_fail("Could not write the Quarter Falls copy-proof manifest.")
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()


func _control_fits_viewport(control: Control, viewport_size: Vector2i) -> bool:
	if control == null or not control.visible:
		return false
	return Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(control.get_global_rect())


func _write_full_golden_capture() -> void:
	# Diagnostic-only full values let the PM recursively compare the accepted
	# parent and copy-only head before refreshing any aggregate hash.
	_isolate_profile("golden_full")
	var app := MainScene.instantiate() as Control
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", "coin_pusher_copy_golden_leaf_probe")
	root.add_child(app)
	await _settle(6)
	var library := app.get("library") as ContentLibrary
	if library == null:
		_fail("Full golden leaf capture could not access ContentLibrary.")
		return
	var runs: Array = []
	for seed_value in ["CREW-IGNORED-GOLDEN-A", "CREW-IGNORED-GOLDEN-B"]:
		var run_state := RunState.new()
		run_state.start_new(str(seed_value))
		_set_golden_world(run_state)
		var generator := RunGeneratorScript.new(library)
		generator.next_environment(run_state, "bar", true)
		var checkpoints: Array = [_full_golden_checkpoint("initial_bar", run_state)]
		run_state.advance_environment_turns(1)
		checkpoints.append(_full_golden_checkpoint("bar_action_boundary", run_state))
		generator.next_environment(run_state, "gas_station_casino", true)
		checkpoints.append(_full_golden_checkpoint("ordinary_travel", run_state))
		generator.next_environment(run_state, "bar", true)
		checkpoints.append(_full_golden_checkpoint("bar_revisit", run_state))
		var restored := RunState.new()
		restored.from_dict(run_state.to_dict())
		checkpoints.append(_full_golden_checkpoint("save_load_round_trip", restored))
		runs.append({"seed": str(seed_value), "checkpoints": checkpoints})
	var absolute_path := ProjectSettings.globalize_path(golden_full_out)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write full golden leaf capture: %s" % absolute_path)
		return
	file.store_string(JSON.stringify({"schema_version": 1, "runs": runs}, "\t") + "\n")
	file.close()
	print("COIN_PUSHER_COPY_GOLDEN_FULL_CAPTURE_PASS out=%s" % absolute_path)


func _full_golden_checkpoint(label: String, run_state: RunState) -> Dictionary:
	return {
		"label": label,
		"run_state": run_state.to_dict(),
		"current_environment": run_state.current_environment.duplicate(true),
		"world_environments": _golden_world_environments(run_state.world_map),
	}


func _golden_world_environments(world_map: Dictionary) -> Array:
	var result: Array = []
	for node_value in world_map.get("nodes", []):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node := node_value as Dictionary
		result.append({
			"id": str(node.get("id", "")),
			"environment": (node.get("environment", {}) as Dictionary).duplicate(true) if typeof(node.get("environment", {})) == TYPE_DICTIONARY else {},
		})
	return result


func _set_golden_world(run_state: RunState) -> void:
	run_state.set_world_map({
		"version": 3,
		"seed_text": run_state.seed_text,
		"start_node_id": "bar",
		"current_node_id": "bar",
		"nodes": [
			{"id": "bar", "archetype_id": "bar", "display_name": "Bar", "kind": "casino", "tier": 1, "state": "revealed", "seen": true, "environment": {}},
			{"id": "gas_station_casino", "archetype_id": "gas_station_casino", "display_name": "Gas Station Casino", "kind": "casino", "tier": 1, "state": "revealed", "seen": true, "environment": {}},
			{"id": "motel", "archetype_id": "motel", "display_name": "Motel", "kind": "shop", "tier": 1, "state": "revealed", "seen": true, "environment": {}},
		],
		"edges": [{"from": "bar", "to": "gas_station_casino"}, {"from": "gas_station_casino", "to": "motel"}, {"from": "motel", "to": "bar"}],
		"visited_path": ["bar"],
	})


func _isolate_profile(profile_id: String) -> void:
	var profile_root := "%s/profile_%s" % [out_dir, profile_id]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profile_root))
	OS.set_environment("BTH_DISTRIBUTION_BUILD", "1")
	OS.set_environment("BTH_DISTRIBUTION_DATA_ROOT", "%s/distribution" % profile_root)
	OS.set_environment("BTH_USER_SETTINGS_PATH", "%s/settings.json" % profile_root)
	OS.set_environment("BTH_PROFILE_INVENTORY_PATH", "%s/profile_inventory.json" % profile_root)
	OS.set_environment("BTH_META_COLLECTION_PATH", "%s/meta_collection.json" % profile_root)


func _contains_forbidden_copy(values: Array) -> bool:
	for value in values:
		var lowered := (JSON.stringify(value) if typeof(value) in [TYPE_ARRAY, TYPE_DICTIONARY] else str(value)).to_lower()
		for forbidden in FORBIDDEN_COPY:
			if lowered.contains(str(forbidden)):
				return true
	return false


func _string_array(value: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	if typeof(value) == TYPE_ARRAY:
		for entry in value:
			result.append(str(entry))
	return result


func _size_record(value: Vector2i) -> Dictionary:
	return {"width": value.x, "height": value.y}


func _vector_record(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _rect_record(value: Rect2) -> Dictionary:
	return {"x": value.position.x, "y": value.position.y, "w": value.size.x, "h": value.size.y}


func _settle(frame_count: int) -> void:
	for _index in range(frame_count):
		await process_frame


func _require(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error(message)
