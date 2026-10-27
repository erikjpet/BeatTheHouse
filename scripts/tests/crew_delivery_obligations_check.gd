extends SceneTree

# Focused synthetic fixtures; borrowing uses the normal detached hook transaction,
# delivery uses the real event/sequence/owner checkpoint and SaveService.
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const Main := preload("res://scripts/ui/foundation_main.gd")
const Schedule := preload("res://scripts/core/crew_delivery_schedule.gd")
var library: ContentLibrary
var failures: Array = []
var checks := 0

class HourlyClockHost:
	extends "res://scripts/ui/foundation_main.gd"
	var observed_refreshes := 0
	var observed_saves := 0
	func _refresh() -> void: observed_refreshes += 1
	func _autosave_foundation_run(_status_text: String = "Autosaved.", _force: bool = false) -> bool:
		observed_saves += 1
		return true
	# Closing/travel view scripts are lazily loaded by a rendered host. This
	# focused observer keeps that unrelated boundary outside the clock contract.
	func _apply_closing_time_clock_boundary() -> bool: return false

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message);print("CHECK FAILED: "+message)

# These existing obligation cases select a known successful cadence fixture.
# The separate hourly check exercises failures, the 25% boundary and persistence.
func queue_offer(run: RunState, source: String = "game_action", context: Dictionary = {}, overrides: Dictionary = {}) -> bool:
	if run.crew_package_solicitation_available() and not run.triggered_event_pending("crew_favor_delivery") and run.game_clock_minutes >= int(run.narrative_flags.get("crew_package_next_attempt_clock", 0)):
		run.narrative_flags["crew_package_offer_rng_state"] = 48
	return run.enqueue_triggered_event("crew_favor_delivery", source, context, overrides)

func fixture(lender_ids: Array, seed: String) -> RunState:
	var run := RunState.new();run.start_new(seed);run.bankroll=100
	var archetype: Dictionary = {}
	for value in library.environment_archetypes:
		if str(value.get("id",""))=="back_alley":archetype=value.duplicate(true);break
	archetype["lender_hooks"]=lender_ids.duplicate();archetype["required_lender_hooks"]=lender_ids.duplicate();archetype["lender_count"]=[lender_ids.size(),lender_ids.size()]
	archetype["event_pool"]=[];archetype["event_count"]=[0,0]
	run.set_environment(EnvironmentInstance.from_archetype(archetype,1,run.create_rng(seed),library).to_dict())
	return run

func restore(run: RunState, slot: String) -> RunState:
	var saves := SaveService.new();check(saves.save_run(run,slot)==OK,"Save failed "+slot)
	var loaded: Variant=SaveService.new().load_run(slot)
	check(loaded is RunState,"Continue failed "+slot)
	return loaded if loaded is RunState else run

func _run() -> void:
	if OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_empty():quit(64);return
	library=ContentLibrary.new();library.load()
	if OS.get_environment("BTH_CREW_RULES_CASE")=="loans":_check_borrows()
	elif OS.get_environment("BTH_CREW_RULES_CASE")=="denial":_check_miss_and_denial()
	elif OS.get_environment("BTH_CREW_RULES_CASE")=="reputation_hourly":_check_hourly();_check_reputation()
	elif OS.get_environment("BTH_CREW_RULES_CASE")=="legacy_blackjack":_check_legacy_blackjack_route()
	elif OS.get_environment("BTH_CREW_RULES_CASE")=="clock_presentation":_check_clock_presentation();_check_reputation()
	elif OS.get_environment("BTH_CREW_RULES_CASE")=="first_meeting_presence":_check_first_meeting_presence()
	elif OS.get_environment("BTH_CREW_RULES_CASE")=="voluntary_context":_check_voluntary_context();_check_miss_and_denial()
	else:_check_borrows();_check_migration();_check_stale_presence();_check_delivery();_check_first_meeting_presence()
	print("CREW_DELIVERY_OBLIGATIONS checks=%d failures=%s" % [checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _check_borrows() -> void:
	var run:=fixture(["the_crew"],"CREW-OBLIGATIONS-BORROW")
	var service:=RunActionService.new();service.setup(library,run)
	var rng:=run.rng_state
	check(str(service.hook_option("lender","the_crew").get("terms_summary","")).contains("total after this borrow: 2"),"first borrow quote does not show resulting total2")
	var first:=service.use_hook("lender","the_crew")
	check(bool(first.get("ok",false)),"first borrow rejected: "+str(first))
	check(run.bankroll==170 and run.crew_delivery_obligation_count()==2 and run.debt.is_empty(),"first borrow must add70 and2 obligations without debt")
	check(not bool(run.lender_repayment_status("the_crew").get("available",false)),"Crew has a repayment action")
	var blocked:=service.hook_option("lender","the_crew")
	check(str(blocked.get("terms_summary","")).contains("2 Crew deliveries owed") and not str(blocked.get("summary","")).contains("Receive $0"),"blocked Crew card presents a zero-dollar offer")
	var after:=var_to_bytes(run.to_dict())
	check(not bool(service.use_hook("lender","the_crew").get("ok",false)),"duplicate confirmation accepted")
	check(var_to_bytes(run.to_dict())==after,"duplicate confirmation mutated cash/obligations/RNG")
	run.current_environment["id"]="crew_second_location";run.reconcile_current_environment_object_manifest(true)
	check(str(service.hook_option("lender","the_crew").get("terms_summary","")).contains("total after this borrow: 4"),"second borrow quote does not show resulting total4")
	check(bool(service.use_hook("lender","the_crew").get("ok",false)),"second location borrow rejected")
	check(run.bankroll==240 and run.crew_delivery_obligation_count()==4 and run.debt.is_empty(),"two borrows must add140 and4 obligations without debt")
	check(run.rng_state==rng,"borrowing consumed game RNG")
	run=restore(run,"crew_obligations_four")
	check(run.bankroll==240 and run.crew_delivery_obligation_count()==4 and run.debt.is_empty(),"Continue changed borrowing settlement")
	var context:Dictionary={"trigger":"action","type":"action","source":"event_choice","turns":maxi(1,int(run.current_environment.get("turns",0)))}
	var shortlisted:=false
	for candidate in library.action_trigger_event_candidates_for_context_readonly("event_choice",context,run.current_environment):
		if str(candidate.get("id",""))=="crew_favor_delivery":shortlisted=true
	var favor:=EventModule.new();favor.setup(library.event("crew_favor_delivery"),library)
	check(shortlisted and favor.can_trigger(run,run.current_environment,context),"automatic action path omitted an eligible Crew request")
	check(run.event_cadence_allows_world_event("crew_favor_delivery","random","event_choice",library.event("crew_favor_delivery")),"automatic cadence blocked an eligible Crew request")
	service.setup(library,run)
	var terms:=service.lender_loan_terms(library.lender("the_crew"),{"bankroll_delta":70})
	check(int(terms.get("repayment_total",-1))==0 and int(terms.get("delivery_obligations_added",0))==2 and str(terms.get("summary","")).contains("No cash repayment"),"Crew terms still present monetary debt")
	var other:=fixture(["street_lender"],"CREW-UNRELATED-LOAN")
	service.setup(library,other)
	check(bool(service.use_hook("lender","street_lender").get("ok",false)) and other.debt.size()==1 and str(other.debt[0].get("debt_kind",""))=="cash" and other.crew_delivery_obligation_count()==0,"unrelated lender changed")

func _check_migration() -> void:
	var run:=fixture(["the_crew"],"CREW-LEGACY-OPEN")
	var old:=run.to_dict();old["narrative_flags"]={"crew_favor_pending":true}
	old["debt"]=[{"id":"the_crew_marker","lender_id":"the_crew","debt_kind":"favor","loan_count":2,"balance":1,"principal":70,"status":"favor_due","source_location_ids":["one","two"]},{"id":"other_note","lender_id":"motel_friend","debt_kind":"cash","balance":31,"status":"active","turns_remaining":5}]
	var migrated:=RunState.new();migrated.from_dict(old)
	check(migrated.crew_delivery_obligation_count()==3,"open legacy borrow/completion credit migration wrong")
	check(migrated.debt.size()==1 and str(migrated.debt[0].get("id",""))=="other_note" and migrated.bankroll==100,"migration altered cash/non-Crew debt")
	var saved:=migrated.to_dict();var again:=RunState.new();again.from_dict(saved)
	check(again.crew_delivery_obligation_count()==3 and again.debt==migrated.debt,"migration repeated on Continue")
	old["debt"]=[];old["narrative_flags"]={"crew_marker_clear":true}
	migrated.from_dict(old)
	check(migrated.crew_delivery_obligation_count()==0,"cleared historical borrowing reopened")
	old["debt"]=[{"id":"legacy_cash","lender_id":"the_crew","debt_kind":"cash","loan_count":1,"balance":94,"status":"overdue"}]
	migrated.from_dict(old)
	check(migrated.debt.is_empty() and migrated.crew_delivery_obligation_count()==2,"converted Crew cash debt survived migration")
	old["debt"]=[{"id":"legacy_unknown","lender_id":"the_crew","debt_kind":"favor","balance":2,"status":"favor_due"}]
	migrated.from_dict(old)
	check(migrated.crew_delivery_obligation_count()==2 and bool(migrated.narrative_flags.get("crew_delivery_migration",{}).get("unknown_historical_borrow_count",false)),"missing historical count fabricated or lost known favors")
	old["debt"]=[{"id":"legacy_paid","lender_id":"the_crew","debt_kind":"cash","loan_count":1,"balance":0,"status":"paid"}]
	migrated.from_dict(old)
	check(migrated.debt.is_empty() and migrated.crew_delivery_obligation_count()==0,"paid legacy debt reopened")

func _check_stale_presence() -> void:
	var run:=fixture(["the_crew"],"CREW-STALE-PRESENCE")
	run.narrative_flags["crew_delivery_obligations"]=2
	check(queue_offer(run,"game_action",{}, {"presentation":"talk"}),"stale fixture offer was not queued with Crew present")
	var prior_environment:=run.current_environment.duplicate(true)
	run.current_environment["lender_hooks"]=[];run.current_environment["crew_presence"]=[]
	run.reconcile_current_environment_object_manifest(true)
	check(bool(run.validate_room_action_authority().get("ok",false)),"stale fixture absence is not an authoritative room")
	var module:=EventModule.new();module.setup(library.event("crew_favor_delivery"),library)
	var before:=var_to_bytes(run.to_dict())
	check(not bool(module.resolve(run,prior_environment,"run_package").get("ok",false)),"old room snapshot authorized absent Crew acceptance")
	check(var_to_bytes(run.to_dict())==before and not run.delivery_has_active_run(),"stale acceptance mutated state")

func delivery_fixture(seed: String, owed: int) -> RunState:
	var run:=RunState.new();run.start_new(seed)
	var generator:=RunGenerator.new(library)
	Fidelity.generate_and_finalize(generator,run,failures,seed)
	Fidelity.travel_and_finalize(generator,run,"bar",true,library,failures,seed+" bar")
	run.current_environment["crew_presence"]=[{"member_id":"crew_rook"}]
	run.reconcile_current_environment_object_manifest(true)
	run.narrative_flags["crew_delivery_obligations"]=owed
	run.crew_add_trust("crew_rook",50,"fixture")
	return run

func accept(run: RunState) -> Dictionary:
	check(queue_offer(run,"game_action",{}, {"presentation":"talk"}),"request enqueue rejected")
	var host:=Main.new();host.run_state=run;host.library=library
	var module: EventModule=host._crew_delivery_event_module(library.event("crew_favor_delivery"))
	var choice_id:="run_package_after_miss" if bool(run.narrative_flags.get("crew_delivery_post_miss",false)) else "run_package"
	module.choice_views(run,run.current_environment)
	var result:=module.resolve(run,run.current_environment,choice_id)
	run.complete_talk_event_resolution("crew_favor_delivery");host.free()
	check(bool(result.get("ok",false)) and run.delivery_has_active_run(),"accept failed: "+str(result))
	return result

func _check_delivery() -> void:
	var run:=delivery_fixture("CREW-OBLIGATIONS-DELIVERY",4)
	var module:=EventModule.new();module.setup(library.event("crew_favor_delivery"),library)
	var no_crew:=run.to_dict();no_crew["current_environment"]["crew_presence"]=[];no_crew["current_environment"]["lender_hooks"]=[]
	# Remove all physical Crew sources, including unrecruited first meetings.
	for member_id in CrewStateModel.MEMBER_IDS:
		(no_crew["current_environment"]["event_ids"] as Array).erase(str(CrewRecruitmentModel.member_definition(str(member_id)).get("event_id","")))
	var absent:=RunState.new();absent.from_dict(no_crew)
	check(not absent.crew_package_solicitation_available() and not absent.enqueue_triggered_event("crew_favor_delivery"),"absent Crew generated request")
	accept(run)
	var original:=run.active_delivery_run.duplicate(true);var sequence:=run.crew_job_sequence
	var active_legacy:=run.to_dict()
	for i in range(3):
		check(not bool(run.resolve_crew_favor_delivery_job("run_package").get("ok",false)) and not run.enqueue_triggered_event("crew_favor_delivery"),"active assignment permitted duplicate request/accept")
	check(not bool(run.crew_job_accept_definition("rook_quiet_package").get("ok",false)),"other Crew source replaced active package")
	check(run.active_delivery_run==original and run.crew_job_sequence==sequence and run.crew_delivery_obligation_count()==4,"duplicate changed active assignment or queue")
	run=restore(run,"crew_obligations_active")
	check(run.active_delivery_run==original and run.inventory.count("crew_package")==1,"active job changed on Continue")
	var target:=str(run.delivery_snapshot().get("targets",[{}])[0].get("node_id",""))
	var generator:=RunGenerator.new(library)
	Fidelity.travel_and_finalize(generator,run,target,true,library,failures,"Crew obligation target")
	var window:=Schedule.window_for(run.active_delivery_run,target)
	run.advance_game_clock_minutes(maxi(0,int(window.get("opens",0))-run.game_clock_minutes))
	run.delivery_resolve_travel_arrival({}, {})
	if run.scenario_sequence_present():run.scenario_finalize_installed_environment(library,{"viewport_size":{"x":1280,"y":720}})
	else:run.world_sequence_finalize_base_semantics([],library,{"viewport_size":{"x":1280,"y":720}})
	var final_obligation_state:=run.to_dict()
	var dispatched:=_dispatch_handoff(run,"crew-obligations:handoff")
	var token:=str(dispatched.get("token",""));var command:Dictionary=dispatched.get("command",{})
	check(bool(command.get("ok",false)),"authorized handoff command failed: "+str(command))
	var cash:=run.bankroll
	var before_reputation := run.crew_reputation()
	var settled:=run.world_sequence_checkpoint_delivery_outcome(token,target)
	check(bool(settled.get("ok",false)) and run.bankroll==cash+22 and run.crew_delivery_obligation_count()==3,"success did not satisfy exactly one obligation: "+str(settled))
	check(run.crew_reputation()==mini(100,before_reputation+25),"success must reward shared reputation25 once, capped100")
	run.world_sequence_materialize_delivery_checkpoint(token)
	var anchor:=int(run.narrative_flags.get("crew_package_next_offer_clock",0))
	check(anchor==run.game_clock_minutes+360,"success did not restart six-hour cooldown")
	run=restore(run,"crew_obligations_success")
	run.world_sequence_checkpoint_delivery_outcome(token,target)
	check(run.bankroll==cash+22 and run.crew_delivery_obligation_count()==3,"success repeated on Continue/retry")
	check(run.crew_reputation()==mini(100,before_reputation+25),"success reputation repeated on Continue/retry")
	var legacy:=active_legacy;legacy["narrative_flags"].erase("crew_delivery_rules_version");legacy["narrative_flags"].erase("crew_delivery_obligations")
	# An active legacy package without recoverable borrow history must survive.
	var migrated:=RunState.new();migrated.from_dict(legacy)
	check(migrated.delivery_has_active_run() and str(migrated.active_delivery_run.get("job_id",""))==str(original.get("job_id","")) and migrated.crew_delivery_obligation_count()>=1,"active legacy package lost in migration")
	run.current_environment["crew_presence"]=[{"member_id":"crew_rook"}];run.reconcile_current_environment_object_manifest(true)
	run.advance_game_clock_minutes(anchor-run.game_clock_minutes-1)
	check(not run.crew_package_solicitation_available(),"success cooldown released at359")
	run.advance_game_clock_minutes(1)
	check(run.crew_package_solicitation_available(),"success cooldown blocked at360")
	_check_last_obligation(final_obligation_state,target)
	_check_board_package()
	_check_miss_and_denial()

func _dispatch_handoff(run: RunState, receipt: String) -> Dictionary:
	var interactions:Dictionary=run.world_sequence_composed_projection().get("semantic_state",{}).get("interactions",{})
	for interaction in interactions.values():
		for action in interaction.get("available_actions",[]):
			if str(action.get("id",""))!="make_handoff":continue
			var token:=str(action.get("world_sequence_owner_token",interaction.get("world_sequence_owner_token","")))
			var options:Dictionary={"owner_namespace":"crew","stable_object_id":"package_handoff","host_interaction_availability":{"crew::package_handoff":true}}
			for key in ["action_origin_owner_namespace","action_origin_stable_object_id","action_origin_receipt_key","action_origin_boundary_id","action_origin_fingerprint"]:options[key]=str(action.get(key,""))
			return {"token":token,"command":run.world_sequence_command(FunctionOptions.world_sequence_command(token,"make_handoff",receipt,options))}
	return {}

func _check_last_obligation(prepared_state: Dictionary, target: String) -> void:
	# A separate synthetic branch at the real prepared owner boundary exercises
	# the final-duty threshold and post-miss recovery without replaying a player.
	var run:=RunState.new();run.from_dict(prepared_state)
	run.narrative_flags["crew_delivery_obligations"]=1
	run.narrative_flags["crew_delivery_post_miss"]=true
	run.narrative_flags["crew_delivery_loan_locations"]=["completed_source"]
	if run.scenario_sequence_present():run.scenario_finalize_installed_environment(library,{"viewport_size":{"x":1280,"y":720}})
	else:run.world_sequence_finalize_base_semantics([],library,{"viewport_size":{"x":1280,"y":720}})
	var dispatched:=_dispatch_handoff(run,"crew-obligations:last")
	check(bool(dispatched.get("command",{}).get("ok",false)),"last obligation handoff rejected")
	var token:=str(dispatched.get("token",""))
	check(bool(run.world_sequence_checkpoint_delivery_outcome(token,target).get("ok",false)),"last obligation settlement rejected")
	run.world_sequence_materialize_delivery_checkpoint(token)
	check(run.crew_delivery_obligation_count()==0 and not bool(run.narrative_flags.get("crew_delivery_post_miss",true)) and run.narrative_flags.get("crew_delivery_loan_locations",[])==[],"last success failed to clear queue/miss context/locations")
	run=restore(run,"crew_obligations_cleared")
	run.advance_game_clock_minutes(360);run.advance_environment_turns(5)
	check(run.crew_delivery_obligation_count()==0 and not run.enqueue_triggered_event("crew_favor_delivery"),"cleared queue resumed unsolicited requests")

func _check_board_package(owed: int = 2, post_miss: bool = false) -> RunState:
	var run:=delivery_fixture("CREW-OBLIGATIONS-BOARD",owed)
	run.narrative_flags["crew_delivery_post_miss"]=post_miss
	var started:=run.crew_job_accept_definition("rook_quiet_package")
	check(bool(started.get("ok",false)),"manual Crew package did not start")
	if str(run.delivery_snapshot().get("physical",{}).get("cargo_state",""))=="pickup_pending":
		check(bool(run.delivery_apply_physical_action("pickup","crew-obligations:board-pickup").get("ok",false)),"manual package pickup failed")
	var target:=str(run.delivery_snapshot().get("targets",[{}])[0].get("node_id",""))
	Fidelity.travel_and_finalize(RunGenerator.new(library),run,target,true,library,failures,"Crew board target")
	var window:=Schedule.window_for(run.active_delivery_run,target)
	run.advance_game_clock_minutes(maxi(0,int(window.get("opens",0))-run.game_clock_minutes))
	run.delivery_resolve_travel_arrival({}, {})
	var completed:=run.delivery_complete_handoff()
	if not bool(completed.get("ok",false)):print("CREW_BOARD_HANDOFF ",JSON.stringify(completed))
	check(bool(completed.get("ok",false)) and run.crew_delivery_obligation_count()==maxi(0,owed-1),"manual Crew package settled the wrong obligation count")
	check(int(run.narrative_flags.get("crew_package_next_offer_clock",0))==run.game_clock_minutes+360,"manual package end bypassed Crew cooldown")
	if post_miss: check(not bool(run.narrative_flags.get("crew_delivery_post_miss",true)),"successful voluntary Crew delivery did not clear post-miss context")
	return run

func _check_voluntary_context() -> void:
	var succeeded := _check_board_package(0,true)
	succeeded=restore(succeeded,"crew_voluntary_success_context")
	check(succeeded.crew_delivery_obligation_count()==0 and not bool(succeeded.narrative_flags.get("crew_delivery_post_miss",true)),"voluntary success/Continue retained pushy context or created a duty")
	var missed := delivery_fixture("CREW-VOLUNTARY-MISS-CONTEXT",0)
	check(bool(missed.crew_job_accept_definition("rook_quiet_package").get("ok",false)),"voluntary miss fixture did not start")
	if str(missed.delivery_snapshot().get("physical",{}).get("cargo_state",""))=="pickup_pending":
		check(bool(missed.delivery_apply_physical_action("pickup","crew-voluntary-context-pickup").get("ok",false)),"voluntary miss fixture pickup failed")
	missed.advance_game_clock_minutes(Schedule.next_deadline(missed.active_delivery_run)-missed.game_clock_minutes)
	check(not missed.delivery_has_active_run() and missed.crew_delivery_obligation_count()==0 and bool(missed.narrative_flags.get("crew_delivery_post_miss",false)),"voluntary miss did not retain pushy context without creating a duty")
	check(not missed.enqueue_triggered_event("crew_favor_delivery"),"voluntary miss created unsolicited work at zero duties")
	missed=restore(missed,"crew_voluntary_missed_context")
	check(missed.crew_delivery_obligation_count()==0 and bool(missed.narrative_flags.get("crew_delivery_post_miss",false)),"Continue lost voluntary post-miss context")

func _check_miss_and_denial() -> void:
	var run:=delivery_fixture("CREW-OBLIGATIONS-MISS",2)
	var initial_reputation := run.crew_reputation()
	accept(run)
	run.advance_game_clock_minutes(Schedule.next_deadline(run.active_delivery_run)-run.game_clock_minutes)
	check(not run.delivery_has_active_run() and run.crew_delivery_obligation_count()==2 and bool(run.narrative_flags.get("crew_delivery_post_miss",false)),"miss satisfied obligation or lost pushy context")
	check(run.crew_reputation()==initial_reputation-5,"miss must reduce shared reputation once")
	var anchor:=int(run.narrative_flags.get("crew_package_next_offer_clock",0))
	check(anchor==run.game_clock_minutes+360,"miss did not restart six-hour cooldown")
	run=restore(run,"crew_obligations_missed")
	check(run.crew_reputation()==initial_reputation-5,"miss reputation repeated on Continue")
	run.advance_environment_turns(10)
	check(not run.crew_package_solicitation_available(),"old turn pressure bypassed cooldown")
	run.advance_game_clock_minutes(anchor-run.game_clock_minutes-1)
	check(not run.crew_package_solicitation_available(),"miss cooldown released at359")
	run.advance_game_clock_minutes(1)
	check(run.crew_package_solicitation_available(),"miss cooldown blocked at360")
	check(queue_offer(run,"game_action",{}, {"presentation":"talk"}),"post-miss request not queued")
	var module:=EventModule.new();module.setup(library.event("crew_favor_delivery"),library)
	var ids:Array=[]
	for choice in module.choices(run,run.current_environment):ids.append(choice.get("id"))
	check(ids.has("refuse_after_miss") and ids.has("run_package_after_miss") and not ids.has("refuse"),"post-miss choices not distinct")
	var prior_heat:=run.suspicion_level()
	check(not bool(module.resolve(run,run.current_environment,"refuse").get("ok",false)) and run.suspicion_level()==prior_heat,"stale normal refusal bypassed pushy response")
	var heat:=run.suspicion_level()
	var boundary_preview:=run.detached_host_action_candidate()
	boundary_preview.advance_environment_turns(1)
	var boundary_heat:=boundary_preview.suspicion_level()
	var refusal_reputation := run.crew_reputation()
	var refused:=module.resolve(run,run.current_environment,"refuse_after_miss")
	run.complete_talk_event_resolution("crew_favor_delivery")
	print("CREW_POSTMISS_DENIAL ",JSON.stringify({"ok":refused.get("ok"),"message":refused.get("message"),"heat_before":heat,"heat_after":run.suspicion_level(),"authored_heat":refused.get("suspicion_delta"),"owed":run.crew_delivery_obligation_count(),"post_miss":run.narrative_flags.get("crew_delivery_post_miss")}))
	check(bool(refused.get("ok",false)) and int(refused.get("suspicion_delta",0))==18 and run.suspicion_level()==boundary_heat+18 and run.crew_delivery_obligation_count()==2 and bool(run.narrative_flags.get("crew_delivery_post_miss",false)),"post-miss denial Heat/queue/context wrong")
	check(run.crew_reputation()==refusal_reputation-5,"pushy refusal reputation must be one standard job failure")
	check(int(run.narrative_flags.get("crew_package_next_offer_clock",0))==run.game_clock_minutes+360,"denial did not restart request cooldown")
	run=restore(run,"crew_obligations_pushy_refused")
	check(run.crew_reputation()==refusal_reputation-5,"refusal reputation repeated on Continue")
	check(run.crew_delivery_obligation_count()==2 and bool(run.narrative_flags.get("crew_delivery_post_miss",false)),"refusal/Continue erased post-miss context")
	var normal:=delivery_fixture("CREW-OBLIGATIONS-DENIAL",2)
	check(queue_offer(normal,"game_action",{}, {"presentation":"talk"}),"normal request not queued")
	module=EventModule.new();module.setup(library.event("crew_favor_delivery"),library)
	heat=normal.suspicion_level();refused=module.resolve(normal,normal.current_environment,"refuse")
	check(bool(refused.get("ok",false)) and normal.suspicion_level()==heat+9 and normal.crew_delivery_obligation_count()==2,"normal denial Heat/obligations changed")
	normal.complete_talk_event_resolution("crew_favor_delivery")
	normal=restore(normal,"crew_obligations_normal_refused")
	var refusal_anchor:=int(normal.narrative_flags.get("crew_package_next_offer_clock",0))
	normal.advance_game_clock_minutes(refusal_anchor-normal.game_clock_minutes-1)
	check(not normal.crew_package_solicitation_available(),"request cooldown released at359")
	normal.advance_game_clock_minutes(1)
	check(normal.crew_package_solicitation_available(),"request cooldown blocked at360")

func _check_hourly() -> void:
	var run := fixture(["the_crew"], "CREW-HOURLY-PERSISTENCE")
	run.narrative_flags["crew_delivery_rules_version"] = 1
	run.crew_change_reputation(0)
	run.narrative_flags["crew_delivery_obligations"] = 2
	run.narrative_flags["crew_package_next_offer_clock"] = run.game_clock_minutes + 360
	var anchor := int(run.narrative_flags["crew_package_next_offer_clock"])
	run.advance_game_clock_minutes(359)
	check(not run.enqueue_triggered_event("crew_favor_delivery") and not run.narrative_flags.has("crew_package_last_attempt_hour"), "cooldown359 consumed an hourly roll")
	run.advance_game_clock_minutes(1)
	run.event_cadence_note_modal_closed()
	check(run.event_cadence_allows_world_event("crew_favor_delivery","random","crew_hourly",library.event("crew_favor_delivery")), "old one-action popup breather blocked a cooled-down hourly opportunity")
	var hourly_module := EventModule.new();hourly_module.setup(library.event("crew_favor_delivery"),library)
	check(hourly_module.can_trigger(run,run.current_environment,{}), "zero-turn hourly request failed the obsolete action trigger")
	var host := Main.new();host.run_state=run;host.library=library;host.current_screen=Main.SCREEN_ENVIRONMENT
	check(host._crew_hourly_room_boundary_ready(), "idle room cannot check the current hourly opportunity")
	host.current_screen=Main.SCREEN_GAME
	check(not host._crew_hourly_room_boundary_ready(), "hourly request could interrupt a game surface/reveal")
	host.current_screen=Main.SCREEN_ENVIRONMENT;host.travel_transition_active=true
	check(not host._crew_hourly_room_boundary_ready(), "hourly request could interrupt travel")
	host.travel_transition_active=false;host._event_response_transaction={"probe":true}
	check(not host._crew_hourly_room_boundary_ready(), "hourly request could mutate an owned event transaction")
	host._event_response_transaction={};host.free()
	run.narrative_flags["crew_package_offer_rng_state"] = 1 # Next roll72 fails.
	var wager_rng := run.rng_state
	check(not run.enqueue_triggered_event("crew_favor_delivery"), "cooldown expiry guaranteed a request")
	check(int(run.narrative_flags.get("crew_package_last_attempt_roll",0))==72 and int(run.narrative_flags.get("crew_package_next_attempt_clock",0))==anchor+60, "first eligible opportunity did not record one25percent roll")
	var flags := run.narrative_flags.duplicate(true)
	for index in range(4): run.enqueue_triggered_event("crew_favor_delivery")
	check(run.narrative_flags==flags and run.rng_state==wager_rng, "repeated clicks rerolled or consumed wager RNG")
	run=restore(run,"crew_hourly_failed_roll")
	check(not run.enqueue_triggered_event("crew_favor_delivery") and int(run.narrative_flags.get("crew_package_offer_rng_state",0))==48271 and int(run.narrative_flags.get("crew_package_next_attempt_clock",0))==anchor+60 and run.crew_delivery_obligation_count()==2, "Continue rerolled the failed hour")
	flags=run.narrative_flags.duplicate(true)
	run.advance_game_clock_minutes(59)
	check(not run.enqueue_triggered_event("crew_favor_delivery") and run.narrative_flags==flags, "hourly opportunity released before60minutes")
	run.current_environment["id"]="crew_hourly_reentry"
	check(not run.enqueue_triggered_event("crew_favor_delivery") and run.narrative_flags==flags, "travel/reentry manufactured another roll")
	run.advance_game_clock_minutes(1)
	run.narrative_flags["crew_package_offer_rng_state"] = 48 # Next roll9 succeeds.
	check(run.enqueue_triggered_event("crew_favor_delivery","crew_hourly",{}, {"presentation":"talk"}), "next hourly25percent success did not queue")
	check(run.pending_triggered_events.size()==1 and int(run.narrative_flags.get("crew_package_last_attempt_roll",0))==9, "successful hour queued multiple requests")
	flags=run.narrative_flags.duplicate(true)
	check(not run.enqueue_triggered_event("crew_favor_delivery") and run.narrative_flags==flags, "pending request permitted another attempt")
	var absent := fixture([],"CREW-HOURLY-NO-BANK")
	absent.narrative_flags["crew_delivery_obligations"]=2
	absent.advance_game_clock_minutes(720)
	check(not absent.enqueue_triggered_event("crew_favor_delivery") and not absent.narrative_flags.has("crew_package_last_attempt_hour"), "absent hours banked attempts")
	absent.current_environment["crew_presence"]=[{"member_id":"crew_rook"}]
	absent.narrative_flags["crew_package_offer_rng_state"]=1
	check(not absent.enqueue_triggered_event("crew_favor_delivery") and int(absent.narrative_flags.get("crew_package_offer_rng_state",0))==48271, "return burst rolled more than the current hour")
	absent.advance_game_clock_minutes(600)
	check(not absent.enqueue_triggered_event("crew_favor_delivery") and int(absent.narrative_flags.get("crew_package_offer_rng_state",0))==182605794, "multi-hour jump replayed skipped hourly rolls")
	for boundary in [{"seed":44,"roll":25,"queued":true},{"seed":75,"roll":26,"queued":false}]:
		var threshold := fixture(["the_crew"],"CREW-CHANCE-BOUNDARY-%d" % int(boundary["roll"]))
		threshold.narrative_flags["crew_delivery_obligations"]=2
		threshold.narrative_flags["crew_package_offer_rng_state"]=int(boundary["seed"])
		check(threshold.enqueue_triggered_event("crew_favor_delivery")==bool(boundary["queued"]) and int(threshold.narrative_flags.get("crew_package_last_attempt_roll",0))==int(boundary["roll"]), "25percent threshold boundary wrong")

func _check_reputation() -> void:
	var run := fixture(["the_crew"],"CREW-REPUTATION")
	run.crew_trust_by_member["crew_rook"]=60
	run.crew_trust_by_member["crew_mags"]=30
	var legacy:=run.to_dict()
	legacy["narrative_flags"].erase("crew_reputation")
	legacy["debt"]=[{"id":"crew_blackjack_backoff:test","lender_id":"the_crew","balance":1,"debt_kind":"favor","status":"active"}]
	run.from_dict(legacy)
	check(run.crew_reputation()==60 and run.debt.is_empty() and run.crew_delivery_obligation_count()==0,"legacy reputation migration summed relationships or kept blackjack duty")
	check(bool(run.crew_standing().get("layer_3_access",false)),"shared reputation60 did not unlock existing made threshold")
	run.crew_change_reputation(-1)
	check(not bool(run.crew_standing().get("layer_3_access",true)),"member trust bypassed shared reputation59")
	check(not run.crew_rook_escort_available(),"Rook escort availability bypassed shared reputation59")
	run.current_environment["archetype_id"]="small_underground_casino"
	check(not run._environment_layer_access_path_allows({"flags_any":["rook_escort_punchline_back_room"]},{"back_room":true},"back_room"),"escort bypassed low shared reputation")
	var before:=run.crew_reputation()
	var heat:=run.add_suspicion("rep-test",3)
	check(heat==3 and run.crew_reputation()==before-3,"actual underground Heat gain did not reduce shared reputation1:1")
	run.add_suspicion("cooling",-2)
	check(run.crew_reputation()==before-3,"cooling changed shared reputation")
	var before_offsite:=run.crew_reputation()
	run.add_suspicion("other-room",3,"behavior",false,{"environment_archetype_id":"bar"})
	check(run.crew_reputation()==before_offsite,"offsite heat changed current Crew reputation")
	run.current_environment["archetype_id"]="back_alley"
	run.add_suspicion("outside",3)
	check(run.crew_reputation()==before_offsite,"outside Heat reduced Crew reputation")
	run.current_environment["crew_presence"]=[{"member_id":"crew_knuckles"}]
	check(not run.crew_reward_contact("crew_knuckles","inspect"),"informational click earned reputation")
	check(run.crew_reward_contact("crew_knuckles","crew_knuckles_stash") and run.crew_reputation()==before_offsite+2,"meaningful contact did not earn established2trust reward")
	var contact_rep:=run.crew_reputation()
	check(not run.crew_reward_contact("crew_knuckles","crew_knuckles_stash") and run.crew_reputation()==contact_rep,"repeat interaction farmed reputation")
	var data:=run.to_dict();var continued:=RunState.new();continued.from_dict(data)
	check(continued.crew_reputation()==contact_rep and not continued.crew_reward_contact("crew_knuckles","crew_knuckles_stash"),"Continue replayed contact or changed reputation")
	run.narrative_flags["crew_reputation"]=90
	check(str(run.crew_standing().get("rank",""))=="inner_circle","shared90 did not derive inner-circle rank")
	var any_live := false
	for row in run.crew_heist_planning_status().get("plans",[]): any_live = any_live or bool(row.get("live",false))
	check(not any_live,"shared reputation bypassed existing world/plan requirements")
	run.narrative_flags["crew_delivery_obligations"]=2
	run.current_environment["archetype_id"]="small_underground_casino"
	run.suspicion["level"]=90
	run.current_environment["game_states"]={"blackjack":{"hands_played":1}}
	var trust:=run.crew_trust_by_member.duplicate(true)
	var penalty:=run.apply_blackjack_heat_backoff({"game_id":"blackjack"})
	check(bool(penalty.get("triggered",false)) and run.crew_reputation()==0 and run.debt.is_empty() and run.crew_delivery_obligation_count()==2 and not run.delivery_has_active_run(),"blackjack penalty added debt/package/duty or missed reputation loss")
	check(run.crew_trust_by_member==trust and run.apply_blackjack_heat_backoff({"game_id":"blackjack"}).is_empty(),"blackjack replay changed relationships or applied again")

func _check_legacy_blackjack_route() -> void:
	var run:=delivery_fixture("CREW-LEGACY-BLACKJACK-ROUTE",2)
	accept(run)
	var job_id:=str(run.active_delivery_run.get("job_id",""))
	var data:=run.to_dict()
	data["narrative_flags"].erase("crew_delivery_rules_version")
	data["narrative_flags"].erase("crew_delivery_obligations")
	data["debt"]=[{"id":"crew_blackjack_backoff:test","lender_id":"the_crew","balance":1,"debt_kind":"favor","status":"active"}]
	run.from_dict(data)
	check(run.debt.is_empty() and run.crew_delivery_obligation_count()==0 and run.delivery_has_active_run() and str(run.active_delivery_run.get("job_id",""))==job_id,"legacy non-loan route lost identity or created queued duties")
	var target:=str(run.delivery_snapshot().get("targets",[{}])[0].get("node_id",""))
	var generator:=RunGenerator.new(library)
	Fidelity.travel_and_finalize(generator,run,target,true,library,failures,"legacy non-loan target")
	var window:=Schedule.window_for(run.active_delivery_run,target)
	run.advance_game_clock_minutes(maxi(0,int(window.get("opens",0))-run.game_clock_minutes))
	run.delivery_resolve_travel_arrival({}, {})
	if run.scenario_sequence_present():run.scenario_finalize_installed_environment(library,{"viewport_size":{"x":1280,"y":720}})
	else:run.world_sequence_finalize_base_semantics([],library,{"viewport_size":{"x":1280,"y":720}})
	var dispatched:=_dispatch_handoff(run,"legacy-nonloan-handoff")
	var token:=str(dispatched.get("token",""))
	var cash:=run.bankroll
	check(bool(run.world_sequence_checkpoint_delivery_outcome(token,target).get("ok",false)) and run.bankroll==cash+22 and run.crew_delivery_obligation_count()==0,"legacy non-loan handoff blocked or created future duty")
	run.world_sequence_materialize_delivery_checkpoint(token)
	var reputation:=run.crew_reputation()
	run=restore(run,"legacy_nonloan_success")
	run.world_sequence_checkpoint_delivery_outcome(token,target)
	check(run.bankroll==cash+22 and run.crew_reputation()==reputation and run.crew_delivery_obligation_count()==0,"legacy non-loan Continue/retry replayed award or queued another package")

func _check_clock_presentation() -> void:
	var run := fixture(["the_crew"],"CREW-CLOCK-PRESENTATION")
	run.narrative_flags["crew_delivery_obligations"]=2
	run.narrative_flags["crew_package_offer_rng_state"]=48
	run.event_cadence_note_modal_closed()
	var host := HourlyClockHost.new()
	host.run_state=run;host.library=library;host.current_screen=Main.SCREEN_ENVIRONMENT
	host.continuous_environment_clock_enabled=true
	host._advance_run_game_clock(1.0)
	check(run.triggered_event_pending("crew_favor_delivery"),"real room clock did not queue the eligible hourly request")
	check(host.observed_saves==1,"room-clock request did not request durability")
	check(host.observed_refreshes==1,"room-clock request did not refresh the existing TalkDock presentation")
	var first_refreshes := host.observed_refreshes
	host._advance_run_game_clock(1.0)
	check(host.observed_refreshes==first_refreshes and host.observed_saves==1 and run.pending_triggered_events.size()==1,"following clock tick repeated request or presentation")
	host.free()

func _check_first_meeting_presence() -> void:
	var run := fixture([],"CREW-FIRST-MEETING-PRESENCE")
	run.narrative_flags["crew_delivery_obligations"]=2
	run.current_environment["crew_presence"]=[]
	run.current_environment["event_ids"]=[]
	check(not run.crew_delivery_request_context_valid(),"remembered Crew without a live actor became presence")
	var event_id := str(CrewRecruitmentModel.member_definition("crew_switch").get("event_id",""))
	run.current_environment["event_ids"]=[event_id]
	run.current_environment["resolved_event_ids"]=[]
	check(not event_id.is_empty() and run.crew_delivery_request_context_valid(),"live first-meeting Crew actor did not count as presence")
	run.current_environment["resolved_event_ids"]=[event_id]
	check(not run.crew_delivery_request_context_valid(),"retired first-meeting actor still counted as presence")
	run.current_environment["event_ids"]=["parking_lot_tip"]
	check(not run.crew_delivery_request_context_valid(),"unrelated event counted as Crew presence")
