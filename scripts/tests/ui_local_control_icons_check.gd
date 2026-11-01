extends SceneTree

# Synthetic presentation checks only: never boot a profile, load a save or open
# a game. Signal emissions below verify routing, not physical mobile taps.
const Art := preload("res://scripts/ui/ui_art.gd")
const Widgets := preload("res://scripts/ui/foundation_widgets.gd")
const Inventory := preload("res://scripts/ui/inventory_container_surface.gd")
const Report := preload("res://scripts/ui/run_report_screen.gd")
const Hud := preload("res://scripts/ui/foundation_hud_bar.gd")
const Money := preload("res://scripts/ui/money_feedback_view_model.gd")
const SmallScreen := preload("res://scripts/ui/small_screen_policy.gd")

class MenuOnly:
	extends "res://scripts/ui/foundation_main.gd"
	var settings_requests := 0
	var setup_requests := 0

	func _ready() -> void:
		pass

	func _ensure_main_menu_background_built() -> void:
		pass

	func open_settings_menu() -> void:
		settings_requests += 1

	func toggle_run_configuration() -> void:
		setup_requests += 1


var failures: Array[String] = []
var checks := 0
var activations := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_assets()
	_check_button_contract()
	_check_menu_routing()
	_check_inventory()
	_check_report()
	_check_chip_feedback()
	for failure in failures:
		push_error(failure)
	print("UI_LOCAL_CONTROL_ICONS %s checks=%d failures=%d physical_touch_verified=false" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _check_assets() -> void:
	var ids := ["settings", "run_setup", "close", "previous", "next", "decrease", "increase", "play", "replay", "selected", "focused", "hovered", "cash_transfer"]
	_check(Art.CONTROL_ICONS.size() == ids.size(), "Control asset inventory changed unexpectedly.")
	for icon_id in ids:
		var texture: Texture2D = Art.control_icon(icon_id)
		_check(texture != null, "Missing bundled control icon: " + icon_id)
		if texture == null:
			continue
		var path := "res://assets/art/ui/icons/controls/%s.svg" % icon_id
		_check(texture.resource_path == path and Art.expected_runtime_paths().has(path), "Control asset is not in the local export dependency set: " + icon_id)
		_check(texture.get_size() == Vector2(32, 32), "Unexpected control icon dimensions: " + icon_id)
		var image := texture.get_image()
		_check(image != null and not image.is_empty(), "Imported control icon has no pixels: " + icon_id)
		if image == null or image.is_empty():
			continue
		var painted := false
		var transparent := false
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var alpha := image.get_pixel(x, y).a
				painted = painted or alpha > 0.5
				transparent = transparent or alpha < 0.01
		_check(painted and transparent, "Control icon must contain visible art on transparency: " + icon_id)


func _check_button_contract() -> void:
	var button := Widgets.button("Original", func() -> void: activations += 1)
	button.custom_minimum_size = Vector2(52, 52)
	button.tooltip_text = "Original help"
	button.disabled = true
	var original_focus := button.focus_mode
	var original_mouse_filter := button.mouse_filter
	Art.apply_control_icon(button, "settings", "Settings", 24, true)
	_check_icon_button(button, "settings", "Settings")
	_check(button.custom_minimum_size == Vector2(52, 52) and button.disabled, "Applying art changed the existing target or enabled state.")
	_check(button.focus_mode == original_focus and button.mouse_filter == original_mouse_filter and button.get_child_count() == 0, "Applying art changed focus or added an input overlay.")
	_check(button.tooltip_text == "Original help", "Applying art lost existing help.")
	button.disabled = false
	button.pressed.emit()
	_check(activations == 1 and button.pressed.get_connections().size() == 1, "Applying art changed signal routing.")
	Art.apply_control_icon(button, "unknown-id", "Settings", 24, true)
	_check(button.icon == null and button.text == "Settings", "Unknown asset IDs must fall back to readable ordinary text.")
	button.free()


func _check_menu_routing() -> void:
	# Construct shipped controls without attaching the application to a tree:
	# FoundationMain._ready (profile/session startup) is never called.
	var app := MenuOnly.new()
	app.start_screen = Control.new()
	app.add_child(app.start_screen)
	app.call("_build_start_screen")
	_check_icon_button(app.settings_button, "settings", "Settings")
	_check_icon_button(app.exit_game_button, "close", "Exit Game")
	_check(app.settings_button.custom_minimum_size == Vector2(48, 48), "Settings target changed size.")
	_check(app.run_config_button.text == "RUN SETUP" and app.run_config_button.icon == Art.control_icon("run_setup"), "Run setup must keep its label alongside local art.")
	_check(app.run_config_button.custom_minimum_size == Vector2(296, 106), "Run setup target changed size.")
	app.settings_button.pressed.emit()
	app.run_config_button.pressed.emit()
	_check(app.settings_requests == 1 and app.setup_requests == 1, "Menu icon controls no longer route one activation to the original actions.")
	_check(app.exit_game_button.pressed.is_connected(Callable(app, "exit_game")), "Exit icon lost its original action.")
	app.free()


func _check_inventory() -> void:
	for grouped in [false, true]:
		var surface := Inventory.new()
		surface.size = Vector2(360, 420)
		var model := {
			"selected_key": "one", "active_container_key": "first",
			"layout": {"presentation": "grouped_card_grid" if grouped else ""},
			"containers": [
				{"key": "first", "container_type": "loose_carry", "capacity": 1, "slots": [{"occupied": true, "selection_key": "one", "state_marker": "2", "item": {"display_name": "Synthetic item"}}]},
				{"key": "second", "container_type": "loose_carry", "capacity": 1, "slots": []},
			],
		}
		surface.update_model(model)
		var previous := surface.get("_previous_button") as Button
		var next := surface.get("_next_button") as Button
		_check_icon_button(previous, "previous", "Previous container")
		_check_icon_button(next, "next", "Next container")
		surface.set_small_screen_mode(true)
		_check(previous.custom_minimum_size.y >= SmallScreen.CONTROL_TOUCH_TARGET_HEIGHT and next.custom_minimum_size.y >= SmallScreen.CONTROL_TOUCH_TARGET_HEIGHT, "Inventory lost its small-screen target height.")
		var marker := (surface.get("_slot_markers") as Array)[0] as Label
		var cue := marker.get_node("StateCue") as TextureRect
		_check(marker.text == "2" and cue.texture == Art.control_icon("selected"), "Selection art must retain the ordinary trade-position numeral.")
		_check(cue.mouse_filter == Control.MOUSE_FILTER_IGNORE and marker.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Selection art must not intercept item taps.")
		for state in ["focused", "hovered", ""]:
			surface.call("_set_slot_marker", marker, state, "2", Color.WHITE)
			_check(cue.texture == Art.control_icon(state) and cue.visible == (state != "") and marker.text == "2", "Inventory state cue failed: " + state)
		next.pressed.emit()
		_check(surface.active_container_key() == "second", "Next asset button did not preserve its +1 binding.")
		previous.pressed.emit()
		_check(surface.active_container_key() == "first", "Previous asset button did not preserve its -1 binding.")
		surface.free()


func _check_report() -> void:
	var report := Report.new()
	report.set_report({})
	_check(report.play_button.text == "Play" and report.play_button.icon == Art.control_icon("play"), "Report Play still depends on a glyph.")
	_check(report.play_button.custom_minimum_size == Vector2(104, 38), "Report target changed size.")
	report.play_button.pressed.emit()
	_check(report.replay_playing and report.play_button.icon == Art.control_icon("play"), "Report Play lost its original action.")
	report.call("_on_timeline_seek", 1.0)
	_check(report.play_button.text == "Replay" and report.play_button.icon == Art.control_icon("replay"), "Completed replay did not use local replay art.")
	report.call("_on_timeline_seek", 0.5)
	_check(report.play_button.text == "Continue" and report.play_button.icon == Art.control_icon("play"), "Seeking did not retain local Play art.")
	report.set_reduce_motion(true)
	_check(not report.play_button.visible and report.play_button.disabled and not report.replay_playing, "Icon replacement changed reduced-motion replay behavior.")
	report.free()


func _check_chip_feedback() -> void:
	var hud := Hud.new()
	hud.call("_build")
	hud.present_money_feedback(Money.build({"chips": 3}))
	_check(hud.wallet_delta.text == "+3 chips", "Chip feedback lost its readable currency unit.")
	_check(hud.wallet_delta_icon.visible and hud.wallet_delta_icon.texture == Art.icon("casino_chips"), "Chip feedback did not reuse bundled chip art.")
	_check(hud.wallet_delta_icon.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Chip art must not intercept HUD taps.")
	hud.reset_wallet_delta()
	hud.present_money_feedback(Money.build({"cash": 4}))
	_check(hud.wallet_delta.text == "+$4" and not hud.wallet_delta_icon.visible, "Cash feedback acquired an incorrect chip icon.")
	hud.free()


func _check_icon_button(button: Button, icon_id: String, accessible_label: String) -> void:
	_check(button.icon == Art.control_icon(icon_id) and button.icon != null and button.text.is_empty(), "Missing icon-only control art: " + icon_id)
	_check(button.accessibility_name == accessible_label and not button.tooltip_text.is_empty(), "Missing accessible name/help: " + icon_id)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
