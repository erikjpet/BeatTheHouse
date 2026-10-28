extends SceneTree

const Blackjack := preload("res://scripts/games/blackjack.gd")
const Driver := preload("res://scripts/tests/foundation/blackjack_authority_test_driver.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}
var library: ContentLibrary

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var private_ready := true
	for key in ["BTH_DISTRIBUTION_DATA_ROOT","BTH_PROFILE_INVENTORY_PATH","BTH_META_COLLECTION_PATH","BTH_USER_SETTINGS_PATH","BTH_TARGET_OUTPUT"]:
		private_ready = private_ready and not OS.get_environment(key).is_empty()
	if not check(private_ready,"private diagnostic persistence roots required"):
		_finish()
		return
	# Install the copied legacy authority key before any synthetic codec call.
	var captured_ready := not OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and _install_bundle()
	library = ContentLibrary.new()
	library.load(false)
	if captured_ready: _legacy_unknown()
	for available in [10,0,40,70]: _caught_case(available)
	_normal_settlements()
	_witness_validation()
	_finish()

func _fixture(available: int) -> RunState:
	var run := RunState.new()
	run.start_new("APPLIED-PEEK-RECEIPT")
	# Materialize the normal reputation default, as official restore does.
	run.crew_change_reputation(0)
	run.bankroll = 78
	run.grand_casino_chips = available + 40
	run.current_environment = {"id":"applied_peek_table","archetype_id":RunState.GRAND_CASINO_ARCHETYPE_ID,"display_name":"Synthetic receipt table","game_ids":["blackjack"],"economic_profile":{"stake_floor":1,"stake_ceiling":100},"security_profile":{},"game_states":{}}
	return run

func _game() -> GameModule:
	var game := Blackjack.new()
	for definition in library.games:
		if str(definition.get("id","")) == "blackjack":
			game.setup(definition,library)
	return game

func _caught_case(available: int) -> void:
	var run := _fixture(available)
	var game := _game()
	var table := game.generate_environment_state(run,run.current_environment,run.create_rng("receipt_table"))
	game.environment_state_generated(run,run.current_environment,table)
	# Explicit synthetic always-watched attention, not an original save replay or
	# a future outcome search. The production action authority still owns RNG.
	table["dealer_profile"] = {"attention_base":100,"gaze_speed":95,"blink_offset":0,"tell":"locks onto your hands"}
	table["patrons"] = []
	table["side_bets"] = []
	run.current_environment.game_states["blackjack"] = table
	var environment := run.current_environment
	var deal_command := game.surface_action_command("blackjack_deal",0,false,{"selected_stake":40,"surface_time_msec":24000},run,environment)
	var deal := Driver.resolve(game,"blackjack_place_bet",40,run,environment,run.create_rng(),deal_command.get("ui_state",{}))
	if not check(bool(deal.get("ok",false)),"%s actual authority accepts paid Deal" % available):
		facts[str(available)] = {"deal":deal}
		return
	check(run.bankroll == 78 and run.grand_casino_chips == available,"%s Deal charges exactly40 chips" % available)
	check(GameModule.applied_currency_settlement(deal).is_empty(),"ordinary Deal has no Peek witness")
	environment = run.current_environment
	var canonical: Dictionary = environment.game_states.blackjack.get(Authority.LEDGER_KEY,{}).get("session",{}).duplicate(true)
	canonical["surface_time_msec"] = 30000
	var peek_command := game.surface_action_command("blackjack_peek",0,false,canonical,run,environment)
	if not check(str(peek_command.get("action_id","")) == "peek_hole_card" and bool(peek_command.get("ui_state",{}).get("peek_caught_watching",false)),"%s synthetic watched Peek enters confrontation" % available):
		facts[str(available)] = {"deal":deal,"command":peek_command,"session":canonical}
		return
	var result := Driver.resolve(game,"peek_hole_card",0,run,environment,run.create_rng(),peek_command.get("ui_state",{}))
	if not check(bool(result.get("ok",false)),"%s watched Peek accepted by production authority" % available):
		facts[str(available)] = {"result":result}
		return
	var applied := -mini(available,40)
	var witness := GameModule.applied_currency_settlement(result)
	check(not witness.is_empty() and int(witness.get("delta",1)) == applied,"%s explicit measured applied loss" % available)
	check(int(witness.get("cash_delta",1)) == 0 and int(witness.get("nominal_chips_delta",0)) == -40 and int(witness.get("nominal_cash_delta",1)) == 0,"witness retains routed nominal instructions")
	check(run.bankroll == 78 and run.grand_casino_chips == available + applied,"existing clamp and cash funding unchanged")
	check(int(result.get("blackjack_confiscated_bet",0)) == 40 and int(result.get("deltas",{}).get("chips_delta",0)) == -40,"nominal penalty and debit instructions unchanged")
	check(bool(result.get("blackjack_table_barred",false)) and run.suspicion_level() >= 60 and run.suspicion_level() <= RunState.BLACKJACK_BACKOFF_HEAT,"bar and existing Heat rule retained")
	check(str(result.get("currency","")) == "chips" and int(result.get("currency_delta",1)) == applied and int(result.get("settlement",{}).get("delta",1)) == applied,"warm structured receipt displays actual chips")
	var stored: Dictionary = run.current_environment.game_states.blackjack.get("last_result",{})
	check(int(stored.get("nominal_bankroll_delta",0)) == -40 and int(stored.get("confiscated_bet",0)) == 40,"durable nominal penalty metadata remains40")
	check(int(stored.get("bankroll_delta",1)) == applied,"existing Blackjack headline reads actual applied amount")
	check(GameModule.applied_currency_settlement(stored) == witness and int(stored.get("settlement",{}).get("delta",1)) == applied,"durable table receipt carries measured witness")
	var story := _peek_story(run)
	check(GameModule.applied_currency_settlement(story) == witness and int(story.get("bankroll_delta",1)) == applied and int(story.get("nominal_bankroll_delta",0)) == -40,"prospective story records actual loss with nominal retained")
	check(int(story.get("total_wager",0)) == 40 and int(story.get("settlement",{}).get("delta",1)) == applied,"story wager semantics and measured settlement distinct")
	var renormalized := result.duplicate(true)
	GameModule.normalize_skill_cheat_contract(renormalized)
	var normalized_story: Array = renormalized.get("deltas",{}).get("story_log",[])
	check(not normalized_story.is_empty() and int(normalized_story[0].get("bankroll_delta",1)) == applied,"later skill normalization preserves measured story loss")
	var money_before := {"cash":run.bankroll,"chips":run.grand_casino_chips,"rng":run.rng_state}
	GameModule.finalize_routed_settlement(run,result,result.get("deltas",{}))
	check(run.bankroll == money_before.cash and run.grand_casino_chips == money_before.chips and run.rng_state == money_before.rng and int(run.current_environment.game_states.blackjack.last_result.get("nominal_bankroll_delta",0)) == -40,"repeated formatting preserves funds/RNG/nominal metadata")
	var before := run.to_save_snapshot()
	var duplicate := GameModule.apply_result(run,result.duplicate(true))
	check(not bool(duplicate.get("ok",true)) and str(duplicate.get("error_code","")) == "authority_receipt_rejected","duplicate accepted receipt rejected")
	check(_equal(run.to_save_snapshot(),before),"duplicate preserves complete wallet/ledger/story/RNG")
	var slot := "applied_peek_%s" % available
	var service := SaveService.new()
	var save_error := service.save_run(run,slot)
	check(save_error == OK,"%s official SaveService persists receipt" % available)
	var restored: Variant = SaveService.new().load_run(slot) if save_error == OK else null
	var restore_differences: Array = []
	check(restored is RunState,"%s fresh SaveService restores receipt" % available)
	if restored is RunState:
		restore_differences = _differences(before,restored.to_save_snapshot())
		# JSON rounds these four card-animation coordinates by less than1e-9.
		# Every other field, including all receipt/ledger money, stays exact.
		check(restore_differences.all(_known_codec_visual_float),"official codec preserves complete state except known visual float text roundoff")
		check(restored.bankroll == run.bankroll and restored.grand_casino_chips == run.grand_casino_chips and restored.rng_state == run.rng_state,"official codec preserves exact integer money/RNG")
		check(_equal(GameModule.applied_currency_settlement(_peek_story(restored)),witness),"codec preserves known measured zero or loss")
		var restored_before: Dictionary = restored.to_save_snapshot()
		check(not bool(GameModule.apply_result(restored,result.duplicate(true)).get("ok",true)) and _equal(restored.to_save_snapshot(),restored_before),"restored ledger still rejects duplicate receipt")
	facts[str(available)] = {"cash":run.bankroll,"chips":run.grand_casino_chips,"witness":witness,"nominal_penalty":result.get("blackjack_confiscated_bet"),"settlement":result.get("settlement"),"message":result.get("message"),"rng":str(run.rng_state),"save_error":save_error,"last_result":stored,"restore_differences":restore_differences}

func _peek_story(run: RunState) -> Dictionary:
	for index in range(run.story_log.size()-1,-1,-1):
		var entry: Dictionary = run.story_log[index]
		if str(entry.get("type","")) == "game_action" and str(entry.get("game_id","")) == "blackjack" and str(entry.get("action_id","")) == "peek_hole_card": return entry
	return {}

func _normal_settlements() -> void:
	for chips in [false,true]:
		var run := _fixture(70)
		if not chips: run.current_environment["archetype_id"] = "bar"
		var before_cash := run.bankroll
		var before_chips := run.grand_casino_chips
		var result := GameModule.build_action_result({"game_id":"bar_dice","action_id":"play_basic","environment_id":run.current_environment.id,"environment_archetype_id":run.current_environment.archetype_id,"bankroll_delta":25,"message":"A normal win.","won":true})
		check(bool(GameModule.apply_result(run,result).get("ok",false)),"normal settlement accepts")
		check(GameModule.applied_currency_settlement(result).is_empty(),"normal settlement does not invent Peek witness")
		check(run.bankroll == before_cash + (0 if chips else 25) and run.grand_casino_chips == before_chips + (25 if chips else 0),"normal currency authority unchanged")
		check(int(result.get("currency_delta",0)) == 25 and str(result.get("currency","")) == ("chips" if chips else "cash"),"normal settlement presentation unchanged")

func _witness_validation() -> void:
	check(GameModule.applied_currency_settlement({}).is_empty(),"missing witness remains unknown")
	var valid := {"schema":GameModule.APPLIED_CURRENCY_SETTLEMENT_SCHEMA,"currency":"chips","delta":0,"cash_delta":0,"chips_delta":0,"nominal_cash_delta":0,"nominal_chips_delta":-40}
	check(not GameModule.applied_currency_settlement({"applied_currency_settlement":valid}).is_empty(),"measured zero is known")
	for pair in [["schema","legacy"],["currency","cash"],["delta",1],["chips_delta",-41],["cash_delta",-1],["delta",0.5],["nominal_chips_delta",1]]:
		var invalid := valid.duplicate(true)
		invalid[pair[0]] = pair[1]
		check(GameModule.applied_currency_settlement({"applied_currency_settlement":invalid}).is_empty(),"invalid witness is unknown: %s" % str(pair))
	var holder := {"applied_currency_settlement":valid}
	var copied := GameModule.applied_currency_settlement(holder)
	copied["delta"] = -99
	check(int(valid.delta) == 0,"read-only witness getter returns owned copy")

func _legacy_unknown() -> void:
	var legacy: Variant = SaveService.new().load_run("foundation_ui_autosave")
	if not check(legacy is RunState,"official copied historical f041 loads"): return
	var before: Dictionary = legacy.to_save_snapshot()
	var story := _peek_story(legacy)
	check(not story.is_empty(),"legacy includes already-accepted watched Peek")
	check(GameModule.applied_currency_settlement(story).is_empty(),"legacy actual loss stays unknown despite later funding")
	var table: Dictionary = legacy.current_environment.get("game_states",{}).get("blackjack",{})
	check(GameModule.applied_currency_settlement(table.get("last_result",{})).is_empty(),"legacy durable receipt is not reconstructed")
	check(_equal(legacy.to_save_snapshot(),before),"legacy witness reads preserve full original state")
	facts["legacy"] = {"cash":legacy.bankroll,"chips":legacy.grand_casino_chips,"rng":str(legacy.rng_state),"peek_found":not story.is_empty(),"witness_known":false}

func _install_bundle() -> bool:
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	var user_dir := ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(saves)
	DirAccess.make_dir_recursive_absolute(user_dir)
	for name in ["foundation_ui_autosave.json","foundation_ui_autosave.json.bak"]:
		if FileAccess.file_exists(bundle.path_join(name)) and not check(not FileAccess.file_exists(saves.path_join(name)) and DirAccess.copy_absolute(bundle.path_join(name),saves.path_join(name)) == OK,"install private unchanged "+name): return false
	if not check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"),user_dir.path_join(".crew_host_authority_v1")) == OK,"install copied authority key"): return false
	for pair in [["profile_inventory.json","BTH_PROFILE_INVENTORY_PATH"],["meta_collection.json","BTH_META_COLLECTION_PATH"],["settings.json","BTH_USER_SETTINGS_PATH"]]:
		for suffix in ["",".bak"]:
			var original := bundle.path_join(str(pair[0])+suffix)
			if FileAccess.file_exists(original) and not check(DirAccess.copy_absolute(original,OS.get_environment(pair[1])+suffix) == OK,"install copied companion"): return false
	return true

func _equal(left: Variant, right: Variant) -> bool:
	if typeof(left) in [TYPE_INT,TYPE_FLOAT] and typeof(right) in [TYPE_INT,TYPE_FLOAT]: return left == right
	if typeof(left) != typeof(right): return false
	if typeof(left) in [TYPE_ARRAY,TYPE_DICTIONARY]:
		if left.size() != right.size(): return false
		for key in left.keys() if typeof(left) == TYPE_DICTIONARY else range(left.size()):
			if typeof(left) == TYPE_DICTIONARY and not right.has(key): return false
			if not _equal(left[key],right[key]): return false
		return true
	return left == right

func _differences(left: Variant, right: Variant, path: String = "state") -> Array:
	if _equal(left,right): return []
	var result: Array = []
	if typeof(left) == typeof(right) and typeof(left) in [TYPE_DICTIONARY,TYPE_ARRAY]:
		var keys: Array = left.keys() if typeof(left) == TYPE_DICTIONARY else range(maxi(left.size(),right.size()))
		if typeof(left) == TYPE_DICTIONARY:
			for key in right.keys():
				if not keys.has(key): keys.append(key)
		for key in keys:
			var left_has: bool = left.has(key) if typeof(left) == TYPE_DICTIONARY else int(key) < left.size()
			var right_has: bool = right.has(key) if typeof(right) == TYPE_DICTIONARY else int(key) < right.size()
			if left_has and right_has: result.append_array(_differences(left[key],right[key],path+"/"+str(key)))
			else: result.append({"path":path+"/"+str(key),"left_present":left_has,"right_present":right_has})
	else:
		var difference := {"path":path,"before":left,"restored":right,"before_type":type_string(typeof(left)),"restored_type":type_string(typeof(right))}
		if typeof(left) == TYPE_FLOAT and typeof(right) == TYPE_FLOAT:
			difference["absolute_error"] = absf(left-right)
			difference["before_17_digits"] = "%.17f" % left
			difference["restored_17_digits"] = "%.17f" % right
		result.append(difference)
	return result

func _known_codec_visual_float(difference: Dictionary) -> bool:
	var path := str(difference.get("path",""))
	return path.begins_with("state/current_environment/game_states/blackjack/_blackjack_action_authority/") \
		and path.contains("/deal_animation_events/") and (path.ends_with("/to/0") or path.ends_with("/to/1")) \
		and str(difference.get("before_type","")) == "float" and str(difference.get("restored_type","")) == "float" \
		and float(difference.get("absolute_error",1.0)) < 1e-9

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok

func _finish() -> void:
	var report := {"checks":checks,"failures":failures,"facts":facts,"fidelity":"Synthetic watched attention and actual production Blackjack action authority. Official SaveService/fresh-service codec; same engine, no browser or separate-process cold UI claim. Copied historical accepted f041 restored read-only, never replayed/refunded. Main/profile consumers are separate primary-owned dependencies."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
	print("BLACKJACK_APPLIED_PEEK checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
