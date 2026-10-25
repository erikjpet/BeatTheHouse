extends "res://scripts/tests/foundation/world_sequence_delivery_proof_contract.gd"

var checks := 0
var failures: Array = []

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	var library := ContentLibraryScript.new()
	library.load(false)
	# Authored production event/target/authority, with synthetic schedule boundary
	# advancement. Faithful captured-player coverage is kept separately.
	var fixture := _prepared_delivery_outcome(library, "APPOINTMENT", failures, false)
	if not fixture.is_empty(): _check_appointment(fixture, library)
	for failure in failures: push_error(str(failure))
	print("Delivery appointment checks: ",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)

func _command(run: RunState, token: String, key: String, legacy: bool = false) -> Dictionary:
	var interactions := _dict(_dict(run.world_sequence_composed_projection().get("semantic_state", {})).get("interactions", {}))
	for record_value in interactions.values():
		var record := _dict(record_value)
		for action_value in _array(record.get("available_actions", [])):
			var action := _dict(action_value)
			if str(action.get("id", "")) != "make_handoff": continue
			var options := FunctionOptions.world_sequence_command(token,"make_handoff",key,{
				"owner_namespace":"crew","stable_object_id":"package_handoff",
				"host_interaction_availability":{"crew::package_handoff":true},
				"action_origin_owner_namespace":str(action.get("action_origin_owner_namespace","")),
				"action_origin_stable_object_id":str(action.get("action_origin_stable_object_id","")),
				"action_origin_receipt_key":str(action.get("action_origin_receipt_key","")),
				"action_origin_boundary_id":str(action.get("action_origin_boundary_id","")),
				"action_origin_fingerprint":str(action.get("action_origin_fingerprint","")),
			})
			if legacy:
				# Reproduce the previous host's terminal-before-owner boundary through
				# the existing adapter API, without forging a receipt or sealed state.
				var values := options.values.duplicate(true)
				values["node_id"]=run.current_world_node_id()
				values["phase_id"]=str(run.world_sequence_projection(token).get("phase_id",""))
				return run.world_sequence_execute(token,SequenceRuntimeScript.command(FunctionOptions.ScenarioSequenceCommandOptions.from(values)),{"available_funds":run.bankroll,"host_interaction_availability":{"crew::package_handoff":true}})
			return run.world_sequence_command(options)
	return {"ok":false,"errors":["fixture handoff missing"]}

func _check_appointment(fixture: Dictionary, library: ContentLibrary) -> void:
	var run: RunState = fixture.run_state
	var token := str(fixture.token)
	var target := str(fixture.target_node_id)
	var window := CrewDeliveryScheduleScript.window_for(run.active_delivery_run,target)
	var opens := int(window.get("opens",0))
	_expect(run.game_clock_minutes < opens,"Fixture must reach its contact before the appointment.")
	if run.game_clock_minutes >= opens: return
	var before := JSON.stringify(run.to_dict())
	var early := _command(run,token,"appointment:handoff")
	_expect(not bool(early.get("ok",false)),"Early handoff was accepted.")
	_expect(JSON.stringify(run.to_dict())==before,"Early handoff changed cash/RNG/delivery/room/registration state.")
	_expect(bool(run.world_sequence_resume_delivery_checkpoint().get("inactive",false)),"Recovery paid an unissued early handoff.")
	_expect(JSON.stringify(run.to_dict())==before,"Inactive recovery changed the early run.")
	var service := SaveServiceScript.new()
	var slot := "delivery_appointment_boundary_check"
	_expect(service.save_run(run,slot)==OK,"Early run Save failed.")
	var loaded: Variant = service.load_run(slot)
	_expect(loaded is RunState,"Early Save/Continue failed.")
	if not loaded is RunState: service.clear_run(slot);return
	run=loaded
	_expect(bool(_finalize_delivery_target(run,library).get("ok",false)),"Early Continue target authority failed.")
	_expect(str(run.world_sequence_projection(token).get("phase_id",""))=="handoff","Early Continue lost its usable contact.")
	_check_legacy_early(run,token,opens,library)
	_expect(bool(run.advance_game_clock_minutes(opens-run.game_clock_minutes).get("ok",false)),"Appointment clock advancement failed.")
	var cash := run.bankroll
	var rng := run.rng_state
	var issued := _command(run,token,"appointment:handoff")
	_expect(bool(issued.get("ok",false)),"Open appointment did not accept the same handoff key.")
	_expect(run.bankroll==cash and run.rng_state==rng and run.delivery_has_active_run(),"Room command settled owner accounting prematurely.")
	_expect(service.save_run(run,slot)==OK,"Interrupted terminal command Save failed.")
	loaded=service.load_run(slot)
	_expect(loaded is RunState,"Interrupted terminal Continue failed.")
	if not loaded is RunState:service.clear_run(slot);return
	run=loaded
	_expect(bool(_finalize_delivery_target(run,library).get("ok",false)),"Interrupted Continue target authority failed.")
	var resumed := run.world_sequence_resume_delivery_checkpoint()
	_expect(bool(resumed.get("ok",false)) and not bool(resumed.get("inactive",false)),"Interrupted command did not resume its owner checkpoint.")
	_expect(run.bankroll==cash+22 and run.rng_state==rng and not run.delivery_has_active_run(),"Recovered owner payout/RNG/status mismatch.")
	var pending := run.world_sequence_pending_outcomes(token)
	_expect(pending.size()==1,"Recovered handoff did not materialize one receipt.")
	if pending.size()==1:
		var consumed := run.world_sequence_consume_delivery_outcome(token,str(_dict(pending[0]).get("receipt_id","")),target)
		_expect(bool(consumed.get("ok",false)),"Recovered receipt acknowledgement failed.")
	var settled := JSON.stringify(run.to_dict())
	_expect(bool(run.world_sequence_resume_delivery_checkpoint().get("ok",false)),"Repeated recovery failed.")
	_expect(JSON.stringify(run.to_dict())==settled,"Repeated recovery changed settled accounting.")
	_expect(service.save_run(run,slot)==OK,"Settled Save failed.")
	loaded=service.load_run(slot);service.clear_run(slot)
	_expect(loaded is RunState,"Settled cold Continue failed.")
	if loaded is RunState:
		_expect(bool(_finalize_delivery_target(loaded,library).get("ok",false)),"Settled Continue authority failed.")
		_expect(bool(loaded.world_sequence_resume_delivery_checkpoint().get("ok",false)) and loaded.bankroll==cash+22 and loaded.rng_state==rng,"Settled cold Continue repaid or changed RNG.")

func _check_legacy_early(source: RunState, token: String, opens: int, library: ContentLibrary) -> void:
	var run := RunStateScript.new()
	run.from_dict(source.to_dict())
	_expect(bool(_finalize_delivery_target(run,library).get("ok",false)),"Legacy fixture target authority failed.")
	_expect(bool(_command(run,token,"appointment:legacy",true).get("ok",false)),"Legacy early terminal boundary was not reproduced.")
	var before := JSON.stringify(run.to_dict())
	_expect(bool(run.world_sequence_resume_delivery_checkpoint().get("inactive",false)),"Legacy early command paid before its appointment.")
	_expect(JSON.stringify(run.to_dict())==before,"Legacy early recovery changed the waiting owner.")
	_expect(bool(run.advance_game_clock_minutes(opens-run.game_clock_minutes).get("ok",false)),"Legacy appointment advancement failed.")
	var registration := _dict(run.world_sequence_registrations[token])
	run.world_sequence_registrations[token]["public_instance_token"]="crew_favor_delivery:foreign"
	before=JSON.stringify(run.to_dict())
	_expect(bool(run.world_sequence_resume_delivery_checkpoint().get("inactive",false)) and JSON.stringify(run.to_dict())==before,"Foreign delivery instance was recovered.")
	run.world_sequence_registrations[token]=registration.duplicate(true)
	run.world_sequence_registrations[token]["node_id"]="wrong_node"
	before=JSON.stringify(run.to_dict())
	_expect(bool(run.world_sequence_resume_delivery_checkpoint().get("inactive",false)) and JSON.stringify(run.to_dict())==before,"Offsite delivery was recovered.")
	run.world_sequence_registrations[token]=registration.duplicate(true)
	var cash := run.bankroll
	var rng := run.rng_state
	_expect(bool(run.world_sequence_resume_delivery_checkpoint().get("ok",false)) and run.bankroll==cash+22 and run.rng_state==rng,"Legacy command did not recover its exact owner once the appointment opened.")
