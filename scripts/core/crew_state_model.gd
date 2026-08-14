class_name CrewStateModel
extends RefCounted

# Data and normalization contract for within-run Crew trust, jobs, and The Turn ledger.

const CREW_CONFIG_PATH := "res://data/crew/crew.json"
const CREW_JOBS_PATH := "res://data/crew/jobs.json"
const CrewPokerModelScript := preload("res://scripts/core/crew_poker_model.gd")
const STATE_SCHEMA_VERSION := 1
const MEMBER_IDS := [
	"crew_rook",
	"crew_velvet",
	"crew_knuckles",
	"crew_switch",
	"crew_mags",
	"crew_bishop",
	"crew_lucky",
]
const RANK_IDS := ["stranger", "marker", "associate", "made", "inner_circle"]
const GRIEVANCE_KINDS := [
	"job_abandoned",
	"stake_horse_loss_shrugged",
	"distraction_heat_dumped",
	"wrong_accusation",
	"favor_converted_unpaid",
	"numbers_past_posting_in_colors",
]
const JOB_OUTCOMES := ["success", "failed", "abandoned"]

static var _config_cache: Dictionary = {}
static var _job_cache: Dictionary = {}


static func config() -> Dictionary:
	if _config_cache.is_empty():
		var rows := _load_array(CREW_CONFIG_PATH)
		if not rows.is_empty() and typeof(rows[0]) == TYPE_DICTIONARY:
			_config_cache = (rows[0] as Dictionary).duplicate(true)
	return _config_cache.duplicate(true)


static func job_definition(job_id: String) -> Dictionary:
	_ensure_job_cache()
	var definition: Variant = _job_cache.get(job_id, {})
	return (definition as Dictionary).duplicate(true) if typeof(definition) == TYPE_DICTIONARY else {}


static func default_trust() -> Dictionary:
	var result := {}
	for member_id in MEMBER_IDS:
		result[member_id] = 0
	return result


static func normalize_trust(value: Variant) -> Dictionary:
	var source: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var result := default_trust()
	for member_id in MEMBER_IDS:
		result[member_id] = maxi(0, int(source.get(member_id, 0)))
	return result


static func rank_threshold(rank_id: String) -> int:
	for threshold_value in config().get("rank_thresholds", []):
		if typeof(threshold_value) != TYPE_DICTIONARY:
			continue
		var threshold: Dictionary = threshold_value
		if str(threshold.get("id", "")) == rank_id:
			return maxi(0, int(threshold.get("trust", 0)))
	return 0


static func rank_for_trust(trust: int) -> String:
	var result := "stranger"
	for threshold_value in config().get("rank_thresholds", []):
		if typeof(threshold_value) != TYPE_DICTIONARY:
			continue
		var threshold: Dictionary = threshold_value
		if trust < int(threshold.get("trust", 0)):
			break
		result = str(threshold.get("id", result))
	return result


static func normalize_grievances(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var member_id := str(entry.get("member_id", "")).strip_edges()
		var kind := str(entry.get("kind", "")).strip_edges()
		if not MEMBER_IDS.has(member_id) or not GRIEVANCE_KINDS.has(kind):
			continue
		result.append({
			"id": str(entry.get("id", "")).strip_edges(),
			"member_id": member_id,
			"kind": kind,
			"weight": maxi(1, int(entry.get("weight", 1))),
			"turn_recorded": maxi(0, int(entry.get("turn_recorded", 0))),
			"source_ref": str(entry.get("source_ref", "")).strip_edges(),
		})
	return result


static func normalize_jobs(value: Variant) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for instance_id_value in (value as Dictionary).keys():
		var instance_id := str(instance_id_value).strip_edges()
		var job_value: Variant = (value as Dictionary).get(instance_id_value, {})
		if instance_id.is_empty() or typeof(job_value) != TYPE_DICTIONARY:
			continue
		var job := _normalize_job_instance(job_value as Dictionary, instance_id)
		if not job.is_empty():
			result[instance_id] = job
	return result


static func normalize_job_definition(value: Dictionary) -> Dictionary:
	var definition_id := str(value.get("id", "")).strip_edges()
	var member_id := str(value.get("member_id", "")).strip_edges()
	if definition_id.is_empty() or not MEMBER_IDS.has(member_id):
		return {}
	var failure: Dictionary = value.get("failure", {}) if typeof(value.get("failure", {})) == TYPE_DICTIONARY else {}
	var grievance_kind := str(failure.get("grievance_kind", "")).strip_edges()
	if not grievance_kind.is_empty() and not GRIEVANCE_KINDS.has(grievance_kind):
		return {}
	var rewards: Dictionary = value.get("rewards", {}) if typeof(value.get("rewards", {})) == TYPE_DICTIONARY else {}
	return {
		"id": definition_id,
		"member_id": member_id,
		"kind": str(value.get("kind", "")).strip_edges(),
		"payload": (value.get("payload", {}) as Dictionary).duplicate(true) if typeof(value.get("payload", {})) == TYPE_DICTIONARY else {},
		"expiry_in_actions": maxi(1, int(value.get("expiry_in_actions", 1))),
		"rewards": {
			"cash": maxi(0, int(rewards.get("cash", 0))),
			"trust": int(rewards.get("trust", 0)),
		},
		"failure": {
			"trust": int(failure.get("trust", 0)),
			"grievance_kind": grievance_kind,
			"grievance_weight": maxi(1, int(failure.get("grievance_weight", 1))),
		},
	}


static func validate_content() -> Array:
	var failures: Array = []
	var config_rows := _load_array(CREW_CONFIG_PATH)
	if config_rows.size() != 1 or typeof(config_rows[0]) != TYPE_DICTIONARY:
		failures.append("crew.json must contain exactly one configuration object.")
		return failures
	var source: Dictionary = config_rows[0]
	if int(source.get("schema_version", 0)) != STATE_SCHEMA_VERSION:
		failures.append("crew.json schema_version must match CrewStateModel.")
	if _string_array(source.get("member_ids", [])) != MEMBER_IDS:
		failures.append("crew.json member_ids must contain the seven authored crew ids in contract order.")
	var thresholds: Array = source.get("rank_thresholds", []) if typeof(source.get("rank_thresholds", [])) == TYPE_ARRAY else []
	var previous := -1
	var rank_ids: Array = []
	for threshold_value in thresholds:
		if typeof(threshold_value) != TYPE_DICTIONARY:
			continue
		var threshold: Dictionary = threshold_value
		rank_ids.append(str(threshold.get("id", "")))
		var amount := int(threshold.get("trust", -1))
		if amount <= previous:
			failures.append("crew.json rank thresholds must increase strictly.")
		previous = amount
	if rank_ids != RANK_IDS:
		failures.append("crew.json rank ladder does not match the binding five ranks.")
	if _string_array(source.get("grievance_kinds", [])) != GRIEVANCE_KINDS:
		failures.append("crew.json grievance taxonomy does not match the binding ledger kinds.")
	var heist_requirements: Dictionary = source.get("heist_requirements", {}) if typeof(source.get("heist_requirements", {})) == TYPE_DICTIONARY else {}
	for plan_id in heist_requirements.keys():
		for member_id in _string_array(heist_requirements.get(plan_id, [])):
			if not MEMBER_IDS.has(member_id):
				failures.append("crew.json heist requirement %s references unknown member %s." % [plan_id, member_id])
	var job_ids := {}
	var job_rows := _load_array(CREW_JOBS_PATH)
	if job_rows.is_empty():
		failures.append("jobs.json must contain at least the Crew favor proof job.")
	for job_value in job_rows:
		if typeof(job_value) != TYPE_DICTIONARY:
			failures.append("jobs.json entries must be objects.")
			continue
		var job: Dictionary = job_value
		var normalized := normalize_job_definition(job)
		var job_id := str(job.get("id", "")).strip_edges()
		if normalized.is_empty() or str(normalized.get("kind", "")).is_empty():
			failures.append("jobs.json job %s has an invalid member, kind, reward, or failure contract." % job_id)
		elif job_ids.has(job_id):
			failures.append("jobs.json contains duplicate id %s." % job_id)
		job_ids[job_id] = true
	if not job_ids.has("crew_favor_delivery"):
		failures.append("jobs.json is missing the Crew favor proof job.")
	failures.append_array(CrewPokerModelScript.validate_content(MEMBER_IDS))
	return failures


static func _normalize_job_instance(value: Dictionary, instance_id: String) -> Dictionary:
	var member_id := str(value.get("member_id", "")).strip_edges()
	var status := str(value.get("status", "offered")).strip_edges()
	if not MEMBER_IDS.has(member_id) or not ["offered", "accepted", "active", "resolved"].has(status):
		return {}
	var outcome := str(value.get("outcome", "")).strip_edges()
	if not outcome.is_empty() and not JOB_OUTCOMES.has(outcome):
		return {}
	var normalized := value.duplicate(true)
	normalized["id"] = instance_id
	normalized["definition_id"] = str(value.get("definition_id", instance_id)).strip_edges()
	normalized["member_id"] = member_id
	normalized["kind"] = str(value.get("kind", "")).strip_edges()
	normalized["status"] = status
	normalized["outcome"] = outcome
	normalized["payload"] = (value.get("payload", {}) as Dictionary).duplicate(true) if typeof(value.get("payload", {})) == TYPE_DICTIONARY else {}
	var rewards: Dictionary = value.get("rewards", {}) if typeof(value.get("rewards", {})) == TYPE_DICTIONARY else {}
	normalized["rewards"] = {
		"cash": maxi(0, int(rewards.get("cash", 0))),
		"trust": int(rewards.get("trust", 0)),
	}
	var failure: Dictionary = value.get("failure", {}) if typeof(value.get("failure", {})) == TYPE_DICTIONARY else {}
	normalized["failure"] = {
		"trust": int(failure.get("trust", 0)),
		"grievance_kind": str(failure.get("grievance_kind", "")).strip_edges(),
		"grievance_weight": maxi(1, int(failure.get("grievance_weight", 1))),
	}
	normalized["expiry_in_actions"] = maxi(1, int(value.get("expiry_in_actions", 1)))
	normalized["offered_action"] = maxi(0, int(value.get("offered_action", 0)))
	normalized["expires_at_action"] = maxi(normalized["offered_action"] + 1, int(value.get("expires_at_action", normalized["offered_action"] + 1)))
	for action_key in ["accepted_action", "active_action", "resolved_action"]:
		if value.has(action_key):
			normalized[action_key] = maxi(0, int(value.get(action_key, 0)))
	return normalized


static func _ensure_job_cache() -> void:
	if not _job_cache.is_empty():
		return
	for job_value in _load_array(CREW_JOBS_PATH):
		if typeof(job_value) != TYPE_DICTIONARY:
			continue
		var definition := normalize_job_definition(job_value as Dictionary)
		if not definition.is_empty():
			_job_cache[str(definition.get("id", ""))] = definition


static func _load_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Array).duplicate(true) if typeof(parsed) == TYPE_ARRAY else []


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value:
		var entry := str(entry_value).strip_edges()
		if not entry.is_empty():
			result.append(entry)
	return result
