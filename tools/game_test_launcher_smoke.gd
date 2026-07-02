extends SceneTree

const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")

var failures: Array = []
var launched: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: FoundationMain = FoundationMainScript.new()
	root.add_child(main)
	await process_frame
	await process_frame
	main.open_game_test_menu()
	await process_frame
	await process_frame
	if main.start_menu_intro != null and main.start_menu_intro.visible:
		failures.append("Game Test menu did not hide the main-menu intro block.")
	if main.game_test_menu == null or not main.game_test_menu.visible:
		failures.append("Game Test menu was not visible after opening.")
	else:
		_check_game_test_layout(main)
	var game_ids: Array = main.call("_implemented_game_ids")
	if game_ids.is_empty():
		failures.append("No implemented games were exposed by the test launcher.")
	for game_id in game_ids:
		main.return_to_main_menu()
		await process_frame
		main.start_game_test_session(str(game_id))
		await process_frame
		if main.current_game == null:
			failures.append("Launcher did not enter %s." % str(game_id))
			continue
		if main.current_game.get_id() != str(game_id):
			failures.append("Launcher entered %s instead of %s." % [main.current_game.get_id(), str(game_id)])
			continue
		if main.run_state == null:
			failures.append("Launcher did not create a run state for %s." % str(game_id))
			continue
		if not bool(main.dev_game_test_mode):
			failures.append("Launcher did not mark %s as a non-autosaved test session." % str(game_id))
		var environment: Dictionary = main.run_state.current_environment
		if not (environment.get("game_ids", []) as Array).has(str(game_id)):
			failures.append("Test environment for %s did not expose the selected game id." % str(game_id))
		var states: Dictionary = environment.get("game_states", {})
		if not states.has(str(game_id)):
			failures.append("Test environment for %s did not generate game state." % str(game_id))
		var snapshot := main.current_game_view_snapshot()
		if str(snapshot.get("game_id", "")) != str(game_id):
			failures.append("Game snapshot for %s did not report the active game id." % str(game_id))
		launched.append(str(game_id))
	if not game_ids.is_empty():
		var target_game_id := str(game_ids[0])
		main.return_to_main_menu()
		await process_frame
		if main.game_test_seed_input != null:
			main.game_test_seed_input.text = "CUSTOM-LAUNCH"
		if main.game_test_bankroll_input != null:
			main.game_test_bankroll_input.value = 54321
		if main.game_test_stake_floor_input != null:
			main.game_test_stake_floor_input.value = 7
		if main.game_test_stake_ceiling_input != null:
			main.game_test_stake_ceiling_input.value = 77
		if main.game_test_security_option != null:
			for index in range(main.game_test_security_option.item_count):
				if str(main.game_test_security_option.get_item_metadata(index)) == "high":
					main.game_test_security_option.select(index)
					break
		if main.game_test_generation_overrides_text != null:
			main.game_test_generation_overrides_text.text = JSON.stringify({
				"environment": {
					"depth": 2,
					"economic_profile": {"cashout_tone": "lab"},
				},
				"game_state": {
					"test_marker": "customized",
					"rules": {"test_rule": 7},
				},
			})
		main.start_game_test_session(target_game_id)
		await process_frame
		if main.run_state == null:
			failures.append("Custom launch did not create a run state.")
		else:
			var environment: Dictionary = main.run_state.current_environment
			var economic: Dictionary = environment.get("economic_profile", {})
			var security: Dictionary = environment.get("security_profile", {})
			var state: Dictionary = (environment.get("game_states", {}) as Dictionary).get(target_game_id, {})
			if main.run_state.bankroll != 54321:
				failures.append("Custom launch bankroll was not applied: got %d." % main.run_state.bankroll)
			if int(environment.get("depth", 0)) != 2:
				failures.append("Custom launch environment override was not applied.")
			if int(economic.get("stake_floor", 0)) != 7 or int(economic.get("stake_ceiling", 0)) != 77:
				failures.append("Custom launch stake range was not applied: got %d/%d." % [int(economic.get("stake_floor", 0)), int(economic.get("stake_ceiling", 0))])
			if str(economic.get("cashout_tone", "")) != "lab":
				failures.append("Custom launch nested environment override was not applied.")
			if str(security.get("strictness", "")) != "high":
				failures.append("Custom launch security strictness was not applied.")
			if str(state.get("test_marker", "")) != "customized":
				failures.append("Custom launch game-state override was not applied.")
			if int((state.get("rules", {}) as Dictionary).get("test_rule", 0)) != 7:
				failures.append("Custom launch nested game-state override was not applied.")
	var report := {
		"tool": "game_test_launcher_smoke",
		"launched": launched,
		"failures": failures,
	}
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)


func _check_game_test_layout(main: FoundationMain) -> void:
	var menu_rect := main.game_test_menu.get_global_rect()
	if menu_rect.size.x <= 0.0 or menu_rect.size.y <= 0.0:
		failures.append("Game Test menu did not receive a usable layout rect.")
		return
	for child in main.game_test_menu.get_children():
		if not child is Control:
			continue
		var control := child as Control
		if not control.visible:
			continue
		var rect := control.get_global_rect()
		if rect.position.y < menu_rect.position.y - 1.0 or rect.end.y > menu_rect.end.y + 1.0:
			failures.append("Game Test control overflows vertical menu bounds: %s." % control.name)
