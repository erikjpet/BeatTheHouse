class_name BlackjackActionAuthority
extends RefCounted

# Production Blackjack transaction root.  Callers submit only an action intent;
# this object derives the saved session, wager, funding and RNG from the trusted
# RunState it was constructed with.  All candidate work happens on a detached
# RunState and is published only after the complete action succeeds.

const RuntimeScript := preload("res://scripts/core/game_ritual_runtime.gd")
const CACHE_LIMIT := 128
const LEDGER_KEY := "_blackjack_action_authority"
const LEDGER_VERSION := 1

class HostLease:
	extends RefCounted
	var request_key := ""
	var context_fingerprint := ""
	var consumed := false

var _game
var _run_state: RunState
var _environment: Dictionary
var _trusted_stake := 0
var _rng_stream_tag := ""


func _init(game, run_state: RunState, environment: Dictionary, trusted_stake: int = 0, rng_stream_tag: String = "") -> void:
	_game = game
	_run_state = run_state
	_environment = environment
	_trusted_stake = maxi(0, trusted_stake)
	_rng_stream_tag = rng_stream_tag


func preview_wager_cost(action_id: String) -> int:
	if not _ready() or action_id.is_empty():
		return 0
	var candidate := _detached_run_state()
	if candidate == null:
		return 0
	var candidate_environment := candidate.current_environment
	var ledger := _ledger(candidate, candidate_environment, true)
	var session: Dictionary = (ledger.get("session", {}) as Dictionary).duplicate(true)
	var lease := HostLease.new()
	lease.request_key = "preview"
	lease.context_fingerprint = _context_fingerprint(action_id, session)
	_game.call("_blackjack_begin_host_lease", lease)
	var cost := int(_game.call("_blackjack_wager_cost_with_host_lease", lease, action_id, _trusted_stake, candidate, candidate_environment, session))
	_game.call("_blackjack_end_host_lease", lease)
	return maxi(0, cost)


func submit_surface_intent(surface_action: String, index: int, confirm_requested: bool = false) -> Dictionary:
	if not _ready() or surface_action.is_empty():
		return _rejection("invalid_intent", "Blackjack action intent is unavailable.")
	var candidate := _detached_run_state()
	if candidate == null:
		return _rejection("internal_fail_closed", "Blackjack authority could not create a detached candidate.")
	var candidate_environment := candidate.current_environment
	var table: Dictionary = _game.call("_table_state", candidate, candidate_environment)
	var ledger := _ledger_from_table(table, true)
	var request_key := _next_request_key(ledger)
	var session: Dictionary = (ledger.get("session", {}) as Dictionary).duplicate(true)
	if not _game.call("_has_dealt_hand", session) and _trusted_stake > 0:
		session["selected_stake"] = _trusted_stake
	var command: Dictionary = _game.surface_action_command(surface_action, index, confirm_requested, session, candidate, candidate_environment)
	if command.is_empty() or not bool(command.get("handled", false)):
		return _rejection("unavailable_action", "Blackjack rejected that action without changing state.", request_key)
	var next_session: Dictionary = command.get("ui_state", session) if typeof(command.get("ui_state", session)) == TYPE_DICTIONARY else session
	ledger["session"] = next_session.duplicate(true)
	if candidate.grand_casino_duel_active(candidate_environment):
		candidate.persist_grand_casino_duel_session(next_session)
	ledger["boundary_ordinal"] = int(ledger.get("boundary_ordinal", 0)) + 1
	ledger["next_request_ordinal"] = int(ledger.get("next_request_ordinal", 1)) + 1
	if bool(command.get("direct_resolve", false)) or bool(command.get("resolve", false)):
		ledger["pending_request_key"] = request_key
		ledger["pending_action_id"] = str(command.get("action_id", ""))
	else:
		ledger.erase("pending_request_key")
		ledger.erase("pending_action_id")
	table[LEDGER_KEY] = ledger
	_game.call("_update_environment_table", candidate_environment, table)
	if not _publish(candidate):
		return _rejection("internal_fail_closed", "Blackjack authority could not publish the staged action.", request_key)
	command["blackjack_host_request_key"] = request_key
	command["blackjack_host_boundary_ordinal"] = int(ledger.get("boundary_ordinal", 0))
	return command


func needs_auto_tick(surface_time_msec: int) -> bool:
	if not _ready():
		return false
	var candidate := _detached_run_state()
	if candidate == null:
		return false
	var candidate_environment := candidate.current_environment
	var ledger := _ledger(candidate, candidate_environment, true)
	var session: Dictionary = (ledger.get("session", {}) as Dictionary).duplicate(true)
	session["surface_time_msec"] = surface_time_msec
	return bool(_game.surface_needs_auto_tick(session, candidate, candidate_environment))


func submit_auto_intent(surface_time_msec: int) -> Dictionary:
	if not _ready():
		return _rejection("invalid_intent", "Blackjack auto action intent is unavailable.")
	var candidate := _detached_run_state()
	if candidate == null:
		return _rejection("internal_fail_closed", "Blackjack authority could not create a detached candidate.")
	var candidate_environment := candidate.current_environment
	var table: Dictionary = _game.call("_table_state", candidate, candidate_environment)
	var ledger := _ledger_from_table(table, true)
	var request_key := _next_request_key(ledger)
	var session: Dictionary = (ledger.get("session", {}) as Dictionary).duplicate(true)
	session["surface_time_msec"] = surface_time_msec
	var command: Dictionary = _game.surface_auto_action_command(session, candidate, candidate_environment, {})
	# The timer can legitimately initialize on an unhandled tick. Publish that
	# candidate-owned table mutation, but only an accepted command advances the
	# durable Blackjack action boundary.
	if bool(command.get("handled", false)):
		var next_session: Dictionary = command.get("ui_state", session) if typeof(command.get("ui_state", session)) == TYPE_DICTIONARY else session
		ledger["session"] = next_session.duplicate(true)
		ledger["boundary_ordinal"] = int(ledger.get("boundary_ordinal", 0)) + 1
		ledger["next_request_ordinal"] = int(ledger.get("next_request_ordinal", 1)) + 1
		if bool(command.get("direct_resolve", false)) or bool(command.get("resolve", false)):
			ledger["pending_request_key"] = request_key
			ledger["pending_action_id"] = str(command.get("action_id", ""))
		else:
			ledger.erase("pending_request_key")
			ledger.erase("pending_action_id")
		table = _game.call("_table_state", candidate, candidate_environment)
		table[LEDGER_KEY] = ledger
		_game.call("_update_environment_table", candidate_environment, table)
	if not _publish(candidate):
		return _rejection("internal_fail_closed", "Blackjack authority could not publish the auto action.", request_key)
	if bool(command.get("handled", false)):
		command["blackjack_host_request_key"] = request_key
		command["blackjack_host_boundary_ordinal"] = int(ledger.get("boundary_ordinal", 0))
	return command


func submit_resolve_intent(action_id: String) -> Dictionary:
	if not _ready() or action_id.is_empty():
		return _rejection("invalid_intent", "Blackjack action intent is unavailable.")
	var live_table: Dictionary = _game.call("_table_state_preview", _run_state, _environment)
	var live_ledger := _ledger_from_table(live_table, true)
	var pending_action := str(live_ledger.get("pending_action_id", ""))
	var request_key := str(live_ledger.get("pending_request_key", ""))
	if request_key.is_empty() or (not pending_action.is_empty() and pending_action != action_id):
		request_key = _next_request_key(live_ledger)
	var live_cache: Dictionary = live_ledger.get("request_cache", {}) if typeof(live_ledger.get("request_cache", {})) == TYPE_DICTIONARY else {}
	if live_cache.has(request_key):
		var cached: Dictionary = live_cache[request_key]
		if str(cached.get("action_id", "")) != action_id:
			return _rejection("receipt_content_conflict", "Blackjack request receipt is bound to different content.", request_key)
		return (cached.get("response", {}) as Dictionary).duplicate(true)

	var candidate := _detached_run_state()
	if candidate == null:
		return _rejection("internal_fail_closed", "Blackjack authority could not create a detached candidate.", request_key)
	var candidate_environment := candidate.current_environment
	var table: Dictionary = _game.call("_table_state", candidate, candidate_environment)
	var ledger := _ledger_from_table(table, true)
	var session: Dictionary = (ledger.get("session", {}) as Dictionary).duplicate(true)
	var context_fingerprint := _context_fingerprint(action_id, session)
	var lease := HostLease.new()
	lease.request_key = request_key
	lease.context_fingerprint = context_fingerprint
	_game.call("_blackjack_begin_host_lease", lease)
	var wager_cost := maxi(0, int(_game.call("_blackjack_wager_cost_with_host_lease", lease, action_id, _trusted_stake, candidate, candidate_environment, session)))
	var funding_preview: Dictionary = candidate.preview_grand_casino_wager_funding(_game.get_id(), wager_cost, candidate_environment)
	if not bool(funding_preview.get("ok", false)):
		_game.call("_blackjack_end_host_lease", lease)
		return _rejection("insufficient_funds", str(funding_preview.get("message", "You do not have enough cash or chips for that wager.")), request_key)
	if not bool(_game.call("_blackjack_consume_host_lease", lease)):
		_game.call("_blackjack_end_host_lease", lease)
		return _rejection("stale_lease", "Blackjack authority lease is missing or already consumed.", request_key)
	ledger["pending_apply_receipt"] = {"request_key": request_key, "context_fingerprint": context_fingerprint}
	table[LEDGER_KEY] = ledger
	_game.call("_update_environment_table", candidate_environment, table)
	var funding: Dictionary = candidate.fund_grand_casino_wager(_game.get_id(), wager_cost, candidate_environment)
	if not bool(funding.get("ok", false)):
		_game.call("_blackjack_end_host_lease", lease)
		return _rejection("insufficient_funds", str(funding.get("message", "You do not have enough cash or chips for that wager.")), request_key)
	var rng: RngStream = candidate.create_rng(_rng_stream_tag)
	var result: Dictionary = _game.call("_resolve_with_blackjack_host_lease", lease, action_id, _trusted_stake, candidate, candidate_environment, rng, session)
	_game.call("_blackjack_end_host_lease", lease)
	if not bool(result.get("ok", false)):
		return _stable_result_rejection(result, request_key)
	if bool(result.get("host_apply_result", false)):
		result["blackjack_host_apply_receipt"] = {"request_key": request_key, "context_fingerprint": context_fingerprint}
		GameModule.apply_result(candidate, result, rng)
	# Up-front all-in placement and caught-Peek reprieves intentionally defer the
	# zero-bankroll terminal check while a hand remains live. Advancing here would
	# clear that contract before the follow-up settlement can run.
	if not bool(result.get("defer_bankroll_zero_failure", false)):
		candidate.advance_environment_turns(1)
	var committed_session: Dictionary = {}
	if typeof(result.get("ui_state", null)) == TYPE_DICTIONARY:
		committed_session = (result.get("ui_state", {}) as Dictionary).duplicate(true)
	elif typeof(result.get("blackjack_surface_ui_state", null)) == TYPE_DICTIONARY:
		committed_session = (result.get("blackjack_surface_ui_state", {}) as Dictionary).duplicate(true)
	elif action_id != "play_basic":
		committed_session = session.duplicate(true)
	result["blackjack_host_committed"] = true
	result["blackjack_host_request_key"] = request_key
	result["blackjack_host_wager_cost"] = wager_cost
	result["blackjack_host_funding_lease"] = funding_preview.duplicate(true)
	result["blackjack_host_context_fingerprint"] = context_fingerprint
	result["blackjack_host_content_fingerprint"] = RuntimeScript.canonical_fingerprint(result)

	# Re-fetch after resolution because Blackjack may replace its table record.
	table = _game.call("_table_state", candidate, candidate_environment)
	ledger = _ledger_from_table(table, true)
	ledger["session"] = committed_session
	ledger["boundary_ordinal"] = int(ledger.get("boundary_ordinal", 0)) + 1
	if str(ledger.get("pending_request_key", "")) != request_key:
		ledger["next_request_ordinal"] = int(ledger.get("next_request_ordinal", 1)) + 1
	ledger.erase("pending_request_key")
	ledger.erase("pending_action_id")
	var cache: Dictionary = ledger.get("request_cache", {}) if typeof(ledger.get("request_cache", {})) == TYPE_DICTIONARY else {}
	var order: Array = ledger.get("request_order", []) if typeof(ledger.get("request_order", [])) == TYPE_ARRAY else []
	cache[request_key] = {"action_id": action_id, "context_fingerprint": context_fingerprint, "response": result.duplicate(true)}
	order.append(request_key)
	while order.size() > CACHE_LIMIT:
		cache.erase(str(order.pop_front()))
	ledger["request_cache"] = cache
	ledger["request_order"] = order
	table[LEDGER_KEY] = ledger
	_game.call("_update_environment_table", candidate_environment, table)
	if not _publish(candidate):
		return _rejection("internal_fail_closed", "Blackjack authority could not publish the accepted transaction.", request_key)
	return result


func replay_request(request_key: String) -> Dictionary:
	if not _ready() or request_key.is_empty():
		return _rejection("unknown_receipt", "Blackjack request receipt is unavailable.", request_key)
	var table: Dictionary = _game.call("_table_state_preview", _run_state, _environment)
	var ledger := _ledger_from_table(table, false)
	var cache: Dictionary = ledger.get("request_cache", {}) if typeof(ledger.get("request_cache", {})) == TYPE_DICTIONARY else {}
	if not cache.has(request_key):
		return _rejection("unknown_receipt", "Blackjack request receipt is unavailable.", request_key)
	return ((cache[request_key] as Dictionary).get("response", {}) as Dictionary).duplicate(true)


func _ready() -> bool:
	return _game != null and _run_state != null and not _environment.is_empty() and _game.get_id() == "blackjack"


func _detached_run_state() -> RunState:
	var candidate := RunState.new()
	candidate.from_dict(_run_state.to_save_snapshot())
	return candidate


func _publish(candidate: RunState) -> bool:
	# Validate the exact serialization boundary before touching live state.
	# RunState normalization is part of publication, so compare two normalized
	# round trips rather than a raw in-memory candidate with its normalized form.
	var normalized_candidate := RunState.new()
	normalized_candidate.from_dict(candidate.to_save_snapshot())
	var normalized_snapshot := normalized_candidate.to_save_snapshot()
	var verifier := RunState.new()
	verifier.from_dict(normalized_snapshot)
	if RuntimeScript.canonical_fingerprint(verifier.to_save_snapshot()) != RuntimeScript.canonical_fingerprint(normalized_snapshot):
		return false
	var original_snapshot := _run_state.to_save_snapshot()
	var original_environment := _environment.duplicate(true)
	_run_state.from_dict(normalized_snapshot)
	# Keep the environment Dictionary identity held by FoundationMain/callers.
	var published_environment := _run_state.current_environment.duplicate(true)
	_environment.clear()
	for key in published_environment:
		_environment[key] = published_environment[key]
	_run_state.current_environment = _environment
	var live_snapshot := _run_state.to_save_snapshot()
	if RuntimeScript.canonical_fingerprint(live_snapshot) == RuntimeScript.canonical_fingerprint(normalized_snapshot):
		return true
	# A publication mismatch must remain failure-atomic even though it should be
	# unreachable after the shadow verification above.
	_run_state.from_dict(original_snapshot)
	_environment.clear()
	for key in original_environment:
		_environment[key] = original_environment[key]
	_run_state.current_environment = _environment
	return false


func _ledger(run_state: RunState, environment: Dictionary, create: bool) -> Dictionary:
	var table: Dictionary = _game.call("_table_state", run_state, environment) if create else _game.call("_table_state_preview", run_state, environment)
	return _ledger_from_table(table, create)


func _ledger_from_table(table: Dictionary, create: bool) -> Dictionary:
	var value: Variant = table.get(LEDGER_KEY, {})
	if typeof(value) == TYPE_DICTIONARY and int((value as Dictionary).get("version", 0)) == LEDGER_VERSION:
		return (value as Dictionary).duplicate(true)
	if not create:
		return {}
	return {
		"version": LEDGER_VERSION,
		"initialized": true,
		"next_request_ordinal": 1,
		"boundary_ordinal": 0,
		"session": {},
		"request_cache": {},
		"request_order": [],
	}


func _next_request_key(ledger: Dictionary) -> String:
	var session: Dictionary = ledger.get("session", {}) if typeof(ledger.get("session", {})) == TYPE_DICTIONARY else {}
	var session_id := str(session.get("session_id", "%s:%s" % [_game.get_id(), str(_environment.get("id", "table"))]))
	return "blackjack:%s:%d" % [session_id.replace(" ", "_").replace(":", "_"), maxi(1, int(ledger.get("next_request_ordinal", 1)))]


func _context_fingerprint(action_id: String, session: Dictionary) -> String:
	return RuntimeScript.canonical_fingerprint({"action_id": action_id, "stake": _trusted_stake, "session": session})


func _stable_result_rejection(result: Dictionary, request_key: String) -> Dictionary:
	var rejection := result.duplicate(true)
	rejection["ok"] = false
	rejection["blackjack_host_request_key"] = request_key
	rejection["blackjack_host_committed"] = false
	return rejection


func _rejection(error_code: String, message: String, request_key: String = "") -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"message": message,
		"request_key": request_key,
		"blackjack_host_committed": false,
	}
