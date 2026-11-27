extends "res://tests/ending_solvers/ending_solver/player_run_solver.gd"

const WINNING_REPORTS := ["heist_clean_sweep", "heist_out_hot", "heist_somebody_got_pinched"]
const COOLING_RESPONSES := {
	"eye_in_the_sky": "change_table",
	"blackjack_counter_probe": "play_dumb",
	"floor_staff_heat_warning": "play_cool",
	"pit_boss_heat_warning": "walk_now",
	"rival_counter": "tip_off",
	"whale_sighting": "fade",
	"dave_bus_warning": "acknowledge",
	"machine_jam": "wait",
	"the_collector": "promise",
}
const LIVE_CHOICES := ["go_hold", "distraction_sit", "exit_dock", "begin_getaway"]
const LIVE_STAKE := 8
const MAX_AUDIT_DAYS := 7
const CAMERA_WINDOW_REWARD := 30
const CAMERA_WINDOWS_FOR_PLANNING := 5
const RECRUITMENT_RESPONSES := {
	"switch": "work_with_switch",
	"mags": "work_with_mags",
	"knuckles": "work_with_knuckles",
	"velvet": "work_with_velvet",
	"lucky": "work_with_lucky",
}
const CAMERA_TRAVEL_RESERVE := 25
const CAMERA_TRAVEL_CUSHION := 10
const CAMERA_DETOUR_REMAINING_CASH := 20

enum Stage { AUDIT, ACCESS, CAMERA_WINDOW, PLAN, SCHEDULE, CART, LIVE, GETAWAY }

var stage := Stage.AUDIT
var last_checked_day := ""
var audit_days: Array[String] = []
var destination_rejections: Dictionary = {}
var obscured_delivery_object := ""
var previous_world_node := ""
var route_stop := ""
var bishop_recruited := false
var recruited_members: Array[String] = []
var bishop_room_rechecks := 0
var bishop_refresh_needed := false
var camera_windows := 0
var camera_window_start_cash := -1
var camera_travel_reserve := CAMERA_TRAVEL_RESERVE
var reserve_checked_window := -1
var last_hold_cash := -1
var camera_target := ""
var live_round := 0
var live_choice_made := false
var live_deal_sent := false
var live_repeat_attempted := false
var reopen_planning_table := false
var awaiting_schedule_presentation := false


func observe() -> Dictionary:
	var view := super.observe()
	var hud := app.get("structured_hud") as Control
	var day := hud.get("time_day_label") as Label if hud != null else null
	if _label_text_is_fully_rendered(day):
		view["crew_day"] = day.text
	var header := app.get("environment_header") as Control
	var signage := header.get("situation_label") as Label if header != null else null
	if _label_text_is_fully_rendered(signage):
		view["crew_situation"] = signage.text
	return view


func send(command: String) -> Dictionary:
	var input := await super.send(command)
	if (command.begins_with("click_object delivery:") and not bool(input.get("ok", false))
			and str(input.get("reason", "")).contains("not hittable")):
		obscured_delivery_object = command.trim_prefix("click_object ").trim_suffix(" double")
	return input


func _visible_map(screen: Dictionary, buttons: Array) -> void:
	var targets := {}
	for node: Dictionary in screen.get("world_map", {}).get("nodes", []):
		if bool(node.get("delivery_target", false)) and node.get("delivery_target_status") != "delivered":
			targets[node.get("id")] = true
	super._visible_map(screen, buttons)
	for node: Dictionary in screen.get("world_map", {}).get("nodes", []):
		if targets.has(node.get("id")):
			node["delivery_target"] = true


func _ending_command(view: Dictionary) -> String:
	var command := _choose_heist_command(view)
	if command.is_empty() or command != OpeningPolicy.button(view, ["Travel"]):
		return command
	var hud: Dictionary = view.get("status_hud", {})
	if not bool(hud.get("bankroll_rendered", false)):
		return command
	var map: Dictionary = view.get("screen", {}).get("world_map", {})
	var selected := str(map.get("selected_node_id", ""))
	for marker: Dictionary in map.get("nodes", []):
		var fare := int(marker.get("cost", 0))
		if marker.get("id") != selected or fare <= 0:
			continue
		var reserve := 1
		if stage == Stage.CAMERA_WINDOW and not bool(marker.get("delivery_target", false)):
			reserve = CAMERA_DETOUR_REMAINING_CASH
		if int(hud.get("bankroll", 0)) - fare < reserve:
			destination_rejections[selected] = "The fare would leave too little cash to continue."
			opening.map_rejections[selected] = true
			print("BTH_CREW_FARE_REJECTED ", JSON.stringify({"destination": selected, "fare": fare, "reserve": reserve}))
			return "wait 8"
	return command


func _choose_heist_command(view: Dictionary) -> String:
	var screen: Dictionary = view.get("screen", {})
	if stage == Stage.PLAN and screen.get("screen") == "EVENT":
		var planning_button := OpeningPolicy.button(view, ["Lock The Count", "Watch the schedule"])
		if not planning_button.is_empty():
			return planning_button
	if bool(screen.get("travel_transition_active", false)) or bool(view.get("spatial", {}).get("loading", false)):
		return "wait 16"
	var modal := _modal_command(view)
	if not modal.is_empty():
		return modal
	if screen.get("screen") == "GAME":
		return _live_game(view)
	var room: Dictionary = view.get("environment", {})
	var world_node := str(room.get("world_node_id", ""))
	if not world_node.is_empty() and world_node != previous_world_node:
		previous_world_node = world_node
		destination_rejections.clear()
	var archetype := str(room.get("archetype_id", ""))
	if archetype == "delta_queen" and opening.river_queen_walk_pending:
		return opening.room_object(view, "service:riverboat_deck_walk", ["Use"], ["Walk the Deck: Use"])
	match stage:
		Stage.AUDIT:
			return _search_audit(view, archetype)
		Stage.ACCESS:
			return _earn_access(view, archetype)
		Stage.CAMERA_WINDOW:
			return _camera_window(view, world_node)
		Stage.PLAN:
			return _plan_command(view, archetype)
		Stage.SCHEDULE:
			if awaiting_schedule_presentation:
				awaiting_schedule_presentation = false
				if view.get("spatial", {}).get("selected_object_id") == "event:crew_planning_table":
					return "click_blank_room"
				return "wait 16"
			if archetype == "grand_casino_cage":
				return _hold_sightline(view, world_node)
			if archetype == "grand_casino":
				return _grand_room(view, "grand_casino_cage", "Grand Casino Cage")
			var recovery := OpeningPolicy.button(view, ["Room unavailable - Return to casino"])
			if not recovery.is_empty():
				return recovery
			if (archetype == "small_underground_casino" and not bool(screen.get("world_map_overlay_visible", false))
					and not _room_object_visible(view, "travel:leave") and not _room_object_visible(view, "environment_layer:casino")):
				return "key Left"
			if _room_object_visible(view, "environment_layer:casino") and not _room_object_visible(view, "travel:leave"):
				return opening.room_object(view, "environment_layer:casino", ["Enter Room"], ["Hidden Casino: Enter Room"])
			return _travel(view, "grand_casino", true)
		Stage.CART:
			if archetype == "grand_casino_cage":
				return _grand_room(view, "grand_casino", "Main Floor")
			var handoff := "crew::package_handoff"
			var direct_handoff := "delivery:handoff:" + world_node
			if _room_object_visible(view, direct_handoff) or direct_handoff == obscured_delivery_object:
				handoff = direct_handoff
			if handoff == obscured_delivery_object and view.get("spatial", {}).get("selected_object_id") != handoff:
				return "key Right"
			return opening.room_object(view, handoff, ["Hand Over The Package"], ["The Floor Contact: Hand Over The Package"])
		Stage.LIVE:
			if archetype != "grand_casino":
				route_stop = "the live table is no longer on Grand Main"
				return ""
			if live_choice_made:
				return opening.room_object(view, "game:blackjack", ["Enter", "Play"], ["Blackjack: Enter", "Blackjack: Play"])
			return opening.room_object(view, "event:heist_live_table", ["Hold", "Sit", "Dock", "Take the exit", "Open"], ["Live Table: Hold", "Live Table: Sit", "Live Table: Dock", "Live Table: Take the exit"])
		Stage.GETAWAY:
			return _travel(view, "delta_queen", true)
	return ""


func _search_audit(view: Dictionary, archetype: String) -> String:
	var day := str(view.get("crew_day", ""))
	if archetype == "grand_casino":
		if not day.is_empty() and day not in audit_days:
			audit_days.append(day)
			var objects := _witness(view).get("room_objects", []) as Array
			print("BTH_CREW_AUDIT " + JSON.stringify({
				"day": day, "signage": view.get("crew_situation", ""),
				"roster": _room_object_visible(view, "event:scenario_audit_roster"),
				"room_objects": objects,
			}))
		if _room_object_visible(view, "event:scenario_audit_roster") or str(view.get("crew_situation", "")).contains("EVERY DRAWER"):
			return opening.room_object(view, "event:scenario_audit_roster", ["Read the shift", "Open"], ["The Audit Roster: Read the shift"])
		if day.is_empty():
			return "wait 16"
		last_checked_day = day
		if audit_days.size() >= MAX_AUDIT_DAYS:
			route_stop = "no visible Audit window found within seven Grand Main day checks"
			return ""
	if not last_checked_day.is_empty() and day == last_checked_day:
		if str(view.get("environment", {}).get("kind", "")) == "home":
			return opening.room_object(view, "home_sleep:bed", ["Sleep"], ["Bed: Sleep"])
		return _travel(view, "home")
	if not last_checked_day.is_empty():
		return _travel(view, "grand_casino")
	return opening.decide(view)


func _earn_access(view: Dictionary, archetype: String) -> String:
	if archetype not in ["grand_casino", "grand_casino_cage"]:
		return _travel(view, "grand_casino")
	if not bishop_recruited:
		return opening.room_object(view, "event:recruitment_bishop", ["Talk"], ["Bishop: Talk"])
	var reserve := _camera_reserve_command(view, archetype)
	if not reserve.is_empty():
		return reserve
	if bishop_refresh_needed and archetype == "grand_casino":
		return _grand_room(view, "grand_casino_cage", "Grand Casino Cage")
	bishop_refresh_needed = false
	var contact := "event:crew_contact_bishop"
	if _room_object_visible(view, contact):
		return opening.room_object(view, contact, ["Talk"], ["Bishop: Talk"])
	if bishop_room_rechecks >= 6:
		route_stop = "Bishop's job contact did not appear after checking Grand Main and Cage"
		return ""
	if archetype == "grand_casino_cage":
		return _grand_room(view, "grand_casino", "Main Floor")
	return _grand_room(view, "grand_casino_cage", "Grand Casino Cage")


func _camera_reserve_command(view: Dictionary, archetype: String) -> String:
	var hud: Dictionary = view.get("status_hud", {})
	# The balance on return to the Cage includes the reward and both fares.
	if camera_window_start_cash >= 0 and bool(hud.get("bankroll_rendered", false)):
		var round_trip_loss := camera_window_start_cash - int(hud.get("bankroll", 0))
		camera_travel_reserve = maxi(
			camera_travel_reserve, round_trip_loss + CAMERA_WINDOW_REWARD + CAMERA_TRAVEL_CUSHION
		)
		camera_window_start_cash = -1
	if camera_windows == 0 or reserve_checked_window == camera_windows \
			or not bool(hud.get("bankroll_rendered", false)) or int(hud.get("bankroll", 0)) >= camera_travel_reserve:
		return ""
	if archetype == "grand_casino":
		return _grand_room(view, "grand_casino_cage", "Grand Casino Cage")
	var atm := "casino_fixture:cage_atm"
	var loan := "Borrow $50"
	if view.get("spatial", {}).get("selected_object_id") != atm and _room_object_visible(view, atm):
		return "click_object " + atm
	reserve_checked_window = camera_windows
	for action: Dictionary in view.get("clickable", {}).get("room_actions", []):
		if action.get("selected_object_id") == atm and action.get("label") == loan and bool(action.get("enabled", false)):
			return OpeningPolicy._room_action(action, atm)
	return OpeningPolicy.button(view, ["Casino ATM: " + loan])


func _camera_window(view: Dictionary, world_node: String) -> String:
	if last_hold_cash >= 0:
		var hud: Dictionary = view.get("status_hud", {})
		if int(hud.get("bankroll", 0)) == last_hold_cash + CAMERA_WINDOW_REWARD:
			camera_windows += 1
			stage = Stage.PLAN if camera_windows >= CAMERA_WINDOWS_FOR_PLANNING else Stage.ACCESS
			bishop_refresh_needed = world_node == "grand_casino"
			last_hold_cash = -1
			return "wait 16"
	if bool(view.get("screen", {}).get("world_map_overlay_visible", false)):
		return _travel(view, "", true)
	var hold := _hold_sightline(view, world_node)
	if (world_node == camera_target or _room_object_visible(view, "delivery:hold:" + world_node)
			or not OpeningPolicy.button(view, ["Hold Sightline"]).is_empty()):
		return hold
	return _travel(view, "", true)


func _hold_sightline(view: Dictionary, world_node: String) -> String:
	var id := "delivery:hold:" + world_node
	for row: Dictionary in view.get("clickable", {}).get("room_actions", []):
		if row.get("selected_object_id") == id and row.get("label") == "Hold Sightline" and bool(row.get("enabled", false)):
			return "click_action room %d %s label %s" % [int(row.get("index", 0)), Marshalls.utf8_to_base64(id), Marshalls.utf8_to_base64("Hold Sightline")]
	if id == obscured_delivery_object:
		var button := OpeningPolicy.button(view, ["Hold Sightline"])
		return button if not button.is_empty() else "key Right"
	return opening.room_object(view, id, ["Hold Sightline"], ["Hold Sightline"])


func _plan_command(view: Dictionary, archetype: String) -> String:
	if archetype != "small_underground_casino":
		return _travel(view, "small_underground_casino")
	# Current plans require shared reputation. Recruit available contacts in
	# the club and casino before going to the planning table.
	for member: String in RECRUITMENT_RESPONSES:
		var event := "event:recruitment_" + member
		if member not in recruited_members and _room_object_visible(view, event):
			return opening.room_object(view, event, ["Talk"], [member.capitalize() + ": Talk"])
	if str(view.get("environment", {}).get("kind", "")) == "crew" or _room_object_visible(view, "event:crew_planning_table"):
		if reopen_planning_table:
			reopen_planning_table = false
			if view.get("spatial", {}).get("selected_object_id") == "event:crew_planning_table":
				return "click_blank_room"
			return "wait 16"
		return opening.room_object(view, "event:crew_planning_table", ["Lock The Count", "Watch the schedule", "Open"], ["Planning Table: Lock The Count", "Planning Table: Watch the schedule"])
	if _room_object_visible(view, "event:side_door"):
		return opening.room_object(view, "event:side_door", ["Try the word", "Open"], ["Side Door: Try the word"])
	var back_room := opening.room_object(view, "environment_layer:back_room", ["Enter Room"], ["Crew Back Room: Enter Room"])
	if _room_object_visible(view, "environment_layer:back_room") or back_room.begins_with("click"):
		return back_room
	return opening.room_object(view, "environment_layer:casino", ["Enter Casino", "Enter Room"], ["Enter Casino: Enter Room", "Casino: Enter Room"])


func _live_game(view: Dictionary) -> String:
	if stage != Stage.LIVE:
		return OpeningPolicy.surface_action(view, ["surface_back", "leave_game"])
	var game: Dictionary = view.get("game", {})
	if game.get("game_id") != "blackjack":
		return "wait 16"
	var phase := str(game.get("phase", ""))
	if phase == "barred" or bool(game.get("boss_duel_active", false)):
		route_stop = "ordinary Blackjack is no longer playable for The Count"
		return ""
	var settle := OpeningPolicy.surface_action(view, ["blackjack_settle"])
	if not settle.is_empty() and bool(game.get("settle_available", false)):
		return settle
	if phase == "decision":
		return OpeningPolicy.surface_action(view, ["blackjack_stand"])
	if phase != "betting":
		return "wait 16"
	if live_deal_sent:
		return OpeningPolicy.surface_action(view, ["surface_back", "leave_game"])
	var stake := int(game.get("selected_stake", 0))
	if stake == LIVE_STAKE:
		return OpeningPolicy.surface_action(view, ["blackjack_deal"])
	if live_round > 0 and not live_repeat_attempted:
		var repeat := OpeningPolicy.surface_action(view, ["blackjack_repeat_bet"])
		if not repeat.is_empty():
			live_repeat_attempted = true
			return repeat
	var edits: Array = view.get("clickable", {}).get("game_surface_actions", [])
	var denominations: Array = game.get("chip_denominations", [])
	var edit_action := "blackjack_wager_place_gesture" if stake < LIVE_STAKE else "blackjack_remove_chip"
	var best_value := 0
	var edit := ""
	for row: Dictionary in edits:
		var index := int(row.get("index", -1))
		if not bool(row.get("enabled", false)) or row.get("action") != edit_action or index < 0 or index >= denominations.size():
			continue
		var value := int(denominations[index])
		if value > best_value and value <= absi(stake - LIVE_STAKE):
			best_value = value
			edit = "click_action %s %d" % [edit_action, index]
	if not edit.is_empty():
		return edit
	return OpeningPolicy.surface_action(view, ["blackjack_max_bet"]) if stake < LIVE_STAKE else "wait 16"


func _modal_command(view: Dictionary) -> String:
	var popup: Dictionary = view.get("event_popup", {})
	var talk: Dictionary = view.get("talk", {})
	if not bool(popup.get("visible", false)) and not bool(talk.get("visible", false)):
		return ""
	var choices: Array = popup.get("choices", []) if bool(popup.get("visible", false)) else view.get("clickable", {}).get("talk_choices", [])
	var event := str(popup.get("event_id", "")) if bool(popup.get("visible", false)) else str(talk.get("event_id", ""))
	var preferred := ["read_the_shift", "punchline_password", "lock_the_count", "count_schedule",
		"wait_for_bishop", "work_with_bishop", "job_bishop_camera_window", "follow_tip",
		"accept_invite", "continue", "dismiss", "leave_it", "ignore", "decline"]
	if event == "heist_live_table":
		preferred = [LIVE_CHOICES[live_round], "dismiss"]
	elif COOLING_RESPONSES.has(event):
		preferred.push_front(COOLING_RESPONSES[event])
	elif event.begins_with("recruitment_"):
		var response := str(RECRUITMENT_RESPONSES.get(event.trim_prefix("recruitment_"), ""))
		if not response.is_empty():
			preferred.push_front(response)
	for id in preferred:
		for choice: Dictionary in choices:
			if choice.get("id") == id and bool(choice.get("enabled", false)):
				return "click_choice " + id
	var close := OpeningPolicy.button(view, ["Close", "Back", "OK"])
	return close if not close.is_empty() else "wait 16"


func _travel(view: Dictionary, destination: String, marked: bool = false) -> String:
	var screen: Dictionary = view.get("screen", {})
	if not bool(screen.get("world_map_overlay_visible", false)):
		return opening.room_object(view, "travel:leave", ["Open Map"], ["Open Map", "Leave: Open Map"])
	var map: Dictionary = screen.get("world_map", {})
	var selected := str(map.get("selected_node_id", ""))
	var candidate: Dictionary = {}
	for node: Dictionary in map.get("nodes", []):
		if marked and not bool(node.get("delivery_target", false)):
			continue
		var id := str(node.get("id", ""))
		if marked and destination.is_empty():
			camera_target = id
		if bool(node.get("current", false)):
			if marked and destination.is_empty():
				return OpeningPolicy.button(view, ["Close"])
			continue
		if (not destination_rejections.has(id)
				and (destination.is_empty() or id == destination or node.get("archetype_id") == destination or node.get("kind") == destination)):
			candidate = node
			break
	if candidate.is_empty():
		if marked and not destination.is_empty():
			return "wait 16"
		return _travel_detour(view, destination)
	var target := str(candidate.get("id", ""))
	if selected != target:
		return "click_map " + target
	if not candidate.has("travel_enabled"):
		return "wait 16"
	if not bool(candidate.get("travel_enabled", false)):
		if (not marked and destination != "home") or (marked and destination.is_empty()):
			return _close_blocked_travel(view, candidate)
		return "wait 16"
	return OpeningPolicy.button(view, ["Travel"])


func _travel_detour(view: Dictionary, destination: String) -> String:
	var map: Dictionary = view.get("screen", {}).get("world_map", {})
	var markers: Array = map.get("nodes", [])
	var node := str(view.get("environment", {}).get("world_node_id", ""))
	if node != opening.last_node:
		opening.last_node = node
		opening.visits[node] = int(opening.visits.get(node, 0)) + 1
		opening.map_rejections.clear()
	for rejected in destination_rejections:
		opening.map_rejections[rejected] = true
	for marker: Dictionary in markers:
		if (marker.get("id") == map.get("selected_node_id") and marker.has("travel_enabled")
				and not bool(marker.get("travel_enabled", false))):
			return _close_blocked_travel(view, marker)
	# The Queen and Lounge are ordinary approaches to the Grand. Prefer a
	# visible approach when a return leg quotes an unaffordable through fare.
	if destination == "grand_casino":
		for approach in ["delta_queen", "kitty_cat_lounge"]:
			for marker: Dictionary in markers:
				if marker.get("id") == approach and not marker.get("current", false) and not opening.map_rejections.has(approach):
					return _travel(view, approach)
	return opening.decide(view)


func _close_blocked_travel(view: Dictionary, marker: Dictionary) -> String:
	var reason := str(marker.get("travel_disabled_reason", ""))
	if reason.begins_with("The River Queen is out on the river"):
		opening.river_queen_walk_pending = true
	else:
		destination_rejections[marker.get("id")] = reason
	return OpeningPolicy.button(view, ["Close"])


func _grand_room(view: Dictionary, room: String, label: String) -> String:
	return opening.room_object(view, "travel:" + room, ["Enter Room", "Enter"], [label + ": Enter Room"])


func _room_object_visible(view: Dictionary, id: String) -> bool:
	return not OpeningPolicy._rendered_object(view, id).is_empty() or view.get("spatial", {}).get("selected_object_id") == id


func _record_ending_input(command: String, view: Dictionary) -> void:
	var choice := command.trim_prefix("click_choice ") if command.begins_with("click_choice ") else ""
	if stage == Stage.PLAN and view.get("screen", {}).get("screen") == "EVENT":
		if command == OpeningPolicy.button(view, ["Lock The Count"]):
			choice = "lock_the_count"
		elif command == OpeningPolicy.button(view, ["Watch the schedule"]):
			choice = "count_schedule"
	var held_sightline := command == OpeningPolicy.button(view, ["Hold Sightline"])
	if command.begins_with("click_action room "):
		var object := Marshalls.base64_to_raw(command.get_slice(" ", 3)).get_string_from_utf8()
		var identity := Marshalls.base64_to_raw(command.get_slice(" ", 5)).get_string_from_utf8()
		if identity.begins_with("event_response:"):
			choice = identity.get_slice(":", 2)
		if stage == Stage.ACCESS and object in ["travel:grand_casino", "travel:grand_casino_cage"]:
			bishop_room_rechecks += 1
		if object.begins_with("delivery:hold:") and (identity in ["Hold Sightline", "wait"] or identity.ends_with(":wait")):
			held_sightline = true
		if stage == Stage.CART and (object == "crew::package_handoff" or object.begins_with("delivery:handoff:")):
			stage = Stage.LIVE
	match choice:
		"read_the_shift": stage = Stage.ACCESS
		"work_with_bishop": bishop_recruited = true
		"lock_the_count": reopen_planning_table = true
		"job_bishop_camera_window":
			stage = Stage.CAMERA_WINDOW
			camera_window_start_cash = int(view.get("status_hud", {}).get("bankroll", -1))
			last_hold_cash = -1
			camera_target = ""
			bishop_room_rechecks = 0
		"count_schedule":
			stage = Stage.SCHEDULE
			awaiting_schedule_presentation = true
		"go_hold", "distraction_sit", "exit_dock": live_choice_made = true
		"begin_getaway": stage = Stage.GETAWAY
	for member: String in RECRUITMENT_RESPONSES:
		if choice == RECRUITMENT_RESPONSES[member] and member not in recruited_members:
			recruited_members.append(member)
	if held_sightline:
		if stage == Stage.SCHEDULE:
			stage = Stage.CART
		elif stage == Stage.CAMERA_WINDOW:
			last_hold_cash = int(view.get("status_hud", {}).get("bankroll", -1))
	if stage == Stage.CART and command == OpeningPolicy.button(view, ["The Floor Contact: Hand Over The Package"]):
		stage = Stage.LIVE
	if stage == Stage.LIVE and command == "click_action blackjack_deal 0":
		live_deal_sent = true
	if stage == Stage.LIVE and live_deal_sent and command.begins_with("click_action surface_back "):
		live_round += 1
		live_choice_made = false
		live_deal_sent = false
		live_repeat_attempted = false


func _witness(view: Dictionary) -> Dictionary:
	var result := super._witness(view)
	result["crew_stage"] = Stage.keys()[stage]
	result["crew_round"] = live_round
	result["crew_day"] = view.get("crew_day", "")
	result["crew_situation"] = view.get("crew_situation", "")
	result["crew_camera_windows"] = camera_windows
	result["crew_recruits"] = recruited_members.duplicate()
	var message: Dictionary = view.get("message", {})
	if message.get("visible", false):
		result["crew_message"] = message.get("text", "")
	var feedback: Dictionary = view.get("feedback", {})
	if feedback.get("visible", false):
		result["crew_feedback"] = feedback.get("text", "")
	if bool(view.get("screen", {}).get("world_map_overlay_visible", false)):
		var map: Dictionary = view.get("screen", {}).get("world_map", {})
		result["crew_route_markers"] = []
		for node: Dictionary in map.get("nodes", []):
			if bool(node.get("delivery_target", false)):
				result["crew_route_markers"].append(str(node.get("id", "")))
			if node.get("id") == map.get("selected_node_id"):
				result["crew_map_travel_enabled"] = node.get("travel_enabled")
				result["crew_map_travel_disabled_reason"] = node.get("travel_disabled_reason", "")
	var game: Dictionary = view.get("game", {})
	if game.has("selected_stake"):
		result["crew_stake"] = game["selected_stake"]
	return result


func _ending_stop_reason(_view: Dictionary) -> String:
	return route_stop


func _matches_target_key(key: String) -> bool:
	return key in WINNING_REPORTS


func _target_ending() -> String:
	return "crew_heist"
