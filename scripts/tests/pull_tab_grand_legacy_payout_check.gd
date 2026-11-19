extends SceneTree

# Independent, explicitly historical Grand stock. Buy/Collect/Reveal/File use
# normal host controls; no outcome, stock, ticket or RNG is changed. The filed
# outstanding winner is then loaded with the CURRENT catalog and redeemed by
# the real host hook. Run producer then --cold in the same disposable namespace.
const Main := preload("res://scripts/ui/foundation_main.gd")
const Fixture := preload("res://scripts/tests/pull_tab_grand_fixture.gd")
const FreshStorage := preload("res://scripts/tests/fixtures/qa_fresh_storage_admission.gd")
const OUTSTANDING := "pull_tab_grand_legacy_outstanding"
const MAX_PROBES := 16

# All entry/Continue/control handlers remain production code. Only optional
# asynchronous UI prewarm is suppressed; entry builds the same UI synchronously.
class FixtureHost extends Main:
	func _prewarm_run_ui_after_web_start() -> void:
		pass
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}
var app: Control
var completed := false
var storage_admitted := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _private_roots():
		await _finish()
		return
	app = FixtureHost.new()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set("continuous_environment_clock_enabled", false)
	app.set("script_prewarm_stopping", true)
	root.add_child(app)
	for _frame in range(4):
		await process_frame
	app.get("user_settings").coach_tips_enabled = false
	app.call("_ensure_full_content_library_loaded")
	if OS.get_cmdline_user_args().has("--cold"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_reference_path()))
		if _check(typeof(parsed) == TYPE_DICTIONARY and parsed.has("outstanding"), "cold phase has the producer's outstanding-winner receipt"):
			facts = parsed.get("facts", {}).duplicate(true)
			_current_load_and_redeem(parsed, "cold")
			completed = failures.is_empty()
		await _finish()
		return
	if not _check(not app.get("save_service").has_run(OUTSTANDING), "producer requires a fresh isolated outstanding slot"):
		await _finish()
		return
	var retained := false
	var prize := 0
	var ticket_id := ""
	for probe in range(MAX_PROBES):
		# Each independent candidate is actually purchased, revealed and filed.
		# A large winner or loser is left intact in its disposable candidate run.
		var seed := "PULLTAB-LEGACY-PAYOUT-%d" % probe
		var setup := Fixture.create(app, seed, {"scenario_id": "grand_casino_audit_night", "clock_minutes": 3120})
		if not _check(bool(setup.get("ok", false)), "historical candidate generation: " + JSON.stringify(setup.get("errors", []))):
			break
		app.set("autosave_slot_id", OUTSTANDING + "_probe")
		if not _check(app.get("save_service").save_run(setup.get("run"), OUTSTANDING + "_probe") == OK and bool(app.call("load_foundation_run")), "candidate official baseline Save/Continue succeeds"):
			break
		if not _check(bool(app.call("enter_game", "pull_tabs")), "candidate historical Pull Tabs host entry succeeds"):
			break
		var run: RunState = app.get("run_state")
		var chips := run.grand_casino_chips
		var cash := run.bankroll
		app.call("_on_game_surface_action", "pull_tab_buy", int(setup.get("facts", {}).get("two_dollar_deal_index", -1)), false)
		for _frame in range(6):
			await process_frame
		if not _check(run.bankroll == cash and run.grand_casino_chips == chips - 2 and _pile(run).get("tray_stack", []).size() == 1, "candidate pays the posted two-chip price exactly once"):
			break
		app.call("_on_game_surface_action", "pull_tab_collect_tray", 0, false)
		await create_timer(0.1).timeout
		app.call("_on_game_surface_action", "pull_tab_reveal_next", 0, false)
		await create_timer(1.2).timeout
		app.call("_on_game_surface_action", "pull_tab_file_ticket", 0, false)
		await create_timer(0.7).timeout
		var winners: Array = _pile(run).get("winner_pile", [])
		if winners.size() == 1:
			prize = int(winners[0].get("payout", 0))
			if prize > 0 and prize <= 6:
				retained = true
				ticket_id = str(winners[0].get("id", ""))
				facts = {"historical_fixture": setup.get("facts", {}), "seed": seed, "paid_revealed_candidates": probe + 1, "ticket_id": ticket_id, "natural_prize": prize}
				break
	if not _check(retained, "bounded paid/revealed/filed candidates reach a naturally small winner; otherwise payout acceptance is NOT REACHED"):
		await _finish()
		return
	var outstanding := _snapshot(app.get("run_state"))
	if not _menu_save(OUTSTANDING):
		await _finish()
		return
	# Return to actual shipping content before either load. No saved state,
	# geometry, seal, custody or issued ticket is replaced during this switch.
	if not _check(Fixture.restore_current_content(app), "historical generator content restores to the current shipping catalog before warm load"):
		await _finish()
		return
	var reference := {"outstanding": outstanding, "prize": prize, "ticket_id": ticket_id, "facts": facts}
	_current_load_and_redeem(reference, "warm")
	var file := FileAccess.open(_reference_path(), FileAccess.WRITE)
	if _check(file != null, "producer can write its private outstanding-winner receipt"):
		file.store_string(JSON.stringify(reference, "\t"))
		file.close()
	completed = failures.is_empty()
	await _finish()


func _current_load_and_redeem(reference: Dictionary, phase: String) -> void:
	var outstanding_path: String = app.get("save_service").run_save_path(OUTSTANDING)
	var outstanding_sha := FileAccess.get_sha256(outstanding_path)
	if not _check(not outstanding_sha.is_empty(), phase + " outstanding primary input exists before Continue"):
		return
	var library: ContentLibrary = app.get("library")
	var current := library.environment_archetype("grand_casino")
	if not _check(current.get("game_pool", []).has("coin_pusher") and not current.get("game_pool", []).has("pull_tabs"), phase + " loader uses fresh current Grand catalog"):
		return
	app.set("autosave_slot_id", OUTSTANDING)
	if not _check(bool(app.call("load_foundation_run")), phase + " official current-catalog Continue loads outstanding historical winner"):
		return
	var run: RunState = app.get("run_state")
	_check(_snapshot(run) == reference.get("outstanding", {}), phase + " load retains exact winner stock wallets RNG card bag and historical authority")
	_check(run.current_environment.get("game_ids", []).has("pull_tabs") and not run.current_environment.get("game_ids", []).has("coin_pusher") and bool(run.validate_room_action_authority().get("ok", false)), phase + " issued historical room retains valid authority without a replacement cabinet")
	var winners: Array = _pile(run).get("winner_pile", [])
	if not _check(winners.size() == 1 and str(winners[0].get("id", "")) == str(reference.get("ticket_id", "")) and int(winners[0].get("payout", 0)) == int(reference.get("prize", 0)), phase + " load retains the actual paid natural prize and ticket identity"):
		return
	var before := _snapshot(run)
	# The outstanding slot is an immutable producer input for the cold phase.
	# Normal hook autosaves belong to this phase's separate working generation.
	app.set("autosave_slot_id", OUTSTANDING + "_" + phase + "_working")
	var invoked: bool = app.call("use_game_environment_hook", "pull_tabs", "ticket_redeemer", "redeem_pull_tab_winners")
	var result: Dictionary = app.get("last_hook_result")
	var after := _snapshot(run)
	var prize := int(reference.get("prize", 0))
	var credit := prize + int(result.get("pull_tab_luck_payout_bonus", 0)) + int(result.get("pull_tab_item_payout_bonus", 0))
	_check(int(result.get("pull_tab_base_redeemed_payout", -1)) == prize and int(result.get("pull_tab_redeemed_payout", -1)) == credit and int(result.get("pull_tab_security_bankroll_delta", 0)) == 0, phase + " redemption retains the natural face prize and existing earned bonus semantics")
	_check(invoked and bool(result.get("ok", false)) and run.bankroll == int(before.cash) and run.grand_casino_chips == int(before.chips) + credit and int(result.get("chips_delta", -1)) == credit, phase + " real counter hook credits the exact natural payout to Grand chips once")
	for key in ["rng", "deals", "tickets_sold", "companions", "card_float_bits", "pending_bags"]:
		_check(after[key] == before[key], phase + " redemption preserves " + key)
	_check(int(before.get("ticket_marker_count", -1)) == 1 and int(after.get("ticket_marker_count", -1)) == 0, phase + " redeeming the last issued winner removes exactly its portable inventory marker")
	var machine := _machine(run)
	_check(int(machine.get("cashout_count", 0)) == int(before.get("cashout_count", 0)) + 1 and _pile(run).get("winner_pile", []).is_empty(), phase + " one host redemption consumes the outstanding winner once")
	var redeemed: Array = machine.get("redeemed_pile", [])
	_check(redeemed.any(func(ticket: Dictionary) -> bool: return str(ticket.get("id", "")) == str(reference.get("ticket_id", ""))), phase + " redeemed receipt retains the original ticket identity")
	var retry_before := _snapshot(run)
	app.call("use_game_environment_hook", "pull_tabs", "ticket_redeemer", "redeem_pull_tab_winners")
	_check(not bool(app.get("last_hook_result").get("ok", true)) and _snapshot(run) == retry_before, phase + " empty host retry cannot credit again or alter protected state")
	var settled_slot := OUTSTANDING + "_" + phase + "_settled"
	if not _menu_save(settled_slot):
		return
	app.set("autosave_slot_id", settled_slot)
	if _check(bool(app.call("load_foundation_run")), phase + " post-payout official Continue succeeds"):
		run = app.get("run_state")
		_check(_snapshot(run) == retry_before, phase + " post-payout load preserves exactly one chip credit and receipt")
		app.call("use_game_environment_hook", "pull_tabs", "ticket_redeemer", "redeem_pull_tab_winners")
		_check(_snapshot(run) == retry_before, phase + " post-payout load cannot replay redeemed money")
	app.get("save_service").wait_for_async_save()
	_check(FileAccess.get_sha256(outstanding_path) == outstanding_sha, phase + " load and working-slot settlements preserve the outstanding cold input bytes")
	facts[phase + "_settlement"] = {"natural_face_prize": prize, "credited_prize_including_existing_bonuses": credit, "cash_before": before.cash, "cash_after": after.cash, "chips_before": before.chips, "chips_after": after.chips, "companions_before": before.companions, "companions_after": after.companions, "card_float_bits": after.card_float_bits, "ticket_marker_transition": [before.ticket_marker_count, after.ticket_marker_count], "outstanding_authority": before.historical_room_authority, "outstanding_primary_sha256": outstanding_sha, "settled_slot": settled_slot}


func _menu_save(slot: String) -> bool:
	app.set("autosave_slot_id", slot)
	app.call("open_run_menu")
	app.call("save_run_from_menu")
	app.get("save_service").wait_for_async_save()
	return _check(not bool(app.get("run_menu_overlay").visible) and app.get("save_service").has_run(slot), "normal Menu Save commits " + slot)


func _machine(run: RunState) -> Dictionary:
	return run.current_environment.get("game_states", {}).get("pull_tabs", {})


func _pile(run: RunState) -> Dictionary:
	return run.portable_ticket_state("pull_tabs", run.current_environment)


func _snapshot(run: RunState) -> Dictionary:
	var machine := _machine(run)
	var companions: Array = []
	var ticket_marker_count := 0
	var card_float_bits: Dictionary = {}
	for value in run.inventory:
		# Inventory supports item-ID strings as well as item dictionaries. Only
		# this exact portable-ticket marker is expected to disappear at cash-in.
		var item_id := str(value.get("id", "")) if typeof(value) == TYPE_DICTIONARY else str(value)
		if item_id == RunState.PULL_TAB_PILE_ITEM_ID:
			ticket_marker_count += 1
			continue
		companions.append(value)
		if typeof(value) == TYPE_DICTIONARY:
			var meta: Dictionary = value.get("meta_collection", {})
			if int(meta.get("itemdef_id", 0)) == 9500:
				var bits: Dictionary = {}
				for key in ["potency", "condition", "resonance", "usage"]:
					bits[key] = var_to_bytes(float(meta.get("floats", {}).get(key, -1.0))).hex_encode()
				card_float_bits[item_id] = bits
	return JSON.parse_string(JSON.stringify({"cash": run.bankroll, "chips": run.grand_casino_chips, "rng": str(run.rng_state), "deals": machine.get("deals", []), "tickets_sold": machine.get("tickets_sold", 0), "cashout_count": machine.get("cashout_count", 0), "redeemed_pile": machine.get("redeemed_pile", []), "pile": _pile(run), "inventory": run.inventory, "companions": companions, "ticket_marker_count": ticket_marker_count, "card_float_bits": card_float_bits, "pending_bags": run.pending_bags, "historical_room_authority": Fixture.authority_receipt(run)}))


func _reference_path() -> String:
	return SaveService.new().run_save_path(OUTSTANDING).get_base_dir().path_join("pull_tab_grand_legacy_payout_reference.json")


func _private_roots() -> bool:
	var admission := FreshStorage.validate()
	storage_admitted = _check(bool(admission.get("ok", false)) and not OS.has_feature("web"), "exact prepared fresh native QA storage admission: " + JSON.stringify(admission.get("errors", [])))
	return storage_admitted


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
	return ok


func _finish() -> void:
	_check(completed, "requested historical outstanding-payout stage completes; an unplayed/no-winner stage is NOT REACHED")
	if app != null:
		app.call("_drain_script_prewarm_requests_for_shutdown")
		app.get("save_service").wait_for_async_save()
		_check(Fixture.restore_current_content(app), "owned fixture restores the current catalog at cleanup")
		app.queue_free()
		for _frame in range(2):
			await process_frame
	var report := {"checks": checks, "failures": failures, "completed": completed, "facts": facts, "fidelity": "Explicit pinned historical Grand content generates up to16 independent real paid/revealed/filed candidates, retaining a naturally small winner without outcome changes. Official outstanding Menu Save then CURRENT-catalog warm/cold Continue, real host chip redemption/retry and post-payout Save/load. No owner saves, browser or rendered-pixel claim."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if storage_admitted and not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	print("PULL_TAB_GRAND_LEGACY_PAYOUT_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
