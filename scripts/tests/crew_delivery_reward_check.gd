extends "res://scripts/tests/crew_delivery_obligations_check.gd"

# Synthetic model fixtures plus four real event/owner delivery settlements.
# No player/QA profile is read or changed by this focused contract.
const PACKAGE_JOBS := ["crew_favor_delivery", "rook_quiet_package", "switch_two_stop_signal", "lucky_book_rounds", "bishop_cage_packet", "switch_weather_packet"]

func _run() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty():quit(64);return
	library=ContentLibrary.new();library.load(false)
	if OS.get_environment("BTH_CREW_REWARD_CASE")=="curve":
		var output:=OS.get_environment("BTH_TARGET_OUTPUT")
		if output.is_empty() or not output.is_absolute_path() or not DirAccess.dir_exists_absolute(output.get_base_dir()):
			push_error("Crew reward curve requires an explicit admitted absolute BTH_TARGET_OUTPUT with an existing directory.")
			quit(64);return
		_check_curve()
	elif OS.get_environment("BTH_CREW_REWARD_CASE")=="adjacent":_check_reputation()
	else:_check_caps();_check_job_kinds()
	print("CREW_DELIVERY_REWARD checks=%d failures=%s" % [checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check_caps() -> void:
	var run:=RunState.new();run.start_new("CREW-REWARD-CAPS")
	run.crew_change_reputation(99)
	run.crew_add_trust("crew_rook",5,"fixture_contact")
	check(run.crew_reputation()==100 and run.crew_trust("crew_rook")==5,"ordinary member gain missed cap or changed member reward")
	run.crew_change_reputation(-5)
	check(run.crew_reputation()==95,"penalty at capped standing used hidden excess")
	run.crew_change_reputation(1000)
	check(run.crew_reputation()==100,"direct gain exceeded100")
	run.crew_change_reputation(-1000)
	check(run.crew_reputation()==0,"negative floor changed")
	run.crew_change_reputation(97)
	run.crew_record_poker_session(["crew_mags","crew_velvet"],12)
	check(run.crew_reputation()==100 and run.crew_trust("crew_mags")==2,"settled poker gain exceeded cap or changed base2")
	run.crew_record_poker_session(["crew_mags","crew_velvet"],12)
	check(run.crew_reputation()==100 and run.crew_trust("crew_mags")==5,"poker hustle gain exceeded cap or changed bonus1")
	run.crew_change_reputation(-5)
	check(run.crew_reputation()==95,"poker excess banked above100")
	for old_value in [-20,45,140]:
		var old:=run.to_dict();old["narrative_flags"]["crew_reputation"]=old_value
		var cash:=run.bankroll;var rng:=run.rng_state;var trust:=run.crew_trust_by_member.duplicate(true)
		var migrated:=RunState.new();migrated.from_dict(old)
		check(migrated.crew_reputation()==clampi(old_value,0,100) and int(migrated.narrative_flags.get("crew_reputation",-1))==clampi(old_value,0,100),"saved shared value not normalized")
		check(migrated.bankroll==cash and migrated.rng_state==rng and migrated.crew_trust_by_member==trust,"normalizing shared standing changed money/RNG/relationships")
		migrated=restore(migrated,"crew_reward_cap_%s" % str(old_value))
		check(migrated.crew_reputation()==clampi(old_value,0,100),"cap changed on cold load")
	run.crew_trust_by_member["crew_rook"]=180
	var legacy:=run.to_dict();legacy["narrative_flags"].erase("crew_reputation")
	var migrated:=RunState.new();migrated.from_dict(legacy)
	check(migrated.crew_reputation()==100 and migrated.crew_trust("crew_rook")==180,"legacy highest-member migration exceeded cap or rewrote relationship")
	migrated.crew_change_reputation(-5)
	check(migrated.crew_reputation()==95,"legacy member180 defeated shared penalty")
	check(CrewStateModel.rank_threshold("made")==60 and CrewStateModel.rank_threshold("inner_circle")==90,"access thresholds changed")

func _check_job_kinds() -> void:
	for definition in CrewStateModel.job_definitions():
		for outcome in ["success","failed","abandoned"]:
			var run:=RunState.new();run.start_new("CREW-REWARD-"+str(definition.id)+outcome)
			run.crew_change_reputation(50)
			var cap=run._crew_job_host_capability
			var offered:=run.job_offer(definition,cap);var id:=str(offered.get("id",""))
			run.job_accept(id,cap);run.job_activate(id,cap)
			var before:=run.to_dict();var cash:=run.bankroll;var rng:=run.rng_state
			check(run.job_resolve(id,outcome).is_empty() and run.to_dict()==before,"unauthorized settlement changed state")
			var result:=run.job_resolve(id,outcome,cap)
			var expected:=25 if PACKAGE_JOBS.has(str(definition.id)) else int(definition.rewards.trust)
			if outcome!="success":expected=int(definition.failure.trust)
			check(not result.is_empty() and run.crew_reputation()==50+expected,"wrong shared delta for "+str(definition.id)+":"+outcome)
			var member_delta:=int(definition.rewards.trust) if outcome=="success" else 0
			check(run.crew_trust(str(definition.member_id))==maxi(0,member_delta),"individual relationship reward changed")
			var expected_cash:=cash+int(definition.rewards.cash) if outcome=="success" else cash
			check(run.bankroll==expected_cash and run.rng_state==rng,"job reward changed cash or RNG")
			var settled:=run.to_dict()
			check(run.job_resolve(id,outcome,cap).is_empty() and run.to_dict()==settled,"repeat settlement rewarded again")
			var continued:=RunState.new();continued.from_dict(settled)
			check(continued.job_resolve(id,outcome,continued._crew_job_host_capability).is_empty() and continued.crew_reputation()==50+expected and continued.bankroll==expected_cash,"restored completed job rewarded again")

func _check_curve() -> void:
	var run:=delivery_fixture("CREW-REWARD-FOUR-DELIVERIES",4)
	run.crew_change_reputation(-run.crew_reputation())
	var curve: Array = [run.crew_reputation()]
	for index in range(4):
		accept(run)
		var target:=str(run.delivery_snapshot().get("targets",[{}])[0].get("node_id",""))
		Fidelity.travel_and_finalize(RunGenerator.new(library),run,target,true,library,failures,"Crew reward curve target")
		var window:=Schedule.window_for(run.active_delivery_run,target)
		run.advance_game_clock_minutes(maxi(0,int(window.get("opens",0))-run.game_clock_minutes))
		run.delivery_resolve_travel_arrival({}, {})
		if run.scenario_sequence_present():run.scenario_finalize_installed_environment(library,{"viewport_size":{"x":1280,"y":720}})
		else:run.world_sequence_finalize_base_semantics([],library,{"viewport_size":{"x":1280,"y":720}})
		if index==3:
			check(SaveService.new().save_run(run,"foundation_ui_autosave")==OK,"prepared fourth handoff save failed")
			var export_dir:=OS.get_environment("BTH_TARGET_OUTPUT").get_base_dir()
			var authority:=ProjectSettings.globalize_path("user://.crew_host_authority_v1")
			check(FileAccess.file_exists(authority) and DirAccess.copy_absolute(authority,export_dir.path_join("crew-authority.bin"))==OK,"prepared handoff authority missing")
		var dispatched:=_dispatch_handoff(run,"crew-reward:handoff:%d" % index)
		var token:=str(dispatched.get("token",""));var cash:=run.bankroll;var rng:=run.rng_state
		var settled:=run.world_sequence_checkpoint_delivery_outcome(token,target)
		check(bool(dispatched.get("command",{}).get("ok",false)) and bool(settled.get("ok",false)),"curve handoff rejected "+str(index))
		check(run.crew_reputation()==25*(index+1) and run.bankroll==cash+22 and run.crew_delivery_obligation_count()==3-index,"curve/obligation/payment wrong "+str(index))
		check(run.rng_state==rng,"handoff consumed game RNG")
		# Match the Host's complete consequence/acknowledgement/cleanup boundary.
		# Materialization alone leaves the old handoff's exclusive owner pending.
		var materialized:=run.world_sequence_materialize_delivery_checkpoint(token)
		check(bool(materialized.get("ok",false)),"handoff materialization succeeds")
		var pending:=run.world_sequence_pending_outcomes(token)
		check(pending.size()==1,"one handoff receipt awaits Host consumption")
		for receipt in pending:
			var consumed:=run.world_sequence_consume_delivery_outcome(token,str(receipt.get("receipt_id","")),target)
			check(bool(consumed.get("ok",false)),"Host consumes and cleans handoff: "+JSON.stringify(consumed.get("errors",[])))
		check(run.world_sequence_pending_outcomes(token).is_empty(),"handoff has no stranded pending outcome")
		var reputation:=run.crew_reputation();var after_cash:=run.bankroll
		run.world_sequence_checkpoint_delivery_outcome(token,target)
		check(run.crew_reputation()==reputation and run.bankroll==after_cash,"checkpoint retry duplicated reward")
		run=restore(run,"crew_reward_curve_%d" % index)
		run.world_sequence_checkpoint_delivery_outcome(token,target)
		check(run.crew_reputation()==reputation and run.bankroll==after_cash and run.crew_delivery_obligation_count()==3-index,"Continue repeated reward")
		curve.append(run.crew_reputation())
		if index<3:
			run.current_environment["crew_presence"]=[{"member_id":"crew_rook"}];run.reconcile_current_environment_object_manifest(true)
			check(bool(run.advance_game_clock_minutes(360).get("ok",false)),"fixture cooldown advance succeeds")
	check(curve==[0,25,50,75,100],"four-success earning curve wrong")
	var result={"curve":curve,"checks":checks,"failures":failures,"final_reputation":run.crew_reputation(),"final_obligations":run.crew_delivery_obligation_count(),"fidelity":"Synthetic generated campaign; four normal event accepts, production travel/appointment and authorized physical handoff checkpoints, real SaveService/Continue; prepared pre-fourth checkpoint exported for separate Web normal-control verification."}
	var file:=FileAccess.open(OS.get_environment("BTH_TARGET_OUTPUT"),FileAccess.WRITE)
	check(file!=null,"reward curve output opens")
	if file==null:return
	result["checks"]=checks
	result["failures"]=failures.duplicate()
	file.store_string(JSON.stringify(result,"  ")+"\n");file.close()


func restore(run: RunState, slot: String) -> RunState:
	var loaded:=super.restore(run,slot)
	# Reputation-cap migration fixtures have no installed room to publish.
	if loaded.current_environment.is_empty():return loaded
	var protected:={"cash":loaded.bankroll,"chips":loaded.grand_casino_chips,"rng":loaded.rng_state,"reputation":loaded.crew_reputation(),"obligations":loaded.crew_delivery_obligation_count()}
	# SaveService intentionally omits derived scenario proofs. Ordinary Continue
	# rebuilds them before any room action; reproduce only its trusted restore gate.
	if loaded.scenario_sequence_present() and bool(loaded.current_environment.get("scenario_restore_pending_trusted_rebuild",false)):
		var rebuilt:=loaded.scenario_finalize_installed_environment(library,{"viewport_size":{"x":1280,"y":720}})
		check(bool(rebuilt.get("ok",false)),"Continue finalization succeeds: "+JSON.stringify(rebuilt.get("errors",[])))
	check(bool(loaded.validate_room_action_authority().get("ok",false)),"restored room authority valid before next action")
	check(protected=={"cash":loaded.bankroll,"chips":loaded.grand_casino_chips,"rng":loaded.rng_state,"reputation":loaded.crew_reputation(),"obligations":loaded.crew_delivery_obligation_count()},"derived rebuild does not transact or advance RNG")
	return loaded
