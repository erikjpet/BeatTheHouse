extends GameModule

# Seeded stock and state shared by venue presentation and the playable cabinet.

const DEFAULT_DEAL_COUNT := 150
const MAX_DEAL_COUNT := 150
const REAL_PULL_TAB_UNIT_COUNT := 540
const PULL_TAB_INITIAL_REMOVED_MIN_RATIO := 0.04
const PULL_TAB_INITIAL_REMOVED_BAND_RATIO := 0.045
const PULL_TAB_INITIAL_REMOVED_JITTER_RATIO := 0.025
# A 150-ticket deal scales to 48 payouts and 188 stake units (125.33% RTP).
const PULL_TAB_UNIT_PRIZE_COUNTS := [
	{"id": "small", "symbol": "CHERRY", "multiplier": 1, "count": 126},
	{"id": "small_plus", "symbol": "LEMON", "multiplier": 2, "count": 25},
	{"id": "medium_small", "symbol": "BELL", "multiplier": 3, "count": 10},
	{"id": "medium", "symbol": "BAR", "multiplier": 10, "count": 2},
	{"id": "large", "symbol": "7", "multiplier": 20, "count": 1},
	{"id": "top", "symbol": "CROWN", "multiplier": 100, "count": 1},
]
const REDEEM_HOOK_ID := "ticket_redeemer"
const CLERK_DIALOGUE_HOOK_ID := "pull_tab_clerk_dialogue"
const CLERK_DIALOGUE_ID := "pull_tab_clerk"
const REDEEM_ACTION_ID := "redeem_pull_tab_winners"
const CHEAT_REDEMPTION_HEAT := 7
const FAKE_TICKET_REDEMPTION_HEAT := 14
const CASHOUT_HIGH_VALUE_TICKET_THRESHOLD := 25
const CASHOUT_BULK_WINNER_THRESHOLD := 4
const CASHOUT_LOSER_TRAIL_PER_WINNER := 2
const CASHOUT_MIN_LOSER_TRAIL := 3
const CASHOUT_HISTORY_LOOKBACK := 12
const CASHOUT_REPEATED_HIGH_VALUE_THRESHOLD := 2
const CASHOUT_REPEATED_HIGH_VALUE_HEAT := 5
const CASHOUT_LOW_LOSER_PATTERN_HEAT := 6
const CASHOUT_BULK_WINNER_HEAT_STEP := 2
const PULL_TAB_DISPENSE_STAGGER_MSEC := 430
const PULL_TAB_DISPENSE_DROP_START_MSEC := 240
const PULL_TAB_DISPENSE_DROP_DURATION_MSEC := 360
const PULL_TAB_MACHINE_COLUMN_COUNT := 4
const XRAY_TARGET_COUNT := 2
const TAROT_READING_COUNT := 5


# Exposes help and redemption as actions on the room's existing sales counter.
func environment_interactable_objects(run_state: RunState, environment: Dictionary) -> Array:
	var machine := _read_machine_state(run_state, environment)
	if machine.is_empty():
		return []
	var pending_payout := _pending_winner_payout(machine)
	var winner_count := _array_size(machine.get("winner_pile", []))
	var label := _redeemer_label(environment)
	var wager_currency := GameModule.presentation_currency_for_game(run_state, get_id(), environment)
	var payout_text := PlayerTextScript.format_currency_amount(wager_currency, pending_payout)
	var account_noun := "chips" if wager_currency == "chips" else "cash"
	var host_object_id := _counter_host_object_id(environment)
	var speaker_override := _counter_speaker_override(environment)
	var help_record := {
		"id": CLERK_DIALOGUE_HOOK_ID,
		"object_id": "dialogue:%s" % CLERK_DIALOGUE_ID,
		"label": "%s - Pull-Tab Help" % label,
		"short_description": "The counter staff answers quick questions about the Pull Tabs for sale.",
		"enabled": true,
		"action_summary": "Ask about Pull Tabs.",
		"effect_summary": "Tips, risk, route leads.",
		"risk_summary": "Loose-ticket questions can draw heat.",
		"cost_summary": "",
		"dialogue_id": CLERK_DIALOGUE_ID,
		"dialogue_speaker_override": speaker_override,
		"slot_binding_source_id": host_object_id,
		"visual_key": "pull_tab_redeemer",
		"visual_type": "service",
		"icon_key": "clerk_chat",
		"available_actions": [{"id": "start_dialogue", "label": "Ask About Pull Tabs"}],
		"confirm_action_id": "start_dialogue",
	}
	var redeem_record := {
		"id": REDEEM_HOOK_ID,
		"object_id": "game_hook:%s:%s" % [get_id(), REDEEM_HOOK_ID],
		"label": label,
		"short_description": "Turns the room's winning tabs into %s." % account_noun,
		"enabled": true,
		"recovery": pending_payout > 0,
		"action_summary": "Redeem %d winner%s for %s." % [winner_count, "" if winner_count == 1 else "s", payout_text] if winner_count > 0 else "No winning tabs to redeem.",
		"effect_summary": "Pending payout %s." % payout_text if pending_payout > 0 else "Sort winners here before redeeming.",
		"risk_summary": _redemption_risk_summary(machine, run_state),
		"cost_summary": "",
		"slot_binding_source_id": host_object_id,
		"visual_key": "pull_tab_redeemer",
		"visual_type": "service",
		"icon_key": "service",
		"available_actions": [{"id": REDEEM_ACTION_ID, "label": "Redeem Pull Tabs" if wager_currency == "chips" else "Cash In Pull Tabs"}],
		"confirm_action_id": REDEEM_ACTION_ID,
	}
	# Compatibility fallback for custom/test environments that have not declared
	# a counter host. Authored production environments always use the host path.
	if host_object_id.is_empty():
		help_record["unique_object_class"] = "lottery_redemption_clerk"
		help_record["unique_object_priority"] = 80
		redeem_record["unique_object_class"] = "lottery_redemption_clerk"
		redeem_record["unique_object_priority"] = 120 if pending_payout > 0 else 90
	return [help_record, redeem_record]


func environment_runtime_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine := _read_machine_state(run_state, environment)
	if machine.is_empty():
		return {}
	return _runtime_state_for_machine(run_state, environment, machine)


func _runtime_state_for_machine(run_state: RunState, environment: Dictionary, machine: Dictionary) -> Dictionary:
	var pending_payout := _pending_winner_payout(machine)
	var winner_count := _array_size(machine.get("winner_pile", []))
	var stack_count := _array_size(machine.get("ticket_stack", []))
	var tray_count := _array_size(machine.get("tray_stack", []))
	var unresolved_count := _unresolved_pull_tab_ticket_count(machine)
	var deferred := run_state != null and not run_state.has_liquid_run_funds() and _pull_tab_bankroll_zero_failure_deferred(machine)
	var wager_currency := GameModule.presentation_currency_for_game(run_state, get_id(), environment)
	var payout_text := PlayerTextScript.format_currency_amount(wager_currency, pending_payout)
	var status_bits: Array[String] = []
	if pending_payout > 0:
		status_bits.append(PlayerTextScript.format_currency_account_balance(wager_currency, pending_payout))
	if tray_count > 0:
		status_bits.append("%d TRAY" % tray_count)
	if stack_count > 0:
		status_bits.append("%d OPEN" % stack_count)
	return {
		"active": unresolved_count > 0 or pending_payout > 0 or winner_count > 0,
		"bankroll_zero_failure_deferred": deferred,
		"pending_payout": pending_payout,
		"winner_count": winner_count,
		"stack_count": stack_count,
		"tray_count": tray_count,
		"unresolved_ticket_count": unresolved_count,
		"wager_currency": wager_currency,
		"status_label": " ".join(status_bits),
		"status_summary": "Pending pull-tabs: %d tray, %d in play, %s to redeem." % [tray_count, stack_count, payout_text],
	}


func environment_object_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine := _read_machine_state(run_state, environment)
	if machine.is_empty():
		return {}
	var runtime_state := _runtime_state_for_machine(run_state, environment, machine)
	var pending_payout: int = runtime_state["pending_payout"]
	var winner_count: int = runtime_state["winner_count"]
	var stack_count: int = runtime_state["stack_count"]
	var tray_count: int = runtime_state["tray_count"]
	var wager_currency: String = runtime_state["wager_currency"]
	var payout_text := PlayerTextScript.format_currency_amount(wager_currency, pending_payout)
	var remaining := 0
	for deal in _deal_array(machine.get("deals", [])):
		remaining += int((deal as Dictionary).get("remaining", 0))
	var badge := ""
	if pending_payout > 0:
		badge = PlayerTextScript.format_currency_account_balance(wager_currency, pending_payout)
	elif tray_count > 0:
		badge = "%d IN TRAY" % tray_count
	elif stack_count > 0:
		badge = PlayerTextScript.count_text("ticket", stack_count).to_upper()
	runtime_state["status_label"] = badge
	runtime_state["tickets_remaining"] = remaining
	return {
		"status_summary": "%s remain across %s." % [PlayerTextScript.count_text("ticket", remaining), PlayerTextScript.count_text("deal_row", 4)],
		"effect_summary": "Pending payout %s; %s; %d in play." % [payout_text, PlayerTextScript.count_text("tray_ticket", tray_count), stack_count],
		"status_message_key": "pull_tabs.stock_summary",
		"status_message_params": {"ticket_count": remaining, "deal_row_count": 4, "tray_ticket_count": tray_count, "in_play_count": stack_count},
		"state_badge": badge,
		"runtime_state": runtime_state,
		"visual_state": {
			"machine_name": str(machine.get("machine_name", "Pull-Tab Counter Stock")),
			"pending_payout": pending_payout,
			"winner_count": winner_count,
			"stack_count": stack_count,
			"tray_count": tray_count,
			"tickets_remaining": remaining,
			"last_ticket_id": str(machine.get("last_ticket_id", "")),
		},
	}


# Generates finite deal state with the environment, before entry/selection.
func generate_environment_state(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return _generate_machine_state(run_state, environment, rng)


func _generate_machine_state(run_state: RunState, environment: Dictionary, rng_override: RngStream = null) -> Dictionary:
	var environment_id := str(environment.get("id", "room"))
	var machine_rng := rng_override
	if machine_rng == null:
		machine_rng = _seeded_rng("pull_tabs:%s" % environment_id)
	var deals: Array = []
	var templates := _selected_deal_templates(_deal_templates(), environment)
	for index in range(templates.size()):
		var template: Dictionary = (templates[index] as Dictionary).duplicate(true)
		var count := _generated_deal_ticket_count(template)
		var serial := "%03d-%05d" % [index + 1, machine_rng.randi_range(10000, 99999)]
		var prizes := _build_deal_prizes(template, count, machine_rng)
		var ticket_sleeve := _build_ticket_sleeve(prizes, count, machine_rng)
		var initial_removed_count := _initial_removed_ticket_count(count, index, machine_rng)
		var removed_summary := _burn_ticket_sleeve(ticket_sleeve, initial_removed_count, prizes)
		var deal := {
			"id": str(template.get("id", "deal_%d" % index)),
			"display_name": str(template.get("display_name", "Deal %d" % (index + 1))),
			"theme": str(template.get("theme", "")),
			"form": str(template.get("form", "PT-%03d" % index)),
			"serial": serial,
			"price": maxi(1, int(template.get("price", 1))),
			"ticket_count": count,
			"remaining": ticket_sleeve.size(),
			"sold": 0,
			"unit_cursor": initial_removed_count,
			"initial_removed_count": initial_removed_count,
			"initial_removed_winner_count": int(removed_summary.get("winner_count", 0)),
			"initial_removed_payout_total": int(removed_summary.get("payout_total", 0)),
			"palette": _pt_copy_dict(template.get("palette", {})),
			"prizes": _prizes_with_remaining_counts(prizes, ticket_sleeve),
			"ticket_sleeve": ticket_sleeve,
		}
		deals.append(deal)
	_apply_tutorial_xray_stock(deals, run_state)
	var item_state := _initial_pull_tab_item_state(deals, machine_rng)
	item_state = _apply_tutorial_xray_item_target(deals, item_state, run_state)
	return {
		"schema": "pull_tab_machine_state",
		"version": 1,
		"machine_name": _machine_name_for_environment(environment),
		"deals": deals,
		"deal_template_count": _deal_templates().size(),
		"item_state": item_state,
		"environment_hooks": _default_environment_hooks(environment),
		"tray_stack": [],
		"ticket_stack": [],
		"winner_pile": [],
		"loser_pile": [],
		"loser_archive_count": 0,
		"tickets_sold": 0,
		"cashout_count": 0,
		"dispense_started_msec": 0,
		"last_dispense_id": "",
		"last_dispense_events": [],
	}


func _apply_tutorial_xray_stock(deals: Array, run_state: RunState) -> void:
	if run_state == null or not run_state.is_tutorial_run():
		return
	var desired_offset := int(run_state.challenge_modifiers().get("tutorial_pull_tab_xray_offset", -1))
	if desired_offset < 0 or deals.is_empty() or typeof(deals[0]) != TYPE_DICTIONARY:
		return
	var deal: Dictionary = deals[0]
	var sleeve := _int_array(deal.get("ticket_sleeve", []))
	var prizes := _dictionary_array(deal.get("prizes", []))
	if sleeve.is_empty() or prizes.is_empty():
		return
	var winner_index := -1
	var winner_payout := 0
	for index in range(sleeve.size()):
		var prize_index := int(sleeve[index])
		if prize_index < 0 or prize_index >= prizes.size():
			continue
		var payout := maxi(0, int((prizes[prize_index] as Dictionary).get("payout", 0)))
		if payout > winner_payout:
			winner_payout = payout
			winner_index = index
	if winner_index < 0:
		return
	var target_offset := clampi(desired_offset, 0, sleeve.size() - 1)
	var winner_prize_index: int = sleeve.pop_at(winner_index)
	sleeve.insert(target_offset, winner_prize_index)
	deal["ticket_sleeve"] = sleeve
	deal["tutorial_xray_scripted"] = true
	deal["tutorial_xray_offset"] = target_offset
	deals[0] = deal


func _apply_tutorial_xray_item_target(deals: Array, item_state: Dictionary, run_state: RunState) -> Dictionary:
	if run_state == null or not run_state.is_tutorial_run():
		return item_state
	var desired_offset := int(run_state.challenge_modifiers().get("tutorial_pull_tab_xray_offset", -1))
	if desired_offset < 0 or deals.is_empty() or typeof(deals[0]) != TYPE_DICTIONARY:
		return item_state
	var scripted_target := _highest_remaining_winner_target(deals[0] as Dictionary, 0)
	if scripted_target.is_empty():
		return item_state
	scripted_target["consumed"] = false
	var targets: Array = [scripted_target]
	for target_value in _dictionary_array(item_state.get("xray_targets", [])):
		var target: Dictionary = target_value
		if int(target.get("deal_index", -1)) == 0:
			continue
		targets.append(target.duplicate(true))
		if targets.size() >= XRAY_TARGET_COUNT:
			break
	item_state["xray_targets"] = targets
	return _sync_legacy_xray_fields(item_state)


func _deal_templates() -> Array:
	return _dictionary_array(definition.get("pull_tab_deals", []))


func _selected_deal_templates(templates: Array, environment: Dictionary) -> Array:
	var source := _dictionary_array(templates)
	if source.size() <= PULL_TAB_MACHINE_COLUMN_COUNT:
		return source
	var start_index := _deal_template_rotation_start(environment, source.size())
	var result: Array = []
	for offset in range(source.size()):
		var source_index := (start_index + offset) % source.size()
		result.append((source[source_index] as Dictionary).duplicate(true))
		if result.size() >= PULL_TAB_MACHINE_COLUMN_COUNT:
			break
	return result


func _deal_template_rotation_start(environment: Dictionary, template_count: int) -> int:
	if template_count <= 0:
		return 0
	var scene_type := str(_pt_copy_dict(environment.get("visual_context", {})).get("scene_type", "")).strip_edges()
	var archetype_id := str(environment.get("archetype_id", "")).strip_edges()
	match scene_type:
		"bar":
			return 0
		"gas_station_casino":
			return mini(2, template_count - 1)
		"jazz_club":
			return mini(4, template_count - 1)
		"kitty_cat_lounge":
			return mini(5, template_count - 1)
		"riverboat", "delta_queen":
			return mini(6, template_count - 1)
	if archetype_id == "delta_queen":
		return mini(6, template_count - 1)
	if archetype_id == "kitty_cat_lounge":
		return mini(5, template_count - 1)
	var seed_text := "%s:%s" % [archetype_id, scene_type]
	return int(posmod(RunState.text_to_seed(seed_text), template_count))


func _machine_name_for_environment(environment: Dictionary) -> String:
	var scene_type := str(_pt_copy_dict(environment.get("visual_context", {})).get("scene_type", "")).strip_edges()
	var archetype_id := str(environment.get("archetype_id", "")).strip_edges()
	match scene_type:
		"bar":
			return "Lucky Jar Pull-Tab Counter Stock"
		"gas_station_casino":
			return "Cooler-Case Pull Tabs for Sale"
		"jazz_club":
			return "After-Hours Pull Tabs for Sale"
		"kitty_cat_lounge":
			return "Velvet Rope Pull Tabs for Sale"
		"riverboat", "delta_queen":
			return "Riverboat Pull-Tab Window"
	if archetype_id == "delta_queen":
		return "Riverboat Pull-Tab Window"
	if archetype_id == "kitty_cat_lounge":
		return "Velvet Rope Pull-Tab Rack"
	return "%s's Pull-Tab Counter Stock" % _counter_staff_label(environment)


func _read_machine_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var game_states_value: Variant = environment.get("game_states", {})
	if typeof(game_states_value) == TYPE_DICTIONARY:
		var game_states: Dictionary = game_states_value
		var machine_value: Variant = game_states.get(get_id(), {})
		if typeof(machine_value) == TYPE_DICTIONARY and not (machine_value as Dictionary).is_empty():
			var machine := _normalize_machine_state(machine_value as Dictionary)
			_merge_portable_ticket_state_readonly(run_state, environment, machine)
			return machine
	var generated := _generate_machine_state(run_state, environment)
	_merge_portable_ticket_state_readonly(run_state, environment, generated)
	return generated


func _merge_portable_ticket_state_readonly(run_state: RunState, environment: Dictionary, machine: Dictionary) -> void:
	if run_state == null:
		return
	var portable := run_state.portable_ticket_state(get_id(), environment)
	if portable.is_empty():
		return
	for field in ["tray_stack", "ticket_stack", "winner_pile", "loser_pile"]:
		var value: Variant = portable.get(field, [])
		if typeof(value) == TYPE_DICTIONARY:
			machine[field] = (value as Dictionary).duplicate(true)
		elif typeof(value) == TYPE_ARRAY:
			machine[field] = (value as Array).duplicate(true)
		else:
			machine[field] = value
	machine["loser_archive_count"] = maxi(0, int(portable.get("loser_archive_count", 0)))


func _normalize_machine_state(machine: Dictionary) -> Dictionary:
	if machine.is_empty():
		return {}
	var normalized := machine.duplicate(true)
	normalized["deals"] = _deal_array(normalized.get("deals", []))
	normalized["tray_stack"] = _ticket_array(normalized.get("tray_stack", []))
	normalized["ticket_stack"] = _ticket_array(normalized.get("ticket_stack", []))
	normalized["winner_pile"] = _ticket_array(normalized.get("winner_pile", []))
	normalized["loser_pile"] = _ticket_array(normalized.get("loser_pile", []))
	normalized["loser_archive_count"] = maxi(0, int(normalized.get("loser_archive_count", 0)))
	normalized["redeemed_pile"] = _ticket_array(normalized.get("redeemed_pile", []))
	normalized["environment_hooks"] = _environment_hook_array(normalized.get("environment_hooks", []))
	normalized["tickets_sold"] = int(normalized.get("tickets_sold", 0))
	normalized["item_state"] = _normalize_pull_tab_item_state(normalized)
	normalized["dispense_started_msec"] = maxi(0, int(normalized.get("dispense_started_msec", 0)))
	normalized["last_dispense_id"] = str(normalized.get("last_dispense_id", normalized.get("last_ticket_id", "")))
	normalized["last_dispense_events"] = _dispense_event_array(normalized.get("last_dispense_events", []))
	return normalized


func _initial_pull_tab_item_state(deals: Array, rng: RngStream) -> Dictionary:
	var xray_targets := _xray_targets_for_deal_indices(deals, _xray_selected_deal_indices(deals, rng))
	var item_state := {
		"xray_deal_indices": _xray_deal_indices_from_targets(xray_targets),
		"xray_targets": xray_targets,
		"tab_detector_active": false,
		"tab_detector_heat_triggers": 0,
		"tab_detector_peek_count": 0,
		"tab_detector_peek_success_count": 0,
		"tab_detector_peek_last_succeeded": false,
		"tab_detector_peek_highlight_index": -1,
		"tarot_armed": false,
		"tarot_read_count": TAROT_READING_COUNT,
		"last_tarot_ticket_id": "",
	}
	return _sync_legacy_xray_fields(item_state)


func _normalize_pull_tab_item_state(machine: Dictionary) -> Dictionary:
	var source := _pt_copy_dict(machine.get("item_state", {}))
	var deals := _array_view(machine.get("deals", []))
	var xray_targets := _normalize_xray_targets(source, deals)
	var item_state := {
		"xray_deal_indices": _xray_deal_indices_from_targets(xray_targets),
		"xray_targets": xray_targets,
		"tab_detector_active": bool(source.get("tab_detector_active", false)),
		"tab_detector_heat_triggers": maxi(0, int(source.get("tab_detector_heat_triggers", 0))),
		"tab_detector_peek_count": maxi(0, int(source.get("tab_detector_peek_count", 0))),
		"tab_detector_peek_success_count": maxi(0, int(source.get("tab_detector_peek_success_count", 0))),
		"tab_detector_peek_last_succeeded": bool(source.get("tab_detector_peek_last_succeeded", false)),
		"tab_detector_peek_highlight_index": clampi(int(source.get("tab_detector_peek_highlight_index", -1)), -1, maxi(-1, deals.size() - 1)),
		"tarot_armed": bool(source.get("tarot_armed", false)),
		"tarot_read_count": maxi(1, int(source.get("tarot_read_count", TAROT_READING_COUNT))),
		"last_tarot_ticket_id": str(source.get("last_tarot_ticket_id", "")),
	}
	return _sync_legacy_xray_fields(item_state)


func _xray_selected_deal_indices(deals: Array, rng: RngStream) -> Array:
	var candidates: Array = []
	for deal_index in range(deals.size()):
		if typeof(deals[deal_index]) != TYPE_DICTIONARY:
			continue
		if not _highest_remaining_winner_target(deals[deal_index] as Dictionary, deal_index).is_empty():
			candidates.append(deal_index)
	if rng != null and candidates.size() > 1:
		for index in range(candidates.size() - 1, 0, -1):
			var swap_index := rng.randi_range(0, index)
			var previous: int = int(candidates[index])
			candidates[index] = int(candidates[swap_index])
			candidates[swap_index] = previous
	return candidates.slice(0, mini(XRAY_TARGET_COUNT, candidates.size()))


func _xray_targets_for_deal_indices(deals: Array, deal_indices: Array) -> Array:
	var result: Array = []
	for value in deal_indices:
		var deal_index := int(value)
		if deal_index < 0 or deal_index >= deals.size() or typeof(deals[deal_index]) != TYPE_DICTIONARY:
			continue
		var target := _highest_remaining_winner_target(deals[deal_index] as Dictionary, deal_index)
		if target.is_empty():
			continue
		target["consumed"] = false
		result.append(target)
	return result


func _normalize_xray_targets(source: Dictionary, deals: Array) -> Array:
	var targets: Array = []
	for target_value in _dictionary_array(source.get("xray_targets", [])):
		var target: Dictionary = target_value
		var consumed := bool(target.get("consumed", false))
		var deal_index := int(target.get("deal_index", -1))
		if deal_index < 0 or deal_index >= deals.size() or typeof(deals[deal_index]) != TYPE_DICTIONARY:
			continue
		if int(target.get("ticket_number", 0)) <= 0:
			target = _highest_remaining_winner_target(deals[deal_index] as Dictionary, deal_index)
		if target.is_empty():
			continue
		target["consumed"] = consumed
		targets.append(target)
	if targets.is_empty():
		var legacy_target := _pt_copy_dict(source.get("xray_target", {}))
		var legacy_index := int(source.get("xray_deal_index", int(legacy_target.get("deal_index", -1))))
		if legacy_target.is_empty() and legacy_index >= 0 and legacy_index < deals.size() and typeof(deals[legacy_index]) == TYPE_DICTIONARY:
			legacy_target = _highest_remaining_winner_target(deals[legacy_index] as Dictionary, legacy_index)
		if not legacy_target.is_empty():
			legacy_target["consumed"] = bool(source.get("xray_target_consumed", false))
			targets.append(legacy_target)
	var used_deal_indices := {}
	for target_value in targets:
		if typeof(target_value) == TYPE_DICTIONARY:
			used_deal_indices[int((target_value as Dictionary).get("deal_index", -1))] = true
	var desired_count := mini(XRAY_TARGET_COUNT, deals.size())
	for deal_index in range(deals.size()):
		if targets.size() >= desired_count:
			break
		if used_deal_indices.has(deal_index) or typeof(deals[deal_index]) != TYPE_DICTIONARY:
			continue
		var target := _highest_remaining_winner_target(deals[deal_index] as Dictionary, deal_index)
		if target.is_empty():
			continue
		target["consumed"] = false
		targets.append(target)
		used_deal_indices[deal_index] = true
	return targets.slice(0, mini(XRAY_TARGET_COUNT, targets.size()))


func _xray_deal_indices_from_targets(targets: Array) -> Array:
	var result: Array = []
	for target_value in targets:
		if typeof(target_value) != TYPE_DICTIONARY:
			continue
		var deal_index := int((target_value as Dictionary).get("deal_index", -1))
		if deal_index >= 0 and not result.has(deal_index):
			result.append(deal_index)
	return result


func _sync_legacy_xray_fields(item_state: Dictionary) -> Dictionary:
	var targets := _dictionary_array(item_state.get("xray_targets", []))
	var first_target := {}
	if not targets.is_empty():
		first_target = (targets[0] as Dictionary).duplicate(true)
	item_state["xray_targets"] = targets
	item_state["xray_deal_indices"] = _xray_deal_indices_from_targets(targets)
	item_state["xray_target"] = first_target
	item_state["xray_deal_index"] = int(first_target.get("deal_index", -1)) if not first_target.is_empty() else -1
	item_state["xray_target_consumed"] = bool(first_target.get("consumed", false)) if not first_target.is_empty() else false
	return item_state


func _highest_remaining_winner_target(deal: Dictionary, deal_index: int) -> Dictionary:
	var sleeve := _int_array(deal.get("ticket_sleeve", []))
	var prizes := _dictionary_array(deal.get("prizes", []))
	var best_target := {}
	var best_payout := 0
	for offset in range(sleeve.size()):
		var prize_index := int(sleeve[offset])
		if prize_index < 0 or prize_index >= prizes.size():
			continue
		var prize: Dictionary = prizes[prize_index]
		var payout := maxi(0, int(prize.get("payout", 0)))
		if payout <= best_payout:
			continue
		best_payout = payout
		best_target = _winner_target_payload(deal, deal_index, prize_index, offset)
	return best_target


func _winner_target_payload(deal: Dictionary, deal_index: int, prize_index: int, offset: int) -> Dictionary:
	var prizes := _dictionary_array(deal.get("prizes", []))
	if prize_index < 0 or prize_index >= prizes.size():
		return {}
	var prize: Dictionary = prizes[prize_index]
	var ticket_number := int(deal.get("unit_cursor", int(deal.get("initial_removed_count", 0)))) + offset + 1
	return {
		"deal_index": deal_index,
		"deal_id": str(deal.get("id", "")),
		"ticket_number": ticket_number,
		"ticket_label": "#%03d" % ticket_number,
		"offset": offset,
		"tickets_until": offset + 1,
		"prize_index": prize_index,
		"payout": maxi(0, int(prize.get("payout", 0))),
		"label": str(prize.get("label", "")),
		"symbols": _string_array(prize.get("symbols", [])),
	}


func _generated_deal_ticket_count(template: Dictionary) -> int:
	var authored_count := int(template.get("ticket_count", DEFAULT_DEAL_COUNT))
	return clampi(authored_count, 1, MAX_DEAL_COUNT)


func _build_deal_prizes(template: Dictionary, ticket_count: int, _rng: RngStream) -> Array:
	var price := maxi(1, int(template.get("price", 1)))
	var result: Array = []
	for tier_index in range(PULL_TAB_UNIT_PRIZE_COUNTS.size()):
		var tier: Dictionary = PULL_TAB_UNIT_PRIZE_COUNTS[tier_index]
		var symbol := str(tier.get("symbol", "CHERRY"))
		var count := _scaled_unit_prize_count(int(tier.get("count", 0)), ticket_count, tier_index)
		var payout := price * maxi(1, int(tier.get("multiplier", 1)))
		result.append({
			"id": "%s_%s" % [str(template.get("id", "deal")), str(tier.get("id", "tier_%d" % tier_index))],
			"tier": str(tier.get("id", "tier_%d" % tier_index)),
			"label": "3 %s" % symbol,
			"symbols": [symbol, symbol, symbol],
			"payout": payout,
			"count": count,
			"remaining": count,
		})
	return _trim_prize_counts_to_ticket_count(result, ticket_count)


func _scaled_unit_prize_count(unit_count: int, ticket_count: int, tier_index: int) -> int:
	if ticket_count <= 0 or unit_count <= 0:
		return 0
	var scaled := int(round(float(ticket_count) * float(unit_count) / float(REAL_PULL_TAB_UNIT_COUNT)))
	if tier_index >= PULL_TAB_UNIT_PRIZE_COUNTS.size() - 2:
		return maxi(1, scaled)
	if tier_index == PULL_TAB_UNIT_PRIZE_COUNTS.size() - 3:
		return maxi(1, scaled)
	return maxi(0, scaled)


func _trim_prize_counts_to_ticket_count(prizes: Array, ticket_count: int) -> Array:
	var result := _normalize_prizes(prizes)
	var total := 0
	for prize in result:
		total += int((prize as Dictionary).get("count", 0))
	var max_winners := maxi(0, ticket_count - 1)
	var guard := 0
	while total > max_winners and guard < 1000:
		guard += 1
		for index in range(result.size()):
			var prize: Dictionary = result[index]
			var count := int(prize.get("count", 0))
			if count <= 0:
				continue
			if index >= result.size() - 2 and count <= 1:
				continue
			prize["count"] = count - 1
			prize["remaining"] = int(prize.get("count", 0))
			result[index] = prize
			total -= 1
			if total <= max_winners:
				break
	return result


func _build_ticket_sleeve(prizes: Array, ticket_count: int, rng: RngStream) -> Array:
	var sleeve: Array = []
	for prize_index in range(prizes.size()):
		var prize: Dictionary = prizes[prize_index]
		for _copy_index in range(maxi(0, int(prize.get("count", 0)))):
			if sleeve.size() < ticket_count:
				sleeve.append(prize_index)
	while sleeve.size() < ticket_count:
		sleeve.append(-1)
	return _shuffled_int_array(sleeve, rng)


func _initial_removed_ticket_count(ticket_count: int, deal_index: int, rng: RngStream) -> int:
	if ticket_count <= 1:
		return 0
	var base := int(round(float(ticket_count) * PULL_TAB_INITIAL_REMOVED_MIN_RATIO))
	var band := int(round(float(ticket_count) * PULL_TAB_INITIAL_REMOVED_BAND_RATIO))
	var jitter_max := maxi(1, int(round(float(ticket_count) * PULL_TAB_INITIAL_REMOVED_JITTER_RATIO)))
	var removed := base + deal_index * maxi(1, band) + rng.randi_range(0, jitter_max)
	return clampi(removed, 0, maxi(0, ticket_count - 1))


func _burn_ticket_sleeve(sleeve: Array, burn_count: int, prizes: Array) -> Dictionary:
	var removed_count := mini(maxi(0, burn_count), maxi(0, sleeve.size() - 1))
	var winner_count := 0
	var payout_total := 0
	for _index in range(removed_count):
		if sleeve.is_empty():
			break
		var prize_index := int(sleeve.pop_front())
		if prize_index < 0 or prize_index >= prizes.size():
			continue
		var prize: Dictionary = prizes[prize_index]
		winner_count += 1
		payout_total += maxi(0, int(prize.get("payout", 0)))
	return {
		"count": removed_count,
		"winner_count": winner_count,
		"payout_total": payout_total,
	}


func _prizes_with_remaining_counts(prizes: Array, sleeve: Array) -> Array:
	var result := _normalize_prizes(prizes)
	var remaining_counts: Array = []
	for _index in range(result.size()):
		remaining_counts.append(0)
	for entry in sleeve:
		var prize_index := int(entry)
		if prize_index >= 0 and prize_index < remaining_counts.size():
			remaining_counts[prize_index] = int(remaining_counts[prize_index]) + 1
	for index in range(result.size()):
		var prize: Dictionary = result[index]
		prize["remaining"] = int(remaining_counts[index])
		result[index] = prize
	return result


func _shuffled_int_array(values: Array, rng: RngStream) -> Array:
	var result := _int_array(values)
	for index in range(result.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var previous: int = int(result[index])
		result[index] = result[swap_index]
		result[swap_index] = previous
	return result


func _ticket_animation_payload(ticket: Dictionary) -> Dictionary:
	var palette := _pt_copy_dict(ticket.get("palette", {}))
	return {
		"id": str(ticket.get("id", "")),
		"ticket_number": str(ticket.get("ticket_number", "")),
		"palette": palette,
	}


func _pending_winner_payout(machine: Dictionary) -> int:
	return _ticket_payout_total(_array_view(machine.get("winner_pile", [])))


func _unresolved_pull_tab_ticket_count(machine: Dictionary) -> int:
	return _array_size(machine.get("tray_stack", [])) + _array_size(machine.get("ticket_stack", []))


func _pull_tab_bankroll_zero_failure_deferred(machine: Dictionary) -> bool:
	return RunState.pull_tab_ticket_resolution_pending(machine)


func _ticket_payout_total(tickets: Array) -> int:
	var total := 0
	for ticket_value in tickets:
		if typeof(ticket_value) == TYPE_DICTIONARY:
			total += maxi(0, int((ticket_value as Dictionary).get("payout", 0)))
	return total


func _suspicious_ticket_count(tickets: Array) -> int:
	var count := 0
	for ticket_value in tickets:
		if typeof(ticket_value) != TYPE_DICTIONARY:
			continue
		var ticket: Dictionary = ticket_value as Dictionary
		if bool(ticket.get("tainted", false)) or bool(ticket.get("fake", false)):
			count += 1
	return count


func _fake_ticket_count(tickets: Array) -> int:
	var count := 0
	for ticket_value in tickets:
		if typeof(ticket_value) == TYPE_DICTIONARY and bool((ticket_value as Dictionary).get("fake", false)):
			count += 1
	return count


func _redemption_context(machine: Dictionary, tickets: Array, run_state: RunState, environment: Dictionary = {}, stake: int = 1) -> Dictionary:
	var winners := _ticket_array(tickets)
	var losers := _ticket_array(machine.get("loser_pile", []))
	var redeemed_history := _ticket_array(machine.get("redeemed_pile", []))
	var payout := _ticket_payout_total(winners)
	var suspicious_count := _suspicious_ticket_count(winners)
	var fake_count := _fake_ticket_count(winners)
	var current_high_value_count := _high_value_ticket_count(winners)
	var recent_history := _recent_ticket_history(redeemed_history, CASHOUT_HISTORY_LOOKBACK)
	var recent_high_value_count := _high_value_ticket_count(recent_history)
	var loser_count := losers.size() + maxi(0, int(machine.get("loser_archive_count", 0)))
	var winner_count := winners.size()
	var expected_loser_trail := _expected_cashout_loser_trail(winner_count)
	var low_loser_trail := winner_count > 0 and loser_count < expected_loser_trail
	var risk_reasons: Array = []
	var ticket_heat := suspicious_count * CHEAT_REDEMPTION_HEAT + fake_count * FAKE_TICKET_REDEMPTION_HEAT
	if suspicious_count > 0:
		risk_reasons.append("bent_or_fake_tabs")
	var pattern_heat := 0
	if low_loser_trail:
		var combined_high_value_count := current_high_value_count + recent_high_value_count
		if current_high_value_count > 0 and combined_high_value_count >= CASHOUT_REPEATED_HIGH_VALUE_THRESHOLD:
			pattern_heat += CASHOUT_REPEATED_HIGH_VALUE_HEAT + maxi(0, combined_high_value_count - CASHOUT_REPEATED_HIGH_VALUE_THRESHOLD)
			risk_reasons.append("repeated_high_value_winners_low_loser_trail")
		if winner_count >= CASHOUT_BULK_WINNER_THRESHOLD:
			pattern_heat += CASHOUT_LOW_LOSER_PATTERN_HEAT + maxi(0, winner_count - CASHOUT_BULK_WINNER_THRESHOLD) * CASHOUT_BULK_WINNER_HEAT_STEP
			risk_reasons.append("bulk_winners_low_loser_trail")
	var base_heat := ticket_heat + pattern_heat
	var heat: Dictionary = _pull_tab_cheat_heat(base_heat, stake, run_state, environment)
	return {
		"payout": payout,
		"winner_ticket_count": winner_count,
		"loser_ticket_count": loser_count,
		"expected_loser_trail": expected_loser_trail,
		"low_loser_trail": low_loser_trail,
		"suspicious_ticket_count": suspicious_count,
		"fake_ticket_count": fake_count,
		"current_high_value_ticket_count": current_high_value_count,
		"recent_high_value_ticket_count": recent_high_value_count,
		"ticket_heat": ticket_heat,
		"pattern_heat": pattern_heat,
		"base_heat": maxi(0, base_heat),
		"heat": int(heat.get("suspicion_delta", 0)),
		"security_bankroll_delta": int(heat.get("bankroll_delta", 0)),
		"security_message": str(heat.get("security_message", "")),
		"ended": bool(heat.get("ended", false)),
		"pit_boss_watched": bool(heat.get("pit_boss_watched", false)),
		"pit_boss_heat_bonus": int(heat.get("pit_boss_heat_bonus", 0)),
		"risk_reasons": risk_reasons,
	}


func _pull_tab_cheat_heat(base_heat: int, stake: int, run_state: RunState, environment: Dictionary) -> Dictionary:
	if base_heat <= 0:
		var zero_heat_watch: Dictionary = run_state.pit_boss_watch_status(environment) if run_state != null else {}
		return {
			"suspicion_delta": 0,
			"base_suspicion_delta": 0,
			"bankroll_delta": 0,
			"security_message": "",
			"ended": false,
			"pit_boss_watched": bool(zero_heat_watch.get("watched", false)),
			"pit_boss_heat_bonus": int(zero_heat_watch.get("cheat_heat_bonus", 0)) if bool(zero_heat_watch.get("active", false)) else 0,
		}
	if run_state == null:
		return {
			"suspicion_delta": maxi(0, base_heat),
			"base_suspicion_delta": maxi(0, base_heat),
			"bankroll_delta": 0,
			"security_message": "",
			"ended": false,
			"pit_boss_watched": false,
			"pit_boss_heat_bonus": 0,
		}
	var pit_boss_status: Dictionary = run_state.pit_boss_watch_status(environment)
	var pit_boss_bonus := int(pit_boss_status.get("cheat_heat_bonus", 0)) if bool(pit_boss_status.get("active", false)) else 0
	var raw_heat := maxi(0, base_heat + _item_bonus("cheat_suspicion_delta", run_state, true) + run_state.security_risk_bonus("cheat") + pit_boss_bonus)
	var suspicion_delta := run_state.alcohol_adjusted_suspicion_delta(raw_heat) if raw_heat > 0 else 0
	var pressure: Dictionary = run_state.security_action_pressure("cheat", maxi(1, stake), run_state.suspicion_level() + suspicion_delta) if suspicion_delta > 0 else {}
	var security_message := str(pressure.get("message", ""))
	var pit_boss_summary := str(pit_boss_status.get("summary", "")) if bool(pit_boss_status.get("active", false)) else ""
	if not pit_boss_summary.is_empty():
		security_message = "%s %s" % [pit_boss_summary, security_message]
		security_message = security_message.strip_edges()
	return {
		"suspicion_delta": suspicion_delta,
		"base_suspicion_delta": maxi(0, base_heat),
		"bankroll_delta": int(pressure.get("bankroll_delta", 0)),
		"security_message": security_message,
		"ended": bool(pressure.get("ended", false)),
		"pit_boss_watched": bool(pit_boss_status.get("watched", false)),
		"pit_boss_heat_bonus": pit_boss_bonus,
	}


func _redemption_risk_summary(machine: Dictionary, run_state: RunState) -> String:
	var winners := _ticket_array(machine.get("winner_pile", []))
	if winners.is_empty():
		return "No redemption risk yet."
	var redemption_context := _redemption_context(machine, winners, run_state)
	var suspicious_count := int(redemption_context.get("suspicious_ticket_count", 0))
	var heat := int(redemption_context.get("heat", 0))
	if heat <= 0:
		return "Routine cashout."
	if suspicious_count > 0:
		return "Bent or fake tabs may add heat +%d." % heat
	return "%s Heat +%d." % [_redemption_attention_message(redemption_context), heat]


func _redemption_attention_message(redemption_context: Dictionary) -> String:
	var reasons := _pt_copy_array(redemption_context.get("risk_reasons", []))
	if reasons.has("bent_or_fake_tabs"):
		return "The cashier studies the tabs for tampering."
	if reasons.has("bulk_winners_low_loser_trail") and reasons.has("repeated_high_value_winners_low_loser_trail"):
		return "The cashier notices a streak of valuable winners with too few dead tabs."
	if reasons.has("bulk_winners_low_loser_trail"):
		return "The cashier notices the winner stack is too thick for the dead tabs shown."
	if reasons.has("repeated_high_value_winners_low_loser_trail"):
		return "The cashier notices another high-value winner without enough dead tabs."
	return "The cashout draws attention."


func _expected_cashout_loser_trail(winner_count: int) -> int:
	if winner_count <= 0:
		return 0
	return maxi(CASHOUT_MIN_LOSER_TRAIL, winner_count * CASHOUT_LOSER_TRAIL_PER_WINNER)


func _recent_ticket_history(tickets: Array, limit: int) -> Array:
	var result: Array = []
	for ticket in _ticket_array(tickets):
		if result.size() >= limit:
			break
		result.append(ticket)
	return result


func _high_value_ticket_count(tickets: Array) -> int:
	var count := 0
	for ticket_value in tickets:
		if typeof(ticket_value) != TYPE_DICTIONARY:
			continue
		var ticket: Dictionary = ticket_value as Dictionary
		if int(ticket.get("payout", 0)) >= CASHOUT_HIGH_VALUE_TICKET_THRESHOLD:
			count += 1
	return count


func _redeemer_label(environment: Dictionary) -> String:
	return _counter_staff_label(environment)


func _lottery_counter_config(environment: Dictionary) -> Dictionary:
	var flags := _pt_copy_dict(environment.get("local_narrative_flags", {}))
	return _pt_copy_dict(flags.get("lottery_counter", {}))


func _counter_host_object_id(environment: Dictionary) -> String:
	var counter := _lottery_counter_config(environment)
	if not _pt_copy_array(counter.get("service_game_ids", [])).has(get_id()):
		return ""
	return str(counter.get("host_object_id", "")).strip_edges()


func _counter_staff_label(environment: Dictionary) -> String:
	var configured := str(_lottery_counter_config(environment).get("staff_label", "")).strip_edges()
	if not configured.is_empty():
		return configured
	var scene_type := str(environment.get("visual_context", {}).get("scene_type", ""))
	if scene_type == "bar" or str(environment.get("archetype_id", "")) == "bar":
		return "Bartender"
	return "Counter Staff"


func _counter_speaker_override(environment: Dictionary) -> Dictionary:
	return {
		"role": "staff",
		"name": _counter_staff_label(environment),
		"character_id": "",
		"character_pool_id": "",
		"character_identity_key": _counter_host_object_id(environment),
		"voice_line_key": "",
		"environment_actor": false,
		"mood": "watchful",
		"behavior": "working the sales counter",
		"bind": "none",
	}


func _normalize_prizes(value: Variant) -> Array:
	var result: Array = []
	for prize in _dictionary_array(value):
		var prize_data: Dictionary = prize.duplicate(true)
		prize_data["count"] = maxi(0, int(prize_data.get("count", 0)))
		prize_data["remaining"] = maxi(0, int(prize_data.get("remaining", prize_data.get("count", 0))))
		prize_data["payout"] = maxi(0, int(prize_data.get("payout", 0)))
		prize_data["symbols"] = _string_array(prize_data.get("symbols", []))
		result.append(prize_data)
	return result


func _legacy_ticket_sleeve_for_deal(deal: Dictionary) -> Array:
	var remaining := maxi(0, int(deal.get("remaining", 0)))
	if remaining <= 0:
		return []
	var prizes := _normalize_prizes(deal.get("prizes", []))
	for index in range(prizes.size()):
		var prize: Dictionary = prizes[index]
		var remaining_prizes := maxi(0, int(prize.get("remaining", prize.get("count", 0))))
		prize["count"] = remaining_prizes
		prize["remaining"] = remaining_prizes
		prizes[index] = prize
	var serial := str(deal.get("serial", deal.get("id", "legacy")))
	return _build_ticket_sleeve(prizes, remaining, _seeded_rng("pull_tabs:legacy_sleeve:%s" % serial))


func _deal_array(value: Variant) -> Array:
	var result: Array = []
	for deal in _dictionary_array(value):
		var deal_data: Dictionary = deal.duplicate(true)
		deal_data["price"] = maxi(1, int(deal_data.get("price", 1)))
		deal_data["ticket_count"] = maxi(0, int(deal_data.get("ticket_count", DEFAULT_DEAL_COUNT)))
		deal_data["remaining"] = clampi(int(deal_data.get("remaining", deal_data.get("ticket_count", DEFAULT_DEAL_COUNT))), 0, int(deal_data.get("ticket_count", DEFAULT_DEAL_COUNT)))
		deal_data["sold"] = maxi(0, int(deal_data.get("sold", 0)))
		deal_data["unit_cursor"] = clampi(int(deal_data.get("unit_cursor", int(deal_data.get("initial_removed_count", 0)) + int(deal_data.get("sold", 0)))), 0, int(deal_data.get("ticket_count", DEFAULT_DEAL_COUNT)))
		deal_data["initial_removed_count"] = clampi(int(deal_data.get("initial_removed_count", 0)), 0, int(deal_data.get("ticket_count", DEFAULT_DEAL_COUNT)))
		deal_data["initial_removed_winner_count"] = maxi(0, int(deal_data.get("initial_removed_winner_count", 0)))
		deal_data["initial_removed_payout_total"] = maxi(0, int(deal_data.get("initial_removed_payout_total", 0)))
		deal_data["prizes"] = _normalize_prizes(deal_data.get("prizes", []))
		var sleeve := _int_array(deal_data.get("ticket_sleeve", []))
		if sleeve.is_empty() and int(deal_data.get("remaining", 0)) > 0:
			sleeve = _legacy_ticket_sleeve_for_deal(deal_data)
		deal_data["ticket_sleeve"] = sleeve
		if not sleeve.is_empty() or int(deal_data.get("remaining", 0)) <= 0:
			deal_data["remaining"] = sleeve.size()
		deal_data["palette"] = _pt_copy_dict(deal_data.get("palette", {}))
		result.append(deal_data)
	return result


func _ticket_array(value: Variant) -> Array:
	var result: Array = []
	for ticket in _array_view(value):
		var ticket_data := _ticket_dict(ticket)
		if not ticket_data.is_empty():
			result.append(ticket_data)
	return result


func _ticket_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var ticket_data: Dictionary = (value as Dictionary).duplicate(true)
	ticket_data["price"] = maxi(1, int(ticket_data.get("price", 1)))
	ticket_data["payout"] = maxi(0, int(ticket_data.get("payout", 0)))
	if ticket_data.has("deal_index"):
		ticket_data["deal_index"] = clampi(int(ticket_data.get("deal_index", 0)), 0, PULL_TAB_MACHINE_COLUMN_COUNT - 1)
	ticket_data["rows"] = _pt_copy_array(ticket_data.get("rows", []))
	ticket_data["palette"] = _pt_copy_dict(ticket_data.get("palette", {}))
	ticket_data["tainted"] = bool(ticket_data.get("tainted", false))
	ticket_data["fake"] = bool(ticket_data.get("fake", false))
	ticket_data["sorted"] = bool(ticket_data.get("sorted", false))
	ticket_data["revealed_count"] = clampi(int(ticket_data.get("revealed_count", 0)), 0, _array_size(ticket_data.get("rows", [])))
	ticket_data["fully_revealed"] = bool(ticket_data.get("fully_revealed", false)) or int(ticket_data.get("revealed_count", 0)) >= _array_size(ticket_data.get("rows", []))
	return ticket_data


func _dispense_event_array(value: Variant) -> Array:
	var result: Array = []
	for event in _dictionary_array(value):
		var data: Dictionary = event.duplicate(true)
		data["ticket_id"] = str(data.get("ticket_id", ""))
		data["ticket"] = _ticket_animation_payload(_pt_copy_dict(data.get("ticket", {})))
		data["deal_index"] = clampi(int(data.get("deal_index", 0)), 0, PULL_TAB_MACHINE_COLUMN_COUNT - 1)
		data["sequence_index"] = maxi(0, int(data.get("sequence_index", result.size())))
		data["start_msec"] = maxi(0, int(data.get("start_msec", int(data.get("sequence_index", result.size())) * PULL_TAB_DISPENSE_STAGGER_MSEC)))
		data["drop_start_msec"] = maxi(0, int(data.get("drop_start_msec", PULL_TAB_DISPENSE_DROP_START_MSEC)))
		data["drop_duration_msec"] = maxi(1, int(data.get("drop_duration_msec", PULL_TAB_DISPENSE_DROP_DURATION_MSEC)))
		if not str(data.get("ticket_id", "")).is_empty():
			result.append(data)
	return result


func _environment_hook_array(value: Variant) -> Array:
	var hooks := _dictionary_array(value)
	var defaults := _default_environment_hooks()
	for default_value in defaults:
		var default_hook: Dictionary = default_value
		var default_id := str(default_hook.get("id", ""))
		var found := false
		for hook_value in hooks:
			var hook: Dictionary = hook_value
			if str(hook.get("id", "")) == default_id:
				found = true
				break
		if not found:
			hooks.append(default_hook.duplicate(true))
	return hooks


func _default_environment_hooks(environment: Dictionary = {}) -> Array:
	var host_object_id := _counter_host_object_id(environment)
	return [{
		"id": REDEEM_HOOK_ID,
		"kind": "redeemer",
		"label": "Pull-Tab Counter Redemption",
		"object_id": "game_hook:%s:%s" % [get_id(), REDEEM_HOOK_ID],
		"slot_binding_source_id": host_object_id,
	}, {
		"id": CLERK_DIALOGUE_HOOK_ID,
		"kind": "dialogue",
		"label": "Pull-Tab Counter Help",
		"object_id": "dialogue:%s" % CLERK_DIALOGUE_ID,
		"dialogue_id": CLERK_DIALOGUE_ID,
		"slot_binding_source_id": host_object_id,
	}]


func _seeded_rng(stream_key: String) -> RngStream:
	var rng := RngStream.new()
	rng.configure(RunState.text_to_seed(stream_key), RunState.text_to_seed(stream_key))
	return rng


func _pt_copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _pt_copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _array_view(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return value as Array


func _array_size(value: Variant) -> int:
	if typeof(value) != TYPE_ARRAY:
		return 0
	return (value as Array).size()
