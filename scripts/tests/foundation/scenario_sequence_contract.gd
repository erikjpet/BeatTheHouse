extends RefCounted

const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const SequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const SequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const HostTransactionScript := preload("res://scripts/core/scenario_host_transaction.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EnvironmentSemanticInventoryScript := preload("res://scripts/core/environment_semantic_inventory.gd")
const EnvironmentBaseSemanticRecordsScript := preload("res://scripts/core/environment_base_semantic_records.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RolloutManifestScript := preload("res://scripts/core/scenario_sequence_rollout_manifest.gd")
const EnvironmentInteractionViewModelScript := preload("res://scripts/ui/environment_interaction_view_model.gd")
const EnvironmentInteractionControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")


class LifecycleFixtureGame:
	extends GameModule

	func _init() -> void:
		definition = {"id": "lifecycle_fixture_game", "display_name": "Lifecycle Fixture", "family": "slot", "legal_actions": [], "cheat_actions": []}


class LifecycleRejectingGenerator:
	extends RunGenerator

	var reject_layer := false
	var reject_room := false
	var install_world_destination := false

	func _init(p_library: ContentLibrary) -> void:
		super(p_library)

	func _poison(run_state: RunState, marker: String) -> void:
		run_state.bankroll += 17
		run_state.current_environment["caller_poison"] = marker
		run_state.world_map["caller_poison"] = marker
		run_state.grand_casino_room_states["caller_poison"] = {"marker": marker}

	func enter_environment_layer(run_state: RunState, _target_layer_id: String, _advance_action: bool = true) -> Dictionary:
		if not reject_layer:
			return super.enter_environment_layer(run_state, _target_layer_id, _advance_action)
		_poison(run_state, "layer")
		return {"ok": false, "message": "Layer caller fixture rejected."}

	func enter_grand_casino_room_result(run_state: RunState, _target_archetype_id: String) -> Dictionary:
		if not reject_room:
			return super.enter_grand_casino_room_result(run_state, _target_archetype_id)
		_poison(run_state, "grand_room")
		return {"ok": false, "errors": ["Grand-room caller fixture rejected."]}

	func travel_environment_result(run_state: RunState, target_archetype_id: String, _target_prevalidated: bool = false) -> Dictionary:
		if not install_world_destination:
			return super.travel_environment_result(run_state, target_archetype_id, _target_prevalidated)
		run_state.current_environment = {"id": "%s_fixture" % target_archetype_id, "archetype_id": target_archetype_id, "world_node_id": target_archetype_id, "display_name": "Fixture Destination", "kind": "home", "event_ids": [], "game_ids": [], "item_offers": [], "service_ids": [], "lender_hooks": [], "next_archetypes": []}
		run_state.world_map["current_node_id"] = target_archetype_id
		return {"ok": true, "errors": [], "source_id": "bar_node", "target_id": target_archetype_id, "environment": run_state.current_environment.duplicate(true)}


class LifecycleDeliveryRejectRun:
	extends RunState

	func delivery_has_active_run() -> bool:
		return true

	func delivery_resolve_travel_arrival(_route: Dictionary = {}, _route_risk: Dictionary = {}) -> Dictionary:
		bankroll += 23
		current_environment["delivery_poison"] = true
		world_map["delivery_poison"] = true
		grand_casino_room_states["delivery_poison"] = {"active": true}
		return {"ok": false, "errors": ["Delivery caller fixture rejected."]}


class LifecycleCallerProbe:
	extends FoundationMain

	var message_log: Array = []
	var autosave_count := 0
	var presentation_count := 0
	var reject_install := false
	var meta_result: Dictionary = {}
	var forced_choice: Dictionary = {}
	var forced_travel_result: Dictionary = {"ok": false, "errors": ["Forced travel caller fixture rejected."]}
	var fixture_game := LifecycleFixtureGame.new()

	func _show_message(text: String) -> void:
		message_log.append(text)

	func _refresh() -> void:
		pass

	func _autosave_foundation_run(_status_text: String = "Autosaved.", _force: bool = false) -> bool:
		autosave_count += 1
		return true

	func _start_conclusion_animation(_result: Dictionary, _popup_rect: Rect2) -> void:
		presentation_count += 1

	func _show_item_found_popups(_result: Dictionary, _inventory_before: Dictionary) -> void:
		presentation_count += 1

	func _guard_player_input_route(_force_closing_allowed: bool = false, _coach_action_id: String = "ui:any", _notify_coach: bool = true) -> bool:
		return false

	func _install_lifecycle_environment(environment: Dictionary) -> Dictionary:
		if not reject_install:
			return super._install_lifecycle_environment(environment)
		run_state.bankroll += 31
		run_state.current_environment = {"id": "install_poison"}
		run_state.world_map["install_poison"] = true
		run_state.grand_casino_room_states["install_poison"] = {"active": true}
		run_state.home_state["install_poison"] = true
		return {"ok": false, "errors": ["Environment caller fixture rejected."]}

	func _meta_environment_result(_location_id: String) -> Dictionary:
		return meta_result.duplicate(true)

	func _meta_pawn_location_id() -> String:
		return "pawn"

	func _initialize_meta_collection() -> void:
		pass

	func _travel_choice_view_list() -> Array:
		return [forced_choice.duplicate(true)] if not forced_choice.is_empty() else []

	func _game_module_for_id(_game_id: String) -> GameModule:
		return fixture_game

	func _game_test_environment(_game_id: String, _game: GameModule) -> Dictionary:
		return {"id": "game_test_fixture", "archetype_id": "bar", "display_name": "Game Test Fixture", "game_ids": ["lifecycle_fixture_game"], "event_ids": [], "item_offers": [], "service_ids": [], "lender_hooks": [], "next_archetypes": []}


class LifecycleMetaEntryRejectProbe:
	extends LifecycleCallerProbe

	func _apply_meta_environment(_location_id: String) -> Dictionary:
		run_state.bankroll += 41
		run_state.current_environment = {"id": "meta_entry_poison"}
		run_state.home_state["meta_entry_poison"] = true
		current_screen = SCREEN_RESULT
		meta_session_active = true
		meta_session_location_id = "poison"
		_show_message("Meta entry caller fixture rejected.")
		return {"ok": false, "errors": ["Meta entry caller fixture rejected."]}


class LifecycleForcedTravelProbe:
	extends LifecycleCallerProbe

	func _travel_to(_target_id: String, _target_label: String, _choice_data: Dictionary = {}, _require_immediate_result: bool = false) -> Dictionary:
		run_state.bankroll += 37
		run_state.current_environment["forced_poison"] = true
		run_state.world_map["forced_poison"] = true
		run_state.grand_casino_room_states["forced_poison"] = {"active": true}
		current_screen = SCREEN_RESULT
		return forced_travel_result.duplicate(true)


static func check(library: ContentLibrary, failures: Array) -> void:
	_check_schema(failures)
	_check_catalog_rollout(library, failures)
	_check_registered_operations(failures)
	_check_interaction_identity(failures)
	_check_semantic_inventory(library, failures)
	_check_base_semantic_producer(library, failures)
	_check_lifecycle_finalization(library, failures)
	_check_lifecycle_caller_failure_contract(library, failures)
	_check_negative_fixtures(failures)
	_check_lifecycle_commands(failures)
	_check_handler_reducer_contracts(failures)
	_check_serialized_fact_ingress(failures)
	_check_atomic_runtime_failures(failures)
	_check_sequence_persistence_seam(failures)
	_check_receipt_reconstruction(failures)
	_check_depth_remediation_contracts(failures)
	_check_authoritative_receipt_capacity(failures)
	_check_host_transaction_seam(failures)


static func _check_lifecycle_caller_failure_contract(library: ContentLibrary, failures: Array) -> void:
	var layer_probe := _lifecycle_probe(library, _lifecycle_run(false))
	var layer_generator := LifecycleRejectingGenerator.new(library)
	layer_generator.reject_layer = true
	layer_probe.generator = layer_generator
	var layer_rng := RngStream.new()
	layer_rng.configure(91201)
	var layered_environment := EnvironmentInstanceScript.from_archetype(library.environment_archetype("small_underground_casino"), 1, layer_rng, library).to_dict()
	layer_probe.run_state.current_environment = layered_environment
	var layer_before := _caller_probe_state(layer_probe)
	var layer_result := layer_probe.resolve_event_choice("side_door", "punchline_password")
	if bool(layer_result.get("ok", true)) or _caller_probe_state(layer_probe) != layer_before or layer_probe.autosave_count != 0 or layer_probe.presentation_count != 0 or layer_probe.message_log.is_empty() or str(layer_probe.message_log.back()) != "Layer caller fixture rejected.":
		failures.append("Public event-layer caller did not reject and restore the resolved event byte-identically before presentation/autosave.")
	layer_probe.free()

	var delivery_probe := _lifecycle_probe(library, _lifecycle_run(true))
	var delivery_generator := LifecycleRejectingGenerator.new(library)
	delivery_generator.install_world_destination = true
	delivery_probe.generator = delivery_generator
	delivery_probe.last_game_result = {"sentinel": "game_result"}
	delivery_probe.last_item_result = {"sentinel": "item_result"}
	delivery_probe.last_hook_result = {"sentinel": "hook_result"}
	delivery_probe.selected_travel_target_id = "motel"
	delivery_probe.selected_travel_label = "Motel"
	var delivery_before := _caller_probe_state(delivery_probe)
	var delivery_result := delivery_probe._travel_to("motel", "Motel", {
		"id": "motel", "label": "Motel", "enabled": true, "distance": "near", "travel_minutes": 6,
		"route": {"id": "bar_node_to_motel", "from": "bar_node", "to": "motel", "distance": "near", "cost": 0, "suspicion_delta": 0},
	}, true)
	if bool(delivery_result.get("ok", true)) or _caller_probe_state(delivery_probe) != delivery_before or delivery_probe.autosave_count != 0 or delivery_probe.current_screen != FoundationMain.SCREEN_ENVIRONMENT or delivery_probe.message_log.is_empty() or str(delivery_probe.message_log.back()) != "Delivery caller fixture rejected.":
		failures.append("Public delivery-arrival travel caller did not restore a valid source/destination transaction or suppressed downstream success UI.")
	delivery_probe.free()

	var showdown_run := _showdown_caller_run(library)
	if showdown_run == null:
		failures.append("Forced-casino caller fixture could not reach the production pre-duel event boundary.")
	else:
		var showdown_probe := _lifecycle_probe(library, showdown_run)
		var showdown_generator := LifecycleRejectingGenerator.new(library)
		showdown_generator.reject_room = true
		showdown_probe.generator = showdown_generator
		var showdown_before := _caller_probe_state(showdown_probe)
		var showdown_result := showdown_probe.resolve_event_choice(RunStateScript.GRAND_CASINO_SHOWDOWN_EVENT_ID, "hold_steady")
		if bool(showdown_result.get("ok", true)) or _caller_probe_state(showdown_probe) != showdown_before or showdown_probe.autosave_count != 0 or showdown_probe.presentation_count != 0 or showdown_probe.message_log.is_empty() or str(showdown_probe.message_log.back()) != "Grand-room caller fixture rejected.":
			failures.append("Forced casino event caller presented/autosaved or retained the resolved event after back-room rejection.")
		showdown_probe.free()

	var apply_probe := _lifecycle_probe(library, _lifecycle_run(false))
	apply_probe.reject_install = true
	apply_probe.meta_result = {
		"environment": {"id": "meta_home_fixture", "archetype_id": "apartment", "display_name": "Meta Home"},
		"home_state": {"status": "tenant", "place": "fixture_home"},
	}
	var apply_before := _caller_probe_state(apply_probe)
	var apply_result := apply_probe._apply_meta_environment("home")
	if bool(apply_result.get("ok", true)) or _caller_probe_state(apply_probe) != apply_before or apply_probe.message_log.is_empty() or str(apply_probe.message_log.back()) != "Environment caller fixture rejected.":
		failures.append("Meta environment apply helper did not return failure, restore home/run authority, and retain its error UI.")
	apply_probe.free()

	var meta_entry_probe := LifecycleMetaEntryRejectProbe.new()
	meta_entry_probe.library = library
	meta_entry_probe.run_state = _lifecycle_run(false)
	meta_entry_probe.current_screen = FoundationMain.SCREEN_ENVIRONMENT
	var meta_entry_before := _caller_probe_state(meta_entry_probe)
	var meta_entry_result := meta_entry_probe._enter_meta_location("home")
	if bool(meta_entry_result.get("ok", true)) or _caller_probe_state(meta_entry_probe) != meta_entry_before or meta_entry_probe.message_log.is_empty() or str(meta_entry_probe.message_log.back()) != "Meta entry caller fixture rejected.":
		failures.append("Meta entry caller did not restore its prior session/run/home/screen after apply rejection.")
	meta_entry_probe.free()

	var direct_probe := _lifecycle_probe(library, _lifecycle_run(false))
	direct_probe.show_game_library_launcher = true
	direct_probe.reject_install = true
	var direct_before := _caller_probe_state(direct_probe)
	var direct_result := direct_probe.start_game_test_session("lifecycle_fixture_game")
	var direct_errors := _array(direct_result.get("errors", []))
	if bool(direct_result.get("ok", true)) or _caller_probe_state(direct_probe) != direct_before or direct_probe.autosave_count != 0 or direct_errors.is_empty() or str(direct_errors[0]) != "Environment caller fixture rejected.":
		failures.append("Direct game-test entry did not return/restore its enclosing run and screen after room rejection.")
	direct_probe.free()

	var forced_probe := LifecycleForcedTravelProbe.new()
	forced_probe.library = library
	forced_probe.run_state = _lifecycle_run(false)
	forced_probe.generator = LifecycleRejectingGenerator.new(library)
	forced_probe.current_screen = FoundationMain.SCREEN_ENVIRONMENT
	forced_probe.selected_action_category = FoundationMain.ACTION_CATEGORY_TRAVEL
	forced_probe.run_state.narrative_flags["health_inspector_closing_actions"] = 1
	forced_probe.forced_choice = {"id": "motel", "label": "Motel", "enabled": true}
	var forced_before := _caller_probe_state(forced_probe)
	var forced_result := forced_probe._apply_forced_environment_travel("health_inspector")
	if bool(forced_result.get("ok", true)) or bool(forced_result.get("applied", true)) or _caller_probe_state(forced_probe) != forced_before or forced_probe.message_log.is_empty() or forced_probe.autosave_count != 0 or str(forced_probe.message_log.back()) != "Forced travel caller fixture rejected.":
		failures.append("Health-inspector forced travel did not restore closing/forced flags and enclosing state or propagate its explicit failure.")
	forced_probe.free()


static func _lifecycle_probe(library: ContentLibrary, run_state: RunState) -> LifecycleCallerProbe:
	var probe := LifecycleCallerProbe.new()
	probe.library = library
	probe.run_state = run_state
	probe.generator = LifecycleRejectingGenerator.new(library)
	probe.current_screen = FoundationMain.SCREEN_ENVIRONMENT
	probe.selected_action_category = FoundationMain.ACTION_CATEGORY_TRAVEL
	return probe


static func _lifecycle_run(delivery_reject: bool) -> RunState:
	var run_state: RunState = LifecycleDeliveryRejectRun.new() if delivery_reject else RunStateScript.new()
	run_state.start_new("LIFECYCLE-PUBLIC-CALLER")
	run_state.current_environment = {
		"id": "bar_caller_fixture", "archetype_id": "bar", "world_node_id": "bar_node", "display_name": "Caller Bar", "kind": "bar",
		"game_ids": [], "event_ids": [], "item_offers": [], "service_ids": [], "lender_hooks": [], "next_archetypes": ["motel"],
	}
	run_state.world_map = {
		"version": 3, "seed_text": "LIFECYCLE-PUBLIC-CALLER", "start_node_id": "bar_node", "current_node_id": "bar_node",
		"nodes": [
			{"id": "bar_node", "archetype_id": "bar", "kind": "bar", "tier": 1, "state": "revealed", "seen": true, "environment": run_state.current_environment.duplicate(true)},
			{"id": "motel", "archetype_id": "motel", "kind": "home", "tier": 1, "state": "revealed", "seen": true, "environment": {}},
		],
		"edges": [{"a": "bar_node", "b": "motel"}], "visited_path": ["bar_node"],
	}
	run_state.grand_casino_room_states = {"sentinel": {"id": "caller_room_sentinel", "archetype_id": "grand_casino"}}
	run_state.home_state = {"status": "tenant", "place": "caller_home"}
	return run_state


static func _caller_probe_state(probe: FoundationMain) -> String:
	var run_state: RunState = probe.run_state
	var lifecycle_snapshot := probe._foundation_lifecycle_snapshot()
	var enclosing_fields: Dictionary = {}
	for field_name_value in _dict(lifecycle_snapshot.get("fields", {})).keys():
		var field_name := str(field_name_value)
		var value: Variant = _dict(lifecycle_snapshot.get("fields", {})).get(field_name)
		enclosing_fields[field_name] = (value as Object).get_instance_id() if value is Object else value
	return JSON.stringify({
		"run_ref": run_state.get_instance_id() if run_state != null else 0,
		"run": run_state.to_dict() if run_state != null else {},
		"environment": run_state.current_environment if run_state != null else {},
		"world_map": run_state.world_map if run_state != null else {},
		"room_states": run_state.grand_casino_room_states if run_state != null else {},
		"home_state": run_state.home_state if run_state != null else {},
		"enclosing_fields": enclosing_fields,
		"visibility": lifecycle_snapshot.get("visibility", {}),
	})


static func _showdown_caller_run(library: ContentLibrary) -> RunState:
	var rng := RngStream.new()
	rng.configure(91202)
	var environment := EnvironmentInstanceScript.from_archetype(library.environment_archetype(RunStateScript.GRAND_CASINO_ARCHETYPE_ID), 1, rng, library).to_dict()
	if environment.is_empty():
		return null
	var event_ids := _array(environment.get("event_ids", []))
	if not event_ids.has(RunStateScript.GRAND_CASINO_SHOWDOWN_EVENT_ID):
		event_ids.append(RunStateScript.GRAND_CASINO_SHOWDOWN_EVENT_ID)
	environment["event_ids"] = event_ids
	var run_state := RunStateScript.new()
	run_state.start_new("LIFECYCLE-FORCED-CASINO")
	run_state.current_environment = environment
	run_state.narrative_flags["the_house_calls_pending"] = true
	var module := EventModule.new()
	module.setup(library.event(RunStateScript.GRAND_CASINO_SHOWDOWN_EVENT_ID), library)
	for choice_id in ["enter_back_room", "keep_everything", "face_rourke", "hold_steady", "hold_steady"]:
		var result := module.resolve(run_state, run_state.current_environment, choice_id)
		if not bool(result.get("ok", false)):
			return null
	if str(run_state.narrative_flags.get("grand_casino_showdown_step", "")) != RunStateScript.GRAND_CASINO_SHOWDOWN_STEP_INTERROGATION or int(run_state.narrative_flags.get("grand_casino_showdown_interrogation_beat", -1)) != 2:
		return null
	return run_state


static func _check_semantic_inventory(library: ContentLibrary, failures: Array) -> void:
	if not OperationRegistryScript.validate_owned_identity("game::game:slot:2").is_empty() or OperationRegistryScript.parse_owned_identity("game::game:slot:2").get("stable_object_id", "") != "game:slot:2":
		failures.append("Owned-identity parser did not preserve an arbitrary canonical colon component count.")
	for hostile_identity in ["game::game:slot::evil", "game::game::slot", "Game::game:slot", "game::game::slot", "game::game::", "game::game/slot"]:
		if OperationRegistryScript.validate_owned_identity(hostile_identity).is_empty(): failures.append("Owned-identity parser accepted hostile identity %s." % hostile_identity)
	var bar_catalog := EnvironmentSemanticInventoryScript.for_archetype(library.environment_archetype("bar"), library)
	var bar_guaranteed := EnvironmentSemanticInventoryScript.guaranteed_collections(bar_catalog)
	var bar_possible := _dict(bar_catalog.get("possible", {}))
	if not _array(bar_guaranteed.get("games", [])).has("game::pull_tabs") or _array(bar_guaranteed.get("games", [])).has("game::slot") or not _array(bar_possible.get("games", [])).has("game::slot"):
		failures.append("Archetype catalog did not distinguish guaranteed pull-tabs from an optional bar game.")
	for collection_pair_value in [[bar_guaranteed, "game::game:pull_tabs"], [bar_possible, "game::game:slot"]]:
		var collection_pair := collection_pair_value as Array
		var collections := _dict(collection_pair[0])
		var identity := str(collection_pair[1])
		if not _array(collections.get("interactions", [])).has(identity) or not _array(collections.get("scene_objects", [])).has(identity):
			failures.append("Archetype game census did not mirror rendered interaction/scene collections for %s." % identity)
	var census_archetype := {"id": "census", "kind": "shop", "object_fixtures": ["shopkeeper:merchant"], "layout": {"object_rects": {"shopkeeper:merchant": {"x": 0.1, "y": 0.1, "w": 0.1, "h": 0.1}}}, "service_pool": ["house_drink"], "game_pool": ["slot"], "required_game_ids": ["slot"], "game_count": 1, "item_pool": ["marked_cards"], "item_count": 0, "travel_hooks": ["bar"], "layer_transitions": [{"target_layer_id": "cage"}], "local_narrative_flags": {"casino_room_targets": ["grand_casino_cage"]}}
	var census := EnvironmentSemanticInventoryScript.for_archetype(census_archetype, library)
	var census_guaranteed := EnvironmentSemanticInventoryScript.guaranteed_collections(census)
	var census_possible := EnvironmentSemanticInventoryScript.possible_collections(census)
	for rendered_identity in ["base::shopkeeper:merchant", "service::service:house_drink", "game::game:slot", "base::travel:leave", "base::environment_layer:cage", "base::travel:grand_casino_cage"]:
		if not _array(census_guaranteed.get("scene_objects", [])).has(rendered_identity) or not _array(census_guaranteed.get("interactions", [])).has(rendered_identity):
			failures.append("Static guaranteed census lost exact rendered scene/interaction parity for %s." % rendered_identity)
	if not _array(census_possible.get("scene_objects", [])).has("base::item:marked_cards") or not _array(census_possible.get("interactions", [])).has("base::item:marked_cards"):
		failures.append("Static possible catalog omitted item-offer scene/interaction identities.")
	var census_diagnostics := EnvironmentSemanticInventoryScript.diagnose_declared_targets(census, {"interactions": ["base::item:marked_cards", "base::service:house_drink", "base::ghost"], "scene_objects": ["service::house_drink"]})
	for diagnostic_text in ["possible-only", "belongs to collection", "wrong owner", "unknown"]:
		if not _contains_text(census_diagnostics, diagnostic_text): failures.append("Static target catalog omitted %s diagnostics." % diagnostic_text)
	var public_catalog := library.scenario_target_catalog(_finalization_definition())
	if public_catalog.is_empty() or not public_catalog.has("guaranteed") or not public_catalog.has("possible") or not public_catalog.has("records") or not public_catalog.has("provenance") or not public_catalog.has("errors") or _dict(public_catalog.get("inventory", {})).is_empty():
		failures.append("Public scenario target catalog did not expose full guaranteed/possible/record/provenance/error proof.")
	var wrong_layer_definition := _finalization_definition()
	wrong_layer_definition["layer_id"] = "ghost_layer"
	if not _contains_text(_array(library.scenario_target_catalog(wrong_layer_definition).get("errors", [])), "layer"):
		failures.append("Public scenario target catalog did not diagnose an authored layer mismatch.")
	var exact_environment := {"id": "grand_casino_001", "world_node_id": "node_1", "archetype_id": "grand_casino", "game_ids": ["slot"], "event_ids": ["late_shift_discount"], "item_offers": [{"id": "marked_cards"}], "service_ids": ["house_drink"], "lender_hooks": ["street_lender"], "next_archetypes": ["bar"], "travel_hooks": ["bar"], "current_layer_id": "main", "layer_ids": ["main", "cage"], "layer_transitions": [{"target_layer_id": "cage"}], "local_narrative_flags": {"casino_room_targets": ["grand_casino_cage"]}, "layout": {"object_rects": {"game:slot": {"x": 0.1, "y": 0.1, "w": 0.12, "h": 0.18}, "game:slot:2": {"x": 0.1, "y": 0.1, "w": 0.12, "h": 0.18}}}}
	var exact_stamped := EnvironmentBaseSemanticRecordsScript.stamp_interactable_records([
		_presentation_record("game:slot", "game", "slot", Rect2(0.1, 0.1, 0.12, 0.18)),
		_presentation_record("game:slot:2", "game", "slot", Rect2(0.1, 0.1, 0.12, 0.18)),
	], exact_environment, library)
	var exact_records := _array(exact_stamped.get("records", []))
	var exact := EnvironmentSemanticInventoryScript.for_instance(exact_environment, library, exact_records)
	var exact_collections := EnvironmentSemanticInventoryScript.exact_collections(exact)
	if not bool(exact_stamped.get("ok", false)) or not EnvironmentSemanticInventoryScript.validate(exact).is_empty() or not _array(exact_collections.get("scene_objects", [])).has("game::game:slot:2") or not _array(exact_collections.get("interactions", [])).has("game::game:slot:2") or not _array(exact_collections.get("routes", [])).has("base::layer:cage") or not _array(exact_collections.get("routes", [])).has("base::room:grand_casino_cage"):
		failures.append("Exact instance inventory lost generated fixtures/interactions/layer or room routes.")
	var tampered := exact.duplicate(true)
	tampered["environment_id"] = "forged"
	if EnvironmentSemanticInventoryScript.validate(tampered).is_empty() or not EnvironmentSemanticInventoryScript.exact_collections(tampered).is_empty(): failures.append("Tampered semantic inventory digest was accepted.")
	var duplicate_exact := EnvironmentSemanticInventoryScript.for_instance(exact_environment, library, [exact_records[0], exact_records[0]])
	var duplicate_exact_errors := _array(duplicate_exact.get("errors", []))
	if duplicate_exact_errors != ["base interaction inventory contains duplicate/colliding identity or presentation id game:slot."]:
		failures.append("Duplicate exact base interaction identity did not retain its exact structured collision diagnostic: %s" % JSON.stringify(duplicate_exact_errors))
	var ghost := _fixture_definition()
	ghost["sequence"]["declared_targets"]["scene_objects"] = ["base::ghost"]
	ghost["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(ghost)
	if not _contains_text(SequenceSchemaScript.validate_definition(ghost, OperationRegistryScript, _fixture_target_inventory(ghost)), "not present"):
		failures.append("A declared ghost target passed independent catalog validation.")
	var tombstone_state := {"declared_targets": {"scene_objects": ["base::door"]}, "target_inventory": {"scene_objects": ["base::door"]}}
	var remove := {"family": "scene_ops", "op": "remove", "receipt_id": "remove_door", "owner_namespace": "base", "stable_object_id": "door"}
	var removed := OperationRegistryScript.apply_operations(tombstone_state, "scene_ops", [remove], "fixture:node:phase:remove")
	var removed_state := _dict(removed.get("state", {}))
	if not bool(removed.get("ok", false)) or not _dict(_dict(removed_state.get("tombstones", {})).get("scene_objects", {})).has("base::door"):
		failures.append("Removing an exact immutable target did not create a tombstone.")
	var restored := OperationRegistryScript.apply_operations(removed_state, "scene_ops", [remove], "fixture:node:cleanup:restore", true)
	if not bool(restored.get("ok", false)) or _dict(_dict(_dict(restored.get("state", {})).get("tombstones", {})).get("scene_objects", {})).has("base::door"):
		failures.append("Cleanup did not clear a base tombstone and reveal immutable inventory.")
	var forged_create := _operation_fixture("scene_ops", "spawn", 777)
	forged_create["owner_namespace"] = "game"
	if bool(OperationRegistryScript.apply_operations(tombstone_state, "scene_ops", [forged_create], "fixture:node:phase:forged").get("ok", true)):
		failures.append("Scenario content forged a producer-owned create identity.")


static func _check_base_semantic_producer(library: ContentLibrary, failures: Array) -> void:
	var environment := {"game_ids": ["slot"], "event_ids": [], "service_ids": [], "lender_hooks": [], "item_offers": [], "travel_hooks": ["bar"], "next_archetypes": [], "layout": {"object_rects": {"game:slot": {"x": 0.1, "y": 0.1, "w": 0.12, "h": 0.18}}}}
	var record := _presentation_record("game:slot", "game", "slot", Rect2(0.1, 0.1, 0.12, 0.18))
	var repeated_record := _presentation_record("game:slot", "game", "slot", Rect2(0.1, 0.1, 0.12, 0.18))
	if record.has("coordinate_space") or record.has("pixel_hit_bounds"):
		failures.append("No-sequence ViewModel record gained v2-only geometry metadata.")
	if JSON.stringify(record) != JSON.stringify(repeated_record):
		failures.append("No-sequence ViewModel record was not byte-stable across identical inputs.")
	var legacy_record_before := JSON.stringify(record)
	var stamped := EnvironmentBaseSemanticRecordsScript.stamp_interactable_records([record], environment, library)
	if JSON.stringify(record) != legacy_record_before:
		failures.append("V2 semantic stamping mutated the legacy ViewModel record in place.")
	var produced := EnvironmentBaseSemanticRecordsScript.from_interactable_records(_array(stamped.get("records", [])))
	var interactions := _array(produced.get("interactions", []))
	if not bool(stamped.get("ok", false)) or not bool(produced.get("ok", false)) or interactions.size() != 1:
		failures.append("Exact UI base semantic producer failed its valid game fixture: %s" % JSON.stringify(_array(produced.get("errors", []))))
	else:
		var interaction := _dict(interactions[0])
		if str(interaction.get("owner_namespace", "")) != "game" or str(interaction.get("stable_object_id", "")) != "game:slot" or str(interaction.get("source_field", "")) != "game_ids" or str(interaction.get("source_record_id", "")) != "slot":
			failures.append("UI base semantic producer did not preserve exact identity/origin provenance.")
		if not _array(produced.get("actors", [])).is_empty(): failures.append("UI base semantic producer synthesized an actor without an explicit semantic actor source.")
	var transient := record.duplicate(true)
	transient["hovered"] = true
	transient["focused"] = true
	transient["enabled"] = false
	transient["disabled_reason"] = "Temporarily unavailable."
	var transient_stamped := EnvironmentBaseSemanticRecordsScript.stamp_interactable_records([transient], environment, library)
	var transient_produced := EnvironmentBaseSemanticRecordsScript.from_interactable_records(_array(transient_stamped.get("records", [])))
	if str(produced.get("digest", "")) != str(transient_produced.get("digest", "")):
		failures.append("Base semantic identity digest changed under transient UI state.")
	var decorative := record.duplicate(true)
	decorative["object_id"] = "crew_presence:ambient"
	decorative["interactive"] = false
	var with_decorative := EnvironmentBaseSemanticRecordsScript.stamp_interactable_records([record, decorative], environment, library)
	var decorative_produced := EnvironmentBaseSemanticRecordsScript.from_interactable_records(_array(with_decorative.get("records", [])))
	if _array(decorative_produced.get("interactions", [])).size() != 1: failures.append("Decorative UI record entered the semantic interaction inventory.")
	var disabled := record.duplicate(true)
	disabled["enabled"] = false
	disabled["disabled_reason"] = "Closed."
	disabled["available_actions"] = []
	var disabled_stamped := EnvironmentBaseSemanticRecordsScript.stamp_interactable_records([disabled], environment, library)
	if not bool(EnvironmentBaseSemanticRecordsScript.from_interactable_records(_array(disabled_stamped.get("records", []))).get("ok", false)):
		failures.append("Disabled base interaction with no available action was rejected.")
	for bad_bounds in [{}, {"x": 0.1, "y": 0.1, "w": 0.0, "h": 0.18}, {"x": 0.1, "y": 0.1, "w": 0.04, "h": 0.18}]:
		var bad_record := record.duplicate(true)
		bad_record["focus_rect"] = bad_bounds
		var bad_stamp := EnvironmentBaseSemanticRecordsScript.stamp_interactable_records([bad_record], environment, library)
		if bool(EnvironmentBaseSemanticRecordsScript.from_interactable_records(_array(bad_stamp.get("records", []))).get("ok", true)):
			failures.append("Base semantic producer authorized missing/zero/undersized bounds.")
	var spoof := record.duplicate(true)
	spoof["owner_namespace"] = "base"
	if bool(EnvironmentBaseSemanticRecordsScript.stamp_interactable_records([spoof], environment, library).get("ok", true)):
		failures.append("Base semantic producer accepted owner provenance spoofing.")
	var unknown := record.duplicate(true)
	unknown["source_id"] = "ghost_game"
	unknown["object_id"] = "game:ghost_game"
	if bool(EnvironmentBaseSemanticRecordsScript.stamp_interactable_records([unknown], environment, library).get("ok", true)):
		failures.append("Base semantic producer accepted an unknown/unselected game reference.")
	var unknown_domain := record.duplicate(true)
	unknown_domain["object_id"] = "mystery:ghost"
	unknown_domain["object_type"] = "mystery"
	unknown_domain["source_id"] = "ghost"
	if bool(EnvironmentBaseSemanticRecordsScript.stamp_interactable_records([unknown_domain], environment, library).get("ok", true)):
		failures.append("Base semantic producer accepted an unknown presentation domain through a fallback owner.")
	var duplicate := _array(stamped.get("records", []))
	duplicate.append_array(_array(stamped.get("records", [])))
	if bool(EnvironmentBaseSemanticRecordsScript.from_interactable_records(duplicate).get("ok", true)):
		failures.append("Base semantic producer accepted duplicate presentation/semantic identities.")
	var filtered_inventory := EnvironmentSemanticInventoryScript.for_instance(environment, library, [])
	if not _array(EnvironmentSemanticInventoryScript.exact_collections(filtered_inventory).get("interactions", [])).is_empty():
		failures.append("Exact instance inventory synthesized an interaction absent from the final UI-filtered record set.")
	var caller_actor_inventory := EnvironmentSemanticInventoryScript.for_instance(environment, library, [], [{"owner_namespace": "base", "stable_object_id": "actor:forged", "source_record_id": "forged"}])
	var caller_actor_errors := EnvironmentSemanticInventoryScript.validate(caller_actor_inventory)
	if not _contains_text(caller_actor_errors, "not closed and producer-stamped") or not _array(EnvironmentSemanticInventoryScript.exact_collections(caller_actor_inventory).get("actors", [])).is_empty():
		failures.append("Exact instance inventory did not reject a caller-supplied actor outside the closed producer-stamped contract.")


static func _check_lifecycle_finalization(library: ContentLibrary, failures: Array) -> void:
	var definition := _finalization_definition()
	var run_state := RunStateScript.new()
	run_state.current_environment = {
		"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node", "environment_visit_id": "visit_1",
		"scenario_sequence_definition": definition,
		"game_ids": ["slot"], "event_ids": ["late_shift_discount"], "service_ids": ["house_drink"], "lender_hooks": [], "item_offers": [],
		"travel_hooks": ["bar"], "next_archetypes": [],
		"semantic_anchors": {
			"bar_floor_100": {"position": [90, 120]},
			"bar_actor": {"position": [180, 120]},
		},
		"layout": {"object_rects": {"game:slot": {"x": 0.1, "y": 0.1, "w": 0.12, "h": 0.18}}},
	}
	var before_ingress := JSON.stringify(run_state.current_environment)
	var premature_command := run_state.scenario_sequence_command("prepare", "premature:command", {}, "scenario", "command_console")
	var premature_fact := run_state.scenario_enqueue_fact("world_boundary", "scenario", {"amount": 1, "action_index": 0}, "premature:fact")
	var premature_flush := run_state.scenario_flush_facts(0)
	if bool(premature_command.get("ok", true)) or bool(premature_fact.get("ok", true)) or bool(premature_flush.get("ok", true)) or JSON.stringify(run_state.current_environment) != before_ingress:
		failures.append("Sequence command/fact/flush ingress mutated or opened before semantic finalization.")
	run_state.scenario_prepare_semantic_finalization()
	var presentation := _presentation_record("game:slot", "game", "slot", Rect2(0.1, 0.1, 0.12, 0.18))
	var finalized := run_state.scenario_finalize_base_semantics([presentation], library)
	var first_receipts := _array(_dict(run_state.current_environment.get("scenario_sequence_state", {})).get("visit_receipts", [])).size()
	var replayed := run_state.scenario_finalize_base_semantics([presentation], library)
	var replay_receipts := _array(_dict(run_state.current_environment.get("scenario_sequence_state", {})).get("visit_receipts", [])).size()
	if not bool(finalized.get("ok", false)) or bool(finalized.get("replayed", true)) or not bool(replayed.get("replayed", false)) or first_receipts != 1 or replay_receipts != 1 or not bool(run_state.current_environment.get("scenario_semantic_ready", false)):
		failures.append("Semantic finalization was not atomic/idempotent with exactly-once reentry: %s" % JSON.stringify(finalized))
	var disabled_presentation := presentation.duplicate(true)
	disabled_presentation["enabled"] = false
	disabled_presentation["disabled_reason"] = "Temporarily closed."
	disabled_presentation["available_actions"] = []
	var refreshed := run_state.scenario_finalize_base_semantics([disabled_presentation], library)
	var refreshed_semantic: Dictionary = _dict(_dict(run_state.current_environment.get("scenario_sequence_projection", {})).get("semantic_state", {}))
	var refreshed_slot: Dictionary = _dict(_dict(refreshed_semantic.get("interactions", {})).get("game::game:slot", {}))
	if not bool(refreshed.get("ok", false)) or not bool(refreshed.get("replayed", false)) or bool(_dict(refreshed_slot).get("enabled", true)) or _array(_dict(run_state.current_environment.get("scenario_sequence_state", {})).get("visit_receipts", [])).size() != replay_receipts:
		failures.append("Same-digest semantic refresh did not atomically replace transient action availability without replaying reentry.")
	var valid_authority_environment := run_state.current_environment.duplicate(true)
	var stale_authority_records := _array(run_state.current_environment.get("scenario_base_interactions", []))
	if stale_authority_records.is_empty():
		failures.append("Declared base interaction was not retained for live action-authority validation.")
	else:
		var stale_record := _dict(stale_authority_records[0])
		stale_record["enabled"] = true
		stale_record["available_actions"] = [{"id": "prepare", "handler": "set_local", "inputs": {"key": "side", "value": "left"}}]
		stale_authority_records[0] = stale_record
		run_state.current_environment["scenario_base_interactions"] = stale_authority_records
		var state_before_stale_action := SequenceRuntimeScript.content_fingerprint(run_state.current_environment.get("scenario_sequence_state", {}))
		var stale_action_result := run_state.scenario_sequence_command("prepare", "stale:action:authority", {}, "scenario", "command_console")
		if bool(stale_action_result.get("ok", true)) or SequenceRuntimeScript.content_fingerprint(run_state.current_environment.get("scenario_sequence_state", {})) != state_before_stale_action:
			failures.append("Post-seal action handler/input mutation bypassed ephemeral action authority.")
		run_state.current_environment = valid_authority_environment.duplicate(true)
		var forged_environment := valid_authority_environment.duplicate(true)
		var forged_records := _array(forged_environment.get("scenario_base_interactions", []))
		var forged_record := _dict(forged_records[0])
		forged_record["enabled"] = true
		forged_record["available_actions"] = [{"id": "prepare", "handler": "set_local", "inputs": {"key": "side", "value": "left"}}]
		forged_records[0] = forged_record
		forged_environment["scenario_base_interactions"] = forged_records
		forged_environment["scenario_semantic_action_digest"] = SequenceRuntimeScript.base_interaction_action_authority_digest(forged_records)
		var forged_state := _dict(forged_environment.get("scenario_sequence_state", {}))
		var forged_command := SequenceRuntimeScript.command("prepare", str(forged_state.get("node_id", "")), str(forged_state.get("phase_id", "")), "forged:base:handler", {}, "game", "game:slot")
		var forged_result := ScenarioEngineScript.sequence_command(forged_environment, definition, forged_command, {"available_funds": 10})
		if bool(forged_result.get("ok", true)) or _array(_dict(forged_environment.get("scenario_sequence_state", {})).get("command_receipts", [])).has("forged:base:handler"):
			failures.append("A base-only action invoked a sequence handler without an authenticated authored overlay receipt.")
		var valid_overlay_environment := valid_authority_environment.duplicate(true)
		var valid_overlay_state := _dict(valid_overlay_environment.get("scenario_sequence_state", {}))
		var valid_overlay_command := _runtime_command(valid_overlay_state, definition, "prepare", str(valid_overlay_state.get("node_id", "")), str(valid_overlay_state.get("phase_id", "")), "valid:overlay:handler", {}, "scenario", "command_console")
		if not bool(ScenarioEngineScript.sequence_command(valid_overlay_environment, definition, valid_overlay_command, {"available_funds": 10}).get("ok", false)):
			failures.append("Authenticated authored interaction operation no longer authorized its exact handler action.")
	var cost_run := RunStateScript.new()
	cost_run.current_environment = valid_authority_environment.duplicate(true)
	cost_run.bankroll = 10
	var cost_state := _dict(cost_run.current_environment.get("scenario_sequence_state", {}))
	var cost_descriptor := SequenceRuntimeScript._command_descriptor(cost_state, definition, "scenario", "command_console", "prepare")
	var accepted_cost := cost_run.scenario_sequence_command(
		"prepare", "run_state:cost:once", {}, "scenario", "command_console",
		str(cost_descriptor.get("action_origin_owner_namespace", "")),
		str(cost_descriptor.get("action_origin_stable_object_id", "")),
		str(cost_descriptor.get("action_origin_receipt_key", "")),
		str(cost_descriptor.get("action_origin_boundary_id", "")),
		str(cost_descriptor.get("action_origin_fingerprint", ""))
	)
	var bankroll_after_accept := cost_run.bankroll
	var replayed_cost := cost_run.scenario_sequence_command(
		"prepare", "run_state:cost:once", {}, "scenario", "command_console",
		str(cost_descriptor.get("action_origin_owner_namespace", "")),
		str(cost_descriptor.get("action_origin_stable_object_id", "")),
		str(cost_descriptor.get("action_origin_receipt_key", "")),
		str(cost_descriptor.get("action_origin_boundary_id", "")),
		str(cost_descriptor.get("action_origin_fingerprint", ""))
	)
	var rejected_cost := cost_run.scenario_sequence_command(
		"prepare", "run_state:cost:once", {"forged": true}, "scenario", "command_console",
		str(cost_descriptor.get("action_origin_owner_namespace", "")),
		str(cost_descriptor.get("action_origin_stable_object_id", "")),
		str(cost_descriptor.get("action_origin_receipt_key", "")),
		str(cost_descriptor.get("action_origin_boundary_id", "")),
		str(cost_descriptor.get("action_origin_fingerprint", ""))
	)
	if not bool(accepted_cost.get("ok", false)) or bankroll_after_accept != 8 or not bool(replayed_cost.get("ok", false)) or not bool(replayed_cost.get("replayed", false)) or bool(rejected_cost.get("ok", true)) or cost_run.bankroll != bankroll_after_accept or accepted_cost.has("cost_applied"):
		failures.append("RunState command cost was not charged exactly once on the first accepted receipt while replay/rejection remained free.")
	var downstream_definition := definition.duplicate(true)
	downstream_definition["sequence"]["phase_graph"]["phases"][0]["branches"] = [{"id": "blocked_prepare", "condition": {"type": "command", "command_id": "prepare"}, "next_phase": "aftermath"}]
	downstream_definition["sequence"]["phase_graph"]["phases"][1]["entry_conditions"] = [{"type": "local_min", "key": "pressure", "value": 5}]
	downstream_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(downstream_definition)
	var downstream_run := RunStateScript.new()
	downstream_run.current_environment = valid_authority_environment.duplicate(true)
	downstream_run.current_environment["scenario_sequence_definition"] = downstream_definition
	downstream_run.bankroll = 10
	var downstream_state := _dict(downstream_run.current_environment.get("scenario_sequence_state", {}))
	var downstream_descriptor := SequenceRuntimeScript._command_descriptor(downstream_state, downstream_definition, "scenario", "command_console", "prepare")
	var downstream_failure := downstream_run.scenario_sequence_command(
		"prepare", "run_state:cost:downstream_failure", {}, "scenario", "command_console",
		str(downstream_descriptor.get("action_origin_owner_namespace", "")),
		str(downstream_descriptor.get("action_origin_stable_object_id", "")),
		str(downstream_descriptor.get("action_origin_receipt_key", "")),
		str(downstream_descriptor.get("action_origin_boundary_id", "")),
		str(downstream_descriptor.get("action_origin_fingerprint", ""))
	)
	if bool(downstream_failure.get("ok", true)) or downstream_run.bankroll != 10:
		failures.append("A command rejected by a downstream phase boundary still charged its authored action cost.")
	var refresh_failure_run := RunStateScript.new()
	refresh_failure_run.current_environment = valid_authority_environment.duplicate(true)
	var refresh_journal_before := SequenceRuntimeScript.content_fingerprint(refresh_failure_run.current_environment.get("scenario_sequence_state", {}))
	var failed_refresh := refresh_failure_run.scenario_finalize_base_semantics([presentation, presentation], library)
	if bool(failed_refresh.get("ok", true)) or refresh_failure_run.current_environment.has("scenario_semantic_ready") or SequenceRuntimeScript.content_fingerprint(refresh_failure_run.current_environment.get("scenario_sequence_state", {})) != refresh_journal_before:
		failures.append("Failed live semantic refresh did not invalidate readiness while preserving the durable journal byte-for-byte.")
	var invalidation_run := RunStateScript.new()
	invalidation_run.current_environment = run_state.current_environment.duplicate(true)
	var durable_before_invalidation := SequenceRuntimeScript.content_fingerprint(invalidation_run.current_environment.get("scenario_sequence_state", {}))
	var invalidation_result := invalidation_run._invalidate_scenario_semantic_proof("fixture source changed")
	var invalidated_state := _dict(invalidation_run.current_environment.get("scenario_sequence_state", {}))
	if bool(invalidation_result.get("ok", true)) or SequenceRuntimeScript.content_fingerprint(invalidated_state) != durable_before_invalidation or str(invalidated_state.get("status", "")) == SequenceRuntimeScript.STATUS_CLEANED or invalidation_run.current_environment.has("scenario_semantic_ready") or not _dict(invalidation_run.current_environment.get("scenario_sequence_projection", {})).is_empty():
		failures.append("Semantic proof invalidation forged an unjournaled cleaned state or mutated the durable causal journal.")
	var night_definition := definition.duplicate(true)
	night_definition["sequence"]["expiry"] = {"boundary": "night_end", "after": 3, "policy": "resume"}
	night_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(night_definition)
	var night_run := RunStateScript.new()
	night_run.current_environment = run_state.current_environment.duplicate(true)
	for ephemeral_key in ["scenario_sequence_state", "scenario_sequence_projection", "scenario_semantic_ready", "scenario_semantic_inventory", "scenario_semantic_inventory_version", "scenario_semantic_digest", "scenario_semantic_action_digest", "scenario_base_interactions", "scenario_base_actors", "scenario_base_producer_context"]: night_run.current_environment.erase(ephemeral_key)
	night_run.current_environment["scenario_sequence_definition"] = night_definition
	night_run.current_environment["scenario_sequence_pending_visit_id"] = "visit_night"
	var night_finalized := night_run.scenario_finalize_base_semantics([presentation], library)
	night_run.game_clock_minutes = 1439
	var first_midnight := night_run.advance_game_clock_minutes(1)
	var first_expiry_progress := int(_dict(night_run.current_environment.get("scenario_sequence_state", {})).get("expiry_progress", -1))
	var before_no_midnight := SequenceRuntimeScript.content_fingerprint(_dict(night_run.current_environment.get("scenario_sequence_state", {})).get("expiry_boundary_records", []))
	var no_midnight := night_run.advance_game_clock_minutes(1439)
	var after_no_midnight := SequenceRuntimeScript.content_fingerprint(_dict(night_run.current_environment.get("scenario_sequence_state", {})).get("expiry_boundary_records", []))
	var multi_midnight := night_run.advance_game_clock_minutes(1441)
	var night_state := _dict(night_run.current_environment.get("scenario_sequence_state", {}))
	if not bool(night_finalized.get("ok", false)) or not bool(first_midnight.get("ok", false)) or first_expiry_progress != 1 or not bool(no_midnight.get("ok", false)) or before_no_midnight != after_no_midnight or not bool(multi_midnight.get("ok", false)) or int(night_state.get("expiry_progress", -1)) != 3 or not bool(night_state.get("expired", false)):
		failures.append("Game clock did not apply exact one/multi-midnight sequence expiry boundaries without false in-day progress.")
	var failing_clock := RunStateScript.new()
	failing_clock.current_environment = run_state.current_environment.duplicate(true)
	var failing_clock_definition := definition.duplicate(true)
	failing_clock_definition["sequence"]["expiry"] = {"boundary": "night_end", "after": 1, "policy": "cleanup"}
	failing_clock_definition["sequence"]["cleanup"] = {"operations": []}
	failing_clock_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(failing_clock_definition)
	failing_clock.current_environment["scenario_sequence_definition"] = failing_clock_definition
	failing_clock.game_clock_minutes = 1439
	var failing_clock_run_before := JSON.stringify(failing_clock.to_dict())
	var failing_clock_environment_before := JSON.stringify(failing_clock.current_environment)
	var failed_clock := failing_clock.advance_game_clock_minutes(1)
	if bool(failed_clock.get("ok", true)) or failing_clock.game_clock_minutes != 1439 or JSON.stringify(failing_clock.to_dict()) != failing_clock_run_before or JSON.stringify(failing_clock.current_environment) != failing_clock_environment_before:
		failures.append("Failed night-end cleanup did not restore the authoritative run and live environment byte-for-byte.")
	var failing_travel := RunStateScript.new()
	failing_travel.current_environment = run_state.current_environment.duplicate(true)
	var failing_travel_definition := failing_clock_definition.duplicate(true)
	failing_travel_definition["sequence"]["expiry"]["boundary"] = "leave"
	failing_travel_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(failing_travel_definition)
	failing_travel.current_environment["scenario_sequence_definition"] = failing_travel_definition
	var travel_state_before := SequenceRuntimeScript.content_fingerprint(failing_travel.current_environment)
	var travel_preflight := failing_travel.scenario_preflight_environment_change()
	var failed_install := failing_travel.set_environment({"id": "blocked_destination", "archetype_id": "motel", "world_node_id": "motel"})
	if bool(travel_preflight.get("ok", true)) or bool(failed_install.get("ok", true)) or SequenceRuntimeScript.content_fingerprint(failing_travel.current_environment) != travel_state_before:
		failures.append("Failed departure cleanup was not observable and atomic before environment replacement.")
	var capacity_definition := definition.duplicate(true)
	capacity_definition["sequence"]["expiry"] = {"boundary": "leave", "after": 2, "policy": "resume"}
	capacity_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(capacity_definition)
	var capacity_run := RunStateScript.new()
	capacity_run.current_environment = valid_authority_environment.duplicate(true)
	capacity_run.current_environment["scenario_sequence_definition"] = capacity_definition
	capacity_run.world_map = {
		"version": 3, "seed_text": "LIFECYCLE-CAPACITY", "start_node_id": "bar_node", "current_node_id": "bar_node", "revision": 0,
		"nodes": [
			{"id": "bar_node", "archetype_id": "bar", "kind": "bar", "tier": 1, "state": "revealed", "seen": true, "environment": {}},
			{"id": "motel", "archetype_id": "motel", "kind": "home", "tier": 1, "state": "revealed", "seen": true, "environment": {}},
		],
		"edges": [{"a": "bar_node", "b": "motel"}], "visited_path": ["bar_node"], "runtime_ephemeral": {"nonce": 17},
	}
	capacity_run.grand_casino_room_states = {"sentinel": {"id": "sentinel", "archetype_id": "bar", "scenario_sequence_projection": {"ephemeral": "preserve"}}}
	var capacity_state := _dict(capacity_run.current_environment.get("scenario_sequence_state", {}))
	while SequenceRuntimeScript._next_cause_ordinal(capacity_state) < SequenceRuntimeScript.MAX_RECEIPTS - 1:
		var capacity_visit := SequenceRuntimeScript.record_visit(capacity_state, capacity_definition, "departure_capacity_%d" % SequenceRuntimeScript._next_cause_ordinal(capacity_state))
		if not bool(capacity_visit.get("ok", false)):
			failures.append("Production departure capacity fixture could not reach MAX_RECEIPTS - 1.")
			break
		capacity_state = _dict(capacity_visit.get("state", {}))
	capacity_run.current_environment["scenario_sequence_state"] = capacity_state
	var layered_capacity_environment: Dictionary = {}
	var layered_proof_run := RunStateScript.new()
	layered_proof_run.current_environment = valid_authority_environment.duplicate(true)
	for ephemeral_key in ["scenario_sequence_state", "scenario_sequence_projection", "scenario_semantic_ready", "scenario_semantic_inventory", "scenario_semantic_inventory_version", "scenario_semantic_digest", "scenario_semantic_action_digest", "scenario_base_interactions", "scenario_base_actors", "scenario_base_producer_context"]:
		layered_proof_run.current_environment.erase(ephemeral_key)
	layered_proof_run.current_environment["scenario_sequence_definition"] = capacity_definition
	layered_proof_run.current_environment["scenario_sequence_pending_visit_id"] = "capacity_layer_visit"
	layered_proof_run.current_environment["environment_layer_schema_version"] = 1
	layered_proof_run.current_environment["current_layer_id"] = "main"
	layered_proof_run.current_environment["default_layer_id"] = "main"
	layered_proof_run.current_environment["layer_ids"] = ["main", "back_room"]
	layered_proof_run.current_environment["layer_transitions"] = [{"target_layer_id": "back_room"}]
	layered_proof_run.current_environment["layer_states"] = {"back_room": {"id": "bar_back_room", "archetype_id": "bar", "world_node_id": "bar_node"}}
	var layered_finalized := layered_proof_run.scenario_finalize_base_semantics([presentation], library)
	if not bool(layered_finalized.get("ok", false)):
		failures.append("Production layer-entry capacity fixture could not seal its real layered source.")
	else:
		layered_capacity_environment = layered_proof_run.current_environment.duplicate(true)
		layered_capacity_environment["scenario_sequence_state"] = capacity_state.duplicate(true)
	for production_path_value in ["legacy_next_environment", "world_travel_result", "grand_room_result", "layer_entry"]:
		var production_path := str(production_path_value)
		var path_run := RunStateScript.new()
		path_run.from_dict(capacity_run.to_dict())
		path_run.current_environment = capacity_run.current_environment.duplicate(true)
		path_run.world_map = capacity_run.world_map.duplicate(true)
		path_run.grand_casino_room_states = capacity_run.grand_casino_room_states.duplicate(true)
		if production_path == "legacy_next_environment":
			path_run.world_map = {}
		elif production_path == "grand_room_result":
			path_run.current_environment["id"] = "grand_casino_capacity"
			path_run.current_environment["archetype_id"] = RunStateScript.GRAND_CASINO_ARCHETYPE_ID
			path_run.current_environment["world_node_id"] = "grand_casino"
		elif production_path == "layer_entry" and not layered_capacity_environment.is_empty():
			path_run.current_environment = layered_capacity_environment.duplicate(true)
		var path_run_before := JSON.stringify(path_run.to_dict())
		var path_environment_before := JSON.stringify(path_run.current_environment)
		var path_world_map_before := JSON.stringify(path_run.world_map)
		var path_room_states_before := JSON.stringify(path_run.grand_casino_room_states)
		var path_reported_failure := true
		var path_generator := RunGeneratorScript.new(library)
		match production_path:
			"legacy_next_environment":
				path_generator.next_environment(path_run, "motel", true)
			"world_travel_result":
				path_reported_failure = not bool(path_generator.travel_environment_result(path_run, "motel", true).get("ok", true))
			"grand_room_result":
				path_reported_failure = not bool(path_generator.enter_grand_casino_room_result(path_run, RunStateScript.GRAND_CASINO_CAGE_ARCHETYPE_ID).get("ok", true))
			"layer_entry":
				path_reported_failure = not bool(path_generator.enter_environment_layer(path_run, "back_room", false).get("ok", true))
		if not path_reported_failure or JSON.stringify(path_run.to_dict()) != path_run_before or JSON.stringify(path_run.current_environment) != path_environment_before or JSON.stringify(path_run.world_map) != path_world_map_before or JSON.stringify(path_run.grand_casino_room_states) != path_room_states_before:
			failures.append("%s did not reserve combined departure-plus-expiry capacity and reject byte-identically." % production_path)
	var final_visit := SequenceRuntimeScript.record_visit(capacity_state, capacity_definition, "departure_capacity_final")
	if not bool(final_visit.get("ok", false)):
		failures.append("Production world-boundary capacity fixture could not fill its final causal receipt.")
	else:
		capacity_run.current_environment["scenario_sequence_state"] = _dict(final_visit.get("state", {}))
		var boundary_run_before := JSON.stringify(capacity_run.to_dict())
		var boundary_environment_before := JSON.stringify(capacity_run.current_environment)
		var boundary_world_map_before := JSON.stringify(capacity_run.world_map)
		var boundary_room_states_before := JSON.stringify(capacity_run.grand_casino_room_states)
		var failed_world_boundary := capacity_run.advance_environment_turns(1)
		if bool(failed_world_boundary.get("ok", true)) or JSON.stringify(capacity_run.to_dict()) != boundary_run_before or JSON.stringify(capacity_run.current_environment) != boundary_environment_before or JSON.stringify(capacity_run.world_map) != boundary_world_map_before or JSON.stringify(capacity_run.grand_casino_room_states) != boundary_room_states_before:
			failures.append("Rejected production world-boundary enqueue/flush did not restore the run and live environment byte-for-byte.")
	var future_saved_environment := RunStateScript._environment_for_persistent_storage(valid_authority_environment)
	future_saved_environment["scenario_sequence_state"] = {"schema_version": SequenceRuntimeScript.STATE_SCHEMA_VERSION + 1, "scenario_id": str(definition.get("id", ""))}
	var future_normalized := RunStateScript._normalize_environment(future_saved_environment)
	var blocked_restore := RunStateScript.new()
	blocked_restore.current_environment = future_normalized.duplicate(true)
	var blocked_finalize := blocked_restore.scenario_finalize_base_semantics([presentation], library)
	var instance_restore := EnvironmentInstanceScript.from_dict(future_saved_environment).to_dict()
	var overbound_saved_environment := future_saved_environment.duplicate(true)
	overbound_saved_environment["scenario_sequence_state"] = {"schema_version": SequenceRuntimeScript.STATE_SCHEMA_VERSION, "scenario_id": str(definition.get("id", "")), "hostile": "x".repeat(OperationRegistryScript.MAX_VARIANT_TEXT + 1)}
	var overbound_normalized := RunStateScript._normalize_environment(overbound_saved_environment)
	if str(future_normalized.get("scenario_sequence_migration_error", "")).is_empty() or future_normalized.has("scenario_sequence_state") or bool(blocked_finalize.get("ok", true)) or blocked_restore.current_environment.has("scenario_semantic_ready") or blocked_restore.current_environment.has("scenario_sequence_state") or str(instance_restore.get("scenario_sequence_migration_error", "")).is_empty() or instance_restore.has("scenario_sequence_state") or str(overbound_normalized.get("scenario_sequence_migration_error", "")).is_empty() or overbound_normalized.has("scenario_sequence_state"):
		failures.append("Malformed, unsupported, or overbound persisted sequence state restarted instead of requiring explicit migration.")
	var overlimit_saved_environment := RunStateScript._environment_for_persistent_storage(valid_authority_environment)
	var overlimit_saved_state := _dict(overlimit_saved_environment.get("scenario_sequence_state", {}))
	overlimit_saved_state["fact_receipt_records"] = []
	for hostile_index in range(SequenceRuntimeScript.MAX_RECEIPTS + 1):
		overlimit_saved_state["fact_receipt_records"].append({"hostile": hostile_index})
	overlimit_saved_environment["scenario_sequence_state"] = overlimit_saved_state
	var overlimit_run_normalized := RunStateScript._normalize_environment(overlimit_saved_environment)
	var overlimit_instance_normalized := EnvironmentInstanceScript.from_dict(overlimit_saved_environment).to_dict()
	if overlimit_run_normalized.has("scenario_sequence_state") or str(overlimit_run_normalized.get("scenario_sequence_migration_error", "")).is_empty() or overlimit_instance_normalized.has("scenario_sequence_state") or str(overlimit_instance_normalized.get("scenario_sequence_migration_error", "")).is_empty():
		failures.append("A persisted 257-entry receipt journal survived RunState or EnvironmentInstance load normalization.")
	var overlimit_layer_environment := valid_authority_environment.duplicate(true)
	overlimit_layer_environment.erase("scenario_sequence_state")
	overlimit_layer_environment["environment_layer_schema_version"] = 1
	overlimit_layer_environment["current_layer_id"] = "main"
	overlimit_layer_environment["default_layer_id"] = "main"
	overlimit_layer_environment["layer_ids"] = ["main", "back_room"]
	overlimit_layer_environment["layer_states"] = {"back_room": {"id": "overlimit_layer", "scenario_sequence_state": overlimit_saved_state.duplicate(true)}}
	var normalized_overlimit_layers := RunStateScript._normalize_environment(overlimit_layer_environment)
	var normalized_overlimit_layer_body := _dict(_dict(normalized_overlimit_layers.get("layer_states", {})).get("back_room", {}))
	if normalized_overlimit_layer_body.has("scenario_sequence_state") or str(normalized_overlimit_layer_body.get("scenario_sequence_migration_error", "")).is_empty():
		failures.append("A nested layer retained a persisted 257-entry receipt journal instead of requiring migration.")
	var valid_proof_version := int(run_state.current_environment.get("scenario_semantic_inventory_version", 0))
	var valid_proof_digest := str(run_state.current_environment.get("scenario_semantic_digest", ""))
	var proof_type_cases := [
		{"label": "string version", "set": {"scenario_semantic_inventory_version": "1"}},
		{"label": "float version", "set": {"scenario_semantic_inventory_version": 1.0}},
		{"label": "missing version", "erase": ["scenario_semantic_inventory_version"]},
		{"label": "missing digest", "erase": ["scenario_semantic_digest"]},
		{"label": "mismatched version", "set": {"scenario_semantic_inventory_version": valid_proof_version + 1}},
		{"label": "mismatched digest", "set": {"scenario_semantic_digest": "0".repeat(64)}},
	]
	for proof_case_index in range(proof_type_cases.size()):
		var proof_case := _dict(proof_type_cases[proof_case_index])
		var engine_environment := run_state.current_environment.duplicate(true)
		for proof_key_value in _array(proof_case.get("erase", [])):
			engine_environment.erase(str(proof_key_value))
		for proof_key_value in _dict(proof_case.get("set", {})).keys():
			engine_environment[proof_key_value] = _dict(proof_case.get("set", {})).get(proof_key_value)
		var engine_before_state := _dict(engine_environment.get("scenario_sequence_state", {}))
		var engine_command := _runtime_command(
			engine_before_state,
			definition,
			"prepare",
			str(engine_environment.get("world_node_id", "")),
			str(engine_before_state.get("phase_id", "")),
			"proof_type:engine:%d" % proof_case_index,
			{},
			"scenario",
			"command_console"
		)
		var engine_result := ScenarioEngineScript.sequence_command(engine_environment, definition, engine_command, {"available_funds": 10})
		var engine_after_state := _dict(engine_environment.get("scenario_sequence_state", {}))
		if bool(engine_result.get("ok", true)) or str(engine_after_state.get("status", "")) != SequenceRuntimeScript.STATUS_CLEANED or str(engine_after_state.get("phase_id", "")) != str(engine_before_state.get("phase_id", "")) or int(engine_after_state.get("phase_action_counter", -1)) != int(engine_before_state.get("phase_action_counter", -1)) or SequenceRuntimeScript.content_fingerprint(engine_after_state.get("command_receipts", [])) != SequenceRuntimeScript.content_fingerprint(engine_before_state.get("command_receipts", [])):
			failures.append("Direct Engine ingress did not fail closed for a %s semantic proof reference." % str(proof_case.get("label", "invalid")))
		var run_state_hostile := RunStateScript.new()
		run_state_hostile.current_environment = engine_environment.duplicate(true)
		# RunState must reject before Engine is entered, so give it the original
		# active state rather than the Engine call's intentionally cleaned copy.
		run_state_hostile.current_environment["scenario_sequence_state"] = engine_before_state.duplicate(true)
		var run_state_before := JSON.stringify(run_state_hostile.current_environment)
		var run_state_result := run_state_hostile.scenario_sequence_command("prepare", "proof_type:run_state:%d" % proof_case_index, {}, "scenario", "command_console")
		if bool(run_state_result.get("ok", true)) or JSON.stringify(run_state_hostile.current_environment) != run_state_before:
			failures.append("RunState ingress mutated or authorized a %s semantic proof reference." % str(proof_case.get("label", "invalid")))
	var pristine_recipient := run_state.current_environment.duplicate(true)
	var pristine_host := ScenarioEngineScript.sequence_host_semantics(pristine_recipient)
	var pristine_old := SequenceRuntimeScript.initial_state(definition, "bar", "pristine:node:migration", pristine_host)
	var pristine_old_operation_receipts := _array(_dict(pristine_old.get("semantic_state", {})).get("operation_receipts", [])).duplicate()
	pristine_recipient["scenario_sequence_state"] = pristine_old
	var pristine_rebound := ScenarioEngineScript.ensure_sequence_state(pristine_recipient, definition)
	var pristine_new_operation_receipts := _array(_dict(pristine_rebound.get("semantic_state", {})).get("operation_receipts", []))
	if pristine_old.is_empty() or pristine_old_operation_receipts.is_empty() or str(pristine_rebound.get("node_id", "")) != "bar_node" or str(pristine_rebound.get("status", "")) != SequenceRuntimeScript.STATUS_ACTIVE or pristine_new_operation_receipts.is_empty() or SequenceRuntimeScript.content_fingerprint(pristine_new_operation_receipts) == SequenceRuntimeScript.content_fingerprint(pristine_old_operation_receipts):
		failures.append("Pristine archetype-bound initial state did not reinitialize exact node-bound operation/transition receipts.")
	var expiry_transplant_definition := definition.duplicate(true)
	expiry_transplant_definition["sequence"]["expiry"] = {"boundary": "night_end", "after": 2, "policy": "resume"}
	expiry_transplant_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(expiry_transplant_definition)
	var expiry_host := ScenarioEngineScript.sequence_host_semantics(run_state.current_environment)
	var expiry_seed := SequenceRuntimeScript.initial_state(expiry_transplant_definition, "bar", "expiry_only_transplant", expiry_host)
	var expiry_progressed := SequenceRuntimeScript.apply_expiry_boundary(expiry_seed, expiry_transplant_definition, "night_end")
	var expiry_state := _dict(expiry_progressed.get("state", {}))
	var expiry_recipient := run_state.current_environment.duplicate(true)
	expiry_recipient["scenario_sequence_state"] = expiry_state.duplicate(true)
	var expiry_is_only_progress := bool(expiry_progressed.get("ok", false)) \
		and str(expiry_state.get("status", "")) == SequenceRuntimeScript.STATUS_ACTIVE \
		and not bool(expiry_state.get("expired", true)) \
		and int(expiry_state.get("expiry_progress", 0)) == 1 \
		and _array(expiry_state.get("expiry_boundary_records", [])).size() == 1 \
		and _array(expiry_state.get("command_receipt_records", [])).is_empty() \
		and _array(expiry_state.get("fact_receipt_records", [])).is_empty() \
		and _array(expiry_state.get("visit_receipt_records", [])).is_empty() \
		and _array(expiry_state.get("cleanup_receipt_records", [])).is_empty()
	var expiry_can_rebind := ScenarioEngineScript._sequence_state_can_bind_initial_node(expiry_state, expiry_recipient) if expiry_is_only_progress else true
	var expiry_command := _runtime_command(expiry_state, expiry_transplant_definition, "prepare", str(expiry_recipient.get("world_node_id", "")), str(expiry_state.get("phase_id", "")), "expiry_only:transplant", {}, "scenario", "command_console")
	var expiry_ingress := ScenarioEngineScript.sequence_command(expiry_recipient, expiry_transplant_definition, expiry_command, {"available_funds": 10})
	var expiry_rejected_state := _dict(expiry_recipient.get("scenario_sequence_state", {}))
	if not expiry_is_only_progress or expiry_can_rebind or bool(expiry_ingress.get("ok", true)) or str(expiry_rejected_state.get("status", "")) != SequenceRuntimeScript.STATUS_CLEANED or str(expiry_rejected_state.get("node_id", "")) != "bar" or SequenceRuntimeScript.content_fingerprint(expiry_rejected_state.get("expiry_boundary_records", [])) != SequenceRuntimeScript.content_fingerprint(expiry_state.get("expiry_boundary_records", [])) or not _array(expiry_rejected_state.get("command_receipt_records", [])).is_empty():
		failures.append("Expiry-only sequence progress transplanted across nodes and authorized ingress.")
	var projected_records := EnvironmentInteractionControllerScript.project_sequence_interactions(_array(finalized.get("records", [])), run_state.scenario_sequence_projection())
	var projected_console: Dictionary = {}
	var projected_scene: Dictionary = {}
	for projected_value in projected_records:
		if typeof(projected_value) != TYPE_DICTIONARY: continue
		if str((projected_value as Dictionary).get("object_id", "")) == "scenario::command_console": projected_console = projected_value as Dictionary
		if str((projected_value as Dictionary).get("object_id", "")) == "scenario::fixture_100": projected_scene = projected_value as Dictionary
	if projected_console.is_empty() or str(projected_console.get("object_type", "")) != "scenario_sequence" or typeof(projected_console.get("focus_rect")) != TYPE_RECT2 or _array(projected_console.get("scenario_sequence_actions", [])).size() != 2:
		failures.append("Final semantic interaction projection did not materialize the scenario command surface in the room UI.")
	if projected_scene.is_empty() or str(projected_scene.get("object_type", "")) != "scenario_scene_object" or bool(projected_scene.get("interactive", true)):
		failures.append("Final semantic projection did not materialize scenario scene objects alongside interactions.")
	var collision_record := _presentation_record("scenario::command_console", "info", "spoof", Rect2(0.2, 0.2, 0.1, 0.1))
	collision_record["owner_namespace"] = "base"
	collision_record["stable_object_id"] = "spoof"
	var collision_projection := EnvironmentInteractionControllerScript.project_sequence_interactions([collision_record], run_state.scenario_sequence_projection())
	var collision_count := 0
	var collision_owner := ""
	for collision_value in collision_projection:
		if str(_dict(collision_value).get("object_id", "")) == "scenario::command_console":
			collision_count += 1
			collision_owner = str(_dict(collision_value).get("owner_namespace", ""))
	if collision_count != 1 or collision_owner != "scenario":
		failures.append("Scenario full-owned presentation identity collided with or duplicated a base presentation alias.")
	var transplant := RunStateScript.new()
	transplant.current_environment = run_state.current_environment.duplicate(true)
	var donor_environment := run_state.current_environment.duplicate(true)
	donor_environment["id"] = "bar_donor"
	donor_environment["world_node_id"] = "donor_node"
	var donor_inventory := EnvironmentSemanticInventoryScript.for_instance(
		donor_environment,
		library,
		_array(run_state.current_environment.get("scenario_base_interactions", [])),
		_array(run_state.current_environment.get("scenario_base_actors", []))
	)
	if not EnvironmentSemanticInventoryScript.validate(donor_inventory).is_empty():
		failures.append("Valid sealed-inventory transplant fixture could not build its donor proof.")
	else:
		transplant.current_environment["scenario_semantic_inventory"] = donor_inventory
		transplant.current_environment["scenario_semantic_inventory_version"] = int(donor_inventory.get("schema_version", 0))
		transplant.current_environment["scenario_semantic_digest"] = str(donor_inventory.get("digest", ""))
		transplant.current_environment["scenario_semantic_ready"] = true
		var transplant_before := JSON.stringify(transplant.current_environment)
		var transplant_command := transplant.scenario_sequence_command("prepare", "transplant:command", {}, "scenario", "command_console")
		if bool(transplant_command.get("ok", true)) or JSON.stringify(transplant.current_environment) != transplant_before:
			failures.append("A valid sealed semantic inventory transplanted from another environment authorized command ingress.")
	var progressed_donor := RunStateScript.new()
	progressed_donor.current_environment = run_state.current_environment.duplicate(true)
	progressed_donor.bankroll = 10
	for key in ["scenario_semantic_ready", "scenario_semantic_inventory", "scenario_semantic_inventory_version", "scenario_semantic_digest", "scenario_base_interactions", "scenario_base_actors", "scenario_base_producer_context", "scenario_event_choices", "scenario_sequence_state", "scenario_sequence_projection"]:
		progressed_donor.current_environment.erase(key)
	progressed_donor.current_environment["scenario_sequence_pending_visit_id"] = str(progressed_donor.current_environment.get("environment_visit_id", ""))
	progressed_donor.scenario_prepare_semantic_finalization()
	var progressed_donor_finalized := progressed_donor.scenario_finalize_base_semantics([presentation], library)
	var progressed_donor_state := _dict(progressed_donor.current_environment.get("scenario_sequence_state", {}))
	var progressed_donor_descriptor := SequenceRuntimeScript._command_descriptor(progressed_donor_state, definition, "scenario", "command_console", "prepare")
	var donor_progress := progressed_donor.scenario_sequence_command(
		"prepare",
		"node-binding:prepare",
		{},
		"scenario",
		"command_console",
		str(progressed_donor_descriptor.get("action_origin_owner_namespace", "")),
		str(progressed_donor_descriptor.get("action_origin_stable_object_id", "")),
		str(progressed_donor_descriptor.get("action_origin_receipt_key", "")),
		str(progressed_donor_descriptor.get("action_origin_boundary_id", "")),
		str(progressed_donor_descriptor.get("action_origin_fingerprint", "")),
	)
	if not bool(progressed_donor_finalized.get("ok", false)) or not bool(donor_progress.get("ok", false)):
		failures.append("Progressed-node transplant fixture could not finalize and advance its donor sequence: %s / %s" % [JSON.stringify(progressed_donor_finalized.get("errors", [])), JSON.stringify(donor_progress.get("errors", []))])
	else:
		var progressed_state := _dict(progressed_donor.current_environment.get("scenario_sequence_state", {}))
		var recipient_environment := progressed_donor.current_environment.duplicate(true)
		recipient_environment["world_node_id"] = "recipient_node"
		var recipient_inventory := EnvironmentSemanticInventoryScript.for_instance(
			recipient_environment,
			library,
			_array(recipient_environment.get("scenario_base_interactions", [])),
			_array(recipient_environment.get("scenario_base_actors", []))
		)
		if not EnvironmentSemanticInventoryScript.validate_instance_binding(recipient_inventory, recipient_environment).is_empty():
			failures.append("Progressed-node transplant fixture could not build a recipient-bound semantic proof.")
		else:
			recipient_environment["scenario_semantic_inventory"] = recipient_inventory
			recipient_environment["scenario_semantic_inventory_version"] = int(recipient_inventory.get("schema_version", 0))
			recipient_environment["scenario_semantic_digest"] = str(recipient_inventory.get("digest", ""))
			recipient_environment["scenario_semantic_ready"] = true
			for ingress_kind in ["command", "fact"]:
				var node_transplant := RunStateScript.new()
				node_transplant.current_environment = recipient_environment.duplicate(true)
				var ingress_result: Dictionary = node_transplant.scenario_sequence_command("finish", "node-binding:command", {}, "scenario", "command_console") if ingress_kind == "command" else node_transplant.scenario_enqueue_fact("world_boundary", "scenario", {"amount": 1, "action_index": 0}, "node-binding:fact")
				var rejected_state := _dict(node_transplant.current_environment.get("scenario_sequence_state", {}))
				if bool(ingress_result.get("ok", true)) or str(rejected_state.get("status", "")) != SequenceRuntimeScript.STATUS_CLEANED or str(rejected_state.get("node_id", "")) != str(progressed_state.get("node_id", "")) or str(rejected_state.get("phase_id", "")) != str(progressed_state.get("phase_id", "")) or int(rejected_state.get("phase_action_counter", -1)) != int(progressed_state.get("phase_action_counter", -1)) or SequenceRuntimeScript.content_fingerprint(rejected_state.get("command_receipts", [])) != SequenceRuntimeScript.content_fingerprint(progressed_state.get("command_receipts", [])) or SequenceRuntimeScript.content_fingerprint(rejected_state.get("fact_receipts", [])) != SequenceRuntimeScript.content_fingerprint(progressed_state.get("fact_receipts", [])):
					failures.append("Progressed sequence state transplanted to another current node advanced through %s ingress." % ingress_kind)
	var saved := RunStateScript._environment_for_persistent_storage(run_state.current_environment)
	var saved_semantic := _dict(_dict(saved.get("scenario_sequence_state", {})).get("semantic_state", {}))
	if saved.has("scenario_semantic_ready") or saved.has("scenario_semantic_inventory") or saved.has("scenario_base_interactions") or saved.has("scenario_event_choices") or saved_semantic.has("target_inventory") or saved_semantic.has("declared_targets") or saved_semantic.has("base_interactions") or saved_semantic.has("event_choices") or saved_semantic.has("scene_objects") or saved_semantic.has("interactions") or saved_semantic.has("actors") or saved_semantic.has("transition_queue") or _dict(saved.get("scenario_sequence_state", {})).has("resolved_branches") or _dict(saved.get("scenario_sequence_state", {})).has("resolved_outcomes"):
		failures.append("Save serialization retained ephemeral semantic authorization proof.")
	var forged_live := RunStateScript.new()
	forged_live.current_environment = run_state.current_environment.duplicate(true)
	var forged_inventory: Dictionary = _dict(forged_live.current_environment.get("scenario_semantic_inventory", {}))
	if forged_inventory.is_empty():
		failures.append("Semantic finalization did not publish inventory proof for the live-forgery hostile fixture.")
	else:
		forged_inventory["environment_id"] = "forged"
		forged_live.current_environment["scenario_semantic_inventory"] = forged_inventory
		var forged_live_before := JSON.stringify(forged_live.current_environment)
		if bool(forged_live.scenario_sequence_command("prepare", "forged:live", {}, "scenario", "command_console").get("ok", true)) or JSON.stringify(forged_live.current_environment) != forged_live_before:
			failures.append("Digest-invalid live semantic proof authorized or mutated on command ingress.")
	var forged_save := saved.duplicate(true)
	forged_save["scenario_semantic_ready"] = true
	forged_save["scenario_semantic_inventory"] = {"digest": "forged"}
	forged_save["scenario_base_interactions"] = [_interaction_record("base", "forged", "Forged", true)]
	var restored := RunStateScript.new()
	restored.current_environment = RunStateScript._normalize_environment(forged_save)
	var restored_before := JSON.stringify(restored.current_environment)
	if bool(restored.scenario_sequence_command("prepare", "forged:pre_render", {}, "scenario", "command_console").get("ok", true)) or JSON.stringify(restored.current_environment) != restored_before:
		failures.append("Forged saved semantic proof authorized a command before exact rebuild.")
	var mismatch := RunStateScript.new()
	mismatch.current_environment = run_state.current_environment.duplicate(true)
	for key in ["scenario_semantic_ready", "scenario_semantic_inventory", "scenario_base_interactions", "scenario_base_actors"]: mismatch.current_environment.erase(key)
	mismatch.current_environment["scenario_semantic_digest"] = "forged_digest"
	var mismatch_before := mismatch.current_environment.duplicate(true)
	var mismatch_result := mismatch.scenario_finalize_base_semantics([presentation], library)
	var mismatch_semantic_after := _dict(_dict(mismatch.current_environment.get("scenario_sequence_state", {})).get("semantic_state", {}))
	var mismatch_semantic_before := _dict(_dict(mismatch_before.get("scenario_sequence_state", {})).get("semantic_state", {}))
	if bool(mismatch_result.get("ok", true)) or bool(mismatch.current_environment.get("scenario_semantic_ready", false)) or mismatch.current_environment.has("scenario_semantic_inventory") or JSON.stringify(mismatch_semantic_after) != JSON.stringify(mismatch_semantic_before):
		failures.append("Digest-mismatched finalization exposed partial semantic authorization.")
	var hostile_proof_references := [
		{"label": "matching digest with wrong version", "version": valid_proof_version + 1, "digest": valid_proof_digest},
		{"label": "version without digest", "version": valid_proof_version},
		{"label": "digest without version", "digest": valid_proof_digest},
	]
	for proof_reference_value in hostile_proof_references:
		var proof_reference := _dict(proof_reference_value)
		var proof_hostile := RunStateScript.new()
		proof_hostile.current_environment = run_state.current_environment.duplicate(true)
		for key in ["scenario_semantic_ready", "scenario_semantic_inventory", "scenario_base_interactions", "scenario_base_actors", "scenario_semantic_inventory_version", "scenario_semantic_digest"]: proof_hostile.current_environment.erase(key)
		if proof_reference.has("version"): proof_hostile.current_environment["scenario_semantic_inventory_version"] = proof_reference.get("version")
		if proof_reference.has("digest"): proof_hostile.current_environment["scenario_semantic_digest"] = proof_reference.get("digest")
		var reference_before: Dictionary = {}
		for key in ["scenario_semantic_inventory_version", "scenario_semantic_digest"]:
			if proof_hostile.current_environment.has(key): reference_before[key] = proof_hostile.current_environment.get(key)
		var proof_result := proof_hostile.scenario_finalize_base_semantics([presentation], library)
		var reference_after: Dictionary = {}
		for key in ["scenario_semantic_inventory_version", "scenario_semantic_digest"]:
			if proof_hostile.current_environment.has(key): reference_after[key] = proof_hostile.current_environment.get(key)
		if bool(proof_result.get("ok", true)) or bool(proof_hostile.current_environment.get("scenario_semantic_ready", false)) or proof_hostile.current_environment.has("scenario_semantic_inventory") or SequenceRuntimeScript.content_fingerprint(reference_after) != SequenceRuntimeScript.content_fingerprint(reference_before):
			failures.append("Finalization silently replaced or accepted a hostile persisted semantic proof reference: %s." % str(proof_reference.get("label", "unknown")))


static func _check_catalog_rollout(library: ContentLibrary, failures: Array) -> void:
	var definitions: Array = []
	for pool_value in library.environment_scenarios.values():
		definitions.append_array(_array(pool_value))
	var report := SequenceSchemaScript.catalog_rollout_report(definitions, RolloutManifestScript.expected_ids(), OperationRegistryScript, {}, RolloutManifestScript.required_sequence_ids())
	if RolloutManifestScript.EXPECTED_COUNT != 55 or RolloutManifestScript.expected_ids().size() != 55 or not bool(report.get("ok", false)):
		failures.append("Production sequence rollout manifest does not enforce the exact 55-id catalog without blocking pending env06_7 packages: %s" % JSON.stringify(report.get("failures", [])))
	var proof := _fixture_definition()
	proof["id"] = "proof"
	var pending := {"id": "pending"}
	var proof_report := SequenceSchemaScript.catalog_rollout_report([pending, proof], ["pending", "proof"], OperationRegistryScript, {}, ["proof"], {"proof": _fixture_target_inventory(proof)})
	if not bool(proof_report.get("ok", false)):
		failures.append("A valid declared sequence proof was blocked by an explicitly pending catalog id.")
	var missing_report := SequenceSchemaScript.catalog_rollout_report([pending, {"id": "proof"}], ["pending", "proof"], OperationRegistryScript, {}, ["proof"])
	if bool(missing_report.get("ok", true)) or not _contains_text(_array(missing_report.get("failures", [])), "missing its required sequence"):
		failures.append("Rollout manifest accepted a missing sequence-required proof.")


static func _check_schema(failures: Array) -> void:
	var definition := _fixture_definition()
	var errors := SequenceSchemaScript.validate_definition(definition, OperationRegistryScript, _fixture_target_inventory(definition))
	if not errors.is_empty():
		failures.append("Valid sequence schema fixture failed: %s" % JSON.stringify(errors))
	var defaults := SequenceSchemaScript.default_local_state(definition)
	if defaults != {"pressure": 0, "protected_exit": false, "side": "none"}:
		failures.append("Sequence local-state defaults are not typed/deterministic: %s." % JSON.stringify(defaults))
	var normalized := SequenceSchemaScript.normalize_local_state(definition, {"pressure": 99, "protected_exit": "yes", "side": "invalid", "unknown": true})
	if normalized != {"pressure": 5, "protected_exit": false, "side": "none"}:
		failures.append("Sequence local-state normalization did not clamp/reject invalid values: %s." % JSON.stringify(normalized))
	if SequenceSchemaScript.initial_phase_id(definition) != "arrival" or SequenceSchemaScript.phase_ids(definition) != ["arrival", "aftermath"]:
		failures.append("Sequence phase identity/order is unstable.")
	var padded_local := definition.duplicate(true)
	padded_local["sequence"]["local_state_schema"][" pressure "] = padded_local["sequence"]["local_state_schema"]["pressure"]
	padded_local["sequence"]["local_state_schema"].erase("pressure")
	padded_local["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(padded_local)
	if not _contains_text(SequenceSchemaScript.validate_definition(padded_local, OperationRegistryScript, _fixture_target_inventory(padded_local)), "invalid field id"):
		failures.append("Whitespace-padded local field id passed exact descriptor validation.")
	var bad_fact_selector := definition.duplicate(true)
	bad_fact_selector["sequence"]["fact_subscriptions"] = [{"fact_type": "heat_changed", "handler": "set_local", "inputs": {"key": "pressure", "value_from_payload": "source"}}]
	bad_fact_selector["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(bad_fact_selector)
	if not _contains_text(SequenceSchemaScript.validate_definition(bad_fact_selector, OperationRegistryScript, _fixture_target_inventory(bad_fact_selector)), "selector type"):
		failures.append("Fact selector with incompatible payload/local types passed schema validation.")
	var signature_a := SequenceSchemaScript.normalized_signature(definition)
	var renamed := definition.duplicate(true)
	renamed["id"] = "renamed_fixture"
	renamed["display_name"] = "Different prose"
	if SequenceSchemaScript.signature_text(definition) != SequenceSchemaScript.signature_text(renamed) or SequenceSchemaScript.signature_similarity(signature_a, SequenceSchemaScript.normalized_signature(renamed)) != 1.0:
		failures.append("Calculated mechanic signature can be evaded by renaming display identity.")
	var identity_renamed := definition.duplicate(true)
	identity_renamed["sequence"]["phase_graph"]["phases"][0]["scene_ops"][0]["stable_object_id"] = "renamed_prop"
	identity_renamed["sequence"]["phase_graph"]["phases"][0]["scene_ops"][0]["receipt_id"] = "renamed_receipt"
	if SequenceSchemaScript.signature_text(definition) != SequenceSchemaScript.signature_text(identity_renamed):
		failures.append("Calculated mechanic signature changes under stable-id/receipt renaming.")
	var reordered := definition.duplicate(true)
	reordered["sequence"]["phase_graph"]["phases"].reverse()
	if SequenceSchemaScript.signature_text(definition) != SequenceSchemaScript.signature_text(reordered):
		failures.append("Calculated mechanic signature changes under phase reordering.")
	var mismatched_signature := definition.duplicate(true)
	mismatched_signature["sequence"]["sequence_signature"] = "forged"
	if not _contains_text(SequenceSchemaScript.validate_definition(mismatched_signature, OperationRegistryScript, _fixture_target_inventory(mismatched_signature)), "sequence_signature mismatch"):
		failures.append("Sequence schema accepted an authored/calculated signature mismatch.")
	var boundary_expectations := [[0.599, "pass"], [0.600, "warning"], [0.719, "warning"], [0.720, "blocking_review"], [0.819, "blocking_review"], [0.820, "fail"]]
	for expectation_value in boundary_expectations:
		var expectation := expectation_value as Array
		var score := float(expectation[0])
		var expected_band := str(expectation[1])
		if str(SequenceSchemaScript.uniqueness_band(score).get("status", "")) != expected_band:
			failures.append("Uniqueness band boundary %.3f did not resolve to %s." % [score, expected_band])
	if str(SequenceSchemaScript.uniqueness_band(0.1, true).get("status", "")) != "equal_hash_hard_fail":
		failures.append("Equal normalized mechanic hashes are not a hard failure.")
	var exact_count := SequenceSchemaScript.catalog_uniqueness_report([definition], 2, OperationRegistryScript, {}, {str(definition.get("id", "")): _fixture_target_inventory(definition)})
	if bool(exact_count.get("ok", true)) or not _contains_text(_array(exact_count.get("failures", [])), "expected 2"):
		failures.append("Sequence rollout audit did not enforce exact catalog count.")


static func _check_registered_operations(failures: Array) -> void:
	var operations := OperationRegistryScript.registered_operations()
	var expected := {
		"scene_ops": ["spawn", "remove", "move", "replace", "reveal", "hide", "enable", "disable", "set_state", "set_appearance"],
		"interaction_ops": ["add", "remove", "replace", "gate", "retarget", "augment"],
		"actor_ops": ["spawn", "despawn", "set_position", "set_route", "set_pose", "set_behavior"],
		"transition_ops": ["stage", "sound", "music", "scene_change", "feedback"],
		"service_ops": ["add", "remove", "gate", "replace"],
		"game_ops": ["add", "remove", "gate", "set_modifier"],
		"route_ops": ["open", "close", "gate", "retarget"],
	}
	if operations != expected:
		failures.append("Scenario registered operation surface changed: %s." % JSON.stringify(operations))
	var state := _operation_semantic_seed()
	for family_value in expected.keys():
		var family := str(family_value)
		var family_operations: Array = []
		for index in range((expected[family] as Array).size()):
			family_operations.append(_operation_fixture(family, str((expected[family] as Array)[index]), index))
		var boundary_scope := "fixture:node:phase:%s" % family
		var applied := OperationRegistryScript.apply_operations(state, family, family_operations, boundary_scope)
		if not bool(applied.get("ok", false)):
			failures.append("Registered %s fixtures failed: %s." % [family, JSON.stringify(applied.get("errors", []))])
			continue
		state = _dict(applied.get("state", {}))
		var replay := OperationRegistryScript.apply_operations(state, family, family_operations, boundary_scope)
		if not bool(replay.get("ok", false)) or not _array(replay.get("applied", [])).is_empty() or JSON.stringify(replay.get("state", {})) != JSON.stringify(state):
			failures.append("Registered %s operations are not idempotent by boundary receipt." % family)
	if _array(state.get("operation_receipts", [])).size() != 39:
		failures.append("Registered operation fixture did not receipt every operation exactly once.")
	_check_golden_operation_state(state, failures)
	var before_atomic := JSON.stringify(state)
	var valid := _operation_fixture("scene_ops", "set_state", 901)
	var invalid := _operation_fixture("scene_ops", "set_state", 902)
	invalid["op"] = "reflect"
	var atomic := OperationRegistryScript.apply_operations(state, "scene_ops", [valid, invalid], "fixture:node:phase:atomic")
	if bool(atomic.get("ok", true)) or not _array(atomic.get("applied", [])).is_empty() or JSON.stringify(atomic.get("state", {})) != before_atomic:
		failures.append("Scenario operation batch was not prevalidated and atomic.")
	var duplicate_receipt_a := _operation_fixture("scene_ops", "set_state", 903)
	var duplicate_receipt_b := _operation_fixture("scene_ops", "set_appearance", 904)
	duplicate_receipt_b["receipt_id"] = duplicate_receipt_a["receipt_id"]
	if bool(OperationRegistryScript.apply_operations(state, "scene_ops", [duplicate_receipt_a, duplicate_receipt_b], "fixture:node:phase:duplicate").get("ok", true)):
		failures.append("Scenario operation batch accepted duplicate authored receipt ids.")
	var conflicting_replay := _operation_fixture("scene_ops", "set_state", 8)
	conflicting_replay["state"] = "conflicting"
	var conflict := OperationRegistryScript.apply_operations(state, "scene_ops", [conflicting_replay], "fixture:node:phase:scene_ops")
	if bool(conflict.get("ok", true)) or not _contains_text(_array(conflict.get("errors", [])), "conflicting content"):
		failures.append("Scenario operation receipt accepted conflicting replay content.")
	var wrong_family := _operation_fixture("scene_ops", "set_state", 905)
	wrong_family["family"] = "actor_ops"
	if OperationRegistryScript.validate_operation("scene_ops", wrong_family).is_empty():
		failures.append("Scenario operation accepted a mismatched family field.")
	if bool(OperationRegistryScript.apply_operations(state, "scene_ops", [valid], "unscoped").get("ok", true)):
		failures.append("Scenario operation batch accepted an unscoped boundary receipt.")
	var handlers := OperationRegistryScript.registered_handlers()
	for handler_id in ["set_local", "increment_local", "complete_objective_step", "record_outcome", "publish_feedback", "request_cleanup", "event_bridge"]:
		var handler := _dict(handlers.get(handler_id, {}))
		if handler.is_empty() or str(handler.get("rng", "")) != "none" or not handler.has("persistent") or _array(handler.get("outputs", [])).is_empty():
			failures.append("Scenario handler %s lacks explicit input/output/persistence/RNG contract." % handler_id)
	var absent_target := _operation_fixture("scene_ops", "set_state", 9999)
	var absent_result := OperationRegistryScript.apply_operations(state, "scene_ops", [absent_target], "fixture:node:phase:absent")
	if bool(absent_result.get("ok", true)) or JSON.stringify(absent_result.get("state", {})) != JSON.stringify(state):
		failures.append("Scenario operation synthesized an undeclared absent target.")
	var bad_anchor := _operation_fixture("scene_ops", "spawn", 910)
	bad_anchor["object"]["anchor_id"] = "forged_anchor"
	if bool(OperationRegistryScript.apply_operations(_operation_semantic_seed(), "scene_ops", [bad_anchor], "fixture:node:phase:bad_anchor").get("ok", true)):
		failures.append("Scenario scene operation accepted an unauthored semantic anchor.")
	var bad_zone := _operation_fixture("actor_ops", "spawn", 911)
	bad_zone["actor"].erase("anchor_id")
	bad_zone["actor"]["zone_id"] = "forged_zone"
	if bool(OperationRegistryScript.apply_operations(_operation_semantic_seed(), "actor_ops", [bad_zone], "fixture:node:phase:bad_zone").get("ok", true)):
		failures.append("Scenario actor operation accepted an unauthored semantic zone.")
	var bad_route := _operation_fixture("actor_ops", "set_route", 3)
	bad_route["route_id"] = "forged_bar_route"
	if bool(OperationRegistryScript.apply_operations(_operation_semantic_seed(), "actor_ops", [bad_route], "fixture:node:phase:bad_route").get("ok", true)):
		failures.append("Scenario actor operation accepted a suffix-like route without exact declared/inventory proof.")
	var ambiguous_route_state := _operation_semantic_seed()
	ambiguous_route_state["declared_targets"]["routes"].append("base::layer:bar_route")
	ambiguous_route_state["target_inventory"]["routes"].append("base::layer:bar_route")
	var ambiguous_route := _operation_fixture("actor_ops", "set_route", 3)
	ambiguous_route["route_id"] = "bar_route"
	if bool(OperationRegistryScript.apply_operations(ambiguous_route_state, "actor_ops", [ambiguous_route], "fixture:node:phase:ambiguous_route").get("ok", true)):
		failures.append("Actor set_route accepted a bare component shared by world and layer route identities.")
	var bad_presentation := _operation_fixture("interaction_ops", "add", 940)
	for presentation_alias in ["", "fixture_940", "base::fixture_target_940"]:
		bad_presentation["interaction"]["presentation_object_id"] = presentation_alias
		if OperationRegistryScript.validate_operation("interaction_ops", bad_presentation).is_empty():
			failures.append("Scenario interaction create accepted non-owned presentation identity %s." % presentation_alias)
	var derived_presentation := _operation_fixture("interaction_ops", "add", 941)
	derived_presentation["interaction"].erase("presentation_object_id")
	var derived_result := OperationRegistryScript.apply_operations(_operation_semantic_seed(), "interaction_ops", [derived_presentation], "fixture:node:phase:derived_presentation")
	var derived_record: Dictionary = _dict(_dict(_dict(derived_result.get("state", {})).get("interactions", {})).get("scenario::fixture_941", {}))
	if not bool(derived_result.get("ok", false)) or str(_dict(derived_record).get("presentation_object_id", "")) != "scenario::fixture_941":
		failures.append("Scenario interaction create did not centrally derive its full owned presentation identity.")
	var alias_left := OperationRegistryScript.structural_receipt_key("a:b:c:d", "scene_ops", "x:y")
	var alias_right := OperationRegistryScript.structural_receipt_key("a:b:c:d:x", "scene_ops", "y")
	if alias_left == alias_right:
		failures.append("Structural operation receipt identity aliases colon-delimited tuples.")


static func _check_interaction_identity(failures: Array) -> void:
	var base := [_interaction_record("base", "exit", "Leave", true)]
	var gate := _interaction_record("scenario", "exit_gate", "Fight blocks the door", false)
	gate["mode"] = "gate"
	gate["target_owner_namespace"] = "base"
	gate["target_stable_object_id"] = "exit"
	gate["disabled_reason"] = "Clear a readable path first."
	var resolved := OperationRegistryScript.resolve_interactions(base, [gate])
	var records := _array(resolved.get("records", []))
	if not bool(resolved.get("ok", false)) or records.size() != 1 or bool(_dict(records[0]).get("enabled", true)) or str(_dict(records[0]).get("disabled_reason", "")).is_empty():
		failures.append("Explicit scenario gate did not preserve and fail-close the base interaction identity.")
	var duplicate := OperationRegistryScript.resolve_interactions(base, [_interaction_record("base", "exit", "Hostile duplicate", true)])
	if bool(duplicate.get("ok", true)) or not _array(duplicate.get("records", [])).is_empty():
		failures.append("Illegal same-owner interaction collision did not fail closed.")
	var low_priority := _interaction_record("traveler", "bad_replace", "Traveler", true)
	low_priority["mode"] = "replace"
	low_priority["target_owner_namespace"] = "scenario"
	low_priority["target_stable_object_id"] = "high"
	var higher := _interaction_record("scenario", "high", "Scenario", true)
	var priority_result := OperationRegistryScript.resolve_interactions([higher], [low_priority])
	if bool(priority_result.get("ok", true)) or _array(priority_result.get("records", [])).size() != 1 or str(_dict(_array(priority_result.get("records", []))[0]).get("owner_namespace", "")) != "scenario":
		failures.append("Lower-priority interaction override did not fail closed.")
	var triple := OperationRegistryScript.resolve_interactions([
		_interaction_record("base", "triple", "One", true),
		_interaction_record("base", "triple", "Two", true),
		_interaction_record("base", "triple", "Three", true),
	], [])
	if bool(triple.get("ok", true)) or not _array(triple.get("records", [])).is_empty():
		failures.append("Triple duplicate interaction identity was not permanently tainted.")
	var invalid_owner := _interaction_record("intruder", "bad", "Bad", true)
	var invalid_mode := _interaction_record("scenario", "bad_mode", "Bad", true)
	invalid_mode["mode"] = "steal"
	var missing_target := _interaction_record("scenario", "missing_target", "Missing", true)
	missing_target["mode"] = "replace"
	missing_target["target_owner_namespace"] = "base"
	missing_target["target_stable_object_id"] = "absent"
	var hostile := OperationRegistryScript.resolve_interactions(base, [invalid_owner, invalid_mode, missing_target])
	if bool(hostile.get("ok", true)) or _array(hostile.get("records", [])).size() != 1 or str(_dict(_array(hostile.get("records", []))[0]).get("stable_object_id", "")) != "exit":
		failures.append("Invalid owner/mode/missing-target overlays leaked invalid interaction records.")
	var inaccessible := _interaction_record("scenario", "bad_accessibility", "Bad", true)
	inaccessible["focus_order"] = "first"
	inaccessible["hit_bounds"] = {"w": 43, "h": 44}
	inaccessible["min_target_size"] = 43
	inaccessible["safe_exit"] = "yes"
	inaccessible["input_actions"] = [7]
	var inaccessible_result := OperationRegistryScript.resolve_interactions(base, [inaccessible])
	if bool(inaccessible_result.get("ok", true)) or _array(inaccessible_result.get("records", [])).size() != 1:
		failures.append("Inaccessible interaction overlay did not fail closed without leaking a record.")
	var hostile_base := _interaction_record("base", "non_add_base", "Bad base", true)
	hostile_base["mode"] = "gate"
	hostile_base["target_owner_namespace"] = "base"
	hostile_base["target_stable_object_id"] = "exit"
	if bool(OperationRegistryScript.resolve_interactions([hostile_base], []).get("ok", true)):
		failures.append("Base interaction accepted a non-add overlay mode.")
	var competing := gate.duplicate(true)
	competing["stable_object_id"] = "exit_gate_two"
	var competing_result := OperationRegistryScript.resolve_interactions(base, [gate, competing])
	var competing_records := _array(competing_result.get("records", []))
	if bool(competing_result.get("ok", true)) or competing_records.size() != 1 or not bool(_dict(competing_records[0]).get("enabled", false)):
		failures.append("Competing interaction overlays did not fail closed before mutating their shared target.")


static func _check_golden_operation_state(state: Dictionary, failures: Array) -> void:
	var scene := _dict(state.get("scene_objects", {}))
	var interactions := _dict(state.get("interactions", {}))
	var actors := _dict(state.get("actors", {}))
	var services := _dict(state.get("services", {}))
	var games := _dict(state.get("games", {}))
	var routes := _dict(state.get("routes", {}))
	var checks := [
		[not scene.has("scenario::fixture_1"), "scene remove"],
		[str(_dict(scene.get("scenario::fixture_2", {})).get("anchor_id", "")) == "bar_floor_3", "scene move"],
		[bool(_dict(scene.get("scenario::fixture_4", {})).get("visible", false)), "scene reveal"],
		[not bool(_dict(scene.get("scenario::fixture_5", {})).get("visible", true)), "scene hide"],
		[bool(_dict(scene.get("scenario::fixture_6", {})).get("enabled", false)), "scene enable"],
		[not bool(_dict(scene.get("scenario::fixture_7", {})).get("enabled", true)), "scene disable"],
		[str(_dict(scene.get("scenario::fixture_8", {})).get("state", "")) == "ready", "scene state"],
		[str(_dict(scene.get("scenario::fixture_9", {})).get("appearance", "")) == "scuffed", "scene appearance"],
		[str(_dict(interactions.get("scenario::fixture_2", {})).get("mode", "")) == "replace", "interaction replace"],
		[not bool(_dict(interactions.get("scenario::fixture_3", {})).get("enabled", true)), "interaction gate"],
		[str(_dict(interactions.get("scenario::fixture_4", {})).get("source_id", "")) == "fixture_source", "interaction retarget"],
		[_array(_dict(interactions.get("scenario::fixture_5", {})).get("available_actions", [])).size() == 1, "interaction augment"],
		[not actors.has("scenario::fixture_1"), "actor despawn"],
		[str(_dict(actors.get("scenario::fixture_2", {})).get("anchor_id", "")) == "bar_actor_2", "actor position"],
		[str(_dict(actors.get("scenario::fixture_3", {})).get("route_id", "")) == "base::world:bar_route", "actor route"],
		[str(_dict(actors.get("scenario::fixture_4", {})).get("pose", "")) == "brace", "actor pose"],
		[str(_dict(actors.get("scenario::fixture_5", {})).get("behavior", "")) == "watch", "actor behavior"],
		[_array(state.get("transition_queue", [])).size() == 5, "transition reducers"],
		[services.has("scenario::fixture_0") and not services.has("scenario::fixture_1") and not bool(_dict(services.get("scenario::fixture_2", {})).get("enabled", true)) and services.has("scenario::fixture_3"), "service reducers"],
		[games.has("scenario::fixture_0") and not games.has("scenario::fixture_1") and not bool(_dict(games.get("scenario::fixture_2", {})).get("enabled", true)) and games.has("scenario::fixture_3") and not _dict(_dict(games.get("scenario::fixture_3", {})).get("modifier", {})).is_empty(), "game reducers"],
		[bool(_dict(routes.get("scenario::fixture_0", {})).get("enabled", false)), "route open"],
		[not bool(_dict(routes.get("scenario::fixture_1", {})).get("enabled", true)), "route close"],
		[not bool(_dict(routes.get("scenario::fixture_2", {})).get("enabled", true)), "route gate"],
		[str(_dict(routes.get("scenario::fixture_3", {})).get("source_id", "")) == "alternate_exit", "route retarget"],
	]
	for check_value in checks:
		var check := check_value as Array
		if not bool(check[0]):
			failures.append("Golden registered-operation state failed for %s." % str(check[1]))


static func _check_negative_fixtures(failures: Array) -> void:
	var invalid_operation := _operation_fixture("scene_ops", "spawn", 0)
	invalid_operation["object"]["asset"] = "res://untrusted/script.gd"
	if OperationRegistryScript.validate_operation("scene_ops", invalid_operation).is_empty():
		failures.append("Scenario operation registry accepted an arbitrary resource path.")
	if OperationRegistryScript.validate_operation("scene_ops", {"op": "reflect", "owner_namespace": "scenario", "stable_object_id": "bad"}).is_empty():
		failures.append("Scenario operation registry accepted an unregistered operation.")
	var invalid := _fixture_definition()
	invalid["sequence"]["phase_graph"]["phases"].append({"id": "orphan", "label": "Orphan", "arrival_feedback": "Nobody reaches this.", "exit_prompt": "Leave", "terminal": true, "branches": []})
	if not _contains_text(SequenceSchemaScript.validate_definition(invalid, OperationRegistryScript), "unreachable phase"):
		failures.append("Sequence schema accepted an unreachable phase.")
	var exception := _fixture_definition()
	exception["sequence"]["owner_exceptions"] = [{"row": "semantic_changes", "reason": "Owner decision"}]
	if not _contains_text(SequenceSchemaScript.validate_definition(exception, OperationRegistryScript), "owner exception"):
		failures.append("Sequence schema accepted an unsigned owner exception.")
	var invalid_fact := _fixture_definition()
	invalid_fact["sequence"]["fact_subscriptions"] = ["invented_fact"]
	if not _contains_text(SequenceSchemaScript.validate_definition(invalid_fact, OperationRegistryScript), "unregistered fact type"):
		failures.append("Sequence schema accepted an unregistered fact subscription.")
	var dead_end := _fixture_definition()
	dead_end["sequence"]["phase_graph"]["phases"][0]["branches"] = []
	if not _contains_text(SequenceSchemaScript.validate_definition(dead_end, OperationRegistryScript), "dead end"):
		failures.append("Sequence schema accepted a non-terminal dead end.")
	var duplicate_branch := _fixture_definition()
	duplicate_branch["sequence"]["phase_graph"]["phases"][1]["branches"][1]["id"] = "finish"
	if not _contains_text(SequenceSchemaScript.validate_definition(duplicate_branch, OperationRegistryScript), "duplicate branch"):
		failures.append("Sequence schema accepted duplicate branch ids.")
	var nonterminating := _fixture_definition()
	nonterminating["sequence"]["phase_graph"]["phases"][1]["terminal"] = false
	nonterminating["sequence"]["phase_graph"]["phases"][1]["branches"] = [{"id": "loop", "condition": {"type": "always"}, "next_phase": "arrival"}]
	if not _contains_text(SequenceSchemaScript.validate_definition(nonterminating, OperationRegistryScript), "no path to a terminal"):
		failures.append("Sequence schema accepted a reachable non-terminating cycle.")
	var mismatched_aftermath := _fixture_definition()
	mismatched_aftermath["sequence"]["aftermath"].erase("refused")
	if not _contains_text(SequenceSchemaScript.validate_definition(mismatched_aftermath, OperationRegistryScript), "exactly match reachable outcomes"):
		failures.append("Sequence schema accepted aftermath keys that do not match terminal outcomes.")
	var duplicate_effect := _fixture_definition()
	duplicate_effect["sequence"]["aftermath"]["refused"] = duplicate_effect["sequence"]["aftermath"]["repaired"].duplicate(true)
	if not _contains_text(SequenceSchemaScript.validate_definition(duplicate_effect, OperationRegistryScript), "duplicates the normalized material effect"):
		failures.append("Sequence schema accepted duplicate normalized aftermath effects.")
	var projection_duplicate := _fixture_definition()
	var projection_ready := _operation_fixture("scene_ops", "set_state", 901)
	projection_ready["stable_object_id"] = "fixture_101"
	projection_ready["state"] = "ready"
	var projection_done_a := _operation_fixture("scene_ops", "set_state", 902)
	projection_done_a["stable_object_id"] = "fixture_101"
	projection_done_a["state"] = "done"
	var projection_done_b := _operation_fixture("scene_ops", "set_state", 903)
	projection_done_b["stable_object_id"] = "fixture_101"
	projection_done_b["state"] = "done"
	projection_duplicate["sequence"]["aftermath"]["repaired"]["scene_ops"] = [projection_ready, projection_done_a]
	projection_duplicate["sequence"]["aftermath"]["repaired"]["route_ops"] = []
	projection_duplicate["sequence"]["aftermath"]["broken"]["scene_ops"] = [projection_done_b]
	projection_duplicate["sequence"]["aftermath"]["broken"]["route_ops"] = []
	projection_duplicate["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(projection_duplicate)
	if not _contains_text(SequenceSchemaScript.validate_definition(projection_duplicate, OperationRegistryScript, _fixture_target_inventory(projection_duplicate)), "duplicates the normalized material effect"):
		failures.append("Sequence schema treated different authored operation lists with the same final projection as unique aftermaths.")
	var created_on_one_path := _two_path_repaired_fixture()
	var spawned := _operation_fixture("scene_ops", "spawn", 904)
	spawned["stable_object_id"] = "path_object"
	created_on_one_path["sequence"]["phase_graph"]["phases"][1]["scene_ops"] = [spawned]
	var mutate_created := _operation_fixture("scene_ops", "set_state", 905)
	mutate_created["stable_object_id"] = "path_object"
	created_on_one_path["sequence"]["aftermath"]["repaired"]["scene_ops"] = [mutate_created]
	created_on_one_path["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(created_on_one_path)
	if not _contains_text(SequenceSchemaScript.validate_definition(created_on_one_path, OperationRegistryScript, _fixture_target_inventory(created_on_one_path)), "not material on every reachable terminal path"):
		failures.append("Sequence schema authorized an aftermath target created on only one mutually exclusive path.")
	var removed_on_one_path := _two_path_repaired_fixture()
	var path_remove := _operation_fixture("scene_ops", "remove", 906)
	path_remove["stable_object_id"] = "fixture_101"
	removed_on_one_path["sequence"]["phase_graph"]["phases"][1]["scene_ops"] = [path_remove]
	removed_on_one_path["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(removed_on_one_path)
	if not _contains_text(SequenceSchemaScript.validate_definition(removed_on_one_path, OperationRegistryScript, _fixture_target_inventory(removed_on_one_path)), "not material on every reachable terminal path"):
		failures.append("Sequence schema authorized an aftermath target removed on one mutually exclusive path.")
	var duplicate_at_reconvergence := _two_path_repaired_fixture()
	duplicate_at_reconvergence["sequence"]["phase_graph"]["phases"][2]["terminal"] = false
	duplicate_at_reconvergence["sequence"]["phase_graph"]["phases"][2]["branches"] = [{"id": "rejoin", "condition": {"type": "always"}, "next_phase": "aftermath"}]
	var path_create := _operation_fixture("scene_ops", "spawn", 920)
	path_create["stable_object_id"] = "rejoined_object"
	duplicate_at_reconvergence["sequence"]["phase_graph"]["phases"][2]["scene_ops"] = [path_create]
	var joined_create := path_create.duplicate(true)
	joined_create["receipt_id"] = "scene_spawn_joined"
	duplicate_at_reconvergence["sequence"]["phase_graph"]["phases"][1]["scene_ops"] = [joined_create]
	duplicate_at_reconvergence["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(duplicate_at_reconvergence)
	if not _contains_text(SequenceSchemaScript.validate_definition(duplicate_at_reconvergence, OperationRegistryScript, _fixture_target_inventory(duplicate_at_reconvergence)), "duplicate or targets an object that is not live"):
		failures.append("Sequence schema accepted a duplicate create at path reconvergence.")
	var maybe_live_mutation := duplicate_at_reconvergence.duplicate(true)
	var joined_mutation := _operation_fixture("scene_ops", "set_state", 921)
	joined_mutation["stable_object_id"] = "rejoined_object"
	maybe_live_mutation["sequence"]["phase_graph"]["phases"][1]["scene_ops"] = [joined_mutation]
	maybe_live_mutation["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(maybe_live_mutation)
	if not _contains_text(SequenceSchemaScript.validate_definition(maybe_live_mutation, OperationRegistryScript, _fixture_target_inventory(maybe_live_mutation)), "duplicate or targets an object that is not live"):
		failures.append("Sequence schema accepted a mutation of a maybe-not-live target at path reconvergence.")
	var projection_targets := SequenceSchemaScript._material_target_seed(_fixture_definition()["sequence"], _fixture_target_inventory(_fixture_definition()))
	var projection_state := _operation_fixture("scene_ops", "set_state", 930)
	projection_state["stable_object_id"] = "fixture_101"
	projection_state["state"] = "ready"
	var projection_appearance := _operation_fixture("scene_ops", "set_appearance", 931)
	projection_appearance["stable_object_id"] = "fixture_101"
	projection_appearance["appearance"] = "scuffed"
	SequenceSchemaScript._apply_material_target_projection("scene_ops", projection_state, projection_targets)
	SequenceSchemaScript._apply_material_target_projection("scene_ops", projection_appearance, projection_targets)
	var merged_projection := _dict(_dict(projection_targets.get("scene_objects", {})).get("scenario::fixture_101", {}))
	if str(merged_projection.get("state", "")) != "ready" or str(merged_projection.get("appearance", "")) != "scuffed":
		failures.append("Terminal path projection overwrote rather than merged sequential semantic field mutations.")
	var semantic_value_pairs := [
		["actor_ops", {"family": "actor_ops", "op": "set_position", "receipt_id": "a", "owner_namespace": "scenario", "stable_object_id": "fixture_103", "anchor_id": "left"}, {"family": "actor_ops", "op": "set_position", "receipt_id": "b", "owner_namespace": "scenario", "stable_object_id": "fixture_103", "anchor_id": "right"}],
		["actor_ops", {"family": "actor_ops", "op": "set_route", "receipt_id": "a", "owner_namespace": "scenario", "stable_object_id": "fixture_103", "route_id": "base::world:casino"}, {"family": "actor_ops", "op": "set_route", "receipt_id": "b", "owner_namespace": "scenario", "stable_object_id": "fixture_103", "route_id": "base::layer:casino"}],
		["game_ops", {"family": "game_ops", "op": "set_modifier", "receipt_id": "a", "owner_namespace": "scenario", "stable_object_id": "fixture_103", "modifier": {"payout": 2}}, {"family": "game_ops", "op": "set_modifier", "receipt_id": "b", "owner_namespace": "scenario", "stable_object_id": "fixture_103", "modifier": {"payout": 3}}],
		["interaction_ops", {"family": "interaction_ops", "op": "augment", "receipt_id": "a", "owner_namespace": "scenario", "stable_object_id": "overlay", "mode": "augment", "target_owner_namespace": "base", "target_stable_object_id": "door", "available_actions": [{"id": "act", "handler": "set_local", "inputs": {"key": "side", "value": "left"}}]}, {"family": "interaction_ops", "op": "augment", "receipt_id": "b", "owner_namespace": "scenario", "stable_object_id": "overlay", "mode": "augment", "target_owner_namespace": "base", "target_stable_object_id": "door", "available_actions": [{"id": "act", "handler": "set_local", "inputs": {"key": "side", "value": "right"}}]}],
	]
	for pair_value in semantic_value_pairs:
		var pair := pair_value as Array
		if JSON.stringify(SequenceSchemaScript._normalized_operation_feature(str(pair[0]), _dict(pair[1]))) == JSON.stringify(SequenceSchemaScript._normalized_operation_feature(str(pair[0]), _dict(pair[2]))):
			failures.append("Normalized terminal projection omitted authored anchor/route/modifier/action input values for %s." % str(pair[0]))
	var unknown_key := _fixture_definition()
	unknown_key["sequence"]["phase_graph"]["phases"][0]["mystery"] = true
	if not _contains_text(SequenceSchemaScript.validate_definition(unknown_key, OperationRegistryScript), "unknown key"):
		failures.append("Sequence schema accepted an unknown phase key.")
	var nonterminal_outcome := _fixture_definition()
	nonterminal_outcome["sequence"]["phase_graph"]["phases"][0]["branches"] = [{"id": "early", "condition": {"type": "always"}, "outcome": "repaired"}]
	if not _contains_text(SequenceSchemaScript.validate_definition(nonterminal_outcome, OperationRegistryScript), "non-terminal phase"):
		failures.append("Sequence schema accepted an outcome edge from a non-terminal phase.")
	var unknown_objective := _fixture_definition()
	unknown_objective["sequence"]["phase_graph"]["phases"][0]["objective_ids"] = ["missing_objective"]
	if not _contains_text(SequenceSchemaScript.validate_definition(unknown_objective, OperationRegistryScript), "unknown objective"):
		failures.append("Sequence schema accepted an unknown objective reference.")
	var unknown_local := _fixture_definition()
	unknown_local["sequence"]["phase_graph"]["phases"][0]["entry_conditions"] = [{"type": "local_equals", "key": "missing_local", "value": true}]
	if not _contains_text(SequenceSchemaScript.validate_definition(unknown_local, OperationRegistryScript), "unknown local state"):
		failures.append("Sequence schema accepted an unknown local-state reference.")
	var unsubscribed_fact := _fixture_definition()
	unsubscribed_fact["sequence"]["fact_subscriptions"].erase("heat_changed")
	if not _contains_text(SequenceSchemaScript.validate_definition(unsubscribed_fact, OperationRegistryScript), "unsubscribed fact"):
		failures.append("Sequence schema accepted a branch referencing an unsubscribed fact.")
	var unknown_receipt := _fixture_definition()
	unknown_receipt["sequence"]["phase_graph"]["phases"][0]["entry_conditions"] = [{"type": "receipt", "receipt_kind": "operation", "family": "scene_ops", "boundary_id": "scenario:node:phase:arrival", "receipt_id": "unknown_receipt"}]
	if not _contains_text(SequenceSchemaScript.validate_definition(unknown_receipt, OperationRegistryScript), "unknown authored operation receipt"):
		failures.append("Sequence schema accepted an unknown receipt reference.")
	var unknown_outcome := _fixture_definition()
	unknown_outcome["sequence"]["phase_graph"]["phases"][0]["entry_conditions"] = [{"type": "outcome", "outcome": "invented"}]
	if not _contains_text(SequenceSchemaScript.validate_definition(unknown_outcome, OperationRegistryScript), "unknown outcome"):
		failures.append("Sequence schema accepted an unknown outcome reference.")
	var oversized := _fixture_definition()
	for index in range(SequenceSchemaScript.MAX_OPERATIONS_PER_FAMILY + 1):
		oversized["sequence"]["phase_graph"]["phases"][0]["scene_ops"].append(_operation_fixture("scene_ops", "set_state", 1000 + index))
	if not _contains_text(SequenceSchemaScript.validate_definition(oversized, OperationRegistryScript), "exceeds 32 operations"):
		failures.append("Sequence schema accepted an oversized operation family.")
	var deeply_nested := _fixture_definition()
	var nested: Dictionary = {"leaf": true}
	for _index in range(SequenceSchemaScript.MAX_DATA_DEPTH + 2):
		nested = {"nested": nested}
	deeply_nested["sequence"]["owner_exceptions"] = [nested]
	if not _contains_text(SequenceSchemaScript.validate_definition(deeply_nested, OperationRegistryScript), "nesting depth"):
		failures.append("Sequence schema accepted data beyond its nesting-depth bound.")
	var bad_stage := _operation_fixture("transition_ops", "stage", 99)
	bad_stage["duration_boundaries"] = 9
	bad_stage.erase("reduced_motion_message")
	if OperationRegistryScript.validate_operation("transition_ops", bad_stage).is_empty():
		failures.append("Scenario transition stage accepted an unbounded inaccessible payload.")
	var cyclic: Dictionary = {}
	cyclic["cycle"] = cyclic
	if not _contains_text(OperationRegistryScript.validate_bounded_variant("hostile cycle", cyclic), "cycle"):
		failures.append("Scenario Variant validation did not reject a recursive container cycle.")
	var blocked_initial := _runtime_definition()
	blocked_initial["sequence"]["phase_graph"]["phases"][0]["entry_conditions"] = [{"type": "local_min", "key": "pressure", "value": 1}]
	blocked_initial["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(blocked_initial)
	var blocked_state := SequenceRuntimeScript.initial_state(blocked_initial, "bar_node", "blocked_seed", _fixture_host_semantics(blocked_initial))
	if str(blocked_state.get("status", "")) != SequenceRuntimeScript.STATUS_CLEANED or not _contains_text(_array(blocked_state.get("errors", [])), "entry conditions"):
		failures.append("Failed initial entry conditions silently produced an active partial sequence.")


static func _check_lifecycle_commands(failures: Array) -> void:
	var definition := _runtime_definition()
	var errors := SequenceSchemaScript.validate_definition(definition, OperationRegistryScript, _fixture_target_inventory(definition))
	if not errors.is_empty():
		failures.append("Runtime sequence fixture failed schema validation: %s" % JSON.stringify(errors))
		return
	var initial := SequenceRuntimeScript.initial_state(definition, "bar_node", "fixture_seed", _fixture_host_semantics(definition))
	if str(initial.get("phase_id", "")) != "arrival" or int(_dict(initial.get("performance_counters", {})).get("transitions_prepared", 0)) != 1:
		failures.append("Sequence initial phase was not prepared exactly once.")
	var initial_round_trip := SequenceRuntimeScript.normalize_state(initial, definition)
	if JSON.stringify(initial_round_trip) != JSON.stringify(initial):
		failures.append("Sequence normalization changed a valid initial snapshot.")

	var prepare := _runtime_command(initial, definition, "prepare", "bar_node", "arrival", "command:prepare:1", {"handler": "request_cleanup", "cost": 999}, "scenario", "command_console")
	var applied := SequenceRuntimeScript.apply_command(initial, definition, prepare, {"available_funds": 2})
	if not bool(applied.get("ok", false)) or int(_dict(_dict(applied.get("state", {})).get("local_state", {})).get("pressure", 0)) != 1:
		failures.append("Authoritative sequence command did not apply its authored handler/cost: %s" % JSON.stringify(applied.get("errors", [])))
		return
	var applied_state := _dict(applied.get("state", {}))
	if str(applied_state.get("status", "")) != SequenceRuntimeScript.STATUS_ACTIVE:
		failures.append("Caller-supplied command handler was trusted over the authored action handler.")
	var replay := SequenceRuntimeScript.apply_command(applied_state, definition, prepare, {"available_funds": 0})
	if not bool(replay.get("ok", false)) or not bool(replay.get("replayed", false)) or JSON.stringify(replay.get("state", {})) != JSON.stringify(applied_state) or int(_dict(applied_state.get("performance_counters", {})).get("commands_applied", 0)) != 1:
		failures.append("Sequence command replay was not exactly idempotent.")
	var key_collision := prepare.duplicate(true)
	key_collision["command_id"] = "finish"
	if not _contains_text(_array(SequenceRuntimeScript.apply_command(applied_state, definition, key_collision, {"available_funds": 9}).get("errors", [])), "reused"):
		failures.append("Sequence command accepted one idempotency key for a different command.")

	var hostile_commands := [
		["wrong node", SequenceRuntimeScript.command("prepare", "other_node", "arrival", "bad:node", {}, "scenario", "command_console")],
		["stale", SequenceRuntimeScript.command("prepare", "bar_node", "later", "bad:phase", {}, "scenario", "command_console")],
		["identity", SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "bad:owner", {}, "intruder", "command_console")],
		["absent interaction", SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "bad:absent", {}, "scenario", "absent_console")],
		["unavailable", SequenceRuntimeScript.command("invented", "bar_node", "arrival", "bad:action", {}, "scenario", "command_console")],
	]
	var missing_key := SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "", {}, "scenario", "command_console")
	hostile_commands.append(["idempotency_key", missing_key])
	var padded_command := SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "bad:padded", {}, "scenario", "command_console")
	padded_command["command_id"] = " prepare "
	hostile_commands.append(["exact string", padded_command])
	for fixture_value in hostile_commands:
		var fixture := fixture_value as Array
		var rejected := SequenceRuntimeScript.apply_command(initial, definition, fixture[1] as Dictionary, {"available_funds": 10})
		if bool(rejected.get("ok", true)) or not _contains_text(_array(rejected.get("errors", [])), str(fixture[0])):
			failures.append("Sequence command hostile case was not rejected for %s." % str(fixture[0]))
	var unaffordable := SequenceRuntimeScript.apply_command(initial, definition, prepare, {"available_funds": 1})
	if bool(unaffordable.get("ok", true)) or not _contains_text(_array(unaffordable.get("errors", [])), "not payable"):
		failures.append("Sequence command trusted caller cost or skipped authored affordability.")
	var finish_too_soon := _runtime_command(initial, definition, "finish", "bar_node", "arrival", "command:finish:early", {}, "scenario", "command_console")
	if bool(SequenceRuntimeScript.apply_command(initial, definition, finish_too_soon, {"available_funds": 10}).get("ok", true)):
		failures.append("Sequence command skipped an authored objective precondition.")
	var finish := _runtime_command(applied_state, definition, "finish", "bar_node", "arrival", "command:finish:1", {}, "scenario", "command_console")
	var finished := SequenceRuntimeScript.apply_command(applied_state, definition, finish, {"available_funds": 10})
	if not bool(finished.get("ok", false)) or str(_dict(finished.get("state", {})).get("phase_id", "")) != "aftermath":
		failures.append("Explicit command branch did not enter the authored next phase.")


static func _check_serialized_fact_ingress(failures: Array) -> void:
	var definition := _runtime_definition()
	var initial := SequenceRuntimeScript.initial_state(definition, "bar_node", "fixture_seed", _fixture_host_semantics(definition))
	var event_fact := SequenceRuntimeScript.fact("event_result", "event", "bar_node", "event:1", 7, 2, _fact_payload("event_result"))
	var event_queued := SequenceRuntimeScript.enqueue_fact(initial, definition, event_fact)
	if not bool(event_queued.get("ok", false)):
		failures.append("Valid event fact was rejected: %s" % JSON.stringify(event_queued.get("errors", [])))
		return
	var queued_state := _dict(event_queued.get("state", {}))
	for stable_key in ["phase_id", "status", "local_state", "objective_progress", "semantic_state", "resolved_branches", "resolved_outcomes"]:
		if JSON.stringify(queued_state.get(stable_key)) != JSON.stringify(initial.get(stable_key)):
			failures.append("Fact ingress mutated sequence state before a safe flush (%s)." % stable_key)
	var duplicate := SequenceRuntimeScript.enqueue_fact(queued_state, definition, event_fact)
	if not bool(duplicate.get("ok", false)) or not bool(duplicate.get("duplicate", false)) or JSON.stringify(duplicate.get("state", {})) != JSON.stringify(queued_state):
		failures.append("Queued fact replay was not idempotent.")
	var conflicting_fact := event_fact.duplicate(true)
	conflicting_fact["payload"]["resolved"] = true
	if not _contains_text(_array(SequenceRuntimeScript.enqueue_fact(queued_state, definition, conflicting_fact).get("errors", [])), "reused"):
		failures.append("Fact ingress accepted one fact_id for different payloads.")
	var padded_fact := event_fact.duplicate(true)
	padded_fact["fact_id"] = " event:1 "
	if bool(SequenceRuntimeScript.enqueue_fact(queued_state, definition, padded_fact).get("ok", true)):
		failures.append("Whitespace-padded fact identity bypassed exact duplicate/receipt validation.")
	var event_flushed := SequenceRuntimeScript.flush_facts(queued_state, definition, 2)
	if not bool(event_flushed.get("ok", false)) or str(_dict(event_flushed.get("state", {})).get("phase_id", "")) != "arrival":
		failures.append("An ordinary event resolution incorrectly resolved the scenario graph.")

	var facts := [
		["sweep_changed", "sweep", "sweep:1"],
		["world_boundary", "scenario", "scenario:1"],
		["town_transition", "town", "town:1"],
		["heat_changed", "heat", "heat:1"],
		["crew_changed", "crew", "crew:1"],
		["travel_arrived", "travel", "travel:1"],
		["service_result", "service", "service:1"],
		["event_result", "event", "event:2"],
		["game_result", "game", "game:1"],
	]
	var ordered_state := initial
	for fact_fixture_value in facts:
		var fact_fixture := fact_fixture_value as Array
		var typed_fact := SequenceRuntimeScript.fact(str(fact_fixture[0]), str(fact_fixture[1]), "bar_node", str(fact_fixture[2]), 1, 3, _fact_payload(str(fact_fixture[0])))
		var enqueued := SequenceRuntimeScript.enqueue_fact(ordered_state, definition, typed_fact)
		if not bool(enqueued.get("ok", false)):
			failures.append("Valid %s fact was rejected: %s" % [str(fact_fixture[0]), JSON.stringify(enqueued.get("errors", []))])
			return
		ordered_state = _dict(enqueued.get("state", {}))
	var deterministic_copy := ordered_state.duplicate(true)
	var ordered := SequenceRuntimeScript.flush_facts(ordered_state, definition, 3)
	var ordered_copy := SequenceRuntimeScript.flush_facts(deterministic_copy, definition, 3)
	var expected_order := ["game:1", "event:2", "service:1", "travel:1", "crew:1", "heat:1", "town:1", "sweep:1", "scenario:1"]
	if _array(ordered.get("processed", [])) != expected_order or JSON.stringify(ordered.get("state", {})) != JSON.stringify(ordered_copy.get("state", {})):
		failures.append("Fact flush order/state is not canonical and deterministic: %s" % JSON.stringify(ordered.get("processed", [])))

	var future := SequenceRuntimeScript.fact("game_result", "game", "bar_node", "game:future", 9, 9, _fact_payload("game_result"))
	var future_state := _dict(SequenceRuntimeScript.enqueue_fact(initial, definition, future).get("state", {}))
	var early_flush := SequenceRuntimeScript.flush_facts(future_state, definition, 8)
	if not _array(early_flush.get("processed", [])).is_empty() or _array(_dict(early_flush.get("state", {})).get("fact_queue", [])).size() != 1:
		failures.append("A future-boundary scenario fact flushed early.")

	var malformed := [
		SequenceRuntimeScript.fact("game_result", "event", "bar_node", "bad:producer", 1, 1, _fact_payload("game_result")),
		SequenceRuntimeScript.fact("invented", "event", "bar_node", "bad:type", 1, 1, {}),
		SequenceRuntimeScript.fact("event_result", "event", "wrong_node", "bad:node", 1, 1, _fact_payload("event_result")),
		SequenceRuntimeScript.fact("event_result", "event", "bar_node", "bad:payload", 1, 1, {}),
	]
	malformed[1]["schema_version"] = 99
	for invalid_value in malformed:
		if bool(SequenceRuntimeScript.enqueue_fact(initial, definition, invalid_value as Dictionary).get("ok", true)):
			failures.append("Malformed scenario fact was accepted: %s" % JSON.stringify(invalid_value))

	var prepared := SequenceRuntimeScript.apply_command(initial, definition, _runtime_command(initial, definition, "prepare", "bar_node", "arrival", "terminal:prepare", {}, "scenario", "command_console"), {"available_funds": 2})
	var prepared_state := _dict(prepared.get("state", {}))
	var terminal := SequenceRuntimeScript.apply_command(prepared_state, definition, _runtime_command(prepared_state, definition, "finish", "bar_node", "arrival", "terminal:finish", {}, "scenario", "command_console"), {"available_funds": 4})
	var terminal_fact := SequenceRuntimeScript.fact("world_boundary", "scenario", "bar_node", "terminal:boundary", 1, 4, _fact_payload("world_boundary"))
	var terminal_queued := SequenceRuntimeScript.enqueue_fact(_dict(terminal.get("state", {})), definition, terminal_fact)
	var aftermath := SequenceRuntimeScript.flush_facts(_dict(terminal_queued.get("state", {})), definition, 4)
	if str(_dict(aftermath.get("state", {})).get("status", "")) != SequenceRuntimeScript.STATUS_AFTERMATH:
		failures.append("Terminal branch did not produce persistent aftermath status.")
	elif bool(SequenceRuntimeScript.enqueue_fact(_dict(aftermath.get("state", {})), definition, SequenceRuntimeScript.fact("world_boundary", "scenario", "bar_node", "post:cleanup", 2, 5, _fact_payload("world_boundary"))).get("ok", true)):
		failures.append("Scenario fact ingress remained open after terminal cleanup/aftermath.")


static func _check_handler_reducer_contracts(failures: Array) -> void:
	var definition := _runtime_definition()
	var fixtures := {
		"set_local": {"key": "pressure", "value": 2},
		"increment_local": {"key": "pressure", "amount": 1},
		"complete_objective_step": {"objective_id": "clear_exit", "step_id": "move_chair"},
		"record_outcome": {"outcome": "repaired"},
		"publish_feedback": {"message": "Readable feedback."},
		"request_cleanup": {"reason": "handler"},
		"event_bridge": {"event_id": "fixture_event", "resolution_id": "leave"},
	}
	var contracts := OperationRegistryScript.registered_handlers()
	for handler_id_value in fixtures.keys():
		var handler_id := str(handler_id_value)
		var handler_definition := _safe_early_cleanup_definition() if handler_id == "request_cleanup" else definition
		var before := SequenceRuntimeScript.initial_state(handler_definition, "bar_node", "handler_seed", _fixture_host_semantics(handler_definition))
		var response := SequenceRuntimeScript._run_handler(before, handler_definition, handler_id, _dict(fixtures.get(handler_id, {})), {"kind": "command", "receipt_id": "golden:%s" % handler_id})
		if not bool(response.get("ok", false)):
			failures.append("Registered handler %s failed its golden reducer fixture." % handler_id)
			continue
		var after := _dict(response.get("state", {}))
		var changed_keys: Array = []
		for key_value in after.keys():
			var key := str(key_value)
			if JSON.stringify(after.get(key)) != JSON.stringify(before.get(key)):
				changed_keys.append(key)
		changed_keys.sort()
		var declared_outputs := _array(_dict(contracts.get(handler_id, {})).get("outputs", []))
		declared_outputs.sort()
		if changed_keys != declared_outputs:
			failures.append("Registered handler %s changed %s but declares outputs %s." % [handler_id, JSON.stringify(changed_keys), JSON.stringify(declared_outputs)])
	var local_schema: Dictionary = _dict(_dict(definition.get("sequence", {})).get("local_state_schema", {}))
	var hostile_handlers := [
		["increment_local", {"key": "pressure", "amount": 1.5}, "integer"],
		["set_local", {"key": "pressure", "value": 1, "value_from_payload": "current"}, "exactly one"],
		["request_cleanup", {"reason": " padded "}, "canonical"],
		["publish_feedback", {"message": "res://hostile"}, "path-safe"],
		["event_bridge", {"event_id": "fixture_event", "resolution_id": "ghost"}, "catalog-proven"],
	]
	for hostile_value in hostile_handlers:
		var hostile := hostile_value as Array
		var handler_errors := OperationRegistryScript.validate_handler_inputs(str(hostile[0]), _dict(hostile[1]), _dict(local_schema), SequenceSchemaScript.reachable_outcome_ids(definition), {"source": "command", "objective_steps": {"clear_exit": {"move_chair": true}}, "phase_objective_ids": ["clear_exit"], "event_choices": {"fixture_event": ["leave"]}})
		if handler_errors.is_empty() or not _contains_text(handler_errors, str(hostile[2])):
			failures.append("Hostile handler input passed exact validation: %s" % JSON.stringify(hostile))
	if bool(SequenceRuntimeScript._run_handler(SequenceRuntimeScript.initial_state(definition, "bar_node", "bad_trigger", _fixture_host_semantics(definition)), definition, "publish_feedback", {"message": "No."}, {}).get("ok", true)):
		failures.append("Handler reducer mapped a missing trigger kind to command.")
	var oversized_trigger := "a".repeat(513)
	if bool(SequenceRuntimeScript._run_handler(SequenceRuntimeScript.initial_state(definition, "bar_node", "large_trigger", _fixture_host_semantics(definition)), definition, "event_bridge", {"event_id": "fixture_event", "resolution_id": "leave"}, {"kind": "command", "receipt_id": oversized_trigger}).get("ok", true)):
		failures.append("Event bridge accepted an oversized trigger id.")
	var cleanup_definition := _safe_early_cleanup_definition()
	var cleanup_before := SequenceRuntimeScript.initial_state(cleanup_definition, "bar_node", "cleanup_replay_seed", _fixture_host_semantics(cleanup_definition))
	var cleanup_first := SequenceRuntimeScript._run_handler(cleanup_before, cleanup_definition, "request_cleanup", {"reason": "handler"}, {"kind": "command", "receipt_id": "cleanup:first"})
	var cleanup_second := SequenceRuntimeScript._run_handler(_dict(cleanup_first.get("state", {})), cleanup_definition, "request_cleanup", {"reason": "handler"}, {"kind": "command", "receipt_id": "cleanup:second"})
	if not bool(cleanup_first.get("ok", false)) or not bool(cleanup_second.get("ok", false)) or not bool(cleanup_second.get("replayed", false)) or JSON.stringify(cleanup_second.get("state", {})) != JSON.stringify(cleanup_first.get("state", {})):
		failures.append("Cleanup handler replay did not preserve the exact replayed result shape/state.")
	var forged_correlations := cleanup_before.duplicate(true)
	forged_correlations["event_correlations"] = [{"correlation_key": "forged", "event_id": "fixture_event", "resolution_id": "leave", "trigger_kind": "command", "trigger_id": "bridge:1"}]
	var normalized_forgery := SequenceRuntimeScript.normalize_state(forged_correlations, definition)
	if not _array(normalized_forgery.get("event_correlations", [])).is_empty():
		failures.append("Forged persisted event correlation survived closed normalization.")
	var bridged := SequenceRuntimeScript._run_handler(normalized_forgery, definition, "event_bridge", {"event_id": "fixture_event", "resolution_id": "leave"}, {"kind": "command", "receipt_id": "bridge:1"})
	var normalized_bridge := SequenceRuntimeScript.normalize_state(_dict(bridged.get("state", {})), definition)
	if not bool(bridged.get("ok", false)) or _array(normalized_bridge.get("event_correlations", [])).size() != 1:
		failures.append("Valid event correlation did not survive exact closed normalization.")


static func _check_sequence_persistence_seam(failures: Array) -> void:
	var definition := _runtime_definition()
	var sequence_state := SequenceRuntimeScript.initial_state(definition, "bar_node", "fixture_seed", _fixture_host_semantics(definition))
	var proof_digest := "a".repeat(64)
	var source := {"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node", "scenario_sequence_state": sequence_state, "scenario_sequence_projection": SequenceRuntimeScript.public_projection(sequence_state, definition), "scenario_semantic_inventory_version": 1, "scenario_semantic_digest": proof_digest}
	var restored := EnvironmentInstanceScript.from_dict(source).to_dict()
	var restored_semantic := _dict(_dict(restored.get("scenario_sequence_state", {})).get("semantic_state", {}))
	if not restored.has("scenario_sequence_state") or restored.has("scenario_sequence_projection") or restored_semantic.has("target_inventory") or restored_semantic.has("declared_targets") or restored_semantic.has("base_interactions") or restored_semantic.has("event_choices") or restored_semantic.has("scene_objects") or restored_semantic.has("interactions") or restored_semantic.has("actors") or restored_semantic.has("transition_queue") or _dict(restored.get("scenario_sequence_state", {})).has("resolved_branches") or _dict(restored.get("scenario_sequence_state", {})).has("resolved_outcomes") or str(restored_semantic.get("inventory_digest", "")) != str(_dict(sequence_state.get("semantic_state", {})).get("inventory_digest", "")) or int(restored.get("scenario_semantic_inventory_version", 0)) != 1 or str(restored.get("scenario_semantic_digest", "")) != proof_digest:
		failures.append("Environment snapshot did not retain only durable sequence state while stripping derived authorization/projection.")
	var queued_state := sequence_state.duplicate(true)
	queued_state["semantic_state"]["transition_queue"] = [{"channel": "room", "message": "Do not replay this dialogue."}]
	queued_state["fact_queue"] = [SequenceRuntimeScript.fact("event_result", "event", "bar_node", "save:queued:event", 1, 9, _fact_payload("event_result"))]
	queued_state["fact_queue"][0]["ingress_serial"] = 1
	var layered_source := {"id": "layered", "archetype_id": "bar", "world_node_id": "bar_node", "environment_layer_schema_version": 1, "current_layer_id": "main", "default_layer_id": "main", "layer_ids": ["main", "back_room"], "layer_states": {"back_room": {"id": "nested", "archetype_id": "bar", "world_node_id": "bar_node", "scenario_sequence_state": queued_state, "scenario_sequence_projection": {"forged": true}}}}
	var layered_round_trip := EnvironmentInstanceScript.from_dict(layered_source).to_dict()
	var nested_state := _dict(_dict(_dict(layered_round_trip.get("layer_states", {})).get("back_room", {})).get("scenario_sequence_state", {}))
	if nested_state.is_empty() or _array(nested_state.get("fact_queue", [])).size() != 1 or _dict(nested_state.get("semantic_state", {})).has("transition_queue") or _dict(_dict(layered_round_trip.get("layer_states", {})).get("back_room", {})).has("scenario_sequence_projection"):
		failures.append("Recursive layer save did not preserve durable queued facts while stripping queued dialogue/transition projection.")
	var plain := EnvironmentInstanceScript.from_dict({"id": "plain", "archetype_id": "bar", "world_node_id": "bar_node"}).to_dict()
	if plain.has("scenario_sequence_state") or plain.has("scenario_sequence_projection"):
		failures.append("No-sequence environment gained dynamic sequence persistence fields.")
	var pending_only := RunStateScript._normalize_environment({"id": "pending_only", "archetype_id": "bar", "scenario_sequence_pending_visit_id": "orphan"})
	var malformed_pending := RunStateScript._normalize_environment({"id": "malformed_pending", "archetype_id": "bar", "scenario_sequence_state": "hostile", "scenario_sequence_pending_visit_id": "orphan"})
	if pending_only.has("scenario_sequence_pending_visit_id") or malformed_pending.has("scenario_sequence_pending_visit_id"):
		failures.append("Pending sequence visit identity survived without a valid durable sequence state.")
	var semantic_source := {
		"id": "semantic",
		"archetype_id": "bar",
		"semantic_anchors": {"door": {"position": [100, 120], "zone_id": "floor"}},
		"semantic_zones": {"floor": {"bounds": [0, 0, 900, 430]}},
		"semantic_actors": [{"id": "clerk", "actor_id": "fixture_clerk", "anchor_id": "door"}],
	}
	var semantic_round_trip := EnvironmentInstanceScript.from_dict(semantic_source).to_dict()
	if SequenceRuntimeScript.content_fingerprint(semantic_round_trip.get("semantic_anchors", {})) != SequenceRuntimeScript.content_fingerprint(semantic_source.get("semantic_anchors", {})) or SequenceRuntimeScript.content_fingerprint(semantic_round_trip.get("semantic_zones", {})) != SequenceRuntimeScript.content_fingerprint(semantic_source.get("semantic_zones", {})) or SequenceRuntimeScript.content_fingerprint(semantic_round_trip.get("semantic_actors", [])) != SequenceRuntimeScript.content_fingerprint(semantic_source.get("semantic_actors", [])):
		failures.append("EnvironmentInstance dropped explicit semantic anchors/zones/actors on save/revisit.")
	if plain.has("semantic_anchors") or plain.has("semantic_zones") or plain.has("semantic_actors"):
		failures.append("Legacy no-sequence EnvironmentInstance snapshot gained empty semantic seam fields.")


static func _check_receipt_reconstruction(failures: Array) -> void:
	var definition := _runtime_definition()
	var host_semantics := _fixture_host_semantics(definition)
	var state := SequenceRuntimeScript.initial_state(definition, "bar_node", "rebuild_seed", host_semantics)
	for command_spec_value in [
		["prepare", "arrival", "rebuild:prepare", "command_console"],
		["finish", "arrival", "rebuild:finish", "command_console"],
		["use", "aftermath", "rebuild:outcome", "fixture_201"],
	]:
		var command_spec := command_spec_value as Array
		var command_value := _runtime_command(state, definition, str(command_spec[0]), "bar_node", str(command_spec[1]), str(command_spec[2]), {}, "scenario", str(command_spec[3]))
		var applied := SequenceRuntimeScript.apply_command(state, definition, command_value, {"available_funds": 10})
		if not bool(applied.get("ok", false)):
			failures.append("Receipt reconstruction fixture could not reach terminal state: %s" % JSON.stringify(applied.get("errors", [])))
			return
		state = _dict(applied.get("state", {}))
	var rebuilt := ScenarioEngineScript._rebuild_receipted_semantic_mutations(state, definition, host_semantics)
	if not bool(rebuilt.get("ok", false)) or _array(_dict(rebuilt.get("state", {})).get("resolved_branches", [])) != ["arrival:continue", "aftermath:finish"] or _array(_dict(rebuilt.get("state", {})).get("resolved_outcomes", [])) != ["repaired"]:
		failures.append("Valid receipt journals did not reconstruct exact branch/outcome semantics: %s" % JSON.stringify(rebuilt.get("errors", [])))
	var legacy_receipts := state.duplicate(true)
	for legacy_record_index in range(_array(legacy_receipts.get("command_receipt_records", [])).size()):
		var legacy_record := legacy_receipts["command_receipt_records"][legacy_record_index] as Dictionary
		legacy_record.erase("causal_action_descriptor")
		legacy_record.erase("causal_action_descriptor_fingerprint")
	var migrated_receipts := SequenceRuntimeScript.normalize_state(legacy_receipts, definition)
	var migrated_record_shape_valid := true
	for record_value in _array(migrated_receipts.get("command_receipt_records", [])):
		var migrated_record := _dict(record_value)
		if migrated_record.size() != 6 or _dict(migrated_record.get("causal_action_descriptor", {})).is_empty() or str(migrated_record.get("causal_action_descriptor_fingerprint", "")) != SequenceRuntimeScript.content_fingerprint(migrated_record.get("causal_action_descriptor", {})):
			migrated_record_shape_valid = false
	var migrated_rebuild := ScenarioEngineScript._rebuild_receipted_semantic_mutations(migrated_receipts, definition, host_semantics)
	if not migrated_record_shape_valid or not bool(migrated_rebuild.get("ok", false)) or SequenceRuntimeScript.content_fingerprint(_dict(migrated_rebuild.get("state", {})).get("command_receipt_records", [])) != SequenceRuntimeScript.content_fingerprint(state.get("command_receipt_records", [])):
		failures.append("A valid pre-descriptor v2 command journal did not deterministically migrate to receipt-bound causal action descriptors.")
	var malformed_migration := legacy_receipts.duplicate(true)
	malformed_migration["command_receipt_records"][0]["envelope"]["action_origin_receipt_key"] = "forged_receipt_key"
	var malformed_receipt_key := str(malformed_migration["command_receipt_records"][0].get("receipt_key", ""))
	var malformed_envelope_fingerprint := SequenceRuntimeScript.content_fingerprint(malformed_migration["command_receipt_records"][0]["envelope"])
	malformed_migration["command_receipt_records"][0]["fingerprint"] = malformed_envelope_fingerprint
	malformed_migration["command_fingerprints"][malformed_receipt_key] = malformed_envelope_fingerprint
	var malformed_normalized := SequenceRuntimeScript.normalize_state(malformed_migration, definition)
	if bool(ScenarioEngineScript._rebuild_receipted_semantic_mutations(malformed_normalized, definition, host_semantics).get("ok", true)):
		failures.append("A malformed pre-descriptor command journal migrated or replayed without an exact authored receipt binding.")
	var forged_derived := state.duplicate(true)
	forged_derived["resolved_branches"] = ["arrival:ghost"]
	forged_derived["resolved_outcomes"] = ["broken"]
	var derived_rebuild := ScenarioEngineScript._rebuild_receipted_semantic_mutations(forged_derived, definition, host_semantics)
	if not bool(derived_rebuild.get("ok", false)) or _array(_dict(derived_rebuild.get("state", {})).get("resolved_branches", [])).has("arrival:ghost") or _array(_dict(derived_rebuild.get("state", {})).get("resolved_outcomes", [])).has("broken"):
		failures.append("Saved derived branch/outcome lists influenced journal reconstruction.")
	var forged_journal := state.duplicate(true)
	forged_journal["branch_resolution_records"][0]["branch_fingerprint"] = "0".repeat(64)
	if bool(ScenarioEngineScript._rebuild_receipted_semantic_mutations(forged_journal, definition, host_semantics).get("ok", true)):
		failures.append("Receipt reconstruction accepted a forged authored-branch fingerprint.")
	var forged_cause := state.duplicate(true)
	var cause_record := _dict(forged_cause["command_receipt_records"][1])
	var cause_envelope := _dict(cause_record.get("envelope", {}))
	cause_envelope["command_id"] = "prepare"
	var cause_fingerprint := SequenceRuntimeScript.content_fingerprint(cause_envelope)
	cause_record["envelope"] = cause_envelope
	cause_record["fingerprint"] = cause_fingerprint
	forged_cause["command_receipt_records"][1] = cause_record
	forged_cause["command_fingerprints"]["rebuild:finish"] = cause_fingerprint
	forged_cause["branch_resolution_records"][0]["cause_fingerprint"] = cause_fingerprint
	if bool(ScenarioEngineScript._rebuild_receipted_semantic_mutations(forged_cause, definition, host_semantics).get("ok", true)):
		failures.append("Receipt reconstruction accepted a self-consistent forged command cause that no longer matched its branch condition.")
	var forged_order := state.duplicate(true)
	forged_order["branch_resolution_records"].reverse()
	for index in range(_array(forged_order.get("branch_resolution_records", [])).size()): forged_order["branch_resolution_records"][index]["boundary_ordinal"] = index
	if bool(ScenarioEngineScript._rebuild_receipted_semantic_mutations(forged_order, definition, host_semantics).get("ok", true)):
		failures.append("Receipt reconstruction accepted a reordered legal-looking branch journal.")
	var fact_definition := _runtime_definition()
	fact_definition["sequence"]["phase_graph"]["phases"][0]["branches"] = [{"id": "continue", "condition": {"type": "fact", "fact_type": "heat_changed"}, "next_phase": "aftermath"}]
	fact_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(fact_definition)
	var fact_host := _fixture_host_semantics(fact_definition)
	var fact_state := SequenceRuntimeScript.initial_state(fact_definition, "bar_node", "fact_rebuild_seed", fact_host)
	for fact_value in [
		SequenceRuntimeScript.fact("heat_changed", "heat", "bar_node", "rebuild:fact:phase", 1, 1, _fact_payload("heat_changed")),
		SequenceRuntimeScript.fact("event_result", "event", "bar_node", "rebuild:fact:outcome", 1, 2, _fact_payload("event_result")),
	]:
		var queued := SequenceRuntimeScript.enqueue_fact(fact_state, fact_definition, fact_value as Dictionary)
		var flushed := SequenceRuntimeScript.flush_facts(_dict(queued.get("state", {})), fact_definition, int((fact_value as Dictionary).get("boundary_serial", 0)))
		if not bool(queued.get("ok", false)) or not bool(flushed.get("ok", false)):
			failures.append("Fact-cause reconstruction fixture could not reach terminal state.")
			return
		fact_state = _dict(flushed.get("state", {}))
	if not bool(ScenarioEngineScript._rebuild_receipted_semantic_mutations(fact_state, fact_definition, fact_host).get("ok", false)):
		failures.append("Valid fact receipt envelopes did not prove their branch causes.")
	var forged_fact := fact_state.duplicate(true)
	var fact_record := _dict(forged_fact["fact_receipt_records"][0])
	var fact_envelope := _dict(fact_record.get("envelope", {}))
	fact_envelope["producer"] = "event"
	var fact_fingerprint := SequenceRuntimeScript.content_fingerprint(fact_envelope)
	fact_record["envelope"] = fact_envelope
	fact_record["fingerprint"] = fact_fingerprint
	forged_fact["fact_receipt_records"][0] = fact_record
	forged_fact["fact_fingerprints"]["rebuild:fact:phase"] = fact_fingerprint
	forged_fact["branch_resolution_records"][0]["cause_fingerprint"] = fact_fingerprint
	if bool(ScenarioEngineScript._rebuild_receipted_semantic_mutations(forged_fact, fact_definition, fact_host).get("ok", true)):
		failures.append("Receipt reconstruction accepted a producer-invalid forged fact cause.")
	var local_definition := _runtime_definition()
	local_definition["sequence"]["phase_graph"]["phases"][0]["branches"] = [{"id": "continue", "condition": {"type": "local_min", "key": "pressure", "value": 2}, "next_phase": "aftermath"}]
	local_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(local_definition)
	var local_host := _fixture_host_semantics(local_definition)
	var local_state := SequenceRuntimeScript.initial_state(local_definition, "bar_node", "causal_local_seed", local_host)
	for receipt_id in ["causal:local:first", "causal:local:second"]:
		var local_command := SequenceRuntimeScript.apply_command(local_state, local_definition, _runtime_command(local_state, local_definition, "prepare", "bar_node", "arrival", receipt_id, {}, "scenario", "command_console"), {"available_funds": 10})
		if not bool(local_command.get("ok", false)):
			failures.append("Causal local replay fixture could not reach its branch.")
			return
		local_state = _dict(local_command.get("state", {}))
	var forged_later_local := local_state.duplicate(true)
	var first_local_cause := _dict(_array(forged_later_local.get("command_receipt_records", []))[0])
	forged_later_local["branch_resolution_records"][0]["trigger_receipt_key"] = str(first_local_cause.get("receipt_key", ""))
	forged_later_local["branch_resolution_records"][0]["cause_fingerprint"] = str(first_local_cause.get("fingerprint", ""))
	if bool(ScenarioEngineScript._rebuild_receipted_semantic_mutations(forged_later_local, local_definition, local_host).get("ok", true)):
		failures.append("Causal reconstruction borrowed a later local mutation to authorize an earlier branch cause.")
	var forged_global_order := local_state.duplicate(true)
	forged_global_order["command_receipt_records"][0]["cause_ordinal"] = 1
	forged_global_order["command_receipt_records"][1]["cause_ordinal"] = 0
	if bool(ScenarioEngineScript._rebuild_receipted_semantic_mutations(forged_global_order, local_definition, local_host).get("ok", true)):
		failures.append("Causal reconstruction accepted command records reordered across the shared ordinal journal.")
	var cleanup_definition := _safe_early_cleanup_definition()
	var cleanup_interaction := _dict(cleanup_definition["sequence"]["phase_graph"]["phases"][0]["interaction_ops"][0])
	var cleanup_payload := _dict(cleanup_interaction.get("interaction", {}))
	cleanup_payload["available_actions"].append({"id": "clean", "label": "Clean the room", "input_action": "confirm", "non_color_state": "ready", "handler": "request_cleanup", "inputs": {"reason": "requested"}})
	cleanup_interaction["interaction"] = cleanup_payload
	cleanup_definition["sequence"]["phase_graph"]["phases"][0]["interaction_ops"][0] = cleanup_interaction
	cleanup_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(cleanup_definition)
	var cleanup_host := _fixture_host_semantics(cleanup_definition)
	var cleanup_initial := SequenceRuntimeScript.initial_state(cleanup_definition, "bar_node", "causal_cleanup_seed", cleanup_host)
	var honest_cleanup := SequenceRuntimeScript.apply_command(cleanup_initial, cleanup_definition, _runtime_command(cleanup_initial, cleanup_definition, "clean", "bar_node", "arrival", "causal:cleanup", {}, "scenario", "command_console"), {"available_funds": 10})
	if not bool(honest_cleanup.get("ok", false)) or not bool(ScenarioEngineScript._rebuild_receipted_semantic_mutations(_dict(honest_cleanup.get("state", {})), cleanup_definition, cleanup_host).get("ok", false)):
		failures.append("An exact request_cleanup command cause did not reconstruct its cleanup journal.")
	var uncaused_cleanup := SequenceRuntimeScript._run_handler(cleanup_initial, cleanup_definition, "request_cleanup", {"reason": "requested"}, {"kind": "command", "receipt_id": "forged:cleanup"})
	if not bool(uncaused_cleanup.get("ok", false)) or bool(ScenarioEngineScript._rebuild_receipted_semantic_mutations(_dict(uncaused_cleanup.get("state", {})), cleanup_definition, cleanup_host).get("ok", true)):
		failures.append("Receipt reconstruction accepted cleanup operations without a matching command, fact, terminal branch, or expiry cause.")
	var marker_definition := _runtime_definition()
	var marker_interaction := _dict(marker_definition["sequence"]["phase_graph"]["phases"][0]["interaction_ops"][0])
	var marker_payload := _dict(marker_interaction.get("interaction", {}))
	marker_payload["available_actions"].append({"id": "mark", "label": "Mark outcome", "input_action": "confirm", "non_color_state": "ready", "handler": "record_outcome", "inputs": {"outcome": "repaired"}})
	marker_interaction["interaction"] = marker_payload
	marker_definition["sequence"]["phase_graph"]["phases"][0]["interaction_ops"][0] = marker_interaction
	marker_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(marker_definition)
	var marker_host := _fixture_host_semantics(marker_definition)
	var marker_initial := SequenceRuntimeScript.initial_state(marker_definition, "bar_node", "outcome_marker_seed", marker_host)
	var marked := SequenceRuntimeScript.apply_command(marker_initial, marker_definition, _runtime_command(marker_initial, marker_definition, "mark", "bar_node", "arrival", "causal:marker", {}, "scenario", "command_console"), {"available_funds": 10})
	var marked_state := _dict(marked.get("state", {}))
	var marked_rebuild := ScenarioEngineScript._rebuild_receipted_semantic_mutations(marked_state, marker_definition, marker_host)
	if not bool(marked.get("ok", false)) or not bool(marked_rebuild.get("ok", false)) or _array(_dict(marked_rebuild.get("state", {})).get("resolved_outcomes", [])) != ["repaired"] or _contains_text(_array(_dict(marked_state.get("semantic_state", {})).get("operation_receipt_records", [])), ":aftermath:repaired"):
		failures.append("An honest record_outcome marker incorrectly required or executed aftermath operations.")
	var forged_aftermath := marked_state.duplicate(true)
	var forged_semantic := _dict(forged_aftermath.get("semantic_state", {}))
	var repaired_aftermath := _dict(marker_definition["sequence"]["aftermath"]["repaired"])
	var aftermath_boundary := "%s:%s:aftermath:repaired" % [str(forged_aftermath.get("scenario_id", "")), str(forged_aftermath.get("node_id", ""))]
	for family in ["scene_ops", "interaction_ops", "actor_ops", "service_ops", "game_ops", "route_ops"]:
		var forged_apply := OperationRegistryScript.apply_operations(forged_semantic, family, _array(repaired_aftermath.get(family, [])), aftermath_boundary)
		if not bool(forged_apply.get("ok", false)):
			failures.append("Forged aftermath fixture could not construct a legal-looking operation journal.")
			return
		forged_semantic = _dict(forged_apply.get("state", forged_semantic))
	forged_aftermath["semantic_state"] = forged_semantic
	if bool(ScenarioEngineScript._rebuild_receipted_semantic_mutations(forged_aftermath, marker_definition, marker_host).get("ok", true)):
		failures.append("A record_outcome marker authorized forged aftermath operation receipts.")
	# The generic runtime fixture owns a later-phase interaction. Expiry from the
	# initial phase must use the early-cleanup fixture so every cleanup target is
	# live on this exact causal path.
	var expiry_definition := _safe_early_cleanup_definition()
	expiry_definition["sequence"]["expiry"] = {"boundary": "night_end", "after": 1, "policy": "cleanup"}
	expiry_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(expiry_definition)
	var expiry_host := _fixture_host_semantics(expiry_definition)
	var expiry_initial := SequenceRuntimeScript.initial_state(expiry_definition, "bar_node", "expiry_journal_seed", expiry_host)
	var expired := SequenceRuntimeScript.apply_expiry_boundary(expiry_initial, expiry_definition, "night_end")
	if not bool(expired.get("ok", false)) or not bool(ScenarioEngineScript._rebuild_receipted_semantic_mutations(_dict(expired.get("state", {})), expiry_definition, expiry_host).get("ok", false)):
		failures.append("An exact authored expiry journal did not prove its cleanup cause.")
	var forged_expiry := _dict(expired.get("state", {})).duplicate(true)
	forged_expiry["expiry_boundary_records"] = []
	if bool(ScenarioEngineScript._rebuild_receipted_semantic_mutations(forged_expiry, expiry_definition, expiry_host).get("ok", true)):
		failures.append("Expiry cleanup reconstruction succeeded without its exact boundary journal.")
	var long_envelope := SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "causal:long", {"a": "x".repeat(400), "b": "y".repeat(400)}, "scenario", "command_console")
	if not SequenceRuntimeScript._valid_sha256(SequenceRuntimeScript.content_fingerprint(long_envelope)) or not SequenceRuntimeScript._valid_sha256(OperationRegistryScript.operation_fingerprint(_operation_fixture("interaction_ops", "add", 998))):
		failures.append("Persisted causal/operation fingerprints are not fixed 64-character lowercase SHA-256 values.")


static func _check_depth_remediation_contracts(failures: Array) -> void:
	var definition := _runtime_definition()
	var host_semantics := _fixture_host_semantics(definition)
	var initial := SequenceRuntimeScript.initial_state(definition, "bar_node", "depth_remediation_seed", host_semantics)
	var public_semantic := _dict(SequenceRuntimeScript.public_projection(initial, definition).get("semantic_state", {}))
	var public_semantic_keys := public_semantic.keys()
	var expected_public_semantic_keys := OperationRegistryScript.PUBLIC_SEMANTIC_KEYS.duplicate()
	public_semantic_keys.sort()
	expected_public_semantic_keys.sort()
	if public_semantic_keys != expected_public_semantic_keys:
		failures.append("Public scenario semantic projection exposed runtime authorization or journal internals: %s" % JSON.stringify(public_semantic_keys))
	var resolved_semantic := OperationRegistryScript.resolved_semantic_state(_dict(initial.get("semantic_state", {})))
	if SequenceRuntimeScript.content_fingerprint(public_semantic.get("interactions", {})) != SequenceRuntimeScript.content_fingerprint(resolved_semantic.get("interactions", {})) or SequenceRuntimeScript.content_fingerprint(public_semantic.get("scene_objects", {})) != SequenceRuntimeScript.content_fingerprint(resolved_semantic.get("scene_objects", {})):
		failures.append("Closed public scenario semantics did not retain the room UI interaction/scene projection.")
	var prepare := _runtime_command(initial, definition, "prepare", "bar_node", "arrival", "depth:prepare", {}, "scenario", "command_console")
	var descriptor := SequenceRuntimeScript._command_descriptor(initial, definition, "scenario", "command_console", "prepare")
	var action := _dict(descriptor.get("action", {}))
	var semantic_records := _array(_dict(initial.get("semantic_state", {})).get("operation_receipt_records", []))
	var action_record: Dictionary = {}
	for record_value in semantic_records:
		var operation_record := _dict(record_value)
		if str(operation_record.get("family", "")) == "interaction_ops" and str(operation_record.get("authored_receipt_id", "")) == "interaction_add_200":
			action_record = operation_record
	if action_record.is_empty() or str(action.get("action_origin_receipt_key", "")) != str(action_record.get("receipt_key", "")) or str(action.get("action_origin_boundary_id", "")) != str(action_record.get("boundary_id", "")) or str(action.get("action_origin_fingerprint", "")) != str(action_record.get("fingerprint", "")):
		failures.append("Interaction add actions did not inherit exact operation receipt provenance.")
	var unavailable_state := initial.duplicate(true)
	var unavailable_interaction := _dict(_dict(unavailable_state["semantic_state"].get("interactions", {})).get("scenario::command_console", {}))
	unavailable_interaction["enabled"] = false
	unavailable_interaction["available_actions"] = []
	unavailable_state["semantic_state"]["interactions"]["scenario::command_console"] = unavailable_interaction
	var causal_descriptor := SequenceRuntimeScript.causal_action_descriptor(initial, definition, prepare)
	var unavailable_live_result := SequenceRuntimeScript.apply_command(unavailable_state, definition, prepare, {"available_funds": 10})
	var historical_causal_result := SequenceRuntimeScript.apply_command(unavailable_state, definition, prepare, {"available_funds": 10, "causal_action_descriptor": causal_descriptor})
	if bool(unavailable_live_result.get("ok", true)) or not bool(historical_causal_result.get("ok", false)):
		failures.append("Historical command replay depended on current ephemeral interaction availability instead of its receipt-bound authored causal descriptor.")
	var applied := SequenceRuntimeScript.apply_command(initial, definition, prepare, {"available_funds": 10})
	var applied_state := _dict(applied.get("state", {}))
	var cached := _dict(_dict(applied_state.get("command_results", {})).get("depth:prepare", {}))
	var exact_command_result_keys := ["changed", "command_id", "ok", "outcomes", "phase_id", "receipt_id", "replayed", "state", "status"]
	var applied_keys := applied.keys()
	var cached_keys := cached.keys()
	applied_keys.sort()
	cached_keys.sort()
	if not bool(applied.get("ok", false)) or applied.has("handler_replayed") or applied_keys != exact_command_result_keys or cached_keys != exact_command_result_keys or bool(cached.get("replayed", true)) or not _dict(cached.get("state", {})).is_empty() or JSON.stringify(applied.get("state", {})) != JSON.stringify(applied_state):
		failures.append("Accepted command results did not persist the exact closed replay-cache schema.")
	var forged_cache := applied_state.duplicate(true)
	forged_cache["command_results"]["depth:prepare"]["handler_replayed"] = false
	var normalized_forgery := SequenceRuntimeScript.normalize_state(forged_cache, definition)
	if _dict(normalized_forgery.get("command_results", {})).has("depth:prepare") or bool(SequenceRuntimeScript.apply_command(normalized_forgery, definition, prepare, {"available_funds": 10}).get("ok", true)):
		failures.append("A command result with an undeclared cache field survived normalization/replay.")
	var mistyped_cache := applied_state.duplicate(true)
	mistyped_cache["command_results"]["depth:prepare"]["changed"] = 1
	if _dict(SequenceRuntimeScript.normalize_state(mistyped_cache, definition).get("command_results", {})).has("depth:prepare") or bool(ScenarioEngineScript._rebuild_receipted_semantic_mutations(mistyped_cache, definition, host_semantics).get("ok", true)):
		failures.append("A command replay cache with a coerced field type survived normalization or Engine reconstruction.")

	var replace_operation := _operation_fixture("interaction_ops", "replace", 331)
	replace_operation["stable_object_id"] = "replacement_console"
	replace_operation["target_owner_namespace"] = "scenario"
	replace_operation["target_stable_object_id"] = "command_console"
	replace_operation["interaction"] = _interaction_record("scenario", "replacement_console", "Replacement console", true)
	var replace_result := OperationRegistryScript.apply_operations(_dict(initial.get("semantic_state", {})), "interaction_ops", [replace_operation], "sequence_fixture:bar_node:phase:replacement")
	var replacement := _dict(_dict(OperationRegistryScript.resolved_semantic_state(_dict(replace_result.get("state", {}))).get("interactions", {})).get("scenario::replacement_console", {}))
	var replacement_action := _dict(_array(replacement.get("available_actions", []))[0] if not _array(replacement.get("available_actions", [])).is_empty() else {})
	if not bool(replace_result.get("ok", false)) or str(replacement_action.get("action_origin_receipt_key", "")).is_empty() or str(replacement_action.get("action_origin_boundary_id", "")) != "sequence_fixture:bar_node:phase:replacement" or not SequenceRuntimeScript._valid_sha256(str(replacement_action.get("action_origin_fingerprint", ""))):
		failures.append("Interaction replace actions did not inherit exact operation provenance.")

	var boundary_state := {"declared_targets": {"scene_objects": ["scenario::fixture_101"]}, "target_inventory": {"scene_objects": ["scenario::fixture_101"]}}
	var boundary_operation := _operation_fixture("scene_ops", "set_state", 101)
	var long_boundary_result := OperationRegistryScript.apply_operations(boundary_state, "scene_ops", [boundary_operation], "a:b:phase:%s" % "x".repeat(OperationRegistryScript.MAX_VARIANT_TEXT))
	if bool(long_boundary_result.get("ok", true)):
		failures.append("Operation registry accepted an overlong persisted boundary id.")
	var long_identity_operation := _operation_fixture("scene_ops", "spawn", 332)
	long_identity_operation["stable_object_id"] = "x".repeat(OperationRegistryScript.MAX_VARIANT_TEXT)
	long_identity_operation["object"]["anchor_id"] = "bar_floor_0"
	var long_identity_result := OperationRegistryScript.apply_operations(_operation_semantic_seed(), "scene_ops", [long_identity_operation], "a:b:phase:long_identity")
	if bool(long_identity_result.get("ok", true)) or not _contains_text(_array(long_identity_result.get("errors", [])), "dictionary key exceeding 512 characters"):
		failures.append("Operation registry persisted a derived owned-identity key beyond the text bound.")
	var long_visit := SequenceRuntimeScript.record_visit(initial, definition, "v".repeat(OperationRegistryScript.MAX_VARIANT_TEXT + 1))
	if bool(long_visit.get("ok", true)):
		failures.append("Scenario runtime accepted an overlong visit id.")
	var long_scope_definition := _runtime_definition()
	long_scope_definition["id"] = "s".repeat(250)
	long_scope_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(long_scope_definition)
	var long_scope_state := SequenceRuntimeScript.initial_state(long_scope_definition, "n".repeat(250), "bounded_seed", _fixture_host_semantics(long_scope_definition))
	if str(long_scope_state.get("status", "")) != SequenceRuntimeScript.STATUS_CLEANED or not _contains_text(_array(long_scope_state.get("errors", [])), "persisted text boundary"):
		failures.append("Scenario runtime persisted an overlong composite phase boundary.")
	var event_state := initial.duplicate(true)
	var event_id := "e".repeat(250)
	var resolution_id := "r".repeat(250)
	var long_event_choices: Dictionary = {}
	long_event_choices[event_id] = [resolution_id]
	event_state["semantic_state"]["event_choices"] = long_event_choices
	var long_feedback := SequenceRuntimeScript._run_handler(event_state, definition, "event_bridge", {"event_id": event_id, "resolution_id": resolution_id}, {"kind": "command", "receipt_id": "depth:event"})
	if bool(long_feedback.get("ok", true)) or JSON.stringify(long_feedback.get("state", {})) != JSON.stringify(event_state):
		failures.append("Event bridge accepted overlong derived feedback/correlation text or mutated on rejection.")

	var visit_definition := _runtime_definition()
	visit_definition["sequence"]["phase_graph"]["phases"][0]["branches"] = [{"id": "visit_continue", "condition": {"type": "receipt", "receipt_kind": "visit", "receipt_id": "visit_branch"}, "next_phase": "aftermath"}]
	visit_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(visit_definition)
	var visit_host := _fixture_host_semantics(visit_definition)
	var visit_initial := SequenceRuntimeScript.initial_state(visit_definition, "bar_node", "visit_replay_seed", visit_host)
	var visited := SequenceRuntimeScript.record_visit(visit_initial, visit_definition, "visit_branch")
	var visited_state := _dict(visited.get("state", {}))
	var visit_records := _array(visited_state.get("visit_receipt_records", []))
	var visit_record := _dict(visit_records[0] if not visit_records.is_empty() else {})
	var visited_command := _runtime_command(visited_state, visit_definition, "prepare", "bar_node", "arrival", "visit:prepare", {}, "scenario", "command_console")
	var visit_branched := SequenceRuntimeScript.apply_command(visited_state, visit_definition, visited_command, {"available_funds": 10})
	var visit_branched_state := _dict(visit_branched.get("state", {}))
	var visit_rebuilt := ScenarioEngineScript._rebuild_receipted_semantic_mutations(visit_branched_state, visit_definition, visit_host)
	if not bool(visited.get("ok", false)) or visit_record.size() != 3 or typeof(visit_record.get("cause_ordinal")) != TYPE_INT or str(visit_branched_state.get("phase_id", "")) != "aftermath" or not bool(visit_rebuilt.get("ok", false)) or str(_dict(visit_rebuilt.get("state", {})).get("phase_id", "")) != "aftermath":
		failures.append("An honest visit-dependent branch did not survive exact causal reconstruction.")
	var fabricated_visit := visit_branched_state.duplicate(true)
	fabricated_visit["visit_receipt_records"][0]["visit_id"] = "fabricated_visit"
	if bool(ScenarioEngineScript._rebuild_receipted_semantic_mutations(fabricated_visit, visit_definition, visit_host).get("ok", true)):
		failures.append("Receipt reconstruction accepted a fabricated visit record.")
	var forged_visit_shape := visit_branched_state.duplicate(true)
	forged_visit_shape["visit_receipt_records"][0]["extra"] = true
	if bool(ScenarioEngineScript._rebuild_receipted_semantic_mutations(forged_visit_shape, visit_definition, visit_host).get("ok", true)):
		failures.append("Receipt reconstruction accepted a visit record outside the exact schema.")

	var capacity_state := SequenceRuntimeScript.initial_state(definition, "bar_node", "mixed_capacity_seed", host_semantics)
	for visit_index in range(SequenceRuntimeScript.MAX_RECEIPTS - 1):
		var capacity_visit := SequenceRuntimeScript.record_visit(capacity_state, definition, "capacity_visit_%d" % visit_index)
		if not bool(capacity_visit.get("ok", false)):
			failures.append("Mixed causal-capacity fixture could not record its bounded visits.")
			return
		capacity_state = _dict(capacity_visit.get("state", {}))
	var capacity_fact := SequenceRuntimeScript.fact("heat_changed", "heat", "bar_node", "depth:capacity:first", 1, 1, _fact_payload("heat_changed"))
	var capacity_first_queue := SequenceRuntimeScript.enqueue_fact(capacity_state, definition, capacity_fact)
	var reserved_capacity_state := _dict(capacity_first_queue.get("state", {}))
	var reserved_before_second := JSON.stringify(reserved_capacity_state)
	var capacity_second_fact := SequenceRuntimeScript.fact("heat_changed", "heat", "bar_node", "depth:capacity:second", 2, 1, _fact_payload("heat_changed"))
	var capacity_second_queue := SequenceRuntimeScript.enqueue_fact(reserved_capacity_state, definition, capacity_second_fact)
	var capacity_command := SequenceRuntimeScript.apply_command(reserved_capacity_state, definition, _runtime_command(reserved_capacity_state, definition, "prepare", "bar_node", "arrival", "depth:capacity:command", {}, "scenario", "command_console"), {"available_funds": 10})
	var capacity_visit_rejection := SequenceRuntimeScript.record_visit(reserved_capacity_state, definition, "capacity_visit_rejected")
	var capacity_expiry_rejection := SequenceRuntimeScript.apply_expiry_boundary(reserved_capacity_state, definition, "night_end")
	var bounded_capacity_rebuild := ScenarioEngineScript._rebuild_receipted_semantic_mutations(reserved_capacity_state, definition, host_semantics)
	if not bool(capacity_first_queue.get("ok", false)) or bool(capacity_second_queue.get("ok", true)) or bool(capacity_command.get("ok", true)) or bool(capacity_visit_rejection.get("ok", true)) or bool(capacity_expiry_rejection.get("ok", true)) or not _contains_text(_array(capacity_second_queue.get("errors", [])), "lifetime") or not _contains_text(_array(capacity_command.get("errors", [])), "lifetime") or not _contains_text(_array(capacity_visit_rejection.get("errors", [])), "lifetime") or not _contains_text(_array(capacity_expiry_rejection.get("errors", [])), "lifetime") or JSON.stringify(capacity_second_queue.get("state", {})) != reserved_before_second or JSON.stringify(capacity_command.get("state", {})) != reserved_before_second or JSON.stringify(capacity_visit_rejection.get("state", {})) != reserved_before_second or JSON.stringify(capacity_expiry_rejection.get("state", {})) != reserved_before_second or not bool(bounded_capacity_rebuild.get("ok", false)) or _array(_dict(bounded_capacity_rebuild.get("state", {})).get("fact_queue", [])).size() != 1:
		failures.append("The shared lifetime cause budget did not atomically reserve pending fact capacity after 255 visits.")
	var over_capacity_state := reserved_capacity_state.duplicate(true)
	var forged_pending := _dict(over_capacity_state["fact_queue"][0]).duplicate(true)
	forged_pending["fact_id"] = "depth:capacity:forged_second"
	forged_pending["producer_serial"] = 2
	forged_pending["ingress_serial"] = int(forged_pending.get("ingress_serial", 1)) + 1
	over_capacity_state["fact_queue"].append(forged_pending)
	over_capacity_state["fact_serial_next"] = int(forged_pending.get("ingress_serial", 2)) + 1
	if not SequenceRuntimeScript.normalize_state(over_capacity_state, definition).is_empty() or bool(ScenarioEngineScript._rebuild_receipted_semantic_mutations(over_capacity_state, definition, host_semantics).get("ok", true)):
		failures.append("Normalization or Engine reconstruction retained 255 visit causes plus two pending facts beyond the global capacity.")
	var overbound_receipt_values: Array = []
	for hostile_index in range(SequenceRuntimeScript.MAX_RECEIPTS + 1):
		overbound_receipt_values.append("hostile_%d" % hostile_index)
	for field_value in [
		"resolved_branches", "resolved_outcomes",
		"fact_receipts", "fact_receipt_records", "fact_flush_batch_records",
		"command_receipts", "command_receipt_records", "branch_resolution_records",
		"transition_receipts", "transition_receipt_records",
		"cleanup_receipts", "cleanup_receipt_records", "event_correlations",
		"visit_receipts", "visit_receipt_records", "expiry_boundary_records",
	]:
		var overbound_field_state := initial.duplicate(true)
		overbound_field_state[str(field_value)] = overbound_receipt_values.duplicate(true)
		if not SequenceRuntimeScript.normalize_state(overbound_field_state, definition).is_empty():
			failures.append("Persisted %s accepted 257 entries by filtering or tail-slicing before its runtime limit check." % str(field_value))
	var overbound_dictionary_values: Dictionary = {}
	for hostile_index in range(SequenceRuntimeScript.MAX_RECEIPTS + 1):
		overbound_dictionary_values["hostile_%d" % hostile_index] = ""
	for field_value in ["command_results", "command_fingerprints", "cleanup_fingerprints", "fact_fingerprints"]:
		var overbound_dictionary_state := initial.duplicate(true)
		overbound_dictionary_state[str(field_value)] = overbound_dictionary_values.duplicate(true)
		if not SequenceRuntimeScript.normalize_state(overbound_dictionary_state, definition).is_empty():
			failures.append("Persisted %s accepted 257 entries before its runtime limit check." % str(field_value))
	var overbound_queue_values: Array = []
	for hostile_index in range(SequenceRuntimeScript.MAX_FACT_QUEUE + 1):
		overbound_queue_values.append("hostile_queue_%d" % hostile_index)
	var overbound_fact_queue := initial.duplicate(true)
	overbound_fact_queue["fact_queue"] = overbound_queue_values.duplicate(true)
	if not SequenceRuntimeScript.normalize_state(overbound_fact_queue, definition).is_empty():
		failures.append("Persisted fact_queue accepted 129 entries by filtering before its queue limit check.")
	var overbound_transition_queue := initial.duplicate(true)
	overbound_transition_queue["semantic_state"]["transition_queue"] = overbound_queue_values.duplicate(true)
	if not SequenceRuntimeScript.normalize_state(overbound_transition_queue, definition).is_empty():
		failures.append("Persisted semantic transition_queue accepted 129 entries before its queue limit check.")
	var overbound_operation_values: Array = []
	var overbound_operation_fingerprints: Dictionary = {}
	for hostile_index in range(OperationRegistryScript.MAX_OPERATION_RECEIPTS + 1):
		var hostile_receipt := "hostile_operation_%d" % hostile_index
		overbound_operation_values.append(hostile_receipt)
		overbound_operation_fingerprints[hostile_receipt] = "0".repeat(64)
	for field_value in ["operation_receipts", "operation_receipt_records"]:
		var overbound_operation_state := initial.duplicate(true)
		overbound_operation_state["semantic_state"][str(field_value)] = overbound_operation_values.duplicate(true)
		if not SequenceRuntimeScript.normalize_state(overbound_operation_state, definition).is_empty():
			failures.append("Persisted semantic %s accepted 513 entries before its runtime limit check." % str(field_value))
	var overbound_operation_fingerprint_state := initial.duplicate(true)
	overbound_operation_fingerprint_state["semantic_state"]["operation_fingerprints"] = overbound_operation_fingerprints
	if not SequenceRuntimeScript.normalize_state(overbound_operation_fingerprint_state, definition).is_empty():
		failures.append("Persisted semantic operation_fingerprints accepted 513 entries before its runtime limit check.")

	var fact_state := SequenceRuntimeScript.initial_state(definition, "bar_node", "fact_batch_seed", host_semantics)
	var first_payload := _fact_payload("heat_changed")
	first_payload["current"] = 1
	var first_fact := SequenceRuntimeScript.fact("heat_changed", "heat", "bar_node", "depth:fact:first", 1, 10, first_payload)
	var first_queued := SequenceRuntimeScript.enqueue_fact(fact_state, definition, first_fact)
	var first_flushed := SequenceRuntimeScript.flush_facts(_dict(first_queued.get("state", {})), definition, 10)
	fact_state = _dict(first_flushed.get("state", {}))
	var second_payload := _fact_payload("heat_changed")
	second_payload["current"] = 4
	var second_fact := SequenceRuntimeScript.fact("heat_changed", "heat", "bar_node", "depth:fact:second", 2, 1, second_payload)
	var second_queued := SequenceRuntimeScript.enqueue_fact(fact_state, definition, second_fact)
	var second_flushed := SequenceRuntimeScript.flush_facts(_dict(second_queued.get("state", {})), definition, 1)
	fact_state = _dict(second_flushed.get("state", {}))
	var fact_records := _array(fact_state.get("fact_receipt_records", []))
	var fact_batches := _array(fact_state.get("fact_flush_batch_records", []))
	var fact_rebuilt := ScenarioEngineScript._rebuild_receipted_semantic_mutations(fact_state, definition, host_semantics)
	if not bool(first_flushed.get("ok", false)) or not bool(second_flushed.get("ok", false)) or fact_records.size() != 2 or fact_batches.size() != 2 or int(_dict(fact_records[0]).get("flush_batch_ordinal", -1)) != 0 or int(_dict(fact_records[1]).get("flush_batch_ordinal", -1)) != 1 or int(_dict(fact_records[0]).get("flush_boundary_serial", -1)) != 10 or int(_dict(fact_records[1]).get("flush_boundary_serial", -1)) != 10 or int(_dict(fact_batches[0]).get("requested_boundary_serial", -1)) != 10 or int(_dict(fact_batches[1]).get("requested_boundary_serial", -1)) != 1 or int(_dict(fact_batches[0]).get("effective_boundary_serial", -1)) != 10 or int(_dict(fact_batches[1]).get("effective_boundary_serial", -1)) != 10 or str(_dict(fact_batches[1]).get("prior_batch_fingerprint", "")) != str(_dict(fact_batches[0]).get("batch_fingerprint", "")) or not bool(fact_rebuilt.get("ok", false)) or int(_dict(_dict(fact_rebuilt.get("state", {})).get("local_state", {})).get("pressure", -1)) != 4:
		failures.append("Fact replay did not preserve explicit accepted batch order across decreasing boundaries.")
	var forged_split_batch := fact_state.duplicate(true)
	forged_split_batch["fact_receipt_records"][1]["flush_batch_ordinal"] = 0
	if bool(ScenarioEngineScript._rebuild_receipted_semantic_mutations(forged_split_batch, definition, host_semantics).get("ok", true)):
		failures.append("Fact reconstruction accepted a duplicated/split flush batch ordinal.")
	var forged_merged_batch := fact_state.duplicate(true)
	forged_merged_batch["fact_flush_batch_records"][0]["fact_receipt_keys"].append("depth:fact:second")
	forged_merged_batch["fact_flush_batch_records"][0]["fact_fingerprints"].append(str(_dict(fact_records[1]).get("fingerprint", "")))
	forged_merged_batch["fact_flush_batch_records"].remove_at(1)
	if bool(ScenarioEngineScript._rebuild_receipted_semantic_mutations(forged_merged_batch, definition, host_semantics).get("ok", true)):
		failures.append("Fact reconstruction accepted a forged merge of independently authenticated equal-boundary batches.")
	var chained_definition := _runtime_definition()
	chained_definition["sequence"]["phase_graph"]["phases"][0]["branches"] = [{"id": "event_enters_aftermath", "condition": {"type": "fact", "fact_type": "event_result"}, "next_phase": "aftermath"}]
	chained_definition["sequence"]["fact_subscriptions"].append("event_result")
	chained_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(chained_definition)
	var chained_host := _fixture_host_semantics(chained_definition)
	var chained_initial := SequenceRuntimeScript.initial_state(chained_definition, "bar_node", "chained_fact_seed", chained_host)
	var chained_event := SequenceRuntimeScript.fact("event_result", "event", "bar_node", "depth:batch:event", 1, 7, _fact_payload("event_result"))
	var chained_heat := SequenceRuntimeScript.fact("heat_changed", "heat", "bar_node", "depth:batch:heat", 1, 7, _fact_payload("heat_changed"))
	var chained_event_queue := SequenceRuntimeScript.enqueue_fact(chained_initial, chained_definition, chained_event)
	var chained_heat_queue := SequenceRuntimeScript.enqueue_fact(_dict(chained_event_queue.get("state", {})), chained_definition, chained_heat)
	var chained_flush := SequenceRuntimeScript.flush_facts(_dict(chained_heat_queue.get("state", {})), chained_definition, 7)
	var chained_state := _dict(chained_flush.get("state", {}))
	var chained_batches := _array(chained_state.get("fact_flush_batch_records", []))
	var chained_batch_keys := _array(_dict(chained_batches[0] if not chained_batches.is_empty() else {}).get("fact_receipt_keys", []))
	var chained_saved_state := _without_transition_queue(chained_state)
	var chained_rebuild := ScenarioEngineScript._rebuild_receipted_semantic_mutations(chained_saved_state, chained_definition, chained_host)
	if not bool(chained_event_queue.get("ok", false)) or not bool(chained_heat_queue.get("ok", false)) or not bool(chained_flush.get("ok", false)) or chained_batches.size() != 1 or chained_batch_keys != ["depth:batch:event", "depth:batch:heat"] or str(chained_state.get("status", "")) != SequenceRuntimeScript.STATUS_AFTERMATH or _array(chained_state.get("resolved_outcomes", [])) != ["repaired"] or int(_dict(chained_state.get("local_state", {})).get("pressure", -1)) != 4 or not bool(chained_rebuild.get("ok", false)) or SequenceRuntimeScript.content_fingerprint(chained_rebuild.get("state", {})) != SequenceRuntimeScript.content_fingerprint(chained_saved_state):
		failures.append("One authenticated multi-fact batch did not replay the exact event-driven phase change before its later heat outcome.")

	var base_scene_identity := "base::fixture_101"
	var base_scene_state := {"declared_targets": {"scene_objects": [base_scene_identity]}, "target_inventory": {"scene_objects": [base_scene_identity]}}
	var base_mutation := _operation_fixture("scene_ops", "set_state", 101)
	base_mutation["owner_namespace"] = "base"
	var base_mutated := OperationRegistryScript.apply_operations(base_scene_state, "scene_ops", [base_mutation], "cleanup:base:phase:mutate")
	var base_restored := OperationRegistryScript.apply_operations(_dict(base_mutated.get("state", {})), "scene_ops", [base_mutation], "cleanup:base:cleanup:mutate", true)
	var base_remove := _operation_fixture("scene_ops", "remove", 101)
	base_remove["owner_namespace"] = "base"
	var base_removed := OperationRegistryScript.apply_operations(_dict(base_restored.get("state", {})), "scene_ops", [base_remove], "cleanup:base:phase:remove")
	var base_remove_restored := OperationRegistryScript.apply_operations(_dict(base_removed.get("state", {})), "scene_ops", [base_remove], "cleanup:base:cleanup:remove", true)
	if not bool(base_mutated.get("ok", false)) or not _dict(_dict(base_mutated.get("state", {})).get("scene_objects", {})).has(base_scene_identity) or not bool(base_restored.get("ok", false)) or _dict(_dict(base_restored.get("state", {})).get("scene_objects", {})).has(base_scene_identity) or not bool(_dict(_dict(_dict(base_removed.get("state", {})).get("tombstones", {})).get("scene_objects", {})).get(base_scene_identity, false)) or not bool(base_remove_restored.get("ok", false)) or _dict(_dict(_dict(base_remove_restored.get("state", {})).get("tombstones", {})).get("scene_objects", {})).has(base_scene_identity):
		failures.append("Cleanup did not erase a mutable base overlay and clear a base-removal tombstone back to the immutable inventory baseline.")
	for overlay_fixture_value in [["augment", 2], ["gate", 3], ["retarget", 4], ["replace", 5]]:
		var overlay_fixture := overlay_fixture_value as Array
		var overlay_kind := str(overlay_fixture[0])
		var overlay_index := int(overlay_fixture[1])
		var base_interaction_id := "fixture_target_%d" % overlay_index
		var base_interaction_identity := "base::%s" % base_interaction_id
		var base_interaction := _interaction_record("base", base_interaction_id, "Immutable base interaction", true)
		var overlay_state := {"base_interactions": [base_interaction], "declared_targets": {"interactions": [base_interaction_identity]}, "target_inventory": {"interactions": [base_interaction_identity]}}
		var baseline_interactions := _dict(OperationRegistryScript.resolved_semantic_state(overlay_state).get("interactions", {}))
		var overlay_operation := _operation_fixture("interaction_ops", overlay_kind, overlay_index)
		var overlay_applied := OperationRegistryScript.apply_operations(overlay_state, "interaction_ops", [overlay_operation], "cleanup:overlay:phase:%s" % overlay_kind)
		var overlay_source_identity := "scenario::fixture_%d" % overlay_index
		var overlay_cleaned := OperationRegistryScript.apply_operations(_dict(overlay_applied.get("state", {})), "interaction_ops", [overlay_operation], "cleanup:overlay:cleanup:%s" % overlay_kind, true)
		var restored_interactions := _dict(OperationRegistryScript.resolved_semantic_state(_dict(overlay_cleaned.get("state", {}))).get("interactions", {}))
		if not bool(overlay_applied.get("ok", false)) or not _dict(_dict(overlay_applied.get("state", {})).get("interactions", {})).has(overlay_source_identity) or not bool(overlay_cleaned.get("ok", false)) or _dict(_dict(overlay_cleaned.get("state", {})).get("interactions", {})).has(overlay_source_identity) or JSON.stringify(restored_interactions) != JSON.stringify(baseline_interactions):
			failures.append("Interaction %s cleanup did not remove its source overlay and reveal the exact immutable base interaction." % overlay_kind)
	var cleanup_proof_operations: Array = [base_mutation, base_remove]
	for proof_overlay_value in [["augment", 2], ["gate", 3], ["retarget", 4], ["replace", 5]]:
		var proof_overlay := proof_overlay_value as Array
		cleanup_proof_operations.append(_operation_fixture("interaction_ops", str(proof_overlay[0]), int(proof_overlay[1])))
	for proof_operation_value in cleanup_proof_operations:
		var proof_operation := _dict(proof_operation_value)
		var proof_family := str(proof_operation.get("family", ""))
		var target_collection := "scene_objects" if proof_family == "scene_ops" else "interactions"
		var target_identity := "%s::%s" % [str(proof_operation.get("owner_namespace", "")), str(proof_operation.get("stable_object_id", ""))]
		if proof_family == "interaction_ops":
			target_identity = "%s::%s" % [str(proof_operation.get("target_owner_namespace", "")), str(proof_operation.get("target_stable_object_id", ""))]
		var proof_fixture := _cleanup_proof_fixture(proof_operation, target_collection, target_identity)
		var proof_errors := SequenceSchemaScript.validate_definition(_dict(proof_fixture.get("definition", {})), OperationRegistryScript, _dict(proof_fixture.get("inventory", {})))
		if not proof_errors.is_empty():
			failures.append("Cleanup material proof rejected exact inverse restoration for %s: %s" % [str(proof_operation.get("op", "")), JSON.stringify(proof_errors)])

	var restart_definition := _runtime_definition()
	restart_definition["sequence"]["reentry_policy"]["partial"] = "restart"
	restart_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(restart_definition)
	var restart_host := _fixture_host_semantics(restart_definition)
	var restart_state := SequenceRuntimeScript.initial_state(restart_definition, "bar_node", "interleaved_restart_seed", restart_host)
	var restart_first_visit := SequenceRuntimeScript.record_visit(restart_state, restart_definition, "restart_visit_before")
	restart_state = _dict(restart_first_visit.get("state", {}))
	var restart_fact := SequenceRuntimeScript.fact("heat_changed", "heat", "bar_node", "depth:restart:fact", 1, 3, _fact_payload("heat_changed"))
	var restart_queued := SequenceRuntimeScript.enqueue_fact(restart_state, restart_definition, restart_fact)
	var restart_flushed := SequenceRuntimeScript.flush_facts(_dict(restart_queued.get("state", {})), restart_definition, 3)
	restart_state = _dict(restart_flushed.get("state", {}))
	var restart_command := SequenceRuntimeScript.apply_command(restart_state, restart_definition, _runtime_command(restart_state, restart_definition, "prepare", "bar_node", "arrival", "depth:restart:command", {}, "scenario", "command_console"), {"available_funds": 10})
	restart_state = _dict(restart_command.get("state", {}))
	var restarted := SequenceRuntimeScript.apply_reentry(restart_state, restart_definition, "restart_visit_after", restart_host)
	var restarted_state := _dict(restarted.get("state", {}))
	var restarted_visit_records := _array(restarted_state.get("visit_receipt_records", []))
	var restarted_saved_state := _without_transition_queue(restarted_state)
	var restarted_rebuild := ScenarioEngineScript._rebuild_receipted_semantic_mutations(restarted_saved_state, restart_definition, restart_host)
	if not bool(restart_first_visit.get("ok", false)) or not bool(restart_queued.get("ok", false)) or not bool(restart_flushed.get("ok", false)) or not bool(restart_command.get("ok", false)) or not bool(restarted.get("ok", false)) or str(restarted.get("policy", "")) != "restart" or _array(restarted_state.get("command_receipt_records", [])).size() != 0 or _array(restarted_state.get("fact_receipt_records", [])).size() != 0 or _array(restarted_state.get("fact_flush_batch_records", [])).size() != 0 or restarted_visit_records.size() != 2 or int(_dict(restarted_visit_records[0]).get("cause_ordinal", -1)) != 0 or int(_dict(restarted_visit_records[1]).get("cause_ordinal", -1)) != 1 or int(_dict(restarted_state.get("local_state", {})).get("pressure", -1)) != 0 or not bool(restarted_rebuild.get("ok", false)) or SequenceRuntimeScript.content_fingerprint(restarted_rebuild.get("state", {})) != SequenceRuntimeScript.content_fingerprint(restarted_saved_state):
		failures.append("Restart reentry did not reset interleaved command/fact batches while reordinaling visits into an exact replayable causal journal.")

	var lifecycle_definition := _runtime_definition()
	lifecycle_definition["sequence"]["expiry"] = {"boundary": "night_end", "after": 1, "policy": "cleanup"}
	lifecycle_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(lifecycle_definition)
	var lifecycle_host := _fixture_host_semantics(lifecycle_definition)
	var lifecycle_state := SequenceRuntimeScript.initial_state(lifecycle_definition, "bar_node", "cleanup_lifecycle_seed", lifecycle_host)
	for lifecycle_command_value in [["prepare", "arrival", "lifecycle:prepare", "command_console"], ["finish", "arrival", "lifecycle:finish", "command_console"], ["use", "aftermath", "lifecycle:terminal", "fixture_201"]]:
		var lifecycle_command := lifecycle_command_value as Array
		var lifecycle_applied := SequenceRuntimeScript.apply_command(lifecycle_state, lifecycle_definition, _runtime_command(lifecycle_state, lifecycle_definition, str(lifecycle_command[0]), "bar_node", str(lifecycle_command[1]), str(lifecycle_command[2]), {}, "scenario", str(lifecycle_command[3])), {"available_funds": 10})
		if not bool(lifecycle_applied.get("ok", false)):
			failures.append("Cleanup lifecycle fixture could not reach its terminal state.")
			return
		lifecycle_state = _dict(lifecycle_applied.get("state", {}))
	var terminal_operation_count := _array(_dict(lifecycle_state.get("semantic_state", {})).get("operation_receipt_records", [])).size()
	var lifecycle_expiry := SequenceRuntimeScript.apply_expiry_boundary(lifecycle_state, lifecycle_definition, "night_end")
	var lifecycle_expired_state := _dict(lifecycle_expiry.get("state", {}))
	var repeated_expiry := SequenceRuntimeScript.apply_expiry_boundary(lifecycle_expired_state, lifecycle_definition, "night_end")
	var lifecycle_saved_state := _without_transition_queue(lifecycle_expired_state)
	var lifecycle_rebuild := ScenarioEngineScript._rebuild_receipted_semantic_mutations(lifecycle_saved_state, lifecycle_definition, lifecycle_host)
	if not bool(lifecycle_expiry.get("ok", false)) or not bool(repeated_expiry.get("ok", false)) or not bool(repeated_expiry.get("replayed", false)) or JSON.stringify(repeated_expiry.get("state", {})) != JSON.stringify(lifecycle_expired_state) or _array(lifecycle_expired_state.get("cleanup_receipts", [])).size() != 2 or _array(_dict(lifecycle_expired_state.get("semantic_state", {})).get("operation_receipt_records", [])).size() != terminal_operation_count or not bool(lifecycle_rebuild.get("ok", false)) or SequenceRuntimeScript.content_fingerprint(lifecycle_rebuild.get("state", {})) != SequenceRuntimeScript.content_fingerprint(lifecycle_saved_state):
		failures.append("Terminal cleanup followed by authored expiry did not remain an exact semantic no-op with replayable causal journals.")
	var later_cleanup_state := lifecycle_expired_state
	for later_reason in ["leave", "visit_end", "night"]:
		var before_later_count := _array(_dict(later_cleanup_state.get("semantic_state", {})).get("operation_receipt_records", [])).size()
		var later_cleanup := SequenceRuntimeScript._apply_cleanup(later_cleanup_state, lifecycle_definition, later_reason)
		var later_cleaned_state := _dict(later_cleanup.get("state", {}))
		var later_replay := SequenceRuntimeScript._apply_cleanup(later_cleaned_state, lifecycle_definition, later_reason)
		if not bool(later_cleanup.get("ok", false)) or bool(later_cleanup.get("replayed", true)) or _array(_dict(later_cleaned_state.get("semantic_state", {})).get("operation_receipt_records", [])).size() != before_later_count or not bool(later_replay.get("ok", false)) or not bool(later_replay.get("replayed", false)) or JSON.stringify(later_replay.get("state", {})) != JSON.stringify(later_cleaned_state):
			failures.append("Repeated legitimate %s cleanup was not a receipt-authenticated semantic no-op." % later_reason)
		later_cleanup_state = later_cleaned_state
	var forged_cleanup_definition := lifecycle_definition.duplicate(true)
	forged_cleanup_definition["sequence"]["cleanup"]["operations"][0]["receipt_id"] = "forged_cleanup_content"
	forged_cleanup_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(forged_cleanup_definition)
	var before_forged_cleanup := JSON.stringify(later_cleanup_state)
	var forged_cleanup_result := SequenceRuntimeScript._apply_cleanup(later_cleanup_state, forged_cleanup_definition, "forged")
	if bool(forged_cleanup_result.get("ok", true)) or JSON.stringify(forged_cleanup_result.get("state", {})) != before_forged_cleanup:
		failures.append("Finalized cleanup accepted different authored content or mutated before rejecting it.")

	for local_fixture_value in [
		["missing", {"type": "local_min", "key": "pressure"}],
		["float", {"type": "local_min", "key": "pressure", "value": 1.0}],
		["descriptor", {"type": "local_min", "key": "protected_exit", "value": 1}],
		["domain", {"type": "local_min", "key": "pressure", "value": 6}],
	]:
		var local_fixture := local_fixture_value as Array
		var local_definition := _runtime_definition()
		local_definition["sequence"]["phase_graph"]["phases"][0]["entry_conditions"] = [_dict(local_fixture[1])]
		local_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(local_definition)
		if not _contains_text(SequenceSchemaScript.validate_definition(local_definition, OperationRegistryScript, _fixture_target_inventory(local_definition)), "local_min"):
			failures.append("Sequence schema accepted hostile local_min fixture %s." % str(local_fixture[0]))
	if SequenceRuntimeScript._condition_matches({"type": "local_min", "key": "pressure", "value": 1.0}, {"local_state": {"pressure": 3}}, {}):
		failures.append("Runtime local_min coerced a floating threshold to an integer.")

	var cycle_with_exit := _fixture_definition()
	cycle_with_exit["sequence"]["phase_graph"]["phases"][0]["branches"].append({"id": "cycle_with_exit", "condition": {"type": "fact", "fact_type": "heat_changed"}, "next_phase": "arrival"})
	cycle_with_exit["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(cycle_with_exit)
	if not _contains_text(SequenceSchemaScript.validate_definition(cycle_with_exit, OperationRegistryScript, _fixture_target_inventory(cycle_with_exit)), "phase cycles are not permitted"):
		failures.append("Material path proof silently skipped a reachable cycle that also had an exit.")
	var cleanup_ghost := _fixture_definition()
	cleanup_ghost["sequence"]["cleanup"]["operations"].append({"family": "scene_ops", "op": "remove", "receipt_id": "cleanup_ghost", "owner_namespace": "scenario", "stable_object_id": "ghost"})
	cleanup_ghost["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(cleanup_ghost)
	if not _contains_text(SequenceSchemaScript.validate_definition(cleanup_ghost, OperationRegistryScript, _fixture_target_inventory(cleanup_ghost)), "cleanup operation cleanup_ghost has no exact live mutation/tombstone/overlay obligation"):
		failures.append("Sequence cleanup authorized a target absent from terminal paths.")
	var early_cleanup_target := _runtime_definition()
	var early_interaction := _dict(early_cleanup_target["sequence"]["phase_graph"]["phases"][0]["interaction_ops"][0])
	var early_payload := _dict(early_interaction.get("interaction", {}))
	early_payload["available_actions"].append({"id": "early_clean", "label": "Clean early", "input_action": "confirm", "non_color_state": "ready", "handler": "request_cleanup", "inputs": {"reason": "early"}})
	early_interaction["interaction"] = early_payload
	early_cleanup_target["sequence"]["phase_graph"]["phases"][0]["interaction_ops"][0] = early_interaction
	early_cleanup_target["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(early_cleanup_target)
	var early_cleanup_errors := SequenceSchemaScript.validate_definition(early_cleanup_target, OperationRegistryScript, _fixture_target_inventory(early_cleanup_target))
	if not _contains_text(early_cleanup_errors, "phase arrival request_cleanup") or not _contains_text(early_cleanup_errors, "cleanup operation cleanup_terminal_interaction has no exact live mutation/tombstone/overlay obligation"):
		failures.append("Schema validation did not reject an actual arrival request_cleanup call site whose cleanup target is created only in a later phase.")
	var cleanup_leak := _fixture_definition()
	cleanup_leak["sequence"]["cleanup"]["operations"].remove_at(2)
	cleanup_leak["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(cleanup_leak)
	if not _contains_text(SequenceSchemaScript.validate_definition(cleanup_leak, OperationRegistryScript, _fixture_target_inventory(cleanup_leak)), "leaks temporary actors target"):
		failures.append("Sequence cleanup proof did not reject a temporary actor leak.")
	var path_explosion := _path_explosion_fixture()
	if not _contains_text(SequenceSchemaScript.validate_definition(path_explosion, OperationRegistryScript, _fixture_target_inventory(path_explosion)), "512-path limit"):
		failures.append("Sequence material proof silently truncated exploration beyond 512 paths.")


static func _check_atomic_runtime_failures(failures: Array) -> void:
	var definition := _runtime_definition()
	var initial := SequenceRuntimeScript.initial_state(definition, "bar_node", "atomic_seed", _fixture_host_semantics(definition))
	var prepared := SequenceRuntimeScript.apply_command(initial, definition, _runtime_command(initial, definition, "prepare", "bar_node", "arrival", "atomic:prepare", {}, "scenario", "command_console"), {"available_funds": 2})
	var prepared_state := _dict(prepared.get("state", {}))
	var bad_phase := definition.duplicate(true)
	bad_phase["sequence"]["phase_graph"]["phases"][1]["scene_ops"] = [_operation_fixture("scene_ops", "set_state", 9999)]
	var before_phase := JSON.stringify(prepared_state)
	var failed_phase := SequenceRuntimeScript.apply_command(prepared_state, bad_phase, _runtime_command(prepared_state, bad_phase, "finish", "bar_node", "arrival", "atomic:finish", {}, "scenario", "command_console"), {"available_funds": 4})
	if bool(failed_phase.get("ok", true)) or JSON.stringify(failed_phase.get("state", {})) != before_phase:
		failures.append("Failed phase entry committed command, objective, receipt, or semantic state.")
	var blocked_entry := definition.duplicate(true)
	blocked_entry["sequence"]["phase_graph"]["phases"][1]["entry_conditions"] = [{"type": "local_min", "key": "pressure", "value": 5}]
	var failed_entry := SequenceRuntimeScript.apply_command(prepared_state, blocked_entry, _runtime_command(prepared_state, blocked_entry, "finish", "bar_node", "arrival", "atomic:entry", {}, "scenario", "command_console"), {"available_funds": 4})
	if bool(failed_entry.get("ok", true)) or JSON.stringify(failed_entry.get("state", {})) != before_phase:
		failures.append("Phase entry conditions were not executed atomically.")
	var receipt_entry := definition.duplicate(true)
	receipt_entry["sequence"]["phase_graph"]["phases"][1]["entry_conditions"] = [{"type": "receipt", "receipt_kind": "operation", "family": "scene_ops", "boundary_id": "sequence_fixture:bar_node:phase:arrival:initial", "receipt_id": "scene_spawn_100"}]
	receipt_entry["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(receipt_entry)
	var receipt_initial := SequenceRuntimeScript.initial_state(receipt_entry, "bar_node", "receipt_entry_seed", _fixture_host_semantics(receipt_entry))
	var receipt_prepared := SequenceRuntimeScript.apply_command(receipt_initial, receipt_entry, _runtime_command(receipt_initial, receipt_entry, "prepare", "bar_node", "arrival", "receipt:prepare", {}, "scenario", "command_console"), {"available_funds": 2})
	var receipt_prepared_state := _dict(receipt_prepared.get("state", {}))
	var receipt_finished := SequenceRuntimeScript.apply_command(receipt_prepared_state, receipt_entry, _runtime_command(receipt_prepared_state, receipt_entry, "finish", "bar_node", "arrival", "receipt:finish", {}, "scenario", "command_console"), {"available_funds": 4})
	if not bool(receipt_finished.get("ok", false)) or str(_dict(receipt_finished.get("state", {})).get("phase_id", "")) != "aftermath":
		failures.append("Typed operation receipt condition did not match its exact family/boundary/authored id record.")
	var bad_cleanup := definition.duplicate(true)
	bad_cleanup["sequence"]["expiry"]["policy"] = "cleanup"
	bad_cleanup["sequence"]["cleanup"]["operations"].append(_operation_fixture("scene_ops", "set_state", 9999))
	var failed_expiry := SequenceRuntimeScript.apply_expiry_boundary(initial, bad_cleanup, "night_end")
	if bool(failed_expiry.get("ok", true)) or JSON.stringify(failed_expiry.get("state", {})) != JSON.stringify(initial):
		failures.append("Failed expiry cleanup committed partial state or a cleanup receipt.")
	var bad_fact := bad_cleanup.duplicate(true)
	bad_fact["sequence"]["fact_subscriptions"] = [{"fact_type": "event_result", "handler": "request_cleanup", "inputs": {"reason": "fact"}}]
	var queued := SequenceRuntimeScript.enqueue_fact(initial, bad_fact, SequenceRuntimeScript.fact("event_result", "event", "bar_node", "atomic:fact", 1, 1, _fact_payload("event_result")))
	var queued_state := _dict(queued.get("state", {}))
	var failed_flush := SequenceRuntimeScript.flush_facts(queued_state, bad_fact, 1)
	if bool(failed_flush.get("ok", true)) or JSON.stringify(failed_flush.get("state", {})) != JSON.stringify(queued_state) or not _array(failed_flush.get("processed", [])).is_empty():
		failures.append("Failed fact batch dropped a fact or committed a partial receipt/state change.")
	var visit := SequenceRuntimeScript.record_visit(initial, definition, "visit_1")
	var visit_replay := SequenceRuntimeScript.record_visit(_dict(visit.get("state", {})), definition, "visit_1")
	if not bool(visit.get("ok", false)) or not bool(visit_replay.get("replayed", false)):
		failures.append("Scenario visit receipt is not stable and replay-safe.")
	var reentered := SequenceRuntimeScript.apply_reentry(initial, definition, "visit_2")
	if not bool(reentered.get("ok", false)) or str(reentered.get("policy", "")) != "resume" or _array(_dict(reentered.get("state", {})).get("visit_receipts", [])).size() != 1:
		failures.append("Scenario partial reentry policy did not execute with a durable visit receipt.")
	var expired := SequenceRuntimeScript.apply_expiry_boundary(initial, definition, "night_end")
	if not bool(expired.get("ok", false)) or not bool(_dict(expired.get("state", {})).get("expired", false)) or str(_dict(_dict(_dict(expired.get("state", {})).get("objective_progress", {})).get("clear_exit", {})).get("outcome", "")) != "ignore":
		failures.append("Scenario expiry policy did not persist its objective outcome.")


static func _check_authoritative_receipt_capacity(failures: Array) -> void:
	var definition := _runtime_definition()
	var state := SequenceRuntimeScript.initial_state(definition, "bar_node", "receipt_seed", _fixture_host_semantics(definition))
	var first_command := _runtime_command(state, definition, "prepare", "bar_node", "arrival", "capacity:command:0", {}, "scenario", "command_console")
	for index in range(SequenceRuntimeScript.MAX_RECEIPTS):
		var command := first_command if index == 0 else _runtime_command(state, definition, "prepare", "bar_node", "arrival", "capacity:command:%d" % index, {}, "scenario", "command_console")
		var applied := SequenceRuntimeScript.apply_command(state, definition, command, {"available_funds": 2})
		if not bool(applied.get("ok", false)):
			failures.append("Authoritative command receipt capacity failed before its declared limit at %d." % index)
			return
		state = _dict(applied.get("state", {}))
	var overflow := SequenceRuntimeScript.apply_command(state, definition, _runtime_command(state, definition, "prepare", "bar_node", "arrival", "capacity:command:overflow", {}, "scenario", "command_console"), {"available_funds": 2})
	if bool(overflow.get("ok", true)) or not _contains_text(_array(overflow.get("errors", [])), "lifetime receipt limit"):
		failures.append("Sequence command lifetime did not fail closed at receipt capacity.")
	var old_replay := SequenceRuntimeScript.apply_command(state, definition, first_command, {"available_funds": 0})
	if not bool(old_replay.get("ok", false)) or not bool(old_replay.get("replayed", false)):
		failures.append("Old command receipt became replayable after reaching capacity.")

	var fact_state := SequenceRuntimeScript.initial_state(definition, "bar_node", "fact_receipt_seed", _fixture_host_semantics(definition))
	var first_fact := SequenceRuntimeScript.fact("event_result", "event", "bar_node", "capacity:fact:0", 0, 1, _fact_payload("event_result"))
	for index in range(SequenceRuntimeScript.MAX_RECEIPTS):
		var typed_fact := first_fact if index == 0 else SequenceRuntimeScript.fact("event_result", "event", "bar_node", "capacity:fact:%d" % index, index, 1, _fact_payload("event_result"))
		var queued := SequenceRuntimeScript.enqueue_fact(fact_state, definition, typed_fact)
		if not bool(queued.get("ok", false)):
			failures.append("Authoritative fact receipt capacity failed before its declared limit at %d." % index)
			return
		var flushed := SequenceRuntimeScript.flush_facts(_dict(queued.get("state", {})), definition, 1)
		fact_state = _dict(flushed.get("state", {}))
	var fact_overflow := SequenceRuntimeScript.enqueue_fact(fact_state, definition, SequenceRuntimeScript.fact("event_result", "event", "bar_node", "capacity:fact:overflow", 999, 1, _fact_payload("event_result")))
	if bool(fact_overflow.get("ok", true)) or not _contains_text(_array(fact_overflow.get("errors", [])), "lifetime receipt limit"):
		failures.append("Sequence fact lifetime did not fail closed at receipt capacity.")
	var old_fact_replay := SequenceRuntimeScript.enqueue_fact(fact_state, definition, first_fact)
	if not bool(old_fact_replay.get("ok", false)) or not bool(old_fact_replay.get("duplicate", false)):
		failures.append("Old fact receipt became replayable after reaching capacity.")

	var semantic_targets := {"scene_objects": ["scenario::fixture_700"]}
	var semantic: Dictionary = {"declared_targets": semantic_targets, "target_inventory": semantic_targets.duplicate(true)}
	var first_operation := _operation_fixture("scene_ops", "set_state", 700)
	for index in range(SequenceRuntimeScript.MAX_RECEIPTS + 16):
		var operation := first_operation.duplicate(true)
		if index > 0:
			operation["receipt_id"] = "capacity_operation_%d" % index
		var applied_ops := OperationRegistryScript.apply_operations(semantic, "scene_ops", [operation], "capacity:node:phase:%d" % index)
		semantic = _dict(applied_ops.get("state", {}))
	var operation_replay := OperationRegistryScript.apply_operations(semantic, "scene_ops", [first_operation], "capacity:node:phase:0")
	if not bool(operation_replay.get("ok", false)) or not _array(operation_replay.get("applied", [])).is_empty() or JSON.stringify(operation_replay.get("state", {})) != JSON.stringify(semantic):
		failures.append("Old transition/operation receipt was evicted after presentation capacity.")
	var full_receipts: Array = []
	for index in range(OperationRegistryScript.MAX_OPERATION_RECEIPTS):
		full_receipts.append("op_capacity_%d" % index)
	var full_state := {"declared_targets": {"scene_objects": ["scenario::fixture_700"]}, "operation_receipts": full_receipts}
	var receipt_overflow := OperationRegistryScript.apply_operations(full_state, "scene_ops", [first_operation], "capacity:node:phase:new")
	if bool(receipt_overflow.get("ok", true)) or not _contains_text(_array(receipt_overflow.get("errors", [])), "receipt limit"):
		failures.append("Operation lifetime receipt capacity did not fail closed.")
	var full_queue: Array = []
	for index in range(OperationRegistryScript.MAX_TRANSITION_QUEUE):
		full_queue.append({"receipt_id": "queued_%d" % index})
	var queue_state := {"transition_queue": full_queue}
	var queue_overflow := OperationRegistryScript.apply_operations(queue_state, "transition_ops", [_operation_fixture("transition_ops", "feedback", 999)], "capacity:node:phase:queue")
	if bool(queue_overflow.get("ok", true)) or not _contains_text(_array(queue_overflow.get("errors", [])), "queue capacity") or JSON.stringify(queue_overflow.get("state", {})) != JSON.stringify(OperationRegistryScript.apply_operations(queue_state, "transition_ops", [], "capacity:node:phase:noop").get("state", {})):
		failures.append("Transition queue capacity did not preserve the unchanged semantic state.")


static func _check_host_transaction_seam(failures: Array) -> void:
	var context := HostTransactionScript.public_context("bar_node", "bar_visit_7", "night_3", "table_context_11")
	var injected := HostTransactionScript.inject_public_context({"id": "bar_001", "archetype_id": "bar"}, context)
	var restored_environment := EnvironmentInstanceScript.from_dict(_dict(injected.get("environment", {}))).to_dict()
	for key in ["world_node_id", "environment_visit_id", "night_instance_id", "context_instance_id"]:
		var context_key: String = "node_id" if key == "world_node_id" else key
		if str(restored_environment.get(key, "")) != str(context.get(context_key, "")):
			failures.append("Public game context did not persist %s before normalization." % key)
	var leases := {
		"scenario_main": {"owner_id": "scenario", "stream_id": "scenario", "current_state": 10, "receipts": []},
		"craps_throw_main": {"owner_id": "craps_throw", "stream_id": "craps_throw", "current_state": 20, "receipts": []},
		"craps_recovery_main": {"owner_id": "craps_recovery", "stream_id": "craps_recovery", "current_state": 30, "receipts": []},
		"poker_cards_main": {"owner_id": "poker_cards", "stream_id": "poker_cards", "current_state": 40, "receipts": []},
		"poker_policy_crew_rook": {"owner_id": "poker_policy_crew_rook", "stream_id": "poker_policy_crew_rook", "current_state": 50, "receipts": []},
		"poker_policy_crew_velvet": {"owner_id": "poker_policy_crew_velvet", "stream_id": "poker_policy_crew_velvet", "current_state": 51, "receipts": []},
		"poker_policy_crew_knuckles": {"owner_id": "poker_policy_crew_knuckles", "stream_id": "poker_policy_crew_knuckles", "current_state": 52, "receipts": []},
		"poker_policy_crew_switch": {"owner_id": "poker_policy_crew_switch", "stream_id": "poker_policy_crew_switch", "current_state": 53, "receipts": []},
		"poker_policy_crew_mags": {"owner_id": "poker_policy_crew_mags", "stream_id": "poker_policy_crew_mags", "current_state": 54, "receipts": []},
		"poker_policy_crew_bishop": {"owner_id": "poker_policy_crew_bishop", "stream_id": "poker_policy_crew_bishop", "current_state": 55, "receipts": []},
		"poker_policy_crew_lucky": {"owner_id": "poker_policy_crew_lucky", "stream_id": "poker_policy_crew_lucky", "current_state": 56, "receipts": []},
		"poker_policy_intruder": {"owner_id": "poker_policy_intruder", "stream_id": "poker_policy_intruder", "current_state": 57, "receipts": []},
	}
	var state := HostTransactionScript.initial_state({"player_bankroll": {"fund_domain": "bankroll", "balance": 100}, "grand_casino_chips": {"fund_domain": "chips", "balance": 50}}, {
		"craps_table": {"producer_id": "craps", "game_id": "craps", "active": true, "round": 0},
		"casino_craps_table": {"producer_id": "craps", "game_id": "craps", "active": true, "round": 0, "prepared_account_id": "grand_casino_chips"},
		"poker_table": {"producer_id": "poker", "game_id": "poker", "active": true, "round": 0},
	}, leases)
	var allowed := HostTransactionScript.prepared_game_context(state, context, "craps_table", "craps")
	if not bool(allowed.get("ok", false)) or _dict(allowed.get("context", {})).has("prepared_requests"):
		failures.append("Prepared game context did not use the public allowlist.")
	var allowed_leases := _array(_dict(allowed.get("context", {})).get("rng_leases", []))
	if allowed_leases.size() != 2 or str(_dict(allowed_leases[0]).get("owner_id", "")).begins_with("poker"):
		failures.append("Prepared game context exposed another producer's RNG leases.")
	var street_accounts := _dict(_dict(allowed.get("context", {})).get("accounts", {}))
	var street_prepared := _dict(_dict(allowed.get("context", {})).get("prepared_account", {}))
	if street_accounts.keys() != ["player_bankroll"] or str(street_prepared.get("account_id", "")) != "player_bankroll" or str(street_prepared.get("fund_domain", "")) != "bankroll":
		failures.append("Street Craps context did not expose exactly its prepared bankroll account.")
	var casino_allowed := HostTransactionScript.prepared_game_context(state, context, "casino_craps_table", "craps")
	var casino_accounts := _dict(_dict(casino_allowed.get("context", {})).get("accounts", {}))
	var casino_prepared := _dict(_dict(casino_allowed.get("context", {})).get("prepared_account", {}))
	if not bool(casino_allowed.get("ok", false)) or casino_accounts.keys() != ["grand_casino_chips"] or str(casino_prepared.get("fund_domain", "")) != "chips":
		failures.append("Casino Craps context did not expose exactly its prepared chip account.")
	var poker_allowed := HostTransactionScript.prepared_game_context(state, context, "poker_table", "poker")
	var poker_leases := _array(_dict(poker_allowed.get("context", {})).get("rng_leases", []))
	var poker_states: Dictionary = {}
	for lease_value in poker_leases:
		var lease := _dict(lease_value)
		poker_states[str(lease.get("current_state", ""))] = true
		if str(lease.get("owner_id", "")).begins_with("craps") or str(lease.get("owner_id", "")) == "scenario": failures.append("Poker context exposed a foreign RNG lease.")
	if not bool(poker_allowed.get("ok", false)) or poker_leases.size() != 8 or poker_states.size() != 8:
		failures.append("Poker context did not expose cards plus seven unique member-scoped policy leases.")
	var forbidden_context := HostTransactionScript.prepared_game_context(state, context, "craps_table", "craps", ["node_id", "prepared_requests"])
	if bool(forbidden_context.get("ok", true)):
		failures.append("Prepared game context exposed runtime-owned request records.")
	var replacement := {"producer_id": "craps", "game_id": "craps", "active": true, "round": 1, "point": 6}
	var command_receipt := "craps:bar_visit_7:table_context_11:roll_1"
	var fact := HostTransactionScript.game_fact("game_result", "craps", "craps", "craps_table", context, "craps:bar_visit_7:roll:1", "scenario:bar_visit_7:fact:1", 1, {"won": true, "amount": 5})
	var request := HostTransactionScript.prepared_request("sweep_interrupt_1", "interruption", "craps_table", context, HostTransactionScript.state_digest(replacement), 1, 1, 3, {"reason_id": "police_sweep"})
	var command := HostTransactionScript.game_command("craps", "craps", "craps_table", command_receipt, context, HostTransactionScript.state_digest({"producer_id": "craps", "game_id": "craps", "active": true, "round": 0}), replacement, {
		"account_ops": [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": 100, "account_after": 95, "delta": -5, "reason": "stake"}],
		"facts": [fact],
		"prepared_acknowledgements": [{"ack_id": "roll_prepared", "kind": "game_command", "message": "Roll prepared."}],
		"external_warnings": ["The table is being watched."],
		"rng_updates": [{"lease_id": "craps_throw_main", "owner_id": "craps_throw", "before_state": 20, "after_state": 21, "receipt_id": command_receipt}],
		"prepared_request": request,
	})
	var transaction := HostTransactionScript.reduce_game_command(state, command)
	if not bool(transaction.get("ok", false)):
		failures.append("Pure game-command reducer rejected a valid typed delta: %s" % JSON.stringify(transaction.get("errors", [])))
		return
	var stale_state := state.duplicate(true)
	stale_state["revision"] = 1
	var stale := HostTransactionScript.commit_game_command(stale_state, transaction)
	if bool(stale.get("ok", true)) or JSON.stringify(stale.get("state", {})) != JSON.stringify(HostTransactionScript.normalize_state(stale_state)):
		failures.append("CAS game transaction did not reject a stale revision/digest without partial state.")
	var committed := HostTransactionScript.commit_game_command(state, transaction)
	if not bool(committed.get("ok", false)):
		failures.append("Atomic game transaction failed: %s" % JSON.stringify(committed.get("errors", [])))
		return
	state = _dict(committed.get("state", {}))
	if int(_dict(_dict(state.get("accounts", {})).get("player_bankroll", {})).get("balance", 0)) != 95 or int(_dict(_dict(state.get("table_states", {})).get("craps_table", {})).get("round", 0)) != 1:
		failures.append("Atomic Craps transaction did not commit its table and prepared account together.")
	if int(_dict(_dict(state.get("rng_leases", {})).get("craps_throw_main", {})).get("current_state", 0)) != 21 or _array(state.get("fact_queue", [])).size() != 1 or str(_dict(_dict(state.get("prepared_requests", {})).get("sweep_interrupt_1", {})).get("status", "")) != "prepared":
		failures.append("Atomic game transaction dropped RNG, GameFact, or prepared-request state.")
	if _array(state.get("external_warnings", [])).size() != 1 or _array(state.get("acknowledgements", [])).size() < 2:
		failures.append("External warnings and runtime acknowledgements were not kept distinct.")
	var replay := HostTransactionScript.commit_game_command(state, transaction)
	if not bool(replay.get("ok", false)) or not bool(replay.get("replayed", false)) or JSON.stringify(replay.get("state", {})) != JSON.stringify(state):
		failures.append("Authoritative game-command receipt was not idempotent and non-evicting.")
	var divergent := state.duplicate(true)
	divergent["accounts"]["player_bankroll"]["balance"] = 999
	var divergence_command := HostTransactionScript.game_command("craps", "craps", "craps_table", "craps:bar_visit_7:table_context_11:divergence", context, HostTransactionScript.state_digest(replacement), replacement)
	if bool(HostTransactionScript.reduce_game_command(divergent, divergence_command).get("ok", true)):
		failures.append("Host transaction accepted a canonical RunState snapshot that diverged from its CAS digest.")
	var conflicting := transaction.duplicate(true)
	conflicting["fingerprint"] = "conflicting"
	if bool(HostTransactionScript.commit_game_command(state, conflicting).get("ok", true)):
		failures.append("Authoritative game-command receipt accepted conflicting content.")
	var poker_replacement := {"producer_id": "poker", "game_id": "poker", "active": true, "round": 1}
	var poker_command := HostTransactionScript.game_command("poker", "poker", "poker_table", "poker:bar_visit_7:table_context_11:hand_1", context, HostTransactionScript.state_digest({"producer_id": "poker", "game_id": "poker", "active": true, "round": 0}), poker_replacement, {
		"account_ops": [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": 95, "account_after": 98, "delta": 3, "reason": "winnings"}],
		"trust_ops": [{"subject_id": "crew_rook", "before": 0, "after": 1, "delta": 1, "reason": "clean_play"}],
		"tell_ops": [{"pattern_id": "crew_rook:dealer_nervous", "before": 0, "after": 1, "delta": 1, "reason": "observed"}],
	})
	var poker_transaction := HostTransactionScript.reduce_game_command(state, poker_command)
	var poker_committed := HostTransactionScript.commit_game_command(state, poker_transaction)
	if not bool(poker_committed.get("ok", false)):
		failures.append("Poker producer could not atomically commit its bankroll and Crew effects: %s" % JSON.stringify(poker_committed.get("errors", [])))
		return
	state = _dict(poker_committed.get("state", {}))
	if int(_dict(_dict(state.get("accounts", {})).get("player_bankroll", {})).get("balance", 0)) != 98 or int(_dict(state.get("trust", {})).get("crew_rook", 0)) != 1 or int(_dict(state.get("tells", {})).get("crew_rook:dealer_nervous", 0)) != 1 or int(_dict(_dict(state.get("table_states", {})).get("poker_table", {})).get("round", 0)) != 1:
		failures.append("Poker transaction did not atomically commit table/bankroll/trust/tell effects.")
	var craps_trust := HostTransactionScript.game_command("craps", "craps", "craps_table", "craps:bar_visit_7:table_context_11:trust", context, HostTransactionScript.state_digest(replacement), replacement, {"trust_ops": [{"subject_id": "crew_rook", "before": 1, "after": 2, "delta": 1, "reason": "hostile"}]})
	if bool(HostTransactionScript.reduce_game_command(state, craps_trust).get("ok", true)):
		failures.append("Craps producer was allowed to author Crew trust effects.")
	var poker_chips := HostTransactionScript.game_command("poker", "poker", "poker_table", "poker:bar_visit_7:table_context_11:chips", context, HostTransactionScript.state_digest(poker_replacement), poker_replacement, {"account_ops": [{"account_id": "grand_casino_chips", "fund_domain": "chips", "account_before": 50, "account_after": 51, "delta": 1, "reason": "hostile"}]})
	if bool(HostTransactionScript.reduce_game_command(state, poker_chips).get("ok", true)):
		failures.append("Poker producer was allowed to mutate casino chips with a matching before value.")
	var foreign_table := HostTransactionScript.game_command("poker", "poker", "craps_table", "poker:bar_visit_7:table_context_11:foreign_table", context, HostTransactionScript.state_digest(replacement), {"producer_id": "poker", "game_id": "poker", "active": true, "round": 2})
	if bool(HostTransactionScript.reduce_game_command(state, foreign_table).get("ok", true)):
		failures.append("Poker producer was allowed to replace a Craps-owned table.")
	var casino_replacement := {"producer_id": "craps", "game_id": "craps", "active": true, "round": 1, "prepared_account_id": "grand_casino_chips"}
	var casino_valid := HostTransactionScript.game_command("craps", "craps", "casino_craps_table", "craps:bar_visit_7:table_context_11:casino_valid", context, HostTransactionScript.state_digest({"producer_id": "craps", "game_id": "craps", "active": true, "round": 0, "prepared_account_id": "grand_casino_chips"}), casino_replacement, {"account_ops": [{"account_id": "grand_casino_chips", "fund_domain": "chips", "account_before": 50, "account_after": 49, "delta": -1, "reason": "casino_stake"}]})
	if not bool(HostTransactionScript.reduce_game_command(state, casino_valid).get("ok", false)):
		failures.append("Casino Craps could not use its prepared chip account.")
	var no_op_switch := HostTransactionScript.game_command("craps", "craps", "casino_craps_table", "craps:bar_visit_7:table_context_11:no_op_switch", context, HostTransactionScript.state_digest({"producer_id": "craps", "game_id": "craps", "active": true, "round": 0, "prepared_account_id": "grand_casino_chips"}), {"producer_id": "craps", "game_id": "craps", "active": true, "round": 1, "prepared_account_id": "player_bankroll"})
	if bool(HostTransactionScript.reduce_game_command(state, no_op_switch).get("ok", true)):
		failures.append("A no-op Craps replacement switched its future prepared account authority.")
	var after_switch_charge := HostTransactionScript.game_command("craps", "craps", "casino_craps_table", "craps:bar_visit_7:table_context_11:after_switch_charge", context, HostTransactionScript.state_digest({"producer_id": "craps", "game_id": "craps", "active": true, "round": 0, "prepared_account_id": "grand_casino_chips"}), casino_replacement, {"account_ops": [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": 98, "account_after": 97, "delta": -1, "reason": "hostile_followup"}]})
	if bool(HostTransactionScript.reduce_game_command(state, after_switch_charge).get("ok", true)):
		failures.append("Craps gained bankroll authority after a rejected no-op account switch.")
	var switched_account := HostTransactionScript.game_command("craps", "craps", "casino_craps_table", "craps:bar_visit_7:table_context_11:switch_account", context, HostTransactionScript.state_digest({"producer_id": "craps", "game_id": "craps", "active": true, "round": 0, "prepared_account_id": "grand_casino_chips"}), {"producer_id": "craps", "game_id": "craps", "active": true, "round": 1, "prepared_account_id": "player_bankroll"}, {"account_ops": [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": 98, "account_after": 97, "delta": -1, "reason": "hostile_switch"}]})
	if bool(HostTransactionScript.reduce_game_command(state, switched_account).get("ok", true)):
		failures.append("Craps replacement switched its prepared account before authorization.")
	var transaction_bypass := HostTransactionScript.reduce_game_command(state, HostTransactionScript.game_command("craps", "craps", "craps_table", "craps:bar_visit_7:table_context_11:transaction_bypass", context, HostTransactionScript.state_digest(replacement), {"producer_id": "craps", "game_id": "craps", "active": true, "round": 2}))
	if not bool(transaction_bypass.get("ok", false)):
		failures.append("Valid reducer baseline failed before transaction-path producer validation.")
		return
	transaction_bypass["trust_ops"] = [{"subject_id": "crew_rook", "before": 1, "after": 2, "delta": 1, "reason": "post_reduce_injection"}]
	transaction_bypass["fingerprint"] = HostTransactionScript._transaction_fingerprint(transaction_bypass)
	var before_bypass := JSON.stringify(state)
	var bypass_result := HostTransactionScript.commit_game_command(state, transaction_bypass)
	if bool(bypass_result.get("ok", true)) or JSON.stringify(bypass_result.get("state", {})) != before_bypass:
		failures.append("Transaction-path producer validation accepted injected Craps trust effects.")
	var partial := HostTransactionScript.reduce_game_command(state, HostTransactionScript.game_command("craps", "craps", "craps_table", "craps:bar_visit_7:table_context_11:partial", context, HostTransactionScript.state_digest(replacement), {"producer_id": "craps", "game_id": "craps", "active": true, "round": 2}, {"account_ops": [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": 98, "account_after": 97, "delta": -1, "reason": "stake"}]}))
	if not bool(partial.get("ok", false)):
		failures.append("Valid reducer baseline failed before post-reduction fingerprint tampering test.")
		return
	partial["account_ops"] = [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": 98, "account_after": -901, "delta": -999, "reason": "hostile"}]
	var before_partial := JSON.stringify(state)
	var partial_result := HostTransactionScript.commit_game_command(state, partial)
	if bool(partial_result.get("ok", true)) or JSON.stringify(partial_result.get("state", {})) != before_partial:
		failures.append("Hostile post-reduction transaction tampering changed canonical state.")
	var mixed := HostTransactionScript.game_command("craps", "craps", "craps_table", "craps:bar_visit_7:table_context_11:mixed", context, HostTransactionScript.state_digest(replacement), replacement, {"account_ops": [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": 98, "account_after": 97, "delta": -1, "reason": "bankroll"}, {"account_id": "grand_casino_chips", "fund_domain": "chips", "account_before": 50, "account_after": 51, "delta": 1, "reason": "chips"}]})
	if bool(HostTransactionScript.reduce_game_command(state, mixed).get("ok", true)):
		failures.append("Game command reducer accepted mixed account domains.")
	var wrong_lease := HostTransactionScript.game_command("poker", "poker", "poker_table", "poker:bar_visit_7:table_context_11:wrong_lease", context, HostTransactionScript.state_digest(poker_replacement), poker_replacement, {"rng_updates": [{"lease_id": "craps_throw_main", "owner_id": "craps_throw", "before_state": 21, "after_state": 22, "receipt_id": "poker:bar_visit_7:table_context_11:wrong_lease"}]})
	if bool(HostTransactionScript.reduce_game_command(state, wrong_lease).get("ok", true)):
		failures.append("Game command reducer accepted another consumer's RNG lease.")
	var missing_context := command.duplicate(true)
	missing_context["receipt_id"] = "craps:bar_visit_7:table_context_11:missing_context"
	missing_context["context"].erase("environment_visit_id")
	if bool(HostTransactionScript.reduce_game_command(state, missing_context).get("ok", true)):
		failures.append("Game command normalized before public persisted context IDs were injected.")
	var room_mutation := command.duplicate(true)
	room_mutation["receipt_id"] = "craps:bar_visit_7:table_context_11:room_mutation"
	room_mutation["room_ops"] = [{"remove": "craps_table"}]
	if bool(HostTransactionScript.reduce_game_command(state, room_mutation).get("ok", true)):
		failures.append("Game command was allowed to mutate runtime-owned room records.")
	var bad_serial_request := HostTransactionScript.prepared_request("bad_serial", "travel", "craps_table", context, HostTransactionScript.state_digest(replacement), 1, 3, 3, {"target_node_id": "motel_node"})
	var travel_command := HostTransactionScript.game_command("craps", "craps", "craps_table", "craps:bar_visit_7:table_context_11:travel", context, HostTransactionScript.state_digest(replacement), replacement)
	var hooked := HostTransactionScript.pre_travel_hook(travel_command, bad_serial_request)
	if not bool(hooked.get("ok", false)) or bool(HostTransactionScript.reduce_game_command(state, _dict(hooked.get("command", {}))).get("ok", true)):
		failures.append("Pre-travel hook bypassed the prepared-request delivery protocol.")
	var corrupt_order := state.duplicate(true)
	corrupt_order["fact_queue"][0]["commit_order"] = 0
	if bool(HostTransactionScript.flush_game_facts(corrupt_order, 1).get("ok", true)):
		failures.append("Safe-boundary GameFact flush accepted out-of-order host commit state.")
	var flushed := HostTransactionScript.flush_game_facts(state, 1)
	if not bool(flushed.get("ok", false)) or _array(flushed.get("processed", [])).size() != 1:
		failures.append("Typed GameFact did not flush once at its safe boundary.")
		return
	state = _dict(flushed.get("state", {}))
	var deferred := HostTransactionScript.respond_to_prepared_request(state, "sweep_interrupt_1", "defer", "game:bar_visit_7:sweep_interrupt_1:defer", int(state.get("revision", 0)), HostTransactionScript.state_digest(state))
	if not bool(deferred.get("ok", false)):
		failures.append("Prepared interruption could not be deferred without removing its live table.")
		return
	state = _dict(deferred.get("state", {}))
	var accepted := HostTransactionScript.respond_to_prepared_request(state, "sweep_interrupt_1", "accept", "game:bar_visit_7:sweep_interrupt_1:accept", int(state.get("revision", 0)), HostTransactionScript.state_digest(state))
	if not bool(accepted.get("ok", false)):
		failures.append("Deferred interruption could not later be accepted.")
		return
	state = _dict(accepted.get("state", {}))
	var early_runtime := HostTransactionScript.apply_prepared_request_runtime(state, "sweep_interrupt_1", "runtime:bar_visit_7:sweep_interrupt_1:early", int(state.get("revision", 0)), HostTransactionScript.state_digest(state))
	if bool(early_runtime.get("ok", true)) or not bool(_dict(_dict(state.get("table_states", {})).get("craps_table", {})).get("active", false)):
		failures.append("Interruption applied runtime state before economics/game unwind or hid the live table first.")
	var wrong_economy := HostTransactionScript.complete_prepared_request_economy(state, "sweep_interrupt_1", [{"account_id": "grand_casino_chips", "fund_domain": "chips", "account_before": 50, "account_after": 49, "delta": -1, "reason": "hostile_fee"}], "economy:bar_visit_7:sweep_interrupt_1:wrong_account", int(state.get("revision", 0)), HostTransactionScript.state_digest(state))
	if bool(wrong_economy.get("ok", true)):
		failures.append("Prepared interruption economics mutated an account outside the stored request binding.")
	var economic := HostTransactionScript.complete_prepared_request_economy(state, "sweep_interrupt_1", [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": 98, "account_after": 96, "delta": -2, "reason": "sweep_fee"}], "economy:bar_visit_7:sweep_interrupt_1:complete", int(state.get("revision", 0)), HostTransactionScript.state_digest(state))
	if not bool(economic.get("ok", false)):
		failures.append("Accepted interruption could not complete its economic receipt.")
		return
	state = _dict(economic.get("state", {}))
	var before_unwind := HostTransactionScript.apply_prepared_request_runtime(state, "sweep_interrupt_1", "runtime:bar_visit_7:sweep_interrupt_1:before_unwind", int(state.get("revision", 0)), HostTransactionScript.state_digest(state))
	if bool(before_unwind.get("ok", true)):
		failures.append("Interruption applied before the game published its unwind acknowledgement.")
	var unwound := HostTransactionScript.acknowledge_prepared_request_unwound(state, "sweep_interrupt_1", {"producer_id": "craps", "game_id": "craps", "active": false, "round": 1, "unwound": true}, "game:bar_visit_7:sweep_interrupt_1:unwound", int(state.get("revision", 0)), HostTransactionScript.state_digest(state))
	if not bool(unwound.get("ok", false)):
		failures.append("Game could not acknowledge unwind after economic completion.")
		return
	state = _dict(unwound.get("state", {}))
	var runtime_applied := HostTransactionScript.apply_prepared_request_runtime(state, "sweep_interrupt_1", "runtime:bar_visit_7:sweep_interrupt_1:applied", int(state.get("revision", 0)), HostTransactionScript.state_digest(state))
	if not bool(runtime_applied.get("ok", false)) or str(_dict(_dict(_dict(runtime_applied.get("state", {})).get("prepared_requests", {})).get("sweep_interrupt_1", {})).get("status", "")) != "applied":
		failures.append("Prepared interruption did not reach runtime-applied acknowledgement after unwind.")
	_check_run_state_host_transaction_facade(failures)


static func _check_run_state_host_transaction_facade(failures: Array) -> void:
	var run_state := RunState.new()
	run_state.start_new("HOST-FACADE-SEED")
	run_state.set_environment({"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node", "game_states": {
		"craps_table": {"producer_id": "craps", "game_id": "craps", "active": true, "round": 0},
		"poker_table": {"producer_id": "poker", "game_id": "poker", "active": true, "round": 0},
	}})
	var prepared_context := run_state.prepare_game_command_context("craps_table", "craps")
	if not bool(prepared_context.get("ok", false)):
		failures.append("Production RunState facade could not prepare public game context.")
		return
	var context := _dict(prepared_context.get("context", {}))
	for key in ["node_id", "environment_visit_id", "night_instance_id", "context_instance_id"]:
		if str(context.get(key, "")).is_empty():
			failures.append("Production RunState facade omitted persisted context key %s." % key)
	if bool(run_state.prepare_game_command_context("craps_table", "poker").get("ok", true)):
		failures.append("Production RunState facade prepared a Poker context for a Craps-owned table.")
	var owned_leases := _array(context.get("rng_leases", []))
	if owned_leases.size() != 2 or int(_dict(owned_leases[0]).get("current_state", 0)) == int(_dict(owned_leases[1]).get("current_state", 0)):
		failures.append("Production RunState facade did not derive distinct deterministic consumer RNG streams.")
		return
	var same_seed := RunState.new()
	same_seed.start_new("HOST-FACADE-SEED")
	same_seed.set_environment({"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node", "game_states": {
		"craps_table": {"producer_id": "craps", "game_id": "craps", "active": true, "round": 0},
		"poker_table": {"producer_id": "poker", "game_id": "poker", "active": true, "round": 0},
	}})
	var same_context := same_seed.prepare_game_command_context("craps_table", "craps")
	if JSON.stringify(_array(_dict(same_context.get("context", {})).get("rng_leases", []))) != JSON.stringify(owned_leases):
		failures.append("Same-seed RunState facades derived different consumer RNG leases.")
	var poker_prepared := run_state.prepare_game_command_context("poker_table", "poker")
	var poker_owned_leases := _array(_dict(poker_prepared.get("context", {})).get("rng_leases", []))
	var poker_streams: Dictionary = {}
	var poker_states: Dictionary = {}
	for lease_value in poker_owned_leases:
		var lease := _dict(lease_value)
		poker_streams[str(lease.get("stream_id", ""))] = true
		poker_states[str(lease.get("current_state", ""))] = true
		if str(lease.get("owner_id", "")).begins_with("craps") or str(lease.get("owner_id", "")) == "scenario": failures.append("Production Poker context exposed a foreign lease.")
	if not bool(poker_prepared.get("ok", false)) or poker_owned_leases.size() != 8 or poker_streams.size() != 8 or poker_states.size() != 8:
		failures.append("Production RunState did not derive cards plus seven unique member-scoped Poker leases.")
		return
	var same_poker := same_seed.prepare_game_command_context("poker_table", "poker")
	if JSON.stringify(_array(_dict(same_poker.get("context", {})).get("rng_leases", []))) != JSON.stringify(poker_owned_leases):
		failures.append("Same-seed RunState facades derived different Poker policy leases.")
	var throw_lease: Dictionary = {}
	for lease_value in owned_leases:
		if str(_dict(lease_value).get("owner_id", "")) == "craps_throw": throw_lease = _dict(lease_value)
	var recovery_before := int(_dict(_dict(run_state.scenario_host_transaction_ledger.get("rng_leases", {})).get("craps_recovery_main", {})).get("current_state", 0))
	var replacement := {"producer_id": "craps", "game_id": "craps", "active": true, "round": 1}
	var request := HostTransactionScript.prepared_request("facade_interrupt", "interruption", "craps_table", context, HostTransactionScript.state_digest(replacement), 1, 1, 3, {"reason_id": "fixture_interrupt"})
	var fact := HostTransactionScript.game_fact("game_result", "craps", "craps", "craps_table", context, "craps:facade:roll:1", "scenario:facade:fact:1", 1, {"won": false})
	var command := HostTransactionScript.game_command("craps", "craps", "craps_table", "craps:facade:command:1", context, str(context.get("table_state_digest", "")), replacement, {
		"account_ops": [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": run_state.bankroll, "account_after": run_state.bankroll - 2, "delta": -2, "reason": "facade_stake"}],
		"facts": [fact],
		"rng_updates": [{"lease_id": str(throw_lease.get("lease_id", "")), "owner_id": "craps_throw", "before_state": throw_lease.get("current_state"), "after_state": int(throw_lease.get("current_state", 0)) + 1, "receipt_id": "craps:facade:command:1"}],
		"prepared_request": request,
	})
	var transaction := run_state.reduce_game_command_transaction(command)
	var tampered_transaction := transaction.duplicate(true)
	tampered_transaction["replacement_table_state"] = {"producer_id": "craps", "game_id": "craps", "active": true, "round": 99}
	var bankroll_before_tamper := run_state.bankroll
	if bool(run_state.commit_game_command(tampered_transaction).get("ok", true)) or run_state.bankroll != bankroll_before_tamper or int(_dict(_dict(run_state.current_environment.get("game_states", {})).get("craps_table", {})).get("round", 0)) != 0:
		failures.append("Production RunState accepted a post-reduction transaction mutation.")
	var committed := run_state.commit_game_command(transaction)
	if not bool(committed.get("ok", false)) or run_state.bankroll != RunState.DEFAULT_BANKROLL - 2 or int(_dict(_dict(run_state.current_environment.get("game_states", {})).get("craps_table", {})).get("round", 0)) != 1:
		failures.append("Production RunState facade did not atomically apply canonical game effects.")
		return
	if int(_dict(_dict(run_state.scenario_host_transaction_ledger.get("rng_leases", {})).get("craps_recovery_main", {})).get("current_state", 0)) != recovery_before:
		failures.append("Craps throw commit advanced an unrelated recovery RNG lease.")
	if not bool(run_state.commit_game_command(transaction).get("replayed", false)) or run_state.bankroll != RunState.DEFAULT_BANKROLL - 2:
		failures.append("Production RunState facade replay reapplied canonical effects.")
	var flushed := run_state.flush_game_facts_at_safe_boundary(1)
	if not bool(flushed.get("ok", false)) or _array(flushed.get("processed", [])).size() != 1:
		failures.append("Production RunState facade did not flush GameFacts at a safe boundary.")
		return
	var cas := run_state.game_command_cas_snapshot()
	var accepted := run_state.respond_to_prepared_game_request("facade_interrupt", "accept", "game:facade:interrupt:accept", int(cas.get("revision", -1)), str(cas.get("state_digest", "")))
	if not bool(accepted.get("ok", false)):
		failures.append("Production RunState facade could not accept a prepared interruption.")
		return
	cas = run_state.game_command_cas_snapshot()
	var chips_before_hostile_economy := run_state.grand_casino_chips
	var hostile_economy := run_state.complete_prepared_game_request_economy("facade_interrupt", [{"account_id": "grand_casino_chips", "fund_domain": "chips", "account_before": run_state.grand_casino_chips, "account_after": run_state.grand_casino_chips + 1, "delta": 1, "reason": "hostile"}], "economy:facade:interrupt:wrong_account", int(cas.get("revision", -1)), str(cas.get("state_digest", "")))
	if bool(hostile_economy.get("ok", true)) or run_state.grand_casino_chips != chips_before_hostile_economy:
		failures.append("Production prepared request mutated an account outside its stored binding.")
	cas = run_state.game_command_cas_snapshot()
	var economic := run_state.complete_prepared_game_request_economy("facade_interrupt", [{"account_id": "player_bankroll", "fund_domain": "bankroll", "account_before": run_state.bankroll, "account_after": run_state.bankroll - 1, "delta": -1, "reason": "facade_fee"}], "economy:facade:interrupt:complete", int(cas.get("revision", -1)), str(cas.get("state_digest", "")))
	if not bool(economic.get("ok", false)):
		failures.append("Production RunState facade could not complete prepared economics.")
		return
	cas = run_state.game_command_cas_snapshot()
	var unwound := run_state.acknowledge_prepared_game_unwound("facade_interrupt", {"producer_id": "craps", "game_id": "craps", "active": false, "round": 1}, "game:facade:interrupt:unwound", int(cas.get("revision", -1)), str(cas.get("state_digest", "")))
	if not bool(unwound.get("ok", false)):
		failures.append("Production RunState facade could not acknowledge game unwind.")
		return
	cas = run_state.game_command_cas_snapshot()
	if not bool(run_state.apply_prepared_game_request_runtime("facade_interrupt", "runtime:facade:interrupt:applied", int(cas.get("revision", -1)), str(cas.get("state_digest", ""))).get("ok", false)):
		failures.append("Production RunState facade did not complete the runtime-applied phase.")
	var save := run_state.to_dict()
	var restored := RunState.new()
	restored.from_dict(save)
	if restored.bankroll != run_state.bankroll or JSON.stringify(restored.scenario_host_transaction_ledger) != JSON.stringify(run_state.scenario_host_transaction_ledger) or save.has("accounts") or save.has("table_states"):
		failures.append("Production RunState facade did not persist only its receipt/fact/RNG/request ledger.")
	var restored_poker := restored.prepare_game_command_context("poker_table", "poker")
	if JSON.stringify(_array(_dict(restored_poker.get("context", {})).get("rng_leases", []))) != JSON.stringify(poker_owned_leases):
		failures.append("Save/reload changed the producer-owned Poker RNG lease projection.")


static func _finalization_definition() -> Dictionary:
	var definition := _runtime_definition()
	var sequence := _dict(definition.get("sequence", {}))
	sequence["declared_targets"] = {
		"scene_objects": ["game::game:slot"],
		"interactions": ["game::game:slot"],
		"actors": [],
		"services": ["service::house_drink"],
		"games": [],
		"routes": ["base::world:bar"],
		"anchors": ["base::anchor:bar_floor_100", "base::anchor:bar_actor"],
		"zones": [],
	}
	var aftermath := _dict(sequence.get("aftermath", {}))
	for outcome_id in ["repaired", "broken"]:
		var outcome := _dict(aftermath.get(outcome_id, {}))
		var scene_ops := _array(outcome.get("scene_ops", []))
		for operation_value in scene_ops:
			var operation := operation_value as Dictionary
			operation["owner_namespace"] = "game"
			operation["stable_object_id"] = "game:slot"
		outcome["scene_ops"] = scene_ops
		var route_ops := _array(outcome.get("route_ops", []))
		for operation_value in route_ops:
			var operation := operation_value as Dictionary
			operation["owner_namespace"] = "base"
			operation["stable_object_id"] = "world:bar"
		outcome["route_ops"] = route_ops
		aftermath[outcome_id] = outcome
	var refused := _dict(aftermath.get("refused", {}))
	refused["actor_ops"] = []
	var service_ops := _array(refused.get("service_ops", []))
	for operation_value in service_ops:
		var operation := operation_value as Dictionary
		operation["owner_namespace"] = "service"
		operation["stable_object_id"] = "house_drink"
	refused["service_ops"] = service_ops
	aftermath["refused"] = refused
	sequence["aftermath"] = aftermath
	definition["sequence"] = sequence
	definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(definition)
	return definition


static func _runtime_definition() -> Dictionary:
	var definition := _fixture_definition()
	var sequence := _dict(definition.get("sequence", {}))
	var graph := _dict(sequence.get("phase_graph", {}))
	var phases := _array(graph.get("phases", []))
	var arrival := _dict(phases[0])
	var interaction_op := _operation_fixture("interaction_ops", "add", 200)
	interaction_op["stable_object_id"] = "command_console"
	interaction_op["interaction"] = _interaction_record("scenario", "command_console", "Keep the exit clear", true)
	interaction_op["interaction"]["safe_exit"] = true
	interaction_op["interaction"]["available_actions"] = [
		{"id": "prepare", "label": "Brace the exit", "input_action": "confirm", "non_color_state": "ready", "cost": 2, "handler": "increment_local", "inputs": {"key": "pressure", "amount": 1}},
		{"id": "finish", "label": "Open the lane", "input_action": "confirm", "non_color_state": "ready", "cost": 4, "requires_objective_steps": [{"objective_id": "clear_exit", "step_id": "move_chair"}]},
	]
	arrival["interaction_ops"] = [interaction_op]
	arrival["branches"] = [{"id": "continue", "condition": {"type": "command", "command_id": "finish"}, "next_phase": "aftermath"}]
	arrival["advance_after_actions"] = 0
	phases[0] = arrival
	graph["phases"] = phases
	sequence["phase_graph"] = graph
	var cleanup := _dict(sequence.get("cleanup", {}))
	var cleanup_operations := _array(cleanup.get("operations", []))
	for cleanup_value in cleanup_operations:
		var cleanup_operation := cleanup_value as Dictionary
		if str(cleanup_operation.get("family", "")) == "interaction_ops" and str(cleanup_operation.get("stable_object_id", "")) == "fixture_100":
			cleanup_operation["stable_object_id"] = "command_console"
	cleanup["operations"] = cleanup_operations
	sequence["cleanup"] = cleanup
	sequence["objectives"] = [{"id": "clear_exit", "label": "Keep the exit clear", "progress_label": "Exit lane", "steps": [{"id": "move_chair", "label": "Move the chair", "kind": "command", "command_id": "prepare"}], "outcomes": ["success", "failure", "ignore", "cancel"]}]
	sequence["fact_subscriptions"] = [{"fact_type": "heat_changed", "handler": "set_local", "inputs": {"key": "pressure", "value_from_payload": "current"}}]
	definition["sequence"] = sequence
	definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(definition)
	return definition


static func _safe_early_cleanup_definition() -> Dictionary:
	var definition := _runtime_definition()
	var arrival := _dict(definition["sequence"]["phase_graph"]["phases"][0])
	arrival["terminal"] = true
	arrival["branches"] = [
		{"id": "finish_early", "condition": {"type": "always"}, "outcome": "repaired"},
		{"id": "break_early", "condition": {"type": "fact", "fact_type": "heat_changed"}, "outcome": "broken"},
		{"id": "refuse_early", "condition": {"type": "command", "command_id": "finish"}, "outcome": "refused"},
	]
	definition["sequence"]["phase_graph"]["phases"] = [arrival]
	var cleanup_operations := _array(definition["sequence"]["cleanup"].get("operations", []))
	for operation_index in range(cleanup_operations.size() - 1, -1, -1):
		var operation := _dict(cleanup_operations[operation_index])
		if str(operation.get("family", "")) == "interaction_ops" and str(operation.get("stable_object_id", "")) == "fixture_201":
			cleanup_operations.remove_at(operation_index)
	definition["sequence"]["cleanup"]["operations"] = cleanup_operations
	definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(definition)
	return definition


static func _cleanup_proof_fixture(phase_operation: Dictionary, target_collection: String, target_identity: String) -> Dictionary:
	var definition := _fixture_definition()
	var family := str(phase_operation.get("family", ""))
	definition["sequence"]["phase_graph"]["phases"][0][family].append(phase_operation.duplicate(true))
	var cleanup_operation := phase_operation.duplicate(true)
	cleanup_operation["receipt_id"] = "cleanup_proof_%s" % str(phase_operation.get("receipt_id", "operation"))
	definition["sequence"]["cleanup"]["operations"].append(cleanup_operation)
	definition["sequence"]["declared_targets"][target_collection].append(target_identity)
	definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(definition)
	var inventory := _fixture_target_inventory(definition)
	inventory[target_collection].append(target_identity)
	return {"definition": definition, "inventory": inventory}


static func _two_path_repaired_fixture() -> Dictionary:
	var definition := _fixture_definition()
	var alternate_interaction := _operation_fixture("interaction_ops", "add", 220)
	alternate_interaction["stable_object_id"] = "fixture_201"
	alternate_interaction["interaction"] = _interaction_record("scenario", "fixture_201", "Fixture interaction", true)
	alternate_interaction["interaction"]["safe_exit"] = true
	var alternate := {
		"id": "alternate",
		"label": "Alternate cleanup",
		"arrival_feedback": "The room takes the other lane.",
		"exit_prompt": "The alternate exit remains readable.",
		"terminal": true,
		"entry_conditions": [],
		"objective_ids": [],
		"advance_after_actions": 0,
		"scene_ops": [],
		"interaction_ops": [alternate_interaction],
		"actor_ops": [],
		"transition_ops": [],
		"branches": [{"id": "finish_alternate", "condition": {"type": "always"}, "outcome": "repaired"}],
	}
	definition["sequence"]["phase_graph"]["phases"].append(alternate)
	definition["sequence"]["phase_graph"]["phases"][0]["branches"].append({"id": "alternate_path", "condition": {"type": "fact", "fact_type": "heat_changed"}, "next_phase": "alternate"})
	definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(definition)
	return definition


static func _path_explosion_fixture() -> Dictionary:
	var definition := _fixture_definition()
	var phases: Array = []
	for phase_index in range(5):
		var terminal := phase_index == 4
		var branches: Array = []
		if terminal:
			branches = [
				{"id": "explosion_repaired", "condition": {"type": "always"}, "outcome": "repaired"},
				{"id": "explosion_broken", "condition": {"type": "fact", "fact_type": "heat_changed"}, "outcome": "broken"},
				{"id": "explosion_refused", "condition": {"type": "command", "command_id": "refuse"}, "outcome": "refused"},
			]
		else:
			for branch_index in range(8):
				branches.append({"id": "explosion_%d_%d" % [phase_index, branch_index], "condition": {"type": "always"}, "next_phase": "explosion_%d" % (phase_index + 1)})
		phases.append({
			"id": "explosion_%d" % phase_index,
			"label": "Path explosion %d" % phase_index,
			"arrival_feedback": "The path proof enters another bounded phase.",
			"exit_prompt": "The authored exit remains explicit.",
			"terminal": terminal,
			"entry_conditions": [],
			"objective_ids": [],
			"advance_after_actions": 0,
			"scene_ops": [],
			"interaction_ops": [],
			"actor_ops": [],
			"transition_ops": [],
			"branches": branches,
		})
	definition["sequence"]["phase_graph"] = {"initial_phase": "explosion_0", "phases": phases}
	definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(definition)
	return definition


static func _fact_payload(fact_type: String) -> Dictionary:
	match fact_type:
		"game_result": return {"game_id": "blackjack", "action_id": "hit", "won": true, "ended": false, "bankroll_delta": 2, "chips_delta": 0, "applied_heat_delta": 0}
		"event_result": return {"event_id": "fixture_event", "choice_id": "leave", "resolved": false, "ok": true}
		"service_result": return {"kind": "service", "service_id": "fixture_service", "ok": true, "action_id": "use"}
		"travel_departed", "travel_arrived": return {"source_id": "bar_node", "target_id": "motel_node", "travel_kind": "world"}
		"crew_changed": return {"member_id": "crew_switch", "change": "trust", "value": 2}
		"crew_job_changed": return {"job_id": "job_1", "status": "active"}
		"heat_changed": return {"previous": 2, "current": 4, "applied_delta": 2, "source": "fixture"}
		"heat_band_changed": return {"previous_band": "quiet", "current_band": "caution", "current": 25, "source": "fixture"}
		"town_transition": return {"action_index": 3, "weather": "rain", "day_type": "weeknight", "happening_ids": ["roadwork"]}
		"sweep_changed": return {"action_index": 3, "node_id": "motel_node", "segment_index": 1, "active": true}
		"world_boundary": return {"amount": 1, "action_index": 3}
		"scenario_command": return {"command_id": "prepare", "receipt_id": "command:prepare:1"}
	return {}


static func _fixture_definition() -> Dictionary:
	var definition := {
		"id": "sequence_fixture",
		"archetype_id": "bar",
		"display_name": "Sequence Fixture",
		"sequence": {
			"schema_version": 2,
			"local_state_schema": {
				"pressure": {"type": "int", "default": 0, "min": 0, "max": 5},
				"protected_exit": {"type": "bool", "default": false},
				"side": {"type": "enum", "default": "none", "values": ["none", "left", "right"]},
			},
			"phase_graph": {
				"initial_phase": "arrival",
				"phases": [
					{
						"id": "arrival", "label": "Warning", "arrival_feedback": "Chairs scrape away from a forming ring.", "exit_prompt": "The front door remains readable.",
						"entry_conditions": [{"type": "always"}], "objective_ids": ["clear_exit"], "advance_after_actions": 2,
						"scene_ops": [_operation_fixture("scene_ops", "spawn", 100)],
						"interaction_ops": [_operation_fixture("interaction_ops", "add", 100)],
						"actor_ops": [_operation_fixture("actor_ops", "spawn", 100)],
						"transition_ops": [_operation_fixture("transition_ops", "feedback", 100)],
						"branches": [{"id": "continue", "condition": {"type": "command", "command_id": "protect_exit"}, "next_phase": "aftermath"}],
					},
					{
						"id": "aftermath", "label": "Cleanup", "arrival_feedback": "The lane opens again.", "exit_prompt": "Leave through the clear front door.", "terminal": true,
						"entry_conditions": [], "objective_ids": [], "advance_after_actions": 0, "scene_ops": [], "interaction_ops": [_operation_fixture("interaction_ops", "add", 201)], "actor_ops": [], "transition_ops": [],
						"branches": [
							{"id": "finish", "condition": {"type": "always"}, "outcome": "repaired"},
							{"id": "break", "condition": {"type": "fact", "fact_type": "heat_changed"}, "outcome": "broken"},
							{"id": "refuse", "condition": {"type": "command", "command_id": "refuse"}, "outcome": "refused"},
						],
					},
				],
			},
			"objectives": [{"id": "clear_exit", "label": "Keep the exit clear", "progress_label": "Exit lane", "steps": [{"id": "move_chair", "label": "Move the chair", "kind": "command", "command_id": "protect_exit"}], "outcomes": ["success", "failure", "ignore", "cancel"]}],
			"reentry_policy": {"partial": "resume", "terminal": "aftermath", "expired": "expired"},
			"expiry": {"boundary": "night_end", "after": 1, "policy": "ignore"},
			"cleanup": {"operations": [
				{"family": "scene_ops", "op": "remove", "receipt_id": "cleanup_scene_fixture", "owner_namespace": "scenario", "stable_object_id": "fixture_100"},
				{"family": "interaction_ops", "op": "remove", "receipt_id": "cleanup_interaction_fixture", "owner_namespace": "scenario", "stable_object_id": "fixture_100"},
				{"family": "actor_ops", "op": "despawn", "receipt_id": "cleanup_actor_fixture", "owner_namespace": "scenario", "stable_object_id": "fixture_100"},
				{"family": "interaction_ops", "op": "remove", "receipt_id": "cleanup_terminal_interaction", "owner_namespace": "scenario", "stable_object_id": "fixture_201"},
			]},
			"aftermath": {
				"repaired": {"label": "Repaired", "revisit_feedback": "The chair is back in place.", "scene_ops": [_operation_fixture("scene_ops", "set_state", 101)], "route_ops": [_operation_fixture("route_ops", "open", 101)]},
				"broken": {"label": "Broken", "revisit_feedback": "A broken chair marks the fight.", "scene_ops": [_operation_fixture("scene_ops", "set_appearance", 102)], "route_ops": [_operation_fixture("route_ops", "close", 102)]},
				"refused": {"label": "Refused", "revisit_feedback": "The staff keep their distance.", "actor_ops": [_operation_fixture("actor_ops", "set_pose", 103)], "service_ops": [_operation_fixture("service_ops", "gate", 103)]},
			},
			"declared_targets": {
				"scene_objects": ["scenario::fixture_101", "scenario::fixture_102"],
				"interactions": [],
				"actors": ["scenario::fixture_103"],
				"services": ["scenario::fixture_103"],
				"games": [],
				"routes": ["scenario::fixture_101", "scenario::fixture_102"],
				"anchors": ["base::anchor:bar_floor_100", "base::anchor:bar_actor"],
				"zones": [],
			},
			"mechanic_tags": ["room_route", "multi_step"],
			"sequence_signature": "",
			"owner_exceptions": [],
			"fact_subscriptions": ["event_result", "travel_departed", "heat_changed"],
		},
	}
	definition["sequence"]["phase_graph"]["phases"][0]["interaction_ops"][0]["interaction"]["safe_exit"] = true
	definition["sequence"]["phase_graph"]["phases"][1]["interaction_ops"][0]["interaction"]["safe_exit"] = true
	definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(definition)
	return definition


static func _operation_semantic_seed() -> Dictionary:
	var declared := {"scene_objects": [], "interactions": [], "actors": [], "services": [], "games": [], "routes": [], "anchors": [], "zones": []}
	# Spawn/add fixture_0 is scenario-created and therefore must not already be
	# present in the exact host inventory. Every reducer target after index zero
	# is an existing authorized identity.
	for index in range(1, 10):
		declared["scene_objects"].append("scenario::fixture_%d" % index)
	for index in range(1, 6):
		declared["actors"].append("scenario::fixture_%d" % index)
	for index in range(1, 4):
		declared["services"].append("scenario::fixture_%d" % index)
		declared["games"].append("scenario::fixture_%d" % index)
	for index in range(4):
		declared["routes"].append("scenario::fixture_%d" % index)
	declared["routes"].append("base::world:bar_route")
	for index in range(2, 6):
		declared["interactions"].append("base::fixture_target_%d" % index)
	for index in range(24):
		declared["anchors"].append("base::anchor:bar_floor_%d" % index)
		declared["anchors"].append("base::anchor:bar_actor_%d" % index)
	declared["anchors"].append("base::anchor:bar_actor")
	return {
		"scene_objects": {"scenario::fixture_1": {"owner_namespace": "scenario", "stable_object_id": "fixture_1"}},
		"interactions": {"scenario::fixture_1": _interaction_record("scenario", "fixture_1", "Existing", true)},
		"actors": {"scenario::fixture_1": {"owner_namespace": "scenario", "stable_object_id": "fixture_1"}},
		"services": {"scenario::fixture_1": {"owner_namespace": "scenario", "stable_object_id": "fixture_1"}},
		"games": {"scenario::fixture_1": {"owner_namespace": "scenario", "stable_object_id": "fixture_1"}},
		"declared_targets": declared,
		"target_inventory": declared.duplicate(true),
	}


static func _fixture_target_inventory(_definition: Dictionary) -> Dictionary:
	return {
		"scene_objects": ["scenario::fixture_101", "scenario::fixture_102"],
		"interactions": [],
		"actors": ["scenario::fixture_103"],
		"services": ["scenario::fixture_103"],
		"games": [],
		"routes": ["scenario::fixture_101", "scenario::fixture_102"],
		"anchors": ["base::anchor:bar_floor_100", "base::anchor:bar_actor"],
		"zones": [],
		"event_choices": {"fixture_event": ["leave"]},
	}


static func _fixture_host_semantics(definition: Dictionary) -> Dictionary:
	var inventory := _fixture_target_inventory(definition)
	return {"target_inventory": inventory, "inventory_schema_version": 1, "inventory_digest": SequenceSchemaScript.calculated_signature_hash(definition), "inventory_errors": [], "base_interactions": [], "event_choices": _dict(inventory.get("event_choices", {}))}


static func _runtime_command(state: Dictionary, definition: Dictionary, command_id: String, node_id: String, phase_id: String, receipt_id: String, payload: Dictionary = {}, owner_namespace: String = "scenario", stable_object_id: String = "sequence") -> Dictionary:
	var descriptor := SequenceRuntimeScript._command_descriptor(state, definition, owner_namespace, stable_object_id, command_id)
	return SequenceRuntimeScript.command(
		command_id,
		node_id,
		phase_id,
		receipt_id,
		payload,
		owner_namespace,
		stable_object_id,
		str(descriptor.get("action_origin_owner_namespace", owner_namespace)),
		str(descriptor.get("action_origin_stable_object_id", stable_object_id)),
		str(descriptor.get("action_origin_receipt_key", "")),
		str(descriptor.get("action_origin_boundary_id", "")),
		str(descriptor.get("action_origin_fingerprint", "")),
	)


static func _operation_fixture(family: String, op_id: String, index: int) -> Dictionary:
	var stable_id := "fixture_%d" % index
	var operation := {"family": family, "op": op_id, "receipt_id": "%s_%s_%d" % [family.trim_suffix("_ops"), op_id, index], "owner_namespace": "scenario", "stable_object_id": stable_id}
	match family:
		"scene_ops":
			if op_id in ["spawn", "replace"]:
				operation["object"] = {"label": "Fixture prop", "role": "obstacle", "anchor_id": "bar_floor_%d" % index, "bounds": {"w": 48, "h": 48}, "visible": true, "enabled": true}
			elif op_id == "move": operation["anchor_id"] = "bar_floor_%d" % (index + 1)
			elif op_id == "disable": operation["disabled_reason"] = "Blocked by the fixture."
			elif op_id == "set_state": operation["state"] = "ready"
			elif op_id == "set_appearance": operation["appearance"] = "scuffed"
		"interaction_ops":
			if op_id in ["add", "replace"]:
				operation["interaction"] = _interaction_record("scenario", stable_id, "Fixture interaction", true)
			if not ["add", "remove"].has(op_id):
				operation["mode"] = op_id
				operation["target_owner_namespace"] = "base"
				operation["target_stable_object_id"] = "fixture_target_%d" % index
			if op_id == "gate":
				operation["enabled"] = false
				operation["disabled_reason"] = "Blocked by the fixture."
			elif op_id == "retarget": operation["source_id"] = "fixture_source"
			elif op_id == "augment": operation["available_actions"] = [{"id": "fixture_action", "label": "Act", "input_action": "confirm", "non_color_state": "ready"}]
		"actor_ops":
			if op_id == "spawn":
				operation["actor"] = {"label": "Fixture actor", "actor_id": "actor_fixture", "anchor_id": "bar_actor", "behavior": "idle"}
			elif op_id == "set_position": operation["anchor_id"] = "bar_actor_%d" % index
			elif op_id == "set_route": operation["route_id"] = "base::world:bar_route"
			elif op_id == "set_pose": operation["pose"] = "brace"
			elif op_id == "set_behavior": operation["behavior"] = "watch"
		"transition_ops":
			operation["channel"] = "room"
			if op_id in ["sound", "music"]: operation["cue_id"] = "fixture_cue"
			elif op_id == "stage":
				operation["message"] = "The room changes."
				operation["stage_id"] = "fixture_stage"
				operation["duration_boundaries"] = 1
				operation["reduced_motion_message"] = "The room changes without motion."
			elif op_id == "scene_change":
				operation["message"] = "The room changes."
				operation["change_id"] = "fixture_change"
			elif op_id == "feedback": operation["message"] = "The room changes."
		"service_ops", "game_ops":
			if op_id in ["add", "replace"]:
				operation["object"] = {"id": stable_id, "label": "Fixture"}
			elif op_id == "gate":
				operation["enabled"] = false
				operation["disabled_reason"] = "Closed by the fixture."
			elif family == "game_ops" and op_id == "set_modifier": operation["modifier"] = {"tone": "tense"}
		"route_ops":
			if op_id == "close": operation["disabled_reason"] = "The fixture closes this route."
			elif op_id == "gate":
				operation["enabled"] = false
				operation["disabled_reason"] = "The fixture gates this route."
			elif op_id == "retarget": operation["source_id"] = "alternate_exit"
	return operation


static func _interaction_record(owner: String, stable_id: String, label: String, enabled: bool) -> Dictionary:
	return {
		"owner_namespace": owner,
		"stable_object_id": stable_id,
		"presentation_object_id": "%s::%s" % [owner, stable_id] if owner == "scenario" else stable_id,
		"label": label,
		"state_label": "Available" if enabled else "Blocked",
		"prompt": "Choose an action.",
		"enabled": enabled,
		"disabled_reason": "Blocked." if not enabled else "",
		"available_actions": [{"id": "use", "label": "Use", "input_action": "confirm", "non_color_state": "ready"}] if enabled else [],
		"input_actions": ["confirm"],
		"non_color_state": "open" if enabled else "closed",
		"focus_order": 0,
		"hit_bounds": {"w": 48, "h": 48},
		"normalized_hit_rect": {"x": 0.1, "y": 0.1, "w": 0.12, "h": 0.18},
		"min_target_size": 44,
		"safe_exit": stable_id.contains("exit"),
	}


static func _presentation_record(object_id: String, object_type: String, source_id: String, rect: Rect2, enabled: bool = true, actions: Array = [{"id": "enter_game", "label": "Enter"}]) -> Dictionary:
	return EnvironmentInteractionViewModelScript.make_interactable_object({
		"object_id": object_id,
		"object_type": object_type,
		"source_id": source_id,
		"interactive": true,
		"label": object_id,
		"prompt": "Choose an action.",
		"enabled": enabled,
		"disabled_reason": "Closed." if not enabled else "",
		"available_actions": actions if enabled else [],
		"focus_rect": rect,
	}, {})


static func _contains_text(values: Array, needle: String) -> bool:
	for value in values:
		if str(value).contains(needle):
			return true
	return false


static func _without_transition_queue(state_value: Dictionary) -> Dictionary:
	var state := state_value.duplicate(true)
	var semantic := _dict(state.get("semantic_state", {}))
	semantic["transition_queue"] = []
	state["semantic_state"] = semantic
	return state


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
