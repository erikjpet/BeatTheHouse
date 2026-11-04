extends "res://scripts/tests/vault_drop_save_feedback_check.gd"

# Optional windowed evidence from the base fixture's one ordinary paid drop.
# Requires its awaited _after_refusal_menu hook; never repeats the drop.
# Run through the owned native runner with a fresh private root and an offscreen
# window (--position -32000,-32000), not --headless. Production canvas_items
# scaling and normal processing remain enabled while the Run Menu pauses play.
const CAPTURE_SIZES := [Vector2i(1280, 720), Vector2i(960, 540)]
const MANIFEST := "vault_drop_save_feedback_visual.json"

var capture_dir := ""
var captures: Array[Dictionary] = []


func _initialize() -> void:
	print("VAULT_VISUAL_STAGE initialize_before_base")
	super._initialize()
	print("VAULT_VISUAL_STAGE initialize_after_base completed=", completed)


func _run() -> void:
	print("VAULT_VISUAL_STAGE prepare_before")
	var prepared := _prepare_visual_output()
	print("VAULT_VISUAL_STAGE prepare_after ok=", prepared)
	if not prepared:
		completed = true
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.position = Vector2i(-32000, -32000)
	print("VAULT_VISUAL_STAGE base_run_before")
	await super._run()


func _additional_completion_checks() -> void:
	_check(captures.size() == CAPTURE_SIZES.size(), "Visual hook did not capture both requested window sizes")
	print("VAULT_DROP_SAVE_FEEDBACK_VISUAL captures=", captures.size(), " failures=", JSON.stringify(failures), " output=", capture_dir)


func _prepare_visual_output() -> bool:
	if not _check(not OS.get_cmdline_user_args().has("--cold"), "Visual evidence requires its own fresh warm fixture"):
		return false
	if not _check(DisplayServer.get_name() != "headless", "Visual evidence requires a windowed rendering backend"):
		return false
	capture_dir = private_root.path_join("rendered-menu")
	if not _check(_inside(capture_dir) and not FileAccess.file_exists(capture_dir), "Capture directory must remain inside the owned private root"):
		return false
	var targets: Array[String] = [MANIFEST]
	for size_value in CAPTURE_SIZES:
		var target_size: Vector2i = size_value
		targets.append(_capture_name(target_size))
	for name in targets:
		if not _check(_target_missing(name), "Refusing to overwrite visual evidence: " + name):
			return false
	return _check(DirAccess.make_dir_recursive_absolute(capture_dir) == OK, "Could not create the private capture directory")


func _after_refusal_menu(app: Control) -> void:
	var status: Label = app.get("run_menu_status_label")
	var panel: PanelContainer = app.get("run_menu_panel")
	var run: RunState = app.get("run_state")
	var game: GameModule = app.get("current_game")
	if not _check(status != null and panel != null and run != null and game != null, "Refusal capture requires the existing live Vault menu"):
		return
	var expected_text := status.text
	if not _check(expected_text.contains("Not saved") and expected_text.contains("Resume") and expected_text.contains("Leave"), "Refusal capture requires actual recovery guidance"):
		return
	var protected_snapshot := _snapshot(run, game, true)
	var disk_before := _disk(app)
	var original_size := root.size
	for size_value in CAPTURE_SIZES:
		var target_size: Vector2i = size_value
		root.size = target_size
		root.position = Vector2i(-32000, -32000)
		for _frame in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		var viewport: Rect2 = app.get_viewport_rect()
		var status_rect := status.get_global_rect()
		var panel_rect := panel.get_global_rect()
		var visible := _check(status.is_visible_in_tree() and panel.is_visible_in_tree(), "Refusal controls are not visible in the rendered tree")
		visible = _check(status.text == expected_text, "Window resize changed the refusal guidance") and visible
		visible = _check(viewport.grow(0.5).encloses(panel_rect) and viewport.grow(0.5).encloses(status_rect) and panel_rect.grow(0.5).encloses(status_rect), "Refusal menu/status bounds escaped their viewport or panel") and visible
		visible = _check(status.get_line_count() > 0 and status.get_visible_line_count() >= status.get_line_count(), "Refusal guidance has clipped lines") and visible
		var raster: Image = root.get_texture().get_image()
		visible = _check(root.size == target_size and raster != null and not raster.is_empty() and raster.get_size() == target_size, "Rendered PNG must match the requested physical window size") and visible
		if not visible:
			break
		var file_name := _capture_name(target_size)
		if not _check(_target_missing(file_name), "Refusing to overwrite " + file_name):
			break
		if not _check(raster.save_png(capture_dir.path_join(file_name)) == OK, "Could not write " + file_name):
			break
		captures.append({"file": file_name, "width": target_size.x, "height": target_size.y, "status_text": status.text,
			"viewport_rect": _rect_fact(viewport), "menu_rect": _rect_fact(panel_rect), "status_rect": _rect_fact(status_rect),
			"line_count": status.get_line_count(), "visible_line_count": status.get_visible_line_count(),
			"content_scale_mode": root.content_scale_mode, "content_scale_size": [root.content_scale_size.x, root.content_scale_size.y]})
	root.size = original_size
	root.position = Vector2i(-32000, -32000)
	for _frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	_check(_snapshot(run, game, true) == protected_snapshot and _disk(app) == disk_before, "Rendered menu capture changed the paused live state or saved checkpoint")
	_write_visual_manifest()


func _capture_name(target_size: Vector2i) -> String:
	return "vault_drop_save_refused_%dx%d.png" % [target_size.x, target_size.y]


func _target_missing(file_name: String) -> bool:
	var path := capture_dir.path_join(file_name)
	return _inside(path) and not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path)


func _rect_fact(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _write_visual_manifest() -> void:
	if not _check(_target_missing(MANIFEST), "Refusing to overwrite the visual manifest"):
		return
	var file := FileAccess.open(capture_dir.path_join(MANIFEST), FileAccess.WRITE)
	if not _check(file != null, "Could not open the visual manifest"):
		return
	file.store_string(JSON.stringify({"seed": SEED, "source_sha_operator_supplied": OS.get_environment("BTH_VAULT_SAVE_SOURCE_SHA"),
		"engine": Engine.get_version_info(), "fidelity": "Native rendered Run Menu from the base fixture's single independent ordinary Vault Drop. Two physical 16:9 window sizes retain project canvas_items scaling. Normal processing stays enabled; the existing menu pause owns gameplay suspension. No original campaign access or paid-action replay.",
		"captures": captures, "failures_at_capture": failures}, "\t"))
	_check(file.get_error() == OK, "Could not finish the visual manifest")
	file.close()
