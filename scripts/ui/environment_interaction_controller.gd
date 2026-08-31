extends RefCounted

const EnvironmentBaseSemanticRecordsScript := preload("res://scripts/core/environment_base_semantic_records.gd")
const ScenarioSequenceSchemaScript := preload("res://scripts/core/scenario_sequence_schema.gd")
const ScenarioSemanticViewModelScript := preload("res://scripts/ui/scenario_semantic_view_model.gd")


static func interactable_object_view_list(host: Variant) -> Array:
	if host.run_state == null or host.library == null:
		return []
	if host._is_meta_session():
		return host._meta_interactable_object_view_list()
	var preparation: Dictionary = _dict(host.run_state.scenario_prepare_semantic_finalization())
	var world_preparation: Dictionary = _dict(host.run_state.world_sequence_prepare_semantic_finalization())
	var failed = host._run_failed_without_recovery()
	var failed_reason = host._pressure_status_text(host._run_pressure_view())
	if failed_reason.strip_edges().is_empty():
		failed_reason = "Run failed."
	var game_sources: Array = []
	var game_ids = host._string_array(host.run_state.current_environment.get("game_ids", []))
	for index in range(game_ids.size()):
		var game_id := str(game_ids[index])
		game_sources.append({
			"id": game_id,
			"index": index,
			"definition": host.library.game(game_id),
			"runtime_state": host._environment_game_runtime_state(game_id),
			"object_state": host._environment_game_object_state(game_id),
			"fixture_object_states": host._environment_game_fixture_object_states(game_id),
		})
	var before_travel_objects: Array = []
	var all_event_options: Array = host._eligible_event_option_view_list()
	before_travel_objects.append_array(host._game_hook_interactable_objects())
	before_travel_objects.append_array(host._home_interactable_objects())
	before_travel_objects.append_array(casino_spatial_interactable_objects(host))
	before_travel_objects.append_array(environment_layer_interactable_objects(host))
	before_travel_objects.append_array(numbers_interactable_objects(host))
	before_travel_objects.append_array(crew_presence_interactable_objects(host, all_event_options))
	var after_travel_objects: Array = []
	var room_return_object = host._parent_home_return_interactable_object()
	if not room_return_object.is_empty():
		after_travel_objects.append(room_return_object)
	after_travel_objects.append_array(host._hook_interactable_objects(host.CONTEXT_MODE_SERVICE, host._service_hook_view_list()))
	after_travel_objects.append_array(host._hook_interactable_objects(host.CONTEXT_MODE_LENDER, host._lender_hook_view_list()))
	var travel_choices = host._travel_choice_view_list()
	var delivery_occupied := before_travel_objects + after_travel_objects
	for travel_index in range(travel_choices.size()):
		var travel_choice: Dictionary = travel_choices[travel_index] if typeof(travel_choices[travel_index]) == TYPE_DICTIONARY else {}
		delivery_occupied.append({
			"focus_rect": host._interaction_rect_for_object("travel:%s" % str(travel_choice.get("id", "")), host.CONTEXT_MODE_TRAVEL, travel_index),
		})
	before_travel_objects.append_array(delivery_interactable_objects(host, delivery_occupied))
	var event_options: Array = []
	var contact_event_ids: Array = []
	for presence_value in host._copy_array(host.run_state.current_environment.get("crew_presence", [])):
		if typeof(presence_value) == TYPE_DICTIONARY:
			var contact_event_id := str((presence_value as Dictionary).get("contact_event_id", "")).strip_edges()
			if not contact_event_id.is_empty():
				contact_event_ids.append(contact_event_id)
	for event_value in all_event_options:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event_id := str((event_value as Dictionary).get("id", ""))
		if event_id != "numbers_desk" and not contact_event_ids.has(event_id):
			event_options.append(event_value)
	var result: Array = _array(host.EnvironmentInteractionViewModelScript.interactable_object_view_list(host.run_state, host.library, {
		"run_failed_without_recovery": failed,
		"failed_reason": failed_reason,
		"selection": {
			"hover_target_id": host.hover_target_id,
			"focus_target_id": host.focus_target_id,
			"selected_object_id": host.selected_object_id,
		},
		"layout": host._current_environment_layout(),
		"risk_cue": host._risk_cue_text(),
		"game_sources": game_sources,
		"event_options": event_options,
		"event_choice_summary": Callable(host, "_event_choice_list_summary"),
		"event_inline_actions": Callable(host, "_event_inline_response_actions"),
		"item_offers": host._item_offer_view_list(),
		"shopkeeper_should_draw": host._shopkeeper_should_draw(),
		"shopkeeper_available": host._shopkeeper_available(),
		"shopkeeper_label": host._shopkeeper_label(),
		"shop_description": host._shop_description(),
		"before_travel_objects": before_travel_objects,
		"travel_choices": travel_choices,
		"direct_room_exit": host._local_parent_home_door_travel_choice(host._parent_home_parent_target_id()),
		"travel_risk_summary": Callable(host, "_travel_risk_summary"),
		"travel_preview_summary": Callable(host, "_travel_preview_summary"),
		"after_travel_objects": after_travel_objects,
		"closing_time_locked": host._closing_time_blocks_environment_actions(),
		"closing_time_reason": host._closing_time_disabled_reason(),
	}))
	var definition: Dictionary = _dict(host.run_state.scenario_sequence_definition())
	var trusted_base_result := result.duplicate(true)
	var layout_context: Dictionary = {}
	if host.environment_canvas != null and host.environment_canvas.has_method("scenario_layout_context"):
		layout_context = _dict(host.environment_canvas.call("scenario_layout_context"))
	if not bool(preparation.get("ok", false)):
		var preparation_failure := projection_failure_result(result, _array(preparation.get("errors", [])))
		var committed_preparation_failure := committed_projection_status_result(host.run_state, preparation_failure, trusted_base_result)
		return _array(committed_preparation_failure.get("records", trusted_base_result))
	if not bool(world_preparation.get("ok", false)):
		var world_preparation_failure := projection_failure_result(result, _array(world_preparation.get("errors", [])))
		var committed_world_preparation_failure := committed_projection_status_result(host.run_state, world_preparation_failure, trusted_base_result)
		return _array(committed_world_preparation_failure.get("records", trusted_base_result))
	if ScenarioSequenceSchemaScript.is_sequence(definition):
		var finalized: Dictionary = _dict(host.run_state.scenario_finalize_installed_environment(host.library, layout_context))
		if not bool(finalized.get("ok", false)):
			var finalization_failure := projection_failure_result(result, _array(finalized.get("errors", [])), _dict(finalized.get("layout_audit", {})))
			var committed_finalization_failure := committed_projection_status_result(host.run_state, finalization_failure, trusted_base_result)
			return _array(committed_finalization_failure.get("records", trusted_base_result))
		var sealed_base_records: Array = host._copy_array(finalized.get("records", []))
		result = sealed_base_records.duplicate(true)
		var projection_result := project_finalized_sequence_interaction_result(result, finalized)
		var committed_result := committed_projection_status_result(host.run_state, projection_result, trusted_base_result)
		result = _array(committed_result.get("records", trusted_base_result))
		if bool(committed_result.get("ok", false)):
			result = append_unsealed_live_records(result, trusted_base_result, sealed_base_records)
	elif bool(world_preparation.get("active", false)):
		var world_finalized: Dictionary = _dict(host.run_state.world_sequence_finalize_base_semantics(result, host.library, layout_context))
		if not bool(world_finalized.get("ok", false)):
			var world_finalization_failure := projection_failure_result(result, _array(world_finalized.get("errors", [])), _dict(world_finalized.get("layout_audit", {})))
			var committed_world_finalization_failure := committed_projection_status_result(host.run_state, world_finalization_failure, trusted_base_result)
			return _array(committed_world_finalization_failure.get("records", trusted_base_result))
		result = host._copy_array(world_finalized.get("records", []))
		var world_projection_result := project_finalized_sequence_interaction_result(result, world_finalized)
		var committed_world_result := committed_projection_status_result(host.run_state, world_projection_result, trusted_base_result)
		result = _array(committed_world_result.get("records", trusted_base_result))
	else:
		host.run_state.current_environment.erase("scenario_sequence_lifecycle_errors")
		host.run_state.current_environment.erase("scenario_layout_audit")
		host.run_state.current_environment.erase("scenario_layout_authority_digest")
	return result


# Static scenario authority owns every record it seals, including removals.
# Runtime-only controls (delivery pickup/stash, Numbers, Crew presence, and
# authored live game hooks) have separate RunState/ContentLibrary producers and
# are not legal scenario targets until they are explicitly sealed. Preserve
# those ordinary controls only when their presentation id was never admitted to
# the scenario base inventory; a sealed tombstone can therefore never be
# resurrected by the live presentation pass.
static func append_unsealed_live_records(projected_records: Array, live_records: Array, sealed_base_records: Array) -> Array:
	var result := projected_records.duplicate(true)
	var sealed_ids: Dictionary = {}
	var visible_ids: Dictionary = {}
	for record_value in sealed_base_records:
		var record := _dict(record_value)
		var object_id := str(record.get("object_id", "")).strip_edges()
		if not object_id.is_empty(): sealed_ids[object_id] = true
	for record_value in result:
		var record := _dict(record_value)
		var object_id := str(record.get("object_id", "")).strip_edges()
		if not object_id.is_empty(): visible_ids[object_id] = true
	for record_value in live_records:
		if typeof(record_value) != TYPE_DICTIONARY: continue
		var record := (record_value as Dictionary).duplicate(true)
		var object_id := str(record.get("object_id", "")).strip_edges()
		if object_id.is_empty() or sealed_ids.has(object_id) or visible_ids.has(object_id): continue
		result.append(record)
		visible_ids[object_id] = true
	return result


static func project_sequence_interactions(base_records: Array, projection: Dictionary, environment: Dictionary = {}) -> Array:
	return _array(project_sequence_interaction_result(base_records, projection, environment).get("records", base_records))


static func project_finalized_sequence_interaction_result(base_records: Array, finalized: Dictionary) -> Dictionary:
	if not bool(finalized.get("ok", false)):
		return projection_failure_result(base_records, _array(finalized.get("errors", [])), _dict(finalized.get("layout_audit", {})))
	var resolved_projection := _dict(finalized.get("projection", {}))
	var semantic_state := _dict(resolved_projection.get("semantic_state", {}))
	var authority := _dict(finalized.get("layout_authority", {}))
	var authority_digest := str(finalized.get("layout_authority_digest", ""))
	var layout_audit := _dict(finalized.get("layout_audit", {}))
	if authority.is_empty() and not bool(layout_audit.get("active", false)):
		if authority_digest.length() != 64 \
			or _layout_authority_digest(authority) != authority_digest \
			or str(semantic_state.get("layout_authority_digest", "")) != authority_digest \
			or str(layout_audit.get("authority_digest", "")) != authority_digest \
			or not bool(layout_audit.get("valid", false)) \
			or not bool(layout_audit.get("sealed_passive", false)) \
			or not _semantic_projection_coverage_errors(resolved_projection, authority).is_empty():
			return projection_failure_result(base_records, ["Passive scenario layout authority failed closed digest correlation."], layout_audit)
		return {
			"ok": true,
			"records": base_records.duplicate(true),
			"projection": resolved_projection,
			"errors": [],
			"warnings": _array(finalized.get("warnings", [])),
			"layout_authority": {},
			"layout_authority_digest": authority_digest,
			"layout_audit": layout_audit,
		}
	if authority_digest.length() != 64 \
		or _layout_authority_digest(authority) != authority_digest \
		or str(semantic_state.get("layout_authority_digest", "")) != authority_digest \
		or str(layout_audit.get("authority_digest", "")) != authority_digest \
		or not bool(layout_audit.get("valid", false)):
		return projection_failure_result(base_records, ["Finalized scenario layout authority failed digest correlation."], layout_audit)
	var actor_authority_errors := _finalized_actor_authority_errors(semantic_state, authority)
	if not actor_authority_errors.is_empty():
		return projection_failure_result(base_records, actor_authority_errors, layout_audit)
	var composed := _compose_projected_records(base_records, resolved_projection, authority, authority_digest)
	if not bool(composed.get("ok", false)):
		return projection_failure_result(base_records, _array(composed.get("errors", [])), _dict(finalized.get("layout_audit", {})))
	var composed_records := _array(composed.get("records", []))
	var coverage_errors := _projected_record_authority_errors(composed_records, authority, authority_digest, resolved_projection)
	if not coverage_errors.is_empty():
		return projection_failure_result(base_records, coverage_errors, _dict(finalized.get("layout_audit", {})))
	return {
		"ok": true,
		"records": composed_records,
		"projection": resolved_projection,
		"errors": [],
		"warnings": _array(finalized.get("warnings", [])),
		"layout_authority": authority,
		"layout_authority_digest": authority_digest,
		"layout_audit": _dict(finalized.get("layout_audit", {})),
	}


static func _layout_authority_digest(authority: Dictionary) -> String:
	var canonical: Array = []
	var identities := authority.keys()
	identities.sort()
	for identity_value in identities:
		canonical.append(_dict(authority.get(identity_value, {})))
	return JSON.stringify(canonical).sha256_text()


static func _finalized_actor_authority_errors(semantic_state: Dictionary, authority: Dictionary) -> Array:
	var errors: Array = []
	var actors := _dict(semantic_state.get("actors", {}))
	for identity_value in actors.keys():
		var identity := str(identity_value)
		var actor := _dict(actors.get(identity_value, {}))
		if actor.is_empty() or not bool(actor.get("present", true)):
			continue
		var sealed := _dict(authority.get(identity, {}))
		if str(sealed.get("visual_kind", "")) != "actor":
			errors.append("Finalized scenario actor %s lost its sealed route authority." % identity)
			continue
		var owned_identity := "%s::%s" % [str(actor.get("owner_namespace", "")), str(actor.get("stable_object_id", ""))]
		var semantic_presentation_id := identity if identity.begins_with("scenario::") else str(actor.get("presentation_object_id", sealed.get("presentation_object_id", "")))
		for pair in [
			["identity", owned_identity, identity],
			["presentation_object_id", semantic_presentation_id, sealed.get("presentation_object_id", "")],
			["normalized_hit_rect", actor.get("normalized_hit_rect", {}), sealed.get("normalized_hit_rect", {})],
			["small_screen_rect", actor.get("small_screen_rect", {}), sealed.get("small_screen_rect", {})],
			["route_points", actor.get("route_points", []), sealed.get("actor_route_points", [])],
			["route_stage", actor.get("route_stage", {}), sealed.get("actor_route_stage", {})],
			["z_order", actor.get("z_order", -1), sealed.get("z_order", -2)],
		]:
			var values := pair as Array
			if JSON.stringify(values[1]) != JSON.stringify(values[2]):
				errors.append("Finalized scenario actor %s %s diverged from sealed canvas authority." % [identity, str(values[0])])
	return errors


static func project_sequence_interaction_result(base_records: Array, projection: Dictionary, environment: Dictionary = {}) -> Dictionary:
	var prepared := ScenarioSemanticViewModelScript.prepare_projection(base_records, projection, environment)
	if not bool(prepared.get("ok", false)):
		return projection_failure_result(
			base_records,
			_array(prepared.get("errors", [])),
			_dict(prepared.get("layout_audit", {})),
			_dict(prepared.get("fallback_authority", {}))
		)
	var resolved_projection := _dict(prepared.get("projection", projection))
	var semantic_state := _dict(resolved_projection.get("semantic_state", {}))
	if not semantic_state.has("interactions") and not semantic_state.has("scene_objects") and not semantic_state.has("actors"):
		return {
			"ok": true,
			"records": base_records.duplicate(true),
			"projection": resolved_projection,
			"errors": [],
			"warnings": _array(prepared.get("warnings", [])),
			"layout_authority": {},
			"layout_authority_digest": "",
			"layout_audit": _dict(prepared.get("layout_audit", {})),
		}
	var authority := _dict(prepared.get("layout_authority", {}))
	var authority_digest := str(prepared.get("layout_authority_digest", ""))
	var composed := _compose_projected_records(base_records, resolved_projection, authority, authority_digest)
	if not bool(composed.get("ok", false)):
		return projection_failure_result(
			base_records,
			_array(composed.get("errors", [])),
			_dict(prepared.get("layout_audit", {})),
			_dict(prepared.get("fallback_authority", {}))
		)
	var composed_records := _array(composed.get("records", []))
	var coverage_errors := _projected_record_authority_errors(composed_records, authority, authority_digest, resolved_projection)
	if not coverage_errors.is_empty():
		return projection_failure_result(
			base_records,
			coverage_errors,
			_dict(prepared.get("layout_audit", {})),
			_dict(prepared.get("fallback_authority", {}))
		)
	return {
		"ok": true,
		"records": composed_records,
		"projection": resolved_projection,
		"errors": [],
		"warnings": _array(prepared.get("warnings", [])),
		"layout_authority": authority,
		"layout_authority_digest": authority_digest,
		"layout_audit": _dict(prepared.get("layout_audit", {})),
	}


static func projection_failure_result(base_records: Array, errors: Array, layout_audit: Dictionary = {}, _fallback_authority: Dictionary = {}) -> Dictionary:
	# Recompute the trusted fallback against the exact ordinary controls so the
	# readable failure surface cannot eclipse the interactions it preserves.
	var authority := ScenarioSemanticViewModelScript.failure_authority(base_records)
	var clean_errors: Array = []
	for value in errors:
		var message := str(value).strip_edges()
		if not message.is_empty() and not clean_errors.has(message):
			clean_errors.append(message)
	if clean_errors.is_empty():
		clean_errors.append("Scenario presentation validation failed.")
	var records := base_records.duplicate(true)
	records.append(_projection_failure_record(authority, clean_errors))
	var audit := layout_audit.duplicate(true)
	audit["active"] = true
	audit["valid"] = false
	audit["error_count"] = clean_errors.size()
	audit["fallback_visible"] = true
	return {
		"ok": false,
		"records": records,
		"projection": {},
		"errors": clean_errors,
		"warnings": [],
		"layout_authority": {str(authority.get("identity", "system::scenario_presentation_failure")): authority},
		"layout_authority_digest": JSON.stringify(authority).sha256_text(),
		"layout_audit": audit,
	}


static func _compose_projected_records(base_records: Array, resolved_projection: Dictionary, authority: Dictionary, authority_digest: String) -> Dictionary:
	var errors: Array = []
	var semantic_state := _dict(resolved_projection.get("semantic_state", {}))
	var semantic_interactions := _dict(semantic_state.get("interactions", {}))
	var semantic_scene_objects := _dict(semantic_state.get("scene_objects", {}))
	var semantic_actors := _dict(semantic_state.get("actors", {}))
	var semantic_visuals := semantic_scene_objects.duplicate(true)
	for actor_identity_value in semantic_actors.keys():
		var actor_identity := str(actor_identity_value)
		if not semantic_visuals.has(actor_identity):
			semantic_visuals[actor_identity] = _dict(semantic_actors.get(actor_identity_value, {}))
	var projected: Array = []
	var consumed: Dictionary = {}
	var used_presentation_ids: Dictionary = {}
	var scenario_presentation_ids: Dictionary = {}
	for collection in [semantic_visuals, semantic_interactions]:
		for semantic_value in (collection as Dictionary).values():
			var semantic := _dict(semantic_value)
			if str(semantic.get("owner_namespace", "")) == "scenario":
				var owned_identity := "scenario::%s" % str(semantic.get("stable_object_id", ""))
				scenario_presentation_ids[owned_identity] = true
	for record_value in base_records:
		if typeof(record_value) != TYPE_DICTIONARY: continue
		var record := (record_value as Dictionary).duplicate(true)
		var identity := "%s::%s" % [str(record.get("owner_namespace", "")), str(record.get("stable_object_id", ""))]
		var presentation_id := str(record.get("object_id", ""))
		if scenario_presentation_ids.has(presentation_id) and identity != presentation_id: continue
		if not authority.has(identity):
			errors.append("Finalized base interaction %s lost its sealed layout authority." % identity)
			continue
		# Layout authority seals the entire final record set, including ordinary
		# controls the sequence does not otherwise rewrite. This prevents a stale
		# producer normalized_rect from outranking the validated focus_rect later.
		record = _apply_layout_authority(record, _dict(authority.get(identity, {})), authority_digest)
		var semantic_scene := _dict(semantic_visuals.get(identity, {}))
		var semantic_interaction := _dict(semantic_interactions.get(identity, {}))
		if semantic_visuals.has(identity) and not bool(semantic_scene.get("present", true)):
			consumed[identity] = true
			continue
		if semantic_interactions.has(identity) and not bool(semantic_interaction.get("present", true)):
			consumed[identity] = true
			continue
		if semantic_visuals.has(identity):
			if not authority.has(identity):
				errors.append("Projected visual %s lost its sealed layout authority." % identity)
				continue
			record = _merge_projected_visual(record, semantic_scene, _dict(authority.get(identity, {})), authority_digest)
		if not semantic_interactions.has(identity):
			if semantic_visuals.has(identity) and str(semantic_scene.get("owner_namespace", "")) == "scenario":
				record["interactive"] = false
				record["scenario_sequence_actions"] = []
			projected.append(record)
			used_presentation_ids[str(record.get("object_id", ""))] = true
			consumed[identity] = true
			continue
		if not authority.has(identity):
			errors.append("Projected interaction %s lost its exact sealed layout authority." % identity)
			continue
		var merged := _merge_projected_interaction(record, semantic_interaction, _dict(authority.get(identity, {})), authority_digest)
		projected.append(merged)
		used_presentation_ids[str(merged.get("object_id", ""))] = true
		consumed[identity] = true
	var pending: Array = []
	for identity_value in semantic_interactions.keys():
		var identity := str(identity_value)
		if consumed.has(identity): continue
		var semantic := _dict(semantic_interactions.get(identity, {}))
		if semantic.is_empty() or not bool(semantic.get("present", true)): continue
		if not authority.has(identity):
			errors.append("Projected interaction %s has no exact sealed visual authority." % identity)
			continue
		var visual_base: Dictionary = {}
		if semantic_visuals.has(identity):
			visual_base = _merge_projected_visual({}, _dict(semantic_visuals.get(identity, {})), _dict(authority.get(identity, {})), authority_digest)
		var merged := _merge_projected_interaction(visual_base, semantic, _dict(authority.get(identity, {})), authority_digest)
		var presentation_id := str(merged.get("object_id", ""))
		if used_presentation_ids.has(presentation_id): continue
		pending.append(merged)
		used_presentation_ids[presentation_id] = true
		consumed[identity] = true
	for identity_value in semantic_visuals.keys():
		var identity := str(identity_value)
		if consumed.has(identity): continue
		var semantic := _dict(semantic_visuals.get(identity, {}))
		if semantic.is_empty() or not bool(semantic.get("present", true)): continue
		if not authority.has(identity):
			errors.append("Projected visual %s has no exact sealed layout authority." % identity)
			continue
		var merged := _merge_projected_visual({}, semantic, _dict(authority.get(identity, {})), authority_digest)
		var presentation_id := str(merged.get("object_id", ""))
		if used_presentation_ids.has(presentation_id): continue
		pending.append(merged)
		used_presentation_ids[presentation_id] = true
	pending.sort_custom(func(a: Variant, b: Variant) -> bool:
		var left := _dict(a)
		var right := _dict(b)
		var left_order := int(left.get("focus_order", 0))
		var right_order := int(right.get("focus_order", 0))
		return left_order < right_order if left_order != right_order else str(left.get("object_id", "")) < str(right.get("object_id", ""))
	)
	projected.append_array(pending)
	return {"ok": errors.is_empty(), "records": projected if errors.is_empty() else [], "errors": errors}


static func _merge_projected_interaction(base: Dictionary, semantic: Dictionary, authority: Dictionary, authority_digest: String) -> Dictionary:
	var result := base.duplicate(true)
	var world_owner_token := str(semantic.get("world_sequence_owner_token", ""))
	var scenario_owned := str(semantic.get("owner_namespace", "")) == "scenario" or not world_owner_token.is_empty()
	var owned_identity := "%s::%s" % [str(semantic.get("owner_namespace", "")), str(semantic.get("stable_object_id", ""))]
	var presentation_id := owned_identity if scenario_owned else str(semantic.get("presentation_object_id", result.get("object_id", "")))
	result["object_id"] = presentation_id
	result["object_type"] = "scenario_sequence" if scenario_owned else str(result.get("object_type", "info"))
	result["visual_type"] = str(result.get("visual_type", "fixture"))
	result["source_id"] = str(semantic.get("source_id", result.get("source_id", semantic.get("stable_object_id", ""))))
	result["owner_namespace"] = str(semantic.get("owner_namespace", ""))
	result["stable_object_id"] = str(semantic.get("stable_object_id", ""))
	if not world_owner_token.is_empty(): result["world_sequence_owner_token"] = world_owner_token
	result["label"] = str(semantic.get("label", result.get("label", presentation_id)))
	result["short_description"] = str(semantic.get("prompt", result.get("short_description", "")))
	result["action_summary"] = str(semantic.get("prompt", result.get("action_summary", "Choose an action.")))
	result["state_label"] = str(semantic.get("state_label", result.get("state_label", "Available")))
	result["enabled"] = bool(result.get("enabled", true)) and bool(semantic.get("enabled", false))
	result["interactive"] = true
	result["disabled_reason"] = str(semantic.get("disabled_reason", ""))
	result["non_color_state"] = str(semantic.get("non_color_state", result.get("non_color_state", "available")))
	result["focus_order"] = int(semantic.get("focus_order", result.get("focus_order", 0)))
	result["safe_exit"] = bool(semantic.get("safe_exit", result.get("safe_exit", false)))
	result["alternate_exit"] = bool(semantic.get("alternate_exit", result.get("alternate_exit", false)))
	result["input_actions"] = _array(semantic.get("input_actions", result.get("input_actions", [])))
	result = _apply_layout_authority(result, authority, authority_digest)
	var actions := _array(semantic.get("available_actions", []))
	result["available_actions"] = actions
	result["confirm_action_id"] = str(_dict(actions[0]).get("id", "")) if not actions.is_empty() else ""
	var sequence_actions: Array = []
	for action_value in actions:
		var action := _dict(action_value)
		if scenario_owned or not str(action.get("action_origin_receipt_key", "")).is_empty() or not str(action.get("world_sequence_owner_token", "")).is_empty(): sequence_actions.append(action)
	result["scenario_sequence_actions"] = sequence_actions
	return result


static func _merge_projected_visual(base: Dictionary, semantic: Dictionary, authority: Dictionary, authority_digest: String) -> Dictionary:
	if str(semantic.get("semantic_kind", "")) == "actor":
		return _merge_projected_actor(base, semantic, authority, authority_digest)
	return _merge_projected_scene_object(base, semantic, authority, authority_digest)


static func _merge_projected_scene_object(base: Dictionary, semantic: Dictionary, authority: Dictionary, authority_digest: String) -> Dictionary:
	var result := base.duplicate(true)
	var owner := str(semantic.get("owner_namespace", result.get("owner_namespace", "")))
	var stable_id := str(semantic.get("stable_object_id", result.get("stable_object_id", "")))
	var owned_identity := "%s::%s" % [owner, stable_id]
	result["object_id"] = owned_identity if owner == "scenario" else str(result.get("object_id", semantic.get("presentation_object_id", owned_identity)))
	result["object_type"] = str(result.get("object_type", "scenario_scene_object" if owner == "scenario" else "info"))
	result["visual_type"] = str(result.get("visual_type", "fixture"))
	result["source_id"] = str(result.get("source_id", stable_id))
	result["owner_namespace"] = owner
	result["stable_object_id"] = stable_id
	var world_owner_token := str(semantic.get("world_sequence_owner_token", ""))
	if not world_owner_token.is_empty(): result["world_sequence_owner_token"] = world_owner_token
	result["label"] = str(semantic.get("label", result.get("label", stable_id)))
	result["short_description"] = str(semantic.get("role", result.get("short_description", "Room fixture")))
	result["state_label"] = str(semantic.get("state", semantic.get("appearance", result.get("state_label", "Present"))))
	result["enabled"] = bool(semantic.get("enabled", result.get("enabled", true)))
	result["visible"] = bool(semantic.get("visible", result.get("visible", true)))
	result["interactive"] = bool(result.get("interactive", false))
	result["scenario_sequence_actions"] = _array(result.get("scenario_sequence_actions", []))
	result["anchor_id"] = str(semantic.get("anchor_id", result.get("anchor_id", "")))
	result["zone_id"] = str(semantic.get("zone_id", result.get("zone_id", "")))
	result["semantic_role"] = str(semantic.get("role", result.get("semantic_role", "prop")))
	result["semantic_state"] = str(semantic.get("state", result.get("semantic_state", "")))
	result["semantic_appearance"] = str(semantic.get("appearance", result.get("semantic_appearance", "")))
	result["non_color_state"] = str(semantic.get("non_color_state", result.get("non_color_state", result.get("state_label", "Present"))))
	result["visual_state"] = {
		"role": result["semantic_role"],
		"state": result["semantic_state"],
		"appearance": result["semantic_appearance"],
	}
	return _apply_layout_authority(result, authority, authority_digest)


static func _merge_projected_actor(base: Dictionary, semantic: Dictionary, authority: Dictionary, authority_digest: String) -> Dictionary:
	var result := _merge_projected_scene_object(base, semantic, authority, authority_digest)
	var owner := str(semantic.get("owner_namespace", result.get("owner_namespace", "")))
	if base.is_empty() or str(result.get("object_type", "")) == "scenario_scene_object":
		result["object_type"] = "scenario_actor" if owner == "scenario" else "character"
	result["visual_type"] = "character"
	result["presence"] = "character"
	result["short_description"] = "%s; %s" % [
		str(semantic.get("behavior", "idle")).replace("_", " ").capitalize(),
		str(semantic.get("pose", "idle")).replace("_", " ").capitalize(),
	]
	result["actor_id"] = str(semantic.get("actor_id", result.get("source_id", "")))
	result["source_id"] = result["actor_id"]
	result["actor_pose"] = str(semantic.get("pose", "idle"))
	result["actor_behavior"] = str(semantic.get("behavior", "idle"))
	result["actor_route_id"] = str(semantic.get("route_id", ""))
	result["actor_route_points"] = _array(authority.get("actor_route_points", []))
	result["actor_route_stage"] = _dict(authority.get("actor_route_stage", {}))
	result["character_actor"] = ScenarioSemanticViewModelScript.actor_character_model(semantic)
	return result


static func _apply_layout_authority(record: Dictionary, authority: Dictionary, authority_digest: String) -> Dictionary:
	var result := record.duplicate(true)
	var normalized := _dict(authority.get("normalized_hit_rect", {}))
	var small := _dict(authority.get("small_screen_rect", {}))
	var final_rect := Rect2(float(normalized.get("x", 0.0)), float(normalized.get("y", 0.0)), float(normalized.get("w", 0.0)), float(normalized.get("h", 0.0)))
	# Every production geometry consumer receives the same sealed rectangle.
	# `normalized_rect` used to retain a producer's stale pre-sequence value and
	# silently outrank focus_rect on PixelSceneCanvas.
	result["object_id"] = str(authority.get("presentation_object_id", ""))
	result["normalized_rect"] = normalized.duplicate(true)
	result["focus_rect"] = final_rect
	result["small_screen_rect"] = small
	result["actor_route_points"] = _array(authority.get("actor_route_points", []))
	result["actor_route_stage"] = _dict(authority.get("actor_route_stage", {}))
	result["scenario_z_order"] = int(authority.get("z_order", 0))
	result["scenario_layout_resolved"] = true
	result["scenario_layout_authority_identity"] = str(authority.get("identity", ""))
	result["scenario_layout_authority_digest"] = authority_digest
	return result


static func _projection_failure_record(authority: Dictionary, errors: Array) -> Dictionary:
	var message := "Scenario presentation is unavailable. %s" % str(errors[0])
	return _apply_layout_authority({
		"object_id": "scenario::presentation_failure",
		"object_type": "scenario_presentation_failure",
		"visual_type": "fixture",
		"source_id": "scenario_presentation_failure",
		"owner_namespace": "system",
		"stable_object_id": "scenario_presentation_failure",
		"label": "Scenario unavailable",
		"short_description": message,
		"action_summary": message,
		"state_label": "Unavailable",
		"state_badge": "Unavailable",
		"enabled": false,
		"interactive": true,
		"visible": true,
		"disabled_reason": message,
		"non_color_state": "blocked",
		"available_actions": [],
		"inline_actions": [],
		"confirm_action_id": "",
		"scenario_sequence_actions": [],
		"scenario_projection_failure": true,
		"scenario_projection_errors": errors.duplicate(true),
	}, authority, JSON.stringify(authority).sha256_text())


static func committed_projection_status_result(run_state: Variant, projection_result: Dictionary, trusted_base_records: Array) -> Dictionary:
	var audit := _dict(projection_result.get("layout_audit", {}))
	if bool(projection_result.get("ok", false)):
		var committed_digest := str(run_state.current_environment.get("scenario_layout_authority_digest", ""))
		var projected_digest := str(projection_result.get("layout_authority_digest", ""))
		var projected_authority := _dict(projection_result.get("layout_authority", {}))
		var passive_projection := projected_authority.is_empty() \
			and not bool(audit.get("active", false)) \
			and bool(audit.get("valid", false)) \
			and bool(audit.get("sealed_passive", false)) \
			and projected_digest.length() == 64 \
			and _layout_authority_digest(projected_authority) == projected_digest
		var integrity_errors: Array = []
		if not passive_projection:
			integrity_errors = _projected_record_authority_errors(
				_array(projection_result.get("records", [])),
				projected_authority,
				projected_digest,
				_dict(projection_result.get("projection", {}))
			)
		var projected_semantics := _dict(_dict(projection_result.get("projection", {})).get("semantic_state", {}))
		var committed_semantics := _dict(_dict(run_state.current_environment.get("scenario_sequence_projection", {})).get("semantic_state", {}))
		if JSON.stringify(projected_semantics) != JSON.stringify(committed_semantics):
			integrity_errors.append("Projected scenario semantics diverged from the exact committed semantic state.")
		if committed_digest == projected_digest and integrity_errors.is_empty():
			run_state.current_environment.erase("scenario_sequence_lifecycle_errors")
			return projection_result.duplicate(true)
		var mismatch_errors := integrity_errors
		if mismatch_errors.is_empty():
			mismatch_errors.append("Committed scenario layout authority diverged from the finalized production projection.")
		run_state.scenario_reject_layout_projection(mismatch_errors, audit)
		return projection_failure_result(trusted_base_records, mismatch_errors, audit)
	var projection_errors := _array(projection_result.get("errors", []))
	if projection_errors.is_empty():
		projection_errors.append("Scenario production projection was rejected without diagnostics.")
	run_state.scenario_reject_layout_projection(projection_errors, audit)
	return projection_failure_result(trusted_base_records, projection_errors, audit)


static func _projected_record_authority_errors(records: Array, authority: Dictionary, authority_digest: String, projection: Dictionary) -> Array:
	var errors: Array = []
	if authority_digest.length() != 64 or _layout_authority_digest(authority) != authority_digest:
		errors.append("Projected scenario records no longer match their sealed authority digest.")
		return errors
	errors.append_array(_semantic_projection_coverage_errors(projection, authority))
	var expected_records: Dictionary = {}
	var expected_presentation_ids: Dictionary = {}
	var authority_identities := authority.keys()
	authority_identities.sort()
	for identity_value in authority_identities:
		var identity := str(identity_value)
		var sealed := _dict(authority.get(identity_value, {}))
		if typeof(sealed.get("presentation_required")) != TYPE_BOOL or typeof(sealed.get("presentation_visible")) != TYPE_BOOL or typeof(sealed.get("presentation_interactive")) != TYPE_BOOL or typeof(sealed.get("semantic_scene_object_member")) != TYPE_BOOL or typeof(sealed.get("semantic_actor_member")) != TYPE_BOOL or typeof(sealed.get("semantic_interaction_member")) != TYPE_BOOL:
			errors.append("Sealed presentation %s has malformed exact-coverage flags." % identity)
			continue
		var required := bool(sealed.get("presentation_required", false))
		if not required:
			if bool(sealed.get("presentation_visible", false)) or bool(sealed.get("presentation_interactive", false)):
				errors.append("Sealed presentation tombstone %s remains visible or interactive." % identity)
			continue
		var presentation_object_id := str(sealed.get("presentation_object_id", ""))
		if presentation_object_id.is_empty() or expected_presentation_ids.has(presentation_object_id):
			errors.append("Required sealed presentation %s has an empty or aliased canvas identity." % identity)
			continue
		expected_records[identity] = presentation_object_id
		expected_presentation_ids[presentation_object_id] = identity
	var seen_identities: Dictionary = {}
	var seen_presentation_ids: Dictionary = {}
	for value in records:
		var record := _dict(value)
		var identity := str(record.get("scenario_layout_authority_identity", ""))
		var presentation_object_id := str(record.get("object_id", ""))
		var owned_identity := "%s::%s" % [str(record.get("owner_namespace", "")), str(record.get("stable_object_id", ""))]
		if typeof(record.get("scenario_layout_resolved")) != TYPE_BOOL or not bool(record.get("scenario_layout_resolved", false)) or identity.is_empty() or identity != owned_identity or not authority.has(identity) or str(record.get("scenario_layout_authority_digest", "")) != authority_digest:
			errors.append("Projected record %s lost its correlated sealed layout authority." % str(record.get("object_id", "")))
			continue
		if not expected_records.has(identity):
			errors.append("Projected record %s is extra or contradicts a sealed presentation tombstone." % presentation_object_id)
			continue
		if seen_identities.has(identity) or presentation_object_id.is_empty() or seen_presentation_ids.has(presentation_object_id):
			errors.append("Projected record %s aliases another sealed canvas identity." % presentation_object_id)
			continue
		seen_identities[identity] = true
		seen_presentation_ids[presentation_object_id] = true
		var sealed := _dict(authority.get(identity, {}))
		if typeof(record.get("visible", true)) != TYPE_BOOL or typeof(record.get("interactive", true)) != TYPE_BOOL:
			errors.append("Projected record %s has malformed canvas presence flags." % presentation_object_id)
		for pair in [
			["object_id", record.get("object_id", ""), sealed.get("presentation_object_id", "")],
			["normalized_rect", record.get("normalized_rect", {}), sealed.get("normalized_hit_rect", {})],
			["small_screen_rect", record.get("small_screen_rect", {}), sealed.get("small_screen_rect", {})],
			["scenario_z_order", record.get("scenario_z_order", -1), sealed.get("z_order", -2)],
			["actor_route_points", record.get("actor_route_points", []), sealed.get("actor_route_points", [])],
			["actor_route_stage", record.get("actor_route_stage", {}), sealed.get("actor_route_stage", {})],
			["visible", record.get("visible", true), sealed.get("presentation_visible", false)],
			["interactive", record.get("interactive", true), sealed.get("presentation_interactive", false)],
		]:
			var values := pair as Array
			if JSON.stringify(values[1]) != JSON.stringify(values[2]):
				errors.append("Projected record %s %s diverged from sealed canvas authority." % [str(record.get("object_id", "")), str(values[0])])
	var missing_identities := expected_records.keys()
	missing_identities.sort()
	for identity_value in missing_identities:
		var identity := str(identity_value)
		if not seen_identities.has(identity):
			errors.append("Required sealed presentation %s (%s) is missing from projected records." % [identity, str(expected_records.get(identity, ""))])
	return errors


static func _semantic_projection_coverage_errors(projection: Dictionary, authority: Dictionary) -> Array:
	var errors: Array = []
	var semantic_state := _dict(projection.get("semantic_state", {}))
	var scenes := _dict(semantic_state.get("scene_objects", {}))
	var actors := _dict(semantic_state.get("actors", {}))
	var interactions := _dict(semantic_state.get("interactions", {}))
	var semantic_identities: Dictionary = {}
	for collection_value in [scenes, actors, interactions]:
		var collection := collection_value as Dictionary
		for identity_value in collection.keys():
			semantic_identities[str(identity_value)] = true
	var identities := semantic_identities.keys()
	identities.sort()
	for identity_value in identities:
		var identity := str(identity_value)
		var visual_entries: Array = []
		for collection_value in [scenes, actors]:
			var collection := collection_value as Dictionary
			if collection.has(identity):
				visual_entries.append(_dict(collection.get(identity, {})))
		if visual_entries.size() > 1:
			errors.append("Semantic identity %s has multiple finalized visual presence contracts." % identity)
		var visual := _dict(visual_entries[0]) if not visual_entries.is_empty() else {}
		var interaction := _dict(interactions.get(identity, {}))
		var presence_values: Dictionary = {}
		var presence_entries := visual_entries.duplicate(true)
		if not interaction.is_empty():
			presence_entries.append(interaction)
		for semantic_value in presence_entries:
			var semantic := _dict(semantic_value)
			var owned_identity := "%s::%s" % [str(semantic.get("owner_namespace", "")), str(semantic.get("stable_object_id", ""))]
			if owned_identity != identity:
				errors.append("Semantic coverage identity %s diverges from its finalized owner/stable identity." % identity)
			if typeof(semantic.get("present", true)) != TYPE_BOOL:
				errors.append("Semantic coverage identity %s has non-boolean presence." % identity)
			else:
				presence_values[bool(semantic.get("present", true))] = true
		# A tombstone in either finalized collection suppresses the shared base
		# canvas record. Exact collection membership below, plus the committed
		# semantic-state comparison at the public gate, authenticates the split.
		var required := not presence_values.has(false)
		if not authority.has(identity):
			errors.append("Semantic presentation %s has no sealed collection-membership authority." % identity)
			continue
		var sealed := _dict(authority.get(identity, {}))
		if required != bool(sealed.get("presentation_required", false)):
			errors.append("Semantic identity %s presence diverged from sealed required-record coverage." % identity)
		if not visual.is_empty() and required:
			if typeof(visual.get("visible", true)) != TYPE_BOOL or bool(visual.get("visible", true)) != bool(sealed.get("presentation_visible", false)):
				errors.append("Semantic visual %s visibility diverged from sealed canvas coverage." % identity)
		if not interaction.is_empty():
			var expected_interactive := required and bool(interaction.get("present", true))
			if expected_interactive != bool(sealed.get("presentation_interactive", false)):
				errors.append("Semantic interaction %s presence diverged from sealed canvas interactivity." % identity)
		elif not visual.is_empty() and str(visual.get("owner_namespace", "")) == "scenario" and bool(sealed.get("presentation_interactive", true)):
			errors.append("Scenario visual %s gained interactivity without a finalized interaction." % identity)
	var sealed_identities := authority.keys()
	sealed_identities.sort()
	for identity_value in sealed_identities:
		var identity := str(identity_value)
		var sealed := _dict(authority.get(identity_value, {}))
		for membership_value in [
			["scene-object", scenes.has(identity), bool(sealed.get("semantic_scene_object_member", false))],
			["actor", actors.has(identity), bool(sealed.get("semantic_actor_member", false))],
			["interaction", interactions.has(identity), bool(sealed.get("semantic_interaction_member", false))],
		]:
			var membership := membership_value as Array
			if bool(membership[1]) != bool(membership[2]):
				errors.append("Semantic %s collection membership for %s diverged from sealed coverage." % [str(membership[0]), identity])
	return errors


static func crew_presence_interactable_objects(host: Variant, event_options: Array = []) -> Array:
	var result: Array = []
	if host.run_state == null:
		return result
	var index := 0
	for value in host._copy_array(host.run_state.current_environment.get("crew_presence", [])):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var presence: Dictionary = value
		var member_id := str(presence.get("member_id", "")).strip_edges()
		var line := str(presence.get("line", "")).strip_edges()
		if member_id.is_empty() or line.is_empty():
			continue
		var contact_event_id := str(presence.get("contact_event_id", "")).strip_edges()
		var contact_event: Dictionary = {}
		for event_value in event_options:
			if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("id", "")) == contact_event_id:
				contact_event = event_value
				break
		var speaker_source: Dictionary = contact_event.get("speaker", {}) if typeof(contact_event.get("speaker", {})) == TYPE_DICTIONARY else {
			"role": "crew",
			"name": member_id.trim_prefix("crew_").capitalize(),
			"character_id": member_id,
			"voice_line_key": "favor_due",
		}
		var speaker: Dictionary = host._resolve_character_speaker(speaker_source, "crew_presence:%s" % member_id, "favor_due")
		var label := str(speaker.get("speaking_character_name", member_id.trim_prefix("crew_").capitalize()))
		var choices: Array = contact_event.get("choices", []) if typeof(contact_event.get("choices", [])) == TYPE_ARRAY else []
		var interactive := not contact_event_id.is_empty() and not choices.is_empty()
		var object_id := "event:%s" % contact_event_id if interactive else "crew_presence:%s" % member_id
		result.append(host._make_interactable_object({
			"object_id": object_id,
			"object_type": "event" if interactive else "dialogue",
			"visual_type": "character",
			"source_id": contact_event_id if interactive else member_id,
			"label": label,
			"short_description": line,
			"presence": "ambient",
			"interactive": interactive,
			"enabled": interactive,
			"disabled_reason": "" if interactive else line,
			"action_summary": str(contact_event.get("start_summary", line)) if interactive else line,
			"status_summary": str(presence.get("rank", "marker")).replace("_", " ").capitalize(),
			"visual_key": "crew_presence",
			"prop": "patron",
			"icon_key": "rowdy_regular",
			"character_actor": speaker,
			"available_actions": [{"id": "inspect_event_choices", "label": "Review responses"}] if interactive else [],
			"inline_actions": host._event_inline_response_actions(contact_event_id, choices) if interactive else [],
			"confirm_action_id": "inspect_event_choices" if interactive else "",
			"focus_rect": host._interaction_rect_for_object(object_id, host.CONTEXT_MODE_EVENT if interactive else "dialogue", index),
		}))
		index += 1
	return result


static func delivery_interactable_objects(host: Variant, occupied_objects: Array = []) -> Array:
	if host.run_state == null:
		return []
	var result: Array = []
	var physical_interactions: Array = host.run_state.delivery_physical_interactions() if host.run_state.has_method("delivery_physical_interactions") else []
	for physical_index in range(physical_interactions.size()):
		var interaction: Dictionary = physical_interactions[physical_index]
		var verb := str(interaction.get("verb", ""))
		result.append(host._make_interactable_object({
			"object_id": str(interaction.get("object_id", "delivery:%s" % verb)),
			"object_type": host.CONTEXT_MODE_DELIVERY,
			"visual_type": "character" if verb == "pickup" else "prop",
			"source_id": verb,
			"label": str(interaction.get("label", verb.replace("_", " ").capitalize())),
			"short_description": str(interaction.get("message", "The route has a physical choice here.")),
			"presence": "character" if verb == "pickup" else "fixture",
			"interactive": true,
			"enabled": true,
			"action_summary": str(interaction.get("message", "Act here.")),
			"status_summary": str(interaction.get("cargo_label", "Crew route")),
			"visual_key": "character" if verb == "pickup" else "item" if verb in ["stash", "retrieve", "ditch"] else "travel",
			"prop": "patron_talk" if verb == "pickup" else "crate" if verb in ["stash", "retrieve", "ditch"] else "street_sign",
			"icon_key": "item" if verb in ["pickup", "stash", "retrieve", "ditch"] else "travel",
			"available_actions": [{"id": "delivery_physical_action", "label": str(interaction.get("label", "Act"))}],
			"confirm_action_id": "delivery_physical_action",
			"focus_rect": host._interaction_rect_for_object("", host.CONTEXT_MODE_DELIVERY, physical_index),
		}))
	var handoff: Dictionary = host.run_state.delivery_arrival_interaction()
	if handoff.is_empty():
		return result
	var node_id := str(handoff.get("node_id", "")).strip_edges()
	# A mounted owner projection is the sole player-facing handoff at this node.
	# The old delivery record remains unchanged for legacy/unconverted runs.
	if not host.run_state.world_sequence_mounted_owner_for_channel("delivery_handoff", node_id).is_empty():
		return result
	var object_id := "delivery:handoff:%s" % node_id
	var occupied_rects: Array[Rect2] = []
	var layout: Dictionary = host._current_environment_layout()
	var object_rects: Variant = layout.get("object_rects", {})
	if typeof(object_rects) == TYPE_DICTIONARY:
		for rect_value in (object_rects as Dictionary).values():
			var rect: Rect2 = host.EnvironmentInteractionViewModelScript.rect_from_dict(rect_value)
			if rect.size.x > 0.0 and rect.size.y > 0.0:
				occupied_rects.append(rect)
	for occupied_value in occupied_objects:
		if typeof(occupied_value) != TYPE_DICTIONARY:
			continue
		var occupied: Dictionary = occupied_value
		var rect_value: Variant = occupied.get("focus_rect", Rect2())
		if typeof(rect_value) == TYPE_RECT2 and (rect_value as Rect2).size.x > 0.0 and (rect_value as Rect2).size.y > 0.0:
			occupied_rects.append(rect_value as Rect2)
	var focus_rect: Rect2 = host._interaction_rect_for_object("", host.CONTEXT_MODE_DELIVERY, 0)
	var best_overlap := INF
	for candidate_index in range(8):
		var candidate: Rect2 = host._interaction_rect_for_object("", host.CONTEXT_MODE_DELIVERY, candidate_index)
		var overlap := 0.0
		for occupied_rect in occupied_rects:
			overlap += candidate.intersection(occupied_rect).get_area()
		if overlap < best_overlap:
			best_overlap = overlap
			focus_rect = candidate
		if is_zero_approx(overlap):
			break
	result.append(host._make_interactable_object({
		"object_id": object_id,
		"object_type": host.CONTEXT_MODE_DELIVERY,
		"visual_type": "character",
		"source_id": node_id,
		"label": str(handoff.get("label", "Make the handoff")),
		"short_description": str(handoff.get("message", "A quiet hand waits inside the room.")),
		"presence": "character",
		"interactive": true,
		"enabled": true,
		"action_summary": "Pass the contraband over.",
		"status_summary": str(handoff.get("cargo_label", "Crew package")),
		"risk_summary": "The room is still watching.",
		"visual_key": "character",
		"prop": "patron_talk",
		"icon_key": "dialogue",
		"available_actions": [{"id": "complete_delivery_handoff", "label": "Hand Over"}],
		"confirm_action_id": "complete_delivery_handoff",
		"focus_rect": focus_rect,
	}))
	return result


static func numbers_interactable_objects(host: Variant) -> Array:
	var objects: Array = []
	if host.run_state == null:
		return objects
	var venue_id := str(host.run_state.current_environment.get("archetype_id", host.run_state.current_world_node_id())).strip_edges()
	var venue_row: Dictionary = {}
	for venue_value in host._copy_array(host.run_state.numbers_status().get("venue_status", [])):
		if typeof(venue_value) == TYPE_DICTIONARY and str((venue_value as Dictionary).get("id", "")) == venue_id:
			venue_row = (venue_value as Dictionary).duplicate(true)
			break
	var current_layer := str(host.run_state.current_environment.get("current_layer_id", "")).strip_edges()
	var at_desk := venue_id == "small_underground_casino" and current_layer == "back_room"
	if not venue_row.is_empty():
		var venue_label := str(venue_row.get("label", host._label_from_id(venue_id)))
		var book_source := "desk" if at_desk else "book"
		var object_id := "event:numbers_desk" if at_desk else "numbers:book"
		# The production desk replaces the event card but owns its dedicated
		# Numbers fixture spot, which must not drift with encounter-card layout.
		var focus_rect: Rect2 = host._authored_interaction_rect(host.CONTEXT_MODE_NUMBERS, 0) if at_desk \
			else host._interaction_rect_for_object(object_id, host.CONTEXT_MODE_NUMBERS, 0)
		objects.append(host._make_interactable_object({
			"object_id": object_id,
			"object_type": host.CONTEXT_MODE_NUMBERS,
			"source_id": book_source,
			"label": "The Numbers Desk" if at_desk else "%s Numbers Book" % venue_label,
			"short_description": "Five books, runner work, and crew paper." if at_desk else "A local book taking three-digit slips.",
			"presence": "fixture",
			"interactive": true,
			"enabled": true,
			"action_summary": "Work the desk." if at_desk else "Write a straight or box slip.",
			"visual_key": "event",
			"prop": "paper_note",
			"icon_key": "parking_note",
			"available_actions": [{"id": "open_numbers", "label": "Work the Desk" if at_desk else "Open Book"}],
			"confirm_action_id": "open_numbers",
			"focus_rect": focus_rect,
		}))
	var silas_here: bool = host.run_state.numbers_silas_is_here()
	if silas_here:
		objects.append(host._make_interactable_object({
			"object_id": "numbers:silas",
			"object_type": host.CONTEXT_MODE_NUMBERS,
			"source_id": "silas",
			"label": "Silas Crow",
			"short_description": "Silas has something quiet to sell.",
			"presence": "character",
			"interactive": true,
			"enabled": true,
			"action_summary": "Talk business.",
			"visual_key": "character",
			"prop": "patron_talk",
			"icon_key": "dialogue",
			"available_actions": [{"id": "open_numbers", "label": "Talk Business"}],
			"confirm_action_id": "open_numbers",
			"focus_rect": host._interaction_rect_for_object("numbers:silas", "numbers_silas", 0),
		}))
	return objects


static func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []


static func game_hook_interactable_objects(host: Variant, apply_failure_lock: bool = true) -> Array:
	var objects: Array = []
	if host.run_state == null or host.library == null:
		return objects
	var run_failed_without_recovery = host._run_failed_without_recovery() if apply_failure_lock else false
	var failed_reason := ""
	if apply_failure_lock:
		failed_reason = host._pressure_status_text(host._run_pressure_view())
		if failed_reason.strip_edges().is_empty():
			failed_reason = "Run failed."
	var hook_index := 0
	for game_id in host._string_array(host.run_state.current_environment.get("game_ids", [])):
		var game = host._game_module_for_id(game_id)
		if game == null:
			continue
		for hook_value in game.environment_interactable_objects(host.run_state, host.run_state.current_environment):
			if typeof(hook_value) != TYPE_DICTIONARY:
				continue
			var hook: Dictionary = hook_value
			var hook_id := str(hook.get("id", hook.get("source_id", "")))
			if hook_id.is_empty():
				continue
			var dialogue_id := str(hook.get("dialogue_id", "")).strip_edges()
			var object_type = host.CONTEXT_MODE_DIALOGUE if not dialogue_id.is_empty() else host.CONTEXT_MODE_GAME_HOOK
			var character_actor: Dictionary = {}
			var visual_type := str(hook.get("visual_type", "service"))
			if not dialogue_id.is_empty():
				var dialogue_definition: Dictionary = host.library.dialogue(dialogue_id)
				var dialogue_speaker: Dictionary = dialogue_definition.get("speaker", {}) if typeof(dialogue_definition.get("speaker", {})) == TYPE_DICTIONARY else {}
				if not dialogue_speaker.is_empty() and bool(dialogue_speaker.get("environment_actor", true)):
					character_actor = host._resolve_character_speaker(
						host._normalized_talk_speaker(dialogue_speaker),
						dialogue_id,
						str(dialogue_speaker.get("voice_line_key", ""))
					)
					visual_type = "character"
			var object_id := str(hook.get("object_id", ""))
			if object_id.is_empty():
				object_id = "dialogue:%s" % dialogue_id if not dialogue_id.is_empty() else "game_hook:%s:%s" % [game_id, hook_id]
			var base_enabled := bool(hook.get("enabled", true))
			var enabled = base_enabled and not run_failed_without_recovery
			var disabled_reason := str(hook.get("disabled_reason", ""))
			if run_failed_without_recovery:
				disabled_reason = failed_reason
			var hook_actions: Array = [{"id": "start_dialogue", "label": "Talk"}] if enabled and not dialogue_id.is_empty() else host._copy_array(hook.get("available_actions", [])) if enabled else []
			var confirm_action: String = "start_dialogue" if enabled and not dialogue_id.is_empty() else str(hook.get("confirm_action_id", "")) if enabled else ""
			var enriched_actions: Array = []
			for action_value in hook_actions:
				if typeof(action_value) != TYPE_DICTIONARY:
					continue
				var action_data: Dictionary = (action_value as Dictionary).duplicate(true)
				action_data["parent_id"] = game_id
				action_data["source_id"] = dialogue_id if not dialogue_id.is_empty() else hook_id
				action_data["hook_id"] = hook_id
				action_data["object_type"] = object_type
				enriched_actions.append(action_data)
			objects.append(host._make_interactable_object({
				"object_id": object_id,
				"object_type": object_type,
				"visual_type": visual_type,
				"source_id": dialogue_id if not dialogue_id.is_empty() else hook_id,
				"parent_id": game_id,
				"label": str(hook.get("label", host._label_from_id(hook_id))),
				"short_description": str(hook.get("short_description", "")),
				"identity_summary": host.EnvironmentInteractionViewModelScript.character_identity_summary(character_actor),
				"enabled": enabled,
				"disabled_reason": disabled_reason if not enabled else "",
				"action_summary": str(hook.get("action_summary", "")),
				"effect_summary": str(hook.get("effect_summary", "")),
				"risk_summary": str(hook.get("risk_summary", "")),
				"cost_summary": str(hook.get("cost_summary", "")),
				"dialogue_summary": str(hook.get("dialogue_summary", "")),
				"attribute_badges": host._copy_array(hook.get("attribute_badges", [])),
				"visual_key": str(hook.get("visual_key", "")),
				"icon_key": str(hook.get("icon_key", "service")),
				"character_actor": character_actor,
				"unique_object_class": str(hook.get("unique_object_class", "")).strip_edges(),
				"unique_object_priority": int(hook.get("unique_object_priority", 0)),
				"allow_duplicate_unique_class": bool(hook.get("allow_duplicate_unique_class", false)),
				"available_actions": enriched_actions,
				"confirm_action_id": confirm_action,
				"focus_rect": host._interaction_rect_for_object(object_id, object_type, hook_index),
			}))
			hook_index += 1
	return objects


static func home_interactable_objects(host: Variant) -> Array:
	var objects: Array = []
	if host.run_state == null or host.library == null or not host.run_state.is_current_home_environment():
		return objects
	var tenure_status = host.run_state.home_tenure_status()
	var tenure_action = host.run_state.home_tenure_action_status()
	var tenure_available := bool(tenure_action.get("available", false))
	var tenure_enabled := tenure_available and bool(tenure_action.get("enabled", false))
	var tenure_label := str(tenure_action.get("label", "Home Status"))
	var tenure_description := str(tenure_status.get("summary", host.run_state.home_status_summary()))
	var tenure_actions := [{"id": "home_tenure_action", "label": tenure_label}] if tenure_available else []
	objects.append(host._make_interactable_object({
		"object_id": "home_tenure:status",
		"object_type": host.CONTEXT_MODE_HOME_TENURE,
		"visual_type": host.CONTEXT_MODE_HOME_TENURE,
		"source_id": "status",
		"label": tenure_label,
		"short_description": tenure_description,
		"presence": "fixture",
		"interactive": tenure_available,
		"enabled": tenure_enabled,
		"disabled_reason": "" if tenure_enabled else str(tenure_action.get("disabled_reason", "")),
		"action_summary": "Settle the home clock." if tenure_enabled else tenure_description,
		"status_summary": tenure_description,
		"cost_summary": "Cost: %d" % int(tenure_action.get("cost", 0)) if tenure_available else "",
		"visual_key": "home_tenure",
		"prop": "paper_note",
		"icon_key": "service",
		"available_actions": tenure_actions if tenure_enabled else [],
		"confirm_action_id": "home_tenure_action" if tenure_enabled else "",
		"focus_rect": host._interaction_rect_for_object("home_tenure:status", host.CONTEXT_MODE_HOME_TENURE, 0),
	}))
	objects.append(host._make_interactable_object({
		"object_id": "home_sleep:bed",
		"object_type": host.CONTEXT_MODE_HOME_SLEEP,
		"visual_type": host.CONTEXT_MODE_HOME_SLEEP,
		"source_id": "bed",
		"label": "Sleep",
		"short_description": "Sleep at home for four to eight hours.",
		"presence": "fixture",
		"interactive": true,
		"enabled": true,
		"action_summary": "Sleep until you wake naturally.",
		"status_summary": "Several hours pass.",
		"effect_summary": "Cools heat and steadies the room.",
		"visual_key": "home_sleep",
		"prop": "bed",
		"icon_key": "motel_room",
		"available_actions": [{"id": "home_sleep", "label": "Sleep"}],
		"confirm_action_id": "home_sleep",
		"focus_rect": host._interaction_rect_for_object("home_sleep:bed", host.CONTEXT_MODE_HOME_SLEEP, 0),
	}))
	var held_containers = host._held_container_item_options()
	var storage_enabled = not held_containers.is_empty()
	objects.append(host._make_interactable_object({
		"object_id": "home_storage:place",
		"object_type": host.CONTEXT_MODE_HOME_STORAGE,
		"visual_type": host.CONTEXT_MODE_HOME_STORAGE,
		"source_id": "place",
		"label": "Storage Spot",
		"short_description": "Place a carried container here for home storage.",
		"presence": "fixture",
		"interactive": true,
		"enabled": storage_enabled,
		"disabled_reason": "" if storage_enabled else "Carry a container first.",
		"action_summary": "Place a carried container." if storage_enabled else "No carried container to place.",
		"status_summary": "%d carried container(s)" % held_containers.size(),
		"visual_key": "home_storage",
		"prop": "crate",
		"icon_key": "service",
		"available_actions": [{"id": "place_home_container", "label": "Place"}] if storage_enabled else [],
		"confirm_action_id": "place_home_container" if storage_enabled else "",
		"focus_rect": host._interaction_rect_for_object("home_storage:place", host.CONTEXT_MODE_HOME_STORAGE, 0),
	}))
	var containers = host.run_state.current_home_containers()
	for index in range(containers.size()):
		if typeof(containers[index]) != TYPE_DICTIONARY:
			continue
		var container: Dictionary = containers[index]
		var container_id := str(container.get("id", ""))
		var stored_items = host._string_array(container.get("items", []))
		var capacity := maxi(0, int(container.get("capacity", 0)))
		var object_id := "home_container:%s" % container_id
		objects.append(host._make_interactable_object({
			"object_id": object_id,
			"object_type": host.CONTEXT_MODE_HOME_CONTAINER,
			"visual_type": host.CONTEXT_MODE_HOME_CONTAINER,
			"source_id": container_id,
			"label": str(container.get("display_name", "Container")),
			"short_description": "Home storage. Stored items do not grant effects while stashed.",
			"presence": "fixture",
			"interactive": true,
			"enabled": true,
			"action_summary": "Move items in or out.",
			"status_summary": "%d/%d stored" % [stored_items.size(), capacity],
			"effect_summary": host._home_container_contents_summary(container),
			"visual_key": "home_container",
			"prop": "satchel",
			"icon_key": str(container.get("item_id", "service")),
			"available_actions": [{"id": "manage_home_container", "label": "Open"}],
			"confirm_action_id": "manage_home_container",
			"focus_rect": host._interaction_rect_for_object(object_id, host.CONTEXT_MODE_HOME_CONTAINER, index),
		}))
	return objects


static func hook_interactable_objects(host: Variant, object_type: String, options: Array) -> Array:
	var objects: Array = []
	var run_failed_without_recovery = host._run_failed_without_recovery()
	var failed_reason = host._pressure_status_text(host._run_pressure_view())
	if failed_reason.strip_edges().is_empty():
		failed_reason = "Run failed."
	for index in range(options.size()):
		if typeof(options[index]) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = options[index]
		var hook_id := str(option.get("id", ""))
		if hook_id.is_empty():
			continue
		var object_id := "%s:%s" % [object_type, hook_id]
		var presence := "fixture" if host._object_fixture_declared(object_id) else "dynamic"
		if bool(option.get("hidden", false)) and presence != "fixture":
			continue
		var supported := bool(option.get("mutation_supported", false))
		var enabled = bool(option.get("enabled", supported)) and not run_failed_without_recovery
		var disabled_reason = "" if enabled else failed_reason if run_failed_without_recovery else str(option.get("disabled_reason", option.get("status", "Display-only.")))
		var availability_class := str(option.get("availability_class", RunState.AVAILABILITY_AVAILABLE))
		var category := str(option.get("category", ""))
		var duration_minutes := maxi(0, int(option.get("duration_minutes", 0)))
		var duration_summary := "Takes 1 hour." if duration_minutes == 60 else "Takes %d minutes." % duration_minutes if duration_minutes > 0 else ""
		var visual_type := "drink" if object_type == host.CONTEXT_MODE_SERVICE and category == "alcohol" else object_type
		var character_actor: Dictionary = {}
		if object_type == host.CONTEXT_MODE_LENDER:
			var lender_definition: Dictionary = host.library.lender(hook_id)
			var lender_speaker: Dictionary = lender_definition.get("speaker", {}) if typeof(lender_definition.get("speaker", {})) == TYPE_DICTIONARY else {}
			if str(lender_definition.get("lender_type", "")) != "family_phone" and not lender_speaker.is_empty() and bool(lender_speaker.get("environment_actor", true)):
				character_actor = host._resolve_character_speaker(
					host._normalized_talk_speaker(lender_speaker),
					hook_id,
					str(lender_speaker.get("voice_line_key", "loan_offer"))
				)
				visual_type = "character"
		var icon_key := str(option.get("icon_key", visual_type)).strip_edges()
		if icon_key.is_empty():
			icon_key = visual_type
		objects.append(host._make_interactable_object({
			"object_id": object_id,
			"object_type": object_type,
			"visual_type": visual_type,
			"source_id": hook_id,
			"label": str(option.get("display_name", host._label_from_id(hook_id))),
			"short_description": str(option.get("summary", "")),
			"identity_summary": host.EnvironmentInteractionViewModelScript.character_identity_summary(character_actor),
			"presence": presence,
			"interactive": enabled or availability_class == RunState.AVAILABILITY_TRANSIENT_BLOCKED,
			"enabled": enabled,
			"disabled_reason": disabled_reason,
			"action_summary": "Double-click to use." if enabled else "",
			"status_summary": duration_summary,
			"risk_summary": "",
			"cost_summary": "Cost: %d" % int(option.get("cost", 0)) if option.has("cost") else "",
			"effect_summary": str(option.get("delta_summary", "")),
			"attribute_badges": host._copy_array(option.get("attribute_badges", [])),
			"visual_key": visual_type,
			"prop": str(option.get("environment_prop", "")),
			"surface": str(option.get("surface", "")),
			"icon_key": icon_key,
			"asset_path": str(option.get("asset_path", "")),
			"character_actor": character_actor,
			"available_actions": [{"id": "use_%s_hook" % object_type, "label": "Use"}] if enabled else [],
			"confirm_action_id": "use_%s_hook" % object_type if enabled else "",
			"focus_rect": host._interaction_rect_for_object(object_id, object_type, index),
		}))
	return objects


static func interactable_object(host: Variant, object_id: String) -> Dictionary:
	for object_data in host._interactable_object_view_list():
		if typeof(object_data) == TYPE_DICTIONARY and str((object_data as Dictionary).get("object_id", "")) == object_id:
			return (object_data as Dictionary).duplicate(true)
	if object_id == "travel:leave":
		return host._travel_leave_interactable_object()
	return {}


static func parent_home_return_interactable_object(host: Variant) -> Dictionary:
	var room_node_id = host._parent_home_node_id()
	if room_node_id.is_empty():
		return {}
	var choice = host._local_parent_home_door_travel_choice(room_node_id)
	if choice.is_empty():
		return {}
	return host._make_interactable_object({
		"object_id": "travel:%s" % room_node_id,
		"object_type": host.CONTEXT_MODE_TRAVEL,
		"source_id": room_node_id,
		"label": "Room Door",
		"short_description": "Return to your room.",
		"enabled": bool(choice.get("enabled", true)),
		"disabled_reason": str(choice.get("disabled_reason", "")),
		"action_summary": "Enter room.",
		"risk_summary": "",
		"impact_summary": "No fare. No street exposure.",
		"cost_summary": "Cost: 0",
		"attribute_badges": host._copy_array(choice.get("attribute_badges", [])),
		"preview_lines": host._copy_array(choice.get("preview_lines", [])),
		"unlock_conditions": [],
		"visual_key": "travel",
		"prop": "door",
		"icon_key": "travel",
		"available_actions": [{"id": "enter_room", "label": "Enter Room"}] if bool(choice.get("enabled", true)) else [],
		"confirm_action_id": "enter_room" if bool(choice.get("enabled", true)) else "",
		"focus_rect": host._interaction_rect_for_object("travel:%s" % room_node_id, host.CONTEXT_MODE_TRAVEL, 1),
	})


static func casino_spatial_interactable_objects(host: Variant) -> Array:
	var objects: Array = []
	if host.run_state == null or not host.run_state.is_grand_casino_environment():
		return objects
	var flags: Dictionary = host.run_state.current_environment.get("local_narrative_flags", {}) if typeof(host.run_state.current_environment.get("local_narrative_flags", {})) == TYPE_DICTIONARY else {}
	var fixture_index := 0
	for fixture_value in host._copy_array(flags.get("casino_fixtures", [])):
		if typeof(fixture_value) != TYPE_DICTIONARY:
			continue
		var fixture: Dictionary = fixture_value
		var fixture_id := str(fixture.get("id", "")).strip_edges()
		if fixture_id.is_empty():
			continue
		# The Cage case is scenery and shelving, not a catalog control. Its saved
		# stock is exposed below through the normal item-offer path so every gift
		# has its own icon, focus target, details, and purchase action.
		if fixture_id == "cage_gift_shop":
			continue
		var object_id := "casino_fixture:%s" % fixture_id
		var object_data := {
			"object_id": object_id,
			"object_type": host.CONTEXT_MODE_CASINO_FIXTURE,
			"source_id": fixture_id,
			"label": str(fixture.get("label", host._label_from_id(fixture_id))),
			"short_description": str(fixture.get("description", "A Grand Casino fixture.")),
			"presence": "fixture",
			"interactive": true,
			"enabled": true,
			"action_summary": str(fixture.get("action_summary", "Inspect.")),
			"interaction_message": str(fixture.get("interaction_message", "The casino staff acknowledge you.")),
			"visual_key": str(fixture.get("visual_key", "casino_fixture")),
			"prop": str(fixture.get("prop", "counter")),
			"surface": str(fixture.get("surface", "counter_case")),
			"icon_key": str(fixture.get("icon_key", "service")),
			"available_actions": [{"id": "inspect_casino_fixture", "label": "Inspect"}],
			"confirm_action_id": "inspect_casino_fixture",
			"focus_rect": host._interaction_rect_for_object(object_id, host.CONTEXT_MODE_CASINO_FIXTURE, fixture_index),
		}
		if fixture_id == "cage_atm":
			object_data["inline_actions"] = host._cage_atm_inline_actions()
		objects.append(host._make_interactable_object(object_data))
		fixture_index += 1
	var door_index := 0
	for target_id_value in host._copy_array(flags.get("casino_room_targets", [])):
		var target_id := str(target_id_value).strip_edges()
		var choice := casino_room_door_travel_choice(host, target_id)
		if choice.is_empty():
			continue
		var object_id := "travel:%s" % target_id
		var enabled := bool(choice.get("enabled", true))
		objects.append(host._make_interactable_object({
			"object_id": object_id,
			"object_type": host.CONTEXT_MODE_TRAVEL,
			"source_id": target_id,
			"label": str(choice.get("label", host._label_from_id(target_id))),
			"short_description": str(choice.get("description", "An interior casino door.")),
			"presence": "fixture",
			"interactive": true,
			"enabled": enabled,
			"disabled_reason": str(choice.get("disabled_reason", "")),
			"action_summary": "Enter room." if enabled else str(choice.get("disabled_reason", "Locked.")),
			"cost_summary": "Cost: %d" % int(choice.get("cost", 0)),
			"attribute_badges": host._copy_array(choice.get("attribute_badges", [])),
			"preview_lines": host._copy_array(choice.get("preview_lines", [])),
			"unlock_conditions": host._copy_array(choice.get("unlock_conditions", [])),
			"visual_key": "travel",
			"prop": "door",
			"icon_key": "travel",
			"available_actions": [{"id": "enter_room", "label": "Enter Room"}] if enabled else [],
			"confirm_action_id": "enter_room" if enabled else "",
			"focus_rect": host._interaction_rect_for_object(object_id, host.CONTEXT_MODE_TRAVEL, door_index + 1),
		}))
		door_index += 1
	return objects


static func environment_layer_interactable_objects(host: Variant) -> Array:
	var objects: Array = []
	if host.run_state == null or not host.run_state.is_layered_environment():
		return objects
	var ambient_line := str(host.run_state.current_environment.get("layer_ambient_line", "")).strip_edges()
	var ambient_label := str(host.run_state.current_environment.get("layer_ambient_label", "")).strip_edges()
	if not ambient_line.is_empty() and not ambient_label.is_empty():
		objects.append(host._make_interactable_object({
			"object_id": "environment_layer:ambient",
			"object_type": host.CONTEXT_MODE_ENVIRONMENT_LAYER,
			"source_id": "ambient",
			"label": ambient_label,
			"short_description": ambient_line,
			"presence": "fixture",
			"interactive": false,
			"enabled": false,
			"disabled_reason": ambient_line,
			"action_summary": ambient_line,
			"visual_key": "environment_layer_ambient",
			"prop": str(host.run_state.current_environment.get("layer_ambient_prop", "stage")),
			"icon_key": "service",
			"available_actions": [],
			"confirm_action_id": "",
			"focus_rect": host._interaction_rect_for_object("environment_layer:ambient", host.CONTEXT_MODE_ENVIRONMENT_LAYER, 0),
		}))
	var transition_index := 1
	for transition_value in host._copy_array(host.run_state.current_environment.get("layer_transitions", [])):
		if typeof(transition_value) != TYPE_DICTIONARY:
			continue
		var transition: Dictionary = transition_value
		var target_id := str(transition.get("target_layer_id", "")).strip_edges()
		if target_id.is_empty():
			continue
		var status: Dictionary = host.run_state.environment_layer_access_status(target_id)
		if bool(status.get("hidden", false)):
			continue
		var enabled := bool(status.get("available", false))
		var object_id := "environment_layer:%s" % target_id
		objects.append(host._make_interactable_object({
			"object_id": object_id,
			"object_type": host.CONTEXT_MODE_ENVIRONMENT_LAYER,
			"source_id": target_id,
			"label": str(transition.get("label", host._label_from_id(target_id))),
			"short_description": str(transition.get("description", "An interior door.")),
			"presence": "fixture",
			"interactive": true,
			"enabled": enabled,
			"disabled_reason": "" if enabled else str(status.get("reason", transition.get("locked_reason", "The door stays shut."))),
			"action_summary": "Enter room." if enabled else str(status.get("reason", transition.get("locked_reason", "The door stays shut."))),
			"impact_summary": "No fare. No street exposure.",
			"cost_summary": "Cost: 0",
			"visual_key": "environment_layer_door",
			"prop": str(transition.get("prop", "door")),
			"icon_key": str(transition.get("icon_key", "travel")),
			"available_actions": [{"id": "enter_environment_layer", "label": "Enter Room"}] if enabled else [],
			"confirm_action_id": "enter_environment_layer" if enabled else "",
			"focus_rect": host._interaction_rect_for_object(object_id, host.CONTEXT_MODE_ENVIRONMENT_LAYER, transition_index),
		}))
		transition_index += 1
	return objects


static func travel_leave_interactable_object(host: Variant) -> Dictionary:
	if host.run_state == null:
		return {}
	var travel_choices = host._travel_choice_view_list()
	if travel_choices.is_empty():
		return {}
	var first_choice: Dictionary = travel_choices[0] if typeof(travel_choices[0]) == TYPE_DICTIONARY else {}
	var direct_room_exit = host._local_parent_home_door_travel_choice(host._parent_home_parent_target_id())
	if not direct_room_exit.is_empty():
		first_choice = direct_room_exit
	var any_enabled := false
	for choice_value in travel_choices:
		if typeof(choice_value) == TYPE_DICTIONARY and bool((choice_value as Dictionary).get("enabled", true)):
			any_enabled = true
			break
	var travel_enabled = not host._run_failed_without_recovery()
	var preview_lines = host._travel_leave_preview_lines(travel_choices, direct_room_exit)
	var travel_label := str(direct_room_exit.get("label", "Lobby")) if not direct_room_exit.is_empty() else "Leave"
	var travel_description := "Enter motel lobby." if not direct_room_exit.is_empty() else "Open city map."
	var travel_action_summary := "Enter lobby." if not direct_room_exit.is_empty() else "Open map." if any_enabled else "Inspect locked routes."
	var travel_available_actions := [{"id": "enter_lobby", "label": "Enter Lobby"}] if not direct_room_exit.is_empty() and travel_enabled else [{"id": "open_map", "label": "Open Map"}] if travel_enabled else []
	var travel_confirm_action := "enter_lobby" if not direct_room_exit.is_empty() and travel_enabled else "open_map" if travel_enabled else ""
	return host._make_interactable_object({
		"object_id": "travel:leave",
		"object_type": host.CONTEXT_MODE_TRAVEL,
		"source_id": "leave",
		"label": travel_label,
		"short_description": travel_description,
		"enabled": travel_enabled,
		"disabled_reason": host._pressure_status_text(host._run_pressure_view()) if not travel_enabled else "",
		"action_summary": travel_action_summary,
		"risk_summary": host._travel_risk_summary(first_choice),
		"impact_summary": host._travel_preview_summary(first_choice),
		"cost_summary": "%d route(s)" % travel_choices.size(),
		"attribute_badges": host._copy_array(first_choice.get("attribute_badges", [])),
		"preview_lines": preview_lines,
		"unlock_conditions": [],
		"visual_key": "travel",
		"prop": "door",
		"icon_key": "travel",
		"available_actions": travel_available_actions,
		"confirm_action_id": travel_confirm_action,
		"focus_rect": host._interaction_rect_for_object("travel:leave", host.CONTEXT_MODE_TRAVEL, 0),
	})


static func local_parent_home_door_travel_choice(host: Variant, target_id: String) -> Dictionary:
	var casino_choice := casino_room_door_travel_choice(host, target_id)
	if not casino_choice.is_empty():
		return casino_choice
	var door_kind = host._local_parent_home_door_kind(target_id)
	if door_kind.is_empty():
		return {}
	if not host._travel_target_ids().has(target_id):
		return {}
	var route = host._world_route_for_target(target_id)
	if route.is_empty():
		route = host.library.route(target_id) if host.library != null else {}
	route["cost"] = 0
	route["base_cost"] = 0
	route["distance"] = "near"
	route["distance_blocks"] = 1
	route["risk"] = ""
	route["suspicion_delta"] = 0
	route["risk_decay"] = 0
	route["travel_method"] = "Door"
	var archetype = host._environment_archetype(target_id)
	var label = host._travel_label_from_archetype(archetype, target_id)
	var preview_line := "Step through the door into the lobby."
	if door_kind == "return":
		label = str(host.run_state.home_state.get("display_name", "Room"))
		preview_line = "Step through the door back into your room."
	elif label.is_empty() or label == target_id:
		label = "Lobby"
	var status = host.run_state.travel_route_status(route)
	if bool(status.get("hidden", false)):
		return {}
	return {
		"id": target_id,
		"label": label,
		"kind": str(archetype.get("kind", "")),
		"tier": int(archetype.get("tier", 1)),
		"description": "A local door between your room and the lobby.",
		"route": route.duplicate(true),
		"cost": 0,
		"risk": "",
		"suspicion_delta": 0,
		"distance": "near",
		"distance_blocks": 1,
		"risk_decay": 0,
		"travel_method": "Door",
		"risk_text": "",
		"risk_event": {},
		"attribute_badges": host.AttributeBadgesScript.for_route(route, {}),
		"unlock_conditions": host._copy_array(status.get("unlock_conditions", [])),
		"unlock_summary": str(status.get("unlock_summary", "")),
		"preview": {"level": "full", "lines": [preview_line]},
		"preview_level": "full",
		"preview_lines": [preview_line],
		"enabled": bool(status.get("available", true)),
		"disabled_reason": str(status.get("disabled_reason", "")),
		"local_door": true,
		"door_kind": door_kind,
	}


static func casino_room_door_travel_choice(host: Variant, target_id: String) -> Dictionary:
	if host.run_state == null or not host.run_state.is_grand_casino_environment():
		return {}
	var clean_target_id := target_id.strip_edges()
	var flags: Dictionary = host.run_state.current_environment.get("local_narrative_flags", {}) if typeof(host.run_state.current_environment.get("local_narrative_flags", {})) == TYPE_DICTIONARY else {}
	if not host._string_array(flags.get("casino_room_targets", [])).has(clean_target_id):
		return {}
	var archetype = host._environment_archetype(clean_target_id)
	if archetype.is_empty():
		return {}
	var travel_minutes := maxi(1, int(flags.get("casino_room_travel_minutes", 5)))
	var buy_in := maxi(0, int(flags.get("casino_high_limit_buy_in", 60)))
	var room_access: Dictionary = host.run_state.grand_casino_room_access_status(clean_target_id, buy_in)
	var requires_buy_in := bool(room_access.get("cash_buy_in_required", false))
	var locked_back_room := clean_target_id == RunState.GRAND_CASINO_BACK_ROOM_ARCHETYPE_ID
	var route := {
		"id": clean_target_id,
		"destination_archetype": clean_target_id,
		"target_node_id": RunState.GRAND_CASINO_ARCHETYPE_ID,
		"cost": buy_in if requires_buy_in else 0,
		"base_cost": buy_in if requires_buy_in else 0,
		"distance": "near",
		"distance_blocks": 0,
		"risk": "",
		"suspicion_delta": 0,
		"risk_decay": 0,
		"travel_method": "Inside",
		"method": "Inside",
		"travel_minutes": travel_minutes,
		"local_casino_room": true,
	}
	var status = host.run_state.travel_route_status(route)
	var enabled := bool(status.get("available", true)) and bool(room_access.get("available", false))
	var disabled_reason := str(status.get("disabled_reason", room_access.get("reason", "")))
	var unlock_conditions: Array = []
	var preview_line := "Cross the Grand Casino interior in %d minutes." % travel_minutes
	if locked_back_room:
		enabled = false
		disabled_reason = "Locked. Rourke opens the Back Room only for a showdown."
		unlock_conditions = ["Rourke must take you there."]
		preview_line = "The Back Room door is visible, but Rourke controls the lock."
	elif requires_buy_in:
		unlock_conditions = ["Silver Players Card or a $%d cash buy-in." % buy_in]
		preview_line = "Pay the $%d cash buy-in, or enter later with Silver card access." % buy_in
		if not bool(room_access.get("available", false)):
			enabled = false
			disabled_reason = str(room_access.get("reason", "High-Limit requires Silver card access or a $%d cash buy-in." % buy_in))
	var label := str(archetype.get("display_name", "")).strip_edges()
	if label.is_empty():
		label = host._travel_label_from_archetype(archetype, clean_target_id)
	return {
		"id": clean_target_id,
		"label": label,
		"kind": str(archetype.get("kind", "boss")),
		"tier": int(archetype.get("tier", 3)),
		"description": str(archetype.get("room_description", "An interior Grand Casino room.")),
		"route": route.duplicate(true),
		"cost": int(route.get("cost", 0)),
		"risk": "",
		"suspicion_delta": 0,
		"distance": "near",
		"distance_blocks": 0,
		"risk_decay": 0,
		"travel_method": "Inside",
		"travel_minutes": travel_minutes,
		"local_door": true,
		"local_casino_room": true,
		"high_limit_buy_in": requires_buy_in,
		"attribute_badges": host.AttributeBadgesScript.for_route(route, {}),
		"unlock_conditions": unlock_conditions,
		"unlock_summary": "; ".join(unlock_conditions),
		"preview": {"level": "full", "lines": [preview_line]},
		"preview_level": "full",
		"preview_lines": [preview_line],
		"enabled": enabled,
		"disabled_reason": disabled_reason,
	}


static func local_parent_home_door_kind(host: Variant, target_id: String) -> String:
	if host.run_state == null or target_id.strip_edges().is_empty():
		return ""
	var room_node_id = host._parent_home_node_id()
	if room_node_id.is_empty():
		return ""
	var current_id = host._current_environment_archetype_id()
	var parent_id = host._parent_home_parent_target_id()
	if current_id == room_node_id and target_id == parent_id:
		return "exit"
	if current_id == parent_id and target_id == room_node_id:
		return "return"
	return ""


static func current_environment_archetype_id(host: Variant) -> String:
	if host.run_state == null:
		return ""
	return str(host.run_state.current_environment.get("world_node_id", host.run_state.current_environment.get("archetype_id", host.run_state.current_environment.get("id", "")))).strip_edges()


static func parent_home_node_id(host: Variant) -> String:
	if host.run_state == null or not host.run_state.home_is_active():
		return ""
	var home_id := str(host.run_state.home_state.get("home_archetype_id", "")).strip_edges()
	var home_archetype = host._environment_archetype(home_id)
	if str(home_archetype.get("parent_archetype", "")).strip_edges().is_empty():
		return ""
	var node_id := str(host.run_state.home_state.get("home_node_id", home_id)).strip_edges()
	return node_id if not node_id.is_empty() else home_id


static func parent_home_parent_target_id(host: Variant) -> String:
	if host.run_state == null:
		return ""
	var room_node_id = host._parent_home_node_id()
	if room_node_id.is_empty():
		return ""
	var room_archetype = host._environment_archetype(room_node_id)
	var parent_id := str(room_archetype.get("parent_archetype", "")).strip_edges()
	return parent_id
