extends SceneTree

const UIArtScript := preload("res://scripts/ui/ui_art.gd")
const SegmentedMeterScript := preload("res://scripts/ui/segmented_meter.gd")
const FoundationHudBarScript := preload("res://scripts/ui/foundation_hud_bar.gd")
const EnvironmentHeaderScript := preload("res://scripts/ui/environment_header.gd")
const CheatDockScript := preload("res://scripts/ui/cheat_dock.gd")
const FoundationWidgetsScript := preload("res://scripts/ui/foundation_widgets.gd")
const VisualStyle := preload("res://scripts/ui/visual_style.gd")
const TalkDockScript := preload("res://scripts/ui/talk_dock.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(UIArtScript.ICON_IDS.size() == 12, "HUD icon contract is incomplete.")
	_check(UIArtScript.PORTRAIT_IDS.size() == 6, "Portrait contract is incomplete.")
	_check(UIArtScript.ENVIRONMENT_TITLE_IDS.size() == 18, "Environment title contract is incomplete.")
	for path in UIArtScript.expected_runtime_paths():
		_check(ResourceLoader.exists(path), "Manifested runtime asset is missing: %s" % path)
	var missing_icon := UIArtScript.fallback_for_test("icon", "missing")
	var missing_title := UIArtScript.fallback_for_test("title", "missing")
	_check(missing_icon != null and missing_icon.get_size() == Vector2(64, 64), "Missing icon did not return its code fallback.")
	_check(missing_title != null and missing_title.get_size() == Vector2(384, 64), "Missing title did not return its code fallback.")

	var meter: SegmentedMeter = SegmentedMeterScript.new()
	root.add_child(meter)
	meter.configure("heat", 0.0)
	_check(str(meter.current_snapshot().get("band", "")) == "safe", "Heat 0 did not use the safe band.")
	meter.configure("heat", 35.0)
	_check(str(meter.current_snapshot().get("band", "")) == "warning", "Heat 35 did not use the warning band.")
	meter.configure("heat", 70.0)
	_check(str(meter.current_snapshot().get("band", "")) == "danger", "Heat 70 did not use the danger band.")
	meter.configure("drunk", 40.0, 20.0)
	var pending_snapshot := meter.current_snapshot()
	_check(bool(pending_snapshot.get("ghost_visible", false)), "Pending drink did not expose a ghost segment.")
	_check((pending_snapshot.get("ticks", []) as Array).size() == 2, "Threshold ticks are missing.")
	meter.queue_free()

	var hud: FoundationHudBar = FoundationHudBarScript.new()
	root.add_child(hud)
	await process_frame
	hud.render({
		"bankroll": 240,
		"bankroll_delta": 40,
		"show_chips": true,
		"chips": 17,
		"heat_level": 70,
		"drunk_level": 40,
		"pending_drunk_absorption": 20,
		"clock_day": 2,
		"clock_minute_of_day": 1420,
		"clock_exact_display": "11:40 PM",
		"clock_display": "Night 2 · 11:40 PM",
		"clock_tooltip": "Closes soon.",
		"status_icons": [{"id": "debt", "icon": "debt", "tooltip": "Marker due"}],
	})
	var hud_snapshot := hud.current_snapshot()
	_check(str(hud_snapshot.get("wallet", "")) == "$240", "Structured HUD wallet does not use authoritative cash.")
	_check(str(hud_snapshot.get("wallet_delta", "")) == "+40", "Structured HUD did not retain the last bankroll gain.")
	_check(str(hud_snapshot.get("wallet_delta_tone", "")) == "success", "Structured HUD bankroll gain did not use the success tone.")
	_check(bool(hud_snapshot.get("wallet_delta_static", false)), "Structured HUD bankroll delta is still animated.")
	_check(is_equal_approx(float(hud_snapshot.get("wallet_delta_alpha", 0.0)), VisualStyle.HUD_LAST_DELTA_ALPHA), "Structured HUD bankroll delta did not use the subtle opacity token.")
	_check(bool(hud_snapshot.get("chips_visible", false)) and str(hud_snapshot.get("chips", "")) == "17", "Grand Casino chips are not conditionally visible.")
	_check(bool((hud_snapshot.get("drunk", {}) as Dictionary).get("ghost_visible", false)), "Structured HUD did not show pending drink.")
	_check(int(hud_snapshot.get("status_icon_count", 0)) == 1, "Structured HUD conditional icon tray is incorrect.")
	hud.call("_on_time_pressed")
	_check(bool(hud.current_snapshot().get("time_detail_visible", false)), "Time widget did not open its schedule detail.")
	_check(str(hud.current_snapshot().get("time_day", "")) == "DAY 2", "Time widget did not show the authoritative run day.")
	_check(str(hud.current_snapshot().get("time_exact", "")) == "11:40 PM", "Time widget did not show the exact authoritative time.")
	var watch_snapshot: Dictionary = hud.current_snapshot().get("time_watch", {})
	_check(int(watch_snapshot.get("minute_of_day", -1)) == 1420, "Analog watch did not use the authoritative run minute.")
	var status_tray: HBoxContainer = hud.status_tray
	var status_icon_id := status_tray.get_child(0).get_instance_id()
	hud.render({
		"bankroll": 240,
		"status_icons": [{"id": "debt", "icon": "debt", "tooltip": "Marker due"}],
	})
	_check(
		status_tray.get_child_count() == 1 and status_tray.get_child(0).get_instance_id() == status_icon_id,
		"Unchanged HUD status data rebuilt the conditional icon tray.",
	)
	hud.render_clock({
		"clock_day": 3,
		"clock_minute_of_day": 75,
		"clock_exact_display": "1:15 AM",
		"clock_tooltip": "Late-run clock tick.",
	})
	var clock_tick_snapshot := hud.current_snapshot()
	_check(str(clock_tick_snapshot.get("time_day", "")) == "DAY 3", "Clock-only HUD refresh did not advance the day.")
	_check(str(clock_tick_snapshot.get("time_exact", "")) == "1:15 AM", "Clock-only HUD refresh did not advance the exact time.")
	_check(str(clock_tick_snapshot.get("wallet", "")) == "$240", "Clock-only HUD refresh disturbed authoritative run status.")
	_check(
		status_tray.get_child_count() == 1 and status_tray.get_child(0).get_instance_id() == status_icon_id,
		"Clock-only HUD refresh rebuilt the conditional icon tray.",
	)
	hud.render({"bankroll": 240, "bankroll_delta": 0})
	_check(str(hud.current_snapshot().get("wallet_delta", "")) == "+40", "A zero-cash refresh cleared the last bankroll change.")
	hud.render({"bankroll": 210, "bankroll_delta": -30})
	var loss_snapshot := hud.current_snapshot()
	_check(str(loss_snapshot.get("wallet_delta", "")) == "-30", "Structured HUD did not replace the last bankroll change with the latest loss.")
	_check(str(loss_snapshot.get("wallet_delta_tone", "")) == "danger", "Structured HUD bankroll loss did not use the danger tone.")
	_check(is_equal_approx(float(loss_snapshot.get("wallet_delta_alpha", 0.0)), VisualStyle.HUD_LAST_DELTA_ALPHA), "Structured HUD bankroll loss did not remain subtly translucent.")
	hud.queue_free()

	var environment_config: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/environment_ui.json"))
	_check(typeof(environment_config) == TYPE_ARRAY, "Environment UI data is not an authoritative data array.")
	var environment_index: Dictionary = {}
	for entry_value in environment_config:
		if typeof(entry_value) == TYPE_DICTIONARY:
			var entry: Dictionary = entry_value
			environment_index[str(entry.get("id", ""))] = entry
	for archetype_id in UIArtScript.ENVIRONMENT_TITLE_IDS:
		_check(environment_index.has(archetype_id), "Environment UI data is missing %s." % archetype_id)
		var entry: Dictionary = environment_index.get(archetype_id, {})
		_check(not str(entry.get("blurb", "")).is_empty(), "%s has no cold-look blurb." % archetype_id)
		_check(not (entry.get("options", []) as Array).is_empty(), "%s has no data-driven option strip." % archetype_id)
	var header: EnvironmentHeader = EnvironmentHeaderScript.new()
	root.add_child(header)
	await process_frame
	header.render({"archetype_id": "grand_casino_cage", "display_name": "Grand Casino Cage"}, "Settle the marker.")
	var header_snapshot := header.current_snapshot()
	_check(str(header_snapshot.get("archetype_id", "")) == "grand_casino_cage", "Environment header lost its archetype identity.")
	_check(int(header_snapshot.get("configured_option_count", 0)) == 4, "Environment header lost its configured room-option data.")
	_check(int(header_snapshot.get("option_count", -1)) == 0, "Environment header still renders instructional option copy.")
	_check(not bool(header_snapshot.get("guidance_visible", true)), "Environment header still renders goal or tutorial guidance.")
	_check(bool(header_snapshot.get("compact", false)), "Environment header did not use its compact presentation.")
	_check(not str(header_snapshot.get("title_texture", "")).is_empty(), "Environment header did not load its title plate.")
	header.queue_free()

	var dock: CheatDock = CheatDockScript.new()
	root.add_child(dock)
	await process_frame
	dock.render({
		"risk_cue": "Room attention raises the cost.",
		"cheat_actions": [
			{"id": "mark_card", "label": "Mark card", "summary": "Heat +8", "suspicion_delta": 8, "selected": false},
			{"id": "signal_friend", "label": "Signal friend", "summary": "Heat +5", "suspicion_delta": 5, "selected": true},
		],
	})
	var dock_snapshot := dock.current_snapshot()
	_check(not bool(dock_snapshot.get("visible", true)), "Legacy cheat dock still renders as a separate menu.")
	_check(int(dock_snapshot.get("action_count", 0)) == 2, "Integrated action compatibility snapshot lost available actions.")
	_check(str(dock_snapshot.get("presentation", "")) == "integrated_game_surface_actions", "Risky actions are not declared as game-surface controls.")
	_check(bool(dock_snapshot.get("actions_on_game_surface", false)), "Risky actions are not assigned to the game surface.")
	_check(not bool(dock_snapshot.get("resizes_environment", true)), "Risky actions still resize the game environment.")
	_check(bool(dock_snapshot.get("selection_requires_confirmation", false)), "Integrated risky actions bypass arm/confirm semantics.")
	dock.render({"cheat_actions": []})
	_check(not bool(dock.current_snapshot().get("visible", true)), "Legacy cheat dock became visible when emptied.")
	dock.queue_free()

	for popup_case in [
		{"viewport": Vector2(1280, 720), "content": Vector2(260, 120)},
		{"viewport": Vector2(960, 540), "content": Vector2(420, 260)},
		{"viewport": Vector2(640, 360), "content": Vector2(720, 640)},
	]:
		var popup := PanelContainer.new()
		root.add_child(popup)
		var viewport_size: Vector2 = popup_case["viewport"]
		var content_size: Vector2 = popup_case["content"]
		var popup_size := FoundationWidgetsScript.autosize_popup(popup, viewport_size, content_size)
		_check(popup_size.x <= viewport_size.x, "Autosized popup escaped the viewport width.")
		_check(popup_size.y <= viewport_size.y, "Autosized popup escaped the viewport height.")
		_check(popup_size.x <= content_size.x + float(VisualStyle.SPACE_6 * 2) or is_equal_approx(popup_size.x, VisualStyle.POPUP_MIN_WIDTH), "Autosized popup retained unexplained horizontal dead space.")
		_check(popup_size.y <= content_size.y + float(VisualStyle.SPACE_6 * 2), "Autosized popup retained unexplained vertical dead space.")
		popup.queue_free()

	var talk: TalkDock = TalkDockScript.new()
	root.add_child(talk)
	await process_frame
	talk.set_entry({
		"event_id": "ui05:test",
		"speaker": {"name": "Sal", "role": "merchant"},
	}, {
		"display_name": "A quiet offer",
		"summary": "Sal names the price and waits for an answer.",
		"choices": [{"id": "leave", "label": "Leave"}],
	}, 1)
	var revealing_talk := talk.current_snapshot()
	_check(bool(revealing_talk.get("typewriter_active", false)), "Conversation copy did not begin its typewriter reveal.")
	_check(str(revealing_talk.get("portrait_renderer", "")) == "animated_character_model", "Conversation did not use the animated character-model renderer.")
	_check(bool(revealing_talk.get("portrait_animation_active", false)), "Conversation character model did not animate.")
	_check(not revealing_talk.has("portrait_texture"), "Conversation unexpectedly exposed a static portrait texture.")
	_check(bool(revealing_talk.get("name_plate", false)), "Conversation speaker is missing a name plate.")
	_check(str(revealing_talk.get("speaker_text", "")) == "Sal", "Conversation title does not show the speaker.")
	_check(bool(revealing_talk.get("topic_visible", false)) and str(revealing_talk.get("topic", "")) == "A quiet offer", "Conversation topic is not visible under the title.")
	var skip_click := InputEventMouseButton.new()
	skip_click.pressed = true
	talk.call("_on_body_gui_input", skip_click)
	_check(not bool(talk.current_snapshot().get("typewriter_active", true)), "Click did not skip the conversation typewriter.")
	talk.set_reduce_motion(true)
	talk.set_entry({
		"event_id": "ui05:reduced",
		"speaker": {"name": "Linda", "presentation": "faceless_silhouette"},
	}, {
		"display_name": "At the cage",
		"summary": "Linda answers without a pause.",
		"choices": [{"id": "leave", "label": "Leave"}],
	}, 1)
	var reduced_talk := talk.current_snapshot()
	_check(not bool(reduced_talk.get("typewriter_active", true)), "Reduce-motion conversation copy still animates.")
	_check(int(reduced_talk.get("visible_characters", 0)) == -1, "Reduce-motion conversation copy is not instantly complete.")
	_check(str(reduced_talk.get("portrait_renderer", "")) == "animated_character_model", "Reduced-motion conversation replaced the character model.")
	_check(str(reduced_talk.get("portrait_presentation", "")) == "faceless_silhouette", "Faceless speaker did not preserve the silhouette model contract.")
	talk.set_entry({
		"event_id": "ui05:group",
		"speaker": {"name": "The Crew", "presentation": "faceless_silhouette", "portrait_count": 3},
	}, {
		"display_name": "Loan Offer",
		"summary": "Three figures wait on your answer.",
		"choices": [{"id": "leave", "label": "Leave"}],
	}, 1)
	var group_talk := talk.current_snapshot()
	_check(int(group_talk.get("portrait_count", 0)) == 3, "Conversation renderer did not preserve a three-person speaker group.")
	talk.set_entry({
		"event_id": "ui05:unknown",
		"speaker": {"name": "", "presentation": "faceless_silhouette"},
	}, {
		"display_name": "A guarded request",
		"summary": "A hidden figure addresses you.",
		"choices": [{"id": "leave", "label": "Leave"}],
	}, 1)
	_check(str(talk.current_snapshot().get("speaker_text", "")) == "Unknown", "Nameless faceless conversation did not use the Unknown title.")
	talk.queue_free()

	if failures.is_empty():
		print("UI05_DESIGN_SYSTEM_CHECK PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
