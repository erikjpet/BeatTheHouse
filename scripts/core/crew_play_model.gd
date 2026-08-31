class_name CrewPlayModel
extends RefCounted

# Data and deterministic state rules for explicit, limited-use coordinated plays.
# Presence and rank remain owned by RunState/CrewRecruitmentModel.

const CONFIG_PATH := "res://data/crew/plays.json"
const SCHEMA_VERSION := 1
const STATE_SCHEMA_VERSION := 2
const LEGACY_STATE_SCHEMA_VERSION := 1
const TOMBSTONE_LIMIT := 16
const ACTION_PREFIX := "crew_play:"
const PLAY_IDS := ["spotter", "distraction", "big_player", "chip_dump", "table_flood"]
const RANK_IDS := ["stranger", "marker", "associate", "made", "inner_circle"]

static var _config_cache: Dictionary = {}


static func config() -> Dictionary:
	return _config_ref().duplicate(true)


static func _config_ref() -> Dictionary:
	if _config_cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH)) if FileAccess.file_exists(CONFIG_PATH) else []
		if typeof(parsed) == TYPE_ARRAY and (parsed as Array).size() == 1 and typeof((parsed as Array)[0]) == TYPE_DICTIONARY:
			_config_cache = ((parsed as Array)[0] as Dictionary).duplicate(true)
	return _config_cache


static func definition(play_id: String) -> Dictionary:
	return _definition_ref(play_id).duplicate(true)


static func _definition_ref(play_id: String) -> Dictionary:
	for value in _array(_config_ref().get("plays", [])):
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == play_id:
			return value as Dictionary
	return {}


static func default_state() -> Dictionary:
	return {
		"schema_version": STATE_SCHEMA_VERSION,
		"uses": {},
		"member_cooldowns": {},
		"active": [],
		"sequence": 0,
		"last_beat": {},
		"distraction_liability": {},
		"tombstones": [],
	}


static func normalize_state(value: Variant) -> Dictionary:
	var source: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var result := default_state()
	var uses: Dictionary = source.get("uses", {}) if typeof(source.get("uses", {})) == TYPE_DICTIONARY else {}
	for play_id in PLAY_IDS:
		var count := maxi(0, int(uses.get(play_id, 0)))
		if count > 0:
			result["uses"][play_id] = count
	var cooldowns: Dictionary = source.get("member_cooldowns", {}) if typeof(source.get("member_cooldowns", {})) == TYPE_DICTIONARY else {}
	for member_value in cooldowns.keys():
		var member_id := str(member_value).strip_edges()
		var until := maxi(0, int(cooldowns.get(member_value, 0)))
		if not member_id.is_empty() and until > 0:
			result["member_cooldowns"][member_id] = until
	for active_value in _array(source.get("active", [])):
		if typeof(active_value) != TYPE_DICTIONARY:
			continue
		var active := _normalize_active(active_value as Dictionary)
		if not active.is_empty():
			result["active"].append(active)
	result["sequence"] = maxi(0, int(source.get("sequence", 0)))
	if typeof(source.get("last_beat", {})) == TYPE_DICTIONARY:
		result["last_beat"] = (source.get("last_beat", {}) as Dictionary).duplicate(true)
	if typeof(source.get("distraction_liability", {})) == TYPE_DICTIONARY:
		var liability := source.get("distraction_liability", {}) as Dictionary
		if not str(liability.get("member_id", "")).is_empty() and not bool(liability.get("recorded", false)):
			result["distraction_liability"] = liability.duplicate(true)
	for tombstone_value in _array(source.get("tombstones", [])):
		var tombstone := _normalize_tombstone(_dict(tombstone_value))
		if not tombstone.is_empty():
			result["tombstones"].append(tombstone)
	while (result["tombstones"] as Array).size() > TOMBSTONE_LIMIT:
		(result["tombstones"] as Array).pop_front()
	return result


static func restore_state(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).is_empty():
		return default_state()
	var source: Dictionary = value
	var state_keys := ["active", "distraction_liability", "last_beat", "member_cooldowns", "schema_version", "sequence", "tombstones", "uses"]
	if int(source.get("schema_version", 0)) not in [LEGACY_STATE_SCHEMA_VERSION, STATE_SCHEMA_VERSION] or not _exact_keys(source, state_keys) \
			or typeof(source.get("uses")) != TYPE_DICTIONARY or typeof(source.get("member_cooldowns")) != TYPE_DICTIONARY \
			or typeof(source.get("active")) != TYPE_ARRAY or typeof(source.get("last_beat")) != TYPE_DICTIONARY \
			or typeof(source.get("distraction_liability")) != TYPE_DICTIONARY or typeof(source.get("tombstones")) != TYPE_ARRAY \
			or (source.get("tombstones") as Array).size() > TOMBSTONE_LIMIT:
		return default_state()
	for play_key in (source.get("uses") as Dictionary).keys():
		if str(play_key) not in PLAY_IDS or int((source.get("uses") as Dictionary).get(play_key, -1)) < 0: return default_state()
	for active_value in source.get("active") as Array:
		if typeof(active_value) != TYPE_DICTIONARY or not _exact_keys(active_value as Dictionary, ["activated_action", "effect", "environment_key", "expires_at_action", "game_id", "member_ids", "play_id", "sequence"]) \
				or _normalize_active(active_value as Dictionary).is_empty(): return default_state()
	for tombstone_value in source.get("tombstones") as Array:
		if typeof(tombstone_value) != TYPE_DICTIONARY or not _exact_keys(tombstone_value as Dictionary, ["ended_action", "environment_key", "game_id", "member_ids", "play_id", "reason", "sequence"]) \
				or _normalize_tombstone(tombstone_value as Dictionary).is_empty(): return default_state()
	var last_beat: Dictionary = source.get("last_beat")
	if not last_beat.is_empty() and not _exact_keys(last_beat, ["action_index", "member_ids", "message", "play_id"]): return default_state()
	var liability: Dictionary = source.get("distraction_liability")
	if not liability.is_empty() and not _exact_keys(liability, ["member_id", "recorded", "source_ref", "until_action"]): return default_state()
	return normalize_state(source)


static func available_actions(run_state: RunState, environment: Dictionary, game_id: String) -> Array:
	if run_state == null or environment.is_empty() or game_id.is_empty():
		return []
	var result: Array = []
	for value in _array(_config_ref().get("plays", [])):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var play: Dictionary = value
		var availability := availability(run_state, environment, game_id, str(play.get("id", "")))
		if not bool(availability.get("available", false)):
			continue
		var play_id := str(play.get("id", ""))
		result.append({
			"id": ACTION_PREFIX + play_id,
			"label": "PLAY · %s" % str(play.get("display_name", play_id.capitalize())),
			"crew_play": true,
			"crew_play_id": play_id,
			"summary": str(availability.get("cost_summary", "")),
			"cost_summary": str(availability.get("cost_summary", "")),
			"member_ids": _string_array(availability.get("member_ids", [])),
			"uses_remaining": int(availability.get("uses_remaining", 0)),
		})
	return result


static func availability(run_state: RunState, environment: Dictionary, game_id: String, play_id: String) -> Dictionary:
	var play := _definition_ref(play_id)
	if run_state == null or play.is_empty() or not _string_array(play.get("game_ids", [])).has(game_id):
		return {"available": false, "reason": "wrong_context"}
	var state := normalize_state(run_state.crew_play_state)
	var current_action := run_state.crew_action_index()
	var used := maxi(0, int((state.get("uses", {}) as Dictionary).get(play_id, 0)))
	var cap := maxi(0, int(play.get("uses_per_run", 0)))
	var free_heist_use := run_state.crew_heist_free_play_available()
	if used >= cap and not free_heist_use:
		return {"available": false, "reason": "uses_spent"}
	var required_active := str(play.get("requires_active_play", "")).strip_edges()
	if not required_active.is_empty() and not is_active(state, required_active, current_action, environment):
		return {"available": false, "reason": "pair_required"}
	if not _concurrency_allows(state, play_id, current_action, environment):
		return {"available": false, "reason": "active_window_cap"}
	var members := _eligible_members(run_state, environment, play, state, current_action)
	var member_count := maxi(1, int(play.get("member_count", 1)))
	if members.size() < member_count:
		return {"available": false, "reason": "member_presence_rank_or_cooldown"}
	members = members.slice(0, member_count)
	var cash_cost := 0 if free_heist_use else maxi(0, int(play.get("cash_cost", 0)))
	var effect: Dictionary = play.get("effect", {}) if typeof(play.get("effect", {})) == TYPE_DICTIONARY else {}
	if play_id == "chip_dump":
		cash_cost += maxi(0, int(effect.get("transfer_amount", 0))) + maxi(0, int(effect.get("transfer_fee", 0)))
	if run_state.bankroll < cash_cost:
		return {"available": false, "reason": "cash_cost"}
	var summary := "The room covers this one" if free_heist_use else "%d/%d uses" % [cap - used, cap]
	if play_id == "chip_dump":
		summary += " · $%d transfer + $%d fee" % [int(effect.get("transfer_amount", 0)), int(effect.get("transfer_fee", 0))]
	elif cash_cost > 0:
		summary += " · $%d cut" % cash_cost
	var window := maxi(0, int(play.get("window_boundaries", 0)))
	if window > 0:
		summary += " · %d actions" % window
	var risk := maxi(0, int(play.get("detection_chance_percent", 0)))
	if risk > 0:
		summary += " · %d%% heat risk" % risk
	return {
		"available": true,
		"play_id": play_id,
		"member_ids": members,
		"uses_remaining": cap - used,
		"cash_cost": cash_cost,
		"free_heist_use": free_heist_use,
		"cost_summary": summary,
	}


# Player-safe description of the table-presence sequence a host adapter may
# mount. This model has no sealed adapter receipt or live actor/scene inventory,
# so the projection is deliberately non-authoritative and never mutates state.
static func table_presence_proposal(run_state: RunState, environment: Dictionary, game_id: String, play_id: String) -> Dictionary:
	var base := {
		"authoritative": false,
		"proposal_only": true,
		"can_mutate": false,
		"authority_gap": "adapter_host_root_unavailable",
		"play_id": play_id,
		"game_id": game_id,
		"environment_key": environment_key(environment),
	}
	if run_state == null or environment.is_empty() or JSON.stringify(environment) != JSON.stringify(run_state.current_environment) \
			or str(environment.get("active_game_id", "")) != game_id:
		return base.merged({"eligible": false, "reason": "untrusted_table_context"}, true)
	var status := availability(run_state, environment, game_id, play_id)
	if not bool(status.get("available", false)):
		return base.merged({"eligible": false, "reason": str(status.get("reason", "unavailable"))}, true)
	var play := _definition_ref(play_id)
	var members := _string_array(status.get("member_ids", []))
	var action_index := run_state.crew_action_index()
	var state := normalize_state(run_state.crew_play_state)
	var used := maxi(0, int((state.get("uses", {}) as Dictionary).get(play_id, 0)))
	var uses_per_run := maxi(0, int(play.get("uses_per_run", 0)))
	var window_boundaries := maxi(0, int(play.get("window_boundaries", 0)))
	var cooldown_boundaries := maxi(0, int(play.get("cooldown_boundaries", 0)))
	var actor_ops: Array = []
	for member_id in members:
		actor_ops.append({"phase_id": "arrive", "verb": "behavior", "actor_id": member_id, "state": "arriving"})
		actor_ops.append({"phase_id": "work", "verb": "behavior", "actor_id": member_id, "state": "working"})
		actor_ops.append({"phase_id": "detected", "verb": "behavior", "actor_id": member_id, "state": "detected"})
		actor_ops.append({"phase_id": "clean", "verb": "behavior", "actor_id": member_id, "state": "working"})
		actor_ops.append({"phase_id": "leave", "verb": "behavior", "actor_id": member_id, "state": "leaving"})
	var funding: Dictionary = {}
	if play_id == "chip_dump":
		var effect := _dict(play.get("effect", {}))
		funding = {
			"model": "A_player_funded",
			"direction": str(effect.get("direction", "")),
			"cash_debit": maxi(0, int(effect.get("transfer_amount", 0))) + maxi(0, int(effect.get("transfer_fee", 0))),
			"chip_credit": maxi(0, int(effect.get("transfer_amount", 0))),
			"fee_sink": maxi(0, int(effect.get("transfer_fee", 0))),
		}
	return base.merged({
		"eligible": true,
		"reason": "proposal_ready_host_authorization_required",
		"member_ids": members,
		"lifecycle_phases": ["arrive", "work", "detected_or_clean", "leave"],
		"actor_ops": actor_ops,
		"transition_ops": [
			{"from": "arrive", "to": "work", "cause": "host_arrival_complete"},
			{"from": "work", "to": "detected", "cause": "host_authenticated_detected"},
			{"from": "work", "to": "clean", "cause": "host_authenticated_clean"},
			{"from": "detected", "to": "leave", "cause": "host_aftermath_complete"},
			{"from": "clean", "to": "leave", "cause": "host_window_complete"},
		],
		"window_state": {
			"boundaries": window_boundaries,
			"active": is_active(state, play_id, action_index, environment),
			"would_expire_at_action": action_index + window_boundaries + 1 if window_boundaries > 0 else action_index,
		},
		"cooldown_state": {"boundaries": cooldown_boundaries, "would_end_at_action": action_index + cooldown_boundaries + 1},
		"use_state": {"used": used, "cap": uses_per_run, "remaining": maxi(0, uses_per_run - used)},
		"detection": {
			"chance_percent": clampi(int(play.get("detection_chance_percent", 0)), 0, 100),
			"heat": maxi(0, int(play.get("detection_heat", 0))),
			"outcome_authority": "host_authenticated_only",
			"branches": ["detected", "clean"],
		},
		"funding": funding,
		"effect": _dict(play.get("effect", {})),
		"voice_lines": _dict(play.get("voice_lines", {})),
	}, true)


static func activate(run_state: RunState, environment: Dictionary, game_id: String, play_id: String, host_capability: Variant = null) -> Dictionary:
	if run_state == null or not run_state.crew_play_host_authorizes(host_capability, environment, game_id):
		return _result(false, play_id, environment, "That crew play is not bound to the live table host.")
	var status := availability(run_state, environment, game_id, play_id)
	if not bool(status.get("available", false)):
		return _result(false, play_id, environment, "That crew play is not available now.")
	var play := _definition_ref(play_id)
	var state := normalize_state(run_state.crew_play_state)
	var members := _string_array(status.get("member_ids", []))
	var current_action := run_state.crew_action_index()
	var uses: Dictionary = state.get("uses", {})
	var free_heist_use := bool(status.get("free_heist_use", false)) and run_state.crew_heist_consume_free_play()
	if not free_heist_use:
		uses[play_id] = int(uses.get(play_id, 0)) + 1
	state["uses"] = uses
	state["sequence"] = int(state.get("sequence", 0)) + 1
	var cooldowns: Dictionary = state.get("member_cooldowns", {})
	var cooldown_boundaries := maxi(0, int(play.get("cooldown_boundaries", 0)))
	for member_id in members:
		cooldowns[member_id] = current_action + cooldown_boundaries + 1
	state["member_cooldowns"] = cooldowns
	var cash_cost := 0 if free_heist_use else maxi(0, int(play.get("cash_cost", 0)))
	var effect: Dictionary = play.get("effect", {}) if typeof(play.get("effect", {})) == TYPE_DICTIONARY else {}
	var beat := _voice_line(play, members)
	var bankroll_delta := -cash_cost
	var chips_delta := 0
	var suspicion_delta := 0
	var detected := false
	if play_id == "distraction":
		var dump := maxi(0, int(effect.get("suspicion_dump", 0)))
		if dump > 0:
			suspicion_delta = run_state.add_suspicion("crew_play_distraction", -dump, "crew_play", true, _environment_context(environment))
		state["distraction_liability"] = {
			"member_id": members[0],
			"until_action": current_action + cooldown_boundaries + 1,
			"source_ref": "crew_play:%d" % int(state.get("sequence", 0)),
			"recorded": false,
		}
	elif play_id == "chip_dump":
		var transfer := maxi(0, int(effect.get("transfer_amount", 0)))
		var fee := maxi(0, int(effect.get("transfer_fee", 0)))
		bankroll_delta = -(transfer + fee)
		chips_delta = transfer
		detected = _activation_detected(run_state, play, int(state.get("sequence", 0)))
		if detected:
			suspicion_delta = run_state.add_suspicion("crew_play_chip_dump_detected", int(play.get("detection_heat", 0)), "crew_play", true, _environment_context(environment).merged({"action_kind": "cheat"}, true))
	var window := maxi(0, int(play.get("window_boundaries", 0)))
	if window > 0:
		var active: Array = state.get("active", [])
		active.append({
			"play_id": play_id,
			"member_ids": members.duplicate(true),
			"environment_key": environment_key(environment),
			"game_id": game_id,
			"activated_action": current_action,
			"expires_at_action": current_action + window + 1,
			"sequence": int(state.get("sequence", 0)),
			"effect": effect.duplicate(true),
		})
		state["active"] = active
	if play_id == "big_player":
		_apply_big_player_warm_state(run_state, environment, effect)
	if bankroll_delta != 0:
		run_state.change_bankroll(bankroll_delta, true)
	if chips_delta != 0:
		run_state.grand_casino_chips = maxi(0, run_state.grand_casino_chips + chips_delta)
	state["last_beat"] = {
		"play_id": play_id,
		"member_ids": members,
		"message": beat,
		"action_index": current_action,
	}
	run_state.crew_play_state = normalize_state(state)
	var message := beat
	if play_id == "distraction":
		message += " Heat %d." % suspicion_delta
	elif play_id == "chip_dump":
		message += " $%d becomes %d chips; the fee is $%d.%s" % [maxi(0, int(effect.get("transfer_amount", 0))), chips_delta, maxi(0, int(effect.get("transfer_fee", 0))), " The floor marks the pass." if detected else ""]
	elif window > 0:
		message += " %s is live for %d actions." % [str(play.get("display_name", play_id.capitalize())), window]
	run_state.log_story({
		"type": "crew_play",
		"play_id": play_id,
		"member_ids": members,
		"bankroll_delta": bankroll_delta,
		"chips_delta": chips_delta,
		"suspicion_delta": suspicion_delta,
		"detected": detected,
		"message": message,
	})
	return _result(true, play_id, environment, message).merged({
		"action_kind": "crew_play",
		"bankroll_delta": bankroll_delta,
		"chips_delta": chips_delta,
		"suspicion_delta": suspicion_delta,
		"crew_play_detected": detected,
		"crew_play_member_ids": members,
	}, true)


static func advance_boundary(run_state: RunState, environment: Dictionary, host_capability: Variant = null) -> Array:
	var events: Array = []
	if run_state == null or not run_state.crew_play_host_authorizes(host_capability, environment, str(environment.get("active_game_id", "")), false):
		return events
	var state := normalize_state(run_state.crew_play_state)
	var action_index := run_state.crew_action_index()
	var active_next: Array = []
	for active_value in _array(state.get("active", [])):
		if typeof(active_value) != TYPE_DICTIONARY:
			continue
		var active: Dictionary = active_value
		var play_id := str(active.get("play_id", ""))
		if action_index >= int(active.get("expires_at_action", 0)):
			events.append({"type": "crew_play_ended", "play_id": play_id, "message": "%s's window closes." % str(_definition_ref(play_id).get("display_name", play_id.capitalize()))})
			_append_tombstone(state, active, action_index, "window_ended")
			continue
		var detected := false
		if play_id == "spotter" and action_index > int(active.get("activated_action", action_index)) and environment_key(environment) == str(active.get("environment_key", "")):
			var pit := run_state.pit_boss_watch_status(environment)
			if bool(pit.get("watched", false)):
				detected = _window_detected(run_state, _definition_ref(play_id), int(active.get("sequence", 0)), action_index)
		if detected:
			var heat := maxi(0, int(_definition_ref(play_id).get("detection_heat", 0)))
			var applied := run_state.add_suspicion("crew_play_spotter_burned", heat, "crew_play", true, _environment_context(environment).merged({"action_kind": "cheat"}, true), true)
			events.append({"type": "crew_play_detected", "play_id": play_id, "suspicion_delta": applied, "message": "The pit sweep catches Switch signaling the count. Spotter burns; Heat +%d." % applied})
			_append_tombstone(state, active, action_index, "detected")
			continue
		active_next.append(active)
	state["active"] = active_next
	run_state.crew_play_state = normalize_state(state)
	for event_value in events:
		if typeof(event_value) == TYPE_DICTIONARY:
			run_state.log_story(event_value as Dictionary)
	return events


static func active_status(state_value: Variant, action_index: int, environment: Dictionary, game_id: String = "") -> Array:
	var state := normalize_state(state_value)
	var result: Array = []
	for active_value in _array(state.get("active", [])):
		if typeof(active_value) != TYPE_DICTIONARY:
			continue
		var active: Dictionary = active_value
		if action_index >= int(active.get("expires_at_action", 0)) or str(active.get("environment_key", "")) != environment_key(environment):
			continue
		if not game_id.is_empty() and str(active.get("game_id", "")) != game_id:
			continue
		var play_id := str(active.get("play_id", ""))
		result.append({
			"play_id": play_id,
			"display_name": str(_definition_ref(play_id).get("display_name", play_id.capitalize())),
			"member_ids": _string_array(active.get("member_ids", [])),
			"remaining_boundaries": maxi(0, int(active.get("expires_at_action", 0)) - action_index),
			"effect": (active.get("effect", {}) as Dictionary).duplicate(true) if typeof(active.get("effect", {})) == TYPE_DICTIONARY else {},
		})
	return result


static func is_active(state_value: Variant, play_id: String, action_index: int, environment: Dictionary) -> bool:
	for status_value in active_status(state_value, action_index, environment):
		if typeof(status_value) == TYPE_DICTIONARY and str((status_value as Dictionary).get("play_id", "")) == play_id:
			return true
	return false


static func effect_int(state_value: Variant, play_id: String, effect_key: String, action_index: int, environment: Dictionary, fallback: int) -> int:
	for status_value in active_status(state_value, action_index, environment):
		if typeof(status_value) != TYPE_DICTIONARY or str((status_value as Dictionary).get("play_id", "")) != play_id:
			continue
		var effect: Dictionary = (status_value as Dictionary).get("effect", {}) if typeof((status_value as Dictionary).get("effect", {})) == TYPE_DICTIONARY else {}
		return int(effect.get(effect_key, fallback))
	return fallback


static func distraction_grievance_candidate(state_value: Variant, action_index: int, heat_before: int, heat_after: int) -> Dictionary:
	var state := normalize_state(state_value)
	var liability: Dictionary = state.get("distraction_liability", {}) if typeof(state.get("distraction_liability", {})) == TYPE_DICTIONARY else {}
	if liability.is_empty() or bool(liability.get("recorded", false)) or action_index > int(liability.get("until_action", -1)):
		return {}
	var threshold := maxi(1, int(_config_ref().get("security_consequence_heat", 65)))
	if heat_before >= threshold or heat_after < threshold:
		return {}
	return liability.duplicate(true)


static func mark_distraction_grievance_recorded(state_value: Variant) -> Dictionary:
	var state := normalize_state(state_value)
	state["distraction_liability"] = {}
	return state


static func validate_content(member_ids: Array) -> Array:
	var failures: Array = []
	var source := _config_ref()
	if int(source.get("schema_version", 0)) != SCHEMA_VERSION:
		failures.append("plays.json schema_version must match CrewPlayModel.")
	var seen: Array = []
	for value in _array(source.get("plays", [])):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var play: Dictionary = value
		var play_id := str(play.get("id", ""))
		if not PLAY_IDS.has(play_id) or seen.has(play_id):
			failures.append("plays.json contains unknown or duplicate play %s." % play_id)
		seen.append(play_id)
		if not RANK_IDS.has(str(play.get("minimum_rank", ""))) or _string_array(play.get("game_ids", [])).is_empty():
			failures.append("Play %s has an invalid rank/context." % play_id)
		for member_id in _string_array(play.get("member_ids", [])):
			if member_id != "*" and not member_ids.has(member_id):
				failures.append("Play %s references unknown member %s." % [play_id, member_id])
		if int(play.get("uses_per_run", 0)) <= 0 or int(play.get("cooldown_boundaries", 0)) <= 0:
			failures.append("Play %s needs positive uses and cooldown tuning." % play_id)
	if seen != PLAY_IDS:
		failures.append("plays.json must define the five coordinated plays in contract order.")
	return failures


static func environment_key(environment: Dictionary) -> String:
	return str(environment.get("id", environment.get("world_node_id", environment.get("archetype_id", "")))).strip_edges()


static func _eligible_members(run_state: RunState, environment: Dictionary, play: Dictionary, state: Dictionary, action_index: int) -> Array:
	var result: Array = []
	var allowed := _string_array(play.get("member_ids", []))
	var excluded: Array = []
	if bool(play.get("exclude_active_members", false)):
		for active_value in _array(state.get("active", [])):
			if typeof(active_value) == TYPE_DICTIONARY:
				excluded.append_array(_string_array((active_value as Dictionary).get("member_ids", [])))
	var cooldowns: Dictionary = state.get("member_cooldowns", {})
	var minimum_rank := str(play.get("minimum_rank", "made"))
	for member_value in run_state.crew_present_member_ids(environment):
		var member_id := str(member_value)
		if excluded.has(member_id) or (not allowed.has("*") and not allowed.has(member_id)):
			continue
		if int(cooldowns.get(member_id, 0)) > action_index:
			continue
		if RANK_IDS.find(run_state.crew_rank(member_id)) < RANK_IDS.find(minimum_rank):
			continue
		result.append(member_id)
	result.sort()
	return result


static func _concurrency_allows(state: Dictionary, play_id: String, action_index: int, environment: Dictionary) -> bool:
	var active := active_status(state, action_index, environment)
	if active.is_empty():
		return true
	if active.size() < maxi(1, int(_config_ref().get("active_window_cap", 1))):
		return true
	for active_value in active:
		var pair := "%s:%s" % [str((active_value as Dictionary).get("play_id", "")), play_id]
		if _string_array(_config_ref().get("pairing_exceptions", [])).has(pair):
			return true
	return false


static func _activation_detected(run_state: RunState, play: Dictionary, sequence: int) -> bool:
	var chance := clampi(int(play.get("detection_chance_percent", 0)), 0, 100)
	if chance <= 0:
		return false
	var rng := run_state.create_rng("crew_plays").fork("activation:%s:%d" % [str(play.get("id", "")), sequence])
	return rng.randi_range(1, 100) <= chance


static func _window_detected(run_state: RunState, play: Dictionary, sequence: int, action_index: int) -> bool:
	var chance := clampi(int(play.get("detection_chance_percent", 0)), 0, 100)
	var rng := run_state.create_rng("crew_plays").fork("window:%s:%d:%d" % [str(play.get("id", "")), sequence, action_index])
	return chance > 0 and rng.randi_range(1, 100) <= chance


static func _apply_big_player_warm_state(run_state: RunState, environment: Dictionary, effect: Dictionary) -> void:
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var table: Dictionary = game_states.get("blackjack", {}) if typeof(game_states.get("blackjack", {})) == TYPE_DICTIONARY else {}
	if table.is_empty():
		return
	var minimum := maxi(1, int(effect.get("minimum_warm_count", 3)))
	var maximum := maxi(minimum, int(effect.get("maximum_warm_count", minimum)))
	var current := int(table.get("running_count", 0))
	var warm_count := clampi(current, minimum, maximum) if current >= 0 else clampi(current, -maximum, -minimum)
	if current == 0:
		var rng := run_state.create_rng("crew_plays").fork("big_player_count:%d" % int(normalize_state(run_state.crew_play_state).get("sequence", 0)))
		warm_count = rng.randi_range(minimum, maximum)
	table["running_count"] = warm_count
	table["recorded_running_count"] = warm_count
	table["crew_pre_warmed"] = true
	game_states["blackjack"] = table
	environment["game_states"] = game_states


static func _voice_line(play: Dictionary, members: Array) -> String:
	var lines: Dictionary = play.get("voice_lines", {}) if typeof(play.get("voice_lines", {})) == TYPE_DICTIONARY else {}
	var parts: Array = []
	for member_id in members:
		var line := str(lines.get(member_id, "")).strip_edges()
		if not line.is_empty():
			parts.append(line)
	return " ".join(parts) if not parts.is_empty() else "The crew closes around the table."


static func _result(ok: bool, play_id: String, environment: Dictionary, message: String) -> Dictionary:
	return GameModule.build_action_result({
		"ok": ok,
		"type": "game_action",
		"source_id": "crew_plays",
		"game_id": str(environment.get("active_game_id", "")),
		"action_id": ACTION_PREFIX + play_id,
		"action_kind": "crew_play" if ok else "unknown",
		"stake": 0,
		"won": false,
		"environment_id": environment.get("id", ""),
		"message": message,
	})


static func _environment_context(environment: Dictionary) -> Dictionary:
	return {
		"environment_id": str(environment.get("id", "")),
		"environment_archetype_id": str(environment.get("archetype_id", "")),
		"world_node_id": str(environment.get("world_node_id", "")),
	}


static func _normalize_active(value: Dictionary) -> Dictionary:
	var play_id := str(value.get("play_id", ""))
	if not PLAY_IDS.has(play_id):
		return {}
	var activated := maxi(0, int(value.get("activated_action", 0)))
	var expires := maxi(activated + 1, int(value.get("expires_at_action", activated + 1)))
	return {
		"play_id": play_id,
		"member_ids": _string_array(value.get("member_ids", [])),
		"environment_key": str(value.get("environment_key", "")),
		"game_id": str(value.get("game_id", "")),
		"activated_action": activated,
		"expires_at_action": expires,
		"sequence": maxi(0, int(value.get("sequence", 0))),
		"effect": (value.get("effect", {}) as Dictionary).duplicate(true) if typeof(value.get("effect", {})) == TYPE_DICTIONARY else {},
	}


static func _append_tombstone(state: Dictionary, active: Dictionary, ended_action: int, reason: String) -> void:
	var tombstones := _array(state.get("tombstones", []))
	tombstones.append({
		"play_id": str(active.get("play_id", "")),
		"member_ids": _string_array(active.get("member_ids", [])),
		"environment_key": str(active.get("environment_key", "")),
		"game_id": str(active.get("game_id", "")),
		"sequence": maxi(0, int(active.get("sequence", 0))),
		"ended_action": maxi(0, ended_action),
		"reason": reason,
	})
	while tombstones.size() > TOMBSTONE_LIMIT:
		tombstones.pop_front()
	state["tombstones"] = tombstones


static func _normalize_tombstone(value: Dictionary) -> Dictionary:
	var play_id := str(value.get("play_id", ""))
	var reason := str(value.get("reason", ""))
	if not PLAY_IDS.has(play_id) or reason not in ["window_ended", "detected"] or str(value.get("environment_key", "")).is_empty() \
			or not _string_array(_definition_ref(play_id).get("game_ids", [])).has(str(value.get("game_id", ""))):
		return {}
	return {
		"play_id": play_id,
		"member_ids": _string_array(value.get("member_ids", [])),
		"environment_key": str(value.get("environment_key", "")),
		"game_id": str(value.get("game_id", "")),
		"sequence": maxi(0, int(value.get("sequence", 0))),
		"ended_action": maxi(0, int(value.get("ended_action", 0))),
		"reason": reason,
	}


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	for entry in _array(value):
		var text := str(entry).strip_edges()
		if not text.is_empty():
			result.append(text)
	return result


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _exact_keys(value: Dictionary, expected: Array) -> bool:
	var keys := value.keys(); keys.sort()
	var exact := expected.duplicate(); exact.sort()
	return keys == exact
