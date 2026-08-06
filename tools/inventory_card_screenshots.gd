extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const RunViewModelScript := preload("res://scripts/ui/run_inventory_view_model.gd")
const RunScreenScript := preload("res://scripts/ui/run_inventory_screen.gd")
const MetaScreenScript := preload("res://scripts/ui/meta_item_interaction_screen.gd")

var out_dir := "user://inventory_card_captures"


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=").strip_edges()
	call_deferred("_capture")


func _capture() -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load(false)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("INVENTORY-CARD-CAPTURE")
	run_state.inventory = [
		"creased_luck_card",
		"creased_luck_card",
		"roadside_map",
		"instant_coffee",
		"loaded_dice",
		"high_roller_watch",
	]
	var service: RunActionService = RunActionServiceScript.new()
	service.setup(library, run_state)
	var model := RunViewModelScript.build(run_state, service, "inspect", "", {})
	var absolute_dir := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	await _capture_run(model, Vector2i(1280, 720), false, "%s/run_inventory_desktop.png" % absolute_dir)
	await _capture_run(model, Vector2i(640, 360), true, "%s/run_inventory_small.png" % absolute_dir)
	var meta_model := model.duplicate(true)
	meta_model["mode"] = "meta_container"
	meta_model["title"] = "Inventory and Storage"
	meta_model["summary"] = "The same cards follow your haul home."
	await _capture_meta(meta_model, Vector2i(1280, 720), false, "%s/meta_inventory_desktop.png" % absolute_dir)
	await _capture_meta(meta_model, Vector2i(640, 360), true, "%s/meta_inventory_small.png" % absolute_dir)
	print("INVENTORY_CARD_CAPTURES %s" % absolute_dir)
	quit(0)


func _capture_run(model: Dictionary, viewport_size: Vector2i, small: bool, path: String) -> void:
	root.size = viewport_size
	var backdrop := _backdrop()
	root.add_child(backdrop)
	var screen: RunInventoryScreen = RunScreenScript.new()
	backdrop.add_child(screen)
	screen.configure(Callable(self, "_texture"))
	screen.set_reduced_motion(true)
	screen.set_small_screen_mode(small)
	screen.open(model)
	await _save_frame(path)
	backdrop.queue_free()
	await process_frame


func _capture_meta(model: Dictionary, viewport_size: Vector2i, small: bool, path: String) -> void:
	root.size = viewport_size
	var backdrop := _backdrop()
	root.add_child(backdrop)
	var screen: MetaItemInteractionScreen = MetaScreenScript.new()
	backdrop.add_child(screen)
	screen.configure(Callable(self, "_texture"))
	screen.set_reduced_motion(true)
	screen.set_small_screen_mode(small)
	screen.open(model)
	await _save_frame(path)
	backdrop.queue_free()
	await process_frame


func _save_frame(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Inventory card capture failed for %s: %s" % [path, error])


func _backdrop() -> ColorRect:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#05060a")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return backdrop


func _texture(path: String) -> Texture2D:
	return load(path) as Texture2D if not path.is_empty() else null
