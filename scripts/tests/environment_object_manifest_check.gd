extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")
const EnvironmentInteractionControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")

const FAMILIES := ["fixed", "event", "scenario", "exit"]
const PLACEMENT_MAP_PATH := "res://data/environments/placement_surfaces.json"

var _failures: Array[String] = []
var _runtime_variants := 0
var _authored_maps := 0
var _manifest_rows := 0
var _roundtrips := 0
var _jazz_environment: Dictionary = {}
var _ordinary_event_environment: Dictionary = {}


class DeliveryInteractionHost:
	var run_state: Variant
	const CONTEXT_MODE_DELIVERY := "delivery"
	const CONTEXT_MODE_DIALOGUE := "dialogue"
	const CONTEXT_MODE_SHOPKEEPER := "shopkeeper"

	func _init(source_run_state: Variant) -> void:
		run_state = source_run_state

	func _interaction_rect_for_object(object_id: String, _object_type: String, _index: int) -> Rect2:
		var layout: Dictionary = run_state.current_environment.get("layout", {}) if typeof(run_state.current_environment.get("layout", {})) == TYPE_DICTIONARY else {}
		var rects: Dictionary = layout.get("object_rects", {}) if typeof(layout.get("object_rects", {})) == TYPE_DICTIONARY else {}
		var rect: Dictionary = rects.get(object_id, {}) if typeof(rects.get(object_id, {})) == TYPE_DICTIONARY else {}
		return Rect2(float(rect.get("x", 0.0)), float(rect.get("y", 0.0)), float(rect.get("w", 0.0)), float(rect.get("h", 0.0)))

	func _make_interactable_object(data: Dictionary) -> Dictionary:
		var result := data.duplicate(true)
		result["presentation_mode"] = "room"
		return result


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library := ContentLibraryScript.new()
	library.load(false)
	_check_authored_map_coverage(library)
	for archetype_value in library.environment_archetypes:
		if typeof(archetype_value) != TYPE_DICTIONARY:
			continue
		var archetype := archetype_value as Dictionary
		var archetype_id := str(archetype.get("id", "")).strip_edges()
		if archetype_id.is_empty():
			continue
		var layers := _dict(archetype.get("layers", {}))
		if layers.is_empty():
			_check_runtime_variant(archetype, "", library)
			continue
		var layer_ids := layers.keys()
		layer_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		for layer_id_value in layer_ids:
			_check_runtime_variant(archetype, str(layer_id_value), library)
	_check_tutorial_home_item_manifest(library)
	_check_category_family_authority(library)
	_check_jazz_guarantees()
	_check_lottery_counter_hosts(library)
	_check_grand_casino_rumor_host(library)
	_check_grand_casino_live_table(library)
	_check_missing_and_stale_regeneration(library)
	_check_scenario_manifest_retention_validation(library)
	_check_resolved_event_lifecycle(library)
	_check_resolved_fixed_event_lifecycle(library)
	_check_contextual_runtime_membership(library)
	_check_delivery_runtime_hosts(library)
	_check_numbers_runtime_hosts(library)
	_check_grand_living_runtime_hosts(library)
	_check_controller_fail_closed_membership()
	if _failures.is_empty():
		print("ENVIRONMENT OBJECT MANIFEST CHECK maps=%d variants=%d rows=%d roundtrips=%d jazz_hosts=6 lottery_counters=4 ok=true" % [
			_authored_maps,
			_runtime_variants,
			_manifest_rows,
			_roundtrips,
		])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check_authored_map_coverage(library: ContentLibrary) -> void:
	var expected_ids: Dictionary = {}
	for archetype_value in library.environment_archetypes:
		var archetype := _dict(archetype_value)
		var archetype_id := str(archetype.get("id", "")).strip_edges()
		if archetype_id.is_empty():
			continue
		expected_ids[archetype_id] = true
		for layer_id_value in _dict(archetype.get("layers", {})).keys():
			expected_ids["%s:%s" % [archetype_id, str(layer_id_value)]] = true
	var root := _read_json_dictionary(PLACEMENT_MAP_PATH)
	var actual_ids: Dictionary = {}
	for map_value in _array(root.get("maps", [])):
		var map_data := _dict(map_value)
		var map_id := str(map_data.get("id", "")).strip_edges()
		if map_id.is_empty():
			_fail("placement maps", "contains a map without an id")
			continue
		if actual_ids.has(map_id):
			_fail("placement maps", "repeats %s" % map_id)
		actual_ids[map_id] = true
		_authored_maps += 1
		_check_surface_families(map_id, map_data)
	for expected_id_value in expected_ids.keys():
		var expected_id := str(expected_id_value)
		if not actual_ids.has(expected_id):
			_fail("placement maps", "is missing environment definition %s" % expected_id)
	for actual_id_value in actual_ids.keys():
		var actual_id := str(actual_id_value)
		if not expected_ids.has(actual_id):
			_fail("placement maps", "contains orphaned environment definition %s" % actual_id)


func _check_surface_families(label: String, surface_map: Dictionary) -> void:
	_check(int(surface_map.get("slot_schema_version", 0)) == EnvironmentPlacementScript.SLOT_SCHEMA_VERSION, label, "does not use the current slot schema")
	for family in FAMILIES:
		var field := "%s_slots" % family
		_check(typeof(surface_map.get(field)) == TYPE_ARRAY, label, "is missing %s" % field)
		for slot_value in _array(surface_map.get(field, [])):
			var slot := _dict(slot_value)
			var slot_id := str(slot.get("id", "")).strip_edges()
			_check(str(slot.get("kind", "")) == family, label, "%s has the wrong family" % slot_id)
			_check(slot_id.begins_with("%s." % family), label, "%s does not use its family prefix" % slot_id)


func _check_runtime_variant(archetype: Dictionary, layer_id: String, library: ContentLibrary) -> void:
	var archetype_id := str(archetype.get("id", "")).strip_edges()
	var label := archetype_id if layer_id.is_empty() else "%s:%s" % [archetype_id, layer_id]
	var rng := RngStreamScript.new()
	rng.configure(RngStreamScript.derive_seed(902_806, 902_806, label))
	var instance = EnvironmentInstanceScript.from_archetype(archetype, 1, rng, library) \
			if layer_id.is_empty() else EnvironmentInstanceScript.from_archetype_layer(archetype, layer_id, 1, rng, library)
	var environment: Dictionary = instance.to_dict()
	_runtime_variants += 1
	if archetype_id == "jazz_club" and layer_id.is_empty():
		_jazz_environment = environment.duplicate(true)
	if _ordinary_event_environment.is_empty():
		for row_value in EnvironmentInstanceScript.active_object_manifest_rows(environment, "event"):
			var row := _dict(row_value)
			if str(row.get("presentation_object_id", "")).begins_with("event:"):
				_ordinary_event_environment = environment.duplicate(true)
				break
	_check_manifest_and_bindings(label, environment)
	_check_json_roundtrip(label, environment, library)


func _check_tutorial_home_item_manifest(library: ContentLibrary) -> void:
	var config := library.challenge_config_for("tutorial_first_card", "FIRST-NIGHT-ACE-17")
	var run_state := RunStateScript.new()
	run_state.start_new("FIRST-NIGHT-ACE-17", config)
	var generator := RunGeneratorScript.new(library)
	generator.next_environment(run_state)
	var environment: Dictionary = run_state.current_environment
	var manifest_row: Dictionary = {}
	for row_value in EnvironmentInstanceScript.active_object_manifest_rows(environment, "fixed"):
		var row := _dict(row_value)
		if str(row.get("presentation_object_id", "")) == "item:xray_glasses":
			manifest_row = row
			break
	var binding: Dictionary = _dict(_dict(_dict(environment.get("layout", {})).get("slot_bindings", {})).get("item:xray_glasses", {}))
	_check(not manifest_row.is_empty(), "tutorial apartment", "is missing the X-ray Glasses manifest row")
	_check(str(manifest_row.get("placement_class", "")) == "surface_item", "tutorial apartment", "classified the free home pickup as shop merchandise")
	_check(str(binding.get("slot_id", "")) == "fixed.home_item_1", "tutorial apartment", "did not bind the free pickup to fixed.home_item_1")
	_check(str(binding.get("placement_class", "")) == str(manifest_row.get("placement_class", "")), "tutorial apartment", "manifest and binding disagree on the free pickup class")
	_check(EnvironmentInstanceScript.object_manifest_errors(environment).is_empty(), "tutorial apartment", "failed strict manifest validation")
	var authority := EnvironmentSlotBinderScript.validate_base_layout_authority(environment, [manifest_row], false)
	_check(bool(authority.get("ok", false)), "tutorial apartment", "rejected the X-ray Glasses during persisted slot-authority replay: %s" % JSON.stringify(authority.get("errors", [])))


func _check_category_family_authority(library: ContentLibrary) -> void:
	# A physical catalog object may use authored category capacity even without an
	# identity-local override. The category does not, by itself, turn an abstract
	# service verb into another physical room object.
	var environment := {
		"id": "category_family_fixture",
		"archetype_id": "corner_store",
		"display_name": "Category Family Fixture",
		"kind": "casino",
		"tier": 1,
		"game_ids": [],
		"event_ids": [],
		"resolved_event_ids": [],
		"item_offers": [],
		"service_ids": ["cashier_tip"],
		"lender_hooks": ["street_lender"],
		"travel_hooks": [],
		"next_archetypes": [],
		"object_fixtures": [],
	}
	environment["layout"] = EnvironmentInstanceScript.ensure_generated_layout(environment, library)
	_check(EnvironmentInstanceScript.object_manifest_errors(environment).is_empty(), "category family authority", "produced an invalid manifest")
	_check(_array(_dict(environment.get("layout", {})).get("placement_errors", [])).is_empty(), "category family authority", "failed layout generation: %s" % JSON.stringify(_dict(environment.get("layout", {})).get("placement_errors", [])))
	var rows: Dictionary = {}
	for row_value in EnvironmentInstanceScript.active_object_manifest_rows(environment):
		var row := _dict(row_value)
		rows[str(row.get("presentation_object_id", ""))] = row
	var bindings := _dict(_dict(environment.get("layout", {})).get("slot_bindings", {}))
	for expectation in [
		["event:call_brother_in_law", "fixed", "fixed.phone"],
		["lender:street_lender", "fixed", "fixed.lender_floor_1"],
	]:
		var object_id := str(expectation[0])
		var family := str(expectation[1])
		var slot_id := str(expectation[2])
		_check(str(_dict(rows.get(object_id, {})).get("family", "")) == family, "category family authority", "%s did not inherit its authored %s category family" % [object_id, family])
		var binding := _dict(bindings.get(object_id, {}))
		_check(str(binding.get("slot_family", "")) == family and str(binding.get("slot_id", "")) == slot_id, "category family authority", "%s did not bind through its authored category slot %s" % [object_id, slot_id])
	var phone_row := _dict(rows.get("event:call_brother_in_law", {}))
	_check(str(phone_row.get("instance_object_id", "")) == "corner_store:phone" and _array(phone_row.get("action_ids", [])).has("service:cashier_tip"), "category family authority", "the cashier-tip action is not owned by the guaranteed store phone")
	var surface_map := EnvironmentPlacementScript.surface_map(environment)
	_check(not _dict(surface_map.get("object_family_ids", {})).has("lender:street_lender"), "category family authority", "fixture no longer exercises category-only family authority")
	_check(str(_dict(surface_map.get("fixed_category_slot_ids", {})).get("lender_spots:0", "")) == "fixed.lender_floor_1", "category family authority", "fixture is missing its authored lender category slot")
	var lender_entry := {
		"object_id": "lender:street_lender",
		"object_type": "lender",
		"spot_field": "lender_spots",
		"index": 0,
	}
	_check(EnvironmentSlotBinderScript.authored_entry_slot_family(surface_map, lender_entry, "lender:street_lender") == "fixed", "category family authority", "shared family resolver did not resolve the lender category")
	_check(EnvironmentSlotBinderScript.authored_entry_slot_family(surface_map, lender_entry, "lender:street_lender", "", false).is_empty(), "category family authority", "category capacity was mistaken for identity-local physical-presence authority")
	var authority := EnvironmentSlotBinderScript.validate_base_layout_authority(environment, [rows.get("lender:street_lender", {})], false)
	_check(bool(authority.get("ok", false)), "category family authority", "rejected category-authorized lender binding: %s" % JSON.stringify(authority.get("errors", [])))
	# Scenario semantic replay carries a closed record and the already-sealed room
	# occupancy. Rebinding that same identity must recognize its category-derived
	# physical family instead of dropping the binding and colliding with its own
	# occupancy claim.
	var closed_lender_record := {
		"object_id": "lender:street_lender",
		"object_type": "lender",
		"slot_family": "fixed",
		"placement_class": str(_dict(rows.get("lender:street_lender", {})).get("placement_class", "")),
		"interactive": true,
	}
	var sealed_occupancy: Dictionary = {}
	for binding_value in bindings.values():
		var sealed_binding := _dict(binding_value)
		var sealed_slot_id := str(sealed_binding.get("slot_id", "")).strip_edges()
		var sealed_identity := str(sealed_binding.get("identity", "")).strip_edges()
		if not sealed_slot_id.is_empty() and not sealed_identity.is_empty():
			sealed_occupancy[sealed_slot_id] = sealed_identity
	var replay := EnvironmentSlotBinderScript.bind_base_records(environment, [closed_lender_record], bindings, sealed_occupancy)
	_check(bool(replay.get("ok", false)), "category family authority", "closed semantic replay collided with its own category-authorized slot: %s" % JSON.stringify(replay.get("errors", [])))
	_check(str(_dict(_dict(replay.get("slot_bindings", {})).get("lender:street_lender", {})).get("slot_id", "")) == "fixed.lender_floor_1", "category family authority", "closed semantic replay lost the category-authorized lender slot")
	var parsed: Variant = JSON.parse_string(JSON.stringify(environment))
	var restored: Dictionary = EnvironmentInstanceScript.from_dict(parsed as Dictionary).to_dict() if typeof(parsed) == TYPE_DICTIONARY else {}
	if not restored.is_empty():
		EnvironmentInstanceScript.reconcile_object_manifest(restored, library)
	var restored_binding: Dictionary = _dict(_dict(_dict(restored.get("layout", {})).get("slot_bindings", {})).get("lender:street_lender", {}))
	_check(not restored.is_empty() and EnvironmentInstanceScript.object_manifest_errors(restored).is_empty() and str(restored_binding.get("slot_id", "")) == "fixed.lender_floor_1", "category family authority", "JSON roundtrip lost category-authorized manifest/binding authority")


func _check_manifest_and_bindings(label: String, environment: Dictionary) -> void:
	var errors := EnvironmentInstanceScript.object_manifest_errors(environment)
	_check(errors.is_empty(), label, "manifest validation failed: %s" % JSON.stringify(errors))
	var manifest := _dict(environment.get("object_manifest", {}))
	_check(str(environment.get("object_manifest_digest", "")) == str(manifest.get("digest", "")), label, "manifest digest mirror is stale")
	_check(int(environment.get("object_manifest_revision", 0)) == int(manifest.get("revision", -1)), label, "manifest revision mirror is stale")
	var rows := EnvironmentInstanceScript.active_object_manifest_rows(environment)
	_manifest_rows += rows.size()
	var row_families: Dictionary = {}
	for row_value in rows:
		var row := _dict(row_value)
		var object_id := str(row.get("object_id", row.get("presentation_object_id", ""))).strip_edges()
		var family := str(row.get("family", "")).strip_edges()
		_check(not object_id.is_empty(), label, "contains an active physical manifest row without an object id")
		_check(family in FAMILIES, label, "%s has invalid family %s" % [object_id, family])
		_check(not row_families.has(object_id), label, "repeats active physical presentation %s" % object_id)
		row_families[object_id] = family
	var layout := _dict(environment.get("layout", {}))
	_check(_array(layout.get("placement_errors", [])).is_empty(), label, "layout generation failed: %s" % JSON.stringify(layout.get("placement_errors", [])))
	var bindings := _dict(layout.get("slot_bindings", {}))
	for object_id_value in row_families.keys():
		var object_id := str(object_id_value)
		var family := str(row_families.get(object_id, ""))
		var binding := _dict(bindings.get(object_id, {}))
		_check(not binding.is_empty(), label, "%s has no slot binding" % object_id)
		_check(str(binding.get("presentation_mode", "")) == "room", label, "%s is not presented in the room" % object_id)
		_check(str(binding.get("slot_family", "")) == family, label, "%s crossed from %s into %s" % [object_id, family, str(binding.get("slot_family", ""))])
		_check(str(binding.get("slot_id", "")).begins_with("%s." % family), label, "%s has an invalid family-scoped slot" % object_id)
	for object_id_value in bindings.keys():
		var object_id := str(object_id_value)
		_check(row_families.has(object_id), label, "slot binding %s has no active physical manifest row" % object_id)


func _check_json_roundtrip(label: String, environment: Dictionary, library: ContentLibrary) -> void:
	var parsed_value: Variant = JSON.parse_string(JSON.stringify(environment))
	_check(typeof(parsed_value) == TYPE_DICTIONARY, label, "could not parse its JSON save projection")
	if typeof(parsed_value) != TYPE_DICTIONARY:
		return
	var restored_instance = EnvironmentInstanceScript.from_dict(parsed_value as Dictionary)
	var restored: Dictionary = restored_instance.to_dict()
	# Reconciliation with the live library must be a no-op after a normal reload.
	var before := _dict(restored.get("object_manifest", {})).duplicate(true)
	EnvironmentInstanceScript.reconcile_object_manifest(restored, library)
	var after := _dict(restored.get("object_manifest", {}))
	_check(EnvironmentInstanceScript.object_manifest_errors(restored).is_empty(), label, "JSON reload produced an invalid manifest")
	_check(str(after.get("digest", "")) == str(_dict(environment.get("object_manifest", {})).get("digest", "")), label, "JSON reload changed deterministic manifest content")
	_check(_array(after.get("rows", [])) == _array(_dict(environment.get("object_manifest", {})).get("rows", [])), label, "JSON reload changed deterministic manifest rows")
	_check(before == after, label, "unchanged reconciliation advanced or rewrote the JSON-restored manifest")
	_roundtrips += 1


func _check_jazz_guarantees() -> void:
	_check(not _jazz_environment.is_empty(), "jazz_club", "was not generated by the all-environment pass")
	if _jazz_environment.is_empty():
		return
	var expectations := {
		"jazz_club:bartender": ["shopkeeper:merchant", "fixed.staff_bartender", "service:house_drink"],
		"jazz_club:musician_sax": ["musician:jazz_sax", "fixed.musician_sax", "service:jazz_sax_round"],
		"jazz_club:musician_cello": ["musician:jazz_cello", "fixed.musician_cello", "service:jazz_cello_round"],
		"jazz_club:musician_drummer": ["musician:jazz_drummer", "fixed.musician_drummer", "service:jazz_drummer_round"],
		"jazz_club:band_tip_jar": ["service:jazz_band_tip_jar", "fixed.tip_jar_band", "service:jazz_band_tip_jar"],
		"jazz_club:band_stage": ["fixture:jazz_band_stage", "fixed.band_stage", "service:listen_to_jazz"],
	}
	var manifest := _dict(_jazz_environment.get("object_manifest", {}))
	var rows_by_instance: Dictionary = {}
	var action_owners: Dictionary = {}
	for row_value in _array(manifest.get("rows", [])):
		var row := _dict(row_value)
		rows_by_instance[str(row.get("instance_object_id", ""))] = row
		for action_id_value in _array(row.get("action_ids", [])):
			var action_id := str(action_id_value)
			var owners := _array(action_owners.get(action_id, []))
			owners.append(str(row.get("instance_object_id", "")))
			action_owners[action_id] = owners
	var bindings := _dict(_dict(_jazz_environment.get("layout", {})).get("slot_bindings", {}))
	for instance_id_value in expectations.keys():
		var instance_id := str(instance_id_value)
		var expected := _array(expectations.get(instance_id, []))
		var presentation_id := str(expected[0])
		var exact_slot_id := str(expected[1])
		var action_id := str(expected[2])
		var row := _dict(rows_by_instance.get(instance_id, {}))
		_check(not row.is_empty(), "jazz_club", "is missing guaranteed host %s" % instance_id)
		_check(str(row.get("presentation_object_id", "")) == presentation_id, "jazz_club", "%s has the wrong presentation identity" % instance_id)
		_check(str(row.get("family", "")) == "fixed", "jazz_club", "%s is not fixed" % instance_id)
		_check(bool(row.get("required", false)) and bool(row.get("active", false)) and bool(row.get("physical", false)), "jazz_club", "%s is not guaranteed active physical inventory" % instance_id)
		_check(str(row.get("exact_slot_id", "")) == exact_slot_id, "jazz_club", "%s lost exact slot %s" % [instance_id, exact_slot_id])
		_check(_array(row.get("action_ids", [])).has(action_id), "jazz_club", "%s does not host action %s" % [instance_id, action_id])
		var binding := _dict(bindings.get(presentation_id, {}))
		_check(str(binding.get("slot_id", "")) == exact_slot_id, "jazz_club", "%s did not bind to %s" % [instance_id, exact_slot_id])
		_check(_array(action_owners.get(action_id, [])).size() == 1 and str(_array(action_owners.get(action_id, []))[0]) == instance_id, "jazz_club", "action %s is not owned by exactly one guaranteed host" % action_id)


func _check_lottery_counter_hosts(library: ContentLibrary) -> void:
	var expected_hosts := {
		"bar": "staff:bar_bartender",
		"gas_station_casino": "character:nell",
		"jazz_club": "shopkeeper:merchant",
		"grand_casino": "casino_fixture:host_desk",
	}
	var base_counter_actions := [
		"game:pull_tabs",
		"dialogue:pull_tab_clerk",
		"game_hook:pull_tabs:ticket_redeemer",
	]
	for archetype_id_value in expected_hosts.keys():
		var archetype_id := str(archetype_id_value)
		var host_id := str(expected_hosts.get(archetype_id, ""))
		var label := "%s lottery counter" % archetype_id
		var environment := _generated_environment(library, archetype_id)
		var selected_game_ids := _array(environment.get("game_ids", []))
		if not selected_game_ids.has("pull_tabs"):
			selected_game_ids.append("pull_tabs")
		environment["game_ids"] = selected_game_ids
		var game_states := _dict(environment.get("game_states", {}))
		game_states["pull_tabs"] = {
			"environment_hooks": [
				{"id": "ticket_redeemer", "object_id": "game_hook:pull_tabs:ticket_redeemer", "unique_object_class": "pull_tab_clerk"},
				{"id": "pull_tab_clerk_dialogue", "object_id": "dialogue:pull_tab_clerk", "dialogue_id": "pull_tab_clerk", "unique_object_class": "pull_tab_clerk"},
			],
		}
		if archetype_id == "gas_station_casino":
			game_states["scratch_tickets"] = {
				"environment_hooks": [
					{"id": "scratch_ticket_clerk", "object_id": "game_hook:scratch_tickets:scratch_ticket_clerk", "unique_object_class": "scratch_ticket_clerk"},
				],
			}
		environment["game_states"] = game_states
		environment["layout"] = EnvironmentInstanceScript.ensure_generated_layout(environment, library)
		var manifest := _dict(environment.get("object_manifest", {}))
		var host_row := _active_manifest_row(manifest, host_id)
		_check(not host_row.is_empty(), label, "is missing its configured physical counter host %s" % host_id)
		var expected_actions := base_counter_actions.duplicate()
		if archetype_id == "gas_station_casino":
			expected_actions.append("game_hook:scratch_tickets:scratch_ticket_clerk")
		for action_id_value in expected_actions:
			var action_id := str(action_id_value)
			_check(_array(host_row.get("action_ids", [])).has(action_id), label, "%s does not own counter action %s" % [host_id, action_id])
		for forbidden_id in [
			"game:pull_tabs",
			"dialogue:pull_tab_clerk",
			"game_hook:pull_tabs:ticket_redeemer",
			"game_hook:scratch_tickets:scratch_ticket_clerk",
		]:
			_check(_active_manifest_row(manifest, forbidden_id).is_empty(), label, "created duplicate physical row %s" % forbidden_id)
		var bindings := _dict(_dict(environment.get("layout", {})).get("slot_bindings", {}))
		_check(bindings.has(host_id), label, "%s lost its physical slot binding" % host_id)
		for forbidden_id in ["game:pull_tabs", "dialogue:pull_tab_clerk", "game_hook:pull_tabs:ticket_redeemer", "game_hook:scratch_tickets:scratch_ticket_clerk"]:
			_check(not bindings.has(forbidden_id), label, "%s incorrectly consumed its own placement slot" % forbidden_id)
		if archetype_id in ["bar", "gas_station_casino", "grand_casino"]:
			var unstocked := _generated_environment(library, archetype_id)
			var unstocked_game_ids := _array(unstocked.get("game_ids", []))
			unstocked_game_ids.erase("pull_tabs")
			unstocked["game_ids"] = unstocked_game_ids
			var unstocked_states := _dict(unstocked.get("game_states", {}))
			unstocked_states.erase("pull_tabs")
			unstocked["game_states"] = unstocked_states
			unstocked["layout"] = EnvironmentInstanceScript.ensure_generated_layout(unstocked, library)
			var unstocked_host := _active_manifest_row(_dict(unstocked.get("object_manifest", {})), host_id)
			for action_id_value in base_counter_actions:
				var action_id := str(action_id_value)
				_check(not _array(unstocked_host.get("action_ids", [])).has(action_id), "%s unstocked counter" % archetype_id, "%s advertised unavailable counter action %s" % [host_id, action_id])
		if archetype_id == "gas_station_casino":
			var scratchless := _generated_environment(library, archetype_id)
			var scratchless_game_ids := _array(scratchless.get("game_ids", []))
			scratchless_game_ids.erase("scratch_tickets")
			scratchless["game_ids"] = scratchless_game_ids
			var scratchless_states := _dict(scratchless.get("game_states", {}))
			scratchless_states.erase("scratch_tickets")
			scratchless["game_states"] = scratchless_states
			scratchless["layout"] = EnvironmentInstanceScript.ensure_generated_layout(scratchless, library)
			var scratchless_host := _active_manifest_row(_dict(scratchless.get("object_manifest", {})), host_id)
			_check(
				not _array(scratchless_host.get("action_ids", [])).has("game_hook:scratch_tickets:scratch_ticket_clerk"),
				"gas_station_casino scratchless counter",
				"Nell advertised Scratcher cashout without Scratch Tickets selected"
			)


func _check_grand_casino_rumor_host(library: ContentLibrary) -> void:
	var environment := _generated_environment(library, "grand_casino")
	var event_ids := _array(environment.get("event_ids", []))
	if not event_ids.has("town_rumor_staff"):
		event_ids.append("town_rumor_staff")
	environment["event_ids"] = event_ids
	environment["resolved_event_ids"] = []
	environment["layout"] = EnvironmentInstanceScript.ensure_generated_layout(environment, library)
	var host_id := "staff:grand_casino_host"
	var action_id := "event:town_rumor_staff"
	var manifest := _dict(environment.get("object_manifest", {}))
	var host_row := _active_manifest_row(manifest, host_id)
	var bindings := _dict(_dict(environment.get("layout", {})).get("slot_bindings", {}))
	_check(str(host_row.get("instance_object_id", "")) == "grand_casino:floor_host", "grand casino rumor host", "Iris is not the fixed floor-host manifest identity")
	_check(str(host_row.get("family", "")) == "fixed" and _array(host_row.get("action_ids", [])).has(action_id), "grand casino rumor host", "Iris does not own the town-rumor action")
	_check(_active_manifest_row(manifest, action_id).is_empty(), "grand casino rumor host", "town-rumor dialogue minted a duplicate physical staff row")
	_check(str(_dict(bindings.get(host_id, {})).get("slot_id", "")) == "fixed.staff_host", "grand casino rumor host", "Iris lost her authenticated fixed slot")
	_check(not bindings.has(action_id), "grand casino rumor host", "town-rumor dialogue claimed an independent slot")
	var joined := EnvironmentInteractionControllerScript._join_object_manifest([
		{
			"object_id": action_id,
			"object_type": "event",
			"source_id": "town_rumor_staff",
			"confirm_action_id": "inspect_event_choices",
			"available_actions": [{"id": "inspect_event_choices", "source_id": action_id}],
		},
	], environment, true)
	var action_record := _record_by_id(joined, action_id)
	_check(str(action_record.get("slot_binding_source_id", "")) == host_id, "grand casino rumor host", "town-rumor dialogue did not attach to Iris")


func _check_grand_casino_live_table(library: ContentLibrary) -> void:
	var object_id := "event:heist_live_table"
	var classified := EnvironmentPlacementScript.classify(
		{"role": "staff", "visual_prop": "card_table"},
		"event",
		object_id,
		"card_table"
	)
	_check(classified == "floor_fixture", "grand casino live table", "card-table furniture was classified from its dialogue speaker instead of its physical prop")
	for archetype_id in ["grand_casino", "grand_casino_high_limit", "grand_casino_back_room", "grand_casino_cage"]:
		var environment := _generated_environment(library, archetype_id)
		var event_ids := _array(environment.get("event_ids", []))
		if not event_ids.has("heist_live_table"):
			event_ids.append("heist_live_table")
		environment["event_ids"] = event_ids
		var resolved_ids := _array(environment.get("resolved_event_ids", []))
		resolved_ids.erase("heist_live_table")
		environment["resolved_event_ids"] = resolved_ids
		var label := "%s live table" % archetype_id
		var run_state := RunStateScript.new()
		run_state.current_environment = environment
		var reconciled := run_state.reconcile_environment_object_membership(environment)
		_check(bool(reconciled.get("ok", false)), label, "runtime membership failed: %s" % JSON.stringify(reconciled.get("errors", [])))
		var surface_map := EnvironmentPlacementScript.surface_map(environment)
		var manifest := _dict(environment.get("object_manifest", {}))
		var row := _active_manifest_row(manifest, object_id)
		var bindings := _dict(_dict(environment.get("layout", {})).get("slot_bindings", {}))
		var binding := _dict(bindings.get(object_id, {}))
		var runtime_projection: Dictionary = {}
		for entry_value in _array(environment.get("runtime_object_manifest_entries", [])):
			var entry := _dict(entry_value)
			if str(entry.get("object_id", "")) == object_id:
				runtime_projection = entry
				break
		_check(str(_dict(surface_map.get("object_family_ids", {})).get(object_id, "")) == "scenario", label, "The Live Table lost scenario lifecycle ownership")
		for family in FAMILIES:
			_check(not _dict(surface_map.get("%s_object_slot_ids" % family, {})).has(object_id), label, "The Live Table stopped using shared scenario capacity")
		_check(str(runtime_projection.get("runtime_owner", "")) == "crew_heist_live_table" and str(runtime_projection.get("spot_field", "")) == "runtime_object_manifest_entries", label, "The Live Table was not rebuilt from its trusted Crew runtime projection")
		_check(str(row.get("family", "")) == "scenario" and str(row.get("placement_class", "")) == "floor_fixture", label, "The Live Table did not become scenario-owned furniture")
		_check(str(row.get("spot_field", "")) == "runtime_object_manifest_entries", label, "The Live Table manifest row did not retain runtime projection provenance")
		_check(str(binding.get("slot_family", "")) == "scenario" and str(binding.get("placement_class", "")) == "floor_fixture", label, "The Live Table did not bind through scenario furniture capacity")
		_check(str(binding.get("slot_id", "")).begins_with("scenario.floor_fixture_"), label, "The Live Table did not claim a generic scenario floor-fixture slot")
		if archetype_id == "grand_casino":
			var hostile_map := surface_map.duplicate(true)
			var hostile_event_preferences := _dict(hostile_map.get("event_object_slot_ids", {}))
			hostile_event_preferences[object_id] = "event.behind_counter_person_1"
			hostile_map["event_object_slot_ids"] = hostile_event_preferences
			var hostile_errors := EnvironmentSlotBinderScript._surface_map_errors(hostile_map)
			_check(not hostile_errors.is_empty(), label, "cross-family live-table authoring was not rejected")

		# Event membership is the sole runtime authority. Removing it must delete the
		# trusted projection, manifest row, geometry, and binding in one reconciliation.
		event_ids.erase("heist_live_table")
		environment["event_ids"] = event_ids
		var cleanup := run_state.reconcile_environment_object_membership(environment)
		_check(bool(cleanup.get("ok", false)), label, "runtime cleanup failed: %s" % JSON.stringify(cleanup.get("errors", [])))
		_assert_runtime_membership(environment, object_id, "scenario", false, "%s cleanup" % label)
		for entry_value in _array(environment.get("runtime_object_manifest_entries", [])):
			var entry := _dict(entry_value)
			_check(str(entry.get("runtime_owner", "")) != "crew_heist_live_table", label, "The Live Table runtime projection survived event removal")


func _check_missing_and_stale_regeneration(library: ContentLibrary) -> void:
	if _jazz_environment.is_empty():
		return
	var original := _dict(_jazz_environment.get("object_manifest", {}))
	var absent := _jazz_environment.duplicate(true)
	absent.erase("object_manifest")
	absent.erase("object_manifest_digest")
	absent.erase("object_manifest_revision")
	var absent_restored: Dictionary = EnvironmentInstanceScript.from_dict(absent).to_dict()
	var absent_manifest := _dict(absent_restored.get("object_manifest", {}))
	_check(EnvironmentInstanceScript.object_manifest_errors(absent_restored).is_empty(), "manifest regeneration", "did not rebuild a missing manifest during reload")
	_check(str(absent_manifest.get("digest", "")) == str(original.get("digest", "")), "manifest regeneration", "missing-manifest rebuild was not deterministic")
	_check(_array(absent_manifest.get("rows", [])) == _array(original.get("rows", [])), "manifest regeneration", "missing-manifest rebuild changed rows")

	var stale := _jazz_environment.duplicate(true)
	var stale_manifest := _dict(stale.get("object_manifest", {})).duplicate(true)
	var stale_revision := int(stale_manifest.get("revision", 0))
	stale_manifest["source_digest"] = "0".repeat(64)
	stale["object_manifest"] = stale_manifest
	var stale_restored: Dictionary = EnvironmentInstanceScript.from_dict(stale).to_dict()
	var repaired := _dict(stale_restored.get("object_manifest", {}))
	_check(EnvironmentInstanceScript.object_manifest_errors(stale_restored).is_empty(), "manifest regeneration", "did not repair a stale manifest during reload")
	_check(str(repaired.get("digest", "")) == str(original.get("digest", "")), "manifest regeneration", "stale-manifest repair was not deterministic")
	_check(_array(repaired.get("rows", [])) == _array(original.get("rows", [])), "manifest regeneration", "stale-manifest repair changed rows")
	_check(int(repaired.get("revision", 0)) > stale_revision, "manifest regeneration", "stale-manifest repair did not advance its revision")
	var repaired_before := repaired.duplicate(true)
	EnvironmentInstanceScript.reconcile_object_manifest(stale_restored, library)
	_check(_dict(stale_restored.get("object_manifest", {})) == repaired_before, "manifest regeneration", "a second reconciliation rewrote the repaired manifest")


func _check_scenario_manifest_retention_validation(library: ContentLibrary) -> void:
	if _jazz_environment.is_empty():
		return
	# Use a real scenario-added event identity. It appears both in the ordinary
	# active-entry projection and in the authored renderer snapshot, which is the
	# collision that previously made a valid rendererless save look stale.
	var scenario_object_id := "event:scenario_engine_trouble_repairs"
	var environment := _jazz_environment.duplicate(true)
	var event_ids := _array(environment.get("event_ids", [])).duplicate(true)
	if not event_ids.has("scenario_engine_trouble_repairs"):
		event_ids.append("scenario_engine_trouble_repairs")
	environment["event_ids"] = event_ids
	environment["scenario_state"] = {
		"id": "manifest_retention_fixture",
		"phase_index": 0,
		"phase_action_counter": 0,
		"mutations": {"event_pool_add": ["scenario_engine_trouble_repairs"]},
	}
	environment["scenario_render_snapshot"] = {
		"ok": true,
		"scenario_id": "manifest_retention_fixture",
		"phase_id": "arrival",
		"visual_objects": [{
			"object_id": scenario_object_id,
			"stable_object_id": "manifest_retention_fixture",
			"object_type": "scenario_object",
			"placement_class": "surface_item",
			"slot_id": "scenario.surface_item_1",
			"render_key": "paper_note",
			"present": true,
			"visible": true,
		}],
		"interaction_overlays": [],
	}
	EnvironmentInstanceScript.reconcile_object_manifest(environment, library)
	var trusted_manifest := _dict(environment.get("object_manifest", {})).duplicate(true)
	_check(str(_active_manifest_row(trusted_manifest, scenario_object_id).get("render_key", "")) == "paper_note", "scenario manifest retention", "fixture did not produce a valid scenario manifest row")

	# A valid, source-matching saved manifest remains the exact presentation bridge
	# while the noncausal renderer snapshot is absent.
	environment.erase("scenario_render_snapshot")
	EnvironmentInstanceScript.reconcile_object_manifest(environment, library)
	_check(_dict(environment.get("object_manifest", {})) == trusted_manifest, "scenario manifest retention", "valid saved scenario rows were not retained exactly without a renderer snapshot")

	# Corrupt one canonical row without updating the digest. Reconciliation must
	# regenerate from trusted gameplay sources and must never sign the forged row.
	var forged_environment := environment.duplicate(true)
	var forged_manifest := trusted_manifest.duplicate(true)
	var forged_rows := _array(forged_manifest.get("rows", [])).duplicate(true)
	for index in range(forged_rows.size()):
		var row := _dict(forged_rows[index]).duplicate(true)
		if str(row.get("presentation_object_id", "")) != scenario_object_id:
			continue
		row["render_key"] = "forged_renderer"
		row["action_ids"] = ["forged_action"]
		forged_rows[index] = row
	forged_manifest["rows"] = forged_rows
	forged_environment["object_manifest"] = forged_manifest
	forged_environment["object_manifest_digest"] = str(forged_manifest.get("digest", ""))
	EnvironmentInstanceScript.reconcile_object_manifest(forged_environment, library)
	var repaired_manifest := _dict(forged_environment.get("object_manifest", {}))
	var repaired_errors := EnvironmentInstanceScript.object_manifest_errors(forged_environment)
	_check(repaired_errors.is_empty(), "scenario manifest retention", "invalid saved scenario manifest was not repaired: %s" % JSON.stringify(repaired_errors))
	_check(_active_manifest_row(repaired_manifest, scenario_object_id).is_empty(), "scenario manifest retention", "invalid saved scenario row was retained and re-signed")
	var joined := EnvironmentInteractionControllerScript._join_object_manifest([{"object_id": scenario_object_id}], forged_environment, false)
	var joined_record := _record_by_id(joined, scenario_object_id)
	_check(str(joined_record.get("manifest_render_key", "")) != "forged_renderer" and not _array(joined_record.get("manifest_action_ids", [])).has("forged_action"), "scenario manifest retention", "forged scenario manifest authority reached a live interaction record")


func _check_resolved_event_lifecycle(library: ContentLibrary) -> void:
	_check(not _ordinary_event_environment.is_empty(), "resolved event manifest", "all-environment fixture did not select an ordinary physical event")
	if _ordinary_event_environment.is_empty():
		return
	var original_manifest := _dict(_ordinary_event_environment.get("object_manifest", {}))
	var event_row: Dictionary = {}
	for row_value in EnvironmentInstanceScript.active_object_manifest_rows(_ordinary_event_environment, "event"):
		var row := _dict(row_value)
		if str(row.get("presentation_object_id", "")).begins_with("event:"):
			event_row = row
			break
	_check(not event_row.is_empty(), "resolved event manifest", "selected fixture has no ordinary event-family manifest row")
	if event_row.is_empty():
		return
	var object_id := str(event_row.get("presentation_object_id", ""))
	var event_id := object_id.trim_prefix("event:")
	_check(_active_manifest_row(original_manifest, object_id).get("family", "") == "event", "resolved event manifest", "%s did not begin as active event-family inventory" % object_id)

	# Keep a stale pre-resolution envelope to prove the presentation join cannot
	# synthesize a consumed event even before a legacy caller reconciles it.
	var stale_environment := _ordinary_event_environment.duplicate(true)
	stale_environment["resolved_event_ids"] = [event_id]
	var stale_join := EnvironmentInteractionControllerScript._join_object_manifest([], stale_environment, true)
	_check(_record_by_id(stale_join, object_id).is_empty(), "resolved event manifest", "stale manifest synthesis resurrected %s" % object_id)

	var run_state := RunStateScript.new()
	run_state.current_environment = _ordinary_event_environment.duplicate(true)
	var original_revision := int(original_manifest.get("revision", 0))
	run_state.resolve_event(event_id)
	var resolved_environment: Dictionary = run_state.current_environment
	var resolved_manifest := _dict(resolved_environment.get("object_manifest", {}))
	_check(_active_manifest_row(resolved_manifest, object_id).is_empty(), "resolved event manifest", "%s remained active after resolve_event" % object_id)
	_check(int(resolved_manifest.get("revision", 0)) > original_revision, "resolved event manifest", "resolution did not advance manifest revision")
	_check(str(resolved_manifest.get("source_digest", "")) != str(original_manifest.get("source_digest", "")), "resolved event manifest", "resolution did not change manifest source authority")
	_check(EnvironmentInstanceScript.object_manifest_errors(resolved_environment).is_empty(), "resolved event manifest", "resolution produced an invalid manifest")

	# Layout refresh must consume the filtered manifest, free the event slot, and
	# remain stable through the save-shaped EnvironmentInstance restoration path.
	resolved_environment["layout"] = EnvironmentInstanceScript.ensure_generated_layout(resolved_environment, library)
	var resolved_layout := _dict(resolved_environment.get("layout", {}))
	_check(not _dict(resolved_layout.get("slot_bindings", {})).has(object_id), "resolved event manifest", "%s retained a slot binding after layout refresh" % object_id)
	_check(not _dict(resolved_layout.get("object_rects", {})).has(object_id), "resolved event manifest", "%s retained room geometry after layout refresh" % object_id)
	var parsed_value: Variant = JSON.parse_string(JSON.stringify(resolved_environment))
	if typeof(parsed_value) != TYPE_DICTIONARY:
		_fail("resolved event manifest", "resolved environment did not survive JSON serialization")
		return
	var restored := EnvironmentInstanceScript.from_dict(parsed_value as Dictionary).to_dict()
	_check(_active_manifest_row(_dict(restored.get("object_manifest", {})), object_id).is_empty(), "resolved event manifest", "JSON restore resurrected %s in the manifest" % object_id)
	_check(not _dict(_dict(restored.get("layout", {})).get("slot_bindings", {})).has(object_id), "resolved event manifest", "JSON restore resurrected %s in slot bindings" % object_id)


func _check_resolved_fixed_event_lifecycle(library: ContentLibrary) -> void:
	for layer_id in ["club", "casino"]:
		var label := "resolved fixed event manifest/%s" % layer_id
		var environment := _generated_environment(library, "small_underground_casino", layer_id)
		var object_id := "event:side_door"
		var event_id := "side_door"
		var original_manifest := _dict(environment.get("object_manifest", {}))
		var original_row := _active_manifest_row(original_manifest, object_id)
		var original_binding := _dict(_dict(_dict(environment.get("layout", {})).get("slot_bindings", {})).get(object_id, {}))
		_check(str(original_row.get("family", "")) == "fixed", label, "Punchline Side Door did not begin as fixed-family inventory")
		_check(str(original_binding.get("slot_family", "")) == "fixed", label, "Punchline Side Door did not begin with an authenticated fixed binding")

		var run_state := RunStateScript.new()
		run_state.current_environment = environment.duplicate(true)
		var original_revision := int(original_manifest.get("revision", 0))
		run_state.resolve_event(event_id)
		var resolved_environment: Dictionary = run_state.current_environment
		var resolved_manifest := _dict(resolved_environment.get("object_manifest", {}))
		var resolved_row := _active_manifest_row(resolved_manifest, object_id)
		var resolved_layout := _dict(resolved_environment.get("layout", {}))
		var resolved_binding := _dict(_dict(resolved_layout.get("slot_bindings", {})).get(object_id, {}))
		_check(str(resolved_row.get("family", "")) == "fixed", label, "resolving the Punchline Side Door removed its guaranteed fixed presence")
		_check(str(resolved_binding.get("slot_family", "")) == "fixed", label, "resolving the Punchline Side Door removed its authenticated fixed binding")
		_check(_dict(resolved_layout.get("object_rects", {})).has(object_id), label, "resolving the Punchline Side Door removed its fixed room geometry")
		_check(int(resolved_manifest.get("revision", 0)) > original_revision, label, "resolution did not advance the fixed fixture manifest revision")
		_check(str(resolved_manifest.get("source_digest", "")) != str(original_manifest.get("source_digest", "")), label, "resolution did not update fixed fixture source authority")
		_check(EnvironmentInstanceScript.object_manifest_errors(resolved_environment).is_empty(), label, "resolved fixed fixture produced an invalid manifest")

		var parsed_value: Variant = JSON.parse_string(JSON.stringify(resolved_environment))
		if typeof(parsed_value) != TYPE_DICTIONARY:
			_fail(label, "resolved fixed fixture did not survive JSON serialization")
			continue
		var restored := EnvironmentInstanceScript.from_dict(parsed_value as Dictionary).to_dict()
		_check(str(_active_manifest_row(_dict(restored.get("object_manifest", {})), object_id).get("family", "")) == "fixed", label, "JSON restore removed the resolved Side Door fixture")
		_check(str(_dict(_dict(_dict(restored.get("layout", {})).get("slot_bindings", {})).get(object_id, {})).get("slot_family", "")) == "fixed", label, "JSON restore removed the resolved Side Door fixed binding")


func _check_contextual_runtime_membership(library: ContentLibrary) -> void:
	# Crew presence is already-selected itinerary state. Prove the strict event
	# family has room for the actual worst cases rather than only a single marker.
	for fixture_value in [
		{"archetype_id": "small_underground_casino", "layer_id": "back_room", "counts": [2, 3, 4]},
		{"archetype_id": "back_alley", "layer_id": "", "counts": [4]},
	]:
		var fixture := _dict(fixture_value)
		for count_value in _array(fixture.get("counts", [])):
			var count := int(count_value)
			var run_state := RunStateScript.new()
			run_state.start_new("MANIFEST-CREW-%s-%s-%d" % [str(fixture.get("archetype_id", "")), str(fixture.get("layer_id", "")), count])
			var presence: Array = []
			for index in range(count):
				presence.append({
					"member_id": ["crew_rook", "crew_mags", "crew_bishop", "crew_switch"][index],
					"rank": "associate",
					"line": "Crew residency fixture %d" % index,
				})
			var environment := {
				"id": "runtime_crew_%s_%d" % [str(fixture.get("archetype_id", "")), count],
				"archetype_id": str(fixture.get("archetype_id", "")),
				"world_node_id": str(fixture.get("archetype_id", "")),
				"current_layer_id": str(fixture.get("layer_id", "")),
				"event_ids": [],
				"resolved_event_ids": [],
				"crew_presence": presence,
			}
			run_state.current_environment = environment
			var reconciled := run_state.reconcile_environment_object_membership(environment)
			var label := "%s%s crew capacity %d" % [str(fixture.get("archetype_id", "")), ":%s" % str(fixture.get("layer_id", "")) if not str(fixture.get("layer_id", "")).is_empty() else "", count]
			_check(bool(reconciled.get("ok", false)), label, "failed strict runtime membership: %s" % JSON.stringify(reconciled.get("errors", [])))
			var occupied: Dictionary = {}
			for index in range(count):
				var object_id := "crew_presence:%s" % str((presence[index] as Dictionary).get("member_id", ""))
				var binding := _assert_runtime_membership(environment, object_id, "event", true, label)
				var slot_id := str(binding.get("slot_id", ""))
				_check(not occupied.has(slot_id), label, "%s stacked into %s" % [object_id, slot_id])
				occupied[slot_id] = object_id

	# A parent venue owns one exit-family door back to its active sub-environment.
	var home_run := RunStateScript.new()
	home_run.start_new("MANIFEST-PARENT-HOME-EXIT")
	home_run.home_state = {
		"active": true,
		"lost": false,
		"home_archetype_id": "motel_room",
		"home_node_id": "motel_room_runtime_fixture",
		"parent_archetype_id": "motel",
		"display_name": "Motel Room",
	}
	home_run.current_environment = _generated_environment(library, "motel")
	var home_reconciled := home_run.reconcile_environment_object_membership(home_run.current_environment)
	_check(bool(home_reconciled.get("ok", false)), "parent-home exit", "failed membership reconciliation: %s" % JSON.stringify(home_reconciled.get("errors", [])))
	_assert_runtime_membership(home_run.current_environment, "travel:motel_room_runtime_fixture", "exit", true, "parent-home exit")
	var restored_home := RunStateScript.new()
	restored_home.from_dict(home_run.to_dict())
	_check(str(restored_home.home_state.get("parent_archetype_id", "")) == "motel", "parent-home exit", "save normalization dropped parent_archetype_id")


func _check_delivery_runtime_hosts(library: ContentLibrary) -> void:
	var hold_run := _delivery_fixture_run(library, "MANIFEST-DELIVERY-HOLD")
	var origin_id := hold_run.current_world_node_id()
	var hold_started := hold_run.delivery_begin_hold({
		"run_id": "manifest_hold",
		"targets": [{"node_id": origin_id}],
		"deadline_actions": 6,
		"hold_required_actions": 3,
		"hold_attention_limit": 100,
	})
	_check(bool(hold_started.get("ok", false)), "delivery hold host", "normal Punchline hold failed to reconcile: %s" % JSON.stringify(hold_started))
	if bool(hold_started.get("ok", false)):
		var interactions := _array(hold_run.delivery_physical_interactions())
		var host_id := "delivery:hold:%s" % origin_id
		_check(interactions.size() == 1, "delivery hold host", "three hold verbs created %d physical objects" % interactions.size())
		if interactions.size() == 1:
			var interaction := _dict(interactions[0])
			_check(str(interaction.get("object_id", "")) == host_id, "delivery hold host", "hold actions did not alias the stable sightline host")
			_check(_array(interaction.get("verbs", [])) == ["wait", "signal", "break_hold"], "delivery hold host", "stable sightline host lost its exact verbs")
		var hold_binding := _assert_runtime_membership(hold_run.current_environment, host_id, "scenario", true, "delivery hold host")
		var hold_row := _active_manifest_row(_dict(hold_run.current_environment.get("object_manifest", {})), host_id)
		_check(str(hold_binding.get("placement_class", "")) == "wall_mounted", "delivery hold host", "sightline host did not use wall capacity")
		_check(_array(_dict(hold_row.get("metadata", {})).get("verbs", [])) == ["wait", "signal", "break_hold"], "delivery hold host", "manifest host did not retain all hold verbs")
		_check(_array(hold_row.get("action_ids", [])) == ["delivery_physical_action"], "delivery hold host", "hold host did not own the single public action route")
		var controller_records := EnvironmentInteractionControllerScript.delivery_interactable_objects(DeliveryInteractionHost.new(hold_run))
		controller_records = EnvironmentInteractionControllerScript._join_object_manifest(controller_records, hold_run.current_environment, false)
		_check(controller_records.size() == 1 and str(_dict(controller_records[0]).get("object_id", "")) == host_id, "delivery hold host", "controller records were not bijective with the physical host")
		_check(_array(_dict(controller_records[0]).get("delivery_actions", [])).size() == 3, "delivery hold host", "controller host did not expose all three actions")
		var broken := hold_run.delivery_apply_physical_action("break_hold", "manifest:hold:break")
		_check(bool(broken.get("ok", false)) and not hold_run.delivery_has_active_run(), "delivery hold host", "breaking the hold did not close its lifecycle")
		_assert_runtime_membership(hold_run.current_environment, host_id, "scenario", false, "delivery hold host cleanup")

	var package_run := _delivery_fixture_run(library, "MANIFEST-DELIVERY-PACKAGE")
	var package_origin := package_run.current_world_node_id()
	var package_id := "delivery:package:%s" % package_origin
	var package_started := package_run.delivery_begin_package({
		"run_id": "manifest_package",
		"targets": [{"node_id": "bar"}],
		"deadline_actions": 10,
	})
	_check(bool(package_started.get("ok", false)), "delivery package host", "package route failed to start: %s" % JSON.stringify(package_started))
	if bool(package_started.get("ok", false)):
		_assert_runtime_membership(package_run.current_environment, package_id, "scenario", true, "delivery pickup host")
		_check(_array(_dict(_array(package_run.delivery_physical_interactions())[0]).get("verbs", [])) == ["pickup"], "delivery pickup host", "pickup did not own the package host")
		var picked_up := package_run.delivery_apply_physical_action("pickup", "manifest:package:pickup")
		_check(bool(picked_up.get("ok", false)), "delivery package host", "pickup action failed")
		_assert_runtime_membership(package_run.current_environment, package_id, "scenario", false, "delivery carried cleanup")
		var stashed := package_run.delivery_apply_physical_action("stash", "manifest:package:stash")
		_check(bool(stashed.get("ok", false)), "delivery package host", "stash action failed")
		_assert_runtime_membership(package_run.current_environment, package_id, "scenario", true, "delivery retrieve host")
		var stored_environment := _dict(WorldMapScript.node_metadata_by_id(package_run.world_map, package_origin).get("environment", {}))
		_assert_runtime_membership(stored_environment, package_id, "scenario", false, "delivery retrieve offscreen alias")
		var retrieved := package_run.delivery_apply_physical_action("retrieve", "manifest:package:retrieve")
		_check(bool(retrieved.get("ok", false)), "delivery package host", "retrieve action failed")
		_assert_runtime_membership(package_run.current_environment, package_id, "scenario", false, "delivery retrieve cleanup")
		stored_environment = _dict(WorldMapScript.node_metadata_by_id(package_run.world_map, package_origin).get("environment", {}))
		_assert_runtime_membership(stored_environment, package_id, "scenario", false, "delivery retrieve stored cleanup")

		# Install the sparse destination, cross the authoritative map edge, and
		# prove the direct contact has one scenario-owned physical identity. This
		# must survive save/load and disappear atomically after completion.
		# Revealed-but-unvisited world nodes intentionally do not retain a generated
		# environment snapshot. Install the destination package exactly as the real
		# travel pipeline does before advancing the authoritative map cursor.
		var bar_environment := _generated_environment(library, "bar")
		bar_environment["world_node_id"] = "bar"
		var installed := package_run.set_environment(bar_environment)
		_check(bool(installed.get("ok", false)), "delivery direct contact", "destination installation failed: %s" % JSON.stringify(installed))
		if bool(installed.get("ok", false)):
			package_run.world_map = WorldMapScript.enter_node(package_run.world_map, "bar", package_run.current_environment)
			var arrived := package_run.delivery_resolve_travel_arrival({"target_node_id": "bar"}, {})
			_check(bool(arrived.get("ok", false)) and bool(arrived.get("handoff_ready", false)), "delivery direct contact", "arrival did not publish a handoff: %s" % JSON.stringify(arrived))
			var handoff_id := "delivery:handoff:bar"
			var handoff_binding := _assert_runtime_membership(package_run.current_environment, handoff_id, "scenario", true, "delivery direct contact")
			var handoff_row := _active_manifest_row(_dict(package_run.current_environment.get("object_manifest", {})), handoff_id)
			_check(str(handoff_row.get("placement_class", "")) == "standing_person", "delivery direct contact", "handoff did not consume standing-person capacity")
			_check(_array(handoff_row.get("action_ids", [])) == ["delivery_handoff_direct"], "delivery direct contact", "handoff row lost its sole direct action")
			var contact_manifest_errors := EnvironmentInstanceScript.object_manifest_errors(package_run.current_environment)
			_check(contact_manifest_errors.is_empty(), "delivery direct contact", "contact manifest authority was invalid before controller join: %s" % JSON.stringify(contact_manifest_errors))
			var contact_layout_errors := EnvironmentInteractionControllerScript._manifest_layout_correlation_errors(
				_array(_dict(package_run.current_environment.get("object_manifest", {})).get("rows", [])),
				_dict(_dict(package_run.current_environment.get("layout", {})).get("slot_bindings", {}))
			)
			_check(contact_layout_errors.is_empty(), "delivery direct contact", "contact manifest/layout correlation was invalid before controller join: %s" % JSON.stringify(contact_layout_errors))
			var contact_records := EnvironmentInteractionControllerScript._join_object_manifest([], package_run.current_environment, true)
			_check(not _record_by_id(contact_records, handoff_id).is_empty(), "delivery direct contact", "manifest join did not synthesize the direct contact: %s" % JSON.stringify(contact_records))
			contact_records = EnvironmentInteractionControllerScript._attach_delivery_handoff_to_contact(DeliveryInteractionHost.new(package_run), contact_records)
			var direct_contact := _record_by_id(contact_records, handoff_id)
			_check(not direct_contact.is_empty() and bool(direct_contact.get("delivery_contact", false)), "delivery direct contact", "controller did not consume the manifest-owned contact")
			_check(
				str(direct_contact.get("slot_id", "")) == str(handoff_binding.get("slot_id", "")) and str(direct_contact.get("slot_family", "")) == "scenario",
				"delivery direct contact",
				"controller contact did not retain exact scenario authority: %s" % JSON.stringify({"contact": direct_contact, "binding": handoff_binding})
			)
			_check(_count_delivery_contacts(contact_records) == 1, "delivery direct contact", "controller produced duplicate delivery contacts")

			var restored_package := RunStateScript.new()
			restored_package.from_dict(package_run.to_dict())
			_assert_runtime_membership(restored_package.current_environment, handoff_id, "scenario", true, "delivery direct contact save-load")
			var completed := restored_package.delivery_complete_handoff("bar")
			_check(bool(completed.get("ok", false)), "delivery direct contact", "handoff completion failed after save/load: %s" % JSON.stringify(completed))
			_assert_runtime_membership(restored_package.current_environment, handoff_id, "scenario", false, "delivery direct contact cleanup")


func _check_numbers_runtime_hosts(library: ContentLibrary) -> void:
	var run_state := RunStateScript.new()
	run_state.start_new("MANIFEST-NUMBERS-RUNTIME")
	run_state.current_environment = _generated_environment(library, "bar")
	var bar_result := run_state.reconcile_environment_object_membership(run_state.current_environment)
	_check(bool(bar_result.get("ok", false)), "Numbers book host", "Bar membership failed: %s" % JSON.stringify(bar_result.get("errors", [])))
	_assert_runtime_membership(run_state.current_environment, "numbers:book", "fixed", true, "Numbers book host")

	var nonvenue := _generated_environment(library, "jazz_club")
	run_state.current_environment = nonvenue
	run_state.reconcile_environment_object_membership(nonvenue)
	_assert_runtime_membership(nonvenue, "numbers:book", "fixed", false, "Numbers non-venue")

	var punchline_back_room := _generated_environment(library, "small_underground_casino", "back_room")
	run_state.current_environment = punchline_back_room
	run_state.reconcile_environment_object_membership(punchline_back_room)
	_assert_runtime_membership(punchline_back_room, "numbers:book", "fixed", false, "Punchline back-room desk")

	var silas_environment := _generated_environment(library, "bar")
	run_state.current_environment = silas_environment
	run_state.town_state.living_world.action_index = 0
	run_state.town_state.living_world.itinerary_schedules["silas_snitch"] = [{"node_id": "bar", "start_action": 0, "end_action": 99}]
	var silas_result := run_state.reconcile_environment_object_membership(silas_environment)
	_check(bool(silas_result.get("ok", false)), "Numbers Silas host", "Silas presence failed: %s" % JSON.stringify(silas_result.get("errors", [])))
	var first_silas_row := _active_manifest_row(_dict(silas_environment.get("object_manifest", {})), "numbers:silas").duplicate(true)
	var first_silas_binding := _assert_runtime_membership(silas_environment, "numbers:silas", "event", true, "Numbers Silas host").duplicate(true)
	run_state.town_state.living_world.itinerary_schedules["silas_snitch"] = [{"node_id": "jazz_club", "start_action": 0, "end_action": 99}]
	run_state.reconcile_environment_object_membership(silas_environment)
	_assert_runtime_membership(silas_environment, "numbers:silas", "event", false, "Numbers Silas departure")
	run_state.town_state.living_world.itinerary_schedules["silas_snitch"] = [{"node_id": "bar", "start_action": 0, "end_action": 99}]
	run_state.reconcile_environment_object_membership(silas_environment)
	var rebuilt_silas_row := _active_manifest_row(_dict(silas_environment.get("object_manifest", {})), "numbers:silas")
	var rebuilt_silas_binding := _assert_runtime_membership(silas_environment, "numbers:silas", "event", true, "Numbers Silas return")
	_check(first_silas_row == rebuilt_silas_row, "Numbers Silas return", "deterministic rebuild changed the manifest row")
	_check(str(first_silas_binding.get("slot_id", "")) == str(rebuilt_silas_binding.get("slot_id", "")), "Numbers Silas return", "deterministic rebuild changed the event slot")


func _check_grand_living_runtime_hosts(library: ContentLibrary) -> void:
	var run_state := RunStateScript.new()
	run_state.start_new("MANIFEST-GRAND-LIVING")
	run_state.current_environment = _generated_environment(library, RunStateScript.GRAND_CASINO_ARCHETYPE_ID)
	run_state.rourke_current_room = RunStateScript.GRAND_CASINO_ARCHETYPE_ID
	run_state.rourke_current_spot = "main_pit"
	run_state.rourke_facing = "right"
	run_state.rourke_off_floor_actions = 0
	run_state.rival_cheaters = [{
		"id": "runtime_rival_fixture",
		"display_name": "Rival Counter",
		"room": RunStateScript.GRAND_CASINO_ARCHETYPE_ID,
		"spot": 1,
		"tell": "chip_riffle",
		"idle_phase": 0,
	}]
	var result := run_state.reconcile_environment_object_membership(run_state.current_environment)
	_check(bool(result.get("ok", false)), "Grand living-floor hosts", "membership failed: %s" % JSON.stringify(result.get("errors", [])))
	var rourke_binding := _assert_runtime_membership(run_state.current_environment, "grand_living:rourke", "event", true, "Grand living-floor hosts")
	var rival_binding := _assert_runtime_membership(run_state.current_environment, "grand_living:rival:runtime_rival_fixture", "event", true, "Grand living-floor hosts")
	_check(not str(rourke_binding.get("slot_id", "")).is_empty() and str(rourke_binding.get("slot_id", "")) != str(rival_binding.get("slot_id", "")), "Grand living-floor hosts", "Rourke and rival did not bind distinct event slots")


func _check_controller_fail_closed_membership() -> void:
	var physical_record := {
		"object_id": "event:unmanifested_fixture",
		"object_type": "event",
		"visual_type": "event",
		"visual_prop": "paper_note",
		"interactive": true,
		"focus_rect": Rect2(0.1, 0.1, 0.2, 0.2),
	}
	var missing_manifest := EnvironmentInteractionControllerScript._join_object_manifest([physical_record], {}, true)
	var missing_record := _record_by_id(missing_manifest, "event:unmanifested_fixture")
	_check(str(missing_record.get("presentation_mode", "")) == "overflow", "controller missing manifest", "unmanifested physical record remained in the room plane")
	_check(not missing_record.has("focus_rect") and not missing_record.has("slot_id"), "controller missing manifest", "unmanifested physical record retained fabricatable geometry")
	var rejected_binding := EnvironmentInteractionControllerScript._fail_closed_room_records([physical_record], "fixture rejection")
	var rejected_record := _record_by_id(rejected_binding, "event:unmanifested_fixture")
	_check(str(rejected_record.get("presentation_mode", "")) == "overflow" and not rejected_record.has("focus_rect"), "controller binding failure", "rejected physical record retained room geometry")
	_check(not EnvironmentInteractionControllerScript._object_manifest_join_errors({}).is_empty(), "controller authority preflight", "missing manifest/layout authority passed preflight")

	# Only stable fixed and exit identities promise an exact authored slot. Event
	# and scenario rows carry a deterministic preference but may consume another
	# compatible family-local slot when their preferred location is occupied.
	var preference_rows := [
		{"instance_object_id": "fixed:fixture", "presentation_object_id": "fixed:fixture", "family": "fixed", "placement_class": "standing_person", "exact_slot_id": "fixed.preferred", "active": true, "physical": true},
		{"instance_object_id": "event:fixture", "presentation_object_id": "event:fixture", "family": "event", "placement_class": "wall_mounted", "exact_slot_id": "event.preferred", "active": true, "physical": true},
		{"instance_object_id": "scenario:fixture", "presentation_object_id": "scenario:fixture", "family": "scenario", "placement_class": "floor_prop", "exact_slot_id": "scenario.preferred", "active": true, "physical": true},
		{"instance_object_id": "exit:fixture", "presentation_object_id": "exit:fixture", "family": "exit", "placement_class": "floor_prop", "exact_slot_id": "exit.preferred", "active": true, "physical": true},
	]
	var preference_bindings := {
		"fixed:fixture": {"slot_family": "fixed", "placement_class": "standing_person", "slot_id": "fixed.alternate", "presentation_mode": "room"},
		"event:fixture": {"slot_family": "event", "placement_class": "wall_mounted", "slot_id": "event.alternate", "presentation_mode": "room"},
		"scenario:fixture": {"slot_family": "scenario", "placement_class": "floor_prop", "slot_id": "scenario.alternate", "presentation_mode": "room"},
		"exit:fixture": {"slot_family": "exit", "placement_class": "floor_prop", "slot_id": "exit.alternate", "presentation_mode": "room"},
	}
	var preference_errors := EnvironmentInteractionControllerScript._manifest_layout_correlation_errors(preference_rows, preference_bindings)
	_check(preference_errors.size() == 2, "controller exact-slot policy", "expected fixed/exit rejection only, got %s" % JSON.stringify(preference_errors))
	var annotated_event := EnvironmentInteractionControllerScript._manifest_layout_annotated_record(
		{"object_id": "event:fixture", "placement_class": "wall_mounted", "manifest_exact_slot_id": "event.preferred"},
		preference_bindings,
		{"event:fixture": {"x": 0.1, "y": 0.2, "w": 0.2, "h": 0.2}},
		"event:fixture",
		"event:fixture",
		"event"
	)
	_check(str(annotated_event.get("slot_id", "")) == "event.alternate", "controller exact-slot policy", "event preference blocked an authenticated alternate slot")


func _delivery_fixture_run(library: ContentLibrary, seed_text: String) -> RunState:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	var environment := _generated_environment(library, "small_underground_casino", "club")
	environment["world_node_id"] = "small_underground_casino"
	var bar_environment := _generated_environment(library, "bar")
	bar_environment["world_node_id"] = "bar"
	run_state.set_world_map({
		"version": 3,
		"seed_text": seed_text,
		"start_node_id": "small_underground_casino",
		"current_node_id": "small_underground_casino",
		"nodes": [
			{"id": "small_underground_casino", "label": "The Punchline", "archetype_id": "small_underground_casino", "kind": "casino", "state": "visited", "seen": true, "environment": environment.duplicate(true)},
			{"id": "bar", "label": "Bar", "archetype_id": "bar", "kind": "bar", "state": "revealed", "seen": true, "environment": bar_environment},
		],
		"edges": [{"id": "punchline--bar", "a": "small_underground_casino", "b": "bar"}],
		"visited_path": ["small_underground_casino"],
	})
	run_state.current_environment = environment
	run_state.reconcile_environment_object_membership(run_state.current_environment)
	return run_state


func _generated_environment(library: ContentLibrary, archetype_id: String, layer_id: String = "") -> Dictionary:
	var archetype := library.environment_archetype(archetype_id)
	var rng := RngStreamScript.new()
	rng.configure(RngStreamScript.derive_seed(902_806, 902_806, "%s:%s:runtime" % [archetype_id, layer_id]))
	var instance = EnvironmentInstanceScript.from_archetype(archetype, 2, rng, library) \
			if layer_id.is_empty() else EnvironmentInstanceScript.from_archetype_layer(archetype, layer_id, 2, rng, library)
	return instance.to_dict()


func _assert_runtime_membership(environment: Dictionary, object_id: String, family: String, expected: bool, label: String) -> Dictionary:
	var manifest := _dict(environment.get("object_manifest", {}))
	var row := _active_manifest_row(manifest, object_id)
	var layout := _dict(environment.get("layout", {}))
	var bindings := _dict(layout.get("slot_bindings", {}))
	var rects := _dict(layout.get("object_rects", {}))
	var binding := _dict(bindings.get(object_id, {}))
	if expected:
		_check(not row.is_empty(), label, "%s has no active manifest row" % object_id)
		_check(str(row.get("family", "")) == family, label, "%s is not in the %s family" % [object_id, family])
		_check(not binding.is_empty(), label, "%s has no slot binding" % object_id)
		_check(str(binding.get("slot_family", "")) == family and str(binding.get("slot_id", "")).begins_with("%s." % family), label, "%s crossed slot families" % object_id)
		_check(rects.has(object_id), label, "%s has no room rectangle" % object_id)
		_check(not _array(layout.get("slot_overflow_ids", [])).has(object_id), label, "%s overflowed instead of using authored capacity" % object_id)
	else:
		_check(row.is_empty(), label, "%s retained an active manifest row" % object_id)
		_check(not bindings.has(object_id), label, "%s retained a slot binding" % object_id)
		_check(not rects.has(object_id), label, "%s retained room geometry" % object_id)
	return binding


func _active_manifest_row(manifest: Dictionary, object_id: String) -> Dictionary:
	for row_value in _array(manifest.get("rows", [])):
		var row := _dict(row_value)
		if bool(row.get("active", false)) and bool(row.get("physical", false)) \
				and str(row.get("presentation_object_id", row.get("object_id", ""))) == object_id:
			return row
	return {}


func _record_by_id(records: Array, object_id: String) -> Dictionary:
	for record_value in records:
		var record := _dict(record_value)
		if str(record.get("object_id", "")) == object_id:
			return record
	return {}


func _count_delivery_contacts(records: Array) -> int:
	var count := 0
	for record_value in records:
		if bool(_dict(record_value).get("delivery_contact", false)):
			count += 1
	return count


func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail(path, "does not exist")
		return {}
	var parsed_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed_value) != TYPE_DICTIONARY:
		_fail(path, "is not a JSON dictionary")
		return {}
	return parsed_value as Dictionary


func _check(condition: bool, label: String, message: String) -> void:
	if not condition:
		_fail(label, message)


func _fail(label: String, message: String) -> void:
	_failures.append("%s: %s" % [label, message])


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []
