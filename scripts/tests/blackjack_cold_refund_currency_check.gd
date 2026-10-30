extends "res://scripts/tests/scenario_venue_cycle_captured_check.gd"

const Blackjack := preload("res://scripts/games/blackjack.gd")
const Driver := preload("res://scripts/tests/foundation/blackjack_authority_test_driver.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const SLOT := "cold_chip_refund_unit_roundtrip"

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "private refund test roots required"): _finish(); return
	var cold := OS.get_environment("BTH_REFUND_STAGE") == "cold"
	if not cold: _install(OS.get_environment("BTH_CAPTURED_FIXTURE"))
	var reference: Variant = SaveService.new().load_run(SLOT if cold else "foundation_ui_autosave")
	if not _check(reference is RunState, "unchanged settled fixture official load"): _finish(); return
	var protected := _protected(reference)
	root.size = Vector2i(1280,720)
	var app := Host.new(); app.continuous_environment_clock_enabled=false; app.script_prewarm_stopping=true; root.add_child(app)
	for frame in range(3): await process_frame
	if cold: app.save_service.save_run(reference, "foundation_ui_autosave")
	if not _check(app.load_foundation_run(), "normal Continue already-settled surrender"): app.queue_free(); _finish(); return
	app.set_process(false) # No decisions or live clock progression on the captured state.
	var run: RunState = app.run_state
	_check(run.bankroll==71 and run.grand_casino_chips==145, "existing71cash145chips unchanged; no refund replay")
	_check(_protected(run)==protected, "normal Continue retains full protected paid/account/history/RNG")
	var rows := _blackjack_rows(run)
	if not _check(rows.size()>=2, "settled history has original debit and return"): app.queue_free(); _finish(); return
	var debit:Dictionary=rows[rows.size()-2]; var refund:Dictionary=rows.back()
	_check(int(debit.get("bankroll_delta",0))==-10 and int(refund.get("bankroll_delta",0))==5, "original-10 debit and+5 return retained")
	_check(not refund.has("currency") and not refund.has("currency_delta"), "genuine legacy row remains unmodified and untagged")
	_check(int(refund.get("round_net_delta",0))==-5, "recorded round loss remains-5")
	var view:Dictionary=app._environment_result_feedback_view()
	var text:=str(view.get("text","")); var receipt:Dictionary=view.get("result",{})
	_check(bool(view.get("visible",false)) and text.contains("+5 chips"), "actual cold environment Result labels five-chip movement")
	_check(not text.contains("$+5") and not text.contains("Bankroll +5") and not text.contains("$5"), "cold refund has no false cash wording")
	_check(str(receipt.get("currency",""))=="chips" and int(receipt.get("currency_delta",0))==5 and int(receipt.get("bankroll_delta",1))==0, "structured receipt separates chip return from cash")
	_check(not bool(receipt.get("won",true)), "partial surrender return is not relabeled as a win")
	var before:=_protected(run)
	for repeat in range(3):
		app._environment_result_feedback_view(); app._result_from_story_log(run.story_log); app._game_result_from_story_log(run.story_log)
	_check(_protected(run)==before, "repeated formatters are read-only and cannot reapply return")
	if not cold:
		_reader_controls(app)
		_future_rows(app.library,false)
		_future_rows(app.library,true)
	var save_error:=app.save_service.save_run(run,SLOT)
	_check(save_error==OK, "official Save preserves settled display fixture")
	var restored:Variant=SaveService.new().load_run(SLOT)
	_check(restored is RunState and _protected(restored)==before, "fresh SaveService preserves protected state without compensation")
	facts["rendered_text"]=text;facts["cash"]=run.bankroll;facts["chips"]=run.grand_casino_chips
	facts["last_movements"]=[-10,5];facts["round_net"]=-5;facts["mode"]="cold" if cold else "warm"
	app.save_service.wait_for_async_save();app.queue_free();await process_frame;_finish()

func _blackjack_rows(run:RunState)->Array:
	var rows:Array=[]
	for row in run.story_log:
		if str(row.get("type",""))=="game_action" and str(row.get("game_id",""))=="blackjack":rows.append(row)
	return rows

func _reader_controls(app:Host)->void:
	for game_id in RunState.GRAND_CASINO_CHIP_GAME_IDS:
		var row:Dictionary={"type":"game_action","game_id":game_id,"action_id":"test_recorded_return","environment_id":"grand_casino_004","bankroll_delta":5,"won":false}
		var original:=row.duplicate(true)
		var result:Dictionary=app._game_result_from_story_log([row])
		_check(str(result.get("currency",""))=="chips" and int(result.get("currency_delta",0))==5, "recorded Grand source resolves units for "+str(game_id))
		_check(row==original, "legacy formatter does not rewrite "+str(game_id)+" history")
	for delta in [-10,0,5]:
		var row:Dictionary={"type":"game_action","game_id":"blackjack","action_id":"play_basic","environment_archetype_id":"grand_casino","environment_id":"riverboat_casino_001","bankroll_delta":delta}
		var result:Dictionary=app._result_from_story_log([row])
		_check(str(result.get("currency",""))=="chips" and int(result.get("currency_delta",99))==delta, "explicit recorded Grand archetype wins conflicting ID, including zero")
	var cash:Dictionary={"type":"game_action","game_id":"blackjack","action_id":"play_basic","environment_archetype_id":"riverboat_casino","environment_id":"grand_casino_004","bankroll_delta":5,"won":false}
	_check(not app._recorded_game_uses_chips(cash), "recorded nonGrand archetype wins conflicting Grand ID")
	cash={"type":"game_action","game_id":"blackjack","action_id":"play_basic","environment_id":"grand_casino_004","currency":"cash","currency_delta":5,"bankroll_delta":5}
	_check(not app._recorded_game_uses_chips(cash) and app._result_from_story_log([cash]).get("currency")=="cash", "explicit cash metadata is never converted by venue")
	var unknown:Dictionary={"type":"game_action","game_id":"blackjack","action_id":"play_basic","bankroll_delta":5}
	_check(not app._recorded_game_uses_chips(unknown), "unknown source never borrows current Grand room/wallet")
	unknown.environment_id="grand_casino_impostor"
	_check(not app._recorded_game_uses_chips(unknown), "impostor generated ID never grants chip interpretation")
	var zero:Dictionary={"type":"game_action","game_id":"blackjack","action_id":"play_basic","environment_id":"grand_casino_004","currency":"chips","currency_delta":0,"bankroll_delta":0}
	_check(int(app._result_from_story_log([zero]).get("currency_delta",1))==0, "known zero remains measured zero")
	# Preserve previously approved clamped-loss/unknown-history display semantics.
	var penalty:Dictionary={"type":"game_action","game_id":"blackjack","action_id":"play_basic","environment_id":"grand_casino_004","bankroll_delta":-53,"dealer_caught_cheat":true}
	_check(bool(app._result_from_story_log([penalty]).get("applied_currency_unknown",false)), "legacy nominal penalty is still unknown actual loss")
	var witness:Dictionary={"schema":"bth.applied_currency_settlement/v1","currency":"chips","delta":-10,"cash_delta":0,"chips_delta":-10,"nominal_cash_delta":0,"nominal_chips_delta":-40}
	penalty.applied_currency_settlement=witness
	var measured:Dictionary=app._result_from_story_log([penalty])
	_check(not bool(measured.get("applied_currency_unknown",false)) and int(measured.get("currency_delta",0))==-10, "applied witness still overrides nominal historical instruction")

func _future_rows(library:ContentLibrary,chips:bool)->void:
	# Explicit synthetic card fixture; no historic original decision is replayed.
	var run:=RunState.new();run.start_new("REFUND-CURRENCY-METADATA");run.crew_change_reputation(0)
	run.bankroll=71 if chips else 150;run.grand_casino_chips=150 if chips else 0
	run.current_environment={"id":"grand_casino_004" if chips else "riverboat_casino_001","archetype_id":"grand_casino" if chips else "riverboat_casino","game_ids":["blackjack"],"economic_profile":{"stake_floor":1,"stake_ceiling":100},"security_profile":{},"game_states":{}}
	var game:=Blackjack.new();game.setup(library.game("blackjack"),library)
	var table:Dictionary=game.generate_environment_state(run,run.current_environment,run.create_rng("refund_table"))
	table.patrons=[];table.side_bets=[];table.rules.late_surrender=true;table.counting_enabled=false
	table.shoe=[{"rank":5,"suit":0,"deck":0},{"rank":6,"suit":1,"deck":0},{"rank":11,"suit":2,"deck":0},{"rank":10,"suit":3,"deck":0},{"rank":2,"suit":0,"deck":0},{"rank":3,"suit":1,"deck":0}]
	run.current_environment.game_states.blackjack=table
	var command:Dictionary=game.surface_action_command("blackjack_deal",0,false,{"selected_stake":10},run,run.current_environment)
	var deal:Dictionary=Driver.resolve(game,"blackjack_place_bet",10,run,run.current_environment,run.create_rng(),command.ui_state)
	_check(bool(deal.get("ok",false)), "synthetic actual10 wager accepted")
	var surrender:Dictionary=Driver.surface_intent(game,"blackjack_surrender",10,run,run.current_environment)
	var result:Dictionary=Driver.resolve_surface_command(game,surrender,10,run,run.current_environment)
	_check(bool(result.get("ok",false)), "synthetic actual surrender accepted")
	var rows:=_blackjack_rows(run);var movement:Dictionary=rows.back()
	var currency:="chips" if chips else "cash"
	_check(str(rows[rows.size()-2].get("currency",""))==currency and int(rows[rows.size()-2].get("currency_delta",0))==-10, "future paid row stores correct denomination only")
	_check(str(movement.get("currency",""))==currency and int(movement.get("currency_delta",0))==5 and int(movement.get("bankroll_delta",0))==5, "future refund stores original+5 movement and units")
	_check(int(movement.get("round_net_delta",0))==-5, "future round net remains-5")
	_check(run.bankroll==(71 if chips else 145) and run.grand_casino_chips==(145 if chips else 0), "tagging changes no cash/chip accounting")
	var before:=run.to_save_snapshot();var duplicate:=GameModule.apply_result(run,result.duplicate(true))
	_check(not bool(duplicate.get("ok",true)) and run.to_save_snapshot()==before, "future duplicate cannot refund again")
