extends SceneTree

const Host = preload("res://scripts/ui/foundation_main.gd")
const Service = preload("res://scripts/core/meta_collection_service.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _has_object(objects: Array, id: String) -> bool:
	for object in objects:
		if str(object.get("object_id", "")) == id:
			return true
	return false

func _run() -> void:
	var ui = Host.new()
	root.add_child(ui)
	await process_frame
	ui.meta_collection_service = Service.new()
	ui.meta_collection_service.mint_players_card({"starter_card": true})
	ui.meta_collection_service.mint_grand_casino_chip_stack(1)
	ui.open_meta_home()
	var home: Array = ui._interactable_object_view_list()
	_check(home.size() > 1 and _has_object(home, "meta_upgrade:home"), "Home fixtures must remain reachable through the room catalog reader.")
	ui._enter_meta_location("pawn_shop")
	var expected: Array = ui._meta_interactable_object_view_list()
	var pawn: Array = ui._interactable_object_view_list()
	_check(pawn.size() == expected.size() and pawn.size() > 1, "Pawn catalog must expose its current meta projection instead of an empty run publication.")
	_check(_has_object(pawn, "meta_sal:talk"), "Sal's sell/talk interaction must be reachable.")
	_check(not _has_object(pawn, "meta_upgrade:home"), "Travel must replace the previous meta room projection.")
	_check(ui.focus_interactable_object("meta_sal:talk"), "The normal focus route must accept Sal's published interaction.")
	var before: Dictionary = ui.run_state.to_dict()
	var collection: Dictionary = ui.meta_collection_service.snapshot()
	ui._interactable_object_view_list()
	ui._meta_interactable_object_view_list()
	_check(ui.run_state.to_dict() == before and ui.meta_collection_service.snapshot() == collection, "Catalog reads must leave RNG, economy and profile state unchanged.")
	ui.queue_free()
	await process_frame
	print("META_ROOM_CATALOG_READ_CHECK: ", "PASS (6 checks)" if failures.is_empty() else "FAIL: %s" % failures)
	quit(0 if failures.is_empty() else 1)
