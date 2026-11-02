extends SceneTree

# BTH-32 synthetic native regression. All persistence must be inside a fresh
# task-private root. Host processing is disabled; each Auto tick is explicit and
# bounded. This is not a live profile, OS-pointer, or browser acceptance test.
const Foundation := preload("res://scripts/ui/foundation_main.gd")
const State := preload("res://scripts/games/slots/slot_machine_state.gd")
const Saves := preload("res://scripts/core/save_service.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const PENDING_SLOT := "bth32_pending_no_wager"
const SETTLED_SLOT := "bth32_accepted_once"

class ClockHost extends Foundation:
	var test_msec := 100000
	func _environment_simulation_time_msec() -> int:
		return test_msec

var app: ClockHost
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {"explicit_auto_ticks": 0, "explicit_background_passes": 0, "explicit_confirm_inputs": 0,
	"fixtures": [], "captured_profiles_or_keys": false, "fidelity": "synthetic native host callbacks; controlled presentation clock; unchanged Slot RNG/resolver"}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _private_roots():
		_finish(); return
	root.size = Vector2i(1280, 720)
	app = ClockHost.new()
	app.autosave_slot_id = "bth32_runtime"
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	await _frames(2)
	if not _check(app._ensure_run_ui_built(), "real Foundation run UI builds"):
		await _cleanup(); _finish(); return
	app._ensure_full_content_library_loaded()
	var mode := OS.get_environment("BTH32_MODE")
	if mode == "cold":
		await _cold()
	elif mode == "save_warm":
		await _pending_save()
		await _accept_once()
	else:
		_check(mode in ["", "warm"], "mode is warm or cold")
		await _warm_transition()
		await _unaffordable()
		await _background_unaffordable()
		await _cancel_and_exit()
		await _stale_inputs()
		await _pending_save()
		await _accept_once()
	facts["mode"] = "warm" if mode.is_empty() else mode
	await _cleanup()
	_finish()

func _fixture(label: String, bankroll: int, normal_run: bool = false) -> bool:
	app.test_msec += 100000
	if normal_run:
		# Practice sessions deliberately disable the normal Save UI and their
		# synthetic room is not a normal Continue target. Use the real generated
		# Bar for persistence cases, through the supported custom start input.
		# The room's authored game pool is sampled by seed. This normal Bar seed
		# has already been observed to contain Slot in the legacy native fixture.
		var seed := "BTH32-LEGACY-below"
		var challenge := RunState.custom_challenge("bth32_persistence", seed, {"home_archetype_id": "bar"})
		if not _check(app.start_foundation_run(seed, challenge, false), label + ": canonical generated Bar run starts"):
			return false
		if not _check(app.run_state != null and app.run_state.current_environment.get("game_ids", []).has("slot"), label + ": generated room contains a normal Slot object"):
			return false
		if not _check(app.enter_game("slot"), label + ": normal generated Slot opens"):
			return false
	else:
		if app.game_test_seed_input != null:
			app.game_test_seed_input.text = "BTH32-" + label
		var started := app.start_game_test_session("slot")
		if not _check(bool(started.get("ok", false)), label + ": canonical Slot practice session starts"):
			return false
	app.set_process(false)
	(facts["fixtures"] as Array).append({"label": label, "seed_text": app.run_state.seed_text,
		"normal_run": normal_run, "initial_bankroll": bankroll})
	app.run_state.bankroll = bankroll
	app._sync_presented_bankroll_to_actual()
	app._refresh()
	app._on_game_surface_action("slot_bet", 4, false)
	await _frames(2)
	return _check(_bet() == 20 and _pending_delivery().is_empty(), label + ": normal MAX selector stages $20 with no pending wager")

func _toggle_auto() -> bool:
	var before := _money_guard()
	app._on_game_surface_action("slot_auto_toggle", 0, false)
	return _check(bool(_machine().get("slot_autoplay_active", false)) and _money_guard() == before,
		"Auto toggle arms the production machine without spending cash, RNG, clock or stake")

func _auto_tick() -> void:
	app.test_msec += 100000
	facts["explicit_auto_ticks"] = int(facts["explicit_auto_ticks"]) + 1
	app._advance_game_surface_automation()
	await _frames(2)

func _open_all_in(label: String, normal_run: bool = false) -> bool:
	if not (await _fixture(label, 20, normal_run)) or not _toggle_auto():
		return false
	var before := _money_guard()
	await _auto_tick()
	var popup := app.current_event_choice_popup_snapshot()
	_check(_money_guard() == before, label + ": reaching all-in confirmation places no wager")
	_check(not bool(_machine().get("slot_autoplay_active", false)), label + ": Auto pauses before confirmation")
	_check(_pending_delivery().is_empty(), label + ": popup has no durable sealed pending delivery")
	_check(int(popup.get("stake", -1)) == 20 and int(popup.get("wager_cost", -1)) == 20,
		label + ": popup states the exact selected wager")
	var overlay: Control = app.event_choice_popup_overlay
	var surface: Control = app.game_surface_canvas
	_check(overlay != null and overlay.is_visible_in_tree() and surface != null and surface.is_visible_in_tree()
		and overlay.get_global_rect().intersects(surface.get_global_rect()), label + ": confirmation is actually visible over the active Slot surface")
	_check(overlay != null and overlay.get_index() > app.run_screen.get_index(), label + ": confirmation draws above the run surface")
	_check(app._modal_contract_blocks_player_input(), label + ": confirmation owns player input")
	var owner: Control = root.gui_get_focus_owner()
	_check(owner != null and overlay != null and overlay.is_ancestor_of(owner), label + ": keyboard focus belongs to confirmation")
	return _check(bool(popup.get("visible", false)) and str(popup.get("popup_type", "")) == "wager_confirmation",
		label + ": all-in prompt is immediate while the slot remains active")

func _warm_transition() -> void:
	# One genuine seeded paid Auto spin must leave a positive remainder below the
	# unchanged selected wager. No outcome or RNG override manufactures this loss.
	if not (await _fixture("WARM-TRANSITION", 35)) or not _toggle_auto(): return
	var count := int(_machine().get("spin_count", 0))
	await _auto_tick()
	var first := _machine()
	facts["warm_transition"] = {"seed_text": app.run_state.seed_text, "bankroll": app.run_state.bankroll, "last_stake_cost": first.get("last_stake_cost"),
		"last_payout": first.get("last_payout"), "active_bonus": first.get("active_bonus", {}), "spin_count": first.get("spin_count")}
	if not _check(int(first.get("spin_count", 0)) == count + 1 and app.run_state.bankroll > 0
		and app.run_state.bankroll < 20 and not State.active_bonus_incomplete(first),
		"one bounded unchanged-RNG Auto spin reaches the warm low-funds transition"):
		return
	var before := _money_guard()
	await _auto_tick()
	_check(_money_guard() == before, "next warm low-funds Auto tick has no debit or RNG advance")
	_check(not bool(_machine().get("slot_autoplay_active", false)) and _pending_delivery().is_empty(),
		"warm low-funds stop releases Auto and its pending delivery")
	_check(_bet() == 20, "warm low-funds stop preserves the player's MAX bet choice")
	app._on_game_surface_action("slot_bet", 0, false)
	_check(_bet() == 2, "warm low-funds stop immediately accepts a smaller bet")

func _unaffordable() -> void:
	for bankroll in [19, 10, 1]:
		if not (await _fixture("BELOW-%d" % bankroll, bankroll)) or not _toggle_auto(): continue
		var before := _money_guard()
		await _auto_tick()
		_check(_money_guard() == before, "cash %d below selected wager stops without debit or RNG" % bankroll)
		_check(not bool(_machine().get("slot_autoplay_active", false)) and _pending_delivery().is_empty(),
			"cash %d stops Auto without stranding a sealed action" % bankroll)
		_check(not bool(app.current_event_choice_popup_snapshot().get("visible", false)),
			"cash %d does not offer to confirm an unaffordable wager" % bankroll)
		_check(_bet() == 20, "cash %d preserves the selected bet" % bankroll)
		app.back_to_environment()
		await _frames(2)
		app._advance_environment_game_runtime()
		_check(app.current_game == null and _money_guard() == before
			and not bool(app.current_event_choice_popup_snapshot().get("visible", false)),
			"cash %d exit cannot reveal a delayed confirmation or wager" % bankroll)

func _background_unaffordable() -> void:
	# Leave while Auto is armed but before any foreground tick. This exercises
	# background affordability itself, rather than rechecking an already-paused
	# foreground cabinet. The host may spend its first pass draining the normal
	# one-frame quiet marker, so permit at most four explicit process passes.
	if not (await _fixture("BACKGROUND-BELOW", 10)) or not _toggle_auto(): return
	var before := _money_guard()
	app.back_to_environment()
	await _frames(2)
	if not _check(app.current_game == null and bool(_machine().get("slot_autoplay_active", false)),
		"background fixture exits before a foreground Auto tick and leaves Auto armed"):
		return
	app.test_msec += 100000
	for _pass in range(4):
		facts["explicit_background_passes"] = int(facts["explicit_background_passes"]) + 1
		app._advance_environment_game_runtime()
		await _frames(1)
		if not bool(_machine().get("slot_autoplay_active", false)): break
	_check(_money_guard() == before, "background unaffordable Auto has no debit, RNG advance, clock advance or result")
	_check(not bool(_machine().get("slot_autoplay_active", false)) and _pending_delivery().is_empty(),
		"background unaffordable Auto pauses without a sealed pending delivery")
	_check(not bool(app.current_event_choice_popup_snapshot().get("visible", false))
		and app.pending_wager_confirm_action_id.is_empty(), "background unaffordable Auto shows no misleading confirmation")
	_check(_bet() == 20, "background unaffordable pause preserves the player's selected MAX bet")
	facts["background_unaffordable"] = {"bankroll": app.run_state.bankroll, "selected_bet": _bet(),
		"autoplay_active": bool(_machine().get("slot_autoplay_active", false)), "pending_delivery": not _pending_delivery().is_empty()}

func _cancel_and_exit() -> void:
	if not (await _open_all_in("CANCEL")): return
	var before := _money_guard()
	app._on_game_surface_action("slot_bet", 0, false)
	_check(_bet() == 20 and _money_guard() == before, "modal blocks bet changes before the player cancels")
	app.back_to_environment()
	_check(_money_guard() == before, "exit while confirmation owns input cannot place a wager")
	# Blocking exit until Change Stake or canceling on exit are both safe policies.
	if app.current_game != null:
		_check(bool(app.current_event_choice_popup_snapshot().get("visible", false)), "blocked exit retains the visible pending decision")
		app.cancel_pending_wager_confirmation()
		app.back_to_environment()
	await _frames(2)
	_check(app.current_game == null and app.pending_wager_confirm_action_id.is_empty(), "cancel/exit clears transient wager intent")
	_check(_money_guard() == before and _pending_delivery().is_empty(), "cancel/exit neither charges nor strands sealed state")
	_check(app.enter_game("slot"), "same slot opens again after cancel/exit")
	app._on_game_surface_action("slot_bet", 0, false)
	_check(_bet() == 2, "returning to the slot permits changing the bet")
	_check(_money_guard() == before, "changing bet after return has no debit")

func _stale_inputs() -> void:
	for kind in ["bankroll", "bet", "session"]:
		if not (await _open_all_in("STALE-" + kind)): continue
		if kind == "bankroll":
			app.run_state.bankroll += 1
		elif kind == "bet":
			# Synthetic stale state, not a player route: live input is modal-blocked.
			var machine := State.set_selected_bet(_machine(), "bet_10")
			State.write_machine(app.run_state.current_environment, _state_key(), machine)
		else:
			app._reset_game_surface_runtime_state()
		var before := _money_guard()
		facts["explicit_confirm_inputs"] = int(facts["explicit_confirm_inputs"]) + 1
		app.confirm_pending_wager_action()
		_check(_money_guard() == before and app.pending_wager_confirm_action_id.is_empty()
			and _pending_delivery().is_empty(), kind + " change invalidates the pending decision without wagering")

func _pending_save() -> void:
	if not (await _open_all_in("SAVE-PENDING", true)): return
	var before := _money_guard()
	_check(app.save_service.save_run(app.run_state, PENDING_SLOT) == OK, "normal SaveService saves while all-in decision is pending")
	var restored: RunState = Saves.new().load_run(PENDING_SLOT)
	_check(restored != null, "fresh SaveService loads pending-decision snapshot")
	if restored != null:
		_check(restored.bankroll == app.run_state.bankroll and restored.rng_state == app.run_state.rng_state
			and not bool(State.read_machine(restored.current_environment, _state_key()).get("slot_autoplay_active", false)),
			"Save roundtrip preserves funds/RNG and paused Auto")
	_check(_money_guard() == before, "Save at pending decision places no wager")
	app.cancel_pending_wager_confirmation()

func _accept_once() -> void:
	if not (await _open_all_in("ACCEPT", true)): return
	var before := _machine()
	var bankroll := app.run_state.bankroll
	facts["explicit_confirm_inputs"] = int(facts["explicit_confirm_inputs"]) + 1
	app.confirm_pending_wager_action()
	await _frames(3)
	var after := _machine()
	_check(int(after.get("spin_count", 0)) == int(before.get("spin_count", 0)) + 1, "accepted all-in resolves exactly one spin")
	_check(int(after.get("coin_in", 0)) == int(before.get("coin_in", 0)) + 20
		and int(after.get("last_stake_cost", 0)) == 20, "accepted all-in charges exactly the displayed $20 stake")
	_check(app.run_state.bankroll == bankroll + int(after.get("last_net", 0)), "accepted all-in wallet agrees with its settled result")
	_check(not bool(after.get("slot_autoplay_active", false)) and _pending_delivery().is_empty(), "acceptance leaves Auto paused and no pending delivery")
	var settled := _money_guard()
	var state := JSON.stringify(app.run_state.to_dict())
	app.confirm_pending_wager_action()
	_check(_money_guard() == settled and JSON.stringify(app.run_state.to_dict()) == state, "repeated confirmation cannot charge or resolve twice")
	_check(app.save_service.save_run(app.run_state, SETTLED_SLOT) == OK, "accepted settlement saves through normal SaveService")
	var restored: RunState = Saves.new().load_run(SETTLED_SLOT)
	_check(restored != null, "fresh SaveService loads the accepted settlement")
	if restored != null:
		var machine := State.read_machine(restored.current_environment, _state_key())
		_check(restored.bankroll == app.run_state.bankroll and restored.rng_state == app.run_state.rng_state
			and int(machine.get("coin_in", 0)) == int(after.get("coin_in", 0))
			and int(machine.get("spin_count", 0)) == int(after.get("spin_count", 0)), "Save roundtrip cannot duplicate the accepted stake/result")
	facts["accepted"] = {"coin_in_before": before.get("coin_in", 0), "coin_in_after": after.get("coin_in", 0),
		"spin_count_before": before.get("spin_count", 0), "spin_count_after": after.get("spin_count", 0), "bankroll_after": app.run_state.bankroll}

func _cold() -> void:
	app.autosave_slot_id = PENDING_SLOT
	if not _check(app.load_foundation_run(), "fresh-process Continue loads pending-decision Save"): return
	app.set_process(false)
	if not _check(app.run_state != null, "Continue publishes an active RunState before entry"): return
	var loaded_run := app.run_state
	var before := _money_guard()
	_check(app.pending_wager_confirm_action_id.is_empty() and _pending_delivery().is_empty(), "cold Continue restores no stale UI or sealed wager intent")
	if not _check(app.enter_game("slot"), "cold Continue opens the same Slot"): return
	await _frames(2)
	facts["cold_entry_lifecycle"] = {"screen": app.current_screen, "run_present": app.run_state != null,
		"same_run": app.run_state == loaded_run, "room_recovery_generation": app.room_recovery_generation,
		"room_publication_generation": app.room_publication_generation, "save_status": app.save_status_message,
		"seed_text": loaded_run.seed_text}
	if not _check(app.run_state != null and app.run_state == loaded_run, "cold entry retains the same RunState after deferred room publication"): return
	_check(_money_guard() == before and not bool(_machine().get("slot_autoplay_active", false)), "cold entry preserves funds/result and keeps Auto paused")
	app.confirm_pending_wager_action()
	_check(_money_guard() == before, "stale confirmation after cold entry has no effect")
	app._on_game_surface_action("slot_bet", 0, false)
	_check(_bet() == 2 and _money_guard() == before, "cold entry accepts a smaller bet without charging")
	app.autosave_slot_id = SETTLED_SLOT
	if not _check(app.load_foundation_run(), "fresh-process Continue loads accepted settlement"): return
	app.set_process(false)
	if not _check(app.run_state != null, "accepted Continue publishes an active RunState"): return
	facts["cold_accepted_seed_text"] = app.run_state.seed_text
	before = _money_guard()
	app.confirm_pending_wager_action()
	_check(_money_guard() == before and _pending_delivery().is_empty(), "cold accepted settlement cannot replay a confirmation or duplicate debit")

func _state_key() -> String:
	return app.current_game_state_key if not app.current_game_state_key.is_empty() else "slot"

func _machine() -> Dictionary:
	if not is_instance_valid(app) or app.run_state == null: return {}
	return State.read_machine(app.run_state.current_environment, _state_key())

func _bet() -> int:
	return int(State.selected_bet(_machine()).get("total_credits", 0))

func _pending_delivery() -> Dictionary:
	# Inspect even after leaving the surface. Returning {} merely because no
	# foreground game exists would hide the exact stranded-delivery regression.
	var ledger: Dictionary = _machine().get(Authority.LEDGER_KEY, {})
	return ledger.get("pending_delivery", {})

func _money_guard() -> Array:
	if not is_instance_valid(app) or app.run_state == null: return ["missing_run_state"]
	var machine := _machine()
	return [app.run_state.bankroll, app.run_state.grand_casino_chips, app.run_state.rng_state,
		app.run_state.game_clock_minutes, app.run_state.simulation_msec,
		int(machine.get("coin_in", 0)), int(machine.get("coin_out", 0)), int(machine.get("spin_count", 0))]

func _private_roots() -> bool:
	var private_root := OS.get_environment("BTH32_PRIVATE_ROOT").replace("\\", "/").simplify_path().trim_suffix("/").to_lower()
	if not _check(private_root.is_absolute_path() and private_root.contains("/native-private-bth32-"), "explicit fresh BTH32 private root is required"): return false
	for key in ["APPDATA", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH", "BTH_TARGET_OUTPUT"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path().to_lower()
		if not _check(path == private_root or path.begins_with(private_root + "/"), "private containment for " + key): return false
	var user_path := ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path().to_lower()
	if not _check(user_path.begins_with(private_root + "/"), "Godot user root is private before constructing host"): return false
	return _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "no captured save or browser profile input")

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
	print("BTH32_SLOT_AUTOPLAY_BANKROLL_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
