extends SceneTree

const JOBS_PATH := "res://data/crew/jobs.json"
const RECRUITMENT_PATH := "res://data/crew/recruitment.json"
const JOB_IDS := [
	"crew_favor_delivery", "rook_quiet_package", "switch_two_stop_signal", "lucky_book_rounds",
	"bishop_camera_window", "velvet_lounge_lookout", "mags_low_roller_stake", "velvet_queen_stake",
	"lucky_slot_stake", "knuckles_friendly_collection", "knuckles_hard_collection",
	"bishop_cage_packet", "switch_weather_packet",
]
const KINDS := ["collection", "lookout_hold", "numbers_route", "package_delivery", "package_run", "stake_horse"]
const MEMBERS := ["crew_rook", "crew_switch", "crew_mags", "crew_knuckles", "crew_velvet", "crew_bishop", "crew_lucky"]
const BACK_ROOM_OBJECTS := ["job_board", "numbers_desk", "planning_table", "mags_bench", "rook_ride", "practice_rig"]


func _initialize() -> void:
	var failures: Array = []
	var jobs := _load_array(JOBS_PATH)
	var recruitment := _dict(_load_array(RECRUITMENT_PATH)[0]) if not _load_array(RECRUITMENT_PATH).is_empty() else {}
	_check_job_catalog(jobs, failures)
	_check_recruitment_paths(recruitment, failures)
	_check_back_room(recruitment, failures)
	_check_semantics_non_economic(jobs, recruitment, failures)
	if failures.is_empty():
		print("world06_4 authored semantics contract passed")
		quit(0)
		return
	for failure in failures:
		push_error(str(failure))
	quit(1)


func _check_job_catalog(jobs: Array, failures: Array) -> void:
	var ids: Array = []
	var kinds: Array = []
	for row_value in jobs:
		var row := _dict(row_value)
		ids.append(str(row.get("id", "")))
		if not kinds.has(str(row.get("kind", ""))): kinds.append(str(row.get("kind", "")))
		var semantics := _dict(row.get("semantics", {}))
		var keys: Array = semantics.keys()
		keys.sort()
		if keys != ["actor_role", "aftermath", "object_role", "place_role", "public_verbs"] \
				or str(semantics.get("actor_role", "")) != str(row.get("member_id", "")) \
				or str(semantics.get("place_role", "")).is_empty() or str(semantics.get("object_role", "")).is_empty() \
				or _strings(semantics.get("public_verbs", [])).size() < 4 or _strings(semantics.get("aftermath", [])).size() < 4:
			failures.append("Job %s lacks its closed place/actor/object/verb/aftermath semantics." % str(row.get("id", "")))
	ids.sort()
	var expected_ids := JOB_IDS.duplicate(); expected_ids.sort()
	kinds.sort()
	if ids != expected_ids or kinds != KINDS:
		failures.append("Authored semantics changed the exact 13-job/six-kind catalog.")


func _check_recruitment_paths(recruitment: Dictionary, failures: Array) -> void:
	if int(recruitment.get("schema_version", 0)) != 1 or int(recruitment.get("associate_trust", -1)) != 30 or int(recruitment.get("presence_rotate_actions", -1)) != 6:
		failures.append("Recruitment semantics changed schema, Associate trust, or presence rotation.")
	var seen: Array = []
	for member_value in _array(recruitment.get("members", [])):
		var member := _dict(member_value)
		var member_id := str(member.get("member_id", ""))
		seen.append(member_id)
		for path_kind in ["primary", "fallback"]:
			var path := _dict(member.get(path_kind, {}))
			var semantics := _dict(path.get("semantics", {}))
			var keys: Array = semantics.keys(); keys.sort()
			if keys != ["actor_role", "aftermath", "object_role", "place_role", "public_verbs"] \
					or str(semantics.get("actor_role", "")) != member_id or str(semantics.get("place_role", "")).is_empty() \
					or str(semantics.get("object_role", "")).is_empty() \
					or _strings(semantics.get("public_verbs", [])) != ["approach", "observe", "speak", "refuse", "defer", "accept"] \
							and _strings(semantics.get("public_verbs", [])) != ["approach", "observe", "wait", "speak", "refuse", "defer", "accept"] \
					or _strings(semantics.get("aftermath", [])) != ["refused", "deferred", "accepted"]:
				failures.append("%s %s path lacks authored public encounter semantics." % [member_id, path_kind])
	if seen != MEMBERS:
		failures.append("Recruitment semantics changed the landed seven-member order.")


func _check_back_room(recruitment: Dictionary, failures: Array) -> void:
	var room := _dict(recruitment.get("back_room_semantics", {}))
	if str(room.get("place_role", "")) != "crew_back_room" or _strings(room.get("occupancy_states", [])) != ["empty", "rotating", "occupied", "in_use"]:
		failures.append("Layer 3 lacks closed public room/occupancy semantics.")
	var object_ids: Array = []
	for object_value in _array(room.get("objects", [])):
		var object := _dict(object_value)
		object_ids.append(str(object.get("object_id", "")))
		var keys: Array = object.keys(); keys.sort()
		if keys != ["actor_role", "aftermath", "object_id", "occupancy_states", "public_verbs", "service_id"] \
				or str(object.get("service_id", "")).is_empty() or str(object.get("actor_role", "")).is_empty() \
				or _strings(object.get("public_verbs", [])).size() < 3 or _strings(object.get("occupancy_states", [])).size() < 2 \
				or _strings(object.get("aftermath", [])).size() < 2:
			failures.append("Back-room object %s lacks service/occupancy/public aftermath semantics." % str(object.get("object_id", "")))
	if object_ids != BACK_ROOM_OBJECTS:
		failures.append("Layer 3 semantic inventory must contain the six declared objects in contract order.")


func _check_semantics_non_economic(jobs: Array, recruitment: Dictionary, failures: Array) -> void:
	var semantics_values: Array = []
	for row_value in jobs: semantics_values.append(_dict(_dict(row_value).get("semantics", {})))
	semantics_values.append(_dict(recruitment.get("back_room_semantics", {})))
	for member_value in _array(recruitment.get("members", [])):
		var member := _dict(member_value)
		semantics_values.append(_dict(_dict(member.get("primary", {})).get("semantics", {})))
		semantics_values.append(_dict(_dict(member.get("fallback", {})).get("semantics", {})))
	for semantics in semantics_values:
		for forbidden in ["cash", "trust", "grievance", "weight", "expiry", "heat", "stake", "reward", "seed", "turn_", "eligible"]:
			if _contains_forbidden_key(semantics, forbidden):
				failures.append("Non-economic authored semantics leaked governing/hidden field %s." % forbidden)
		if _contains_number(semantics):
			failures.append("Non-economic authored semantics introduced a numeric tuning value.")


static func _contains_number(value: Variant) -> bool:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]: return true
	if typeof(value) == TYPE_DICTIONARY:
		for child in (value as Dictionary).values():
			if _contains_number(child): return true
	if typeof(value) == TYPE_ARRAY:
		for child in value as Array:
			if _contains_number(child): return true
	return false


static func _contains_forbidden_key(value: Variant, fragment: String) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		for key_value in (value as Dictionary).keys():
			if str(key_value).to_lower().contains(fragment): return true
			if _contains_forbidden_key((value as Dictionary).get(key_value), fragment): return true
	if typeof(value) == TYPE_ARRAY:
		for child in value as Array:
			if _contains_forbidden_key(child, fragment): return true
	return false


static func _load_array(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Array).duplicate(true) if typeof(parsed) == TYPE_ARRAY else []


static func _strings(value: Variant) -> Array:
	var result: Array = []
	for entry in _array(value): result.append(str(entry))
	return result


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
