extends SceneTree

# Promo capture tool for the v0.5 release checklist and publish-copy index.
# It boots the real app, drives representative 0.5 UI states, and saves
# full-viewport screenshots.
# Run windowed (not --headless):
#   <godot.exe> --path . --script res://tools/promo_screenshots_0_5.gd -- --out=C:/absolute/output/dir

const MainScene := preload("res://scenes/main.tscn")
const CollectionItemResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const SEED_TEXT := "PROMO-V05-CAPTURE"

var app: Control
var out_dir := "user://promo_captures_0_5"


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var store_path := "%s/promo_meta_store.json" % out_dir
	OS.set_environment("BTH_META_COLLECTION_PATH", store_path)
	if FileAccess.file_exists(store_path):
		DirAccess.remove_absolute(store_path)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1280, 720))
	app = MainScene.instantiate()
	root.add_child(app)
	await _settle(10)
	await _save_shot("01_start_screen")
	await _capture_run_flow()
	await _capture_cage()
	await _capture_sale_showcase()
	await _capture_run_report()
	print("PROMO_CAPTURE_0_5_DONE -> %s" % out_dir)
	quit(0)


func _capture_run_flow() -> void:
	app.call("start_foundation_run", SEED_TEXT, {})
	await _settle(14)
	await _save_shot("02_room_hud")
	await _show_dialogue()
	await _save_shot("03_conversation_popup")
	var talk_dock: Variant = app.get("talk_dock")
	if talk_dock != null:
		talk_dock.call("clear_entry")
	await _settle(4)
	_set_environment_archetype("grand_casino")
	await _settle(8)
	app.call("enter_game", "blackjack", "blackjack")
	await _settle(10)
	await _save_shot("04_cheat_dock")
	await _save_shot("05_game_surface")
	if app.has_method("back_to_environment"):
		app.call("back_to_environment")
	await _settle(6)


func _capture_cage() -> void:
	if app.get("run_state") == null:
		app.call("start_foundation_run", SEED_TEXT, {})
		await _settle(8)
	_set_environment_archetype("grand_casino_cage")
	await _settle(12)
	await _save_shot("06_cage")


func _capture_sale_showcase() -> void:
	app.call("_enter_meta_location", "pawn_shop")
	await _settle(10)
	var service: Variant = app.get("meta_collection_service")
	if service != null:
		service.call("add_gold", 5000)
		if service.has_method("generate_and_insert_sal_stock"):
			service.call("generate_and_insert_sal_stock", "promo-v05-sale-showcase")
		service.call("save")
	await _settle(4)
	app.call("_enter_meta_location", "pawn_shop")
	await _settle(8)
	var opened := false
	var snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	var objects: Array = snapshot.get("objects", []) if typeof(snapshot.get("objects", [])) == TYPE_ARRAY else []
	for object_value in objects:
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = object_value
		var object_id := str(object_data.get("object_id", ""))
		if object_id.begins_with("meta_sal_shelf:") and bool(object_data.get("enabled", true)):
			opened = bool(app.call("activate_interactable_object", object_id))
			break
	if not opened and app.has_method("open_meta_sal_shelf"):
		app.call("open_meta_sal_shelf", 0)
	await _settle(10)
	await _save_shot("07_sale_showcase")


func _capture_run_report() -> void:
	app.call("start_foundation_run", "%s-REPORT" % SEED_TEXT, {})
	await _settle(8)
	_set_environment_archetype("grand_casino")
	await _settle(6)
	var run_state: Variant = app.get("run_state")
	if run_state != null:
		run_state.call("fail_run", "bankroll_zero", "Promo run ended at the Grand Casino after one risky climb.")
	if app.has_method("_route_failed_run_if_needed"):
		app.call("_route_failed_run_if_needed", {"message": "Promo run ended."})
	if app.has_method("_refresh"):
		app.call("_refresh")
	await _settle(14)
	await _save_shot("08_run_report")


func _set_environment_archetype(archetype_id: String) -> bool:
	var library: Variant = app.get("library")
	var run_state: Variant = app.get("run_state")
	if library == null or run_state == null:
		return false
	var archetype: Dictionary = library.environment_archetype(archetype_id) if library.has_method("environment_archetype") else {}
	if archetype.is_empty():
		push_error("Promo capture: archetype not found: %s" % archetype_id)
		return false
	var rng: Variant = run_state.create_rng()
	var environment: Variant = EnvironmentInstance.from_archetype(archetype, 1, rng, library, run_state.challenge_config)
	var data: Dictionary = environment.to_dict()
	data["world_node_id"] = archetype_id
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data)
	run_state.save_rng(rng)
	run_state.set_environment(data)
	if app.has_method("_clear_selected_game_action"):
		app.call("_clear_selected_game_action")
	if app.has_method("_clear_selected_travel"):
		app.call("_clear_selected_travel")
	if app.has_method("clear_interaction_focus"):
		app.call("clear_interaction_focus")
	if app.has_method("_refresh"):
		app.call("_refresh")
	return true


func _show_dialogue() -> void:
	var talk_dock: Variant = app.get("talk_dock")
	if talk_dock == null:
		push_error("Promo capture: talk dock missing.")
		return
	var entry := {
		"event_id": "promo_crew_warning",
		"speaker": {
			"role": "crew",
			"name": "Mara and Jax",
			"presentation": "group",
			"portrait_count": 2,
			"bind": "none",
		},
		"timing": {
			"expires": true,
			"duration_actions": 3,
			"remaining_actions": 2,
		},
	}
	var option := {
		"display_name": "Crew Warning",
		"summary": "Mara taps the rail while Jax watches the cashier. They think the house is counting your wins tonight.",
		"choices": [
			{"id": "hear_out", "label": "Hear Them Out", "text": "Listen for the angle."},
			{"id": "keep_grinding", "label": "Keep Grinding", "text": "Stay focused on the next table."},
			{"id": "walk_away", "label": "Walk Away", "text": "Do not owe anyone a favor."},
		],
	}
	talk_dock.call("set_entry", entry, option, 2)
	await _settle(8)


func _save_shot(file_id: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [out_dir, file_id])
	print("PROMO_0_5_SHOT %s" % file_id)


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame
