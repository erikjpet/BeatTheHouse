class_name BlackjackActionAuthority
extends RefCounted

# Pure Blackjack authority vocabulary and closed validation engine. This type
# owns no Object, RunState, environment, account, RNG, clock, Callable, or
# capability. FoundationMain is the sole live transaction host; callers may use
# these helpers to form/inspect proposals, but this engine can mutate nothing.

const RuntimeScript := preload("res://scripts/core/game_ritual_runtime.gd")
const LEDGER_KEY := "_blackjack_action_authority"
const LEDGER_VERSION := 3
const CACHE_LIMIT := 128
const JOURNAL_LIMIT := 128
const RECEIPT_CAUSE := "foundation_main:blackjack_action"
const REPLAY_CAUSE := "foundation_main:blackjack_cache_hit"

# Closed module/host vocabulary. FoundationMain consumes these generic constant
# names so the live transaction host does not embed any game-specific action,
# method, table-key, or result-key literals.
const RESOLVE_PROPOSAL_METHOD := &"_blackjack_resolve_proposal"
const WAGER_COST_PROPOSAL_METHOD := &"_blackjack_wager_cost_proposal"
const HOST_AUTO_TICK_METHOD := &"_blackjack_host_needs_auto_tick"
const SURFACE_INTENT_KEY := "blackjack_surface_intent"
const SURFACE_INTENT_INDEX_KEY := "blackjack_surface_intent_index"
const PENDING_APPLY_RECEIPT_KEY := "_blackjack_pending_apply_receipt"
const PROPOSAL_REQUIRES_APPLY_KEY := "blackjack_proposal_requires_apply"
const SURFACE_UI_STATE_KEY := "blackjack_surface_ui_state"
const HOST_REQUEST_KEY := "blackjack_host_request_key"
const HOST_COMMITTED_KEY := "blackjack_host_committed"
const HOST_BOUNDARY_ORDINAL_KEY := "blackjack_host_boundary_ordinal"
const HOST_DELIVERY_KEY := "blackjack_host_delivery"
const HOST_WAGER_COST_KEY := "blackjack_host_wager_cost"
const HOST_FUNDING_LEASE_KEY := "blackjack_host_funding_lease"
const HOST_INTENT_FINGERPRINT_KEY := "blackjack_host_intent_fingerprint"
const HOST_CONTEXT_FINGERPRINT_KEY := "blackjack_host_context_fingerprint"
const HOST_CONTENT_FINGERPRINT_KEY := "blackjack_host_content_fingerprint"
const HOST_APPLY_RECEIPT_KEY := "blackjack_host_apply_receipt"
const HOST_ACTION_SUSPICION_DELTA_KEY := "blackjack_host_action_suspicion_delta"
const HOST_ENVIRONMENT_TURN_SUSPICION_DELTA_KEY := "blackjack_host_environment_turn_suspicion_delta"
const HOST_REPLAY_KEY := "blackjack_host_replay"
const SKIP_ENVIRONMENT_TURN_KEY := "sealed_action_skip_environment_turn"
const PLACE_BET_ACTION := "blackjack_place_bet"
const RETRY_SURFACE_ACTIONS := ["blackjack_retry_pending", "blackjack_deal"]
const CANCEL_SURFACE_ACTION := "blackjack_cancel_pending"

const LEDGER_KEYS := [
	"boundary_ordinal",
	"checkpoint_fingerprint",
	"initialized",
	"journal",
	"journal_head",
	"next_request_ordinal",
	"pending_delivery",
	"pending_recovery_session",
	"request_cache",
	"request_order",
	"session",
	"table_binding",
	"version",
]
const DELIVERY_KEYS := ["action_id", "boundary_ordinal", "intent_fingerprint", "recovery_session_fingerprint", "request_key", "stake", "trusted_context_fingerprint"]
const CACHE_ENTRY_KEYS := ["action_id", "boundary_ordinal", "intent_fingerprint", "proposal_fingerprint", "recovery_session_fingerprint", "request_key", "response", "result_fingerprint", "rng_fingerprint", "run_fingerprint", "stake", "trusted_context_fingerprint"]
const JOURNAL_ENTRY_KEYS := ["boundary_ordinal", "entry_fingerprint", "intent_fingerprint", "previous_fingerprint", "proposal_fingerprint", "recovery_session_fingerprint", "request_key", "result_fingerprint", "rng_fingerprint", "run_fingerprint", "stake", "trusted_context_fingerprint"]
const RECEIPT_KEYS := ["boundary_ordinal", "cause", "intent_fingerprint", "proposal_fingerprint", "recovery_session_fingerprint", "request_key", "result_fingerprint", "rng_fingerprint", "run_fingerprint", "stake", "table_binding", "trusted_context_fingerprint", "version"]
const REPLAY_MARKER_KEYS := ["cause", "delivery_fingerprint", "request_key", "response_fingerprint", "version"]


static func default_ledger(table_binding: String, checkpoint_fingerprint: String) -> Dictionary:
	return {
		"version": LEDGER_VERSION,
		"initialized": true,
		"table_binding": table_binding,
		"checkpoint_fingerprint": checkpoint_fingerprint,
		"next_request_ordinal": 1,
		"boundary_ordinal": 0,
		"session": {},
		"pending_delivery": {},
		"pending_recovery_session": {},
		"request_cache": {},
		"request_order": [],
		"journal": [],
		"journal_head": "",
	}


static func validate_persisted_ledger(value: Variant, table_binding: String, expected_checkpoint_fingerprint: String = "") -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var ledger: Dictionary = (value as Dictionary).duplicate(true)
	if not _closed_shape(ledger, LEDGER_KEYS) \
			or int(ledger.get("version", 0)) != LEDGER_VERSION \
			or not bool(ledger.get("initialized", false)) \
			or str(ledger.get("table_binding", "")) != table_binding \
			or not _fingerprint(ledger.get("checkpoint_fingerprint")) \
			or (not expected_checkpoint_fingerprint.is_empty() and str(ledger.get("checkpoint_fingerprint", "")) != expected_checkpoint_fingerprint) \
			or int(ledger.get("next_request_ordinal", 0)) < 1 \
			or int(ledger.get("boundary_ordinal", -1)) < 0 \
			or typeof(ledger.get("session", null)) != TYPE_DICTIONARY \
			or typeof(ledger.get("pending_delivery", null)) != TYPE_DICTIONARY \
			or typeof(ledger.get("pending_recovery_session", null)) != TYPE_DICTIONARY \
			or typeof(ledger.get("request_cache", null)) != TYPE_DICTIONARY \
			or typeof(ledger.get("request_order", null)) != TYPE_ARRAY \
			or typeof(ledger.get("journal", null)) != TYPE_ARRAY:
		return {}
	var pending: Dictionary = ledger.get("pending_delivery", {})
	if not pending.is_empty() and not _valid_delivery(pending, ledger):
		return {}
	var recovery_session: Dictionary = ledger.get("pending_recovery_session", {})
	if (pending.is_empty() and not recovery_session.is_empty()) \
			or (not pending.is_empty() and str(pending.get("recovery_session_fingerprint", "")) != RuntimeScript.canonical_fingerprint(recovery_session)):
		return {}
	var cache: Dictionary = ledger.get("request_cache", {})
	var order: Array = ledger.get("request_order", [])
	if order.size() > CACHE_LIMIT or cache.size() != order.size():
		return {}
	var seen := {}
	for request_value in order:
		var request_key := str(request_value)
		if request_key.is_empty() or seen.has(request_key) or not cache.has(request_key):
			return {}
		seen[request_key] = true
		if not _valid_cache_entry(cache.get(request_key), request_key, table_binding):
			return {}
	var journal: Array = ledger.get("journal", [])
	if journal.size() > JOURNAL_LIMIT or journal.size() != order.size():
		return {}
	var previous := ""
	for journal_index in range(journal.size()):
		var entry_value: Variant = journal[journal_index]
		if typeof(entry_value) != TYPE_DICTIONARY:
			return {}
		var entry: Dictionary = entry_value
		if not _valid_journal_entry(entry, previous):
			return {}
		var journal_request_key := str(entry.get("request_key", ""))
		if journal_request_key != str(order[journal_index]) or not cache.has(journal_request_key):
			return {}
		var cached_entry: Dictionary = cache.get(journal_request_key, {})
		for causal_key in ["boundary_ordinal", "intent_fingerprint", "proposal_fingerprint", "recovery_session_fingerprint", "request_key", "result_fingerprint", "rng_fingerprint", "run_fingerprint", "stake", "trusted_context_fingerprint"]:
			if entry.get(causal_key) != cached_entry.get(causal_key):
				return {}
		previous = str(entry.get("entry_fingerprint", ""))
	if str(ledger.get("journal_head", "")) != previous:
		return {}
	return ledger


static func stage_session(ledger: Dictionary, session: Dictionary) -> Dictionary:
	var next := ledger.duplicate(true)
	next["session"] = session.duplicate(true)
	return next


static func issue_delivery(ledger: Dictionary, action_id: String, trusted_context: Dictionary, stake: int, recovery_session: Dictionary) -> Dictionary:
	var next := ledger.duplicate(true)
	var intent_fingerprint := RuntimeScript.canonical_fingerprint({
		"action_id": action_id,
		"session": next.get("session", {}),
	})
	var trusted_context_fingerprint := RuntimeScript.canonical_fingerprint(trusted_context)
	var recovery_session_fingerprint := RuntimeScript.canonical_fingerprint(recovery_session)
	var pending: Dictionary = next.get("pending_delivery", {})
	if not pending.is_empty():
		if str(pending.get("action_id", "")) != action_id \
				or int(pending.get("stake", -1)) != stake \
				or str(pending.get("intent_fingerprint", "")) != intent_fingerprint \
				or str(pending.get("recovery_session_fingerprint", "")) != recovery_session_fingerprint \
				or str(pending.get("trusted_context_fingerprint", "")) != trusted_context_fingerprint:
			return {"ok": false, "error_code": "receipt_content_conflict", "ledger": ledger.duplicate(true)}
		return {"ok": true, "delivery": pending.duplicate(true), "ledger": next}
	var boundary := int(next.get("boundary_ordinal", 0)) + 1
	var ordinal := int(next.get("next_request_ordinal", 1))
	var request_key := "blackjack:%s:%d" % [str(next.get("table_binding", "table")).replace(":", "_"), ordinal]
	pending = {
		"request_key": request_key,
		"action_id": action_id,
		"stake": stake,
		"boundary_ordinal": boundary,
		"intent_fingerprint": intent_fingerprint,
		"trusted_context_fingerprint": trusted_context_fingerprint,
		"recovery_session_fingerprint": recovery_session_fingerprint,
	}
	next["pending_delivery"] = pending
	next["pending_recovery_session"] = recovery_session.duplicate(true)
	next["boundary_ordinal"] = boundary
	next["next_request_ordinal"] = ordinal + 1
	return {"ok": true, "delivery": pending.duplicate(true), "ledger": next}


static func delivery_matches(ledger: Dictionary, request_key: String, action_id: String, trusted_context: Dictionary, stake: int) -> Dictionary:
	var pending: Dictionary = ledger.get("pending_delivery", {})
	if str(pending.get("request_key", "")) != request_key:
		return {"ok": false, "error_code": "stale_boundary"}
	var issued := issue_delivery(ledger, action_id, trusted_context, stake, ledger.get("pending_recovery_session", {}))
	if not bool(issued.get("ok", false)):
		return issued
	return {"ok": true, "delivery": pending.duplicate(true)}


static func cancel_delivery(ledger: Dictionary, delivery: Dictionary) -> Dictionary:
	var pending: Dictionary = ledger.get("pending_delivery", {})
	if not _closed_shape(delivery, DELIVERY_KEYS) \
			or RuntimeScript.canonical_json(delivery) != RuntimeScript.canonical_json(pending):
		return {"ok": false, "error_code": "receipt_content_conflict", "ledger": ledger.duplicate(true)}
	var next := ledger.duplicate(true)
	next["session"] = (next.get("pending_recovery_session", {}) as Dictionary).duplicate(true)
	next["pending_delivery"] = {}
	next["pending_recovery_session"] = {}
	return {"ok": true, "ledger": next}


static func cached_response(ledger: Dictionary, request_key: String, delivery: Dictionary) -> Dictionary:
	if not _closed_shape(delivery, DELIVERY_KEYS) or str(delivery.get("request_key", "")) != request_key:
		return {"ok": false, "error_code": "receipt_content_conflict"}
	var cache: Dictionary = ledger.get("request_cache", {})
	if not cache.has(request_key):
		return {}
	var entry: Dictionary = cache.get(request_key, {})
	if not _valid_cache_entry(entry, request_key, str(ledger.get("table_binding", ""))):
		return {"ok": false, "error_code": "invalid_cache"}
	for key in ["action_id", "boundary_ordinal", "intent_fingerprint", "recovery_session_fingerprint", "request_key", "stake", "trusted_context_fingerprint"]:
		if entry.get(key) != delivery.get(key):
			return {"ok": false, "error_code": "receipt_content_conflict"}
	return (entry.get("response", {}) as Dictionary).duplicate(true)


static func cached_replay_response(ledger: Dictionary, request_key: String, delivery: Dictionary) -> Dictionary:
	var response := cached_response(ledger, request_key, delivery)
	if response.is_empty() or (not bool(response.get("ok", false)) and response.has("error_code")):
		return response
	response["blackjack_host_replay"] = {
		"version": LEDGER_VERSION,
		"cause": REPLAY_CAUSE,
		"request_key": request_key,
		"delivery_fingerprint": RuntimeScript.canonical_fingerprint(delivery),
		"response_fingerprint": result_fingerprint(response),
	}
	return response


static func valid_cached_replay(ledger: Dictionary, replay: Dictionary) -> bool:
	var marker_value: Variant = replay.get("blackjack_host_replay", null)
	var delivery_value: Variant = replay.get("blackjack_host_delivery", null)
	if typeof(marker_value) != TYPE_DICTIONARY or typeof(delivery_value) != TYPE_DICTIONARY:
		return false
	var marker: Dictionary = marker_value
	var delivery: Dictionary = delivery_value
	var request_key := str(marker.get("request_key", ""))
	if not _closed_shape(marker, REPLAY_MARKER_KEYS) \
			or int(marker.get("version", 0)) != LEDGER_VERSION \
			or str(marker.get("cause", "")) != REPLAY_CAUSE \
			or request_key.is_empty() \
			or request_key != str(delivery.get("request_key", "")) \
			or str(marker.get("delivery_fingerprint", "")) != RuntimeScript.canonical_fingerprint(delivery):
		return false
	var canonical_replay := replay.duplicate(true)
	canonical_replay.erase("blackjack_host_replay")
	if str(marker.get("response_fingerprint", "")) != result_fingerprint(canonical_replay):
		return false
	var cached := cached_response(ledger, request_key, delivery)
	return not cached.is_empty() \
		and not (not bool(cached.get("ok", false)) and cached.has("error_code")) \
		and RuntimeScript.canonical_json(cached) == RuntimeScript.canonical_json(canonical_replay)


static func result_fingerprint(result: Dictionary) -> String:
	var content := result.duplicate(true)
	content.erase("blackjack_host_apply_receipt")
	content.erase("blackjack_host_content_fingerprint")
	return RuntimeScript.canonical_fingerprint(content)


static func receipt_for(delivery: Dictionary, table_binding: String, result: Dictionary, proposal_fingerprint: String, run_fingerprint: String, rng_fingerprint: String) -> Dictionary:
	return {
		"version": LEDGER_VERSION,
		"cause": RECEIPT_CAUSE,
		"table_binding": table_binding,
		"request_key": str(delivery.get("request_key", "")),
		"boundary_ordinal": int(delivery.get("boundary_ordinal", -1)),
		"intent_fingerprint": str(delivery.get("intent_fingerprint", "")),
		"trusted_context_fingerprint": str(delivery.get("trusted_context_fingerprint", "")),
		"recovery_session_fingerprint": str(delivery.get("recovery_session_fingerprint", "")),
		"stake": int(delivery.get("stake", 0)),
		"proposal_fingerprint": proposal_fingerprint,
		"run_fingerprint": run_fingerprint,
		"rng_fingerprint": rng_fingerprint,
		"result_fingerprint": result_fingerprint(result),
	}


static func valid_receipt(receipt: Variant, pending: Variant, result: Dictionary, table_binding: String) -> bool:
	if typeof(receipt) != TYPE_DICTIONARY or typeof(pending) != TYPE_DICTIONARY:
		return false
	var provided: Dictionary = receipt
	var expected: Dictionary = pending
	if not _closed_shape(provided, RECEIPT_KEYS) or not _closed_shape(expected, RECEIPT_KEYS):
		return false
	if RuntimeScript.canonical_json(provided) != RuntimeScript.canonical_json(expected):
		return false
	return int(provided.get("version", 0)) == LEDGER_VERSION \
		and str(provided.get("cause", "")) == RECEIPT_CAUSE \
		and str(provided.get("table_binding", "")) == table_binding \
		and _fingerprint(provided.get("proposal_fingerprint")) \
		and _fingerprint(provided.get("run_fingerprint")) \
		and _fingerprint(provided.get("rng_fingerprint")) \
		and str(provided.get("result_fingerprint", "")) == result_fingerprint(result)


static func commit_response(ledger: Dictionary, delivery: Dictionary, response: Dictionary, proposal_fingerprint: String, run_fingerprint: String, rng_fingerprint: String, checkpoint_fingerprint: String) -> Dictionary:
	var next := ledger.duplicate(true)
	var request_key := str(delivery.get("request_key", ""))
	var result_hash := result_fingerprint(response)
	var cache: Dictionary = next.get("request_cache", {})
	var order: Array = next.get("request_order", [])
	cache[request_key] = {
		"request_key": request_key,
		"action_id": str(delivery.get("action_id", "")),
		"boundary_ordinal": int(delivery.get("boundary_ordinal", -1)),
		"intent_fingerprint": str(delivery.get("intent_fingerprint", "")),
		"trusted_context_fingerprint": str(delivery.get("trusted_context_fingerprint", "")),
		"recovery_session_fingerprint": str(delivery.get("recovery_session_fingerprint", "")),
		"stake": int(delivery.get("stake", 0)),
		"proposal_fingerprint": proposal_fingerprint,
		"run_fingerprint": run_fingerprint,
		"rng_fingerprint": rng_fingerprint,
		"result_fingerprint": result_hash,
		"response": response.duplicate(true),
	}
	if not order.has(request_key):
		order.append(request_key)
	while order.size() > CACHE_LIMIT:
		cache.erase(str(order.pop_front()))
	next["request_cache"] = cache
	next["request_order"] = order
	var previous := str(next.get("journal_head", ""))
	var journal_entry := {
		"request_key": request_key,
		"boundary_ordinal": int(delivery.get("boundary_ordinal", -1)),
		"intent_fingerprint": str(delivery.get("intent_fingerprint", "")),
		"trusted_context_fingerprint": str(delivery.get("trusted_context_fingerprint", "")),
		"recovery_session_fingerprint": str(delivery.get("recovery_session_fingerprint", "")),
		"stake": int(delivery.get("stake", 0)),
		"proposal_fingerprint": proposal_fingerprint,
		"run_fingerprint": run_fingerprint,
		"rng_fingerprint": rng_fingerprint,
		"result_fingerprint": result_hash,
		"previous_fingerprint": previous,
	}
	journal_entry["entry_fingerprint"] = RuntimeScript.canonical_fingerprint(journal_entry)
	var journal: Array = next.get("journal", [])
	journal.append(journal_entry)
	while journal.size() > JOURNAL_LIMIT:
		journal.pop_front()
		if not journal.is_empty():
			(journal[0] as Dictionary)["previous_fingerprint"] = ""
			_rehash_journal(journal)
	next["journal"] = journal
	next["journal_head"] = str((journal[-1] as Dictionary).get("entry_fingerprint", "")) if not journal.is_empty() else ""
	next["pending_delivery"] = {}
	next["pending_recovery_session"] = {}
	next["checkpoint_fingerprint"] = checkpoint_fingerprint
	return next


static func _valid_delivery(delivery: Dictionary, ledger: Dictionary) -> bool:
	return _closed_shape(delivery, DELIVERY_KEYS) \
		and not str(delivery.get("request_key", "")).is_empty() \
		and not str(delivery.get("action_id", "")).is_empty() \
		and int(delivery.get("stake", -1)) >= 0 \
		and int(delivery.get("boundary_ordinal", -1)) == int(ledger.get("boundary_ordinal", -2)) \
		and str(delivery.get("intent_fingerprint", "")) == RuntimeScript.canonical_fingerprint({
			"action_id": str(delivery.get("action_id", "")),
			"session": ledger.get("session", {}),
		}) \
		and _fingerprint(delivery.get("intent_fingerprint")) \
		and _fingerprint(delivery.get("recovery_session_fingerprint")) \
		and _fingerprint(delivery.get("trusted_context_fingerprint"))


static func _valid_cache_entry(value: Variant, request_key: String, table_binding: String) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var entry: Dictionary = value
	if not _closed_shape(entry, CACHE_ENTRY_KEYS) \
			or str(entry.get("request_key", "")) != request_key \
			or typeof(entry.get("response", null)) != TYPE_DICTIONARY:
		return false
	var response: Dictionary = entry.get("response", {})
	if str(entry.get("result_fingerprint", "")) != result_fingerprint(response) \
			or str(response.get("blackjack_host_request_key", "")) != request_key \
			or str(response.get("blackjack_host_content_fingerprint", "")) != str(entry.get("result_fingerprint", "")):
		return false
	for fingerprint_key in ["intent_fingerprint", "proposal_fingerprint", "recovery_session_fingerprint", "run_fingerprint", "rng_fingerprint", "trusted_context_fingerprint"]:
		if not _fingerprint(entry.get(fingerprint_key)):
			return false
	if int(entry.get("stake", -1)) < 0:
		return false
	var delivery: Dictionary = response.get("blackjack_host_delivery", {}) if typeof(response.get("blackjack_host_delivery", {})) == TYPE_DICTIONARY else {}
	if not _closed_shape(delivery, DELIVERY_KEYS):
		return false
	for delivery_key in ["action_id", "boundary_ordinal", "intent_fingerprint", "recovery_session_fingerprint", "request_key", "stake", "trusted_context_fingerprint"]:
		if delivery.get(delivery_key) != entry.get(delivery_key):
			return false
	var receipt: Dictionary = response.get("blackjack_host_apply_receipt", {}) if typeof(response.get("blackjack_host_apply_receipt", {})) == TYPE_DICTIONARY else {}
	if not _closed_shape(receipt, RECEIPT_KEYS):
		return false
	if str(receipt.get("table_binding", "")) != table_binding \
			or not _binding_matches_response(table_binding, response):
		return false
	for receipt_key in ["boundary_ordinal", "intent_fingerprint", "proposal_fingerprint", "recovery_session_fingerprint", "request_key", "result_fingerprint", "rng_fingerprint", "run_fingerprint", "stake", "trusted_context_fingerprint"]:
		if receipt.get(receipt_key) != entry.get(receipt_key):
			return false
	return valid_receipt(receipt, receipt, response, str(receipt.get("table_binding", "")))


static func _binding_matches_response(table_binding: String, response: Dictionary) -> bool:
	var environment_id := str(response.get("environment_id", ""))
	var game_id := str(response.get("game_id", response.get("source_id", "")))
	if environment_id.is_empty() or game_id.is_empty():
		return false
	return table_binding.begins_with("%s:%s:" % [game_id, environment_id])


static func _valid_journal_entry(entry: Dictionary, previous: String) -> bool:
	if not _closed_shape(entry, JOURNAL_ENTRY_KEYS) or str(entry.get("previous_fingerprint", "")) != previous:
		return false
	var content := entry.duplicate(true)
	var fingerprint := str(content.get("entry_fingerprint", ""))
	content.erase("entry_fingerprint")
	return _fingerprint(fingerprint) and fingerprint == RuntimeScript.canonical_fingerprint(content)


static func _rehash_journal(journal: Array) -> void:
	var previous := ""
	for index in range(journal.size()):
		var entry: Dictionary = (journal[index] as Dictionary).duplicate(true)
		entry["previous_fingerprint"] = previous
		entry.erase("entry_fingerprint")
		entry["entry_fingerprint"] = RuntimeScript.canonical_fingerprint(entry)
		previous = str(entry.get("entry_fingerprint", ""))
		journal[index] = entry


static func _closed_shape(value: Dictionary, expected_keys: Array) -> bool:
	var actual := value.keys()
	actual.sort()
	var expected := expected_keys.duplicate()
	expected.sort()
	return actual == expected


static func _fingerprint(value: Variant) -> bool:
	var text := str(value)
	return text.length() == 64 and text.is_valid_hex_number(false)
