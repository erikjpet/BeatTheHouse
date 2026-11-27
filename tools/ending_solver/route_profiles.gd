extends RefCounted

const MODEL_SCHEMA := "bth.ending_solver_route_model/v1"
const DEFAULT_POLICY := "balanced"
const LOUNGE_FIRST := "lounge_first"
const RIVERBOAT_FIRST := "riverboat_first"
const RESERVE_FIRST := "reserve_first"

# The endpoint policies control play at the Grand. Each also has one fixed
# opening preference so a training arm is comparable across independent runs.
const OPENING_BY_ENDING := {
	"crew_heist": {"the_count": RIVERBOAT_FIRST},
	"gold_card": {
		"baseline": LOUNGE_FIRST,
		"balanced": LOUNGE_FIRST,
		"risk_aware": RESERVE_FIRST,
		"minimum_stakes": RESERVE_FIRST,
		"target_stakes": RIVERBOAT_FIRST,
		"high_limit": RIVERBOAT_FIRST,
		"reserve_recovery": LOUNGE_FIRST,
	},
	"rourke_duel": {
		"baseline": LOUNGE_FIRST,
		"balanced": LOUNGE_FIRST,
		"risk_aware": RESERVE_FIRST,
		"direct_peek": RIVERBOAT_FIRST,
		"profit_trigger": RIVERBOAT_FIRST,
		"cool_before_duel": RESERVE_FIRST,
	},
}
const DESTINATION_BONUSES := {
	LOUNGE_FIRST: {"kitty_cat_lounge": 115, "delta_queen": 70, "bar": 35, "gas_station": 25},
	RIVERBOAT_FIRST: {"delta_queen": 125, "beach": 105, "kitty_cat_lounge": 65, "motel": 30},
	RESERVE_FIRST: {"beach": 145, "kitty_cat_lounge": 65, "delta_queen": 55, "pawn_shop": 26},
}
const KNOWN_OPENING_VENUES := [
	"home", "corner_store", "gas_station", "bar", "back_alley", "motel",
	"pawn_shop", "beach", "kitty_cat_lounge", "delta_queen", "grand_casino",
]
const ROUTE_MARKERS := {
	"kitty_cat_lounge": "lounge",
	"delta_queen": "riverboat",
	"beach": "beach",
	"grand_casino": "grand",
}


static func policies(ending_target: String) -> Array:
	var catalog: Dictionary = OPENING_BY_ENDING.get(ending_target, {})
	return catalog.keys()


static func opening_profile(ending_target: String, policy: String) -> String:
	var catalog: Dictionary = OPENING_BY_ENDING.get(ending_target, {})
	return str(catalog.get(policy, LOUNGE_FIRST))


static func destination_bonus(opening_name: String, node: Dictionary) -> int:
	var bonuses: Dictionary = DESTINATION_BONUSES.get(opening_name, DESTINATION_BONUSES[LOUNGE_FIRST])
	return int(bonuses.get(str(node.get("archetype_id", "")), 0))


static func requires_chip_reserve(opening_name: String) -> bool:
	return opening_name == RESERVE_FIRST


static func starting_observation(view: Dictionary) -> Dictionary:
	var screen: Dictionary = view.get("screen", {})
	if not bool(screen.get("world_map_overlay_visible", false)):
		return {}
	var seen := {}
	var frontier := {}
	var has_destination := false
	var other_casino := false
	var map: Dictionary = screen.get("world_map", {})
	for value in map.get("nodes", []):
		var node: Dictionary = value
		if bool(node.get("current", false)):
			continue
		has_destination = true
		var destination := str(node.get("archetype_id", ""))
		if destination in KNOWN_OPENING_VENUES:
			frontier[destination] = true
		var marker := str(ROUTE_MARKERS.get(destination, ""))
		if not marker.is_empty():
			seen[marker] = true
		elif str(node.get("kind", "")) == "casino":
			other_casino = true
	if not has_destination:
		return {}
	var markers: Array[String] = []
	for marker in ["lounge", "riverboat", "beach", "grand"]:
		if seen.has(marker):
			markers.append(marker)
	if other_casino:
		markers.append("other_casino")
	var map_group := "+".join(markers) if not markers.is_empty() else "local_stops"
	var environment: Dictionary = view.get("environment", {})
	var venue := str(environment.get("archetype_id", ""))
	if venue not in KNOWN_OPENING_VENUES:
		venue = "other"
	var room_label := str(environment.get("display_name", "")).strip_edges()
	var frontier_ids := PackedStringArray(frontier.keys())
	frontier_ids.sort()
	var hud: Dictionary = view.get("status_hud", {})
	var cash := _hud_band(hud, "bankroll", "bankroll_rendered", 50, 100)
	var heat := _hud_band(hud, "heat_level", "heat_rendered", 15, 30)
	var venue_key := "venue=" + venue
	var room_key := "room=" + room_label.to_snake_case()
	var frontier_key := "frontier=" + "+".join(frontier_ids)
	var map_key := "map=" + map_group
	var cash_key := "cash=" + cash
	var heat_key := "heat=" + heat
	return {
		"venue": venue, "room": room_label, "frontier": frontier_ids,
		"map": map_group, "cash_band": cash, "heat_band": heat,
		"context_keys": [
			"|".join([room_key, frontier_key, cash_key, heat_key]),
			"|".join([room_key, frontier_key]),
			"|".join([frontier_key, cash_key]),
			room_key,
			frontier_key,
			"|".join([venue_key, map_key, cash_key, heat_key]),
			"|".join([venue_key, map_key]),
			"|".join([map_key, cash_key]),
			"|".join([venue_key, cash_key]),
			venue_key,
			map_key,
			"|".join([cash_key, heat_key]),
		],
	}


static func choose_policy(ending_target: String, learned_model: Dictionary, observation: Dictionary) -> String:
	if learned_model.get("schema") != MODEL_SCHEMA or learned_model.get("ending_target") != ending_target:
		return DEFAULT_POLICY
	var candidates := policies(ending_target)
	var fallback := str(learned_model.get("default_policy", DEFAULT_POLICY))
	if fallback not in candidates:
		fallback = DEFAULT_POLICY
	var contexts: Variant = learned_model.get("context_policies", {})
	if typeof(contexts) != TYPE_DICTIONARY:
		return fallback
	for key in observation.get("context_keys", []):
		var choice: Variant = contexts.get(key)
		if typeof(choice) == TYPE_STRING and choice in candidates:
			return choice
	return fallback


static func _hud_band(hud: Dictionary, field: String, visibility: String, middle: int, upper: int) -> String:
	if not bool(hud.get(visibility, false)) or not hud.has(field):
		return "unknown"
	var value := int(hud[field])
	if value < middle:
		return "low"
	return "medium" if value < upper else "high"
