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


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
		elif argument == "--meta-home-review":
			meta_home_review = true
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
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data)
	run_state.save_rng(rng)
	run_state.set_environment(data)
	app.call("_clear_selected_game_action")
	app.call("_refresh")
	await _settle(4)
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [out_dir, archetype_id])
	report[archetype_id] = {
		"name": str(data.get("name", archetype_id)),
		"scene_type": str((data.get("visual_context", {}) as Dictionary).get("scene_type", "")),
		"game_ids": data.get("game_ids", []),
		"event_ids": data.get("event_ids", []),
		"service_ids": data.get("service_ids", []),
		"lender_hooks": data.get("lender_hooks", []),
		"authored_layout": archetype.get("layout", {}),
		"canvas_object_layout": _canvas_object_layout(),
	}


func _canvas_object_layout() -> Dictionary:
	var canvas: Variant = app.get("environment_canvas")
	if canvas == null:
		return {}
	var snapshot: Dictionary = canvas.call("current_view_snapshot")
	return snapshot.get("object_layout", {})


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
