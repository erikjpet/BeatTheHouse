class_name CrewRecruitmentModel
extends RefCounted

# Deterministic, data-backed placement and presence rules for the seven Crew
# members. The model never advances run RNG and only mutates rooms at generation
# or revisit boundaries through apply_to_environment().

const CONFIG_PATH := "res://data/crew/recruitment.json"
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const SCHEMA_VERSION := 1
const RANKS := ["stranger", "marker", "associate", "made", "inner_circle"]
const MEMBER_IDS := [
	"crew_rook", "crew_switch", "crew_mags", "crew_knuckles",
	"crew_velvet", "crew_bishop", "crew_lucky",
]
const GRAND_CASINO_ROOM_IDS := ["grand_casino", "grand_casino_cage", "grand_casino_high_limit"]

static var _config_cache: Dictionary = {}


static func config() -> Dictionary:
	if _config_cache.is_empty():
		var rows := _load_array(CONFIG_PATH)
		if rows.size() == 1 and typeof(rows[0]) == TYPE_DICTIONARY:
			_config_cache = (rows[0] as Dictionary).duplicate(true)
	return _config_cache.duplicate(true)


static func member_definition(member_id: String) -> Dictionary:
	for value in _array(config().get("members", [])):
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("member_id", "")) == member_id:
			return (value as Dictionary).duplicate(true)
	return {}


static func recruitment_event_ids() -> Array:
	var result: Array = []
	for value in _array(config().get("members", [])):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var event_id := str((value as Dictionary).get("event_id", "")).strip_edges()
		if not event_id.is_empty():
			result.append(event_id)
	return result


static func contact_event_ids() -> Array:
	var result: Array = []
	for value in _array(config().get("members", [])):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var event_id := str((value as Dictionary).get("contact_event_id", "")).strip_edges()
		if not event_id.is_empty():
			result.append(event_id)
	return result


static func apply_to_environment(run_state: RunState, environment: Dictionary) -> void:
	if run_state == null or environment.is_empty() or not crew_path_started(run_state):
		return
	var event_ids := _string_array(environment.get("event_ids", []))
	# Rook's contextual leads follow his seeded presence. Remove the derived
	# event before recomputing so a revisit never leaves his voice in an empty
	# room after his itinerary rotates.
	event_ids.erase("recruitment_rook_leads")
	for contact_event_id in contact_event_ids():
		event_ids.erase(contact_event_id)
	for member_id in MEMBER_IDS:
		if member_id == "crew_rook" or _rank_at_least(run_state.crew_rank(member_id), "associate"):
			continue
		var definition := member_definition(member_id)
		if placement_kind(run_state, environment, definition).is_empty():
			continue
		var event_id := str(definition.get("event_id", "")).strip_edges()
		if not event_id.is_empty() and not event_ids.has(event_id):
			event_ids.append(event_id)
	environment["event_ids"] = event_ids
	var patrons := _string_array(environment.get("scenario_patron_ids", []))
	for member_id in MEMBER_IDS:
		patrons.erase(member_id)
	var presence := presence_for_environment(run_state, environment)
	if presence.is_empty():
		environment.erase("crew_presence")
		environment["event_ids"] = event_ids
		environment["scenario_patron_ids"] = patrons
		return
	environment["crew_presence"] = presence
	for entry_value in presence:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var member_id := str(entry.get("member_id", ""))
		if not member_id.is_empty() and not patrons.has(member_id):
			patrons.append(member_id)
		var contact_event_id := str(member_definition(member_id).get("contact_event_id", "")).strip_edges()
		if not contact_event_id.is_empty() and _rank_at_least(run_state.crew_rank(member_id), "associate"):
			entry["contact_event_id"] = contact_event_id
			if not contact_choices(run_state, environment, member_id).is_empty() and not event_ids.has(contact_event_id):
				event_ids.append(contact_event_id)
	environment["scenario_patron_ids"] = patrons
	for entry_value in presence:
		if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("member_id", "")) == "crew_rook" \
			and not rook_signpost_choices(run_state).is_empty():
			event_ids.append("recruitment_rook_leads")
			break
	environment["event_ids"] = event_ids


static func crew_path_started(run_state: RunState) -> bool:
	if run_state == null:
		return false
	return _rank_at_least(str(run_state.crew_standing().get("rank", "stranger")), "marker")


static func placement_kind(run_state: RunState, environment: Dictionary, definition: Dictionary) -> String:
	if definition.is_empty() or str(definition.get("member_id", "")) == "crew_rook":
		return ""
	var primary := _dict(definition.get("primary", {}))
	if _location_matches(primary, environment):
		return "primary"
	var fallback := _dict(definition.get("fallback", {}))
	if fallback.is_empty() or not _fallback_system_live(run_state, fallback):
		return ""
	if primary_available(run_state, definition) and not bool(fallback.get("available_with_primary", false)):
		return ""
	if not _location_matches(fallback, environment):
		return ""
	var selected_node := fallback_node_id(run_state, definition)
	var current_node := str(environment.get("world_node_id", environment.get("archetype_id", ""))).strip_edges()
	return "fallback" if selected_node.is_empty() or selected_node == current_node else ""


static func primary_available(run_state: RunState, definition: Dictionary) -> bool:
	var primary := _dict(definition.get("primary", {}))
	var scenario_ids := _string_array(primary.get("scenario_ids", []))
	if not scenario_ids.is_empty():
		for node_id in _world_node_ids(run_state):
			if scenario_ids.has(str(run_state.seeded_scenario_for_node(node_id).get("id", ""))):
				return true
		return false
	var archetype_ids := _string_array(primary.get("archetype_ids", []))
	for node_id in _world_node_ids(run_state):
		if archetype_ids.has(node_id):
			return true
	return not archetype_ids.is_empty() and not run_state.has_world_map()


static func fallback_node_id(run_state: RunState, definition: Dictionary) -> String:
	var fallback := _dict(definition.get("fallback", {}))
	var allowed := _string_array(fallback.get("archetype_ids", []))
	var candidates: Array = []
	for node_id in _world_node_ids(run_state):
		if allowed.has(node_id):
			candidates.append(node_id)
	if candidates.is_empty():
		return ""
	candidates.sort()
	var rng := RngStream.new()
	rng.configure(run_state.seed_value, run_state.seed_value)
	rng = rng.fork("crew_recruitment_fallback:%s" % str(definition.get("member_id", "")))
	return str(rng.pick(candidates, candidates[0]))


static func meetable_members(run_state: RunState) -> Array:
	if not crew_path_started(run_state):
		return []
	var result: Array = []
	for member_id in MEMBER_IDS:
		if member_id == "crew_rook" or _rank_at_least(run_state.crew_rank(member_id), "associate"):
			continue
		var definition := member_definition(member_id)
		if primary_available(run_state, definition) or not fallback_node_id(run_state, definition).is_empty():
			result.append(member_id)
	return result


static func contact_choices(run_state: RunState, _environment: Dictionary, member_id: String, library: ContentLibrary = null) -> Array:
	if run_state == null or not _rank_at_least(run_state.crew_rank(member_id), "associate"):
		return []
	var choices: Array = []
	if run_state.crew_member_job_available(member_id):
		for job_value in CrewStateModelScript.job_definitions_for_member(member_id):
			if choices.size() >= 3 or typeof(job_value) != TYPE_DICTIONARY:
				break
			var job: Dictionary = job_value
			var definition_id := str(job.get("id", "")).strip_edges()
			var target_event_id := str(_dict(job.get("payload", {})).get("event_id", "")).strip_edges()
			if definition_id.is_empty() or run_state.crew_job_definition_pending(definition_id):
				continue
			var offer_line := str(member_definition(member_id).get("job_offer_line", "There is work if you want it."))
			if not target_event_id.is_empty():
				if (library != null and library.event(target_event_id).is_empty()) or run_state.triggered_event_pending(target_event_id):
					continue
				choices.append({
					"id": "job_%s" % definition_id,
					"label": "Ask about work",
					"text": offer_line,
					"consequences": {"trigger_event": {"event_id": target_event_id, "chance": 1.0}},
				})
			else:
				choices.append({
					"id": "job_%s" % definition_id,
					"label": str(job.get("label", "Take the job")),
					"text": offer_line,
					"consequences": {"event_hooks": [{"type": "crew_job_accept", "definition_id": definition_id}]},
				})
	if member_id == "crew_switch":
		var sweep := run_state.sweep_status()
		if run_state.crew_capability_active("sweep_intel") and choices.size() < 3:
			var sweep_text := "Sweep is quiet for now."
			if bool(sweep.get("active", false)):
				var current_node := str(sweep.get("current_node_id", "")).replace("_", " ").capitalize()
				var heading_node := str(sweep.get("heading_node_id", "")).replace("_", " ").capitalize()
				var heading_suffix := ""
				if not heading_node.is_empty():
					heading_suffix = " and heading toward %s" % heading_node
				sweep_text = "Sweep is at %s%s." % [current_node, heading_suffix]
			choices.append({"id": "read_sweep", "label": "Read the sweep", "text": sweep_text, "consequences": {}})
		for candidate_value in run_state.crew_switch_reveal_candidates():
			if choices.size() >= 3 or typeof(candidate_value) != TYPE_DICTIONARY:
				break
			var candidate: Dictionary = candidate_value
			var node_id := str(candidate.get("node_id", ""))
			choices.append({
				"id": "reveal_%s" % node_id,
				"label": "Read %s" % str(candidate.get("display_name", node_id.replace("_", " ").capitalize())),
				"text": "Switch taps the route once. The real stop comes into focus.",
				"consequences": {"event_hooks": [{"type": "crew_switch_reveal", "node_id": node_id}]},
			})
	elif member_id == "crew_knuckles":
		var stash_status := run_state.crew_knuckles_stash_status()
		if bool(stash_status.get("available", false)):
			for candidate_value in run_state.crew_knuckles_stash_candidates():
				if choices.size() >= 3 or typeof(candidate_value) != TYPE_DICTIONARY:
					break
				var candidate: Dictionary = candidate_value
				var item_id := str(candidate.get("item_id", ""))
				var inventory_index := int(candidate.get("inventory_index", -1))
				choices.append({
					"id": "stash_%s_%d" % [item_id, inventory_index],
					"label": "Stash %s" % _item_display_name(library, item_id),
					"text": "Knuckles takes it without asking where it came from.",
					"consequences": {"event_hooks": [{"type": "crew_knuckles_stash", "item_id": item_id, "inventory_index": inventory_index}]},
				})
		for candidate_value in run_state.crew_knuckles_retrieve_candidates():
			if choices.size() >= 3 or typeof(candidate_value) != TYPE_DICTIONARY:
				break
			var candidate: Dictionary = candidate_value
			var item_id := str(candidate.get("item_id", ""))
			var stash_index := int(candidate.get("stash_index", -1))
			choices.append({
				"id": "retrieve_%s_%d" % [item_id, stash_index],
				"label": "Retrieve %s" % _item_display_name(library, item_id),
				"text": "Knuckles slides it back. Still yours. Still quiet.",
				"consequences": {"event_hooks": [{"type": "crew_knuckles_retrieve", "item_id": item_id, "stash_index": stash_index}]},
			})
	elif member_id == "crew_lucky" and bool(run_state.numbers_desk_status().get("runner_available", false)) and choices.size() < 3:
		choices.append({
			"id": "start_numbers_collection",
			"label": "Take the collection route",
			"text": "Lucky hands over a sealed bag and three stops that refuse to stay simple.",
			"consequences": {"event_hooks": [{"type": "crew_lucky_collection"}]},
		})
	if choices.is_empty():
		return []
	choices.append({"id": "leave", "label": "Leave", "text": "The Crew contact lets the room breathe.", "consequences": {}})
	return choices


static func rook_signpost_choices(run_state: RunState, resolve_event: bool = true) -> Array:
	var result: Array = []
	for member_id in meetable_members(run_state):
		var heard_flag := "crew_rook_lead_heard:%s" % member_id
		if bool(run_state.narrative_flags.get(heard_flag, false)):
			continue
		var definition := member_definition(member_id)
		var line := str(definition.get("rook_line", "")).strip_edges()
		if line.is_empty():
			continue
		var consequences := {"flags": {heard_flag: true}}
		if resolve_event:
			consequences["resolve_event"] = true
		else:
			consequences["event_hooks"] = [{"type": "crew_rook_lead_closed"}]
		result.append({
			"id": "ask_%s" % member_id.trim_prefix("crew_"),
			"label": str(member_id.trim_prefix("crew_")).capitalize(),
			"text": line,
			"consequences": consequences,
		})
	if not result.is_empty() and resolve_event:
		result.append({"id": "keep_moving", "label": "Keep moving", "text": "Rook nods. The road keeps its own time.", "consequences": {"resolve_event": true}})
	return result


static func presence_for_environment(run_state: RunState, environment: Dictionary) -> Array:
	var result: Array = []
	# Recovery venues intentionally author no room actors. Recruitment can still
	# surface as an event beat there, but ambient Crew presence never weakens
	# that shipped environment rule.
	if str(environment.get("kind", "")) == "recovery":
		return result
	var canonical_node := str(environment.get("world_node_id", environment.get("archetype_id", ""))).strip_edges()
	var physical_location := str(environment.get("archetype_id", canonical_node)).strip_edges()
	var current_location := physical_location if canonical_node == "grand_casino" and GRAND_CASINO_ROOM_IDS.has(physical_location) else canonical_node
	var action_index := int(run_state.town_snapshot().get("action_index", 0))
	var rotate := maxi(1, int(config().get("presence_rotate_actions", 6)))
	var segment := action_index / rotate
	if str(environment.get("current_layer_id", "")) == "back_room":
		return _back_room_residency(run_state, segment)
	for member_id in MEMBER_IDS:
		var rank := run_state.crew_rank(member_id)
		if not _rank_at_least(rank, "marker"):
			continue
		var definition := member_definition(member_id)
		var locations := _string_array(definition.get("presence", []))
		var available: Array = []
		var nodes := _world_node_ids(run_state)
		for location in locations:
			var grand_child_available := nodes.has("grand_casino") and GRAND_CASINO_ROOM_IDS.has(location)
			if nodes.is_empty() or nodes.has(location) or grand_child_available:
				available.append(location)
		if available.is_empty():
			continue
		var rng := RngStream.new()
		rng.configure(run_state.seed_value, run_state.seed_value)
		rng = rng.fork("crew_presence:%s:%d" % [member_id, segment])
		if str(rng.pick(available, available[0])) != current_location:
			continue
		var lines := _dict(definition.get("presence_lines", {}))
		var line := str(lines.get(rank, lines.get("marker", ""))).strip_edges()
		result.append({"member_id": member_id, "rank": rank, "line": line})
	return result


# Layer 3 is a home base rather than another itinerary stop. Two to four met
# members rotate into residence on the same seeded schedule as their public
# appearances. The result depends only on seed, segment, and canonical trust.
static func _back_room_residency(run_state: RunState, segment: int) -> Array:
	var candidates: Array = []
	for member_id in MEMBER_IDS:
		if _rank_at_least(run_state.crew_rank(member_id), "marker"):
			candidates.append(member_id)
	if candidates.is_empty():
		return []
	var rng := RngStream.new()
	rng.configure(run_state.seed_value, run_state.seed_value)
	rng = rng.fork("crew_back_room_residency:%d" % segment)
	var count := mini(candidates.size(), 2 + posmod(run_state.seed_value + segment, 3))
	var selected := rng.pick_many(candidates, count)
	var result: Array = []
	for member_value in selected:
		var member_id := str(member_value)
		var rank := run_state.crew_rank(member_id)
		var lines := _dict(member_definition(member_id).get("presence_lines", {}))
		result.append({
			"member_id": member_id,
			"rank": rank,
			"line": str(lines.get(rank, lines.get("marker", ""))).strip_edges(),
			"resident": true,
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("member_id", "")) < str(b.get("member_id", "")))
	return result


static func rank_perks(member_id: String) -> Dictionary:
	return _dict(_dict(CrewStateModelScript.config().get("member_rank_perks", {})).get(member_id, {}))


static func stash_cap() -> int:
	return maxi(0, int(_dict(CrewStateModelScript.config().get("member_services", {})).get("knuckles_stash_cap", 0)))


static func validate_content() -> Array:
	var failures: Array = []
	var source := config()
	if int(source.get("schema_version", 0)) != SCHEMA_VERSION:
		failures.append("recruitment.json schema_version must match CrewRecruitmentModel.")
	if int(source.get("associate_trust", -1)) != CrewStateModelScript.rank_threshold("associate"):
		failures.append("recruitment.json associate_trust must match crew.json's Associate threshold.")
	var seen: Array = []
	for value in _array(source.get("members", [])):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = value
		var member_id := str(definition.get("member_id", ""))
		if not MEMBER_IDS.has(member_id) or seen.has(member_id):
			failures.append("Crew recruitment has an unknown or duplicate member %s." % member_id)
			continue
		seen.append(member_id)
		if _dict(definition.get("primary", {})).is_empty() or _dict(definition.get("fallback", {})).is_empty():
			failures.append("Crew recruitment %s needs primary and fallback placement data." % member_id)
		if str(definition.get("contact_event_id", "")).strip_edges().is_empty():
			failures.append("Crew recruitment %s needs a contact event id." % member_id)
		if _string_array(definition.get("presence", [])).is_empty():
			failures.append("Crew recruitment %s needs a seeded presence itinerary." % member_id)
		var lines := _dict(definition.get("presence_lines", {}))
		for rank in ["marker", "associate", "made", "inner_circle"]:
			if str(lines.get(rank, "")).strip_edges().is_empty():
				failures.append("Crew recruitment %s is missing its %s presence line." % [member_id, rank])
	if seen != MEMBER_IDS:
		failures.append("Crew recruitment must define all seven members in contract order.")
	return failures


static func _fallback_system_live(run_state: RunState, fallback: Dictionary) -> bool:
	var system_id := str(fallback.get("requires_system", "")).strip_edges()
	if system_id.is_empty():
		return true
	if system_id == "numbers":
		return run_state.numbers_state != null
	return false


static func _location_matches(location: Dictionary, environment: Dictionary) -> bool:
	var archetype_ids := _string_array(location.get("archetype_ids", []))
	var archetype_id := str(environment.get("archetype_id", "")).strip_edges()
	if not archetype_ids.is_empty() and not archetype_ids.has(archetype_id):
		return false
	var scenario_ids := _string_array(location.get("scenario_ids", []))
	if not scenario_ids.is_empty() and not scenario_ids.has(str(environment.get("scenario_id", ""))):
		return false
	var layer_ids := _string_array(location.get("layer_ids", []))
	if not layer_ids.is_empty() and not layer_ids.has(str(environment.get("current_layer_id", ""))):
		return false
	return not archetype_ids.is_empty() or not scenario_ids.is_empty()


static func _world_node_ids(run_state: RunState) -> Array:
	var result: Array = []
	if run_state == null:
		return result
	for value in _array(run_state.world_map.get("nodes", [])):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var node_id := str((value as Dictionary).get("id", "")).strip_edges()
		if not node_id.is_empty():
			result.append(node_id)
	return result


static func _rank_at_least(rank: String, minimum: String) -> bool:
	return RANKS.has(rank) and RANKS.has(minimum) and RANKS.find(rank) >= RANKS.find(minimum)


static func _load_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Array).duplicate(true) if typeof(parsed) == TYPE_ARRAY else []


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	for entry_value in _array(value):
		var entry := str(entry_value).strip_edges()
		if not entry.is_empty():
			result.append(entry)
	return result


static func _item_display_name(library: ContentLibrary, item_id: String) -> String:
	if library != null:
		var definition := library.item(item_id)
		if not definition.is_empty():
			return str(definition.get("display_name", definition.get("name", item_id.replace("_", " ").capitalize())))
	return item_id.replace("_", " ").capitalize()
