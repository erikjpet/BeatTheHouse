extends SceneTree

const CONFIG_PATH := "res://data/crew/numbers.json"
const VENUE_INVARIANTS := {
	"small_underground_casino": [-3, true, 2], "bar": [-2, false, 1], "motel": [-1, false, 1],
	"gas_station_casino": [2, false, 1], "corner_store": [4, false, 1],
}
const BOOK_STATES := ["open", "busy", "closing", "closed", "friendly", "wary", "suspicious"]
const ACTIONS := ["place_slip", "show_slip", "hide_slip", "hand_slip", "collect_win"]
const AFTERMATH := ["big_win", "past_post_seen", "refused", "visit_count"]


func _init() -> void:
	var failures: Array = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	var root: Dictionary = (parsed as Array)[0] if typeof(parsed) == TYPE_ARRAY and (parsed as Array).size() == 1 and typeof((parsed as Array)[0]) == TYPE_DICTIONARY else {}
	if root.is_empty(): failures.append("Numbers authored semantics source is not one closed root record.")
	_check_locked_numbers(root, failures)
	_check_books(root, failures)
	_check_staged_beats(root, failures)
	_check_no_authority_claims(root, failures)
	if failures.is_empty():
		print("world06_3 numbers authored semantics contract passed books=5 numeric_invariants=unchanged")
		quit(0)
		return
	for failure in failures: push_error(str(failure))
	quit(1)


func _check_locked_numbers(root: Dictionary, failures: Array) -> void:
	var clock := _dict(root.get("clock", {}))
	var slips := _dict(root.get("slips", {}))
	var play_types := _dict(slips.get("play_types", {}))
	var runner := _dict(root.get("runner", {}))
	var fix := _dict(root.get("fix", {}))
	var past := _dict(root.get("past_posting", {}))
	if _ints(clock, ["actions_per_day", "post_action_offset", "settlement_action_offset"]) != [24, 16, 21]: failures.append("Numbers clock tuning changed.")
	if _ints(slips, ["stake_min", "stake_max", "declared_pool_payout_cap"]) != [1, 20, 9000]: failures.append("Numbers stake or pool cap changed.")
	var straight := _dict(play_types.get("straight", {}))
	var box := _dict(play_types.get("box", {}))
	if _ints(straight, ["payout_to_one", "per_slip_payout_cap"]) != [500, 5000] or not is_equal_approx(float(straight.get("honest_hit_probability", 0.0)), 0.001) or not is_equal_approx(float(straight.get("honest_gross_return", 0.0)), 0.5): failures.append("Straight odds/payout invariants changed.")
	if _ints(box, ["payout_to_one", "per_slip_payout_cap"]) != [70, 1400] or not is_equal_approx(float(box.get("honest_hit_probability_distinct_digits", 0.0)), 0.006) or not is_equal_approx(float(box.get("honest_gross_return_distinct_digits", 0.0)), 0.42): failures.append("Box odds/payout invariants changed.")
	var bag_values := _array(runner.get("bag_value_per_venue", []))
	if bag_values.size() != 2 or int(bag_values[0]) != 35 or int(bag_values[1]) != 70 or _ints(runner, ["pay_percent", "trust_on_time", "trust_late", "swept_heat"]) != [18, 5, -6, 14]: failures.append("Runner economics changed.")
	if _ints(_dict(fix.get("camouflage", {})), ["minimum_venues", "maximum_concentration_percent", "thin_venue_stake", "target_total_stake", "operation_heat_too_concentrated"]) != [3, 45, 4, 60, 18]: failures.append("Fix camouflage tuning changed.")
	if _ints(past, ["detection_base_percent", "detection_repeat_step_percent", "detection_stake_step_percent_per_5", "detection_cap_percent", "penalty_flat", "penalty_stake_multiplier"]) != [5, 7, 3, 70, 20, 2]: failures.append("Past-post detection or penalty tuning changed.")


func _check_books(root: Dictionary, failures: Array) -> void:
	var seen: Array = []
	for venue_value in _array(root.get("venues", [])):
		var venue := _dict(venue_value)
		var venue_id := str(venue.get("id", ""))
		seen.append(venue_id)
		if not VENUE_INVARIANTS.has(venue_id):
			failures.append("Unknown Numbers venue %s." % venue_id)
			continue
		var locked: Array = VENUE_INVARIANTS[venue_id]
		if int(venue.get("close_offset_from_post_actions", 999)) != int(locked[0]) or bool(venue.get("post_source", false)) != bool(locked[1]) or int(venue.get("base_strictness", -1)) != int(locked[2]): failures.append("%s close/source/strictness changed." % venue_id)
		var place := _dict(venue.get("place", {}))
		var bookmaker := _dict(venue.get("bookmaker", {}))
		if str(place.get("id", "")) != "%s::numbers_book" % venue_id or str(place.get("kind", "")).is_empty() or str(place.get("public_label", "")).is_empty(): failures.append("%s lacks its authored semantic place." % venue_id)
		if str(bookmaker.get("actor_id", "")) != "numbers_bookmaker_%s" % venue_id or _array(bookmaker.get("authored_states", [])) != BOOK_STATES: failures.append("%s lacks its exact bookmaker actor/state vocabulary." % venue_id)
		for action in ACTIONS:
			if not _array(venue.get("public_actions", [])).has(action): failures.append("%s lacks public action %s." % [venue_id, action])
		if _array(venue.get("aftermath_descriptors", [])) != AFTERMATH: failures.append("%s lacks closed public aftermath descriptors." % venue_id)
	seen.sort()
	var expected: Array = VENUE_INVARIANTS.keys()
	expected.sort()
	if seen != expected: failures.append("Authored semantics do not cover exactly all five books.")


func _check_staged_beats(root: Dictionary, failures: Array) -> void:
	var semantics := _dict(root.get("world_semantics", {}))
	var draw := _dict(semantics.get("draw_occasion", {}))
	var fix := _dict(semantics.get("fix_sequence", {}))
	if str(semantics.get("contract", "")) != "numbers_world_semantics/1": failures.append("Numbers semantic package id/version is missing.")
	if _array(draw.get("present_beats", [])).size() < 5 or _array(draw.get("absent_beats", [])).size() < 3 or not _array(draw.get("public_actions", [])).has("watch_draw"): failures.append("Draw present/absent occasion beats are incomplete.")
	for key in ["bribe_beats", "camouflage_beats", "payday_beats", "failure_beats"]:
		if _array(fix.get(key, [])).size() < 4: failures.append("Fix sequence lacks staged %s." % key)


func _check_no_authority_claims(root: Dictionary, failures: Array) -> void:
	var source := JSON.stringify(root).to_lower()
	for forbidden in ["route_ops", "route_authority", "receipt_id", "receipt_key", "rng", "random"]:
		if source.contains(forbidden): failures.append("Authored semantic data claims forbidden authority: %s." % forbidden)


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _ints(source: Dictionary, keys: Array) -> Array:
	var result: Array = []
	for key in keys: result.append(int(source.get(key, 0)))
	return result
