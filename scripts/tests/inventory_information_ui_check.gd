extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const RunInventoryViewModelScript := preload("res://scripts/ui/run_inventory_view_model.gd")
const RunInventoryScreenScript := preload("res://scripts/ui/run_inventory_screen.gd")
const MetaItemInteractionScreenScript := preload("res://scripts/ui/meta_item_interaction_screen.gd")
const ItemCardViewModelScript := preload("res://scripts/ui/item_card_view_model.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load(false)
	var run: RunState = RunStateScript.new()
	run.start_new("INVENTORY-INFORMATION-UI")
	var item_ids: Array[String] = []
	for definition_value in library.items:
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var item_id := str((definition_value as Dictionary).get("id", "")).strip_edges()
		if not item_id.is_empty():
			item_ids.append(item_id)
	var service: RunActionService = RunActionServiceScript.new()
	service.setup(library, run)
	for item_id in item_ids:
		var detail := service.inventory_item_detail(item_id)
		_check(not detail.is_empty(), "Missing inventory detail for %s." % item_id)
		_check(not str(detail.get("use_instructions", "")).strip_edges().is_empty(), "Missing usage instructions for %s." % item_id)
		var card := ItemCardViewModelScript.build(detail)
		if not str(detail.get("effect_summary", "")).strip_edges().is_empty():
			_check(str(card.get("description", "")) == str(detail.get("effect_summary", "")), "Card for %s did not preview its mechanics." % item_id)

	var sample_count := mini(24, item_ids.size())
	run.inventory = item_ids.slice(0, sample_count)
	run.invalidate_inventory_effect_cache()
	var model := RunInventoryViewModelScript.build(run, service, "inspect", "", {})
	root.size = Vector2i(1280, 720)
	var screen: RunInventoryScreen = RunInventoryScreenScript.new()
	root.add_child(screen)
	screen.open(model)
	await process_frame
	await process_frame
	var total_count := screen.visible_item_count()
	_check(total_count == sample_count, "Large inventory rendered %d of %d items before filtering." % [total_count, sample_count])
	_check(_control_tree_has_text(screen, "EFFECT"), "Selected item did not show an Effect section.")
	_check(_control_tree_has_text(screen, "HOW TO USE"), "Selected item did not show usage instructions.")

	screen.call("_on_search_changed", "coffee")
	await process_frame
	var coffee_count := screen.visible_item_count()
	_check(coffee_count > 0 and coffee_count < total_count, "Inventory search did not narrow the large item set.")
	screen.call("_on_search_changed", "")
	screen.call("_on_filter_selected", 3)
	await process_frame
	var consumable_count := screen.visible_item_count()
	_check(consumable_count > 0 and consumable_count < total_count, "Consumables filter did not narrow the large item set.")

	screen.call("_on_filter_selected", 0)
	screen.set_small_screen_mode(true)
	screen.size = Vector2(640, 360)
	root.size = Vector2i(640, 360)
	screen.refresh_layout()
	await process_frame
	var layout := screen.layout_rects()
	var popup_rect: Rect2 = layout.get("popup_rect", Rect2())
	_check(popup_rect.has_area() and Rect2(Vector2.ZERO, Vector2(640, 360)).grow(1.0).encloses(popup_rect), "Small-screen inventory escaped the viewport: %s." % popup_rect)
	screen.queue_free()
	await process_frame

	root.size = Vector2i(1280, 720)
	var meta_screen: MetaItemInteractionScreen = MetaItemInteractionScreenScript.new()
	root.add_child(meta_screen)
	meta_screen.open(model)
	await process_frame
	_check(_control_tree_has_text(meta_screen, "EFFECT"), "Home inventory did not show an Effect section.")
	_check(_control_tree_has_text(meta_screen, "HOW TO USE"), "Home inventory did not show usage instructions.")
	meta_screen.call("_on_search_changed", "coffee")
	await process_frame
	var meta_coffee_count := meta_screen.visible_item_count()
	_check(meta_coffee_count > 0 and meta_coffee_count < total_count, "Home inventory search did not narrow the large item set.")
	meta_screen.queue_free()
	await process_frame

	if _failures.is_empty():
		print("INVENTORY_INFORMATION_UI_CHECK PASS definitions=%d large_items=%d search=%d consumables=%d" % [item_ids.size(), total_count, coffee_count, consumable_count])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _control_tree_has_text(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	if node is Button and (node as Button).text.contains(text):
		return true
	for child in node.get_children():
		if _control_tree_has_text(child, text):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
