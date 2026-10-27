extends SceneTree
# Focused synthetic checkpoint capability/integrity contract. Captured host Deal,
# real event response and Continue are qualified separately from this model test.
const Authority=preload("res://scripts/core/blackjack_action_authority.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);print("FAIL ",message)
func _initialize()->void:call_deferred("_run")
func fixture()->RunState:
	var run:=RunState.new();run.start_new("BLACKJACK-EXTERNAL-EVENT-CHECKPOINT")
	run.bankroll=43;run.grand_casino_chips=20
	run.current_environment={"id":"checkpoint_table_room","archetype_id":"grand_casino","game_states":{}}
	var states:Dictionary=run.current_environment.game_states
	for key in ["blackjack","blackjack:second","slot"]:
		var ledger:=Authority.default_ledger(RunState.action_authority_table_binding(key,run.current_environment),run.action_authority_checkpoint_fingerprint())
		ledger["initialized"]=true;ledger["session"]={"test_pending_hand":true,"paid_wager":5}
		states[key]={Authority.LEDGER_KEY:ledger}
	return run
func ledger(run:RunState,key:String="blackjack")->Dictionary:return run.current_environment.game_states[key][Authority.LEDGER_KEY]
func valid(run:RunState,key:String="blackjack")->bool:return not Authority.validate_persisted_ledger(ledger(run,key),RunState.action_authority_table_binding(key,run.current_environment),run.action_authority_checkpoint_fingerprint()).is_empty()
func _run()->void:
	for kind in ["cash_gain","cash_loss","chips_gain","chips_loss","rng","cash_and_rng"]:
		var run:=fixture();var before:=run._blackjack_checkpoint_before_external_event()
		var held_session:Dictionary=ledger(run).session.duplicate(true);var untouched_slot:Dictionary=ledger(run,"slot").duplicate(true)
		var prior_table:Dictionary=run.current_environment.game_states.blackjack
		match kind:
			"cash_gain":run.change_bankroll(15)
			"cash_loss":run.change_bankroll(-5)
			"chips_gain":run.change_grand_casino_chips(10)
			"chips_loss":run.change_grand_casino_chips(-5)
			"rng","cash_and_rng":
				if kind=="cash_and_rng":run.change_bankroll(15)
				var rng:=run.create_rng();rng.randi_range(0,100);run.save_rng(rng)
		check(not valid(run),"fixture did not produce external checkpoint drift "+kind)
		var cash:=run.bankroll;var chips:=run.grand_casino_chips;var rng_state:=run.rng_state
		run._rebind_blackjack_checkpoint_after_external_event(before)
		check(valid(run) and valid(run,"blackjack:second"),"valid external boundary lost a table "+kind)
		check(ledger(run).session==held_session and ledger(run).journal==[] and ledger(run).request_cache=={},"event rebase changed hand/history "+kind)
		check(ledger(run,"slot")==untouched_slot,"event rebase touched unrelated Slot authority")
		check(run.bankroll==cash and run.grand_casino_chips==chips and run.rng_state==rng_state,"rebase changed money/RNG")
		check(prior_table[Authority.LEDGER_KEY].checkpoint_fingerprint==before,"rebase mutated prior snapshot alias")
		var state:Dictionary=run.current_environment.game_states.duplicate(true)
		run._rebind_blackjack_checkpoint_after_external_event(before)
		check(run.current_environment.game_states==state,"retry changed authority again")
	for broken in ["checkpoint","binding","journal"]:
		var run:=fixture();var old:=run._blackjack_checkpoint_before_external_event()
		if broken=="checkpoint":ledger(run)["checkpoint_fingerprint"]="0".repeat(64)
		elif broken=="binding":ledger(run)["table_binding"]="blackjack:another:room"
		else:ledger(run)["journal"]=[{"forged":true}]
		var rejected:=ledger(run).duplicate(true)
		run.change_bankroll(15);run._rebind_blackjack_checkpoint_after_external_event(old)
		check(ledger(run)==rejected and not valid(run),"event blessed preexisting invalid "+broken)
	var run:=fixture();var before:Dictionary=run.current_environment.game_states.duplicate(true)
	run.change_bankroll(15);run._rebind_blackjack_checkpoint_after_external_event("")
	check(run.current_environment.game_states==before,"missing event context authorized a rebase")
	run.current_environment["game_states"]={}
	check(run._blackjack_checkpoint_before_external_event().is_empty(),"empty room created an authority checkpoint")
	run.current_environment["game_states"]=[]
	check(run._blackjack_checkpoint_before_external_event().is_empty(),"malformed room created an authority checkpoint")
	print("BLACKJACK_EXTERNAL_EVENT_CHECKPOINT checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
