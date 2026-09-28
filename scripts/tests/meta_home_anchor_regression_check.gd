extends SceneTree

const MetaServiceScript := preload("res://scripts/core/meta_collection_service.gd")
const TEST_STORE_PATH := "user://meta_home_anchor_regression.json"
const TUTORIAL_ANCHOR_ID := "tutorial:meta_home_card_container"


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
	await process_frame
	var spatial := app.call("current_spatial_interaction_snapshot") as Dictionary
	var has_container := false
	var has_exit := false
	for object_value in spatial.get("objects", []):
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_id := str((object_value as Dictionary).get("object_id", ""))
		has_container = has_container or object_id.begins_with("meta_container:")
		has_exit = has_exit or object_id == "travel:leave"
	var anchors := app.call("_coach_anchor_rects") as Dictionary
	var anchor_rect: Variant = (anchors.get("interactable_objects", {}) as Dictionary).get(TUTORIAL_ANCHOR_ID, Rect2())
	var anchor_valid := anchor_rect is Rect2 and (anchor_rect as Rect2).has_area()
	var run: Variant = app.get("run_state")
	var placement_errors: Array = run.current_environment.get("layout", {}).get("placement_errors", []) if run != null else ["missing run"]
	var ok := has_container and has_exit and anchor_valid and placement_errors.is_empty()
	app.queue_free()
	await process_frame
	_remove_test_store()
	OS.set_environment(MetaServiceScript.STORE_PATH_ENV, "")
	if ok:
		print("META HOME CHECK container=true map_door=true tutorial_anchor=true placement_errors=0 ok=true")
		quit(0)
		return
	printerr("META HOME CHECK container=%s map_door=%s tutorial_anchor=%s placement_errors=%s ok=false" % [
		str(has_container), str(has_exit), str(anchor_valid), JSON.stringify(placement_errors),
	])
	quit(1)


func _remove_test_store() -> void:
	if FileAccess.file_exists(TEST_STORE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STORE_PATH))
