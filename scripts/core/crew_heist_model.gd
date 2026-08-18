class_name CrewHeistModel
extends RefCounted

# Deterministic, boundary-driven state model for the two launch heists.

const CONFIG_PATH := "res://data/crew/heist.json"
const SCHEMA_VERSION := 1
const PLAN_COUNT := "the_count"
const PLAN_WHALE := "the_whale_game"
const PLAN_IDS := [PLAN_COUNT, PLAN_WHALE]
const STATUS_LOCKED := "locked"
const STATUS_SETUP := "setup"
const STATUS_PLAY := "play"
const STATUS_INTERVIEW := "interview"
const STATUS_GETAWAY := "getaway"
const STATUS_COMPLETED := "completed"
const STATUS_ABORTED := "aborted"
const STATUSES := [STATUS_LOCKED, STATUS_SETUP, STATUS_PLAY, STATUS_INTERVIEW, STATUS_GETAWAY, STATUS_COMPLETED, STATUS_ABORTED]

static var _config_cache: Dictionary = {}


static func config() -> Dictionary:
	if _config_cache.is_empty():
		var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_ARRAY and not (parsed as Array).is_empty() and typeof((parsed as Array)[0]) == TYPE_DICTIONARY:
				_config_cache = ((parsed as Array)[0] as Dictionary).duplicate(true)
	return _config_cache.duplicate(true)


static func plan(plan_id: String) -> Dictionary:
	for value in config().get("plans", []):
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == plan_id:
			return (value as Dictionary).duplicate(true)
	return {}


static func empty_state() -> Dictionary:
	return {}


static func begin(plan_id: String, action_index: int) -> Dictionary:
	if not PLAN_IDS.has(plan_id) or plan(plan_id).is_empty():
		return {}
	return normalize_state({
		"schema_version": SCHEMA_VERSION,
		"plan_id": plan_id,
		"status": STATUS_SETUP,
		"locked_action": maxi(0, action_index),
		"setup": {},
		"play": {"round": 0, "score": 100, "decisions": {}, "hazards": [], "lifelines_used": []},
		"getaway": {},
		"outcome": "",
		"payout": 0,
		"r": {"v": 1, "s": "0"},
	})


static func normalize_state(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).is_empty():
		return {}
	var source: Dictionary = value
	var plan_id := str(source.get("plan_id", ""))
	if not PLAN_IDS.has(plan_id):
		return {}
	var status := str(source.get("status", STATUS_SETUP))
	if not STATUSES.has(status):
		status = STATUS_ABORTED
	var result := {
		"schema_version": SCHEMA_VERSION,
		"plan_id": plan_id,
		"status": status,
		"locked_action": maxi(0, int(source.get("locked_action", 0))),
		"setup": _copy_dict(source.get("setup", {})),
		"play": _copy_dict(source.get("play", {})),
		"getaway": _copy_dict(source.get("getaway", {})),
		"outcome": str(source.get("outcome", "")),
		"payout": maxi(0, int(source.get("payout", 0))),
		"r": _copy_dict(source.get("r", {"v": 1, "s": "0"})),
	}
	if source.has("abort"):
		result["abort"] = _copy_dict(source.get("abort", {}))
	if source.has("interview"):
		result["interview"] = _copy_dict(source.get("interview", {}))
	return result


static func setup_complete(state_value: Variant) -> bool:
	var state := normalize_state(state_value)
	if state.is_empty():
		return false
	var setup := _copy_dict(state.get("setup", {}))
	if str(state.get("plan_id", "")) == PLAN_COUNT:
		return bool(setup.get("identity", false)) and bool(setup.get("schedule", false)) and bool(setup.get("swap_cart", false))
	return bool(setup.get("vouch", false)) and bool(setup.get("rig", false)) and bool(setup.get("name", false)) and bool(setup.get("drunk", false))


static func ladder(score: int, getaway_success: bool, made: bool = false, bust: bool = false) -> String:
	var adjusted := clampi(score, 0, 100)
	if not getaway_success:
		adjusted -= 25
	if made:
		adjusted -= 25
	if bust:
		adjusted -= 20
	if adjusted >= 80:
		return "clean_sweep"
	if adjusted >= 55:
		return "out_hot"
	return "somebody_got_pinched"


static func payout_for(state_value: Variant, outcome: String) -> int:
	var state := normalize_state(state_value)
	var definition := plan(str(state.get("plan_id", "")))
	var tuning := _copy_dict(definition.get("payout", {}))
	if str(state.get("plan_id", "")) == PLAN_COUNT:
		var value := int(tuning.get("base", 0))
		if outcome == "clean_sweep":
			value += int(tuning.get("clean_bonus", 0))
		elif outcome == "somebody_got_pinched":
			value -= int(tuning.get("hot_penalty", 0))
		return maxi(0, value)
	var play := _copy_dict(state.get("play", {}))
	return clampi(int(play.get("pot", tuning.get("minimum", 0))), int(tuning.get("minimum", 0)), int(tuning.get("maximum", 0)))


static func ending_line(plan_id: String, outcome: String) -> String:
	return str(_copy_dict(_copy_dict(config().get("ending_copy", {})).get(plan_id, {})).get(outcome, "The crew leaves before the room can name what happened."))


static func validate_content() -> Array:
	var failures: Array = []
	var source := config()
	if int(source.get("schema_version", 0)) != SCHEMA_VERSION or int(source.get("state_schema_version", 0)) != SCHEMA_VERSION:
		failures.append("heist.json schema versions must match CrewHeistModel.")
	var ids: Array = []
	for value in source.get("plans", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = value
		ids.append(str(row.get("id", "")))
		if _copy_array(row.get("world_criteria", [])).is_empty() or _copy_array(row.get("crew_criteria", [])).is_empty() or _copy_dict(row.get("setup", {})).is_empty() or _copy_dict(row.get("play", {})).is_empty() or _copy_dict(row.get("getaway", {})).is_empty():
			failures.append("Heist plan %s is missing criteria or phase tuning." % str(row.get("id", "")))
		var expected_architects := ["crew_bishop"] if str(row.get("id", "")) == PLAN_COUNT else ["crew_velvet", "crew_mags"]
		if _copy_array(row.get("architects", [])) != expected_architects:
			failures.append("Heist plan %s must expose its exact crew06_9 loyal-architect set." % str(row.get("id", "")))
		var setup := _copy_dict(row.get("setup", {}))
		var play := _copy_dict(row.get("play", {}))
		if str(row.get("id", "")) == PLAN_COUNT:
			var decision_rounds := _copy_dict(play.get("decision_rounds", {}))
			if int(play.get("window_actions", 0)) <= 0 or int(decision_rounds.get("go", -1)) != 0 or int(decision_rounds.get("distraction", -1)) != 1 or int(decision_rounds.get("exit", -1)) != 2:
				failures.append("The Count must author its action window and three interleaved decision rounds.")
			var routes := _copy_dict(_copy_dict(row.get("getaway", {})).get("routes", {}))
			if not routes.has("dock") or not routes.has("corridor"):
				failures.append("The Count must author distinct dock and corridor getaway routes.")
		else:
			if _copy_array(play.get("game_sequence", [])) != ["craps", "blackjack", "craps", "baccarat", "blackjack"]:
				failures.append("The Whale Game must author its mixed craps/card invitational sequence.")
			var rig := _copy_dict(setup.get("rig", {}))
			if str(rig.get("component_item", "")) != "false_bottom_cup" or str(rig.get("training_flag", "")) != "craps_setting_trained":
				failures.append("The Whale Game rig schema must match its reachable item and training producers.")
			if _copy_dict(row.get("interview", {})).is_empty():
				failures.append("The Whale Game must author its cage interview beat.")
	if ids != PLAN_IDS:
		failures.append("heist.json must ship Plans A and B only, in contract order.")
	for forbidden in ["the_jackpot_job", "lights_out"]:
		if JSON.stringify(source).to_lower().find(forbidden) != -1:
			failures.append("heist.json contains a forbidden future-plan coupling: %s." % forbidden)
	return failures


static func _copy_dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _copy_array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
