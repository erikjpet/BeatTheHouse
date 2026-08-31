class_name CrewStateModel
extends RefCounted

# Data and normalization contract for within-run Crew trust, jobs, and The Turn ledger.

const CREW_CONFIG_PATH := "res://data/crew/crew.json"
const CREW_JOBS_PATH := "res://data/crew/jobs.json"
const CrewPokerModelScript := preload("res://scripts/core/crew_poker_model.gd")
const STATE_SCHEMA_VERSION := 1
const JOB_EXECUTION_SCHEMA_VERSION := 1
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
const JOB_KINDS := ["package_run", "numbers_route", "lookout_hold", "stake_horse", "collection", "package_delivery", "numbers_collection"]

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


static func job_definitions_for_member(member_id: String) -> Array:
	_ensure_job_cache()
	var result: Array = []
	for job_id_value in _job_cache.keys():
		var definition_value: Variant = _job_cache.get(job_id_value, {})
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = definition_value
		if str(definition.get("member_id", "")) == member_id:
			result.append(definition.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("id", "")) < str(b.get("id", "")))
	return result


static func job_definitions() -> Array:
	_ensure_job_cache()
	var result: Array = []
	for job_id_value in _job_cache.keys():
		var definition_value: Variant = _job_cache.get(job_id_value, {})
		if typeof(definition_value) == TYPE_DICTIONARY:
			result.append((definition_value as Dictionary).duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("id", "")) < str(b.get("id", "")))
	return result


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
		"label": str(value.get("label", definition_id.replace("_", " ").capitalize())).strip_edges(),
		"member_id": member_id,
		"kind": str(value.get("kind", "")).strip_edges(),
		"min_rank": str(value.get("min_rank", "associate")).strip_edges(),
		"payload": (value.get("payload", {}) as Dictionary).duplicate(true) if typeof(value.get("payload", {})) == TYPE_DICTIONARY else {},
		"semantics": (value.get("semantics", {}) as Dictionary).duplicate(true) if typeof(value.get("semantics", {})) == TYPE_DICTIONARY else {},
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


# Additive player-safe Layer 3 projections. Residency is supplied by the
# authoritative itinerary owner; this model only renders member/job state.
static func layer3_room_state(resident_member_ids: Array, trust_value: Variant, grievances_value: Variant, jobs_value: Variant) -> Dictionary:
	var trust := normalize_trust(trust_value)
	var grievances := normalize_grievances(grievances_value)
	var jobs := normalize_jobs(jobs_value)
	var residents: Array = []
	for member_value in resident_member_ids:
		var member_id := str(member_value).strip_edges()
		if MEMBER_IDS.has(member_id) and not residents.has(member_id): residents.append(member_id)
	residents.sort()
	var members: Array = []
	for member_id in residents: members.append(member_public_state(member_id, int(trust.get(member_id, 0)), grievances, jobs, true))
	return {
		"schema_version": JOB_EXECUTION_SCHEMA_VERSION,
		"occupancy_count": members.size(),
		"resident_member_ids": residents,
		"members": members,
		"objects": layer3_service_states(trust, residents, jobs),
	}


static func member_public_state(member_id: String, trust: int, grievances_value: Variant, jobs_value: Variant, resident: bool = false) -> Dictionary:
	if not MEMBER_IDS.has(member_id): return {}
	var grievances: Array = []
	for grievance in normalize_grievances(grievances_value):
		if str(grievance.get("member_id", "")) == member_id:
			grievances.append({"id": str(grievance.get("id", "")), "kind": str(grievance.get("kind", ""))})
	var active_job_ids: Array = []
	for job_value in normalize_jobs(jobs_value).values():
		var job: Dictionary = job_value
		if str(job.get("member_id", "")) == member_id and str(job.get("status", "")) in ["accepted", "active"]: active_job_ids.append(str(job.get("id", "")))
	active_job_ids.sort()
	var rank := rank_for_trust(trust)
	return {
		"member_id": member_id,
		"resident": resident,
		"rank": rank,
		"pose": "working" if not active_job_ids.is_empty() else ("guarded" if not grievances.is_empty() else "at_ease"),
		"behavior_state": "job_out" if not active_job_ids.is_empty() else ("aggrieved" if not grievances.is_empty() else "available"),
		"active_job_ids": active_job_ids,
		"grievances": grievances,
	}


static func layer3_service_states(trust_value: Variant, resident_member_ids: Array, jobs_value: Variant = {}) -> Array:
	var trust := normalize_trust(trust_value)
	var jobs := normalize_jobs(jobs_value)
	var services := config().get("member_services", {}) as Dictionary
	var active_members := {}
	for job_value in jobs.values():
		var job: Dictionary = job_value
		if str(job.get("status", "")) in ["accepted", "active"]: active_members[str(job.get("member_id", ""))] = true
	var result: Array = [
		_service("job_board", "crew_job_board", "open", "", true),
		_service("numbers_desk", "numbers_desk", "available", "crew_lucky", resident_member_ids.has("crew_lucky")),
		_service("planning_table", "crew_planning_table", "waiting", "", true),
		_service("mags_bench", "crew_mags_bench", "in_use" if active_members.has("crew_mags") else "ready", "crew_mags", resident_member_ids.has("crew_mags")),
		_service("rook_ride", "crew_rook_ride", "in_use" if active_members.has("crew_rook") else "ready", "crew_rook", resident_member_ids.has("crew_rook")),
		_service("practice_rig", "crew_practice_rig", "ready", "", true),
	]
	for row in result:
		match str(row.get("id", "")):
			"practice_rig": row["successes_required"] = int(services.get("practice_rig_successes_required", 2))
			"rook_ride":
				var rank := rank_for_trust(int(trust.get("crew_rook", 0)))
				row["uses"] = int((services.get("rook_ride_uses_by_rank", {}) as Dictionary).get(rank, 0))
				row["discount_percent"] = int((services.get("rook_ride_discount_percent_by_rank", {}) as Dictionary).get(rank, 0))
			"mags_bench": row["catalog_ready"] = true
	return result


static func new_job_execution(definition_id: String, instance_id: String, offered_action: int = 0) -> Dictionary:
	var definition := job_definition(definition_id)
	var clean_id := instance_id.strip_edges()
	if definition.is_empty() or clean_id.is_empty(): return {}
	return {
		"schema_version": JOB_EXECUTION_SCHEMA_VERSION,
		"instance_id": clean_id,
		"definition_id": definition_id,
		"member_id": str(definition.get("member_id", "")),
		"kind": str(definition.get("kind", "")),
		"phase": "offered_proposal",
		"offered_action": maxi(0, offered_action),
		"expires_at_action": maxi(0, offered_action) + int(definition.get("expiry_in_actions", 1)),
		"payload": (definition.get("payload", {}) as Dictionary).duplicate(true),
		"verbs": job_proposal_verbs(str(definition.get("kind", ""))),
		"definition_fingerprint": _job_fingerprint(definition),
		"step_index": 0,
		"evidence_claims": [],
		"proposal_chain": [],
		"proposal_sequence": 0,
		"outcome_proposal": "",
		"authoritative": false,
		"authority_gap": "host_commitment_not_verifiable_in_model",
	}


static func normalize_job_execution(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY: return {}
	var state: Dictionary = (value as Dictionary).duplicate(true)
	var exact := ["authoritative", "authority_gap", "definition_fingerprint", "definition_id", "evidence_claims", "expires_at_action", "instance_id", "kind", "member_id", "offered_action", "outcome_proposal", "payload", "phase", "proposal_chain", "proposal_sequence", "schema_version", "step_index", "verbs"]
	var keys := state.keys(); keys.sort()
	if keys != exact or int(state.get("schema_version", 0)) != JOB_EXECUTION_SCHEMA_VERSION or bool(state.get("authoritative", true)): return {}
	var definition := job_definition(str(state.get("definition_id", "")))
	if definition.is_empty() or str(state.get("instance_id", "")).strip_edges().is_empty() or int(state.get("offered_action", -1)) < 0 or str(state.get("definition_fingerprint", "")) != _job_fingerprint(definition) or str(state.get("member_id", "")) != str(definition.get("member_id", "")) or str(state.get("kind", "")) != str(definition.get("kind", "")) or state.get("payload", {}) != definition.get("payload", {}): return {}
	if state.get("verbs", []) != job_proposal_verbs(str(state.get("kind", ""))) or typeof(state.get("evidence_claims", [])) != TYPE_ARRAY: return {}
	if str(state.get("phase", "")) != "offered_proposal" or int(state.get("step_index", -1)) != 0 or not (state.get("evidence_claims", []) as Array).is_empty() or not str(state.get("outcome_proposal", "")).is_empty(): return {}
	if int(state.get("expires_at_action", -1)) != int(state.get("offered_action", 0)) + int(definition.get("expiry_in_actions", 0)): return {}
	if bool(state.get("authoritative", true)) or str(state.get("authority_gap", "")) != "host_commitment_not_verifiable_in_model": return {}
	if typeof(state.get("proposal_chain", [])) != TYPE_ARRAY or not (state.get("proposal_chain", []) as Array).is_empty() or int(state.get("proposal_sequence", -1)) != 0: return {}
	return state


static func apply_job_action(state_value: Variant, receipt_key: String, action: String, context: Dictionary = {}) -> Dictionary:
	var state := normalize_job_execution(state_value)
	# This model has no host-rooted job/game/world authority. Caller-authored
	# dictionaries cannot authenticate an offer, played fact, terminal result,
	# or deadline. Preserve the exact projection until the host supplies such a
	# root through an integration-owned API outside this row.
	var _ignored_proposal := {"proposal_id": receipt_key, "action": action, "context": context}
	return state


static func job_execution_public_state(value: Variant) -> Dictionary:
	var state := normalize_job_execution(value)
	if state.is_empty(): return {}
	return {"instance_id": str(state.get("instance_id", "")), "definition_id": str(state.get("definition_id", "")), "member_id": str(state.get("member_id", "")), "kind": str(state.get("kind", "")), "phase": str(state.get("phase", "")), "expires_at_action": int(state.get("expires_at_action", 0)), "outcome_proposal": str(state.get("outcome_proposal", "")), "step_index": int(state.get("step_index", 0)), "step_count": (state.get("verbs", []) as Array).size(), "authoritative": false, "authority_gap": "host_commitment_not_verifiable_in_model", "requires": ["host_job_record", "host_game_or_world_evidence"]}


static func _service(id: String, object_id: String, state: String, operator_id: String, occupied: bool) -> Dictionary:
	return {"id": id, "object_id": object_id, "state": state, "operator_id": operator_id, "occupied": occupied, "reachable": true}


static func job_proposal_verbs(kind: String) -> Array:
	for definition in job_definitions():
		if str(definition.get("kind", "")) != kind:
			continue
		var semantics: Dictionary = definition.get("semantics", {}) if typeof(definition.get("semantics", {})) == TYPE_DICTIONARY else {}
		return _string_array(semantics.get("public_verbs", []))
	return []


static func _job_fingerprint(value: Variant) -> String:
	return JSON.stringify(_canonical_job_value(value)).sha256_text()


static func _canonical_job_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var result := {}; var keys := (value as Dictionary).keys(); keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key in keys: result[str(key)] = _canonical_job_value((value as Dictionary).get(key))
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for entry in value as Array: result.append(_canonical_job_value(entry))
		return result
	return value


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
	var member_rank_perks: Dictionary = source.get("member_rank_perks", {}) if typeof(source.get("member_rank_perks", {})) == TYPE_DICTIONARY else {}
	for member_id in MEMBER_IDS:
		var gates: Dictionary = member_rank_perks.get(member_id, {}) if typeof(member_rank_perks.get(member_id, {})) == TYPE_DICTIONARY else {}
		if not _string_array(gates.get("associate", [])).has("member_jobs"):
			failures.append("crew.json %s must open member jobs at Associate." % member_id)
		for rank_id_value in gates.keys():
			var rank_id := str(rank_id_value)
			if not RANK_IDS.has(rank_id) or _string_array(gates.get(rank_id_value, [])).is_empty():
				failures.append("crew.json %s has an invalid or empty %s perk gate." % [member_id, rank_id])
	var member_services: Dictionary = source.get("member_services", {}) if typeof(source.get("member_services", {})) == TYPE_DICTIONARY else {}
	if int(member_services.get("switch_intel_uses_per_visit", 0)) <= 0 or int(member_services.get("knuckles_stash_cap", 0)) <= 0:
		failures.append("crew.json member service caps must be positive.")
	var ride_caps: Dictionary = member_services.get("rook_ride_uses_by_rank", {}) if typeof(member_services.get("rook_ride_uses_by_rank", {})) == TYPE_DICTIONARY else {}
	var ride_discounts: Dictionary = member_services.get("rook_ride_discount_percent_by_rank", {}) if typeof(member_services.get("rook_ride_discount_percent_by_rank", {})) == TYPE_DICTIONARY else {}
	for rank_id in ["associate", "made", "inner_circle"]:
		if int(ride_caps.get(rank_id, 0)) <= 0 or not range(0, 101).has(int(ride_discounts.get(rank_id, -1))):
			failures.append("crew.json Rook ride tuning is invalid for %s." % rank_id)
	if int(member_services.get("practice_rig_successes_required", 0)) <= 0:
		failures.append("crew.json Practice Rig threshold must be positive.")
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
		if normalized.is_empty() or not JOB_KINDS.has(str(normalized.get("kind", ""))):
			failures.append("jobs.json job %s has an invalid member, kind, reward, or failure contract." % job_id)
		elif not RANK_IDS.has(str(normalized.get("min_rank", ""))):
			failures.append("jobs.json job %s has an invalid rank gate." % job_id)
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
	normalized["label"] = str(value.get("label", normalized["definition_id"].replace("_", " ").capitalize())).strip_edges()
	normalized["member_id"] = member_id
	normalized["kind"] = str(value.get("kind", "")).strip_edges()
	normalized["min_rank"] = str(value.get("min_rank", "associate")).strip_edges()
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
