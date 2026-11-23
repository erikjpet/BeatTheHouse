extends SceneTree

# Two synthetic presentation cases using production CoachOverlay nodes and the
# complete authored catalogue. No run, paid hand, profile, save or meta is opened
# or modified; these contexts do not claim ordinary-play or cold-Continue proof.
const Coach = preload("res://scripts/ui/coach_overlay.gd")
const ViewModel = preload("res://scripts/ui/coach_view_model.gd")
const ROUTE := "tutorial_route_choice"
const BEFORE := "tutorial_underground_table"
const GAS := "tutorial_gas_machine"
const RECOVERY := "tutorial_recovery:" + GAS
const CLEAN := "tutorial_blackjack_clean_deal"
const FINISH := "tutorial_blackjack_clean_finish"
const RAISE := "tutorial_blackjack_raise"
var lessons: Array = []
var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var completed: Array[String] = []
var activated: Array[String] = []
var dialogue_requests: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var isolation_root := OS.get_environment("BTH_PAL_RECOVERY_ROOT").replace("\\", "/").trim_suffix("/")
	if isolation_root.is_empty() or not ProjectSettings.globalize_path("user://").replace("\\", "/").begins_with(isolation_root + "/"):
		push_error("BTH_PAL_RECOVERY_ROOT must contain this fresh synthetic user:// root")
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var catalogue: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial/lessons.json"))
	if typeof(catalogue) != TYPE_ARRAY or (catalogue as Array).is_empty():
		push_error("The full authored tutorial catalogue did not load")
		quit(2)
		return
	lessons = catalogue
	for id in [GAS, CLEAN, FINISH, RAISE]:
		if not _has_lesson(id):
			push_error("Required authored lesson missing: " + id)
			quit(2)
			return
	await _stale_recovery_yields()
	await _needed_recovery_stays()
	print("COACH_RECOVERY_AUTHORED_YIELD ", JSON.stringify({
		"cases": cases, "checks": checks, "failures": failures,
		"catalogue_lessons": lessons.size(),
		"scope": "Production CoachOverlay and full authored catalogue; synthetic public presentation contexts only. No game, profile, Save/Continue, meta or settlement acceptance."
	}))
	quit(0 if failures.is_empty() else 1)

func _stale_recovery_yields() -> void:
	var first_check := checks
	var first_failure := failures.size()
	var coach := _coach()
	var room := _context(false)
	var table := _context(true)
	var original_room := var_to_bytes(room)
	var original_table := var_to_bytes(table)
	var original_lessons := var_to_bytes(lessons)
	coach.evaluate_at_boundary(room)
	_check(coach.active_lesson_id() == RECOVERY, "full catalogue reproduces Gas recovery in Underground room")
	_check(bool(coach.active_lesson.get("runtime_recovery", false)), "initial advice is a runtime recovery, not an authored completion")
	_check(activated == [RECOVERY] and completed.is_empty(), "initial recovery activates once without completing a lesson")
	coach.evaluate_at_boundary(table)
	_check(coach.active_lesson_id() == RAISE, "settled Underground boundary yields to eligible authored Raise")
	_check(completed == [CLEAN, FINISH], "existing state reconciliation completes Clean Deal and Finish once, in order")
	_check(activated == [RECOVERY, RAISE], "Raise activates once after recovery")
	_check(dialogue_requests == [RAISE], "only current Raise dialogue is requested once")
	_check(_queue_ids(coach).is_empty() and coach.queued_ids.is_empty(), "authored FIFO head is consumed without a duplicate queued lesson")
	_check(bool(coach.seen.get(CLEAN, false)) and bool(coach.seen.get(FINISH, false)), "only already-achieved clean-hand progress is retained")
	_check(not bool(coach.seen.get(GAS, false)) and not bool(coach.seen.get(RECOVERY, false)) and not bool(coach.seen.get(RAISE, false)), "Gas, runtime recovery and unfinished Raise remain uncompleted")
	var retained_seen := var_to_bytes(coach.seen)
	for boundary in range(3):
		coach.evaluate_at_boundary(table)
	_check(coach.active_lesson_id() == RAISE and _queue_ids(coach).is_empty() and coach.queued_ids.is_empty(), "repeated settled boundaries retain one Raise and no queue backlog")
	_check(completed == [CLEAN, FINISH] and activated == [RECOVERY, RAISE] and dialogue_requests == [RAISE], "repeated boundaries duplicate no completion, activation or dialogue")
	_check(var_to_bytes(coach.seen) == retained_seen, "repeated boundaries do not invent further progress")
	_check(var_to_bytes(room) == original_room and var_to_bytes(table) == original_table, "supplied room and table contexts remain byte-exact")
	_check(var_to_bytes(lessons) == original_lessons, "complete authored catalogue remains byte-exact")
	cases.append({"id": "stale_gas_recovery_yields_to_authored_raise", "checks": checks - first_check, "failures": failures.size() - first_failure})
	coach.queue_free()
	await process_frame

func _needed_recovery_stays() -> void:
	var first_check := checks
	var first_failure := failures.size()
	var coach := _coach()
	var room := _context(false)
	coach.evaluate_at_boundary(room)
	_check(coach.active_lesson_id() == RECOVERY, "legitimate Gas recovery activates on the mismatched room surface")
	_check(_eligible_authored_ids(coach, room).is_empty(), "full catalogue has no eligible authored lesson on this boundary")
	var active_before := var_to_bytes(coach.active_lesson)
	var queue_before := var_to_bytes(coach.queued_lessons)
	var ids_before := var_to_bytes(coach.queued_ids)
	var seen_before := var_to_bytes(coach.seen)
	var room_before := var_to_bytes(room)
	var lessons_before := var_to_bytes(lessons)
	for boundary in range(3):
		coach.evaluate_at_boundary(room)
	_check(coach.active_lesson_id() == RECOVERY and var_to_bytes(coach.active_lesson) == active_before, "needed recovery remains the same unfinished instruction")
	_check(var_to_bytes(coach.queued_lessons) == queue_before and var_to_bytes(coach.queued_ids) == ids_before, "queue contents, FIFO order and queued IDs remain unchanged")
	_check(var_to_bytes(coach.seen) == seen_before and completed.is_empty(), "no eligible authored head means no seen or completion changes")
	_check(activated == [RECOVERY] and dialogue_requests.is_empty(), "unchanged recovery is not reactivated or voiced as an authored lesson")
	_check(var_to_bytes(room) == room_before and var_to_bytes(lessons) == lessons_before, "control context and full catalogue remain byte-exact")
	cases.append({"id": "needed_recovery_without_authored_head_stays", "checks": checks - first_check, "failures": failures.size() - first_failure})
	coach.queue_free()
	await process_frame

func _coach() -> Control:
	completed.clear()
	activated.clear()
	dialogue_requests.clear()
	var coach := Coach.new()
	root.add_child(coach)
	coach.set_reduce_motion(true)
	coach.set_lessons(lessons)
	var retained := {ROUTE: true, BEFORE: true}
	coach.restore_seen(retained)
	coach.begin_tutorial_run(retained)
	coach.lesson_completed.connect(func(id: String): completed.append(id))
	coach.lesson_seen.connect(func(id: String): activated.append(id))
	coach.dialogue_requested.connect(func(id: String, _dialogue: String, _node: String): dialogue_requests.append(id))
	return coach

func _has_lesson(id: String) -> bool:
	for value in lessons:
		if typeof(value) == TYPE_DICTIONARY and str(value.get("id", "")) == id:
			return true
	return false

func _eligible_authored_ids(coach: Control, context: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for value in lessons:
		if typeof(value) == TYPE_DICTIONARY and ViewModel.trigger_matches(value, context, coach.seen):
			ids.append(str(value.get("id", "")))
	return ids

func _queue_ids(coach: Control) -> Array[String]:
	var ids: Array[String] = []
	for entry in coach.queued_lessons:
		ids.append(str(entry.get("lesson", {}).get("id", "")))
	return ids

func _context(at_settled_table: bool) -> Dictionary:
	return {
		"screen": "GAME" if at_settled_table else "ENVIRONMENT",
		"environment_archetype": "small_underground_casino",
		"game_id": "blackjack" if at_settled_table else "",
		"run": {"tutorial": true, "flags": {}},
		"game": {"hands_played": 1, "hand_active": false, "between_hands": at_settled_table, "wager_raised": false},
		"viewport_rect": Rect2(0, 0, 1280, 720),
		"anchor_rects": {
			"interactable_objects": {"travel:leave": Rect2(30, 560, 100, 60)},
			"surface_actions": {
				"blackjack_deal": Rect2(40, 610, 80, 60),
				"blackjack_stand": Rect2(140, 610, 80, 60),
				"blackjack_wager_place_gesture": Rect2(240, 610, 80, 60),
			},
		},
	}

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
