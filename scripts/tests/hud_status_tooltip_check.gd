extends SceneTree

const Model := preload("res://scripts/ui/foundation_hud_view_model.gd")
const Hud := preload("res://scripts/ui/foundation_hud_bar.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func friendly(text: String) -> String:
	return text.replace("RAW_LENDER", "The Crew")

func project(items: Array) -> Dictionary:
	# Synthetic projection of the same complete debt lines passed by the host.
	# This is not a debt action, authority fixture or Web rendering check.
	return Model.run_status_model(RunState.new(), {"debt_items":items, "player_facing_text":Callable(self, "friendly")})

func debt_icon(model: Dictionary) -> Dictionary:
	for status in model.get("status_icons", []):
		if str(status.get("id", "")) == "debt": return status
	return {}

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var lines := [
		"The Crew wants 1 favor, due in 1 turn (Active)",
		"The Crew wants 1 favor, favor due now (Favor Due)",
		"Nico balance 22, due in 4 turns (Active)",
		"Sal holds Trunk; borrowed 68, buy-back 85, due in 5 turns (Active)",
	]
	for text in lines:
		check(str(debt_icon(project([text])).get("tooltip", "")) == text, "HUD tooltip truncates debt details: " + text)
	var multiple := [lines[0], lines[2]]
	var original := multiple.duplicate()
	check(str(debt_icon(project(multiple)).get("tooltip", "")) == "\n".join(multiple), "Multiple debt deadlines are replaced with a count.")
	check(multiple == original, "Debt projection mutates its input.")
	check(str(debt_icon(project([" RAW_LENDER wants 1 favor, due in 1 turn (Active) "])).get("tooltip", "")) == lines[0], "Full tooltip skips player-facing normalization.")
	check(debt_icon(project([])).is_empty(), "Debt badge appears without debt.")
	check(Model.hud_debt_text([lines[0]], Callable()) == "The Crew wants 1 favor, due...", "Compact HUD summary unexpectedly changed.")
	var hud := Hud.new()
	root.add_child(hud)
	await process_frame
	var statuses: Array = project([lines[0]])["status_icons"]
	hud.call("_render_status_icons", statuses)
	await process_frame
	check(hud.status_tray.get_child(0).tooltip_text == lines[0], "Model-to-HUD path loses the full deadline.")
	var original_id := hud.status_tray.get_child(0).get_instance_id()
	hud.call("_render_status_icons", statuses)
	check(hud.status_tray.get_child(0).get_instance_id() == original_id, "Unchanged status unnecessarily rebuilds the hovered icon.")
	hud.call("_render_status_icons", project([lines[1]])["status_icons"])
	await process_frame
	check(hud.status_tray.get_child(0).tooltip_text == lines[1], "Updated due status retains stale text.")
	hud.queue_free()
	for failure in failures: push_error(failure)
	print("HUD debt tooltip projection checks: ", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
