extends "res://tests/ending_solvers/ending_solver/player_run_solver.gd"

const DuelPolicy := preload("res://tests/ending_solvers/rourke_solver/rourke_duel_policy.gd")
const RouteProgression := preload("res://tests/ending_solvers/ending_solver/route_progression.gd")
const PULL_TAB_SCAN := "pull_tab_detector_scan"
const PULL_TAB_MAX_PEEKS := 4
const PULL_TAB_MAX_DECISIONS := 40
const PULL_TAB_MAX_WAITS := 8

enum BarredTableCheck { NONE, BACK_SENT, FLOOR_SEEN }

var progression := RouteProgression.new()
var barred_table_check := BarredTableCheck.NONE
var pull_tab_decisions := 0
var pull_tab_waits := 0
var pull_tab_peeks := 0
var pull_tab_pending_heat := -1
var pull_tab_back_sent := false
var pull_tab_checked_floor := false
var pull_tab_recovery_done := false


func observe() -> Dictionary:
	var view := super.observe()
	if not _at_main_floor_pull_tabs(view) or OpeningPolicy.surface_action(view, [PULL_TAB_SCAN]).is_empty():
		return view
	var canvas := app.get("game_surface_canvas") as Control
	var surface: Dictionary = canvas.call("realtime_surface_state")
	var items: Dictionary = surface.get("pull_tab_item_state", {})
	# Mirror the label on this rendered cabinet control. Do not expose ticket contents.
	var game: Dictionary = view["game"]
	if bool(items.get("tab_detector_available", false)):
		game["pull_tab_scan_label"] = "SCAN"
	elif bool(canvas.call("surface_native_action_selected", PULL_TAB_SCAN)):
		game["pull_tab_scan_label"] = "CONFIRM"
	else:
		game["pull_tab_scan_label"] = "PEEK"
	return view


func _configure_progression(id: String) -> void:
	progression.configure(_target_ending(), id)


func _ending_command(view: Dictionary) -> String:
	var alternate := progression.decide_rourke(view)
	if not alternate.is_empty():
		return alternate
	var duel := DuelPolicy.decide(view, active_policy)
	if not duel.is_empty():
		return duel
	var recovery := _pull_tab_recovery_command(view)
	return recovery if not recovery.is_empty() else opening.decide(view)


func _record_ending_input(command: String, view: Dictionary) -> void:
	progression.record_input(command, view)
	if _at_main_floor_blackjack(view) and view.get("game", {}).get("phase") == "barred" \
			and command == OpeningPolicy.surface_action(view, ["surface_back", "leave_game"]):
		barred_table_check = BarredTableCheck.BACK_SENT
	if barred_table_check != BarredTableCheck.FLOOR_SEEN:
		return
	pull_tab_waits = 0
	if not _at_main_floor_pull_tabs(view):
		return
	if command == OpeningPolicy.surface_action(view, ["surface_back", "leave_game"]):
		pull_tab_back_sent = true
	elif command == OpeningPolicy.surface_action(view, [PULL_TAB_SCAN]) \
			and view.get("game", {}).get("pull_tab_scan_label") == "CONFIRM":
		pull_tab_pending_heat = _visible_heat(view)
		pull_tab_peeks += 1
		if not requested_route.is_empty():
			route_signature.append("pull_tabs:peek")


func _ending_stop_reason(view: Dictionary) -> String:
	if barred_table_check == BarredTableCheck.NONE:
		return ""
	var screen: Dictionary = view.get("screen", {})
	if _bar_recovery_view_blocked(view):
		return ""
	# Allow the opening policy to inspect the floor and follow The House Calls before checking the seat again.
	if screen.get("screen") in ["ENVIRONMENT", "RESULT"] \
			and view.get("environment", {}).get("archetype_id") == "grand_casino":
		barred_table_check = BarredTableCheck.FLOOR_SEEN
		if pull_tab_back_sent:
			pull_tab_checked_floor = true
			pull_tab_back_sent = false
			pull_tab_pending_heat = -1
		return ""
	if _at_main_floor_pull_tabs(view) and (pull_tab_waits >= PULL_TAB_MAX_WAITS * 2 \
			or pull_tab_decisions >= PULL_TAB_MAX_DECISIONS + PULL_TAB_MAX_WAITS):
		return "Grand Casino Blackjack was barred and Pull Tabs recovery could not return to the floor."
	if barred_table_check != BarredTableCheck.FLOOR_SEEN or not _at_main_floor_blackjack(view):
		return ""
	if OpeningPolicy.surface_action(view, ["surface_back", "leave_game"]).is_empty():
		return ""
	if view.get("game", {}).get("phase") != "barred":
		barred_table_check = BarredTableCheck.NONE
		return ""
	if not OpeningPolicy.surface_action(view, ["ending.ack", "showdown_exit", "blackjack_retry_pending"]).is_empty():
		return ""
	return "Grand Casino Main Floor Blackjack stayed barred after leaving and returning."


func _pull_tab_recovery_command(view: Dictionary) -> String:
	if barred_table_check != BarredTableCheck.FLOOR_SEEN or _bar_recovery_view_blocked(view) \
			or view.get("environment", {}).get("archetype_id") != "grand_casino":
		return ""
	var at_cabinet := _at_main_floor_pull_tabs(view)
	var screen_id := str(view.get("screen", {}).get("screen", ""))
	if not at_cabinet and (screen_id not in ["ENVIRONMENT", "RESULT"] \
			or (screen_id == "RESULT" and not opening.result_normalized)):
		return ""
	var heat := _visible_heat(view)
	if pull_tab_decisions >= PULL_TAB_MAX_DECISIONS or pull_tab_waits >= PULL_TAB_MAX_WAITS \
			or heat >= 95:
		pull_tab_recovery_done = true
	if at_cabinet:
		var back := OpeningPolicy.surface_action(view, ["surface_back", "leave_game"])
		if pull_tab_recovery_done or pull_tab_back_sent or (heat >= 85 and not pull_tab_checked_floor):
			return _pull_tab_step(back)
		if heat < 0 or (pull_tab_pending_heat >= 0 and heat == pull_tab_pending_heat):
			return _pull_tab_step("")
		pull_tab_pending_heat = -1
		var label := str(view.get("game", {}).get("pull_tab_scan_label", ""))
		if label == "SCAN" or pull_tab_peeks >= PULL_TAB_MAX_PEEKS:
			pull_tab_recovery_done = true
			return _pull_tab_step(back)
		return _pull_tab_step(OpeningPolicy.surface_action(view, [PULL_TAB_SCAN]) if label in ["PEEK", "CONFIRM"] else "")
	if pull_tab_recovery_done:
		return ""
	var house_calls := opening.room_object(view, "event:the_house_calls", ["Follow Rourke", "Open", "Answer"])
	if house_calls.is_empty():
		house_calls = OpeningPolicy.button(view, ["The House Calls: Follow Rourke"])
	if not house_calls.is_empty():
		return house_calls
	if heat >= 85:
		pull_tab_checked_floor = true
	var entry := opening.room_object(view, "game:pull_tabs", ["Enter", "Play"], ["Pull Tabs: Enter", "Pull Tabs: Play"])
	return _pull_tab_step(entry if heat >= 0 else "")


func _pull_tab_step(command: String) -> String:
	pull_tab_decisions += 1
	if command.is_empty() or command.begins_with("wait "):
		pull_tab_waits += 1
		return command if not command.is_empty() else "wait 16"
	return command


func _witness(view: Dictionary) -> Dictionary:
	var witness := super._witness(view)
	var label := str(view.get("game", {}).get("pull_tab_scan_label", ""))
	if not label.is_empty():
		witness["pull_tab_scan_label"] = label
	return witness


static func _visible_heat(view: Dictionary) -> int:
	var hud: Dictionary = view.get("status_hud", {})
	return int(hud.get("heat_level", 0)) if bool(hud.get("heat_rendered", false)) else -1


static func _bar_recovery_view_blocked(view: Dictionary) -> bool:
	var screen: Dictionary = view.get("screen", {})
	return (bool(screen.get("travel_transition_active", false)) or bool(screen.get("world_map_overlay_visible", false))
		or bool(view.get("spatial", {}).get("loading", false)) or bool(view.get("coach", {}).get("visible", false))
		or bool(view.get("event_popup", {}).get("visible", false)) or bool(view.get("talk", {}).get("visible", false)))


static func _at_main_floor_pull_tabs(view: Dictionary) -> bool:
	return (view.get("screen", {}).get("screen") == "GAME"
		and view.get("environment", {}).get("archetype_id") == "grand_casino"
		and view.get("game", {}).get("game_id") == "pull_tabs")


static func _at_main_floor_blackjack(view: Dictionary) -> bool:
	var game: Dictionary = view.get("game", {})
	return (view.get("screen", {}).get("screen") == "GAME"
		and view.get("environment", {}).get("archetype_id") == "grand_casino"
		and view.get("spatial", {}).get("selected_object_id") == "game:blackjack"
		and game.get("game_id") == "blackjack"
		and not bool(game.get("boss_duel_active", false)))


func _target_key() -> String:
	return "showdown_survived"


func _target_ending() -> String:
	return "rourke_duel"
