class_name BlackjackActionAuthority
extends RefCounted

# Pure Blackjack authority vocabulary and closed validation engine. This type
# owns no Object, RunState, environment, account, RNG, clock, Callable, or
# capability. FoundationMain is the sole live transaction host; callers may use
# these helpers to form/inspect proposals, but this engine can mutate nothing.

const RuntimeScript := preload("res://scripts/core/game_ritual_runtime.gd")
const LEDGER_KEY := "_blackjack_action_authority"
const LEDGER_VERSION := 2
const CACHE_LIMIT := 128
const JOURNAL_LIMIT := 128
const RECEIPT_CAUSE := "foundation_main:blackjack_action"

const LEDGER_KEYS := [
	"boundary_ordinal",
	"initialized",
	"journal",
	"journal_head",
	"next_request_ordinal",
	"pending_delivery",
	"request_cache",
	"request_order",
	"session",
	"table_binding",
	"version",
]
const DELIVERY_KEYS := ["action_id", "boundary_ordinal", "intent_fingerprint", "request_key", "trusted_context_fingerprint"]
const CACHE_ENTRY_KEYS := ["action_id", "boundary_ordinal", "intent_fingerprint", "request_key", "response", "result_fingerprint", "trusted_context_fingerprint"]
const JOURNAL_ENTRY_KEYS := ["boundary_ordinal", "entry_fingerprint", "intent_fingerprint", "previous_fingerprint", "request_key", "result_fingerprint", "trusted_context_fingerprint"]
const RECEIPT_KEYS := ["boundary_ordinal", "cause", "intent_fingerprint", "request_key", "result_fingerprint", "table_binding", "trusted_context_fingerprint", "version"]


static func default_ledger(table_binding: String) -> Dictionary:
	return {
		"version": LEDGER_VERSION,
		"initialized": true,
		"table_binding": table_binding,
		"next_request_ordinal": 1,
		"boundary_ordinal": 0,
		"session": {},
		"pending_delivery": {},
		"request_cache": {},
		"request_order": [],
		"journal": [],
		"journal_head": "",
	}


static func validate_persisted_ledger(value: Variant, table_binding: String) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var ledger: Dictionary = (value as Dictionary).duplicate(true)
	if not _closed_shape(ledger, LEDGER_KEYS) \
			or int(ledger.get("version", 0)) != LEDGER_VERSION \
			or not bool(ledger.get("initialized", false)) \
			or str(ledger.get("table_binding", "")) != table_binding \
			or int(ledger.get("next_request_ordinal", 0)) < 1 \
			or int(ledger.get("boundary_ordinal", -1)) < 0 \
			or typeof(ledger.get("session", null)) != TYPE_DICTIONARY \
			or typeof(ledger.get("pending_delivery", null)) != TYPE_DICTIONARY \
			or typeof(ledger.get("request_cache", null)) != TYPE_DICTIONARY \
			or typeof(ledger.get("request_order", null)) != TYPE_ARRAY \
			or typeof(ledger.get("journal", null)) != TYPE_ARRAY:
		return {}
	var pending: Dictionary = ledger.get("pending_delivery", {})
	if not pending.is_empty() and not _valid_delivery(pending, ledger):
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
		if not _valid_cache_entry(cache.get(request_key), request_key):
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
		for causal_key in ["boundary_ordinal", "intent_fingerprint", "request_key", "result_fingerprint", "trusted_context_fingerprint"]:
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


static func issue_delivery(ledger: Dictionary, action_id: String, trusted_context: Dictionary) -> Dictionary:
	var next := ledger.duplicate(true)
	var intent_fingerprint := RuntimeScript.canonical_fingerprint({
		"action_id": action_id,
		"session": next.get("session", {}),
	})
	var trusted_context_fingerprint := RuntimeScript.canonical_fingerprint(trusted_context)
	var pending: Dictionary = next.get("pending_delivery", {})
	if not pending.is_empty():
		if str(pending.get("action_id", "")) != action_id \
				or str(pending.get("intent_fingerprint", "")) != intent_fingerprint \
				or str(pending.get("trusted_context_fingerprint", "")) != trusted_context_fingerprint:
			return {"ok": false, "error_code": "receipt_content_conflict", "ledger": ledger.duplicate(true)}
		return {"ok": true, "delivery": pending.duplicate(true), "ledger": next}
	var boundary := int(next.get("boundary_ordinal", 0)) + 1
	var ordinal := int(next.get("next_request_ordinal", 1))
	var request_key := "blackjack:%s:%d" % [str(next.get("table_binding", "table")).replace(":", "_"), ordinal]
	pending = {
		"request_key": request_key,
		"action_id": action_id,
		"boundary_ordinal": boundary,
		"intent_fingerprint": intent_fingerprint,
		"trusted_context_fingerprint": trusted_context_fingerprint,
	}
	next["pending_delivery"] = pending
	next["boundary_ordinal"] = boundary
	next["next_request_ordinal"] = ordinal + 1
	return {"ok": true, "delivery": pending.duplicate(true), "ledger": next}


static func delivery_matches(ledger: Dictionary, request_key: String, action_id: String, trusted_context: Dictionary) -> Dictionary:
	var pending: Dictionary = ledger.get("pending_delivery", {})
	if str(pending.get("request_key", "")) != request_key:
		return {"ok": false, "error_code": "stale_boundary"}
	var issued := issue_delivery(ledger, action_id, trusted_context)
	if not bool(issued.get("ok", false)):
		return issued
	return {"ok": true, "delivery": pending.duplicate(true)}


static func cached_response(ledger: Dictionary, request_key: String, delivery: Dictionary) -> Dictionary:
	var cache: Dictionary = ledger.get("request_cache", {})
	if not cache.has(request_key):
		return {}
	var entry: Dictionary = cache.get(request_key, {})
	if not _valid_cache_entry(entry, request_key):
		return {"ok": false, "error_code": "invalid_cache"}
	for key in ["action_id", "boundary_ordinal", "intent_fingerprint", "trusted_context_fingerprint"]:
		if entry.get(key) != delivery.get(key):
			return {"ok": false, "error_code": "receipt_content_conflict"}
	return (entry.get("response", {}) as Dictionary).duplicate(true)


static func result_fingerprint(result: Dictionary) -> String:
	var content := result.duplicate(true)
	content.erase("blackjack_host_apply_receipt")
	content.erase("blackjack_host_content_fingerprint")
	return RuntimeScript.canonical_fingerprint(content)


static func receipt_for(delivery: Dictionary, table_binding: String, result: Dictionary) -> Dictionary:
	return {
		"version": LEDGER_VERSION,
		"cause": RECEIPT_CAUSE,
		"table_binding": table_binding,
		"request_key": str(delivery.get("request_key", "")),
		"boundary_ordinal": int(delivery.get("boundary_ordinal", -1)),
		"intent_fingerprint": str(delivery.get("intent_fingerprint", "")),
		"trusted_context_fingerprint": str(delivery.get("trusted_context_fingerprint", "")),
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
		and str(provided.get("result_fingerprint", "")) == result_fingerprint(result)


static func commit_response(ledger: Dictionary, delivery: Dictionary, response: Dictionary) -> Dictionary:
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
	return next


static func _valid_delivery(delivery: Dictionary, ledger: Dictionary) -> bool:
	return _closed_shape(delivery, DELIVERY_KEYS) \
		and not str(delivery.get("request_key", "")).is_empty() \
		and not str(delivery.get("action_id", "")).is_empty() \
		and int(delivery.get("boundary_ordinal", -1)) == int(ledger.get("boundary_ordinal", -2)) \
		and str(delivery.get("intent_fingerprint", "")) == RuntimeScript.canonical_fingerprint({
			"action_id": str(delivery.get("action_id", "")),
			"session": ledger.get("session", {}),
		}) \
		and _fingerprint(delivery.get("intent_fingerprint")) \
		and _fingerprint(delivery.get("trusted_context_fingerprint"))


static func _valid_cache_entry(value: Variant, request_key: String) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var entry: Dictionary = value
	return _closed_shape(entry, CACHE_ENTRY_KEYS) \
		and str(entry.get("request_key", "")) == request_key \
		and typeof(entry.get("response", null)) == TYPE_DICTIONARY \
		and str(entry.get("result_fingerprint", "")) == result_fingerprint(entry.get("response", {})) \
		and str((entry.get("response", {}) as Dictionary).get("blackjack_host_request_key", "")) == request_key \
		and str((entry.get("response", {}) as Dictionary).get("blackjack_host_content_fingerprint", "")) == str(entry.get("result_fingerprint", "")) \
		and _fingerprint(entry.get("intent_fingerprint")) \
		and _fingerprint(entry.get("trusted_context_fingerprint"))


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
