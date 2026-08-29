class_name EventModule
extends RefCounted

# Data-backed event contract for conditional run consequences.

const CrewRecruitmentModelScript := preload("res://scripts/core/crew_recruitment_model.gd")
const CharacterChainModelScript := preload("res://scripts/core/character_chain_model.gd")

var definition: Dictionary = {}
var content_library: ContentLibrary = null


# Stores the event definition used by this module.
func setup(p_definition: Dictionary, p_library: ContentLibrary = null) -> void:
	definition = p_definition.duplicate(true)
	content_library = p_library


# Returns this event id.
func get_id() -> String:
	return str(definition.get("id", ""))


# Returns the player-facing event name.
func get_display_name() -> String:
	return str(definition.get("display_name", get_id()))


# Returns the event type.
func get_event_type() -> String:
	return str(definition.get("type", ""))


# Returns the event interaction mode.
func get_interaction_mode() -> String:
	return str(definition.get("interaction_mode", "interactable"))


# Returns available event choices.
func choices(run_state: RunState = null, environment: Dictionary = {}) -> Array:
	var payload := _copy_dict(definition.get("payload", {}))
	if get_id() == "crew_planning_table":
		return run_state.crew_heist_table_choices() if run_state != null else []
	if get_id() == "heist_live_table":
		return run_state.crew_heist_live_table_choices() if run_state != null else []
	if str(payload.get("kind", "")) == "crew_rook_signpost":
		return CrewRecruitmentModelScript.rook_signpost_choices(run_state) if run_state != null else []
	if str(payload.get("kind", "")) == "crew_rook_leads":
		return CrewRecruitmentModelScript.rook_signpost_choices(run_state, false) if run_state != null else []
	if str(payload.get("kind", "")) == "crew_contact":
		return CrewRecruitmentModelScript.contact_choices(run_state, environment, str(payload.get("member_id", "")), content_library) if run_state != null else []
	if str(payload.get("kind", "")) == "crew_job_board":
		return run_state.crew_job_board_choices(payload) if run_state != null else []
	if str(payload.get("kind", "")) == "crew_practice_rig":
		return run_state.crew_practice_rig_choices() if run_state != null else []
	if str(payload.get("kind", "")) == "crew_stake_horse_loss":
		return run_state.crew_stake_horse_loss_choices() if run_state != null else []
	if str(payload.get("kind", "")) == "crew_collection_press":
		return run_state.crew_collection_choices() if run_state != null else []
	if str(payload.get("kind", "")) == "crew_rook_ride":
		if run_state == null:
			return []
		var ride := run_state.crew_rook_ride_status()
		return [
			{"id": "call_ride", "label": "Call Rook's ride", "text": "%d/%d rides remain · %d%% route discount." % [int(ride.get("uses_remaining", 0)), int(ride.get("cap", 0)), int(ride.get("discount_percent", 0))], "consequences": {"event_hooks": [{"type": "crew_rook_ride"}]}, "conditions": {"requires_flags": {}}},
			{"id": "leave", "label": "Keep walking", "text": "Rook leaves the engine quiet.", "consequences": {}},
		] if bool(ride.get("available", false)) else [{"id": "leave", "label": "Ride unavailable", "text": "Travel is locked or today's rides are used.", "consequences": {}}]
	if str(payload.get("kind", "")) == "crew_mags_bench":
		if run_state == null:
			return []
		return _mags_bench_choices(payload, run_state, environment)
	if str(payload.get("kind", "")) == "grand_casino_showdown":
		return _grand_casino_showdown_choices(payload, run_state, environment)
	if str(payload.get("kind", "")) == "grand_casino_high_roller_cashout":
		return _grand_casino_high_roller_choices(payload, run_state, environment)
	var result: Array = []
	for choice_value in _copy_array(payload.get("choices", [])):
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice_data: Dictionary = (choice_value as Dictionary).duplicate(true)
		if _choice_conditions_allow(choice_data, run_state, environment):
			choice_data = _rumor_delivery_choice(choice_data, run_state, environment)
			choice_data = _traveler_context_choice(choice_data, run_state)
			choice_data = _reputation_context_choice(choice_data, environment)
			choice_data = CharacterChainModelScript.contextualize_choice(get_id(), choice_data, run_state)
			result.append(choice_data)
	return result


# Finds one event choice by id.
func choice(choice_id: String, run_state: RunState = null, environment: Dictionary = {}) -> Dictionary:
	for option in choices(run_state, environment):
		if option.get("id", "") == choice_id:
			return option.duplicate(true)
	return {}


# Projects Mags' authored catalog through the ordinary event consequence path.
func _mags_bench_choices(payload: Dictionary, run_state: RunState, environment: Dictionary) -> Array:
	var status := run_state.crew_mags_bench_status()
	if not bool(status.get("available", false)):
		return [{"id": "leave", "label": "Cases closed", "text": str(status.get("message", "Mags keeps the cases shut.")), "consequences": {}}]
	var result: Array = []
	for entry_value in _copy_array(payload.get("catalog", [])):
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var output_item := str(entry.get("output_item", "")).strip_edges()
		var required_items := _string_array(entry.get("requires_items", []))
		var cash_cost := maxi(0, int(entry.get("cash_cost", 0)))
		var minimum_rank := str(entry.get("min_member_rank", "associate")).strip_edges()
		var conditions := {
			"min_bankroll": cash_cost,
			"crew_member_rank_at_least": {"crew_mags": minimum_rank},
			"requires_items": required_items,
			"blocked_by_items": [output_item],
		}
		var choice_data := {
			"id": str(entry.get("id", output_item)),
			"label": str(entry.get("label", "Build gear")),
			"text": "%s\n%s" % [str(entry.get("text", "")), str(entry.get("risk_delta_note", ""))],
			"consequence_summary": "Bankroll -%d; parts become %s" % [cash_cost, output_item],
			"conditions": conditions,
			"consequences": {"bankroll_delta": -cash_cost, "inventory_remove": required_items, "inventory_add": [output_item]},
		}
		if _choice_conditions_allow(choice_data, run_state, environment):
			result.append(choice_data)
	result.append({"id": "leave", "label": "Leave the cases", "text": "Mags closes nothing you paid for.", "consequences": {}})
	return result


# Checks whether this event can fire in the current run context.
func can_trigger(run_state: RunState, environment: Dictionary, context: Dictionary = {}) -> bool:
	var min_suspicion := int(definition.get("min_suspicion", 0))
	var tier_min := int(definition.get("tier_min", 1))
	if int(run_state.suspicion.get("level", 0)) < min_suspicion:
		return false
	if int(environment.get("tier", 1)) < tier_min:
		return false
	var event_ids := _copy_array(environment.get("event_ids", []))
	if get_interaction_mode() != "triggered" and not event_ids.is_empty() and not event_ids.has(get_id()):
		return false
	var resolved := _copy_array(environment.get("resolved_event_ids", []))
	if resolved.has(get_id()):
		return false
	var scopes := _copy_array(definition.get("scopes", []))
	if not scopes.is_empty() and not scopes.has("any") and not scopes.has(str(environment.get("kind", ""))):
		return false
	if _event_requires_room_actor(context) and not _environment_allows_room_actor(environment):
		return false
	if not _conditions_allow(run_state, environment, context):
		return false
	return _trigger_allows(environment, context)


# Applies simple event consequences to the run.
func resolve(run_state: RunState, environment: Dictionary, choice_id: String = "") -> Dictionary:
	var payload := _copy_dict(definition.get("payload", {}))
	if str(payload.get("kind", "")) == "grand_casino_showdown":
		return _resolve_grand_casino_showdown(run_state, environment, payload, choice_id)
	if str(payload.get("kind", "")) == "grand_casino_high_roller_cashout":
		return _resolve_grand_casino_high_roller_cashout(run_state, environment, payload, choice_id)
	var selected_choice := choice(choice_id, run_state, environment)
	if not choice_id.is_empty() and selected_choice.is_empty():
		return _empty_result(choice_id, environment, "Event choice is not available.")
	var consequences := _consequences(selected_choice)
	consequences = _resolved_checked_consequences(run_state, environment, selected_choice, consequences)
	consequences = _resolved_lender_hook_consequences(run_state, consequences)
	var debt_settlement: Dictionary = {}
	if consequences.has("debt_settlement_discount_percent"):
		debt_settlement = run_state.discounted_debt_settlement_preview(int(consequences.get("debt_settlement_discount_percent", 0)))
		if not bool(debt_settlement.get("ok", false)):
			return _empty_result(choice_id, environment, str(debt_settlement.get("reason", "The marker cannot be settled.")))
		consequences["bankroll_delta"] = int(consequences.get("bankroll_delta", 0)) - int(debt_settlement.get("payment", 0))
		consequences["discounted_debt_settlement"] = debt_settlement.duplicate(true)
	var bankroll_delta := int(consequences.get("bankroll_delta", 0))
	var suspicion_delta := int(consequences.get("suspicion_delta", 0))
	var alcohol_intake := int(consequences.get("alcohol_intake", 0))
	var drunk_delta := int(consequences.get("drunk_delta", 0))
	var pending_drunk_absorption_delta := int(consequences.get("pending_drunk_absorption_delta", 0))
	var drunk_distortion_suppression_turns := int(consequences.get("drunk_distortion_suppression_turns", 0))
	var heat_cooldown_actions := int(consequences.get("heat_cooldown_actions", 0))
	var heat_cooldown_per_action := int(consequences.get("heat_cooldown_per_action", 0))
	var alcoholic_delta := int(consequences.get("alcoholic_delta", 0))
	var baseline_luck_delta := int(consequences.get("baseline_luck_delta", 0))
	var choice_key := str(selected_choice.get("id", choice_id))
	var message := _message(selected_choice)
	var story_entry := {
		"type": "event",
		"event_id": get_id(),
		"choice_id": choice_key,
		"environment_id": environment.get("id", ""),
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"alcohol_intake": alcohol_intake,
		"drunk_delta": drunk_delta,
		"pending_drunk_absorption_delta": pending_drunk_absorption_delta,
		"drunk_distortion_suppression_turns": drunk_distortion_suppression_turns,
		"heat_cooldown_actions": heat_cooldown_actions,
		"heat_cooldown_per_action": heat_cooldown_per_action,
		"alcoholic_delta": alcoholic_delta,
		"baseline_luck_delta": baseline_luck_delta,
	}
	var deltas := _consequence_deltas(consequences, story_entry, message)
	var result := GameModule.build_action_result({
		"ok": true,
		"type": "event",
		"source_id": get_id(),
		"action_id": choice_key,
		"action_kind": "event",
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"deltas": deltas,
		"environment_id": environment.get("id", ""),
		"message": message,
	})
	result["event_id"] = get_id()
	result["choice_id"] = choice_key
	result["interaction_mode"] = get_interaction_mode()
	var audio_cue := str(selected_choice.get("audio_cue", consequences.get("audio_cue", ""))).strip_edges()
	if not audio_cue.is_empty():
		result["audio_cue"] = audio_cue
		result["audio_cue_volume_db"] = float(selected_choice.get("audio_cue_volume_db", consequences.get("audio_cue_volume_db", -1.0)))
	var conclusion_animation := str(selected_choice.get("conclusion_animation", consequences.get("conclusion_animation", ""))).strip_edges()
	if conclusion_animation.is_empty() and bankroll_delta > 0:
		conclusion_animation = "bankroll_transfer"
	result["conclusion_animation"] = conclusion_animation
	if get_id() == "crew_favor_delivery" and choice_key == "run_package":
		var delivery_rollback := run_state.to_dict()
		var delivery_rollback_environment := run_state.current_environment.duplicate(true)
		var delivery_rollback_world_map := run_state.world_map.duplicate(true)
		var delivery_rollback_room_states := run_state.grand_casino_room_states.duplicate(true)
		var delivery_result := run_state.resolve_crew_favor_delivery_job(choice_key, {
			"success": consequences,
			"failure": _copy_dict(selected_choice.get("streets_failure", {})),
		})
		var sequence_schedule := {"ok": true, "inactive": true}
		if bool(delivery_result.get("ok", false)):
			sequence_schedule = _schedule_choice_world_sequence(run_state, selected_choice, delivery_result)
			if not bool(sequence_schedule.get("ok", false)):
				run_state.from_dict(delivery_rollback)
				run_state.current_environment = delivery_rollback_environment
				run_state.world_map = delivery_rollback_world_map
				run_state.grand_casino_room_states = delivery_rollback_room_states
				result["ok"] = false
				result["delivery_started"] = false
				result["world_sequence_scheduled"] = false
				result["errors"] = _copy_array(sequence_schedule.get("errors", []))
				result["message"] = str((result["errors"] as Array)[0]) if not (result["errors"] as Array).is_empty() else "The Crew route could not be staged safely."
				return result
		var start_message := str(delivery_result.get("message", "The route is marked. Keep your head down."))
		var start_deltas := _copy_dict(result.get("deltas", {}))
		start_deltas["bankroll_delta"] = 0
		start_deltas["suspicion_delta"] = 0
		start_deltas["flags_set"] = {}
		start_deltas["messages"] = [start_message]
		var start_story := _copy_array(start_deltas.get("story_log", []))
		if not start_story.is_empty() and typeof(start_story[0]) == TYPE_DICTIONARY:
			var entry := _copy_dict(start_story[0])
			entry["bankroll_delta"] = 0
			entry["suspicion_delta"] = 0
			start_story[0] = entry
		start_deltas["story_log"] = start_story
		result["bankroll_delta"] = 0
		result["suspicion_delta"] = 0
		result["deltas"] = start_deltas
		result["message"] = start_message
		result["conclusion_animation"] = ""
		result["delivery_started"] = bool(delivery_result.get("ok", false))
		result["delivery_snapshot"] = delivery_result.get("snapshot", {})
		result["world_sequence_scheduled"] = bool(sequence_schedule.get("ok", false)) and not bool(sequence_schedule.get("inactive", false))
		result["world_sequence_owner_token"] = str(sequence_schedule.get("owner_token", ""))
		apply_event_result(run_state, result)
		return result
	apply_event_result(run_state, result)
	if get_id() == "crew_favor_delivery":
		run_state.resolve_crew_favor_delivery_job(choice_key, {"success": consequences})
	return result


# Schedules an authored owner sequence using only the public result returned by
# the existing owning model. The package id is allowlisted in trusted code;
# authored event data cannot supply a path, model method, node, or owner token.
func _schedule_choice_world_sequence(run_state: RunState, selected_choice: Dictionary, owner_start_result: Dictionary) -> Dictionary:
	var package_id := str(selected_choice.get("world_sequence_package_id", "")).strip_edges()
	if package_id.is_empty():
		return {"ok": true, "inactive": true}
	var snapshot := _copy_dict(owner_start_result.get("snapshot", {}))
	var targets := _copy_array(snapshot.get("targets", []))
	var target := _copy_dict(targets[0]) if not targets.is_empty() else {}
	var node_id := str(target.get("node_id", "")).strip_edges()
	var public_instance_token := str(snapshot.get("job_id", "")).strip_edges()
	if public_instance_token.is_empty():
		public_instance_token = str(snapshot.get("run_id", "")).strip_edges()
	if node_id.is_empty() or public_instance_token.is_empty():
		return {"ok": false, "errors": ["World sequence owner start result lacks a public instance or target."]}
	return run_state.world_sequence_schedule_mount(
		package_id,
		public_instance_token,
		node_id
	)


# Applies a shared event result and records event-specific outcomes.
static func apply_event_result(run_state: RunState, result: Dictionary) -> void:
	if run_state == null or not bool(result.get("ok", false)):
		return
	var rollback_run := run_state.to_dict()
	var rollback_environment := run_state.current_environment.duplicate(true)
	var rollback_world_map := run_state.world_map.duplicate(true)
	var rollback_room_states := run_state.grand_casino_room_states.duplicate(true)
	var deltas: Dictionary = result.get("deltas", {})
	var debt_settlement := _copy_dict(deltas.get("discounted_debt_settlement", {}))
	if not debt_settlement.is_empty():
		var settlement_result := run_state.apply_discounted_debt_settlement(debt_settlement)
		if not bool(settlement_result.get("ok", false)):
			result["ok"] = false
			result["message"] = str(settlement_result.get("message", "The marker settlement failed."))
			return
	# Facts and storage services take effect on the side of the boundary where
	# the player chose them. In particular, a sweep advanced by this action must
	# see an item after Knuckles hid it, never confiscate it first.
	for hook in deltas.get("event_hooks", []):
		if typeof(hook) != TYPE_DICTIONARY:
			continue
		var pre_hook: Dictionary = hook
		var service_result: Dictionary = {}
		match str(pre_hook.get("type", "")):
			"hear_rumor":
				run_state.hear_rumor(str(pre_hook.get("rumor_id", "")))
			"crew_switch_reveal":
				service_result = run_state.crew_switch_reveal_node(str(pre_hook.get("node_id", "")))
			"crew_knuckles_stash":
				service_result = run_state.crew_knuckles_stash_inventory_entry(int(pre_hook.get("inventory_index", -1)), str(pre_hook.get("item_id", "")))
			"crew_knuckles_retrieve":
				service_result = run_state.crew_knuckles_retrieve_stash_entry(int(pre_hook.get("stash_index", -1)), str(pre_hook.get("item_id", "")))
			"crew_lucky_collection":
				service_result = run_state.numbers_begin_collection_route()
			"crew_job_accept":
				service_result = run_state.crew_job_accept_definition(str(pre_hook.get("definition_id", "")))
			"crew_practice_rig":
				service_result = run_state.crew_practice_rig_session(str(pre_hook.get("window", "")))
			"crew_stake_loss_choice":
				service_result = run_state.crew_resolve_stake_horse_loss(str(pre_hook.get("choice", "")))
			"crew_collection_choice":
				service_result = run_state.crew_resolve_collection(str(pre_hook.get("choice", "")))
			"crew_rook_ride":
				service_result = run_state.crew_rook_begin_ride()
			"crew_heist":
				service_result = run_state.crew_record_heist_event_result(result)
		if not service_result.is_empty():
			if not bool(service_result.get("ok", false)):
				result["ok"] = false
				result["message"] = "That Crew service is no longer available."
				return
			result["crew_service_result"] = service_result
	var advance_result := run_state.advance_environment_turns(1)
	if not bool(advance_result.get("ok", false)):
		run_state.from_dict(rollback_run)
		run_state.current_environment = rollback_environment
		run_state.world_map = rollback_world_map
		run_state.grand_casino_room_states = rollback_room_states
		var advance_errors: Array = advance_result.get("errors", []) if typeof(advance_result.get("errors", [])) == TYPE_ARRAY else []
		result["ok"] = false
		result["message"] = str(advance_errors[0]) if not advance_errors.is_empty() else "The event boundary could not advance safely."
		result["errors"] = advance_errors.duplicate(true)
		return
	GameModule.apply_result(run_state, result)
	# Recruitment aftermath is committed from this exact resolved event result,
	# before resolve_event removes the live placement. The host derives member,
	# path and outcome; consequence payloads never write Crew state directly.
	if get_id().begins_with("recruitment_") and get_id() not in ["recruitment_rook_signpost", "recruitment_rook_leads"]:
		result["crew_recruitment_result"] = run_state.crew_record_recruitment_event_result(result)
	for hook in deltas.get("event_hooks", []):
		if typeof(hook) != TYPE_DICTIONARY:
			continue
		var hook_data := _copy_dict(hook)
		match str(hook_data.get("type", "")):
			"resolve_event":
				run_state.resolve_event(str(hook_data.get("event_id", "")))
			"trigger_event":
				_apply_trigger_event_hook(run_state, result, hook_data)
			"hear_rumor":
				pass
			"crew_recruit", "crew_meet":
				pass
			"crew_rook_lead_closed":
				run_state.crew_close_rook_leads_event()
			"resolve_lender_favor":
				result["lender_favor_result"] = CharacterChainModelScript.resolve_lender_favor(
					run_state,
					str(hook_data.get("lender_id", "")),
					str(hook_data.get("resolution", ""))
				)
			"crew_switch_reveal", "crew_lucky_collection", "crew_knuckles_stash", "crew_knuckles_retrieve", "crew_job_accept", "crew_practice_rig", "crew_stake_loss_choice", "crew_collection_choice", "crew_rook_ride", "crew_heist":
				pass
	CharacterChainModelScript.apply_to_environment(run_state, run_state.current_environment)
	run_state.scenario_publish_event_result(result)
	# The event action already advanced the authoritative world boundary above.
	# Consume its correlated scenario fact on that same boundary so an accepted
	# choice cannot leave sequence aftermath pending until another player action.
	run_state.scenario_flush_facts()


# Returns a no-op event result for invalid choices.
func _empty_result(choice_id: String, environment: Dictionary, text: String) -> Dictionary:
	var result := GameModule.build_action_result({
		"ok": false,
		"type": "event",
		"source_id": get_id(),
		"action_id": choice_id,
		"action_kind": "event",
		"environment_id": environment.get("id", ""),
		"message": text,
	})
	result["event_id"] = get_id()
	result["choice_id"] = choice_id
	return result


# Converts event consequences into the shared result-delta shape.
func _consequence_deltas(consequences: Dictionary, story_entry: Dictionary, message: String) -> Dictionary:
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = int(consequences.get("bankroll_delta", 0))
	deltas["suspicion_delta"] = int(consequences.get("suspicion_delta", 0))
	deltas["alcohol_intake"] = int(consequences.get("alcohol_intake", 0))
	deltas["drunk_delta"] = int(consequences.get("drunk_delta", 0))
	deltas["pending_drunk_absorption_delta"] = int(consequences.get("pending_drunk_absorption_delta", 0))
	deltas["drunk_distortion_suppression_turns"] = int(consequences.get("drunk_distortion_suppression_turns", 0))
	deltas["heat_cooldown_actions"] = int(consequences.get("heat_cooldown_actions", 0))
	deltas["heat_cooldown_per_action"] = int(consequences.get("heat_cooldown_per_action", 0))
	deltas["alcoholic_delta"] = int(consequences.get("alcoholic_delta", 0))
	deltas["baseline_luck_delta"] = int(consequences.get("baseline_luck_delta", 0))
	if consequences.has("debt"):
		deltas["debt_changes"] = [_copy_dict(consequences.get("debt", {}))]
	else:
		deltas["debt_changes"] = _copy_array(consequences.get("debt_changes", []))
	deltas["inventory_add"] = _copy_array(consequences.get("inventory_add", []))
	deltas["inventory_remove"] = _copy_array(consequences.get("inventory_remove", []))
	var pending_bag_value: Variant = consequences.get("pending_bags", consequences.get("pending_bag", []))
	if typeof(pending_bag_value) == TYPE_DICTIONARY:
		deltas["pending_bags"] = [pending_bag_value]
	else:
		deltas["pending_bags"] = _copy_array(pending_bag_value)
	deltas["flags_set"] = _copy_dict(consequences.get("flags", consequences.get("flags_set", {})))
	var story_flags := _copy_dict(consequences.get("story_flags_set", {}))
	var single_story_flag := str(consequences.get("set_story_flag", "")).strip_edges()
	if not single_story_flag.is_empty():
		story_flags[single_story_flag] = true
	for story_flag_id in _single_or_array_strings(consequences.get("set_story_flags", [])):
		story_flags[str(story_flag_id)] = true
	deltas["story_flags_set"] = story_flags
	deltas["environment_layer_discovery"] = _copy_dict(consequences.get("environment_layer_discovery", {}))
	var travel_hooks := _copy_array(consequences.get("travel_hooks_add", []))
	for route_id in _single_or_array_strings(consequences.get("unlock_travel_route", consequences.get("unlock_travel_routes", []))):
		var route_target := _destination_archetype_for_route(str(route_id))
		if route_target.is_empty():
			route_target = str(route_id)
		if not travel_hooks.has(route_target):
			travel_hooks.append(route_target)
	deltas["travel_hooks_add"] = travel_hooks
	var travel_changes := _copy_dict(consequences.get("travel_changes", {}))
	if consequences.has("set_next_archetypes"):
		travel_changes["set_next_archetypes"] = _copy_array(consequences.get("set_next_archetypes", []))
	if consequences.has("add_next_archetypes"):
		travel_changes["add_next_archetypes"] = _copy_array(consequences.get("add_next_archetypes", []))
	deltas["travel_changes"] = travel_changes
	var story_entries := [story_entry]
	story_entries.append_array(_copy_array(consequences.get("story_log", [])))
	deltas["story_log"] = story_entries
	var messages := _copy_array(consequences.get("messages", []))
	if not message.is_empty():
		messages.push_front(message)
	deltas["messages"] = messages
	deltas["event_hooks"] = _copy_array(consequences.get("event_hooks", []))
	var recruit_member_id := str(consequences.get("crew_recruit_member", "")).strip_edges()
	if not recruit_member_id.is_empty():
		deltas["event_hooks"].append({"type": "crew_recruit", "member_id": recruit_member_id})
	var meet_member_id := str(consequences.get("crew_meet_member", "")).strip_edges()
	if not meet_member_id.is_empty():
		deltas["event_hooks"].append({"type": "crew_meet", "member_id": meet_member_id})
	deltas["demo_finale"] = _copy_dict(consequences.get("demo_finale", {}))
	deltas["discounted_debt_settlement"] = _copy_dict(consequences.get("discounted_debt_settlement", {}))
	if bool(consequences.get("resolve_event", false)):
		deltas["event_hooks"].append({
			"type": "resolve_event",
			"event_id": get_id(),
		})
	var trigger_event := _copy_dict(consequences.get("trigger_event", {}))
	if not trigger_event.is_empty():
		trigger_event["type"] = "trigger_event"
		trigger_event["source_event_id"] = get_id()
		trigger_event["source_choice_id"] = str(story_entry.get("choice_id", ""))
		var target_event_id := str(trigger_event.get("event_id", "")).strip_edges()
		var target_event := content_library.event(target_event_id) if content_library != null and not target_event_id.is_empty() else {}
		if not target_event.is_empty():
			trigger_event["entry_overrides"] = {
				"presentation": str(target_event.get("presentation", "modal")),
				"speaker": _copy_dict(target_event.get("speaker", {})),
			}
		deltas["event_hooks"].append(trigger_event)
	var hear_rumor_id := str(consequences.get("hear_rumor_id", "")).strip_edges()
	if not hear_rumor_id.is_empty():
		deltas["event_hooks"].append({"type": "hear_rumor", "rumor_id": hear_rumor_id})
	return deltas


func _destination_archetype_for_route(route_id: String) -> String:
	var clean_id := route_id.strip_edges()
	if clean_id.is_empty() or content_library == null:
		return ""
	var route := content_library.route(clean_id)
	if route.is_empty():
		return ""
	return str(route.get("destination_archetype", "")).strip_edges()


func _resolved_lender_hook_consequences(run_state: RunState, consequences: Dictionary) -> Dictionary:
	var lender_id := str(consequences.get("lender_hook", "")).strip_edges()
	if lender_id.is_empty() or run_state == null or content_library == null:
		return consequences
	var resolver := RunActionService.new()
	resolver.setup(content_library, run_state)
	var lender_result := resolver.hook_result("lender", lender_id)
	if lender_result.is_empty() or not bool(lender_result.get("ok", false)):
		return consequences
	var lender_deltas := _copy_dict(lender_result.get("deltas", {}))
	var resolved := consequences.duplicate(true)
	for key in ["bankroll_delta", "suspicion_delta", "alcohol_intake", "drunk_delta", "pending_drunk_absorption_delta", "drunk_distortion_suppression_turns", "heat_cooldown_actions", "heat_cooldown_per_action", "alcoholic_delta", "baseline_luck_delta"]:
		resolved[key] = int(resolved.get(key, 0)) + int(lender_deltas.get(key, 0))
	var debt_changes := _copy_array(resolved.get("debt_changes", []))
	debt_changes.append_array(_copy_array(lender_deltas.get("debt_changes", [])))
	resolved["debt_changes"] = debt_changes
	var flags := _copy_dict(resolved.get("flags_set", resolved.get("flags", {})))
	var lender_flags := _copy_dict(lender_deltas.get("flags_set", {}))
	for flag_key in lender_flags.keys():
		flags[str(flag_key)] = lender_flags[flag_key]
	resolved["flags_set"] = flags
	var story_log := _copy_array(resolved.get("story_log", []))
	story_log.append_array(_copy_array(lender_deltas.get("story_log", [])))
	resolved["story_log"] = story_log
	var messages := _copy_array(resolved.get("messages", []))
	messages.append_array(_copy_array(lender_deltas.get("messages", [])))
	resolved["messages"] = messages
	return resolved


# Applies a chain hook after the source event result has already mutated the run.
static func _apply_trigger_event_hook(run_state: RunState, source_result: Dictionary, hook_data: Dictionary) -> void:
	var target_id := str(hook_data.get("event_id", "")).strip_edges()
	if run_state == null or target_id.is_empty():
		return
	var chance := clampf(float(hook_data.get("chance", 1.0)), 0.0, 1.0)
	var chance_overrides: Dictionary = run_state.challenge_modifiers().get("tutorial_event_chain_chances", {}) if typeof(run_state.challenge_modifiers().get("tutorial_event_chain_chances", {})) == TYPE_DICTIONARY else {}
	# The guided family call is an authored tutorial beat, not a probability
	# lesson. Guarantee the pickup even if an older/custom tutorial save is
	# missing the challenge's chance override.
	if run_state.is_tutorial_run() and target_id == "family_loan":
		chance = 1.0
	elif chance_overrides.has(target_id):
		chance = clampf(float(chance_overrides.get(target_id, chance)), 0.0, 1.0)
	var threshold := clampi(int(round(chance * 10000.0)), 0, 10000)
	var rng := run_state.create_rng()
	var roll := rng.randi_range(0, 9999)
	run_state.save_rng(rng)
	var success := roll < threshold
	_apply_trigger_hook_flags(run_state, _copy_dict(hook_data.get("success_flags" if success else "failure_flags", {})))
	_apply_trigger_hook_story(run_state, _copy_array(hook_data.get("success_story_log" if success else "failure_story_log", [])))
	if success:
		var context := _copy_dict(hook_data.get("context", {}))
		context["trigger"] = "chain"
		context["type"] = "chain"
		context["source_event_id"] = str(hook_data.get("source_event_id", source_result.get("event_id", "")))
		context["source_choice_id"] = str(hook_data.get("source_choice_id", source_result.get("choice_id", "")))
		context["chance"] = chance
		context["roll"] = roll
		run_state.enqueue_triggered_event(target_id, "event_chain", context, _copy_dict(hook_data.get("entry_overrides", {})))
	else:
		var failure_audio_cue := str(hook_data.get("failure_audio_cue", "")).strip_edges()
		if not failure_audio_cue.is_empty():
			source_result["audio_cue"] = failure_audio_cue
			source_result["audio_cue_volume_db"] = float(hook_data.get("failure_audio_cue_volume_db", source_result.get("audio_cue_volume_db", -1.0)))
		var failure_message := str(hook_data.get("failure_message", "The follow-up does not land.")).strip_edges()
		if not failure_message.is_empty():
			source_result["event_chain_miss_message"] = failure_message
			source_result["post_resolution_message"] = failure_message
		run_state.log_story({
			"type": "event_chain_miss",
			"event_id": str(hook_data.get("source_event_id", source_result.get("event_id", ""))),
			"choice_id": str(hook_data.get("source_choice_id", source_result.get("choice_id", ""))),
			"target_event_id": target_id,
			"chance": chance,
			"roll": roll,
			"message": failure_message,
		})


static func _apply_trigger_hook_flags(run_state: RunState, flags: Dictionary) -> void:
	if run_state == null:
		return
	for flag_key in flags.keys():
		run_state.narrative_flags[str(flag_key)] = flags[flag_key]


static func _apply_trigger_hook_story(run_state: RunState, entries: Array) -> void:
	if run_state == null:
		return
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		run_state.log_story(entry_value as Dictionary)


# Checks the event trigger payload.
func _trigger_allows(environment: Dictionary, context: Dictionary = {}) -> bool:
	var trigger := _copy_dict(definition.get("trigger", {"type": "manual"}))
	var trigger_type := str(trigger.get("type", "manual"))
	match trigger_type:
		"manual":
			return true
		"timed":
			var turns := int(context.get("turns", environment.get("turns", 0)))
			return turns >= int(trigger.get("turns", 0))
		"travel":
			return str(context.get("trigger", context.get("type", ""))) == "travel"
		"random":
			if str(context.get("trigger", context.get("type", ""))) != "action":
				return false
			var turns := int(context.get("turns", environment.get("turns", 0)))
			return turns >= int(trigger.get("turns", trigger.get("min_turns", 0)))
		"heat_threshold":
			if str(context.get("trigger", context.get("type", ""))) != "heat_threshold":
				return false
			return int(context.get("threshold", 0)) == int(trigger.get("level", 0))
		"table_approach":
			if str(context.get("trigger", context.get("type", ""))) != "table_approach":
				return false
			var games := _string_array(trigger.get("games", []))
			var game_id := str(context.get("game_id", "")).strip_edges()
			if not games.is_empty() and not games.has(game_id):
				return false
			return int(context.get("hands_played", context.get("rounds_played", 0))) >= int(trigger.get("min_hands", 0))
		_:
			return false


func _event_requires_room_actor(context: Dictionary = {}) -> bool:
	if str(context.get("trigger", context.get("type", ""))) == "travel":
		return false
	var speaker := _copy_dict(definition.get("speaker", {}))
	if speaker.is_empty():
		return false
	if speaker.has("environment_actor") and not bool(speaker.get("environment_actor", true)):
		return false
	return true


func _environment_allows_room_actor(environment: Dictionary) -> bool:
	var kind := str(environment.get("kind", "")).strip_edges().to_lower()
	var archetype_id := str(environment.get("archetype_id", "")).strip_edges().to_lower()
	if ["home", "recovery"].has(kind):
		return false
	if ["beach"].has(archetype_id):
		return false
	return true


# Checks optional run-state/system conditions without mutating the run.
func _conditions_allow(run_state: RunState, environment: Dictionary, context: Dictionary = {}) -> bool:
	var conditions := _copy_dict(context.get("conditions_override", definition.get("conditions", {})))
	if conditions.is_empty():
		return true
	if run_state == null:
		return false
	if conditions.has("min_bankroll") and run_state.bankroll < int(conditions.get("min_bankroll", 0)):
		return false
	if conditions.has("max_bankroll") and run_state.bankroll > int(conditions.get("max_bankroll", 0)):
		return false
	if conditions.has("min_suspicion") and run_state.suspicion_level() < int(conditions.get("min_suspicion", 0)):
		return false
	if conditions.has("max_suspicion") and run_state.suspicion_level() > int(conditions.get("max_suspicion", 0)):
		return false
	if conditions.has("min_drunk") and run_state.drunk_level < int(conditions.get("min_drunk", 0)):
		return false
	if conditions.has("max_drunk") and run_state.drunk_level > int(conditions.get("max_drunk", 0)):
		return false
	if conditions.has("min_alcoholic") and run_state.alcoholic_level < int(conditions.get("min_alcoholic", 0)):
		return false
	if conditions.has("max_alcoholic") and run_state.alcoholic_level > int(conditions.get("max_alcoholic", 0)):
		return false
	if conditions.has("min_tier") and int(environment.get("tier", 1)) < int(conditions.get("min_tier", 1)):
		return false
	if conditions.has("max_tier") and int(environment.get("tier", 1)) > int(conditions.get("max_tier", 99)):
		return false
	if conditions.has("min_luck") and run_state.effective_luck() < int(conditions.get("min_luck", 0)):
		return false
	if conditions.has("max_luck") and run_state.effective_luck() > int(conditions.get("max_luck", 0)):
		return false
	var economy_states := _string_array(conditions.get("economy_states", []))
	if not economy_states.is_empty() and not economy_states.has(run_state.economy()):
		return false
	var requires_flags := _copy_dict(conditions.get("requires_flags", {}))
	for key in requires_flags.keys():
		if run_state.narrative_flags.get(str(key), null) != requires_flags[key]:
			return false
	var completed_tutorial_lessons := _copy_dict(run_state.narrative_flags.get("tutorial_lessons_completed", {}))
	for lesson_id in _string_array(conditions.get("requires_tutorial_lessons", [])):
		if not bool(completed_tutorial_lessons.get(lesson_id, false)):
			return false
	var requires_story_flags := _copy_dict(conditions.get("requires_story_flags", {}))
	for key in requires_story_flags.keys():
		if _story_flag_value(run_state, str(key)) != requires_story_flags[key]:
			return false
	for flag_id in _string_array(conditions.get("blocked_by_flags", [])):
		if bool(run_state.narrative_flags.get(flag_id, false)):
			return false
	for flag_id in _string_array(conditions.get("missing_flags", [])):
		if bool(run_state.narrative_flags.get(flag_id, false)):
			return false
	for flag_id in _string_array(conditions.get("blocked_by_story_flags", [])):
		if _story_flag_is_true(run_state, flag_id):
			return false
	for flag_id in _string_array(conditions.get("missing_story_flags", [])):
		if _story_flag_is_true(run_state, flag_id):
			return false
	var requires_any_flags := _string_array(conditions.get("requires_any_flags", []))
	if not requires_any_flags.is_empty():
		var found_any_flag := false
		for flag_id in requires_any_flags:
			if _story_flag_is_true(run_state, flag_id) or bool(run_state.narrative_flags.get(flag_id, false)):
				found_any_flag = true
				break
		if not found_any_flag:
			return false
	for item_id in _string_array(conditions.get("requires_items", [])):
		if not run_state.inventory.has(item_id):
			return false
	for item_id in _string_array(conditions.get("blocked_by_items", [])):
		if run_state.inventory.has(item_id):
			return false
	if conditions.has("min_bankroll") and run_state.bankroll < int(conditions.get("min_bankroll", 0)):
		return false
	var archetype_ids := _string_array(conditions.get("archetype_ids", []))
	if not archetype_ids.is_empty() and not archetype_ids.has(str(environment.get("archetype_id", ""))):
		return false
	for archetype_id in _string_array(conditions.get("blocked_archetype_ids", [])):
		if str(environment.get("archetype_id", "")) == archetype_id:
			return false
	var scenario_ids := _string_array(conditions.get("scenario_ids", []))
	var environment_scenario_id := str(environment.get("scenario_id", _copy_dict(environment.get("scenario_state", {})).get("id", "")))
	if not scenario_ids.is_empty() and not scenario_ids.has(environment_scenario_id):
		return false
	var environment_node_id := str(environment.get("world_node_id", environment.get("archetype_id", ""))).strip_edges()
	for flag_id in _string_array(conditions.get("story_flag_matches_node", [])):
		if str(_story_flag_value(run_state, flag_id)).strip_edges() != environment_node_id:
			return false
	for character_id in _string_array(conditions.get("requires_traveler_here", [])):
		if run_state.traveler_node(character_id) != environment_node_id:
			return false
	var pressure_band := _copy_dict(conditions.get("pressure_band", {}))
	if not pressure_band.is_empty():
		var heat_met := pressure_band.has("min_suspicion") and run_state.suspicion_level() >= int(pressure_band.get("min_suspicion", 0))
		var winnings_met := pressure_band.has("min_bankroll") and run_state.bankroll >= int(pressure_band.get("min_bankroll", 0))
		if not heat_met and not winnings_met:
			return false
	if bool(conditions.get("requires_available_rumor", false)) and _next_environment_rumor(environment).is_empty():
		return false
	for rumor_id in _string_array(conditions.get("requires_rumor_fact_ids", [])):
		if run_state.rumor_fact(rumor_id).is_empty():
			return false
	var layer_ids := _string_array(conditions.get("layer_ids", []))
	if not layer_ids.is_empty() and not layer_ids.has(str(environment.get("current_layer_id", ""))):
		return false
	for layer_id in _string_array(conditions.get("blocked_layer_ids", [])):
		if str(environment.get("current_layer_id", "")) == layer_id:
			return false
	var minimum_crew_rank := str(conditions.get("min_crew_rank", "")).strip_edges()
	if not minimum_crew_rank.is_empty():
		var ranks := CrewStateModel.RANK_IDS
		if not ranks.has(minimum_crew_rank) or ranks.find(str(run_state.crew_standing().get("rank", "stranger"))) < ranks.find(minimum_crew_rank):
			return false
	var member_rank_maximum := _copy_dict(conditions.get("crew_member_rank_at_most", {}))
	for member_id_value in member_rank_maximum.keys():
		var member_id := str(member_id_value)
		var maximum := str(member_rank_maximum.get(member_id_value, "stranger"))
		var ranks := CrewStateModel.RANK_IDS
		if not CrewStateModel.MEMBER_IDS.has(member_id) or not ranks.has(maximum) or ranks.find(run_state.crew_rank(member_id)) > ranks.find(maximum):
			return false
	var member_rank_minimum := _copy_dict(conditions.get("crew_member_rank_at_least", {}))
	for member_id_value in member_rank_minimum.keys():
		var member_id := str(member_id_value)
		var minimum := str(member_rank_minimum.get(member_id_value, "stranger"))
		var ranks := CrewStateModel.RANK_IDS
		if not CrewStateModel.MEMBER_IDS.has(member_id) or not ranks.has(minimum) or ranks.find(run_state.crew_rank(member_id)) < ranks.find(minimum):
			return false
	var requires_games := _string_array(conditions.get("requires_games", []))
	if not requires_games.is_empty():
		var environment_games := _string_array(environment.get("game_ids", []))
		for game_id in requires_games:
			if not environment_games.has(game_id):
				return false
	if conditions.has("requires_debt"):
		var requires_debt := bool(conditions.get("requires_debt", false))
		if requires_debt != (run_state.debt.size() > 0):
			return false
	if conditions.has("requires_collectible_debt"):
		var has_collectible_debt := not str(run_state.discounted_debt_settlement_preview(0).get("debt_id", "")).is_empty()
		if bool(conditions.get("requires_collectible_debt", false)) != has_collectible_debt:
			return false
	if conditions.has("requires_overdue_debt") and bool(conditions.get("requires_overdue_debt", false)) != _has_debt_with_status(run_state, ["overdue", "favor_due"]):
		return false
	var lender_ids := _string_array(conditions.get("requires_lender_debt", []))
	if not lender_ids.is_empty() and not _has_lender_debt(run_state, lender_ids):
		return false
	var travel_ids := _string_array(conditions.get("requires_travel_targets", []))
	if not travel_ids.is_empty():
		var available_travel := _event_travel_targets(run_state, environment)
		for travel_id in travel_ids:
			if not available_travel.has(travel_id):
				return false
	var context_flags := _copy_dict(conditions.get("requires_context", {}))
	for key in context_flags.keys():
		if context.get(str(key), null) != context_flags[key]:
			return false
	return true


func _rumor_delivery_choice(choice_data: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var conditions := _copy_dict(definition.get("conditions", {}))
	var required := bool(conditions.get("requires_available_rumor", false))
	var speaker := _copy_dict(definition.get("speaker", {}))
	var dave_delivery := str(speaker.get("character_id", "")) == "dave_bus_regular"
	if not required and not bool(definition.get("rumor_delivery", false)) and not dave_delivery:
		return choice_data
	var rumor := _next_environment_rumor(environment)
	if rumor.is_empty() or run_state == null:
		return choice_data
	var resolved := choice_data.duplicate(true)
	if required:
		resolved["scene_summary"] = str(rumor.get("line", ""))
		resolved["text"] = str(rumor.get("line", ""))
	else:
		resolved["text"] = "%s %s" % [str(resolved.get("text", "")).strip_edges(), str(rumor.get("line", "")).strip_edges()]
		resolved["text"] = str(resolved.get("text", "")).strip_edges()
	var consequences := _copy_dict(resolved.get("consequences", {}))
	consequences["hear_rumor_id"] = str(rumor.get("id", rumor.get("fact_id", "")))
	resolved["consequences"] = consequences
	return resolved


func _traveler_context_choice(choice_data: Dictionary, run_state: RunState) -> Dictionary:
	var speaker := _copy_dict(definition.get("speaker", {}))
	var character_id := str(speaker.get("character_id", "")).strip_edges()
	if run_state == null or character_id != "dave_bus_regular" or run_state.town_state == null:
		return choice_data
	var context_line := run_state.town_state.traveler_context_line(character_id)
	if context_line.is_empty():
		return choice_data
	var resolved := choice_data.duplicate(true)
	resolved["text"] = "%s %s" % [str(resolved.get("text", "")).strip_edges(), context_line]
	resolved["traveler_context_line"] = context_line
	return resolved


func _reputation_context_choice(choice_data: Dictionary, environment: Dictionary) -> Dictionary:
	if str(definition.get("id", "")) != "town_reputation_reaction":
		return choice_data
	var reputation := _copy_dict(environment.get("town_reputation", {}))
	var staff_line := str(reputation.get("staff_line", "")).strip_edges()
	if staff_line.is_empty():
		return choice_data
	var resolved := choice_data.duplicate(true)
	resolved["text"] = staff_line
	resolved["reputation_context_line"] = staff_line
	return resolved


func _next_environment_rumor(environment: Dictionary) -> Dictionary:
	for rumor_value in _copy_array(environment.get("town_rumors", [])):
		if typeof(rumor_value) == TYPE_DICTIONARY:
			return (rumor_value as Dictionary).duplicate(true)
	return {}


func _story_flag_value(run_state: RunState, flag_id: String) -> Variant:
	if run_state == null:
		return null
	if run_state.story_flags.has(flag_id):
		return run_state.story_flags.get(flag_id)
	return run_state.narrative_flags.get(flag_id, null)


func _story_flag_is_true(run_state: RunState, flag_id: String) -> bool:
	var value: Variant = _story_flag_value(run_state, flag_id)
	match typeof(value):
		TYPE_BOOL:
			return bool(value)
		TYPE_NIL:
			return false
		TYPE_INT:
			return int(value) != 0
		TYPE_FLOAT:
			return not is_zero_approx(float(value))
		TYPE_STRING:
			var text := str(value).strip_edges().to_lower()
			return text == "true" or text == "1" or text == "yes"
		_:
			return false


func _event_travel_targets(run_state: RunState, environment: Dictionary) -> Array:
	var result: Array = []
	for source in [
		environment.get("next_archetypes", []),
		environment.get("travel_hooks", []),
		run_state.unlocked_travel,
	]:
		for target_id in _string_array(source):
			if not result.has(target_id):
				result.append(target_id)
	return result


func _has_lender_debt(run_state: RunState, lender_ids: Array) -> bool:
	for debt_entry in run_state.debt:
		if typeof(debt_entry) != TYPE_DICTIONARY:
			continue
		var debt_data := debt_entry as Dictionary
		if lender_ids.has(str(debt_data.get("lender_id", ""))):
			return true
	return false


func _has_debt_with_status(run_state: RunState, statuses: Array) -> bool:
	for debt_entry in run_state.debt:
		if typeof(debt_entry) != TYPE_DICTIONARY:
			continue
		var debt_data := debt_entry as Dictionary
		if statuses.has(str(debt_data.get("status", "active"))):
			return true
	return false


func _choice_conditions_allow(choice_data: Dictionary, run_state: RunState, environment: Dictionary) -> bool:
	var choice_conditions := _copy_dict(choice_data.get("conditions", {}))
	if choice_conditions.is_empty():
		return true
	return _conditions_allow(run_state, environment, {"choice_conditions": true, "conditions_override": choice_conditions})


# Returns consequences from a selected choice or legacy top-level event data.
func _consequences(selected_choice: Dictionary) -> Dictionary:
	if not selected_choice.is_empty():
		return _copy_dict(selected_choice.get("consequences", {}))
	return _copy_dict(definition.get("consequences", {}))


func _resolved_checked_consequences(run_state: RunState, environment: Dictionary, selected_choice: Dictionary, consequences: Dictionary) -> Dictionary:
	var check := _copy_dict(consequences.get("check", {}))
	if check.is_empty() or run_state == null:
		return consequences
	var chance := clampi(int(check.get("chance_percent", 50)), 0, 100)
	var item_bonus := _copy_dict(check.get("item_success_bonus", {}))
	for item_id_value in item_bonus.keys():
		if run_state.inventory.has(str(item_id_value)):
			chance += int(item_bonus[item_id_value])
	chance = clampi(chance, int(check.get("min_chance", 0)), int(check.get("max_chance", 100)))
	var rng := run_state.create_rng()
	var roll := rng.randi_range(1, 100)
	run_state.save_rng(rng)
	var outcome_key := "success_consequences" if roll <= chance else "failure_consequences"
	var resolved := consequences.duplicate(true)
	resolved.erase("check")
	var outcome := _copy_dict(check.get(outcome_key, {}))
	for key in outcome.keys():
		resolved[key] = outcome[key]
	var story := _copy_array(resolved.get("story_log", []))
	story.append({
		"type": "event_check",
		"event_id": get_id(),
		"choice_id": str(selected_choice.get("id", "")),
		"environment_id": str(environment.get("id", "")),
		"chance_percent": chance,
		"roll": roll,
		"success": roll <= chance,
	})
	resolved["story_log"] = story
	return resolved


# Returns the player-facing event resolution text.
func _message(selected_choice: Dictionary) -> String:
	if not selected_choice.is_empty():
		return str(selected_choice.get("text", selected_choice.get("label", get_display_name())))
	var payload := _copy_dict(definition.get("payload", {}))
	return str(definition.get("text", payload.get("summary", "")))


func _grand_casino_showdown_choices(payload: Dictionary, run_state: RunState, environment: Dictionary) -> Array:
	var all_choices := _copy_array(payload.get("choices", []))
	if run_state == null:
		return all_choices
	var active := bool(run_state.narrative_flags.get("grand_casino_showdown_active", false))
	var pending := bool(run_state.narrative_flags.get("grand_casino_showdown_pending", false)) or bool(run_state.narrative_flags.get("the_house_calls_pending", false))
	if not active and pending:
		return _grand_casino_showdown_presented_choices(all_choices)
	if not active:
		return []
	var config := _grand_casino_showdown_config(payload)
	var step := str(run_state.narrative_flags.get("grand_casino_showdown_step", ""))
	match step:
		RunState.GRAND_CASINO_SHOWDOWN_STEP_WALK:
			return _grand_casino_showdown_walk_choices(payload, run_state)
		RunState.GRAND_CASINO_SHOWDOWN_STEP_PAT_DOWN:
			var pat_down_config := _copy_dict(payload.get("pat_down", {}))
			var continue_choice := _copy_dict(pat_down_config.get("continue_choice", {}))
			if continue_choice.is_empty():
				return []
			var pat_down := _copy_dict(run_state.narrative_flags.get("grand_casino_showdown_pat_down", {}))
			var tier := str(pat_down.get("tier", "clean"))
			var tier_message := str(_copy_dict(pat_down_config.get("tier_messages", {})).get(tier, "Rourke's search ends."))
			continue_choice["scene_summary"] = "Pat-down: %s. %s" % [tier.capitalize(), tier_message]
			continue_choice["presentation_consequence_summary"] = str(continue_choice.get("consequence_summary", ""))
			return [continue_choice]
		RunState.GRAND_CASINO_SHOWDOWN_STEP_INTERROGATION:
			var choices := run_state.grand_casino_showdown_interrogation_choices(config)
			var scene_summary := _grand_casino_interrogation_scene_summary(run_state.grand_casino_showdown_interrogation_status(config))
			for index in range(choices.size()):
				if typeof(choices[index]) == TYPE_DICTIONARY:
					var choice_data := (choices[index] as Dictionary).duplicate(true)
					choice_data["scene_summary"] = scene_summary
					choice_data["presentation_consequence_summary"] = str(choice_data.get("consequence_summary", ""))
					choices[index] = choice_data
			return choices
	return []


func _resolve_grand_casino_showdown(run_state: RunState, environment: Dictionary, payload: Dictionary, choice_id: String) -> Dictionary:
	var selected_choice := choice(choice_id, run_state, environment)
	if selected_choice.is_empty():
		return _empty_result(choice_id, environment, "Showdown choice is not available.")
	var config := _grand_casino_showdown_config(payload)
	var choice_key := str(selected_choice.get("id", choice_id))
	var outcome := {}
	if choice_key == "enter_back_room":
		outcome = run_state.start_grand_casino_showdown(config)
	elif str(run_state.narrative_flags.get("grand_casino_showdown_step", "")) == RunState.GRAND_CASINO_SHOWDOWN_STEP_WALK:
		outcome = run_state.resolve_grand_casino_showdown_walk(str(selected_choice.get("showdown_method", "")), str(selected_choice.get("item_id", "")), config)
	elif str(run_state.narrative_flags.get("grand_casino_showdown_step", "")) == RunState.GRAND_CASINO_SHOWDOWN_STEP_PAT_DOWN:
		outcome = run_state.continue_grand_casino_showdown_pat_down(config)
	elif str(run_state.narrative_flags.get("grand_casino_showdown_step", "")) == RunState.GRAND_CASINO_SHOWDOWN_STEP_INTERROGATION:
		outcome = run_state.resolve_grand_casino_showdown_interrogation(choice_key, config)
	else:
		outcome = {"ok": false, "message": "The showdown cannot advance from here."}
	var ok := bool(outcome.get("ok", false))
	var message := str(outcome.get("message", selected_choice.get("text", get_display_name())))
	var deltas := GameModule.empty_result_deltas()
	deltas["messages"] = [] if message.is_empty() else [message]
	deltas["ended"] = run_state.is_terminal()
	var result := GameModule.build_action_result({
		"ok": ok,
		"type": "event",
		"source_id": get_id(),
		"action_id": choice_key,
		"action_kind": "event",
		"deltas": deltas,
		"environment_id": environment.get("id", ""),
		"message": message,
		"ended": run_state.is_terminal(),
	})
	result["event_id"] = get_id()
	result["choice_id"] = choice_key
	result["showdown"] = _copy_dict(outcome.get("status", run_state.grand_casino_showdown_status(config)))
	result["showdown_check"] = _copy_dict(outcome.get("check", {}))
	result["grand_casino_duel_terms"] = _copy_dict(run_state.narrative_flags.get("grand_casino_duel_terms", {}))
	result["duel_ready"] = bool(outcome.get("duel_ready", false))
	result["grand_casino_duel"] = _copy_dict(outcome.get("duel", {}))
	if outcome.has("success"):
		result["success"] = bool(outcome.get("success", false))
	if run_state.is_terminal():
		result["state"] = GameModule.RESULT_ENDED
	return result


func _grand_casino_showdown_config(payload: Dictionary) -> Dictionary:
	var config := _copy_dict(payload.get("showdown_tuning", {}))
	for key in ["walk", "pat_down", "interrogation", "duel_terms"]:
		config[key] = _copy_dict(payload.get(key, {}))
	config["success_message"] = str(payload.get("success_message", ""))
	config["failure_message"] = str(payload.get("failure_message", ""))
	return config


func _grand_casino_showdown_presented_choices(choices: Array) -> Array:
	var result: Array = []
	for choice_value in choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice_data := (choice_value as Dictionary).duplicate(true)
		choice_data["presentation_consequence_summary"] = str(choice_data.get("consequence_summary", ""))
		result.append(choice_data)
	return result


func _grand_casino_showdown_walk_choices(payload: Dictionary, run_state: RunState) -> Array:
	var walk_config := _copy_dict(payload.get("walk", {}))
	var status := run_state.grand_casino_showdown_walk_status()
	if bool(status.get("ditch_used", false)):
		return []
	var inventory_items := _copy_array(status.get("inventory", []))
	var result: Array = []
	for option_value in _copy_array(walk_config.get("choices", [])):
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = option_value
		var method := str(option.get("method", ""))
		if method == "keep":
			var keep_choice := option.duplicate(true)
			keep_choice["showdown_method"] = method
			keep_choice["item_id"] = ""
			keep_choice["scene_summary"] = "The walk: change one pocket before Rourke's door."
			keep_choice["presentation_consequence_summary"] = str(keep_choice.get("consequence_summary", ""))
			result.append(keep_choice)
			continue
		if bool(option.get("requires_crew", false)) and not bool(status.get("crew_available", false)):
			continue
		for item_value in inventory_items:
			var item_id := str(item_value)
			if item_id.is_empty():
				continue
			var item_label := _grand_casino_showdown_item_label(item_id)
			var choice_data := option.duplicate(true)
			choice_data["id"] = "%s__%s" % [str(option.get("id", method)), item_id]
			choice_data["label"] = str(option.get("label", item_label)).replace("{item}", item_label)
			choice_data["text"] = str(option.get("text", "")).replace("{item}", item_label)
			choice_data["showdown_method"] = method
			choice_data["item_id"] = item_id
			choice_data["scene_summary"] = "The walk: change one pocket before Rourke's door."
			choice_data["presentation_consequence_summary"] = str(choice_data.get("consequence_summary", ""))
			result.append(choice_data)
	return result


func _grand_casino_showdown_item_label(item_id: String) -> String:
	if content_library != null:
		var definition := content_library.item(item_id)
		if not definition.is_empty():
			return str(definition.get("display_name", item_id.replace("_", " ").capitalize()))
	return item_id.replace("_", " ").capitalize()


func _grand_casino_interrogation_scene_summary(status: Dictionary) -> String:
	var stakes := _copy_dict(status.get("stakes", {}))
	return "Beat %d/%d. Rourke: %s Stakes: heat %s; proof %s; clean %s; items %s; drink/debt %s; history %s." % [
		int(status.get("beat_number", 0)),
		int(status.get("beat_count", 0)),
		str(status.get("evidence_text", "Rourke opens the ledger.")),
		_signed_value(-int(stakes.get("heat_penalty", 0))),
		_signed_value(-int(stakes.get("evidence_penalty", 0))),
		_signed_value(int(stakes.get("clean_play_modifier", 0))),
		_signed_value(int(stakes.get("item_modifier", 0))),
		_signed_value(-int(stakes.get("alcohol_debt_penalty", 0))),
		_signed_value(int(stakes.get("prior_boss_event_modifier", 0))),
	]


func _signed_value(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


func _grand_casino_high_roller_choices(payload: Dictionary, run_state: RunState, _environment: Dictionary) -> Array:
	var all_choices := _copy_array(payload.get("choices", []))
	if run_state == null:
		return all_choices
	if not bool(run_state.narrative_flags.get("high_roller_cashout_pending", false)):
		return []
	if bool(run_state.narrative_flags.get("grand_casino_showdown_pending", false)) or bool(run_state.narrative_flags.get("grand_casino_showdown_active", false)):
		return []
	var result: Array = []
	for choice_value in all_choices:
		if typeof(choice_value) != TYPE_DICTIONARY:
			continue
		var choice_data := (choice_value as Dictionary).duplicate(true)
		if str(choice_data.get("id", "")) == RunState.GRAND_CASINO_HIGH_ROLLER_EVENT_ID:
			result.append(choice_data)
	return result


func _resolve_grand_casino_high_roller_cashout(run_state: RunState, environment: Dictionary, payload: Dictionary, choice_id: String) -> Dictionary:
	var selected_choice := choice(choice_id, run_state, environment)
	if selected_choice.is_empty():
		return _empty_result(choice_id, environment, "The Players Card desk is not available.")
	var config := {
		"success_message": str(payload.get("success_message", "")),
	}
	var outcome := run_state.complete_grand_casino_high_roller_cashout(config)
	var ok := bool(outcome.get("ok", false))
	var message := str(outcome.get("message", selected_choice.get("text", get_display_name())))
	var deltas := GameModule.empty_result_deltas()
	deltas["messages"] = [] if message.is_empty() else [message]
	deltas["ended"] = run_state.is_terminal()
	var choice_key := str(selected_choice.get("id", choice_id))
	var result := GameModule.build_action_result({
		"ok": ok,
		"type": "event",
		"source_id": get_id(),
		"action_id": choice_key,
		"action_kind": "event",
		"deltas": deltas,
		"environment_id": environment.get("id", ""),
		"message": message,
		"ended": run_state.is_terminal(),
	})
	result["event_id"] = get_id()
	result["choice_id"] = choice_key
	result["high_roller_cashout"] = _copy_dict(outcome.get("status", {}))
	if run_state.is_terminal():
		result["state"] = GameModule.RESULT_ENDED
	return result


# Safely duplicates array content.
static func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


# Normalizes a variant array into string ids.
static func _string_array(value: Variant) -> Array:
	var result: Array = []
	for entry in _copy_array(value):
		var id := str(entry)
		if not id.is_empty():
			result.append(id)
	return result


static func _single_or_array_strings(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return _string_array(value)
	var text := str(value).strip_edges()
	return [] if text.is_empty() else [text]


# Safely duplicates dictionary content.
static func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
