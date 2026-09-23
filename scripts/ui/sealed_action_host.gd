class_name SealedActionHost
extends RefCounted

const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")
const PlayerTextScript := preload("res://scripts/ui/player_text.gd")
const GameRitualRuntimeScript := preload("res://scripts/core/game_ritual_runtime.gd")

var _foundation: Object


func _init(foundation: Object) -> void:
	_foundation = foundation


func bind(foundation: Object) -> SealedActionHost:
	_foundation = foundation
	return self


func surface_intent(surface_action: String, index: int, confirm_requested: bool = false, surface_time_msec: int = -1) -> Dictionary:
	if _foundation == null:
		return {"ok": false, "error_code": "missing_host", "message": "Sealed action host is unavailable."}
	return _sealed_action_host_surface_intent_impl(surface_action, index, confirm_requested, surface_time_msec)


func _sealed_action_host_table_binding(environment: Dictionary = {}) -> String:
	var source = environment if not environment.is_empty() else (_foundation.run_state.current_environment if _foundation.run_state != null else {})
	# A venue can contain several independently generated cabinets for one game.
	# Their sealed receipts must not share an identity: otherwise cabinet 2 can
	# collide with cabinet 1's already-consumed request key and fail as stale.
	var state_key := _sealed_action_host_state_key()
	return RunState.action_authority_table_binding(state_key, source)


func _sealed_action_host_state_key() -> String:
	if _foundation.current_game == null:
		return ""
	var game_id = _foundation.current_game.get_id()
	var state_key = _foundation.current_game_state_key.strip_edges()
	if state_key.is_empty():
		state_key = _foundation.current_game.transient_state_key_context().strip_edges()
	if state_key == game_id or state_key.begins_with("%s:" % game_id):
		return state_key
	return game_id


func _sealed_action_host_ledger(candidate: RunState, create: bool = true, reconcile_checkpoint: bool = true) -> Dictionary:
	if candidate == null or not _foundation._current_game_uses_action_authority():
		return {}
	var environment := candidate.current_environment
	var table: Dictionary = _foundation.current_game.call("_table_state", candidate, environment) if create else _foundation.current_game.call("_table_state_preview", candidate, environment)
	var binding := _sealed_action_host_table_binding(environment)
	var expected_checkpoint := candidate.action_authority_checkpoint_fingerprint() if reconcile_checkpoint else ""
	var persisted_ledger: Variant = table.get(_foundation.ActionAuthorityScript.LEDGER_KEY, {})
	var validated: Dictionary = _foundation.ActionAuthorityScript.validate_persisted_ledger_cow(persisted_ledger, binding, expected_checkpoint)
	if not validated.is_empty() or not create:
		return validated
	# A trusted live account/RNG change invalidates replay evidence, but it must not
	# erase the table session the player can still see (for example, Blackjack side
	# bets while a background wager changes available funds). Rebase only a fully
	# valid, delivery-free ledger: old responses/journal are discarded, pending
	# authority is never carried across a checkpoint, and request identity remains
	# monotonic. Hostile save restoration strips mismatched ledgers before this live
	# boundary, so this path reconciles only state already owned by the active run.
	if reconcile_checkpoint:
		var prior: Dictionary = _foundation.ActionAuthorityScript.validate_persisted_ledger_cow(persisted_ledger, binding)
		if not prior.is_empty() and (prior.get("pending_delivery", {}) as Dictionary).is_empty():
			var rebased: Dictionary = _foundation.ActionAuthorityScript.default_ledger(binding, expected_checkpoint)
			rebased["session"] = (prior.get("session", {}) as Dictionary).duplicate(true)
			rebased["next_request_ordinal"] = maxi(1, int(prior.get("next_request_ordinal", 1)))
			rebased["boundary_ordinal"] = maxi(0, int(prior.get("boundary_ordinal", 0)))
			return rebased
	return _foundation.ActionAuthorityScript.default_ledger(binding, candidate.action_authority_checkpoint_fingerprint())


func _sealed_action_host_store_ledger(candidate: RunState, ledger: Dictionary) -> void:
	var environment := candidate.current_environment
	var table: Dictionary = _foundation.current_game.call("_table_state", candidate, environment)
	# Authority helpers are copy-on-write and cached response/journal values are
	# immutable. Isolate the top-level ledger binding without recursively cloning
	# the full replay window on every internal host stage.
	table[_foundation.ActionAuthorityScript.LEDGER_KEY] = ledger.duplicate(false)
	table.erase(_foundation.ActionAuthorityScript.PENDING_APPLY_RECEIPT_KEY)
	_foundation.current_game.call("_update_environment_table", environment, table)


func _sealed_action_host_compact_evidence_method() -> StringName:
	var method := StringName(_foundation.action_authority_contract.get("compact_authority_evidence_method", &""))
	if _foundation.current_game == null or method.is_empty() or not _foundation.current_game.has_method(method):
		return &""
	return method


func _sealed_action_host_compact_evidence_allowed(candidate: RunState, action_id: String, stake: int, session: Dictionary) -> bool:
	if candidate == null or _sealed_action_host_compact_evidence_method().is_empty():
		return false
	var predicate := StringName(_foundation.action_authority_contract.get("compact_authority_evidence_predicate_method", &""))
	return predicate.is_empty() or (_foundation.current_game.has_method(predicate) and bool(_foundation.current_game.call(predicate, candidate, action_id, stake, session)))


func _sealed_action_host_compact_evidence(candidate: RunState, action_id: String, stake: int, session: Dictionary) -> Dictionary:
	var method := _sealed_action_host_compact_evidence_method()
	if candidate == null or method.is_empty() or not _sealed_action_host_compact_evidence_allowed(candidate, action_id, stake, session):
		return {}
	var value: Variant = _foundation.current_game.call(method, candidate, action_id, stake, session)
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _sealed_action_host_trusted_context(candidate: RunState, stake: int, action_id: String = "") -> Dictionary:
	var environment := candidate.current_environment
	var canonical_run_fingerprint := ""
	var compact_evidence: Dictionary = {}
	# The delivery already binds action_id independently. Keep the canonical table
	# context action-neutral, matching the historical public helper and allowing a
	# sealed delivery to be compared with the same live state before resolution.
	if _sealed_action_host_compact_evidence_allowed(candidate, action_id, stake, {}):
		var evidence_method := _sealed_action_host_compact_evidence_method()
		var evidence_value: Variant = _foundation.current_game.call(evidence_method, candidate, "", stake, {})
		if typeof(evidence_value) == TYPE_DICTIONARY:
			compact_evidence = evidence_value as Dictionary
	if not compact_evidence.is_empty():
		canonical_run_fingerprint = GameRitualRuntimeScript.canonical_fingerprint(compact_evidence)
	else:
		var snapshot := candidate.to_save_snapshot()
		# These are host presentation caches, not simulation authority. The UI can
		# materialize their defaults between a sealed surface intent and synchronous
		# settlement, and authority-ledger writes intentionally bump the room render
		# revision. Binding either to a wager receipt makes a valid click fail closed
		# even though game state, funds, and RNG are unchanged.
		snapshot.erase("music_tempo_state")
		snapshot.erase("music_choreography_state")
		# Crew's per-run save authority is intentionally random and private. It is not
		# Blackjack action authority, so exclude only that opaque id/capsule from the
		# trusted-context fingerprint while retaining every public Crew state field.
		var crew_state: Dictionary = (snapshot.get("crew_state", {}) as Dictionary).duplicate(false) if typeof(snapshot.get("crew_state", {})) == TYPE_DICTIONARY else {}
		crew_state.erase("a")
		crew_state.erase("z")
		snapshot["crew_state"] = crew_state
		# Remove only host presentation/replay metadata from the canonical table.
		var snapshot_environment: Dictionary = (snapshot.get("current_environment", {}) as Dictionary).duplicate(false)
		snapshot_environment.erase("environment_runtime_revision")
		var game_states: Dictionary = (snapshot_environment.get("game_states", {}) as Dictionary).duplicate(false)
		var state_key := _sealed_action_host_state_key()
		if typeof(game_states.get(state_key, null)) == TYPE_DICTIONARY:
			var table: Dictionary = (game_states.get(state_key, {}) as Dictionary).duplicate(false)
			table.erase(_foundation.ActionAuthorityScript.LEDGER_KEY)
			table.erase(_foundation.ActionAuthorityScript.PENDING_APPLY_RECEIPT_KEY)
			game_states[state_key] = table
			snapshot_environment["game_states"] = game_states
			snapshot["current_environment"] = snapshot_environment
		canonical_run_fingerprint = GameRitualRuntimeScript.canonical_fingerprint(snapshot)
	return {
		"table_binding": _sealed_action_host_table_binding(environment),
		"environment_id": str(environment.get("id", "")),
		"environment_archetype_id": str(environment.get("archetype_id", "")),
		"stake": maxi(0, stake),
		"canonical_run_fingerprint": canonical_run_fingerprint,
		"account_rng_checkpoint_fingerprint": candidate.action_authority_checkpoint_fingerprint(),
	}


func _sealed_action_host_transient_run_snapshot(candidate: RunState) -> Dictionary:
	var snapshot := candidate.to_save_snapshot()
	if _foundation.current_game == null:
		return snapshot
	var environment: Dictionary = (snapshot.get("current_environment", {}) as Dictionary).duplicate(false) if typeof(snapshot.get("current_environment", {})) == TYPE_DICTIONARY else {}
	environment["active_game_id"] = _foundation.current_game.get_id()
	snapshot["current_environment"] = environment
	return snapshot


func _sealed_action_host_detached() -> RunState:
	if _foundation.run_state == null:
		return null
	var candidate = _foundation.run_state.detached_host_action_candidate(_sealed_action_host_state_key())
	if candidate == null or not candidate.scenario_sequence_present() or candidate._scenario_semantic_ready():
		return candidate
	# A loaded save intentionally marks renderer-derived scenario authority for
	# trusted reconstruction. Game actions can arrive before a full room redraw,
	# so repair the detached transaction itself instead of letting its environment
	# turn fail and strand a durable pending delivery.
	var finalized = candidate.scenario_finalize_installed_environment(
		_foundation.library,
		JsonCoerceScript._copy_dict(candidate.current_environment.get("scenario_layout_context", {}))
	)
	return candidate if bool(finalized.get("ok", false)) else null


func _sealed_action_host_can_commit_in_place() -> bool:
	return _foundation.run_state != null \
		and bool(_foundation.action_authority_contract.get("in_place_nonrejecting_commit", false)) \
		and _foundation.run_state.host_action_in_place_commit_safe()


func _sealed_action_host_transaction_candidate() -> RunState:
	return _foundation.run_state if _sealed_action_host_can_commit_in_place() else _sealed_action_host_detached()


func _sealed_action_host_delivery_stake(command: Dictionary, session: Dictionary) -> int:
	if command.has("set_stake"):
		return maxi(0, int(command.get("set_stake", 0)))
	if session.has("locked_stake"):
		var locked_stake := maxi(0, int(session.get("locked_stake", 0)))
		if locked_stake > 0:
			return locked_stake
	if session.has("selected_stake"):
		var selected_stake := maxi(0, int(session.get("selected_stake", 0)))
		if selected_stake > 0:
			return selected_stake
	# An undealt normalized session carries locked_stake=0. Fall back to the same
	# capacity-clamped value shown by the UI, never the stale raw host selection.
	return maxi(0, int(_foundation._current_selected_stake()))


func _sealed_action_host_in_place_session_intent_allowed(surface_action: String) -> bool:
	if _foundation.run_state == null or _foundation.run_state.is_terminal() or surface_action.is_empty():
		return false
	var intents_value: Variant = _foundation.action_authority_contract.get("in_place_session_intents", [])
	if typeof(intents_value) != TYPE_ARRAY or not (intents_value as Array).has(surface_action):
		return false
	var predicate := StringName(_foundation.action_authority_contract.get("in_place_session_intent_predicate_method", &""))
	return predicate.is_empty() or (_foundation.current_game.has_method(predicate) and bool(_foundation.current_game.call(predicate, surface_action, _foundation.run_state, _foundation.run_state.current_environment)))


func _sealed_action_host_in_place_ledger() -> Dictionary:
	if _foundation.run_state == null or _foundation.current_game == null:
		return {}
	var states_value: Variant = _foundation.run_state.current_environment.get("game_states", {})
	if typeof(states_value) != TYPE_DICTIONARY:
		return {}
	var table_value: Variant = (states_value as Dictionary).get(_sealed_action_host_state_key(), {})
	if typeof(table_value) != TYPE_DICTIONARY:
		return {}
	return _foundation.ActionAuthorityScript.validate_persisted_ledger_cow(
		(table_value as Dictionary).get(_foundation.ActionAuthorityScript.LEDGER_KEY, {}),
		_sealed_action_host_table_binding(_foundation.run_state.current_environment),
		_foundation.run_state.action_authority_checkpoint_fingerprint()
	)


func _sealed_action_host_store_in_place_ledger(ledger: Dictionary) -> bool:
	if _foundation.run_state == null or _foundation.current_game == null or ledger.is_empty():
		return false
	var states_value: Variant = _foundation.run_state.current_environment.get("game_states", {})
	if typeof(states_value) != TYPE_DICTIONARY:
		return false
	var states := states_value as Dictionary
	var state_key := _sealed_action_host_state_key()
	var table_value: Variant = states.get(state_key, {})
	if typeof(table_value) != TYPE_DICTIONARY:
		return false
	var table := table_value as Dictionary
	table[_foundation.ActionAuthorityScript.LEDGER_KEY] = ledger.duplicate(false)
	table.erase(_foundation.ActionAuthorityScript.PENDING_APPLY_RECEIPT_KEY)
	return true


func _sealed_action_host_in_place_session_intent(surface_action: String, index: int, confirm_requested: bool, surface_time_msec: int) -> Dictionary:
	var method := StringName(_foundation.action_authority_contract.get("in_place_session_intent_method", &""))
	if method.is_empty() or _foundation.current_game == null or not _foundation.current_game.has_method(method):
		return _sealed_action_host_rejection("invalid_intent", "Session-only Blackjack input has no sealed handler.")
	var ledger := _sealed_action_host_in_place_ledger()
	if ledger.is_empty():
		return _sealed_action_host_rejection("internal_fail_closed", "The live Blackjack session could not be validated.")
	if not (ledger.get("pending_delivery", {}) as Dictionary).is_empty():
		return _sealed_action_host_rejection("pending_delivery", "Retry or cancel the pending Blackjack action before changing the table.")
	var session: Dictionary = (ledger.get("session", {}) as Dictionary).duplicate(true)
	if surface_time_msec >= 0:
		session = _foundation._apply_game_surface_time_fields(session, surface_time_msec)
	var command_value: Variant = _foundation.current_game.call(method, surface_action, index, confirm_requested, session, _foundation.run_state, _foundation.run_state.current_environment)
	if typeof(command_value) != TYPE_DICTIONARY:
		return _sealed_action_host_rejection("invalid_intent", "Session-only Blackjack input returned an invalid command.")
	var command := command_value as Dictionary
	if bool(command.get("direct_resolve", false)) or bool(command.get("resolve", false)) or not str(command.get("action_id", "")).is_empty():
		# Some hand controls are session-only until the selected card completes the
		# round. Let those terminal variants restart on the isolated transaction
		# path instead of either mutating live economics or rejecting a valid click.
		return {"_sealed_action_host_requires_transaction": true}
	if bool(command.get("handled", false)):
		var next_session: Dictionary = command.get("ui_state", session) if typeof(command.get("ui_state", session)) == TYPE_DICTIONARY else session
		ledger = _foundation.ActionAuthorityScript.stage_session_cow(ledger, next_session)
		if not _sealed_action_host_store_in_place_ledger(ledger):
			return _sealed_action_host_rejection("internal_fail_closed", "The live Blackjack session could not be staged.")
		if not command.has("surface_state_patch"):
			var patch_method := StringName(_foundation.action_authority_contract.get("in_place_session_surface_patch_method", &""))
			if not patch_method.is_empty() and _foundation.current_game.has_method(patch_method):
				var patch_value: Variant = _foundation.current_game.call(patch_method, next_session, _foundation.run_state, _foundation.run_state.current_environment)
				if typeof(patch_value) == TYPE_DICTIONARY and not (patch_value as Dictionary).is_empty():
					command["surface_state_patch"] = patch_value
	return command


func _sealed_action_host_restored_candidate(snapshot: Dictionary, layout_context: Dictionary = {}, trusted_environment: Dictionary = {}) -> RunState:
	var candidate := RunState.new()
	candidate.from_dict(snapshot)
	if candidate.restore_trusted_scenario_semantics(trusted_environment):
		if _foundation.current_game != null:
			candidate.current_environment["active_game_id"] = _foundation.current_game.get_id()
		return candidate
	# Save snapshots deliberately omit renderer-derived scenario semantics and
	# mark dynamic rooms for a trusted rebuild. Sealed game transactions operate
	# on detached save snapshots, so rebuild that non-causal authority before an
	# environment-turn boundary is allowed to run on the candidate.
	var finalized := candidate.scenario_finalize_installed_environment(_foundation.library, layout_context)
	if not bool(finalized.get("ok", false)):
		return null
	if _foundation.current_game != null:
		candidate.current_environment["active_game_id"] = _foundation.current_game.get_id()
	return candidate


func _sealed_action_host_publish(candidate: RunState) -> bool:
	if candidate == null or _foundation.run_state == null:
		return false
	if candidate == _foundation.run_state:
		return _sealed_action_host_can_commit_in_place()
	if not _foundation.run_state.publish_host_action_candidate(candidate):
		return false
	_foundation._set_active_game_binding(_foundation.current_game.get_id() if _foundation.current_game != null else "")
	return true


func _sealed_action_host_rejection(error_code: String, message: String, request_key: String = "") -> Dictionary:
	var message_key := PlayerTextScript.sealed_action_message_key(error_code)
	var rejection := {
		"ok": false,
		"error_code": error_code,
		"message": PlayerTextScript.resolve(message_key),
		"message_key": message_key,
		"message_params": {},
		"diagnostic_detail": message,
		"request_key": request_key,
	}
	rejection[_foundation.ActionAuthorityScript.HOST_REQUEST_KEY] = request_key
	rejection[_foundation.ActionAuthorityScript.HOST_COMMITTED_KEY] = false
	return rejection


func _sealed_action_host_player_text_params() -> Dictionary:
	var provider_label := ""
	if _foundation != null and _foundation.current_game != null:
		provider_label = str(_foundation.current_game.get_display_name()).strip_edges()
	return {"provider_label": provider_label}


func _sealed_action_host_surface_intent(surface_action: String, index: int, confirm_requested: bool = false, surface_time_msec: int = -1) -> Dictionary:
	return surface_intent(surface_action, index, confirm_requested, surface_time_msec)


func _sealed_action_host_surface_intent_impl(surface_action: String, index: int, confirm_requested: bool = false, surface_time_msec: int = -1) -> Dictionary:
	if not _foundation._current_game_uses_action_authority() or _foundation.run_state == null or surface_action.is_empty():
		return _sealed_action_host_rejection("invalid_intent", "Blackjack action intent is unavailable.")
	# A count-pulse mouse-over only stages the already sealed table session. It has
	# no wager, RNG, environment-turn, or result authority, so cloning a late run's
	# world/scenario graph here is both unnecessary and visibly expensive.
	if _sealed_action_host_in_place_session_intent_allowed(surface_action):
		var in_place_command := _sealed_action_host_in_place_session_intent(surface_action, index, confirm_requested, surface_time_msec)
		if not bool(in_place_command.get("_sealed_action_host_requires_transaction", false)):
			return in_place_command
	var candidate := _sealed_action_host_transaction_candidate()
	if candidate == null:
		return _sealed_action_host_rejection("internal_fail_closed", "Sealed table semantics could not be rebuilt.")
	var ledger := _sealed_action_host_ledger(candidate, true)
	# First entry can materialize and normalize the Blackjack table while the
	# authority ledger is being created. Persist that deterministic, non-economic
	# table shape on the detached candidate before sealing a delivery. The ledger
	# was fully validated above and store_ledger writes that exact COW value
	# synchronously, so walking every retained response a second time here adds no
	# authority at this boundary (the auto-intent path follows the same rule).
	_sealed_action_host_store_ledger(candidate, ledger)
	var pending: Dictionary = ledger.get("pending_delivery", {})
	if not pending.is_empty():
		var retry_surface_actions: Array = _foundation.action_authority_contract.get("retry_surface_actions", [])
		var cancel_surface_actions: Array = _foundation.action_authority_contract.get("cancel_surface_actions", [])
		if surface_action in retry_surface_actions:
			var retry_message_params := _sealed_action_host_player_text_params()
			return GameModule.surface_command({
				"handled": true,
				"action_id": str(pending.get("action_id", "")),
				"action_kind": "legal",
				"direct_resolve": true,
				"skip_stake_validation": true,
				"set_stake": int(pending.get("stake", 0)),
				"ui_state": (ledger.get("session", {}) as Dictionary).duplicate(true),
				"_sealed_action_host_delivery": pending.duplicate(true),
				"message": PlayerTextScript.resolve("sealed_action.retrying", retry_message_params),
				"message_key": "sealed_action.retrying",
				"message_params": retry_message_params,
			})
		if surface_action in cancel_surface_actions:
			var cancelled: Dictionary = _foundation.ActionAuthorityScript.cancel_delivery_cow(ledger, pending)
			if not bool(cancelled.get("ok", false)):
				return _sealed_action_host_rejection(str(cancelled.get("error_code", "receipt_content_conflict")), "Blackjack cancellation did not match the pending action.", str(pending.get("request_key", "")))
			var cancelled_ledger: Dictionary = cancelled.get("ledger", ledger)
			_sealed_action_host_store_ledger(candidate, cancelled_ledger)
			if not _sealed_action_host_publish(candidate):
				return _sealed_action_host_rejection("internal_fail_closed", "Blackjack cancellation could not restore the pre-delivery session.", str(pending.get("request_key", "")))
			var cancel_message_params := _sealed_action_host_player_text_params()
			return GameModule.surface_command({
				"handled": true,
				"ui_state": (cancelled_ledger.get("session", {}) as Dictionary).duplicate(true),
				"message": PlayerTextScript.resolve("sealed_action.cancelled", cancel_message_params),
				"message_key": "sealed_action.cancelled",
				"message_params": cancel_message_params,
			})
		return _sealed_action_host_rejection("pending_delivery", "Retry or cancel the pending Blackjack action before changing the table.", str(pending.get("request_key", "")))
	var session: Dictionary = (ledger.get("session", {}) as Dictionary).duplicate(true)
	var recovery_session := session.duplicate(true)
	if surface_time_msec >= 0:
		# Sealed sessions retain UI state between actions. Refresh the complete
		# surface clock tuple together so games cannot observe a new raw timestamp
		# alongside an older slowed/presentation timestamp.
		session = _foundation._apply_game_surface_time_fields(session, surface_time_msec)
	if _foundation.current_game.has_method("_has_dealt_hand") and not _foundation.current_game.call("_has_dealt_hand", session):
		# The visible stake control already clamps a stale prior selection to the
		# player's current capacity. Seal that same affordable value into the
		# detached session; copying the raw host field here used to let Blackjack
		# reject a valid all-in before the shared resolver could normalize it.
		var selected_stake: int = int(_foundation._current_selected_stake())
		if selected_stake > 0:
			session["selected_stake"] = selected_stake
	# Once a provider ledger is initialized, Blackjack deliberately ignores durable
	# wager fields supplied only through caller UI state. Stage this host-owned,
	# capacity-clamped session on the detached candidate first so the provider sees
	# the exact trusted stake that will be presented and sealed. Nothing reaches the
	# live run until the complete command below has succeeded and is published.
	ledger = _foundation.ActionAuthorityScript.stage_session_cow(ledger, session)
	_sealed_action_host_store_ledger(candidate, ledger)
	var command: Dictionary = _foundation.current_game.surface_action_command(surface_action, index, confirm_requested, session, candidate, candidate.current_environment)
	command.erase("_sealed_action_host_prepared")
	if bool(command.get("handled", false)):
		var next_session: Dictionary = command.get("ui_state", session) if typeof(command.get("ui_state", session)) == TYPE_DICTIONARY else session
		ledger = _foundation.ActionAuthorityScript.stage_session_cow(ledger, next_session)
		if bool(command.get("direct_resolve", false)) or bool(command.get("resolve", false)):
			# Persist the detached staged session before sealing so any canonical
			# non-ledger defaults materialized by the table update are present in the
			# trusted context. The COW ledger itself is already host-validated.
			_sealed_action_host_store_ledger(candidate, ledger)
			var action_id := str(command.get("action_id", ""))
			var delivery_stake := _sealed_action_host_delivery_stake(command, next_session)
			var trusted_context := _sealed_action_host_trusted_context(candidate, delivery_stake, action_id)
			var issued: Dictionary = _foundation.ActionAuthorityScript.issue_delivery_cow(ledger, action_id, trusted_context, delivery_stake, recovery_session)
			if not bool(issued.get("ok", false)):
				return _sealed_action_host_rejection(str(issued.get("error_code", "receipt_content_conflict")), "Blackjack delivery conflicts with the pending action.")
			ledger = issued.get("ledger", ledger)
			var delivery: Dictionary = issued.get("delivery", {})
			command[_foundation.ActionAuthorityScript.HOST_REQUEST_KEY] = str(delivery.get("request_key", ""))
			command[_foundation.ActionAuthorityScript.HOST_BOUNDARY_ORDINAL_KEY] = int(delivery.get("boundary_ordinal", 0))
			command["_sealed_action_host_delivery"] = delivery.duplicate(true)
	_sealed_action_host_store_ledger(candidate, ledger)
	if not _sealed_action_host_publish(candidate):
		return _sealed_action_host_rejection("internal_fail_closed", "Blackjack host could not publish the staged action.")
	if command.has("_sealed_action_host_delivery"):
		command["_sealed_action_host_prepared"] = {
			"candidate": candidate,
			"ledger": ledger,
			"delivery": command.get("_sealed_action_host_delivery", {}),
		}
	return command


func _sealed_action_host_pointer_intent(surface_action: String, index: int, phase: String, board_position: Vector2, ui_state: Dictionary) -> Dictionary:
	var candidate := _sealed_action_host_transaction_candidate()
	if candidate == null:
		return _sealed_action_host_rejection("invalid_intent", "Table pointer intent is unavailable.")
	var ledger := _sealed_action_host_ledger(candidate, true)
	if not (ledger.get("pending_delivery", {}) as Dictionary).is_empty():
		return _sealed_action_host_rejection("pending_delivery", "Retry or cancel the pending table action before changing the ceremony.")
	var session: Dictionary = (ledger.get("session", {}) as Dictionary).duplicate(true)
	for transient_key in ["surface_time_msec", "surface_presentation_time_msec", "drunk_scaled_surface_time_msec", "reduce_motion"]:
		if ui_state.has(transient_key):
			session[transient_key] = ui_state[transient_key]
	var command: Dictionary = _foundation.current_game.surface_pointer_command(surface_action, index, phase, board_position, session, candidate, candidate.current_environment)
	if bool(command.get("handled", false)):
		var next_session: Dictionary = command.get("ui_state", session) if typeof(command.get("ui_state", session)) == TYPE_DICTIONARY else session
		ledger = _foundation.ActionAuthorityScript.stage_session_cow(ledger, next_session)
	_sealed_action_host_store_ledger(candidate, ledger)
	if not _sealed_action_host_publish(candidate):
		return _sealed_action_host_rejection("internal_fail_closed", "Table pointer intent could not be persisted.")
	return command


func _sealed_action_host_needs_auto_tick(surface_time_msec: int) -> bool:
	var predicate_method := StringName(_foundation.action_authority_contract.get("host_auto_tick_method", &""))
	if _foundation.run_state == null or _foundation.current_game == null or predicate_method.is_empty() or not _foundation.current_game.has_method(predicate_method):
		return false
	var predicate_time_msec := surface_time_msec
	if bool(_foundation.action_authority_contract.get("host_auto_tick_uses_drunk_scaled_time", false)):
		predicate_time_msec = _foundation._drunk_scaled_surface_time_msec(surface_time_msec, _foundation._current_drunk_time_scale())
	return bool(_foundation.current_game.call(predicate_method, predicate_time_msec, _foundation.run_state, _foundation.run_state.current_environment))


func _sealed_action_host_auto_intent(surface_time_msec: int) -> Dictionary:
	var candidate := _sealed_action_host_transaction_candidate()
	if candidate == null:
		return _sealed_action_host_rejection("invalid_intent", "Blackjack auto action intent is unavailable.")
	var ledger := _sealed_action_host_ledger(candidate, true)
	if not (ledger.get("pending_delivery", {}) as Dictionary).is_empty():
		return {}
	var session: Dictionary = (ledger.get("session", {}) as Dictionary).duplicate(true)
	var recovery_session := session.duplicate(true)
	# Automatic actions are a new presentation boundary, not a continuation of
	# the retained session's prior frame. Rebase raw and slowed clocks atomically;
	# Slot uses the latter to schedule both base and Buffalo feature reels.
	session = _foundation._apply_game_surface_time_fields(session, surface_time_msec)
	var command = _foundation.current_game.surface_auto_action_command(session, candidate, candidate.current_environment, {})
	if bool(command.get("handled", false)):
		var next_session: Dictionary = command.get("ui_state", session) if typeof(command.get("ui_state", session)) == TYPE_DICTIONARY else session
		ledger = _foundation.ActionAuthorityScript.stage_session_cow(ledger, next_session)
		if bool(command.get("direct_resolve", false)) or bool(command.get("resolve", false)):
			_sealed_action_host_store_ledger(candidate, ledger)
			# The ledger was fully validated before staging and store_ledger writes
			# that exact COW value synchronously. Revalidating its cached responses
			# and journal here walked the complete replay window a second time on
			# every Slot autoplay spin without crossing an external boundary.
			# Automatic sit-out hands publish a normalized session stake of one even
			# though the host still resolves the prepared command with its selected
			# table stake. Seal the same value the synchronous resolver will receive;
			# machine commands that author an explicit set_stake keep that override.
			var delivery_stake := int(command.get("set_stake", _foundation._current_selected_stake()))
			var auto_action_id := str(command.get("action_id", ""))
			var issued: Dictionary = _foundation.ActionAuthorityScript.issue_delivery_cow(ledger, auto_action_id, _sealed_action_host_trusted_context(candidate, delivery_stake, auto_action_id), delivery_stake, recovery_session)
			if not bool(issued.get("ok", false)):
				return _sealed_action_host_rejection(str(issued.get("error_code", "receipt_content_conflict")), "Blackjack auto delivery conflicts with the pending action.")
			ledger = issued.get("ledger", ledger)
			var delivery: Dictionary = issued.get("delivery", {})
			command["_sealed_action_host_delivery"] = delivery.duplicate(true)
			command[_foundation.ActionAuthorityScript.HOST_REQUEST_KEY] = str(delivery.get("request_key", ""))
	_sealed_action_host_store_ledger(candidate, ledger)
	if not _sealed_action_host_publish(candidate):
		return _sealed_action_host_rejection("internal_fail_closed", "Blackjack host could not publish the auto action.")
	if command.has("_sealed_action_host_delivery"):
		# The automatic action is resolved synchronously by
		# _apply_game_surface_automation_command. Carry the exact candidate that
		# crossed the publish boundary just as the manual surface path does; cloning
		# the whole run again adds no authority or isolation.
		command["_sealed_action_host_prepared"] = {
			"candidate": candidate,
			"ledger": ledger,
			"delivery": command.get("_sealed_action_host_delivery", {}),
		}
	return command


func _sealed_action_host_preview_wager_cost(action_id: String, stake: int) -> int:
	if not _foundation._current_game_uses_action_authority() or _foundation.run_state == null or action_id.is_empty():
		return 0
	var candidate := _sealed_action_host_transaction_candidate()
	if candidate == null:
		return 0
	var ledger := _sealed_action_host_ledger(candidate, true)
	_sealed_action_host_store_ledger(candidate, ledger)
	var trusted_wager_method := StringName(_foundation.action_authority_contract.get("trusted_candidate_wager_method", &""))
	if not trusted_wager_method.is_empty() and _foundation.current_game.has_method(trusted_wager_method):
		var trusted_session: Dictionary = ledger.get("session", {}) if typeof(ledger.get("session", {})) == TYPE_DICTIONARY else {}
		return maxi(0, int(_foundation.current_game.call(trusted_wager_method, action_id, stake, candidate, trusted_session)))
	var snapshot := _sealed_action_host_transient_run_snapshot(candidate)
	# The wager proposal is read-only and the canonical module binds this exact
	# session into its input fingerprint; no mutable staging happens on this path.
	var session: Dictionary = ledger.get("session", {}) if typeof(ledger.get("session", {})) == TYPE_DICTIONARY else {}
	var wager_method := StringName(_foundation.action_authority_contract.get("wager_cost_proposal_method", &""))
	if wager_method.is_empty() or not _foundation.current_game.has_method(wager_method):
		return 0
	var proposal: Dictionary = _foundation.current_game.call(wager_method, action_id, stake, snapshot, session)
	var expected_input := GameRitualRuntimeScript.canonical_fingerprint({
		"action_id": action_id,
		"stake": stake,
		"run_snapshot": snapshot,
		"ui_state": session,
	})
	if str(proposal.get("input_fingerprint", "")) != expected_input:
		return 0
	return maxi(0, int(proposal.get("cost", 0)))


func _sealed_action_host_replay_request(delivery_claim: Dictionary) -> Dictionary:
	var request_key := str(delivery_claim.get("request_key", ""))
	if request_key.is_empty() or not _foundation._current_game_uses_action_authority() or _foundation.run_state == null:
		return _sealed_action_host_rejection("unknown_receipt", "Blackjack request receipt is unavailable.", request_key)
	var candidate := _sealed_action_host_detached()
	if candidate == null:
		return _sealed_action_host_rejection("internal_fail_closed", "Sealed table semantics could not be rebuilt.", request_key)
	# _sealed_action_host_detached restored through RunState.from_dict, whose
	# save boundary already fully validated and isolated this ledger. Carry that
	# exact local value through this synchronous transaction instead of re-reading
	# and revalidating the growing history at every internal stage.
	var candidate_states: Dictionary = candidate.current_environment.get("game_states", {}) if typeof(candidate.current_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var state_key := _sealed_action_host_state_key()
	var candidate_table: Dictionary = candidate_states.get(state_key, {}) if typeof(candidate_states.get(state_key, {})) == TYPE_DICTIONARY else {}
	var ledger: Dictionary = (candidate_table.get(_foundation.ActionAuthorityScript.LEDGER_KEY, {}) as Dictionary).duplicate(false) if typeof(candidate_table.get(_foundation.ActionAuthorityScript.LEDGER_KEY, {})) == TYPE_DICTIONARY else {}
	var replay: Dictionary = _foundation.ActionAuthorityScript.cached_response(ledger, request_key, delivery_claim)
	if replay.is_empty():
		return _sealed_action_host_rejection("unknown_receipt", "Blackjack request receipt is unavailable.", request_key)
	if not bool(replay.get("ok", false)) and replay.has("error_code"):
		return _sealed_action_host_rejection(str(replay.get("error_code", "receipt_content_conflict")), "Blackjack replay envelope did not match its committed boundary.", request_key)
	return replay


func _sealed_action_host_prepare_delivery(action_id: String, stake: int, delivery_claim: Dictionary = {}) -> Dictionary:
	var requested_key := str(delivery_claim.get("request_key", ""))
	var candidate := _sealed_action_host_transaction_candidate()
	if candidate == null:
		return _sealed_action_host_rejection("internal_fail_closed", "Blackjack host could not create a detached delivery.", requested_key)
	var ledger := _sealed_action_host_ledger(candidate, true)
	var cache: Dictionary = ledger.get("request_cache", {}) if typeof(ledger.get("request_cache", {})) == TYPE_DICTIONARY else {}
	if not requested_key.is_empty() and cache.has(requested_key):
		if str(delivery_claim.get("action_id", "")) != action_id or int(delivery_claim.get("stake", -1)) != stake:
			return _sealed_action_host_rejection("receipt_content_conflict", "Blackjack request receipt is bound to a different action or stake.", requested_key)
		var cached_response: Dictionary = _foundation.ActionAuthorityScript.cached_replay_response(ledger, requested_key, delivery_claim)
		if cached_response.is_empty() or (not bool(cached_response.get("ok", false)) and cached_response.has("error_code")):
			return _sealed_action_host_rejection("receipt_content_conflict", "Blackjack request receipt is bound to different content.", requested_key)
		return {"ok": true, "cached_response": cached_response}
	var context := _sealed_action_host_trusted_context(candidate, stake, action_id)
	var pending: Dictionary = ledger.get("pending_delivery", {}) if typeof(ledger.get("pending_delivery", {})) == TYPE_DICTIONARY else {}
	if not pending.is_empty():
		if not delivery_claim.is_empty() and GameRitualRuntimeScript.canonical_json(delivery_claim) != GameRitualRuntimeScript.canonical_json(pending):
			return _sealed_action_host_rejection("stale_boundary", "Blackjack delivery belongs to a different action boundary.", requested_key)
		var matched: Dictionary = _foundation.ActionAuthorityScript.delivery_matches(ledger, str(pending.get("request_key", "")), action_id, context, stake)
		if not bool(matched.get("ok", false)):
			return _sealed_action_host_rejection(str(matched.get("error_code", "receipt_content_conflict")), "Blackjack delivery content changed before settlement.", str(pending.get("request_key", "")))
		return {
			"ok": true,
			"delivery": pending.duplicate(true),
			"_sealed_candidate": candidate,
			"_sealed_ledger": ledger,
		}
	if not requested_key.is_empty():
		return _sealed_action_host_rejection("stale_boundary", "Blackjack delivery is no longer pending.", requested_key)
	var issued: Dictionary = _foundation.ActionAuthorityScript.issue_delivery_cow(ledger, action_id, context, stake, ledger.get("session", {}))
	if not bool(issued.get("ok", false)):
		return _sealed_action_host_rejection(str(issued.get("error_code", "receipt_content_conflict")), "Blackjack delivery could not be issued.")
	ledger = issued.get("ledger", ledger)
	_sealed_action_host_store_ledger(candidate, ledger)
	# Delivery identity is durable before any RNG, funding, or game proposal work.
	if not _sealed_action_host_publish(candidate):
		return _sealed_action_host_rejection("internal_fail_closed", "Blackjack delivery could not be persisted.")
	# Publishing the durable pending delivery transfers candidate collection roots
	# into the live RunState. Reusing that candidate would let apply_result append
	# story/profile/crew histories through those aliases before the still-fallible
	# environment-turn boundary. Fork once more so every apply-time collection is
	# transaction-owned until the final publish succeeds.
	candidate = _sealed_action_host_detached()
	if candidate == null:
		return _sealed_action_host_rejection("internal_fail_closed", "Blackjack delivery could not isolate its transaction histories.")
	ledger = _sealed_action_host_ledger(candidate, false)
	if ledger.is_empty() or GameRitualRuntimeScript.canonical_json(ledger.get("pending_delivery", {})) != GameRitualRuntimeScript.canonical_json(issued.get("delivery", {})):
		return _sealed_action_host_rejection("internal_fail_closed", "Blackjack delivery isolation lost its pending authority.")
	return {
		"ok": true,
		"delivery": (issued.get("delivery", {}) as Dictionary).duplicate(true),
		"_sealed_candidate": candidate,
		"_sealed_ledger": ledger,
	}


func _sealed_action_host_is_canonical_replay(result: Dictionary) -> bool:
	if _foundation.run_state == null or not _foundation._current_game_uses_action_authority():
		return false
	var ledger := _sealed_action_host_ledger(_foundation.run_state, false)
	return not ledger.is_empty() and _foundation.ActionAuthorityScript.valid_cached_replay(ledger, result)


func _sealed_action_host_cached_replay(delivery_claim: Dictionary) -> Dictionary:
	var request_key := str(delivery_claim.get("request_key", ""))
	if request_key.is_empty() or _foundation.run_state == null or not _foundation._current_game_uses_action_authority():
		return {}
	var ledger := _sealed_action_host_ledger(_foundation.run_state, false)
	var cache: Dictionary = ledger.get("request_cache", {}) if typeof(ledger.get("request_cache", {})) == TYPE_DICTIONARY else {}
	if ledger.is_empty() or not cache.has(request_key):
		return {}
	var replay: Dictionary = _foundation.ActionAuthorityScript.cached_replay_response(ledger, request_key, delivery_claim)
	if replay.is_empty() or (not bool(replay.get("ok", false)) and replay.has("error_code")):
		return _sealed_action_host_rejection("receipt_content_conflict", "Blackjack request receipt is bound to different content.", request_key)
	return replay


func _sealed_action_host_present_cached_replay(result: Dictionary) -> bool:
	if not _sealed_action_host_is_canonical_replay(result):
		return false
	if _foundation.FoundationActionViewModelScript == null:
		_foundation.FoundationActionViewModelScript = load(str(_foundation.RUN_UI_SCRIPT_PATHS.get("FoundationActionViewModelScript", ""))) as Script
	if _foundation.FoundationActionViewModelScript == null:
		return false
	# Cache hits may refresh presentation, but they are not a second action
	# boundary and must never repeat tutorials, audio, absorption, autosave,
	# interrupts, outcome scheduling, or any other one-shot consumer.
	_foundation.last_game_result = _foundation.FoundationActionViewModelScript.stored_game_result_snapshot(result)
	if _foundation.game_surface_canvas != null and _foundation.current_screen == _foundation.SCREEN_GAME:
		_foundation.game_surface_canvas.render_game_snapshot(_foundation._game_view_snapshot(true))
	else:
		_foundation._refresh()
	return true


func _sealed_action_host_proposal_valid(proposal: Dictionary, proposal_input: Dictionary) -> bool:
	if not _foundation._current_game_uses_action_authority():
		return false
	var keys := proposal.keys()
	keys.sort()
	var expected_keys := ["input_fingerprint", "ok", "output_fingerprint", "result", "rng_snapshot", "run_snapshot"]
	expected_keys.sort()
	if keys != expected_keys \
			or typeof(proposal.get("result", null)) != TYPE_DICTIONARY \
			or typeof(proposal.get("run_snapshot", null)) != TYPE_DICTIONARY \
			or typeof(proposal.get("rng_snapshot", null)) != TYPE_DICTIONARY:
		return false
	if str(proposal.get("input_fingerprint", "")) != GameRitualRuntimeScript.canonical_fingerprint(proposal_input):
		return false
	# Validation erases only one top-level field. The proposal's nested result and
	# snapshots remain immutable here, so cloning the entire saved run would add
	# a second full-state allocation to every accepted action.
	var output := proposal.duplicate(false)
	var provided_output_fingerprint := str(output.get("output_fingerprint", ""))
	output.erase("output_fingerprint")
	if provided_output_fingerprint != GameRitualRuntimeScript.canonical_fingerprint(output):
		return false
	# The host replays the canonical module from the sealed serialized input. Both
	# outputs are independently bound to their complete canonical content by the
	# same SHA-256 contract, so comparing those verified bindings is equivalent to
	# serializing both full proposals a second time and comparing the strings.
	# This keeps the hostile-input boundary fail-closed while avoiding one large,
	# short-lived allocation on every accepted action.
	var resolve_method := StringName(_foundation.action_authority_contract.get("resolve_proposal_method", &""))
	if resolve_method.is_empty() or not _foundation.current_game.has_method(resolve_method):
		return false
	var canonical: Dictionary = _foundation.current_game.call(
		resolve_method,
		str(proposal_input.get("action_id", "")),
		int(proposal_input.get("stake", 0)),
		proposal_input.get("run_snapshot", {}),
		proposal_input.get("rng_snapshot", {}),
		proposal_input.get("ui_state", {})
	)
	var canonical_output := canonical.duplicate(false)
	var canonical_output_fingerprint := str(canonical_output.get("output_fingerprint", ""))
	canonical_output.erase("output_fingerprint")
	if canonical_output_fingerprint.is_empty() \
			or canonical_output_fingerprint != GameRitualRuntimeScript.canonical_fingerprint(canonical_output):
		return false
	return canonical_output_fingerprint == provided_output_fingerprint


func _sealed_action_host_candidate_proposal(resolve_method: StringName, action_id: String, stake: int, base_candidate: RunState, input_ledger: Dictionary, proposal_input: Dictionary, proposal_input_fingerprint: String, session: Dictionary, use_base_candidate: bool = false, compact_evidence: bool = false, fingerprint_output: bool = true) -> Dictionary:
	if base_candidate == null or resolve_method.is_empty() or not _foundation.current_game.has_method(resolve_method):
		return {}
	var proposal_candidate := base_candidate
	if not use_base_candidate:
		if bool(_foundation.action_authority_contract.get("lightweight_resolution_candidate", false)):
			proposal_candidate = base_candidate.detached_host_resolution_candidate(
				_sealed_action_host_state_key(),
				bool(_foundation.action_authority_contract.get("trusted_candidate_shallow_machine_detach", false))
			)
		else:
			proposal_candidate = base_candidate.detached_host_action_candidate(_sealed_action_host_state_key())
	_sealed_action_host_store_ledger(proposal_candidate, input_ledger)
	var proposal_rng := RngStream.new()
	proposal_rng.restore(proposal_input.get("rng_snapshot", {}))
	var result: Dictionary = _foundation.current_game.call(resolve_method, action_id, stake, proposal_candidate, proposal_rng, session)
	var authority_evidence := _sealed_action_host_compact_evidence(proposal_candidate, action_id, stake, session) if compact_evidence else {}
	if compact_evidence and authority_evidence.is_empty():
		return {}
	var proposal := {
		"ok": bool(result.get("ok", false)),
		"input_fingerprint": proposal_input_fingerprint,
		# Trusted compact providers return a fresh, proposal-owned result. The host
		# keeps that graph read-only through replay matching/fingerprinting and forks
		# only its top level before adding receipt metadata. Legacy serialized
		# providers retain the defensive deep copy at their hostile-data boundary.
		"result": result if compact_evidence else result.duplicate(true),
		# Compact providers retain the actual detached candidate in this private
		# bundle. A serialized whole-run snapshot adds no validation after the host
		# has independently replayed and matched exact evidence.
		"run_snapshot": {} if compact_evidence else proposal_candidate.to_save_snapshot(),
		"rng_snapshot": proposal_rng.snapshot(),
	}
	var compact_component_fingerprints: Dictionary = {}
	if compact_evidence and fingerprint_output:
		# Bind the authoritative output machine and RNG once, then seal their hashes
		# together. Exact structural replay already compares the full result, and the
		# apply/commit receipts bind that result separately; hashing the same dense
		# presentation here a third time added no independent validation.
		compact_component_fingerprints = {
			"authority_fingerprint": GameRitualRuntimeScript.canonical_fingerprint(authority_evidence),
			"rng_fingerprint": GameRitualRuntimeScript.canonical_fingerprint(proposal.get("rng_snapshot", {})),
		}
		proposal["output_fingerprint"] = GameRitualRuntimeScript.canonical_fingerprint({
			"input_fingerprint": proposal_input_fingerprint,
			"ok": bool(proposal.get("ok", false)),
			"rng_fingerprint": compact_component_fingerprints.get("rng_fingerprint", ""),
			"authority_fingerprint": compact_component_fingerprints.get("authority_fingerprint", ""),
		})
	elif not compact_evidence:
		proposal["output_fingerprint"] = GameRitualRuntimeScript.canonical_fingerprint(proposal)
	else:
		# The accepted execution owns the receipt fingerprint. A provider that opts
		# into exact structural replay can leave the second digest empty after the
		# host compares every replay output and authority-evidence field below.
		proposal["output_fingerprint"] = ""
	return {"proposal": proposal, "candidate": proposal_candidate, "authority_evidence": authority_evidence, "component_fingerprints": compact_component_fingerprints}


func _sealed_action_host_candidate_proposals_match(first: Dictionary, replay: Dictionary, proposal_input: Dictionary, first_authority_evidence: Dictionary = {}, replay_authority_evidence: Dictionary = {}) -> bool:
	var expected_input_fingerprint := str(first.get("input_fingerprint", ""))
	if expected_input_fingerprint.is_empty() or expected_input_fingerprint != str(replay.get("input_fingerprint", "")):
		return false
	var expected_keys := ["input_fingerprint", "ok", "output_fingerprint", "result", "rng_snapshot", "run_snapshot"]
	expected_keys.sort()
	var structural_replay_match := bool(_foundation.action_authority_contract.get("trusted_candidate_structural_replay_match", false)) \
			and not first_authority_evidence.is_empty() and not replay_authority_evidence.is_empty()
	for proposal_index in range(2):
		var proposal: Dictionary = first if proposal_index == 0 else replay
		if typeof(proposal) != TYPE_DICTIONARY:
			return false
		var keys := proposal.keys()
		keys.sort()
		if keys != expected_keys \
				or str(proposal.get("input_fingerprint", "")) != expected_input_fingerprint \
				or typeof(proposal.get("result", null)) != TYPE_DICTIONARY \
				or typeof(proposal.get("run_snapshot", null)) != TYPE_DICTIONARY \
				or typeof(proposal.get("rng_snapshot", null)) != TYPE_DICTIONARY:
			return false
		if str(proposal.get("output_fingerprint", "")).is_empty() and not (structural_replay_match and proposal_index == 1):
			return false
	if structural_replay_match:
		return str(replay.get("output_fingerprint", "")).is_empty() \
				and bool(first.get("ok", false)) == bool(replay.get("ok", false)) \
				and (first.get("result", {}) as Dictionary).recursive_equal(replay.get("result", {}) as Dictionary, 64) \
				and (first.get("run_snapshot", {}) as Dictionary).recursive_equal(replay.get("run_snapshot", {}) as Dictionary, 64) \
				and (first.get("rng_snapshot", {}) as Dictionary).recursive_equal(replay.get("rng_snapshot", {}) as Dictionary, 64) \
				and first_authority_evidence.recursive_equal(replay_authority_evidence, 64)
	return str(first.get("output_fingerprint", "")) == str(replay.get("output_fingerprint", ""))


func _sealed_action_host_snapshot_ledger(snapshot: Dictionary) -> Dictionary:
	var environment: Dictionary = snapshot.get("current_environment", {}) if typeof(snapshot.get("current_environment", {})) == TYPE_DICTIONARY else {}
	var game_states: Dictionary = environment.get("game_states", {}) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var state_key := _sealed_action_host_state_key()
	var table: Dictionary = game_states.get(state_key, {}) if typeof(game_states.get(state_key, {})) == TYPE_DICTIONARY else {}
	return (table.get(_foundation.ActionAuthorityScript.LEDGER_KEY, {}) as Dictionary).duplicate(false) if typeof(table.get(_foundation.ActionAuthorityScript.LEDGER_KEY, {})) == TYPE_DICTIONARY else {}


func _sealed_action_host_snapshot_with_ledger(snapshot: Dictionary, ledger: Dictionary) -> Dictionary:
	# Copy only the four containers on the authority path. All other snapshot
	# values remain immutable during proposal hashing/restoration.
	var result := snapshot.duplicate(false)
	var environment: Dictionary = (result.get("current_environment", {}) as Dictionary).duplicate(false) if typeof(result.get("current_environment", {})) == TYPE_DICTIONARY else {}
	var game_states: Dictionary = (environment.get("game_states", {}) as Dictionary).duplicate(false) if typeof(environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var state_key := _sealed_action_host_state_key()
	var table: Dictionary = (game_states.get(state_key, {}) as Dictionary).duplicate(false) if typeof(game_states.get(state_key, {})) == TYPE_DICTIONARY else {}
	table[_foundation.ActionAuthorityScript.LEDGER_KEY] = ledger.duplicate(false)
	game_states[state_key] = table
	environment["game_states"] = game_states
	result["current_environment"] = environment
	return result


func _sealed_action_host_compact_proposal_ledger(ledger: Dictionary) -> Dictionary:
	var compact := ledger.duplicate(false)
	compact["request_cache"] = {}
	compact["request_order"] = []
	compact["journal"] = []
	compact["journal_head"] = ""
	return compact


func _sealed_action_host_expand_proposal_ledger(full_input: Dictionary, compact_input: Dictionary, compact_output: Dictionary) -> Dictionary:
	# The module may rebind only the account/RNG checkpoint (Crew plays do this
	# after their visible fee). It cannot change delivery/session identity or
	# smuggle history through the compact proposal channel.
	if compact_output.is_empty() \
			or not (compact_output.get("request_cache", {}) as Dictionary).is_empty() \
			or not (compact_output.get("request_order", []) as Array).is_empty() \
			or not (compact_output.get("journal", []) as Array).is_empty() \
			or not str(compact_output.get("journal_head", "")).is_empty():
		return {}
	for key in _foundation.ActionAuthorityScript.LEDGER_KEYS:
		if key in ["checkpoint_fingerprint", "request_cache", "request_order", "journal", "journal_head"]:
			continue
		var output_value: Variant = compact_output.get(key)
		var input_value: Variant = compact_input.get(key)
		if typeof(output_value) != typeof(input_value):
			return {}
		if typeof(output_value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
			if GameRitualRuntimeScript.canonical_fingerprint(output_value) != GameRitualRuntimeScript.canonical_fingerprint(input_value):
				return {}
		elif output_value != input_value:
			return {}
	var expanded := full_input.duplicate(false)
	expanded["checkpoint_fingerprint"] = compact_output.get("checkpoint_fingerprint")
	return expanded


func _sealed_action_host_public_run_snapshot(value: Variant) -> Dictionary:
	var snapshot: Dictionary = (value as Dictionary).duplicate(false) if typeof(value) == TYPE_DICTIONARY else {}
	# This projection erases top-level private authority only; nested public Crew
	# state is immutable and can be shared by the temporary fingerprint view.
	var crew_state: Dictionary = (snapshot.get("crew_state", {}) as Dictionary).duplicate(false) if typeof(snapshot.get("crew_state", {})) == TYPE_DICTIONARY else {}
	crew_state.erase("a")
	crew_state.erase("z")
	snapshot["crew_state"] = crew_state
	return snapshot


func _sealed_action_host_proposal_fingerprints(proposal: Dictionary, proposal_input: Dictionary, compact_authority_evidence: Dictionary = {}, compact_component_fingerprints: Dictionary = {}) -> Dictionary:
	if not compact_authority_evidence.is_empty():
		var run_fingerprint := str(compact_component_fingerprints.get("authority_fingerprint", ""))
		if run_fingerprint.is_empty():
			run_fingerprint = GameRitualRuntimeScript.canonical_fingerprint(compact_authority_evidence)
		var rng_fingerprint := str(compact_component_fingerprints.get("rng_fingerprint", ""))
		if rng_fingerprint.is_empty():
			rng_fingerprint = GameRitualRuntimeScript.canonical_fingerprint(proposal.get("rng_snapshot", {}))
		return {
			"proposal_fingerprint": str(proposal.get("output_fingerprint", "")),
			"run_fingerprint": run_fingerprint,
			"rng_fingerprint": rng_fingerprint,
		}
	var content := proposal.duplicate(false)
	content.erase("output_fingerprint")
	# The full opaque proposal was already replayed and validated above. Receipts
	# persist a public gameplay identity, so Crew's random private save authority
	# must not make otherwise identical Blackjack transactions hash differently.
	var public_input := proposal_input.duplicate(false)
	public_input["run_snapshot"] = _sealed_action_host_public_run_snapshot(public_input.get("run_snapshot", {}))
	content["input_fingerprint"] = GameRitualRuntimeScript.canonical_fingerprint(public_input)
	content["run_snapshot"] = _sealed_action_host_public_run_snapshot(content.get("run_snapshot", {}))
	return {
		"proposal_fingerprint": GameRitualRuntimeScript.canonical_fingerprint(content),
		"run_fingerprint": GameRitualRuntimeScript.canonical_fingerprint(content.get("run_snapshot", {})),
		"rng_fingerprint": GameRitualRuntimeScript.canonical_fingerprint(proposal.get("rng_snapshot", {})),
	}


func _sealed_action_host_advance_environment_turn(candidate: RunState) -> Dictionary:
	return candidate.advance_environment_turns(1)


func _sealed_action_host_resolve_intent(action_id: String, stake: int, delivery_claim: Dictionary = {}, prepared_claim: Dictionary = {}) -> Dictionary:
	var delivery_key := str(delivery_claim.get("request_key", ""))
	if not _foundation._current_game_uses_action_authority() or _foundation.run_state == null or action_id.is_empty():
		return _sealed_action_host_rejection("invalid_intent", "Blackjack action intent is unavailable.", delivery_key)
	var prepared: Dictionary = prepared_claim
	if not prepared.is_empty():
		var prepared_candidate: RunState = prepared.get("candidate", null) as RunState
		var prepared_ledger: Dictionary = prepared.get("ledger", {}) if typeof(prepared.get("ledger", {})) == TYPE_DICTIONARY else {}
		var prepared_delivery: Dictionary = prepared.get("delivery", {}) if typeof(prepared.get("delivery", {})) == TYPE_DICTIONARY else {}
		if prepared_candidate == null \
				or str(prepared_delivery.get("action_id", "")) != action_id \
				or int(prepared_delivery.get("stake", -1)) != stake \
				or GameRitualRuntimeScript.canonical_json(prepared_delivery) != GameRitualRuntimeScript.canonical_json(delivery_claim) \
				or GameRitualRuntimeScript.canonical_json(prepared_ledger.get("pending_delivery", {})) != GameRitualRuntimeScript.canonical_json(prepared_delivery):
			return _sealed_action_host_rejection("stale_boundary", "Blackjack prepared delivery no longer matched its synchronous action boundary.", delivery_key)
		prepared = {
			"ok": true,
			"delivery": prepared_delivery,
			"_sealed_candidate": prepared_candidate,
			"_sealed_ledger": prepared_ledger,
		}
	else:
		prepared = _sealed_action_host_prepare_delivery(action_id, stake, delivery_claim)
	if not bool(prepared.get("ok", false)):
		return prepared
	if typeof(prepared.get("cached_response", null)) == TYPE_DICTIONARY:
		return (prepared.get("cached_response", {}) as Dictionary).duplicate(true)
	var delivery: Dictionary = prepared.get("delivery", {})
	var request_key := str(delivery.get("request_key", ""))
	var candidate_value: Variant = prepared.get("_sealed_candidate", null)
	var candidate: RunState = candidate_value as RunState
	if candidate == null:
		candidate = _sealed_action_host_detached()
	if candidate == null:
		return _sealed_action_host_rejection("internal_fail_closed", "Sealed table semantics could not be rebuilt.", request_key)
	var commits_in_place = candidate == _foundation.run_state and _sealed_action_host_can_commit_in_place()
	# prepare_delivery validated this ledger and either observed an already durable
	# pending delivery or published the newly issued one. Keep a top-level local
	# copy for the remaining copy-on-write stages.
	var prepared_ledger_value: Variant = prepared.get("_sealed_ledger", {})
	var ledger: Dictionary = (prepared_ledger_value as Dictionary).duplicate(false) if typeof(prepared_ledger_value) == TYPE_DICTIONARY else {}
	if ledger.is_empty() or GameRitualRuntimeScript.canonical_json(ledger.get("pending_delivery", {})) != GameRitualRuntimeScript.canonical_json(delivery):
		return _sealed_action_host_rejection("stale_boundary", "Blackjack delivery was not present on the canonical candidate.", request_key)
	# Resolution proposals copy the session at their own mutation boundary. Keep
	# the validated ledger value read-only here instead of cloning it once in the
	# host and a second time in the provider.
	var session: Dictionary = ledger.get("session", {}) if typeof(ledger.get("session", {})) == TYPE_DICTIONARY else {}
	var provider_contract: Dictionary = _foundation.action_authority_contract
	var wager_method := StringName(provider_contract.get("wager_cost_proposal_method", &""))
	var resolve_method := StringName(provider_contract.get("resolve_proposal_method", &""))
	var candidate_wager_method := StringName(provider_contract.get("trusted_candidate_wager_method", &""))
	var candidate_resolve_method := StringName(provider_contract.get("trusted_candidate_resolve_method", &""))
	var uses_trusted_candidate_provider = not candidate_wager_method.is_empty() \
			and not candidate_resolve_method.is_empty() \
			and _foundation.current_game.has_method(candidate_wager_method) \
			and _foundation.current_game.has_method(candidate_resolve_method)
	var uses_compact_authority_evidence = uses_trusted_candidate_provider \
			and _sealed_action_host_compact_evidence_allowed(candidate, action_id, stake, session)
	var first_proposal_owns_transaction = uses_trusted_candidate_provider \
			and not commits_in_place \
			and bool(provider_contract.get("trusted_candidate_first_proposal_owns_transaction", false))
	if wager_method.is_empty() or resolve_method.is_empty() \
			or not _foundation.current_game.has_method(wager_method) or not _foundation.current_game.has_method(resolve_method):
		return _sealed_action_host_rejection("invalid_intent", "Sealed action proposal methods are unavailable.", request_key)
	var wager_proposal: Dictionary
	if uses_trusted_candidate_provider:
		wager_proposal = {
			"cost": maxi(0, int(_foundation.current_game.call(candidate_wager_method, action_id, stake, candidate, session))),
		}
	else:
		# Trusted candidate providers above read the already isolated RunState and
		# never consume a serialized wager input. Materialize this snapshot only for
		# legacy proposal providers that actually bind it into their fingerprint.
		var wager_snapshot := _sealed_action_host_transient_run_snapshot(candidate)
		var wager_input_fingerprint := GameRitualRuntimeScript.canonical_fingerprint({
			"action_id": action_id,
			"stake": stake,
			"run_snapshot": wager_snapshot,
			"ui_state": session,
		})
		wager_proposal = _foundation.current_game.call(wager_method, action_id, stake, wager_snapshot, session)
		if str(wager_proposal.get("input_fingerprint", "")) != wager_input_fingerprint:
			return _sealed_action_host_rejection("invalid_proposal", "Blackjack wager proposal did not match its canonical input.", request_key)
	var wager_cost := maxi(0, int(wager_proposal.get("cost", 0)))
	var funding_preview := candidate.preview_grand_casino_wager_funding(_foundation.current_game.get_id(), wager_cost, candidate.current_environment)
	if not bool(funding_preview.get("ok", false)):
		return _sealed_action_host_rejection("insufficient_funds", str(funding_preview.get("message", "You do not have enough cash or chips for that wager.")), request_key)
	var funding_depletes_liquid_balance := candidate.bankroll - int(funding_preview.get("cash_used", 0)) <= 0 \
		and candidate.grand_casino_chips - int(funding_preview.get("existing_chips_used", 0)) <= 0
	var place_bet_action := str(provider_contract.get("place_bet_action", ""))
	if not place_bet_action.is_empty() and action_id == place_bet_action and funding_depletes_liquid_balance:
		candidate.begin_deferred_bankroll_zero_resolution()
	var funding := candidate.fund_grand_casino_wager(_foundation.current_game.get_id(), wager_cost, candidate.current_environment)
	if not bool(funding.get("ok", false)):
		return _sealed_action_host_rejection("insufficient_funds", str(funding.get("message", "You do not have enough cash or chips for that wager.")), request_key)
	# Detached proposal restores still reconcile their serialized account/RNG.
	# Refresh only the detached checkpoint after funding; the live pending
	# delivery remains bound to its original canonical context until commit.
	var funded_ledger := ledger.duplicate(false)
	if funded_ledger.is_empty():
		return _sealed_action_host_rejection("invalid_proposal", "Blackjack authority disappeared during wager funding.", request_key)
	funded_ledger["checkpoint_fingerprint"] = candidate.action_authority_checkpoint_fingerprint()
	_sealed_action_host_store_ledger(candidate, funded_ledger)
	var rng := candidate.create_rng()
	var proposal_input := {
		"action_id": action_id,
		"stake": stake,
		"run_snapshot": {} if uses_compact_authority_evidence else _sealed_action_host_transient_run_snapshot(candidate),
		"rng_snapshot": rng.snapshot(),
		"ui_state": session,
	}
	# Historical responses are irrelevant to deterministic game resolution. Send
	# the canonical module an internally consistent empty-history ledger, replay
	# and validate that compact proposal in full, then restore the exact
	# host-validated history before receipt hashing, apply, and publication.
	var compact_input_ledger := _sealed_action_host_compact_proposal_ledger(funded_ledger)
	var compact_proposal_input := proposal_input.duplicate(false)
	if uses_compact_authority_evidence:
		# The detached candidate remains the source of truth; compact evidence below
		# binds its exact Slot/account inputs without embedding unrelated run history.
		# An in-place transaction keeps the durable live retry history intact while
		# both narrow proposal candidates receive their own compact ledger below.
		if not commits_in_place:
			_sealed_action_host_store_ledger(candidate, compact_input_ledger)
	else:
		compact_proposal_input["run_snapshot"] = _sealed_action_host_snapshot_with_ledger(
			proposal_input.get("run_snapshot", {}),
			compact_input_ledger
		)
	var compact_proposal: Dictionary
	var trusted_proposed_candidate: RunState
	var compact_authority_evidence: Dictionary = {}
	var compact_component_fingerprints: Dictionary = {}
	var runtime_restore_method: StringName = &""
	var runtime_checkpoint: Dictionary = {}
	var accepted_runtime_checkpoint: Dictionary = {}
	var has_runtime_checkpoint := false
	if uses_trusted_candidate_provider:
		var compact_input_fingerprint := ""
		if uses_compact_authority_evidence:
			var input_evidence := _sealed_action_host_compact_evidence(candidate, action_id, stake, session)
			if input_evidence.is_empty():
				return _sealed_action_host_rejection("invalid_proposal", "Game authority evidence was unavailable.", request_key)
			compact_input_fingerprint = GameRitualRuntimeScript.canonical_fingerprint({
				"action_id": action_id,
				"stake": stake,
				"authority_evidence": input_evidence,
				"rng_snapshot": proposal_input.get("rng_snapshot", {}),
				"ui_state": session,
			})
		else:
			compact_input_fingerprint = GameRitualRuntimeScript.canonical_fingerprint(compact_proposal_input)
		var runtime_checkpoint_method := StringName(provider_contract.get("proposal_runtime_checkpoint_method", &""))
		runtime_restore_method = StringName(provider_contract.get("proposal_runtime_restore_method", &""))
		has_runtime_checkpoint = not runtime_checkpoint_method.is_empty() \
				and not runtime_restore_method.is_empty() \
				and _foundation.current_game.has_method(runtime_checkpoint_method) \
				and _foundation.current_game.has_method(runtime_restore_method)
		runtime_checkpoint = _foundation.current_game.call(runtime_checkpoint_method, candidate) if has_runtime_checkpoint else {}
		# Compact providers execute the accepted proposal directly on the already
		# isolated full candidate. Build the cheap replay candidate before that first
		# mutation so both executions begin at the exact same machine boundary.
		var shallow_machine_detach := bool(provider_contract.get("trusted_candidate_shallow_machine_detach", false))
		var first_source: RunState = candidate.detached_host_resolution_candidate(_sealed_action_host_state_key(), shallow_machine_detach) if commits_in_place else candidate
		# A detached transaction candidate is already private host-owned state. A
		# provider may consume it as the accepted first execution when the replay
		# clone is built before that mutation. This retains two independent full
		# proposals while avoiding a third deep copy of the bound table.
		var direct_full_candidate = uses_compact_authority_evidence or first_proposal_owns_transaction
		var structural_replay_match = uses_compact_authority_evidence \
				and bool(provider_contract.get("trusted_candidate_structural_replay_match", false))
		var replay_source: RunState = candidate.detached_host_action_candidate(_sealed_action_host_state_key()) if first_proposal_owns_transaction else (candidate.detached_host_resolution_candidate(_sealed_action_host_state_key(), shallow_machine_detach) if uses_compact_authority_evidence else candidate)
		var first_bundle := _sealed_action_host_candidate_proposal(candidate_resolve_method, action_id, stake, first_source, compact_input_ledger, compact_proposal_input, compact_input_fingerprint, session, direct_full_candidate, uses_compact_authority_evidence)
		if has_runtime_checkpoint and not bool(_foundation.current_game.call(runtime_restore_method, runtime_checkpoint)):
			return _sealed_action_host_rejection("invalid_proposal", "Game runtime could not be restored for sealed replay.", request_key)
		var replay_bundle := _sealed_action_host_candidate_proposal(candidate_resolve_method, action_id, stake, replay_source, compact_input_ledger, compact_proposal_input, compact_input_fingerprint, session, direct_full_candidate, uses_compact_authority_evidence, not structural_replay_match)
		compact_proposal = first_bundle.get("proposal", {})
		var replay_proposal: Dictionary = replay_bundle.get("proposal", {})
		var replay_authority_evidence: Dictionary = replay_bundle.get("authority_evidence", {}) if typeof(replay_bundle.get("authority_evidence", {})) == TYPE_DICTIONARY else {}
		compact_authority_evidence = first_bundle.get("authority_evidence", {}) if typeof(first_bundle.get("authority_evidence", {})) == TYPE_DICTIONARY else {}
		compact_component_fingerprints = first_bundle.get("component_fingerprints", {}) if typeof(first_bundle.get("component_fingerprints", {})) == TYPE_DICTIONARY else {}
		if not _sealed_action_host_candidate_proposals_match(compact_proposal, replay_proposal, compact_proposal_input, compact_authority_evidence, replay_authority_evidence):
			if has_runtime_checkpoint:
				_foundation.current_game.call(runtime_restore_method, runtime_checkpoint)
			return _sealed_action_host_rejection("invalid_proposal", "Blackjack game proposal failed closed validation.", request_key)
		trusted_proposed_candidate = first_bundle.get("candidate", null) as RunState
		if has_runtime_checkpoint:
			var replay_candidate: RunState = replay_bundle.get("candidate", null) as RunState
			accepted_runtime_checkpoint = _foundation.current_game.call(runtime_checkpoint_method, replay_candidate if replay_candidate != null else candidate)
			if not bool(_foundation.current_game.call(runtime_restore_method, runtime_checkpoint)):
				return _sealed_action_host_rejection("invalid_proposal", "Game runtime could not be restored after sealed replay.", request_key)
	else:
		compact_proposal = _foundation.current_game.call(
			resolve_method,
			action_id,
			stake,
			compact_proposal_input.get("run_snapshot", {}),
			compact_proposal_input.get("rng_snapshot", {}),
			session
		)
		if not _sealed_action_host_proposal_valid(compact_proposal, compact_proposal_input):
			return _sealed_action_host_rejection("invalid_proposal", "Blackjack game proposal failed closed validation.", request_key)
	var compact_output_ledger: Dictionary
	if uses_compact_authority_evidence and trusted_proposed_candidate != null:
		var compact_output_table: Dictionary = _foundation.current_game.call("_table_state_preview", trusted_proposed_candidate, trusted_proposed_candidate.current_environment)
		compact_output_ledger = (compact_output_table.get(_foundation.ActionAuthorityScript.LEDGER_KEY, {}) as Dictionary).duplicate(false) if typeof(compact_output_table.get(_foundation.ActionAuthorityScript.LEDGER_KEY, {})) == TYPE_DICTIONARY else {}
	else:
		compact_output_ledger = _sealed_action_host_snapshot_ledger(compact_proposal.get("run_snapshot", {}))
	var expanded_ledger := _sealed_action_host_expand_proposal_ledger(funded_ledger, compact_input_ledger, compact_output_ledger)
	if expanded_ledger.is_empty():
		return _sealed_action_host_rejection("invalid_proposal", "Blackjack proposal changed sealed authority history or delivery state.", request_key)
	# Both replacements below are top-level. The compact proposal has already
	# passed exact replay validation, and its nested values remain read-only.
	var proposal := compact_proposal.duplicate(false)
	if not uses_compact_authority_evidence:
		proposal["run_snapshot"] = _sealed_action_host_snapshot_with_ledger(
			compact_proposal.get("run_snapshot", {}),
			expanded_ledger
		)
	var proposal_fingerprints := _sealed_action_host_proposal_fingerprints(proposal, proposal_input, compact_authority_evidence, compact_component_fingerprints)
	# Proposal fingerprints are sealed above and the local proposal is never read
	# again. Isolate the result's top-level host metadata without cloning nested
	# game presentation/delta payloads that apply_result already owns defensively.
	var result: Dictionary = (proposal.get("result", {}) as Dictionary).duplicate(false)
	if not bool(proposal.get("ok", false)) or not bool(result.get("ok", false)):
		result["ok"] = false
		result[_foundation.ActionAuthorityScript.HOST_REQUEST_KEY] = request_key
		result[_foundation.ActionAuthorityScript.HOST_COMMITTED_KEY] = false
		return result
	if str(result.get("game_id", result.get("source_id", ""))) != _foundation.current_game.get_id() \
			or str(result.get("action_id", "")) != action_id \
			or str(result.get("environment_id", "")) != str(candidate.current_environment.get("id", "")):
		return _sealed_action_host_rejection("invalid_proposal", "Blackjack result identity did not match the sealed delivery.", request_key)
	var proposed_candidate := trusted_proposed_candidate
	if commits_in_place and trusted_proposed_candidate != null:
		# Both detached executions matched before this first live gameplay mutation.
		# Transfer the accepted machine as one owned value; the pending delivery was
		# already durable and all account/result consequences remain host-owned below.
		var accepted_table: Dictionary = _foundation.current_game.call("_table_state_preview", trusted_proposed_candidate, trusted_proposed_candidate.current_environment)
		# trusted_proposed_candidate is the isolated first execution and is never
		# read again after this transfer. Its table can move into the live run without
		# recursively cloning the reel, animation, and feature payload a fourth time.
		accepted_table[_foundation.ActionAuthorityScript.LEDGER_KEY] = expanded_ledger.duplicate(false)
		_foundation.current_game.call("_update_environment_table", _foundation.run_state.current_environment, accepted_table)
		proposed_candidate = _foundation.run_state
	if proposed_candidate == null:
		proposed_candidate = _sealed_action_host_restored_candidate(
			compact_proposal.get("run_snapshot", {}),
			JsonCoerceScript._copy_dict(candidate.current_environment.get("scenario_layout_context", {})),
			candidate.current_environment
		)
	if proposed_candidate == null:
		return _sealed_action_host_rejection("invalid_proposal", "Blackjack proposal scenario semantics could not be rebuilt.", request_key)
	if str(expanded_ledger.get("checkpoint_fingerprint", "")) != proposed_candidate.action_authority_checkpoint_fingerprint():
		return _sealed_action_host_rejection("invalid_proposal", "Blackjack proposal checkpoint did not match its canonical account and RNG state.", request_key)
	var proposed_table: Dictionary = _foundation.current_game.call("_table_state", proposed_candidate, proposed_candidate.current_environment)
	proposed_table[_foundation.ActionAuthorityScript.LEDGER_KEY] = expanded_ledger.duplicate(false)
	_foundation.current_game.call("_update_environment_table", proposed_candidate.current_environment, proposed_table)
	var proposed_ledger := expanded_ledger.duplicate(false)
	if proposed_ledger.is_empty() or GameRitualRuntimeScript.canonical_json(proposed_ledger.get("pending_delivery", {})) != GameRitualRuntimeScript.canonical_json(delivery):
		return _sealed_action_host_rejection("invalid_proposal", "Blackjack proposal changed its delivery authority.", request_key)
	var proposed_rng := RngStream.new()
	proposed_rng.restore(proposal.get("rng_snapshot", {}))
	var skip_environment_turn := _sealed_action_host_normalize_environment_turn(result, action_id)
	var requires_apply := _sealed_action_host_normalize_result_authority(result, provider_contract)
	result[_foundation.ActionAuthorityScript.HOST_COMMITTED_KEY] = true
	result[_foundation.ActionAuthorityScript.HOST_REQUEST_KEY] = request_key
	result[_foundation.ActionAuthorityScript.HOST_DELIVERY_KEY] = delivery.duplicate(true)
	result[_foundation.ActionAuthorityScript.HOST_BOUNDARY_ORDINAL_KEY] = int(delivery.get("boundary_ordinal", 0))
	result[_foundation.ActionAuthorityScript.HOST_WAGER_COST_KEY] = wager_cost
	result[_foundation.ActionAuthorityScript.HOST_FUNDING_LEASE_KEY] = funding_preview.duplicate(true)
	result[_foundation.ActionAuthorityScript.HOST_INTENT_FINGERPRINT_KEY] = str(delivery.get("intent_fingerprint", ""))
	result[_foundation.ActionAuthorityScript.HOST_CONTEXT_FINGERPRINT_KEY] = str(delivery.get("trusted_context_fingerprint", ""))
	var binding := _sealed_action_host_table_binding(proposed_candidate.current_environment)
	var receipt: Dictionary = _foundation.ActionAuthorityScript.receipt_for(
		delivery,
		binding,
		result,
		str(proposal_fingerprints.get("proposal_fingerprint", "")),
		str(proposal_fingerprints.get("run_fingerprint", "")),
		str(proposal_fingerprints.get("rng_fingerprint", ""))
	)
	# receipt_for has just fingerprinted the same result content and excludes both
	# host receipt fields by contract. Reuse that verified binding instead of
	# serializing the result a second time before apply.
	result[_foundation.ActionAuthorityScript.HOST_CONTENT_FINGERPRINT_KEY] = str(receipt.get("result_fingerprint", ""))
	result[_foundation.ActionAuthorityScript.HOST_APPLY_RECEIPT_KEY] = receipt.duplicate(true)
	var environment_id := str(proposed_candidate.current_environment.get("id", ""))
	var suspicion_before := proposed_candidate.suspicion_level_for_environment_id(environment_id)
	var should_apply := requires_apply or bool(result.get("host_apply_result", false))
	if should_apply:
		var table: Dictionary = _foundation.current_game.call("_table_state", proposed_candidate, proposed_candidate.current_environment)
		table[_foundation.ActionAuthorityScript.PENDING_APPLY_RECEIPT_KEY] = receipt.duplicate(true)
		_foundation.current_game.call("_update_environment_table", proposed_candidate.current_environment, table)
		GameModule.apply_result(proposed_candidate, result, proposed_rng, str(receipt.get("result_fingerprint", "")))
		var applied_table: Dictionary = _foundation.current_game.call("_table_state_preview", proposed_candidate, proposed_candidate.current_environment)
		if applied_table.has(_foundation.ActionAuthorityScript.PENDING_APPLY_RECEIPT_KEY):
			return _sealed_action_host_rejection("apply_receipt_rejected", "Blackjack result apply did not consume its exact pending receipt.", request_key)
	# Main's environment turn is itself a snapshot transaction. Reconcile the
	# detached ledger to the post-apply account/RNG before entering that boundary.
	if proposed_ledger.is_empty():
		return _sealed_action_host_rejection("invalid_proposal", "Blackjack authority disappeared after result apply.", request_key)
	proposed_ledger["checkpoint_fingerprint"] = proposed_candidate.action_authority_checkpoint_fingerprint()
	_sealed_action_host_store_ledger(proposed_candidate, proposed_ledger)
	if not bool(result.get("defer_bankroll_zero_failure", false)) and not skip_environment_turn:
		# Route through the Foundation compatibility seam so retained subclasses can
		# still reject or audit the environment-turn publish boundary.
		var turn_result := _foundation.call("_sealed_action_host_advance_environment_turn", proposed_candidate) as Dictionary
		if not bool(turn_result.get("ok", false)):
			return _sealed_action_host_rejection(str(turn_result.get("error_code", "environment_turn_failed")), "Blackjack transaction could not cross the environment boundary.", request_key)
	var suspicion_after := proposed_candidate.suspicion_level_for_environment_id(environment_id)
	var transaction_suspicion_delta := suspicion_after - suspicion_before
	var action_suspicion_delta := int((result.get("deltas", {}) as Dictionary).get("suspicion_delta", result.get("suspicion_delta", 0))) if typeof(result.get("deltas", {})) == TYPE_DICTIONARY else int(result.get("suspicion_delta", 0))
	if transaction_suspicion_delta != action_suspicion_delta:
		result[_foundation.ActionAuthorityScript.HOST_ACTION_SUSPICION_DELTA_KEY] = action_suspicion_delta
		result[_foundation.ActionAuthorityScript.HOST_ENVIRONMENT_TURN_SUSPICION_DELTA_KEY] = transaction_suspicion_delta - action_suspicion_delta
		result["suspicion_delta"] = transaction_suspicion_delta
		var transaction_deltas: Dictionary = result.get("deltas", {}).duplicate(true) if typeof(result.get("deltas", {})) == TYPE_DICTIONARY else GameModule.empty_result_deltas()
		transaction_deltas["suspicion_delta"] = transaction_suspicion_delta
		result["deltas"] = transaction_deltas
		GameModule.normalize_skill_cheat_contract(result)
	var committed_session: Dictionary = {}
	if typeof(result.get("ui_state", null)) == TYPE_DICTIONARY:
		committed_session = result.get("ui_state", {})
	elif typeof(result.get(_foundation.ActionAuthorityScript.SURFACE_UI_STATE_KEY, null)) == TYPE_DICTIONARY:
		committed_session = result.get(_foundation.ActionAuthorityScript.SURFACE_UI_STATE_KEY, {})
	elif action_id != "play_basic":
		committed_session = session
	if proposed_ledger.is_empty():
		return _sealed_action_host_rejection("invalid_proposal", "Blackjack ledger disappeared before commit.", request_key)
	proposed_ledger = _foundation.ActionAuthorityScript.stage_session_cow(proposed_ledger, committed_session)
	var committed_receipt: Dictionary = _foundation.ActionAuthorityScript.receipt_for(
		delivery,
		binding,
		result,
		str(proposal_fingerprints.get("proposal_fingerprint", "")),
		str(proposal_fingerprints.get("run_fingerprint", "")),
		str(proposal_fingerprints.get("rng_fingerprint", ""))
	)
	result[_foundation.ActionAuthorityScript.HOST_APPLY_RECEIPT_KEY] = committed_receipt
	result[_foundation.ActionAuthorityScript.HOST_CONTENT_FINGERPRINT_KEY] = str(committed_receipt.get("result_fingerprint", ""))
	proposed_ledger = _foundation.ActionAuthorityScript.commit_response_cow_with_result_fingerprint(
		proposed_ledger,
		delivery,
		result,
		str(proposal_fingerprints.get("proposal_fingerprint", "")),
		str(proposal_fingerprints.get("run_fingerprint", "")),
		str(proposal_fingerprints.get("rng_fingerprint", "")),
		proposed_candidate.action_authority_checkpoint_fingerprint(),
		str(committed_receipt.get("result_fingerprint", "")),
		int(provider_contract.get("active_replay_limit", _foundation.ActionAuthorityScript.ACTIVE_REPLAY_LIMIT))
	)
	_sealed_action_host_store_ledger(proposed_candidate, proposed_ledger)
	if has_runtime_checkpoint and not bool(_foundation.current_game.call(runtime_restore_method, accepted_runtime_checkpoint)):
		return _sealed_action_host_rejection("internal_fail_closed", "Game runtime could not publish the accepted transaction.", request_key)
	if not _sealed_action_host_publish(proposed_candidate):
		if has_runtime_checkpoint:
			_foundation.current_game.call(runtime_restore_method, runtime_checkpoint)
		return _sealed_action_host_rejection("internal_fail_closed", "Blackjack host could not publish the accepted transaction.", request_key)
	return result


func _sealed_action_host_normalize_result_authority(result: Dictionary, provider_contract: Dictionary) -> bool:
	var proposal_requires_apply_key := str(provider_contract.get("proposal_requires_apply_key", ""))
	var requires_apply := not proposal_requires_apply_key.is_empty() and bool(result.get(proposal_requires_apply_key, false))
	if not proposal_requires_apply_key.is_empty():
		result.erase(proposal_requires_apply_key)
	var authoritative_result_marker := str(provider_contract.get("authoritative_result_marker", ""))
	if not authoritative_result_marker.is_empty():
		# The host owns capability minting even when a canonical provider authored
		# the proposal. Strip every inbound claim before observing host policy.
		result.erase(authoritative_result_marker)
		if requires_apply:
			result[authoritative_result_marker] = true
	return requires_apply


func _sealed_action_host_normalize_environment_turn(result: Dictionary, action_id: String) -> bool:
	# A proposal may describe an internal preference, but it cannot grant itself
	# authority over the host's environment clock. Erase the inbound marker and
	# derive the exception only from this host-owned, exact game/action allowlist.
	result.erase(_foundation.ActionAuthorityScript.SKIP_ENVIRONMENT_TURN_KEY)
	if _foundation.current_game == null:
		return false
	var game_id = _foundation.current_game.get_id()
	var allowed_value: Variant = _foundation.SEALED_ACTION_HOST_SKIP_ENVIRONMENT_TURN_ALLOWLIST.get(game_id, [])
	var provider_allowed_value: Variant = _foundation.action_authority_contract.get("skip_environment_turn_actions", [])
	var legacy_allowed := typeof(allowed_value) == TYPE_ARRAY and (allowed_value as Array).has(action_id)
	var provider_allowed := typeof(provider_allowed_value) == TYPE_ARRAY and (provider_allowed_value as Array).has(action_id)
	return legacy_allowed or provider_allowed
