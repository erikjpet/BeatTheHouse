extends RefCounted

# Opening decisions share the same rendered observation as the duel policy.
const RouteProfiles := preload("res://tools/ending_solver/route_profiles.gd")
const CHIP_RESERVE := 50

var opening_profile := "standard"
var visits: Dictionary = {}
var last_node := ""
var map_rejections: Dictionary = {}
var funding_scanned: Dictionary = {}
var chips_prepared := false
var funding_target := 0
var funding_spins := 0
var river_queen_walk_pending := false
var room_scroll_direction := "down"
var room_scroll_reversed := false
var refocus_attempts: Dictionary = {}
var clearing_result := false
var result_normalized := false


func decide(view: Dictionary) -> String:
	var screen: Dictionary = view.get("screen", {})
	var environment: Dictionary = view.get("environment", {})
	var hud: Dictionary = view.get("status_hud", {})
	var archetype := str(environment.get("archetype_id", ""))
	var node := str(environment.get("world_node_id", ""))
	if not node.is_empty() and node != last_node:
		visits[node] = int(visits.get(node, 0)) + 1
		last_node = node
		map_rejections.clear()
	if bool(hud.get("chips_rendered", false)) and int(hud.get("chips", 0)) >= CHIP_RESERVE:
		chips_prepared = true
	var cash := int(hud.get("bankroll", 0)) if bool(hud.get("bankroll_rendered", false)) else -1
	var modal_command := _modal(view, cash)
	if not modal_command.is_empty():
		return modal_command
	if bool(screen.get("travel_transition_active", false)) or bool(view.get("spatial", {}).get("loading", false)):
		return "wait 16"
	var screen_name := str(screen.get("screen", ""))
	if bool(screen.get("world_map_overlay_visible", false)):
		if clearing_result:
			var close := button(view, ["Close"])
			if not close.is_empty():
				clearing_result = false
				result_normalized = true
			return close
		return _map_command(view, cash, archetype)
	if screen_name != "RESULT":
		result_normalized = false
	elif not result_normalized:
		var open_map := room_object(view, "travel:leave", ["Open Map"], ["Open Map", "Leave: Open Map"])
		if not open_map.is_empty():
			clearing_result = true
			return open_map
	if screen_name == "GAME":
		return _funding_game(view, cash)
	if screen_name not in ["ENVIRONMENT", "RESULT"]:
		return ""
	if archetype == "grand_casino_cage":
		if not chips_prepared or int(hud.get("chips", 0)) < 5:
			if cash >= 0 and cash < 25:
				var marker := room_object(view, "casino_fixture:cage_atm", ["Borrow $50"], ["Casino ATM: Borrow $50"])
				if not marker.is_empty():
					return marker
			return room_object(view, "casino_fixture:cage_counter", ["Talk", "Open", "Inspect"], ["Cashout Counter: Inspect"])
		return room_object(view, "travel:grand_casino", ["Enter Room", "Travel", "Enter"], ["Grand Casino Main Floor: Enter Room", "Main Floor: Enter Room"])
	if archetype == "grand_casino":
		var house_calls := room_object(view, "event:the_house_calls", ["Follow Rourke", "Open", "Answer"])
		if house_calls.is_empty():
			house_calls = button(view, ["The House Calls: Follow Rourke"])
		if not house_calls.is_empty():
			return house_calls
		if int(hud.get("heat_level", 0)) >= 85:
			var overflow := room_object(view, "event:the_house_calls", ["Follow Rourke"], ["The House Calls: Follow Rourke"])
			if not overflow.is_empty():
				return overflow
		if not chips_prepared or int(hud.get("chips", 0)) < 5:
			return room_object(view, "travel:grand_casino_cage", ["Enter Room", "Travel", "Enter"], ["Grand Casino Cage: Enter Room", "Cage: Enter Room"])
		return room_object(view, "game:blackjack", ["Enter", "Play"], ["Blackjack: Play", "Blackjack: Enter"])
	if archetype == "grand_casino_high_limit":
		return room_object(view, "travel:grand_casino", ["Enter Room", "Travel", "Enter"], ["Grand Casino Main Floor: Enter Room", "Main Floor: Enter Room"])
	var invite := room_object(view, "event:grand_casino_invite", ["Take the invite", "Open", "Answer", "Respond", "Talk", "Inspect"])
	if invite.is_empty():
		invite = button(view, ["High Roller Invitation: Take the invite", "High Roller Invitation: Talk"])
	if not invite.is_empty():
		return invite
	if archetype == "delta_queen" and river_queen_walk_pending:
		return room_object(view, "service:riverboat_deck_walk", ["Use"], ["Walk the Deck: Use"])
	if cash >= 0 and cash < funding_target and funding_spins < 6:
		var cash_offer := room_object(view, "event:back_alley_offer", ["Take the cash"])
		if not cash_offer.is_empty():
			return cash_offer
		var slots := room_object(view, "game:slot", ["Enter", "Play"])
		if not slots.is_empty():
			return slots
	return room_object(view, "travel:leave", ["Open Map"], ["Open Map", "Leave: Open Map"])


func _modal(view: Dictionary, cash: int) -> String:
	var popup: Dictionary = view.get("event_popup", {})
	var talk: Dictionary = view.get("talk", {})
	var choices: Array = []
	if bool(popup.get("visible", false)):
		choices = popup.get("choices", [])
	elif bool(talk.get("visible", false)):
		choices = view.get("clickable", {}).get("talk_choices", [])
	else:
		return ""
	var ids := ["accept_invite", "ignore", "leave_it", "walk_away", "decline", "continue"]
	if funding_target > cash and str(popup.get("event_id", talk.get("event_id", ""))) == "back_alley_offer":
		ids.push_front("take_cash")
	if bool(talk.get("visible", false)):
		if cash < 25 or chips_prepared:
			ids = ["leave_counter", "back_main"] + ids
		else:
			ids = ["cage_buy_50", "cage_buy_25", "open_chips"] + ids
		if chips_prepared and cash >= 25 and int(view.get("status_hud", {}).get("chips", 0)) < 5:
			ids = ["cage_buy_25", "open_chips"] + ids
	for id in ids:
		for choice in choices:
			if str(choice.get("id", "")) == id and bool(choice.get("enabled", false)):
				return "click_choice " + id
	var enabled_choices := choices.filter(func(choice: Dictionary) -> bool: return bool(choice.get("enabled", false)))
	if enabled_choices.size() == 1:
		var label := str(enabled_choices[0].get("label", "")).to_lower()
		if label in ["ok", "okay", "close", "got it", "continue", "enter the floor", "keep walking"]:
			return "click_choice " + str(enabled_choices[0].get("id", ""))
	return "wait 16"


func _map_command(view: Dictionary, cash: int, archetype: String) -> String:
	var screen: Dictionary = view.get("screen", {})
	var map: Dictionary = screen.get("world_map", {})
	var selected := str(map.get("selected_node_id", ""))
	var best: Dictionary = {}
	var best_score := -100000
	for node in map.get("nodes", []):
		var id := str(node.get("id", ""))
		var destination := str(node.get("archetype_id", ""))
		if bool(node.get("current", false)) or id == last_node or map_rejections.has(id):
			continue
		var score := -200 * int(visits.get(id, 0))
		if str(node.get("kind", "")) == "casino":
			score += 40
		if opening_profile == "standard":
			if destination in ["kitty_cat_lounge", "delta_queen"]:
				score += 50
			if destination == "kitty_cat_lounge":
				score += 10
		else:
			score += RouteProfiles.destination_bonus(opening_profile, node)
		if destination == "grand_casino":
			score += 1000
		if score > best_score:
			best = node
			best_score = score
	if best.is_empty():
		return ""
	var target := str(best.get("id", ""))
	if target != selected:
		return "click_map " + target
	if not best.has("travel_enabled") or cash < 0:
		return "wait 16"
	var cost := int(best.get("cost", 0))
	var enabled := bool(best.get("travel_enabled", false))
	if str(best.get("archetype_id", "")) == "grand_casino":
		var reason := str(best.get("travel_disabled_reason", ""))
		if archetype == "delta_queen" and reason.begins_with("The River Queen is out on the river") and cash >= cost + CHIP_RESERVE + 10:
			var walk_close := button(view, ["Close"])
			if not walk_close.is_empty():
				river_queen_walk_pending = true
			return walk_close
		var chip_reserve := CHIP_RESERVE if cost > 0 and RouteProfiles.requires_chip_reserve(opening_profile) else 1
		if cash < cost + chip_reserve and (enabled or reason.begins_with("Not enough bankroll")):
			funding_target = cost + chip_reserve
			if funding_spins < 6 and not funding_scanned.has(last_node):
				var funding_close := button(view, ["Close"])
				if not funding_close.is_empty():
					funding_scanned[last_node] = true
				return funding_close
			enabled = false
	if enabled:
		var travel := button(view, ["Travel"])
		return travel if not travel.is_empty() else "wait 16"
	map_rejections[target] = true
	return "wait 8"


func _funding_game(view: Dictionary, cash: int) -> String:
	if str(view.get("game", {}).get("game_id", "")) != "slot" or funding_target <= 0:
		return ""
	if cash >= funding_target or funding_spins >= 6 or cash <= 5:
		return surface_action(view, ["surface_back", "leave_game"])
	for action in view.get("clickable", {}).get("game_surface_actions", []):
		var id := str(action.get("action", ""))
		if bool(action.get("enabled", false)) and (id == "slot_handpay_acknowledge" or id.begins_with("slot_bonus_")):
			return "click_action %s %d" % [id, int(action.get("index", 0))]
	var spin := surface_action(view, ["slot_spin"])
	return spin if not spin.is_empty() else "wait 20"


func record_input(command: String, view: Dictionary) -> void:
	if command.begins_with("click_action slot_spin"):
		funding_spins += 1
	if river_queen_walk_pending and command.begins_with("click_action room "):
		var focused := str(view.get("spatial", {}).get("selected_object_id", ""))
		if focused == "service:riverboat_deck_walk":
			river_queen_walk_pending = false
	if river_queen_walk_pending and command in [button(view, ["Walk the Deck: Use"]), "click_object service:riverboat_deck_walk double"]:
		river_queen_walk_pending = false


func room_object(view: Dictionary, id: String, labels: Array, overflow_labels: Array = []) -> String:
	var refocus_key := str(view.get("environment", {}).get("id", "")) + "/" + id
	var actions: Array = view.get("clickable", {}).get("room_actions", [])
	var matching: Array[Dictionary] = []
	for row in actions:
		if not bool(row.get("enabled", false)) or not bool(row.get("rendered", false)):
			continue
		if str(row.get("selected_object_id", "")) != id:
			continue
		matching.append(row)
		if str(row.get("label", "")) in labels:
			refocus_attempts.erase(refocus_key)
			return _room_action(row, id)
	if matching.size() == 1:
		refocus_attempts.erase(refocus_key)
		return _room_action(matching[0], id)
	var overflow := button(view, overflow_labels)
	if not overflow.is_empty():
		room_scroll_reversed = false
		room_scroll_direction = "down"
		return overflow
	if not _rendered_object(view, id).is_empty():
		var selected := str(view.get("spatial", {}).get("selected_object_id", ""))
		return "click_object " + id + (" double" if selected == id and matching.is_empty() else "")
	if overflow_labels.is_empty():
		return ""
	for surface in view.get("clickable", {}).get("scroll_surfaces", []):
		if str(surface.get("id", "")) != "room_actions":
			continue
		if bool(surface.get("can_scroll_" + room_scroll_direction, false)):
			return "scroll_surface room_actions " + room_scroll_direction
		if not room_scroll_reversed and bool(surface.get("can_scroll_up", false)):
			room_scroll_reversed = true
			room_scroll_direction = "up"
			return "scroll_surface room_actions up"
		return ""
	var more := button(view, ["More room actions"], true)
	if not more.is_empty():
		return more
	var tried: Dictionary = refocus_attempts.get(refocus_key, {})
	if tried.is_empty():
		refocus_attempts[refocus_key] = {"waited": true}
		return "wait 30"
	var selected := str(view.get("spatial", {}).get("selected_object_id", ""))
	if not tried.has("") and not selected.is_empty():
		tried[""] = true
		refocus_attempts[refocus_key] = tried
		return "click_blank_room"
	var keyboard_steps := int(tried.get("keyboard_steps", 0))
	if keyboard_steps > 0 and keyboard_steps < 30:
		tried["keyboard_steps"] = keyboard_steps + 1
		return "key Right"
	for row in view.get("clickable", {}).get("canvas_objects", []):
		var other := str(row.get("semantic_id", ""))
		if other != selected and not tried.has(other) and bool(row.get("enabled", false)):
			tried[other] = true
			if keyboard_steps == 0:
				tried["keyboard_steps"] = 1
			refocus_attempts[refocus_key] = tried
			return "click_object " + other
	return ""


static func _room_action(row: Dictionary, id: String) -> String:
	for key in ["id", "action", "action_id", "emit_object_id", "label"]:
		var identity := str(row.get(key, ""))
		if not identity.is_empty():
			return "click_action room %d %s %s %s" % [
				int(row.get("index", 0)), Marshalls.utf8_to_base64(id), key, Marshalls.utf8_to_base64(identity),
			]
	return ""


static func _rendered_object(view: Dictionary, id: String) -> Dictionary:
	for row in view.get("clickable", {}).get("canvas_objects", []):
		if str(row.get("semantic_id", "")) == id and bool(row.get("enabled", false)) and bool(row.get("rendered", false)):
			return row
	return {}


static func button(view: Dictionary, labels: Array, contains_text: bool = false) -> String:
	for label in labels:
		for row in view.get("clickable", {}).get("buttons", []):
			if not bool(row.get("enabled", false)) or not bool(row.get("fully_visible", false)):
				continue
			var visible_text := str(row.get("text", ""))
			var id := str(row.get("id", ""))
			if id == label or visible_text == label or (contains_text and visible_text.contains(label)):
				return "click_button " + id
	return ""


static func surface_action(view: Dictionary, ids: Array) -> String:
	for id in ids:
		for row in view.get("clickable", {}).get("game_surface_actions", []):
			if str(row.get("action", "")) == id and bool(row.get("enabled", false)):
				return "click_action %s %d" % [id, int(row.get("index", 0))]
	return ""
