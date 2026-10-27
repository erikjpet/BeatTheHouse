extends SceneTree

const Blackjack = preload("res://scripts/games/blackjack.gd")
const Library = preload("res://scripts/core/content_library.gd")
const Coach = preload("res://scripts/ui/coach_overlay.gd")
const Driver = preload("res://scripts/tests/foundation/blackjack_authority_test_driver.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var library=Library.new();library.load()
	var game=Blackjack.new();game.setup(library.game("blackjack"),library)
	var run=RunState.new();run.start_new("TUTORIAL-RAISE-OUTCOME")
	var environment={"id":"raise_fixture","archetype_id":"small_underground_casino","depth":0,"economic_profile":{"stake_floor":5,"stake_ceiling":100},"security_profile":{"strictness":"low"}}
	var table=game.generate_environment_state(run,environment,run.create_rng("table"))
	# Synthetic previous-hand receipt, not a replay or an accounting assertion.
	table["hands_played"]=1;table["last_result"]={"main_stake":5,"payout":0}
	environment["game_states"]={"blackjack":table};run.current_environment=environment
	var lesson: Dictionary={}
	for candidate in library.tutorial_lessons:
		if str(candidate.get("id",""))=="tutorial_blackjack_raise":lesson=candidate
	_check(not lesson.is_empty(),"raise lesson missing")
	var overlay=_coach(lesson)
	var ui={"selected_stake":5}
	overlay.evaluate_at_boundary(_context(game.coach_state(run,environment,ui)))
	_check(overlay.active_lesson_id()=="tutorial_blackjack_raise","raise lesson did not activate")
	for action in ["blackjack_wager_place_gesture","blackjack_chip","surface_stake_up"]:
		overlay.notify_action(action)
	_check(not bool(overlay.seen.get("tutorial_blackjack_raise",false)),"gesture begin/denomination intent completed an unchanged wager")
	overlay.evaluate_at_boundary(_context(game.coach_state(run,environment,ui)))
	_check(not bool(overlay.seen.get("tutorial_blackjack_raise",false)),"unchanged wager completed on refresh")
	ui["selected_stake"]=4
	_check(not bool(game.coach_state(run,environment,ui).get("wager_raised",false)),"reduced/minimum wager counted as raised")
	var cash=run.bankroll;var rng=run.rng_state
	var command=game.surface_action_command("blackjack_chip",0,false,{"selected_stake":5},run,environment)
	var staged: Dictionary=command.get("ui_state",{})
	_check(int(command.get("set_stake",0))==6,"real chip placement did not raise five to six")
	_check(run.bankroll==cash and run.rng_state==rng,"staging changed money or RNG")
	var raised=game.coach_state(run,environment,staged)
	_check(bool(raised.get("wager_raised",false)),"real raised wager missing from coach projection")
	overlay.evaluate_at_boundary(_context(raised))
	_check(bool(overlay.seen.get("tutorial_blackjack_raise",false)),"real raised wager did not complete lesson")
	# Rebuild the coach from retained pending-wager state: no transient input needed.
	var cold=_coach(lesson);cold.evaluate_at_boundary(_context(raised))
	_check(bool(cold.seen.get("tutorial_blackjack_raise",false)),"restored raised wager lost completion")
	var active=staged.duplicate(true)
	active["player_hands"]=[{"cards":[{"rank":7,"suit":"clubs"},{"rank":6,"suit":"spades"}]}]
	active["dealer_cards"]=[{"rank":9,"suit":"hearts"}]
	_check(not bool(game.coach_state(run,environment,active).get("wager_raised",false)),"live hand counted as a pending raise")
	_check(run.bankroll==cash and run.rng_state==rng,"coach observations changed money or RNG")
	# Existing authority fixture adapter stages a valid pending session. Restoring
	# it is observational and must reject the same ledger under another table.
	Driver._seed_session(game,run,environment,staged)
	var restored=game.restored_surface_ui_state(run,environment)
	_check(int(restored.get("selected_stake",0))==6,"valid pending wager did not restore")
	_check(run.bankroll==cash and run.rng_state==rng,"pending-wager restore changed money or RNG")
	var other=environment.duplicate(true);other["id"]="different_table"
	_check(game.restored_surface_ui_state(run,other).is_empty(),"restore accepted another table's ledger")
	overlay.queue_free();cold.queue_free();await process_frame
	print("TUTORIAL_BLACKJACK_RAISE checks=%d failures=%s" % [checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _coach(lesson: Dictionary) -> Control:
	var coach=Coach.new();root.add_child(coach);coach.set_lessons([lesson])
	coach.restore_seen({"tutorial_blackjack_clean_finish":true})
	coach.begin_tutorial_run({"tutorial_blackjack_clean_finish":true})
	return coach

func _context(game_state: Dictionary) -> Dictionary:
	return {"screen":"GAME","environment_archetype":"small_underground_casino","game_id":"blackjack","run":{"tutorial":true,"flags":{}},"game":game_state,"viewport_rect":Rect2(0,0,1280,720),"anchor_rects":{"surface_actions":{"blackjack_wager_place_gesture":Rect2(40,610,80,60)}}}

func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
