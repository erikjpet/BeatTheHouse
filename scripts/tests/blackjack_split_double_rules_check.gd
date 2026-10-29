extends SceneTree
const Blackjack:=preload("res://scripts/games/blackjack.gd")
const Driver:=preload("res://scripts/tests/foundation/blackjack_authority_test_driver.gd")
const Authority:=preload("res://scripts/core/blackjack_action_authority.gd")
var checks:=0
var failures:Array=[]
var facts:Dictionary={}
var library:ContentLibrary
func _initialize()->void:call_deferred("_run")
func check(ok:bool,label:String)->bool:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
	return ok
func card(rank:int,suit:int=0)->Dictionary:return {"rank":rank,"suit":suit,"deck":0}
func hand(cards:Array,split:bool=false)->Dictionary:return {"cards":cards,"split":split,"blackjack_eligible":not split,"wager_multiplier":1,"stood":false,"doubled":false}
func session(run:RunState)->Dictionary:return run.current_environment.game_states.blackjack[Authority.LEDGER_KEY].session.duplicate(true)
func balance(run:RunState,chips:bool)->int:return run.grand_casino_chips if chips else run.bankroll
func fixture(chips:bool,funds:int,pair:int=8,draws:Array=[3,2,10,9,2,4,3])->Dictionary:
	var run:=RunState.new();run.start_new("SYNTHETIC-SPLIT-RULES");run.crew_change_reputation(0)
	run.bankroll=0 if chips else funds;run.grand_casino_chips=funds if chips else 0
	run.current_environment={"id":"grand_casino_001" if chips else "riverboat_casino_001","archetype_id":"grand_casino" if chips else "riverboat_casino","game_ids":["blackjack"],"economic_profile":{"stake_floor":1,"stake_ceiling":100},"security_profile":{},"game_states":{}}
	var game:=Blackjack.new();game.setup(library.game("blackjack"),library)
	var table:Dictionary=game.generate_environment_state(run,run.current_environment,run.create_rng("split_table"))
	table.patrons=[];table.side_bets=[];table.rules.double_after_split=false;table.rules.split_aces_one_card=false
	var shoe:Array=[card(pair),card(6),card(pair,1),card(10,2)]
	for r in draws:shoe.append(card(r,3))
	for i in range(30):shoe.append(card(2,i%4))
	table.shoe=shoe;table.counting_enabled=false
	run.current_environment.game_states.blackjack=table
	var command:Dictionary=game.surface_action_command("blackjack_deal",0,false,{"selected_stake":10},run,run.current_environment)
	var deal:Dictionary=Driver.resolve(game,"blackjack_place_bet",10,run,run.current_environment,run.create_rng(),command.ui_state)
	check(bool(deal.get("ok",false)) and balance(run,chips)==funds-10,"synthetic real paid Deal costs10")
	return {"run":run,"game":game,"chips":chips,"start":funds}
func action(f:Dictionary,id:String)->Dictionary:
	var run:RunState=f.run;var game:GameModule=f.game
	var command:=Driver.surface_intent(game,id,10,run,run.current_environment)
	if not str(command.get("action_id","")).is_empty() and bool(command.get("resolve",false) or command.get("direct_resolve",false)):
		var result:=Driver.resolve_surface_command(game,command,10,run,run.current_environment)
		check(bool(result.get("ok",false)),"sealed "+id+" accepted")
		return {"command":command,"result":result}
	return {"command":command,"result":{}}
func _run()->void:
	if not check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"),"private persistence required"):finish();return
	if OS.get_environment("BTH_SPLIT_STAGE")=="cold":
		for chips in [false,true]:
			var restored:Variant=SaveService.new().load_run("split_after_double_"+str(chips))
			if check(restored is RunState,"independent process paid split save loads"):
				check(balance(restored,chips)==70 and int(session(restored).wager_debited)==30,"independent process retains exact30 committed stake")
				check(session(restored).player_hands.size()==2 and session(restored).player_hands[0].doubled and not session(restored).player_hands[1].doubled,"independent process retains first double and live sibling")
		finish();return
	library=ContentLibrary.new();library.load(false)
	var game:=Blackjack.new();game.setup(library.game("blackjack"),library)
	for ten in [10,11,12,13]:
		for position in [0,1]:
			var natural:=hand([card(14),card(ten,1)],true)
			var r:Dictionary=game._settle_hand(natural,[card(10),card(9)],10)
			check(r.outcome=="blackjack" and int(r.bankroll_delta)==15,"legacy split Ace rank%s position%s pays3:2"%[ten,position])
			var push:Dictionary=game._settle_hand(natural,[card(14),card(13)],10)
			check(push.outcome=="push" and int(push.bankroll_delta)==0,"dealer natural pushes split Ace")
			var three:Dictionary=game._settle_hand(natural,[card(7),card(7),card(7)],5)
			check(three.outcome=="blackjack" and int(three.bankroll_delta)==7,"odd5 uses existing floor7; beats dealer3card21")
	check(not game._is_natural_blackjack(hand([card(10),card(14)],true)),"Ten-origin split plusAce stays ordinary21")
	check(not game._is_natural_blackjack(hand([card(14),card(5),card(5)],true)),"threecard21 is not natural")
	check(game._is_natural_blackjack(hand([card(14),card(13)])),"unsplit natural unchanged")
	for ranks in [[10,6,8],[8,2,9],[8,2,8],[8,2,7]]:
		var doubled:=hand([card(ranks[0]),card(ranks[1]),card(ranks[2])],true)
		doubled.wager_multiplier=2;doubled.doubled=true;doubled.stood=true
		var total:int=game._hand_total(doubled.cards)
		var expected_delta:= -20 if total>21 or total<18 else 0 if total==18 else 20
		var outcome:Dictionary=game._settle_hand(doubled,[card(10),card(8)],10)
		check(int(outcome.wager)==20 and int(outcome.bankroll_delta)==expected_delta,"double win/loss/push/bust uses precisely doubled stake")
	for chips in [false,true]:
		var f:=fixture(chips,100);var run:RunState=f.run;var table:Dictionary=run.current_environment.game_states.blackjack
		check(bool(game._table_rules(table).double_after_split),"saved noDAS effective policy allows double")
		var turns:=int(run.current_environment.get("turns",0));var rng:=run.rng_state
		var split:=action(f,"blackjack_split")
		if not check(balance(run,chips)==80,"split immediately commits one extra10"):facts[str(chips)]={"split":split,"session":session(run)};continue
		var s:=session(run);check(s.player_hands.size()==2 and int(s.wager_debited)==20,"two hands backed by exact20")
		check(int(run.current_environment.get("turns",0))==turns and run.rng_state==rng,"internal split funding adds no world turn/root RNG")
		var sibling:Dictionary=s.player_hands[1].duplicate(true)
		var first:=action(f,"blackjack_double");s=session(run)
		check(balance(run,chips)==70 and int(s.wager_debited)==30,"first split Double commits exactly10")
		check(s.player_hands[0].cards.size()==3 and s.player_hands[0].doubled and s.player_hands[0].stood,"Double draws one and finishes first hand")
		check(s.player_hands[1]==sibling and int(s.active_hand_index)==1,"Double preserves sibling and advances to it")
		var saved:=SaveService.new().save_run(run,"split_after_double_"+str(chips))
		var cold:Variant=SaveService.new().load_run("split_after_double_"+str(chips))
		check(saved==OK and cold is RunState,"paid split+Double official Save/cold")
		if cold is RunState:
			check(balance(cold,chips)==70 and int(session(cold).wager_debited)==30 and session(cold).player_hands==s.player_hands,"cold preserves paid hands/debit/eligibility")
		var before:=run.to_save_snapshot()
		var duplicate:=Driver.resolve_surface_command(f.game,first.command,10,run,run.current_environment)
		check(duplicate.has(Authority.HOST_REPLAY_KEY) or not bool(duplicate.get("ok",true)),"same Double delivery is replay/rejection")
		check(run.to_save_snapshot()==before,"stale Double cannot debit/draw again")
		var second:=action(f,"blackjack_double");s=session(run)
		check(balance(run,chips)==60 and int(s.wager_debited)==40,"second split Double commits its own10")
		check(s.player_hands[1].cards.size()==3 and s.player_hands[1].doubled,"second hand double draws onlyone")
		var settled:=Driver.resolve(f.game,"play_basic",10,run,run.current_environment,run.create_rng(),s)
		check(bool(settled.get("ok",false)) and balance(run,chips)==140,"both doubles settle once: stake40 return80 profit40")
		var paid:Dictionary=run.to_save_snapshot();var replay:=GameModule.apply_result(run,settled.duplicate(true))
		check(not bool(replay.get("ok",true)) and run.to_save_snapshot()==paid,"settlement receipt rejects repeat")
		check(int(run.current_environment.get("turns",0))==turns+1,"only final round adds its normal environment turn")
		facts[str(chips)]={"final_balance":balance(run,chips),"settled_ok":settled.get("ok"),"story_rows":run.story_log.size()}
		var low:=fixture(chips,25);action(low,"blackjack_split")
		var low_s:=session(low.run);var low_before:Dictionary=low.run.to_save_snapshot()
		check(not bool(low.game._can_double(low_s,low.run.current_environment.game_states.blackjack,10,low.run)),"insufficient5 disables Double after split")
		action(low,"blackjack_double")
		check(balance(low.run,chips)==5 and session(low.run).player_hands==low_s.player_hands,"rejected Double never debits or draws")
		var aces:=fixture(chips,100,14,[10,13,2,4]);action(aces,"blackjack_split")
		var ace_session:=session(aces.run)
		check(game._is_natural_blackjack(ace_session.player_hands[0]) and game._is_natural_blackjack(ace_session.player_hands[1]),"both actual split positions inherit Ace-origin eligibility")
		var ace_result:=Driver.resolve(aces.game,"play_basic",10,aces.run,aces.run.current_environment,aces.run.create_rng(),ace_session)
		check(bool(ace_result.get("ok",false)) and balance(aces.run,chips)==130,"two split Ace naturals return50 on paid20")
		for draws in [[10,5,2,4],[5,10,2,4]]:
			var mixed:=fixture(chips,100,14,draws);action(mixed,"blackjack_split")
			var mixed_session:=session(mixed.run)
			var mixed_result:=Driver.resolve(mixed.game,"play_basic",10,mixed.run,mixed.run.current_environment,mixed.run.create_rng(),mixed_session)
			check(bool(mixed_result.get("ok",false)) and balance(mixed.run,chips)==105,"one split-Ace natural plus losing sibling returns25 from paid20 in either position")
		var exact:=fixture(chips,20);action(exact,"blackjack_split")
		check(balance(exact.run,chips)==0 and exact.run.run_status=="active" and int(session(exact.run).wager_debited)==20,"exact-balance split keeps its paid hands playable atzero")

	finish()
func finish()->void:
	var output:=OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"facts":facts},"  "));file.close()
	print("BLACKJACK_SPLIT_RULES checks=",checks," failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
