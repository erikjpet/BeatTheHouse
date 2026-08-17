class_name Onboarding06Contract
extends RefCounted

const CoachOverlayScript := preload("res://scripts/ui/coach_overlay.gd")
const CoachViewModelScript := preload("res://scripts/ui/coach_view_model.gd")

const GUIDED_LESSON_IDS := [
	"tutorial_apartment_xray", "tutorial_inventory_xray", "tutorial_open_map_corner", "tutorial_travel_corner",
	"tutorial_inspect_coffee", "tutorial_inspect_pencil", "tutorial_buy_store_item", "tutorial_buy_remaining_store_item",
	"tutorial_crew_warning", "tutorial_family_phone", "tutorial_family_debt", "tutorial_parking_tip",
	"tutorial_route_map", "tutorial_route_choice", "tutorial_gas_machine", "tutorial_gas_peek",
	"tutorial_gas_peek_heat", "tutorial_gas_xray_buy", "tutorial_gas_peel", "tutorial_gas_leave_machine",
	"tutorial_gas_redeem", "tutorial_gas_map_underground", "tutorial_gas_travel_underground", "tutorial_underground_table",
	"tutorial_blackjack_clean_deal", "tutorial_blackjack_clean_finish", "tutorial_blackjack_raise", "tutorial_blackjack_raised_deal",
	"tutorial_blackjack_heat_precheck", "tutorial_blackjack_lookaway", "tutorial_blackjack_peek", "tutorial_blackjack_peek_finish",
	"tutorial_blackjack_count_start", "tutorial_blackjack_count_all", "tutorial_blackjack_count_finish", "tutorial_heat_warning",
	"tutorial_leave_blackjack", "tutorial_drink_intro", "tutorial_accept_invitation", "tutorial_pal_goodbye_map",
	"tutorial_travel_grand", "tutorial_host_entry", "tutorial_rourke_intro", "tutorial_take_comp",
	"tutorial_enter_cage", "tutorial_open_linda", "tutorial_buy_cage_chips", "tutorial_cage_shop",
	"tutorial_return_main_floor", "tutorial_enter_grand_table", "tutorial_earn_bronze", "tutorial_leave_grand_table",
	"tutorial_return_cage", "tutorial_reopen_linda", "tutorial_claim_bronze", "tutorial_meta_home_card",
]

const LESSON_IDS := [
	"tip06_tonight_changes_rooms",
	"tip06_delivery_route",
	"tip06_numbers_book",
	"tip06_crew_standing",
	"tip06_coin_pusher",
	"tip06_craps_pass_line",
	"tip06_venue_depth",
]

const DISCOVERY_BLOCKERS := [
	"past-post", "past posting", "crew fix", "the turn", "hidden layer", "lower layer", "layer 2", "layer 3",
	"traitor", "betrayal", "grievance", "bribe", "camouflage", "already won", "book closes", "news across town",
	"hidden casino", "crew back room", "numbers desk",
]


class PublicRunFixture:
	extends RefCounted

	var current_environment := {
		"archetype_id": "small_underground_casino",
		"current_layer_id": "club",
		"scenario_id": "punchline_open_mic",
	}
	var crew_jobs := {"fixture:0001": {"status": "resolved"}}
	var delivery := {"status": "active"}

	func delivery_has_active_run() -> bool:
		return true

	func delivery_snapshot() -> Dictionary:
		return delivery.duplicate(true)


class PublicHostFixture:
	extends Control

	var run_state: Variant = PublicRunFixture.new()
	var current_context_mode := "numbers"
	var pending_event_choice_popup_snapshot := {"popup_type": "numbers_surface"}


static func check(library: Variant, failures: Array) -> void:
	_check_guided_prefix(library, failures)
	_check_contextual_lesson_matrix(library, failures)
	_check_public_host_context(failures)
	_check_contextual_queue_discipline(library, failures)
	_check_normal_tip_action_handoff(library, failures)
	_check_discovery_boundary(library, failures)


static func _check_guided_prefix(library: Variant, failures: Array) -> void:
	var guided_ids: Array = []
	var found_normal := false
	for lesson_value in library.tutorial_lessons:
		if typeof(lesson_value) != TYPE_DICTIONARY:
			continue
		var lesson: Dictionary = lesson_value
		if str(lesson.get("scope", "")) == "tutorial_run":
			if found_normal:
				failures.append("0.6 onboarding was inserted into the shipped guided tutorial sequence instead of appended after it.")
			guided_ids.append(str(lesson.get("id", "")))
		else:
			found_normal = true
	if guided_ids != GUIDED_LESSON_IDS:
		failures.append("The shipped 56-lesson guided tutorial prefix or sequence changed: %s" % str(guided_ids))


static func _check_contextual_lesson_matrix(library: Variant, failures: Array) -> void:
	var matrix := [
		{
			"id": "tip06_tonight_changes_rooms",
			"encounter": _environment_context({"scenario_active": true}),
			"miss": _environment_context({"scenario_active": false}),
			"terms": ["tonight", "rumor", "map"],
		},
		{
			"id": "tip06_delivery_route",
			"encounter": _environment_context({"delivery_active": true}),
			"miss": _environment_context({"delivery_active": false}),
			"terms": ["contraband", "action", "deadline", "map", "real stops", "route"],
		},
		{
			"id": "tip06_numbers_book",
			"encounter": _environment_context({}, {"numbers_encountered": true}),
			"miss": _environment_context({}, {"numbers_encountered": false}),
			"terms": ["digits", "stake", "daily draw", "town talks", "contraband"],
		},
		{
			"id": "tip06_crew_standing",
			"encounter": _environment_context({"crew_job_resolved": true}),
			"miss": _environment_context({"crew_job_resolved": false}),
			"terms": ["jobs", "standing", "miss", "opens rooms", "path"],
		},
		{
			"id": "tip06_coin_pusher",
			"encounter": _game_context("coin_pusher"),
			"miss": _game_context("blackjack"),
			"terms": ["paid drop", "shelf", "lane", "nudges", "rock", "chirp", "stare", "lock"],
		},
		{
			"id": "tip06_craps_pass_line",
			"encounter": _game_context("craps"),
			"miss": _game_context("blackjack"),
			"terms": ["stake", "pass", "seven", "eleven", "point"],
		},
		{
			"id": "tip06_venue_depth",
			"encounter": _environment_context({"venue_depth_surface": true}),
			"miss": _environment_context({"venue_depth_surface": false}),
			"terms": ["venues", "more room", "way through"],
		},
	]
	var actual_ids: Array = []
	for lesson_value in library.tutorial_lessons:
		if typeof(lesson_value) == TYPE_DICTIONARY and str((lesson_value as Dictionary).get("scope", "")) != "tutorial_run":
			actual_ids.append(str((lesson_value as Dictionary).get("id", "")))
	if actual_ids != LESSON_IDS:
		failures.append("The public 0.6 onboarding catalog drifted: %s" % str(actual_ids))
	for case_value in matrix:
		var case: Dictionary = case_value
		var lesson: Dictionary = library.tutorial_lesson(str(case.get("id", "")))
		if lesson.is_empty():
			failures.append("Missing contextual 0.6 lesson: %s" % str(case.get("id", "")))
			continue
		var encounter := _dict(case.get("encounter", {}))
		var miss := _dict(case.get("miss", {}))
		if not CoachViewModelScript.trigger_matches(lesson, encounter, {}, true):
			failures.append("%s did not fire on its first genuine encounter." % str(case.get("id", "")))
		if CoachViewModelScript.trigger_matches(lesson, encounter, {str(case.get("id", "")): true}, true):
			failures.append("%s fired more than once after being seen." % str(case.get("id", "")))
		if CoachViewModelScript.trigger_matches(lesson, miss, {}, true):
			failures.append("%s appeared in a run that never met its system." % str(case.get("id", "")))
		if CoachViewModelScript.trigger_matches(lesson, encounter, {}, false):
			failures.append("%s ignored the normal-run coach preference." % str(case.get("id", "")))
		var tutorial_encounter := encounter.duplicate(true)
		var tutorial_run := _dict(tutorial_encounter.get("run", {})).duplicate(true)
		tutorial_run["tutorial"] = true
		tutorial_encounter["run"] = tutorial_run
		if CoachViewModelScript.trigger_matches(lesson, tutorial_encounter, {}, true):
			failures.append("%s leaked into the shipped guided tutorial." % str(case.get("id", "")))
		if not CoachViewModelScript.completion_matches(lesson, "coach:skip"):
			failures.append("%s cannot be skipped." % str(case.get("id", "")))
		var model := CoachViewModelScript.build(lesson, encounter)
		if not bool(model.get("dismissible", false)) or bool(model.get("gating", true)):
			failures.append("%s became modal or non-dismissible." % str(case.get("id", "")))
		var copy := str(lesson.get("copy", "")).to_lower()
		for term_value in case.get("terms", []):
			var term := str(term_value)
			if not copy.contains(term):
				failures.append("%s lost required public teaching term '%s'." % [str(case.get("id", "")), term])


static func _check_public_host_context(failures: Array) -> void:
	var host := PublicHostFixture.new()
	var overlay := CoachOverlayScript.new()
	host.add_child(overlay)
	var context: Dictionary = overlay.call("_with_public_system_context", _environment_context())
	var run_context := _dict(context.get("run", {}))
	var ui_context := _dict(context.get("ui", {}))
	for key in ["scenario_active", "delivery_active", "crew_job_resolved", "venue_depth_surface"]:
		if not bool(run_context.get(key, false)):
			failures.append("Coach public-context seam did not expose landed encounter '%s'." % key)
	if not bool(ui_context.get("numbers_encountered", false)):
		failures.append("Coach public-context seam did not recognize the focused Numbers surface.")
	host.free()


static func _check_contextual_queue_discipline(library: Variant, failures: Array) -> void:
	var host := PublicHostFixture.new()
	var overlay := CoachOverlayScript.new()
	host.add_child(overlay)
	var scenario_lesson: Dictionary = library.tutorial_lesson("tip06_tonight_changes_rooms")
	var depth_lesson: Dictionary = library.tutorial_lesson("tip06_venue_depth")
	overlay.set_lessons([scenario_lesson, depth_lesson])
	overlay.restore_seen({})
	overlay.evaluate_at_boundary(_environment_context())
	var first_snapshot: Dictionary = overlay.current_snapshot()
	if str(first_snapshot.get("lesson_id", "")) != "tip06_tonight_changes_rooms" \
			or int(first_snapshot.get("queued_count", -1)) != 0:
		failures.append("A simultaneous scenario/Punchline encounter queued a normal-run advice wall: %s" % JSON.stringify(first_snapshot))
	if not overlay.notify_action("coach:skip"):
		failures.append("The first simultaneous contextual tip could not be dismissed normally.")
	# Leaving the surface before another boundary must not display the deferred
	# Punchline tip out of context.
	host.run_state.current_environment = {"archetype_id": "bar"}
	host.current_context_mode = "room"
	host.pending_event_choice_popup_snapshot = {}
	overlay.evaluate_at_boundary(_environment_context())
	var stale_surface_snapshot: Dictionary = overlay.current_snapshot()
	if bool(stale_surface_snapshot.get("visible", false)) or not str(stale_surface_snapshot.get("lesson_id", "")).is_empty():
		failures.append("Deferred contextual advice followed the player off its genuine encounter: %s" % JSON.stringify(stale_surface_snapshot))
	# Returning later is a new genuine encounter and may teach the deferred tip.
	host.run_state.current_environment = {
		"archetype_id": "small_underground_casino",
		"current_layer_id": "club",
	}
	overlay.evaluate_at_boundary(_environment_context())
	var deferred_snapshot: Dictionary = overlay.current_snapshot()
	if str(deferred_snapshot.get("lesson_id", "")) != "tip06_venue_depth" \
			or int(deferred_snapshot.get("queued_count", -1)) != 0:
		failures.append("A deferred contextual tip did not wait for its next genuine encounter: %s" % JSON.stringify(deferred_snapshot))
	# Exercise the defensive display-time check directly: a legacy/staged queue
	# entry whose trigger no longer matches is dropped without becoming seen.
	overlay.restore_seen({})
	overlay.set_lessons([depth_lesson])
	host.run_state.current_environment = {"archetype_id": "bar"}
	overlay.queued_lessons.append({"lesson": depth_lesson.duplicate(true), "context": _environment_context({"venue_depth_surface": true})})
	overlay.queued_ids["tip06_venue_depth"] = true
	overlay.evaluate_at_boundary(_environment_context())
	var revalidated_snapshot: Dictionary = overlay.current_snapshot()
	if bool(revalidated_snapshot.get("visible", false)) \
			or int(revalidated_snapshot.get("queued_count", -1)) != 0 \
			or bool(overlay.seen.get("tip06_venue_depth", false)):
		failures.append("A stale contextual queue entry displayed or became seen after its trigger disappeared: %s" % JSON.stringify(revalidated_snapshot))
	host.free()


static func _check_normal_tip_action_handoff(library: Variant, failures: Array) -> void:
	var host := PublicHostFixture.new()
	host.current_context_mode = "room"
	host.pending_event_choice_popup_snapshot = {}
	var overlay := CoachOverlayScript.new()
	host.add_child(overlay)
	var delivery_lesson: Dictionary = library.tutorial_lesson("tip06_delivery_route")
	var scenario_lesson: Dictionary = library.tutorial_lesson("tip06_tonight_changes_rooms")
	var numbers_lesson: Dictionary = library.tutorial_lesson("tip06_numbers_book")
	overlay.set_lessons([delivery_lesson])
	overlay.restore_seen({})
	overlay.evaluate_at_boundary(_environment_context())
	if overlay.active_lesson_id() != "tip06_delivery_route":
		failures.append("Normal-tip handoff fixture did not begin with active delivery advice.")
	if not _normal_tip_pointer_blockers(overlay).is_empty():
		failures.append("Normal-run advice was not pointer-transparent over real room and surface controls.")
	# Production activation reports the object to the input guard before focus
	# updates the public context. The guard may dismiss existing advice, but it
	# must not select and mark an intermediate room tip in that same physical
	# activation.
	overlay.set_lessons([delivery_lesson, scenario_lesson, numbers_lesson])
	var guard_consumed := overlay.notify_action("numbers:book")
	if guard_consumed \
			or not overlay.active_lesson_id().is_empty() \
			or bool(overlay.seen.get("tip06_tonight_changes_rooms", false)) \
			or bool(overlay.seen.get("tip06_numbers_book", false)):
		failures.append("The activation guard selected or marked unseen contextual advice before the real focus boundary.")
	host.current_context_mode = "numbers"
	host.pending_event_choice_popup_snapshot = {"popup_type": "numbers_surface"}
	var focus_consumed := overlay.notify_action("focus:numbers:book")
	if focus_consumed \
			or overlay.active_lesson_id() != "tip06_tonight_changes_rooms" \
			or not bool(overlay.seen.get("tip06_tonight_changes_rooms", false)) \
			or bool(overlay.seen.get("tip06_numbers_book", false)):
		failures.append("The genuine focus boundary did not admit exactly one visible contextual tip in catalog order.")
	if not _normal_tip_pointer_blockers(overlay).is_empty():
		failures.append("Replacement normal-run advice stopped being pointer-transparent after the genuine focus boundary.")
	var first_surface_action_consumed := overlay.notify_action("numbers:digit")
	if first_surface_action_consumed \
			or not overlay.active_lesson_id().is_empty() \
			or bool(overlay.seen.get("tip06_numbers_book", false)):
		failures.append("The first Numbers control silently admitted replacement advice in the notification that dismissed the visible tip.")
	overlay.evaluate_at_boundary(_environment_context())
	if overlay.active_lesson_id() != "tip06_numbers_book" or not bool(overlay.seen.get("tip06_numbers_book", false)):
		failures.append("A later genuine refresh boundary did not admit the deferred Numbers advice.")
	var slip_consumed := overlay.notify_action("numbers:write_slip")
	if slip_consumed or not overlay.active_lesson_id().is_empty():
		failures.append("Normal Numbers advice consumed or remained over the ordinary slip action instead of yielding non-modally.")
	host.free()


static func _normal_tip_pointer_blockers(node: Node) -> Array:
	var blockers: Array = []
	if node == null:
		return ["missing_panel"]
	if node is Control and (node as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		blockers.append((node as Control).name)
	for child in node.get_children():
		blockers.append_array(_normal_tip_pointer_blockers(child))
	return blockers


static func _check_discovery_boundary(library: Variant, failures: Array) -> void:
	for lesson_id in LESSON_IDS:
		var lesson: Dictionary = library.tutorial_lesson(str(lesson_id))
		var searchable := JSON.stringify(lesson).to_lower()
		for blocker in DISCOVERY_BLOCKERS:
			if searchable.contains(str(blocker)):
				failures.append("Discovery-gated phrase '%s' leaked into %s." % [str(blocker), str(lesson_id)])


static func _environment_context(run_values: Dictionary = {}, ui_values: Dictionary = {}) -> Dictionary:
	var run_context := {"tutorial": false}
	for key in run_values.keys():
		run_context[key] = run_values.get(key)
	return {"screen": "ENVIRONMENT", "run": run_context, "ui": ui_values.duplicate(true)}


static func _game_context(game_id: String) -> Dictionary:
	return {"screen": "GAME", "game_id": game_id, "run": {"tutorial": false}, "ui": {}}


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary) if typeof(value) == TYPE_DICTIONARY else {}
