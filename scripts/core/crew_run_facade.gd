class_name CrewRunFacade
extends RefCounted

const CrewTurnModelScript := preload("res://scripts/core/crew_turn_model.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")
const PlayerTextScript := preload("res://scripts/ui/player_text.gd")
const COUNT_AUDIT_KNOWLEDGE_FLAG := "crew_heist_count_audit_roster_read"

var trust_by_member: Dictionary = {}
var grievance_ledger: Array = []
var jobs: Dictionary = {}
var grievance_sequence := 0
var job_sequence := 0
var job_host_capability: RefCounted = RefCounted.new()
var recruitment_host_capability: RefCounted = RefCounted.new()
var heist_host_capability: RefCounted = RefCounted.new()
var heist_private_capsule := ""
var heist_private_fingerprint := ""
var private_authority_id := CrewTurnModelScript.new_authority_id()
var pattern_memory: Dictionary = {}
var match_marks: Dictionary = {}
var contraband_stash: Array = []
var recruitment_encounters: Dictionary = {}
var play_state: Dictionary = {}
var heist_state: Dictionary = {}
var _run_ref: WeakRef
var _run:
	get: return _run_ref.get_ref() if _run_ref != null else null
	set(value): _run_ref = weakref(value) if value != null else null

# Compatibility names keep the mechanically moved facade bodies unchanged
# while the shorter backing names make ownership explicit in this file.
var crew_trust_by_member: Dictionary:
	get: return trust_by_member
	set(value): trust_by_member = value
var crew_grievance_ledger: Array:
	get: return grievance_ledger
	set(value): grievance_ledger = value
var crew_jobs: Dictionary:
	get: return jobs
	set(value): jobs = value
var crew_grievance_sequence: int:
	get: return grievance_sequence
	set(value): grievance_sequence = value
var crew_job_sequence: int:
	get: return job_sequence
	set(value): job_sequence = value
var crew_job_host_capability: RefCounted:
	get: return job_host_capability
	set(value): job_host_capability = value
var crew_recruitment_host_capability: RefCounted:
	get: return recruitment_host_capability
	set(value): recruitment_host_capability = value
var crew_heist_host_capability: RefCounted:
	get: return heist_host_capability
	set(value): heist_host_capability = value
var crew_heist_private_capsule: String:
	get: return heist_private_capsule
	set(value): heist_private_capsule = value
var crew_heist_private_fingerprint: String:
	get: return heist_private_fingerprint
	set(value): heist_private_fingerprint = value
var crew_private_authority_id: String:
	get: return private_authority_id
	set(value): private_authority_id = value
var crew_pattern_memory: Dictionary:
	get: return pattern_memory
	set(value): pattern_memory = value
var crew_match_marks: Dictionary:
	get: return match_marks
	set(value): match_marks = value
var crew_contraband_stash: Array:
	get: return contraband_stash
	set(value): contraband_stash = value
var crew_recruitment_encounters: Dictionary:
	get: return recruitment_encounters
	set(value): recruitment_encounters = value
var crew_play_state: Dictionary:
	get: return play_state
	set(value): play_state = value
var crew_heist_state: Dictionary:
	get: return heist_state
	set(value): heist_state = value
var _crew_job_host_capability: RefCounted:
	get: return job_host_capability
	set(value): job_host_capability = value
var _crew_recruitment_host_capability: RefCounted:
	get: return recruitment_host_capability
	set(value): recruitment_host_capability = value
var _crew_heist_host_capability: RefCounted:
	get: return heist_host_capability
	set(value): heist_host_capability = value
var _crew_heist_private_capsule: String:
	get: return heist_private_capsule
	set(value): heist_private_capsule = value
var _crew_heist_private_fingerprint: String:
	get: return heist_private_fingerprint
	set(value): heist_private_fingerprint = value
var _crew_private_authority_id: String:
	get: return private_authority_id
	set(value): private_authority_id = value


func bind(run_state: Object) -> CrewRunFacade:
	_run = run_state
	return self


func trust(member_id: String) -> int:
	return maxi(0, int(trust_by_member.get(member_id, 0))) if CrewStateModelScript.MEMBER_IDS.has(member_id) else 0


func rank(member_id: String) -> String:
	return CrewStateModelScript.rank_for_trust(trust(member_id))


func crew_trust(member_id: String) -> int:
	return trust(member_id)


func crew_rank(member_id: String) -> String:
	return rank(member_id)


func crew_add_trust(member_id: String, amount: int, _reason: String = "") -> int:
	if not CrewStateModelScript.MEMBER_IDS.has(member_id) or amount == 0:
		return crew_trust(member_id)
	var previous := crew_trust(member_id)
	crew_trust_by_member[member_id] = maxi(0, crew_trust(member_id) + amount)
	_run._reconcile_crew_recruitment_perks()
	if crew_trust(member_id) != previous:
		_run._scenario_publish_crew_change(member_id, "trust", crew_trust(member_id))
	return crew_trust(member_id)


func crew_recruit_member(member_id: String, host_capability: RefCounted = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_recruitment_host_capability:
		return {"ok": false, "member_id": member_id}
	if not CrewStateModelScript.MEMBER_IDS.has(member_id) or member_id == "crew_rook":
		return {"ok": false, "member_id": member_id}
	var target := CrewStateModelScript.rank_threshold("associate")
	if crew_trust(member_id) < target:
		crew_add_trust(member_id, target - crew_trust(member_id), "recruitment_intro")
	return {"ok": crew_rank(member_id) == "associate" or CrewStateModelScript.RANK_IDS.find(crew_rank(member_id)) > CrewStateModelScript.RANK_IDS.find("associate"), "member_id": member_id, "rank": crew_rank(member_id)}


func crew_meet_member(member_id: String, host_capability: RefCounted = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_recruitment_host_capability:
		return {"ok": false, "member_id": member_id}
	if not CrewStateModelScript.MEMBER_IDS.has(member_id) or member_id == "crew_rook":
		return {"ok": false, "member_id": member_id}
	var target := CrewStateModelScript.rank_threshold("marker")
	if crew_trust(member_id) < target:
		crew_add_trust(member_id, target - crew_trust(member_id), "recruitment_contact")
	return {"ok": CrewStateModelScript.RANK_IDS.find(crew_rank(member_id)) >= CrewStateModelScript.RANK_IDS.find("marker"), "member_id": member_id, "rank": crew_rank(member_id)}


func crew_record_recruitment_event_result(result: Dictionary) -> Dictionary:
	if not bool(result.get("ok", false)) or str(result.get("type", "")) != "event":
		return {"ok": false, "reason": "not_resolved_event"}
	var event_id := str(result.get("event_id", result.get("source_id", ""))).strip_edges()
	var choice_id := str(result.get("choice_id", result.get("action_id", ""))).strip_edges()
	if event_id.is_empty() or choice_id.is_empty() or not JsonCoerceScript._copy_array(_run.current_environment.get("event_ids", [])).has(event_id) \
			or JsonCoerceScript._copy_array(_run.current_environment.get("resolved_event_ids", [])).has(event_id):
		return {"ok": false, "reason": "event_not_live"}
	var member_id := ""
	var definition: Dictionary = {}
	for candidate_id in CrewStateModelScript.MEMBER_IDS:
		var candidate = _run.CrewRecruitmentModelScript.member_definition(str(candidate_id))
		if str(candidate.get("event_id", "")) == event_id:
			member_id = str(candidate_id)
			definition = candidate
			break
	if member_id.is_empty() or member_id == "crew_rook":
		return {"ok": false, "reason": "not_first_meeting"}
	var path_kind = _run.CrewRecruitmentModelScript.placement_kind(_run, _run.current_environment, definition)
	if path_kind.is_empty():
		return {"ok": false, "reason": "placement_changed"}
	var outcome := "refused" if choice_id.begins_with("leave_") else "deferred"
	var hooks := JsonCoerceScript._copy_array(JsonCoerceScript._copy_dict(result.get("deltas", {})).get("event_hooks", []))
	var recruit_hook := false
	var meet_hook := false
	for hook_value in hooks:
		var hook := JsonCoerceScript._copy_dict(hook_value)
		if str(hook.get("member_id", "")) != member_id:
			continue
		recruit_hook = recruit_hook or str(hook.get("type", "")) == "crew_recruit"
		meet_hook = meet_hook or str(hook.get("type", "")) == "crew_meet"
	if recruit_hook:
		outcome = "accepted"
	elif not meet_hook and not choice_id.begins_with("leave_"):
		return {"ok": false, "reason": "choice_has_no_recruitment_outcome"}
	var proposal = _run.CrewRecruitmentModelScript.first_meeting_proposal(_run, _run.current_environment, member_id, path_kind, outcome)
	if str(proposal.get("reason", "")) != "adapter_host_root_unavailable" or str(proposal.get("event_id", "")) != event_id:
		return {"ok": false, "reason": "proposal_mismatch"}
	var state = _run.CrewRecruitmentModelScript.normalize_encounter_state(crew_recruitment_encounters)
	if state.is_empty():
		state = _run.CrewRecruitmentModelScript.new_encounter_state()
	var meetings := JsonCoerceScript._copy_dict(state.get("meetings", {}))
	var previous := JsonCoerceScript._copy_dict(meetings.get(member_id, {}))
	if str(previous.get("outcome", "")) == "accepted":
		return {"ok": true, "replayed": true, "public_state": _run.CrewRecruitmentModelScript.encounter_public_state(state, member_id)}
	var action_index := _crew_action_index()
	var fact := {"path_kind": path_kind, "outcome": outcome, "action_index": action_index}
	var history := JsonCoerceScript._copy_array(previous.get("history", []))
	if history.is_empty() or history.back() != fact:
		history.append(fact)
	meetings[member_id] = {
		"member_id": member_id,
		"first_path_kind": str(previous.get("first_path_kind", path_kind)),
		"first_outcome": str(previous.get("first_outcome", outcome)),
		"path_kind": path_kind,
		"outcome": outcome,
		"action_index": action_index,
		"aftermath_id": "%s_%s" % [member_id, outcome],
		"history": history,
	}
	state["meetings"] = meetings
	crew_recruitment_encounters = state
	if outcome == "accepted":
		crew_recruit_member(member_id, _crew_recruitment_host_capability)
	elif outcome == "deferred":
		crew_meet_member(member_id, _crew_recruitment_host_capability)
	return {"ok": true, "replayed": false, "public_state": _run.CrewRecruitmentModelScript.encounter_public_state(state, member_id)}


func crew_recruitment_public_state(member_id: String) -> Dictionary:
	var result = _run.CrewRecruitmentModelScript.encounter_public_state(crew_recruitment_encounters, member_id)
	if str(result.get("meeting_state", "")) != "accepted":
		return result
	var job_out := false
	for job_value in crew_jobs.values():
		var job := JsonCoerceScript._copy_dict(job_value)
		if str(job.get("member_id", "")) == member_id and str(job.get("status", "")) in ["offered", "accepted", "active"]:
			job_out = true
			break
	var standing := crew_rank(member_id)
	result["standing"] = standing
	result["contact_state"] = "job_out" if job_out else ("trusted" if standing in ["made", "inner_circle"] else "familiar")
	return result


func crew_rank_perks(member_id: String) -> Array:
	var result: Array = []
	var rank_index := CrewStateModelScript.RANK_IDS.find(crew_rank(member_id))
	for rank_id_value in _run.CrewRecruitmentModelScript.rank_perks(member_id).keys():
		var rank_id := str(rank_id_value)
		if CrewStateModelScript.RANK_IDS.has(rank_id) and rank_index >= CrewStateModelScript.RANK_IDS.find(rank_id):
			for perk_value in JsonCoerceScript._copy_array(_run.CrewRecruitmentModelScript.rank_perks(member_id).get(rank_id_value, [])):
				var perk_id := str(perk_value)
				if not perk_id.is_empty() and not result.has(perk_id):
					result.append(perk_id)
	return result


func crew_member_job_available(member_id: String) -> bool:
	return crew_rank_perks(member_id).has("member_jobs")


func crew_present_member_ids(environment: Dictionary = {}) -> Array:
	var source = _run.current_environment if environment.is_empty() else environment
	var result: Array = []
	for entry_value in JsonCoerceScript._copy_array(source.get("crew_presence", [])):
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var member_id := str((entry_value as Dictionary).get("member_id", "")).strip_edges()
		if CrewStateModelScript.MEMBER_IDS.has(member_id) and not result.has(member_id):
			result.append(member_id)
	result.sort()
	return result


func crew_member_present(member_id: String, environment: Dictionary = {}) -> bool:
	return crew_present_member_ids(environment).has(member_id.strip_edges())


func crew_practice_rig_readout() -> Dictionary:
	var services := JsonCoerceScript._copy_dict(CrewStateModelScript.config().get("member_services", {}))
	var required := maxi(1, int(services.get("practice_rig_successes_required", 2)))
	var windows := ["early", "center", "late"]
	var index := posmod(_run.seed_value * 31 + _crew_action_index() * 17, windows.size())
	return {
		"target_window": windows[index],
		"progress": mini(required, maxi(0, int(_run.narrative_flags.get("craps_setting_street_progress", 0)))),
		"required": required,
		"trained": bool(_run.narrative_flags.get("craps_setting_trained", false)),
	}


func crew_practice_rig_choices() -> Array:
	var readout := crew_practice_rig_readout()
	if bool(readout.get("trained", false)):
		return [{"id": "leave", "label": "Rig trained", "text": "The target distribution holds steady. The setting technique is learned.", "consequences": {}}]
	var result: Array = []
	for window in ["early", "center", "late"]:
		result.append({
			"id": window,
			"label": "Release %s" % str(window).capitalize(),
			"text": "Readout target: %s. Progress %d/%d." % [str(readout.get("target_window", "center")).capitalize(), int(readout.get("progress", 0)), int(readout.get("required", 2))],
			"consequences": {"event_hooks": [{"type": "crew_practice_rig", "window": window}]},
		})
	result.append({"id": "leave", "label": "Step away", "text": "No stakes. No heat. The rig waits.", "consequences": {}})
	return result


func crew_practice_rig_session(window: String) -> Dictionary:
	var readout := crew_practice_rig_readout()
	var hit := window.strip_edges() == str(readout.get("target_window", ""))
	var grant := {}
	if hit:
		grant = _run.grant_shared_training_progress("craps_setting_street_progress", "craps_setting_trained", int(readout.get("required", 2)), 1, true)
	return {"ok": ["early", "center", "late"].has(window), "hit": hit, "window": window, "target_window": str(readout.get("target_window", "")), "grant": grant, "message": "The dice settle inside the band." if hit else "The dice land outside the target band."}


func crew_rook_ride_status() -> Dictionary:
	var services := JsonCoerceScript._copy_dict(CrewStateModelScript.config().get("member_services", {}))
	var rank := crew_rank("crew_rook")
	var caps := JsonCoerceScript._copy_dict(services.get("rook_ride_uses_by_rank", {}))
	var discounts := JsonCoerceScript._copy_dict(services.get("rook_ride_discount_percent_by_rank", {}))
	var cap := maxi(0, int(caps.get(rank, 0)))
	var day := int(floor(float(_crew_action_index()) / 48.0))
	var stored_day := int(_run.narrative_flags.get("crew_rook_ride_day", -1))
	var used := maxi(0, int(_run.narrative_flags.get("crew_rook_ride_uses", 0))) if stored_day == day else 0
	var active := bool(_run.narrative_flags.get("crew_rook_ride_active", false))
	return {"available": cap > used and not active and _run.current_travel_lock_remaining() <= 0, "rank": rank, "cap": cap, "used": used, "uses_remaining": maxi(0, cap - used), "discount_percent": clampi(int(discounts.get(rank, 0)), 0, 100), "active": active, "travel_locked": _run.current_travel_lock_remaining() > 0, "day": day}


func crew_rook_begin_ride() -> Dictionary:
	var status := crew_rook_ride_status()
	if not bool(status.get("available", false)):
		return {"ok": false, "message": "Rook cannot move the car through this lock." if bool(status.get("travel_locked", false)) else "Rook's rides are used for this stretch."}
	_run.narrative_flags["crew_rook_ride_day"] = int(status.get("day", 0))
	_run.narrative_flags["crew_rook_ride_uses"] = int(status.get("used", 0))
	_run.narrative_flags["crew_rook_ride_active"] = true
	_run.narrative_flags["crew_rook_ride_discount_percent"] = int(status.get("discount_percent", 0))
	return {"ok": true, "status": crew_rook_ride_status(), "message": "Rook starts the car. Choose any normally open route."}


func crew_rook_finish_ride() -> Dictionary:
	if not bool(_run.narrative_flags.get("crew_rook_ride_active", false)):
		return {}
	_run.narrative_flags["crew_rook_ride_active"] = false
	_run.narrative_flags["crew_rook_ride_discount_percent"] = 0
	_run.narrative_flags["crew_rook_ride_day"] = int(floor(float(_crew_action_index()) / 48.0))
	_run.narrative_flags["crew_rook_ride_uses"] = maxi(0, int(_run.narrative_flags.get("crew_rook_ride_uses", 0))) + 1
	return crew_rook_ride_status()


func crew_mags_bench_status() -> Dictionary:
	var available := CrewStateModelScript.RANK_IDS.find(crew_rank("crew_mags")) >= CrewStateModelScript.RANK_IDS.find("associate")
	return {"available": available, "catalog_ready": true, "catalog_owner": "content06_1", "message": "Mags opens the labeled cases." if available else "Mags does not open the cases for strangers."}


func crew_action_index() -> int:
	return _crew_action_index()


func crew_play_actions(game_id: String, environment: Dictionary = _run.current_environment) -> Array:
	if (not is_same(environment, _run.current_environment) and JSON.stringify(environment) != JSON.stringify(_run.current_environment)) \
		or str(_run.current_environment.get("active_game_id", "")) != game_id:
		return []
	return _run.CrewPlayModelScript.available_actions(_run, _run.current_environment, game_id)


func crew_play_activate(play_id: String, game_id: String, environment: Dictionary = _run.current_environment) -> Dictionary:
	if not crew_play_host_authorizes(_run._world1_host_capability, environment, game_id):
		return GameModule.build_action_result({"ok": false, "type": "game_action", "source_id": "crew_plays", "game_id": game_id, "action_id": "crew_play:%s" % play_id, "action_kind": "unknown", "message": "That crew play is not bound to the live table."})
	var rollback: Dictionary = _run._environment_turn_snapshot()
	var before_state = _run.CrewPlayModelScript.normalize_state(crew_play_state)
	var before_bankroll = _run.bankroll
	var before_chips = _run.grand_casino_chips
	var result = _run.CrewPlayModelScript.activate(_run, _run.current_environment, game_id, play_id, _run._world1_host_capability)
	var after_state = _run.CrewPlayModelScript.normalize_state(crew_play_state)
	var valid = bool(result.get("ok", false)) \
		and str(result.get("source_id", "")) == "crew_plays" and str(result.get("game_id", "")) == game_id \
		and int(after_state.get("sequence", -1)) == int(before_state.get("sequence", 0)) + 1 \
		and _run.bankroll == before_bankroll + int(result.get("bankroll_delta", 0)) \
		and _run.grand_casino_chips == before_chips + int(result.get("chips_delta", 0))
	if not valid:
		_run._apply_environment_turn_snapshot(rollback, false)
		return GameModule.build_action_result({"ok": false, "type": "game_action", "source_id": "crew_plays", "game_id": game_id, "action_id": "crew_play:%s" % play_id, "action_kind": "unknown", "message": "The table host rejected an incomplete play transaction."})
	return result


func crew_play_host_authorizes(host_capability: Variant, environment: Dictionary, game_id: String, require_active_game: bool = true) -> bool:
	if host_capability == null or host_capability != _run._world1_host_capability:
		return false
	if not is_same(environment, _run.current_environment) and JSON.stringify(environment) != JSON.stringify(_run.current_environment):
		return false
	return not require_active_game or not game_id.is_empty() and str(_run.current_environment.get("active_game_id", "")) == game_id


func crew_play_active(play_id: String, environment: Dictionary = _run.current_environment) -> bool:
	return _run.CrewPlayModelScript.is_active(crew_play_state, play_id, _crew_action_index(), environment)


func crew_play_active_status(game_id: String = "", environment: Dictionary = _run.current_environment) -> Array:
	return _run.CrewPlayModelScript.active_status(crew_play_state, _crew_action_index(), environment, game_id)


func crew_heist_free_play_available() -> bool:
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	return str(state.get("status", "")) == _run.CrewHeistModelScript.STATUS_PLAY and int(JsonCoerceScript._copy_dict(state.get("play", {})).get("free_play", 0)) > 0


func crew_heist_travel_comped(source_node_id: String, target_node_id: String) -> bool:
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("plan_id", "")) != _run.CrewHeistModelScript.PLAN_COUNT:
		return false
	var source_id := source_node_id.strip_edges()
	var target_id := target_node_id.strip_edges()
	if _run.GRAND_CASINO_ARCHETYPE_IDS.has(source_id):
		source_id = _run.GRAND_CASINO_ARCHETYPE_ID
	if _run.GRAND_CASINO_ARCHETYPE_IDS.has(target_id):
		target_id = _run.GRAND_CASINO_ARCHETYPE_ID
	if source_id.is_empty() or target_id.is_empty() or source_id == target_id:
		return false
	var phase := str(state.get("status", ""))
	if phase == _run.CrewHeistModelScript.STATUS_SETUP:
		var planning_and_score := ["small_underground_casino", _run.GRAND_CASINO_ARCHETYPE_ID]
		return planning_and_score.has(source_id) and planning_and_score.has(target_id)
	if phase == _run.CrewHeistModelScript.STATUS_PLAY:
		return source_id == "small_underground_casino" and target_id == _run.GRAND_CASINO_ARCHETYPE_ID
	if phase == _run.CrewHeistModelScript.STATUS_GETAWAY:
		var getaway := JsonCoerceScript._copy_dict(state.get("getaway", {}))
		return source_id == _run.GRAND_CASINO_ARCHETYPE_ID and target_id == str(getaway.get("target_node_id", ""))
	return false


func crew_heist_consume_free_play() -> bool:
	if not crew_heist_free_play_available():
		return false
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	var play := JsonCoerceScript._copy_dict(state.get("play", {}))
	play["free_play"] = maxi(0, int(play.get("free_play", 0)) - 1)
	state["play"] = play
	crew_heist_state = state
	return true


func crew_play_effect_int(play_id: String, effect_key: String, fallback: int, environment: Dictionary = _run.current_environment) -> int:
	return _run.CrewPlayModelScript.effect_int(crew_play_state, play_id, effect_key, _crew_action_index(), environment, fallback)


func crew_play_adjust_suspicion(amount: int, game_id: String, environment: Dictionary = _run.current_environment) -> int:
	if amount <= 0 or game_id != "blackjack":
		return amount
	var multiplier := crew_play_effect_int("spotter", "suspicion_multiplier_percent", 100, environment)
	return maxi(0, int(ceil(float(amount) * float(multiplier) / 100.0)))


func crew_play_adjust_detection_chance(chance: int, environment: Dictionary = _run.current_environment) -> int:
	var multiplier := crew_play_effect_int("table_flood", "cheat_detection_multiplier_percent", 100, environment)
	return clampi(int(ceil(float(maxi(0, chance)) * float(multiplier) / 100.0)), 0, 100)


func crew_job_definition_pending(definition_id: String) -> bool:
	var clean_id := definition_id.strip_edges()
	for job_value in crew_jobs.values():
		if typeof(job_value) != TYPE_DICTIONARY:
			continue
		var job: Dictionary = job_value
		if str(job.get("definition_id", "")) == clean_id and str(job.get("status", "")) != "resolved":
			return true
	return false


func crew_close_rook_leads_event() -> void:
	var event_ids := JsonCoerceScript._copy_array(_run.current_environment.get("event_ids", []))
	event_ids.erase("recruitment_rook_leads")
	_run.current_environment["event_ids"] = event_ids
	_run.store_current_world_node_environment()


func crew_switch_intel_status() -> Dictionary:
	var available := crew_rank_perks("crew_switch").has("remote_scenario_reveal")
	var services := JsonCoerceScript._copy_dict(CrewStateModelScript.config().get("member_services", {}))
	var cap := maxi(1, int(services.get("switch_intel_uses_per_visit", 2)))
	var visit_id = _run._event_cadence_visit_key(_run.current_environment)
	var stored_visit_id := str(_run.current_environment.get("crew_switch_intel_visit_id", ""))
	var used := maxi(0, int(_run.current_environment.get("crew_switch_intel_uses", 0))) if not visit_id.is_empty() and stored_visit_id == visit_id else 0
	return {"available": available and used < cap, "rank_gated": not available, "uses": used, "uses_remaining": maxi(0, cap - used), "cap": cap, "visit_id": visit_id}


func crew_switch_reveal_candidates() -> Array:
	if not bool(crew_switch_intel_status().get("available", false)):
		return []
	var result: Array = []
	for node_value in JsonCoerceScript._copy_array(_run.world_map.get("nodes", [])):
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", "")).strip_edges()
		if node_id.is_empty() or node_id == _run.current_world_node_id() or bool(node.get("scouted", false)):
			continue
		var scenario = _run.seeded_scenario_for_node(node_id)
		if scenario.is_empty():
			continue
		result.append({
			"node_id": node_id,
			"display_name": str(node.get("display_name", node.get("name", node_id.replace("_", " ").capitalize()))),
			"scenario_id": str(scenario.get("id", "")),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("node_id", "")) < str(b.get("node_id", "")))
	return result


func crew_switch_reveal_node(node_id: String) -> Dictionary:
	var status := crew_switch_intel_status()
	var target := node_id.strip_edges()
	if not bool(status.get("available", false)) or target.is_empty() or _run.seeded_scenario_for_node(target).is_empty():
		return {"ok": false, "node_id": target, "status": status}
	var heard = _run.hear_rumor("scenario:%s" % target)
	if heard.is_empty():
		return {"ok": false, "node_id": target, "status": status}
	_run.world_map = WorldMap.mark_scouted(_run.world_map, target)
	_run.current_environment["crew_switch_intel_visit_id"] = str(status.get("visit_id", ""))
	_run.current_environment["crew_switch_intel_uses"] = int(status.get("uses", 0)) + 1
	_run.store_current_world_node_environment()
	return {"ok": true, "node_id": target, "heard": heard, "status": crew_switch_intel_status()}


func crew_rook_escort_available() -> bool:
	return crew_rank_perks("crew_rook").has("rook_l3_escort")


func crew_knuckles_stash_status() -> Dictionary:
	var cap = _run.CrewRecruitmentModelScript.stash_cap()
	var available := crew_rank_perks("crew_knuckles").has("contraband_stash")
	return {"available": available and crew_contraband_stash.size() < cap, "rank_gated": not available, "count": crew_contraband_stash.size(), "cap": cap, "item_ids": crew_contraband_stash.duplicate(true)}


func crew_knuckles_stash_candidates() -> Array:
	var result: Array = []
	var definitions = _run._item_definition_index()
	for inventory_index in range(_run.inventory.size()):
		var item_id = _run._inventory_item_id(_run.inventory[inventory_index])
		var definition := JsonCoerceScript._copy_dict(definitions.get(item_id, {}))
		var risk_flags := JsonCoerceScript._string_array(JsonCoerceScript._copy_array(definition.get("risk_flags", [])))
		if str(definition.get("class", "")).strip_edges().to_lower() == "contraband" or risk_flags.has("contraband"):
			result.append({"candidate_id": "inventory:%d" % inventory_index, "inventory_index": inventory_index, "item_id": item_id})
	return result


func crew_knuckles_retrieve_candidates() -> Array:
	var result: Array = []
	for stash_index in range(crew_contraband_stash.size()):
		result.append({"candidate_id": "stash:%d" % stash_index, "stash_index": stash_index, "item_id": _run._inventory_item_id(crew_contraband_stash[stash_index])})
	return result


func crew_knuckles_stash_item(item_id: String) -> Dictionary:
	var clean_id := item_id.strip_edges()
	for candidate_value in crew_knuckles_stash_candidates():
		if typeof(candidate_value) == TYPE_DICTIONARY and str((candidate_value as Dictionary).get("item_id", "")) == clean_id:
			return crew_knuckles_stash_inventory_entry(int((candidate_value as Dictionary).get("inventory_index", -1)), clean_id)
	return {"ok": false, "item_id": clean_id, "status": crew_knuckles_stash_status()}


func crew_knuckles_stash_inventory_entry(inventory_index: int, expected_item_id: String) -> Dictionary:
	var status := crew_knuckles_stash_status()
	var clean_id := expected_item_id.strip_edges()
	if not bool(status.get("available", false)) or inventory_index < 0 or inventory_index >= _run.inventory.size() \
		or _run._inventory_item_id(_run.inventory[inventory_index]) != clean_id:
		return {"ok": false, "item_id": clean_id, "status": status}
	var valid_candidate := false
	for candidate_value in crew_knuckles_stash_candidates():
		if typeof(candidate_value) == TYPE_DICTIONARY and int((candidate_value as Dictionary).get("inventory_index", -1)) == inventory_index:
			valid_candidate = true
			break
	if not valid_candidate:
		return {"ok": false, "item_id": clean_id, "status": status}
	crew_contraband_stash.append(_run._persistent_copy_value(_run.inventory[inventory_index]))
	_run.inventory.remove_at(inventory_index)
	_run.invalidate_inventory_effect_cache()
	if _run.active_item_id == clean_id:
		_run.active_item_id = ""
	return {"ok": true, "item_id": clean_id, "status": crew_knuckles_stash_status()}


func crew_knuckles_retrieve_stash_entry(stash_index: int, expected_item_id: String) -> Dictionary:
	var clean_id := expected_item_id.strip_edges()
	if not crew_rank_perks("crew_knuckles").has("contraband_stash") or stash_index < 0 or stash_index >= crew_contraband_stash.size() \
		or _run._inventory_item_id(crew_contraband_stash[stash_index]) != clean_id:
		return {"ok": false, "item_id": clean_id}
	_run.inventory.append(_run._persistent_copy_value(crew_contraband_stash[stash_index]))
	crew_contraband_stash.remove_at(stash_index)
	_run.invalidate_inventory_effect_cache()
	return {"ok": true, "item_id": clean_id, "status": crew_knuckles_stash_status()}


func crew_standing() -> Dictionary:
	var total_trust := 0
	var highest_rank_index := 0
	var ranks := {}
	var made_members: Array = []
	var inner_circle_members: Array = []
	for member_id in CrewStateModelScript.MEMBER_IDS:
		var trust := crew_trust(member_id)
		var rank_id := crew_rank(member_id)
		total_trust += trust
		ranks[member_id] = rank_id
		highest_rank_index = maxi(highest_rank_index, CrewStateModelScript.RANK_IDS.find(rank_id))
		if CrewStateModelScript.RANK_IDS.find(rank_id) >= CrewStateModelScript.RANK_IDS.find("made"):
			made_members.append(member_id)
		if rank_id == "inner_circle":
			inner_circle_members.append(member_id)
	var heist_eligibility := {}
	for plan_id_value in _run.CrewHeistModelScript.release_plan_ids():
		var plan_id := str(plan_id_value)
		var eligible := true
		for criterion_value in JsonCoerceScript._copy_array(_run.CrewHeistModelScript.plan(plan_id).get("crew_criteria", [])):
			var criterion := JsonCoerceScript._copy_dict(criterion_value)
			var required_rank := str(criterion.get("rank", "inner_circle"))
			if CrewStateModelScript.RANK_IDS.find(crew_rank(str(criterion.get("member_id", "")))) < CrewStateModelScript.RANK_IDS.find(required_rank):
				eligible = false
				break
		heist_eligibility[plan_id] = eligible
	return {
		"rank": CrewStateModelScript.RANK_IDS[highest_rank_index],
		"total_trust": total_trust,
		"average_trust": int(floor(float(total_trust) / float(CrewStateModelScript.MEMBER_IDS.size()))),
		"member_ranks": ranks,
		"made_members": made_members,
		"inner_circle_members": inner_circle_members,
		"layer_3_access": not made_members.is_empty(),
		"heist_eligibility": heist_eligibility,
	}


func crew_heist_planning_status() -> Dictionary:
	var rows: Array = []
	var architect_ready := false
	for plan_id in _run.CrewHeistModelScript.release_plan_ids():
		var definition = _run.CrewHeistModelScript.plan(plan_id)
		var missing: Array = []
		var crew_ready := true
		for criterion_value in JsonCoerceScript._copy_array(definition.get("crew_criteria", [])):
			var criterion := JsonCoerceScript._copy_dict(criterion_value)
			var required_rank := str(criterion.get("rank", "inner_circle"))
			if CrewStateModelScript.RANK_IDS.find(crew_rank(str(criterion.get("member_id", "")))) < CrewStateModelScript.RANK_IDS.find(required_rank):
				crew_ready = false
				missing.append(str(criterion.get("label", "The crew is not ready.")))
		architect_ready = architect_ready or crew_ready
		for criterion_value in JsonCoerceScript._copy_array(definition.get("world_criteria", [])):
			var criterion := JsonCoerceScript._copy_dict(criterion_value)
			var found := false
			if str(criterion.get("kind", "")) == "scenario_hook":
				found = _crew_heist_world_has_hook(str(criterion.get("key", "")))
			else:
				for key_value in JsonCoerceScript._copy_array(criterion.get("keys", [])):
					if _crew_heist_world_has_hook(str(key_value)):
						found = true
						break
			if not found:
				missing.append(str(criterion.get("label", "The night does not carry this score.")))
		rows.append({
			"id": plan_id,
			"label": str(definition.get("label", plan_id)),
			"live": crew_ready and missing.is_empty() and crew_heist_state.is_empty(),
			"missing_stars": missing,
		})
	return {
		"visible": architect_ready,
		"locked_plan_id": str(crew_heist_state.get("plan_id", "")),
		"phase": str(crew_heist_state.get("status", "")),
		"plans": rows if architect_ready else [],
	}


func crew_heist_table_choices() -> Array:
	var status := crew_heist_planning_status()
	if not crew_heist_state.is_empty():
		var active_choices: Array = []
		var phase := str(crew_heist_state.get("status", "setup"))
		var plan_id := str(crew_heist_state.get("plan_id", ""))
		var setup := JsonCoerceScript._copy_dict(crew_heist_state.get("setup", {}))
		var play := JsonCoerceScript._copy_dict(crew_heist_state.get("play", {}))
		active_choices.append({"id": "inspect", "label": "Read the live score", "text": "The locked plan is in %s." % phase.replace("_", " "), "consequences": {}})
		if phase == _run.CrewHeistModelScript.STATUS_SETUP:
			active_choices.append({"id": "table_talk", "label": "Let the room talk", "text": "Nobody has stood up yet.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "observe_table"}]}})
			active_choices.append_array(_crew_heist_private_choices())
			if plan_id == _run.CrewHeistModelScript.PLAN_COUNT:
				if not bool(setup.get("schedule", false)):
					if _crew_heist_setup_delivery_active("schedule"):
						active_choices.append({"id": "count_schedule_active", "label": "Finish the schedule watch", "text": "The shift route is already marked. Return to the Grand cage and use Hold Sightline before the window closes.", "disabled": true, "consequences": {}})
					else:
						var count_setup := JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.plan(_run.CrewHeistModelScript.PLAN_COUNT).get("setup", {}))
						var schedule := JsonCoerceScript._copy_dict(count_setup.get("schedule", {}))
						active_choices.append({"id": "count_schedule", "label": "Watch the schedule", "text": "Hold the Grand cage through shift change at Heat %d or lower. The crew covers direct transport while The Count is live." % int(schedule.get("attention_limit", 55)), "consequences": {"event_hooks": [{"type": "crew_heist", "action": "count_schedule"}]}})
				if not bool(setup.get("swap_cart", false)):
					if _crew_heist_setup_delivery_active("swap_cart"):
						active_choices.append({"id": "count_cart_active", "label": "Finish the swap route", "text": "The cart route is already marked at the Grand. Finish its handoff before changing the map.", "disabled": true, "consequences": {}})
					else:
						active_choices.append({"id": "count_cart", "label": "Move the swap cart", "text": "Take the hard package route to the service perimeter. The crew covers the direct Grand route.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "count_cart"}]}})
			else:
				_crew_heist_sync_whale_setup()
				setup = JsonCoerceScript._copy_dict(crew_heist_state.get("setup", {}))
			var setup_ready: bool = bool(_run.CrewHeistModelScript.setup_complete(crew_heist_state))
			active_choices.append({"id": "begin_play", "label": "Begin the Play", "text": "All chairs are filled." if setup_ready else "The setup still has an empty chair.", "disabled": not setup_ready, "consequences": {"event_hooks": [{"type": "crew_heist", "action": "begin_play"}]}})
			active_choices.append({"id": "abort", "label": "Fold the score", "text": "Pay for the preparation already burned. The run continues.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "abort"}]}})
		elif phase == _run.CrewHeistModelScript.STATUS_PLAY:
			active_choices.append({"id": "live_table_direction", "label": "Return to the live table", "text": "The decisions happen inside the session, not over the planning map.", "disabled": true, "consequences": {}})
		active_choices.append({"id": "leave", "label": "Leave the table", "text": "The map stays where it is.", "dismissal": true, "consequences": {}})
		return active_choices
	if not bool(status.get("visible", false)):
		return [{"id": "leave", "label": "Leave the table clear", "text": "The center waits for somebody inside the circle.", "dismissal": true, "consequences": {}}]
	var choices: Array = []
	for row_value in JsonCoerceScript._copy_array(status.get("plans", [])):
		var row := JsonCoerceScript._copy_dict(row_value)
		var missing := JsonCoerceScript._copy_array(row.get("missing_stars", []))
		choices.append({
			"id": "lock_%s" % str(row.get("id", "")),
			"label": "Lock %s" % str(row.get("label", "the plan")),
			"text": "The stars line up." if bool(row.get("live", false)) else " ".join(missing),
			"disabled": not bool(row.get("live", false)),
			"consequences": {"event_hooks": [{"type": "crew_heist", "action": "lock", "plan_id": str(row.get("id", ""))}]},
		})
	choices.append({"id": "leave", "label": "Leave the table clear", "text": "No score is forced tonight.", "dismissal": true, "consequences": {}})
	return choices


func crew_heist_live_table_choices() -> Array:
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	var phase := str(state.get("status", ""))
	if phase == _run.CrewHeistModelScript.STATUS_INTERVIEW and str(state.get("plan_id", "")) == _run.CrewHeistModelScript.PLAN_WHALE:
		var interview := JsonCoerceScript._copy_dict(state.get("interview", {}))
		return [
			{"id": "interview_show_receipt", "label": "Show the receipt", "text": "Let the borrowed name survive the cage questions.", "disabled": bool(interview.get("cracked", false)), "consequences": {"event_hooks": [{"type": "crew_heist", "action": "resolve_interview", "choice": "show_receipt"}]}},
			{"id": "interview_cut_short", "label": "Cut it short", "text": "Call Rook before the borrowed name cracks in the light.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "resolve_interview", "choice": "cut_short"}]}},
		]
	if phase != _run.CrewHeistModelScript.STATUS_PLAY or not _crew_heist_at_designated_table(state):
		return [{"id": "leave", "label": "Leave the quiet table", "text": "No crew beat is live here.", "dismissal": true, "consequences": {}}]
	var play := JsonCoerceScript._copy_dict(state.get("play", {}))
	var plan_id := str(state.get("plan_id", ""))
	var result: Array = [{"id": "inspect", "label": "Read the live session", "text": "Round %d is settled." % int(play.get("round", 0)), "consequences": {}}]
	if plan_id == _run.CrewHeistModelScript.PLAN_COUNT:
		var decision_id := _crew_heist_count_decision_due(state)
		if decision_id == "go":
			result.append_array(_crew_heist_decision_choices("go", ["early", "hold"]))
		elif decision_id == "distraction":
			result.append_array(_crew_heist_decision_choices("distraction", ["sit", "dump"]))
		elif decision_id == "exit":
			var exits := ["dock"]
			if bool(JsonCoerceScript._copy_dict(state.get("setup", {})).get("guard_marker", false)):
				exits.append("corridor")
			result.append_array(_crew_heist_decision_choices("exit", exits))
	if int(play.get("round", 0)) >= int(JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.plan(plan_id).get("play", {})).get("required_rounds", 1)) and (plan_id != _run.CrewHeistModelScript.PLAN_COUNT or JsonCoerceScript._copy_dict(play.get("decisions", {})).size() == 3):
		if plan_id == _run.CrewHeistModelScript.PLAN_WHALE:
			result.append({"id": "begin_interview", "label": "Take the pot to the cage", "text": "The borrowed name still has to survive the interview.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "begin_interview"}]}})
		else:
			result.append({"id": "begin_getaway", "label": "Take the exit", "text": "Leave the live table for the marked route.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "begin_getaway"}]}})
	result.append({"id": "leave", "label": "Stay in the session", "text": "The table keeps moving only when you play.", "dismissal": true, "consequences": {}})
	return result


func _crew_heist_decision_choices(decision_id: String, values: Array) -> Array:
	var result: Array = []
	for value in values:
		var choice := str(value)
		result.append({"id": "%s_%s" % [decision_id, choice], "label": choice.replace("_", " ").capitalize(), "text": "Bishop records the choice, not an excuse.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "decide", "decision": decision_id, "choice": choice}]}})
	return result


func crew_record_heist_event_result(result: Dictionary) -> Dictionary:
	if not bool(result.get("ok", false)) or str(result.get("type", "")) != "event":
		return {"ok": false, "reason": "not_resolved_event"}
	var event_id := str(result.get("event_id", result.get("source_id", ""))).strip_edges()
	var choice_id := str(result.get("choice_id", result.get("action_id", ""))).strip_edges()
	if event_id not in ["crew_planning_table", "heist_live_table"] or choice_id.is_empty() \
			or not JsonCoerceScript._copy_array(_run.current_environment.get("event_ids", [])).has(event_id) \
			or JsonCoerceScript._copy_array(_run.current_environment.get("resolved_event_ids", [])).has(event_id):
		return {"ok": false, "reason": "event_not_live"}
	var live_choices := crew_heist_table_choices() if event_id == "crew_planning_table" else crew_heist_live_table_choices()
	var expected_hook: Dictionary = {}
	for choice_value in live_choices:
		var choice := JsonCoerceScript._copy_dict(choice_value)
		if str(choice.get("id", "")) != choice_id or bool(choice.get("disabled", false)): continue
		var candidate_hooks: Array = []
		for hook_value in JsonCoerceScript._copy_array(JsonCoerceScript._copy_dict(choice.get("consequences", {})).get("event_hooks", [])):
			var candidate := JsonCoerceScript._copy_dict(hook_value)
			if str(candidate.get("type", "")) == "crew_heist": candidate_hooks.append(candidate)
		if candidate_hooks.size() == 1: expected_hook = JsonCoerceScript._copy_dict(candidate_hooks[0])
		break
	if expected_hook.is_empty(): return {"ok": false, "reason": "choice_not_live"}
	var supplied_hooks: Array = []
	for hook_value in JsonCoerceScript._copy_array(JsonCoerceScript._copy_dict(result.get("deltas", {})).get("event_hooks", [])):
		var supplied := JsonCoerceScript._copy_dict(hook_value)
		if str(supplied.get("type", "")) == "crew_heist": supplied_hooks.append(supplied)
	if supplied_hooks.size() != 1 or JSON.stringify(supplied_hooks[0]) != JSON.stringify(expected_hook):
		return {"ok": false, "reason": "hook_mismatch"}
	return crew_heist_event_action(expected_hook, _crew_heist_host_capability)


func crew_heist_event_action(hook: Dictionary, host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability:
		return {"ok": false, "message": "The heist host rejected that action."}
	var rollback = _run._environment_turn_snapshot()
	var action := str(hook.get("action", ""))
	var result: Dictionary = {}
	match str(hook.get("action", "")):
		"lock": result = crew_heist_lock(str(hook.get("plan_id", "")), host_capability)
		"observe_table": result = crew_heist_observe_table(host_capability)
		"confront": result = crew_heist_confront(str(hook.get("member_id", "")), host_capability)
		"hedge": result = crew_heist_hedge(host_capability)
		"abort": result = crew_heist_abort("planning_table", host_capability)
		"count_schedule": result = crew_heist_begin_count_schedule(host_capability)
		"count_cart": result = crew_heist_begin_count_swap_cart(host_capability)
		"begin_play": result = crew_heist_begin_play(host_capability)
		"decide": result = crew_heist_decide(str(hook.get("decision", "")), str(hook.get("choice", "")), host_capability)
		"begin_interview": result = crew_heist_begin_interview(host_capability)
		"resolve_interview": result = crew_heist_resolve_interview(str(hook.get("choice", "")), host_capability)
		"begin_getaway": result = crew_heist_begin_getaway(host_capability)
		_: result = {"ok": false, "message": "That part of the plan is not live."}
	if not bool(result.get("ok", false)):
		_run._apply_environment_turn_snapshot(rollback, false)
		return result
	var action_codes := {"lock": 1, "observe_table": 2, "confront": 3, "hedge": 4, "abort": 5, "count_schedule": 6, "count_cart": 7, "begin_play": 8, "decide": 9, "begin_interview": 10, "resolve_interview": 11, "begin_getaway": 12}
	var phase_codes := {_run.CrewHeistModelScript.STATUS_SETUP: 1, _run.CrewHeistModelScript.STATUS_PLAY: 2, _run.CrewHeistModelScript.STATUS_INTERVIEW: 3, _run.CrewHeistModelScript.STATUS_GETAWAY: 4, _run.CrewHeistModelScript.STATUS_COMPLETED: 5, _run.CrewHeistModelScript.STATUS_ABORTED: 6}
	var state = _run.CrewHeistModelScript.record_tombstone(crew_heist_state, _crew_action_index(), int(action_codes.get(action, 99)), int(phase_codes.get(str(crew_heist_state.get("status", "")), 9)))
	if state.is_empty():
		_run._apply_environment_turn_snapshot(rollback, false)
		return {"ok": false, "message": "The heist receipt could not be committed."}
	if action in ["observe_table", "confront", "hedge"]:
		var private_codes := {"observe_table": 1, "confront": 2, "hedge": 3}
		state["x"] = CrewTurnModelScript.record_tombstone(state.get("x", {}), _crew_action_index(), int(private_codes.get(action, 99)), CrewStateModelScript.MEMBER_IDS)
	crew_heist_state = state
	var sequence_result = _run.world_sequence_schedule_heist_mount(action, host_capability)
	if not bool(sequence_result.get("ok", false)):
		_run._apply_environment_turn_snapshot(rollback, false)
		return {"ok": false, "message": "The heist scene could not be staged atomically.", "errors": JsonCoerceScript._copy_array(sequence_result.get("errors", []))}
	# A player-authenticated planning-table fold pays its authored preparation
	# cost and tears down the live route, but it is not a terminal ending. Keep
	# the aborted state only long enough to authenticate, receipt, and unmount the
	# action atomically, then retain the already-authenticated plan lock. Crew
	# standing may legitimately change after lock and cannot brick that score.
	if action == "abort":
		crew_heist_state = _crew_heist_reopen_folded_plan(crew_heist_state)
		result["relockable"] = true
	result["world_sequence_scheduled"] = not bool(sequence_result.get("inactive", false))
	# Quiet-table actions schedule their scene internally, but the package/owner
	# token names the private observation channel. It is never needed as a player
	# command receipt, so do not echo it through the public action result.
	if action not in ["observe_table", "confront", "hedge"]:
		result["world_sequence_owner_token"] = str(sequence_result.get("owner_token", ""))
	return result


func crew_heist_lock(plan_id: String, host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	if not crew_heist_state.is_empty():
		return {"ok": false, "message": "One score is already the run's score."}
	for row_value in JsonCoerceScript._copy_array(crew_heist_planning_status().get("plans", [])):
		var row := JsonCoerceScript._copy_dict(row_value)
		if str(row.get("id", "")) == plan_id and bool(row.get("live", false)):
			crew_heist_state = _run.CrewHeistModelScript.begin(plan_id, _crew_action_index())
			var met_members: Array = []
			for member_id in CrewStateModelScript.MEMBER_IDS:
				if crew_rank(member_id) != "stranger":
					met_members.append(member_id)
			var resolution_rng = _run.create_rng("crew_heist_hidden").fork("lock:%s:%d" % [plan_id, _crew_action_index()])
			crew_heist_state["x"] = CrewTurnModelScript.resolve(
				_run.CrewHeistModelScript.plan(plan_id), met_members, crew_grievances(), CrewStateModelScript.MEMBER_IDS,
				JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.config().get("hidden_resolution", {})), resolution_rng
			)
			return {"ok": not crew_heist_state.is_empty(), "plan_id": plan_id, "message": "The plan is locked. The map stays on the table."}
	return {"ok": false, "message": "The plan's stars do not line up tonight."}


func _crew_heist_private_choices() -> Array:
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	var hidden := JsonCoerceScript._copy_dict(state.get("x", {}))
	var witnessed := CrewTurnModelScript.witnessed_count(hidden, CrewStateModelScript.MEMBER_IDS)
	var result: Array = []
	if witnessed == 1 and not bool(hidden.get("h", false)):
		result.append({"id": "change_seat", "label": "Change your place at the table", "text": "Move your part without explaining why.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "hedge"}]}})
	elif witnessed >= 2 and not bool(hidden.get("c", false)):
		var eligible := CrewTurnModelScript.eligible_members(_run.CrewHeistModelScript.plan(str(state.get("plan_id", ""))), _crew_heist_met_members(), CrewStateModelScript.MEMBER_IDS)
		for member_id in eligible:
			result.append({"id": "close_door_%s" % member_id.trim_prefix("crew_"), "label": "Close the door on %s" % member_id.trim_prefix("crew_").capitalize(), "text": "Say the name once and accept what follows.", "consequences": {"event_hooks": [{"type": "crew_heist", "action": "confront", "member_id": member_id}]}})
	return result


func crew_heist_observe_table(host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("status", "")) != _run.CrewHeistModelScript.STATUS_SETUP:
		return {"ok": false, "message": "The room has moved past talk."}
	var hidden := CrewTurnModelScript.normalize_state(state.get("x", {}), CrewStateModelScript.MEMBER_IDS)
	var member_id := CrewTurnModelScript.active_member(hidden, CrewStateModelScript.MEMBER_IDS)
	if member_id.is_empty():
		return {"ok": true, "message": "The room talks through the route one more time."}
	var emitted := JsonCoerceScript._copy_array(hidden.get("e", []))
	if not emitted.has(CrewTurnModelScript.SIGNAL_PATTERN):
		var learned = _run.tell_learned(member_id)
		hidden = CrewTurnModelScript.mark_emitted(hidden, CrewTurnModelScript.SIGNAL_PATTERN, learned, CrewStateModelScript.MEMBER_IDS)
		state["x"] = hidden
		crew_heist_state = state
		if learned:
			return {"ok": true, "message": "A familiar table tell surfaces in the quiet room. No cards are on the table."}
		# An unlearned tell must be observationally identical to a clean table.
		return {"ok": true, "message": "The room talks through the route one more time."}
	if not emitted.has(CrewTurnModelScript.SIGNAL_ROUTE):
		var contradiction := _crew_heist_route_contradiction(member_id)
		if not contradiction.is_empty():
			hidden = CrewTurnModelScript.mark_emitted(hidden, CrewTurnModelScript.SIGNAL_ROUTE, true, CrewStateModelScript.MEMBER_IDS)
			state["x"] = hidden
			crew_heist_state = state
			assert(bool(contradiction.get("checkable", false)), "Planning route line lacked a visited world record.")
			return {"ok": true, "message": "A neutral Crew voice gives a route claim that contradicts a visit you personally witnessed during the same window."}
	return {"ok": true, "message": "The route gets read without another word."}


func crew_heist_confront(member_id: String, host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	var hidden := CrewTurnModelScript.normalize_state(state.get("x", {}), CrewStateModelScript.MEMBER_IDS)
	if str(state.get("status", "")) != _run.CrewHeistModelScript.STATUS_SETUP or CrewTurnModelScript.witnessed_count(hidden, CrewStateModelScript.MEMBER_IDS) < 2:
		return {"ok": false, "message": "The room does not follow you there."}
	var eligible := CrewTurnModelScript.eligible_members(_run.CrewHeistModelScript.plan(str(state.get("plan_id", ""))), _crew_heist_met_members(), CrewStateModelScript.MEMBER_IDS)
	if not eligible.has(member_id):
		return {"ok": false, "message": "That chair is not yours to close."}
	if member_id == str(hidden.get("m", "")) and not member_id.is_empty():
		hidden["c"] = true
		hidden["m"] = ""
		var play := JsonCoerceScript._copy_dict(state.get("play", {}))
		play["free_play"] = 1
		state["play"] = play
		state["x"] = hidden
		crew_heist_state = state
		return {"ok": true, "message": "%s stays after the others leave. The old debt comes out plain. One chair moves closer." % member_id.trim_prefix("crew_").capitalize()}
	_run.grievance_add({"member_id": member_id, "kind": "wrong_accusation", "weight": 2, "source_ref": "heist_table"})
	var tuning := JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.config().get("hidden_resolution", {}))
	var trust_cost := maxi(1, int(tuning.get("crew_trust_cost", 5)))
	for crew_member_id in CrewStateModelScript.MEMBER_IDS:
		crew_add_trust(crew_member_id, -trust_cost, "closed_door")
	# Re-run only the already-real member against the increased curve. The wrong
	# chair's new debt cannot become a candidate here, and a miss cannot fabricate
	# evidence. Existing evidence remains valid only if that same member fires.
	var real_member := CrewTurnModelScript.active_member(hidden, CrewStateModelScript.MEMBER_IDS)
	var escalation := int(hidden.get("f", 0)) + 1
	var reroll_rng = _run.create_rng("crew_heist_hidden").fork("reroute:%s:%d:%d:%s" % [str(state.get("plan_id", "")), _crew_action_index(), escalation, real_member])
	var rerolled := CrewTurnModelScript.resolve(_run.CrewHeistModelScript.plan(str(state.get("plan_id", ""))), [real_member], crew_grievances(real_member), CrewStateModelScript.MEMBER_IDS, tuning, reroll_rng, escalation)
	if str(rerolled.get("m", "")) == real_member:
		rerolled["e"] = JsonCoerceScript._copy_array(hidden.get("e", []))
		rerolled["w"] = JsonCoerceScript._copy_array(hidden.get("w", []))
	state["x"] = rerolled
	crew_heist_state = state
	return {"ok": true, "message": "%s leaves first. Nobody brightens the lamp for the next name." % member_id.trim_prefix("crew_").capitalize()}


func crew_heist_hedge(host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	var hidden := CrewTurnModelScript.normalize_state(state.get("x", {}), CrewStateModelScript.MEMBER_IDS)
	if str(state.get("status", "")) != _run.CrewHeistModelScript.STATUS_SETUP or CrewTurnModelScript.witnessed_count(hidden, CrewStateModelScript.MEMBER_IDS) != 1 or bool(hidden.get("h", false)):
		return {"ok": false, "message": "The seats stay where they are."}
	hidden["h"] = true
	if CrewTurnModelScript.active_member(hidden, CrewStateModelScript.MEMBER_IDS).is_empty():
		var cost := maxi(1, int(JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.config().get("hidden_resolution", {})).get("hedge_trust_cost", 2)))
		for member_id in CrewStateModelScript.MEMBER_IDS:
			crew_add_trust(member_id, -cost, "cold_feet")
	state["x"] = hidden
	crew_heist_state = state
	return {"ok": true, "message": "You move your own chair. The room notices and lets you keep the explanation."}


func _crew_heist_met_members() -> Array:
	var result: Array = []
	for member_id in CrewStateModelScript.MEMBER_IDS:
		if crew_rank(member_id) != "stranger":
			result.append(member_id)
	return result


func _crew_heist_route_contradiction(member_id: String) -> Dictionary:
	var actual := {}
	for node_value in JsonCoerceScript._copy_array(_run.world_map.get("nodes", [])):
		var node := JsonCoerceScript._copy_dict(node_value)
		if str(node.get("state", "")) != "visited":
			continue
		var environment := JsonCoerceScript._copy_dict(node.get("environment", {}))
		var period_start := int(environment.get("entered_game_clock_minutes", -1))
		var period_end := int(environment.get("departed_game_clock_minutes", -1))
		if period_start < 0 or period_end <= period_start:
			continue
		for presence_value in JsonCoerceScript._copy_array(environment.get("crew_presence", [])):
			if str(JsonCoerceScript._copy_dict(presence_value).get("member_id", "")) == member_id:
				actual = {"id": str(node.get("id", "")), "name": str(node.get("label", node.get("id", "the room"))), "period_start": period_start, "period_end": period_end}
				break
		if not actual.is_empty():
			break
	if actual.is_empty():
		return {}
	var claimed := {}
	for node_value in JsonCoerceScript._copy_array(_run.world_map.get("nodes", [])):
		var node := JsonCoerceScript._copy_dict(node_value)
		if str(node.get("id", "")) != str(actual.get("id", "")):
			claimed = {"id": str(node.get("id", "")), "name": str(node.get("label", node.get("id", "the other room")))}
			break
	if claimed.is_empty():
		return {}
	return {"checkable": true, "actual_node_id": str(actual.get("id", "")), "actual_name": str(actual.get("name", "")), "claimed_node_id": str(claimed.get("id", "")), "claimed_name": str(claimed.get("name", "")), "period_start": int(actual.get("period_start", 0)), "period_end": int(actual.get("period_end", 0))}


static func _crew_clock_label(total_minutes: int) -> String:
	return PlayerTextScript.format_time_of_day(total_minutes)


func crew_heist_abort(reason: String = "retreated", host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	if state.is_empty() or [_run.CrewHeistModelScript.STATUS_PLAY, _run.CrewHeistModelScript.STATUS_GETAWAY, _run.CrewHeistModelScript.STATUS_COMPLETED, _run.CrewHeistModelScript.STATUS_ABORTED].has(str(state.get("status", ""))):
		return {"ok": false, "message": "That retreat is no longer available."}
	var setup_count := JsonCoerceScript._copy_dict(state.get("setup", {})).size()
	var requested_cost := 15 + setup_count * 10
	var paid := mini(requested_cost, maxi(0, _run.bankroll - 1))
	_run.bankroll -= paid
	if reason == "planning_table":
		_crew_heist_clear_setup_delivery(str(state.get("plan_id", "")))
	state["status"] = _run.CrewHeistModelScript.STATUS_ABORTED
	state["abort"] = {"reason": reason.strip_edges(), "cost": paid, "action": _crew_action_index()}
	crew_heist_state = state
	return {"ok": true, "cost": paid, "run_ended": false, "message": "The crew folds the map. Preparation costs $%d; the run stays yours." % paid}


# Fold is a voluntary setup teardown, distinct from a forced identity failure.
# Clear only delivery machinery owned by this exact plan; unrelated jobs and
# completed delivery receipts remain untouched.
func _crew_heist_clear_setup_delivery(plan_id: String) -> void:
	var run_id := str(_run.active_delivery_run.get("run_id", "")).strip_edges()
	if run_id not in ["heist:%s:schedule" % plan_id, "heist:%s:swap_cart" % plan_id]:
		return
	_run._delivery_remove_inventory_cargo()
	_run.active_delivery_run = {}


# Preserve the authenticated lock and completed setup facts while returning the
# plan to SETUP. The live schedule/cart route is separate authority and has
# already been removed above; forced abort reasons never cross this helper.
func _crew_heist_reopen_folded_plan(state_value: Variant) -> Dictionary:
	var state = _run.CrewHeistModelScript.normalize_state(state_value)
	if state.is_empty():
		return {}
	state["status"] = _run.CrewHeistModelScript.STATUS_SETUP
	state.erase("abort")
	state["getaway"] = {}
	state["outcome"] = ""
	state["payout"] = 0
	return state


# Saves made while the old Fold behavior was live contain an authenticated
# planning-table abort plus its orphaned setup route. Migrate only that exact
# public reason after private authority and delivery state have both restored.
func reconcile_planning_table_fold() -> bool:
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("status", "")) != _run.CrewHeistModelScript.STATUS_ABORTED \
			or str(JsonCoerceScript._copy_dict(state.get("abort", {})).get("reason", "")) != "planning_table":
		return false
	_crew_heist_clear_setup_delivery(str(state.get("plan_id", "")))
	crew_heist_state = _crew_heist_reopen_folded_plan(state)
	return true


func crew_heist_record_count_session(bet: int, heat_start: int, heat_peak: int, settled: bool = true, session_id: String = "", host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("plan_id", "")) != _run.CrewHeistModelScript.PLAN_COUNT or str(state.get("status", "")) != _run.CrewHeistModelScript.STATUS_SETUP:
		return {"ok": false}
	var tuning := JsonCoerceScript._copy_dict(JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.plan(_run.CrewHeistModelScript.PLAN_COUNT).get("setup", {})).get("identity", {}))
	var qualifies := settled and bet >= int(tuning.get("bet_min", 0)) and bet <= int(tuning.get("bet_max", 0)) and heat_peak <= int(tuning.get("heat_ceiling", 100)) and heat_peak - heat_start < int(tuning.get("heat_ceiling", 100))
	var setup := JsonCoerceScript._copy_dict(state.get("setup", {}))
	var session_ids := JsonCoerceScript._copy_array(setup.get("identity_session_ids", []))
	var clean_session_id := session_id.strip_edges()
	if clean_session_id.is_empty():
		clean_session_id = "%s:%d" % [_run._event_cadence_visit_key(_run.current_environment), int(_run.current_environment.get("turns", 0))]
	if session_ids.has(clean_session_id):
		qualifies = false
	elif qualifies:
		session_ids.append(clean_session_id)
	setup["identity_session_ids"] = session_ids
	var count := session_ids.size()
	setup["identity_sessions"] = count
	setup["identity"] = count >= int(tuning.get("required_sessions", 1))
	state["setup"] = setup
	crew_heist_state = state
	return {"ok": true, "qualified": qualifies, "sessions": count, "complete": bool(setup.get("identity", false)), "message": "Bishop keeps the sessions that look like furniture."}


func crew_heist_begin_count_schedule(host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	return _crew_heist_begin_setup_delivery("schedule", true)


func crew_heist_begin_count_swap_cart(host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	return _crew_heist_begin_setup_delivery("swap_cart", false)


func crew_heist_record_whale_vouch(session_loss: int, entourage_beat: bool = true, host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("plan_id", "")) != _run.CrewHeistModelScript.PLAN_WHALE or str(state.get("status", "")) != _run.CrewHeistModelScript.STATUS_SETUP:
		return {"ok": false}
	var tuning := JsonCoerceScript._copy_dict(JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.plan(_run.CrewHeistModelScript.PLAN_WHALE).get("setup", {})).get("vouch", {}))
	var setup := JsonCoerceScript._copy_dict(state.get("setup", {}))
	var rounds := int(setup.get("vouch_rounds", 0)) + (1 if entourage_beat and session_loss < 0 else 0)
	var loss := int(setup.get("vouch_loss", 0)) + maxi(0, -session_loss)
	setup["vouch_rounds"] = rounds
	setup["vouch_loss"] = loss
	setup["vouch"] = rounds >= int(tuning.get("rounds", 1)) and loss >= int(tuning.get("loss_target", 1))
	state["setup"] = setup
	crew_heist_state = state
	return {"ok": true, "rounds": rounds, "loss": loss, "complete": bool(setup.get("vouch", false))}


func _crew_heist_sync_whale_setup() -> void:
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("plan_id", "")) != _run.CrewHeistModelScript.PLAN_WHALE or str(state.get("status", "")) != _run.CrewHeistModelScript.STATUS_SETUP:
		return
	var setup := JsonCoerceScript._copy_dict(state.get("setup", {}))
	if bool(_run.narrative_flags.get("heist_plan_b_whale_vouch", false)) and not bool(setup.get("vouch_event_seeded", false)):
		setup["vouch_event_seeded"] = true
		setup["vouch_rounds"] = maxi(1, int(setup.get("vouch_rounds", 0)))
		setup["vouch_loss"] = maxi(18, int(setup.get("vouch_loss", 0)))
	var vouch_tuning := JsonCoerceScript._copy_dict(JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.plan(_run.CrewHeistModelScript.PLAN_WHALE).get("setup", {})).get("vouch", {}))
	setup["vouch"] = int(setup.get("vouch_rounds", 0)) >= int(vouch_tuning.get("rounds", 1)) and int(setup.get("vouch_loss", 0)) >= int(vouch_tuning.get("loss_target", 1))
	var has_component: bool = _run.inventory.has("false_bottom_cup")
	var trained := bool(_run.narrative_flags.get("craps_setting_trained", false))
	setup["rig"] = bool(setup.get("rig", false)) or (has_component and trained)
	var name_tuning := JsonCoerceScript._copy_dict(JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.plan(_run.CrewHeistModelScript.PLAN_WHALE).get("setup", {})).get("name", {}))
	setup["name_spend"] = maxi(int(setup.get("name_spend", 0)), _run.run_spending_score)
	setup["name_seen"] = JsonCoerceScript._copy_array(setup.get("name_seen_ids", [])).size()
	setup["name"] = int(setup.get("name_spend", 0)) >= int(name_tuning.get("spend_required", 0)) and int(setup.get("name_seen", 0)) >= int(name_tuning.get("seen_required", 0))
	state["setup"] = setup
	crew_heist_state = state


func _crew_heist_boundary_sync() -> void:
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	state = _crew_heist_sync_count_window(state)
	_crew_heist_sync_live_table_event(state)
	if str(state.get("plan_id", "")) != _run.CrewHeistModelScript.PLAN_WHALE or str(state.get("status", "")) != _run.CrewHeistModelScript.STATUS_SETUP:
		return
	var hooks := JsonCoerceScript._copy_dict(_run.current_environment.get("scenario_hook_flags", {}))
	if bool(hooks.get("heist_plan_b_criteria", false)) or bool(hooks.get("gala_night", false)):
		var setup := JsonCoerceScript._copy_dict(state.get("setup", {}))
		var seen_ids := JsonCoerceScript._copy_array(setup.get("name_seen_ids", []))
		var visit_id = _run._event_cadence_visit_key(_run.current_environment)
		if not visit_id.is_empty() and not seen_ids.has(visit_id):
			seen_ids.append(visit_id)
			setup["name_seen_ids"] = seen_ids
			state["setup"] = setup
			crew_heist_state = state
	_crew_heist_sync_whale_setup()


func crew_heist_begin_play(host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	if state.is_empty() or str(state.get("status", "")) != _run.CrewHeistModelScript.STATUS_SETUP:
		return {"ok": false, "message": "There is no prepared play."}
	var setup := JsonCoerceScript._copy_dict(state.get("setup", {}))
	if str(state.get("plan_id", "")) == _run.CrewHeistModelScript.PLAN_COUNT:
		setup["guard_marker"] = bool(_run.narrative_flags.get("debt_court_settlement", false)) and CrewStateModelScript.RANK_IDS.find(crew_rank("crew_knuckles")) >= CrewStateModelScript.RANK_IDS.find("associate")
	else:
		setup["drunk"] = bool(setup.get("vouch", false)) and bool(setup.get("rig", false)) and bool(setup.get("name", false))
	state["setup"] = setup
	if str(state.get("plan_id", "")) == _run.CrewHeistModelScript.PLAN_COUNT and not bool(setup.get("identity", false)):
		crew_heist_state = state
		var forced_abort := crew_heist_abort("identity_shortfall", host_capability)
		forced_abort["forced"] = bool(forced_abort.get("ok", false))
		forced_abort["message"] = "The identity never held. Bishop folds the score and the preparation cost stays spent."
		return forced_abort
	if not _run.CrewHeistModelScript.setup_complete(state):
		crew_heist_state = state
		return {"ok": false, "message": "The setup still has an empty chair."}
	state["status"] = _run.CrewHeistModelScript.STATUS_PLAY
	_run.narrative_flags["heist_live_table_active"] = true
	var play := JsonCoerceScript._copy_dict(state.get("play", {}))
	var begin_message := "The Play begins at the real table."
	if str(state.get("plan_id", "")) == _run.CrewHeistModelScript.PLAN_COUNT:
		var count_play := JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.plan(_run.CrewHeistModelScript.PLAN_COUNT).get("play", {}))
		var starting_float := maxi(0, int(count_play.get("starting_float", 0)))
		if not bool(play.get("table_float_granted", false)) and starting_float > 0:
			_run.change_grand_casino_chips(starting_float, true)
			play["table_float_granted"] = true
			play["table_float_chips"] = starting_float
			begin_message = "The Crew stakes %d table chips for the Count. The Play begins at the real table." % starting_float
	else:
		_run.change_grand_casino_chips(int(JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.plan(_run.CrewHeistModelScript.PLAN_WHALE).get("play", {})).get("starting_pot", 0)), true)
		play["pot"] = _run.grand_casino_chips
	state["play"] = play
	crew_heist_state = state
	state = _crew_heist_sync_count_window(state)
	_crew_heist_sync_live_table_event(state)
	return {"ok": true, "message": begin_message}


func crew_heist_decide(decision_id: String, choice: String, host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("status", "")) != _run.CrewHeistModelScript.STATUS_PLAY:
		return {"ok": false}
	var plan_id := str(state.get("plan_id", ""))
	var allowed := {"go": ["early", "hold"], "distraction": ["sit", "dump"], "exit": ["dock", "corridor"]}
	if plan_id != _run.CrewHeistModelScript.PLAN_COUNT or not allowed.has(decision_id) or not JsonCoerceScript._copy_array(allowed.get(decision_id, [])).has(choice):
		return {"ok": false}
	var setup := JsonCoerceScript._copy_dict(state.get("setup", {}))
	if decision_id == "exit" and choice == "corridor" and not bool(setup.get("guard_marker", false)):
		return {"ok": false, "message": "The corridor has no marker."}
	var play := JsonCoerceScript._copy_dict(state.get("play", {}))
	if decision_id == "exit" and choice == "corridor" and bool(play.get("corridor_blown", false)):
		return {"ok": false, "message": "The heat spike has already blown the corridor."}
	if _crew_heist_count_decision_due(state) != decision_id:
		return {"ok": false, "message": "That crew beat is not live in this round."}
	var decisions := JsonCoerceScript._copy_dict(play.get("decisions", {}))
	decisions[decision_id] = choice
	play["decisions"] = decisions
	if choice in ["early", "dump"]:
		play["score"] = int(play.get("score", 100)) - 12
	if decision_id == "distraction":
		play["deliberate_heat"] = 6
		_run.add_suspicion("heist_count_distraction", 6, "crew_heist", true)
	state["play"] = play
	crew_heist_state = state
	return {"ok": true, "decision": decision_id, "choice": choice}


func crew_heist_play_round(round_data: Dictionary, host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("status", "")) != _run.CrewHeistModelScript.STATUS_PLAY:
		return {"ok": false}
	var plan_id := str(state.get("plan_id", ""))
	var tuning := JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.plan(plan_id).get("play", {}))
	var play := JsonCoerceScript._copy_dict(state.get("play", {}))
	var next_round := int(play.get("round", 0)) + 1
	var score := int(play.get("score", 100))
	if plan_id == _run.CrewHeistModelScript.PLAN_COUNT:
		state = _crew_heist_sync_count_window(state)
		play = JsonCoerceScript._copy_dict(state.get("play", {}))
		score = int(play.get("score", 100))
		if not _crew_heist_at_designated_table(state):
			return {"ok": false, "message": "The Count only moves at its designated table."}
		if _crew_heist_count_decision_due(state) != "":
			return {"ok": false, "message": "Bishop's live-table beat is still waiting."}
		if str(round_data.get("game_id", "")) != str(tuning.get("table_game", "blackjack")):
			return {"ok": false, "message": "That is not the designated boring table."}
		var bet := int(round_data.get("bet", 0))
		if bet < int(tuning.get("boring_bet_min", 0)) or bet > int(tuning.get("boring_bet_max", 0)):
			score -= 12
		if int(round_data.get("heat_delta", 0)) >= int(tuning.get("heat_spike", 1)):
			score -= 20
			play["heat_degraded"] = true
			play["corridor_blown"] = true
	else:
		if not _crew_heist_at_designated_table(state):
			return {"ok": false, "message": "The invitational is not running in this room."}
		var sequence := JsonCoerceScript._copy_array(tuning.get("game_sequence", []))
		var expected_game_id := str(sequence[next_round - 1]) if next_round - 1 < sequence.size() else ""
		if expected_game_id.is_empty() or str(round_data.get("game_id", "")) != expected_game_id:
			return {"ok": false, "expected_game_id": expected_game_id, "message": "The invitational calls a different game this round."}
		var hazard := false
		for hazard_round_value in JsonCoerceScript._copy_array(tuning.get("hazard_rounds", [])):
			if int(hazard_round_value) == next_round:
				hazard = true
				break
		var hidden := CrewTurnModelScript.normalize_state(state.get("x", {}), CrewStateModelScript.MEMBER_IDS)
		if hazard and not CrewTurnModelScript.active_member(hidden, CrewStateModelScript.MEMBER_IDS).is_empty():
			return _crew_heist_finish_whale_exposure(state, next_round, hidden)
		var honest := bool(round_data.get("honest", false))
		if hazard:
			var hazards := JsonCoerceScript._copy_array(play.get("hazards", []))
			hazards.append({"round": next_round, "honest": honest})
			play["hazards"] = hazards
			score += 5 if honest else -30
		if bool(round_data.get("made", false)):
			score -= 25
			play["made"] = true
		play["pot"] = _run.grand_casino_chips
		if int(play.get("pot", 0)) <= 0:
			play["bust"] = true
		var lifeline_sequence := _crew_heist_live_lifeline_sequence(str(round_data.get("game_id", "")), play)
		if lifeline_sequence > 0:
			var lifelines: Array = play.get("lifelines_used", [])
			if lifelines.size() < int(tuning.get("lifelines", 0)):
				lifelines.append(lifeline_sequence)
				play["lifelines_used"] = lifelines
				score += 8
	play["round"] = next_round
	play["score"] = clampi(score, 0, 100)
	state["play"] = play
	crew_heist_state = state
	return {"ok": true, "round": next_round, "score": int(play.get("score", 0)), "ready": next_round >= int(tuning.get("required_rounds", 1))}


func _crew_heist_finish_whale_exposure(state_value: Dictionary, round_index: int, hidden: Dictionary) -> Dictionary:
	var state = _run.CrewHeistModelScript.normalize_state(state_value)
	var play := JsonCoerceScript._copy_dict(state.get("play", {}))
	play["round"] = round_index
	play["interrupted"] = "house_points_at_rig"
	state["play"] = play
	var hedged := bool(hidden.get("h", false))
	var outcome := "out_hot" if hedged else "closed"
	var payout := 0
	var scar_id := ""
	if hedged:
		payout = _crew_heist_hidden_partial_payout(state)
		_run.add_suspicion("heist_whale_exit", 10, "crew_heist", true, {}, true)
	else:
		scar_id = "rig_exposure"
		_run.add_suspicion("heist_whale_rig_exposed", 25, "contraband", true, {}, true)
	_run.grand_casino_chips = 0
	_run.bankroll += payout
	state["status"] = _run.CrewHeistModelScript.STATUS_COMPLETED
	state["outcome"] = outcome
	state["payout"] = payout
	if not scar_id.is_empty():
		play["scar"] = scar_id
		state["play"] = play
		_run.story_flags["heist_scar_%s" % scar_id] = true
	crew_heist_state = state
	_run.narrative_flags["heist_live_table_active"] = false
	_crew_heist_sync_live_table_event(state)
	var message = _run.CrewHeistModelScript.ending_line(_run.CrewHeistModelScript.PLAN_WHALE, outcome)
	_run.narrative_flags["crew_heist_outcome"] = outcome
	_run.narrative_flags["crew_heist_plan_id"] = _run.CrewHeistModelScript.PLAN_WHALE
	_run._complete_demo_objective({"id": _run.CREW_HEIST_ROUTE, "target_bankroll": _run.bankroll, "victory_message": message}, message, {"finale_event_id": "heist_finale", "finale_branch": outcome, "demo_victory_route": _run.CREW_HEIST_ROUTE})
	_run.narrative_flags["act_two_seam_ready"] = true
	return {"ok": true, "resolved": true, "outcome": outcome, "payout": payout, "message": message}


func _crew_heist_hidden_partial_payout(state: Dictionary) -> int:
	var band := JsonCoerceScript._copy_array(JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.config().get("hidden_resolution", {})).get("partial_haul_percent_band", [35, 55]))
	var low := int(band[0]) if band.size() > 0 else 35
	var high := int(band[1]) if band.size() > 1 else low
	var partial_rng = _run.create_rng("crew_heist_hidden").fork("partial:%s:%d" % [str(state.get("plan_id", "")), int(state.get("locked_action", 0))])
	return int(floor(float(_run.CrewHeistModelScript.payout_for(state, "clean_sweep")) * float(partial_rng.randi_range(low, high)) / 100.0))


func crew_heist_begin_interview(host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("plan_id", "")) != _run.CrewHeistModelScript.PLAN_WHALE or str(state.get("status", "")) != _run.CrewHeistModelScript.STATUS_PLAY:
		return {"ok": false, "message": "No invitational pot is ready for the cage."}
	var play := JsonCoerceScript._copy_dict(state.get("play", {}))
	var required_rounds := int(JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.plan(_run.CrewHeistModelScript.PLAN_WHALE).get("play", {})).get("required_rounds", 1))
	if int(play.get("round", 0)) < required_rounds:
		return {"ok": false, "message": "The invitational is not finished."}
	var cracked := int(play.get("score", 100)) < int(JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.plan(_run.CrewHeistModelScript.PLAN_WHALE).get("interview", {})).get("clean_score_min", 80)) or bool(play.get("made", false)) or bool(play.get("bust", false))
	state["status"] = _run.CrewHeistModelScript.STATUS_INTERVIEW
	state["interview"] = {"started_action": _crew_action_index(), "cracked": cracked, "resolved": false}
	crew_heist_state = state
	return {"ok": true, "cracked": cracked, "message": "The cage counts the chips. Rourke lets the borrowed name answer for them."}


func crew_heist_resolve_interview(choice: String, host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("plan_id", "")) != _run.CrewHeistModelScript.PLAN_WHALE or str(state.get("status", "")) != _run.CrewHeistModelScript.STATUS_INTERVIEW:
		return {"ok": false}
	var interview := JsonCoerceScript._copy_dict(state.get("interview", {}))
	if bool(interview.get("resolved", false)) or not ["show_receipt", "cut_short"].has(choice):
		return {"ok": false}
	if bool(interview.get("cracked", false)) and choice == "show_receipt":
		return {"ok": false, "message": "The borrowed name has already cracked."}
	interview["resolved"] = true
	interview["choice"] = choice
	if choice == "cut_short":
		interview["cracked"] = true
	state["interview"] = interview
	crew_heist_state = state
	return crew_heist_begin_getaway(host_capability)


func crew_heist_begin_getaway(host_capability: Variant = null) -> Dictionary:
	if host_capability == null or host_capability != _crew_heist_host_capability: return {"ok": false}
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	var plan_id := str(state.get("plan_id", ""))
	var phase := str(state.get("status", ""))
	if (plan_id == _run.CrewHeistModelScript.PLAN_COUNT and phase != _run.CrewHeistModelScript.STATUS_PLAY) or (plan_id == _run.CrewHeistModelScript.PLAN_WHALE and (phase != _run.CrewHeistModelScript.STATUS_INTERVIEW or not bool(JsonCoerceScript._copy_dict(state.get("interview", {})).get("resolved", false)))):
		return {"ok": false, "message": "The Play is not ready to leave."}
	var definition = _run.CrewHeistModelScript.plan(plan_id)
	var play := JsonCoerceScript._copy_dict(state.get("play", {}))
	var play_tuning := JsonCoerceScript._copy_dict(definition.get("play", {}))
	if int(play.get("round", 0)) < int(play_tuning.get("required_rounds", 1)):
		return {"ok": false, "message": "The table sequence is not finished."}
	if str(state.get("plan_id", "")) == _run.CrewHeistModelScript.PLAN_COUNT and JsonCoerceScript._copy_dict(play.get("decisions", {})).size() < 3:
		return {"ok": false, "message": "The Count still has a decision open."}
	var exit_choice := str(JsonCoerceScript._copy_dict(play.get("decisions", {})).get("exit", "dock")) if plan_id == _run.CrewHeistModelScript.PLAN_COUNT else "front_door"
	if plan_id == _run.CrewHeistModelScript.PLAN_COUNT and bool(play.get("corridor_blown", false)):
		exit_choice = "dock"
	var target_id := _crew_heist_getaway_target(plan_id, exit_choice)
	if target_id.is_empty():
		return {"ok": false, "message": "The real town has no valid exit route."}
	var getaway_tuning := JsonCoerceScript._copy_dict(definition.get("getaway", {}))
	var tuning := JsonCoerceScript._copy_dict(JsonCoerceScript._copy_dict(getaway_tuning.get("routes", {})).get(exit_choice, {})) if plan_id == _run.CrewHeistModelScript.PLAN_COUNT else getaway_tuning
	var hot_whale_exit = plan_id == _run.CrewHeistModelScript.PLAN_WHALE and (bool(JsonCoerceScript._copy_dict(state.get("interview", {})).get("cracked", false)) or int(play.get("score", 100)) < 80 or bool(play.get("made", false)) or bool(play.get("bust", false)))
	var pursuit_pressure := 0
	if plan_id == _run.CrewHeistModelScript.PLAN_COUNT:
		pursuit_pressure = int(tuning.get("pursuit_pressure", 0)) + (10 if bool(play.get("heat_degraded", false)) else 0)
	elif hot_whale_exit:
		pursuit_pressure = int(tuning.get("hot_pursuit_pressure", 0)) + (10 if bool(play.get("made", false)) or bool(play.get("bust", false)) else 0)
	var started = _run.delivery_begin_getaway({
		"enabled": true,
		"run_id": "heist:%s:getaway" % str(state.get("plan_id", "")),
		"targets": [{"node_id": target_id}],
		"deadline_actions": int(tuning.get("deadline_actions", 10)),
		"pursuit_pressure": pursuit_pressure,
		"pursuit_per_boundary": 0 if plan_id == _run.CrewHeistModelScript.PLAN_WHALE and not hot_whale_exit else 2,
		"pursuit_limit": int(tuning.get("pursuit_limit", 10)),
		"assists": ["rook_cutoff", "switch_route"],
		"assist_relief": 4,
		"cargo_id": "heist_take",
		"cargo_label": "The take",
		"cargo_heat_per_travel": 0,
		"consumer_payload": {"start_boundary_grace": 1},
	})
	if not bool(started.get("ok", false)):
		return started
	state["status"] = _run.CrewHeistModelScript.STATUS_GETAWAY
	state["getaway"] = {"target_node_id": target_id, "exit": exit_choice, "status": "active", "chase": plan_id == _run.CrewHeistModelScript.PLAN_COUNT or hot_whale_exit}
	crew_heist_state = state
	_run.narrative_flags["heist_live_table_active"] = false
	_crew_heist_sync_live_table_event(state)
	return started


func crew_heist_snapshot() -> Dictionary:
	var public_state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	public_state.erase("x")
	return public_state


func _crew_heist_whale_attention_active() -> bool:
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	return str(state.get("plan_id", "")) == _run.CrewHeistModelScript.PLAN_WHALE and str(state.get("status", "")) in [_run.CrewHeistModelScript.STATUS_PLAY, _run.CrewHeistModelScript.STATUS_INTERVIEW, _run.CrewHeistModelScript.STATUS_GETAWAY] and _run._is_grand_casino_environment(_run.current_environment)


func _crew_heist_capture_whale_attention() -> bool:
	if not _crew_heist_whale_attention_active() or _run.suspicion_level() < 100:
		return false
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	var play := JsonCoerceScript._copy_dict(state.get("play", {}))
	if not bool(play.get("made", false)):
		play["made"] = true
		play["score"] = maxi(0, int(play.get("score", 100)) - 25)
	play["rourke_attention_capped"] = true
	state["play"] = play
	crew_heist_state = state
	_run.add_suspicion("heist_rourke_attention", -1, "crew_heist", true)
	return true


func _crew_heist_count_decision_due(state: Dictionary) -> String:
	if str(state.get("plan_id", "")) != _run.CrewHeistModelScript.PLAN_COUNT or str(state.get("status", "")) != _run.CrewHeistModelScript.STATUS_PLAY:
		return ""
	var play := JsonCoerceScript._copy_dict(state.get("play", {}))
	var decisions := JsonCoerceScript._copy_dict(play.get("decisions", {}))
	var round_index := int(play.get("round", 0))
	var decision_rounds := JsonCoerceScript._copy_dict(JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.plan(_run.CrewHeistModelScript.PLAN_COUNT).get("play", {})).get("decision_rounds", {}))
	for decision_id in ["go", "distraction", "exit"]:
		if not decisions.has(decision_id) and round_index == int(decision_rounds.get(decision_id, -1)):
			return decision_id
	return ""


func _crew_heist_live_lifeline_sequence(game_id: String, play: Dictionary) -> int:
	var crew_state = _run.CrewPlayModelScript.normalize_state(crew_play_state)
	var sequence := int(crew_state.get("sequence", 0))
	if sequence <= 0 or JsonCoerceScript._copy_array(play.get("lifelines_used", [])).has(sequence):
		return 0
	var beat := JsonCoerceScript._copy_dict(crew_state.get("last_beat", {}))
	if str(beat.get("play_id", "")).is_empty():
		return 0
	var beat_is_current := int(beat.get("action_index", -1000)) >= _crew_action_index() - 1
	var active_match := false
	for active_value in JsonCoerceScript._copy_array(crew_state.get("active", [])):
		var active := JsonCoerceScript._copy_dict(active_value)
		if int(active.get("sequence", 0)) == sequence and (str(active.get("game_id", "")).is_empty() or str(active.get("game_id", "")) == game_id):
			active_match = _run.CrewPlayModelScript.is_active(crew_state, str(active.get("play_id", "")), _crew_action_index(), _run.current_environment)
			break
	return sequence if beat_is_current or active_match else 0


func _crew_heist_sync_count_window(state: Dictionary) -> Dictionary:
	if str(state.get("plan_id", "")) != _run.CrewHeistModelScript.PLAN_COUNT or str(state.get("status", "")) != _run.CrewHeistModelScript.STATUS_PLAY:
		return state
	var play := JsonCoerceScript._copy_dict(state.get("play", {}))
	var tuning := JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.plan(_run.CrewHeistModelScript.PLAN_COUNT).get("play", {}))
	if int(play.get("round", 0)) >= int(tuning.get("required_rounds", 1)):
		return state
	var action_index := _crew_action_index()
	if not play.has("window_started_action"):
		if not _crew_heist_at_designated_table(state):
			return state
		play["window_started_action"] = action_index
		play["window_deadline_action"] = action_index + maxi(1, int(tuning.get("window_actions", 1)))
		play["table_visit_id"] = _run._event_cadence_visit_key(_run.current_environment)
	elif not _crew_heist_at_designated_table(state) and not bool(play.get("left_table", false)):
		play["left_table"] = true
		play["corridor_blown"] = true
		play["score"] = maxi(0, int(play.get("score", 100)) - 15)
	# The deadline is the final allowed boundary. Three minimum blackjack hands
	# consume the Count's authored nine actions exactly; lateness begins only
	# after that inclusive budget, matching delivery-window settlement.
	if action_index > int(play.get("window_deadline_action", action_index + 1)) and not bool(play.get("late", false)):
		play["late"] = true
		play["heat_degraded"] = true
		play["corridor_blown"] = true
		play["score"] = maxi(0, int(play.get("score", 100)) - 20)
	state["play"] = play
	crew_heist_state = state
	return state


func _crew_heist_at_designated_table(state: Dictionary) -> bool:
	var archetype_id := str(_run.current_environment.get("archetype_id", ""))
	if str(state.get("plan_id", "")) == _run.CrewHeistModelScript.PLAN_COUNT:
		return archetype_id in _run.GRAND_CASINO_ARCHETYPE_IDS
	return archetype_id == str(JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.plan(_run.CrewHeistModelScript.PLAN_WHALE).get("play", {})).get("venue_archetype", _run.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID))


func _crew_heist_sync_live_table_event(state: Dictionary) -> void:
	var phase := str(state.get("status", ""))
	var should_register := phase in [_run.CrewHeistModelScript.STATUS_PLAY, _run.CrewHeistModelScript.STATUS_INTERVIEW] and _crew_heist_at_designated_table(state)
	var was_registered := bool(_run.narrative_flags.get("heist_live_table_registered", false))
	# Crew-ignoring runs must remain byte-identical at every boundary.  The
	# expensive world scan is cleanup for an event we actually registered, not
	# a speculative repair pass for every run in the game.
	if not was_registered and not should_register:
		return
	if was_registered:
		_run._remove_heist_live_table_event(_run.current_environment)
		var nodes := JsonCoerceScript._copy_array(_run.world_map.get("nodes", []))
		for index in range(nodes.size()):
			if typeof(nodes[index]) == TYPE_DICTIONARY:
				var node := JsonCoerceScript._copy_dict(nodes[index])
				var environment := JsonCoerceScript._copy_dict(node.get("environment", {}))
				_run._remove_heist_live_table_event(environment)
				node["environment"] = environment
				nodes[index] = node
		_run.world_map["nodes"] = nodes
		for room_id_value in _run.grand_casino_room_states.keys():
			var room: Variant = _run.grand_casino_room_states.get(room_id_value, {})
			if typeof(room) == TYPE_DICTIONARY:
				var clean_room := JsonCoerceScript._copy_dict(room)
				_run._remove_heist_live_table_event(clean_room)
				_run.grand_casino_room_states[room_id_value] = clean_room
		_run.narrative_flags.erase("heist_live_table_registered")
	if not should_register:
		return
	var event_ids := JsonCoerceScript._copy_array(_run.current_environment.get("event_ids", []))
	if not event_ids.has("heist_live_table"):
		event_ids.append("heist_live_table")
		_run.current_environment["event_ids"] = event_ids
		# This event is a real object on the current environment plane. Give the
		# newly appended object the same generated layout authority as every other
		# environment event before semantic presentation is sealed.
		_run.current_environment["layout"] = EnvironmentInstance.ensure_generated_layout(_run.current_environment)
	_run.narrative_flags["heist_live_table_registered"] = true


func _crew_heist_world_has_hook(hook_id: String) -> bool:
	if hook_id.is_empty():
		return false
	# The Count may use the Audit only while it is literally the current public
	# situation, or after the player has read its visible roster. Do not infer
	# this fact from an unvisited seed or a stale stored environment: both leak
	# private/cycle-old scenario selection into the planning table.
	if hook_id == "audit_night":
		var current_hook_value = JsonCoerceScript._copy_dict(_run.current_environment.get("scenario_hook_flags", {})).get(hook_id, false)
		var learned_audit_value = _run.story_flags.get(COUNT_AUDIT_KNOWLEDGE_FLAG, false)
		return (typeof(current_hook_value) == TYPE_BOOL and bool(current_hook_value)) \
			or (typeof(learned_audit_value) == TYPE_BOOL and bool(learned_audit_value))
	if bool(JsonCoerceScript._copy_dict(_run.current_environment.get("scenario_hook_flags", {})).get(hook_id, false)):
		return true
	for node_value in JsonCoerceScript._copy_array(_run.world_map.get("nodes", [])):
		var node := JsonCoerceScript._copy_dict(node_value)
		var environment := JsonCoerceScript._copy_dict(node.get("environment", {}))
		if bool(JsonCoerceScript._copy_dict(environment.get("scenario_hook_flags", {})).get(hook_id, false)):
			return true
		var definition = _run._seeded_scenario_definition_for_node_readonly(str(node.get("id", "")))
		if bool(JsonCoerceScript._copy_dict(JsonCoerceScript._copy_dict(definition.get("mutations", {})).get("hook_flags", {})).get(hook_id, false)):
			return true
	return false


func _crew_heist_begin_setup_delivery(step: String, hold: bool) -> Dictionary:
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("plan_id", "")) != _run.CrewHeistModelScript.PLAN_COUNT or str(state.get("status", "")) != _run.CrewHeistModelScript.STATUS_SETUP:
		return {"ok": false}
	var setup := JsonCoerceScript._copy_dict(state.get("setup", {}))
	if bool(setup.get(step, false)):
		return {"ok": false, "message": "That setup is already complete."}
	# Every Grand Casino room is an interior of the one real town-map node. Keep
	# the route on that canonical node and carry the exact room as an opt-in
	# delivery constraint; map-hidden Cage/Main room ids must never masquerade as
	# world destinations.
	var target_room_archetype_id := str(_run.GRAND_CASINO_CAGE_ARCHETYPE_ID if hold else _run.GRAND_CASINO_ARCHETYPE_ID)
	var target_id := _crew_heist_node_for_archetype(_run.GRAND_CASINO_ARCHETYPE_ID)
	if target_id.is_empty():
		return {"ok": false, "message": "The setup has no real venue tonight."}
	var tuning := JsonCoerceScript._copy_dict(JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.plan(_run.CrewHeistModelScript.PLAN_COUNT).get("setup", {})).get(step, {}))
	var spec := {
		"run_id": "heist:%s:%s" % [_run.CrewHeistModelScript.PLAN_COUNT, step],
		"targets": [{"node_id": target_id}],
		"deadline_actions": int(tuning.get("deadline_actions", 12)),
		"cargo_id": "heist_swap_cart" if not hold else "heist_schedule_watch",
		"cargo_label": "Swap cart" if not hold else "Shift schedule",
		"cargo_heat_per_travel": 0,
		"consumer_payload": {"required_target_archetype_id": target_room_archetype_id},
	}
	if hold:
		spec["hold_required_actions"] = int(tuning.get("hold_required_actions", 2))
		spec["hold_attention_limit"] = int(tuning.get("attention_limit", 40))
	return _run.delivery_begin_hold(spec) if hold else _run.delivery_begin_package(spec)


func _crew_heist_setup_delivery_active(step: String) -> bool:
	if not _run.delivery_has_active_run():
		return false
	return str(_run.active_delivery_run.get("run_id", "")) == "heist:%s:%s" % [_run.CrewHeistModelScript.PLAN_COUNT, step]


func _crew_heist_node_for_archetype(archetype_id: String) -> String:
	for node_value in JsonCoerceScript._copy_array(_run.world_map.get("nodes", [])):
		var node := JsonCoerceScript._copy_dict(node_value)
		if str(node.get("archetype_id", "")) == archetype_id:
			return str(node.get("id", ""))
	return ""


func _crew_heist_getaway_target(plan_id: String, _exit_choice: String = "") -> String:
	var preferred_archetype := "small_underground_casino"
	if plan_id == _run.CrewHeistModelScript.PLAN_COUNT:
		# Dock and corridor are distinct cart exits inside the score, but both
		# converge on Rook's real dock-side getaway node. Grand Casino rooms are
		# interiors, never town-map destinations.
		preferred_archetype = "delta_queen"
	var preferred := _crew_heist_node_for_archetype(preferred_archetype)
	if not preferred.is_empty() and preferred != _run.current_world_node_id():
		return preferred
	return ""


func _crew_heist_apply_delivery_resolution(run_id: String, succeeded: bool, resolution: Dictionary) -> void:
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	if state.is_empty() or not run_id.begins_with("heist:%s:" % str(state.get("plan_id", ""))):
		return
	var part := run_id.get_slice(":", 2)
	if part in ["schedule", "swap_cart"]:
		if succeeded:
			var setup := JsonCoerceScript._copy_dict(state.get("setup", {}))
			setup[part] = true
			state["setup"] = setup
		crew_heist_state = state
		return
	if part != "getaway" or str(state.get("status", "")) != _run.CrewHeistModelScript.STATUS_GETAWAY:
		return
	var play := JsonCoerceScript._copy_dict(state.get("play", {}))
	var hidden := CrewTurnModelScript.normalize_state(state.get("x", {}), CrewStateModelScript.MEMBER_IDS)
	var active_member := CrewTurnModelScript.active_member(hidden, CrewStateModelScript.MEMBER_IDS)
	var outcome = _run.CrewHeistModelScript.ladder(int(play.get("score", 0)), succeeded, bool(play.get("made", false)), bool(play.get("bust", false)))
	var payout = _run.CrewHeistModelScript.payout_for(state, outcome)
	var scar_id := ""
	if not active_member.is_empty():
		if bool(hidden.get("h", false)):
			outcome = "out_hot"
			payout = _crew_heist_hidden_partial_payout(state)
		else:
			outcome = "closed"
			payout = 0
			scar_id = "corridor_breach" if str(state.get("plan_id", "")) == _run.CrewHeistModelScript.PLAN_COUNT else "rig_exposure"
	if str(state.get("plan_id", "")) == _run.CrewHeistModelScript.PLAN_WHALE:
		_run.grand_casino_chips = 0
	_run.bankroll += payout
	state["status"] = _run.CrewHeistModelScript.STATUS_COMPLETED
	state["outcome"] = outcome
	state["payout"] = payout
	var getaway := JsonCoerceScript._copy_dict(state.get("getaway", {}))
	getaway["status"] = "success" if succeeded else "failed"
	getaway["resolution"] = resolution.duplicate(true)
	if not scar_id.is_empty():
		getaway["scar"] = scar_id
		if scar_id == "corridor_breach":
			getaway["corridor_failed"] = true
			_run.add_suspicion("heist_count_corridor_breach", 15, "crew_heist", true, {}, true)
		_run.story_flags["heist_scar_%s" % scar_id] = true
	state["getaway"] = getaway
	crew_heist_state = state
	_run.narrative_flags["heist_live_table_active"] = false
	_crew_heist_sync_live_table_event(state)
	var message = _run.CrewHeistModelScript.ending_line(str(state.get("plan_id", "")), outcome)
	_run.narrative_flags["crew_heist_outcome"] = outcome
	_run.narrative_flags["crew_heist_plan_id"] = str(state.get("plan_id", ""))
	_run._complete_demo_objective({"id": _run.CREW_HEIST_ROUTE, "target_bankroll": _run.bankroll, "victory_message": message}, message, {"finale_event_id": "heist_finale", "finale_branch": outcome, "demo_victory_route": _run.CREW_HEIST_ROUTE})
	_run.narrative_flags["act_two_seam_ready"] = true


func crew_grievances(member_id: String = "") -> Array:
	var result: Array = []
	for entry_value in crew_grievance_ledger:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if member_id.is_empty() or str(entry.get("member_id", "")) == member_id:
			result.append(entry.duplicate(true))
	return result


func crew_record_pattern(member_id: String, state_key: String) -> bool:
	var before = _run.tell_learned(member_id)
	crew_pattern_memory = _run.CrewPokerModelScript.record_verified(crew_pattern_memory, member_id, state_key)
	return not before and _run.tell_learned(member_id)


func crew_record_poker_session(member_ids: Array, session_swing: int) -> Dictionary:
	var tuning = _run.CrewPokerModelScript.config()
	var base_trust := maxi(0, int(tuning.get("session_trust", 2)))
	var threshold := maxi(1, int(tuning.get("hustle_threshold", 12)))
	var repeats := maxi(1, int(tuning.get("hustle_sessions_required", 2)))
	var bonus := maxi(0, int(tuning.get("hustle_respect_bonus", 1)))
	var applied := {}
	for member_value in member_ids:
		var member_id := str(member_value)
		if not CrewStateModelScript.MEMBER_IDS.has(member_id):
			continue
		var mark := int(crew_match_marks.get(member_id, 0))
		mark = mark + 1 if session_swing >= threshold else 0
		crew_match_marks[member_id] = mark
		var amount := base_trust + (bonus if mark >= repeats else 0)
		crew_add_trust(member_id, amount, "crew_poker_session")
		applied[member_id] = amount
	return applied


func _crew_heist_job_payment(member_id: String, posted_cash: int, job_id: String) -> Dictionary:
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	if str(state.get("status", "")) != _run.CrewHeistModelScript.STATUS_SETUP or posted_cash <= 0:
		return {"paid": posted_cash}
	var hidden := CrewTurnModelScript.normalize_state(state.get("x", {}), CrewStateModelScript.MEMBER_IDS)
	if CrewTurnModelScript.active_member(hidden, CrewStateModelScript.MEMBER_IDS) != member_id or JsonCoerceScript._copy_array(hidden.get("e", [])).has(CrewTurnModelScript.SIGNAL_PAYMENT):
		return {"paid": posted_cash}
	var percent := clampi(int(JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.config().get("hidden_resolution", {})).get("payment_shortfall_percent", 25)), 1, 90)
	var shortfall := maxi(1, int(ceil(float(posted_cash) * float(percent) / 100.0)))
	var paid := maxi(0, posted_cash - shortfall)
	hidden = CrewTurnModelScript.mark_emitted(hidden, CrewTurnModelScript.SIGNAL_PAYMENT, true, CrewStateModelScript.MEMBER_IDS)
	state["x"] = hidden
	crew_heist_state = state
	assert(posted_cash - paid == shortfall and shortfall > 0, "Job payment did not retain a checkable board figure.")
	return {"paid": paid, "posted": posted_cash, "source": job_id}


func crew_job_board_offers() -> Array:
	var result: Array = []
	for definition_value in CrewStateModelScript.job_definitions():
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = definition_value
		var definition_id := str(definition.get("id", ""))
		if definition_id == "crew_favor_delivery" or crew_job_definition_pending(definition_id):
			continue
		var member_id := str(definition.get("member_id", ""))
		var min_rank := str(definition.get("min_rank", "associate"))
		if not crew_member_present(member_id) \
			or CrewStateModelScript.RANK_IDS.find(crew_rank(member_id)) < CrewStateModelScript.RANK_IDS.find(min_rank):
			continue
		result.append({
			"definition_id": definition_id,
			"label": str(definition.get("label", definition_id.replace("_", " ").capitalize())),
			"member_id": member_id,
			"kind": str(definition.get("kind", "")),
			"expiry_in_actions": int(definition.get("expiry_in_actions", 1)),
			"cash": int(JsonCoerceScript._copy_dict(definition.get("rewards", {})).get("cash", 0)),
			"trust": int(JsonCoerceScript._copy_dict(definition.get("rewards", {})).get("trust", 0)),
			"member_present": true,
		})
	return result


func crew_job_board_choices(payload: Dictionary = {}) -> Array:
	var result: Array = []
	var flavor_lines := JsonCoerceScript._string_array(payload.get("flavor_lines", []))
	var flavor_line := ""
	if not flavor_lines.is_empty():
		flavor_line = str(flavor_lines[posmod(_run.seed_value + _crew_action_index(), flavor_lines.size())])
	for offer_value in crew_job_board_offers():
		var offer: Dictionary = offer_value
		var member_name := str(offer.get("member_id", "crew")).trim_prefix("crew_").capitalize()
		var expiry_text := PlayerTextScript.count_text("action", int(offer.get("expiry_in_actions", 1)))
		var detail := "%s%s · %s · $%d / trust %+d." % [
			str(offer.get("kind", "job")).replace("_", " ").capitalize(),
			" · here tonight",
			expiry_text, int(offer.get("cash", 0)), int(offer.get("trust", 0))]
		# The event surface has no board-level subtitle, so project the rotating
		# board note once on the first row instead of repeating it for every job.
		if not flavor_line.is_empty() and result.is_empty():
			detail = "%s\n%s" % [flavor_line, detail]
		result.append({
			"id": "accept_%s" % str(offer.get("definition_id", "")),
			"label": "%s · %s" % [str(offer.get("label", "Work")), member_name],
			"text": detail,
			"consequences": {"event_hooks": [{"type": "crew_job_accept", "definition_id": str(offer.get("definition_id", ""))}]},
		})
	result.append({"id": "leave", "label": "Leave the board", "text": "No promise made. The chalk stays clean.", "consequences": {}})
	return result


func crew_job_accept_definition(definition_id: String) -> Dictionary:
	var definition := CrewStateModelScript.job_definition(definition_id)
	if definition.is_empty() or crew_job_definition_pending(definition_id):
		return {"ok": false, "message": "That note is no longer open."}
	var member_id := str(definition.get("member_id", ""))
	var min_rank := str(definition.get("min_rank", "associate"))
	if not crew_member_present(member_id):
		return {"ok": false, "message": "That crew member is not in the room."}
	if CrewStateModelScript.RANK_IDS.find(crew_rank(member_id)) < CrewStateModelScript.RANK_IDS.find(min_rank):
		return {"ok": false, "message": "That work is above your standing."}
	var offered = _run.job_offer(definition, _crew_job_host_capability)
	var job_id := str(offered.get("id", ""))
	if job_id.is_empty() or _run.job_accept(job_id, _crew_job_host_capability).is_empty() or _run.job_activate(job_id, _crew_job_host_capability).is_empty():
		return {"ok": false, "message": "The note will not come off the wall."}
	var payload := JsonCoerceScript._copy_dict(definition.get("payload", {}))
	var kind := str(definition.get("kind", ""))
	if kind in ["package_run", "package_delivery", "numbers_route", "lookout_hold", "collection"]:
		var spec := payload.duplicate(true)
		spec["run_id"] = "crew_job:%s" % job_id
		spec["job_id"] = "" if kind == "collection" else job_id
		spec["deadline_actions"] = int(definition.get("expiry_in_actions", 1))
		spec["consumer_payload"] = {"success": {"cash": 0, "heat": 0}, "failure": {"cash": 0, "heat": 0}}
		var started = _run.delivery_begin_multi_stop(spec) if kind == "numbers_route" else _run.delivery_begin_hold(spec) if kind == "lookout_hold" else _run.delivery_begin_package(spec)
		if not bool(started.get("ok", false)):
			_run.job_resolve(job_id, "failed", _crew_job_host_capability)
			return started
		if kind == "collection":
			_run.active_delivery_run["run_id"] = "crew_collection:%s" % job_id
		return {"ok": true, "job_id": job_id, "kind": kind, "delivery": started, "message": "The real-map route is marked."}
	if kind == "stake_horse":
		var stake := maxi(1, int(payload.get("crew_stake", 1)))
		payload["session_net"] = 0
		payload["loss_choice_pending"] = false
		var job := _crew_job(job_id)
		job["payload"] = payload
		crew_jobs[job_id] = job
		_run.change_bankroll(stake, true)
		return {"ok": true, "job_id": job_id, "kind": kind, "crew_stake": stake, "message": "Crew money is in your pocket. Play the named game."}
	_run.job_resolve(job_id, "failed", _crew_job_host_capability)
	return {"ok": false, "message": "That job kind has no live surface."}


func crew_record_game_result(result: Dictionary, deltas: Dictionary) -> Dictionary:
	var game_id := str(result.get("game_id", result.get("source_id", "")))
	var venue_id := str(result.get("environment_archetype_id", _run.current_environment.get("archetype_id", "")))
	_crew_heist_record_settled_game(game_id, venue_id, result, deltas)
	for job_id_value in crew_jobs.keys():
		var job_id := str(job_id_value)
		var job := _crew_job(job_id)
		if str(job.get("status", "")) != "active" or str(job.get("kind", "")) != "stake_horse":
			continue
		var payload := JsonCoerceScript._copy_dict(job.get("payload", {}))
		if str(payload.get("game_id", "")) != game_id or str(payload.get("venue_id", "")) != venue_id:
			continue
		payload["session_net"] = int(payload.get("session_net", 0)) + int(deltas.get("bankroll_delta", 0))
		job["payload"] = payload
		crew_jobs[job_id] = job
		if int(payload.get("session_net", 0)) >= int(payload.get("profit_target", 1)):
			return _run.job_resolve(job_id, "success", _crew_job_host_capability)
		if int(payload.get("session_net", 0)) <= -int(payload.get("crew_stake", 1)):
			payload["loss_choice_pending"] = true
			job["payload"] = payload
			crew_jobs[job_id] = job
			_crew_add_room_event("crew_stake_horse_loss")
		return _crew_job_public_projection(job)
	return {}


func _crew_heist_record_settled_game(game_id: String, venue_id: String, result: Dictionary, deltas: Dictionary) -> void:
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	if state.is_empty():
		return
	var phase := str(state.get("status", ""))
	var plan_id := str(state.get("plan_id", ""))
	var settled := _crew_heist_game_result_is_settled(game_id, result)
	if plan_id == _run.CrewHeistModelScript.PLAN_WHALE and phase == _run.CrewHeistModelScript.STATUS_PLAY and venue_id == str(JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.plan(_run.CrewHeistModelScript.PLAN_WHALE).get("play", {})).get("venue_archetype", _run.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID)):
		if not settled:
			_crew_heist_record_whale_pending_fact(game_id, _crew_heist_whale_result_facts(game_id, result))
			return
	if not settled:
		return
	var net := int(deltas.get("chips_delta", 0)) if str(result.get("currency", "")) == "chips" else int(deltas.get("bankroll_delta", 0))
	if phase == _run.CrewHeistModelScript.STATUS_SETUP:
		if plan_id == _run.CrewHeistModelScript.PLAN_COUNT and venue_id in _run.GRAND_CASINO_ARCHETYPE_IDS:
			var session_id := str(result.get("session_id", "%s:%s" % [_run._event_cadence_visit_key(_run.current_environment), game_id]))
			crew_heist_record_count_session(int(result.get("bet", result.get("wager", result.get("stake", 0)))), int(result.get("heat_start", _run.suspicion_level())), int(result.get("heat_peak", _run.suspicion_level())), bool(result.get("ok", true)), session_id, _crew_heist_host_capability)
		elif plan_id == _run.CrewHeistModelScript.PLAN_WHALE and bool(_run.narrative_flags.get("heist_plan_b_whale_vouch", false)) and net < 0 and _crew_heist_whale_vouch_table_active(venue_id):
			_crew_heist_sync_whale_setup()
			crew_heist_record_whale_vouch(net, true, _crew_heist_host_capability)
		return
	if phase != _run.CrewHeistModelScript.STATUS_PLAY:
		return
	if plan_id == _run.CrewHeistModelScript.PLAN_COUNT and venue_id in _run.GRAND_CASINO_ARCHETYPE_IDS:
		crew_heist_play_round({"game_id": game_id, "bet": int(result.get("bet", result.get("wager", result.get("stake", 0)))), "heat_delta": int(result.get("heat_delta", deltas.get("suspicion_delta", 0)))}, _crew_heist_host_capability)
	elif plan_id == _run.CrewHeistModelScript.PLAN_WHALE and venue_id == str(JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.plan(_run.CrewHeistModelScript.PLAN_WHALE).get("play", {})).get("venue_archetype", _run.GRAND_CASINO_HIGH_LIMIT_ARCHETYPE_ID)) and game_id in ["craps", "blackjack", "baccarat", "poker", "video_poker"]:
		var whale_facts := _crew_heist_whale_result_facts(game_id, result)
		state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
		var play := JsonCoerceScript._copy_dict(state.get("play", {}))
		var pending_by_game := JsonCoerceScript._copy_dict(play.get("pending_game_facts", {}))
		var pending := JsonCoerceScript._copy_dict(pending_by_game.get(game_id, {}))
		var expected_game_id := _crew_heist_whale_expected_game(state)
		if game_id == expected_game_id:
			pending_by_game.erase(game_id)
			play["pending_game_facts"] = pending_by_game
			state["play"] = play
			crew_heist_state = state
		var honest := bool(whale_facts.get("honest", true)) and not bool(pending.get("dishonest", false))
		var made_now := bool(whale_facts.get("made", false)) and not bool(play.get("made", false))
		crew_heist_play_round({"game_id": game_id, "honest": honest, "made": made_now, "pot_delta": net}, _crew_heist_host_capability)


func _crew_heist_whale_vouch_table_active(venue_id: String) -> bool:
	if venue_id.is_empty() or venue_id != str(_run.current_environment.get("archetype_id", "")):
		return false
	var hooks := JsonCoerceScript._copy_dict(_run.current_environment.get("scenario_hook_flags", {}))
	var event_ids := JsonCoerceScript._copy_array(_run.current_environment.get("event_ids", []))
	return bool(hooks.get("whale_vouch_anchor", false)) or (bool(hooks.get("heist_plan_b_criteria", false)) and event_ids.has("scenario_whale_aboard_vouch"))


func _crew_heist_whale_expected_game(state: Dictionary) -> String:
	var sequence := JsonCoerceScript._copy_array(JsonCoerceScript._copy_dict(_run.CrewHeistModelScript.plan(_run.CrewHeistModelScript.PLAN_WHALE).get("play", {})).get("game_sequence", []))
	var round_index := int(JsonCoerceScript._copy_dict(state.get("play", {})).get("round", 0))
	return str(sequence[round_index]) if round_index >= 0 and round_index < sequence.size() else ""


func _crew_heist_record_whale_pending_fact(game_id: String, facts: Dictionary) -> void:
	if bool(facts.get("honest", true)) and not bool(facts.get("made", false)):
		return
	var state = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	var play := JsonCoerceScript._copy_dict(state.get("play", {}))
	var pending_by_game := JsonCoerceScript._copy_dict(play.get("pending_game_facts", {}))
	var pending := JsonCoerceScript._copy_dict(pending_by_game.get(game_id, {}))
	pending["dishonest"] = bool(pending.get("dishonest", false)) or not bool(facts.get("honest", true))
	pending["made"] = bool(pending.get("made", false)) or bool(facts.get("made", false))
	if bool(facts.get("made", false)) and not bool(play.get("made", false)):
		play["made"] = true
		play["score"] = maxi(0, int(play.get("score", 100)) - 25)
		pending["made_penalty_applied"] = true
	pending_by_game[game_id] = pending
	play["pending_game_facts"] = pending_by_game
	state["play"] = play
	crew_heist_state = state


func _crew_heist_whale_result_facts(game_id: String, result: Dictionary) -> Dictionary:
	var action_kind := str(result.get("action_kind", "")).to_lower()
	var cheat_used := action_kind in ["cheat", "risky", "advantage"]
	var made := false
	match game_id:
		"blackjack":
			cheat_used = cheat_used or bool(result.get("player_cheat_used", false))
			made = bool(result.get("blackjack_cheat_caught", false)) or bool(result.get("dealer_caught_cheat", false))
		"baccarat":
			cheat_used = cheat_used or bool(result.get("baccarat_edge_sort_edge_used", false)) or bool(result.get("baccarat_edge_sort", false))
	var skill_outcome := str(result.get("skill_outcome", "")).to_lower()
	var skill_grade := str(result.get("skill_grade", "")).to_lower()
	made = made or skill_outcome.find("caught") >= 0 or skill_outcome.find("blown") >= 0 or skill_grade == "blown"
	return {"honest": not cheat_used, "made": made}


func _crew_heist_game_result_is_settled(game_id: String, result: Dictionary) -> bool:
	if not bool(result.get("ok", false)):
		return false
	if result.has("settled"):
		return bool(result.get("settled", false))
	match game_id:
		"blackjack":
			return not JsonCoerceScript._copy_array(result.get("blackjack_hand_results", [])).is_empty()
		"roulette":
			return not str(result.get("roulette_spin_id", "")).is_empty()
		"baccarat":
			return not str(result.get("baccarat_winner", "")).is_empty() and not JsonCoerceScript._copy_dict(result.get("baccarat_hand", {})).is_empty()
		"craps":
			return not JsonCoerceScript._copy_dict(result.get("craps_roll", {})).is_empty() and not JsonCoerceScript._copy_array(result.get("craps_bet_results", [])).is_empty()
		"video_poker":
			return str(result.get("action_id", "")) == "draw" and not JsonCoerceScript._copy_array(result.get("video_poker_hand_results", [])).is_empty()
	return false


func crew_stake_horse_loss_choices() -> Array:
	var pending = _run._pending_crew_job("stake_horse", "loss_choice_pending")
	if pending.is_empty():
		return []
	return [
		{"id": "repay", "label": "Repay the stake", "text": "Make the crew whole. The loss still costs trust.", "consequences": {"event_hooks": [{"type": "crew_stake_loss_choice", "choice": "repay"}], "resolve_event": true}},
		{"id": "shrug", "label": "Shrug it off", "text": "Call it the cost of doing business.", "consequences": {"event_hooks": [{"type": "crew_stake_loss_choice", "choice": "shrug"}], "resolve_event": true}},
	]


func crew_resolve_stake_horse_loss(choice_id: String) -> Dictionary:
	var pending = _run._pending_crew_job("stake_horse", "loss_choice_pending")
	if pending.is_empty() or not ["repay", "shrug"].has(choice_id):
		return {"ok": false}
	var job_id := str(pending.get("id", ""))
	var payload := JsonCoerceScript._copy_dict(pending.get("payload", {}))
	if choice_id == "repay":
		_run.change_bankroll(-mini(_run.bankroll, maxi(1, int(payload.get("crew_stake", 1)))), true)
	var resolved = _run.job_resolve(job_id, "failed", _crew_job_host_capability)
	if choice_id == "shrug":
		_run.grievance_add({"member_id": str(pending.get("member_id", "")), "kind": "stake_horse_loss_shrugged", "weight": 1, "source_ref": job_id})
	return {"ok": not resolved.is_empty(), "choice": choice_id, "job": resolved}


func crew_collection_choices() -> Array:
	var pending = _run._pending_crew_job("collection", "press_choice_pending")
	if pending.is_empty():
		return []
	return [
		{"id": "friendly", "label": "Keep the friendly face", "text": "Take the smaller envelope and leave the room intact.", "consequences": {"event_hooks": [{"type": "crew_collection_choice", "choice": "friendly"}], "resolve_event": true}},
		{"id": "press", "label": "Press harder", "text": "Take more cash and let the town remember the pressure.", "consequences": {"event_hooks": [{"type": "crew_collection_choice", "choice": "press"}], "resolve_event": true}},
	]


func crew_resolve_collection(choice_id: String) -> Dictionary:
	var pending = _run._pending_crew_job("collection", "press_choice_pending")
	if pending.is_empty() or not ["friendly", "press"].has(choice_id):
		return {"ok": false}
	var payload := JsonCoerceScript._copy_dict(pending.get("payload", {}))
	var cash := int(payload.get("friendly_cash", 0)) if choice_id == "friendly" else int(payload.get("press_cash", 0))
	var heat := int(payload.get("friendly_heat", 0)) if choice_id == "friendly" else int(payload.get("press_heat", 0))
	if cash > 0:
		_run.change_bankroll(cash, true)
	if heat > 0:
		_run.add_suspicion("crew_collection_press", heat, "behavior", false, {}, true)
	var resolved = _run.job_resolve(str(pending.get("id", "")), "success", _crew_job_host_capability)
	return {"ok": not resolved.is_empty(), "choice": choice_id, "cash": cash, "heat": heat, "job": resolved}


func _crew_add_room_event(event_id: String) -> void:
	var ids := JsonCoerceScript._copy_array(_run.current_environment.get("event_ids", []))
	if not ids.has(event_id):
		ids.append(event_id)
	_run.current_environment["event_ids"] = ids
	_run.store_current_world_node_environment()


func _crew_favor_delivery_is_active() -> bool:
	return _run.delivery_has_active_run() and (
		str(_run.active_delivery_run.get("run_id", "")) == "crew_favor_delivery"
		or str(_run.active_delivery_run.get("source_event_id", "")) == "crew_favor_delivery"
	)


func crew_capability_active(capability_id: String) -> bool:
	var clean_id := capability_id.strip_edges().to_lower()
	if clean_id == "sweep_intel" and crew_rank_perks("crew_switch").has("sweep_intel"):
		return true
	return not clean_id.is_empty() and bool(_run.narrative_flags.get("crew_capability:%s" % clean_id, false))


func _crew_lender_repeat_status(current_location_id: String) -> Dictionary:
	var status := {
		"available": true,
		"disabled_reason": "",
		"active_debt": false,
		"availability_class": _run.AVAILABILITY_AVAILABLE,
	}
	var location_lookup := {}
	var open_locations := 0
	for debt_entry in _run.debt:
		if typeof(debt_entry) != TYPE_DICTIONARY:
			continue
		var debt_data := debt_entry as Dictionary
		if str(debt_data.get("lender_id", "")) != _run.CREW_LENDER_ID:
			continue
		var debt_status := str(debt_data.get("status", "active"))
		if debt_status != "active" and debt_status != "overdue" and debt_status != "favor_due":
			continue
		for location_value in JsonCoerceScript._copy_array(debt_data.get("source_location_ids", [])):
			var location_id := str(location_value)
			if location_id.is_empty() or location_lookup.has(location_id):
				continue
			location_lookup[location_id] = true
			open_locations += 1
		var single_location_id := str(debt_data.get("source_location_id", ""))
		if not single_location_id.is_empty() and not location_lookup.has(single_location_id):
			location_lookup[single_location_id] = true
			open_locations += 1
	if not current_location_id.is_empty() and location_lookup.has(current_location_id):
		status["available"] = false
		status["disabled_reason"] = "The Crew already marked this location."
		status["active_debt"] = true
		status["availability_class"] = _run.AVAILABILITY_TRANSIENT_BLOCKED
		return status
	if open_locations >= _run.CREW_MAX_LOAN_LOCATIONS:
		status["available"] = false
		status["disabled_reason"] = "The Crew will not open more than three markers."
		status["active_debt"] = true
		status["availability_class"] = _run.AVAILABILITY_TRANSIENT_BLOCKED
	return status


func _crew_debt_lead_member(debt_data: Dictionary) -> String:
	for member_value in JsonCoerceScript._copy_array(debt_data.get("crew_member_ids", [])):
		var member_id := str(member_value)
		if CrewStateModelScript.MEMBER_IDS.has(member_id):
			return member_id
	return "crew_rook"


func _crew_job(job_id: String) -> Dictionary:
	var value: Variant = crew_jobs.get(job_id, {})
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func _crew_action_index() -> int:
	return maxi(0, int(_run.event_cadence.get("action_index", 0)))


func _crew_pack_ledger() -> Array:
	if crew_grievance_ledger.size() > CrewTurnModelScript.PRIVATE_GRIEVANCE_LIMIT:
		return []
	var result: Array = []
	for entry_value in crew_grievance_ledger:
		var entry := JsonCoerceScript._copy_dict(entry_value)
		var member_index := CrewStateModelScript.MEMBER_IDS.find(str(entry.get("member_id", "")))
		var kind_index := CrewStateModelScript.GRIEVANCE_KINDS.find(str(entry.get("kind", "")))
		var entry_id := str(entry.get("id", ""))
		var source_ref := str(entry.get("source_ref", ""))
		var weight := int(entry.get("weight", 1))
		var turn_recorded := int(entry.get("turn_recorded", 0))
		if member_index < 0 or kind_index < 0 or entry_id.is_empty() \
				or entry_id.to_utf8_buffer().size() > CrewTurnModelScript.PRIVATE_TEXT_BYTE_LIMIT \
				or source_ref.to_utf8_buffer().size() > CrewTurnModelScript.PRIVATE_TEXT_BYTE_LIMIT \
				or weight < 1 or weight > CrewTurnModelScript.PRIVATE_SEQUENCE_LIMIT \
				or turn_recorded < 0 or turn_recorded > CrewTurnModelScript.PRIVATE_SEQUENCE_LIMIT:
			return []
		result.append([member_index, kind_index, weight, turn_recorded, entry_id.to_utf8_buffer().hex_encode(), source_ref.to_utf8_buffer().hex_encode()])
	return result


func _crew_unpack_ledger(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var source: Array = value
	# Backward-compatible reader for pre-crew06_9 saves.
	if not source.is_empty() and typeof(source[0]) == TYPE_DICTIONARY:
		return CrewStateModelScript.normalize_grievances(source)
	var decoded: Array = []
	for index in range(source.size()):
		if typeof(source[index]) != TYPE_ARRAY:
			continue
		var row: Array = source[index]
		if row.size() < 4:
			continue
		var member_index := int(row[0])
		var kind_index := int(row[1])
		if member_index < 0 or member_index >= CrewStateModelScript.MEMBER_IDS.size() or kind_index < 0 or kind_index >= CrewStateModelScript.GRIEVANCE_KINDS.size():
			continue
		var entry_id := str(row[4]).hex_decode().get_string_from_utf8() if row.size() > 4 else "g%04d" % (index + 1)
		var source_ref := str(row[5]).hex_decode().get_string_from_utf8() if row.size() > 5 else ""
		decoded.append({"id": entry_id, "member_id": CrewStateModelScript.MEMBER_IDS[member_index], "kind": CrewStateModelScript.GRIEVANCE_KINDS[kind_index], "weight": maxi(1, int(row[2])), "turn_recorded": maxi(0, int(row[3])), "source_ref": source_ref})
	return decoded


func _crew_jobs_for_save(deep_copy: bool) -> Dictionary:
	var result := crew_jobs.duplicate(deep_copy)
	for job_id in result.keys():
		result[job_id] = _crew_job_public_projection(JsonCoerceScript._copy_dict(result.get(job_id, {})))
	return result


func _crew_jobs_from_save(value: Variant) -> Dictionary:
	var result: Dictionary = (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}
	for job_id in result.keys():
		var job := JsonCoerceScript._copy_dict(result.get(job_id, {}))
		var failure := JsonCoerceScript._copy_dict(job.get("failure", {}))
		# Legacy packed failure readers remain supported, but new public saves do
		# not duplicate grievance authority outside the private capsule.
		var packed := JsonCoerceScript._copy_array(failure.get("g", []))
		if packed.size() >= 2:
			var kind_index := int(packed[0])
			failure["grievance_kind"] = CrewStateModelScript.GRIEVANCE_KINDS[kind_index] if kind_index >= 0 and kind_index < CrewStateModelScript.GRIEVANCE_KINDS.size() else ""
			failure["grievance_weight"] = maxi(1, int(packed[1]))
			failure.erase("g")
		else:
			var definition := CrewStateModelScript.job_definition(str(job.get("definition_id", "")))
			var authored_failure := JsonCoerceScript._copy_dict(definition.get("failure", {}))
			failure["grievance_kind"] = str(authored_failure.get("grievance_kind", ""))
			failure["grievance_weight"] = maxi(1, int(authored_failure.get("grievance_weight", 1)))
		job["failure"] = failure
		result[job_id] = job
	return result


func _crew_job_public_projection(job_value: Dictionary) -> Dictionary:
	var job := job_value.duplicate(true)
	var failure := JsonCoerceScript._copy_dict(job.get("failure", {}))
	failure.erase("grievance_kind")
	failure.erase("grievance_weight")
	failure.erase("g")
	job["failure"] = failure
	return job


func _crew_state_for_save(deep_copy: bool, _opaque_hidden: bool = true) -> Dictionary:
	var result := {
		"schema_version": CrewStateModelScript.STATE_SCHEMA_VERSION,
		"trust": crew_trust_by_member.duplicate(deep_copy),
		"jobs": _crew_jobs_for_save(deep_copy),
		"job_sequence": crew_job_sequence,
		# Neutral keys keep the hidden learning model opaque in raw saves.
		"p": _run.CrewPokerModelScript.pack_observations(crew_pattern_memory),
		"m": crew_match_marks.duplicate(deep_copy),
	}
	# Keep a crew-ignoring save byte-identical to the crew06_1 projection. The
	# optional field carries its own addition version only after the stash is used.
	if not crew_contraband_stash.is_empty():
		result["recruitment_schema_version"] = _run.CrewRecruitmentModelScript.SCHEMA_VERSION
		result["stash"] = crew_contraband_stash.duplicate(deep_copy)
	var recruitment_encounters := _crew_recruitment_encounters_for_save()
	if not recruitment_encounters.is_empty() and (not JsonCoerceScript._copy_dict(recruitment_encounters.get("meetings", {})).is_empty() or not JsonCoerceScript._copy_dict(recruitment_encounters.get("contacts", {})).is_empty()):
		result["recruitment_schema_version"] = _run.CrewRecruitmentModelScript.SCHEMA_VERSION
		result["encounters"] = recruitment_encounters.duplicate(deep_copy)
	var normalized_plays = _run.CrewPlayModelScript.normalize_state(crew_play_state)
	if not (normalized_plays.get("uses", {}) as Dictionary).is_empty() \
			or not (normalized_plays.get("active", []) as Array).is_empty() \
			or not (normalized_plays.get("member_cooldowns", {}) as Dictionary).is_empty() \
			or not (normalized_plays.get("tombstones", []) as Array).is_empty():
		result["plays"] = _crew_plays_for_save(normalized_plays, deep_copy)
	var normalized_heist = _run.CrewHeistModelScript.normalize_state(crew_heist_state)
	var private_heist := CrewTurnModelScript.empty_state()
	if not normalized_heist.is_empty():
		private_heist = JsonCoerceScript._copy_dict(normalized_heist.get("x", CrewTurnModelScript.empty_state()))
		normalized_heist.erase("x")
		result["crew_heist_schema_version"] = _run.CrewHeistModelScript.SCHEMA_VERSION
		result["crew_heist"] = normalized_heist.duplicate(deep_copy)
	# Every save carries the same fixed-size private authority envelope, including
	# a pristine zero-grievance run. Omitting it (or writing public empty
	# sentinels) made zero versus one grievance distinguishable by keys and size.
	# `_opaque_hidden` remains in the signature for old callers only.
	var _legacy_projection_ignored := _opaque_hidden
	var packed_ledger := _crew_pack_ledger()
	if packed_ledger.size() != crew_grievance_ledger.size() or crew_grievance_sequence < packed_ledger.size() \
			or crew_grievance_sequence > CrewTurnModelScript.PRIVATE_SEQUENCE_LIMIT:
		result["private_authority_error"] = "private_authority_capacity_exceeded"
		return result
	if not CrewTurnModelScript.valid_authority_id(_crew_private_authority_id):
		result["private_authority_error"] = "private_authority_unavailable"
		return result
	var payload := {"x": private_heist, "g": packed_ledger, "q": crew_grievance_sequence}
	var binding := _crew_private_save_binding(_crew_private_authority_id, normalized_heist)
	var fingerprint := CrewTurnModelScript.private_save_fingerprint(payload, CrewStateModelScript.MEMBER_IDS, CrewStateModelScript.GRIEVANCE_KINDS, binding)
	if binding.is_empty() or fingerprint.is_empty():
		result["private_authority_error"] = "private_authority_capacity_exceeded"
		return result
	if _crew_heist_private_capsule.is_empty() or _crew_heist_private_fingerprint != fingerprint:
		_crew_heist_private_capsule = CrewTurnModelScript.pack_private_save(payload, CrewStateModelScript.MEMBER_IDS, CrewStateModelScript.GRIEVANCE_KINDS, binding)
		_crew_heist_private_fingerprint = fingerprint if not _crew_heist_private_capsule.is_empty() else ""
	if _crew_heist_private_capsule.is_empty():
		result["private_authority_error"] = "private_authority_unavailable"
		return result
	result["a"] = _crew_private_authority_id
	result["z"] = _crew_heist_private_capsule
	return result


func _crew_private_save_binding(authority_id: String, public_heist: Dictionary) -> String:
	return CrewTurnModelScript.private_save_binding(authority_id, _run.seed_text, {
		"challenge_config": _run.challenge_config.duplicate(true),
		"member_ids": CrewStateModelScript.MEMBER_IDS.duplicate(),
		"trust": CrewStateModelScript.normalize_trust(crew_trust_by_member),
		"jobs": _crew_jobs_for_save(true),
		"heist": public_heist.duplicate(true),
	})


func _crew_plays_for_save(normalized_plays: Dictionary, deep_copy: bool) -> Dictionary:
	var result := normalized_plays.duplicate(deep_copy)
	var liability := JsonCoerceScript._copy_dict(result.get("distraction_liability", {}))
	if not liability.is_empty():
		# The source is a hidden-ledger join key. It is reconstructed from the
		# already-public play sequence after authentication, never serialized.
		liability["source_ref"] = ""
		result["distraction_liability"] = liability
	return result


func _crew_recruitment_encounters_for_save() -> Dictionary:
	var result = _run.CrewRecruitmentModelScript.normalize_encounter_state(crew_recruitment_encounters)
	var contacts := JsonCoerceScript._copy_dict(result.get("contacts", {}))
	for member_id in contacts.keys():
		var contact := JsonCoerceScript._copy_dict(contacts.get(member_id, {}))
		# `aggrieved` was a legacy public classifier derived from the private
		# ledger. Preserve the durable meeting/contact receipt but project a
		# neutral state based only on public standing and active-job facts.
		if str(contact.get("contact_state", "")) == "aggrieved":
			var standing := str(contact.get("standing", ""))
			var job_out := false
			for job_value in crew_jobs.values():
				var job := JsonCoerceScript._copy_dict(job_value)
				if str(job.get("member_id", "")) == str(member_id) and str(job.get("status", "")) in ["offered", "accepted", "active"]:
					job_out = true
					break
			contact["contact_state"] = "job_out" if job_out else ("trusted" if standing in ["made", "inner_circle"] else "familiar")
		contacts[member_id] = contact
	result["contacts"] = contacts
	return result


func _crew_plays_from_save(value: Variant) -> Dictionary:
	var result = _run.CrewPlayModelScript.restore_state(value)
	return result


func _crew_distraction_grievance_source(liability: Dictionary) -> String:
	return CrewTurnModelScript.private_reference("crew_play", CrewTurnModelScript.canonical_json({
		"seed": _run.seed_text,
		"member_id": str(liability.get("member_id", "")),
		"until_action": maxi(0, int(liability.get("until_action", 0))),
	}))


func _crew_private_restore_failed(saved_heist: Dictionary) -> Dictionary:
	crew_grievance_ledger = []
	crew_grievance_sequence = 0
	_crew_private_authority_id = ""
	_crew_heist_private_capsule = ""
	_crew_heist_private_fingerprint = ""
	_run.narrative_flags["crew_private_authority_error"] = "private_authority_unavailable"
	# Preserve an active heist as an explicit terminal result. A missing capsule
	# must never become a fresh attempt with erased hidden consequences.
	if not saved_heist.is_empty():
		saved_heist["x"] = CrewTurnModelScript.empty_state()
		saved_heist["status"] = _run.CrewHeistModelScript.STATUS_ABORTED
		saved_heist["abort"] = {"reason": "private_authority_unavailable", "cost": 0, "action": _crew_action_index()}
		_run.narrative_flags["crew_heist_private_restore_error"] = "private_authority_unavailable"
	return saved_heist
