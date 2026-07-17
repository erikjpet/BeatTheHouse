class_name RunReportScreen
extends Control

signal new_run_requested
signal home_requested
signal copy_seed_requested(seed: String)
signal bag_claim_requested(marker_id: String)

const WorldMapCanvasScript := preload("res://scripts/ui/world_map_canvas.gd")
const TimelineCanvasScript := preload("res://scripts/ui/run_report_timeline_canvas.gd")
const RunReportViewModelScript := preload("res://scripts/ui/run_report_view_model.gd")
const REPLAY_SECONDS := 7.0

var report_model: Dictionary = {}
var reduce_motion := false
var small_screen_mode := false
var replay_progress := 0.0
var replay_playing := false
var timeline_install_count := 0

var section_panels := {}
var section_titles := {}
var outcome_icon: TextureRect
var outcome_title: Label
var outcome_how: Label
var outcome_where: Label
var outcome_meta_reward: Label
var score_formula: Label
var score_detail: Label
var map_canvas: WorldMapCanvas
var timeline_canvas: RunReportTimelineCanvas
var play_button: Button
var replay_clock_label: Label
var story_rows: VBoxContainer
var item_rows: GridContainer
var bag_reward_row: VBoxContainer
var bag_reward_label: Label
var bag_reward_selector: OptionButton
var bag_claim_button: Button
var debt_rows: VBoxContainer
var seed_label: Label
var button_row: HBoxContainer
var new_run_button: Button
var home_button: Button


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	set_process(false)


func set_report(model: Dictionary) -> void:
	report_model = model
	var tutorial_failure := bool(model.get("tutorial_failure", false))
	new_run_button.text = "Replay Lessons" if tutorial_failure else "New Run"
	home_button.text = "Start Normal Run" if tutorial_failure else "Home"
	new_run_button.tooltip_text = "Restart First Night in Town from the beginning." if tutorial_failure else "Start a new run."
	home_button.tooltip_text = "Leave the tutorial and begin a normal run." if tutorial_failure else "Return to the collection home."
	var outcome := _dict(model.get("outcome", {}))
	var outcome_accent := VisualStyle.TEAL if bool(outcome.get("won", false)) else VisualStyle.PINK
	var result_panel := section_panels.get("result") as PanelContainer
	if result_panel != null:
		result_panel.add_theme_stylebox_override("panel", VisualStyle.pixel_box(Color("#080817", 0.98), outcome_accent, 1))
	var result_title := section_titles.get("result") as Label
	if result_title != null:
		result_title.add_theme_color_override("font_color", outcome_accent)
	outcome_title.text = str(outcome.get("title", "Run complete"))
	outcome_how.text = str(outcome.get("how", "The run ended here."))
	outcome_where.text = str(outcome.get("where", "Unknown room"))
	var meta_reward := _dict(model.get("meta_reward", {}))
	outcome_meta_reward.visible = bool(meta_reward.get("visible", false))
	outcome_meta_reward.text = "%s — %s" % [str(meta_reward.get("title", "")), str(meta_reward.get("detail", ""))]
	outcome_meta_reward.tooltip_text = outcome_meta_reward.text
	_set_icon(outcome_icon, str(outcome.get("icon_path", "")))
	var score := _dict(model.get("score", {}))
	var base := int(score.get("money_put_to_work", 0))
	var multiplier := maxi(1, int(score.get("winner_bonus", 1)))
	var final_score := int(score.get("final_score", base * multiplier))
	score_formula.text = "$%d × %d = %d" % [base, multiplier, final_score] if bool(score.get("show_winner_bonus", false)) else "$%d = %d" % [base, final_score]
	score_detail.text = "Money put to work  ×  Winner's bonus  =  Final score" if bool(score.get("show_winner_bonus", false)) else "Money put to work  =  Final score"
	seed_label.text = "Seed: %s" % str(model.get("seed", ""))
	_render_story(model.get("money_rows", []))
	_render_bag_reward(_dict(model.get("bag_reward", {})))
	_render_items(_dict(model.get("items", {})))
	_render_debts(model.get("debts", []))
	var timeline := _dict(model.get("timeline", {}))
	timeline_canvas.set_timeline(timeline)
	timeline_install_count += 1
	map_canvas.set_map_snapshot(_dict(model.get("map_snapshot", {})))
	map_canvas.set_run_report_replay(timeline.get("travel_keyframes", []), reduce_motion, timeline.get("replay_segments", []))
	replay_progress = 1.0 if reduce_motion else 0.0
	timeline_canvas.set_replay_progress(replay_progress)
	_update_replay_clock()
	play_button.text = "Replay ready" if reduce_motion else "▶ Play"
	play_button.disabled = reduce_motion
	play_button.visible = not reduce_motion
	replay_playing = false
	set_process(false)
	queue_redraw()


func set_reduce_motion(enabled: bool) -> void:
	reduce_motion = enabled
	if not report_model.is_empty():
		var timeline := _dict(report_model.get("timeline", {}))
		map_canvas.set_run_report_replay(timeline.get("travel_keyframes", []), reduce_motion, timeline.get("replay_segments", []))
		replay_progress = 1.0 if reduce_motion else 0.0
		timeline_canvas.set_replay_progress(replay_progress)
		_update_replay_clock()
	play_button.visible = not reduce_motion
	play_button.disabled = reduce_motion
	replay_playing = false
	set_process(false)


func set_small_screen_mode(enabled: bool) -> void:
	small_screen_mode = enabled
	button_row.add_theme_constant_override("separation", 12 if enabled else 9)
	for child in button_row.get_children():
		if child is Button:
			(child as Button).custom_minimum_size.y = 52.0 if enabled else 42.0
	bag_reward_selector.custom_minimum_size.y = 52.0 if enabled else 42.0
	bag_claim_button.custom_minimum_size.y = 52.0 if enabled else 42.0
	_layout_sections()


func _process(delta: float) -> void:
	if not replay_playing or reduce_motion:
		set_process(false)
		return
	replay_progress = minf(1.0, replay_progress + delta / REPLAY_SECONDS)
	map_canvas.set_run_report_replay_progress(replay_progress)
	timeline_canvas.set_replay_progress(replay_progress)
	_update_replay_clock()
	if replay_progress >= 1.0:
		replay_playing = false
		play_button.text = "↻ Replay"
		set_process(false)


func _on_play_pressed() -> void:
	if reduce_motion:
		return
	if replay_progress >= 1.0:
		replay_progress = 0.0
	map_canvas.set_run_report_replay_progress(replay_progress)
	timeline_canvas.set_replay_progress(replay_progress)
	_update_replay_clock()
	replay_playing = true
	play_button.text = "Playing…"
	set_process(true)


func _on_timeline_seek(progress: float) -> void:
	replay_progress = clampf(progress, 0.0, 1.0)
	replay_playing = false
	map_canvas.set_run_report_replay_progress(replay_progress)
	timeline_canvas.set_replay_progress(replay_progress)
	_update_replay_clock()
	play_button.text = "▶ Continue" if replay_progress < 1.0 else "↻ Replay"
	set_process(false)


func _build() -> void:
	var result_stack := _section("result", "RESULT", VisualStyle.PINK)
	var result_row := HBoxContainer.new()
	result_row.add_theme_constant_override("separation", 10)
	result_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_stack.add_child(result_row)
	outcome_icon = TextureRect.new()
	outcome_icon.custom_minimum_size = Vector2(68, 68)
	outcome_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	outcome_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result_row.add_child(outcome_icon)
	var result_copy := VBoxContainer.new()
	result_copy.add_theme_constant_override("separation", 1)
	result_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_row.add_child(result_copy)
	outcome_title = _label("Run complete", 20, VisualStyle.WHITE)
	outcome_how = _label("", 11, VisualStyle.SOFT)
	outcome_how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outcome_how.max_lines_visible = 2
	outcome_where = _label("", 11, VisualStyle.CYAN_2)
	outcome_meta_reward = _label("", 10, VisualStyle.YELLOW)
	outcome_meta_reward.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	outcome_meta_reward.visible = false
	result_copy.add_child(outcome_title)
	result_copy.add_child(outcome_how)
	result_copy.add_child(outcome_where)
	result_copy.add_child(outcome_meta_reward)

	var score_stack := _section("score", "SCORE", VisualStyle.YELLOW)
	score_formula = _label("0 = 0", 28, VisualStyle.YELLOW)
	score_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_formula.size_flags_vertical = Control.SIZE_EXPAND_FILL
	score_formula.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_stack.add_child(score_formula)
	score_detail = _label("Money put to work = Final score", 10, VisualStyle.SOFT)
	score_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_stack.add_child(score_detail)

	var travel_stack := _section("travel", "TRAVEL REPLAY", VisualStyle.CYAN)
	var travel_holder := Control.new()
	travel_holder.clip_contents = true
	travel_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	travel_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	travel_stack.add_child(travel_holder)
	map_canvas = WorldMapCanvasScript.new()
	map_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	travel_holder.add_child(map_canvas)
	play_button = Button.new()
	play_button.text = "▶ Play"
	play_button.position = Vector2(8, 8)
	play_button.custom_minimum_size = Vector2(104, 38)
	play_button.pressed.connect(_on_play_pressed)
	travel_holder.add_child(play_button)
	replay_clock_label = _label("Day 1 12:00 PM · AT VENUE", 11, VisualStyle.WHITE)
	replay_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	replay_clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	replay_clock_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	replay_clock_label.offset_left = -230.0
	replay_clock_label.offset_top = 9.0
	replay_clock_label.offset_right = -9.0
	replay_clock_label.offset_bottom = 31.0
	replay_clock_label.add_theme_color_override("font_shadow_color", Color("#000000", 0.95))
	replay_clock_label.add_theme_constant_override("shadow_offset_x", 2)
	replay_clock_label.add_theme_constant_override("shadow_offset_y", 2)
	travel_holder.add_child(replay_clock_label)

	story_rows = _section("story", "STORY · MONEY FLOW", VisualStyle.TEAL)
	var item_stack := _section("items", "ITEMS · KEPT / PAWNED / SOLD", VisualStyle.AMBER)
	bag_reward_row = VBoxContainer.new()
	bag_reward_row.add_theme_constant_override("separation", 5)
	bag_reward_row.visible = false
	item_stack.add_child(bag_reward_row)
	bag_reward_label = _label("Choose one earned bag", 10, VisualStyle.YELLOW)
	bag_reward_label.custom_minimum_size = Vector2(118, 0)
	bag_reward_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bag_reward_row.add_child(bag_reward_label)
	var bag_reward_actions := HBoxContainer.new()
	bag_reward_actions.add_theme_constant_override("separation", 5)
	bag_reward_row.add_child(bag_reward_actions)
	bag_reward_selector = OptionButton.new()
	bag_reward_selector.custom_minimum_size = Vector2(150, 42)
	bag_reward_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_reward_actions.add_child(bag_reward_selector)
	bag_claim_button = _action_button("Bring Home")
	bag_claim_button.custom_minimum_size.x = 104
	bag_claim_button.pressed.connect(_on_bag_claim_pressed)
	bag_reward_actions.add_child(bag_claim_button)
	item_rows = GridContainer.new()
	item_rows.columns = 2
	item_rows.add_theme_constant_override("h_separation", 5)
	item_rows.add_theme_constant_override("v_separation", 3)
	item_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_stack.add_child(item_rows)

	var heat_stack := _section("heat", "HEAT TIMELINE · DRAG TO SEEK", VisualStyle.ORANGE)
	timeline_canvas = TimelineCanvasScript.new()
	timeline_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	timeline_canvas.seek_requested.connect(_on_timeline_seek)
	heat_stack.add_child(timeline_canvas)

	debt_rows = _section("debt", "DEBT · FULL LEDGER", VisualStyle.PURPLE_2)

	button_row = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 9)
	add_child(button_row)
	new_run_button = _action_button("New Run")
	new_run_button.pressed.connect(func() -> void: new_run_requested.emit())
	button_row.add_child(new_run_button)
	home_button = _action_button("Home")
	home_button.pressed.connect(func() -> void: home_requested.emit())
	button_row.add_child(home_button)
	var copy_seed := _action_button("Copy Seed")
	copy_seed.pressed.connect(func() -> void: copy_seed_requested.emit(str(report_model.get("seed", ""))))
	button_row.add_child(copy_seed)
	seed_label = _label("Seed:", 10, VisualStyle.SOFT)
	seed_label.custom_minimum_size = Vector2(250, 0)
	seed_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button_row.add_child(seed_label)
	_layout_sections()


func _on_bag_claim_pressed() -> void:
	if bag_reward_selector.item_count <= 0:
		return
	var marker_id := str(bag_reward_selector.get_item_metadata(bag_reward_selector.selected)).strip_edges()
	if not marker_id.is_empty():
		bag_claim_requested.emit(marker_id)


func _update_replay_clock() -> void:
	if replay_clock_label == null:
		return
	var timeline := _dict(report_model.get("timeline", {}))
	var cursor: Dictionary = RunReportViewModelScript.cursor_for_progress(timeline, replay_progress)
	var phase := "TRAVELING" if str(cursor.get("phase", "dwell")) == "travel" else "AT VENUE"
	replay_clock_label.text = "%s · %s" % [RunReportViewModelScript.format_game_clock(int(cursor.get("game_clock_minutes", RunState.GAME_CLOCK_START_MINUTE))), phase]


func _section(key: String, title_text: String, accent: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", VisualStyle.pixel_box(Color("#080817", 0.98), accent, 1))
	add_child(panel)
	section_panels[key] = panel
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 6)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(stack)
	var title_label := _label(title_text, 11, accent)
	section_titles[key] = title_label
	stack.add_child(title_label)
	return stack


func _layout_sections() -> void:
	if section_panels.is_empty():
		return
	var width := maxf(1.0, size.x)
	var height := maxf(1.0, size.y)
	var gap: float = 5.0 if small_screen_mode else 7.0
	var margin: float = 5.0 if small_screen_mode else 8.0
	var buttons_h: float = 58.0 if small_screen_mode else 48.0
	var top_h: float = floor(height * 0.17)
	var bottom_h: float = floor(height * 0.245)
	var body_bottom: float = height - margin - buttons_h - gap
	var bottom_y: float = body_bottom - bottom_h
	var middle_y: float = margin + top_h + gap
	var middle_h: float = bottom_y - middle_y - gap
	var left_w: float = floor((width - margin * 2.0 - gap) * 0.65)
	var right_x: float = margin + left_w + gap
	var right_w: float = width - margin - right_x
	_set_rect(section_panels["result"], Rect2(margin, margin, left_w, top_h))
	_set_rect(section_panels["score"], Rect2(right_x, margin, right_w, top_h))
	_set_rect(section_panels["travel"], Rect2(margin, middle_y, left_w, middle_h))
	var story_h: float = floor((middle_h - gap) * 0.48)
	_set_rect(section_panels["story"], Rect2(right_x, middle_y, right_w, story_h))
	_set_rect(section_panels["items"], Rect2(right_x, middle_y + story_h + gap, right_w, middle_h - story_h - gap))
	_set_rect(section_panels["heat"], Rect2(margin, bottom_y, left_w, bottom_h))
	_set_rect(section_panels["debt"], Rect2(right_x, bottom_y, right_w, bottom_h))
	_set_rect(button_row, Rect2(margin, body_bottom + gap, width - margin * 2.0, buttons_h))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_sections()


func _render_story(rows_value: Variant) -> void:
	_clear(story_rows, 1)
	var rows: Array = rows_value if typeof(rows_value) == TYPE_ARRAY else []
	var maximum := 1
	for value in rows:
		if typeof(value) == TYPE_DICTIONARY:
			maximum = maxi(maximum, absi(int((value as Dictionary).get("net", 0))))
	for value in rows.slice(0, 6):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = value
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		var label := _label(str(row.get("label", "Source")).left(20), 10, VisualStyle.SOFT)
		label.custom_minimum_size = Vector2(120, 0)
		line.add_child(label)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = maximum
		bar.value = absi(int(row.get("net", 0)))
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(70, 12)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tone := VisualStyle.TEAL if int(row.get("net", 0)) >= 0 else VisualStyle.PINK
		bar.add_theme_stylebox_override("fill", VisualStyle.pixel_box(Color(tone, 0.78), tone, 1))
		line.add_child(bar)
		var amount := _label("%+d" % int(row.get("net", 0)), 10, tone)
		amount.custom_minimum_size = Vector2(55, 0)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(amount)
		story_rows.add_child(line)
	if rows.is_empty():
		story_rows.add_child(_label("No money moved.", 10, VisualStyle.SOFT))


func _render_items(items: Dictionary) -> void:
	_clear(item_rows)
	var shown := 0
	var maximum_shown := 4 if bag_claim_button.visible else 8
	for group_key in ["kept", "pawned", "sold"]:
		var rows: Array = items.get(group_key, []) if typeof(items.get(group_key, [])) == TYPE_ARRAY else []
		for value in rows:
			if typeof(value) != TYPE_DICTIONARY or shown >= maximum_shown:
				continue
			var row: Dictionary = value
			var cell := HBoxContainer.new()
			cell.add_theme_constant_override("separation", 4)
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(25, 25)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_set_icon(icon, str(row.get("icon_path", "")))
			cell.add_child(icon)
			var suffix := " ×%d" % int(row.get("count", 1)) if int(row.get("count", 1)) > 1 else ""
			if group_key == "pawned": suffix += " · %s" % str(row.get("fate", "held"))
			if group_key == "sold": suffix += " · $%d" % int(row.get("price", 0))
			cell.add_child(_label((str(row.get("label", "Item")) + suffix).left(26), 9, VisualStyle.SOFT))
			item_rows.add_child(cell)
			shown += 1
	if shown == 0:
		item_rows.add_child(_label("No items carried, pawned, or sold.", 10, VisualStyle.SOFT))


func _render_bag_reward(reward: Dictionary) -> void:
	bag_reward_selector.clear()
	var choices: Array = reward.get("choices", []) if typeof(reward.get("choices", [])) == TYPE_ARRAY else []
	for value in choices:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = value
		var marker_id := str(choice.get("marker_id", "")).strip_edges()
		if marker_id.is_empty():
			continue
		var display_name := str(choice.get("display_name", "Collection Bag")).strip_edges()
		bag_reward_selector.add_item(display_name if not display_name.is_empty() else "Collection Bag")
		var index := bag_reward_selector.item_count - 1
		bag_reward_selector.set_item_metadata(index, marker_id)
		var detail_parts: Array[String] = []
		for detail_key in ["collection_name", "tier_label"]:
			var detail := str(choice.get(detail_key, "")).strip_edges()
			if not detail.is_empty() and not detail_parts.has(detail):
				detail_parts.append(detail)
		bag_reward_selector.set_item_tooltip(index, " · ".join(detail_parts))
	var pending := bool(reward.get("pending", false)) and bag_reward_selector.item_count > 0
	bag_reward_row.visible = bool(reward.get("visible", false))
	bag_reward_selector.visible = pending
	bag_claim_button.visible = pending
	new_run_button.disabled = pending
	home_button.disabled = pending
	if pending:
		bag_reward_label.text = "Choose one earned bag"
		bag_reward_label.tooltip_text = "Choose one earned collection bag before leaving this report."
	else:
		var summary_lines: Array = reward.get("summary_lines", []) if typeof(reward.get("summary_lines", [])) == TYPE_ARRAY else []
		bag_reward_label.text = "Stored: %s" % str(summary_lines[0]) if not summary_lines.is_empty() else "Collection bag stored"
		bag_reward_label.tooltip_text = bag_reward_label.text


func _render_debts(rows_value: Variant) -> void:
	_clear(debt_rows, 1)
	var rows: Array = rows_value if typeof(rows_value) == TYPE_ARRAY else []
	for value in rows.slice(0, 6):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = value
		var tone := VisualStyle.YELLOW
		if str(row.get("tone", "")) == "settled": tone = VisualStyle.TEAL
		elif str(row.get("tone", "")) == "burned": tone = VisualStyle.PINK
		debt_rows.add_child(_label("%s · $%d · %s" % [str(row.get("lender", "Lender")), int(row.get("amount", 0)), str(row.get("outcome", "outstanding"))], 10, tone))
	if rows.is_empty():
		debt_rows.add_child(_label("No loans this run.", 10, VisualStyle.SOFT))


func debug_layout_snapshot() -> Dictionary:
	var rects := {}
	for key in section_panels.keys():
		rects[str(key)] = (section_panels[key] as Control).get_rect()
	return {"size": size, "section_rects": rects, "button_rect": button_row.get_rect(), "small_screen_mode": small_screen_mode, "reduce_motion": reduce_motion, "replay_progress": replay_progress, "replay_clock_text": replay_clock_label.text, "timeline_install_count": timeline_install_count, "has_scroll_container": _has_scroll_container(self), "bag_reward_visible": bag_reward_row.visible, "bag_reward_pending": bag_claim_button.visible, "bag_reward_choice_count": bag_reward_selector.item_count, "meta_reward_visible": outcome_meta_reward.visible, "meta_reward_text": outcome_meta_reward.text, "new_run_disabled": new_run_button.disabled, "home_disabled": home_button.disabled}


func _has_scroll_container(node: Node) -> bool:
	for child in node.get_children():
		if child is ScrollContainer or _has_scroll_container(child):
			return true
	return false


func _set_rect(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size


func _action_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(138, 42)
	return button


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	return label


func _set_icon(target: TextureRect, path: String) -> void:
	target.texture = load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null


func _clear(container: Node, keep_count: int = 0) -> void:
	while container.get_child_count() > keep_count:
		container.get_child(keep_count).queue_free()
		container.remove_child(container.get_child(keep_count))


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
