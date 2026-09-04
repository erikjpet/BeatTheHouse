extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const CoachOverlayScript := preload("res://scripts/ui/coach_overlay.gd")
const CoachViewModelScript := preload("res://scripts/ui/coach_view_model.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const BlackjackScript := preload("res://scripts/games/blackjack.gd")
const BlackjackAuthorityTestDriverScript := preload("res://scripts/tests/foundation/blackjack_authority_test_driver.gd")

const TEST_META_PATH := "user://tutorial_guardrail_stress_meta.json"
const TEST_PROFILE_PATH := "user://tutorial_guardrail_stress_profile.json"
const TEST_SAVE_SLOT := "tutorial_guardrail_recovery_stress"
const REPEATS_PER_LESSON := 12
const PRODUCTION_RESTARTS := 40

var failures: Array[String] = []
var dialogue_request_count := 0
var boundary_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("BTH_META_COLLECTION_PATH", TEST_META_PATH)
	OS.set_environment("BTH_PROFILE_INVENTORY_PATH", TEST_PROFILE_PATH)
	_remove_test_file(TEST_META_PATH)
	_remove_test_file(TEST_PROFILE_PATH)
	var library := ContentLibraryScript.new()
	library.load()
	if not library.validation_errors.is_empty():
		_fail("Tutorial guardrail stress could not load clean content: %s" % JSON.stringify(library.validation_errors))
	else:
		await _exercise_every_authored_frontier(library.tutorial_lessons)
		await _exercise_generated_blackjack_peek_tables(library)
		await _exercise_heat_to_peek_transition(library)
		await _exercise_production_dialogue_recovery()
	_remove_test_file(TEST_META_PATH)
	_remove_test_file(TEST_PROFILE_PATH)
	if failures.is_empty():
		print("tutorial_guardrail_recovery_stress_check: PASS (%d irregular boundaries)" % boundary_count)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _exercise_every_authored_frontier(lessons: Array) -> void:
	var overlay := CoachOverlayScript.new()
	root.add_child(overlay)
	overlay.set_lessons(lessons)
	overlay.dialogue_requested.connect(_on_dialogue_requested)
	await process_frame
	for lesson_value in lessons:
		if typeof(lesson_value) != TYPE_DICTIONARY:
			continue
		var lesson: Dictionary = lesson_value
		if str(lesson.get("scope", "")) != "tutorial_run":
			continue
		var lesson_id := str(lesson.get("id", ""))
		var completed := _all_except(lessons, lesson_id)
		for repeat_index in range(REPEATS_PER_LESSON):
			overlay.begin_tutorial_run(completed)
			var context := _exact_context(lesson, repeat_index)
			var requests_before := dialogue_request_count
			overlay.evaluate_at_boundary(context)
			boundary_count += 1
			var active_id := overlay.active_lesson_id()
			if active_id != lesson_id:
				_fail("Exact authored frontier %s lost its guardrail on repeat %d (active=%s)." % [lesson_id, repeat_index, active_id])
				continue
			if str(lesson.get("delivery", "coach")) == "dialogue":
				if dialogue_request_count <= requests_before:
					_fail("Authored dialogue %s did not request its TalkDock entry." % lesson_id)
					continue
				var retry_before := dialogue_request_count
				if not overlay.reconcile_active_dialogue(false) or dialogue_request_count != retry_before + 1:
					_fail("Lost TalkDock entry for %s was not re-requested exactly once." % lesson_id)
				overlay.notify_dialogue_completed(lesson_id)
				var acknowledged_before := dialogue_request_count
				var acknowledged_retry := overlay.reconcile_active_dialogue(false)
				if acknowledged_retry or dialogue_request_count != acknowledged_before:
					_fail("Acknowledged TalkDock entry for %s was incorrectly repeated." % lesson_id)

		# Rebuild the same save on an unrelated room/screen. The state machine must
		# own either the lesson itself or a visible recovery step; blank is failure.
		overlay.begin_tutorial_run(completed)
		var displaced_context := _exact_context(lesson, 0)
		displaced_context["screen"] = "ENVIRONMENT"
		displaced_context["environment_archetype"] = "playtest_detour_room"
		displaced_context["game_id"] = ""
		displaced_context["anchor_rects"] = _anchor_rects_for(lesson, displaced_context)
		overlay.evaluate_at_boundary(displaced_context)
		boundary_count += 1
		var displaced_id := overlay.active_lesson_id()
		if not bool(lesson.get("optional", false)) and (displaced_id.is_empty() or (displaced_id != lesson_id and displaced_id != "tutorial_recovery:%s" % lesson_id)):
			_fail("Displaced/reloaded frontier %s had no matching recovery guardrail (active=%s)." % [lesson_id, displaced_id])

		# State-based work may be completed on the same frame that made the lesson
		# eligible. Rebuild that boundary and prove the durable outcome advances the
		# dependency graph even though the transient trigger was never displayed.
		var completion: Dictionary = lesson.get("completion", {}) if typeof(lesson.get("completion", {})) == TYPE_DICTIONARY else {}
		if str(completion.get("type", "")) == "state_predicate":
			overlay.begin_tutorial_run(completed)
			var completed_context := _exact_context(lesson, 0)
			_apply_matching_predicates(completed_context, completion.get("state_predicates", []))
			overlay.evaluate_at_boundary(completed_context)
			boundary_count += 1
			var seen: Dictionary = overlay.get("seen")
			if not bool(seen.get(lesson_id, false)):
				_fail("Pre-performed state lesson %s did not reconcile at its eligibility boundary." % lesson_id)
	overlay.queue_free()
	await process_frame


func _exercise_production_dialogue_recovery() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	var app: Control = MainScene.instantiate()
	app.set("autosave_slot_id", TEST_SAVE_SLOT)
	app.set("continuous_environment_clock_enabled", false)
	root.add_child(app)
	await _settle(8)
	var first_lesson := "tutorial_apartment_xray"
	var first_event := "tutorial_guide:%s" % first_lesson
	var run_state: RunState
	var coach
	for restart_index in range(PRODUCTION_RESTARTS):
		app.call("start_tutorial_run")
		await _settle(8)
		run_state = app.get("run_state")
		coach = app.get("coach_overlay")
		if run_state == null or coach == null or coach.call("active_lesson_id") != first_lesson or run_state.pending_talk_event(first_event).is_empty():
			_fail("Production tutorial restart %d did not establish the initial Pal guardrail." % restart_index)
			continue

		# Simulate the exact queue-loss class seen in playtesting: the coach remains
		# active while travel/cleanup removes the separate conversation entry.
		run_state.complete_talk_event_resolution(first_event)
		app.call("_refresh_coach_at_boundary")
		await _settle(3)
		boundary_count += 1
		if run_state.pending_talk_event(first_event).is_empty() or coach.call("active_lesson_id") != first_lesson:
			_fail("Production restart %d did not restore a lost Pal queue entry." % restart_index)

		# Once the player acknowledges the line, its absence is intentional and must
		# not become an annoying loop while they perform the highlighted action.
		app.call("_on_talk_dock_choice_requested", first_event, "continue")
		await _settle(3)
		app.call("_refresh_coach_at_boundary")
		await _settle(2)
		boundary_count += 1
		if not run_state.pending_talk_event(first_event).is_empty():
			_fail("Production restart %d repeated an already-acknowledged Pal line." % restart_index)
	if run_state == null or coach == null:
		app.queue_free()
		return

	# A save made after opening the map can reload with the map closed. Rebuild
	# from that persisted lesson set and require a non-modal route back into the
	# destination lesson instead of an empty coach state.
	var completed := {
		"tutorial_apartment_xray": true,
		"tutorial_inventory_xray": true,
		"tutorial_open_map_corner": true,
	}
	run_state.narrative_flags["tutorial_lessons_completed"] = completed.duplicate(true)
	coach.call("begin_tutorial_run", completed)
	app.set("current_screen", "ENVIRONMENT")
	app.call("_refresh_coach_at_boundary")
	await _settle(3)
	boundary_count += 1
	if coach.call("active_lesson_id") != "tutorial_recovery:tutorial_travel_corner":
		_fail("Closed-map reload did not expose the travel recovery guardrail (active=%s)." % coach.call("active_lesson_id"))
	app.queue_free()
	await _settle(2)


func _exercise_generated_blackjack_peek_tables(library) -> void:
	var config: Dictionary = library.challenge_config_for("tutorial_first_card", "IGNORED")
	for seed_index in range(500):
		var run_state: RunState = RunStateScript.new()
		run_state.start_new("TUTORIAL-PEEK-TABLE-%03d" % seed_index, config)
		var environment := {
			"id": "tutorial_peek_table_%03d" % seed_index,
			"archetype_id": "small_underground_casino",
			"kind": "casino",
			"game_states": {},
			"economic_profile": {"stake_floor": 1, "stake_ceiling": 25},
		}
		run_state.set_environment(environment)
		var game = BlackjackScript.new()
		game.setup(library.game("blackjack"), library)
		game.enter(run_state, run_state.current_environment)
		var before_projection := JSON.stringify(run_state.current_environment)
		var surface := game.surface_state(run_state, run_state.current_environment, {})
		var distractions: Array = surface.get("distractions", []) if typeof(surface.get("distractions", [])) == TYPE_ARRAY else []
		var ids: Array[String] = []
		for distraction_value in distractions:
			if typeof(distraction_value) == TYPE_DICTIONARY:
				ids.append(str((distraction_value as Dictionary).get("id", "")))
		boundary_count += 1
		if ids.size() < 2 or ids[0] != "drink_pass" or ids[1] != "chip_spill":
			_fail("Generated tutorial Blackjack table %d omitted the mandatory Peek setup controls: %s." % [seed_index, JSON.stringify(ids)])
			continue
		if JSON.stringify(run_state.current_environment) != before_projection:
			_fail("Generated tutorial Blackjack table %d mutated persisted state during passive projection." % seed_index)
		# Passive entry/surface reads are observational after fix06_2. Prove the
		# projected repair persists only when the player crosses a real sealed
		# action boundary, without making all 500 generation seeds pay host cost.
		if seed_index in [0, 499] and not _commit_blackjack_first_action(game, run_state):
			_fail("Generated tutorial Blackjack table %d could not persist Peek controls at its first authorized action." % seed_index)
		elif seed_index in [0, 499]:
			var stored: Dictionary = run_state.current_environment.get("game_states", {}).get("blackjack", {})
			var stored_distractions: Array = stored.get("distractions", []) if typeof(stored.get("distractions", [])) == TYPE_ARRAY else []
			if stored_distractions.size() < 2 \
					or str((stored_distractions[0] as Dictionary).get("id", "")) != "drink_pass" \
					or str((stored_distractions[1] as Dictionary).get("id", "")) != "chip_spill":
				_fail("Generated tutorial Blackjack table %d did not persist Peek controls at its first authorized action." % seed_index)

	# Reproduce the reported boundary with a legacy/stuck table whose random roll
	# omitted DRINK PASS. Reading the live table must repair the save in place.
	var legacy_run: RunState = RunStateScript.new()
	legacy_run.start_new("TUTORIAL-PEEK-LEGACY-REPAIR", config)
	var legacy_environment := {
		"id": "tutorial_peek_legacy",
		"archetype_id": "small_underground_casino",
		"kind": "casino",
		"game_states": {},
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 25},
	}
	legacy_run.set_environment(legacy_environment)
	var legacy_game = BlackjackScript.new()
	legacy_game.setup(library.game("blackjack"), library)
	legacy_game.surface_state(legacy_run, legacy_run.current_environment, {})
	var legacy_states: Dictionary = legacy_run.current_environment.get("game_states", {})
	var legacy_table: Dictionary = legacy_states.get("blackjack", {})
	legacy_table["distractions"] = [
		{"id": "payout_question", "label": "Payout Ask", "duration_msec": 3400, "cover": 6, "noise": 4},
		{"id": "pit_glance", "label": "Pit Glance", "duration_msec": 4200, "cover": 4, "noise": 10},
	]
	legacy_table.erase("tutorial_peek_distractions_repaired")
	legacy_states["blackjack"] = legacy_table
	legacy_run.current_environment["game_states"] = legacy_states
	var legacy_before_projection := JSON.stringify(legacy_run.current_environment)
	var repaired_surface := legacy_game.surface_state(legacy_run, legacy_run.current_environment, {})
	var repaired_ids: Array[String] = []
	for distraction_value in repaired_surface.get("distractions", []):
		if typeof(distraction_value) == TYPE_DICTIONARY:
			repaired_ids.append(str((distraction_value as Dictionary).get("id", "")))
	boundary_count += 1
	if repaired_ids.size() < 2 or repaired_ids[0] != "drink_pass" or repaired_ids[1] != "chip_spill":
		_fail("An already-stuck tutorial Blackjack save did not regain the Heat-to-Peek controls: %s." % JSON.stringify(repaired_ids))
	if JSON.stringify(legacy_run.current_environment) != legacy_before_projection:
		_fail("An already-stuck tutorial Blackjack save mutated during passive repair projection.")
	if not _commit_blackjack_first_action(legacy_game, legacy_run):
		_fail("The already-stuck tutorial Blackjack repair could not cross its first authorized action boundary.")
	var persisted_legacy: Dictionary = legacy_run.current_environment.get("game_states", {}).get("blackjack", {})
	if not bool(persisted_legacy.get("tutorial_peek_distractions_repaired", false)):
		_fail("The already-stuck tutorial Blackjack repair was not persisted by its first authorized action.")

	# The repair is deliberately tutorial-only. A normal underground table with
	# the same random roll must retain its original distraction selection.
	var normal_run: RunState = RunStateScript.new()
	normal_run.start_new("NORMAL-PEEK-ISOLATION", {})
	var normal_environment := {
		"id": "normal_peek_isolation",
		"archetype_id": "small_underground_casino",
		"kind": "casino",
		"game_states": {},
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 25},
	}
	normal_run.set_environment(normal_environment)
	var normal_game = BlackjackScript.new()
	normal_game.setup(library.game("blackjack"), library)
	normal_game.surface_state(normal_run, normal_run.current_environment, {})
	var normal_states: Dictionary = normal_run.current_environment.get("game_states", {})
	var normal_table: Dictionary = normal_states.get("blackjack", {})
	normal_table["distractions"] = [
		{"id": "payout_question", "label": "Payout Ask", "duration_msec": 3400, "cover": 6, "noise": 4},
		{"id": "pit_glance", "label": "Pit Glance", "duration_msec": 4200, "cover": 4, "noise": 10},
	]
	normal_states["blackjack"] = normal_table
	normal_run.current_environment["game_states"] = normal_states
	var normal_surface := normal_game.surface_state(normal_run, normal_run.current_environment, {})
	var normal_ids: Array[String] = []
	for distraction_value in normal_surface.get("distractions", []):
		if typeof(distraction_value) == TYPE_DICTIONARY:
			normal_ids.append(str((distraction_value as Dictionary).get("id", "")))
	boundary_count += 1
	if normal_ids != ["payout_question", "pit_glance"]:
		_fail("Tutorial Peek repair changed a normal Blackjack table: %s." % JSON.stringify(normal_ids))


func _commit_blackjack_first_action(game: GameModule, run_state: RunState) -> bool:
	var command := BlackjackAuthorityTestDriverScript.surface_intent(game, "blackjack_deal", 5, run_state, run_state.current_environment)
	if not bool(command.get("handled", false)) or str(command.get("action_id", "")).is_empty():
		return false
	var result := BlackjackAuthorityTestDriverScript.resolve_surface_command(game, command, 5, run_state, run_state.current_environment)
	return bool(result.get("ok", false))


func _exercise_heat_to_peek_transition(library) -> void:
	var heat_lesson: Dictionary = {}
	for lesson_value in library.tutorial_lessons:
		if typeof(lesson_value) == TYPE_DICTIONARY and str((lesson_value as Dictionary).get("id", "")) == "tutorial_blackjack_heat_precheck":
			heat_lesson = lesson_value
			break
	if heat_lesson.is_empty():
		_fail("Heat-to-Peek regression could not find tutorial_blackjack_heat_precheck.")
		return
	var completed := _completed_before(library.tutorial_lessons, "tutorial_blackjack_heat_precheck")
	for repeat_index in range(100):
		await _exercise_heat_to_peek_once(library, heat_lesson, completed, repeat_index)


func _exercise_heat_to_peek_once(library, heat_lesson: Dictionary, completed: Dictionary, repeat_index: int) -> void:
	# Build the anchor set from a real generated tutorial table. This prevents the
	# regression from silently fabricating DRINK PASS as the old stress test did.
	var config: Dictionary = library.challenge_config_for("tutorial_first_card", "IGNORED")
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("TUTORIAL-HEAT-TO-PEEK-%03d" % repeat_index, config)
	var environment := {
		"id": "tutorial_heat_to_peek_%03d" % repeat_index,
		"archetype_id": "small_underground_casino",
		"kind": "casino",
		"game_states": {},
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 25},
	}
	run_state.set_environment(environment)
	var game = BlackjackScript.new()
	game.setup(library.game("blackjack"), library)
	var surface := game.surface_state(run_state, run_state.current_environment, {})
	var surface_actions := {
		"blackjack_peek": Rect2(760, 560, 120, 56),
	}
	for distraction_value in surface.get("distractions", []):
		if typeof(distraction_value) != TYPE_DICTIONARY:
			continue
		var distraction_id := str((distraction_value as Dictionary).get("id", ""))
		surface_actions["blackjack_distraction:%s" % distraction_id] = Rect2(420, 560, 150, 56)

	var overlay := CoachOverlayScript.new()
	root.add_child(overlay)
	overlay.set_lessons(library.tutorial_lessons)
	overlay.dialogue_requested.connect(_on_dialogue_requested)
	overlay.begin_tutorial_run(completed)
	await process_frame
	var context := _exact_context(heat_lesson, repeat_index)
	context["anchor_rects"] = {
		"interactable_objects": {},
		"hud_elements": {"heat": Rect2(1040, 24, 180, 42)},
		"surface_actions": surface_actions,
	}
	var requests_before := dialogue_request_count
	overlay.evaluate_at_boundary(context)
	boundary_count += 1
	if overlay.active_lesson_id() != "tutorial_blackjack_heat_precheck" or dialogue_request_count != requests_before + 1:
		_fail("Heat-to-Peek repeat %d did not establish Pal's Heat dialogue." % repeat_index)
		overlay.queue_free()
		await process_frame
		return

	overlay.notify_dialogue_completed("tutorial_blackjack_heat_precheck")
	requests_before = dialogue_request_count
	overlay.evaluate_at_boundary(context)
	boundary_count += 1
	if overlay.active_lesson_id() != "tutorial_blackjack_lookaway" or dialogue_request_count != requests_before + 1:
		_fail("Heat-to-Peek repeat %d did not expose the real DRINK PASS Lookaway lesson." % repeat_index)
		overlay.queue_free()
		await process_frame
		return

	overlay.notify_dialogue_completed("tutorial_blackjack_lookaway")
	overlay.notify_action("blackjack_distraction")
	(context["game"] as Dictionary)["lookaway_started"] = true
	requests_before = dialogue_request_count
	overlay.evaluate_at_boundary(context)
	boundary_count += 1
	if overlay.active_lesson_id() != "tutorial_blackjack_peek" or dialogue_request_count != requests_before + 1:
		_fail("Heat-to-Peek repeat %d did not advance DRINK PASS to Peek." % repeat_index)
	overlay.queue_free()
	await process_frame


func _exact_context(lesson: Dictionary, salt: int) -> Dictionary:
	var trigger: Dictionary = lesson.get("trigger", {}) if typeof(lesson.get("trigger", {})) == TYPE_DICTIONARY else {}
	var context := {
		"screen": str(trigger.get("screen", "ENVIRONMENT")),
		"environment_kind": str(trigger.get("environment_kind", "venue")),
		"environment_archetype": str(trigger.get("environment_archetype", "")),
		"game_id": str(trigger.get("game_id", "")),
		"run": {
			"tutorial": true,
			"challenge_id": "tutorial_first_card",
			"inventory_count": 0,
			"flags": {},
		},
		"game": {
			"hands_played": 0,
			"hand_active": false,
			"between_hands": false,
			"peek_count": 0,
			"tutorial_count_completed": false,
			"count_perfect": false,
		},
		"ui": {"world_map_open": false},
		"meta": {"home": false, "starter_card_count": 0},
		"action": {"last_action_id": "stress:%d" % salt},
		"viewport_rect": Rect2(Vector2.ZERO, Vector2(1280, 720)),
	}
	_apply_matching_predicates(context, trigger.get("state_predicates", []))
	context["anchor_rects"] = _anchor_rects_for(lesson, context)
	return context


func _apply_matching_predicates(context: Dictionary, predicates: Variant) -> void:
	if typeof(predicates) != TYPE_ARRAY:
		return
	for predicate_value in predicates:
		if typeof(predicate_value) != TYPE_DICTIONARY:
			continue
		var predicate: Dictionary = predicate_value
		var expected: Variant = predicate.get("value")
		var matching_value: Variant = expected
		match str(predicate.get("op", "equals")):
			"gt":
				matching_value = float(expected) + 1.0
			"lt":
				matching_value = float(expected) - 1.0
			"not_equals":
				matching_value = not bool(expected) if typeof(expected) == TYPE_BOOL else "%s:other" % str(expected)
			"truthy":
				matching_value = true
		_set_path(context, str(predicate.get("path", "")), matching_value)


func _anchor_rects_for(lesson: Dictionary, context: Dictionary) -> Dictionary:
	var groups := {"interactable_objects": {}, "hud_elements": {}, "surface_actions": {}}
	var anchor := CoachViewModelScript.resolved_anchor(lesson, context)
	var group_name := str({
		"interactable_object": "interactable_objects",
		"hud_element": "hud_elements",
		"surface_action": "surface_actions",
	}.get(str(anchor.get("kind", "")), ""))
	var anchor_id := str(anchor.get("id", ""))
	if not group_name.is_empty() and not anchor_id.is_empty():
		groups[group_name][anchor_id] = Rect2(240, 180, 120, 64)
	groups["interactable_objects"]["travel:leave"] = Rect2(40, 540, 130, 70)
	groups["surface_actions"]["surface_back"] = Rect2(40, 540, 130, 70)
	return groups


func _all_except(lessons: Array, excluded_id: String) -> Dictionary:
	var completed := {}
	for lesson_value in lessons:
		if typeof(lesson_value) != TYPE_DICTIONARY:
			continue
		var lesson_id := str((lesson_value as Dictionary).get("id", ""))
		if not lesson_id.is_empty() and lesson_id != excluded_id:
			completed[lesson_id] = true
	return completed


func _completed_before(lessons: Array, frontier_id: String) -> Dictionary:
	var completed := {}
	for lesson_value in lessons:
		if typeof(lesson_value) != TYPE_DICTIONARY:
			continue
		var lesson_id := str((lesson_value as Dictionary).get("id", ""))
		if lesson_id == frontier_id:
			break
		if not lesson_id.is_empty():
			completed[lesson_id] = true
	return completed


func _set_path(target: Dictionary, path: String, value: Variant) -> void:
	var segments := path.split(".", false)
	if segments.is_empty():
		return
	var cursor := target
	for index in range(segments.size() - 1):
		var segment := str(segments[index])
		var child: Dictionary = cursor.get(segment, {}) if typeof(cursor.get(segment, {})) == TYPE_DICTIONARY else {}
		cursor[segment] = child
		cursor = child
	cursor[str(segments[segments.size() - 1])] = value


func _on_dialogue_requested(_lesson_id: String, _dialogue_id: String, _dialogue_node: String) -> void:
	dialogue_request_count += 1


func _remove_test_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame


func _fail(message: String) -> void:
	failures.append(message)
