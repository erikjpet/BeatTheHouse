class_name NumbersModel
extends RefCounted

const CONFIG_PATH := "res://data/crew/numbers.json"
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const SCHEMA_VERSION := 1
const DEPTH_SCHEMA_VERSION := 2
const PLAY_TYPES := ["straight", "box"]
const FIX_STATES := ["locked", "ready", "bribe_running", "camouflage", "payday", "completed", "aborted"]
const LEGACY_SNAPSHOT_KEYS := [
	"action_index", "active_leak", "collection_state", "draws_by_day",
	"fix_state", "knowledge", "leak_successes", "past_post_attempts",
	"pending_leaks", "schema_version", "seed_value", "slip_sequence", "slips",
]
const CURRENT_SNAPSHOT_KEYS := [
	"action_index", "active_leak", "bookmaker_aftermath", "collection_state",
	"depth_causes", "depth_schema_version", "draw_occasions", "draws_by_day",
	"fix_state", "knowledge", "leak_successes", "past_post_attempts",
	"pending_leaks", "schema_version", "seed_value", "slip_sequence", "slips",
]
const DEPTH_CAUSE_KINDS := [
	"legacy_slip_projection", "slip_issued", "slip_confiscated",
	"slip_settled", "draw_presence", "draw_posted",
]
const DEPTH_CAUSE_KEYS := [
	"action_index", "context", "day", "kind", "sequence", "subject_id", "venue_id",
]

static var _config_cache: Dictionary = {}

var seed_value: int = 1
var action_index: int = 0
var slip_sequence: int = 0
var draws_by_day: Dictionary = {}
var slips: Array = []
var knowledge: Dictionary = {}
var past_post_attempts: int = 0
var fix_state: Dictionary = {}
var leak_successes: int = 0
var pending_leaks: Array = []
var active_leak: Dictionary = {}
var collection_state: Dictionary = {}
var draw_occasions: Dictionary = {}
var bookmaker_aftermath: Dictionary = {}
var depth_causes: Array = []
var config: Dictionary = {}
var _host_capability: RefCounted


static func tuning() -> Dictionary:
	if not _config_cache.is_empty():
		return _config_cache
	if not FileAccess.file_exists(CONFIG_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if typeof(parsed) == TYPE_ARRAY and not (parsed as Array).is_empty():
		parsed = (parsed as Array)[0]
	if typeof(parsed) == TYPE_DICTIONARY:
		_config_cache = (parsed as Dictionary).duplicate(true)
	return _config_cache


func reset(p_seed_value: int, source_config: Dictionary = {}) -> void:
	seed_value = maxi(1, p_seed_value)
	action_index = 0
	slip_sequence = 0
	draws_by_day = {}
	slips = []
	knowledge = {"staggered_close_rumor_ids": [], "silas_tip": false, "assembled": false, "known_numbers_by_day": {}}
	past_post_attempts = 0
	fix_state = {"status": "locked", "retry_day": 0}
	leak_successes = 0
	pending_leaks = []
	active_leak = {}
	collection_state = {}
	draw_occasions = {}
	bookmaker_aftermath = {}
	depth_causes = []
	config = source_config.duplicate(true) if not source_config.is_empty() else tuning().duplicate(true)


# RunState binds one unforgeable live object and never serializes it. Public
# proposal dictionaries cannot substitute for this identity.
func bind_host_capability(capability: RefCounted) -> bool:
	if capability == null or _host_capability != null:
		return false
	_host_capability = capability
	return true


func snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"seed_value": seed_value,
		"action_index": action_index,
		"slip_sequence": slip_sequence,
		"draws_by_day": draws_by_day.duplicate(true),
		"slips": slips.duplicate(true),
		"knowledge": knowledge.duplicate(true),
		"past_post_attempts": past_post_attempts,
		"fix_state": fix_state.duplicate(true),
		"leak_successes": leak_successes,
		"pending_leaks": pending_leaks.duplicate(true),
		"active_leak": active_leak.duplicate(true),
		"collection_state": collection_state.duplicate(true),
		"depth_schema_version": DEPTH_SCHEMA_VERSION,
		"depth_causes": depth_causes.duplicate(true),
		"draw_occasions": draw_occasions.duplicate(true),
		"bookmaker_aftermath": bookmaker_aftermath.duplicate(true),
	}


func restore(source: Dictionary, p_seed_value: int, source_config: Dictionary = {}) -> bool:
	var before := snapshot()
	var before_config := config.duplicate(true)
	var keys := source.keys()
	keys.sort()
	var legacy := keys == LEGACY_SNAPSHOT_KEYS
	var current := keys == CURRENT_SNAPSHOT_KEYS and int(source.get("depth_schema_version", 0)) == DEPTH_SCHEMA_VERSION
	if int(source.get("schema_version", 0)) != SCHEMA_VERSION or (not legacy and not current):
		return false
	_load_core_unchecked(source, p_seed_value, source_config)
	if legacy:
		if not _legacy_depth_is_empty(source):
			_load_snapshot_unchecked(before, before_config)
			return false
		_migrate_legacy_depth()
		return true
	depth_causes = _dictionary_array(source.get("depth_causes", []))
	draw_occasions = _dictionary(source.get("draw_occasions", {})).duplicate(true)
	bookmaker_aftermath = _dictionary(source.get("bookmaker_aftermath", {})).duplicate(true)
	if not _depth_state_is_valid():
		_load_snapshot_unchecked(before, before_config)
		return false
	return true


func advance_to(target_action: int) -> Array:
	var target := maxi(action_index, target_action)
	var events: Array = []
	for boundary in range(action_index + 1, target + 1):
		var day := day_at(boundary)
		if boundary == day_start_action(day):
			events.append_array(_activate_leaks(day))
			events.append(_day_rumor_event(day))
		if boundary == post_action(day):
			var draw := _handle_record_at_boundary(day)
			draw["resolved"] = true
			draw["posted"] = true
			draw["resolved_action"] = boundary
			draw["posted_action"] = boundary
			draws_by_day[str(day)] = draw
			_resolve_draw_occasion(day, boundary)
			events.append({"type": "numbers_post", "day": day, "number": str(draw.get("number", "000")), "action": boundary})
		if boundary == settlement_action(day):
			events.append_array(_settle_day(day))
		action_index = boundary
	return events


func status() -> Dictionary:
	var day := day_at(action_index)
	var draw := _handle_record_at_boundary(day)
	return {
		"action_index": action_index,
		"day": day,
		"post_action": post_action(day),
		"settlement_action": settlement_action(day),
		"posted": bool(draw.get("posted", false)),
		"published_number": known_number(day) if bool(draw.get("posted", false)) else "",
		"yesterday_number": yesterday_number(day),
		"open_slip_count": open_slip_count(),
		"venue_status": venue_statuses(day, action_index),
		"bookmakers": bookmaker_states_public(day, action_index),
	}


# Private systems/test projection. Presentation code must use status().
func internal_status() -> Dictionary:
	var result := status()
	result["knowledge"] = knowledge.duplicate(true)
	result["fix"] = fix_state.duplicate(true)
	result["leak"] = active_leak.duplicate(true)
	result["collection"] = collection_state.duplicate(true)
	return result


# Closed player-safe projections for the world adapter. Clock and disposition
# are derived here; callers cannot author a second book state.
func bookmaker_state(venue_id: String, day: int = -1, at_action: int = -1) -> Dictionary:
	var venue := venue_definition(venue_id)
	if venue.is_empty():
		return {}
	var target_action := action_index if at_action < 0 else maxi(0, at_action)
	var target_day := day_at(target_action) if day < 0 else maxi(0, day)
	var close := close_action(venue_id, target_day)
	var open := target_action < close
	var open_here := 0
	for slip_value in slips:
		var slip := _dictionary(slip_value)
		if int(slip.get("day", -1)) == target_day and str(slip.get("venue_id", "")) == venue_id and str(slip.get("status", "")) == "open":
			open_here += 1
	var memory := _dictionary(bookmaker_aftermath.get(venue_id, {}))
	var disposition := "closed"
	if open:
		disposition = "closing" if close - target_action <= 2 else ("busy" if bool(memory.get("busy", false)) or open_here > 0 else "open")
	var demeanor := "suspicious" if bool(memory.get("refused", false)) else ("wary" if not memory.is_empty() else "friendly")
	return {
		"schema_version": DEPTH_SCHEMA_VERSION,
		"venue_id": venue_id,
		"place_id": "%s::numbers_book" % venue_id,
		"bookmaker_id": "numbers_bookmaker_%s" % venue_id,
		"disposition": disposition,
		"service_state": disposition,
		"demeanor": demeanor,
		"open": open,
		"close_action": close,
		"actions_until_close": maxi(0, close - target_action),
		"open_slip_count": open_here,
		"aftermath": _public_bookmaker_aftermath(memory),
		"memory": _public_bookmaker_aftermath(memory),
	}


func bookmaker_states_public(day: int = -1, at_action: int = -1) -> Array:
	var result: Array = []
	for venue in _dictionary_array(config.get("venues", [])):
		result.append(bookmaker_state(str(venue.get("id", "")), day, at_action))
	return result


func slip_public_state(slip_id: String) -> Dictionary:
	var slip := _slip_by_id(slip_id)
	if slip.is_empty():
		return {}
	var physical := _physical_slip_state(slip)
	return {
		"schema_version": DEPTH_SCHEMA_VERSION,
		"id": str(slip.get("id", "")),
		"day": int(slip.get("day", 0)),
		"venue_id": str(slip.get("venue_id", "")),
		"digits": str(slip.get("digits", "")),
		"stake": int(slip.get("stake", 0)),
		"play_type": str(slip.get("play_type", "")),
		"status": str(slip.get("status", "")),
		"won": bool(slip.get("won", false)),
		"payout": int(slip.get("payout", 0)),
		"item_id": "numbers_slips",
		"instance_id": str(physical.get("instance_id", str(slip.get("id", "")))),
		"node_id": str(physical.get("node_id", "")),
		"place_id": str(physical.get("place_id", "")),
		"holder_id": str(physical.get("holder_id", "")),
		"physical_state": str(physical.get("state", "carried")),
	}


func draw_occasion_status(day: int = -1) -> Dictionary:
	var target_day := day_at(action_index) if day < 0 else maxi(0, day)
	var saved := _dictionary(draw_occasions.get(str(target_day), {}))
	if saved.is_empty():
		return {"schema_version": DEPTH_SCHEMA_VERSION, "day": target_day, "status": "unregistered", "presence": "absent", "post_action": post_action(target_day)}
	var result := saved.duplicate(true)
	result.erase("receipt_key")
	result.erase("cause_sequence")
	if action_index >= post_action(target_day):
		result["number"] = str(_dictionary(draws_by_day.get(str(target_day), {})).get("number", ""))
	return result


func public_aftermath(venue_id: String = "") -> Variant:
	if not venue_id.strip_edges().is_empty():
		return _public_bookmaker_aftermath(_dictionary(bookmaker_aftermath.get(venue_id.strip_edges(), {})))
	var result: Dictionary = {}
	for key_value in bookmaker_aftermath.keys():
		result[str(key_value)] = _public_bookmaker_aftermath(_dictionary(bookmaker_aftermath.get(key_value, {})))
	return result


func host_mark_draw_presence(capability: RefCounted, target_action: int, venue_id: String, host_context: Dictionary) -> bool:
	if capability == null or capability != _host_capability or venue_id != "small_underground_casino":
		return false
	var target := maxi(action_index, target_action)
	var marked := false
	for day in range(day_at(action_index), day_at(target) + 1):
		var boundary := post_action(day)
		if action_index >= boundary or target < boundary:
			continue
		var existing := _dictionary(draw_occasions.get(str(day), {}))
		if not existing.is_empty():
			marked = marked or (str(existing.get("status", "")) == "registered" and str(existing.get("presence", "")) == "present")
			continue
		var context := _closed_host_context(host_context)
		if str(context.get("node_id", "")) != venue_id:
			continue
		var cause_sequence := _append_depth_cause("draw_presence", "draw:%d" % day, day, action_index, venue_id, context)
		draw_occasions[str(day)] = {
			"schema_version": DEPTH_SCHEMA_VERSION,
			"day": day,
			"presence": "present",
			"attendance": "present",
			"venue_id": venue_id,
			"post_action": boundary,
			"status": "registered",
			"cause_sequence": cause_sequence,
		}
		marked = true
	return marked


# The public model entry remains proposal-only. RunState's bound object identity
# is the sole host path, so caller dictionaries never mutate Numbers authority
# and never mint a second receipt authority.
func apply_action(receipt_key: String, action: String, context: Dictionary) -> Dictionary:
	var clean_action := action.strip_edges().to_lower()
	if clean_action in ["draw_present", "draw_absent"] and action_index >= post_action(maxi(0, int(context.get("day", day_at(action_index))))):
		return {"ok": false, "proposed": false, "reason": "attendance_closed"}
	return {
		"ok": false,
		"proposed": true,
		"reason": "host_authority_unavailable",
		"proposal": {"proposal_id": receipt_key.strip_edges(), "action": clean_action, "context": context.duplicate(true), "authoritative": false, "requires": ["host_presence", "host_proximity", "host_command_or_transaction"]},
	}


func begin_action_proposal(sequence_kind: String, context: Dictionary = {}) -> Dictionary:
	var verbs: Array = []
	match sequence_kind.strip_edges().to_lower():
		"place_slip": verbs = ["approach_bookmaker", "choose_number", "choose_money", "write_slip", "hand_slip"]
		"collect_payday": verbs = ["approach_bookmaker", "present_winning_slip", "witness_verification", "receive_payday"]
		"solo_past_post": verbs = ["learn_posted_handle", "travel_to_open_book", "choose_number", "choose_money", "write_slip", "hand_slip", "leave_unseen"]
		_: return {}
	return {"schema_version": DEPTH_SCHEMA_VERSION, "kind": sequence_kind.strip_edges().to_lower(), "step_index": 0, "verbs": verbs, "context": context.duplicate(true), "status": "proposed", "authoritative": false, "requires": ["host_presence", "host_proximity", "host_command_or_transaction"]}


func advance_action_proposal(proposal_value: Variant, verb: String, evidence_claim: Dictionary = {}) -> Dictionary:
	if typeof(proposal_value) != TYPE_DICTIONARY: return {}
	var proposal: Dictionary = (proposal_value as Dictionary).duplicate(true)
	var verbs: Array = proposal.get("verbs", []) if typeof(proposal.get("verbs", [])) == TYPE_ARRAY else []
	var index := int(proposal.get("step_index", 0))
	if str(proposal.get("status", "")) != "proposed" or index < 0 or index >= verbs.size() or str(verbs[index]) != verb.strip_edges(): return proposal
	proposal["step_index"] = index + 1
	proposal["last_evidence_claim"] = evidence_claim.duplicate(true)
	proposal["status"] = "ready_for_host_commit" if index + 1 == verbs.size() else "proposed"
	return proposal


func buy_slip(venue_id: String, digits_value: Variant, stake: int, play_type: String, known_number: String = "") -> Dictionary:
	var venue := venue_definition(venue_id)
	if venue.is_empty():
		return {"ok": false, "message": "That counter does not carry the Numbers."}
	var clean_type := play_type.strip_edges().to_lower()
	if not PLAY_TYPES.has(clean_type):
		return {"ok": false, "message": "Choose straight or box."}
	var digits := _normalize_digits(digits_value)
	if digits.is_empty():
		return {"ok": false, "message": "A slip needs exactly three digits."}
	var slip_config := _dictionary(config.get("slips", {}))
	var minimum := maxi(1, int(slip_config.get("stake_min", 1)))
	var maximum := maxi(minimum, int(slip_config.get("stake_max", 20)))
	if stake < minimum or stake > maximum:
		return {"ok": false, "message": "Stake must be between $%d and $%d." % [minimum, maximum]}
	var day := day_at(action_index)
	var close := close_action(venue_id, day)
	if action_index >= close:
		return {"ok": false, "message": "%s's book is closed for today's handle." % str(venue.get("label", venue_id))}
	var draw := _handle_record_at_boundary(day)
	var is_past_post := bool(draw.get("posted", false)) and not known_number.is_empty()
	if is_past_post:
		if not bool(knowledge.get("assembled", false)):
			return {"ok": false, "message": "The timing means nothing to you."}
		if known_number != self.known_number(day):
			return {"ok": false, "message": "You did not hear today's handle at its source."}
		if known_number != str(draw.get("number", "")):
			return {"ok": false, "message": "That is not the published handle."}
		if digits != known_number:
			return {"ok": false, "message": "A past-post only works if the paper matches the handle."}
	slip_sequence += 1
	var slip_id := "numbers_slip_%05d" % slip_sequence
	var detected := false
	var detection_percent := 0
	if is_past_post:
		past_post_attempts += 1
		detection_percent = detection_chance(stake, past_post_attempts)
		var detection_roll := (_stable_hash("%d:%d:%s:past_post_detection" % [seed_value, day, slip_id]) % 100) + 1
		detected = detection_roll <= detection_percent
	var issue_context := {
		"status": "open", "holder_id": "player", "physical_state": "carried",
		"visibility": "visible", "past_post": is_past_post,
	}
	var issue_cause := _append_depth_cause("slip_issued", slip_id, day, action_index, venue_id, issue_context)
	var slip := {
		"id": slip_id,
		"day": day,
		"venue_id": venue_id,
		"digits": digits,
		"stake": stake,
		"play_type": clean_type,
		"placed_action": action_index,
		"close_action": close,
		"status": "open",
		"past_post": is_past_post,
		"detection_percent": detection_percent,
		"detected": detected,
		"physical_state": _new_physical_slip_state(slip_id, venue_id, "player", "carried", "visible", issue_cause),
	}
	slips.append(slip)
	return {"ok": true, "message": "%s takes the slip." % str(venue.get("label", venue_id)), "slip": slip.duplicate(true)}


func confiscate_open_slips(reason: String = "sweep") -> Dictionary:
	var ids: Array = []
	var stake_total := 0
	for index in range(slips.size()):
		var slip := _dictionary(slips[index])
		if str(slip.get("status", "")) != "open":
			continue
		slip["status"] = "confiscated"
		slip["confiscated_action"] = action_index
		slip["confiscated_reason"] = reason
		var previous_cause := int(_dictionary(slip.get("physical_state", {})).get("cause_sequence", 0))
		var cause_sequence := _append_depth_cause(
			"slip_confiscated", str(slip.get("id", "")), int(slip.get("day", 0)),
			action_index, str(slip.get("venue_id", "")),
			{"status": "confiscated", "holder_id": "police", "physical_state": "confiscated", "visibility": "hidden", "reason": reason, "previous_cause_sequence": previous_cause},
		)
		var confiscated_physical := _new_physical_slip_state(str(slip.get("id", "")), str(slip.get("venue_id", "")), "police", "confiscated", "hidden", cause_sequence)
		confiscated_physical["last_action"] = "confiscated"
		slip["physical_state"] = confiscated_physical
		slips[index] = slip
		ids.append(str(slip.get("id", "")))
		stake_total += maxi(0, int(slip.get("stake", 0)))
	return {"count": ids.size(), "slip_ids": ids, "stake_total": stake_total, "reason": reason}


func hear_staggered_close_rumor(rumor_id: String) -> Dictionary:
	var clean_id := rumor_id.strip_edges()
	if clean_id.is_empty():
		return knowledge.duplicate(true)
	var heard := _string_array(knowledge.get("staggered_close_rumor_ids", []))
	if not heard.has(clean_id):
		heard.append(clean_id)
		heard.sort()
	knowledge["staggered_close_rumor_ids"] = heard
	_refresh_knowledge()
	return knowledge.duplicate(true)


func buy_silas_tip(today_number: bool = false) -> Dictionary:
	knowledge["silas_tip"] = true
	_refresh_knowledge()
	var result := {"ok": true, "knowledge": knowledge.duplicate(true)}
	if today_number:
		var day := day_at(action_index)
		result["number"] = reveal_number(day, "silas")
	return result


func reveal_number(day: int, source: String) -> String:
	var draw := _handle_record_at_boundary(day)
	if not bool(draw.get("posted", false)) and source != "silas":
		return ""
	var known := _dictionary(knowledge.get("known_numbers_by_day", {})).duplicate(true)
	known[str(day)] = {"number": str(draw.get("number", "000")), "source": source, "known_action": action_index}
	knowledge["known_numbers_by_day"] = known
	return str(draw.get("number", "000"))


func known_number(day: int = -1) -> String:
	var target_day := day_at(action_index) if day < 0 else day
	var known := _dictionary(_dictionary(knowledge.get("known_numbers_by_day", {})).get(str(target_day), {}))
	if not known.is_empty():
		return str(known.get("number", ""))
	if action_index >= settlement_action(target_day):
		return str(_handle_record_at_boundary(target_day).get("number", ""))
	return ""


func detection_chance(stake: int, repetition: int) -> int:
	var tuning_data := _dictionary(config.get("past_posting", {}))
	var chance := int(tuning_data.get("detection_base_percent", 5))
	chance += maxi(0, repetition - 1) * int(tuning_data.get("detection_repeat_step_percent", 7))
	chance += maxi(0, int(floor(float(stake) / 5.0))) * int(tuning_data.get("detection_stake_step_percent_per_5", 3))
	chance += maxi(0, int(active_leak.get("strictness_delta", 0))) * 2
	return clampi(chance, 0, int(tuning_data.get("detection_cap_percent", 70)))


func fix_unlock(eligible: bool) -> Dictionary:
	var day := day_at(action_index)
	if eligible and day >= int(fix_state.get("retry_day", 0)) and ["locked", "aborted", "completed"].has(str(fix_state.get("status", "locked"))):
		fix_state = {"status": "ready", "retry_day": int(fix_state.get("retry_day", 0))}
	return fix_state.duplicate(true)


func fix_begin_bribe() -> Dictionary:
	if str(fix_state.get("status", "")) != "ready":
		return {"ok": false, "message": "Lucky has no fix ready."}
	var current_day := day_at(action_index)
	# The bribe and camouflage are a real operation, so they always prepare the
	# next handle instead of rewriting a draw whose clock is already in motion.
	var target_day := current_day + 1
	fix_state = {"status": "bribe_running", "target_day": target_day, "started_action": action_index}
	return {"ok": true, "fix": fix_state.duplicate(true)}


func fix_record_bribe(success: bool, resolution: Dictionary = {}) -> Dictionary:
	if str(fix_state.get("status", "")) != "bribe_running":
		return {"ok": false, "message": "No bribe package is moving."}
	if not success:
		var retry_delay := maxi(1, int(_dictionary(config.get("fix", {})).get("retry_delay_days", 1)))
		fix_state["status"] = "aborted"
		fix_state["aborted_action"] = action_index
		fix_state["retry_day"] = day_at(action_index) + retry_delay
		return {"ok": true, "aborted": true, "fix": fix_state.duplicate(true)}
	var score := 55
	if bool(resolution.get("clean", false)):
		score += 25
	if bool(resolution.get("fast", false)):
		score += 20
	fix_state["status"] = "camouflage"
	fix_state["bribe_score"] = clampi(score, 0, 100)
	fix_state["bribe_resolution"] = resolution.duplicate(true)
	return {"ok": true, "fix": fix_state.duplicate(true)}


func fix_allocation_quote(allocations_value: Variant) -> Dictionary:
	if str(fix_state.get("status", "")) != "camouflage":
		return {"ok": false, "message": "The camouflage is not on the desk."}
	var scheduled_day := int(fix_state.get("target_day", day_at(action_index) + 1))
	if action_index >= post_action(scheduled_day):
		return {"ok": false, "late": true, "message": "The handle posted before the spread was covered."}
	var allocations := _normalize_allocations(allocations_value)
	var camouflage := _dictionary(_dictionary(config.get("fix", {})).get("camouflage", {}))
	var minimum_venues := maxi(1, int(camouflage.get("minimum_venues", 3)))
	if allocations.size() < minimum_venues:
		return {"ok": false, "message": "Spread the paper across at least %d books." % minimum_venues}
	var stake_limit := maxi(1, int(_dictionary(config.get("slips", {})).get("stake_max", 20)))
	var total := 0
	var maximum := 0
	var thin_count := 0
	for venue_id in allocations.keys():
		var stake_value: Variant = allocations.get(venue_id, 0)
		var allocation_stake := maxi(0, int(stake_value))
		if allocation_stake > stake_limit:
			return {"ok": false, "message": "%s will only write up to $%d on one slip." % [str(venue_definition(str(venue_id)).get("label", venue_id)), stake_limit]}
		total += allocation_stake
		maximum = maxi(maximum, allocation_stake)
		if allocation_stake < int(camouflage.get("thin_venue_stake", 4)):
			thin_count += 1
	if total <= 0:
		return {"ok": false, "message": "Empty books camouflage nothing."}
	var concentration := int(ceil(float(maximum) * 100.0 / float(total)))
	var cap := int(camouflage.get("maximum_concentration_percent", 45))
	var too_concentrated := concentration > cap
	var target_total := maxi(1, int(camouflage.get("target_total_stake", 60)))
	var volume_score := clampi(int(round(float(total) * 100.0 / float(target_total))), 0, 100)
	var spread_score := clampi(100 - maxi(0, concentration - int(100.0 / float(allocations.size()))) * 2 - thin_count * 12, 0, 100)
	var camouflage_score := clampi(int(round((float(volume_score) + float(spread_score)) * 0.5)), 0, 100)
	return {
		"ok": true,
		"allocations": allocations,
		"total": total,
		"venue_count": allocations.size(),
		"concentration_percent": concentration,
		"too_concentrated": too_concentrated,
		"camouflage_score": camouflage_score,
		"operation_heat": int(camouflage.get("operation_heat_too_concentrated", 18)) if too_concentrated else 0,
	}


func fix_allocate(allocations_value: Variant) -> Dictionary:
	var quote := fix_allocation_quote(allocations_value)
	if not bool(quote.get("ok", false)):
		if bool(quote.get("late", false)):
			fix_state["status"] = "aborted"
			fix_state["aborted_action"] = action_index
			fix_state["retry_day"] = day_at(action_index) + maxi(1, int(_dictionary(config.get("fix", {})).get("retry_delay_days", 1)))
			quote["aborted"] = true
		return quote
	var scheduled_day := int(fix_state.get("target_day", day_at(action_index) + 1))
	var allocations := _dictionary(quote.get("allocations", {})).duplicate(true)
	var target_day := scheduled_day
	var fixed_number := _three_digits(_stable_hash("%d:%d:crew_fix_number" % [seed_value, target_day]) % 1000)
	var draw := _handle_record_at_boundary(target_day)
	draw["number"] = fixed_number
	draw["fixed_by_crew"] = true
	draws_by_day[str(target_day)] = draw
	var slip_ids: Array = []
	var venue_ids := allocations.keys()
	venue_ids.sort()
	for venue_id_value in venue_ids:
		var venue_id := str(venue_id_value)
		var stake := int(allocations.get(venue_id_value, 0))
		slip_sequence += 1
		var slip_id := "numbers_slip_%05d" % slip_sequence
		var cause_sequence := _append_depth_cause(
			"slip_issued", slip_id, target_day, action_index, venue_id,
			{"status": "open", "holder_id": "player", "physical_state": "carried", "visibility": "hidden", "past_post": false},
		)
		slips.append({
			"id": slip_id,
			"day": target_day,
			"venue_id": venue_id,
			"digits": fixed_number,
			"stake": stake,
			"play_type": "straight",
			"placed_action": action_index,
			"close_action": close_action(venue_id, target_day),
			"status": "open",
			"past_post": false,
			"detection_percent": 0,
			"detected": false,
			"crew_fix": true,
			"physical_state": _new_physical_slip_state(slip_id, venue_id, "player", "carried", "hidden", cause_sequence),
		})
		slip_ids.append(slip_id)
	fix_state["status"] = "payday"
	fix_state["allocations"] = allocations
	fix_state["allocation_total"] = int(quote.get("total", 0))
	fix_state["concentration_percent"] = int(quote.get("concentration_percent", 0))
	fix_state["too_concentrated"] = bool(quote.get("too_concentrated", false))
	fix_state["camouflage_score"] = int(quote.get("camouflage_score", 0))
	fix_state["slip_ids"] = slip_ids
	fix_state["fixed_number"] = fixed_number
	return {
		"ok": true,
		"message": "$%d in crew paper is spread across %d books." % [int(quote.get("total", 0)), allocations.size()],
		"total": int(quote.get("total", 0)),
		"slip_count": slip_ids.size(),
		"operation_heat": int(quote.get("operation_heat", 0)),
		"fix": fix_state.duplicate(true),
	}


func begin_collection(stops: Array, bag_value: int, job_id: String) -> Dictionary:
	collection_state = {
		"status": "active",
		"day": day_at(action_index),
		"job_id": job_id,
		"stops": stops.duplicate(true),
		"bag_value": maxi(0, bag_value),
		"started_action": action_index,
		"deadline_action": post_action(day_at(action_index)),
	}
	return collection_state.duplicate(true)


func resolve_collection(success: bool, reason: String, resolution: Dictionary = {}) -> Dictionary:
	if str(collection_state.get("status", "")) != "active":
		return {}
	collection_state["status"] = "resolved"
	collection_state["success"] = success
	collection_state["reason"] = reason
	collection_state["resolution"] = resolution.duplicate(true)
	collection_state["resolved_action"] = action_index
	return collection_state.duplicate(true)


func collection_next_node(visited_stop_ids: Array) -> String:
	if str(collection_state.get("status", "")) != "active":
		return ""
	for stop in _dictionary_array(collection_state.get("stops", [])):
		if not visited_stop_ids.has(str(stop.get("id", ""))):
			return str(stop.get("node_id", ""))
	return ""


func _apply_depth_action(action: String, context: Dictionary) -> Dictionary:
	# Retained as a private compatibility symbol for callers compiled against the
	# rejected candidate. It is permanently fail-closed and cannot mutate state.
	return {"ok": false, "proposed": true, "reason": "host_authority_unavailable", "action": action, "context": context.duplicate(true)}


func _resolve_draw_occasion(day: int, boundary: int) -> void:
	var occasion := _dictionary(draw_occasions.get(str(day), {})).duplicate(true)
	if occasion.is_empty():
		occasion = {"schema_version": DEPTH_SCHEMA_VERSION, "day": day, "presence": "absent", "attendance": "absent", "venue_id": "", "post_action": boundary, "status": "registered", "cause_sequence": 0}
	var posted_cause := _append_depth_cause(
		"draw_posted", "draw:%d" % day, day, boundary,
		str(occasion.get("venue_id", "")),
		{"presence": str(occasion.get("presence", "absent")), "presence_cause_sequence": int(occasion.get("cause_sequence", 0))},
	)
	occasion["status"] = "witnessed" if str(occasion.get("presence", "absent")) == "present" else "missed"
	occasion["resolved_action"] = boundary
	occasion["cause_sequence"] = posted_cause
	draw_occasions[str(day)] = occasion


func venue_definition(venue_id: String) -> Dictionary:
	for venue in _dictionary_array(config.get("venues", [])):
		if str(venue.get("id", "")) == venue_id.strip_edges():
			return venue
	return {}


func venue_statuses(day: int, at_action: int) -> Array:
	var result: Array = []
	for venue in _dictionary_array(config.get("venues", [])):
		var venue_id := str(venue.get("id", ""))
		var close := close_action(venue_id, day)
		var row: Dictionary = venue.duplicate(true)
		row["close_action"] = close
		row["open"] = at_action < close
		row["strictness_delta"] = int(active_leak.get("strictness_delta", 0))
		result.append(row)
	return result


func day_at(at_action: int) -> int:
	return int(floor(float(maxi(0, at_action)) / float(actions_per_day())))


func day_start_action(day: int) -> int:
	return maxi(0, day) * actions_per_day()


func post_action(day: int) -> int:
	return day_start_action(day) + int(_dictionary(config.get("clock", {})).get("post_action_offset", 16))


func settlement_action(day: int) -> int:
	return day_start_action(day) + int(_dictionary(config.get("clock", {})).get("settlement_action_offset", 21))


func close_action(venue_id: String, day: int) -> int:
	var venue := venue_definition(venue_id)
	return post_action(day) + int(venue.get("close_offset_from_post_actions", -1))


func actions_per_day() -> int:
	return maxi(1, int(_dictionary(config.get("clock", {})).get("actions_per_day", 24)))


func yesterday_number(day: int = -1) -> String:
	var target_day := day_at(action_index) if day < 0 else day
	if target_day <= 0:
		return ""
	return str(_handle_record_at_boundary(target_day - 1).get("number", ""))


func open_slip_count() -> int:
	var count := 0
	for slip in slips:
		if str(_dictionary(slip).get("status", "")) == "open":
			count += 1
	return count


func _handle_record_at_boundary(day: int) -> Dictionary:
	var saved := _dictionary(draws_by_day.get(str(maxi(0, day)), {}))
	if not saved.is_empty():
		return saved.duplicate(true)
	# Pure named derivation. Only the post boundary or an explicit pre-post fix
	# persists this value into draws_by_day.
	return {
		"day": maxi(0, day),
		"number": _derived_handle(day),
		"resolved": false,
		"posted": false,
		"fixed_by_crew": false,
	}


func _settle_day(day: int) -> Array:
	var events: Array = []
	var draw := _handle_record_at_boundary(day)
	var winning_number := str(draw.get("number", "000"))
	var authored_pool_cap := maxi(0, int(_dictionary(config.get("slips", {})).get("declared_pool_payout_cap", 9000)))
	var pile_on_multiplier := maxi(100, int(active_leak.get("declared_pool_multiplier_percent", 100)))
	# Pile-on NPC paper consumes the declared pool first. The player's available
	# pool remains capped and therefore shrinks as leaked action crowds the books.
	var pool_cap := int(floor(float(authored_pool_cap) * 100.0 / float(pile_on_multiplier)))
	var paid_from_pool := 0
	for index in range(slips.size()):
		var slip := _dictionary(slips[index])
		if int(slip.get("day", -1)) != day or str(slip.get("status", "")) != "open":
			continue
		var won := _slip_wins(slip, winning_number)
		var payout := _slip_payout(slip) if won else 0
		payout = mini(payout, maxi(0, pool_cap - paid_from_pool))
		var clawed_back := payout
		if bool(slip.get("detected", false)):
			payout = 0
		slip["status"] = "settled"
		slip["winning_number"] = winning_number
		slip["won"] = won
		slip["payout"] = payout
		slip["settled_action"] = settlement_action(day)
		var settlement_cause := _append_depth_cause(
			"slip_settled", str(slip.get("id", "")), day, settlement_action(day),
			str(slip.get("venue_id", "")),
			{"status": "settled", "won": won, "payout": payout, "detected": bool(slip.get("detected", false))},
		)
		slips[index] = slip
		_record_settlement_aftermath(slip, settlement_cause)
		paid_from_pool += payout
		var event := {"type": "numbers_settlement", "day": day, "slip": slip.duplicate(true), "payout": payout}
		if bool(slip.get("past_post", false)) and bool(slip.get("detected", false)):
			var past_tuning := _dictionary(config.get("past_posting", {}))
			event["type"] = "numbers_past_post_detected"
			event["clawed_back"] = clawed_back
			event["penalty"] = maxi(0, int(past_tuning.get("penalty_flat", 20))) + maxi(0, int(slip.get("stake", 0))) * maxi(0, int(past_tuning.get("penalty_stake_multiplier", 2)))
		elif bool(slip.get("past_post", false)) and won:
			event["type"] = "numbers_past_post_success"
			if int(slip.get("stake", 0)) >= int(_dictionary(config.get("leak", {})).get("qualifying_solo_stake", 10)):
				_queue_leak(day + 1, winning_number, "solo_past_post")
		events.append(event)
	if str(fix_state.get("status", "")) == "payday" and int(fix_state.get("target_day", -1)) == day:
		var cut := _fix_cut()
		fix_state["status"] = "completed"
		fix_state["player_cut"] = cut
		fix_state["completed_action"] = settlement_action(day)
		_queue_leak(day + 1, winning_number, "crew_fix")
		events.append({"type": "numbers_fix_payday", "day": day, "number": winning_number, "player_cut": cut, "fix": fix_state.duplicate(true)})
	return events


func _fix_cut() -> int:
	var payday := _dictionary(_dictionary(config.get("fix", {})).get("payday", {}))
	var bribe_score := clampi(int(fix_state.get("bribe_score", 0)), 0, 100)
	var camouflage_score := clampi(int(fix_state.get("camouflage_score", 0)), 0, 100)
	var bribe_weight := clampi(int(payday.get("performance_weight_bribe_percent", 45)), 0, 100)
	var camouflage_weight := clampi(int(payday.get("performance_weight_camouflage_percent", 55)), 0, 100)
	var total_weight := maxi(1, bribe_weight + camouflage_weight)
	var performance := int(round(float(bribe_score * bribe_weight + camouflage_score * camouflage_weight) / float(total_weight)))
	var base_percent := maxi(0, int(payday.get("base_cut_percent", 10)))
	var max_percent := maxi(base_percent, int(payday.get("maximum_cut_percent", 28)))
	var cut_percent := base_percent + int(round(float(max_percent - base_percent) * float(performance) / 100.0))
	return int(floor(float(maxi(0, int(payday.get("crew_pool", 240)))) * float(cut_percent) / 100.0))


func _queue_leak(active_day: int, number: String, source: String) -> void:
	leak_successes += 1
	var row := _leak_row(leak_successes)
	var chance := clampi(int(row.get("sweep_reroute_chance_percent", 0)), 0, 100)
	var roll := (_stable_hash("%d:%d:%d:numbers_leak_sweep" % [seed_value, active_day, leak_successes]) % 100) + 1
	pending_leaks.append({
		"active_day": active_day,
		"number": number,
		"source": source,
		"successes": leak_successes,
		"declared_pool_multiplier_percent": int(row.get("declared_pool_multiplier_percent", 100)),
		"strictness_delta": int(row.get("strictness_delta", 0)),
		"sweep_reroute_chance_percent": chance,
		"sweep_reroute_requested": chance > 0 and roll <= chance,
	})


func _activate_leaks(day: int) -> Array:
	var events: Array = []
	active_leak = {}
	var retained: Array = []
	for leak in pending_leaks:
		var entry := _dictionary(leak)
		if int(entry.get("active_day", -1)) == day:
			active_leak = entry.duplicate(true)
			events.append({"type": "numbers_leak_active", "leak": active_leak.duplicate(true)})
		else:
			retained.append(entry)
	pending_leaks = retained
	return events


func _day_rumor_event(day: int) -> Dictionary:
	var yesterday := yesterday_number(day)
	var hot_number := _three_digits(_stable_hash("%d:%d:numbers_hot_talk" % [seed_value, day]) % 1000)
	return {"type": "numbers_day_rumors", "day": day, "yesterday_number": yesterday, "hot_number": hot_number}


func _leak_row(success_count: int) -> Dictionary:
	var selected: Dictionary = {}
	for row in _dictionary_array(_dictionary(config.get("leak", {})).get("escalation", [])):
		if success_count >= int(row.get("successes", 1)):
			selected = row
	return selected


func _slip_wins(slip: Dictionary, winning_number: String) -> bool:
	var digits := str(slip.get("digits", ""))
	if str(slip.get("play_type", "")) == "straight":
		return digits == winning_number
	return _sorted_digits(digits) == _sorted_digits(winning_number)


func _slip_payout(slip: Dictionary) -> int:
	var play := _dictionary(_dictionary(_dictionary(config.get("slips", {})).get("play_types", {})).get(str(slip.get("play_type", "")), {}))
	var gross := maxi(0, int(slip.get("stake", 0))) * maxi(0, int(play.get("payout_to_one", 0)))
	return mini(gross, maxi(0, int(play.get("per_slip_payout_cap", gross))))


func _refresh_knowledge() -> void:
	var required := maxi(1, int(_dictionary(config.get("past_posting", {})).get("required_distinct_staggered_close_rumors", 2)))
	knowledge["assembled"] = bool(knowledge.get("silas_tip", false)) and _string_array(knowledge.get("staggered_close_rumor_ids", [])).size() >= required


func _slip_index(slip_id: String) -> int:
	for index in range(slips.size()):
		if str(_dictionary(slips[index]).get("id", "")) == slip_id.strip_edges(): return index
	return -1


func _slip_by_id(slip_id: String) -> Dictionary:
	var index := _slip_index(slip_id)
	return _dictionary(slips[index]).duplicate(true) if index >= 0 else {}


func _physical_slip_state(slip: Dictionary) -> Dictionary:
	var saved := _dictionary(slip.get("physical_state", {}))
	if not saved.is_empty(): return saved.duplicate(true)
	var status := str(slip.get("status", "open"))
	return _new_physical_slip_state(str(slip.get("id", "")), str(slip.get("venue_id", "")), "player", "carried" if status in ["open", "settled"] else status, "visible", 0)


func _new_physical_slip_state(slip_id: String, node_id: String, holder_id: String, possession: String, visibility: String, cause_sequence: int) -> Dictionary:
	return {
		"schema_version": DEPTH_SCHEMA_VERSION,
		"item_id": "numbers_slips",
		"instance_id": slip_id,
		"node_id": node_id,
		"place_id": "player" if holder_id == "player" else "%s::numbers_book" % node_id,
		"holder_id": holder_id,
		"possession": possession,
		"state": possession,
		"visibility": visibility,
		"last_action": "issued",
		"last_action_index": action_index,
		"cause_sequence": cause_sequence,
	}


func _record_settlement_aftermath(slip: Dictionary, cause_sequence: int) -> void:
	var venue_id := str(slip.get("venue_id", ""))
	if venue_id.is_empty(): return
	var memory := _dictionary(bookmaker_aftermath.get(venue_id, {})).duplicate(true)
	if bool(slip.get("detected", false)):
		memory["suspicious"] = true
		memory["past_post_memory"] = true
		memory["last_public_event"] = "refusal"
	elif bool(slip.get("won", false)):
		memory["friendly"] = true
		memory["last_public_event"] = "winner"
	memory["last_day"] = int(slip.get("day", 0))
	var causes := _int_array(memory.get("_cause_sequences", []))
	causes.append(cause_sequence)
	memory["_cause_sequences"] = causes
	bookmaker_aftermath[venue_id] = memory


func _record_collection_aftermath(slip: Dictionary) -> void:
	var venue_id := str(slip.get("venue_id", ""))
	var memory := _dictionary(bookmaker_aftermath.get(venue_id, {})).duplicate(true)
	memory["friendly"] = true
	memory["collection_count"] = int(memory.get("collection_count", 0)) + 1
	memory["last_public_event"] = "large_win" if int(slip.get("payout", 0)) >= _slip_payout({"stake": maxi(1, int(_dictionary(config.get("slips", {})).get("stake_max", 20))), "play_type": str(slip.get("play_type", ""))}) else "collected_win"
	memory["last_day"] = int(slip.get("day", 0))
	bookmaker_aftermath[venue_id] = memory


static func _public_bookmaker_aftermath(memory: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in ["busy", "refused", "visit_count", "friendly", "wary", "suspicious", "past_post_memory", "collection_count", "last_public_event", "last_day"]:
		if memory.has(key): result[key] = memory.get(key)
	return result


func _append_depth_cause(kind: String, subject_id: String, day: int, at_action: int, venue_id: String, context: Dictionary) -> int:
	var sequence := depth_causes.size() + 1
	depth_causes.append({
		"sequence": sequence,
		"kind": kind,
		"subject_id": subject_id,
		"day": maxi(0, day),
		"action_index": maxi(0, at_action),
		"venue_id": venue_id,
		"context": context.duplicate(true),
	})
	return sequence


static func _closed_host_context(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in ["node_id", "environment_visit_id", "night_instance_id", "context_instance_id"]:
		var text := str(value.get(key, "")).strip_edges()
		if text.is_empty() or text.length() > 128:
			return {}
		result[key] = text
	return result


static func _dictionary_has_exact_keys(value: Dictionary, expected: Array) -> bool:
	var keys := value.keys()
	keys.sort()
	var wanted := expected.duplicate()
	wanted.sort()
	return keys == wanted


func _load_core_unchecked(source: Dictionary, p_seed_value: int, source_config: Dictionary) -> void:
	reset(p_seed_value, source_config)
	seed_value = maxi(1, int(source.get("seed_value", p_seed_value)))
	action_index = maxi(0, int(source.get("action_index", 0)))
	slip_sequence = maxi(0, int(source.get("slip_sequence", 0)))
	draws_by_day = _dictionary(source.get("draws_by_day", {})).duplicate(true)
	slips = _dictionary_array(source.get("slips", []))
	knowledge = _normalize_knowledge(source.get("knowledge", {}))
	past_post_attempts = maxi(0, int(source.get("past_post_attempts", 0)))
	fix_state = _dictionary(source.get("fix_state", {})).duplicate(true)
	if not FIX_STATES.has(str(fix_state.get("status", "locked"))):
		fix_state = {"status": "locked", "retry_day": 0}
	leak_successes = maxi(0, int(source.get("leak_successes", 0)))
	pending_leaks = _dictionary_array(source.get("pending_leaks", []))
	active_leak = _dictionary(source.get("active_leak", {})).duplicate(true)
	collection_state = _dictionary(source.get("collection_state", {})).duplicate(true)


func _load_snapshot_unchecked(source: Dictionary, source_config: Dictionary) -> void:
	_load_core_unchecked(source, int(source.get("seed_value", 1)), source_config)
	depth_causes = _dictionary_array(source.get("depth_causes", []))
	draw_occasions = _dictionary(source.get("draw_occasions", {})).duplicate(true)
	bookmaker_aftermath = _dictionary(source.get("bookmaker_aftermath", {})).duplicate(true)


static func _legacy_depth_is_empty(source: Dictionary) -> bool:
	for slip_value in _dictionary_array(source.get("slips", [])):
		if slip_value.has("physical_state"):
			return false
	return true


func _migrate_legacy_depth() -> void:
	depth_causes = []
	draw_occasions = {}
	bookmaker_aftermath = {}
	for index in range(slips.size()):
		var slip := _dictionary(slips[index]).duplicate(true)
		var status := str(slip.get("status", "open"))
		var holder := "police" if status == "confiscated" else "player"
		var physical := "confiscated" if status == "confiscated" else "carried"
		var visibility := "hidden" if status == "confiscated" else "visible"
		var cause := _append_depth_cause(
			"legacy_slip_projection", str(slip.get("id", "")), int(slip.get("day", 0)),
			int(slip.get("placed_action", 0)), str(slip.get("venue_id", "")),
			{"status": status, "holder_id": holder, "physical_state": physical, "visibility": visibility},
		)
		var projected := _new_physical_slip_state(str(slip.get("id", "")), str(slip.get("venue_id", "")), holder, physical, visibility, cause)
		projected["last_action"] = "legacy_projection"
		projected["last_action_index"] = int(slip.get("placed_action", 0))
		slip["physical_state"] = projected
		slips[index] = slip


func _depth_state_is_valid() -> bool:
	if depth_causes.size() > 4096 or slips.size() > 4096 or not _depth_causes_are_closed():
		return false
	var seen_slips: Dictionary = {}
	for slip_value in slips:
		var slip := _dictionary(slip_value)
		var slip_id := str(slip.get("id", ""))
		if slip_id.is_empty() or slip_id.length() > 128 or seen_slips.has(slip_id) or not _core_slip_is_valid(slip) or not _physical_slip_is_valid(slip):
			return false
		seen_slips[slip_id] = true
	if not _draw_occasions_are_valid():
		return false
	return bookmaker_aftermath == _expected_bookmaker_aftermath() and _all_slip_causes_are_referenced()


func _core_slip_is_valid(slip: Dictionary) -> bool:
	var venue_id := str(slip.get("venue_id", ""))
	var day := int(slip.get("day", -1))
	var stake := int(slip.get("stake", 0))
	var limits := _dictionary(config.get("slips", {}))
	if venue_definition(venue_id).is_empty() or day < 0 or _normalize_digits(slip.get("digits", "")) != str(slip.get("digits", "")) or str(slip.get("play_type", "")) not in PLAY_TYPES:
		return false
	if stake < maxi(1, int(limits.get("stake_min", 1))) or stake > maxi(1, int(limits.get("stake_max", 20))) or int(slip.get("placed_action", -1)) < 0 or int(slip.get("placed_action", 0)) > action_index or int(slip.get("close_action", -1)) != close_action(venue_id, day):
		return false
	return str(slip.get("status", "")) in ["open", "settled", "confiscated"]


func _depth_causes_are_closed() -> bool:
	for index in range(depth_causes.size()):
		var cause := _dictionary(depth_causes[index])
		var keys := cause.keys()
		keys.sort()
		if keys != DEPTH_CAUSE_KEYS or int(cause.get("sequence", 0)) != index + 1:
			return false
		var kind := str(cause.get("kind", ""))
		if not DEPTH_CAUSE_KINDS.has(kind) or int(cause.get("action_index", -1)) < 0 or int(cause.get("action_index", 0)) > action_index:
			return false
		var subject_id := str(cause.get("subject_id", ""))
		var context := _dictionary(cause.get("context", {}))
		if subject_id.is_empty() or subject_id.length() > 128 or str(cause.get("venue_id", "")).length() > 128 or int(cause.get("day", -1)) < 0 or int(cause.get("day", 0)) > day_at(action_index) + 1 or context.is_empty() or JSON.stringify(context).length() > 1024:
			return false
		if kind.begins_with("slip_") or kind == "legacy_slip_projection":
			var slip := _slip_by_id(subject_id)
			if slip.is_empty() or str(slip.get("venue_id", "")) != str(cause.get("venue_id", "")) or int(slip.get("day", -1)) != int(cause.get("day", -2)):
				return false
			if kind == "slip_issued":
				if not _dictionary_has_exact_keys(context, ["holder_id", "past_post", "physical_state", "status", "visibility"]):
					return false
				if str(context.get("holder_id", "")) not in ["player", "police"] or str(context.get("physical_state", "")) not in ["carried", "confiscated"] or str(context.get("visibility", "")) not in ["visible", "hidden"] or bool(context.get("past_post", false)) != bool(slip.get("past_post", false)):
					return false
			elif kind == "legacy_slip_projection":
				if not _dictionary_has_exact_keys(context, ["holder_id", "physical_state", "status", "visibility"]):
					return false
				if str(context.get("status", "")) != str(slip.get("status", "")) or str(context.get("holder_id", "")) not in ["player", "police"] or str(context.get("physical_state", "")) not in ["carried", "confiscated"] or str(context.get("visibility", "")) not in ["visible", "hidden"]:
					return false
			elif kind == "slip_confiscated":
				var previous := int(context.get("previous_cause_sequence", 0))
				var previous_cause := _dictionary(depth_causes[previous - 1]) if previous > 0 and previous < int(cause.get("sequence", 0)) else {}
				if not _dictionary_has_exact_keys(context, ["holder_id", "physical_state", "previous_cause_sequence", "reason", "status", "visibility"]) or str(slip.get("status", "")) != "confiscated" or str(context.get("status", "")) != "confiscated" or str(context.get("holder_id", "")) != "police" or str(context.get("physical_state", "")) != "confiscated" or str(context.get("visibility", "")) != "hidden" or str(context.get("reason", "")) != str(slip.get("confiscated_reason", "")) or previous <= 0 or previous >= int(cause.get("sequence", 0)) or str(previous_cause.get("subject_id", "")) != subject_id or str(previous_cause.get("venue_id", "")) != str(cause.get("venue_id", "")):
					return false
			elif kind == "slip_settled":
				var settled_day := int(slip.get("day", -1))
				var settled_draw := _dictionary(draws_by_day.get(str(settled_day), {}))
				if not _dictionary_has_exact_keys(context, ["detected", "payout", "status", "won"]) or str(slip.get("status", "")) != "settled" or int(cause.get("action_index", -1)) != settlement_action(settled_day) or int(slip.get("settled_action", -1)) != settlement_action(settled_day) or str(context.get("status", "")) != "settled" or bool(context.get("won", false)) != bool(slip.get("won", false)) or bool(slip.get("won", false)) != _slip_wins(slip, str(settled_draw.get("number", ""))) or int(context.get("payout", -1)) != int(slip.get("payout", -2)) or bool(context.get("detected", false)) != bool(slip.get("detected", false)):
					return false
		elif kind == "draw_presence":
			if not _dictionary_has_exact_keys(context, ["context_instance_id", "environment_visit_id", "night_instance_id", "node_id"]) or subject_id != "draw:%d" % int(cause.get("day", 0)) or str(cause.get("venue_id", "")) != "small_underground_casino" or _closed_host_context(context) != context or int(cause.get("action_index", 0)) >= post_action(int(cause.get("day", 0))):
				return false
		elif kind == "draw_posted":
			var day := int(cause.get("day", -1))
			var draw := _dictionary(draws_by_day.get(str(day), {}))
			if subject_id != "draw:%d" % day or int(cause.get("action_index", -1)) != post_action(day) or not bool(draw.get("posted", false)) or int(draw.get("posted_action", -1)) != post_action(day):
				return false
			var expected_number := _three_digits(_stable_hash("%d:%d:crew_fix_number" % [seed_value, day]) % 1000) if bool(draw.get("fixed_by_crew", false)) else _derived_handle(day)
			if str(draw.get("number", "")) != expected_number:
				return false
			if not _dictionary_has_exact_keys(context, ["presence", "presence_cause_sequence"]) or str(context.get("presence", "")) not in ["present", "absent"]:
				return false
	return true


func _physical_slip_is_valid(slip: Dictionary) -> bool:
	var physical := _dictionary(slip.get("physical_state", {}))
	var keys := physical.keys()
	keys.sort()
	if keys != ["cause_sequence", "holder_id", "instance_id", "item_id", "last_action", "last_action_index", "node_id", "place_id", "possession", "schema_version", "state", "visibility"]:
		return false
	var cause_sequence := int(physical.get("cause_sequence", 0))
	if cause_sequence <= 0 or cause_sequence > depth_causes.size():
		return false
	var cause := _dictionary(depth_causes[cause_sequence - 1])
	if str(cause.get("subject_id", "")) != str(slip.get("id", "")) or str(cause.get("venue_id", "")) != str(slip.get("venue_id", "")) or str(cause.get("kind", "")) not in ["legacy_slip_projection", "slip_issued", "slip_confiscated"]:
		return false
	var expected_action := "legacy_projection" if str(cause.get("kind", "")) == "legacy_slip_projection" else "confiscated" if str(cause.get("kind", "")) == "slip_confiscated" else "issued"
	if str(physical.get("last_action", "")) != expected_action or int(physical.get("last_action_index", -1)) != int(cause.get("action_index", -2)):
		return false
	if int(physical.get("schema_version", 0)) != DEPTH_SCHEMA_VERSION or str(physical.get("item_id", "")) != "numbers_slips" or str(physical.get("instance_id", "")) != str(slip.get("id", "")) or str(physical.get("node_id", "")) != str(slip.get("venue_id", "")):
		return false
	var status := str(slip.get("status", ""))
	var holder := str(physical.get("holder_id", ""))
	var possession := str(physical.get("possession", ""))
	if str(physical.get("state", "")) != possession or str(physical.get("visibility", "")) not in ["visible", "hidden"]:
		return false
	if status == "confiscated":
		return holder == "police" and possession == "confiscated" and str(physical.get("place_id", "")) == "%s::numbers_book" % str(slip.get("venue_id", ""))
	return status in ["open", "settled"] and holder == "player" and possession == "carried" and str(physical.get("place_id", "")) == "player"


func _draw_occasions_are_valid() -> bool:
	var referenced: Dictionary = {}
	for day_value in draw_occasions.keys():
		var occasion := _dictionary(draw_occasions.get(day_value, {}))
		var day := int(day_value)
		if str(day) != str(day_value) or int(occasion.get("schema_version", 0)) != DEPTH_SCHEMA_VERSION or int(occasion.get("day", -1)) != day or int(occasion.get("post_action", -1)) != post_action(day):
			return false
		var cause_sequence := int(occasion.get("cause_sequence", 0))
		if cause_sequence <= 0 or cause_sequence > depth_causes.size():
			return false
		var cause := _dictionary(depth_causes[cause_sequence - 1])
		referenced[cause_sequence] = true
		var status := str(occasion.get("status", ""))
		if status == "registered":
			if not _dictionary_has_exact_keys(occasion, ["attendance", "cause_sequence", "day", "post_action", "presence", "schema_version", "status", "venue_id"]) or cause.keys().is_empty() or str(cause.get("kind", "")) != "draw_presence" or int(cause.get("day", -1)) != day or str(cause.get("venue_id", "")) != str(occasion.get("venue_id", "")) or action_index >= post_action(day) or str(occasion.get("presence", "")) != "present" or str(occasion.get("attendance", "")) != "present":
				return false
		else:
			if not _dictionary_has_exact_keys(occasion, ["attendance", "cause_sequence", "day", "post_action", "presence", "resolved_action", "schema_version", "status", "venue_id"]) or status not in ["witnessed", "missed"] or str(cause.get("kind", "")) != "draw_posted" or int(cause.get("day", -1)) != day or str(cause.get("venue_id", "")) != str(occasion.get("venue_id", "")) or int(occasion.get("resolved_action", -1)) != post_action(day):
				return false
			var presence := str(occasion.get("presence", ""))
			var posted_context := _dictionary(cause.get("context", {}))
			if presence != str(posted_context.get("presence", "")) or str(occasion.get("attendance", "")) != presence or status != ("witnessed" if presence == "present" else "missed"):
				return false
			var presence_sequence := int(posted_context.get("presence_cause_sequence", 0))
			if presence == "present":
				var presence_cause := _dictionary(depth_causes[presence_sequence - 1]) if presence_sequence > 0 and presence_sequence <= depth_causes.size() else {}
				if presence_sequence <= 0 or presence_sequence > depth_causes.size() or str(presence_cause.get("kind", "")) != "draw_presence" or int(presence_cause.get("day", -1)) != day or str(presence_cause.get("subject_id", "")) != "draw:%d" % day or str(presence_cause.get("venue_id", "")) != str(occasion.get("venue_id", "")):
					return false
				referenced[presence_sequence] = true
			elif presence_sequence != 0 or not str(occasion.get("venue_id", "")).is_empty():
				return false
	for cause_value in depth_causes:
		var cause := _dictionary(cause_value)
		if str(cause.get("kind", "")) in ["draw_presence", "draw_posted"] and not referenced.has(int(cause.get("sequence", 0))):
			return false
	return true


func _expected_bookmaker_aftermath() -> Dictionary:
	var result: Dictionary = {}
	for cause_value in depth_causes:
		var cause := _dictionary(cause_value)
		if str(cause.get("kind", "")) != "slip_settled":
			continue
		var slip := _slip_by_id(str(cause.get("subject_id", "")))
		var venue_id := str(slip.get("venue_id", ""))
		var memory := _dictionary(result.get(venue_id, {})).duplicate(true)
		if bool(slip.get("detected", false)):
			memory["suspicious"] = true
			memory["past_post_memory"] = true
			memory["last_public_event"] = "refusal"
		elif bool(slip.get("won", false)):
			memory["friendly"] = true
			memory["last_public_event"] = "winner"
		memory["last_day"] = int(slip.get("day", 0))
		var sequences := _int_array(memory.get("_cause_sequences", []))
		sequences.append(int(cause.get("sequence", 0)))
		memory["_cause_sequences"] = sequences
		result[venue_id] = memory
	return result


func _all_slip_causes_are_referenced() -> bool:
	var referenced: Dictionary = {}
	for slip_value in slips:
		var physical := _dictionary(_dictionary(slip_value).get("physical_state", {}))
		referenced[int(physical.get("cause_sequence", 0))] = true
	for memory_value in bookmaker_aftermath.values():
		for sequence in _int_array(_dictionary(memory_value).get("_cause_sequences", [])):
			referenced[int(sequence)] = true
	var changed := true
	while changed:
		changed = false
		for sequence_value in referenced.keys():
			var sequence := int(sequence_value)
			if sequence <= 0 or sequence > depth_causes.size():
				continue
			var previous := int(_dictionary(_dictionary(depth_causes[sequence - 1]).get("context", {})).get("previous_cause_sequence", 0))
			if previous > 0 and not referenced.has(previous):
				referenced[previous] = true
				changed = true
	for cause_value in depth_causes:
		var cause := _dictionary(cause_value)
		if (str(cause.get("kind", "")).begins_with("slip_") or str(cause.get("kind", "")) == "legacy_slip_projection") and not referenced.has(int(cause.get("sequence", 0))):
			return false
	return true


func _normalize_knowledge(value: Variant) -> Dictionary:
	var source := _dictionary(value)
	var result := {
		"staggered_close_rumor_ids": _string_array(source.get("staggered_close_rumor_ids", [])),
		"silas_tip": bool(source.get("silas_tip", false)),
		"assembled": false,
		"known_numbers_by_day": _dictionary(source.get("known_numbers_by_day", {})).duplicate(true),
	}
	knowledge = result
	_refresh_knowledge()
	return knowledge.duplicate(true)


func _normalize_allocations(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for venue_value in (value as Dictionary).keys():
		var venue_id := str(venue_value).strip_edges()
		var stake := maxi(0, int((value as Dictionary).get(venue_value, 0)))
		if stake > 0 and not venue_definition(venue_id).is_empty():
			result[venue_id] = stake
	return result


static func _normalize_digits(value: Variant) -> String:
	var text := str(value).strip_edges()
	if text.length() != 3:
		return ""
	for index in range(3):
		var code := text.unicode_at(index)
		if code < 48 or code > 57:
			return ""
	return text


static func _sorted_digits(value: String) -> String:
	var digits: Array = []
	for index in range(value.length()):
		digits.append(value.substr(index, 1))
	digits.sort()
	return "".join(digits)


static func _three_digits(value: int) -> String:
	return "%03d" % posmod(value, 1000)


func _derived_handle(day: int) -> String:
	var root := RngStreamScript.new()
	root.configure(seed_value, seed_value)
	var stream := root.fork("numbers_handle:day:%d:post_boundary" % maxi(0, day))
	return _three_digits(stream.randi_range(0, 999))


static func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


static func _dictionary_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value as Array:
		if typeof(entry_value) == TYPE_DICTIONARY:
			result.append((entry_value as Dictionary).duplicate(true))
	return result


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value as Array:
		var text := str(entry_value).strip_edges()
		if not text.is_empty() and not result.has(text):
			result.append(text)
	return result


static func _int_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value as Array:
		if typeof(entry_value) != TYPE_INT or int(entry_value) <= 0:
			return []
		result.append(int(entry_value))
	return result


static func _stable_hash(text: String) -> int:
	var hash_value := 2166136261
	for index in range(text.length()):
		hash_value = hash_value ^ text.unicode_at(index)
		hash_value = (hash_value * 16777619) & 0x7fffffff
	return maxi(1, hash_value)
