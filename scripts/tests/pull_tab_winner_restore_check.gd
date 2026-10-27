extends SceneTree
const State=preload("res://scripts/core/run_state.gd")
const PullTabs=preload("res://scripts/games/pull_tabs.gd")
const Library=preload("res://scripts/core/content_library.gd")
var checks=0
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
func restore(run):
	var next=State.new();next.from_dict(run.to_dict());return next
func _initialize() -> void:
	# Generated, deterministic model fixtures; never alter a captured ticket/RNG.
	var library=Library.new();library.load(false)
	var game=PullTabs.new();game.setup(library.game("pull_tabs"),library)
	var run=null
	var selected_seed=""
	for i in range(12):
		var candidate=State.new();candidate.start_new("PULLTAB011-WINNER-%d" % i)
		var env={"id":"paid_tab_model_fixture","archetype_id":"bar","world_node_id":"bar","kind":"casino","economic_profile":{"stake_floor":1,"stake_ceiling":1},"game_ids":["pull_tabs","bar_dice"],"game_states":{},"event_ids":[],"lender_hooks":[],"travel_hooks":[]}
		env.game_states={"pull_tabs":game.generate_environment_state(candidate,env,candidate.create_rng("stock"))}
		candidate.set_environment(env);candidate.change_bankroll(1-candidate.bankroll,true)
		game.resolve_with_context("buy_tab",1,candidate,candidate.current_environment,candidate.create_rng("buy"),{"pull_tab_deal_index":2})
		var tray: Array=game._read_machine_state(candidate,candidate.current_environment).get("tray_stack",[])
		if tray.size()==1 and int(tray[0].get("payout",0)) in [1,2,3]:
			run=candidate;selected_seed=candidate.seed_text;break
	check(run!=null,"bounded generated fixture did not produce a small winning purchase")
	if run!=null:
		var env=run.current_environment
		var ticket: Dictionary=game._read_machine_state(run,env).tray_stack[0]
		var id=str(ticket.id);var purchase_rng=run.rng_state
		check(run.bankroll==0 and run.run_status=="active","normal all-in winner purchase failed before reveal")
		run=restore(run);env=run.current_environment
		check(run.run_status=="active" and run.rng_state==purchase_rng,"uncollected winner restore failed/redrew")
		var ui: Dictionary=game.surface_action_command("pull_tab_collect_tray",0,false,{},run,env).get("ui_state",{})
		ui=game.surface_action_command("pull_tab_reveal_next",0,false,ui,run,env).get("ui_state",ui)
		game.checkpoint_surface_ui_state(ui,run,env)
		run=restore(run);env=run.current_environment
		var opened=game._read_machine_state(run,env)
		check(run.run_status=="active" and opened.ticket_stack.size()==1 and opened.ticket_stack[0].fully_revealed,"revealed/unfiled winner not resumable")
		check(str(opened.ticket_stack[0].id)==id and run.rng_state==purchase_rng and run.bankroll==0,"winner reopen changed ticket/cash/RNG")
		game.resolve_with_context(PullTabs.SORT_TICKET_ACTION,0,run,env,run.create_rng("file"),ui)
		var file_rng=run.rng_state
		check(run.run_status=="active" and run.bankroll==0,"filed winner caused bankruptcy before redemption")
		run=restore(run);env=run.current_environment
		var filed=game._read_machine_state(run,env)
		check(run.run_status=="active" and filed.winner_pile.size()==1 and str(filed.winner_pile[0].id)==id,"filed winner lost across restore")
		check(run.rng_state==file_rng and filed.tickets_sold==1,"filed winner restore redrew/repurchased")
		var redeem_rng=run.create_rng("redeem")
		var redemption=game.environment_action_command(PullTabs.REDEEM_HOOK_ID,PullTabs.REDEEM_ACTION_ID,run,env,redeem_rng).get("result",{})
		GameModule.apply_result(run,redemption,redeem_rng)
		var paid=run.bankroll;var paid_rng=run.rng_state
		var cashed=game._read_machine_state(run,env)
		check(paid==int(redemption.get("bankroll_delta",-1)) and paid>0,"winning redemption did not credit its exact normal result")
		check(cashed.cashout_count==1 and cashed.winner_pile.is_empty() and cashed.redeemed_pile.size()==1,"winner redemption duplicated/lost receipt")
		var repeat_rng=run.create_rng("repeat")
		var repeated=game.environment_action_command(PullTabs.REDEEM_HOOK_ID,PullTabs.REDEEM_ACTION_ID,run,env,repeat_rng).get("result",{})
		GameModule.apply_result(run,repeated,repeat_rng)
		check(run.bankroll==paid and run.rng_state==paid_rng and game._read_machine_state(run,env).cashout_count==1,"repeat redemption paid or advanced RNG again")
		run=restore(run)
		check(run.run_status=="active" and run.bankroll==paid and run.rng_state==paid_rng,"post-redemption restore replayed payout")
	print("PULL_TAB_WINNER_RESTORE seed=",selected_seed," checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
