extends SceneTree

# Captured locked Count setup, supplied outside the repository. This is a
# read-only native UI component check, not a new heist attempt: no response,
# lock, clue, schedule, payout or Save is accepted. The simulation clock is
# disabled on the detached host so layout frames cannot advance the fixture.
const Host := preload("res://scripts/ui/foundation_main.gd")
const Fingerprint := preload("res://scripts/core/game_ritual_runtime.gd")
const EVENT_ID := "crew_planning_table"
var checks := 0
var failures: Array[String] = []
var facts: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "isolated component-test root required"):
		_finish(); return
	var bundle := OS.get_environment("BTH_PLANNING_CARD_BUNDLE")
	if not _check(not bundle.is_empty(), "genuine captured locked-setup bundle required"):
		_finish(); return
	_install(bundle)
	if not failures.is_empty():
		_finish(); return
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	app.set_anchors_preset(Control.PRESET_TOP_LEFT)
	app.size = Vector2(root.size)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "official Continue loads copied locked setup"):
		app.queue_free(); await process_frame; _finish(); return
	var run: RunState = app.run_state
	_check(run.bankroll == 120 and run.grand_casino_chips == 0 and run.suspicion_level() == 10, "captured 120cash/0chips/Heat10 retained")
	_check(run.crew_reputation() == 92 and str(run.current_environment.get("current_layer_id")) == "back_room", "captured Crew92 Back Room retained")
	var before := Fingerprint.canonical_fingerprint(run.to_save_snapshot())
	var option: Dictionary = app._eligible_event_option(EVENT_ID)
	var choices: Array = option.get("choices", [])
	var choice_before := Fingerprint.canonical_fingerprint(choices)
	var expected_ids := ["inspect", "table_talk", "count_schedule", "count_cart", "begin_play", "abort", "leave"]
	_check(choices.map(func(value): return str(value.get("id", ""))) == expected_ids, "exact seven captured setup choices, no invented eligibility")
	_check(app._event_inline_response_actions(EVENT_ID, choices).is_empty(), "oversized planning choices are not placed in the floating room card")
	_check(app._event_inline_response_actions("ordinary_layout_control", [{"id": "leave", "label": "Leave", "text": "No effect."}]).size() == 1, "ordinary single inline response remains available")
	_check(app._event_allows_canvas_inline_response(RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID, [{"id": "enter_back_room"}]), "existing initial Grand entry remains inline")
	_check(not app._event_allows_canvas_inline_response(RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID, [{"id": "other"}]), "other Grand responses retain popup ownership")
	for mode in [{"size": Vector2i(1280, 720), "small": false}, {"size": Vector2i(960, 540), "small": false}, {"size": Vector2i(720, 1280), "small": true}]:
		root.size = mode.size
		app.size = Vector2(mode.size)
		app.user_settings.play_on_small_screen = bool(mode.small)
		app.user_settings.text_size = "large" if bool(mode.small) else "normal"
		app._apply_accessibility_settings()
		for frame in range(3): await process_frame
		_check(app.focus_interactable_object("event:" + EVENT_ID), "normal room focus reaches Planning Table")
		_check(app.activate_interactable_object("event:" + EVENT_ID), "normal Review responses opens Planning Table")
		for frame in range(4): await process_frame
		app._position_event_choice_popup()
		await process_frame
		var panel: Rect2 = app.event_choice_popup_panel.get_global_rect()
		var overlay: Rect2 = app.event_choice_popup_overlay.get_global_rect()
		facts.append({"stage": "layout_diagnostic", "mode": str(mode.size), "viewport": str(app.get_viewport_rect()), "host_size": str(app.size), "overlay": str(overlay), "overlay_parent": str(app.event_choice_popup_overlay.get_parent()), "scroll_mode": app.event_choice_popup_scroll.vertical_scroll_mode})
		_check(overlay.encloses(panel), "planning window remains within visible viewport")
		_check(app.event_choice_popup_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "long setup uses existing whole-window scrolling")
		var buttons := _choice_buttons(app.event_choice_popup_choices_list)
		_check(buttons.keys() == expected_ids, "all seven original response identities rendered once in authored order")
		for choice in choices:
			var choice_id := str(choice.get("id", ""))
			var button: Button = buttons.get(choice_id)
			if not _check(button != null, "rendered response exists: " + choice_id): continue
			_check(button.disabled == (bool(choice.get("disabled", false)) or not bool(choice.get("enabled", true))), "authored disabled state retained: " + choice_id)
			app.event_choice_popup_scroll.ensure_control_visible(button)
			for frame in range(2): await process_frame
			var viewport: Rect2 = app.event_choice_popup_scroll.get_global_rect()
			_check(viewport.grow(1.0).encloses(button.get_global_rect()), "response is fully pointer-reachable after ordinary scroll: " + choice_id)
			var card: Node = button.get_parent().get_parent()
			var expected_detail := app._event_choice_action_detail(choice)
			_check(_label_texts(card).has(expected_detail), "public cost and prose retained: " + choice_id)
			for body in card.find_children("*", "Label", true, false):
				if body is Label and body.text == expected_detail:
					facts.append({"choice_id": choice_id, "line_count": body.get_line_count(), "visible_line_count": body.get_visible_line_count(), "line_height": body.get_line_height(), "label_size": str(body.size), "min_size": str(body.get_combined_minimum_size()), "text_lines": body.max_lines_visible})
					_check(body.max_lines_visible == -1, "planning prose is not capped inside its scrollable card: " + choice_id)
					_check(not body.text.is_empty() and body.get_line_count() <= body.get_visible_line_count(), "all wrapped planning terms remain visible within the card: " + choice_id)
					_check(body.get_global_rect().end.y <= button.get_global_rect().position.y + 1, "complete planning terms do not overlap their response button: " + choice_id)
		_check(Fingerprint.canonical_fingerprint(run.to_save_snapshot()) == before, "focus/open/scroll changes no cash, time, RNG, heist, knowledge or history")
		_check(Fingerprint.canonical_fingerprint(app._eligible_event_option(EVENT_ID).get("choices", [])) == choice_before, "viewing does not mutate choice eligibility or payloads")
		facts.append({"viewport": str(mode.size), "small": mode.small, "panel": str(panel), "choice_ids": buttons.keys(), "responses_accepted": 0})
		app._dismiss_interactable_event_popup()
		await process_frame
	_check(Fingerprint.canonical_fingerprint(run.to_save_snapshot()) == before, "neutral dismissal preserves entire captured run")
	app.queue_free()
	await process_frame
	_finish()

func _install(bundle: String) -> void:
	var user := ProjectSettings.globalize_path("user://")
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	DirAccess.make_dir_recursive_absolute(user)
	DirAccess.make_dir_recursive_absolute(saves)
	for name in ["foundation_ui_autosave.json", "foundation_ui_autosave.json.bak"]:
		_check(DirAccess.copy_absolute(bundle.path_join(name), saves.path_join(name)) == OK, "install private save companion")
	_check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"), user.path_join(".crew_host_authority_v1")) == OK, "install private authority companion")
	for pair in [["profile_inventory.json", "BTH_PROFILE_INVENTORY_PATH"], ["meta_collection.json", "BTH_META_COLLECTION_PATH"]]:
		for suffix in ["", ".bak"]:
			if FileAccess.file_exists(bundle.path_join(pair[0] + suffix)):
				_check(not OS.get_environment(pair[1]).is_empty() and DirAccess.copy_absolute(bundle.path_join(pair[0] + suffix), OS.get_environment(pair[1]) + suffix) == OK, "install explicit private profile companion")

func _choice_buttons(node: Node) -> Dictionary:
	var result := {}
	for child in node.get_children():
		if child is Button and str(child.get_meta("event_id", "")) == EVENT_ID:
			var choice_id := str(child.get_meta("choice_id", ""))
			_check(not result.has(choice_id), "no duplicate response button")
			result[choice_id] = child
		var nested := _choice_buttons(child)
		for key in nested:
			_check(not result.has(key), "no duplicate nested response button")
			result[key] = nested[key]
	return result

func _label_texts(node: Node) -> Array:
	var result := []
	for child in node.get_children():
		if child is Label: result.append(child.text)
		result.append_array(_label_texts(child))
	return result

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

func _finish() -> void:
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts, "fidelity": "Captured locked setup loaded through official Continue in isolated native component context; UI focus/open/scroll/dismiss only. No response, clue, schedule, payout, Save or gameplay progression."}, "  "))
	print("CREW_PLANNING_POPUP_LAYOUT checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
