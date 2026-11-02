extends SceneTree

# BTH-32 production-host branch regression. This instantiates the exact shipped
# Main scene: no host subclass, overridden clock, altered deadline, RNG/outcome
# override, captured profile, or production instrumentation. Host processing is
# disabled so Auto can run only at the explicitly bounded callbacks below.
const MainScene := preload("res://scenes/main.tscn")
const State := preload("res://scripts/games/slots/slot_machine_state.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const DUE_TIMEOUT_MSEC := 10000

var app
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {"host_script": "", "fixtures": [], "explicit_auto_ticks": 0,
	"explicit_confirm_inputs": 0, "paid_prepared_candidate_was_live_run": false,
	"production_instrumentation_added": false, "profiles_or_keys_imported": false,
	"fidelity": "exact production MainScene; natural finite host clock; bounded native callbacks; unchanged RNG/resolver"}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _private_roots():
		_finish(); return
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.autosave_slot_id = "bth32_actual_host_runtime"
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	await _frames(2)
	facts["host_script"] = app.get_script().resource_path
	if not _check(facts["host_script"] == "res://scripts/ui/foundation_main.gd", "exact production FoundationMain script instantiated"):
		await _cleanup(); _finish(); return
	if not _check(app._ensure_run_ui_built(), "actual host builds its normal run UI"):
		await _cleanup(); _finish(); return
	app._ensure_full_content_library_loaded()
	await _warm_in_place()
	await _all_in_cancel()
	await _all_in_accept_once()
	await _cleanup()
	_finish()

func _fixture(label: String, bankroll: int) -> bool:
	# Reuse the canonical default practice seed used by the previously observed
	# ClockHost 35 -> 15 loss. Record the actual seed instead of inferring which
	# optional Game Library widgets have been built.
	var started: Dictionary = app.start_game_test_session("slot")
	if not _check(bool(started.get("ok", false)), label + ": canonical no-scenario Slot session starts"): return false
	app.set_process(false)
	if not _check(app.run_state != null, label + ": session publishes RunState"): return false
	app.run_state.bankroll = bankroll
	app._sync_presented_bankroll_to_actual()
	app._refresh()
	app._on_game_surface_action("slot_bet", 4, false)
	await _frames(2)
	_check(_bet() == 20 and _pending().is_empty(), label + ": MAX selection stages $20 without pending wager")
	var eligible: bool = app._sealed_action_host_can_commit_in_place("spin")
	var identity: bool = app._sealed_action_host_transaction_candidate("spin") == app.run_state
	(facts["fixtures"] as Array).append({"label": label, "seed_text": app.run_state.seed_text,
		"initial_bankroll": bankroll, "host_script": app.get_script().resource_path,
		"in_place_eligible": eligible, "transaction_candidate_is_live_run": identity})
	return _check(eligible and identity, label + ": production gate and actual candidate factory choose the live in-place RunState")

func _arm_auto() -> bool:
	var before := _money_guard()
	app._on_game_surface_action("slot_auto_toggle", 0, false)
	return _check(bool(_machine().get("slot_autoplay_active", false)) and _money_guard() == before,
		"actual-host Auto toggle arms without charging or resolving")

func _wait_due() -> bool:
	app._sync_simulation_pause_owners()
	var deadline := Time.get_ticks_msec() + DUE_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		if app.run_state == null or app.current_game == null:
			return _check(false, "actual-host session remains present while waiting for its natural Auto deadline")
		if app._sealed_action_host_needs_auto_tick(app._environment_simulation_time_msec()):
			return _check(not app.is_processing() and not app._simulation_progression_paused(),
				"natural Auto deadline arrives with host processing disabled and no modal pause")
		await create_timer(0.05).timeout
	return _check(false, "natural Auto deadline arrives within ten seconds")

func _tick(observe_prepared: bool = false) -> bool:
	if not (await _wait_due()): return false
	facts["explicit_auto_ticks"] = int(facts["explicit_auto_ticks"]) + 1
	if observe_prepared:
		# Match the normal automation call stack while retaining its returned
		# command long enough to observe the existing candidate identity.
		var now: int = app._environment_simulation_time_msec()
		var ui_state: Dictionary = app._current_game_surface_auto_tick_state()
		var command: Dictionary = app._sealed_action_host_auto_intent(now)
		var prepared: Dictionary = command.get("_sealed_action_host_prepared", {})
		var live_candidate: bool = prepared.get("candidate") == app.run_state
		facts["paid_prepared_candidate_was_live_run"] = live_candidate
		_check(live_candidate and not prepared.is_empty(), "paid Auto returned the exact live RunState in its prepared command, observing the in-place branch")
		app._apply_game_surface_automation_command(command, ui_state)
	else:
		app._advance_game_surface_automation()
	await _frames(3)
	return _check(app.run_state != null, "explicit actual-host Auto callback retains RunState")

func _warm_in_place() -> void:
	if not (await _fixture("warm", 35)) or not _arm_auto(): return
	var before := _machine()
	if not (await _tick(true)): return
	var settled := _machine()
	facts["warm_transition"] = {"seed_text": app.run_state.seed_text, "bankroll": app.run_state.bankroll,
		"coin_in": settled.get("coin_in", 0), "last_stake_cost": settled.get("last_stake_cost", 0),
		"payout": settled.get("last_payout", 0), "spin_count": settled.get("spin_count", 0)}
	if not _check(int(settled.get("spin_count", 0)) == int(before.get("spin_count", 0)) + 1
		and int(settled.get("coin_in", 0)) == int(before.get("coin_in", 0)) + 20
		and app.run_state.bankroll > 0 and app.run_state.bankroll < 20 and not State.active_bonus_incomplete(settled),
		"one unchanged-RNG production in-place Auto spin reaches positive cash below the selected bet"):
		return
	var guard := _money_guard()
	if not (await _tick()): return
	_check(_money_guard() == guard, "in-place low-funds tick has no additional debit, RNG, clock or result")
	_check(not bool(_machine().get("slot_autoplay_active", false)) and _pending().is_empty(),
		"in-place low-funds stop pauses Auto without stranded delivery")
	_check(not bool(app.current_event_choice_popup_snapshot().get("visible", false)) and _bet() == 20,
		"in-place unaffordable stop preserves MAX without an unaffordable approval")
	app._on_game_surface_action("slot_bet", 0, false)
	_check(_bet() == 2 and _money_guard() == guard, "actual in-place stop immediately permits a smaller bet without debit")
	app.back_to_environment()
	await _frames(2)
	_check(app.current_game == null and app.pending_wager_confirm_action_id.is_empty()
		and not bool(app.current_event_choice_popup_snapshot().get("visible", false)) and _money_guard() == guard,
		"actual-host exit cannot reveal a delayed decision or place a wager")

func _open_all_in(label: String) -> bool:
	if not (await _fixture(label, 20)) or not _arm_auto(): return false
	var before := _money_guard()
	if not (await _tick()): return false
	var popup: Dictionary = app.current_event_choice_popup_snapshot()
	_check(_money_guard() == before and _pending().is_empty(), label + ": in-place all-in decision has no debit or durable pending delivery")
	_check(not bool(_machine().get("slot_autoplay_active", false)), label + ": in-place Auto pauses before the decision")
	_check(int(popup.get("stake", -1)) == 20 and int(popup.get("wager_cost", -1)) == 20, label + ": exact $20 wager is displayed")
	_check(app.event_choice_popup_overlay.is_visible_in_tree() and app.game_surface_canvas.is_visible_in_tree()
		and app.event_choice_popup_overlay.get_index() > app.run_screen.get_index(), label + ": prompt is visibly above the active slot")
	_check(app._modal_contract_blocks_player_input(), label + ": prompt owns input")
	return _check(bool(popup.get("visible", false)) and str(popup.get("popup_type", "")) == "wager_confirmation",
		label + ": production in-place Auto opens the confirmation immediately")

func _all_in_cancel() -> void:
	if not (await _open_all_in("cancel")): return
	var before := _money_guard()
	app.cancel_pending_wager_confirmation()
	app._on_game_surface_action("slot_bet", 0, false)
	_check(_bet() == 2 and _money_guard() == before and _pending().is_empty(), "actual-host cancel releases bet selection with no charge")
	app.back_to_environment()
	await _frames(2)
	_check(app.current_game == null and app.pending_wager_confirm_action_id.is_empty() and _money_guard() == before,
		"actual-host cancel/exit clears pending intent without a wager")

func _all_in_accept_once() -> void:
	if not (await _open_all_in("accept")): return
	var before := _machine()
	var bankroll: int = app.run_state.bankroll
	facts["explicit_confirm_inputs"] = int(facts["explicit_confirm_inputs"]) + 1
	app.confirm_pending_wager_action()
	await _frames(3)
	if not _check(app.run_state != null, "actual-host acceptance retains its result RunState"): return
	var after := _machine()
	_check(int(after.get("spin_count", 0)) == int(before.get("spin_count", 0)) + 1
		and int(after.get("coin_in", 0)) == int(before.get("coin_in", 0)) + 20
		and int(after.get("last_stake_cost", 0)) == 20, "actual-host acceptance places the displayed stake exactly once")
	_check(app.run_state.bankroll == bankroll + int(after.get("last_net", 0)) and _pending().is_empty(),
		"actual-host accepted wallet matches settled result and clears pending delivery")
	var settled := _money_guard()
	app.confirm_pending_wager_action()
	_check(_money_guard() == settled and not bool(_machine().get("slot_autoplay_active", false)),
		"actual-host repeated approval cannot charge twice or restart Auto")
	facts["accepted"] = {"bankroll_after": app.run_state.bankroll, "coin_in_before": before.get("coin_in", 0),
		"coin_in_after": after.get("coin_in", 0), "spin_count_after": after.get("spin_count", 0)}

func _state_key() -> String:
	return str(app.current_game_state_key) if not str(app.current_game_state_key).is_empty() else "slot"

func _machine() -> Dictionary:
	if app == null or app.run_state == null: return {}
	return State.read_machine(app.run_state.current_environment, _state_key())

func _bet() -> int:
	return int(State.selected_bet(_machine()).get("total_credits", 0))

func _pending() -> Dictionary:
	var ledger: Dictionary = _machine().get(Authority.LEDGER_KEY, {})
	return ledger.get("pending_delivery", {})

func _money_guard() -> Array:
	if app == null or app.run_state == null: return ["missing_run_state"]
	var machine := _machine()
	return [app.run_state.bankroll, app.run_state.grand_casino_chips, app.run_state.rng_state,
		app.run_state.game_clock_minutes, app.run_state.simulation_msec,
		int(machine.get("coin_in", 0)), int(machine.get("coin_out", 0)), int(machine.get("spin_count", 0))]

func _private_roots() -> bool:
	var private_root := OS.get_environment("BTH32_PRIVATE_ROOT").replace("\\", "/").simplify_path().trim_suffix("/").to_lower()
	if not _check(private_root.is_absolute_path() and private_root.contains("/native-private-bth32-"), "fresh BTH32 private root required"): return false
	for key in ["APPDATA", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH", "BTH_TARGET_OUTPUT"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path().to_lower()
		if not _check(path == private_root or path.begins_with(private_root + "/"), "private containment for " + key): return false
	var user_path := ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path().to_lower()
	if not _check(user_path.begins_with(private_root + "/"), "Godot user namespace is private before host creation"): return false
	return _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "no imported captured profile")

func _frames(count: int) -> void:
	for _i in range(count): await process_frame

func _cleanup() -> void:
	if is_instance_valid(app):
		app.set_process(false)
		if app.save_service != null: app.save_service.wait_for_async_save()
		if app.get_parent() != null: app.get_parent().remove_child(app)
		app.free()
	await process_frame

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok

func _finish() -> void:
	var report := {"checks": checks, "failures": failures, "facts": facts}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if output.is_absolute_path() and output.replace("\\", "/").to_lower().contains("/native-private-bth32-"):
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "\t"))
	print("BTH32_ACTUAL_HOST_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
