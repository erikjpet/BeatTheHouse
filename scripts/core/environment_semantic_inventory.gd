class_name EnvironmentSemanticInventory
extends RefCounted

const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const ArtContractsScript := preload("res://scripts/core/art_contracts.gd")
const BaseSemanticRecordsScript := preload("res://scripts/core/environment_base_semantic_records.gd")

# Immutable proof of semantic identities that genuinely exist in authored
# archetypes or a finalized EnvironmentInstance. Presentation IDs are retained
# as metadata; operation identities are domain-qualified and collision-safe.

const SCHEMA_VERSION := 1
const COLLECTION_KEYS := ["scene_objects", "interactions", "actors", "services", "games", "routes", "anchors", "zones"]
const RECORD_KEYS := ["collection", "owner_namespace", "stable_object_id", "owned_identity", "presentation_object_id", "availability", "source_kind", "source_field", "source_record_id", "record"]
const DIAGNOSTIC_CODES := ["possible_only", "wrong_collection", "wrong_owner", "layer_mismatch", "unknown_target"]
const SOURCE_KINDS := ["environment_archetype", "scenario_selection", "environment_instance", "environment_instance_ui", "environment_event"]


static func event_choice_index(event_ids: Array, library: Variant) -> Dictionary:
	var result: Dictionary = {}
	if library == null or not library.has_method("event"): return result
	for event_id_value in event_ids:
		var event_id := str(event_id_value).strip_edges()
		var event_definition := _dict(library.call("event", event_id))
		if event_definition.is_empty(): continue
		var choices: Array = []
		for choice_value in _array(_dict(event_definition.get("payload", {})).get("choices", [])):
			var choice_id := str(_dict(choice_value).get("id", "")).strip_edges()
			if not choice_id.is_empty() and not choices.has(choice_id): choices.append(choice_id)
		result[event_id] = choices
	return result


static func effective_archetype(archetype: Dictionary, layer_id: String = "") -> Dictionary:
	var clean_layer := layer_id.strip_edges()
	if clean_layer.is_empty(): return archetype.duplicate(true)
	var layers := _dict(archetype.get("layers", {}))
	if not layers.has(clean_layer): return {}
	return _effective_layer(archetype, _dict(layers.get(clean_layer, {})), clean_layer)


static func for_archetype(archetype: Dictionary, library: Variant = null, layer_id: String = "") -> Dictionary:
	var guaranteed := _empty_collections()
	var possible := _empty_collections()
	var presentation_ids: Dictionary = {}
	var provenance: Dictionary = {}
	var errors: Array = []
	var selected := archetype
	if not layer_id.strip_edges().is_empty():
		var layers := _dict(archetype.get("layers", {}))
		if not layers.has(layer_id): return _sealed("catalog", str(archetype.get("id", "")), layer_id, guaranteed, possible, presentation_ids, ["inventory layer is not authored by this archetype."], provenance)
		selected = _effective_layer(archetype, _dict(layers.get(layer_id, {})), layer_id)
	for fixture_value in _array(selected.get("object_fixtures", archetype.get("object_fixtures", []))):
		var fixture_id := str(fixture_value)
		if _dict(_dict(selected.get("layout", {})).get("object_rects", {})).has(fixture_id) or _recognized_fixture(selected, fixture_id):
			var fixture_identity := _add_presentation_identity(guaranteed, presentation_ids, "scene_objects", fixture_id)
			if not fixture_identity.is_empty(): _set_provenance(provenance, "scene_objects", fixture_identity, "environment_archetype", "object_fixtures", fixture_id)
			if _recognized_fixture(selected, fixture_id) and not fixture_identity.is_empty():
				_add(guaranteed, "interactions", fixture_identity)
				presentation_ids["interactions|%s" % fixture_identity] = fixture_id
				_set_provenance(provenance, "interactions", fixture_identity, "environment_archetype", "object_fixtures", fixture_id)
	for object_id_value in _dict(_dict(selected.get("layout", {})).get("object_rects", {})).keys():
		var object_id := str(object_id_value)
		var identity := _add_presentation_identity(guaranteed, presentation_ids, "scene_objects", object_id)
		if not identity.is_empty(): _set_provenance(provenance, "scene_objects", identity, "environment_archetype", "layout.object_rects", object_id)
		# Geometry proves a renderable scene object, not an interaction.
	var semantic_content := _validated_semantic_content(selected, library, "environment_archetype", errors)
	for zone_id_value in _dict(semantic_content.get("zones", {})).keys():
		var zone_id := str(zone_id_value)
		var identity := "base::zone:%s" % zone_id
		_add(guaranteed, "zones", identity)
		_set_provenance(provenance, "zones", identity, "environment_archetype", "semantic_zones", zone_id, _dict(_dict(semantic_content.get("zones", {})).get(zone_id, {})))
	for anchor_id_value in _dict(semantic_content.get("anchors", {})).keys():
		var anchor_id := str(anchor_id_value)
		var identity := "base::anchor:%s" % anchor_id
		_add(guaranteed, "anchors", identity)
		_set_provenance(provenance, "anchors", identity, "environment_archetype", "semantic_anchors", anchor_id, _dict(_dict(semantic_content.get("anchors", {})).get(anchor_id, {})))
	for actor_value in _array(semantic_content.get("actors", [])):
		var actor := _dict(actor_value)
		var actor_id := str(actor.get("id", ""))
		var identity := "base::actor:%s" % actor_id
		_add(guaranteed, "actors", identity)
		_set_provenance(provenance, "actors", identity, "environment_archetype", "semantic_actors", actor_id, actor)
	for service_id in _ids(selected.get("service_pool", [])):
		if library == null or not library.has_method("service") or not _dict(library.call("service", service_id)).is_empty():
			var domain_identity := "service::%s" % service_id
			var rendered_identity := "service::service:%s" % service_id
			_add(guaranteed, "services", domain_identity)
			_set_provenance(provenance, "services", domain_identity, "environment_archetype", "service_pool", service_id)
			_add_rendered_identity(guaranteed, presentation_ids, rendered_identity, "service:%s" % service_id)
			for collection_key in ["scene_objects", "interactions"]: _set_provenance(provenance, collection_key, rendered_identity, "environment_archetype", "service_pool", service_id)
	for game_id in _ids(selected.get("game_pool", [])):
		if library != null and library.has_method("game") and _dict(library.call("game", game_id)).is_empty():
			continue
		var target := possible
		var required_games := _ids(selected.get("required_game_ids", []))
		var game_pool := _ids(selected.get("game_pool", []))
		if required_games.has(game_id) or _minimum_count(selected.get("game_count", 1)) >= game_pool.size():
			target = guaranteed
		var domain_identity := "game::%s" % game_id
		_add(target, "games", domain_identity)
		_set_provenance(provenance, "games", domain_identity, "environment_archetype", "game_pool", game_id)
		var fixture_counts := _dict(_dict(selected.get("layout", {})).get("game_fixture_counts", {}))
		var fixture_count := maxi(1, int(fixture_counts.get(game_id, 1)))
		for fixture_index in range(fixture_count):
			var presentation_id := "game:%s" % game_id if fixture_index == 0 else "game:%s:%d" % [game_id, fixture_index + 1]
			var rendered_identity := "game::%s" % presentation_id
			_add_rendered_identity(target, presentation_ids, rendered_identity, presentation_id)
			for collection_key in ["scene_objects", "interactions"]: _set_provenance(provenance, collection_key, rendered_identity, "environment_archetype", "game_pool", game_id)
	var exclusive_opportunity := _dict(selected.get("scenario_exclusive_opportunity", {}))
	var exclusive_game_id := str(exclusive_opportunity.get("game_id", "")).strip_edges()
	if not exclusive_game_id.is_empty() and (library == null or not library.has_method("game") or not _dict(library.call("game", exclusive_game_id)).is_empty()):
		var domain_identity := "game::%s" % exclusive_game_id
		_add(guaranteed, "games", domain_identity)
		_set_provenance(provenance, "games", domain_identity, "scenario_selection", "scenario_exclusive_opportunity.game_id", exclusive_game_id)
		var fixture_counts := _dict(_dict(selected.get("layout", {})).get("game_fixture_counts", {}))
		var fixture_count := maxi(1, int(fixture_counts.get(exclusive_game_id, 1)))
		for fixture_index in range(fixture_count):
			var presentation_id := "game:%s" % exclusive_game_id if fixture_index == 0 else "game:%s:%d" % [exclusive_game_id, fixture_index + 1]
			var rendered_identity := "game::%s" % presentation_id
			_add_rendered_identity(guaranteed, presentation_ids, rendered_identity, presentation_id)
			for collection_key in ["scene_objects", "interactions"]: _set_provenance(provenance, collection_key, rendered_identity, "scenario_selection", "scenario_exclusive_opportunity.game_id", exclusive_game_id)
	elif not exclusive_game_id.is_empty(): errors.append("scenario exclusive opportunity references unknown game %s." % exclusive_game_id)
	for event_id in _ids(selected.get("event_pool", [])):
		if library == null or not library.has_method("event") or not _dict(library.call("event", event_id)).is_empty():
			var rendered_identity := "event::event:%s" % event_id
			_add_rendered_identity(possible, presentation_ids, rendered_identity, "event:%s" % event_id)
			for collection_key in ["scene_objects", "interactions"]: _set_provenance(provenance, collection_key, rendered_identity, "environment_archetype", "event_pool", event_id)
	var exclusive_event_id := str(exclusive_opportunity.get("event_id", "")).strip_edges()
	if not exclusive_event_id.is_empty() and (library == null or not library.has_method("event") or not _dict(library.call("event", exclusive_event_id)).is_empty()):
		var rendered_identity := "event::event:%s" % exclusive_event_id
		_add_rendered_identity(guaranteed, presentation_ids, rendered_identity, "event:%s" % exclusive_event_id)
		for collection_key in ["scene_objects", "interactions"]: _set_provenance(provenance, collection_key, rendered_identity, "scenario_selection", "scenario_exclusive_opportunity.event_id", exclusive_event_id)
	elif not exclusive_event_id.is_empty(): errors.append("scenario exclusive opportunity references unknown event %s." % exclusive_event_id)
	var item_pool := _ids(selected.get("item_pool", []))
	var item_target := guaranteed if not item_pool.is_empty() and _minimum_count(selected.get("item_count", 0)) >= item_pool.size() else possible
	for item_id in item_pool:
		if library == null or not library.has_method("item") or not _dict(library.call("item", item_id)).is_empty():
			var rendered_identity := "base::item:%s" % item_id
			_add_rendered_identity(item_target, presentation_ids, rendered_identity, "item:%s" % item_id)
			for collection_key in ["scene_objects", "interactions"]: _set_provenance(provenance, collection_key, rendered_identity, "environment_archetype", "item_pool", item_id)
		else: errors.append("environment archetype item_pool references unknown item %s." % item_id)
	for offer_value in _array(selected.get("scenario_item_offers", [])):
		if typeof(offer_value) != TYPE_DICTIONARY:
			errors.append("scenario_item_offers entry must be a dictionary.")
			continue
		var offer_id := str((offer_value as Dictionary).get("id", "")).strip_edges()
		if not offer_id.is_empty() and (library == null or not library.has_method("item") or not _dict(library.call("item", offer_id)).is_empty()):
			var rendered_identity := "base::item:%s" % offer_id
			_add_rendered_identity(guaranteed, presentation_ids, rendered_identity, "item:%s" % offer_id)
			for collection_key in ["scene_objects", "interactions"]: _set_provenance(provenance, collection_key, rendered_identity, "scenario_selection", "scenario_item_offers", offer_id)
		elif offer_id.is_empty(): errors.append("scenario_item_offers entry requires an exact item id.")
		else: errors.append("scenario_item_offers references unknown item %s." % offer_id)
	for lender_id in _ids(selected.get("lender_hooks", [])):
		if library == null or not library.has_method("lender") or not _dict(library.call("lender", lender_id)).is_empty():
			var lender_target := guaranteed if _ids(selected.get("required_lender_hooks", [])).has(lender_id) else possible
			var domain_identity := "service::%s" % lender_id
			var rendered_identity := "service::lender:%s" % lender_id
			_add(lender_target, "services", domain_identity)
			_set_provenance(provenance, "services", domain_identity, "environment_archetype", "lender_hooks", lender_id)
			_add_rendered_identity(lender_target, presentation_ids, rendered_identity, "lender:%s" % lender_id)
			for collection_key in ["scene_objects", "interactions"]: _set_provenance(provenance, collection_key, rendered_identity, "environment_archetype", "lender_hooks", lender_id)
	var route_ids := _ids(_array(selected.get("travel_hooks", archetype.get("travel_hooks", []))) + _array(selected.get("next_archetypes", archetype.get("next_archetypes", []))))
	for route_id in route_ids:
		var identity := "base::world:%s" % route_id
		_add(guaranteed, "routes", identity)
		_set_provenance(provenance, "routes", identity, "environment_archetype", "travel_hooks+next_archetypes", route_id)
	var rare_route_ids := _ids(selected.get("rare_next_archetypes", archetype.get("rare_next_archetypes", [])))
	var rare_route_chance := clampi(int(selected.get("rare_next_chance_percent", archetype.get("rare_next_chance_percent", 8))), 0, 100)
	var rare_target := guaranteed if rare_route_chance >= 100 else possible
	if rare_route_chance > 0:
		for route_id in rare_route_ids:
			if library != null and not _library_route_target(library, route_id):
				errors.append("rare_next_archetypes references unknown route %s." % route_id)
				continue
			var identity := "base::world:%s" % route_id
			_add(rare_target, "routes", identity)
			_set_provenance(provenance, "routes", identity, "environment_archetype", "rare_next_archetypes", route_id)
	if not route_ids.is_empty() or rare_route_chance >= 100 and not rare_route_ids.is_empty():
		_add_rendered_identity(guaranteed, presentation_ids, "base::travel:leave", "travel:leave")
		for collection_key in ["scene_objects", "interactions"]: _set_provenance(provenance, collection_key, "base::travel:leave", "environment_archetype", "travel_hooks+next_archetypes+rare_next_archetypes", "leave")
	elif rare_route_chance > 0 and not rare_route_ids.is_empty():
		_add_rendered_identity(possible, presentation_ids, "base::travel:leave", "travel:leave")
		for collection_key in ["scene_objects", "interactions"]: _set_provenance(provenance, collection_key, "base::travel:leave", "environment_archetype", "rare_next_archetypes", "leave")
	for transition_value in _array(selected.get("layer_transitions", [])):
		var target_layer := str(_dict(transition_value).get("target_layer_id", "")).strip_edges()
		if not target_layer.is_empty():
			var route_identity := "base::layer:%s" % target_layer
			var rendered_identity := "base::environment_layer:%s" % target_layer
			_add(guaranteed, "routes", route_identity)
			_set_provenance(provenance, "routes", route_identity, "environment_archetype", "layer_transitions", target_layer)
			_add_rendered_identity(guaranteed, presentation_ids, rendered_identity, "environment_layer:%s" % target_layer)
			for collection_key in ["scene_objects", "interactions"]: _set_provenance(provenance, collection_key, rendered_identity, "environment_archetype", "layer_transitions", target_layer)
	var narrative_flags := _dict(selected.get("local_narrative_flags", {}))
	for fixture_value in _array(narrative_flags.get("casino_fixtures", [])):
		var fixture_id := str(_dict(fixture_value).get("id", "")).strip_edges()
		if not fixture_id.is_empty():
			var rendered_identity := "base::casino_fixture:%s" % fixture_id
			_add_rendered_identity(guaranteed, presentation_ids, rendered_identity, "casino_fixture:%s" % fixture_id)
			for collection_key in ["scene_objects", "interactions"]: _set_provenance(provenance, collection_key, rendered_identity, "environment_archetype", "local_narrative_flags.casino_fixtures", fixture_id)
	for room_id in _ids(narrative_flags.get("casino_room_targets", [])):
		var route_identity := "base::room:%s" % room_id
		var rendered_identity := "base::travel:%s" % room_id
		_add(guaranteed, "routes", route_identity)
		_set_provenance(provenance, "routes", route_identity, "environment_archetype", "local_narrative_flags.casino_room_targets", room_id)
		_add_rendered_identity(guaranteed, presentation_ids, rendered_identity, "travel:%s" % room_id)
		for collection_key in ["scene_objects", "interactions"]: _set_provenance(provenance, collection_key, rendered_identity, "environment_archetype", "local_narrative_flags.casino_room_targets", room_id)
	_remove_guaranteed_from_possible(guaranteed, possible)
	return _sealed("catalog", str(archetype.get("id", "")), layer_id if not layer_id.is_empty() else str(selected.get("current_layer_id", "")), guaranteed, possible, presentation_ids, errors, provenance)


static func for_instance(environment: Dictionary, library: Variant = null, base_interactions: Array = [], base_actors: Array = []) -> Dictionary:
	var exact := _empty_collections()
	var presentation_ids: Dictionary = {}
	var provenance: Dictionary = {}
	var errors: Array = []
	var layout_rects := _dict(_dict(environment.get("layout", {})).get("object_rects", {}))
	for object_id_value in layout_rects.keys():
		var scene_identity := _add_presentation_identity(exact, presentation_ids, "scene_objects", str(object_id_value))
		if scene_identity.is_empty(): errors.append("environment layout object %s cannot form a canonical owned identity." % str(object_id_value))
		else: _set_provenance(provenance, "scene_objects", scene_identity, "environment_instance", "layout.object_rects", str(object_id_value))
	var interaction_identities: Dictionary = {}
	var interaction_presentations: Dictionary = {}
	for record_value in base_interactions:
		if typeof(record_value) != TYPE_DICTIONARY:
			errors.append("base interaction inventory entry must be a dictionary.")
			continue
		var record := record_value as Dictionary
		var identity := "%s::%s" % [str(record.get("owner_namespace", "")), str(record.get("stable_object_id", ""))]
		var presentation_id := str(record.get("presentation_object_id", record.get("object_id", "")))
		var dynamic_record := BaseSemanticRecordsScript.is_dynamic_interaction_record(record)
		var dynamic_errors: Array = []
		if dynamic_record:
			dynamic_errors.append_array(BaseSemanticRecordsScript.validate_dynamic_interaction_record(record, environment, library))
			var resolved_dynamic := OperationRegistryScript.resolve_interactions([record], [])
			if not bool(resolved_dynamic.get("ok", false)): dynamic_errors.append_array(_array(resolved_dynamic.get("errors", [])))
		if not _valid_identity(identity): errors.append("base interaction inventory contains an invalid identity.")
		elif interaction_identities.has(identity) or interaction_presentations.has(presentation_id): errors.append("base interaction inventory contains duplicate/colliding identity or presentation id %s." % presentation_id)
		elif dynamic_record and not dynamic_errors.is_empty(): errors.append_array(dynamic_errors)
		elif not layout_rects.has(presentation_id) and not dynamic_record: errors.append("base interaction %s has no exact final layout geometry or authorized dynamic producer." % presentation_id)
		elif layout_rects.has(presentation_id) and not _same_normalized_rect(record.get("normalized_hit_rect", {}), layout_rects.get(presentation_id)):
			errors.append("base interaction %s geometry does not match final layout.object_rects." % presentation_id)
		else:
			interaction_identities[identity] = true
			interaction_presentations[presentation_id] = true
			_add(exact, "interactions", identity)
			if not _array(exact.get("scene_objects", [])).has(identity): _add(exact, "scene_objects", identity)
			presentation_ids["interactions|%s" % identity] = presentation_id
			presentation_ids["scene_objects|%s" % identity] = presentation_id
			var source_kind := str(record.get("source_kind", ""))
			var source_field := str(record.get("source_field", ""))
			var source_record_id := str(record.get("source_record_id", ""))
			if source_kind.is_empty() and source_field.is_empty() and source_record_id.is_empty() and layout_rects.has(presentation_id):
				source_kind = "environment_instance"
				source_field = "layout.object_rects"
				source_record_id = presentation_id
			_set_provenance(provenance, "interactions", identity, source_kind, source_field, source_record_id)
			if not provenance.has("scene_objects|%s" % identity): _set_provenance(provenance, "scene_objects", identity, source_kind, source_field, source_record_id)
	for service_id in _ids(environment.get("service_ids", [])):
		if library != null and library.has_method("service") and _dict(library.call("service", service_id)).is_empty(): errors.append("environment instance references an unknown service %s." % service_id)
		else:
			var identity := "service::%s" % service_id
			_add(exact, "services", identity)
			_set_provenance(provenance, "services", identity, "environment_instance", "service_ids", service_id)
	for game_id in _ids(environment.get("game_ids", [])):
		if library != null and library.has_method("game") and _dict(library.call("game", game_id)).is_empty(): errors.append("environment instance references an unknown game %s." % game_id)
		else:
			var identity := "game::%s" % game_id
			_add(exact, "games", identity)
			_set_provenance(provenance, "games", identity, "environment_instance", "game_ids", game_id)
	for event_id in _ids(environment.get("event_ids", [])):
		if library != null and library.has_method("event") and _dict(library.call("event", event_id)).is_empty(): errors.append("environment instance references an unknown event %s." % event_id)
		# The saved id proves the event source, but only final base records prove an interaction.
	for offer_value in _array(environment.get("item_offers", [])):
		var offer_id := str(_dict(offer_value).get("id", ""))
		if offer_id.is_empty(): errors.append("environment instance contains an item offer without an exact id.")
		elif library != null and library.has_method("item") and _dict(library.call("item", offer_id)).is_empty(): errors.append("environment instance references an unknown item offer %s." % offer_id)
	for lender_id in _ids(environment.get("lender_hooks", [])):
		if library != null and library.has_method("lender") and _dict(library.call("lender", lender_id)).is_empty(): errors.append("environment instance references an unknown lender %s." % lender_id)
		else:
			var identity := "service::%s" % lender_id
			_add(exact, "services", identity)
			_set_provenance(provenance, "services", identity, "environment_instance", "lender_hooks", lender_id)
	for route_id in _ids(_array(environment.get("travel_hooks", [])) + _array(environment.get("next_archetypes", []))):
		if library != null and not _library_route_target(library, route_id): errors.append("environment instance references an unknown world route %s." % route_id)
		else:
			var identity := "base::world:%s" % route_id
			_add(exact, "routes", identity)
			_set_provenance(provenance, "routes", identity, "environment_instance", "travel_hooks+next_archetypes", route_id)
	for transition_value in _array(environment.get("layer_transitions", [])):
		var target_layer := str(_dict(transition_value).get("target_layer_id", "")).strip_edges()
		if not target_layer.is_empty() and not _ids(environment.get("layer_ids", [])).has(target_layer): errors.append("environment instance references an unauthored layer transition %s." % target_layer)
		elif not target_layer.is_empty():
			var identity := "base::layer:%s" % target_layer
			_add(exact, "routes", identity)
			_set_provenance(provenance, "routes", identity, "environment_instance", "layer_transitions", target_layer)
	for room_id in _ids(_dict(environment.get("local_narrative_flags", {})).get("casino_room_targets", [])):
		if library != null and (not library.has_method("environment_archetype") or _dict(library.call("environment_archetype", room_id)).is_empty()): errors.append("environment instance references an unknown room route %s." % room_id)
		else:
			var identity := "base::room:%s" % room_id
			_add(exact, "routes", identity)
			_set_provenance(provenance, "routes", identity, "environment_instance", "local_narrative_flags.casino_room_targets", room_id)
	var semantic_content := _validated_semantic_content(environment, library, "environment_instance", errors)
	for zone_id_value in _dict(semantic_content.get("zones", {})).keys():
		var zone_id := str(zone_id_value)
		var identity := "base::zone:%s" % zone_id
		_add(exact, "zones", identity)
		_set_provenance(provenance, "zones", identity, "environment_instance", "semantic_zones", zone_id, _dict(_dict(semantic_content.get("zones", {})).get(zone_id, {})))
	for anchor_id_value in _dict(semantic_content.get("anchors", {})).keys():
		var anchor_id := str(anchor_id_value)
		var identity := "base::anchor:%s" % anchor_id
		_add(exact, "anchors", identity)
		_set_provenance(provenance, "anchors", identity, "environment_instance", "semantic_anchors", anchor_id, _dict(_dict(semantic_content.get("anchors", {})).get(anchor_id, {})))
	for actor_value in _array(semantic_content.get("actors", [])):
		var actor := _dict(actor_value)
		var actor_id := str(actor.get("id", ""))
		var actor_identity := "base::actor:%s" % actor_id
		_add(exact, "actors", actor_identity)
		_set_provenance(provenance, "actors", actor_identity, "environment_instance", "semantic_actors", actor_id, actor)
	for actor_value in base_actors:
		var dynamic_actor := _validated_dynamic_actor(actor_value, environment, library, semantic_content, errors)
		if dynamic_actor.is_empty(): continue
		var actor_identity := OperationRegistryScript.identity(str(dynamic_actor.get("owner_namespace", "")), str(dynamic_actor.get("stable_object_id", "")))
		if _array(exact.get("actors", [])).has(actor_identity):
			errors.append("base actor inventory contains duplicate identity %s." % actor_identity)
			continue
		_add(exact, "actors", actor_identity)
		_set_provenance(provenance, "actors", actor_identity, str(dynamic_actor.get("source_kind", "")), str(dynamic_actor.get("source_field", "")), str(dynamic_actor.get("source_record_id", "")), _dynamic_actor_payload(dynamic_actor))
	var result := _sealed("instance", str(environment.get("id", "")), str(environment.get("current_layer_id", "")), exact, _empty_collections(), presentation_ids, errors, provenance)
	result["source_provenance"] = _instance_source_provenance(environment, base_interactions, base_actors)
	result["digest"] = _digest(result)
	return result


static func exact_collections(inventory: Dictionary) -> Dictionary:
	if int(inventory.get("schema_version", 0)) != SCHEMA_VERSION or str(inventory.get("kind", "")) != "instance" or str(inventory.get("digest", "")) != _digest(inventory) or not validate(inventory).is_empty(): return {}
	return _dict(inventory.get("guaranteed", {}))


# A valid seal is not portable between rooms or layers. Besides the explicit
# room/layer identity, bind the seal to every authored source collection used
# to build its exact target inventory.
static func validate_instance_binding(inventory: Dictionary, environment: Dictionary) -> Array:
	var errors := validate(inventory)
	if not errors.is_empty(): return errors
	if str(inventory.get("kind", "")) != "instance":
		errors.append("semantic inventory binding requires an instance proof.")
	var expected_environment_id := str(environment.get("id", "")).strip_edges()
	if expected_environment_id.is_empty() or str(inventory.get("environment_id", "")) != expected_environment_id:
		errors.append("semantic inventory proof is not bound to the current environment.")
	if str(inventory.get("layer_id", "")) != str(environment.get("current_layer_id", "")).strip_edges():
		errors.append("semantic inventory proof is not bound to the current environment layer.")
	if _canonical(inventory.get("source_provenance", {})) != _canonical(_instance_source_provenance(environment)):
		errors.append("semantic inventory proof source provenance does not match the current environment.")
	errors.append_array(_validate_consumed_dynamic_sources(inventory, environment))
	return errors


# Live producer context is intentionally not part of the durable inventory
# digest. Only dynamic records actually sealed into this inventory are checked,
# so unrelated Numbers/Silas/delivery churn cannot invalidate a sequence.
static func _validate_consumed_dynamic_sources(inventory: Dictionary, environment: Dictionary) -> Array:
	var errors: Array = []
	var context := _dict(environment.get("scenario_base_producer_context", {}))
	var authority := _array(_dict(inventory.get("source_provenance", {})).get("base_interaction_authority", []))
	for authority_value in authority:
		var record := _dict(authority_value)
		var source_field := str(record.get("source_field", ""))
		var presentation_id := str(record.get("presentation_object_id", ""))
		match source_field:
			"numbers_state.venue_status":
				var venue_id := str(environment.get("archetype_id", environment.get("world_node_id", "")))
				var venue_ids := _ids(context.get("numbers_venue_ids", []))
				if not _closed_id_array(context.get("numbers_venue_ids")) or not venue_ids.has(venue_id):
					errors.append("consumed dynamic target %s is no longer backed by current numbers_state.venue_status." % presentation_id)
			"numbers_state.silas_presence":
				if typeof(context.get("numbers_silas_present")) != TYPE_BOOL or not bool(context.get("numbers_silas_present", false)):
					errors.append("consumed dynamic target %s is no longer backed by current numbers_state.silas_presence." % presentation_id)
			"active_delivery_run.handoff_pending_node_id":
				var node_id := str(environment.get("world_node_id", ""))
				var handoff_id := str(context.get("delivery_handoff_node_id", ""))
				if typeof(context.get("delivery_handoff_node_id")) != TYPE_STRING or handoff_id != handoff_id.strip_edges() or handoff_id != node_id:
					errors.append("consumed dynamic target %s is no longer backed by the current delivery handoff node." % presentation_id)
	return errors


static func _closed_id_array(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY: return false
	var seen: Dictionary = {}
	for item in value as Array:
		if typeof(item) != TYPE_STRING: return false
		var source_id := str(item)
		if source_id != source_id.strip_edges() or source_id.is_empty() or seen.has(source_id): return false
		seen[source_id] = true
	return true


static func guaranteed_collections(inventory: Dictionary) -> Dictionary:
	if int(inventory.get("schema_version", 0)) != SCHEMA_VERSION or str(inventory.get("digest", "")) != _digest(inventory) or not _array(inventory.get("errors", [])).is_empty(): return {}
	return _dict(inventory.get("guaranteed", {}))


static func possible_collections(inventory: Dictionary) -> Dictionary:
	if int(inventory.get("schema_version", 0)) != SCHEMA_VERSION or str(inventory.get("digest", "")) != _digest(inventory) or not _array(inventory.get("errors", [])).is_empty(): return {}
	return _dict(inventory.get("possible", {}))


static func diagnose_declared_targets(inventory: Dictionary, declared_value: Variant, alternate_layers: Dictionary = {}) -> Array:
	var errors := validate(inventory)
	for diagnostic_value in diagnose_declared_targets_structured(inventory, declared_value, alternate_layers):
		errors.append(str(_dict(diagnostic_value).get("message", "")))
	return errors


static func diagnose_declared_targets_structured(inventory: Dictionary, declared_value: Variant, alternate_layers: Dictionary = {}) -> Array:
	var diagnostics: Array = []
	var guaranteed := guaranteed_collections(inventory)
	var possible := possible_collections(inventory)
	var declared := _dict(declared_value)
	for collection_key in COLLECTION_KEYS:
		for identity_value in _array(declared.get(collection_key, [])):
			var identity := str(identity_value)
			if _array(guaranteed.get(collection_key, [])).has(identity): continue
			if _array(possible.get(collection_key, [])).has(identity):
				diagnostics.append(_diagnostic("possible_only", collection_key, identity, identity, collection_key, "", "declared target %s is possible-only in %s and cannot authorize a guaranteed operation" % [identity, collection_key]))
				continue
			var parsed := OperationRegistryScript.parse_owned_identity(identity)
			var stable_id := str(parsed.get("stable_object_id", ""))
			var wrong_collection := ""
			var wrong_owner := ""
			for candidate_collection in COLLECTION_KEYS:
				for candidate_value in _array(guaranteed.get(candidate_collection, [])) + _array(possible.get(candidate_collection, [])):
					var candidate := str(candidate_value)
					if candidate == identity and candidate_collection != collection_key and wrong_collection.is_empty(): wrong_collection = candidate_collection
					var candidate_parsed := OperationRegistryScript.parse_owned_identity(candidate)
					if candidate_collection == collection_key and not stable_id.is_empty() and str(candidate_parsed.get("stable_object_id", "")) == stable_id and candidate != identity and wrong_owner.is_empty(): wrong_owner = candidate
			if not wrong_collection.is_empty():
				diagnostics.append(_diagnostic("wrong_collection", collection_key, identity, identity, wrong_collection, "", "declared target %s belongs to collection %s, not %s" % [identity, wrong_collection, collection_key]))
				continue
			if not wrong_owner.is_empty():
				diagnostics.append(_diagnostic("wrong_owner", collection_key, identity, wrong_owner, collection_key, "", "declared target %s has the wrong owner; catalog identity is %s" % [identity, wrong_owner]))
				continue
			var alternate_layer := ""
			for layer_id_value in alternate_layers.keys():
				var layer_catalog := _dict(alternate_layers.get(layer_id_value, {}))
				if _array(_dict(layer_catalog.get("guaranteed", {})).get(collection_key, [])).has(identity) or _array(_dict(layer_catalog.get("possible", {})).get(collection_key, [])).has(identity):
					alternate_layer = str(layer_id_value)
					break
			if not alternate_layer.is_empty():
				diagnostics.append(_diagnostic("layer_mismatch", collection_key, identity, identity, collection_key, alternate_layer, "declared target %s belongs to layer %s, not the selected layer" % [identity, alternate_layer]))
			else:
				diagnostics.append(_diagnostic("unknown_target", collection_key, identity, "", "", "", "declared target %s is unknown in collection %s" % [identity, collection_key]))
	return diagnostics


static func validate(inventory: Dictionary) -> Array:
	var errors: Array = []
	if int(inventory.get("schema_version", 0)) != SCHEMA_VERSION: errors.append("semantic inventory schema_version is invalid.")
	if str(inventory.get("kind", "")) not in ["catalog", "instance"]: errors.append("semantic inventory kind is invalid.")
	if str(inventory.get("digest", "")) != _digest(inventory): errors.append("semantic inventory digest does not match immutable content.")
	errors.append_array(_array(inventory.get("errors", [])))
	var collisions: Dictionary = {}
	var expected_records: Dictionary = {}
	for collection_name in ["guaranteed", "possible"]:
		var collections := _dict(inventory.get(collection_name, {}))
		for collection_key in COLLECTION_KEYS:
			for identity_value in _array(collections.get(collection_key, [])):
				var identity := str(identity_value)
				if not _valid_identity(identity): errors.append("semantic inventory contains invalid %s identity %s." % [collection_key, identity])
				var collision_key := "%s|%s" % [collection_key, identity]
				if collisions.has(collision_key): errors.append("semantic inventory contains duplicate/colliding identity %s." % identity)
				collisions[collision_key] = true
				expected_records[collision_key] = collection_name
	if str(inventory.get("kind", "")) == "instance":
		expected_records.clear()
		for collection_key in COLLECTION_KEYS:
			for identity_value in _array(_dict(inventory.get("guaranteed", {})).get(collection_key, [])):
				expected_records["%s|%s" % [collection_key, str(identity_value)]] = "exact"
	var seen_records: Dictionary = {}
	var provenance := _dict(inventory.get("provenance", {}))
	for record_value in _array(inventory.get("records", [])):
		var record := _dict(record_value)
		if record.size() != RECORD_KEYS.size():
			errors.append("semantic inventory record is not closed.")
			continue
		for key in RECORD_KEYS:
			if not record.has(key): errors.append("semantic inventory record is missing %s." % key)
		var collection_key := str(record.get("collection", ""))
		var identity := str(record.get("owned_identity", ""))
		var composite_key := "%s|%s" % [collection_key, identity]
		if not expected_records.has(composite_key) or str(expected_records.get(composite_key, "")) != str(record.get("availability", "")):
			errors.append("semantic inventory record availability does not match its collection.")
		if identity != OperationRegistryScript.identity(str(record.get("owner_namespace", "")), str(record.get("stable_object_id", ""))):
			errors.append("semantic inventory record owned identity does not match its fields.")
		if seen_records.has(composite_key): errors.append("semantic inventory records duplicate %s." % composite_key)
		seen_records[composite_key] = true
		var source := _dict(provenance.get(composite_key, {}))
		for provenance_key in ["source_kind", "source_field", "source_record_id"]:
			if typeof(record.get(provenance_key)) != TYPE_STRING or str(record.get(provenance_key, "")).is_empty() or str(record.get(provenance_key, "")) != str(source.get(provenance_key, "")):
				errors.append("semantic inventory record %s lacks exact provenance." % composite_key)
		if not SOURCE_KINDS.has(str(record.get("source_kind", ""))): errors.append("semantic inventory record %s has an unauthorized provenance source." % composite_key)
		if typeof(record.get("record")) != TYPE_DICTIONARY or _canonical(record.get("record")) != _canonical(source.get("record", {})):
			errors.append("semantic inventory record %s payload does not match provenance." % composite_key)
	if seen_records.size() != expected_records.size(): errors.append("semantic inventory records do not cover every target exactly once.")
	return errors


static func _sealed(kind: String, environment_id: String, layer_id: String, guaranteed: Dictionary, possible: Dictionary, presentation_ids: Dictionary, errors: Array, provenance: Dictionary = {}) -> Dictionary:
	var sorted_guaranteed := _sorted_collections(guaranteed)
	var sorted_possible := _sorted_collections(possible)
	var records: Array = []
	var sealed_provenance: Dictionary = provenance.duplicate(true)
	for collection_name in ["guaranteed", "possible"]:
		var collections := sorted_guaranteed if collection_name == "guaranteed" else sorted_possible
		for collection_key in COLLECTION_KEYS:
			for identity_value in _array(collections.get(collection_key, [])):
				var parts := str(identity_value).split("::", false, 1)
				var composite_key := "%s|%s" % [collection_key, str(identity_value)]
				var source := _dict(provenance.get(composite_key, provenance.get(identity_value, {})))
				var record_source := {"source_kind": str(source.get("source_kind", "%s_%s" % [kind, collection_name])), "source_field": str(source.get("source_field", collection_key)), "source_record_id": str(source.get("source_record_id", identity_value)), "record": _dict(source.get("record", {}))}
				sealed_provenance[composite_key] = record_source
				records.append({"collection": collection_key, "owner_namespace": str(parts[0]), "stable_object_id": str(parts[1]), "owned_identity": str(identity_value), "presentation_object_id": str(presentation_ids.get(composite_key, presentation_ids.get(identity_value, ""))), "availability": "exact" if kind == "instance" else collection_name, "source_kind": str(record_source.get("source_kind", "")), "source_field": str(record_source.get("source_field", "")), "source_record_id": str(record_source.get("source_record_id", "")), "record": _dict(record_source.get("record", {}))})
	var result := {"schema_version": SCHEMA_VERSION, "kind": kind, "environment_id": environment_id.strip_edges(), "layer_id": layer_id.strip_edges(), "guaranteed": sorted_guaranteed, "possible": sorted_possible, "records": records, "presentation_ids": presentation_ids.duplicate(true), "provenance": sealed_provenance, "errors": errors.duplicate(true), "digest": ""}
	result["digest"] = _digest(result)
	return result


static func _digest(inventory: Dictionary) -> String:
	var body := inventory.duplicate(true)
	body.erase("digest")
	return JSON.stringify(_canonical(body)).sha256_text()


static func _diagnostic(code: String, collection: String, owned_identity: String, catalog_identity: String, actual_collection: String, layer_id: String, message: String) -> Dictionary:
	return {
		"code": code,
		"collection": collection,
		"owned_identity": owned_identity,
		"catalog_identity": catalog_identity,
		"actual_collection": actual_collection,
		"layer_id": layer_id,
		"message": message,
	}


static func _add_presentation_identity(collections: Dictionary, presentation_ids: Dictionary, collection_key: String, presentation_id: String) -> String:
	var domain := presentation_id.split(":", false)[0] if presentation_id.contains(":") else "base"
	var owner: String = str({"game": "game", "service": "service", "lender": "service", "event": "event", "crew": "crew", "delivery": "traveler", "traveler": "traveler", "sweep": "sweep"}.get(domain, "base"))
	var stable_id := presentation_id
	var identity := "%s::%s" % [owner, stable_id]
	if not _valid_identity(identity): return ""
	_add(collections, collection_key, identity)
	presentation_ids["%s|%s" % [collection_key, identity]] = presentation_id
	return identity


static func _add_rendered_identity(collections: Dictionary, presentation_ids: Dictionary, identity: String, presentation_id: String) -> void:
	if not _valid_identity(identity): return
	for collection_key in ["scene_objects", "interactions"]:
		_add(collections, collection_key, identity)
		presentation_ids["%s|%s" % [collection_key, identity]] = presentation_id


static func _add(collections: Dictionary, collection_key: String, identity: String) -> void:
	var values := _array(collections.get(collection_key, []))
	if not values.has(identity): values.append(identity)
	collections[collection_key] = values


static func _remove_guaranteed_from_possible(guaranteed: Dictionary, possible: Dictionary) -> void:
	for collection_key in COLLECTION_KEYS:
		var values := _array(possible.get(collection_key, []))
		for guaranteed_value in _array(guaranteed.get(collection_key, [])): values.erase(str(guaranteed_value))
		possible[collection_key] = values


static func _empty_collections() -> Dictionary:
	var result: Dictionary = {}
	for key in COLLECTION_KEYS: result[key] = []
	return result


static func _sorted_collections(value: Dictionary) -> Dictionary:
	var result := _empty_collections()
	for key in COLLECTION_KEYS:
		var values: Array = []
		for item_value in _array(value.get(key, [])): values.append(str(item_value))
		values.sort()
		result[key] = values
	return result


static func _valid_identity(value: String) -> bool:
	return OperationRegistryScript.validate_owned_identity(value).is_empty()


static func _safe_id(value: String) -> String:
	var result := ""
	for index in range(value.strip_edges().to_lower().length()):
		var code := value.strip_edges().to_lower().unicode_at(index)
		result += value.strip_edges().to_lower()[index] if (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code in [95, 45] else "_"
	return result.strip_edges().trim_prefix("_").trim_suffix("_")


static func _validated_semantic_content(source: Dictionary, library: Variant, source_label: String, errors: Array) -> Dictionary:
	var zones: Dictionary = {}
	var anchors: Dictionary = {}
	var actors: Array = []
	var zones_value: Variant = source.get("semantic_zones", {})
	if typeof(zones_value) != TYPE_DICTIONARY:
		errors.append("%s semantic_zones must be a dictionary keyed by canonical id." % source_label)
	else:
		var zone_ids := (zones_value as Dictionary).keys()
		zone_ids.sort()
		for zone_id_value in zone_ids:
			var zone_id := str(zone_id_value)
			var zone := _dict((zones_value as Dictionary).get(zone_id_value, {}))
			if not _canonical_semantic_id(zone_id):
				errors.append("%s semantic zone id %s is not canonical." % [source_label, zone_id])
				continue
			if zone.size() != 1 or not zone.has("bounds"):
				errors.append("%s semantic zone %s must be closed with exactly bounds." % [source_label, zone_id])
				continue
			var bounds := _semantic_bounds(zone.get("bounds"))
			if bounds.is_empty():
				errors.append("%s semantic zone %s has invalid environment-board bounds." % [source_label, zone_id])
				continue
			zones[zone_id] = {"bounds": bounds}
	var anchors_value: Variant = source.get("semantic_anchors", {})
	if typeof(anchors_value) != TYPE_DICTIONARY:
		errors.append("%s semantic_anchors must be a dictionary keyed by canonical id." % source_label)
	else:
		var anchor_ids := (anchors_value as Dictionary).keys()
		anchor_ids.sort()
		for anchor_id_value in anchor_ids:
			var anchor_id := str(anchor_id_value)
			var anchor := _dict((anchors_value as Dictionary).get(anchor_id_value, {}))
			if not _canonical_semantic_id(anchor_id):
				errors.append("%s semantic anchor id %s is not canonical." % [source_label, anchor_id])
				continue
			if not _closed_dictionary(anchor, ["position"], ["zone_id"]):
				errors.append("%s semantic anchor %s must be closed with position and optional zone_id." % [source_label, anchor_id])
				continue
			var position := _semantic_position(anchor.get("position"))
			if position.is_empty():
				errors.append("%s semantic anchor %s has an invalid environment-board position." % [source_label, anchor_id])
				continue
			var zone_id := str(anchor.get("zone_id", ""))
			if not zone_id.is_empty() and (zone_id != zone_id.strip_edges() or not zones.has(zone_id)):
				errors.append("%s semantic anchor %s references unavailable zone %s." % [source_label, anchor_id, zone_id])
				continue
			var normalized := {"position": position}
			if not zone_id.is_empty(): normalized["zone_id"] = zone_id
			anchors[anchor_id] = normalized
	var actors_value: Variant = source.get("semantic_actors", [])
	if typeof(actors_value) != TYPE_ARRAY:
		errors.append("%s semantic_actors must be an array of closed actor records." % source_label)
	else:
		var actor_ids: Dictionary = {}
		for actor_index in range((actors_value as Array).size()):
			var actor_value: Variant = (actors_value as Array)[actor_index]
			if typeof(actor_value) != TYPE_DICTIONARY:
				errors.append("%s semantic actor %d must be a dictionary." % [source_label, actor_index])
				continue
			var actor := actor_value as Dictionary
			if not _closed_dictionary(actor, ["id", "actor_id"], ["anchor_id", "zone_id", "behavior"]):
				errors.append("%s semantic actor %d is not a closed actor record." % [source_label, actor_index])
				continue
			var semantic_id := str(actor.get("id", ""))
			var actor_id := str(actor.get("actor_id", ""))
			var anchor_id := str(actor.get("anchor_id", ""))
			var zone_id := str(actor.get("zone_id", ""))
			var behavior := str(actor.get("behavior", ""))
			if not _canonical_semantic_id(semantic_id) or not _canonical_semantic_id(actor_id):
				errors.append("%s semantic actor %d has a non-canonical id or actor_id." % [source_label, actor_index])
				continue
			if actor_ids.has(semantic_id):
				errors.append("%s semantic actors duplicate id %s." % [source_label, semantic_id])
				continue
			if library != null and not _library_actor(library, actor_id):
				errors.append("%s semantic actor %s references unknown ContentLibrary actor %s." % [source_label, semantic_id, actor_id])
				continue
			if anchor_id.is_empty() and zone_id.is_empty():
				errors.append("%s semantic actor %s requires an exact anchor_id or zone_id placement." % [source_label, semantic_id])
				continue
			if not anchor_id.is_empty() and (anchor_id != anchor_id.strip_edges() or not anchors.has(anchor_id)):
				errors.append("%s semantic actor %s references unavailable anchor %s." % [source_label, semantic_id, anchor_id])
				continue
			if not zone_id.is_empty() and (zone_id != zone_id.strip_edges() or not zones.has(zone_id)):
				errors.append("%s semantic actor %s references unavailable zone %s." % [source_label, semantic_id, zone_id])
				continue
			if not anchor_id.is_empty() and not zone_id.is_empty() and not str(_dict(anchors.get(anchor_id, {})).get("zone_id", "")).is_empty() and str(_dict(anchors.get(anchor_id, {})).get("zone_id", "")) != zone_id:
				errors.append("%s semantic actor %s anchor and zone placements conflict." % [source_label, semantic_id])
				continue
			if not behavior.is_empty() and not _canonical_semantic_id(behavior):
				errors.append("%s semantic actor %s behavior is not canonical." % [source_label, semantic_id])
				continue
			var normalized := {"id": semantic_id, "actor_id": actor_id}
			if not anchor_id.is_empty(): normalized["anchor_id"] = anchor_id
			if not zone_id.is_empty(): normalized["zone_id"] = zone_id
			if not behavior.is_empty(): normalized["behavior"] = behavior
			actors.append(normalized)
			actor_ids[semantic_id] = true
	return {"zones": zones, "anchors": anchors, "actors": actors}


static func _validated_dynamic_actor(value: Variant, environment: Dictionary, library: Variant, semantic_content: Dictionary, errors: Array) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("base actor inventory entry must be a dictionary.")
		return {}
	var actor := value as Dictionary
	var keys := ["owner_namespace", "stable_object_id", "actor_id", "anchor_id", "zone_id", "behavior", "source_kind", "source_field", "source_record_id"]
	if actor.size() != keys.size():
		errors.append("base actor inventory entry is not closed and producer-stamped.")
		return {}
	for key in keys:
		if typeof(actor.get(key)) != TYPE_STRING or str(actor.get(key, "")) != str(actor.get(key, "")).strip_edges():
			errors.append("base actor inventory entry has malformed %s." % key)
			return {}
	var owner := str(actor.get("owner_namespace", ""))
	var stable_id := str(actor.get("stable_object_id", ""))
	var semantic_id := stable_id.trim_prefix("actor:")
	var source_kind := str(actor.get("source_kind", ""))
	var source_field := str(actor.get("source_field", ""))
	var source_record_id := str(actor.get("source_record_id", ""))
	if owner != "event" or source_kind != "environment_event" or source_field != "event_ids" or stable_id != "actor:%s" % semantic_id or not _canonical_semantic_id(semantic_id) or not _ids(environment.get("event_ids", [])).has(source_record_id):
		errors.append("base actor inventory entry is not authorized by its exact event producer provenance.")
		return {}
	if library == null or not library.has_method("event"):
		errors.append("base actor inventory event producer requires ContentLibrary.")
		return {}
	var event_definition := _dict(library.call("event", source_record_id))
	var authored := _dict(event_definition.get("semantic_actor", _dict(event_definition.get("payload", {})).get("semantic_actor", {})))
	var expected := {"id": semantic_id, "actor_id": str(actor.get("actor_id", ""))}
	if not str(actor.get("anchor_id", "")).is_empty(): expected["anchor_id"] = str(actor.get("anchor_id", ""))
	if not str(actor.get("zone_id", "")).is_empty(): expected["zone_id"] = str(actor.get("zone_id", ""))
	if not str(actor.get("behavior", "")).is_empty(): expected["behavior"] = str(actor.get("behavior", ""))
	if authored != expected:
		errors.append("base actor inventory entry conflicts with exact ContentLibrary event actor metadata.")
		return {}
	var actor_id := str(actor.get("actor_id", ""))
	if not _canonical_semantic_id(actor_id) or not _library_actor(library, actor_id):
		errors.append("base actor inventory entry references an unknown ContentLibrary actor.")
		return {}
	var anchor_id := str(actor.get("anchor_id", ""))
	var zone_id := str(actor.get("zone_id", ""))
	if anchor_id.is_empty() and zone_id.is_empty() or not anchor_id.is_empty() and not _dict(semantic_content.get("anchors", {})).has(anchor_id) or not zone_id.is_empty() and not _dict(semantic_content.get("zones", {})).has(zone_id):
		errors.append("base actor inventory entry has no valid semantic placement.")
		return {}
	return actor.duplicate(true)


static func _dynamic_actor_payload(actor: Dictionary) -> Dictionary:
	var result := {"id": str(actor.get("stable_object_id", "")).trim_prefix("actor:"), "actor_id": str(actor.get("actor_id", ""))}
	for key in ["anchor_id", "zone_id", "behavior"]:
		if not str(actor.get(key, "")).is_empty(): result[key] = str(actor.get(key, ""))
	return result


static func _set_provenance(provenance: Dictionary, collection: String, identity: String, source_kind: String, source_field: String, source_record_id: String, record: Dictionary = {}) -> void:
	provenance["%s|%s" % [collection, identity]] = {"source_kind": source_kind, "source_field": source_field, "source_record_id": source_record_id, "record": record.duplicate(true)}


static func _closed_dictionary(value: Dictionary, required: Array, optional: Array) -> bool:
	for key in required:
		if not value.has(key): return false
	for key_value in value.keys():
		if not required.has(str(key_value)) and not optional.has(str(key_value)): return false
	return true


static func _canonical_semantic_id(value: String) -> bool:
	return not value.is_empty() and value == value.strip_edges() and _safe_id(value) == value


static func _semantic_bounds(value: Variant) -> Array:
	var values := _array(value)
	if values.size() != 4: return []
	for item in values:
		if typeof(item) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(item)): return []
	var x := float(values[0])
	var y := float(values[1])
	var width := float(values[2])
	var height := float(values[3])
	var board := Vector2(ArtContractsScript.ENVIRONMENT_BOARD_SIZE)
	if x < 0.0 or y < 0.0 or width <= 0.0 or height <= 0.0 or x + width > board.x or y + height > board.y: return []
	return [x, y, width, height]


static func _semantic_position(value: Variant) -> Array:
	var values := _array(value)
	if values.size() != 2: return []
	for item in values:
		if typeof(item) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(item)): return []
	var x := float(values[0])
	var y := float(values[1])
	var board := Vector2(ArtContractsScript.ENVIRONMENT_BOARD_SIZE)
	if x < 0.0 or y < 0.0 or x > board.x or y > board.y: return []
	return [x, y]


static func _semantic_ids(value: Variant) -> Array:
	var source: Array = (value as Dictionary).keys() if typeof(value) == TYPE_DICTIONARY else _array(value)
	var result: Array = []
	for item_value in source:
		var item := str(_dict(item_value).get("id", "")) if typeof(item_value) == TYPE_DICTIONARY else str(item_value)
		if _safe_id(item) == item and not item.is_empty() and not result.has(item): result.append(item)
	return result


static func _ids(value: Variant) -> Array:
	var result: Array = []
	for item in _array(value):
		var text := str(item).strip_edges()
		if not text.is_empty() and not result.has(text): result.append(text)
	return result


static func _minimum_count(value: Variant) -> int:
	if typeof(value) == TYPE_ARRAY:
		var counts := _array(value)
		return maxi(0, int(counts[0])) if not counts.is_empty() else 0
	return maxi(0, int(value))


static func _recognized_fixture(environment: Dictionary, presentation_id: String) -> bool:
	var parts := presentation_id.split(":", false)
	if parts.size() < 2: return false
	var domain := str(parts[0])
	var source_id := str(parts[1])
	match domain:
		"game": return _ids(environment.get("game_pool", [])).has(source_id)
		"event": return _ids(environment.get("event_pool", [])).has(source_id)
		"service": return _ids(environment.get("service_pool", [])).has(source_id)
		"lender": return _ids(environment.get("lender_hooks", [])).has(source_id)
		"item":
			for offer_value in _array(environment.get("item_offers", [])):
				if str(_dict(offer_value).get("id", "")) == source_id: return true
			return false
		"shopkeeper": return presentation_id == "shopkeeper:merchant" and (str(environment.get("kind", "")) == "shop" or not _array(environment.get("item_offers", [])).is_empty())
		"casino_fixture": return _record_has_id(_dict(environment.get("local_narrative_flags", {})).get("casino_fixtures", []), source_id)
		"travel": return source_id == "leave" and not _ids(_array(environment.get("travel_hooks", [])) + _array(environment.get("next_archetypes", []))).is_empty()
	return false


static func _record_has_id(value: Variant, source_id: String) -> bool:
	for item_value in _array(value):
		if str(_dict(item_value).get("id", "")) == source_id: return true
	return false


static func _instance_source_provenance(environment: Dictionary, base_interactions_value: Variant = null, base_actors_value: Variant = null) -> Dictionary:
	var base_interactions := _array(environment.get("scenario_base_interactions", [])) if typeof(base_interactions_value) != TYPE_ARRAY else _array(base_interactions_value)
	var base_actors := _array(environment.get("scenario_base_actors", [])) if typeof(base_actors_value) != TYPE_ARRAY else _array(base_actors_value)
	return {
		"world_node_id": str(environment.get("world_node_id", "")),
		"archetype_id": str(environment.get("archetype_id", "")),
		"layout_object_rects": _dict(_dict(environment.get("layout", {})).get("object_rects", {})),
		"game_ids": _ids(environment.get("game_ids", [])),
		"event_ids": _ids(environment.get("event_ids", [])),
		"item_offer_authority": _consumed_item_offer_authority(environment.get("item_offers", []), base_interactions),
		"shopkeeper_offer_source_present": _consumed_shopkeeper_offer_source_present(environment.get("item_offers", []), base_interactions),
		"service_ids": _ids(environment.get("service_ids", [])),
		"lender_ids": _ids(environment.get("lender_hooks", [])),
		"layer_ids": _ids(environment.get("layer_ids", [])),
		"route_ids": _ids(_array(environment.get("travel_hooks", [])) + _array(environment.get("next_archetypes", []))),
		"layer_transition_ids": _layer_transition_ids(environment.get("layer_transitions", [])),
		"casino_room_target_ids": _ids(_dict(environment.get("local_narrative_flags", {})).get("casino_room_targets", [])),
		"casino_fixture_ids": _consumed_record_ids(_dict(environment.get("local_narrative_flags", {})).get("casino_fixtures", []), "id", base_interactions, "local_narrative_flags.casino_fixtures"),
		"crew_presence_ids": _consumed_record_ids(environment.get("crew_presence", []), "member_id", base_interactions, "crew_presence"),
		"home_profile": _dict(environment.get("home_profile", {})) if _source_field_used(base_interactions, "home_profile") else {},
		"home_container_ids": _consumed_record_ids(environment.get("home_containers", []), "id", base_interactions, "home_containers"),
		"semantic_zones": _dict(environment.get("semantic_zones", {})),
		"semantic_anchors": _dict(environment.get("semantic_anchors", {})),
		"semantic_actors": _array(environment.get("semantic_actors", [])),
		"base_interaction_authority": _base_interaction_authority(base_interactions),
		"base_actor_authority": _base_actor_authority(base_actors),
	}
static func _layer_transition_ids(value: Variant) -> Array:
	var result: Array = []
	for transition_value in _array(value):
		var target_layer_id := str(_dict(transition_value).get("target_layer_id", "")).strip_edges()
		if not target_layer_id.is_empty() and not result.has(target_layer_id): result.append(target_layer_id)
	result.sort()
	return result


static func _base_interaction_authority(value: Variant) -> Array:
	var result: Array = []
	for record_value in _array(value):
		var record := _dict(record_value)
		result.append({
			"owner_namespace": str(record.get("owner_namespace", "")),
			"stable_object_id": str(record.get("stable_object_id", "")),
			"presentation_object_id": str(record.get("presentation_object_id", record.get("object_id", ""))),
			"normalized_hit_rect": _rect(record.get("normalized_hit_rect", {})),
			"hit_bounds": _dict(record.get("hit_bounds", record.get("pixel_hit_bounds", {}))),
			"source_kind": str(record.get("source_kind", "")),
			"source_field": str(record.get("source_field", "")),
			"source_record_id": str(record.get("source_record_id", "")),
		})
	result.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(_canonical(a)) < JSON.stringify(_canonical(b)))
	return result


static func _consumed_item_offer_authority(value: Variant, interactions_value: Variant) -> Array:
	var result: Array = []
	for interaction_value in _array(interactions_value):
		var interaction := _dict(interaction_value)
		if str(interaction.get("source_field", "")) != "item_offers": continue
		var presentation_id := str(interaction.get("presentation_object_id", interaction.get("object_id", "")))
		if not presentation_id.begins_with("item:"): continue
		var source_record_id := str(interaction.get("source_record_id", ""))
		for offer_value in _array(value):
			var offer := _dict(offer_value)
			var offer_id := str(offer.get("id", "")).strip_edges()
			var object_id := str(offer.get("object_id", "item:%s" % offer_id))
			if offer_id == source_record_id and object_id == presentation_id:
				var authority := {"id": offer_id, "object_id": object_id}
				if not result.has(authority): result.append(authority)
	result.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(_canonical(a)) < JSON.stringify(_canonical(b)))
	return result


static func _consumed_shopkeeper_offer_source_present(value: Variant, interactions_value: Variant) -> bool:
	for interaction_value in _array(interactions_value):
		var interaction := _dict(interaction_value)
		if str(interaction.get("source_field", "")) == "item_offers" and str(interaction.get("presentation_object_id", interaction.get("object_id", ""))) == "shopkeeper:merchant":
			return not _array(value).is_empty()
	return false


static func _consumed_record_ids(value: Variant, field: String, interactions_value: Variant, source_field: String) -> Array:
	var consumed: Dictionary = {}
	for interaction_value in _array(interactions_value):
		var interaction := _dict(interaction_value)
		if str(interaction.get("source_field", "")) == source_field:
			var source_record_id := str(interaction.get("source_record_id", "")).strip_edges()
			if not source_record_id.is_empty(): consumed[source_record_id] = true
	var result: Array = []
	for record_value in _array(value):
		var record_id := str(_dict(record_value).get(field, "")).strip_edges()
		if consumed.has(record_id) and not result.has(record_id): result.append(record_id)
	result.sort()
	return result


static func _source_field_used(interactions_value: Variant, source_field: String) -> bool:
	for interaction_value in _array(interactions_value):
		if str(_dict(interaction_value).get("source_field", "")) == source_field: return true
	return false


static func _base_actor_authority(value: Variant) -> Array:
	var result: Array = []
	for record_value in _array(value):
		var record := _dict(record_value)
		result.append({
			"owner_namespace": str(record.get("owner_namespace", "")),
			"stable_object_id": str(record.get("stable_object_id", "")),
			"actor_id": str(record.get("actor_id", "")),
			"anchor_id": str(record.get("anchor_id", "")),
			"zone_id": str(record.get("zone_id", "")),
			"behavior": str(record.get("behavior", "")),
			"source_kind": str(record.get("source_kind", "")),
			"source_field": str(record.get("source_field", "")),
			"source_record_id": str(record.get("source_record_id", "")),
		})
	result.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(_canonical(a)) < JSON.stringify(_canonical(b)))
	return result


static func _library_route_target(library: Variant, source_id: String) -> bool:
	if library == null: return true
	return library.has_method("route") and not _dict(library.call("route", source_id)).is_empty() or library.has_method("environment_archetype") and not _dict(library.call("environment_archetype", source_id)).is_empty()


static func _library_actor(library: Variant, source_id: String) -> bool:
	if library == null: return true
	return library.has_method("character") and not _dict(library.call("character", source_id)).is_empty() or library.has_method("character_pool") and not _dict(library.call("character_pool", source_id)).is_empty()


static func _same_normalized_rect(left_value: Variant, right_value: Variant) -> bool:
	var left := _rect(left_value)
	var right := _rect(right_value)
	if left.is_empty() or right.is_empty(): return false
	for key in ["x", "y", "w", "h"]:
		if not is_equal_approx(float(left.get(key)), float(right.get(key))): return false
	return true


static func _semantic_actor(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY: return {}
	var source := value as Dictionary
	var actor_id := str(source.get("id", ""))
	var stable_id := str(source.get("stable_object_id", "actor:%s" % actor_id))
	var owner := str(source.get("owner_namespace", "base"))
	var anchor_id := str(source.get("anchor_id", ""))
	var zone_id := str(source.get("zone_id", ""))
	if actor_id != actor_id.strip_edges() or actor_id.is_empty() or anchor_id != anchor_id.strip_edges() or zone_id != zone_id.strip_edges() or (anchor_id.is_empty() and zone_id.is_empty()): return {}
	var identity := OperationRegistryScript.identity(owner, stable_id)
	if not OperationRegistryScript.validate_owned_identity(identity).is_empty(): return {}
	return {"identity": identity, "anchor_id": anchor_id, "zone_id": zone_id, "source_record_id": actor_id}


static func _rect(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_RECT2:
		var rect := value as Rect2
		if not is_finite(rect.position.x) or not is_finite(rect.position.y) or not is_finite(rect.size.x) or not is_finite(rect.size.y): return {}
		return {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y}
	if typeof(value) != TYPE_DICTIONARY: return {}
	var source := value as Dictionary
	for key in ["x", "y", "w", "h"]:
		if typeof(source.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(source.get(key))): return {}
	return {"x": float(source.get("x")), "y": float(source.get("y")), "w": float(source.get("w")), "h": float(source.get("h"))}


static func _effective_layer(archetype: Dictionary, overlay: Dictionary, layer_id: String) -> Dictionary:
	var result := archetype.duplicate(true)
	for key_value in ["layers", "default_layer_id", "layer_discovery_defaults", "compatibility_primary_layer_id", "environment_layer_schema_version"]: result.erase(key_value)
	result = _deep_merge(result, overlay)
	result["current_layer_id"] = layer_id
	return result


static func _deep_merge(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key_value in overlay.keys():
		var incoming: Variant = overlay.get(key_value)
		if typeof(incoming) == TYPE_DICTIONARY and typeof(result.get(key_value)) == TYPE_DICTIONARY:
			result[key_value] = _deep_merge(_dict(result.get(key_value)), incoming as Dictionary)
		else:
			result[key_value] = incoming.duplicate(true) if typeof(incoming) in [TYPE_DICTIONARY, TYPE_ARRAY] else incoming
	return result


static func _canonical(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		var keys := (value as Dictionary).keys()
		keys.sort()
		for key in keys: result[str(key)] = _canonical((value as Dictionary).get(key))
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for item in value as Array: result.append(_canonical(item))
		return result
	return value


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []
