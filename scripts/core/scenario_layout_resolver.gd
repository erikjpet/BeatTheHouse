class_name ScenarioLayoutResolver
extends RefCounted

const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")

const ArtContractsScript := preload("res://scripts/core/art_contracts.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const EnvironmentSemanticInventoryScript := preload("res://scripts/core/environment_semantic_inventory.gd")
const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")

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
	var response := {
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
	if not errors.is_empty():
		for key in ["visual_objects", "interaction_overlays", "services", "games", "routes", "active_stages"]:
			response[key] = []
		var failed_audit := _dict(response.get("layout_audit", {}))
		failed_audit["visual_count"] = 0
		failed_audit["interaction_count"] = 0
		response["layout_audit"] = failed_audit
	return response


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
		var route_resolution := _resolve_route_center_result(environment, semantic_state, str(semantic.get("route_id", "")))
		var route_center: Vector2 = route_resolution.get("center", Vector2(-1.0, -1.0))
		if bool(route_resolution.get("ok", false)) and _finite_point(route_center) and route_center.x >= 0.0:
			route_points = [_normalized_point(center), _normalized_point(route_center)]
		else:
			errors.append("Scenario actor %s references an unresolved route: %s" % [identity, str(route_resolution.get("error", "unknown route endpoint"))])
	var rect := _clamp_inside_board(Rect2(center - size * 0.5, size))
	var owner := str(semantic.get("owner_namespace", ""))
	var stable_id := str(semantic.get("stable_object_id", ""))
	return {
		"object_id": "scenario:%s:%s" % [owner, stable_id],
		"object_type": "scenario_actor" if actor else "scenario_object",
		"visual_type": "scenario_actor" if actor else "scenario_object",
		"source_id": str(semantic.get("actor_id", stable_id)),
		"label": label,
		"short_description": _scenario_description(semantic),
		"icon_key": _scenario_icon_key(semantic),
		"presence": "scenario",
		"interactive": true,
		"decorative": false,
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


static func _scenario_description(semantic: Dictionary) -> String:
	var description := str(semantic.get("description", "")).strip_edges()
	var variants := _dict(semantic.get("description_variants", {}))
	for key in [str(semantic.get("state", "")), str(semantic.get("appearance", "")), str(semantic.get("pose", "")), str(semantic.get("behavior", "")), str(semantic.get("anchor_id", "")), str(semantic.get("zone_id", ""))]:
		var variant := str(variants.get(key, "")).strip_edges()
		if not variant.is_empty():
			return variant
	return description


static func _scenario_icon_key(semantic: Dictionary) -> String:
	var authored_icon := str(semantic.get("icon_key", "")).strip_edges()
	if not authored_icon.is_empty():
		return authored_icon
	var semantic_kind := str(semantic.get("semantic_kind", "scene_object")).strip_edges()
	return "%s %s %s" % [
		"scenario_actor" if semantic_kind == "actor" else "scenario_scene",
		str(semantic.get("label", "")).strip_edges(),
		str(semantic.get("role", "")).strip_edges(),
	]


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
	var layout_audit := _dict(layout_result.get("layout_audit", {}))
	var sealed_passive := not bool(layout_audit.get("active", true))
	if not JsonCoerceScript._valid_sha256(authority_digest) or _authority_digest(authority) != authority_digest:
		return {"ok": false, "errors": ["Scenario renderer authority digest is missing or stale."]}
	if sealed_passive and (not authority.is_empty() or _has_active_presentation(semantic_state)):
		return {"ok": false, "errors": ["Scenario passive renderer snapshot contains active presentation authority."]}
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
				"short_description": _scenario_description(semantic),
				"icon_key": _scenario_icon_key(semantic),
				"presence": "scenario",
				"interactive": true,
				"decorative": false,
				"enabled": bool(semantic.get("enabled", true)),
				"visible": bool(sealed.get("presentation_visible", true)),
				"normalized_rect": _dict(sealed.get("normalized_hit_rect", {})),
				"focus_rect": _dict(sealed.get("normalized_hit_rect", {})),
				"small_screen_rect": _dict(sealed.get("small_screen_rect", {})),
				"label_rect": _dict(sealed.get("label_rect", {})),
				"small_screen_label_rect": _dict(sealed.get("small_screen_label_rect", {})),
				"fixed_slot_geometry": true,
				"owner_namespace": str(semantic.get("owner_namespace", "")),
				"stable_object_id": str(semantic.get("stable_object_id", "")),
				"semantic_identity": identity,
				"role": str(semantic.get("role", "actor" if actor else "prop")),
				"placement_class": str(semantic.get("placement_class", "")),
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
		"presentation_mode": "passive" if sealed_passive else "active",
		"sealed_passive": sealed_passive,
		"warnings": _array(layout_result.get("warnings", [])),
		"visual_objects": visuals,
		"interaction_overlays": _ordered_semantic_values(_dict(semantic_state.get("interactions", {}))),
		"services": _ordered_semantic_values(_dict(semantic_state.get("services", {}))),
		"games": _ordered_semantic_values(_dict(semantic_state.get("games", {}))),
		"routes": _ordered_semantic_values(_dict(semantic_state.get("routes", {}))),
		"active_stages": _array(projection.get("active_stages", [])),
		"layout_authority": authority,
		"layout_authority_digest": authority_digest,
		"layout_audit": layout_audit,
	}


static func resolve(base_records: Array, projection: Dictionary, environment: Dictionary = {}) -> Dictionary:
	var semantic_state := _dict(projection.get("semantic_state", {}))
	var resolved_projection := projection.duplicate(true)
	var passive_audit := {
		"active": false,
		"valid": true,
		"visual_count": 0,
		"collision_adjustment_count": 0,
		"board_size": _size_snapshot(BOARD_SIZE),
		"small_screen_target": _size_snapshot(SMALL_SCREEN_TARGET),
	}
	if not _has_active_presentation(semantic_state):
		var passive_authority: Dictionary = {}
		var passive_digest := _authority_digest(passive_authority)
		semantic_state["layout_authority_digest"] = passive_digest
		resolved_projection["semantic_state"] = semantic_state
		passive_audit["sealed_passive"] = true
		passive_audit["authority_count"] = 0
		passive_audit["authority_digest"] = passive_digest
		return {
			"ok": true,
			"projection": resolved_projection,
			"errors": [],
			"warnings": [],
			"layout_authority": passive_authority,
			"layout_authority_digest": passive_digest,
			"fallback_authority": _fallback_authority(),
			"layout_audit": passive_audit,
		}
	if environment.is_empty():
		return _failed_result(resolved_projection, ["An active scenario presentation requires the current validated room layout."], [], passive_audit)
	# Runtime refresh and composed world-sequence callers can legitimately pass a
	# room snapshot before its scenario fields have been reattached. The active
	# projection is the authoritative scenario identity for placement overrides.
	environment = environment.duplicate(false)
	var errors: Array = []
	var warnings: Array = []
	var context := _layout_context(environment)
	var occupied := _base_occupied_records(base_records)
	var context_base_occupied := _context_base_occupied_records(context, base_records, errors)
	occupied.append_array(context_base_occupied)
	var base_by_identity := _base_records_by_identity(base_records)
	# TalkDock is transient modal/input geometry. It may cover immutable room
	# slots while open, but it must never relocate them or invalidate their seal.
	# The dock blocks underlying input and the same controls recover on close.
	var authority := _base_layout_authority(base_records, errors, environment)
	var collision_adjustments := 0
	var visual_count := 0
	var resolved_scenes: Dictionary = {}
	var resolved_actors: Dictionary = {}
	var interactions := _dict(semantic_state.get("interactions", {}))
	var placement_queue: Array = []
	for collection_entry in [[semantic_state.get("scene_objects", {}), false], [semantic_state.get("actors", {}), true]]:
		var collection := _dict((collection_entry as Array)[0])
		var actor := bool((collection_entry as Array)[1])
		for identity_value in collection.keys():
			var identity := str(identity_value)
			var semantic := _dict(collection.get(identity_value, {}))
			var classified_semantic := semantic.duplicate(true)
			var class_overrides := _dict(EnvironmentPlacementScript.surface_map(environment).get("class_overrides", {}))
			var stable_identity := identity.trim_prefix("scenario::")
			var class_override := str(class_overrides.get(identity, class_overrides.get(stable_identity, "")))
			if class_override in EnvironmentPlacementScript.CLASSES:
				classified_semantic["placement_class"] = class_override
			var placement_class := EnvironmentPlacementScript.classify(classified_semantic, "actor" if actor else "scene_object", identity, str(semantic.get("prop", semantic.get("icon_key", ""))))
			var interaction := _dict(interactions.get(identity, {}))
			if bool(interaction.get("safe_exit", false)):
				placement_class = "doorway"
				classified_semantic["placement_class"] = placement_class
			placement_queue.append({
				"identity": identity,
				"semantic": classified_semantic,
				"actor": actor,
				"placement_class": placement_class,
				"safe_exit": bool(interaction.get("safe_exit", false)),
			})
	placement_queue.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left := _dict(left_value)
		var right := _dict(right_value)
		var left_priority := _placement_class_priority(str(left.get("placement_class", "")))
		var right_priority := _placement_class_priority(str(right.get("placement_class", "")))
		if left_priority != right_priority:
			return left_priority < right_priority
		var left_area := _semantic_visual_area(_dict(left.get("semantic", {})), bool(left.get("actor", false)))
		var right_area := _semantic_visual_area(_dict(right.get("semantic", {})), bool(right.get("actor", false)))
		return str(left.get("identity", "")) < str(right.get("identity", "")) if is_equal_approx(left_area, right_area) else left_area > right_area
	)
	var placement_result := _resolve_visual_queue(placement_queue, environment, semantic_state, base_by_identity, occupied, interactions)
	resolved_scenes = _dict(placement_result.get("scenes", {}))
	resolved_actors = _dict(placement_result.get("actors", {}))
	occupied = _array(placement_result.get("occupied", occupied))
	collision_adjustments = int(placement_result.get("collision_adjustments", 0))
	visual_count = int(placement_result.get("visual_count", 0))
	errors.append_array(_array(placement_result.get("errors", [])))

	semantic_state["scene_objects"] = resolved_scenes
	semantic_state["actors"] = resolved_actors
	_validate_visual_identity_uniqueness(resolved_scenes, resolved_actors, errors)
	_assign_z_order(resolved_scenes, resolved_actors)
	var obstacles := _scenario_obstacles(resolved_scenes)
	_validate_visual_access(resolved_scenes, resolved_actors, obstacles, _dict(semantic_state.get("interactions", {})), base_records, environment, errors)
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
		"production_canvas": context.get("production_canvas", false) if typeof(context.get("production_canvas", false)) == TYPE_BOOL else false,
		"small_screen_mode": context.get("small_screen_mode", false) if typeof(context.get("small_screen_mode", false)) == TYPE_BOOL else false,
		"reduce_motion": context.get("reduce_motion", false) if typeof(context.get("reduce_motion", false)) == TYPE_BOOL else false,
		"authority_count": authority.size(),
		"context_base_occupied_count": context_base_occupied.size(),
		"authority_digest": authority_digest,
		"reachable_interaction_ids": interaction_audit.get("reachable_interaction_ids", []),
		"safe_exit_ids": interaction_audit.get("safe_exit_ids", []),
		"alternate_exit_ids": interaction_audit.get("alternate_exit_ids", []),
		"actor_route_count": _actor_route_count(resolved_actors),
		"normal_overlap_count": _overlap_count(authority, "normalized_hit_rect", environment),
		"small_screen_overlap_count": _overlap_count(authority, "small_screen_rect", environment),
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


static func failure_authority(_base_records: Array = []) -> Dictionary:
	var authored := Rect2(300.0, 24.0, 300.0, 76.0)
	var rect := authored
	return _authority_record(FunctionOptions.ScenarioAuthorityRecordOptions.from({
		"identity": "system::scenario_presentation_failure",
		"presentation_object_id": "scenario::presentation_failure",
		"normal": _normalized_rect(rect),
		"small": _normalized_rect(_expanded_rect(rect, SMALL_SCREEN_TARGET)),
		"label_rect": _normalized_rect(_label_rect(rect, "Scenario unavailable")),
		"small_label_rect": _normalized_rect(_label_rect(rect, "Scenario unavailable")),
		"z_order": MAX_VISUALS + 1,
		"visual_kind": "system_failure",
		"source": "trusted_runtime_fallback",
	}))


static func _resolve_visual_queue(queue: Array, environment: Dictionary, semantic_state: Dictionary, base_by_identity: Dictionary, initial_occupied: Array, interactions: Dictionary) -> Dictionary:
	var queue_errors: Array = []
	var occupied := initial_occupied.duplicate(true)
	var scenes: Dictionary = {}
	var actors: Dictionary = {}
	var visual_count := 0
	var bind_entries: Array = []
	for queue_value in queue:
		var queue_entry := _dict(queue_value)
		var identity := str(queue_entry.get("identity", ""))
		var base_record := _dict(base_by_identity.get(identity, {}))
		# Exact ordinary room identities keep their already-authored base slot.
		# Scenario-owned visuals and routed actors bind to the stage/exit authority.
		var semantic := _dict(queue_entry.get("semantic", {}))
		if not _record_pixel_rect(base_record).has_area() or not str(semantic.get("route_id", "")).is_empty():
			bind_entries.append(queue_entry)
	var binding_result := EnvironmentSlotBinderScript.bind_scenario_visuals(environment, bind_entries)
	if not bool(binding_result.get("ok", false)):
		queue_errors.append_array(_array(binding_result.get("errors", ["Scenario fixed-slot binding failed closed."])))
	var bindings := _dict(binding_result.get("slot_bindings", {}))
	for queue_value in queue:
		var queue_entry := _dict(queue_value)
		var identity := str(queue_entry.get("identity", ""))
		var semantic := _dict(queue_entry.get("semantic", {}))
		var actor := bool(queue_entry.get("actor", false))
		var destination := actors if actor else scenes
		if semantic.is_empty():
			continue
		if not bool(semantic.get("present", true)):
			destination[identity] = semantic
			continue
		visual_count += 1
		if visual_count > MAX_VISUALS:
			queue_errors.append("Scenario presentation exceeds the %d visual-object bound." % MAX_VISUALS)
			continue
		var interaction := _dict(interactions.get(identity, {}))
		var visual_label := str(semantic.get("label", "")).strip_edges()
		var interaction_label := str(interaction.get("label", "")).strip_edges()
		var placement_label := interaction_label if interaction_label.length() > visual_label.length() else visual_label
		var resolved := _resolve_fixed_visual(
			identity,
			semantic,
			actor,
			environment,
			_dict(base_by_identity.get(identity, {})),
			_dict(bindings.get(identity, {})),
			str(queue_entry.get("placement_class", "")),
			queue_errors
		)
		if resolved.is_empty():
			continue
		resolved["layout_valid"] = true
		destination[identity] = resolved
		if bool(resolved.get("visible", true)) and str(resolved.get("presentation_mode", "room")) == "room":
			occupied.append({
				"identity": identity,
				"rect": _pixel_rect(_dict(resolved.get("normalized_hit_rect", {}))),
				"small_rect": _pixel_rect(_dict(resolved.get("small_screen_rect", {}))),
				"label": placement_label,
			})
	return {
		"scenes": scenes,
		"actors": actors,
		"occupied": occupied,
		"collision_adjustments": 0,
		"visual_count": visual_count,
		"errors": queue_errors,
	}


static func _resolve_fixed_visual(
	identity: String,
	semantic: Dictionary,
	actor: bool,
	environment: Dictionary,
	base_record: Dictionary,
	binding: Dictionary,
	placement_class: String,
	errors: Array
) -> Dictionary:
	var result := semantic.duplicate(true)
	var label := str(semantic.get("label", base_record.get("label", "")))
	if not _readable_text(label, LABEL_MAX_LENGTH):
		errors.append("Scenario visual %s requires a bounded, readable label." % identity)
		return {}
	if placement_class not in EnvironmentPlacementScript.CLASSES:
		placement_class = EnvironmentPlacementScript.classify(semantic, "actor" if actor else "scene_object", identity, str(semantic.get("prop", semantic.get("icon_key", ""))))
	var pixel_rect := _record_pixel_rect(base_record)
	var label_rect := _pixel_rect(_dict(base_record.get("label_rect", {})))
	var small_label_rect := _pixel_rect(_dict(base_record.get("small_screen_label_rect", {})))
	var presentation_mode := str(base_record.get("presentation_mode", "room")) if not base_record.is_empty() else str(binding.get("presentation_mode", "overflow"))
	var slot_id := str(base_record.get("slot_id", "")) if not base_record.is_empty() else str(binding.get("slot_id", ""))
	if not binding.is_empty() and (not str(semantic.get("route_id", "")).is_empty() or not pixel_rect.has_area()):
		presentation_mode = str(binding.get("presentation_mode", "overflow"))
		slot_id = str(binding.get("slot_id", ""))
		pixel_rect = EnvironmentSlotBinderScript.rect_from_binding(binding)
		label_rect = EnvironmentSlotBinderScript.label_rect_from_binding(binding, label)
		small_label_rect = label_rect
	if presentation_mode == "room" and not pixel_rect.has_area():
		errors.append("Scenario visual %s has a room binding without authored slot geometry." % identity)
		return {}
	var route_points: Array = []
	var route_stage: Dictionary = {}
	var route_id := str(semantic.get("route_id", "")).strip_edges()
	if route_id.is_empty():
		route_id = str(binding.get("route_id", "")).strip_edges()
	if actor and presentation_mode == "room" and not route_id.is_empty():
		var route := _dict(binding.get("route", {}))
		var start_slot := _slot_by_id(environment, str(route.get("start_slot_id", "")))
		var end_slot := _slot_by_id(environment, str(route.get("end_slot_id", "")))
		if route.is_empty() or start_slot.is_empty() or end_slot.is_empty():
			errors.append("Scenario actor %s route %s has no authored slot route." % [identity, route_id])
			return {}
		var start_rect := EnvironmentSlotBinderScript.rect_from_binding({"slot": start_slot})
		var endpoint_rect := EnvironmentSlotBinderScript.rect_from_binding({"slot": end_slot})
		var start := start_rect.get_center()
		var endpoint := endpoint_rect.get_center()
		var route_pixel_points := EnvironmentSlotBinderScript.authored_route_points(
			EnvironmentPlacementScript.surface_map(environment),
			start_slot,
			end_slot,
			_array(route.get("lane_ids", []))
		)
		if route_pixel_points.size() < 2 \
				or not route_pixel_points.front().is_equal_approx(start) \
				or not route_pixel_points.back().is_equal_approx(endpoint):
			errors.append("Scenario actor %s route %s could not slice its authored lane between endpoint slots." % [identity, route_id])
			return {}
		var route_distance := 0.0
		for index in range(route_pixel_points.size()):
			route_points.append(_normalized_point(route_pixel_points[index]))
			if index > 0:
				route_distance += route_pixel_points[index - 1].distance_to(route_pixel_points[index])
		var behavior := str(semantic.get("behavior", "idle"))
		route_stage = {
			"mode": "ping_pong" if behavior == "patrol" or str(route.get("motion", "")) == "ping_pong" else "to_endpoint",
			"duration_sec": clampf(route_distance / 82.0, 0.75, 8.0),
			"reduced_motion_endpoint": _normalized_point(endpoint),
			"start": _normalized_point(start),
			"endpoint": _normalized_point(endpoint),
			"small_screen_start": _normalized_point(_expanded_rect(pixel_rect, SMALL_SCREEN_TARGET).get_center()),
			"small_screen_endpoint": _normalized_point(_expanded_rect(endpoint_rect, SMALL_SCREEN_TARGET).get_center()),
		}
	result["present"] = true
	result["semantic_kind"] = "actor" if actor else "scene_object"
	result["normalized_hit_rect"] = _normalized_rect(pixel_rect) if presentation_mode == "room" else {}
	result["small_screen_rect"] = _normalized_rect(_expanded_rect(pixel_rect, SMALL_SCREEN_TARGET)) if presentation_mode == "room" else {}
	result["label_rect"] = _normalized_rect(label_rect) if presentation_mode == "room" else {}
	result["small_screen_label_rect"] = _normalized_rect(small_label_rect) if presentation_mode == "room" else {}
	result["resolved_bounds"] = {"w": pixel_rect.size.x, "h": pixel_rect.size.y} if presentation_mode == "room" else {}
	result["collision_adjusted"] = false
	result["placement_spacing_warning"] = false
	result["zone_surface_adjusted"] = false
	result["placement_class"] = placement_class
	result["contact"] = _placement_contact(placement_class)
	result["presentation_mode"] = presentation_mode
	result["slot_id"] = slot_id
	result["route_id"] = route_id
	result["route_points"] = route_points
	result["route_stage"] = route_stage
	result["visible"] = bool(result.get("visible", true))
	result["enabled"] = bool(result.get("enabled", true))
	return result


static func _slot_by_id(environment: Dictionary, slot_id: String) -> Dictionary:
	if slot_id.is_empty():
		return {}
	var surface_map := EnvironmentPlacementScript.surface_map(environment)
	for field in ["base_slots", "stage_slots", "exit_slots"]:
		for value in _array(surface_map.get(field, [])):
			var slot := _dict(value)
			if str(slot.get("id", "")) == slot_id:
				return slot
	return {}


static func _validate_visual_access(scenes: Dictionary, actors: Dictionary, obstacles: Array, interactions: Dictionary, base_records: Array, environment: Dictionary, errors: Array) -> void:
	var normal_labels: Array = []
	var small_labels: Array = []
	for base_value in base_records:
		var base_record := _dict(base_value)
		var base_identity := _record_identity(base_record)
		if not bool(base_record.get("visible", true)) or str(base_record.get("presentation_mode", "room")) == "overflow" or scenes.has(base_identity) or actors.has(base_identity):
			continue
		var base_rect := _record_pixel_rect(base_record)
		var base_small := _record_small_rect(base_record)
		normal_labels.append({"identity": base_identity, "rect": _record_label_rect(base_record), "target_rect": base_rect})
		small_labels.append({"identity": base_identity, "rect": _record_label_rect(base_record, true), "target_rect": base_small})
	for collection in [scenes, actors]:
		var identities := (collection as Dictionary).keys()
		identities.sort()
		for identity_value in identities:
			var identity := str(identity_value)
			var semantic := _dict((collection as Dictionary).get(identity_value, {}))
			if semantic.is_empty() or not bool(semantic.get("present", true)) or not bool(semantic.get("visible", true)) or str(semantic.get("presentation_mode", "room")) == "overflow":
				continue
			var rect := _pixel_rect(_dict(semantic.get("normalized_hit_rect", {})))
			var small_rect := _pixel_rect(_dict(semantic.get("small_screen_rect", {})))
			var label_rect := _pixel_rect(_dict(semantic.get("label_rect", {})))
			var small_label_rect := _pixel_rect(_dict(semantic.get("small_screen_label_rect", {})))
			normal_labels.append({"identity": identity, "rect": label_rect, "target_rect": rect})
			small_labels.append({"identity": identity, "rect": small_label_rect, "target_rect": small_rect})
			var role := str(semantic.get("role", "")).to_lower()
			if role in ["obstacle", "barrier", "blockade"] and (rect.intersects(WALK_LANE) or small_rect.intersects(WALK_LANE)):
				errors.append("Scenario obstacle %s blocks the mandatory player access lane in normal or expanded small-screen layout." % identity)
	_validate_label_entries(normal_labels, "normal", errors)
	_validate_label_entries(small_labels, "expanded small-screen", errors)
	if not obstacles.is_empty() and not _room_path_reachable(obstacles):
		errors.append("Scenario obstruction leaves no reachable route from the player access lane into the room.")
	if not obstacles.is_empty() and not _room_path_reachable(obstacles, "small_rect"):
		errors.append("Expanded small-screen scenario obstruction leaves no reachable route from the player access lane into the room.")


static func _room_path_reachable(obstacles: Array, rect_key: String = "rect") -> bool:
	# The room is an area, not the single center pixel. Prove that at least one
	# interior approach remains reachable when a legitimate fixture occupies the
	# center, while a complete blockade still fails every target.
	for goal in [
		Vector2(BOARD_SIZE.x * 0.5, BOARD_SIZE.y * 0.5),
		Vector2(BOARD_SIZE.x * 0.35, BOARD_SIZE.y * 0.5),
		Vector2(BOARD_SIZE.x * 0.65, BOARD_SIZE.y * 0.5),
		Vector2(BOARD_SIZE.x * 0.5, BOARD_SIZE.y * 0.35),
	]:
		if _path_reachable(WALK_LANE.get_center(), goal, obstacles, "", rect_key):
			return true
	return false


static func _validate_label_entries(entries: Array, layout_label: String, errors: Array) -> void:
	for left_index in range(entries.size()):
		var left := _dict(entries[left_index])
		var left_label: Rect2 = left.get("rect", Rect2())
		if not left_label.has_area():
			errors.append("Layout label %s has no authored %s rectangle." % [str(left.get("identity", "")), layout_label])
			continue
		for right_index in range(left_index + 1, entries.size()):
			var right := _dict(entries[right_index])
			var right_label: Rect2 = right.get("rect", Rect2())
			var left_target: Rect2 = left.get("target_rect", Rect2())
			var right_target: Rect2 = right.get("target_rect", Rect2())
			if left_label.intersects(right_label) and left_label.intersection(right_label).get_area() > 0.01:
				errors.append("Layout labels %s and %s overlap in %s layout." % [str(left.get("identity", "")), str(right.get("identity", "")), layout_label])
			if left_label.intersects(right_target) and left_label.intersection(right_target).get_area() > 0.01 \
					or right_label.intersects(left_target) and right_label.intersection(left_target).get_area() > 0.01:
				errors.append("Layout label and hit authority for %s / %s overlap in %s layout." % [str(left.get("identity", "")), str(right.get("identity", "")), layout_label])


static func _validate_actor_routes(actors: Dictionary, obstacles: Array, occupied: Array, environment: Dictionary, errors: Array) -> void:
	for identity_value in actors.keys():
		var identity := str(identity_value)
		var actor := _dict(actors.get(identity_value, {}))
		if actor.is_empty() or not bool(actor.get("present", true)):
			continue
		var points := _array(actor.get("route_points", []))
		if points.is_empty():
			continue
		if points.size() < 2:
			errors.append("Scenario actor %s route staging must include authored start and endpoint slots." % identity)
			continue
		var start := _pixel_point(_dict(points[0]))
		var endpoint := _pixel_point(_dict(points.back()))
		if not _finite_point(start) or not _finite_point(endpoint) or not Rect2(Vector2.ZERO, BOARD_SIZE).has_point(start) or not Rect2(Vector2.ZERO, BOARD_SIZE).has_point(endpoint):
			errors.append("Scenario actor %s route staging leaves the room board." % identity)
			continue
		for point_index in range(1, points.size()):
			var segment_start := _pixel_point(_dict(points[point_index - 1]))
			var segment_end := _pixel_point(_dict(points[point_index]))
			if not _path_reachable(segment_start, segment_end, obstacles, identity) or not _path_reachable(segment_start, segment_end, obstacles, identity, "small_rect"):
				errors.append("Scenario actor %s authored lane segment is obstructed or unreachable." % identity)
				break
		var bounds := _dict(actor.get("resolved_bounds", {}))
		var endpoint_size := Vector2(float(bounds.get("w", DEFAULT_ACTOR_SIZE.x)), float(bounds.get("h", DEFAULT_ACTOR_SIZE.y)))
		var endpoint_rect := Rect2(endpoint - endpoint_size * 0.5, endpoint_size)
		if not Rect2(Vector2.ZERO, BOARD_SIZE).encloses(endpoint_rect):
			errors.append("Scenario actor %s route endpoint cannot stage its full bounds inside the room." % identity)
			continue
		var endpoint_small := _expanded_rect(endpoint_rect, SMALL_SCREEN_TARGET)
		var actor_start_rect := _pixel_rect(_dict(actor.get("normalized_hit_rect", {})))
		var actor_small_start_rect := _pixel_rect(_dict(actor.get("small_screen_rect", {})))
		var endpoint_label := _translated_label_rect(_pixel_rect(_dict(actor.get("label_rect", {}))), actor_start_rect, endpoint_rect)
		var endpoint_small_label := _translated_label_rect(_pixel_rect(_dict(actor.get("small_screen_label_rect", {}))), actor_small_start_rect, endpoint_small)
		if _substantially_overlaps(identity, endpoint_rect, occupied) \
				or _expanded_overlaps(identity, endpoint_small, occupied) \
				or endpoint_label.has_area() and _substantially_overlaps(identity, endpoint_label, occupied) \
				or endpoint_small_label.has_area() and _expanded_overlaps(identity, endpoint_small_label, occupied):
			errors.append("Scenario actor %s route endpoint collides in normal or expanded small-screen layout at %s with %s." % [identity, str(endpoint), JSON.stringify(_overlap_identities(identity, endpoint_rect, endpoint_small, occupied))])


static func _validate_interactions(interactions: Dictionary, authority: Dictionary, obstacles: Array, base_records: Array, environment: Dictionary, errors: Array) -> Dictionary:
	var reachable_ids: Array = []
	var safe_exit_ids: Array = []
	var alternate_exit_ids: Array = []
	var active_targets: Array = []
	var blocked_exit_count := 0
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
		var overflow := str(authority_record.get("presentation_mode", "room")) == "overflow"
		var rect := _pixel_rect(_dict(authority_record.get("normalized_hit_rect", {})))
		var small_rect := _pixel_rect(_dict(authority_record.get("small_screen_rect", {})))
		var authority_label_rect := _pixel_rect(_dict(authority_record.get("label_rect", {})))
		var authority_small_label_rect := _pixel_rect(_dict(authority_record.get("small_screen_label_rect", {})))
		if not overflow:
			active_targets.append({
				"identity": identity,
				"scenario_owned": str(interaction.get("owner_namespace", "")) == "scenario",
				"developer_placed": _developer_placement_room(environment) or bool(authority_record.get("placement_spacing_warning", false)),
				"rect": rect,
				"small_rect": small_rect,
				"label_rect": authority_label_rect,
				"small_label_rect": authority_small_label_rect,
			})
		var normal_reachable := true if overflow else _path_reachable(WALK_LANE.get_center(), rect.get_center(), obstacles, identity)
		var small_reachable := true if overflow else _path_reachable(WALK_LANE.get_center(), small_rect.get_center(), obstacles, identity, "small_rect")
		var reachable := overflow or normal_reachable and small_reachable
		if not reachable:
			if normal_reachable and not small_reachable:
				errors.append("Expanded small-screen scenario obstruction leaves no reachable route from the player access lane into the room.")
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
			# This validator owns scenario composition. Base-only room collisions are
			# validated by the base-environment contracts and must not become
			# scenario failures merely because a scenario is active.
			if not bool(left.get("scenario_owned", false)) and not bool(right.get("scenario_owned", false)):
				continue
			# The 44px target expansion is allowed to share spacing (D2). Only the
			# actual normal interaction rectangles own exclusive click authority.
			for rect_key in ["rect"]:
				var left_rect: Rect2 = left.get(rect_key, Rect2())
				var right_rect: Rect2 = right.get(rect_key, Rect2())
				if left_rect.intersects(right_rect) and left_rect.intersection(right_rect).get_area() > 0.01:
					errors.append("Scenario interactions %s and %s have ambiguous %s hit authority (%s vs %s)." % [str(left.get("identity", "")), str(right.get("identity", "")), "expanded small-screen" if rect_key == "small_rect" else "normal", str(left_rect), str(right_rect)])
			for label_key in ["label_rect", "small_label_rect"]:
				var left_label: Rect2 = left.get(label_key, Rect2())
				var right_label: Rect2 = right.get(label_key, Rect2())
				if left_label.intersects(right_label) and left_label.intersection(right_label).get_area() > 0.01:
					errors.append("Scenario interaction labels %s and %s overlap in %s layout." % [str(left.get("identity", "")), str(right.get("identity", "")), "expanded small-screen" if label_key == "small_label_rect" else "normal"])
	for target_value in active_targets:
		var target := _dict(target_value)
		if not bool(target.get("scenario_owned", false)):
			continue
		var target_identity := str(target.get("identity", ""))
		for base_value in base_records:
			var base_record := _dict(base_value)
			var base_identity := _record_identity(base_record)
			if base_identity == target_identity or interactions.has(base_identity) or not bool(base_record.get("interactive", true)) or not bool(base_record.get("visible", true)) or str(base_record.get("presentation_mode", "room")) == "overflow":
				continue
			var base_rect := _record_pixel_rect(base_record)
			var base_small := _record_small_rect(base_record)
			for pair in [[target.get("rect", Rect2()), base_rect, "normal"]]:
				var target_rect: Rect2 = (pair as Array)[0]
				var other_rect: Rect2 = (pair as Array)[1]
				if target_rect.intersects(other_rect) and target_rect.intersection(other_rect).get_area() > 0.01:
					errors.append("Scenario interaction %s has ambiguous %s hit authority with unrelated room control %s (%s vs %s)." % [target_identity, str((pair as Array)[2]), base_identity, str(target_rect), str(other_rect)])
			for label_pair in [
				[target.get("label_rect", Rect2()), _record_label_rect(base_record), "normal"],
				[target.get("small_label_rect", Rect2()), _record_label_rect(base_record, true), "expanded small-screen"],
			]:
				var target_label: Rect2 = (label_pair as Array)[0]
				var base_label: Rect2 = (label_pair as Array)[1]
				if target_label.intersects(base_label) and target_label.intersection(base_label).get_area() > 0.01:
					errors.append("Scenario interaction %s label overlaps unrelated room control %s in %s layout (%s vs %s)." % [target_identity, base_identity, str((label_pair as Array)[2]), str(target_label), str(base_label)])
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
		var normal := _dict(semantic.get("normalized_hit_rect", {}))
		var small := _dict(semantic.get("small_screen_rect", {}))
		var label_rect := _dict(semantic.get("label_rect", {}))
		var small_label_rect := _dict(semantic.get("small_screen_label_rect", {}))
		var z_order := int(semantic.get("z_order", 0))
		var authority_kind := visual_kind
		var authority_source := "semantic_visual"
		if not existing.is_empty() and str(existing.get("source", "")) == "sealed_base_record":
			# A semantic update to an existing machine, offer, event, or other room
			# object shares that object's plane; it cannot create replacement draw
			# geometry or jump ahead in a renderer-only z layer.
			normal = _dict(existing.get("normalized_hit_rect", {}))
			small = _dict(existing.get("small_screen_rect", {}))
			label_rect = _dict(existing.get("label_rect", {}))
			small_label_rect = _dict(existing.get("small_screen_label_rect", {}))
			z_order = int(existing.get("z_order", 0))
			authority_kind = str(existing.get("visual_kind", "base_record"))
			authority_source = "sealed_base_record"
		var sealed_record := _authority_record(FunctionOptions.ScenarioAuthorityRecordOptions.from({
			"identity": identity,
			"presentation_object_id": presentation_object_id,
			"normal": normal,
			"small": small,
			"label_rect": label_rect,
			"small_label_rect": small_label_rect,
			"z_order": z_order,
			"visual_kind": authority_kind,
			"source": authority_source,
			"actor_route_points": _array(semantic.get("route_points", [])) if visual_kind == "actor" else [],
			"actor_route_stage": _dict(semantic.get("route_stage", {})) if visual_kind == "actor" else {},
			"presentation_required": true,
			"presentation_visible": presentation_visible,
			"presentation_interactive": presentation_interactive,
		}))
		var placement_class := str(semantic.get("placement_class", existing.get("placement_class", "")))
		sealed_record["placement_class"] = placement_class
		sealed_record["contact"] = str(semantic.get("contact", existing.get("contact", _placement_contact(placement_class))))
		sealed_record["presentation_mode"] = str(existing.get("presentation_mode", semantic.get("presentation_mode", "room")))
		sealed_record["slot_id"] = str(existing.get("slot_id", semantic.get("slot_id", "")))
		authority[identity] = sealed_record


static func _base_layout_authority(base_records: Array, errors: Array = [], environment: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	var class_overrides := _dict(EnvironmentPlacementScript.surface_map(environment).get("class_overrides", {}))
	for value in base_records:
		var record := _dict(value)
		var identity := _record_identity(record)
		var rect := _record_pixel_rect(record)
		var presentation_mode := str(record.get("presentation_mode", "room"))
		if identity == "::" or presentation_mode == "room" and not rect.has_area():
			continue
		if result.has(identity):
			errors.append("Base layout authority contains duplicate semantic identity %s." % identity)
			continue
		var classified_record := record.duplicate(true)
		var object_id := str(record.get("object_id", ""))
		var class_override := str(class_overrides.get(object_id, ""))
		if class_override in EnvironmentPlacementScript.CLASSES:
			classified_record["placement_class"] = class_override
		var placement_class := EnvironmentPlacementScript.classify(classified_record, str(record.get("object_type", "")), object_id, str(record.get("prop", record.get("icon_key", ""))))
		var record_label_rect := _dict(record.get("label_rect", {}))
		var record_small_label_rect := _dict(record.get("small_screen_label_rect", {}))
		if presentation_mode == "room" and record_label_rect.is_empty():
			var record_slot := _slot_by_id(environment, str(record.get("slot_id", "")))
			var authored_label := EnvironmentSlotBinderScript.label_rect_from_slot(record_slot, str(record.get("label", "")))
			record_label_rect = _normalized_rect(authored_label)
			record_small_label_rect = _normalized_rect(authored_label)
		var sealed_record := _authority_record(FunctionOptions.ScenarioAuthorityRecordOptions.from({
			"identity": identity,
			"presentation_object_id": object_id.strip_edges(),
			"normal": _normalized_rect(rect),
			"small": _normalized_rect(_expanded_rect(rect, SMALL_SCREEN_TARGET)),
			"label_rect": record_label_rect,
			"small_label_rect": record_small_label_rect,
			"z_order": int(record.get("scenario_z_order", record.get("z_order", 0))),
			"visual_kind": "base_record",
			"source": "sealed_base_record",
			"presentation_required": true,
			"presentation_visible": bool(record.get("visible", true)),
			"presentation_interactive": bool(record.get("interactive", true)),
		}))
		sealed_record["placement_class"] = placement_class
		sealed_record["contact"] = _placement_contact(placement_class)
		sealed_record["presentation_mode"] = presentation_mode
		sealed_record["slot_id"] = str(record.get("slot_id", ""))
		result[identity] = sealed_record
	return result


static func _placement_contact(placement_class: String) -> String:
	if EnvironmentPlacementScript.is_person_class(placement_class):
		return "feet"
	if placement_class in ["floor_fixture", "ground_marker"]:
		return "base"
	if placement_class == "surface_item":
		return "surface"
	if placement_class in ["wall_mounted", "hanging"]:
		return "mount"
	return "edge"


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
		# Collection membership is sealed independently. A tombstone in either
		# presentation collection intentionally suppresses the shared base canvas
		# record even when the other collection still records its exact membership.
		# The three membership booleans below preserve that distinction for the
		# hostile pre-canvas comparison.
		var required := not presence_values.has(false)
		if record.is_empty():
			if required:
				errors.append("Required semantic presentation %s has no layout authority to seal." % identity)
				continue
			var tombstone_kind := "actor" if actor_member else "scene_object" if scene_member else "interaction_tombstone"
			record = _authority_record(FunctionOptions.ScenarioAuthorityRecordOptions.from({
				"identity": identity,
				"presentation_object_id": identity,
				"normal": {},
				"small": {},
				"z_order": 0,
				"visual_kind": tombstone_kind,
				"source": "semantic_tombstone",
				"presentation_required": false,
				"presentation_visible": false,
				"presentation_interactive": false,
			}))
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
			# Scenario decoration is deliberately inspectable even when it has no
			# command actions. The sealed flag means canvas selection, not mutation.
			interactive = required
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
	var expected_keys := ["actor_route_points", "actor_route_stage", "contact", "identity", "label_rect", "normalized_hit_rect", "placement_class", "presentation_interactive", "presentation_mode", "presentation_object_id", "presentation_required", "presentation_visible", "semantic_actor_member", "semantic_interaction_member", "semantic_scene_object_member", "slot_id", "small_screen_label_rect", "small_screen_rect", "source", "visual_kind", "z_order"]
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
		var mode := str(record.get("presentation_mode", "room"))
		if mode not in ["room", "overflow"]:
			errors.append("Layout authority %s has an invalid presentation mode." % identity)
		var coverage_only := not bool(record.get("presentation_required", false)) and str(record.get("source", "")) == "semantic_tombstone"
		for rect_key in ["normalized_hit_rect", "small_screen_rect", "label_rect", "small_screen_label_rect"]:
			if (coverage_only or mode == "overflow") and _dict(record.get(rect_key, {})).is_empty():
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
	if route_points.size() < 2:
		errors.append("Actor layout authority %s must seal authored start and endpoint route points." % identity)
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
	if JSON.stringify(route_points[0]) != JSON.stringify(route_stage.get("start", {})) or JSON.stringify(route_points.back()) != JSON.stringify(route_stage.get("endpoint", {})) or JSON.stringify(route_points.back()) != JSON.stringify(route_stage.get("reduced_motion_endpoint", {})):
		errors.append("Actor layout authority %s route points and normal/reduced-motion endpoints diverge." % identity)
		return
	var normal_rect := _pixel_rect(_dict(authority_record.get("normalized_hit_rect", {})))
	var small_rect := _pixel_rect(_dict(authority_record.get("small_screen_rect", {})))
	var start := _pixel_point(_dict(route_points[0]))
	var endpoint := _pixel_point(_dict(route_points.back()))
	var expected_small_endpoint := _expanded_rect(Rect2(endpoint - normal_rect.size * 0.5, normal_rect.size), SMALL_SCREEN_TARGET).get_center()
	var route_distance := 0.0
	for index in range(1, route_points.size()):
		route_distance += _pixel_point(_dict(route_points[index - 1])).distance_to(_pixel_point(_dict(route_points[index])))
	var expected_duration := clampf(route_distance / 82.0, 0.75, 8.0)
	if not start.is_equal_approx(normal_rect.get_center()) \
		or not _pixel_point(_dict(route_stage.get("small_screen_start", {}))).is_equal_approx(small_rect.get_center()) \
		or not _pixel_point(_dict(route_stage.get("small_screen_endpoint", {}))).is_equal_approx(expected_small_endpoint) \
		or not is_equal_approx(float(route_stage.get("duration_sec", 0.0)), expected_duration):
		errors.append("Actor layout authority %s route geometry or timing diverges from its sealed normal/small rectangles." % identity)


static func _authority_record(options: FunctionOptions.ScenarioAuthorityRecordOptions) -> Dictionary:
	var identity := str(options.values.get("identity", ""))
	var presentation_object_id := str(options.values.get("presentation_object_id", ""))
	var normal: Dictionary = options.values.get("normal", {})
	var small: Dictionary = options.values.get("small", {})
	var label_rect: Dictionary = options.values.get("label_rect", {})
	var small_label_rect: Dictionary = options.values.get("small_label_rect", {})
	var z_order := int(options.values.get("z_order", 0))
	var visual_kind := str(options.values.get("visual_kind", ""))
	var source := str(options.values.get("source", ""))
	var actor_route_points: Array = options.values.get("actor_route_points", [])
	var actor_route_stage: Dictionary = options.values.get("actor_route_stage", {})
	var presentation_required := bool(options.values.get("presentation_required", true))
	var presentation_visible := bool(options.values.get("presentation_visible", true))
	var presentation_interactive := bool(options.values.get("presentation_interactive", true))
	var semantic_scene_object_member := bool(options.values.get("semantic_scene_object_member", false))
	var semantic_actor_member := bool(options.values.get("semantic_actor_member", false))
	var semantic_interaction_member := bool(options.values.get("semantic_interaction_member", false))
	return {
		"actor_route_points": actor_route_points.duplicate(true),
		"actor_route_stage": actor_route_stage.duplicate(true),
		"contact": "",
		"identity": identity,
		"label_rect": label_rect,
		"normalized_hit_rect": normal,
		"placement_class": "",
		"presentation_interactive": presentation_interactive,
		"presentation_mode": str(options.values.get("presentation_mode", "room")),
		"presentation_object_id": presentation_object_id,
		"presentation_required": presentation_required,
		"presentation_visible": presentation_visible,
		"semantic_actor_member": semantic_actor_member,
		"semantic_interaction_member": semantic_interaction_member,
		"semantic_scene_object_member": semantic_scene_object_member,
		"small_screen_rect": small,
		"small_screen_label_rect": small_label_rect,
		"slot_id": str(options.values.get("slot_id", "")),
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
	var detour_x_values := [16.0, BOARD_SIZE.x - 16.0]
	var detour_y_values := [16.0, BOARD_SIZE.y - 16.0]
	for obstacle_value in obstacles:
		var obstacle := _dict(obstacle_value)
		if str(obstacle.get("identity", "")) == ignored_identity:
			continue
		var obstacle_rect: Rect2 = obstacle.get(rect_key, Rect2())
		if not obstacle_rect.has_area():
			continue
		detour_x_values.append(clampf(obstacle_rect.position.x - 12.0, 16.0, BOARD_SIZE.x - 16.0))
		detour_x_values.append(clampf(obstacle_rect.end.x + 12.0, 16.0, BOARD_SIZE.x - 16.0))
		detour_y_values.append(clampf(obstacle_rect.position.y - 12.0, 16.0, BOARD_SIZE.y - 16.0))
		detour_y_values.append(clampf(obstacle_rect.end.y + 12.0, 16.0, BOARD_SIZE.y - 16.0))
	for x_value in detour_x_values:
		var first := Vector2(float(x_value), start.y)
		var second := Vector2(float(x_value), endpoint.y)
		if _point_clear(first, obstacles, ignored_identity, rect_key) and _point_clear(second, obstacles, ignored_identity, rect_key) \
				and _segment_clear(start, first, obstacles, ignored_identity, rect_key) \
				and _segment_clear(first, second, obstacles, ignored_identity, rect_key) \
				and _segment_clear(second, endpoint, obstacles, ignored_identity, rect_key):
			return true
	for y_value in detour_y_values:
		var horizontal_first := Vector2(start.x, float(y_value))
		var horizontal_second := Vector2(endpoint.x, float(y_value))
		if _point_clear(horizontal_first, obstacles, ignored_identity, rect_key) and _point_clear(horizontal_second, obstacles, ignored_identity, rect_key) \
				and _segment_clear(start, horizontal_first, obstacles, ignored_identity, rect_key) \
				and _segment_clear(horizontal_first, horizontal_second, obstacles, ignored_identity, rect_key) \
				and _segment_clear(horizontal_second, endpoint, obstacles, ignored_identity, rect_key):
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


static func _placement_class_priority(placement_class: String) -> int:
	match placement_class:
		"behind_counter_person", "seated_person": return 0
		"doorway", "wall_mounted", "hanging": return 1
		"floor_fixture": return 2
		"surface_item": return 3
		"ground_marker", "standing_person", "group": return 4
		_: return 5


static func _semantic_visual_area(semantic: Dictionary, actor: bool) -> float:
	var bounds := _dict(semantic.get("bounds", {}))
	var fallback := DEFAULT_ACTOR_SIZE if actor else DEFAULT_SCENE_SIZE
	var width := float(bounds.get("w", fallback.x))
	var height := float(bounds.get("h", fallback.y))
	return maxf(width, MIN_SCENE_SIZE.x) * maxf(height, MIN_SCENE_SIZE.y)


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


static func _overlap_identities(identity: String, rect: Rect2, small_rect: Rect2, occupied: Array) -> Array:
	var result: Array = []
	for occupied_value in occupied:
		var occupied_record := _dict(occupied_value)
		var other_identity := str(occupied_record.get("identity", ""))
		if other_identity.is_empty() or other_identity == identity:
			continue
		var other_rect: Rect2 = occupied_record.get("rect", Rect2())
		var other_small: Rect2 = occupied_record.get("small_rect", Rect2())
		if not other_small.has_area():
			other_small = _expanded_rect(other_rect, SMALL_SCREEN_TARGET)
		if (other_rect.has_area() and rect.intersects(other_rect)) or (other_small.has_area() and small_rect.intersects(other_small)):
			result.append(other_identity)
	result.sort()
	return result


static func _overlap_count(authority: Dictionary, rect_key: String, environment: Dictionary = {}) -> int:
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


static func _developer_placement_room(environment: Dictionary) -> bool:
	var placement_map := EnvironmentPlacementScript.surface_map(environment)
	for field in ["developer_object_slot_positions", "developer_scenario_object_slot_positions", "developer_category_slot_positions"]:
		if not _dict(placement_map.get(field, {})).is_empty():
			return true
	return false


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


static func _context_base_occupied_records(context: Dictionary, base_records: Array, errors: Array = []) -> Array:
	var value: Variant = context.get("base_occupied_records", [])
	if typeof(value) != TYPE_ARRAY:
		errors.append("Scenario production base occupancy must be an array.")
		return []
	if (value as Array).size() > 256:
		errors.append("Scenario production base occupancy exceeds the 256-record bound.")
		return []
	var sealed_presentation_ids: Dictionary = {}
	for base_value in base_records:
		var base := _dict(base_value)
		var presentation_id := str(base.get("object_id", "")).strip_edges()
		if not presentation_id.is_empty():
			sealed_presentation_ids[presentation_id] = true
	var seen: Dictionary = {}
	var result: Array = []
	for index in range((value as Array).size()):
		var source := _dict((value as Array)[index])
		var object_id := str(source.get("object_id", "")).strip_edges()
		var presentation_mode := str(source.get("presentation_mode", "room"))
		var label := str(source.get("label", "")).strip_edges()
		if source.is_empty() or object_id.is_empty() or seen.has(object_id):
			errors.append("Scenario production base occupancy record %d has an empty or duplicate identity." % index)
			continue
		seen[object_id] = true
		# Overflow objects live only in the action list and intentionally carry no
		# room geometry. Likewise, an exact sealed presentation record supersedes
		# the duplicate runtime reservation. Filter both before validating geometry.
		if presentation_mode == "overflow" or sealed_presentation_ids.has(object_id):
			continue
		var rect := _normalized_or_pixel_rect(source.get("focus_rect", {}))
		if label.length() > LABEL_MAX_LENGTH or not label.is_empty() and not _readable_text(label, LABEL_MAX_LENGTH):
			errors.append("Scenario production base occupancy record %s has an invalid label." % object_id)
			continue
		if not rect.has_area() or not Rect2(Vector2.ZERO, BOARD_SIZE).encloses(rect):
			errors.append("Scenario production base occupancy record %s has invalid room geometry." % object_id)
			continue
		result.append({
			"identity": "runtime_base::%s" % object_id,
			"rect": rect,
			"small_rect": _expanded_rect(rect, SMALL_SCREEN_TARGET),
			"label": label,
		})
	return result


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


static func _translated_label_rect(label_rect: Rect2, start_rect: Rect2, target_rect: Rect2) -> Rect2:
	if not label_rect.has_area() or not start_rect.has_area() or not target_rect.has_area():
		return Rect2()
	var translated := label_rect
	translated.position += target_rect.get_center() - start_rect.get_center()
	return _clamp_label_inside_board(translated)


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


static func _zone_rect(environment: Dictionary, zone_id: String) -> Rect2:
	if zone_id.is_empty():
		return Rect2()
	return _rect_from_semantic_bounds(_dict(_dict(environment.get("semantic_zones", {})).get(zone_id, {})).get("bounds", []))


static func _rect_from_semantic_bounds(value: Variant) -> Rect2:
	var values := _array(value)
	if values.size() < 4:
		return Rect2()
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


static func _resolve_route_center(environment: Dictionary, semantic_state: Dictionary, route_id: String) -> Vector2:
	var result := _resolve_route_center_result(environment, semantic_state, route_id)
	return result.get("center", Vector2(-1.0, -1.0)) if bool(result.get("ok", false)) else Vector2(-1.0, -1.0)


static func _resolve_route_center_result(environment: Dictionary, semantic_state: Dictionary, route_id: String) -> Dictionary:
	var parsed := OperationRegistryScript.parse_owned_identity(route_id)
	var raw_alias := route_id.strip_edges()
	var sealed_inventory := _dict(environment.get("scenario_semantic_inventory", {}))
	# Static content validation carries a validated catalog seal; live runtime
	# resolution carries an instance-bound seal. Both are authoritative for their
	# boundary, but only the latter may use exact_collections().
	var inventory := EnvironmentSemanticInventoryScript.guaranteed_collections(sealed_inventory) if str(sealed_inventory.get("kind", "")) == "catalog" else EnvironmentSemanticInventoryScript.exact_collections(sealed_inventory)
	# Actor spawn payloads may name a room-local endpoint alias rather than a
	# world route identity. The alias never resolves directly from live geometry:
	# it must match one guaranteed/exact anchor in the sealed inventory first.
	if parsed.is_empty():
		var raw_anchor_matches := _inventory_alias_matches(_array(inventory.get("anchors", [])), raw_alias)
		if raw_alias.is_empty() or raw_alias != raw_alias.to_lower() or raw_alias.contains("::") or raw_anchor_matches.is_empty():
			return {"ok": false, "center": Vector2(-1.0, -1.0), "error": "unknown sealed route/anchor alias %s" % raw_alias}
		if raw_anchor_matches.size() != 1:
			return {"ok": false, "center": Vector2(-1.0, -1.0), "error": "ambiguous sealed route/anchor alias %s" % raw_alias}
		var raw_center := _resolve_center(environment, raw_alias, raw_alias)
		if not _finite_point(raw_center) or raw_center.x < 0.0:
			return {"ok": false, "center": Vector2(-1.0, -1.0), "error": "unknown sealed route/anchor alias %s" % raw_alias}
		return {"ok": true, "center": raw_center, "error": ""}
	var stable_id := str(parsed.get("stable_object_id", ""))
	var alias := stable_id.get_slice(":", stable_id.get_slice_count(":") - 1)
	var route_matches := _inventory_alias_matches(_array(inventory.get("routes", [])), alias)
	var anchor_matches := _inventory_alias_matches(_array(inventory.get("anchors", [])), alias)
	if parsed.is_empty() or alias.is_empty() or route_matches.is_empty() or anchor_matches.is_empty():
		return {"ok": false, "center": Vector2(-1.0, -1.0), "error": "unknown sealed route/anchor alias %s" % alias}
	if route_matches.size() != 1 or str(route_matches[0]) != route_id or anchor_matches.size() != 1:
		return {"ok": false, "center": Vector2(-1.0, -1.0), "error": "ambiguous sealed route/anchor alias %s" % alias}
	var sealed_anchor := str(anchor_matches[0])
	var sealed_anchor_parsed := OperationRegistryScript.parse_owned_identity(sealed_anchor)
	var sealed_anchor_stable_id := str(sealed_anchor_parsed.get("stable_object_id", ""))
	var sealed_anchor_alias := sealed_anchor_stable_id.get_slice(":", sealed_anchor_stable_id.get_slice_count(":") - 1)
	if sealed_anchor_parsed.is_empty() or sealed_anchor_alias != alias:
		return {"ok": false, "center": Vector2(-1.0, -1.0), "error": "unknown sealed route/anchor alias %s" % alias}
	var aliased_center := _resolve_center(environment, sealed_anchor_alias, sealed_anchor_alias)
	if not _finite_point(aliased_center) or aliased_center.x < 0.0:
		return {"ok": false, "center": Vector2(-1.0, -1.0), "error": "unknown sealed route/anchor alias %s" % alias}
	return {"ok": true, "center": aliased_center, "error": ""}


static func _inventory_alias_matches(values: Array, alias: String) -> Array:
	var matches: Array = []
	for value in values:
		var identity_value := str(value)
		var parsed := OperationRegistryScript.parse_owned_identity(identity_value)
		var stable_id := str(parsed.get("stable_object_id", ""))
		if not parsed.is_empty() and stable_id.get_slice(":", stable_id.get_slice_count(":") - 1) == alias:
			matches.append(identity_value)
	matches.sort()
	return matches


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
		result.append({
			"identity": _record_identity(record),
			"rect": rect,
			"small_rect": _expanded_rect(rect, SMALL_SCREEN_TARGET),
			"label": str(record.get("label", "")),
		})
	return result


static func _record_identity(record: Dictionary) -> String:
	return "%s::%s" % [str(record.get("owner_namespace", "")), str(record.get("stable_object_id", ""))]


static func _record_pixel_rect(record: Dictionary) -> Rect2:
	if record.is_empty():
		return Rect2()
	return _normalized_or_pixel_rect(record.get("focus_rect", record.get("normalized_rect", {})))


static func _record_small_rect(record: Dictionary) -> Rect2:
	var authored := _normalized_or_pixel_rect(record.get("small_screen_rect", {}))
	return authored if authored.has_area() else _expanded_rect(_record_pixel_rect(record), SMALL_SCREEN_TARGET)


static func _record_label_rect(record: Dictionary, small_screen: bool = false) -> Rect2:
	var key := "small_screen_label_rect" if small_screen else "label_rect"
	return _normalized_or_pixel_rect(record.get(key, {}))


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
