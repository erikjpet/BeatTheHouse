extends SceneTree

# Presentation-only synthetic fixtures. No campaign, paid hand, SaveService,
# authority key or browser storage is read or copied by this test.
const Coach = preload("res://scripts/ui/coach_overlay.gd")
const ViewModel = preload("res://scripts/ui/coach_view_model.gd")
const CLEAN := "tutorial_blackjack_clean_deal"
const FINISH := "tutorial_blackjack_clean_finish"
const RAISE := "tutorial_blackjack_raise"
const RAISED := "tutorial_blackjack_raised_deal"
const BEFORE := "tutorial_underground_table"
const PROGRESS_FILE := "user://pal_clean_deal_synthetic_progress.json"
var checks := 0
var failures: Array[String] = []
var lessons: Array = []
var completed: Array[String] = []
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
	var all_lessons: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial/lessons.json"))
	if typeof(all_lessons) != TYPE_ARRAY:
		push_error("Authored tutorial catalogue did not load")
		quit(2)
		return
	for value in all_lessons:
		if typeof(value) == TYPE_DICTIONARY and [CLEAN, FINISH, RAISE, RAISED].has(str(value.get("id", ""))):
			lessons.append(value.duplicate(true))
	_check(lessons.size() == 4, "four actual authored Blackjack lessons loaded")
	var mode := OS.get_environment("BTH_PAL_RECOVERY_MODE")
	if mode == "cold":
		await _cold()
	elif mode == "warm":
		await _warm()
	else:
		failures.append("explicit warm or cold mode required")
	print("TUTORIAL_CLEAN_DEAL_RECOVERY ", JSON.stringify({"mode": mode, "checks": checks, "failures": failures, "scope": "Actual authored lessons and CoachOverlay; synthetic presentation context and completed-map cold restore. No official run Save/Continue or genuine-profile acceptance claim."}))
	quit(0 if failures.is_empty() else 1)

func _warm() -> void:
	var clean := _lesson(CLEAN)
	_check(ViewModel.completion_matches(clean, "blackjack_deal"), "normal Deal completion retained")
	_check(not ViewModel.completion_matches(clean, "blackjack_chip"), "unfunded chip does not complete Clean Deal")
	_check(not ViewModel.completion_matches(clean, "blackjack_stand"), "Stand does not replace Deal completion")
	_check(not ViewModel.state_completion_matches(clean, _context(0)), "zero completed hands cannot prove missed Deal")
	var active := _context(1)
	active["game"]["between_hands"] = false
	active["game"]["hand_active"] = true
	_check(not ViewModel.state_completion_matches(clean, active), "recovery waits outside an active paid hand")
	for field in ["screen", "environment_archetype", "game_id"]:
		var wrong := _context(1)
		wrong[field] = "wrong_surface"
		_check(not ViewModel.state_completion_matches(clean, wrong), "recovery rejects wrong " + field)
	var ordinary := _context(1)
	ordinary["run"]["tutorial"] = false
	_check(not ViewModel.state_completion_matches(clean, ordinary), "recovery does not apply in an ordinary run")
	var no_opt_in := clean.duplicate(true)
	no_opt_in["completion"].erase("recovery_state_predicates")
	_check(not ViewModel.state_completion_matches(no_opt_in, _context(1)), "anchored lessons without authored recovery remain unchanged")
	for bad in [null, {}, [], ["not a predicate"]]:
		var malformed := clean.duplicate(true)
		malformed["completion"]["recovery_state_predicates"] = bad
		_check(not ViewModel.state_completion_matches(malformed, _context(1)), "malformed or empty recovery proof rejects")
	var other_type := clean.duplicate(true)
	other_type["completion"]["type"] = "explicit_ok"
	_check(not ViewModel.state_completion_matches(other_type, _context(1)), "explicit acknowledgement cannot be auto-completed by recovery field")
	_check(not ViewModel.state_completion_matches(_lesson(RAISED), _context(1)), "raised Deal is not completed by an earlier hand")
	var missing_dependency := _coach({})
	missing_dependency.evaluate_at_boundary(_context(1))
	_check(not bool(missing_dependency.seen.get(CLEAN, false)), "missing prerequisite is not invented")
	_check(completed.is_empty(), "blocked dependency emits no completion")
	missing_dependency.queue_free()
	await process_frame
	var fresh := _coach({BEFORE: true})
	fresh.evaluate_at_boundary(_context(0))
	_check(fresh.active_lesson_id() == CLEAN, "fresh first-hand instruction still activates")
	_check(dialogue_requests == [CLEAN], "fresh Clean Deal requests its original voice once")
	_check(completed.is_empty(), "fresh instruction is not silently skipped")
	_check(fresh.notify_action("blackjack_deal"), "fresh Deal completes by original anchored action")
	var first_active := _context(0)
	first_active["game"]["between_hands"] = false
	first_active["game"]["hand_active"] = true
	fresh.evaluate_at_boundary(first_active)
	_check(fresh.active_lesson_id() == FINISH, "ordinary first-hand Finish instruction still follows Deal")
	_check(dialogue_requests == [CLEAN, FINISH], "normal Deal/Finish voice order unchanged")
	fresh.evaluate_at_boundary(_context(1))
	_check(fresh.active_lesson_id() == RAISE, "ordinary settled first hand reaches Raise")
	_check(completed.count(CLEAN) == 1 and completed.count(FINISH) == 1, "ordinary first-hand steps complete once")
	fresh.queue_free()
	await process_frame
	var recovery := _coach({BEFORE: true})
	var room := _context(1)
	room["screen"] = "ENVIRONMENT"
	room["game_id"] = ""
	recovery.evaluate_at_boundary(room)
	_check(recovery.active_lesson_id() == "tutorial_recovery:" + CLEAN, "genuine diagnostic's public recovery target is reproduced synthetically")
	_check(completed.is_empty(), "room recovery does not claim the missed Deal")
	var table := _context(1)
	var original_table := var_to_bytes(table)
	var original_lessons := var_to_bytes(lessons)
	recovery.evaluate_at_boundary(table)
	_check(recovery.active_lesson_id() == RAISE, "return to settled first hand reaches next eligible instruction without Deal")
	_check(completed == [CLEAN, FINISH], "only already-performed Deal and Finish catch up in dependency order")
	_check(dialogue_requests == [RAISE], "recovery requests only the next current instruction")
	_check(var_to_bytes(table) == original_table, "coach recovery leaves supplied game/run presentation context byte-exact")
	_check(var_to_bytes(lessons) == original_lessons, "authored lesson definitions remain byte-exact")
	for i in range(5):
		recovery.evaluate_at_boundary(table)
	_check(completed == [CLEAN, FINISH], "repeated refreshes do not duplicate catch-up completion")
	_check(dialogue_requests == [RAISE], "repeated refreshes do not repeat an existing dialogue request")
	var progress := {BEFORE: true, CLEAN: true, FINISH: true}
	_check(bool(recovery.seen.get(CLEAN, false)) and bool(recovery.seen.get(FINISH, false)), "catch-up progress is retained for normal persistence listener")
	_check(not bool(recovery.seen.get(RAISE, false)), "unchanged wager does not invent Raise completion")
	var file := FileAccess.open(PROGRESS_FILE, FileAccess.WRITE)
	_check(file != null, "synthetic progress handoff opens only within isolated user root")
	if file != null:
		file.store_string(JSON.stringify({"completed": progress, "context": table}))
		file.close()
	recovery.queue_free()
	await process_frame
	var already_raised := _coach({BEFORE: true})
	var raised_context := _context(1)
	raised_context["game"]["wager_raised"] = true
	already_raised.evaluate_at_boundary(raised_context)
	_check(already_raised.active_lesson_id() == RAISED, "existing unfunded raised draft reaches raised-Deal instruction")
	_check(completed == [CLEAN, FINISH, RAISE], "existing raised draft advances only its three actual achieved steps")
	_check(not bool(already_raised.seen.get(RAISED, false)), "recovery never performs or invents another Deal")
	already_raised.queue_free()
	await process_frame

func _cold() -> void:
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROGRESS_FILE))
	_check(typeof(saved) == TYPE_DICTIONARY, "fresh process reads the prior synthetic progress handoff")
	if typeof(saved) != TYPE_DICTIONARY:
		return
	var retained: Dictionary = saved.get("completed", {})
	var context: Dictionary = saved.get("context", {})
	# JSON does not carry Rect2; restore presentation geometry only, not gameplay.
	context["viewport_rect"] = Rect2(0, 0, 1280, 720)
	context["anchor_rects"] = _context(1)["anchor_rects"]
	_check(retained == {BEFORE: true, CLEAN: true, FINISH: true}, "only expected completed-map entries crossed the process boundary")
	var overlay := _coach(retained)
	overlay.evaluate_at_boundary(context)
	_check(overlay.active_lesson_id() == RAISE, "fresh coach restores pending Raise without a replayed hand")
	_check(completed.is_empty(), "restored completed lessons emit no duplicate completion")
	_check(dialogue_requests == [RAISE], "cold pending instruction requests its voice once")
	for i in range(5):
		overlay.evaluate_at_boundary(context)
	_check(completed.is_empty(), "cold repeated refresh does not replay progress")
	_check(dialogue_requests == [RAISE], "cold repeated refresh does not repeat pending dialogue")
	context["game"]["wager_raised"] = true
	overlay.evaluate_at_boundary(context)
	_check(overlay.active_lesson_id() == RAISED, "later real raised-draft projection reaches next instruction")
	_check(completed == [RAISE], "only the newly achieved Raise completes after restore")
	_check(not bool(overlay.seen.get(RAISED, false)), "cold recovery cannot fund or complete raised Deal")
	overlay.queue_free()
	await process_frame

func _coach(retained: Dictionary) -> Control:
	completed.clear()
	dialogue_requests.clear()
	var overlay := Coach.new()
	root.add_child(overlay)
	overlay.set_lessons(lessons)
	overlay.restore_seen(retained)
	overlay.begin_tutorial_run(retained)
	overlay.lesson_completed.connect(func(id: String): completed.append(id))
	overlay.dialogue_requested.connect(func(id: String, _dialogue: String, _node: String): dialogue_requests.append(id))
	return overlay

func _lesson(id: String) -> Dictionary:
	for value in lessons:
		if str(value.get("id", "")) == id:
			return value.duplicate(true)
	return {}

func _context(hands: int) -> Dictionary:
	return {
		"screen": "GAME", "environment_archetype": "small_underground_casino", "game_id": "blackjack",
		"run": {"tutorial": true, "flags": {}},
		"game": {"hands_played": hands, "hand_active": false, "between_hands": hands > 0, "wager_raised": false},
		"viewport_rect": Rect2(0, 0, 1280, 720),
		"anchor_rects": {"surface_actions": {
			"blackjack_deal": Rect2(40, 610, 80, 60),
			"blackjack_stand": Rect2(140, 610, 80, 60),
			"blackjack_wager_place_gesture": Rect2(240, 610, 80, 60),
		}},
	}

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
