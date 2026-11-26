extends GameModule

# Seeded stock and state shared by venue presentation and the playable cabinet.

const RegionModelScript := preload("res://scripts/games/scratch_ticket_region_model.gd")
const MaskScript := preload("res://scripts/games/scratch_ticket_mask.gd")
const DISPENSE_DURATION_MSEC := 1500
const REDEEM_HOOK_ID := "scratch_ticket_clerk"
const REDEEM_ACTION_ID := "redeem_scratch_winners"
const SCALPER_HOOK_ID := "scratch_ticket_scalper"
const SCALPER_DIALOGUE_KNOWS_ID := "scratch_ticket_scalper_knows"
const SCALPER_DIALOGUE_OBLIVIOUS_ID := "scratch_ticket_scalper_oblivious"
const RESTOCK_INTERVAL_MINUTES := 180
const RESTOCK_ZERO_PERCENT := 50
const RESTOCK_ONE_PERCENT := 40
const SCALPER_VISIT_CHANCE_PERCENT := 30
const SCALPER_KNOWS_CHANCE_PERCENT := 50
const SCALPER_RESTOCK_ARRIVAL_CHANCE_PERCENT := 20
const SCALPER_GIFT_REWARD_CHANCE_PERCENT := 33
const PRACTICE_STOCK_COUNT := 100
const DEFAULT_MASK_COLUMNS := MaskScript.MASK_COLUMNS
const DEFAULT_MASK_ROWS := MaskScript.MASK_ROWS
const ACTIVE_TICKET_TYPE_IDS := ["two_fer", "lucky_7s", "tic_tac_gold", "crossword_corner", "bonus_bingo", "high_roller_holdem", "golden_vault"]
const MACHINE_STATE_VERSION := 6
const REGION_LAYOUT_VERSION := RegionModelScript.LAYOUT_VERSION


func generate_environment_state(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	return _generate_machine_state(run_state, environment, rng)


func environment_object_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, false)
	var rows := _stock_view(machine)
	var public_rows: Array = []
	var stock_total := 0
	var sold_out_count := 0
	for row_value in rows:
		if typeof(row_value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_value
		var remaining := maxi(0, int(row.get("remaining", 0)))
		var palette: Dictionary = row.get("palette", {}) if typeof(row.get("palette", {})) == TYPE_DICTIONARY else {}
		stock_total += remaining
		if remaining <= 0:
			sold_out_count += 1
		public_rows.append({
			"type_id": str(row.get("type_id", "ticket")),
			"remaining": remaining,
			"capacity": maxi(1, int(row.get("capacity", 1))),
			"paper_color": Color(str(palette.get("paper", "#fff2c7"))),
			"accent_color": Color(str(palette.get("accent", "#ef3156"))),
			"ink_color": Color(str(palette.get("ink", "#35152e"))),
		})
	return {
		"runtime_state": {
			"active": stock_total <= 0,
			"status_label": "SOLD OUT" if stock_total <= 0 else "",
		},
		"visual_state": {
			"machine_name": str(machine.get("machine_name", "Highway Scratch Center")),
			"stock_rows": public_rows,
			"stock_total": stock_total,
			"sold_out_count": sold_out_count,
		},
		"status_summary": "Scratch center sold out." if stock_total <= 0 else "%s across %s." % [PlayerTextScript.count_text("ticket", stock_total), PlayerTextScript.count_text("active_row", rows.size() - sold_out_count)],
		"status_message_key": "scratch.stock_summary",
		"status_message_params": {"ticket_count": stock_total, "active_row_count": rows.size() - sold_out_count},
		"state_badge": "OUT" if stock_total <= 0 else "TIX",
	}


func environment_interactable_objects(run_state: RunState, environment: Dictionary) -> Array:
	# Interaction discovery is observational. Project visit/restock state on a
	# detached machine; gameplay action boundaries persist the same projection.
	var machine := _ensure_machine_state(run_state, environment, false)
	var payout := _pending_payout(machine)
	var winners := _dictionary_array(machine.get("winner_pile", [])).size()
	var label := _redeemer_label(environment)
	var host_object_id := _counter_host_object_id(environment)
	var redeem_record := {
		"id": REDEEM_HOOK_ID,
		"object_id": "game_hook:%s:%s" % [get_id(), REDEEM_HOOK_ID],
		"label": label,
		"short_description": "Turns the room's winning scratchers into cash.",
		"enabled": true,
		"recovery": payout > 0,
		"action_summary": "Cash %d winner%s for $%d." % [winners, "" if winners == 1 else "s", payout] if winners > 0 else "No scratched winners to cash.",
		"effect_summary": "$%d waits at the counter." % payout if payout > 0 else "Scratch a winner, then bring it here.",
		"risk_summary": "Large prizes draw the counter staff's attention.",
		"cost_summary": "",
		"slot_binding_source_id": host_object_id,
		"visual_key": "pull_tab_redeemer",
		"visual_type": "service",
		"icon_key": "service",
		"available_actions": [{"id": REDEEM_ACTION_ID, "label": "Cash In Scratchers"}],
		"confirm_action_id": REDEEM_ACTION_ID,
	}
	if host_object_id.is_empty():
		redeem_record["unique_object_class"] = "lottery_redemption_clerk"
		redeem_record["unique_object_priority"] = 120 if payout > 0 else 90
	var objects: Array = [redeem_record]
	if bool(machine.get("scalper_present", false)):
		var knows_schedule := bool(machine.get("scalper_knows_schedule", false))
		var dialogue_id := SCALPER_DIALOGUE_KNOWS_ID if knows_schedule else SCALPER_DIALOGUE_OBLIVIOUS_ID
		objects.append({
			"id": SCALPER_HOOK_ID,
			"object_id": "dialogue:%s" % SCALPER_HOOK_ID,
			"label": "Scalper",
			"short_description": "A reseller camps beside the empty scratch-ticket machine.",
			"enabled": true,
			"action_summary": "Ask about the machine's restock.",
			"effect_summary": "He may know the next release time-or pretend he does not.",
			"risk_summary": "Every slot is empty while he is watching it.",
			"cost_summary": "",
			"dialogue_id": dialogue_id,
			"dialogue_summary": _scalper_dialogue_summary(machine, knows_schedule),
			"visual_key": "scalper",
			"visual_type": "character",
			"icon_key": "clerk_chat",
			"unique_object_class": SCALPER_HOOK_ID,
			"unique_object_priority": 130,
			"available_actions": [{"id": "start_dialogue", "label": "Talk"}],
			"confirm_action_id": "start_dialogue",
		})
	return objects


func prepare_environment_presentation_boundary(run_state: RunState, environment: Dictionary) -> Dictionary:
	if run_state == null or not is_same(environment, run_state.current_environment):
		return {"ok": false, "changed": false, "errors": ["Scratch presence requires the owned current room boundary."]}
	var prior_proof := run_state.validate_room_action_authority()
	if not bool(prior_proof.get("ok", false)):
		return {"ok": false, "changed": false, "errors": JsonCoerceScript._copy_array(prior_proof.get("errors", []))}
	var prior: Dictionary = _dict_ref(_dict_ref(environment.get("game_states", {})).get(get_id(), {}))
	var projected := _ensure_machine_state(run_state, environment, false)
	if projected == prior:
		return {"ok": true, "changed": false, "errors": []}
	# The same deterministic visit/restock projection used by observers belongs
	# to this causal boundary. Commit it before the room manifest and hook list
	# are paired, including a negative visit roll so later reads cannot reroll it.
	var candidate := run_state.detached_host_action_candidate(get_id())
	_ensure_machine_state(candidate, candidate.current_environment, true, false)
	var membership := candidate.prepare_current_environment_object_membership_for_publication(true)
	var proof := candidate.validate_room_action_authority() if bool(membership.get("ok", false)) else membership
	if not bool(proof.get("ok", false)):
		return {"ok": false, "changed": false, "errors": JsonCoerceScript._copy_array(proof.get("errors", []))}
	run_state.publish_host_action_candidate(candidate)
	return {"ok": true, "changed": true, "errors": []}


func environment_runtime_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine := _ensure_machine_state(run_state, environment, false)
	var active := _dict_ref(machine.get("active_ticket", {}))
	var payout := _pending_payout(machine)
	var pending := RunState.scratch_ticket_resolution_pending(machine)
	var unresolved_count := _dictionary_array(machine.get("tray_stack", [])).size() + _dictionary_array(machine.get("pending_queue", [])).size() + (0 if active.is_empty() else 1)
	return {
		"active": pending,
		"bankroll_zero_failure_deferred": run_state != null and run_state.bankroll <= 0 and pending,
		"pending_payout": payout,
		"unresolved_ticket_count": unresolved_count,
		"status_label": "CASH $%d" % payout if payout > 0 else "SCRATCHING" if not active.is_empty() else "TICKETS" if pending else "",
		"status_summary": "$%d in scratched winners; %s." % [payout, "%d tickets to finish" % unresolved_count if unresolved_count > 0 else "surface clear"],
	}


func _redeemer_label(environment: Dictionary) -> String:
	var counter := _lottery_counter_config(environment)
	var configured := str(counter.get("staff_label", "")).strip_edges()
	if not configured.is_empty():
		return configured
	var scene_type := str(environment.get("visual_context", {}).get("scene_type", ""))
	if scene_type == "bar" or str(environment.get("archetype_id", "")) == "bar":
		return "Bartender"
	return "Counter Staff"


func _lottery_counter_config(environment: Dictionary) -> Dictionary:
	var flags := _copy_dict(environment.get("local_narrative_flags", {}))
	return _copy_dict(flags.get("lottery_counter", {}))


func _counter_host_object_id(environment: Dictionary) -> String:
	var counter := _lottery_counter_config(environment)
	if not _array_ref(counter.get("service_game_ids", [])).has(get_id()):
		return ""
	return str(counter.get("host_object_id", "")).strip_edges()


func _is_practice_environment(environment: Dictionary) -> bool:
	var flags_value: Variant = environment.get("local_narrative_flags", {})
	var flags: Dictionary = flags_value if typeof(flags_value) == TYPE_DICTIONARY else {}
	return bool(flags.get("practice_session", false))


func _generate_machine_state(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var day_key := int(environment.get("generated_day", environment.get("day", 0)))
	var stream_key := "scratch-stock:%s:day:%d" % [str(environment.get("id", "room")), day_key]
	var root_rng := rng if rng != null else _seeded_rng("scratch-stock-root:%s" % str(environment.get("id", "room")))
	var machine_rng := root_rng.fork(stream_key)
	var current_absolute_minute := maxi(0, run_state.game_clock_minutes) if run_state != null else maxi(0, day_key * 1440)
	var restock_phase_minute := machine_rng.randi_range(0, RESTOCK_INTERVAL_MINUTES - 1)
	var practice_session := _is_practice_environment(environment)
	var stock: Array = []
	for ticket_type_value in _ticket_types():
		var ticket_type: Dictionary = ticket_type_value
		var count_range := _int_array(ticket_type.get("stock_count", [0, 5]))
		var maximum := PRACTICE_STOCK_COUNT if practice_session else clampi(int(count_range[1]) if count_range.size() > 1 else 5, 1, 5)
		var stock_roll := machine_rng.randi_range(0, 19)
		# Consume one stable roll per family so stock remains deterministic when
		# ticket families are added or migrated.
		var remaining := PRACTICE_STOCK_COUNT if practice_session else (0 if stock_roll < 15 else mini(maximum, stock_roll - 14))
		stock.append({
			"type_id": str(ticket_type.get("id", "")),
			"display_name": str(ticket_type.get("display_name", "Ticket")),
			"price": maxi(1, int(ticket_type.get("price", 1))),
			"remaining": remaining,
			"capacity": maximum,
			"stock_weight": maxi(1, int(ticket_type.get("stock_weight", 1))),
			"size_id": str(ticket_type.get("size_id", "medium_square")),
			"palette": _copy_dict(_copy_dict(ticket_type.get("face", {})).get("palette", {})),
			"release_availability": "active",
		})
	var initially_empty := _stock_total_from_rows(stock) <= 0
	var initial_scalper_present := initially_empty and run_state != null and not run_state.is_tutorial_run()
	var initial_scalper_knows := initial_scalper_present and scalper_knows_for_roll(machine_rng.randi_range(0, 99))
	var initial_visit_token := _scratch_visit_token(run_state, environment) if initial_scalper_present else ""
	return {
		"schema": "scratch_ticket_machine_state",
		"version": MACHINE_STATE_VERSION,
		"machine_name": "Highway Scratch Center",
		"stock_day": int(environment.get("generated_day", environment.get("day", 0))),
		"stock_stream_key": stream_key,
		"stock_weighting": "full_roster_75_out_of_stock_1_to_5",
		"restock_interval_minutes": RESTOCK_INTERVAL_MINUTES,
		"restock_distribution": "50_percent_0_40_percent_1_10_percent_2",
		"restock_phase_minute": restock_phase_minute,
		"restock_cursor_absolute_minute": current_absolute_minute,
		"next_restock_absolute_minute": _next_restock_after(current_absolute_minute, restock_phase_minute),
		"last_restock_scheduled_count": 0,
		"last_restock_stocked_count": 0,
		"restock_event_count": 0,
		"scalper_visit_chance_percent": SCALPER_VISIT_CHANCE_PERCENT,
		"scalper_restock_arrival_chance_percent": SCALPER_RESTOCK_ARRIVAL_CHANCE_PERCENT,
		"scalper_gift_reward_chance_percent": SCALPER_GIFT_REWARD_CHANCE_PERCENT,
		# A machine generated with no sellable tickets always has a scalper already
		# camping it. Stocked machines keep the normal seeded visit chance below.
		"scalper_present": initial_scalper_present,
		"scalper_knows_schedule": initial_scalper_knows,
		"scalper_visit_token": initial_visit_token,
		"scalper_gift_visit_token": "",
		"scalper_gift_count": 0,
		"scalper_last_gift_ticket_id": "",
		"scalper_last_gift_reward_item_id": "",
		"scalper_restock_arrival_count": 0,
		"scalper_last_restock_arrival_boundary": -1,
		"scalper_cleared_count": 0,
		"scalper_intercepted_restock_count": 0,
		"stock": stock,
		"environment_hooks": [{
			"id": REDEEM_HOOK_ID,
			"kind": "redeemer",
			"label": "Scratch-Ticket Counter Redemption",
			"slot_binding_source_id": _counter_host_object_id(environment),
			"unique_object_class": "scratch_ticket_clerk",
			"unique_object_priority": 100,
		}, {
			"id": SCALPER_HOOK_ID,
			"kind": "dialogue",
			"label": "Scalper",
			"object_id": "dialogue:%s" % SCALPER_HOOK_ID,
			"unique_object_class": SCALPER_HOOK_ID,
			"unique_object_priority": 130,
		}],
		"active_ticket": {},
		"tray_stack": [],
		"pending_queue": [],
		"winner_pile": [],
		"loser_pile": [],
		"loser_archive_count": 0,
		"pending_penalty": 0,
		"penalty_shields_remaining": 0,
		"purchased_count": 0,
		"redeemed_count": 0,
		"last_dispense_id": "",
		"last_dispense_slot": 0,
		"dispense_started_msec": 0,
		"last_dispense_events": [],
		"last_settled_ticket": {},
		"last_settled_pile": "",
		"last_file_id": "",
		"file_started_msec": 0,
		"last_sweep_id": "",
		"last_sweep_section": "",
		"sweep_started_msec": 0,
	}


func _ensure_ticket_regions(ticket: Dictionary) -> void:
	MaskScript.ensure(ticket)


func _stock_view(machine: Dictionary) -> Array:
	var result: Array = []
	var stock := _dictionary_array(machine.get("stock", []))
	for index in range(stock.size()):
		var value: Dictionary = stock[index]
		var view := value.duplicate(true)
		view["source_stock_index"] = index
		result.append(view)
	return result


static func restock_count_for_roll(roll: int) -> int:
	var normalized_roll := posmod(roll, 100)
	if normalized_roll < RESTOCK_ZERO_PERCENT:
		return 0
	if normalized_roll < RESTOCK_ZERO_PERCENT + RESTOCK_ONE_PERCENT:
		return 1
	return 2


static func scalper_present_for_roll(roll: int) -> bool:
	return posmod(roll, 100) < SCALPER_VISIT_CHANCE_PERCENT


static func scalper_knows_for_roll(roll: int) -> bool:
	return posmod(roll, 100) < SCALPER_KNOWS_CHANCE_PERCENT


static func scalper_restock_arrives_for_roll(roll: int) -> bool:
	return posmod(roll, 100) < SCALPER_RESTOCK_ARRIVAL_CHANCE_PERCENT


static func _next_restock_after(absolute_minute: int, phase_minute: int) -> int:
	var cursor := maxi(0, absolute_minute)
	var phase := clampi(phase_minute, 0, RESTOCK_INTERVAL_MINUTES - 1)
	var cycle_start := cursor - posmod(cursor, RESTOCK_INTERVAL_MINUTES)
	var candidate := cycle_start + phase
	if candidate <= cursor:
		candidate += RESTOCK_INTERVAL_MINUTES
	return candidate


func _advance_restock_schedule(run_state: RunState, environment: Dictionary, machine: Dictionary, reconcile_membership: bool = true) -> bool:
	if run_state == null:
		return false
	var scalper_was_present_at_entry := bool(machine.get("scalper_present", false))
	var now := maxi(0, run_state.game_clock_minutes)
	var phase := clampi(int(machine.get("restock_phase_minute", 0)), 0, RESTOCK_INTERVAL_MINUTES - 1)
	var cursor := maxi(0, int(machine.get("restock_cursor_absolute_minute", now)))
	var next_boundary := _next_restock_after(cursor, phase)
	var changed := false
	while next_boundary <= now:
		var rng := run_state.create_rng("scratch-restock:%s:%d" % [_machine_identity(environment), next_boundary])
		var scheduled_count := restock_count_for_roll(rng.randi_range(0, 99))
		var stocked_count := 0
		var scalper_was_present := bool(machine.get("scalper_present", false))
		if scalper_was_present:
			machine["scalper_intercepted_restock_count"] = int(machine.get("scalper_intercepted_restock_count", 0)) + scheduled_count
		else:
			stocked_count = _add_restock_tickets(machine, scheduled_count, rng)
			if not _is_practice_environment(environment) and not run_state.is_tutorial_run():
				var arrival_rng := run_state.create_rng("scratch-restock-scalper-arrival:%s:%d" % [_machine_identity(environment), next_boundary])
				if scalper_restock_arrives_for_roll(arrival_rng.randi_range(0, 99)):
					machine["scalper_present"] = true
					machine["scalper_knows_schedule"] = scalper_knows_for_roll(arrival_rng.randi_range(0, 99))
					machine["scalper_visit_token"] = _scratch_visit_token(run_state, environment)
					machine["scalper_cleared_count"] = 0
					machine["scalper_restock_arrival_count"] = int(machine.get("scalper_restock_arrival_count", 0)) + 1
					machine["scalper_last_restock_arrival_boundary"] = next_boundary
		machine["last_restock_scheduled_count"] = scheduled_count
		machine["last_restock_stocked_count"] = stocked_count
		machine["restock_event_count"] = int(machine.get("restock_event_count", 0)) + 1
		cursor = next_boundary
		next_boundary = _next_restock_after(cursor, phase)
		changed = true
	machine["restock_cursor_absolute_minute"] = cursor
	machine["next_restock_absolute_minute"] = next_boundary
	if reconcile_membership:
		_reconcile_persisted_scalper_transition(environment, machine, run_state, scalper_was_present_at_entry)
	return changed


func _add_restock_tickets(machine: Dictionary, count: int, rng: RngStream) -> int:
	var stock := _dictionary_array(machine.get("stock", []))
	var added := 0
	for _ticket_index in range(clampi(count, 0, 2)):
		var eligible_indexes: Array[int] = []
		var total_weight := 0
		for index in range(stock.size()):
			var slot: Dictionary = stock[index]
			if int(slot.get("remaining", 0)) >= int(slot.get("capacity", 5)):
				continue
			eligible_indexes.append(index)
			total_weight += maxi(1, int(slot.get("stock_weight", 1)))
		if eligible_indexes.is_empty() or total_weight <= 0:
			break
		var pick := rng.randi_range(1, total_weight)
		var chosen_index := int(eligible_indexes.back())
		for index in eligible_indexes:
			pick -= maxi(1, int((stock[index] as Dictionary).get("stock_weight", 1)))
			if pick <= 0:
				chosen_index = index
				break
		var chosen: Dictionary = stock[chosen_index]
		chosen["remaining"] = int(chosen.get("remaining", 0)) + 1
		stock[chosen_index] = chosen
		added += 1
	machine["stock"] = stock
	return added


func _refresh_scalper_for_visit(run_state: RunState, environment: Dictionary, machine: Dictionary, reconcile_membership: bool = true) -> bool:
	if run_state == null:
		return false
	var scalper_was_present := bool(machine.get("scalper_present", false))
	var visit_token := _scratch_visit_token(run_state, environment)
	if _is_practice_environment(environment):
		var practice_changed := bool(machine.get("scalper_present", false)) or bool(machine.get("scalper_knows_schedule", false))
		machine["scalper_present"] = false
		machine["scalper_knows_schedule"] = false
		machine["scalper_visit_token"] = visit_token
		if reconcile_membership:
			_reconcile_persisted_scalper_transition(environment, machine, run_state, scalper_was_present)
		return practice_changed
	if run_state.is_tutorial_run():
		var tutorial_changed := bool(machine.get("scalper_present", false)) or bool(machine.get("scalper_knows_schedule", false))
		machine["scalper_present"] = false
		machine["scalper_knows_schedule"] = false
		machine["scalper_visit_token"] = visit_token
		if reconcile_membership:
			_reconcile_persisted_scalper_transition(environment, machine, run_state, scalper_was_present)
		return tutorial_changed
	var same_visit := visit_token == str(machine.get("scalper_visit_token", ""))
	if same_visit and (bool(machine.get("scalper_present", false)) or _stock_total(machine) > 0):
		return false
	machine["scalper_visit_token"] = visit_token
	var rng := run_state.create_rng("scratch-scalper:%s:%s" % [_machine_identity(environment), visit_token])
	# Empty-on-arrival is the encounter condition itself. The percentage roll is
	# only needed when a stocked machine may be intercepted and cleared.
	var present := _stock_total(machine) <= 0 or scalper_present_for_roll(rng.randi_range(0, 99))
	var knows_schedule := present and scalper_knows_for_roll(rng.randi_range(0, 99))
	machine["scalper_present"] = present
	machine["scalper_knows_schedule"] = knows_schedule
	machine["scalper_cleared_count"] = _clear_machine_stock(machine) if present else 0
	if reconcile_membership:
		_reconcile_persisted_scalper_transition(environment, machine, run_state, scalper_was_present)
	return true


func _clear_machine_stock(machine: Dictionary) -> int:
	var stock := _dictionary_array(machine.get("stock", []))
	var cleared := 0
	for index in range(stock.size()):
		var slot: Dictionary = stock[index]
		cleared += maxi(0, int(slot.get("remaining", 0)))
		slot["remaining"] = 0
		stock[index] = slot
	machine["stock"] = stock
	return cleared


func _stock_total(machine: Dictionary) -> int:
	return _stock_total_from_rows(_dictionary_array(machine.get("stock", [])))


func _stock_total_from_rows(stock: Array) -> int:
	var total := 0
	for slot_value in stock:
		var slot: Dictionary = slot_value
		if str(slot.get("type_id", "")).is_empty():
			continue
		total += maxi(0, int(slot.get("remaining", 0)))
	return total


func _scratch_visit_token(run_state: RunState, environment: Dictionary) -> String:
	var entered_at := maxi(0, int(environment.get("entered_game_clock_minutes", run_state.game_clock_minutes if run_state != null else 0)))
	return "%s@%d" % [_machine_identity(environment), entered_at]


func _machine_identity(environment: Dictionary) -> String:
	return RunState.portable_ticket_origin_key(environment)


func _scalper_dialogue_summary(machine: Dictionary, knows_schedule: bool) -> String:
	var gift_used := str(machine.get("scalper_gift_visit_token", "")) == str(machine.get("scalper_visit_token", "")) \
		and not str(machine.get("scalper_visit_token", "")).is_empty()
	var gift_note := " He already took the one ticket he will accept this visit." if gift_used else ""
	if knows_schedule:
		var next_restock := int(machine.get("next_restock_absolute_minute", 0))
		return ("I keep the counter schedule. This machine resets every three hours: %s, then %s, then %s. Be here before the cashier wheels past." % [
			_clock_text_at_absolute_minute(next_restock),
			_clock_text_at_absolute_minute(next_restock + RESTOCK_INTERVAL_MINUTES),
			_clock_text_at_absolute_minute(next_restock + RESTOCK_INTERVAL_MINUTES * 2),
		]) + gift_note
	return "Restock time? Never heard of one. I am just standing beside an empty machine because I like the carpet." + gift_note


static func _clock_text_at_absolute_minute(absolute_minute: int) -> String:
	return PlayerTextScript.format_game_clock(absolute_minute, true, ", ")


func _normalize_machine_state(machine: Dictionary, run_state: RunState = null) -> void:
	if _machine_state_is_current(machine):
		return
	var needs_upgrade := int(machine.get("version", 1)) < MACHINE_STATE_VERSION or not machine.has("tray_stack") or not machine.has("pending_queue")
	if not machine.has("tray_stack"):
		machine["tray_stack"] = []
	if not machine.has("pending_queue"):
		machine["pending_queue"] = []
	if not machine.has("winner_pile"):
		machine["winner_pile"] = []
	if not machine.has("loser_pile"):
		machine["loser_pile"] = []
	machine["loser_archive_count"] = maxi(0, int(machine.get("loser_archive_count", 0)))
	var active_value: Variant = machine.get("active_ticket", {})
	if typeof(active_value) == TYPE_DICTIONARY:
		var active: Dictionary = active_value
		if _ticket_region_upgrade_needed(active) or needs_upgrade:
			_ensure_ticket_regions(active)
		machine["active_ticket"] = active
	if needs_upgrade:
		for field in ["tray_stack", "pending_queue", "winner_pile", "loser_pile"]:
			var tickets := _dictionary_array(machine.get(field, []))
			for index in range(tickets.size()):
				var ticket: Dictionary = tickets[index]
				if bool(ticket.get("mask_compacted", false)):
					continue
				if _ticket_region_upgrade_needed(ticket) or needs_upgrade:
					_ensure_ticket_regions(ticket)
					tickets[index] = ticket
			machine[field] = tickets
	var stock := _dictionary_array(machine.get("stock", []))
	for index in range(stock.size()):
		var slot: Dictionary = stock[index]
		var ticket_type := _ticket_type(str(slot.get("type_id", "")))
		var count_range := _int_array(ticket_type.get("stock_count", [0, 5]))
		var default_capacity := clampi(int(count_range[1]) if count_range.size() > 1 else 5, 1, 5)
		slot["capacity"] = maxi(1, int(slot.get("capacity", default_capacity)))
		slot["remaining"] = clampi(int(slot.get("remaining", 0)), 0, int(slot.get("capacity", default_capacity)))
		slot["release_availability"] = "active"
		stock[index] = slot
	machine["stock"] = stock
	machine["last_dispense_events"] = _scratch_dispense_event_array(machine.get("last_dispense_events", []))
	var phase_fallback := posmod(RunState.text_to_seed(str(machine.get("stock_stream_key", "scratch-restock"))), RESTOCK_INTERVAL_MINUTES)
	var phase := clampi(int(machine.get("restock_phase_minute", phase_fallback)), 0, RESTOCK_INTERVAL_MINUTES - 1)
	var current_absolute_minute := maxi(0, run_state.game_clock_minutes) if run_state != null else maxi(0, int(machine.get("stock_day", 0)) * 1440)
	var cursor := maxi(0, int(machine.get("restock_cursor_absolute_minute", current_absolute_minute)))
	machine["restock_interval_minutes"] = RESTOCK_INTERVAL_MINUTES
	machine["restock_distribution"] = "50_percent_0_40_percent_1_10_percent_2"
	machine["restock_phase_minute"] = phase
	machine["restock_cursor_absolute_minute"] = cursor
	machine["next_restock_absolute_minute"] = maxi(cursor + 1, int(machine.get("next_restock_absolute_minute", _next_restock_after(cursor, phase))))
	machine["last_restock_scheduled_count"] = clampi(int(machine.get("last_restock_scheduled_count", 0)), 0, 2)
	machine["last_restock_stocked_count"] = clampi(int(machine.get("last_restock_stocked_count", 0)), 0, 2)
	machine["restock_event_count"] = maxi(0, int(machine.get("restock_event_count", 0)))
	machine["scalper_visit_chance_percent"] = SCALPER_VISIT_CHANCE_PERCENT
	machine["scalper_restock_arrival_chance_percent"] = SCALPER_RESTOCK_ARRIVAL_CHANCE_PERCENT
	machine["scalper_gift_reward_chance_percent"] = SCALPER_GIFT_REWARD_CHANCE_PERCENT
	machine["scalper_present"] = bool(machine.get("scalper_present", false))
	machine["scalper_knows_schedule"] = bool(machine.get("scalper_knows_schedule", false))
	machine["scalper_visit_token"] = str(machine.get("scalper_visit_token", ""))
	machine["scalper_gift_visit_token"] = str(machine.get("scalper_gift_visit_token", ""))
	machine["scalper_gift_count"] = maxi(0, int(machine.get("scalper_gift_count", 0)))
	machine["scalper_last_gift_ticket_id"] = str(machine.get("scalper_last_gift_ticket_id", ""))
	machine["scalper_last_gift_reward_item_id"] = str(machine.get("scalper_last_gift_reward_item_id", ""))
	machine["scalper_cleared_count"] = maxi(0, int(machine.get("scalper_cleared_count", 0)))
	machine["scalper_intercepted_restock_count"] = maxi(0, int(machine.get("scalper_intercepted_restock_count", 0)))
	machine["scalper_restock_arrival_count"] = maxi(0, int(machine.get("scalper_restock_arrival_count", 0)))
	machine["scalper_last_restock_arrival_boundary"] = int(machine.get("scalper_last_restock_arrival_boundary", -1))
	machine["version"] = maxi(MACHINE_STATE_VERSION, int(machine.get("version", 1)))


func _machine_state_is_current(machine: Dictionary) -> bool:
	if int(machine.get("version", 0)) < MACHINE_STATE_VERSION:
		return false
	if str(machine.get("schema", "")) != "scratch_ticket_machine_state":
		return false
	for field in ["stock", "tray_stack", "pending_queue", "winner_pile", "loser_pile"]:
		if typeof(machine.get(field, null)) != TYPE_ARRAY:
			return false
	for slot_value in machine.get("stock", []) as Array:
		if typeof(slot_value) != TYPE_DICTIONARY:
			return false
		var slot := slot_value as Dictionary
		if str(slot.get("release_availability", "")) != "active":
			return false
	if typeof(machine.get("active_ticket", null)) != TYPE_DICTIONARY:
		return false
	var active: Dictionary = machine.get("active_ticket", {}) as Dictionary
	if _ticket_region_upgrade_needed(active):
		return false
	return machine.has("restock_phase_minute") and machine.has("restock_cursor_absolute_minute") and machine.has("next_restock_absolute_minute") \
		and machine.has("scalper_gift_visit_token") and machine.has("scalper_restock_arrival_count")


func _ticket_region_upgrade_needed(ticket: Dictionary) -> bool:
	if ticket.is_empty():
		return false
	if bool(ticket.get("mask_compacted", false)):
		return false
	var scratch: Dictionary = ticket.get("scratch", {}) if typeof(ticket.get("scratch", {})) == TYPE_DICTIONARY else {}
	var columns := maxi(24, int(scratch.get("mask_columns", DEFAULT_MASK_COLUMNS)))
	var rows := maxi(18, int(scratch.get("mask_rows", DEFAULT_MASK_ROWS)))
	var mask: Array = ticket.get("latex_mask", []) if typeof(ticket.get("latex_mask", [])) == TYPE_ARRAY else []
	var regions_value: Variant = ticket.get("scratch_regions", [])
	if typeof(regions_value) != TYPE_ARRAY or (regions_value as Array).is_empty() or mask.size() != columns * rows:
		return true
	if int(ticket.get("region_layout_version", 0)) != REGION_LAYOUT_VERSION:
		return true
	var first_region_value: Variant = (regions_value as Array)[0]
	if typeof(first_region_value) != TYPE_DICTIONARY:
		return true
	var first_region: Dictionary = first_region_value as Dictionary
	if int(first_region.get("layout_version", 0)) != REGION_LAYOUT_VERSION:
		return true
	return int(first_region.get("sample_total", 0)) <= 0


func _ensure_machine_state(run_state: RunState, environment: Dictionary, persist: bool, reconcile_membership: bool = true) -> Dictionary:
	var states_value: Variant = environment.get("game_states", {})
	var states: Dictionary = states_value as Dictionary if typeof(states_value) == TYPE_DICTIONARY else {}
	var value: Variant = states.get(get_id(), {})
	if typeof(value) == TYPE_DICTIONARY and not (value as Dictionary).is_empty():
		var machine := value as Dictionary if persist else (value as Dictionary).duplicate(true)
		_normalize_machine_state(machine, run_state)
		# Project elapsed restocks and the visit-scoped scalper on the owned copy
		# used by presentation reads. Persistent callers receive the same
		# deterministic projection and commit it at their action boundary.
		_refresh_scalper_for_visit(run_state, environment, machine, reconcile_membership)
		_advance_restock_schedule(run_state, environment, machine, reconcile_membership)
		if persist:
			_sync_portable_ticket_state(run_state, environment, machine)
		else:
			_merge_portable_ticket_state_readonly(run_state, environment, machine)
		return machine
	var generated := _generate_machine_state(run_state, environment, null)
	_normalize_machine_state(generated, run_state)
	_refresh_scalper_for_visit(run_state, environment, generated, reconcile_membership)
	_advance_restock_schedule(run_state, environment, generated, reconcile_membership)
	if persist:
		_sync_portable_ticket_state(run_state, environment, generated)
	else:
		_merge_portable_ticket_state_readonly(run_state, environment, generated)
	if persist:
		var writable_states := states.duplicate(false)
		writable_states[get_id()] = generated
		environment["game_states"] = writable_states
		if reconcile_membership:
			_reconcile_scalper_membership(environment, run_state)
	return generated


func _reconcile_persisted_scalper_transition(environment: Dictionary, machine: Dictionary, run_state: RunState, prior_present: bool) -> void:
	if run_state == null or prior_present == bool(machine.get("scalper_present", false)):
		return
	var states_value: Variant = environment.get("game_states", {})
	if typeof(states_value) != TYPE_DICTIONARY:
		return
	var persisted_value: Variant = (states_value as Dictionary).get(get_id(), {})
	# Read-only projections intentionally exercise the same deterministic visit and
	# restock logic on a detached copy. Only an owned machine can change physical
	# room membership or any persisted alias.
	if typeof(persisted_value) != TYPE_DICTIONARY or not is_same(persisted_value, machine):
		return
	_reconcile_scalper_membership(environment, run_state)


func _reconcile_scalper_membership(environment: Dictionary, run_state: RunState) -> void:
	if run_state == null or environment.is_empty():
		return
	if is_same(environment, run_state.current_environment):
		run_state.prepare_current_environment_object_membership_for_publication()
	else:
		run_state.reconcile_environment_object_membership(environment)


func _sync_portable_ticket_state(run_state: RunState, environment: Dictionary, machine: Dictionary) -> void:
	if run_state == null:
		return
	var portable := run_state.portable_ticket_state(get_id(), environment)
	if portable.is_empty():
		_stamp_machine_ticket_origins(machine, environment)
		var legacy := _portable_ticket_player_state(machine)
		if _portable_ticket_count(legacy) > 0:
			run_state.remember_portable_ticket_state(get_id(), environment, legacy)
			portable = run_state.portable_ticket_state(get_id(), environment)
	if portable.is_empty():
		return
	for field in ["active_ticket", "tray_stack", "pending_queue", "winner_pile", "loser_pile", "loser_archive_count", "pending_penalty", "penalty_shields_remaining", "last_settled_ticket", "last_settled_pile", "last_file_id", "file_started_msec", "last_sweep_id", "last_sweep_section", "sweep_started_msec"]:
		if portable.has(field):
			machine[field] = portable[field]
	_normalize_machine_state(machine, run_state)


func _merge_portable_ticket_state_readonly(run_state: RunState, environment: Dictionary, machine: Dictionary) -> void:
	if run_state == null:
		return
	var portable := run_state.portable_ticket_state(get_id(), environment)
	if portable.is_empty():
		return
	for field in ["active_ticket", "tray_stack", "pending_queue", "winner_pile", "loser_pile", "loser_archive_count", "pending_penalty", "penalty_shields_remaining", "last_settled_ticket", "last_settled_pile", "last_file_id", "file_started_msec", "last_sweep_id", "last_sweep_section", "sweep_started_msec"]:
		if portable.has(field):
			var value: Variant = portable[field]
			if typeof(value) == TYPE_DICTIONARY:
				machine[field] = (value as Dictionary).duplicate(true)
			elif typeof(value) == TYPE_ARRAY:
				machine[field] = (value as Array).duplicate(true)
			else:
				machine[field] = value
	_normalize_machine_state(machine, run_state)


func _portable_ticket_player_state(machine: Dictionary) -> Dictionary:
	return {
		"active_ticket": machine.get("active_ticket", {}),
		"tray_stack": machine.get("tray_stack", []),
		"pending_queue": machine.get("pending_queue", []),
		"winner_pile": machine.get("winner_pile", []),
		"loser_pile": machine.get("loser_pile", []),
		"loser_archive_count": maxi(0, int(machine.get("loser_archive_count", 0))),
		"pending_penalty": maxi(0, int(machine.get("pending_penalty", 0))),
		"penalty_shields_remaining": maxi(0, int(machine.get("penalty_shields_remaining", 0))),
		"last_settled_ticket": _copy_dict(machine.get("last_settled_ticket", {})),
		"last_settled_pile": str(machine.get("last_settled_pile", "")),
		"last_file_id": str(machine.get("last_file_id", "")),
		"file_started_msec": maxi(0, int(machine.get("file_started_msec", 0))),
		"last_sweep_id": str(machine.get("last_sweep_id", "")),
		"last_sweep_section": str(machine.get("last_sweep_section", "")),
		"sweep_started_msec": maxi(0, int(machine.get("sweep_started_msec", 0))),
	}


func _portable_ticket_count(state: Dictionary) -> int:
	return (0 if _dict_ref(state.get("active_ticket", {})).is_empty() else 1) + _dictionary_array(state.get("tray_stack", [])).size() + _dictionary_array(state.get("pending_queue", [])).size() + _dictionary_array(state.get("winner_pile", [])).size() + _dictionary_array(state.get("loser_pile", [])).size() + maxi(0, int(state.get("loser_archive_count", 0)))


func _stamp_ticket_origin(ticket: Dictionary, environment: Dictionary) -> void:
	if ticket.is_empty():
		return
	ticket["origin_key"] = RunState.portable_ticket_origin_key(environment)
	ticket["origin_name"] = RunState.portable_ticket_origin_name(environment)
	ticket["origin_environment_id"] = str(environment.get("id", "")).strip_edges()
	ticket["origin_world_node_id"] = str(environment.get("world_node_id", "")).strip_edges()


func _stamp_machine_ticket_origins(machine: Dictionary, environment: Dictionary) -> void:
	var active_value: Variant = machine.get("active_ticket", {})
	if typeof(active_value) == TYPE_DICTIONARY:
		_stamp_ticket_origin(active_value as Dictionary, environment)
	for field in ["tray_stack", "pending_queue", "winner_pile", "loser_pile"]:
		for ticket_value in _dictionary_array(machine.get(field, [])):
			_stamp_ticket_origin(ticket_value as Dictionary, environment)


func _ticket_types() -> Array:
	if library != null:
		return _dictionary_array(library.scratch_ticket_types)
	return []


func _ticket_type(type_id: String) -> Dictionary:
	for value in _ticket_types():
		var ticket_type: Dictionary = value
		if str(ticket_type.get("id", "")) == type_id:
			return ticket_type
	return {}


func _pending_payout(machine: Dictionary) -> int:
	var total := 0
	for value in _dictionary_array(machine.get("winner_pile", [])):
		total += maxi(0, int((value as Dictionary).get("payout", 0)))
	return total


func _scratch_dispense_event_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for event_value in value as Array:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event := (event_value as Dictionary).duplicate(true)
		event["slot"] = clampi(int(event.get("slot", 0)), 0, maxi(0, ACTIVE_TICKET_TYPE_IDS.size() - 1))
		event["start_msec"] = maxi(0, int(event.get("start_msec", result.size() * DISPENSE_DURATION_MSEC)))
		event["duration_msec"] = DISPENSE_DURATION_MSEC
		result.append(event)
	return result


func _seeded_rng(stream_key: String) -> RngStream:
	var rng := RngStream.new()
	var seed := RunState.text_to_seed(stream_key)
	rng.configure(seed, seed)
	return rng


func _dict_ref(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array_ref(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []
