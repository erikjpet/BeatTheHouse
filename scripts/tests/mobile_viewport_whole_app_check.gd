extends SceneTree

const Main := preload("res://scripts/ui/foundation_main.gd")
const MainScene := preload("res://scenes/main.tscn")
const Policy := preload("res://scripts/ui/mobile_viewport_policy.gd")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const Generator := preload("res://scripts/core/run_generator.gd")

# Native Windows supplies the real root, Main and GUI input pipeline. Only the
# platform predicate and native physical-window settings calls are substituted;
# Web startup/rotation and browser touch still need separate actual evidence.
class PhoneSettings extends UserSettings:
	func _apply_window() -> void:
		pass

class App extends Main:
	var observe_delivery_only := false
	var observed_delivery: Array[String] = []
	func _mobile_viewport_platform_supported() -> bool:
		return true
	func _initialize_user_settings() -> void:
		user_settings = PhoneSettings.new()
		user_settings_load_outcome = user_settings.load()
		selected_home_type_id = user_settings.selected_home_type_id
		user_settings.apply()
	func _activate_delivery_physical_action(verb: String) -> bool:
		if observe_delivery_only:
			observed_delivery.append(verb)
			return false
		return super._activate_delivery_physical_action(verb)

class Observer extends Node:
	var touch_positions: Array[Vector2] = []
	var pointer_events: Array[Dictionary] = []
	func _input(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
			touch_positions.append(event.position)
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			pointer_events.append({"type": event.get_class(), "device": touch.device, "position": touch.position, "pressed": touch.pressed, "canceled": touch.canceled})
		elif event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			pointer_events.append({"type": event.get_class(), "device": mouse.device, "position": mouse.position, "pressed": mouse.pressed, "canceled": mouse.canceled})

class TermsRun extends RunState:
	func delivery_crew_offer(_definition_id: String, _clock: int = -1) -> Dictionary:
		return {"ok": true, "message": "Synthetic route: recipient at the Corner Store, Day 2 14:00-16:00. ".repeat(12)}

class DenseHUDRun extends RunState:
	func delivery_top_actions() -> Array:
		# The ordinary carried-cargo model permits these four top-strip verbs.
		return [{"id": "wait", "label": "Hold Sightline"}, {"id": "duck", "label": "Duck Cover"}, {"id": "stash", "label": "Stash Package"}, {"id": "ditch", "label": "Ditch Package"}]
	func delivery_has_active_run() -> bool:
		return true
	func delivery_timing_text() -> String:
		return "Synthetic recipient at the Corner Store | 11 minutes remain"
	func crew_delivery_obligation_count() -> int:
		return 2

var checks := 0
var failures: Array[String] = []
var phases: Array[String] = []
var facts: Dictionary = {}
var observer: Observer
var app: App
var original_scale: Vector2i
var original_size: Vector2i


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
	return ok


func _settle(frames: int = 8) -> void:
	for _frame in range(frames):
		await process_frame


func _policy() -> void:
	for requested in [Vector2i(390, 844), Vector2i(375, 667), Vector2i(844, 390), Vector2i(1280, 720)]:
		var target: Vector2i = Policy.target_size(requested, true)
		_check(Policy.target_size(requested, false) == Vector2i(1280, 720), "unsupported native platform retains original authored root")
		_check(Policy.target_size(requested * 2, true) == target, "device pixel ratio does not change logical policy")
		if requested.y > requested.x:
			_check(target.x == 390 and target.y > target.x, "portrait uses the actual aspect and phone logical width")
			var scale: float = minf(float(requested.x) / target.x, float(requested.y) / target.y)
			_check(absf(target.x * scale - requested.x) <= 1.0 and absf(target.y * scale - requested.y) <= 1.0, "portrait content covers the phone within integer-rounding tolerance")
		else:
			_check(target == Vector2i(1280, 720), "desktop and landscape retain the authored root")
	_check(Policy.target_size(Vector2i.ZERO, true) == Vector2i(1280, 720), "pure invalid-size fallback remains bounded")
	phases.append("policy")


func _touch(point: Vector2, down: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = down
	event.canceled = canceled
	Input.parse_input_event(event)
	await process_frame


func _tap_control(control: Control, description: String) -> bool:
	if not _check(is_instance_valid(control) and control.is_visible_in_tree(), description + " exists and is visible"):
		return false
	if control is BaseButton and not _check(not control.disabled, description + " is enabled"):
		return false
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await _settle()
	var rect := control.get_global_rect()
	if not _check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(rect), description + " is inside the logical viewport"):
		return false
	var logical := rect.get_center()
	var physical: Vector2 = root.get_final_transform() * logical
	var pointer_before := observer.pointer_events.size()
	var hit_trace: Array[Dictionary] = []
	_trace_controls(root, logical, hit_trace)
	var seen := observer.touch_positions.size()
	var pressed_count := [0]
	var pressed_observer := func(): pressed_count[0] += 1
	if control is BaseButton:
		control.pressed.connect(pressed_observer)
	await _touch(physical, true)
	await _touch(physical, false)
	await _settle()
	var hovered := root.gui_get_hovered_control()
	if not facts.has("control_input"):
		facts["control_input"] = []
	facts["control_input"].append({"description": description, "path": str(control.get_path()), "logical": logical, "physical": physical, "mouse_filter": control.mouse_filter,
		"gui_disable_input": root.gui_disable_input, "mouse_from_touch": Input.emulate_mouse_from_touch, "touch_from_mouse": Input.emulate_touch_from_mouse,
		"accumulated_input": Input.use_accumulated_input, "mouse_position_after": root.get_mouse_position(), "hovered_after": str(hovered.get_path()) if hovered != null else "",
		"pointer_events": observer.pointer_events.slice(pointer_before), "visible_controls_at_point": hit_trace.slice(maxi(0, hit_trace.size() - 32)), "pressed_count": pressed_count[0]})
	if is_instance_valid(control) and control is BaseButton:
		control.pressed.disconnect(pressed_observer)
		_check(pressed_count[0] == 1, description + " emits its actual connected press exactly once")
	_check(observer.touch_positions.size() > seen and observer.touch_positions.back().distance_to(logical) <= 1.0, description + " real root input transform aligns with the drawn target")
	return true


func _trace_controls(node: Node, point: Vector2, output: Array[Dictionary]) -> void:
	if node is Control and node.is_visible_in_tree() and node.get_global_rect().has_point(point):
		output.append({"path": str(node.get_path()), "class": node.get_class(), "mouse_filter": node.mouse_filter, "z_index": node.z_index, "rect": node.get_global_rect()})
	for child in node.get_children():
		_trace_controls(child, point, output)


func _find_button(node: Node, prefix: String) -> Button:
	if node is Button and node.text.strip_edges().to_lower().begins_with(prefix.to_lower()):
		return node
	for child in node.get_children():
		var found := _find_button(child, prefix)
		if found != null:
			return found
	return null


func _protected(run: RunState) -> PackedByteArray:
	return var_to_bytes([run.bankroll, run.grand_casino_chips, run.suspicion, run.game_clock_minutes,
		run.rng_state, run.story_log, run.inventory, run.debt, run.crew_jobs, run.active_delivery_run])


func _title_gestures() -> bool:
	var before_run: RunState = app.run_state
	var scroll := app.portrait_start_layout["scroll"] as ScrollContainer
	facts["title_actions"] = []
	for row in app.portrait_start_layout["action_nodes"]:
		var control := row["control"] as BaseButton
		var frame_before: int = Engine.get_process_frames()
		var before_rect: Rect2 = control.get_global_rect()
		scroll.ensure_control_visible(control)
		await _settle()
		var bar: VScrollBar = scroll.get_v_scroll_bar()
		var record := {"label": control.text, "before_frame": frame_before, "after_frame": Engine.get_process_frames(),
			"before_rect": before_rect, "rect": control.get_global_rect(), "minimum": control.custom_minimum_size, "combined_minimum": control.get_combined_minimum_size(),
			"base_minimum": control.get_meta(app.ACCESSIBILITY_BASE_MIN_SIZE_META, null), "scroll_rect": scroll.get_global_rect(),
			"offset": scroll.scroll_vertical, "maximum": bar.max_value, "page": bar.page, "grid_rect": (app.portrait_start_layout["action_grid"] as Control).get_global_rect(),
			"small_screen": app.user_settings.play_on_small_screen, "control_scale": app._accessibility_control_scale()}
		facts["title_actions"].append(record)
		print("BTH31_TITLE_BOUNDS ", JSON.stringify(record))
		_check(scroll.get_global_rect().encloses(control.get_global_rect()), "each original title action is reachable by portrait scrolling")
		_check(not control.pressed.get_connections().is_empty(), "reflow preserves every title action callback")
		var base: Vector2 = control.get_meta(app.ACCESSIBILITY_BASE_MIN_SIZE_META)
		_check(base.y == 106.0, "portrait title rounding preserves the original unscaled106px metadata")
		_check(is_equal_approx(control.custom_minimum_size.y, ceilf(base.y * app._accessibility_control_scale())), "portrait title uses whole-pixel minima after actual accessibility scaling")
	if not await _tap_control(app.run_config_button, "Run Setup"):
		return false
	_check(app.run_config_panel.visible, "actual Run Setup opens without losing the action")
	if not await _tap_control(_find_button(app.run_config_panel, "Done"), "Run Setup Done"):
		return false
	_check(not app.run_config_panel.visible and app.main_menu_action_row.visible, "Run Setup closes and restores the same title actions")
	scroll.ensure_control_visible(app.new_run_button)
	await _settle()
	var logical := app.new_run_button.get_global_rect().get_center()
	var physical: Vector2 = root.get_final_transform() * logical
	await _touch(physical, true)
	_check(app.run_state == before_run and app.current_screen == app.SCREEN_START, "portrait title action waits until gesture completion")
	await _touch(physical, false, true)
	await _settle()
	if not _check(app.run_state == before_run and app.current_screen == app.SCREEN_START, "OS touch cancellation cannot start Continue"):
		return false
	_check(not app.new_run_button.disabled, "cancellation restores the original enabled control for deliberate retry")
	var before := scroll.scroll_vertical
	var direction := 1.0 if before >= 60 else -1.0
	await _touch(physical, true)
	for index in range(1, 7):
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = root.get_final_transform() * (logical + Vector2(0, direction * index * 10))
		event.relative = root.get_final_transform().basis_xform(Vector2(0, direction * 10))
		event.screen_relative = event.relative
		Input.parse_input_event(event)
		await process_frame
	var release_logical := logical + Vector2(0, direction * 60)
	_check(scroll.scroll_vertical != before, "drag over title action genuinely moves the portrait scroll region")
	_check(app.new_run_button.get_global_rect().has_point(release_logical), "scroll gesture releases over the moved title action")
	await _touch(root.get_final_transform() * release_logical, false)
	await _settle()
	if not _check(app.run_state == before_run and app.current_screen == app.SCREEN_START, "scrolling from Continue cannot activate it on release"):
		return false
	phases.append("title_gestures")
	return true


func _startup_and_continue(size: Vector2i, cold: bool) -> bool:
	root.size = size
	root.content_scale_size = Vector2i(1280, 720)
	observer = Observer.new()
	root.add_child(observer)
	# Preserve the authored root layout rather than constructing a bare Control.
	# Only the two documented platform/settings substitutions replace its script.
	var scene_root := MainScene.instantiate()
	scene_root.set_script(App)
	app = scene_root as App
	if not _check(app != null, "actual authored Main scene accepts the documented native phone substitutions"):
		scene_root.free()
		return false
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	await _settle()
	facts["startup_viewport"] = {"requested_window": size, "actual_window": root.size, "content_scale_size": root.content_scale_size, "visible_rect": root.get_visible_rect(), "final_transform": root.get_final_transform(), "authored_scene": app.scene_file_path, "Main_rect": app.get_global_rect(), "start_screen_rect": app.start_screen.get_global_rect(), "small_screen": app.user_settings.play_on_small_screen, "control_scale": app._accessibility_control_scale(), "ready_frame": Engine.get_process_frames(), "title_minimum_after_ready": app.new_run_button.custom_minimum_size}
	_check(app.get_global_rect().is_equal_approx(root.get_visible_rect()), "authored Main root fills the actual logical viewport before input")
	_check(app.start_screen.get_global_rect().is_equal_approx(root.get_visible_rect()), "authored start clipping region fills the actual logical viewport before input")
	_check(root.content_scale_size == Policy.target_size(size, true), "actual Main startup applies the candidate root policy")
	if not _check(app._ensure_run_ui_built(), "actual Main completes its real run UI dependencies"):
		return false
	app._ensure_full_content_library_loaded()
	await _settle()
	facts["title_after_dependency_build"] = {"frame": Engine.get_process_frames(), "minimum": app.new_run_button.custom_minimum_size, "rect": app.new_run_button.get_global_rect(), "small_screen": app.user_settings.play_on_small_screen}
	_check(app.new_run_button != null and app.settings_button != null, "all original title controls remain available")
	if not cold:
		var run := RunState.new()
		run.start_new("BTH-31-SYNTHETIC-GENERATED-UI")
		var generation_failures: Array = []
		Fidelity.generate_and_finalize(Generator.new(app.library), run, generation_failures, "BTH-31 initial test room")
		if not _check(generation_failures.is_empty(), "normal generated room passes strict finalization"):
			facts["generation_failures"] = generation_failures
			return false
		_check(app.save_service.save_run(run, app.autosave_slot_id) == OK, "fresh synthetic resident slot saved normally, with no key copy")
	app._refresh_start_screen()
	await _settle()
	_check(app.new_run_button.text == "CONTINUE", "actual title exposes Continue for the resident test slot")
	if Policy.portrait_layout(root.get_visible_rect().size):
		if not await _title_gestures():
			return false
	else:
		_check(app.new_run_button.action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE, "landscape preserves original default title release behavior")
	if not await _tap_control(app.new_run_button, "title Continue"):
		return false
	if not _check(app.run_state != null and app.current_screen == app.SCREEN_ENVIRONMENT, "real Continue enters the generated room"):
		return false
	phases.append("startup_continue")
	return true


func _run_controls() -> void:
	var run: RunState = app.run_state
	var before := _protected(run)
	_check(app.structured_hud.wallet_value.text.contains(str(run.bankroll)), "HUD money remains accurate")
	_check(app.run_hud_panel.get_global_rect().encloses(app.top_menu_button.get_global_rect()), "Menu remains within the visible HUD budget")
	_check(app.run_hud_panel.get_global_rect().encloses(app.structured_hud.get_global_rect()), "wrapped HUD values remain within their panel")
	facts["HUD"] = {"panel": app.run_hud_panel.get_global_rect(), "values": app.structured_hud.get_global_rect(), "Menu": app.top_menu_button.get_global_rect(), "wallet_text": app.structured_hud.wallet_value.text}
	phases.append("HUD")
	var canvas := app.environment_canvas
	var candidate_id := ""
	var candidate_point := Vector2.ZERO
	# Match the same published cache used by Canvas drawing and hit testing;
	# scene_objects alone is the legacy room source, not the Foundation catalog.
	for value in canvas._active_scene_objects():
		if typeof(value) != TYPE_DICTIONARY or not bool(value.get("interactive", true)):
			continue
		var object_id := str(value.get("id", ""))
		var rect: Rect2 = canvas.global_rect_for_object(object_id)
		if rect.has_area() and canvas.get_global_rect().encloses(rect):
			var local := canvas.get_global_transform().affine_inverse() * rect.get_center()
			if canvas.object_id_at_local_position(local) == object_id:
				candidate_id = object_id
				candidate_point = rect.get_center()
				break
	if _check(not candidate_id.is_empty(), "a normal visible generated room object has aligned draw/hit bounds"):
		var physical: Vector2 = root.get_final_transform() * candidate_point
		await _touch(physical, true)
		await _touch(physical, false)
		await _settle(16)
		_check(canvas.selected_object_id == candidate_id, "real touch focuses the drawn room object")
		_check(_protected(run) == before, "focus changes no finance/clock/history/jobs/RNG")
	phases.append("environment_focus")
	if not await _tap_control(app.top_menu_button, "HUD Menu"):
		return
	_check(app.run_menu_overlay.visible, "real Menu callback opens the run menu")
	if not await _tap_control(app.run_menu_resume_button, "Resume"):
		return
	_check(not app.run_menu_overlay.visible, "real Resume callback closes the run menu")
	_check(_protected(run) == before, "Menu and Resume preserve protected run state")
	phases.append("menu_resume")
	if not await _tap_control(app.top_menu_button, "HUD Menu for Save"):
		return
	if not await _tap_control(app.run_menu_save_button, "normal Save"):
		return
	_check(bool(app.save_service.last_save_outcome.get("ok", false)), "normal connected Save succeeds")
	_check(_protected(run) == before, "Save does not change protected run state")
	_check(not app.run_menu_overlay.visible, "successful ordinary Save closes its menu through the production callback")
	phases.append("save")
	if not await _tap_control(app.top_settings_button, "HUD Settings"):
		return
	_check(app.settings_overlay.visible, "Settings opens through its actual control")
	var previous_small := app.user_settings.play_on_small_screen
	if not await _tap_control(app.settings_menu.play_on_small_screen, "small-screen preference"):
		return
	var apply_button := _find_button(app.settings_menu, "Apply")
	if not await _tap_control(apply_button, "Settings Apply"):
		return
	_check(app.user_settings.play_on_small_screen != previous_small, "normal Apply commits the visible small-screen preference")
	_check(root.content_scale_size == Policy.target_size(root.size, true), "Settings Apply retains the actual viewport policy")
	var back_button := _find_button(app.settings_menu, "Back")
	if not await _tap_control(back_button, "Settings Back"):
		return
	_check(not app.settings_overlay.visible, "Settings closes through its actual control")
	_check(app.run_hud_panel.get_global_rect().encloses(app.top_menu_button.get_global_rect()), "Menu remains visible after the changed control/font scale")
	_check(_protected(run) == before, "Settings UI preserves protected run state")
	phases.append("settings")
	if not await _tap_control(app.top_inventory_button, "HUD Inventory"):
		return
	_check(app.run_inventory_overlay.visible, "actual Inventory opens from its preserved control")
	_assert_inventory_portrait_bounds("ordinary font")
	if not await _tap_control(_find_button(app.run_inventory_screen, "Close"), "Inventory Close"):
		return
	_check(not app.run_inventory_overlay.visible and _protected(run) == before, "neutral Inventory close preserves the generated run")
	phases.append("inventory_access")
	await _dense_hud(run, before)
	app.environment_result_title_label.text = "Result"
	app.environment_result_body_label.text = "Synthetic display-only result. No payment or action."
	app.environment_result_panel.visible = true
	app._invalidate_run_screen_layout()
	app._apply_run_screen_layout()
	await _settle()
	_check(app.visual_panel_container.get_global_rect().encloses(app.environment_result_panel.get_global_rect()), "visible Result remains inside the room region")
	phases.append("result")
	app.talk_dock.set_entry({"event_id": "BTH31generic", "speaker": {"name": "Synthetic neighbour"}}, {"summary": "An ordinary unfinished response.", "choices": [{"id": "leave", "label": "Leave"}]}, 1)
	await _settle()
	_check(app.talk_dock.body_label.visible and not app.talk_dock.package_terms_scroll.visible, "generic dialogue keeps its ordinary body surface")
	_check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(app.talk_dock.panel.get_global_rect()), "generic dialogue fits the actual candidate viewport")
	phases.append("generic_dialogue")
	# Exercise the real package projection in the same whole-app UI. This test
	# data is never saved or accepted, and the generated run remains protected.
	var preview := TermsRun.new()
	preview.start_new("BTH-31-SYNTHETIC-DIALOGUE")
	preview.narrative_flags["crew_delivery_obligations"] = 2
	preview.current_environment = {"id": "BTH31preview", "kind": "casino", "tier": 1, "lender_hooks": ["the_crew"]}
	preview.pending_triggered_events = [preview._normalize_triggered_event_entry({"event_id": "crew_favor_delivery", "presentation": "talk", "speaker": {"name": "Velvet"}})]
	app.run_state = preview
	app._refresh_talk_dock()
	await _settle()
	_check(app.talk_dock.package_terms_scroll.is_visible_in_tree(), "real pending package pipeline exposes full terms under the candidate viewport")
	_check(app.talk_dock.package_terms_label.text.contains("Missing the window") and app.talk_dock.package_terms_label.text.contains("On delivery:"), "window penalties and delivery effects remain present")
	_check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(app.talk_dock.panel.get_global_rect()), "terms and dialogue panel fit the actual logical viewport")
	facts["terms"] = {"panel": app.talk_dock.panel.get_global_rect(), "scroll": app.talk_dock.package_terms_scroll.get_global_rect(), "maximum": app.talk_dock.package_terms_scroll.get_v_scroll_bar().max_value, "page": app.talk_dock.package_terms_scroll.get_v_scroll_bar().page}
	_check(app.talk_dock.package_terms_scroll.get_v_scroll_bar().max_value > app.talk_dock.package_terms_scroll.get_v_scroll_bar().page, "long synthetic terms create genuine overflow")
	app.run_state = run
	app.talk_dock.clear_entry()
	_check(_protected(run) == before, "dialogue presentation never alters the original generated run")
	phases.append("dialogue_terms")


func _dense_hud(run: RunState, before: PackedByteArray) -> void:
	var placement_before := var_to_bytes([run.current_environment.get("scenario_layout_authority", {}), run.current_environment.get("scenario_layout_base_records", [])])
	var previous := {"ui_scale": app.user_settings.ui_scale, "text_size": app.user_settings.text_size, "small": app.user_settings.play_on_small_screen}
	var dense := DenseHUDRun.new()
	dense.start_new("BTH31-SYNTHETIC-DENSE-DISPLAY-ONLY")
	var statuses: Array = []
	for index in range(6):
		statuses.append({"id": "synthetic_status_%d" % index, "icon": "alert", "tooltip": "Synthetic status %d" % index})
	facts["dense_HUD"] = []
	var scales: Array = [false, true] if Policy.portrait_layout(root.get_visible_rect().size) else [false]
	for maximum in scales:
		if maximum:
			app.user_settings.ui_scale = 1.3
			app.user_settings.text_size = "large"
			app.user_settings.play_on_small_screen = true
		app._apply_accessibility_settings()
		if maximum:
			_check(is_equal_approx(app._accessibility_font_scale(), 1.458) and app._accessibility_font_scale() <= 1.5, "dense portrait fixture exercises actual maximum supported font scale under the1.5 cap")
		# Produce the real strip synchronously, restoring the actual run reference
		# before a frame can advance. No physical action is requested or saved.
		app.run_state = dense
		# Use the normal writer's HUD-then-delivery order and deferred layout.
		app._render_embedded_action_hud_model({"bankroll": run.bankroll, "chips": run.grand_casino_chips, "show_chips": true,
			"heat_level": 37.0, "drunk_level": 22.0, "pending_drunk_absorption": 5.0, "status_icons": statuses, "game_clock_minutes": run.game_clock_minutes})
		app.run_state = run
		await _settle(16)
		_check(app.delivery_action_buttons.size() == 4, "dense HUD retains all four ordinary carried-package controls")
		_check(app.structured_hud.status_tray.get_child_count() == 6 and app.structured_hud.chips_chip.visible, "dense HUD retains six statuses and separate chip money")
		var controls: Array = [app.top_menu_button, app.top_settings_button, app.top_inventory_button, app.active_item_button]
		controls.append_array(app.delivery_action_buttons.values())
		var bounds: Array[Dictionary] = []
		for value in controls:
			var control := value as BaseButton
			var ancestor: Node = control.get_parent()
			while ancestor != null:
				if ancestor is ScrollContainer:
					ancestor.ensure_control_visible(control)
				ancestor = ancestor.get_parent()
			await _settle()
			_check(control.is_visible_in_tree() and app.run_hud_panel.get_global_rect().encloses(control.get_global_rect()) and Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(control.get_global_rect()), "dense HUD control remains reachable within its actual clipped panel: " + control.text)
			_check(not control.pressed.get_connections().is_empty(), "dense HUD retains connected callback: " + control.text)
			bounds.append({"text": control.text, "rect": control.get_global_rect(), "disabled": control.disabled})
		facts["dense_HUD"].append({"maximum_font": maximum, "font_scale": app._accessibility_font_scale(), "writer": "_render_embedded_action_hud_model", "panel": app.run_hud_panel.get_global_rect(), "strip": app.delivery_action_strip.get_global_rect(), "strip_minimum": app.delivery_action_strip.get_combined_minimum_size(), "layout_dirty": app.run_layout_dirty, "delivery_layout_deferred": app.delivery_action_layout_refresh_deferred, "controls": bounds})
		_check(_protected(run) == before, "dense display-only model preserves actual finance/time/history/jobs/RNG")
		if not maximum and OS.get_environment("BTH31_CASE") == "rotate":
			await _dense_hud_rotation_focus(run, before)
		if Policy.portrait_layout(root.get_visible_rect().size):
			var scroll := app.portrait_run_layout["scroll"] as ScrollContainer
			_check(scroll.is_visible_in_tree() and app.portrait_run_layout["hud_margin"].get_parent() == scroll, "portrait uses the real bounded HUD scroll viewport")
			_check(app.run_hud_panel.size.y <= floor(root.get_visible_rect().size.y * 0.55), "portrait HUD stays within its measured viewport budget")
			for child in app.delivery_action_strip.get_children():
				if child is Label:
					_check(child.custom_minimum_size.x < 390.0, "delivery heading wraps inside actual portrait width")
			await _hud_gestures(scroll, run, before)
			if maximum:
				if await _tap_control(app.top_inventory_button, "maximum-font HUD Inventory"):
					_check(app.run_inventory_overlay.visible, "maximum-font Inventory opens through the real control")
					_assert_inventory_portrait_bounds("maximum supported font")
					await _tap_control(_find_button(app.run_inventory_screen, "Close"), "maximum-font Inventory Close")
					_check(not app.run_inventory_overlay.visible and _protected(run) == before, "maximum-font neutral Inventory close preserves the generated run")
					phases.append("inventory_max_font")
	app.user_settings.ui_scale = previous["ui_scale"]
	app.user_settings.text_size = previous["text_size"]
	app.user_settings.play_on_small_screen = previous["small"]
	app._apply_accessibility_settings()
	app._refresh_delivery_action_strip()
	app.financial_hud_dirty = true
	app._refresh_financial_hud_if_dirty()
	await _settle()
	_check(_protected(run) == before, "dense HUD cleanup restores display without changing the generated run")
	_check(var_to_bytes([run.current_environment.get("scenario_layout_authority", {}), run.current_environment.get("scenario_layout_base_records", [])]) == placement_before, "dense HUD and scrolling preserve exact authoritative room placement")
	phases.append("dense_HUD_and_max_font")


func _dense_hud_rotation_focus(run: RunState, before: PackedByteArray) -> void:
	var target: Button = app.delivery_action_buttons.get("ditch") as Button
	if not _check(target != null, "actual dense HUD exposes its lower delivery focus target"):
		return
	var observations: Array[Dictionary] = []
	for requested in [Vector2i(844, 390), Vector2i(375, 667), Vector2i(1280, 720), Vector2i(390, 844)]:
		target.grab_focus()
		_check(root.gui_get_focus_owner() == target, "low delivery keyboard/controller focus established before actual rotation")
		root.size = requested
		await _settle(20)
		_check(root.gui_get_focus_owner() == target, "actual Main retains the same low delivery focus after rotation")
		_check(app.run_hud_panel.get_global_rect().encloses(target.get_global_rect()), "actual Main makes the focused low delivery control visible after settled rotation")
		if Policy.portrait_layout(root.get_visible_rect().size):
			var scroll: ScrollContainer = app.portrait_run_layout["scroll"]
			_check(scroll.get_global_rect().encloses(target.get_global_rect()), "actual Main focus target lies fully inside the portrait scroll viewport")
		_check(_protected(run) == before, "focused rotation never requests delivery or changes protected run state")
		observations.append({"requested_window": requested, "logical": root.content_scale_size, "HUD": app.run_hud_panel.get_global_rect(), "target": target.get_global_rect(), "focus_retained": root.gui_get_focus_owner() == target})
	facts["dense_HUD_rotation_focus"] = observations
	phases.append("dense_HUD_rotation_focus")


func _assert_inventory_portrait_bounds(context: String) -> void:
	if not Policy.portrait_layout(root.get_visible_rect().size):
		return
	var inventory: RunInventoryScreen = app.run_inventory_screen
	var panel_rect: Rect2 = inventory._panel.get_global_rect()
	_check(root.get_visible_rect().encloses(panel_rect), context + " Inventory panel fits the actual portrait viewport")
	_check(inventory._browse_toolbar.vertical, context + " Inventory toolbar retains every control in a vertical portrait layout")
	var parts: Array[Dictionary] = []
	for control in [inventory._close_button, inventory._search_input, inventory._filter_option, inventory._sort_option, inventory._items_scroll, inventory._detail_scroll]:
		_check(control.is_visible_in_tree() and panel_rect.encloses(control.get_global_rect()), context + " Inventory content/control remains inside its panel: " + control.get_class())
		parts.append({"class": control.get_class(), "rect": control.get_global_rect()})
	_check(root.gui_get_focus_owner() == inventory._close_button, context + " Inventory layout preserves its ordinary initial Close focus")
	if not facts.has("Inventory_portrait"):
		facts["Inventory_portrait"] = []
	facts["Inventory_portrait"].append({"context": context, "panel": panel_rect, "minimum": inventory._panel.get_combined_minimum_size(), "parts": parts})


func _center_hud_control(control: Control, scroll: ScrollContainer) -> Vector2:
	scroll.ensure_control_visible(control)
	await _settle()
	scroll.scroll_vertical += roundi(control.get_global_rect().get_center().y - scroll.get_global_rect().get_center().y)
	await _settle()
	_check(scroll.get_global_rect().encloses(control.get_global_rect()), "HUD gesture target is fully visible before real input")
	return control.get_global_rect().get_center()


func _hud_gestures(scroll: ScrollContainer, run: RunState, before: PackedByteArray) -> void:
	var button := app.delivery_action_buttons.get("wait") as Button
	if not _check(button != null, "real delivery producer exposes the synthetic gesture target"):
		return
	app.observe_delivery_only = true
	app.observed_delivery.clear()
	var point := await _center_hud_control(button, scroll)
	await _touch(root.get_final_transform() * point, true)
	_check(app.observed_delivery.is_empty(), "HUD delivery waits for a completed touch")
	await _touch(root.get_final_transform() * point, false, true)
	_check(app.observed_delivery.is_empty(), "OS canceled HUD touch cannot request a delivery action")
	var before_scroll := scroll.scroll_vertical
	var has_overflow := scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page
	var drag_positions: Array = []
	var drag_geometry: Dictionary = {}
	if has_overflow:
		point = await _center_hud_control(button, scroll)
		before_scroll = scroll.scroll_vertical
		var bar: VScrollBar = scroll.get_v_scroll_bar()
		# R9 actual Main proved offset19 was already max483-page464. Choose
		# available travel and keep the stroke inside the moved button/viewport.
		var lower: float = bar.min_value
		var upper: float = maxf(lower, bar.max_value - bar.page)
		var upward_room: float = maxf(0.0, float(before_scroll) - lower)
		var downward_room: float = maxf(0.0, upper - float(before_scroll))
		var direction: float = 1.0 if upward_room >= downward_room else -1.0
		var travel_room: float = upward_room if direction > 0.0 else downward_room
		var view_rect: Rect2 = scroll.get_global_rect()
		var button_rect: Rect2 = button.get_global_rect()
		var edge_room: float = view_rect.end.y - point.y if direction > 0.0 else point.y - view_rect.position.y
		var distance: float = maxf(0.0, minf(30.0, minf(edge_room - 2.0, travel_room + button_rect.size.y * 0.5 - 2.0)))
		var effective_deadzone: float = maxf(float(scroll.scroll_deadzone), float(ProjectSettings.get_setting("gui/common/default_scroll_deadzone", 0)))
		_check(travel_room > 0.0 and distance > effective_deadzone, "HUD drag has available scroll travel and exceeds its actual deadzone")
		drag_geometry = {"minimum": bar.min_value, "maximum": bar.max_value, "page": bar.page,
			"upper_offset": maxf(bar.min_value, bar.max_value - bar.page), "start_offset": before_scroll,
			"start_point": point, "start_button": button.get_global_rect(), "view": scroll.get_global_rect(),
			"deadzone": scroll.scroll_deadzone, "project_deadzone": ProjectSettings.get_setting("gui/common/default_scroll_deadzone", null),
			"direction": direction, "distance": distance, "available_travel": travel_room, "intended_release": point + Vector2(0, direction * distance)}
		print("BTH31_HUD_DRAG_BEFORE ", JSON.stringify(drag_geometry))
		await _touch(root.get_final_transform() * point, true)
		for index in range(1, 7):
			var event := InputEventScreenDrag.new()
			event.index = 0
			event.position = root.get_final_transform() * (point + Vector2(0, direction * distance * index / 6.0))
			event.relative = root.get_final_transform().basis_xform(Vector2(0, direction * distance / 6.0))
			event.screen_relative = event.relative
			Input.parse_input_event(event)
			await process_frame
			drag_positions.append(scroll.scroll_vertical)
		_check(scroll.scroll_vertical != before_scroll, "touch drag starting on delivery button genuinely scrolls the HUD")
		var release := point + Vector2(0, direction * distance)
		drag_geometry["release"] = release
		drag_geometry["end_offset"] = scroll.scroll_vertical
		drag_geometry["end_button"] = button.get_global_rect()
		_check(button.get_global_rect().has_point(release) and scroll.get_global_rect().has_point(release), "HUD drag releases over the moved button inside its viewport")
		await _touch(root.get_final_transform() * release, false)
		_check(app.observed_delivery.is_empty(), "HUD scroll gesture cannot request a delivery action")
		await _settle(30)
	point = await _center_hud_control(button, scroll)
	await _touch(root.get_final_transform() * point, true)
	await _touch(root.get_final_transform() * point, false)
	_check(app.observed_delivery == ["wait"], "fresh deliberate HUD tap reaches the existing delivery callback exactly once")
	app.observe_delivery_only = false
	var time_count := [0]
	var time_callback := func(): time_count[0] += 1
	app.structured_hud.time_requested.connect(time_callback)
	var previous_detail: bool = app.structured_hud.time_detail.visible
	point = await _center_hud_control(app.structured_hud.time_button, scroll)
	await _touch(root.get_final_transform() * point, true)
	await _touch(root.get_final_transform() * point, false, true)
	_check(time_count[0] == 0 and app.structured_hud.time_detail.visible == previous_detail, "OS canceled time touch cannot toggle hidden HUD detail")
	await _touch(root.get_final_transform() * point, true)
	await _touch(root.get_final_transform() * point, false)
	_check(time_count[0] == 1 and app.structured_hud.time_detail.visible != previous_detail, "fresh time tap preserves its ordinary visible-detail action")
	point = await _center_hud_control(app.structured_hud.time_button, scroll)
	await _touch(root.get_final_transform() * point, true)
	await _touch(root.get_final_transform() * point, false)
	_check(time_count[0] == 2 and app.structured_hud.time_detail.visible == previous_detail, "second time tap restores the same HUD detail state")
	app.structured_hud.time_requested.disconnect(time_callback)
	_check(_protected(run) == before, "actual HUD gesture routing never invokes payment or changes time/history/jobs/RNG")
	if not facts.has("HUD_gestures"):
		facts["HUD_gestures"] = []
	facts["HUD_gestures"].append({"overflow": has_overflow, "before_scroll": before_scroll, "drag_positions": drag_positions, "drag_geometry": drag_geometry, "synthetic_delivery_callbacks": app.observed_delivery.duplicate(), "time_callbacks": time_count[0]})
	if not phases.has("HUD_scroll_gestures"):
		phases.append("HUD_scroll_gestures")


func _title_fractional_minima() -> void:
	var previous := {"ui_scale": app.user_settings.ui_scale, "text_size": app.user_settings.text_size, "small": app.user_settings.play_on_small_screen}
	var previous_window: Vector2i = root.size
	var protected_before: PackedByteArray = _protected(app.run_state)
	app.user_settings.play_on_small_screen = false
	app.user_settings.ui_scale = 1.15
	app.user_settings.text_size = "normal"
	app._apply_accessibility_settings()
	await _settle()
	_check(is_equal_approx(app.new_run_button.custom_minimum_size.y, 122.0), "fractional1.15 scale rounds portrait106px minimum upward to122")
	var base: Vector2 = app.new_run_button.get_meta(app.ACCESSIBILITY_BASE_MIN_SIZE_META)
	_check(base.y == 106.0, "fractional portrait scale keeps unscaled metadata")
	app._apply_accessibility_settings()
	await _settle()
	_check(is_equal_approx(app.new_run_button.custom_minimum_size.y, 122.0), "reapplying accessibility does not compound portrait rounding")
	root.size = Vector2i(844, 390)
	await _settle(16)
	_check(is_equal_approx(app.new_run_button.custom_minimum_size.y, 121.9), "landscape restores the exact original unrounded accessibility height")
	root.size = previous_window
	await _settle(16)
	_check(is_equal_approx(app.new_run_button.custom_minimum_size.y, 122.0), "returning to portrait recomputes whole-pixel height from the original base")
	app.user_settings.ui_scale = previous["ui_scale"]
	app.user_settings.text_size = previous["text_size"]
	app.user_settings.play_on_small_screen = previous["small"]
	app._apply_accessibility_settings()
	await _settle()
	_check(_protected(app.run_state) == protected_before, "title fractional/layout regression changes no finance/time/history/jobs/RNG")
	base = app.new_run_button.get_meta(app.ACCESSIBILITY_BASE_MIN_SIZE_META)
	_check(base.y == 106.0, "original title metadata remains unchanged after full restore")
	phases.append("title_fractional_minima")


func _rotation() -> void:
	var before := _protected(app.run_state)
	var placements := var_to_bytes([app.run_state.current_environment.get("scenario_layout_authority", {}), app.run_state.current_environment.get("scenario_layout_base_records", [])])
	var original_buttons := [app.new_run_button.get_instance_id(), app.top_menu_button.get_instance_id(), app.run_menu_save_button.get_instance_id()]
	for size in [Vector2i(844, 390), Vector2i(375, 667), Vector2i(1280, 720), Vector2i(390, 844)]:
		# Establish eligible keyboard/controller focus, then test the real resize;
		# this does not stand in for any of the separate pointer-routing checks.
		app.top_menu_button.grab_focus()
		_check(root.gui_get_focus_owner() == app.top_menu_button, "HUD keyboard/controller focus exists before orientation switch")
		root.size = size
		await _settle(16)
		_check(root.gui_get_focus_owner() == app.top_menu_button, "actual orientation reparenting preserves the same eligible HUD focus")
		_check(root.content_scale_size == Policy.target_size(size, true), "real size_changed policy handles rotation")
		_check([app.new_run_button.get_instance_id(), app.top_menu_button.get_instance_id(), app.run_menu_save_button.get_instance_id()] == original_buttons, "rotation preserves existing controls and callbacks")
		_check(_protected(app.run_state) == before, "rotation preserves finance/time/history/jobs/RNG")
		_check(var_to_bytes([app.run_state.current_environment.get("scenario_layout_authority", {}), app.run_state.current_environment.get("scenario_layout_base_records", [])]) == placements, "rotation preserves authoritative placement records")
		if size.x >= size.y:
			_check(app.new_run_button.custom_minimum_size.x == 608.0 and app.structured_hud.run_bar is HBoxContainer, "landscape restores original menu minimum and HUD row")
			_check(not app.portrait_run_layout["scroll"].visible and app.portrait_run_layout["hud_margin"].get_parent() == app.run_hud_panel, "landscape restores the original unscrolled HUD parent")
		if not await _tap_control(app.top_menu_button, "Menu after rotation"):
			return
		if not await _tap_control(app.run_menu_resume_button, "Resume after rotation"):
			return
	phases.append("rotation")


func _run() -> void:
	var private_root := OS.get_environment("BTH31_PRIVATE_ROOT")
	if private_root.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(private_root + "/"):
		quit(2)
		return
	original_size = root.size
	original_scale = root.content_scale_size
	var mode := OS.get_environment("BTH31_CASE")
	if mode == "title390":
		# Fresh synthetic preference file, loaded normally by Main. This isolates
		# cold's loaded-small-screen ordering without reusing a failed root/key.
		var prepared_settings: UserSettings = PhoneSettings.new()
		prepared_settings.play_on_small_screen = true
		_check(prepared_settings.save() == OK, "synthetic small-screen preference saved before ordinary Main startup")
	if mode == "policy":
		_policy()
	else:
		var sizes := {"portrait390": Vector2i(390, 844), "portrait375": Vector2i(375, 667), "landscape844": Vector2i(844, 390), "desktop1280": Vector2i(1280, 720), "cold390": Vector2i(390, 844), "rotate": Vector2i(390, 844), "title390": Vector2i(390, 844)}
		if _check(sizes.has(mode), "explicit bounded viewport case required"):
			if await _startup_and_continue(sizes[mode], mode == "cold390"):
				if mode != "title390":
					await _run_controls()
				else:
					await _title_fractional_minima()
				if mode == "rotate" and failures.is_empty():
					await _rotation()
	if app != null:
		app.queue_free()
		await _settle()
	if observer != null:
		observer.queue_free()
		await process_frame
	root.size = original_size
	root.content_scale_size = original_scale
	var result := {"task_id": "BTH-31", "mode": mode, "checks": checks, "failures": failures, "completed_phases": phases, "facts": facts,
		"fidelity": "Native authored Main scene and actual candidate root policy; mobile platform predicate/physical native window settings substituted. During dense HUD gesture checks only, delivery callbacks are recorded instead of invoking settlement; outside that flag the original method remains in use. Normal synthetic generated run and same-resident-key Save/Continue. Real engine touch dispatch, not direct _gui_input or pressed.emit. Package terms use a separate unsaved synthetic route. No original campaign/profile/key copying; actual Web/physical phone remains unqualified."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("BTH31_WHOLE_APP ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
