class_name BarDiceRitualProjection
extends RefCounted

# Contract-only presentation projection. This type cannot roll or score dice,
# grade a skill input, accept/refund a wager, move cash, add heat, disperse a
# street game, grant teaching progress, or settle an outcome.

const RITUAL_ID := "street.bar_dice"
const STATE_VERSION := 1
const PHASES := ["agree_wager", "cover", "shake", "throw", "reveal", "call", "settle"]
const COVER_STATES := ["pending", "accepted", "partial", "refused"]
const OUTCOMES := ["win", "lose", "carry", "interrupted", "refused"]
const PUBLIC_AUTHORITY_FIELDS := [
	"round_id", "result_serial", "available_cash", "opponent_available_cash",
	"proposed_total", "covered_total", "returned_stake", "at_risk_total",
	"cover_status", "authoritative_result_ref", "outcome", "payout",
	"net_change", "rake", "carryover_pot", "rounds_played", "attention",
	"interrupted", "interruption_reason", "aftermath_receipt",
]


static func initial_state(authority: Dictionary) -> Dictionary:
	return {
		"schema_version": STATE_VERSION,
		"ritual_id": RITUAL_ID,
		"phase_id": "agree_wager",
		"phase_entry_receipts": ["receipt:phase_entry:agree_wager"],
		"transition_receipts": {},
		"one_shot_receipts": {},
		"authority_ref": _public_authority(authority),
		"authoritative_result_ref": "",
		"settlement_receipt": "",
	}


static func normalize_state(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY: return {}
	var source := value as Dictionary
	var phase_id := str(source.get("phase_id", ""))
	if int(source.get("schema_version", 0)) != STATE_VERSION or str(source.get("ritual_id", "")) != RITUAL_ID or not PHASES.has(phase_id): return {}
	return {
		"schema_version": STATE_VERSION,
		"ritual_id": RITUAL_ID,
		"phase_id": phase_id,
		"phase_entry_receipts": _bounded_strings(source.get("phase_entry_receipts", []), 24),
		"transition_receipts": _bounded_dictionary(source.get("transition_receipts", {}), 48),
		"one_shot_receipts": _bounded_dictionary(source.get("one_shot_receipts", {}), 48),
		"authority_ref": _public_authority(_dict(source.get("authority_ref", {}))),
		"authoritative_result_ref": str(source.get("authoritative_result_ref", "")),
		"settlement_receipt": str(source.get("settlement_receipt", "")),
	}


static func apply_transition(state_value: Dictionary, next_phase: String, receipt_key: String, authority: Dictionary) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty(): return {"ok":false,"state":state_value,"error_code":"invalid_state"}
	var receipt := receipt_key.strip_edges()
	if receipt.is_empty() or receipt.length() > 128: return {"ok":false,"state":state,"error_code":"invalid_receipt"}
	var phase_before := str(state.get("phase_id", ""))
	var public_authority := _public_authority(authority)
	var result_ref := str(public_authority.get("authoritative_result_ref", ""))
	# The replay identity excludes the caller's current phase: after a successful
	# transition the same receipt is necessarily observed from phase_after.
	var content := {"phase_after":next_phase,"authority":public_authority}
	var fingerprint := _fingerprint(content)
	var receipts := _dict(state.get("transition_receipts", {}))
	if receipts.has(receipt):
		if str(_dict(receipts.get(receipt, {})).get("content_fingerprint", "")) == fingerprint: return {"ok":true,"state":state,"replayed":true}
		return {"ok":false,"state":state,"error_code":"receipt_content_conflict"}
	if not _allowed_transition(phase_before, next_phase, public_authority): return {"ok":false,"state":state,"error_code":"phase_transition_rejected"}
	if next_phase in ["reveal", "call", "settle"] and result_ref.is_empty() and not _terminal_without_throw(public_authority):
		return {"ok":false,"state":state,"error_code":"authoritative_result_missing"}
	var next := state.duplicate(true)
	next["phase_id"] = next_phase
	next["authority_ref"] = public_authority
	next["authoritative_result_ref"] = result_ref
	if next_phase == "settle": next["settlement_receipt"] = receipt
	receipts = _dict(next.get("transition_receipts", {}))
	receipts[receipt] = {"phase_before":phase_before,"phase_after":next_phase,"content_fingerprint":fingerprint}
	next["transition_receipts"] = receipts
	var entries := _array(next.get("phase_entry_receipts", []))
	entries.append("receipt:phase_entry:%s:%d" % [next_phase, entries.size() + 1])
	next["phase_entry_receipts"] = entries
	return {"ok":true,"state":next,"replayed":false}


static func record_one_shot(state_value: Dictionary, effect_id: String, receipt_key: String) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty(): return {"ok":false,"state":state_value,"error_code":"invalid_state","emit":false}
	var content := {"effect_id":effect_id,"phase_id":str(state.get("phase_id", ""))}
	var fingerprint := _fingerprint(content)
	var receipts := _dict(state.get("one_shot_receipts", {}))
	if receipts.has(receipt_key):
		if str(_dict(receipts.get(receipt_key, {})).get("content_fingerprint", "")) == fingerprint: return {"ok":true,"state":state,"replayed":true,"emit":false}
		return {"ok":false,"state":state,"error_code":"receipt_content_conflict","emit":false}
	var next := state.duplicate(true)
	receipts = _dict(next.get("one_shot_receipts", {}))
	receipts[receipt_key] = {"effect_id":effect_id,"phase_id":str(state.get("phase_id", "")),"content_fingerprint":fingerprint}
	next["one_shot_receipts"] = receipts
	return {"ok":true,"state":next,"replayed":false,"emit":true}


static func public_projection(ritual_state_value: Dictionary, authority: Dictionary) -> Dictionary:
	var state := normalize_state(ritual_state_value)
	if state.is_empty(): return {}
	var public := _public_authority(authority)
	var phase_id := str(state.get("phase_id", ""))
	var cover_status := str(public.get("cover_status", "pending"))
	if not COVER_STATES.has(cover_status): cover_status = "pending"
	var outcome := str(public.get("outcome", ""))
	if not OUTCOMES.has(outcome): outcome = ""
	var dice_visible := phase_id in ["reveal", "call", "settle"] and not str(public.get("authoritative_result_ref", "")).is_empty()
	return {
		"ritual_id": RITUAL_ID,
		"phase_id": phase_id,
		"authoritative_result_ref": str(public.get("authoritative_result_ref", "")),
		"money": {
			"available_cash":maxi(0, int(public.get("available_cash", 0))),
			"opponent_available_cash":maxi(0, int(public.get("opponent_available_cash", 0))),
			"proposed_total":maxi(0, int(public.get("proposed_total", 0))),
			"covered_total":maxi(0, int(public.get("covered_total", 0))),
			"returned_stake":maxi(0, int(public.get("returned_stake", 0))),
			"at_risk_total":maxi(0, int(public.get("at_risk_total", 0))),
			"payout":maxi(0, int(public.get("payout", 0))) if phase_id == "settle" else 0,
			"net_change":int(public.get("net_change", 0)) if phase_id == "settle" else 0,
			"rake":maxi(0, int(public.get("rake", 0))) if phase_id == "settle" else 0,
		},
		"cover_state": cover_status,
		"cup_state": _cup_state(phase_id),
		"dice_state": "revealed" if dice_visible else "hidden",
		"outcome": outcome if phase_id in ["call", "settle"] else "",
		"opponent_actor": _opponent_projection(phase_id, public, outcome),
		"onlookers_actor": _onlookers_projection(public),
		"energy_tier": _energy_tier(public),
		"available_controls": _controls_for_phase(phase_id),
		"interruption": _interruption_projection(public),
		"reduced_motion_equivalent": true,
		"colorblind_state_labels": [cover_status, _energy_tier(public), outcome if not outcome.is_empty() else "unresolved"],
	}


static func _allowed_transition(current: String, next_phase: String, authority: Dictionary) -> bool:
	if next_phase == "settle" and current != "settle" and _terminal_without_throw(authority): return true
	var allowed := {"agree_wager":["cover"],"cover":["shake"],"shake":["throw"],"throw":["reveal"],"reveal":["call"],"call":["settle"],"settle":[]}
	return _array(allowed.get(current, [])).has(next_phase)


static func _terminal_without_throw(authority: Dictionary) -> bool:
	return bool(authority.get("interrupted", false)) or str(authority.get("cover_status", "")) == "refused"


static func _cup_state(phase_id: String) -> String:
	var states := {"agree_wager":"rest","cover":"rest","shake":"shakeable","throw":"throwable","reveal":"revealable","call":"lifted","settle":"returned"}
	return str(states.get(phase_id, "rest"))


static func _opponent_projection(phase_id: String, authority: Dictionary, outcome: String) -> Dictionary:
	var behavior := "offering"
	var cover := str(authority.get("cover_status", "pending"))
	if cover == "refused": behavior = "refused"
	elif phase_id == "cover": behavior = "covering"
	elif phase_id in ["shake", "throw", "reveal"]: behavior = "watching"
	elif phase_id == "call": behavior = "calling"
	elif phase_id == "settle": behavior = "lost" if outcome == "win" else "won" if outcome == "lose" else "backing_off"
	if bool(authority.get("interrupted", false)): behavior = "walking"
	return {"id":"actor.opponent","behavior_state":behavior,"pose":"departing" if behavior == "walking" else "standing" if phase_id == "settle" else "leaning" if phase_id in ["reveal", "call"] else "seated","tell":_public_tell(phase_id, authority)}


static func _public_tell(phase_id: String, authority: Dictionary) -> Dictionary:
	if phase_id in ["agree_wager", "cover"]:
		var cover := str(authority.get("cover_status", "pending"))
		return {"id":"cover_posture","source_fact":"cover_status","value":cover,"reliability":"literal_public_state"}
	if phase_id in ["call", "settle"]:
		return {"id":"called_result","source_fact":"outcome","value":str(authority.get("outcome", "")),"reliability":"literal_public_state"}
	return {"id":"round_posture","source_fact":"rounds_played","value":maxi(0, int(authority.get("rounds_played", 0))),"reliability":"cosmetic_only"}


static func _onlookers_projection(authority: Dictionary) -> Dictionary:
	var tier := _energy_tier(authority)
	var behavior := "quiet" if tier == "quiet" else "watching" if tier == "watching" else "tense" if tier == "tense" else "breaking"
	return {"id":"actor.onlookers","behavior_state":behavior,"pose":"leaving" if tier == "breaking" else "crowding" if tier == "tense" else "watching" if tier == "watching" else "distant"}


static func _energy_tier(authority: Dictionary) -> String:
	if bool(authority.get("interrupted", false)): return "breaking"
	var attention := maxi(0, int(authority.get("attention", 0)))
	if attention >= 70: return "tense"
	if attention >= 25: return "watching"
	return "quiet"


static func _controls_for_phase(phase_id: String) -> Array:
	var controls := {"agree_wager":["commit.place","commit.correct","commit.remove","commit.undo","commit.clear","commit.repeat","commit.rebet","commit.confirm"],"cover":["bar_dice.ack_cover"],"shake":["bar_dice.shake"],"throw":["bar_dice.throw"],"reveal":["bar_dice.reveal"],"call":["bar_dice.ack_call"],"settle":[]}
	return _array(controls.get(phase_id, []))


static func _interruption_projection(authority: Dictionary) -> Dictionary:
	if not bool(authority.get("interrupted", false)): return {"active":false}
	return {"active":true,"reason":str(authority.get("interruption_reason", "")),"returned_stake":maxi(0, int(authority.get("returned_stake", 0))),"aftermath_receipt":str(authority.get("aftermath_receipt", ""))}


static func _public_authority(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in PUBLIC_AUTHORITY_FIELDS:
		if value.has(key): result[key] = value.get(key)
	return result


static func _fingerprint(value: Variant) -> String:
	return JSON.stringify(_canonical(value)).sha256_text()


static func _canonical(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var source := value as Dictionary
		var keys: Array = source.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var result: Dictionary = {}
		for key in keys: result[str(key)] = _canonical(source.get(key))
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for item in value as Array: result.append(_canonical(item))
		return result
	return value


static func _bounded_strings(value: Variant, limit: int) -> Array:
	var result: Array = []
	for item in _array(value):
		var text := str(item)
		if not text.is_empty() and text.length() <= 128 and result.size() < limit: result.append(text)
	return result


static func _bounded_dictionary(value: Variant, limit: int) -> Dictionary:
	var source := _dict(value)
	var result: Dictionary = {}
	var keys: Array = source.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for key in keys:
		if result.size() >= limit: break
		result[str(key)] = _dict(source.get(key))
	return result


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
