class_name EnvironmentInstance
extends RefCounted

const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")

# One generated location, regardless of venue type.

const ArtContractsScript := preload("res://scripts/core/art_contracts.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const ScenarioOperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const ScenarioSequenceRuntimeScript := preload("res://scripts/core/scenario_sequence_runtime.gd")
const CrewWorldSequenceAdapterScript := preload("res://scripts/core/crew_world_sequence_adapter.gd")
const EnvironmentSemanticInventoryScript := preload("res://scripts/core/environment_semantic_inventory.gd")
const EnvironmentEventResolverScript := preload("res://scripts/core/environment_event_resolver.gd")
const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")

const ENVIRONMENT_BOARD_SIZE := Vector2(ArtContractsScript.ENVIRONMENT_BOARD_SIZE)
const GENERATED_LAYOUT_VERSION := 16
const ENVIRONMENT_LAYER_SCHEMA_VERSION := 1
const EMPTY_MUSIC_NOTE := -999
const BASE_REPACK_CANDIDATE_TIER_PREFERRED := 0
const BASE_REPACK_CANDIDATE_TIER_SUPPORTED := 1
const BASE_REPACK_CANDIDATE_TIER_FINE := 2
const BASE_REPACK_FAST_SEARCH_NODE_LIMIT := 256
const BASE_REPACK_CLIQUE_WORD_BITS := 62
const BASE_REPACK_CLIQUE_MEMO_LIMIT := 65536
const BASE_REPACK_CLIQUE_COLOR_BOUND_VERTEX_LIMIT := 512
const BASE_REPACK_CLIQUE_ROOT_ARC_VERTEX_LIMIT := 512
const BASE_REPACK_CLIQUE_ROOT_EXACT_VERTEX_THRESHOLD := 256
const BASE_REPACK_CLIQUE_EXPENSIVE_REDUCTION_VERTEX_THRESHOLD := 256
const BASE_REPACK_CLIQUE_WITNESS_NODE_LIMIT := 8192
const BASE_PLACEMENT_SCARCITY_RANK := {
	"behind_counter_person": 0,
	"seated_person": 1,
	"hanging": 2,
	"wall_mounted": 3,
	"surface_item": 4,
	"standing_person": 5,
	"group": 6,
	"ground_marker": 7,
	"floor_fixture": 8,
}
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


# Builds one environment from an archetype and content library. Flat production
# generation may defer grounding until all late controls have been assembled.
static func from_archetype(archetype: Dictionary, p_depth: int, rng: RngStream, library: ContentLibrary = null, challenge_config: Dictionary = {}, selected_scenario: Dictionary = {}, defer_flat_generated_layout: bool = false) -> EnvironmentInstance:
	if _is_layered_archetype(archetype):
		# Layer bodies are persisted independently, and restore does not ground
		# inactive bodies. Keep every layered archetype eager and save-ready.
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
	var event_placement_hints := _event_placement_hints(environment.event_ids, library, environment.to_dict())
	if not event_placement_hints.is_empty():
		environment.layout["object_placement_hints"] = event_placement_hints
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
	environment.suspicion_cues = JsonCoerceScript._copy_array(archetype.get("suspicion_cues", environment.security_profile.get("visible_cues", [])))
	environment.travel_hooks = JsonCoerceScript._copy_array(archetype.get("travel_hooks", []))
	environment.next_archetypes = JsonCoerceScript._copy_array(archetype.get("next_archetypes", []))
	environment.object_fixtures = JsonCoerceScript._copy_array(archetype.get("object_fixtures", []))
	# The expanded semantic catalog belongs to an installed dynamic sequence.
	# Keep legacy no-sequence room snapshots compact and byte-compatible.
	if not selected_state.is_empty():
		environment.semantic_anchors = JsonCoerceScript._copy_dict(archetype.get("semantic_anchors", {}))
		environment.semantic_zones = JsonCoerceScript._copy_dict(archetype.get("semantic_zones", {}))
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
		# Scenario attachment completes the data shape before layout ownership is
		# decided below. Hydrate raw here so eager construction also has exactly one
		# final grounding boundary instead of an eager pass plus a cached duplicate.
		environment = _hydrate_from_dict(scenario_environment, true)
	if not defer_flat_generated_layout:
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
	return _hydrate_from_dict(data, false)


# Construction-only hydration seam. Restore/install callers always use the
# eager public from_dict() contract so an ungrounded save can never escape.
static func _hydrate_from_dict(data: Dictionary, defer_generated_layout: bool) -> EnvironmentInstance:
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
	environment.layout = JsonCoerceScript._copy_dict(data.get("layout", {})) if defer_generated_layout else ensure_generated_layout(data)
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
		var refreshed_hints := _event_placement_hints(JsonCoerceScript._copy_array(environment_data.get("event_ids", [])), library, environment_data)
		if not refreshed_hints.is_empty():
			layout["object_placement_hints"] = refreshed_hints
	var object_rects := JsonCoerceScript._copy_dict(layout.get("object_rects", {}))
	if int(layout.get("generated_object_rect_version", 0)) != GENERATED_LAYOUT_VERSION:
		object_rects = {}
	# Town/scenario modifiers can add events after the EnvironmentInstance was
	# first built. Classify those late additions from the refreshed hints above,
	# rather than the stale hints still held by the serialized input dictionary.
	var placement_environment := environment_data.duplicate(true)
	placement_environment["layout"] = layout
	var active_entries := _active_object_layout_entries(placement_environment)
	var active_object_ids := _active_object_ids_from_entries(active_entries)
	var grounding_signature := _grounding_signature(environment_data, layout, active_entries)
	if int(layout.get("generated_object_rect_version", 0)) == GENERATED_LAYOUT_VERSION \
			and str(layout.get("grounding_signature", "")) == grounding_signature \
			and JsonCoerceScript._copy_array(layout.get("placement_errors", [])).is_empty() \
			and JsonCoerceScript._copy_array(layout.get("placement_fallback_ids", [])).is_empty():
		return layout
	var prioritize_services := bool(layout.get("prioritize_service_spots", false))
	_prune_inactive_object_rects(object_rects, active_object_ids)
	_assign_object_layout_entries(object_rects, layout, _game_layout_entries(environment_data), active_object_ids)
	_assign_string_object_rects(object_rects, layout, "event", JsonCoerceScript._copy_array(environment_data.get("event_ids", [])), "event_spots", active_object_ids)
	_assign_object_layout_entries(object_rects, layout, _environment_layer_layout_entries(environment_data), active_object_ids)
	if not prioritize_services:
		_assign_item_offer_rects(object_rects, layout, JsonCoerceScript._copy_array(environment_data.get("item_offers", [])), active_object_ids)
	_assign_object_layout_entries(object_rects, layout, _cage_gift_layout_entries(environment_data), active_object_ids)
	_assign_single_object_rect(object_rects, layout, "shopkeeper:merchant", "shopkeeper", 0, "shopkeeper_spots", _shopkeeper_should_exist(environment_data), active_object_ids)
	_assign_single_object_rect(object_rects, layout, "travel:leave", "travel", 0, "travel_spots", not _travel_target_ids(environment_data).is_empty(), active_object_ids)
	_assign_string_object_rects(object_rects, layout, "travel", _grand_casino_local_target_ids(environment_data), "casino_door_spots", active_object_ids)
	_assign_string_object_rects(object_rects, layout, "casino_fixture", _casino_fixture_ids(environment_data), "casino_fixture_spots", active_object_ids)
	_assign_string_object_rects(object_rects, layout, "service", JsonCoerceScript._copy_array(environment_data.get("service_ids", [])), "service_spots", active_object_ids)
	_assign_string_object_rects(object_rects, layout, "lender", JsonCoerceScript._copy_array(environment_data.get("lender_hooks", [])), "lender_spots", active_object_ids)
	_assign_object_layout_entries(object_rects, layout, _filter_unique_object_layout_entries(_game_hook_layout_entries(environment_data)), active_object_ids)
	_assign_object_layout_entries(object_rects, layout, _numbers_layout_entries(environment_data), active_object_ids)
	_assign_single_object_rect(object_rects, layout, "home_tenure:status", "home_tenure", 0, "home_tenure_spots", _home_tenure_should_exist(environment_data), active_object_ids)
	_assign_single_object_rect(object_rects, layout, "home_sleep:bed", "home_sleep", 0, "home_sleep_spots", _home_sleep_should_exist(environment_data), active_object_ids)
	_assign_single_object_rect(object_rects, layout, "home_storage:place", "home_storage", 0, "home_storage_spots", _home_storage_should_exist(environment_data), active_object_ids)
	_assign_string_object_rects(object_rects, layout, "home_container", _home_container_ids(environment_data), "home_container_spots", active_object_ids)
	if prioritize_services:
		_assign_item_offer_rects(object_rects, layout, JsonCoerceScript._copy_array(environment_data.get("item_offers", [])), active_object_ids)
	_ground_authored_object_rects(object_rects, layout, environment_data, active_entries)
	layout["object_rects"] = object_rects
	layout["generated_object_rect_version"] = GENERATED_LAYOUT_VERSION
	layout["grounding_signature"] = grounding_signature
	return layout


static func _grounding_signature(environment_data: Dictionary, layout: Dictionary, active_entries: Array) -> String:
	var layout_source := layout.duplicate(true)
	for generated_key in ["object_rects", "placement_classes", "placement_surfaces", "placement_errors", "placement_fallback_ids", "placement_adjusted_ids", "grounding_signature", "generated_object_rect_version"]:
		layout_source.erase(generated_key)
	var signature_source := {
		"version": GENERATED_LAYOUT_VERSION,
		"placement_authority_version": 5,
		"archetype_id": str(environment_data.get("archetype_id", environment_data.get("id", ""))),
		"layer_id": str(environment_data.get("current_layer_id", environment_data.get("layer_id", ""))),
		"surface_map": EnvironmentPlacementScript.surface_map(environment_data),
		"active_entries": active_entries,
		"layout_source": layout_source,
	}
	return JSON.stringify(signature_source).sha256_text()


# Applies the same class/surface authority used by scenario projection. Existing
# saved rects are inputs, not authority: restores therefore receive the current
# grounded placement without a save-schema change or a new RNG draw.
static func _ground_authored_object_rects(object_rects: Dictionary, layout: Dictionary, environment_data: Dictionary, active_entries: Array) -> void:
	var placed: Dictionary = {}
	var exclusive_placed: Dictionary = {}
	var placement_classes: Dictionary = {}
	var placement_surfaces: Dictionary = {}
	var placement_map := EnvironmentPlacementScript.surface_map(environment_data)
	var preferred_slots := JsonCoerceScript._copy_dict(placement_map.get("object_slot_positions", {}))
	var developer_object_slots := JsonCoerceScript._copy_dict(placement_map.get("developer_object_slot_positions", {}))
	var developer_category_slots := JsonCoerceScript._copy_dict(placement_map.get("developer_category_slot_positions", {}))
	var placement_errors: Array = []
	var placement_error_classes: Dictionary = {}
	var placement_fallback_ids: Array = []
	var placement_adjusted_ids: Array = []
	var placement_records: Dictionary = {}
	# Candidate domains are a pure function of an object's grounding record and
	# the environment surfaces. Keep them for the complete pass; successful
	# repacks invalidate only records whose current geometry changed.
	var placement_candidate_cache: Dictionary = {}
	var ordered_entries := active_entries.duplicate(true)
	ordered_entries.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left := JsonCoerceScript._copy_dict(left_value)
		var right := JsonCoerceScript._copy_dict(right_value)
		var left_id := str(left.get("object_id", ""))
		var right_id := str(right.get("object_id", ""))
		var left_class := EnvironmentPlacementScript.classify(left, str(left.get("object_type", "")), left_id)
		var right_class := EnvironmentPlacementScript.classify(right, str(right.get("object_type", "")), right_id)
		var left_route := left_class == "doorway" or str(left.get("object_type", "")) in ["travel", "casino_door"]
		var right_route := right_class == "doorway" or str(right.get("object_type", "")) in ["travel", "casino_door"]
		if left_route != right_route:
			return left_route
		var left_category_key := "%s:%d" % [str(left.get("spot_field", "")), int(left.get("index", 0))]
		var right_category_key := "%s:%d" % [str(right.get("spot_field", "")), int(right.get("index", 0))]
		# Exact category/index authoring has the same placement authority as an
		# exact object slot. Place both before flexible peers so ordinary packing
		# works around authored anchors instead of displacing them after the fact.
		var left_has_slot := preferred_slots.has(left_id) or developer_object_slots.has(left_id) \
				or developer_category_slots.has(left_category_key)
		var right_has_slot := preferred_slots.has(right_id) or developer_object_slots.has(right_id) \
				or developer_category_slots.has(right_category_key)
		if left_has_slot != right_has_slot:
			return left_has_slot
		var left_scarcity := int(BASE_PLACEMENT_SCARCITY_RANK.get(left_class, 100))
		var right_scarcity := int(BASE_PLACEMENT_SCARCITY_RANK.get(right_class, 100))
		return left_scarcity < right_scarcity if left_scarcity != right_scarcity else left_id < right_id
	)
	for entry_value in ordered_entries:
		var entry := JsonCoerceScript._copy_dict(entry_value)
		var object_id := str(entry.get("object_id", ""))
		if object_id.is_empty() or placed.has(object_id):
			continue
		var object_type := str(entry.get("object_type", ""))
		var exclusive_authority := _layout_entry_owns_exclusive_authority(entry)
		var placement_class := EnvironmentPlacementScript.classify(entry, object_type, object_id)
		placement_classes[object_id] = placement_class
		var authored_normalized := _rect_from_dict(object_rects.get(object_id, {}))
		var authored := Rect2(authored_normalized.position * ENVIRONMENT_BOARD_SIZE, authored_normalized.size * ENVIRONMENT_BOARD_SIZE)
		var slot_values := JsonCoerceScript._copy_array(preferred_slots.get(object_id, []))
		if slot_values.size() >= 2:
			authored.position = Vector2(float(slot_values[0]), float(slot_values[1]))
		var category_key := "%s:%d" % [str(entry.get("spot_field", "")), int(entry.get("index", 0))]
		var category_slot_values := JsonCoerceScript._copy_array(developer_category_slots.get(category_key, []))
		var developer_slot_values := JsonCoerceScript._copy_array(developer_object_slots.get(object_id, []))
		# An exact object decision is more specific than a category/index default.
		# The old reverse precedence silently moved doors and other reserved objects
		# back onto crowded generic slots.
		var manual_values := developer_slot_values if developer_slot_values.size() >= 2 else category_slot_values
		var manually_placed := manual_values.size() >= 2
		if manually_placed:
			authored.position = Vector2(float(manual_values[0]), float(manual_values[1]))
			authored.position.x = clampf(authored.position.x, 0.0, maxf(0.0, ENVIRONMENT_BOARD_SIZE.x - authored.size.x))
			authored.position.y = clampf(authored.position.y, 0.0, maxf(0.0, ENVIRONMENT_BOARD_SIZE.y - authored.size.y))
		var resolved := {"rect": authored, "surface_id": "developer_free", "adjusted": false} if manually_placed else EnvironmentPlacementScript.authored_or_local_rect(environment_data, placement_class, authored)
		var selected: Rect2 = resolved.get("rect", authored)
		var selected_surface := str(resolved.get("surface_id", ""))
		var placement_anchor := selected
		# Project-authored overrides are shipping content, not an exemption from hit
		# authority. Every origin participates in the same deterministic recovery.
		var selected_normalized := Rect2(selected.position / ENVIRONMENT_BOARD_SIZE, selected.size / ENVIRONMENT_BOARD_SIZE)
		var initial_direct_collision := _object_rect_direct_collides_with_any(placed, selected_normalized)
		var initial_expanded_collision := exclusive_authority and _expanded_object_rect_collides_with_any(exclusive_placed, selected_normalized)
		if _base_layout_candidate_collides(placed, exclusive_placed, selected_normalized, exclusive_authority, true):
			# The 8px presentation margin is advisory. Preserve an authored rect
			# immediately when its normal and expanded interaction authority is
			# already disjoint; candidate scans must not displace an exact slot for
			# a spacing-only conflict.
			var recovered := not initial_direct_collision and not initial_expanded_collision
			var recovered_via_grid := false
			var supported_candidates: Array = []
			var fine_candidates: Array = []
			if not recovered and not manually_placed:
				supported_candidates = EnvironmentPlacementScript.supported_rect_candidates(environment_data, placement_class, selected)
				for candidate_value in supported_candidates:
					var candidate: Dictionary = candidate_value
					var candidate_rect: Rect2 = candidate.get("rect", Rect2())
					var normalized_candidate := Rect2(candidate_rect.position / ENVIRONMENT_BOARD_SIZE, candidate_rect.size / ENVIRONMENT_BOARD_SIZE)
					if candidate_rect.has_area() and not _base_layout_candidate_collides(placed, exclusive_placed, normalized_candidate, exclusive_authority, true):
						selected = candidate_rect
						selected_surface = str(candidate.get("surface_id", selected_surface))
						recovered = true
						break
			# Coarse authored supports can skip a narrow valid gap. Exhaust the same
			# physical surfaces at the canonical 8px authoring step before invoking
			# transitive semantic repacking or failing closed.
			if not recovered and not manually_placed:
				fine_candidates = EnvironmentPlacementScript.candidate_rects(environment_data, placement_class, selected, Rect2(), true)
				for candidate_value in fine_candidates:
					var candidate := JsonCoerceScript._copy_dict(candidate_value)
					var candidate_rect: Rect2 = candidate.get("rect", Rect2())
					var normalized_candidate := Rect2(candidate_rect.position / ENVIRONMENT_BOARD_SIZE, candidate_rect.size / ENVIRONMENT_BOARD_SIZE)
					if candidate_rect.has_area() and not _base_layout_candidate_collides(placed, exclusive_placed, normalized_candidate, exclusive_authority, true):
						selected = candidate_rect
						selected_surface = str(candidate.get("surface_id", selected_surface))
						recovered = true
						break
			# Spacing is advisory (D2), while direct interaction authority is not.
			# Dense rooms may lack a margin-perfect support even though a support is
			# directly disjoint. Prefer that truthful placement over retaining the
			# original direct collision or incorrectly reporting exhaustion.
			if not recovered and not manually_placed and (initial_direct_collision or initial_expanded_collision):
				var relaxed_candidates := supported_candidates.duplicate(true)
				relaxed_candidates.append_array(fine_candidates)
				for candidate_value in relaxed_candidates:
					var candidate: Dictionary = candidate_value
					var candidate_rect: Rect2 = candidate.get("rect", Rect2())
					var normalized_candidate := Rect2(candidate_rect.position / ENVIRONMENT_BOARD_SIZE, candidate_rect.size / ENVIRONMENT_BOARD_SIZE)
					if candidate_rect.has_area() and not _base_layout_candidate_collides(placed, exclusive_placed, normalized_candidate, exclusive_authority, false):
						selected = candidate_rect
						selected_surface = str(candidate.get("surface_id", selected_surface))
						recovered = true
						break
			# A late, constrained object can be starved by an earlier flexible object.
			# Exhaust deterministic, class-valid transitive displacement before an
			# exclusive control may fail closed. Generic board slots are not physical
			# supports and therefore cannot count as successful item/event placement.
			if not recovered and exclusive_authority:
				var repair_record := {
					"object_id": object_id,
					"object_type": object_type,
					"index": int(entry.get("index", 0)),
					"placement_class": placement_class,
					"anchor_rect": placement_anchor,
					"current_rect": selected_normalized,
					"surface_id": selected_surface,
					"fallback": selected_surface == "fallback_grid",
					"is_route": placement_class == "doorway" or object_type in ["travel", "casino_door"],
					"fixed": manually_placed,
				}
				var repair := _try_repack_base_conflict_cohort(
					repair_record,
					environment_data,
					placed,
					exclusive_placed,
					placement_records,
					placement_candidate_cache
				)
				if bool(repair.get("ok", false)):
					var repaired_placements := JsonCoerceScript._copy_dict(repair.get("placements", {}))
					var repaired_ids := repaired_placements.keys()
					repaired_ids.sort()
					for repaired_id_value in repaired_ids:
						var repaired_id := str(repaired_id_value)
						var repaired := JsonCoerceScript._copy_dict(repaired_placements.get(repaired_id, {}))
						var repaired_rect: Rect2 = repaired.get("rect", Rect2())
						var repaired_surface := str(repaired.get("surface_id", ""))
						object_rects[repaired_id] = _rect_to_dict(repaired_rect)
						placed[repaired_id] = _rect_to_dict(repaired_rect)
						exclusive_placed[repaired_id] = _rect_to_dict(repaired_rect)
						placement_error_classes.erase(repaired_id)
						placement_surfaces[repaired_id] = repaired_surface
						placement_fallback_ids.erase(repaired_id)
						if bool(repaired.get("fallback", false)):
							if not placement_fallback_ids.has(repaired_id):
								placement_fallback_ids.append(repaired_id)
						placement_candidate_cache.erase(repaired_id)
						if placement_records.has(repaired_id):
							var repaired_record := JsonCoerceScript._copy_dict(placement_records.get(repaired_id, {}))
							var previous_rect: Rect2 = repaired_record.get("current_rect", Rect2())
							if bool(repaired_record.get("fixed", false)) and not previous_rect.is_equal_approx(repaired_rect) \
									and not placement_adjusted_ids.has(repaired_id):
								placement_adjusted_ids.append(repaired_id)
							repaired_record["current_rect"] = repaired_rect
							repaired_record["surface_id"] = repaired_surface
							repaired_record["fallback"] = bool(repaired.get("fallback", false))
							placement_records[repaired_id] = repaired_record
					var current_repair := JsonCoerceScript._copy_dict(repaired_placements.get(object_id, {}))
					var current_repair_rect: Rect2 = current_repair.get("rect", selected_normalized)
					selected = Rect2(current_repair_rect.position * ENVIRONMENT_BOARD_SIZE, current_repair_rect.size * ENVIRONMENT_BOARD_SIZE)
					selected_surface = str(current_repair.get("surface_id", selected_surface))
					recovered = true
					recovered_via_grid = bool(current_repair.get("fallback", false))
			# Ambient, noninteractive decoration may still use the bounded board grid.
			# Every actionable/exclusive record instead reports semantic exhaustion.
			if not recovered and not exclusive_authority:
				for fallback_value in _fallback_grid_object_rects(object_type, int(entry.get("index", 0)), selected_normalized):
					var fallback_normalized: Rect2 = fallback_value
					if not _base_layout_candidate_collides(placed, exclusive_placed, fallback_normalized, exclusive_authority, true):
						selected = Rect2(fallback_normalized.position * ENVIRONMENT_BOARD_SIZE, fallback_normalized.size * ENVIRONMENT_BOARD_SIZE)
						selected_surface = "fallback_grid"
						recovered = true
						recovered_via_grid = true
						break
			if not recovered and not exclusive_authority and (initial_direct_collision or initial_expanded_collision):
				for fallback_value in _fallback_grid_object_rects(object_type, int(entry.get("index", 0)), selected_normalized):
					var fallback_normalized: Rect2 = fallback_value
					if not _base_layout_candidate_collides(placed, exclusive_placed, fallback_normalized, exclusive_authority, false):
						selected = Rect2(fallback_normalized.position * ENVIRONMENT_BOARD_SIZE, fallback_normalized.size * ENVIRONMENT_BOARD_SIZE)
						selected_surface = "fallback_grid"
						recovered = true
						recovered_via_grid = true
						break
			# Moving to another valid authored support is ordinary packing. Reserve
			# fallback diagnostics for the generic grid, whose use means content has
			# no semantically appropriate slot and therefore needs author attention.
			if recovered_via_grid:
				if not placement_fallback_ids.has(object_id):
					placement_fallback_ids.append(object_id)
			elif not recovered and exclusive_authority and (initial_direct_collision or initial_expanded_collision):
				placement_error_classes[object_id] = placement_class
		# Surface grounding may shift an authored hotspot near the right or bottom
		# edge. Preserve its size while keeping the complete interactive rectangle
		# on the environment board; semantic validation rejects clipped controls.
		selected.position.x = clampf(selected.position.x, 0.0, maxf(0.0, ENVIRONMENT_BOARD_SIZE.x - selected.size.x))
		selected.position.y = clampf(selected.position.y, 0.0, maxf(0.0, ENVIRONMENT_BOARD_SIZE.y - selected.size.y))
		var normalized_selected := Rect2(selected.position / ENVIRONMENT_BOARD_SIZE, selected.size / ENVIRONMENT_BOARD_SIZE)
		object_rects[object_id] = _rect_to_dict(normalized_selected)
		placed[object_id] = _rect_to_dict(normalized_selected)
		if exclusive_authority:
			exclusive_placed[object_id] = _rect_to_dict(normalized_selected)
			placement_records[object_id] = {
				"object_id": object_id,
				"object_type": object_type,
				"index": int(entry.get("index", 0)),
				"placement_class": placement_class,
				"anchor_rect": placement_anchor,
				"current_rect": normalized_selected,
				"surface_id": selected_surface,
				"fallback": selected_surface == "fallback_grid",
				"is_route": placement_class == "doorway" or object_type in ["travel", "casino_door"],
				"fixed": manually_placed and selected_surface == "developer_free",
			}
		placement_surfaces[object_id] = selected_surface
	var unresolved_error_ids := placement_error_classes.keys()
	unresolved_error_ids.sort()
	for unresolved_id_value in unresolved_error_ids:
		var unresolved_id := str(unresolved_id_value)
		placement_errors.append("No collision-free placement exists for %s (%s)." % [unresolved_id, str(placement_error_classes.get(unresolved_id, ""))])
	# Re-audit the complete assembled set. Generated entries that appear after a
	# manual override may never turn an earlier exact placement into a silent
	# success.
	var placed_ids := exclusive_placed.keys()
	placed_ids.sort()
	for left_index in range(placed_ids.size()):
		var left_id := str(placed_ids[left_index])
		var left_rect := _rect_from_dict(exclusive_placed.get(left_id, {}))
		for right_index in range(left_index + 1, placed_ids.size()):
			var right_id := str(placed_ids[right_index])
			var right_rect := _rect_from_dict(exclusive_placed.get(right_id, {}))
			if left_rect.intersects(right_rect) and left_rect.intersection(right_rect).get_area() > 0.000001:
				placement_errors.append("Interactive placements %s and %s overlap after final packing." % [left_id, right_id])
			elif _expanded_object_rect(left_rect).intersects(_expanded_object_rect(right_rect)) \
					and _expanded_object_rect(left_rect).intersection(_expanded_object_rect(right_rect)).get_area() > 0.000001:
				placement_errors.append("Expanded interactive placements %s and %s overlap after final packing." % [left_id, right_id])
	layout["placement_classes"] = placement_classes
	layout["placement_surfaces"] = placement_surfaces
	layout["placement_errors"] = placement_errors
	layout["placement_fallback_ids"] = placement_fallback_ids
	placement_adjusted_ids.sort()
	layout["placement_adjusted_ids"] = placement_adjusted_ids


# Creates a generated display name from archetype name parts.
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


# Builds the per-instance room layout variant. Authored object families stay in their
# authored zones, while encounters can trade spots between runs.
static func _generated_layout_variant(archetype: Dictionary, rng: RngStream) -> Dictionary:
	var layout := JsonCoerceScript._copy_dict(archetype.get("layout", {}))
	var randomized_fields := JsonCoerceScript._string_array(archetype.get("randomized_spot_fields", ["event_spots", "lender_spots"]))
	for field_name_value in randomized_fields:
		var field_name := str(field_name_value)
		var spots := JsonCoerceScript._copy_array(layout.get(field_name, []))
		if spots.size() > 1:
			layout[field_name] = rng.shuffled(spots)
	return layout


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
static func _assign_string_object_rects(object_rects: Dictionary, layout: Dictionary, object_type: String, ids: Array, spot_field: String, active_object_ids: Dictionary) -> void:
	var stable_ids := JsonCoerceScript._string_array(ids)
	for index in range(stable_ids.size()):
		_assign_single_object_rect(object_rects, layout, "%s:%s" % [object_type, stable_ids[index]], object_type, index, spot_field, true, active_object_ids)


# Expands authored fixture counts without duplicating game simulation state.
# Extra fixtures route to the same game id while receiving stable object ids and spots.
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


static func _assign_object_layout_entries(object_rects: Dictionary, layout: Dictionary, entries: Array, active_object_ids: Dictionary) -> void:
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		_assign_single_object_rect(
			object_rects,
			layout,
			str(entry.get("object_id", "")),
			str(entry.get("object_type", "")),
			int(entry.get("index", 0)),
			str(entry.get("spot_field", "")),
			true,
			active_object_ids
		)


# Assigns stable rects to generated item offers by item id.
static func _assign_item_offer_rects(object_rects: Dictionary, layout: Dictionary, offers: Array, active_object_ids: Dictionary) -> void:
	var item_ids: Array = []
	for offer in offers:
		if typeof(offer) != TYPE_DICTIONARY:
			continue
		var item_id := str((offer as Dictionary).get("id", ""))
		if not item_id.is_empty() and not item_ids.has(item_id):
			item_ids.append(item_id)
	for index in range(item_ids.size()):
		_assign_single_object_rect(object_rects, layout, "item:%s" % item_ids[index], "item", index, "item_spots", true, active_object_ids)


# Assigns one object rect without disturbing an existing generated rect.
static func _assign_single_object_rect(object_rects: Dictionary, layout: Dictionary, object_id: String, object_type: String, index: int, spot_field: String, should_assign: bool, _active_object_ids: Dictionary) -> void:
	if not should_assign or object_id.is_empty() or object_rects.has(object_id):
		return
	var rect := _object_rect_from_layout(layout, object_type, index, spot_field)
	object_rects[object_id] = _rect_to_dict(rect)


# Keeps late-added objects from taking a spot already owned by a persistent object.
static func _first_available_object_rect(object_rects: Dictionary, active_object_ids: Dictionary, object_id: String, layout: Dictionary, object_type: String, index: int, spot_field: String, desired_rect: Rect2) -> Rect2:
	if not _object_rect_collides_with_active(object_rects, active_object_ids, object_id, desired_rect):
		return desired_rect
	var slot_count := maxi(maxi(_layout_spot_count(layout, spot_field), index + 1), 8)
	for slot_index in range(slot_count):
		var candidate := _object_rect_from_layout(layout, object_type, slot_index, spot_field)
		if not _object_rect_collides_with_active(object_rects, active_object_ids, object_id, candidate):
			return candidate
	for candidate_value in _fallback_grid_object_rects(object_type, index, desired_rect):
		var candidate: Rect2 = candidate_value
		if not _object_rect_collides_with_active(object_rects, active_object_ids, object_id, candidate):
			return candidate
	return desired_rect


static func _layout_spot_count(layout: Dictionary, spot_field: String) -> int:
	if spot_field.is_empty():
		return 0
	var spots: Variant = layout.get(spot_field, [])
	if typeof(spots) != TYPE_ARRAY:
		return 0
	return (spots as Array).size()


static func _object_rect_collides_with_active(object_rects: Dictionary, active_object_ids: Dictionary, object_id: String, rect: Rect2) -> bool:
	for key in object_rects.keys():
		var existing_id := str(key)
		if existing_id == object_id or not bool(active_object_ids.get(existing_id, false)):
			continue
		var existing_rect := _rect_from_dict(object_rects.get(key, {}))
		if existing_rect.size.x <= 0.0 or existing_rect.size.y <= 0.0:
			continue
		if _rects_overlap_with_layout_gap(existing_rect, rect):
			return true
	return false


static func _rects_overlap_with_layout_gap(a: Rect2, b: Rect2) -> bool:
	var gap := Vector2(8.0 / ENVIRONMENT_BOARD_SIZE.x, 8.0 / ENVIRONMENT_BOARD_SIZE.y)
	var a_padded := Rect2(a.position - gap, a.size + gap * 2.0)
	var b_padded := Rect2(b.position - gap, b.size + gap * 2.0)
	return a_padded.intersects(b_padded)


# Returns authored spot placement when available, otherwise the generated fallback slot.
static func _object_rect_from_layout(layout: Dictionary, object_type: String, index: int, spot_field: String) -> Rect2:
	var fallback_rect := _fallback_object_rect(object_type, index)
	var spot := _layout_spot(layout, spot_field, index)
	if spot.x < 0.0 or spot.y < 0.0:
		return fallback_rect
	var center := Vector2(
		clampf(spot.x / ENVIRONMENT_BOARD_SIZE.x, 0.0, 1.0),
		clampf(spot.y / ENVIRONMENT_BOARD_SIZE.y, 0.0, 1.0)
	)
	return _clamped_rect_from_center(center, fallback_rect.size)


# Mirrors the foundation UI fallback slots so generated layouts remain stable without authored spots.
static func _fallback_object_rect(object_type: String, index: int) -> Rect2:
	var center := Vector2(0.5, 0.5)
	var size := Vector2(0.12, 0.18)
	match object_type:
		"game":
			center = Vector2(0.28 + float(index % 3) * 0.18, 0.56 + float(index / 3) * 0.13)
			size = Vector2(110.0 / ENVIRONMENT_BOARD_SIZE.x, 72.0 / ENVIRONMENT_BOARD_SIZE.y)
		"event":
			center = Vector2(0.68 + float(index % 2) * 0.12, 0.42 + float(index / 2) * 0.14)
			size = Vector2(100.0 / ENVIRONMENT_BOARD_SIZE.x, 64.0 / ENVIRONMENT_BOARD_SIZE.y)
		"item":
			var item_columns := 5
			center = Vector2(0.20 + float(index % item_columns) * 0.15, 0.36 + float(index / item_columns) * 0.14)
			size = Vector2(90.0 / ENVIRONMENT_BOARD_SIZE.x, 54.0 / ENVIRONMENT_BOARD_SIZE.y)
		"shopkeeper":
			center = Vector2(0.80, 0.34)
			size = Vector2(108.0 / ENVIRONMENT_BOARD_SIZE.x, 70.0 / ENVIRONMENT_BOARD_SIZE.y)
		"game_hook":
			var hook_columns := 5
			center = Vector2(0.18 + float(index % hook_columns) * 0.16, 0.82 - float(index / hook_columns) * 0.14)
			size = Vector2(104.0 / ENVIRONMENT_BOARD_SIZE.x, 58.0 / ENVIRONMENT_BOARD_SIZE.y)
		"travel":
			var travel_centers := [
				Vector2(0.84, 0.34),
				Vector2(0.84, 0.60),
				Vector2(0.50, 0.18),
				Vector2(0.50, 0.50),
				Vector2(0.30, 0.28),
				Vector2(0.30, 0.78),
				Vector2(0.64, 0.30),
				Vector2(0.64, 0.70),
				Vector2(0.84, 0.84),
			]
			center = travel_centers[index % travel_centers.size()]
			size = Vector2(104.0 / ENVIRONMENT_BOARD_SIZE.x, 64.0 / ENVIRONMENT_BOARD_SIZE.y)
		"service":
			var service_columns := 6
			center = Vector2(0.14 + float(index % service_columns) * 0.14, 0.30 + float(index / service_columns) * 0.13)
			size = Vector2(96.0 / ENVIRONMENT_BOARD_SIZE.x, 54.0 / ENVIRONMENT_BOARD_SIZE.y)
		"lender":
			var lender_columns := 5
			center = Vector2(0.22 + float(index % lender_columns) * 0.15, 0.70 + float(index / lender_columns) * 0.12)
			size = Vector2(102.0 / ENVIRONMENT_BOARD_SIZE.x, 58.0 / ENVIRONMENT_BOARD_SIZE.y)
		"numbers", "numbers_silas":
			center = Vector2(0.42 + float(index % 2) * 0.24, 0.68)
			size = Vector2(106.0 / ENVIRONMENT_BOARD_SIZE.x, 62.0 / ENVIRONMENT_BOARD_SIZE.y)
		"environment_layer":
			center = Vector2(0.80, 0.26 + float(index % 3) * 0.24)
			size = Vector2(118.0 / ENVIRONMENT_BOARD_SIZE.x, 72.0 / ENVIRONMENT_BOARD_SIZE.y)
		"home_tenure":
			center = Vector2(0.78, 0.46)
			size = Vector2(116.0 / ENVIRONMENT_BOARD_SIZE.x, 58.0 / ENVIRONMENT_BOARD_SIZE.y)
		"home_sleep":
			center = Vector2(0.50, 0.42)
			size = Vector2(150.0 / ENVIRONMENT_BOARD_SIZE.x, 74.0 / ENVIRONMENT_BOARD_SIZE.y)
		"home_storage":
			center = Vector2(0.20, 0.72)
			size = Vector2(108.0 / ENVIRONMENT_BOARD_SIZE.x, 58.0 / ENVIRONMENT_BOARD_SIZE.y)
		"home_container":
			var container_columns := 4
			center = Vector2(0.22 + float(index % container_columns) * 0.18, 0.76 + float(index / container_columns) * 0.11)
			size = Vector2(104.0 / ENVIRONMENT_BOARD_SIZE.x, 58.0 / ENVIRONMENT_BOARD_SIZE.y)
	return _clamped_rect_from_center(center, size)


# Reads an authored board-coordinate spot from a generated layout.
static func _layout_spot(layout: Dictionary, spot_field: String, index: int) -> Vector2:
	if spot_field.is_empty():
		return Vector2(-1.0, -1.0)
	var spots: Variant = layout.get(spot_field, [])
	if typeof(spots) != TYPE_ARRAY or index < 0 or index >= (spots as Array).size():
		return Vector2(-1.0, -1.0)
	return _layout_spot_to_board_position((spots as Array)[index])


# Converts supported authoring spot formats to board coordinates.
static func _layout_spot_to_board_position(value: Variant) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value as Vector2
	if typeof(value) == TYPE_VECTOR2I:
		var spot_i := value as Vector2i
		return Vector2(float(spot_i.x), float(spot_i.y))
	if typeof(value) == TYPE_ARRAY:
		var parts := value as Array
		if parts.size() >= 2:
			return Vector2(float(parts[0]), float(parts[1]))
	if typeof(value) == TYPE_DICTIONARY:
		var data := value as Dictionary
		return Vector2(float(data.get("x", -1.0)), float(data.get("y", -1.0)))
	return Vector2(-1.0, -1.0)


# Keeps generated rects in the normalized environment canvas.
static func _clamped_rect_from_center(center: Vector2, size: Vector2) -> Rect2:
	var clamped_size := Vector2(clampf(size.x, 0.08, 0.22), clampf(size.y, 0.12, 0.28))
	var max_position := Vector2(0.98, 0.96) - clamped_size
	var position := center - clamped_size * 0.5
	return Rect2(
		Vector2(
			clampf(position.x, 0.02, maxf(0.02, max_position.x)),
			clampf(position.y, 0.04, maxf(0.04, max_position.y))
		),
		clamped_size
	)


# Converts a normalized rect to saveable primitive data.
static func _rect_to_dict(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"w": rect.size.x,
		"h": rect.size.y,
	}


static func _rect_from_dict(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value as Rect2
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data: Dictionary = value
	return Rect2(
		Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))),
		Vector2(float(data.get("w", 0.0)), float(data.get("h", 0.0)))
	)


static func _resolve_active_object_rect_collisions(object_rects: Dictionary, layout: Dictionary, active_entries: Array) -> void:
	var kept_rects: Dictionary = {}
	for entry_value in active_entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var object_id := str(entry.get("object_id", ""))
		if object_id.is_empty():
			continue
		var object_type := str(entry.get("object_type", ""))
		var index := int(entry.get("index", 0))
		var spot_field := str(entry.get("spot_field", ""))
		var rect := _rect_from_dict(object_rects.get(object_id, {}))
		if rect.size.x <= 0.0 or rect.size.y <= 0.0 or _object_rect_collides_with_any(kept_rects, rect):
			var desired_rect := _object_rect_from_layout(layout, object_type, index, spot_field)
			rect = _first_noncolliding_object_rect(kept_rects, layout, object_type, index, spot_field, desired_rect)
			object_rects[object_id] = _rect_to_dict(rect)
		kept_rects[object_id] = _rect_to_dict(rect)


static func _first_noncolliding_object_rect(placed_rects: Dictionary, layout: Dictionary, object_type: String, index: int, spot_field: String, desired_rect: Rect2) -> Rect2:
	if not _object_rect_collides_with_any(placed_rects, desired_rect):
		return desired_rect
	var slot_count := maxi(maxi(_layout_spot_count(layout, spot_field), index + 1), 48)
	for slot_index in range(slot_count):
		var candidate := _object_rect_from_layout(layout, object_type, slot_index, spot_field)
		if not _object_rect_collides_with_any(placed_rects, candidate):
			return candidate
	for candidate_value in _fallback_grid_object_rects(object_type, index, desired_rect):
		var candidate: Rect2 = candidate_value
		if not _object_rect_collides_with_any(placed_rects, candidate):
			return candidate
	return desired_rect


static func _object_rect_collides_with_any(placed_rects: Dictionary, rect: Rect2) -> bool:
	for key in placed_rects.keys():
		var existing_rect := _rect_from_dict(placed_rects.get(key, {}))
		if existing_rect.size.x <= 0.0 or existing_rect.size.y <= 0.0:
			continue
		if _rects_overlap_with_layout_gap(existing_rect, rect):
			return true
	return false


static func _object_rect_direct_collides_with_any(placed_rects: Dictionary, rect: Rect2) -> bool:
	for key in placed_rects.keys():
		var existing_rect := _rect_from_dict(placed_rects.get(key, {}))
		if existing_rect.has_area() and rect.has_area() and existing_rect.intersects(rect) \
				and existing_rect.intersection(rect).get_area() > 0.000001:
			return true
	return false


static func _layout_entry_owns_exclusive_authority(entry: Dictionary) -> bool:
	# Layer ambience is descriptive scenery and the production record is explicitly
	# noninteractive. Every other generated-layout entry becomes a selectable base
	# control, including disabled-but-readable doors and offers.
	return str(entry.get("object_id", "")) != "environment_layer:ambient"


static func _base_layout_candidate_collides(placed_rects: Dictionary, exclusive_rects: Dictionary, rect: Rect2, exclusive_authority: bool, require_layout_gap: bool) -> bool:
	var visual_collision := _object_rect_collides_with_any(placed_rects, rect) if require_layout_gap else _object_rect_direct_collides_with_any(placed_rects, rect)
	if visual_collision:
		return true
	return exclusive_authority and _expanded_object_rect_collides_with_any(exclusive_rects, rect)


static func _try_repack_base_conflict_cohort(current_record: Dictionary, environment_data: Dictionary, placed_rects: Dictionary, exclusive_rects: Dictionary, placement_records: Dictionary, candidate_cache: Dictionary) -> Dictionary:
	var current_id := str(current_record.get("object_id", ""))
	var current_rect: Rect2 = current_record.get("current_rect", Rect2())
	if current_id.is_empty() or not current_rect.has_area() or bool(current_record.get("is_route", false)):
		return {"ok": false}
	var pair_conflict_cache: Dictionary = {}
	var movable_records: Dictionary = {}
	var relaxable_fixed_records: Dictionary = {}
	var immutable_placed := placed_rects.duplicate(true)
	var immutable_exclusive := exclusive_rects.duplicate(true)
	var strict_immutable_placed := placed_rects.duplicate(true)
	var strict_immutable_exclusive := exclusive_rects.duplicate(true)
	var movable_expanded_rects: Dictionary = {}
	var movable_ids := placement_records.keys()
	movable_ids.sort()
	for movable_id_value in movable_ids:
		var movable_id := str(movable_id_value)
		var movable_record := JsonCoerceScript._copy_dict(placement_records.get(movable_id, {}))
		if not exclusive_rects.has(movable_id):
			continue
		# Authored route locks stay immutable, but an ordinary generated route may
		# move to another class-valid doorway when it blocks a later exact developer
		# placement. Treating every route as immutable made a clear doorway elsewhere
		# in the same room invisible to the complete transitive solve.
		if bool(movable_record.get("is_route", false)) and bool(movable_record.get("fixed", false)):
			continue
		if bool(movable_record.get("fixed", false)):
			# Exact/manual content remains fixed through strict class-local and ordinary
			# movable expansion. If those complete graphs are impossible, an actual
			# blocking fixed record may join the final class-valid solve with its
			# authored/current rect still ranked first. Routes never enter this path.
			relaxable_fixed_records[movable_id] = movable_record
			immutable_placed.erase(movable_id)
			immutable_exclusive.erase(movable_id)
			var relaxable_expanded := _expanded_object_rect(_rect_from_dict(exclusive_rects.get(movable_id, {})))
			if relaxable_expanded.has_area():
				movable_expanded_rects[movable_id] = _rect_to_dict(relaxable_expanded)
			continue
		movable_records[movable_id] = movable_record
		immutable_placed.erase(movable_id)
		immutable_exclusive.erase(movable_id)
		strict_immutable_placed.erase(movable_id)
		strict_immutable_exclusive.erase(movable_id)
		var movable_expanded := _expanded_object_rect(_rect_from_dict(exclusive_rects.get(movable_id, {})))
		if movable_expanded.has_area():
			movable_expanded_rects[movable_id] = _rect_to_dict(movable_expanded)
	if movable_records.is_empty() and relaxable_fixed_records.is_empty():
		return {"ok": false}
	var immutable_expanded := _base_layout_expanded_rect_map(immutable_exclusive)
	var strict_immutable_expanded := _base_layout_expanded_rect_map(strict_immutable_exclusive)
	# Each complete semantic candidate is a deterministic target. A deliberate
	# developer slot remains pinned, but its movable blockers still participate in
	# the same general displacement solve; fixed does not mean collision-exempt.
	var candidate_tier_limit := BASE_REPACK_CANDIDATE_TIER_SUPPORTED
	var target_candidates: Array = []
	if bool(current_record.get("fixed", false)):
		var current_pixel := Rect2(current_rect.position * ENVIRONMENT_BOARD_SIZE, current_rect.size * ENVIRONMENT_BOARD_SIZE)
		target_candidates.append({
			"rect": current_rect,
			"expanded_rect": _expanded_object_rect(current_rect),
			"surface_id": str(current_record.get("surface_id", "developer_free")),
			"fallback": false,
			"preferred": true,
			"tier": BASE_REPACK_CANDIDATE_TIER_PREFERRED,
			"key": "%.3f:%.3f:%.3f:%.3f" % [current_pixel.position.x, current_pixel.position.y, current_pixel.size.x, current_pixel.size.y],
			"pixel_center": current_pixel.get_center(),
			"ordinal": 0,
		})
	else:
		target_candidates = _cached_base_layout_repack_candidates(
			current_record,
			environment_data,
			candidate_cache,
			candidate_tier_limit
		)
	# Solve the canonical preferred/supported domain first. Fine 8px candidates
	# remain a complete fallback, but ordinary rooms never pay their combinatorial
	# cost when an authored support already resolves the collision.
	var viable_targets := _base_layout_repack_viable_candidates(
		target_candidates,
		immutable_placed,
		immutable_expanded,
		candidate_tier_limit
	)
	if viable_targets.is_empty():
		candidate_tier_limit = BASE_REPACK_CANDIDATE_TIER_FINE
		if not bool(current_record.get("fixed", false)):
			target_candidates = _cached_base_layout_repack_candidates(
				current_record,
				environment_data,
				candidate_cache,
				candidate_tier_limit
			)
		viable_targets = _base_layout_repack_viable_candidates(
			target_candidates,
			immutable_placed,
			immutable_expanded,
			candidate_tier_limit
		)
	if viable_targets.is_empty():
		return {"ok": false}
	# Begin with the object that actually failed placement. Only a blocker touched
	# by a complete candidate domain may enter the deterministic transitive closure;
	# unrelated same-class records must not inflate the constraint graph.
	var cohort_ids: Dictionary = {current_id: true}
	var remaining_relaxable_records := relaxable_fixed_records.duplicate(true)
	var active_immutable_placed := strict_immutable_placed.duplicate(true)
	var active_immutable_expanded := strict_immutable_expanded.duplicate(true)
	var fixed_relaxation_active := false
	while true:
		# Flexible records have no authored-lock privilege. Expand their complete
		# deterministic transitive blocker closure before solving, instead of paying
		# for a series of doomed prefix proofs as each blocker joins one at a time.
		while true:
			var closure_records := _base_layout_repack_cohort_records(current_record, cohort_ids, movable_records)
			var closure_blocker := _next_base_layout_transitive_blocker(
				current_id,
				viable_targets,
				closure_records,
				cohort_ids,
				movable_records,
				movable_expanded_rects,
				environment_data,
				active_immutable_placed,
				active_immutable_expanded,
				candidate_cache,
				candidate_tier_limit
			)
			if closure_blocker.is_empty():
				break
			cohort_ids[closure_blocker] = true
		var cohort_records := _base_layout_repack_cohort_records(current_record, cohort_ids, movable_records)
		var fixed_placed := placed_rects.duplicate(true)
		var fixed_exclusive := exclusive_rects.duplicate(true)
		for cohort_id_value in cohort_ids.keys():
			var cohort_id := str(cohort_id_value)
			fixed_placed.erase(cohort_id)
			fixed_exclusive.erase(cohort_id)
		var solution := _solve_base_layout_repack_cohort(
			cohort_records,
			environment_data,
			fixed_placed,
			fixed_exclusive,
			candidate_cache,
			{current_id: viable_targets},
			pair_conflict_cache,
			current_id,
			candidate_tier_limit
		)
		if bool(solution.get("ok", false)):
			return solution
		if candidate_tier_limit < BASE_REPACK_CANDIDATE_TIER_FINE:
			# The supported graph was proved impossible with its exact transitive
			# blockers. Fine geometry is always the complete fallback. Before fixed
			# relaxation begins, reset to the strict no-lock-movement graph; once the
			# strict fine proof has already completed, retain the admitted fixed closure.
			candidate_tier_limit = BASE_REPACK_CANDIDATE_TIER_FINE
			if not bool(current_record.get("fixed", false)):
				target_candidates = _cached_base_layout_repack_candidates(
					current_record,
					environment_data,
					candidate_cache,
					candidate_tier_limit
				)
			viable_targets = _base_layout_repack_viable_candidates(
				target_candidates,
				immutable_placed,
				immutable_expanded,
				candidate_tier_limit
			)
			if viable_targets.is_empty():
				return {"ok": false}
			if not fixed_relaxation_active:
				cohort_ids = {current_id: true}
				remaining_relaxable_records = relaxable_fixed_records.duplicate(true)
				active_immutable_placed = strict_immutable_placed.duplicate(true)
				active_immutable_expanded = strict_immutable_expanded.duplicate(true)
			pair_conflict_cache.clear()
			continue
		if not remaining_relaxable_records.is_empty():
			# Strict fine-grid packing has already been proved impossible without moving
			# a fixed object. Build the complete deterministic transitive closure of only
			# the fixed records that actually block a cohort candidate, then solve once.
			# Every admitted lock keeps its exact rect first in its domain, so closure
			# membership does not move it unless the complete solve requires that change.
			var fixed_closure_added := false
			while not remaining_relaxable_records.is_empty():
				var closure_records := _base_layout_repack_cohort_records(current_record, cohort_ids, movable_records)
				var next_fixed_blocker := _next_base_layout_transitive_blocker(
					current_id,
					viable_targets,
					closure_records,
					cohort_ids,
					remaining_relaxable_records,
					movable_expanded_rects,
					environment_data,
					immutable_placed,
					immutable_expanded,
					candidate_cache,
					candidate_tier_limit
				)
				if next_fixed_blocker.is_empty():
					remaining_relaxable_records.clear()
					break
				var next_fixed_record := JsonCoerceScript._copy_dict(remaining_relaxable_records.get(next_fixed_blocker, {}))
				movable_records[next_fixed_blocker] = next_fixed_record
				cohort_ids[next_fixed_blocker] = true
				remaining_relaxable_records.erase(next_fixed_blocker)
				active_immutable_placed.erase(next_fixed_blocker)
				active_immutable_expanded.erase(next_fixed_blocker)
				fixed_closure_added = true
			if fixed_closure_added:
				# Strict preferred/supported and fine domains have both failed before any
				# lock moves. Re-enter the smaller supported tier for the admitted fixed
				# closure, with fine geometry still guaranteed as its complete fallback.
				fixed_relaxation_active = true
				candidate_tier_limit = BASE_REPACK_CANDIDATE_TIER_SUPPORTED
				viable_targets = _base_layout_repack_viable_candidates(
					target_candidates,
					immutable_placed,
					immutable_expanded,
					candidate_tier_limit
				)
				if viable_targets.is_empty():
					candidate_tier_limit = BASE_REPACK_CANDIDATE_TIER_FINE
					if not bool(current_record.get("fixed", false)):
						target_candidates = _cached_base_layout_repack_candidates(
							current_record,
							environment_data,
							candidate_cache,
							candidate_tier_limit
						)
					viable_targets = _base_layout_repack_viable_candidates(
						target_candidates,
						immutable_placed,
						immutable_expanded,
						candidate_tier_limit
					)
				pair_conflict_cache.clear()
				continue
		break
	return {"ok": false}


static func _base_layout_expanded_rect_map(rects: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var object_ids := rects.keys()
	object_ids.sort()
	for object_id_value in object_ids:
		var object_id := str(object_id_value)
		var expanded := _expanded_object_rect(_rect_from_dict(rects.get(object_id, {})))
		if expanded.has_area():
			result[object_id] = _rect_to_dict(expanded)
	return result


static func _base_layout_repack_viable_candidates(candidates: Array, immutable_placed: Dictionary, immutable_expanded: Dictionary, tier_limit: int) -> Array:
	var result: Array = []
	for candidate_value in candidates:
		var candidate: Dictionary = candidate_value
		if int(candidate.get("tier", BASE_REPACK_CANDIDATE_TIER_FINE)) > tier_limit:
			continue
		if _base_layout_repack_candidate_collides(immutable_placed, immutable_expanded, candidate):
			continue
		result.append(candidate)
	return result


static func _base_layout_repack_cohort_records(current_record: Dictionary, cohort_ids: Dictionary, movable_records: Dictionary) -> Array:
	var result: Array = [current_record.duplicate(true)]
	var object_ids := cohort_ids.keys()
	object_ids.sort()
	var current_id := str(current_record.get("object_id", ""))
	for object_id_value in object_ids:
		var object_id := str(object_id_value)
		if object_id == current_id or not movable_records.has(object_id):
			continue
		result.append(JsonCoerceScript._copy_dict(movable_records.get(object_id, {})))
	return result


static func _next_base_layout_transitive_blocker(current_id: String, current_targets: Array, cohort_records: Array, cohort_ids: Dictionary, movable_records: Dictionary, movable_expanded_rects: Dictionary, environment_data: Dictionary, immutable_placed: Dictionary, immutable_expanded: Dictionary, candidate_cache: Dictionary, candidate_tier_limit: int) -> String:
	var conflict_scores: Dictionary = {}
	for record_value in cohort_records:
		var record := JsonCoerceScript._copy_dict(record_value)
		var record_id := str(record.get("object_id", ""))
		var candidates: Array = current_targets if record_id == current_id else _base_layout_repack_candidates_for_tier(
			_cached_base_layout_repack_candidates(record, environment_data, candidate_cache, candidate_tier_limit),
			candidate_tier_limit
		)
		for candidate_value in candidates:
			var candidate: Dictionary = candidate_value
			if _base_layout_repack_candidate_collides(immutable_placed, immutable_expanded, candidate):
				continue
			var expanded: Rect2 = candidate.get("expanded_rect", Rect2())
			for blocker_id_value in _base_layout_conflicting_expanded_ids(movable_expanded_rects, expanded):
				var blocker_id := str(blocker_id_value)
				if blocker_id == record_id or cohort_ids.has(blocker_id) or not movable_records.has(blocker_id):
					continue
				var score := JsonCoerceScript._copy_dict(conflict_scores.get(blocker_id, {}))
				score["count"] = int(score.get("count", 0)) + 1
				score["preferred"] = bool(score.get("preferred", false)) or bool(candidate.get("preferred", false))
				conflict_scores[blocker_id] = score
	var ranked_blockers := conflict_scores.keys()
	ranked_blockers.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left_id := str(left_value)
		var right_id := str(right_value)
		var left_score := JsonCoerceScript._copy_dict(conflict_scores.get(left_id, {}))
		var right_score := JsonCoerceScript._copy_dict(conflict_scores.get(right_id, {}))
		var left_preferred := bool(left_score.get("preferred", false))
		var right_preferred := bool(right_score.get("preferred", false))
		if left_preferred != right_preferred:
			return left_preferred
		var left_count := int(left_score.get("count", 0))
		var right_count := int(right_score.get("count", 0))
		return left_count > right_count if left_count != right_count else left_id < right_id
	)
	return "" if ranked_blockers.is_empty() else str(ranked_blockers[0])


static func _solve_base_layout_repack_cohort(cohort_records: Array, environment_data: Dictionary, fixed_placed: Dictionary, fixed_exclusive: Dictionary, candidate_cache: Dictionary, pinned_candidates: Dictionary, pair_conflict_cache: Dictionary, priority_object_id: String, candidate_tier_limit: int) -> Dictionary:
	var candidate_domains: Dictionary = {}
	var fixed_expanded := _base_layout_expanded_rect_map(fixed_exclusive)
	for record_value in cohort_records:
		var record := JsonCoerceScript._copy_dict(record_value)
		var object_id := str(record.get("object_id", ""))
		var viable: Array = []
		var source_candidates: Array = pinned_candidates.get(object_id, []) if pinned_candidates.has(object_id) else _base_layout_repack_candidates_for_tier(
			_cached_base_layout_repack_candidates(record, environment_data, candidate_cache, candidate_tier_limit),
			candidate_tier_limit
		)
		for candidate_value in source_candidates:
			var candidate: Dictionary = candidate_value
			if not _base_layout_repack_candidate_collides(fixed_placed, fixed_expanded, candidate):
				viable.append(candidate)
		if viable.is_empty():
			return {"ok": false}
		candidate_domains[object_id] = viable
	# Dense fine-grid cohorts are usually satisfiable near the front of their
	# deterministic domains. Try that exact search before building compatibility
	# proofs for every candidate pair. The node cap is only a fast-path budget:
	# an interrupted search falls through to the complete capacity proof below.
	var fast_placements: Dictionary = {}
	var fast_state := {"nodes": 0, "aborted": false}
	var fast_solved := _search_base_layout_repack_bounded(
		candidate_domains,
		fast_placements,
		pair_conflict_cache,
		priority_object_id,
		fast_state,
		BASE_REPACK_FAST_SEARCH_NODE_LIMIT
	)
	if fast_solved:
		return {"ok": true, "placements": fast_placements}
	if not bool(fast_state.get("aborted", false)):
		return {"ok": false}
	# Exact compatibility-equivalent candidates are interchangeable for every
	# remaining constraint. Collapse them in O(candidate-pairs) before the stronger
	# ordered-dominance pass, whose former cubic scan was the dense-room hot path.
	# Build the cross-object compatibility relation once. Fine-tier rooms can have
	# thousands of candidates; recomputing rectangle intersections separately for
	# equivalence, dominance, and every earlier/later pair turns this exact
	# preprocessing step cubic. Bitsets retain the same relation and authored
	# order while reducing the two pruning passes to masked equality/subset tests.
	var compatibility_graph := _base_layout_repack_candidate_compatibility_graph(candidate_domains)
	_base_layout_repack_prune_compatibility_equivalent_candidates(candidate_domains, compatibility_graph)
	# A later candidate is redundant when an earlier candidate is compatible with
	# every peer placement it supports. Removing only order-dominated candidates
	# preserves exact preference while collapsing equivalent fine-grid geometry
	# before an otherwise exponential UNSAT proof.
	_base_layout_repack_prune_order_dominated_candidates(candidate_domains, compatibility_graph)
	# The reduced compatibility graph has one vertex per remaining placement and no
	# edges within an object's partition. A clique as large as the object cohort is
	# therefore exactly one collision-free placement per object. Greedy graph-color
	# bounds prove global capacity failures that pairwise consistency cannot see;
	# deterministic self-reduction still emits the first authored priority choice.
	pair_conflict_cache.clear()
	return _solve_base_layout_repack_clique(candidate_domains, priority_object_id, compatibility_graph)


static func _search_base_layout_repack_bounded(candidate_domains: Dictionary, placements: Dictionary, pair_conflict_cache: Dictionary, priority_object_id: String, state: Dictionary, node_limit: int) -> bool:
	state["nodes"] = int(state.get("nodes", 0)) + 1
	if int(state.get("nodes", 0)) > node_limit:
		state["aborted"] = true
		return false
	if candidate_domains.is_empty():
		return true
	var object_id := ""
	var viable_candidates: Array = []
	var sorted_ids := candidate_domains.keys()
	sorted_ids.sort()
	if not priority_object_id.is_empty() and candidate_domains.has(priority_object_id):
		object_id = priority_object_id
		viable_candidates = candidate_domains.get(priority_object_id, [])
	else:
		for candidate_id_value in sorted_ids:
			var candidate_id := str(candidate_id_value)
			var candidate_viable: Array = candidate_domains.get(candidate_id, [])
			if candidate_viable.is_empty():
				return false
			if object_id.is_empty() or candidate_viable.size() < viable_candidates.size():
				object_id = candidate_id
				viable_candidates = candidate_viable
	for candidate_value in viable_candidates:
		if bool(state.get("aborted", false)):
			return false
		var candidate: Dictionary = candidate_value
		var next_domains: Dictionary = {}
		var possible := true
		for remaining_id_value in sorted_ids:
			var remaining_id := str(remaining_id_value)
			if remaining_id == object_id:
				continue
			var filtered: Array = []
			for remaining_candidate_value in candidate_domains.get(remaining_id, []):
				var remaining_candidate: Dictionary = remaining_candidate_value
				if not _base_layout_repack_candidates_conflict(
					object_id,
					candidate,
					remaining_id,
					remaining_candidate,
					pair_conflict_cache
				):
					filtered.append(remaining_candidate)
			if filtered.is_empty():
				possible = false
				break
			next_domains[remaining_id] = filtered
		if not possible:
			continue
		placements[object_id] = candidate
		if _search_base_layout_repack_bounded(next_domains, placements, pair_conflict_cache, priority_object_id, state, node_limit):
			return true
		placements.erase(object_id)
	return false


static func _base_layout_repack_candidate_compatibility_graph(candidate_domains: Dictionary) -> Dictionary:
	var object_ids := candidate_domains.keys()
	object_ids.sort()
	var vertex_objects := PackedInt32Array()
	var vertex_candidates: Array = []
	var object_vertices: Dictionary = {}
	for object_index in range(object_ids.size()):
		var object_id := str(object_ids[object_index])
		var vertices := PackedInt32Array()
		var candidates: Array = candidate_domains.get(object_id, [])
		for candidate_value in candidates:
			vertices.append(vertex_candidates.size())
			vertex_objects.append(object_index)
			vertex_candidates.append(candidate_value)
		object_vertices[object_id] = vertices
	var vertex_count := vertex_candidates.size()
	var word_count := int(ceil(float(vertex_count) / float(BASE_REPACK_CLIQUE_WORD_BITS)))
	var adjacency: Array = []
	adjacency.resize(vertex_count)
	# Row construction intentionally evaluates the symmetric relation per row.
	# Packed arrays are copy-on-write, so mutating two shared rows per edge is
	# substantially more expensive than the duplicate geometry predicate here.
	for left_vertex in range(vertex_count):
		var neighbors := PackedInt64Array()
		neighbors.resize(word_count)
		var left_object := int(vertex_objects[left_vertex])
		var left_candidate: Dictionary = vertex_candidates[left_vertex]
		for right_vertex in range(vertex_count):
			if right_vertex == left_vertex or int(vertex_objects[right_vertex]) == left_object:
				continue
			var right_candidate: Dictionary = vertex_candidates[right_vertex]
			if not _base_layout_repack_candidate_geometry_conflicts(left_candidate, right_candidate):
				_base_layout_repack_clique_mask_add(neighbors, right_vertex)
		adjacency[left_vertex] = neighbors
	var active := PackedInt64Array()
	active.resize(word_count)
	for vertex_index in range(vertex_count):
		_base_layout_repack_clique_mask_add(active, vertex_index)
	return {
		"object_ids": object_ids,
		"object_vertices": object_vertices,
		"vertex_objects": vertex_objects,
		"vertex_candidates": vertex_candidates,
		"adjacency": adjacency,
		"active": active,
	}


static func _base_layout_repack_prune_compatibility_equivalent_candidates(candidate_domains: Dictionary, graph: Dictionary) -> void:
	var active: PackedInt64Array = graph.get("active", PackedInt64Array())
	var adjacency: Array = graph.get("adjacency", [])
	var object_vertices: Dictionary = graph.get("object_vertices", {})
	var object_ids: Array = graph.get("object_ids", [])
	for object_id_value in object_ids:
		var object_id := str(object_id_value)
		var signatures: Dictionary = {}
		var vertices: PackedInt32Array = object_vertices.get(object_id, PackedInt32Array())
		for vertex_value in vertices:
			var vertex_index := int(vertex_value)
			if not _base_layout_repack_clique_mask_has(active, vertex_index):
				continue
			var neighbors: PackedInt64Array = adjacency[vertex_index]
			var signature_parts := PackedStringArray()
			for word_index in range(active.size()):
				signature_parts.append("%016x" % (int(neighbors[word_index]) & int(active[word_index])))
			var signature := ":".join(signature_parts)
			if signatures.has(signature):
				_base_layout_repack_clique_mask_remove(active, vertex_index)
				continue
			signatures[signature] = true
	graph["active"] = active
	_base_layout_repack_apply_compatibility_active(candidate_domains, graph)


static func _base_layout_repack_prune_order_dominated_candidates(candidate_domains: Dictionary, graph: Dictionary) -> void:
	var active: PackedInt64Array = graph.get("active", PackedInt64Array())
	var adjacency: Array = graph.get("adjacency", [])
	var object_vertices: Dictionary = graph.get("object_vertices", {})
	var object_ids: Array = graph.get("object_ids", [])
	for object_id_value in object_ids:
		var object_id := str(object_id_value)
		var retained := PackedInt32Array()
		var vertices: PackedInt32Array = object_vertices.get(object_id, PackedInt32Array())
		for vertex_value in vertices:
			var vertex_index := int(vertex_value)
			if not _base_layout_repack_clique_mask_has(active, vertex_index):
				continue
			var dominated := false
			var later_neighbors: PackedInt64Array = adjacency[vertex_index]
			for earlier_value in retained:
				var earlier_neighbors: PackedInt64Array = adjacency[int(earlier_value)]
				if _base_layout_repack_compatibility_subset(later_neighbors, earlier_neighbors, active):
					dominated = true
					break
			if dominated:
				_base_layout_repack_clique_mask_remove(active, vertex_index)
			else:
				retained.append(vertex_index)
	graph["active"] = active
	_base_layout_repack_apply_compatibility_active(candidate_domains, graph)


static func _base_layout_repack_compatibility_subset(later: PackedInt64Array, earlier: PackedInt64Array, active: PackedInt64Array) -> bool:
	for word_index in range(active.size()):
		var later_supported := int(later[word_index]) & int(active[word_index])
		var earlier_supported := int(earlier[word_index]) & int(active[word_index])
		if (later_supported & ~earlier_supported) != 0:
			return false
	return true


static func _base_layout_repack_apply_compatibility_active(candidate_domains: Dictionary, graph: Dictionary) -> void:
	var active: PackedInt64Array = graph.get("active", PackedInt64Array())
	var object_vertices: Dictionary = graph.get("object_vertices", {})
	var vertex_candidates: Array = graph.get("vertex_candidates", [])
	var object_ids: Array = graph.get("object_ids", [])
	for object_id_value in object_ids:
		var object_id := str(object_id_value)
		var candidates: Array = []
		var vertices: PackedInt32Array = object_vertices.get(object_id, PackedInt32Array())
		for vertex_value in vertices:
			var vertex_index := int(vertex_value)
			if _base_layout_repack_clique_mask_has(active, vertex_index):
				candidates.append(vertex_candidates[vertex_index])
		candidate_domains[object_id] = candidates


static func _base_layout_conflicting_expanded_ids(expanded_rects: Dictionary, expanded: Rect2) -> Array:
	var result: Array = []
	var object_ids := expanded_rects.keys()
	object_ids.sort()
	for object_id_value in object_ids:
		var object_id := str(object_id_value)
		var existing_expanded := _rect_from_dict(expanded_rects.get(object_id, {}))
		if expanded.has_area() and existing_expanded.has_area() and expanded.intersects(existing_expanded) \
				and expanded.intersection(existing_expanded).get_area() > 0.000001:
			result.append(object_id)
	return result


static func _base_layout_repack_candidate_collides(placed_rects: Dictionary, expanded_rects: Dictionary, candidate: Dictionary) -> bool:
	var rect: Rect2 = candidate.get("rect", Rect2())
	if not rect.has_area() or _object_rect_direct_collides_with_any(placed_rects, rect):
		return true
	var expanded: Rect2 = candidate.get("expanded_rect", Rect2())
	return not expanded.has_area() or _object_rect_direct_collides_with_any(expanded_rects, expanded)


static func _cached_base_layout_repack_candidates(record: Dictionary, environment_data: Dictionary, candidate_cache: Dictionary, tier_limit: int = BASE_REPACK_CANDIDATE_TIER_FINE) -> Array:
	var object_id := str(record.get("object_id", ""))
	var requested_tier := clampi(
		tier_limit,
		BASE_REPACK_CANDIDATE_TIER_PREFERRED,
		BASE_REPACK_CANDIDATE_TIER_FINE
	)
	var cached_value: Variant = candidate_cache.get(object_id, {})
	var cached: Dictionary = cached_value if typeof(cached_value) == TYPE_DICTIONARY else {}
	if cached.is_empty() or int(cached.get("max_tier", -1)) < requested_tier:
		# Rebuild on upgrade rather than appending. Fine candidates can duplicate
		# supported geometry, and the canonical full sort/ordinals must remain
		# byte-identical to a cold full-domain enumeration.
		cached = {
			"max_tier": requested_tier,
			"candidates": _base_layout_repack_candidates(record, environment_data, requested_tier),
		}
		candidate_cache[object_id] = cached
	var candidates_value: Variant = cached.get("candidates", [])
	if typeof(candidates_value) != TYPE_ARRAY:
		return []
	var result: Array = candidates_value
	return result


static func _base_layout_repack_candidates_for_tier(candidates: Array, tier_limit: int) -> Array:
	if tier_limit >= BASE_REPACK_CANDIDATE_TIER_FINE:
		return candidates
	var result: Array = []
	for candidate_value in candidates:
		var candidate: Dictionary = candidate_value
		if int(candidate.get("tier", BASE_REPACK_CANDIDATE_TIER_FINE)) <= tier_limit:
			result.append(candidate)
	return result


static func _base_layout_repack_candidates(record: Dictionary, environment_data: Dictionary, tier_limit: int = BASE_REPACK_CANDIDATE_TIER_FINE) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	var placement_class := str(record.get("placement_class", ""))
	var anchor: Rect2 = record.get("anchor_rect", Rect2())
	var current_normalized: Rect2 = record.get("current_rect", Rect2())
	var current_pixel := Rect2(current_normalized.position * ENVIRONMENT_BOARD_SIZE, current_normalized.size * ENVIRONMENT_BOARD_SIZE)
	# Fixed developer geometry always retains exact first-choice authority, even
	# when it intentionally sits outside a semantic surface. Flexible persisted
	# geometry enters only when it remains class-valid under the live surface map.
	if bool(record.get("fixed", false)) or (not bool(record.get("fallback", false)) \
			and EnvironmentPlacementScript.valid_rect(environment_data, placement_class, current_pixel)):
		_append_base_layout_repack_candidate(result, seen, current_pixel, str(record.get("surface_id", "")), false, true, BASE_REPACK_CANDIDATE_TIER_PREFERRED)
	if tier_limit >= BASE_REPACK_CANDIDATE_TIER_SUPPORTED:
		for candidate_value in EnvironmentPlacementScript.supported_rect_candidates(environment_data, placement_class, anchor):
			var candidate: Dictionary = candidate_value
			_append_base_layout_repack_candidate(result, seen, candidate.get("rect", Rect2()), str(candidate.get("surface_id", "")), false, false, BASE_REPACK_CANDIDATE_TIER_SUPPORTED)
	if tier_limit >= BASE_REPACK_CANDIDATE_TIER_FINE:
		for candidate_value in EnvironmentPlacementScript.candidate_rects(environment_data, placement_class, anchor, Rect2(), true):
			var candidate: Dictionary = candidate_value
			_append_base_layout_repack_candidate(result, seen, candidate.get("rect", Rect2()), str(candidate.get("surface_id", "")), false, false, BASE_REPACK_CANDIDATE_TIER_FINE)
	var anchor_center := anchor.get_center()
	result.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		return _sort_base_layout_repack_candidate(left_value, right_value, anchor_center)
	)
	for candidate_index in range(result.size()):
		var indexed_candidate := JsonCoerceScript._copy_dict(result[candidate_index])
		indexed_candidate["ordinal"] = candidate_index
		result[candidate_index] = indexed_candidate
	return result


static func _append_base_layout_repack_candidate(result: Array, seen: Dictionary, pixel_rect: Rect2, surface_id: String, fallback: bool, preferred: bool, tier: int) -> void:
	if not pixel_rect.has_area():
		return
	var key := "%.3f:%.3f:%.3f:%.3f" % [pixel_rect.position.x, pixel_rect.position.y, pixel_rect.size.x, pixel_rect.size.y]
	if seen.has(key):
		var existing_index := int(seen.get(key, -1))
		if existing_index >= 0:
			var existing := JsonCoerceScript._copy_dict(result[existing_index])
			existing["preferred"] = bool(existing.get("preferred", false)) or preferred
			existing["tier"] = mini(int(existing.get("tier", BASE_REPACK_CANDIDATE_TIER_FINE)), tier)
			# A semantic support at the same geometry supersedes generic-grid
			# provenance; never let candidate de-duplication turn it into fallback.
			if bool(existing.get("fallback", false)) and not fallback:
				existing["fallback"] = false
				existing["surface_id"] = surface_id
			result[existing_index] = existing
		return
	seen[key] = result.size()
	var normalized_rect := Rect2(pixel_rect.position / ENVIRONMENT_BOARD_SIZE, pixel_rect.size / ENVIRONMENT_BOARD_SIZE)
	result.append({
		"rect": normalized_rect,
		"expanded_rect": _expanded_object_rect(normalized_rect),
		"surface_id": surface_id,
		"fallback": fallback,
		"preferred": preferred,
		"tier": tier,
		"key": key,
		"pixel_center": pixel_rect.get_center(),
	})


static func _sort_base_layout_repack_candidate(left_value: Variant, right_value: Variant, anchor_center: Vector2) -> bool:
	var left: Dictionary = left_value
	var right: Dictionary = right_value
	var left_preferred := bool(left.get("preferred", false))
	var right_preferred := bool(right.get("preferred", false))
	if left_preferred != right_preferred:
		return left_preferred
	var left_fallback := bool(left.get("fallback", false))
	var right_fallback := bool(right.get("fallback", false))
	if left_fallback != right_fallback:
		return not left_fallback
	var left_center: Vector2 = left.get("pixel_center", Vector2.ZERO)
	var right_center: Vector2 = right.get("pixel_center", Vector2.ZERO)
	var left_distance := left_center.distance_squared_to(anchor_center)
	var right_distance := right_center.distance_squared_to(anchor_center)
	if left_distance != right_distance:
		return left_distance < right_distance
	return str(left.get("key", "")) < str(right.get("key", ""))


static func _solve_base_layout_repack_clique(candidate_domains: Dictionary, priority_object_id: String, prepared_graph: Dictionary = {}) -> Dictionary:
	# Equivalence and dominance pruning already built this exact compatibility
	# graph. Keep its original vertex indices and active mask instead of rebuilding
	# the same O(V^2) geometry relation for the retained candidates.
	var graph := prepared_graph if not prepared_graph.is_empty() else _base_layout_repack_candidate_compatibility_graph(candidate_domains)
	var object_ids: Array = graph.get("object_ids", [])
	if object_ids.is_empty():
		return {"ok": true, "placements": {}}
	var object_vertices_by_id: Dictionary = graph.get("object_vertices", {})
	var object_vertices: Array = []
	var vertex_objects: PackedInt32Array = graph.get("vertex_objects", PackedInt32Array())
	var vertex_candidate_values: Array = graph.get("vertex_candidates", [])
	var adjacency: Array = graph.get("adjacency", [])
	var active_vertices: PackedInt64Array = graph.get("active", PackedInt64Array()).duplicate()
	var priority_index := -1
	for object_index in range(object_ids.size()):
		var object_id := str(object_ids[object_index])
		var vertices: PackedInt32Array = object_vertices_by_id.get(object_id, PackedInt32Array())
		if _base_layout_repack_clique_object_candidate_count(active_vertices, vertices) <= 0:
			return {"ok": false}
		object_vertices.append(vertices)
		if object_id == priority_object_id:
			priority_index = object_index
	var vertex_count := vertex_objects.size()
	var active_vertex_count := _base_layout_repack_clique_mask_count(active_vertices)
	if vertex_count != vertex_candidate_values.size() or vertex_count != adjacency.size() or active_vertices.is_empty():
		return {"ok": false}
	var word_count := active_vertices.size()
	var color_rank_values: Array = []
	var vertex_degrees := PackedInt32Array()
	vertex_degrees.resize(vertex_count)
	for vertex_index in range(vertex_count):
		if not _base_layout_repack_clique_mask_has(active_vertices, vertex_index):
			continue
		color_rank_values.append(vertex_index)
		var neighbors: PackedInt64Array = adjacency[vertex_index]
		vertex_degrees[vertex_index] = _base_layout_repack_clique_masks_intersection_count(neighbors, active_vertices)
	color_rank_values.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left_vertex := int(left_value)
		var right_vertex := int(right_value)
		var left_degree := int(vertex_degrees[left_vertex])
		var right_degree := int(vertex_degrees[right_vertex])
		return left_degree > right_degree if left_degree != right_degree else left_vertex < right_vertex
	)
	var color_rank := PackedInt32Array()
	for vertex_value in color_rank_values:
		color_rank.append(int(vertex_value))
	# Degree-first coloring is a strong bound for ordinary conflict graphs, but
	# equal-degree slot domains can be encountered object-major and color by
	# object instead of by physical capacity.  A second geometry-major order
	# groups equivalent occupied space, exposing Hall deficits without changing
	# authored candidate/output order.
	var geometry_color_rank := _base_layout_repack_clique_geometry_rank(
		vertex_candidate_values,
		vertex_objects
	)
	var color_ranks: Array = [color_rank, geometry_color_rank]
	var object_vertex_masks := _base_layout_repack_clique_object_masks(
		vertex_objects,
		object_ids.size(),
		word_count
	)
	var search_stats := {
		"calls": 0,
		"color_rejections": 0,
		"matching_rejections": 0,
		"memo_hits": 0,
		"arc_passes": 0,
		"arc_removals": 0,
		"arc_rejections": 0,
		"partition_branches": 0,
	}
	var feasibility_memo: Dictionary = {}
	var assignments := PackedInt32Array()
	assignments.resize(object_ids.size())
	assignments.fill(-1)
	var remaining := object_ids.size()
	# A dense root contains every candidate from every partition; scanning all of
	# it cannot establish an authored choice and can dominate the solve. Exact AC
	# still runs as soon as each authored priority candidate restricts the graph.
	if active_vertex_count <= BASE_REPACK_CLIQUE_ROOT_ARC_VERTEX_LIMIT:
		active_vertices = _base_layout_repack_clique_arc_consistency(
			active_vertices,
			adjacency,
			vertex_objects,
			object_ids.size(),
			object_vertex_masks,
			remaining,
			search_stats
		)
	if _base_layout_repack_clique_distinct_object_count(active_vertices, vertex_objects, object_ids.size()) != remaining:
		return {"ok": false}
	# Apply cheap safe bounds to the complete graph before authored-order
	# self-reduction.  This rejects capacity-impossible cohorts once at the root.
	if _base_layout_repack_clique_mask_count(active_vertices) <= BASE_REPACK_CLIQUE_COLOR_BOUND_VERTEX_LIMIT \
			and not _base_layout_repack_clique_bounds_allow(
		active_vertices,
		remaining,
		adjacency,
		vertex_objects,
		object_ids.size(),
		color_ranks,
		search_stats
	):
		return {"ok": false}
	# Large dense graphs need one global feasibility decision before deterministic
	# self-reduction. Otherwise an UNSAT room repeats the same proof for every
	# authored priority candidate even though no candidate can possibly extend.
	if active_vertex_count > BASE_REPACK_CLIQUE_ROOT_EXACT_VERTEX_THRESHOLD \
			and not _base_layout_repack_clique_can_complete(
		active_vertices,
		remaining,
		adjacency,
		vertex_objects,
		object_ids.size(),
		object_vertex_masks,
		color_ranks,
		search_stats,
		feasibility_memo
	):
		return {"ok": false}
	if priority_index >= 0:
		var priority_selected := false
		var priority_vertices: PackedInt32Array = object_vertices[priority_index]
		for priority_vertex in priority_vertices:
			if not _base_layout_repack_clique_mask_has(active_vertices, priority_vertex):
				continue
			var next_active := _base_layout_repack_clique_mask_intersection(
				active_vertices,
				adjacency[priority_vertex]
			)
			var can_complete := _base_layout_repack_clique_can_complete(
				next_active,
				remaining - 1,
				adjacency,
				vertex_objects,
				object_ids.size(),
				object_vertex_masks,
				color_ranks,
				search_stats,
				feasibility_memo
			)
			if not can_complete:
				continue
			if remaining - 1 > 1:
				next_active = _base_layout_repack_clique_arc_consistency(
					next_active,
					adjacency,
					vertex_objects,
					object_ids.size(),
					object_vertex_masks,
					remaining - 1,
					search_stats
				)
			assignments[priority_index] = priority_vertex
			active_vertices = next_active
			remaining -= 1
			priority_selected = true
			break
		if not priority_selected:
			return {"ok": false}
	while remaining > 0:
		var object_index := -1
		var smallest_domain_size := 2147483647
		for candidate_object_index in range(object_ids.size()):
			if int(assignments[candidate_object_index]) >= 0:
				continue
			var live_count := _base_layout_repack_clique_object_candidate_count(
				active_vertices,
				object_vertices[candidate_object_index]
			)
			if live_count <= 0:
				return {"ok": false}
			if live_count < smallest_domain_size:
				object_index = candidate_object_index
				smallest_domain_size = live_count
		if object_index < 0:
			return {"ok": false}
		var selected := false
		var candidates_for_object: PackedInt32Array = object_vertices[object_index]
		for candidate_vertex in candidates_for_object:
			if not _base_layout_repack_clique_mask_has(active_vertices, candidate_vertex):
				continue
			var next_active := _base_layout_repack_clique_mask_intersection(
				active_vertices,
				adjacency[candidate_vertex]
			)
			if not _base_layout_repack_clique_can_complete(
				next_active,
				remaining - 1,
				adjacency,
				vertex_objects,
				object_ids.size(),
				object_vertex_masks,
				color_ranks,
				search_stats,
				feasibility_memo
			):
				continue
			if remaining - 1 > 1:
				next_active = _base_layout_repack_clique_arc_consistency(
					next_active,
					adjacency,
					vertex_objects,
					object_ids.size(),
					object_vertex_masks,
					remaining - 1,
					search_stats
				)
			assignments[object_index] = candidate_vertex
			active_vertices = next_active
			remaining -= 1
			selected = true
			break
		if not selected:
			return {"ok": false}
	var placements: Dictionary = {}
	for object_index in range(object_ids.size()):
		var vertex_index := int(assignments[object_index])
		if vertex_index < 0 or vertex_index >= vertex_candidate_values.size():
			return {"ok": false}
		placements[str(object_ids[object_index])] = vertex_candidate_values[vertex_index]
	return {"ok": true, "placements": placements}


static func _base_layout_repack_clique_can_complete(candidates: PackedInt64Array, need: int, adjacency: Array, vertex_objects: PackedInt32Array, object_count: int, object_vertex_masks: Array, color_ranks: Array, stats: Dictionary, feasibility_memo: Dictionary, allow_expensive_reduction: bool = true) -> bool:
	stats["calls"] = int(stats.get("calls", 0)) + 1
	if need <= 0:
		return true
	var candidate_count := _base_layout_repack_clique_mask_count(candidates)
	if candidate_count < need:
		return false
	var distinct_object_count := _base_layout_repack_clique_distinct_object_count(candidates, vertex_objects, object_count)
	if distinct_object_count != need:
		return false
	if need == 1:
		return true
	candidates = _base_layout_repack_clique_arc_consistency(
		candidates,
		adjacency,
		vertex_objects,
		object_count,
		object_vertex_masks,
		need,
		stats
	)
	candidate_count = _base_layout_repack_clique_mask_count(candidates)
	if candidate_count < need \
			or _base_layout_repack_clique_distinct_object_count(candidates, vertex_objects, object_count) != need:
		return false
	# Reject globally capacity-impossible states before the more expensive active
	# dominance reduction. This is decisive for dense strict-tier failures.
	if candidate_count > BASE_REPACK_CLIQUE_EXPENSIVE_REDUCTION_VERTEX_THRESHOLD \
			and not _base_layout_repack_clique_bounds_allow(
		candidates,
		need,
		adjacency,
		vertex_objects,
		object_count,
		color_ranks,
		stats
	):
		return false
	if allow_expensive_reduction and candidate_count > BASE_REPACK_CLIQUE_EXPENSIVE_REDUCTION_VERTEX_THRESHOLD:
		for _dominance_pass in range(8):
			var previous_count := _base_layout_repack_clique_mask_count(candidates)
			candidates = _base_layout_repack_clique_prune_active_dominated(
				candidates,
				adjacency,
				vertex_objects,
				object_count,
				stats
			)
			candidates = _base_layout_repack_clique_arc_consistency(
				candidates,
				adjacency,
				vertex_objects,
				object_count,
				object_vertex_masks,
				need,
				stats
			)
			if _base_layout_repack_clique_mask_count(candidates) == previous_count:
				break
		candidate_count = _base_layout_repack_clique_mask_count(candidates)
		if candidate_count < need \
				or _base_layout_repack_clique_distinct_object_count(candidates, vertex_objects, object_count) != need:
			return false
	var memo_key := _base_layout_repack_clique_memo_key(candidates, need)
	if feasibility_memo.has(memo_key):
		stats["memo_hits"] = int(stats.get("memo_hits", 0)) + 1
		return bool(feasibility_memo.get(memo_key, false))
	if not _base_layout_repack_clique_bounds_allow(
		candidates,
		need,
		adjacency,
		vertex_objects,
		object_count,
		color_ranks,
		stats
	):
		if feasibility_memo.size() < BASE_REPACK_CLIQUE_MEMO_LIMIT:
			feasibility_memo[memo_key] = false
		return false
	if allow_expensive_reduction and candidate_count > BASE_REPACK_CLIQUE_EXPENSIVE_REDUCTION_VERTEX_THRESHOLD:
		var witness_state := {"nodes": 0, "aborted": false}
		if _base_layout_repack_clique_find_witness_bounded(
			candidates,
			need,
			adjacency,
			vertex_objects,
			object_count,
			object_vertex_masks,
			witness_state,
			BASE_REPACK_CLIQUE_WITNESS_NODE_LIMIT
		):
			stats["witness_nodes"] = int(stats.get("witness_nodes", 0)) + int(witness_state.get("nodes", 0))
			stats["witness_successes"] = int(stats.get("witness_successes", 0)) + 1
			return true
		stats["witness_nodes"] = int(stats.get("witness_nodes", 0)) + int(witness_state.get("nodes", 0))
		if not bool(witness_state.get("aborted", false)):
			stats["witness_rejections"] = int(stats.get("witness_rejections", 0)) + 1
			if feasibility_memo.size() < BASE_REPACK_CLIQUE_MEMO_LIMIT:
				feasibility_memo[memo_key] = false
			return false
		stats["witness_aborts"] = int(stats.get("witness_aborts", 0)) + 1
	# This graph is partitioned by object and every valid result contains exactly
	# one vertex from every represented partition. Branching on the smallest live
	# partition is therefore complete, avoids exploring alternate vertex-order
	# permutations of the same placement set, and retains the outer authored-order
	# self-reduction that chooses the returned placements.
	var branch_object := -1
	var branch_size := 2147483647
	for object_index in range(object_count):
		var object_mask: PackedInt64Array = object_vertex_masks[object_index]
		var live_mask := _base_layout_repack_clique_mask_intersection(candidates, object_mask)
		var live_count := _base_layout_repack_clique_mask_count(live_mask)
		if live_count > 0 and live_count < branch_size:
			branch_object = object_index
			branch_size = live_count
	if branch_object < 0:
		if feasibility_memo.size() < BASE_REPACK_CLIQUE_MEMO_LIMIT:
			feasibility_memo[memo_key] = false
		return false
	for vertex_index in range(vertex_objects.size()):
		if int(vertex_objects[vertex_index]) != branch_object \
				or not _base_layout_repack_clique_mask_has(candidates, vertex_index):
			continue
		stats["partition_branches"] = int(stats.get("partition_branches", 0)) + 1
		var next_candidates := _base_layout_repack_clique_mask_intersection(
			candidates,
			adjacency[vertex_index]
		)
		if _base_layout_repack_clique_can_complete(
			next_candidates,
			need - 1,
			adjacency,
			vertex_objects,
			object_count,
			object_vertex_masks,
			color_ranks,
			stats,
			feasibility_memo,
			false
		):
			if feasibility_memo.size() < BASE_REPACK_CLIQUE_MEMO_LIMIT:
				feasibility_memo[memo_key] = true
			return true
	if feasibility_memo.size() < BASE_REPACK_CLIQUE_MEMO_LIMIT:
		feasibility_memo[memo_key] = false
	return false


static func _base_layout_repack_clique_prune_active_dominated(candidates: PackedInt64Array, adjacency: Array, vertex_objects: PackedInt32Array, object_count: int, stats: Dictionary) -> PackedInt64Array:
	var reduced := candidates.duplicate()
	var removals := 0
	for object_index in range(object_count):
		var retained := PackedInt32Array()
		for vertex_index in range(vertex_objects.size()):
			if int(vertex_objects[vertex_index]) != object_index \
					or not _base_layout_repack_clique_mask_has(reduced, vertex_index):
				continue
			var candidate_neighbors: PackedInt64Array = adjacency[vertex_index]
			var dominated := false
			for retained_vertex in retained:
				var retained_neighbors: PackedInt64Array = adjacency[int(retained_vertex)]
				if _base_layout_repack_compatibility_subset(
					candidate_neighbors,
					retained_neighbors,
					reduced
				):
					dominated = true
					break
			if dominated:
				_base_layout_repack_clique_mask_remove(reduced, vertex_index)
				removals += 1
			else:
				for retained_index in range(retained.size() - 1, -1, -1):
					var retained_vertex := int(retained[retained_index])
					var retained_neighbors: PackedInt64Array = adjacency[retained_vertex]
					if _base_layout_repack_compatibility_subset(
						retained_neighbors,
						candidate_neighbors,
						reduced
					):
						_base_layout_repack_clique_mask_remove(reduced, retained_vertex)
						retained.remove_at(retained_index)
						removals += 1
				retained.append(vertex_index)
	stats["active_dominance_removals"] = int(stats.get("active_dominance_removals", 0)) + removals
	return reduced


static func _base_layout_repack_clique_find_witness_bounded(candidates: PackedInt64Array, need: int, adjacency: Array, vertex_objects: PackedInt32Array, object_count: int, object_vertex_masks: Array, state: Dictionary, node_limit: int) -> bool:
	state["nodes"] = int(state.get("nodes", 0)) + 1
	if int(state.get("nodes", 0)) > node_limit:
		state["aborted"] = true
		return false
	if need <= 0:
		return true
	if _base_layout_repack_clique_mask_count(candidates) < need \
			or _base_layout_repack_clique_distinct_object_count(candidates, vertex_objects, object_count) != need:
		return false
	if need == 1:
		return true
	var branch_object := -1
	var branch_mask := PackedInt64Array()
	var branch_size := 2147483647
	for object_index in range(object_count):
		var live_mask := _base_layout_repack_clique_mask_intersection(
			candidates,
			object_vertex_masks[object_index]
		)
		var live_count := _base_layout_repack_clique_mask_count(live_mask)
		if live_count > 0 and live_count < branch_size:
			branch_object = object_index
			branch_mask = live_mask
			branch_size = live_count
	if branch_object < 0:
		return false
	var ranked_vertices: Array = []
	for vertex_index in range(vertex_objects.size()):
		if not _base_layout_repack_clique_mask_has(branch_mask, vertex_index):
			continue
		var next_candidates := _base_layout_repack_clique_mask_intersection(
			candidates,
			adjacency[vertex_index]
		)
		var represented_objects := 0
		var minimum_support := 2147483647
		var total_support := 0
		for object_index in range(object_count):
			var support_count := _base_layout_repack_clique_masks_intersection_count(
				next_candidates,
				object_vertex_masks[object_index]
			)
			if support_count <= 0:
				continue
			represented_objects += 1
			minimum_support = mini(minimum_support, support_count)
			total_support += support_count
		if represented_objects != need - 1:
			continue
		ranked_vertices.append({
			"vertex": vertex_index,
			"next": next_candidates,
			"minimum_support": minimum_support,
			"total_support": total_support,
		})
	ranked_vertices.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left: Dictionary = left_value
		var right: Dictionary = right_value
		var left_minimum := int(left.get("minimum_support", 0))
		var right_minimum := int(right.get("minimum_support", 0))
		if left_minimum != right_minimum:
			return left_minimum > right_minimum
		var left_total := int(left.get("total_support", 0))
		var right_total := int(right.get("total_support", 0))
		return left_total > right_total if left_total != right_total else int(left.get("vertex", 0)) < int(right.get("vertex", 0))
	)
	for ranked_value in ranked_vertices:
		if bool(state.get("aborted", false)):
			return false
		var ranked: Dictionary = ranked_value
		var next_candidates: PackedInt64Array = ranked.get("next", PackedInt64Array())
		if _base_layout_repack_clique_find_witness_bounded(
			next_candidates,
			need - 1,
			adjacency,
			vertex_objects,
			object_count,
			object_vertex_masks,
			state,
			node_limit
		):
			return true
	return false


static func _base_layout_repack_clique_arc_consistency(candidates: PackedInt64Array, adjacency: Array, vertex_objects: PackedInt32Array, object_count: int, object_vertex_masks: Array, need: int, stats: Dictionary) -> PackedInt64Array:
	var reduced := candidates.duplicate()
	if need <= 1:
		return reduced
	while true:
		var object_masks: Array = []
		var object_live_counts := PackedInt32Array()
		object_live_counts.resize(object_count)
		var represented_objects := 0
		for object_index in range(object_count):
			var object_mask := _base_layout_repack_clique_mask_intersection(
				reduced,
				object_vertex_masks[object_index]
			)
			object_masks.append(object_mask)
			var live_count := _base_layout_repack_clique_mask_count(object_mask)
			object_live_counts[object_index] = live_count
			if live_count > 0:
				represented_objects += 1
		if represented_objects != need:
			stats["arc_rejections"] = int(stats.get("arc_rejections", 0)) + 1
			return reduced
		var removals := PackedInt32Array()
		for vertex_index in range(vertex_objects.size()):
			if not _base_layout_repack_clique_mask_has(reduced, vertex_index):
				continue
			var vertex_object := int(vertex_objects[vertex_index])
			var neighbors: PackedInt64Array = adjacency[vertex_index]
			for other_object in range(object_count):
				if other_object == vertex_object or int(object_live_counts[other_object]) <= 0:
					continue
				if not _base_layout_repack_clique_masks_intersect(neighbors, object_masks[other_object]):
					removals.append(vertex_index)
					break
		stats["arc_passes"] = int(stats.get("arc_passes", 0)) + 1
		if removals.is_empty():
			return reduced
		stats["arc_removals"] = int(stats.get("arc_removals", 0)) + removals.size()
		for removed_vertex in removals:
			_base_layout_repack_clique_mask_remove(reduced, int(removed_vertex))
	return reduced


static func _base_layout_repack_clique_masks_intersection_count(left: PackedInt64Array, right: PackedInt64Array) -> int:
	var result := 0
	for word_index in range(left.size()):
		var value := int(left[word_index]) & int(right[word_index])
		while value != 0:
			value = value & (value - 1)
			result += 1
	return result


static func _base_layout_repack_clique_bounds_allow(candidates: PackedInt64Array, need: int, adjacency: Array, vertex_objects: PackedInt32Array, object_count: int, color_ranks: Array, stats: Dictionary) -> bool:
	for rank_value in color_ranks:
		var color_rank: PackedInt32Array = rank_value
		var color_data := _base_layout_repack_clique_color_sort(candidates, adjacency, color_rank)
		var ordered_vertices: PackedInt32Array = color_data[0]
		var color_bounds: PackedInt32Array = color_data[1]
		if color_bounds.is_empty():
			return need <= 0
		var color_count := int(color_bounds[color_bounds.size() - 1])
		var matching_count := _base_layout_repack_clique_color_matching_bound(
			ordered_vertices,
			color_bounds,
			vertex_objects,
			object_count,
			color_count
		)
		var color_rejected := color_count < need
		var matching_rejected := matching_count < need
		if color_rejected:
			stats["color_rejections"] = int(stats.get("color_rejections", 0)) + 1
		if matching_rejected:
			stats["matching_rejections"] = int(stats.get("matching_rejections", 0)) + 1
		if color_rejected or matching_rejected:
			return false
	return true


static func _base_layout_repack_clique_geometry_rank(vertex_candidate_values: Array, vertex_objects: PackedInt32Array) -> PackedInt32Array:
	var rank_values: Array = []
	for vertex_index in range(vertex_candidate_values.size()):
		rank_values.append(vertex_index)
	rank_values.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left_vertex := int(left_value)
		var right_vertex := int(right_value)
		var left: Dictionary = vertex_candidate_values[left_vertex]
		var right: Dictionary = vertex_candidate_values[right_vertex]
		var left_rect: Rect2 = left.get("rect", Rect2())
		var right_rect: Rect2 = right.get("rect", Rect2())
		for component in [
			[left_rect.position.x, right_rect.position.x],
			[left_rect.position.y, right_rect.position.y],
			[left_rect.size.x, right_rect.size.x],
			[left_rect.size.y, right_rect.size.y],
		]:
			if float(component[0]) != float(component[1]):
				return float(component[0]) < float(component[1])
		var left_expanded: Rect2 = left.get("expanded_rect", left_rect)
		var right_expanded: Rect2 = right.get("expanded_rect", right_rect)
		for component in [
			[left_expanded.position.x, right_expanded.position.x],
			[left_expanded.position.y, right_expanded.position.y],
			[left_expanded.size.x, right_expanded.size.x],
			[left_expanded.size.y, right_expanded.size.y],
		]:
			if float(component[0]) != float(component[1]):
				return float(component[0]) < float(component[1])
		var left_key := str(left.get("key", ""))
		var right_key := str(right.get("key", ""))
		if left_key != right_key:
			return left_key < right_key
		var left_object := int(vertex_objects[left_vertex])
		var right_object := int(vertex_objects[right_vertex])
		return left_object < right_object if left_object != right_object else left_vertex < right_vertex
	)
	var result := PackedInt32Array()
	for vertex_value in rank_values:
		result.append(int(vertex_value))
	return result


static func _base_layout_repack_clique_color_sort(candidates: PackedInt64Array, adjacency: Array, color_rank: PackedInt32Array) -> Array:
	var uncolored := candidates.duplicate()
	var ordered_vertices := PackedInt32Array()
	var color_bounds := PackedInt32Array()
	var color := 0
	while not _base_layout_repack_clique_mask_is_empty(uncolored):
		color += 1
		var available := uncolored.duplicate()
		for vertex_index in color_rank:
			if not _base_layout_repack_clique_mask_has(available, vertex_index):
				continue
			ordered_vertices.append(vertex_index)
			color_bounds.append(color)
			_base_layout_repack_clique_mask_remove(uncolored, vertex_index)
			_base_layout_repack_clique_mask_remove(available, vertex_index)
			var neighbors: PackedInt64Array = adjacency[vertex_index]
			for word_index in range(available.size()):
				available[word_index] = int(available[word_index]) & ~int(neighbors[word_index])
	return [ordered_vertices, color_bounds]


static func _base_layout_repack_clique_color_matching_bound(ordered_vertices: PackedInt32Array, color_bounds: PackedInt32Array, vertex_objects: PackedInt32Array, object_count: int, color_count: int) -> int:
	var object_colors: Array = []
	var color_option_counts := PackedInt32Array()
	color_option_counts.resize(object_count)
	for object_index in range(object_count):
		var colors := PackedByteArray()
		colors.resize(color_count + 1)
		object_colors.append(colors)
	for ordered_index in range(ordered_vertices.size()):
		var vertex_index := int(ordered_vertices[ordered_index])
		var object_index := int(vertex_objects[vertex_index])
		var color := int(color_bounds[ordered_index])
		var colors: PackedByteArray = object_colors[object_index]
		if int(colors[color]) != 0:
			continue
		colors[color] = 1
		object_colors[object_index] = colors
		color_option_counts[object_index] += 1
	var object_order: Array = []
	for object_index in range(object_count):
		if int(color_option_counts[object_index]) > 0:
			object_order.append(object_index)
	object_order.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left_object := int(left_value)
		var right_object := int(right_value)
		var left_count := int(color_option_counts[left_object])
		var right_count := int(color_option_counts[right_object])
		return left_count < right_count if left_count != right_count else left_object < right_object
	)
	var matched_object_by_color := PackedInt32Array()
	matched_object_by_color.resize(color_count + 1)
	matched_object_by_color.fill(-1)
	var matching_size := 0
	for object_value in object_order:
		var visited_colors := PackedByteArray()
		visited_colors.resize(color_count + 1)
		if _base_layout_repack_clique_augment_color_matching(
			int(object_value),
			object_colors,
			matched_object_by_color,
			visited_colors
		):
			matching_size += 1
	return matching_size


static func _base_layout_repack_clique_augment_color_matching(object_index: int, object_colors: Array, matched_object_by_color: PackedInt32Array, visited_colors: PackedByteArray) -> bool:
	var colors: PackedByteArray = object_colors[object_index]
	for color in range(1, colors.size()):
		if int(colors[color]) == 0 or int(visited_colors[color]) != 0:
			continue
		visited_colors[color] = 1
		var previous_object := int(matched_object_by_color[color])
		if previous_object < 0 or _base_layout_repack_clique_augment_color_matching(
			previous_object,
			object_colors,
			matched_object_by_color,
			visited_colors
		):
			matched_object_by_color[color] = object_index
			return true
	return false


static func _base_layout_repack_clique_object_candidate_count(candidates: PackedInt64Array, object_candidate_vertices: PackedInt32Array) -> int:
	var result := 0
	for vertex_index in object_candidate_vertices:
		if _base_layout_repack_clique_mask_has(candidates, vertex_index):
			result += 1
	return result


static func _base_layout_repack_clique_object_masks(vertex_objects: PackedInt32Array, object_count: int, word_count: int) -> Array:
	var result: Array = []
	for object_index in range(object_count):
		var object_mask := PackedInt64Array()
		object_mask.resize(word_count)
		result.append(object_mask)
	for vertex_index in range(vertex_objects.size()):
		var object_index := int(vertex_objects[vertex_index])
		var object_mask: PackedInt64Array = result[object_index]
		_base_layout_repack_clique_mask_add(object_mask, vertex_index)
		result[object_index] = object_mask
	return result


static func _base_layout_repack_clique_distinct_object_count(candidates: PackedInt64Array, vertex_objects: PackedInt32Array, object_count: int) -> int:
	var present := PackedByteArray()
	present.resize(object_count)
	var result := 0
	for vertex_index in range(vertex_objects.size()):
		if not _base_layout_repack_clique_mask_has(candidates, vertex_index):
			continue
		var object_index := int(vertex_objects[vertex_index])
		if int(present[object_index]) != 0:
			continue
		present[object_index] = 1
		result += 1
	return result


static func _base_layout_repack_clique_mask_intersection(left: PackedInt64Array, right: PackedInt64Array) -> PackedInt64Array:
	var result := PackedInt64Array()
	result.resize(left.size())
	for word_index in range(left.size()):
		result[word_index] = int(left[word_index]) & int(right[word_index])
	return result


static func _base_layout_repack_clique_masks_intersect(left: PackedInt64Array, right: PackedInt64Array) -> bool:
	for word_index in range(left.size()):
		if (int(left[word_index]) & int(right[word_index])) != 0:
			return true
	return false


static func _base_layout_repack_clique_memo_key(candidates: PackedInt64Array, need: int) -> String:
	var parts := PackedStringArray([str(need)])
	for word_value in candidates:
		parts.append("%016x" % int(word_value))
	return ":".join(parts)


static func _base_layout_repack_clique_mask_add(mask_words: PackedInt64Array, vertex_index: int) -> void:
	var word_index := int(vertex_index / BASE_REPACK_CLIQUE_WORD_BITS)
	mask_words[word_index] = int(mask_words[word_index]) | (1 << (vertex_index % BASE_REPACK_CLIQUE_WORD_BITS))


static func _base_layout_repack_clique_mask_remove(mask_words: PackedInt64Array, vertex_index: int) -> void:
	var word_index := int(vertex_index / BASE_REPACK_CLIQUE_WORD_BITS)
	mask_words[word_index] = int(mask_words[word_index]) & ~(1 << (vertex_index % BASE_REPACK_CLIQUE_WORD_BITS))


static func _base_layout_repack_clique_mask_has(mask_words: PackedInt64Array, vertex_index: int) -> bool:
	var word_index := int(vertex_index / BASE_REPACK_CLIQUE_WORD_BITS)
	return (int(mask_words[word_index]) & (1 << (vertex_index % BASE_REPACK_CLIQUE_WORD_BITS))) != 0


static func _base_layout_repack_clique_mask_is_empty(mask_words: PackedInt64Array) -> bool:
	for word_value in mask_words:
		if int(word_value) != 0:
			return false
	return true


static func _base_layout_repack_clique_mask_count(mask_words: PackedInt64Array) -> int:
	var result := 0
	for word_value in mask_words:
		var value := int(word_value)
		while value != 0:
			value = value & (value - 1)
			result += 1
	return result


static func _base_layout_repack_candidates_conflict(left_id: String, left: Dictionary, right_id: String, right: Dictionary, pair_conflict_cache: Dictionary) -> bool:
	var left_first := left_id < right_id
	var pair_key := "%s|%s" % [left_id, right_id] if left_first else "%s|%s" % [right_id, left_id]
	var left_ordinal := int(left.get("ordinal", 0))
	var right_ordinal := int(right.get("ordinal", 0))
	var state_key: int
	if left_first:
		state_key = (left_ordinal << 32) | right_ordinal
	else:
		state_key = (right_ordinal << 32) | left_ordinal
	var pair_cache: Dictionary = pair_conflict_cache.get(pair_key, {})
	if pair_cache.has(state_key):
		return bool(pair_cache.get(state_key, false))
	var conflicts := _base_layout_repack_candidate_geometry_conflicts(left, right)
	pair_cache[state_key] = conflicts
	pair_conflict_cache[pair_key] = pair_cache
	return conflicts


static func _base_layout_repack_candidate_geometry_conflicts(left: Dictionary, right: Dictionary) -> bool:
	var left_rect: Rect2 = left.get("rect", Rect2())
	var right_rect: Rect2 = right.get("rect", Rect2())
	var direct_conflict := left_rect.has_area() and right_rect.has_area() and left_rect.intersects(right_rect) \
			and left_rect.intersection(right_rect).get_area() > 0.000001
	var left_expanded: Rect2 = left.get("expanded_rect", Rect2())
	var right_expanded: Rect2 = right.get("expanded_rect", Rect2())
	var expanded_conflict := left_expanded.has_area() and right_expanded.has_area() and left_expanded.intersects(right_expanded) \
			and left_expanded.intersection(right_expanded).get_area() > 0.000001
	return direct_conflict or expanded_conflict


static func _expanded_object_rect_collides_with_any(placed_rects: Dictionary, rect: Rect2) -> bool:
	var expanded := _expanded_object_rect(rect)
	for key in placed_rects.keys():
		var existing_rect := _rect_from_dict(placed_rects.get(key, {}))
		var existing_expanded := _expanded_object_rect(existing_rect)
		if expanded.has_area() and existing_expanded.has_area() and expanded.intersects(existing_expanded) \
				and expanded.intersection(existing_expanded).get_area() > 0.000001:
			return true
	return false


static func _expanded_object_rect(rect: Rect2) -> Rect2:
	if not rect.has_area():
		return Rect2()
	var pixel_rect := Rect2(rect.position * ENVIRONMENT_BOARD_SIZE, rect.size * ENVIRONMENT_BOARD_SIZE)
	var minimum := Vector2(ArtContractsScript.ENVIRONMENT_OBJECT_HIT_SIZE)
	var size := Vector2(maxf(pixel_rect.size.x, minimum.x), maxf(pixel_rect.size.y, minimum.y))
	var position := pixel_rect.get_center() - size * 0.5
	position.x = clampf(position.x, 0.0, ENVIRONMENT_BOARD_SIZE.x - size.x)
	position.y = clampf(position.y, 0.0, ENVIRONMENT_BOARD_SIZE.y - size.y)
	return Rect2(position / ENVIRONMENT_BOARD_SIZE, size / ENVIRONMENT_BOARD_SIZE)


static func _fallback_grid_object_rects(object_type: String, index: int, desired_rect: Rect2) -> Array:
	var size := _fallback_object_rect(object_type, index).size
	var desired_center := desired_rect.position + desired_rect.size * 0.5
	var centers := [
		Vector2(0.12, 0.20),
		Vector2(0.28, 0.20),
		Vector2(0.44, 0.20),
		Vector2(0.60, 0.20),
		Vector2(0.76, 0.20),
		Vector2(0.88, 0.20),
		Vector2(0.12, 0.34),
		Vector2(0.28, 0.34),
		Vector2(0.44, 0.34),
		Vector2(0.60, 0.34),
		Vector2(0.76, 0.34),
		Vector2(0.88, 0.34),
		Vector2(0.12, 0.48),
		Vector2(0.28, 0.48),
		Vector2(0.44, 0.48),
		Vector2(0.60, 0.48),
		Vector2(0.76, 0.48),
		Vector2(0.88, 0.48),
		Vector2(0.12, 0.62),
		Vector2(0.28, 0.62),
		Vector2(0.44, 0.62),
		Vector2(0.60, 0.62),
		Vector2(0.76, 0.62),
		Vector2(0.88, 0.62),
		Vector2(0.12, 0.76),
		Vector2(0.28, 0.76),
		Vector2(0.44, 0.76),
		Vector2(0.60, 0.76),
		Vector2(0.76, 0.76),
		Vector2(0.88, 0.76),
		Vector2(0.12, 0.88),
		Vector2(0.28, 0.88),
		Vector2(0.44, 0.88),
		Vector2(0.60, 0.88),
		Vector2(0.76, 0.88),
		Vector2(0.88, 0.88),
	]
	var scored: Array = []
	for center_value in centers:
		var center: Vector2 = center_value
		var rect := _clamped_rect_from_center(center, size)
		var candidate_center := rect.position + rect.size * 0.5
		scored.append({
			"rect": rect,
			"score": desired_center.distance_squared_to(candidate_center),
		})
	scored.sort_custom(func(a: Variant, b: Variant) -> bool:
		return _sort_layout_rect_candidate(a, b)
	)
	var result: Array = []
	for entry_value in scored:
		var entry: Dictionary = entry_value
		result.append(entry.get("rect", Rect2()))
	return result


static func _sort_layout_rect_candidate(a: Variant, b: Variant) -> bool:
	var entry_a: Dictionary = a
	var entry_b: Dictionary = b
	var score_a := float(entry_a.get("score", 0.0))
	var score_b := float(entry_b.get("score", 0.0))
	if score_a == score_b:
		var rect_a: Rect2 = entry_a.get("rect", Rect2())
		var rect_b: Rect2 = entry_b.get("rect", Rect2())
		if rect_a.position.y == rect_b.position.y:
			return rect_a.position.x < rect_b.position.x
		return rect_a.position.y < rect_b.position.y
	return score_a < score_b


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


# Numbers fixtures are runtime-backed, but they are still physical room objects.
# Reserve their stable authored positions in the same generated layout as games,
# events, services, and doors so the UI never composes a second placement layer.
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


static func _active_object_ids_from_entries(entries: Array) -> Dictionary:
	var result: Dictionary = {}
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var object_id := str((entry_value as Dictionary).get("object_id", ""))
		if not object_id.is_empty():
			result[object_id] = true
	return result


static func _active_object_ids(environment_data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for entry_value in _game_layout_entries(environment_data):
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var object_id := str((entry_value as Dictionary).get("object_id", ""))
		if not object_id.is_empty():
			result[object_id] = true
	for event_id in JsonCoerceScript._string_array(environment_data.get("event_ids", [])):
		result["event:%s" % event_id] = true
	for offer in JsonCoerceScript._copy_array(environment_data.get("item_offers", [])):
		if typeof(offer) != TYPE_DICTIONARY:
			continue
		var item_id := str((offer as Dictionary).get("id", ""))
		if not item_id.is_empty():
			result["item:%s" % item_id] = true
	if _shopkeeper_should_exist(environment_data):
		result["shopkeeper:merchant"] = true
	if not _travel_target_ids(environment_data).is_empty():
		result["travel:leave"] = true
	for fixture_id in _casino_fixture_ids(environment_data):
		result["casino_fixture:%s" % fixture_id] = true
	for target_id in _grand_casino_local_target_ids(environment_data):
		result["travel:%s" % target_id] = true
	for service_id in JsonCoerceScript._string_array(environment_data.get("service_ids", [])):
		result["service:%s" % service_id] = true
	for lender_id in JsonCoerceScript._string_array(environment_data.get("lender_hooks", [])):
		result["lender:%s" % lender_id] = true
	for entry_value in _environment_layer_layout_entries(environment_data):
		if typeof(entry_value) == TYPE_DICTIONARY:
			result[str((entry_value as Dictionary).get("object_id", ""))] = true
	for entry_value in _game_hook_layout_entries(environment_data):
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var object_id := str((entry_value as Dictionary).get("object_id", ""))
		if not object_id.is_empty():
			result[object_id] = true
	if _home_tenure_should_exist(environment_data):
		result["home_tenure:status"] = true
	if _home_sleep_should_exist(environment_data):
		result["home_sleep:bed"] = true
	if _home_storage_should_exist(environment_data):
		result["home_storage:place"] = true
	for container_id in _home_container_ids(environment_data):
		result["home_container:%s" % container_id] = true
	return result


static func _prune_inactive_object_rects(object_rects: Dictionary, active_object_ids: Dictionary) -> void:
	for key in object_rects.keys():
		var object_id := str(key)
		if _is_managed_object_id(object_id) and not bool(active_object_ids.get(object_id, false)):
			object_rects.erase(key)


static func _is_managed_object_id(object_id: String) -> bool:
	for prefix in ["game:", "event:", "item:", "shopkeeper:", "travel:", "service:", "lender:", "game_hook:", "dialogue:", "casino_fixture:", "home_tenure:", "home_sleep:", "home_storage:", "home_container:", "environment_layer:", "numbers:"]:
		if object_id.begins_with(prefix):
			return true
	return false


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
			var object_id := str(hook_data.get("object_id", "")).strip_edges()
			if object_id.is_empty():
				var dialogue_id := str(hook_data.get("dialogue_id", "")).strip_edges()
				object_id = "dialogue:%s" % dialogue_id if not dialogue_id.is_empty() else "game_hook:%s:%s" % [game_id, hook_id]
			result.append({
				"object_id": object_id,
				"object_type": "game_hook",
				"index": result.size(),
				"spot_field": "game_hook_spots",
				"unique_object_class": str(hook_data.get("unique_object_class", "")).strip_edges(),
				"unique_object_priority": int(hook_data.get("unique_object_priority", 0)),
				"allow_duplicate_unique_class": bool(hook_data.get("allow_duplicate_unique_class", false)),
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
