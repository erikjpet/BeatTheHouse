extends SceneTree

# Headless audit for environment generation and travel-only run paths.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")
const ScenarioSequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")
const HarnessProductionFidelityScript := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const FoundationTravelViewModelScript := preload("res://scripts/ui/foundation_travel_view_model.gd")
const TutorialFlowScript := preload("res://scripts/core/tutorial_flow.gd")
const AttributeBadgesScript := preload("res://scripts/core/attribute_badges.gd")

const DEFAULT_RUN_COUNT := 100
const DEFAULT_VISITS_PER_RUN := 6
const DEFAULT_OUTPUT_JSON := "res://.tmp/environment_generation_audit/report.json"
const DEFAULT_OUTPUT_MARKDOWN := "res://.tmp/environment_generation_audit/report.md"

# A deliberately narrow adapter lets the audit call the shipped travel view
# model without constructing FoundationMain or a UI scene. The qualifying
# contract below excludes every overlay whose host behavior is not represented
# here; target ranking, route opening hours, locked-route cards, authored Walk
# timing and choice enablement still execute in the production view model.
class AuditFoundationTravelHost:
	const TRAVEL_CLOCK_MINUTES_PER_BLOCK := 6
	const WALK_CLOCK_MINUTES_PER_BLOCK := 10

	var view_model_script: Script
	var WorldMapScript: Script
	var TutorialFlowScript: Script
	var AttributeBadgesScript: Script
	var run_state: Variant
	var generator: Variant
	var library: Variant
	var current_screen := "ENVIRONMENT"
	var selected_travel_target_id := ""
	var selected_world_map_node_id := ""
	var world_map_overlay: Variant = null
	var travel_target_ids_cache_key := ""
	var travel_target_ids_cache: Array = []
	var travel_choice_cache_key := ""
	var travel_choice_cache: Array = []
	var world_route_cache_key := ""
	var world_route_cache: Dictionary = {}

	func _init(
		p_view_model_script: Script,
		p_world_map_script: Script,
		p_tutorial_flow_script: Script,
		p_attribute_badges_script: Script,
		p_run_state: Variant,
		p_generator: Variant,
		p_library: Variant
	) -> void:
		view_model_script = p_view_model_script
		WorldMapScript = p_world_map_script
		TutorialFlowScript = p_tutorial_flow_script
		AttributeBadgesScript = p_attribute_badges_script
		run_state = p_run_state
		generator = p_generator
		library = p_library

	func _is_meta_session() -> bool:
		return false

	func _travel_base_cache_key() -> String:
		return str(view_model_script.travel_base_cache_key(self))

	func _enabled_world_route_ids(source_id: String) -> Array:
		return view_model_script.enabled_world_route_ids(self, source_id)

	func _world_route_for_target(target_id: String, path_query: Dictionary = {}) -> Dictionary:
		return view_model_script.world_route_for_target(self, target_id, path_query)

	func _environment_archetype(archetype_id: String) -> Dictionary:
		return view_model_script.environment_archetype(self, archetype_id)

	func _travel_clock_minutes_for_route(route: Dictionary, force_walk: bool = false) -> int:
		return int(view_model_script.travel_clock_minutes_for_route(self, route, force_walk))

	func _arrival_minute_for_route(route: Dictionary, force_walk: bool = false) -> int:
		return int(view_model_script.arrival_minute_for_route(self, route, force_walk))

	func _environment_open_status_at(archetype: Dictionary, minute_of_day: int) -> Dictionary:
		return view_model_script.environment_open_status_at(self, archetype, minute_of_day)

	func _travel_label_from_archetype(archetype: Dictionary, fallback_id: String) -> String:
		return str(view_model_script.travel_label_from_archetype(self, archetype, fallback_id))

	func _travel_full_preview_enabled() -> bool:
		return bool(view_model_script.travel_full_preview_enabled(self))

	func _travel_full_preview_enabled_for(target_id: String) -> bool:
		return bool(view_model_script.travel_full_preview_enabled_for(self, target_id))

	func _local_parent_home_door_travel_choice(_target_id: String) -> Dictionary:
		return {}

	func _closing_time_blocks_environment_actions() -> bool:
		return false

	func _closing_time_walk_fallback_target_id() -> String:
		return ""

	func _travel_target_ids() -> Array:
		return view_model_script.travel_target_ids(self)

	func _travel_choice(target_id: String, known_target_ids: Array) -> Dictionary:
		return view_model_script.travel_choice(self, target_id, known_target_ids)


var library: ContentLibrary
var generator: RunGenerator
var records: Array = []
var travel_records: Array = []
var run_summaries: Array = []
var failures: Array = []
var warnings: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _parse_options()
	var run_count := maxi(1, int(options.get("runs", DEFAULT_RUN_COUNT)))
	var visits_per_run := maxi(1, int(options.get("visits", DEFAULT_VISITS_PER_RUN)))
	var output_json := str(options.get("output_json", DEFAULT_OUTPUT_JSON))
	var output_markdown := str(options.get("output_markdown", DEFAULT_OUTPUT_MARKDOWN))
	var exact_seed := str(options.get("exact_seed", "")).strip_edges()
	var seed_prefix := str(options.get("seed_prefix", "")).strip_edges()
	var attempt_id := str(options.get("attempt_id", "")).strip_edges()
	var attempt_id_contract_requested := bool(options.get("require_attempt_id", false))
	var require_attempt_id := true
	var attempt_id_valid := attempt_id_contract_requested and not attempt_id.is_empty()
	if not attempt_id_valid:
		failures.append("A qualifying environment audit requires --require-attempt-id and a nonempty launcher-issued attempt id.")
	var visit_contract_valid := visits_per_run == DEFAULT_VISITS_PER_RUN
	if not visit_contract_valid:
		failures.append("A qualifying environment audit requires exactly %d visits per run." % DEFAULT_VISITS_PER_RUN)
	if seed_prefix.is_empty():
		seed_prefix = _random_seed_prefix()
	if not exact_seed.is_empty():
		run_count = 1

	library = ContentLibraryScript.new()
	library.load()
	for error in library.validation_errors:
		failures.append("Content library validation error: %s" % error)
	for warning in library.validation_warnings:
		warnings.append("Content library validation warning: %s" % warning)
	generator = RunGeneratorScript.new(library)

	var entropy := RandomNumberGenerator.new()
	entropy.randomize()
	var used_seeds := {}
	for run_index in range(run_count):
		var seed := exact_seed if not exact_seed.is_empty() else _unique_seed(seed_prefix, run_index, entropy, used_seeds)
		print("ENVIRONMENT_GENERATION_AUDIT RUN %d/%d seed=%s" % [run_index + 1, run_count, seed])
		_simulate_run(run_index, seed, visits_per_run, attempt_id, require_attempt_id)
		print("ENVIRONMENT_GENERATION_AUDIT RUN_COMPLETE %d/%d" % [run_index + 1, run_count])

	var aggregate := _build_aggregate(run_count, visits_per_run, seed_prefix)
	var requested_visits_satisfied := run_summaries.size() == run_count
	var installed_finalized_visit_count := 0
	var successful_linked_travel_count := 0
	var crew_state_unchanged := run_summaries.size() == run_count
	for summary_value in run_summaries:
		if typeof(summary_value) != TYPE_DICTIONARY:
			requested_visits_satisfied = false
			crew_state_unchanged = false
			break
		var summary: Dictionary = summary_value
		installed_finalized_visit_count += int(summary.get("installed_finalized_visit_count", 0))
		successful_linked_travel_count += int(summary.get("successful_linked_travel_count", 0))
		if not bool(summary.get("requested_visits_satisfied", false)):
			requested_visits_satisfied = false
		if not bool(summary.get("crew_state_unchanged", false)):
			crew_state_unchanged = false
	var native_diagnostics := _native_diagnostic_totals()
	var native_diagnostic_failure_count := int(native_diagnostics.get("failure_count", 0))
	var native_diagnostic_warning_count := int(native_diagnostics.get("warning_count", 0))
	var native_diagnostics_clean := native_diagnostic_failure_count == 0 and native_diagnostic_warning_count == 0
	var evidence_satisfied := requested_visits_satisfied \
		and crew_state_unchanged \
		and attempt_id_valid \
		and visit_contract_valid \
		and native_diagnostics_clean
	var qualifying_passed := failures.is_empty() and warnings.is_empty() and evidence_satisfied
	var report := {
		"tool": "environment_generation_audit",
		"evidence_schema_version": 2,
		"generated_at_unix": Time.get_unix_time_from_system(),
		"attempt_id": attempt_id,
		"attempt_id_required": require_attempt_id,
		"attempt_id_valid": attempt_id_valid,
		"run_count": run_count,
		"visits_per_run_target": visits_per_run,
		"travels_per_run_target": maxi(0, visits_per_run - 1),
		"seed_prefix": seed_prefix,
		"exact_seed_requested": not exact_seed.is_empty(),
		"requested_seed_text": exact_seed,
		"requested_total_visit_count": run_count * visits_per_run,
		"requested_total_travel_count": run_count * maxi(0, visits_per_run - 1),
		"installed_finalized_visit_count": installed_finalized_visit_count,
		"successful_linked_travel_count": successful_linked_travel_count,
		"requested_visits_satisfied": requested_visits_satisfied,
		"crew_state_unchanged": crew_state_unchanged,
		"private_state_evidence_policy": "digest_only",
		"native_diagnostics_clean": native_diagnostics_clean,
		"native_diagnostics": native_diagnostics,
		"tool_failure_count": failures.size(),
		"tool_warning_count": warnings.size(),
		"warnings_clean": warnings.is_empty() and native_diagnostic_warning_count == 0,
		"passed": qualifying_passed,
		"failure_count": failures.size() + native_diagnostic_failure_count,
		"warning_count": warnings.size() + native_diagnostic_warning_count,
		"method": _method_notes(),
		"aggregate": aggregate,
		"runs": run_summaries,
		"environment_records": records,
		"travel_records": travel_records,
		"failures": failures,
		"warnings": warnings,
	}
	_write_json(output_json, report)
	_write_markdown(output_markdown, report)
	_print_summary(output_json, output_markdown, aggregate, evidence_satisfied)
	await _finish(0 if qualifying_passed else 1)


func _finish(exit_code: int) -> void:
	await process_frame
	quit(exit_code)


func _parse_options() -> Dictionary:
	var options := {}
	for arg in OS.get_cmdline_user_args():
		var text := str(arg)
		if text.begins_with("--runs="):
			options["runs"] = maxi(1, int(text.trim_prefix("--runs=")))
		elif text.begins_with("--visits="):
			options["visits"] = maxi(1, int(text.trim_prefix("--visits=")))
		elif text.begins_with("--output="):
			options["output_json"] = text.trim_prefix("--output=")
		elif text.begins_with("--report="):
			options["output_markdown"] = text.trim_prefix("--report=")
		elif text.begins_with("--seed-prefix="):
			options["seed_prefix"] = text.trim_prefix("--seed-prefix=")
		elif text.begins_with("--exact-seed="):
			options["exact_seed"] = text.trim_prefix("--exact-seed=")
		elif text.begins_with("--attempt-id="):
			options["attempt_id"] = text.trim_prefix("--attempt-id=")
		elif text == "--require-attempt-id":
			options["require_attempt_id"] = true
	return options


func _random_seed_prefix() -> String:
	var entropy := RandomNumberGenerator.new()
	entropy.randomize()
	return "ENV-AUDIT-%d-%d-%d" % [
		int(Time.get_unix_time_from_system()),
		int(Time.get_ticks_usec()),
		int(entropy.randi()),
	]


func _unique_seed(prefix: String, run_index: int, entropy: RandomNumberGenerator, used_seeds: Dictionary) -> String:
	var seed := "%s-%03d-%d" % [prefix, run_index, int(entropy.randi())]
	while used_seeds.has(seed):
		seed = "%s-%03d-%d" % [prefix, run_index, int(entropy.randi())]
	used_seeds[seed] = true
	return seed


func _simulate_run(run_index: int, seed: String, visits_per_run: int, attempt_id: String, require_attempt_id: bool) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed)
	var crew_state_before_json := _crew_state_json(run_state)
	var path_rng := run_state.create_rng("environment_generation_audit_path")
	var seed_binding := _seed_binding(run_state, seed)
	seed_binding["attempt_id_required"] = require_attempt_id
	var run_summary := {
		"run_index": run_index,
		"attempt_id": attempt_id,
		"seed": seed,
		"requested_seed_text": str(seed_binding.get("requested_seed_text", "")),
		"seed_text": str(seed_binding.get("seed_text", "")),
		"seed_value": int(seed_binding.get("seed_value", 0)),
		"challenge_key": str(seed_binding.get("challenge_key", "")),
		"challenge_id": str(seed_binding.get("challenge_id", "")),
		"challenge_mode": str(seed_binding.get("challenge_mode", "")),
		"challenge_seed_text": str(seed_binding.get("challenge_seed_text", "")),
		"derived_seed_value": int(seed_binding.get("derived_seed_value", 0)),
		"expected_challenge_key": str(seed_binding.get("expected_challenge_key", "")),
		"expected_seed_value": int(seed_binding.get("expected_seed_value", 0)),
		"seed_binding_valid": bool(seed_binding.get("seed_binding_valid", false)),
		"attempt_id_required": require_attempt_id,
		"attempt_id_valid": not require_attempt_id or not attempt_id.is_empty(),
		"final_seed_binding": {},
		"final_seed_binding_valid": false,
		"post_event_seed_binding_count": 0,
		"requested_visit_count": visits_per_run,
		"requested_travel_count": maxi(0, visits_per_run - 1),
		"visited": [],
		"visit_indices": [],
		"travel_indices": [],
		"initial_arrival_receipt": {},
		"stopped_reason": "completed",
		"start_bankroll": run_state.bankroll,
		"end_bankroll": run_state.bankroll,
		"end_suspicion": run_state.suspicion_level(),
		"events_resolved": 0,
		"travel_count": 0,
		"environment_count": 0,
		"installed_finalized_visit_count": 0,
		"successful_linked_travel_count": 0,
		"contiguous_visit_indices": false,
		"contiguous_travel_indices": false,
		"requested_visits_satisfied": false,
		"crew_state_before_sha256": crew_state_before_json.sha256_text(),
		"crew_state_after_sha256": "",
		"crew_state_unchanged": false,
		"travel_lock_wait_actions": 0,
	}
	var initial_arrival: Dictionary = HarnessProductionFidelityScript.generate_and_finalize(
		generator, run_state, failures, "environment-generation initial arrival for %s" % seed
	)
	var initial_projection_rebuild := _independent_live_projection_binding(run_state)
	var pending_arrival_receipt := _arrival_receipt(
		initial_arrival, run_state.current_environment, "initial", 0, -1, -1,
		attempt_id, seed_binding, run_state._scenario_semantic_ready(), initial_projection_rebuild
	)
	run_summary["initial_arrival_receipt"] = pending_arrival_receipt.duplicate(true)
	if not bool(initial_arrival.get("ok", false)):
		run_summary["stopped_reason"] = "initial_arrival_failed"
		_seal_final_seed_binding(run_summary, run_state, seed, attempt_id, require_attempt_id)
		_seal_crew_noop_evidence(run_summary, run_state, crew_state_before_json)
		_finalize_run_evidence(run_summary, visits_per_run)
		run_summaries.append(run_summary)
		return
	_audit_world_map_beach_delta(run_state.world_map, seed)

	for visit_index in range(visits_per_run):
		if run_state.current_environment.is_empty():
			run_summary["stopped_reason"] = "missing_environment"
			break
		var record := _record_environment(run_state, run_index, seed, visit_index, pending_arrival_receipt, attempt_id)
		_audit_environment_unique_object_classes(run_state.current_environment, seed, visit_index)
		var event_results := _resolve_travel_unlock_events(run_state, path_rng)
		record["events_resolved_for_travel"] = event_results
		record["resolved_event_ids_after_policy"] = _copy_array(run_state.current_environment.get("resolved_event_ids", []))
		record["next_archetypes_after_events"] = _copy_array(run_state.current_environment.get("next_archetypes", []))
		# Qualifying evidence is public/player-visible evidence. Hidden routes must
		# never be serialized merely because this is an audit process.
		record["travel_after_events"] = _travel_choices(run_state, false)
		record["travel_after_events_digest"] = _json_sha256(record["travel_after_events"])
		record["bankroll_after_events"] = run_state.bankroll
		record["suspicion_after_events"] = run_state.suspicion_level()
		var terminal_after_event_policy := run_state.is_terminal()
		var post_event_seed_binding := _seed_binding(run_state, seed)
		post_event_seed_binding["attempt_id"] = attempt_id
		post_event_seed_binding["attempt_id_required"] = require_attempt_id
		seed_binding = post_event_seed_binding
		record["seed_binding_after_event_policy"] = post_event_seed_binding.duplicate(true)
		record["seed_binding_after_event_policy_valid"] = bool(post_event_seed_binding.get("seed_binding_valid", false))
		record["terminal_after_event_policy"] = terminal_after_event_policy
		record["run_status_after_event_policy"] = str(run_state.run_status)
		record["terminal_reason_after_event_policy"] = str(run_state.run_failure_reason) if terminal_after_event_policy else ""
		record["terminal_message_after_event_policy"] = str(run_state.run_failure_message) if terminal_after_event_policy else ""
		records.append(record)
		var visited: Array = run_summary.get("visited", [])
		visited.append({
			"attempt_id": attempt_id,
			"requested_seed_text": str(seed_binding.get("requested_seed_text", "")),
			"seed_text": str(seed_binding.get("seed_text", "")),
			"seed_value": int(seed_binding.get("seed_value", 0)),
			"challenge_key": str(seed_binding.get("challenge_key", "")),
			"challenge_id": str(seed_binding.get("challenge_id", "")),
			"challenge_mode": str(seed_binding.get("challenge_mode", "")),
			"derived_seed_value": int(seed_binding.get("derived_seed_value", 0)),
			"seed_binding_valid": bool(seed_binding.get("seed_binding_valid", false)),
			"visit_index": visit_index,
			"environment_id": str(run_state.current_environment.get("id", "")),
			"archetype_id": str(run_state.current_environment.get("archetype_id", "")),
			"world_node_id": str(run_state.current_environment.get("world_node_id", run_state.current_world_node_id())),
			"scenario_id": str(run_state.current_environment.get("scenario_id", "")),
			"arrival_kind": str(pending_arrival_receipt.get("kind", "")),
			"arrival_ok": bool(pending_arrival_receipt.get("ok", false)),
			"installed_finalized": bool(pending_arrival_receipt.get("installed_finalized", false)),
			"scenario_layout_authority_digest": str(_copy_dict(pending_arrival_receipt.get("runtime_scenario_layout", {})).get("authority_digest", "")),
			"kind": str(run_state.current_environment.get("kind", "")),
			"games": _copy_array(run_state.current_environment.get("game_ids", [])),
			"events": _copy_array(run_state.current_environment.get("event_ids", [])),
			"items": _item_ids_from_offers(run_state.current_environment.get("item_offers", [])),
		})
		run_summary["visited"] = visited
		run_summary["events_resolved"] = int(run_summary.get("events_resolved", 0)) + event_results.size()
		if terminal_after_event_policy:
			run_summary["stopped_reason"] = str(run_state.run_failure_reason)
			if str(run_summary.get("stopped_reason", "")).is_empty():
				run_summary["stopped_reason"] = "terminal_after_event_policy"
			break

		if visit_index >= visits_per_run - 1:
			break
		var choice := _pick_travel_choice(run_state, path_rng)
		if choice.is_empty():
			var wait_actions := _current_travel_lock_remaining(run_state)
			if wait_actions > 0:
				run_state.advance_environment_turns(wait_actions)
				run_summary["travel_lock_wait_actions"] = int(run_summary.get("travel_lock_wait_actions", 0)) + wait_actions
				choice = _pick_travel_choice(run_state, path_rng)
		if choice.is_empty():
			run_summary["stopped_reason"] = "no_enabled_travel"
			break
		var travel_record := _travel_to(run_state, choice, visit_index, visit_index, visit_index + 1, attempt_id, seed_binding)
		travel_record["run_index"] = run_index
		travel_record["attempt_id"] = attempt_id
		travel_record["seed"] = seed
		travel_record["requested_seed_text"] = str(seed_binding.get("requested_seed_text", ""))
		travel_record["seed_text"] = str(seed_binding.get("seed_text", ""))
		travel_record["seed_value"] = int(seed_binding.get("seed_value", 0))
		travel_record["challenge_key"] = str(seed_binding.get("challenge_key", ""))
		travel_record["challenge_id"] = str(seed_binding.get("challenge_id", ""))
		travel_record["challenge_mode"] = str(seed_binding.get("challenge_mode", ""))
		travel_record["derived_seed_value"] = int(seed_binding.get("derived_seed_value", 0))
		travel_record["seed_binding_valid"] = bool(seed_binding.get("seed_binding_valid", false))
		travel_records.append(travel_record)
		if not bool(travel_record.get("ok", true)):
			run_summary["stopped_reason"] = "room_finalization_failed"
			break
		run_summary["travel_count"] = int(run_summary.get("travel_count", 0)) + 1
		pending_arrival_receipt = _copy_dict(travel_record.get("arrival_receipt", {}))
		if run_state.is_terminal():
			run_summary["stopped_reason"] = str(run_state.run_failure_reason)
			break

	run_summary["end_bankroll"] = run_state.bankroll
	run_summary["end_suspicion"] = run_state.suspicion_level()
	_seal_final_seed_binding(run_summary, run_state, seed, attempt_id, require_attempt_id)
	_seal_crew_noop_evidence(run_summary, run_state, crew_state_before_json)
	_finalize_run_evidence(run_summary, visits_per_run)
	run_summaries.append(run_summary)


func _record_environment(run_state: RunState, run_index: int, seed: String, visit_index: int, arrival_receipt: Dictionary, attempt_id: String) -> Dictionary:
	var environment := run_state.current_environment.duplicate(true)
	var seed_binding := _seed_binding(run_state, seed)
	var travel_initial := _travel_choices(run_state, false)
	var game_ids := _string_array(environment.get("game_ids", []))
	var game_states := _copy_dict(environment.get("game_states", {}))
	var state_summaries := {}
	for game_id in game_ids:
		var state := _copy_dict(game_states.get(game_id, {}))
		state_summaries[game_id] = _summarize_game_state(game_id, state)
	return {
		"run_index": run_index,
		"attempt_id": attempt_id,
		"seed": seed,
		"requested_seed_text": str(seed_binding.get("requested_seed_text", "")),
		"seed_text": str(seed_binding.get("seed_text", "")),
		"seed_value": int(seed_binding.get("seed_value", 0)),
		"challenge_key": str(seed_binding.get("challenge_key", "")),
		"challenge_id": str(seed_binding.get("challenge_id", "")),
		"challenge_mode": str(seed_binding.get("challenge_mode", "")),
		"challenge_seed_text": str(seed_binding.get("challenge_seed_text", "")),
		"derived_seed_value": int(seed_binding.get("derived_seed_value", 0)),
		"expected_challenge_key": str(seed_binding.get("expected_challenge_key", "")),
		"expected_seed_value": int(seed_binding.get("expected_seed_value", 0)),
		"seed_binding_valid": bool(seed_binding.get("seed_binding_valid", false)),
		"visit_index": visit_index,
		"capture_boundary": "arrival_before_event_policy",
		"arrival_receipt": arrival_receipt.duplicate(true),
		"installed_finalized": bool(arrival_receipt.get("installed_finalized", false)),
		"environment_id": str(environment.get("id", "")),
		"archetype_id": str(environment.get("archetype_id", "")),
		"world_node_id": str(environment.get("world_node_id", run_state.current_world_node_id())),
		"scenario_id": str(environment.get("scenario_id", "")),
		"runtime_scenario_layout": _runtime_scenario_layout_receipt(environment, run_state._scenario_semantic_ready()),
		"display_name": str(environment.get("display_name", "")),
		"kind": str(environment.get("kind", "")),
		"tier": int(environment.get("tier", 1)),
		"depth": int(environment.get("depth", visit_index)),
		"mood": str(environment.get("mood", "")),
		"art_key": str(environment.get("art_key", "")),
		"visual_context": _copy_dict(environment.get("visual_context", {})),
		"security_profile": _copy_dict(environment.get("security_profile", {})),
		"economic_profile": _copy_dict(environment.get("economic_profile", {})),
		"local_narrative_flag_count": _copy_dict(environment.get("local_narrative_flags", {})).size(),
		"suspicion_cues": _copy_array(environment.get("suspicion_cues", [])),
		"games": game_ids,
		"game_state_summaries": state_summaries,
		"events": _string_array(environment.get("event_ids", [])),
		"event_trigger_status": _event_trigger_status(run_state),
		"items": _item_offer_records(environment.get("item_offers", [])),
		"services": _string_array(environment.get("service_ids", [])),
		"lenders": _string_array(environment.get("lender_hooks", [])),
		"next_archetypes_initial": _string_array(environment.get("next_archetypes", [])),
		"travel_hooks_initial": _string_array(environment.get("travel_hooks", [])),
		"travel_initial": travel_initial,
		"travel_initial_digest": _json_sha256(travel_initial),
		"travel_lock_remaining": int(environment.get("travel_lock_remaining", 0)),
		"turns": int(environment.get("turns", 0)),
		"bankroll_on_entry": run_state.bankroll,
		"suspicion_on_entry": run_state.suspicion_level(),
	}


func _seed_binding(run_state: RunState, requested_seed_text: String) -> Dictionary:
	var challenge := _copy_dict(run_state.challenge_config)
	var challenge_key := RunStateScript.challenge_key(challenge)
	var derived_seed_value := RunStateScript.text_to_seed(challenge_key)
	var expected_challenge := RunStateScript.standard_challenge(requested_seed_text)
	var expected_challenge_key := RunStateScript.challenge_key(expected_challenge)
	var expected_seed_value := RunStateScript.text_to_seed(expected_challenge_key)
	var challenge_modifiers := _copy_dict(challenge.get("modifiers", {}))
	var seed_binding_valid := not requested_seed_text.is_empty() \
		and run_state.seed_text == requested_seed_text \
		and str(challenge.get("seed_text", "")) == requested_seed_text \
		and str(challenge.get("mode", "")) == "standard" \
		and str(challenge.get("id", "")) == "standard" \
		and str(challenge.get("daily_id", "")) == "" \
		and not bool(challenge.get("hidden_seed", true)) \
		and challenge_modifiers.is_empty() \
		and challenge_key == expected_challenge_key \
		and run_state.seed_value == derived_seed_value \
		and run_state.seed_value == expected_seed_value
	return {
		"requested_seed_text": requested_seed_text,
		"seed_text": run_state.seed_text,
		"seed_value": run_state.seed_value,
		"challenge_key": challenge_key,
		"challenge_id": str(challenge.get("id", "")),
		"challenge_mode": str(challenge.get("mode", "")),
		"challenge_seed_text": str(challenge.get("seed_text", "")),
		"challenge_daily_id": str(challenge.get("daily_id", "")),
		"challenge_hidden_seed": bool(challenge.get("hidden_seed", true)),
		"challenge_modifier_count": challenge_modifiers.size(),
		"derived_seed_value": derived_seed_value,
		"expected_challenge_key": expected_challenge_key,
		"expected_seed_value": expected_seed_value,
		"seed_binding_valid": seed_binding_valid,
	}


func _seal_final_seed_binding(run_summary: Dictionary, run_state: RunState, requested_seed_text: String, attempt_id: String, require_attempt_id: bool) -> void:
	var binding := _seed_binding(run_state, requested_seed_text)
	binding["attempt_id"] = attempt_id
	binding["attempt_id_required"] = require_attempt_id
	run_summary["final_seed_binding"] = binding.duplicate(true)
	run_summary["final_seed_binding_valid"] = bool(binding.get("seed_binding_valid", false)) \
		and (not require_attempt_id or not attempt_id.is_empty())


func _crew_state_json(run_state: RunState) -> String:
	return JSON.stringify(run_state._crew_state_for_save(true, true))


func _seal_crew_noop_evidence(run_summary: Dictionary, run_state: RunState, before_json: String) -> void:
	var after_json := _crew_state_json(run_state)
	run_summary["crew_state_before_sha256"] = before_json.sha256_text()
	run_summary["crew_state_after_sha256"] = after_json.sha256_text()
	run_summary["crew_state_unchanged"] = after_json == before_json


func _arrival_receipt(
	arrival: Dictionary,
	environment: Dictionary,
	kind: String,
	visit_index: int,
	travel_index: int,
	from_visit_index: int,
	attempt_id: String,
	seed_binding: Dictionary,
	live_semantic_ready: bool,
	independent_projection_binding: Dictionary
) -> Dictionary:
	# HarnessProductionFidelity is the production-boundary witness. Never repair a
	# missing field from the live RunState here: doing so would let a malformed
	# harness receipt prove its own destination/finalization contract.
	var installed_environment := _copy_dict(arrival.get("environment", {}))
	var travel := _copy_dict(arrival.get("travel", {}))
	var travel_environment := _copy_dict(travel.get("environment", {}))
	var finalization := _copy_dict(arrival.get("finalization", {}))
	var installed_identity_shape := _environment_identity_shape(installed_environment)
	var current_identity_shape := _environment_identity_shape(environment)
	var travel_identity_shape := _environment_identity_shape(travel_environment)
	var installed_identity_shape_valid := not installed_identity_shape.is_empty()
	var current_identity_shape_valid := not current_identity_shape.is_empty()
	var travel_identity_shape_valid := not travel_identity_shape.is_empty()
	var source_id := str(arrival.get("source_id", "")).strip_edges()
	var travel_source_id := str(travel.get("source_id", "")).strip_edges()
	var target_id := str(arrival.get("target_id", "")).strip_edges()
	var travel_target_id := str(travel.get("target_id", "")).strip_edges()
	var installed_environment_id := str(installed_identity_shape.get("environment_id", "")).strip_edges()
	var installed_archetype_id := str(installed_identity_shape.get("archetype_id", "")).strip_edges()
	var installed_world_node_id := str(installed_identity_shape.get("world_node_id", "")).strip_edges()
	var installed_scenario_id := str(installed_identity_shape.get("scenario_id", "")).strip_edges()
	var travel_environment_id := str(travel_identity_shape.get("environment_id", "")).strip_edges()
	var travel_archetype_id := str(travel_identity_shape.get("archetype_id", "")).strip_edges()
	var travel_world_node_id := str(travel_identity_shape.get("world_node_id", "")).strip_edges()
	var travel_scenario_id := str(travel_identity_shape.get("scenario_id", "")).strip_edges()
	var current_environment_id := str(current_identity_shape.get("environment_id", "")).strip_edges()
	var current_archetype_id := str(current_identity_shape.get("archetype_id", "")).strip_edges()
	var current_world_node_id := str(current_identity_shape.get("world_node_id", "")).strip_edges()
	var current_scenario_id := str(current_identity_shape.get("scenario_id", "")).strip_edges()
	var installed_projection_binding := _environment_projection_binding(installed_environment)
	var live_projection_binding := _environment_projection_binding(environment)
	var installed_travel_envelope_binding := _durable_travel_envelope_binding(installed_environment)
	var travel_projection_binding := _durable_travel_envelope_binding(travel_environment)
	var installed := installed_identity_shape_valid \
		and not installed_environment_id.is_empty() \
		and not installed_archetype_id.is_empty() \
		and not installed_world_node_id.is_empty()
	var finalization_receipt := _finalization_receipt(finalization, installed_environment)
	var runtime_layout := _runtime_scenario_layout_receipt(installed_environment, live_semantic_ready)
	var finalization_inactive := bool(finalization_receipt.get("inactive", false))
	var independent_projection_binding_valid := bool(independent_projection_binding.get("canonical_valid", false)) \
		and ((finalization_inactive and not bool(independent_projection_binding.get("active", false))) \
			or (not finalization_inactive \
				and bool(independent_projection_binding.get("active", false)) \
				and str(independent_projection_binding.get("fingerprint", "")) == str(installed_projection_binding.get("resolved_projection_fingerprint", ""))))
	var installed_projection_binding_valid := bool(installed_projection_binding.get("canonical_valid", false))
	var live_projection_binding_valid := bool(live_projection_binding.get("canonical_valid", false))
	var installed_live_projection_binding_valid := installed_projection_binding_valid \
		and live_projection_binding_valid \
		and str(installed_projection_binding.get("fingerprint", "")) == str(live_projection_binding.get("fingerprint", ""))
	# EnvironmentInstance.to_dict deliberately carries only durable travel state,
	# never the ephemeral renderer/layout proof. Bind that exact durable envelope
	# here; full projection authority is independently bound arrival <-> live and
	# against the finalizer below.
	var travel_projection_binding_required := kind != "initial"
	var travel_projection_binding_valid := not travel_projection_binding_required \
		or (bool(installed_travel_envelope_binding.get("canonical_valid", false)) \
			and bool(travel_projection_binding.get("canonical_valid", false)) \
			and str(travel_projection_binding.get("fingerprint", "")) == str(installed_travel_envelope_binding.get("fingerprint", "")))
	var expected_finalization_fingerprint := str(installed_projection_binding.get(
		"finalization_fingerprint_with_renderer" if bool(finalization_receipt.get("renderer_snapshot_present", false)) else "finalization_fingerprint",
		""
	))
	var finalization_projection_binding_valid := finalization_inactive \
		or (bool(finalization_receipt.get("projection_binding_valid", false)) \
			and str(finalization_receipt.get("projection_fingerprint", "")) == expected_finalization_fingerprint)
	var finalization_matches_runtime := str(finalization_receipt.get("semantic_digest", "")) == str(runtime_layout.get("semantic_digest", "")) \
		and str(finalization_receipt.get("layout_authority_digest", "")) == str(runtime_layout.get("authority_digest", "")) \
		and int(finalization_receipt.get("layout_authority_count", 0)) == int(runtime_layout.get("authority_count", 0)) \
		and finalization_projection_binding_valid
	var runtime_layout_valid := false
	if finalization_inactive:
		runtime_layout_valid = not bool(runtime_layout.get("semantic_ready", false)) \
			and not bool(runtime_layout.get("live_semantic_ready", false)) \
			and installed_scenario_id.is_empty() \
			and str(runtime_layout.get("semantic_digest", "")).is_empty() \
			and str(runtime_layout.get("semantic_action_digest", "")).is_empty() \
			and int(runtime_layout.get("authority_count", 0)) == 0 \
			and int(runtime_layout.get("layout_audit_field_count", 0)) == 0 \
			and int(runtime_layout.get("renderer_field_count", 0)) == 0
	else:
		runtime_layout_valid = bool(runtime_layout.get("semantic_ready", false)) \
			and bool(runtime_layout.get("live_semantic_ready", false)) \
			and str(runtime_layout.get("scenario_id", "")) == installed_scenario_id \
			and not installed_scenario_id.is_empty() \
			and int(runtime_layout.get("state_error_count", 0)) == 0 \
			and int(runtime_layout.get("semantic_error_count", 0)) == 0 \
			and int(runtime_layout.get("renderer_error_count", 0)) == 0 \
			and bool(runtime_layout.get("layout_audit_valid", false)) \
			and (bool(runtime_layout.get("layout_audit_active", false)) or bool(runtime_layout.get("layout_audit_sealed_passive", false))) \
			and bool(runtime_layout.get("authority_count_matches_audit", false)) \
			and bool(runtime_layout.get("authority_digest_matches_audit", false)) \
			and bool(runtime_layout.get("renderer_ok", false)) \
			and bool(runtime_layout.get("renderer_digest_matches_authority", false)) \
			and bool(runtime_layout.get("action_authority_contract_valid", false)) \
			and str(runtime_layout.get("semantic_digest", "")).length() == 64 \
			and str(runtime_layout.get("authority_digest", "")).length() == 64
	var arrival_errors := _copy_array(arrival.get("errors", []))
	var travel_errors := _copy_array(travel.get("errors", []))
	var arrival_contract_shape_valid := typeof(arrival.get("ok")) == TYPE_BOOL \
		and typeof(arrival.get("stage")) == TYPE_STRING \
		and typeof(arrival.get("source_id")) == TYPE_STRING \
		and typeof(arrival.get("target_id")) == TYPE_STRING \
		and typeof(arrival.get("travel")) == TYPE_DICTIONARY \
		and typeof(arrival.get("finalization")) == TYPE_DICTIONARY \
		and typeof(arrival.get("environment")) == TYPE_DICTIONARY \
		and installed_identity_shape_valid \
		and typeof(arrival.get("errors")) == TYPE_ARRAY
	var travel_contract_shape_valid := typeof(travel.get("ok")) == TYPE_BOOL \
		and typeof(travel.get("source_id")) == TYPE_STRING \
		and typeof(travel.get("target_id")) == TYPE_STRING \
		and typeof(travel.get("environment")) == TYPE_DICTIONARY \
		and travel_identity_shape_valid
	if kind != "initial":
		travel_contract_shape_valid = travel_contract_shape_valid \
			and typeof(travel.get("errors")) == TYPE_ARRAY \
			and typeof(travel.get("scenario_finalized")) == TYPE_BOOL
	var finalization_clean := bool(finalization_receipt.get("ok", false)) \
		and bool(finalization_receipt.get("contract_shape_valid", false)) \
		and int(finalization_receipt.get("warning_count", -1)) == 0 \
		and int(finalization_receipt.get("error_count", -1)) == 0
	var target_binding_valid := installed_identity_shape_valid \
		and not target_id.is_empty() \
		and travel_target_id == target_id \
		and installed_world_node_id == target_id
	var source_binding_valid := source_id.is_empty() and travel_source_id.is_empty()
	if kind != "initial":
		source_binding_valid = not source_id.is_empty() and travel_source_id == source_id
	var current_install_binding_valid := installed_identity_shape_valid \
		and current_identity_shape_valid \
		and installed_environment_id == current_environment_id \
		and installed_archetype_id == current_archetype_id \
		and installed_world_node_id == current_world_node_id \
		and installed_scenario_id == current_scenario_id
	var travel_install_binding_valid := installed_identity_shape_valid \
		and travel_identity_shape_valid \
		and travel_environment_id == installed_environment_id \
		and travel_archetype_id == installed_archetype_id \
		and travel_world_node_id == installed_world_node_id \
		and travel_scenario_id == installed_scenario_id
	var production_boundary_valid := kind == "initial" or bool(travel.get("scenario_finalized", false))
	var projection_binding_valid := installed_live_projection_binding_valid \
		and travel_projection_binding_valid \
		and finalization_projection_binding_valid \
		and independent_projection_binding_valid
	var receipt_valid := bool(arrival.get("ok", false)) \
		and str(arrival.get("stage", "")) == "complete" \
		and bool(travel.get("ok", false)) \
		and arrival_contract_shape_valid \
		and travel_contract_shape_valid \
		and arrival_errors.is_empty() \
		and travel_errors.is_empty() \
		and installed \
		and source_binding_valid \
		and target_binding_valid \
		and current_install_binding_valid \
		and travel_install_binding_valid \
		and production_boundary_valid \
		and projection_binding_valid \
		and finalization_clean \
		and finalization_matches_runtime \
		and runtime_layout_valid \
		and current_identity_shape_valid \
		and (not bool(seed_binding.get("attempt_id_required", false)) or not attempt_id.is_empty()) \
		and bool(seed_binding.get("seed_binding_valid", false))
	return {
		"ok": bool(arrival.get("ok", false)),
		"kind": kind,
		"production_path": "generate_and_finalize" if kind == "initial" else "travel_and_finalize",
		"stage": str(arrival.get("stage", "")),
		"visit_index": visit_index,
		"travel_index": travel_index,
		"from_visit_index": from_visit_index,
		"attempt_id": attempt_id,
		"attempt_id_required": bool(seed_binding.get("attempt_id_required", false)),
		"requested_seed_text": str(seed_binding.get("requested_seed_text", "")),
		"seed_text": str(seed_binding.get("seed_text", "")),
		"seed_value": int(seed_binding.get("seed_value", 0)),
		"challenge_key": str(seed_binding.get("challenge_key", "")),
		"challenge_id": str(seed_binding.get("challenge_id", "")),
		"challenge_mode": str(seed_binding.get("challenge_mode", "")),
		"challenge_seed_text": str(seed_binding.get("challenge_seed_text", "")),
		"challenge_daily_id": str(seed_binding.get("challenge_daily_id", "")),
		"challenge_hidden_seed": bool(seed_binding.get("challenge_hidden_seed", true)),
		"challenge_modifier_count": int(seed_binding.get("challenge_modifier_count", -1)),
		"derived_seed_value": int(seed_binding.get("derived_seed_value", 0)),
		"expected_challenge_key": str(seed_binding.get("expected_challenge_key", "")),
		"expected_seed_value": int(seed_binding.get("expected_seed_value", 0)),
		"seed_binding_valid": bool(seed_binding.get("seed_binding_valid", false)),
		"source_id": source_id,
		"travel_source_id": travel_source_id,
		"target_id": target_id,
		"travel_target_id": travel_target_id,
		"travel_ok": bool(travel.get("ok", false)),
		"production_scenario_finalized": bool(travel.get("scenario_finalized", false)),
		"production_boundary_valid": production_boundary_valid,
		"installed_projection_binding_valid": installed_projection_binding_valid,
		"live_projection_binding_valid": live_projection_binding_valid,
		"installed_live_projection_binding_valid": installed_live_projection_binding_valid,
		"travel_projection_binding_required": travel_projection_binding_required,
		"travel_projection_binding_valid": travel_projection_binding_valid,
		"finalization_projection_binding_valid": finalization_projection_binding_valid,
		"independent_projection_binding_valid": independent_projection_binding_valid,
		"projection_binding_valid": projection_binding_valid,
		"installed_projection_fingerprint": str(installed_projection_binding.get("fingerprint", "")),
		"live_projection_fingerprint": str(live_projection_binding.get("fingerprint", "")),
		"travel_projection_fingerprint": str(travel_projection_binding.get("fingerprint", "")),
		"finalization_projection_fingerprint": str(finalization_receipt.get("projection_fingerprint", "")),
		"independent_projection_fingerprint": str(independent_projection_binding.get("fingerprint", "")),
		"arrival_contract_shape_valid": arrival_contract_shape_valid,
		"travel_contract_shape_valid": travel_contract_shape_valid,
		"installed": installed,
		"installed_environment_id": installed_environment_id,
		"installed_archetype_id": installed_archetype_id,
		"installed_world_node_id": installed_world_node_id,
		"installed_scenario_id": installed_scenario_id,
		"travel_environment_id": travel_environment_id,
		"travel_archetype_id": travel_archetype_id,
		"travel_world_node_id": travel_world_node_id,
		"travel_scenario_id": travel_scenario_id,
		"source_binding_valid": source_binding_valid,
		"target_binding_valid": target_binding_valid,
		"current_install_binding_valid": current_install_binding_valid,
		"travel_install_binding_valid": travel_install_binding_valid,
		"finalization": finalization_receipt,
		"finalization_matches_runtime": finalization_matches_runtime,
		"runtime_layout_valid": runtime_layout_valid,
		"finalization_clean": finalization_clean,
		"installed_finalized": receipt_valid,
		"runtime_scenario_layout": runtime_layout,
		"arrival_error_count": arrival_errors.size(),
		"travel_error_count": travel_errors.size(),
		"errors": arrival_errors,
		"travel_errors": travel_errors,
	}


func _finalization_receipt(finalization: Dictionary, _environment: Dictionary) -> Dictionary:
	var inactive := bool(finalization.get("inactive", false))
	var authority := _copy_dict(finalization.get("layout_authority", {}))
	var projection_binding := _finalization_projection_binding(finalization)
	var contract_shape_valid := typeof(finalization.get("ok")) == TYPE_BOOL \
		and (not finalization.has("inactive") or typeof(finalization.get("inactive")) == TYPE_BOOL) \
		and typeof(finalization.get("errors")) == TYPE_ARRAY
	if not inactive:
		contract_shape_valid = contract_shape_valid \
			and typeof(finalization.get("digest")) == TYPE_STRING \
			and typeof(finalization.get("layout_authority")) == TYPE_DICTIONARY \
			and typeof(finalization.get("layout_authority_digest")) == TYPE_STRING \
			and typeof(finalization.get("warnings")) == TYPE_ARRAY \
			and str(finalization.get("digest", "")).length() == 64 \
			and str(finalization.get("layout_authority_digest", "")).length() == 64
	return {
		"ok": bool(finalization.get("ok", false)),
		"inactive": inactive,
		"already_finalized": bool(finalization.get("already_finalized", false)),
		"contract_shape_valid": contract_shape_valid,
		"semantic_digest": str(finalization.get("digest", "")),
		"layout_authority_digest": str(finalization.get("layout_authority_digest", "")),
		"layout_authority_count": authority.size(),
		"projection_binding_valid": inactive or bool(projection_binding.get("canonical_valid", false)),
		"projection_fingerprint": str(projection_binding.get("fingerprint", "")),
		"renderer_snapshot_present": bool(projection_binding.get("renderer_snapshot_present", false)),
		"warning_count": _copy_array(finalization.get("warnings", [])).size(),
		"error_count": _copy_array(finalization.get("errors", [])).size(),
		"warnings": _copy_array(finalization.get("warnings", [])),
		"errors": _copy_array(finalization.get("errors", [])),
	}


func _environment_projection_binding(environment: Dictionary) -> Dictionary:
	var identity_shape := _environment_identity_shape(environment)
	var identity_shape_valid := not identity_shape.is_empty()
	var scenario_id := str(identity_shape.get("scenario_id", "")).strip_edges()
	var semantic_ready := bool(environment.get("scenario_semantic_ready", false))
	var inventory_version := int(environment.get("scenario_semantic_inventory_version", 0))
	var semantic_digest := str(environment.get("scenario_semantic_digest", ""))
	var semantic_action_digest := str(environment.get("scenario_semantic_action_digest", ""))
	var inventory := _copy_dict(environment.get("scenario_semantic_inventory", {}))
	var base_interactions := _copy_array(environment.get("scenario_base_interactions", []))
	var state := _copy_dict(environment.get("scenario_sequence_state", {}))
	var semantic := _copy_dict(state.get("semantic_state", {}))
	var base_records := _copy_array(environment.get("scenario_layout_base_records", []))
	var layout_context := _copy_dict(environment.get("scenario_layout_context", {}))
	var projection := _copy_dict(environment.get("scenario_sequence_projection", {}))
	var projection_semantic := _copy_dict(projection.get("semantic_state", {}))
	var authority := _copy_dict(environment.get("scenario_layout_authority", {}))
	var authority_digest := str(environment.get("scenario_layout_authority_digest", ""))
	var audit := _copy_dict(environment.get("scenario_layout_audit", {}))
	var renderer := _copy_dict(environment.get("scenario_render_snapshot", {}))
	var trusted_state_digest := str(environment.get(ScenarioEngineScript.TRUSTED_STATE_REFERENCE_KEY, ""))
	var trusted_layout_input_digest := str(environment.get(ScenarioEngineScript.TRUSTED_LAYOUT_INPUT_DIGEST_KEY, ""))
	var state_fingerprint := _json_sha256(state)
	var action_authority_digest := ScenarioSequenceRuntimeScript.base_interaction_action_authority_digest(base_interactions)
	var canonical_authority_digest := _layout_authority_digest(authority)
	var finalization_shape := {
		"semantic_digest": semantic_digest,
		"state_sha256": state_fingerprint,
		"base_records_sha256": _json_sha256(base_records),
		"projection_sha256": _json_sha256(projection),
		"authority_sha256": _json_sha256(authority),
		"authority_digest": authority_digest,
		"audit_sha256": _json_sha256(audit),
	}
	var resolved_projection_shape := {
		"projection_sha256": _json_sha256(projection),
		"authority_sha256": _json_sha256(authority),
		"authority_digest": authority_digest,
		"audit_sha256": _json_sha256(audit),
		"renderer_sha256": _json_sha256(renderer),
		"renderer_authority_digest": str(renderer.get("layout_authority_digest", "")),
	}
	var finalization_shape_with_renderer := finalization_shape.duplicate(true)
	finalization_shape_with_renderer["renderer_present"] = true
	finalization_shape_with_renderer["renderer_sha256"] = _json_sha256(renderer)
	finalization_shape_with_renderer["renderer_authority_digest"] = str(renderer.get("layout_authority_digest", ""))
	var full_shape := finalization_shape.duplicate(true)
	full_shape["scenario_id"] = scenario_id
	full_shape["semantic_ready"] = semantic_ready
	full_shape["semantic_inventory_version"] = inventory_version
	full_shape["semantic_action_digest"] = semantic_action_digest
	full_shape["semantic_inventory_sha256"] = _json_sha256(inventory)
	full_shape["base_interactions_sha256"] = _json_sha256(base_interactions)
	full_shape["layout_context_sha256"] = _json_sha256(layout_context)
	full_shape["trusted_state_digest"] = trusted_state_digest
	full_shape["trusted_layout_input_digest"] = trusted_layout_input_digest
	full_shape["renderer_sha256"] = _json_sha256(renderer)
	full_shape["renderer_authority_digest"] = str(renderer.get("layout_authority_digest", ""))
	var active := semantic_ready or not scenario_id.is_empty()
	var canonical_valid := false
	if active:
		canonical_valid = identity_shape_valid \
			and semantic_ready \
			and not scenario_id.is_empty() \
			and inventory_version > 0 \
			and semantic_digest.length() == 64 \
			and semantic_action_digest.length() == 64 \
			and not inventory.is_empty() \
			and int(inventory.get("schema_version", 0)) == inventory_version \
			and str(inventory.get("digest", "")) == semantic_digest \
			and int(semantic.get("inventory_schema_version", 0)) == inventory_version \
			and str(semantic.get("inventory_digest", "")) == semantic_digest \
			and action_authority_digest == semantic_action_digest \
			and trusted_state_digest == state_fingerprint \
			and trusted_layout_input_digest.length() == 64 \
			and authority_digest.length() == 64 \
			and canonical_authority_digest == authority_digest \
			and str(projection_semantic.get("layout_authority_digest", "")) == authority_digest \
			and bool(audit.get("valid", false)) \
			and str(audit.get("authority_digest", "")) == authority_digest \
			and bool(renderer.get("ok", false)) \
			and str(renderer.get("layout_authority_digest", "")) == authority_digest
	else:
		canonical_valid = identity_shape_valid \
			and scenario_id.is_empty() \
			and not semantic_ready \
			and inventory_version == 0 \
			and semantic_digest.is_empty() \
			and semantic_action_digest.is_empty() \
			and inventory.is_empty() \
			and base_interactions.is_empty() \
			and state.is_empty() \
			and base_records.is_empty() \
			and layout_context.is_empty() \
			and projection.is_empty() \
			and authority.is_empty() \
			and audit.is_empty() \
			and renderer.is_empty() \
			and trusted_state_digest.is_empty() \
			and trusted_layout_input_digest.is_empty()
	return {
		"active": active,
		"canonical_valid": canonical_valid,
		"scenario_id": scenario_id,
		"semantic_digest": semantic_digest,
		"semantic_action_digest": semantic_action_digest,
		"layout_authority_digest": authority_digest,
		"canonical_layout_authority_digest": canonical_authority_digest,
		"resolved_projection_fingerprint": _json_sha256(resolved_projection_shape) if identity_shape_valid else "",
		"finalization_fingerprint": _json_sha256(finalization_shape) if identity_shape_valid else "",
		"finalization_fingerprint_with_renderer": _json_sha256(finalization_shape_with_renderer) if identity_shape_valid else "",
		"fingerprint": _json_sha256(full_shape) if identity_shape_valid else "",
	}


func _environment_identity_shape(environment: Dictionary) -> Dictionary:
	# Missing scenario_id is the canonical inactive value. If present, it must
	# remain a String; no raw identity may be normalized into a colliding string.
	if typeof(environment.get("id")) != TYPE_STRING \
			or typeof(environment.get("archetype_id")) != TYPE_STRING \
			or typeof(environment.get("world_node_id")) != TYPE_STRING \
			or typeof(environment.get("scenario_id", "")) != TYPE_STRING:
		return {}
	return {
		"environment_id": environment.get("id"),
		"archetype_id": environment.get("archetype_id"),
		"world_node_id": environment.get("world_node_id"),
		"scenario_id": environment.get("scenario_id", ""),
	}


func _durable_travel_envelope_binding(environment: Dictionary) -> Dictionary:
	# RunGenerator returns the generated EnvironmentInstance.to_dict() object,
	# which intentionally predates installation/finalization. Bind only immutable
	# generated identity here; never pretend it carries IDs/context stamped during
	# installation or the live semantic projection proof.
	var shape := _environment_identity_shape(environment)
	var identity_shape_valid := not shape.is_empty()
	return {
		"canonical_valid": identity_shape_valid \
			and not str(shape.get("environment_id", "")).is_empty() \
			and not str(shape.get("archetype_id", "")).is_empty() \
			and not str(shape.get("world_node_id", "")).is_empty(),
		"fingerprint": _json_sha256(shape) if identity_shape_valid else "",
	}


func _independent_live_projection_binding(run_state: RunState) -> Dictionary:
	if run_state == null:
		return {"active": false, "canonical_valid": false, "fingerprint": ""}
	var environment := run_state.current_environment
	var identity_shape := _environment_identity_shape(environment)
	if identity_shape.is_empty():
		return {"active": false, "canonical_valid": false, "fingerprint": ""}
	if not run_state._scenario_semantic_ready():
		var inactive_valid := str(identity_shape.get("scenario_id", "")).strip_edges().is_empty()
		return {
			"active": false,
			"canonical_valid": inactive_valid,
			"fingerprint": _json_sha256({"active": false}),
		}
	var raw_projection := run_state.world_sequence_composed_projection()
	if raw_projection.is_empty() or not bool(raw_projection.get("ok", true)):
		return {"active": true, "canonical_valid": false, "fingerprint": ""}
	var layout_environment := environment.duplicate(false)
	var layout_context := _copy_dict(environment.get("scenario_layout_context", {}))
	if not layout_context.is_empty():
		layout_environment["_scenario_layout_context"] = layout_context
	var base_records := _copy_array(environment.get("scenario_layout_base_records", []))
	var layout_result := ScenarioLayoutResolverScript.resolve(base_records, raw_projection, layout_environment)
	if not bool(layout_result.get("ok", false)):
		return {"active": true, "canonical_valid": false, "fingerprint": ""}
	var projection := _copy_dict(layout_result.get("projection", {}))
	var authority := _copy_dict(layout_result.get("layout_authority", {}))
	var authority_digest := str(layout_result.get("layout_authority_digest", ""))
	var audit := _copy_dict(layout_result.get("layout_audit", {}))
	var renderer := ScenarioLayoutResolverScript.sealed_renderer_snapshot(layout_result)
	var trusted_layout_input_digest := str(environment.get(ScenarioEngineScript.TRUSTED_LAYOUT_INPUT_DIGEST_KEY, ""))
	var recomputed_layout_input_digest := ScenarioEngineScript._sequence_layout_input_digest(environment, raw_projection)
	var projection_semantic := _copy_dict(projection.get("semantic_state", {}))
	var shape := {
		"projection_sha256": _json_sha256(projection),
		"authority_sha256": _json_sha256(authority),
		"authority_digest": authority_digest,
		"audit_sha256": _json_sha256(audit),
		"renderer_sha256": _json_sha256(renderer),
		"renderer_authority_digest": str(renderer.get("layout_authority_digest", "")),
	}
	var canonical_valid := authority_digest.length() == 64 \
		and _layout_authority_digest(authority) == authority_digest \
		and bool(audit.get("valid", false)) \
		and str(audit.get("authority_digest", "")) == authority_digest \
		and str(projection_semantic.get("layout_authority_digest", "")) == authority_digest \
		and bool(renderer.get("ok", false)) \
		and str(renderer.get("layout_authority_digest", "")) == authority_digest \
		and trusted_layout_input_digest.length() == 64 \
		and trusted_layout_input_digest == recomputed_layout_input_digest
	return {
		"active": true,
		"canonical_valid": canonical_valid,
		"fingerprint": _json_sha256(shape),
		"trusted_layout_input_digest": trusted_layout_input_digest,
		"recomputed_layout_input_digest": recomputed_layout_input_digest,
	}


func _finalization_projection_binding(finalization: Dictionary) -> Dictionary:
	var inactive := bool(finalization.get("inactive", false))
	if inactive:
		return {"active": false, "canonical_valid": true, "fingerprint": ""}
	var authority := _copy_dict(finalization.get("layout_authority", {}))
	var authority_digest := str(finalization.get("layout_authority_digest", ""))
	var projection := _copy_dict(finalization.get("projection", {}))
	var projection_semantic := _copy_dict(projection.get("semantic_state", {}))
	var audit := _copy_dict(finalization.get("layout_audit", {}))
	var renderer_present := finalization.has("renderer_snapshot")
	var renderer := _copy_dict(finalization.get("renderer_snapshot", {}))
	var shape := {
		"semantic_digest": str(finalization.get("digest", "")),
		"state_sha256": _json_sha256(_copy_dict(finalization.get("state", {}))),
		"base_records_sha256": _json_sha256(_copy_array(finalization.get("records", []))),
		"projection_sha256": _json_sha256(projection),
		"authority_sha256": _json_sha256(authority),
		"authority_digest": authority_digest,
		"audit_sha256": _json_sha256(audit),
	}
	if renderer_present:
		shape["renderer_present"] = true
		shape["renderer_sha256"] = _json_sha256(renderer)
		shape["renderer_authority_digest"] = str(renderer.get("layout_authority_digest", ""))
	var canonical_valid := str(finalization.get("digest", "")).length() == 64 \
		and authority_digest.length() == 64 \
		and _layout_authority_digest(authority) == authority_digest \
		and typeof(finalization.get("state")) == TYPE_DICTIONARY \
		and typeof(finalization.get("records")) == TYPE_ARRAY \
		and typeof(finalization.get("projection")) == TYPE_DICTIONARY \
		and typeof(finalization.get("layout_authority")) == TYPE_DICTIONARY \
		and typeof(finalization.get("layout_audit")) == TYPE_DICTIONARY \
		and bool(audit.get("valid", false)) \
		and str(audit.get("authority_digest", "")) == authority_digest \
		and str(projection_semantic.get("layout_authority_digest", "")) == authority_digest \
		and (not renderer_present or (typeof(finalization.get("renderer_snapshot")) == TYPE_DICTIONARY \
			and bool(renderer.get("ok", false)) \
			and str(renderer.get("layout_authority_digest", "")) == authority_digest))
	return {
		"active": true,
		"canonical_valid": canonical_valid,
		"renderer_snapshot_present": renderer_present,
		"fingerprint": _json_sha256(shape),
	}


func _layout_authority_digest(authority: Dictionary) -> String:
	var canonical: Array = []
	var identities := authority.keys()
	identities.sort()
	for identity_value in identities:
		canonical.append(_copy_dict(authority.get(identity_value, {})))
	return JSON.stringify(canonical).sha256_text()


func _json_sha256(value: Variant) -> String:
	return ScenarioSequenceRuntimeScript.content_fingerprint(value)


func _runtime_scenario_layout_receipt(environment: Dictionary, live_semantic_ready: bool = false) -> Dictionary:
	var state := _copy_dict(environment.get("scenario_sequence_state", {}))
	var state_semantic := _copy_dict(state.get("semantic_state", {}))
	# Actionability must come from the same sealed public projection consumed by
	# the renderer/UI. The private sequence state may still contain authored
	# actions that production preconditions removed from the player-facing view.
	var projection := _copy_dict(environment.get("scenario_sequence_projection", {}))
	var semantic := _copy_dict(projection.get("semantic_state", {}))
	var authority := _copy_dict(environment.get("scenario_layout_authority", {}))
	var interactions := _copy_dict(semantic.get("interactions", {}))
	var authority_digest := str(environment.get("scenario_layout_authority_digest", ""))
	var base_by_identity: Dictionary = {}
	for record_value in _copy_array(environment.get("scenario_layout_base_records", [])):
		if typeof(record_value) != TYPE_DICTIONARY:
			continue
		var base_record: Dictionary = record_value
		var base_identity := "%s::%s" % [str(base_record.get("owner_namespace", "")), str(base_record.get("stable_object_id", ""))]
		if base_identity != "::":
			base_by_identity[base_identity] = base_record
	var audit := _copy_dict(environment.get("scenario_layout_audit", {}))
	var reachable_interaction_ids := _string_array(audit.get("reachable_interaction_ids", []))
	var authority_identities := _sorted_keys(authority)
	var authority_receipts: Array = []
	var action_authority_member_count := 0
	var actionable_authority_count := 0
	var invalid_action_authority_count := 0
	for identity_value in authority_identities:
		var identity := str(identity_value)
		var sealed := _copy_dict(authority.get(identity, {}))
		var interaction := _copy_dict(interactions.get(identity, {}))
		var base_record := _copy_dict(base_by_identity.get(identity, {}))
		var semantic_interaction_member := bool(sealed.get("semantic_interaction_member", false))
		var presentation_mode := str(sealed.get("presentation_mode", ""))
		var semantic_interaction_present := semantic_interaction_member \
			and not interaction.is_empty() \
			and bool(interaction.get("present", true))
		var semantic_interaction_sealed := semantic_interaction_present \
			and "%s::%s" % [str(interaction.get("owner_namespace", "")), str(interaction.get("stable_object_id", ""))] == identity \
			and str(interaction.get("presentation_object_id", "")) == str(sealed.get("presentation_object_id", ""))
		var exact_sealed_authority := str(sealed.get("identity", "")) == identity \
			and not str(sealed.get("presentation_object_id", "")).is_empty() \
			and presentation_mode in ["room", "overflow"]
		var base_record_sealed := not base_record.is_empty() \
			and "%s::%s" % [str(base_record.get("owner_namespace", "")), str(base_record.get("stable_object_id", ""))] == identity \
			and str(base_record.get("object_id", "")) == str(sealed.get("presentation_object_id", "")) \
			and str(base_record.get("presentation_mode", "room")) == presentation_mode \
			and str(base_record.get("slot_id", "")) == str(sealed.get("slot_id", ""))
		var semantic_raw_actions := _copy_array(interaction.get("available_actions", []))
		var base_raw_actions := _copy_array(base_record.get("available_actions", []))
		var semantic_action_ids := _enabled_action_ids(interaction)
		var base_action_ids := _enabled_action_ids(base_record)
		var sealed_room_geometry_valid := presentation_mode == "room" \
			and _serialized_rect_has_positive_area(_copy_dict(sealed.get("normalized_hit_rect", {}))) \
			and _serialized_rect_has_positive_area(_copy_dict(sealed.get("small_screen_rect", {})))
		var sealed_overflow_valid := presentation_mode == "overflow" \
			and _copy_dict(sealed.get("normalized_hit_rect", {})).is_empty() \
			and _copy_dict(sealed.get("small_screen_rect", {})).is_empty()
		var sealed_geometry_valid := sealed_room_geometry_valid or sealed_overflow_valid
		var base_geometry_matches_seal := base_record_sealed \
			and JSON.stringify(base_record.get("normalized_rect", {})) == JSON.stringify(sealed.get("normalized_hit_rect", {})) \
			and JSON.stringify(base_record.get("small_screen_rect", {})) == JSON.stringify(sealed.get("small_screen_rect", {}))
		# The layout audit's reachable_interaction_ids covers semantic interactions
		# only. Ordinary/base controls have a separate closed reachability proof:
		# their exact stamped record must match the sealed room/overflow authority.
		var semantic_reachable := semantic_interaction_sealed \
			and reachable_interaction_ids.has(identity) \
			and sealed_geometry_valid
		var base_reachable := not semantic_interaction_member \
			and base_record_sealed \
			and base_geometry_matches_seal \
			and sealed_geometry_valid \
			and bool(sealed.get("presentation_required", false)) \
			and bool(sealed.get("presentation_visible", false)) \
			and bool(sealed.get("presentation_interactive", false)) \
			and bool(base_record.get("visible", true)) \
			and bool(base_record.get("interactive", true))
		var reachable := semantic_reachable or base_reachable
		var reachability_basis := "layout_audit_room" if semantic_reachable and presentation_mode == "room" \
			else ("layout_audit_overflow" if semantic_reachable \
			else ("sealed_base_room" if base_reachable and presentation_mode == "room" \
			else ("sealed_base_overflow" if base_reachable else "")))
		var semantic_enabled := bool(interaction.get("enabled", false))
		var base_enabled := bool(base_record.get("enabled", false))
		var semantic_disabled_reason := str(interaction.get("disabled_reason", "")).strip_edges()
		var base_disabled_reason := str(base_record.get("disabled_reason", "")).strip_edges()
		var semantic_authority_core_valid := semantic_interaction_sealed \
			and exact_sealed_authority \
			and bool(sealed.get("presentation_required", false)) \
			and bool(sealed.get("presentation_visible", false)) \
			and bool(sealed.get("presentation_interactive", false)) \
			and semantic_reachable \
			and typeof(interaction.get("enabled")) == TYPE_BOOL \
			and typeof(interaction.get("available_actions")) == TYPE_ARRAY \
			and typeof(interaction.get("disabled_reason", "")) == TYPE_STRING
		var base_authority_core_valid := not semantic_interaction_member \
			and base_record_sealed \
			and base_geometry_matches_seal \
			and exact_sealed_authority \
			and base_reachable \
			and typeof(base_record.get("enabled")) == TYPE_BOOL \
			and typeof(base_record.get("available_actions")) == TYPE_ARRAY \
			and typeof(base_record.get("disabled_reason", "")) == TYPE_STRING
		var semantic_actionable := semantic_authority_core_valid \
			and semantic_enabled \
			and not semantic_action_ids.is_empty()
		var base_actionable := base_authority_core_valid \
			and base_enabled \
			and not base_action_ids.is_empty()
		var semantic_disabled_authority_valid := semantic_authority_core_valid \
			and not semantic_enabled \
			and semantic_raw_actions.is_empty() \
			and not semantic_disabled_reason.is_empty()
		var base_disabled_authority_valid := base_authority_core_valid \
			and not base_enabled \
			and base_raw_actions.is_empty() \
			and not base_disabled_reason.is_empty()
		var base_action_authority_member := not semantic_interaction_member \
			and bool(sealed.get("presentation_required", false)) \
			and bool(sealed.get("presentation_interactive", false)) \
			and not base_record.is_empty() \
			and bool(base_record.get("interactive", true)) \
			and (base_record.has("available_actions") or base_record.has("disabled_reason"))
		var action_authority_member := bool(sealed.get("presentation_required", false)) \
			and ((semantic_interaction_member and semantic_interaction_present) or base_action_authority_member)
		var actionable := semantic_actionable or base_actionable
		var disabled_authority_valid := semantic_disabled_authority_valid or base_disabled_authority_valid
		var authority_valid := not action_authority_member or actionable or disabled_authority_valid
		var action_authority_valid := authority_valid
		if action_authority_member:
			action_authority_member_count += 1
			if actionable:
				actionable_authority_count += 1
			if not action_authority_valid:
				invalid_action_authority_count += 1
		var runtime_enabled := bool(interaction.get("enabled", false)) if semantic_interaction_member else bool(base_record.get("enabled", false))
		var runtime_visible := bool(sealed.get("presentation_visible", false)) \
			and (bool(interaction.get("present", true)) if semantic_interaction_member else bool(base_record.get("visible", true)))
		var runtime_interactive := bool(sealed.get("presentation_interactive", false)) \
			and (semantic_interaction_present if semantic_interaction_member else bool(base_record.get("interactive", true)))
		var action_ids := semantic_action_ids if semantic_interaction_member else base_action_ids
		var raw_actions := semantic_raw_actions if semantic_interaction_member else base_raw_actions
		authority_receipts.append({
			"identity": identity,
			"presentation_object_id": str(sealed.get("presentation_object_id", "")),
			"source": str(sealed.get("source", "")),
			"presentation_mode": presentation_mode,
			"slot_id": str(sealed.get("slot_id", "")),
			"presentation_required": bool(sealed.get("presentation_required", false)),
			"presentation_visible": bool(sealed.get("presentation_visible", false)),
			"presentation_interactive": bool(sealed.get("presentation_interactive", false)),
			"semantic_scene_object_member": bool(sealed.get("semantic_scene_object_member", false)),
			"semantic_actor_member": bool(sealed.get("semantic_actor_member", false)),
			"semantic_interaction_member": semantic_interaction_member,
			"semantic_interaction_present": semantic_interaction_present,
			"semantic_interaction_sealed": semantic_interaction_sealed,
			"base_record_present": not base_record.is_empty(),
			"base_object_id": str(base_record.get("object_id", "")),
			"exact_sealed_authority": exact_sealed_authority,
			"projected_record_sealed": base_record_sealed,
			"base_record_sealed": base_record_sealed,
			"base_geometry_matches_seal": base_geometry_matches_seal,
			"runtime_enabled": runtime_enabled,
			"runtime_visible": runtime_visible,
			"runtime_interactive": runtime_interactive,
			"raw_action_count": raw_actions.size(),
			"enabled_action_count": action_ids.size(),
			"enabled_action_ids": action_ids,
			"semantic_enabled_action_ids": semantic_action_ids,
			"projected_enabled_action_ids": base_action_ids,
			"action_authority_member": action_authority_member,
			"base_action_authority_member": base_action_authority_member,
			"action_authority_present": not action_ids.is_empty(),
			"authority_valid": authority_valid,
			"disabled_authority_valid": disabled_authority_valid,
			"disabled_reason": semantic_disabled_reason if semantic_interaction_member else base_disabled_reason,
			"action_authority_valid": action_authority_valid,
			"authority_branch": "semantic" if semantic_interaction_member else ("base_record" if not base_record.is_empty() else "none"),
			"sealed_geometry_valid": sealed_geometry_valid,
			"semantic_reachable": semantic_reachable,
			"base_reachable": base_reachable,
			"reachable": reachable,
			"reachability_basis": reachability_basis,
			"actionable": actionable,
		})
	var renderer := _copy_dict(environment.get("scenario_render_snapshot", {}))
	return {
		"scenario_id": str(environment.get("scenario_id", "")),
		"status": str(projection.get("status", state.get("status", ""))),
		"node_id": str(projection.get("node_id", state.get("node_id", state_semantic.get("node_id", "")))),
		"phase_id": str(projection.get("phase_id", state.get("phase_id", state_semantic.get("phase_id", "")))),
		"semantic_ready": bool(environment.get("scenario_semantic_ready", false)),
		"live_semantic_ready": live_semantic_ready,
		"semantic_digest": str(environment.get("scenario_semantic_digest", "")),
		"semantic_action_digest": str(environment.get("scenario_semantic_action_digest", "")),
		"semantic_inventory_version": int(environment.get("scenario_semantic_inventory_version", 0)),
		"state_error_count": _copy_array(state.get("errors", [])).size(),
		"semantic_error_count": _copy_array(semantic.get("errors", [])).size(),
		"authority_digest": authority_digest,
		"authority_count": authority.size(),
		"authority_identities": authority_identities,
		"authority_receipts": authority_receipts,
		"action_authority_member_count": action_authority_member_count,
		"actionable_authority_count": actionable_authority_count,
		"invalid_action_authority_count": invalid_action_authority_count,
		"action_authority_contract_valid": invalid_action_authority_count == 0,
		"layout_audit_active": bool(audit.get("active", false)),
		"layout_audit_valid": bool(audit.get("valid", false)),
		"layout_audit_sealed_passive": bool(audit.get("sealed_passive", false)),
		"layout_audit_field_count": audit.size(),
		"layout_audit_authority_count": int(audit.get("authority_count", 0)),
		"layout_audit_authority_digest": str(audit.get("authority_digest", "")),
		"authority_count_matches_audit": authority.size() == int(audit.get("authority_count", 0)),
		"authority_digest_matches_audit": authority_digest == str(audit.get("authority_digest", "")),
		"renderer_ok": bool(renderer.get("ok", false)),
		"renderer_field_count": renderer.size(),
		"renderer_error_count": _copy_array(renderer.get("errors", [])).size(),
		"renderer_presentation_mode": str(renderer.get("presentation_mode", "")),
		"renderer_authority_digest": str(renderer.get("layout_authority_digest", "")),
		"renderer_digest_matches_authority": str(renderer.get("layout_authority_digest", "")) == authority_digest,
		"reachable_interaction_ids": reachable_interaction_ids,
		"safe_exit_ids": _string_array(audit.get("safe_exit_ids", [])),
		"alternate_exit_ids": _string_array(audit.get("alternate_exit_ids", [])),
	}


func _enabled_action_ids(record: Dictionary) -> Array:
	var result: Array = []
	for action_value in _copy_array(record.get("available_actions", [])):
		if typeof(action_value) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = action_value
		var action_id := str(action.get("id", "")).strip_edges()
		if not action_id.is_empty() and bool(action.get("enabled", true)):
			result.append(action_id)
	result.sort()
	return result


func _serialized_rect_has_positive_area(rect: Dictionary) -> bool:
	for key in ["x", "y", "w", "h"]:
		if not rect.has(key) or typeof(rect.get(key)) not in [TYPE_INT, TYPE_FLOAT]:
			return false
	var x := float(rect.get("x", -1.0))
	var y := float(rect.get("y", -1.0))
	var width := float(rect.get("w", 0.0))
	var height := float(rect.get("h", 0.0))
	return is_finite(x) and is_finite(y) and is_finite(width) and is_finite(height) \
		and x >= 0.0 and y >= 0.0 and width > 0.0 and height > 0.0 \
		and x + width <= 1.00001 and y + height <= 1.00001


func _native_diagnostic_totals() -> Dictionary:
	var totals := {
		"receipt_count": 0,
		"receipt_missing_count": 0,
		"receipt_invalid_count": 0,
		"arrival_ok_invalid_count": 0,
		"travel_ok_invalid_count": 0,
		"arrival_stage_invalid_count": 0,
		"arrival_error_count": 0,
		"travel_error_count": 0,
		"finalization_warning_count": 0,
		"finalization_error_count": 0,
		"scenario_state_error_count": 0,
		"semantic_error_count": 0,
		"renderer_error_count": 0,
		"arrival_contract_invalid_count": 0,
		"travel_contract_invalid_count": 0,
		"finalization_contract_invalid_count": 0,
		"runtime_layout_invalid_count": 0,
		"layout_audit_invalid_count": 0,
		"action_authority_invalid_count": 0,
		"installed_invalid_count": 0,
		"source_binding_invalid_count": 0,
		"target_binding_invalid_count": 0,
		"current_install_binding_invalid_count": 0,
		"travel_install_binding_invalid_count": 0,
		"production_boundary_invalid_count": 0,
		"projection_binding_invalid_count": 0,
		"installed_live_projection_binding_invalid_count": 0,
		"travel_projection_binding_invalid_count": 0,
		"finalization_projection_binding_invalid_count": 0,
		"independent_projection_binding_invalid_count": 0,
		"finalization_runtime_invalid_count": 0,
		"finalization_clean_invalid_count": 0,
		"seed_binding_invalid_count": 0,
		"attempt_binding_invalid_count": 0,
	}
	# Count the unique native receipt stream. Failed initial arrivals never append
	# an environment record, and failed travel arrivals live only on travel_records;
	# walking successful records alone would make those diagnostics disappear.
	var receipts: Array = []
	for summary_value in run_summaries:
		if typeof(summary_value) != TYPE_DICTIONARY:
			totals["receipt_missing_count"] = int(totals.get("receipt_missing_count", 0)) + 1
			continue
		var initial_receipt := _copy_dict((summary_value as Dictionary).get("initial_arrival_receipt", {}))
		if initial_receipt.is_empty():
			totals["receipt_missing_count"] = int(totals.get("receipt_missing_count", 0)) + 1
		else:
			receipts.append(initial_receipt)
	for travel_value in travel_records:
		if typeof(travel_value) != TYPE_DICTIONARY:
			totals["receipt_missing_count"] = int(totals.get("receipt_missing_count", 0)) + 1
			continue
		var travel_receipt := _copy_dict((travel_value as Dictionary).get("arrival_receipt", {}))
		if travel_receipt.is_empty():
			totals["receipt_missing_count"] = int(totals.get("receipt_missing_count", 0)) + 1
		else:
			receipts.append(travel_receipt)
	totals["receipt_count"] = receipts.size()
	for receipt_value in receipts:
		var arrival := _copy_dict(receipt_value)
		var finalization := _copy_dict(arrival.get("finalization", {}))
		var runtime_layout := _copy_dict(arrival.get("runtime_scenario_layout", {}))
		totals["arrival_error_count"] = int(totals.get("arrival_error_count", 0)) + int(arrival.get("arrival_error_count", 0))
		totals["travel_error_count"] = int(totals.get("travel_error_count", 0)) + int(arrival.get("travel_error_count", 0))
		totals["finalization_warning_count"] = int(totals.get("finalization_warning_count", 0)) + int(finalization.get("warning_count", 0))
		totals["finalization_error_count"] = int(totals.get("finalization_error_count", 0)) + int(finalization.get("error_count", 0))
		totals["scenario_state_error_count"] = int(totals.get("scenario_state_error_count", 0)) + int(runtime_layout.get("state_error_count", 0))
		totals["semantic_error_count"] = int(totals.get("semantic_error_count", 0)) + int(runtime_layout.get("semantic_error_count", 0))
		totals["renderer_error_count"] = int(totals.get("renderer_error_count", 0)) + int(runtime_layout.get("renderer_error_count", 0))
		totals["action_authority_invalid_count"] = int(totals.get("action_authority_invalid_count", 0)) + int(runtime_layout.get("invalid_action_authority_count", 0))
		if not bool(arrival.get("arrival_contract_shape_valid", false)):
			totals["arrival_contract_invalid_count"] = int(totals.get("arrival_contract_invalid_count", 0)) + 1
		if not bool(arrival.get("travel_contract_shape_valid", false)):
			totals["travel_contract_invalid_count"] = int(totals.get("travel_contract_invalid_count", 0)) + 1
		if not bool(finalization.get("contract_shape_valid", false)):
			totals["finalization_contract_invalid_count"] = int(totals.get("finalization_contract_invalid_count", 0)) + 1
		if not bool(arrival.get("runtime_layout_valid", false)):
			totals["runtime_layout_invalid_count"] = int(totals.get("runtime_layout_invalid_count", 0)) + 1
		if not bool(finalization.get("inactive", false)) and not bool(runtime_layout.get("layout_audit_valid", false)):
			totals["layout_audit_invalid_count"] = int(totals.get("layout_audit_invalid_count", 0)) + 1
		if not bool(arrival.get("installed_finalized", false)):
			totals["receipt_invalid_count"] = int(totals.get("receipt_invalid_count", 0)) + 1
		if not bool(arrival.get("ok", false)):
			totals["arrival_ok_invalid_count"] = int(totals.get("arrival_ok_invalid_count", 0)) + 1
		if not bool(arrival.get("travel_ok", false)):
			totals["travel_ok_invalid_count"] = int(totals.get("travel_ok_invalid_count", 0)) + 1
		if str(arrival.get("stage", "")) != "complete":
			totals["arrival_stage_invalid_count"] = int(totals.get("arrival_stage_invalid_count", 0)) + 1
		if not bool(arrival.get("installed", false)):
			totals["installed_invalid_count"] = int(totals.get("installed_invalid_count", 0)) + 1
		for binding_value in [
			["source_binding_valid", "source_binding_invalid_count"],
			["target_binding_valid", "target_binding_invalid_count"],
			["current_install_binding_valid", "current_install_binding_invalid_count"],
			["travel_install_binding_valid", "travel_install_binding_invalid_count"],
			["production_boundary_valid", "production_boundary_invalid_count"],
			["projection_binding_valid", "projection_binding_invalid_count"],
			["installed_live_projection_binding_valid", "installed_live_projection_binding_invalid_count"],
			["travel_projection_binding_valid", "travel_projection_binding_invalid_count"],
			["finalization_projection_binding_valid", "finalization_projection_binding_invalid_count"],
			["independent_projection_binding_valid", "independent_projection_binding_invalid_count"],
			["finalization_matches_runtime", "finalization_runtime_invalid_count"],
			["finalization_clean", "finalization_clean_invalid_count"],
			["seed_binding_valid", "seed_binding_invalid_count"],
		]:
			var binding := binding_value as Array
			if not bool(arrival.get(str(binding[0]), false)):
				var count_key := str(binding[1])
				totals[count_key] = int(totals.get(count_key, 0)) + 1
		if bool(arrival.get("attempt_id_required", false)) and str(arrival.get("attempt_id", "")).is_empty():
			totals["attempt_binding_invalid_count"] = int(totals.get("attempt_binding_invalid_count", 0)) + 1
	var warning_count := int(totals.get("finalization_warning_count", 0))
	var failure_count := 0
	for key_value in totals.keys():
		var key := str(key_value)
		if key not in ["receipt_count", "finalization_warning_count"]:
			failure_count += int(totals.get(key, 0))
	totals["warning_count"] = warning_count
	totals["failure_count"] = failure_count
	totals["clean"] = warning_count == 0 and failure_count == 0
	return totals


func _finalize_run_evidence(run_summary: Dictionary, visits_per_run: int) -> void:
	var run_index := int(run_summary.get("run_index", -1))
	var visit_records: Array = []
	var visit_by_index: Dictionary = {}
	var visit_indices: Array = []
	var installed_finalized_visit_count := 0
	var identity_bound_visit_count := 0
	var post_event_seed_binding_count := 0
	var terminal_visit_count := 0
	for record_value in records:
		if typeof(record_value) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = record_value
		if int(record.get("run_index", -2)) != run_index:
			continue
		visit_records.append(record)
		var visit_index := int(record.get("visit_index", -1))
		visit_indices.append(visit_index)
		visit_by_index[visit_index] = record
		if bool(record.get("installed_finalized", false)):
			installed_finalized_visit_count += 1
		if _run_identity_tuple_matches(record, run_summary):
			identity_bound_visit_count += 1
		if _run_identity_tuple_matches(_copy_dict(record.get("seed_binding_after_event_policy", {})), run_summary):
			post_event_seed_binding_count += 1
		if bool(record.get("terminal_after_event_policy", false)):
			terminal_visit_count += 1
	var run_travel_records: Array = []
	var travel_indices: Array = []
	var successful_linked_travel_count := 0
	for global_index in range(travel_records.size()):
		if typeof(travel_records[global_index]) != TYPE_DICTIONARY:
			continue
		var travel: Dictionary = travel_records[global_index]
		if int(travel.get("run_index", -2)) != run_index:
			continue
		run_travel_records.append(travel)
		travel_indices.append(int(travel.get("travel_index", -1)))
		var source_visit_index := int(travel.get("from_visit_index", -1))
		var destination_visit_index := int(travel.get("to_visit_index", -1))
		var source_record := _copy_dict(visit_by_index.get(source_visit_index, {}))
		var destination_record := _copy_dict(visit_by_index.get(destination_visit_index, {}))
		var arrival_receipt := _copy_dict(travel.get("arrival_receipt", {}))
		var source_world_node_id := str(source_record.get("world_node_id", ""))
		var destination_world_node_id := str(destination_record.get("world_node_id", ""))
		var linked := bool(travel.get("ok", false)) \
			and destination_visit_index == source_visit_index + 1 \
			and not source_record.is_empty() \
			and not destination_record.is_empty() \
			and _run_identity_tuple_matches(travel, run_summary) \
			and _run_identity_tuple_matches(source_record, run_summary) \
			and _run_identity_tuple_matches(destination_record, run_summary) \
			and _run_identity_tuple_matches(arrival_receipt, run_summary) \
			and str(travel.get("from_environment_id", "")) == str(source_record.get("environment_id", "")) \
			and str(travel.get("to_environment_id", "")) == str(destination_record.get("environment_id", "")) \
			and str(travel.get("to_archetype_id", "")) == str(destination_record.get("archetype_id", "")) \
			and not source_world_node_id.is_empty() \
			and not destination_world_node_id.is_empty() \
			and str(travel.get("source_id", "")) == source_world_node_id \
			and str(travel.get("from_world_node_id", "")) == source_world_node_id \
			and str(travel.get("target_id", "")) == destination_world_node_id \
			and str(travel.get("to_world_node_id", "")) == destination_world_node_id \
			and str(arrival_receipt.get("source_id", "")) == source_world_node_id \
			and str(arrival_receipt.get("travel_source_id", "")) == source_world_node_id \
			and str(arrival_receipt.get("target_id", "")) == destination_world_node_id \
			and str(arrival_receipt.get("travel_target_id", "")) == destination_world_node_id \
			and str(arrival_receipt.get("installed_world_node_id", "")) == destination_world_node_id \
			and str(arrival_receipt.get("installed_environment_id", "")) == str(destination_record.get("environment_id", "")) \
			and str(arrival_receipt.get("installed_archetype_id", "")) == str(destination_record.get("archetype_id", "")) \
			and str(arrival_receipt.get("installed_scenario_id", "")) == str(destination_record.get("scenario_id", "")) \
			and str(arrival_receipt.get("kind", "")) == "travel" \
			and int(arrival_receipt.get("travel_index", -1)) == int(travel.get("travel_index", -2)) \
			and int(arrival_receipt.get("from_visit_index", -1)) == source_visit_index \
			and int(arrival_receipt.get("visit_index", -1)) == destination_visit_index \
			and bool(arrival_receipt.get("source_binding_valid", false)) \
			and bool(arrival_receipt.get("target_binding_valid", false)) \
			and bool(arrival_receipt.get("current_install_binding_valid", false)) \
			and bool(arrival_receipt.get("production_boundary_valid", false)) \
			and bool(arrival_receipt.get("installed_finalized", false))
		travel["linked_to_recorded_visits"] = linked
		travel_records[global_index] = travel
		if linked:
			successful_linked_travel_count += 1
	var requested_travel_count := maxi(0, visits_per_run - 1)
	var contiguous_visits := _indices_are_contiguous(visit_indices, visits_per_run)
	var contiguous_travels := _indices_are_contiguous(travel_indices, requested_travel_count)
	var visited_summaries := _copy_array(run_summary.get("visited", []))
	var bound_visited_summary_count := 0
	for visited_value in visited_summaries:
		if typeof(visited_value) != TYPE_DICTIONARY:
			continue
		var visited_summary: Dictionary = visited_value
		var visit_index := int(visited_summary.get("visit_index", -1))
		var full_record := _copy_dict(visit_by_index.get(visit_index, {}))
		if _run_identity_tuple_matches(visited_summary, run_summary) \
				and not full_record.is_empty() \
				and str(visited_summary.get("environment_id", "")) == str(full_record.get("environment_id", "")) \
				and str(visited_summary.get("world_node_id", "")) == str(full_record.get("world_node_id", "")) \
				and str(visited_summary.get("scenario_id", "")) == str(full_record.get("scenario_id", "")):
			bound_visited_summary_count += 1
	var seed_binding_satisfied := bool(run_summary.get("seed_binding_valid", false)) \
		and str(run_summary.get("requested_seed_text", "")) == str(run_summary.get("seed_text", "")) \
		and int(run_summary.get("seed_value", 0)) == int(run_summary.get("derived_seed_value", -1)) \
		and int(run_summary.get("seed_value", 0)) == int(run_summary.get("expected_seed_value", -2)) \
		and str(run_summary.get("challenge_key", "")) == str(run_summary.get("expected_challenge_key", ""))
	var final_seed_binding := _copy_dict(run_summary.get("final_seed_binding", {}))
	var final_seed_binding_satisfied := bool(run_summary.get("final_seed_binding_valid", false)) \
		and _run_identity_tuple_matches(final_seed_binding, run_summary)
	var attempt_binding_satisfied := not bool(run_summary.get("attempt_id_required", false)) \
		or not str(run_summary.get("attempt_id", "")).is_empty()
	var initial_arrival_receipt := _copy_dict(run_summary.get("initial_arrival_receipt", {}))
	run_summary["environment_count"] = visit_records.size()
	run_summary["travel_record_count"] = run_travel_records.size()
	run_summary["visit_indices"] = visit_indices
	run_summary["travel_indices"] = travel_indices
	run_summary["installed_finalized_visit_count"] = installed_finalized_visit_count
	run_summary["identity_bound_visit_count"] = identity_bound_visit_count
	run_summary["post_event_seed_binding_count"] = post_event_seed_binding_count
	run_summary["identity_bound_visited_summary_count"] = bound_visited_summary_count
	run_summary["terminal_visit_count"] = terminal_visit_count
	run_summary["successful_linked_travel_count"] = successful_linked_travel_count
	run_summary["contiguous_visit_indices"] = contiguous_visits
	run_summary["contiguous_travel_indices"] = contiguous_travels
	run_summary["seed_binding_satisfied"] = seed_binding_satisfied
	run_summary["final_seed_binding_satisfied"] = final_seed_binding_satisfied
	run_summary["attempt_binding_satisfied"] = attempt_binding_satisfied
	run_summary["requested_visits_satisfied"] = str(run_summary.get("stopped_reason", "")) == "completed" \
		and seed_binding_satisfied \
		and final_seed_binding_satisfied \
		and attempt_binding_satisfied \
		and bool(run_summary.get("crew_state_unchanged", false)) \
		and visit_records.size() == visits_per_run \
		and installed_finalized_visit_count == visits_per_run \
		and identity_bound_visit_count == visits_per_run \
		and post_event_seed_binding_count == visits_per_run \
		and visited_summaries.size() == visits_per_run \
		and bound_visited_summary_count == visits_per_run \
		and terminal_visit_count == 0 \
		and run_travel_records.size() == requested_travel_count \
		and int(run_summary.get("travel_count", 0)) == requested_travel_count \
		and successful_linked_travel_count == requested_travel_count \
		and contiguous_visits \
		and contiguous_travels \
		and _run_identity_tuple_matches(initial_arrival_receipt, run_summary) \
		and bool(initial_arrival_receipt.get("installed_finalized", false))


func _run_identity_tuple_matches(evidence: Dictionary, run_summary: Dictionary) -> bool:
	if evidence.is_empty() or not bool(evidence.get("seed_binding_valid", false)):
		return false
	var attempt_required := bool(run_summary.get("attempt_id_required", false))
	var expected_attempt := str(run_summary.get("attempt_id", ""))
	return (not attempt_required or not expected_attempt.is_empty()) \
		and str(evidence.get("attempt_id", "")) == expected_attempt \
		and str(evidence.get("requested_seed_text", "")) == str(run_summary.get("requested_seed_text", "")) \
		and str(evidence.get("seed_text", "")) == str(run_summary.get("seed_text", "")) \
		and int(evidence.get("seed_value", 0)) == int(run_summary.get("seed_value", -1)) \
		and int(evidence.get("derived_seed_value", 0)) == int(run_summary.get("derived_seed_value", -1)) \
		and str(evidence.get("challenge_key", "")) == str(run_summary.get("challenge_key", "")) \
		and str(evidence.get("challenge_id", "")) == str(run_summary.get("challenge_id", "")) \
		and str(evidence.get("challenge_mode", "")) == str(run_summary.get("challenge_mode", ""))


func _indices_are_contiguous(indices: Array, expected_count: int) -> bool:
	if indices.size() != expected_count:
		return false
	for index in range(expected_count):
		if int(indices[index]) != index:
			return false
	return true


func _audit_world_map_beach_delta(map_data: Dictionary, seed: String) -> void:
	if map_data.is_empty():
		return
	var beach := WorldMapScript.node_by_id(map_data, "beach")
	var delta := WorldMapScript.node_by_id(map_data, "delta_queen")
	if beach.is_empty() or delta.is_empty():
		failures.append("%s: generated world map is missing beach or delta_queen." % seed)
		return
	var edge := _world_map_edge_between(map_data, "beach", "delta_queen")
	if edge.is_empty():
		failures.append("%s: beach must have a direct edge to delta_queen." % seed)
		return
	if int(edge.get("distance_blocks", 0)) != 1:
		failures.append("%s: beach edge to delta_queen must be 1 block, got %d." % [seed, int(edge.get("distance_blocks", 0))])
	var beach_edge_count := 0
	for edge_value in _copy_array(map_data.get("edges", [])):
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = edge_value
		if str(candidate.get("a", "")) == "beach" or str(candidate.get("b", "")) == "beach":
			beach_edge_count += 1
	if beach_edge_count != 1:
		failures.append("%s: beach must only connect to delta_queen, saw %d beach edges." % [seed, beach_edge_count])


func _world_map_edge_between(map_data: Dictionary, a: String, b: String) -> Dictionary:
	for edge_value in _copy_array(map_data.get("edges", [])):
		if typeof(edge_value) != TYPE_DICTIONARY:
			continue
		var edge: Dictionary = edge_value
		var left := str(edge.get("a", "")).strip_edges()
		var right := str(edge.get("b", "")).strip_edges()
		if (left == a and right == b) or (left == b and right == a):
			return edge
	return {}


func _audit_environment_unique_object_classes(environment: Dictionary, seed: String, visit_index: int) -> void:
	var class_by_object_id := _unique_class_by_layout_object_id(environment)
	if class_by_object_id.is_empty():
		return
	var layout := _copy_dict(environment.get("layout", {}))
	var object_rects := _copy_dict(layout.get("object_rects", {}))
	var seen_classes: Dictionary = {}
	for object_id_value in object_rects.keys():
		var object_id := str(object_id_value)
		var unique_class := str(class_by_object_id.get(object_id, "")).strip_edges()
		if unique_class.is_empty():
			continue
		if seen_classes.has(unique_class):
			failures.append("%s visit %d %s: duplicate unique object class %s from %s and %s." % [
				seed,
				visit_index,
				str(environment.get("archetype_id", environment.get("id", ""))),
				unique_class,
				str(seen_classes.get(unique_class, "")),
				object_id,
			])
			return
		seen_classes[unique_class] = object_id


func _unique_class_by_layout_object_id(environment: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for event_id in _string_array(environment.get("event_ids", [])):
		var event_definition := library.event(event_id)
		var unique_class := str(event_definition.get("unique_object_class", "")).strip_edges()
		if not unique_class.is_empty() and not bool(event_definition.get("allow_duplicate_unique_class", false)):
			result["event:%s" % event_id] = unique_class
	var game_states := _copy_dict(environment.get("game_states", {}))
	for game_id in _string_array(environment.get("game_ids", [])):
		var machine := _copy_dict(game_states.get(game_id, {}))
		for hook_value in _copy_array(machine.get("environment_hooks", [])):
			if typeof(hook_value) != TYPE_DICTIONARY:
				continue
			var hook: Dictionary = hook_value
			var unique_class := str(hook.get("unique_object_class", "")).strip_edges()
			if unique_class.is_empty() or bool(hook.get("allow_duplicate_unique_class", false)):
				continue
			var object_id := str(hook.get("object_id", "")).strip_edges()
			if object_id.is_empty():
				var dialogue_id := str(hook.get("dialogue_id", "")).strip_edges()
				object_id = "dialogue:%s" % dialogue_id if not dialogue_id.is_empty() else "game_hook:%s:%s" % [game_id, str(hook.get("id", ""))]
			result[object_id] = unique_class
	return result


func _summarize_game_state(game_id: String, state: Dictionary) -> Dictionary:
	var summary := {
		"present": not state.is_empty(),
		# Count only. Field names can disclose hidden turn, draw, traitor, rigging,
		# or ticket-order state even when their values are omitted.
		"state_key_count": state.size(),
	}
	match game_id:
		"blackjack":
			var side_bets := []
			for side_bet in _copy_array(state.get("side_bets", [])):
				if typeof(side_bet) == TYPE_DICTIONARY:
					side_bets.append(str((side_bet as Dictionary).get("id", "")))
			summary["table_name"] = str(state.get("table_name", ""))
			summary["dealer_name"] = str(state.get("dealer_name", ""))
			summary["deck_count"] = int(state.get("deck_count", 0))
			summary["shoe_remaining"] = int(state.get("shoe_remaining", 0))
			summary["side_bets"] = side_bets
			summary["side_bet_count"] = side_bets.size()
			summary["patron_count"] = _copy_array(state.get("patrons", [])).size()
			summary["rule_field_count"] = _copy_dict(state.get("rules", {})).size()
		"pull_tabs":
			var deals := _copy_array(state.get("deals", []))
			var deal_summaries := []
			var total_remaining := 0
			var prices := []
			for index in range(deals.size()):
				if typeof(deals[index]) != TYPE_DICTIONARY:
					continue
				var deal: Dictionary = deals[index]
				total_remaining += int(deal.get("remaining", 0))
				prices.append(int(deal.get("price", 0)))
				deal_summaries.append({
					"index": index,
					"id": str(deal.get("id", "")),
					"display_name": str(deal.get("display_name", "")),
					"price": int(deal.get("price", 0)),
					"ticket_count": int(deal.get("ticket_count", 0)),
					"remaining": int(deal.get("remaining", 0)),
					"initial_removed_count": int(deal.get("initial_removed_count", 0)),
					"prize_count": _copy_array(deal.get("prizes", [])).size(),
				})
			var item_state := _copy_dict(state.get("item_state", {}))
			summary["deal_count"] = deals.size()
			summary["total_remaining"] = total_remaining
			summary["column_prices"] = prices
			summary["deals"] = deal_summaries
			summary["xray_target_count"] = _copy_array(item_state.get("xray_targets", [])).size()
		"slot":
			summary["machine_name"] = str(state.get("machine_name", state.get("name", "")))
			summary["jackpot_current"] = int(state.get("jackpot_current", 0))
			summary["jackpot_base"] = int(state.get("jackpot_base", 0))
			summary["bumper_goal"] = int(state.get("bumper_goal", 0))
			summary["reel_count"] = _copy_array(state.get("reels", [])).size()
		_:
			summary["schema"] = str(state.get("schema", ""))
	return summary


func _event_trigger_status(run_state: RunState) -> Array:
	var result: Array = []
	for event_id in _string_array(run_state.current_environment.get("event_ids", [])):
		var definition := library.event(event_id)
		if definition.is_empty():
			continue
		var module := EventModule.new()
		module.setup(definition)
		result.append({
			"id": event_id,
			"display_name": str(definition.get("display_name", event_id)),
			"trigger": _copy_dict(definition.get("trigger", {"type": "manual"})),
			"manual_now": module.can_trigger(run_state, run_state.current_environment),
			"timed_after_two_turns": module.can_trigger(run_state, run_state.current_environment, {"turns": 2}),
			"travel_trigger": module.can_trigger(run_state, run_state.current_environment, {"trigger": "travel"}),
		})
	return result


func _resolve_travel_unlock_events(run_state: RunState, path_rng: RngStream) -> Array:
	var resolved: Array = []
	for _pass_index in range(6):
		var enabled_travel := _enabled_travel_choices(run_state)
		var allow_bankroll_help := enabled_travel.is_empty()
		var candidate := _best_event_choice(run_state, allow_bankroll_help)
		if candidate.is_empty():
			break
		var event_id := str(candidate.get("event_id", ""))
		var choice_id := str(candidate.get("choice_id", ""))
		var definition := library.event(event_id)
		if definition.is_empty():
			break
		var module := EventModule.new()
		module.setup(definition)
		if not module.can_trigger(run_state, run_state.current_environment):
			break
		var before_next := _string_array(run_state.current_environment.get("next_archetypes", []))
		var before_bankroll := run_state.bankroll
		var before_heat := run_state.suspicion_level()
		var result := module.resolve(run_state, run_state.current_environment, choice_id)
		resolved.append({
			"event_id": event_id,
			"choice_id": choice_id,
			"reason": str(candidate.get("reason", "")),
			"score": int(candidate.get("score", 0)),
			"bankroll_before": before_bankroll,
			"bankroll_after": run_state.bankroll,
			"suspicion_before": before_heat,
			"suspicion_after": run_state.suspicion_level(),
			"next_archetypes_before": before_next,
			"next_archetypes_after": _string_array(run_state.current_environment.get("next_archetypes", [])),
			"message": str(result.get("message", "")),
		})
		if run_state.is_terminal() or path_rng == null:
			break
	return resolved


func _best_event_choice(run_state: RunState, allow_bankroll_help: bool) -> Dictionary:
	var best := {}
	for event_id in _string_array(run_state.current_environment.get("event_ids", [])):
		var definition := library.event(event_id)
		if definition.is_empty():
			continue
		var module := EventModule.new()
		module.setup(definition)
		if not module.can_trigger(run_state, run_state.current_environment):
			continue
		for choice in module.choices():
			if typeof(choice) != TYPE_DICTIONARY:
				continue
			var choice_data: Dictionary = choice
			var score_data := _event_choice_score(run_state, choice_data, allow_bankroll_help)
			var score := int(score_data.get("score", 0))
			if score <= 0:
				continue
			if best.is_empty() or score > int(best.get("score", 0)):
				best = {
					"event_id": event_id,
					"choice_id": str(choice_data.get("id", "")),
					"score": score,
					"reason": str(score_data.get("reason", "")),
				}
	return best


func _event_choice_score(run_state: RunState, choice: Dictionary, allow_bankroll_help: bool) -> Dictionary:
	var consequences := _copy_dict(choice.get("consequences", {}))
	var current_targets := _travel_target_ids(run_state)
	var route_targets := _route_targets_from_consequences(consequences)
	var score := 0
	var reasons: Array = []
	var new_target_count := 0
	for target in route_targets:
		if not current_targets.has(target):
			new_target_count += 1
	if new_target_count > 0:
		score += 40 + new_target_count * 15
		reasons.append("adds %d new route target(s)" % new_target_count)
	elif not route_targets.is_empty():
		score += 12
		reasons.append("refreshes route choices")
	var flags := _copy_dict(consequences.get("flags", consequences.get("flags_set", {})))
	for key in flags.keys():
		if str(key) == "underground_tip" and bool(flags[key]) and not bool(run_state.narrative_flags.get("underground_tip", false)):
			score += 65
			reasons.append("unlocks underground route condition")
		if str(key) == "grand_casino_invite" and bool(flags[key]) and not bool(run_state.narrative_flags.get("grand_casino_invite", false)):
			score += 90
			reasons.append("unlocks Grand Casino route condition")
	if allow_bankroll_help and int(consequences.get("bankroll_delta", 0)) > 0:
		score += int(consequences.get("bankroll_delta", 0))
		reasons.append("restores travel bankroll")
	if score > 0 and int(consequences.get("suspicion_delta", 0)) <= 0:
		score += 3
	return {"score": score, "reason": "; ".join(reasons)}


func _route_targets_from_consequences(consequences: Dictionary) -> Array:
	var targets: Array = []
	for id in _string_array(consequences.get("travel_hooks_add", [])):
		if not targets.has(id):
			targets.append(id)
	for id in _string_array(consequences.get("set_next_archetypes", [])):
		if not targets.has(id):
			targets.append(id)
	for id in _string_array(consequences.get("add_next_archetypes", [])):
		if not targets.has(id):
			targets.append(id)
	var travel_changes := _copy_dict(consequences.get("travel_changes", {}))
	for id in _string_array(travel_changes.get("set_next_archetypes", [])):
		if not targets.has(id):
			targets.append(id)
	for id in _string_array(travel_changes.get("add_next_archetypes", [])):
		if not targets.has(id):
			targets.append(id)
	return targets


func _pick_travel_choice(run_state: RunState, path_rng: RngStream) -> Dictionary:
	var enabled := _enabled_travel_choices(run_state)
	if enabled.is_empty():
		return {}
	var grand_choices: Array = []
	for choice in enabled:
		if str((choice as Dictionary).get("id", "")) == "grand_casino":
			grand_choices.append(choice)
	if not grand_choices.is_empty():
		return (grand_choices[0] as Dictionary).duplicate(true)
	return (enabled[path_rng.randi_range(0, enabled.size() - 1)] as Dictionary).duplicate(true)


func _enabled_travel_choices(run_state: RunState) -> Array:
	var enabled: Array = []
	for choice in _travel_choices(run_state, false):
		if bool((choice as Dictionary).get("enabled", false)):
			enabled.append(choice)
	return enabled


func _travel_choices(run_state: RunState, include_hidden: bool) -> Array:
	var choices: Array = []
	var target_ids := _travel_target_ids(run_state)
	var production_host := _production_foundation_travel_host(run_state)
	for target_id in target_ids:
		var production_choice: Dictionary = production_host._travel_choice(str(target_id), target_ids)
		if production_choice.is_empty():
			var missing_message := "Production travel view omitted admitted target %s at %s." % [
				str(target_id), run_state.current_world_node_id()
			]
			if not failures.has(missing_message):
				failures.append(missing_message)
			continue
		if bool(production_choice.get("hidden", false)) and not include_hidden:
			continue
		var choice := {
			"id": str(production_choice.get("id", target_id)),
			"label": str(production_choice.get("label", target_id)),
			"kind": str(production_choice.get("kind", "")),
			"tier": int(production_choice.get("tier", 1)),
			"enabled": bool(production_choice.get("enabled", false)),
			"hidden": false,
			"disabled_reason": str(production_choice.get("disabled_reason", "")),
			"cost": int(production_choice.get("cost", 0)),
			"risk": str(production_choice.get("risk", "")),
			"distance": str(production_choice.get("distance", "")),
			"risk_decay": int(production_choice.get("risk_decay", 0)),
			"suspicion_delta": int(production_choice.get("suspicion_delta", 0)),
			"risk_text": str(production_choice.get("risk_text", "")),
			"risk_event": _copy_dict(production_choice.get("risk_event", {})),
			"unlock_conditions": _copy_array(production_choice.get("unlock_conditions", [])),
			"travel_lock_remaining": int(production_choice.get("travel_lock_remaining", 0)),
			"availability_turn": int(production_choice.get("availability_turn", -1)),
		}
		choices.append(choice)
	return choices


func _current_travel_lock_remaining(run_state: RunState) -> int:
	if run_state == null or run_state.current_environment.is_empty():
		return 0
	return maxi(0, int(run_state.current_environment.get("travel_lock_remaining", 0)))


func _travel_to(
	run_state: RunState,
	choice: Dictionary,
	travel_index: int,
	from_visit_index: int,
	to_visit_index: int,
	attempt_id: String,
	seed_binding: Dictionary
) -> Dictionary:
	var target_id := str(choice.get("id", ""))
	var source_id := run_state.current_world_node_id()
	var admitted_targets_before := _travel_target_ids(run_state)
	var route := generator.world_route_for_target(run_state, target_id)
	var previous_environment := run_state.current_environment.duplicate(true)
	var previous_bankroll := run_state.bankroll
	var previous_heat := run_state.suspicion_level()
	var route_risk := run_state.travel_route_risk(route, target_id)
	var travel_heat := run_state.begin_travel_suspicion_decay(route, target_id)
	var admitted_targets_after_heat := _travel_target_ids(run_state)
	var arrival := HarnessProductionFidelityScript.travel_and_finalize(
		# This choice came from the same capped route catalog and availability
		# checks as production. The UI likewise passes a prevalidated destination
		# after advancing its travel clock, so revalidating here would test a
		# different time boundary and can reject a route the player was offered.
		generator, run_state, target_id, true, library, failures,
		"environment-generation travel to %s" % target_id
	)
	var travel_projection_rebuild := _independent_live_projection_binding(run_state)
	var arrival_receipt := _arrival_receipt(
		arrival, run_state.current_environment, "travel", to_visit_index, travel_index, from_visit_index,
		attempt_id, seed_binding, run_state._scenario_semantic_ready(), travel_projection_rebuild
	)
	if not bool(arrival.get("ok", false)):
		var target_node := WorldMapScript.node_by_id(run_state.world_map, target_id)
		return {
			"ok": false,
			"travel_index": travel_index,
			"from_visit_index": from_visit_index,
			"to_visit_index": to_visit_index,
			"source_id": source_id,
			"target_id": target_id,
			"arrival_receipt": arrival_receipt,
			"finalization_receipt": _copy_dict(arrival_receipt.get("finalization", {})),
			"admitted_targets_before": admitted_targets_before,
			"admitted_targets_after_heat": admitted_targets_after_heat,
			"admitted_targets_before_digest": _json_sha256(admitted_targets_before),
			"admitted_targets_after_heat_digest": _json_sha256(admitted_targets_after_heat),
			"selected_choice": choice.duplicate(true),
			"selected_choice_digest": _json_sha256(choice),
			"generator_install_errors": generator._last_environment_install_errors.duplicate(true),
			"source_scenario_state": _scenario_state_diagnostic(run_state.current_environment),
			"stored_destination_scenario_state": _scenario_state_diagnostic(_copy_dict(target_node.get("environment", {}))),
		}
	var travel_decay := run_state.finish_travel_suspicion_decay(travel_heat)
	var destination_name := str(run_state.current_environment.get("display_name", target_id))
	var result := _travel_result(run_state, target_id, destination_name, route, previous_environment, run_state.current_environment, travel_decay, route_risk)
	GameModule.apply_result(run_state, result)
	return {
		"ok": true,
		"travel_index": travel_index,
		"from_visit_index": from_visit_index,
		"to_visit_index": to_visit_index,
		"source_id": source_id,
		"target_id": target_id,
		"from_world_node_id": source_id,
		"to_world_node_id": str(run_state.current_world_node_id()),
		"arrival_receipt": arrival_receipt,
		"finalization_receipt": _copy_dict(arrival_receipt.get("finalization", {})),
		"admitted_targets_before": admitted_targets_before,
		"admitted_targets_after_heat": admitted_targets_after_heat,
		"admitted_targets_before_digest": _json_sha256(admitted_targets_before),
		"admitted_targets_after_heat_digest": _json_sha256(admitted_targets_after_heat),
		"selected_choice": choice.duplicate(true),
		"selected_choice_digest": _json_sha256(choice),
		"label": str(choice.get("label", target_id)),
		"from_environment_id": str(previous_environment.get("id", "")),
		"from_archetype_id": str(previous_environment.get("archetype_id", "")),
		"to_environment_id": str(run_state.current_environment.get("id", "")),
		"to_archetype_id": str(run_state.current_environment.get("archetype_id", "")),
		"cost": int(choice.get("cost", 0)),
		"bankroll_before": previous_bankroll,
		"bankroll_after": run_state.bankroll,
		"suspicion_before": previous_heat,
		"suspicion_after": run_state.suspicion_level(),
		"travel_decay": travel_decay,
		"route_risk": route_risk,
		"message": str(result.get("message", "")),
	}


func _scenario_state_diagnostic(environment: Dictionary) -> Dictionary:
	var state := _copy_dict(environment.get("scenario_sequence_state", {}))
	var semantic := _copy_dict(state.get("semantic_state", {}))
	return {
		"environment_id": str(environment.get("id", "")),
		"archetype_id": str(environment.get("archetype_id", "")),
		"scenario_id": str(environment.get("scenario_id", "")),
		"status": str(state.get("status", "")),
		"errors": _copy_array(state.get("errors", [])),
		"cleanup_receipts": _copy_array(state.get("cleanup_receipts", [])),
		"cleanup_receipt_records": _copy_array(state.get("cleanup_receipt_records", [])),
		"cleanup_content_fingerprint": str(state.get("cleanup_content_fingerprint", "")),
		"expiry_boundary_records": _copy_array(state.get("expiry_boundary_records", [])),
		"visit_receipt_records": _copy_array(state.get("visit_receipt_records", [])),
		"fact_receipt_records": _copy_array(state.get("fact_receipt_records", [])),
		"operation_receipt_records": _copy_array(semantic.get("operation_receipt_records", [])),
	}


func _travel_result(run_state: RunState, target_id: String, destination_name: String, route: Dictionary, previous_environment: Dictionary, destination_environment: Dictionary, travel_decay: Dictionary, route_risk: Dictionary) -> Dictionary:
	var route_status := run_state.travel_route_status(route)
	var cost := int(route_status.get("cost", 0))
	var suspicion_delta := int(route_status.get("suspicion_delta", 0))
	var risk_bankroll_delta := int(route_risk.get("bankroll_delta", 0)) if bool(route_risk.get("triggered", false)) else 0
	var risk_suspicion_delta := int(route_risk.get("suspicion_delta", 0)) if bool(route_risk.get("triggered", false)) else 0
	var cooled := int(travel_decay.get("cooled", 0))
	var risk_decay := int(travel_decay.get("risk_decay", route_status.get("risk_decay", 0)))
	var message := "Traveled to %s." % destination_name
	var detail_parts: Array = []
	if cost > 0:
		detail_parts.append("Route cost %d" % cost)
	if cooled > 0:
		detail_parts.append("distance shakes most heat" if risk_decay >= 70 else "distance shakes some heat")
	var drunk_delta := int(travel_decay.get("drunk_delta", 0))
	if drunk_delta < 0:
		detail_parts.append("travel sobers you %+d" % drunk_delta)
	if suspicion_delta > 0:
		detail_parts.append("risk +%d" % suspicion_delta)
	if risk_bankroll_delta != 0 or risk_suspicion_delta != 0:
		var risk_label := str(route_risk.get("label", "route risk"))
		var risk_detail := "%s" % risk_label
		if risk_bankroll_delta != 0:
			risk_detail += " %+d" % risk_bankroll_delta
		if risk_suspicion_delta > 0:
			risk_detail += ", heat +%d" % risk_suspicion_delta
		detail_parts.append(risk_detail)
	if not detail_parts.is_empty():
		message = "%s %s." % [message, ", ".join(detail_parts)]
	var total_bankroll_delta := -cost + risk_bankroll_delta
	var total_suspicion_delta := suspicion_delta + risk_suspicion_delta
	var story_entry := {
		"type": "travel",
		"id": target_id,
		"route_id": target_id,
		"from_environment_id": str(previous_environment.get("id", "")),
		"from_environment_name": str(previous_environment.get("display_name", "")),
		"to_archetype_id": target_id,
		"to_environment_id": str(destination_environment.get("id", "")),
		"to_environment_name": destination_name,
		"bankroll_delta": total_bankroll_delta,
		"route_cost": cost,
		"suspicion_delta": total_suspicion_delta,
		"route_suspicion_delta": suspicion_delta,
		"travel_distance": str(travel_decay.get("distance", route_status.get("distance", ""))),
		"risk_decay": risk_decay,
		"risk_cooled": cooled,
		"route_risk": route_risk.duplicate(true),
		"drunk_delta": drunk_delta,
		"drunk_after": int(travel_decay.get("drunk_after", run_state.drunk_level)),
		"message": message,
	}
	var story_entries: Array = [story_entry]
	if bool(route_risk.get("triggered", false)):
		story_entries.append({
			"type": "travel_risk_event",
			"id": str(route_risk.get("id", "travel_risk")),
			"route_id": target_id,
			"label": str(route_risk.get("label", "Route risk")),
			"roll": int(route_risk.get("roll", 0)),
			"chance_percent": int(route_risk.get("chance_percent", 0)),
			"bankroll_delta": risk_bankroll_delta,
			"suspicion_delta": risk_suspicion_delta,
			"message": str(route_risk.get("message", "The route risk catches you.")),
		})
	var deltas := GameModule.empty_result_deltas()
	deltas["bankroll_delta"] = total_bankroll_delta
	deltas["suspicion_delta"] = total_suspicion_delta
	deltas["story_log"] = story_entries
	deltas["messages"] = [message]
	return GameModule.build_action_result({
		"ok": true,
		"type": "travel",
		"source_id": target_id,
		"action_id": "confirm_travel",
		"action_kind": "travel",
		"environment_id": str(destination_environment.get("id", "")),
		"environment_archetype_id": target_id,
		"bankroll_delta": total_bankroll_delta,
		"suspicion_delta": total_suspicion_delta,
		"route_cost": cost,
		"route_risk": route_risk.duplicate(true),
		"deltas": deltas,
		"message": message,
	})


func _travel_target_ids(run_state: RunState) -> Array:
	if not _qualifying_world_travel_contract_holds(run_state):
		return []
	# Invoke the shipped Foundation travel view directly. The qualifying contract
	# below excludes the meta/tutorial/delivery/local-door/closing overlays while
	# retaining its exact route ranking, Walk timing and locked-card semantics.
	return _production_foundation_travel_host(run_state)._travel_target_ids()


func _production_foundation_travel_host(run_state: RunState) -> AuditFoundationTravelHost:
	return AuditFoundationTravelHost.new(
		FoundationTravelViewModelScript,
		WorldMapScript,
		TutorialFlowScript,
		AttributeBadgesScript,
		run_state,
		generator,
		library
	)


func _qualifying_world_travel_contract_holds(run_state: RunState) -> bool:
	var issues: Array = []
	if run_state == null or not run_state.has_world_map():
		issues.append("a generated world map is required")
	if run_state != null and run_state.is_tutorial_run():
		issues.append("tutorial route filtering is outside this normal-run audit")
	if run_state != null and bool(run_state.narrative_flags.get("_meta_home_session", false)):
		issues.append("meta-session travel is outside this normal-run audit")
	if run_state != null and run_state.delivery_has_active_run():
		issues.append("active delivery next-hop promotion is outside this audit")
	if run_state != null and run_state.closing_time_forced_travel_required():
		issues.append("forced closing-time walk presentation is outside this audit")
	if run_state != null and run_state.travel_option_bonus() != 0:
		issues.append("the fixed three-card evidence schema requires zero travel-option bonus")
	if run_state != null:
		var local_flags_value: Variant = run_state.current_environment.get("local_narrative_flags", {})
		var local_flags: Dictionary = local_flags_value if typeof(local_flags_value) == TYPE_DICTIONARY else {}
		if not _string_array(local_flags.get("casino_room_targets", [])).is_empty():
			issues.append("local casino-room door presentation is outside this world-route audit")
	if issues.is_empty():
		return true
	var node_id := run_state.current_world_node_id() if run_state != null else "missing-run"
	for issue_value in issues:
		var message := "Qualifying world-travel contract failed at %s: %s." % [node_id, str(issue_value)]
		if not failures.has(message):
			failures.append(message)
	return false


func _build_aggregate(run_count: int, visits_per_run: int, seed_prefix: String) -> Dictionary:
	var aggregate := {
		"run_count": run_count,
		"visits_per_run_target": visits_per_run,
		"seed_prefix": seed_prefix,
		"environment_visit_count": records.size(),
		"travel_count": travel_records.size(),
		"events_resolved_for_travel": 0,
		"stopped_reasons": {},
		"archetypes": {},
		"kinds": {},
		"tiers": {},
		"moods": {},
		"games": {},
		"events": {},
		"event_resolutions": {},
		"items": {},
		"item_prices": {},
		"services": {},
		"lenders": {},
		"travel_targets_generated": {},
		"travel_targets_available": {},
		"travel_targets_locked": {},
		"travel_targets_selected": {},
		"travel_risk_events": {},
		"overall_objects": {},
		"archetype_content": {},
		"run_presence": {},
	}
	var run_presence := _empty_presence_groups()
	for summary in run_summaries:
		if typeof(summary) != TYPE_DICTIONARY:
			continue
		_count_key(aggregate["stopped_reasons"], str((summary as Dictionary).get("stopped_reason", "unknown")))
	for record in records:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = record
		var run_index := int(data.get("run_index", 0))
		var archetype_id := str(data.get("archetype_id", "unknown"))
		_count_key(aggregate["archetypes"], archetype_id)
		_count_key(aggregate["overall_objects"], "environment:%s" % archetype_id)
		_mark_presence(run_presence["archetypes"], run_index, archetype_id)
		_count_key(aggregate["kinds"], str(data.get("kind", "unknown")))
		_count_key(aggregate["tiers"], str(data.get("tier", 1)))
		_count_key(aggregate["moods"], str(data.get("mood", "unknown")))
		_count_archetype_content(aggregate, archetype_id, "visits", archetype_id)
		for game_id in _string_array(data.get("games", [])):
			_count_key(aggregate["games"], game_id)
			_count_key(aggregate["overall_objects"], "game:%s" % game_id)
			_mark_presence(run_presence["games"], run_index, game_id)
			_count_archetype_content(aggregate, archetype_id, "games", game_id)
		for event_id in _string_array(data.get("events", [])):
			_count_key(aggregate["events"], event_id)
			_count_key(aggregate["overall_objects"], "event:%s" % event_id)
			_mark_presence(run_presence["events"], run_index, event_id)
			_count_archetype_content(aggregate, archetype_id, "events", event_id)
		for offer in _copy_array(data.get("items", [])):
			if typeof(offer) != TYPE_DICTIONARY:
				continue
			var item_id := str((offer as Dictionary).get("id", ""))
			_count_key(aggregate["items"], item_id)
			_count_key(aggregate["overall_objects"], "item:%s" % item_id)
			_mark_presence(run_presence["items"], run_index, item_id)
			_count_archetype_content(aggregate, archetype_id, "items", item_id)
			_track_price(aggregate["item_prices"], item_id, int((offer as Dictionary).get("price", 0)))
		for service_id in _string_array(data.get("services", [])):
			_count_key(aggregate["services"], service_id)
			_count_key(aggregate["overall_objects"], "service:%s" % service_id)
			_mark_presence(run_presence["services"], run_index, service_id)
			_count_archetype_content(aggregate, archetype_id, "services", service_id)
		for lender_id in _string_array(data.get("lenders", [])):
			_count_key(aggregate["lenders"], lender_id)
			_count_key(aggregate["overall_objects"], "lender:%s" % lender_id)
			_mark_presence(run_presence["lenders"], run_index, lender_id)
			_count_archetype_content(aggregate, archetype_id, "lenders", lender_id)
		var recorded_travel_object := false
		for choice in _copy_array(data.get("travel_after_events", [])):
			if typeof(choice) != TYPE_DICTIONARY:
				continue
			var target_id := str((choice as Dictionary).get("id", ""))
			_count_key(aggregate["travel_targets_generated"], target_id)
			if not recorded_travel_object:
				_count_key(aggregate["overall_objects"], "travel:leave")
				recorded_travel_object = true
			if bool((choice as Dictionary).get("enabled", false)):
				_count_key(aggregate["travel_targets_available"], target_id)
			else:
				_count_key(aggregate["travel_targets_locked"], target_id)
		var resolved_events := _copy_array(data.get("events_resolved_for_travel", []))
		aggregate["events_resolved_for_travel"] = int(aggregate.get("events_resolved_for_travel", 0)) + resolved_events.size()
		for resolved in resolved_events:
			if typeof(resolved) != TYPE_DICTIONARY:
				continue
			var key := "%s:%s" % [str((resolved as Dictionary).get("event_id", "")), str((resolved as Dictionary).get("choice_id", ""))]
			_count_key(aggregate["event_resolutions"], key)
	for travel in travel_records:
		if typeof(travel) != TYPE_DICTIONARY:
			continue
		var travel_data: Dictionary = travel
		_count_key(aggregate["travel_targets_selected"], str(travel_data.get("target_id", "")))
		var route_risk := _copy_dict(travel_data.get("route_risk", {}))
		if bool(route_risk.get("triggered", false)):
			_count_key(aggregate["travel_risk_events"], str(route_risk.get("id", "travel_risk")))
	aggregate["run_presence"] = _presence_counts(run_presence)
	_finalize_price_stats(aggregate["item_prices"])
	return aggregate


func _write_json(output_path: String, report: Dictionary) -> void:
	var global_path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(global_path.get_base_dir())
	var file := FileAccess.open(global_path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write JSON report to %s." % global_path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()


func _write_markdown(output_path: String, report: Dictionary) -> void:
	var global_path := ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(global_path.get_base_dir())
	var markdown := _build_markdown(report)
	var file := FileAccess.open(global_path, FileAccess.WRITE)
	if file == null:
		failures.append("Could not write Markdown report to %s." % global_path)
		return
	file.store_string(markdown)
	file.close()


func _build_markdown(report: Dictionary) -> String:
	var aggregate := _copy_dict(report.get("aggregate", {}))
	var env_count := maxi(1, int(aggregate.get("environment_visit_count", 0)))
	var run_count := maxi(1, int(aggregate.get("run_count", 0)))
	var lines: Array = []
	lines.append("# Environment Generation Audit")
	lines.append("")
	lines.append("Generated by `tools/environment_generation_audit.gd`.")
	lines.append("")
	lines.append("## Method")
	for note in _method_notes():
		lines.append("- %s" % note)
	lines.append("- Seed prefix: `%s`." % str(report.get("seed_prefix", "")))
	lines.append("- Raw data: `res://.tmp/environment_generation_audit/report.json`.")
	lines.append("")
	lines.append("## Summary")
	lines.append("")
	lines.append("| Metric | Value |")
	lines.append("| --- | ---: |")
	lines.append("| Unique seed runs | %d |" % int(report.get("run_count", 0)))
	lines.append("| Target location visits per run | %d |" % int(report.get("visits_per_run_target", 0)))
	lines.append("| Generated location samples | %d |" % int(aggregate.get("environment_visit_count", 0)))
	lines.append("| Travel transitions | %d |" % int(aggregate.get("travel_count", 0)))
	lines.append("| Travel risk events | %d |" % _count_total(aggregate.get("travel_risk_events", {})))
	lines.append("| Event choices resolved for travel | %d |" % int(aggregate.get("events_resolved_for_travel", 0)))
	lines.append("| Failures | %d |" % int(report.get("failure_count", 0)))
	lines.append("| Warnings | %d |" % int(report.get("warning_count", 0)))
	lines.append("")
	lines.append("## Environment Visits")
	lines.append("")
	lines.append(_count_table(aggregate.get("archetypes", {}), env_count, run_count, aggregate.get("run_presence", {}).get("archetypes", {}), "Environment"))
	lines.append("")
	lines.append("```mermaid")
	lines.append("pie showData")
	lines.append("    title Environment visit share")
	for pair in _ranked_pairs(aggregate.get("archetypes", {}), 12):
		lines.append("    \"%s\" : %d" % [str(pair.get("key", "")), int(pair.get("count", 0))])
	lines.append("```")
	lines.append("")
	lines.append("## Generated Games")
	lines.append("")
	lines.append(_count_table(aggregate.get("games", {}), env_count, run_count, aggregate.get("run_presence", {}).get("games", {}), "Game"))
	lines.append("")
	lines.append("## Generated Events")
	lines.append("")
	lines.append(_count_table(aggregate.get("events", {}), env_count, run_count, aggregate.get("run_presence", {}).get("events", {}), "Event"))
	lines.append("")
	lines.append("### Event Choices Resolved For Travel")
	lines.append("")
	lines.append(_simple_count_table(aggregate.get("event_resolutions", {}), int(aggregate.get("events_resolved_for_travel", 0)), "Event choice"))
	lines.append("")
	lines.append("## Item Offers")
	lines.append("")
	lines.append(_item_table(aggregate, env_count, run_count))
	lines.append("")
	lines.append("## Services And Lenders")
	lines.append("")
	lines.append("### Services")
	lines.append("")
	lines.append(_count_table(aggregate.get("services", {}), env_count, run_count, aggregate.get("run_presence", {}).get("services", {}), "Service"))
	lines.append("")
	lines.append("### Lenders")
	lines.append("")
	lines.append(_count_table(aggregate.get("lenders", {}), env_count, run_count, aggregate.get("run_presence", {}).get("lenders", {}), "Lender"))
	lines.append("")
	lines.append("## Travel Availability")
	lines.append("")
	lines.append("### Available After Event Policy")
	lines.append("")
	lines.append(_simple_count_table(aggregate.get("travel_targets_available", {}), env_count, "Route"))
	lines.append("")
	lines.append("### Locked Or Hidden After Event Policy")
	lines.append("")
	lines.append(_simple_count_table(aggregate.get("travel_targets_locked", {}), env_count, "Route"))
	lines.append("")
	lines.append("### Selected Routes")
	lines.append("")
	lines.append(_simple_count_table(aggregate.get("travel_targets_selected", {}), maxi(1, int(aggregate.get("travel_count", 0))), "Route"))
	lines.append("")
	lines.append("### Travel Risk Events")
	lines.append("")
	lines.append(_simple_count_table(aggregate.get("travel_risk_events", {}), maxi(1, _count_total(aggregate.get("travel_risk_events", {}))), "Risk event"))
	lines.append("")
	lines.append("## Most Common Objects Overall")
	lines.append("")
	lines.append(_simple_count_table(aggregate.get("overall_objects", {}), env_count, "Object", 20))
	lines.append("")
	lines.append("## Content By Environment")
	lines.append("")
	lines.append(_archetype_content_sections(aggregate))
	lines.append("")
	lines.append("## Run Stops")
	lines.append("")
	lines.append(_simple_count_table(aggregate.get("stopped_reasons", {}), run_count, "Reason"))
	lines.append("")
	lines.append("## Notes")
	lines.append("")
	lines.append("- Percentages are based on generated location samples unless a column is labeled run rate.")
	lines.append("- Grand Casino can appear as a travel target before it is affordable. In this no-game travel audit, locked Grand Casino availability is expected unless events create enough bankroll.")
	lines.append("- The JSON output includes every sampled environment, every generated game-state summary, every route choice, and every travel transition.")
	lines.append("")
	return "\n".join(lines)


func _count_table(counts_value: Variant, env_count: int, run_count: int, run_presence_value: Variant, label: String) -> String:
	var counts := _copy_dict(counts_value)
	if counts.is_empty():
		return "_None observed._"
	var run_presence := _copy_dict(run_presence_value)
	var lines: Array = []
	lines.append("| %s | Count | Env rate | Run rate | Chart |" % label)
	lines.append("| --- | ---: | ---: | ---: | --- |")
	for pair in _ranked_pairs(counts, 50):
		var key := str(pair.get("key", ""))
		var count := int(pair.get("count", 0))
		var run_hits := int(run_presence.get(key, 0))
		lines.append("| `%s` | %d | %s | %s | `%s` |" % [
			key,
			count,
			_percent(float(count) / float(maxi(1, env_count))),
			_percent(float(run_hits) / float(maxi(1, run_count))),
			_bar(float(count) / float(maxi(1, env_count))),
		])
	return "\n".join(lines)


func _simple_count_table(counts_value: Variant, denominator: int, label: String, limit: int = 50) -> String:
	var counts := _copy_dict(counts_value)
	if counts.is_empty():
		return "_None observed._"
	var lines: Array = []
	lines.append("| %s | Count | Rate | Chart |" % label)
	lines.append("| --- | ---: | ---: | --- |")
	for pair in _ranked_pairs(counts, limit):
		var count := int(pair.get("count", 0))
		var rate := float(count) / float(maxi(1, denominator))
		lines.append("| `%s` | %d | %s | `%s` |" % [str(pair.get("key", "")), count, _percent(rate), _bar(rate)])
	return "\n".join(lines)


func _count_total(counts_value: Variant) -> int:
	var counts := _copy_dict(counts_value)
	var total := 0
	for key in counts.keys():
		total += int(counts.get(key, 0))
	return total


func _item_table(aggregate: Dictionary, env_count: int, run_count: int) -> String:
	var counts := _copy_dict(aggregate.get("items", {}))
	if counts.is_empty():
		return "_None observed._"
	var run_presence := _copy_dict(_copy_dict(aggregate.get("run_presence", {})).get("items", {}))
	var prices := _copy_dict(aggregate.get("item_prices", {}))
	var lines: Array = []
	lines.append("| Item | Count | Env rate | Run rate | Avg price | Price range | Chart |")
	lines.append("| --- | ---: | ---: | ---: | ---: | ---: | --- |")
	for pair in _ranked_pairs(counts, 50):
		var key := str(pair.get("key", ""))
		var count := int(pair.get("count", 0))
		var price := _copy_dict(prices.get(key, {}))
		var avg := float(price.get("average", 0.0))
		var min_price := int(price.get("min", 0))
		var max_price := int(price.get("max", 0))
		lines.append("| `%s` | %d | %s | %s | %.1f | %d-%d | `%s` |" % [
			key,
			count,
			_percent(float(count) / float(maxi(1, env_count))),
			_percent(float(int(run_presence.get(key, 0))) / float(maxi(1, run_count))),
			avg,
			min_price,
			max_price,
			_bar(float(count) / float(maxi(1, env_count))),
		])
	return "\n".join(lines)


func _archetype_content_sections(aggregate: Dictionary) -> String:
	var content := _copy_dict(aggregate.get("archetype_content", {}))
	if content.is_empty():
		return "_No archetype content recorded._"
	var sections: Array = []
	var archetypes := content.keys()
	archetypes.sort()
	for archetype_id in archetypes:
		var data := _copy_dict(content.get(archetype_id, {}))
		sections.append("### `%s`" % archetype_id)
		sections.append("")
		for group in ["games", "events", "items", "services", "lenders"]:
			var counts := _copy_dict(data.get(group, {}))
			var top := _top_inline(counts, 8)
			sections.append("- %s: %s" % [group.capitalize(), top if not top.is_empty() else "none"])
		sections.append("")
	return "\n".join(sections)


func _top_inline(counts: Dictionary, limit: int) -> String:
	var parts: Array = []
	for pair in _ranked_pairs(counts, limit):
		parts.append("`%s` (%d)" % [str(pair.get("key", "")), int(pair.get("count", 0))])
	return ", ".join(parts)


func _print_summary(output_json: String, output_markdown: String, aggregate: Dictionary, evidence_satisfied: bool) -> void:
	print("Environment generation audit complete.")
	print("Environment samples: %d" % int(aggregate.get("environment_visit_count", 0)))
	print("Travel transitions: %d" % int(aggregate.get("travel_count", 0)))
	print("Markdown report: %s" % ProjectSettings.globalize_path(output_markdown))
	print("JSON report: %s" % ProjectSettings.globalize_path(output_json))
	if failures.is_empty() and warnings.is_empty() and evidence_satisfied:
		print("Environment generation audit passed.")
	else:
		for failure in failures:
			push_error(failure)
		for warning in warnings:
			push_error("Qualifying audit warning: %s" % warning)
		if not evidence_satisfied:
			push_error("Environment generation audit did not satisfy its requested visit/travel or Crew no-op evidence contract.")


func _method_notes() -> Array:
	return [
		"100 unique randomly generated seed runs by default.",
		"Each run targets six generated location visits.",
		"No game is entered or resolved; game state is only generated by the environment generator.",
		"No items, services, or lenders are purchased or used.",
		"Event policy resolves only choices that add/replace travel targets, set the underground travel flag, or restore bankroll when no route is otherwise enabled.",
		"Travel-locked venues advance their lock countdown when no route is enabled, simulating non-game ride actions for audit continuity.",
		"Travel uses the same route status, route cost, suspicion decay, and travel result application path as the Foundation UI.",
	]


func _empty_presence_groups() -> Dictionary:
	return {
		"archetypes": {},
		"games": {},
		"events": {},
		"items": {},
		"services": {},
		"lenders": {},
	}


func _presence_counts(presence: Dictionary) -> Dictionary:
	var result := {}
	for group in presence.keys():
		var group_result := {}
		var group_presence := _copy_dict(presence.get(group, {}))
		for key in group_presence.keys():
			group_result[key] = _copy_dict(group_presence.get(key, {})).size()
		result[group] = group_result
	return result


func _mark_presence(presence_group: Dictionary, run_index: int, key: String) -> void:
	if key.is_empty():
		return
	var runs := _copy_dict(presence_group.get(key, {}))
	runs[str(run_index)] = true
	presence_group[key] = runs


func _count_archetype_content(aggregate: Dictionary, archetype_id: String, group: String, key: String) -> void:
	var content := _copy_dict(aggregate.get("archetype_content", {}))
	var archetype := _copy_dict(content.get(archetype_id, {}))
	var counts := _copy_dict(archetype.get(group, {}))
	_count_key(counts, key)
	archetype[group] = counts
	content[archetype_id] = archetype
	aggregate["archetype_content"] = content


func _track_price(price_stats: Dictionary, item_id: String, price: int) -> void:
	if item_id.is_empty():
		return
	var data := _copy_dict(price_stats.get(item_id, {}))
	if data.is_empty():
		data = {"count": 0, "sum": 0, "min": price, "max": price}
	data["count"] = int(data.get("count", 0)) + 1
	data["sum"] = int(data.get("sum", 0)) + price
	data["min"] = mini(int(data.get("min", price)), price)
	data["max"] = maxi(int(data.get("max", price)), price)
	price_stats[item_id] = data


func _finalize_price_stats(price_stats: Dictionary) -> void:
	for item_id in price_stats.keys():
		var data := _copy_dict(price_stats.get(item_id, {}))
		var count := maxi(1, int(data.get("count", 0)))
		data["average"] = float(int(data.get("sum", 0))) / float(count)
		price_stats[item_id] = data


func _ranked_pairs(counts_value: Variant, limit: int) -> Array:
	var counts := _copy_dict(counts_value)
	var pairs: Array = []
	for key in counts.keys():
		pairs.append({"key": str(key), "count": int(counts[key])})
	pairs.sort_custom(Callable(self, "_sort_count_desc"))
	if limit > 0 and pairs.size() > limit:
		return pairs.slice(0, limit)
	return pairs


func _sort_count_desc(a: Dictionary, b: Dictionary) -> bool:
	var count_a := int(a.get("count", 0))
	var count_b := int(b.get("count", 0))
	if count_a == count_b:
		return str(a.get("key", "")) < str(b.get("key", ""))
	return count_a > count_b


func _count_key(counts: Dictionary, key: String) -> void:
	if key.is_empty():
		return
	counts[key] = int(counts.get(key, 0)) + 1


func _item_offer_records(offers_value: Variant) -> Array:
	var result: Array = []
	for offer in _copy_array(offers_value):
		if typeof(offer) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = offer
		result.append({
			"id": str(data.get("id", "")),
			"display_name": str(data.get("display_name", "")),
			"price": int(data.get("price", 0)),
			"price_min": int(data.get("price_min", 0)),
			"price_max": int(data.get("price_max", 0)),
		})
	return result


func _item_ids_from_offers(offers_value: Variant) -> Array:
	var result: Array = []
	for offer in _copy_array(offers_value):
		if typeof(offer) != TYPE_DICTIONARY:
			continue
		var item_id := str((offer as Dictionary).get("id", ""))
		if not item_id.is_empty():
			result.append(item_id)
	return result


func _archetype(archetype_id: String) -> Dictionary:
	for archetype in library.environment_archetypes:
		if typeof(archetype) == TYPE_DICTIONARY and str((archetype as Dictionary).get("id", "")) == archetype_id:
			return (archetype as Dictionary).duplicate(true)
	return {}


func _travel_label_from_archetype(archetype: Dictionary, fallback_id: String) -> String:
	var nouns := _copy_array(archetype.get("name_nouns", []))
	if not nouns.is_empty():
		return str(nouns[0])
	return fallback_id.replace("_", " ").capitalize()


func _percent(value: float) -> String:
	return "%.1f%%" % (value * 100.0)


func _bar(value: float, width: int = 24) -> String:
	var filled := clampi(int(round(value * float(width))), 0, width)
	var text := ""
	for index in range(width):
		text += "#" if index < filled else "."
	return text


func _sorted_keys(value: Dictionary) -> Array:
	var keys := value.keys()
	keys.sort()
	var result: Array = []
	for key in keys:
		result.append(str(key))
	return result


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		var id := str(entry)
		if not id.is_empty():
			result.append(id)
	return result


func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
