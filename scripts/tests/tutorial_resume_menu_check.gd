extends SceneTree

const Host = preload("res://scripts/ui/foundation_main.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _host() -> Control:
	var app=Host.new()
	app.continuous_environment_clock_enabled=false
	app.script_prewarm_stopping=true
	root.add_child(app)
	app.size=Vector2(1280,720)
	return app

func _run() -> void:
	if OS.get_environment("BTH_SAVE_DIR").is_empty():quit(64);return
	root.size=Vector2i(1280,720)
	var app=_host()
	for _i in range(3):await process_frame
	_check(app.start_tutorial_run(),"First Night did not start")
	for _i in range(4):await process_frame
	var before=_facts(app)
	_check(app._autosave_foundation_run("Explicit tutorial Save.",true),"explicit Save failed")
	_check(app.save_service.has_run(app.autosave_slot_id),"explicit Save left no Resume Slot")
	_check(app.return_to_main_menu(),"Main Menu failed")
	_check(app.save_service.has_run(app.autosave_slot_id),"Main Menu deleted unfinished tutorial")
	app.queue_free();await process_frame;await process_frame
	# A fresh host must restore the lesson and all accepted state, not start PLAY.
	var cold=_host()
	for _i in range(3):await process_frame
	var loaded: bool=cold.load_foundation_run()
	_check(loaded,"cold Continue lost unfinished tutorial")
	if loaded:
		for _i in range(4):await process_frame
		_check(_facts(cold)==before,"cold Continue changed tutorial state")
		_check(cold.return_to_main_menu(),"repeated Main Menu failed")
		_check(cold.load_foundation_run(),"repeated Continue failed")
		_check(_facts(cold)==before,"repeated menu/Continue changed state")
		# An unavailable writer must not dismiss the active lesson.
		var writer=cold.save_service
		cold.save_service=null
		_check(not cold.return_to_main_menu(),"failed Save dismissed tutorial")
		_check(cold.run_state!=null and _facts(cold)==before,"failed Save lost active state")
		cold.save_service=writer
		# Explicit Skip Lessons is the intentional discard boundary.
		cold.request_skip_tutorial()
		_check(cold.tutorial_skip_dialog.visible,"Skip Lessons omitted confirmation")
		cold.tutorial_skip_dialog.hide()
		cold._confirm_skip_tutorial()
		_check(cold.run_state==null and not writer.has_run(cold.autosave_slot_id),"confirmed Skip retained tutorial")
		_check(cold.start_tutorial_run(),"tutorial replay failed")
		cold.run_state.run_status=RunState.RUN_STATUS_ENDED
		_check(cold.return_to_main_menu(),"finished tutorial exit failed")
		_check(not writer.has_run(cold.autosave_slot_id),"finished tutorial retained Resume Slot")
	cold.queue_free();await process_frame;await process_frame
	print("TUTORIAL_RESUME_MENU checks=%d failures=%s" % [checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _facts(app: Control) -> Dictionary:
	var state: RunState=app.run_state
	return {"tutorial":state.is_tutorial_run(),"cash":state.bankroll,"rng":str(state.rng_state),"clock":state.game_clock_minutes,"inventory":state.inventory.duplicate(true),"debt":state.debt.duplicate(true),"room":state.current_environment.get("id"),"lessons":state.narrative_flags.get("tutorial_lessons_completed",{}).duplicate(true),"lesson":app.coach_overlay.active_lesson_id()}

func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
