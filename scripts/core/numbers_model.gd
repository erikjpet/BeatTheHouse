class_name NumbersModel
extends RefCounted

const CONFIG_PATH := "res://data/crew/numbers.json"
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const SCHEMA_VERSION := 1
const DEPTH_SCHEMA_VERSION := 1
const PLAY_TYPES := ["straight", "box"]
const FIX_STATES := ["locked", "ready", "bribe_running", "camouflage", "payday", "completed", "aborted"]

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
var action_receipts: Dictionary = {}
var action_sequence: int = 0
var draw_occasions: Dictionary = {}
var bookmaker_aftermath: Dictionary = {}
var config: Dictionary = {}


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
	action_receipts = {}
	action_sequence = 0
	draw_occasions = {}
	bookmaker_aftermath = {}
	config = source_config.duplicate(true) if not source_config.is_empty() else tuning().duplicate(true)


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
		"action_receipts": action_receipts.duplicate(true),
		"action_sequence": action_sequence,
		"draw_occasions": draw_occasions.duplicate(true),
		"bookmaker_aftermath": bookmaker_aftermath.duplicate(true),
	}


func restore(source: Dictionary, p_seed_value: int, source_config: Dictionary = {}) -> bool:
	reset(p_seed_value, source_config)
	if int(source.get("schema_version", 0)) != SCHEMA_VERSION:
		return false
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
	action_receipts = _dictionary(source.get("action_receipts", {})).duplicate(true)
	action_sequence = maxi(0, int(source.get("action_sequence", action_receipts.size())))
	draw_occasions = _dictionary(source.get("draw_occasions", {})).duplicate(true)
	bookmaker_aftermath = _dictionary(source.get("bookmaker_aftermath", {})).duplicate(true)
	if not _receipt_chain_valid(action_receipts, action_sequence):
		reset(p_seed_value, source_config)
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


# Model-owned physical action seam. Receipt replay returns the original result;
# a reused key with different content is rejected without mutation.
func apply_action(receipt_key: String, action: String, context: Dictionary) -> Dictionary:
	var clean_key := receipt_key.strip_edges()
	var clean_action := action.strip_edges().to_lower()
	var envelope := {"action": clean_action, "context": _canonical_value(context)}
	var envelope_fingerprint := _fingerprint(envelope)
	var existing := _dictionary(action_receipts.get(clean_key, {}))
	if not existing.is_empty():
		return {"ok": true, "replayed": true, "receipt_key": clean_key} if str(existing.get("envelope_fingerprint", "")) == envelope_fingerprint else {"ok": false, "reason": "receipt_conflict"}
	if clean_key.is_empty():
		return {"ok": false, "reason": "receipt_required"}
	var result := _apply_depth_action(clean_action, context)
	if not bool(result.get("ok", false)):
		return result
	_record_depth_receipt(clean_key, clean_action, envelope_fingerprint, result)
	return result.duplicate(true)


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
		"physical_state": _new_physical_slip_state(slip_id, venue_id, "player", "carried", "visible"),
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
		slip["physical_state"] = _new_physical_slip_state(str(slip.get("id", "")), str(slip.get("venue_id", "")), "police", "confiscated", "hidden")
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
			"physical_state": _new_physical_slip_state(slip_id, venue_id, "player", "carried", "hidden"),
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
	if action in ["bookmaker_busy", "bookmaker_remember"]:
		var venue_id := str(context.get("venue_id", "")).strip_edges()
		if venue_definition(venue_id).is_empty(): return {"ok": false, "reason": "unknown_bookmaker"}
		var memory := _dictionary(bookmaker_aftermath.get(venue_id, {})).duplicate(true)
		if action == "bookmaker_busy":
			memory["busy"] = true
		else:
			var memory_id := str(context.get("memory_id", "")).strip_edges()
			if memory_id.is_empty(): return {"ok": false, "reason": "memory_required"}
			memory[memory_id] = true if memory_id != "visit_count" else int(memory.get(memory_id, 0)) + 1
		bookmaker_aftermath[venue_id] = memory
		return {"ok": true, "bookmaker": bookmaker_state(venue_id)}
	if action in ["fix_bribe_begin", "fix_bribe_resolve", "fix_camouflage_place", "fix_camouflage_commit"]:
		if action == "fix_bribe_begin": return fix_begin_bribe()
		if action == "fix_bribe_resolve": return fix_record_bribe(bool(context.get("success", false)), {"clean": bool(context.get("clean", false)), "fast": bool(context.get("fast", false))})
		if action == "fix_camouflage_place":
			if str(fix_state.get("status", "")) != "camouflage": return {"ok": false, "reason": "camouflage_not_ready"}
			var venue_id := str(context.get("venue_id", "")).strip_edges()
			var stake := int(context.get("stake", 0))
			if venue_definition(venue_id).is_empty() or stake <= 0: return {"ok": false, "reason": "invalid_camouflage_slip"}
			var staged := _dictionary(fix_state.get("staged_allocations", {})).duplicate(true)
			staged[venue_id] = stake
			fix_state["staged_allocations"] = staged
			return {"ok": true, "venue_id": venue_id, "stake": stake}
		var allocations := _dictionary(fix_state.get("staged_allocations", {})).duplicate(true)
		var committed := fix_allocate(allocations)
		if bool(committed.get("ok", false)): fix_state.erase("staged_allocations")
		return committed
	if action in ["draw_present", "draw_absent"]:
		var day := maxi(0, int(context.get("day", day_at(action_index))))
		if action_index < post_action(day):
			return {"ok": false, "reason": "draw_not_posted"}
		var venue_id := str(context.get("venue_id", "")).strip_edges()
		if action == "draw_present" and venue_definition(venue_id).is_empty():
			return {"ok": false, "reason": "bookmaker_place_required"}
		var occasion := {
			"schema_version": DEPTH_SCHEMA_VERSION,
			"day": day,
			"status": "witnessed" if action == "draw_present" else "missed",
			"presence": "present" if action == "draw_present" else "absent",
			"attendance": "present" if action == "draw_present" else "absent",
			"venue_id": venue_id if action == "draw_present" else "",
			"post_action": post_action(day),
			"registered_action": action_index,
			"resolved_action": post_action(day),
		}
		draw_occasions[str(day)] = occasion
		return {"ok": true, "occasion": draw_occasion_status(day)}
	if action in ["slip_show", "slip_hide", "slip_hand", "slip_move", "slip_lose", "slip_collect"]:
		var slip_id := str(context.get("slip_id", "")).strip_edges()
		var index := _slip_index(slip_id)
		if index < 0:
			return {"ok": false, "reason": "unknown_slip"}
		var slip := _dictionary(slips[index])
		var physical := _physical_slip_state(slip)
		var requested_node := str(context.get("node_id", "")).strip_edges()
		if requested_node.is_empty() or requested_node != str(physical.get("node_id", "")):
			return {"ok": false, "reason": "slip_not_here"}
		if action == "slip_show":
			physical["visibility"] = "visible"
			physical["state"] = "shown"
		elif action == "slip_hide":
			physical["visibility"] = "hidden"
			physical["state"] = "hidden"
		elif action == "slip_hand" or action == "slip_move":
			var node_id := requested_node
			var place_id := str(context.get("place_id", physical.get("place_id", ""))).strip_edges()
			var holder_id := str(context.get("holder_id", "")).strip_edges()
			if node_id.is_empty() or holder_id.is_empty():
				return {"ok": false, "reason": "physical_destination_required"}
			physical["node_id"] = node_id
			physical["place_id"] = place_id
			physical["holder_id"] = holder_id
			physical["possession"] = "held"
			physical["state"] = "handed"
		elif action == "slip_lose":
			if str(slip.get("status", "")) != "open":
				return {"ok": false, "reason": "slip_not_open"}
			slip["status"] = "lost"
			physical["holder_id"] = ""
			physical["possession"] = "lost"
			physical["state"] = "lost"
			physical["visibility"] = "hidden"
			physical["place_id"] = str(context.get("place_id", physical.get("place_id", ""))).strip_edges()
		elif action == "slip_collect":
			if str(slip.get("status", "")) != "settled" or not bool(slip.get("won", false)) or int(slip.get("payout", 0)) <= 0:
				return {"ok": false, "reason": "winning_settlement_required"}
			var venue_id := str(slip.get("venue_id", ""))
			if str(context.get("venue_id", venue_id)) != venue_id:
				return {"ok": false, "reason": "wrong_bookmaker"}
			slip["status"] = "collected"
			slip["collected_action"] = action_index
			physical["holder_id"] = "numbers_bookmaker_%s" % venue_id
			physical["node_id"] = venue_id
			physical["place_id"] = "%s::numbers_book" % venue_id
			physical["possession"] = "redeemed"
			physical["state"] = "collected"
			_record_collection_aftermath(slip)
		physical["last_action"] = action
		physical["last_action_index"] = action_index
		slip["physical_state"] = physical
		slips[index] = slip
		return {"ok": true, "slip": slip_public_state(slip_id)}
	return {"ok": false, "reason": "unsupported_action"}


func _resolve_draw_occasion(day: int, boundary: int) -> void:
	var occasion := _dictionary(draw_occasions.get(str(day), {})).duplicate(true)
	if occasion.is_empty():
		occasion = {"schema_version": DEPTH_SCHEMA_VERSION, "day": day, "presence": "absent", "attendance": "absent", "venue_id": "", "post_action": boundary}
	occasion["status"] = "witnessed" if str(occasion.get("presence", "absent")) == "present" else "missed"
	occasion["resolved_action"] = boundary
	draw_occasions[str(day)] = occasion


func _record_depth_receipt(receipt_key: String, action: String, envelope_fingerprint: String, _result: Dictionary) -> void:
	action_sequence += 1
	var previous := "0".repeat(64)
	for receipt_value in action_receipts.values():
		var receipt := _dictionary(receipt_value)
		if int(receipt.get("sequence", 0)) == action_sequence - 1:
			previous = str(receipt.get("receipt_fingerprint", ""))
			break
	var receipt := {
		"schema_version": DEPTH_SCHEMA_VERSION,
		"receipt_key": receipt_key,
		"action": action,
		"sequence": action_sequence,
		"envelope_fingerprint": envelope_fingerprint,
		"previous_receipt_fingerprint": previous,
	}
	receipt["receipt_fingerprint"] = _fingerprint(receipt)
	action_receipts[receipt_key] = receipt


func _receipt_chain_valid(receipts: Dictionary, sequence_total: int) -> bool:
	if sequence_total != receipts.size():
		return false
	var by_sequence: Dictionary = {}
	var exact_keys := ["action", "envelope_fingerprint", "previous_receipt_fingerprint", "receipt_fingerprint", "receipt_key", "schema_version", "sequence"]
	for key_value in receipts.keys():
		var receipt := _dictionary(receipts.get(key_value, {}))
		var keys: Array = receipt.keys()
		keys.sort()
		if keys != exact_keys or str(key_value) != str(receipt.get("receipt_key", "")) or int(receipt.get("schema_version", 0)) != DEPTH_SCHEMA_VERSION:
			return false
		for digest_key in ["envelope_fingerprint", "previous_receipt_fingerprint", "receipt_fingerprint"]:
			if not _is_sha256(str(receipt.get(digest_key, ""))): return false
		var body := receipt.duplicate(true)
		var stored := str(body.get("receipt_fingerprint", ""))
		body.erase("receipt_fingerprint")
		if stored != _fingerprint(body): return false
		var sequence := int(receipt.get("sequence", 0))
		if sequence <= 0 or by_sequence.has(sequence): return false
		by_sequence[sequence] = receipt
	for sequence in range(1, sequence_total + 1):
		if not by_sequence.has(sequence): return false
		var expected := "0".repeat(64) if sequence == 1 else str(_dictionary(by_sequence.get(sequence - 1, {})).get("receipt_fingerprint", ""))
		if str(_dictionary(by_sequence.get(sequence, {})).get("previous_receipt_fingerprint", "")) != expected: return false
	return true


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
		slips[index] = slip
		_record_settlement_aftermath(slip)
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
	return _new_physical_slip_state(str(slip.get("id", "")), str(slip.get("venue_id", "")), "player", "carried" if status in ["open", "settled"] else status, "visible")


func _new_physical_slip_state(slip_id: String, node_id: String, holder_id: String, possession: String, visibility: String) -> Dictionary:
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
	}


func _record_settlement_aftermath(slip: Dictionary) -> void:
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


static func _fingerprint(value: Variant) -> String:
	return JSON.stringify(_canonical_value(value)).sha256_text()


static func _canonical_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		var keys: Array = (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key_value in keys: result[str(key_value)] = _canonical_value((value as Dictionary).get(key_value))
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for entry in value as Array: result.append(_canonical_value(entry))
		return result
	return value


static func _is_sha256(value: String) -> bool:
	if value.length() != 64 or value != value.to_lower(): return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102): return false
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


static func _stable_hash(text: String) -> int:
	var hash_value := 2166136261
	for index in range(text.length()):
		hash_value = hash_value ^ text.unicode_at(index)
		hash_value = (hash_value * 16777619) & 0x7fffffff
	return maxi(1, hash_value)
