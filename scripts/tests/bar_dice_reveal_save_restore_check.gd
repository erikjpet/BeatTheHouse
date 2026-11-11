extends SceneTree

# BTH061-BAR-DICE-REVEAL-RESTORE-001. A NEW synthetic Practice cup only.
# MainScene, the real renderer hit regions and normal Menu Save handle the path.
# Default noon is retained; this is not the original overnight/scenario route.
# Warm stops with an UNFUNDED Reveal save. A separate cold process may Lift and
# Call that same cup once; it never replaces a lost cup or repeats a bet.
const MainScene := preload("res://scenes/main.tscn")
const BarDice := preload("res://scripts/games/bar_dice.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const Codec := preload("res://scripts/core/run_save_codec.gd")
const NumericJson := preload("res://scripts/core/storage_numeric_json.gd")
const Runtime := preload("res://scripts/core/game_ritual_runtime.gd")
const SLOT := "bar_dice_reveal_restore"
const SEED := "BTH061-BAR-DICE-REVEAL-RESTORE-001"
var app: Variant
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {"boundaries": [], "first_loss": "", "original_state_used": false}
var actions: Array = []
var blocks: Array = []
var private_root := ""
var stage := ""


func _initialize() -> void:
	stage = OS.get_environment("BTH_BAR_DICE_RESTORE_STAGE")
	private_root = OS.get_environment("BTH_BAR_DICE_RESTORE_PRIVATE_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	if not _private_paths(): _finish(); return
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.set("show_game_library_launcher", true)
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", SLOT)
	_configure_fixture_host()
	root.add_child(app)
	await _frames(8)
	app._settle_script_prewarm_before_runtime()
	if not _check(_inside(ProjectSettings.globalize_path(app.save_service.run_save_path(SLOT))), "Actual SaveService slot is private"):
		await _close(); return
	if stage == "settled": await _settled()
	elif stage == "cold": await _cold()
	else: await _warm()
	await _close()


func _configure_fixture_host() -> void:
	pass


func _warm() -> void:
	if not _check(not FileAccess.file_exists(app.save_service.run_save_path(SLOT)) and not FileAccess.file_exists(_expectation_path()), "Warm case requires unused save and expectation paths"): return
	app.open_game_test_menu()
	await _frames(2)
	if not _check(app.game_test_generation_overrides_text != null, "Supported Practice configuration exists"): return
	app.game_test_seed_input.text = SEED
	app.game_test_bankroll_input.value = 94
	app.game_test_stake_floor_input.value = 6
	app.game_test_stake_ceiling_input.value = 6
	app.game_test_generation_overrides_text.text = JSON.stringify({"environment": {"archetype_id": "bar", "kind": "casino", "economic_profile": {"stake_floor": 6, "stake_ceiling": 6, "game_stake_floor_overrides": {}, "game_stake_ceiling_overrides": {}}}})
	var started: Dictionary = app.start_game_test_session("bar_dice")
	if not _check(bool(started.get("ok", false)), "Supported launcher starts fresh Bar Dice Practice"): return
	await _frames(8)
	# Practice refuses Menu Save. Bootstrap this NEW fixture with the official
	# service, then normal Continue before the first cup input.
	if not _check(app.save_service.save_run(app.run_state, SLOT) == OK, "Official service stores fresh declared Practice fixture"): return
	if not _check(app.load_foundation_run() and app.enter_game("bar_dice"), "Ordinary Continue opens fresh fixture outside Practice Save mode"): return
	await _frames(8)
	_connect_canvas()
	facts["fixture"] = {"seed": SEED, "cash": app.run_state.bankroll, "ante": 6, "raw_ladder": _table(app.run_state.to_dict()).get("stake_ladder", []), "practice": true, "clock_minutes": app.run_state.game_clock_minutes, "clock_input": "unchanged default; no root-clock override supported by Practice JSON", "continuous_clock": false}
	if not _check(app.run_state.bankroll == 94 and _ints(_table(app.run_state.to_dict()).get("stake_ladder", [])) == [6], "Declared cash94 and authored Practice ante6 are active"): return
	if not await _click("bar_dice_roll"): return
	if not await _click("bar_dice_ack_cover"): return
	if not await _idle_tumble(): return
	if not _check(_phase() == "shake" and int(_session().get("shake_number", 0)) == 1, "Opening is the first unfunded Shake"): return
	if not await _save_boundary("shake_control", false): return
	var shake_guard := _guard(app.run_state.to_dict())
	if not _check(app.load_foundation_run(), "Normal Continue loads Shake control"): return
	if not _check(app.enter_game("bar_dice"), "Normal table reentry restores Shake control"): return
	await _frames(8)
	_connect_canvas()
	if not _compare_host(shake_guard, "Shake Continue"): return
	if not await _idle_tumble(): return
	for number in [2, 3]:
		if not await _click("bar_dice_shake"): return
		if not _check(int(_session().get("shake_number", 0)) == number and _phase() == "shake", "One ordinary Shake advances to %d" % number): return
		if not await _idle_tumble(): return
	var before_ritual := _guard(app.run_state.to_dict())
	if not await _click("bar_dice_resolve"): return
	if not _check(_phase() == "throw", "Settle presents Throw"): return
	if not await _click("bar_dice_throw"): return
	if not _check(_phase() == "reveal", "Slam presents Reveal before Lift or Call"): return
	var reveal_guard := _guard(app.run_state.to_dict())
	if not _check(reveal_guard.account == before_ritual.account and reveal_guard.cup.dice == before_ritual.cup.dice, "Settle and Throw preserve wallet/RNG/dice without funding"): return
	# Expectation is written before any official Reveal load/reconciliation. Even
	# a baseline failure therefore leaves its own exact cold input available.
	if not await _save_boundary("reveal", true): return
	facts["completed"] = true
	facts["warm_paid_calls"] = 0


func _cold() -> void:
	# Use the shipped numeric parser. Guard comparisons below also normalize
	# ordinary JSON int/float representations, without changing root RNG strings.
	var expectation: Dictionary = NumericJson.parse(FileAccess.get_file_as_string(_expectation_path()))
	var record: Variant = expectation.get("data") if int(expectation.get("error", FAILED)) == OK else null
	if not _check(record is Dictionary and record.get("task_id", "") == "BTH061-BAR-DICE-REVEAL-RESTORE-001" and record.get("stage", "") == "reveal", "Cold process reads its own prior Reveal expectation"): return
	if not _inspect_saved("cold_reveal", record.get("expected", {})): return
	if not _check(app.load_foundation_run(), "Fresh-process normal Continue succeeds"): return
	if not _check(app.enter_game("bar_dice"), "Fresh-process normal table entry succeeds"): return
	await _frames(8)
	_connect_canvas()
	if not _compare_host(record.get("expected", {}), "Cold Reveal Continue"): return
	if not _check(_phase() == "reveal" and _guard(app.run_state.to_dict()).cup.ante == 6, "Cold restores the same Reveal cup and exact ante6"): return
	var before := _guard(app.run_state.to_dict())
	if not await _click("bar_dice_reveal"): return
	if not _check(_phase() == "call" and _guard(app.run_state.to_dict()).account == before.account, "Ordinary Lift reaches Call without funding or rootRNG change"): return
	if not await _click("bar_dice_ack_call"): return
	var result: Dictionary = app.last_game_result
	if not _check(bool(result.get(Authority.HOST_COMMITTED_KEY, false)), "One final Call commits authenticated result"): return
	var table := _table(app.run_state.to_dict())
	if not _check(int(result.get("bar_dice_stake", -1)) == 6 and int(result.get(Authority.HOST_WAGER_COST_KEY, -1)) == 6, "Call funds exactly the restored six-unit ante"): return
	if not _check(app.run_state.bankroll == 94 + int(result.get("bankroll_delta", 0)) and int(table.get("rounds_played", 0)) == 1, "One natural result conserves wallet and settles exactly one round"): return
	if not _check(_digest(_ints(table.get("last_result", {}).get("player_dice", []))) == before.cup.dice, "Settlement uses the exact saved final dice"): return
	if not _check(_phase() == "settle" and _ledger(app.run_state.to_dict()).get("pending_delivery", {}).is_empty(), "Settled cup has no pending delivery"): return
	if not _check(not _session().has("bar_dice_agreed_ante"), "Settled cup clears its agreed ante before a new wager"): return
	var delivery: Dictionary = result.get(Authority.HOST_DELIVERY_KEY, {})
	if not _check(not delivery.is_empty(), "Committed result retains its exact replay claim"): return
	var settled := _digest(app.run_state.to_dict())
	var settled_guard := _guard(app.run_state.to_dict())
	var replay: Dictionary = app._sealed_action_host_resolve_intent("roll", 6, delivery)
	_check(bool(replay.get("ok", false)) and _digest(app.run_state.to_dict()) == settled and _guard(app.run_state.to_dict()) == settled_guard, "Exact delivery replay is once-only across full run including wallet/RNG/history")
	facts["cold"] = {"paid_call_count": 1, "rounds": int(table.get("rounds_played", 0)), "final_cash": app.run_state.bankroll, "stake": 6}
	facts["post_call_ui"] = {"screen": app.current_screen, "transition_active": app.game_surface_canvas.surface_transition_animation_active(), "popup_visible": app.event_choice_popup_overlay != null and app.event_choice_popup_overlay.visible, "popup_event_id": app.pending_event_choice_popup_event_id, "closing_active": app.run_state.closing_time_active()}
	# The ordinary Menu guard waits for the result's existing finite tumble.
	if not await _idle_tumble(): return
	if not await _save_menu(): return
	var saved: Variant = SaveService.new().load_run(SLOT)
	_check(saved is RunState and _guard(saved.to_dict()) == _guard(app.run_state.to_dict()), "Final official Save preserves the one settled result")
	facts["cold"] = {"paid_call_count": 1, "rounds": int(table.get("rounds_played", 0)), "final_cash": app.run_state.bankroll, "stake": 6}
	facts["completed"] = failures.is_empty()


func _settled() -> void:
	# Read only the outcome already saved by the prior process. Never repeat Call
	# or answer a pending decision to force the result animation/Menu to resume.
	var expectation: Dictionary = NumericJson.parse(FileAccess.get_file_as_string(_expectation_path()))
	var record: Variant = expectation.get("data")
	if not _check(record is Dictionary and record.get("task_id", "") == "BTH061-BAR-DICE-REVEAL-RESTORE-001", "Read-only settled check has its own prior cup expectation"): return
	var loaded: Variant = SaveService.new().load_run(SLOT)
	if not _check(loaded is RunState, "Fresh official service reads prior automatic outcome Save"): return
	var before: Dictionary = _guard(loaded.to_dict())
	var table: Dictionary = _table(loaded.to_dict())
	var ledger: Dictionary = _ledger(loaded.to_dict())
	var expected_cash := int(OS.get_environment("BTH_DICE_EXPECTED_FINAL_CASH"))
	var story_count := 0
	for row_value in loaded.story_log:
		if typeof(row_value) == TYPE_DICTIONARY and str(row_value.get("type", "")) == "game_action" and str(row_value.get("game_id", "")) == "bar_dice":
			story_count += 1
	var binding := RunState.action_authority_table_binding("bar_dice", loaded.current_environment)
	facts["settled"] = {"cash": loaded.bankroll, "expected_cash_from_prior_observation": expected_cash, "rounds": table.get("rounds_played", 0), "phase": before.cup.phase, "game_action_rows": story_count, "request_count": ledger.get("request_order", []).size(), "new_inputs": 0}
	if not _check(loaded.bankroll == expected_cash and int(table.get("rounds_played", 0)) == 1 and story_count == 1, "Automatic Save retains observed wallet and exactly one round/story action"): return
	if not _check(str(before.cup.phase) == "settle" and not bool(before.cup.rolled) and ledger.get("pending_delivery", {}).is_empty() and not ledger.get("session", {}).has("bar_dice_agreed_ante"), "Persisted result has no open cup, agreed ante or pending delivery"): return
	if not _check(_digest(_ints(table.get("last_result", {}).get("player_dice", []))) == str(record.get("expected", {}).get("cup", {}).get("dice", "")), "Durable result uses the exact originally saved Reveal dice"): return
	if not _check(not Authority.validate_persisted_ledger(ledger, binding, loaded.action_authority_checkpoint_fingerprint()).is_empty(), "Durable outcome ledger still binds its exact saved account/root RNG"): return
	if not _check(app.load_foundation_run(), "Read-only normal cold Continue loads committed outcome"): return
	await _frames(8)
	_check(_guard(app.run_state.to_dict()) == before and int(_table(app.run_state.to_dict()).get("rounds_played", 0)) == 1, "Cold Continue does not change wallet/root RNG/cup or settle the result again")
	facts["completed"] = failures.is_empty()


func _save_boundary(label: String, preserve: bool) -> bool:
	var before := _guard(app.run_state.to_dict())
	if not await _save_menu(): return false
	var expected := _guard(app.run_state.to_dict())
	if not _check(before.account == expected.account and before.cup == expected.cup, label + " Menu Save preserves cup, wallets and rootRNG"): return false
	if preserve:
		var file := FileAccess.open(_expectation_path(), FileAccess.WRITE)
		if not _check(file != null, "Private cold expectation opens"): return false
		file.store_string(JSON.stringify({"task_id": "BTH061-BAR-DICE-REVEAL-RESTORE-001", "stage": "reveal", "expected": expected}, "  "))
		file.close()
	var ok := _inspect_saved(label, expected)
	if not ok: return false
	if not preserve:
		app.run_menu_resume_button.pressed.emit()
		await _frames(2)
	return true


func _inspect_saved(label: String, expected: Dictionary) -> bool:
	var boundary := {"label": label, "first_failed_stage": "", "economy": _economy()}
	facts.boundaries.append(boundary)
	var parsed := NumericJson.parse(Codec.preserve_blackjack_ledger_integer_tokens(FileAccess.get_file_as_string(app.save_service.run_save_path(SLOT))))
	if not _gate(int(parsed.get("error", FAILED)) == OK and parsed.get("data") is Dictionary, boundary, "official_envelope_parse"): return false
	var payload: Dictionary = parsed.data
	var storage: Dictionary = payload.get("run_state", {})
	if not _gate(Codec.storage_envelope_valid(storage) and Codec.storage_contents_valid(storage), boundary, "official_storage_validation"): return false
	var encoded := Codec.unpack_from_storage(storage)
	if not _gate(not encoded.is_empty(), boundary, "official_unpack"): return false
	var raw := Codec.decode(encoded)
	if not _gate(raw.has("current_environment") and raw.has("rng_state"), boundary, "official_decode"): return false
	var raw_guard := _guard(raw)
	boundary["raw_ledger_present"] = raw_guard.ledger_present
	boundary["raw_cup_equal"] = _digest(raw_guard.cup) == _digest(expected.cup)
	boundary["raw_account_and_root_rng_equal"] = _digest(raw_guard.account) == _digest(expected.account)
	if not _gate(_digest(raw_guard) == _digest(expected), boundary, "saved_raw_shape_differs_from_live"): return false
	var env: Dictionary = raw.get("current_environment", {})
	var binding := RunState.action_authority_table_binding("bar_dice", env)
	var ledger := _ledger(raw)
	boundary["valid_shape_and_binding"] = not Authority.validate_persisted_ledger(ledger, binding).is_empty()
	var checkpoint := Runtime.canonical_fingerprint({"bankroll": int(raw.get("bankroll", 0)), "grand_casino_chips": int(raw.get("grand_casino_chips", 0)), "rng_seed": int(raw.get("rng_seed", 0)), "rng_state": int(raw.get("rng_state", 0))})
	boundary["checkpoint_matches_raw_root"] = str(ledger.get("checkpoint_fingerprint", "")) == checkpoint
	boundary["valid_with_checkpoint"] = not Authority.validate_persisted_ledger(ledger, binding, checkpoint).is_empty()
	# Raw evidence above is captured before this can invoke RunState.from_dict.
	var fresh := SaveService.new()
	var loaded: Variant = fresh.load_run(SLOT)
	boundary["load_outcome"] = fresh.last_load_outcome.get("status", fresh.last_load_outcome.get("outcome", ""))
	if not _gate(loaded is RunState, boundary, "official_load_run"): return false
	var loaded_guard := _guard(loaded.to_dict())
	boundary["loaded_ledger_present"] = loaded_guard.ledger_present
	boundary["loaded_cup_equal"] = loaded_guard.cup == raw_guard.cup
	boundary["loaded_account_and_root_rng_equal"] = loaded_guard.account == raw_guard.account
	boundary["loaded_ledger_exact"] = loaded_guard.ledger == raw_guard.ledger
	if not _gate(bool(boundary.valid_shape_and_binding), boundary, "persisted_ledger_shape_or_binding_validation"): return false
	if not _gate(bool(boundary.valid_with_checkpoint), boundary, "persisted_ledger_checkpoint_validation"): return false
	return _gate(loaded_guard == raw_guard, boundary, "RunState_restore_changed_saved_shape")


func _compare_host(expected: Dictionary, label: String) -> bool:
	var current := _guard(app.run_state.to_dict())
	var ok: bool = _digest(current.account) == _digest(expected.account) and _digest(current.cup) == _digest(expected.cup)
	facts[label] = {"cup_equal": _digest(current.cup) == _digest(expected.cup), "account_and_root_rng_equal": _digest(current.account) == _digest(expected.account), "phase": _phase(), "economy": _economy()}
	if not ok and str(facts.first_loss).is_empty(): facts.first_loss = label + ":Host_reentry_projection"
	return _check(ok, label + " retains exact cup/ante/phase/dice and account/rootRNG")


func _guard(data: Dictionary) -> Dictionary:
	var table := _table(data)
	var ledger := _ledger(data)
	var session: Dictionary = ledger.get("session", {})
	var ladder: Array = table.get("stake_ladder", [])
	var index := int(session.get("selected_stake_index", table.get("selected_stake_index", 0)))
	return {"account": {"cash": int(data.get("bankroll", 0)), "chips": int(data.get("grand_casino_chips", 0)), "heat": _digest(data.get("suspicion", {})), "root_rng": _digest([str(int(data.get("rng_seed", 0))), str(int(data.get("rng_state", 0)))])}, "cup": {"table": _digest(table.get("table_key", "")), "rounds": int(table.get("rounds_played", 0)), "phase": str(session.get("bar_dice_ritual_phase", "")), "rolled": bool(session.get("rolled", false)), "shake": int(session.get("shake_number", 0)), "ante": int(ladder[index]) if index >= 0 and index < ladder.size() else -1, "dice": _digest(_ints(session.get("dice", []))), "dice_count": _ints(session.get("dice", [])).size(), "reroll": _digest(_ints(session.get("reroll", []))), "last_rerolled": _digest(_ints(session.get("last_rerolled", []))), "pending_action": str(session.get("bar_dice_pending_action_id", ""))}, "ledger_present": not ledger.is_empty(), "ledger": _digest(ledger)}


func _table(data: Dictionary) -> Dictionary:
	return data.get("current_environment", {}).get("game_states", {}).get("bar_dice", {})


func _ledger(data: Dictionary) -> Dictionary:
	return _table(data).get(Authority.LEDGER_KEY, {})


func _session() -> Dictionary:
	return _ledger(app.run_state.to_dict()).get("session", {})


func _phase() -> String:
	return str(_session().get("bar_dice_ritual_phase", ""))


func _economy() -> Dictionary:
	if app == null or app.run_state == null:
		return {"state": "before_normal_Continue"}
	var environment: Dictionary = app.run_state.current_environment
	var economy: Dictionary = environment.get("economic_profile", {})
	return {"floor": economy.get("stake_floor", -1), "ceiling": economy.get("stake_ceiling", -1), "game_floor": economy.get("game_stake_floor_overrides", {}).get("bar_dice", -1), "game_ceiling": economy.get("game_stake_ceiling_overrides", {}).get("bar_dice", -1), "ante_block_reason": app.current_game._ante_block_reason(_table(app.run_state.to_dict()), _session(), app.run_state, environment) if app.current_game != null else "not_in_game", "clock_minutes": app.run_state.game_clock_minutes, "scenario_id": environment.get("scenario_id", "")}


func _click(action: String) -> bool:
	await _frames(3)
	var canvas: Variant = app.game_surface_canvas
	var chosen: Dictionary = {}
	for region in canvas.hit_regions:
		var bound: Dictionary = canvas._resolved_surface_action_binding(str(region.get("action", "")), int(region.get("index", -1)))
		if str(bound.get("action", "")) == action: chosen = region; break
	if not _check(not chosen.is_empty(), "Renderer publishes " + action): return false
	var count := actions.size()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = canvas._board_to_screen((chosen.get("rect", Rect2()) as Rect2).get_center())
	canvas._gui_input(event)
	await _frames(3)
	return _check(actions.size() == count + 1 and str(actions[-1]) == action and blocks.is_empty(), "One drawn input reaches ordinary Host: " + action)


func _connect_canvas() -> void:
	var canvas: Variant = app.game_surface_canvas
	if not canvas.surface_action.is_connected(_record_action): canvas.surface_action.connect(_record_action)
	if not canvas.surface_action_blocked.is_connected(_record_block): canvas.surface_action_blocked.connect(_record_block)


func _record_action(action: String, _index: int, _confirmed: bool) -> void:
	actions.append(action)


func _record_block(action: String, reason: String) -> void:
	blocks.append({"action": action, "reason": reason})


func _idle_tumble() -> bool:
	if not await _dismiss_event_popup_before_tumble(): return false
	var before: Dictionary = _guard(app.run_state.to_dict()).account
	await create_timer(float(BarDice.TUMBLE_DURATION_MSEC + 150) / 1000.0).timeout
	await _frames(2)
	var account_after: Dictionary = _guard(app.run_state.to_dict()).account
	var idle: bool = not app.game_surface_canvas.surface_animation_active(BarDice.TUMBLE_CHANNEL)
	var popup_buttons: Array = []
	if app.event_choice_popup_choices_list != null:
		_collect_visible_popup_buttons(app.event_choice_popup_choices_list, popup_buttons)
	if not facts.has("tumble_observations"): facts["tumble_observations"] = []
	facts.tumble_observations.append({"account_before": before, "account_after": account_after, "animation_idle": idle, "popup_visible": app._event_choice_popup_is_visible(), "popup_title": app.event_choice_popup_title_label.text if app.event_choice_popup_title_label != null else "", "popup_buttons": popup_buttons, "pause": app.game_surface_canvas.debug_pause_contract_snapshot()})
	var account_ok := _check(account_after == before, "Passive tumble preserves account and root RNG")
	var animation_ok := _check(idle, "Passive tumble animation ends")
	return account_ok and animation_ok


func _dismiss_event_popup_before_tumble() -> bool:
	if not app._event_choice_popup_is_visible(): return true
	var before: Dictionary = _guard(app.run_state.to_dict()).account
	if not _check(app.pending_event_choice_popup_event_id == "health_inspector", "Observed modal is the expected Health Inspector event"): return false
	var button := _find_inspector_finish_button(app.event_choice_popup_choices_list)
	if not _check(button != null and button.text == "One last move", "Real enabled no-payment inspector response is available"): return false
	button.pressed.emit()
	for frame in range(120):
		await process_frame
		if not app._event_choice_popup_is_visible() and app._event_response_transaction.is_empty(): break
	var after: Dictionary = _guard(app.run_state.to_dict()).account
	if not facts.has("tumble_popup_dismissals"): facts["tumble_popup_dismissals"] = []
	facts.tumble_popup_dismissals.append({"event":"health_inspector","choice":"finish_one","control":"One last move","account_before":before,"account_after":after,"popup_closed":not app._event_choice_popup_is_visible()})
	if not _check(not app._event_choice_popup_is_visible(), "Normal inspector response closes its popup before passive wait"): return false
	return _check(int(before.cash) == int(after.cash) and int(before.chips) == int(after.chips), "No-payment inspector response preserves both wallets")


func _find_inspector_finish_button(node: Node) -> Button:
	if node is Button and (node as Button).is_visible_in_tree() and not (node as Button).disabled 			and str(node.get_meta("event_id", "")) == "health_inspector" and str(node.get_meta("choice_id", "")) == "finish_one":
		return node as Button
	for child in node.get_children():
		var found := _find_inspector_finish_button(child)
		if found != null: return found
	return null


func _collect_visible_popup_buttons(node: Node, buttons: Array) -> void:
	if node is Button and (node as Button).is_visible_in_tree():
		buttons.append({"text": (node as Button).text, "disabled": (node as Button).disabled})
	for child in node.get_children():
		_collect_visible_popup_buttons(child, buttons)


func _save_menu() -> bool:
	app.top_menu_button.pressed.emit()
	await _frames(2)
	if not _check(app._run_menu_is_visible(), "Normal Menu opens"): return false
	app.run_menu_save_button.pressed.emit()
	var error: int = app.save_service.wait_for_async_save()
	await _frames(2)
	return _check(error == OK and bool(app.save_service.last_save_outcome.get("ok", false)) and not app._run_menu_is_visible(), "Normal Menu Save accepts and closes with official success")


func _digest(value: Variant) -> String:
	# Normalize ordinary JSON int/float representations. Root RNG is compared as
	# exact decimal strings separately in _guard, before this normalization.
	return Runtime.canonical_fingerprint(JSON.parse_string(JSON.stringify(value))).sha256_text()


func _ints(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value: result.append(int(item))
	return result


func _gate(ok: bool, boundary: Dictionary, label: String) -> bool:
	if not ok:
		boundary.first_failed_stage = label
		if str(facts.first_loss).is_empty(): facts.first_loss = str(boundary.label) + ":" + label
	return _check(ok, str(boundary.label) + ":" + label)


func _inside(path: String) -> bool:
	var normalized := path.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()
	return normalized == private_root.to_lower() or normalized.begins_with(private_root.to_lower() + "/")


func _expectation_path() -> String:
	return private_root.path_join("bar-dice-reveal-expectation.json")


func _private_paths() -> bool:
	if not _check(stage in ["warm", "cold", "settled"] and private_root.is_absolute_path() and "native-private-" in private_root and not OS.has_feature("web"), "Explicit private native root and warm/cold/settled stage required"): return false
	if not _check(_inside(ProjectSettings.globalize_path("user://")), "Actual user:// is private before Host/services"): return false
	for key in ["APPDATA", "LOCALAPPDATA", "USERPROFILE", "BTH_WORLD_REENTRY_ROOT", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH"]:
		var path := OS.get_environment(key)
		if not _check(not path.is_empty() and _inside(ProjectSettings.globalize_path(path)), "Private containment: " + key): return false
	for key in ["BTH_TARGET_OUTPUT", "BTH_DEVELOPER_PLACEMENT_PATH", "BTH_DEVELOPER_PLACEMENT_REPORT_PATH"]:
		var path := OS.get_environment(key)
		if not _check(path.is_empty() or _inside(ProjectSettings.globalize_path(path)), "Private optional output containment: " + key): return false
	return _check(OS.get_environment("BTH_PROJECT_PLACEMENT_PATH").is_empty() and OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "Shipped placement; no original save/profile inputs")


func _frames(count: int) -> void:
	for frame in range(count): await process_frame


func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label); push_error(label)
	return ok


func _close() -> void:
	if app != null:
		app.save_service.wait_for_async_save()
		app.queue_free()
		await _frames(2)
	_finish()


func _finish() -> void:
	facts["source_sha256"] = {"game": FileAccess.get_sha256("res://scripts/games/bar_dice.gd"), "fixture": FileAccess.get_sha256(get_script().resource_path), "base": FileAccess.get_sha256("res://scripts/tests/bar_dice_reveal_save_restore_check.gd")}
	facts["scope"] = "NEW synthetic Practice94/ante6/default-noon; native MainScene/renderer GUI injection. Not original storage, normal travel, overnight closure, Web or OS pointer evidence. Warm leaves unfunded Reveal; separate cold may finish once."
	facts["stage"] = stage
	facts["actions"] = actions
	facts["blocked"] = blocks
	var result := {"checks": checks, "failures": failures, "facts": facts}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty() and not private_root.is_empty() and _inside(output):
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result, "  ")); file.close()
	print("BAR_DICE_REVEAL_SAVE_RESTORE_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
