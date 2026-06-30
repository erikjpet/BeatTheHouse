extends SceneTree

# Press-kit screenshot harness. Runs the real main scene in a window (non-headless)
# and saves PNG captures of the start screen, a generated room, and each game
# surface through the foundation UI's own public API.

const MainScene := preload("res://scenes/main.tscn")

var app: Control
var out_dir := ""
var saved: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	out_dir = ProjectSettings.globalize_path("res://branding/screenshots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))

	app = MainScene.instantiate()
	root.add_child(app)
	await _settle(10)

	# Enable the in-app game launcher so we can enter each game's real interface.
	app.set("show_game_library_launcher", true)

	await _shot("01_start_screen")

	# A seeded run to show a generated environment room.
	app.call("start_foundation_run", "BTH-PRESSKIT-1")
	await _settle()
	await _shot("02_environment_room")

	app.call("start_foundation_run", "BTH-PRESSKIT-2")
	await _settle()
	await _shot("03_environment_room_b")

	var games := [
		"blackjack",
		"roulette",
		"slot",
		"video_poker",
		"baccarat",
		"bar_dice",
		"pull_tabs",
	]
	var index := 4
	for game_id in games:
		app.call("start_game_test_session", game_id)
		await _settle(10)
		_set_believable_bankroll(600)
		await _settle(3)
		await _shot("%02d_%s" % [index, game_id])
		# Try one primary action to show the game in play.
		await _play_one_action()
		await _shot("%02d_%s_in_play" % [index, game_id])
		index += 1

	print("CAPTURED %d screenshots to %s" % [saved.size(), out_dir])
	for path in saved:
		print("  ", path)
	quit(0)


func _set_believable_bankroll(amount: int) -> void:
	var run_state: Object = app.get("run_state")
	if run_state != null:
		run_state.set("bankroll", amount)
	if app.has_method("_refresh"):
		app.call("_refresh")


func _play_one_action() -> void:
	if app == null or not app.has_method("current_game_view_snapshot"):
		return
	var snapshot: Dictionary = app.call("current_game_view_snapshot")
	if int(snapshot.get("stake_max", 0)) > 0 and bool(snapshot.get("has_valid_stake", false)):
		app.call("set_selected_stake", int(snapshot.get("stake_max", 0)))
		await _settle(2)
	var legal_actions: Array = snapshot.get("legal_actions", [])
	if legal_actions.is_empty():
		return
	var first: Dictionary = legal_actions[0]
	var action_id := str(first.get("id", first.get("action_id", "")))
	var action_kind := str(first.get("kind", first.get("action_kind", "legal")))
	if action_id.is_empty():
		return
	app.call("select_game_action", action_id, action_kind)
	await _settle(2)
	app.call("resolve_selected_game_action")
	await _settle(8)
	# Some games gate the wager behind a confirm popup.
	if app.has_method("confirm_pending_wager_action"):
		app.call("confirm_pending_wager_action")
		await _settle(8)


func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	var error := image.save_png(path)
	if error == OK:
		saved.append(path)
	else:
		print("FAILED to save ", path, " err=", error)
