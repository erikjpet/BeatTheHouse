extends SceneTree

const Dock := preload("res://scripts/ui/talk_dock.gd")
const Event := preload("res://scripts/core/event_module.gd")
const TERMS := "Mags at the Corner Store: Day 2, 14:00-16:00. Missing the window loses the package and payment, reduces Crew trust by 5 and adds 9 Heat."
const OFFER_TERMS := TERMS + "\nOn delivery: Bankroll +22, heat +4"

class PreviewRun extends RunState:
	func delivery_crew_offer(_definition_id: String, _offered_clock: int = -1) -> Dictionary:
		return {"ok": true, "message": "Mags at the Corner Store: Day 2, 14:00-16:00."}
	func delivery_has_active_run() -> bool:
		return false
	func crew_package_scene_allows_offer(_environment: Dictionary = {}) -> bool:
		return true

var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}
var signals_seen: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var mode := OS.get_environment("BTH_PACKAGE_TERMS_CASE")
	if mode == "model":
		_model()
	elif mode == "desktop":
		await _display(Vector2i(1280, 720), false)
	elif mode == "mobile":
		await _display(Vector2i(390, 844), true)
		await _display(Vector2i(844, 390), true)
		await _four_choices(Vector2i(844, 390))
		await _four_choices(Vector2i(390, 844))
	elif mode == "generic":
		await _generic(Vector2i(1280, 720), false)
		await _generic(Vector2i(390, 844), true)
	elif mode == "rollback":
		await _rollback()
	elif mode == "touch":
		await _touch()
	else:
		_check(false, "explicit model/desktop/mobile/generic/rollback/touch mode required")
	var result := {"id": "CREW-PACKAGE-TERMS-001", "task_id": "BTH-30", "mode": mode, "checks": checks, "failures": failures, "facts": facts,
		"fidelity": "Synthetic preview producer and actual TalkDock controls; rollback mode calls detached Main UI lifecycle without _ready or a campaign. No preserved R02 state, package acceptance, delivery, payment, time advancement or existing profile/key access. Programmatic scroll/button signals are native widget tests, not browser touch or original-offer acceptance."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("CREW_PACKAGE_TERMS mode=%s checks=%d failures=%d" % [mode, checks, failures.size()])
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _model() -> void:
	var run := PreviewRun.new()
	run.start_new("BTH-30-SYNTHETIC-PREVIEW")
	var event := Event.new()
	event.setup({"id": "crew_favor_delivery"})
	var before := var_to_bytes(run.to_dict())
	for choice_id in ["run_package", "run_package_after_miss"]:
		var original := {"id": choice_id, "label": "Run the package", "text": "Authored result", "consequence_summary": "Bankroll +22, heat +4", "consequences": {"bankroll_delta": 22, "suspicion_delta": 4}}
		var projected := event._contextualized_choice(original.duplicate(true), run, {})
		_check(projected.get("package_offer_terms") == OFFER_TERMS, "ordinary/replacement preview preserves route/window/miss terms and identifies existing delivery consequences")
		_check(projected.text == TERMS, "existing outcome text is unchanged by display metadata")
		_check(projected.consequences == original.consequences and projected.consequence_summary == original.consequence_summary, "cash/Heat instructions and summary unchanged")
		_check(int(projected.crew_offer_clock) == run.game_clock_minutes, "existing offered clock unchanged")
	var generic := {"id": "refuse", "label": "Refuse", "text": "Post-action response", "consequences": {"suspicion_delta": 9}}
	_check(event._contextualized_choice(generic.duplicate(true), run, {}) == generic, "generic choice never gains a pre-acceptance terms surface")
	var timed := [{"id": "take_package", "label": "Quiet Package", "text": "Authored lead\nOriginal follow-up", "consequences": {"event_hooks": [{"type": "crew_job_accept", "definition_id": "rook_quiet_package"}]}}]
	var timed_before := var_to_bytes(timed)
	var timed_views := event._crew_timed_choices(timed, run)
	_check(timed_views.size() == 1, "existing eligible timed package still present exactly once")
	if timed_views.size() == 1:
		_check(timed_views[0].package_offer_terms == timed_views[0].text, "other timed-package producer exposes existing full preview only")
		_check(str(timed_views[0].package_offer_terms).contains("Corner Store") and str(timed_views[0].package_offer_terms).contains("Missing a drop"), "other package route and existing miss terms included")
	_check(var_to_bytes(timed) == timed_before, "timed-choice input rows and hooks untouched")
	_check(var_to_bytes(run.to_dict()) == before, "all serialized finance/jobs/history/RNG unchanged by preview rendering")
	facts["model_kind"] = "Real EventModule contextualization with a deterministic synthetic PreviewRun route, no job creation or obligation resolution."


func _display(viewport_size: Vector2i, small: bool) -> void:
	root.content_scale_size = viewport_size
	root.size = viewport_size
	var dock := Dock.new()
	root.add_child(dock)
	dock.set_reduce_motion(true)
	dock.set_small_screen_mode(small)
	dock.size = Vector2(viewport_size)
	var entry := {"event_id": "crew_favor_delivery", "speaker": {"name": "Velvet", "role": "lender"}}
	var option := {"display_name": "Crew Package", "summary": "Velvet: The Crew needs a quiet favour.", "choices": [
		{"id": "run_package", "label": "Run the package", "text": TERMS, "package_offer_terms": OFFER_TERMS, "requires_confirm": true, "enabled": true},
		{"id": "refuse", "label": "Refuse", "text": "Post-action response", "enabled": true},
	]}
	var entry_before := var_to_bytes(entry)
	var option_before := var_to_bytes(option)
	signals_seen.clear()
	dock.choice_requested.connect(func(event_id, choice_id): signals_seen.append([event_id, choice_id]))
	dock.set_entry(entry, option, 1)
	await _settle()
	_check(dock.package_terms_scroll.is_visible_in_tree(), "%s initial terms visible before any arm/confirm" % viewport_size)
	_check(dock.package_terms_label.text.contains(OFFER_TERMS) and dock.package_terms_label.text.contains(option.summary), "full route, window, penalties, delivery consequences and original summary readable")
	_check(dock.package_terms_label.max_lines_visible == -1 and not dock.package_terms_label.clip_text, "terms never truncated by original four-line cap")
	_check(dock.package_terms_scroll.clip_contents and dock.package_terms_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "terms scroll vertically without drawing over controls")
	_check(not dock.body_label.visible, "package summary is in full terms pane without duplicated hidden four-line body")
	_check(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(dock.panel.get_global_rect()), "%s full package panel inside viewport" % viewport_size)
	_check(dock.panel.get_global_rect().encloses(dock.package_terms_scroll.get_global_rect()), "terms viewport inside actual panel")
	var button := _button(dock, "run_package")
	_check(button != null, "ordinary accepting choice remains connected")
	if button != null:
		dock.package_terms_scroll.ensure_control_visible(button)
		await _settle()
		var initial_rect := button.get_global_rect()
		_check(dock.panel.get_global_rect().encloses(initial_rect), "accept button fully inside actual panel")
		_check(dock.package_terms_scroll.get_global_rect().encloses(initial_rect), "scrolling makes complete accept control accessible")
		_check(not small or button.size.y >= 52.0, "small-screen accepting target retains minimum touch height")
		button.pressed.emit()
		await _settle()
		_check(dock.armed_choice_id == "run_package" and signals_seen.is_empty(), "first connected click arms only, no acceptance signal")
		button = _button(dock, "run_package")
		_check(button.text.begins_with("Confirm:"), "ordinary confirmation wording retained")
		_check(button.get_global_rect().is_equal_approx(initial_rect), "arming never shifts confirmation hit rectangle")
		_check(dock.package_terms_label.text.contains(TERMS), "all package terms remain present at confirmation")
		button.pressed.emit()
		_check(signals_seen == [["crew_favor_delivery", "run_package"]], "two connected clicks emit one ordinary acceptance request")
	_check(var_to_bytes(entry) == entry_before and var_to_bytes(option) == option_before, "display and confirmation never mutate supplied semantic rows")
	var long_option := option.duplicate(true)
	long_option.choices[0].package_offer_terms = ("Additional recipient at the station: Day 2, 14:00-16:00. ").repeat(18) + "FINAL MISS TERM: trust -5, Heat +9."
	dock.set_entry(entry, long_option, 1)
	await _settle()
	var scrollbar := dock.package_terms_scroll.get_v_scroll_bar()
	_check(scrollbar.max_value > scrollbar.page, "long terms have an actual scroll range")
	dock.package_terms_scroll.scroll_vertical = maxi(0, ceili(dock.package_terms_label.position.y + dock.package_terms_label.size.y - dock.package_terms_scroll.size.y))
	await _settle()
	_check(dock.package_terms_label.text.ends_with("FINAL MISS TERM: trust -5, Heat +9."), "last supplied penalty text retained")
	var final_line_y := dock.package_terms_label.get_global_rect().end.y
	_check(final_line_y <= dock.package_terms_scroll.get_global_rect().end.y + 2.0 and final_line_y >= dock.package_terms_scroll.get_global_rect().position.y + 10.0, "scrolling exposes final terms line inside readable viewport")
	dock.package_terms_scroll.ensure_control_visible(_button(dock, "run_package"))
	await _settle()
	_check(dock.package_terms_scroll.get_global_rect().encloses(_button(dock, "run_package").get_global_rect()) and not _button(dock, "run_package").disabled, "scrolling preserves accessible live confirmation controls")
	var actual_scroll := dock.package_terms_scroll.scroll_vertical
	dock.set_entry(entry, long_option, 1)
	await _settle()
	_check(dock.package_terms_scroll.scroll_vertical == actual_scroll, "unchanged refresh does not reset reading position")
	signals_seen.clear()
	dock.collapse_button.pressed.emit()
	_check(signals_seen == [["crew_favor_delivery", Dock.NEUTRAL_CLOSE_CHOICE_ID]], "neutral Close still emits only its existing no-effect dismissal")
	# Existing Main rollback rebuilds choices after restoring option data. Terms
	# must follow that same source instead of retaining the failed option text.
	dock.option = {"summary": "Restored ordinary dialogue", "choices": [{"id": "leave", "label": "Leave"}]}
	dock._render_choices()
	_check(not dock.package_terms_scroll.visible and dock.package_terms_label.text.is_empty(), "choice rebuild removes terms absent from restored option")
	_check(dock.body_label.visible and dock.body_label.text == "Restored ordinary dialogue", "package-to-generic rebuild restores the current ordinary body")
	dock.option = option.duplicate(true)
	dock._render_choices()
	_check(dock.package_terms_label.text.contains(OFFER_TERMS), "choice rebuild derives terms from restored authoritative presentation option")
	_check(not dock.body_label.visible and not dock.typewriter_active, "generic-to-package rebuild hides duplicate body and completes hidden reveal")
	facts[str(viewport_size)] = {"panel": str(dock.panel.get_global_rect()), "terms_viewport": str(dock.package_terms_scroll.get_global_rect()), "scroll_range": scrollbar.max_value - scrollbar.page, "scroll_bottom": actual_scroll}
	dock.clear_entry()
	_check(not dock.package_terms_scroll.visible and dock.package_terms_label.text.is_empty(), "clearing entry removes prior terms")
	dock.queue_free()
	await process_frame


func _four_choices(viewport_size: Vector2i) -> void:
	root.content_scale_size = viewport_size
	root.size = viewport_size
	var dock := Dock.new()
	root.add_child(dock)
	dock.set_reduce_motion(true)
	dock.set_small_screen_mode(true)
	dock.size = Vector2(viewport_size)
	var choices: Array = []
	for index in range(4):
		choices.append({"id": "choice_%d" % index, "label": "A longer package response with the existing full authored label %d" % index,
			"enabled": index % 2 == 0, "disabled_reason": "This recipient is unavailable for the existing reason; do not change the offer.",
			"requires_confirm": true})
	choices[0]["package_offer_terms"] = OFFER_TERMS
	var option := {"display_name": "Crew Package", "summary": "An existing four-response offer.", "choices": choices}
	var option_before := var_to_bytes(option)
	dock.set_entry({"event_id": "synthetic_four_choices", "speaker": {"name": "Velvet"}}, option, 1)
	await _settle()
	_check(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(dock.panel.get_global_rect()), "four long responses keep panel inside %s" % viewport_size)
	_check(dock.package_terms_scroll.size.y >= 52.0, "four long responses never reduce terms viewport to a1px strip")
	_check(dock.package_terms_label.text.contains(OFFER_TERMS), "four-choice offer retains all destination/window/miss terms")
	_check(dock.package_terms_scroll.get_v_scroll_bar().max_value > dock.package_terms_scroll.get_v_scroll_bar().page, "long terms/responses have a real scroll range")
	for index in range(4):
		var button := _button(dock, "choice_%d" % index)
		_check(button != null, "all four original response controls remain present")
		if button == null:
			continue
		dock.package_terms_scroll.ensure_control_visible(button)
		await _settle()
		_check(dock.package_terms_scroll.get_global_rect().encloses(button.get_global_rect()), "each long response can be fully exposed without covering another control")
		_check(button.size.y >= 52.0 and not button.clip_text, "long response retains touch target and full wrapped label")
		_check(button.disabled == (index % 2 != 0), "original response eligibility is preserved")
		if index % 2 != 0:
			_check(button.text.contains(str(choices[index].disabled_reason)), "full existing disabled reason is readable in its response")
	_check(dock.panel.get_global_rect().encloses(dock.collapse_button.get_global_rect()) and not dock.package_terms_scroll.get_global_rect().intersects(dock.collapse_button.get_global_rect()), "neutral Close stays fixed and accessible outside scroll")
	_check(var_to_bytes(option) == option_before, "four-choice layout never changes offer or eligibility bytes")
	dock.queue_free()
	await process_frame


func _generic(viewport_size: Vector2i, small: bool) -> void:
	root.content_scale_size = viewport_size
	root.size = viewport_size
	var dock := Dock.new()
	root.add_child(dock)
	dock.set_small_screen_mode(small)
	dock.size = Vector2(viewport_size)
	var entry := {"event_id": "generic_event", "speaker": {"name": "Neighbour"}}
	var option := {"summary": "An ordinary authored summary.", "choices": [
		{"id": "answer", "label": "Answer", "text": "POST_ACTION_ONLY_DO_NOT_EXPOSE", "requires_confirm": true},
		{"id": "disabled", "label": "Unavailable", "text": "Hidden result", "enabled": false, "disabled_reason": "Existing eligibility reason"},
	]}
	var before := var_to_bytes(option)
	signals_seen.clear()
	dock.choice_requested.connect(func(event_id, choice_id): signals_seen.append([event_id, choice_id]))
	dock.set_entry(entry, option, 1)
	var typewriter_started := dock.typewriter_active
	await _settle()
	_check(not dock.package_terms_scroll.visible and dock.body_label.visible, "generic dialogue retains original body surface")
	_check(_button(dock, "answer").action_mode == BaseButton.ACTION_MODE_BUTTON_PRESS, "generic response keeps its existing press-mode input contract")
	_check(dock.full_body_text == option.summary and typewriter_started, "generic authored summary and initial typewriter preserved")
	_check(not dock.package_terms_label.text.contains("POST_ACTION"), "generic outcome text never leaks before choice")
	_check(dock.body_label.max_lines_visible == (10 if small else 4), "generic existing desktop/compact line contract unchanged")
	_check(is_equal_approx(dock._choice_layout_panel_width(2), 176.0 if small else 400.0), "generic existing desktop/compact panel width unchanged")
	_check(_button(dock, "disabled").disabled and _button(dock, "disabled").text.contains("Existing eligibility reason"), "generic disabled state/reason unchanged")
	_button(dock, "disabled").pressed.emit()
	_check(signals_seen.is_empty(), "disabled connected choice cannot emit acceptance")
	_button(dock, "answer").pressed.emit()
	await _settle()
	_check(dock.armed_choice_id == "answer" and signals_seen.is_empty(), "generic first-click confirmation still arms only")
	_button(dock, "answer").pressed.emit()
	_check(signals_seen == [["generic_event", "answer"]], "generic confirm emits original event/choice identity")
	for malformed in [{"hidden": "text"}, true, 9, ""]:
		var bad_option := option.duplicate(true)
		bad_option.choices[0].package_offer_terms = malformed
		dock.set_entry(entry, bad_option, 1)
		await _settle()
		_check(not dock.package_terms_scroll.visible, "malformed/empty terms metadata cannot open a terms pane")
	_check(var_to_bytes(option) == before, "generic input row bytes unchanged")
	dock.queue_free()
	await process_frame


func _rollback() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var dock := Dock.new()
	root.add_child(dock)
	dock.size = Vector2(1280, 720)
	# Detached Main: exercise its actual UI snapshot/restore functions without
	# running _ready, opening a profile, creating a campaign or starting clocks.
	var host_script: Script = load("res://scripts/ui/foundation_main.gd")
	var host: Control = host_script.new()
	host.set("talk_dock", dock)
	_check(host.get("run_state") == null, "real Main rollback probe has no campaign or saved profile")
	signals_seen.clear()
	dock.choice_requested.connect(func(event_id, choice_id): signals_seen.append([event_id, choice_id]))
	var generic_entry := {"event_id": "generic_original", "speaker": {"name": "Neighbour"}}
	var generic_option := {"summary": "An unfinished ordinary response. ".repeat(30), "choices": [{"id": "answer", "label": "Answer"}]}
	# Baseline TalkDock projects summary.strip_edges(); preserve the raw input
	# bytes separately and compare visible text with that exact old projection.
	var expected_generic_body := str(generic_option.summary).strip_edges()
	var package_entry := {"event_id": "crew_favor_delivery", "speaker": {"name": "Velvet"}}
	var package_option := {"summary": "The supplied package offer.", "choices": [{"id": "run_package", "label": "Run the package", "requires_confirm": true,
		"package_offer_terms": TERMS.repeat(12)}]}
	dock.set_entry(generic_entry, generic_option, 1)
	await _settle()
	var generic_snapshot: Dictionary = host.call("_talk_dock_lifecycle_snapshot")
	_check(generic_snapshot.body_text == expected_generic_body, "generic snapshot matches the existing trimmed display projection")
	dock.set_entry(package_entry, package_option, 1)
	await _settle()
	host.call("_restore_talk_dock_lifecycle_snapshot", generic_snapshot)
	_check(dock.body_label.visible and not dock.package_terms_scroll.visible, "actual package-to-generic rollback restores only ordinary body visibility")
	_check(dock.body_label.text == generic_snapshot.body_text and dock.full_body_text == generic_snapshot.full_body_text, "actual rollback restores current generic body text")
	_check(dock.body_label.visible_characters == generic_snapshot.body_visible_characters, "actual rollback restores exact generic revealed character count")
	_check(dock.typewriter_active == generic_snapshot.typewriter_active and dock.reveal_elapsed == generic_snapshot.reveal_elapsed and dock.is_processing() == generic_snapshot.processing, "actual rollback preserves generic typewriter progress/processing")
	_check(var_to_bytes(dock.option) == var_to_bytes(generic_snapshot.option) and var_to_bytes(dock.entry) == var_to_bytes(generic_snapshot.entry), "actual rollback preserves original generic semantic input bytes")
	await _settle()
	_check(dock.body_label.visible and not dock.package_terms_scroll.visible and dock.body_label.text == expected_generic_body, "generic body stays current after deferred container rebuild")
	dock.set_entry(package_entry, package_option, 1)
	await _settle()
	dock.package_terms_scroll.scroll_vertical = int(dock.package_terms_scroll.get_v_scroll_bar().max_value)
	await _settle()
	var package_snapshot: Dictionary = host.call("_talk_dock_lifecycle_snapshot")
	_check(dock.package_terms_scroll.size.y > 0.0, "original package viewport has usable height before rollback")
	dock.set_entry(generic_entry, generic_option, 1)
	await _settle()
	host.call("_restore_talk_dock_lifecycle_snapshot", package_snapshot)
	_check(not dock.body_label.visible and dock.package_terms_scroll.visible, "actual generic-to-package rollback hides duplicate body")
	_check(dock.package_terms_label.text == package_snapshot.package_terms_text, "actual rollback restores full package terms")
	_check(dock.package_terms_scroll.custom_minimum_size == package_snapshot.package_terms_scroll_control.custom_minimum_size, "actual rollback restores package viewport height budget")
	_check(dock.package_terms_scroll.scroll_vertical == int(package_snapshot.package_terms_scroll_value), "actual rollback restores existing package reading position")
	_check(not dock.typewriter_active and dock.body_label.visible_characters == -1 and dock.full_body_text == package_snapshot.full_body_text, "actual rollback preserves completed hidden package summary")
	_check(var_to_bytes(dock.option) == var_to_bytes(package_snapshot.option) and var_to_bytes(dock.entry) == var_to_bytes(package_snapshot.entry), "actual rollback preserves original package semantic input bytes")
	await _settle()
	_check(dock.package_terms_scroll.size.y > 0.0 and dock.package_terms_scroll.scroll_vertical == int(package_snapshot.package_terms_scroll_value), "package viewport and reading position survive deferred layout")
	_check(signals_seen.is_empty(), "presentation restore emits no choice, acceptance or dismissal")
	_check(host.get("run_state") == null, "real Main rollback probe still has no campaign or transaction")
	# Cover direct helper rebuilds separately from Main's complete restoration.
	dock.option = generic_option.duplicate(true)
	dock._render_choices()
	_check(dock.body_label.visible and dock.body_label.text == expected_generic_body and not dock.package_terms_scroll.visible, "direct helper switches to current generic body")
	var generic_progress := [dock.reveal_elapsed, dock.body_label.visible_characters, dock.typewriter_active]
	dock._render_choices()
	_check([dock.reveal_elapsed, dock.body_label.visible_characters, dock.typewriter_active] == generic_progress, "unchanged helper rebuild does not restart generic typewriter")
	dock.option = package_option.duplicate(true)
	dock._render_choices()
	_check(not dock.body_label.visible and dock.package_terms_scroll.visible and not dock.typewriter_active, "direct helper switches back without duplicated generic body")
	facts["rollback_scope"] = "Actual detached Main UI lifecycle, both directions plus direct helper. No _ready/run/profile/Save or gameplay action."
	host.set("talk_dock", null)
	host.free()
	dock.queue_free()
	await process_frame


func _touch() -> void:
	root.content_scale_size = Vector2i(390, 844)
	root.size = Vector2i(390, 844)
	var previous_mouse_emulation := Input.emulate_mouse_from_touch
	var previous_touch_emulation := Input.emulate_touch_from_mouse
	var previous_accumulation := Input.use_accumulated_input
	Input.emulate_mouse_from_touch = true
	Input.emulate_touch_from_mouse = true
	Input.use_accumulated_input = false
	facts["touchscreen_available"] = DisplayServer.is_touchscreen_available()
	_check(DisplayServer.is_touchscreen_available(), "test-only touchscreen emulation enables the real ScrollContainer drag path")
	# Controlled old-property comparator on the same real TalkDock widget.
	# Only this synthetic button is switched to PRESS; no game listener exists.
	var baseline := _touch_offer()
	await _settle()
	var baseline_button := await _touch_button(baseline)
	_check(baseline_button.action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE and baseline_button.mouse_filter == Control.MOUSE_FILTER_PASS, "package source uses release activation and lets scroll receive the gesture")
	var point := baseline_button.get_global_rect().get_center()
	await _screen_touch(point, true)
	_check(baseline.armed_choice_id.is_empty() and signals_seen.is_empty(), "first touch down cannot arm or accept a package")
	await _screen_touch(point, false)
	_check(baseline.armed_choice_id == "run_package" and signals_seen.is_empty(), "first completed touch tap arms without accepting")
	baseline_button = await _touch_button(baseline)
	baseline_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	point = baseline_button.get_global_rect().get_center()
	await _screen_touch(point, true)
	_check(signals_seen == [["synthetic_touch_package", "run_package"]], "old PRESS property reproduces early armed acceptance signal on touchdown")
	await _screen_touch(point, false)
	_check(signals_seen.size() == 1, "controlled PRESS comparator records exactly its one early UI signal")
	baseline.queue_free()
	await process_frame
	var dock := _touch_offer()
	await _settle()
	var button := await _touch_button(dock)
	_check(button.action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE, "fresh actual TalkDock uses safe source action mode")
	point = button.get_global_rect().get_center()
	await _screen_touch(point, true)
	_check(dock.armed_choice_id.is_empty() and signals_seen.is_empty(), "fresh normal tap waits for release")
	await _screen_touch(point, false)
	_check(dock.armed_choice_id == "run_package" and signals_seen.is_empty(), "fresh first tap arms once on release")
	button = await _touch_button(dock)
	point = button.get_global_rect().get_center()
	var scroll_before := dock.package_terms_scroll.scroll_vertical
	await _screen_touch(point, true)
	_check(signals_seen.is_empty(), "armed Confirm emits no request on touchdown")
	var drag_step := Vector2(0, maxf(60.0, float(dock.package_terms_scroll.scroll_deadzone) + 24.0) / 6.0)
	var scroll_values: Array = []
	for step in range(1, 7):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = point + drag_step * step
		drag.relative = drag_step
		drag.velocity = drag_step * 60.0
		Input.parse_input_event(drag)
		await process_frame
		scroll_values.append(dock.package_terms_scroll.scroll_vertical)
	_check(scroll_values.any(func(value): return int(value) != scroll_before), "actual ScreenDrag beginning on armed Confirm moves the scroll value")
	var release_point := point + drag_step * 6.0
	_check(button.get_global_rect().has_point(release_point) and dock.package_terms_scroll.get_global_rect().has_point(release_point), "scroll gesture ends over the armed button inside the viewport")
	await _screen_touch(release_point, false)
	_check(signals_seen.is_empty(), "completed scrolling gesture does not accept the armed package")
	_check(dock.armed_choice_id == "run_package", "scrolling does not resolve or silently replace the armed choice")
	button = await _touch_button(dock)
	point = button.get_global_rect().get_center()
	await _screen_touch(point, true)
	var canceled := InputEventScreenTouch.new()
	canceled.index = 0
	canceled.position = point
	canceled.pressed = false
	canceled.canceled = true
	Input.parse_input_event(canceled)
	await process_frame
	_check(signals_seen.is_empty() and dock.armed_choice_id == "run_package", "OS canceled touch release cannot accept, resolve or disarm the package")
	_check(bool(button.get_meta("package_touch_cancelled", false)), "actual TalkDock records OS cancellation before release callback dispatch")
	button = await _touch_button(dock)
	point = button.get_global_rect().get_center()
	await _screen_touch(point, true)
	_check(signals_seen.is_empty(), "subsequent intentional confirmation tap still waits for release")
	await _screen_touch(point, false)
	_check(signals_seen == [["synthetic_touch_package", "run_package"]], "one intentional completed tap emits the normal request once")
	facts["armed_drag"] = {"scroll_before": scroll_before, "scroll_during": scroll_values, "signals_after_intentional_tap": signals_seen.duplicate(true), "input": "InputEventScreenTouch + InputEventScreenDrag through Input.parse_input_event; no pressed.emit for this mode"}
	dock.queue_free()
	await process_frame
	var fresh_cancel := _touch_offer()
	await _settle()
	# Fresh synthetic armed widget, with no earlier tap or drag on this widget.
	# This is UI-only setup; no game/job/state authority is present.
	fresh_cancel.armed_choice_id = "run_package"
	fresh_cancel._render_choices()
	await _settle()
	button = await _touch_button(fresh_cancel)
	point = button.get_global_rect().get_center()
	await _screen_touch(point, true)
	_check(signals_seen.is_empty(), "fresh armed widget does not dispatch on touch down")
	await _screen_touch(point, false, true)
	_check(signals_seen.is_empty() and fresh_cancel.armed_choice_id == "run_package" and bool(button.get_meta("package_touch_cancelled", false)), "fresh widget rejects OS cancel without any earlier drag/inertia")
	await _screen_touch(point, true)
	await _screen_touch(point, false)
	_check(signals_seen == [["synthetic_touch_package", "run_package"]], "fresh widget accepts only the subsequent deliberate completed tap")
	_check(not bool(button.get_meta("package_touch_cancelled", true)), "new gesture clears only the previous UI cancel flag")
	fresh_cancel.queue_free()
	await process_frame
	var opening := _touch_offer()
	await _settle()
	button = await _touch_button(opening)
	point = button.get_global_rect().get_center()
	# Controlled current-frame UI entry boundary, not a game-time/state edit.
	opening.entry_open_input_frame = Engine.get_process_frames()
	await _screen_touch(point, true)
	_check(bool(button.get_meta("package_entry_press_blocked", false)), "opening-frame press is captured before release-mode callback")
	await _screen_touch(point, false)
	_check(opening.armed_choice_id.is_empty() and signals_seen.is_empty(), "release in a later frame cannot reuse the opening gesture")
	opening.queue_free()
	await process_frame
	Input.emulate_mouse_from_touch = previous_mouse_emulation
	Input.emulate_touch_from_mouse = previous_touch_emulation
	Input.use_accumulated_input = previous_accumulation
	_check(Input.emulate_mouse_from_touch == previous_mouse_emulation and Input.emulate_touch_from_mouse == previous_touch_emulation and Input.use_accumulated_input == previous_accumulation, "test-only input settings restored without persistent settings changes")
	facts["touch_scope"] = "Real synthetic TalkDock and engine touch pipeline; controlled PRESS-property baseline. No campaign, profile, actual package/job listener, transaction or browser/physical-phone claim."


func _touch_offer() -> Dock:
	var dock := Dock.new()
	root.add_child(dock)
	dock.set_reduce_motion(true)
	dock.set_small_screen_mode(true)
	dock.size = Vector2(390, 844)
	signals_seen.clear()
	dock.choice_requested.connect(func(event_id, choice_id): signals_seen.append([event_id, choice_id]))
	var choices: Array = [{"id": "run_package", "label": "Run the package", "package_offer_terms": OFFER_TERMS.repeat(12), "requires_confirm": true}]
	for index in range(3):
		choices.append({"id": "other_%d" % index, "label": "Other existing response %d" % index})
	dock.set_entry({"event_id": "synthetic_touch_package", "speaker": {"name": "Velvet"}}, {"summary": "Synthetic touch offer.", "choices": choices}, 1)
	return dock


func _touch_button(dock: Dock) -> Button:
	var button := _button(dock, "run_package")
	dock.package_terms_scroll.ensure_control_visible(button)
	await _settle()
	var offset := button.get_global_rect().get_center().y - dock.package_terms_scroll.get_global_rect().get_center().y
	dock.package_terms_scroll.scroll_vertical += roundi(offset)
	await _settle()
	return button


func _screen_touch(point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	await process_frame


func _button(dock: Dock, choice_id: String) -> Button:
	for row in dock.choice_list.get_children():
		for child in row.get_children():
			if child is Button and str(child.get_meta("choice_id", "")) == choice_id:
				return child
	return null


func _settle() -> void:
	for _index in range(4):
		await process_frame


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
