extends RefCounted

const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EnvironmentSemanticInventoryScript := preload("res://scripts/core/environment_semantic_inventory.gd")
const EnvironmentBaseSemanticRecordsScript := preload("res://scripts/core/environment_base_semantic_records.gd")
const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")

const RECORD_KEYS := ["collection", "owner_namespace", "stable_object_id", "owned_identity", "presentation_object_id", "availability", "source_kind", "source_field", "source_record_id", "record"]


class FixtureLibrary:
	extends RefCounted

	var events_by_id: Dictionary = {}
	var characters_by_id: Dictionary = {}
	var character_pools_by_id: Dictionary = {}
	var games_by_id: Dictionary = {}
	var dialogues_by_id: Dictionary = {}
	var items_by_id: Dictionary = {}
	var routes_by_id: Dictionary = {}
	var archetypes_by_id: Dictionary = {}

	func event(event_id: String) -> Dictionary:
		return _entry(events_by_id, event_id)

	func character(character_id: String) -> Dictionary:
		return _entry(characters_by_id, character_id)

	func character_pool(pool_id: String) -> Dictionary:
		return _entry(character_pools_by_id, pool_id)

	func game(game_id: String) -> Dictionary:
		return _entry(games_by_id, game_id)

	func dialogue(dialogue_id: String) -> Dictionary:
		return _entry(dialogues_by_id, dialogue_id)

	func service(_service_id: String) -> Dictionary:
		return {}

	func item(item_id: String) -> Dictionary:
		return _entry(items_by_id, item_id)

	func lender(_lender_id: String) -> Dictionary:
		return {}

	func route(route_id: String) -> Dictionary:
		return _entry(routes_by_id, route_id)

	func environment_archetype(archetype_id: String) -> Dictionary:
		return _entry(archetypes_by_id, archetype_id)

	func _entry(entries: Dictionary, entry_id: String) -> Dictionary:
		var value: Variant = entries.get(entry_id, {})
		return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func check(library: ContentLibrary, failures: Array) -> void:
	_check_identity_contract(failures)
	_check_target_key_contract(failures)
	_check_selected_offer_catalog_and_generation(library, failures)
	_check_exclusive_catalog_and_generation(library, failures)
	_check_exclusive_pool_and_choices(library, failures)
	_check_rare_route_catalog(library, failures)
	_check_rare_route_materialization(library, failures)
	_check_semantic_zone_shapes(library, failures)
	_check_semantic_anchor_shapes(library, failures)
	_check_authored_actor_shapes(library, failures)
	_check_authored_actor_rejections(library, failures)
	_check_dynamic_actor_authority(failures)
	_check_dynamic_actor_rejections(failures)
	_check_noninteractive_actor_independence(failures)
	_check_game_interactable_authority(library, failures)
	_check_dynamic_interaction_revalidation(library, failures)
	_check_instance_source_binding(failures)
	_check_consumed_dynamic_source_binding(failures)
	_check_record_contract(library, failures)
	_check_digest_contract(library, failures)
	_check_diagnostic_codes(library, failures)
	_check_diagnostic_messages(library, failures)
	_check_static_golden_examples(library, failures)
	_check_exact_optional_absence(library, failures)
	_check_exact_fixture_distinctions(library, failures)
	_check_exact_collision_and_geometry(library, failures)
	_check_presentation_actor_rejection(failures)
	_check_semantic_proof_reference_persistence(failures)
	_check_legacy_round_trip(library, failures)
	_check_semantic_save_shapes(failures)
	_check_exclusive_offer_key_rejection(library, failures)
	_check_all_scenario_catalogs(library, failures)


static func _check_identity_contract(failures: Array) -> void:
	for identity in ["base::zone:floor", "game::game:slot", "event::event:street_craps"]:
		if not OperationRegistryScript.validate_owned_identity(identity).is_empty():
			failures.append("Environment semantic inventory rejected canonical owned identity %s." % identity)
	var invalid_identities := ["", "base::", "::zone:floor", "base::zone::floor", "BASE::zone:floor", " base::zone:floor", "base::zone/../../../floor"]
	invalid_identities.append("base::zone%sfloor" % String.chr(0x2028))
	for identity in invalid_identities:
		if OperationRegistryScript.validate_owned_identity(identity).is_empty():
			failures.append("Environment semantic inventory accepted malformed owned identity %s." % identity)


static func _check_target_key_contract(failures: Array) -> void:
	var first := OperationRegistryScript.target_key("interactions", "game", "game:slot")
	var second := OperationRegistryScript.target_key("interactionsgame", "game", ":slot")
	var third := OperationRegistryScript.target_key("interactions", "game", "game:slot:2")
	if first.is_empty() or first == second or first == third:
		failures.append("Environment semantic target keys aliased distinct collection/owner/stable-id tuples.")
	if first != OperationRegistryScript.target_key("interactions", "game", "game:slot"):
		failures.append("Environment semantic target-key generation was not deterministic.")


static func _check_selected_offer_catalog_and_generation(library: ContentLibrary, failures: Array) -> void:
	var definition := library.scenario("pawn_shop_estate_lot_day")
	var catalog := library.scenario_target_catalog(definition)
	var guaranteed := _dict(catalog.get("guaranteed", {}))
	for item_id in ["roadside_map", "false_bottom_cup"]:
		var identity := "base::item:%s" % item_id
		if not _array(guaranteed.get("scene_objects", [])).has(identity) or not _array(guaranteed.get("interactions", [])).has(identity):
			failures.append("Selected scenario offer %s was not guaranteed in both rendered catalog collections." % item_id)
	var generated := _generated_environment(library, "pawn_shop", definition, 7101)
	for item_id in ["roadside_map", "false_bottom_cup"]:
		if not _offer_ids(generated.get("item_offers", [])).has(item_id):
			failures.append("Selected scenario offer %s did not materialize in EnvironmentInstance generation." % item_id)


static func _check_exclusive_catalog_and_generation(library: ContentLibrary, failures: Array) -> void:
	var definition := library.scenario("back_alley_street_craps")
	var catalog := library.scenario_target_catalog(definition)
	var guaranteed := _dict(catalog.get("guaranteed", {}))
	for collection_key in ["scene_objects", "interactions"]:
		if not _array(guaranteed.get(collection_key, [])).has("event::event:scenario_street_craps_circle"):
			failures.append("Scenario-exclusive event was not a guaranteed rendered %s target." % collection_key)
		if not _array(guaranteed.get(collection_key, [])).has("game::game:craps"):
			failures.append("Scenario-exclusive game was not a guaranteed rendered %s target." % collection_key)
	if not _array(guaranteed.get("games", [])).has("game::craps"):
		failures.append("Scenario-exclusive game did not expose its guaranteed game-domain target.")
	var generated := _generated_environment(library, "back_alley", definition, 7102)
	if not _array(generated.get("event_ids", [])).has("scenario_street_craps_circle") or not _array(generated.get("game_ids", [])).has("craps"):
		failures.append("Scenario-exclusive event/game did not materialize in EnvironmentInstance generation.")


static func _check_exclusive_pool_and_choices(library: ContentLibrary, failures: Array) -> void:
	var definition := library.scenario("back_alley_street_craps")
	var base := library.environment_archetype("back_alley")
	if _array(base.get("event_pool", [])).has("scenario_street_craps_circle"):
		failures.append("Street-craps exclusive event unexpectedly became a base archetype pool member.")
	var catalog := library.scenario_target_catalog(definition)
	if not _dict(catalog.get("event_choices", {})).has("scenario_street_craps_circle"):
		failures.append("Scenario-exclusive event was omitted from static event-choice authorization.")
	var inventory := _dict(catalog.get("inventory", {}))
	if _array(_dict(inventory.get("possible", {})).get("interactions", [])).has("event::event:scenario_street_craps_circle"):
		failures.append("Scenario-exclusive event leaked into the possible-only pool after being guaranteed.")


static func _check_rare_route_catalog(library: ContentLibrary, failures: Array) -> void:
	for chance in [0, 50, 100]:
		var archetype := _rare_route_archetype(library, chance)
		var inventory := EnvironmentSemanticInventoryScript.for_archetype(archetype, library)
		var guaranteed := EnvironmentSemanticInventoryScript.guaranteed_collections(inventory)
		var possible := EnvironmentSemanticInventoryScript.possible_collections(inventory)
		var route_identity := "base::world:bar"
		var leave_identity := "base::travel:leave"
		if chance == 0 and (_array(guaranteed.get("routes", [])).has(route_identity) or _array(possible.get("routes", [])).has(route_identity)):
			failures.append("Zero-percent rare route appeared in the static catalog.")
		elif chance == 50 and (not _array(possible.get("routes", [])).has(route_identity) or not _array(possible.get("interactions", [])).has(leave_identity)):
			failures.append("Partial-chance rare route/travel surface was not possible-only.")
		elif chance == 100 and (not _array(guaranteed.get("routes", [])).has(route_identity) or not _array(guaranteed.get("interactions", [])).has(leave_identity)):
			failures.append("Certain rare route/travel surface was not guaranteed.")


static func _check_rare_route_materialization(library: ContentLibrary, failures: Array) -> void:
	var absent := _generated_from_archetype(_rare_route_archetype(library, 0), library, 7200)
	var present := _generated_from_archetype(_rare_route_archetype(library, 100), library, 7200)
	if _array(absent.get("next_archetypes", [])).has("bar") or not _array(present.get("next_archetypes", [])).has("bar"):
		failures.append("Rare route did not obey deterministic zero/one-hundred-percent materialization.")
	var first := _generated_from_archetype(_rare_route_archetype(library, 50), library, 7201)
	var second := _generated_from_archetype(_rare_route_archetype(library, 50), library, 7201)
	if _array(first.get("next_archetypes", [])).has("bar") != _array(second.get("next_archetypes", [])).has("bar"):
		failures.append("Partial rare-route materialization was not deterministic for the same RNG seed.")


static func _check_semantic_zone_shapes(_library: ContentLibrary, failures: Array) -> void:
	var fixture_library := _semantic_library()
	var valid := _semantic_archetype()
	var inventory := EnvironmentSemanticInventoryScript.for_archetype(valid, fixture_library)
	if not EnvironmentSemanticInventoryScript.guaranteed_collections(inventory).get("zones", []).has("base::zone:floor"):
		failures.append("Valid semantic zone did not derive base::zone:<id> ownership.")
	var malformed_values: Array = [
		[],
		{"floor": {}},
		{"floor": {"bounds": [0, 0, 0, 20]}},
		{"floor": {"bounds": [-1, 0, 20, 20]}},
		{"floor": {"bounds": [0, 0, 9000, 20]}},
		{"Bad Zone": {"bounds": [0, 0, 20, 20]}},
		{"floor": {"bounds": [0, 0, 20, 20], "label": "forged"}},
	]
	for malformed_value in malformed_values:
		var candidate := valid.duplicate(true)
		candidate["semantic_zones"] = malformed_value
		if EnvironmentSemanticInventoryScript.validate(EnvironmentSemanticInventoryScript.for_archetype(candidate, fixture_library)).is_empty():
			failures.append("Malformed semantic zone shape was accepted: %s." % JSON.stringify(malformed_value))


static func _check_semantic_anchor_shapes(_library: ContentLibrary, failures: Array) -> void:
	var fixture_library := _semantic_library()
	var valid := _semantic_archetype()
	var inventory := EnvironmentSemanticInventoryScript.for_archetype(valid, fixture_library)
	if not EnvironmentSemanticInventoryScript.guaranteed_collections(inventory).get("anchors", []).has("base::anchor:stage"):
		failures.append("Valid semantic anchor did not derive base::anchor:<id> ownership.")
	var malformed_values: Array = [
		[],
		{"stage": {}},
		{"stage": {"position": [50]}},
		{"stage": {"position": [-1, 50]}},
		{"stage": {"position": [50, 50], "zone_id": "missing"}},
		{"Bad Anchor": {"position": [50, 50]}},
		{"stage": {"position": [50, 50], "label": "forged"}},
	]
	for malformed_value in malformed_values:
		var candidate := valid.duplicate(true)
		candidate["semantic_anchors"] = malformed_value
		if EnvironmentSemanticInventoryScript.validate(EnvironmentSemanticInventoryScript.for_archetype(candidate, fixture_library)).is_empty():
			failures.append("Malformed semantic anchor shape was accepted: %s." % JSON.stringify(malformed_value))


static func _check_authored_actor_shapes(_library: ContentLibrary, failures: Array) -> void:
	var fixture_library := _semantic_library()
	var inventory := EnvironmentSemanticInventoryScript.for_archetype(_semantic_archetype(), fixture_library)
	var guaranteed := EnvironmentSemanticInventoryScript.guaranteed_collections(inventory)
	if not _array(guaranteed.get("actors", [])).has("base::actor:clerk"):
		failures.append("Authored semantic actor did not derive base-owned actor identity.")
	var actor_record := _record_for(inventory, "actors", "base::actor:clerk")
	if str(actor_record.get("owner_namespace", "")) != "base" or str(actor_record.get("stable_object_id", "")) != "actor:clerk" or str(actor_record.get("source_field", "")) != "semantic_actors":
		failures.append("Authored semantic actor record lost derived identity or exact provenance.")


static func _check_authored_actor_rejections(_library: ContentLibrary, failures: Array) -> void:
	var fixture_library := _semantic_library()
	var actor_cases: Array = [
		{"id": "clerk", "actor_id": "dealer_actor"},
		{"id": "clerk", "actor_id": "unknown_actor", "anchor_id": "stage"},
		{"id": "clerk", "actor_id": "dealer_actor", "anchor_id": "missing"},
		{"id": "clerk", "actor_id": "dealer_actor", "anchor_id": "stage", "zone_id": "side"},
		{"id": "Bad Actor", "actor_id": "dealer_actor", "anchor_id": "stage"},
		{"id": "clerk", "actor_id": "dealer_actor", "anchor_id": "stage", "owner_namespace": "event"},
		{"id": "clerk", "actor_id": "dealer_actor", "anchor_id": "stage", "stable_object_id": "actor:forged"},
	]
	for actor in actor_cases:
		var candidate := _semantic_archetype()
		candidate["semantic_actors"] = [actor]
		if EnvironmentSemanticInventoryScript.validate(EnvironmentSemanticInventoryScript.for_archetype(candidate, fixture_library)).is_empty():
			failures.append("Malformed or forged authored semantic actor was accepted: %s." % JSON.stringify(actor))
	var duplicate := _semantic_archetype()
	duplicate["semantic_actors"] = [_semantic_actor(), _semantic_actor()]
	if EnvironmentSemanticInventoryScript.validate(EnvironmentSemanticInventoryScript.for_archetype(duplicate, fixture_library)).is_empty():
		failures.append("Duplicate authored semantic actor identity was accepted.")


static func _check_dynamic_actor_authority(failures: Array) -> void:
	var fixture_library := _semantic_library()
	var environment := _semantic_environment()
	var authorized := EnvironmentBaseSemanticRecordsScript.authorized_dynamic_actor_records(environment, fixture_library)
	if not bool(authorized.get("ok", false)) or _array(authorized.get("records", [])).size() != 1:
		failures.append("Authorized event semantic actor did not produce exactly one trusted actor record.")
		return
	var inventory := EnvironmentSemanticInventoryScript.for_instance(environment, fixture_library, [], _array(authorized.get("records", [])))
	if not EnvironmentSemanticInventoryScript.validate(inventory).is_empty():
		failures.append("Authorized event semantic actor did not seal into a valid exact inventory.")
		return
	var exact := EnvironmentSemanticInventoryScript.exact_collections(inventory)
	if not _array(exact.get("actors", [])).has("event::actor:dealer"):
		failures.append("Authorized event semantic actor lost its event-owned derived identity.")
	var record := _record_for(inventory, "actors", "event::actor:dealer")
	if str(record.get("source_kind", "")) != "environment_event" or str(record.get("source_field", "")) != "event_ids" or str(record.get("source_record_id", "")) != "actor_event":
		failures.append("Authorized event semantic actor lost exact producer provenance.")


static func _check_dynamic_actor_rejections(failures: Array) -> void:
	var fixture_library := _semantic_library()
	var environment := _semantic_environment()
	var authorized := EnvironmentBaseSemanticRecordsScript.authorized_dynamic_actor_records(environment, fixture_library)
	var records := _array(authorized.get("records", []))
	if not bool(authorized.get("ok", false)) or records.size() != 1:
		failures.append("Dynamic actor rejection matrix could not establish its trusted control record.")
		return
	var record := _dict(records[0]).duplicate(true)
	var forged_cases: Array = []
	for key in ["owner_namespace", "stable_object_id", "source_kind", "source_field", "source_record_id"]:
		var forged := record.duplicate(true)
		forged[key] = "forged"
		forged_cases.append(forged)
	var missing_provenance := record.duplicate(true)
	missing_provenance.erase("source_record_id")
	forged_cases.append(missing_provenance)
	var payload_conflict := record.duplicate(true)
	payload_conflict["behavior"] = "hostile"
	forged_cases.append(payload_conflict)
	for forged in forged_cases:
		var inventory := EnvironmentSemanticInventoryScript.for_instance(environment, fixture_library, [], [forged])
		if EnvironmentSemanticInventoryScript.validate(inventory).is_empty():
			failures.append("Forged/missing dynamic actor authority was accepted: %s." % JSON.stringify(forged))


static func _check_noninteractive_actor_independence(failures: Array) -> void:
	var fixture_library := _semantic_library()
	var environment := _semantic_environment()
	environment["event_ids"] = []
	var inventory := EnvironmentSemanticInventoryScript.for_instance(environment, fixture_library)
	var exact := EnvironmentSemanticInventoryScript.exact_collections(inventory)
	if not _array(exact.get("actors", [])).has("base::actor:clerk") or not _array(exact.get("interactions", [])).is_empty():
		failures.append("Noninteractive authored actor was coupled to presentation interaction metadata.")


static func _check_game_interactable_authority(library: ContentLibrary, failures: Array) -> void:
	var fixture_library := FixtureLibrary.new()
	fixture_library.games_by_id = {
		"fixture_game": {
			"id": "fixture_game",
			"environment_interactable_objects": [
				{"id": "cash_out", "object_id": "game_hook:fixture_game:cash_out"},
				{"id": "clerk_talk", "object_id": "dialogue:fixture_dialogue", "dialogue_id": "fixture_dialogue"},
			],
		},
		"other_game": {
			"id": "other_game",
			"environment_interactable_objects": [
				{"id": "other_cash_out", "object_id": "game_hook:other_game:other_cash_out"},
				{"id": "other_talk", "object_id": "dialogue:other_dialogue", "dialogue_id": "other_dialogue"},
			],
		},
	}
	fixture_library.dialogues_by_id = {
		"fixture_dialogue": {"id": "fixture_dialogue"},
		"other_dialogue": {"id": "other_dialogue"},
		"global_only_dialogue": {"id": "global_only_dialogue"},
	}
	var environment := {"game_ids": ["fixture_game"]}
	var positive_hook := _producer_presentation_record("game_hook:fixture_game:cash_out", "game_hook", "cash_out", "fixture_game")
	var positive_dialogue := _producer_presentation_record("dialogue:fixture_dialogue", "dialogue", "fixture_dialogue", "fixture_game")
	for positive_record in [positive_hook, positive_dialogue]:
		var pipeline := _game_interactable_pipeline(positive_record, environment, fixture_library)
		if not bool(pipeline.get("ok", false)):
			failures.append("Exact authored parent-game interactable row did not survive stamp -> record conversion -> exact inventory: %s." % JSON.stringify(pipeline.get("errors", [])))
		else:
			var stamped_record := _dict(pipeline.get("stamped_record", {}))
			if str(stamped_record.get("owner_namespace", "")) != "game" or not str(stamped_record.get("source_field", "")).begins_with("game_ids.environment_interactable_objects") or str(stamped_record.get("source_record_id", "")).is_empty():
				failures.append("Authored parent-game interactable row lost game ownership or exact row provenance.")
	var hostile_records := [
		_producer_presentation_record("game_hook:fixture_game:forged_hook", "game_hook", "forged_hook", "fixture_game"),
		_producer_presentation_record("game_hook:fixture_game:other_cash_out", "game_hook", "other_cash_out", "fixture_game"),
		_producer_presentation_record("game_hook:other_game:other_cash_out", "game_hook", "other_cash_out", "other_game"),
		_producer_presentation_record("dialogue:global_only_dialogue", "dialogue", "global_only_dialogue", "fixture_game"),
		_producer_presentation_record("dialogue:other_dialogue", "dialogue", "other_dialogue", "fixture_game"),
		_producer_presentation_record("dialogue:forged_presentation", "dialogue", "fixture_dialogue", "fixture_game"),
	]
	for hostile_record in hostile_records:
		if bool(EnvironmentBaseSemanticRecordsScript.stamp_interactable_records([hostile_record], environment, fixture_library).get("ok", true)):
			failures.append("Game-hook/dialogue producer authorized a forged or wrong-parent authored row: %s." % JSON.stringify(hostile_record))
	var production_rows := [
		["pull_tabs", "game_hook:pull_tabs:ticket_redeemer", "game_hook", "ticket_redeemer"],
		["pull_tabs", "dialogue:pull_tab_clerk", "dialogue", "pull_tab_clerk"],
		["scratch_tickets", "game_hook:scratch_tickets:scratch_ticket_clerk", "game_hook", "scratch_ticket_clerk"],
		["scratch_tickets", "dialogue:scratch_ticket_scalper", "dialogue", "scratch_ticket_scalper_knows"],
		["scratch_tickets", "dialogue:scratch_ticket_scalper", "dialogue", "scratch_ticket_scalper_oblivious"],
	]
	var scratch_variant_digests: Array = []
	var scratch_variant_source_records: Array = []
	for row_value in production_rows:
		var row := row_value as Array
		var game_id := str(row[0])
		var production_environment := {"game_ids": [game_id]}
		var production_record := _producer_presentation_record(str(row[1]), str(row[2]), str(row[3]), game_id)
		var production_pipeline := _game_interactable_pipeline(production_record, production_environment, library)
		if not bool(production_pipeline.get("ok", false)):
			failures.append("Production game interactable manifest did not admit %s/%s through exact inventory: %s." % [game_id, str(row[3]), JSON.stringify(production_pipeline.get("errors", []))])
		elif game_id == "scratch_tickets" and str(row[2]) == "dialogue":
			scratch_variant_digests.append(str(_dict(production_pipeline.get("inventory", {})).get("digest", "")))
			scratch_variant_source_records.append(str(_dict(production_pipeline.get("stamped_record", {})).get("source_record_id", "")))
	if scratch_variant_digests.size() != 2 or scratch_variant_digests[0] != scratch_variant_digests[1] or scratch_variant_source_records != ["scratch_tickets:scratch_ticket_scalper", "scratch_tickets:scratch_ticket_scalper"]:
		failures.append("The production scratch scalper's fixed presentation identity did not remain stable across its knows/oblivious dialogue variants.")


static func _check_dynamic_interaction_revalidation(library: ContentLibrary, failures: Array) -> void:
	var presentation := _producer_presentation_record("game_hook:pull_tabs:ticket_redeemer", "game_hook", "ticket_redeemer", "pull_tabs")
	var pipeline := _game_interactable_pipeline(presentation, {"game_ids": ["pull_tabs"]}, library)
	if not bool(pipeline.get("ok", false)):
		failures.append("Dynamic-interaction hostile matrix could not establish its production control record.")
		return
	var valid_record := _dict(_array(pipeline.get("interactions", []))[0])
	var environment := {
		"id": "dynamic_revalidation_001",
		"archetype_id": "bar",
		"world_node_id": "bar",
		"layout": {"object_rects": {}},
		"game_ids": ["pull_tabs"],
		"event_ids": [],
		"item_offers": [],
		"service_ids": [],
		"lender_hooks": [],
		"travel_hooks": [],
		"next_archetypes": [],
	}
	var hostile_cases: Array = []
	for field in ["source_kind", "source_record_id", "source_id", "owner_namespace"]:
		var forged := valid_record.duplicate(true)
		forged[field] = "forged"
		hostile_cases.append(forged)
	var malformed_bounds := valid_record.duplicate(true)
	malformed_bounds["hit_bounds"] = {"w": 0.0, "h": 0.0}
	hostile_cases.append(malformed_bounds)
	var inaccessible := valid_record.duplicate(true)
	inaccessible["prompt"] = ""
	hostile_cases.append(inaccessible)
	for hostile_value in hostile_cases:
		var hostile := _dict(hostile_value)
		var inventory := EnvironmentSemanticInventoryScript.for_instance(environment, library, [hostile])
		if EnvironmentSemanticInventoryScript.validate(inventory).is_empty():
			failures.append("Direct forged allowlisted dynamic interaction survived exact producer revalidation: %s." % JSON.stringify(hostile))


static func _game_interactable_pipeline(presentation_record: Dictionary, environment_value: Dictionary, library: Variant) -> Dictionary:
	var stamped := EnvironmentBaseSemanticRecordsScript.stamp_interactable_records([presentation_record], environment_value, library)
	if not bool(stamped.get("ok", false)) or _array(stamped.get("records", [])).size() != 1:
		return {"ok": false, "errors": _array(stamped.get("errors", []))}
	var stamped_record := _dict(_array(stamped.get("records", []))[0])
	var produced := EnvironmentBaseSemanticRecordsScript.from_interactable_records([stamped_record])
	if not bool(produced.get("ok", false)) or _array(produced.get("interactions", [])).size() != 1:
		return {"ok": false, "errors": _array(produced.get("errors", []))}
	var environment := environment_value.duplicate(true)
	environment["id"] = "game_manifest_fixture_001"
	environment["archetype_id"] = "game_manifest_fixture"
	environment["world_node_id"] = "game_manifest_fixture"
	environment["layout"] = {"object_rects": {}}
	var interactions := _array(produced.get("interactions", []))
	environment["scenario_base_interactions"] = interactions.duplicate(true)
	environment["scenario_base_actors"] = []
	var inventory := EnvironmentSemanticInventoryScript.for_instance(environment, library, interactions)
	var identity := OperationRegistryScript.identity("game", str(presentation_record.get("object_id", "")))
	if not EnvironmentSemanticInventoryScript.validate(inventory).is_empty() or not _array(EnvironmentSemanticInventoryScript.exact_collections(inventory).get("interactions", [])).has(identity) or not EnvironmentSemanticInventoryScript.validate_instance_binding(inventory, environment).is_empty():
		return {"ok": false, "errors": _array(inventory.get("errors", [])) + EnvironmentSemanticInventoryScript.validate_instance_binding(inventory, environment)}
	return {"ok": true, "errors": [], "stamped_record": stamped_record, "interactions": interactions, "inventory": inventory}


static func _check_instance_source_binding(failures: Array) -> void:
	var library := _semantic_library()
	library.archetypes_by_id = {"casino_room_a": {"id": "casino_room_a"}, "casino_room_b": {"id": "casino_room_b"}}
	library.items_by_id = {"marked_cards": {"id": "marked_cards"}}
	var environment := _semantic_environment()
	environment["current_layer_id"] = "front"
	environment["layer_ids"] = ["front", "back", "side"]
	environment["layer_transitions"] = [{"target_layer_id": "back"}]
	environment["local_narrative_flags"] = {"casino_room_targets": ["casino_room_a"], "casino_fixtures": [{"id": "roulette_table"}]}
	environment["crew_presence"] = [{"member_id": "crew_rook"}]
	environment["home_profile"] = {"status": "tenant", "bed": "cot", "place": "back_room"}
	environment["home_containers"] = [{"id": "footlocker"}]
	environment["item_offers"] = [{"id": "marked_cards", "object_id": "item:marked_cards"}]
	environment["scenario_base_producer_context"] = {"numbers_venue_ids": ["semantic_fixture"], "numbers_silas_present": true, "delivery_handoff_node_id": "semantic_fixture"}
	var source_rect := {"x": 0.1, "y": 0.1, "w": 0.1, "h": 0.2}
	environment["layout"] = {"object_rects": {
		"console": source_rect.duplicate(true),
		"item:marked_cards": source_rect.duplicate(true),
		"casino_fixture:roulette_table": source_rect.duplicate(true),
		"home_tenure:status": source_rect.duplicate(true),
		"home_container:footlocker": source_rect.duplicate(true),
	}}
	var interaction := _interaction_record("base", "console", "console")
	interaction["source_field"] = "layout.object_rects"
	interaction["source_record_id"] = "console"
	var producer_records := [
		_producer_presentation_record("item:marked_cards", "item", "marked_cards", ""),
		_producer_presentation_record("casino_fixture:roulette_table", "casino_fixture", "roulette_table", ""),
		_producer_presentation_record("crew_presence:crew_rook", "dialogue", "crew_rook", ""),
		_producer_presentation_record("home_tenure:status", "home_tenure", "status", ""),
		_producer_presentation_record("home_container:footlocker", "home_container", "footlocker", ""),
	]
	var stamped_sources := EnvironmentBaseSemanticRecordsScript.stamp_interactable_records(producer_records, environment, library)
	var produced_sources := EnvironmentBaseSemanticRecordsScript.from_interactable_records(_array(stamped_sources.get("records", [])))
	var interactions := [interaction]
	interactions.append_array(_array(produced_sources.get("interactions", [])))
	var dynamic_actors := EnvironmentBaseSemanticRecordsScript.authorized_dynamic_actor_records(environment, library)
	var actors := _array(dynamic_actors.get("records", []))
	environment["scenario_base_interactions"] = interactions.duplicate(true)
	environment["scenario_base_actors"] = actors.duplicate(true)
	var inventory := EnvironmentSemanticInventoryScript.for_instance(environment, library, interactions, actors)
	if not bool(stamped_sources.get("ok", false)) or not bool(produced_sources.get("ok", false)) or not bool(dynamic_actors.get("ok", false)) or not EnvironmentSemanticInventoryScript.validate_instance_binding(inventory, environment).is_empty():
		failures.append("Exact instance source-binding fixture did not produce a valid host-bound seal.")
		return
	var mutations: Array = []
	var changed := environment.duplicate(true)
	changed["layout"]["object_rects"]["console"]["x"] = 0.2
	mutations.append(["layout.object_rects", changed])
	changed = environment.duplicate(true)
	changed["semantic_zones"]["floor"]["bounds"][2] = 199
	mutations.append(["semantic_zones", changed])
	changed = environment.duplicate(true)
	changed["semantic_anchors"]["stage"]["position"][0] = 51
	mutations.append(["semantic_anchors", changed])
	changed = environment.duplicate(true)
	changed["semantic_actors"][0]["behavior"] = "waiting"
	mutations.append(["semantic_actors", changed])
	changed = environment.duplicate(true)
	changed["layer_transitions"][0]["target_layer_id"] = "side"
	mutations.append(["layer_transitions", changed])
	changed = environment.duplicate(true)
	changed["local_narrative_flags"]["casino_room_targets"] = ["casino_room_b"]
	mutations.append(["casino_room_targets", changed])
	changed = environment.duplicate(true)
	changed["local_narrative_flags"]["casino_fixtures"][0]["id"] = "forged_table"
	mutations.append(["casino fixture authority", changed])
	changed = environment.duplicate(true)
	changed["crew_presence"][0]["member_id"] = "crew_forged"
	mutations.append(["crew presence authority", changed])
	changed = environment.duplicate(true)
	changed["home_profile"]["place"] = "forged_room"
	mutations.append(["home profile authority", changed])
	changed = environment.duplicate(true)
	changed["home_containers"][0]["id"] = "forged_container"
	mutations.append(["home container authority", changed])
	changed = environment.duplicate(true)
	changed["item_offers"][0]["object_id"] = "item:forged"
	mutations.append(["item-offer presentation authority", changed])
	changed = environment.duplicate(true)
	changed["scenario_base_interactions"][0]["source_record_id"] = "forged_console"
	mutations.append(["finalized base interaction provenance", changed])
	changed = environment.duplicate(true)
	changed["scenario_base_interactions"][0]["normalized_hit_rect"]["x"] = 0.2
	mutations.append(["finalized base interaction geometry", changed])
	changed = environment.duplicate(true)
	changed["scenario_base_actors"][0]["behavior"] = "watching"
	mutations.append(["finalized base actors", changed])
	for mutation_value in mutations:
		var mutation := mutation_value as Array
		if EnvironmentSemanticInventoryScript.validate_instance_binding(inventory, _dict(mutation[1])).is_empty():
			failures.append("Same-room %s mutation retained a stale exact semantic seal." % str(mutation[0]))
	var transient_environment := environment.duplicate(true)
	transient_environment["scenario_base_interactions"][0]["enabled"] = false
	transient_environment["scenario_base_interactions"][0]["available_actions"] = []
	var transient_interactions := _array(transient_environment.get("scenario_base_interactions", []))
	var refreshed := EnvironmentSemanticInventoryScript.for_instance(transient_environment, library, transient_interactions, actors)
	if not EnvironmentSemanticInventoryScript.validate_instance_binding(inventory, transient_environment).is_empty() or str(refreshed.get("digest", "")) != str(inventory.get("digest", "")):
		failures.append("Transient interaction availability/action refresh churned or invalidated stable semantic authority.")
	var unrelated_context := environment.duplicate(true)
	unrelated_context["scenario_base_producer_context"] = {"numbers_venue_ids": [], "numbers_silas_present": false, "delivery_handoff_node_id": "elsewhere"}
	var unrelated_inventory := EnvironmentSemanticInventoryScript.for_instance(unrelated_context, library, interactions, actors)
	if not EnvironmentSemanticInventoryScript.validate_instance_binding(inventory, unrelated_context).is_empty() or str(unrelated_inventory.get("digest", "")) != str(inventory.get("digest", "")):
		failures.append("Unconsumed Numbers/Silas/delivery producer churn invalidated or changed a stable semantic inventory.")


static func _check_consumed_dynamic_source_binding(failures: Array) -> void:
	var library := _semantic_library()
	var context := {"numbers_venue_ids": ["semantic_fixture"], "numbers_silas_present": true, "delivery_handoff_node_id": "semantic_fixture"}
	var cases := [
		{"label": "numbers venue", "record": _producer_presentation_record("numbers:book", "numbers", "book", ""), "stale_key": "numbers_venue_ids", "stale_value": [], "malformed_value": "semantic_fixture", "unrelated": {"numbers_silas_present": false, "delivery_handoff_node_id": "elsewhere"}},
		{"label": "numbers contact", "record": _producer_presentation_record("numbers:silas", "numbers", "silas", ""), "stale_key": "numbers_silas_present", "stale_value": false, "malformed_value": "true", "unrelated": {"numbers_venue_ids": [], "delivery_handoff_node_id": "elsewhere"}},
		{"label": "delivery handoff", "record": _producer_presentation_record("delivery:handoff:semantic_fixture", "delivery", "semantic_fixture", ""), "stale_key": "delivery_handoff_node_id", "stale_value": "elsewhere", "malformed_value": ["semantic_fixture"], "unrelated": {"numbers_venue_ids": [], "numbers_silas_present": false}},
	]
	for case_value in cases:
		var case := _dict(case_value)
		var environment := {
			"id": "consumed_dynamic_fixture_001",
			"archetype_id": "semantic_fixture",
			"world_node_id": "semantic_fixture",
			"layout": {"object_rects": {}},
			"game_ids": [], "event_ids": [], "item_offers": [], "service_ids": [], "lender_hooks": [], "travel_hooks": [], "next_archetypes": [],
			"semantic_zones": {}, "semantic_anchors": {}, "semantic_actors": [],
			"scenario_base_producer_context": context.duplicate(true),
		}
		var stamped := EnvironmentBaseSemanticRecordsScript.stamp_interactable_records([case.get("record")], environment, library, context)
		var produced := EnvironmentBaseSemanticRecordsScript.from_interactable_records(_array(stamped.get("records", [])))
		var interactions := _array(produced.get("interactions", []))
		environment["scenario_base_interactions"] = interactions.duplicate(true)
		environment["scenario_base_actors"] = []
		var inventory := EnvironmentSemanticInventoryScript.for_instance(environment, library, interactions)
		if not bool(stamped.get("ok", false)) or not bool(produced.get("ok", false)) or not EnvironmentSemanticInventoryScript.validate_instance_binding(inventory, environment).is_empty():
			failures.append("Consumed %s dynamic source could not establish its exact live authority control." % str(case.get("label", "producer")))
			continue
		var stale := environment.duplicate(true)
		stale["scenario_base_producer_context"][str(case.get("stale_key", ""))] = case.get("stale_value")
		if not _contains_text(EnvironmentSemanticInventoryScript.validate_instance_binding(inventory, stale), "consumed dynamic target"):
			failures.append("Consumed %s dynamic source remained authorized after its live producer disappeared." % str(case.get("label", "producer")))
		var malformed := environment.duplicate(true)
		malformed["scenario_base_producer_context"][str(case.get("stale_key", ""))] = case.get("malformed_value")
		if not _contains_text(EnvironmentSemanticInventoryScript.validate_instance_binding(inventory, malformed), "consumed dynamic target"):
			failures.append("Consumed %s dynamic source accepted malformed live producer authority." % str(case.get("label", "producer")))
		var unrelated := environment.duplicate(true)
		for key_value in _dict(case.get("unrelated", {})).keys(): unrelated["scenario_base_producer_context"][key_value] = _dict(case.get("unrelated", {})).get(key_value)
		var unrelated_inventory := EnvironmentSemanticInventoryScript.for_instance(unrelated, library, interactions)
		if not EnvironmentSemanticInventoryScript.validate_instance_binding(inventory, unrelated).is_empty() or str(unrelated_inventory.get("digest", "")) != str(inventory.get("digest", "")):
			failures.append("Unrelated live producer churn changed or invalidated consumed %s stable authority." % str(case.get("label", "producer")))


static func _check_record_contract(library: ContentLibrary, failures: Array) -> void:
	var catalog := library.scenario_target_catalog(library.scenario("pawn_shop_estate_lot_day"))
	var catalog_inventory := _dict(catalog.get("inventory", {}))
	if not EnvironmentSemanticInventoryScript.validate(catalog_inventory).is_empty():
		failures.append("Known scenario catalog did not produce a valid sealed semantic inventory.")
	for record_value in _array(catalog_inventory.get("records", [])):
		var record := _dict(record_value)
		if not _same_string_set(record.keys(), RECORD_KEYS) or str(record.get("availability", "")) not in ["guaranteed", "possible"]:
			failures.append("Catalog semantic record was not closed or used an invalid availability value.")
			break
		if str(record.get("owned_identity", "")) != OperationRegistryScript.identity(str(record.get("owner_namespace", "")), str(record.get("stable_object_id", ""))):
			failures.append("Catalog semantic record owned identity disagreed with owner/stable fields.")
			break
		if str(record.get("source_kind", "")).is_empty() or str(record.get("source_field", "")).is_empty() or str(record.get("source_record_id", "")).is_empty():
			failures.append("Catalog semantic record lacked exact source provenance.")
			break
	var exact_inventory := EnvironmentSemanticInventoryScript.for_instance(_exact_environment(), library, [_interaction_record("game", "game:slot", "game:slot")])
	if not EnvironmentSemanticInventoryScript.validate(exact_inventory).is_empty():
		failures.append("Exact fixture did not produce a valid sealed semantic inventory.")
	for record_value in _array(exact_inventory.get("records", [])):
		if str(_dict(record_value).get("availability", "")) != "exact":
			failures.append("Instance semantic record did not use exact availability.")
			break


static func _check_digest_contract(library: ContentLibrary, failures: Array) -> void:
	var environment := _exact_environment()
	var first_interaction := _interaction_record("game", "game:slot", "game:slot")
	var presentation_variant := first_interaction.duplicate(true)
	presentation_variant["label"] = "A different presentation label"
	presentation_variant["enabled"] = false
	presentation_variant["available_actions"] = []
	var first := EnvironmentSemanticInventoryScript.for_instance(environment, library, [first_interaction])
	var second := EnvironmentSemanticInventoryScript.for_instance(environment, library, [presentation_variant])
	if str(first.get("digest", "")) != str(second.get("digest", "")):
		failures.append("Semantic inventory digest changed from presentation-only interaction metadata.")
	var repeated := EnvironmentSemanticInventoryScript.for_instance(environment, library, [first_interaction])
	if str(first.get("digest", "")) != str(repeated.get("digest", "")):
		failures.append("Semantic inventory digest was not deterministic for identical source state.")
	var tampered := first.duplicate(true)
	var records := _array(tampered.get("records", []))
	if not records.is_empty():
		var altered := _dict(records[0])
		altered["availability"] = "guaranteed"
		records[0] = altered
		tampered["records"] = records
	if EnvironmentSemanticInventoryScript.validate(tampered).is_empty() or not EnvironmentSemanticInventoryScript.exact_collections(tampered).is_empty():
		failures.append("Semantic inventory digest did not reject record tampering.")


static func _check_diagnostic_codes(library: ContentLibrary, failures: Array) -> void:
	var archetype := {
		"id": "diagnostic_fixture",
		"game_pool": ["slot"],
		"game_count": [0, 0],
		"layout": {},
	}
	var inventory := EnvironmentSemanticInventoryScript.for_archetype(archetype, library)
	var alternate_layers := {
		"casino": {
			"guaranteed": {"interactions": ["event::event:alternate"]},
			"possible": {},
		},
	}
	var declared := {
		"games": ["game::slot", "game::game:slot"],
		"interactions": ["base::game:slot", "event::event:alternate", "base::unknown:target"],
	}
	var diagnostics := EnvironmentSemanticInventoryScript.diagnose_declared_targets_structured(inventory, declared, alternate_layers)
	var codes: Array = []
	for diagnostic_value in diagnostics:
		var code := str(_dict(diagnostic_value).get("code", ""))
		if not codes.has(code): codes.append(code)
	for expected_code in ["possible_only", "wrong_collection", "wrong_owner", "layer_mismatch", "unknown_target"]:
		if not codes.has(expected_code):
			failures.append("Semantic target diagnostics did not produce code %s." % expected_code)
	if diagnostics.size() != 5:
		failures.append("Semantic target diagnostic matrix did not produce exactly one result per hostile declaration.")


static func _check_diagnostic_messages(library: ContentLibrary, failures: Array) -> void:
	var definition := library.scenario("back_alley_street_craps")
	definition["sequence"] = {"declared_targets": {"games": ["game::game:craps"]}}
	var catalog := library.scenario_target_catalog(definition)
	var expected_detail := ""
	for diagnostic_value in _array(catalog.get("diagnostics", [])):
		var diagnostic := _dict(diagnostic_value)
		if str(diagnostic.get("code", "")) == "wrong_collection" and str(diagnostic.get("owned_identity", "")) == "game::game:craps":
			expected_detail = str(diagnostic.get("message", ""))
			break
	if expected_detail.is_empty():
		failures.append("ContentLibrary omitted the structured wrong_collection diagnostic for game::game:craps.")
		return
	var expected := "environment_scenarios back_alley_street_craps target_catalog[wrong_collection]: %s" % expected_detail
	var messages := library.scenario_target_catalog_messages("back_alley_street_craps", catalog)
	if not messages.has(expected):
		failures.append("ContentLibrary did not format the exact structured target-catalog diagnostic message.")
	var compatibility := EnvironmentSemanticInventoryScript.diagnose_declared_targets(_dict(catalog.get("inventory", {})), {"games": ["game::game:craps"]})
	if not compatibility.has(expected_detail):
		failures.append("Compatibility target-diagnostic wrapper omitted the structured diagnostic text.")


static func _check_static_golden_examples(library: ContentLibrary, failures: Array) -> void:
	var examples := {
		"bar": {"guaranteed": ["game::pull_tabs"], "possible": ["game::slot"]},
		"gas_station_casino": {"guaranteed": ["game::pull_tabs", "game::scratch_tickets"], "possible": ["game::slot"]},
		"kitty_cat_lounge": {"guaranteed": ["game::roulette"], "possible": ["game::slot"]},
		"delta_queen": {"guaranteed": ["game::blackjack", "game::roulette", "game::video_poker"], "possible": []},
	}
	for archetype_id_value in examples.keys():
		var archetype_id := str(archetype_id_value)
		var inventory := EnvironmentSemanticInventoryScript.for_archetype(library.environment_archetype(archetype_id), library)
		var guaranteed := EnvironmentSemanticInventoryScript.guaranteed_collections(inventory)
		var possible := EnvironmentSemanticInventoryScript.possible_collections(inventory)
		for identity in _array(_dict(examples.get(archetype_id, {})).get("guaranteed", [])):
			if not _array(guaranteed.get("games", [])).has(identity):
				failures.append("Static golden census for %s lost guaranteed target %s." % [archetype_id, identity])
		for identity in _array(_dict(examples.get(archetype_id, {})).get("possible", [])):
			if not _array(possible.get("games", [])).has(identity):
				failures.append("Static golden census for %s lost possible target %s." % [archetype_id, identity])
	var punchline := library.environment_archetype("small_underground_casino")
	for layer_id in ["club", "casino", "back_room"]:
		var layer_inventory := EnvironmentSemanticInventoryScript.for_archetype(punchline, library, layer_id)
		if not EnvironmentSemanticInventoryScript.validate(layer_inventory).is_empty() or str(layer_inventory.get("layer_id", "")) != layer_id:
			failures.append("Punchline semantic catalog did not preserve valid exact layer %s scope." % layer_id)


static func _check_exact_optional_absence(library: ContentLibrary, failures: Array) -> void:
	var generated := _generated_environment(library, "bar", {}, 7301)
	var inventory := EnvironmentSemanticInventoryScript.for_instance(generated, library)
	var exact := EnvironmentSemanticInventoryScript.exact_collections(inventory)
	for game_id_value in _array(generated.get("game_ids", [])):
		if not _array(exact.get("games", [])).has("game::%s" % str(game_id_value)):
			failures.append("Generated exact inventory omitted selected bar game %s." % str(game_id_value))
	var static_inventory := EnvironmentSemanticInventoryScript.for_archetype(library.environment_archetype("bar"), library)
	var possible_games := _array(EnvironmentSemanticInventoryScript.possible_collections(static_inventory).get("games", []))
	var absent_count := 0
	for identity_value in possible_games:
		if not _array(exact.get("games", [])).has(str(identity_value)): absent_count += 1
	if absent_count == 0:
		failures.append("Exact inventory retained every optional bar game instead of reflecting selected instance state.")
	if not _array(exact.get("interactions", [])).is_empty():
		failures.append("Saved game ids alone incorrectly proved final rendered interaction geometry.")


static func _check_exact_fixture_distinctions(library: ContentLibrary, failures: Array) -> void:
	var environment := _exact_environment()
	environment["game_ids"] = ["slot"]
	environment["next_archetypes"] = ["bar"]
	environment["layout"] = {"object_rects": {
		"game:slot": {"x": 0.05, "y": 0.1, "w": 0.1, "h": 0.2},
		"game:slot:2": {"x": 0.2, "y": 0.1, "w": 0.1, "h": 0.2},
		"game:slot:3": {"x": 0.35, "y": 0.1, "w": 0.1, "h": 0.2},
	}}
	var interactions := [
		_interaction_record("game", "game:slot", "game:slot", _dict(_dict(environment.get("layout", {})).get("object_rects", {})).get("game:slot")),
		_interaction_record("game", "game:slot:2", "game:slot:2", _dict(_dict(environment.get("layout", {})).get("object_rects", {})).get("game:slot:2")),
		_interaction_record("game", "game:slot:3", "game:slot:3", _dict(_dict(environment.get("layout", {})).get("object_rects", {})).get("game:slot:3")),
	]
	var inventory := EnvironmentSemanticInventoryScript.for_instance(environment, library, interactions)
	var exact := EnvironmentSemanticInventoryScript.exact_collections(inventory)
	for identity in ["game::game:slot", "game::game:slot:2", "game::game:slot:3"]:
		if not _array(exact.get("interactions", [])).has(identity):
			failures.append("Exact multi-fixture inventory collapsed distinct Grand Casino target %s." % identity)
	if not _array(exact.get("routes", [])).has("base::world:bar") or _array(exact.get("interactions", [])).has("base::world:bar"):
		failures.append("World/layer route domains collided with exact rendered game-fixture identities.")


static func _check_exact_collision_and_geometry(library: ContentLibrary, failures: Array) -> void:
	var environment := _exact_environment()
	var record := _interaction_record("game", "game:slot", "game:slot")
	var duplicate_inventory := EnvironmentSemanticInventoryScript.for_instance(environment, library, [record, record.duplicate(true)])
	if EnvironmentSemanticInventoryScript.validate(duplicate_inventory).is_empty():
		failures.append("Exact semantic inventory accepted duplicate base interaction identity/presentation id.")
	var mismatched := record.duplicate(true)
	mismatched["normalized_hit_rect"] = {"x": 0.6, "y": 0.6, "w": 0.1, "h": 0.2}
	var mismatch_inventory := EnvironmentSemanticInventoryScript.for_instance(environment, library, [mismatched])
	if EnvironmentSemanticInventoryScript.validate(mismatch_inventory).is_empty():
		failures.append("Exact semantic inventory accepted interaction geometry that disagreed with final layout.")
	var missing_layout := environment.duplicate(true)
	missing_layout["layout"] = {"object_rects": {}}
	var missing_inventory := EnvironmentSemanticInventoryScript.for_instance(missing_layout, library, [record])
	if EnvironmentSemanticInventoryScript.validate(missing_inventory).is_empty():
		failures.append("Exact semantic inventory accepted a base interaction without final geometry.")


static func _check_presentation_actor_rejection(failures: Array) -> void:
	var record := {
		"interactive": true,
		"object_id": "game:slot",
		"owner_namespace": "game",
		"stable_object_id": "game:slot",
		"source_kind": "environment_instance_ui",
		"source_field": "game_ids",
		"source_record_id": "slot",
		"available_actions": [{"id": "use", "label": "Use", "input_action": "confirm", "non_color_state": "ready"}],
		"enabled": true,
		"coordinate_space": "normalized_environment_board",
		"coordinate_board_size": {"w": 900, "h": 430},
		"normalized_hit_rect": {"x": 0.1, "y": 0.1, "w": 0.1, "h": 0.2},
		"pixel_hit_bounds": {"w": 90, "h": 86},
		"semantic_actor": {"id": "forged", "actor_id": "dealer_actor", "anchor_id": "stage"},
	}
	var result := EnvironmentBaseSemanticRecordsScript.from_interactable_records([record])
	if bool(result.get("ok", true)) or not _contains_text(_array(result.get("errors", [])), "cannot promote presentation metadata"):
		failures.append("Presentation interaction metadata was allowed to promote itself into a semantic actor.")


static func _check_semantic_proof_reference_persistence(failures: Array) -> void:
	var digest := "semantic-proof-reference".sha256_text()
	var source := _exact_environment()
	source["scenario_semantic_inventory_version"] = 1
	source["scenario_semantic_digest"] = digest
	var restored := EnvironmentInstanceScript.from_dict(source).to_dict()
	if int(restored.get("scenario_semantic_inventory_version", 0)) != 1 or str(restored.get("scenario_semantic_digest", "")) != digest:
		failures.append("EnvironmentInstance did not round-trip the durable semantic inventory version/digest reference.")
	var hostile_digest := "forged-mismatch"
	var hostile := source.duplicate(true)
	hostile["scenario_semantic_digest"] = hostile_digest
	var hostile_restored := EnvironmentInstanceScript.from_dict(hostile).to_dict()
	if int(hostile_restored.get("scenario_semantic_inventory_version", 0)) != 1 or str(hostile_restored.get("scenario_semantic_digest", "")) != hostile_digest:
		failures.append("EnvironmentInstance erased a hostile persisted digest mismatch instead of preserving it for fail-closed rebuild comparison.")
	var incomplete_pairs: Array = [
		{"scenario_semantic_inventory_version": 1},
		{"scenario_semantic_digest": digest},
		{"scenario_semantic_inventory_version": 0, "scenario_semantic_digest": digest},
		{"scenario_semantic_inventory_version": 1, "scenario_semantic_digest": "   "},
	]
	for incomplete_pair in incomplete_pairs:
		var incomplete := _exact_environment()
		for key in incomplete_pair.keys(): incomplete[key] = incomplete_pair.get(key)
		var normalized := EnvironmentInstanceScript.from_dict(incomplete).to_dict()
		if normalized.has("scenario_semantic_inventory_version") or normalized.has("scenario_semantic_digest"):
			failures.append("EnvironmentInstance serialized a one-sided/empty semantic proof reference: %s." % JSON.stringify(incomplete_pair))
	var empty := EnvironmentInstanceScript.from_dict(_exact_environment()).to_dict()
	if empty.has("scenario_semantic_inventory_version") or empty.has("scenario_semantic_digest"):
		failures.append("EnvironmentInstance serialized empty semantic proof reference fields.")


static func _check_exclusive_offer_key_rejection(library: ContentLibrary, failures: Array) -> void:
	var prior_errors := library.validation_errors.duplicate(true)
	library._validate_scenario_mutations(
		"hostile_exclusive_offer",
		"mutations",
		{"exclusive_opportunity": {"offer_id": "deck"}},
		{},
		{},
		{},
		{}
	)
	var emitted: Array = []
	for index in range(prior_errors.size(), library.validation_errors.size()): emitted.append(library.validation_errors[index])
	library.validation_errors = prior_errors
	var expected := "environment_scenarios hostile_exclusive_offer mutations exclusive_opportunity contains unknown key: offer_id"
	if not emitted.has(expected):
		failures.append("Scenario authoring did not reject exclusive_opportunity.offer_id as an unknown key.")


static func _check_legacy_round_trip(library: ContentLibrary, failures: Array) -> void:
	var plain := _generated_environment(library, "bar", {}, 7401)
	var restored_plain := EnvironmentInstanceScript.from_dict(plain).to_dict()
	if not _json_equal(plain, restored_plain):
		failures.append("Legacy no-sequence EnvironmentInstance did not round-trip canonically.")
	for key in ["semantic_anchors", "semantic_zones", "semantic_actors"]:
		if plain.has(key) or restored_plain.has(key):
			failures.append("Legacy no-sequence EnvironmentInstance gained absent %s state." % key)
	var definition := library.scenario("back_alley_street_craps")
	var selected := _generated_environment(library, "back_alley", definition, 7402)
	var restored_selected := EnvironmentInstanceScript.from_dict(selected).to_dict()
	for key in ["scenario_id", "game_ids", "event_ids", "item_offers", "service_ids", "lender_hooks", "travel_hooks", "next_archetypes", "layout"]:
		if not _json_equal(selected.get(key), restored_selected.get(key)):
			failures.append("Selected legacy scenario EnvironmentInstance lost %s on save/load." % key)


static func _check_semantic_save_shapes(failures: Array) -> void:
	var source := _semantic_environment()
	source["scenario_state"] = {}
	var restored := EnvironmentInstanceScript.from_dict(source).to_dict()
	for key in ["semantic_zones", "semantic_anchors", "semantic_actors"]:
		if not _json_equal(source.get(key), restored.get(key)):
			failures.append("EnvironmentInstance did not preserve exact %s save shape." % key)
	var plain := EnvironmentInstanceScript.from_dict({"id": "plain", "layout": {}}).to_dict()
	for key in ["semantic_zones", "semantic_anchors", "semantic_actors"]:
		if plain.has(key): failures.append("EnvironmentInstance serialized absent semantic field %s." % key)
	var layered := _exact_environment()
	layered["environment_layer_schema_version"] = 1
	layered["current_layer_id"] = "front"
	layered["default_layer_id"] = "front"
	layered["layer_ids"] = ["front"]
	layered["layer_states"] = {"front": {"scenario_semantic_action_digest": "ephemeral", "scenario_base_producer_context": {"numbers_venue_ids": ["bar"], "numbers_silas_present": true, "delivery_handoff_node_id": "bar"}}}
	var layered_restored := EnvironmentInstanceScript.from_dict(layered).to_dict()
	var durable_front := _dict(_dict(layered_restored.get("layer_states", {})).get("front", {}))
	if durable_front.has("scenario_base_producer_context") or durable_front.has("scenario_semantic_action_digest"):
		failures.append("EnvironmentInstance persisted ephemeral scenario producer/action authority inside durable layer state.")


static func _check_all_scenario_catalogs(library: ContentLibrary, failures: Array) -> void:
	var scenario_ids: Dictionary = {}
	var scenario_count := 0
	var archetype_ids: Array = library.environment_scenarios.keys()
	archetype_ids.sort()
	for archetype_id_value in archetype_ids:
		for definition_value in _array(library.environment_scenarios.get(archetype_id_value, [])):
			if typeof(definition_value) != TYPE_DICTIONARY:
				failures.append("Environment scenario pack contains a non-dictionary catalog row.")
				continue
			var definition := (definition_value as Dictionary).duplicate(true)
			var scenario_id := str(definition.get("id", ""))
			scenario_count += 1
			if scenario_id.is_empty() or scenario_ids.has(scenario_id):
				failures.append("Environment scenario catalog census found empty/duplicate id %s." % scenario_id)
				continue
			scenario_ids[scenario_id] = true
			var first := library.scenario_target_catalog(definition)
			var second := library.scenario_target_catalog(definition)
			if not _json_equal(first, second):
				failures.append("Scenario target catalog %s was not deterministic." % scenario_id)
			if not _array(first.get("errors", [])).is_empty() or not EnvironmentSemanticInventoryScript.validate(_dict(first.get("inventory", {}))).is_empty():
				failures.append("Scenario target catalog %s was invalid: %s." % [scenario_id, JSON.stringify(first.get("errors", []))])
			var seen: Dictionary = {}
			for record_value in _array(first.get("records", [])):
				var record := _dict(record_value)
				var key := "%s|%s" % [str(record.get("collection", "")), str(record.get("owned_identity", ""))]
				if not _same_string_set(record.keys(), RECORD_KEYS) or seen.has(key):
					failures.append("Scenario target catalog %s emitted open/duplicate semantic records." % scenario_id)
					break
				seen[key] = true
	if scenario_count != 55:
		failures.append("Environment scenario target-catalog census expected 55 definitions, found %d." % scenario_count)


static func _generated_environment(library: ContentLibrary, archetype_id: String, definition: Dictionary, seed: int) -> Dictionary:
	return _generated_from_archetype(library.environment_archetype(archetype_id), library, seed, definition)


static func _generated_from_archetype(archetype: Dictionary, library: ContentLibrary, seed: int, definition: Dictionary = {}) -> Dictionary:
	var rng := RngStream.new()
	rng.configure(seed)
	return EnvironmentInstanceScript.from_archetype(archetype, 1, rng, library, {}, definition).to_dict()


static func _rare_route_archetype(_library: ContentLibrary, chance: int) -> Dictionary:
	return {
		"id": "rare_route_fixture",
		"kind": "shop",
		"tier": 1,
		"name_prefixes": ["Rare"],
		"name_nouns": ["Route"],
		"layout": {},
		"game_pool": [],
		"game_count": [0, 0],
		"item_pool": [],
		"item_count": [0, 0],
		"event_pool": [],
		"event_count": [0, 0],
		"service_pool": [],
		"lender_hooks": [],
		"travel_hooks": [],
		"next_archetypes": [],
		"rare_next_archetypes": ["bar"],
		"rare_next_chance_percent": chance,
	}


static func _semantic_library() -> FixtureLibrary:
	var library := FixtureLibrary.new()
	library.characters_by_id = {"dealer_actor": {"id": "dealer_actor"}}
	library.events_by_id = {
		"actor_event": {
			"id": "actor_event",
			"semantic_actor": {"id": "dealer", "actor_id": "dealer_actor", "anchor_id": "stage", "behavior": "idle"},
			"payload": {"choices": [{"id": "talk"}]},
		},
	}
	return library


static func _semantic_actor() -> Dictionary:
	return {"id": "clerk", "actor_id": "dealer_actor", "anchor_id": "stage", "behavior": "idle"}


static func _semantic_archetype() -> Dictionary:
	return {
		"id": "semantic_fixture",
		"layout": {},
		"semantic_zones": {
			"floor": {"bounds": [0, 0, 200, 200]},
			"side": {"bounds": [200, 0, 100, 200]},
		},
		"semantic_anchors": {"stage": {"zone_id": "floor", "position": [50, 50]}},
		"semantic_actors": [_semantic_actor()],
	}


static func _semantic_environment() -> Dictionary:
	var environment := _semantic_archetype()
	environment["id"] = "semantic_fixture_001"
	environment["archetype_id"] = "semantic_fixture"
	environment["world_node_id"] = "semantic_fixture"
	environment["layout"] = {"object_rects": {}}
	environment["game_ids"] = []
	environment["event_ids"] = ["actor_event"]
	environment["item_offers"] = []
	environment["service_ids"] = []
	environment["lender_hooks"] = []
	environment["travel_hooks"] = []
	environment["next_archetypes"] = []
	return environment


static func _exact_environment() -> Dictionary:
	return {
		"id": "exact_fixture_001",
		"archetype_id": "bar",
		"world_node_id": "bar",
		"layout": {"object_rects": {"game:slot": {"x": 0.1, "y": 0.1, "w": 0.1, "h": 0.2}}},
		"game_ids": ["slot"],
		"event_ids": [],
		"item_offers": [],
		"service_ids": [],
		"lender_hooks": [],
		"travel_hooks": [],
		"next_archetypes": [],
		"semantic_zones": {},
		"semantic_anchors": {},
		"semantic_actors": [],
	}


static func _producer_presentation_record(object_id: String, object_type: String, source_id: String, parent_id: String) -> Dictionary:
	return {
		"object_id": object_id,
		"object_type": object_type,
		"source_id": source_id,
		"parent_id": parent_id,
		"interactive": true,
		"enabled": true,
		"available_actions": [{"id": "use", "label": "Use"}],
		"focus_rect": {"x": 0.1, "y": 0.1, "w": 0.1, "h": 0.2},
	}


static func _interaction_record(owner: String, stable_id: String, presentation_id: String, rect_value: Variant = null) -> Dictionary:
	var rect := {"x": 0.1, "y": 0.1, "w": 0.1, "h": 0.2}
	if typeof(rect_value) == TYPE_DICTIONARY: rect = (rect_value as Dictionary).duplicate(true)
	return {
		"owner_namespace": owner,
		"stable_object_id": stable_id,
		"presentation_object_id": presentation_id,
		"normalized_hit_rect": rect,
		"source_kind": "environment_instance_ui",
		"source_field": "game_ids",
		"source_record_id": "slot",
		"label": presentation_id,
		"enabled": true,
		"available_actions": [{"id": "use"}],
	}


static func _record_for(inventory: Dictionary, collection: String, identity: String) -> Dictionary:
	for record_value in _array(inventory.get("records", [])):
		var record := _dict(record_value)
		if str(record.get("collection", "")) == collection and str(record.get("owned_identity", "")) == identity:
			return record
	return {}


static func _offer_ids(value: Variant) -> Array:
	var result: Array = []
	for offer_value in _array(value):
		var offer_id := str(_dict(offer_value).get("id", ""))
		if not offer_id.is_empty() and not result.has(offer_id): result.append(offer_id)
	return result


static func _same_string_set(left_value: Variant, right_value: Variant) -> bool:
	var left: Array = []
	for value in _array(left_value): left.append(str(value))
	var right: Array = []
	for value in _array(right_value): right.append(str(value))
	left.sort()
	right.sort()
	return left == right


static func _json_equal(left: Variant, right: Variant) -> bool:
	return JSON.stringify(_canonical(left)) == JSON.stringify(_canonical(right))


static func _canonical(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		var keys: Array = (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key in keys: result[str(key)] = _canonical((value as Dictionary).get(key))
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for item in value as Array: result.append(_canonical(item))
		return result
	return value


static func _contains_text(values: Array, needle: String) -> bool:
	for value in values:
		if str(value).contains(needle): return true
	return false


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
