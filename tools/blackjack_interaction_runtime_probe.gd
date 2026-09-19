extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const AuthorityScript := preload("res://scripts/core/blackjack_action_authority.gd")

const SETTLE_FRAMES := 8
const ACTION_BUDGET_MSEC := 25.0
const SETTLEMENT_BUDGET_MSEC := 200.0

var app: Control
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.set("show_game_library_launcher", true)
	app.set("autosave_slot_id", "blackjack_interaction_runtime_probe")
	root.add_child(app)
	await _settle(SETTLE_FRAMES)
	var opened: Dictionary = app.call("start_game_test_session", "blackjack")
	_check(bool(opened.get("ok", false)), "Blackjack test session did not open: %s" % JSON.stringify(opened))
	await _settle(SETTLE_FRAMES)
	if not failures.is_empty():
		await _finish()
		return

	app.call("_handle_module_surface_action", "blackjack_count_toggle", 0, false, true)
	await _settle(2)
	app.call("_handle_module_surface_action", "blackjack_deal", 0, true)
	await create_timer(2.0).timeout
	await _settle(3)
	var canvas = app.get("game_surface_canvas")
	var before_state: Dictionary = canvas.call("realtime_surface_state")
	_check(bool(before_state.get("can_hit", false)), "Deterministic probe hand cannot hit: %s" % JSON.stringify(before_state.get("player_hands", [])))
	var before_cards := _active_card_count(before_state)
	var started_usec := Time.get_ticks_usec()
	app.call("_handle_module_surface_action", "blackjack_hit", 0, false, true)
	var hit_elapsed_msec := float(Time.get_ticks_usec() - started_usec) / 1000.0
	var after_state: Dictionary = canvas.call("realtime_surface_state")
	var after_cards := _active_card_count(after_state)
	var animation_active := bool(canvas.call("surface_animation_active", "blackjack_deal"))
	_check(after_cards == before_cards + 1, "Hit did not project the new card immediately (%d -> %d)." % [before_cards, after_cards])
	_check(animation_active, "Hit did not start the card-deal animation on the same input boundary.")
	_check(hit_elapsed_msec <= ACTION_BUDGET_MSEC, "Hit blocked the player for %.2f ms (budget %.2f ms)." % [hit_elapsed_msec, ACTION_BUDGET_MSEC])

	# Exercise the real counting settlement route using an authenticated terminal
	# session, including the first reveal click and the second payout click.
	var ledger: Dictionary = app.call("_sealed_action_host_in_place_ledger")
	var session: Dictionary = (ledger.get("session", {}) as Dictionary).duplicate(true)
	var hands: Array = session.get("player_hands", [])
	for hand_value in hands:
		if typeof(hand_value) == TYPE_DICTIONARY:
			(hand_value as Dictionary)["stood"] = true
	session["player_hands"] = hands
	session["counting_enabled"] = true
	session["count_attempted"] = true
	session["presentation_timing_enforced"] = true
	session["deal_animation_id"] = ""
	session["deal_animation_events"] = []
	ledger = AuthorityScript.stage_session_cow(ledger, session)
	_check(bool(app.call("_sealed_action_host_store_in_place_ledger", ledger)), "Could not stage terminal counting session.")
	var preview_started := Time.get_ticks_usec()
	var preview_command: Dictionary = app.call("_sealed_action_host_surface_intent", "blackjack_settle", 0, false, int(session.get("surface_time_msec", Time.get_ticks_msec())))
	app.call("_apply_game_surface_command", preview_command, 0, false, true, true)
	var preview_elapsed_msec := float(Time.get_ticks_usec() - preview_started) / 1000.0
	await _settle(2)
	var preview_ledger: Dictionary = app.call("_sealed_action_host_in_place_ledger")
	var preview_session: Dictionary = preview_ledger.get("session", {})
	_check(bool(preview_session.get("settlement_count_revealed", false)), "First Settle click did not stage the counting reveal. command=%s session=%s" % [JSON.stringify(preview_command), JSON.stringify(preview_session)])
	_check(preview_elapsed_msec <= ACTION_BUDGET_MSEC, "Counting reveal blocked the player for %.2f ms." % preview_elapsed_msec)

	# Resolve every still-live count pulse at its authored time, then press the
	# visible Settle control again through Foundation's production action path.
	var challenge: Dictionary = preview_session.get("count_challenge", {})
	var icons: Array = challenge.get("icons", [])
	var settle_boundary_msec := Time.get_ticks_msec()
	for icon_index in range(icons.size()):
		var icon: Dictionary = icons[icon_index]
		var click_msec := int(icon.get("spawn_msec", 0)) + 1
		settle_boundary_msec = maxi(settle_boundary_msec, click_msec + 1)
		app.call("_sealed_action_host_surface_intent", "blackjack_count_icon", icon_index, false, click_msec)
	var settle_started := Time.get_ticks_usec()
	var defer_enabled: bool = app.get("current_game").call("defers_embedded_action_presentation_refresh", app.get("run_state"), app.get("run_state").current_environment)
	var deferred_before := int(app.get("deferred_embedded_refresh_schedule_count"))
	var settle_command: Dictionary = app.call("_sealed_action_host_surface_intent", "blackjack_settle", 0, false, settle_boundary_msec)
	var settle_intent_msec := float(Time.get_ticks_usec() - settle_started) / 1000.0
	var settle_apply_started := Time.get_ticks_usec()
	app.call("_apply_game_surface_command", settle_command, 0, false, true, true)
	var settle_apply_msec := float(Time.get_ticks_usec() - settle_apply_started) / 1000.0
	var settle_elapsed_msec := float(Time.get_ticks_usec() - settle_started) / 1000.0
	var deferred_after := int(app.get("deferred_embedded_refresh_schedule_count"))
	await _settle(24)
	var final_ledger: Dictionary = app.call("_sealed_action_host_in_place_ledger")
	var final_session: Dictionary = final_ledger.get("session", {})
	_check(not bool(app.get("current_game").call("_has_dealt_hand", final_session)), "Second Settle click left the counted hand active.")
	_check(str(settle_command.get("action_id", "")) == "play_basic", "Second Settle click did not issue the sealed payout action: %s" % JSON.stringify(settle_command))
	_check(settle_elapsed_msec <= SETTLEMENT_BUDGET_MSEC, "Counted settlement blocked the player for %.2f ms." % settle_elapsed_msec)

	print("BLACKJACK_INTERACTION_RUNTIME_METRICS hit_ms=%.2f preview_ms=%.2f settle_ms=%.2f intent_ms=%.2f apply_ms=%.2f defer=%s scheduled=%d" % [hit_elapsed_msec, preview_elapsed_msec, settle_elapsed_msec, settle_intent_msec, settle_apply_msec, str(defer_enabled), deferred_after - deferred_before])
	await _finish()


func _active_card_count(state: Dictionary) -> int:
	var hands: Array = state.get("player_hands", [])
	if hands.is_empty():
		return 0
	var index := clampi(int(state.get("active_hand_index", 0)), 0, hands.size() - 1)
	var hand: Dictionary = hands[index]
	return (hand.get("cards", []) as Array).size()


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	var exit_code := 0
	if failures.is_empty():
		print("BLACKJACK_INTERACTION_RUNTIME_PROBE_PASS")
	else:
		exit_code = 1
		for failure in failures:
			push_error(failure)
	app.queue_free()
	await process_frame
	await process_frame
	quit(exit_code)
