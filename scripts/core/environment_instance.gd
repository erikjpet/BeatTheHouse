class_name EnvironmentInstance
extends RefCounted

const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")

# One generated location, regardless of venue type.

const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const ScenarioOperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const ScenarioSequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const CrewWorldSequenceAdapterScript := preload("res://scripts/core/crew_world_sequence_adapter.gd")
const EnvironmentSemanticInventoryScript := preload("res://scripts/core/environment_semantic_inventory.gd")
const EnvironmentEventResolverScript := preload("res://scripts/core/environment_event_resolver.gd")
const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")

const GENERATED_LAYOUT_VERSION := 13
const ENVIRONMENT_LAYER_SCHEMA_VERSION := 1
const EMPTY_MUSIC_NOTE := -999
const SALS_PAWN_COUNTER_ID := "sals_pawn_counter"
const PAWN_SHOP_ARCHETYPE_ID := "pawn_shop"

var id: String = ""
var archetype_id: String = ""
var world_node_id: String = ""
var environment_visit_id: String = ""
var night_instance_id: String = ""
var context_instance_id: String = ""
var world_map_travel: bool = false
var kind: String = ""
var display_name: String = ""
var tier: int = 1
var depth: int = 0
var art_key: String = ""
var visual_context: Dictionary = {}
var layout: Dictionary = {}
var security_profile: Dictionary = {}
var music_profile: Dictionary = {}
var economic_profile: Dictionary = {}
var objective_hint: String = ""
var demo_objective: Dictionary = {}
var game_ids: Array = []
var game_states: Dictionary = {}
var event_ids: Array = []
var item_offers: Array = []
var home_profile: Dictionary = {}
var home_containers: Array = []
var home_container_index: int = 0
var home_lost: bool = false
var parent_archetype: String = ""
var service_ids: Array = []
var lender_hooks: Array = []
var suspicion_cues: Array = []
var travel_hooks: Array = []
var next_archetypes: Array = []
var object_fixtures: Array = []
var semantic_anchors: Dictionary = {}
var semantic_zones: Dictionary = {}
var semantic_actors: Array = []
var local_narrative_flags: Dictionary = {}
var mood: String = ""
var turns: int = 0
var resolved_event_ids: Array = []
var travel_locked_actions: int = 0
var travel_lock_remaining: int = 0
var scenario_state: Dictionary = {}
var scenario_patron_ids: Array = []
var scenario_staff_ids: Array = []
var scenario_game_modifiers: Dictionary = {}
var scenario_presentation: Dictionary = {}
var scenario_exclusive_opportunity: Dictionary = {}
var scenario_hook_flags: Dictionary = {}
var scenario_semantic_inventory_version: int = 0
var scenario_semantic_digest: String = ""
var scenario_sequence_state: Dictionary = {}
var scenario_sequence_migration_error: String = ""
var scenario_sequence_projection: Dictionary = {}
var scenario_render_snapshot: Dictionary = {}
var scenario_sequence_migration: Dictionary = {}
var scenario_sequence_base_game_ids: Array = []
var scenario_sequence_base_service_ids: Array = []
var scenario_sequence_base_travel_hooks: Array = []
var scenario_sequence_base_game_modifiers: Dictionary = {}
var scenario_event_choices: Dictionary = {}
var world_sequence_instances: Dictionary = {}
var environment_layer_schema_version: int = 0
var current_layer_id: String = ""
var default_layer_id: String = ""
var layer_ids: Array = []
var layer_display_name: String = ""
var layer_transitions: Array = []
var layer_discovery: Dictionary = {}
var layer_states: Dictionary = {}
var layer_ambient_lines: Array = []
var layer_ambient_label: String = ""
var layer_ambient_prop: String = ""
var layer_ambient_rotate_actions: int = 1
var layer_ambient_index: int = 0
var layer_ambient_line: String = ""


# Builds one environment from an archetype and content library.
static func from_archetype(archetype: Dictionary, p_depth: int, rng: RngStream, library: ContentLibrary = null, challenge_config: Dictionary = {}, selected_scenario: Dictionary = {}) -> EnvironmentInstance:
	if _is_layered_archetype(archetype):
		return _from_layered_archetype(archetype, p_depth, rng, library, challenge_config, selected_scenario)
	if library != null:
		archetype = library.environment_archetype_for_challenge(archetype, challenge_config)
	# Sequence definitions also publish their own schema_version. Runtime scenario
	# state is identified by its progress fields; treating every versioned
	# definition as state discards its legacy mutations before room generation.
	var selected_is_state := selected_scenario.has("phase_index") or selected_scenario.has("phase_action_counter")
	var selected_state := ScenarioEngineScript.normalize_state(selected_scenario) if selected_is_state else ScenarioEngineScript.initial_state(selected_scenario)
	if not selected_state.is_empty():
		archetype = ScenarioEngineScript.apply_to_archetype(archetype, selected_state)
	var environment := EnvironmentInstance.new()
	environment.depth = p_depth
	environment.tier = int(archetype.get("tier", 1))
	environment.kind = archetype.get("kind", "unknown")
	environment.archetype_id = archetype.get("id", "unknown")
	# Legacy travel still needs a stable physical-node identity. World-map
	# generation replaces this with the concrete node id before installation.
	environment.world_node_id = environment.archetype_id
	environment.id = "%s_%03d" % [environment.archetype_id, p_depth + 1]
	environment.display_name = _build_name(archetype, rng)
	environment.art_key = _art_key(archetype)
	environment.visual_context = _simulation_visual_context(archetype, environment.art_key)
	environment.layout = _generated_layout_variant(archetype, rng.fork("layout:%s" % environment.id))
	environment.security_profile = JsonCoerceScript._copy_dict(archetype.get("security_profile", {}))
	environment.music_profile = _generated_music_profile(archetype, environment, rng)
	environment.economic_profile = JsonCoerceScript._copy_dict(archetype.get("economic_profile", {}))
	environment.objective_hint = str(archetype.get("objective_hint", ""))
	environment.demo_objective = JsonCoerceScript._copy_dict(archetype.get("demo_objective", {}))
	var game_pool := _filtered_game_pool(archetype, library, challenge_config)
	var required_games := _filtered_required_games(archetype, game_pool)
	environment.game_ids = _pick_ids_with_required(game_pool, archetype.get("game_count", 1), required_games, rng)
	environment.game_states = {}
	environment.event_ids = _pick_events(archetype, rng.fork("events:%s" % environment.id), library)
	if not selected_state.is_empty() and ScenarioEngineScript.SequenceSchemaScript.is_sequence(selected_scenario):
		environment.scenario_event_choices = EnvironmentSemanticInventoryScript.event_choice_index(environment.event_ids, library)
	environment.item_offers = _build_offers(archetype, rng, library, challenge_config)
	for scenario_offer_value in JsonCoerceScript._copy_array(archetype.get("scenario_item_offers", [])):
		if typeof(scenario_offer_value) != TYPE_DICTIONARY:
			continue
		var scenario_offer := (scenario_offer_value as Dictionary).duplicate(true)
		var scenario_item_id := str(scenario_offer.get("id", "")).strip_edges()
		if scenario_item_id.is_empty():
			continue
		for offer_index in range(environment.item_offers.size() - 1, -1, -1):
			if typeof(environment.item_offers[offer_index]) == TYPE_DICTIONARY and str((environment.item_offers[offer_index] as Dictionary).get("id", "")) == scenario_item_id:
				environment.item_offers.remove_at(offer_index)
		environment.item_offers.append(scenario_offer)
	environment.home_profile = JsonCoerceScript._copy_dict(archetype.get("home_profile", {}))
	environment.home_containers = []
	environment.parent_archetype = str(archetype.get("parent_archetype", ""))
	environment.service_ids = JsonCoerceScript._copy_array(archetype.get("service_pool", []))
	environment.lender_hooks = _pick_lenders(archetype, rng.fork("lenders:%s" % environment.id))
	var base_placement_hints := _base_placement_hints(environment.to_dict(), library)
	if not base_placement_hints.is_empty():
		environment.layout["object_placement_hints"] = base_placement_hints
	environment.suspicion_cues = JsonCoerceScript._copy_array(archetype.get("suspicion_cues", environment.security_profile.get("visible_cues", [])))
	environment.travel_hooks = JsonCoerceScript._copy_array(archetype.get("travel_hooks", []))
	environment.next_archetypes = JsonCoerceScript._copy_array(archetype.get("next_archetypes", []))
	environment.object_fixtures = JsonCoerceScript._copy_array(archetype.get("object_fixtures", []))
	# Semantic zones are authored base-room authority. Keep them on every room so
	# a world sequence mounted after generation can prove its physical zone.
	environment.semantic_zones = JsonCoerceScript._copy_dict(archetype.get("semantic_zones", {}))
	# Expanded anchors and actors belong to an installed room sequence. Keep
	# legacy no-sequence room snapshots compact unless that catalog is active.
	if not selected_state.is_empty():
		environment.semantic_anchors = JsonCoerceScript._copy_dict(archetype.get("semantic_anchors", {}))
		environment.semantic_actors = JsonCoerceScript._copy_array(archetype.get("semantic_actors", []))
	var rare_route_rng := rng.fork("rare_next:%s" % environment.id)
	_append_rare_archetypes(environment.next_archetypes, archetype, rare_route_rng)
	environment.local_narrative_flags = JsonCoerceScript._copy_dict(archetype.get("local_narrative_flags", {}))
	environment.mood = rng.pick(archetype.get("moods", ["watchful"]), "watchful")
	environment.travel_locked_actions = maxi(0, int(archetype.get("travel_locked_actions", 0)))
	environment.travel_lock_remaining = environment.travel_locked_actions
	environment.scenario_patron_ids = JsonCoerceScript._copy_array(archetype.get("scenario_patron_ids", []))
	environment.scenario_staff_ids = JsonCoerceScript._copy_array(archetype.get("scenario_staff_ids", []))
	environment.scenario_game_modifiers = JsonCoerceScript._copy_dict(archetype.get("scenario_game_modifiers", {}))
	environment.scenario_presentation = JsonCoerceScript._copy_dict(archetype.get("scenario_presentation", {}))
	environment.scenario_exclusive_opportunity = JsonCoerceScript._copy_dict(archetype.get("scenario_exclusive_opportunity", {}))
	environment.scenario_hook_flags = JsonCoerceScript._copy_dict(archetype.get("scenario_hook_flags", {}))
	if not selected_state.is_empty():
		environment.scenario_state = selected_state
		var scenario_environment := environment.to_dict()
		# Layer metadata is finalized by _apply_layer_metadata after flat generation,
		# but scenario attachment must know the physical floor before it decides
		# whether to install room-local mutations and sequence visuals.
		if archetype.has("current_layer_id"):
			scenario_environment["current_layer_id"] = str(archetype.get("current_layer_id", "")).strip_edges()
		ScenarioEngineScript.attach_to_environment(scenario_environment, selected_state, selected_scenario)
		environment = from_dict(scenario_environment)
	environment.layout = ensure_generated_layout(environment.to_dict())
	return environment


# Generates the exact fields shown by a travel scout while preserving the RNG
# sequence used by full room generation. Presentation layout, events, semantic
# inventories, and machine state are intentionally outside this projection.
static func travel_preview_from_archetype(archetype: Dictionary, p_depth: int, rng: RngStream, library: ContentLibrary = null, challenge_config: Dictionary = {}, selected_scenario: Dictionary = {}) -> Dictionary:
	if _is_layered_archetype(archetype):
		var layers := JsonCoerceScript._copy_dict(archetype.get("layers", {}))
		var layer_ids := JsonCoerceScript._string_array(layers.keys())
		if layer_ids.is_empty():
			return {}
		var configured_default := str(archetype.get("default_layer_id", layer_ids[0])).strip_edges()
		var modifiers := JsonCoerceScript._copy_dict(challenge_config.get("modifiers", {}))
		var overrides := JsonCoerceScript._copy_dict(modifiers.get("environment_layer_overrides", {}))
		var default_id := str(overrides.get(str(archetype.get("id", "")), configured_default)).strip_edges()
		if not layer_ids.has(default_id):
			default_id = configured_default if layer_ids.has(configured_default) else str(layer_ids[0])
		var primary_id := str(archetype.get("compatibility_primary_layer_id", default_id)).strip_edges()
		if not layer_ids.has(primary_id):
			primary_id = default_id
		# Full generation forks every non-primary floor before generating the
		# primary one. A scout only renders the configured active floor, so select
		# that same stream without materializing the other layer states.
		var layer_rng := rng if default_id == primary_id else rng.fork("environment_layer:%s:%s" % [str(archetype.get("id", "")), default_id])
		return travel_preview_from_archetype(_archetype_for_layer(archetype, default_id), p_depth, layer_rng, library, challenge_config, selected_scenario)
	if library != null:
		archetype = library.environment_archetype_for_challenge(archetype, challenge_config)
	var selected_is_state := selected_scenario.has("phase_index") or selected_scenario.has("phase_action_counter")
	var selected_state := ScenarioEngineScript.normalize_state(selected_scenario) if selected_is_state else ScenarioEngineScript.initial_state(selected_scenario)
	if not selected_state.is_empty():
		archetype = ScenarioEngineScript.apply_to_archetype(archetype, selected_state)
	var environment := EnvironmentInstance.new()
	environment.depth = p_depth
	environment.tier = int(archetype.get("tier", 1))
	environment.kind = str(archetype.get("kind", "unknown"))
	environment.archetype_id = str(archetype.get("id", "unknown"))
	environment.id = "%s_%03d" % [environment.archetype_id, p_depth + 1]
	# Name and generated music precede games/offers on the authoritative stream.
	# Compute them even though the route card does not render either value.
	_build_name(archetype, rng)
	_generated_music_profile(archetype, environment, rng)
	var game_pool := _filtered_game_pool(archetype, library, challenge_config)
	var required_games := _filtered_required_games(archetype, game_pool)
	var game_ids := _pick_ids_with_required(game_pool, archetype.get("game_count", 1), required_games, rng)
	# attach_to_environment materializes a scenario's exclusive game after base
	# selection. Mirror that one player-visible delta without constructing the
	# complete semantic environment.
	var exclusive_opportunity := JsonCoerceScript._copy_dict(archetype.get("scenario_exclusive_opportunity", {}))
	var exclusive_game_id := str(exclusive_opportunity.get("game_id", "")).strip_edges()
	if not exclusive_game_id.is_empty() and not game_ids.has(exclusive_game_id):
		game_ids.append(exclusive_game_id)
	var item_offers := _build_offers(archetype, rng, library, challenge_config)
	for scenario_offer_value in JsonCoerceScript._copy_array(archetype.get("scenario_item_offers", [])):
		if typeof(scenario_offer_value) != TYPE_DICTIONARY:
			continue
		var scenario_offer := (scenario_offer_value as Dictionary).duplicate(true)
		var scenario_item_id := str(scenario_offer.get("id", "")).strip_edges()
		if scenario_item_id.is_empty():
			continue
		for offer_index in range(item_offers.size() - 1, -1, -1):
			if typeof(item_offers[offer_index]) == TYPE_DICTIONARY and str((item_offers[offer_index] as Dictionary).get("id", "")) == scenario_item_id:
				item_offers.remove_at(offer_index)
		item_offers.append(scenario_offer)
	return {
		"tier": environment.tier,
		"kind": environment.kind,
		"game_ids": game_ids,
		"service_ids": JsonCoerceScript._copy_array(archetype.get("service_pool", [])),
		"lender_hooks": _pick_lenders(archetype, rng.fork("lenders:%s" % environment.id)),
		"item_offers": item_offers,
		"travel_locked_actions": maxi(0, int(archetype.get("travel_locked_actions", 0))),
	}


# Restores a generated environment from saveable data.
static func from_dict(data: Dictionary) -> EnvironmentInstance:
	var environment := EnvironmentInstance.new()
	environment.id = str(data.get("id", ""))
	environment.archetype_id = str(data.get("archetype_id", ""))
	environment.world_node_id = str(data.get("world_node_id", environment.archetype_id)).strip_edges()
	environment.environment_visit_id = str(data.get("environment_visit_id", "")).strip_edges()
	environment.night_instance_id = str(data.get("night_instance_id", "")).strip_edges()
	environment.context_instance_id = str(data.get("context_instance_id", "")).strip_edges()
	environment.world_map_travel = bool(data.get("world_map_travel", false))
	environment.kind = str(data.get("kind", ""))
	environment.display_name = str(data.get("display_name", ""))
	environment.tier = int(data.get("tier", 1))
	environment.depth = int(data.get("depth", 0))
	environment.art_key = str(data.get("art_key", JsonCoerceScript._copy_dict(data.get("visual_context", {})).get("art_key", "")))
	environment.visual_context = _strip_presentation_paths(JsonCoerceScript._copy_dict(data.get("visual_context", {})), environment.art_key)
	environment.layout = ensure_generated_layout(data)
	environment.security_profile = JsonCoerceScript._copy_dict(data.get("security_profile", {}))
	environment.music_profile = JsonCoerceScript._copy_dict(data.get("music_profile", {}))
	environment.economic_profile = JsonCoerceScript._copy_dict(data.get("economic_profile", {}))
	environment.objective_hint = str(data.get("objective_hint", ""))
	environment.demo_objective = JsonCoerceScript._copy_dict(data.get("demo_objective", {}))
	environment.game_ids = JsonCoerceScript._copy_array(data.get("game_ids", []))
	environment.game_states = JsonCoerceScript._copy_dict(data.get("game_states", {}))
	environment.event_ids = JsonCoerceScript._copy_array(data.get("event_ids", []))
	environment.item_offers = JsonCoerceScript._copy_array(data.get("item_offers", []))
	environment.home_profile = JsonCoerceScript._copy_dict(data.get("home_profile", {}))
	environment.home_containers = JsonCoerceScript._copy_array(data.get("home_containers", []))
	environment.home_container_index = maxi(0, int(data.get("home_container_index", 0)))
	environment.home_lost = bool(data.get("home_lost", false))
	environment.parent_archetype = str(data.get("parent_archetype", ""))
	environment.service_ids = JsonCoerceScript._copy_array(data.get("service_ids", []))
	environment.lender_hooks = JsonCoerceScript._copy_array(data.get("lender_hooks", []))
	environment.suspicion_cues = JsonCoerceScript._copy_array(data.get("suspicion_cues", []))
	environment.travel_hooks = JsonCoerceScript._copy_array(data.get("travel_hooks", []))
	environment.next_archetypes = JsonCoerceScript._copy_array(data.get("next_archetypes", []))
	environment.object_fixtures = JsonCoerceScript._copy_array(data.get("object_fixtures", []))
	environment.semantic_anchors = JsonCoerceScript._copy_dict(data.get("semantic_anchors", {}))
	environment.semantic_zones = JsonCoerceScript._copy_dict(data.get("semantic_zones", {}))
	environment.semantic_actors = JsonCoerceScript._copy_array(data.get("semantic_actors", []))
	environment.local_narrative_flags = JsonCoerceScript._copy_dict(data.get("local_narrative_flags", {}))
	environment.mood = str(data.get("mood", ""))
	environment.turns = int(data.get("turns", 0))
	environment.resolved_event_ids = JsonCoerceScript._copy_array(data.get("resolved_event_ids", []))
	environment.travel_locked_actions = maxi(0, int(data.get("travel_locked_actions", 0)))
	environment.travel_lock_remaining = maxi(0, int(data.get("travel_lock_remaining", environment.travel_locked_actions)))
	environment.scenario_state = ScenarioEngineScript.normalize_state(data.get("scenario_state", {}))
	environment.scenario_patron_ids = JsonCoerceScript._copy_array(data.get("scenario_patron_ids", []))
	environment.scenario_staff_ids = JsonCoerceScript._copy_array(data.get("scenario_staff_ids", []))
	environment.scenario_game_modifiers = JsonCoerceScript._copy_dict(data.get("scenario_game_modifiers", {}))
	environment.scenario_presentation = JsonCoerceScript._copy_dict(data.get("scenario_presentation", {}))
	environment.scenario_exclusive_opportunity = JsonCoerceScript._copy_dict(data.get("scenario_exclusive_opportunity", {}))
	environment.scenario_hook_flags = JsonCoerceScript._copy_dict(data.get("scenario_hook_flags", {}))
	var semantic_inventory_version := maxi(0, int(data.get("scenario_semantic_inventory_version", 0)))
	var semantic_digest := str(data.get("scenario_semantic_digest", "")).strip_edges()
	if semantic_inventory_version > 0 and not semantic_digest.is_empty():
		environment.scenario_semantic_inventory_version = semantic_inventory_version
		environment.scenario_semantic_digest = semantic_digest
	var raw_sequence_state: Variant = data.get("scenario_sequence_state", {})
	environment.scenario_sequence_state = _durable_sequence_state(raw_sequence_state)
	environment.scenario_sequence_migration_error = str(data.get("scenario_sequence_migration_error", ""))
	if data.has("scenario_sequence_state") and _persisted_sequence_state_requires_migration(raw_sequence_state, environment.scenario_sequence_state):
		environment.scenario_sequence_migration_error = "Persisted dynamic room sequence state is malformed, unsupported, or overbound; explicit migration is required."
	environment.scenario_sequence_projection = {}
	environment.scenario_render_snapshot = {}
	environment.scenario_sequence_migration = JsonCoerceScript._copy_dict(data.get("scenario_sequence_migration", {}))
	environment.scenario_sequence_base_game_ids = JsonCoerceScript._copy_array(data.get("scenario_sequence_base_game_ids", []))
	environment.scenario_sequence_base_service_ids = JsonCoerceScript._copy_array(data.get("scenario_sequence_base_service_ids", []))
	environment.scenario_sequence_base_travel_hooks = JsonCoerceScript._copy_array(data.get("scenario_sequence_base_travel_hooks", []))
	environment.scenario_sequence_base_game_modifiers = JsonCoerceScript._copy_dict(data.get("scenario_sequence_base_game_modifiers", {}))
	environment.scenario_event_choices = {}
	environment.world_sequence_instances = CrewWorldSequenceAdapterScript.durable_container(data.get(CrewWorldSequenceAdapterScript.CONTAINER_KEY, {}))
	environment.environment_layer_schema_version = maxi(0, int(data.get("environment_layer_schema_version", 0)))
	environment.current_layer_id = str(data.get("current_layer_id", "")).strip_edges()
	environment.default_layer_id = str(data.get("default_layer_id", "")).strip_edges()
	environment.layer_ids = JsonCoerceScript._string_array(data.get("layer_ids", []))
	environment.layer_display_name = str(data.get("layer_display_name", "")).strip_edges()
	environment.layer_transitions = JsonCoerceScript._copy_array(data.get("layer_transitions", []))
	environment.layer_discovery = JsonCoerceScript._copy_dict(data.get("layer_discovery", {}))
	environment.layer_states = _durable_layer_states(data.get("layer_states", {}))
	environment.layer_ambient_lines = JsonCoerceScript._string_array(data.get("layer_ambient_lines", []))
	environment.layer_ambient_label = str(data.get("layer_ambient_label", "")).strip_edges()
	environment.layer_ambient_prop = str(data.get("layer_ambient_prop", "")).strip_edges()
	environment.layer_ambient_rotate_actions = maxi(1, int(data.get("layer_ambient_rotate_actions", 1)))
	environment.layer_ambient_index = maxi(0, int(data.get("layer_ambient_index", 0)))
	environment.layer_ambient_line = str(data.get("layer_ambient_line", "")).strip_edges()
	return environment


# Converts the environment to saveable data.
func to_dict() -> Dictionary:
	var result := {
		"id": id,
		"archetype_id": archetype_id,
		"world_node_id": world_node_id,
		"world_map_travel": world_map_travel,
		"kind": kind,
		"display_name": display_name,
		"tier": tier,
		"depth": depth,
		"art_key": art_key,
		"visual_context": visual_context.duplicate(true),
		"layout": layout.duplicate(true),
		"security_profile": security_profile.duplicate(true),
		"music_profile": music_profile.duplicate(true),
		"economic_profile": economic_profile.duplicate(true),
		"objective_hint": objective_hint,
		"demo_objective": demo_objective.duplicate(true),
		"game_ids": game_ids.duplicate(true),
		"game_states": game_states.duplicate(true),
		"event_ids": event_ids.duplicate(true),
		"item_offers": item_offers.duplicate(true),
		"home_profile": home_profile.duplicate(true),
		"home_containers": home_containers.duplicate(true),
		"home_container_index": home_container_index,
		"home_lost": home_lost,
		"parent_archetype": parent_archetype,
		"service_ids": service_ids.duplicate(true),
		"lender_hooks": lender_hooks.duplicate(true),
		"suspicion_cues": suspicion_cues.duplicate(true),
		"travel_hooks": travel_hooks.duplicate(true),
		"next_archetypes": next_archetypes.duplicate(true),
		"object_fixtures": object_fixtures.duplicate(true),
		"local_narrative_flags": local_narrative_flags.duplicate(true),
		"mood": mood,
		"turns": turns,
		"resolved_event_ids": resolved_event_ids.duplicate(true),
		"travel_locked_actions": travel_locked_actions,
		"travel_lock_remaining": travel_lock_remaining,
	}
	if not scenario_state.is_empty():
		result["scenario_state"] = scenario_state.duplicate(true)
		result["scenario_id"] = str(scenario_state.get("id", ""))
		result["scenario_phase_index"] = int(scenario_state.get("phase_index", 0))
		result["scenario_phase_action_counter"] = int(scenario_state.get("phase_action_counter", 0))
		result["scenario_patron_ids"] = scenario_patron_ids.duplicate(true)
		result["scenario_staff_ids"] = scenario_staff_ids.duplicate(true)
		result["scenario_game_modifiers"] = scenario_game_modifiers.duplicate(true)
		result["scenario_presentation"] = scenario_presentation.duplicate(true)
		result["scenario_exclusive_opportunity"] = scenario_exclusive_opportunity.duplicate(true)
		result["scenario_hook_flags"] = scenario_hook_flags.duplicate(true)
	var sequence_migration_error := scenario_sequence_migration_error
	if not scenario_sequence_state.is_empty():
		var durable_sequence_state := _durable_sequence_state(scenario_sequence_state)
		if _persisted_sequence_state_requires_migration(scenario_sequence_state, durable_sequence_state):
			sequence_migration_error = "Persisted dynamic room sequence state is malformed, unsupported, or overbound; explicit migration is required."
		else:
			result["scenario_sequence_state"] = durable_sequence_state
		result["scenario_sequence_base_game_ids"] = scenario_sequence_base_game_ids.duplicate(true)
		result["scenario_sequence_base_service_ids"] = scenario_sequence_base_service_ids.duplicate(true)
		result["scenario_sequence_base_travel_hooks"] = scenario_sequence_base_travel_hooks.duplicate(true)
		result["scenario_sequence_base_game_modifiers"] = scenario_sequence_base_game_modifiers.duplicate(true)
	if not scenario_sequence_migration.is_empty():
		result["scenario_sequence_migration"] = scenario_sequence_migration.duplicate(true)
	if not sequence_migration_error.is_empty(): result["scenario_sequence_migration_error"] = sequence_migration_error
	if not world_sequence_instances.is_empty():
		result[CrewWorldSequenceAdapterScript.CONTAINER_KEY] = CrewWorldSequenceAdapterScript.durable_container(world_sequence_instances)
	if scenario_semantic_inventory_version > 0 and not scenario_semantic_digest.strip_edges().is_empty():
		result["scenario_semantic_inventory_version"] = scenario_semantic_inventory_version
		result["scenario_semantic_digest"] = scenario_semantic_digest.strip_edges()
	if not semantic_anchors.is_empty(): result["semantic_anchors"] = semantic_anchors.duplicate(true)
	if not semantic_zones.is_empty(): result["semantic_zones"] = semantic_zones.duplicate(true)
	if not semantic_actors.is_empty(): result["semantic_actors"] = semantic_actors.duplicate(true)
	if not environment_visit_id.is_empty() or not night_instance_id.is_empty() or not context_instance_id.is_empty():
		result["environment_visit_id"] = environment_visit_id
		result["night_instance_id"] = night_instance_id
		result["context_instance_id"] = context_instance_id
	if environment_layer_schema_version > 0 and not current_layer_id.is_empty():
		result["environment_layer_schema_version"] = environment_layer_schema_version
		result["current_layer_id"] = current_layer_id
		result["default_layer_id"] = default_layer_id
		result["layer_ids"] = layer_ids.duplicate(true)
		result["layer_display_name"] = layer_display_name
		result["layer_transitions"] = layer_transitions.duplicate(true)
		result["layer_discovery"] = layer_discovery.duplicate(true)
		result["layer_states"] = _durable_layer_states(layer_states)
		result["layer_ambient_lines"] = layer_ambient_lines.duplicate(true)
		result["layer_ambient_label"] = layer_ambient_label
		result["layer_ambient_prop"] = layer_ambient_prop
		result["layer_ambient_rotate_actions"] = layer_ambient_rotate_actions
		result["layer_ambient_index"] = layer_ambient_index
		result["layer_ambient_line"] = layer_ambient_line
	return result


static func _durable_sequence_state(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY: return {}
	if (value as Dictionary).is_empty(): return {}
	if not ScenarioOperationRegistryScript.validate_bounded_variant("persisted environment scenario sequence state", value).is_empty(): return {}
	if not ScenarioSequenceRuntimeScript._persisted_collections_within_limits(value as Dictionary): return {}
	var state := (value as Dictionary).duplicate(true)
	var semantic := JsonCoerceScript._copy_dict(state.get("semantic_state", {}))
	for key in ["target_inventory", "declared_targets", "base_interactions", "event_choices", "scene_objects", "interactions", "actors", "services", "games", "routes", "transition_queue", "tombstones"]: semantic.erase(key)
	state["semantic_state"] = semantic
	state.erase("resolved_branches")
	state.erase("resolved_outcomes")
	return state


static func _persisted_sequence_state_requires_migration(raw_value: Variant, durable_state: Dictionary) -> bool:
	if typeof(raw_value) != TYPE_DICTIONARY or durable_state.is_empty(): return true
	var raw := raw_value as Dictionary
	return typeof(raw.get("schema_version")) != TYPE_INT \
		or int(raw.get("schema_version", 0)) != ScenarioSequenceRuntimeScript.STATE_SCHEMA_VERSION \
		or typeof(raw.get("scenario_id")) != TYPE_STRING \
		or str(raw.get("scenario_id", "")).strip_edges().is_empty()


static func _durable_layer_states(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	for layer_id_value in JsonCoerceScript._copy_dict(value).keys():
		var body := JsonCoerceScript._copy_dict(JsonCoerceScript._copy_dict(value).get(layer_id_value, {})).duplicate(true)
		# Base/live producer context belongs to the ephemeral proof. The separately
		# named sealed context is durable rebuild authority and remains in layer state.
		for key in ["scenario_semantic_ready", "scenario_semantic_inventory", "scenario_semantic_action_digest", "scenario_base_interactions", "scenario_base_actors", "scenario_base_producer_context", "scenario_event_choices", "scenario_sequence_projection", "scenario_sequence_lifecycle_errors", "scenario_live_producer_projection"]: body.erase(key)
		if body.has(CrewWorldSequenceAdapterScript.CONTAINER_KEY):
			var world_instances := CrewWorldSequenceAdapterScript.durable_container(body.get(CrewWorldSequenceAdapterScript.CONTAINER_KEY, {}))
			if world_instances.is_empty(): body.erase(CrewWorldSequenceAdapterScript.CONTAINER_KEY)
			else: body[CrewWorldSequenceAdapterScript.CONTAINER_KEY] = world_instances
		if body.has("scenario_sequence_state"):
			var raw_sequence_state: Variant = body.get("scenario_sequence_state", {})
			var durable := _durable_sequence_state(raw_sequence_state)
			if _persisted_sequence_state_requires_migration(raw_sequence_state, durable):
				body.erase("scenario_sequence_state")
				body["scenario_sequence_migration_error"] = "Persisted dynamic room sequence state is malformed, unsupported, or overbound; explicit migration is required."
			else: body["scenario_sequence_state"] = durable
		body.erase("layer_states")
		result[str(layer_id_value)] = body
	return result


# Generates every layer from independent deterministic data while exposing the
# active layer through the unchanged flat environment contract.
static func _from_layered_archetype(archetype: Dictionary, p_depth: int, rng: RngStream, library: ContentLibrary, challenge_config: Dictionary, selected_scenario: Dictionary) -> EnvironmentInstance:
	var layers := JsonCoerceScript._copy_dict(archetype.get("layers", {}))
	var ids := JsonCoerceScript._string_array(layers.keys())
	if ids.is_empty():
		return EnvironmentInstance.new()
	var configured_default := str(archetype.get("default_layer_id", ids[0])).strip_edges()
	var modifiers := JsonCoerceScript._copy_dict(challenge_config.get("modifiers", {}))
	var overrides := JsonCoerceScript._copy_dict(modifiers.get("environment_layer_overrides", {}))
	var default_id := str(overrides.get(str(archetype.get("id", "")), configured_default)).strip_edges()
	if not ids.has(default_id):
		default_id = configured_default if ids.has(configured_default) else str(ids[0])
	var discovery := JsonCoerceScript._copy_dict(archetype.get("layer_discovery_defaults", {}))
	discovery[default_id] = true
	var generated_states: Dictionary = {}
	var primary_layer_id := str(archetype.get("compatibility_primary_layer_id", default_id)).strip_edges()
	if not ids.has(primary_layer_id):
		primary_layer_id = default_id
	var forked_rngs: Dictionary = {}
	for layer_id_value in ids:
		var layer_id := str(layer_id_value)
		if layer_id != primary_layer_id:
			forked_rngs[layer_id] = rng.fork("environment_layer:%s:%s" % [str(archetype.get("id", "")), layer_id])
	var generation_order: Array = [primary_layer_id]
	for layer_id_value in ids:
		if str(layer_id_value) != primary_layer_id:
			generation_order.append(str(layer_id_value))
	for layer_id_value in generation_order:
		var layer_id := str(layer_id_value)
		var layer_rng: RngStream = rng if layer_id == primary_layer_id else forked_rngs.get(layer_id) as RngStream
		var flat := _archetype_for_layer(archetype, layer_id)
		var layer_environment := from_archetype(flat, p_depth, layer_rng, library, challenge_config, selected_scenario)
		var layer_data := layer_environment.to_dict()
		_apply_layer_metadata(layer_data, archetype, layer_id, ids, discovery)
		generated_states[layer_id] = _layer_state_body(layer_data)
	var active_data := JsonCoerceScript._copy_dict(generated_states.get(default_id, {}))
	_apply_layer_metadata(active_data, archetype, default_id, ids, discovery)
	active_data["layer_states"] = generated_states
	active_data["display_name"] = str(archetype.get("display_name", "The Punchline"))
	return from_dict(active_data)


# Generates one missing layer for schema migration without rebuilding the node.
static func from_archetype_layer(archetype: Dictionary, layer_id: String, p_depth: int, rng: RngStream, library: ContentLibrary = null, challenge_config: Dictionary = {}, selected_scenario: Dictionary = {}) -> EnvironmentInstance:
	if not _is_layered_archetype(archetype):
		return from_archetype(archetype, p_depth, rng, library, challenge_config, selected_scenario)
	var layers := JsonCoerceScript._copy_dict(archetype.get("layers", {}))
	var ids := JsonCoerceScript._string_array(layers.keys())
	var clean_layer_id := layer_id.strip_edges()
	if not ids.has(clean_layer_id):
		return EnvironmentInstance.new()
	var flat := _archetype_for_layer(archetype, clean_layer_id)
	var environment := from_archetype(flat, p_depth, rng, library, challenge_config, selected_scenario)
	var data := environment.to_dict()
	var discovery := JsonCoerceScript._copy_dict(archetype.get("layer_discovery_defaults", {}))
	_apply_layer_metadata(data, archetype, clean_layer_id, ids, discovery)
	return from_dict(data)


static func _archetype_for_layer(archetype: Dictionary, layer_id: String) -> Dictionary:
	var result := archetype.duplicate(true)
	var layers := JsonCoerceScript._copy_dict(result.get("layers", {}))
	var overlay := JsonCoerceScript._copy_dict(layers.get(layer_id, {}))
	for key_value in ["layers", "default_layer_id", "layer_discovery_defaults", "compatibility_primary_layer_id", "environment_layer_schema_version"]:
		result.erase(key_value)
	result = _deep_merge(result, overlay)
	result["current_layer_id"] = layer_id
	return result


static func _apply_layer_metadata(target: Dictionary, archetype: Dictionary, layer_id: String, ids: Array, discovery: Dictionary) -> void:
	var layers := JsonCoerceScript._copy_dict(archetype.get("layers", {}))
	var layer := JsonCoerceScript._copy_dict(layers.get(layer_id, {}))
	target["display_name"] = str(archetype.get("display_name", target.get("display_name", "")))
	target["environment_layer_schema_version"] = ENVIRONMENT_LAYER_SCHEMA_VERSION
	target["current_layer_id"] = layer_id
	target["default_layer_id"] = str(archetype.get("default_layer_id", ids[0] if not ids.is_empty() else layer_id))
	target["layer_ids"] = ids.duplicate(true)
	target["layer_display_name"] = str(layer.get("layer_display_name", layer_id.replace("_", " ").capitalize()))
	target["layer_transitions"] = JsonCoerceScript._copy_array(layer.get("layer_transitions", []))
	target["layer_discovery"] = discovery.duplicate(true)
	target["layer_ambient_lines"] = JsonCoerceScript._string_array(layer.get("ambient_lines", []))
	target["layer_ambient_label"] = str(layer.get("ambient_label", "")).strip_edges()
	target["layer_ambient_prop"] = str(layer.get("ambient_prop", "")).strip_edges()
	target["layer_ambient_rotate_actions"] = maxi(1, int(layer.get("ambient_rotate_actions", 1)))
	target["layer_ambient_index"] = 0
	var ambient_lines := JsonCoerceScript._string_array(target.get("layer_ambient_lines", []))
	target["layer_ambient_line"] = str(ambient_lines[0]) if not ambient_lines.is_empty() else ""


static func _layer_state_body(environment: Dictionary) -> Dictionary:
	var result := environment.duplicate(true)
	result.erase("layer_states")
	return result


static func _is_layered_archetype(archetype: Dictionary) -> bool:
	return not JsonCoerceScript._copy_dict(archetype.get("layers", {})).is_empty()


# Ensures a generated environment owns stable object placement keyed by object id.
static func ensure_generated_layout(environment_data: Dictionary, library: ContentLibrary = null) -> Dictionary:
	var layout := JsonCoerceScript._copy_dict(environment_data.get("layout", {}))
	if library != null:
		var refreshed_hints := _base_placement_hints(environment_data, library)
		if not refreshed_hints.is_empty():
			layout["object_placement_hints"] = refreshed_hints
	# Town/scenario modifiers can add catalog objects after the EnvironmentInstance
	# was first built. Classify those late additions from the refreshed hints above,
	# rather than the stale hints still held by the serialized input dictionary.
	var placement_environment := environment_data.duplicate(true)
	placement_environment["layout"] = layout
	var active_entries := _active_object_layout_entries(placement_environment)
	var grounding_signature := _grounding_signature(environment_data, layout, active_entries)
	var current_slot_map_digest := EnvironmentSlotBinderScript.slot_map_digest(
		EnvironmentPlacementScript.surface_map(placement_environment)
	)
	var persisted_slot_authority := EnvironmentSlotBinderScript.validate_base_layout_authority(placement_environment)
	if int(layout.get("generated_object_rect_version", 0)) == GENERATED_LAYOUT_VERSION \
			and str(layout.get("grounding_signature", "")) == grounding_signature \
			and int(layout.get("slot_schema_version", 0)) == EnvironmentSlotBinderScript.SLOT_SCHEMA_VERSION \
			and str(layout.get("slot_map_digest", "")) == current_slot_map_digest \
			and bool(persisted_slot_authority.get("ok", false)):
		return layout
	var binding_result := EnvironmentSlotBinderScript.bind_base_layout(placement_environment, active_entries)
	layout["object_rects"] = JsonCoerceScript._copy_dict(binding_result.get("object_rects", {}))
	layout["slot_bindings"] = JsonCoerceScript._copy_dict(binding_result.get("slot_bindings", {}))
	layout["slot_overflow_ids"] = JsonCoerceScript._copy_array(binding_result.get("overflow_ids", []))
	layout["slot_schema_version"] = int(binding_result.get("slot_schema_version", 0))
	layout["slot_map_digest"] = str(binding_result.get("slot_map_digest", ""))
	layout["slot_binding_digest"] = str(binding_result.get("binding_digest", ""))
	# Legacy recovery diagnostics are removed deliberately. Overflow is a normal,
	# first-class presentation mode and is never an emergency placement fallback.
	layout.erase("placement_classes")
	layout.erase("placement_surfaces")
	layout.erase("placement_errors")
	layout.erase("placement_fallback_ids")
	layout["generated_object_rect_version"] = GENERATED_LAYOUT_VERSION
	layout["grounding_signature"] = grounding_signature
	return layout


static func _grounding_signature(environment_data: Dictionary, layout: Dictionary, active_entries: Array) -> String:
	var layout_source := layout.duplicate(true)
	for generated_key in ["object_rects", "slot_bindings", "slot_overflow_ids", "slot_schema_version", "slot_map_digest", "slot_binding_digest", "placement_classes", "placement_surfaces", "placement_errors", "placement_fallback_ids", "grounding_signature", "generated_object_rect_version"]:
		layout_source.erase(generated_key)
	var signature_source := {
		"version": GENERATED_LAYOUT_VERSION,
		"placement_authority_version": 3,
		"archetype_id": str(environment_data.get("archetype_id", environment_data.get("id", ""))),
		"layer_id": str(environment_data.get("current_layer_id", environment_data.get("layer_id", ""))),
		"surface_map": EnvironmentPlacementScript.surface_map(environment_data),
		"active_entries": active_entries,
		"layout_source": layout_source,
	}
	return JSON.stringify(signature_source).sha256_text()


static func _build_name(archetype: Dictionary, rng: RngStream) -> String:
	var prefixes: Array = archetype.get("name_prefixes", ["Unnamed"])
	var nouns: Array = archetype.get("name_nouns", ["Room"])
	return "%s %s" % [rng.pick(prefixes, "Unnamed"), rng.pick(nouns, "Room")]


# Adds rare route hooks with deterministic per-instance odds.
static func _append_rare_archetypes(target: Array, archetype: Dictionary, rng: RngStream) -> void:
	var rare_ids := JsonCoerceScript._string_array(archetype.get("rare_next_archetypes", []))
	if rare_ids.is_empty():
		return
	var chance := clampi(int(archetype.get("rare_next_chance_percent", 8)), 0, 100)
	if chance <= 0 or rng.randi_range(1, 100) > chance:
		return
	for archetype_id in rare_ids:
		if not target.has(archetype_id):
			target.append(archetype_id)


# Generates one saved composition profile for venues that request unique music.
static func _generated_music_profile(archetype: Dictionary, environment: EnvironmentInstance, rng: RngStream) -> Dictionary:
	var profile := JsonCoerceScript._copy_dict(archetype.get("music_profile", {}))
	if str(profile.get("procedural_variant", "")) != "jazz_club":
		return profile
	var progression_options := [
		[0, 3, 4, 5],
		[0, 5, 3, 4],
		[0, 2, 5, 4],
		[0, 6, 3, 5],
	]
	var mode_options := ["dorian", "minor", "harmonic_minor"]
	var texture_options := ["jazz", "funk_jazz"]
	var root_options := [41, 43, 46, 48, 50]
	var title_prefixes := ["Blue", "Velvet", "After Hours", "Fifth Street", "Midnight"]
	var title_nouns := ["Turnaround", "Pocket", "Standard", "Break", "Cadence"]
	var progression_value: Variant = rng.pick(progression_options, [0, 3, 4, 5])
	var progression: Array = [0, 3, 4, 5]
	if typeof(progression_value) == TYPE_ARRAY:
		progression = (progression_value as Array).duplicate(true)
	var motif := _generated_jazz_motif(rng)
	profile["theme"] = "classical jazz club"
	profile["texture"] = str(rng.pick(texture_options, "jazz"))
	profile["mode"] = str(rng.pick(mode_options, "dorian"))
	profile["bpm"] = rng.randi_range(88, 116)
	profile["root_midi"] = int(rng.pick(root_options, 46))
	profile["progression"] = progression.duplicate(true)
	profile["motif"] = motif
	profile["arrangement_phrases"] = rng.randi_range(4, 6)
	profile["generated_title"] = "%s %s" % [str(rng.pick(title_prefixes, "Blue")), str(rng.pick(title_nouns, "Standard"))]
	profile["generated_signature"] = "%s:%s:%d:%s:%s" % [
		str(environment.id),
		str(profile.get("mode", "")),
		int(profile.get("root_midi", 0)),
		JSON.stringify(profile.get("progression", [])),
		JSON.stringify(profile.get("motif", [])),
	]
	return profile


static func _generated_jazz_motif(rng: RngStream) -> Array:
	var degrees := [0, 1, 2, 3, 4, 5, 6, 7]
	var motif: Array = []
	for index in range(16):
		if index % 4 == 3 and rng.randi_range(1, 100) <= 72:
			motif.append(EMPTY_MUSIC_NOTE)
		elif index % 2 == 1 and rng.randi_range(1, 100) <= 42:
			motif.append(EMPTY_MUSIC_NOTE)
		else:
			motif.append(int(rng.pick(degrees, 0)))
	return motif


# Returns the presentation manifest key for this environment.
static func _art_key(archetype: Dictionary) -> String:
	var visual := JsonCoerceScript._copy_dict(archetype.get("visual_context", {}))
	var key := str(archetype.get("art_key", visual.get("art_key", "")))
	if not key.is_empty():
		return key
	return str(archetype.get("id", "unknown"))


# Keeps first-person visual identity in simulation without concrete asset paths.
static func _simulation_visual_context(archetype: Dictionary, p_art_key: String) -> Dictionary:
	return _strip_presentation_paths(JsonCoerceScript._copy_dict(archetype.get("visual_context", {})), p_art_key)


# Builds the per-instance room layout variant without randomizing spatial data.
static func _generated_layout_variant(archetype: Dictionary, _rng: RngStream) -> Dictionary:
	# Spatial composition is authored data. Run RNG may select content, but may
	# never permute the slots to which that content binds.
	return JsonCoerceScript._copy_dict(archetype.get("layout", {}))


# Removes presentation-only paths from generated environment state.
static func _strip_presentation_paths(visual: Dictionary, p_art_key: String) -> Dictionary:
	visual.erase("asset_path")
	visual.erase("scene_asset_path")
	visual["art_key"] = p_art_key
	return visual


# Builds priced item offers from the archetype item pool.
static func _build_offers(archetype: Dictionary, rng: RngStream, library: ContentLibrary, challenge_config: Dictionary = {}) -> Array:
	if library == null:
		return []
	var offers: Array = []
	var economic_profile := JsonCoerceScript._copy_dict(archetype.get("economic_profile", {}))
	var price_multiplier := 1.0
	if economic_profile.has("shop_price_multiplier"):
		price_multiplier = clampf(float(economic_profile.get("shop_price_multiplier", 1.0)), 0.5, 1.5)
	var sale_price_multiplier := maxf(0.0, float(economic_profile.get("shop_sale_price_multiplier", 0.0)))
	var item_pool := library.shop_item_pool_for_challenge(archetype.get("item_pool", []), challenge_config)
	var item_ids := _pick_ids(item_pool, archetype.get("item_count", 0), rng)
	for item_id in item_ids:
		var item := library.item(item_id)
		if item.is_empty():
			continue
		var min_price := int(item.get("price_min", 1))
		var max_price := int(item.get("price_max", min_price))
		var price := rng.randi_range(min_price, max_price)
		if not is_equal_approx(price_multiplier, 1.0):
			price = maxi(1, int(floor(float(price) * price_multiplier)))
		if sale_price_multiplier > 0.0:
			var sale_price := _item_sale_price(item)
			price = maxi(1, int(ceil(float(sale_price) * sale_price_multiplier)))
		offers.append({
			"id": item_id,
			"display_name": item.get("display_name", item_id),
			"price": price,
			"price_min": min_price,
			"price_max": max_price,
		})
	return offers


static func _item_sale_price(item: Dictionary) -> int:
	if item.has("sale_price"):
		return maxi(0, int(item.get("sale_price", 0)))
	var price_min := int(item.get("price_min", 0))
	var price_max := int(item.get("price_max", price_min))
	return maxi(0, int(round(float(price_min + price_max) * 0.25)))


static func _filtered_game_pool(archetype: Dictionary, library: ContentLibrary, challenge_config: Dictionary = {}) -> Array:
	var pool := JsonCoerceScript._copy_array(archetype.get("game_pool", []))
	if library == null:
		return JsonCoerceScript._string_array(pool)
	return library.filter_game_ids_for_challenge(pool, challenge_config)


static func _filtered_required_games(archetype: Dictionary, filtered_pool: Array) -> Array:
	var required: Array = []
	for required_id in JsonCoerceScript._string_array(archetype.get("required_game_ids", [])):
		if filtered_pool.has(required_id):
			required.append(required_id)
	return required


# Picks a per-instance subset of lender hooks when the archetype declares a count.
static func _pick_lenders(archetype: Dictionary, rng: RngStream) -> Array:
	var pool := JsonCoerceScript._string_array(archetype.get("lender_hooks", []))
	var archetype_id := str(archetype.get("id", "")).strip_edges()
	if archetype_id != PAWN_SHOP_ARCHETYPE_ID:
		pool.erase(SALS_PAWN_COUNTER_ID)
	if pool.is_empty():
		return []
	if not archetype.has("lender_count"):
		return rng.shuffled(pool)
	var required_lenders := JsonCoerceScript._string_array(archetype.get("required_lender_hooks", []))
	if archetype_id != PAWN_SHOP_ARCHETYPE_ID:
		required_lenders.erase(SALS_PAWN_COUNTER_ID)
	var selected := _pick_ids_with_required(pool, archetype.get("lender_count", pool.size()), required_lenders, rng)
	return rng.shuffled(selected)


# Picks event ids that match the environment scopes.
static func _pick_events(archetype: Dictionary, rng: RngStream, library: ContentLibrary) -> Array:
	var definitions: Array = [] if library == null else library.events
	return EnvironmentEventResolverScript.select_ids(archetype, definitions, rng)


static func _base_placement_hints(environment_data: Dictionary, library: ContentLibrary) -> Dictionary:
	var result := _event_placement_hints(
		JsonCoerceScript._copy_array(environment_data.get("event_ids", [])),
		library,
		environment_data
	)
	if library == null:
		return result
	for service_id in JsonCoerceScript._string_array(environment_data.get("service_ids", [])):
		var definition := library.service(service_id)
		if definition.is_empty():
			continue
		result["service:%s" % service_id] = {
			"visual_type": "drink" if str(definition.get("category", "")) == "alcohol" else "service",
			"visual_prop": str(definition.get("environment_prop", "")),
			"asset_path": str(definition.get("asset_path", "")),
		}
	for lender_id in JsonCoerceScript._string_array(environment_data.get("lender_hooks", [])):
		var definition := library.lender(lender_id)
		if definition.is_empty():
			continue
		var speaker := JsonCoerceScript._copy_dict(definition.get("speaker", {}))
		var physical_person := str(definition.get("lender_type", "")) != "family_phone" \
				and not speaker.is_empty() and bool(speaker.get("environment_actor", true))
		var hint := {
			"visual_type": "character" if physical_person else "lender",
			"asset_path": str(definition.get("asset_path", "")),
			"physical_person": physical_person,
		}
		result["lender:%s" % lender_id] = hint
	return result


static func _event_placement_hints(event_ids: Array, library: ContentLibrary, environment_data: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	if library == null:
		return result
	var surfaces := EnvironmentPlacementScript.surface_map(environment_data)
	var has_counters := not JsonCoerceScript._copy_array(surfaces.get("counters", [])).is_empty()
	var has_seats := not JsonCoerceScript._copy_array(surfaces.get("seats", [])).is_empty()
	for event_id in JsonCoerceScript._string_array(event_ids):
		var definition := library.event(event_id)
		if definition.is_empty():
			continue
		var speaker := JsonCoerceScript._copy_dict(definition.get("speaker", {}))
		var visual_prop := str(definition.get("environment_prop", ""))
		var speaker_role := str(speaker.get("role", ""))
		var hint := {
			"visual_prop": visual_prop,
			"icon_key": str(definition.get("icon_key", "")),
			"asset_path": str(definition.get("asset_path", "")),
			"physical_person": not speaker.is_empty() and bool(speaker.get("environment_actor", true)),
			"role": speaker_role,
		}
		var counter_staff: bool = visual_prop in ["clerk_counter", "host_station"] \
				or event_id == "town_rumor_staff" and str(environment_data.get("archetype_id", "")) == "bar"
		if has_counters and counter_staff and speaker_role in ["staff", "clerk", "cashier", "dealer", "vendor"]:
			hint["placement_class"] = "behind_counter_person"
		elif has_seats and str(environment_data.get("archetype_id", "")) == "bar" \
				and visual_prop in ["bar_patron", "patron", "patron_talk", "rowdy_patron"]:
			hint["placement_class"] = "seated_person"
		elif not str(speaker.get("character_id", "")).strip_edges().is_empty():
			hint["placement_class"] = "standing_person"
		result["event:%s" % event_id] = hint
	return result


# Picks a fixed or ranged number of unique ids from a pool.
static func _pick_ids(pool: Array, requested_count: Variant, rng: RngStream) -> Array:
	var count := _count(requested_count, rng)
	return rng.pick_many(pool, max(0, count))


# Picks unique ids while preserving explicit must-spawn ids.
static func _pick_ids_with_required(pool: Array, requested_count: Variant, required_ids: Variant, rng: RngStream) -> Array:
	var normalized_pool := JsonCoerceScript._string_array(pool)
	var required: Array = []
	for required_id in JsonCoerceScript._string_array(required_ids):
		if normalized_pool.has(required_id) and not required.has(required_id):
			required.append(required_id)
	var count := maxi(_count(requested_count, rng), required.size())
	var remaining_pool: Array = []
	for pool_id in normalized_pool:
		if not required.has(pool_id):
			remaining_pool.append(pool_id)
	var picks := rng.pick_many(remaining_pool, maxi(0, count - required.size()))
	var selected := {}
	for required_id in required:
		selected[required_id] = true
	for pick_value in picks:
		var pick_id := str(pick_value)
		if not pick_id.is_empty():
			selected[pick_id] = true
	var result: Array = []
	for pool_id in normalized_pool:
		if bool(selected.get(pool_id, false)):
			result.append(pool_id)
	return result


# Resolves a fixed count or random count range.
static func _count(requested_count: Variant, rng: RngStream) -> int:
	if typeof(requested_count) == TYPE_ARRAY:
		var range_values: Array = requested_count
		if range_values.size() >= 2:
			return rng.randi_range(int(range_values[0]), int(range_values[1]))
	return int(requested_count)


# Assigns stable rects to simple string-id object families.
static func _game_layout_entries(environment_data: Dictionary) -> Array:
	var entries: Array = []
	var layout := JsonCoerceScript._copy_dict(environment_data.get("layout", {}))
	var fixture_counts := JsonCoerceScript._copy_dict(layout.get("game_fixture_counts", {}))
	var layout_index := 0
	for game_id in JsonCoerceScript._string_array(environment_data.get("game_ids", [])):
		var fixture_count := maxi(1, int(fixture_counts.get(game_id, 1)))
		for fixture_index in range(fixture_count):
			entries.append({
				"object_id": "game:%s" % game_id if fixture_index == 0 else "game:%s:%d" % [game_id, fixture_index + 1],
				"object_type": "game",
				"index": layout_index,
				"spot_field": "game_spots",
			})
			layout_index += 1
	return entries


static func _layout_spot_count(layout: Dictionary, spot_field: String) -> int:
	if spot_field.is_empty():
		return 0
	var spots: Variant = layout.get(spot_field, [])
	if typeof(spots) != TYPE_ARRAY:
		return 0
	return (spots as Array).size()


static func _active_object_layout_entries(environment_data: Dictionary) -> Array:
	var entries: Array = []
	entries.append_array(_game_layout_entries(environment_data))
	_append_string_layout_entries(entries, "event", JsonCoerceScript._copy_array(environment_data.get("event_ids", [])), "event_spots")
	entries.append_array(_environment_layer_layout_entries(environment_data))
	var layout := JsonCoerceScript._copy_dict(environment_data.get("layout", {}))
	var prioritize_services := bool(layout.get("prioritize_service_spots", false))
	if not prioritize_services:
		_append_item_offer_layout_entries(entries, JsonCoerceScript._copy_array(environment_data.get("item_offers", [])))
	entries.append_array(_cage_gift_layout_entries(environment_data))
	if _shopkeeper_should_exist(environment_data):
		entries.append({"object_id": "shopkeeper:merchant", "object_type": "shopkeeper", "index": 0, "spot_field": "shopkeeper_spots"})
	if not _travel_target_ids(environment_data).is_empty():
		entries.append({"object_id": "travel:leave", "object_type": "travel", "index": 0, "spot_field": "travel_spots"})
	_append_string_layout_entries(entries, "travel", _grand_casino_local_target_ids(environment_data), "casino_door_spots")
	_append_string_layout_entries(entries, "casino_fixture", _casino_fixture_ids(environment_data), "casino_fixture_spots")
	_append_string_layout_entries(entries, "service", JsonCoerceScript._copy_array(environment_data.get("service_ids", [])), "service_spots")
	_append_string_layout_entries(entries, "lender", JsonCoerceScript._copy_array(environment_data.get("lender_hooks", [])), "lender_spots")
	entries.append_array(_game_hook_layout_entries(environment_data))
	entries.append_array(_numbers_layout_entries(environment_data))
	if _home_tenure_should_exist(environment_data):
		entries.append({"object_id": "home_tenure:status", "object_type": "home_tenure", "index": 0, "spot_field": "home_tenure_spots"})
	if _home_sleep_should_exist(environment_data):
		entries.append({"object_id": "home_sleep:bed", "object_type": "home_sleep", "index": 0, "spot_field": "home_sleep_spots"})
	if _home_storage_should_exist(environment_data):
		entries.append({"object_id": "home_storage:place", "object_type": "home_storage", "index": 0, "spot_field": "home_storage_spots"})
	_append_string_layout_entries(entries, "home_container", _home_container_ids(environment_data), "home_container_spots")
	if prioritize_services:
		_append_item_offer_layout_entries(entries, JsonCoerceScript._copy_array(environment_data.get("item_offers", [])))
	var filtered := _filter_unique_object_layout_entries(entries)
	var placement_hints := JsonCoerceScript._copy_dict(JsonCoerceScript._copy_dict(environment_data.get("layout", {})).get("object_placement_hints", {}))
	var class_overrides := JsonCoerceScript._copy_dict(EnvironmentPlacementScript.surface_map(environment_data).get("class_overrides", {}))
	for entry_value in filtered:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var hint := JsonCoerceScript._copy_dict(placement_hints.get(str(entry.get("object_id", "")), {}))
		for key in hint.keys():
			entry[key] = hint[key]
		var object_id := str(entry.get("object_id", ""))
		var class_override := str(class_overrides.get(object_id, ""))
		if class_override in EnvironmentPlacementScript.CLASSES:
			entry["placement_class"] = class_override
	return filtered


static func _environment_layer_layout_entries(environment_data: Dictionary) -> Array:
	var entries: Array = []
	var index := 0
	if not str(environment_data.get("layer_ambient_line", "")).strip_edges().is_empty():
		entries.append({"object_id": "environment_layer:ambient", "object_type": "environment_layer", "index": index, "spot_field": "layer_spots"})
		index += 1
	for transition_value in JsonCoerceScript._copy_array(environment_data.get("layer_transitions", [])):
		if typeof(transition_value) != TYPE_DICTIONARY:
			continue
		var target_id := str((transition_value as Dictionary).get("target_layer_id", "")).strip_edges()
		if target_id.is_empty():
			continue
		entries.append({"object_id": "environment_layer:%s" % target_id, "object_type": "environment_layer", "index": index, "spot_field": "layer_spots"})
		index += 1
	return entries


# Numbers identities are runtime-backed, so keep them in the same generated
# authority as the rest of the room. The book remains geometry-free until it
# owns concrete art; the exact Silas identity may reserve a person slot.
static func _numbers_layout_entries(environment_data: Dictionary) -> Array:
	var layout := JsonCoerceScript._copy_dict(environment_data.get("layout", {}))
	var numbers_count := _layout_spot_count(layout, "numbers_spots")
	var silas_count := _layout_spot_count(layout, "numbers_silas_spots")
	if numbers_count <= 0 and silas_count <= 0:
		return []
	# The Crew back-room desk is already the authored event:numbers_desk fixture.
	# All other Numbers venues expose the shared book plus an optional Silas spot.
	if str(environment_data.get("archetype_id", "")) == "small_underground_casino" \
			and str(environment_data.get("current_layer_id", "")) == "back_room":
		return []
	var entries: Array = []
	if numbers_count > 0:
		entries.append({
			"object_id": "numbers:book",
			"object_type": "numbers",
			"index": 0,
			"spot_field": "numbers_spots",
		})
	# Silas can rotate into any active Numbers venue. Reserve his physical rect
	# even while he is absent so the interaction layer never invents a second,
	# ungrounded fallback position when town state brings him in later.
	if silas_count > 0:
		entries.append({
			"object_id": "numbers:silas",
			"object_type": "numbers_silas",
			"index": 0,
			"spot_field": "numbers_silas_spots",
		})
	return entries


static func _append_string_layout_entries(entries: Array, object_type: String, ids: Array, spot_field: String) -> void:
	var stable_ids := JsonCoerceScript._string_array(ids)
	for index in range(stable_ids.size()):
		entries.append({
			"object_id": "%s:%s" % [object_type, stable_ids[index]],
			"object_type": object_type,
			"index": index,
			"spot_field": spot_field,
		})


static func _append_item_offer_layout_entries(entries: Array, offers: Array) -> void:
	var item_ids: Array = []
	for offer in offers:
		if typeof(offer) != TYPE_DICTIONARY:
			continue
		var item_id := str((offer as Dictionary).get("id", ""))
		if not item_id.is_empty() and not item_ids.has(item_id):
			item_ids.append(item_id)
	for index in range(item_ids.size()):
		entries.append({
			"object_id": "item:%s" % item_ids[index],
			"object_type": "item",
			"index": index,
			"spot_field": "item_spots",
		})


static func _cage_gift_layout_entries(environment_data: Dictionary) -> Array:
	var result: Array = []
	var shop_state := JsonCoerceScript._copy_dict(environment_data.get("cage_gift_shop_state", {}))
	var stock := JsonCoerceScript._copy_array(shop_state.get("stock", []))
	for stock_index in range(stock.size()):
		if typeof(stock[stock_index]) != TYPE_DICTIONARY or bool((stock[stock_index] as Dictionary).get("sold", false)):
			continue
		result.append({
			"object_id": "cage_gift_item:%d" % stock_index,
			"object_type": "item",
			"index": stock_index,
			"spot_field": "item_spots",
		})
	return result


# Returns unique route target ids in the same order the UI exposes them.
static func _travel_target_ids(environment_data: Dictionary) -> Array:
	var result: Array = []
	for source in [
		environment_data.get("next_archetypes", []),
		environment_data.get("travel_hooks", []),
	]:
		for target_id in JsonCoerceScript._string_array(source):
			if not result.has(target_id):
				result.append(target_id)
	return result


static func _casino_fixture_ids(environment_data: Dictionary) -> Array:
	if not _is_grand_casino_archetype(environment_data):
		return []
	var flags: Dictionary = environment_data.get("local_narrative_flags", {}) if typeof(environment_data.get("local_narrative_flags", {})) == TYPE_DICTIONARY else {}
	var result: Array = []
	for fixture_value in flags.get("casino_fixtures", []):
		if typeof(fixture_value) != TYPE_DICTIONARY:
			continue
		var fixture_id := str((fixture_value as Dictionary).get("id", "")).strip_edges()
		if not fixture_id.is_empty() and not result.has(fixture_id):
			result.append(fixture_id)
	return result


static func _grand_casino_local_target_ids(environment_data: Dictionary) -> Array:
	if not _is_grand_casino_archetype(environment_data):
		return []
	var flags: Dictionary = environment_data.get("local_narrative_flags", {}) if typeof(environment_data.get("local_narrative_flags", {})) == TYPE_DICTIONARY else {}
	return JsonCoerceScript._string_array(flags.get("casino_room_targets", []))


static func _is_grand_casino_archetype(environment_data: Dictionary) -> bool:
	var archetype_id := str(environment_data.get("archetype_id", environment_data.get("id", ""))).strip_edges()
	return archetype_id == "grand_casino" or archetype_id == "grand_casino_high_limit" or archetype_id == "grand_casino_back_room" or archetype_id == "grand_casino_cage"


static func _game_hook_layout_entries(environment_data: Dictionary) -> Array:
	var result: Array = []
	var game_states := JsonCoerceScript._copy_dict(environment_data.get("game_states", {}))
	for game_id in JsonCoerceScript._string_array(environment_data.get("game_ids", [])):
		var machine: Variant = game_states.get(game_id, {})
		if typeof(machine) != TYPE_DICTIONARY:
			continue
		for hook in JsonCoerceScript._copy_array((machine as Dictionary).get("environment_hooks", [])):
			if typeof(hook) != TYPE_DICTIONARY:
				continue
			var hook_data: Dictionary = hook
			var hook_id := str(hook_data.get("id", ""))
			if hook_id.is_empty():
				continue
			# Scratch Tickets and Pull Tabs expose two action providers for the
			# same in-room Lottery Clerk. Normalize them before the unique-object
			# filter so the late hook consumes one authored person slot. The
			# scalper is a separate person and exists only while its state says so.
			var unique_object_class := str(hook_data.get("unique_object_class", "")).strip_edges()
			var physical_person := false
			if unique_object_class in ["scratch_ticket_clerk", "pull_tab_clerk", "lottery_redemption_clerk"]:
				unique_object_class = "lottery_redemption_clerk"
				physical_person = true
			elif hook_id == "scratch_ticket_scalper":
				if not bool((machine as Dictionary).get("scalper_present", false)):
					continue
				physical_person = true
			var object_id := str(hook_data.get("object_id", "")).strip_edges()
			if object_id.is_empty():
				var dialogue_id := str(hook_data.get("dialogue_id", "")).strip_edges()
				object_id = "dialogue:%s" % dialogue_id if not dialogue_id.is_empty() else "game_hook:%s:%s" % [game_id, hook_id]
			result.append({
				"object_id": object_id,
				"object_type": "game_hook",
				"index": result.size(),
				"spot_field": "game_hook_spots",
				"unique_object_class": unique_object_class,
				"unique_object_priority": 120 if hook_id == "scratch_ticket_clerk" else int(hook_data.get("unique_object_priority", 0)),
				"allow_duplicate_unique_class": bool(hook_data.get("allow_duplicate_unique_class", false)),
				"physical_person": physical_person,
			})
	return result


static func _filter_unique_object_layout_entries(entries: Array) -> Array:
	var result: Array = []
	var class_indexes: Dictionary = {}
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = (entry_value as Dictionary).duplicate(true)
		var unique_class := str(entry.get("unique_object_class", "")).strip_edges()
		if unique_class.is_empty() or bool(entry.get("allow_duplicate_unique_class", false)):
			result.append(entry)
			continue
		if not class_indexes.has(unique_class):
			class_indexes[unique_class] = result.size()
			result.append(entry)
			continue
		var existing_index := int(class_indexes[unique_class])
		var existing: Dictionary = result[existing_index]
		if int(entry.get("unique_object_priority", 0)) > int(existing.get("unique_object_priority", 0)):
			result[existing_index] = entry
	return result


static func _home_container_ids(environment_data: Dictionary) -> Array:
	var result: Array = []
	for container_value in JsonCoerceScript._copy_array(environment_data.get("home_containers", [])):
		if typeof(container_value) != TYPE_DICTIONARY:
			continue
		var container: Dictionary = container_value
		var container_id := str(container.get("id", "")).strip_edges()
		if not container_id.is_empty() and not result.has(container_id):
			result.append(container_id)
	return result


static func _home_tenure_should_exist(environment_data: Dictionary) -> bool:
	return str(environment_data.get("kind", "")) == "home" and not bool(environment_data.get("home_lost", false))


static func _home_sleep_should_exist(environment_data: Dictionary) -> bool:
	return str(environment_data.get("kind", "")) == "home" and not bool(environment_data.get("home_lost", false))


static func _home_storage_should_exist(environment_data: Dictionary) -> bool:
	return str(environment_data.get("kind", "")) == "home" and not bool(environment_data.get("home_lost", false))


# Returns whether this environment should expose a merchant prop.
static func _shopkeeper_should_exist(environment_data: Dictionary) -> bool:
	if _object_fixture_declared(environment_data, "shopkeeper:merchant"):
		return true
	if not JsonCoerceScript._copy_array(environment_data.get("item_offers", [])).is_empty():
		return true
	return str(environment_data.get("kind", "")) == "shop"


static func _object_fixture_declared(environment_data: Dictionary, object_id: String) -> bool:
	if object_id.is_empty():
		return false
	for fixture_id in JsonCoerceScript._string_array(environment_data.get("object_fixtures", [])):
		if fixture_id == object_id:
			return true
	return false


static func _deep_merge(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key_value in overlay.keys():
		var value: Variant = overlay.get(key_value)
		if typeof(value) == TYPE_DICTIONARY and typeof(result.get(key_value)) == TYPE_DICTIONARY:
			result[key_value] = _deep_merge(result.get(key_value, {}) as Dictionary, value as Dictionary)
		elif typeof(value) == TYPE_DICTIONARY:
			result[key_value] = (value as Dictionary).duplicate(true)
		elif typeof(value) == TYPE_ARRAY:
			result[key_value] = (value as Array).duplicate(true)
		else:
			result[key_value] = value
	return result


# Safely duplicates array content.
# Safely converts an array-like value to non-empty strings.
# Safely duplicates dictionary content.
