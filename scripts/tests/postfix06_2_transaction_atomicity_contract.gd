extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const GameModuleScript := preload("res://scripts/core/game_module.gd")
const ItemEffectScript := preload("res://scripts/core/item_effect.gd")
const RunActionServiceScript := preload("res://scripts/core/run_action_service.gd")
const FactRunStateScript := preload("res://scripts/tests/postfix06_2_fact_run_state.gd")
const ScenarioSequenceContractScript := preload("res://scripts/tests/foundation/scenario_sequence_contract.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const ScenarioSequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const ScenarioSequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")

const PAID_SERVICES := [
	{"id": "cashier_tip", "cost": 4, "archetype": "grand_casino_cage"},
	{"id": "house_drink", "cost": 8, "archetype": "bar"},
	{"id": "punchline_two_drink_minimum", "cost": 8, "archetype": "small_underground_casino"},
	{"id": "jazz_sax_round", "cost": 8, "archetype": "jazz_club"},
	{"id": "jazz_cello_round", "cost": 8, "archetype": "jazz_club"},
	{"id": "jazz_drummer_round", "cost": 8, "archetype": "jazz_club"},
	{"id": "jazz_band_tip_jar", "cost": 6, "archetype": "jazz_club"},
	{"id": "kitty_champagne", "cost": 18, "archetype": "kitty_cat_lounge"},
	{"id": "kitty_burlesque_show", "cost": 28, "archetype": "kitty_cat_lounge"},
	{"id": "riverboat_deck_walk", "cost": 10, "archetype": "delta_queen"},
	{"id": "punchline_cover_charge", "cost": 14, "archetype": "small_underground_casino"},
	{"id": "punchline_private_table", "cost": 24, "archetype": "small_underground_casino"},
]

const FREE_SERVICES := [
	{"id": "call_brother_in_law", "archetype": "motel"},
	{"id": "listen_to_jazz", "archetype": "jazz_club"},
	{"id": "show_drummer_glasses", "archetype": "jazz_club"},
	{"id": "beach_relax", "archetype": "beach"},
	{"id": "beach_sand_pile", "archetype": "beach"},
	{"id": "scenario_open_bar", "archetype": "delta_queen"},
]

const DIRECT_LENDERS := ["street_lender", "motel_friend", "the_crew", "brother_in_law"]
const PAWN_ITEM_ID := "creased_luck_card"
const GIFT_ITEM_ID := "ledger_pencil"
const GIFT_PRICE := 3
const CASH_ITEM_PRICE := 10

const MATRIX_MODE_ERROR := "error_after_apply"
const MATRIX_MODE_HEAT := "heat_terminal"
const MATRIX_MODE_DEBT_TERMINAL := "debt_due_terminal"
const MATRIX_MODE_DEBT_NONTERMINAL := "debt_due_nonterminal"
const MATRIX_MODE_CLOSING := "closing_travel"
const MATRIX_MODE_ZERO := "bankroll_zero"
const MATRIX_REJECTION_MODES := [
	MATRIX_MODE_ERROR,
	MATRIX_MODE_HEAT,
	MATRIX_MODE_DEBT_TERMINAL,
	MATRIX_MODE_CLOSING,
	MATRIX_MODE_ZERO,
]

var failures: Array[String] = []
var library: ContentLibrary


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	library = ContentLibraryScript.new()
	var loaded: Dictionary = library.load(false)
	if not bool(loaded.get("ok", true)) or not library.validation_errors.is_empty():
		failures.append("SETUP: ContentLibrary did not load cleanly: %s / %s" % [JSON.stringify(loaded), JSON.stringify(library.validation_errors)])
		_finish()
		return
	_assert_positive_service_manifest()
	_assert_zero_service_and_lender_manifests()
	_check_all_paid_service_quotes()
	_check_free_service_transactions()
	_check_lender_transactions()
	_check_active_scenario_hook_facts()
	_check_cage_gift_transactions()
	_check_pawn_transactions()
	_check_portable_ticket_transactions()
	_check_nonterminal_forced_repayment_transactions()
	_check_result_induced_terminal_rollback()
	_check_cage_result_induced_terminal_rollback()
	_check_terminal_apply_result_guard()
	_check_descriptor_normal_acceptance_matrix()
	_check_descriptor_boundary_matrix()
	_check_descriptor_due_debt_acceptance_matrix()
	_finish()


func _transaction_descriptors() -> Array:
	var descriptors: Array = []
	for service_value in PAID_SERVICES:
		var service_data: Dictionary = service_value
		descriptors.append({
			"action_type": "hook",
			"kind": "service",
			"id": str(service_data.get("id", "")),
			"cost": int(service_data.get("cost", 0)),
			"archetype": str(service_data.get("archetype", "fixture")),
			"label": "paid service %s" % str(service_data.get("id", "")),
		})
	for service_value in FREE_SERVICES:
		var service_data: Dictionary = service_value
		descriptors.append({
			"action_type": "hook",
			"kind": "service",
			"id": str(service_data.get("id", "")),
			"cost": 0,
			"archetype": str(service_data.get("archetype", "fixture")),
			"label": "free service %s" % str(service_data.get("id", "")),
		})
	for lender_id in DIRECT_LENDERS:
		descriptors.append({
			"action_type": "hook",
			"kind": "lender",
			"id": str(lender_id),
			"cost": 0,
			"label": "lender %s" % str(lender_id),
		})
	descriptors.append({"action_type": "cage", "id": GIFT_ITEM_ID, "cost": GIFT_PRICE, "label": "Cage gift %s" % GIFT_ITEM_ID})
	descriptors.append({"action_type": "pawn", "id": PAWN_ITEM_ID, "cost": 0, "label": "Sal pawn %s" % PAWN_ITEM_ID})
	for item_id in [RunState.PULL_TAB_PILE_ITEM_ID, RunState.SCRATCH_TICKET_PILE_ITEM_ID]:
		descriptors.append({"action_type": "ticket", "id": item_id, "cost": 0, "label": "portable ticket %s" % item_id})
	descriptors.append({"action_type": "cash_item", "id": PAWN_ITEM_ID, "cost": CASH_ITEM_PRICE, "label": "cash item %s" % PAWN_ITEM_ID})
	return descriptors


func _descriptor_run(descriptor: Dictionary, suffix: String) -> RunState:
	var action_type := str(descriptor.get("action_type", ""))
	var action_id := str(descriptor.get("id", ""))
	var cost := maxi(0, int(descriptor.get("cost", 0)))
	match action_type:
		"hook":
			if str(descriptor.get("kind", "")) == "lender":
				return _lender_run(suffix, action_id)
			if cost > 0:
				var bankroll := maxi(cost * 2, cost + 20)
				var run := _base_run(suffix, bankroll, str(descriptor.get("archetype", "fixture")), [action_id], [])
				_set_local_heat(run, 20)
				return run
			return _free_service_run(suffix, action_id, str(descriptor.get("archetype", "fixture")))
		"cage":
			return _gift_run(suffix)
		"pawn":
			return _pawn_run(suffix)
		"ticket":
			return _ticket_run(suffix, action_id)
		"cash_item":
			return _item_purchase_run(suffix, maxi(40, cost * 2), cost)
	return _base_run(suffix, 60, "bar", [], [])


func _invoke_descriptor(run: RunState, descriptor: Dictionary) -> Dictionary:
	var action := _service(run)
	var action_type := str(descriptor.get("action_type", ""))
	var action_id := str(descriptor.get("id", ""))
	match action_type:
		"hook":
			return action.use_hook(str(descriptor.get("kind", "")), action_id)
		"cage":
			return action.buy_cage_gift_shop_offer(action_id)
		"pawn", "ticket":
			return action.pawn_inventory_item(action_id)
		"cash_item":
			return action.buy_item_offer(action_id)
	return {"ok": false, "message": "Unknown transaction descriptor."}


func _descriptor_available(run: RunState, descriptor: Dictionary) -> bool:
	var action := _service(run)
	var action_type := str(descriptor.get("action_type", ""))
	var action_id := str(descriptor.get("id", ""))
	match action_type:
		"hook":
			var option := action.hook_option(str(descriptor.get("kind", "")), action_id)
			return not option.is_empty() and bool(option.get("enabled", false))
		"cage":
			for offer_value in action.cage_gift_shop_offer_view_list():
				if typeof(offer_value) == TYPE_DICTIONARY and str((offer_value as Dictionary).get("item_id", "")) == action_id:
					return bool((offer_value as Dictionary).get("enabled", false))
		"pawn":
			return not _quote_for_item(action.pawn_quote_options(), action_id).is_empty()
		"ticket":
			return not _quote_for_item(action.portable_ticket_cash_options(), action_id).is_empty()
		"cash_item":
			var offer := action.item_offer(action_id)
			return not offer.is_empty() and run.bankroll >= int(offer.get("price", 0))
	return false


func _descriptor_seed_fragment(descriptor: Dictionary) -> String:
	return "%s-%s" % [str(descriptor.get("action_type", "ACTION")).to_upper(), str(descriptor.get("id", "unknown")).to_upper()]


func _prepare_descriptor_rejection_mode(run: RunState, descriptor: Dictionary, mode: String) -> void:
	match mode:
		MATRIX_MODE_ERROR, MATRIX_MODE_HEAT, MATRIX_MODE_CLOSING:
			run.current_environment[FactRunStateScript.POSTFIX_BOUNDARY_SEAM_KEY] = mode
		MATRIX_MODE_DEBT_TERMINAL:
			_set_local_heat(run, 96)
			_add_forced_boundary_debt(run)
			if str(descriptor.get("id", "")) == "beach_relax":
				run.current_environment[FactRunStateScript.POSTFIX_BOUNDARY_SEAM_KEY] = mode
		MATRIX_MODE_ZERO:
			run.bankroll = 0
			# Cage purchases spend chips, and chips count as liquid run funds. Keep
			# the offer preflight-valid at its exact quote so reservation reaches a
			# genuine post-boundary zero-funds terminal instead of retaining change.
			if str(descriptor.get("action_type", "")) == "cage":
				run.grand_casino_chips = maxi(1, int(descriptor.get("cost", 0)))


func _check_descriptor_boundary_matrix() -> void:
	for descriptor_value in _transaction_descriptors():
		var descriptor: Dictionary = descriptor_value
		for mode_value in MATRIX_REJECTION_MODES:
			var mode := str(mode_value)
			var label := "GP-PF-002 matrix %s %s" % [str(descriptor.get("label", "action")), mode]
			var run := _descriptor_run(descriptor, "MATRIX-%s-%s" % [_descriptor_seed_fragment(descriptor), mode.to_upper()])
			_prepare_descriptor_rejection_mode(run, descriptor, mode)
			var positive_cash_preflight := mode == MATRIX_MODE_ZERO and str(descriptor.get("action_type", "")) in ["cash_item", "hook"] and int(descriptor.get("cost", 0)) > 0
			if not positive_cash_preflight and not _descriptor_available(run, descriptor):
				failures.append("%s was not available before its qualified boundary." % label)
			var before := _snapshot(run)
			var response := _invoke_descriptor(run, descriptor)
			_assert_rejected_unchanged(response, run, before, label)


func _check_descriptor_due_debt_acceptance_matrix() -> void:
	for descriptor_value in _transaction_descriptors():
		var descriptor: Dictionary = descriptor_value
		var label := "GP-PF-002 matrix %s debt-due accepted" % str(descriptor.get("label", "action"))
		var run := _descriptor_run(descriptor, "MATRIX-%s-DEBT-ACCEPT" % _descriptor_seed_fragment(descriptor))
		_set_local_heat(run, 20)
		_add_forced_repayment_boundary_debt(run, 1)
		if str(descriptor.get("id", "")) == "beach_relax":
			run.current_environment[FactRunStateScript.POSTFIX_BOUNDARY_SEAM_KEY] = MATRIX_MODE_DEBT_NONTERMINAL
		var debt_story_before := _story_count_for_debt_id(run, "exhausting_boundary_note")
		var exact_once_oracle := run.detached_host_action_candidate()
		var response := _invoke_descriptor(run, descriptor)
		if not bool(response.get("ok", false)):
			failures.append("%s rejected: %s" % [label, str(response.get("message", response.get("errors", [])))])
			continue
		if str(descriptor.get("action_type", "")) == "hook":
			_assert_hook_committed_exactly_once(
				response,
				run,
				exact_once_oracle,
				str(descriptor.get("kind", "")),
				str(descriptor.get("id", "")),
				int(descriptor.get("cost", 0)),
				label
			)
		else:
			_assert_nonhook_committed_exactly_once(response, run, exact_once_oracle, descriptor, label)
		if _story_count_for_debt_id(run, "exhausting_boundary_note") != debt_story_before + 1:
			failures.append("%s did not publish exactly one due-debt consequence." % label)
		if _debt_count_for_id(run, "exhausting_boundary_note") != 0:
			failures.append("%s did not clear the one-dollar forced-repayment fixture exactly once." % label)


func _check_descriptor_normal_acceptance_matrix() -> void:
	for descriptor_value in _transaction_descriptors():
		var descriptor: Dictionary = descriptor_value
		var action_type := str(descriptor.get("action_type", ""))
		var label := "GP-PF-002 matrix %s normal" % str(descriptor.get("label", "action"))
		var run := _descriptor_run(descriptor, "EXACT-%s" % _descriptor_seed_fragment(descriptor))
		if action_type == "cash_item":
			run.bankroll = int(descriptor.get("cost", 0))
		if action_type != "hook":
			var fixture_id := ("nonhook_%s" % _descriptor_seed_fragment(descriptor).to_lower()).replace("-", "_")
			if not _install_active_service_fact_fixture(run, fixture_id):
				continue
		var exact_once_oracle := run.detached_host_action_candidate()
		var response := _invoke_descriptor(run, descriptor)
		if not bool(response.get("ok", false)):
			failures.append("%s rejected: %s" % [label, str(response.get("message", response.get("errors", [])))])
			continue
		if action_type == "hook":
			_assert_hook_committed_exactly_once(response, run, exact_once_oracle, str(descriptor.get("kind", "")), str(descriptor.get("id", "")), int(descriptor.get("cost", 0)), label)
		else:
			_assert_nonhook_committed_exactly_once(response, run, exact_once_oracle, descriptor, label)


func _check_all_paid_service_quotes() -> void:
	for service_value in PAID_SERVICES:
		var service_data: Dictionary = service_value
		var service_id := str(service_data.get("id", ""))
		var cost := int(service_data.get("cost", 0))
		var archetype := str(service_data.get("archetype", "fixture"))
		for debt_clock in [-1, 0, 1, 2]:
			for bankroll in [cost - 1, cost, cost + 1, cost * 2 - 1, cost * 2]:
				var label := "%s bankroll=%d debt_clock=%d" % [service_id, bankroll, debt_clock]
				var run := _base_run("PAID-%s-%d-%d" % [service_id, bankroll, debt_clock], bankroll, archetype, [service_id], [])
				_set_local_heat(run, 20)
				if debt_clock >= 0:
					_add_benign_clock_debt(run, debt_clock)
				var action := _service(run)
				var option: Dictionary = action.service_hook(service_id)
				var before := _snapshot(run)
				var exact_once_oracle := run.detached_host_action_candidate()
				var response: Dictionary = action.use_hook("service", service_id)
				if int(option.get("cost", -1)) != cost:
					failures.append("GP-PF-001 %s: displayed quote drifted from authored $%d price." % [label, cost])
				if bankroll < cost:
					if bool(option.get("enabled", true)):
						failures.append("GP-PF-001 %s: below-price service remained enabled." % label)
					if bool(response.get("ok", false)) or _snapshot(run) != before:
						failures.append("GP-PF-001 %s: below-price rejection changed the production snapshot." % label)
					continue
				if not bool(option.get("enabled", false)):
					failures.append("GP-PF-001 %s: affordable service was disabled before activation: %s" % [label, JSON.stringify(option)])
					continue
				if not bool(response.get("ok", false)):
					failures.append("GP-PF-001 %s: affordable service rejected: %s" % [label, str(response.get("message", response.get("errors", [])))])
					continue
				_assert_hook_committed_exactly_once(response, run, exact_once_oracle, "service", service_id, cost, "GP-PF-001 %s" % label)

		var rejected_run := _base_run("PAID-ERROR-%s" % service_id, cost * 2, archetype, [service_id], [])
		_set_local_heat(rejected_run, 20)
		rejected_run._turn_transaction_test_failure_stage = "global_start"
		var rejected_before := _snapshot(rejected_run)
		var rejected := _service(rejected_run).use_hook("service", service_id)
		_assert_rejected_unchanged(rejected, rejected_run, rejected_before, "GP-PF-001 %s injected boundary" % service_id)


func _check_free_service_transactions() -> void:
	for service_value in FREE_SERVICES:
		var service_data: Dictionary = service_value
		var service_id := str(service_data.get("id", ""))
		var archetype := str(service_data.get("archetype", "fixture"))
		for debt_clock in [-1, 0, 1, 2]:
			var label := "free service %s debt_clock=%d" % [service_id, debt_clock]
			var normal := _free_service_run("FREE-NORMAL-%s-%d" % [service_id, debt_clock], service_id, archetype)
			if debt_clock >= 0:
				_add_benign_clock_debt(normal, debt_clock)
			var exact_once_oracle := normal.detached_host_action_candidate()
			var normal_response := _service(normal).use_hook("service", service_id)
			if not bool(normal_response.get("ok", false)):
				failures.append("GP-PF-002 %s normal control rejected: %s" % [label, str(normal_response.get("message", ""))])
			else:
				_assert_hook_committed_exactly_once(normal_response, normal, exact_once_oracle, "service", service_id, 0, "GP-PF-002 %s" % label)

		if service_id != "beach_relax":
			var injected := _free_service_run("FREE-ERROR-%s" % service_id, service_id, archetype)
			injected._turn_transaction_test_failure_stage = "global_start"
			var injected_before := _snapshot(injected)
			var injected_response := _service(injected).use_hook("service", service_id)
			_assert_rejected_unchanged(injected_response, injected, injected_before, "GP-PF-002 free service %s injected boundary" % service_id)

		var terminal := _free_service_run("FREE-TERMINAL-%s" % service_id, service_id, archetype)
		if service_id == "beach_relax":
			_set_latent_local_heat(terminal, 100)
		else:
			_set_local_heat(terminal, 96)
			_add_forced_boundary_debt(terminal)
		var terminal_before := _snapshot(terminal)
		var terminal_response := _service(terminal).use_hook("service", service_id)
		_assert_rejected_unchanged(terminal_response, terminal, terminal_before, "GP-PF-002 free service %s terminal boundary" % service_id)

		var closing := _free_service_run("FREE-CLOSING-%s" % service_id, service_id, archetype)
		closing.force_closing_time_travel()
		if closing.closing_time_state.is_empty():
			closing.closing_time_state = {"phase": RunState.CLOSING_TIME_PHASE_FORCED_TRAVEL, "environment_id": str(closing.current_environment.get("id", ""))}
		var closing_before := _snapshot(closing)
		var closing_response := _service(closing).use_hook("service", service_id)
		_assert_rejected_unchanged(closing_response, closing, closing_before, "GP-PF-002 free service %s forced travel" % service_id)

	var zero := _free_service_run("FREE-ZERO-CASH", "call_brother_in_law", "motel")
	zero.bankroll = 0
	var zero_before := _snapshot(zero)
	var zero_response := _service(zero).use_hook("service", "call_brother_in_law")
	_assert_rejected_unchanged(zero_response, zero, zero_before, "GP-PF-002 free service bankroll-zero boundary")


func _check_lender_transactions() -> void:
	for lender_id in DIRECT_LENDERS:
		for debt_clock in [-1, 0, 1, 2]:
			var label := "lender %s debt_clock=%d" % [lender_id, debt_clock]
			var normal := _lender_run("LENDER-NORMAL-%s-%d" % [lender_id, debt_clock], lender_id)
			if debt_clock >= 0:
				_add_benign_clock_debt(normal, debt_clock)
			var exact_once_oracle := normal.detached_host_action_candidate()
			var normal_response := _service(normal).use_hook("lender", lender_id)
			if not bool(normal_response.get("ok", false)):
				failures.append("GP-PF-002 %s normal control rejected: %s" % [label, str(normal_response.get("message", ""))])
			else:
				_assert_hook_committed_exactly_once(normal_response, normal, exact_once_oracle, "lender", lender_id, 0, "GP-PF-002 %s" % label)

		for mode in ["error", "terminal", "closing"]:
			var run := _lender_run("LENDER-%s-%s" % [mode, lender_id], lender_id)
			if mode == "error":
				run._turn_transaction_test_failure_stage = "global_start"
			elif mode == "terminal":
				_set_local_heat(run, 96)
				_add_forced_boundary_debt(run)
			else:
				run.closing_time_state = {"phase": RunState.CLOSING_TIME_PHASE_FORCED_TRAVEL, "environment_id": str(run.current_environment.get("id", ""))}
			var before := _snapshot(run)
			var response := _service(run).use_hook("lender", lender_id)
			_assert_rejected_unchanged(response, run, before, "GP-PF-002 lender %s %s boundary" % [lender_id, mode])

	var zero := _lender_run("LENDER-ZERO-CASH", "motel_friend")
	zero.bankroll = 0
	var zero_before := _snapshot(zero)
	var zero_response := _service(zero).use_hook("lender", "motel_friend")
	_assert_rejected_unchanged(zero_response, zero, zero_before, "GP-PF-002 lender bankroll-zero boundary")


func _check_active_scenario_hook_facts() -> void:
	# One active causal-state control per hook complements the full affordability
	# and debt-clock matrices above. It proves that candidate publication queues
	# one (and only one) production service_result fact for every hook identity.
	for service_value in PAID_SERVICES:
		var service_data: Dictionary = service_value
		var service_id := str(service_data.get("id", ""))
		var cost := int(service_data.get("cost", 0))
		var archetype := str(service_data.get("archetype", "bar"))
		var run := _base_run("FACT-PAID-%s" % service_id, cost * 2, archetype, [service_id], [])
		_set_local_heat(run, 20)
		if not _install_active_service_fact_fixture(run, "paid_%s" % service_id):
			continue
		var oracle := run.detached_host_action_candidate()
		var response := _service(run).use_hook("service", service_id)
		if not bool(response.get("ok", false)):
			failures.append("GP-PF-001 active-scenario %s rejected: %s" % [service_id, str(response.get("message", ""))])
		else:
			_assert_hook_committed_exactly_once(response, run, oracle, "service", service_id, cost, "GP-PF-001 active-scenario %s" % service_id)
		var rejected_run := _base_run("FACT-PAID-REJECT-%s" % service_id, cost * 2, archetype, [service_id], [])
		_set_local_heat(rejected_run, 20)
		if _install_active_service_fact_fixture(rejected_run, "paid_reject_%s" % service_id):
			rejected_run._turn_transaction_test_failure_stage = "global_start"
			var rejected_before := _snapshot(rejected_run)
			var rejected := _service(rejected_run).use_hook("service", service_id)
			_assert_rejected_unchanged(rejected, rejected_run, rejected_before, "GP-PF-001 active-scenario %s injected boundary" % service_id)

	for service_value in FREE_SERVICES:
		var service_data: Dictionary = service_value
		var service_id := str(service_data.get("id", ""))
		var archetype := str(service_data.get("archetype", "bar"))
		var run := _free_service_run("FACT-FREE-%s" % service_id, service_id, archetype)
		if not _install_active_service_fact_fixture(run, "free_%s" % service_id):
			continue
		var oracle := run.detached_host_action_candidate()
		var response := _service(run).use_hook("service", service_id)
		if not bool(response.get("ok", false)):
			failures.append("GP-PF-002 active-scenario free service %s rejected: %s" % [service_id, str(response.get("message", ""))])
		else:
			_assert_hook_committed_exactly_once(response, run, oracle, "service", service_id, 0, "GP-PF-002 active-scenario free service %s" % service_id)
		var rejected_run := _free_service_run("FACT-FREE-REJECT-%s" % service_id, service_id, archetype)
		if _install_active_service_fact_fixture(rejected_run, "free_reject_%s" % service_id):
			if service_id == "beach_relax":
				rejected_run.closing_time_state = {"phase": RunState.CLOSING_TIME_PHASE_FORCED_TRAVEL, "environment_id": str(rejected_run.current_environment.get("id", ""))}
			else:
				rejected_run._turn_transaction_test_failure_stage = "global_start"
			var rejected_before := _snapshot(rejected_run)
			var rejected := _service(rejected_run).use_hook("service", service_id)
			_assert_rejected_unchanged(rejected, rejected_run, rejected_before, "GP-PF-002 active-scenario free service %s rejected boundary" % service_id)

	for lender_id in DIRECT_LENDERS:
		var run := _lender_run("FACT-LENDER-%s" % lender_id, lender_id)
		if not _install_active_service_fact_fixture(run, "lender_%s" % lender_id):
			continue
		var oracle := run.detached_host_action_candidate()
		var response := _service(run).use_hook("lender", lender_id)
		if not bool(response.get("ok", false)):
			failures.append("GP-PF-002 active-scenario lender %s rejected: %s" % [lender_id, str(response.get("message", ""))])
		else:
			_assert_hook_committed_exactly_once(response, run, oracle, "lender", lender_id, 0, "GP-PF-002 active-scenario lender %s" % lender_id)
		var rejected_run := _lender_run("FACT-LENDER-REJECT-%s" % lender_id, lender_id)
		if _install_active_service_fact_fixture(rejected_run, "lender_reject_%s" % lender_id):
			rejected_run._turn_transaction_test_failure_stage = "global_start"
			var rejected_before := _snapshot(rejected_run)
			var rejected := _service(rejected_run).use_hook("lender", lender_id)
			_assert_rejected_unchanged(rejected, rejected_run, rejected_before, "GP-PF-002 active-scenario lender %s injected boundary" % lender_id)


func _check_cage_gift_transactions() -> void:
	var normal := _gift_run("GIFT-NORMAL")
	var normal_story_before := _story_count_for_item(normal, GIFT_ITEM_ID)
	var response := _service(normal).buy_cage_gift_shop_offer(GIFT_ITEM_ID)
	if not bool(response.get("ok", false)) or normal.grand_casino_chips != 10 - GIFT_PRICE or not normal.inventory.has(GIFT_ITEM_ID) or not _gift_offer_sold(normal, GIFT_ITEM_ID):
		failures.append("GP-PF-002 chip gift normal control did not debit, grant, and sell exactly once: %s" % JSON.stringify(response))
	elif _story_count_for_item(normal, GIFT_ITEM_ID) != normal_story_before + 1 or int(normal.current_environment.get("turns", 0)) != 1:
		failures.append("GP-PF-002 chip gift normal control did not advance/story exactly once.")
	for mode in ["error", "terminal", "closing"]:
		var run := _gift_run("GIFT-%s" % mode)
		_prepare_rejection_mode(run, mode)
		var before := _snapshot(run)
		var rejected := _service(run).buy_cage_gift_shop_offer(GIFT_ITEM_ID)
		_assert_rejected_unchanged(rejected, run, before, "GP-PF-002 chip gift %s boundary" % mode)


func _check_pawn_transactions() -> void:
	var normal := _pawn_run("PAWN-NORMAL")
	var action := _service(normal)
	var quote := _quote_for_item(action.pawn_quote_options(), PAWN_ITEM_ID)
	var cash_before := normal.bankroll
	var story_before := _story_count_for_id(normal, "sals_pawn_counter")
	var response := action.pawn_inventory_item(PAWN_ITEM_ID)
	if quote.is_empty() or not bool(response.get("ok", false)) or normal.inventory.has(PAWN_ITEM_ID):
		failures.append("GP-PF-002 pawn normal control rejected or retained collateral: %s" % JSON.stringify(response))
	elif normal.bankroll != cash_before + int(quote.get("loan_amount", 0)) or _debt_count_for_lender(normal, "sals_pawn_counter") != 1:
		failures.append("GP-PF-002 pawn normal control did not grant principal/debt exactly once.")
	elif _story_count_for_id(normal, "sals_pawn_counter") != story_before + 1 or int(normal.current_environment.get("turns", 0)) != 1:
		failures.append("GP-PF-002 pawn normal control did not advance/story exactly once.")
	for mode in ["error", "terminal", "zero", "closing"]:
		var run := _pawn_run("PAWN-%s" % mode)
		_prepare_rejection_mode(run, mode)
		var before := _snapshot(run)
		var rejected := _service(run).pawn_inventory_item(PAWN_ITEM_ID)
		_assert_rejected_unchanged(rejected, run, before, "GP-PF-002 pawn %s boundary" % mode)


func _check_portable_ticket_transactions() -> void:
	for item_id in [RunState.PULL_TAB_PILE_ITEM_ID, RunState.SCRATCH_TICKET_PILE_ITEM_ID]:
		var normal := _ticket_run("TICKET-NORMAL-%s" % item_id, item_id)
		var cash_before := normal.bankroll
		var story_before := _story_count_for_type(normal, "portable_ticket_sal_cashout")
		var response := _service(normal).pawn_inventory_item(item_id)
		if not bool(response.get("ok", false)) or normal.bankroll != cash_before + 5 or int(normal.portable_ticket_pile_summary(item_id).get("winner_count", -1)) != 0:
			failures.append("GP-PF-002 %s normal cashout did not surrender/pay exactly once: %s" % [item_id, JSON.stringify(response)])
		elif _story_count_for_type(normal, "portable_ticket_sal_cashout") != story_before + 1 or int(normal.current_environment.get("turns", 0)) != 1:
			failures.append("GP-PF-002 %s normal cashout did not advance/story exactly once." % item_id)
		for mode in ["error", "terminal", "zero", "closing"]:
			var run := _ticket_run("TICKET-%s-%s" % [mode, item_id], item_id)
			_prepare_rejection_mode(run, mode)
			var before := _snapshot(run)
			var rejected := _service(run).pawn_inventory_item(item_id)
			_assert_rejected_unchanged(rejected, run, before, "GP-PF-002 %s %s boundary" % [item_id, mode])


func _check_nonterminal_forced_repayment_transactions() -> void:
	# Forced repayment is capped at one third of available bankroll. These are
	# deliberately non-terminal controls: the boundary debt consequence and the
	# requested action must commit exactly once rather than being over-rejected.
	var paid_service := _base_run("PAID-BOUNDARY-ZERO", 28, "small_underground_casino", ["punchline_cover_charge"], [])
	_set_local_heat(paid_service, 20)
	_add_forced_repayment_boundary_debt(paid_service, 14)
	var paid_story_before := _story_count_for_id(paid_service, "punchline_cover_charge")
	var paid_response := _service(paid_service).use_hook("service", "punchline_cover_charge")
	if not bool(paid_response.get("ok", false)) or paid_service.run_status != RunState.RUN_STATUS_ACTIVE or paid_service.bankroll != 10:
		failures.append("GP-PF-002 paid service nonterminal forced repayment did not commit with capped payment: %s" % JSON.stringify(paid_response))
	elif _story_count_for_id(paid_service, "punchline_cover_charge") != paid_story_before + 1 or int(paid_service.current_environment.get("turns", 0)) != 1:
		failures.append("GP-PF-002 paid service nonterminal forced repayment did not publish action effects exactly once.")

	var free_service := _free_service_run("FREE-BOUNDARY-ZERO", "call_brother_in_law", "motel")
	_add_forced_repayment_boundary_debt(free_service, free_service.bankroll)
	var free_story_before := _story_count_for_id(free_service, "call_brother_in_law")
	var free_response := _service(free_service).use_hook("service", "call_brother_in_law")
	if not bool(free_response.get("ok", false)) or free_service.run_status != RunState.RUN_STATUS_ACTIVE or free_service.bankroll != 40:
		failures.append("GP-PF-002 free service nonterminal forced repayment did not commit with capped payment: %s" % JSON.stringify(free_response))
	elif _story_count_for_id(free_service, "call_brother_in_law") != free_story_before + 1 or int(free_service.current_environment.get("turns", 0)) != 1:
		failures.append("GP-PF-002 free service nonterminal forced repayment did not publish action effects exactly once.")

	var lender := _lender_run("LENDER-BOUNDARY-ZERO", "motel_friend")
	_add_forced_repayment_boundary_debt(lender, lender.bankroll)
	var lender_story_before := _story_count_for_id(lender, "motel_friend")
	var lender_debt_before := _debt_count_for_lender(lender, "motel_friend")
	var lender_response := _service(lender).use_hook("lender", "motel_friend")
	var lender_result: Dictionary = lender_response.get("result", {}) if typeof(lender_response.get("result", {})) == TYPE_DICTIONARY else {}
	var lender_deltas: Dictionary = lender_result.get("deltas", {}) if typeof(lender_result.get("deltas", {})) == TYPE_DICTIONARY else {}
	var expected_lender_bankroll := 40 + int(lender_deltas.get("bankroll_delta", 0))
	if not bool(lender_response.get("ok", false)) or lender.run_status != RunState.RUN_STATUS_ACTIVE or lender.bankroll != expected_lender_bankroll:
		failures.append("GP-PF-002 lender nonterminal forced repayment did not commit with capped payment: %s" % JSON.stringify(lender_response))
	elif _debt_count_for_lender(lender, "motel_friend") != lender_debt_before + 1 or _story_count_for_id(lender, "motel_friend") != lender_story_before + 1 or int(lender.current_environment.get("turns", 0)) != 1:
		failures.append("GP-PF-002 lender nonterminal forced repayment did not publish reward/debt/story exactly once.")

	var item := _item_purchase_run("ITEM-BOUNDARY-ZERO", 30, 10)
	_add_forced_repayment_boundary_debt(item, 20)
	var item_story_before := _story_count_for_item(item, PAWN_ITEM_ID)
	var item_response := _service(item).buy_item_offer(PAWN_ITEM_ID)
	if not bool(item_response.get("ok", false)) or item.run_status != RunState.RUN_STATUS_ACTIVE or item.bankroll != 14 or _inventory_occurrences(item, PAWN_ITEM_ID) != 1:
		failures.append("GP-PF-002 item nonterminal forced repayment did not commit with capped payment: %s" % JSON.stringify(item_response))
	elif _story_count_for_item(item, PAWN_ITEM_ID) != item_story_before + 1 or int(item.current_environment.get("turns", 0)) != 1:
		failures.append("GP-PF-002 item nonterminal forced repayment did not publish inventory/story exactly once.")


func _check_result_induced_terminal_rollback() -> void:
	# The action boundary itself remains valid at Heat 99; the authored service
	# result adds the terminal point. A success response must never publish that
	# failed candidate as though the transaction committed normally.
	var run := _base_run("SERVICE-RESULT-TERMINAL", 24, "bar", ["house_drink"], [])
	_set_local_heat(run, 99)
	var before := _snapshot(run)
	var response := _service(run).use_hook("service", "house_drink")
	_assert_rejected_unchanged(response, run, before, "GP-PF-002 service result-induced Heat terminal")


func _check_cage_result_induced_terminal_rollback() -> void:
	# Exercise the same post-result atomicity boundary through the Cage's item
	# effect path. The fixture augmentation is in-memory only and is restored
	# before assertions so no later contract observes modified authored content.
	var item_index := -1
	for index in range(library.items.size()):
		var item_value: Variant = library.items[index]
		if typeof(item_value) == TYPE_DICTIONARY and str((item_value as Dictionary).get("id", "")) == GIFT_ITEM_ID:
			item_index = index
			break
	if item_index < 0:
		failures.append("SETUP: GP-PF-002 Cage result-induced terminal fixture could not find %s." % GIFT_ITEM_ID)
		return
	var original_definition: Dictionary = (library.items[item_index] as Dictionary).duplicate(true)
	var terminal_definition := original_definition.duplicate(true)
	var terminal_effect: Dictionary = terminal_definition.get("effect", {}).duplicate(true) if typeof(terminal_definition.get("effect", {})) == TYPE_DICTIONARY else {}
	terminal_effect["suspicion_delta"] = 1
	terminal_definition["effect"] = terminal_effect
	library.items[item_index] = terminal_definition
	library.rebuild_content_indexes()

	var run := _gift_run("GIFT-RESULT-TERMINAL")
	_set_local_heat(run, 99)
	var before := _snapshot(run)
	var response := _service(run).buy_cage_gift_shop_offer(GIFT_ITEM_ID)

	library.items[item_index] = original_definition
	library.rebuild_content_indexes()
	_assert_rejected_unchanged(response, run, before, "GP-PF-002 Cage result-induced Heat terminal")


func _check_terminal_apply_result_guard() -> void:
	var run := _base_run("TERMINAL-APPLY-GUARD", 40, "bar", [], [])
	run.fail_run(RunState.FAILURE_ABANDONED, "Fixture terminal state.")
	var before := _snapshot(run)
	var deltas := GameModuleScript.empty_result_deltas()
	deltas["bankroll_delta"] = 9
	deltas["flags_set"] = {"terminal_apply_leak": true}
	deltas["story_log"] = [{"type": "terminal_apply_leak"}]
	var result := GameModuleScript.build_action_result({"ok": true, "type": "fixture", "source_id": "terminal_guard", "deltas": deltas, "message": "Must not apply."})
	var applied := GameModuleScript.apply_result(run, result)
	if bool(applied.get("ok", false)) or _snapshot(run) != before:
		failures.append("GP-PF-002 GameModule accepted or mutated a non-terminal settlement on an already terminal run.")


func _assert_positive_service_manifest() -> void:
	var expected: Dictionary = {}
	for service_value in PAID_SERVICES:
		var service_data: Dictionary = service_value
		expected[str(service_data.get("id", ""))] = int(service_data.get("cost", 0))
	var actual: Dictionary = {}
	for service_value in library.services:
		if typeof(service_value) != TYPE_DICTIONARY:
			continue
		var service_data := service_value as Dictionary
		var cost := int(service_data.get("cost", 0))
		if cost > 0:
			actual[str(service_data.get("id", ""))] = cost
	if actual.size() != expected.size():
		failures.append("GP-PF-001 positive-price manifest drifted: expected %d services, found %d (%s)." % [expected.size(), actual.size(), JSON.stringify(actual)])
	for service_id_value in expected.keys():
		var service_id := str(service_id_value)
		if int(actual.get(service_id, -1)) != int(expected[service_id_value]):
			failures.append("GP-PF-001 positive-price manifest is missing %s at its authored $%d quote." % [service_id, int(expected[service_id_value])])
	for service_id_value in actual.keys():
		var service_id := str(service_id_value)
		if not expected.has(service_id):
			failures.append("GP-PF-001 positive-price manifest added untested service %s at $%d." % [service_id, int(actual[service_id_value])])


func _assert_zero_service_and_lender_manifests() -> void:
	var expected_free: Dictionary = {}
	for service_value in FREE_SERVICES:
		var service_data: Dictionary = service_value
		expected_free[str(service_data.get("id", ""))] = str(service_data.get("archetype", ""))
	var actual_free: Dictionary = {}
	for service_value in library.services:
		if typeof(service_value) != TYPE_DICTIONARY:
			continue
		var service_data := service_value as Dictionary
		if int(service_data.get("cost", 0)) == 0:
			actual_free[str(service_data.get("id", ""))] = true
	if actual_free.size() != expected_free.size():
		failures.append("GP-PF-002 zero-price service manifest drifted: expected %d, found %d (%s)." % [expected_free.size(), actual_free.size(), JSON.stringify(actual_free)])
	for service_id_value in expected_free.keys():
		var service_id := str(service_id_value)
		if not actual_free.has(service_id):
			failures.append("GP-PF-002 zero-price service manifest is missing %s." % service_id)
	for service_id_value in actual_free.keys():
		var service_id := str(service_id_value)
		if not expected_free.has(service_id):
			failures.append("GP-PF-002 zero-price service manifest added untested service %s." % service_id)

	var expected_direct: Dictionary = {}
	for lender_id in DIRECT_LENDERS:
		expected_direct[str(lender_id)] = true
	var actual_direct: Dictionary = {}
	var pawn_ids: Array[String] = []
	for lender_value in library.lenders:
		if typeof(lender_value) != TYPE_DICTIONARY:
			continue
		var lender_data := lender_value as Dictionary
		var lender_id := str(lender_data.get("id", ""))
		if str(lender_data.get("lender_type", "")) == "pawn":
			pawn_ids.append(lender_id)
		else:
			actual_direct[lender_id] = true
	if actual_direct.size() != expected_direct.size():
		failures.append("GP-PF-002 direct-lender manifest drifted: expected %s, found %s." % [JSON.stringify(expected_direct), JSON.stringify(actual_direct)])
	for lender_id_value in expected_direct.keys():
		if not actual_direct.has(str(lender_id_value)):
			failures.append("GP-PF-002 direct-lender manifest is missing %s." % str(lender_id_value))
	for lender_id_value in actual_direct.keys():
		if not expected_direct.has(str(lender_id_value)):
			failures.append("GP-PF-002 direct-lender manifest added untested lender %s." % str(lender_id_value))
	pawn_ids.sort()
	if pawn_ids.size() != 1 or pawn_ids[0] != "sals_pawn_counter":
		failures.append("GP-PF-002 pawn-lender manifest drifted: expected only sals_pawn_counter, found %s." % JSON.stringify(pawn_ids))


# Builds the accepted state independently from the pre-action snapshot: reserve
# the quote once, advance the authored boundary once, apply the rebuilt result
# once, publish one service fact, and then compare the complete save payload.
# This catches duplicate or omitted effects even when the API still says success.
func _assert_hook_committed_exactly_once(response: Dictionary, run: RunState, exact_once_oracle: RunState, kind: String, hook_id: String, quoted_price: int, label: String) -> void:
	if exact_once_oracle == null:
		failures.append("%s could not create the exact-once oracle snapshot." % label)
		return
	var definition := library.service(hook_id).duplicate(true) if kind == "service" else library.lender(hook_id).duplicate(true)
	if definition.is_empty():
		failures.append("%s lost its authored definition before exact-once qualification." % label)
		return
	var initial_bankroll := exact_once_oracle.bankroll
	var initial_turns := int(exact_once_oracle.current_environment.get("turns", 0))
	var initial_clock := exact_once_oracle.game_clock_minutes
	var initial_action_index := exact_once_oracle._crew_action_index()
	var initial_inventory := exact_once_oracle.inventory.duplicate(true)
	var initial_crew_trust := exact_once_oracle.crew_trust("crew_rook")
	var initial_scenario_state := JSON.stringify(exact_once_oracle.current_environment.get("scenario_sequence_state", {}))
	var actual_result: Dictionary = response.get("result", {}) if typeof(response.get("result", {})) == TYPE_DICTIONARY else {}
	var actual_deltas: Dictionary = actual_result.get("deltas", {}) if typeof(actual_result.get("deltas", {})) == TYPE_DICTIONARY else {}
	if actual_result.is_empty():
		failures.append("%s returned success without a structured result." % label)
		return

	if quoted_price > 0:
		exact_once_oracle.change_bankroll(-quoted_price, true)
	var duration_minutes := maxi(0, int(definition.get("duration_minutes", 0))) if kind == "service" else 0
	var boundary_result := exact_once_oracle.advance_game_clock_minutes(duration_minutes) if duration_minutes > 0 else exact_once_oracle.advance_environment_turns(1)
	if not bool(boundary_result.get("ok", false)):
		failures.append("%s exact-once oracle boundary rejected: %s" % [label, JSON.stringify(boundary_result)])
		return
	exact_once_oracle.evaluate_immediate_terminal_state(quoted_price > 0)
	if exact_once_oracle.is_terminal() or exact_once_oracle.closing_time_forced_travel_required():
		failures.append("%s accepted control unexpectedly ended during its oracle boundary." % label)
		return
	var boundary_story_count := exact_once_oracle.story_log.size()
	var boundary_debt_count := exact_once_oracle.debt.size()
	var boundary_fact_count := _scenario_service_fact_count(exact_once_oracle, kind, hook_id)
	var boundary_bankroll := exact_once_oracle.bankroll
	var oracle_action := _service(exact_once_oracle)
	var live_option := oracle_action.hook_option(kind, hook_id, "", quoted_price)
	if live_option.is_empty() or not bool(live_option.get("enabled", false)) or int(live_option.get("cost", -1)) != quoted_price:
		failures.append("%s exact-once oracle could not revalidate the quoted hook: %s" % [label, JSON.stringify(live_option)])
		return
	var expected_result := oracle_action.hook_result(kind, hook_id, quoted_price)
	if expected_result.is_empty():
		failures.append("%s exact-once oracle could not rebuild the authored result." % label)
		return
	var expected_deltas: Dictionary = expected_result.get("deltas", {}) if typeof(expected_result.get("deltas", {})) == TYPE_DICTIONARY else {}
	if JSON.stringify(actual_result) != JSON.stringify(expected_result):
		failures.append("%s returned a result different from the post-boundary authored result." % label)
	_assert_resolved_authored_effects_in_result(definition, expected_deltas, actual_deltas, label)

	var applied_result := expected_result.duplicate(true)
	var applied_deltas: Dictionary = applied_result.get("deltas", {}).duplicate(true) if typeof(applied_result.get("deltas", {})) == TYPE_DICTIONARY else {}
	if quoted_price > 0:
		applied_deltas["bankroll_delta"] = int(applied_deltas.get("bankroll_delta", 0)) + quoted_price
		applied_result["deltas"] = applied_deltas
		applied_result["bankroll_delta"] = int(applied_deltas.get("bankroll_delta", 0))
		applied_result["defer_bankroll_zero_failure"] = true
	var applied := GameModuleScript.apply_result(exact_once_oracle, applied_result)
	if not bool(applied.get("ok", false)):
		failures.append("%s exact-once oracle could not apply its authored result: %s" % [label, JSON.stringify(applied)])
		return
	if exact_once_oracle.is_terminal() or exact_once_oracle.closing_time_forced_travel_required():
		failures.append("%s exact-once oracle became terminal after its authored result." % label)
		return
	if kind == "lender" and hook_id == "the_crew":
		oracle_action.call("_apply_crew_loan_trust", definition)
	exact_once_oracle.scenario_publish_service_result(kind, hook_id, applied_result)

	var expected_snapshot := _exact_once_snapshot(exact_once_oracle)
	var actual_snapshot := _exact_once_snapshot(run)
	if actual_snapshot != expected_snapshot:
		failures.append("%s did not equal one boundary plus one authored result byte-for-byte (%s)." % [label, _snapshot_first_difference(actual_snapshot, expected_snapshot)])
	if run.run_status != RunState.RUN_STATUS_ACTIVE:
		failures.append("%s reported success with final run status %s." % [label, run.run_status])
	if run.bankroll != boundary_bankroll + int(applied_deltas.get("bankroll_delta", 0)):
		failures.append("%s did not compose its boundary cash movement and quoted price/reward exactly once: started $%d, boundary $%d, applied delta %d, finished $%d." % [label, initial_bankroll, boundary_bankroll, int(applied_deltas.get("bankroll_delta", 0)), run.bankroll])
	if kind == "service" and quoted_price > 0 and int(actual_deltas.get("bankroll_delta", 0)) != -quoted_price:
		failures.append("%s result did not retain the exact single $%d debit." % [label, quoted_price])
	if duration_minutes > 0:
		if run.game_clock_minutes != initial_clock + duration_minutes or int(run.current_environment.get("turns", 0)) != initial_turns or run._crew_action_index() != initial_action_index:
			failures.append("%s did not advance its %d-minute clock boundary exactly once." % [label, duration_minutes])
	elif int(run.current_environment.get("turns", 0)) != initial_turns + 1 or run._crew_action_index() != initial_action_index + 1:
		failures.append("%s did not advance its action boundary exactly once." % label)

	var result_story: Array = actual_deltas.get("story_log", []) if typeof(actual_deltas.get("story_log", [])) == TYPE_ARRAY else []
	if run.story_log.size() != boundary_story_count + result_story.size():
		failures.append("%s did not commit its boundary and result story rows exactly once." % label)
	for story_value in result_story:
		if typeof(story_value) != TYPE_DICTIONARY:
			continue
		var before_count := _dictionary_occurrences(exact_once_oracle.story_log.slice(0, boundary_story_count), story_value as Dictionary)
		var after_count := _dictionary_occurrences(run.story_log, story_value as Dictionary)
		var authored_count := _dictionary_occurrences(result_story, story_value as Dictionary)
		if after_count != before_count + authored_count:
			failures.append("%s did not commit one exact copy of an authored story row." % label)

	var result_flags: Dictionary = actual_deltas.get("flags_set", {}) if typeof(actual_deltas.get("flags_set", {})) == TYPE_DICTIONARY else {}
	for flag_value in result_flags.keys():
		var flag_id := str(flag_value)
		if run.narrative_flags.get(flag_id, null) != result_flags[flag_value]:
			failures.append("%s did not commit authored flag %s exactly." % [label, flag_id])
	for item_value in actual_deltas.get("inventory_add", []):
		var item_id := str(item_value)
		var initial_count := _inventory_occurrences_in(initial_inventory, item_id)
		var authored_count := _string_occurrences(actual_deltas.get("inventory_add", []), item_id)
		if _inventory_occurrences(run, item_id) != initial_count + authored_count:
			failures.append("%s did not add inventory item %s exactly %d time(s)." % [label, item_id, authored_count])
	var result_debt: Array = actual_deltas.get("debt_changes", []) if typeof(actual_deltas.get("debt_changes", [])) == TYPE_ARRAY else []
	if run.debt.size() != boundary_debt_count + result_debt.size():
		failures.append("%s did not commit its debt reward exactly once." % label)
	if kind == "lender" and hook_id == "the_crew" and (run.crew_trust("crew_rook") != exact_once_oracle.crew_trust("crew_rook") or run.crew_trust("crew_rook") <= initial_crew_trust):
		failures.append("%s did not commit its candidate-owned Crew trust reward exactly once." % label)
	var final_fact_count := _scenario_service_fact_count(run, kind, hook_id)
	var oracle_fact_count := _scenario_service_fact_count(exact_once_oracle, kind, hook_id)
	if final_fact_count != oracle_fact_count or oracle_fact_count - boundary_fact_count < 0 or oracle_fact_count - boundary_fact_count > 1:
		failures.append("%s did not preserve the exact-once scenario service fact contract." % label)
	if initial_scenario_state != "{}" and oracle_fact_count != boundary_fact_count + 1:
		failures.append("%s active scenario did not receive exactly one service_result fact." % label)
	if initial_scenario_state != "{}" and not _scenario_service_fact_payloads_valid(run, kind, hook_id, str(actual_result.get("action_id", ""))):
		failures.append("%s active scenario received a malformed service_result fact payload." % label)
	_assert_effect_projection_matches(run, exact_once_oracle, label)


func _assert_nonhook_committed_exactly_once(response: Dictionary, run: RunState, exact_once_oracle: RunState, descriptor: Dictionary, label: String) -> void:
	if exact_once_oracle == null:
		failures.append("%s could not create the exact-once oracle snapshot." % label)
		return
	var actual_result: Dictionary = response.get("result", {}) if typeof(response.get("result", {})) == TYPE_DICTIONARY else {}
	if actual_result.is_empty():
		failures.append("%s returned success without a structured result." % label)
		return

	var action_type := str(descriptor.get("action_type", ""))
	var action_id := str(descriptor.get("id", ""))
	var quoted_price := maxi(0, int(descriptor.get("cost", 0)))
	var initial_bankroll := exact_once_oracle.bankroll
	var initial_chips := exact_once_oracle.grand_casino_chips
	var initial_turns := int(exact_once_oracle.current_environment.get("turns", 0))
	var initial_action_index := exact_once_oracle._crew_action_index()
	var initial_inventory := exact_once_oracle.inventory.duplicate(true)
	var initial_scenario_state := JSON.stringify(exact_once_oracle.current_environment.get("scenario_sequence_state", {}))
	var initial_world_fact_count := _scenario_fact_count(exact_once_oracle, "world_boundary")
	var candidate_service := _service(exact_once_oracle)
	var boundary_result: Dictionary = {}
	var expected_result: Dictionary = {}
	var shape_context: Dictionary = {}

	match action_type:
		"cage":
			if exact_once_oracle.grand_casino_chips < quoted_price:
				failures.append("%s oracle could not reserve the quoted chip price." % label)
				return
			exact_once_oracle.change_grand_casino_chips(-quoted_price, true)
			boundary_result = exact_once_oracle.advance_environment_turns(1)
			if not _qualify_nonhook_oracle_boundary(exact_once_oracle, boundary_result, label):
				return
			candidate_service = _service(exact_once_oracle)
			var offer: Dictionary = {}
			for offer_value in candidate_service.cage_gift_shop_offer_view_list():
				if typeof(offer_value) == TYPE_DICTIONARY and str((offer_value as Dictionary).get("item_id", "")) == action_id:
					offer = (offer_value as Dictionary).duplicate(true)
					break
			var definition := library.item(action_id)
			if offer.is_empty() or definition.is_empty():
				failures.append("%s oracle lost its post-boundary Cage offer or item definition." % label)
				return
			var item_effect := ItemEffectScript.new()
			item_effect.setup(definition)
			shape_context["effect_result"] = item_effect.apply({
				"domain": str(definition.get("domain", "global")),
				"domains": [str(definition.get("domain", "global")), "global"],
				"environment_id": str(exact_once_oracle.current_environment.get("id", "")),
				"action_id": "buy_item",
			})
			expected_result = candidate_service._cage_gift_purchase_result(action_id, offer, definition)
			shape_context["definition"] = definition
		"pawn":
			boundary_result = exact_once_oracle.advance_environment_turns(1)
			if not _qualify_nonhook_oracle_boundary(exact_once_oracle, boundary_result, label):
				return
			candidate_service = _service(exact_once_oracle)
			var definition := library.lender("sals_pawn_counter")
			var status := candidate_service.hook_run_status("lender", definition)
			var quote := _quote_for_item(candidate_service.pawn_quote_options(), action_id)
			if definition.is_empty() or quote.is_empty() or not bool(status.get("available", false)):
				failures.append("%s oracle lost its post-boundary pawn quote." % label)
				return
			expected_result = candidate_service._dynamic_lender_result("sals_pawn_counter", definition, status, quote)
			shape_context["quote"] = quote
		"ticket":
			var surrendered := exact_once_oracle.surrender_portable_ticket_winners_to_sal(action_id)
			if not bool(surrendered.get("ok", false)):
				failures.append("%s oracle could not surrender its portable winners: %s" % [label, JSON.stringify(surrendered)])
				return
			boundary_result = exact_once_oracle.advance_environment_turns(1)
			if not _qualify_nonhook_oracle_boundary(exact_once_oracle, boundary_result, label):
				return
			candidate_service = _service(exact_once_oracle)
			expected_result = candidate_service._portable_ticket_cashout_result(action_id, "sals_pawn_counter", surrendered)
			shape_context["surrendered"] = surrendered
		"cash_item":
			if exact_once_oracle.bankroll < quoted_price:
				failures.append("%s oracle could not reserve the quoted cash price." % label)
				return
			if quoted_price > 0:
				exact_once_oracle.change_bankroll(-quoted_price, true)
			boundary_result = exact_once_oracle.advance_environment_turns(1)
			if not _qualify_nonhook_oracle_boundary(exact_once_oracle, boundary_result, label, quoted_price > 0):
				return
			candidate_service = _service(exact_once_oracle)
			var offer := candidate_service.item_offer(action_id)
			var definition := library.item(action_id)
			if offer.is_empty() or definition.is_empty():
				failures.append("%s oracle lost its post-boundary cash offer or item definition." % label)
				return
			var item_effect := ItemEffectScript.new()
			item_effect.setup(definition)
			var effect_result: Dictionary = item_effect.apply({
				"domain": str(definition.get("domain", "global")),
				"domains": [str(definition.get("domain", "global")), "global"],
				"environment_id": str(exact_once_oracle.current_environment.get("id", "")),
				"action_id": "buy_item",
			})
			expected_result = candidate_service.purchase_item_result(effect_result, definition, offer)
			shape_context["effect_result"] = effect_result
		_:
			failures.append("%s has unknown non-hook descriptor %s." % [label, action_type])
			return

	if expected_result.is_empty():
		failures.append("%s oracle could not rebuild the post-boundary result." % label)
		return
	_assert_nonhook_result_shape(actual_result, descriptor, shape_context, label)
	var expected_deltas: Dictionary = expected_result.get("deltas", {}).duplicate(true) if typeof(expected_result.get("deltas", {})) == TYPE_DICTIONARY else {}

	var boundary_bankroll := exact_once_oracle.bankroll
	var boundary_chips := exact_once_oracle.grand_casino_chips
	# Pawn and portable-ticket production applies the authored dictionary itself,
	# so authoritative settlement metadata (including currency) is part of the
	# returned response. Cash and Cage transactions instead apply a compensated
	# clone because their quoted price was already reserved before the boundary.
	var applied_result := expected_result if action_type in ["pawn", "ticket"] else expected_result.duplicate(true)
	var applied_deltas := candidate_service.copy_result_deltas(applied_result.get("deltas", {}))
	if action_type == "cage":
		applied_deltas["chips_delta"] = int(applied_deltas.get("chips_delta", 0)) + quoted_price
		applied_result["deltas"] = applied_deltas
		applied_result["chips_delta"] = int(applied_deltas.get("chips_delta", 0))
	elif action_type == "cash_item":
		applied_deltas["bankroll_delta"] = int(applied_deltas.get("bankroll_delta", 0)) + quoted_price
		applied_result["deltas"] = applied_deltas
		applied_result["bankroll_delta"] = int(applied_deltas.get("bankroll_delta", 0))
		applied_result["defer_bankroll_zero_failure"] = quoted_price > 0
	var applied := GameModuleScript.apply_result(exact_once_oracle, applied_result)
	if not bool(applied.get("ok", false)):
		failures.append("%s oracle could not apply its authored result: %s" % [label, JSON.stringify(applied)])
		return
	if exact_once_oracle.is_terminal() or exact_once_oracle.closing_time_forced_travel_required():
		failures.append("%s oracle became terminal after its authored result." % label)
		return
	var actual_result_json := JSON.stringify(actual_result)
	var expected_result_json := JSON.stringify(expected_result)
	if actual_result_json != expected_result_json:
		failures.append("%s returned a result different from the post-boundary authored result (%s)." % [label, _snapshot_first_difference(actual_result_json, expected_result_json)])
	if action_type == "cage":
		var definition := library.item(action_id)
		if candidate_service._definition_is_active_item(definition):
			candidate_service._auto_select_active_item_after_gain(action_id)
		candidate_service._mark_cage_gift_shop_offer_sold(action_id)
	elif action_type == "cash_item":
		exact_once_oracle.remove_item_offer(action_id)
		var definition := library.item(action_id)
		if candidate_service._definition_is_active_item(definition):
			candidate_service._auto_select_active_item_after_gain(action_id)

	var expected_snapshot := _exact_once_snapshot(exact_once_oracle)
	var actual_snapshot := _exact_once_snapshot(run)
	if actual_snapshot != expected_snapshot:
		failures.append("%s did not equal one boundary plus one authored result byte-for-byte (%s)." % [label, _snapshot_first_difference(actual_snapshot, expected_snapshot)])
	if run.run_status != RunState.RUN_STATUS_ACTIVE:
		failures.append("%s reported success with final run status %s." % [label, run.run_status])
	if int(run.current_environment.get("turns", 0)) != initial_turns + 1 or run._crew_action_index() != initial_action_index + 1:
		failures.append("%s did not advance its action boundary exactly once." % label)
	if run.bankroll != boundary_bankroll + int(applied_deltas.get("bankroll_delta", 0)):
		failures.append("%s did not apply its cash delta exactly once (initial=%d boundary=%d final=%d)." % [label, initial_bankroll, boundary_bankroll, run.bankroll])
	if run.grand_casino_chips != boundary_chips + int(applied_deltas.get("chips_delta", 0)):
		failures.append("%s did not apply its chip delta exactly once (initial=%d boundary=%d final=%d)." % [label, initial_chips, boundary_chips, run.grand_casino_chips])
	var expected_item_count := _inventory_occurrences_in(initial_inventory, action_id)
	expected_item_count += _string_occurrences(expected_deltas.get("inventory_add", []), action_id)
	expected_item_count -= _string_occurrences(expected_deltas.get("inventory_remove", []), action_id)
	if action_type != "ticket" and _inventory_occurrences(run, action_id) != expected_item_count:
		failures.append("%s did not apply the item occurrence delta exactly once." % label)
	if action_type == "cage" and not _gift_offer_sold(run, action_id):
		failures.append("%s did not mark exactly the purchased Cage stock entry sold." % label)
	if action_type == "cash_item" and not _service(run).item_offer(action_id).is_empty():
		failures.append("%s did not remove its purchased cash offer exactly once." % label)
	var oracle_world_fact_count := _scenario_fact_count(exact_once_oracle, "world_boundary")
	var final_world_fact_count := _scenario_fact_count(run, "world_boundary")
	if final_world_fact_count != oracle_world_fact_count:
		failures.append("%s did not preserve the exact-once world-boundary fact contract." % label)
	if initial_scenario_state != "{}" and oracle_world_fact_count != initial_world_fact_count + 1:
		failures.append("%s active scenario did not receive exactly one world_boundary fact." % label)


func _qualify_nonhook_oracle_boundary(run: RunState, boundary_result: Dictionary, label: String, defer_bankroll_zero: bool = false) -> bool:
	if not bool(boundary_result.get("ok", false)):
		failures.append("%s oracle boundary rejected: %s" % [label, JSON.stringify(boundary_result)])
		return false
	run.evaluate_immediate_terminal_state(defer_bankroll_zero)
	if run.is_terminal() or run.closing_time_forced_travel_required():
		failures.append("%s accepted control unexpectedly ended during its oracle boundary." % label)
		return false
	return true


func _assert_nonhook_result_shape(result: Dictionary, descriptor: Dictionary, shape_context: Dictionary, label: String) -> void:
	var action_type := str(descriptor.get("action_type", ""))
	var action_id := str(descriptor.get("id", ""))
	var price := maxi(0, int(descriptor.get("cost", 0)))
	var deltas: Dictionary = result.get("deltas", {}) if typeof(result.get("deltas", {})) == TYPE_DICTIONARY else {}
	var story: Array = deltas.get("story_log", []) if typeof(deltas.get("story_log", [])) == TYPE_ARRAY else []
	match action_type:
		"cage", "cash_item":
			var effect_result: Dictionary = shape_context.get("effect_result", {}) if typeof(shape_context.get("effect_result", {})) == TYPE_DICTIONARY else {}
			var effect_deltas: Dictionary = effect_result.get("deltas", {}) if typeof(effect_result.get("deltas", {})) == TYPE_DICTIONARY else {}
			for key_value in GameModuleScript.empty_result_deltas().keys():
				var key := str(key_value)
				if key in ["bankroll_delta", "chips_delta", "inventory_add", "story_log", "messages"]:
					continue
				if JSON.stringify(deltas.get(key)) != JSON.stringify(effect_deltas.get(key)):
					failures.append("%s item effect delta %s drifted before its one transaction wrapper." % [label, key])
			if _string_occurrences(deltas.get("inventory_add", []), action_id) != 1:
				failures.append("%s result did not author exactly one purchased inventory item." % label)
			if _story_occurrences_in(story, "item_purchase", action_id, "item_id") != 1:
				failures.append("%s result did not author exactly one item-purchase story row." % label)
			if action_type == "cage":
				if int(deltas.get("chips_delta", 0)) != -price or int(deltas.get("bankroll_delta", 0)) != 0:
					failures.append("%s Cage result did not author one chip debit and zero cash debit." % label)
			else:
				if int(deltas.get("bankroll_delta", 0)) != int(effect_deltas.get("bankroll_delta", 0)) - price:
					failures.append("%s cash-item result did not author exactly one quoted debit." % label)
		"pawn":
			var quote: Dictionary = shape_context.get("quote", {}) if typeof(shape_context.get("quote", {})) == TYPE_DICTIONARY else {}
			var debt_changes: Array = deltas.get("debt_changes", []) if typeof(deltas.get("debt_changes", [])) == TYPE_ARRAY else []
			if _string_occurrences(deltas.get("inventory_remove", []), action_id) != 1 or debt_changes.size() != 1 or typeof(debt_changes[0]) != TYPE_DICTIONARY:
				failures.append("%s pawn result did not author one collateral removal and one debt." % label)
			else:
				var debt_entry := debt_changes[0] as Dictionary
				var loan_amount := int(quote.get("loan_amount", -1))
				if int(deltas.get("bankroll_delta", -2)) != loan_amount or int(debt_entry.get("principal", -3)) != loan_amount or str(debt_entry.get("lender_id", "")) != "sals_pawn_counter" or str(debt_entry.get("collateral_item_id", "")) != action_id:
					failures.append("%s pawn result drifted from its one quote/principal/collateral contract." % label)
			if _story_occurrences_in(story, "lender_hook", "sals_pawn_counter", "id") != 1:
				failures.append("%s pawn result did not author exactly one lender story row." % label)
		"ticket":
			var surrendered: Dictionary = shape_context.get("surrendered", {}) if typeof(shape_context.get("surrendered", {})) == TYPE_DICTIONARY else {}
			var ticket_debt: Array = deltas.get("debt_changes", []) if typeof(deltas.get("debt_changes", [])) == TYPE_ARRAY else ["malformed"]
			var ticket_add: Array = deltas.get("inventory_add", []) if typeof(deltas.get("inventory_add", [])) == TYPE_ARRAY else ["malformed"]
			var ticket_remove: Array = deltas.get("inventory_remove", []) if typeof(deltas.get("inventory_remove", [])) == TYPE_ARRAY else ["malformed"]
			if not ticket_debt.is_empty() or not ticket_add.is_empty() or not ticket_remove.is_empty():
				failures.append("%s ticket cashout authored unrelated debt or inventory deltas." % label)
			if int(deltas.get("bankroll_delta", -1)) != int(surrendered.get("cash_value", -2)) or _story_occurrences_in(story, "portable_ticket_sal_cashout", action_id, "item_id") != 1:
				failures.append("%s ticket cashout did not author one exact payout/story row." % label)
			else:
				for story_value in story:
					if typeof(story_value) != TYPE_DICTIONARY or str((story_value as Dictionary).get("type", "")) != "portable_ticket_sal_cashout":
						continue
					var row := story_value as Dictionary
					if str(row.get("lender_id", "")) != "sals_pawn_counter" or int(row.get("ticket_count", -1)) != int(surrendered.get("ticket_count", -2)) or int(row.get("face_value", -1)) != int(surrendered.get("face_value", -2)) or int(row.get("bankroll_delta", -1)) != int(surrendered.get("cash_value", -2)):
						failures.append("%s ticket cashout story payload drifted from surrendered winners." % label)



# Hook resolution is the authoritative authoring boundary. Jazz services derive
# local flags/rewards from the live post-boundary state, while profile lenders
# derive principal, debt, and flags from debt_profile rather than copying the
# legacy effect dictionary verbatim. Compare every canonical resolved delta to
# the independently rebuilt oracle result; raw effect equality would reject
# those intentional transforms and would not describe what GameModule applies.
func _assert_resolved_authored_effects_in_result(definition: Dictionary, expected_deltas: Dictionary, actual_deltas: Dictionary, label: String) -> void:
	for key_value in GameModuleScript.empty_result_deltas().keys():
		var key := str(key_value)
		if JSON.stringify(actual_deltas.get(key)) != JSON.stringify(expected_deltas.get(key)):
			failures.append("%s resolved authored delta %s drifted (actual=%s expected=%s)." % [label, key, JSON.stringify(actual_deltas.get(key)), JSON.stringify(expected_deltas.get(key))])
	var result_debt: Array = actual_deltas.get("debt_changes", []) if typeof(actual_deltas.get("debt_changes", [])) == TYPE_ARRAY else []
	var debt_profile: Dictionary = definition.get("debt_profile", {}) if typeof(definition.get("debt_profile", {})) == TYPE_DICTIONARY else {}
	if not debt_profile.is_empty():
		if result_debt.is_empty() or typeof(result_debt[0]) != TYPE_DICTIONARY:
			failures.append("%s result omitted its profile-authored debt reward." % label)
		else:
			var result_entry := result_debt[0] as Dictionary
			var lender_id := str(definition.get("id", ""))
			if str(result_entry.get("lender_id", "")) != lender_id \
					or int(result_entry.get("deadline_turns", -1)) != int(debt_profile.get("deadline_turns", -2)) \
					or int(result_entry.get("principal", -1)) != int(actual_deltas.get("bankroll_delta", -2)):
				failures.append("%s result drifted from its lender profile principal/deadline/owner." % label)


func _assert_effect_projection_matches(run: RunState, expected: RunState, label: String) -> void:
	var actual := {
		"heat": run.suspicion_level(),
		"drunk": run.drunk_level,
		"pending_drunk": run.pending_drunk_absorption_amount(),
		"alcoholic": run.alcoholic_level,
		"luck": run.baseline_luck,
		"cooldown_actions": run.active_heat_cooldown_actions(),
		"cooldown_per_action": run.active_heat_cooldown_per_action(),
		"flags": run.narrative_flags,
		"story_flags": run.story_flags,
		"inventory": run.inventory,
		"debt": run.debt,
	}
	var oracle := {
		"heat": expected.suspicion_level(),
		"drunk": expected.drunk_level,
		"pending_drunk": expected.pending_drunk_absorption_amount(),
		"alcoholic": expected.alcoholic_level,
		"luck": expected.baseline_luck,
		"cooldown_actions": expected.active_heat_cooldown_actions(),
		"cooldown_per_action": expected.active_heat_cooldown_per_action(),
		"flags": expected.narrative_flags,
		"story_flags": expected.story_flags,
		"inventory": expected.inventory,
		"debt": expected.debt,
	}
	if JSON.stringify(actual) != JSON.stringify(oracle):
		failures.append("%s Heat/drunk/luck/flag/inventory/debt effects did not match one authored application." % label)


func _scenario_service_fact_count(run: RunState, kind: String, hook_id: String) -> int:
	var state: Dictionary = run.current_environment.get("scenario_sequence_state", {}) if typeof(run.current_environment.get("scenario_sequence_state", {})) == TYPE_DICTIONARY else {}
	var count := 0
	for collection_key in ["fact_queue", "fact_receipt_records"]:
		var values: Array = state.get(collection_key, []) if typeof(state.get(collection_key, [])) == TYPE_ARRAY else []
		for value in values:
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var envelope: Dictionary = value as Dictionary
			if collection_key == "fact_receipt_records":
				envelope = envelope.get("envelope", {}) if typeof(envelope.get("envelope", {})) == TYPE_DICTIONARY else {}
			var payload: Dictionary = envelope.get("payload", {}) if typeof(envelope.get("payload", {})) == TYPE_DICTIONARY else {}
			if str(envelope.get("fact_type", "")) == "service_result" and str(payload.get("kind", "")) == kind and str(payload.get("service_id", "")) == hook_id:
				count += 1
	return count


func _scenario_fact_count(run: RunState, fact_type: String) -> int:
	var state: Dictionary = run.current_environment.get("scenario_sequence_state", {}) if typeof(run.current_environment.get("scenario_sequence_state", {})) == TYPE_DICTIONARY else {}
	var count := 0
	for collection_key in ["fact_queue", "fact_receipt_records"]:
		var values: Array = state.get(collection_key, []) if typeof(state.get(collection_key, [])) == TYPE_ARRAY else []
		for value in values:
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var envelope: Dictionary = value as Dictionary
			if collection_key == "fact_receipt_records":
				envelope = envelope.get("envelope", {}) if typeof(envelope.get("envelope", {})) == TYPE_DICTIONARY else {}
			if str(envelope.get("fact_type", "")) == fact_type:
				count += 1
	return count


func _scenario_service_fact_payloads_valid(run: RunState, kind: String, hook_id: String, action_id: String) -> bool:
	var state: Dictionary = run.current_environment.get("scenario_sequence_state", {}) if typeof(run.current_environment.get("scenario_sequence_state", {})) == TYPE_DICTIONARY else {}
	var matched := 0
	for collection_key in ["fact_queue", "fact_receipt_records"]:
		var values: Array = state.get(collection_key, []) if typeof(state.get(collection_key, [])) == TYPE_ARRAY else []
		for value in values:
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var envelope: Dictionary = value as Dictionary
			if collection_key == "fact_receipt_records":
				envelope = envelope.get("envelope", {}) if typeof(envelope.get("envelope", {})) == TYPE_DICTIONARY else {}
			var payload: Dictionary = envelope.get("payload", {}) if typeof(envelope.get("payload", {})) == TYPE_DICTIONARY else {}
			if str(envelope.get("fact_type", "")) != "service_result" or str(payload.get("kind", "")) != kind or str(payload.get("service_id", "")) != hook_id:
				continue
			matched += 1
			if not bool(payload.get("ok", false)) or str(payload.get("action_id", "")) != action_id:
				return false
	return matched == 1


func _dictionary_occurrences(values: Array, target: Dictionary) -> int:
	var target_json := JSON.stringify(target)
	var count := 0
	for value in values:
		if typeof(value) == TYPE_DICTIONARY and JSON.stringify(value) == target_json:
			count += 1
	return count


func _story_occurrences_in(values: Array, story_type: String, identity: String, identity_key: String) -> int:
	var count := 0
	for value in values:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("type", "")) == story_type and str((value as Dictionary).get(identity_key, "")) == identity:
			count += 1
	return count


func _inventory_occurrences_in(values: Array, item_id: String) -> int:
	var count := 0
	for value in values:
		var current_id := str((value as Dictionary).get("id", "")) if typeof(value) == TYPE_DICTIONARY else str(value)
		if current_id == item_id:
			count += 1
	return count


func _string_occurrences(values: Variant, target: String) -> int:
	if typeof(values) != TYPE_ARRAY:
		return 0
	var count := 0
	for value in values as Array:
		if str(value) == target:
			count += 1
	return count


func _prepare_rejection_mode(run: RunState, mode: String) -> void:
	match mode:
		"error":
			run._turn_transaction_test_failure_stage = "global_start"
		"terminal":
			_set_local_heat(run, 96)
			_add_forced_boundary_debt(run)
		"zero":
			run.bankroll = 0
		"closing":
			run.closing_time_state = {"phase": RunState.CLOSING_TIME_PHASE_FORCED_TRAVEL, "environment_id": str(run.current_environment.get("id", ""))}


func _assert_rejected_unchanged(response: Dictionary, run: RunState, before: String, label: String) -> void:
	if bool(response.get("ok", false)):
		failures.append("%s returned success." % label)
	if _snapshot(run) != before:
		failures.append("%s changed the complete production save snapshot." % label)


func _free_service_run(seed_suffix: String, service_id: String, archetype: String) -> RunState:
	var run := _base_run(seed_suffix, 60, archetype, [service_id], [])
	_set_local_heat(run, 20)
	if service_id == "show_drummer_glasses":
		run.add_item("jazz_drummer_glasses")
	return run


func _lender_run(seed_suffix: String, lender_id: String) -> RunState:
	var archetype := "motel" if lender_id in ["motel_friend", "brother_in_law"] else "bar"
	var run := _base_run(seed_suffix, 60, archetype, [], [lender_id])
	_set_local_heat(run, 10)
	if lender_id == "brother_in_law":
		run.narrative_flags["brother_in_law_phone_ready"] = true
	return run


func _gift_run(seed_suffix: String) -> RunState:
	var run := _base_run(seed_suffix, 60, RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID, [], [])
	run.grand_casino_chips = 10
	run.current_environment["cage_gift_shop_state"] = {"version": 1, "stock": [{"item_id": GIFT_ITEM_ID, "chip_price": GIFT_PRICE, "sold": false}]}
	return run


func _pawn_run(seed_suffix: String) -> RunState:
	var run := _base_run(seed_suffix, 60, "pawn_shop", [], ["sals_pawn_counter"])
	run.add_item(PAWN_ITEM_ID)
	return run


func _ticket_run(seed_suffix: String, item_id: String) -> RunState:
	var run := _base_run(seed_suffix, 60, "pawn_shop", [], ["sals_pawn_counter"])
	var kind := RunState.portable_ticket_kind_for_item(item_id)
	var origin := {"id": "%s_origin" % kind, "world_node_id": "%s_origin" % kind, "archetype_id": "gas_station_casino", "display_name": "Ticket Origin"}
	run.remember_portable_ticket_state(kind, origin, {"winner_pile": [{"id": "%s_winner" % kind, "payout": 25}], "loser_pile": []})
	return run


func _item_purchase_run(seed_suffix: String, bankroll: int, price: int) -> RunState:
	var run := _base_run(seed_suffix, bankroll, "corner_store", [], [])
	run.current_environment["item_offers"] = [{
		"id": PAWN_ITEM_ID,
		"display_name": "Creased Luck Card",
		"price": price,
		"pickup": false,
	}]
	return run


func _base_run(seed_suffix: String, bankroll: int, archetype_id: String, service_ids: Array, lender_hooks: Array) -> RunState:
	var run := FactRunStateScript.new()
	run.start_new("POSTFIX-TXN-%s" % seed_suffix)
	run.bankroll = bankroll
	run.set_environment({
		"id": "postfix_%s_room" % seed_suffix.to_lower(),
		"world_node_id": "postfix_%s_node" % archetype_id,
		"archetype_id": archetype_id,
		"kind": "shop",
		"turns": 0,
		"item_offers": [],
		"service_ids": service_ids.duplicate(true),
		"lender_hooks": lender_hooks.duplicate(true),
		"game_ids": [],
		"event_ids": [],
		"next_archetypes": [],
		"travel_hooks": [],
		"game_states": {},
		"layout": {},
	})
	return run


func _install_active_service_fact_fixture(run: RunState, fixture_id: String) -> bool:
	var definition: Dictionary = ScenarioSequenceContractScript._fixture_definition().duplicate(true)
	definition["id"] = "postfix06_2_%s" % fixture_id
	definition["archetype_id"] = str(run.current_environment.get("archetype_id", "bar"))
	var sequence: Dictionary = definition.get("sequence", {}).duplicate(true) if typeof(definition.get("sequence", {})) == TYPE_DICTIONARY else {}
	var subscriptions: Array = sequence.get("fact_subscriptions", []).duplicate(true) if typeof(sequence.get("fact_subscriptions", [])) == TYPE_ARRAY else []
	for fact_type in ["world_boundary", "service_result"]:
		if not subscriptions.has(fact_type):
			subscriptions.append(fact_type)
	sequence["fact_subscriptions"] = subscriptions
	definition["sequence"] = sequence
	definition["sequence"]["sequence_signature"] = ScenarioSequenceSchemaScript.calculated_signature_hash(definition)
	var host_semantics: Dictionary = ScenarioSequenceContractScript._fixture_host_semantics(definition)
	# Bind the synthetic room and map cursor to one node so fact ingress, causal
	# state, and the environment-owned definition cannot disagree on identity.
	var node_id := "postfix_fact_%s_node" % fixture_id
	run.current_environment["world_node_id"] = node_id
	run.world_map["current_node_id"] = node_id
	var state := ScenarioSequenceRuntimeScript.initial_state(definition, node_id, "POSTFIX-FACT-%s" % fixture_id, host_semantics)
	var state_errors: Array = state.get("errors", []) if typeof(state.get("errors", [])) == TYPE_ARRAY else ["Malformed causal-state error list."]
	if state.is_empty() or str(state.get("status", "")) != ScenarioSequenceRuntimeScript.STATUS_ACTIVE or not state_errors.is_empty():
		failures.append("SETUP: active service-fact fixture %s did not create causal state: %s" % [fixture_id, JSON.stringify(state_errors)])
		return false
	# initial_state above performs the full schema + exact target-inventory proof.
	# Finalized production rooms retain that successful validation receipt so hot
	# ingress never revalidates declared targets without their sealed inventory.
	definition[ScenarioEngineScript.VALIDATED_SEQUENCE_MARKER] = true
	if not run.cache_runtime_scenario_definition(definition):
		failures.append("SETUP: active service-fact fixture %s could not retain its validated definition receipt." % fixture_id)
		return false
	run.current_environment["scenario_state"] = ScenarioEngineScript.initial_state(definition)
	run.current_environment["scenario_id"] = str(definition.get("id", ""))
	run.current_environment["scenario_sequence_definition"] = definition
	run.current_environment["scenario_sequence_state"] = state
	run.current_environment["scenario_semantic_ready"] = true
	run.current_environment["postfix06_2_fact_fixture"] = true
	# The real enqueue/flush path still requires a sealed causal and passive-layout
	# receipt. This headless test seam supplies those exact receipts while the
	# subclass bypasses only renderer-oriented readiness reconstruction.
	var inventory_digest := str(host_semantics.get("inventory_digest", ""))
	var inventory_version := int(host_semantics.get("inventory_schema_version", 1))
	var base_interactions: Array = host_semantics.get("base_interactions", []).duplicate(true) if typeof(host_semantics.get("base_interactions", [])) == TYPE_ARRAY else []
	var event_choices: Dictionary = host_semantics.get("event_choices", {}).duplicate(true) if typeof(host_semantics.get("event_choices", {})) == TYPE_DICTIONARY else {}
	run.current_environment["scenario_semantic_inventory"] = {"schema_version": inventory_version, "digest": inventory_digest}
	run.current_environment["scenario_semantic_inventory_version"] = inventory_version
	run.current_environment["scenario_semantic_digest"] = inventory_digest
	run.current_environment["scenario_base_interactions"] = base_interactions
	run.current_environment["scenario_semantic_action_digest"] = ScenarioSequenceRuntimeScript.base_interaction_action_authority_digest(base_interactions)
	run.current_environment["scenario_event_choices"] = event_choices
	run.current_environment[ScenarioEngineScript.TRUSTED_STATE_REFERENCE_KEY] = ScenarioSequenceRuntimeScript.content_fingerprint(state)
	var passive_digest := ScenarioSequenceRuntimeScript.content_fingerprint({"fixture_id": fixture_id, "mode": "passive"})
	run.current_environment["scenario_layout_base_records"] = []
	run.current_environment["scenario_layout_context"] = {}
	run.current_environment["scenario_layout_authority"] = {}
	run.current_environment["scenario_layout_authority_digest"] = passive_digest
	run.current_environment["scenario_layout_audit"] = {"active": false, "valid": true, "sealed_passive": true, "authority_digest": passive_digest}
	run.current_environment["scenario_render_snapshot"] = {"ok": true, "sealed_passive": true, "presentation_mode": "passive", "layout_authority_digest": passive_digest}
	# Seal the projection through the same ScenarioEngine commit path used by a
	# finalized production room. Hand-populating only causal state can look active
	# while later enqueue commits fail closed on missing projection/layout receipts.
	run.current_environment["scenario_sequence_base_service_ids"] = run.current_environment.get("service_ids", []).duplicate(true)
	run.current_environment["scenario_sequence_base_game_ids"] = run.current_environment.get("game_ids", []).duplicate(true)
	run.current_environment["scenario_sequence_base_travel_hooks"] = run.current_environment.get("travel_hooks", []).duplicate(true)
	run.current_environment["scenario_sequence_base_game_modifiers"] = {}
	run.current_environment["scenario_sequence_base_layout_object_rects"] = {}
	var refreshed := ScenarioEngineScript.refresh_sequence_snapshots(run.current_environment, definition)
	if not bool(refreshed.get("ok", false)) or typeof(run.current_environment.get("scenario_sequence_projection", {})) != TYPE_DICTIONARY or (run.current_environment.get("scenario_sequence_projection", {}) as Dictionary).is_empty():
		failures.append("SETUP: active service-fact fixture %s could not seal its production projection: %s" % [fixture_id, JSON.stringify(refreshed)])
		return false

	# Prove the fully detached path that the transaction will use can accept and
	# retain one service_result envelope. The probe is discarded, so the fixture
	# under test remains byte-identical while setup failures expose ingress errors.
	var ingress_probe := run.detached_host_action_candidate()
	var probe_service_id := "fixture_probe_%s" % fixture_id
	var ingress := ingress_probe.scenario_enqueue_fact("service_result", "service", {
		"kind": "service",
		"service_id": probe_service_id,
		"ok": true,
		"action_id": "use_service",
	}, "postfix_probe_%s" % fixture_id)
	if not bool(ingress.get("ok", false)) \
			or _scenario_service_fact_count(ingress_probe, "service", probe_service_id) != 1 \
			or not _scenario_service_fact_payloads_valid(ingress_probe, "service", probe_service_id, "use_service"):
		failures.append("SETUP: active service-fact fixture %s failed detached production ingress: %s / %s" % [fixture_id, JSON.stringify(ingress), JSON.stringify(ingress_probe.current_environment.get("scenario_sequence_state", {}))])
		return false
	return true


func _service(run: RunState) -> RunActionService:
	var result := RunActionServiceScript.new()
	result.setup(library, run)
	return result


func _add_benign_clock_debt(run: RunState, clock: int) -> void:
	run.add_debt({
		"id": "benign_clock_%d" % clock,
		"lender_id": "benign_clock_fixture",
		"balance": 1,
		"deadline_turns": clock,
		"turns_remaining": clock,
		"status": "active",
		"debt_kind": "cash",
		"default_consequence": "favor_owed",
	})


func _add_forced_boundary_debt(run: RunState) -> void:
	run.add_debt({
		"id": "terminal_boundary_note",
		"lender_id": "boundary_pressure",
		"balance": 30,
		"deadline_turns": 1,
		"turns_remaining": 1,
		"status": "active",
		"debt_kind": "cash",
		"interest_rate": 0.1,
		"default_consequence": "forced_repayment",
	})


func _add_forced_repayment_boundary_debt(run: RunState, balance: int) -> void:
	run.add_debt({
		"id": "exhausting_boundary_note",
		"lender_id": "boundary_exhaustion",
		"balance": maxi(1, balance),
		"deadline_turns": 1,
		"turns_remaining": 1,
		"status": "active",
		"debt_kind": "cash",
		"interest_rate": 0.0,
		"default_consequence": "forced_repayment",
	})


func _set_local_heat(run: RunState, level: int) -> void:
	var current := run.suspicion_level()
	run.add_suspicion("postfix_contract_heat", level - current, "behavior", false, {"environment_id": str(run.current_environment.get("id", ""))}, true)


func _set_latent_local_heat(run: RunState, level: int) -> void:
	var location_id := run.current_suspicion_location_id()
	var levels: Dictionary = run.suspicion.get("local_levels", {}) if typeof(run.suspicion.get("local_levels", {})) == TYPE_DICTIONARY else {}
	levels[location_id] = level
	run.suspicion["local_levels"] = levels
	run.suspicion["level"] = level


func _snapshot(run: RunState) -> String:
	return JSON.stringify(run.to_save_snapshot())


# Independent oracle candidates can need to reseal the private Crew payload.
# Its AES IV and padded bytes are intentionally random, so ciphertext equality
# is not a state equality predicate. Retain every save byte except z, replacing
# z with the deterministic authenticated payload+binding fingerprint and encoded
# length. Rejected-transaction checks continue to use _snapshot() above and thus
# still require literal byte-for-byte rollback of the original save envelope.
func _exact_once_snapshot(run: RunState) -> String:
	var snapshot := run.to_save_snapshot()
	var crew_state: Dictionary = snapshot.get("crew_state", {}) if typeof(snapshot.get("crew_state", {})) == TYPE_DICTIONARY else {}
	if crew_state.has("z"):
		var capsule := str(crew_state.get("z", ""))
		crew_state["z"] = {
			"authenticated_fingerprint": str(run._crew_heist_private_fingerprint),
			"encoded_length": capsule.length(),
		}
		snapshot["crew_state"] = crew_state
	return JSON.stringify(snapshot)


func _snapshot_first_difference(actual_json: String, expected_json: String) -> String:
	var actual: Variant = JSON.parse_string(actual_json)
	var expected: Variant = JSON.parse_string(expected_json)
	if actual == null or expected == null:
		return "snapshot JSON could not be parsed"
	var difference := _variant_first_difference(actual, expected, "save")
	return difference if not difference.is_empty() else "serialized key ordering differs"


func _variant_first_difference(actual: Variant, expected: Variant, path: String) -> String:
	if typeof(actual) != typeof(expected):
		return "%s type actual=%d expected=%d" % [path, typeof(actual), typeof(expected)]
	if typeof(actual) == TYPE_DICTIONARY:
		var actual_dictionary := actual as Dictionary
		var expected_dictionary := expected as Dictionary
		for key_value in expected_dictionary.keys():
			if not actual_dictionary.has(key_value):
				return "%s.%s missing from actual" % [path, str(key_value)]
		for key_value in actual_dictionary.keys():
			if not expected_dictionary.has(key_value):
				return "%s.%s unexpected in actual" % [path, str(key_value)]
		for key_value in expected_dictionary.keys():
			var nested := _variant_first_difference(actual_dictionary.get(key_value), expected_dictionary.get(key_value), "%s.%s" % [path, str(key_value)])
			if not nested.is_empty():
				return nested
		return ""
	if typeof(actual) == TYPE_ARRAY:
		var actual_array := actual as Array
		var expected_array := expected as Array
		if actual_array.size() != expected_array.size():
			return "%s size actual=%d expected=%d" % [path, actual_array.size(), expected_array.size()]
		for index in range(expected_array.size()):
			var nested := _variant_first_difference(actual_array[index], expected_array[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
		return ""
	if actual != expected:
		return "%s actual=%s expected=%s" % [path, _short_json(actual), _short_json(expected)]
	return ""


func _short_json(value: Variant) -> String:
	var encoded := JSON.stringify(value)
	return encoded.left(157) + "..." if encoded.length() > 160 else encoded


func _story_count_for_id(run: RunState, id: String) -> int:
	var count := 0
	for value in run.story_log:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == id:
			count += 1
	return count


func _story_count_for_item(run: RunState, item_id: String) -> int:
	var count := 0
	for value in run.story_log:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("item_id", "")) == item_id and str((value as Dictionary).get("type", "")) == "item_purchase":
			count += 1
	return count


func _story_count_for_type(run: RunState, story_type: String) -> int:
	var count := 0
	for value in run.story_log:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("type", "")) == story_type:
			count += 1
	return count


func _story_count_for_debt_id(run: RunState, debt_id: String) -> int:
	var count := 0
	for value in run.story_log:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("debt_id", "")) == debt_id:
			count += 1
	return count


func _debt_count_for_lender(run: RunState, lender_id: String) -> int:
	var count := 0
	for value in run.debt:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("lender_id", "")) == lender_id:
			count += 1
	return count


func _debt_count_for_id(run: RunState, debt_id: String) -> int:
	var count := 0
	for value in run.debt:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == debt_id:
			count += 1
	return count


func _inventory_occurrences(run: RunState, item_id: String) -> int:
	var count := 0
	for value in run.inventory:
		var current_id := str((value as Dictionary).get("id", "")) if typeof(value) == TYPE_DICTIONARY else str(value)
		if current_id == item_id:
			count += 1
	return count


func _gift_offer_sold(run: RunState, item_id: String) -> bool:
	var shop: Dictionary = run.current_environment.get("cage_gift_shop_state", {}) if typeof(run.current_environment.get("cage_gift_shop_state", {})) == TYPE_DICTIONARY else {}
	for value in shop.get("stock", []):
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("item_id", "")) == item_id:
			return bool((value as Dictionary).get("sold", false))
	return false


func _quote_for_item(quotes: Array, item_id: String) -> Dictionary:
	for value in quotes:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("item_id", "")) == item_id:
			return (value as Dictionary).duplicate(true)
	return {}


func _finish() -> void:
	if failures.is_empty():
		print("POSTFIX06_2_TRANSACTION_ATOMICITY PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
