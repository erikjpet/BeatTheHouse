extends SceneTree

# Promo capture tool for the v0.4 social card: boots the real app, drives the
# release showcase states, and saves full-viewport screenshots.
# Run windowed (not --headless): the capture reads the viewport texture.
#   <godot.exe> --path . --script res://tools/promo_screenshots_0_4.gd -- --out=C:/absolute/output/dir

const MainScene := preload("res://scenes/main.tscn")
const CollectionItemResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const SEED_TEXT := "PROMO-V04-CARD"

var app: Control
var out_dir := "user://promo_captures"


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	app = MainScene.instantiate()
	root.add_child(app)
	await _settle(6)
	await _capture_house()
	await _capture_pawn_shop()
	await _capture_run_states()
	await _capture_beach()
	print("PROMO_CAPTURE_DONE -> %s" % out_dir)
	quit(0)


func _capture_pawn_shop() -> void:
	app.call("_enter_meta_location", "pawn_shop")
	await _settle(10)
	await _save_shot("promo_pawn_shop")


func _capture_beach() -> void:
	var library: Variant = app.get("library")
	var run_state: Variant = app.get("run_state")
	if library == null or run_state == null:
		push_error("Promo capture: beach needs an active run.")
		return
	var archetype: Dictionary = library.environment_archetype("beach") if library.has_method("environment_archetype") else {}
	if archetype.is_empty():
		for archetype_value in library.environment_archetypes:
			if typeof(archetype_value) == TYPE_DICTIONARY and str((archetype_value as Dictionary).get("id", "")) == "beach":
				archetype = archetype_value
				break
	if archetype.is_empty():
		push_error("Promo capture: beach archetype not found.")
		return
	var rng: Variant = run_state.create_rng()
	var environment: Variant = EnvironmentInstance.from_archetype(archetype, 1, rng, library, run_state.challenge_config)
	var data: Dictionary = environment.to_dict()
	data["world_node_id"] = "beach"
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data)
	run_state.save_rng(rng)
	run_state.set_environment(data)
	app.call("_clear_selected_game_action")
	if app.has_method("_clear_selected_travel"):
		app.call("_clear_selected_travel")
	if app.has_method("clear_interaction_focus"):
		app.call("clear_interaction_focus")
	app.call("_refresh")
	await _settle(8)
	await _save_shot("promo_beach")


func _capture_house() -> void:
	var store_path := "%s/promo_meta_store.json" % out_dir
	OS.set_environment("BTH_META_COLLECTION_PATH", store_path)
	if FileAccess.file_exists(store_path):
		DirAccess.remove_absolute(store_path)
	await _settle(2)
	app.call("open_meta_home")
	await _settle(8)
	var service: Variant = app.get("meta_collection_service")
	if service == null:
		push_error("Promo capture could not load MetaCollectionService.")
		return
	_seed_collection(service)
	service.call("add_gold", 4000)
	service.call("purchase_housing_upgrade")
	service.call("purchase_housing_upgrade")
	service.call("purchase_housing_upgrade")
	service.call("save")
	app.call("open_meta_home")
	await _settle(10)
	await _save_shot("promo_house")


func _capture_run_states() -> void:
	app.call("start_foundation_run", SEED_TEXT, {})
	await _settle(10)
	await _save_shot("promo_run_room")
	await _show_dialogue()
	await _save_shot("promo_dialogue")
	var talk_dock: Variant = app.get("talk_dock")
	if talk_dock != null:
		talk_dock.call("clear_entry")
	await _settle(2)
	await _open_world_map()
	await _save_shot("promo_map")
	if app.has_method("_hide_world_map_overlay"):
		app.call("_hide_world_map_overlay")
	await _settle(4)


func _show_dialogue() -> void:
	var talk_dock: Variant = app.get("talk_dock")
	if talk_dock == null:
		push_error("Promo capture: talk dock missing.")
		return
	var entry := {
		"event_id": "suspicious_patron",
		"speaker": {
			"role": "patron",
			"name": "Suspicious Patron",
			"silhouette": "coat",
			"bind": "none",
		},
		"timing": {
			"expires": true,
			"duration_actions": 3,
			"remaining_actions": 2,
		},
	}
	var option := {
		"display_name": "Suspicious Patron",
		"summary": "A patron in a long coat leans in. He says the pit boss is watching the corner table tonight.",
		"choices": [
			{"id": "hear_out", "label": "Hear Him Out", "text": "Listen for the tip."},
			{"id": "buy_drink", "label": "Buy Him a Drink", "text": "Loosen the story with a drink."},
			{"id": "keep_quiet", "label": "Keep Quiet", "text": "You avoid becoming memorable."},
		],
	}
	talk_dock.call("set_entry", entry, option, 2)
	await _settle(6)


func _open_world_map() -> void:
	var opened := await _activate_first_object_with_prefix("travel")
	await _settle(6)
	if not opened and app.has_method("_show_world_map_overlay"):
		app.call("_show_world_map_overlay")
		await _settle(6)
	var run_state: Variant = app.get("run_state")
	if run_state == null:
		return
	var map_data: Dictionary = run_state.world_map if typeof(run_state.world_map) == TYPE_DICTIONARY else {}
	var current_id := str(map_data.get("current_node_id", ""))
	var nodes: Array = map_data.get("nodes", []) if typeof(map_data.get("nodes", [])) == TYPE_ARRAY else []
	for node_value in nodes:
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if node_id.is_empty() or node_id == current_id:
			continue
		if str(node.get("state", "hidden")) == "hidden":
			continue
		if bool(app.call("select_world_map_node", node_id)):
			break
	await _settle(6)


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


func _seed_collection(service: Variant) -> void:
	var resolver: Variant = CollectionItemResolverScript.new()
	var collections: Array = resolver.collections()
	if collections.is_empty() or typeof(collections[0]) != TYPE_DICTIONARY:
		return
	var collection: Dictionary = collections[0]
	var bag_defs: Array = collection.get("bag_defs", []) if typeof(collection.get("bag_defs", [])) == TYPE_ARRAY else []
	for bag_index in range(mini(2, bag_defs.size())):
		if typeof(bag_defs[bag_index]) != TYPE_DICTIONARY:
			continue
		var bag_def: Dictionary = bag_defs[bag_index]
		service.call("grant_bag", int(bag_def.get("itemdef_id", -1)), "promo-bag-%d" % bag_index, {"source": "promo", "source_id": "card"})
	for tier in ["blue", "green"]:
		var tier_items: Array = resolver.item_definitions_for_collection_tier(str(collection.get("id", "")), tier)
		if tier_items.is_empty() or typeof(tier_items[0]) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = tier_items[0]
		var itemdef_id := int(definition.get("itemdef_id", -1))
		for index in range(4):
			var instance: Dictionary = resolver.roll_instance(itemdef_id, "promo-item-%s-%d" % [tier, index])
			service.call("grant_instance", instance)
	service.call("save")


func _save_shot(file_id: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [out_dir, file_id])
	print("PROMO_SHOT %s" % file_id)


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame
