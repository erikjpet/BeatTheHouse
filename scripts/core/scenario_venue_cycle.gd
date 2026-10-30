class_name ScenarioVenueCycle
extends RefCounted

const Json := preload("res://scripts/core/json_coerce.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const RuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const InstanceScript := preload("res://scripts/core/environment_instance.gd")

static func cycle_for_existing_room(environment: Dictionary, archetype: Dictionary, now: int) -> Dictionary:
	var stamp := str(environment.get("environment_situation_cycle_id", ""))
	if stamp.begins_with("venue:v1:"):
		var opened := int(stamp.trim_prefix("venue:v1:"))
		return EnvironmentHours.scenario_cycle_status(archetype, maxi(0, opened)) if opened >= 0 else EnvironmentHours.scenario_cycle_status(archetype, 0)
	# Legacy saves retain their accepted room when no close has elapsed since its
	# recorded entry. Unknown entry history is adopted once, never fabricated.
	return EnvironmentHours.scenario_cycle_status(archetype, int(environment.get("entered_game_clock_minutes", now)))


static func retirement_record(environment: Dictionary, definition: Dictionary, cycle: Dictionary, observed_at: int) -> Dictionary:
	var state := Json._copy_dict(environment.get("scenario_sequence_state", {}))
	var cleanup: Dictionary = {}
	if not state.is_empty():
		cleanup = RuntimeScript.prepare_venue_cycle_retirement(state, definition, str(cycle.get("cycle_id", "")))
		if not bool(cleanup.get("ok", false)): return cleanup
	var durable := InstanceScript._durable_sequence_state(state)
	var legacy := ScenarioEngineScript.normalize_state(environment.get("scenario_state", {}))
	return {"ok": true, "record": {"schema": "bth.venue_scenario_retirement/v1",
		"cycle_id": str(cycle.get("cycle_id", "")), "closed_at": int(cycle.get("closes_at", observed_at)),
		"observed_at": observed_at, "scenario_id": str(legacy.get("id", environment.get("scenario_id", ""))),
		"layer_id": str(environment.get("current_layer_id", "room")), "scenario_state": legacy,
		"sequence_state": durable, "source_fingerprint": RuntimeScript.content_fingerprint(durable),
		"resolved_event_ids": Json._copy_array(environment.get("resolved_event_ids", [])),
		"cleanup_receipts": cleanup.get("cleanup_receipts", []), "cleanup_fingerprint": cleanup.get("cleanup_fingerprint", ""),
		"retired_objectives": cleanup.get("retired_objectives", {}), "resolved_outcomes": state.get("resolved_outcomes", []),
		"retired_status": str(state.get("status", "legacy")),
		"unfinished_policy": Json._copy_dict(Json._copy_dict(definition.get("sequence", {})).get("expiry", {}))}}


static func base_profiles(environment: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in ["economic_profile", "music_profile", "security_profile", "visual_context", "travel_locked_actions", "travel_lock_remaining"]:
		var value: Variant = environment.get(key)
		result[key] = value.duplicate(true) if typeof(value) in [TYPE_ARRAY, TYPE_DICTIONARY] else value
	return result


# Remove only the retiring scenario's declared material. Paid machine state,
# event resolutions, merchant stock consumption and unrelated runtime owners
# remain live; a new situation is not a new physical casino or another visit.
static func clear_scenario(environment: Dictionary, archetype: Dictionary, prior_profiles: Dictionary = {}) -> Dictionary:
	var result := environment.duplicate(true)
	var old := ScenarioEngineScript.normalize_state(result.get("scenario_state", {}))
	var mutations: Array = [Json._copy_dict(old.get("mutations", {}))]
	for phase in Json._copy_array(old.get("phases", [])):
		mutations.append(Json._copy_dict(Json._copy_dict(phase).get("mutations", {})))
	ScenarioEngineScript.deactivate_environment_sequence_projection(result)
	for mutation_value in mutations:
		var mutation := Json._copy_dict(mutation_value)
		for mapping in [["event_pool_add", "event_ids", "event_pool"], ["service_add", "service_ids", "service_pool"]]:
			var ids := Json._raw_string_array(result.get(mapping[1], []))
			var ordinary := Json._raw_string_array(archetype.get(mapping[2], []))
			var added := Json._raw_string_array(mutation.get(mapping[0], []))
			if mapping[1] == "event_ids":
				var exclusive_id := str(Json._copy_dict(mutation.get("exclusive_opportunity", {})).get("event_id", ""))
				if not exclusive_id.is_empty() and not added.has(exclusive_id): added.append(exclusive_id)
			for id in added:
				if ordinary.has(id): continue
				ids.erase(id)
				if mapping[1] == "event_ids":
					# The new immutable host must not resurrect a retired event from
					# the previous cycle's resolved-event fallback. Its history is in
					# the retirement record; unrelated/base resolutions remain live.
					var resolved := Json._raw_string_array(result.get("resolved_event_ids", []))
					resolved.erase(id); result["resolved_event_ids"] = resolved
			result[mapping[1]] = ids
		for mapping in [["economic_profile_overrides", "economic_profile"], ["music_profile_override", "music_profile"], ["security_overrides", "security_profile"], ["presentation", "visual_context"]]:
			if mutation.has(mapping[0]):
				var baseline := Json._copy_dict(prior_profiles.get(mapping[1], archetype.get(mapping[1], {})))
				result[mapping[1]] = _restore_owned_keys(Json._copy_dict(result.get(mapping[1], {})), baseline, Json._copy_dict(mutation.get(mapping[0], {})))
		if mutation.has("travel_lock_actions"):
			for key in ["travel_locked_actions", "travel_lock_remaining"]:
				result[key] = int(prior_profiles.get(key, archetype.get("travel_locked_actions", 0)))
		var offers := Json._copy_array(result.get("item_offers", []))
		for offer in Json._copy_array(mutation.get("item_offer_add", [])):
			var id := str(Json._copy_dict(offer).get("id", ""))
			for i in range(offers.size() - 1, -1, -1):
				if str(Json._copy_dict(offers[i]).get("id", "")) == id: offers.remove_at(i)
		result["item_offers"] = offers
	for key in result.keys():
		if str(key).begins_with("scenario_"): result.erase(key)
	return result


static func attach(environment: Dictionary, definition: Dictionary, archetype: Dictionary = {}) -> void:
	if definition.is_empty(): return
	var state := ScenarioEngineScript.initial_state(definition)
	if ScenarioEngineScript.state_targets_environment(state, environment):
		# Base/None generation intentionally omits expanded semantic context. A
		# newly installed cycle needs the same authored inputs as fresh generation;
		# carrying the old empty context makes valid scene anchors unavailable.
		if not archetype.is_empty():
			environment["semantic_anchors"] = Json._copy_dict(archetype.get("semantic_anchors", {}))
			environment["semantic_actors"] = Json._copy_array(archetype.get("semantic_actors", []))
			environment["semantic_zones"] = Json._copy_dict(archetype.get("semantic_zones", {}))
		ScenarioEngineScript._apply_mutations(environment, Json._copy_dict(state.get("mutations", {})), false)
		environment["scenario_applied_phase_index"] = -1
		ScenarioEngineScript.reconcile_environment(environment, state)
	ScenarioEngineScript.attach_to_environment(environment, state, definition)


static func _restore_owned_keys(current: Dictionary, baseline: Dictionary, owned: Dictionary) -> Dictionary:
	var result := current.duplicate(true)
	for key in owned:
		if typeof(owned[key]) == TYPE_DICTIONARY and typeof(result.get(key)) == TYPE_DICTIONARY:
			result[key] = _restore_owned_keys(result[key], Json._copy_dict(baseline.get(key, {})), owned[key])
		elif baseline.has(key): result[key] = baseline[key]
		else: result.erase(key)
	return result
