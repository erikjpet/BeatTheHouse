extends RefCounted

const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")


static func build_start_screen(host: Variant) -> void:
	host.main_menu_background = PixelSceneCanvasScript.new()
	host.main_menu_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.start_screen.add_child(host.main_menu_background)
	var menu_environment_id = host._main_menu_background_environment_id()
	if not menu_environment_id.is_empty():
		host.main_menu_background.set("environment_id", menu_environment_id)
	host.main_menu_background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var menu_panel = host._panel_container(Color("#050611", 0.96), VisualStyle.PURPLE_2)
	host.main_menu_panel = menu_panel
	menu_panel.clip_contents = true
	menu_panel.anchor_left = 0.5
	menu_panel.anchor_top = 0.5
	menu_panel.anchor_right = 0.5
	menu_panel.anchor_bottom = 0.5
	host._apply_main_menu_panel_size(host.MAIN_MENU_COLLAPSED_SIZE)
	host.start_screen.add_child(menu_panel)

	var menu_margin := MarginContainer.new()
	menu_margin.add_theme_constant_override("margin_left", 18)
	menu_margin.add_theme_constant_override("margin_top", 16)
	menu_margin.add_theme_constant_override("margin_right", 18)
	menu_margin.add_theme_constant_override("margin_bottom", 16)
	menu_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_panel.add_child(menu_margin)

	var stack := VBoxContainer.new()
	host.start_menu_stack = stack
	stack.add_theme_constant_override("separation", 8)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	menu_margin.add_child(stack)

	host.start_menu_intro = VBoxContainer.new()
	host.start_menu_intro.add_theme_constant_override("separation", 8)
	host.start_menu_intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(host.start_menu_intro)

	var kicker = host._label("Run-Based Casino Crime Spiral", 14)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._set_control_font_color(kicker, VisualStyle.YELLOW)
	host.start_menu_intro.add_child(kicker)

	var heading = host._label("BEAT THE HOUSE", 38)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._set_control_font_color(heading, VisualStyle.PINK)
	host.start_menu_intro.add_child(heading)

	host.release_version_label = host._label(host._release_version_text(), 12)
	host.release_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._set_control_font_color(host.release_version_label, VisualStyle.CYAN_2)
	host.start_menu_intro.add_child(host.release_version_label)

	var copy = host._label("Start in cheap rooms, borrow badly, read crooked tables, and climb toward the Grand Casino before the house learns your shape.", 14)
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._set_control_font_color(copy, VisualStyle.SOFT)
	host.start_menu_intro.add_child(copy)

	host.release_framing_label = host._label(host.RELEASE_MENU_FRAMING, 12)
	host.release_framing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.release_framing_label.max_lines_visible = 1
	host.release_framing_label.clip_text = true
	host._set_control_font_color(host.release_framing_label, VisualStyle.CYAN_2)
	host.start_menu_intro.add_child(host.release_framing_label)

	host.start_status_label = host._label("", 12)
	host.start_status_label.visible = true
	host.start_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._set_control_font_color(host.start_status_label, VisualStyle.YELLOW)
	host.start_menu_intro.add_child(host.start_status_label)

	host.start_menu_controls = VBoxContainer.new()
	host.start_menu_controls.add_theme_constant_override("separation", 8)
	host.start_menu_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.start_menu_controls.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stack.add_child(host.start_menu_controls)

	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	seed_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.start_menu_controls.add_child(seed_row)

	host.seed_input = LineEdit.new()
	host.seed_input.text = host._generate_menu_seed_text()
	host.seed_input.placeholder_text = "Enter run seed"
	host.seed_input.tooltip_text = "Edit the seed before New Run to replay a deterministic climb."
	host.seed_input.custom_minimum_size = Vector2(0, 46)
	host.seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._set_control_font_color(host.seed_input, VisualStyle.WHITE)
	host.seed_input.add_theme_stylebox_override("normal", VisualStyle.pixel_box(Color("#080817", 0.98), VisualStyle.TEAL, 2))
	host.seed_input.add_theme_stylebox_override("focus", VisualStyle.pixel_box(Color("#111024", 0.98), VisualStyle.CYAN, 2))
	seed_row.add_child(host.seed_input)

	host.content_group_config_button = Button.new()
	host.content_group_config_button.text = "⚙"
	host.content_group_config_button.tooltip_text = "Configure run content."
	host.content_group_config_button.custom_minimum_size = Vector2(46, 46)
	host.content_group_config_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	host._set_control_font_color(host.content_group_config_button, VisualStyle.WHITE)
	host._set_control_font_size(host.content_group_config_button, 18)
	host.content_group_config_button.add_theme_stylebox_override("normal", VisualStyle.pixel_box(Color("#080817", 0.98), VisualStyle.CYAN_2, 2))
	host.content_group_config_button.add_theme_stylebox_override("hover", VisualStyle.pixel_box(Color("#13142c", 0.98), VisualStyle.CYAN, 2))
	host.content_group_config_button.add_theme_stylebox_override("pressed", VisualStyle.pixel_box(Color("#271538", 1.0), VisualStyle.YELLOW, 2))
	host.content_group_config_button.pressed.connect(host.toggle_content_group_config)
	seed_row.add_child(host.content_group_config_button)

	host.challenge_select_button = host._main_menu_button("Challenges", "Pick an authored challenge run", Callable(host, "toggle_challenge_selection"))
	host.challenge_select_button.custom_minimum_size = Vector2(128, 46)
	host.challenge_select_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	host._set_control_font_size(host.challenge_select_button, 13)
	seed_row.add_child(host.challenge_select_button)

	host._build_content_group_controls(host.start_menu_controls)
	host._build_challenge_controls(host.start_menu_controls)

	var run_row := HFlowContainer.new()
	run_row.add_theme_constant_override("h_separation", 12)
	run_row.add_theme_constant_override("v_separation", 6)
	run_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.start_menu_controls.add_child(run_row)
	host.start_menu_action_controls.append(run_row)
	host.new_run_button = host._main_menu_button("New Run", "Start a seeded climb", Callable(host, "_on_start_pressed"))
	run_row.add_child(host.new_run_button)
	host.daily_run_button = host._main_menu_button("Daily Run", "Start today's hidden-seed challenge", Callable(host, "start_daily_challenge_run"))
	run_row.add_child(host.daily_run_button)
	host.continue_button = host._main_menu_button("Continue", "Load the saved run", Callable(host, "load_foundation_run"))
	run_row.add_child(host.continue_button)
	host.replay_tutorial_button = host._main_menu_button("Replay Lessons", "Replay the guided First Night", Callable(host, "start_tutorial_run"))
	run_row.add_child(host.replay_tutorial_button)

	var utility_row := HFlowContainer.new()
	utility_row.add_theme_constant_override("h_separation", 12)
	utility_row.add_theme_constant_override("v_separation", 6)
	utility_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.start_menu_controls.add_child(utility_row)
	host.start_menu_action_controls.append(utility_row)
	host.settings_button = host._main_menu_button("Settings", "Resolution and sound", Callable(host, "open_settings_menu"))
	utility_row.add_child(host.settings_button)
	host.inventory_button = host._main_menu_button("Inventory", "Profile stash", Callable(host, "open_inventory_page"))
	utility_row.add_child(host.inventory_button)
	host.collections_button = host._main_menu_button("Home", "Meta home, pawn shop, and bags", Callable(host, "open_collection_browser"))
	utility_row.add_child(host.collections_button)
	if host.show_game_library_launcher:
		host.game_library_button = host._main_menu_button("Games", "Practice any table", Callable(host, "open_game_test_menu"))
		utility_row.add_child(host.game_library_button)

	host.exit_game_button = host._main_menu_button("Exit Game", "Close the game window", Callable(host, "exit_game"))
	host.start_menu_controls.add_child(host.exit_game_button)
	host.start_menu_action_controls.append(host.exit_game_button)

	host._build_inventory_page(stack)
	if host.show_game_library_launcher:
		host._build_game_test_menu(stack)


static func build_run_screen(host: Variant) -> void:
	host.run_hud_panel = host._panel(VisualStyle.DARK_2, VisualStyle.CYAN_2)
	host.run_hud_panel.clip_contents = true
	host.run_hud_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.run_hud_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	host.run_screen.add_child(host.run_hud_panel)
	var hud_margin := MarginContainer.new()
	hud_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_margin.add_theme_constant_override("margin_left", 8)
	hud_margin.add_theme_constant_override("margin_right", 8)
	hud_margin.add_theme_constant_override("margin_top", 6)
	hud_margin.add_theme_constant_override("margin_bottom", 4)
	host.run_hud_panel.add_child(hud_margin)
	var hud_stack := VBoxContainer.new()
	hud_stack.add_theme_constant_override("separation", 2)
	hud_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hud_margin.add_child(hud_stack)
	var hud_row := HBoxContainer.new()
	hud_row.add_theme_constant_override("separation", 8)
	hud_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_stack.add_child(hud_row)
	host.top_menu_button = host._hud_nav_button("Menu", Callable(host, "open_run_menu"))
	hud_row.add_child(host.top_menu_button)
	host.top_settings_button = host._hud_nav_button("Settings", Callable(host, "open_settings_menu"))
	hud_row.add_child(host.top_settings_button)
	host.top_inventory_button = host._hud_nav_button("Inventory", Callable(host, "open_run_inventory"))
	host.top_inventory_button.custom_minimum_size = Vector2(118, host.MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	host.top_inventory_button.tooltip_text = "Inspect current run items."
	hud_row.add_child(host.top_inventory_button)
	host.status_label = host._label("", 14)
	host.status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	host.status_label.clip_text = true
	hud_row.add_child(host.status_label)
	host.save_status_label = host._label("", 13)
	host.save_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	host.save_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	host.save_status_label.clip_text = true
	host.save_status_label.custom_minimum_size = Vector2(260, 0)
	hud_row.add_child(host.save_status_label)
	host.active_item_button = host._hud_nav_button("Active: Empty", Callable(host, "use_active_item_slot"))
	host.active_item_button.custom_minimum_size = Vector2(148, host.MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	host.active_item_button.tooltip_text = "Use the equipped active item."
	hud_row.add_child(host.active_item_button)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_stack.add_child(title_row)
	host.title_label = host._label("", 17)
	host.title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	host.title_label.clip_text = true
	host.title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(host.title_label)
	host.environment_result_panel = host._panel_container(Color("#080817", 0.96), VisualStyle.CYAN_2)
	host.environment_result_panel.custom_minimum_size = Vector2(host.RESULT_FEEDBACK_WIDTH, host.RESULT_FEEDBACK_HEIGHT)
	host.environment_result_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	host.environment_result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.environment_result_panel.visible = false
	title_row.add_child(host.environment_result_panel)
	var result_feedback_stack := VBoxContainer.new()
	result_feedback_stack.add_theme_constant_override("separation", 1)
	result_feedback_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.environment_result_panel.add_child(result_feedback_stack)
	host.environment_result_title_label = host._label("Result", 10)
	host.environment_result_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	host.environment_result_title_label.clip_text = true
	result_feedback_stack.add_child(host.environment_result_title_label)
	host.environment_result_body_label = host._label("", 12)
	host.environment_result_body_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	host.environment_result_body_label.clip_text = true
	result_feedback_stack.add_child(host.environment_result_body_label)

	host.objective_label = host._label("", 13)
	host.objective_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	host.objective_label.clip_text = true
	host.objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._set_control_font_color(host.objective_label, VisualStyle.YELLOW)
	hud_stack.add_child(host.objective_label)
	host.summary_label = host._label("", 12)
	host.summary_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	host.summary_label.max_lines_visible = 1
	host.summary_label.clip_text = true
	host.summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_stack.add_child(host.summary_label)

	host.visual_panel_container = host._panel_container(VisualStyle.DARK_2, VisualStyle.CYAN_2)
	host.visual_panel_container.clip_contents = true
	host.visual_panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.visual_panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.visual_panel_container.add_theme_stylebox_override("panel", host._surface_panel_style())
	host.run_screen.add_child(host.visual_panel_container)
	var visual_stack := VBoxContainer.new()
	visual_stack.add_theme_constant_override("separation", 0)
	visual_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visual_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.visual_panel_container.add_child(visual_stack)
	host._build_run_report_screen(visual_stack)
	host.environment_canvas = PixelSceneCanvasScript.new()
	host.environment_canvas.clip_contents = true
	host.environment_canvas.custom_minimum_size = host.ENVIRONMENT_CANVAS_MIN_SIZE
	host.environment_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.environment_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.environment_canvas.object_hovered.connect(host._on_environment_object_hovered)
	host.environment_canvas.object_focused.connect(host._on_environment_object_focused)
	host.environment_canvas.object_activated.connect(host._on_environment_object_activated)
	visual_stack.add_child(host.environment_canvas)
	host.game_surface_canvas = host.GameSurfaceCanvasScript.new()
	host.game_surface_canvas.custom_minimum_size = host.GAME_SURFACE_PREVIEW_MIN_SIZE
	host.game_surface_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.game_surface_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.game_surface_canvas.surface_action.connect(host._on_game_surface_action)
	host.game_surface_canvas.surface_action_blocked.connect(host._on_game_surface_action_blocked)
	host.game_surface_canvas.surface_pointer_action.connect(host._on_game_surface_pointer_action)
	host.game_surface_canvas.surface_music_cue.connect(host._on_game_surface_music_cue)
	visual_stack.add_child(host.game_surface_canvas)

	host.action_panel_container = host._panel_container(VisualStyle.DARK_3, VisualStyle.PINK)
	host.action_panel_container.custom_minimum_size = Vector2.ZERO
	host.action_panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.action_panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.action_panel_container.visible = false
	visual_stack.add_child(host.action_panel_container)
	var action_stack := VBoxContainer.new()
	action_stack.add_theme_constant_override("separation", 6)
	action_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.action_panel_container.add_child(action_stack)
	host.action_heading_label = host._label("Room objects", 18)
	host._set_control_font_color(host.action_heading_label, VisualStyle.YELLOW)
	action_stack.add_child(host.action_heading_label)
	host.action_hint_label = host._label("Choose a game, answer trouble, buy gear, or move on.", 13)
	host.action_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.action_hint_label.max_lines_visible = 2
	host.action_hint_label.clip_text = true
	action_stack.add_child(host.action_hint_label)
	var action_scroll := ScrollContainer.new()
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	action_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_stack.add_child(action_scroll)
	host.actions_list = VBoxContainer.new()
	host.actions_list.add_theme_constant_override("separation", 5)
	host.actions_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.actions_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_scroll.add_child(host.actions_list)

	host.consequence_panel = host._panel_container(VisualStyle.DARK_2, VisualStyle.AMBER)
	host.consequence_panel.custom_minimum_size = Vector2(0, 0)
	host.consequence_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.consequence_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	host.consequence_panel.visible = false
	hud_stack.add_child(host.consequence_panel)
	var result_stack := VBoxContainer.new()
	result_stack.add_theme_constant_override("separation", 3)
	host.consequence_panel.add_child(result_stack)
	host.consequence_heading_label = host._label("Recent consequence", 15)
	host._set_control_font_color(host.consequence_heading_label, VisualStyle.AMBER)
	result_stack.add_child(host.consequence_heading_label)
	host.message_label = host._label("", 14)
	host.message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.message_label.visible = false
	result_stack.add_child(host.message_label)
	host.consequence_result_label = host._label("", 13)
	host.consequence_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.consequence_result_label.visible = false
	result_stack.add_child(host.consequence_result_label)
	host.consequence_state_label = host._label("", 13)
	host.consequence_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.consequence_state_label.visible = false
	result_stack.add_child(host.consequence_state_label)
	host.consequence_story_label = host._label("", 13)
	host.consequence_story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.consequence_story_label.visible = false
	result_stack.add_child(host.consequence_story_label)
	host.consequence_cards_scroll = ScrollContainer.new()
	host.consequence_cards_scroll.custom_minimum_size = Vector2(0, 42)
	host.consequence_cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.consequence_cards_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.consequence_cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_stack.add_child(host.consequence_cards_scroll)
	host.consequence_cards_list = HBoxContainer.new()
	host.consequence_cards_list.add_theme_constant_override("separation", 6)
	host.consequence_cards_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.consequence_cards_scroll.add_child(host.consequence_cards_list)
	host._apply_run_screen_layout()
