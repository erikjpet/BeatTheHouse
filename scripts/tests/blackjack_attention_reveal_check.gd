extends "res://scripts/tests/scenario_venue_cycle_captured_check.gd"
const Authority:=preload("res://scripts/core/blackjack_action_authority.gd")
func _run()->void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"),"private root required"):_finish();return
	_install(OS.get_environment("BTH_CAPTURED_FIXTURE"))
	root.size=Vector2i(1280,720)
	var app:=Host.new();app.continuous_environment_clock_enabled=false;app.script_prewarm_stopping=true;root.add_child(app)
	for frame in range(3):await process_frame
	if not _check(app.load_foundation_run() and app.enter_game("blackjack"),"genuine paid40 Continue/entry"):app.queue_free();_finish();return
	for frame in range(3):await process_frame
	var run:RunState=app.run_state
	var money:Dictionary={"cash":run.bankroll,"chips":run.grand_casino_chips,"rng":run.rng_state,"story":run.story_log.duplicate(true),"flags":run.narrative_flags.duplicate(true),"inventory":run.inventory.duplicate(true)}
	var t:=Time.get_ticks_usec()
	var away:Dictionary=app._sealed_action_host_surface_intent("blackjack_distraction",1,false,100000)
	app._apply_game_surface_command(away,1,false,false,true)
	facts["lookaway_usec"]=Time.get_ticks_usec()-t
	_check(not away.get("surface_state_patch",{}).is_empty(),"attention carries incremental patch")
	t=Time.get_ticks_usec()
	var peek:Dictionary=app._sealed_action_host_surface_intent("blackjack_peek",0,false,100250)
	_check(not bool(peek.get("resolve",true)) and not bool(peek.get("direct_resolve",true)),"first in-window Peek preserves selection-only semantics")
	_check(not peek.has("_sealed_action_host_delivery"),"information reveal does not fabricate a paid settlement")
	_check(not peek.get("surface_state_patch",{}).is_empty(),"first Peek carries incremental patch")
	app._apply_game_surface_command(peek,0,false,false,true)
	facts["peek_usec"]=Time.get_ticks_usec()-t
	_check(app.selected_action_id=="peek_hole_card" and app.selected_action_kind=="cheat","normal validated selection is retained")
	var s:Dictionary=run.current_environment.game_states.blackjack[Authority.LEDGER_KEY].session
	_check(bool(s.get("dealer_hole_visible",false)) and bool(s.get("cheats_used",{}).get("peek_hole_card",false)),"same live hole reveal and cheat usage")
	_check(int(s.dealer_lookaway_started_msec)==100000 and int(s.dealer_lookaway_duration_msec)==int(away.ui_state.dealer_lookaway_duration_msec),"Peek never resets or extends attention window")
	_check(run.bankroll==money.cash and run.grand_casino_chips==money.chips and run.rng_state==money.rng,"first Peek never charges or draws root RNG")
	_check(run.story_log==money.story and run.narrative_flags==money.flags and run.inventory==money.inventory,"information selection preserves history/profile/inventory")
	var live:Dictionary=app.game_surface_canvas.realtime_surface_state()
	_check(bool(live.get("dealer_hole_visible",false)),"actual retained Canvas receives reveal on same boundary")
	_check(bool(run.validate_room_action_authority().get("ok",false)),"reveal keeps strict room authority")
	var save_error:=SaveService.new().save_run(run,"attention_reveal")
	var restored:Variant=SaveService.new().load_run("attention_reveal")
	_check(save_error==OK and restored is RunState,"official paid reveal Save/fresh service")
	if restored is RunState:
		var rs:Dictionary=restored.current_environment.game_states.blackjack[Authority.LEDGER_KEY].session
		_check(bool(rs.get("dealer_hole_visible",false)) and bool(rs.get("cheats_used",{}).get("peek_hole_card",false)),"cold keeps reveal/cheat without replay")
		_check(restored.bankroll==money.cash and restored.grand_casino_chips==money.chips and restored.rng_state==money.rng,"cold keeps money/RNG")
	var repeat:Dictionary=app._sealed_action_host_surface_intent("blackjack_peek",0,false,100300)
	_check(not bool(repeat.get("resolve",false)) and str(repeat.get("message","")).contains("already"),"repeated revealed Peek is existing harmless message")
	_check(run.bankroll==money.cash and run.grand_casino_chips==money.chips and run.story_log==money.story,"repeat cannot charge or replay result")
	app.save_service.wait_for_async_save();app.queue_free();await process_frame;_finish()
