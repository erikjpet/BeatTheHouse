class_name ScenarioEngine
extends RefCounted

const SequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const SequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const SequenceCatalogScript := preload("res://scripts/core/scenario_sequence_catalog.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const ScenarioExtensionDispatchScript := preload("res://scripts/core/scenario_extension_dispatch.gd")
const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")
const VALIDATED_SEQUENCE_MARKER := "__scenario_sequence_runtime_validated"
const SEQUENCE_SUPPRESSION_KEY := "sequence_suppressed"
const EnvironmentSemanticInventoryScript := preload("res://scripts/core/environment_semantic_inventory.gd")

# Deterministic scenario overlays. Selection belongs to RunGenerator; this
# module only builds and advances the selected node-owned state.

const STATE_SCHEMA_VERSION := 1
const ALLOWED_MUTATION_KEYS := [
	"patron_set",
	"staff_set",
	"event_pool_add",
	"event_pool_remove",
	"item_offer_add",
	"item_offer_remove",
	"economic_profile_overrides",
	"game_modifier_hooks",
	"service_add",
	"service_remove",
	"music_profile_override",
	"presentation",
	"exclusive_opportunity",
	"security_overrides",
	"hook_flags",
	"travel_lock_actions",
]
const ALLOWED_PRESENTATION_KEYS := ["palette_tint", "lighting_key", "crowd_density", "signage_line"]
const ALLOWED_EXCLUSIVE_KEYS := ["event_id", "game_id"]
const ALLOWED_SECURITY_KEYS := ["strictness_band", "cheat_risk_window", "machine_alarm_tolerance_band"]


static func initial_state(definition: Dictionary) -> Dictionary:
	if definition.is_empty():
		return {}
	return {
		"schema_version": STATE_SCHEMA_VERSION,
		"id": str(definition.get("id", "")).strip_edges(),
		"archetype_id": str(definition.get("archetype_id", "")).strip_edges(),
		"layer_id": str(definition.get("layer_id", "")).strip_edges(),
		"display_name": str(definition.get("display_name", "")).strip_edges(),
		"placeholder": bool(definition.get("placeholder", false)),
		"sequence_suppressed": bool(definition.get(SEQUENCE_SUPPRESSION_KEY, false)),
		"phase_index": 0,
		"phase_action_counter": 0,
		"mutations": _copy_dict(definition.get("mutations", {})),
		"phases": _copy_array(definition.get("phases", [])),
		"town_weight_tags": _string_array(definition.get("town_weight_tags", [])),
	}


static func normalize_state(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = value
	var scenario_id := str(source.get("id", "")).strip_edges()
	if scenario_id.is_empty():
		return {}
	var phases := _copy_array(source.get("phases", []))
	var phase_index := maxi(0, int(source.get("phase_index", 0)))
	if not phases.is_empty():
		phase_index = mini(phase_index, phases.size() - 1)
	else:
		phase_index = 0
	return {
		"schema_version": STATE_SCHEMA_VERSION,
		"id": scenario_id,
		"archetype_id": str(source.get("archetype_id", "")).strip_edges(),
		"layer_id": str(source.get("layer_id", "")).strip_edges(),
		"display_name": str(source.get("display_name", scenario_id)).strip_edges(),
		"placeholder": bool(source.get("placeholder", false)),
		"sequence_suppressed": bool(source.get(SEQUENCE_SUPPRESSION_KEY, false)),
		"phase_index": phase_index,
		"phase_action_counter": maxi(0, int(source.get("phase_action_counter", 0))),
		"mutations": _copy_dict(source.get("mutations", {})),
		"phases": phases,
		"town_weight_tags": _string_array(source.get("town_weight_tags", [])),
	}


static func apply_to_archetype(archetype: Dictionary, state_value: Variant) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty():
		return archetype
	var result := archetype.duplicate(true)
	if not _state_targets_layer(state, result):
		return result
	_apply_mutations(result, _copy_dict(state.get("mutations", {})), true)
	var phases := _copy_array(state.get("phases", []))
	var phase_index := mini(maxi(0, int(state.get("phase_index", 0))), phases.size() - 1)
	for index in range(phase_index + 1):
		if index < phases.size() and typeof(phases[index]) == TYPE_DICTIONARY:
			_apply_mutations(result, _copy_dict((phases[index] as Dictionary).get("mutations", {})), true)
	return result


static func attach_to_environment(environment: Dictionary, state_value: Variant, definition: Dictionary = {}) -> void:
	var state := normalize_state(state_value)
	if state.is_empty():
		return
	environment["scenario_state"] = state
	environment["scenario_id"] = str(state.get("id", ""))
	environment["scenario_phase_index"] = int(state.get("phase_index", 0))
	environment["scenario_phase_action_counter"] = int(state.get("phase_action_counter", 0))
	environment["scenario_applied_phase_index"] = int(state.get("phase_index", 0)) if _state_targets_layer(state, environment) else -1
	_apply_exclusive_opportunity(environment)
	migrate_environment_sequence(environment, definition, str(environment.get("id", "")))


# Public sequence API. Producers publish through enqueue/flush and never mutate
# sequence internals. RunState supplies the node-owned definition/state seam.
static func sequence_definition_for_environment(environment: Dictionary, preferred: Dictionary = {}) -> Dictionary:
	var scenario_id := str(_copy_dict(environment.get("scenario_state", {})).get("id", environment.get("scenario_id", ""))).strip_edges()
	if scenario_id.is_empty():
		return {}
	if _sequence_is_suppressed(environment, preferred):
		var suppressed_source := preferred if not preferred.is_empty() and str(preferred.get("id", preferred.get("scenario_id", ""))).strip_edges() == scenario_id else {"id": scenario_id, "archetype_id": str(_copy_dict(environment.get("scenario_state", {})).get("archetype_id", environment.get("archetype_id", "")))}
		return suppress_sequence_definition(suppressed_source)
	# RunState caches the immutable resolved definition. Preserve that owned
	# validation receipt so refresh/presentation reads never re-run the schema.
	if not preferred.is_empty() \
		and str(preferred.get("id", preferred.get("scenario_id", ""))).strip_edges() == scenario_id \
		and bool(preferred.get(VALIDATED_SEQUENCE_MARKER, false)):
		return preferred
	var candidate: Dictionary = {}
	if not preferred.is_empty() and str(preferred.get("id", preferred.get("scenario_id", ""))).strip_edges() == scenario_id:
		candidate = SequenceCatalogScript.apply_overlay(preferred)
	else:
		candidate = SequenceCatalogScript.legacy_definition(scenario_id)
	if SequenceSchemaScript.is_sequence(candidate):
		var errors := SequenceSchemaScript.validate_definition(candidate, OperationRegistryScript)
		if candidate.has("sequence_package_id"):
			var catalog := SequenceCatalogScript.default_catalog_snapshot()
			var registered_overlay := SequenceCatalogScript.overlay_for(scenario_id, catalog)
			if not bool(catalog.get("ok", false)) or registered_overlay.is_empty() or str(registered_overlay.get("package_id", "")) != str(candidate.get("sequence_package_id", "")):
				errors.append("scenario sequence package is not active in the fail-closed content catalog")
			errors.append_array(ScenarioExtensionDispatchScript.validate_package_extensions(
				str(candidate.get("sequence_package_id", "")),
				str(candidate.get("sequence_handler_pack", "")),
				str(candidate.get("sequence_renderer_id", ""))
			))
		if not errors.is_empty():
			return _without_sequence_overlay(candidate)
		candidate[VALIDATED_SEQUENCE_MARKER] = true
	return candidate


static func migrate_environment_sequence(environment: Dictionary, preferred: Dictionary = {}, seed_token: String = "") -> Dictionary:
	var legacy := normalize_state(environment.get("scenario_state", {}))
	if legacy.is_empty():
		return {"ok": true, "changed": false, "active": false, "scenario_id": ""}
	var scenario_id := str(legacy.get("id", ""))
	if _sequence_is_suppressed(environment, preferred):
		var suppressed_before := JSON.stringify(environment)
		_clear_environment_sequence(environment)
		return {"ok": true, "changed": suppressed_before != JSON.stringify(environment), "active": false, "suppressed": true, "scenario_id": scenario_id, "definition": sequence_definition_for_environment(environment, preferred)}
	var definition := sequence_definition_for_environment(environment, preferred)
	# A runtime installed before its content packages must leave legacy snapshots
	# exactly alone. Once an overlay exists, migration is deterministic and in-place.
	if not SequenceSchemaScript.is_sequence(definition):
		return {"ok": true, "changed": false, "active": false, "scenario_id": scenario_id, "definition": definition}
	var before := JSON.stringify(environment)
	var migration := {
		"schema_version": SequenceRuntimeScript.STATE_SCHEMA_VERSION,
		"scenario_id": scenario_id,
		"receipt_id": "legacy:%s:v%d" % [scenario_id, SequenceRuntimeScript.STATE_SCHEMA_VERSION],
		"status": "sequence_active",
	}
	environment["scenario_sequence_migration"] = migration
	ensure_sequence_state(environment, definition, seed_token)
	return {"ok": true, "changed": before != JSON.stringify(environment), "active": true, "scenario_id": scenario_id, "definition": definition}


static func ensure_sequence_state(environment: Dictionary, definition: Dictionary, seed_token: String = "") -> Dictionary:
	if _sequence_is_suppressed(environment, definition):
		_clear_environment_sequence(environment)
		return {}
	definition = sequence_definition_for_environment(environment, definition)
	if not SequenceSchemaScript.is_sequence(definition):
		return {}
	if not bool(environment.get("scenario_semantic_ready", false)):
		return {}
	if not str(environment.get("scenario_sequence_migration_error", "")).is_empty():
		environment["scenario_sequence_lifecycle_errors"] = [str(environment.get("scenario_sequence_migration_error", ""))]
		environment.erase("scenario_semantic_ready")
		return {}
	var node_id := str(environment.get("world_node_id", environment.get("archetype_id", environment.get("id", "")))).strip_edges()
	var host_semantics := sequence_host_semantics(environment)
	var state := SequenceRuntimeScript.normalize_state(environment.get("scenario_sequence_state", {}), definition, host_semantics)
	if state.is_empty() and environment.has("scenario_sequence_state"):
		environment["scenario_sequence_migration_error"] = "Persisted dynamic room sequence state cannot be normalized; explicit migration is required."
		environment["scenario_sequence_lifecycle_errors"] = [str(environment.get("scenario_sequence_migration_error", ""))]
		environment.erase("scenario_semantic_ready")
		return {}
	if state.is_empty():
		_capture_sequence_baseline(environment)
		state = SequenceRuntimeScript.initial_state(definition, node_id, seed_token, host_semantics)
	else:
		var node_binding_failed := false
		if str(state.get("node_id", "")) != node_id:
			if _sequence_state_can_bind_initial_node(state, environment, definition, host_semantics):
				# Initial operation/transition receipts are structurally bound to the
				# old node. Recreate the semantically pristine initial state instead
				# of rewriting its node while retaining contradictory journals.
				state = SequenceRuntimeScript.initial_state(definition, node_id, str(state.get("seed_token", "")), host_semantics)
				if state.is_empty() or str(state.get("status", "")) == SequenceRuntimeScript.STATUS_CLEANED:
					node_binding_failed = true
			else:
				node_binding_failed = true
				state["status"] = SequenceRuntimeScript.STATUS_CLEANED
				state["errors"] = ["scenario progressed sequence state is bound to another world node; explicit migration is required"]
		if not node_binding_failed and not _copy_array(host_semantics.get("inventory_errors", [])).is_empty():
			state["status"] = SequenceRuntimeScript.STATUS_CLEANED
			state["errors"] = _copy_array(host_semantics.get("inventory_errors", []))
		elif not node_binding_failed and (int(_copy_dict(state.get("semantic_state", {})).get("inventory_schema_version", 0)) != int(host_semantics.get("inventory_schema_version", 0)) or str(_copy_dict(state.get("semantic_state", {})).get("inventory_digest", "")) != str(host_semantics.get("inventory_digest", ""))):
			state["status"] = SequenceRuntimeScript.STATUS_CLEANED
			state["errors"] = ["scenario semantic inventory digest changed; explicit migration is required"]
		elif not node_binding_failed:
			# Saved authorization arrays are never trusted. Rebuild and replace them
			# from the immutable current EnvironmentInstance proof on every ingress.
			var semantic := _copy_dict(state.get("semantic_state", {}))
			var target_inventory := _copy_dict(host_semantics.get("target_inventory", {}))
			target_inventory["event_choices"] = _copy_dict(host_semantics.get("event_choices", {}))
			semantic["target_inventory"] = target_inventory
			semantic["declared_targets"] = SequenceSchemaScript.verified_declared_targets(definition, target_inventory)
			semantic["base_interactions"] = _copy_array(host_semantics.get("base_interactions", []))
			semantic["event_choices"] = _copy_dict(host_semantics.get("event_choices", {}))
			state["semantic_state"] = semantic
			var rebuilt := _rebuild_receipted_semantic_mutations(state, definition, host_semantics)
			if not bool(rebuilt.get("ok", false)):
				state["status"] = SequenceRuntimeScript.STATUS_CLEANED
				state["errors"] = _copy_array(rebuilt.get("errors", []))
			else:
				state = _copy_dict(rebuilt.get("state", state))
	environment["scenario_sequence_state"] = state
	return state.duplicate(true)


static func _rebuild_receipted_semantic_mutations(state_value: Dictionary, definition: Dictionary, host_semantics: Dictionary) -> Dictionary:
	var state := state_value.duplicate(true)
	var errors: Array = []
	var causal_record_total := _copy_array(state.get("command_receipt_records", [])).size() + _copy_array(state.get("fact_receipt_records", [])).size() + _copy_array(state.get("visit_receipt_records", [])).size() + _copy_array(state.get("expiry_boundary_records", [])).size()
	if causal_record_total > SequenceRuntimeScript.MAX_RECEIPTS or causal_record_total + _copy_array(state.get("fact_queue", [])).size() > SequenceRuntimeScript.MAX_RECEIPTS:
		errors.append("scenario causal journal plus pending facts exceeds the lifetime receipt limit")
	var cause_validation := _validated_cause_records(state, definition, host_semantics)
	errors.append_array(_copy_array(cause_validation.get("errors", [])))
	var expiry_validation := _validated_expiry_boundary_records(state, definition)
	errors.append_array(_copy_array(expiry_validation.get("errors", [])))
	var visit_validation := _validated_visit_records(state)
	errors.append_array(_copy_array(visit_validation.get("errors", [])))
	if not errors.is_empty(): return {"ok": false, "errors": errors}
	var causal_records := _copy_array(cause_validation.get("ordered_records", []))
	causal_records.append_array(_copy_array(expiry_validation.get("ordered_records", [])))
	causal_records.append_array(_copy_array(visit_validation.get("ordered_records", [])))
	causal_records.sort_custom(func(a: Variant, b: Variant) -> bool: return int(_copy_dict(a).get("cause_ordinal", -1)) < int(_copy_dict(b).get("cause_ordinal", -1)))
	for record_index in range(causal_records.size()):
		if int(_copy_dict(causal_records[record_index]).get("cause_ordinal", -1)) != record_index:
			errors.append("scenario causal journal ordinals are incomplete, duplicated, or reordered")
	if not errors.is_empty(): return {"ok": false, "errors": errors}
	var replay := SequenceRuntimeScript.initial_state(definition, str(state.get("node_id", "")), str(state.get("seed_token", "")), host_semantics)
	if replay.is_empty() or str(replay.get("status", "")) == SequenceRuntimeScript.STATUS_CLEANED:
		return {"ok": false, "errors": ["scenario causal replay could not initialize trusted host semantics"]}
	var replay_result := _replay_causal_records(replay, definition, causal_records, _copy_array(cause_validation.get("fact_batch_records", [])))
	if not bool(replay_result.get("ok", false)):
		return {"ok": false, "errors": _copy_array(replay_result.get("errors", []))}
	replay = _copy_dict(replay_result.get("state", replay))
	errors.append_array(_exact_replay_journal_errors(state, replay))
	if not errors.is_empty(): return {"ok": false, "errors": errors}
	# Preserve only pending ingress, which has not crossed a causal boundary.
	# Every applied mutation and visit comes from the trusted replay above.
	replay["fact_queue"] = _copy_array(state.get("fact_queue", []))
	replay["fact_serial_next"] = maxi(int(replay.get("fact_serial_next", 1)), int(state.get("fact_serial_next", 1)))
	var semantic := _copy_dict(replay.get("semantic_state", {}))
	# Transition operations are one-shot presentation effects. Their receipts
	# prove they ran, but save/revisit reconstruction must never replay them.
	semantic["transition_queue"] = []
	replay["semantic_state"] = semantic
	return {"ok": true, "state": replay, "errors": []}


static func _validated_cause_records(state: Dictionary, definition: Dictionary, host_semantics: Dictionary) -> Dictionary:
	var errors: Array = []
	var causes: Dictionary = {}
	var ordered_records: Array = []
	var validated_command_records: Array = []
	var command_receipts := _copy_array(state.get("command_receipts", []))
	var command_fingerprints := _copy_dict(state.get("command_fingerprints", {}))
	var command_records := _copy_array(state.get("command_receipt_records", []))
	for record_index in range(command_records.size()):
		var record := _copy_dict(command_records[record_index])
		var envelope := _copy_dict(record.get("envelope", {}))
		var causal_descriptor := _copy_dict(record.get("causal_action_descriptor", {}))
		if record.size() != 6 or not _exact_string_fields(record, ["receipt_key", "fingerprint", "causal_action_descriptor_fingerprint"]) or not _valid_sha256(str(record.get("fingerprint", ""))) or not _valid_sha256(str(record.get("causal_action_descriptor_fingerprint", ""))) or typeof(record.get("cause_ordinal")) != TYPE_INT or int(record.get("cause_ordinal", -1)) < 0 or envelope.size() != 13 or typeof(envelope.get("schema_version")) != TYPE_INT or int(envelope.get("schema_version", 0)) != SequenceRuntimeScript.COMMAND_SCHEMA_VERSION or typeof(envelope.get("payload")) != TYPE_DICTIONARY or causal_descriptor.is_empty():
			errors.append("scenario command receipt record is not closed and typed")
			continue
		var command_strings := ["command_id", "node_id", "expected_phase", "idempotency_key", "owner_namespace", "stable_object_id", "action_origin_owner_namespace", "action_origin_stable_object_id", "action_origin_receipt_key", "action_origin_boundary_id", "action_origin_fingerprint"]
		if not _exact_string_values(envelope, command_strings, ["action_origin_receipt_key", "action_origin_boundary_id", "action_origin_fingerprint"]):
			errors.append("scenario command receipt envelope contains non-exact string fields")
			continue
		var receipt_key := str(record.get("receipt_key", ""))
		var fingerprint := SequenceRuntimeScript.content_fingerprint(envelope)
		var cause_key := "command|%s" % receipt_key
		if record_index >= command_receipts.size() or str(command_receipts[record_index]) != receipt_key or str(envelope.get("idempotency_key", "")) != receipt_key or str(envelope.get("node_id", "")) != str(state.get("node_id", "")) or SequenceSchemaScript.phase(definition, str(envelope.get("expected_phase", ""))).is_empty() or OperationRegistryScript.parse_owned_identity(OperationRegistryScript.identity(str(envelope.get("owner_namespace", "")), str(envelope.get("stable_object_id", "")))).is_empty() or str(record.get("fingerprint", "")) != fingerprint or str(command_fingerprints.get(receipt_key, "")) != fingerprint or str(record.get("causal_action_descriptor_fingerprint", "")) != SequenceRuntimeScript.content_fingerprint(causal_descriptor) or not SequenceRuntimeScript.validate_causal_action_descriptor(state, definition, envelope, causal_descriptor).is_empty() or causes.has(cause_key):
			errors.append("scenario command receipt record does not authenticate its exact envelope")
			continue
		validated_command_records.append(record)
		causes[cause_key] = {"kind": "command", "receipt_key": receipt_key, "fingerprint": fingerprint, "envelope": envelope}
		ordered_records.append({"kind": "command", "cause_ordinal": int(record.get("cause_ordinal", -1)), "record": record})
	if command_receipts.size() != validated_command_records.size() or command_fingerprints.size() != validated_command_records.size():
		errors.append("scenario command receipts contain unauthenticated entries")
	var fact_receipts := _copy_array(state.get("fact_receipts", []))
	var fact_fingerprints := _copy_dict(state.get("fact_fingerprints", {}))
	var fact_records := _copy_array(state.get("fact_receipt_records", []))
	var fact_validation_state := state.duplicate(true)
	fact_validation_state["status"] = SequenceRuntimeScript.STATUS_ACTIVE
	var trusted_semantic := _copy_dict(fact_validation_state.get("semantic_state", {}))
	trusted_semantic["event_choices"] = _copy_dict(host_semantics.get("event_choices", {}))
	fact_validation_state["semantic_state"] = trusted_semantic
	var validated_fact_records: Array = []
	for record_index in range(fact_records.size()):
		var record := _copy_dict(fact_records[record_index])
		var envelope := _copy_dict(record.get("envelope", {}))
		if record.size() != 6 or not _exact_string_fields(record, ["receipt_key", "fingerprint"]) or not _valid_sha256(str(record.get("fingerprint", ""))) or typeof(record.get("cause_ordinal")) != TYPE_INT or int(record.get("cause_ordinal", -1)) < 0 or typeof(record.get("flush_batch_ordinal")) != TYPE_INT or int(record.get("flush_batch_ordinal", -1)) < 0 or typeof(record.get("flush_boundary_serial")) != TYPE_INT or int(record.get("flush_boundary_serial", -1)) < 0 or envelope.size() != 8 or not SequenceRuntimeScript.validate_fact(fact_validation_state, envelope).is_empty():
			errors.append("scenario fact receipt record is not a closed valid envelope")
			continue
		var receipt_key := str(record.get("receipt_key", ""))
		var fingerprint := SequenceRuntimeScript.content_fingerprint(envelope)
		var cause_key := "fact|%s" % receipt_key
		if record_index >= fact_receipts.size() or str(fact_receipts[record_index]) != receipt_key or str(envelope.get("fact_id", "")) != receipt_key or int(record.get("flush_boundary_serial", -1)) < int(envelope.get("boundary_serial", 0)) or str(record.get("fingerprint", "")) != fingerprint or str(fact_fingerprints.get(receipt_key, "")) != fingerprint or causes.has(cause_key):
			errors.append("scenario fact receipt record does not authenticate its exact envelope")
			continue
		validated_fact_records.append(record)
		causes[cause_key] = {"kind": "fact", "receipt_key": receipt_key, "fingerprint": fingerprint, "envelope": envelope}
		ordered_records.append({"kind": "fact", "cause_ordinal": int(record.get("cause_ordinal", -1)), "record": record})
	if fact_receipts.size() != validated_fact_records.size() or fact_fingerprints.size() != validated_fact_records.size():
		errors.append("scenario fact receipts contain unauthenticated entries")
	var batch_records := _copy_array(state.get("fact_flush_batch_records", []))
	var validated_batch_records: Array = []
	var next_fact_record_index := 0
	var prior_batch_fingerprint := "0".repeat(64)
	var prior_effective_boundary := 0
	for batch_index in range(batch_records.size()):
		var batch := _copy_dict(batch_records[batch_index])
		var receipt_keys := _copy_array(batch.get("fact_receipt_keys", []))
		var batch_fingerprints := _copy_array(batch.get("fact_fingerprints", []))
		if batch.size() != 8 or typeof(batch.get("batch_ordinal")) != TYPE_INT or int(batch.get("batch_ordinal", -1)) != batch_index or typeof(batch.get("requested_boundary_serial")) != TYPE_INT or int(batch.get("requested_boundary_serial", -1)) < 0 or typeof(batch.get("effective_boundary_serial")) != TYPE_INT or int(batch.get("effective_boundary_serial", -1)) < 0 or typeof(batch.get("first_cause_ordinal")) != TYPE_INT or int(batch.get("first_cause_ordinal", -1)) < 0 or typeof(batch.get("fact_receipt_keys")) != TYPE_ARRAY or typeof(batch.get("fact_fingerprints")) != TYPE_ARRAY or receipt_keys.is_empty() or receipt_keys.size() != batch_fingerprints.size() or not _exact_string_fields(batch, ["prior_batch_fingerprint", "batch_fingerprint"]):
			errors.append("scenario fact flush batch delimiter is not closed and typed")
			continue
		if str(batch.get("prior_batch_fingerprint", "")) != prior_batch_fingerprint or not _valid_sha256(str(batch.get("batch_fingerprint", ""))) or str(batch.get("batch_fingerprint", "")) != SequenceRuntimeScript.fact_flush_batch_fingerprint(batch) or int(batch.get("effective_boundary_serial", -1)) != maxi(prior_effective_boundary, int(batch.get("requested_boundary_serial", -1))):
			errors.append("scenario fact flush batch delimiter chain/fingerprint is invalid")
			continue
		var batch_valid := true
		for batch_fact_index in range(receipt_keys.size()):
			if next_fact_record_index >= validated_fact_records.size():
				batch_valid = false
				break
			var fact_record := _copy_dict(validated_fact_records[next_fact_record_index])
			if typeof(receipt_keys[batch_fact_index]) != TYPE_STRING or typeof(batch_fingerprints[batch_fact_index]) != TYPE_STRING or str(receipt_keys[batch_fact_index]) != str(fact_record.get("receipt_key", "")) or str(batch_fingerprints[batch_fact_index]) != str(fact_record.get("fingerprint", "")) or int(fact_record.get("flush_batch_ordinal", -1)) != batch_index or int(fact_record.get("flush_boundary_serial", -1)) != int(batch.get("effective_boundary_serial", -1)) or int(fact_record.get("cause_ordinal", -1)) != int(batch.get("first_cause_ordinal", -1)) + batch_fact_index:
				batch_valid = false
			next_fact_record_index += 1
		if not batch_valid:
			errors.append("scenario fact flush batch delimiter does not authenticate its exact ordered facts")
			continue
		validated_batch_records.append(batch)
		prior_batch_fingerprint = str(batch.get("batch_fingerprint", ""))
		prior_effective_boundary = int(batch.get("effective_boundary_serial", 0))
	if next_fact_record_index != validated_fact_records.size() or validated_batch_records.size() != batch_records.size():
		errors.append("scenario fact receipt records are not covered exactly once by authenticated flush batches")
	return {"causes": causes, "command_records": validated_command_records, "fact_records": validated_fact_records, "fact_batch_records": validated_batch_records, "ordered_records": ordered_records, "errors": errors}


static func _validated_visit_records(state: Dictionary) -> Dictionary:
	var errors: Array = []
	var ordered_records: Array = []
	var receipts := _copy_array(state.get("visit_receipts", []))
	var records := _copy_array(state.get("visit_receipt_records", []))
	var seen: Dictionary = {}
	for record_index in range(records.size()):
		var record := _copy_dict(records[record_index])
		if record.size() != 3 or not _exact_string_fields(record, ["receipt_key", "visit_id"]) or typeof(record.get("cause_ordinal")) != TYPE_INT or int(record.get("cause_ordinal", -1)) < 0 or str(record.get("visit_id", "")).length() > OperationRegistryScript.MAX_VARIANT_TEXT:
			errors.append("scenario visit receipt record is not closed, typed, and bounded")
			continue
		var receipt_key := str(record.get("receipt_key", ""))
		var expected := SequenceRuntimeScript.structural_runtime_receipt("visit", [str(state.get("scenario_id", "")), str(state.get("node_id", "")), str(record.get("visit_id", ""))])
		if record_index >= receipts.size() or str(receipts[record_index]) != receipt_key or receipt_key != expected or seen.has(receipt_key):
			errors.append("scenario visit receipt record does not authenticate its exact visit")
			continue
		seen[receipt_key] = true
		ordered_records.append({"kind": "visit", "cause_ordinal": int(record.get("cause_ordinal", -1)), "record": record})
	if receipts.size() != ordered_records.size():
		errors.append("scenario visit receipts contain unauthenticated entries")
	return {"ordered_records": ordered_records, "errors": errors}


static func _validated_expiry_boundary_records(state: Dictionary, definition: Dictionary) -> Dictionary:
	var errors: Array = []
	var ordered_records: Array = []
	var authored_boundary := str(_copy_dict(SequenceSchemaScript.sequence(definition).get("expiry", {})).get("boundary", "none"))
	for record_value in _copy_array(state.get("expiry_boundary_records", [])):
		var record := _copy_dict(record_value)
		if record.size() != 3 or typeof(record.get("cause_ordinal")) != TYPE_INT or int(record.get("cause_ordinal", -1)) < 0 or typeof(record.get("boundary")) != TYPE_STRING or str(record.get("boundary", "")) != str(record.get("boundary", "")).strip_edges() or str(record.get("boundary", "")).is_empty() or typeof(record.get("amount")) != TYPE_INT or int(record.get("amount", 0)) < 1:
			errors.append("scenario expiry boundary record is not closed and typed")
			continue
		if authored_boundary == "none" or str(record.get("boundary", "")) != authored_boundary:
			errors.append("scenario expiry boundary record does not match the authored boundary")
			continue
		ordered_records.append({"kind": "expiry", "cause_ordinal": int(record.get("cause_ordinal", -1)), "record": record})
	return {"ordered_records": ordered_records, "errors": errors}


static func _replay_causal_records(initial: Dictionary, definition: Dictionary, causal_records: Array, fact_batch_records: Array) -> Dictionary:
	var state := initial.duplicate(true)
	var record_index := 0
	var expected_fact_batch_ordinal := 0
	while record_index < causal_records.size():
		var causal := _copy_dict(causal_records[record_index])
		var kind := str(causal.get("kind", ""))
		if kind == "fact":
			var first_fact_record := _copy_dict(_copy_dict(causal_records[record_index]).get("record", {}))
			var batch_ordinal := int(first_fact_record.get("flush_batch_ordinal", -1))
			var batch := _copy_dict(fact_batch_records[expected_fact_batch_ordinal] if expected_fact_batch_ordinal < fact_batch_records.size() else {})
			var expected_receipt_keys := _copy_array(batch.get("fact_receipt_keys", []))
			var requested_boundary := int(batch.get("requested_boundary_serial", -1))
			var target_boundary := int(batch.get("effective_boundary_serial", -1))
			if batch_ordinal != expected_fact_batch_ordinal or int(batch.get("batch_ordinal", -1)) != batch_ordinal or requested_boundary < 0 or target_boundary < 0:
				return {"ok": false, "state": initial, "errors": ["scenario causal fact batches are missing, duplicated, or reordered"]}
			var batch_fact_index := 0
			while record_index < causal_records.size() and str(_copy_dict(causal_records[record_index]).get("kind", "")) == "fact" and int(_copy_dict(_copy_dict(causal_records[record_index]).get("record", {})).get("flush_batch_ordinal", -1)) == batch_ordinal:
				var fact_record := _copy_dict(_copy_dict(causal_records[record_index]).get("record", {}))
				if batch_fact_index >= expected_receipt_keys.size() or str(fact_record.get("receipt_key", "")) != str(expected_receipt_keys[batch_fact_index]) or int(fact_record.get("flush_boundary_serial", -1)) != target_boundary:
					return {"ok": false, "state": initial, "errors": ["scenario causal fact batch contains conflicting flush boundaries"]}
				var envelope := _copy_dict(fact_record.get("envelope", {}))
				var queued := SequenceRuntimeScript.enqueue_fact(state, definition, envelope)
				if not bool(queued.get("ok", false)) or bool(queued.get("duplicate", false)):
					return {"ok": false, "state": initial, "errors": ["scenario causal replay rejected a journaled fact: %s" % JSON.stringify(queued.get("errors", []))]}
				state = _copy_dict(queued.get("state", state))
				record_index += 1
				batch_fact_index += 1
			if batch_fact_index != expected_receipt_keys.size():
				return {"ok": false, "state": initial, "errors": ["scenario causal fact batch delimiter count does not match its facts"]}
			var flushed := SequenceRuntimeScript.flush_facts(state, definition, requested_boundary)
			if not bool(flushed.get("ok", false)):
				return {"ok": false, "state": initial, "errors": ["scenario causal replay rejected a journaled fact batch: %s" % JSON.stringify(flushed.get("errors", []))]}
			state = _copy_dict(flushed.get("state", state))
			var replayed_batches := _copy_array(state.get("fact_flush_batch_records", []))
			if replayed_batches.is_empty() or SequenceRuntimeScript.content_fingerprint(replayed_batches.back()) != SequenceRuntimeScript.content_fingerprint(batch):
				return {"ok": false, "state": initial, "errors": ["scenario causal replay did not reproduce the exact authenticated fact batch delimiter"]}
			expected_fact_batch_ordinal += 1
			continue
		var record := _copy_dict(causal.get("record", {}))
		var result: Dictionary = {}
		if kind == "command":
			result = SequenceRuntimeScript.apply_command(state, definition, _copy_dict(record.get("envelope", {})), {"available_funds": 9223372036854775807, "causal_action_descriptor": _copy_dict(record.get("causal_action_descriptor", {}))})
		elif kind == "visit":
			result = SequenceRuntimeScript.record_visit(state, definition, str(record.get("visit_id", "")))
		elif kind == "expiry":
			result = SequenceRuntimeScript.apply_expiry_boundary(state, definition, str(record.get("boundary", "")), int(record.get("amount", 1)))
		else:
			return {"ok": false, "state": initial, "errors": ["scenario causal replay encountered an unknown journal kind"]}
		if not bool(result.get("ok", false)):
			return {"ok": false, "state": initial, "errors": ["scenario causal replay rejected a journaled %s: %s" % [kind, JSON.stringify(result.get("errors", []))]]}
		state = _copy_dict(result.get("state", state))
		record_index += 1
	if expected_fact_batch_ordinal != fact_batch_records.size():
		return {"ok": false, "state": initial, "errors": ["scenario causal replay did not consume every authenticated fact batch delimiter"]}
	return {"ok": true, "state": state, "errors": []}


static func _exact_replay_journal_errors(stored: Dictionary, replayed: Dictionary) -> Array:
	var errors: Array = []
	for key in ["command_receipts", "command_receipt_records", "command_results", "command_fingerprints", "fact_receipts", "fact_receipt_records", "fact_flush_batch_records", "fact_fingerprints", "visit_receipts", "visit_receipt_records", "expiry_boundary_records", "branch_resolution_records", "transition_receipts", "transition_receipt_records", "cleanup_receipts", "cleanup_receipt_records", "cleanup_fingerprints", "cleanup_content_fingerprint", "event_correlations"]:
		if SequenceRuntimeScript.content_fingerprint(stored.get(key)) != SequenceRuntimeScript.content_fingerprint(replayed.get(key)):
			errors.append("scenario saved %s does not exactly match causal replay" % key)
	var stored_semantic := _copy_dict(stored.get("semantic_state", {}))
	var replayed_semantic := _copy_dict(replayed.get("semantic_state", {}))
	for key in ["operation_receipts", "operation_receipt_records", "operation_fingerprints"]:
		if SequenceRuntimeScript.content_fingerprint(stored_semantic.get(key)) != SequenceRuntimeScript.content_fingerprint(replayed_semantic.get(key)):
			errors.append("scenario saved semantic %s does not exactly match causal replay" % key)
	return errors


static func _validated_branch_resolution_records(state: Dictionary, definition: Dictionary, transition_records: Array, causes: Dictionary) -> Dictionary:
	var errors: Array = []
	var validated: Array = []
	var resolved_branch_ids: Array = []
	var resolved_outcomes: Array = []
	var used_causes: Dictionary = {}
	var used_transition_sources: Dictionary = {}
	var transition_index := 0
	var current_phase := str(_copy_dict(transition_records[0] if not transition_records.is_empty() else {}).get("phase_id", ""))
	var terminal_seen := false
	var records := _copy_array(state.get("branch_resolution_records", []))
	for record_index in range(records.size()):
		var record := _copy_dict(records[record_index])
		var has_target := record.has("target_phase_id")
		var has_outcome := record.has("terminal_outcome")
		var string_fields := ["phase_id", "branch_id", "trigger_kind", "trigger_receipt_key", "branch_fingerprint", "cause_fingerprint", "target_phase_id" if has_target else "terminal_outcome"]
		if record.size() != 8 or has_target == has_outcome or not _exact_string_fields(record, string_fields) or typeof(record.get("boundary_ordinal")) != TYPE_INT or int(record.get("boundary_ordinal", -1)) != record_index:
			errors.append("scenario branch resolution record is not closed, typed, and ordered")
			continue
		while current_phase != str(record.get("phase_id", "")) and transition_index + 1 < transition_records.size() and str(_copy_dict(transition_records[transition_index + 1]).get("source_receipt", "")) == "ordered_compat":
			transition_index += 1
			current_phase = str(_copy_dict(transition_records[transition_index]).get("phase_id", ""))
		var phase_id := str(record.get("phase_id", ""))
		var authored_branch_id := str(record.get("branch_id", ""))
		var resolved_id := "%s:%s" % [phase_id, authored_branch_id]
		var trigger_kind := str(record.get("trigger_kind", ""))
		var cause_key := "%s|%s" % [trigger_kind, str(record.get("trigger_receipt_key", ""))]
		var cause := _copy_dict(causes.get(cause_key, {}))
		var authored_branch := _authored_branch(definition, phase_id, authored_branch_id)
		if terminal_seen or current_phase != phase_id or authored_branch.is_empty() or resolved_branch_ids.has(resolved_id) or used_causes.has(cause_key) or cause.is_empty() or str(cause.get("fingerprint", "")) != str(record.get("cause_fingerprint", "")) or str(record.get("branch_fingerprint", "")) != SequenceRuntimeScript.branch_content_fingerprint(authored_branch):
			errors.append("scenario branch resolution does not authenticate an authored causal edge")
			continue
		var envelope := _copy_dict(cause.get("envelope", {}))
		if trigger_kind == "command" and str(envelope.get("expected_phase", "")) != phase_id:
			errors.append("scenario branch command cause was issued in a different phase")
			continue
		var first_matching_branch := ""
		for candidate_value in _copy_array(SequenceSchemaScript.phase(definition, phase_id).get("branches", [])):
			var candidate := _copy_dict(candidate_value)
			if _branch_condition_matches_cause(_copy_dict(candidate.get("condition", {})), trigger_kind, envelope, state, resolved_outcomes, causes, definition, phase_id):
				first_matching_branch = str(candidate.get("id", ""))
				break
		if first_matching_branch != authored_branch_id:
			errors.append("scenario branch resolution condition or authored priority is not proven by its cause")
			continue
		if has_target:
			var target_phase := str(record.get("target_phase_id", ""))
			var source_receipt := resolved_id
			if str(authored_branch.get("next_phase", "")) != target_phase or transition_index + 1 >= transition_records.size():
				errors.append("scenario branch target does not prove the next transition")
				continue
			var next_transition := _copy_dict(transition_records[transition_index + 1])
			if str(next_transition.get("phase_id", "")) != target_phase or str(next_transition.get("source_receipt", "")) != source_receipt:
				errors.append("scenario branch target and transition journal are out of order")
				continue
			transition_index += 1
			current_phase = target_phase
			used_transition_sources[source_receipt] = true
		else:
			var outcome_id := str(record.get("terminal_outcome", ""))
			if str(authored_branch.get("outcome", "")) != outcome_id or _copy_dict(_copy_dict(SequenceSchemaScript.sequence(definition).get("aftermath", {})).get(outcome_id, {})).is_empty():
				errors.append("scenario branch terminal outcome is not authored")
				continue
			resolved_outcomes.append(outcome_id)
			terminal_seen = true
		validated.append(record)
		resolved_branch_ids.append(resolved_id)
		used_causes[cause_key] = true
	for index in range(1, transition_records.size()):
		var source_receipt := str(_copy_dict(transition_records[index]).get("source_receipt", ""))
		if source_receipt != "ordered_compat" and not used_transition_sources.has(source_receipt):
			errors.append("scenario transition journal contains an unjournaled branch source")
	if not records.is_empty() and validated.size() != records.size():
		errors.append("scenario branch resolution journal contains unauthenticated entries")
	if not current_phase.is_empty() and str(state.get("phase_id", "")) != current_phase:
		errors.append("scenario saved phase does not match the proven branch/transition chain")
	return {"records": validated, "resolved_branch_ids": resolved_branch_ids, "resolved_outcomes": resolved_outcomes, "errors": errors}


static func _authored_branch(definition: Dictionary, phase_id: String, branch_id: String) -> Dictionary:
	for branch_value in _copy_array(SequenceSchemaScript.phase(definition, phase_id).get("branches", [])):
		var branch := _copy_dict(branch_value)
		if str(branch.get("id", "")) == branch_id: return branch
	return {}


static func _branch_condition_matches_cause(condition: Dictionary, trigger_kind: String, envelope: Dictionary, state: Dictionary, proven_outcomes: Array, causes: Dictionary, definition: Dictionary, phase_id: String) -> bool:
	var handler := _authored_handler_for_cause(definition, trigger_kind, envelope, phase_id)
	var handler_id := str(handler.get("handler", ""))
	var inputs := _copy_dict(handler.get("inputs", {}))
	match str(condition.get("type", "")):
		"always": return true
		"command": return trigger_kind == "command" and str(envelope.get("command_id", "")) == str(condition.get("command_id", ""))
		"fact": return trigger_kind == "fact" and str(envelope.get("fact_type", "")) == str(condition.get("fact_type", ""))
		"local_equals":
			if handler_id == "set_local" and str(inputs.get("key", "")) == str(condition.get("key", "")):
				var projected_key := str(inputs.get("value_from_payload", ""))
				var value: Variant = _copy_dict(envelope.get("payload", {})).get(projected_key) if not projected_key.is_empty() else inputs.get("value")
				return value == condition.get("value")
			return _copy_dict(state.get("local_state", {})).get(str(condition.get("key", ""))) == condition.get("value")
		"local_min":
			var local_value: Variant = _copy_dict(state.get("local_state", {})).get(str(condition.get("key", "")))
			return typeof(local_value) == TYPE_INT and typeof(condition.get("value")) == TYPE_INT and int(local_value) >= int(condition.get("value"))
		"objective":
			if handler_id == "complete_objective_step" and str(inputs.get("objective_id", "")) == str(condition.get("objective_id", "")) and str(inputs.get("step_id", "")) == str(condition.get("step_id", "")): return true
			if trigger_kind == "command" and _command_completes_objective_step(definition, str(envelope.get("command_id", "")), str(condition.get("objective_id", "")), str(condition.get("step_id", ""))): return true
			return _copy_array(_copy_dict(_copy_dict(state.get("objective_progress", {})).get(str(condition.get("objective_id", "")), {})).get("completed_steps", [])).has(str(condition.get("step_id", "")))
		"outcome": return proven_outcomes.has(str(condition.get("outcome", ""))) or handler_id == "record_outcome" and str(inputs.get("outcome", "")) == str(condition.get("outcome", ""))
		"receipt": return _journal_receipt_condition_proven(condition, state, causes)
	return false


static func _causal_recorded_outcomes(definition: Dictionary, cause_validation: Dictionary) -> Array:
	var result: Array = []
	for record_key in ["command_records", "fact_records"]:
		for record_value in _copy_array(cause_validation.get(record_key, [])):
			var envelope := _copy_dict(_copy_dict(record_value).get("envelope", {}))
			var trigger_kind := "command" if record_key == "command_records" else "fact"
			var handler := _authored_handler_for_cause(definition, trigger_kind, envelope, str(envelope.get("expected_phase", "")))
			if str(handler.get("handler", "")) == "record_outcome": _append_unique_text(result, str(_copy_dict(handler.get("inputs", {})).get("outcome", "")))
	return result


static func _authored_handler_for_cause(definition: Dictionary, trigger_kind: String, envelope: Dictionary, phase_id: String) -> Dictionary:
	if trigger_kind == "fact":
		for subscription_value in _copy_array(SequenceSchemaScript.sequence(definition).get("fact_subscriptions", [])):
			var subscription := _copy_dict(subscription_value)
			if str(subscription.get("fact_type", "")) == str(envelope.get("fact_type", "")): return subscription
		return {}
	var command_id := str(envelope.get("command_id", ""))
	for operation_value in _copy_array(SequenceSchemaScript.phase(definition, phase_id).get("interaction_ops", [])):
		var operation := _copy_dict(operation_value)
		var interaction := _copy_dict(operation.get("interaction", {}))
		for action_value in _copy_array(interaction.get("available_actions", operation.get("available_actions", []))):
			var action := _copy_dict(action_value)
			if str(action.get("id", "")) == command_id: return action
	return {}


static func _command_completes_objective_step(definition: Dictionary, command_id: String, objective_id: String, step_id: String) -> bool:
	for objective_value in _copy_array(SequenceSchemaScript.sequence(definition).get("objectives", [])):
		var objective := _copy_dict(objective_value)
		if str(objective.get("id", "")) != objective_id: continue
		for step_value in _copy_array(objective.get("steps", [])):
			var step := _copy_dict(step_value)
			if str(step.get("id", "")) == step_id and str(step.get("kind", "")) == "command" and str(step.get("command_id", "")) == command_id: return true
	return false


static func _journal_receipt_condition_proven(condition: Dictionary, state: Dictionary, causes: Dictionary) -> bool:
	var receipt_kind := str(condition.get("receipt_kind", ""))
	var receipt_id := str(condition.get("receipt_id", ""))
	if receipt_kind in ["command", "fact"]: return causes.has("%s|%s" % [receipt_kind, receipt_id])
	var collection_key: String = str({"operation": "operation_receipt_records", "transition": "transition_receipt_records", "cleanup": "cleanup_receipt_records", "visit": "visit_receipt_records"}.get(receipt_kind, ""))
	var records := _copy_array(_copy_dict(state.get("semantic_state", {})).get(collection_key, [])) if receipt_kind == "operation" else _copy_array(state.get(collection_key, []))
	for record_value in records:
		var record := _copy_dict(record_value)
		if receipt_kind == "operation" and str(record.get("authored_receipt_id", "")) == receipt_id and str(record.get("family", "")) == str(condition.get("family", "")) and str(record.get("boundary_id", "")) == str(condition.get("boundary_id", "")): return true
		if receipt_kind == "transition" and (str(record.get("receipt_key", "")) == receipt_id or str(record.get("source_receipt", "")) == receipt_id): return true
		if receipt_kind == "cleanup" and (str(record.get("receipt_key", "")) == receipt_id or str(record.get("reason", "")) == receipt_id): return true
		if receipt_kind == "visit" and (str(record.get("receipt_key", "")) == receipt_id or str(record.get("visit_id", "")) == receipt_id): return true
	return false


static func _exact_string_values(value: Dictionary, fields: Array, allow_empty: Array = []) -> bool:
	for field_value in fields:
		var field := str(field_value)
		if typeof(value.get(field)) != TYPE_STRING or str(value.get(field, "")) != str(value.get(field, "")).strip_edges() or str(value.get(field, "")).is_empty() and not allow_empty.has(field): return false
	return true


static func _register_allowed_operations(allowed: Dictionary, family_override: String, operations: Array, boundary_id: String, cleanup_restore: bool, errors: Array) -> void:
	var boundary_ordinal := 0
	for proof_value in allowed.values():
		if str(_copy_dict(proof_value).get("boundary_id", "")) == boundary_id: boundary_ordinal += 1
	for operation_index in range(operations.size()):
		var operation_value: Variant = operations[operation_index]
		var operation := _copy_dict(operation_value)
		var family := family_override if not family_override.is_empty() else str(operation.get("family", ""))
		var authored_receipt_id := str(operation.get("receipt_id", ""))
		var receipt_key := OperationRegistryScript.structural_receipt_key(boundary_id, family, authored_receipt_id)
		if allowed.has(receipt_key):
			errors.append("authored reached operations collide on structural receipt")
			continue
		var boundary_kind := "phase" if boundary_id.contains(":phase:") else "aftermath" if boundary_id.contains(":aftermath:") else "cleanup" if boundary_id.contains(":cleanup:") else ""
		var marker := ":%s:" % boundary_kind
		allowed[receipt_key] = {"operation": operation, "family": family, "authored_receipt_id": authored_receipt_id, "boundary_id": boundary_id, "boundary_kind": boundary_kind, "boundary_ordinal": boundary_ordinal, "operation_index": operation_index, "source_ref": boundary_id.substr(boundary_id.find(marker) + marker.length()) if not boundary_kind.is_empty() else "", "journal_order": allowed.size(), "fingerprint": OperationRegistryScript.operation_fingerprint(operation), "cleanup_restore": cleanup_restore}
		boundary_ordinal += 1


static func _valid_phase_transition(definition: Dictionary, prior_phase: String, phase_id: String, source_receipt: String) -> bool:
	if SequenceSchemaScript.phase(definition, phase_id).is_empty(): return false
	if prior_phase.is_empty(): return phase_id == SequenceSchemaScript.initial_phase_id(definition) and source_receipt == "initial"
	if source_receipt == "ordered_compat":
		var ids := SequenceSchemaScript.phase_ids(definition)
		return ids.find(phase_id) == ids.find(prior_phase) + 1
	for branch_value in _copy_array(SequenceSchemaScript.phase(definition, prior_phase).get("branches", [])):
		var branch := _copy_dict(branch_value)
		if source_receipt == "%s:%s" % [prior_phase, str(branch.get("id", ""))] and str(branch.get("next_phase", "")) == phase_id: return true
	return false


static func _authored_cleanup_reasons(definition: Dictionary) -> Array:
	var result: Array = []
	var sequence := SequenceSchemaScript.sequence(definition)
	for subscription_value in _copy_array(sequence.get("fact_subscriptions", [])):
		var subscription := _copy_dict(subscription_value)
		if str(subscription.get("handler", "")) == "request_cleanup": _append_unique_text(result, str(_copy_dict(subscription.get("inputs", {})).get("reason", "")))
	for phase_value in _copy_array(_copy_dict(sequence.get("phase_graph", {})).get("phases", [])):
		for operation_value in _copy_array(_copy_dict(phase_value).get("interaction_ops", [])):
			var operation := _copy_dict(operation_value)
			var interaction := _copy_dict(operation.get("interaction", {}))
			for action_value in _copy_array(interaction.get("available_actions", operation.get("available_actions", []))):
				var action := _copy_dict(action_value)
				if str(action.get("handler", "")) == "request_cleanup": _append_unique_text(result, str(_copy_dict(action.get("inputs", {})).get("reason", "")))
	return result


static func _all_branches(definition: Dictionary) -> Array:
	var result: Array = []
	for phase_value in _copy_array(_copy_dict(SequenceSchemaScript.sequence(definition).get("phase_graph", {})).get("phases", [])):
		var phase := _copy_dict(phase_value)
		for branch_value in _copy_array(phase.get("branches", [])):
			var branch := _copy_dict(branch_value)
			branch["phase_id"] = str(phase.get("id", ""))
			result.append(branch)
	return result


static func _exact_string_fields(value: Dictionary, fields: Array) -> bool:
	for field_value in fields:
		var field := str(field_value)
		if typeof(value.get(field)) != TYPE_STRING or str(value.get(field, "")) != str(value.get(field, "")).strip_edges() or str(value.get(field, "")).is_empty(): return false
	return true


static func _valid_sha256(value: String) -> bool:
	if value.length() != 64 or value != value.to_lower(): return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102): return false
	return true


static func _record_keys(records: Array) -> Array:
	var result: Array = []
	for record_value in records: result.append(str(_copy_dict(record_value).get("receipt_key", "")))
	return result


static func _append_unique_text(values: Array, value: String) -> void:
	if value == value.strip_edges() and not value.is_empty() and not values.has(value): values.append(value)


static func sequence_record_visit(environment: Dictionary, definition: Dictionary, visit_id: String) -> Dictionary:
	var candidate := environment.duplicate(true)
	var state := ensure_sequence_state(candidate, definition)
	if state.is_empty(): return {"ok": false, "errors": ["No dynamic room sequence is active."]}
	return _commit_sequence_candidate(environment, candidate, definition, SequenceRuntimeScript.record_visit(state, definition, visit_id))


static func sequence_apply_reentry(environment: Dictionary, definition: Dictionary, visit_id: String) -> Dictionary:
	var candidate := environment.duplicate(true)
	var state := ensure_sequence_state(candidate, definition)
	if state.is_empty(): return {"ok": false, "errors": ["No dynamic room sequence is active."]}
	return _commit_sequence_candidate(environment, candidate, definition, SequenceRuntimeScript.apply_reentry(state, definition, visit_id, sequence_host_semantics(candidate)))


static func sequence_apply_expiry_boundary(environment: Dictionary, definition: Dictionary, boundary: String, amount: int = 1) -> Dictionary:
	var candidate := environment.duplicate(true)
	var state := ensure_sequence_state(candidate, definition)
	if state.is_empty(): return {"ok": false, "errors": ["No dynamic room sequence is active."]}
	return _commit_sequence_candidate(environment, candidate, definition, SequenceRuntimeScript.apply_expiry_boundary(state, definition, boundary, amount))


static func sequence_host_semantics(environment: Dictionary) -> Dictionary:
	var base_interactions := _copy_array(environment.get("scenario_base_interactions", []))
	var sealed_inventory := _copy_dict(environment.get("scenario_semantic_inventory", {}))
	if not bool(environment.get("scenario_semantic_ready", false)) or sealed_inventory.is_empty():
		return {"target_inventory": {}, "inventory_schema_version": 0, "inventory_digest": "", "inventory_errors": ["scenario semantic records are not finalized"], "base_interactions": [], "event_choices": {}}
	if typeof(environment.get("scenario_semantic_inventory_version")) != TYPE_INT or typeof(environment.get("scenario_semantic_digest")) != TYPE_STRING:
		return {"target_inventory": {}, "inventory_schema_version": 0, "inventory_digest": "", "inventory_errors": ["scenario semantic proof reference is missing or malformed"], "base_interactions": [], "event_choices": {}}
	if typeof(environment.get("scenario_semantic_action_digest")) != TYPE_STRING or not SequenceRuntimeScript._valid_sha256(str(environment.get("scenario_semantic_action_digest", ""))) or str(environment.get("scenario_semantic_action_digest", "")) != SequenceRuntimeScript.base_interaction_action_authority_digest(base_interactions):
		return {"target_inventory": {}, "inventory_schema_version": 0, "inventory_digest": "", "inventory_errors": ["scenario semantic action authority is missing or stale"], "base_interactions": [], "event_choices": {}}
	if int(environment.get("scenario_semantic_inventory_version", 0)) != int(sealed_inventory.get("schema_version", 0)) or str(environment.get("scenario_semantic_digest", "")) != str(sealed_inventory.get("digest", "")):
		return {"target_inventory": {}, "inventory_schema_version": 0, "inventory_digest": "", "inventory_errors": ["scenario semantic proof reference does not match the sealed inventory"], "base_interactions": [], "event_choices": {}}
	var binding_errors := EnvironmentSemanticInventoryScript.validate_instance_binding(sealed_inventory, environment)
	if not binding_errors.is_empty():
		return {"target_inventory": {}, "inventory_schema_version": 0, "inventory_digest": "", "inventory_errors": binding_errors, "base_interactions": [], "event_choices": {}}
	return {"target_inventory": EnvironmentSemanticInventoryScript.exact_collections(sealed_inventory), "inventory_schema_version": int(sealed_inventory.get("schema_version", 0)), "inventory_digest": str(sealed_inventory.get("digest", "")), "inventory_errors": [], "base_interactions": base_interactions, "event_choices": _copy_dict(environment.get("scenario_event_choices", {}))}


static func sequence_command(environment: Dictionary, definition: Dictionary, command: Dictionary, context: Dictionary = {}) -> Dictionary:
	definition = sequence_definition_for_environment(environment, definition)
	var candidate := environment.duplicate(true)
	var state := ensure_sequence_state(candidate, definition)
	if state.is_empty():
		return {"ok": false, "errors": ["No dynamic room sequence is active."]}
	var dispatched := ScenarioExtensionDispatchScript.prepare_command(definition, command, context)
	if not bool(dispatched.get("ok", false)):
		return {"ok": false, "errors": _copy_array(dispatched.get("errors", [])), "state": state}
	var result := SequenceRuntimeScript.apply_command(state, definition, _copy_dict(dispatched.get("command", command)), _copy_dict(dispatched.get("context", context)))
	return _commit_sequence_candidate(environment, candidate, definition, result)


static func enqueue_sequence_fact(environment: Dictionary, definition: Dictionary, fact: Dictionary) -> Dictionary:
	definition = sequence_definition_for_environment(environment, definition)
	var candidate := environment.duplicate(true)
	var state := ensure_sequence_state(candidate, definition)
	if state.is_empty():
		return {"ok": false, "errors": ["No dynamic room sequence is active."]}
	var result := SequenceRuntimeScript.enqueue_fact(state, definition, fact)
	return _commit_sequence_candidate(environment, candidate, definition, result)


static func flush_sequence_facts(environment: Dictionary, definition: Dictionary, boundary_serial: int) -> Dictionary:
	definition = sequence_definition_for_environment(environment, definition)
	var candidate := environment.duplicate(true)
	var state := ensure_sequence_state(candidate, definition)
	if state.is_empty():
		return {"ok": false, "errors": ["No dynamic room sequence is active."]}
	var result := SequenceRuntimeScript.flush_facts(state, definition, boundary_serial)
	return _commit_sequence_candidate(environment, candidate, definition, result)


static func sequence_projection(environment: Dictionary, definition: Dictionary = {}) -> Dictionary:
	if _sequence_is_suppressed(environment, definition):
		_clear_environment_sequence(environment)
		return {}
	definition = sequence_definition_for_environment(environment, definition)
	if not SequenceSchemaScript.is_sequence(definition): return {}
	var host_semantics := sequence_host_semantics(environment)
	if not _copy_array(host_semantics.get("inventory_errors", [])).is_empty(): return {}
	var state := SequenceRuntimeScript.normalize_state(environment.get("scenario_sequence_state", {}), definition, host_semantics)
	return SequenceRuntimeScript.public_projection(state, definition) if not state.is_empty() else {}


static func sequence_reentry(environment: Dictionary, definition: Dictionary, visit_id: String) -> Dictionary:
	definition = sequence_definition_for_environment(environment, definition)
	var candidate := environment.duplicate(true)
	var state := ensure_sequence_state(candidate, definition)
	if state.is_empty():
		return {"ok": false, "inactive": true, "errors": []}
	var result := SequenceRuntimeScript.apply_reentry(state, definition, visit_id, sequence_host_semantics(candidate))
	return _commit_sequence_candidate(environment, candidate, definition, result)


static func sequence_expiry(environment: Dictionary, definition: Dictionary, boundary: String, boundary_serial: int) -> Dictionary:
	definition = sequence_definition_for_environment(environment, definition)
	var candidate := environment.duplicate(true)
	var state := ensure_sequence_state(candidate, definition)
	if state.is_empty():
		return {"ok": false, "inactive": true, "errors": []}
	var result := SequenceRuntimeScript.apply_expiry(state, definition, boundary, boundary_serial)
	return _commit_sequence_candidate(environment, candidate, definition, result)


static func drain_sequence_transitions(environment: Dictionary, definition: Dictionary, reduced_motion: bool = false) -> Dictionary:
	definition = sequence_definition_for_environment(environment, definition)
	var candidate := environment.duplicate(true)
	var state := ensure_sequence_state(candidate, definition)
	if state.is_empty():
		return {"ok": false, "inactive": true, "transitions": [], "errors": []}
	var result := SequenceRuntimeScript.drain_transitions(state, definition, reduced_motion)
	return _commit_sequence_candidate(environment, candidate, definition, result)


static func drain_sequence_event_requests(environment: Dictionary, definition: Dictionary) -> Dictionary:
	definition = sequence_definition_for_environment(environment, definition)
	var candidate := environment.duplicate(true)
	var state := ensure_sequence_state(candidate, definition)
	if state.is_empty():
		return {"ok": false, "inactive": true, "requests": [], "errors": []}
	var result := SequenceRuntimeScript.drain_event_requests(state, definition)
	return _commit_sequence_candidate(environment, candidate, definition, result)


static func refresh_sequence_snapshots(environment: Dictionary, definition: Dictionary = {}) -> Dictionary:
	if _sequence_is_suppressed(environment, definition):
		_clear_environment_sequence(environment)
		return {}
	definition = sequence_definition_for_environment(environment, definition)
	return _refresh_sequence_snapshots(environment, definition)


static func suppress_sequence_definition(definition: Dictionary) -> Dictionary:
	var result := _without_sequence_overlay(definition)
	result[SEQUENCE_SUPPRESSION_KEY] = true
	return result


static func _sequence_is_suppressed(environment: Dictionary, preferred: Dictionary = {}) -> bool:
	return bool(_copy_dict(environment.get("scenario_state", {})).get(SEQUENCE_SUPPRESSION_KEY, false)) or bool(preferred.get(SEQUENCE_SUPPRESSION_KEY, false))


static func _clear_environment_sequence(environment: Dictionary) -> void:
	var baseline_arrays := {
		"scenario_sequence_base_game_ids": "game_ids",
		"scenario_sequence_base_service_ids": "service_ids",
		"scenario_sequence_base_travel_hooks": "travel_hooks",
	}
	for baseline_key_value in baseline_arrays.keys():
		var baseline_key := str(baseline_key_value)
		if environment.has(baseline_key):
			environment[str(baseline_arrays.get(baseline_key_value, ""))] = _copy_array(environment.get(baseline_key, []))
	if environment.has("scenario_sequence_base_game_modifiers"):
		environment["scenario_game_modifiers"] = _copy_dict(environment.get("scenario_sequence_base_game_modifiers", {}))
	for key in [
		"scenario_sequence_state", "scenario_sequence_projection", "scenario_render_snapshot",
		"scenario_sequence_migration", "scenario_sequence_definition",
		"scenario_sequence_base_game_ids", "scenario_sequence_base_service_ids",
		"scenario_sequence_base_travel_hooks", "scenario_sequence_base_game_modifiers",
		"scenario_layout_base_records", "scenario_layout_context", "scenario_layout_authority",
		"scenario_layout_audit", "scenario_layout_authority_digest",
	]:
		environment.erase(key)


static func _refresh_sequence_snapshots(environment: Dictionary, definition: Dictionary) -> Dictionary:
	var state := SequenceRuntimeScript.normalize_state(environment.get("scenario_sequence_state", {}), definition)
	if state.is_empty():
		return {"ok": false, "errors": ["Scenario snapshot refresh requires normalized state."]}
	var candidate := environment.duplicate(true)
	var committed := _commit_sequence_candidate(environment, candidate, definition, {"ok": true, "state": state, "errors": []})
	if not bool(committed.get("ok", false)):
		return {"ok": false, "errors": _copy_array(committed.get("errors", []))}
	return _copy_dict(environment.get("scenario_render_snapshot", {}))


static func _commit_sequence_candidate(environment: Dictionary, candidate_value: Dictionary, definition: Dictionary, result_value: Dictionary) -> Dictionary:
	var result := result_value.duplicate(true)
	if not bool(result.get("ok", false)):
		var rejected_state := _copy_dict(result.get("state", {}))
		if str(rejected_state.get("status", "")) == SequenceRuntimeScript.STATUS_CLEANED and str(_copy_dict(environment.get("scenario_sequence_state", {})).get("status", "")) != SequenceRuntimeScript.STATUS_CLEANED:
			var rejected_candidate := candidate_value.duplicate(true)
			rejected_candidate["scenario_sequence_state"] = rejected_state
			environment.clear()
			environment.merge(rejected_candidate, true)
		return result
	var candidate := candidate_value.duplicate(true)
	var next := _copy_dict(result.get("state", {}))
	if next.is_empty():
		return _sequence_candidate_failure(environment, result, ["Scenario operation produced no authoritative next state."])
	candidate["scenario_sequence_state"] = next
	var projection := SequenceRuntimeScript.public_projection(next, definition)
	if projection.is_empty():
		return _sequence_candidate_failure(environment, result, ["Scenario operation produced no public projection."])
	if not bool(candidate.get("scenario_semantic_ready", false)):
		return _sequence_candidate_failure(environment, result, ["Scenario post-operation layout requires finalized semantic records."])
	if typeof(candidate.get("scenario_layout_base_records")) != TYPE_ARRAY or typeof(candidate.get("scenario_layout_context", {})) != TYPE_DICTIONARY:
		return _sequence_candidate_failure(environment, result, ["Scenario post-operation layout authority inputs are missing."])
	var layout_environment := candidate.duplicate(true)
	var layout_context := _copy_dict(candidate.get("scenario_layout_context", {}))
	if not layout_context.is_empty():
		layout_environment["_scenario_layout_context"] = layout_context
	var layout_result := ScenarioLayoutResolverScript.resolve(_copy_array(candidate.get("scenario_layout_base_records", [])), projection, layout_environment)
	if not bool(layout_result.get("ok", false)):
		return _sequence_candidate_failure(environment, result, _copy_array(layout_result.get("errors", ["Scenario post-operation layout validation failed closed."])))
	var sealed_projection := _copy_dict(layout_result.get("projection", {}))
	var renderer_snapshot := ScenarioLayoutResolverScript.sealed_renderer_snapshot(layout_result)
	if not bool(renderer_snapshot.get("ok", false)):
		return _sequence_candidate_failure(environment, result, _copy_array(renderer_snapshot.get("errors", ["Scenario post-operation renderer validation failed closed."])))
	var authority_digest := str(layout_result.get("layout_authority_digest", ""))
	if authority_digest.is_empty() or str(renderer_snapshot.get("layout_authority_digest", "")) != authority_digest:
		return _sequence_candidate_failure(environment, result, ["Scenario post-operation renderer authority diverged from sealed layout geometry."])
	candidate["scenario_sequence_projection"] = sealed_projection
	candidate["scenario_layout_authority"] = _copy_dict(layout_result.get("layout_authority", {}))
	candidate["scenario_layout_audit"] = _copy_dict(layout_result.get("layout_audit", {}))
	candidate["scenario_layout_authority_digest"] = authority_digest
	candidate["scenario_render_snapshot"] = renderer_snapshot
	_materialize_sequence_services_games_routes(candidate, sealed_projection)
	environment.clear()
	environment.merge(candidate, true)
	result["state"] = next.duplicate(true)
	result["projection"] = sealed_projection.duplicate(true)
	result["layout_authority"] = _copy_dict(layout_result.get("layout_authority", {}))
	result["layout_authority_digest"] = authority_digest
	result["layout_audit"] = _copy_dict(layout_result.get("layout_audit", {}))
	result["renderer_snapshot"] = renderer_snapshot.duplicate(true)
	result["warnings"] = _copy_array(layout_result.get("warnings", []))
	return result


static func _sequence_candidate_failure(environment: Dictionary, result_value: Dictionary, errors_value: Array) -> Dictionary:
	var result := result_value.duplicate(true)
	var errors: Array = []
	for value in errors_value:
		var message := str(value).strip_edges()
		if not message.is_empty() and not errors.has(message):
			errors.append(message)
	if errors.is_empty():
		errors.append("Scenario post-operation candidate failed closed.")
	result["ok"] = false
	result["errors"] = errors
	result["state"] = _copy_dict(environment.get("scenario_sequence_state", {}))
	for collection_key in ["processed", "requests", "transitions"]:
		if result.has(collection_key):
			result[collection_key] = []
	if result.has("cost"):
		result["cost"] = 0
	if result.has("applied"):
		result["applied"] = false
	return result


static func _capture_sequence_baseline(environment: Dictionary) -> void:
	if not environment.has("scenario_sequence_base_game_ids"):
		environment["scenario_sequence_base_game_ids"] = _string_array(environment.get("game_ids", []))
	if not environment.has("scenario_sequence_base_service_ids"):
		environment["scenario_sequence_base_service_ids"] = _string_array(environment.get("service_ids", []))
	if not environment.has("scenario_sequence_base_travel_hooks"):
		environment["scenario_sequence_base_travel_hooks"] = _string_array(environment.get("travel_hooks", []))
	if not environment.has("scenario_sequence_base_game_modifiers"):
		environment["scenario_sequence_base_game_modifiers"] = _copy_dict(environment.get("scenario_game_modifiers", {}))


static func _materialize_sequence_services_games_routes(environment: Dictionary, projection: Dictionary) -> void:
	_capture_sequence_baseline(environment)
	var semantic := _copy_dict(projection.get("semantic_state", {}))
	var services := _string_array(environment.get("scenario_sequence_base_service_ids", []))
	for value in _copy_dict(semantic.get("services", {})).values():
		var record := _copy_dict(value)
		var service_id := str(record.get("id", record.get("stable_object_id", ""))).strip_edges()
		if service_id.is_empty(): continue
		if bool(record.get("enabled", true)):
			if not services.has(service_id): services.append(service_id)
		else:
			services.erase(service_id)
	environment["service_ids"] = services
	var games := _string_array(environment.get("scenario_sequence_base_game_ids", []))
	var modifiers := _copy_dict(environment.get("scenario_sequence_base_game_modifiers", {}))
	for value in _copy_dict(semantic.get("games", {})).values():
		var record := _copy_dict(value)
		var game_id := str(record.get("id", record.get("stable_object_id", ""))).strip_edges()
		if game_id.is_empty(): continue
		if bool(record.get("enabled", true)):
			if not games.has(game_id): games.append(game_id)
		else:
			games.erase(game_id)
		var modifier := _copy_dict(record.get("modifier", {}))
		if not modifier.is_empty(): modifiers[game_id] = modifier
	environment["game_ids"] = games
	environment["scenario_game_modifiers"] = modifiers
	var routes := _string_array(environment.get("scenario_sequence_base_travel_hooks", []))
	for value in _copy_dict(semantic.get("routes", {})).values():
		var record := _copy_dict(value)
		var route_id := str(record.get("stable_object_id", "")).strip_edges()
		var source_id := str(record.get("source_id", route_id)).strip_edges()
		if not route_id.is_empty(): routes.erase(route_id)
		if bool(record.get("enabled", true)) and not source_id.is_empty() and not routes.has(source_id): routes.append(source_id)
	environment["travel_hooks"] = routes


static func validate_sequence_definition(definition: Dictionary, references: Dictionary = {}) -> Array:
	var errors := SequenceSchemaScript.validate_definition(definition, OperationRegistryScript)
	if not SequenceSchemaScript.is_sequence(definition):
		return errors
	var scenario_id := str(definition.get("id", ""))
	if definition.has("sequence_package_id"):
		errors.append_array(ScenarioExtensionDispatchScript.validate_package_extensions(
			str(definition.get("sequence_package_id", "")),
			str(definition.get("sequence_handler_pack", "")),
			str(definition.get("sequence_renderer_id", ""))
		))
	var archetype_id := str(definition.get("archetype_id", ""))
	if not _copy_dict(references.get("archetype_ids", {})).has(archetype_id):
		errors.append("scenario %s sequence references unknown archetype %s." % [scenario_id, archetype_id])
	var authoring := _copy_dict(definition.get("sequence_authoring", {}))
	if str(authoring.get("arrival_summary", "")).strip_edges().is_empty() or _string_array(authoring.get("player_verbs", [])).is_empty() or _string_array(authoring.get("world_connections", [])).is_empty():
		errors.append("scenario %s sequence authoring requires arrival_summary, player_verbs, and world_connections." % scenario_id)
	if _string_array(authoring.get("capture_ids", [])).is_empty() or _copy_dict(authoring.get("seed_evidence", {})).is_empty():
		errors.append("scenario %s sequence authoring requires capture_ids and seed_evidence." % scenario_id)
	_validate_sequence_references(scenario_id, authoring, references, errors)
	var archetype := _copy_dict(references.get("archetype", {}))
	for operation_value in _sequence_operations(definition):
		var operation := _copy_dict(operation_value)
		var owner := str(operation.get("owner_namespace", ""))
		var identity := OperationRegistryScript.identity(owner, str(operation.get("stable_object_id", "")))
		if owner != "scenario" and not _string_array(_copy_dict(authoring.get("references", {})).get("objects", [])).has(identity):
			errors.append("scenario %s sequence operation %s mutates unreferenced host identity %s." % [scenario_id, str(operation.get("receipt_id", "")), identity])
		for anchor_key in ["anchor_id", "zone_id"]:
			var anchor := str(operation.get(anchor_key, "")).strip_edges()
			if anchor.is_empty():
				var payload := _copy_dict(operation.get("object", operation.get("actor", {})))
				anchor = str(payload.get(anchor_key, "")).strip_edges()
			if not anchor.is_empty() and not _sequence_anchor_exists(archetype, anchor_key, anchor):
				errors.append("scenario %s sequence references unknown %s %s." % [scenario_id, anchor_key, anchor])
		if str(operation.get("family", "")) == "actor_ops" and str(operation.get("op", "")) == "spawn":
			var actor_id := str(_copy_dict(operation.get("actor", {})).get("actor_id", ""))
			if not _copy_dict(references.get("actor_ids", {})).has(actor_id):
				errors.append("scenario %s sequence references unknown actor %s." % [scenario_id, actor_id])
	if errors.is_empty():
		var layout_environment := {
			"id": "validation_%s" % scenario_id,
			"archetype_id": archetype_id,
			"world_node_id": "validation_%s" % scenario_id,
			"layout": _copy_dict(archetype.get("layout", {})),
			"travel_hooks": _copy_array(archetype.get("travel_hooks", [])),
			"next_archetypes": _copy_array(archetype.get("next_archetypes", [])),
		}
		var initial := SequenceRuntimeScript.initial_state(definition, str(layout_environment.get("world_node_id", "")), "content_validation")
		var prepared := ScenarioExtensionDispatchScript.prepare_render(definition, layout_environment, SequenceRuntimeScript.public_projection(initial, definition))
		if not bool(prepared.get("ok", false)):
			for layout_error_value in _copy_array(prepared.get("errors", [])):
				errors.append("scenario %s layout: %s" % [scenario_id, str(layout_error_value)])
	return errors


static func sequence_catalog_audit(definitions: Array, expected_count: int, masked_visual_explanations: Dictionary = {}) -> Dictionary:
	return SequenceSchemaScript.catalog_uniqueness_report(definitions, expected_count, OperationRegistryScript, masked_visual_explanations)


static func _without_sequence_overlay(definition: Dictionary) -> Dictionary:
	var result := definition.duplicate(true)
	for key in ["sequence", "sequence_package_id", "sequence_handler_pack", "sequence_renderer_id", "sequence_authoring", VALIDATED_SEQUENCE_MARKER]:
		result.erase(key)
	return result


static func _validate_sequence_references(scenario_id: String, authoring: Dictionary, references: Dictionary, errors: Array) -> void:
	var authored_refs := _copy_dict(authoring.get("references", {}))
	var known := {
		"events": "event_ids", "games": "game_ids", "services": "service_ids",
		"items": "item_ids", "actors": "actor_ids",
	}
	for key_value in authored_refs.keys():
		var key := str(key_value)
		if key == "objects":
			for identity_value in _string_array(authored_refs.get(key, [])):
				var identity := str(identity_value)
				var parts := identity.split("::", false)
				if parts.size() != 2 or not OperationRegistryScript.OWNER_NAMESPACES.has(str(parts[0])):
					errors.append("scenario %s sequence references invalid object identity %s." % [scenario_id, identity])
			continue
		if not known.has(key):
			errors.append("scenario %s sequence authoring references unknown registry %s." % [scenario_id, key])
			continue
		var valid := _copy_dict(references.get(str(known.get(key, "")), {}))
		for id_value in _string_array(authored_refs.get(key, [])):
			if not valid.has(str(id_value)):
				errors.append("scenario %s sequence references unknown %s id %s." % [scenario_id, key, str(id_value)])


static func _sequence_operations(definition: Dictionary) -> Array:
	var result: Array = []
	var authored := SequenceSchemaScript.sequence(definition)
	for phase_value in _copy_array(_copy_dict(authored.get("phase_graph", {})).get("phases", [])):
		var phase := _copy_dict(phase_value)
		for family in ["scene_ops", "interaction_ops", "actor_ops", "transition_ops"]:
			result.append_array(_copy_array(phase.get(family, [])))
	result.append_array(_copy_array(_copy_dict(authored.get("cleanup", {})).get("operations", [])))
	for aftermath_value in _copy_dict(authored.get("aftermath", {})).values():
		var aftermath := _copy_dict(aftermath_value)
		for family in ["scene_ops", "interaction_ops", "actor_ops", "service_ops", "game_ops", "route_ops"]:
			result.append_array(_copy_array(aftermath.get(family, [])))
	return result


static func _sequence_anchor_exists(archetype: Dictionary, anchor_kind: String, anchor: String) -> bool:
	if anchor_kind == "zone_id":
		return anchor in ["left", "right", "center", "foreground", "background", "exit_lane", "service_lane"]
	var parts := anchor.split(":", false)
	if parts.size() != 3 or str(parts[0]) != "layout" or not str(parts[2]).is_valid_int():
		return false
	var field := {
		"game": "game_spots", "event": "event_spots", "item": "item_spots",
		"service": "service_spots", "lender": "lender_spots", "travel": "travel_spots",
		"shopkeeper": "shopkeeper_spots", "game_hook": "game_hook_spots",
	}.get(str(parts[1]), "")
	if str(field).is_empty():
		return false
	return int(parts[2]) >= 0 and int(parts[2]) < _copy_array(_copy_dict(archetype.get("layout", {})).get(str(field), [])).size()


static func _sequence_state_can_bind_initial_node(state: Dictionary, environment: Dictionary, definition: Dictionary = {}, host_semantics: Dictionary = {}) -> bool:
	var original := str(state.get("node_id", "")).strip_edges()
	var archetype_id := str(environment.get("archetype_id", "")).strip_edges()
	if original.is_empty() or original != archetype_id or not SequenceSchemaScript.is_sequence(definition): return false
	var expected := SequenceRuntimeScript.initial_state(definition, original, str(state.get("seed_token", "")), host_semantics)
	return not expected.is_empty() and SequenceRuntimeScript.content_fingerprint(state) == SequenceRuntimeScript.content_fingerprint(expected)


static func advance_environment(environment: Dictionary, amount: int) -> bool:
	if amount <= 0:
		return false
	var state := normalize_state(environment.get("scenario_state", {}))
	if state.is_empty():
		return false
	var phases := _copy_array(state.get("phases", []))
	if phases.is_empty():
		return false
	var changed := false
	var applies_here := _state_targets_layer(state, environment)
	var remaining := amount
	while remaining > 0:
		var phase_index := mini(maxi(0, int(state.get("phase_index", 0))), phases.size() - 1)
		var phase: Dictionary = phases[phase_index] if typeof(phases[phase_index]) == TYPE_DICTIONARY else {}
		var threshold := maxi(0, int(phase.get("advance_after_actions", 0)))
		if threshold <= 0 or phase_index >= phases.size() - 1:
			state["phase_action_counter"] = maxi(0, int(state.get("phase_action_counter", 0))) + remaining
			remaining = 0
			continue
		var counter := maxi(0, int(state.get("phase_action_counter", 0)))
		var consumed := mini(remaining, maxi(1, threshold - counter))
		counter += consumed
		remaining -= consumed
		if counter < threshold:
			state["phase_action_counter"] = counter
			continue
		phase_index += 1
		state["phase_index"] = phase_index
		state["phase_action_counter"] = 0
		var next_phase: Dictionary = phases[phase_index] if typeof(phases[phase_index]) == TYPE_DICTIONARY else {}
		if applies_here:
			_apply_mutations(environment, _copy_dict(next_phase.get("mutations", {})), false)
			environment["scenario_applied_phase_index"] = phase_index
			_apply_exclusive_opportunity(environment)
		changed = true
	environment["scenario_state"] = state
	environment["scenario_id"] = str(state.get("id", ""))
	environment["scenario_phase_index"] = int(state.get("phase_index", 0))
	environment["scenario_phase_action_counter"] = int(state.get("phase_action_counter", 0))
	return changed


# Synchronizes a stored layer with the authoritative node scenario cursor.
static func reconcile_environment(environment: Dictionary, state_value: Variant) -> void:
	var state := normalize_state(state_value)
	if state.is_empty():
		return
	environment["scenario_state"] = state
	environment["scenario_id"] = str(state.get("id", ""))
	environment["scenario_phase_index"] = int(state.get("phase_index", 0))
	environment["scenario_phase_action_counter"] = int(state.get("phase_action_counter", 0))
	if not _state_targets_layer(state, environment):
		return
	var phases := _copy_array(state.get("phases", []))
	var applied_index := int(environment.get("scenario_applied_phase_index", -1))
	var target_index := mini(maxi(0, int(state.get("phase_index", 0))), phases.size() - 1) if not phases.is_empty() else -1
	for index in range(applied_index + 1, target_index + 1):
		if index >= 0 and index < phases.size() and typeof(phases[index]) == TYPE_DICTIONARY:
			_apply_mutations(environment, _copy_dict((phases[index] as Dictionary).get("mutations", {})), false)
	environment["scenario_applied_phase_index"] = target_index
	_apply_exclusive_opportunity(environment)


static func public_snapshot(state_value: Variant) -> Dictionary:
	var state := normalize_state(state_value)
	if state.is_empty():
		return {}
	return {
		"id": str(state.get("id", "")),
		"archetype_id": str(state.get("archetype_id", "")),
		"layer_id": str(state.get("layer_id", "")),
		"display_name": str(state.get("display_name", "")),
		"phase_index": int(state.get("phase_index", 0)),
		"phase_action_counter": int(state.get("phase_action_counter", 0)),
	}


static func _state_targets_layer(state: Dictionary, target: Dictionary) -> bool:
	var wanted := str(state.get("layer_id", "")).strip_edges()
	if wanted.is_empty():
		return true
	return str(target.get("current_layer_id", "")).strip_edges() == wanted


static func _apply_mutations(target: Dictionary, mutations: Dictionary, generation: bool) -> void:
	if mutations.is_empty():
		return
	if mutations.has("patron_set"):
		target["scenario_patron_ids"] = _string_array(mutations.get("patron_set", []))
	if mutations.has("staff_set"):
		target["scenario_staff_ids"] = _string_array(mutations.get("staff_set", []))
	_apply_id_delta(target, "event_pool" if generation else "event_ids", mutations.get("event_pool_add", []), mutations.get("event_pool_remove", []))
	_apply_id_delta(target, "service_pool" if generation else "service_ids", mutations.get("service_add", []), mutations.get("service_remove", []))
	_apply_item_offer_delta(target, "scenario_item_offers" if generation else "item_offers", mutations.get("item_offer_add", []), mutations.get("item_offer_remove", []))
	if mutations.has("economic_profile_overrides"):
		target["economic_profile"] = _deep_merge(_copy_dict(target.get("economic_profile", {})), _copy_dict(mutations.get("economic_profile_overrides", {})))
	if mutations.has("game_modifier_hooks"):
		target["scenario_game_modifiers"] = _deep_merge(_copy_dict(target.get("scenario_game_modifiers", {})), _copy_dict(mutations.get("game_modifier_hooks", {})))
	if mutations.has("music_profile_override"):
		target["music_profile"] = _deep_merge(_copy_dict(target.get("music_profile", {})), _copy_dict(mutations.get("music_profile_override", {})))
	if mutations.has("presentation"):
		var presentation := _deep_merge(_copy_dict(target.get("scenario_presentation", {})), _copy_dict(mutations.get("presentation", {})))
		target["scenario_presentation"] = presentation
		target["visual_context"] = _deep_merge(_copy_dict(target.get("visual_context", {})), presentation)
	if mutations.has("exclusive_opportunity"):
		target["scenario_exclusive_opportunity"] = _copy_dict(mutations.get("exclusive_opportunity", {}))
	if mutations.has("security_overrides"):
		target["security_profile"] = _deep_merge(_copy_dict(target.get("security_profile", {})), _copy_dict(mutations.get("security_overrides", {})))
	if mutations.has("hook_flags"):
		target["scenario_hook_flags"] = _deep_merge(_copy_dict(target.get("scenario_hook_flags", {})), _copy_dict(mutations.get("hook_flags", {})))
	if mutations.has("travel_lock_actions"):
		var lock_actions := maxi(0, int(mutations.get("travel_lock_actions", 0)))
		target["travel_locked_actions"] = lock_actions
		if not generation:
			target["travel_lock_remaining"] = lock_actions


static func _apply_exclusive_opportunity(environment: Dictionary) -> void:
	var opportunity := _copy_dict(environment.get("scenario_exclusive_opportunity", {}))
	var event_id := str(opportunity.get("event_id", "")).strip_edges()
	if not event_id.is_empty():
		_apply_id_delta(environment, "event_ids", [event_id], [])
	var game_id := str(opportunity.get("game_id", "")).strip_edges()
	if not game_id.is_empty():
		_apply_id_delta(environment, "game_ids", [game_id], [])


static func _apply_id_delta(target: Dictionary, key: String, additions_value: Variant, removals_value: Variant) -> void:
	var values := _string_array(target.get(key, []))
	for remove_id in _string_array(removals_value):
		while values.has(remove_id):
			values.erase(remove_id)
	for add_id in _string_array(additions_value):
		if not values.has(add_id):
			values.append(add_id)
	target[key] = values


static func _apply_item_offer_delta(target: Dictionary, key: String, additions_value: Variant, removals_value: Variant) -> void:
	var offers := _copy_array(target.get(key, []))
	var remove_ids := _string_array(removals_value)
	for index in range(offers.size() - 1, -1, -1):
		if typeof(offers[index]) == TYPE_DICTIONARY and remove_ids.has(str((offers[index] as Dictionary).get("id", ""))):
			offers.remove_at(index)
	for offer_value in _copy_array(additions_value):
		if typeof(offer_value) != TYPE_DICTIONARY:
			continue
		var offer := (offer_value as Dictionary).duplicate(true)
		var item_id := str(offer.get("id", "")).strip_edges()
		if item_id.is_empty():
			continue
		for index in range(offers.size() - 1, -1, -1):
			if typeof(offers[index]) == TYPE_DICTIONARY and str((offers[index] as Dictionary).get("id", "")) == item_id:
				offers.remove_at(index)
		offers.append(offer)
	target[key] = offers


static func _deep_merge(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key_value in overlay.keys():
		var value: Variant = overlay.get(key_value)
		if typeof(value) == TYPE_DICTIONARY and typeof(result.get(key_value)) == TYPE_DICTIONARY:
			result[key_value] = _deep_merge(result.get(key_value, {}) as Dictionary, value as Dictionary)
		elif typeof(value) == TYPE_DICTIONARY:
			result[key_value] = (value as Dictionary).duplicate(true)
		elif typeof(value) == TYPE_ARRAY:
			result[key_value] = (value as Array).duplicate(true)
		else:
			result[key_value] = value
	return result


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value as Array:
		var entry := str(entry_value).strip_edges()
		if not entry.is_empty() and not result.has(entry):
			result.append(entry)
	return result


static func _copy_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _copy_dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
