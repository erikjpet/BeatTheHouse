extends SceneTree

const HEIST_PATH := "res://data/crew/heist.json"
const EXPECTED_GOVERNING_SHA256 := "33b7036254db4f65abe90527cf0012877f98bfff5bd912f9d22a1a6a1c153198"
const EXPECTED_PLANS := ["the_count", "the_whale_game"]
const EXPECTED_EXITS := {
	"the_count": ["corridor", "dock"],
	"the_whale_game": ["clean_walk", "hot_chase"],
}
const FORBIDDEN_SURFACES := [
	"traitor", "betray", "eligible", "eligibility", "grievance", "weight",
	"resolution", "clue", "suspect", "loyal", "guilt", "hidden_identity",
	"active_member", "member_pool", "chance_percent", "crew_trust_cost",
]


func _initialize() -> void:
	var failures: Array = []
	var rows := _load_array(HEIST_PATH)
	if rows.size() != 1 or typeof(rows[0]) != TYPE_DICTIONARY:
		failures.append("heist.json must retain exactly one root object.")
	else:
		var root: Dictionary = rows[0]
		var governing := root.duplicate(true)
		var stripped_plans: Array = []
		var plan_ids: Array = []
		for plan_value in root.get("plans", []):
			var plan: Dictionary = (plan_value as Dictionary).duplicate(true)
			plan_ids.append(str(plan.get("id", "")))
			_check_semantics(plan, failures)
			plan.erase("semantics")
			stripped_plans.append(plan)
		governing["plans"] = stripped_plans
		if plan_ids != EXPECTED_PLANS: failures.append("The exact two-plan catalog or order changed.")
		var governing_hash := JSON.stringify(_canonical(governing)).sha256_text()
		if governing_hash != EXPECTED_GOVERNING_SHA256:
			failures.append("Existing governing heist catalog changed: expected %s found %s." % [EXPECTED_GOVERNING_SHA256, governing_hash])
	if failures.is_empty():
		print("world06_6 heist authored semantics contract passed plans=2 exits=4 failure_beats=4 governing_values=unchanged hidden_surfaces=absent")
		quit(0)
		return
	for failure in failures: push_error(str(failure))
	quit(1)


func _check_semantics(plan: Dictionary, failures: Array) -> void:
	var plan_id := str(plan.get("id", ""))
	var semantics: Dictionary = plan.get("semantics", {}) if typeof(plan.get("semantics", {})) == TYPE_DICTIONARY else {}
	var keys := semantics.keys(); keys.sort()
	if keys != ["actor_roles", "confrontation", "exits", "failure_beats", "object_roles", "phases", "place_roles", "public_verbs"]:
		failures.append("Plan %s lacks its closed public semantic surface." % plan_id)
		return
	for role_key in ["actor_roles", "object_roles", "place_roles", "public_verbs"]:
		if typeof(semantics.get(role_key, [])) != TYPE_ARRAY or (semantics.get(role_key, []) as Array).is_empty(): failures.append("Plan %s has no %s." % [plan_id, role_key])
	var phases: Dictionary = semantics.get("phases", {}) if typeof(semantics.get("phases", {})) == TYPE_DICTIONARY else {}
	var phase_keys := phases.keys(); phase_keys.sort()
	if phase_keys != ["getaway", "plan", "play", "setup"]: failures.append("Plan %s changed the four public heist phases." % plan_id)
	for phase_id in phase_keys: _check_beat(plan_id, "phase:%s" % phase_id, phases.get(phase_id), failures)
	var exits: Dictionary = semantics.get("exits", {}) if typeof(semantics.get("exits", {})) == TYPE_DICTIONARY else {}
	var exit_keys := exits.keys(); exit_keys.sort()
	if exit_keys != EXPECTED_EXITS.get(plan_id, []): failures.append("Plan %s changed its distinct public exits." % plan_id)
	for exit_id in exit_keys: _check_beat(plan_id, "exit:%s" % exit_id, exits.get(exit_id), failures)
	_check_beat(plan_id, "confrontation", semantics.get("confrontation"), failures)
	var confrontation: Dictionary = semantics.get("confrontation", {})
	if not (confrontation.get("verbs", []) as Array).has("hedge"): failures.append("Plan %s confrontation omitted the public hedge verb." % plan_id)
	var failures_map: Dictionary = semantics.get("failure_beats", {}) if typeof(semantics.get("failure_beats", {})) == TYPE_DICTIONARY else {}
	if failures_map.size() != 2: failures.append("Plan %s must expose two distinct public failure beats." % plan_id)
	var aftermaths := {}
	for failure_id in failures_map.keys():
		_check_beat(plan_id, "failure:%s" % failure_id, failures_map.get(failure_id), failures)
		var aftermath := str((failures_map.get(failure_id) as Dictionary).get("aftermath", ""))
		if aftermaths.has(aftermath): failures.append("Plan %s failure beats share an aftermath." % plan_id)
		aftermaths[aftermath] = true
	if _contains_number(semantics): failures.append("Plan %s semantics introduced a governing numeric value." % plan_id)
	var leak := _forbidden_surface(semantics)
	if not leak.is_empty(): failures.append("Plan %s public semantics exposed forbidden surface %s." % [plan_id, leak])


func _check_beat(plan_id: String, beat_id: String, value: Variant, failures: Array) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		failures.append("Plan %s %s is not an authored public beat." % [plan_id, beat_id]); return
	var beat: Dictionary = value
	var keys := beat.keys(); keys.sort()
	if keys != ["actors", "aftermath", "objects", "place", "verbs"]:
		failures.append("Plan %s %s lacks place/actor/object/verb/aftermath fields." % [plan_id, beat_id]); return
	if str(beat.get("place", "")).is_empty() or typeof(beat.get("actors", [])) != TYPE_ARRAY or (beat.get("actors", []) as Array).is_empty() or typeof(beat.get("objects", [])) != TYPE_ARRAY or (beat.get("objects", []) as Array).is_empty() or typeof(beat.get("verbs", [])) != TYPE_ARRAY or (beat.get("verbs", []) as Array).is_empty():
		failures.append("Plan %s %s has an empty public staging descriptor." % [plan_id, beat_id])
	var aftermath: Variant = beat.get("aftermath")
	if not (typeof(aftermath) == TYPE_STRING and not str(aftermath).is_empty()) and not (typeof(aftermath) == TYPE_ARRAY and not (aftermath as Array).is_empty()): failures.append("Plan %s %s lacks public aftermath." % [plan_id, beat_id])


static func _forbidden_surface(value: Variant) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		for key in (value as Dictionary).keys():
			var key_text := str(key).to_lower()
			for forbidden in FORBIDDEN_SURFACES:
				if key_text.contains(forbidden): return "%s:key" % forbidden
			var child := _forbidden_surface((value as Dictionary).get(key))
			if not child.is_empty(): return child
	elif typeof(value) == TYPE_ARRAY:
		for child_value in value as Array:
			var child := _forbidden_surface(child_value)
			if not child.is_empty(): return child
	elif typeof(value) == TYPE_STRING:
		var text := str(value).to_lower()
		if text.contains("crew_"): return "member_identity:value"
		for forbidden in FORBIDDEN_SURFACES:
			if text.contains(forbidden): return "%s:value" % forbidden
	return ""


static func _contains_number(value: Variant) -> bool:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]: return true
	if typeof(value) == TYPE_DICTIONARY:
		for child in (value as Dictionary).values():
			if _contains_number(child): return true
	if typeof(value) == TYPE_ARRAY:
		for child in value as Array:
			if _contains_number(child): return true
	return false


static func _canonical(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var result := {}; var keys := (value as Dictionary).keys(); keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key in keys: result[str(key)] = _canonical((value as Dictionary).get(key))
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for entry in value as Array: result.append(_canonical(entry))
		return result
	return value


static func _load_array(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Array).duplicate(true) if typeof(parsed) == TYPE_ARRAY else []
