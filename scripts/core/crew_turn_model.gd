class_name CrewTurnModel
extends RefCounted

# Hidden, deterministic heist-fracture rules. Persisted state uses neutral keys
# because raw saves are a player-visible surface.

const STATE_VERSION := 1
const MEMBER_ROOK := "crew_rook"
const SIGNAL_PATTERN := "p"
const SIGNAL_ROUTE := "r"
const SIGNAL_PAYMENT := "e"
const SIGNAL_IDS := [SIGNAL_PATTERN, SIGNAL_ROUTE, SIGNAL_PAYMENT]


static func empty_state() -> Dictionary:
	return {"v": STATE_VERSION, "m": "", "w": [], "e": [], "h": false, "c": false, "f": 0}


static func normalize_state(value: Variant, member_ids: Array) -> Dictionary:
	var source: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var member_id := str(source.get("m", ""))
	if not member_ids.has(member_id):
		member_id = ""
	return {
		"v": STATE_VERSION,
		"m": member_id,
		"w": _signal_array(source.get("w", [])),
		"e": _signal_array(source.get("e", [])),
		"h": bool(source.get("h", false)),
		"c": bool(source.get("c", false)),
		"f": maxi(0, int(source.get("f", 0))),
	}


static func eligible_members(plan_definition: Dictionary, met_members: Array, member_ids: Array) -> Array:
	var architects := _string_array(plan_definition.get("architects", []))
	var result: Array = []
	for member_value in met_members:
		var member_id := str(member_value)
		if member_ids.has(member_id) and member_id != MEMBER_ROOK and not architects.has(member_id) and not result.has(member_id):
			result.append(member_id)
	result.sort()
	return result


static func resolve(plan_definition: Dictionary, met_members: Array, ledgers: Array, member_ids: Array, tuning: Dictionary, rng: RngStream, escalation: int = 0) -> Dictionary:
	var state := empty_state()
	state["f"] = maxi(0, escalation)
	var eligible := eligible_members(plan_definition, met_members, member_ids)
	var weights := {}
	var total_weight := 0
	for member_id in eligible:
		var weight := 0
		for entry_value in ledgers:
			if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("member_id", "")) == member_id:
				weight += maxi(1, int((entry_value as Dictionary).get("weight", 1)))
		if weight > 0:
			weights[member_id] = weight
			total_weight += weight
	# Hidden guarantee: no eligible debt means no roll and no selected member.
	if total_weight <= 0:
		return state
	var per_weight := maxi(1, int(tuning.get("chance_percent_per_weight", 12)))
	var escalation_step := maxi(0, int(tuning.get("wrong_choice_chance_percent", 18)))
	var cap := clampi(int(tuning.get("chance_percent_cap", 72)), 1, 100)
	var chance := mini(cap, total_weight * per_weight + escalation * escalation_step)
	if rng.randi_range(1, 100) > chance:
		return state
	var roll := rng.randi_range(1, total_weight)
	var cursor := 0
	var ids: Array = weights.keys()
	ids.sort()
	for member_id in ids:
		cursor += int(weights.get(member_id, 0))
		if roll <= cursor:
			state["m"] = member_id
			break
	return state


static func witnessed_count(state_value: Variant, member_ids: Array) -> int:
	return _signal_array(normalize_state(state_value, member_ids).get("w", [])).size()


static func active_member(state_value: Variant, member_ids: Array) -> String:
	var state := normalize_state(state_value, member_ids)
	return "" if bool(state.get("c", false)) else str(state.get("m", ""))


static func mark_emitted(state_value: Variant, signal_id: String, witnessed: bool, member_ids: Array) -> Dictionary:
	var state := normalize_state(state_value, member_ids)
	if not SIGNAL_IDS.has(signal_id) or str(state.get("m", "")).is_empty() or bool(state.get("c", false)):
		return state
	var emitted := _signal_array(state.get("e", []))
	if not emitted.has(signal_id):
		emitted.append(signal_id)
	state["e"] = emitted
	if witnessed:
		var witnessed_ids := _signal_array(state.get("w", []))
		if not witnessed_ids.has(signal_id):
			witnessed_ids.append(signal_id)
		state["w"] = witnessed_ids
	return state


static func validate_tuning(tuning: Dictionary) -> Array:
	var failures: Array = []
	for key in ["chance_percent_per_weight", "chance_percent_cap", "wrong_choice_chance_percent", "crew_trust_cost", "hedge_trust_cost", "payment_shortfall_percent"]:
		if int(tuning.get(key, 0)) <= 0:
			failures.append("Hidden heist tuning %s must be positive." % key)
	var partial := _int_array(tuning.get("partial_haul_percent_band", []))
	if partial.size() != 2 or partial[0] <= 0 or partial[1] < partial[0] or partial[1] >= 100:
		failures.append("Hidden heist partial-haul band must contain two ascending percentages below 100.")
	return failures


static func _signal_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value:
		var signal_id := str(entry_value)
		if SIGNAL_IDS.has(signal_id) and not result.has(signal_id):
			result.append(signal_id)
	return result


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry_value in value:
			var text := str(entry_value).strip_edges()
			if not text.is_empty():
				result.append(text)
	return result


static func _int_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry_value in value:
			result.append(int(entry_value))
	return result


# WORLD06_6_PUBLIC_SURFACE_BEGIN
# These projections contain authored presentation only. The model cannot verify
# a live host observation or apply any resulting consequence at this boundary.
const PUBLIC_SURFACE_VERSION := 1
const PUBLIC_AUTHORITY_GAP := "host_observation_authority_unavailable"
const PUBLIC_PLAN_IDS := ["the_count", "the_whale_game"]


static func observable_signal_proposal(signal_id: String) -> Dictionary:
	var authored := {
		SIGNAL_PATTERN: {"surface_id": "table_rhythm_shift", "place_role": "table", "line": "A familiar rhythm lands wrong in the room."},
		SIGNAL_ROUTE: {"surface_id": "route_detail_shift", "place_role": "planning_table", "line": "A route detail does not match what the room remembers."},
		SIGNAL_PAYMENT: {"surface_id": "envelope_shortfall", "place_role": "planning_table", "line": "The envelope feels light against the posted figure."},
	}
	if not authored.has(signal_id):
		return {}
	var presentation: Dictionary = (authored.get(signal_id, {}) as Dictionary).duplicate(true)
	presentation["actor_roles"] = ["player", "crew_voice"]
	presentation["public_verbs"] = ["notice", "look", "continue"]
	return _public_proposal(presentation)


static func confrontation_surface_proposal(plan_id: String) -> Dictionary:
	if not PUBLIC_PLAN_IDS.has(plan_id):
		return {}
	return _public_proposal({
		"surface_id": "quiet_table_question",
		"place_role": "planning_table",
		"actor_roles": ["player", "crew_voice"],
		"line": "The room goes quiet enough for one careful question.",
		"public_verbs": ["press", "step_back", "change_role"],
	})


static func confrontation_aftermath_proposal(public_beat: String) -> Dictionary:
	var authored := {
		"right": {"beat_id": "crew_tightens", "line": "The answer comes clean. The crew closes ranks and carries a small edge forward.", "public_effect": "one_play_edge_pending_host"},
		"wrong": {"beat_id": "room_darkens", "line": "The question lands badly. The table goes cold around you.", "public_effect": "trust_cost_pending_host"},
		"hedge": {"beat_id": "role_shift", "line": "You quietly change your place in the plan and keep an exit within reach.", "public_effect": "partial_exit_pending_host"},
	}
	if not authored.has(public_beat):
		return {}
	return _public_proposal(authored.get(public_beat, {}))


static func plan_failure_beat_proposal(plan_id: String, failure_kind: String) -> Dictionary:
	var authored := {
		"the_count": {
			"fracture": {"beat_id": "corridor_break", "place_role": "corridor", "line": "The corridor folds before the exit opens."},
			"mechanical": {"beat_id": "floor_pressure", "place_role": "casino_floor", "line": "The floor play comes apart under the house's pressure."},
		},
		"the_whale_game": {
			"fracture": {"beat_id": "rig_exposure", "place_role": "high_limit_table", "line": "The house points at the rig before the cage clears."},
			"mechanical": {"beat_id": "name_break", "place_role": "cage_interview", "line": "The borrowed name breaks under the cage lights."},
		},
	}
	if not authored.has(plan_id) or not (authored.get(plan_id, {}) as Dictionary).has(failure_kind):
		return {}
	return _public_proposal((authored.get(plan_id, {}) as Dictionary).get(failure_kind, {}))


static func _public_proposal(authored_value: Variant) -> Dictionary:
	var authored: Dictionary = authored_value if typeof(authored_value) == TYPE_DICTIONARY else {}
	if authored.is_empty():
		return {}
	return {
		"schema_version": PUBLIC_SURFACE_VERSION,
		"authoritative": false,
		"proposal_only": true,
		"can_mutate": false,
		"authority_gap": PUBLIC_AUTHORITY_GAP,
		"presentation": authored.duplicate(true),
	}
