extends SceneTree

const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const DeveloperPlacementStoreScript := preload("res://scripts/core/developer_placement_store.gd")
const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")
const EnvironmentInteractionControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")

const PLACEMENT_PATH := "res://data/environments/placement_surfaces.json"
const LAYOUT_PATH := "res://data/environments/scenario_slot_layouts.json"
const CONDITIONAL_OBJECTS := {
	"pawn_shop::pawn_shop_estate_lot_day": ["event:chain06_sal_estate_item"],
	"motel::motel_weekly_rates": ["event:chain06_nico_weekly_door"],
	"gas_station_casino::gas_station_trucker_convoy": ["event:recruitment_switch"],
	"back_alley::back_alley_fence_night": ["event:recruitment_mags"],
	"bar::bar_fight_night": ["event:recruitment_knuckles"],
	"kitty_cat_lounge::kitty_cat_lounge_buyout": ["event:recruitment_velvet"],
	"kitty_cat_lounge::kitty_cat_lounge_slow_night": ["event:recruitment_velvet"],
	"beach::beach_festival_weekend": ["event:recruitment_lucky"],
}
const ACTION_ONLY_OBJECT_IDS := [
	"event:scenario_bringer_show_favor",
	"event:scenario_punchline_high_stakes_table",
	"event:scenario_slow_night_intel",
]
const LOCAL_ROLE_SLOT_TOKENS := {
	"wall_mounted": "wall_item",
	"hanging": "hanging_item",
}

var failures: Array[String] = []
var base_context_count := 0
var scenario_context_count := 0


class ServiceHookHost:
	const CONTEXT_MODE_SERVICE := "service"
	const CONTEXT_MODE_LENDER := "lender"
	var EnvironmentInteractionViewModelScript := preload("res://scripts/ui/environment_interaction_view_model.gd")
	var library: Variant = null

	func _run_failed_without_recovery() -> bool:
		return false

	func _pressure_status_text(_view: Dictionary) -> String:
		return ""

	func _run_pressure_view() -> Dictionary:
		return {}

	func _object_fixture_declared(_object_id: String) -> bool:
		return true

	func _label_from_id(value: String) -> String:
		return value.replace("_", " ").capitalize()

	func _interaction_rect_for_object(_object_id: String, _object_type: String, _index: int) -> Rect2:
		return Rect2(0.0, 0.0, 72.0, 48.0)

	func _make_interactable_object(data: Dictionary) -> Dictionary:
		var result := data.duplicate(true)
		result["presentation_mode"] = "room"
		return result


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var placement := _read_json(PLACEMENT_PATH)
	var authority := _read_json(LAYOUT_PATH)
	var maps := _rows_by_id(_array(placement.get("maps", [])), "id")
	var layouts := _rows_by_id(_array(authority.get("layouts", [])), "layout_id")
	var catalog_map_ids := _string_set(_array(authority.get("maps_with_catalog_scenarios", [])))
	_check(int(authority.get("layout_count", -1)) == 55, "authority must declare 55 scenario contexts")
	_check(layouts.size() == 55, "authority must contain 55 unique scenario layouts")
	_check(maps.size() == 21, "placement authority must contain 21 unique base maps")
	_check(_array(authority.get("base_layout_ids", [])).size() == 20, "authority must declare 20 reachable base contexts")
	_check(
		_array(authority.get("template_map_ids", [])) == ["small_underground_casino"],
		"authority must identify the unreachable layered Punchline parent as template-only"
	)

	for map_id_value in _array(authority.get("base_layout_ids", [])):
		_check_base_context(str(map_id_value), _dict(maps.get(str(map_id_value), {})), catalog_map_ids)
	for layout_value in _array(authority.get("layouts", [])):
		_check_scenario_context(_dict(layout_value), maps)
	_check_layer_scoped_scenario_cursor(maps)
	_check_conditional_runtime_ownership(layouts)
	_check_action_only_objects_have_no_markers(layouts)
	_check_generated_action_alias_bindings()
	_check_attached_service_actions(layouts, maps)
	_check_attached_controls_and_zone_banks(layouts)
	_check_attached_action_host_selection()
	_check_terminal_action_alias_lifecycle()
	_check_fail_closed_binding()
	_check_complete_manual_save_and_export(authority)

	_check(base_context_count == 20, "runtime sweep did not visit all 20 reachable base contexts")
	_check(scenario_context_count == 55, "runtime sweep did not visit all 55 scenario contexts")
	if failures.is_empty():
		print("SCENARIO_SLOT_LAYOUT_RUNTIME_CHECK PASS base=20 scenarios=55 contexts=75")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_base_context(map_id: String, base_map: Dictionary, catalog_map_ids: Dictionary) -> void:
	base_context_count += 1
	var environment := _environment_for_map(map_id)
	var surface := EnvironmentPlacementScript.surface_map(environment)
	var label := "%s::base" % map_id
	_check(not base_map.is_empty(), "%s has no source placement map" % label)
	_check(str(surface.get("id", "")) == map_id, "%s resolved the wrong runtime map" % label)
	var validation := EnvironmentSlotBinderScript.validate_slot_map(surface)
	_check(bool(validation.get("ok", false)), "%s runtime map is invalid: %s" % [label, JSON.stringify(validation.get("errors", []))])
	if not catalog_map_ids.has(map_id):
		return

	var reserve_ids := _runtime_reserve_ids(base_map)
	var runtime_scenario_slots := _array(surface.get("scenario_slots", []))
	var runtime_ids := _slot_ids(runtime_scenario_slots)
	_check(bool(surface.get("scenario_layout_scoped", false)), "%s is not scenario-layout scoped" % label)
	_check(str(surface.get("scenario_layout_id", "")) == label, "%s has the wrong base layout id" % label)
	_check(runtime_ids == reserve_ids, "%s did not remove its ordinary catalog scenario markers" % label)
	for slot_value in runtime_scenario_slots:
		var slot := _dict(slot_value)
		_check(bool(slot.get("runtime_reserve", false)), "%s retained ordinary no-scenario marker %s" % [label, str(slot.get("id", ""))])
	_check(_dict(surface.get("scenario_instance_slot_ids", {})).is_empty(), "%s leaked semantic instance mappings" % label)
	_check(_dict(surface.get("scenario_instance_object_slot_ids", {})).is_empty(), "%s leaked object instance mappings" % label)
	_check(_dict(surface.get("scenario_slot_ids", {})).is_empty(), "%s leaked ordinary scenario preferences" % label)
	for field in ["scenario_object_slot_ids", "scenario_category_slot_ids"]:
		for slot_id_value in _dict(surface.get(field, {})).values():
			_check(reserve_ids.has(str(slot_id_value)), "%s %s points outside runtime reserves" % [label, field])


func _check_scenario_context(layout: Dictionary, maps: Dictionary) -> void:
	scenario_context_count += 1
	var map_id := str(layout.get("map_id", "")).strip_edges()
	var scenario_id := str(layout.get("scenario_id", "")).strip_edges()
	var layout_id := "%s::%s" % [map_id, scenario_id]
	var base_map := _dict(maps.get(map_id, {}))
	var surface := EnvironmentPlacementScript.surface_map(_environment_for_map(map_id, scenario_id))
	_check(not base_map.is_empty(), "%s has no source placement map" % layout_id)
	_check(str(layout.get("layout_id", "")) == layout_id, "%s has a noncanonical authority id" % layout_id)
	_check(str(surface.get("id", "")) == map_id, "%s resolved the wrong runtime map" % layout_id)
	_check(bool(surface.get("scenario_layout_scoped", false)), "%s is not scoped at runtime" % layout_id)
	_check(str(surface.get("scenario_layout_id", "")) == layout_id, "%s selected the wrong runtime layout" % layout_id)
	_check(str(surface.get("scenario_layout_scenario_id", "")) == scenario_id, "%s lost its scenario identity" % layout_id)

	var validation := EnvironmentSlotBinderScript.validate_slot_map(surface)
	_check(bool(validation.get("ok", false)), "%s runtime map is invalid: %s" % [layout_id, JSON.stringify(validation.get("errors", []))])
	var local_slots := _slots_by_id(_array(layout.get("scenario_slots", [])))
	var reserve_ids := _runtime_reserve_ids(base_map)
	var expected_ids := reserve_ids.duplicate(true)
	for slot_id_value in local_slots.keys():
		expected_ids[str(slot_id_value)] = true
	var runtime_slots := _slots_by_id(_array(surface.get("scenario_slots", [])))
	_check(_string_set(runtime_slots.keys()) == expected_ids, "%s runtime slots are not exact-layout plus reserves" % layout_id)
	var role_ordinals: Dictionary = {}
	for slot_id_value in local_slots.keys():
		var slot_id := str(slot_id_value)
		var runtime_slot := _dict(runtime_slots.get(slot_id, {}))
		_check(not runtime_slot.is_empty(), "%s is missing local slot %s" % [layout_id, slot_id])
		_check(not bool(runtime_slot.get("runtime_reserve", false)), "%s local slot %s became a runtime reserve" % [layout_id, slot_id])
		_check(str(runtime_slot.get("scenario_id", "")) == scenario_id, "%s local slot %s belongs to another scenario" % [layout_id, slot_id])
		var role := str(runtime_slot.get("scenario_role", ""))
		var ordinal := int(runtime_slot.get("scenario_ordinal", 0))
		var token := str(LOCAL_ROLE_SLOT_TOKENS.get(role, role))
		_check(slot_id == "scenario.local_%s_%d" % [token, ordinal], "%s local slot %s does not match its role/ordinal metadata" % [layout_id, slot_id])
		var ordinals := _array(role_ordinals.get(role, []))
		ordinals.append(ordinal)
		role_ordinals[role] = ordinals
	for role_value in role_ordinals.keys():
		var role := str(role_value)
		var ordinals := _array(role_ordinals.get(role_value, []))
		ordinals.sort()
		var expected_ordinals: Array = []
		for ordinal in range(1, ordinals.size() + 1):
			expected_ordinals.append(ordinal)
		_check(ordinals == expected_ordinals, "%s local role %s has non-contiguous ordinals %s" % [layout_id, role, str(ordinals)])
	for reserve_id_value in reserve_ids.keys():
		var reserve_id := str(reserve_id_value)
		_check(bool(_dict(runtime_slots.get(reserve_id, {})).get("runtime_reserve", false)), "%s lost reserve status for %s" % [layout_id, reserve_id])

	var semantic_preferences := _dict(layout.get("scenario_instance_slot_ids", {}))
	var object_preferences := _dict(layout.get("scenario_instance_object_slot_ids", {}))
	var action_hosts := _dict(layout.get("scenario_instance_action_host_ids", {}))
	_check(_same_mapping(_dict(surface.get("scenario_instance_slot_ids", {})), semantic_preferences), "%s semantic exact mappings changed at runtime" % layout_id)
	_check(_same_mapping(_dict(surface.get("scenario_instance_object_slot_ids", {})), object_preferences), "%s object exact mappings changed at runtime" % layout_id)
	_check(_same_mapping(_dict(surface.get("scenario_instance_action_host_ids", {})), action_hosts), "%s action-host mappings changed at runtime" % layout_id)
	_check(_same_mapping(_dict(surface.get("scenario_slot_ids", {})), semantic_preferences), "%s compatibility semantic view is not exact" % layout_id)
	_check(_same_mapping(_dict(surface.get("scenario_object_slot_ids", {})), object_preferences), "%s compatibility object view is not exact" % layout_id)
	var generated_environment := _environment_for_map(map_id, scenario_id)
	var generated_layout := EnvironmentInstanceScript.ensure_generated_layout(generated_environment)
	_check(
		_same_mapping(_dict(generated_layout.get("scenario_instance_action_host_ids", {})), action_hosts),
		"%s durable generated layout lost exact action-host authority" % layout_id
	)
	for slot_id_value in semantic_preferences.values():
		var slot_id := str(slot_id_value)
		_check(local_slots.has(slot_id) and not reserve_ids.has(slot_id), "%s semantic mapping targets nonlocal slot %s" % [layout_id, slot_id])
	for object_id_value in object_preferences.keys():
		var object_id := str(object_id_value)
		var slot_id := str(object_preferences.get(object_id_value, ""))
		_check(local_slots.has(slot_id) and not reserve_ids.has(slot_id), "%s object %s targets nonlocal slot %s" % [layout_id, object_id, slot_id])
		_check(str(_dict(surface.get("object_family_ids", {})).get(object_id, "")) == "scenario", "%s object %s is not scenario-owned" % [layout_id, object_id])
		for family in ["fixed", "event", "exit"]:
			_check(not _dict(surface.get("%s_object_slot_ids" % family, {})).has(object_id), "%s object %s retained stale %s ownership" % [layout_id, object_id, family])
		for declaration_value in _array(surface.get("fixed_objects", [])):
			_check(str(_dict(declaration_value).get("object_id", "")) != object_id, "%s object %s retained a fixed declaration" % [layout_id, object_id])


func _check_layer_scoped_scenario_cursor(maps: Dictionary) -> void:
	var scenario_id := "punchline_open_mic_night"
	var retained_state := {
		"id": scenario_id,
		"archetype_id": "small_underground_casino",
		"layer_id": "club",
	}
	var casino_environment := {
		"archetype_id": "small_underground_casino",
		"current_layer_id": "casino",
		"scenario_id": scenario_id,
		"scenario_state": retained_state,
	}
	var casino_surface := EnvironmentPlacementScript.surface_map(casino_environment)
	var casino_base := _dict(maps.get("small_underground_casino:casino", {}))
	_check(
		EnvironmentPlacementScript.active_scenario_id(casino_environment).is_empty(),
		"a club-scoped scenario cursor remained active on the casino floor"
	)
	_check(
		str(casino_surface.get("scenario_layout_id", "")) == "small_underground_casino:casino::base",
		"a retained club scenario did not resolve the casino floor's base placement layout"
	)
	_check(
		_slot_ids(_array(casino_surface.get("scenario_slots", []))) == _runtime_reserve_ids(casino_base),
		"a retained club scenario exposed ordinary generic scenario capacity on the casino floor"
	)
	_check(
		_dict(casino_surface.get("scenario_instance_slot_ids", {})).is_empty(),
		"a retained club scenario leaked exact scenario mappings onto the casino floor"
	)

	var club_environment := casino_environment.duplicate(true)
	club_environment["current_layer_id"] = "club"
	var club_surface := EnvironmentPlacementScript.surface_map(club_environment)
	_check(
		EnvironmentPlacementScript.active_scenario_id(club_environment) == scenario_id,
		"a layer-scoped scenario was not active on its target club floor"
	)
	_check(
		str(club_surface.get("scenario_layout_id", "")) == "small_underground_casino:club::%s" % scenario_id,
		"the target club floor did not resolve its exact scenario placement layout"
	)


func _check_conditional_runtime_ownership(layouts: Dictionary) -> void:
	for layout_id_value in CONDITIONAL_OBJECTS.keys():
		var layout_id := str(layout_id_value)
		var layout := _dict(layouts.get(layout_id, {}))
		var map_id := str(layout.get("map_id", ""))
		var scenario_id := str(layout.get("scenario_id", ""))
		var surface := EnvironmentPlacementScript.surface_map(_environment_for_map(map_id, scenario_id))
		var object_preferences := _dict(surface.get("scenario_instance_object_slot_ids", {}))
		var family_ids := _dict(surface.get("object_family_ids", {}))
		for object_id_value in _array(CONDITIONAL_OBJECTS.get(layout_id, [])):
			var object_id := str(object_id_value)
			_check(object_preferences.has(object_id), "%s is missing conditional object %s" % [layout_id, object_id])
			_check(str(family_ids.get(object_id, "")) == "scenario", "%s conditional object %s is not scenario-owned" % [layout_id, object_id])
			for family in ["fixed", "event", "exit"]:
				_check(not _dict(surface.get("%s_object_slot_ids" % family, {})).has(object_id), "%s conditional object %s retained %s ownership" % [layout_id, object_id, family])


func _check_action_only_objects_have_no_markers(layouts: Dictionary) -> void:
	for layout_id_value in layouts.keys():
		var layout_id := str(layout_id_value)
		var layout := _dict(layouts.get(layout_id_value, {}))
		var object_preferences := _dict(layout.get("scenario_instance_object_slot_ids", {}))
		var action_ids := _array(ACTION_ONLY_OBJECT_IDS)
		for action_id_value in _dict(layout.get("scenario_instance_action_host_ids", {})).keys():
			var action_id := str(action_id_value)
			if not action_ids.has(action_id):
				action_ids.append(action_id)
		for object_id in action_ids:
			_check(not object_preferences.has(object_id), "%s action-only object %s created a duplicate manual marker" % [layout_id, object_id])
		for slot_value in _array(layout.get("scenario_slots", [])):
			var slot := _dict(slot_value)
			for object_id in action_ids:
				_check(not _array(slot.get("scenario_object_ids", [])).has(object_id), "%s slot %s retained action-only claimant %s" % [layout_id, str(slot.get("id", "")), object_id])


func _check_generated_action_alias_bindings() -> void:
	var environment := _environment_for_map("small_underground_casino:club", "punchline_bringer_show")
	environment["id"] = "scenario_action_alias_generation_fixture"
	environment["event_ids"] = ["scenario_bringer_show_favor"]
	environment["service_ids"] = ["punchline_two_drink_minimum", "house_drink"]
	environment["layout"] = {}
	var surface := EnvironmentPlacementScript.surface_map(environment)
	var event_id := "event:scenario_bringer_show_favor"
	var event_host_id := "scenario::punchline_bringer_show_bringer_performer"
	var service_id := "service:house_drink"
	var service_host_id := "service:punchline_two_drink_minimum"
	var event_host_slot_id := str(_dict(surface.get("scenario_instance_object_slot_ids", {})).get(event_host_id, ""))
	environment["scenario_render_snapshot"] = {
		"ok": true,
		"scenario_id": "punchline_bringer_show",
		"phase_id": "arrival",
		"visual_objects": [{
			"object_id": event_host_id,
			"stable_object_id": "punchline_bringer_show_bringer_performer",
			"object_type": "scenario_actor",
			"placement_class": "standing_person",
			"slot_id": event_host_slot_id,
			"render_key": "character",
			"present": true,
			"visible": true,
		}],
		"interaction_overlays": [],
	}
	var entries := EnvironmentInstanceScript._physical_manifest_layout_entries(environment, surface)
	var entries_by_id := _rows_by_id(entries, "object_id")
	for action_id in [event_id, service_id]:
		_check(
			not entries_by_id.has(action_id),
			"hosted action %s entered the physical manifest projection" % action_id
		)

	var generated_layout := EnvironmentInstanceScript.ensure_generated_layout(environment)
	environment["layout"] = generated_layout.duplicate(true)
	var manifest_entries := EnvironmentInstanceScript.active_object_manifest_rows(environment)
	var manifest_entries_by_id := _rows_by_id(manifest_entries, "object_id")
	for action_id in [event_id, service_id]:
		_check(
			not manifest_entries_by_id.has(action_id),
			"hosted action %s survived as an active physical manifest row" % action_id
		)
	var bindings := _dict(generated_layout.get("slot_bindings", {}))
	_check(
		int(generated_layout.get("generated_object_rect_version", 0)) > 0 \
				and _array(generated_layout.get("placement_errors", [])).is_empty(),
		"generated event/service action aliases invalidated the room layout"
	)
	_check(not bindings.has(event_id), "generated event action alias received an independent physical binding")
	_check(not bindings.has(service_id), "generated service action alias received an independent physical binding")
	_check(bindings.has(event_host_id), "generated event action alias lost its authored physical host binding")
	_check(
		bindings.has(service_host_id),
		"generated service action alias lost its authored physical host binding (bindings=%s errors=%s)" % [
			str(bindings.keys()), str(generated_layout.get("placement_errors", [])),
		]
	)
	var replay_authority := EnvironmentSlotBinderScript.validate_base_layout_authority(
		environment, manifest_entries
	)
	_check(
		bool(replay_authority.get("ok", false)),
		"persisted authority replay rejected the hosted-action-free physical manifest: %s" % str(replay_authority.get("errors", []))
	)
	var live_actions := [{
		"object_id": event_id,
		"object_type": "event",
		"physical": true,
		"slot_binding_source_id": event_host_id,
	}, {
		"object_id": service_id,
		"object_type": "service",
		"physical": true,
		"slot_binding_source_id": service_host_id,
	}]
	var live_records := manifest_entries.duplicate(true)
	live_records.append_array(live_actions)
	var live_replay := EnvironmentSlotBinderScript.validate_base_layout_authority(
		environment, live_records
	)
	_check(
		bool(live_replay.get("ok", false)),
		"strict replay rejected exact hosted live actions: %s" % str(live_replay.get("errors", []))
	)
	var late_bound := EnvironmentSlotBinderScript.bind_base_records(
		environment, live_records, bindings, {}
	)
	var late_bindings := _dict(late_bound.get("slot_bindings", {}))
	_check(
		bool(late_bound.get("ok", false)) \
				and not late_bindings.has(event_id) \
				and not late_bindings.has(service_id) \
				and late_bindings.has(event_host_id) \
				and late_bindings.has(service_host_id),
		"late live binding did not keep hosted event/service actions slotless: %s" % str(late_bound.get("errors", []))
	)

	# Route actors are scenario-render authority, not base-manifest occupants. The
	# exact action-host map must authenticate this attachment without inventing a
	# base binding for either the action or its transient route actor host.
	var route_environment := _environment_for_map("back_alley", "back_alley_cruiser_parked")
	route_environment["id"] = "scenario_route_action_alias_generation_fixture"
	route_environment["event_ids"] = ["scenario_cruiser_parked_watch"]
	route_environment["layout"] = {}
	var route_surface := EnvironmentPlacementScript.surface_map(route_environment)
	var route_action_id := "event:scenario_cruiser_parked_watch"
	var route_host_id := "scenario::patrol_officer"
	var route_entries := EnvironmentInstanceScript._physical_manifest_layout_entries(
		route_environment, route_surface
	)
	var route_entries_by_id := _rows_by_id(route_entries, "object_id")
	_check(
		not route_entries_by_id.has(route_action_id),
		"route-hosted action entered the physical manifest projection"
	)
	var route_layout := EnvironmentInstanceScript.ensure_generated_layout(route_environment)
	route_environment["layout"] = route_layout.duplicate(true)
	var route_manifest_entries := EnvironmentInstanceScript.active_object_manifest_rows(route_environment)
	var route_manifest_by_id := _rows_by_id(route_manifest_entries, "object_id")
	var route_bindings := _dict(route_layout.get("slot_bindings", {}))
	_check(not route_manifest_by_id.has(route_action_id), "route-hosted action survived as an active physical manifest row")
	_check(
		int(route_layout.get("generated_object_rect_version", 0)) > 0 \
				and _array(route_layout.get("placement_errors", [])).is_empty(),
		"route-hosted action invalidated generated base placement"
	)
	_check(not route_bindings.has(route_action_id), "route-hosted action received an independent base binding")
	_check(not route_bindings.has(route_host_id), "transient route actor leaked into base bindings")
	var route_replay := EnvironmentSlotBinderScript.validate_base_layout_authority(
		route_environment, route_manifest_entries
	)
	_check(
		bool(route_replay.get("ok", false)),
		"persisted authority replay rejected an exact route-hosted action: %s" % str(route_replay.get("errors", []))
	)
	var route_live_records := route_manifest_entries.duplicate(true)
	route_live_records.append({
		"object_id": route_action_id,
		"object_type": "event",
		"physical": true,
		"slot_binding_source_id": route_host_id,
	})
	var route_live_replay := EnvironmentSlotBinderScript.validate_base_layout_authority(
		route_environment, route_live_records
	)
	_check(
		bool(route_live_replay.get("ok", false)),
		"strict replay rejected the exact route-hosted live action: %s" % str(route_live_replay.get("errors", []))
	)
	var route_rebound := EnvironmentSlotBinderScript.bind_base_records(
		route_environment, route_live_records, route_bindings, {}
	)
	_check(
		bool(route_rebound.get("ok", false)) \
				and not _dict(route_rebound.get("slot_bindings", {})).has(route_action_id),
		"late base-record binding recreated the exact route-hosted action: %s" % str(route_rebound.get("errors", []))
	)


func _check_attached_service_actions(layouts: Dictionary, maps: Dictionary) -> void:
	var bringer_layout_id := "small_underground_casino:club::punchline_bringer_show"
	var headliner_layout_id := "small_underground_casino:club::punchline_headliner_night"
	var bringer_layout := _dict(layouts.get(bringer_layout_id, {}))
	var headliner_layout := _dict(layouts.get(headliner_layout_id, {}))
	var bringer_hosts := _dict(bringer_layout.get("scenario_instance_action_host_ids", {}))
	var headliner_hosts := _dict(headliner_layout.get("scenario_instance_action_host_ids", {}))
	var drink_id := "service:house_drink"
	var drink_host_id := "service:punchline_two_drink_minimum"
	var cover_id := "service:punchline_cover_charge"
	var cover_host_id := "scenario::punchline_headliner_night_service_door"
	_check(
		str(bringer_hosts.get(drink_id, "")) == drink_host_id,
		"Bringer Show Buy a Drink did not attach to the fixed two-drink service host"
	)
	_check(
		str(headliner_hosts.get(cover_id, "")) == cover_host_id,
		"Headliner Cover did not attach to the scenario service door"
	)
	for pair in [
		{"layout": bringer_layout, "layout_id": bringer_layout_id, "action_id": drink_id},
		{"layout": headliner_layout, "layout_id": headliner_layout_id, "action_id": cover_id},
	]:
		var layout := _dict(pair.get("layout", {}))
		var layout_id := str(pair.get("layout_id", ""))
		var action_id := str(pair.get("action_id", ""))
		_check(
			not _dict(layout.get("scenario_instance_object_slot_ids", {})).has(action_id),
			"%s attached service %s retained a manual object marker" % [layout_id, action_id]
		)
		for slot_value in _array(layout.get("scenario_slots", [])):
			var slot := _dict(slot_value)
			_check(
				not _array(slot.get("scenario_object_ids", [])).has(action_id),
				"%s slot %s retained attached service %s" % [layout_id, str(slot.get("id", "")), action_id]
			)

	var club_map := _dict(maps.get("small_underground_casino:club", {}))
	var fixed_service_stage: Dictionary = {}
	for slot_value in _array(club_map.get("fixed_slots", [])):
		var slot := _dict(slot_value)
		if str(slot.get("id", "")) == "fixed.service_stage":
			fixed_service_stage = slot
			break
	_check(
		_array(fixed_service_stage.get("occupant_ids", [])).has(drink_host_id),
		"the rendered Buy a Drink host no longer occupies fixed.service_stage"
	)
	_check(
		str(_dict(club_map.get("fixed_object_slot_ids", {})).get(drink_host_id, "")) == "fixed.service_stage",
		"the two-drink service host lost its fixed.service_stage exact mapping"
	)

	var source_options: Array = [{
		"id": "house_drink",
		"display_name": "Buy a Drink",
		"category": "alcohol",
		"mutation_supported": true,
		"enabled": true,
	}]
	var enriched_options := EnvironmentInteractionControllerScript._service_options_with_exact_hosts(
		source_options, {drink_id: drink_host_id}
	)
	_check(
		str(_dict(enriched_options[0]).get("slot_binding_source_id", "")) == drink_host_id,
		"exact service-host authority was not injected into the service option"
	)
	_check(
		str(_dict(source_options[0]).get("slot_binding_source_id", "")).is_empty(),
		"service-host injection mutated the source service option"
	)
	var records := EnvironmentInteractionControllerScript.hook_interactable_objects(
		ServiceHookHost.new(), "service", enriched_options
	)
	var drink_record := _dict(records[0]) if not records.is_empty() else {}
	_check(
		records.size() == 1 and str(drink_record.get("slot_binding_source_id", "")) == drink_host_id,
		"service interaction composition dropped the exact room-host binding"
	)
	var attached := EnvironmentInteractionControllerScript._attach_action_only_records([{
		"object_id": drink_host_id,
		"object_type": "service",
		"visual_type": "service",
		"visible": true,
		"presentation_mode": "room",
		"manifest_physical": true,
	}, drink_record])
	var attached_actions := _array(_dict(attached[0]).get("attached_room_actions", [])) if attached.size() == 1 else []
	_check(
		attached.size() == 1 and attached_actions.size() == 1 \
				and str(_dict(_dict(attached_actions[0]).get("record", {})).get("object_id", "")) == drink_id,
		"Buy a Drink did not collapse into one action on its fixed rendered service host"
	)


func _check_attached_controls_and_zone_banks(layouts: Dictionary) -> void:
	var attached_control_count := 0
	var same_zone_reuse_count := 0
	for layout_id_value in layouts.keys():
		var layout_id := str(layout_id_value)
		var layout := _dict(layouts.get(layout_id_value, {}))
		var preferences := _dict(layout.get("scenario_instance_slot_ids", {}))
		for stable_id_value in _array(_dict(layout.get("audit", {})).get("action_only_ids", [])):
			var stable_id := str(stable_id_value)
			attached_control_count += 1
			_check(not preferences.has(stable_id), "%s attached control %s received a stable exact marker" % [layout_id, stable_id])
			_check(not preferences.has("scenario::%s" % stable_id), "%s attached control %s received an identity exact marker" % [layout_id, stable_id])
			for key_value in preferences.keys():
				_check(not str(key_value).begins_with("%s|" % stable_id), "%s attached control %s received a positioned exact marker" % [layout_id, stable_id])
		for slot_value in _array(layout.get("scenario_slots", [])):
			var slot := _dict(slot_value)
			var zone_ids := _array(slot.get("scenario_zone_ids", []))
			_check(zone_ids.size() <= 1, "%s slot %s combines different authored zones" % [layout_id, str(slot.get("id", ""))])
			if zone_ids.size() == 1 and _array(slot.get("scenario_position_keys", [])).size() > 1:
				same_zone_reuse_count += 1
	_check(attached_control_count > 0, "no attached scenario controls were audited")
	_check(same_zone_reuse_count > 0, "valid same-zone scenario alternatives stopped sharing slots")

	# Exact preferences must not override the attached-control gate.
	var control_surface := EnvironmentPlacementScript.surface_map(_environment_for_map("bar", "bar_dead_tuesday")).duplicate(true)
	var control_preferences := _dict(control_surface.get("scenario_instance_slot_ids", {})).duplicate(true)
	control_preferences["bar_dead_tuesday_task_0||left|"] = "scenario.local_surface_item_1"
	control_surface["scenario_instance_slot_ids"] = control_preferences
	_check(
		not EnvironmentSlotBinderScript.scenario_visual_requires_room_slot(control_surface, {
			"identity": "scenario::bar_dead_tuesday_task_0",
			"semantic": {
				"present": true,
				"stable_object_id": "bar_dead_tuesday_task_0",
				"role": "task_station",
				"zone_id": "left",
			},
		}),
		"a stale exact preference turned an attached task control into a physical marker"
	)

	var lane_surface := EnvironmentPlacementScript.surface_map(_environment_for_map("bar", "bar_darts_league_night"))
	_check(
		EnvironmentSlotBinderScript.scenario_visual_requires_room_slot(lane_surface, {
			"identity": "scenario::bar_darts_league_night_darts_oche",
			"semantic": {
				"present": true,
				"stable_object_id": "bar_darts_league_night_darts_oche",
				"role": "game_lane",
				"zone_id": "right",
			},
		}),
		"the tangible darts game lane lost exact physical authority"
	)


func _check_attached_action_host_selection() -> void:
	var catalog_option := {
		"id": "scenario_test_action",
		"slot_binding_source_id": "scenario::canonical_prop",
	}
	var inactive_option := EnvironmentInteractionControllerScript._event_option_with_exact_host(
		catalog_option, {}
	)
	_check(
		str(inactive_option.get("slot_binding_source_id", "")).is_empty(),
		"an inactive exact-scenario host hid a standalone event instead of leaving it on an event slot"
	)
	var active_option := EnvironmentInteractionControllerScript._event_option_with_exact_host(
		catalog_option,
		{"event:scenario_test_action": "scenario::active_prop"}
	)
	_check(
		str(active_option.get("slot_binding_source_id", "")) == "scenario::active_prop",
		"active exact action-host authority did not replace the catalog documentation hint"
	)
	_check(
		str(catalog_option.get("slot_binding_source_id", "")) == "scenario::canonical_prop",
		"event action-host normalization mutated catalog data"
	)
	var explicit_action := {
		"object_id": "event:scenario_test_action",
		"slot_binding_source_id": "scenario::expected_prop",
	}
	var unrelated_records := [{
		"object_id": "scenario::unrelated_actor",
		"object_type": "scenario_actor",
		"visual_type": "character",
		"visible": true,
		"presentation_mode": "room",
	}]
	_check(
		EnvironmentInteractionControllerScript._attached_action_target_index(
			unrelated_records, explicit_action
		) == -1,
		"an exact scenario action alias silently fell back to an unrelated room object"
	)
	var exact_records := unrelated_records.duplicate(true)
	exact_records.append({
		"object_id": "scenario::expected_prop",
		"object_type": "scenario_object",
		"visible": true,
		"presentation_mode": "room",
	})
	_check(
		EnvironmentInteractionControllerScript._attached_action_target_index(
			exact_records, explicit_action
		) == 1,
		"an exact scenario action alias did not select its authored tangible host"
	)
	_check(
		EnvironmentInteractionControllerScript._missing_action_host_warning_deferred(
			explicit_action,
			{"event:scenario_test_action": "scenario::expected_prop"}
		),
		"the base-only pass did not defer its known exact scenario host"
	)
	_check(
		not EnvironmentInteractionControllerScript._missing_action_host_warning_deferred(
			explicit_action,
			{"event:scenario_test_action": "scenario::different_prop"}
		),
		"the base-only pass deferred a mismatched exact scenario host"
	)
	_check(
		not EnvironmentInteractionControllerScript._missing_action_host_warning_deferred(
			explicit_action,
			{}
		),
		"the authoritative pass suppressed a genuinely missing exact scenario host"
	)

	var payday_surface := EnvironmentPlacementScript.surface_map(
		_environment_for_map("bar", "bar_payday_rush")
	)
	var tray_identity := "scenario::bar_payday_rush_carrying_tray"
	var bartender_identity := "scenario::bar_payday_rush_rush_bartender"
	var payday_scenes := {
		tray_identity: {
			"present": true,
			"visible": true,
			"stable_object_id": "bar_payday_rush_carrying_tray",
			"label": "Carrying tray",
			"role": "service",
			"zone_id": "service_lane",
		},
	}
	var payday_actors := {
		bartender_identity: {
			"present": true,
			"visible": true,
			"stable_object_id": "bar_payday_rush_rush_bartender",
			"label": "Rush bartender",
			"actor_id": "actor_bartender",
			"zone_id": "right",
		},
	}
	var tray_target := ScenarioLayoutResolverScript._abstract_action_target(
		"scenario::bar_payday_rush_task_0",
		{
			"stable_object_id": "bar_payday_rush_task_0",
			"label": "Lift First Tray",
			"role": "task_station",
			"anchor_id": "payday_task",
			"zone_id": "left",
		},
		payday_scenes,
		payday_actors,
		[],
		payday_surface
	)
	_check(
		tray_target == tray_identity,
		"Lift First Tray attached to %s instead of the tangible Carrying Tray" % tray_target
	)

	var darts_surface := EnvironmentPlacementScript.surface_map(
		_environment_for_map("bar", "bar_darts_league_night")
	)
	var dart_identity := "scenario::bar_darts_league_night_disputed_dart"
	var captain_identity := "scenario::bar_darts_league_night_league_captain"
	var dart_target := ScenarioLayoutResolverScript._abstract_action_target(
		"scenario::bar_darts_league_night_task_4",
		{
			"stable_object_id": "bar_darts_league_night_task_4",
			"label": "Inspect Disputed Dart",
			"role": "task_station",
			"anchor_id": "darts_task",
			"zone_id": "background",
		},
		{
			dart_identity: {
				"present": true,
				"visible": true,
				"stable_object_id": "bar_darts_league_night_disputed_dart",
				"label": "Disputed board dart",
				"role": "evidence",
				"anchor_id": "env06_8_disputed_dart",
				"zone_id": "background",
			},
		},
		{
			captain_identity: {
				"present": true,
				"visible": true,
				"stable_object_id": "bar_darts_league_night_league_captain",
				"label": "League captain",
				"actor_id": "actor_league_captain",
				"anchor_id": "env06_8_darts_captain",
				"zone_id": "background",
			},
		},
		[],
		darts_surface
	)
	_check(
		dart_target == dart_identity,
		"Inspect Disputed Dart attached to %s instead of the tangible Disputed Board Dart" % dart_target
	)

	# A broad zone is only placement context for an abstract control.  Strong
	# command-label evidence must win even when the named prop lives elsewhere,
	# and the final subject must break a one-token modifier tie.
	var festival_surface := EnvironmentPlacementScript.surface_map(
		_environment_for_map("beach", "beach_festival_weekend")
	)
	var schedule_target := ScenarioLayoutResolverScript._abstract_action_target(
		"scenario::beach_festival_weekend_station",
		{
			"label": "Read the moving schedule",
			"role": "task_station",
			"anchor_id": "festival_station",
			"zone_id": "right",
		},
		{
			"scenario::beach_festival_weekend_crowd_rope": {
				"present": true,
				"visible": true,
				"label": "Moving crowd rope",
				"role": "route_marker",
				"zone_id": "background",
			},
			"scenario::beach_festival_weekend_schedule_board": {
				"present": true,
				"visible": true,
				"label": "Festival schedule board",
				"role": "clue",
				"zone_id": "left",
			},
		},
		{
			"scenario::beach_festival_weekend_lost_child": {
				"present": true,
				"visible": true,
				"label": "Lost child",
				"actor_id": "actor_lost_child",
				"zone_id": "right",
			},
		},
		[],
		festival_surface
	)
	_check(
		schedule_target == "scenario::beach_festival_weekend_schedule_board",
		"Read the moving schedule attached to %s instead of the named schedule board." % schedule_target
	)

	var wedding_surface := EnvironmentPlacementScript.surface_map(
		_environment_for_map("motel", "motel_wedding_overflow")
	)
	var key_tray_target := ScenarioLayoutResolverScript._abstract_action_target(
		"scenario::motel_wedding_overflow_station",
		{
			"label": "Read the room-key trail",
			"role": "task_station",
			"anchor_id": "wedding_station",
			"zone_id": "left",
		},
		{
			"scenario::motel_wedding_overflow_room_key_tray": {
				"present": true,
				"visible": true,
				"label": "Mixed room-key tray",
				"role": "workstation",
				"zone_id": "service_lane",
			},
		},
		{
			"scenario::motel_wedding_overflow_wedding_runner": {
				"present": true,
				"visible": true,
				"label": "Wedding runner",
				"actor_id": "actor_wedding_runner",
				"zone_id": "left",
			},
		},
		[],
		wedding_surface
	)
	_check(
		key_tray_target == "scenario::motel_wedding_overflow_room_key_tray",
		"Read the room-key trail attached to %s instead of the named room-key tray." % key_tray_target
	)

	# Compare base fixtures in the same candidate pool. A named room fixture must
	# beat an unrelated actor, while the actor remains the fallback when the
	# command label names no tangible host.
	var phone_target := ScenarioLayoutResolverScript._abstract_action_target(
		"scenario::fixture_phone_task",
		{"label": "Call Counter Phone", "role": "task_station", "zone_id": "left"},
		payday_scenes,
		payday_actors,
		[{
			"owner_namespace": "base",
			"stable_object_id": "counter_phone",
			"label": "Counter Phone",
			"object_type": "fixture",
			"visible": true,
			"presentation_mode": "room",
		}],
		payday_surface
	)
	_check(phone_target == "base::counter_phone", "A named base fixture was not considered beside scenario hosts.")
	var fallback_target := ScenarioLayoutResolverScript._abstract_action_target(
		"scenario::fixture_fallback_task",
		{"label": "Proceed", "role": "task_station", "zone_id": "left"},
		payday_scenes,
		payday_actors,
		[],
		payday_surface
	)
	_check(fallback_target == bartender_identity, "An unrelated tangible actor stopped serving as the safe attachment fallback.")


func _check_terminal_action_alias_lifecycle() -> void:
	var run_state := RunStateScript.new()
	var candidate := {
		"scenario_sequence_state": {"status": "aftermath"},
		"layout": {
			"scenario_instance_action_host_ids": {
				"event:scenario_fixture_action_a": "scenario::fixture_host_a",
			"event:scenario_fixture_action_b": "scenario::fixture_host_b",
			"event:": "scenario::malformed_empty_event",
			"event:scenario_fixture_missing_host": "",
			"service:fixture_attached_purchase": "scenario::fixture_host_a",
			"item:not_an_event": "scenario::fixture_host_a",
			},
		},
		"resolved_event_ids": ["already_resolved"],
		"layer_states": {
			"main": {"resolved_event_ids": ["already_resolved"]},
			"other": {"resolved_event_ids": []},
		},
	}
	run_state._resolve_terminal_scenario_action_aliases(candidate)
	var expected_resolved := [
		"already_resolved",
		"scenario_fixture_action_a",
		"scenario_fixture_action_b",
	]
	_check(
		_array(candidate.get("resolved_event_ids", [])) == expected_resolved,
		"terminal scenario publication did not resolve every exact action alias once"
	)
	var expected_layer_resolved := {
		"main": expected_resolved,
		"other": ["scenario_fixture_action_a", "scenario_fixture_action_b"],
	}
	for layer_id in expected_layer_resolved.keys():
		_check(
			_array(_dict(_dict(candidate.get("layer_states", {})).get(layer_id, {})).get("resolved_event_ids", [])) == _array(expected_layer_resolved.get(layer_id, [])),
			"terminal scenario action aliases did not propagate to layer %s" % layer_id
		)
	var once := JSON.stringify(candidate)
	run_state._resolve_terminal_scenario_action_aliases(candidate)
	_check(JSON.stringify(candidate) == once, "terminal action-alias cleanup is not idempotent")

	var active_candidate := candidate.duplicate(true)
	active_candidate["scenario_sequence_state"] = {"status": "active"}
	active_candidate["resolved_event_ids"] = ["already_resolved"]
	active_candidate["layer_states"] = {
		"main": {"resolved_event_ids": ["already_resolved"]},
	}
	var active_before := JSON.stringify(active_candidate)
	run_state._resolve_terminal_scenario_action_aliases(active_candidate)
	_check(
		JSON.stringify(active_candidate) == active_before,
		"active scenario action aliases were resolved before their hosts left the room"
	)


func _check_fail_closed_binding() -> void:
	var environment := _environment_for_map("back_alley", "back_alley_cruiser_parked")
	var surface := EnvironmentPlacementScript.surface_map(environment)
	var valid_identity := "scenario::back_alley_cruiser_parked_exit"
	var valid := EnvironmentSlotBinderScript.bind_scenario_visuals(environment, [{
		"identity": valid_identity,
		"semantic": {
			"present": true,
			"stable_object_id": "back_alley_cruiser_parked_exit",
		},
		"actor": false,
		"safe_exit": true,
		"placement_class": "doorway",
	}])
	_check(bool(valid.get("ok", false)), "known exact scenario mapping failed to bind: %s" % JSON.stringify(valid.get("errors", [])))
	var valid_binding := _dict(_dict(valid.get("slot_bindings", {})).get(valid_identity, {}))
	var expected_slot_id := str(_dict(surface.get("scenario_instance_slot_ids", {})).get("back_alley_cruiser_parked_exit", ""))
	_check(str(valid_binding.get("slot_id", "")) == expected_slot_id, "known exact scenario mapping bound the wrong slot")
	_check(not bool(_dict(_slots_by_id(_array(surface.get("scenario_slots", []))).get(expected_slot_id, {})).get("runtime_reserve", false)), "known exact scenario mapping fell into a reserve")

	var invented_identity := "scenario::__unmapped_runtime_actor"
	var rejected := EnvironmentSlotBinderScript.bind_scenario_visuals(environment, [{
		"identity": invented_identity,
		"semantic": {
			"present": true,
			"stable_object_id": "__unmapped_runtime_actor",
		},
		"actor": true,
		"placement_class": "standing_person",
	}])
	_check(not bool(rejected.get("ok", true)), "unmapped scenario visual did not fail closed")
	_check(not _dict(rejected.get("slot_bindings", {})).has(invented_identity), "unmapped scenario visual received a fallback binding")
	_check(_array(rejected.get("occupied_slot_ids", [])).is_empty(), "unmapped scenario visual consumed scenario reserve capacity")
	var named_error := false
	for error_value in _array(rejected.get("errors", [])):
		if str(error_value).contains("no exact slot instance"):
			named_error = true
	_check(named_error, "unmapped scenario visual did not report missing exact authority")


func _check_complete_manual_save_and_export(authority: Dictionary) -> void:
	var temp_root := ProjectSettings.globalize_path("res://.tmp/scenario_slot_layout_check")
	DirAccess.make_dir_recursive_absolute(temp_root)
	var user_path := temp_root.path_join("user.json")
	var project_path := temp_root.path_join("project.json")
	var report_path := temp_root.path_join("report.json")
	for path in [user_path, "%s.bak" % user_path, project_path, "%s.bak" % project_path, report_path, "%s.bak" % report_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var project_file := FileAccess.open(project_path, FileAccess.WRITE)
	project_file.store_string(JSON.stringify({
		"schema_version": DeveloperPlacementStoreScript.SCHEMA_VERSION,
		"rooms": {},
	}, "\t"))
	project_file.close()
	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV, user_path)
	OS.set_environment(DeveloperPlacementStoreScript.PROJECT_PATH_ENV, project_path)
	OS.set_environment(DeveloperPlacementStoreScript.REPORT_PATH_ENV, report_path)
	DeveloperPlacementStoreScript.reload()
	var template_environment := _environment_for_map("small_underground_casino")
	var rejected_template := DeveloperPlacementStoreScript.save_layout(
		template_environment,
		_surface_positions(EnvironmentPlacementScript.surface_map(template_environment))
	)
	_check(
		not bool(rejected_template.get("ok", true)),
		"the unreachable layered Punchline parent was accepted as a manual base layout"
	)

	var expected_exported_slot_count := 0
	for map_id_value in _array(authority.get("base_layout_ids", [])):
		var map_id := str(map_id_value)
		var environment := _environment_for_map(map_id)
		var positions := _surface_positions(EnvironmentPlacementScript.surface_map(environment))
		expected_exported_slot_count += positions.size()
		var result := DeveloperPlacementStoreScript.save_layout(
			environment,
			positions
		)
		_check(bool(result.get("ok", false)), "%s::__base failed the complete manual save: %s" % [map_id, str(result.get("error", ""))])
	for layout_value in _array(authority.get("layouts", [])):
		var layout := _dict(layout_value)
		var map_id := str(layout.get("map_id", ""))
		var scenario_id := str(layout.get("scenario_id", ""))
		expected_exported_slot_count += _array(layout.get("scenario_slots", [])).size()
		var environment := _environment_for_map(map_id, scenario_id)
		var result := DeveloperPlacementStoreScript.save_layout(
			environment,
			_surface_positions(EnvironmentPlacementScript.surface_map(environment))
		)
		_check(bool(result.get("ok", false)), "%s failed the complete manual save: %s" % [str(layout.get("layout_id", "")), str(result.get("error", ""))])

	var coverage := DeveloperPlacementStoreScript.coverage_snapshot()
	_check(
		bool(coverage.get("complete", false))
			and int(coverage.get("expected_layout_count", -1)) == 75
			and int(coverage.get("saved_layout_count", -1)) == 75
			and _array(coverage.get("missing_layout_ids", [])).is_empty(),
		"the simulated owner pass did not reach complete 75/75 coverage"
	)
	var exported := DeveloperPlacementStoreScript.export_user_overrides()
	_check(
		bool(exported.get("ok", false))
			and bool(exported.get("complete", false))
			and int(exported.get("room_count", -1)) == 20
			and int(exported.get("slot_count", -1)) == expected_exported_slot_count
			and FileAccess.file_exists(report_path),
		"the complete owner pass did not export 20 rooms and %d scoped positions" % expected_exported_slot_count
	)
	var report := _read_json(report_path)
	var rooms := _dict(report.get("rooms", {}))
	for map_id_value in _array(authority.get("base_layout_ids", [])):
		var map_id := str(map_id_value)
		_check(bool(_dict(rooms.get(map_id, {})).get("base_saved", false)), "%s report lost base completion" % map_id)
	for layout_value in _array(authority.get("layouts", [])):
		var layout := _dict(layout_value)
		var map_id := str(layout.get("map_id", ""))
		var scenario_id := str(layout.get("scenario_id", ""))
		var saved_layout := _dict(_dict(_dict(rooms.get(map_id, {})).get("scenario_layouts", {})).get(scenario_id, {}))
		_check(bool(saved_layout.get("saved", false)), "%s report lost scenario completion" % str(layout.get("layout_id", "")))
		_check(
			_dict(saved_layout.get("slot_positions", {})).size() == _array(layout.get("scenario_slots", [])).size(),
			"%s report did not preserve every local scenario coordinate" % str(layout.get("layout_id", ""))
		)

	var shared_edit := DeveloperPlacementStoreScript.save_position(
		{"archetype_id": "bar"},
		"slot_positions",
		"fixed.random_game_1",
		Vector2(75.0, 178.0)
	)
	var invalidated_coverage := DeveloperPlacementStoreScript.coverage_snapshot()
	var invalidated_missing := _array(invalidated_coverage.get("missing_layout_ids", []))
	var expected_bar_missing: Array = ["bar::__base"]
	for layout_value in _array(authority.get("layouts", [])):
		var layout := _dict(layout_value)
		if str(layout.get("map_id", "")) == "bar":
			expected_bar_missing.append(str(layout.get("layout_id", "")))
	expected_bar_missing.sort()
	_check(
		bool(shared_edit.get("ok", false))
			and invalidated_missing == expected_bar_missing
			and int(invalidated_coverage.get("saved_layout_count", -1)) == 75 - expected_bar_missing.size(),
		"editing shared room geometry did not invalidate the base and every previously reviewed scenario for that room"
	)

	OS.set_environment(DeveloperPlacementStoreScript.USER_PATH_ENV, "")
	OS.set_environment(DeveloperPlacementStoreScript.PROJECT_PATH_ENV, "")
	OS.set_environment(DeveloperPlacementStoreScript.REPORT_PATH_ENV, "")
	DeveloperPlacementStoreScript.reload()
	for path in [user_path, "%s.bak" % user_path, project_path, "%s.bak" % project_path, report_path, "%s.bak" % report_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(temp_root):
		DirAccess.remove_absolute(temp_root)


func _environment_for_map(map_id: String, scenario_id: String = "") -> Dictionary:
	var pieces := map_id.split(":", false, 1)
	var environment := {"archetype_id": str(pieces[0])}
	if pieces.size() > 1:
		environment["current_layer_id"] = str(pieces[1])
	if not scenario_id.is_empty():
		environment["scenario_id"] = scenario_id
	return environment


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return _dict(parsed)


func _rows_by_id(rows: Array, id_field: String) -> Dictionary:
	var result: Dictionary = {}
	for row_value in rows:
		var row := _dict(row_value)
		var row_id := str(row.get(id_field, "")).strip_edges()
		if not row_id.is_empty():
			result[row_id] = row
	return result


func _slots_by_id(slots: Array) -> Dictionary:
	return _rows_by_id(slots, "id")


func _slot_ids(slots: Array) -> Dictionary:
	return _string_set(_slots_by_id(slots).keys())


func _runtime_reserve_ids(surface: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for slot_value in _array(surface.get("scenario_slots", [])):
		var slot := _dict(slot_value)
		if bool(slot.get("runtime_reserve", false)):
			result[str(slot.get("id", ""))] = true
	return result


func _surface_positions(surface: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field in ["fixed_slots", "event_slots", "scenario_slots", "exit_slots"]:
		for slot_value in _array(surface.get(field, [])):
			var slot := _dict(slot_value)
			var slot_id := str(slot.get("id", "")).strip_edges()
			var position := _array(slot.get("pos", []))
			if not slot_id.is_empty() and position.size() >= 2:
				result[slot_id] = Vector2(float(position[0]), float(position[1]))
	return result


func _string_set(entries: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in entries:
		result[str(value)] = true
	return result


func _same_mapping(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for key_value in left.keys():
		if not right.has(key_value) or str(left.get(key_value)) != str(right.get(key_value)):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
