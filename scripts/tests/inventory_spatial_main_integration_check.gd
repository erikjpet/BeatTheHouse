extends SceneTree

const MetaServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const ResolverScript := preload("res://scripts/core/collection_item_resolver.gd")
const MetaViewModelScript := preload("res://scripts/ui/meta_item_interaction_view_model.gd")
const TEST_STORE_PATH := "user://inventory_spatial_main_integration.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment(MetaServiceScript.STORE_PATH_ENV, TEST_STORE_PATH)
	_remove_test_store()
	var scene := load("res://scenes/main.tscn") as PackedScene
	var app := scene.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	app.call("open_meta_home")
	await process_frame
	var service: Variant = app.get("meta_collection_service")
	var resolver: Variant = ResolverScript.new()
	var item_ids: Array = []
	for index in range(14):
		var item: Dictionary = service.grant_instance(resolver.roll_instance(1000, "main-spatial-item-%d" % index))
		item_ids.append(int(item.get("instance_id", 0)))
	var bag_ids: Array = []
	for index in range(13):
		var bag: Dictionary = service.grant_bag(9000, "main-spatial-bag-%d" % index)
		bag_ids.append(int(bag.get("instance_id", 0)))
	var unchanged_snapshot := JSON.stringify(service.snapshot())

	app.call("open_meta_container")
	await process_frame
	var inventory_snapshot: Dictionary = app.call("current_meta_item_interaction_snapshot")
	_check(bool(inventory_snapshot.get("visible", false)), "open_meta_container did not open the spatial host.")
	_check(str(inventory_snapshot.get("mode", "")) == MetaViewModelScript.MODE_CONTAINER, "Container compatibility entry opened the wrong mode.")
	_check(int(inventory_snapshot.get("item_count", 0)) == 14, "Main meta container route truncated owned instances.")
	_check(bool(app.call("_modal_contract_blocks_player_input")), "Spatial meta inventory did not block environment input.")

	app.call("open_meta_bag", int(bag_ids[12]))
	await process_frame
	var bag_snapshot: Dictionary = app.call("current_meta_item_interaction_snapshot")
	_check(str(bag_snapshot.get("mode", "")) == MetaViewModelScript.MODE_BAGS, "open_meta_bag did not open the bag-selection surface.")
	_check(str(bag_snapshot.get("selected_key", "")) == "meta:bag:%d" % int(bag_ids[12]), "Bag selection did not preserve exact instance identity.")
	_check(service.unopened_bags().size() == 13, "Opening the bag-selection surface consumed a bag before explicit Open.")

	app.call("open_meta_sell_counter")
	await process_frame
	var sale_snapshot: Dictionary = app.call("current_meta_item_interaction_snapshot")
	_check(str(sale_snapshot.get("mode", "")) == MetaViewModelScript.MODE_SALE and int(sale_snapshot.get("item_count", 0)) == 27, "Sal sale route did not expose every exact item and bag.")

	app.call("open_meta_trade_up")
	for index in range(5):
		app.call("_toggle_meta_trade_selection", int(item_ids[index]))
	await process_frame
	var trade_snapshot: Dictionary = app.call("current_meta_item_interaction_snapshot")
	_check(str(trade_snapshot.get("mode", "")) == MetaViewModelScript.MODE_TRADE, "Trade-up route did not use the spatial host.")
	_check((trade_snapshot.get("trade_selected_instance_ids", []) as Array).size() == 5, "Trade-up did not retain five arbitrary exact selections.")
	_check(JSON.stringify(service.snapshot()) == unchanged_snapshot, "Selection-only Main routes mutated the store or RNG state.")

	app.call("close_meta_item_interaction")
	await process_frame
	_check(not bool(app.call("_modal_contract_blocks_player_input")), "Closing the spatial meta host did not restore environment input.")
	app.queue_free()
	await process_frame
	_remove_test_store()
	OS.set_environment(MetaServiceScript.STORE_PATH_ENV, "")
	if failures.is_empty():
		print("INVENTORY_SPATIAL_MAIN_INTEGRATION_CHECK PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _remove_test_store() -> void:
	if FileAccess.file_exists(TEST_STORE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STORE_PATH))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
