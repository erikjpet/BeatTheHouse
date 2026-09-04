class_name Env068EnvironmentReadabilityContract
extends RefCounted

const SequenceCatalogScript := preload("res://scripts/core/scenario_sequence_catalog.gd")
const SequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const SemanticInventoryScript := preload("res://scripts/core/environment_semantic_inventory.gd")
const EnvironmentInteractionControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const CrewHeistModelScript := preload("res://scripts/core/crew_heist_model.gd")
const CrewTurnModelScript := preload("res://scripts/core/crew_turn_model.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")

const EXPECTED_SCENARIOS := 55
const EXPECTED_PHASE_OBJECT_OPS := 1108
const EXPECTED_ACTIONS := 673
const GENERATED_PROSE_MARKERS := [
	"the room advances to a new physical station",
	"beat moves props and actors",
	"shared aftermath fixes a distinct",
	"arrangement remains physically readable",
	"chosen outcome settles into a visible",
	"allowing you to",
	"now bears the visible signs",
	"has shifted to a new part of the room",
	"the choice to",
]


static func check(library: Variant, failures: Array) -> void:
	var definitions: Array = []
	for pool_value in library.environment_scenarios.values():
		for definition_value in _array(pool_value):
			if typeof(definition_value) != TYPE_DICTIONARY: continue
			var definition := SequenceCatalogScript.apply_overlay(definition_value as Dictionary, library.scenario_sequence_catalog)
			if not _dict(definition.get("sequence", {})).is_empty(): definitions.append(definition)
	if definitions.size() != EXPECTED_SCENARIOS:
		failures.append("env06_8 expected %d scenario definitions, got %d." % [EXPECTED_SCENARIOS, definitions.size()])
		return
	var counts := {"phase_object_ops": 0, "zoned_phase_ops": 0, "create_records": 0, "described": 0, "zoned": 0, "actions": 0, "handlers": {}}
	var presentation_records: Array = []
	for definition_value in definitions:
		_check_definition(_dict(definition_value), counts, presentation_records, failures)
	if int(counts.get("phase_object_ops", 0)) != EXPECTED_PHASE_OBJECT_OPS:
		failures.append("env06_8 object census changed: expected %d, got %d." % [EXPECTED_PHASE_OBJECT_OPS, int(counts.get("phase_object_ops", 0))])
	if int(counts.get("actions", 0)) != EXPECTED_ACTIONS:
		failures.append("env06_8 action census changed: expected %d, got %d." % [EXPECTED_ACTIONS, int(counts.get("actions", 0))])
	if int(counts.get("zoned_phase_ops", 0)) != EXPECTED_PHASE_OBJECT_OPS:
		failures.append("env06_8 phase operations are not completely zoned: %s" % JSON.stringify(counts))
	if int(counts.get("create_records", 0)) != int(counts.get("described", 0)) or int(counts.get("create_records", 0)) != int(counts.get("zoned", 0)):
		failures.append("env06_8 creation surfaces are not completely described and zoned: %s" % JSON.stringify(counts))
	var handlers := _dict(counts.get("handlers", {}))
	if int(handlers.get("<none>", 0)) != 0:
		failures.append("env06_8 still has actions without handlers.")
	if int(handlers.get("publish_feedback", 0)) != 0:
		failures.append("env06_8 still has message-only actions without a material consequence.")
	for handler_id in ["event_bridge", "grant_item", "grant_cash", "change_scene_object", "play_cue"]:
		if int(handlers.get(handler_id, 0)) <= 0:
			failures.append("env06_8 consequence vocabulary is not exercised by %s." % handler_id)
	_check_presentation_records(presentation_records, failures)
	_check_reachable_presentation_and_hidden_state(library, definitions, failures)


static func _check_definition(definition: Dictionary, counts: Dictionary, presentation_records: Array, failures: Array) -> void:
	var sequence := _dict(definition.get("sequence", {}))
	var scenario_id := str(definition.get("id", ""))
	var creates: Dictionary = {}
	_collect_create_records(sequence, scenario_id, counts, creates, presentation_records, failures)
	for phase_value in _array(_dict(sequence.get("phase_graph", {})).get("phases", [])):
		var phase := _dict(phase_value)
		counts["phase_object_ops"] = int(counts.get("phase_object_ops", 0)) + _array(phase.get("scene_ops", [])).size() + _array(phase.get("actor_ops", [])).size()
		for family in ["scene_ops", "actor_ops"]:
			for operation_value in _array(phase.get(family, [])):
				var operation := _dict(operation_value)
				var payload := _dict(operation.get("object", operation.get("actor", operation)))
				counts["zoned_phase_ops"] = int(counts.get("zoned_phase_ops", 0)) + int(not str(payload.get("zone_id", operation.get("zone_id", ""))).strip_edges().is_empty())
		for operation_value in _array(phase.get("interaction_ops", [])):
			var operation := _dict(operation_value)
			for action_value in _array(_dict(operation.get("interaction", {})).get("available_actions", operation.get("available_actions", []))):
				var action := _dict(action_value)
				var handler_id := str(action.get("handler", "<none>"))
				if handler_id.is_empty(): handler_id = "<none>"
				counts["actions"] = int(counts.get("actions", 0)) + 1
				var handlers := _dict(counts.get("handlers", {}))
				handlers[handler_id] = int(handlers.get(handler_id, 0)) + 1
				counts["handlers"] = handlers
		for family in ["scene_ops", "actor_ops"]:
			for operation_value in _array(phase.get(family, [])):
				var operation := _dict(operation_value)
				if str(operation.get("op", "")) not in ["move", "set_position", "set_state", "set_appearance", "set_pose", "set_behavior"]: continue
				var variant_key := ""
				for key in ["state", "appearance", "pose", "behavior", "anchor_id", "zone_id"]:
					if not str(operation.get(key, "")).is_empty(): variant_key = str(operation.get(key, "")); break
				if variant_key.is_empty(): continue
				var covered := false
				for payload_value in _array(creates.get(str(operation.get("stable_object_id", "")), [])):
					if _dict(_dict(payload_value).get("description_variants", {})).has(variant_key): covered = true
				if not covered:
					failures.append("env06_8 %s/%s lacks description variant %s." % [scenario_id, str(operation.get("stable_object_id", "")), variant_key])
	_check_generated_prose(sequence, scenario_id, failures)


static func _collect_create_records(value: Variant, scenario_id: String, counts: Dictionary, creates: Dictionary, presentation_records: Array, failures: Array) -> void:
	if typeof(value) == TYPE_ARRAY:
		for child in value: _collect_create_records(child, scenario_id, counts, creates, presentation_records, failures)
		return
	if typeof(value) != TYPE_DICTIONARY: return
	var row := value as Dictionary
	var family := str(row.get("family", ""))
	var payload := _dict(row.get("object", row.get("actor", {})))
	if family in ["scene_ops", "actor_ops"] and not payload.is_empty():
		counts["create_records"] = int(counts.get("create_records", 0)) + 1
		counts["described"] = int(counts.get("described", 0)) + int(not str(payload.get("description", "")).strip_edges().is_empty())
		counts["zoned"] = int(counts.get("zoned", 0)) + int(not str(payload.get("zone_id", "")).strip_edges().is_empty())
		var stable_id := str(row.get("stable_object_id", ""))
		var payloads := _array(creates.get(stable_id, [])); payloads.append(payload); creates[stable_id] = payloads
		presentation_records.append({"scenario_id": scenario_id, "family": family, "stable_object_id": stable_id, "payload": payload})
	for child in row.values(): _collect_create_records(child, scenario_id, counts, creates, presentation_records, failures)


static func _check_reachable_presentation_and_hidden_state(library: Variant, definitions: Array, failures: Array) -> void:
	for definition_value in definitions:
		var definition := _dict(definition_value)
		var scenario_id := str(definition.get("id", ""))
		var host := _production_host_semantics(library, definition, failures)
		if host.is_empty():
			continue
		var clean := _reachable_presentation_observer(definition, host, false, failures)
		var hidden := _reachable_presentation_observer(definition, host, true, failures, _array(clean.get("state_corpus", [])))
		if clean.is_empty() or hidden.is_empty():
			continue
		clean.erase("state_corpus")
		hidden.erase("state_corpus")
		if JSON.stringify(clean) != JSON.stringify(hidden):
			failures.append("env06_8 complete reachable presentation diverged for %s under paired Turn/grievance, rigged Numbers, or unrevealed-ticket state." % scenario_id)


static func _production_host_semantics(library: Variant, definition: Dictionary, failures: Array) -> Dictionary:
	var scenario_id := str(definition.get("id", ""))
	var catalog := _dict(library.scenario_target_catalog(definition))
	var inventory := _dict(catalog.get("inventory", {}))
	var inventory_errors := SemanticInventoryScript.validate(inventory)
	if not inventory_errors.is_empty():
		failures.append("env06_8 %s production target inventory is invalid: %s" % [scenario_id, JSON.stringify(inventory_errors)])
		return {}
	var declared := _dict(_dict(definition.get("sequence", {})).get("declared_targets", {}))
	var bounded: Dictionary = {}
	for collection in ["scene_objects", "interactions", "actors", "services", "games", "routes", "anchors", "zones"]:
		bounded[collection] = _array(declared.get(collection, []))
	bounded["event_choices"] = _dict(catalog.get("event_choices", {}))
	return {
		"target_inventory": bounded,
		"inventory_schema_version": int(inventory.get("schema_version", 0)),
		"inventory_digest": str(inventory.get("digest", "")),
		"event_choices": _dict(bounded.get("event_choices", {})),
		"inventory_errors": [],
		"base_interactions": [],
	}


static func _check_presentation_records(records: Array, failures: Array) -> void:
	for record_value in records:
		var record := _dict(record_value)
		var semantic := _dict(record.get("payload", {})).duplicate(true)
		semantic["owner_namespace"] = "scenario"
		semantic["stable_object_id"] = str(record.get("stable_object_id", ""))
		semantic["semantic_kind"] = "actor" if str(record.get("family", "")) == "actor_ops" else "scene_object"
		var authority := {"presentation_object_id": "scenario::%s" % str(record.get("stable_object_id", "")), "normalized_hit_rect": {"x": 0.1, "y": 0.1, "w": 0.1, "h": 0.1}, "small_screen_rect": {"x": 0.1, "y": 0.1, "w": 0.1, "h": 0.1}}
		var projected := EnvironmentInteractionControllerScript._merge_projected_actor({}, semantic, authority, "digest") if str(record.get("family", "")) == "actor_ops" else EnvironmentInteractionControllerScript._merge_projected_scene_object({}, semantic, authority, "digest")
		if str(projected.get("label", "")).is_empty() or str(projected.get("short_description", "")).is_empty() or str(projected.get("icon_key", "")).is_empty() or not bool(projected.get("interactive", false)):
			failures.append("env06_8 projected object %s lacks complete inspectable presentation." % str(record.get("stable_object_id", "")))


static func _reachable_presentation_observer(definition: Dictionary, host: Dictionary, hidden: bool, failures: Array, replay_states: Array = []) -> Dictionary:
	var scenario_id := str(definition.get("id", ""))
	# The paired host owns secret state. Only the closed production scenario host
	# contract crosses into the runtime/presentation path below.
	var hidden_host := RunStateScript.new()
	hidden_host.start_new("ENV06_8-PAIR-%s" % scenario_id)
	if hidden:
		var turn := CrewTurnModelScript.empty_state()
		turn["m"] = str(CrewStateModelScript.MEMBER_IDS[1])
		hidden_host.crew_heist_state = CrewHeistModelScript.begin(CrewHeistModelScript.PLAN_COUNT, 0)
		hidden_host.crew_heist_state["x"] = turn
		hidden_host.grievance_add({"member_id": str(CrewStateModelScript.MEMBER_IDS[1]), "kind": "job_abandoned", "weight": 9, "source_ref": "env06_8_hidden_probe"})
		hidden_host.numbers_state.draws_by_day[0] = {"number": "777", "posted": false, "fixed": true}
		hidden_host.numbers_state.fix_state = {"status": "ready", "retry_day": 0, "number": "777"}
		hidden_host.portable_ticket_piles = {
			"scratch_tickets": {"env06_8_hidden": {"active_ticket": {"id": "hidden_scratch", "mechanic_result": {"payout": 500}}, "pending_queue": [{"id": "hidden_next", "mechanic_result": {"payout": 0}}]}},
			"pull_tabs": {"env06_8_hidden": {"ticket_stack": [{"id": "hidden_pull_tab", "payout": 100}]}},
		}
	var initial := SequenceRuntimeScript.initial_state(definition, "%s_env06_8" % scenario_id, "ENV06_8-REACHABLE-%s" % scenario_id, host)
	if str(initial.get("status", "")) != SequenceRuntimeScript.STATUS_ACTIVE:
		failures.append("env06_8 %s could not initialize its production-authorized reachable observer: %s" % [scenario_id, JSON.stringify(initial.get("errors", []))])
		return {}
	if not replay_states.is_empty():
		var replay_snapshots: Array = []
		for state_value in replay_states:
			replay_snapshots.append(_resolved_presentation_snapshot(_dict(state_value), definition, scenario_id, failures))
		replay_snapshots.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(a) < JSON.stringify(b))
		return {"scenario_id": scenario_id, "reachable_state_count": replay_states.size(), "snapshots": replay_snapshots, "state_corpus": replay_states}
	var queue: Array = [initial]
	var seen: Dictionary = {}
	var phase_ids: Dictionary = {}
	var snapshots: Array = []
	var state_corpus: Array = []
	var serial := 0
	while not queue.is_empty() and seen.size() < 128:
		var state := _dict(queue.pop_front())
		var state_key := _reachable_state_key(state, definition)
		if seen.has(state_key):
			continue
		seen[state_key] = true
		phase_ids[str(state.get("phase_id", ""))] = true
		var snapshot := _resolved_presentation_snapshot(state, definition, scenario_id, failures)
		snapshots.append(snapshot)
		state_corpus.append(state)
		if str(state.get("status", "")) != SequenceRuntimeScript.STATUS_ACTIVE:
			continue
		var semantic := _dict(OperationRegistryScript.resolved_semantic_state(state.get("semantic_state", {})))
		for interaction_value in _dict(semantic.get("interactions", {})).values():
			var interaction := _dict(interaction_value)
			if not bool(interaction.get("enabled", false)):
				continue
			for action_value in _array(interaction.get("available_actions", [])):
				var action := _dict(action_value)
				var command_id := str(action.get("id", ""))
				var descriptor := SequenceRuntimeScript._command_descriptor(state, definition, str(interaction.get("owner_namespace", "")), str(interaction.get("stable_object_id", "")), command_id, {})
				if descriptor.is_empty():
					continue
				serial += 1
				var receipt := "%s_reachable_%d" % [scenario_id, serial]
				var command := SequenceRuntimeScript.command(
					command_id, str(state.get("node_id", "")), str(state.get("phase_id", "")), receipt, {},
					str(interaction.get("owner_namespace", "")), str(interaction.get("stable_object_id", "")),
					str(descriptor.get("action_origin_owner_namespace", "")), str(descriptor.get("action_origin_stable_object_id", "")),
					str(descriptor.get("action_origin_receipt_key", "")), str(descriptor.get("action_origin_boundary_id", "")), str(descriptor.get("action_origin_fingerprint", "")))
				var applied := SequenceRuntimeScript.apply_command(state, definition, command, {"available_funds": 100000})
				if not bool(applied.get("ok", false)):
					continue
				var next := _dict(applied.get("state", {}))
				_check_exactly_once_consequence(definition, command, action, next, failures, scenario_id)
				queue.append(next)
		var phase := _phase_definition(definition, str(state.get("phase_id", "")))
		var fact_types: Dictionary = {}
		for branch_value in _array(phase.get("branches", [])):
			var condition := _dict(_dict(branch_value).get("condition", {}))
			if str(condition.get("type", "")) == "fact":
				fact_types[str(condition.get("fact_type", ""))] = true
		for fact_type_value in fact_types.keys():
			var fact_type := str(fact_type_value)
			serial += 1
			var fact_boundary := int(state.get("boundary_serial", 0)) + 1
			var fact := SequenceRuntimeScript.fact(fact_type, _fact_producer(fact_type), str(state.get("node_id", "")), "%s_fact_%d" % [scenario_id, serial], serial, fact_boundary, _fact_payload(fact_type, state))
			var queued := SequenceRuntimeScript.enqueue_fact(state, definition, fact)
			if not bool(queued.get("ok", false)):
				continue
			var flushed := SequenceRuntimeScript.flush_facts(_dict(queued.get("state", {})), definition, fact_boundary)
			if not bool(flushed.get("ok", false)):
				continue
			var fact_state := _dict(flushed.get("state", {}))
			if fact_type == "world_boundary" and str(fact_state.get("status", "")) == SequenceRuntimeScript.STATUS_ACTIVE and str(fact_state.get("phase_id", "")) == str(state.get("phase_id", "")):
				serial += 1
				fact_boundary += 1
				var second := SequenceRuntimeScript.fact(fact_type, _fact_producer(fact_type), str(state.get("node_id", "")), "%s_fact_%d" % [scenario_id, serial], serial, fact_boundary, _fact_payload(fact_type, fact_state))
				var second_queued := SequenceRuntimeScript.enqueue_fact(fact_state, definition, second)
				if bool(second_queued.get("ok", false)):
					var second_flushed := SequenceRuntimeScript.flush_facts(_dict(second_queued.get("state", {})), definition, fact_boundary)
					if bool(second_flushed.get("ok", false)):
						fact_state = _dict(second_flushed.get("state", fact_state))
			queue.append(fact_state)
	# Exercise every authored aftermath from an actually initialized state. The
	# production reducer performs cleanup before installing each visible receipt.
	for outcome_value in _dict(_dict(definition.get("sequence", {})).get("aftermath", {})).keys():
		var outcome := str(outcome_value)
		var resolved := SequenceRuntimeScript._resolve_outcome(initial, definition, outcome, "env06_8_%s" % outcome)
		if not bool(resolved.get("ok", false)):
			failures.append("env06_8 %s aftermath %s could not resolve: %s" % [scenario_id, outcome, JSON.stringify(resolved.get("errors", []))])
			continue
		var aftermath_state := _dict(resolved.get("state", {}))
		snapshots.append(_resolved_presentation_snapshot(aftermath_state, definition, scenario_id, failures))
		state_corpus.append(aftermath_state)
	var expected_phases: Dictionary = {}
	for phase_value in _array(_dict(_dict(definition.get("sequence", {})).get("phase_graph", {})).get("phases", [])):
		expected_phases[str(_dict(phase_value).get("id", ""))] = true
	for phase_id_value in expected_phases.keys():
		if not phase_ids.has(str(phase_id_value)):
			failures.append("env06_8 %s reachable observer did not exercise phase %s." % [scenario_id, str(phase_id_value)])
	snapshots.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(a) < JSON.stringify(b))
	return {"scenario_id": scenario_id, "reachable_state_count": state_corpus.size(), "snapshots": snapshots, "state_corpus": state_corpus}


static func _reachable_state_key(state: Dictionary, definition: Dictionary) -> String:
	return JSON.stringify({
		"status": str(state.get("status", "")),
		"phase_id": str(state.get("phase_id", "")),
		"local_state": _dict(state.get("local_state", {})),
		"objectives": _dict(state.get("objective_progress", {})),
		"outcomes": _array(state.get("resolved_outcomes", [])),
		"semantic": SequenceRuntimeScript.public_projection(state, definition).get("semantic_state", {}),
	})


static func _phase_definition(definition: Dictionary, phase_id: String) -> Dictionary:
	for phase_value in _array(_dict(_dict(definition.get("sequence", {})).get("phase_graph", {})).get("phases", [])):
		var phase := _dict(phase_value)
		if str(phase.get("id", "")) == phase_id:
			return phase
	return {}


static func _fact_producer(fact_type: String) -> String:
	if fact_type.begins_with("travel_"): return "travel"
	if fact_type == "game_result": return "game"
	if fact_type == "event_result": return "event"
	if fact_type == "service_result": return "service"
	if fact_type.begins_with("crew_"): return "crew"
	if fact_type.begins_with("heat_"): return "heat"
	if fact_type == "town_transition": return "town"
	if fact_type == "sweep_changed": return "sweep"
	return "scenario"


static func _fact_payload(fact_type: String, state: Dictionary) -> Dictionary:
	match fact_type:
		"game_result": return {"game_id": "env06_8_game", "action_id": "resolve", "won": false, "ended": true, "bankroll_delta": 0, "chips_delta": 0, "applied_heat_delta": 0}
		"event_result": return {"event_id": "env06_8_event", "choice_id": "leave", "resolution_id": "leave", "resolved": true, "ok": true}
		"service_result": return {"kind": "service", "service_id": "env06_8_service", "ok": true, "action_id": "resolve"}
		"travel_departed", "travel_arrived": return {"source_id": str(state.get("node_id", "env06_8_source")), "target_id": "env06_8_target", "travel_kind": "road"}
		"crew_changed": return {"member_id": str(CrewStateModelScript.MEMBER_IDS[0]), "change": "present", "value": true}
		"crew_job_changed": return {"job_id": "env06_8_job", "status": "resolved", "definition_id": "env06_8_job", "member_id": str(CrewStateModelScript.MEMBER_IDS[0]), "outcome": "resolved"}
		"heat_changed": return {"previous": 0, "current": 1, "applied_delta": 1, "source": "env06_8"}
		"heat_band_changed": return {"previous_band": "quiet", "current_band": "caution", "current": 1, "source": "env06_8"}
		"town_transition": return {"action_index": 1, "weather": "clear", "day_type": "weekday", "happening_ids": []}
		"sweep_changed": return {"action_index": 1, "node_id": str(state.get("node_id", "env06_8_node")), "segment_index": 0, "active": true}
		"world_boundary": return {"amount": 1, "action_index": 1}
		"scenario_command": return {"command_id": "env06_8_probe", "receipt_id": "env06_8_probe_receipt"}
	return {}


static func _resolved_presentation_snapshot(state: Dictionary, definition: Dictionary, scenario_id: String, failures: Array) -> Dictionary:
	var projection := SequenceRuntimeScript.public_projection(state, definition)
	var semantic := _dict(projection.get("semantic_state", {}))
	var identities: Dictionary = {}
	for collection_key in ["scene_objects", "actors", "interactions"]:
		for identity_value in _dict(semantic.get(collection_key, {})).keys():
			identities[str(identity_value)] = true
	var authority: Dictionary = {}
	var identity_keys := identities.keys()
	identity_keys.sort()
	for index in range(identity_keys.size()):
		var identity := str(identity_keys[index])
		var x := 0.03 + float(index % 8) * 0.115
		var y := 0.08 + float((int(index / 8)) % 4) * 0.2
		authority[identity] = {
			"identity": identity,
			"presentation_object_id": identity,
			"normalized_hit_rect": {"x": x, "y": y, "w": 0.09, "h": 0.13},
			"small_screen_rect": {"x": x, "y": y, "w": 0.10, "h": 0.14},
			"z_order": index,
		}
	var authority_digest := JSON.stringify(authority).sha256_text()
	var composed := EnvironmentInteractionControllerScript._compose_projected_records([], projection, authority, authority_digest)
	if not bool(composed.get("ok", false)):
		failures.append("env06_8 %s production presentation resolver rejected reachable %s/%s: %s" % [scenario_id, str(projection.get("phase_id", "")), str(projection.get("status", "")), JSON.stringify(composed.get("errors", []))])
		return {}
	var rows: Array = []
	for record_value in _array(composed.get("records", [])):
		var record := _dict(record_value)
		if not bool(record.get("visible", true)):
			continue
		var actions := _array(record.get("scenario_sequence_actions", []))
		var complete := not str(record.get("label", "")).strip_edges().is_empty() \
			and not str(record.get("short_description", "")).strip_edges().is_empty() \
			and not str(record.get("icon_key", "")).strip_edges().is_empty() \
			and bool(record.get("interactive", false)) \
			and (not actions.is_empty() or bool(record.get("scenario_presentation_read_only", false)))
		if not complete:
			failures.append("env06_8 %s reachable %s/%s object %s lacks complete icon/label/description/panel presentation." % [scenario_id, str(projection.get("phase_id", "")), str(projection.get("status", "")), str(record.get("object_id", ""))])
		var action_ids: Array = []
		for action_value in actions:
			action_ids.append(str(_dict(action_value).get("id", "")))
		rows.append({
			"id": str(record.get("object_id", "")),
			"object_type": str(record.get("object_type", "")),
			"visual_type": str(record.get("visual_type", "")),
			"icon": str(record.get("icon_key", "")),
			"label": str(record.get("label", "")),
			"description": str(record.get("short_description", "")),
			"state": str(record.get("semantic_state", record.get("state_label", ""))),
			"actions": action_ids,
			"read_only": bool(record.get("scenario_presentation_read_only", false)),
			"normalized_rect": _dict(record.get("normalized_rect", {})),
			"small_screen_rect": _dict(record.get("small_screen_rect", {})),
		})
	rows.sort_custom(func(a: Variant, b: Variant) -> bool: return str(_dict(a).get("id", "")) < str(_dict(b).get("id", "")))
	return {"phase_id": str(projection.get("phase_id", "")), "status": str(projection.get("status", "")), "outcomes": _array(projection.get("resolved_outcomes", [])), "rows": rows}


static func _check_exactly_once_consequence(definition: Dictionary, command: Dictionary, action: Dictionary, state: Dictionary, failures: Array, scenario_id: String) -> void:
	var handler := str(action.get("handler", ""))
	if handler not in ["event_bridge", "grant_item", "grant_cash", "change_scene_object", "play_cue"]:
		return
	var saved := SequenceRuntimeScript.normalize_state(state, definition)
	var before := JSON.stringify(saved)
	var replay := SequenceRuntimeScript.apply_command(saved, definition, command, {"available_funds": 100000})
	if not bool(replay.get("ok", false)) or not bool(replay.get("replayed", false)) or JSON.stringify(replay.get("state", {})) != before:
		failures.append("env06_8 %s consequence %s/%s did not replay exactly once after save/load." % [scenario_id, handler, str(action.get("id", ""))])
	if handler in ["event_bridge", "grant_item", "grant_cash"]:
		var drained := SequenceRuntimeScript.drain_event_requests(saved, definition)
		if not bool(drained.get("ok", false)):
			failures.append("env06_8 %s consequence %s could not drain its external request." % [scenario_id, str(action.get("id", ""))])
			return
		var redrained := SequenceRuntimeScript.drain_event_requests(_dict(drained.get("state", {})), definition)
		if _array(drained.get("requests", [])).size() != 1 or not _array(redrained.get("requests", [])).is_empty():
			failures.append("env06_8 %s consequence %s delivered more or less than exactly once." % [scenario_id, str(action.get("id", ""))])


static func _collect_description_lines(value: Variant, result: Array) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		var row := value as Dictionary
		if row.has("description"): result.append(str(row.get("description", "")))
		for line in _dict(row.get("description_variants", {})).values(): result.append(str(line))
		for child in row.values(): _collect_description_lines(child, result)
	elif typeof(value) == TYPE_ARRAY:
		for child in value as Array: _collect_description_lines(child, result)


static func _check_generated_prose(value: Variant, scenario_id: String, failures: Array) -> void:
	if typeof(value) == TYPE_STRING:
		var text := str(value).to_lower()
		for marker in GENERATED_PROSE_MARKERS:
			if text.contains(marker): failures.append("env06_8 %s retains generated prose marker %s." % [scenario_id, marker])
	elif typeof(value) == TYPE_ARRAY:
		for child in value: _check_generated_prose(child, scenario_id, failures)
	elif typeof(value) == TYPE_DICTIONARY:
		for child in (value as Dictionary).values(): _check_generated_prose(child, scenario_id, failures)


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
