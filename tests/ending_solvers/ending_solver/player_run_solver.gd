extends "res://tests/ending_solvers/rourke_solver/rourke_player_bridge.gd"

const OpeningPolicy := preload("res://tests/ending_solvers/rourke_solver/rourke_opening_policy.gd")
const RouteProfiles := preload("res://tests/ending_solvers/ending_solver/route_profiles.gd")
const POLICIES := ["baseline", "balanced", "risk_aware"]
const MAX_IDENTICAL_DECISIONS := 28
const STARTUP_POLL_FRAMES := 96
const STARTUP_GRACE_FRAMES := 2304
const SHUTDOWN_DRAIN_FRAMES := 12

enum ResultRecovery { NONE, WATCH_RESULT, SAVE_SENT, SAVED, LOAD_SENT, DONE }

var opening := OpeningPolicy.new()
var requested_seed := ""
var policy := "balanced"
var active_policy := "balanced"
var requested_route := ""
var selected_route := ""
var route_model: Dictionary = {}
var starting_observation: Dictionary = {}
var route_signature: Array[String] = []
var previous_venue := ""
var actions := 0
var action_budget_override := 0
var started_seeded_run := false
var seed_start_requested := false
var needs_first_night := false
var startup_grace_frames := 0
var ordinary_round_in_progress := false
var result_recovery := ResultRecovery.NONE
var result_recovery_polls := 0


func _boot() -> void:
	var expected_user_data := ""
	var route_model_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			requested_seed = argument.trim_prefix("--seed=")
		elif argument.begins_with("--policy="):
			policy = argument.trim_prefix("--policy=")
		elif argument.begins_with("--route="):
			requested_route = argument.trim_prefix("--route=")
		elif argument.begins_with("--route-model="):
			route_model_path = argument.trim_prefix("--route-model=")
		elif argument.begins_with("--action-budget="):
			var budget := argument.trim_prefix("--action-budget=")
			if not budget.is_valid_int() or int(budget) < 1 or int(budget) > 3000:
				await _finish("action budget must be between 1 and 3000", {}, 2)
				return
			action_budget_override = int(budget)
		elif argument.begins_with("--expected-user-data="):
			expected_user_data = argument.trim_prefix("--expected-user-data=")
	if requested_seed.strip_edges().is_empty() or policy not in POLICIES:
		await _finish("invalid seed or policy", {}, 2)
		return
	if expected_user_data.is_empty() or _normalized_path(OS.get_user_data_dir()) != _normalized_path(expected_user_data):
		await _finish("Godot user data path differs from the admitted path", {}, 2)
		return
	if not requested_route.is_empty() and requested_route != "auto" and requested_route not in RouteProfiles.policies(_target_ending()):
		await _finish("unknown route for the requested ending", {}, 2)
		return
	if not route_model_path.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(route_model_path))
		if not parsed is Dictionary:
			await _finish("the route model could not be read", {}, 2)
			return
		route_model = parsed
	active_policy = policy
	if not requested_route.is_empty() and requested_route != "auto":
		_select_route(requested_route)
	await start_game()
	var identical_decisions := 0
	var previous_decision := ""
	var action_limit := action_budget_override if action_budget_override > 0 else _max_actions()
	var decision_limit := maxi(_max_iterations(), action_budget_override * 8)
	for _iteration in range(decision_limit):
		var view := observe()
		var screen: Dictionary = view.get("screen", {})
		var screen_name := str(screen.get("screen", ""))
		var report: Dictionary = screen.get("run_report", {})
		if seed_start_requested and screen_name != "START" and bool(screen.get("has_run", false)):
			started_seeded_run = true
		if started_seeded_run and not requested_route.is_empty():
			_observe_route(view)
		if bool(screen.get("run_report_visible", false)) and not report.is_empty():
			await _finish("terminal", view)
			return
		if actions >= action_limit:
			await _finish("action budget exhausted", view)
			return
		var stop_reason := _ending_stop_reason(view)
		if not stop_reason.is_empty():
			await _finish(stop_reason, view)
			return
		var game: Dictionary = view.get("game", {})
		if screen_name in ["ENVIRONMENT", "RESULT", "TRAVEL"] and game.is_empty():
			ordinary_round_in_progress = false
		elif str(game.get("game_id", "")) == "blackjack" and not bool(game.get("boss_duel_active", false)):
			if str(game.get("phase", "")) in ["decision", "settling"]:
				ordinary_round_in_progress = true
		view["ordinary_round_in_progress"] = ordinary_round_in_progress
		var command := _decide(view)
		if command.is_empty():
			command = "wait 16"
		var witness := _witness(view)
		var decision := JSON.stringify([command, witness])
		identical_decisions = identical_decisions + 1 if decision == previous_decision else 0
		previous_decision = decision
		if identical_decisions >= MAX_IDENTICAL_DECISIONS:
			await _finish("no visible progress", view)
			return
		var input := await send(command)
		var ok := bool(input.get("ok", false))
		if not command.begins_with("wait "):
			print("BTH_SOLVER_STEP " + JSON.stringify({
				"command": command if not command.begins_with("set_field seed ") else "set_field seed",
				"accepted": ok, "reason": str(input.get("reason", "")), "view": witness,
			}))
			if ok:
				actions += 1
				_record(command, view)
	await _finish("decision budget exhausted", observe())


func observe() -> Dictionary:
	var view := super.observe()
	var game: Dictionary = view.get("game", {})
	if str(game.get("game_id", "")) != "blackjack" or str(game.get("phase", "")) != "betting":
		return view
	var canvas := app.get("game_surface_canvas") as Control
	var rail: Array = _array(_dict(canvas.call("realtime_surface_state")).get("chip_denominations", []))
	if rail.is_empty():
		return view
	var rendered: Array[int] = []
	rendered.resize(rail.size())
	rendered.fill(0)
	for action in view.get("clickable", {}).get("game_surface_actions", []):
		if str(action.get("action", "")) != "blackjack_wager_place_gesture" or not bool(action.get("enabled", false)):
			continue
		var index := int(action.get("index", -1))
		if index >= 0 and index < rail.size():
			rendered[index] = int(rail[index])
	game["chip_denominations"] = rendered
	return view


func _decide(view: Dictionary) -> String:
	var skip_scene := OpeningPolicy.button(view, ["Skip scene"])
	if not skip_scene.is_empty():
		# The focused travel overlay accepts Enter during departure and arrival.
		return "key Enter"
	var screen: Dictionary = view.get("screen", {})
	if screen.get("screen") == "TRAVEL" and not bool(screen.get("world_map_overlay_visible", false)):
		var receipt := OpeningPolicy.button(view, ["Continue"])
		return "key Enter" if not receipt.is_empty() else "wait 96"
	if not started_seeded_run:
		return _setup_command(view)
	var coach_command := _coach_command(view)
	if not coach_command.is_empty():
		return coach_command
	var restore_room := _result_recovery_command(view)
	if not restore_room.is_empty():
		return restore_room
	return _ending_command(view)


func _result_recovery_command(view: Dictionary) -> String:
	if result_recovery in [ResultRecovery.NONE, ResultRecovery.DONE]:
		return ""
	var screen: Dictionary = view.get("screen", {})
	if bool(screen.get("travel_transition_active", false)) or bool(screen.get("world_map_overlay_visible", false)) \
			or bool(view.get("spatial", {}).get("loading", false)) or bool(view.get("event_popup", {}).get("visible", false)) \
			or bool(view.get("talk", {}).get("visible", false)):
		return ""
	var screen_id := str(screen.get("screen", ""))
	var menu_open := bool(screen.get("run_menu_visible", false))
	if result_recovery == ResultRecovery.LOAD_SENT:
		if not menu_open and screen_id == "ENVIRONMENT" and _has_room_controls(view):
			result_recovery = ResultRecovery.DONE
			_ending_room_recovered()
		return ""
	if result_recovery == ResultRecovery.WATCH_RESULT:
		if screen_id != "RESULT" or _has_room_controls(view):
			if screen_id in ["ENVIRONMENT", "RESULT"] or not view.get("game", {}).is_empty():
				result_recovery = ResultRecovery.NONE
			return ""
		if result_recovery_polls < 4:
			result_recovery_polls += 1
			return "wait 16"
		var save := OpeningPolicy.button(view, ["Save"] if menu_open else ["Menu"])
		return save if not save.is_empty() else "wait 16"
	if result_recovery == ResultRecovery.SAVE_SENT:
		# A successful Save closes the menu. A refused Save leaves it open.
		if menu_open:
			return "wait 16"
		result_recovery = ResultRecovery.SAVED
	if not menu_open:
		var menu := OpeningPolicy.button(view, ["Menu"])
		return menu if not menu.is_empty() else "wait 16"
	var load := OpeningPolicy.button(view, ["Load"])
	if screen.get("run_menu", {}).get("seed") == requested_seed and not load.is_empty():
		return load
	return "wait 16"


static func _has_room_controls(view: Dictionary) -> bool:
	var clickable: Dictionary = view.get("clickable", {})
	return not clickable.get("room_actions", []).is_empty() or not clickable.get("canvas_objects", []).is_empty()


func _record_result_recovery_input(command: String, view: Dictionary) -> void:
	if command in ["click_choice press_anyway", "click_choice change_table"] \
			and result_recovery == ResultRecovery.NONE and view.get("event_popup", {}).get("event_id") == "eye_in_the_sky" \
			and view.get("environment", {}).get("archetype_id") == "grand_casino":
		result_recovery = ResultRecovery.WATCH_RESULT
		result_recovery_polls = 0
	elif result_recovery == ResultRecovery.WATCH_RESULT and command == OpeningPolicy.button(view, ["Save"]):
		result_recovery = ResultRecovery.SAVE_SENT
	elif result_recovery == ResultRecovery.SAVED and command == OpeningPolicy.button(view, ["Load"]):
		result_recovery = ResultRecovery.LOAD_SENT
		if not requested_route.is_empty():
			route_signature.append("room_recovery:resume_slot")


func _ending_room_recovered() -> void:
	pass


func _ending_command(_view: Dictionary) -> String:
	return ""


func _select_route(id: String) -> void:
	if id not in RouteProfiles.policies(_target_ending()):
		return
	selected_route = id
	active_policy = id if id in POLICIES else "risk_aware"
	opening.opening_profile = RouteProfiles.opening_profile(_target_ending(), id)
	_configure_progression(id)


func _observe_route(view: Dictionary) -> void:
	var venue := str(view.get("environment", {}).get("archetype_id", ""))
	if not venue.is_empty() and venue != previous_venue:
		previous_venue = venue
		route_signature.append("venue:" + venue)
	if not starting_observation.is_empty():
		return
	starting_observation = RouteProfiles.starting_observation(view)
	if requested_route == "auto" and not starting_observation.is_empty():
		_select_route(RouteProfiles.choose_policy(_target_ending(), route_model, starting_observation))


func _configure_progression(_id: String) -> void:
	pass


func _ending_stop_reason(_view: Dictionary) -> String:
	return ""


func _max_actions() -> int:
	return 500


func _max_iterations() -> int:
	return 1600


func _target_key() -> String:
	return ""


func _matches_target_key(key: String) -> bool:
	return key == _target_key()


func _target_ending() -> String:
	return ""


func _record_ending_input(_command: String, _view: Dictionary) -> void:
	pass


func _setup_command(view: Dictionary) -> String:
	var screen: Dictionary = view.get("screen", {})
	var coach := _coach_command(view)
	if not coach.is_empty():
		return coach
	var accept_lesson := OpeningPolicy.button(view, ["first_lesson_choice:ok"])
	if not accept_lesson.is_empty():
		return accept_lesson
	if str(screen.get("screen", "")) == "START":
		if startup_grace_frames > 0:
			startup_grace_frames -= STARTUP_POLL_FRAMES
			return "wait %d" % STARTUP_POLL_FRAMES
		var start: Dictionary = screen.get("start_menu", {})
		if bool(start.get("run_config_visible", false)):
			var editable_seed := false
			for field in view.get("clickable", {}).get("text_fields", []):
				editable_seed = editable_seed or str(field.get("placeholder", "")) == "Enter run seed"
			if not editable_seed:
				needs_first_night = true
				return OpeningPolicy.button(view, ["Done"])
			if bool(start.get("seed_field_visible", false)) and not bool(start.get("seed_text_committed", false)):
				return "set_field seed " + requested_seed
			if str(start.get("seed_text", "")) == requested_seed:
				return OpeningPolicy.button(view, ["START NEW RUN"])
			return ""
		if needs_first_night:
			return OpeningPolicy.button(view, ["PLAY"])
		return OpeningPolicy.button(view, ["RUN SETUP"], true)
	var confirm := OpeningPolicy.button(view, ["tutorial_skip_dialog:ok"])
	if not confirm.is_empty():
		return confirm
	if bool(screen.get("run_menu_visible", false)):
		var skip := OpeningPolicy.button(view, ["Skip Lessons"])
		if not skip.is_empty():
			return skip
		for surface in view.get("clickable", {}).get("scroll_surfaces", []):
			if str(surface.get("id", "")) == "run_menu" and bool(surface.get("can_scroll_down", false)):
				return "scroll_surface run_menu down"
		return ""
	return OpeningPolicy.button(view, ["Menu"])


func _coach_command(view: Dictionary) -> String:
	var coach: Dictionary = view.get("coach", {})
	if not bool(coach.get("visible", false)):
		return ""
	for choice in view.get("clickable", {}).get("talk_choices", []):
		if str(choice.get("id", "")) == "continue" and bool(choice.get("enabled", false)):
			return "click_choice continue"
	var label := str(coach.get("dismiss_label", "Skip tip"))
	return OpeningPolicy.button(view, [label, "Skip tip"])


func _record(command: String, view: Dictionary) -> void:
	if command == "click_button tutorial_skip_dialog:ok":
		needs_first_night = false
		startup_grace_frames = 0
	if command.begins_with("click_button ") and not started_seeded_run:
		var start := OpeningPolicy.button(view, ["START NEW RUN"])
		if command == start:
			seed_start_requested = not needs_first_night
		if command == start or command == OpeningPolicy.button(view, ["PLAY", "first_lesson_choice:ok"]):
			startup_grace_frames = STARTUP_GRACE_FRAMES
	if command.begins_with("click_action blackjack_deal") and not bool(view.get("game", {}).get("boss_duel_active", false)):
		ordinary_round_in_progress = true
	opening.record_input(command, view)
	if started_seeded_run:
		if not requested_route.is_empty():
			_record_route_action(command, view)
		_record_result_recovery_input(command, view)
		_record_ending_input(command, view)


func _record_route_action(command: String, view: Dictionary) -> void:
	if command.begins_with("click_choice "):
		route_signature.append("choice:" + command.get_slice(" ", 1))
		return
	if command.begins_with("click_action blackjack_deal "):
		var game: Dictionary = view.get("game", {})
		route_signature.append("wager:%d" % int(game.get("selected_stake", 0)))
		return
	for action in ["hit", "stand", "peek", "distraction", "double", "split", "surrender", "boss_callout"]:
		if command.begins_with("click_action blackjack_" + action + " "):
			route_signature.append("blackjack:" + action)
			return
	if command.begins_with("click_action room "):
		var fields := command.split(" ", false)
		if fields.size() == 6:
			var object_id := Marshalls.base64_to_raw(fields[3]).get_string_from_utf8()
			var identity := Marshalls.base64_to_raw(fields[5]).get_string_from_utf8()
			if object_id != "travel:leave" and not object_id.is_empty():
				route_signature.append("room:%s:%s" % [object_id, identity])


func _finish(reason: String, view: Dictionary, exit_code: int = 0) -> void:
	var screen: Dictionary = view.get("screen", {})
	var report: Dictionary = screen.get("run_report", {})
	var outcome: Dictionary = report.get("outcome", {})
	var ending := str(outcome.get("key", ""))
	var report_seed := str(report.get("seed", ""))
	var victory := (
		str(screen.get("screen", "")) == "VICTORY"
		and bool(screen.get("run_report_visible", false))
		and bool(outcome.get("won", false))
		and _matches_target_key(ending)
		and report_seed == requested_seed
	)
	var result := {
		"seed": requested_seed, "report_seed": report_seed, "victory": victory, "ending": ending,
		"ending_target": _target_ending(), "policy": policy, "actions": actions, "reason": reason,
		"last_view": _witness(view),
	}
	if not requested_route.is_empty():
		result["route"] = requested_route
		result["selected_route"] = selected_route
		result["opening_profile"] = opening.opening_profile
		result["starting_observation"] = starting_observation
		result["route_signature"] = route_signature
	print("BTH_SOLVER_RESULT " + JSON.stringify(result))
	if is_instance_valid(app):
		app.queue_free()
		await _wait_frames(SHUTDOWN_DRAIN_FRAMES)
	quit(exit_code)


func _witness(view: Dictionary) -> Dictionary:
	var screen: Dictionary = view.get("screen", {})
	var hud: Dictionary = view.get("status_hud", {})
	var game: Dictionary = view.get("game", {})
	var popup: Dictionary = view.get("event_popup", {})
	var talk: Dictionary = view.get("talk", {})
	var clickable: Dictionary = view.get("clickable", {})
	var witness := {
		"screen": screen.get("screen", ""), "location": view.get("environment", {}).get("display_name", ""),
		"map": screen.get("world_map_overlay_visible", false), "run_menu": screen.get("run_menu_visible", false),
		"room_selection": view.get("spatial", {}).get("selected_object_id", ""),
		"game": game.get("game_id", ""), "phase": game.get("phase", ""), "result": game.get("outcome_message", ""),
		"duel_hand": game.get("boss_hand_number", 0), "tell": game.get("boss_tell", ""),
		"popup": popup.get("title", ""), "talk": talk.get("event_id", ""),
		"choices": popup.get("choice_ids", []) if bool(popup.get("visible", false)) else talk.get("choice_ids", []),
	}
	if bool(game.get("boss_duel_active", false)):
		witness["player_stack"] = game.get("boss_player_stack", 0)
		witness["rourke_stack"] = game.get("boss_rourke_stack", 0)
	if view.has("gold_progress"):
		witness["gold_progress"] = view["gold_progress"]
	if not str(view.get("objective_text", "")).is_empty():
		witness["objective"] = view["objective_text"]
	if str(game.get("game_id", "")) == "blackjack" and game.has("selected_stake"):
		witness["stake"] = game["selected_stake"]
	for field in ["bankroll", "chips", "heat"]:
		var hud_key: String = "heat_level" if field == "heat" else field
		if bool(hud.get(field + "_rendered", false)):
			witness[field] = hud.get(hud_key, 0)
	witness["controls"] = clickable.get("game_surface_actions", []).filter(
		func(row: Dictionary) -> bool: return bool(row.get("enabled", false)),
	).map(func(row: Dictionary) -> String: return str(row.get("action", "")))
	if witness["controls"].is_empty():
		witness["buttons"] = clickable.get("buttons", []).map(func(row: Dictionary) -> String: return str(row.get("text", "")))
		witness["room_actions"] = clickable.get("room_actions", []).map(func(row: Dictionary) -> String: return str(row.get("label", "")))
		witness["room_objects"] = clickable.get("canvas_objects", []).filter(
			func(row: Dictionary) -> bool: return bool(row.get("enabled", false)),
		).map(func(row: Dictionary) -> String: return str(row.get("label", "")))
	if bool(witness["map"]):
		var map: Dictionary = screen.get("world_map", {})
		witness["map_selection"] = map.get("selected_node_id", "")
		witness["map_detail"] = screen.get("world_map_detail_text", "")
	return witness


static func _normalized_path(path: String) -> String:
	return path.replace("\\", "/").simplify_path().to_lower()
