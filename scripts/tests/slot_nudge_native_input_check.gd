extends "res://tools/slot_environment_entry_probe.gd"

# Rendered native regression using the maintained MainScene/input probe helpers.
# Fresh fixture only: production Grand room generation, natural Spin outcomes,
# authentic Foundation sealed host, and normal Save/Continue. No player profile,
# fabricated nudge offer, private-key copy, ledger edits, or result substitution.
#
# Run each phase in a separate maintained native Job, preserving the same isolated
# user-data directory and BTH_SLOT_NUDGE_TEST_ROOT between phases:
#   --produce --mouse   (or --touch, in a different fresh root)
#   --cold --mouse      (or --touch)
#   --verify-settled --mouse (or --touch)
# OS.get_user_data_dir() must be inside the explicitly supplied test root before
# MainScene is instantiated. The script also isolates distribution/profile paths.

const LabelContractScript := preload("res://scripts/tests/slot_nudge_label_contract.gd")
const RendererScript := preload("res://scripts/games/slots/slot_renderer.gd")
const MAX_NATURAL_SPINS := 40
const MAX_PRESENTATION_FRAMES := 720

var test_root := ""
var pointer_kind := "mouse"
var phase_name := ""
var test_slot := ""
var test_seed := "SLOT-COLLECT-NUDGE-NATIVE-01"
var paths_isolated := false
var emitted_actions: Array = []


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	pointer_kind = "touch" if arguments.has("--touch") else "mouse"
	for index in range(arguments.size()):
		var argument := str(arguments[index])
		if argument.begins_with("--storage-key="):
			pointer_kind = argument.trim_prefix("--storage-key=")
		elif argument == "--storage-key" and index + 1 < arguments.size():
			pointer_kind = str(arguments[index + 1])
		elif argument.begins_with("--seed="):
			test_seed = argument.trim_prefix("--seed=")
	if not pointer_kind in ["mouse", "touch"]:
		_fail("Storage key must be mouse or touch.")
	for phase in ["produce", "cold", "verify-settled"]:
		if arguments.has("--%s" % phase):
			if not phase_name.is_empty():
				_fail("Choose exactly one phase.")
			phase_name = phase
	if phase_name.is_empty():
		_fail("A --produce, --cold or --verify-settled phase is required.")
	if not _isolate_paths():
		_finish()
		return
	if not failures.is_empty():
		_finish()
		return
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	test_slot = "slot_nudge_native_%s" % pointer_kind
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", test_slot)
	root.add_child(app)
	await _settle(12)
	if phase_name == "produce":
		await _produce_offer()
	elif phase_name == "cold":
		await _cold_nudge()
	else:
		await _verify_settled()
	_finish()


func _isolate_paths() -> bool:
	test_root = OS.get_environment("BTH_SLOT_NUDGE_TEST_ROOT").strip_edges().replace("\\", "/").trim_suffix("/")
	var user_root := OS.get_user_data_dir().replace("\\", "/").trim_suffix("/")
	if test_root.is_empty() or not test_root.is_absolute_path() or test_root.length() < 12:
		_fail("Set BTH_SLOT_NUDGE_TEST_ROOT to an explicit absolute disposable test directory.")
		return false
	if not user_root.to_lower().begins_with(test_root.to_lower() + "/"):
		_fail("Refusing MainScene/profile access: user data must be inside the disposable test root. user_data=%s test_root=%s" % [user_root, test_root])
		return false
	if DirAccess.make_dir_recursive_absolute(test_root.path_join("distribution")) != OK:
		_fail("Cannot create the disposable distribution directory.")
		return false
	OS.set_environment("BTH_DISTRIBUTION_DATA_ROOT", test_root.path_join("distribution"))
	OS.set_environment("BTH_PROFILE_INVENTORY_PATH", test_root.path_join("profile_inventory.json"))
	OS.set_environment("BTH_USER_SETTINGS_PATH", test_root.path_join("settings.json"))
	OS.set_environment("BTH_DEVELOPER_PLACEMENT_PATH", test_root.path_join("placements.json"))
	OS.set_environment("BTH_DEVELOPER_PLACEMENT_REPORT_PATH", test_root.path_join("placement_report.json"))
	paths_isolated = true
	return true


func _produce_offer() -> void:
	var service: SaveService = app.get("save_service")
	if service == null or service.has_run(test_slot) or FileAccess.file_exists(_receipt_path("offer")):
		_fail("Producer requires a fresh isolated test slot; existing evidence is preserved.")
		return
	if not bool(app.call("start_foundation_run", test_seed, {}, false)):
		_fail("Fresh test run could not start.")
		return
	var run_state: RunState = app.get("run_state")
	# Initial fixture balances, before production room/machine/session creation.
	run_state.bankroll = 1000
	run_state.grand_casino_chips = 13
	var generator: RunGenerator = app.get("generator")
	var installed: Dictionary = generator.environment_test_result(run_state, {
		"archetype_id": RunState.GRAND_CASINO_ARCHETYPE_ID,
		"scenario_id": "__none", "generation_key": "slot_collect_nudge_native",
	})
	if not bool(installed.get("ok", false)):
		_fail("Production Grand fixture generation was rejected: %s" % JSON.stringify(installed.get("errors", [])))
		return
	app.set("current_game", null)
	app.call("_refresh_run_action_service")
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_refresh")
	if not await _enter_slot():
		return
	var initial := _state_receipt()
	_check(bool(initial.get("card_eligible", false)) and not bool(initial.get("cheat_evidence", true)) and int(initial.get("heat", -1)) == 0, "Fresh Grand fixture did not begin with clean Card eligibility at Heat 0.")
	if not failures.is_empty():
		return
	var surface: GameSurfaceCanvas = app.get("game_surface_canvas")
	await _pointer_action(surface, "slot_bet", 0)
	if str(((_machine().get("bet_ladder", {}) as Dictionary).get("selected_id", ""))) != "bet_2":
		_fail("Real rendered bet control did not select the $2 wager.")
		return
	for attempt in range(MAX_NATURAL_SPINS):
		if not await _wait_spin_presentation(surface):
			return
		var before := _state_receipt()
		await _pointer_action(surface, "slot_spin")
		var result: Dictionary = app.get("last_game_result")
		if not _check_committed(result, "spin"):
			return
		var after := _state_receipt()
		_check(int(after.get("spins", 0)) == int(before.get("spins", 0)) + 1, "One real Spin input did not commit exactly once.")
		_check(int(after.get("cash", 0)) == int(before.get("cash", 0)) + int(result.get("bankroll_delta", 0)), "Normal Spin cash accounting changed.")
		_check(int(after.get("chips", -1)) == int(before.get("chips", -2)), "Cash Slot Spin changed Grand chips.")
		_check(not bool(after.get("cheat_evidence", true)), "Normal Spin created Grand cheat evidence.")
		if not failures.is_empty():
			return
		reports.append({"case": "natural_spin", "attempt": attempt + 1, "before": before, "after": after, "result": _public_result(result)})
		if not await _wait_spin_presentation(surface):
			return
		var offer: Dictionary = _machine().get("last_nudge_offer", {})
		if not offer.is_empty() and int(result.get("slot_payout", -1)) == 0 and int(result.get("slot_net", 0)) == -2:
			_assert_offer_labels(surface)
			await _check_enter_inert(surface)
			if failures.is_empty() and await _normal_save():
				_write_receipt("offer", _state_receipt())
				await _capture("offer")
			return
		var active: Dictionary = _machine().get("active_bonus", {})
		if bool(active.get("active", false)) and not bool(active.get("complete", false)):
			_fail("Bounded natural-offer search stopped at a genuine bonus; no offer was fabricated. Preserve this root and choose a fresh test seed/root if another search is needed.")
			return
	_fail("No natural $2 zero-payout loss with a Nudge offer occurred within %d accepted Spins; no offer was fabricated." % MAX_NATURAL_SPINS)


func _cold_nudge() -> void:
	var expected := _read_receipt("offer")
	if expected.is_empty() or not bool(app.call("load_foundation_run")):
		_fail("Cold phase could not load the producer's normal Save.")
		return
	await _settle(12)
	_check(_same_receipt(expected, _state_receipt()), "Cold Continue changed the saved offer/economy/RNG or Grand Card eligibility.")
	if not failures.is_empty() or not await _enter_slot():
		return
	var surface: GameSurfaceCanvas = app.get("game_surface_canvas")
	if not await _wait_spin_presentation(surface):
		return
	_assert_offer_labels(surface)
	await _check_enter_inert(surface)
	if not failures.is_empty():
		return
	var before := _state_receipt()
	await _pointer_action(surface, "slot_nudge")
	var result: Dictionary = app.get("last_game_result")
	if not _check_committed(result, "nudge"):
		return
	var after := _state_receipt()
	_check(str(result.get("action_kind", "")) == "cheat", "Deliberate explicit Nudge lost cheat classification.")
	_check(int(result.get("slot_stake_cost", -1)) == 0, "Offered Nudge charged another wager.")
	_check(int(after.get("spins", 0)) == int(before.get("spins", 0)) + 1, "One real Nudge input did not commit exactly once.")
	_check(int(after.get("cash", 0)) == int(before.get("cash", 0)) + int(result.get("bankroll_delta", 0)), "Deliberate Nudge cash accounting changed.")
	_check(int(after.get("coin_in", -1)) == int(before.get("coin_in", -2)), "Offered Nudge increased coin-in.")
	_check(int(after.get("coin_out", 0)) == int(before.get("coin_out", 0)) + int(result.get("slot_payout", 0)), "Nudge payout and coin-out diverged.")
	_check(int(after.get("chips", -1)) == int(before.get("chips", -2)), "Cash Slot Nudge changed Grand chips.")
	_check(int(result.get("suspicion_delta", 0)) > 0 and int(after.get("heat", 0)) > int(before.get("heat", 0)), "Intentional Nudge did not retain its positive Heat consequence.")
	_check(bool(after.get("cheat_evidence", false)) and not bool(after.get("card_eligible", true)), "Intentional Grand Nudge did not retain cheat evidence and Card closure.")
	reports.append({"case": "cold_deliberate_nudge", "pointer": pointer_kind, "before": before, "after": after, "result": _public_result(result)})
	if not await _wait_spin_presentation(surface):
		return
	if failures.is_empty() and await _normal_save():
		_write_receipt("settled", _state_receipt())
		await _capture("settled")


func _verify_settled() -> void:
	var expected := _read_receipt("settled")
	if expected.is_empty() or not bool(app.call("load_foundation_run")):
		_fail("Settled cold phase could not load the post-Nudge normal Save.")
		return
	await _settle(12)
	var before_enter := _state_receipt()
	_check(_same_receipt(expected, before_enter), "Second cold Continue duplicated payout/wager, changed Heat/RNG, or lost Card closure.")
	if not failures.is_empty() or not await _enter_slot():
		return
	await _settle(12)
	var after_enter := _state_receipt()
	_check(_same_receipt(before_enter, after_enter), "Reentering the cold-restored Slot repeated a settlement.")
	_check(bool(after_enter.get("cheat_evidence", false)) and not bool(after_enter.get("card_eligible", true)), "Cold Continue lost intentional cheat evidence/Card closure.")
	reports.append({"case": "settled_cold_continue", "state": after_enter})
	await _capture("settled_cold")


func _enter_slot() -> bool:
	if app.get("current_game") == null and not bool(app.call("enter_game", "slot", "slot")):
		_fail("Normal Foundation Slot entry was rejected.")
		return false
	await _settle(12)
	var surface: GameSurfaceCanvas = app.get("game_surface_canvas")
	if surface == null or not surface.is_visible_in_tree() or str(app.get("current_screen")) != "GAME":
		_fail("Slot entry did not produce a visible native game surface.")
		return false
	if not surface.surface_action.is_connected(_record_surface_action):
		surface.surface_action.connect(_record_surface_action)
	return true


func _wait_spin_presentation(surface: GameSurfaceCanvas) -> bool:
	for _frame in range(MAX_PRESENTATION_FRAMES):
		if not surface.surface_animation_active("slot_spin") and not bool(app.get("deferred_embedded_refresh_pending")):
			await _settle(3)
			return true
		await process_frame
	_fail("Ordinary Slot presentation did not settle within the bounded native window.")
	return false


func _pointer_action(surface: GameSurfaceCanvas, action: String, index: int = -1) -> void:
	var rect := surface.global_rect_for_surface_action(action, index)
	if not rect.has_area() or surface.surface_action_is_blocked(action):
		_fail("Rendered %s target is missing or blocked." % action)
		return
	emitted_actions.clear()
	_move_viewport_global(rect.get_center())
	await _settle(2)
	if pointer_kind == "touch":
		var press := InputEventScreenTouch.new()
		press.index = 0
		press.pressed = true
		press.position = rect.get_center()
		Input.parse_input_event(press)
		var release := InputEventScreenTouch.new()
		release.index = 0
		release.pressed = false
		release.position = rect.get_center()
		Input.parse_input_event(release)
	else:
		_click_viewport_global(rect.get_center())
	await _settle(10)
	_check(emitted_actions.size() == 1 and str(emitted_actions[0].get("action", "")) == action, "%s %s input did not emit exactly one matching surface action: %s" % [pointer_kind, action, JSON.stringify(emitted_actions)])


func _check_enter_inert(surface: GameSurfaceCanvas) -> void:
	var before := _state_receipt()
	emitted_actions.clear()
	surface.grab_focus()
	var press := InputEventKey.new()
	press.keycode = KEY_ENTER
	press.physical_keycode = KEY_ENTER
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventKey.new()
	release.keycode = KEY_ENTER
	release.physical_keycode = KEY_ENTER
	release.pressed = false
	Input.parse_input_event(release)
	await _settle(3)
	_check(emitted_actions.is_empty() and _same_receipt(before, _state_receipt()), "Enter on focused Slot surface unexpectedly submitted an action or cheat.")


func _assert_offer_labels(surface: GameSurfaceCanvas) -> void:
	var state := surface.realtime_surface_state()
	var bindings: Dictionary = state.get("surface_action_bindings", {})
	_check(str((bindings.get("legal", {}) as Dictionary).get("action", "")) == "slot_spin", "Native legal binding aliases an unexpected action.")
	_check(str((bindings.get("cheat", {}) as Dictionary).get("action", "")) == "slot_nudge", "Native cheat binding no longer identifies Nudge.")
	var recorder = LabelContractScript.RecordingSurface.new()
	var renderer = RendererScript.new()
	var skin: Dictionary = state.get("slot_skin", {})
	renderer.call("_draw_controls", recorder, state, skin, Color.PINK, Color.WHITE, Color.YELLOW)
	var nudge_hits: Array = recorder.hits_for("slot_nudge")
	_check(nudge_hits.size() == 1, "Natural native offer has no unique Nudge control.")
	if nudge_hits.size() == 1:
		var text: String = recorder.text_inside(nudge_hits[0].get("rect", Rect2()))
		_check(text.contains("NUDGE") and text.contains("CHEAT") and not text.contains("COLLECT"), "Natural native offer still mislabels its cheating control: %s" % text)
	renderer.call("_draw_status_panel", recorder, state, skin, Color.PINK, Color.WHITE, Color.YELLOW)
	var all_text: String = recorder.all_text()
	_check(all_text.contains("HEAT") and all_text.contains("CARD") and all_text.contains("CLOSE"), "Native offer does not disclose Heat/Card closure.")
	_check(not surface.global_rect_for_surface_action("slot_collect").has_area(), "Native offer exposes a Collect action alias.")
	reports.append({"case": "native_offer_presentation", "text": all_text, "nudge_rect": _rect_payload(surface.global_rect_for_surface_action("slot_nudge"))})


func _normal_save() -> bool:
	app.call("save_foundation_run")
	await _settle(4)
	var service: SaveService = app.get("save_service")
	if service != null and service.async_save_in_flight():
		service.wait_for_async_save()
	var status: Dictionary = app.call("save_status_snapshot")
	var saved := service != null and service.has_run(test_slot) and str(status.get("status_text", "")).contains("Saved") and int(status.get("autosave_last_error_code", 0)) == 0
	_check(saved, "Normal Save did not acknowledge an isolated loadable slot: %s" % JSON.stringify(status))
	return saved


func _machine() -> Dictionary:
	var run_state: RunState = app.get("run_state")
	if run_state == null:
		return {}
	return SlotMachineStateScript.peek_machine(run_state.current_environment, "slot")


func _state_receipt() -> Dictionary:
	var run_state: RunState = app.get("run_state")
	var machine := _machine()
	if run_state == null or machine.is_empty():
		return {}
	var offer: Dictionary = machine.get("last_nudge_offer", {})
	var status: Dictionary = run_state.demo_objective_status()
	return {
		"cash": run_state.bankroll, "chips": run_state.grand_casino_chips,
		"heat": run_state.suspicion_level(), "rng": str(run_state.rng_state),
		"spins": int(machine.get("spin_count", 0)),
		"coin_in": int(machine.get("coin_in", 0)), "coin_out": int(machine.get("coin_out", 0)),
		"last_payout": int(machine.get("last_payout", 0)), "last_net": int(machine.get("last_net", 0)),
		"classification": str(machine.get("last_classification", "")),
		"offer_type": str(offer.get("type", "")), "offer_event": str(offer.get("event_id", "")),
		"offer_count": int(offer.get("coin_count", 0)), "offer_bank": int(offer.get("banked_payout", 0)),
		"cheat_evidence": bool(run_state.narrative_flags.get("grand_casino_cheat_evidence", false)),
		"card_eligible": bool(status.get("players_card_eligible", false)),
	}


func _check_committed(result: Dictionary, action: String) -> bool:
	var committed := bool(result.get("ok", false)) and str(result.get("action_id", "")) == action and bool(result.get("blackjack_host_committed", false)) and bool(result.get("sealed_action_authoritative", false)) and typeof(result.get("blackjack_host_apply_receipt", null)) == TYPE_DICTIONARY
	_check(committed, "Native %s did not commit through authentic Foundation authority: %s" % [action, JSON.stringify(_public_result(result))])
	return committed


func _public_result(result: Dictionary) -> Dictionary:
	var public: Dictionary = {}
	for key in ["ok", "action_id", "action_kind", "error_code", "message", "bankroll_delta", "suspicion_delta", "slot_stake_cost", "slot_payout", "slot_net", "slot_classification", "slot_nudge_skill_outcome", "blackjack_host_committed", "sealed_action_authoritative"]:
		if result.has(key):
			public[key] = result[key]
	return public


func _record_surface_action(action: String, index: int, confirm_requested: bool) -> void:
	emitted_actions.append({"action": action, "index": index, "confirm_requested": confirm_requested})


func _same_receipt(first: Dictionary, second: Dictionary) -> bool:
	if first.size() != second.size():
		return false
	for key in first:
		# JSON loads numbers as float; compare numeric value rather than serialized
		# token spelling (1000.0 versus 1000). RNG is deliberately a string.
		if not second.has(key) or first[key] != second[key]:
			return false
	return true


func _receipt_path(kind: String) -> String:
	return test_root.path_join("%s-%s.json" % [pointer_kind, kind])


func _write_receipt(kind: String, state: Dictionary) -> void:
	var file := FileAccess.open(_receipt_path(kind), FileAccess.WRITE)
	if file == null:
		_fail("Cannot write the test-owned %s receipt." % kind)
		return
	file.store_string(JSON.stringify(state, "\t"))
	file.flush()


func _read_receipt(kind: String) -> Dictionary:
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(_receipt_path(kind)))
	return payload if typeof(payload) == TYPE_DICTIONARY else {}


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		reports.append({"case": "native_viewport_capture", "skipped": "headless display; renderer labels recorded", "label": label})
		return
	await process_frame
	var image := root.get_texture().get_image()
	if image != null and not image.is_empty():
		var path := test_root.path_join("%s-%s.png" % [pointer_kind, label])
		if image.save_png(path) == OK:
			reports.append({"case": "native_viewport_capture", "path": path})


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _finish() -> void:
	if app != null:
		var service: SaveService = app.get("save_service")
		if service != null and service.async_save_in_flight():
			service.wait_for_async_save()
	var report := {"test": "slot_nudge_native_input_check", "phase": phase_name, "pointer": pointer_kind, "scope": "fresh production-generated native Grand fixture; rendered input and authentic sealed host; original campaign untouched", "passed": failures.is_empty(), "failures": failures, "reports": reports}
	print(JSON.stringify(report))
	if paths_isolated:
		var file := FileAccess.open(test_root.path_join("%s-%s-result.json" % [pointer_kind, phase_name]), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
	quit(0 if failures.is_empty() else 1)
