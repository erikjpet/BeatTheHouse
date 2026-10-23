class_name CrewDeliverySchedule
extends RefCounted

# Absolute game minutes, including the day. Windows are [opens, closes).
# Walking is the slow, fare-free travel option used to budget the appointment.
const PlayerTextScript := preload("res://scripts/ui/player_text.gd")
const EnvironmentHoursScript := preload("res://scripts/core/environment_hours.gd")
const WALK_MINUTES_PER_BLOCK := 10
const WINDOW_MINUTES := 30
const FIRST_LEAD_MINUTES := 150
static var _archetypes: Dictionary = {}


static func is_package_kind(kind: String) -> bool:
	return kind in ["package_run", "package_delivery", "numbers_route"]


static func is_route_kind(kind: String) -> bool:
	return is_package_kind(kind) or kind in ["lookout_hold", "collection"]


static func is_crew_route(state: Dictionary) -> bool:
	var run_id := str(state.get("run_id", ""))
	return str(state.get("mode", "")) in ["package", "multi_stop"] and (
		run_id == "crew_favor_delivery" or run_id.begins_with("crew_offer:")
		or (run_id.begins_with("crew_job:") and not str(state.get("job_id", "")).is_empty())
	)


static func windows_for(run: Object, targets: Array, offered_clock: int) -> Array:
	if _archetypes.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/environments/archetypes.json"))
		if typeof(parsed) == TYPE_ARRAY:
			for row in parsed:
				if typeof(row) == TYPE_DICTIONARY: _archetypes[str(row.get("id", ""))] = row
	var result: Array = []
	var origin: String = run.current_world_node_id()
	var cursor := offered_clock
	for target_value in targets:
		var target: Dictionary = target_value
		if str(target.get("status", "pending")) == "delivered": continue
		var node_id := str(target.get("node_id", ""))
		var route := WorldMap.new(null).route_for_target_prepared(run.world_map, origin, node_id, WorldMap.prepare_path_query(run.world_map, origin, false)) if origin != node_id else {}
		if origin != node_id and route.is_empty(): return []
		var travel := maxi(1, int(route.get("distance_blocks", 1))) * WALK_MINUTES_PER_BLOCK if origin != node_id else 0
		var lead := maxi(FIRST_LEAD_MINUTES, travel + WINDOW_MINUTES) if result.is_empty() else travel + WINDOW_MINUTES
		var opens := ceili(float(cursor + lead) / 30.0) * 30
		var node := WorldMap.node_metadata_by_id(run.world_map, node_id)
		var archetype: Dictionary = _archetypes.get(str(node.get("archetype_id", "")), {})
		# Find a complete half-hour inside the venue's existing operating hours.
		# The bounded daily scan also handles overnight venues and midnight.
		var available := false
		for _slot in range(49):
			if run.is_tutorial_run() or (EnvironmentHoursScript.environment_open_at(archetype, opens) and EnvironmentHoursScript.environment_open_at(archetype, opens + WINDOW_MINUTES - 1)):
				available = true
				break
			opens += 30
		if not available: return []
		result.append({"node_id": node_id, "opens": opens, "closes": opens + WINDOW_MINUTES})
		cursor = opens + WINDOW_MINUTES
		origin = node_id
	return result


static func window_for(state: Dictionary, node_id: String) -> Dictionary:
	var payload: Dictionary = state.get("consumer_payload", {})
	for row in payload.get("meeting_windows", []):
		if typeof(row) == TYPE_DICTIONARY and str(row.get("node_id", "")) == node_id: return row
	return {}


static func next_deadline(state: Dictionary) -> int:
	var deadline := int(state.get("deadline_game_clock_minutes", 0))
	for target in state.get("targets", []):
		if str(target.get("status", "pending")) == "delivered": continue
		var window := window_for(state, str(target.get("node_id", "")))
		if not window.is_empty(): deadline = mini(deadline, int(window.get("closes", deadline)))
	return deadline


static func handoff_open(state: Dictionary, node_id: String) -> bool:
	var window := window_for(state, node_id)
	if window.is_empty(): return true
	# advance_clock is the sole owner of elapsed game time in delivery state.
	var now := int(state.get("deadline_game_clock_minutes", 0)) - int(state.get("deadline_remaining", 0))
	return now >= int(window.get("opens", 0)) and now < int(window.get("closes", 0))


static func window_text(window: Dictionary) -> String:
	return "%s to %s (handoff before closing)" % [
		PlayerTextScript.format_game_clock(int(window.get("opens", 0))),
		PlayerTextScript.format_game_clock(int(window.get("closes", 0))),
	]


static func timing_text(state: Dictionary, all_targets: bool = false) -> String:
	var lines: Array[String] = []
	for target in state.get("targets", []):
		if str(target.get("status", "pending")) == "delivered": continue
		var window := window_for(state, str(target.get("node_id", "")))
		if window.is_empty(): continue
		lines.append("%s at %s: %s" % [str(target.get("contact_label", "Recipient")), str(target.get("label", "destination")), window_text(window)])
		if not all_targets: break
	if not lines.is_empty(): return "\n".join(lines)
	if str(state.get("deadline_kind", "actions")) == "clock":
		return "Before %s" % PlayerTextScript.format_game_clock(int(state.get("deadline_game_clock_minutes", 0)))
	return PlayerTextScript.count_text("action", int(state.get("deadline_remaining", 0)))
