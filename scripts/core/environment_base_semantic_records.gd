class_name EnvironmentBaseSemanticRecords
extends RefCounted

const OperationRegistryScript := preload("res://scripts/core/scenario_operation_registry.gd")
const ArtContractsScript := preload("res://scripts/core/art_contracts.gd")
const DYNAMIC_SOURCE_FIELDS := ["active_delivery_run.handoff_pending_node_id", "numbers_state.venue_status", "numbers_state.silas_presence", "crew_presence", "game_ids.environment_interactable_objects", "game_ids.environment_interactable_objects.dialogue_id"]


# Produces the deterministic, environment-owned presentation subset needed to
# seal sequence authorization before any UI exists. Live UI may refresh labels,
# availability, and action descriptors later, but it must resolve to the same
# declared semantic identities.
static func authoritative_interactable_records(environment: Dictionary, library: Variant) -> Dictionary:
	if library == null:
		return {"ok": false, "records": [], "errors": ["authoritative base semantic production requires ContentLibrary."]}
	var object_rects := _dict(_dict(environment.get("layout", {})).get("object_rects", {}))
	var records: Array = []
	var errors: Array = []
	for object_id_value in object_rects.keys():
		var object_id := str(object_id_value).strip_edges()
		var parts := object_id.split(":", false)
		if parts.size() != 2:
			continue
		var domain := str(parts[0])
		var source_id := str(parts[1])
		var object_type := domain
		if domain not in ["game", "event", "service", "lender", "travel"]:
			continue
		var definition: Dictionary = {}
		match domain:
			"game": definition = _dict(library.call("game", source_id)) if library.has_method("game") else {}
			"event": definition = _dict(library.call("event", source_id)) if library.has_method("event") else {}
			"service": definition = _dict(library.call("service", source_id)) if library.has_method("service") else {}
			"lender": definition = _dict(library.call("lender", source_id)) if library.has_method("lender") else {}
			"travel":
				if source_id == "leave":
					definition = {"display_name": "Leave"}
				elif _casino_room_target_authorized(environment, library, source_id, object_id):
					definition = _dict(library.call("environment_archetype", source_id))
				else:
					definition = _dict(library.call("route", source_id)) if library.has_method("route") else {}
		if definition.is_empty():
			errors.append("authoritative base semantic source %s is not catalog-backed." % object_id)
			continue
		var rect := _dict(object_rects.get(object_id, {}))
		for rect_key in ["x", "y", "w", "h"]:
			if not _finite_number(rect.get(rect_key)):
				errors.append("authoritative base semantic source %s has malformed layout geometry." % object_id)
				break
		if not errors.is_empty() and str(errors[-1]).contains(object_id):
			continue
		records.append({
			"object_id": object_id,
			"object_type": object_type,
			"source_id": source_id,
			"label": str(definition.get("display_name", definition.get("label", source_id.replace("_", " ").capitalize()))),
			"enabled": true,
			"disabled_reason": "",
			"available_actions": [{"id": "interact", "label": "Interact", "input_action": "confirm", "non_color_state": "available"}],
			"focus_rect": rect,
		})
	return {"ok": errors.is_empty(), "records": records if errors.is_empty() else [], "errors": errors}


static func stamp_interactable_records(records_value: Array, environment: Dictionary, library: Variant, producer_context: Dictionary = {}) -> Dictionary:
	var records: Array = []
	var errors: Array = []
	for index in range(records_value.size()):
		if typeof(records_value[index]) != TYPE_DICTIONARY:
			errors.append("base presentation record %d must be a dictionary." % index)
			continue
		var record := (records_value[index] as Dictionary).duplicate(true)
		if not bool(record.get("interactive", true)):
			records.append(record)
			continue
		var geometry := _producer_geometry(record)
		if geometry.is_empty():
			errors.append("base presentation record %d has no valid normalized environment-board geometry." % index)
			continue
		for geometry_key in geometry.keys(): record[geometry_key] = geometry.get(geometry_key)
		var identity := _identity_for_record(record, environment, library, producer_context)
		if identity.is_empty():
			errors.append("base presentation record %d is not backed by an exact environment source." % index)
			continue
		for field in ["owner_namespace", "stable_object_id", "source_kind", "source_field", "source_record_id"]:
			if record.has(field) and str(record.get(field, "")) != str(identity.get(field, "")):
				errors.append("base presentation record %d attempts to spoof semantic %s." % [index, field])
		record["owner_namespace"] = str(identity.get("owner_namespace", ""))
		record["stable_object_id"] = str(identity.get("stable_object_id", ""))
		record["source_kind"] = str(identity.get("source_kind", ""))
		record["source_field"] = str(identity.get("source_field", ""))
		record["source_record_id"] = str(identity.get("source_record_id", ""))
		records.append(record)
	# Preserve rejected inputs for defensive downstream validation. Callers must
	# still honor ok=false, and callers that do not will receive untrusted records
	# that fail from_interactable_records instead of an ambiguous successful empty set.
	return {"ok": errors.is_empty(), "records": records if errors.is_empty() else records_value.duplicate(true), "errors": errors}


static func from_interactable_records(records_value: Array) -> Dictionary:
	var interactions: Array = []
	var actors: Array = []
	var errors: Array = []
	var identities: Dictionary = {}
	var presentation_ids: Dictionary = {}
	for index in range(records_value.size()):
		if typeof(records_value[index]) != TYPE_DICTIONARY:
			errors.append("base interactable record %d must be a dictionary." % index)
			continue
		var source := records_value[index] as Dictionary
		if not bool(source.get("interactive", true)):
			continue
		var presentation_id := str(source.get("object_id", ""))
		var parsed := OperationRegistryScript.parse_owned_identity(OperationRegistryScript.identity(str(source.get("owner_namespace", "")), str(source.get("stable_object_id", ""))))
		if parsed.is_empty():
			errors.append("base interactable record %d has no producer-stamped canonical identity." % index)
			continue
		for provenance_key in ["source_kind", "source_field", "source_record_id"]:
			if str(source.get(provenance_key, "")) != str(source.get(provenance_key, "")).strip_edges() or str(source.get(provenance_key, "")).is_empty():
				errors.append("base interactable record %d lacks exact producer provenance." % index)
		var owned_identity := str(parsed.get("owned_identity", ""))
		if identities.has(owned_identity) or presentation_ids.has(presentation_id):
			errors.append("base interactable records contain duplicate identity/presentation id %s." % presentation_id)
			continue
		identities[owned_identity] = true
		presentation_ids[presentation_id] = true
		var actions: Array = []
		for action_value in _array(source.get("available_actions", [])):
			if typeof(action_value) != TYPE_DICTIONARY:
				errors.append("base interactable %s contains a non-dictionary action." % presentation_id)
				continue
			var source_action := action_value as Dictionary
			var action_id := str(source_action.get("id", ""))
			if not _canonical_id(action_id):
				errors.append("base interactable %s contains invalid action id." % presentation_id)
				continue
			var action := {"id": action_id, "label": str(source_action.get("label", action_id.replace("_", " ").capitalize())), "input_action": str(source_action.get("input_action", "confirm")), "non_color_state": str(source_action.get("non_color_state", "available"))}
			for optional_key in ["cost", "handler", "inputs", "requires_objective_steps", "requires_local"]:
				if source_action.has(optional_key): action[optional_key] = _copy(source_action.get(optional_key))
			actions.append(action)
		var enabled := bool(source.get("enabled", false))
		if not enabled: actions = []
		if enabled and actions.is_empty(): enabled = false
		var disabled_reason := str(source.get("disabled_reason", ""))
		if not enabled and disabled_reason.strip_edges().is_empty(): disabled_reason = "No action is currently available."
		var geometry := _bounds(source)
		var bounds := _dict(geometry.get("pixel_hit_bounds", {}))
		if bounds.is_empty():
			errors.append("base interactable %s has missing, non-finite, zero, or undersized hit bounds." % presentation_id)
			continue
		var label := str(source.get("label", "")).strip_edges()
		if label.is_empty(): label = presentation_id
		var state_label := str(source.get("state_label", "")).strip_edges()
		if state_label.is_empty(): state_label = "Available" if enabled else "Unavailable"
		var prompt := str(source.get("prompt", "")).strip_edges()
		if prompt.is_empty(): prompt = str(source.get("action_summary", "")).strip_edges()
		if prompt.is_empty(): prompt = "Choose an action."
		var non_color_state := str(source.get("non_color_state", "")).strip_edges()
		if non_color_state.is_empty(): non_color_state = "open" if enabled else "closed"
		var interaction := {
			"owner_namespace": str(parsed.get("owner_namespace", "")),
			"stable_object_id": str(parsed.get("stable_object_id", "")),
			"presentation_object_id": presentation_id,
			"source_kind": str(source.get("source_kind", "")),
			"source_field": str(source.get("source_field", "")),
			"source_record_id": str(source.get("source_record_id", "")),
			"label": label,
			"state_label": state_label,
			"prompt": prompt,
			"enabled": enabled,
			"disabled_reason": disabled_reason,
			"available_actions": actions,
			"input_actions": _action_inputs(actions),
			"non_color_state": non_color_state,
			"focus_order": index,
			"hit_bounds": bounds,
			"normalized_hit_rect": _dict(geometry.get("normalized_hit_rect", {})),
			"min_target_size": OperationRegistryScript.MIN_TARGET_SIZE,
			"safe_exit": presentation_id == "travel:leave" or presentation_id.begins_with("environment_layer:") or presentation_id.begins_with("travel:"),
			"alternate_exit": false,
			"source_id": str(source.get("source_id", "")),
		}
		interactions.append(interaction)
		if source.has("semantic_actor") or source.has("semantic_actor_id") or source.has("semantic_actor_owner_namespace") or source.has("semantic_actor_provenance"):
			errors.append("base interactable %s cannot promote presentation metadata into a semantic actor." % presentation_id)
	var resolved := OperationRegistryScript.resolve_interactions(interactions, [])
	if not bool(resolved.get("ok", false)): errors.append_array(_array(resolved.get("errors", [])))
	var identity_projection: Array = []
	for interaction_value in interactions:
		var interaction := interaction_value as Dictionary
		identity_projection.append({"owner_namespace": interaction.get("owner_namespace"), "stable_object_id": interaction.get("stable_object_id"), "presentation_object_id": interaction.get("presentation_object_id"), "source_kind": interaction.get("source_kind"), "source_field": interaction.get("source_field"), "source_record_id": interaction.get("source_record_id")})
	identity_projection.sort_custom(func(a: Variant, b: Variant) -> bool: return JSON.stringify(a) < JSON.stringify(b))
	return {"ok": errors.is_empty(), "interactions": interactions if errors.is_empty() else [], "actors": actors if errors.is_empty() else [], "digest": JSON.stringify(identity_projection).sha256_text(), "errors": errors}


static func is_dynamic_interaction_record(record: Dictionary) -> bool:
	return str(record.get("source_field", "")) in DYNAMIC_SOURCE_FIELDS


# Producer-only records have no final layout entry to independently prove them,
# so exact inventory admission replays their closed producer authority here.
static func validate_dynamic_interaction_record(record: Dictionary, environment: Dictionary, library: Variant) -> Array:
	var errors: Array = []
	var source_field := str(record.get("source_field", ""))
	var source_record_id := str(record.get("source_record_id", ""))
	var source_id := str(record.get("source_id", ""))
	var presentation_id := str(record.get("presentation_object_id", record.get("object_id", "")))
	var producer_context := _dict(environment.get("scenario_base_producer_context", {}))
	if str(record.get("source_kind", "")) != "environment_instance_ui" or not DYNAMIC_SOURCE_FIELDS.has(source_field):
		errors.append("dynamic interaction lacks an allowlisted producer provenance field.")
	if source_field != source_field.strip_edges() or source_record_id != source_record_id.strip_edges() or source_record_id.is_empty() or presentation_id != presentation_id.strip_edges() or presentation_id.is_empty():
		errors.append("dynamic interaction producer provenance is malformed.")
	var expected_owner := str({"game_ids.environment_interactable_objects": "game", "game_ids.environment_interactable_objects.dialogue_id": "game", "crew_presence": "crew", "active_delivery_run.handoff_pending_node_id": "traveler"}.get(source_field, "base"))
	if str(record.get("owner_namespace", "")) != expected_owner or str(record.get("stable_object_id", "")) != presentation_id:
		errors.append("dynamic interaction identity does not match its producer-owned presentation object.")
	if not _interaction_geometry_valid(record):
		errors.append("dynamic interaction lacks valid normalized and pixel hit bounds.")
	match source_field:
		"game_ids.environment_interactable_objects", "game_ids.environment_interactable_objects.dialogue_id":
			var row_parts := source_record_id.split(":", false)
			if row_parts.size() != 2:
				errors.append("dynamic game interaction provenance does not identify one parent game and authored row.")
			else:
				var parent_game := str(row_parts[0])
				var row_id := str(row_parts[1])
				var expected_dialogue_id := source_id if source_field.ends_with("dialogue_id") else ""
				var authored := _authored_game_interactable_by_row(library, parent_game, presentation_id, row_id, expected_dialogue_id)
				if not _exact_id(environment.get("game_ids", []), parent_game) or authored.is_empty():
					errors.append("dynamic game interaction is not authorized by its selected parent game manifest.")
				elif source_field.ends_with("dialogue_id"):
					if str(authored.get("dialogue_id", "")) != source_id or not _library_has(library, "dialogue", source_id): errors.append("dynamic game dialogue does not match its authored row dialogue.")
				elif source_id != row_id or not str(authored.get("dialogue_id", "")).strip_edges().is_empty():
					errors.append("dynamic game hook does not match its authored non-dialogue row.")
		"crew_presence":
			if source_id != source_record_id or not _record_present(environment.get("crew_presence", []), "member_id", source_record_id) or presentation_id != "crew_presence:%s" % source_record_id:
				errors.append("dynamic crew interaction is not backed by current crew_presence authority.")
		"numbers_state.venue_status":
			var venue_id := str(environment.get("archetype_id", environment.get("world_node_id", "")))
			if source_id != "book" or source_record_id != "book" or presentation_id != "numbers:book" or not _closed_id_array(producer_context.get("numbers_venue_ids")) or not _exact_id(producer_context.get("numbers_venue_ids", []), venue_id): errors.append("dynamic numbers book interaction lacks its current closed producer authority.")
		"numbers_state.silas_presence":
			if source_id != "silas" or source_record_id != "silas" or presentation_id != "numbers:silas" or typeof(producer_context.get("numbers_silas_present")) != TYPE_BOOL or not bool(producer_context.get("numbers_silas_present", false)): errors.append("dynamic numbers contact interaction lacks its current closed producer authority.")
		"active_delivery_run.handoff_pending_node_id":
			var handoff_id := str(producer_context.get("delivery_handoff_node_id", ""))
			if source_id != source_record_id or source_record_id != str(environment.get("world_node_id", "")) or typeof(producer_context.get("delivery_handoff_node_id")) != TYPE_STRING or handoff_id != handoff_id.strip_edges() or source_record_id != handoff_id or presentation_id != "delivery:handoff:%s" % source_record_id:
				errors.append("dynamic delivery interaction is not bound to the current handoff node.")
	return errors


# Trusted dynamic producers may publish actors only through explicit closed
# ContentLibrary metadata. Presentation character payloads remain decorative.
static func authorized_dynamic_actor_records(environment: Dictionary, library: Variant) -> Dictionary:
	var records: Array = []
	var errors: Array = []
	var identities: Dictionary = {}
	if library == null or not library.has_method("event"):
		return {"ok": false, "records": [], "errors": ["dynamic semantic actor production requires ContentLibrary event authority."]}
	for event_id_value in _array(environment.get("event_ids", [])):
		if typeof(event_id_value) != TYPE_STRING or str(event_id_value) != str(event_id_value).strip_edges() or str(event_id_value).is_empty():
			errors.append("environment event_ids contains a malformed dynamic actor producer id.")
			continue
		var event_id := str(event_id_value)
		var event_definition := _dict(library.call("event", event_id))
		if event_definition.is_empty():
			errors.append("environment event_ids references unknown dynamic actor producer %s." % event_id)
			continue
		var semantic_actor := _dict(event_definition.get("semantic_actor", _dict(event_definition.get("payload", {})).get("semantic_actor", {})))
		if semantic_actor.is_empty(): continue
		if not _closed_dictionary(semantic_actor, ["id", "actor_id"], ["anchor_id", "zone_id", "behavior"]):
			errors.append("event %s semantic_actor is not a closed actor record." % event_id)
			continue
		var semantic_id := str(semantic_actor.get("id", ""))
		var actor_id := str(semantic_actor.get("actor_id", ""))
		var anchor_id := str(semantic_actor.get("anchor_id", ""))
		var zone_id := str(semantic_actor.get("zone_id", ""))
		var behavior := str(semantic_actor.get("behavior", ""))
		if not _canonical_id(semantic_id) or not _canonical_id(actor_id) or anchor_id.is_empty() and zone_id.is_empty() or not anchor_id.is_empty() and not _canonical_id(anchor_id) or not zone_id.is_empty() and not _canonical_id(zone_id) or not behavior.is_empty() and not _canonical_id(behavior):
			errors.append("event %s semantic_actor contains malformed identity or placement metadata." % event_id)
			continue
		if not _library_actor(library, actor_id):
			errors.append("event %s semantic_actor references unknown ContentLibrary actor %s." % [event_id, actor_id])
			continue
		var stable_id := "actor:%s" % semantic_id
		var identity := OperationRegistryScript.identity("event", stable_id)
		if identities.has(identity):
			errors.append("dynamic semantic actor producers duplicate identity %s." % identity)
			continue
		identities[identity] = true
		records.append({
			"owner_namespace": "event",
			"stable_object_id": stable_id,
			"actor_id": actor_id,
			"anchor_id": anchor_id,
			"zone_id": zone_id,
			"behavior": behavior,
			"source_kind": "environment_event",
			"source_field": "event_ids",
			"source_record_id": event_id,
		})
	return {"ok": errors.is_empty(), "records": records if errors.is_empty() else [], "errors": errors}


static func _identity_for_record(source: Dictionary, environment: Dictionary, library: Variant, producer_context: Dictionary) -> Dictionary:
	var presentation_id := str(source.get("object_id", ""))
	if presentation_id != presentation_id.strip_edges() or presentation_id.is_empty(): return {}
	var parts := presentation_id.split(":", false)
	var domain := str(parts[0]) if not parts.is_empty() else ""
	var source_id := str(source.get("source_id", "")).strip_edges()
	if source_id.is_empty() and parts.size() > 1: source_id = str(parts[1])
	var owner := str({"game": "game", "game_hook": "game", "dialogue": "game", "service": "service", "lender": "service", "event": "event", "crew_presence": "crew", "delivery": "traveler"}.get(domain, "base"))
	var source_field := ""
	var source_record_id := source_id
	match domain:
		"game":
			source_field = "game_ids"
			if str(source.get("object_type", "")) != "game" or not _exact_id(environment.get(source_field, []), source_id) or not _library_has(library, "game", source_id): return {}
		"service":
			source_field = "service_ids"
			if str(source.get("object_type", "")) != "service" or not _exact_id(environment.get(source_field, []), source_id) or not _library_has(library, "service", source_id): return {}
		"lender":
			source_field = "lender_hooks"
			if str(source.get("object_type", "")) != "lender" or not _exact_id(environment.get(source_field, []), source_id) or not _library_has(library, "lender", source_id): return {}
		"event":
			source_field = "event_ids"
			var event_id := str(parts[1]) if parts.size() == 2 else ""
			if str(source.get("object_type", "")) not in ["event", "numbers"] or not _exact_id(environment.get(source_field, []), event_id) or not _library_has(library, "event", event_id): return {}
			source_record_id = event_id
		"item":
			source_field = "item_offers"
			if str(source.get("object_type", "")) != "item" or not _offer_present(environment.get(source_field, []), source_id, presentation_id) or not _library_has(library, "item", source_id): return {}
		"crew_presence":
			source_field = "crew_presence"
			if str(source.get("object_type", "")) != "dialogue" or not _record_present(environment.get(source_field, []), "member_id", source_id): return {}
		"travel":
			var room_target := _exact_id(_dict(environment.get("local_narrative_flags", {})).get("casino_room_targets", []), source_id)
			if room_target:
				source_field = "local_narrative_flags.casino_room_targets"
				if str(source.get("object_type", "")) != "travel" or presentation_id != "travel:%s" % source_id or not _casino_room_target_authorized(environment, library, source_id, presentation_id): return {}
			else:
				source_field = "travel_hooks"
				if str(source.get("object_type", "")) != "travel" or (source_id != "leave" and (not _ordinary_route_present(environment, source_id) or not _library_route_target(library, source_id))): return {}
			if source_id == "leave" and _ids(_array(environment.get("travel_hooks", [])) + _array(environment.get("next_archetypes", []))).is_empty(): return {}
		"environment_layer":
			if str(source.get("object_type", "")) != "environment_layer": return {}
			if source_id == "ambient":
				source_field = "current_layer_id"
				if str(environment.get("current_layer_id", "")) != str(source.get("parent_id", environment.get("current_layer_id", ""))): return {}
			else:
				source_field = "layer_transitions"
				if not _transition_present(environment.get(source_field, []), source_id) or not _exact_id(environment.get("layer_ids", []), source_id): return {}
		"shopkeeper":
			source_field = "item_offers"
			if str(source.get("object_type", "")) != "shopkeeper" or presentation_id != "shopkeeper:merchant" or source_id != "merchant" or _array(environment.get(source_field, [])).is_empty(): return {}
		"casino_fixture":
			source_field = "local_narrative_flags.casino_fixtures"
			if str(source.get("object_type", "")) != "casino_fixture" or not _record_present(_dict(environment.get("local_narrative_flags", {})).get("casino_fixtures", []), "id", source_id): return {}
		"game_hook":
			source_field = "game_ids.environment_interactable_objects"
			var hook_parent_game := str(source.get("parent_id", ""))
			if str(source.get("object_type", "")) != "game_hook" or not _exact_id(environment.get("game_ids", []), hook_parent_game) or source_id.is_empty(): return {}
			var authored_hook := _authored_game_interactable(library, hook_parent_game, presentation_id, source_id, "")
			if authored_hook.is_empty(): return {}
			source_record_id = "%s:%s" % [hook_parent_game, str(authored_hook.get("id", ""))]
		"dialogue":
			source_field = "game_ids.environment_interactable_objects.dialogue_id"
			var dialogue_parent_game := str(source.get("parent_id", ""))
			if str(source.get("object_type", "")) != "dialogue" or not _exact_id(environment.get("game_ids", []), dialogue_parent_game) or not _library_has(library, "dialogue", source_id): return {}
			var authored_dialogue := _authored_game_interactable(library, dialogue_parent_game, presentation_id, "", source_id)
			if authored_dialogue.is_empty(): return {}
			# The authored hook row owns the stable presentation identity. A producer may
			# select one of that row's authorized dialogue variants without changing it.
			source_record_id = "%s:%s" % [dialogue_parent_game, str(authored_dialogue.get("id", ""))]
		"home_tenure", "home_sleep", "home_storage":
			source_field = "home_profile"
			var expected_id: String = str({"home_tenure": "status", "home_sleep": "bed", "home_storage": "place"}.get(domain, ""))
			if str(source.get("object_type", "")) != domain or source_id != expected_id or _dict(environment.get("home_profile", {})).is_empty(): return {}
		"home_container":
			source_field = "home_containers"
			if str(source.get("object_type", "")) != "home_container" or not _record_present(environment.get(source_field, []), "id", source_id): return {}
		"numbers":
			if str(source.get("object_type", "")) != "numbers": return {}
			if source_id == "book":
				source_field = "numbers_state.venue_status"
				if not _exact_id(producer_context.get("numbers_venue_ids", []), str(environment.get("archetype_id", environment.get("world_node_id", "")))): return {}
			elif source_id == "silas":
				source_field = "numbers_state.silas_presence"
				if not bool(producer_context.get("numbers_silas_present", false)): return {}
			else: return {}
		"delivery":
			source_field = "active_delivery_run.handoff_pending_node_id"
			if str(source.get("object_type", "")) != "delivery" or parts.size() != 3 or str(parts[1]) != "handoff" or source_id != str(environment.get("world_node_id", "")) or source_id != str(producer_context.get("delivery_handoff_node_id", "")): return {}
		_:
			return {}
	var parsed := OperationRegistryScript.parse_owned_identity(OperationRegistryScript.identity(owner, presentation_id))
	if parsed.is_empty(): return {}
	return {
		"owner_namespace": str(parsed.get("owner_namespace", "")),
		"stable_object_id": str(parsed.get("stable_object_id", "")),
		"source_kind": "environment_instance_ui",
		"source_field": source_field,
		"source_record_id": source_record_id if not source_record_id.is_empty() else presentation_id,
	}


static func _bounds(record: Dictionary) -> Dictionary:
	if str(record.get("coordinate_space", "")) != "normalized_environment_board": return {}
	var board := _dict(record.get("coordinate_board_size", {}))
	var expected := Vector2(ArtContractsScript.ENVIRONMENT_BOARD_SIZE)
	if not _finite_number(board.get("w")) or not _finite_number(board.get("h")) or not is_equal_approx(float(board.get("w")), expected.x) or not is_equal_approx(float(board.get("h")), expected.y): return {}
	var rect := _dict(record.get("normalized_hit_rect", {}))
	for key in ["x", "y", "w", "h"]:
		if not _finite_number(rect.get(key)): return {}
	var x := float(rect.get("x"))
	var y := float(rect.get("y"))
	var width := float(rect.get("w"))
	var height := float(rect.get("h"))
	if width <= 0.0 or height <= 0.0 or x < 0.0 or y < 0.0 or x + width > 1.00001 or y + height > 1.00001: return {}
	var pixels := _dict(record.get("pixel_hit_bounds", {}))
	if not _finite_number(pixels.get("w")) or not _finite_number(pixels.get("h")): return {}
	var pixel_width := float(pixels.get("w"))
	var pixel_height := float(pixels.get("h"))
	if not is_equal_approx(pixel_width, width * expected.x) or not is_equal_approx(pixel_height, height * expected.y): return {}
	if pixel_width < OperationRegistryScript.MIN_TARGET_SIZE or pixel_height < OperationRegistryScript.MIN_TARGET_SIZE: return {}
	return {"pixel_hit_bounds": {"w": pixel_width, "h": pixel_height}, "normalized_hit_rect": {"x": x, "y": y, "w": width, "h": height}}


static func _producer_geometry(record: Dictionary) -> Dictionary:
	var rect := _dict(record.get("focus_rect", {}))
	if typeof(record.get("focus_rect")) == TYPE_RECT2:
		var source_rect := record.get("focus_rect") as Rect2
		rect = {"x": source_rect.position.x, "y": source_rect.position.y, "w": source_rect.size.x, "h": source_rect.size.y}
	for key in ["x", "y", "w", "h"]:
		if not _finite_number(rect.get(key)): return {}
	var expected := Vector2(ArtContractsScript.ENVIRONMENT_BOARD_SIZE)
	var x := float(rect.get("x"))
	var y := float(rect.get("y"))
	var width := float(rect.get("w"))
	var height := float(rect.get("h"))
	if x < 0.0 or y < 0.0 or width <= 0.0 or height <= 0.0 or x + width > 1.00001 or y + height > 1.00001 or width * expected.x < OperationRegistryScript.MIN_TARGET_SIZE or height * expected.y < OperationRegistryScript.MIN_TARGET_SIZE: return {}
	return {
		"normalized_hit_rect": {"x": x, "y": y, "w": width, "h": height},
		"coordinate_space": "normalized_environment_board",
		"coordinate_board_size": {"w": expected.x, "h": expected.y},
		"pixel_hit_bounds": {"w": width * expected.x, "h": height * expected.y},
	}


static func _interaction_geometry_valid(record: Dictionary) -> bool:
	var rect := _dict(record.get("normalized_hit_rect", {}))
	var pixels := _dict(record.get("hit_bounds", record.get("pixel_hit_bounds", {})))
	for key in ["x", "y", "w", "h"]:
		if not _finite_number(rect.get(key)): return false
	for key in ["w", "h"]:
		if not _finite_number(pixels.get(key)): return false
	var x := float(rect.get("x"))
	var y := float(rect.get("y"))
	var width := float(rect.get("w"))
	var height := float(rect.get("h"))
	var board := Vector2(ArtContractsScript.ENVIRONMENT_BOARD_SIZE)
	return x >= 0.0 and y >= 0.0 and width > 0.0 and height > 0.0 and x + width <= 1.00001 and y + height <= 1.00001 \
		and float(pixels.get("w")) >= OperationRegistryScript.MIN_TARGET_SIZE and float(pixels.get("h")) >= OperationRegistryScript.MIN_TARGET_SIZE \
		and is_equal_approx(float(pixels.get("w")), width * board.x) and is_equal_approx(float(pixels.get("h")), height * board.y)


static func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _library_has(library: Variant, method: String, source_id: String) -> bool:
	return library != null and library.has_method(method) and not _dict(library.call(method, source_id)).is_empty()


static func _library_route_target(library: Variant, source_id: String) -> bool:
	return _library_has(library, "route", source_id) or _library_has(library, "environment_archetype", source_id)


static func _library_actor(library: Variant, source_id: String) -> bool:
	return _library_has(library, "character", source_id) or _library_has(library, "character_pool", source_id)


static func _authored_game_interactable(library: Variant, game_id: String, presentation_id: String, hook_id: String, dialogue_id: String) -> Dictionary:
	if library == null or not library.has_method("game"): return {}
	var game_definition := _dict(library.call("game", game_id))
	if game_definition.is_empty(): return {}
	for row_value in _array(game_definition.get("environment_interactable_objects", [])):
		if typeof(row_value) != TYPE_DICTIONARY: continue
		var row := row_value as Dictionary
		var row_id := str(row.get("id", ""))
		var row_object_id := str(row.get("object_id", ""))
		if row_id != row_id.strip_edges() or row_id.is_empty() or row_object_id != presentation_id: continue
		if not hook_id.is_empty():
			if row_id == hook_id and str(row.get("dialogue_id", "")).strip_edges().is_empty(): return row.duplicate(true)
		elif not dialogue_id.is_empty() and str(row.get("dialogue_id", "")).strip_edges() == dialogue_id:
			return row.duplicate(true)
	return {}


static func _authored_game_interactable_by_row(library: Variant, game_id: String, presentation_id: String, row_id: String, dialogue_id: String = "") -> Dictionary:
	if library == null or not library.has_method("game"): return {}
	var game_definition := _dict(library.call("game", game_id))
	for row_value in _array(game_definition.get("environment_interactable_objects", [])):
		var row := _dict(row_value)
		if str(row.get("id", "")) != row_id or str(row.get("object_id", "")) != presentation_id: continue
		if not dialogue_id.is_empty() and str(row.get("dialogue_id", "")) != dialogue_id: continue
		if dialogue_id.is_empty() and not str(row.get("dialogue_id", "")).strip_edges().is_empty(): continue
		return row
	return {}


static func _exact_id(value: Variant, source_id: String) -> bool:
	for item in _array(value):
		if typeof(item) == TYPE_STRING and str(item) == source_id: return true
	return false


static func _ids(value: Variant) -> Array:
	var result: Array = []
	for item in _array(value):
		if typeof(item) == TYPE_STRING and str(item) == str(item).strip_edges() and not str(item).is_empty() and not result.has(str(item)): result.append(str(item))
	return result


static func _closed_id_array(value: Variant) -> bool:
	return typeof(value) == TYPE_ARRAY and _ids(value).size() == (value as Array).size()


static func _record_present(value: Variant, field: String, source_id: String) -> bool:
	for item in _array(value):
		if typeof(item) == TYPE_DICTIONARY and str((item as Dictionary).get(field, "")) == source_id: return true
	return false


static func _offer_present(value: Variant, source_id: String, presentation_id: String) -> bool:
	for item in _array(value):
		if typeof(item) != TYPE_DICTIONARY: continue
		var offer := item as Dictionary
		if str(offer.get("id", "")) == source_id and str(offer.get("object_id", "item:%s" % source_id)) == presentation_id: return true
	return false


static func _transition_present(value: Variant, source_id: String) -> bool:
	return _record_present(value, "target_layer_id", source_id)


static func _route_present(environment: Dictionary, source_id: String) -> bool:
	if _exact_id(environment.get("travel_hooks", []), source_id) or _exact_id(environment.get("next_archetypes", []), source_id): return true
	return _exact_id(_dict(environment.get("local_narrative_flags", {})).get("casino_room_targets", []), source_id)


static func _ordinary_route_present(environment: Dictionary, source_id: String) -> bool:
	return _exact_id(environment.get("travel_hooks", []), source_id) or _exact_id(environment.get("next_archetypes", []), source_id)


static func _casino_room_target_authorized(environment: Dictionary, library: Variant, source_id: String, presentation_id: String) -> bool:
	if source_id.is_empty() or presentation_id != "travel:%s" % source_id: return false
	if not _exact_id(_dict(environment.get("local_narrative_flags", {})).get("casino_room_targets", []), source_id): return false
	if not _layout_present(environment, presentation_id) or not _library_has(library, "environment_archetype", source_id): return false
	var selected := _selected_authored_archetype(environment, library)
	return not selected.is_empty() and _exact_id(_dict(selected.get("local_narrative_flags", {})).get("casino_room_targets", []), source_id)


static func _selected_authored_archetype(environment: Dictionary, library: Variant) -> Dictionary:
	var archetype_id := str(environment.get("archetype_id", "")).strip_edges()
	if archetype_id.is_empty() or library == null or not library.has_method("environment_archetype"): return {}
	var archetype := _dict(library.call("environment_archetype", archetype_id))
	if archetype.is_empty(): return {}
	var layer_id := str(environment.get("current_layer_id", "")).strip_edges()
	var layers := _dict(archetype.get("layers", {}))
	if layer_id.is_empty() or layers.is_empty(): return archetype
	if not layers.has(layer_id): return {}
	return _deep_merge(archetype, _dict(layers.get(layer_id, {})))


static func _deep_merge(base: Dictionary, overlay: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key_value in overlay.keys():
		var incoming: Variant = overlay.get(key_value)
		if typeof(incoming) == TYPE_DICTIONARY and typeof(result.get(key_value)) == TYPE_DICTIONARY:
			result[key_value] = _deep_merge(_dict(result.get(key_value)), incoming as Dictionary)
		else:
			result[key_value] = incoming.duplicate(true) if typeof(incoming) in [TYPE_DICTIONARY, TYPE_ARRAY] else incoming
	return result


static func _layout_present(environment: Dictionary, presentation_id: String) -> bool:
	return _dict(_dict(environment.get("layout", {})).get("object_rects", {})).has(presentation_id)


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _action_inputs(actions: Array) -> Array:
	var result: Array = []
	for action_value in actions:
		var input_action := str((action_value as Dictionary).get("input_action", "confirm"))
		if not result.has(input_action): result.append(input_action)
	return result


static func _action_ids(actions: Array) -> Array:
	var result: Array = []
	for action_value in actions: result.append(str((action_value as Dictionary).get("id", "")))
	result.sort()
	return result


static func _canonical_id(value: String) -> bool:
	if value != value.strip_edges() or value.is_empty(): return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 97 and code <= 122) and not (code >= 48 and code <= 57) and code != 95 and code != 45: return false
	return true


static func _closed_dictionary(value: Dictionary, required: Array, optional: Array) -> bool:
	for key in required:
		if not value.has(key): return false
	for key_value in value.keys():
		if not required.has(str(key_value)) and not optional.has(str(key_value)): return false
	return true


static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY] else value


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(false) if typeof(value) == TYPE_ARRAY else []
