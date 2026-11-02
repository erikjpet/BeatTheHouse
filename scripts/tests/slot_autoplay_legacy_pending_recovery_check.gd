extends SceneTree

# BTH32 synthetic legacy-intent regression. The exact production Main creates a
# normal generated Bar run. Its ordinary sealed surface-intent API stages an
# uncommitted spin, deliberately without applying the command, reproducing the
# old pre-validation envelope. No player save, profile, key or RNG is imported.
const MainScene := preload("res://scenes/main.tscn")
const State := preload("res://scripts/games/slots/slot_machine_state.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const Runtime := preload("res://scripts/core/game_ritual_runtime.gd")
const SLOTS := {"below": "bth32_legacy_below", "paused_exact": "bth32_legacy_exact"}

var app
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {"fidelity": "synthetic legacy envelope through exact production Main and normal surface_intent; no command applied", "profiles_or_keys_imported": false, "fixtures": [], "explicit_paid_resolutions": 0}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _private_roots(): _finish(); return
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.autosave_slot_id = "bth32_legacy_runtime"
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	await _frames(2)
	if not _check(app._ensure_run_ui_built(), "production run UI builds"):
		await _cleanup(); _finish(); return
	app._ensure_full_content_library_loaded()
	if not _check(app.has_method("_recover_stranded_slot_wager_on_entry"), "scoped entry recovery method exists"):
		await _cleanup(); _finish(); return
	var mode := OS.get_environment("BTH32_MODE")
	if mode in ["cold", "legacy_cold"]:
		for kind in SLOTS.keys(): await _cold_case(str(kind))
	else:
		_check(mode in ["", "warm", "legacy_warm"], "legacy mode is warm or cold")
		for kind in SLOTS.keys():
			if not (await _seed_legacy(str(kind))): continue
			_check(app.save_service.save_run(app.run_state, str(SLOTS[kind])) == OK, str(kind) + ": normal SaveService preserves old pending intent")
			await _entry_recovery(str(kind), true)
		await _prior_settled_case()
		for kind in ["foreign_binding", "checkpoint", "recovery", "action", "stake", "above_boundary"]:
			await _negative(str(kind))
	facts["mode"] = "warm" if mode.is_empty() else mode
	await _cleanup()
	_finish()

func _seed_legacy(kind: String, bankroll_override: int = -1) -> bool:
	# Bar membership is seed-dependent. Reuse the normally generated Bar seed
	# observed to contain Slot; labels distinguish independent reset cases.
	var seed := "BTH32-LEGACY-below"
	var challenge := RunState.custom_challenge("bth32_legacy", seed, {"home_archetype_id": "bar"})
	if not _check(app.start_foundation_run(seed, challenge, false), kind + ": canonical generated Bar starts"): return false
	if not _check(app.run_state != null and app.run_state.current_environment.get("game_ids", []).has("slot"), kind + ": generated room contains Slot"): return false
	if not _check(app.enter_game("slot"), kind + ": normal Slot enters"): return false
	app.set_process(false)
	app.run_state.bankroll = bankroll_override if bankroll_override >= 0 else (20 if kind == "paused_exact" else 15)
	app._sync_presented_bankroll_to_actual()
	app._refresh()
	app._on_game_surface_action("slot_bet", 4, false)
	app._on_game_surface_action("slot_auto_toggle", 0, false)
	await _frames(2)
	if not _check(_bet() == 20 and bool(_machine().get("slot_autoplay_active", false)), kind + ": selected MAX and Auto are established normally"): return false
	var before := _money_guard()
	# This trusted host seam creates the old pending envelope before stake
	# validation, as old foreground Auto did. Do not dispatch/apply its command.
	var command: Dictionary = app._sealed_action_host_surface_intent("slot_spin", 0, false, app._current_game_surface_input_time_msec())
	var pending := _pending()
	if not _check(not pending.is_empty() and str(pending.get("action_id", "")) == "spin" and int(pending.get("stake", 0)) == 20 and command.has("_sealed_action_host_delivery"), kind + ": normal authority issues matching uncommitted spin envelope"): return false
	if kind == "paused_exact":
		# Old all-in handling paused after sealing, changing trusted context but
		# leaving the same valid, uncommitted ledger/recovery identity.
		app.current_game.surface_pause_repeating_action_for_confirmation({}, app.run_state, app.run_state.current_environment)
	_check(_money_guard() == before, kind + ": legacy preparation never wagers or advances RNG")
	var validated: Dictionary = app._sealed_action_host_ledger(app.run_state, false, true)
	(facts["fixtures"] as Array).append({"kind": kind, "seed_text": app.run_state.seed_text, "bankroll": app.run_state.bankroll, "stake": 20, "host_script": app.get_script().resource_path, "validated_pending": not validated.is_empty(), "autoplay_active": bool(_machine().get("slot_autoplay_active", false))})
	return _check(not validated.is_empty(), kind + ": stored legacy ledger validates against current account/binding")

func _prior_settled_case() -> void:
	# Keep the normal cold fixtures above; this warm-only practice case uses the
	# canonical seed whose genuine one-spin loss was observed in initial native
	# qualification. Require the result/receipts rather than fabricating them.
	var started: Dictionary = app.start_game_test_session("slot")
	if not _check(bool(started.get("ok", false)) and app.run_state != null, "settled prior result: canonical Slot practice starts"): return
	app.set_process(false)
	app.run_state.bankroll = 35
	app._sync_presented_bankroll_to_actual()
	app._refresh()
	app._on_game_surface_action("slot_bet", 4, false)
	await _frames(2)
	if not _check(_bet() == 20 and _pending().is_empty(), "settled prior result: MAX stages normally"): return
	var before_count := int(_machine().get("spin_count", 0))
	app._on_game_surface_action("slot_spin", 0, false)
	facts["explicit_paid_resolutions"] = int(facts["explicit_paid_resolutions"]) + 1
	await _frames(3)
	var machine := _machine()
	var ledger := _ledger()
	if not _check(app.run_state.bankroll == 15 and int(machine.get("spin_count", 0)) == before_count + 1 and int(machine.get("last_stake_cost", 0)) == 20 and int(machine.get("last_payout", -1)) == 0 and not str(machine.get("last_outcome_id", "")).is_empty(), "settled prior result: one unchanged-RNG paid spin naturally resolves35 to15"): return
	if not _check(not (ledger.get("request_cache", {}) as Dictionary).is_empty() and not (ledger.get("journal", []) as Array).is_empty(), "settled prior result: real accepted request/cache/journal are nonempty"): return
	var until := Time.get_ticks_msec() + mini(10000, maxi(250, int(machine.get("slot_animation_duration_msec", 0)) + 250))
	while Time.get_ticks_msec() < until: await process_frame
	var before := _money_guard()
	app._on_game_surface_action("slot_auto_toggle", 0, false)
	if not _check(bool(_machine().get("slot_autoplay_active", false)) and _money_guard() == before, "settled prior result: normal Auto toggle arms without another wager"): return
	var command: Dictionary = app._sealed_action_host_surface_intent("slot_spin", 0, false, app._current_game_surface_input_time_msec())
	if not _check(command.has("_sealed_action_host_delivery") and not _pending().is_empty() and _money_guard() == before, "settled prior result: uncommitted legacy intent stages without applying another spin"): return
	facts["prior_settled"] = {"seed_text": app.run_state.seed_text, "cache_size": (ledger.get("request_cache", {}) as Dictionary).size(), "journal_size": (ledger.get("journal", []) as Array).size(), "last_outcome_id": str(machine.get("last_outcome_id", "")), "bankroll": app.run_state.bankroll}
	# Hostile synthetic request collision: all original accepted evidence remains
	# unchanged; only the pending key is replaced. The helper's committed-key
	# guard must reject it without rewriting the ledger or touching the wallet.
	var legitimate_machine := _machine()
	var collision_machine := legitimate_machine.duplicate(true)
	var collision_ledger: Dictionary = collision_machine.get(Authority.LEDGER_KEY, {})
	(collision_ledger["pending_delivery"] as Dictionary)["request_key"] = str((ledger.get("request_order", []) as Array)[0])
	State.write_machine(app.run_state.current_environment, _state_key(), collision_machine)
	var collision_before := JSON.stringify(_ledger())
	var collision_result: Dictionary = app._recover_stranded_slot_wager_on_entry()
	_check(not bool(collision_result.get("handled", false)) and _money_guard() == before and JSON.stringify(_ledger()) == collision_before, "settled prior result: a pending key already committed in cache/journal is never recovered or replayed")
	State.write_machine(app.run_state.current_environment, _state_key(), legitimate_machine)
	await _entry_recovery("nonempty_prior_settlement", true)

func _entry_recovery(label: String, leave_first: bool) -> void:
	var before := _money_guard()
	var machine_before := _machine()
	var ledger_before := _ledger()
	var old_delivery := _pending().duplicate(true)
	if leave_first:
		app.back_to_environment()
		await _frames(2)
		if not _check(app.run_state != null and app.current_game == null, label + ": pending intent can leave without settling"): return
	if not _check(app.enter_game("slot"), label + ": same Slot enters with legacy pending state"): return
	await _frames(2)
	if not _check(app.run_state != null and app.current_game != null, label + ": normal room/Slot ownership survives deferred publication"): return
	_check(_money_guard() == before, label + ": entry recovery has no debit, payout, RNG, clock or spin advance")
	_check(_pending().is_empty() and not bool(_machine().get("slot_autoplay_active", false)), label + ": recovery cancels pending delivery and pauses Auto")
	_check(_bet() == 20, label + ": recovery preserves selected bet")
	_check(_ledger().get("request_cache", {}) == ledger_before.get("request_cache", {}) and _ledger().get("journal", []) == ledger_before.get("journal", []), label + ": recovery preserves existing cached responses/journal")
	_check(_machine().get("last_result", {}) == machine_before.get("last_result", {}) and _machine().get("last_outcome_id", "") == machine_before.get("last_outcome_id", ""), label + ": recovery preserves last settled result")
	for key in ["last_stake_cost", "last_payout", "last_net", "last_classification"]:
		_check(_machine().get(key) == machine_before.get(key), label + ": recovery preserves " + key)
	var again: Dictionary = app._recover_stranded_slot_wager_on_entry()
	_check(not bool(again.get("handled", false)) and _money_guard() == before, label + ": repeated recovery is a no-op")
	var replay: Dictionary = app._sealed_action_host_resolve_intent("spin", 20, old_delivery)
	_check(not bool(replay.get("ok", false)) and _money_guard() == before, label + ": canceled old delivery cannot replay a wager")
	app._on_game_surface_action("slot_bet", 0, false)
	_check(_bet() == 2 and _money_guard() == before, label + ": smaller bet is editable after legacy recovery")

func _cold_case(kind: String) -> void:
	app.autosave_slot_id = str(SLOTS[kind])
	if not _check(app.load_foundation_run(), kind + ": cold Continue loads the normal saved legacy run"): return
	app.set_process(false)
	if not _check(app.run_state != null and not _pending().is_empty(), kind + ": cold Continue retains authenticated legacy pending state before entry"): return
	await _entry_recovery("cold_" + kind, false)

func _negative(kind: String) -> void:
	if not (await _seed_legacy("negative_" + kind, 21 if kind == "above_boundary" else -1)): return
	var machine := _machine()
	var ledger: Dictionary = machine.get(Authority.LEDGER_KEY, {}).duplicate(true)
	if kind == "foreign_binding": ledger["table_binding"] = "foreign-cabinet"
	elif kind == "checkpoint": ledger["checkpoint_fingerprint"] = "0".repeat(64)
	elif kind == "recovery": (ledger["pending_recovery_session"] as Dictionary)["unexpected"] = true
	elif kind == "action":
		(ledger["pending_delivery"] as Dictionary)["action_id"] = "nudge"
		(ledger["pending_delivery"] as Dictionary)["intent_fingerprint"] = Runtime.canonical_fingerprint({"action_id": "nudge", "session": ledger.get("session", {})})
	elif kind == "stake": (ledger["pending_delivery"] as Dictionary)["stake"] = 2
	machine[Authority.LEDGER_KEY] = ledger
	State.write_machine(app.run_state.current_environment, _state_key(), machine)
	var before := _money_guard()
	var raw_before := JSON.stringify(_ledger())
	var response: Dictionary = app._recover_stranded_slot_wager_on_entry()
	_check(not bool(response.get("handled", false)), kind + ": invalid or out-of-scope pending intent is not recovered")
	_check(_money_guard() == before and JSON.stringify(_ledger()) == raw_before, kind + ": rejection neither wagers nor rewrites authority")

func _state_key() -> String:
	return str(app.current_game_state_key) if not str(app.current_game_state_key).is_empty() else "slot"
func _machine() -> Dictionary:
	return State.read_machine(app.run_state.current_environment, _state_key()) if app != null and app.run_state != null else {}
func _ledger() -> Dictionary:
	return _machine().get(Authority.LEDGER_KEY, {})
func _pending() -> Dictionary:
	return _ledger().get("pending_delivery", {})
func _bet() -> int:
	return int(State.selected_bet(_machine()).get("total_credits", 0))
func _money_guard() -> Array:
	if app == null or app.run_state == null: return ["missing_run"]
	var machine := _machine()
	return [app.run_state.bankroll, app.run_state.grand_casino_chips, app.run_state.rng_state, app.run_state.game_clock_minutes, app.run_state.simulation_msec, int(machine.get("coin_in", 0)), int(machine.get("coin_out", 0)), int(machine.get("spin_count", 0))]
func _private_roots() -> bool:
	var private_root := OS.get_environment("BTH32_PRIVATE_ROOT").replace("\\", "/").simplify_path().trim_suffix("/").to_lower()
	if not _check(private_root.is_absolute_path() and private_root.contains("/native-private-bth32-"), "fresh private BTH32 root is required"): return false
	for key in ["APPDATA", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH", "BTH_TARGET_OUTPUT"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path().to_lower()
		if not _check(path == private_root or path.begins_with(private_root + "/"), "private containment for " + key): return false
	var user_path := ProjectSettings.globalize_path("user://").replace("\\", "/").simplify_path().to_lower()
	return _check(user_path.begins_with(private_root + "/") and OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "private user namespace and no imported profiles")
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
	print("BTH32_LEGACY_PENDING_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
