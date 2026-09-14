extends SceneTree

const CrapsGameScript := preload("res://scripts/games/craps.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")

const OUTPUT_DIR := "res://review_artifacts/craps_rework"
const CAPTURE_SIZE := Vector2i(1280, 720)

var failures: Array[String] = []
var saved_files: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = CAPTURE_SIZE
	RenderingServer.set_default_clear_color(Color("#08070d"))
	var definition := _craps_definition()
	if definition.is_empty():
		_fail("Could not load the production Craps definition.")
		return
	var game: GameModule = CrapsGameScript.new()
	game.setup(definition)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("CRAPS-REVIEW-CAPTURE")
	run_state.bankroll = 5000
	run_state.grand_casino_chips = 5000
	run_state.simulation_msec = 40000
	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.size = CAPTURE_SIZE
	root.add_child(canvas)
	canvas.call("set_game_module", game)

	var casino := _casino_environment()
	var casino_table := game.generate_environment_state(run_state, casino, run_state.create_rng("craps_review_casino"))
	_configure_live_table(game, casino_table, false)
	casino["game_states"] = {"craps": casino_table}
	for page in ["line", "numbers", "props", "odds"]:
		if not await _capture_page(canvas, game, run_state, casino, "casino_%s.png" % page, str(page), 45000):
			break
	_configure_roll(game, casino_table, [4, 3], 7, 6, 0, 50000)
	casino["game_states"] = {"craps": casino_table}
	if failures.is_empty():
		await _capture_page(canvas, game, run_state, casino, "casino_dice_in_motion.png", "line", 50100)

	var street := _street_environment()
	var street_table := game.generate_environment_state(run_state, street, run_state.create_rng("craps_review_street"))
	_configure_live_table(game, street_table, true)
	street["game_states"] = {"craps": street_table}
	if failures.is_empty():
		for page in ["line", "numbers", "props", "odds"]:
			if not await _capture_page(canvas, game, run_state, street, "street_%s.png" % page, str(page), 55000):
				break
	_configure_roll(game, street_table, [3, 3], 6, 6, 6, 60000)
	street["game_states"] = {"craps": street_table}
	if failures.is_empty():
		await _capture_page(canvas, game, run_state, street, "street_dice_in_motion.png", "line", 60100)

	var manifest := {
		"tool": "craps_review_capture",
		"passed": failures.is_empty(),
		"capture_size": {"width": CAPTURE_SIZE.x, "height": CAPTURE_SIZE.y},
		"files": saved_files,
		"renderer": "production GameSurfaceCanvas + craps.gd",
	}
	var file := FileAccess.open(OUTPUT_DIR + "/manifest.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()
	if failures.is_empty():
		print("CRAPS_REVIEW_CAPTURE PASS files=%d dir=%s" % [saved_files.size(), ProjectSettings.globalize_path(OUTPUT_DIR)])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _capture_page(canvas: Control, game: GameModule, run_state: RunState, environment: Dictionary, file_name: String, page: String, time_msec: int) -> bool:
	var state := game.surface_state(run_state, environment, {
		"selected_chip": 5 if str(environment.get("archetype_id", "")) == RunState.GRAND_CASINO_ARCHETYPE_ID else 2,
		"craps_bet_page": page,
		"surface_time_msec": time_msec,
	})
	canvas.call("render_game_snapshot", state)
	await process_frame
	await process_frame
	RenderingServer.force_sync()
	var texture := root.get_viewport().get_texture()
	if texture == null:
		_fail("%s could not access a rendered viewport texture." % file_name)
		return false
	var image := texture.get_image()
	if image.is_empty():
		_fail("%s produced an empty image." % file_name)
		return false
	if image.get_size() != CAPTURE_SIZE:
		image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_NEAREST)
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	if image.save_png(path) != OK:
		_fail("Could not save %s." % file_name)
		return false
	saved_files.append(file_name)
	return true


func _configure_live_table(game: GameModule, table: Dictionary, street: bool) -> void:
	table["point"] = 6
	table["shooter_index"] = 0
	table["working_bets"] = {
		"pass_line": 25 if not street else 4,
		"dont_pass": 0,
		"pass_odds": 25 if not street else 4,
		"dont_pass_odds": 0,
		"come": {"5": 10 if not street else 2},
		"dont_come": {"9": 10 if not street else 2},
		"come_odds": {"5": 10 if not street else 2},
		"dont_come_odds": {"9": 10 if not street else 2},
		"place": {"6": 12 if not street else 2, "10": 10 if not street else 2},
		"buy": {"4": 10 if not street else 2},
		"lay": {"10": 10 if not street else 2},
		"hardways": {"8": 5 if not street else 2},
		"big": {"6": 5 if not street else 2},
		"working_on_come_out": false,
	}
	table["npc_bets"] = game.call("_npc_bets_for_roll", table)
	table["last_result"] = {"message": "The table is open and the point is six.", "bankroll_delta": 0, "bet_results": []}
	table["last_roll"] = _roll([2, 4], 6, 0, 6, 35000)
	table["last_roll"]["throw_trajectory"] = game.call("_throw_trajectory", Vector2(36, -148))
	table["roll_history"] = [
		_roll([3, 2], 5, 6, 6, 31000),
		_roll([4, 4], 8, 6, 6, 33000),
		table["last_roll"],
	]
	table["table_energy"] = 28
	table["hot_shooter_streak"] = 2


func _configure_roll(game: GameModule, table: Dictionary, dice: Array, total: int, point_before: int, point_after: int, resolved_at_msec: int) -> void:
	table["last_roll"] = _roll(dice, total, point_before, point_after, resolved_at_msec)
	table["last_roll"]["throw_trajectory"] = game.call("_throw_trajectory", Vector2(36, -148))
	table["roll_history"] = [table["last_roll"]]
	table["point"] = point_after


func _roll(dice: Array, total: int, point_before: int, point_after: int, resolved_at_msec: int) -> Dictionary:
	return {
		"dice": dice.duplicate(),
		"total": total,
		"initial_total": total,
		"setting_bias_applied": false,
		"point_before": point_before,
		"point_after": point_after,
		"animation_id": "craps:review:%d:%d" % [resolved_at_msec, total],
		"resolved_at_msec": resolved_at_msec,
		"throw_trajectory": {},
	}


func _craps_definition() -> Dictionary:
	var file := FileAccess.open("res://data/games/games.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_ARRAY:
		return {}
	for value in parsed as Array:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == "craps":
			return (value as Dictionary).duplicate(true)
	return {}


func _casino_environment() -> Dictionary:
	return {
		"id": "craps_review_casino",
		"archetype_id": RunState.GRAND_CASINO_ARCHETYPE_ID,
		"kind": "boss",
		"game_ids": ["craps"],
		"economic_profile": {"stake_floor": 5, "stake_ceiling": 1000},
	}


func _street_environment() -> Dictionary:
	return {
		"id": "craps_review_street",
		"archetype_id": "back_alley",
		"kind": "shop",
		"game_ids": ["craps"],
		"economic_profile": {"stake_floor": 2, "stake_ceiling": 20},
		"scenario_game_modifiers": {"game_hook": "street_craps"},
	}


func _fail(message: String) -> void:
	failures.append(message)
