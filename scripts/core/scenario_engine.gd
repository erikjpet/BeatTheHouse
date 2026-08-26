class_name ScenarioEngine
extends RefCounted

const SequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const SequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const SequenceCatalogScript := preload("res://scripts/core/scenario_sequence_catalog.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const ScenarioExtensionDispatchScript := preload("res://scripts/core/scenario_extension_dispatch.gd")
const VALIDATED_SEQUENCE_MARKER := "__scenario_sequence_runtime_validated"

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
const ALLOWED_EXCLUSIVE_KEYS := ["event_id", "offer_id", "game_id"]
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
	definition = sequence_definition_for_environment(environment, definition)
	if not SequenceSchemaScript.is_sequence(definition):
		return {}
	var node_id := str(environment.get("world_node_id", environment.get("archetype_id", environment.get("id", "")))).strip_edges()
	var state := SequenceRuntimeScript.normalize_state(environment.get("scenario_sequence_state", {}), definition)
	if state.is_empty():
		_capture_sequence_baseline(environment)
		state = SequenceRuntimeScript.initial_state(definition, node_id, seed_token)
	elif str(state.get("node_id", "")) != node_id and _sequence_state_can_bind_initial_node(state, environment):
		state["node_id"] = node_id
	environment["scenario_sequence_state"] = state
	_refresh_sequence_snapshots(environment, definition)
	return state.duplicate(true)


static func sequence_command(environment: Dictionary, definition: Dictionary, command: Dictionary, context: Dictionary = {}) -> Dictionary:
	definition = sequence_definition_for_environment(environment, definition)
	var state := ensure_sequence_state(environment, definition)
	if state.is_empty():
		return {"ok": false, "errors": ["No dynamic room sequence is active."]}
	var dispatched := ScenarioExtensionDispatchScript.prepare_command(definition, command, context)
	if not bool(dispatched.get("ok", false)):
		return {"ok": false, "errors": _copy_array(dispatched.get("errors", [])), "state": state}
	var result := SequenceRuntimeScript.apply_command(state, definition, _copy_dict(dispatched.get("command", command)), _copy_dict(dispatched.get("context", context)))
	var next := _copy_dict(result.get("state", state))
	environment["scenario_sequence_state"] = next
	_refresh_sequence_snapshots(environment, definition)
	result["state"] = next.duplicate(true)
	return result


static func enqueue_sequence_fact(environment: Dictionary, definition: Dictionary, fact: Dictionary) -> Dictionary:
	definition = sequence_definition_for_environment(environment, definition)
	var state := ensure_sequence_state(environment, definition)
	if state.is_empty():
		return {"ok": false, "errors": ["No dynamic room sequence is active."]}
	var result := SequenceRuntimeScript.enqueue_fact(state, definition, fact)
	var next := _copy_dict(result.get("state", state))
	environment["scenario_sequence_state"] = next
	_refresh_sequence_snapshots(environment, definition)
	result["state"] = next.duplicate(true)
	return result


static func flush_sequence_facts(environment: Dictionary, definition: Dictionary, boundary_serial: int) -> Dictionary:
	definition = sequence_definition_for_environment(environment, definition)
	var state := ensure_sequence_state(environment, definition)
	if state.is_empty():
		return {"ok": false, "errors": ["No dynamic room sequence is active."]}
	var result := SequenceRuntimeScript.flush_facts(state, definition, boundary_serial)
	var next := _copy_dict(result.get("state", state))
	environment["scenario_sequence_state"] = next
	_refresh_sequence_snapshots(environment, definition)
	result["state"] = next.duplicate(true)
	return result


static func sequence_projection(environment: Dictionary, definition: Dictionary = {}) -> Dictionary:
	definition = sequence_definition_for_environment(environment, definition)
	var state := SequenceRuntimeScript.normalize_state(environment.get("scenario_sequence_state", {}), definition)
	return SequenceRuntimeScript.public_projection(state, definition) if not state.is_empty() else {}


static func sequence_reentry(environment: Dictionary, definition: Dictionary, visit_id: String) -> Dictionary:
	definition = sequence_definition_for_environment(environment, definition)
	var state := ensure_sequence_state(environment, definition)
	if state.is_empty():
		return {"ok": false, "inactive": true, "errors": []}
	var result := SequenceRuntimeScript.apply_reentry(state, definition, visit_id)
	if bool(result.get("ok", false)):
		environment["scenario_sequence_state"] = _copy_dict(result.get("state", state))
		_refresh_sequence_snapshots(environment, definition)
	return result


static func sequence_expiry(environment: Dictionary, definition: Dictionary, boundary: String, boundary_serial: int) -> Dictionary:
	definition = sequence_definition_for_environment(environment, definition)
	var state := ensure_sequence_state(environment, definition)
	if state.is_empty():
		return {"ok": false, "inactive": true, "errors": []}
	var result := SequenceRuntimeScript.apply_expiry(state, definition, boundary, boundary_serial)
	if bool(result.get("ok", false)):
		environment["scenario_sequence_state"] = _copy_dict(result.get("state", state))
		_refresh_sequence_snapshots(environment, definition)
	return result


static func drain_sequence_transitions(environment: Dictionary, definition: Dictionary, reduced_motion: bool = false) -> Dictionary:
	definition = sequence_definition_for_environment(environment, definition)
	var state := ensure_sequence_state(environment, definition)
	if state.is_empty():
		return {"ok": false, "inactive": true, "transitions": [], "errors": []}
	var result := SequenceRuntimeScript.drain_transitions(state, definition, reduced_motion)
	if bool(result.get("ok", false)):
		environment["scenario_sequence_state"] = _copy_dict(result.get("state", state))
		_refresh_sequence_snapshots(environment, definition)
	return result


static func drain_sequence_event_requests(environment: Dictionary, definition: Dictionary) -> Dictionary:
	definition = sequence_definition_for_environment(environment, definition)
	var state := ensure_sequence_state(environment, definition)
	if state.is_empty():
		return {"ok": false, "inactive": true, "requests": [], "errors": []}
	var result := SequenceRuntimeScript.drain_event_requests(state, definition)
	if bool(result.get("ok", false)):
		environment["scenario_sequence_state"] = _copy_dict(result.get("state", state))
		_refresh_sequence_snapshots(environment, definition)
	return result


static func refresh_sequence_snapshots(environment: Dictionary, definition: Dictionary = {}) -> Dictionary:
	definition = sequence_definition_for_environment(environment, definition)
	return _refresh_sequence_snapshots(environment, definition)


static func _refresh_sequence_snapshots(environment: Dictionary, definition: Dictionary) -> Dictionary:
	var state := SequenceRuntimeScript.normalize_state(environment.get("scenario_sequence_state", {}), definition)
	if state.is_empty():
		environment.erase("scenario_sequence_projection")
		environment.erase("scenario_render_snapshot")
		return {}
	var projection := SequenceRuntimeScript.public_projection(state, definition)
	_materialize_sequence_services_games_routes(environment, projection)
	var render_snapshot := ScenarioExtensionDispatchScript.prepare_render(definition, environment, projection)
	environment["scenario_sequence_projection"] = projection
	environment["scenario_render_snapshot"] = render_snapshot
	return render_snapshot.duplicate(true)


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


static func _sequence_state_can_bind_initial_node(state: Dictionary, environment: Dictionary) -> bool:
	var original := str(state.get("node_id", "")).strip_edges()
	var archetype_id := str(environment.get("archetype_id", "")).strip_edges()
	return (original.is_empty() or original == archetype_id) \
		and int(state.get("boundary_serial", 0)) == 0 \
		and int(state.get("phase_action_counter", 0)) == 0 \
		and _copy_array(state.get("fact_receipts", [])).is_empty() \
		and _copy_array(state.get("command_receipts", [])).is_empty() \
		and _copy_array(state.get("fact_queue", [])).is_empty()


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
