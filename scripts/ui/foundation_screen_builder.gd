extends RefCounted

const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")


static func build_start_screen(host: Variant) -> void:
	_build_redesigned_start_screen(host)
	return
	# The menu is not interactive until its visible background is ready. Building
	# it here prevents a deferred texture/cache burst from landing under input.
	host._ensure_main_menu_background_built()

	var menu_panel = host._panel_container(Color(VisualStyle.role("surface_base"), 0.96), VisualStyle.PURPLE_2)
	host.main_menu_panel = menu_panel
	menu_panel.clip_contents = true
	menu_panel.anchor_left = 0.5
	menu_panel.anchor_top = 0.5
	menu_panel.anchor_right = 0.5
	menu_panel.anchor_bottom = 0.5
	host._apply_main_menu_panel_size(host.MAIN_MENU_COLLAPSED_SIZE)
	host.start_screen.add_child(menu_panel)

	var menu_margin := MarginContainer.new()
	menu_margin.add_theme_constant_override("margin_left", VisualStyle.SPACE_8 - VisualStyle.SPACE_3)
	menu_margin.add_theme_constant_override("margin_top", VisualStyle.SPACE_6)
	menu_margin.add_theme_constant_override("margin_right", VisualStyle.SPACE_8 - VisualStyle.SPACE_3)
	menu_margin.add_theme_constant_override("margin_bottom", VisualStyle.SPACE_6)
	menu_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_panel.add_child(menu_margin)

	var stack := VBoxContainer.new()
	host.start_menu_stack = stack
	stack.add_theme_constant_override("separation", VisualStyle.SPACE_4)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	menu_margin.add_child(stack)

	host.start_menu_intro = VBoxContainer.new()
	host.start_menu_intro.add_theme_constant_override("separation", VisualStyle.SPACE_4)
	host.start_menu_intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(host.start_menu_intro)

	var kicker = host._label("Run-Based Casino Crime Spiral", VisualStyle.TYPE_BODY_LARGE)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._set_control_font_color(kicker, VisualStyle.YELLOW)
	host.start_menu_intro.add_child(kicker)

	var heading = host._label("BEAT THE HOUSE", VisualStyle.TYPE_DISPLAY)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._set_control_font_color(heading, VisualStyle.PINK)
	host.start_menu_intro.add_child(heading)

	host.release_version_label = host._label(host._release_version_text(), VisualStyle.TYPE_SMALL)
	host.release_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._set_control_font_color(host.release_version_label, VisualStyle.CYAN_2)
	host.start_menu_intro.add_child(host.release_version_label)

	var copy = host._label("Start in cheap rooms, borrow badly, read crooked tables, and climb toward the Grand Casino before the house learns your shape.", VisualStyle.TYPE_BODY_LARGE)
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._set_control_font_color(copy, VisualStyle.SOFT)
	host.start_menu_intro.add_child(copy)

	host.release_framing_label = host._label(host.RELEASE_MENU_FRAMING, VisualStyle.TYPE_SMALL)
	host.release_framing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.release_framing_label.max_lines_visible = 1
	host.release_framing_label.clip_text = true
	host._set_control_font_color(host.release_framing_label, VisualStyle.CYAN_2)
	host.start_menu_intro.add_child(host.release_framing_label)

	host.start_status_label = host._label("", VisualStyle.TYPE_SMALL)
	host.start_status_label.visible = true
	host.start_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._set_control_font_color(host.start_status_label, VisualStyle.YELLOW)
	host.start_menu_intro.add_child(host.start_status_label)

	host.start_menu_controls = VBoxContainer.new()
	host.start_menu_controls.add_theme_constant_override("separation", VisualStyle.SPACE_4)
	host.start_menu_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.start_menu_controls.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stack.add_child(host.start_menu_controls)

	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", VisualStyle.SPACE_4)
	seed_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.start_menu_controls.add_child(seed_row)

	host.seed_input = LineEdit.new()
	host.seed_input.text = host._generate_menu_seed_text()
	host.seed_input.placeholder_text = "Enter run seed"
	host.seed_input.tooltip_text = "Edit the seed before New Run to replay a deterministic climb."
	host.seed_input.custom_minimum_size = Vector2(VisualStyle.FLEXIBLE_SIZE, VisualStyle.TOUCH_TARGET + VisualStyle.SPACE_1)
	host.seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._set_control_font_color(host.seed_input, VisualStyle.WHITE)
	host.seed_input.add_theme_stylebox_override("normal", VisualStyle.pixel_box(Color(VisualStyle.role("surface_raised"), 0.98), VisualStyle.TEAL, VisualStyle.BORDER_STANDARD))
	host.seed_input.add_theme_stylebox_override("focus", VisualStyle.pixel_box(Color(VisualStyle.role("surface_overlay"), 0.98), VisualStyle.CYAN, VisualStyle.BORDER_STANDARD))
	seed_row.add_child(host.seed_input)

	host.content_group_config_button = Button.new()
	host.content_group_config_button.text = "⚙"
	host.content_group_config_button.tooltip_text = "Configure run content."
	host.content_group_config_button.custom_minimum_size = Vector2(VisualStyle.TOUCH_TARGET + VisualStyle.SPACE_1, VisualStyle.TOUCH_TARGET + VisualStyle.SPACE_1)
	host.content_group_config_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	host._set_control_font_color(host.content_group_config_button, VisualStyle.WHITE)
	host._set_control_font_size(host.content_group_config_button, VisualStyle.TYPE_HEADING)
	host.content_group_config_button.add_theme_stylebox_override("normal", VisualStyle.pixel_box(Color(VisualStyle.role("surface_raised"), 0.98), VisualStyle.CYAN_2, VisualStyle.BORDER_STANDARD))
	host.content_group_config_button.add_theme_stylebox_override("hover", VisualStyle.pixel_box(Color(VisualStyle.role("surface_overlay"), 0.98), VisualStyle.CYAN, VisualStyle.BORDER_STANDARD))
	host.content_group_config_button.add_theme_stylebox_override("pressed", VisualStyle.pixel_box(Color(VisualStyle.color("blue"), 1.0), VisualStyle.YELLOW, VisualStyle.BORDER_STANDARD))
	host.content_group_config_button.pressed.connect(host.toggle_content_group_config)
	seed_row.add_child(host.content_group_config_button)

	host.challenge_select_button = host._main_menu_button("Challenges", "Pick an authored challenge run", Callable(host, "toggle_challenge_selection"))
	host.challenge_select_button.custom_minimum_size = Vector2(VisualStyle.SPACE_9 * 4.0, VisualStyle.TOUCH_TARGET + VisualStyle.SPACE_1)
	host.challenge_select_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	host._set_control_font_size(host.challenge_select_button, VisualStyle.TYPE_BODY)
	seed_row.add_child(host.challenge_select_button)

	if not host._defer_start_menu_secondary_panels():
		host._ensure_start_menu_config_panels_built()

	var run_row := HFlowContainer.new()
	run_row.add_theme_constant_override("h_separation", VisualStyle.SPACE_5)
	run_row.add_theme_constant_override("v_separation", VisualStyle.SPACE_3)
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
	utility_row.add_theme_constant_override("h_separation", VisualStyle.SPACE_5)
	utility_row.add_theme_constant_override("v_separation", VisualStyle.SPACE_3)
	utility_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.start_menu_controls.add_child(utility_row)
	host.start_menu_action_controls.append(utility_row)
	host.settings_button = host._main_menu_button("Settings", "Resolution and sound", Callable(host, "open_settings_menu"))
	utility_row.add_child(host.settings_button)
	host.career_button = host._main_menu_button("Career", "Stats and run history", Callable(host, "open_career_stats_screen"))
	utility_row.add_child(host.career_button)
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
	if not host._defer_start_menu_secondary_panels():
		host._build_inventory_page(stack)
		if host.show_game_library_launcher:
			host._build_game_test_menu(stack)


static func _build_redesigned_start_screen(host: Variant) -> void:
	host._ensure_main_menu_background_built()
	var shade := ColorRect.new()
	# Keep the authored venue readable. The button plates supply their own contrast;
	# the menu should not recolor the environment into a generic dark backdrop.
	shade.color = Color("#05050c", 0.18)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.start_screen.add_child(shade)

	var menu_panel := PanelContainer.new()
	host.main_menu_panel = menu_panel
	menu_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_panel.clip_contents = true
	menu_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	menu_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	host.start_screen.add_child(menu_panel)

	var menu_margin := MarginContainer.new()
	menu_margin.add_theme_constant_override("margin_left", 38)
	menu_margin.add_theme_constant_override("margin_top", 24)
	menu_margin.add_theme_constant_override("margin_right", 38)
	menu_margin.add_theme_constant_override("margin_bottom", 20)
	menu_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_panel.add_child(menu_margin)

	var stack := VBoxContainer.new()
	host.start_menu_stack = stack
	stack.add_theme_constant_override("separation", 8)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_margin.add_child(stack)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	top_bar.custom_minimum_size = Vector2(0, 48)
	stack.add_child(top_bar)
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(top_spacer)
	if host.show_game_library_launcher:
		host.game_library_button = host._main_menu_button("GAMES", "Practice any available table", Callable(host, "open_game_test_menu"))
		host.game_library_button.custom_minimum_size = Vector2(132, 48)
		host._set_control_font_size(host.game_library_button, 15)
		top_bar.add_child(host.game_library_button)
	host.inventory_button = host._main_menu_button("INVENTORY", "Open the profile inventory", Callable(host, "open_inventory_page"))
	host.inventory_button.custom_minimum_size = Vector2(148, 48)
	host._set_control_font_size(host.inventory_button, 15)
	top_bar.add_child(host.inventory_button)
	host.career_button = host._main_menu_button("CAREER", "View career statistics", Callable(host, "open_career_stats_screen"))
	host.career_button.custom_minimum_size = Vector2(124, 48)
	host._set_control_font_size(host.career_button, 15)
	top_bar.add_child(host.career_button)
	host.settings_button = host._main_menu_icon_button(String.chr(0x2699), "Settings", Callable(host, "open_settings_menu"), VisualStyle.CYAN)
	top_bar.add_child(host.settings_button)
	host.exit_game_button = host._main_menu_icon_button("X", "Exit Game", Callable(host, "exit_game"), VisualStyle.PINK)
	top_bar.add_child(host.exit_game_button)

	host.start_menu_intro = VBoxContainer.new()
	host.start_menu_intro.add_theme_constant_override("separation", 1)
	host.start_menu_intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.start_menu_intro.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stack.add_child(host.start_menu_intro)
	var logo_center := CenterContainer.new()
	logo_center.custom_minimum_size = Vector2(0, 174)
	logo_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.start_menu_intro.add_child(logo_center)
	host.main_menu_logo = TextureRect.new()
	host.main_menu_logo.texture = load("res://assets/art/ui/beat_the_house_logo.png") as Texture2D
	host.main_menu_logo.custom_minimum_size = Vector2(520, 168)
	host.main_menu_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	host.main_menu_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.main_menu_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_center.add_child(host.main_menu_logo)

	host.start_menu_controls = VBoxContainer.new()
	host.start_menu_controls.add_theme_constant_override("separation", 8)
	host.start_menu_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.start_menu_controls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(host.start_menu_controls)

	host.main_menu_action_row = HBoxContainer.new()
	host.main_menu_action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.main_menu_action_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.start_menu_controls.add_child(host.main_menu_action_row)
	host.start_menu_action_controls.append(host.main_menu_action_row)
	var grid_left_spacer := Control.new()
	grid_left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.main_menu_action_row.add_child(grid_left_spacer)
	var action_grid := VBoxContainer.new()
	action_grid.add_theme_constant_override("separation", 12)
	action_grid.custom_minimum_size = Vector2(916, 224)
	action_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	action_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	host.main_menu_action_row.add_child(action_grid)

	# A fixed three-column marquee grid keeps every action on the same visual
	# rails. PLAY spans two columns, preserving its primary weight without
	# scattering the secondary actions around the room art.
	var primary_row := HBoxContainer.new()
	primary_row.add_theme_constant_override("separation", 12)
	primary_row.custom_minimum_size = Vector2(916, 106)
	action_grid.add_child(primary_row)
	host.new_run_button = host._main_menu_button("PLAY", "Begin a new run", Callable(host, "start_or_continue_primary"))
	host.new_run_button.custom_minimum_size = Vector2(608, 106)
	host.new_run_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	host._set_control_font_size(host.new_run_button, 28)
	primary_row.add_child(host.new_run_button)
	# Continue replaces Play in place; this alias keeps old callers compatible.
	host.continue_button = host.new_run_button
	host.daily_run_button = host._main_menu_button("DAILY CHALLENGE", "Start today's hidden-seed challenge", Callable(host, "start_daily_challenge_run"))
	host.daily_run_button.custom_minimum_size = Vector2(296, 106)
	primary_row.add_child(host.daily_run_button)

	var secondary_row := HBoxContainer.new()
	secondary_row.add_theme_constant_override("separation", 12)
	secondary_row.custom_minimum_size = Vector2(916, 106)
	action_grid.add_child(secondary_row)
	host.run_config_button = host._main_menu_button("%s  RUN SETUP" % String.chr(0x2699), "Seed, challenges, content, and saved run", Callable(host, "toggle_run_configuration"))
	host.run_config_button.custom_minimum_size = Vector2(296, 106)
	secondary_row.add_child(host.run_config_button)
	host.replay_tutorial_button = host._main_menu_button("REPLAY LESSONS", "Replay the guided First Night", Callable(host, "start_tutorial_run"))
	host.replay_tutorial_button.custom_minimum_size = Vector2(296, 106)
	secondary_row.add_child(host.replay_tutorial_button)
	host.collections_button = host._main_menu_button("TRAVEL HOME", "Enter your persistent home", Callable(host, "open_collection_browser"))
	host.collections_button.custom_minimum_size = Vector2(296, 106)
	host.collections_button.icon = load("res://assets/art/ui/travel.png") as Texture2D
	host.collections_button.expand_icon = true
	host.collections_button.add_theme_constant_override("icon_max_width", 34)
	secondary_row.add_child(host.collections_button)
	var grid_right_spacer := Control.new()
	grid_right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.main_menu_action_row.add_child(grid_right_spacer)

	host.run_config_panel = host._panel_container(Color("#060713", 0.96), VisualStyle.CYAN)
	host.run_config_panel.visible = false
	host.run_config_panel.custom_minimum_size = Vector2(760, 292)
	host.run_config_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.run_config_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.start_menu_controls.add_child(host.run_config_panel)
	var config_margin := MarginContainer.new()
	config_margin.add_theme_constant_override("margin_left", 18)
	config_margin.add_theme_constant_override("margin_top", 14)
	config_margin.add_theme_constant_override("margin_right", 18)
	config_margin.add_theme_constant_override("margin_bottom", 14)
	host.run_config_panel.add_child(config_margin)
	host.run_config_content_stack = VBoxContainer.new()
	host.run_config_content_stack.add_theme_constant_override("separation", 10)
	host.run_config_content_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.run_config_content_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	config_margin.add_child(host.run_config_content_stack)
	var config_header := HBoxContainer.new()
	host.run_config_content_stack.add_child(config_header)
	var config_title: Label = host._label("RUN CONFIGURATION", VisualStyle.TYPE_HEADING)
	config_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._set_control_font_color(config_title, VisualStyle.YELLOW)
	config_header.add_child(config_title)
	var config_done: Button = host._button("Done", Callable(host, "close_run_configuration"))
	config_done.custom_minimum_size = Vector2(100, 42)
	config_header.add_child(config_done)
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 10)
	host.run_config_content_stack.add_child(seed_row)
	var seed_label: Label = host._label("Seed", VisualStyle.TYPE_BODY_LARGE)
	seed_label.custom_minimum_size = Vector2(72, 44)
	seed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seed_row.add_child(seed_label)
	host.seed_input = LineEdit.new()
	host.seed_input.text = host._generate_menu_seed_text()
	host.seed_input.placeholder_text = "Enter run seed"
	host.seed_input.tooltip_text = "Set a deterministic seed for the next new run."
	host.seed_input.custom_minimum_size = Vector2(0, 44)
	host.seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._set_control_font_color(host.seed_input, VisualStyle.WHITE)
	host.seed_input.add_theme_stylebox_override("normal", VisualStyle.pixel_box(Color("#090b1b", 0.98), VisualStyle.CYAN_2, 2))
	host.seed_input.add_theme_stylebox_override("focus", VisualStyle.pixel_box(Color("#15102a", 0.98), VisualStyle.YELLOW, 2))
	seed_row.add_child(host.seed_input)
	var config_actions := HBoxContainer.new()
	config_actions.add_theme_constant_override("separation", 10)
	host.run_config_content_stack.add_child(config_actions)
	host.content_group_config_button = host._button("RUN CONTENT", Callable(host, "toggle_content_group_config"))
	host.content_group_config_button.tooltip_text = "Choose which content groups can appear"
	host.content_group_config_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config_actions.add_child(host.content_group_config_button)
	host.challenge_select_button = host._button("CHALLENGES", Callable(host, "toggle_challenge_selection"))
	host.challenge_select_button.tooltip_text = "Choose an authored challenge"
	host.challenge_select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config_actions.add_child(host.challenge_select_button)
	host.delete_saved_run_button = host._button("DELETE SAVED RUN", Callable(host, "request_delete_saved_run"))
	host.delete_saved_run_button.tooltip_text = "Permanently remove the current resume slot"
	host.delete_saved_run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.delete_saved_run_button.add_theme_stylebox_override("normal", VisualStyle.pixel_box(Color("#1b0914", 0.96), VisualStyle.PINK_2, 2))
	config_actions.add_child(host.delete_saved_run_button)
	host.run_config_start_button = host._button("START NEW RUN", Callable(host, "_on_start_pressed"))
	host.run_config_start_button.tooltip_text = "Start a new run with this seed, content, and challenge configuration"
	host.run_config_start_button.custom_minimum_size = Vector2(0, 48)
	host.run_config_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.run_config_start_button.add_theme_stylebox_override("normal", VisualStyle.pixel_box(Color("#10172b", 0.98), VisualStyle.CYAN, 2))
	host.run_config_content_stack.add_child(host.run_config_start_button)

	host.start_status_label = host._label("", VisualStyle.TYPE_SMALL)
	host.start_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host.start_status_label.max_lines_visible = 1
	host.start_status_label.clip_text = true
	host._set_control_font_color(host.start_status_label, VisualStyle.YELLOW)
	stack.add_child(host.start_status_label)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	stack.add_child(footer)
	host.release_framing_label = host._label(host.RELEASE_MENU_FRAMING, 10)
	host.release_framing_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.release_framing_label.max_lines_visible = 1
	host.release_framing_label.clip_text = true
	host._set_control_font_color(host.release_framing_label, VisualStyle.CYAN_2)
	footer.add_child(host.release_framing_label)
	host.release_version_label = host._label(host._release_version_text(), 10)
	host.release_version_label.custom_minimum_size = Vector2(86, 18)
	host.release_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	host.release_version_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	host.release_version_label.clip_text = true
	host._set_control_font_color(host.release_version_label, VisualStyle.CYAN_2)
	footer.add_child(host.release_version_label)

	host.save_delete_confirmation = ConfirmationDialog.new()
	host.save_delete_confirmation.title = "Delete saved run?"
	host.save_delete_confirmation.dialog_text = "Delete the current saved run? This cannot be undone."
	host.save_delete_confirmation.ok_button_text = "Delete Run"
	host.save_delete_confirmation.confirmed.connect(host.confirm_delete_saved_run)
	host.add_child(host.save_delete_confirmation)

	if not host._defer_start_menu_secondary_panels():
		host._ensure_start_menu_config_panels_built()
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
	hud_margin.add_theme_constant_override("margin_left", VisualStyle.SPACE_4)
	hud_margin.add_theme_constant_override("margin_right", VisualStyle.SPACE_4)
	hud_margin.add_theme_constant_override("margin_top", VisualStyle.SPACE_1)
	hud_margin.add_theme_constant_override("margin_bottom", VisualStyle.SPACE_1)
	host.run_hud_panel.add_child(hud_margin)
	var hud_stack := VBoxContainer.new()
	hud_stack.add_theme_constant_override("separation", VisualStyle.SPACE_1)
	hud_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hud_margin.add_child(hud_stack)
	var hud_row := HFlowContainer.new()
	hud_row.add_theme_constant_override("h_separation", VisualStyle.SPACE_4)
	hud_row.add_theme_constant_override("v_separation", VisualStyle.SPACE_1)
	hud_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_stack.add_child(hud_row)
	host.structured_hud = host.FoundationHudBarScript.new()
	host.structured_hud.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	host.structured_hud.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hud_row.add_child(host.structured_hud)
	host.top_menu_button = host._hud_nav_button("Menu", Callable(host, "open_run_menu"))
	host.top_menu_button.custom_minimum_size = Vector2(VisualStyle.SPACE_9 * 2.0 + VisualStyle.SPACE_4, host.MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	hud_row.add_child(host.top_menu_button)
	host.top_settings_button = host._hud_nav_button("Settings", Callable(host, "open_settings_menu"))
	host.top_settings_button.custom_minimum_size = Vector2(VisualStyle.SPACE_9 * 2.0 + VisualStyle.SPACE_5, host.MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	hud_row.add_child(host.top_settings_button)
	host.top_inventory_button = host._hud_nav_button("Inventory", Callable(host, "open_run_inventory"))
	host.top_inventory_button.custom_minimum_size = Vector2(VisualStyle.SPACE_9 * 2.0 + VisualStyle.SPACE_7, host.MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	host.top_inventory_button.tooltip_text = "Inspect current run items."
	hud_row.add_child(host.top_inventory_button)
	host.active_item_button = host._hud_nav_button("Use Item: Empty", Callable(host, "use_active_item_slot"))
	# Keep the action cluster on one line even when the Grand Casino HUD adds
	# its chips meter. Button content otherwise expands past this width and the
	# HFlowContainer wraps the active item below the clipped HUD panel.
	host.active_item_button.custom_minimum_size = Vector2(VisualStyle.SPACE_9 * 5.0 + VisualStyle.SPACE_6, host.MIN_NATIVE_TOUCH_TARGET_HEIGHT)
	host.active_item_button.clip_text = true
	host.active_item_button.tooltip_text = "Use or choose the equipped active item."
	hud_row.add_child(host.active_item_button)
	host.status_label = host._label("", VisualStyle.TYPE_BODY_LARGE)
	host.status_label.visible = false
	host.status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	host.status_label.clip_text = true
	hud_row.add_child(host.status_label)
	host.save_status_label = host._label("", VisualStyle.TYPE_BODY)
	host.save_status_label.visible = false
	host.save_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	host.save_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	host.save_status_label.clip_text = true
	host.save_status_label.custom_minimum_size = Vector2(VisualStyle.ENVIRONMENT_TITLE_COMPACT_SIZE.x, VisualStyle.FLEXIBLE_SIZE)
	hud_row.add_child(host.save_status_label)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", VisualStyle.SPACE_4)
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.title_label = host._label("", VisualStyle.TYPE_SUBHEAD + VisualStyle.BORDER_HAIRLINE)
	host.title_label.visible = false
	host.title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	host.title_label.clip_text = true
	host.title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(host.title_label)
	host.environment_result_panel = host._panel_container(Color(VisualStyle.role("surface_raised"), 0.96), VisualStyle.CYAN_2)
	host.environment_result_panel.custom_minimum_size = Vector2(host.RESULT_FEEDBACK_WIDTH, host.RESULT_FEEDBACK_HEIGHT)
	host.environment_result_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	host.environment_result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.environment_result_panel.visible = false
	title_row.add_child(host.environment_result_panel)
	var result_feedback_stack := VBoxContainer.new()
	result_feedback_stack.add_theme_constant_override("separation", VisualStyle.BORDER_HAIRLINE)
	result_feedback_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.environment_result_panel.add_child(result_feedback_stack)
	host.environment_result_title_label = host._label("Result", VisualStyle.TYPE_MICRO)
	host.environment_result_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	host.environment_result_title_label.clip_text = true
	result_feedback_stack.add_child(host.environment_result_title_label)
	host.environment_result_body_label = host._label("", VisualStyle.TYPE_SMALL)
	host.environment_result_body_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	host.environment_result_body_label.clip_text = true
	result_feedback_stack.add_child(host.environment_result_body_label)

	host.objective_label = host._label("", VisualStyle.TYPE_BODY)
	host.objective_label.visible = false
	host.objective_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	host.objective_label.clip_text = true
	host.objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host._set_control_font_color(host.objective_label, VisualStyle.YELLOW)
	hud_stack.add_child(host.objective_label)
	host.summary_label = host._label("", VisualStyle.TYPE_SMALL)
	host.summary_label.visible = false
	host.summary_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	host.summary_label.max_lines_visible = 1
	host.summary_label.clip_text = true
	host.summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	host.visual_panel_container = host._panel_container(VisualStyle.DARK_2, VisualStyle.CYAN_2)
	host.visual_panel_container.clip_contents = true
	host.visual_panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.visual_panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.visual_panel_container.add_theme_stylebox_override("panel", host._surface_panel_style())
	host.run_screen.add_child(host.visual_panel_container)
	var visual_stack := VBoxContainer.new()
	visual_stack.add_theme_constant_override("separation", VisualStyle.spacing(0))
	visual_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visual_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.visual_panel_container.add_child(visual_stack)
	host.environment_header = host.EnvironmentHeaderScript.new()
	host.environment_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var compact_environment_row := HBoxContainer.new()
	compact_environment_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compact_environment_row.add_child(host.environment_header)
	title_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	compact_environment_row.add_child(title_row)
	visual_stack.add_child(compact_environment_row)
	visual_stack.add_child(host.summary_label)
	host._build_run_report_screen(visual_stack)
	host.environment_canvas = PixelSceneCanvasScript.new()
	host.environment_canvas.clip_contents = true
	host.environment_canvas.custom_minimum_size = host.ENVIRONMENT_CANVAS_MIN_SIZE
	host.environment_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.environment_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.environment_canvas.object_hovered.connect(host._on_environment_object_hovered)
	host.environment_canvas.object_focused.connect(host._on_environment_object_focused)
	host.environment_canvas.object_activated.connect(host._on_environment_object_activated)
	host.environment_canvas.view_geometry_changed.connect(host._on_environment_view_geometry_changed)
	visual_stack.add_child(host.environment_canvas)
	host.game_surface_canvas = host.GameSurfaceCanvasScript.new()
	if host.game_surface_canvas.has_method("bind_surface_audio_authority"):
		host.game_surface_canvas.call("bind_surface_audio_authority", host._game_surface_audio_authority)
	host.game_surface_canvas.custom_minimum_size = host.GAME_SURFACE_PREVIEW_MIN_SIZE
	host.game_surface_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.game_surface_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.game_surface_canvas.surface_action.connect(host._on_game_surface_action)
	host.game_surface_canvas.surface_action_blocked.connect(host._on_game_surface_action_blocked)
	host.game_surface_canvas.surface_pointer_action.connect(host._on_game_surface_pointer_action)
	host.game_surface_canvas.surface_music_cue.connect(host._on_game_surface_music_cue)
	visual_stack.add_child(host.game_surface_canvas)
	host.cheat_dock = host.CheatDockScript.new()
	host.cheat_dock.action_selected.connect(Callable(host, "select_game_action"))
	host.add_child(host.cheat_dock)

	host.action_panel_container = host._panel_container(VisualStyle.DARK_3, VisualStyle.PINK)
	host.action_panel_container.custom_minimum_size = Vector2.ZERO
	host.action_panel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.action_panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.action_panel_container.visible = false
	visual_stack.add_child(host.action_panel_container)
	var action_stack := VBoxContainer.new()
	action_stack.add_theme_constant_override("separation", VisualStyle.SPACE_3)
	action_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.action_panel_container.add_child(action_stack)
	host.action_heading_label = host._label("Room objects", VisualStyle.TYPE_HEADING)
	host._set_control_font_color(host.action_heading_label, VisualStyle.YELLOW)
	action_stack.add_child(host.action_heading_label)
	host.action_hint_label = host._label("Choose a game, answer trouble, buy gear, or move on.", VisualStyle.TYPE_BODY)
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
	host.actions_list.add_theme_constant_override("separation", VisualStyle.SPACE_2 + VisualStyle.BORDER_HAIRLINE)
	host.actions_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.actions_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_scroll.add_child(host.actions_list)

	host.consequence_panel = host._panel_container(VisualStyle.DARK_2, VisualStyle.AMBER)
	host.consequence_panel.custom_minimum_size = Vector2(VisualStyle.FLEXIBLE_SIZE, VisualStyle.FLEXIBLE_SIZE)
	host.consequence_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.consequence_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	host.consequence_panel.visible = false
	hud_stack.add_child(host.consequence_panel)
	var result_stack := VBoxContainer.new()
	result_stack.add_theme_constant_override("separation", VisualStyle.SPACE_2 - VisualStyle.BORDER_HAIRLINE)
	host.consequence_panel.add_child(result_stack)
	host.consequence_heading_label = host._label("Recent consequence", VisualStyle.TYPE_BODY_LARGE + VisualStyle.BORDER_HAIRLINE)
	host._set_control_font_color(host.consequence_heading_label, VisualStyle.AMBER)
	result_stack.add_child(host.consequence_heading_label)
	host.message_label = host._label("", VisualStyle.TYPE_BODY_LARGE)
	host.message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.message_label.visible = false
	result_stack.add_child(host.message_label)
	host.consequence_result_label = host._label("", VisualStyle.TYPE_BODY)
	host.consequence_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.consequence_result_label.visible = false
	result_stack.add_child(host.consequence_result_label)
	host.consequence_state_label = host._label("", VisualStyle.TYPE_BODY)
	host.consequence_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.consequence_state_label.visible = false
	result_stack.add_child(host.consequence_state_label)
	host.consequence_story_label = host._label("", VisualStyle.TYPE_BODY)
	host.consequence_story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.consequence_story_label.visible = false
	result_stack.add_child(host.consequence_story_label)
	host.consequence_cards_scroll = ScrollContainer.new()
	host.consequence_cards_scroll.custom_minimum_size = Vector2(VisualStyle.FLEXIBLE_SIZE, VisualStyle.TOUCH_TARGET - VisualStyle.SPACE_1)
	host.consequence_cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.consequence_cards_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.consequence_cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_stack.add_child(host.consequence_cards_scroll)
	host.consequence_cards_list = HBoxContainer.new()
	host.consequence_cards_list.add_theme_constant_override("separation", VisualStyle.SPACE_3)
	host.consequence_cards_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.consequence_cards_scroll.add_child(host.consequence_cards_list)
	host._apply_run_screen_layout()
