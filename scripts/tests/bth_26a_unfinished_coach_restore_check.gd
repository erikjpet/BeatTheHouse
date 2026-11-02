extends SceneTree
# Actual authored family-phone definition, delayed live anchor, real overlay and
# Main Menu/Resume controls. Synthetic UI host: no R01, RunState, phone call,
# finance, Save or profile/key access. Not an actual-profile persistence claim.
const ExistingMenuTest := preload("res://scripts/tests/coach_run_menu_visibility_check.gd")
const Coach := preload("res://scripts/ui/coach_overlay.gd")
const Talk := preload("res://scripts/ui/talk_dock.gd")
const LESSON_ID := "tutorial_family_phone"
const ANCHOR_ID := "event:call_brother_in_law"
var checks := 0
var failures: Array[String] = []
var cases: Array = []
var baseline := false
func _init() -> void: call_deferred("_run")
func _frames(n: int = 3) -> void:
	for i in range(n): await process_frame
func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok
func _lesson() -> Dictionary:
	var rows: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial/lessons.json"))
	if typeof(rows) != TYPE_ARRAY: return {}
	for raw in rows:
		if typeof(raw) == TYPE_DICTIONARY and str(raw.get("id", "")) == LESSON_ID: return raw.duplicate(true)
	return {}
func _run() -> void:
	baseline = OS.get_environment("BTH26A_EXPECT_BASELINE") == "1"
	var lesson := _lesson()
	if not _check(not lesson.is_empty() and str(lesson.get("delivery", "")) == "dialogue", "actual authored family-phone dialogue lesson loaded unchanged"):
		_finish(); return
	for dimensions in [Vector2i(1280,720), Vector2i(390,844)]:
		await _case(lesson,dimensions)
	_finish()
func _case(lesson: Dictionary, dimensions: Vector2i) -> void:
	var viewport := SubViewport.new(); viewport.size=dimensions; viewport.disable_3d=true; root.add_child(viewport)
	var host := ExistingMenuTest.MenuOnly.new(); host.size=Vector2(dimensions); host.current_screen=host.SCREEN_ENVIRONMENT; viewport.add_child(host)
	host.coach_overlay=Coach.new(); host.add_child(host.coach_overlay); host.coach_overlay.set_reduce_motion(true)
	host.talk_dock=Talk.new(); host.add_child(host.talk_dock)
	host._build_run_menu_overlay()
	var coach: Coach=host.coach_overlay
	var requested: Array=[]; var completed: Array=[]
	coach.dialogue_requested.connect(func(id,node,phase): requested.append([id,node,phase]))
	coach.lesson_completed.connect(func(id): completed.append(id))
	coach.restore_seen({"tutorial_crew_warning":true}); coach.set_lessons([lesson])
	var context: Dictionary={"screen":"ENVIRONMENT","environment_archetype":"corner_store","run":{"tutorial":true},"viewport_rect":Rect2(Vector2.ZERO,Vector2(dimensions)),"anchor_rects":{"interactable_objects":{}}}
	coach.evaluate_at_boundary(context); await _frames()
	if not _check(coach.active_lesson_id()==LESSON_ID and coach.panel.is_visible_in_tree() and not bool(coach.prepared_snapshot.get("anchor_found",true)), "unfinished real phone lesson initially shows its missing-anchor fallback"):
		viewport.queue_free(); await _frames(); return
	var before_seen: Dictionary=coach.seen.duplicate(true)
	var before_lesson: Dictionary=coach.active_lesson.duplicate(true)
	var anchor:=Rect2(Vector2(30,150),Vector2(80,70))
	coach.update_active_anchor_rect("interactable_object",ANCHOR_ID,anchor); await _frames()
	_check(requested.size()==1 and coach.panel.visible and coach.active_anchor_rect().has_area(), "late live anchor requests Pal once while retaining the visible pointer")
	host.talk_dock.entry={"event_id":"tutorial_guide:"+LESSON_ID,"dialogue_id":"tutorial_pal_guidance","speaker":{"character_id":"pal_tutorial_guide"}}; host.talk_dock.conversation_active=true
	host.open_run_menu(); await _frames()
	_check(not coach.panel.is_visible_in_tree() and not coach.focus_layer.is_visible_in_tree(), "Run Menu still suppresses both card and focus")
	# The next host boundary now has complete anchor geometry. This was absent
	# from the previous coach-only Menu fixture and changes dialogue projection.
	var ready_context: Dictionary=context.duplicate(true)
	ready_context.anchor_rects.interactable_objects[ANCHOR_ID]=anchor
	coach.evaluate_at_boundary(ready_context); await _frames()
	_check(not coach.panel.visible and bool(coach.prepared_snapshot.get("anchor_found",false)), "anchor-ready relayout while Menu is open stays hidden")
	await _click(viewport,host.run_menu_resume_button.get_global_rect().get_center())
	coach.evaluate_at_boundary(ready_context); await _frames()
	_check(not host.run_menu_overlay.visible,"connected Resume closes the real Main menu")
	_check(not coach.panel.visible if baseline else coach.panel.is_visible_in_tree(), "baseline reproduces lost card" if baseline else "Resume restores the SAME previously-visible unfinished phone pointer")
	_check(coach.active_lesson==before_lesson and coach.seen==before_seen and completed.is_empty() and requested.size()==1, "Menu and relayout neither complete/skip the lesson nor replay Pal")
	cases.append({"viewport":str(dimensions),"restored":coach.panel.visible,"lesson":coach.active_lesson_id(),"requests":requested.size(),"baseline":baseline})
	if baseline:
		viewport.queue_free(); await _frames(); return
	# Natural conversations retain temporary ownership; removing both owners
	# must restore only the same already-presented unfinished lesson.
	host.talk_dock.entry={"dialogue_id":"synthetic_natural_conversation"}; host._sync_coach_panel_for_talk_dock()
	_check(not coach.panel.visible,"natural conversation still suppresses this pointer")
	host.open_run_menu(); await _frames(); host.close_run_menu(); await _frames()
	_check(not coach.panel.visible,"Resume cannot uncover a remaining natural conversation")
	host.talk_dock.conversation_active=false; host._sync_coach_panel_for_talk_dock(); await _frames()
	_check(coach.panel.visible,"ending both temporary owners restores the unfinished pointer")
	var lifecycle: Dictionary=host._coach_lifecycle_snapshot()
	coach.suspend(); host._restore_coach_lifecycle_snapshot(lifecycle); coach._render_active(false); await _frames()
	_check(coach.panel.visible and coach.active_lesson==before_lesson and requested.size()==1,"existing Main lifecycle checkpoint retains presentation history without new fields or dialogue replay")
	# A first-time voiced lesson whose anchor is already ready must NOT become
	# a blanket extra panel. Reset clears the prior visible-card history.
	coach.restore_seen({"tutorial_crew_warning":true}); coach.set_lessons([lesson]); coach.evaluate_at_boundary(ready_context); await _frames()
	_check(not coach.panel.visible and coach.active_lesson_id()==LESSON_ID,"new anchored dialogue-only lesson remains dialogue-only")
	host.open_run_menu(); await _frames(); host.close_run_menu(); coach.evaluate_at_boundary(ready_context); await _frames()
	_check(not coach.panel.visible,"Menu must not invent a card that had never been shown")
	_check(coach.notify_dialogue_completed(LESSON_ID) and coach.panel.visible,"existing explicit dialogue acknowledgement can still reveal its instruction")
	coach.ok_button.pressed.emit(); await _frames()
	_check(completed==[LESSON_ID] and coach.active_lesson_id().is_empty(),"only deliberate Skip tip completes this synthetic UI lesson once")
	viewport.queue_free(); await _frames()
func _click(viewport: Viewport, point: Vector2) -> void:
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0; event.pressed=pressed
		viewport.push_input(event,true); await process_frame
func _finish() -> void:
	print("BTH26A_UNFINISHED_COACH_RESULT "+JSON.stringify({"id":"BTH-26-A","checks":checks,"failures":failures,"cases":cases,"baseline":baseline,"R01_or_phone_call_or_Save_or_key_access":false,"actual_profile_or_Web_qualified":false}))
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
