class_name ScenarioLayoutResolver
extends RefCounted

const ArtContractsScript := preload("res://scripts/core/art_contracts.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")

const BOARD_SIZE := Vector2(ArtContractsScript.ENVIRONMENT_BOARD_SIZE)
const SMALL_SCREEN_TARGET := Vector2(ArtContractsScript.ENVIRONMENT_OBJECT_HIT_SIZE)
const MAX_VISUALS := 128
const MIN_SCENE_SIZE := Vector2(16.0, 16.0)
const DEFAULT_SCENE_SIZE := Vector2(48.0, 48.0)
const DEFAULT_ACTOR_SIZE := Vector2(72.0, 80.0)
const COLLISION_RATIO := 0.65
const LABEL_MAX_LENGTH := 64
const PROMPT_MAX_LENGTH := 240
const LABEL_HEIGHT := 15.0
const LABEL_GAP := 4.0
const LABEL_MAX_WIDTH := 126.0
const WALK_LANE := Rect2(16.0, 378.0, 868.0, 36.0)
const ROUTE_BEHAVIORS := ["patrol", "flee", "depart"]
const COLLISION_OFFSETS := [
	Vector2.ZERO,
	Vector2(56.0, 0.0), Vector2(-56.0, 0.0),
	Vector2(0.0, 52.0), Vector2(0.0, -52.0),
	Vector2(112.0, 0.0), Vector2(-112.0, 0.0),
	Vector2(0.0, 104.0), Vector2(0.0, -104.0),
	Vector2(112.0, 52.0), Vector2(-112.0, 52.0),
	Vector2(112.0, -52.0), Vector2(-112.0, -52.0),
	Vector2(168.0, 0.0), Vector2(-168.0, 0.0),
	Vector2(168.0, 104.0), Vector2(-168.0, 104.0),
]
const LAYOUT_SPOT_FIELDS := {
	"game": "game_spots",
	"event": "event_spots",
	"item": "item_spots",
	"service": "service_spots",
	"lender": "lender_spots",
	"travel": "travel_spots",
	"shopkeeper": "shopkeeper_spots",
	"game_hook": "game_hook_spots",
}


# Compatibility projection used by the renderer-extension seam. Production
# interaction composition uses resolve(), which additionally seals geometry to
# the finalized base-record authority.
static func prepare(environment: Dictionary, projection: Dictionary) -> Dictionary:
	if projection.is_empty():
		return {}
	var semantic_state := _dict(projection.get("semantic_state", {}))
	var errors: Array = []
	var visuals: Array = []
	for family_value in [
		[semantic_state.get("scene_objects", {}), false],
		[semantic_state.get("actors", {}), true],
	]:
		var family := _dict((family_value as Array)[0])
		var actor := bool((family_value as Array)[1])
		var identities := family.keys()
		identities.sort()
		for identity_value in identities:
			var semantic := _dict(family.get(identity_value, {}))
			if semantic.is_empty() or not bool(semantic.get("present", true)):
				continue
			var visual := _prepare_extension_visual(environment, semantic_state, semantic, actor, errors)
			if not visual.is_empty():
				visuals.append(visual)
	visuals.sort_custom(func(a: Variant, b: Variant) -> bool:
		var left := _dict(a)
		var right := _dict(b)
		var left_z := int(left.get("z_order", 0))
		var right_z := int(right.get("z_order", 0))
		return str(left.get("semantic_identity", "")) < str(right.get("semantic_identity", "")) if left_z == right_z else left_z < right_z
	)
	return {
		"schema_version": 1,
		"scenario_id": str(projection.get("scenario_id", "")),
		"phase_id": str(projection.get("phase_id", "")),
		"status": str(projection.get("status", "")),
		"boundary_serial": maxi(0, int(projection.get("boundary_serial", 0))),
		"ok": errors.is_empty(),
		"errors": errors,
		"warnings": [],
		"visual_objects": visuals,
		"interaction_overlays": _ordered_semantic_values(_dict(semantic_state.get("interactions", {}))),
		"services": _ordered_semantic_values(_dict(semantic_state.get("services", {}))),
		"games": _ordered_semantic_values(_dict(semantic_state.get("games", {}))),
		"routes": _ordered_semantic_values(_dict(semantic_state.get("routes", {}))),
		"active_stages": _array(projection.get("active_stages", [])),
		"layout_audit": {
			"board_size": _size_snapshot(BOARD_SIZE),
			"small_screen_target": _size_snapshot(SMALL_SCREEN_TARGET),
			"visual_count": visuals.size(),
			"interaction_count": _dict(semantic_state.get("interactions", {})).size(),
		},
	}


static func _prepare_extension_visual(environment: Dictionary, semantic_state: Dictionary, semantic: Dictionary, actor: bool, errors: Array) -> Dictionary:
	var identity := OperationRegistryScript.identity_from(semantic)
	var label := str(semantic.get("label", "")).strip_edges()
	if identity == "::" or label.is_empty():
		errors.append("Scenario visual is missing its stable identity or accessible label.")
		return {}
	var center := _resolve_center(environment, str(semantic.get("anchor_id", "")), str(semantic.get("zone_id", "")))
	if not _finite_point(center) or center.x < 0.0:
		errors.append("Scenario visual %s references an unresolved anchor or zone." % identity)
		return {}
	var bounds := _dict(semantic.get("bounds", {}))
	var size := Vector2(float(bounds.get("w", DEFAULT_ACTOR_SIZE.x if actor else DEFAULT_SCENE_SIZE.x)), float(bounds.get("h", DEFAULT_ACTOR_SIZE.y if actor else DEFAULT_SCENE_SIZE.y)))
	if not _finite_point(size) or size.x < MIN_SCENE_SIZE.x or size.y < MIN_SCENE_SIZE.y:
		errors.append("Scenario visual %s has out-of-bounds semantic dimensions." % identity)
		return {}
	var route_points: Array = []
	if actor and not str(semantic.get("route_id", "")).strip_edges().is_empty():
		var route_center := _resolve_route_center(environment, semantic_state, str(semantic.get("route_id", "")))
		if _finite_point(route_center) and route_center.x >= 0.0:
			route_points = [_normalized_point(center), _normalized_point(route_center)]
		else:
			errors.append("Scenario actor %s references an unresolved route." % identity)
	var rect := _clamp_inside_board(Rect2(center - size * 0.5, size))
	var owner := str(semantic.get("owner_namespace", ""))
	var stable_id := str(semantic.get("stable_object_id", ""))
	return {
		"object_id": "scenario:%s:%s" % [owner, stable_id],
		"object_type": "scenario_actor" if actor else "scenario_object",
		"visual_type": "scenario_actor" if actor else "scenario_object",
		"source_id": str(semantic.get("actor_id", stable_id)),
		"label": label,
		"short_description": str(semantic.get("behavior", semantic.get("role", "Room object"))).replace("_", " ").capitalize(),
		"presence": "scenario",
		"interactive": false,
		"decorative": true,
		"enabled": bool(semantic.get("enabled", true)),
		"visible": bool(semantic.get("visible", true)),
		"normalized_rect": _normalized_rect(rect),
		"focus_rect": _normalized_rect(rect),
		"small_screen_rect": _normalized_rect(_expanded_rect(rect, SMALL_SCREEN_TARGET)),
		"owner_namespace": owner,
		"stable_object_id": stable_id,
		"semantic_identity": identity,
		"role": str(semantic.get("role", "actor" if actor else "prop")),
		"state": str(semantic.get("state", "")),
		"appearance": str(semantic.get("appearance", "")),
		"pose": str(semantic.get("pose", "idle")),
		"behavior": str(semantic.get("behavior", "idle")),
		"route_id": str(semantic.get("route_id", "")),
		"route_points": route_points,
		"non_color_state": str(semantic.get("non_color_state", semantic.get("state", "present"))),
		"z_order": int(round(rect.get_center().y)) + (20 if actor else 0),
	}


static func _ordered_semantic_values(value: Dictionary) -> Array:
	var result: Array = []
	var keys := value.keys()
	keys.sort()
	for key in keys:
		result.append(_dict(value.get(key, {})))
	return result


# Renderer snapshot derived only from a successful sealed layout result. It
# copies the exact draw/hit geometry and authority digest instead of resolving
# a second presentation candidate.
static func sealed_renderer_snapshot(layout_result: Dictionary) -> Dictionary:
	if not bool(layout_result.get("ok", false)):
		return {"ok": false, "errors": _array(layout_result.get("errors", ["Scenario renderer requires sealed layout authority."]))}
	var projection := _dict(layout_result.get("projection", {}))
	var semantic_state := _dict(projection.get("semantic_state", {}))
	var authority := _dict(layout_result.get("layout_authority", {}))
	var authority_digest := str(layout_result.get("layout_authority_digest", ""))
	if not _valid_sha256(authority_digest) or _authority_digest(authority) != authority_digest:
		return {"ok": false, "errors": ["Scenario renderer authority digest is missing or stale."]}
	var visuals: Array = []
	for family_value in [
		[semantic_state.get("scene_objects", {}), false],
		[semantic_state.get("actors", {}), true],
	]:
		var family := _dict((family_value as Array)[0])
		var actor := bool((family_value as Array)[1])
		var identities := family.keys()
		identities.sort()
		for identity_value in identities:
			var identity := str(identity_value)
			var semantic := _dict(family.get(identity_value, {}))
			var sealed := _dict(authority.get(identity, {}))
			if semantic.is_empty() or not bool(semantic.get("present", true)):
				continue
			if sealed.is_empty() or str(sealed.get("identity", "")) != identity:
				return {"ok": false, "errors": ["Scenario renderer visual %s has no exact sealed authority." % identity]}
			visuals.append({
				"object_id": str(sealed.get("presentation_object_id", identity)),
				"object_type": "scenario_actor" if actor else "scenario_object",
				"visual_type": "scenario_actor" if actor else "scenario_object",
				"source_id": str(semantic.get("actor_id", semantic.get("stable_object_id", ""))),
				"label": str(semantic.get("label", "")),
				"short_description": str(semantic.get("behavior", semantic.get("role", "Room object"))).replace("_", " ").capitalize(),
				"presence": "scenario",
				"interactive": bool(sealed.get("presentation_interactive", false)),
				"decorative": not bool(sealed.get("presentation_interactive", false)),
				"enabled": bool(semantic.get("enabled", true)),
				"visible": bool(sealed.get("presentation_visible", true)),
				"normalized_rect": _dict(sealed.get("normalized_hit_rect", {})),
				"focus_rect": _dict(sealed.get("normalized_hit_rect", {})),
				"small_screen_rect": _dict(sealed.get("small_screen_rect", {})),
				"owner_namespace": str(semantic.get("owner_namespace", "")),
				"stable_object_id": str(semantic.get("stable_object_id", "")),
				"semantic_identity": identity,
				"role": str(semantic.get("role", "actor" if actor else "prop")),
				"state": str(semantic.get("state", "")),
				"appearance": str(semantic.get("appearance", "")),
				"pose": str(semantic.get("pose", "idle")),
				"behavior": str(semantic.get("behavior", "idle")),
				"route_id": str(semantic.get("route_id", "")),
				"route_points": _array(sealed.get("actor_route_points", [])),
				"z_order": int(sealed.get("z_order", 0)),
				"scenario_layout_authority_identity": identity,
				"scenario_layout_authority_digest": authority_digest,
			})
	return {
		"schema_version": 2,
		"scenario_id": str(projection.get("scenario_id", "")),
		"phase_id": str(projection.get("phase_id", "")),
		"status": str(projection.get("status", "")),
		"boundary_serial": maxi(0, int(projection.get("boundary_serial", 0))),
		"ok": true,
		"errors": [],
		"warnings": _array(layout_result.get("warnings", [])),
		"visual_objects": visuals,
		"interaction_overlays": _ordered_semantic_values(_dict(semantic_state.get("interactions", {}))),
		"services": _ordered_semantic_values(_dict(semantic_state.get("services", {}))),
		"games": _ordered_semantic_values(_dict(semantic_state.get("games", {}))),
		"routes": _ordered_semantic_values(_dict(semantic_state.get("routes", {}))),
		"active_stages": _array(projection.get("active_stages", [])),
		"layout_authority": authority,
		"layout_authority_digest": authority_digest,
		"layout_audit": _dict(layout_result.get("layout_audit", {})),
	}


static func resolve(base_records: Array, projection: Dictionary, environment: Dictionary = {}) -> Dictionary:
	var semantic_state := _dict(projection.get("semantic_state", {}))
	var resolved_projection := projection.duplicate(true)
	var passive_audit := {
		"active": false,
		"visual_count": 0,
		"collision_adjustment_count": 0,
		"board_size": _size_snapshot(BOARD_SIZE),
		"small_screen_target": _size_snapshot(SMALL_SCREEN_TARGET),
	}
	if not _has_active_presentation(semantic_state):
		return {
			"ok": true,
			"projection": resolved_projection,
			"errors": [],
			"warnings": [],
			"layout_authority": {},
			"layout_authority_digest": "",
			"fallback_authority": _fallback_authority(),
			"layout_audit": passive_audit,
		}
	if environment.is_empty():
		return _failed_result(resolved_projection, ["An active scenario presentation requires the current validated room layout."], [], passive_audit)

	var errors: Array = []
	var warnings: Array = []
	var occupied := _base_occupied_records(base_records)
	var base_by_identity := _base_records_by_identity(base_records)
	var authority := _base_layout_authority(base_records, errors)
	var collision_adjustments := 0
	var visual_count := 0
	var resolved_scenes: Dictionary = {}
	var resolved_actors: Dictionary = {}
	for collection_entry in [
		[semantic_state.get("scene_objects", {}), false, resolved_scenes],
		[semantic_state.get("actors", {}), true, resolved_actors],
	]:
		var collection := _dict((collection_entry as Array)[0])
		var actor := bool((collection_entry as Array)[1])
		var destination: Dictionary = (collection_entry as Array)[2]
		var identities := collection.keys()
		identities.sort()
		for identity_value in identities:
			var identity := str(identity_value)
			var semantic := _dict(collection.get(identity_value, {}))
			if semantic.is_empty():
				continue
			if not bool(semantic.get("present", true)):
				destination[identity] = semantic
				continue
			visual_count += 1
			if visual_count > MAX_VISUALS:
				errors.append("Scenario presentation exceeds the %d visual-object bound." % MAX_VISUALS)
				continue
			var resolved := _resolve_visual(
				identity,
				semantic,
				actor,
				environment,
				semantic_state,
				_dict(base_by_identity.get(identity, {})),
				occupied,
				errors
			)
			if resolved.is_empty():
				continue
			resolved["layout_valid"] = true
			if bool(resolved.get("collision_adjusted", false)):
				collision_adjustments += 1
			destination[identity] = resolved
			if bool(resolved.get("visible", true)):
				var normal_rect := _pixel_rect(_dict(resolved.get("normalized_hit_rect", {})))
				var small_rect := _pixel_rect(_dict(resolved.get("small_screen_rect", {})))
				occupied.append({"identity": identity, "rect": normal_rect, "small_rect": small_rect})

	semantic_state["scene_objects"] = resolved_scenes
	semantic_state["actors"] = resolved_actors
	_validate_visual_identity_uniqueness(resolved_scenes, resolved_actors, errors)
	_assign_z_order(resolved_scenes, resolved_actors)
	var obstacles := _scenario_obstacles(resolved_scenes)
	_validate_visual_access(resolved_scenes, resolved_actors, obstacles, base_records, environment, errors)
	_validate_actor_routes(resolved_actors, obstacles, occupied, environment, errors)
	_validate_visual_interaction_consistency(_dict(semantic_state.get("interactions", {})), resolved_scenes, resolved_actors, errors)
	_add_visual_authority(authority, resolved_scenes, "scene_object")
	_add_visual_authority(authority, resolved_actors, "actor")
	_seal_projection_coverage(authority, semantic_state, errors)
	var interaction_audit := _validate_interactions(_dict(semantic_state.get("interactions", {})), authority, obstacles, base_records, environment, errors)
	_validate_authority(authority, errors)
	var authority_digest := _authority_digest(authority)
	semantic_state["layout_authority_digest"] = authority_digest
	resolved_projection["semantic_state"] = semantic_state
	var context := _layout_context(environment)
	_validate_layout_context(context, errors)
	var audit := {
		"active": true,
		"valid": true,
		"visual_count": mini(visual_count, MAX_VISUALS),
		"collision_adjustment_count": collision_adjustments,
		"board_size": _size_snapshot(BOARD_SIZE),
		"small_screen_target": _size_snapshot(SMALL_SCREEN_TARGET),
		"walk_lane": _rect_snapshot(WALK_LANE),
		"reserved_overlay_rect": _rect_snapshot(_context_overlay_rect(context)),
		"production_canvas": bool(context.get("production_canvas", false)),
		"small_screen_mode": bool(context.get("small_screen_mode", false)),
		"reduce_motion": bool(context.get("reduce_motion", false)),
		"authority_count": authority.size(),
		"authority_digest": authority_digest,
		"reachable_interaction_ids": interaction_audit.get("reachable_interaction_ids", []),
		"safe_exit_ids": interaction_audit.get("safe_exit_ids", []),
		"alternate_exit_ids": interaction_audit.get("alternate_exit_ids", []),
		"actor_route_count": _actor_route_count(resolved_actors),
		"normal_overlap_count": _overlap_count(authority, "normalized_hit_rect"),
		"small_screen_overlap_count": _overlap_count(authority, "small_screen_rect"),
		"deterministic_z_order": true,
	}
	if not errors.is_empty():
		return _failed_result(resolved_projection, errors, warnings, audit)
	return {
		"ok": true,
		"projection": resolved_projection,
		"errors": [],
		"warnings": warnings,
		"layout_authority": authority,
		"layout_authority_digest": authority_digest,
		"fallback_authority": _fallback_authority(),
		"layout_audit": audit,
	}


static func failure_authority(base_records: Array = []) -> Dictionary:
	var authored := Rect2(300.0, 24.0, 300.0, 76.0)
	var placement := _collision_safe_rect("system::scenario_presentation_failure", authored, _base_occupied_records(base_records))
	var rect: Rect2 = placement.get("rect", authored)
	return _authority_record(
		"system::scenario_presentation_failure",
		"scenario::presentation_failure",
		_normalized_rect(rect),
		_normalized_rect(_expanded_rect(rect, SMALL_SCREEN_TARGET)),
		MAX_VISUALS + 1,
		"system_failure",
		"trusted_runtime_fallback"
	)


static func _resolve_visual(
	identity: String,
	semantic: Dictionary,
	actor: bool,
	environment: Dictionary,
	semantic_state: Dictionary,
	base_record: Dictionary,
	occupied: Array,
	errors: Array
) -> Dictionary:
	var result := semantic.duplicate(true)
	var base_rect := _record_pixel_rect(base_record)
	var anchor_id := str(semantic.get("anchor_id", base_record.get("anchor_id", "")))
	var zone_id := str(semantic.get("zone_id", base_record.get("zone_id", "")))
	var center := _resolve_center(
		environment,
		anchor_id,
		zone_id
	)
	if (not _finite_point(center) or center.x < 0.0) and anchor_id.is_empty() and zone_id.is_empty() and base_rect.size.x > 0.0 and base_rect.size.y > 0.0:
		center = base_rect.get_center()
	if not _finite_point(center) or center.x < 0.0:
		errors.append("Scenario visual %s references an unresolved anchor or zone." % identity)
		return {}
	var default_size := DEFAULT_ACTOR_SIZE if actor else DEFAULT_SCENE_SIZE
	var bounds := _dict(semantic.get("bounds", {}))
	var size := Vector2(float(bounds.get("w", 0.0)), float(bounds.get("h", 0.0)))
	if size.x <= 0.0 or size.y <= 0.0:
		size = base_rect.size if base_rect.size.x > 0.0 and base_rect.size.y > 0.0 else default_size
	if not _finite_point(size) or size.x < MIN_SCENE_SIZE.x or size.y < MIN_SCENE_SIZE.y or size.x > BOARD_SIZE.x or size.y > BOARD_SIZE.y:
		errors.append("Scenario visual %s has out-of-bounds semantic dimensions." % identity)
		return {}
	if not _readable_text(str(semantic.get("label", base_record.get("label", ""))), LABEL_MAX_LENGTH):
		errors.append("Scenario visual %s requires a bounded, readable label." % identity)
		return {}
	var authored_rect := _clamp_inside_board(Rect2(center - size * 0.5, size))
	var placement := _collision_safe_rect(identity, authored_rect, occupied)
	if bool(placement.get("colliding", true)):
		errors.append("Scenario visual %s cannot resolve both normal and expanded small-screen geometry without ambiguity." % identity)
		return {}
	var pixel_rect: Rect2 = placement.get("rect", authored_rect)
	var route_points: Array = []
	var route_stage: Dictionary = {}
	if actor:
		var behavior := str(semantic.get("behavior", "idle"))
		var route_id := str(semantic.get("route_id", "")).strip_edges()
		if behavior in ROUTE_BEHAVIORS and route_id.is_empty():
			errors.append("Scenario actor %s behavior %s requires a resolved room route." % [identity, behavior])
			return {}
		if not route_id.is_empty():
			var route_center := _resolve_route_center(environment, semantic_state, route_id)
			if not _finite_point(route_center) or route_center.x < 0.0:
				errors.append("Scenario actor %s route %s has no room-space endpoint." % [identity, route_id])
				return {}
			route_points = [_normalized_point(pixel_rect.get_center()), _normalized_point(route_center)]
			var route_endpoint_rect := Rect2(route_center - pixel_rect.size * 0.5, pixel_rect.size)
			var route_small_start := _expanded_rect(pixel_rect, SMALL_SCREEN_TARGET)
			var route_small_endpoint := _expanded_rect(route_endpoint_rect, SMALL_SCREEN_TARGET)
			var distance := pixel_rect.get_center().distance_to(route_center)
			route_stage = {
				"mode": "ping_pong" if behavior == "patrol" else "to_endpoint",
				"duration_sec": clampf(distance / 82.0, 0.75, 8.0),
				"reduced_motion_endpoint": _normalized_point(route_center),
				"start": _normalized_point(pixel_rect.get_center()),
				"endpoint": _normalized_point(route_center),
				"small_screen_start": _normalized_point(route_small_start.get_center()),
				"small_screen_endpoint": _normalized_point(route_small_endpoint.get_center()),
			}
	result["present"] = true
	result["semantic_kind"] = "actor" if actor else "scene_object"
	result["normalized_hit_rect"] = _normalized_rect(pixel_rect)
	result["small_screen_rect"] = _normalized_rect(_expanded_rect(pixel_rect, SMALL_SCREEN_TARGET))
	result["resolved_bounds"] = {"w": pixel_rect.size.x, "h": pixel_rect.size.y}
	result["collision_adjusted"] = bool(placement.get("adjusted", false))
	result["route_points"] = route_points
	result["route_stage"] = route_stage
	result["visible"] = bool(result.get("visible", true))
	result["enabled"] = bool(result.get("enabled", true))
	return result


static func _validate_visual_access(scenes: Dictionary, actors: Dictionary, obstacles: Array, base_records: Array, environment: Dictionary, errors: Array) -> void:
	var overlay := _context_overlay_rect(_layout_context(environment))
	var normal_labels: Array = []
	var small_labels: Array = []
	for base_value in base_records:
		var base_record := _dict(base_value)
		var base_identity := _record_identity(base_record)
		if not bool(base_record.get("visible", true)) or scenes.has(base_identity) or actors.has(base_identity):
			continue
		var base_rect := _record_pixel_rect(base_record)
		var base_small := _expanded_rect(base_rect, SMALL_SCREEN_TARGET)
		normal_labels.append({"identity": base_identity, "rect": _label_rect(base_rect, str(base_record.get("label", ""))), "scenario": false})
		small_labels.append({"identity": base_identity, "rect": _label_rect(base_small, str(base_record.get("label", ""))), "scenario": false})
	for collection in [scenes, actors]:
		var identities := (collection as Dictionary).keys()
		identities.sort()
		for identity_value in identities:
			var identity := str(identity_value)
			var semantic := _dict((collection as Dictionary).get(identity_value, {}))
			if semantic.is_empty() or not bool(semantic.get("present", true)) or not bool(semantic.get("visible", true)):
				continue
			var rect := _pixel_rect(_dict(semantic.get("normalized_hit_rect", {})))
			var small_rect := _pixel_rect(_dict(semantic.get("small_screen_rect", {})))
			var label_rect := _label_rect(rect, str(semantic.get("label", "")))
			var small_label_rect := _label_rect(small_rect, str(semantic.get("label", "")))
			if overlay.has_area() and (rect.intersects(overlay) or small_rect.intersects(overlay) or label_rect.intersects(overlay) or small_label_rect.intersects(overlay)):
				errors.append("Scenario visual %s collides with the reserved TalkDock overlay." % identity)
			normal_labels.append({"identity": identity, "rect": label_rect, "scenario": true})
			small_labels.append({"identity": identity, "rect": small_label_rect, "scenario": true})
			var role := str(semantic.get("role", "")).to_lower()
			if role in ["obstacle", "barrier", "blockade"] and (rect.intersects(WALK_LANE) or small_rect.intersects(WALK_LANE)):
				errors.append("Scenario obstacle %s blocks the mandatory player access lane in normal or expanded small-screen layout." % identity)
	_validate_label_entries(normal_labels, "normal", errors)
	_validate_label_entries(small_labels, "expanded small-screen", errors)
	if not obstacles.is_empty() and not _path_reachable(WALK_LANE.get_center(), Vector2(BOARD_SIZE.x * 0.5, BOARD_SIZE.y * 0.5), obstacles):
		errors.append("Scenario obstruction leaves no reachable route from the player access lane into the room.")
	if not obstacles.is_empty() and not _path_reachable(WALK_LANE.get_center(), Vector2(BOARD_SIZE.x * 0.5, BOARD_SIZE.y * 0.5), obstacles, "", "small_rect"):
		errors.append("Expanded small-screen scenario obstruction leaves no reachable route from the player access lane into the room.")


static func _validate_label_entries(entries: Array, layout_label: String, errors: Array) -> void:
	for left_index in range(entries.size()):
		var left := _dict(entries[left_index])
		var left_rect: Rect2 = left.get("rect", Rect2())
		for right_index in range(left_index + 1, entries.size()):
			var right := _dict(entries[right_index])
			if not bool(left.get("scenario", false)) and not bool(right.get("scenario", false)):
				continue
			var right_rect: Rect2 = right.get("rect", Rect2())
			if left_rect.intersects(right_rect) and left_rect.intersection(right_rect).get_area() > 0.01:
				errors.append("Scenario labels %s and %s overlap and are not text-safe in %s layout." % [str(left.get("identity", "")), str(right.get("identity", "")), layout_label])


static func _validate_actor_routes(actors: Dictionary, obstacles: Array, occupied: Array, environment: Dictionary, errors: Array) -> void:
	var overlay := _context_overlay_rect(_layout_context(environment))
	for identity_value in actors.keys():
		var identity := str(identity_value)
		var actor := _dict(actors.get(identity_value, {}))
		if actor.is_empty() or not bool(actor.get("present", true)):
			continue
		var points := _array(actor.get("route_points", []))
		if points.is_empty():
			continue
		if points.size() != 2:
			errors.append("Scenario actor %s route staging must have exactly one start and endpoint." % identity)
			continue
		var start := _pixel_point(_dict(points[0]))
		var endpoint := _pixel_point(_dict(points[1]))
		if not _finite_point(start) or not _finite_point(endpoint) or not Rect2(Vector2.ZERO, BOARD_SIZE).has_point(start) or not Rect2(Vector2.ZERO, BOARD_SIZE).has_point(endpoint):
			errors.append("Scenario actor %s route staging leaves the room board." % identity)
			continue
		if not _path_reachable(start, endpoint, obstacles, identity) or not _path_reachable(start, endpoint, obstacles, identity, "small_rect"):
			errors.append("Scenario actor %s route is obstructed or has an unreachable endpoint." % identity)
			continue
		var bounds := _dict(actor.get("resolved_bounds", {}))
		var endpoint_size := Vector2(float(bounds.get("w", DEFAULT_ACTOR_SIZE.x)), float(bounds.get("h", DEFAULT_ACTOR_SIZE.y)))
		var endpoint_rect := Rect2(endpoint - endpoint_size * 0.5, endpoint_size)
		if not Rect2(Vector2.ZERO, BOARD_SIZE).encloses(endpoint_rect):
			errors.append("Scenario actor %s route endpoint cannot stage its full bounds inside the room." % identity)
			continue
		var endpoint_small := _expanded_rect(endpoint_rect, SMALL_SCREEN_TARGET)
		if _substantially_overlaps(identity, endpoint_rect, occupied) or _expanded_overlaps(identity, endpoint_small, occupied):
			errors.append("Scenario actor %s route endpoint collides in normal or expanded small-screen layout." % identity)
		if overlay.has_area() and (endpoint_rect.intersects(overlay) or endpoint_small.intersects(overlay) or _label_rect(endpoint_rect, str(actor.get("label", ""))).intersects(overlay) or _label_rect(endpoint_small, str(actor.get("label", ""))).intersects(overlay)):
			errors.append("Scenario actor %s reduced-motion endpoint collides with the reserved TalkDock overlay." % identity)


static func _validate_interactions(interactions: Dictionary, authority: Dictionary, obstacles: Array, base_records: Array, environment: Dictionary, errors: Array) -> Dictionary:
	var reachable_ids: Array = []
	var safe_exit_ids: Array = []
	var alternate_exit_ids: Array = []
	var active_targets: Array = []
	var blocked_exit_count := 0
	var overlay := _context_overlay_rect(_layout_context(environment))
	var identities := interactions.keys()
	identities.sort()
	for identity_value in identities:
		var identity := str(identity_value)
		var interaction := _dict(interactions.get(identity_value, {}))
		if interaction.is_empty() or not bool(interaction.get("present", true)):
			continue
		if not _readable_text(str(interaction.get("label", "")), LABEL_MAX_LENGTH) or not _readable_text(str(interaction.get("prompt", "")), PROMPT_MAX_LENGTH):
			errors.append("Scenario interaction %s requires readable bounded label and prompt text." % identity)
		if not bool(interaction.get("enabled", false)) and not _readable_text(str(interaction.get("disabled_reason", "")), PROMPT_MAX_LENGTH):
			errors.append("Disabled scenario interaction %s requires a player-readable reason." % identity)
		if not authority.has(identity):
			errors.append("Scenario interaction %s has no exact sealed visual or base-record layout authority; raw hit rectangles cannot authorize it." % identity)
			continue
		var authority_record := _dict(authority.get(identity, {}))
		var rect := _pixel_rect(_dict(authority_record.get("normalized_hit_rect", {})))
		var small_rect := _pixel_rect(_dict(authority_record.get("small_screen_rect", {})))
		if overlay.has_area() and (rect.intersects(overlay) or small_rect.intersects(overlay) or _label_rect(rect, str(interaction.get("label", ""))).intersects(overlay) or _label_rect(small_rect, str(interaction.get("label", ""))).intersects(overlay)):
			errors.append("Scenario interaction %s collides with the reserved TalkDock overlay." % identity)
		active_targets.append({
			"identity": identity,
			"rect": rect,
			"small_rect": small_rect,
			"label_rect": _label_rect(rect, str(interaction.get("label", ""))),
			"small_label_rect": _label_rect(small_rect, str(interaction.get("label", ""))),
		})
		var reachable := _path_reachable(WALK_LANE.get_center(), rect.get_center(), obstacles, identity) and _path_reachable(WALK_LANE.get_center(), small_rect.get_center(), obstacles, identity, "small_rect")
		if not reachable:
			errors.append("Scenario interaction %s is not reachable from the player access lane." % identity)
			continue
		reachable_ids.append(identity)
		var enabled := bool(interaction.get("enabled", false))
		var actions := _array(interaction.get("available_actions", []))
		if not enabled and not actions.is_empty():
			errors.append("Disabled scenario interaction %s cannot retain action authority." % identity)
		if bool(interaction.get("safe_exit", false)):
			if enabled and not actions.is_empty():
				safe_exit_ids.append(identity)
			else:
				blocked_exit_count += 1
		elif enabled and not actions.is_empty() and bool(interaction.get("alternate_exit", false)):
			alternate_exit_ids.append(identity)
	for left_index in range(active_targets.size()):
		var left := _dict(active_targets[left_index])
		for right_index in range(left_index + 1, active_targets.size()):
			var right := _dict(active_targets[right_index])
			for rect_key in ["rect", "small_rect"]:
				var left_rect: Rect2 = left.get(rect_key, Rect2())
				var right_rect: Rect2 = right.get(rect_key, Rect2())
				if left_rect.intersects(right_rect) and left_rect.intersection(right_rect).get_area() > 0.01:
					errors.append("Scenario interactions %s and %s have ambiguous %s hit authority." % [str(left.get("identity", "")), str(right.get("identity", "")), "expanded small-screen" if rect_key == "small_rect" else "normal"])
			for label_key in ["label_rect", "small_label_rect"]:
				var left_label: Rect2 = left.get(label_key, Rect2())
				var right_label: Rect2 = right.get(label_key, Rect2())
				if left_label.intersects(right_label) and left_label.intersection(right_label).get_area() > 0.01:
					errors.append("Scenario interaction labels %s and %s overlap in %s layout." % [str(left.get("identity", "")), str(right.get("identity", "")), "expanded small-screen" if label_key == "small_label_rect" else "normal"])
	for target_value in active_targets:
		var target := _dict(target_value)
		var target_identity := str(target.get("identity", ""))
		for base_value in base_records:
			var base_record := _dict(base_value)
			var base_identity := _record_identity(base_record)
			if base_identity == target_identity or interactions.has(base_identity) or not bool(base_record.get("interactive", true)) or not bool(base_record.get("visible", true)):
				continue
			var base_rect := _record_pixel_rect(base_record)
			var base_small := _expanded_rect(base_rect, SMALL_SCREEN_TARGET)
			for pair in [[target.get("rect", Rect2()), base_rect, "normal"], [target.get("small_rect", Rect2()), base_small, "expanded small-screen"]]:
				var target_rect: Rect2 = (pair as Array)[0]
				var other_rect: Rect2 = (pair as Array)[1]
				if target_rect.intersects(other_rect) and target_rect.intersection(other_rect).get_area() > 0.01:
					errors.append("Scenario interaction %s has ambiguous %s hit authority with unrelated room control %s." % [target_identity, str((pair as Array)[2]), base_identity])
			for label_pair in [
				[target.get("label_rect", Rect2()), _label_rect(base_rect, str(base_record.get("label", ""))), "normal"],
				[target.get("small_label_rect", Rect2()), _label_rect(base_small, str(base_record.get("label", ""))), "expanded small-screen"],
			]:
				var target_label: Rect2 = (label_pair as Array)[0]
				var base_label: Rect2 = (label_pair as Array)[1]
				if target_label.intersects(base_label) and target_label.intersection(base_label).get_area() > 0.01:
					errors.append("Scenario interaction %s label overlaps unrelated room control %s in %s layout." % [target_identity, base_identity, str((label_pair as Array)[2])])
	if blocked_exit_count > 0 and safe_exit_ids.is_empty() and alternate_exit_ids.is_empty():
		errors.append("A blocked scenario exit has no readable, reachable alternate objective or exit action.")
	return {
		"reachable_interaction_ids": reachable_ids,
		"safe_exit_ids": safe_exit_ids,
		"alternate_exit_ids": alternate_exit_ids,
	}


static func _validate_visual_interaction_consistency(interactions: Dictionary, scenes: Dictionary, actors: Dictionary, errors: Array) -> void:
	for identity_value in interactions.keys():
		var identity := str(identity_value)
		var interaction := _dict(interactions.get(identity_value, {}))
		if interaction.is_empty() or not bool(interaction.get("present", true)):
			continue
		var visual := _dict(scenes.get(identity, actors.get(identity, {})))
		if visual.is_empty():
			continue
		if not bool(visual.get("visible", true)):
			errors.append("Scenario interaction %s remains present while its exact visual identity is hidden." % identity)
		if not bool(visual.get("enabled", true)) and bool(interaction.get("enabled", false)):
			errors.append("Scenario interaction %s remains actionable while its exact visual identity is disabled." % identity)


static func _validate_visual_identity_uniqueness(scenes: Dictionary, actors: Dictionary, errors: Array) -> void:
	for identity_value in scenes.keys():
		var identity := str(identity_value)
		var scene := _dict(scenes.get(identity_value, {}))
		var actor := _dict(actors.get(identity, {}))
		if not scene.is_empty() and not actor.is_empty() and bool(scene.get("present", true)) and bool(actor.get("present", true)):
			errors.append("Scenario visual identity %s cannot be both a scene object and an actor." % identity)


static func _assign_z_order(scenes: Dictionary, actors: Dictionary) -> void:
	var entries: Array = []
	for collection in [scenes, actors]:
		for identity_value in (collection as Dictionary).keys():
			var semantic := _dict((collection as Dictionary).get(identity_value, {}))
			if semantic.is_empty() or not bool(semantic.get("present", true)):
				continue
			var rect := _pixel_rect(_dict(semantic.get("normalized_hit_rect", {})))
			entries.append({"identity": str(identity_value), "collection": collection, "bottom": rect.end.y})
	entries.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left := _dict(left_value)
		var right := _dict(right_value)
		var left_bottom := float(left.get("bottom", 0.0))
		var right_bottom := float(right.get("bottom", 0.0))
		return left_bottom < right_bottom if not is_equal_approx(left_bottom, right_bottom) else str(left.get("identity", "")) < str(right.get("identity", ""))
	)
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var collection: Dictionary = entry.get("collection", {})
		var identity := str(entry.get("identity", ""))
		var semantic := _dict(collection.get(identity, {}))
		semantic["z_order"] = index
		collection[identity] = semantic


static func _add_visual_authority(authority: Dictionary, collection: Dictionary, visual_kind: String) -> void:
	for identity_value in collection.keys():
		var identity := str(identity_value)
		var semantic := _dict(collection.get(identity_value, {}))
		if semantic.is_empty() or not bool(semantic.get("present", true)) or not bool(semantic.get("layout_valid", false)):
			continue
		var existing := _dict(authority.get(identity, {}))
		var presentation_object_id := identity if identity.begins_with("scenario::") else str(existing.get("presentation_object_id", semantic.get("presentation_object_id", identity))).strip_edges()
		if presentation_object_id.is_empty():
			presentation_object_id = identity
		var presentation_visible := bool(semantic.get("visible", existing.get("presentation_visible", true)))
		var presentation_interactive := bool(existing.get("presentation_interactive", false))
		authority[identity] = _authority_record(
			identity,
			presentation_object_id,
			_dict(semantic.get("normalized_hit_rect", {})),
			_dict(semantic.get("small_screen_rect", {})),
			int(semantic.get("z_order", 0)),
			visual_kind,
			"semantic_visual",
			_array(semantic.get("route_points", [])) if visual_kind == "actor" else [],
			_dict(semantic.get("route_stage", {})) if visual_kind == "actor" else {},
			true,
			presentation_visible,
			presentation_interactive
		)


static func _base_layout_authority(base_records: Array, errors: Array = []) -> Dictionary:
	var result: Dictionary = {}
	for value in base_records:
		var record := _dict(value)
		var identity := _record_identity(record)
		var rect := _record_pixel_rect(record)
		if identity == "::" or not rect.has_area():
			continue
		if result.has(identity):
			errors.append("Base layout authority contains duplicate semantic identity %s." % identity)
			continue
		result[identity] = _authority_record(
			identity,
			str(record.get("object_id", "")).strip_edges(),
			_normalized_rect(rect),
			_normalized_rect(_expanded_rect(rect, SMALL_SCREEN_TARGET)),
			int(record.get("scenario_z_order", record.get("z_order", 0))),
			"base_record",
			"sealed_base_record",
			[],
			{},
			true,
			bool(record.get("visible", true)),
			bool(record.get("interactive", true))
		)
	return result


static func _seal_projection_coverage(authority: Dictionary, semantic_state: Dictionary, errors: Array) -> void:
	var scenes := _dict(semantic_state.get("scene_objects", {}))
	var actors := _dict(semantic_state.get("actors", {}))
	var interactions := _dict(semantic_state.get("interactions", {}))
	var identity_set: Dictionary = {}
	for collection_value in [authority, scenes, actors, interactions]:
		for identity_value in (collection_value as Dictionary).keys():
			identity_set[str(identity_value)] = true
	var identities := identity_set.keys()
	identities.sort()
	for identity_value in identities:
		var identity := str(identity_value)
		var record := _dict(authority.get(identity_value, {}))
		var scene_member := scenes.has(identity)
		var actor_member := actors.has(identity)
		var interaction_member := interactions.has(identity)
		var presence_values: Dictionary = {}
		var visual: Dictionary = {}
		for collection_value in [scenes, actors]:
			var collection := collection_value as Dictionary
			if not collection.has(identity):
				continue
			var semantic := _dict(collection.get(identity, {}))
			if semantic.is_empty():
				continue
			if typeof(semantic.get("present", true)) != TYPE_BOOL:
				errors.append("Semantic visual %s has a non-boolean presentation presence contract." % identity)
			else:
				presence_values[bool(semantic.get("present", true))] = true
			if visual.is_empty():
				visual = semantic
		var interaction := _dict(interactions.get(identity, {}))
		if not interaction.is_empty():
			if typeof(interaction.get("present", true)) != TYPE_BOOL:
				errors.append("Semantic interaction %s has a non-boolean presentation presence contract." % identity)
			else:
				presence_values[bool(interaction.get("present", true))] = true
		if presence_values.has(true) and presence_values.has(false):
			errors.append("Semantic identity %s has conflicting live and tombstoned presentation presence." % identity)
		var required := not presence_values.has(false)
		if record.is_empty():
			if required:
				errors.append("Required semantic presentation %s has no layout authority to seal." % identity)
				continue
			var tombstone_kind := "actor" if actor_member else "scene_object" if scene_member else "interaction_tombstone"
			record = _authority_record(identity, identity, {}, {}, 0, tombstone_kind, "semantic_tombstone", [], {}, false, false, false)
		var visible := bool(record.get("presentation_visible", true))
		var interactive := bool(record.get("presentation_interactive", true))
		if not visual.is_empty() and required:
			if typeof(visual.get("visible", true)) != TYPE_BOOL:
				errors.append("Semantic visual %s has a non-boolean canvas visibility contract." % identity)
			else:
				visible = bool(visual.get("visible", true))
		if not interaction.is_empty():
			interactive = required and bool(interaction.get("present", true))
		elif not visual.is_empty() and str(visual.get("owner_namespace", "")) == "scenario":
			interactive = false
		if not required:
			visible = false
			interactive = false
		record["presentation_required"] = required
		record["presentation_visible"] = visible
		record["presentation_interactive"] = interactive
		record["semantic_scene_object_member"] = scene_member
		record["semantic_actor_member"] = actor_member
		record["semantic_interaction_member"] = interaction_member
		authority[identity] = record


static func _validate_authority(authority: Dictionary, errors: Array) -> void:
	var expected_keys := ["actor_route_points", "actor_route_stage", "identity", "normalized_hit_rect", "presentation_interactive", "presentation_object_id", "presentation_required", "presentation_visible", "semantic_actor_member", "semantic_interaction_member", "semantic_scene_object_member", "small_screen_rect", "source", "visual_kind", "z_order"]
	expected_keys.sort()
	var presentation_identities: Dictionary = {}
	var identities := authority.keys()
	identities.sort()
	for identity_value in identities:
		var identity := str(identity_value)
		var record := _dict(authority.get(identity_value, {}))
		var keys := record.keys()
		keys.sort()
		if keys != expected_keys or str(record.get("identity", "")) != identity:
			errors.append("Layout authority %s is not an exact closed semantic-identity record." % identity)
			continue
		if typeof(record.get("presentation_required")) != TYPE_BOOL or typeof(record.get("presentation_visible")) != TYPE_BOOL or typeof(record.get("presentation_interactive")) != TYPE_BOOL or typeof(record.get("semantic_scene_object_member")) != TYPE_BOOL or typeof(record.get("semantic_actor_member")) != TYPE_BOOL or typeof(record.get("semantic_interaction_member")) != TYPE_BOOL:
			errors.append("Layout authority %s has a malformed sealed presentation coverage contract." % identity)
		elif not bool(record.get("presentation_required", false)) and (bool(record.get("presentation_visible", false)) or bool(record.get("presentation_interactive", false))):
			errors.append("Tombstoned layout authority %s cannot remain visible or interactive." % identity)
		var presentation_object_id := str(record.get("presentation_object_id", ""))
		if presentation_object_id.is_empty() or presentation_object_id != presentation_object_id.strip_edges():
			errors.append("Layout authority %s has no exact canvas presentation identity." % identity)
		elif identity.begins_with("scenario::") and presentation_object_id != identity:
			errors.append("Scenario layout authority %s must use its owned identity as its canvas presentation identity." % identity)
		elif presentation_object_id.contains("::") and presentation_object_id != identity and str(record.get("visual_kind", "")) != "system_failure":
			errors.append("Layout authority %s cannot alias a different owned identity as its canvas presentation identity." % identity)
		elif authority.has(presentation_object_id) and presentation_object_id != identity:
			errors.append("Layout authority %s aliases the semantic authority identity %s as a canvas presentation identity." % [identity, presentation_object_id])
		elif presentation_identities.has(presentation_object_id):
			errors.append("Layout authorities %s and %s collide on canvas presentation identity %s." % [str(presentation_identities.get(presentation_object_id, "")), identity, presentation_object_id])
		else:
			presentation_identities[presentation_object_id] = identity
		var coverage_only := not bool(record.get("presentation_required", false)) and str(record.get("source", "")) == "semantic_tombstone"
		for rect_key in ["normalized_hit_rect", "small_screen_rect"]:
			if coverage_only and _dict(record.get(rect_key, {})).is_empty():
				continue
			var rect := _pixel_rect(_dict(record.get(rect_key, {})))
			if not rect.has_area() or not Rect2(Vector2.ZERO, BOARD_SIZE).encloses(rect):
				errors.append("Layout authority %s contains invalid %s geometry." % [identity, rect_key])
		_validate_actor_route_authority(identity, record, errors)


static func _validate_actor_route_authority(identity: String, authority_record: Dictionary, errors: Array) -> void:
	var route_points := _array(authority_record.get("actor_route_points", []))
	var route_stage := _dict(authority_record.get("actor_route_stage", {}))
	if str(authority_record.get("visual_kind", "")) != "actor":
		if not route_points.is_empty() or not route_stage.is_empty():
			errors.append("Non-actor layout authority %s cannot carry route relocation authority." % identity)
		return
	if route_points.is_empty() and route_stage.is_empty():
		return
	if route_points.size() != 2:
		errors.append("Actor layout authority %s must seal exactly two route points." % identity)
		return
	var expected_stage_keys := ["duration_sec", "endpoint", "mode", "reduced_motion_endpoint", "small_screen_endpoint", "small_screen_start", "start"]
	expected_stage_keys.sort()
	var stage_keys := route_stage.keys()
	stage_keys.sort()
	if stage_keys != expected_stage_keys or str(route_stage.get("mode", "")) not in ["to_endpoint", "ping_pong"] or not _finite_number(route_stage.get("duration_sec")) or float(route_stage.get("duration_sec", 0.0)) <= 0.0:
		errors.append("Actor layout authority %s has an invalid closed route-stage contract." % identity)
		return
	for point_value in route_points + [route_stage.get("start", {}), route_stage.get("endpoint", {}), route_stage.get("reduced_motion_endpoint", {}), route_stage.get("small_screen_start", {}), route_stage.get("small_screen_endpoint", {})]:
		var point := _pixel_point(_dict(point_value))
		if not _finite_point(point) or not Rect2(Vector2.ZERO, BOARD_SIZE).has_point(point):
			errors.append("Actor layout authority %s contains an invalid routed canvas point." % identity)
			return
	if JSON.stringify(route_points[0]) != JSON.stringify(route_stage.get("start", {})) or JSON.stringify(route_points[1]) != JSON.stringify(route_stage.get("endpoint", {})) or JSON.stringify(route_points[1]) != JSON.stringify(route_stage.get("reduced_motion_endpoint", {})):
		errors.append("Actor layout authority %s route points and normal/reduced-motion endpoints diverge." % identity)
		return
	var normal_rect := _pixel_rect(_dict(authority_record.get("normalized_hit_rect", {})))
	var small_rect := _pixel_rect(_dict(authority_record.get("small_screen_rect", {})))
	var start := _pixel_point(_dict(route_points[0]))
	var endpoint := _pixel_point(_dict(route_points[1]))
	var expected_small_endpoint := _expanded_rect(Rect2(endpoint - normal_rect.size * 0.5, normal_rect.size), SMALL_SCREEN_TARGET).get_center()
	var expected_duration := clampf(start.distance_to(endpoint) / 82.0, 0.75, 8.0)
	if not start.is_equal_approx(normal_rect.get_center()) \
		or not _pixel_point(_dict(route_stage.get("small_screen_start", {}))).is_equal_approx(small_rect.get_center()) \
		or not _pixel_point(_dict(route_stage.get("small_screen_endpoint", {}))).is_equal_approx(expected_small_endpoint) \
		or not is_equal_approx(float(route_stage.get("duration_sec", 0.0)), expected_duration):
		errors.append("Actor layout authority %s route geometry or timing diverges from its sealed normal/small rectangles." % identity)


static func _authority_record(identity: String, presentation_object_id: String, normal: Dictionary, small: Dictionary, z_order: int, visual_kind: String, source: String, actor_route_points: Array = [], actor_route_stage: Dictionary = {}, presentation_required: bool = true, presentation_visible: bool = true, presentation_interactive: bool = true, semantic_scene_object_member: bool = false, semantic_actor_member: bool = false, semantic_interaction_member: bool = false) -> Dictionary:
	return {
		"actor_route_points": actor_route_points.duplicate(true),
		"actor_route_stage": actor_route_stage.duplicate(true),
		"identity": identity,
		"normalized_hit_rect": normal,
		"presentation_interactive": presentation_interactive,
		"presentation_object_id": presentation_object_id,
		"presentation_required": presentation_required,
		"presentation_visible": presentation_visible,
		"semantic_actor_member": semantic_actor_member,
		"semantic_interaction_member": semantic_interaction_member,
		"semantic_scene_object_member": semantic_scene_object_member,
		"small_screen_rect": small,
		"z_order": z_order,
		"visual_kind": visual_kind,
		"source": source,
	}


static func _authority_digest(authority: Dictionary) -> String:
	var canonical: Array = []
	var identities := authority.keys()
	identities.sort()
	for identity_value in identities:
		canonical.append(_dict(authority.get(identity_value, {})))
	return JSON.stringify(canonical).sha256_text()


static func _failed_result(projection: Dictionary, errors: Array, warnings: Array, audit: Dictionary) -> Dictionary:
	var failed_audit := audit.duplicate(true)
	failed_audit["active"] = true
	failed_audit["valid"] = false
	failed_audit["error_count"] = errors.size()
	return {
		"ok": false,
		"projection": projection.duplicate(true),
		"errors": errors.duplicate(true),
		"warnings": warnings.duplicate(true),
		"layout_authority": {},
		"layout_authority_digest": "",
		"fallback_authority": _fallback_authority(),
		"layout_audit": failed_audit,
	}


static func _fallback_authority() -> Dictionary:
	return failure_authority()


static func _has_active_presentation(semantic_state: Dictionary) -> bool:
	for key in ["interactions", "scene_objects", "actors"]:
		if not _dict(semantic_state.get(key, {})).is_empty():
			return true
	return false


static func _scenario_obstacles(scenes: Dictionary) -> Array:
	var result: Array = []
	for identity_value in scenes.keys():
		var semantic := _dict(scenes.get(identity_value, {}))
		if semantic.is_empty() or not bool(semantic.get("present", true)) or not bool(semantic.get("visible", true)):
			continue
		if str(semantic.get("role", "")).to_lower() not in ["obstacle", "barrier", "blockade"]:
			continue
		result.append({
			"identity": str(identity_value),
			"rect": _pixel_rect(_dict(semantic.get("normalized_hit_rect", {}))).grow(8.0),
			"small_rect": _pixel_rect(_dict(semantic.get("small_screen_rect", {}))).grow(8.0),
		})
	return result


static func _path_reachable(start: Vector2, endpoint: Vector2, obstacles: Array, ignored_identity: String = "", rect_key: String = "rect") -> bool:
	if not _point_clear(start, obstacles, ignored_identity, rect_key) or not _point_clear(endpoint, obstacles, ignored_identity, rect_key):
		return false
	if _segment_clear(start, endpoint, obstacles, ignored_identity, rect_key):
		return true
	var corners := [Vector2(start.x, endpoint.y), Vector2(endpoint.x, start.y)]
	for corner_value in corners:
		var corner := corner_value as Vector2
		if _point_clear(corner, obstacles, ignored_identity, rect_key) and _segment_clear(start, corner, obstacles, ignored_identity, rect_key) and _segment_clear(corner, endpoint, obstacles, ignored_identity, rect_key):
			return true
	return false


static func _segment_clear(start: Vector2, endpoint: Vector2, obstacles: Array, ignored_identity: String, rect_key: String) -> bool:
	for step in range(41):
		var point := start.lerp(endpoint, float(step) / 40.0)
		if not _point_clear(point, obstacles, ignored_identity, rect_key):
			return false
	return true


static func _point_clear(point: Vector2, obstacles: Array, ignored_identity: String, rect_key: String) -> bool:
	if not Rect2(Vector2.ZERO, BOARD_SIZE).has_point(point):
		return false
	for value in obstacles:
		var obstacle := _dict(value)
		if str(obstacle.get("identity", "")) == ignored_identity:
			continue
		var rect: Rect2 = obstacle.get(rect_key, Rect2())
		if rect.has_point(point):
			return false
	return true


static func _collision_safe_rect(identity: String, authored: Rect2, occupied: Array) -> Dictionary:
	for offset_value in COLLISION_OFFSETS:
		var offset := offset_value as Vector2
		var candidate := _clamp_inside_board(Rect2(authored.position + offset, authored.size))
		var small_candidate := _expanded_rect(candidate, SMALL_SCREEN_TARGET)
		if not _substantially_overlaps(identity, candidate, occupied) and not _expanded_overlaps(identity, small_candidate, occupied):
			return {"rect": candidate, "adjusted": not offset.is_zero_approx(), "colliding": false}
	return {"rect": authored, "adjusted": false, "colliding": true}


static func _substantially_overlaps(identity: String, rect: Rect2, occupied: Array) -> bool:
	for occupied_value in occupied:
		var occupied_record := _dict(occupied_value)
		if str(occupied_record.get("identity", "")) == identity:
			continue
		var other: Rect2 = occupied_record.get("rect", Rect2())
		if not other.has_area():
			continue
		var overlap := rect.intersection(other).get_area()
		if overlap > minf(rect.get_area(), other.get_area()) * COLLISION_RATIO:
			return true
	return false


static func _expanded_overlaps(identity: String, rect: Rect2, occupied: Array) -> bool:
	for occupied_value in occupied:
		var occupied_record := _dict(occupied_value)
		if str(occupied_record.get("identity", "")) == identity:
			continue
		var other: Rect2 = occupied_record.get("small_rect", Rect2())
		if not other.has_area():
			other = _expanded_rect(occupied_record.get("rect", Rect2()), SMALL_SCREEN_TARGET)
		if rect.intersects(other) and rect.intersection(other).get_area() > 0.01:
			return true
	return false


static func _overlap_count(authority: Dictionary, rect_key: String) -> int:
	var count := 0
	var identities := authority.keys()
	identities.sort()
	for left_index in range(identities.size()):
		var left := _pixel_rect(_dict(_dict(authority.get(identities[left_index], {})).get(rect_key, {})))
		for right_index in range(left_index + 1, identities.size()):
			var right := _pixel_rect(_dict(_dict(authority.get(identities[right_index], {})).get(rect_key, {})))
			if left.intersects(right) and left.intersection(right).get_area() > 0.01:
				count += 1
	return count


static func _actor_route_count(actors: Dictionary) -> int:
	var count := 0
	for value in actors.values():
		if not _array(_dict(value).get("route_points", [])).is_empty():
			count += 1
	return count


static func _layout_context(environment: Dictionary) -> Dictionary:
	return _dict(environment.get("_scenario_layout_context", environment.get("scenario_layout_context", {})))


static func _validate_layout_context(context: Dictionary, errors: Array) -> void:
	if context.is_empty():
		return
	for key in ["small_screen_mode", "reduce_motion", "production_canvas"]:
		if context.has(key) and typeof(context.get(key)) != TYPE_BOOL:
			errors.append("Scenario production layout setting %s must be boolean." % key)
	var overlay := _context_overlay_rect(context)
	if context.has("reserved_overlay_board_rect") and (not overlay.has_area() or not Rect2(Vector2.ZERO, BOARD_SIZE).encloses(overlay)):
		var raw_overlay := _dict(context.get("reserved_overlay_board_rect", {}))
		if not raw_overlay.is_empty() and (float(raw_overlay.get("w", 0.0)) > 0.0 or float(raw_overlay.get("h", 0.0)) > 0.0):
			errors.append("Scenario production reserved-overlay geometry must be finite and board-bounded.")


static func _context_overlay_rect(context: Dictionary) -> Rect2:
	return _normalized_or_pixel_rect(context.get("reserved_overlay_board_rect", context.get("reserved_overlay_rect", {})))


static func _label_rect(rect: Rect2, label: String) -> Rect2:
	var text := label.strip_edges()
	if text.is_empty():
		return Rect2()
	var width := minf(maxf(48.0, float(text.length()) * 5.8 + 12.0), LABEL_MAX_WIDTH)
	var y := rect.position.y - LABEL_HEIGHT - LABEL_GAP
	if y < 16.0:
		y = rect.end.y + LABEL_GAP
	return _clamp_label_inside_board(Rect2(Vector2(rect.get_center().x - width * 0.5, y), Vector2(width, LABEL_HEIGHT)))


static func _clamp_label_inside_board(rect: Rect2) -> Rect2:
	var margin := 16.0
	var position := Vector2(
		clampf(rect.position.x, margin, BOARD_SIZE.x - margin),
		clampf(rect.position.y, margin, BOARD_SIZE.y - margin)
	)
	var end := Vector2(
		clampf(rect.end.x, margin, BOARD_SIZE.x - margin),
		clampf(rect.end.y, margin, BOARD_SIZE.y - margin)
	)
	return Rect2(position, Vector2(maxf(0.0, end.x - position.x), maxf(0.0, end.y - position.y)))


static func _readable_text(value: String, maximum_length: int) -> bool:
	var text := value.strip_edges()
	if text.is_empty() or text.length() > maximum_length:
		return false
	for index in range(text.length()):
		if text.unicode_at(index) < 32:
			return false
	return true


static func _resolve_center(environment: Dictionary, anchor_id: String, zone_id: String) -> Vector2:
	var anchors := _dict(environment.get("semantic_anchors", {}))
	var zones := _dict(environment.get("semantic_zones", {}))
	if not anchor_id.is_empty() and anchors.has(anchor_id):
		return _point(_dict(anchors.get(anchor_id, {})).get("position", []))
	if not zone_id.is_empty() and zones.has(zone_id):
		var zone_rect := _pixel_bounds(_dict(zones.get(zone_id, {})).get("bounds", []))
		if zone_rect.has_area():
			return zone_rect.get_center()
	var layout := _dict(environment.get("layout", environment))
	var object_rects := _dict(layout.get("object_rects", {}))
	if not anchor_id.is_empty() and object_rects.has(anchor_id):
		var object_rect := _normalized_or_pixel_rect(object_rects.get(anchor_id, {}))
		if object_rect.has_area():
			return object_rect.get_center()
	if anchor_id.begins_with("layout:"):
		var parts := anchor_id.split(":", false)
		if parts.size() == 3 and LAYOUT_SPOT_FIELDS.has(str(parts[1])) and str(parts[2]).is_valid_int():
			var spots := _array(layout.get(str(LAYOUT_SPOT_FIELDS.get(str(parts[1]), "")), []))
			var index := int(parts[2])
			if index >= 0 and index < spots.size():
				return _point(spots[index])
	return Vector2(-1.0, -1.0)


static func _resolve_route_center(environment: Dictionary, semantic_state: Dictionary, route_id: String) -> Vector2:
	var routes := _dict(semantic_state.get("routes", {}))
	var route := _dict(routes.get(route_id, {}))
	for candidate_value in [str(route.get("source_id", "")), str(route.get("stable_object_id", "")), route_id.get_slice("::", 1)]:
		var candidate := str(candidate_value)
		var center := _resolve_center(environment, candidate, candidate)
		if center.x >= 0.0:
			return center
	return Vector2(-1.0, -1.0)


static func _base_records_by_identity(base_records: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in base_records:
		var record := _dict(value)
		var identity := _record_identity(record)
		if identity != "::":
			result[identity] = record
	return result


static func _base_occupied_records(base_records: Array) -> Array:
	var result: Array = []
	for value in base_records:
		var record := _dict(value)
		var rect := _record_pixel_rect(record)
		if not rect.has_area():
			continue
		result.append({"identity": _record_identity(record), "rect": rect, "small_rect": _expanded_rect(rect, SMALL_SCREEN_TARGET)})
	return result


static func _record_identity(record: Dictionary) -> String:
	return "%s::%s" % [str(record.get("owner_namespace", "")), str(record.get("stable_object_id", ""))]


static func _record_pixel_rect(record: Dictionary) -> Rect2:
	if record.is_empty():
		return Rect2()
	return _normalized_or_pixel_rect(record.get("focus_rect", record.get("normalized_rect", {})))


static func _normalized_or_pixel_rect(value: Variant) -> Rect2:
	var rect := _rect(value)
	if not _finite_point(rect.position) or not _finite_point(rect.size) or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Rect2()
	if rect.position.x <= 1.0 and rect.position.y <= 1.0 and rect.size.x <= 1.0 and rect.size.y <= 1.0:
		return Rect2(rect.position * BOARD_SIZE, rect.size * BOARD_SIZE)
	return rect


static func _pixel_bounds(value: Variant) -> Rect2:
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 4:
		return Rect2(float((value as Array)[0]), float((value as Array)[1]), float((value as Array)[2]), float((value as Array)[3]))
	return _normalized_or_pixel_rect(value)


static func _clamp_inside_board(rect: Rect2) -> Rect2:
	var size := Vector2(minf(rect.size.x, BOARD_SIZE.x), minf(rect.size.y, BOARD_SIZE.y))
	var position := Vector2(clampf(rect.position.x, 0.0, BOARD_SIZE.x - size.x), clampf(rect.position.y, 0.0, BOARD_SIZE.y - size.y))
	return Rect2(position, size)


static func _expanded_rect(rect: Rect2, minimum: Vector2) -> Rect2:
	if not rect.has_area():
		return Rect2()
	var size := Vector2(maxf(rect.size.x, minimum.x), maxf(rect.size.y, minimum.y))
	return _clamp_inside_board(Rect2(rect.get_center() - size * 0.5, size))


static func _normalized_rect(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x / BOARD_SIZE.x, "y": rect.position.y / BOARD_SIZE.y, "w": rect.size.x / BOARD_SIZE.x, "h": rect.size.y / BOARD_SIZE.y}


static func _pixel_rect(value: Dictionary) -> Rect2:
	return Rect2(float(value.get("x", 0.0)) * BOARD_SIZE.x, float(value.get("y", 0.0)) * BOARD_SIZE.y, float(value.get("w", 0.0)) * BOARD_SIZE.x, float(value.get("h", 0.0)) * BOARD_SIZE.y)


static func _normalized_point(point: Vector2) -> Dictionary:
	return {"x": point.x / BOARD_SIZE.x, "y": point.y / BOARD_SIZE.y}


static func _pixel_point(point: Dictionary) -> Vector2:
	return Vector2(float(point.get("x", -1.0)) * BOARD_SIZE.x, float(point.get("y", -1.0)) * BOARD_SIZE.y)


static func _size_snapshot(value: Vector2) -> Dictionary:
	return {"w": value.x, "h": value.y}


static func _rect_snapshot(value: Rect2) -> Dictionary:
	return {"x": value.position.x, "y": value.position.y, "w": value.size.x, "h": value.size.y}


static func _finite_point(point: Vector2) -> bool:
	return is_finite(point.x) and is_finite(point.y)


static func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _valid_sha256(value: String) -> bool:
	if value.length() != 64 or value != value.to_lower():
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return false
	return true


static func _point(value: Variant) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value as Vector2
	if typeof(value) == TYPE_VECTOR2I:
		return Vector2(value as Vector2i)
	if typeof(value) == TYPE_ARRAY and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2(float((value as Dictionary).get("x", -1.0)), float((value as Dictionary).get("y", -1.0)))
	return Vector2(-1.0, -1.0)


static func _rect(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value as Rect2
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data := value as Dictionary
	return Rect2(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("w", 0.0)), float(data.get("h", 0.0)))


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
