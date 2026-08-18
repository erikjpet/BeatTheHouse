extends SceneTree

# Layout survey tool: boots the real app, forces each environment archetype,
# saves a screenshot plus the resolved interactable-object layout per archetype.
# Run windowed (not --headless): the capture reads the viewport texture.
#   .tools/godot-4.6-stable/<godot.exe> --path . --script res://tools/environment_layout_screenshots.gd -- --out=C:/absolute/output/dir

const MainScene := preload("res://scenes/main.tscn")
const CollectionItemResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const SEED_TEXT := "LAYOUT-SURVEY-QA"

var app: Control
var out_dir := "user://layout_survey"
var report := {}
var meta_home_review := false
var punchline_layer_review := false


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		elif argument == "--meta-home-review":
			meta_home_review = true
		elif argument == "--punchline-layers-only":
			punchline_layer_review = true
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
	if punchline_layer_review:
		if not _verify_punchline_runtime_backgrounds():
			quit(1)
			return
		if not _write_punchline_glance_capture():
			quit(1)
			return
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
		"runtime_background": _canvas_runtime_background(),
	}


func _capture_archetype(archetype: Dictionary, archetype_id: String, run_state: Variant, library: Variant) -> void:
	var rng: Variant = run_state.create_rng()
	var selected_scenario: Dictionary = {}
	if punchline_layer_review and archetype_id == "small_underground_casino":
		selected_scenario = library.scenario("punchline_open_mic_night")
	var environment: Variant = EnvironmentInstance.from_archetype(archetype, 1, rng, library, run_state.challenge_config, selected_scenario)
	var data: Dictionary = environment.to_dict()
	data["world_node_id"] = archetype_id
	if str(archetype.get("kind", "")) == "home":
		var profile: Dictionary = archetype.get("home_profile", {}) if typeof(archetype.get("home_profile", {})) == TYPE_DICTIONARY else {}
		run_state.initialize_home_from_profile(archetype, archetype_id, profile)
		data["home_profile"] = profile.duplicate(true)
		data["home_containers"] = _survey_home_containers(profile)
		data["home_container_index"] = int((data["home_containers"] as Array).size())
		data["home_lost"] = false
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data)
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
		"canvas_object_layout": _canvas_object_layout(),
		"runtime_background": _canvas_runtime_background(),
	}
	if punchline_layer_review:
		await _capture_punchline_club_scenario(archetype, archetype_id, "punchline_headliner_night", "club_headliner", run_state, library)
		for layer_id_value in data.get("layer_ids", []):
			var layer_id := str(layer_id_value)
			if layer_id != default_layer_id:
				await _capture_archetype_layer(archetype, archetype_id, layer_id, run_state, library)


func _capture_punchline_club_scenario(archetype: Dictionary, archetype_id: String, scenario_id: String, file_suffix: String, run_state: Variant, library: Variant) -> void:
	var rng: Variant = run_state.create_rng("layout_survey_scenario:%s" % scenario_id)
	var environment: Variant = EnvironmentInstance.from_archetype(
		archetype,
		1,
		rng,
		library,
		run_state.challenge_config,
		library.scenario(scenario_id)
	)
	var data: Dictionary = environment.to_dict()
	data["world_node_id"] = archetype_id
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data)
	run_state.set_environment(data)
	app.call("_clear_selected_game_action")
	app.call("_refresh")
	await _settle(4)
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var file_id := "%s_%s" % [archetype_id, file_suffix]
	image.save_png("%s/%s.png" % [out_dir, file_id])
	report[file_id] = {
		"name": str(data.get("display_name", archetype_id)),
		"layer_id": str(data.get("current_layer_id", "")),
		"scenario_id": scenario_id,
		"scenario_presentation": data.get("scenario_presentation", {}),
		"canvas_object_layout": _canvas_object_layout(),
		"runtime_background": _canvas_runtime_background(),
	}


func _capture_archetype_layer(archetype: Dictionary, archetype_id: String, layer_id: String, run_state: Variant, library: Variant) -> void:
	var rng: Variant = run_state.create_rng("layout_survey_layer:%s:%s" % [archetype_id, layer_id])
	var environment: Variant = EnvironmentInstance.from_archetype_layer(archetype, layer_id, 1, rng, library, run_state.challenge_config)
	var data: Dictionary = environment.to_dict()
	data["world_node_id"] = archetype_id
	data["layer_discovery"] = {"club": true, "casino": true, "back_room": true}
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data)
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
	}


func _canvas_object_layout() -> Dictionary:
	var canvas: Variant = app.get("environment_canvas")
	if canvas == null:
		return {}
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	return snapshot.get("object_layout", {})


func _canvas_runtime_background() -> Dictionary:
	var canvas: Variant = app.get("environment_canvas")
	if canvas == null:
		return {}
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	return {
		"requested": bool(snapshot.get("scene_asset_background_requested", false)),
		"loaded": bool(snapshot.get("scene_asset_background_loaded", false)),
		"path": str(snapshot.get("scene_asset_background_path", "")),
		"scenario_palette_active": bool(snapshot.get("scenario_palette_active", false)),
		"scenario_crowd_count": int(snapshot.get("scenario_crowd_count", 0)),
		"scenario_signage": str(snapshot.get("scenario_signage", "")),
	}


func _verify_punchline_runtime_backgrounds() -> bool:
	var expected := {
		"small_underground_casino_club": {"requested": true, "path": "res://assets/art/environments/punchline_club.png"},
		"small_underground_casino_club_headliner": {"requested": true, "path": "res://assets/art/environments/punchline_club.png"},
		"small_underground_casino_casino": {"requested": false, "path": ""},
		"small_underground_casino_back_room": {"requested": true, "path": "res://assets/art/environments/punchline_back_room.png"},
	}
	for capture_id in expected.keys():
		var capture := report.get(capture_id, {}) as Dictionary
		var background := capture.get("runtime_background", {}) as Dictionary
		var wanted := expected.get(capture_id, {}) as Dictionary
		var requested := bool(wanted.get("requested", false))
		if bool(background.get("requested", false)) != requested \
			or bool(background.get("loaded", false)) != requested \
			or str(background.get("path", "")) != str(wanted.get("path", "")):
			push_error("Punchline layer runtime background mismatch for %s: %s" % [capture_id, JSON.stringify(background)])
			return false
	var open_mic := report.get("small_underground_casino_club", {}) as Dictionary
	var open_mic_background := open_mic.get("runtime_background", {}) as Dictionary
	var headliner := report.get("small_underground_casino_club_headliner", {}) as Dictionary
	var headliner_background := headliner.get("runtime_background", {}) as Dictionary
	if str(open_mic_background.get("scenario_signage", "")) != "FIVE MINUTES. NO PROMISES." \
		or int(open_mic_background.get("scenario_crowd_count", 0)) != 2 \
		or str(headliner_background.get("scenario_signage", "")) != "SOLD OUT. KEEP MOVING." \
		or int(headliner_background.get("scenario_crowd_count", 0)) != 10:
		push_error("Punchline L1 scenario overlays did not survive the runtime raster path.")
		return false
	return true


func _write_punchline_glance_capture() -> bool:
	var layer_ids := ["club", "casino", "back_room"]
	var tile_size := Vector2i(640, 360)
	var composite := Image.create(tile_size.x * layer_ids.size(), tile_size.y, false, Image.FORMAT_RGBA8)
	for index in range(layer_ids.size()):
		var path := "%s/small_underground_casino_%s.png" % [out_dir, layer_ids[index]]
		var layer_image := Image.load_from_file(path)
		if layer_image == null or layer_image.is_empty():
			push_error("Punchline glance capture could not load %s." % path)
			return false
		layer_image.resize(tile_size.x, tile_size.y, Image.INTERPOLATE_NEAREST)
		composite.blit_rect(layer_image, Rect2i(Vector2i.ZERO, tile_size), Vector2i(index * tile_size.x, 0))
	var error := composite.save_png("%s/punchline_layers_glance.png" % out_dir)
	if error != OK:
		push_error("Punchline glance capture could not be written (error %d)." % error)
		return false
	return true


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
