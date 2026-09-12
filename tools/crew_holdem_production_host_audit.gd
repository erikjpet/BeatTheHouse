extends SceneTree

# Independent production-host audit for the Back-Room Hold'em table. Every
# action crosses FoundationMain's normal game-surface command boundary.

const MainScene := preload("res://scenes/main.tscn")
const GAME_ID := "crew_draw_poker"
const MISSING_ACTION_INDEX := -999
const SEEDS := ["FIX06-32-HOLDEM-A", "FIX06-32-HOLDEM-B", "FIX06-32-HOLDEM-C"]
const RESUME_KEYS := [
	"phase", "hand_number", "session_index", "session_swing", "session_settled",
	"action_ordinal", "button_index", "turn_owner", "turn_order", "turn_cursor",
	"current_bet", "last_raise_size", "round_contributions", "acted_since_raise",
	"raise_count", "player_active", "player_all_in", "player_stack", "player_contribution",
	"community_cards", "burn_cards", "player_cards", "shoe", "seats", "npc_stacks",
	"pot", "action_history", "last_result", "player_signal", "player_signal_history",
]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var rows: Array = []
	for seed_text in SEEDS:
		var primary := await _play_seed(str(seed_text), true, str(seed_text) == str(SEEDS[0]))
		var replay := await _play_seed(str(seed_text), false, str(seed_text) == str(SEEDS[0]))
		if not bool(primary.get("passed", false)) or not bool(replay.get("passed", false)):
			failures.append("Production-host Hold'em seed %s did not complete both deterministic runs." % seed_text)
		if str(primary.get("signature_hash", "")) != str(replay.get("signature_hash", "")):
			failures.append("Production-host Hold'em seed %s changed across deterministic replay." % seed_text)
		rows.append({
			"seed": seed_text,
			"signature_hash": primary.get("signature_hash", ""),
			"streets": primary.get("streets", []),
			"saved_mid_hand": primary.get("saved_mid_hand", false),
			"saved_mid_session": primary.get("saved_mid_session", false),
			"custom_raise_to": primary.get("custom_raise_to", 0),
			"hand": primary.get("hand", {}),
			"button_movement": primary.get("button_movement", {}),
		})
	var report := {"tool": "crew_holdem_production_host_audit", "passed": failures.is_empty(), "failures": failures, "rows": rows}
	var path := "res://.tmp/crew_holdem/production_host_audit.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)


func _play_seed(seed_text: String, exercise_saves: bool, play_second_hand: bool) -> Dictionary:
	var app := MainScene.instantiate()
	app.set("show_game_library_launcher", true)
	app.set("autosave_slot_id", "fix06_32_holdem_%s_%s" % [seed_text.to_lower(), "save" if exercise_saves else "replay"])
	root.add_child(app)
	await _settle(8)
	if not bool(app.call("_ensure_run_ui_built")):
		failures.append("Production host could not build the run UI for Hold'em seed %s." % seed_text)
		return await _finish_app(app, {})
	app.call("_ensure_game_test_menu_built")
	var seed_input := app.get("game_test_seed_input") as LineEdit
	if seed_input == null:
		failures.append("Production host did not expose its authored practice seed input.")
		return await _finish_app(app, {})
	seed_input.text = seed_text
	var start: Dictionary = app.call("start_game_test_session", GAME_ID)
	if not bool(start.get("ok", false)):
		failures.append("Production host rejected Hold'em seed %s." % seed_text)
		return await _finish_app(app, {})
	await _settle(8)
	var first := await _play_hand(app, exercise_saves, true)
	var saved_mid_session := false
	if exercise_saves and bool(first.get("complete", false)):
		var before_session_save := _game_state(app)
		if not _save_host_run(app):
			failures.append("Hold'em seed %s could not write its between-hand save." % seed_text)
		await _settle(2)
		before_session_save = _game_state(app)
		if not bool(app.call("load_foundation_run")):
			failures.append("Hold'em seed %s could not continue from a between-hand save." % seed_text)
		elif not bool(app.call("enter_game", GAME_ID)):
			failures.append("Hold'em seed %s could not re-enter the table after a between-hand save." % seed_text)
		else:
			await _settle(5)
			var after_session_load := _game_state(app)
			saved_mid_session = _resume_signature(before_session_save) == _resume_signature(after_session_load)
			if not saved_mid_session:
				failures.append("Hold'em seed %s changed table state across a between-hand save/continue: %s before=%s after=%s." % [seed_text, JSON.stringify(_changed_resume_keys(before_session_save, after_session_load)), JSON.stringify(_state_summary(before_session_save)), JSON.stringify(_state_summary(after_session_load))])
	var button_movement := {}
	if play_second_hand and bool(first.get("complete", false)):
		var first_button_after := int(_game_state(app).get("button_index", -1))
		var second := await _play_hand(app, false, false)
		var second_button_after := int(_game_state(app).get("button_index", -1))
		button_movement = {"after_hand_1": first_button_after, "after_hand_2": second_button_after, "advanced": second_button_after == first_button_after + 1}
		if not bool(button_movement.get("advanced", false)):
			failures.append("Hold'em dealer button did not advance exactly one seat between hands.")
		if not bool(second.get("complete", false)):
			failures.append("Hold'em second production-host hand did not complete.")
	var signature := _hand_signature(first)
	var result := {
		"passed": bool(first.get("complete", false)),
		"signature_hash": signature.sha256_text(),
		"streets": first.get("streets", []),
		"saved_mid_hand": first.get("saved_mid_hand", false),
		"saved_mid_session": saved_mid_session,
		"custom_raise_to": first.get("custom_raise_to", 0),
		"hand": first.get("arithmetic", {}),
		"button_movement": button_movement,
	}
	return await _finish_app(app, result)


func _play_hand(app: Control, exercise_save: bool, exercise_raise: bool) -> Dictionary:
	var canvas := app.get("game_surface_canvas") as Control
	if not await _perform_action(app, canvas, "poker_deal"):
		failures.append("Production host could not deal Hold'em.")
		return {}
	await _settle(4)
	var dealt := _game_state(app)
	var history_start := (dealt.get("action_history", []) as Array).size()
	var initial_total := _chip_total(dealt) + int(dealt.get("pot", 0))
	var surface: Dictionary = canvas.call("realtime_surface_state")
	if int(surface.get("pot", 0)) != 3:
		failures.append("Hold'em blinds did not open the pot at $3.")
	if str(surface.get("small_blind_actor", "")).is_empty() or str(surface.get("big_blind_actor", "")).is_empty() or str(surface.get("small_blind_actor", "")) == str(surface.get("big_blind_actor", "")):
		failures.append("Hold'em did not assign distinct small- and big-blind actors.")
	if (surface.get("player_cards", []) as Array).size() != 2:
		failures.append("Hold'em did not deal the player exactly two hole cards.")
	for seat_value in surface.get("seats", []):
		for card_value in (seat_value as Dictionary).get("cards", []):
			if typeof(card_value) == TYPE_DICTIONARY and not bool((card_value as Dictionary).get("hidden", false)):
				failures.append("An opponent hole card leaked before showdown.")
	var streets: Array[String] = []
	var saved_mid_hand := false
	var mid_hand_save_attempted := false
	var custom_raise_to := 0
	for _step in range(160):
		await _answer_visible_talk(app)
		canvas = app.get("game_surface_canvas") as Control
		surface = canvas.call("realtime_surface_state")
		var phase := str(surface.get("phase", ""))
		if phase in ["preflop", "flop", "turn", "river"] and not streets.has(phase):
			streets.append(phase)
		if phase == "flop" and exercise_save and not mid_hand_save_attempted:
			mid_hand_save_attempted = true
			if not _save_host_run(app):
				failures.append("Hold'em could not write its mid-hand save.")
				break
			await _settle(2)
			var before_reload := _game_state(app)
			if not bool(app.call("load_foundation_run")) or not bool(app.call("enter_game", GAME_ID)):
				failures.append("Hold'em could not continue from its mid-hand save.")
				break
			await _settle(5)
			var after_reload := _game_state(app)
			saved_mid_hand = _resume_signature(before_reload) == _resume_signature(after_reload)
			if not saved_mid_hand:
				failures.append("Hold'em table state changed across mid-hand save/continue: %s before=%s after=%s." % [JSON.stringify(_changed_resume_keys(before_reload, after_reload)), JSON.stringify(_state_summary(before_reload)), JSON.stringify(_state_summary(after_reload))])
			continue
		if phase == "idle" and int(surface.get("hand_number", 0)) > 0:
			break
		var action := "poker_observe"
		if str(surface.get("turn_owner", "")) == "player":
			action = "poker_call"
			if exercise_raise and phase == "river" and custom_raise_to == 0 and _surface_action_index(canvas, "poker_raise_open") != MISSING_ACTION_INDEX:
				if await _perform_action(app, canvas, "poker_raise_open"):
					await _settle(2)
					canvas = app.get("game_surface_canvas") as Control
					if await _perform_action(app, canvas, "poker_raise_plus_one"):
						await _settle(2)
						canvas = app.get("game_surface_canvas") as Control
						custom_raise_to = int((canvas.call("realtime_surface_state") as Dictionary).get("selected_raise_to", 0))
						if not await _perform_action(app, canvas, "poker_raise_confirm"):
							failures.append("Production host rejected the selected whole-dollar Hold'em raise.")
						await _settle(4)
						continue
		if not await _perform_action(app, canvas, action):
			failures.append("Production host rejected Hold'em action %s during %s." % [action, phase])
			break
		await _settle(4)
	var final_state := _game_state(app)
	var complete := str(final_state.get("phase", "")) == "idle" and int(final_state.get("hand_number", 0)) > 0
	if streets != ["preflop", "flop", "turn", "river"]:
		failures.append("Production-host Hold'em hand missed streets: %s." % JSON.stringify(streets))
	var all_history: Array = final_state.get("action_history", []) if typeof(final_state.get("action_history", [])) == TYPE_ARRAY else []
	var history: Array = all_history.slice(history_start)
	var running_pot := 3
	var action_amounts: Array = []
	var arithmetic_rows: Array = []
	var pot_arithmetic_ok := true
	for row_value in history:
		var row: Dictionary = row_value
		var amount := int(row.get("amount", 0))
		running_pot += amount
		action_amounts.append(amount)
		arithmetic_rows.append({"actor": row.get("actor", ""), "action": row.get("action", ""), "amount": amount, "expected_pot": running_pot, "recorded_pot": int(row.get("pot_after", -1))})
		if int(row.get("pot_after", -1)) != running_pot:
			pot_arithmetic_ok = false
	if not pot_arithmetic_ok:
		failures.append("Hold'em action ledger did not equal blinds plus committed action amounts.")
	var final_total := _chip_total(final_state)
	if complete and final_total != initial_total:
		failures.append("Hold'em payout did not conserve table chips: before=%d after=%d." % [initial_total, final_total])
	var last: Dictionary = final_state.get("last_result", {}) if typeof(final_state.get("last_result", {})) == TYPE_DICTIONARY else {}
	if complete and (last.get("winners", []) as Array).is_empty():
		failures.append("Hold'em completed without a showdown/payout winner.")
	return {
		"complete": complete,
		"streets": streets,
		"saved_mid_hand": saved_mid_hand,
		"custom_raise_to": custom_raise_to,
		"final_state": final_state,
		"arithmetic": {
			"blinds": 3,
			"action_amounts": action_amounts,
			"ledger": arithmetic_rows,
			"pot_before_payout": running_pot,
			"equation": "3 + sum(%s) = %d" % [JSON.stringify(action_amounts), running_pot],
			"payout": int(last.get("payout", 0)),
			"winners": last.get("winners", []),
			"chips_before": initial_total,
			"chips_after": final_total,
			"conserved": final_total == initial_total,
		},
	}


func _perform_action(app: Control, canvas: Control, action: String) -> bool:
	var index := _surface_action_index(canvas, action)
	return index != MISSING_ACTION_INDEX and bool(app.call("_handle_module_surface_action", action, index, true))


func _surface_action_index(canvas: Control, action: String) -> int:
	for hit_value in (canvas.call("current_view_snapshot") as Dictionary).get("surface_hit_actions", []):
		if typeof(hit_value) == TYPE_DICTIONARY and str((hit_value as Dictionary).get("action", "")) == action:
			return int((hit_value as Dictionary).get("index", -1))
	return MISSING_ACTION_INDEX


func _answer_visible_talk(app: Control) -> void:
	var talk: Dictionary = app.call("current_talk_dock_snapshot")
	if not bool(talk.get("visible", false)):
		return
	var choices: Array = talk.get("choice_ids", []) if typeof(talk.get("choice_ids", [])) == TYPE_ARRAY else []
	if not choices.is_empty():
		app.call("_on_talk_dock_choice_requested", str(talk.get("event_id", "")), str(choices[0]))
		await _settle(2)


func _game_state(app: Control) -> Dictionary:
	var run_state := app.get("run_state") as RunState
	if run_state == null:
		return {}
	var states: Dictionary = run_state.current_environment.get("game_states", {}) if typeof(run_state.current_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	return (states.get(GAME_ID, {}) as Dictionary).duplicate(true) if typeof(states.get(GAME_ID, {})) == TYPE_DICTIONARY else {}


func _save_host_run(app: Control) -> bool:
	var run_state := app.get("run_state") as RunState
	var save_service := app.get("save_service") as SaveService
	if run_state == null or save_service == null:
		return false
	app.call("_prepare_foundation_run_save")
	return save_service.save_run(run_state, str(app.get("autosave_slot_id"))) == OK


func _chip_total(state: Dictionary) -> int:
	var total := int(state.get("player_stack", 0))
	for seat_value in state.get("seats", []):
		total += int((seat_value as Dictionary).get("stack", 0))
	return total


func _hand_signature(hand: Dictionary) -> String:
	var state: Dictionary = hand.get("final_state", {}) if typeof(hand.get("final_state", {})) == TYPE_DICTIONARY else {}
	return _canonical({
		"player_cards": state.get("player_cards", []),
		"community_cards": state.get("community_cards", []),
		"burn_cards": state.get("burn_cards", []),
		"seats": state.get("seats", []),
		"history": state.get("action_history", []),
		"last_result": state.get("last_result", {}),
		"button_index": state.get("button_index", 0),
	})


func _resume_signature(state: Dictionary) -> String:
	return _canonical(_resume_snapshot(state))


func _resume_snapshot(state: Dictionary) -> Dictionary:
	var snapshot := {}
	for key in RESUME_KEYS:
		snapshot[key] = state.get(key)
	return snapshot


func _changed_resume_keys(before: Dictionary, after: Dictionary) -> Array[String]:
	var changed: Array[String] = []
	for key in RESUME_KEYS:
		if _canonical(before.get(key)) != _canonical(after.get(key)):
			changed.append(key)
	return changed


func _state_summary(state: Dictionary) -> Dictionary:
	return {"schema": state.get("schema", ""), "version": state.get("version", 0), "phase": state.get("phase", ""), "hand_number": state.get("hand_number", 0), "session_index": state.get("session_index", 0), "pot": state.get("pot", 0), "members": state.get("members", []), "player_cards": (state.get("player_cards", []) as Array).size(), "history": (state.get("action_history", []) as Array).size()}


func _canonical(value: Variant) -> String:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		var number := float(value)
		return str(int(number)) if is_equal_approx(number, floor(number)) else "%.12f" % number
	if typeof(value) == TYPE_DICTIONARY:
		var source := value as Dictionary
		var keys: Array[String] = []
		for key_value in source.keys():
			keys.append(str(key_value))
		keys.sort()
		var parts: Array[String] = []
		for key in keys:
			parts.append("%s:%s" % [JSON.stringify(key), _canonical(source.get(key))])
		return "{%s}" % ",".join(parts)
	if typeof(value) == TYPE_ARRAY:
		var parts: Array[String] = []
		for item in value as Array:
			parts.append(_canonical(item))
		return "[%s]" % ",".join(parts)
	return JSON.stringify(value)


func _finish_app(app: Control, result: Dictionary) -> Dictionary:
	if app != null:
		app.queue_free()
		await process_frame
	return result


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame
