extends RefCounted

const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const SequenceCatalogScript := preload("res://scripts/core/scenario_sequence_catalog.gd")
const SequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const SequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const HostTransactionScript := preload("res://scripts/core/scenario_host_transaction.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const ScenarioLayoutResolverScript := preload("res://scripts/core/scenario_layout_resolver.gd")
const ScenarioExtensionDispatchScript := preload("res://scripts/core/scenario_extension_dispatch.gd")
const ScenarioSequenceAuditScript := preload("res://tools/scenario_sequence_audit.gd")
const ScenarioSequenceProbeSupportScript := preload("res://tools/scenario_sequence_probe_support.gd")
const ScenarioPresentationContractScript := preload("res://scripts/tests/foundation/scenario_presentation_contract.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const SaveServiceScript := preload("res://scripts/core/save_service.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const DELIVERY_SCENARIO_ID := "corner_store_delivery_day"
const DELIVERY_NODE_ID := "corner_store_delivery_day_node"
const DELIVERY_EVENT_ID := "scenario_delivery_day_stock"
const DELIVERY_RESOLUTION_ID := "clear_the_aisle"
const EnvironmentSemanticInventoryScript := preload("res://scripts/core/environment_semantic_inventory.gd")
const EnvironmentBaseSemanticRecordsScript := preload("res://scripts/core/environment_base_semantic_records.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RolloutManifestScript := preload("res://scripts/core/scenario_sequence_rollout_manifest.gd")
const EnvironmentInteractionViewModelScript := preload("res://scripts/ui/environment_interaction_view_model.gd")
const EnvironmentInteractionControllerScript := preload("res://scripts/ui/environment_interaction_controller.gd")
const CoachOverlayScript := preload("res://scripts/ui/coach_overlay.gd")
const TalkDockScript := preload("res://scripts/ui/talk_dock.gd")
const PixelSceneCanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")


class LifecycleFixtureGame:
	extends GameModule

	func _init() -> void:
		definition = {"id": "lifecycle_fixture_game", "display_name": "Lifecycle Fixture", "family": "slot", "legal_actions": [], "cheat_actions": []}


class LifecycleRejectingGenerator:
	extends RunGenerator

	var reject_layer := false
	var reject_room := false
	var install_world_destination := false
	var unrelated_tween_host: Node
	var unrelated_boundary_tween: Tween
	var unrelated_boundary_control: Control
	var environment_canvas_fixture: Control
	var game_surface_canvas_fixture: Control

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
		if unrelated_tween_host != null:
			unrelated_boundary_control = Control.new()
			unrelated_tween_host.add_child(unrelated_boundary_control)
			unrelated_boundary_tween = unrelated_tween_host.create_tween()
			unrelated_boundary_tween.tween_property(unrelated_boundary_control, "position", Vector2(12.0, 0.0), 4.0)
		if environment_canvas_fixture != null:
			environment_canvas_fixture.call("_process", 0.25)
		if game_surface_canvas_fixture != null:
			game_surface_canvas_fixture.call("_process", 0.25)
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

	var environment_canvas_fixture: Control
	var game_surface_canvas_fixture: Control

	func delivery_has_active_run() -> bool:
		return true

	func delivery_resolve_travel_arrival(_route: Dictionary = {}, _route_risk: Dictionary = {}) -> Dictionary:
		if environment_canvas_fixture != null:
			environment_canvas_fixture.call("_process", 0.25)
		if game_surface_canvas_fixture != null:
			game_surface_canvas_fixture.call("_process", 0.25)
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
	var talk_dock_fixture_root: Control
	var capture_transaction_attention := false
	var failed_talk_dock_attention_tween: Tween
	var environment_hover_signal_log: Array[String] = []

	func _show_message(text: String) -> void:
		message_log.append(text)

	func _refresh() -> void:
		pass

	func _refresh_talk_dock() -> void:
		var prior_tweens: Array = talk_dock.attention_tween_lifecycle_snapshot() if capture_transaction_attention and talk_dock != null else []
		super._refresh_talk_dock()
		if not capture_transaction_attention or talk_dock == null:
			return
		for tween_value in talk_dock.attention_tween_lifecycle_snapshot():
			if tween_value is Tween and not prior_tweens.has(tween_value):
				failed_talk_dock_attention_tween = tween_value as Tween

	func _on_environment_object_hovered(object_id: String) -> void:
		environment_hover_signal_log.append(object_id)
		super._on_environment_object_hovered(object_id)

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


class LifecycleDirectExitProbe:
	extends LifecycleCallerProbe

	var direct_exit_choice: Dictionary = {}

	func _local_parent_home_door_travel_choice(_target_id: String) -> Dictionary:
		return direct_exit_choice.duplicate(true)


class LifecycleCageShortcutProbe:
	extends LifecycleCallerProbe

	var cage_fixture := {
		"object_id": "casino_fixture:cage",
		"object_type": FoundationMain.CONTEXT_MODE_CASINO_FIXTURE,
		"source_id": "cage",
		"interactive": true,
		"enabled": true,
		"focus_rect": {"x": 0.2, "y": 0.2, "w": 0.2, "h": 0.2},
		"focus_point": {"x": 0.3, "y": 0.3},
	}

	func _interactable_object(object_id: String) -> Dictionary:
		if object_id == "casino_fixture:cage":
			return cage_fixture.duplicate(true)
		return super._interactable_object(object_id)


static func check(library: ContentLibrary, failures: Array, scene_tree: SceneTree = null) -> void:
	_check_schema(failures)
	_check_public_projection_privacy(failures)
	_check_catalog_rollout(library, failures)
	_check_registered_operations(failures)
	_check_interaction_identity(failures)
	_check_semantic_inventory(library, failures)
	_check_base_semantic_producer(library, failures)
	_check_lifecycle_finalization(library, failures)
	_check_lifecycle_caller_failure_contract(library, failures, scene_tree)
	_check_negative_fixtures(failures)
	_check_lifecycle_commands(failures)
	_check_augment_availability(failures)
	_check_boundary_provenance(failures)
	_check_mutually_exclusive_branch_cleanup(failures)
	_check_handler_reducer_contracts(failures)
	_check_serialized_fact_ingress(failures)
	_check_atomic_runtime_failures(failures)
	_check_sequence_persistence_seam(failures)
	_check_lifecycle_policy_matrix(failures)
	_check_save_service_phase_matrix(failures)
	_check_receipt_reconstruction(failures)
	_check_depth_remediation_contracts(failures)
	_check_authoritative_receipt_capacity(failures)
	_check_completion_evidence(failures)
	_check_extension_dispatch(failures)
	_check_definition_validation_receipt(failures)
	_check_suppressed_sequence_compatibility(library, failures)
	_check_transition_and_event_delivery(failures)
	_check_rollout_growth_contract(library, failures)
	_check_delivery_day_production_package(library, failures)
	_check_executable_evidence_contract(failures)
	_check_material_projection(failures)
	ScenarioPresentationContractScript.check(failures)
	_check_host_transaction_seam(failures)


static func _check_lifecycle_caller_failure_contract(library: ContentLibrary, failures: Array, scene_tree: SceneTree) -> void:
	var tutorial_source_before := JSON.stringify(library.tutorial_lessons)
	var tutorial_index_before := JSON.stringify(_dict(library._indexes.get("tutorial_lessons", {})))
	var layer_probe := _lifecycle_probe(library, _lifecycle_run(false))
	var layer_generator := LifecycleRejectingGenerator.new(library)
	layer_generator.reject_layer = true
	layer_probe.generator = layer_generator
	var layer_rng := RngStream.new()
	layer_rng.configure(91201)
	var layered_environment := EnvironmentInstanceScript.from_archetype(library.environment_archetype("small_underground_casino"), 1, layer_rng, library).to_dict()
	layer_probe.run_state.current_environment = layered_environment
	_install_real_event_popup(layer_probe, "side_door")
	_install_active_tutorial_presentation(layer_probe, "tutorial_family_phone", "event:side_door", "family_phone", scene_tree, true)
	var layer_hover_signal_count := layer_probe.environment_hover_signal_log.size()
	var layer_hover_baseline_valid := layer_probe.environment_hover_signal_log == ["event:side_door"] \
			and layer_probe.selected_object_id.is_empty() and layer_probe.environment_canvas.selected_object_id.is_empty() \
			and layer_probe.hover_target_id == "event:side_door" and layer_probe.environment_canvas.hovered_object_id == "event:side_door" \
			and layer_probe.environment_canvas.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND
	var layer_before := _public_caller_probe_state(layer_probe)
	var layer_preexisting_talk_tweens := layer_probe.talk_dock.attention_tween_lifecycle_snapshot()
	var layer_preexisting_coach_tween: Variant = layer_probe.coach_overlay.attention_tween_lifecycle_snapshot().get("tween", null)
	var layer_message_start := layer_probe.message_log.size()
	layer_probe.capture_transaction_attention = true
	var layer_ok := layer_probe.activate_event_choice_action("side_door", "punchline_password")
	layer_probe.capture_transaction_attention = false
	var layer_messages := layer_probe.message_log.slice(layer_message_start)
	var layer_rollback_equal := _public_caller_probe_state(layer_probe) == layer_before
	layer_probe._resume_after_completed_tutorial_action("tutorial_family_phone", layer_probe.tutorial_action_resume_generation_counter)
	layer_probe.talk_dock._position_panel()
	layer_probe.talk_dock._process(1.0)
	layer_probe._on_talk_dock_occupied_rect_changed(layer_probe.talk_dock.occupied_global_rect())
	var unrelated_tween_advanced := layer_generator.unrelated_boundary_tween != null and layer_generator.unrelated_boundary_tween.custom_step(0.5)
	var layer_stale_work_ignored := _public_caller_probe_state(layer_probe) == layer_before
	var talk_alpha_before_step := layer_probe.talk_dock.panel.modulate.a
	var preexisting_talk_tween_advanced := false
	if not layer_preexisting_talk_tweens.is_empty() and layer_preexisting_talk_tweens[0] is Tween:
		preexisting_talk_tween_advanced = (layer_preexisting_talk_tweens[0] as Tween).custom_step(0.05)
	var preexisting_talk_tween_progressed := layer_probe.talk_dock.panel.modulate.a > talk_alpha_before_step
	var coach_alpha_before_step := layer_probe.coach_overlay.panel.modulate.a
	var preexisting_coach_tween_advanced := false
	if layer_preexisting_coach_tween is Tween:
		preexisting_coach_tween_advanced = (layer_preexisting_coach_tween as Tween).custom_step(0.05)
	var preexisting_coach_tween_progressed := layer_probe.coach_overlay.panel.modulate.a > coach_alpha_before_step
	var layer_preexisting_coach_survived := layer_preexisting_coach_tween is Tween and (layer_preexisting_coach_tween as Tween).is_valid()
	var layer_rollback_checkpoint_clean := layer_probe.coach_overlay.lifecycle_protected_attention_tweens.is_empty()
	var layer_hover_rollback_exact := layer_probe.environment_hover_signal_log.size() == layer_hover_signal_count \
			and layer_probe.selected_object_id.is_empty() and layer_probe.environment_canvas.selected_object_id.is_empty() \
			and layer_probe.hover_target_id == "event:side_door" and layer_probe.environment_canvas.hovered_object_id == "event:side_door" \
			and layer_probe.environment_canvas.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND
	if layer_ok or not layer_rollback_equal or not layer_stale_work_ignored or not layer_hover_baseline_valid or not layer_hover_rollback_exact \
			or layer_probe.autosave_count != 0 or layer_probe.presentation_count != 0 \
			or layer_messages != ["", "Selected event choice: Try the word.", "Layer caller fixture rejected."] \
			or layer_probe.failed_talk_dock_attention_tween == null or layer_probe.failed_talk_dock_attention_tween.is_valid() \
			or not _all_valid_tweens(layer_preexisting_talk_tweens) or not layer_preexisting_coach_survived \
			or not preexisting_talk_tween_advanced or not preexisting_talk_tween_progressed or not preexisting_coach_tween_advanced or not preexisting_coach_tween_progressed \
			or not unrelated_tween_advanced or layer_generator.unrelated_boundary_control == null or layer_generator.unrelated_boundary_control.position.x <= 0.0 \
			or not layer_rollback_checkpoint_clean:
		failures.append("Tutorial event-card completion did not restore its authoritative queue, connected coach, actual TalkDock selection/badge/layout/focus, and popup state exactly before the one terminal layer error.")
	_free_lifecycle_presentation_probe(layer_probe)

	var map_probe := _lifecycle_probe(library, _lifecycle_run(true))
	var map_generator := LifecycleRejectingGenerator.new(library)
	map_generator.install_world_destination = true
	map_probe.generator = map_generator
	_install_real_world_map_popup(map_probe, "motel", "Motel")
	_install_active_tutorial_presentation(map_probe, "tutorial_travel_corner", "travel:motel", "map_destination", scene_tree)
	var map_before := _public_caller_probe_state(map_probe)
	var map_preexisting_talk_tweens := map_probe.talk_dock.attention_tween_lifecycle_snapshot()
	var map_preexisting_coach_tween: Variant = map_probe.coach_overlay.attention_tween_lifecycle_snapshot().get("tween", null)
	var map_message_start := map_probe.message_log.size()
	map_probe.capture_transaction_attention = true
	var map_result := map_probe.confirm_world_map_travel()
	map_probe.capture_transaction_attention = false
	var map_messages := map_probe.message_log.slice(map_message_start)
	var map_rollback_equal := _public_caller_probe_state(map_probe) == map_before
	map_probe._resume_after_completed_tutorial_action("tutorial_travel_corner", map_probe.tutorial_action_resume_generation_counter)
	map_probe.talk_dock._position_panel()
	map_probe.talk_dock._process(1.0)
	map_probe._on_talk_dock_occupied_rect_changed(map_probe.talk_dock.occupied_global_rect())
	var map_stale_work_ignored := _public_caller_probe_state(map_probe) == map_before
	if bool(map_result.get("ok", true)) or not map_rollback_equal or not map_stale_work_ignored or map_probe.autosave_count != 0 or map_probe.presentation_count != 0 \
			or map_messages != ["", "Traveling to Motel...", "Delivery caller fixture rejected."] \
			or map_probe.failed_talk_dock_attention_tween == null or map_probe.failed_talk_dock_attention_tween.is_valid() \
			or not _all_valid_tweens(map_preexisting_talk_tweens) or not (map_preexisting_coach_tween is Tween) or not (map_preexisting_coach_tween as Tween).is_valid() \
			or not map_probe.coach_overlay.lifecycle_protected_attention_tweens.is_empty() \
			or map_probe.coach_overlay.active_anchor_kind() != "hud_element" or map_probe.coach_overlay.active_anchor_id() != "travel:corner_store" or not map_probe.coach_overlay.focus_visual_enabled:
		failures.append("Tutorial world-map acknowledgement did not restore its authoritative queue, connected coach, actual TalkDock presentation, and map controller exactly before the one terminal delivery error.")
	_free_lifecycle_presentation_probe(map_probe)

	var success_probe := _lifecycle_probe(library, _lifecycle_run(false))
	var success_rng := RngStream.new()
	success_rng.configure(91204)
	success_probe.run_state.current_environment = EnvironmentInstanceScript.from_archetype(library.environment_archetype("small_underground_casino"), 1, success_rng, library).to_dict()
	_install_real_event_popup(success_probe, "side_door")
	_install_active_tutorial_presentation(success_probe, "tutorial_family_phone", "event:side_door", "family_phone", scene_tree)
	var success_coach_tween: Variant = success_probe.coach_overlay.attention_tween_lifecycle_snapshot().get("tween", null)
	var success_ok := success_probe.activate_event_choice_action("side_door", "punchline_password")
	if not success_ok or not success_probe.coach_overlay.lifecycle_protected_attention_tweens.is_empty() \
			or success_probe.coach_overlay.attention_tween != null \
			or (success_coach_tween is Tween and (success_coach_tween as Tween).is_valid()):
		failures.append("Successful tutorial event lifecycle did not commit and release its scoped Coach attention checkpoint.")
	_free_lifecycle_presentation_probe(success_probe)
	if JSON.stringify(library.tutorial_lessons) != tutorial_source_before or JSON.stringify(_dict(library._indexes.get("tutorial_lessons", {}))) != tutorial_index_before:
		failures.append("Lifecycle presentation fixtures mutated the source tutorial catalog or its lookup index.")

	var meta_map_probe := LifecycleMetaEntryRejectProbe.new()
	meta_map_probe.library = library
	meta_map_probe.run_state = _lifecycle_run(false)
	meta_map_probe.run_state.narrative_flags["_meta_home_session"] = true
	meta_map_probe.meta_session_active = true
	meta_map_probe.meta_session_location_id = FoundationMain.META_LOCATION_HOME
	meta_map_probe.current_screen = FoundationMain.SCREEN_TRAVEL
	_install_real_world_map_popup(meta_map_probe, "pawn_shop", "Sal's Pawn Shop")
	var meta_map_before := _public_caller_probe_state(meta_map_probe)
	var meta_map_message_start := meta_map_probe.message_log.size()
	var meta_map_result := meta_map_probe.confirm_world_map_travel()
	var meta_map_messages := meta_map_probe.message_log.slice(meta_map_message_start)
	if bool(meta_map_result.get("ok", true)) or _public_caller_probe_state(meta_map_probe) != meta_map_before or meta_map_probe.autosave_count != 0 or meta_map_probe.presentation_count != 0 \
			or meta_map_messages != ["Meta entry caller fixture rejected."]:
		failures.append("Public meta-map caller did not propagate entry rejection, restore its real controller/popup/session state exactly, or retain the single terminal error.")
	meta_map_probe.free()

	var direct_probe := LifecycleDirectExitProbe.new()
	direct_probe.library = library
	direct_probe.run_state = _lifecycle_run(true)
	var direct_generator := LifecycleRejectingGenerator.new(library)
	direct_generator.install_world_destination = true
	direct_probe.generator = direct_generator
	direct_probe.current_screen = FoundationMain.SCREEN_ENVIRONMENT
	direct_probe.selected_action_category = FoundationMain.ACTION_CATEGORY_EVENTS
	direct_probe.direct_exit_choice = {
		"id": "motel", "label": "Motel", "enabled": true, "distance": "near", "travel_minutes": 6,
		"route": {"id": "bar_node_to_motel", "from": "bar_node", "to": "motel", "distance": "near", "cost": 0, "suspicion_delta": 0},
	}
	_install_real_world_map_popup(direct_probe, "motel", "Motel")
	var direct_exit_before := _public_caller_probe_state(direct_probe)
	var direct_exit_message_start := direct_probe.message_log.size()
	var direct_exit_ok := direct_probe.activate_interactable_object("travel:leave")
	var direct_exit_messages := direct_probe.message_log.slice(direct_exit_message_start)
	if direct_exit_ok or _public_caller_probe_state(direct_probe) != direct_exit_before or direct_probe.autosave_count != 0 or direct_probe.presentation_count != 0 \
			or direct_exit_messages != ["Traveling to Motel...", "Delivery caller fixture rejected."]:
		failures.append("Public direct-exit caller did not restore pre-focus state and propagate the exact travel failure without downstream success.")
	direct_probe.free()

	var cage_run := _grand_casino_lifecycle_run(library)
	if cage_run == null:
		failures.append("Public Cage shortcut fixture could not build the production Grand Casino room route.")
	else:
		var cage_probe := LifecycleCageShortcutProbe.new()
		cage_probe.library = library
		cage_probe.run_state = cage_run
		var cage_generator := LifecycleRejectingGenerator.new(library)
		cage_generator.reject_room = true
		cage_probe.generator = cage_generator
		cage_probe.current_screen = FoundationMain.SCREEN_ENVIRONMENT
		var cage_choice := cage_probe._travel_choice(RunStateScript.GRAND_CASINO_CAGE_ARCHETYPE_ID)
		var cage_label := str(cage_choice.get("label", RunStateScript.GRAND_CASINO_CAGE_ARCHETYPE_ID))
		_install_real_world_map_popup(cage_probe, RunStateScript.GRAND_CASINO_CAGE_ARCHETYPE_ID, cage_label)
		var cage_before := _public_caller_probe_state(cage_probe)
		var cage_message_start := cage_probe.message_log.size()
		var cage_ok := cage_probe.activate_interactable_object("casino_fixture:cage")
		var cage_messages := cage_probe.message_log.slice(cage_message_start)
		var expected_cage_messages := ["Route marked: %s." % cage_label, "Traveling to %s..." % cage_label, "Grand-room caller fixture rejected."]
		if cage_choice.is_empty() or cage_ok or _public_caller_probe_state(cage_probe) != cage_before or cage_probe.autosave_count != 0 or cage_probe.presentation_count != 0 or cage_messages != expected_cage_messages:
			failures.append("Public Cage shortcut did not restore pre-focus/selection state and propagate exact room-entry failure ordering without downstream success.")
		cage_probe.free()

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

	var direct_game_probe := _lifecycle_probe(library, _lifecycle_run(false))
	direct_game_probe.show_game_library_launcher = true
	direct_game_probe.reject_install = true
	var direct_before := _caller_probe_state(direct_game_probe)
	var direct_result := direct_game_probe.start_game_test_session("lifecycle_fixture_game")
	var direct_errors := _array(direct_result.get("errors", []))
	if bool(direct_result.get("ok", true)) or _caller_probe_state(direct_game_probe) != direct_before or direct_game_probe.autosave_count != 0 or direct_errors.is_empty() or str(direct_errors[0]) != "Environment caller fixture rejected.":
		failures.append("Direct game-test entry did not return/restore its enclosing run and screen after room rejection.")
	direct_game_probe.free()

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


static func _install_real_event_popup(probe: LifecycleCallerProbe, event_id: String) -> void:
	probe._build_event_choice_popup_overlay()
	probe._show_interactable_event_popup(event_id)


static func _install_active_tutorial_presentation(probe: LifecycleCallerProbe, lesson_id: String, action_id: String, dialogue_node: String, scene_tree: SceneTree, hover_only_canvas_baseline: bool = false) -> void:
	probe.run_state.challenge_config["tutorial"] = true
	var fixture_root := Control.new()
	fixture_root.name = "LifecycleTalkDockFixture"
	fixture_root.size = Vector2(960.0, 640.0)
	assert(scene_tree != null and scene_tree.root != null, "Lifecycle presentation fixture requires the attached check runner SceneTree.")
	scene_tree.root.add_child(fixture_root)
	var environment_canvas := PixelSceneCanvasScript.new()
	environment_canvas.size = fixture_root.size
	fixture_root.add_child(environment_canvas)
	var environment_snapshot := probe.run_state.current_environment.duplicate(true)
	environment_snapshot["event_ids"] = ["side_door"]
	environment_snapshot["reduce_motion"] = false
	environment_canvas.render_environment_snapshot(environment_snapshot)
	probe.environment_canvas = environment_canvas
	environment_canvas.object_hovered.connect(Callable(probe, "_on_environment_object_hovered"))
	environment_canvas.object_focused.connect(Callable(probe, "_on_environment_object_focused"))
	environment_canvas.object_activated.connect(Callable(probe, "_on_environment_object_activated"))
	environment_canvas.view_geometry_changed.connect(Callable(probe, "_on_environment_view_geometry_changed"))
	var game_surface_canvas := GameSurfaceCanvasScript.new()
	game_surface_canvas.size = fixture_root.size
	fixture_root.add_child(game_surface_canvas)
	game_surface_canvas.render_game_snapshot({"game_id": "slot", "surface_time_msec": 2100.0, "surface_presentation_time_msec": 2400.0, "reduce_motion": false})
	probe.game_surface_canvas = game_surface_canvas
	var dock := TalkDockScript.new()
	dock.choice_requested.connect(Callable(probe, "_on_talk_dock_choice_requested"))
	dock.occupied_rect_changed.connect(Callable(probe, "_on_talk_dock_occupied_rect_changed"))
	dock.conversation_active_changed.connect(Callable(probe, "_on_talk_dock_conversation_active_changed"))
	fixture_root.add_child(dock)
	probe.talk_dock_fixture_root = fixture_root
	probe.talk_dock = dock
	if probe.generator is LifecycleRejectingGenerator:
		(probe.generator as LifecycleRejectingGenerator).unrelated_tween_host = fixture_root
		(probe.generator as LifecycleRejectingGenerator).environment_canvas_fixture = environment_canvas
		(probe.generator as LifecycleRejectingGenerator).game_surface_canvas_fixture = game_surface_canvas
	if probe.run_state is LifecycleDeliveryRejectRun:
		(probe.run_state as LifecycleDeliveryRejectRun).environment_canvas_fixture = environment_canvas
		(probe.run_state as LifecycleDeliveryRejectRun).game_surface_canvas_fixture = game_surface_canvas

	var coach := CoachOverlayScript.new()
	coach.lesson_seen.connect(Callable(probe, "_on_coach_lesson_seen"))
	coach.lesson_completed.connect(Callable(probe, "_on_coach_lesson_completed"))
	coach.dialogue_requested.connect(Callable(probe, "_on_coach_dialogue_requested"))
	fixture_root.add_child(coach)
	coach.set_lessons(probe.library.tutorial_lessons)
	probe.coach_overlay = coach
	# ContentLibrary lookups return catalog-owned dictionaries. This presentation
	# fixture authors a local completion/anchor variant and must never mutate the
	# source catalog or its lookup index.
	var lesson := probe.library.tutorial_lesson(lesson_id).duplicate(true)
	lesson["completion"] = {"type": "anchored_action", "action_id": action_id}
	lesson["dialogue_node"] = dialogue_node
	if lesson_id != "tutorial_travel_corner":
		lesson["anchor"] = {"kind": "interactable_object", "id": action_id}
	var anchor := _dict(lesson.get("anchor", {}))
	var anchor_kind := str(anchor.get("kind", "none"))
	var anchor_id := str(anchor.get("id", ""))
	var interactable_anchor_rects := {}
	var hud_anchor_rects := {}
	if anchor_kind == "interactable_object":
		interactable_anchor_rects[anchor_id] = Rect2(210.0, 145.0, 110.0, 72.0)
	elif anchor_kind == "hud_element":
		hud_anchor_rects[anchor_id] = Rect2(690.0, 430.0, 150.0, 64.0)
	var coach_context := {
		"screen": "TRAVEL" if anchor_kind == "hud_element" and anchor_id.begins_with("travel:") else "ENVIRONMENT",
		"viewport_rect": Rect2(Vector2.ZERO, fixture_root.size),
		"anchor_rects": {
			"interactable_objects": interactable_anchor_rects,
			"hud_elements": hud_anchor_rects,
			"surface_actions": {},
		},
		"run": {"tutorial": true},
	}
	coach.latest_context = coach_context.duplicate(true)
	coach.queued_lessons = [{"lesson": lesson, "context": coach_context.duplicate(true)}]
	coach.queued_ids = {lesson_id: true}
	coach._show_next()

	var followup_dialogue := probe.library.dialogue("pull_tab_clerk")
	probe.run_state.enqueue_dialogue(
		"pull_tab_clerk",
		"lifecycle_followup:%s" % lesson_id,
		_dict(followup_dialogue.get("speaker", {})),
		"greeting",
		"dialogue",
		{"source": "dialogue", "fixture": "lifecycle-followup"}
	)
	# Exercise the production refresh, queue badge, selected response, focus, and
	# avoid-rect layout authority before the completion signal refreshes the dock.
	probe._refresh_talk_dock()
	var selected_choices := _array(dock.option.get("choices", []))
	if not selected_choices.is_empty() and typeof(selected_choices[0]) == TYPE_DICTIONARY:
		var selected_choice: Dictionary = selected_choices[0]
		selected_choice["requires_confirm"] = true
		selected_choices[0] = selected_choice
		dock.option["choices"] = selected_choices
		dock.armed_choice_id = "continue"
		dock.rendered_entry_key = JSON.stringify({"entry": dock.entry, "option": dock.option, "queue_count": dock.queue_count})
		_clear_talk_dock_choice_hierarchy(dock)
		dock._render_choices()
	dock._complete_body_reveal()
	if hover_only_canvas_baseline:
		probe.selected_object_id = ""
		environment_canvas.set_selected_object("", false)
		environment_canvas._set_hovered_object("event:side_door")
	else:
		probe.selected_object_id = "event:side_door"
		environment_canvas.set_selected_object(probe.selected_object_id, false)
	dock.set_avoid_global_rect(Rect2(620.0, 390.0, 230.0, 170.0), "lifecycle:%s" % lesson_id, 760.0)
	probe._apply_talk_dock_environment_reserve()
	environment_canvas.scene_idle_animation_redraw_accumulator = 0.03125
	environment_canvas.scene_idle_animation_redraw_count = 9
	environment_canvas.camera_zoom = lerpf(1.0, environment_canvas.target_camera_zoom, 0.35)
	environment_canvas.camera_offset = environment_canvas.target_camera_offset * 0.35
	game_surface_canvas.captured_pointer_move_pending = true
	game_surface_canvas.captured_pointer_move_position = Vector2(317.0, 229.0)
	game_surface_canvas.surface_animation_redraw_accumulator = 0.041
	game_surface_canvas.surface_animation_redraw_count = 7
	game_surface_canvas.continuous_redraw_was_active = true
	game_surface_canvas.flicker = 1.25
	game_surface_canvas.surface_render_elapsed_sec = 2.75
	# The runner constructs this attached presentation synchronously. Exercise one
	# no-op lifecycle restore so Container-managed controls reach the same stable
	# post-layout geometry used by every transaction rollback below.
	var settled_presentation := probe._foundation_lifecycle_snapshot()
	probe._restore_foundation_lifecycle_snapshot(settled_presentation)
	if dock.choice_list.get_child_count() > 0:
		var response := dock.choice_list.get_child(0)
		for response_child in response.get_children():
			if response_child is Button:
				(response_child as Button).grab_focus()
				break
	# Opening the authored Coach dialogue during fixture setup is itself a valid
	# committed boundary. The caller assertions below measure only work emitted by
	# the transaction under test.
	probe.autosave_count = 0


static func _clear_talk_dock_choice_hierarchy(dock: TalkDock) -> void:
	if dock == null or dock.choice_list == null:
		return
	for child in dock.choice_list.get_children():
		dock.choice_list.remove_child(child)
		child.queue_free()


static func _all_valid_tweens(tweens: Array) -> bool:
	if tweens.is_empty():
		return false
	for tween_value in tweens:
		if not tween_value is Tween or not (tween_value as Tween).is_valid():
			return false
	return true


static func _free_lifecycle_presentation_probe(probe: LifecycleCallerProbe) -> void:
	probe.talk_dock = null
	probe.coach_overlay = null
	probe.environment_canvas = null
	probe.game_surface_canvas = null
	var fixture_root := probe.talk_dock_fixture_root
	probe.talk_dock_fixture_root = null
	if fixture_root != null and is_instance_valid(fixture_root):
		fixture_root.free()
	if is_instance_valid(probe):
		probe.free()


static func _install_real_world_map_popup(probe: FoundationMain, target_id: String, target_label: String) -> void:
	var overlay := Control.new()
	var holder := Control.new()
	var nodes_layer := Control.new()
	var title := Label.new()
	var detail_popup := PanelContainer.new()
	var detail_stack := VBoxContainer.new()
	var detail_label := Label.new()
	var badge_slot := VBoxContainer.new()
	var confirm := Button.new()
	probe.add_child(overlay)
	overlay.add_child(holder)
	holder.add_child(nodes_layer)
	overlay.add_child(title)
	overlay.add_child(detail_popup)
	detail_popup.add_child(detail_stack)
	detail_stack.add_child(detail_label)
	detail_stack.add_child(badge_slot)
	detail_stack.add_child(confirm)
	overlay.visible = true
	detail_popup.visible = true
	title.text = "Lifecycle map title"
	detail_label.text = "Lifecycle map detail"
	confirm.text = "Travel fixture"
	probe.world_map_overlay = overlay
	probe.world_map_holder = holder
	probe.world_map_nodes_layer = nodes_layer
	probe.world_map_title_label = title
	probe.world_map_detail_popup = detail_popup
	probe.world_map_detail_label = detail_label
	probe.world_map_badge_slot = badge_slot
	probe.world_map_confirm_button = confirm
	probe._ensure_world_map_overlay_controller()
	probe.world_map_overlay_controller.configure_nodes(overlay, holder, nodes_layer, title, detail_popup, detail_label, badge_slot, confirm)
	probe.selected_world_map_node_id = target_id
	probe.selected_travel_target_id = target_id
	probe.selected_travel_label = target_label
	probe.world_map_snapshot_cache_key = "host-map-cache"
	probe.world_map_canvas_snapshot_key = "host-canvas-cache"
	# Deliberately keep the live controller distinct from its host fields. The
	# public confirm callback synchronizes it before travel; rollback must recover
	# the exact pre-callback controller as well as the host selection.
	probe.world_map_overlay_controller.set_small_screen_mode(true)
	probe.world_map_overlay_controller.sync_from_host("controller-sentinel", "controller-target", "Controller Target", "controller-map-cache", "controller-canvas-cache")


static func _public_caller_probe_state(probe: FoundationMain) -> String:
	var lifecycle_snapshot := probe._foundation_lifecycle_snapshot()
	var coach_state := _dict(lifecycle_snapshot.get("coach", {}))
	coach_state.erase("ref")
	coach_state.erase("parent_ref")
	coach_state.erase("focus_ref")
	var coach_attention_state := _dict(coach_state.get("attention", {}))
	coach_attention_state.erase("tween")
	coach_state["attention"] = coach_attention_state
	var talk_dock_state := _dict(lifecycle_snapshot.get("talk_dock", {}))
	for reference_key in ["ref", "parent_ref", "focus_ref", "attention_tweens"]:
		talk_dock_state.erase(reference_key)
	var talk_dock_canvas_state := _dict(lifecycle_snapshot.get("talk_dock_canvases", {}))
	talk_dock_canvas_state.erase("environment_ref")
	talk_dock_canvas_state.erase("game_surface_ref")
	var popup_state := {
		"visible": probe.event_choice_popup_overlay.visible if probe.event_choice_popup_overlay != null else false,
		"title": probe.event_choice_popup_title_label.text if probe.event_choice_popup_title_label != null else "",
		"summary": probe.event_choice_popup_summary_label.text if probe.event_choice_popup_summary_label != null else "",
		"choice_children": probe.event_choice_popup_choices_list.get_child_count() if probe.event_choice_popup_choices_list != null else 0,
	}
	var map_popup_state := {
		"visible": probe.world_map_overlay.visible if probe.world_map_overlay != null else false,
		"detail_visible": probe.world_map_detail_popup.visible if probe.world_map_detail_popup != null else false,
		"title": probe.world_map_title_label.text if probe.world_map_title_label != null else "",
		"detail": probe.world_map_detail_label.text if probe.world_map_detail_label != null else "",
		"confirm_text": probe.world_map_confirm_button.text if probe.world_map_confirm_button != null else "",
		"confirm_disabled": probe.world_map_confirm_button.disabled if probe.world_map_confirm_button != null else true,
	}
	return "%s\n%s" % [
		_caller_probe_state(probe),
		JSON.stringify({
			"controller": lifecycle_snapshot.get("world_map_controller", {}),
			"coach": coach_state,
			"talk_dock": talk_dock_state,
			"talk_dock_canvases": talk_dock_canvas_state,
			"environment_canvas": probe.environment_canvas.current_view_snapshot() if probe.environment_canvas != null else {},
			"game_surface_canvas": probe.game_surface_canvas.current_view_snapshot() if probe.game_surface_canvas != null else {},
			"event_popup": popup_state,
			"map_popup": map_popup_state,
		}),
	]


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


static func _grand_casino_lifecycle_run(library: ContentLibrary) -> RunState:
	var rng := RngStream.new()
	rng.configure(91203)
	var environment := EnvironmentInstanceScript.from_archetype(library.environment_archetype(RunStateScript.GRAND_CASINO_ARCHETYPE_ID), 1, rng, library).to_dict()
	if environment.is_empty():
		return null
	var run_state := RunStateScript.new()
	run_state.start_new("LIFECYCLE-CAGE-SHORTCUT")
	run_state.current_environment = environment
	run_state.grand_casino_room_states = {"sentinel": {"id": "cage_shortcut_sentinel", "archetype_id": RunStateScript.GRAND_CASINO_ARCHETYPE_ID}}
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
	var public_catalog := library.scenario_target_catalog(finalization_fixture_definition())
	if public_catalog.is_empty() or not public_catalog.has("guaranteed") or not public_catalog.has("possible") or not public_catalog.has("records") or not public_catalog.has("provenance") or not public_catalog.has("errors") or _dict(public_catalog.get("inventory", {})).is_empty():
		failures.append("Public scenario target catalog did not expose full guaranteed/possible/record/provenance/error proof.")
	var wrong_layer_definition := finalization_fixture_definition()
	wrong_layer_definition["layer_id"] = "ghost_layer"
	if not _contains_text(_array(library.scenario_target_catalog(wrong_layer_definition).get("errors", [])), "layer"):
		failures.append("Public scenario target catalog did not diagnose an authored layer mismatch.")
	var exact_environment := {"id": "grand_casino_001", "world_node_id": "node_1", "archetype_id": "grand_casino", "game_ids": ["slot"], "event_ids": ["late_shift_discount"], "item_offers": [{"id": "marked_cards"}], "service_ids": ["house_drink"], "lender_hooks": ["street_lender"], "next_archetypes": ["bar"], "travel_hooks": ["bar"], "current_layer_id": "main", "layer_ids": ["main", "cage"], "layer_transitions": [{"target_layer_id": "cage"}], "local_narrative_flags": {"casino_room_targets": ["grand_casino_cage"]}, "layout": {"object_rects": {"game:slot": {"x": 0.1, "y": 0.1, "w": 0.12, "h": 0.18}, "game:slot:2": {"x": 0.1, "y": 0.1, "w": 0.12, "h": 0.18}, "travel:grand_casino_cage": {"x": 0.3, "y": 0.1, "w": 0.12, "h": 0.18}}}}
	var exact_stamped := EnvironmentBaseSemanticRecordsScript.stamp_interactable_records([
		_presentation_record("game:slot", "game", "slot", Rect2(0.1, 0.1, 0.12, 0.18)),
		_presentation_record("game:slot:2", "game", "slot", Rect2(0.1, 0.1, 0.12, 0.18)),
		_presentation_record("travel:grand_casino_cage", "travel", "grand_casino_cage", Rect2(0.3, 0.1, 0.12, 0.18)),
	], exact_environment, library)
	var exact_records := _array(exact_stamped.get("records", []))
	var exact := EnvironmentSemanticInventoryScript.for_instance(exact_environment, library, exact_records)
	var exact_collections := EnvironmentSemanticInventoryScript.exact_collections(exact)
	if not bool(exact_stamped.get("ok", false)) or not EnvironmentSemanticInventoryScript.validate(exact).is_empty() or not _array(exact_collections.get("scene_objects", [])).has("game::game:slot:2") or not _array(exact_collections.get("interactions", [])).has("game::game:slot:2") or not _array(exact_collections.get("routes", [])).has("base::layer:cage") or not _array(exact_collections.get("routes", [])).has("base::room:grand_casino_cage"):
		failures.append("Exact instance inventory lost generated fixtures/interactions/layer or room routes.")
	var tampered := exact.duplicate(true)
	tampered["environment_id"] = "forged"
	if EnvironmentSemanticInventoryScript.validate(tampered).is_empty() or not EnvironmentSemanticInventoryScript.exact_collections(tampered).is_empty(): failures.append("Tampered semantic inventory digest was accepted.")
	var duplicate_exact := EnvironmentSemanticInventoryScript.for_instance(exact_environment, library, [exact_records[0], exact_records[0], exact_records[2]])
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
	var definition := finalization_fixture_definition()
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
	var installed_definition := run_state.scenario_sequence_definition()
	if not SequenceSchemaScript.is_sequence(installed_definition) or not bool(installed_definition.get(ScenarioEngineScript.VALIDATED_SEQUENCE_MARKER, false)) or str(installed_definition.get("sequence_signature", "")) != str(definition.get("sequence_signature", "")):
		failures.append("Semantic finalization did not retain the exact catalog-validated installed sequence definition.")
		return
	definition = installed_definition
	run_state.current_environment["scenario_sequence_definition"] = installed_definition.duplicate(true)
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
		var valid_overlay_descriptor := SequenceRuntimeScript._command_descriptor(valid_overlay_state, definition, "scenario", "command_console", "prepare")
		var valid_overlay_run := RunStateScript.new()
		valid_overlay_run.current_environment = valid_overlay_environment
		valid_overlay_run.bankroll = 10
		var valid_overlay_result := valid_overlay_run.scenario_sequence_command(
			"prepare", "valid:overlay:handler", {}, "scenario", "command_console", {"scenario::command_console": true},
			str(valid_overlay_descriptor.get("action_origin_owner_namespace", "")),
			str(valid_overlay_descriptor.get("action_origin_stable_object_id", "")),
			str(valid_overlay_descriptor.get("action_origin_receipt_key", "")),
			str(valid_overlay_descriptor.get("action_origin_boundary_id", "")),
			str(valid_overlay_descriptor.get("action_origin_fingerprint", ""))
		)
		if not bool(valid_overlay_result.get("ok", false)):
			failures.append("Authenticated authored interaction operation no longer authorized its exact handler action.")
		else:
			var progressed_interaction := _dict(_dict(_dict(valid_overlay_run.scenario_sequence_projection().get("semantic_state", {})).get("interactions", {})).get("scenario::command_console", {}))
			var progressed_action_ids: Array = []
			for progressed_action_value in _array(progressed_interaction.get("available_actions", [])):
				progressed_action_ids.append(str(_dict(progressed_action_value).get("id", "")))
			if not progressed_action_ids.has("finish"):
				failures.append("A publicly available objective-gated action did not reappear after its sealed objective step completed.")
			var overlay_authority := _dict(valid_overlay_run.current_environment.get("scenario_layout_authority", {}))
			var complication_authority := _dict(overlay_authority.get("game::game:slot", {}))
			var normal_rect := _dict(complication_authority.get("normalized_hit_rect", {}))
			var small_rect := _dict(complication_authority.get("small_screen_rect", {}))
			var complication_scene := _dict(_dict(_dict(valid_overlay_run.current_environment.get("scenario_sequence_state", {})).get("semantic_state", {})).get("scene_objects", {}))
			if str(_dict(complication_scene.get("scenario::fixture_100", {})).get("state", "")) != "blocked" or float(normal_rect.get("w", 0.0)) <= 0.0 or float(normal_rect.get("h", 0.0)) <= 0.0 or float(small_rect.get("w", 0.0)) <= 0.0 or float(small_rect.get("h", 0.0)) <= 0.0:
				failures.append("Authenticated lifecycle command did not apply the complication fixture state with sealed normal and expanded small-screen authority.")
	var cost_run := RunStateScript.new()
	cost_run.current_environment = valid_authority_environment.duplicate(true)
	cost_run.bankroll = 10
	var cost_state := _dict(cost_run.current_environment.get("scenario_sequence_state", {}))
	var cost_descriptor := SequenceRuntimeScript._command_descriptor(cost_state, definition, "scenario", "command_console", "prepare")
	var cost_host_availability := {"scenario::command_console": true}
	var accepted_cost := cost_run.scenario_sequence_command(
		"prepare", "run_state:cost:once", {}, "scenario", "command_console",
		cost_host_availability,
		str(cost_descriptor.get("action_origin_owner_namespace", "")),
		str(cost_descriptor.get("action_origin_stable_object_id", "")),
		str(cost_descriptor.get("action_origin_receipt_key", "")),
		str(cost_descriptor.get("action_origin_boundary_id", "")),
		str(cost_descriptor.get("action_origin_fingerprint", ""))
	)
	var bankroll_after_accept := cost_run.bankroll
	var replayed_cost := cost_run.scenario_sequence_command(
		"prepare", "run_state:cost:once", {}, "scenario", "command_console",
		cost_host_availability,
		str(cost_descriptor.get("action_origin_owner_namespace", "")),
		str(cost_descriptor.get("action_origin_stable_object_id", "")),
		str(cost_descriptor.get("action_origin_receipt_key", "")),
		str(cost_descriptor.get("action_origin_boundary_id", "")),
		str(cost_descriptor.get("action_origin_fingerprint", ""))
	)
	var rejected_cost := cost_run.scenario_sequence_command(
		"prepare", "run_state:cost:once", {"forged": true}, "scenario", "command_console",
		cost_host_availability,
		str(cost_descriptor.get("action_origin_owner_namespace", "")),
		str(cost_descriptor.get("action_origin_stable_object_id", "")),
		str(cost_descriptor.get("action_origin_receipt_key", "")),
		str(cost_descriptor.get("action_origin_boundary_id", "")),
		str(cost_descriptor.get("action_origin_fingerprint", ""))
	)
	var origin_conflict := cost_run.scenario_sequence_command(
		"prepare", "run_state:cost:once", {}, "scenario", "command_console", cost_host_availability,
		str(cost_descriptor.get("action_origin_owner_namespace", "")),
		str(cost_descriptor.get("action_origin_stable_object_id", "")),
		str(cost_descriptor.get("action_origin_receipt_key", "")),
		str(cost_descriptor.get("action_origin_boundary_id", "")),
		"0".repeat(64)
	)
	var restored_cost_run := RunStateScript.new()
	restored_cost_run.from_dict(cost_run.to_dict())
	var restored_cost_finalization := restored_cost_run.scenario_finalize_base_semantics([disabled_presentation], library)
	var restored_replay := restored_cost_run.scenario_sequence_command(
		"prepare", "run_state:cost:once", {}, "scenario", "command_console", cost_host_availability,
		str(cost_descriptor.get("action_origin_owner_namespace", "")),
		str(cost_descriptor.get("action_origin_stable_object_id", "")),
		str(cost_descriptor.get("action_origin_receipt_key", "")),
		str(cost_descriptor.get("action_origin_boundary_id", "")),
		str(cost_descriptor.get("action_origin_fingerprint", ""))
	)
	var phase_conflict_run := RunStateScript.new()
	phase_conflict_run.from_dict(cost_run.to_dict())
	phase_conflict_run.scenario_finalize_base_semantics([disabled_presentation], library)
	phase_conflict_run.current_environment["scenario_sequence_state"]["command_receipt_records"][0]["envelope"]["expected_phase"] = "forged_phase"
	var phase_conflict := phase_conflict_run.scenario_sequence_command("prepare", "run_state:cost:once", {}, "scenario", "command_console", cost_host_availability, str(cost_descriptor.get("action_origin_owner_namespace", "")), str(cost_descriptor.get("action_origin_stable_object_id", "")), str(cost_descriptor.get("action_origin_receipt_key", "")), str(cost_descriptor.get("action_origin_boundary_id", "")), str(cost_descriptor.get("action_origin_fingerprint", "")))
	var cost_conflict_run := RunStateScript.new()
	cost_conflict_run.from_dict(cost_run.to_dict())
	cost_conflict_run.scenario_finalize_base_semantics([disabled_presentation], library)
	cost_conflict_run.current_environment["scenario_sequence_state"]["command_receipt_records"][0]["causal_action_descriptor"]["action"]["cost"] = 3
	var cost_conflict := cost_conflict_run.scenario_sequence_command("prepare", "run_state:cost:once", {}, "scenario", "command_console", cost_host_availability, str(cost_descriptor.get("action_origin_owner_namespace", "")), str(cost_descriptor.get("action_origin_stable_object_id", "")), str(cost_descriptor.get("action_origin_receipt_key", "")), str(cost_descriptor.get("action_origin_boundary_id", "")), str(cost_descriptor.get("action_origin_fingerprint", "")))
	var handler_conflict_run := RunStateScript.new()
	handler_conflict_run.from_dict(cost_run.to_dict())
	handler_conflict_run.scenario_finalize_base_semantics([disabled_presentation], library)
	handler_conflict_run.current_environment["scenario_sequence_state"]["command_receipt_records"][0]["causal_action_descriptor"]["action"]["inputs"]["amount"] = 2
	var handler_conflict := handler_conflict_run.scenario_sequence_command("prepare", "run_state:cost:once", {}, "scenario", "command_console", cost_host_availability, str(cost_descriptor.get("action_origin_owner_namespace", "")), str(cost_descriptor.get("action_origin_stable_object_id", "")), str(cost_descriptor.get("action_origin_receipt_key", "")), str(cost_descriptor.get("action_origin_boundary_id", "")), str(cost_descriptor.get("action_origin_fingerprint", "")))
	if not bool(accepted_cost.get("ok", false)) or bankroll_after_accept != 8 or not bool(replayed_cost.get("ok", false)) or not bool(replayed_cost.get("replayed", false)) or bool(rejected_cost.get("ok", true)) or bool(origin_conflict.get("ok", true)) or not bool(restored_cost_finalization.get("ok", false)) or not bool(restored_replay.get("ok", false)) or not bool(restored_replay.get("replayed", false)) or restored_cost_run.bankroll != bankroll_after_accept or bool(phase_conflict.get("ok", true)) or bool(cost_conflict.get("ok", true)) or bool(handler_conflict.get("ok", true)) or cost_run.bankroll != bankroll_after_accept or accepted_cost.has("cost_applied"):
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
		cost_host_availability,
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
		var engine_before_environment := JSON.stringify(engine_environment)
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
		if bool(engine_result.get("ok", true)) or _array(engine_result.get("errors", [])).is_empty() or JSON.stringify(engine_environment) != engine_before_environment:
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
	var expiry_recipient_before := JSON.stringify(expiry_recipient)
	var expiry_ingress := ScenarioEngineScript.sequence_command(expiry_recipient, expiry_transplant_definition, expiry_command, {"available_funds": 10})
	if not expiry_is_only_progress or expiry_can_rebind or bool(expiry_ingress.get("ok", true)) or not _contains_text(_array(expiry_ingress.get("errors", [])), "bound to another world node") or JSON.stringify(expiry_recipient) != expiry_recipient_before:
		failures.append("Expiry-only sequence progress transplanted across nodes and authorized ingress.")
	var production_projection := EnvironmentInteractionControllerScript.project_finalized_sequence_interaction_result(_array(finalized.get("records", [])), finalized)
	var projected_records := _array(production_projection.get("records", []))
	var projected_console: Dictionary = {}
	var projected_scene: Dictionary = {}
	for projected_value in projected_records:
		if typeof(projected_value) != TYPE_DICTIONARY: continue
		if str((projected_value as Dictionary).get("object_id", "")) == "scenario::command_console": projected_console = projected_value as Dictionary
		if str((projected_value as Dictionary).get("object_id", "")) == "scenario::fixture_100": projected_scene = projected_value as Dictionary
	if not bool(production_projection.get("ok", false)) or projected_console.is_empty() or str(projected_console.get("object_type", "")) != "scenario_sequence" or typeof(projected_console.get("focus_rect")) != TYPE_RECT2 or projected_console.get("focus_rect", Rect2()) == Rect2(0.1, 0.1, 0.12, 0.18) or _array(projected_console.get("scenario_sequence_actions", [])).size() != 2 or str(projected_console.get("scenario_layout_authority_identity", "")) != "scenario::command_console" or str(production_projection.get("layout_authority_digest", "")).length() != 64:
		failures.append("Final semantic interaction projection did not materialize the scenario command surface in the room UI.")
	if projected_scene.is_empty() or str(projected_scene.get("object_type", "")) != "scenario_scene_object" or bool(projected_scene.get("interactive", true)):
		failures.append("Final semantic projection did not materialize scenario scene objects alongside interactions.")
	var missing_layout_projection := EnvironmentInteractionControllerScript.project_sequence_interaction_result(_array(finalized.get("records", [])), run_state.scenario_sequence_projection())
	var missing_layout_records := _array(missing_layout_projection.get("records", []))
	if bool(missing_layout_projection.get("ok", true)) or _record_by_object_id(missing_layout_records, "game:slot").is_empty() or _record_by_object_id(missing_layout_records, "scenario::presentation_failure").is_empty() or not _array(_record_by_object_id(missing_layout_records, "scenario::presentation_failure").get("scenario_sequence_actions", [])).is_empty():
		failures.append("Validated/sealed production finalization bypassed its mandatory active room layout or did not fail visibly without scenario authority.")
	var forged_projection := run_state.scenario_sequence_projection()
	var forged_semantic := _dict(forged_projection.get("semantic_state", {}))
	var forged_interactions := _dict(forged_semantic.get("interactions", {}))
	forged_interactions["scenario::orphan_after_seal"] = _interaction_record("scenario", "orphan_after_seal", "Forged orphan", true)
	forged_semantic["interactions"] = forged_interactions
	forged_projection["semantic_state"] = forged_semantic
	var forged_projection_result := EnvironmentInteractionControllerScript.project_sequence_interaction_result(_array(finalized.get("records", [])), forged_projection, run_state.current_environment)
	if bool(forged_projection_result.get("ok", true)) or not _record_by_object_id(_array(forged_projection_result.get("records", [])), "scenario::orphan_after_seal").is_empty() or _record_by_object_id(_array(forged_projection_result.get("records", [])), "scenario::presentation_failure").is_empty():
		failures.append("A post-finalization orphan rectangle escaped sealed production projection authority.")
	var collision_record := _presentation_record("scenario::command_console", "info", "spoof", Rect2(0.84, 0.84, 0.04, 0.04))
	collision_record["owner_namespace"] = "base"
	collision_record["stable_object_id"] = "spoof"
	var collision_base_records := _array(finalized.get("records", [])).duplicate(true)
	collision_base_records.append(collision_record)
	var collision_result := EnvironmentInteractionControllerScript.project_sequence_interaction_result(collision_base_records, run_state.scenario_sequence_projection(), run_state.current_environment)
	var collision_projection := _array(collision_result.get("records", []))
	var collision_count := 0
	var collision_owner := ""
	var collision_preserved := false
	for collision_value in collision_projection:
		if str(_dict(collision_value).get("object_id", "")) == "scenario::command_console":
			collision_count += 1
			collision_owner = str(_dict(collision_value).get("owner_namespace", ""))
			collision_preserved = JSON.stringify(collision_value) == JSON.stringify(collision_record)
	var collision_identity_reason := false
	for collision_error_value in _array(collision_result.get("errors", [])):
		if "cannot alias a different owned identity" in str(collision_error_value):
			collision_identity_reason = true
	if bool(collision_result.get("ok", true)) or not collision_identity_reason or collision_count != 1 or collision_owner != "base" or not collision_preserved or _record_by_object_id(collision_projection, "scenario::presentation_failure").is_empty():
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
		{"scenario::command_console": true},
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
			var transplant_rejection_errors: Dictionary = {}
			var progressed_state_before := JSON.stringify(progressed_state)
			for ingress_kind in ["command", "fact"]:
				var node_transplant := RunStateScript.new()
				node_transplant.current_environment = recipient_environment.duplicate(true)
				var recipient_before := JSON.stringify(node_transplant.current_environment)
				var ingress_result: Dictionary = node_transplant.scenario_sequence_command("finish", "node-binding:command", {}, "scenario", "command_console") if ingress_kind == "command" else node_transplant.scenario_enqueue_fact("world_boundary", "scenario", {"amount": 1, "action_index": 0}, "node-binding:fact")
				var rejection_errors := _array(ingress_result.get("errors", []))
				transplant_rejection_errors[ingress_kind] = rejection_errors.duplicate(true)
				if bool(ingress_result.get("ok", true)) or int(ingress_result.get("cost", 0)) != 0 or ingress_result.has("bankroll_delta") or not _contains_text(rejection_errors, "bound to another world node") or JSON.stringify(node_transplant.current_environment) != recipient_before:
					failures.append("Progressed sequence state transplanted to another current node advanced through %s ingress." % ingress_kind)
			var command_errors := _array(transplant_rejection_errors.get("command", []))
			var fact_errors := _array(transplant_rejection_errors.get("fact", []))
			if SequenceRuntimeScript.content_fingerprint(command_errors) != SequenceRuntimeScript.content_fingerprint(fact_errors) or JSON.stringify(command_errors).contains("recipient_node") or JSON.stringify(progressed_state) != progressed_state_before:
				failures.append("Node-binding quarantine was not exactly-once, save-stable, or free of recipient hidden-state leakage.")
			var hostile_candidate := recipient_environment.duplicate(true)
			var hostile_state := progressed_state.duplicate(true)
			hostile_state["status"] = SequenceRuntimeScript.STATUS_CLEANED
			hostile_state["errors"] = ["scenario progressed sequence state is bound to another world node; explicit migration is required"]
			hostile_candidate["scenario_sequence_state"] = hostile_state
			var same_node_host := RunStateScript.new()
			same_node_host.current_environment = progressed_donor.current_environment.duplicate(true)
			if not same_node_host._scenario_node_binding_quarantine_state(hostile_candidate, definition).is_empty():
				failures.append("A hostile fake-CLEANED candidate bypassed exact node-binding quarantine reproduction.")
	var saved := RunStateScript._environment_for_persistent_storage(run_state.current_environment)
	var saved_semantic := _dict(_dict(saved.get("scenario_sequence_state", {})).get("semantic_state", {}))
	if str(saved.get("scenario_restore_contract", "")) != RunStateScript.ENV06_6B_SEMANTIC_RESTORE_EQUIVALENCE_V1 \
		or not bool(saved.get("scenario_semantic_ready", false)) \
		or _dict(saved.get("scenario_semantic_inventory", {})).is_empty() \
		or _array(saved.get("scenario_base_interactions", [])).is_empty() \
		or _dict(saved.get("scenario_event_choices", {})).is_empty() \
		or _array(saved_semantic.get("base_interactions", [])).is_empty() \
		or saved.has("scenario_sequence_projection") \
		or saved.has("scenario_render_snapshot") \
		or not RunStateScript.scenario_restore_equivalent(run_state.current_environment, saved):
		failures.append("Save serialization did not preserve the named exact causal/authority restore contract while stripping only derived projection caches.")
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
	if SequenceSchemaScript.initial_phase_id(definition) != "arrival" or SequenceSchemaScript.phase_ids(definition) != ["arrival", "complication", "aftermath"]:
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


static func _check_public_projection_privacy(failures: Array) -> void:
	var definition := _fixture_definition()
	definition["sequence"]["local_state_schema"]["pressure"]["visibility"] = "public"
	definition["sequence"]["local_state_schema"]["protected_exit"]["visibility"] = "private"
	definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(definition)
	var state := SequenceRuntimeScript.initial_state(definition, "bar_node", "privacy_fixture", _fixture_host_semantics(definition))
	state["local_state"]["pressure"] = 3
	state["local_state"]["protected_exit"] = true
	var initial_drain := SequenceRuntimeScript.drain_transitions(state, definition)
	if not bool(initial_drain.get("ok", false)) or _array(initial_drain.get("transitions", [])).size() != 1:
		failures.append("Projection privacy fixture did not explicitly drain its one authored initial transition.")
		return
	state = _dict(initial_drain.get("state", {}))
	var semantic := _dict(state.get("semantic_state", {}))
	var transition_operation := _operation_fixture("transition_ops", "feedback", 777)
	transition_operation["message"] = "Visible feedback"
	var applied := OperationRegistryScript.apply_operations(semantic, "transition_ops", [transition_operation], "privacy:node:phase:arrival")
	state["semantic_state"] = _dict(applied.get("state", semantic))
	state["active_stages"] = [{"stage_id": "visible_stage", "message": "Visible stage", "started_boundary": 1, "expires_boundary": 2, "receipt_id": "hidden_stage_receipt", "operation_fingerprint": "f".repeat(64)}]
	var projection := SequenceRuntimeScript.public_projection(state, definition)
	var public_semantic := _dict(projection.get("semantic_state", {}))
	var public_text := JSON.stringify(projection)
	if not bool(applied.get("ok", false)) or _dict(projection.get("local_state", {})) != {"pressure": 3} or public_semantic.has("transition_queue") or public_semantic.has("operation_receipts") or public_semantic.has("operation_receipt_records") or public_text.contains("transition_feedback_777") or public_text.contains("hidden_stage_receipt") or int(projection.get("pending_transition_count", -1)) != 1:
		failures.append("Public sequence projection leaked private branch state or operation queue/receipt metadata instead of exposing only opted-in local state and pending counts.")
	var drained := SequenceRuntimeScript.drain_transitions(state, definition)
	var delivered := _dict(_array(drained.get("transitions", []))[0]) if not _array(drained.get("transitions", [])).is_empty() else {}
	if not bool(drained.get("ok", false)) or delivered != {"op": "feedback", "message": "Visible feedback", "duration_boundaries": 0} or JSON.stringify(delivered).contains("receipt"):
		failures.append("Delivered transition projection did not use the closed public DTO or leaked its internal receipt metadata.")


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
	var create_operations := {"scene_ops": "spawn", "interaction_ops": "add", "actor_ops": "spawn", "service_ops": "add", "game_ops": "add"}
	for create_family_value in create_operations.keys():
		var create_family := str(create_family_value)
		var conflicting_create := _operation_fixture(create_family, str(create_operations.get(create_family, "")), 0)
		var payload_key := "interaction" if create_family == "interaction_ops" else ("actor" if create_family == "actor_ops" else "object")
		var conflicting_payload := _dict(conflicting_create.get(payload_key, {}))
		conflicting_payload["label"] = "Conflicting replay"
		conflicting_create[payload_key] = conflicting_payload
		var create_conflict := OperationRegistryScript.apply_operations(state, create_family, [conflicting_create], "fixture:node:phase:%s" % create_family)
		if bool(create_conflict.get("ok", true)) or not _contains_text(_array(create_conflict.get("errors", [])), "conflicting content") or JSON.stringify(create_conflict.get("state", {})) != JSON.stringify(state):
			failures.append("Registered %s create replay did not reject conflicting content atomically." % create_family)
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
	if bool(competing_result.get("ok", true)) \
		or competing_records.size() != 1 \
		or bool(_dict(competing_records[0]).get("enabled", true)) \
		or _array(competing_result.get("accepted_overlay_source_identities", [])) != ["scenario::exit_gate"] \
		or not _contains_text(_array(competing_result.get("errors", [])), "target claim loser scenario::exit_gate_two"):
		failures.append("Equal-priority competing overlays did not retain only the canonical first winner with a typed loser error.")
	_check_competing_interaction_overlay_priorities(failures)


static func _check_competing_interaction_overlay_priorities(failures: Array) -> void:
	for mode_value in ["gate", "replace", "augment", "retarget"]:
		var mode := str(mode_value)
		var target_id := "priority_%s" % mode
		var base := [_interaction_record("base", target_id, "Priority target", true)]
		var overlays := [
			_priority_overlay("event", mode, "base", target_id, "event"),
			_priority_overlay("sweep", mode, "base", target_id, "sweep"),
			_priority_overlay("scenario", mode, "base", target_id, "scenario"),
		]
		if mode == "augment":
			overlays[1]["operation_receipt_key"] = "priority:fixture:interaction_ops:sweep_augment"
			overlays[1]["operation_boundary_id"] = "priority:fixture:phase:augment"
			overlays[1]["operation_fingerprint"] = "a".repeat(64)
		var reversed_overlays := overlays.duplicate(true)
		reversed_overlays.reverse()
		var resolved := OperationRegistryScript.resolve_interactions(base, overlays)
		var reversed := OperationRegistryScript.resolve_interactions(base, reversed_overlays)
		if JSON.stringify(resolved) != JSON.stringify(reversed):
			failures.append("Competing %s overlays depended on caller order." % mode)
		var reloaded_value: Variant = JSON.parse_string(JSON.stringify(resolved))
		var reloaded := _dict(reloaded_value)
		if reloaded.is_empty() \
			or _array(reloaded.get("errors", [])) != _array(resolved.get("errors", [])) \
			or _array(reloaded.get("accepted_overlay_source_identities", [])) != _array(resolved.get("accepted_overlay_source_identities", [])) \
			or _array(reloaded.get("records", [])).size() != _array(resolved.get("records", [])).size() \
			or OperationRegistryScript.identity_from(_dict(_array(reloaded.get("records", []))[0])) != OperationRegistryScript.identity_from(_dict(_array(resolved.get("records", []))[0])):
			failures.append("Competing %s overlay arbitration did not survive an exact save/reload round trip." % mode)
		var accepted := _array(resolved.get("accepted_overlay_source_identities", []))
		var records := _array(resolved.get("records", []))
		if bool(resolved.get("ok", true)) or accepted != ["sweep::sweep_%s" % mode] or records.size() != 1 \
			or not _contains_text(_array(resolved.get("errors", [])), "canonical winner is sweep::sweep_%s" % mode):
			failures.append("Competing %s overlays did not preserve only the sweep-priority winner." % mode)
			continue
		var record := _dict(records[0])
		for private_key in ["effective_priority", "effective_owner_namespace", "effective_winner", "source_key", "accepted_overlay_source_identities"]:
			if record.has(private_key):
				failures.append("Competing %s overlay leaked reducer-private winner metadata %s." % [mode, private_key])
		match mode:
			"gate":
				if bool(record.get("enabled", true)) or str(record.get("disabled_reason", "")) != "sweep wins gate":
					failures.append("Lower-priority gate overwrote the sweep gate.")
			"replace":
				if OperationRegistryScript.identity_from(record) != "sweep::sweep_replace" or str(record.get("label", "")) != "sweep wins replace":
					failures.append("Lower-priority replacement displaced the sweep replacement identity.")
			"augment":
				var action_ids: Array = []
				for action_value in _array(record.get("available_actions", [])):
					action_ids.append(str(_dict(action_value).get("id", "")))
				var winner_action := _dict(_array(record.get("available_actions", []))[1])
				var reloaded_action := _dict(_array(_dict(_array(reloaded.get("records", []))[0]).get("available_actions", []))[1])
				if action_ids != ["use", "sweep_action"] \
					or str(winner_action.get("action_origin_receipt_key", "")) != "priority:fixture:interaction_ops:sweep_augment" \
					or str(winner_action.get("action_origin_boundary_id", "")) != "priority:fixture:phase:augment" \
					or str(winner_action.get("action_origin_fingerprint", "")) != "a".repeat(64) \
					or reloaded_action != winner_action:
					failures.append("Lower-priority augment leaked into the winning action set: %s." % JSON.stringify(action_ids))
			"retarget":
				if str(record.get("source_id", "")) != "sweep_source":
					failures.append("Lower-priority retarget overwrote the sweep retarget.")

	var replacement := _priority_overlay("sweep", "replace", "base", "replacement_target", "sweep")
	var replacement_challenger := _priority_overlay("scenario", "gate", "sweep", "sweep_replace", "scenario")
	var replacement_result := OperationRegistryScript.resolve_interactions(
		[_interaction_record("base", "replacement_target", "Replacement target", true)],
		[replacement_challenger, replacement],
	)
	var replacement_records := _array(replacement_result.get("records", []))
	if bool(replacement_result.get("ok", true)) \
		or _array(replacement_result.get("accepted_overlay_source_identities", [])) != ["sweep::sweep_replace"] \
		or replacement_records.size() != 1 \
		or OperationRegistryScript.identity_from(_dict(replacement_records[0])) != "sweep::sweep_replace" \
		or not _contains_text(_array(replacement_result.get("errors", [])), "owned by sweep"):
		failures.append("Replacement winner precedence did not follow its public source identity.")

	var collision_base := _interaction_record("base", "augment_collision", "Collision target", true)
	collision_base["available_actions"] = [{"id": "activate", "label": "Activate", "input_action": "confirm", "non_color_state": "ready"}]
	var base_collision := _priority_overlay("sweep", "augment", "base", "augment_collision", "sweep")
	base_collision["available_actions"] = [
		{"id": "activate", "label": "Colliding activate", "input_action": "confirm", "non_color_state": "ready"},
		{"id": "sweep_unique", "label": "Sweep unique", "input_action": "confirm", "non_color_state": "ready"},
	]
	var base_collision_result := OperationRegistryScript.resolve_interactions([collision_base], [base_collision])
	var base_collision_record := _dict(_array(base_collision_result.get("records", []))[0])
	if bool(base_collision_result.get("ok", true)) \
		or not _array(base_collision_result.get("accepted_overlay_source_identities", [])).is_empty() \
		or _array(base_collision_record.get("available_actions", [])).size() != 1 \
		or JSON.stringify(base_collision_record).contains("sweep_unique"):
		failures.append("Base-action collision did not reject the whole augment atomically.")

	var equal_a := _priority_overlay("scenario", "augment", "base", "equal_augment", "equal")
	equal_a["stable_object_id"] = "a_equal_augment"
	equal_a["available_actions"] = [{"id": "duplicate_action", "label": "A duplicate", "input_action": "confirm", "non_color_state": "ready"}]
	var equal_z := equal_a.duplicate(true)
	equal_z["stable_object_id"] = "z_equal_augment"
	equal_z["available_actions"] = [{"id": "duplicate_action", "label": "Z duplicate", "input_action": "confirm", "non_color_state": "ready"}]
	var equal_base := _interaction_record("base", "equal_augment", "Equal target", true)
	var equal_forward := OperationRegistryScript.resolve_interactions([equal_base], [equal_z, equal_a])
	var equal_reverse := OperationRegistryScript.resolve_interactions([equal_base], [equal_a, equal_z])
	var equal_record := _dict(_array(equal_forward.get("records", []))[0])
	if JSON.stringify(equal_forward) != JSON.stringify(equal_reverse) \
		or bool(equal_forward.get("ok", true)) \
		or _array(equal_forward.get("accepted_overlay_source_identities", [])) != ["scenario::a_equal_augment"] \
		or _array(equal_record.get("available_actions", [])).size() != 2 \
		or not _contains_text(_array(equal_forward.get("errors", [])), "target claim loser scenario::z_equal_augment"):
		failures.append("Same-priority duplicate augment action did not preserve the deterministic first winner/error.")


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
	var unscoped_event_fact := _fixture_definition()
	unscoped_event_fact["sequence"]["fact_subscriptions"][0] = "event_result"
	if not _contains_text(SequenceSchemaScript.validate_definition(unscoped_event_fact, OperationRegistryScript), "payload_equals.event_id"):
		failures.append("Sequence schema accepted an event-result subscription without an event-id payload predicate.")
	var unknown_event_field := _fixture_definition()
	unknown_event_field["sequence"]["fact_subscriptions"][0]["payload_equals"] = {"event_id": "fixture_event", "invented": "collision"}
	if not _contains_text(SequenceSchemaScript.validate_definition(unknown_event_field, OperationRegistryScript), "unknown event_result field"):
		failures.append("Sequence schema accepted an unregistered event-result predicate field.")
	var wrong_event_type := _fixture_definition()
	wrong_event_type["sequence"]["fact_subscriptions"][0]["payload_equals"] = {"event_id": "fixture_event", "resolved": "yes"}
	if not _contains_text(SequenceSchemaScript.validate_definition(wrong_event_type, OperationRegistryScript), "wrong type"):
		failures.append("Sequence schema accepted a wrong-type event-result predicate.")
	var invalid_happening_predicate := _fixture_definition()
	invalid_happening_predicate["sequence"]["fact_subscriptions"].append({"fact_type": "town_transition", "payload_equals": {"happening_ids": ["roadwork", "roadwork"]}})
	if not _contains_text(SequenceSchemaScript.validate_definition(invalid_happening_predicate, OperationRegistryScript), "unique stable strings"):
		failures.append("Sequence schema accepted an unreachable town-happening payload predicate.")
	var unscoped_event_branch := _fixture_definition()
	unscoped_event_branch["sequence"]["phase_graph"]["phases"][0]["branches"][0]["condition"] = {"type": "fact", "fact_type": "event_result"}
	if not _contains_text(SequenceSchemaScript.validate_definition(unscoped_event_branch, OperationRegistryScript), "payload_equals.event_id"):
		failures.append("Sequence schema accepted an event-result branch without an event-id payload predicate.")
	var empty_event_bridge := _runtime_definition()
	empty_event_bridge["sequence"]["phase_graph"]["phases"][0]["interaction_ops"][1]["interaction"]["available_actions"][0]["handler"] = "event_bridge"
	empty_event_bridge["sequence"]["phase_graph"]["phases"][0]["interaction_ops"][1]["interaction"]["available_actions"][0]["inputs"] = {"event_id": "fixture_event", "resolution_id": ""}
	if not _contains_text(SequenceSchemaScript.validate_definition(empty_event_bridge, OperationRegistryScript), "non-empty stable event_id and resolution_id"):
		failures.append("Sequence schema accepted an event bridge without a durable resolution id.")
	var broad_only_event_bridge := _runtime_definition()
	broad_only_event_bridge["sequence"]["phase_graph"]["phases"][0]["interaction_ops"][1]["interaction"]["available_actions"][0]["handler"] = "event_bridge"
	broad_only_event_bridge["sequence"]["phase_graph"]["phases"][0]["interaction_ops"][1]["interaction"]["available_actions"][0]["inputs"] = {"event_id": "fixture_event", "resolution_id": "fixture_resolution"}
	var broad_bridge_errors := SequenceSchemaScript.validate_definition(broad_only_event_bridge, OperationRegistryScript)
	if not _contains_text(broad_bridge_errors, "requires an exact event_result authorizer"):
		failures.append("Sequence schema accepted a correlated event bridge with only broad observers.")
	var exact_event_bridge := broad_only_event_bridge.duplicate(true)
	exact_event_bridge["sequence"]["fact_subscriptions"].append({
		"fact_type": "event_result",
		"payload_equals": {"event_id": "fixture_event", "choice_id": "accept", "resolution_id": "fixture_resolution", "resolved": true, "ok": true},
	})
	if _contains_text(SequenceSchemaScript.validate_definition(exact_event_bridge, OperationRegistryScript), "requires an exact event_result authorizer"):
		failures.append("Sequence schema rejected a correlated event bridge with an exact authored result predicate.")
	var dead_end := _fixture_definition()
	dead_end["sequence"]["phase_graph"]["phases"][0]["branches"] = []
	if not _contains_text(SequenceSchemaScript.validate_definition(dead_end, OperationRegistryScript), "dead end"):
		failures.append("Sequence schema accepted a non-terminal dead end.")
	var duplicate_branch := _fixture_definition()
	var duplicate_phase_branches := _array(duplicate_branch["sequence"]["phase_graph"]["phases"][2].get("branches", []))
	assert(duplicate_phase_branches.size() >= 2, "Duplicate-branch negative fixture requires two authored terminal branches.")
	duplicate_phase_branches[1]["id"] = str(duplicate_phase_branches[0].get("id", ""))
	duplicate_branch["sequence"]["phase_graph"]["phases"][2]["branches"] = duplicate_phase_branches
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
		["missing interaction", SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "bad:absent", {}, "scenario", "absent_console")],
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
		if bool(rejected.get("ok", true)) or not _contains_text(_array(rejected.get("errors", [])), str(fixture[0])) or JSON.stringify(rejected.get("state", {})) != JSON.stringify(initial):
			failures.append("Sequence command hostile case was not rejected for %s." % str(fixture[0]))
	var unaffordable := SequenceRuntimeScript.apply_command(initial, definition, prepare, {"available_funds": 1})
	if bool(unaffordable.get("ok", true)) or not _contains_text(_array(unaffordable.get("errors", [])), "not payable"):
		failures.append("Sequence command trusted caller cost or skipped authored affordability.")
	var finish_too_soon := _runtime_command(initial, definition, "finish", "bar_node", "arrival", "command:finish:early", {}, "scenario", "command_console")
	if bool(SequenceRuntimeScript.apply_command(initial, definition, finish_too_soon, {"available_funds": 10}).get("ok", true)):
		failures.append("Sequence command skipped an authored objective precondition.")
	var repaired_state := _with_live_aftermath_authority(applied_state, "repaired")
	var finish := _runtime_command(repaired_state, definition, "finish", "bar_node", "complication", "command:finish:1", {}, "scenario", "command_console")
	var finished := SequenceRuntimeScript.apply_command(repaired_state, definition, finish, {"available_funds": 10})
	if not bool(finished.get("ok", false)) or str(_dict(finished.get("state", {})).get("phase_id", "")) != "aftermath":
		failures.append("Explicit command branch did not enter the authored next phase.")
	else:
		_check_clean_branch_state(_dict(finished.get("state", {})), definition, "repaired", "scenario::fixture_101", failures)


static func _check_mutually_exclusive_branch_cleanup(failures: Array) -> void:
	var hostile_definition := _runtime_definition()
	var hostile_state := _prepared_fixture_state(hostile_definition, "broken_missing_target", failures)
	var hostile_semantic := _dict(hostile_state.get("semantic_state", {}))
	for authority_key in ["declared_targets", "target_inventory"]:
		var hostile_authority := _dict(hostile_semantic.get(authority_key, {}))
		var hostile_scene_targets := _array(hostile_authority.get("scene_objects", []))
		hostile_scene_targets.erase("scenario::fixture_102")
		hostile_authority["scene_objects"] = hostile_scene_targets
		hostile_semantic[authority_key] = hostile_authority
	hostile_state["semantic_state"] = hostile_semantic
	var hostile_fact := SequenceRuntimeScript.fact("heat_changed", "heat", "bar_node", "branch:broken:missing", 1, 1, _fact_payload("heat_changed"))
	var hostile_queued := SequenceRuntimeScript.enqueue_fact(hostile_state, hostile_definition, hostile_fact)
	var hostile_queued_state := _dict(hostile_queued.get("state", {}))
	var hostile_result := SequenceRuntimeScript.flush_facts(hostile_queued_state, hostile_definition, 1)
	var hostile_rejected_state := _dict(hostile_result.get("state", {}))
	if not bool(hostile_queued.get("ok", false)) or bool(hostile_queued.get("duplicate", true)) or not _array(hostile_queued.get("errors", [])).is_empty() or bool(hostile_result.get("ok", true)) or not _contains_text(_array(hostile_result.get("errors", [])), "missing scenario identity scenario::fixture_102") or not _array(hostile_result.get("processed", [])).is_empty() or SequenceRuntimeScript.content_fingerprint(hostile_rejected_state) != SequenceRuntimeScript.content_fingerprint(SequenceRuntimeScript.normalize_state(hostile_queued_state, hostile_definition)):
		failures.append("Missing aftermath target hostile fixture was not rejected atomically with its typed error.")

	var definition := _runtime_definition()
	var broken_state := _with_live_aftermath_authority(_prepared_fixture_state(definition, "broken_seed", failures), "broken")
	var prior_branch_records := _array(broken_state.get("branch_resolution_records", []))
	var broken_fact := SequenceRuntimeScript.fact("heat_changed", "heat", "bar_node", "branch:broken", 1, 1, _fact_payload("heat_changed"))
	var broken_queued := SequenceRuntimeScript.enqueue_fact(broken_state, definition, broken_fact)
	var broken_result := SequenceRuntimeScript.flush_facts(_dict(broken_queued.get("state", {})), definition, 1)
	var broken_final := _dict(broken_result.get("state", {}))
	var branch_records := _array(broken_final.get("branch_resolution_records", []))
	var new_branch_records := branch_records.slice(prior_branch_records.size())
	if not bool(broken_queued.get("ok", false)) or bool(broken_queued.get("duplicate", true)) or not _array(broken_queued.get("errors", [])).is_empty() or not bool(broken_result.get("ok", false)) or not _array(broken_result.get("errors", [])).is_empty() or _array(broken_result.get("processed", [])) != ["branch:broken"] or _array(broken_final.get("fact_receipts", [])) != ["branch:broken"] or prior_branch_records.size() != 1 or str(_dict(prior_branch_records[0]).get("branch_id", "")) != "continue" or str(_dict(prior_branch_records[0]).get("trigger_kind", "")) != "command" or new_branch_records.size() != 2 or str(_dict(new_branch_records[0]).get("branch_id", "")) != "complication_break" or str(_dict(new_branch_records[0]).get("trigger_kind", "")) != "fact" or str(_dict(new_branch_records[0]).get("trigger_receipt_key", "")) != "branch:broken" or str(_dict(new_branch_records[1]).get("branch_id", "")) != "break" or str(_dict(new_branch_records[1]).get("trigger_kind", "")) != "fact" or str(_dict(new_branch_records[1]).get("trigger_receipt_key", "")) != "branch:broken":
		failures.append("Broken branch did not preserve its exact enqueue/flush/receipt/two-branch causal record.")
	_check_clean_branch_state(_dict(broken_result.get("state", {})), definition, "broken", "scenario::fixture_102", failures)

	var refused_definition := _runtime_definition()
	var refused_state := _with_live_aftermath_authority(_prepared_fixture_state(refused_definition, "refused_seed", failures), "refused")
	var refused_command := _runtime_command(refused_state, refused_definition, "refuse", "bar_node", "complication", "branch:refused", {}, "scenario", "command_console")
	var refused_result := SequenceRuntimeScript.apply_command(refused_state, refused_definition, refused_command, {"available_funds": 0})
	if not bool(refused_result.get("ok", false)):
		failures.append("Refused terminal branch could not be exercised: %s" % JSON.stringify(refused_result.get("errors", [])))
	else:
		_check_clean_branch_state(_dict(refused_result.get("state", {})), refused_definition, "refused", "scenario::fixture_103", failures)


static func _check_boundary_provenance(failures: Array) -> void:
	var definition := _runtime_definition()
	var command_state := _prepared_fixture_state(definition, "command_boundary_seed", failures)
	var first_boundary := SequenceRuntimeScript.fact("world_boundary", "scenario", "bar_node", "command:boundary:1", 1, 1, {"amount": 1, "action_index": 1})
	var first_queued := SequenceRuntimeScript.enqueue_fact(command_state, definition, first_boundary)
	var first_result := SequenceRuntimeScript.flush_facts(_dict(first_queued.get("state", {})), definition, 1)
	var first_state := _dict(first_result.get("state", {}))
	if not bool(first_result.get("ok", false)) or str(first_state.get("phase_id", "")) != "complication" or int(first_state.get("phase_action_counter", -1)) != 0 or int(first_state.get("phase_boundary_grace", -1)) != 0:
		failures.append("Command-entered phase did not consume exactly its immediate turn-boundary grace.")
	var second_boundary := SequenceRuntimeScript.fact("world_boundary", "scenario", "bar_node", "command:boundary:2", 2, 2, {"amount": 1, "action_index": 2})
	var second_queued := SequenceRuntimeScript.enqueue_fact(first_state, definition, second_boundary)
	var second_result := SequenceRuntimeScript.flush_facts(_dict(second_queued.get("state", {})), definition, 2)
	if not bool(second_result.get("ok", false)) or str(_dict(second_result.get("state", {})).get("phase_id", "")) != "aftermath":
		failures.append("Command-entered phase skipped the next legitimate world boundary after grace.")

	var fact_definition := definition.duplicate(true)
	var sequence := _dict(fact_definition.get("sequence", {}))
	var graph := _dict(sequence.get("phase_graph", {}))
	var phases := _array(graph.get("phases", []))
	var arrival := _dict(phases[0])
	arrival["branches"] = [{"id": "travel_into_complication", "condition": {"type": "fact", "fact_type": "travel_arrived"}, "next_phase": "complication"}]
	phases[0] = arrival
	var complication := _dict(phases[1])
	complication["branches"] = [{"id": "fact_boundary_settle", "condition": {"type": "fact", "fact_type": "world_boundary"}, "next_phase": "aftermath"}]
	complication["advance_after_actions"] = 1
	phases[1] = complication
	graph["phases"] = phases
	sequence["phase_graph"] = graph
	sequence["fact_subscriptions"] = _array(sequence.get("fact_subscriptions", [])) + ["travel_arrived", "world_boundary"]
	fact_definition["sequence"] = sequence
	fact_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(fact_definition)
	var fact_state := SequenceRuntimeScript.initial_state(fact_definition, "bar_node", "fact_boundary_seed", _fixture_host_semantics(fact_definition))
	var travel_fact := SequenceRuntimeScript.fact("travel_arrived", "travel", "bar_node", "fact:travel:1", 1, 1, {"source_id": "street", "target_id": "bar_node", "travel_kind": "walk"})
	var travel_queued := SequenceRuntimeScript.enqueue_fact(fact_state, fact_definition, travel_fact)
	var travel_result := SequenceRuntimeScript.flush_facts(_dict(travel_queued.get("state", {})), fact_definition, 1)
	var arrived_state := _dict(travel_result.get("state", {}))
	if not bool(travel_result.get("ok", false)) or str(arrived_state.get("phase_id", "")) != "complication" or int(arrived_state.get("phase_boundary_grace", -1)) != 0:
		failures.append("Fact-entered phase incorrectly inherited command turn-boundary grace.")
	var fact_boundary := SequenceRuntimeScript.fact("world_boundary", "scenario", "bar_node", "fact:boundary:2", 2, 2, {"amount": 1, "action_index": 2})
	var fact_boundary_queued := SequenceRuntimeScript.enqueue_fact(arrived_state, fact_definition, fact_boundary)
	var fact_boundary_result := SequenceRuntimeScript.flush_facts(_dict(fact_boundary_queued.get("state", {})), fact_definition, 2)
	if not bool(fact_boundary_result.get("ok", false)) or str(_dict(fact_boundary_result.get("state", {})).get("phase_id", "")) != "aftermath":
		failures.append("Fact-entered phase lost its next legitimate world boundary.")


static func _check_augment_availability(failures: Array) -> void:
	var definition := _runtime_definition()
	var sequence := _dict(definition.get("sequence", {}))
	var graph := _dict(sequence.get("phase_graph", {}))
	var phases := _array(graph.get("phases", []))
	var arrival := _dict(phases[0])
	var augment_operation := _operation_fixture("interaction_ops", "augment", 5)
	arrival["interaction_ops"] = _array(arrival.get("interaction_ops", [])) + [augment_operation]
	phases[0] = arrival
	graph["phases"] = phases
	sequence["phase_graph"] = graph
	var declared_targets := _dict(sequence.get("declared_targets", {}))
	declared_targets["interactions"] = _array(declared_targets.get("interactions", [])) + ["base::fixture_target_5"]
	sequence["declared_targets"] = declared_targets
	var cleanup := _dict(sequence.get("cleanup", {}))
	var cleanup_operations := _array(cleanup.get("operations", []))
	var cleanup_augment := augment_operation.duplicate(true)
	cleanup_augment["receipt_id"] = "cleanup_augment_fixture_5"
	cleanup_operations.append(cleanup_augment)
	cleanup["operations"] = cleanup_operations
	sequence["cleanup"] = cleanup
	definition["sequence"] = sequence
	definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(definition)
	var host_semantics := _fixture_host_semantics(definition)
	var target_inventory := _dict(host_semantics.get("target_inventory", {}))
	target_inventory["interactions"] = _array(target_inventory.get("interactions", [])) + ["base::fixture_target_5"]
	host_semantics["target_inventory"] = target_inventory
	host_semantics["base_interactions"] = [_interaction_record("base", "fixture_target_5", "Fixture target 5", true)]
	var state := SequenceRuntimeScript.initial_state(definition, "bar_node", "augment_seed", host_semantics)
	var command := _runtime_command(state, definition, "fixture_action", "bar_node", "arrival", "augment:fixture:1", {}, "base", "fixture_target_5")
	var target_identity := "base::fixture_target_5"
	var disabled_availability: Dictionary = {}
	disabled_availability[target_identity] = false
	var disabled := SequenceRuntimeScript.apply_command(state, definition, command, {"available_funds": 0, "host_interaction_availability": disabled_availability})
	if bool(disabled.get("ok", true)) or not _contains_text(_array(disabled.get("errors", [])), "disabled"):
		failures.append("Scenario augment command bypassed an unavailable authoritative host target.")
	var enabled_availability := disabled_availability.duplicate(true)
	enabled_availability[target_identity] = true
	var enabled := SequenceRuntimeScript.apply_command(state, definition, command, {"available_funds": 0, "host_interaction_availability": enabled_availability})
	if not bool(enabled.get("ok", false)):
		failures.append("Scenario augment command could not execute against an available authoritative host target.")
	var unsealed_state := state.duplicate(true)
	var unsealed_semantic := _dict(unsealed_state.get("semantic_state", {}))
	unsealed_semantic["base_interactions"] = []
	unsealed_state["semantic_state"] = unsealed_semantic
	var forged_enabled := SequenceRuntimeScript.apply_command(unsealed_state, definition, command, {"available_funds": 0, "host_interaction_availability": enabled_availability})
	if bool(forged_enabled.get("ok", true)):
		failures.append("Caller proposal true granted an augment after sealed host authority was removed.")


static func _prepared_fixture_state(definition: Dictionary, seed_token: String, failures: Array) -> Dictionary:
	var state := SequenceRuntimeScript.initial_state(definition, "bar_node", seed_token, _fixture_host_semantics(definition))
	var prepare := _runtime_command(state, definition, "prepare", "bar_node", "arrival", "branch:prepare:%s" % seed_token, {}, "scenario", "command_console")
	var result := SequenceRuntimeScript.apply_command(state, definition, prepare, {"available_funds": 2})
	var prepared := _dict(result.get("state", {}))
	if not bool(result.get("ok", false)) or str(prepared.get("phase_id", "")) != "complication" or str(prepared.get("status", "")) != SequenceRuntimeScript.STATUS_ACTIVE:
		failures.append("Terminal branch fixture did not reach complication through the public command API: %s" % JSON.stringify(result.get("errors", [])))
	return prepared


static func _with_live_aftermath_authority(state_value: Dictionary, outcome: String) -> Dictionary:
	var state := state_value.duplicate(true)
	var semantic := _dict(state.get("semantic_state", {}))
	match outcome:
		"repaired", "broken":
			var suffix := "101" if outcome == "repaired" else "102"
			var scene_objects := _dict(semantic.get("scene_objects", {}))
			scene_objects["scenario::fixture_%s" % suffix] = {"owner_namespace": "scenario", "stable_object_id": "fixture_%s" % suffix, "anchor_id": "bar_floor_100", "state": "baseline", "appearance": "baseline"}
			semantic["scene_objects"] = scene_objects
			var routes := _dict(semantic.get("routes", {}))
			routes["scenario::fixture_%s" % suffix] = {"owner_namespace": "scenario", "stable_object_id": "fixture_%s" % suffix, "enabled": true, "source_id": "fixture_%s" % suffix}
			semantic["routes"] = routes
		"refused":
			var actors := _dict(semantic.get("actors", {}))
			actors["scenario::fixture_103"] = {"owner_namespace": "scenario", "stable_object_id": "fixture_103", "actor_id": "actor_fixture", "behavior": "idle"}
			semantic["actors"] = actors
			var services := _dict(semantic.get("services", {}))
			services["scenario::fixture_103"] = {"owner_namespace": "scenario", "stable_object_id": "fixture_103", "id": "fixture_103", "label": "Fixture service", "enabled": true}
			semantic["services"] = services
	state["semantic_state"] = OperationRegistryScript.normalize_semantic_state(semantic)
	return state


static func _check_clean_branch_state(state: Dictionary, definition: Dictionary, outcome: String, aftermath_identity: String, failures: Array) -> void:
	if str(state.get("status", "")) != SequenceRuntimeScript.STATUS_AFTERMATH or _array(state.get("resolved_outcomes", [])) != [outcome]:
		failures.append("Mutually exclusive %s branch did not resolve to persistent aftermath." % outcome)
		return
	var semantic := _dict(state.get("semantic_state", {}))
	for collection_name in ["scene_objects", "interactions", "actors"]:
		var collection := _dict(semantic.get(collection_name, {}))
		for temporary_identity in ["scenario::fixture_100", "scenario::fixture_104", "scenario::fixture_105", "scenario::command_console"]:
			if collection.has(temporary_identity):
				failures.append("Mutually exclusive %s branch left temporary %s in %s." % [outcome, temporary_identity, collection_name])
	var material_collections := ["scene_objects", "actors", "routes", "services", "games", "interactions"]
	var expected_present := false
	for collection_name in material_collections:
		if _dict(semantic.get(collection_name, {})).has(aftermath_identity): expected_present = true
	if not expected_present:
		failures.append("Mutually exclusive %s branch lost its material aftermath identity." % outcome)
	var outcome_identities := {
		"repaired": "scenario::fixture_101",
		"broken": "scenario::fixture_102",
		"refused": "scenario::fixture_103",
	}
	for other_outcome_value in outcome_identities.keys():
		var other_outcome := str(other_outcome_value)
		if other_outcome == outcome: continue
		var other_identity := str(outcome_identities.get(other_outcome, ""))
		for collection_name in material_collections:
			if _dict(semantic.get(collection_name, {})).has(other_identity):
				failures.append("Mutually exclusive %s branch leaked %s identity into %s." % [outcome, other_outcome, collection_name])
	if _array(state.get("cleanup_receipts", [])).is_empty():
		failures.append("Mutually exclusive %s branch did not persist cleanup receipts." % outcome)
	var reentered := SequenceRuntimeScript.apply_reentry(state, definition, "terminal_%s_return" % outcome)
	var reentered_state := _dict(reentered.get("state", {}))
	if not bool(reentered.get("ok", false)) or str(reentered.get("policy", "")) != "aftermath" or str(reentered_state.get("status", "")) != SequenceRuntimeScript.STATUS_AFTERMATH:
		failures.append("Mutually exclusive %s aftermath did not survive terminal reentry." % outcome)
	elif JSON.stringify(reentered_state.get("semantic_state", {})) != JSON.stringify(state.get("semantic_state", {})) or _array(reentered_state.get("resolved_outcomes", [])) != _array(state.get("resolved_outcomes", [])):
		failures.append("Mutually exclusive %s reentry changed its exact semantic aftermath/outcome." % outcome)


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
	var terminal := SequenceRuntimeScript.apply_command(prepared_state, definition, _runtime_command(prepared_state, definition, "finish", "bar_node", "complication", "terminal:finish", {}, "scenario", "command_console"), {"available_funds": 4})
	var terminal_fact := SequenceRuntimeScript.fact("world_boundary", "scenario", "bar_node", "terminal:boundary", 1, 4, _fact_payload("world_boundary"))
	var terminal_queued := SequenceRuntimeScript.enqueue_fact(_dict(terminal.get("state", {})), definition, terminal_fact)
	var aftermath := SequenceRuntimeScript.flush_facts(_dict(terminal_queued.get("state", {})), definition, 4)
	if str(_dict(aftermath.get("state", {})).get("status", "")) != SequenceRuntimeScript.STATUS_AFTERMATH:
		failures.append("Terminal branch did not produce persistent aftermath status.")
	elif bool(SequenceRuntimeScript.enqueue_fact(_dict(aftermath.get("state", {})), definition, SequenceRuntimeScript.fact("world_boundary", "scenario", "bar_node", "post:cleanup", 2, 5, _fact_payload("world_boundary"))).get("ok", true)):
		failures.append("Scenario fact ingress remained open after terminal cleanup/aftermath.")


static func _check_handler_reducer_contracts(failures: Array) -> void:
	var definition := _runtime_definition()
	var event_bridge_definition := definition.duplicate(true)
	event_bridge_definition["sequence"]["fact_subscriptions"].append({
		"fact_type": "event_result",
		"payload_equals": {"event_id": "fixture_event", "choice_id": "leave", "resolution_id": "leave", "resolved": true, "ok": true},
	})
	event_bridge_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(event_bridge_definition)
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
		var handler_definition := _safe_early_cleanup_definition() if handler_id == "request_cleanup" else event_bridge_definition if handler_id == "event_bridge" else definition
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
	var bridge_before := SequenceRuntimeScript.initial_state(event_bridge_definition, "bar_node", "bridge_seed", _fixture_host_semantics(event_bridge_definition))
	var forged_correlations := bridge_before.duplicate(true)
	forged_correlations["event_correlations"] = [{"correlation_key": "forged", "event_id": "fixture_event", "resolution_id": "leave", "trigger_kind": "command", "trigger_id": "bridge:1"}]
	var normalized_forgery := SequenceRuntimeScript.normalize_state(forged_correlations, event_bridge_definition)
	if not _array(normalized_forgery.get("event_correlations", [])).is_empty():
		failures.append("Forged persisted event correlation survived closed normalization.")
	var bridged := SequenceRuntimeScript._run_handler(normalized_forgery, event_bridge_definition, "event_bridge", {"event_id": "fixture_event", "resolution_id": "leave"}, {"kind": "command", "receipt_id": "bridge:1"})
	var normalized_bridge := SequenceRuntimeScript.normalize_state(_dict(bridged.get("state", {})), event_bridge_definition)
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
		["finish", "complication", "rebuild:finish", "command_console"],
	]:
		var command_spec := command_spec_value as Array
		var command_value := _runtime_command(state, definition, str(command_spec[0]), "bar_node", str(command_spec[1]), str(command_spec[2]), {}, "scenario", str(command_spec[3]))
		var applied := SequenceRuntimeScript.apply_command(state, definition, command_value, {"available_funds": 10})
		if not bool(applied.get("ok", false)):
			failures.append("Receipt reconstruction fixture could not reach terminal state: %s" % JSON.stringify(applied.get("errors", [])))
			return
		state = _dict(applied.get("state", {}))
	var rebuilt := ScenarioEngineScript._rebuild_receipted_semantic_mutations(state, definition, host_semantics)
	if not bool(rebuilt.get("ok", false)) or _array(_dict(rebuilt.get("state", {})).get("resolved_branches", [])) != ["arrival:continue", "complication:complication_repair", "aftermath:finish"] or _array(_dict(rebuilt.get("state", {})).get("resolved_outcomes", [])) != ["repaired"]:
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
	fact_definition["sequence"]["phase_graph"]["phases"][0]["branches"] = [{"id": "continue", "condition": {"type": "fact", "fact_type": "town_transition"}, "next_phase": "complication"}]
	fact_definition["sequence"]["fact_subscriptions"].append({"fact_type": "town_transition"})
	fact_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(fact_definition)
	var fact_host := _fixture_host_semantics(fact_definition)
	var fact_state := SequenceRuntimeScript.initial_state(fact_definition, "bar_node", "fact_rebuild_seed", fact_host)
	for fact_value in [
		SequenceRuntimeScript.fact("town_transition", "town", "bar_node", "rebuild:fact:phase", 1, 1, _fact_payload("town_transition")),
		SequenceRuntimeScript.fact("heat_changed", "heat", "bar_node", "rebuild:fact:outcome", 1, 2, _fact_payload("heat_changed")),
	]:
		var queued := SequenceRuntimeScript.enqueue_fact(fact_state, fact_definition, fact_value as Dictionary)
		var flushed := SequenceRuntimeScript.flush_facts(_dict(queued.get("state", {})), fact_definition, int((fact_value as Dictionary).get("boundary_serial", 0)))
		if not bool(queued.get("ok", false)) or not bool(flushed.get("ok", false)):
			failures.append("Fact-cause reconstruction fixture could not reach terminal state: state=%s enqueue=%s flush=%s" % [JSON.stringify(fact_state.get("errors", [])), JSON.stringify(queued.get("errors", [])), JSON.stringify(flushed.get("errors", []))])
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
	local_definition["sequence"]["phase_graph"]["phases"][0]["branches"] = [{"id": "continue", "condition": {"type": "local_min", "key": "pressure", "value": 2}, "next_phase": "complication"}]
	local_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(local_definition)
	var local_host := _fixture_host_semantics(local_definition)
	var local_state := SequenceRuntimeScript.initial_state(local_definition, "bar_node", "causal_local_seed", local_host)
	for receipt_id in ["causal:local:first", "causal:local:second"]:
		var local_command := SequenceRuntimeScript.apply_command(local_state, local_definition, _runtime_command(local_state, local_definition, "prepare", "bar_node", "arrival", receipt_id, {}, "scenario", "command_console"), {"available_funds": 10})
		if not bool(local_command.get("ok", false)):
			failures.append("Causal local replay fixture could not reach its branch: %s" % JSON.stringify(local_command.get("errors", [])))
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
	var honest_cleanup := SequenceRuntimeScript.apply_command(cleanup_initial, cleanup_definition, _runtime_command(cleanup_initial, cleanup_definition, "clean", "bar_node", "arrival", "causal:cleanup", {}, "scenario", "fixture_100"), {"available_funds": 10})
	var honest_cleanup_rebuild := ScenarioEngineScript._rebuild_receipted_semantic_mutations(_dict(honest_cleanup.get("state", {})), cleanup_definition, cleanup_host)
	if not bool(honest_cleanup.get("ok", false)) or not bool(honest_cleanup_rebuild.get("ok", false)):
		failures.append("An exact request_cleanup command cause did not reconstruct its cleanup journal: command=%s rebuild=%s" % [JSON.stringify(honest_cleanup.get("errors", [])), JSON.stringify(honest_cleanup_rebuild.get("errors", []))])
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
	var marked := SequenceRuntimeScript.apply_command(marker_initial, marker_definition, _runtime_command(marker_initial, marker_definition, "mark", "bar_node", "arrival", "causal:marker", {}, "scenario", "fixture_100"), {"available_funds": 10})
	var marked_state := _dict(marked.get("state", {}))
	var marked_rebuild := ScenarioEngineScript._rebuild_receipted_semantic_mutations(marked_state, marker_definition, marker_host)
	if not bool(marked.get("ok", false)) or not bool(marked_rebuild.get("ok", false)) or _array(_dict(marked_rebuild.get("state", {})).get("resolved_outcomes", [])) != ["repaired"] or _contains_text(_array(_dict(marked_state.get("semantic_state", {})).get("operation_receipt_records", [])), ":aftermath:repaired"):
		failures.append("An honest record_outcome marker incorrectly required or executed aftermath operations: command=%s rebuild=%s outcomes=%s" % [JSON.stringify(marked.get("errors", [])), JSON.stringify(marked_rebuild.get("errors", [])), JSON.stringify(_dict(marked_rebuild.get("state", {})).get("resolved_outcomes", []))])
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
	var long_envelope := _runtime_command(state, definition, "prepare", "bar_node", "arrival", "causal:long", {"a": "x".repeat(400), "b": "y".repeat(400)}, "scenario", "command_console")
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
	var resolved_semantic := OperationRegistryScript.public_semantic_state(_dict(initial.get("semantic_state", {})))
	if _dict(public_semantic.get("interactions", {})).keys() != _dict(resolved_semantic.get("interactions", {})).keys() or SequenceRuntimeScript.content_fingerprint(public_semantic.get("scene_objects", {})) != SequenceRuntimeScript.content_fingerprint(resolved_semantic.get("scene_objects", {})):
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
	var exact_command_result_keys := ["boundary_serial", "changed", "command_id", "cost", "ok", "outcomes", "phase_id", "receipt_id", "replayed", "state", "status"]
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
	visit_definition["sequence"]["phase_graph"]["phases"][0]["branches"] = [{"id": "visit_continue", "condition": {"type": "receipt", "receipt_kind": "visit", "receipt_id": "visit_branch"}, "next_phase": "aftermath"}] + _array(visit_definition["sequence"]["phase_graph"]["phases"][0].get("branches", []))
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
	if bool(visited.get("ok", false)) and not visit_records.is_empty():
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
	chained_definition["sequence"]["phase_graph"]["phases"][0]["branches"].append({"id": "event_enters_aftermath", "condition": {"type": "fact", "fact_type": "event_result", "payload_equals": {"event_id": "fixture_event"}}, "next_phase": "aftermath"})
	chained_definition["sequence"]["fact_subscriptions"].append({"fact_type": "event_result", "payload_equals": {"event_id": "fixture_event"}})
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
	if not bool(chained_event_queue.get("ok", false)) or not bool(chained_heat_queue.get("ok", false)) or not bool(chained_flush.get("ok", false)) or chained_batches.size() != 1 or chained_batch_keys != ["depth:batch:event", "depth:batch:heat"] or str(chained_state.get("status", "")) != SequenceRuntimeScript.STATUS_AFTERMATH or _array(chained_state.get("resolved_outcomes", [])) != ["broken"] or int(_dict(chained_state.get("local_state", {})).get("pressure", -1)) != 4 or not bool(chained_rebuild.get("ok", false)) or SequenceRuntimeScript.content_fingerprint(chained_rebuild.get("state", {})) != SequenceRuntimeScript.content_fingerprint(chained_saved_state):
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
	for lifecycle_command_value in [["prepare", "arrival", "lifecycle:prepare", "command_console"], ["finish", "complication", "lifecycle:finish", "command_console"]]:
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

	var expired := SequenceRuntimeScript.apply_expiry(initial, definition, "night_end", 9)
	var expired_state := _dict(expired.get("state", {}))
	if not bool(expired.get("ok", false)) or not bool(expired.get("expired", false)) or str(expired_state.get("status", "")) != SequenceRuntimeScript.STATUS_CLEANED:
		failures.append("Source-room expiry did not clean the active sequence before persistence.")
		return
	var expired_snapshot := EnvironmentInstanceScript.from_dict({
		"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node",
		"scenario_sequence_state": expired_state,
		"scenario_sequence_projection": SequenceRuntimeScript.public_projection(expired_state, definition),
	}).to_dict()
	var restored_expired := _dict(expired_snapshot.get("scenario_sequence_state", {}))
	if not _array(restored_expired.get("expiry_receipts", [])).has("expiry:night_end:9") or _array(restored_expired.get("cleanup_receipts", [])).is_empty():
		failures.append("Source-room expiry/cleanup receipts were not persisted with the room snapshot.")
	var reentered := SequenceRuntimeScript.apply_reentry(restored_expired, definition, "expired_return")
	var reentered_state := _dict(reentered.get("state", {}))
	if not bool(reentered.get("ok", false)) or str(reentered.get("policy", "")) != "expired" or not _array(reentered_state.get("visit_receipts", [])).has("visit:expired_return"):
		failures.append("Expired source-room state did not apply and receipt deterministic reentry.")
	var reentry_snapshot := EnvironmentInstanceScript.from_dict({
		"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node",
		"scenario_sequence_state": reentered_state,
		"scenario_sequence_projection": SequenceRuntimeScript.public_projection(reentered_state, definition),
	}).to_dict()
	if JSON.stringify(reentry_snapshot.get("scenario_sequence_state", {})) != JSON.stringify(EnvironmentInstanceScript._durable_sequence_state(reentered_state)):
		failures.append("Expired source-room reentry state/receipts did not survive a second persistence round-trip.")


static func _check_lifecycle_policy_matrix(failures: Array) -> void:
	var base_definition := _runtime_definition()
	var partial := _prepared_fixture_state(base_definition, "reentry_matrix_seed", failures)
	for policy_value in SequenceSchemaScript.REENTRY_POLICIES:
		var policy := str(policy_value)
		var definition := base_definition.duplicate(true)
		definition["sequence"]["reentry_policy"]["partial"] = policy
		definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(definition)
		var result := SequenceRuntimeScript.apply_reentry(partial, definition, "partial_%s" % policy)
		var next := _dict(result.get("state", {}))
		if not bool(result.get("ok", false)) or str(result.get("policy", "")) != policy or not _array(next.get("visit_receipts", [])).has("visit:partial_%s" % policy):
			failures.append("Partial reentry policy %s did not apply and receipt exactly once." % policy)
			continue
		match policy:
			"resume", "aftermath":
				var expected_feedback := str(SequenceSchemaScript.phase(definition, str(partial.get("phase_id", ""))).get("arrival_feedback", ""))
				if str(next.get("status", "")) != SequenceRuntimeScript.STATUS_ACTIVE or JSON.stringify(next.get("semantic_state", {})) != JSON.stringify(partial.get("semantic_state", {})) or str(next.get("last_feedback", "")) != expected_feedback:
					failures.append("Partial reentry policy %s changed resumable semantic state." % policy)
			"restart":
				if str(next.get("phase_id", "")) != "arrival" or not _array(next.get("command_receipts", [])).is_empty():
					failures.append("Partial restart reentry did not reset phase/command authority.")
			"expired":
				if str(next.get("status", "")) != SequenceRuntimeScript.STATUS_CLEANED or _array(next.get("cleanup_receipts", [])).is_empty():
					failures.append("Partial expired reentry did not clean temporary state.")
		var replay := SequenceRuntimeScript.apply_reentry(next, definition, "partial_%s" % policy)
		if not bool(replay.get("ok", false)) or not bool(replay.get("replayed", false)) or JSON.stringify(replay.get("state", {})) != JSON.stringify(next):
			failures.append("Reentry policy %s was not idempotent." % policy)

	for policy_value in SequenceSchemaScript.EXPIRY_POLICIES:
		var policy := str(policy_value)
		var definition := base_definition.duplicate(true)
		var lifecycle_outcomes := {"fail": "failure", "ignore": "ignore", "cancel": "cancel"}
		var lifecycle_outcome := str(lifecycle_outcomes.get(policy, ""))
		if not lifecycle_outcome.is_empty():
			definition = _definition_with_lifecycle_outcome(definition, lifecycle_outcome)
		definition["sequence"]["expiry"] = {"boundary": "town_action", "after": 2, "policy": policy}
		definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(definition)
		var definition_errors := SequenceSchemaScript.validate_definition(definition, OperationRegistryScript, _fixture_target_inventory(definition))
		if not definition_errors.is_empty():
			failures.append("Expiry policy %s fixture failed schema validation: %s" % [policy, JSON.stringify(definition_errors)])
			continue
		var state := SequenceRuntimeScript.initial_state(definition, "bar_node", "expiry_%s" % policy, _fixture_host_semantics(definition))
		var wrong_boundary := SequenceRuntimeScript.apply_expiry(state, definition, "leave", 1)
		if not bool(wrong_boundary.get("ok", false)) or bool(wrong_boundary.get("applied", true)) or JSON.stringify(wrong_boundary.get("state", {})) != JSON.stringify(state):
			failures.append("Expiry policy %s mutated state at the wrong boundary." % policy)
		var first := SequenceRuntimeScript.apply_expiry(state, definition, "town_action", 1)
		var first_state := _dict(first.get("state", {}))
		if not bool(first.get("ok", false)) or not bool(first.get("applied", false)) or bool(first.get("expired", true)) or int(_dict(first_state.get("expiry_counts", {})).get("town_action", 0)) != 1:
			failures.append("Expiry policy %s did not respect its authored threshold." % policy)
		var duplicate := SequenceRuntimeScript.apply_expiry(first_state, definition, "town_action", 1)
		if not bool(duplicate.get("replayed", false)) or JSON.stringify(duplicate.get("state", {})) != JSON.stringify(first_state):
			failures.append("Expiry policy %s duplicate boundary was not idempotent." % policy)
		var second := SequenceRuntimeScript.apply_expiry(first_state, definition, "town_action", 2)
		var second_state := _dict(second.get("state", {}))
		if not bool(second.get("ok", false)) or int(_dict(second_state.get("expiry_counts", {})).get("town_action", 0)) != 2:
			failures.append("Expiry policy %s did not apply at its threshold boundary." % policy)
		elif policy == "resume":
			if str(second_state.get("status", "")) != SequenceRuntimeScript.STATUS_ACTIVE or bool(second.get("expired", true)) or not str(_dict(_dict(second_state.get("objective_progress", {})).get("clear_exit", {})).get("outcome", "")).is_empty():
				failures.append("Resume expiry policy incorrectly terminated active state.")
		elif policy == "cleanup":
			if str(second_state.get("status", "")) != SequenceRuntimeScript.STATUS_CLEANED or not bool(second.get("expired", false)) or _array(second_state.get("cleanup_receipts", [])).is_empty() or not str(_dict(_dict(second_state.get("objective_progress", {})).get("clear_exit", {})).get("outcome", "")).is_empty():
				failures.append("Cleanup expiry policy did not clean state without inventing an objective outcome.")
		elif str(second_state.get("status", "")) != SequenceRuntimeScript.STATUS_AFTERMATH \
			or _array(second_state.get("resolved_outcomes", [])) != [lifecycle_outcome] \
			or str(_dict(_dict(second_state.get("objective_progress", {})).get("clear_exit", {})).get("outcome", "")) != lifecycle_outcome \
			or not _dict(_dict(second_state.get("semantic_state", {})).get("scene_objects", {})).has("scenario::fixture_101"):
			failures.append("Expiry policy %s did not materialize its distinct %s objective/aftermath outcome." % [policy, lifecycle_outcome])


static func _definition_with_lifecycle_outcome(definition: Dictionary, lifecycle_outcome: String) -> Dictionary:
	var result := definition.duplicate(true)
	var sequence := _dict(result.get("sequence", {}))
	var graph := _dict(sequence.get("phase_graph", {}))
	var phases := _array(graph.get("phases", []))
	var terminal := _dict(phases[phases.size() - 1])
	var branches := _array(terminal.get("branches", []))
	for index in range(branches.size()):
		var branch := _dict(branches[index])
		if str(branch.get("id", "")) == "finish":
			branch["outcome"] = lifecycle_outcome
			branches[index] = branch
	terminal["branches"] = branches
	phases[phases.size() - 1] = terminal
	graph["phases"] = phases
	sequence["phase_graph"] = graph
	var aftermath := _dict(sequence.get("aftermath", {}))
	var renamed := _dict(aftermath.get("repaired", {}))
	renamed["label"] = lifecycle_outcome.capitalize()
	renamed["revisit_feedback"] = "The %s lifecycle aftermath remains visible." % lifecycle_outcome
	aftermath.erase("repaired")
	aftermath[lifecycle_outcome] = renamed
	sequence["aftermath"] = aftermath
	result["sequence"] = sequence
	return result


static func _check_save_service_phase_matrix(failures: Array) -> void:
	var definition := _runtime_definition()
	var arrival := SequenceRuntimeScript.initial_state(definition, "bar_node", "save_arrival", _fixture_host_semantics(definition))
	var before_branch := _prepared_fixture_state(definition, "save_before_branch", failures)
	var repaired_command := _runtime_command(before_branch, definition, "finish", "bar_node", "complication", "save:branch:repaired", {}, "scenario", "command_console")
	var repaired := _dict(SequenceRuntimeScript.apply_command(before_branch, definition, repaired_command, {"available_funds": 10}).get("state", {}))
	var broken_fact := SequenceRuntimeScript.fact("heat_changed", "heat", "bar_node", "save:branch:broken", 1, 1, _fact_payload("heat_changed"))
	var broken_queued := SequenceRuntimeScript.enqueue_fact(before_branch, definition, broken_fact)
	var broken := _dict(SequenceRuntimeScript.flush_facts(_dict(broken_queued.get("state", {})), definition, 1).get("state", {}))
	var refused_command := _runtime_command(before_branch, definition, "refuse", "bar_node", "complication", "save:branch:refused", {}, "scenario", "command_console")
	var refused := _dict(SequenceRuntimeScript.apply_command(before_branch, definition, refused_command, {"available_funds": 0}).get("state", {}))
	var checkpoints := {
		"arrival": arrival,
		"before_branch": before_branch,
		"after_repaired": repaired,
		"after_broken": broken,
		"after_refused": refused,
	}
	for label_value in checkpoints.keys():
		var label := str(label_value)
		var expected := _dict(checkpoints.get(label_value, {}))
		var restored := _save_service_round_trip_state(expected, definition, label, failures)
		if restored.is_empty(): continue
		if JSON.stringify(restored) != JSON.stringify(expected):
			failures.append("SaveService changed exact scenario sequence state at %s." % label)
		match label:
			"after_repaired":
				var replay := SequenceRuntimeScript.apply_command(restored, definition, repaired_command, {"available_funds": 10})
				if not bool(replay.get("replayed", false)) or JSON.stringify(replay.get("state", {})) != JSON.stringify(restored): failures.append("Save/load duplicated repaired branch consequences.")
			"after_broken":
				var duplicate := SequenceRuntimeScript.enqueue_fact(restored, definition, broken_fact)
				if not bool(duplicate.get("duplicate", false)) or JSON.stringify(duplicate.get("state", {})) != JSON.stringify(restored): failures.append("Save/load duplicated broken branch consequences.")
			"after_refused":
				var replay := SequenceRuntimeScript.apply_command(restored, definition, refused_command, {"available_funds": 0})
				if not bool(replay.get("replayed", false)) or JSON.stringify(replay.get("state", {})) != JSON.stringify(restored): failures.append("Save/load duplicated refused branch consequences.")


static func _save_service_round_trip_state(state: Dictionary, definition: Dictionary, label: String, failures: Array, archetype_id: String = "bar", node_id: String = "bar_node") -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("ENV06-6-SAVE-%s" % label, RunState.custom_challenge("env06_6_%s" % label, "ENV06-6-SAVE-%s" % label, {"fixture": true}))
	run_state.current_environment = {
		"id": "%s_001" % archetype_id, "archetype_id": archetype_id, "world_node_id": node_id,
		"scenario_state": ScenarioEngineScript.initial_state(definition),
		"scenario_sequence_definition": definition.duplicate(true),
		"scenario_sequence_state": state.duplicate(true),
		"scenario_sequence_projection": {"hostile": true},
		"scenario_render_snapshot": {"hostile": true},
		"layout": {"object_rects": {}},
	}
	var save_service: SaveService = SaveServiceScript.new()
	var slot_id := "env06_6_sequence_%s" % label
	var clear_before := save_service.clear_run(slot_id)
	if clear_before != OK:
		failures.append("SaveService could not clear scenario fixture slot %s before use: %s." % [label, clear_before])
		return {}
	var save_error := save_service.save_run(run_state, slot_id)
	if save_error != OK:
		failures.append("SaveService scenario checkpoint %s failed to save: %s." % [label, save_error])
		save_service.clear_run(slot_id)
		return {}
	var loaded = save_service.load_run(slot_id)
	var clear_after := save_service.clear_run(slot_id)
	if clear_after != OK:
		failures.append("SaveService could not clear scenario fixture slot %s after use: %s." % [label, clear_after])
	if loaded == null:
		failures.append("SaveService scenario checkpoint %s failed to load." % label)
		return {}
	var environment := _dict((loaded as RunState).current_environment)
	if environment.has("scenario_sequence_projection") and bool(_dict(environment.get("scenario_sequence_projection", {})).get("hostile", false)) or environment.has("scenario_render_snapshot") and bool(_dict(environment.get("scenario_render_snapshot", {})).get("hostile", false)):
		failures.append("SaveService trusted stale derived scenario presentation at %s." % label)
	return _dict(environment.get("scenario_sequence_state", {}))


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
	var receipt_finished := SequenceRuntimeScript.apply_command(receipt_prepared_state, receipt_entry, _runtime_command(receipt_prepared_state, receipt_entry, "finish", "bar_node", "complication", "receipt:finish", {}, "scenario", "command_console"), {"available_funds": 4})
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
	var capacity_definition := definition.duplicate(true)
	var capacity_interaction := _dict(capacity_definition["sequence"]["phase_graph"]["phases"][0]["interaction_ops"][-1]["interaction"])
	var capacity_actions := _array(capacity_interaction.get("available_actions", []))
	capacity_actions.append({"id": "observe", "label": "Observe", "input_action": "confirm", "non_color_state": "ready"})
	capacity_interaction["available_actions"] = capacity_actions
	capacity_definition["sequence"]["phase_graph"]["phases"][0]["interaction_ops"][-1]["interaction"] = capacity_interaction
	capacity_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(capacity_definition)
	var state := SequenceRuntimeScript.initial_state(capacity_definition, "bar_node", "receipt_seed", _fixture_host_semantics(capacity_definition))
	var first_command := _runtime_command(state, capacity_definition, "observe", "bar_node", "arrival", "capacity:command:0", {}, "scenario", "command_console")
	for index in range(SequenceRuntimeScript.MAX_RECEIPTS):
		var command := first_command if index == 0 else _runtime_command(state, capacity_definition, "observe", "bar_node", "arrival", "capacity:command:%d" % index, {}, "scenario", "command_console")
		var applied := SequenceRuntimeScript.apply_command(state, capacity_definition, command, {"available_funds": 2})
		if not bool(applied.get("ok", false)):
			failures.append("Authoritative command receipt capacity failed before its declared limit at %d." % index)
			return
		state = _dict(applied.get("state", {}))
	var overflow := SequenceRuntimeScript.apply_command(state, capacity_definition, _runtime_command(state, capacity_definition, "observe", "bar_node", "arrival", "capacity:command:overflow", {}, "scenario", "command_console"), {"available_funds": 2})
	if bool(overflow.get("ok", true)) or not _contains_text(_array(overflow.get("errors", [])), "lifetime receipt limit"):
		failures.append("Sequence command lifetime did not fail closed at receipt capacity.")
	var old_replay := SequenceRuntimeScript.apply_command(state, capacity_definition, first_command, {"available_funds": 0})
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


static func _check_completion_evidence(failures: Array) -> void:
	var definition := _fixture_definition()
	var calculated := SequenceSchemaScript.calculated_completion_contract(definition)
	for row in SequenceSchemaScript.ALLOWED_EXCEPTION_ROWS:
		if not bool(calculated.get(row, false)):
			failures.append("Calculated hard-10 completion row is not evidenced: %s." % row)
	var excepted := definition.duplicate(true)
	excepted["sequence"]["completion_contract"]["semantic_changes"] = false
	excepted["sequence"]["owner_exceptions"] = [{"row": "semantic_changes", "reason": "Fixture proves signed waiver routing.", "owner": "owner", "approved_on": "2026-08-25"}]
	excepted["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(excepted)
	if not SequenceSchemaScript.validate_definition(excepted, OperationRegistryScript, _fixture_target_inventory(excepted)).is_empty():
		failures.append("Signed owner exception did not waive its named completion row only.")
	var unsigned := excepted.duplicate(true)
	unsigned["sequence"]["owner_exceptions"][0].erase("approved_on")
	if not _contains_text(SequenceSchemaScript.validate_definition(unsigned, OperationRegistryScript), "owner exception"):
		failures.append("Unsigned hard-10 owner exception was accepted.")


static func _check_extension_dispatch(failures: Array) -> void:
	var command := SequenceRuntimeScript.command("use", "bar_node", "arrival", "extension:1", {}, "scenario", "fixture")
	var handled := ScenarioExtensionDispatchScript.prepare_command({}, command, {"available_funds": 10})
	if not bool(handled.get("ok", false)) or JSON.stringify(handled.get("command", {})) != JSON.stringify(command):
		failures.append("Base scenario handler extension changed the authoritative command envelope.")
	var rendered := ScenarioExtensionDispatchScript.prepare_render({}, {"layout": {"object_rects": {}}}, {"scenario_id": "fixture", "phase_id": "arrival", "status": "active", "boundary_serial": 0, "semantic_state": {}})
	if not bool(rendered.get("ok", false)) or str(rendered.get("renderer_id", "")) != "semantic_v1":
		failures.append("Base scenario renderer extension did not produce its fixed semantic snapshot contract.")
	if ScenarioExtensionDispatchScript.validate_package_extensions("invented_package", "invented", "invented").is_empty():
		failures.append("Scenario extension dispatch accepted a package outside the fixed four-package interface.")
	var escaped_handler := ScenarioExtensionDispatchScript.prepare_command({"sequence_handler_pack": "../run_state"}, command, {"available_funds": 10})
	if bool(escaped_handler.get("ok", true)) or not _contains_text(_array(escaped_handler.get("errors", [])), "allowlist"):
		failures.append("Scenario extension dispatch accepted a handler path outside its fixed allowlist.")


static func _check_definition_validation_receipt(failures: Array) -> void:
	var definition := _runtime_definition()
	var definition_errors := SequenceSchemaScript.validate_definition(definition, OperationRegistryScript, _fixture_target_inventory(definition))
	if not definition_errors.is_empty():
		failures.append("Scenario definition receipt fixture did not have exact target-catalog proof: %s" % JSON.stringify(definition_errors))
		return
	definition[ScenarioEngineScript.VALIDATED_SEQUENCE_MARKER] = true
	var environment := {"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node", "scenario_state": {"id": definition.get("id", "")}}
	var resolved := ScenarioEngineScript.sequence_definition_for_environment(environment, definition)
	if not bool(resolved.get("__scenario_sequence_runtime_validated", false)):
		failures.append("Scenario definition resolution did not preserve its immutable catalog-validation receipt.")
	var cached := ScenarioEngineScript.sequence_definition_for_environment(environment, resolved)
	if JSON.stringify(cached) != JSON.stringify(resolved):
		failures.append("Scenario definition validation receipt was not stable across runtime reads.")


static func _check_suppressed_sequence_compatibility(library: ContentLibrary, failures: Array) -> void:
	var legacy_ids: Array = []
	for pool_value in library.environment_scenarios.values():
		for definition_value in _array(pool_value):
			var legacy_definition := _dict(definition_value).duplicate(true)
			var legacy_id := str(legacy_definition.get("id", "")).strip_edges()
			if legacy_id.is_empty() or legacy_ids.has(legacy_id):
				continue
			legacy_ids.append(legacy_id)
			if SequenceSchemaScript.is_sequence(legacy_definition):
				failures.append("Legacy compatibility source %s unexpectedly contains an authored dynamic sequence." % legacy_id)
				continue
			var legacy_environment := {
				"id": "compatibility_%s" % legacy_id,
				"archetype_id": str(legacy_definition.get("archetype_id", "fixture")),
				"world_node_id": "compatibility_node_%s" % legacy_id,
				"scenario_state": ScenarioEngineScript.initial_state(legacy_definition),
			}
			ScenarioEngineScript.reconcile_environment(legacy_environment, _dict(legacy_environment.get("scenario_state", {})))
			var control := legacy_environment.duplicate(true)
			var migrated := legacy_environment.duplicate(true)
			var migration := ScenarioEngineScript.migrate_environment_sequence(migrated, legacy_definition, "compatibility:%s" % legacy_id)
			if not bool(migration.get("ok", false)) or bool(migration.get("changed", true)) or bool(migration.get("active", true)) or JSON.stringify(migrated) != JSON.stringify(legacy_environment):
				failures.append("Legacy no-sequence scenario %s did not remain byte-identical through dynamic migration probing." % legacy_id)
				continue
			var control_changed := ScenarioEngineScript.advance_environment(control, 1)
			var migrated_changed := ScenarioEngineScript.advance_environment(migrated, 1)
			if migrated_changed != control_changed or JSON.stringify(migrated) != JSON.stringify(control):
				failures.append("Legacy no-sequence scenario %s lost its simple phase/mutation behavior after migration probing." % legacy_id)
	legacy_ids.sort()
	if legacy_ids.size() != 55:
		failures.append("Legacy compatibility matrix expected 55 unique scenario ids, got %d." % legacy_ids.size())
	var definition := _runtime_definition()
	var definition_errors := SequenceSchemaScript.validate_definition(definition, OperationRegistryScript, _fixture_target_inventory(definition))
	assert(definition_errors.is_empty(), "Ordinary dynamic compatibility fixture requires exact target-catalog proof: %s" % JSON.stringify(definition_errors))
	definition[ScenarioEngineScript.VALIDATED_SEQUENCE_MARKER] = true
	var ordinary_environment := {
		"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node",
		"layout": {"object_rects": {}}, "game_ids": ["slots"],
		"service_ids": ["fixture_service"], "travel_hooks": ["old_exit"],
		"scenario_game_modifiers": {},
	}
	ScenarioEngineScript.attach_to_environment(ordinary_environment, ScenarioEngineScript.initial_state(definition), definition)
	var ordinary_resolved := ScenarioEngineScript.sequence_definition_for_environment(ordinary_environment, definition)
	if not SequenceSchemaScript.is_sequence(ordinary_resolved) or ordinary_environment.has("scenario_sequence_migration") or ordinary_environment.has("scenario_sequence_state") or ordinary_environment.has("scenario_sequence_projection"):
		failures.append("An ordinary validated dynamic definition did not remain pending and artifact-free before semantic finalization.")

	var suppressed_definition := ScenarioEngineScript.suppress_sequence_definition(definition)
	if str(suppressed_definition.get("id", "")) != str(definition.get("id", "")) or SequenceSchemaScript.is_sequence(suppressed_definition) or not bool(suppressed_definition.get(ScenarioEngineScript.SEQUENCE_SUPPRESSION_KEY, false)):
		failures.append("Sequence suppression did not preserve identity while removing the dynamic overlay.")
	var suppressed_environment := {
		"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node",
		"layout": {"object_rects": {}}, "game_ids": ["slots"],
		"service_ids": ["fixture_service"], "travel_hooks": ["old_exit"],
		"scenario_game_modifiers": {},
	}
	ScenarioEngineScript.attach_to_environment(suppressed_environment, ScenarioEngineScript.initial_state(suppressed_definition), definition)
	if str(_dict(suppressed_environment.get("scenario_state", {})).get("id", "")) != str(definition.get("id", "")) or not bool(_dict(suppressed_environment.get("scenario_state", {})).get(ScenarioEngineScript.SEQUENCE_SUPPRESSION_KEY, false)):
		failures.append("Suppressed sequence setup lost its retained scenario identity marker.")
	var hostile_state := SequenceRuntimeScript.initial_state(definition, "bar_node", "suppressed_hostile", _fixture_host_semantics(definition))
	hostile_state["event_request_queue"] = [{"request_id": "hostile", "event_id": "fixture_event", "resolution_id": "fixture_resolution"}]
	suppressed_environment["scenario_sequence_state"] = hostile_state
	suppressed_environment["scenario_sequence_projection"] = {"hostile": true}
	suppressed_environment["scenario_render_snapshot"] = {"hostile": true}
	suppressed_environment["scenario_sequence_migration"] = {"hostile": true}
	suppressed_environment["scenario_sequence_definition"] = definition.duplicate(true)
	suppressed_environment["scenario_sequence_base_game_ids"] = ["slots"]
	suppressed_environment["scenario_sequence_base_service_ids"] = ["fixture_service"]
	suppressed_environment["scenario_sequence_base_travel_hooks"] = ["old_exit"]
	suppressed_environment["scenario_sequence_base_game_modifiers"] = {}
	suppressed_environment["game_ids"] = ["leaked_game"]
	suppressed_environment["service_ids"] = ["leaked_service"]
	suppressed_environment["travel_hooks"] = ["leaked_route"]
	suppressed_environment["scenario_game_modifiers"] = {"leaked_game": {"tone": "hostile"}}
	var suppressed_state := ScenarioEngineScript.ensure_sequence_state(suppressed_environment, definition)
	var suppressed_resolved := ScenarioEngineScript.sequence_definition_for_environment(suppressed_environment, definition)
	if not suppressed_state.is_empty() or SequenceSchemaScript.is_sequence(suppressed_resolved) or not ScenarioEngineScript.sequence_projection(suppressed_environment, definition).is_empty():
		failures.append("A mutation-suppressed scenario reacquired a dynamic sequence by preferred definition or scenario id.")
	for forbidden_key in ["scenario_sequence_state", "scenario_sequence_projection", "scenario_render_snapshot", "scenario_sequence_migration", "scenario_sequence_definition", "scenario_sequence_base_game_ids", "scenario_sequence_base_service_ids", "scenario_sequence_base_travel_hooks", "scenario_sequence_base_game_modifiers"]:
		if suppressed_environment.has(forbidden_key):
			failures.append("Suppressed scenario retained sequence runtime artifact %s." % forbidden_key)
	if _array(suppressed_environment.get("game_ids", [])) != ["slots"] or _array(suppressed_environment.get("service_ids", [])) != ["fixture_service"] or _array(suppressed_environment.get("travel_hooks", [])) != ["old_exit"] or not _dict(suppressed_environment.get("scenario_game_modifiers", {})).is_empty():
		failures.append("Suppressed scenario did not restore its pre-sequence material baseline.")
	var inactive_command := ScenarioEngineScript.sequence_command(suppressed_environment, definition, SequenceRuntimeScript.command("prepare", "bar_node", "arrival", "suppressed:command", {}, "scenario", "command_console"), {"available_funds": 10})
	var inactive_requests := ScenarioEngineScript.drain_sequence_event_requests(suppressed_environment, definition)
	if bool(inactive_command.get("ok", true)) or not bool(inactive_requests.get("inactive", false)) or not _array(inactive_requests.get("requests", [])).is_empty():
		failures.append("Suppressed scenario exposed command authority or an event-bridge request drain.")

	# Pre-marker saves restore through RunState.from_dict before RunGenerator can
	# revisit a room. Cover every persisted environment graph so the content
	# catalog cannot activate a newly installed overlay during that early seam.
	var old_run := RunStateScript.new()
	var old_challenge := RunStateScript.custom_challenge("suppressed_restore", "SUPPRESSED-RESTORE", {
		"scenario_pins": {"bar": str(definition.get("id", "")), "grand_casino": str(definition.get("id", ""))},
		"scenario_pins_apply_mutations": false,
	})
	old_run.start_new("SUPPRESSED-RESTORE", old_challenge)
	var hostile_snapshot := {
		"id": "bar_legacy", "archetype_id": "bar", "world_node_id": "bar_legacy_node",
		"layout": {"object_rects": {}}, "game_ids": ["leaked_game"],
		"service_ids": ["leaked_service"], "travel_hooks": ["leaked_route"],
		"scenario_game_modifiers": {"leaked_game": {"tone": "hostile"}},
		"scenario_sequence_base_game_ids": ["slots"],
		"scenario_sequence_base_service_ids": ["fixture_service"],
		"scenario_sequence_base_travel_hooks": ["old_exit"],
		"scenario_sequence_base_game_modifiers": {},
		"scenario_sequence_definition": definition.duplicate(true),
		"scenario_sequence_migration": {"hostile": true},
	}
	ScenarioEngineScript.attach_to_environment(hostile_snapshot, ScenarioEngineScript.initial_state(definition), definition)
	var hostile_runtime_state := SequenceRuntimeScript.initial_state(definition, "bar_legacy_node", "pre_marker")
	hostile_runtime_state["event_request_queue"] = [{"request_id": "hostile", "event_id": "fixture_event", "resolution_id": "fixture_resolution"}]
	hostile_snapshot["scenario_sequence_state"] = hostile_runtime_state
	hostile_snapshot["scenario_sequence_projection"] = {"hostile": true}
	hostile_snapshot["scenario_render_snapshot"] = {"hostile": true}
	var hostile_layer := hostile_snapshot.duplicate(true)
	hostile_layer["id"] = "bar_legacy_layer"
	hostile_layer["world_node_id"] = "bar_legacy_layer_node"
	hostile_layer.erase("archetype_id")
	var hostile_layer_scenario := _dict(hostile_layer.get("scenario_state", {}))
	hostile_layer_scenario["archetype_id"] = ""
	hostile_layer["scenario_state"] = hostile_layer_scenario
	hostile_snapshot["environment_layer_schema_version"] = 1
	hostile_snapshot["current_layer_id"] = "main"
	hostile_snapshot["default_layer_id"] = "main"
	hostile_snapshot["layer_ids"] = ["main", "side"]
	hostile_snapshot["layer_states"] = {"side": hostile_layer}
	old_run.current_environment = hostile_snapshot.duplicate(true)
	old_run.world_map = {
		"version": 1, "seed_text": "SUPPRESSED-RESTORE", "start_node_id": "stored_bar", "current_node_id": "stored_bar",
		"nodes": [{"id": "stored_bar", "archetype_id": "bar", "state": "visited", "environment": hostile_layer.duplicate(true)}],
		"edges": [], "visited_path": ["stored_bar"],
	}
	var hostile_grand_room := hostile_layer.duplicate(true)
	hostile_grand_room["id"] = "grand_casino_legacy"
	hostile_grand_room["archetype_id"] = "grand_casino"
	hostile_grand_room["world_node_id"] = "grand_casino"
	old_run.grand_casino_room_states = {"grand_casino": hostile_grand_room}
	var old_save := old_run.to_dict()
	var restored_run := RunStateScript.new()
	restored_run.from_dict(old_save)
	var restored_nodes := _array(_dict(restored_run.world_map).get("nodes", []))
	var restored_stored_environment := _dict(_dict(restored_nodes[0] if not restored_nodes.is_empty() else {}).get("environment", {}))
	var restored_snapshots := [
		{"path": "current", "environment": restored_run.current_environment},
		{"path": "layer", "environment": _dict(_dict(restored_run.current_environment.get("layer_states", {})).get("side", {}))},
		{"path": "world", "environment": restored_stored_environment},
		{"path": "grand", "environment": _dict(restored_run.grand_casino_room_states.get("grand_casino", {}))},
	]
	for restored_entry_value in restored_snapshots:
		var restored_entry := _dict(restored_entry_value)
		var restored_environment := _dict(restored_entry.get("environment", {}))
		var restored_scenario := _dict(restored_environment.get("scenario_state", {}))
		if str(restored_scenario.get("id", "")) != str(definition.get("id", "")) or not bool(restored_scenario.get(ScenarioEngineScript.SEQUENCE_SUPPRESSION_KEY, false)):
			failures.append("Suppressed old-save %s snapshot lost identity or its durable suppression marker." % str(restored_entry.get("path", "")))
		for forbidden_key in ["scenario_sequence_state", "scenario_sequence_projection", "scenario_render_snapshot", "scenario_sequence_migration", "scenario_sequence_definition", "scenario_sequence_base_game_ids", "scenario_sequence_base_service_ids", "scenario_sequence_base_travel_hooks", "scenario_sequence_base_game_modifiers"]:
			if restored_environment.has(forbidden_key):
				failures.append("Suppressed old-save %s snapshot retained sequence runtime artifact %s." % [str(restored_entry.get("path", "")), forbidden_key])
		if _array(restored_environment.get("game_ids", [])) != ["slots"] or _array(restored_environment.get("service_ids", [])) != ["fixture_service"] or _array(restored_environment.get("travel_hooks", [])) != ["old_exit"] or not _dict(restored_environment.get("scenario_game_modifiers", {})).is_empty():
			failures.append("Suppressed old-save %s snapshot did not restore its pre-sequence material baseline." % str(restored_entry.get("path", "")))
	var restored_definition := restored_run.scenario_sequence_definition()
	var restored_requests := restored_run.scenario_drain_event_requests()
	if SequenceSchemaScript.is_sequence(restored_definition) or restored_run.scenario_sequence_active() or not bool(restored_requests.get("inactive", false)) or not _array(restored_requests.get("requests", [])).is_empty():
		failures.append("Suppressed old-save restore reacquired a sequence or event authority after migration.")


static func _check_transition_and_event_delivery(failures: Array) -> void:
	var definition := _runtime_definition()
	var initial := SequenceRuntimeScript.initial_state(definition, "bar_node", "delivery_seed", _fixture_host_semantics(definition))
	var first := SequenceRuntimeScript.drain_transitions(initial, definition)
	var first_state := _dict(first.get("state", {}))
	var replay := SequenceRuntimeScript.drain_transitions(first_state, definition)
	if not bool(first.get("ok", false)) or _array(first.get("transitions", [])).is_empty() or not _array(replay.get("transitions", [])).is_empty():
		failures.append("Scenario transition delivery was not durable and exactly once.")
	var staged_state := _prepared_fixture_state(definition, "stage_seed", failures)
	var staged_delivery := SequenceRuntimeScript.drain_transitions(staged_state, definition)
	var staged_delivery_state := _dict(staged_delivery.get("state", {}))
	if _array(staged_delivery_state.get("active_stages", [])).size() != 1:
		failures.append("Scenario stage transition did not become active after delivery.")
	var boundary_fact := SequenceRuntimeScript.fact("world_boundary", "scenario", "bar_node", "stage:boundary:1", 1, 1, {"amount": 1, "action_index": 1})
	var boundary_queued := SequenceRuntimeScript.enqueue_fact(staged_delivery_state, definition, boundary_fact)
	var boundary_flushed := SequenceRuntimeScript.flush_facts(_dict(boundary_queued.get("state", {})), definition, 1)
	if not bool(boundary_flushed.get("ok", false)) or not _array(_dict(boundary_flushed.get("state", {})).get("active_stages", [])).is_empty():
		failures.append("Scenario stage transition did not expire at its deterministic world boundary.")
	var reduced_state := _prepared_fixture_state(definition, "reduced_stage_seed", failures)
	var reduced_delivery := SequenceRuntimeScript.drain_transitions(reduced_state, definition, true)
	if not bool(reduced_delivery.get("ok", false)) or not _array(_dict(reduced_delivery.get("state", {})).get("active_stages", [])).is_empty():
		failures.append("Reduced-motion transition delivery retained a timed visual stage.")
	var legacy_observer_state := SequenceRuntimeScript.initial_state(definition, "bar_node", "legacy_event_observer", _fixture_host_semantics(definition))
	var legacy_observer_fact := SequenceRuntimeScript.fact("event_result", "event", "bar_node", "event:legacy_observer", 1, 1, {"event_id": "fixture_event", "choice_id": "legacy_observed", "resolution_id": "", "resolved": true, "ok": true})
	var legacy_observer_queued := SequenceRuntimeScript.enqueue_fact(legacy_observer_state, definition, legacy_observer_fact)
	var legacy_observer_result := SequenceRuntimeScript.flush_facts(_dict(legacy_observer_queued.get("state", {})), definition, 1)
	if not bool(legacy_observer_result.get("ok", false)) or _array(_dict(legacy_observer_result.get("state", {})).get("fact_receipts", [])) != ["event:legacy_observer"]:
		failures.append("Broad uncorrelated event-result observer compatibility regressed.")
	var bridged_definition := definition.duplicate(true)
	var sequence := _dict(bridged_definition.get("sequence", {}))
	var graph := _dict(sequence.get("phase_graph", {}))
	var phases := _array(graph.get("phases", []))
	var arrival := _dict(phases[0])
	var interaction_ops := _array(arrival.get("interaction_ops", []))
	var command_console_op := _dict(interaction_ops[interaction_ops.size() - 1])
	var command_console := _dict(command_console_op.get("interaction", {}))
	var actions := _array(command_console.get("available_actions", []))
	actions[0]["handler"] = "event_bridge"
	actions[0]["inputs"] = {"event_id": "fixture_event", "resolution_id": "leave"}
	command_console["available_actions"] = actions
	command_console_op["interaction"] = command_console
	interaction_ops[interaction_ops.size() - 1] = command_console_op
	arrival["interaction_ops"] = interaction_ops
	phases[0] = arrival
	graph["phases"] = phases
	sequence["phase_graph"] = graph
	var objectives := _array(sequence.get("objectives", []))
	var event_objective := _dict(objectives[0])
	var event_steps := _array(event_objective.get("steps", []))
	event_steps.append({"id": "record_event_choice", "label": "Record the correlated event choice", "kind": "fact", "fact_type": "event_result", "payload_equals": {"event_id": "fixture_event"}})
	event_objective["steps"] = event_steps
	objectives[0] = event_objective
	sequence["objectives"] = objectives
	sequence["fact_subscriptions"][0] = {
		"fact_type": "event_result",
		"payload_equals": {"event_id": "fixture_event"},
		"handler": "increment_local",
		"inputs": {"key": "pressure", "amount": 1},
	}
	sequence["fact_subscriptions"].append({
		"fact_type": "event_result",
		"payload_equals": {
			"event_id": "fixture_event", "choice_id": "leave",
			"resolution_id": "leave", "resolved": true, "ok": true,
		},
	})
	bridged_definition["sequence"] = sequence
	bridged_definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(bridged_definition)
	var bridged_initial := SequenceRuntimeScript.initial_state(bridged_definition, "bar_node", "event_seed", _fixture_host_semantics(bridged_definition))
	var applied := SequenceRuntimeScript.apply_command(bridged_initial, bridged_definition, _runtime_command(bridged_initial, bridged_definition, "prepare", "bar_node", "arrival", "event_bridge:1", {}, "scenario", "command_console"), {"available_funds": 2})
	var drained := SequenceRuntimeScript.drain_event_requests(_dict(applied.get("state", {})), bridged_definition)
	var drained_again := SequenceRuntimeScript.drain_event_requests(_dict(drained.get("state", {})), bridged_definition)
	if not bool(applied.get("ok", false)) or _array(drained.get("requests", [])).size() != 1 or not _array(drained_again.get("requests", [])).is_empty():
		failures.append("Scenario event bridge did not publish one durable correlated request.")
	var delivered_state := _dict(drained.get("state", {}))
	var unrelated_fact := SequenceRuntimeScript.fact("event_result", "event", "bar_node", "event:unrelated", 1, 1, {"event_id": "unrelated_event", "choice_id": "leave", "resolved": true, "ok": true})
	var unrelated_queued := SequenceRuntimeScript.enqueue_fact(delivered_state, bridged_definition, unrelated_fact)
	var unrelated_result := SequenceRuntimeScript.flush_facts(_dict(unrelated_queued.get("state", {})), bridged_definition, 1)
	if bool(unrelated_result.get("ok", true)) or not _contains_text(_array(unrelated_result.get("errors", [])), "does not match") or int(_dict(_dict(unrelated_result.get("state", {})).get("local_state", {})).get("pressure", -1)) != 0 or not _array(_dict(unrelated_result.get("state", {})).get("event_choice_receipts", [])).is_empty():
		failures.append("An unrelated event_result with a colliding choice id reached this scenario before payload isolation.")
	var uncorrelated_fact := SequenceRuntimeScript.fact("event_result", "event", "bar_node", "event:uncorrelated", 2, 1, {"event_id": "fixture_event", "choice_id": "leave", "resolved": true, "ok": true})
	var uncorrelated_queued := SequenceRuntimeScript.enqueue_fact(delivered_state, bridged_definition, uncorrelated_fact)
	var uncorrelated_result := SequenceRuntimeScript.flush_facts(_dict(uncorrelated_queued.get("state", {})), bridged_definition, 1)
	if bool(uncorrelated_result.get("ok", true)) or not _contains_text(_array(uncorrelated_result.get("errors", [])), "does not match") or int(_dict(_dict(uncorrelated_result.get("state", {})).get("local_state", {})).get("pressure", -1)) != 0 or JSON.stringify(_dict(uncorrelated_result.get("state", {})).get("objective_progress", {})) != JSON.stringify(delivered_state.get("objective_progress", {})):
		failures.append("A delivered event-bridge request accepted an event_result without its resolution correlation.")
	var branch_definition := bridged_definition.duplicate(true)
	var branch_sequence := _dict(branch_definition.get("sequence", {}))
	var branch_graph := _dict(branch_sequence.get("phase_graph", {}))
	var branch_phases := _array(branch_graph.get("phases", []))
	var branch_complication := _dict(branch_phases[1])
	var complication_branches := _array(branch_complication.get("branches", []))
	complication_branches.append({"id": "event_collision_to_aftermath", "condition": {"type": "fact", "fact_type": "event_result", "payload_equals": {"event_id": "fixture_event"}}, "next_phase": "aftermath"})
	branch_complication["branches"] = complication_branches
	branch_phases[1] = branch_complication
	var branch_aftermath := _dict(branch_phases[2])
	var aftermath_branches := _array(branch_aftermath.get("branches", []))
	aftermath_branches.append({"id": "event_collision_repaired", "condition": {"type": "fact", "fact_type": "event_result", "payload_equals": {"event_id": "fixture_event"}}, "outcome": "repaired", "objective_outcomes": {"clear_exit": "success"}})
	branch_aftermath["branches"] = aftermath_branches
	branch_phases[2] = branch_aftermath
	branch_graph["phases"] = branch_phases
	branch_sequence["phase_graph"] = branch_graph
	branch_definition["sequence"] = branch_sequence
	var branch_uncorrelated_result := SequenceRuntimeScript.flush_facts(_dict(uncorrelated_queued.get("state", {})), branch_definition, 1)
	if bool(branch_uncorrelated_result.get("ok", true)) or not _contains_text(_array(branch_uncorrelated_result.get("errors", [])), "does not match"):
		failures.append("Uncorrelated event-result branch fixture was not rejected.")
	for stable_key in ["phase_id", "status", "local_state", "objective_progress", "resolved_branches", "resolved_outcomes", "semantic_state"]:
		if JSON.stringify(_dict(branch_uncorrelated_result.get("state", {})).get(stable_key)) != JSON.stringify(delivered_state.get(stable_key)):
			failures.append("Uncorrelated event-result isolation ran a handler, objective step, or branch before rejection (%s)." % stable_key)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("ENV06-6-EVENT-BRIDGE", RunState.custom_challenge("env06_6_event_bridge", "ENV06-6-EVENT-BRIDGE", {"fixture": true}))
	run_state.current_environment = {
		"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node",
		"scenario_state": ScenarioEngineScript.initial_state(bridged_definition),
		"scenario_sequence_definition": bridged_definition,
		"scenario_sequence_state": delivered_state,
		"layout": {"object_rects": {}},
	}
	if run_state._scenario_pending_resolution_for_event("fixture_event") != "leave":
		failures.append("Production event-result routing did not infer its delivered scenario resolution correlation.")
	var correlated_fact := SequenceRuntimeScript.fact("event_result", "event", "bar_node", "event:correlated", 1, 1, {"event_id": "fixture_event", "choice_id": "leave", "resolution_id": "leave", "resolved": true, "ok": true})
	var correlated_queued := SequenceRuntimeScript.enqueue_fact(delivered_state, bridged_definition, correlated_fact)
	var correlated_result := SequenceRuntimeScript.flush_facts(_dict(correlated_queued.get("state", {})), bridged_definition, 1)
	var correlated_state := _dict(correlated_result.get("state", {}))
	if not bool(correlated_result.get("ok", false)) or not _array(correlated_state.get("event_choice_receipts", [])).has("leave:leave") or int(_dict(correlated_state.get("local_state", {})).get("pressure", -1)) != 1 or not _array(_dict(_dict(correlated_state.get("objective_progress", {})).get("clear_exit", {})).get("completed_steps", [])).has("record_event_choice"):
		failures.append("Scenario event bridge did not accept its delivered correlated event result.")
	var consumed_fact := SequenceRuntimeScript.fact("event_result", "event", "bar_node", "event:consumed_again", 2, 1, {"event_id": "fixture_event", "choice_id": "conflicting_choice", "resolution_id": "leave", "resolved": true, "ok": true})
	var consumed_queued := SequenceRuntimeScript.enqueue_fact(correlated_state, bridged_definition, consumed_fact)
	var consumed_result := SequenceRuntimeScript.flush_facts(_dict(consumed_queued.get("state", {})), bridged_definition, 1)
	if bool(consumed_result.get("ok", true)) or not _contains_text(_array(consumed_result.get("errors", [])), "does not match") or int(_dict(_dict(consumed_result.get("state", {})).get("local_state", {})).get("pressure", -1)) != 1 or _array(_dict(consumed_result.get("state", {})).get("event_choice_receipts", [])).size() != 1:
		failures.append("A consumed event resolution reran under a fresh fact id or conflicting choice.")
	var mismatched_fact := SequenceRuntimeScript.fact("event_result", "event", "bar_node", "event:mismatched", 2, 1, {"event_id": "fixture_event", "choice_id": "leave", "resolution_id": "wrong_resolution", "resolved": true, "ok": true})
	var mismatched_queued := SequenceRuntimeScript.enqueue_fact(delivered_state, bridged_definition, mismatched_fact)
	var mismatched_result := SequenceRuntimeScript.flush_facts(_dict(mismatched_queued.get("state", {})), bridged_definition, 1)
	if bool(mismatched_result.get("ok", true)) or not _contains_text(_array(mismatched_result.get("errors", [])), "does not match"):
		failures.append("Scenario event bridge accepted an unmatched event-result correlation.")


static func _check_rollout_growth_contract(library: ContentLibrary, failures: Array) -> void:
	var delivery := library.scenario(DELIVERY_SCENARIO_ID)
	if delivery.is_empty():
		failures.append("Rollout-growth fixture could not load the invariant delivery proof.")
		return
	var other := _fixture_definition()
	other["id"] = "aaa_rollout_other"
	var reversed_definitions := [other, delivery]
	var representative := SequenceCatalogScript.definition_for_id(reversed_definitions, DELIVERY_SCENARIO_ID)
	var hostile_rows := ScenarioSequenceAuditScript.hostile_fixture_report_for_definitions(reversed_definitions)
	if str(representative.get("id", "")) != DELIVERY_SCENARIO_ID or hostile_rows.size() != 11:
		failures.append("Expanded audit did not select the invariant delivery proof independently of catalog order.")
	else:
		for hostile_value in hostile_rows:
			var hostile := _dict(hostile_value)
			if not bool(hostile.get("rejected", false)) or str(hostile.get("class", "")) == "fixture_source":
				failures.append("Expanded audit hostile row did not reject: %s." % JSON.stringify(hostile))
	var pair_report := ScenarioEngineScript.sequence_catalog_audit(reversed_definitions, 2, {})
	if not ScenarioSequenceAuditScript.report_has_exact_shape(pair_report, 2) or int(pair_report.get("comparison_count", -1)) != 1:
		failures.append("Expanded two-definition audit did not report its exact single pair.")
	for missing_or_duplicate in [[other], [delivery, delivery]]:
		var fixture_source_rows := ScenarioSequenceAuditScript.hostile_fixture_report_for_definitions(missing_or_duplicate)
		if fixture_source_rows.size() != 1 or str(_dict(fixture_source_rows[0]).get("class", "")) != "fixture_source" or bool(_dict(fixture_source_rows[0]).get("rejected", true)):
			failures.append("Missing/duplicate delivery representative did not fail with fixture_source.")
	for rollout_count_value in [13, 55]:
		var rollout_count := int(rollout_count_value)
		var definitions: Array = []
		for index in range(rollout_count):
			var fixture := _fixture_definition()
			fixture["id"] = "rollout_fixture_%02d" % index
			fixture["sequence"]["sequence_signature"] = "rollout-fixture-%02d" % index
			definitions.append(fixture)
		var rollout_report := ScenarioEngineScript.sequence_catalog_audit(definitions, rollout_count, {})
		if not ScenarioSequenceAuditScript.report_has_exact_shape(rollout_report, rollout_count):
			failures.append("Scenario audit lost exact %d-definition/%d-pair reporting." % [rollout_count, int(rollout_count * (rollout_count - 1) / 2)])

	var catalog := SequenceCatalogScript.load_catalog()
	var proof_package := SequenceCatalogScript.package_for_scenario(DELIVERY_SCENARIO_ID, catalog)
	if proof_package.is_empty():
		failures.append("Rollout-growth fixture could not locate the invariant delivery package.")
		return
	var expanded_package := proof_package.duplicate(true)
	expanded_package["scenario_ids"] = _array(proof_package.get("scenario_ids", [])) + ["future_shop_sequence"]
	var expanded_catalog := {"ok": true, "packages": [
		{"package_id": "future_other", "scenario_ids": ["future_other_sequence"]},
		expanded_package,
		{"package_id": "future_last", "scenario_ids": ["future_last_sequence"]},
	]}
	var expanded_match := SequenceCatalogScript.package_for_scenario(DELIVERY_SCENARIO_ID, expanded_catalog)
	if str(expanded_match.get("package_id", "")) != str(proof_package.get("package_id", "")):
		failures.append("Delivery proof package lookup overfit the catalog/package singleton shape.")
	var duplicate_package := proof_package.duplicate(true)
	duplicate_package["package_id"] = "duplicate_delivery_claim"
	var duplicate_catalog := expanded_catalog.duplicate(true)
	duplicate_catalog["packages"] = _array(expanded_catalog.get("packages", [])) + [duplicate_package]
	if not SequenceCatalogScript.package_for_scenario(DELIVERY_SCENARIO_ID, duplicate_catalog).is_empty():
		failures.append("Delivery proof package lookup accepted duplicate package claims.")
	var repeated_claim := proof_package.duplicate(true)
	repeated_claim["scenario_ids"] = [DELIVERY_SCENARIO_ID, DELIVERY_SCENARIO_ID]
	if not SequenceCatalogScript.package_for_scenario(DELIVERY_SCENARIO_ID, {"ok": true, "packages": [repeated_claim, expanded_package]}).is_empty():
		failures.append("Delivery proof package lookup ignored repeated in-package claims.")


static func _check_delivery_day_production_package(library: ContentLibrary, failures: Array) -> void:
	var raw_package: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/environments/scenario_sequences/env06_7_shops_streets.json"))
	if typeof(raw_package) != TYPE_DICTIONARY or int(_dict(raw_package).get("schema_version", 0)) != 1 or _dict(raw_package).keys() != ["schema_version", "package_id", "handler_pack", "renderer_id", "scenarios"]:
		failures.append("Delivery-day JSON is not the exact schema-v1 object envelope.")
		return
	var catalog := SequenceCatalogScript.load_catalog()
	var definition := library.scenario(DELIVERY_SCENARIO_ID)
	var package := SequenceCatalogScript.package_for_scenario(DELIVERY_SCENARIO_ID, catalog)
	if not bool(catalog.get("ok", false)) or package.is_empty() or _dict(catalog.get("overlays", {})).keys().count(DELIVERY_SCENARIO_ID) != 1:
		failures.append("Delivery-day proof did not resolve to exactly one catalog definition/package: %s" % JSON.stringify(catalog))
		return
	if str(package.get("package_id", "")) != "env06_7_shops_streets" or str(package.get("file_name", "")) != "env06_7_shops_streets.json" or str(package.get("handler_pack", "")) != "shops_streets" or str(package.get("renderer_id", "")) != "shops_streets" or _array(package.get("scenario_ids", [])).count(DELIVERY_SCENARIO_ID) != 1:
		failures.append("Delivery-day package envelope/extension identity changed: %s" % JSON.stringify(package))
	if definition.is_empty() or str(definition.get("sequence_package_id", "")) != "env06_7_shops_streets" or str(definition.get("sequence_handler_pack", "")) != "shops_streets" or str(definition.get("sequence_renderer_id", "")) != "shops_streets":
		failures.append("ContentLibrary did not apply the committed delivery-day package exactly.")
		return
	var target_catalog := library.scenario_target_catalog(definition)
	var sealed_catalog_inventory := _dict(target_catalog.get("inventory", {}))
	var definition_errors := _array(target_catalog.get("errors", []))
	if str(sealed_catalog_inventory.get("kind", "")) != "catalog" or str(sealed_catalog_inventory.get("digest", "")).length() != 64:
		definition_errors.append("delivery-day target catalog did not retain its sealed catalog provenance")
	if definition_errors.is_empty():
		# Mirror ContentLibrary's production schema boundary: the full sealed
		# catalog remains available for provenance/runtime consumers, while schema
		# validation receives its proven collections plus exact event choices.
		var schema_inventory := _dict(target_catalog.get("guaranteed", {})).duplicate(true)
		schema_inventory["event_choices"] = _dict(target_catalog.get("event_choices", {}))
		definition_errors = SequenceSchemaScript.validate_definition(definition, OperationRegistryScript, schema_inventory)
	if not definition_errors.is_empty():
		failures.append("Committed delivery-day definition failed schema/registry validation: %s" % JSON.stringify(definition_errors))
		return
	var sequence := SequenceSchemaScript.sequence(definition)
	if SequenceSchemaScript.phase_ids(definition) != ["arrival", "sorting", "verification", "awaiting_stock", "resolution"]:
		failures.append("Committed delivery-day phase graph identity/order changed.")
	var declared_zones := _array(_dict(sequence.get("declared_targets", {})).get("zones", []))
	if declared_zones != ["base::zone:background", "base::zone:center", "base::zone:exit_lane", "base::zone:foreground", "base::zone:left", "base::zone:right", "base::zone:service_lane"]:
		failures.append("Committed delivery-day sequence does not declare every exact base zone used by its spatial operations.")
	if _array(_dict(sequence.get("declared_targets", {})).get("anchors", [])) != ["base::anchor:delivery_clerk", "base::anchor:delivery_clerk_work", "base::anchor:delivery_manifest", "base::anchor:delivery_runner_route", "base::anchor:delivery_verification_shelf", "base::anchor:travel_1"]:
		failures.append("Committed delivery-day sequence does not declare its exact base actor anchors.")
	var authoring := _dict(definition.get("sequence_authoring", {}))
	var references := _dict(authoring.get("references", {}))
	if _array(references.get("events", [])) != [DELIVERY_EVENT_ID] \
		or _array(references.get("services", [])) != ["cashier_tip"] \
		or _array(references.get("items", [])) != ["delivery_twine"] \
		or _array(references.get("actors", [])) != ["ada_corner_merchant", "priya_travel_merchant"] \
		or _array(references.get("objects", [])) != ["event::event:scenario_delivery_day_stock", "service::shopkeeper:merchant", "service::service:cashier_tip", "base::travel:leave", "base::world:bar", "base::world:gas_station_casino", "base::world:pawn_shop"]:
		failures.append("Committed delivery-day external references changed: %s" % JSON.stringify(references))
	var receipts := _delivery_receipts(sequence)
	for receipt_id in ["arrival_gate_host_delivery_event", "awaiting_stock_keep_host_delivery_event_gated", "resolution_close_host_delivery_event", "cleanup_install_terminal_delivery_event_gate", "aftermath_repaired_remove_terminal_event_gate", "aftermath_broken_remove_terminal_event_gate"]:
		if not receipts.has(receipt_id):
			failures.append("Committed delivery-day receipt is missing: %s." % receipt_id)
	if _array(authoring.get("capture_ids", [])).is_empty() or _dict(authoring.get("seed_evidence", {})).is_empty() or not _array(_dict(authoring.get("seed_evidence", {})).get("base_event_gate_cases", [])).has("drained_request_activates_event"):
		failures.append("Committed delivery-day capture/seed evidence is incomplete or still claims pre-drain event authority.")

	var delivery_host_semantics := {
		"target_inventory": _dict(target_catalog.get("guaranteed", {})),
		"inventory_schema_version": int(sealed_catalog_inventory.get("schema_version", 0)),
		"inventory_digest": str(sealed_catalog_inventory.get("digest", "")),
		"base_interactions": [_delivery_base_event_record()],
		"event_choices": _dict(target_catalog.get("event_choices", {})),
	}
	var arrival := SequenceRuntimeScript.initial_state(definition, DELIVERY_NODE_ID, "delivery_day_production", delivery_host_semantics)
	var inspect_command := _runtime_command(arrival, definition, "inspect_manifest", DELIVERY_NODE_ID, "arrival", "delivery:inspect", {}, "scenario", "delivery_event_gate")
	var sorting_result := SequenceRuntimeScript.apply_command(arrival, definition, inspect_command, {})
	var sorting := _dict(sorting_result.get("state", {}))
	var shift_command := _runtime_command(sorting, definition, "shift_cartons", DELIVERY_NODE_ID, "sorting", "delivery:shift", {}, "scenario", "delivery_cartons")
	var verification_result := SequenceRuntimeScript.apply_command(sorting, definition, shift_command, {})
	var verification := _dict(verification_result.get("state", {}))
	if not bool(sorting_result.get("ok", false)) or str(sorting.get("phase_id", "")) != "sorting" or not bool(verification_result.get("ok", false)) or str(verification.get("phase_id", "")) != "verification":
		failures.append("Committed delivery-day inspect/shift objective path did not reach verification: initial=%s inspect=%s shift=%s phases=%s/%s" % [JSON.stringify(arrival.get("errors", [])), JSON.stringify(sorting_result.get("errors", [])), JSON.stringify(verification_result.get("errors", [])), str(sorting.get("phase_id", "")), str(verification.get("phase_id", ""))])
		return
	var hostile_sorting := SequenceRuntimeScript._enter_phase(arrival, definition, "sorting", "hostile_precondition", {})
	var hostile_commands := [
		{"label": "wrong owner", "result": SequenceRuntimeScript.apply_command(arrival, definition, SequenceRuntimeScript.command("inspect_manifest", DELIVERY_NODE_ID, "arrival", "delivery:hostile:owner", {}, "event", "delivery_event_gate"), {})},
		{"label": "wrong object", "result": SequenceRuntimeScript.apply_command(arrival, definition, SequenceRuntimeScript.command("inspect_manifest", DELIVERY_NODE_ID, "arrival", "delivery:hostile:object", {}, "scenario", "wrong_manifest"), {})},
		{"label": "wrong phase", "result": SequenceRuntimeScript.apply_command(arrival, definition, SequenceRuntimeScript.command("inspect_manifest", DELIVERY_NODE_ID, "sorting", "delivery:hostile:phase", {}, "scenario", "delivery_event_gate"), {})},
		{"label": "unknown command", "result": SequenceRuntimeScript.apply_command(arrival, definition, SequenceRuntimeScript.command("invent_delivery", DELIVERY_NODE_ID, "arrival", "delivery:hostile:unknown", {}, "scenario", "delivery_event_gate"), {})},
		{"label": "missing objective precondition", "result": SequenceRuntimeScript.apply_command(hostile_sorting, definition, SequenceRuntimeScript.command("shift_cartons", DELIVERY_NODE_ID, "sorting", "delivery:hostile:precondition", {}, "scenario", "delivery_cartons"), {})},
	]
	for hostile_command_value in hostile_commands:
		var hostile_command := _dict(hostile_command_value)
		var hostile_result := _dict(hostile_command.get("result", {}))
		if bool(hostile_result.get("ok", true)) or _array(hostile_result.get("errors", [])).is_empty():
			failures.append("Committed delivery-day package accepted hostile command class: %s." % str(hostile_command.get("label", "")))
	var inspect_replay := SequenceRuntimeScript.apply_command(sorting, definition, inspect_command, {})
	var inspect_conflict := SequenceRuntimeScript.apply_command(sorting, definition, SequenceRuntimeScript.command("ignore_delivery", DELIVERY_NODE_ID, "sorting", "delivery:inspect", {}, "scenario", "delivery_exit"), {})
	if not bool(inspect_replay.get("ok", false)) or not bool(inspect_replay.get("replayed", false)) or JSON.stringify(inspect_replay.get("state", {})) != JSON.stringify(sorting) or bool(inspect_conflict.get("ok", true)) or not _contains_text(_array(inspect_conflict.get("errors", [])), "reused"):
		failures.append("Committed delivery-day command idempotency/reuse contract changed.")
	for phase_state_value in [arrival, sorting, verification]:
		var phase_state := _dict(phase_state_value)
		var event_record := _delivery_event_record(phase_state)
		if event_record.is_empty() or bool(event_record.get("enabled", true)):
			failures.append("Base delivery event was not gated during %s." % str(phase_state.get("phase_id", "")))
		if not _array(phase_state.get("event_request_queue", [])).is_empty() or not _array(phase_state.get("event_request_history", [])).is_empty() or not _array(phase_state.get("fact_queue", [])).is_empty():
			failures.append("A pre-authority delivery event click/result changed request or fact queues during %s." % str(phase_state.get("phase_id", "")))

	var early_fact := SequenceRuntimeScript.fact("event_result", "event", DELIVERY_NODE_ID, "delivery:event:shared", 17, 1, {"event_id": DELIVERY_EVENT_ID, "choice_id": "clear_the_aisle", "resolution_id": DELIVERY_RESOLUTION_ID, "resolved": true, "ok": true})
	var early_queued := SequenceRuntimeScript.enqueue_fact(arrival, definition, early_fact)
	var early_rejected := SequenceRuntimeScript.flush_facts(_dict(early_queued.get("state", {})), definition, 1)
	var early_rejected_state := _dict(early_rejected.get("state", {}))
	if bool(early_rejected.get("ok", true)) or not _contains_text(_array(early_rejected.get("errors", [])), "delivered event request") or JSON.stringify(early_rejected_state) != JSON.stringify(early_queued.get("state", {})) or _array(early_rejected_state.get("fact_queue", [])).size() != 1 or not _array(early_rejected_state.get("fact_receipts", [])).is_empty() or int(early_rejected_state.get("last_flushed_fact_serial", -1)) != int(arrival.get("last_flushed_fact_serial", -2)):
		failures.append("Pre-authority correlated event result advanced state or consumed fact/producer authority.")

	var request_command := _runtime_command(verification, definition, "request_stock_check", DELIVERY_NODE_ID, "verification", "delivery:request", {}, "scenario", "sorting_shelf")
	var request_result := SequenceRuntimeScript.apply_command(verification, definition, request_command, {})
	var before_drain := _dict(request_result.get("state", {}))
	if not bool(request_result.get("ok", false)) or str(before_drain.get("phase_id", "")) != "awaiting_stock" or _array(before_drain.get("event_request_queue", [])).size() != 1 or not _array(before_drain.get("event_request_history", [])).is_empty() or bool(_delivery_event_record(before_drain).get("enabled", true)):
		failures.append("Delivery request did not queue once while keeping the base event gated before drain.")
	var request_replay := SequenceRuntimeScript.apply_command(before_drain, definition, request_command, {})
	if not bool(request_replay.get("ok", false)) or not bool(request_replay.get("replayed", false)) or JSON.stringify(request_replay.get("state", {})) != JSON.stringify(before_drain) or _array(_dict(request_replay.get("state", {})).get("event_request_queue", [])).size() != 1:
		failures.append("Delivery request replay duplicated or changed the queued event request.")
	var drained := SequenceRuntimeScript.drain_event_requests(before_drain, definition)
	var delivered := _dict(drained.get("state", {}))
	var requests := _array(drained.get("requests", []))
	var delivered_request := _dict(requests[0] if requests.size() == 1 else {})
	if not bool(drained.get("ok", false)) or requests.size() != 1 or str(delivered_request.get("event_id", "")) != DELIVERY_EVENT_ID or str(delivered_request.get("resolution_id", "")) != DELIVERY_RESOLUTION_ID or _array(delivered.get("event_request_history", [])).size() != 1 or not _array(delivered.get("event_request_queue", [])).is_empty() or bool(_delivery_event_record(delivered).get("enabled", true)):
		failures.append("Delivery bridge did not emit/history the exact request while retaining the host gate.")
	_check_delivery_event_module_resolution_boundary(library, definition, delivered, failures)
	var early_recovery_sorting := _dict(SequenceRuntimeScript.apply_command(arrival, definition, _runtime_command(arrival, definition, "inspect_manifest", DELIVERY_NODE_ID, "arrival", "delivery:recover:inspect", {}, "scenario", "delivery_event_gate"), {}).get("state", {}))
	var early_recovery_verification := _dict(SequenceRuntimeScript.apply_command(early_recovery_sorting, definition, _runtime_command(early_recovery_sorting, definition, "shift_cartons", DELIVERY_NODE_ID, "sorting", "delivery:recover:shift", {}, "scenario", "delivery_cartons"), {}).get("state", {}))
	var early_recovery_before_drain := _dict(SequenceRuntimeScript.apply_command(early_recovery_verification, definition, _runtime_command(early_recovery_verification, definition, "request_stock_check", DELIVERY_NODE_ID, "verification", "delivery:recover:request", {}, "scenario", "sorting_shelf"), {}).get("state", {}))
	var early_recovery_delivered := _dict(SequenceRuntimeScript.drain_event_requests(early_recovery_before_drain, definition).get("state", {}))
	var drain_replay := SequenceRuntimeScript.drain_event_requests(delivered, definition)
	if not _array(drain_replay.get("requests", [])).is_empty() or JSON.stringify(drain_replay.get("state", {})) != JSON.stringify(delivered):
		failures.append("Delivery bridge request drain was not exactly-once/idempotent.")
	var ui_source := FileAccess.get_file_as_string("res://scripts/ui/foundation_main.gd")
	var consume_start := ui_source.find("func _consume_scenario_event_requests()")
	var consume_end := ui_source.find("\nfunc ", consume_start + 1)
	var consumer := ui_source.substr(consume_start, consume_end - consume_start) if consume_start >= 0 and consume_end > consume_start else ""
	if consumer.find("scenario_drain_event_requests()") < 0 or consumer.find("_activate_event_object(event_id)") < consumer.find("scenario_drain_event_requests()"):
		failures.append("Production UI no longer drains the scenario request before activating its event object.")

	for hostile_value in [
		{"label": "unresolved", "payload": {"event_id": DELIVERY_EVENT_ID, "choice_id": "clear_the_aisle", "resolution_id": DELIVERY_RESOLUTION_ID, "resolved": false, "ok": true}},
		{"label": "failed", "payload": {"event_id": DELIVERY_EVENT_ID, "choice_id": "clear_the_aisle", "resolution_id": DELIVERY_RESOLUTION_ID, "resolved": true, "ok": false}},
		{"label": "unsupported_choice", "payload": {"event_id": DELIVERY_EVENT_ID, "choice_id": "invented_delivery_choice", "resolution_id": DELIVERY_RESOLUTION_ID, "resolved": true, "ok": true}},
		{"label": "wrong_event_same_choice", "payload": {"event_id": "unrelated_delivery_event", "choice_id": "clear_the_aisle", "resolution_id": DELIVERY_RESOLUTION_ID, "resolved": true, "ok": true}},
		{"label": "missing_resolution", "payload": {"event_id": DELIVERY_EVENT_ID, "choice_id": "clear_the_aisle", "resolution_id": "", "resolved": true, "ok": true}},
		{"label": "wrong_resolution", "payload": {"event_id": DELIVERY_EVENT_ID, "choice_id": "clear_the_aisle", "resolution_id": "wrong_delivery_resolution", "resolved": true, "ok": true}},
	]:
		var hostile := _dict(hostile_value)
		var hostile_fact := SequenceRuntimeScript.fact("event_result", "event", DELIVERY_NODE_ID, "delivery:event:hostile_shared", 18, 1, _dict(hostile.get("payload", {})))
		var hostile_queued := SequenceRuntimeScript.enqueue_fact(delivered, definition, hostile_fact)
		var hostile_result := SequenceRuntimeScript.flush_facts(_dict(hostile_queued.get("state", {})), definition, 1)
		var hostile_state := _dict(hostile_result.get("state", {}))
		if bool(hostile_result.get("ok", true)):
			failures.append("Delivery %s event result was not rejected." % str(hostile.get("label", "")))
		_check_rejected_delivery_fact_state(hostile_state, _dict(hostile_queued.get("state", {})), str(hostile.get("label", "")), failures)
		var corrected_fact := SequenceRuntimeScript.fact("event_result", "event", DELIVERY_NODE_ID, "delivery:event:hostile_shared", 18, 1, {"event_id": DELIVERY_EVENT_ID, "choice_id": "clear_the_aisle", "resolution_id": DELIVERY_RESOLUTION_ID, "resolved": true, "ok": true})
		var corrected_queued := SequenceRuntimeScript.enqueue_fact(delivered, definition, corrected_fact)
		var corrected_result := SequenceRuntimeScript.flush_facts(_dict(corrected_queued.get("state", {})), definition, 1)
		if not bool(corrected_result.get("ok", false)) or _array(_dict(corrected_result.get("state", {})).get("resolved_outcomes", [])) != ["repaired"]:
			failures.append("Delivery %s rejection could not recover with corrected same-id content from its returned state." % str(hostile.get("label", "")))
	var poison_fact := SequenceRuntimeScript.fact("event_result", "event", DELIVERY_NODE_ID, "delivery:event:poison", 22, 1, {"event_id": DELIVERY_EVENT_ID, "choice_id": "clear_the_aisle", "resolution_id": "wrong_delivery_resolution", "resolved": true, "ok": true})
	var future_sweep_fact := SequenceRuntimeScript.fact("sweep_changed", "sweep", DELIVERY_NODE_ID, "delivery:sweep:future", 23, 5, {"action_index": 5, "node_id": DELIVERY_NODE_ID, "segment_index": 1, "active": true})
	var poison_queued := SequenceRuntimeScript.enqueue_fact(delivered, definition, poison_fact)
	var future_queued := SequenceRuntimeScript.enqueue_fact(_dict(poison_queued.get("state", {})), definition, future_sweep_fact)
	var poison_rejected := SequenceRuntimeScript.flush_facts(_dict(future_queued.get("state", {})), definition, 1)
	var retained_after_rejection := _array(_dict(poison_rejected.get("state", {})).get("fact_queue", []))
	if bool(poison_rejected.get("ok", true)) or JSON.stringify(poison_rejected.get("state", {})) != JSON.stringify(future_queued.get("state", {})) or retained_after_rejection.size() != 2:
		failures.append("Rejected delivery fact did not preserve the other queued future fact exactly.")
	var future_only_queued := SequenceRuntimeScript.enqueue_fact(delivered, definition, future_sweep_fact)
	var retained_flush := SequenceRuntimeScript.flush_facts(_dict(future_only_queued.get("state", {})), definition, 5)
	var retained_flushed_state := _dict(retained_flush.get("state", {}))
	if not bool(retained_flush.get("ok", false)) or _array(retained_flush.get("processed", [])) != ["delivery:sweep:future"] or not _array(retained_flushed_state.get("fact_queue", [])).is_empty() or _array(retained_flushed_state.get("fact_receipts", [])) != ["delivery:sweep:future"] or _dict(retained_flushed_state.get("fact_fingerprints", {})).has("delivery:event:poison"):
		failures.append("The preserved future fact did not flush once without reviving the rejected poison identity.")

	var correlated_after_rejection := SequenceRuntimeScript.enqueue_fact(early_recovery_delivered, definition, early_fact)
	var repaired_result := SequenceRuntimeScript.flush_facts(_dict(correlated_after_rejection.get("state", {})), definition, 1)
	var repaired := _dict(repaired_result.get("state", {}))
	if not bool(repaired_result.get("ok", false)) or str(repaired.get("status", "")) != SequenceRuntimeScript.STATUS_AFTERMATH or _array(repaired.get("resolved_outcomes", [])) != ["repaired"] or not _array(repaired.get("fact_receipts", [])).has("delivery:event:shared"):
		failures.append("The exact correlated fact did not succeed after the discarded pre-authority rejection transaction.")
	var repaired_replay := SequenceRuntimeScript.enqueue_fact(repaired, definition, early_fact)
	if not bool(repaired_replay.get("ok", false)) or not bool(repaired_replay.get("duplicate", false)) or JSON.stringify(repaired_replay.get("state", {})) != JSON.stringify(repaired):
		failures.append("Committed delivery-day correlated result replay duplicated a consequence.")
	var broken_fact := SequenceRuntimeScript.fact("event_result", "event", DELIVERY_NODE_ID, "delivery:event:broken", 19, 1, {"event_id": DELIVERY_EVENT_ID, "choice_id": "take_the_deal", "resolution_id": DELIVERY_RESOLUTION_ID, "resolved": true, "ok": true})
	var broken_queued := SequenceRuntimeScript.enqueue_fact(delivered, definition, broken_fact)
	var broken := _dict(SequenceRuntimeScript.flush_facts(_dict(broken_queued.get("state", {})), definition, 1).get("state", {}))
	var refused := _dict(SequenceRuntimeScript.apply_command(arrival, definition, _runtime_command(arrival, definition, "refuse_sort", DELIVERY_NODE_ID, "arrival", "delivery:refuse", {}, "scenario", "delivery_exit"), {}).get("state", {}))
	var interrupted := _dict(SequenceRuntimeScript.apply_command(arrival, definition, _runtime_command(arrival, definition, "ignore_delivery", DELIVERY_NODE_ID, "arrival", "delivery:ignore", {}, "scenario", "delivery_exit"), {}).get("state", {}))
	var expired_result := SequenceRuntimeScript.apply_expiry(arrival, definition, "night_end", 1)
	var expired := _dict(expired_result.get("state", {}))
	var terminals := {"repaired": repaired, "broken": broken, "refused": refused, "interrupted": interrupted}
	var material_expectations := {
		"repaired": {"scene": "stocked_rack", "actor": "delivery_clerk", "service_enabled": true, "route": "bar", "route_source": "jazz_club"},
		"broken": {"scene": "torn_carton", "actor": "", "service_enabled": false, "route": "bar", "route_enabled": false},
		"refused": {"scene": "sealed_pallet", "actor": "delivery_clerk", "service_enabled": false, "route": "pawn_shop", "route_enabled": false},
		"interrupted": {"scene": "abandoned_manifest", "actor": "", "service_enabled": true, "route": "gas_station_casino", "route_enabled": false},
	}
	for outcome_value in terminals.keys():
		var outcome := str(outcome_value)
		var terminal := _dict(terminals.get(outcome_value, {}))
		if str(terminal.get("status", "")) != SequenceRuntimeScript.STATUS_AFTERMATH or _array(terminal.get("resolved_outcomes", [])) != [outcome] or not _array(terminal.get("event_request_queue", [])).is_empty():
			failures.append("Delivery-day %s outcome did not terminate without a legacy event request." % outcome)
		var terminal_fact := SequenceRuntimeScript.fact("event_result", "event", DELIVERY_NODE_ID, "delivery:event:terminal:%s" % outcome, 20, 2, {"event_id": DELIVERY_EVENT_ID, "choice_id": "clear_the_aisle", "resolution_id": DELIVERY_RESOLUTION_ID, "resolved": true, "ok": true})
		var terminal_ingress := SequenceRuntimeScript.enqueue_fact(terminal, definition, terminal_fact)
		var terminal_drain := SequenceRuntimeScript.drain_event_requests(terminal, definition)
		if bool(terminal_ingress.get("ok", true)) or not _array(terminal_drain.get("requests", [])).is_empty():
			failures.append("Delivery-day %s terminal state accepted a legacy result/request consequence." % outcome)
		var has_terminal_gate := _has_delivery_overlay(terminal, "delivery_event_terminal_gate")
		if outcome in ["repaired", "broken"] and has_terminal_gate:
			failures.append("Legitimately resolved delivery outcome %s retained the terminal event overlay." % outcome)
		elif outcome in ["refused", "interrupted"] and not has_terminal_gate:
			failures.append("Delivery outcome %s lost durable unresolved-event suppression." % outcome)
		_check_delivery_material_state(outcome, terminal, _dict(material_expectations.get(outcome, {})), failures)
		var reentry := SequenceRuntimeScript.apply_reentry(terminal, definition, "delivery_terminal_%s" % outcome)
		var reentered := _dict(reentry.get("state", {}))
		var reentry_replay := SequenceRuntimeScript.apply_reentry(reentered, definition, "delivery_terminal_%s" % outcome)
		if not bool(reentry.get("ok", false)) or not bool(reentry_replay.get("replayed", false)) or JSON.stringify(reentry_replay.get("state", {})) != JSON.stringify(reentered):
			failures.append("Delivery-day %s terminal reentry was not idempotent." % outcome)
	if not bool(expired_result.get("ok", false)) or str(expired.get("status", "")) != SequenceRuntimeScript.STATUS_CLEANED or not _has_delivery_overlay(expired, "delivery_event_terminal_gate") or not _array(expired.get("resolved_outcomes", [])).is_empty() or not _array(expired.get("event_request_queue", [])).is_empty():
		failures.append("Delivery-day ignore expiry did not clean with durable suppression and no legacy consequences.")
	var expiry_replay := SequenceRuntimeScript.apply_expiry(expired, definition, "night_end", 1)
	if not bool(expiry_replay.get("ok", false)) or JSON.stringify(expiry_replay.get("state", {})) != JSON.stringify(expired):
		failures.append("Delivery-day expiry cleanup was not idempotent.")
	var expired_ingress := SequenceRuntimeScript.enqueue_fact(expired, definition, SequenceRuntimeScript.fact("event_result", "event", DELIVERY_NODE_ID, "delivery:event:expired", 21, 2, {"event_id": DELIVERY_EVENT_ID, "choice_id": "clear_the_aisle", "resolution_id": DELIVERY_RESOLUTION_ID, "resolved": true, "ok": true}))
	if bool(expired_ingress.get("ok", true)):
		failures.append("Delivery-day expired state accepted a legacy event consequence.")

	var coexistence_base := [
		_delivery_base_event_record(),
		_interaction_record("game", "game:blackjack", "Blackjack", true),
		_interaction_record("service", "service:cashier_tip", "Cashier tip", true),
		_interaction_record("traveler", "travel:leave", "Leave", true),
		_interaction_record("sweep", "police:sweep", "Police sweep", true),
	]
	var composed := OperationRegistryScript.resolve_interactions(coexistence_base, _dict(_dict(delivered.get("semantic_state", {})).get("interactions", {})).values())
	var composed_ids: Array = []
	for record_value in _array(composed.get("records", [])):
		composed_ids.append(OperationRegistryScript.identity_from(_dict(record_value)))
	for identity in ["event::event:scenario_delivery_day_stock", "game::game:blackjack", "service::service:cashier_tip", "traveler::travel:leave", "sweep::police:sweep"]:
		if not composed_ids.has(identity):
			failures.append("Delivery-day composition overwrote coexisting interaction %s." % identity)

	# Resolution is transaction-internal in production: accepted facts enter it
	# and select an outcome in the same bounded graph evaluation. Enter it through
	# the runtime's own phase transaction to prove its exact serialization shape.
	var resolution_snapshot := SequenceRuntimeScript._enter_phase(delivered, definition, "resolution", "persistence_probe", {})
	var checkpoints := {
		"arrival": arrival, "sorting": sorting, "verification": verification,
		"awaiting_before_request_drain": before_drain, "awaiting_after_request_drain": delivered,
		"resolution_transaction": resolution_snapshot,
		"outcome_repaired": repaired, "outcome_broken": broken,
		"outcome_refused": refused, "outcome_interrupted": interrupted, "expired": expired,
	}
	for label_value in checkpoints.keys():
		var label := str(label_value)
		var expected := _dict(checkpoints.get(label_value, {}))
		var restored := _save_service_round_trip_state(expected, definition, "delivery_%s" % label, failures, "corner_store", DELIVERY_NODE_ID)
		if not restored.is_empty() and JSON.stringify(restored) != JSON.stringify(expected):
			failures.append("SaveService changed exact committed delivery-day state at %s." % label)
		var restored_text := JSON.stringify(restored)
		for private_key in ["accepted_overlay_source_identities", "effective_priority", "effective_owner_namespace", "effective_winner", "source_key"]:
			if restored_text.contains(private_key):
				failures.append("SaveService persisted reducer-private overlay metadata %s at %s." % [private_key, label])


static func _delivery_base_event_record() -> Dictionary:
	return _interaction_record("event", "event:scenario_delivery_day_stock", "Delivery stock", true)


static func _check_executable_evidence_contract(failures: Array) -> void:
	var contract := ScenarioSequenceProbeSupportScript.production_contract()
	if not bool(contract.get("ok", false)) \
		or _array(contract.get("capture_ids", [])) != ScenarioSequenceProbeSupportScript.EXPECTED_CAPTURE_IDS \
		or _array(contract.get("phase_ids", [])) != ScenarioSequenceProbeSupportScript.EXPECTED_PHASES:
		failures.append("Executable evidence support does not pin the production delivery-day contract exactly: %s" % JSON.stringify(contract.get("failures", [])))
	var obstruction_records := [
		{
			"object_id": "scenario::delivery_exit", "object_type": "scenario_sequence", "owner_namespace": "scenario",
			"stable_object_id": "delivery_exit", "role": "exit", "enabled": true, "interactive": true, "safe_exit": true,
			"scenario_sequence_actions": [
				{"id": "ignore_delivery", "enabled": true, "action_origin_owner_namespace": "scenario", "action_origin_stable_object_id": "delivery_exit", "action_origin_receipt_key": "delivery:exit", "action_origin_boundary_id": "delivery:arrival", "action_origin_fingerprint": "a".repeat(64)},
				{"id": "refuse_sort", "enabled": true, "action_origin_owner_namespace": "scenario", "action_origin_stable_object_id": "delivery_exit", "action_origin_receipt_key": "delivery:exit", "action_origin_boundary_id": "delivery:arrival", "action_origin_fingerprint": "a".repeat(64)},
			],
		},
		{
			"object_id": "scenario::delivery_event_gate", "object_type": "scenario_sequence", "owner_namespace": "scenario",
			"stable_object_id": "delivery_event_gate", "role": "workstation", "enabled": true, "interactive": true, "safe_exit": false,
			"scenario_sequence_actions": [{"id": "inspect_manifest", "enabled": true, "action_origin_owner_namespace": "scenario", "action_origin_stable_object_id": "delivery_event_gate", "action_origin_receipt_key": "delivery:event_gate", "action_origin_boundary_id": "delivery:arrival", "action_origin_fingerprint": "b".repeat(64)}],
		},
	]
	var obstruction_contract := ScenarioSequenceProbeSupportScript.obstruction_target_contract(obstruction_records)
	if not bool(obstruction_contract.get("ok", false)) \
		or _array(obstruction_contract.get("target_object_ids", [])) != ScenarioSequenceProbeSupportScript.EXPECTED_OBSTRUCTION_TARGET_IDS:
		failures.append("Executable obstruction contract rejected the distinct production event-gate and safe-exit targets.")
	var collapsed_obstruction := obstruction_records.duplicate(true)
	collapsed_obstruction[0]["object_id"] = "scenario::delivery_event_gate"
	if bool(ScenarioSequenceProbeSupportScript.obstruction_target_contract(collapsed_obstruction).get("ok", false)):
		failures.append("Executable obstruction contract accepted collapsed event-gate/safe-exit identities.")
	var disabled_obstruction := obstruction_records.duplicate(true)
	disabled_obstruction[1]["enabled"] = false
	if bool(ScenarioSequenceProbeSupportScript.obstruction_target_contract(disabled_obstruction).get("ok", false)):
		failures.append("Executable obstruction contract accepted a disabled delivery-event gate.")
	var wrong_exit_role := obstruction_records.duplicate(true)
	wrong_exit_role[0]["safe_exit"] = false
	if bool(ScenarioSequenceProbeSupportScript.obstruction_target_contract(wrong_exit_role).get("ok", false)):
		failures.append("Executable obstruction contract accepted a delivery exit without safe-exit authority.")
	var wrong_obstruction_action := obstruction_records.duplicate(true)
	wrong_obstruction_action[1]["scenario_sequence_actions"][0]["id"] = "wrong_command"
	if bool(ScenarioSequenceProbeSupportScript.obstruction_target_contract(wrong_obstruction_action).get("ok", false)):
		failures.append("Executable obstruction contract accepted the wrong delivery-event action authority.")
	var wrong_obstruction_role := obstruction_records.duplicate(true)
	wrong_obstruction_role[1]["role"] = "exit"
	if bool(ScenarioSequenceProbeSupportScript.obstruction_target_contract(wrong_obstruction_role).get("ok", false)):
		failures.append("Executable obstruction contract accepted the wrong delivery-event authored role.")
	var wrong_obstruction_token := obstruction_records.duplicate(true)
	wrong_obstruction_token[1]["scenario_sequence_actions"][0]["action_origin_stable_object_id"] = "delivery_exit"
	if bool(ScenarioSequenceProbeSupportScript.obstruction_target_contract(wrong_obstruction_token).get("ok", false)):
		failures.append("Executable obstruction contract accepted a token targeting the wrong production object.")
	var extra_obstruction_action := obstruction_records.duplicate(true)
	extra_obstruction_action[1]["scenario_sequence_actions"].append({"id": "", "enabled": true})
	if bool(ScenarioSequenceProbeSupportScript.obstruction_target_contract(extra_obstruction_action).get("ok", false)):
		failures.append("Executable obstruction contract accepted an extra malformed enabled action.")

	var named_rows: Dictionary = {}
	for row_id in ScenarioSequenceProbeSupportScript.REQUIRED_PERFORMANCE_ROWS:
		named_rows[row_id] = ScenarioSequenceProbeSupportScript.timing_summary([1.0])
	var valid_checkpoints: Array = []
	for expected_value in ScenarioSequenceProbeSupportScript.EXPECTED_TRACE_ROWS:
		var expected := _dict(expected_value)
		valid_checkpoints.append({
			"label": str(expected.get("label", "")),
			"projection": {
				"scenario_id": DELIVERY_SCENARIO_ID,
				"node_id": DELIVERY_NODE_ID,
				"phase_id": str(expected.get("phase_id", "")),
				"status": str(expected.get("status", "")),
				"resolved_outcomes": _array(expected.get("outcomes", [])).duplicate(),
			},
		})
	var valid_report := {
		"schema": "env06_6_scenario_sequence_probe_v1",
		"ok": true,
		"platform": "Windows",
		"scenario_id": DELIVERY_SCENARIO_ID,
		"seed": ScenarioSequenceProbeSupportScript.PROOF_SEED,
		"semantic": {"capture_ids": ScenarioSequenceProbeSupportScript.EXPECTED_CAPTURE_IDS, "outcomes": ScenarioSequenceProbeSupportScript.EXPECTED_OUTCOMES, "checkpoints": valid_checkpoints},
		"performance": {
			"named_rows": named_rows,
			"missing_rows": [],
			"transition": ScenarioSequenceProbeSupportScript.timing_summary([1.0]),
			"prepared_frame": ScenarioSequenceProbeSupportScript.timing_summary([1.0]),
			"failed_transitions": 0,
			"missing_transitions": 0,
			"steady_frame": {"unchanged": true},
		},
		"failures": [],
	}
	valid_report["semantic_sha256"] = ScenarioSequenceProbeSupportScript.canonical_semantic_sha256(valid_report)
	if not ScenarioSequenceProbeSupportScript.validate_probe_report(valid_report, "Windows").is_empty():
		failures.append("Valid executable probe report was rejected.")
	var timing_only := valid_report.duplicate(true)
	timing_only["performance"]["transition"]["max_ms"] = 2.0
	if ScenarioSequenceProbeSupportScript.canonical_semantic_sha256(timing_only) != str(valid_report.get("semantic_sha256", "")):
		failures.append("Executable probe canonical hash includes timing data.")
	var missing_checkpoint := valid_report.duplicate(true)
	missing_checkpoint["semantic"]["checkpoints"].pop_back()
	missing_checkpoint["semantic_sha256"] = ScenarioSequenceProbeSupportScript.canonical_semantic_sha256(missing_checkpoint)
	if ScenarioSequenceProbeSupportScript.validate_probe_report(missing_checkpoint, "Windows").is_empty():
		failures.append("Executable probe validator accepted a missing runtime checkpoint.")
	var duplicate_checkpoint := valid_report.duplicate(true)
	duplicate_checkpoint["semantic"]["checkpoints"][1] = _dict(duplicate_checkpoint["semantic"]["checkpoints"][0]).duplicate(true)
	duplicate_checkpoint["semantic_sha256"] = ScenarioSequenceProbeSupportScript.canonical_semantic_sha256(duplicate_checkpoint)
	if ScenarioSequenceProbeSupportScript.validate_probe_report(duplicate_checkpoint, "Windows").is_empty():
		failures.append("Executable probe validator accepted a duplicate runtime checkpoint.")
	var reordered_checkpoints := valid_report.duplicate(true)
	var reordered_rows := reordered_checkpoints["semantic"]["checkpoints"] as Array
	var first_row := _dict(reordered_rows[0]).duplicate(true)
	reordered_rows[0] = _dict(reordered_rows[1]).duplicate(true)
	reordered_rows[1] = first_row
	reordered_checkpoints["semantic_sha256"] = ScenarioSequenceProbeSupportScript.canonical_semantic_sha256(reordered_checkpoints)
	if ScenarioSequenceProbeSupportScript.validate_probe_report(reordered_checkpoints, "Windows").is_empty():
		failures.append("Executable probe validator accepted reordered runtime checkpoints.")
	var mislabeled_checkpoint := valid_report.duplicate(true)
	mislabeled_checkpoint["semantic"]["checkpoints"][0]["label"] = "arrival_mislabeled"
	mislabeled_checkpoint["semantic_sha256"] = ScenarioSequenceProbeSupportScript.canonical_semantic_sha256(mislabeled_checkpoint)
	if ScenarioSequenceProbeSupportScript.validate_probe_report(mislabeled_checkpoint, "Windows").is_empty():
		failures.append("Executable probe validator accepted a mislabeled runtime checkpoint.")
	var wrong_scenario := valid_report.duplicate(true)
	wrong_scenario["semantic"]["checkpoints"][0]["projection"]["scenario_id"] = "wrong_scenario"
	wrong_scenario["semantic_sha256"] = ScenarioSequenceProbeSupportScript.canonical_semantic_sha256(wrong_scenario)
	if ScenarioSequenceProbeSupportScript.validate_probe_report(wrong_scenario, "Windows").is_empty():
		failures.append("Executable probe validator accepted a checkpoint from the wrong scenario.")
	var wrong_node := valid_report.duplicate(true)
	wrong_node["semantic"]["checkpoints"][0]["projection"]["node_id"] = "wrong_node"
	wrong_node["semantic_sha256"] = ScenarioSequenceProbeSupportScript.canonical_semantic_sha256(wrong_node)
	if ScenarioSequenceProbeSupportScript.validate_probe_report(wrong_node, "Windows").is_empty():
		failures.append("Executable probe validator accepted a checkpoint from the wrong node.")
	var wrong_phase := valid_report.duplicate(true)
	wrong_phase["semantic"]["checkpoints"][0]["projection"]["phase_id"] = "sorting"
	if ScenarioSequenceProbeSupportScript.canonical_semantic_sha256(wrong_phase) == str(valid_report.get("semantic_sha256", "")):
		failures.append("Executable probe canonical hash ignored semantic trace data.")
	wrong_phase["semantic_sha256"] = ScenarioSequenceProbeSupportScript.canonical_semantic_sha256(wrong_phase)
	if ScenarioSequenceProbeSupportScript.validate_probe_report(wrong_phase, "Windows").is_empty():
		failures.append("Executable probe validator accepted the wrong checkpoint phase.")
	var wrong_status := valid_report.duplicate(true)
	wrong_status["semantic"]["checkpoints"][9]["projection"]["status"] = "active"
	wrong_status["semantic_sha256"] = ScenarioSequenceProbeSupportScript.canonical_semantic_sha256(wrong_status)
	if ScenarioSequenceProbeSupportScript.validate_probe_report(wrong_status, "Windows").is_empty():
		failures.append("Executable probe validator accepted the wrong checkpoint status.")
	var wrong_outcome := valid_report.duplicate(true)
	wrong_outcome["semantic"]["checkpoints"][9]["projection"]["resolved_outcomes"] = ["broken"]
	wrong_outcome["semantic_sha256"] = ScenarioSequenceProbeSupportScript.canonical_semantic_sha256(wrong_outcome)
	if ScenarioSequenceProbeSupportScript.validate_probe_report(wrong_outcome, "Windows").is_empty():
		failures.append("Executable probe validator accepted the wrong checkpoint outcome.")
	var missing_semantic_capture := valid_report.duplicate(true)
	missing_semantic_capture["semantic"]["capture_ids"].pop_back()
	missing_semantic_capture["semantic_sha256"] = ScenarioSequenceProbeSupportScript.canonical_semantic_sha256(missing_semantic_capture)
	if ScenarioSequenceProbeSupportScript.validate_probe_report(missing_semantic_capture, "Windows").is_empty():
		failures.append("Executable probe validator accepted a missing semantic capture id.")
	var missing_row := valid_report.duplicate(true)
	missing_row["performance"]["named_rows"].erase("load_rebuild")
	missing_row["performance"]["missing_rows"] = ["load_rebuild"]
	if ScenarioSequenceProbeSupportScript.validate_probe_report(missing_row, "Windows").is_empty():
		failures.append("Executable probe validator accepted a missing required performance row.")
	var over_budget := valid_report.duplicate(true)
	over_budget["performance"]["transition"]["p95_ms"] = 16.001
	if ScenarioSequenceProbeSupportScript.validate_probe_report(over_budget, "Windows").is_empty():
		failures.append("Executable probe validator accepted an over-budget native transition.")

	var capture_rows: Array = []
	for expected_value in ScenarioSequenceProbeSupportScript.EXPECTED_TRACE_ROWS:
		var expected := _dict(expected_value)
		var capture_id := str(expected.get("label", ""))
		capture_rows.append({
			"capture_id": capture_id,
			"file": "%s.png" % capture_id,
			"png_sha256": ("png:%s" % capture_id).sha256_text(),
			"width": 1280,
			"height": 720,
			"image_format": "png",
			"scenario_id": DELIVERY_SCENARIO_ID,
			"node_id": DELIVERY_NODE_ID,
			"phase_id": str(expected.get("phase_id", "")),
			"status": str(expected.get("status", "")),
			"outcomes": _array(expected.get("outcomes", [])).duplicate(),
			"visual_state_sha256": ("state:%s" % capture_id).sha256_text(),
			"live_assertions_passed": true,
		})
	var valid_manifest := {
		"schema": "env06_6_scenario_sequence_capture_manifest_v1",
		"passed": true,
		"failures": [],
		"scenario_id": DELIVERY_SCENARIO_ID,
		"seed": ScenarioSequenceProbeSupportScript.PROOF_SEED,
		"capture_ids": ScenarioSequenceProbeSupportScript.EXPECTED_CAPTURE_IDS,
		"captures": capture_rows,
	}
	if not ScenarioSequenceProbeSupportScript.validate_capture_manifest(valid_manifest).is_empty():
		failures.append("Valid executable visual manifest was rejected.")
	var duplicate_capture := valid_manifest.duplicate(true)
	duplicate_capture["captures"].append(_dict(duplicate_capture["captures"][0]).duplicate(true))
	if ScenarioSequenceProbeSupportScript.validate_capture_manifest(duplicate_capture).is_empty():
		failures.append("Executable visual validator accepted a duplicate capture id.")
	var weak_capture := valid_manifest.duplicate(true)
	weak_capture["captures"][20]["live_assertions_passed"] = false
	if ScenarioSequenceProbeSupportScript.validate_capture_manifest(weak_capture).is_empty():
		failures.append("Executable visual validator accepted failed small-screen live assertions.")
	var reordered_capture := valid_manifest.duplicate(true)
	var reordered_capture_rows := reordered_capture["captures"] as Array
	var first_capture := _dict(reordered_capture_rows[0]).duplicate(true)
	reordered_capture_rows[0] = _dict(reordered_capture_rows[1]).duplicate(true)
	reordered_capture_rows[1] = first_capture
	if ScenarioSequenceProbeSupportScript.validate_capture_manifest(reordered_capture).is_empty():
		failures.append("Executable visual validator accepted reordered runtime capture rows.")
	var wrong_capture_identity := valid_manifest.duplicate(true)
	wrong_capture_identity["captures"][0]["node_id"] = "wrong_node"
	if ScenarioSequenceProbeSupportScript.validate_capture_manifest(wrong_capture_identity).is_empty():
		failures.append("Executable visual validator accepted a capture from the wrong production node.")
	var wrong_capture_outcome := valid_manifest.duplicate(true)
	wrong_capture_outcome["captures"][9]["outcomes"] = ["broken"]
	if ScenarioSequenceProbeSupportScript.validate_capture_manifest(wrong_capture_outcome).is_empty():
		failures.append("Executable visual validator accepted the wrong material outcome trace.")

	var main_source := FileAccess.get_file_as_string("res://tools/scenario_sequence_probe_main.gd")
	var scene_source := FileAccess.get_file_as_string("res://tools/scenario_sequence_probe_main.tscn")
	var visual_source := FileAccess.get_file_as_string("res://tools/scenario_sequence_visual_capture.ps1")
	var web_source := FileAccess.get_file_as_string("res://tools/scenario_sequence_web_capture.mjs")
	var parity_source := FileAccess.get_file_as_string("res://tools/scenario_sequence_parity_performance.ps1")
	if not main_source.begins_with("extends Node") \
		or main_source.find("res://scenes/main.tscn") < 0 \
		or main_source.find("activate_interactable_object") < 0 \
		or main_source.find("global_rect_for_object") < 0 \
		or main_source.find("object_id_at_local_position") < 0 \
		or main_source.find("_obstruction_target_evidence") < 0 \
		or main_source.find("intersection(reserved).get_area() > 0.0") < 0 \
		or main_source.find("RenderingServer.frame_post_draw") < 0 \
		or main_source.find("scenario_flush_facts") >= 0 \
		or main_source.find("var scenario_added := false") >= 0 \
		or main_source.find("scenario_hit_rects.size() != 1") >= 0 \
		or main_source.find("intersection(reserved).get_area() > 0.5") >= 0:
		failures.append("Executable evidence main scene lost a production seam or introduced manual fact flushing.")
	if scene_source.find("type=\"Node\"") < 0 or scene_source.find("scenario_sequence_probe_main.gd") < 0:
		failures.append("Executable evidence scene is not a Node-backed dedicated entry scene.")
	if visual_source.find("scenario_sequence_probe_main.tscn") < 0 or visual_source.find("--headless") >= 0 or visual_source.find("Get-FileHash") < 0 or visual_source.find("expectedRuntimeTraceIds") < 0 or visual_source.find("expectedRuntimeStateById") < 0:
		failures.append("Executable visual wrapper is not direct, windowed, and byte-hash fail-closed.")
	if web_source.find("Emulation.setCPUThrottlingRate") < 0 or web_source.find("pageerror") < 0 or web_source.find("requestfailed") < 0:
		failures.append("Executable Web capture lost CPU4 or browser-error authority.")
	if parity_source.find("native_process_1") < 0 \
		or parity_source.find("web_process_1") < 0 \
		or parity_source.find("native_web_semantic_exact") < 0 \
		or parity_source.find("expectedRuntimeTraceLabels") < 0 \
		or parity_source.find("expectedRuntimeStateByLabel") < 0 \
		or parity_source.find("semantic.checkpoints") < 0 \
		or parity_source.find("Copy-Item -LiteralPath $canonicalAddon") < 0 \
		or parity_source.find("Required Windows host library is unavailable") < 0 \
		or parity_source.find("Get-ChildItem -LiteralPath (Join-Path $transientAddon \"bin\") -Filter \"*.wasm\"") < 0:
		failures.append("Executable parity wrapper lost two-process exactness or transient build authority.")


static func _check_delivery_event_module_resolution_boundary(library: ContentLibrary, definition: Dictionary, delivered: Dictionary, failures: Array) -> void:
	var contract_source := FileAccess.get_file_as_string("res://scripts/tests/foundation/scenario_sequence_contract.gd")
	var probe_start := contract_source.find("static func _check_delivery_event_module_resolution_boundary")
	var probe_end := contract_source.find("\nstatic func _delivery_event_record", probe_start + 1)
	var production_probe := contract_source.substr(probe_start, probe_end - probe_start) if probe_start >= 0 and probe_end > probe_start else ""
	if production_probe.contains("scenario_" + "flush_facts("):
		failures.append("Delivery EventModule production-path probe must not manually flush scenario facts.")
	var event_definition := library.event(DELIVERY_EVENT_ID)
	if event_definition.is_empty():
		failures.append("Delivery-day production event definition is missing.")
		return
	var invalid_run_state = _delivery_event_module_run_state(definition, library, delivered, "invalid")
	var invalid_before := _delivery_event_module_observation(invalid_run_state)
	var invalid_module = EventModuleScript.new()
	invalid_module.setup(event_definition, library)
	var invalid_result := invalid_module.resolve(invalid_run_state, invalid_run_state.current_environment, "invented_delivery_choice")
	if bool(invalid_result.get("ok", true)) or JSON.stringify(_delivery_event_module_observation(invalid_run_state)) != JSON.stringify(invalid_before):
		failures.append("EventModule invalid delivery choice crossed a boundary or changed production state.")
	for expectation_value in [
		{"choice_id": "clear_the_aisle", "outcome": "repaired", "bankroll_delta": 0, "suspicion_delta": 0, "item_count": 0, "flag_id": "delivery_day_passed"},
		{"choice_id": "take_the_deal", "outcome": "broken", "bankroll_delta": 6, "suspicion_delta": 1, "item_count": 1, "flag_id": "delivery_day_deal"},
	]:
		var expectation := _dict(expectation_value)
		var choice_id := str(expectation.get("choice_id", ""))
		var run_state = _delivery_event_module_run_state(definition, library, delivered, choice_id)
		var action_before := int(run_state.event_cadence_summary().get("action_index", 0))
		var turns_before := int(run_state.current_environment.get("turns", 0))
		var boundary_before := int(_dict(run_state.current_environment.get("scenario_sequence_state", {})).get("boundary_serial", 0))
		var bankroll_before := int(run_state.bankroll)
		var suspicion_before := int(run_state.suspicion_level())
		var story_count_before := _array(run_state.story_log).size()
		var fact_receipts_before := _array(_dict(run_state.current_environment.get("scenario_sequence_state", {})).get("fact_receipts", []))
		var event_module = EventModuleScript.new()
		event_module.setup(event_definition, library)
		var event_result := event_module.resolve(run_state, run_state.current_environment, choice_id)
		var terminal := _dict(run_state.current_environment.get("scenario_sequence_state", {}))
		var exact_event_receipt := "%s:%s" % [DELIVERY_RESOLUTION_ID, choice_id]
		var fact_receipts := _array(terminal.get("fact_receipts", []))
		var new_fact_receipts := fact_receipts.slice(fact_receipts_before.size())
		var event_fact_receipts: Array = []
		for receipt_value in new_fact_receipts:
			if str(receipt_value).begins_with("event:event_result:"):
				event_fact_receipts.append(receipt_value)
		if not bool(event_result.get("ok", false)) \
		or str(terminal.get("status", "")) != SequenceRuntimeScript.STATUS_AFTERMATH \
		or _array(terminal.get("resolved_outcomes", [])) != [str(expectation.get("outcome", ""))] \
		or _array(terminal.get("event_choice_receipts", [])) != [exact_event_receipt]:
			failures.append("EventModule did not produce immediate exact %s delivery aftermath/receipt: result=%s lifecycle=%s terminal_status=%s terminal_phase=%s terminal_errors=%s." % [choice_id, JSON.stringify(event_result.get("errors", [])), JSON.stringify(run_state.current_environment.get("scenario_sequence_lifecycle_errors", [])), str(terminal.get("status", "")), str(terminal.get("phase_id", "")), JSON.stringify(terminal.get("errors", []))])
		if not _array(terminal.get("fact_queue", [])).is_empty() or not _array(terminal.get("event_request_queue", [])).is_empty() or event_fact_receipts.size() != 1:
			failures.append("EventModule left duplicate or pending %s delivery fact/request consequences." % choice_id)
		if int(run_state.event_cadence_summary().get("action_index", -1)) != action_before + 1 \
			or int(run_state.current_environment.get("turns", -1)) != turns_before + 1 \
			or int(terminal.get("boundary_serial", -1)) != boundary_before + 1:
			failures.append("EventModule %s resolution did not stay on its single advanced boundary." % choice_id)
		if int(run_state.bankroll) != bankroll_before + int(expectation.get("bankroll_delta", 0)) \
			or int(run_state.suspicion_level()) != suspicion_before + int(expectation.get("suspicion_delta", 0)) \
			or _array(run_state.current_environment.get("resolved_event_ids", [])) != [DELIVERY_EVENT_ID] \
			or _array(run_state.inventory) != (["delivery_twine"] if int(expectation.get("item_count", 0)) == 1 else []) \
			or not bool(run_state.narrative_flags.get(str(expectation.get("flag_id", "")), false)) \
			or _array(run_state.story_log).size() != story_count_before + 1:
			failures.append("EventModule duplicated or lost base %s event consequences." % choice_id)
		var resolved_observation := _delivery_event_module_observation(run_state)
		var replay_allowed := event_module.can_trigger(run_state, run_state.current_environment)
		if replay_allowed:
			event_module.resolve(run_state, run_state.current_environment, choice_id)
		if replay_allowed or JSON.stringify(_delivery_event_module_observation(run_state)) != JSON.stringify(resolved_observation):
			failures.append("EventModule production replay gate duplicated %s facts, receipts, reward, or boundaries." % choice_id)


static func _delivery_event_module_run_state(definition: Dictionary, library: ContentLibrary, delivered: Dictionary, seed_suffix: String):
	var run_state = RunStateScript.new()
	run_state.start_new("corner_store_delivery_day_env06_6")
	var installed_definition := definition.duplicate(true)
	installed_definition[ScenarioEngineScript.VALIDATED_SEQUENCE_MARKER] = true
	var rng = run_state.create_rng("env06_6:executable-proof")
	var environment := EnvironmentInstanceScript.from_archetype(library.environment_archetype("corner_store"), 1, rng, library, {}, installed_definition).to_dict()
	environment["world_node_id"] = DELIVERY_NODE_ID
	environment["layout"] = EnvironmentInstanceScript.ensure_generated_layout(environment)
	var authoritative := EnvironmentBaseSemanticRecordsScript.authoritative_interactable_records(environment, library)
	var stamped := EnvironmentBaseSemanticRecordsScript.stamp_interactable_records(_array(authoritative.get("records", [])), environment, library)
	var produced := EnvironmentBaseSemanticRecordsScript.from_interactable_records(_array(stamped.get("records", [])))
	var base_interactions := _array(produced.get("interactions", []))
	var base_actors := _array(produced.get("actors", []))
	var instance_inventory := EnvironmentSemanticInventoryScript.for_instance(environment, library, base_interactions, base_actors)
	var inventory_errors := _array(authoritative.get("errors", [])) + _array(stamped.get("errors", [])) + _array(produced.get("errors", [])) + EnvironmentSemanticInventoryScript.validate(instance_inventory)
	if not inventory_errors.is_empty():
		environment["scenario_sequence_lifecycle_errors"] = inventory_errors
		run_state.current_environment = environment
		return run_state
	var event_choices := EnvironmentSemanticInventoryScript.event_choice_index(_array(environment.get("event_ids", [])), library)
	var trusted_delivered := delivered.duplicate(true)
	var semantic := _dict(trusted_delivered.get("semantic_state", {}))
	var exact_inventory := EnvironmentSemanticInventoryScript.exact_collections(instance_inventory)
	exact_inventory["event_choices"] = event_choices.duplicate(true)
	semantic["target_inventory"] = exact_inventory
	semantic["declared_targets"] = SequenceSchemaScript.verified_declared_targets(installed_definition, exact_inventory)
	semantic["base_interactions"] = base_interactions.duplicate(true)
	semantic["inventory_schema_version"] = int(instance_inventory.get("schema_version", 0))
	semantic["inventory_digest"] = str(instance_inventory.get("digest", ""))
	semantic["event_choices"] = event_choices.duplicate(true)
	trusted_delivered["semantic_state"] = semantic
	environment["scenario_state"] = ScenarioEngineScript.initial_state(installed_definition)
	environment["scenario_sequence_definition"] = installed_definition
	environment["scenario_sequence_state"] = trusted_delivered
	environment["scenario_base_interactions"] = base_interactions.duplicate(true)
	environment["scenario_base_actors"] = base_actors.duplicate(true)
	environment["scenario_semantic_inventory"] = instance_inventory
	environment["scenario_semantic_inventory_version"] = int(instance_inventory.get("schema_version", 0))
	environment["scenario_semantic_digest"] = str(instance_inventory.get("digest", ""))
	environment["scenario_semantic_action_digest"] = SequenceRuntimeScript.base_interaction_action_authority_digest(base_interactions)
	environment["scenario_semantic_ready"] = true
	environment["scenario_restore_contract"] = RunStateScript.ENV06_6B_SEMANTIC_RESTORE_EQUIVALENCE_V1
	environment["scenario_event_choices"] = event_choices
	environment["scenario_layout_base_records"] = _array(stamped.get("records", []))
	environment["scenario_layout_context"] = {}
	# This boundary is about EventModule's atomic result publication, not active
	# room geometry. Derive a real passive seal from the production layout
	# resolver, then retain the exact catalog-authenticated awaiting-stock state.
	var passive_state := trusted_delivered.duplicate(true)
	passive_state["status"] = SequenceRuntimeScript.STATUS_CLEANED
	var passive_projection := SequenceRuntimeScript.public_projection(passive_state, installed_definition)
	var passive_layout := ScenarioLayoutResolverScript.resolve(_array(stamped.get("records", [])), passive_projection, environment)
	if not bool(passive_layout.get("ok", false)):
		environment["scenario_sequence_lifecycle_errors"] = _array(passive_layout.get("errors", []))
		run_state.current_environment = environment
		return run_state
	environment["scenario_sequence_projection"] = _dict(passive_layout.get("projection", {}))
	environment["scenario_layout_authority"] = _dict(passive_layout.get("layout_authority", {}))
	environment["scenario_layout_audit"] = _dict(passive_layout.get("layout_audit", {}))
	environment["scenario_layout_authority_digest"] = str(passive_layout.get("layout_authority_digest", ""))
	environment["scenario_render_snapshot"] = ScenarioLayoutResolverScript.sealed_renderer_snapshot(passive_layout)
	var normalization_probe := environment.duplicate(true)
	var normalized_state := ScenarioEngineScript.ensure_sequence_state(normalization_probe, installed_definition)
	if str(normalized_state.get("status", "")) != SequenceRuntimeScript.STATUS_ACTIVE:
		var host_probe := ScenarioEngineScript.sequence_host_semantics(environment)
		var initial_probe := SequenceRuntimeScript.initial_state(installed_definition, DELIVERY_NODE_ID, "event_boundary_probe", host_probe)
		environment["scenario_sequence_lifecycle_errors"] = ["event boundary normalization probe: %s initial=%s host=%s" % [JSON.stringify(normalized_state.get("errors", [])), JSON.stringify(initial_probe.get("errors", [])), JSON.stringify(host_probe.get("inventory_errors", []))]]
	run_state.current_environment = environment
	return run_state


static func _delivery_event_module_observation(run_state) -> Dictionary:
	return {
		"bankroll": int(run_state.bankroll),
		"suspicion": int(run_state.suspicion_level()),
		"inventory": _array(run_state.inventory),
		"narrative_flags": _dict(run_state.narrative_flags),
		"story_log": _array(run_state.story_log),
		"event_cadence": run_state.event_cadence_summary(),
		"environment_turns": int(run_state.current_environment.get("turns", 0)),
		"resolved_event_ids": _array(run_state.current_environment.get("resolved_event_ids", [])),
		"sequence_state": _dict(run_state.current_environment.get("scenario_sequence_state", {})),
	}


static func _delivery_event_record(state: Dictionary) -> Dictionary:
	var resolved := OperationRegistryScript.resolve_interactions([_delivery_base_event_record()], _dict(_dict(state.get("semantic_state", {})).get("interactions", {})).values())
	for record_value in _array(resolved.get("records", [])):
		var record := _dict(record_value)
		if OperationRegistryScript.identity_from(record) == "event::event:scenario_delivery_day_stock":
			return record
	return {}


static func _check_rejected_delivery_fact_state(actual: Dictionary, expected: Dictionary, label: String, failures: Array) -> void:
	for stable_key in [
		"fact_queue", "fact_receipts", "fact_fingerprints", "last_flushed_fact_serial",
		"phase_id", "status", "local_state", "objective_progress", "semantic_state",
		"event_choice_receipts", "event_request_queue", "event_request_history",
		"resolved_branches", "resolved_outcomes", "command_receipts", "operation_receipts",
	]:
		if JSON.stringify(actual.get(stable_key)) != JSON.stringify(expected.get(stable_key)):
			failures.append("Delivery %s rejection changed authoritative %s." % [label, stable_key])
	if int(actual.get("fact_serial_next", -1)) != int(expected.get("fact_serial_next", -2)):
		failures.append("Delivery %s rejection changed the retained ingress allocation." % label)


static func _has_delivery_overlay(state: Dictionary, stable_object_id: String) -> bool:
	for operation_value in _dict(_dict(state.get("semantic_state", {})).get("interactions", {})).values():
		if str(_dict(operation_value).get("owner_namespace", "")) == "scenario" and str(_dict(operation_value).get("stable_object_id", "")) == stable_object_id:
			return true
	return false


static func _check_delivery_material_state(outcome: String, state: Dictionary, expected: Dictionary, failures: Array) -> void:
	var semantic := _dict(state.get("semantic_state", {}))
	var scene_key := "scenario::%s" % str(expected.get("scene", ""))
	var actor_id := str(expected.get("actor", ""))
	var actor_key := "scenario::%s" % actor_id
	var service := _dict(_dict(semantic.get("services", {})).get("scenario::cashier_tip", {}))
	var route_key := "base::world:%s" % str(expected.get("route", ""))
	var route := _dict(_dict(semantic.get("routes", {})).get(route_key, {}))
	if not _dict(semantic.get("scene_objects", {})).has(scene_key) \
		or not actor_id.is_empty() and not _dict(semantic.get("actors", {})).has(actor_key) \
		or actor_id.is_empty() and _dict(semantic.get("actors", {})).has("scenario::delivery_clerk") \
		or service.is_empty() or bool(service.get("enabled", not bool(expected.get("service_enabled", false)))) != bool(expected.get("service_enabled", false)) \
		or route.is_empty() \
		or expected.has("route_enabled") and bool(route.get("enabled", not bool(expected.get("route_enabled", false)))) != bool(expected.get("route_enabled", false)) \
		or expected.has("route_source") and str(route.get("source_id", "")) != str(expected.get("route_source", "")):
		failures.append("Delivery-day %s aftermath lost its exact scene/actor/service/route material state." % outcome)


static func _delivery_receipts(sequence: Dictionary) -> Array:
	var result: Array = []
	for phase_value in _array(_dict(sequence.get("phase_graph", {})).get("phases", [])):
		var phase := _dict(phase_value)
		for family in ["scene_ops", "interaction_ops", "actor_ops", "transition_ops"]:
			for operation_value in _array(phase.get(family, [])):
				result.append(str(_dict(operation_value).get("receipt_id", "")))
	for operation_value in _array(_dict(sequence.get("cleanup", {})).get("operations", [])):
		result.append(str(_dict(operation_value).get("receipt_id", "")))
	for aftermath_value in _dict(sequence.get("aftermath", {})).values():
		var aftermath := _dict(aftermath_value)
		for family in ["scene_ops", "interaction_ops", "actor_ops", "service_ops", "game_ops", "route_ops"]:
			for operation_value in _array(aftermath.get(family, [])):
				result.append(str(_dict(operation_value).get("receipt_id", "")))
	return result


static func _check_material_projection(failures: Array) -> void:
	var definition := _runtime_definition()
	var state := SequenceRuntimeScript.initial_state(definition, "bar_node", "material_seed", _fixture_host_semantics(definition))
	var semantic := _dict(state.get("semantic_state", {}))
	semantic["services"] = {"scenario::night_service": {"owner_namespace": "scenario", "stable_object_id": "night_service", "id": "night_service", "label": "Night service", "enabled": true}}
	semantic["games"] = {"scenario::blackjack": {"owner_namespace": "scenario", "stable_object_id": "blackjack", "id": "blackjack", "label": "Blackjack", "enabled": true, "modifier": {"tone": "tense"}}}
	semantic["routes"] = {"scenario::old_exit": {"owner_namespace": "scenario", "stable_object_id": "old_exit", "source_id": "alternate_exit", "enabled": true}}
	state["semantic_state"] = semantic
	var environment := {"id": "bar_001", "archetype_id": "bar", "world_node_id": "bar_node", "game_ids": ["slots"], "service_ids": [], "travel_hooks": ["old_exit"], "scenario_game_modifiers": {}, "layout": {"object_rects": {}}, "scenario_state": {"id": definition.get("id", ""), "archetype_id": "bar", "phases": []}, "scenario_sequence_state": state}
	ScenarioEngineScript._materialize_sequence_services_games_routes(environment, SequenceRuntimeScript.public_projection(state, definition))
	if not _array(environment.get("service_ids", [])).has("night_service") or not _array(environment.get("game_ids", [])).has("blackjack") or _array(environment.get("travel_hooks", [])) != ["alternate_exit"] or _dict(_dict(environment.get("scenario_game_modifiers", {})).get("blackjack", {})).is_empty():
		failures.append("Scenario semantic service/game/modifier/route state was not materialized into production environment fields.")


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


static func finalization_fixture_definition() -> Dictionary:
	var definition := _runtime_definition()
	var sequence := _dict(definition.get("sequence", {}))
	var graph := _dict(sequence.get("phase_graph", {}))
	var phases := _array(graph.get("phases", []))
	var arrival := _dict(phases[0])
	arrival["actor_ops"] = []
	var arrival_interaction_ops := _array(arrival.get("interaction_ops", []))
	for interaction_index in range(arrival_interaction_ops.size() - 1, -1, -1):
		if str(_dict(arrival_interaction_ops[interaction_index]).get("stable_object_id", "")) == "fixture_100":
			arrival_interaction_ops.remove_at(interaction_index)
	arrival["interaction_ops"] = arrival_interaction_ops
	var command_visual := _operation_fixture("scene_ops", "spawn", 200)
	command_visual["stable_object_id"] = "command_console"
	command_visual["object"] = {
		"label": "Exit command console",
		"role": "control",
		"anchor_id": "bar_actor",
		"bounds": {"w": 72, "h": 56},
		"visible": true,
		"enabled": true,
	}
	var arrival_scene_ops := _array(arrival.get("scene_ops", []))
	arrival_scene_ops.append(command_visual)
	arrival["scene_ops"] = arrival_scene_ops
	phases[0] = arrival
	graph["phases"] = phases
	sequence["phase_graph"] = graph
	var cleanup := _dict(sequence.get("cleanup", {}))
	var cleanup_operations := _array(cleanup.get("operations", []))
	for cleanup_index in range(cleanup_operations.size() - 1, -1, -1):
		var cleanup_operation := _dict(cleanup_operations[cleanup_index])
		if str(cleanup_operation.get("family", "")) == "actor_ops" and str(cleanup_operation.get("stable_object_id", "")) == "fixture_105":
			cleanup_operations.remove_at(cleanup_index)
		elif str(cleanup_operation.get("family", "")) == "interaction_ops" and str(cleanup_operation.get("stable_object_id", "")) == "fixture_100":
			cleanup_operations.remove_at(cleanup_index)
	cleanup_operations.append({"family": "scene_ops", "op": "remove", "receipt_id": "cleanup_scene_command_console", "owner_namespace": "scenario", "stable_object_id": "command_console"})
	cleanup["operations"] = cleanup_operations
	sequence["cleanup"] = cleanup
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
		{"id": "refuse", "label": "Refuse", "input_action": "ui_cancel", "non_color_state": "choice"},
	]
	interaction_op["interaction"]["input_actions"] = ["confirm", "ui_cancel"]
	arrival["interaction_ops"] = _array(arrival.get("interaction_ops", [])) + [interaction_op]
	arrival["branches"] = [{"id": "continue", "condition": {"type": "command", "command_id": "prepare"}, "next_phase": "complication"}]
	arrival["advance_after_actions"] = 0
	phases[0] = arrival
	var complication := _dict(phases[1])
	complication["branches"] = [
		{"id": "complication_break", "condition": {"type": "fact", "fact_type": "heat_changed"}, "next_phase": "aftermath"},
		{"id": "complication_refuse", "condition": {"type": "command", "command_id": "refuse"}, "next_phase": "aftermath"},
		{"id": "complication_repair", "condition": {"type": "command", "command_id": "finish"}, "next_phase": "aftermath"},
	]
	phases[1] = complication
	graph["phases"] = phases
	sequence["phase_graph"] = graph
	var cleanup := _dict(sequence.get("cleanup", {}))
	var cleanup_operations := _array(cleanup.get("operations", []))
	sequence["objectives"] = [{"id": "clear_exit", "label": "Keep the exit clear", "progress_label": "Exit lane", "steps": [{"id": "move_chair", "label": "Move the chair", "kind": "command", "command_id": "prepare"}], "outcomes": ["success", "failure", "ignore", "cancel"]}]
	sequence["fact_subscriptions"] = [
		{"fact_type": "event_result", "payload_equals": {"event_id": "fixture_event"}},
		{"fact_type": "heat_changed", "handler": "set_local", "inputs": {"key": "pressure", "value_from_payload": "current"}},
	]
	cleanup_operations.append({"family": "interaction_ops", "op": "remove", "receipt_id": "cleanup_command_console", "owner_namespace": "scenario", "stable_object_id": "command_console"})
	cleanup["operations"] = cleanup_operations
	sequence["cleanup"] = cleanup
	definition["sequence"] = sequence
	definition["sequence"]["sequence_signature"] = SequenceSchemaScript.calculated_signature_hash(definition)
	return definition


static func _safe_early_cleanup_definition() -> Dictionary:
	var definition := _runtime_definition()
	var arrival := _dict(definition["sequence"]["phase_graph"]["phases"][0])
	arrival["terminal"] = true
	arrival["branches"] = [
		{"id": "break_early", "condition": {"type": "fact", "fact_type": "heat_changed"}, "outcome": "broken"},
		{"id": "refuse_early", "condition": {"type": "command", "command_id": "finish"}, "outcome": "refused"},
		{"id": "finish_early", "condition": {"type": "always"}, "outcome": "repaired"},
	]
	definition["sequence"]["phase_graph"]["phases"] = [arrival]
	# This single-phase cleanup fixture intentionally cannot evidence the normal
	# three-phase action-boundary completion row. Exercise the frozen schema's
	# explicit signed-exception path without weakening production validation.
	definition["sequence"]["completion_contract"].erase("action_boundaries")
	definition["sequence"]["owner_exceptions"].append({
		"row": "action_boundaries",
		"reason": "Single-phase early-cleanup fixture isolates replay-safe cleanup before normal action-boundary progression.",
		"owner": "env06_6_contract",
		"approved_on": "2026-08-27",
	})
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
				"pressure": {"type": "int", "default": 0, "min": 0, "max": 5, "visibility": "public"},
				"protected_exit": {"type": "bool", "default": false, "visibility": "private"},
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
						"actor_ops": [_operation_fixture("actor_ops", "spawn", 105)],
						"transition_ops": [_operation_fixture("transition_ops", "feedback", 100)],
						"branches": [{"id": "continue", "condition": {"type": "command", "command_id": "protect_exit"}, "next_phase": "complication"}],
					},
					{
						"id": "complication", "label": "Blocked lane", "arrival_feedback": "A second chair skids into the route.", "exit_prompt": "Keep the marked exit lane readable.",
						"entry_conditions": [], "objective_ids": ["clear_exit"], "advance_after_actions": 1,
						"scene_ops": [_operation_fixture("scene_ops", "spawn", 104)], "interaction_ops": [], "actor_ops": [],
						"transition_ops": [_operation_fixture("transition_ops", "stage", 104)],
						"branches": [{"id": "settle", "condition": {"type": "always"}, "next_phase": "aftermath"}],
					},
					{
						"id": "aftermath", "label": "Cleanup", "arrival_feedback": "The lane opens again.", "exit_prompt": "Leave through the clear front door.", "terminal": true,
						"entry_conditions": [], "objective_ids": [], "advance_after_actions": 0, "scene_ops": [], "interaction_ops": [_operation_fixture("interaction_ops", "add", 201)], "actor_ops": [], "transition_ops": [],
						"branches": [
							{"id": "break", "condition": {"type": "fact", "fact_type": "heat_changed"}, "outcome": "broken"},
							{"id": "refuse", "condition": {"type": "command", "command_id": "refuse"}, "outcome": "refused"},
							{"id": "finish", "condition": {"type": "command", "command_id": "finish"}, "outcome": "repaired"},
						],
					},
				],
			},
			"objectives": [{"id": "clear_exit", "label": "Keep the exit clear", "progress_label": "Exit lane", "steps": [{"id": "move_chair", "label": "Move the chair", "kind": "command", "command_id": "protect_exit"}], "outcomes": ["success", "failure", "ignore", "cancel"]}],
			"reentry_policy": {"partial": "resume", "terminal": "aftermath", "expired": "expired"},
			"expiry": {"boundary": "night_end", "after": 1, "policy": "ignore"},
			"cleanup": {"operations": [
				{"family": "scene_ops", "op": "remove", "receipt_id": "cleanup_scene", "owner_namespace": "scenario", "stable_object_id": "fixture_100"},
				{"family": "scene_ops", "op": "remove", "receipt_id": "cleanup_complication", "owner_namespace": "scenario", "stable_object_id": "fixture_104"},
				{"family": "interaction_ops", "op": "remove", "receipt_id": "cleanup_interaction", "owner_namespace": "scenario", "stable_object_id": "fixture_100"},
				{"family": "actor_ops", "op": "despawn", "receipt_id": "cleanup_actor", "owner_namespace": "scenario", "stable_object_id": "fixture_105"},
				{"family": "interaction_ops", "op": "remove", "receipt_id": "cleanup_terminal_interaction", "owner_namespace": "scenario", "stable_object_id": "fixture_201"},
			]},
			"aftermath": {
				"repaired": {"label": "Repaired", "revisit_feedback": "The chair is back in place.", "scene_ops": [_operation_fixture("scene_ops", "set_state", 101)], "route_ops": [_operation_fixture("route_ops", "retarget", 101)]},
				"broken": {"label": "Broken", "revisit_feedback": "A broken chair marks the fight.", "scene_ops": [_operation_fixture("scene_ops", "set_appearance", 102)], "route_ops": [_operation_fixture("route_ops", "close", 102)]},
				"refused": {"label": "Refused", "revisit_feedback": "The staff keep their distance.", "actor_ops": [_operation_fixture("actor_ops", "set_behavior", 103)], "service_ops": [_operation_fixture("service_ops", "gate", 103)]},
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
			"fact_subscriptions": [{"fact_type": "event_result", "payload_equals": {"event_id": "fixture_event"}}, "travel_departed", "heat_changed"],
			"completion_contract": {
				"arrival_readable": true, "semantic_changes": true, "scenario_interaction": true,
				"action_boundaries": true, "choice_or_failure": true, "material_outcomes": true,
				"revisit_coverage": true, "world_connection": true, "primary_verb": true,
				"feedback_and_exit": true,
			},
		},
	}
	assert(_array(definition["sequence"]["phase_graph"]["phases"]).size() >= 3, "Sequence fixture requires arrival, complication, and aftermath phases.")
	assert(not _array(definition["sequence"]["phase_graph"]["phases"][0].get("interaction_ops", [])).is_empty(), "Sequence fixture arrival requires its authored safe-exit interaction.")
	assert(not _array(definition["sequence"]["phase_graph"]["phases"][2].get("interaction_ops", [])).is_empty(), "Sequence fixture aftermath requires its authored safe-exit interaction.")
	var complication_operation := _operation_fixture("scene_ops", "set_state", 104)
	complication_operation["owner_namespace"] = "scenario"
	complication_operation["stable_object_id"] = "fixture_100"
	complication_operation["state"] = "blocked"
	definition["sequence"]["phase_graph"]["phases"][1]["scene_ops"] = [complication_operation]
	var cleanup_operations := _array(definition["sequence"]["cleanup"].get("operations", []))
	for cleanup_index in range(cleanup_operations.size() - 1, -1, -1):
		var cleanup_operation := _dict(cleanup_operations[cleanup_index])
		if str(cleanup_operation.get("family", "")) == "scene_ops" and str(cleanup_operation.get("stable_object_id", "")) == "fixture_104":
			cleanup_operations.remove_at(cleanup_index)
	definition["sequence"]["cleanup"]["operations"] = cleanup_operations
	definition["sequence"]["phase_graph"]["phases"][0]["interaction_ops"][0]["interaction"]["safe_exit"] = true
	definition["sequence"]["phase_graph"]["phases"][2]["interaction_ops"][0]["interaction"]["safe_exit"] = true
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
	var state := {
		"scene_objects": {"scenario::fixture_1": {"owner_namespace": "scenario", "stable_object_id": "fixture_1"}},
		"interactions": {"scenario::fixture_1": _interaction_record("scenario", "fixture_1", "Existing", true)},
		"actors": {"scenario::fixture_1": {"owner_namespace": "scenario", "stable_object_id": "fixture_1"}},
		"services": {"scenario::fixture_1": {"owner_namespace": "scenario", "stable_object_id": "fixture_1"}},
		"games": {"scenario::fixture_1": {"owner_namespace": "scenario", "stable_object_id": "fixture_1"}},
		"routes": {},
		"declared_targets": declared,
		"target_inventory": declared.duplicate(true),
	}
	for index in range(2, 10): state["scene_objects"]["scenario::fixture_%d" % index] = {"owner_namespace": "scenario", "stable_object_id": "fixture_%d" % index}
	for index in range(2, 6):
		state["actors"]["scenario::fixture_%d" % index] = {"owner_namespace": "scenario", "stable_object_id": "fixture_%d" % index}
		state["interactions"]["base::fixture_target_%d" % index] = _interaction_record("base", "fixture_target_%d" % index, "Fixture target %d" % index, true)
	for index in range(2, 4):
		state["services"]["scenario::fixture_%d" % index] = {"owner_namespace": "scenario", "stable_object_id": "fixture_%d" % index, "id": "fixture_%d" % index, "label": "Fixture"}
		state["games"]["scenario::fixture_%d" % index] = {"owner_namespace": "scenario", "stable_object_id": "fixture_%d" % index, "id": "fixture_%d" % index, "label": "Fixture"}
	for index in range(4): state["routes"]["scenario::fixture_%d" % index] = {"owner_namespace": "scenario", "stable_object_id": "fixture_%d" % index, "enabled": true, "source_id": "fixture_%d" % index}
	state["routes"]["base::world:bar_route"] = {"owner_namespace": "base", "stable_object_id": "world:bar_route", "enabled": true, "source_id": "bar_route"}
	return state


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
				if index == 100: operation["interaction"]["safe_exit"] = true
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
		"alternate_exit": false,
	}


static func _priority_overlay(owner: String, mode: String, target_owner: String, target_id: String, marker: String) -> Dictionary:
	var overlay := _interaction_record(owner, "%s_%s" % [owner, mode], "%s wins %s" % [marker, mode], true)
	overlay["mode"] = mode
	overlay["target_owner_namespace"] = target_owner
	overlay["target_stable_object_id"] = target_id
	match mode:
		"gate":
			overlay["enabled"] = marker != "sweep"
			overlay["disabled_reason"] = "%s wins gate" % marker if not bool(overlay.get("enabled", true)) else ""
		"augment":
			overlay["available_actions"] = [{"id": "%s_action" % marker, "label": "%s action" % marker.capitalize(), "input_action": "confirm", "non_color_state": "ready"}]
		"retarget":
			overlay["source_id"] = "%s_source" % marker
	return overlay


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


static func _record_by_object_id(records: Array, object_id: String) -> Dictionary:
	for value in records:
		var record := _dict(value)
		if str(record.get("object_id", "")) == object_id:
			return record
	return {}


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
