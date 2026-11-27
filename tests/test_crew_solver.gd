extends "res://tests/ending_solvers/crew_heist_solver/crew_heist_solver.gd"


func _boot() -> void:
	stage = Stage.CAMERA_WINDOW
	var bar := {"id": "bar", "delivery_target": true, "travel_enabled": false,
		"travel_disabled_reason": "Not on the route list from here right now."}
	var map := {"selected_node_id": "bar", "nodes": [bar, {"id": "small_underground_casino"},
		{"id": "back_alley"}, {"id": "grand_casino", "current": true}]}
	var view := {
		"environment": {"world_node_id": "grand_casino"},
		"screen": {"world_map_overlay_visible": true, "world_map": map},
		"clickable": {"buttons": [{"text": "Close", "id": "map_close", "enabled": true, "fully_visible": true}]},
	}
	if _travel(view, "", true) != "click_button map_close":
		push_error("A blocked Camera Window destination should close its fare preview.")
		quit(1)
		return
	map["selected_node_id"] = ""
	if _travel(view, "", true) != "click_map back_alley":
		push_error("The Bar Camera Window should approach from the Alley when direct travel is blocked.")
		quit(1)
		return
	var reserve_failure := _check_camera_reserve()
	if not reserve_failure.is_empty():
		push_error(reserve_failure)
		quit(1)
		return
	if not _check_return_recruitment():
		push_error("The return from a Camera Window should use only an available, unrecruited contact.")
		quit(1)
		return
	quit(0)


func _check_camera_reserve() -> String:
	camera_windows = 3
	camera_window_start_cash = 76
	camera_window_reward_cash = 89
	camera_travel_reserve = 133
	var hud := {"bankroll_rendered": true, "bankroll": 13}
	var view := {"status_hud": hud, "clickable": {"buttons": [
		{"text": "Casino ATM: Borrow $50", "id": "borrow", "enabled": true, "fully_visible": true},
	]}}
	if _camera_reserve_command(view, "grand_casino_cage") != "click_button borrow":
		return "A low balance must start with a single ATM draw."
	if not _camera_reserve_command(view, "grand_casino_cage").is_empty():
		return "A second ATM draw requires the first $50 to be visible in cash."
	hud["bankroll"] = 63
	if _camera_reserve_command(view, "grand_casino_cage") != "click_button borrow":
		return "One draw still leaves less than the last $76 return fare."
	hud["bankroll"] = 113
	if not _camera_reserve_command(view, "grand_casino_cage").is_empty():
		return "The reserve may take at most two draws per Camera Window."
	return ""


func _check_return_recruitment() -> bool:
	var lucky := "event:recruitment_lucky"
	var view := {"clickable": {"canvas_objects": [{"semantic_id": lucky, "enabled": true, "rendered": true}]}}
	if _earn_access(view, "motel") != "click_object " + lucky:
		return false
	if _earn_access(view, "small_underground_casino") == "click_object " + lucky:
		return false
	recruited_members.append("lucky")
	return _visible_recruitment(view).is_empty()
