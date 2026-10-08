extends SceneTree

const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scenario_id := "back_alley_cruiser_parked"
	var projection := {
		"scenario_id": scenario_id,
		"phase_id": "arrival",
		"status": "active",
		"boundary_serial": 1,
		"semantic_state": {
			"scene_objects": {
				"scenario::back_alley_cruiser_parked_exit": {
					"present": true,
					"visible": true,
					"enabled": true,
					"owner_namespace": "scenario",
					"stable_object_id": "back_alley_cruiser_parked_exit",
					"label": "Marked Clear Exit",
					"appearance": "marked_lane",
					"role": "exit",
					"zone_id": "exit_lane",
					"bounds": {"w": 64.0, "h": 72.0},
				},
			},
			"actors": {
				"scenario::patrol_officer": {
					"present": true,
					"visible": true,
					"enabled": true,
					"owner_namespace": "scenario",
					"stable_object_id": "patrol_officer",
					"actor_id": "patrol_officer",
					"label": "Patrol Officer",
					"behavior": "patrol",
					"pose": "observing",
					"route_id": "base::world:bar",
					"zone_id": "background",
					"bounds": {"w": 72.0, "h": 80.0},
				},
			},
			"interactions": {},
			"services": {},
			"games": {},
			"routes": {},
		},
	}
	var environment := {
		"archetype_id": "back_alley",
		"scenario_id": scenario_id,
		"scenario_state": {"id": scenario_id, "layer_id": ""},
	}
	var resolved := ScenarioLayoutResolverScript.resolve([], projection, environment)
	var canvas := PixelSceneCanvasScript.new()
	var actor_small := canvas._developer_slot_expanded_rect(Rect2(677.0, 275.0, 72.0, 80.0))
	var edge_contact_small := canvas._developer_slot_expanded_rect(Rect2(761.0, 358.0, 64.0, 72.0))
	var real_overlap_small := canvas._developer_slot_expanded_rect(Rect2(761.0, 354.0, 64.0, 72.0))
	var edge_contact_allowed := not canvas._developer_slot_rects_meaningfully_intersect(actor_small, edge_contact_small)
	var real_overlap_rejected := canvas._developer_slot_rects_meaningfully_intersect(actor_small, real_overlap_small)
	canvas.free()
	# Reproduce the live failure at (713, 315): the actor body is clear, but its
	# translated name label touches an unrelated record above it. Runtime label
	# layout resolves that presentation overlap, so it must not invalidate the
	# physical route or produce the misleading `with []` error.
	var endpoint := Vector2(713.0, 315.0)
	var actor_rect := Rect2(endpoint - Vector2(36.0, 40.0), Vector2(72.0, 80.0))
	var actor_small_rect := ScenarioLayoutResolverScript._expanded_rect(actor_rect, ScenarioLayoutResolverScript.SMALL_SCREEN_TARGET)
	var label_rect := Rect2(680.0, 250.0, 120.0, 15.0)
	var label_only_errors: Array = []
	ScenarioLayoutResolverScript._validate_actor_routes({
		"scenario::patrol_officer": {
			"present": true,
			"route_points": [
				ScenarioLayoutResolverScript._normalized_point(endpoint),
				ScenarioLayoutResolverScript._normalized_point(endpoint),
			],
			"resolved_bounds": {"w": 72.0, "h": 80.0},
			"normalized_hit_rect": ScenarioLayoutResolverScript._normalized_rect(actor_rect),
			"small_screen_rect": ScenarioLayoutResolverScript._normalized_rect(actor_small_rect),
			"label_rect": ScenarioLayoutResolverScript._normalized_rect(label_rect),
			"small_screen_label_rect": ScenarioLayoutResolverScript._normalized_rect(label_rect),
		},
	}, [], [{
		"identity": "fixed::label_neighbor",
		"rect": Rect2(700.0, 250.0, 20.0, 15.0),
		"small_rect": Rect2(700.0, 250.0, 20.0, 15.0),
	}], {}, label_only_errors)
	var body_collision_errors: Array = []
	ScenarioLayoutResolverScript._validate_actor_routes({
		"scenario::patrol_officer": {
			"present": true,
			"route_points": [
				ScenarioLayoutResolverScript._normalized_point(endpoint),
				ScenarioLayoutResolverScript._normalized_point(endpoint),
			],
			"resolved_bounds": {"w": 72.0, "h": 80.0},
			"normalized_hit_rect": ScenarioLayoutResolverScript._normalized_rect(actor_rect),
			"small_screen_rect": ScenarioLayoutResolverScript._normalized_rect(actor_small_rect),
		},
	}, [], [{
		"identity": "fixed::physical_obstacle",
		"rect": Rect2(700.0, 300.0, 20.0, 15.0),
		"small_rect": Rect2(700.0, 300.0, 20.0, 15.0),
	}], {}, body_collision_errors)
	if bool(resolved.get("ok", false)) \
			and edge_contact_allowed \
			and real_overlap_rejected \
			and label_only_errors.is_empty() \
			and not body_collision_errors.is_empty():
		print("BACK_ALLEY_ROUTE_ENDPOINT_CHECK PASS")
		quit(0)
		return
	for failure_value in resolved.get("errors", []):
		push_error(str(failure_value))
	if not edge_contact_allowed:
		push_error("Placement preview rejected the harmless one-pixel board-edge contact.")
	if not real_overlap_rejected:
		push_error("Placement preview accepted a meaningful routed-slot collision.")
	for error_value in label_only_errors:
		push_error("Label-only route contact was treated as a physical collision: %s" % str(error_value))
	if body_collision_errors.is_empty():
		push_error("A genuine route-body collision no longer failed closed.")
	quit(1)
