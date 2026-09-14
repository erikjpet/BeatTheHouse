class_name PoliceSweepModel
extends RefCounted

const SCHEMA_VERSION := 2
const LEGACY_SCHEMA_VERSION := 1
const ENCOUNTER_TOMBSTONE_LIMIT := 16
const ENCOUNTER_PROPOSAL_SCHEMA_VERSION := 1
const ENCOUNTER_AUTHORITY_GAP := "host_encounter_resolution_not_verifiable_in_model"
const INTEL_AUTHORITY_GAP := "host_sweep_intel_capability_not_verifiable_in_model"
const ENCOUNTER_OUTCOMES := ["pass_over", "shakedown", "confiscation", "travel_lock", "punchline_l2_near_miss"]
const GRAND_CASINO_IDS := [
	"grand_casino",
	"grand_casino_high_limit",
	"grand_casino_back_room",
	"grand_casino_cage",
]

var seed_value: int = 1
var action_index: int = 0
var configured: bool = false
var disabled: bool = false
var start_action: int = 0
var end_action: int = 0
var segments: Array = []
var segment_index: int = -1
var swept_windows_by_node: Dictionary = {}
var personal_marker: Dictionary = {}
var last_encounter_segment: int = -1
var last_encounter_node_id: String = ""
var last_adjacent_sighting_segment: int = -1
var config: Dictionary = {}
var reroute_history: Array = []
var encounter_tombstones: Array = []

var _host_capability: RefCounted

var _node_metadata: Dictionary = {}
var _neighbors_by_node: Dictionary = {}


func reset(p_seed_value: int, source_config: Dictionary = {}) -> void:
	seed_value = maxi(1, p_seed_value)
	action_index = 0
	configured = false
	disabled = false
	start_action = 0
	end_action = 0
	segments = []
	segment_index = -1
	swept_windows_by_node = {}
	personal_marker = {}
	last_encounter_segment = -1
	last_encounter_node_id = ""
	last_adjacent_sighting_segment = -1
	config = source_config.duplicate(true)
	reroute_history = []
	encounter_tombstones = []
	_node_metadata = {}
	_neighbors_by_node = {}


func bind_host_capability(capability: RefCounted) -> bool:
	if capability == null or _host_capability != null:
		return false
	_host_capability = capability
	return true


func _host_authorized(candidate: Variant) -> bool:
	return typeof(candidate) == TYPE_OBJECT and candidate != null and is_instance_valid(candidate) and candidate == _host_capability


func disable(p_seed_value: int, source_config: Dictionary = {}) -> void:
	reset(p_seed_value, source_config)
	disabled = true
	configured = true


func configure_world(map_data: Dictionary, happening: Dictionary, source_config: Dictionary, current_action: int) -> void:
	action_index = maxi(0, current_action)
	config = source_config.duplicate(true)
	_index_world(map_data)
	if disabled:
		configured = true
		return
	if configured and not segments.is_empty():
		_sync_segment_index()
		return
	if happening.is_empty() or _eligible_node_ids().is_empty():
		return
	configured = true
	start_action = maxi(0, int(happening.get("start_action", 0)))
	end_action = maxi(start_action + 1, int(happening.get("end_action", start_action + 1)))
	_generate_segments()
	_sync_segment_index()
	var current := status()
	if bool(current.get("active", false)) and not last_encounter_node_id.is_empty() and str(current.get("current_node_id", "")) != last_encounter_node_id:
		last_encounter_node_id = ""


func advance_to(next_action_index: int) -> Array:
	var target := maxi(action_index, next_action_index)
	var departures: Array = []
	if disabled or segments.is_empty():
		action_index = target
		return departures
	var previous_index := segment_index
	action_index = target
	_sync_segment_index()
	var current := status()
	if bool(current.get("active", false)) and not last_encounter_node_id.is_empty() and str(current.get("current_node_id", "")) != last_encounter_node_id:
		last_encounter_node_id = ""
	if segment_index > previous_index:
		for index in range(maxi(0, previous_index), segment_index):
			if index < 0 or index >= segments.size():
				continue
			var segment: Dictionary = segments[index]
			var node_id := str(segment.get("node_id", ""))
			var departed_action := int(segment.get("end_action", action_index))
			var window_actions := maxi(1, int(config.get("swept_window_actions", 5)))
			var window := {
				"node_id": node_id,
				"start_action": departed_action,
				"end_action": departed_action + window_actions,
				"source_segment_index": index,
			}
			swept_windows_by_node[node_id] = window
			departures.append(window.duplicate(true))
	_prune_windows()
	return departures


func status() -> Dictionary:
	if disabled or segments.is_empty() or segment_index < 0 or segment_index >= segments.size():
		return {}
	var segment: Dictionary = segments[segment_index]
	var active := action_index >= start_action and action_index < end_action
	return {
		"spawned": true,
		"active": active,
		"current_node_id": str(segment.get("node_id", "")) if active else "",
		"previous_node_id": str(segments[segment_index - 1].get("node_id", "")) if active and segment_index > 0 else "",
		"heading_node_id": str(segments[segment_index + 1].get("node_id", "")) if active and segment_index + 1 < segments.size() else "",
		"arrived_action": int(segment.get("start_action", start_action)),
		"next_move_action": int(segment.get("end_action", end_action)),
		"start_action": start_action,
		"end_action": end_action,
		"segment_index": segment_index,
	}


func intel_status(host_capability: Variant = null, intel_enabled: bool = false) -> Dictionary:
	if not _host_authorized(host_capability) or not intel_enabled:
		return {"available": false, "authority_gap": INTEL_AUTHORITY_GAP}
	var current := status()
	if not bool(current.get("active", false)):
		return {"available": false, "observed": false, "live": false}
	return {
		"available": true,
		"active": true,
		"observed": true,
		"live": true,
		"current_node_id": str(current.get("current_node_id", "")),
		"heading_node_id": str(current.get("heading_node_id", "")),
		"moves_in_actions": maxi(0, int(current.get("next_move_action", action_index)) - action_index),
	}


func report_intel_at_boundary(host_capability: Variant = null, intel_enabled: bool = false, source: String = "crew_intel") -> Dictionary:
	var intel := intel_status(host_capability, intel_enabled)
	if not bool(intel.get("available", false)):
		return intel
	personal_marker = {
		"node_id": str(intel.get("current_node_id", "")),
		"heading_node_id": str(intel.get("heading_node_id", "")),
		"sighted_action": action_index,
		"source": source if source in ["crew_intel", "direct", "adjacent"] else "crew_intel",
		"segment_index": segment_index,
	}
	return map_marker(host_capability, intel_enabled)


func map_marker(host_capability: Variant = null, intel_enabled: bool = false) -> Dictionary:
	if personal_marker.is_empty():
		return {}
	if not _host_authorized(host_capability) or not intel_enabled:
		return {"observed": true, "live": false, "available": false, "authority_gap": INTEL_AUTHORITY_GAP}
	var live := int(personal_marker.get("segment_index", -1)) == segment_index and bool(status().get("active", false))
	return {
		"available": true,
		"observed": true,
		"live": live,
		"node_id": str(personal_marker.get("node_id", "")),
		"heading_node_id": str(personal_marker.get("heading_node_id", "")),
		"sighted_action": maxi(0, int(personal_marker.get("sighted_action", action_index))),
		"stale_actions": maxi(0, action_index - int(personal_marker.get("sighted_action", action_index))),
		"source": str(personal_marker.get("source", "crew_intel")),
	}


func record_personal_sighting(source: String = "direct", host_capability: Variant = null) -> Dictionary:
	if not _host_authorized(host_capability):
		return {}
	var current := status()
	if not bool(current.get("active", false)):
		return {}
	personal_marker = {
		"node_id": str(current.get("current_node_id", "")),
		"heading_node_id": str(current.get("heading_node_id", "")),
		"sighted_action": action_index,
		"source": source,
		"segment_index": int(current.get("segment_index", -1)),
	}
	return map_marker(host_capability, true)


func is_at(node_id: String) -> bool:
	var current := status()
	return bool(current.get("active", false)) and str(current.get("current_node_id", "")) == node_id.strip_edges()


func is_adjacent(node_id: String) -> bool:
	var current := status()
	if not bool(current.get("active", false)):
		return false
	return _string_array(_neighbors_by_node.get(str(current.get("current_node_id", "")), [])).has(node_id.strip_edges())


func adjacent_sighting_due(player_node_id: String) -> bool:
	if not is_adjacent(player_node_id):
		return false
	var current := status()
	var current_segment := int(current.get("segment_index", -1))
	if current_segment < 0 or current_segment == last_adjacent_sighting_segment:
		return false
	var chance := clampi(int(config.get("adjacent_sighting_chance_percent", 35)), 0, 100)
	var roll := (_stable_hash("%d:%s:%d:adjacent" % [seed_value, player_node_id, current_segment]) % 100) + 1
	if roll > chance:
		return false
	last_adjacent_sighting_segment = current_segment
	return true


func claim_encounter(node_id: String, host_capability: Variant = null) -> Dictionary:
	if not _host_authorized(host_capability):
		return {}
	if not is_at(node_id):
		return {}
	var current := status()
	var current_segment := int(current.get("segment_index", -1))
	if current_segment < 0 or current_segment == last_encounter_segment or node_id.strip_edges() == last_encounter_node_id:
		return {}
	last_encounter_segment = current_segment
	last_encounter_node_id = node_id.strip_edges()
	return {
		"segment_index": current_segment,
		"node_id": node_id.strip_edges(),
		"action_index": action_index,
		"encounter_seed": _stable_hash("%d:%d:sweep_encounter" % [seed_value, current_segment]),
		"sweep_departure_action": int(current.get("next_move_action", action_index + 1)),
	}


func swept_window(node_id: String) -> Dictionary:
	var window := _dictionary(swept_windows_by_node.get(node_id.strip_edges(), {}))
	if window.is_empty() or action_index < int(window.get("start_action", 0)) or action_index >= int(window.get("end_action", 0)):
		return {}
	var result := window.duplicate(true)
	result["remaining_actions"] = maxi(0, int(window.get("end_action", action_index)) - action_index)
	result["security_strictness_band_delta"] = -1
	result["cheat_window_open"] = true
	result["pusher_alarm_tolerance_band_delta"] = 1
	return result


# Presentation-only encounter seam. The model can bind this proposal to its
# current track claim, but RunState remains the owner of every economic effect.
func encounter_proposal(claim: Dictionary, cargo_value: Variant, exit_node_ids: Array, host_capability: Variant = null, intel_enabled: bool = false) -> Dictionary:
	if not _encounter_claim_matches_current(claim):
		return {}
	var cargo := _cargo_public_context(cargo_value)
	var exits := _string_array(exit_node_ids)
	exits.sort()
	var unique_exits: Array = []
	for exit_id in exits:
		if exit_id != str(claim.get("node_id", "")) and not unique_exits.has(exit_id): unique_exits.append(exit_id)
	var proposal := {
		"schema_version": ENCOUNTER_PROPOSAL_SCHEMA_VERSION,
		"phase": "arrival_proposal",
		"officer_presence": "street_control",
		"positions": {"officers": "blocking_route", "player": "street_approach", "cargo": "carried" if bool(cargo.get("active", false)) else "none"},
		"exit_node_ids": unique_exits,
		"cargo_context": cargo,
		"intel_projection": map_marker(host_capability, intel_enabled),
		"costed_rungs": encounter_costed_rungs(_dictionary(config.get("encounter", {}))),
		"authoritative": false,
		"can_mutate": false,
		"authority_gap": ENCOUNTER_AUTHORITY_GAP,
	}
	if (proposal["intel_projection"] as Dictionary).is_empty():
		proposal["intel_projection"] = intel_status(host_capability, intel_enabled)
	return proposal


static func normalize_encounter_proposal(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY: return {}
	var proposal: Dictionary = (value as Dictionary).duplicate(true)
	if not _exact_keys(proposal, ["authoritative", "authority_gap", "can_mutate", "cargo_context", "costed_rungs", "exit_node_ids", "intel_projection", "officer_presence", "phase", "positions", "schema_version"]): return {}
	if int(proposal.get("schema_version", 0)) != ENCOUNTER_PROPOSAL_SCHEMA_VERSION or bool(proposal.get("authoritative", true)) or bool(proposal.get("can_mutate", true)) or str(proposal.get("authority_gap", "")) != ENCOUNTER_AUTHORITY_GAP: return {}
	if str(proposal.get("phase", "")) != "arrival_proposal" or str(proposal.get("officer_presence", "")) != "street_control": return {}
	if not _cargo_context_valid(proposal.get("cargo_context")) or not _intel_projection_valid(proposal.get("intel_projection")) or not _positions_valid(proposal.get("positions")) or not _rungs_valid(proposal.get("costed_rungs")): return {}
	var exits := _string_array(proposal.get("exit_node_ids", []))
	var sorted := exits.duplicate(); sorted.sort()
	if exits != sorted or exits.size() != _unique_strings(exits).size(): return {}
	var normalized := {
		"schema_version": ENCOUNTER_PROPOSAL_SCHEMA_VERSION,
		"phase": "arrival_proposal",
		"officer_presence": "street_control",
		"positions": (proposal.get("positions", {}) as Dictionary).duplicate(true),
		"exit_node_ids": exits,
		"cargo_context": (proposal.get("cargo_context", {}) as Dictionary).duplicate(true),
		"intel_projection": _normalized_intel_projection(proposal.get("intel_projection", {})),
		"costed_rungs": _normalized_rungs(proposal.get("costed_rungs", [])),
		"authoritative": false,
		"can_mutate": false,
		"authority_gap": ENCOUNTER_AUTHORITY_GAP,
	}
	return normalized


static func encounter_action_proposal(state_value: Variant, action: String) -> Dictionary:
	var state := normalize_encounter_proposal(state_value)
	var clean_action := action.strip_edges().to_lower()
	if state.is_empty() or clean_action not in ["observe_officers", "use_intel", "choose_exit", "comply"]: return {}
	var intel := _dictionary(state.get("intel_projection", {}))
	if clean_action == "use_intel" and not bool(intel.get("available", false)): return {}
	var result := {
		"action": clean_action,
		"current_phase": "arrival_proposal",
		"next_phase_proposal": "route_choice_proposal" if clean_action in ["observe_officers", "use_intel"] else "host_resolution_required",
		"authoritative": false,
		"can_mutate": false,
		"authority_gap": ENCOUNTER_AUTHORITY_GAP,
	}
	if clean_action == "use_intel":
		var exits := _string_array(state.get("exit_node_ids", []))
		var heading := str(intel.get("heading_node_id", ""))
		for exit_id in exits:
			if exit_id != heading:
				result["recommended_exit_id"] = exit_id
				break
	return result


static func encounter_public_state(state_value: Variant) -> Dictionary:
	var state := normalize_encounter_proposal(state_value)
	if state.is_empty(): return {}
	return {
		"phase": str(state.get("phase", "")),
		"officer_presence": str(state.get("officer_presence", "")), "positions": (state.get("positions", {}) as Dictionary).duplicate(true),
		"exit_node_ids": (state.get("exit_node_ids", []) as Array).duplicate(), "cargo_context": (state.get("cargo_context", {}) as Dictionary).duplicate(true),
		"intel_projection": (state.get("intel_projection", {}) as Dictionary).duplicate(true), "costed_rungs": (state.get("costed_rungs", []) as Array).duplicate(true),
		"authoritative": false, "can_mutate": false, "authority_gap": ENCOUNTER_AUTHORITY_GAP,
	}


static func aftermath_proposal(state_value: Variant, outcome: String, cost_kind: String, cost_amount: int) -> Dictionary:
	var state := normalize_encounter_proposal(state_value)
	var clean_outcome := outcome.strip_edges().to_lower()
	var clean_cost := cost_kind.strip_edges().to_lower()
	if state.is_empty() or not _cost_matches_rung(state.get("costed_rungs", []), clean_outcome, clean_cost, cost_amount): return {}
	var cargo: Dictionary = state.get("cargo_context", {})
	return {
		"phase": "aftermath_proposal",
		"outcome": clean_outcome, "cost_kind": clean_cost, "cost_amount": cost_amount, "run_continues": true,
		"cargo_consequence": "host_may_confiscate_delivery" if clean_cost == "contraband" and bool(cargo.get("active", false)) else "none",
		"officer_presence": "departing", "wake_expected": true,
		"authoritative": false, "can_mutate": false, "authority_gap": ENCOUNTER_AUTHORITY_GAP,
	}


func swept_window_aftermath(node_id: String) -> Dictionary:
	var window := swept_window(node_id)
	if window.is_empty(): return {}
	return {
		"node_id": str(window.get("node_id", "")), "phase": "swept_window", "officer_presence": "departed", "remaining_actions": int(window.get("remaining_actions", 0)),
		"security_strictness_band_delta": int(window.get("security_strictness_band_delta", 0)), "cheat_window_open": bool(window.get("cheat_window_open", false)),
		"pusher_alarm_tolerance_band_delta": int(window.get("pusher_alarm_tolerance_band_delta", 0)), "visible_cues": ["fresh_tire_tracks", "street_reopening"],
	}


func record_encounter_resolution(host_capability: Variant, claim: Dictionary, outcome: String, cost_kind: String, cost_amount: int) -> Dictionary:
	var rungs := encounter_costed_rungs(_dictionary(config.get("encounter", {})))
	var validation_kind := "cash" if cost_kind == "street_debt" else cost_kind
	var cost_valid := _cost_matches_rung(rungs, outcome, validation_kind, cost_amount)
	if not cost_valid and validation_kind == "cash" and cost_amount >= 0:
		for rung_value in rungs:
			var rung := _dictionary(rung_value)
			if str(rung.get("outcome", "")) != outcome: continue
			for option_value in _dictionary_array(rung.get("cost_options", [])):
				var option := _dictionary(option_value)
				var amount_range: Array = (option.get("amount_range", []) as Array).duplicate() if typeof(option.get("amount_range", [])) == TYPE_ARRAY else []
				if str(option.get("cost_kind", "")) == "cash" and amount_range.size() == 2 and cost_amount <= int(amount_range[1]): cost_valid = true
	if not _host_authorized(host_capability) or not _encounter_claim_matches_current(claim) \
			or outcome not in ENCOUNTER_OUTCOMES or not cost_valid:
		return {}
	var tombstone := {
		"segment_index": int(claim.get("segment_index", -1)),
		"node_id": str(claim.get("node_id", "")),
		"action_index": int(claim.get("action_index", action_index)),
		"outcome": outcome,
		"cost_kind": cost_kind,
		"cost_amount": maxi(0, cost_amount),
	}
	for existing_value in encounter_tombstones:
		var existing := _dictionary(existing_value)
		if int(existing.get("segment_index", -2)) == int(tombstone.get("segment_index", -1)):
			return existing.duplicate(true) if existing == tombstone else {}
	encounter_tombstones.append(tombstone)
	while encounter_tombstones.size() > ENCOUNTER_TOMBSTONE_LIMIT:
		encounter_tombstones.pop_front()
	return tombstone.duplicate(true)


static func encounter_costed_rungs(encounter_config: Dictionary) -> Array:
	return [
		_rung("pass_over", "brief_check", [["cash", _int_range(encounter_config.get("pass_over_fee", [2, 6]), 2, 6)], ["travel_delay", [maxi(1, int(encounter_config.get("pass_over_fallback_lock_actions", 1))), maxi(1, int(encounter_config.get("pass_over_fallback_lock_actions", 1)))]]]),
		_rung("shakedown", "street_search", [["cash", _int_range(encounter_config.get("shakedown_fee", [10, 28]), 10, 28)], ["travel_delay", [maxi(1, int(encounter_config.get("shakedown_fallback_lock_actions", 1))), maxi(1, int(encounter_config.get("shakedown_fallback_lock_actions", 1)))]]]),
		_rung("confiscation", "cargo_search", [["contraband", [1, 1]], ["cash", _int_range(encounter_config.get("empty_confiscation_fee", [8, 16]), 8, 16)], ["travel_delay", [maxi(1, int(encounter_config.get("empty_confiscation_fallback_lock_actions", 2))), maxi(1, int(encounter_config.get("empty_confiscation_fallback_lock_actions", 2)))]]]),
		_rung("travel_lock", "road_block", [["travel_delay", _int_range(encounter_config.get("travel_lock_actions", [2, 4]), 2, 4)], ["cash", _int_range(encounter_config.get("occupied_lock_fine", [6, 12]), 6, 12)]]),
		_rung("punchline_l2_near_miss", "layer_two_near_miss", [["travel_delay", [maxi(1, int(encounter_config.get("punchline_near_miss_lock_actions", 2))), maxi(1, int(encounter_config.get("punchline_near_miss_lock_actions", 2)))]], ["cash", _int_range(encounter_config.get("occupied_lock_fine", [6, 12]), 6, 12)]])
	]


# Narrow landed-consumer seam: deterministically rewrites future segments along
# the graph toward one eligible target. Current/past segments never move.
func request_reroute_toward(candidate_ids: Array, request_token: String) -> Dictionary:
	var current := status()
	var request := {
		"token": request_token.strip_edges(),
		"requested_action": action_index,
		"from_node_id": str(current.get("current_node_id", "")),
		"target_node_id": "",
		"path": [],
		"applied_segment_indices": [],
		"applied": false,
	}
	if disabled or not bool(current.get("active", false)) or segment_index + 1 >= segments.size():
		reroute_history.append(request)
		return request.duplicate(true)
	var resolved_candidates: Array = []
	for candidate_value in candidate_ids:
		var candidate := str(candidate_value).strip_edges()
		for node_id_value in _node_metadata.keys():
			var node_id := str(node_id_value)
			var metadata := _dictionary(_node_metadata.get(node_id, {}))
			if node_id == candidate or str(metadata.get("archetype_id", "")) == candidate:
				if not resolved_candidates.has(node_id) and node_id != str(current.get("current_node_id", "")):
					resolved_candidates.append(node_id)
	resolved_candidates.sort()
	if resolved_candidates.is_empty():
		reroute_history.append(request)
		return request.duplicate(true)
	var token := request_token.strip_edges()
	var target := str(resolved_candidates[_stable_hash("%d:%s:numbers_reroute" % [seed_value, token]) % resolved_candidates.size()])
	var path := _shortest_path(str(current.get("current_node_id", "")), target)
	request["target_node_id"] = target
	request["path"] = path.duplicate()
	if path.size() < 2:
		reroute_history.append(request)
		return request.duplicate(true)
	var applied_indices: Array = []
	for path_index in range(1, path.size()):
		var future_index := segment_index + path_index
		if future_index >= segments.size():
			break
		var segment := _dictionary(segments[future_index]).duplicate(true)
		segment["node_id"] = str(path[path_index])
		segment["reroute_token"] = token
		segments[future_index] = segment
		applied_indices.append(future_index)
	request["applied_segment_indices"] = applied_indices
	request["applied"] = not applied_indices.is_empty()
	reroute_history.append(request)
	return request.duplicate(true)


func scenario_pressure_multiplier(node_id: String, scenario_id: String, tags: Array) -> float:
	if GRAND_CASINO_IDS.has(node_id) or not is_adjacent(node_id):
		return 1.0
	var pressure := _dictionary(config.get("adjacent_scenario_pressure", {}))
	var multiplier := 1.0
	var by_id := _dictionary(pressure.get("scenario_weight_by_id", {}))
	multiplier *= float(by_id.get(scenario_id, 1.0))
	var by_tag := _dictionary(pressure.get("scenario_weight_by_tag", {}))
	for tag_value in tags:
		multiplier *= float(by_tag.get(str(tag_value), 1.0))
	return maxf(0.0, multiplier)


func snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"seed_value": seed_value,
		"action_index": action_index,
		"configured": configured,
		"disabled": disabled,
		"start_action": start_action,
		"end_action": end_action,
		"segments": segments.duplicate(true),
		"segment_index": segment_index,
		"swept_windows_by_node": swept_windows_by_node.duplicate(true),
		"personal_marker": personal_marker.duplicate(true),
		"last_encounter_segment": last_encounter_segment,
		"last_encounter_node_id": last_encounter_node_id,
		"last_adjacent_sighting_segment": last_adjacent_sighting_segment,
		"config": config.duplicate(true),
		"reroute_history": reroute_history.duplicate(true),
		"encounter_tombstones": encounter_tombstones.duplicate(true),
	}


func restore(source: Dictionary, p_seed_value: int, source_config: Dictionary = {}) -> bool:
	reset(p_seed_value, source_config)
	var version := int(source.get("schema_version", 0))
	var legacy_keys := ["schema_version", "seed_value", "action_index", "configured", "disabled", "start_action", "end_action", "segments", "segment_index", "swept_windows_by_node", "personal_marker", "last_encounter_segment", "last_encounter_node_id", "last_adjacent_sighting_segment", "config", "reroute_history"]
	var current_keys := legacy_keys.duplicate(); current_keys.append("encounter_tombstones")
	if version not in [LEGACY_SCHEMA_VERSION, SCHEMA_VERSION] or not _exact_keys(source, legacy_keys if version == LEGACY_SCHEMA_VERSION else current_keys):
		disable(p_seed_value, source_config)
		return false
	seed_value = maxi(1, int(source.get("seed_value", p_seed_value)))
	action_index = maxi(0, int(source.get("action_index", 0)))
	configured = bool(source.get("configured", false))
	disabled = bool(source.get("disabled", false))
	start_action = maxi(0, int(source.get("start_action", 0)))
	end_action = maxi(start_action, int(source.get("end_action", start_action)))
	segments = _dictionary_array(source.get("segments", []))
	segment_index = int(source.get("segment_index", -1))
	swept_windows_by_node = _dictionary(source.get("swept_windows_by_node", {})).duplicate(true)
	personal_marker = _dictionary(source.get("personal_marker", {})).duplicate(true)
	last_encounter_segment = int(source.get("last_encounter_segment", -1))
	last_encounter_node_id = str(source.get("last_encounter_node_id", ""))
	last_adjacent_sighting_segment = int(source.get("last_adjacent_sighting_segment", -1))
	config = _dictionary(source.get("config", source_config)).duplicate(true)
	reroute_history = _dictionary_array(source.get("reroute_history", []))
	encounter_tombstones = []
	for tombstone_value in _dictionary_array(source.get("encounter_tombstones", [])):
		var tombstone := _normalize_encounter_tombstone(tombstone_value)
		if tombstone.is_empty() or encounter_tombstones.size() >= ENCOUNTER_TOMBSTONE_LIMIT:
			disable(p_seed_value, source_config)
			return false
		encounter_tombstones.append(tombstone)
	_sync_segment_index()
	_prune_windows()
	return true


static func _normalize_encounter_tombstone(value: Dictionary) -> Dictionary:
	if not _exact_keys(value, ["action_index", "cost_amount", "cost_kind", "node_id", "outcome", "segment_index"]): return {}
	if str(value.get("node_id", "")).is_empty() or str(value.get("outcome", "")) not in ENCOUNTER_OUTCOMES \
			or str(value.get("cost_kind", "")) not in ["cash", "contraband", "travel_delay", "street_debt"] \
			or int(value.get("segment_index", -1)) < 0 or int(value.get("action_index", -1)) < 0 or int(value.get("cost_amount", -1)) < 0:
		return {}
	return value.duplicate(true)


func align_restored_action_index(restored_action_index: int) -> void:
	action_index = maxi(0, restored_action_index)
	_sync_segment_index()
	for node_id_value in swept_windows_by_node.keys():
		var node_id := str(node_id_value)
		var window := _dictionary(swept_windows_by_node.get(node_id, {}))
		if window.is_empty() or action_index < int(window.get("start_action", action_index)) or action_index >= int(window.get("end_action", action_index)):
			swept_windows_by_node.erase(node_id)


func _generate_segments() -> void:
	segments = []
	var eligible := _eligible_node_ids()
	if eligible.is_empty():
		return
	var root_rng := RngStream.new()
	root_rng.configure(seed_value, seed_value)
	var rng := root_rng.fork("police_sweep_track")
	var tier_one: Array = []
	for node_id in eligible:
		if int(_dictionary(_node_metadata.get(node_id, {})).get("tier", 1)) == 1:
			tier_one.append(node_id)
	var current_node := str(rng.pick(tier_one if not tier_one.is_empty() else eligible, eligible[0]))
	var dwell_range := _int_range(config.get("dwell_actions", [3, 6]), 3, 6)
	var cursor := start_action
	var index := 0
	while cursor < end_action:
		var dwell := rng.randi_range(int(dwell_range[0]), int(dwell_range[1]))
		var segment_end := mini(end_action, cursor + maxi(1, dwell))
		segments.append({
			"node_id": current_node,
			"start_action": cursor,
			"end_action": segment_end,
			"dwell_actions": segment_end - cursor,
		})
		cursor = segment_end
		if cursor >= end_action:
			break
		current_node = _next_node(current_node, 2 if index % 2 == 0 else 1, eligible, rng)
		index += 1


func _next_node(current_node: String, preferred_tier: int, eligible: Array, rng: RngStream) -> String:
	var neighbors := _string_array(_neighbors_by_node.get(current_node, []))
	var allowed: Array = []
	var preferred: Array = []
	for node_id in neighbors:
		if not eligible.has(node_id):
			continue
		allowed.append(node_id)
		if int(_dictionary(_node_metadata.get(node_id, {})).get("tier", 1)) == preferred_tier:
			preferred.append(node_id)
	var candidates := preferred if not preferred.is_empty() else allowed
	if candidates.is_empty():
		return current_node
	candidates.sort()
	return str(rng.pick(candidates, current_node))


func _sync_segment_index() -> void:
	if segments.is_empty() or action_index < start_action:
		segment_index = -1
		return
	if action_index >= end_action:
		segment_index = segments.size()
		return
	if segment_index < 0:
		segment_index = 0
	while segment_index + 1 < segments.size() and action_index >= int((segments[segment_index] as Dictionary).get("end_action", end_action)):
		segment_index += 1
	while segment_index > 0 and action_index < int((segments[segment_index] as Dictionary).get("start_action", start_action)):
		segment_index -= 1


func _index_world(map_data: Dictionary) -> void:
	_node_metadata = {}
	_neighbors_by_node = {}
	for node_value in _dictionary_array(map_data.get("nodes", [])):
		var node_id := str(node_value.get("id", node_value.get("archetype_id", ""))).strip_edges()
		if node_id.is_empty():
			continue
		_node_metadata[node_id] = {
			"id": node_id,
			"archetype_id": str(node_value.get("archetype_id", node_id)),
			"kind": str(node_value.get("kind", "")),
			"tier": maxi(1, int(node_value.get("tier", 1))),
		}
		_neighbors_by_node[node_id] = []
	for edge_value in _dictionary_array(map_data.get("edges", [])):
		var a := str(edge_value.get("a", "")).strip_edges()
		var b := str(edge_value.get("b", "")).strip_edges()
		if not _node_metadata.has(a) or not _node_metadata.has(b) or a == b:
			continue
		var a_neighbors := _string_array(_neighbors_by_node.get(a, []))
		var b_neighbors := _string_array(_neighbors_by_node.get(b, []))
		if not a_neighbors.has(b):
			a_neighbors.append(b)
		if not b_neighbors.has(a):
			b_neighbors.append(a)
		a_neighbors.sort()
		b_neighbors.sort()
		_neighbors_by_node[a] = a_neighbors
		_neighbors_by_node[b] = b_neighbors


func _eligible_node_ids() -> Array:
	var ids: Array = []
	for node_id_value in _node_metadata.keys():
		var node_id := str(node_id_value)
		var metadata := _dictionary(_node_metadata.get(node_id, {}))
		var kind := str(metadata.get("kind", "")).strip_edges().to_lower()
		if GRAND_CASINO_IDS.has(node_id) or node_id.begins_with("grand_casino") or kind == "boss":
			continue
		ids.append(node_id)
	ids.sort()
	return ids


func _prune_windows() -> void:
	for node_id_value in swept_windows_by_node.keys():
		var node_id := str(node_id_value)
		var window := _dictionary(swept_windows_by_node.get(node_id, {}))
		if window.is_empty() or action_index >= int(window.get("end_action", action_index)):
			swept_windows_by_node.erase(node_id)


func _shortest_path(start_node: String, target_node: String) -> Array:
	if start_node.is_empty() or target_node.is_empty() or not _node_metadata.has(start_node) or not _node_metadata.has(target_node):
		return []
	if start_node == target_node:
		return [start_node]
	var queue: Array = [start_node]
	var previous := {start_node: ""}
	while not queue.is_empty():
		var node_id := str(queue.pop_front())
		var neighbors := _string_array(_neighbors_by_node.get(node_id, []))
		neighbors.sort()
		for neighbor_value in neighbors:
			var neighbor := str(neighbor_value)
			if previous.has(neighbor):
				continue
			previous[neighbor] = node_id
			if neighbor == target_node:
				var path: Array = [target_node]
				var cursor := target_node
				while cursor != start_node:
					cursor = str(previous.get(cursor, ""))
					if cursor.is_empty():
						return []
					path.push_front(cursor)
				return path
			queue.append(neighbor)
	return []


func _encounter_claim_matches_current(claim: Dictionary) -> bool:
	if not _exact_keys(claim, ["action_index", "encounter_seed", "node_id", "segment_index", "sweep_departure_action"]): return false
	var current := status()
	return not current.is_empty() and int(claim.get("segment_index", -1)) == last_encounter_segment \
		and str(claim.get("node_id", "")) == last_encounter_node_id and int(claim.get("segment_index", -1)) == int(current.get("segment_index", -2)) \
		and str(claim.get("node_id", "")) == str(current.get("current_node_id", "")) and int(claim.get("action_index", -1)) == action_index \
		and int(claim.get("encounter_seed", 0)) == _stable_hash("%d:%d:sweep_encounter" % [seed_value, int(claim.get("segment_index", -1))]) \
		and int(claim.get("sweep_departure_action", -1)) == int(current.get("next_move_action", -2))


static func _cargo_public_context(value: Variant) -> Dictionary:
	var source := _dictionary(value)
	var cargo_id := str(source.get("cargo_id", source.get("id", ""))).strip_edges()
	return {
		"active": not cargo_id.is_empty(),
		"cargo_id": cargo_id,
		"cargo_label": str(source.get("cargo_label", source.get("label", cargo_id.replace("_", " ").capitalize()))).strip_edges() if not cargo_id.is_empty() else "",
		"contraband": bool(source.get("contraband", false)) if not cargo_id.is_empty() else false,
	}


static func _cargo_context_valid(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY: return false
	var cargo: Dictionary = value
	if not _exact_keys(cargo, ["active", "cargo_id", "cargo_label", "contraband"]): return false
	var active := bool(cargo.get("active", false))
	return (active and not str(cargo.get("cargo_id", "")).strip_edges().is_empty() and not str(cargo.get("cargo_label", "")).strip_edges().is_empty()) \
		or (not active and str(cargo.get("cargo_id", "")).is_empty() and str(cargo.get("cargo_label", "")).is_empty() and not bool(cargo.get("contraband", false)))


static func _intel_projection_valid(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY: return false
	var intel: Dictionary = value
	if not bool(intel.get("available", false)):
		return _exact_keys(intel, ["authority_gap", "available"]) and str(intel.get("authority_gap", "")) == INTEL_AUTHORITY_GAP \
			or _exact_keys(intel, ["authority_gap", "available", "live", "observed"]) and str(intel.get("authority_gap", "")) == INTEL_AUTHORITY_GAP and not bool(intel.get("live", true)) \
			or _exact_keys(intel, ["available", "live", "observed"]) and not bool(intel.get("live", true))
	var live_status := _exact_keys(intel, ["active", "available", "current_node_id", "heading_node_id", "live", "moves_in_actions", "observed"]) \
		and bool(intel.get("observed", false)) and not str(intel.get("current_node_id", "")).is_empty() and int(intel.get("moves_in_actions", -1)) >= 0
	var reported_marker := _exact_keys(intel, ["available", "heading_node_id", "live", "node_id", "observed", "sighted_action", "source", "stale_actions"]) \
		and bool(intel.get("observed", false)) and not str(intel.get("node_id", "")).is_empty() and int(intel.get("sighted_action", -1)) >= 0 \
		and int(intel.get("stale_actions", -1)) >= 0 and str(intel.get("source", "")) in ["crew_intel", "direct", "adjacent"]
	return live_status or reported_marker


static func _normalized_intel_projection(value: Variant) -> Dictionary:
	var intel := _dictionary(value)
	if not bool(intel.get("available", false)):
		if intel.has("authority_gap"):
			return {"available": false, "authority_gap": INTEL_AUTHORITY_GAP}
		return {"available": false, "observed": bool(intel.get("observed", false)), "live": false}
	if intel.has("current_node_id"):
		return {
			"available": true,
			"active": bool(intel.get("active", false)),
			"observed": bool(intel.get("observed", false)),
			"live": bool(intel.get("live", false)),
			"current_node_id": str(intel.get("current_node_id", "")),
			"heading_node_id": str(intel.get("heading_node_id", "")),
			"moves_in_actions": maxi(0, int(intel.get("moves_in_actions", 0))),
		}
	return {
		"available": true,
		"observed": bool(intel.get("observed", false)),
		"live": bool(intel.get("live", false)),
		"node_id": str(intel.get("node_id", "")),
		"heading_node_id": str(intel.get("heading_node_id", "")),
		"sighted_action": maxi(0, int(intel.get("sighted_action", 0))),
		"stale_actions": maxi(0, int(intel.get("stale_actions", 0))),
		"source": str(intel.get("source", "crew_intel")),
	}


static func _positions_valid(value: Variant) -> bool:
	return typeof(value) == TYPE_DICTIONARY and _exact_keys(value as Dictionary, ["cargo", "officers", "player"]) \
		and str((value as Dictionary).get("officers", "")) == "blocking_route" and str((value as Dictionary).get("player", "")) == "street_approach" \
		and str((value as Dictionary).get("cargo", "")) in ["carried", "none"]


static func _rung(outcome: String, beat: String, options_value: Array) -> Dictionary:
	var options: Array = []
	for option_value in options_value:
		var option: Array = option_value
		options.append({"cost_kind": str(option[0]), "amount_range": (option[1] as Array).duplicate()})
	return {"outcome": outcome, "staged_beat": beat, "run_continues": true, "cost_options": options}


static func _rungs_valid(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY or (value as Array).size() != ENCOUNTER_OUTCOMES.size(): return false
	var outcomes: Array = []
	for rung_value in value as Array:
		if typeof(rung_value) != TYPE_DICTIONARY: return false
		var rung: Dictionary = rung_value
		if not _exact_keys(rung, ["cost_options", "outcome", "run_continues", "staged_beat"]) or not bool(rung.get("run_continues", false)) or str(rung.get("staged_beat", "")).is_empty() or typeof(rung.get("cost_options")) != TYPE_ARRAY: return false
		outcomes.append(str(rung.get("outcome", "")))
		for option_value in rung.get("cost_options", []):
			if typeof(option_value) != TYPE_DICTIONARY or not _exact_keys(option_value as Dictionary, ["amount_range", "cost_kind"]): return false
			var amount_range: Variant = (option_value as Dictionary).get("amount_range")
			if typeof(amount_range) != TYPE_ARRAY or (amount_range as Array).size() != 2 or int((amount_range as Array)[0]) <= 0 or int((amount_range as Array)[1]) < int((amount_range as Array)[0]): return false
	return outcomes == ENCOUNTER_OUTCOMES


static func _normalized_rungs(value: Variant) -> Array:
	var result: Array = []
	for rung_value in value as Array:
		var rung: Dictionary = rung_value
		var options: Array = []
		for option_value in rung.get("cost_options", []):
			var option: Dictionary = option_value
			var amount_range: Array = option.get("amount_range", [])
			options.append({"cost_kind": str(option.get("cost_kind", "")), "amount_range": [int(amount_range[0]), int(amount_range[1])]})
		result.append({"outcome": str(rung.get("outcome", "")), "staged_beat": str(rung.get("staged_beat", "")), "run_continues": bool(rung.get("run_continues", false)), "cost_options": options})
	return result


static func _cost_matches_rung(rungs_value: Variant, outcome: String, cost_kind: String, cost_amount: int) -> bool:
	if not _rungs_valid(rungs_value) or cost_amount <= 0: return false
	for rung_value in rungs_value as Array:
		var rung: Dictionary = rung_value
		if str(rung.get("outcome", "")) != outcome: continue
		for option_value in rung.get("cost_options", []):
			var option: Dictionary = option_value
			var amount_range: Array = option.get("amount_range", [])
			if str(option.get("cost_kind", "")) == cost_kind and cost_amount >= int(amount_range[0]) and cost_amount <= int(amount_range[1]): return true
	return false


static func _exact_keys(value: Dictionary, expected: Array) -> bool:
	var keys := value.keys(); keys.sort()
	var exact := expected.duplicate(); exact.sort()
	return keys == exact


static func _unique_strings(value: Array) -> Array:
	var result: Array = []
	for entry in value:
		if not result.has(str(entry)): result.append(str(entry))
	return result


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
		var entry := str(entry_value).strip_edges()
		if not entry.is_empty():
			result.append(entry)
	return result


static func _int_range(value: Variant, fallback_min: int, fallback_max: int) -> Array:
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
		var first := int((value as Array)[0])
		var second := int((value as Array)[1])
		return [mini(first, second), maxi(first, second)]
	return [mini(fallback_min, fallback_max), maxi(fallback_min, fallback_max)]


static func _stable_hash(text: String) -> int:
	var hash_value := 2166136261
	for index in range(text.length()):
		hash_value = hash_value ^ text.unicode_at(index)
		hash_value = (hash_value * 16777619) & 0x7fffffff
	return maxi(1, hash_value)
