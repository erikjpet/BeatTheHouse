extends "res://scripts/tests/foundation/check_scratch_tickets.gd"

const CageEconomyModelScript := preload("res://scripts/core/cage_economy_model.gd")
const GrandCasinoShowdownModelScript := preload("res://scripts/core/grand_casino_showdown_model.gd")


func _check_cage_environment_rework(_library: ContentLibrary, failures: Array) -> void:
	_check_cage_terminal_exit(_library, failures)
	_check_cage_linda_simulation(_library, failures)
	_check_cage_atm_state(failures)
	_check_cage_debt_first_cashout(failures)
	_check_cage_gift_shop(_library, failures)
	var exact_cashout := CageEconomyModelScript.cashout_preview(200, 200, 1, 150, 20)
	if not bool(exact_cashout.get("ok", false)) or int(exact_cashout.get("debt_after", -1)) != 0 or int(exact_cashout.get("chips_after", -1)) != 0 or int(exact_cashout.get("cash_paid", -1)) != 50:
		failures.append("Cage debt-first cashout contract did not settle debt 150/chips 200 into $50 cash.")
	var partial_cashout := CageEconomyModelScript.cashout_preview(100, 100, 1, 150, 20)
	if not bool(partial_cashout.get("ok", false)) or int(partial_cashout.get("debt_after", -1)) != 50 or int(partial_cashout.get("cash_paid", -1)) != 0:
		failures.append("Cage debt-first cashout contract did not accept a successful all-debt settlement.")
	var rate_cashout := CageEconomyModelScript.cashout_preview(100, 40, 2, 50, 20)
	if int(rate_cashout.get("gross_value", -1)) != 80 or int(rate_cashout.get("debt_paid", -1)) != 50 or int(rate_cashout.get("cash_paid", -1)) != 30:
		failures.append("Cage debt-first cashout contract did not apply the exchange rate to gross value.")
	for fixture in [
		{"old": 0, "expected": 0},
		{"old": 50, "expected": 53},
		{"old": 200, "expected": 210},
		{"old": 500, "expected": 525},
	]:
		if CageEconomyModelScript.interest_balance(int(fixture.get("old", 0))) != int(fixture.get("expected", 0)):
			failures.append("Cage ATM interest contract failed exact ceiling fixture %s." % JSON.stringify(fixture))
	var compounded := CageEconomyModelScript.interest_balance(CageEconomyModelScript.interest_balance(200))
	if compounded != 221:
		failures.append("Cage ATM interest contract did not compound $200 to $210 then $221.")
	var crossings := CageEconomyModelScript.crossed_interest_boundary_indices(179, 180 + 1440 * 2, -1)
	if crossings != [0, 1, 2]:
		failures.append("Cage ATM boundary contract did not enumerate every crossed 3:00 AM boundary.")
	var valid_borrow := CageEconomyModelScript.borrow_preview(450, 50)
	var capped_borrow := CageEconomyModelScript.borrow_preview(500, 50)
	var invalid_borrow := CageEconomyModelScript.borrow_preview(0, 25)
	if not bool(valid_borrow.get("ok", false)) or int(valid_borrow.get("debt_after", 0)) != 500 or bool(capped_borrow.get("ok", true)) or bool(invalid_borrow.get("ok", true)):
		failures.append("Cage ATM borrowing contract did not enforce $50 increments and the $500 new-credit cap.")


func _check_cage_terminal_exit(library: ContentLibrary, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("CAGE-TERMINAL-EXIT")
	var main_archetype := library.environment_archetype(RunState.GRAND_CASINO_ARCHETYPE_ID)
	var main := EnvironmentInstance.from_archetype(main_archetype, 3, run_state.create_rng("cage_terminal_main"), library)
	run_state.set_environment(main.to_dict())
	var generator := RunGenerator.new(library)
	if not generator.enter_grand_casino_room(run_state, RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID):
		failures.append("Cage terminal-exit fixture could not enter the walkable room.")
		return
	var terminal := RunTerminalEvaluatorScript.evaluate(run_state, library)
	if bool(terminal.get("failed", false)) or not bool(terminal.get("local_room_travel_available", false)) or not bool(terminal.get("recovery_available", false)):
		failures.append("The wagerless Cage was falsely classified as stranded despite its free Main Floor return door.")


func _check_cage_atm_state(failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("CAGE-ATM-STATE")
	run_state.set_environment({"id": "cage_atm_fixture", "archetype_id": RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID, "world_node_id": RunState.GRAND_CASINO_ARCHETYPE_ID, "kind": "boss", "turns": 0})
	var money_before := run_state.bankroll
	var invalid := run_state.borrow_from_grand_casino_atm(25)
	if bool(invalid.get("ok", true)) or run_state.bankroll != money_before or run_state.grand_casino_atm_debt() != 0:
		failures.append("Invalid Cage ATM increment mutated cash or debt.")
	var borrowed := run_state.borrow_from_grand_casino_atm(200)
	if not bool(borrowed.get("ok", false)) or run_state.bankroll != money_before + 200 or run_state.grand_casino_atm_debt() != 200:
		failures.append("Cage ATM did not atomically exchange a $200 marker for $200 cash.")
	var marker_count := 0
	for debt_value in run_state.debt:
		if typeof(debt_value) == TYPE_DICTIONARY and str((debt_value as Dictionary).get("id", "")) == CageEconomyModelScript.ATM_DEBT_ID:
			marker_count += 1
	if marker_count != 1 or int(run_state.to_dict().get("grand_casino_atm_debt", -1)) != 200:
		failures.append("Cage ATM marker did not have one authoritative debt entry and derived save balance.")
	var debt_rows := RunReportViewModelScript.build_debt_ledger(run_state.debt, run_state.story_log)
	var marker_rows := debt_rows.filter(func(row: Dictionary) -> bool: return str(row.get("id", "")) == CageEconomyModelScript.ATM_DEBT_ID)
	if marker_rows.size() != 1 or int((marker_rows[0] as Dictionary).get("amount", -1)) != 200:
		failures.append("Cage ATM marker did not appear exactly once with its live balance in report debt rows.")
	var cap_run: RunState = RunStateScript.new()
	cap_run.start_new("CAGE-ATM-CAP")
	cap_run.set_environment({"id": "cage_atm_cap", "archetype_id": RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID, "world_node_id": RunState.GRAND_CASINO_ARCHETYPE_ID, "kind": "boss", "turns": 0})
	if not bool(cap_run.borrow_from_grand_casino_atm(500).get("ok", false)):
		failures.append("Cage ATM did not allow borrowing exactly to the $500 new-credit cap.")
	var cap_before := JSON.stringify(cap_run.to_dict())
	if bool(cap_run.borrow_from_grand_casino_atm(50).get("ok", true)) or JSON.stringify(cap_run.to_dict()) != cap_before:
		failures.append("Cage ATM draw above the $500 new-credit cap mutated state.")
	var next_boundary := CageEconomyModelScript.next_interest_boundary(run_state.game_clock_minutes)
	run_state.advance_game_clock_minutes(next_boundary - run_state.game_clock_minutes)
	if run_state.grand_casino_atm_debt() != 210:
		failures.append("Cage ATM did not accrue $200 to $210 at the next absolute 3 AM boundary.")
	var after_first := run_state.to_dict()
	var restored: RunState = RunStateScript.new()
	restored.from_dict(after_first)
	restored.advance_game_clock_minutes(1439)
	if restored.grand_casino_atm_debt() != 210:
		failures.append("Cage ATM save/load replayed interest before the next 3 AM boundary.")
	restored.advance_game_clock_minutes(1)
	if restored.grand_casino_atm_debt() != 221:
		failures.append("Cage ATM did not compound $210 to $221 at the second 3 AM boundary.")
	var notifications := restored.grand_casino_atm_pending_interest_notifications()
	if notifications.size() != 2 or int((notifications[0] as Dictionary).get("interest_added", -1)) != 10 or int((notifications[1] as Dictionary).get("interest_added", -1)) != 11:
		failures.append("Cage ATM did not retain every crossed interest notification through save/load.")
	var just_after: RunState = RunStateScript.new()
	just_after.start_new("CAGE-ATM-JUST-AFTER")
	just_after.set_environment({"id": "cage_atm_just_after", "archetype_id": RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID, "world_node_id": RunState.GRAND_CASINO_ARCHETYPE_ID, "kind": "boss", "turns": 0})
	var first_boundary := CageEconomyModelScript.next_interest_boundary(just_after.game_clock_minutes)
	just_after.advance_game_clock_minutes(first_boundary - just_after.game_clock_minutes + 1)
	just_after.borrow_from_grand_casino_atm(50)
	var following_boundary := CageEconomyModelScript.next_interest_boundary(just_after.game_clock_minutes)
	just_after.advance_game_clock_minutes(following_boundary - just_after.game_clock_minutes - 1)
	if just_after.grand_casino_atm_debt() != 50:
		failures.append("Cage ATM borrowing just after 3 AM accrued before the following 3 AM boundary.")
	just_after.advance_game_clock_minutes(1)
	if just_after.grand_casino_atm_debt() != 53:
		failures.append("Cage ATM borrowing just after 3 AM did not accrue at the following boundary.")
	var jump_run: RunState = RunStateScript.new()
	jump_run.start_new("CAGE-ATM-MULTI-BOUNDARY")
	jump_run.set_environment({"id": "cage_atm_jump", "archetype_id": RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID, "world_node_id": RunState.GRAND_CASINO_ARCHETYPE_ID, "kind": "boss", "turns": 0})
	jump_run.borrow_from_grand_casino_atm(200)
	var jump_first := CageEconomyModelScript.next_interest_boundary(jump_run.game_clock_minutes)
	jump_run.advance_game_clock_minutes(jump_first - jump_run.game_clock_minutes + 1440)
	if jump_run.grand_casino_atm_debt() != 221 or jump_run.grand_casino_atm_pending_interest_notifications().size() != 2:
		failures.append("Cage ATM large clock jump did not compound every crossed 3 AM boundary in order.")
	var payment := restored.repay_grand_casino_atm_debt(1)
	if not bool(payment.get("ok", false)) or restored.grand_casino_atm_debt() != 220 or restored.bankroll != money_before + 199:
		failures.append("Cage ATM did not accept an exact $1 partial cash repayment.")
	var payoff_cash_before := restored.bankroll
	var payoff := restored.repay_grand_casino_atm_debt(-1)
	if not bool(payoff.get("ok", false)) or restored.grand_casino_atm_debt() != 0 or restored.bankroll != payoff_cash_before - 220 or not restored.grand_casino_atm_debt_entry().is_empty():
		failures.append("Cage ATM Pay in Full did not clear the marker entry atomically.")
	var legacy_payload := after_first.duplicate(true)
	legacy_payload.erase("grand_casino_atm_interest_boundary_index")
	legacy_payload.erase("grand_casino_atm_interest_notifications")
	var legacy: RunState = RunStateScript.new()
	legacy.from_dict(legacy_payload)
	var legacy_balance := legacy.grand_casino_atm_debt()
	legacy.advance_game_clock_minutes(1)
	if legacy.grand_casino_atm_debt() != legacy_balance:
		failures.append("Legacy Cage ATM save retroactively charged its loaded clock history.")


func _check_cage_debt_first_cashout(failures: Array) -> void:
	var cases := [
		{"seed": "CAGE-CASHOUT-200", "debt": 150, "chips": 200, "request": 200, "rate": 1, "debt_after": 0, "cash_paid": 50},
		{"seed": "CAGE-CASHOUT-100", "debt": 150, "chips": 100, "request": 100, "rate": 1, "debt_after": 50, "cash_paid": 0},
		{"seed": "CAGE-CASHOUT-RATE", "debt": 50, "chips": 100, "request": 40, "rate": 2, "debt_after": 0, "cash_paid": 30},
	]
	for case_value in cases:
		var case: Dictionary = case_value
		var run_state: RunState = RunStateScript.new()
		run_state.start_new(str(case.get("seed", "CAGE-CASHOUT")))
		run_state.set_environment({"id": "cage_cashout_fixture", "archetype_id": RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID, "world_node_id": RunState.GRAND_CASINO_ARCHETYPE_ID, "kind": "boss", "turns": 0})
		var debt_amount := int(case.get("debt", 0))
		var borrow := run_state.borrow_from_grand_casino_atm(debt_amount)
		if not bool(borrow.get("ok", false)):
			failures.append("Debt-first cashout fixture could not establish its marker.")
			continue
		run_state.change_bankroll(-debt_amount, true)
		run_state.grand_casino_chips = int(case.get("chips", 0))
		var cash_before := run_state.bankroll
		var result := run_state.cash_out_grand_casino_chips(int(case.get("request", 0)), int(case.get("rate", 1)))
		if not bool(result.get("ok", false)) or run_state.grand_casino_atm_debt() != int(case.get("debt_after", -1)) or int(result.get("cash_paid", -1)) != int(case.get("cash_paid", -1)) or run_state.bankroll != cash_before + int(case.get("cash_paid", 0)):
			failures.append("Debt-first chip cashout committed a result that disagreed with its exact preview: %s" % JSON.stringify(case))
	var blocked: RunState = RunStateScript.new()
	blocked.start_new("CAGE-CASHOUT-BLOCKED")
	blocked.set_environment({"id": "cage_cashout_blocked", "archetype_id": RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID, "world_node_id": RunState.GRAND_CASINO_ARCHETYPE_ID, "kind": "boss", "turns": 0})
	blocked.grand_casino_chips = 25
	blocked.narrative_flags["grand_casino_showdown_active"] = true
	var blocked_before := JSON.stringify(blocked.to_dict())
	var blocked_result := blocked.cash_out_grand_casino_chips()
	if bool(blocked_result.get("ok", true)) or JSON.stringify(blocked.to_dict()) != blocked_before:
		failures.append("Active Rourke duel cashout mutated chips, cash, debt, or save state.")


func _check_cage_gift_shop(library: ContentLibrary, failures: Array) -> void:
	var main_archetype := library.environment_archetype(RunState.GRAND_CASINO_ARCHETYPE_ID)
	var showdown_event := library.event(RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID)
	var showdown_payload: Dictionary = showdown_event.get("payload", {}) if typeof(showdown_event.get("payload", {})) == TYPE_DICTIONARY else {}
	var pat_down: Dictionary = showdown_payload.get("pat_down", {}) if typeof(showdown_payload.get("pat_down", {})) == TYPE_DICTIONARY else {}
	var cage_archetype := library.environment_archetype(RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID)
	var cage_flags: Dictionary = cage_archetype.get("local_narrative_flags", {}) if typeof(cage_archetype.get("local_narrative_flags", {})) == TYPE_DICTIONARY else {}
	var shop_config: Dictionary = cage_flags.get("casino_gift_shop", {}) if typeof(cage_flags.get("casino_gift_shop", {})) == TYPE_DICTIONARY else {}
	var valid_authored_candidates := 0
	for candidate_value in shop_config.get("candidate_offers", []):
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue
		var candidate_id := str((candidate_value as Dictionary).get("item_id", ""))
		if not library.item(candidate_id).is_empty() and not GrandCasinoShowdownModelScript.item_forbidden_by_pat_down(candidate_id, pat_down):
			valid_authored_candidates += 1
	if valid_authored_candidates < 3:
		failures.append("Cage gift-shop content validation found fewer than three authored pat-down-safe item candidates.")
	var signatures := {}
	var purchase_run: RunState = null
	for seed_index in range(40):
		var run_state: RunState = RunStateScript.new()
		run_state.start_new("CAGE-GIFT-%d" % seed_index)
		var main := EnvironmentInstance.from_archetype(main_archetype, 3, run_state.create_rng("cage_gift_main"), library)
		run_state.set_environment(main.to_dict())
		var generator: RunGenerator = RunGenerator.new(library)
		if not generator.enter_grand_casino_room(run_state, RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID):
			failures.append("Cage gift-shop fixture could not enter the Cage.")
			return
		var shop_state: Dictionary = run_state.current_environment.get("cage_gift_shop_state", {}) if typeof(run_state.current_environment.get("cage_gift_shop_state", {})) == TYPE_DICTIONARY else {}
		var stock: Array = shop_state.get("stock", []) if typeof(shop_state.get("stock", [])) == TYPE_ARRAY else []
		if stock.size() < 3 or stock.size() > 4:
			failures.append("Cage gift shop did not generate exactly 3-4 offers for seed %d." % seed_index)
			continue
		var ids: Array = []
		for stock_value in stock:
			if typeof(stock_value) != TYPE_DICTIONARY:
				continue
			var item_id := str((stock_value as Dictionary).get("item_id", ""))
			if ids.has(item_id):
				failures.append("Cage gift shop generated a duplicate item for seed %d." % seed_index)
			if GrandCasinoShowdownModelScript.item_forbidden_by_pat_down(item_id, pat_down):
				failures.append("Cage gift shop admitted pat-down-forbidden item %s." % item_id)
			ids.append(item_id)
		var signature := ",".join(ids)
		signatures[signature] = true
		if seed_index == 0:
			purchase_run = run_state
	if signatures.size() < 2:
		failures.append("Cage gift shop stock did not vary across the seeded sample.")
	if purchase_run == null:
		return
	var saved_stock := JSON.stringify(purchase_run.current_environment.get("cage_gift_shop_state", {}))
	var same_seed: RunState = RunStateScript.new()
	same_seed.start_new("CAGE-GIFT-0")
	var same_main := EnvironmentInstance.from_archetype(main_archetype, 3, same_seed.create_rng("cage_gift_main"), library)
	same_seed.set_environment(same_main.to_dict())
	var same_generator := RunGenerator.new(library)
	if not same_generator.enter_grand_casino_room(same_seed, RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID) or JSON.stringify(same_seed.current_environment.get("cage_gift_shop_state", {})) != saved_stock:
		failures.append("Cage gift-shop stock diverged for the same seed and named action-boundary fork.")
	var travel_generator := RunGenerator.new(library)
	if not travel_generator.enter_grand_casino_room(purchase_run, RunState.GRAND_CASINO_ARCHETYPE_ID) or not travel_generator.enter_grand_casino_room(purchase_run, RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID) or JSON.stringify(purchase_run.current_environment.get("cage_gift_shop_state", {})) != saved_stock:
		failures.append("Cage gift-shop stock rerolled across local room travel.")
	var restored: RunState = RunStateScript.new()
	restored.from_dict(purchase_run.to_dict())
	if JSON.stringify(restored.current_environment.get("cage_gift_shop_state", {})) != saved_stock:
		failures.append("Cage gift shop stock rerolled or lost sold state on save/load.")
	var action_service := RunActionService.new()
	action_service.setup(library, restored)
	var offers := action_service.cage_gift_shop_offer_view_list()
	if offers.is_empty():
		failures.append("Cage gift shop generated stock but exposed no purchasable view entries.")
		return
	var offer: Dictionary = offers[0]
	var item_id := str(offer.get("item_id", ""))
	var price := int(offer.get("chip_price", 0))
	restored.grand_casino_chips = maxi(0, price - 1)
	var failed_before := JSON.stringify(restored.to_dict())
	var failed_purchase := action_service.buy_cage_gift_shop_offer(item_id)
	if bool(failed_purchase.get("ok", true)) or JSON.stringify(restored.to_dict()) != failed_before:
		failures.append("Failed Cage gift purchase mutated chips, inventory, or saved stock.")
	restored.grand_casino_chips = price + 5
	restored.borrow_from_grand_casino_atm(50)
	var cash_before := restored.bankroll
	var debt_before := restored.grand_casino_atm_debt()
	var result := action_service.buy_cage_gift_shop_offer(item_id)
	if not bool(result.get("ok", false)) or restored.bankroll != cash_before or restored.grand_casino_chips != 5 or restored.grand_casino_atm_debt() != debt_before or not restored.inventory.has(item_id):
		failures.append("Cage gift purchase did not debit chips only through standard item acquisition while indebted.")
	var after_purchase := RunStateScript.new()
	after_purchase.from_dict(restored.to_dict())
	var sold_found := false
	for sold_value in (after_purchase.current_environment.get("cage_gift_shop_state", {}) as Dictionary).get("stock", []):
		if typeof(sold_value) == TYPE_DICTIONARY and str((sold_value as Dictionary).get("item_id", "")) == item_id:
			sold_found = bool((sold_value as Dictionary).get("sold", false))
	if not sold_found:
		failures.append("Cage gift purchase sold state did not survive save/load.")


func _check_cage_linda_simulation(library: ContentLibrary, failures: Array) -> void:
	var run_a: RunState = RunStateScript.new()
	var run_b: RunState = RunStateScript.new()
	for run_state in [run_a, run_b]:
		run_state.start_new("CAGE-LINDA-DETERMINISM")
		run_state.set_environment({"id": "cage_linda_fixture", "archetype_id": RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID, "world_node_id": RunState.GRAND_CASINO_ARCHETYPE_ID, "kind": "boss", "turns": 0})
		run_state.advance_environment_turns(18)
	if JSON.stringify(run_a.linda_cage_snapshot()) != JSON.stringify(run_b.linda_cage_snapshot()):
		failures.append("Linda Cage pose sequence diverged for identical seed and action boundaries.")
	var stable_before := JSON.stringify(run_a.linda_cage_snapshot())
	for _refresh_index in range(5):
		run_a.linda_cage_snapshot()
		run_a.to_dict()
	if JSON.stringify(run_a.linda_cage_snapshot()) != stable_before:
		failures.append("Linda Cage pose changed during read-only refresh/save snapshots.")
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_a.to_dict())
	if JSON.stringify(restored.linda_cage_snapshot()) != stable_before:
		failures.append("Linda Cage pose/facing/countdown/fork state did not survive save/load exactly.")
	run_a.advance_environment_turns(12)
	restored.advance_environment_turns(12)
	if JSON.stringify(restored.linda_cage_snapshot()) != JSON.stringify(run_a.linda_cage_snapshot()):
		failures.append("Linda Cage deterministic continuation diverged after save/load.")
	for dialogue_value in library.dialogues:
		if typeof(dialogue_value) != TYPE_DICTIONARY:
			continue
		var dialogue: Dictionary = dialogue_value
		var speaker: Dictionary = dialogue.get("speaker", {}) if typeof(dialogue.get("speaker", {})) == TYPE_DICTIONARY else {}
		if str(speaker.get("name", "")) != "Linda":
			continue
		if str(speaker.get("presentation", "")) != "faceless_silhouette" or speaker.has("skin_color") or speaker.has("skin") or speaker.has("hair_color") or speaker.has("eye_color") or speaker.has("jacket_color") or not (speaker.get("face_layers", []) as Array).is_empty():
			failures.append("Linda dialogue %s exposed face-capable presentation fields." % str(dialogue.get("id", "unknown")))
