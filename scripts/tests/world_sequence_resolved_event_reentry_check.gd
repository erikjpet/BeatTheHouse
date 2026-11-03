extends "res://scripts/tests/foundation/world_sequence_delivery_proof_contract.gd"

const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const PublicationScript := preload("res://scripts/core/room_presentation_publication.gd")
const OFFER_ID := "back_alley_offer"
const OFFER_OBJECT_ID := "event:back_alley_offer"
const SLOT := "world_sequence_resolved_event_reentry_contract"

var checks: Array = []
var failures: Array = []
var facts := {"fidelity": "Synthetic generated Back Alley with explicit no primary scenario and one real catalog offer. Real EventModule resolution, public package registration, installed finalization and SaveService codec; no genuine player save, quoted travel or full-process cold claim."}


func _expect(ok: bool, message: String) -> bool:
	checks.append(message)
	if not ok: failures.append(message)
	return ok


func _initialize() -> void:
	if not _expect(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "isolated native-private save root required"):
		_finish(); return
	var library := ContentLibraryScript.new(); library.load(false)
	var run := RunStateScript.new()
	run.start_new("WORLD-SEQUENCE-RESOLVED-OFFER-REENTRY")
	var generator := RunGeneratorScript.new(library)
	generator.next_environment(run)
	var arrived := generator.travel_environment_result(run, "back_alley", true)
	if not _expect(bool(arrived.get("ok", false)) and run.current_world_node_id() == "back_alley", "fixture reaches real Back Alley world node"):
		facts["fixture_arrival"] = arrived; _finish(); return
	# Deliberate synthetic selection: use the shipped room/art/slot contracts,
	# explicitly choose no primary room sequence, and guarantee this real offer.
	# Production map topology/cursor remain in place for the public package API.
	var archetype := library.environment_archetype("back_alley").duplicate(true)
	archetype["event_pool"] = [OFFER_ID]
	archetype["required_event_ids"] = [OFFER_ID]
	archetype["event_count"] = [1, 1]
	var rng := RngStreamScript.new(); rng.configure(718860)
	var room := EnvironmentInstanceScript.from_archetype(archetype, 2, rng, library).to_dict()
	var installed := run.set_environment(room)
	if not _expect(bool(installed.get("ok", false)), "synthetic ordinary room installs through RunState"):
		facts["fixture_install"] = installed; _finish(); return
	if not _expect(bool(run.scenario_finalize_installed_environment(library).get("ok", false)), "ordinary source room has valid publication"):
		_finish(); return
	_expect(not SequenceSchemaScript.is_sequence(run.scenario_sequence_definition()), "fixture has no primary room sequence")
	_expect(run.current_environment.get("event_ids", []).has(OFFER_ID), "real offer is selected")
	var event := EventModuleScript.new(); event.setup(library.event(OFFER_ID), library)
	var cash_before_offer := run.bankroll
	var offer := event.resolve(run, run.current_environment, "take_cash", true, false)
	facts["offer_result"] = offer
	if not _expect(run.bankroll > cash_before_offer and run.current_environment.get("resolved_event_ids", []).has(OFFER_ID), "one real take_cash choice resolves and pays offer"):
		_finish(); return
	_expect(_offer_absent(run), "consumed offer releases its live slot and rectangle")
	var begun := run.delivery_begin_package({"run_id": "resolved_offer_delivery", "target_node_ids": ["back_alley"], "cargo_id": "sealed_case", "cargo_label": "Synthetic sealed case", "deadline_actions": 100, "consumer_payload": {"required_target_archetype_id": "back_alley", "allow_origin_room_target": true}})
	if not _expect(bool(begun.get("ok", false)), "public synthetic package begins"):
		facts["package_begin"] = begun; _finish(); return
	_pickup_delivery(run, "resolved_offer")
	if not _expect(str(run.delivery_snapshot().get("physical", {}).get("cargo_state", "")) == "carried", "public pickup puts synthetic cargo in custody"):
		_finish(); return
	var instance := str(run.delivery_snapshot().get("run_id", ""))
	var scheduled := run.world_sequence_schedule_mount("world06_1_crew_favor_delivery", instance, "back_alley")
	if not _expect(bool(scheduled.get("ok", false)), "trusted delivery owner schedules for same room"):
		facts["schedule"] = scheduled; _finish(); return
	var token := str(scheduled.get("owner_token", ""))
	var protected := _protected(run)
	var finalized := run.scenario_finalize_installed_environment(library)
	facts["installed_finalization"] = _result_summary(finalized)
	if not _expect(bool(finalized.get("ok", false)), "resolved-event world-only installed finalization succeeds"):
		# On the original source this records the decisive exact rejection:
		# Current base record event:back_alley_offer has no authenticated slot binding.
		_finish(); return
	_expect(_protected(run) == protected, "finalization changes no cash clock RNG cargo jobs or debt")
	_expect(_offer_absent(run), "world seal does not revive consumed offer")
	_expect(run.world_sequence_mounted_owner_for_channel("delivery_handoff", "back_alley") == token and not token.is_empty(), "scheduled owner mounts normally")
	_expect(bool(run.validate_room_action_authority().get("ok", false)), "mounted room retains strict slot and semantic authority")
	var repeat := run.scenario_finalize_installed_environment(library)
	_expect(bool(repeat.get("ok", false)) and _protected(run) == protected and _offer_absent(run), "repeated finalization has no offer or delivery replay")
	var service := SaveServiceScript.new()
	var save_error := service.save_run(run, SLOT)
	var restored: Variant = service.load_run(SLOT) if save_error == OK else null
	service.clear_run(SLOT)
	if not _expect(restored is RunState, "normal SaveService codec roundtrip loads"):
		facts["save_error"] = save_error; _finish(); return
	var continued: Dictionary = restored.scenario_finalize_installed_environment(library)
	facts["continue_finalization"] = _result_summary(continued)
	_expect(bool(continued.get("ok", false)), "decoded world-only Continue finalizes")
	_expect(_protected(restored) == protected and _offer_absent(restored), "Continue preserves exact gameplay and consumed offer")
	_expect(restored.world_sequence_mounted_owner_for_channel("delivery_handoff", "back_alley") == token, "Continue retains same delivery owner")
	# Exercise installed-room ingress with its decoded durable envelope. This is
	# an installation seam check, not a claim of a map fare or departure journey.
	var durable_room: Dictionary = EnvironmentInstanceScript.from_dict(restored.current_environment).to_dict()
	var reinstalled: Dictionary = restored.set_environment(durable_room)
	var reentry: Dictionary = restored.scenario_finalize_installed_environment(library) if bool(reinstalled.get("ok", false)) else reinstalled
	facts["decoded_room_reentry"] = _result_summary(reentry)
	_expect(bool(reentry.get("ok", false)), "decoded room installs and finalizes on reentry")
	_expect(_protected(restored) == protected and _offer_absent(restored), "installed reentry preserves cash cargo receipts and resolved offer")
	var tampered := RunStateScript.new(); tampered.from_dict(restored.to_dict())
	tampered.current_environment = restored.current_environment.duplicate(true)
	tampered.current_environment["layout"]["slot_binding_digest"] = "untrusted-test-digest"
	var rejected := tampered.scenario_finalize_installed_environment(library)
	_expect(not bool(rejected.get("ok", true)), "edited incoming slot digest remains rejected")
	_expect(not bool(PublicationScript.validate(tampered.current_environment).get("ok", true)), "tampered envelope is not repaired into publication")
	_expect(_protected(tampered) == protected, "tamper rejection changes no gameplay or outcomes")
	facts["protected_after"] = _protected(restored)
	_finish()


func _offer_absent(run: RunState) -> bool:
	var layout: Dictionary = run.current_environment.get("layout", {})
	return run.current_environment.get("resolved_event_ids", []).has(OFFER_ID) \
		and not layout.get("slot_bindings", {}).has(OFFER_OBJECT_ID) \
		and not layout.get("object_rects", {}).has(OFFER_OBJECT_ID)


func _protected(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "clock": run.game_clock_minutes, "rng_seed": run.rng_seed, "rng_state": run.rng_state, "heat": run.suspicion_level(), "inventory": run.inventory.duplicate(true), "delivery": run.active_delivery_run.duplicate(true), "jobs": run.crew_jobs.duplicate(true), "debt": run.debt.duplicate(true), "resolved": run.current_environment.get("resolved_event_ids", []).duplicate(true)}


func _result_summary(result: Dictionary) -> Dictionary:
	return {"ok": bool(result.get("ok", false)), "errors": result.get("errors", []), "inactive": bool(result.get("inactive", false))}


func _finish() -> void:
	var receipt := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "facts": facts}
	var output := OS.get_environment("BTH_RESOLVED_EVENT_RESULT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(receipt, "  "))
	print("WORLD_RESOLVED_EVENT_RECEIPT ", JSON.stringify(receipt))
	for failure in failures: push_error(str(failure))
	quit(0 if failures.is_empty() else 1)
