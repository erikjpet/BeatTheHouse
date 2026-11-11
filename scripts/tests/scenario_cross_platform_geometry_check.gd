extends SceneTree

const Run := preload("res://scripts/core/run_state.gd")
const Inventory := preload("res://scripts/core/environment_semantic_inventory.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	var run := Run.new()
	# Actual native/Web pair observed in schema-2 Gas room inventory.
	var prior := {"layout_object_rects": {"character:nell": {"x": 0.784444444444445, "y": 0.297674418604651, "w": 0.08, "h": 0.167441860465116}}, "event_ids": ["side_door"], "route_ids": ["leave"], "base_interaction_authority": []}
	var next := prior.duplicate(true)
	next.layout_object_rects["character:nell"].x = 0.784444444444444
	var prior_before := JSON.stringify(prior)
	var next_before := JSON.stringify(next)
	_check(run._scenario_refresh_source_matches_prior(prior, next), "Actual native-to-Web geometry pair matches")
	_check(run._scenario_refresh_source_matches_prior(next, prior), "Actual Web-to-native geometry pair matches")
	_check(JSON.stringify(prior) == prior_before and JSON.stringify(next) == next_before, "Comparison owns its copy and never rewrites either source")
	var changed := next.duplicate(true)
	changed.layout_object_rects["character:nell"].x += 0.000000001
	_check(not run._scenario_refresh_source_matches_prior(prior, changed), "A nanounit geometry move is rejected")
	changed = next.duplicate(true); changed.event_ids = ["parking_lot_tip"]
	_check(not run._scenario_refresh_source_matches_prior(prior, changed), "Other provenance stays exact")
	changed = next.duplicate(true); changed["new_authority"] = true
	_check(not run._scenario_refresh_source_matches_prior(prior, changed), "Unknown source authority is not filtered")
	changed = next.duplicate(true); changed.layout_object_rects["other"] = changed.layout_object_rects["character:nell"].duplicate(true)
	_check(not run._scenario_refresh_source_matches_prior(prior, changed), "New rectangle identity is rejected")
	changed = next.duplicate(true); changed.layout_object_rects.erase("character:nell")
	_check(not run._scenario_refresh_source_matches_prior(prior, changed), "Missing rectangle identity is rejected")
	for value in ["0.784444444444444", false, INF, NAN, -0.0000000000001, 1.0000000000001]:
		changed = next.duplicate(true); changed.layout_object_rects["character:nell"].x = value
		_check(not run._scenario_refresh_source_matches_prior(prior, changed), "Malformed coordinate is rejected: %s" % str(value))
	changed = next.duplicate(true); changed.layout_object_rects["character:nell"]["extra"] = 1
	_check(not run._scenario_refresh_source_matches_prior(prior, changed), "Unknown rectangle member is rejected")
	changed = next.duplicate(true); changed.layout_object_rects["character:nell"].erase("w")
	_check(not run._scenario_refresh_source_matches_prior(prior, changed), "Missing rectangle member is rejected")
	var edge := {"edge": {"x": 0.0, "y": 0.0, "w": 0.1, "h": 0.1}}
	changed = edge.duplicate(true); changed.edge.x = -0.0000000000001
	_check(not run._scenario_source_layout_geometry_matches(edge, changed), "Tiny negative baseline cannot be hidden at zero boundary")
	changed = edge.duplicate(true); changed.edge.w = 0.0
	_check(not run._scenario_source_layout_geometry_matches(edge, changed), "Zero width is rejected")
	changed = edge.duplicate(true); changed.edge.x = 0.95
	_check(not run._scenario_source_layout_geometry_matches(changed, changed), "Out-of-board width is rejected")
	var valid_edge := {"edge": {"x": 0.9, "y": 0.0, "w": 0.100000001, "h": 0.1}}
	changed = valid_edge.duplicate(true); changed.edge.w = 0.1000000010000001
	_check(run._scenario_source_layout_geometry_matches(valid_edge, changed), "Existing normalized edge allowance is preserved")
	for failure in failures: push_error(failure)
	print("SCENARIO_CROSS_PLATFORM_GEOMETRY checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
