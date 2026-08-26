class_name CareerStatsScreen
extends VBoxContainer

signal close_requested

const CareerStatsViewModelScript := preload("res://scripts/ui/career_stats_view_model.gd")
const FoundationWidgetsScript := preload("res://scripts/ui/foundation_widgets.gd")

var model: Dictionary = {}
var small_screen_mode := false
var reduce_motion := false
var headline_grid: GridContainer
var route_grid: GridContainer
var money_stack: VBoxContainer
var daily_stack: VBoxContainer
var release_grid: GridContainer
var challenge_stack: VBoxContainer
var history_stack: VBoxContainer
var notes_stack: VBoxContainer
var empty_panel: PanelContainer
var _built := false


func _ready() -> void:
	_ensure_built()


func set_profile(profile_inventory: ProfileInventory) -> void:
	set_model(CareerStatsViewModelScript.build(profile_inventory))


func set_model(next_model: Dictionary) -> void:
	_ensure_built()
	model = next_model.duplicate(true)
	_render()


func set_small_screen_mode(enabled: bool) -> void:
	small_screen_mode = enabled
	if headline_grid != null:
		headline_grid.columns = 1 if small_screen_mode else 2
	if route_grid != null:
		route_grid.columns = 1 if small_screen_mode else 3
	if release_grid != null:
		release_grid.columns = 1 if small_screen_mode else 2


func set_reduce_motion(enabled: bool) -> void:
	reduce_motion = enabled


func current_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"empty": bool(model.get("empty", true)),
		"headline_count": _array(model.get("headline", [])).size(),
		"route_count": _array(model.get("routes", [])).size(),
		"route_ids": _row_ids(_array(model.get("routes", []))),
		"release_section_count": _array(model.get("release_0_6", [])).size(),
		"visible_ledger_text": _ledger_text(),
		"history_count": _array(model.get("history", [])).size(),
		"challenge_count": _array(model.get("challenges", [])).size(),
		"small_screen_mode": small_screen_mode,
		"reduce_motion": reduce_motion,
	}


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	add_theme_constant_override("separation", VisualStyle.SPACE_4)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", VisualStyle.SPACE_4)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(header)
	var title := FoundationWidgetsScript.label("Career Ledger", VisualStyle.TYPE_TITLE)
	FoundationWidgetsScript.set_control_font_color(title, VisualStyle.role("focus"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := FoundationWidgetsScript.variant_button("Back", Callable(self, "_on_close_pressed"))
	close_button.custom_minimum_size = Vector2(VisualStyle.SPACE_9 * 3.0, VisualStyle.TOUCH_TARGET)
	header.add_child(close_button)

	var subtitle := FoundationWidgetsScript.muted_label("Your permanent ledger fills in as runs end: routes, streaks, money, and scars.", VisualStyle.TYPE_BODY)
	subtitle.max_lines_visible = 2
	add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", VisualStyle.SPACE_5)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	empty_panel = _panel(VisualStyle.role("surface_raised"), VisualStyle.role("selected"))
	body.add_child(empty_panel)
	var empty_stack := VBoxContainer.new()
	empty_stack.add_theme_constant_override("separation", VisualStyle.SPACE_2)
	empty_panel.add_child(empty_stack)
	var empty_title := FoundationWidgetsScript.label("No runs recorded yet", VisualStyle.TYPE_HEADING)
	FoundationWidgetsScript.set_control_font_color(empty_title, VisualStyle.role("selected"))
	empty_stack.add_child(empty_title)
	empty_stack.add_child(FoundationWidgetsScript.muted_label("Start a run. Win or lose, the ledger will record the route, money, and what came home.", VisualStyle.TYPE_BODY))

	headline_grid = GridContainer.new()
	headline_grid.columns = 1 if small_screen_mode else 2
	headline_grid.add_theme_constant_override("h_separation", VisualStyle.SPACE_4)
	headline_grid.add_theme_constant_override("v_separation", VisualStyle.SPACE_4)
	headline_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(headline_grid)

	body.add_child(_section_heading("Victory Routes"))
	route_grid = GridContainer.new()
	route_grid.columns = 1 if small_screen_mode else 3
	route_grid.add_theme_constant_override("h_separation", VisualStyle.SPACE_4)
	route_grid.add_theme_constant_override("v_separation", VisualStyle.SPACE_4)
	route_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(route_grid)

	body.add_child(_section_heading("Money and Streaks"))
	var money_panel := _panel(VisualStyle.role("surface_raised"), VisualStyle.role("accent_primary"))
	body.add_child(money_panel)
	money_stack = VBoxContainer.new()
	money_stack.add_theme_constant_override("separation", VisualStyle.SPACE_3)
	money_panel.add_child(money_stack)
	daily_stack = VBoxContainer.new()
	daily_stack.add_theme_constant_override("separation", VisualStyle.SPACE_2)
	money_stack.add_child(daily_stack)

	body.add_child(_section_heading("Run Ledger"))
	release_grid = GridContainer.new()
	release_grid.columns = 1 if small_screen_mode else 2
	release_grid.add_theme_constant_override("h_separation", VisualStyle.SPACE_4)
	release_grid.add_theme_constant_override("v_separation", VisualStyle.SPACE_4)
	release_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(release_grid)

	body.add_child(_section_heading("Completed Challenges"))
	challenge_stack = VBoxContainer.new()
	challenge_stack.add_theme_constant_override("separation", VisualStyle.SPACE_3)
	challenge_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(challenge_stack)

	body.add_child(_section_heading("Recent Runs"))
	history_stack = VBoxContainer.new()
	history_stack.add_theme_constant_override("separation", VisualStyle.SPACE_3)
	history_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(history_stack)

	body.add_child(_section_heading("Profile Notes"))
	notes_stack = VBoxContainer.new()
	notes_stack.add_theme_constant_override("separation", VisualStyle.SPACE_2)
	body.add_child(notes_stack)


func _render() -> void:
	if empty_panel != null:
		empty_panel.visible = bool(model.get("empty", true))
	_render_headlines()
	_render_routes()
	_render_money()
	_render_release_ledger()
	_render_challenges()
	_render_history()
	_render_notes()


func _render_headlines() -> void:
	FoundationWidgetsScript.clear(headline_grid)
	for entry_value in _array(model.get("headline", [])):
		var entry := _dict(entry_value)
		headline_grid.add_child(_stat_card(str(entry.get("label", "")), str(entry.get("value", "")), str(entry.get("detail", "")), VisualStyle.role("focus")))


func _render_routes() -> void:
	FoundationWidgetsScript.clear(route_grid)
	for entry_value in _array(model.get("routes", [])):
		var entry := _dict(entry_value)
		var accent := VisualStyle.role("success") if bool(entry.get("complete", false)) else VisualStyle.role("text_muted")
		var detail := "Recorded in the ledger" if bool(entry.get("complete", false)) else "No wins recorded"
		if bool(entry.get("historical", false)):
			detail = "Historical route entry"
		route_grid.add_child(_stat_card(str(entry.get("label", "")), str(entry.get("value", "")), detail, accent))


func _render_money() -> void:
	FoundationWidgetsScript.clear(daily_stack)
	for entry_value in _array(model.get("money", [])):
		var entry := _dict(entry_value)
		daily_stack.add_child(FoundationWidgetsScript.stat_chip(null, str(entry.get("label", "")), str(entry.get("value", ""))))
	var daily := _dict(model.get("daily", {}))
	daily_stack.add_child(FoundationWidgetsScript.stat_chip(null, "Daily streak", "%d / best %d" % [int(daily.get("current_streak", 0)), int(daily.get("best_streak", 0))]))
	var last_date := str(daily.get("last_completed_date", "")).strip_edges()
	if not last_date.is_empty():
		daily_stack.add_child(FoundationWidgetsScript.muted_label("Last daily clear: %s" % last_date, VisualStyle.TYPE_SMALL))


func _render_release_ledger() -> void:
	FoundationWidgetsScript.clear(release_grid)
	for section_value in _array(model.get("release_0_6", [])):
		var section := _dict(section_value)
		var panel := _panel(VisualStyle.role("surface_raised"), VisualStyle.role("focus"))
		release_grid.add_child(panel)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", VisualStyle.SPACE_2)
		panel.add_child(stack)
		var title := FoundationWidgetsScript.label(str(section.get("title", "Ledger")), VisualStyle.TYPE_SUBHEAD)
		FoundationWidgetsScript.set_control_font_color(title, VisualStyle.role("focus"))
		stack.add_child(title)
		for row_value in _array(section.get("rows", [])):
			var row := _dict(row_value)
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", VisualStyle.SPACE_3)
			var label := FoundationWidgetsScript.muted_label(str(row.get("label", "")), VisualStyle.TYPE_SMALL)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(label)
			var value := FoundationWidgetsScript.label(str(row.get("value", "")), VisualStyle.TYPE_SMALL)
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			FoundationWidgetsScript.set_control_font_color(value, VisualStyle.role("selected"))
			line.add_child(value)
			stack.add_child(line)


func _render_challenges() -> void:
	FoundationWidgetsScript.clear(challenge_stack)
	var challenges := _array(model.get("challenges", []))
	if challenges.is_empty():
		challenge_stack.add_child(FoundationWidgetsScript.muted_label("No challenge clears yet. Optional runs will leave their stamp here.", VisualStyle.TYPE_BODY))
		return
	for challenge_value in challenges:
		var challenge := _dict(challenge_value)
		challenge_stack.add_child(FoundationWidgetsScript.icon_label_row(null, str(challenge.get("title", "Challenge"))))


func _render_history() -> void:
	FoundationWidgetsScript.clear(history_stack)
	var history := _array(model.get("history", []))
	if history.is_empty():
		history_stack.add_child(FoundationWidgetsScript.muted_label("No finished runs yet. Your first bust or victory becomes the opening entry.", VisualStyle.TYPE_BODY))
		return
	for entry_value in history:
		var entry := _dict(entry_value)
		var accent := VisualStyle.role("success") if bool(entry.get("won", false)) else VisualStyle.role("danger")
		var panel := _panel(VisualStyle.role("surface_raised"), accent)
		history_stack.add_child(panel)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", VisualStyle.SPACE_2)
		panel.add_child(stack)
		var title := FoundationWidgetsScript.label("%s · %s" % [str(entry.get("date", "")), str(entry.get("outcome", ""))], VisualStyle.TYPE_BODY_LARGE)
		FoundationWidgetsScript.set_control_font_color(title, accent)
		stack.add_child(title)
		var detail := "%s · %s · %s" % [str(entry.get("bankroll", "")), str(entry.get("day", "")), str(entry.get("actions", ""))]
		stack.add_child(FoundationWidgetsScript.muted_label(detail, VisualStyle.TYPE_SMALL))


func _render_notes() -> void:
	FoundationWidgetsScript.clear(notes_stack)
	for note_value in _array(model.get("missing_stats", [])):
		notes_stack.add_child(FoundationWidgetsScript.muted_label(str(note_value), VisualStyle.TYPE_SMALL))


func _stat_card(label_text: String, value_text: String, detail_text: String, accent: Color) -> PanelContainer:
	var card := _panel(VisualStyle.role("surface_raised"), accent)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", VisualStyle.SPACE_2)
	card.add_child(stack)
	var label := FoundationWidgetsScript.muted_label(label_text, VisualStyle.TYPE_CAPTION)
	stack.add_child(label)
	var value := FoundationWidgetsScript.label(value_text, VisualStyle.TYPE_HEADING)
	FoundationWidgetsScript.set_control_font_color(value, accent)
	stack.add_child(value)
	if not detail_text.strip_edges().is_empty():
		stack.add_child(FoundationWidgetsScript.muted_label(detail_text, VisualStyle.TYPE_SMALL))
	return card


func _section_heading(text: String) -> Label:
	var heading := FoundationWidgetsScript.label(text, VisualStyle.TYPE_SUBHEAD)
	FoundationWidgetsScript.set_control_font_color(heading, VisualStyle.role("focus"))
	return heading


func _panel(fill: Color, border: Color) -> PanelContainer:
	var panel := FoundationWidgetsScript.panel_container(fill, border)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel


func _on_close_pressed() -> void:
	close_requested.emit()


func _array(value: Variant) -> Array:
	return (value as Array) if typeof(value) == TYPE_ARRAY else []


func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary) if typeof(value) == TYPE_DICTIONARY else {}


func _row_ids(rows: Array) -> Array:
	var result: Array = []
	for row_value in rows:
		if typeof(row_value) == TYPE_DICTIONARY:
			result.append(str((row_value as Dictionary).get("id", "")))
	return result


func _ledger_text() -> String:
	var parts: Array[String] = []
	for section_value in _array(model.get("release_0_6", [])):
		var section := _dict(section_value)
		parts.append(str(section.get("title", "")))
		for row_value in _array(section.get("rows", [])):
			var row := _dict(row_value)
			parts.append("%s %s" % [str(row.get("label", "")), str(row.get("value", ""))])
	return " | ".join(parts)
