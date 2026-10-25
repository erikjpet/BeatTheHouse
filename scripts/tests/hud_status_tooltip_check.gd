extends SceneTree

const Hud := preload("res://scripts/ui/foundation_hud_bar.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	# Synthetic UI records matching the clipped normal Web debt badge. This
	# checks tooltip layout, not a game action or debt/accounting authority.
	root.size = Vector2i(1280, 720)
	var hud := Hud.new()
	root.add_child(hud)
	await process_frame
	var text := "The Crew wants 1 favor, due in 1 turn (Active)"
	var statuses := [{"id":"debt", "icon":"debt", "tooltip":text}]
	hud.call("_render_status_icons", statuses)
	await process_frame
	var icon: Control = hud.status_tray.get_child(0)
	check(icon.tooltip_text == text, "Debt schedule was shortened before tooltip rendering.")
	var original_id := icon.get_instance_id()
	hud.call("_render_status_icons", statuses)
	check(hud.status_tray.get_child(0).get_instance_id() == original_id, "Unchanged statuses unnecessarily rebuilt the hovered icon.")
	check(icon.has_method("_make_custom_tooltip"), "HUD status uses an unwrapped default tooltip that clips the due date.")
	if icon.has_method("_make_custom_tooltip"):
		var popup: Control = icon.call("_make_custom_tooltip", text)
		root.add_child(popup)
		for frame in range(3): await process_frame
		var label: Label = popup.get_child(0)
		check(label.text == text, "Tooltip lost part of the debt schedule or status.")
		check(label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Tooltip does not wrap complete words.")
		check(popup.size.x <= VisualStyle.TOOLTIP_MAX_WIDTH + 1.0, "Tooltip exceeds the existing bounded width.")
		var text_width := label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		check(label.get_line_count() > 1 or label.size.x >= text_width, "Debt summary does not fit its rendered line.")
		check(popup.size.y >= label.get_minimum_size().y, "Tooltip height clips wrapped lines.")
		popup.queue_free()
	var replacement := "A very long lender name wants 12 favors, next pressure in 123 turns (Overdue)"
	hud.call("_render_status_icons", [{"id":"debt", "icon":"debt", "tooltip":replacement}])
	await process_frame
	var updated_icon: Control = hud.status_tray.get_child(0)
	check(updated_icon.tooltip_text == replacement, "Changed debt schedule retained stale tooltip text.")
	if updated_icon.has_method("_make_custom_tooltip"):
		var popup: Control = updated_icon.call("_make_custom_tooltip", replacement)
		root.add_child(popup)
		for frame in range(3): await process_frame
		var label: Label = popup.get_child(0)
		check(label.text == replacement and label.get_line_count() > 1, "Long lender and schedule do not wrap in full.")
		check(popup.size.y >= label.get_minimum_size().y, "Long lender schedule is cut off vertically.")
		popup.queue_free()
	hud.queue_free()
	for failure in failures: push_error(failure)
	print("HUD status tooltip checks: ", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
