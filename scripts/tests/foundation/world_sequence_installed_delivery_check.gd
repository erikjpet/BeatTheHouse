extends "res://scripts/tests/foundation/world_sequence_delivery_proof_contract.gd"

var checks := 0
var failures: Array = []
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	var library := ContentLibraryScript.new(); library.load(false)
	# Synthetic public package targeting a real generated ordinary Motel. This
	# isolates installation/Continue, not private Crew settlement authority.
	var run := _production_run(library,"INSTALLED-WORLD-ONLY-DELIVERY")
	var begun := run.delivery_begin_package({"run_id":"installed_world_only_delivery","target_node_ids":["motel"],"cargo_id":"sealed_case","cargo_label":"Sealed case","deadline_actions":100})
	_expect(bool(begun.get("ok",false)),"Package fixture could not start.")
	if not bool(begun.get("ok",false)): _finish();return
	_pickup_delivery(run,"installed_world_only")
	var instance := str(run.delivery_snapshot().get("run_id",""))
	var scheduled := run.world_sequence_schedule_mount("world06_1_crew_favor_delivery",instance,"motel")
	_expect(bool(scheduled.get("ok",false)),"Trusted package schedule failed.")
	var token := str(scheduled.get("owner_token",""))
	var traveled := RunGeneratorScript.new(library).travel_environment_result(run,"motel",true)
	_expect(bool(traveled.get("ok",false)),"Ordinary Motel install failed.")
	_expect(not SequenceSchemaScript.is_sequence(run.scenario_sequence_definition()),"Fixture must exercise a world-only room.")
	_expect(run.world_sequence_mounted_owner_for_channel("delivery_handoff","motel")==token and not token.is_empty(),"Production installation omitted the scheduled contact.")
	_expect(not run.room_presentation_snapshot().is_empty(),"Installed room has no committed presentation.")
	var cash := run.bankroll; var rng := run.rng_state; var clock := run.game_clock_minutes
	var result := run.scenario_finalize_installed_environment(library)
	_expect(bool(result.get("ok",false)),"Repeated trusted finalization failed.")
	_expect(run.bankroll==cash and run.rng_state==rng and run.game_clock_minutes==clock,"Finalization changed cash/RNG/clock.")
	var restored := RunStateScript.new(); restored.from_dict(run.to_dict())
	var continued := restored.scenario_finalize_installed_environment(library)
	_expect(bool(continued.get("ok",false)),"World-only Continue finalization failed.")
	_expect(restored.world_sequence_mounted_owner_for_channel("delivery_handoff","motel")==token,"Continue lost the authenticated contact owner.")
	_expect(restored.bankroll==cash and restored.rng_state==rng and restored.game_clock_minutes==clock,"Continue changed cash/RNG/clock.")
	_expect(not restored.room_presentation_snapshot().is_empty(),"Continue did not publish the room.")
	_finish()

func _finish() -> void:
	for failure in failures: push_error(str(failure))
	print("Installed world-only delivery checks: ",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
