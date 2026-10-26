extends SceneTree
const Game := preload("res://scripts/games/bar_dice.gd")
const Run := preload("res://scripts/core/run_state.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")

var checks := 0
var failures: Array[String] = []

func _init() -> void:
	var game := Game.new()
	game.definition = {"id":"bar_dice","family":"dice","legal_actions":[],"cheat_actions":[]}
	var run := Run.new()
	run.start_new("BAR-DICE-SURFACE-RESTORE")
	run.bankroll = 100
	var env := {"id":"restore_bar","archetype_id":"bar","economic_profile":{"stake_floor":9,"stake_ceiling":25},"game_states":{}}
	var table := game.generate_environment_state(run, env, run.create_rng("restore_table"))
	table["stake_ladder"] = [9,10,25]
	table["selected_stake_index"] = 1
	var session := {"rolled":true,"dice":[6,6,5,4,3],"reroll":[1],"last_rerolled":[1,2,3,4],"shake_number":2,"selected_stake_index":1,"bar_dice_ritual_phase":"shake","tumble_id":"old_process","tumble_started_msec":900000,"tumble_indices":[1,2,3,4]}
	var binding := Run.action_authority_table_binding("bar_dice", env)
	var ledger := Authority.stage_session(Authority.default_ledger(binding, run.action_authority_checkpoint_fingerprint()), session)
	table[Authority.LEDGER_KEY] = ledger
	env.game_states = {"bar_dice":table}
	run.current_environment = env
	var before := run.to_dict().duplicate(true)
	var restored := game.restored_surface_ui_state(run, env)
	_check(bool(restored.get("rolled",false)), "Restore the open cup")
	for key in ["dice","reroll","shake_number","selected_stake_index","bar_dice_ritual_phase"]:
		_check(restored.get(key)==session.get(key), "Restore exact %s" % key)
	for key in ["tumble_id","tumble_started_msec","tumble_indices"]:
		_check(not restored.has(key), "Do not replay old-process %s" % key)
	_check(run.to_dict()==before, "Reading a restored surface must not change account, RNG or authority")
	if not restored.is_empty():
		restored.dice[0] = 1
		_check(ledger.session.dice[0]==6, "Returned cup is detached from durable authority")
	var cover := session.duplicate(true)
	cover.rolled = false
	cover.bar_dice_ritual_phase = "cover"
	table[Authority.LEDGER_KEY] = Authority.stage_session(ledger,cover)
	_check(str(game.restored_surface_ui_state(run,env).get("bar_dice_ritual_phase",""))=="cover", "Keep an agreed cover before the cup opens")
	for action in ["bar_dice_load","bar_dice_palm"]:
		var armed: Dictionary=game.surface_action_command(action,0,false,session,run,env).get("ui_state",{})
		table[Authority.LEDGER_KEY] = Authority.stage_session(ledger,armed)
		var armed_restored := game.restored_surface_ui_state(run,env)
		var challenge_key := "controlled_roll" if action=="bar_dice_load" else "palmed_swap_challenge"
		_check(not armed_restored.is_empty() and armed_restored.get(challenge_key)==armed.get(challenge_key), "Keep exact accepted %s timing and grades" % action)
		_check(armed_restored.get("dice")==session.dice and armed_restored.get("reroll")==session.reroll, "Timing restoration must not change dice choices")
		if not armed_restored.is_empty():
			var challenge: Dictionary=armed_restored.get(challenge_key,{})
			armed_restored["surface_time_msec"]=200
			var first: Dictionary=game._controlled_roll_meter(challenge,armed_restored) if action=="bar_dice_load" else game._palmed_swap_meter(challenge,armed_restored)
			armed_restored["surface_time_msec"]=400
			var second: Dictionary=game._controlled_roll_meter(challenge,armed_restored) if action=="bar_dice_load" else game._palmed_swap_meter(challenge,armed_restored)
			_check(first.get("progress")==null or first.get("progress")!=second.get("progress"), "Restored meter moves with a new process clock")
	var corrupt := ledger.duplicate(true)
	corrupt.version = Authority.LEDGER_VERSION + 1
	table[Authority.LEDGER_KEY] = corrupt
	_check(game.restored_surface_ui_state(run,env).is_empty(), "Do not restore an invalid ledger version")
	corrupt = ledger.duplicate(true)
	corrupt.session = []
	table[Authority.LEDGER_KEY] = corrupt
	_check(game.restored_surface_ui_state(run,env).is_empty(), "Do not restore malformed session storage")
	corrupt = ledger.duplicate(true)
	corrupt.pending_delivery = {"stake":1}
	table[Authority.LEDGER_KEY] = corrupt
	_check(game.restored_surface_ui_state(run,env).is_empty(), "Do not promote a malformed pending delivery")
	table[Authority.LEDGER_KEY] = ledger
	var other_room := env.duplicate(true)
	other_room.id = "other_bar"
	_check(game.restored_surface_ui_state(run,other_room).is_empty(), "Do not restore another table's session")
	run.bankroll = 1
	_check(game.restored_surface_ui_state(run,env).is_empty(), "An unfundable cup returns to the ante controls")
	run.bankroll = 100
	var closed := session.duplicate(true)
	closed.rolled = false
	closed.bar_dice_ritual_phase = "settle"
	table[Authority.LEDGER_KEY] = Authority.stage_session(ledger,closed)
	_check(game.restored_surface_ui_state(run,env).is_empty(), "A settled session must not reopen the cup")
	var malformed := session.duplicate(true)
	malformed.dice = []
	table[Authority.LEDGER_KEY] = Authority.stage_session(ledger,malformed)
	_check(game.restored_surface_ui_state(run,env).is_empty(), "Do not generate replacement dice for an incomplete saved cup")
	table.erase(Authority.LEDGER_KEY)
	_check(game.restored_surface_ui_state(run,env).is_empty(), "Legacy tables without a session keep their normal ante screen")
	print("BAR_DICE_SURFACE_RESTORE ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:failures.append(message)
