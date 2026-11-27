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
	quit(0)
