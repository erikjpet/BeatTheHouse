extends SceneTree

# Captures the real InventoryContainerSurface with the same catalog and asset
# paths used by the running game. Run windowed for a renderer-backed PNG:
#   Godot --path . --script res://tools/inventory_art_screenshots.gd -- --out=<absolute directory>

const CatalogScript := preload("res://scripts/ui/inventory_container_catalog.gd")
const SurfaceScript := preload("res://scripts/ui/inventory_container_surface.gd")

var out_dir := "user://inventory_art_captures"

const CONTAINERS := [
	{"type": "bag", "items": ["instant_coffee", "high_roller_watch", "creased_luck_card"]},
	{"type": "backpack", "items": ["roadside_map", "loaded_dice", "lucky_charm", "cashout_envelope", "cheap_sunglasses"]},
	{"type": "suitcase", "items": ["poker_chip", "velvet_table_key", "thermos_black_coffee", "tarot_card", "timing_bracelet", "foil_sleeve", "lucky_penny"]},
	{"type": "trunk", "items": ["gold_tooth_token", "xray_glasses", "marked_cards", "flask_of_courage", "weighted_keyring", "lucky_bar_napkin", "edge_sort_loupe", "neon_players_charm", "tab_detector", "payout_pamphlet"]},
	{"type": "loose_carry", "items": ["instant_coffee", "creased_luck_card", "loaded_dice", "cheap_sunglasses", "lucky_charm", "cashout_envelope"]},
	{"type": "home_storage", "items": ["roadside_map", "high_roller_watch", "poker_chip", "tarot_card", "thermos_black_coffee", "velvet_table_key", "weighted_keyring", "lucky_penny", "foil_sleeve", "gold_tooth_token"]},
]


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=").strip_edges()
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var backdrop := ColorRect.new()
	backdrop.color = Color("#05060a")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var catalog := CatalogScript.load_catalog(true)
	for index in range(CONTAINERS.size()):
		var definition: Dictionary = CONTAINERS[index]
		var surface: InventoryContainerSurface = SurfaceScript.new()
		surface.position = Vector2(10 + (index % 3) * 423, 8 + (index / 3) * 354)
		surface.size = Vector2(410, 346)
		backdrop.add_child(surface)
		surface.configure(Callable(), catalog)
		surface.set_reduced_motion(true)
		surface.update_model(_model(str(definition.get("type", "loose_carry")), definition.get("items", [])))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var absolute_dir := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var path := "%s/runtime_inventory_art.png" % absolute_dir.trim_suffix("/").trim_suffix("\\")
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Inventory art capture failed: %s" % error)
		quit(1)
		return
	print("INVENTORY_ART_CAPTURE %s" % path)
	quit(0)


func _model(container_type: String, item_ids: Array) -> Dictionary:
	var slots: Array = []
	for item_id_value in item_ids:
		var item_id := str(item_id_value)
		slots.append({
			"slot_index": slots.size(),
			"occupied": true,
			"selection_key": "preview:%s:%s" % [container_type, item_id],
			"item": {
				"id": item_id,
				"display_name": item_id.replace("_", " ").capitalize(),
				"asset_path": "res://assets/art/items/%s.png" % item_id,
			},
		})
	return {
		"selected_key": str((slots[0] as Dictionary).get("selection_key", "")) if not slots.is_empty() else "",
		"focus_explicit": true,
		"containers": [{
			"key": "preview:%s" % container_type,
			"container_type": container_type,
			"display_name": container_type.replace("_", " ").capitalize(),
			"capacity": item_ids.size(),
			"slots": slots,
		}],
	}
