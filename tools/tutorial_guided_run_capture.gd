extends SceneTree

# Windowed proof capture for the dialogue-guided first run. The mechanics are
# exercised by tutorial_seed_audit.gd; this tool stages those proven states in
# the production Main scene so TalkDock, coach focus, and room/game art are
# captured at readable scale.

const MainScene := preload("res://scenes/main.tscn")

var app: Control
var out_dir := "res://.tmp/tutorial_rework/captures"


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=")
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	OS.set_environment("BTH_META_COLLECTION_PATH", "%s/tutorial_capture_meta.json" % ProjectSettings.globalize_path(out_dir))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(Vector2i(1280, 720))
	app = MainScene.instantiate()
	root.add_child(app)
	await _settle(10)
	app.call("start_tutorial_run")
	await _settle(14)
	await _save_shot("01_path_a_apartment_pal")

	_stage_environment("corner_store")
	_stage_guide_lesson("tutorial_route_choice")
	await _settle(8)
	await _save_shot("02_route_split_path_a_or_b")

	_clear_guide_state()
	_stage_environment("gas_station_casino")
	var run_state: RunState = app.get("run_state")
	if not run_state.inventory.has("xray_glasses"):
		run_state.add_item("xray_glasses")
	app.call("enter_game", "pull_tabs", "pull_tabs")
	await _settle(10)
	print("TUTORIAL_CAPTURE_SCREEN pull_tabs=%s" % str(app.get("current_screen")))
	_stage_guide_lesson("tutorial_gas_xray_buy")
	await _settle(8)
	await _save_shot("03_path_a_xray_pull_tab")

	app.call("back_to_environment")
	_clear_guide_state()
	_stage_environment("small_underground_casino")
	app.call("enter_game", "blackjack", "blackjack")
	await _settle(8)
	print("TUTORIAL_CAPTURE_SCREEN blackjack=%s" % str(app.get("current_screen")))
	_stage_blackjack_count_surface()
	_stage_guide_lesson("tutorial_blackjack_count_all")
	await _settle(8)
	await _save_shot("04_path_b_blackjack_count")

	app.call("back_to_environment")
	_clear_guide_state()
	_stage_environment("grand_casino")
	_stage_guide_lesson("tutorial_host_entry")
	await _settle(8)
	await _save_shot("05_grand_host_vivienne")

	_clear_guide_state()
	_stage_guide_lesson("tutorial_rourke_intro")
	await _settle(8)
	await _save_shot("06_rourke_clean_play_warning")

	_clear_guide_state()
	_stage_environment("grand_casino_cage")
	app.call("start_dialogue", "linda_cage_services", {"event_id": "capture:linda_tutorial", "source": "tutorial_capture", "start_node": "main"})
	await _settle(8)
	await _save_shot("07_linda_extended_chips_and_debt")

	app.call("return_to_main_menu")
	await _settle(5)
	app.call("start_foundation_run", "NORMAL-HOST-CAPTURE", {})
	await _settle(8)
	_stage_environment("grand_casino")
	app.call("_queue_normal_grand_host_greeting", {"id": "normal_previous_room", "archetype_id": "bar"})
	await _settle(8)
	await _save_shot("08_normal_run_host_greeting")
	print("TUTORIAL_GUIDED_CAPTURE_DONE -> %s" % ProjectSettings.globalize_path(out_dir))
	quit(0)


func _stage_environment(archetype_id: String) -> bool:
	var library: ContentLibrary = app.get("library")
	var run_state: RunState = app.get("run_state")
	if library == null or run_state == null:
		return false
	var archetype := library.environment_archetype_for_challenge(library.environment_archetype(archetype_id), run_state.challenge_config)
	if archetype.is_empty():
		push_error("Tutorial capture archetype missing: %s" % archetype_id)
		return false
	var rng := run_state.create_rng("tutorial_capture:%s" % archetype_id)
	var environment := EnvironmentInstance.from_archetype(archetype, 1, rng, library, run_state.challenge_config)
	var data := environment.to_dict()
	data["world_node_id"] = archetype_id
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data)
	run_state.save_rng(rng)
	run_state.set_environment(data)
	app.call("_reset_game_surface_runtime_state")
	app.call("clear_interaction_focus")
	app.call("_refresh")
	return true


func _stage_guide_lesson(lesson_id: String) -> void:
	_clear_guide_state()
	var library: ContentLibrary = app.get("library")
	var coach: CoachOverlay = app.get("coach_overlay")
	var lesson := library.tutorial_lesson(lesson_id)
	if lesson.is_empty():
		push_error("Tutorial capture lesson missing: %s" % lesson_id)
		return
	lesson["trigger"] = {"state_predicates": []}
	coach.set_lessons([lesson])
	coach.begin_tutorial_run({})
	coach.evaluate_at_boundary(app.call("_coach_context_snapshot"))
	app.call("_refresh_talk_dock")
	var run_state: RunState = app.get("run_state")
	print("TUTORIAL_CAPTURE_DIALOGUE lesson=%s queued=%s" % [lesson_id, str(run_state.next_pending_talk_event().get("event_id", ""))])


func _clear_guide_state() -> void:
	var run_state: RunState = app.get("run_state")
	if run_state != null:
		while run_state.pending_talk_event_count() > 0:
			var entry := run_state.next_pending_talk_event()
			run_state.complete_talk_event_resolution(str(entry.get("event_id", "")))
	var talk_dock: TalkDock = app.get("talk_dock")
	if talk_dock != null:
		talk_dock.clear_entry()
	var coach: CoachOverlay = app.get("coach_overlay")
	if coach != null:
		coach.set_lessons([])
		coach.suspend()
	app.call("_refresh_talk_dock")
	app.call("_refresh_modal_contract_owner")
	app.call("_refresh")


func _stage_blackjack_count_surface() -> void:
	var game: GameModule = app.get("current_game")
	var run_state: RunState = app.get("run_state")
	if game == null or run_state == null:
		return
	var deal := game.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 4}, run_state, run_state.current_environment)
	var count := game.surface_action_command("blackjack_count", 0, false, deal.get("ui_state", {}), run_state, run_state.current_environment)
	app.set("game_surface_ui_state", count.get("ui_state", {}))
	app.call("_refresh")


func _save_shot(file_id: String) -> void:
	var talk_dock: TalkDock = app.get("talk_dock")
	if talk_dock != null:
		talk_dock.call("_complete_body_reveal")
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [ProjectSettings.globalize_path(out_dir), file_id]
	var error := image.save_png(path)
	if error != OK:
		push_error("Tutorial capture failed: %s (%d)" % [path, error])
	else:
		print("TUTORIAL_GUIDED_SHOT %s" % path)


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame
