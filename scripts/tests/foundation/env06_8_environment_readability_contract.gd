class_name Env068EnvironmentReadabilityContract
extends RefCounted

const SequenceCatalogScript := preload("res://scripts/core/scenario_sequence_catalog.gd")
const SequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const SemanticInventoryScript := preload("res://scripts/core/environment_semantic_inventory.gd")
const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")
const EnvironmentBaseSemanticRecordsScript := preload("res://scripts/core/environment_base_semantic_records.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const EnvironmentInteractionControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")
const EnvironmentInteractionViewModelScript := preload("res://scripts/ui/environment_interaction_view_model.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const ScenarioSequenceContractScript := preload("res://scripts/tests/foundation/scenario_sequence_contract.gd")
const CrewHeistModelScript := preload("res://scripts/core/crew_heist_model.gd")
const CrewTurnModelScript := preload("res://scripts/core/crew_turn_model.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")

const EXPECTED_SCENARIOS := 55
const EXPECTED_PHASE_OBJECT_OPS := 1108
const EXPECTED_ACTIONS := 727
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
	"you let the pressure win",
	"you refuse and leave cleanly",
	"you refuse the task",
	"settles directly into the same visible result",
	"opening the next layer to",
]


static func check(library: Variant, failures: Array) -> void:
	var definitions := _scenario_definitions(library)
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


static func check_geometry(library: Variant, failures: Array, telemetry: Dictionary = {}) -> void:
	var definitions := _scenario_definitions(library)
	if definitions.size() != EXPECTED_SCENARIOS:
		failures.append("env06_8 geometry expected %d scenario definitions, got %d." % [EXPECTED_SCENARIOS, definitions.size()])
		return
	for definition_value in definitions:
		var definition := _dict(definition_value)
		var host := _production_host_semantics(library, definition, failures)
		var layout_fixture := _production_layout_fixture(library, definition, failures)
		if host.is_empty() or layout_fixture.is_empty():
			continue
		var observer := _reachable_presentation_observer(definition, host, failures, layout_fixture, false)
		telemetry["reachable_state_count"] = int(telemetry.get("reachable_state_count", 0)) + int(observer.get("reachable_state_count", 0))
		for snapshot_value in _array(observer.get("snapshots", [])):
			var snapshot := _dict(snapshot_value)
			telemetry["layout_state_count"] = int(telemetry.get("layout_state_count", 0)) + 1
			telemetry["candidate_checks"] = int(telemetry.get("candidate_checks", 0)) + int(snapshot.get("placement_candidate_checks", 0))
			telemetry["max_search"] = maxi(int(telemetry.get("max_search", 0)), int(snapshot.get("max_placement_search", 0)))
			telemetry["candidate_limit"] = maxi(int(telemetry.get("candidate_limit", 0)), int(snapshot.get("placement_candidate_limit", 0)))
			telemetry["repair_checks"] = int(telemetry.get("repair_checks", 0)) + int(snapshot.get("repair_candidate_checks", 0))
			telemetry["max_repair_search"] = maxi(int(telemetry.get("max_repair_search", 0)), int(snapshot.get("max_repair_search", 0)))
			telemetry["repair_limit"] = maxi(int(telemetry.get("repair_limit", 0)), int(snapshot.get("repair_candidate_limit", 0)))
			telemetry["repair_count"] = int(telemetry.get("repair_count", 0)) + int(snapshot.get("repair_count", 0))
			telemetry["repair_generation_checks"] = int(telemetry.get("repair_generation_checks", 0)) + int(snapshot.get("repair_generation_checks", 0))
			telemetry["repair_backtrack_visits"] = int(telemetry.get("repair_backtrack_visits", 0)) + int(snapshot.get("repair_backtrack_visits", 0))
			telemetry["max_repair_generation"] = maxi(int(telemetry.get("max_repair_generation", 0)), int(snapshot.get("max_repair_generation", 0)))
			telemetry["max_repair_backtrack"] = maxi(int(telemetry.get("max_repair_backtrack", 0)), int(snapshot.get("max_repair_backtrack", 0)))


static func _scenario_definitions(library: Variant) -> Array:
	var definitions: Array = []
	for pool_value in library.environment_scenarios.values():
		for definition_value in _array(pool_value):
			if typeof(definition_value) != TYPE_DICTIONARY: continue
			var definition := SequenceCatalogScript.apply_overlay(definition_value as Dictionary, library.scenario_sequence_catalog)
			if not _dict(definition.get("sequence", {})).is_empty(): definitions.append(definition)
	return definitions


static func _check_definition(definition: Dictionary, counts: Dictionary, presentation_records: Array, failures: Array) -> void:
	var sequence := _dict(definition.get("sequence", {}))
	var scenario_id := str(definition.get("id", ""))
	var creates: Dictionary = {}
	var dialogue_action_count := 0
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
				if handler_id == "event_bridge": dialogue_action_count += 1
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
	if dialogue_action_count != 1:
		failures.append("env06_8 %s requires exactly one reachable authored dialogue consequence; found %d." % [scenario_id, dialogue_action_count])


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
	_check_production_hidden_state_boundary(library, failures)
	for definition_value in definitions:
		var definition := _dict(definition_value)
		var host := _production_host_semantics(library, definition, failures)
		if host.is_empty():
			continue
		var layout_fixture := _production_layout_fixture(library, definition, failures)
		if layout_fixture.is_empty():
			continue
		_reachable_presentation_observer(definition, host, failures, layout_fixture)


static func _check_production_hidden_state_boundary(library: Variant, failures: Array) -> void:
	# This is deliberately a production-boundary test, not a second invocation of
	# the pure sequence reducer. Both runs carry the exact same public room and
	# scenario definition, while the hostile run differs in four private systems.
	# Every comparison is made after RunState finalization, sealed layout,
	# controller projection, and committed information-panel validation.
	var definition: Dictionary = ScenarioSequenceContractScript.finalization_fixture_definition()
	print("ENV06_8_HIDDEN_BOUNDARY milestone=baseline_start")
	var pair: Array = _paired_production_runs(definition)
	var clean_run: Variant = pair[0]
	var hostile_run: Variant = pair[1]
	print("ENV06_8_HIDDEN_BOUNDARY milestone=paired_runs_ready")
	if JSON.stringify(clean_run.current_environment) != JSON.stringify(hostile_run.current_environment):
		failures.append("env06_8 paired production runs did not begin with identical public scenario setup.")
		return
	if _hidden_host_fingerprint(clean_run) == _hidden_host_fingerprint(hostile_run):
		failures.append("env06_8 paired production hidden-state control did not actually differ.")
		return
	var clean_arrival := _finalize_production_observer(clean_run, library, failures, "clean arrival")
	print("ENV06_8_HIDDEN_BOUNDARY milestone=clean_arrival_ready")
	var hostile_arrival := _finalize_production_observer(hostile_run, library, failures, "hostile arrival")
	print("ENV06_8_HIDDEN_BOUNDARY milestone=hostile_arrival_ready")
	if clean_arrival.is_empty() or hostile_arrival.is_empty():
		return
	if JSON.stringify(clean_arrival) != JSON.stringify(hostile_arrival):
		failures.append("env06_8 production arrival presentation leaked Turn, grievance, rigged Numbers, or unrevealed-ticket state.")
		return
	var clean_action := _observer_action(clean_arrival, "scenario::command_console", "prepare")
	var hostile_action := _observer_action(hostile_arrival, "scenario::command_console", "prepare")
	if clean_action.is_empty() or clean_action != hostile_action:
		failures.append("env06_8 paired production controller projections did not expose the same prepare action authority.")
		return
	var clean_command: Dictionary = clean_run.scenario_sequence_command(
		"prepare", "env06_8_public_prepare", {}, "scenario", "command_console", {"scenario::command_console": true},
		str(clean_action.get("origin_owner", "")), str(clean_action.get("origin_stable", "")), str(clean_action.get("origin_receipt", "")),
		str(clean_action.get("origin_boundary", "")), str(clean_action.get("origin_fingerprint", "")))
	var hostile_command: Dictionary = hostile_run.scenario_sequence_command(
		"prepare", "env06_8_public_prepare", {}, "scenario", "command_console", {"scenario::command_console": true},
		str(hostile_action.get("origin_owner", "")), str(hostile_action.get("origin_stable", "")), str(hostile_action.get("origin_receipt", "")),
		str(hostile_action.get("origin_boundary", "")), str(hostile_action.get("origin_fingerprint", "")))
	var clean_complication := _operation_production_observer(clean_run, clean_command, failures, "clean complication")
	print("ENV06_8_HIDDEN_BOUNDARY milestone=clean_complication_ready")
	var hostile_complication := _operation_production_observer(hostile_run, hostile_command, failures, "hostile complication")
	print("ENV06_8_HIDDEN_BOUNDARY milestone=hostile_complication_ready")
	if clean_complication.is_empty() or hostile_complication.is_empty():
		return
	if JSON.stringify(clean_complication) != JSON.stringify(hostile_complication):
		failures.append("env06_8 production complication presentation leaked paired private state.")
		return
	var clean_fact: Dictionary = clean_run.scenario_enqueue_fact("heat_changed", "heat", {"previous": 1, "current": 2, "applied_delta": 1, "source": "env06_8_public_control"}, "env06_8_public_heat")
	var hostile_fact: Dictionary = hostile_run.scenario_enqueue_fact("heat_changed", "heat", {"previous": 1, "current": 2, "applied_delta": 1, "source": "env06_8_public_control"}, "env06_8_public_heat")
	if not bool(clean_fact.get("ok", false)) or not bool(hostile_fact.get("ok", false)):
		failures.append("env06_8 authenticated public-fact control could not enter both production runs: %s / %s" % [JSON.stringify(clean_fact.get("errors", [])), JSON.stringify(hostile_fact.get("errors", []))])
		return
	var clean_flush: Dictionary = clean_run.scenario_flush_facts()
	var hostile_flush: Dictionary = hostile_run.scenario_flush_facts()
	var clean_aftermath := _operation_production_observer(clean_run, clean_flush, failures, "clean public-fact aftermath")
	print("ENV06_8_HIDDEN_BOUNDARY milestone=clean_aftermath_ready")
	var hostile_aftermath := _operation_production_observer(hostile_run, hostile_flush, failures, "hostile public-fact aftermath")
	print("ENV06_8_HIDDEN_BOUNDARY milestone=hostile_aftermath_ready")
	if clean_aftermath.is_empty() or hostile_aftermath.is_empty():
		return
	if JSON.stringify(clean_aftermath) != JSON.stringify(hostile_aftermath):
		failures.append("env06_8 production aftermath presentation leaked paired private state after an identical public fact.")
	if SequenceRuntimeScript.content_fingerprint(clean_complication) == SequenceRuntimeScript.content_fingerprint(clean_aftermath):
		failures.append("env06_8 public-fact positive control did not change the visible production projection digest.")


static func _paired_production_runs(definition: Dictionary) -> Array:
	# Initialize the expensive world once, then exercise the real save/restore
	# boundary into two independent RunState instances. Private mutations are
	# applied only after restore, so public setup remains byte-identical.
	var baseline: Variant = RunStateScript.new()
	baseline.start_new("ENV06_8-PRODUCTION-PAIR")
	var serialized_baseline: Dictionary = baseline.to_dict()
	var clean_run: Variant = RunStateScript.new()
	var hostile_run: Variant = RunStateScript.new()
	clean_run.from_dict(serialized_baseline.duplicate(true))
	hostile_run.from_dict(serialized_baseline.duplicate(true))
	clean_run.current_environment = _production_finalization_environment(definition)
	hostile_run.current_environment = _production_finalization_environment(definition)
	var turn: Dictionary = CrewTurnModelScript.empty_state()
	turn["m"] = str(CrewStateModelScript.MEMBER_IDS[1])
	hostile_run.crew_heist_state = CrewHeistModelScript.begin(CrewHeistModelScript.PLAN_COUNT, 0)
	hostile_run.crew_heist_state["x"] = turn
	hostile_run.grievance_add({"member_id": str(CrewStateModelScript.MEMBER_IDS[1]), "kind": "job_abandoned", "weight": 9, "source_ref": "env06_8_hidden_probe"})
	hostile_run.numbers_state.draws_by_day[0] = {"number": "777", "posted": false, "fixed": true}
	hostile_run.numbers_state.fix_state = {"status": "ready", "retry_day": 0, "number": "777"}
	hostile_run.portable_ticket_piles = {
		"scratch_tickets": {"env06_8_hidden": {"active_ticket": {"id": "hidden_scratch", "mechanic_result": {"payout": 500}}, "pending_queue": [{"id": "hidden_next", "mechanic_result": {"payout": 0}}]}},
		"pull_tabs": {"env06_8_hidden": {"ticket_stack": [{"id": "hidden_pull_tab", "payout": 100}]}},
	}
	return [clean_run, hostile_run]


static func _hidden_host_fingerprint(run_state: Variant) -> String:
	return SequenceRuntimeScript.content_fingerprint({
		"turn": run_state.crew_heist_state,
		"grievances": run_state.crew_grievance_ledger,
		"numbers_draws": run_state.numbers_state.draws_by_day,
		"numbers_fix": run_state.numbers_state.fix_state,
		"tickets": run_state.portable_ticket_piles,
	})


static func _finalize_production_observer(run_state: Variant, library: Variant, failures: Array, label: String) -> Dictionary:
	var preparation: Dictionary = run_state.scenario_prepare_semantic_finalization()
	if not bool(preparation.get("ok", false)):
		failures.append("env06_8 %s preparation failed: %s" % [label, JSON.stringify(preparation.get("errors", []))])
		return {}
	var finalized: Dictionary = run_state.scenario_finalize_base_semantics([_production_presentation()], library, _production_layout_context())
	return _operation_production_observer(run_state, finalized, failures, label)


static func _operation_production_observer(run_state: Variant, operation: Dictionary, failures: Array, label: String) -> Dictionary:
	if not bool(operation.get("ok", false)):
		failures.append("env06_8 %s production operation failed: %s" % [label, JSON.stringify(operation.get("errors", []))])
		return {}
	var base_records := _array(run_state.current_environment.get("scenario_layout_base_records", []))
	var projected := EnvironmentInteractionControllerScript.project_finalized_sequence_interaction_result(base_records, operation)
	var committed := EnvironmentInteractionControllerScript.committed_projection_status_result(run_state, projected, base_records)
	if not bool(committed.get("ok", false)):
		failures.append("env06_8 %s controller projection failed: %s" % [label, JSON.stringify(committed.get("errors", []))])
		return {}
	var rows: Array = []
	for record_value in _array(committed.get("records", [])):
		var record := _dict(record_value)
		var actions: Array = []
		for action_value in _array(record.get("scenario_sequence_actions", record.get("available_actions", []))):
			var action := _dict(action_value)
			actions.append({
				"id": str(action.get("id", "")),
				"label": str(action.get("label", "")),
				"enabled": bool(action.get("enabled", true)),
				"origin_owner": str(action.get("action_origin_owner_namespace", "")),
				"origin_stable": str(action.get("action_origin_stable_object_id", "")),
				"origin_receipt": str(action.get("action_origin_receipt_key", "")),
				"origin_boundary": str(action.get("action_origin_boundary_id", "")),
				"origin_fingerprint": str(action.get("action_origin_fingerprint", "")),
			})
		rows.append({
			"id": str(record.get("object_id", "")),
			"icon": str(record.get("icon_key", "")),
			"label": str(record.get("label", "")),
			"description": str(record.get("short_description", "")),
			"state": str(record.get("semantic_state", record.get("state_label", ""))),
			"interactive": bool(record.get("interactive", false)),
			"read_only": bool(record.get("scenario_presentation_read_only", false)),
			"actions": actions,
			"normalized_rect": _dict(record.get("normalized_rect", {})),
			"small_screen_rect": _dict(record.get("small_screen_rect", {})),
		})
	rows.sort_custom(func(a: Variant, b: Variant) -> bool: return str(_dict(a).get("id", "")) < str(_dict(b).get("id", "")))
	var projection := _dict(committed.get("projection", {}))
	return {
		"phase_id": str(projection.get("phase_id", "")),
		"status": str(projection.get("status", "")),
		"outcomes": _array(projection.get("resolved_outcomes", [])),
		"semantic_state": _dict(projection.get("semantic_state", {})),
		"layout_authority_digest": str(committed.get("layout_authority_digest", "")),
		"rows": rows,
	}


static func _observer_action(snapshot: Dictionary, object_id: String, action_id: String) -> Dictionary:
	for row_value in _array(snapshot.get("rows", [])):
		var row := _dict(row_value)
		if str(row.get("id", "")) != object_id:
			continue
		for action_value in _array(row.get("actions", [])):
			var action := _dict(action_value)
			if str(action.get("id", "")) == action_id:
				return action
	return {}


static func _production_finalization_environment(definition: Dictionary) -> Dictionary:
	return {
		"id": "bar_001",
		"archetype_id": "bar",
		"world_node_id": "bar_node",
		"environment_visit_id": "visit_1",
		"night_instance_id": "night_env06_8",
		"context_instance_id": "context_env06_8",
		"scenario_sequence_definition": definition.duplicate(true),
		"game_ids": ["slot"],
		"event_ids": ["late_shift_discount"],
		"service_ids": ["house_drink"],
		"lender_hooks": [],
		"item_offers": [],
		"travel_hooks": ["bar"],
		"next_archetypes": [],
		"semantic_anchors": {
			"bar_floor_100": {"position": [90.0, 120.0]},
			"bar_floor_104": {"position": [420.0, 240.0]},
			"bar_actor": {"position": [180.0, 120.0]},
		},
		"layout": {"object_rects": {"game:slot": {"x": 0.1, "y": 0.1, "w": 0.12, "h": 0.18}}},
	}


static func _production_presentation() -> Dictionary:
	return EnvironmentInteractionViewModelScript.make_interactable_object({
		"object_id": "game:slot",
		"object_type": "game",
		"source_id": "slot",
		"interactive": true,
		"label": "Slot",
		"prompt": "Choose an action.",
		"enabled": true,
		"available_actions": [{"id": "enter_game", "label": "Enter"}],
		"focus_rect": Rect2(0.1, 0.1, 0.12, 0.18),
	}, {})


static func _production_layout_context() -> Dictionary:
	return {
		"reserved_overlay_board_rect": {},
		"small_screen_mode": false,
		"reduce_motion": false,
		"production_canvas": true,
	}


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


static func _production_layout_fixture(library: Variant, definition: Dictionary, failures: Array) -> Dictionary:
	var scenario_id := str(definition.get("id", ""))
	var archetype_id := str(definition.get("archetype_id", ""))
	var archetype := _dict(library.environment_archetype(archetype_id))
	if archetype.is_empty():
		failures.append("env06_8 %s has no production archetype %s for layout proof." % [scenario_id, archetype_id])
		return {}
	var rng := RngStreamScript.new()
	rng.configure(abs(("env06_8_layout:%s" % scenario_id).hash()) + 1)
	var instance: Variant = EnvironmentInstanceScript.from_archetype(archetype, 1, rng, library, {}, definition)
	var environment := _dict(instance.call("to_dict"))
	if environment.is_empty():
		failures.append("env06_8 %s could not compose its production environment for layout proof." % scenario_id)
		return {}
	var authoritative := EnvironmentBaseSemanticRecordsScript.authoritative_interactable_records(environment, library)
	if not bool(authoritative.get("ok", false)):
		failures.append("env06_8 %s could not derive trusted base layout records: %s" % [scenario_id, JSON.stringify(authoritative.get("errors", []))])
		return {}
	# Mirror RunState's production finalization seam: the catalog-derived rows are
	# producer-stamped before either semantic inventory or layout authority sees
	# them. Feeding the raw rows directly makes every base identity collapse to
	# `::`, which cannot represent a production presentation surface.
	var stamped := EnvironmentBaseSemanticRecordsScript.stamp_interactable_records(
		_array(authoritative.get("records", [])), environment, library
	)
	if not bool(stamped.get("ok", false)):
		failures.append("env06_8 %s could not stamp trusted base layout records: %s" % [scenario_id, JSON.stringify(stamped.get("errors", []))])
		return {}
	var base_records := _array(stamped.get("records", []))
	var sealed_inventory := SemanticInventoryScript.for_instance(environment, library, base_records, [])
	var inventory_errors := SemanticInventoryScript.validate(sealed_inventory)
	if not inventory_errors.is_empty():
		failures.append("env06_8 %s could not seal its production layout inventory: %s" % [scenario_id, JSON.stringify(inventory_errors)])
		return {}
	# Resolver route/anchor authority is the same exact instance seal installed by
	# RunState. Supplying only the stamped base rows proved presentation geometry
	# but incorrectly made every authored actor route look unauthorised in this
	# standalone exhaustive fixture.
	environment["scenario_semantic_inventory"] = sealed_inventory
	environment["_scenario_layout_context"] = _production_layout_context()
	return {"environment": environment, "base_records": base_records}


static func _check_presentation_records(records: Array, failures: Array) -> void:
	var icon_counts: Dictionary = {}
	for record_value in records:
		var record := _dict(record_value)
		var semantic := _dict(record.get("payload", {})).duplicate(true)
		semantic["owner_namespace"] = "scenario"
		semantic["stable_object_id"] = str(record.get("stable_object_id", ""))
		semantic["semantic_kind"] = "actor" if str(record.get("family", "")) == "actor_ops" else "scene_object"
		var icon_key := ScenarioLayoutResolverScript.scenario_icon_key(semantic)
		icon_counts[icon_key] = int(icon_counts.get(icon_key, 0)) + 1
		var authority := {"presentation_object_id": "scenario::%s" % str(record.get("stable_object_id", "")), "normalized_hit_rect": {"x": 0.1, "y": 0.1, "w": 0.1, "h": 0.1}, "small_screen_rect": {"x": 0.1, "y": 0.1, "w": 0.1, "h": 0.1}}
		var projected := EnvironmentInteractionControllerScript._merge_projected_actor({}, semantic, authority, "digest") if str(record.get("family", "")) == "actor_ops" else EnvironmentInteractionControllerScript._merge_projected_scene_object({}, semantic, authority, "digest")
		if str(projected.get("label", "")).is_empty() or str(projected.get("short_description", "")).is_empty() or str(projected.get("icon_key", "")).is_empty() or not bool(projected.get("interactive", false)):
			failures.append("env06_8 projected object %s lacks complete inspectable presentation." % str(record.get("stable_object_id", "")))
	var required_icons := [
		"scenario_actor_conflict", "scenario_actor_guard", "scenario_actor_watch", "scenario_actor_work",
		"scenario_exit", "scenario_route", "scenario_hazard", "scenario_barrier", "scenario_evidence",
		"scenario_document", "scenario_task", "scenario_workstation", "scenario_stock", "scenario_vehicle",
		"scenario_game", "scenario_stage", "scenario_equipment", "scenario_signage", "scenario_seating",
		"scenario_shelter", "scenario_service", "scenario_success", "scenario_damage", "scenario_aftermath",
	]
	for required_icon_value in required_icons:
		if int(icon_counts.get(str(required_icon_value), 0)) <= 0:
			failures.append("env06_8 semantic icon vocabulary does not exercise %s." % str(required_icon_value))
	if icon_counts.size() < 24:
		failures.append("env06_8 semantic icon vocabulary collapsed below 24 distinct families: %s" % JSON.stringify(icon_counts))
	var overlay_authority := {"presentation_object_id": "scenario::task_probe", "normalized_hit_rect": {"x": 0.1, "y": 0.1, "w": 0.1, "h": 0.1}, "small_screen_rect": {"x": 0.1, "y": 0.1, "w": 0.1, "h": 0.1}}
	var task_visual := EnvironmentInteractionControllerScript._merge_projected_scene_object({}, {
		"owner_namespace": "scenario", "stable_object_id": "task_probe", "label": "Task probe",
		"description": "The task station remains visibly inspectable.", "role": "task_station",
	}, overlay_authority, "digest")
	var task_overlay := EnvironmentInteractionControllerScript._merge_projected_interaction(task_visual, {
		"owner_namespace": "scenario", "stable_object_id": "task_probe", "label": "Task probe",
		"prompt": "Choose the visible task.", "enabled": true, "available_actions": [],
	}, overlay_authority, "digest")
	if str(task_overlay.get("icon_key", "")) != "scenario_task":
		failures.append("env06_8 interaction overlay collapsed its concrete task icon.")


static func _reachable_presentation_observer(definition: Dictionary, host: Dictionary, failures: Array, layout_fixture: Dictionary, verify_consequences: bool = true) -> Dictionary:
	var scenario_id := str(definition.get("id", ""))
	var initial := SequenceRuntimeScript.initial_state(definition, "%s_env06_8" % scenario_id, "ENV06_8-REACHABLE-%s" % scenario_id, host)
	if str(initial.get("status", "")) != SequenceRuntimeScript.STATUS_ACTIVE:
		failures.append("env06_8 %s could not initialize its production-authorized reachable observer: %s" % [scenario_id, JSON.stringify(initial.get("errors", []))])
		return {}
	var queue: Array = [initial]
	var seen: Dictionary = {}
	var phase_ids: Dictionary = {}
	var snapshots: Array = []
	var state_corpus: Array = []
	var geometry_keys: Dictionary = {}
	var serial := 0
	while not queue.is_empty() and seen.size() < 128:
		var state := _dict(queue.pop_front())
		var state_key := _reachable_state_key(state, definition)
		if seen.has(state_key):
			continue
		seen[state_key] = true
		phase_ids[str(state.get("phase_id", ""))] = true
		var geometry_key := _reachable_geometry_key(state, definition)
		if verify_consequences or not geometry_keys.has(geometry_key):
			geometry_keys[geometry_key] = true
			var snapshot := _resolved_presentation_snapshot(state, definition, scenario_id, failures, layout_fixture)
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
				if verify_consequences:
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
		var aftermath_geometry_key := _reachable_geometry_key(aftermath_state, definition)
		if verify_consequences or not geometry_keys.has(aftermath_geometry_key):
			geometry_keys[aftermath_geometry_key] = true
			snapshots.append(_resolved_presentation_snapshot(aftermath_state, definition, scenario_id, failures, layout_fixture))
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


static func _reachable_geometry_key(state: Dictionary, definition: Dictionary) -> String:
	var projection := SequenceRuntimeScript.public_projection(state, definition)
	return JSON.stringify({
		"phase_id": str(projection.get("phase_id", "")),
		"status": str(projection.get("status", "")),
		"semantic_state": _dict(projection.get("semantic_state", {})),
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


static func _resolved_presentation_snapshot(state: Dictionary, definition: Dictionary, scenario_id: String, failures: Array, layout_fixture: Dictionary) -> Dictionary:
	var projection := SequenceRuntimeScript.public_projection(state, definition)
	var layout_environment := _dict(layout_fixture.get("environment", {}))
	var base_records := _array(layout_fixture.get("base_records", []))
	if layout_environment.is_empty():
		failures.append("env06_8 %s reachable presentation lacks a production layout fixture." % scenario_id)
		return {}
	var layout_result := ScenarioLayoutResolverScript.resolve(base_records, projection, layout_environment)
	if not bool(layout_result.get("ok", false)):
		failures.append("env06_8 %s production layout resolver rejected reachable %s/%s: %s" % [scenario_id, str(projection.get("phase_id", "")), str(projection.get("status", "")), JSON.stringify(layout_result.get("errors", []))])
		var failed_audit := _dict(layout_result.get("layout_audit", {}))
		return {
			"phase_id": str(projection.get("phase_id", "")),
			"status": str(projection.get("status", "")),
			"placement_candidate_checks": int(failed_audit.get("placement_candidate_checks", 0)),
			"max_placement_search": int(failed_audit.get("max_placement_search", 0)),
			"placement_candidate_limit": int(failed_audit.get("placement_candidate_limit", 0)),
			"repair_candidate_checks": int(failed_audit.get("repair_candidate_checks", 0)),
			"max_repair_search": int(failed_audit.get("max_repair_search", 0)),
			"repair_candidate_limit": int(failed_audit.get("repair_candidate_limit", 0)),
			"repair_count": int(failed_audit.get("repair_count", 0)),
			"repair_generation_checks": int(failed_audit.get("repair_generation_checks", 0)),
			"repair_backtrack_visits": int(failed_audit.get("repair_backtrack_visits", 0)),
			"max_repair_generation": int(failed_audit.get("max_repair_generation", 0)),
			"max_repair_backtrack": int(failed_audit.get("max_repair_backtrack", 0)),
			"rows": [],
		}
	projection = _dict(layout_result.get("projection", projection))
	var authority := _dict(layout_result.get("layout_authority", {}))
	var authority_digest := str(layout_result.get("layout_authority_digest", ""))
	var composed := EnvironmentInteractionControllerScript._compose_projected_records(base_records, projection, authority, authority_digest)
	if not bool(composed.get("ok", false)):
		failures.append("env06_8 %s production presentation resolver rejected reachable %s/%s: %s" % [scenario_id, str(projection.get("phase_id", "")), str(projection.get("status", "")), JSON.stringify(composed.get("errors", []))])
		return {}
	var rows: Array = []
	for record_value in _array(composed.get("records", [])):
		var record := _dict(record_value)
		if not bool(record.get("visible", true)):
			continue
		if str(record.get("owner_namespace", "")) != "scenario" and str(record.get("object_type", "")) not in ["scenario_scene_object", "scenario_actor", "scenario_sequence"]:
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
			"layout_authority_digest": str(record.get("scenario_layout_authority_digest", "")),
			"z_order": int(record.get("scenario_z_order", 0)),
		})
	rows.sort_custom(func(a: Variant, b: Variant) -> bool: return str(_dict(a).get("id", "")) < str(_dict(b).get("id", "")))
	var layout_audit := _dict(layout_result.get("layout_audit", {}))
	return {
		"phase_id": str(projection.get("phase_id", "")),
		"status": str(projection.get("status", "")),
		"outcomes": _array(projection.get("resolved_outcomes", [])),
		"layout_authority_digest": authority_digest,
		"placement_candidate_checks": int(layout_audit.get("placement_candidate_checks", 0)),
		"max_placement_search": int(layout_audit.get("max_placement_search", 0)),
		"placement_candidate_limit": int(layout_audit.get("placement_candidate_limit", 0)),
		"repair_candidate_checks": int(layout_audit.get("repair_candidate_checks", 0)),
		"max_repair_search": int(layout_audit.get("max_repair_search", 0)),
		"repair_candidate_limit": int(layout_audit.get("repair_candidate_limit", 0)),
		"repair_count": int(layout_audit.get("repair_count", 0)),
		"repair_generation_checks": int(layout_audit.get("repair_generation_checks", 0)),
		"repair_backtrack_visits": int(layout_audit.get("repair_backtrack_visits", 0)),
		"max_repair_generation": int(layout_audit.get("max_repair_generation", 0)),
		"max_repair_backtrack": int(layout_audit.get("max_repair_backtrack", 0)),
		"rows": rows,
	}


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
		var requests := _array(drained.get("requests", []))
		if requests.size() != 1 or not _array(redrained.get("requests", [])).is_empty():
			failures.append("env06_8 %s consequence %s delivered more or less than exactly once." % [scenario_id, str(action.get("id", ""))])
		elif handler == "event_bridge":
			var request := _dict(requests[0])
			var inputs := _dict(action.get("inputs", {}))
			if str(request.get("event_id", "")) != str(inputs.get("event_id", "")) or str(request.get("resolution_id", "")) != str(inputs.get("resolution_id", "")):
				failures.append("env06_8 %s dialogue consequence %s drained the wrong event choice." % [scenario_id, str(action.get("id", ""))])


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
