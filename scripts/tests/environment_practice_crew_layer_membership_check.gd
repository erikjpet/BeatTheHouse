extends SceneTree

const Crew := preload("res://scripts/core/crew_recruitment_model.gd")
const Binder := preload("res://scripts/core/environment_slot_binder.gd")
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

class ProbeRun extends RunState:
	var inject_stale_input := false
	var target_installed := false
	var target_reconciliations := 0
	var installed_source_digest := ""
	var installed_baseline_errors: Array = []
	func install_environment_layer_state(id: String, state: Dictionary, content: ContentLibrary = null) -> bool:
		var ok := super.install_environment_layer_state(id, state, content)
		if ok and id == "casino":
			target_installed = true
			installed_source_digest = str(current_environment.get("object_manifest", {}).get("source_digest", ""))
			installed_baseline_errors = EnvironmentInstance.object_manifest_errors(current_environment)
			if inject_stale_input:
				var events: Array = current_environment.get("event_ids", []).duplicate()
				events.append("__untrusted_practice_probe_event")
				current_environment["event_ids"] = events
		return ok

	func reconcile_environment_object_membership(environment: Dictionary) -> Dictionary:
		if target_installed: target_reconciliations += 1
		return super.reconcile_environment_object_membership(environment)

class ProbeGenerator extends RunGenerator:
	var phases: Array[Dictionary] = []
	func _init(content: ContentLibrary) -> void: super(content)

	func _prepare_layer_crew_membership(run: RunState) -> Dictionary:
		var before := protected(run)
		var events: Array = run.current_environment.get("event_ids", []).duplicate()
		var baseline_errors := EnvironmentInstance.object_manifest_errors(run.current_environment)
		var old_digest := str(run.current_environment.get("object_manifest", {}).get("source_digest", ""))
		var result := super._prepare_layer_crew_membership(run)
		phases.append({"ok": bool(result.get("ok", false)), "errors": result.get("errors", []).duplicate(true), "baseline_errors": baseline_errors, "post_errors": EnvironmentInstance.object_manifest_errors(run.current_environment), "source_before": old_digest, "source_after": str(run.current_environment.get("object_manifest", {}).get("source_digest", "")), "unrelated_state_equal": before == protected(run), "event_inputs_unchanged": events == run.current_environment.get("event_ids", []), "Lucky_authored_hint_present": run.current_environment.get("layout", {}).get("object_placement_hints", {}).has("event:recruitment_lucky")})
		return result

	static func protected(run: RunState) -> Dictionary:
		var value := run.to_dict().duplicate(true)
		for key in ["current_environment", "world_map", "grand_casino_room_states"]: value.erase(key)
		value["current_game_states"] = run.current_environment.get("game_states", {}).duplicate(true)
		return value

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var mode := OS.get_environment("BTH_PRACTICE_CREW_MODE")
	if not _check(mode in ["eligible", "carried", "clean", "tamper"] and OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-practice-crew-"), "explicit mode and isolated native root required"): _finish(); return
	if not _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "synthetic room probe never loads historical or browser profiles"): _finish(); return
	var content := ContentLibrary.new(); content.load()
	if not _check(content.validation_errors.is_empty(), "authoritative content library loads"): _finish(); return
	var run := ProbeRun.new()
	var seed := "ENVIRONMENT-PRACTICE-v1:SYNTHETIC-CREW-STAKE-PUBLICATION-001"
	run.start_new(seed, RunState.custom_challenge("environment_practice", seed, {"environment_practice": true}))
	run.bankroll = 200
	if mode != "clean":
		# Same explicit synthetic pre-generation eligibility as the preserved
		# failed control. Never defer this until after generation to mask the bug.
		run.crew_add_trust("crew_mags", 30, "synthetic_native_fixture")
		run.crew_change_reputation(100)
	if mode == "carried":
		# Mirrors the production F5/Environment Library carry API on a clone.
		var player := run.environment_test_player_state()
		run.start_new(seed, RunState.custom_challenge("environment_practice", seed, {"environment_practice": true}))
		_check(run.restore_environment_test_player_state(player), "supported practice player-state carry restores")
		_check(Crew.crew_path_started(run), "retained member trust legitimately derives Crew eligibility")
	run.inject_stale_input = mode == "tamper"
	var generator := ProbeGenerator.new(content)
	var before := {"cash": run.bankroll, "chips": run.grand_casino_chips, "trust": run.crew_trust_by_member.duplicate(true), "inventory": run.inventory.duplicate(true), "jobs": run.crew_jobs.duplicate(true)}
	var result := generator.environment_test_result(run, {"archetype_id": "small_underground_casino", "scenario_id": "__none", "layer_id": "casino", "generation_key": "synthetic-stake-loss-publication", "depth": 0})
	facts = {"mode": mode, "fidelity": "SYNTHETIC unpaid native room construction through production environment_test_result; eligibility is installed before generation, or carried by the actual practice API. No genuine campaign/Web reproduction or stake-loss/paid-action proof.", "paid_calls": 0, "Crew_credits": 0, "job_admissions": 0, "generation_ok": bool(result.get("ok", false)), "generation_errors": result.get("errors", []), "phases": generator.phases, "target_reconciliations": run.target_reconciliations}
	_check(run.target_installed and run.installed_baseline_errors.is_empty(), "initial Club then target Casino install have valid incoming authority")
	if mode == "tamper":
		_check(not bool(result.get("ok", false)), "deliberately stale post-install source input is rejected")
		_check(generator.phases.size() == 1 and not generator.phases[0].baseline_errors.is_empty(), "rejection occurs at first baseline authentication")
		_check(run.target_reconciliations == 0, "invalid baseline is never reconciled or signed anew")
		_check(str(run.current_environment.get("object_manifest", {}).get("source_digest", "")) == run.installed_source_digest, "original manifest is not replaced after untrusted input")
		_check(not EnvironmentInstance.object_manifest_errors(run.current_environment).is_empty(), "tampered candidate remains invalid, without healing")
	else:
		_check(bool(result.get("ok", false)), "requested practice Casino layer finalizes and publishes")
		_check(str(run.current_environment.get("current_layer_id", "")) == "casino", "requested layer remains Casino")
		_check(generator.phases.size() == 2, "both pre-finalization and final Crew reconciliation boundaries run")
		_check(EnvironmentInstance.object_manifest_errors(run.current_environment).is_empty(), "final object manifest authenticates actual selected source")
		var base_proof := Binder.validate_base_layout_authority(run.current_environment)
		_check(bool(base_proof.get("ok", false)), "strict base slot authority remains valid")
		_check(bool(run.publish_room_presentation().get("ok", false)), "strict room presentation proof passes")
		var event_ids: Array = run.current_environment.get("event_ids", [])
		_check(event_ids.count("recruitment_lucky") == (0 if mode == "clean" else 1), "eligible Lucky membership is present exactly once; clean room gains none")
		var records: Array = run.current_environment.get("object_manifest", {}).get("rows", [])
		var lucky: Array = records.filter(func(row): return str(row.get("object_id", "")) == "event:recruitment_lucky" and bool(row.get("active", false)))
		_check(lucky.size() == (0 if mode == "clean" else 1), "manifest contains exactly the eligible live Lucky object")
		if not lucky.is_empty():
			var binding_id := str(lucky[0].get("instance_object_id", lucky[0].get("object_id", "")))
			_check(not str(base_proof.get("slot_bindings", {}).get(binding_id, "")).is_empty(), "eligible Lucky has a valid physical slot binding; no exact-placement requirement invented")
		var settled := run.current_environment.duplicate(true)
		var rng_before := [run.seed_value, run.to_dict().get("rng_state")]
		_check(bool(generator._prepare_layer_crew_membership(run).get("ok", false)), "repeating the owner boundary remains valid")
		_check(run.current_environment == settled and [run.seed_value, run.to_dict().get("rng_state")] == rng_before, "repeated owner preparation is idempotent and consumes no RNG")
	for phase in generator.phases:
		_check(bool(phase.unrelated_state_equal), "each Crew reconciliation preserves unrelated run state and unpaid table states")
		if mode != "tamper": _check(bool(phase.ok) and phase.baseline_errors.is_empty() and phase.post_errors.is_empty(), "each legitimate mutation starts and finishes with valid authority")
	_check(run.bankroll == before.cash and run.grand_casino_chips == before.chips and run.inventory == before.inventory and run.crew_trust_by_member == before.trust and run.crew_jobs == before.jobs, "practice construction grants no funds, inventory, trust, job or credit; each Crew boundary separately preserves history")
	_finish()

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

func _finish() -> void:
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts}, "  ")); file.close()
	print("PRACTICE_CREW_LAYER checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
