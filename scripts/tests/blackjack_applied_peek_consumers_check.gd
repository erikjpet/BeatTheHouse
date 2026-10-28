extends SceneTree
const Host:=preload("res://scripts/ui/foundation_main.gd")
const Codec:=preload("res://scripts/core/run_save_codec.gd")
var checks:=0
var failures:Array[String]=[]
var facts:Dictionary={}

func _initialize()->void:call_deferred("_run")

func _run()->void:
	var legacy:RunState
	var bundle:=OS.get_environment("BTH_CAPTURED_FIXTURE")
	if not bundle.is_empty():
		_install(bundle)
		legacy=SaveService.new().load_run("foundation_ui_autosave")
		_check(legacy!=null,"official unchanged legacy caught/funded save loads")
	var app:=Host.new();app.library=ContentLibrary.new();app.library.load(false)
	# The pure-reader test does not enter the scene tree/startup loader. Supply
	# its real lazy dependency explicitly; no mocked result or game state.
	app.TerminalConsequenceViewModelScript=preload("res://scripts/ui/terminal_consequence_view_model.gd")
	for available in [10,0,40,70]:
		var delta:=-mini(available,40)
		var witness:=_witness(delta)
		var entry:={"type":"game_action","game_id":"blackjack","action_id":"peek_hole_card","action_kind":"cheat","environment_archetype_id":"grand_casino","environment_id":"grand_casino_receipt_fixture","bankroll_delta":delta,"nominal_bankroll_delta":-40,"chips_delta":delta,"currency":"chips","currency_delta":delta,"suspicion_delta":77,"dealer_caught_cheat":true,"pit_boss_watched":true,"message":"Caught. Chip change: %+d chips."%delta,"applied_currency_settlement":witness,"settlement":{"currency":"chips","delta":delta}}
		var before:=var_to_bytes(entry)
		for reader in [Callable(app,"_result_from_story_log"),Callable(app,"_game_result_from_story_log")]:
			var result:Dictionary=reader.call([entry])
			_check(str(result.get("currency"))=="chips" and int(result.get("currency_delta",1))==delta,"cold reader retains measured chip units including zero")
			_check(int(result.get("bankroll_delta",1))==0 and int(result.deltas.bankroll_delta)==0,"cold chips never become a cash suffix")
			_check(GameModule.applied_currency_settlement(result)==witness,"cold reader carries exact witness")
			_check(result.get("settlement",{}).get("delta")==delta,"cold reader retains structured settlement")
			var text:=app._environment_result_feedback_text(str(result.message),int(result.bankroll_delta),int(result.suspicion_delta))
			_check(not text.contains("$") and text.contains("chips"),"cold HUD uses chips rather than dollars")
			result.applied_currency_settlement.delta=999
			_check(var_to_bytes(entry)==before,"returned witness is detached from history")
		var transported:Variant=Codec.decode(JSON.parse_string(JSON.stringify(Codec.encode({"story_log":[entry]}))))
		_check(int(app._result_from_story_log(transported.story_log).get("currency_delta",1))==delta,"official JSON codec keeps known zero/actual delta")
		var run:=RunState.new();run.start_new("APPLIED-METRIC-%d"%available)
		run.narrative_flags.profile_bankroll_lost=40
		var money:=_money(run)
		run.record_profile_game_result({"ok":true,"game_id":"blackjack","currency":"chips","deltas":{"bankroll_delta":0,"chips_delta":-40},"applied_currency_settlement":witness})
		_check(int(run.narrative_flags.profile_bankroll_lost)==40-delta,"prospective metric counts measured loss rather than nominal instruction")
		_check(int(run.narrative_flags.profile_games_played.blackjack)==1,"prospective metric records one accepted result")
		_check(_money(run)==money,"metric changes no balances/RNG/clock/inventory")
		var restored:=RunState.new();restored.from_dict(Codec.decode(JSON.parse_string(JSON.stringify(Codec.encode(run.to_save_snapshot())))))
		_check(int(restored.narrative_flags.profile_bankroll_lost)==40-delta,"metric survives codec/Continue without recomputation")
		facts[str(available)]={"applied":delta,"total_lost":int(run.narrative_flags.profile_bankroll_lost)}
	for bad_value in [null,"bad",{"schema":"old"},_witness(-10)]:
		var bad:Variant=bad_value.duplicate(true) if typeof(bad_value)==TYPE_DICTIONARY else bad_value
		if typeof(bad)==TYPE_DICTIONARY and bad.has("delta"):bad.delta=0.5
		var run:=RunState.new();run.start_new("UNKNOWN-METRIC")
		run.record_profile_game_result({"ok":true,"game_id":"blackjack","currency":"chips","deltas":{"chips_delta":-40},"applied_currency_settlement":bad})
		_check(int(run.narrative_flags.profile_bankroll_lost)==40,"invalid/absent witness preserves prior metric compatibility, never guesses from wallet")
	var cash:=app._result_from_story_log([{"type":"event","bankroll_delta":5,"message":"Five dollars."}])
	_check(int(cash.bankroll_delta)==5 and str(cash.message)=="Five dollars.","ordinary cash story unchanged")
	var ordinary:=app._game_result_from_story_log([{"type":"game_action","game_id":"slot","action_id":"spin","bankroll_delta":5}])
	_check(str(ordinary.message).contains("Bankroll +5"),"ordinary legacy cash summary unchanged")
	if legacy!=null:
		var original:=var_to_bytes(legacy.to_save_snapshot())
		var entry:Dictionary={}
		for row in legacy.story_log:
			if str(row.get("game_id"))=="blackjack" and str(row.get("action_id"))=="peek_hole_card":entry=row
		_check(not entry.is_empty(),"actual historical caught Peek found")
		for reader in [Callable(app,"_result_from_story_log"),Callable(app,"_game_result_from_story_log")]:
			var result:Dictionary=reader.call([entry])
			_check(bool(result.get("applied_currency_unknown",false)),"historical applied loss explicitly unknown")
			_check(not result.has("currency_delta") and not result.has("applied_currency_settlement"),"missing witness is not a measured zero")
			_check(str(result.message).contains("40 chips") and str(result.message).contains("not recorded"),"historical nominal penalty labelled accurately")
			_check(int(result.bankroll_delta)==0,"historical chip penalty is not a cash debit")
		_check(var_to_bytes(legacy.to_save_snapshot())==original,"legacy history/balances/metrics remain byte-equivalent in memory")
	app.free()
	_finish()

func _witness(delta:int)->Dictionary:
	return {"schema":"bth.applied_currency_settlement/v1","currency":"chips","delta":delta,"cash_delta":0,"chips_delta":delta,"nominal_cash_delta":0,"nominal_chips_delta":-40}

func _money(run:RunState)->Dictionary:
	return {"cash":run.bankroll,"chips":run.grand_casino_chips,"rng":run.rng_state,"clock":run.game_clock_minutes,"inventory":run.inventory.duplicate(true)}

func _install(bundle:String)->void:
	var root_path:=OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT")
	if not _check(root_path.is_absolute_path(),"explicit private distribution root required"):return
	var user:=ProjectSettings.globalize_path("user://")
	var saves:=ProjectSettings.globalize_path(SaveService.new().save_dir())
	DirAccess.make_dir_recursive_absolute(user);DirAccess.make_dir_recursive_absolute(saves)
	for name in ["foundation_ui_autosave.json","foundation_ui_autosave.json.bak"]:
		_check(DirAccess.copy_absolute(bundle.path_join(name),saves.path_join(name))==OK,"copy private save companion")
	_check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"),user.path_join(".crew_host_authority_v1"))==OK,"copy private authority companion")

func _check(ok:bool,message:String)->bool:
	checks+=1
	if not ok:failures.append(message)
	return ok

func _finish()->void:
	var output:=OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"facts":facts,"scope":"Synthetic consumer contracts and unchanged official legacy save; no new wager or historical refund."},"  "));file.close()
	print("APPLIED_PEEK_CONSUMERS checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
