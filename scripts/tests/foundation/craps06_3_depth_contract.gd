extends SceneTree

const PACKAGE_PATH := "res://data/games/rituals/craps06_3_sequences.json"
const MODULE_PATH := "res://scripts/games/craps.gd"

var failures: Array[String] = []


func _init() -> void:
	var package := _load_json(PACKAGE_PATH)
	_check_package(package)
	_check_module(FileAccess.get_file_as_string(MODULE_PATH))
	if failures.is_empty():
		print("CRAPS06_3_DEPTH_CONTRACT PASS profiles=5 contract=game_ritual/1")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_ARRAY or (parsed as Array).size() != 1 or typeof((parsed as Array)[0]) != TYPE_DICTIONARY:
		failures.append("Ritual package is not a one-record JSON data array.")
		return {}
	return (parsed as Array)[0] as Dictionary


func _check_package(package: Dictionary) -> void:
	if str(package.get("contract", "")) != "game_ritual/1":
		failures.append("Ritual package does not consume frozen game_ritual/1.")
	if str(package.get("contract_head", "")) != "a2760d816c781e711ff0923c296f97b786662453":
		failures.append("Ritual package is not pinned to the owner-frozen contract head.")
	var profiles: Array = package.get("profiles", []) if typeof(package.get("profiles", [])) == TYPE_ARRAY else []
	var expected := ["craps.ordinary_casino", "craps.hot_high_stakes", "craps.security_audit", "craps.ordinary_street", "craps.interrupted_street"]
	var seen: Array[String] = []
	for value in profiles:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var profile := value as Dictionary
		seen.append(str(profile.get("id", "")))
		for key in ["initial_phase", "phases", "required_actions", "actors", "objects", "material_operations", "required_facts"]:
			if not profile.has(key) or (typeof(profile.get(key)) == TYPE_ARRAY and (profile.get(key) as Array).is_empty()):
				failures.append("%s lacks %s." % [str(profile.get("id", "profile")), key])
		if not (profile.get("phases", []) as Array).has(str(profile.get("initial_phase", ""))):
			failures.append("%s initial phase is unreachable." % str(profile.get("id", "profile")))
	if seen != expected:
		failures.append("Required five-profile order/identity changed: %s" % JSON.stringify(seen))
	var persistence: Dictionary = package.get("persistence", {}) if typeof(package.get("persistence", {})) == TYPE_DICTIONARY else {}
	for class_id in ["authoritative", "derived", "transient", "one_shot"]:
		if not persistence.has(class_id):
			failures.append("Persistence class %s is absent." % class_id)
	if not bool((package.get("rejection_policy", {}) as Dictionary).get("side_effect_free", false)):
		failures.append("Rejections are not declared side-effect-free.")


func _check_module(source: String) -> void:
	var required_tokens := [
		"craps_remove", "craps_undo", "craps_repeat", "craps_rebet",
		"craps_throw_origin", "THROW_MIN_DISTANCE", "THROW_MAX_DISTANCE",
		"available_funds", "at_risk_working_stake", "last_returned_stake", "last_payout",
		"street_warning", "street_lookout_warning", "\"dispersal\"",
		"content_fingerprint", "receipt_key", "ritual_sequence",
	]
	for token in required_tokens:
		if source.find(token) < 0:
			failures.append("Craps implementation lacks required seam: %s" % token)
	if source.find("Time.get_ticks_msec") >= 0:
		failures.append("Craps authoritative module reads wall-clock ticks.")
