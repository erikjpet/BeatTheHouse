extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const ScenarioSequenceContractScript := preload("res://scripts/tests/foundation/scenario_sequence_contract.gd")
const ScenarioSemanticPresentationContractScript := preload("res://scripts/tests/foundation/scenario_semantic_presentation_contract.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library = ContentLibraryScript.new()
	library.load()
	var failures: Array = []
	var cluster := "finalization"
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg)
		if arg.begins_with("--cluster="):
			cluster = arg.get_slice("=", 1)
	match cluster:
		"finalization":
			ScenarioSequenceContractScript._check_lifecycle_finalization(library, failures)
		"callers":
			ScenarioSequenceContractScript._check_lifecycle_caller_failure_contract(library, failures, self)
		"runtime":
			ScenarioSequenceContractScript._check_handler_reducer_contracts(failures)
			ScenarioSequenceContractScript._check_serialized_fact_ingress(failures)
			ScenarioSequenceContractScript._check_atomic_runtime_failures(failures)
		"persistence":
			ScenarioSequenceContractScript._check_sequence_persistence_seam(failures)
			ScenarioSequenceContractScript._check_save_service_phase_matrix(failures)
			ScenarioSequenceContractScript._check_receipt_reconstruction(failures)
		"delivery":
			ScenarioSequenceContractScript._check_delivery_day_production_package(library, failures)
			ScenarioSequenceContractScript._check_executable_evidence_contract(failures)
		"layout":
			ScenarioSemanticPresentationContractScript.check(library, failures)
		"layout_atomic_diag":
			var definition = ScenarioSequenceContractScript.finalization_fixture_definition()
			var command_visual = ScenarioSemanticPresentationContractScript._command_visual(definition)
			var command_object: Dictionary = command_visual.get("object", {}).duplicate(true)
			command_object["anchor_id"] = "missing_finalization_anchor"
			command_visual["object"] = command_object
			ScenarioSemanticPresentationContractScript._reseal_definition(definition)
			var run_state = preload("res://scripts/core/run_state.gd").new()
			run_state.current_environment = ScenarioSemanticPresentationContractScript._finalization_environment(definition)
			run_state.scenario_prepare_semantic_finalization()
			var before := JSON.stringify(run_state.current_environment)
			var rejected = run_state.scenario_finalize_base_semantics([ScenarioSemanticPresentationContractScript._production_presentation()], library, ScenarioSemanticPresentationContractScript._production_layout_context())
			print("ATOMIC_REJECTED=" + JSON.stringify(rejected))
			print("ATOMIC_CHANGED=" + str(JSON.stringify(run_state.current_environment) != before))
			print("ATOMIC_BEFORE=" + before)
			print("ATOMIC_AFTER=" + JSON.stringify(run_state.current_environment))
		"post_layout_diag":
			var definition = ScenarioSequenceContractScript.finalization_fixture_definition()
			var run_state = preload("res://scripts/core/run_state.gd").new()
			run_state.bankroll = 41
			run_state.current_environment = ScenarioSemanticPresentationContractScript._finalization_environment(definition)
			run_state.scenario_prepare_semantic_finalization()
			var finalized = run_state.scenario_finalize_base_semantics([ScenarioSemanticPresentationContractScript._production_presentation()], library, ScenarioSemanticPresentationContractScript._production_layout_context())
			var hostile_anchors: Dictionary = run_state.current_environment.get("semantic_anchors", {}).duplicate(true)
			hostile_anchors.erase("bar_floor_104")
			run_state.current_environment["semantic_anchors"] = hostile_anchors
			var command = run_state.scenario_sequence_command("prepare", "atomic_layout_prepare", {}, "scenario", "command_console", {"scenario::command_console": true})
			var hostile_context = ScenarioSemanticPresentationContractScript._production_layout_context()
			hostile_context["reserved_overlay_board_rect"] = {"x": 0.0, "y": 0.0, "w": 900.0, "h": 430.0}
			run_state.current_environment["scenario_layout_context"] = hostile_context
			var before := JSON.stringify(run_state.current_environment)
			var result = run_state.scenario_enqueue_fact("heat_changed", "fixture", {"previous": 1, "current": 2, "applied_delta": 1, "source": "fixture"}, "hostile_layout_fact")
			print("POST_FINALIZED=" + JSON.stringify(finalized.get("errors", [])))
			print("POST_COMMAND=" + JSON.stringify(command))
			print("POST_RESULT=" + JSON.stringify(result))
			print("POST_CHANGED=" + str(JSON.stringify(run_state.current_environment) != before))
		"passive_diag":
			var definition = ScenarioSequenceContractScript.finalization_fixture_definition()
			definition["sequence"]["expiry"] = {"boundary": "night_end", "after": 1, "policy": "cleanup"}
			ScenarioSemanticPresentationContractScript._reseal_definition(definition)
			var run_state = preload("res://scripts/core/run_state.gd").new()
			run_state.current_environment = ScenarioSemanticPresentationContractScript._finalization_environment(definition)
			run_state.scenario_prepare_semantic_finalization()
			var finalized = run_state.scenario_finalize_base_semantics([ScenarioSemanticPresentationContractScript._production_presentation()], library, ScenarioSemanticPresentationContractScript._production_layout_context())
			var result = run_state.scenario_sequence_apply_expiry_boundary("night_end", 1)
			var environment: Dictionary = run_state.current_environment
			print("PASSIVE_FINALIZED=" + JSON.stringify(finalized))
			print("PASSIVE_RESULT=" + JSON.stringify(result))
			print("PASSIVE_STATUS=" + str(environment.get("scenario_sequence_state", {}).get("status", "")))
			print("PASSIVE_AUTHORITY=" + JSON.stringify(environment.get("scenario_layout_authority", {})))
			print("PASSIVE_AUDIT=" + JSON.stringify(environment.get("scenario_layout_audit", {})))
			print("PASSIVE_SNAPSHOT=" + JSON.stringify(environment.get("scenario_render_snapshot", {})))
		_:
			failures.append("Unknown env06_6 cluster: %s" % cluster)
	print("ENV06_6_CLUSTER_FAILURES_JSON=" + JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
