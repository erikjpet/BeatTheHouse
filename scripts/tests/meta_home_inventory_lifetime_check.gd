extends SceneTree

const Host = preload("res://scripts/ui/foundation_main.gd")
const Service = preload("res://scripts/core/meta_collection_service.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if OS.get_environment("BTH_SAVE_DIR").is_empty():quit(64);return
	root.size=Vector2i(1280,720)
	var app=_host()
	for _i in range(3):await process_frame
	app._ensure_full_content_library_loaded()
	app.meta_collection_service=Service.new()
	var card=app.meta_collection_service.mint_players_card({"starter_card":true})
	var id=int(card.get("instance_id",0))
	app.meta_collection_service.save()
	app._enter_meta_location("home",true)
	for _i in range(8):await process_frame
	_check(app.coach_overlay.active_lesson_id()=="tutorial_meta_home_card","fixture did not enter first Home lesson")
	var before=app.meta_collection_service.snapshot()
	var cash=app.run_state.bankroll;var rng=app.run_state.rng_state
	for repetition in range(2):
		app.open_meta_container()
		for _i in range(6):await process_frame
		var screen=app.meta_item_interaction_screen
		_check(screen.is_open(),"Home Bag did not open")
		var unpack=_button(screen,"Unpack")
		_check(unpack!=null,"carried-card Unpack control missing")
		if unpack!=null:
			# Real pointer activation focuses this retiring action button. Preserve
			# that ownership while its ordinary signal rebuilds the detail controls.
			unpack.grab_focus();unpack.pressed.emit()
		for _i in range(4):await process_frame
		_check(app.meta_collection_service.snapshot()==before,"rejected Back Alley Unpack changed the collection")
		_check(is_instance_valid(root.gui_get_focus_owner()),"detail rebuild left no live modal focus owner")
		screen._surface._on_slot_pressed(0)
		for _i in range(4):await process_frame
		_check(screen.selected_key()=="meta:item:%d" % id,"card reselection lost exact instance")
		if repetition==0:
			screen._close_button.grab_focus();screen._close_button.pressed.emit()
		else:
			var cancel=InputEventKey.new();cancel.keycode=KEY_ESCAPE;cancel.pressed=true
			root.push_input(cancel,true);await process_frame
			cancel.pressed=false;root.push_input(cancel,true)
		for _i in range(4):await process_frame
		_check(not screen.is_open(),"Close/Escape failed after Unpack and reselection")
		_check(app.modal_focus_scope.active_root()==null and not app.modal_focus_scope._redirecting,"inventory left stale focus ownership")
	_check(app.run_state.bankroll==cash and app.run_state.rng_state==rng,"inventory changed money or gameplay RNG")
	app.queue_free();await process_frame;await process_frame
	# Fresh host restores the same profile store without replaying card grants.
	var cold=_host()
	for _i in range(3):await process_frame
	cold.open_meta_home();cold.open_meta_container()
	for _i in range(6):await process_frame
	_check(cold.meta_collection_service.owned_instances().size()==before.get("owned_instances",[]).size(),"cold Home duplicated/lost collection items")
	cold.meta_item_interaction_screen._surface._on_slot_pressed(0)
	cold.meta_item_interaction_screen._close_button.pressed.emit()
	for _i in range(4):await process_frame
	_check(not cold.meta_item_interaction_screen.is_open(),"cold Home selection/Close failed")
	cold.queue_free();await process_frame;await process_frame
	print("META_HOME_INVENTORY_LIFETIME checks=%d failures=%s" % [checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)

func _host() -> Control:
	var app=Host.new();app.continuous_environment_clock_enabled=false;app.script_prewarm_stopping=true
	root.add_child(app);app.size=Vector2(1280,720)
	return app

func _button(parent: Node,text: String) -> Button:
	for child in parent.find_children("*","Button",true,false):
		if child.text==text and not child.is_queued_for_deletion():return child
	return null

func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
