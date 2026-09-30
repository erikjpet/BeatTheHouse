class_name EnvironmentObjectManifest
extends RefCounted

const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")

# Durable physical inventory for one generated environment/layer. Gameplay
# collections remain authoritative for selection; this manifest is their
# zero-RNG presentation projection.
const SCHEMA_VERSION := 1
const FAMILIES := ["fixed", "event", "scenario", "exit"]
const MAX_ROWS := 512
const ROW_KEYS := [
	"instance_object_id",
	"presentation_object_id",
	"object_id",
	"family",
	"source_kind",
	"source_field",
	"source_collection",
	"source_id",
	"source_index",
	"object_type",
	"placement_class",
	"required",
	"active",
	"physical",
	"render_key",
	"exact_slot_id",
	"action_ids",
	"index",
	"spot_field",
	"metadata",
]


# Rebuilds only from already-selected environment content. This method never
# receives an RNG and never selects gameplay content.
static func reconcile(environment: Dictionary, active_entries: Array, surface_map: Dictionary, existing_value: Variant = {}) -> Dictionary:
	# normalize_persisted canonicalizes an empty dictionary to {"rows": []}; keep
	# the caller's actual envelope presence before normalization so first-time room
	# construction remains distinguishable from a rendererless saved projection.
	var fresh_projection := typeof(existing_value) != TYPE_DICTIONARY or (existing_value as Dictionary).is_empty()
	var existing := normalize_persisted(existing_value)
	var source_digest := _source_digest(environment, active_entries, surface_map)
	var declarations := _fixed_declarations(surface_map)
	var attached_action_owners: Dictionary = {}
	for declaration_value in declarations:
		var declaration := _dict(declaration_value)
		var declaration_id := _declaration_instance_id(declaration)
		for action_id in _strings(declaration.get("action_ids", [])):
			if not action_id.is_empty() and action_id != declaration_id:
				attached_action_owners[action_id] = declaration_id

	var rows_by_id: Dictionary = {}
	var used_declarations: Dictionary = {}
	var family_overrides := _dict(surface_map.get("object_family_ids", {}))
	var scenario_owned := _scenario_owned_presentations(environment)
	var snapshot_present := _has_scenario_renderer_snapshot(environment)
	# Save projections intentionally omit the renderer snapshot, so a valid saved
	# manifest may preserve its exact scenario rows until trusted finalization
	# rebuilds them. Never let an invalid, cross-room, or stale envelope seed that
	# retention path: doing so would copy its rows and sign them into a fresh digest.
	var retention_manifest := existing if _manifest_can_seed_scenario_retention(existing, environment, source_digest) else {}
	for entry_value in active_entries:
		var entry := _dict(entry_value)
		var presentation_id := str(entry.get("object_id", entry.get("presentation_object_id", ""))).strip_edges()
		if presentation_id.is_empty() or attached_action_owners.has(presentation_id):
			continue
		var declaration_index := _matching_declaration_index(declarations, presentation_id)
		var declaration := _dict(declarations[declaration_index]) if declaration_index >= 0 else {}
		if declaration_index >= 0:
			used_declarations[declaration_index] = true
		var family := _entry_family(entry, presentation_id, family_overrides, scenario_owned)
		if not declaration.is_empty():
			family = "fixed"
		# Scenario mutations also appear in ordinary active collections. When the
		# renderer snapshot is absent, a saved room's only presentation authority is
		# the trusted row path below; rebuilding from a rejected envelope would invent
		# a generic row and can make that repair look canonical on its next validation
		# pass. A genuinely fresh room has no envelope to authenticate, so its already-
		# selected gameplay rows remain the authoritative initial projection. Fixed
		# declarations (including Side Door fixtures) never enter this branch.
		if family == "scenario" and not snapshot_present and not fresh_projection \
				and not _row_is_runtime_projection(entry):
			continue
		var row := _row_from_entry(environment, entry, family, surface_map)
		if not declaration.is_empty():
			row = _merge_declaration(row, declaration, surface_map)
		_upsert_row(rows_by_id, row)

	for declaration_index in range(declarations.size()):
		if used_declarations.has(declaration_index):
			continue
		var row := _row_from_declaration(_dict(declarations[declaration_index]), surface_map)
		_upsert_row(rows_by_id, row)

	var scenario_rows := _scenario_rows(environment) if snapshot_present else _retained_scenario_rows(environment, retention_manifest)
	for scenario_row_value in scenario_rows:
		_upsert_row(rows_by_id, _dict(scenario_row_value))

	var rows: Array = []
	for row_value in rows_by_id.values():
		var normalized := _normalize_row(_dict(row_value))
		if not normalized.is_empty():
			rows.append(normalized)
	rows.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left := _dict(left_value)
		var right := _dict(right_value)
		var left_family := FAMILIES.find(str(left.get("family", "")))
		var right_family := FAMILIES.find(str(right.get("family", "")))
		if left_family != right_family:
			return left_family < right_family
		return str(left.get("instance_object_id", "")) < str(right.get("instance_object_id", ""))
	)

	if _manifest_matches(existing, environment, rows, source_digest):
		# normalize_persisted already produced an owned deep copy. Reusing that
		# canonical value avoids cloning every row a second time on the common
		# idempotent layout-refresh path.
		return existing
	var revision := 1
	if int(existing.get("schema_version", 0)) == SCHEMA_VERSION:
		revision = maxi(1, int(existing.get("revision", 0)) + 1)
	var result := {
		"schema_version": SCHEMA_VERSION,
		"revision": revision,
		"environment_id": str(environment.get("id", environment.get("world_node_id", environment.get("archetype_id", "")))).strip_edges(),
		"archetype_id": str(environment.get("archetype_id", "")).strip_edges(),
		"layer_id": str(environment.get("current_layer_id", environment.get("layer_id", ""))).strip_edges(),
		"source_digest": source_digest,
		"rows": rows,
	}
	result["digest"] = digest(result)
	return result


# JSON restores numeric scalars as floats in some development/save paths. The
# manifest's schema, revision, and ordinals are exact integers, so normalize
# those losslessly before validation and idempotence checks.
static func normalize_persisted(manifest_value: Variant) -> Dictionary:
	if typeof(manifest_value) != TYPE_DICTIONARY:
		return {}
	var result := (manifest_value as Dictionary).duplicate(true)
	for field in ["schema_version", "revision"]:
		var value: Variant = result.get(field)
		if typeof(value) == TYPE_FLOAT and is_finite(float(value)) and is_equal_approx(float(value), floor(float(value))):
			result[field] = int(value)
	var normalized_rows: Array = []
	for row_value in _array(result.get("rows", [])):
		if typeof(row_value) != TYPE_DICTIONARY:
			normalized_rows.append(row_value)
			continue
		var normalized := _normalize_row(row_value as Dictionary)
		normalized_rows.append(normalized if not normalized.is_empty() else (row_value as Dictionary).duplicate(true))
	result["rows"] = normalized_rows
	return result


static func validate(manifest_value: Variant) -> Array:
	var errors: Array = []
	if typeof(manifest_value) != TYPE_DICTIONARY:
		return ["Environment object manifest must be a dictionary."]
	var manifest := manifest_value as Dictionary
	if typeof(manifest.get("schema_version")) != TYPE_INT or int(manifest.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("Environment object manifest has an unsupported schema version.")
	if typeof(manifest.get("revision")) != TYPE_INT or int(manifest.get("revision", 0)) <= 0:
		errors.append("Environment object manifest revision must be a positive integer.")
	for field in ["environment_id", "archetype_id", "layer_id", "source_digest", "digest"]:
		if typeof(manifest.get(field)) != TYPE_STRING:
			errors.append("Environment object manifest %s must be a string." % field)
	if not _valid_digest(str(manifest.get("source_digest", ""))):
		errors.append("Environment object manifest source digest is malformed.")
	if typeof(manifest.get("rows")) != TYPE_ARRAY:
		errors.append("Environment object manifest rows must be an array.")
		return errors
	var source_rows := manifest.get("rows") as Array
	if source_rows.size() > MAX_ROWS:
		errors.append("Environment object manifest exceeds the %d-row bound." % MAX_ROWS)
	var instance_ids: Dictionary = {}
	var presentation_ids: Dictionary = {}
	for row_index in range(source_rows.size()):
		if typeof(source_rows[row_index]) != TYPE_DICTIONARY:
			errors.append("Environment object manifest row %d must be a dictionary." % row_index)
			continue
		var row := source_rows[row_index] as Dictionary
		var normalized := _normalize_row(row)
		if normalized.is_empty() or normalized != row:
			errors.append("Environment object manifest row %d is malformed or non-canonical." % row_index)
			continue
		var instance_id := str(row.get("instance_object_id", ""))
		var presentation_id := str(row.get("presentation_object_id", ""))
		if instance_ids.has(instance_id):
			errors.append("Environment object manifest repeats instance identity %s." % instance_id)
		else:
			instance_ids[instance_id] = true
		if presentation_ids.has(presentation_id):
			errors.append("Environment object manifest repeats presentation identity %s." % presentation_id)
		else:
			presentation_ids[presentation_id] = true
	if not _valid_digest(str(manifest.get("digest", ""))) or str(manifest.get("digest", "")) != digest(manifest):
		errors.append("Environment object manifest digest is missing or stale.")
	return errors


# Validates the persisted envelope against the exact room/gameplay inputs that
# can be regenerated without RNG. Scenario-authored rows may be retained while
# a save omits its renderer snapshot; every other row must still match a fresh
# canonical projection byte-for-byte.
static func validate_for_environment(manifest_value: Variant, environment: Dictionary, active_entries: Array, surface_map: Dictionary) -> Array:
	var errors := validate(manifest_value)
	if not errors.is_empty():
		return errors
	var manifest := manifest_value as Dictionary
	var expected_environment_id := str(environment.get("id", environment.get("world_node_id", environment.get("archetype_id", "")))).strip_edges()
	var expected_archetype_id := str(environment.get("archetype_id", "")).strip_edges()
	var expected_layer_id := str(environment.get("current_layer_id", environment.get("layer_id", ""))).strip_edges()
	if str(manifest.get("environment_id", "")) != expected_environment_id:
		errors.append("Environment object manifest belongs to a different environment instance.")
	if str(manifest.get("archetype_id", "")) != expected_archetype_id:
		errors.append("Environment object manifest belongs to a different archetype.")
	if str(manifest.get("layer_id", "")) != expected_layer_id:
		errors.append("Environment object manifest belongs to a different environment layer.")
	var expected_source_digest := _source_digest(environment, active_entries, surface_map)
	if str(manifest.get("source_digest", "")) != expected_source_digest:
		errors.append("Environment object manifest source authority is stale.")
	if not errors.is_empty():
		return errors

	# A source-matching saved envelope is the only authority that can preserve
	# authored scenario rows when persistence intentionally omits the renderer
	# snapshot. Reconcile against that trusted envelope here too; rebuilding from
	# an empty manifest makes an ordinary active-entry projection overwrite the
	# retained scenario row and then falsely reports the valid save as stale.
	var canonical := reconcile(environment, active_entries, surface_map, manifest)
	var canonical_by_id: Dictionary = {}
	for row_value in _array(canonical.get("rows", [])):
		var row := _dict(row_value)
		canonical_by_id[str(row.get("instance_object_id", ""))] = row
	var persisted_by_id: Dictionary = {}
	for row_value in _array(manifest.get("rows", [])):
		var row := _dict(row_value)
		persisted_by_id[str(row.get("instance_object_id", ""))] = row
	for instance_id_value in canonical_by_id.keys():
		var instance_id := str(instance_id_value)
		if _dict(persisted_by_id.get(instance_id, {})) != _dict(canonical_by_id.get(instance_id, {})):
			errors.append("Environment object manifest canonical row %s is stale or altered." % instance_id)
	var snapshot_present := _has_scenario_renderer_snapshot(environment)
	for instance_id_value in persisted_by_id.keys():
		var instance_id := str(instance_id_value)
		var row := _dict(persisted_by_id.get(instance_id, {}))
		var retained_authored_scenario := not snapshot_present \
				and str(row.get("family", "")) == "scenario" \
				and not _row_is_runtime_projection(row)
		if retained_authored_scenario:
			continue
		if not canonical_by_id.has(instance_id):
			errors.append("Environment object manifest contains noncanonical row %s." % instance_id)
	return errors


static func digest(manifest: Dictionary) -> String:
	var authority := {
		"schema_version": int(manifest.get("schema_version", 0)),
		"environment_id": str(manifest.get("environment_id", "")),
		"archetype_id": str(manifest.get("archetype_id", "")),
		"layer_id": str(manifest.get("layer_id", "")),
		"source_digest": str(manifest.get("source_digest", "")),
		"rows": _array(manifest.get("rows", [])),
	}
	return _fingerprint(authority)


static func active_rows(manifest_value: Variant, family: String = "") -> Array:
	var result: Array = []
	var wanted_family := family.strip_edges()
	for row_value in _array(_dict(manifest_value).get("rows", [])):
		var row := _dict(row_value)
		if not bool(row.get("active", false)) or not bool(row.get("physical", false)):
			continue
		if not wanted_family.is_empty() and str(row.get("family", "")) != wanted_family:
			continue
		result.append(row.duplicate(true))
	return result


static func _row_from_entry(environment: Dictionary, entry: Dictionary, family: String, surface_map: Dictionary) -> Dictionary:
	var presentation_id := str(entry.get("object_id", entry.get("presentation_object_id", ""))).strip_edges()
	var object_type := str(entry.get("object_type", entry.get("visual_type", "object"))).strip_edges()
	var source := _entry_source(entry, presentation_id)
	var placement_class := str(entry.get("placement_class", "")).strip_edges()
	var exact_slot_id := ""
	# Merchandise fills stable numbered capacity by its live row ordinal. Item
	# identity is deliberately not an exact placement authority because stock is
	# selected per generated room and may change after purchases.
	if placement_class == "shop_item":
		var category_key := "%s:%d" % [str(entry.get("spot_field", "")), int(entry.get("index", 0))]
		exact_slot_id = str(_dict(surface_map.get("%s_category_slot_ids" % family, {})).get(category_key, "")).strip_edges()
	if exact_slot_id.is_empty():
		exact_slot_id = _exact_slot_preference(surface_map, family, presentation_id, presentation_id, str(source.get("source_id", "")))
	var render_key := str(entry.get("render_key", entry.get("visual_type", entry.get("visual_prop", object_type)))).strip_edges()
	var action_ids := _strings(entry.get("action_ids", [presentation_id]))
	var metadata := _entry_metadata(entry)
	metadata["environment_id"] = str(environment.get("id", ""))
	return {
		"instance_object_id": presentation_id,
		"presentation_object_id": presentation_id,
		"object_id": presentation_id,
		"family": family,
		"source_kind": str(source.get("source_kind", "environment_instance")),
		"source_field": str(source.get("source_field", "")),
		"source_collection": str(source.get("source_field", "")),
		"source_id": str(source.get("source_id", presentation_id)),
		"source_index": int(entry.get("index", 0)),
		"object_type": object_type,
		"placement_class": placement_class,
		"required": bool(entry.get("required", true)),
		"active": bool(entry.get("active", true)),
		"physical": bool(entry.get("physical", true)),
		"render_key": render_key,
		"exact_slot_id": exact_slot_id,
		"action_ids": action_ids,
		"index": int(entry.get("index", 0)),
		"spot_field": str(entry.get("spot_field", "")),
		"metadata": metadata,
	}


static func _row_from_declaration(declaration: Dictionary, surface_map: Dictionary) -> Dictionary:
	var instance_id := _declaration_instance_id(declaration)
	var presentation_id := str(declaration.get("presentation_object_id", declaration.get("presentation_id", declaration.get("object_id", instance_id)))).strip_edges()
	if presentation_id.is_empty():
		presentation_id = instance_id
	var source_id := str(declaration.get("source_id", declaration.get("id", instance_id))).strip_edges()
	var exact_slot_id := str(declaration.get("exact_slot_id", declaration.get("slot_id", ""))).strip_edges()
	if exact_slot_id.is_empty():
		exact_slot_id = _exact_slot_preference(surface_map, "fixed", instance_id, presentation_id, source_id)
	var metadata := _dict(declaration.get("metadata", {}))
	for key in ["label", "visual_type", "visual_prop", "icon_key", "role", "zone_id", "support_id", "location"]:
		if declaration.has(key):
			metadata[key] = declaration.get(key)
	return {
		"instance_object_id": instance_id,
		"presentation_object_id": presentation_id,
		"object_id": presentation_id,
		"family": "fixed",
		"source_kind": "environment_declaration",
		"source_field": "fixed_objects",
		"source_collection": "fixed_objects",
		"source_id": source_id,
		"source_index": maxi(0, int(declaration.get("source_index", declaration.get("index", 0)))),
		"object_type": str(declaration.get("object_type", declaration.get("visual_type", "fixed_object"))).strip_edges(),
		"placement_class": str(declaration.get("placement_class", "")).strip_edges(),
		"required": bool(declaration.get("required", true)),
		"active": bool(declaration.get("active", true)),
		"physical": bool(declaration.get("physical", true)),
		"render_key": str(declaration.get("render_key", declaration.get("visual_type", declaration.get("visual_prop", instance_id)))).strip_edges(),
		"exact_slot_id": exact_slot_id,
		"action_ids": _strings(declaration.get("action_ids", [])),
		"index": maxi(0, int(declaration.get("index", declaration.get("source_index", 0)))),
		"spot_field": str(declaration.get("spot_field", "fixed_objects")),
		"metadata": metadata,
	}


static func _merge_declaration(generated: Dictionary, declaration: Dictionary, surface_map: Dictionary) -> Dictionary:
	var authored := _row_from_declaration(declaration, surface_map)
	var result := generated.duplicate(true)
	for key in ROW_KEYS:
		if authored.has(key):
			result[key] = authored.get(key).duplicate(true) if typeof(authored.get(key)) in [TYPE_ARRAY, TYPE_DICTIONARY] else authored.get(key)
	var generated_actions := _strings(generated.get("action_ids", []))
	for action_id in _strings(authored.get("action_ids", [])):
		if not generated_actions.has(action_id):
			generated_actions.append(action_id)
	result["action_ids"] = generated_actions
	var metadata := _dict(generated.get("metadata", {}))
	for metadata_key in _dict(authored.get("metadata", {})).keys():
		metadata[metadata_key] = _dict(authored.get("metadata", {})).get(metadata_key)
	result["metadata"] = metadata
	return result


static func _scenario_rows(environment: Dictionary) -> Array:
	var snapshot := _dict(environment.get("scenario_render_snapshot", {}))
	var action_ids_by_presentation := _scenario_action_ids(snapshot, environment)
	var result: Array = []
	for visual_value in _array(snapshot.get("visual_objects", [])):
		var visual := _dict(visual_value)
		var presentation_id := str(visual.get("object_id", visual.get("presentation_object_id", ""))).strip_edges()
		if presentation_id.is_empty():
			continue
		var stable_id := str(visual.get("stable_object_id", visual.get("source_id", presentation_id))).strip_edges()
		var object_type := str(visual.get("object_type", "scenario_object")).strip_edges()
		var metadata := {
			"owner_namespace": str(visual.get("owner_namespace", "scenario")),
			"semantic_identity": str(visual.get("semantic_identity", "")),
			"role": str(visual.get("role", "")),
			"state": str(visual.get("state", "")),
			"scenario_id": str(snapshot.get("scenario_id", environment.get("scenario_id", ""))),
			"phase_id": str(snapshot.get("phase_id", _dict(environment.get("scenario_sequence_state", {})).get("phase_id", ""))),
		}
		result.append({
			"instance_object_id": presentation_id,
			"presentation_object_id": presentation_id,
			"object_id": presentation_id,
			"family": "scenario",
			"source_kind": "scenario_projection",
			"source_field": "actors" if object_type == "scenario_actor" else "scene_objects",
			"source_collection": "actors" if object_type == "scenario_actor" else "scene_objects",
			"source_id": stable_id,
			"source_index": result.size(),
			"object_type": object_type,
			"placement_class": str(visual.get("placement_class", "")).strip_edges(),
			"required": bool(visual.get("presentation_required", true)),
			"active": bool(visual.get("present", true)) and bool(visual.get("visible", true)),
			"physical": true,
			"render_key": str(visual.get("render_key", visual.get("icon_key", visual.get("visual_type", object_type)))).strip_edges(),
			"exact_slot_id": str(visual.get("slot_id", "")).strip_edges(),
			"action_ids": _strings(action_ids_by_presentation.get(presentation_id, [])),
			"index": result.size(),
			"spot_field": "scenario_slots",
			"metadata": metadata,
		})
	return result


static func _scenario_action_ids(snapshot: Dictionary, environment: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var interactions := _array(snapshot.get("interaction_overlays", []))
	if interactions.is_empty():
		interactions = _dict(_dict(environment.get("scenario_sequence_projection", {})).get("semantic_state", {})).get("interactions", {}).values()
	for interaction_value in interactions:
		var interaction := _dict(interaction_value)
		var presentation_id := str(interaction.get("presentation_object_id", interaction.get("object_id", ""))).strip_edges()
		if presentation_id.is_empty():
			var owner := str(interaction.get("owner_namespace", "")).strip_edges()
			var stable_id := str(interaction.get("stable_object_id", "")).strip_edges()
			if not owner.is_empty() and not stable_id.is_empty():
				presentation_id = "%s::%s" % [owner, stable_id]
		if presentation_id.is_empty():
			continue
		var action_ids := _strings(result.get(presentation_id, []))
		for action_value in _array(interaction.get("available_actions", [])):
			var action_id := str(_dict(action_value).get("id", "")).strip_edges()
			if not action_id.is_empty() and not action_ids.has(action_id):
				action_ids.append(action_id)
		result[presentation_id] = action_ids
	return result


static func _retained_scenario_rows(environment: Dictionary, existing: Dictionary) -> Array:
	var state := _dict(environment.get("scenario_state", {}))
	var sequence_state := _dict(environment.get("scenario_sequence_state", {}))
	if state.is_empty() and sequence_state.is_empty():
		return []
	if not _array(environment.get("scenario_sequence_lifecycle_errors", [])).is_empty():
		return []
	if int(environment.get("scenario_applied_phase_index", 0)) < 0:
		return []
	var result: Array = []
	for row_value in _array(existing.get("rows", [])):
		var row := _dict(row_value)
		# Scenario-authored rows are durable when the save intentionally omits its
		# renderer snapshot. Runtime projections may also consume scenario capacity,
		# but their authoritative source is RunState and must never be resurrected
		# from the old manifest after an offscreen save strips that source.
		if str(row.get("family", "")) == "scenario" and not _row_is_runtime_projection(row):
			result.append(row.duplicate(true))
	return result


static func _row_is_runtime_projection(row: Dictionary) -> bool:
	for field in ["spot_field", "source_field", "source_collection"]:
		if str(row.get(field, "")).strip_edges() == "runtime_object_manifest_entries":
			return true
	return false


static func _manifest_can_seed_scenario_retention(existing: Dictionary, environment: Dictionary, source_digest: String) -> bool:
	if not validate(existing).is_empty() or str(existing.get("source_digest", "")) != source_digest:
		return false
	var environment_id := str(environment.get("id", environment.get("world_node_id", environment.get("archetype_id", "")))).strip_edges()
	if str(existing.get("environment_id", "")) != environment_id:
		return false
	if str(existing.get("archetype_id", "")) != str(environment.get("archetype_id", "")).strip_edges():
		return false
	return str(existing.get("layer_id", "")) == str(environment.get("current_layer_id", environment.get("layer_id", ""))).strip_edges()


static func _scenario_owned_presentations(environment: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var state := _dict(environment.get("scenario_state", {}))
	if not state.is_empty():
		var wanted_layer := str(state.get("layer_id", "")).strip_edges()
		var current_layer := str(environment.get("current_layer_id", "")).strip_edges()
		if wanted_layer.is_empty() or wanted_layer == current_layer:
			_collect_scenario_mutation_ids(result, _dict(state.get("mutations", {})))
			var phases := _array(state.get("phases", []))
			var phase_index := mini(maxi(0, int(state.get("phase_index", 0))), phases.size() - 1) if not phases.is_empty() else -1
			for index in range(phase_index + 1):
				_collect_scenario_mutation_ids(result, _dict(_dict(phases[index]).get("mutations", {})))
	var opportunity := _dict(environment.get("scenario_exclusive_opportunity", {}))
	for pair in [["event_id", "event"], ["game_id", "game"]]:
		var source_id := str(opportunity.get(str(pair[0]), "")).strip_edges()
		if not source_id.is_empty():
			result["%s:%s" % [str(pair[1]), source_id]] = true
	for baseline_pair in [["game_ids", "scenario_sequence_base_game_ids", "game"], ["service_ids", "scenario_sequence_base_service_ids", "service"]]:
		if not environment.has(str(baseline_pair[1])):
			continue
		var baseline := _strings(environment.get(str(baseline_pair[1]), []))
		for source_id in _strings(environment.get(str(baseline_pair[0]), [])):
			if not baseline.has(source_id):
				result["%s:%s" % [str(baseline_pair[2]), source_id]] = true
	return result


static func _collect_scenario_mutation_ids(target: Dictionary, mutations: Dictionary) -> void:
	for pair in [["event_pool_add", "event"], ["service_add", "service"]]:
		for source_id in _strings(mutations.get(str(pair[0]), [])):
			target["%s:%s" % [str(pair[1]), source_id]] = true
	for offer_value in _array(mutations.get("item_offer_add", [])):
		var item_id := str(_dict(offer_value).get("id", "")).strip_edges()
		if not item_id.is_empty():
			target["item:%s" % item_id] = true
	var opportunity := _dict(mutations.get("exclusive_opportunity", {}))
	for pair in [["event_id", "event"], ["game_id", "game"]]:
		var source_id := str(opportunity.get(str(pair[0]), "")).strip_edges()
		if not source_id.is_empty():
			target["%s:%s" % [str(pair[1]), source_id]] = true


static func _entry_family(entry: Dictionary, presentation_id: String, overrides: Dictionary, scenario_owned: Dictionary) -> String:
	var override_value: Variant = overrides.get(presentation_id, "")
	var override_family := str(_dict(override_value).get("family", "")) if typeof(override_value) == TYPE_DICTIONARY else str(override_value)
	if FAMILIES.has(override_family):
		return override_family
	var entry_family := str(entry.get("slot_family", entry.get("family", ""))).strip_edges().to_lower()
	if FAMILIES.has(entry_family):
		return entry_family
	var object_type := str(entry.get("object_type", ""))
	if object_type == "travel" or presentation_id == "travel:leave" or presentation_id.begins_with("travel:"):
		return "exit"
	if object_type == "environment_layer" and presentation_id != "environment_layer:ambient":
		return "exit"
	if scenario_owned.has(presentation_id):
		return "scenario"
	if object_type == "event":
		return "event"
	return "fixed"


static func _entry_source(entry: Dictionary, presentation_id: String) -> Dictionary:
	var object_type := str(entry.get("object_type", "object"))
	var source_field: String = str({
		"game": "game_ids",
		"event": "event_ids",
		"item": "item_offers",
		"service": "service_ids",
		"lender": "lender_hooks",
		"shopkeeper": "object_fixtures",
		"travel": "travel_hooks+next_archetypes",
		"environment_layer": "layer_transitions",
		"casino_fixture": "local_narrative_flags.casino_fixtures",
		"game_hook": "game_states.environment_hooks",
		"home_container": "home_containers",
		"home_storage": "home_profile",
		"home_tenure": "home_profile",
		"home_sleep": "home_profile",
		"numbers": "numbers_state",
		"numbers_silas": "numbers_state",
	}.get(object_type, "environment_instance"))
	var source_id := str(entry.get("source_id", "")).strip_edges()
	if source_id.is_empty():
		source_id = presentation_id.get_slice(":", 1) if presentation_id.contains(":") else presentation_id
	return {
		"source_kind": "environment_instance",
		"source_field": source_field,
		"source_id": source_id,
	}


static func _entry_metadata(entry: Dictionary) -> Dictionary:
	var result := _dict(entry.get("metadata", {})).duplicate(true)
	for key in ["label", "visual_type", "visual_prop", "icon_key", "role", "zone_id", "support_id", "location", "unique_object_class", "physical_person", "slot_binding_source_id"]:
		if entry.has(key):
			result[key] = entry.get(key)
	return result


static func _fixed_declarations(surface_map: Dictionary) -> Array:
	var value: Variant = surface_map.get("fixed_objects", [])
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for row_value in value as Array:
			if typeof(row_value) == TYPE_DICTIONARY:
				result.append((row_value as Dictionary).duplicate(true))
	elif typeof(value) == TYPE_DICTIONARY:
		var keys := (value as Dictionary).keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		for key_value in keys:
			var row := _dict((value as Dictionary).get(key_value, {}))
			if row.is_empty():
				continue
			if not row.has("instance_object_id") and not row.has("object_id") and not row.has("id"):
				row["instance_object_id"] = str(key_value)
			result.append(row)
	return result


static func _matching_declaration_index(declarations: Array, presentation_id: String) -> int:
	for index in range(declarations.size()):
		var declaration := _dict(declarations[index])
		if presentation_id in [
			_declaration_instance_id(declaration),
			str(declaration.get("presentation_object_id", "")).strip_edges(),
			str(declaration.get("presentation_id", "")).strip_edges(),
			str(declaration.get("object_id", "")).strip_edges(),
		]:
			return index
	return -1


static func _declaration_instance_id(declaration: Dictionary) -> String:
	return str(declaration.get("instance_object_id", declaration.get("object_id", declaration.get("id", "")))).strip_edges()


static func _exact_slot_preference(surface_map: Dictionary, family: String, instance_id: String, presentation_id: String, source_id: String) -> String:
	var preferences := _dict(surface_map.get("%s_object_slot_ids" % family, {}))
	for candidate in [instance_id, presentation_id, source_id]:
		var preference := str(preferences.get(candidate, "")).strip_edges()
		if not preference.is_empty():
			return preference
	return ""


static func _normalize_row(source: Dictionary) -> Dictionary:
	var instance_id := str(source.get("instance_object_id", "")).strip_edges()
	var presentation_id := str(source.get("presentation_object_id", source.get("object_id", ""))).strip_edges()
	var family := str(source.get("family", "")).strip_edges()
	if instance_id.is_empty() or presentation_id.is_empty() or not FAMILIES.has(family):
		return {}
	var action_ids := _strings(source.get("action_ids", []))
	action_ids.sort()
	var result := {
		"instance_object_id": instance_id,
		"presentation_object_id": presentation_id,
		"object_id": presentation_id,
		"family": family,
		"source_kind": str(source.get("source_kind", "environment_instance")).strip_edges(),
		"source_field": str(source.get("source_field", source.get("source_collection", ""))).strip_edges(),
		"source_collection": str(source.get("source_collection", source.get("source_field", ""))).strip_edges(),
		"source_id": str(source.get("source_id", instance_id)).strip_edges(),
		"source_index": maxi(0, int(source.get("source_index", source.get("index", 0)))),
		"object_type": str(source.get("object_type", "object")).strip_edges(),
		"placement_class": str(source.get("placement_class", "")).strip_edges(),
		"required": bool(source.get("required", true)),
		"active": bool(source.get("active", true)),
		"physical": bool(source.get("physical", true)),
		"render_key": str(source.get("render_key", "")).strip_edges(),
		"exact_slot_id": str(source.get("exact_slot_id", "")).strip_edges(),
		"action_ids": action_ids,
		"index": maxi(0, int(source.get("index", source.get("source_index", 0)))),
		"spot_field": str(source.get("spot_field", "")).strip_edges(),
		"metadata": _dict(source.get("metadata", {})),
	}
	if result["source_kind"].is_empty() or result["source_field"].is_empty() or result["source_id"].is_empty() or result["object_type"].is_empty():
		return {}
	return result


static func _upsert_row(rows_by_id: Dictionary, row: Dictionary) -> void:
	var normalized := _normalize_row(row)
	if normalized.is_empty():
		return
	var instance_id := str(normalized.get("instance_object_id", ""))
	var presentation_id := str(normalized.get("presentation_object_id", ""))
	# A declaration may use a purpose-specific instance id while replacing a
	# generated action-facing presentation id. Remove either collision before
	# inserting the authoritative physical host.
	for prior_id_value in rows_by_id.keys():
		var prior := _dict(rows_by_id.get(prior_id_value, {}))
		if str(prior.get("presentation_object_id", "")) == presentation_id and str(prior_id_value) != instance_id:
			rows_by_id.erase(prior_id_value)
	rows_by_id[instance_id] = normalized


static func _has_scenario_renderer_snapshot(environment: Dictionary) -> bool:
	if typeof(environment.get("scenario_render_snapshot")) != TYPE_DICTIONARY:
		return false
	var snapshot := environment.get("scenario_render_snapshot") as Dictionary
	return bool(snapshot.get("ok", false)) and typeof(snapshot.get("visual_objects")) == TYPE_ARRAY


static func _source_digest(environment: Dictionary, active_entries: Array, surface_map: Dictionary) -> String:
	var offer_ids: Array = []
	for offer_value in _array(environment.get("item_offers", [])):
		var offer_id := str(_dict(offer_value).get("id", "")).strip_edges()
		if not offer_id.is_empty():
			offer_ids.append(offer_id)
	var container_ids: Array = []
	for container_value in _array(environment.get("home_containers", [])):
		var container_id := str(_dict(container_value).get("id", "")).strip_edges()
		if not container_id.is_empty():
			container_ids.append(container_id)
	var state := _dict(environment.get("scenario_state", {}))
	var sequence_state := _dict(environment.get("scenario_sequence_state", {}))
	var resolved_event_ids := _strings(environment.get("resolved_event_ids", []))
	resolved_event_ids.sort()
	var semantic := _dict(sequence_state.get("semantic_state", {}))
	# Manifest rows already seal the concrete scenario presentation. The source
	# digest must use the same durable sequence proof saved by EnvironmentInstance,
	# otherwise a valid save (which intentionally strips rebuilt semantic visuals)
	# looks stale and loses every scenario slot on its first restore.
	var durable_semantic := semantic.duplicate(true)
	for transient_key in [
		"target_inventory", "declared_targets", "base_interactions", "event_choices",
		"scene_objects", "interactions", "actors", "services", "games", "routes",
		"transition_queue", "tombstones",
	]:
		durable_semantic.erase(transient_key)
	var scenario_source := {
		"scenario_id": str(state.get("id", sequence_state.get("scenario_id", environment.get("scenario_id", "")))),
		"phase_index": int(state.get("phase_index", environment.get("scenario_phase_index", 0))),
		# A legacy phase's action counter advances between physical transitions.
		# Hash the phase identity, not that presentation-neutral clock, so ordinary
		# turns cannot invalidate an otherwise unchanged physical inventory.
		"status": str(sequence_state.get("status", "")),
		"phase_id": str(sequence_state.get("phase_id", "")),
		"boundary_serial": int(sequence_state.get("boundary_serial", 0)),
		"durable_semantic": durable_semantic,
	}
	var entry_source: Array = []
	for entry_value in active_entries:
		var entry := _dict(entry_value)
		# Runtime-owned rows are a live projection of RunState authorities such as
		# Crew residency, delivery position, the Numbers itinerary, and Grand Casino
		# floor movement. Their concrete rows remain sealed by the manifest digest,
		# but they must not invalidate the durable source seal used to retain scenario
		# rows while a saved renderer snapshot is absent. This lets persistence omit
		# offscreen runtime projections and rebuild them on installation without
		# discarding otherwise valid scenario-family inventory.
		if not str(entry.get("runtime_owner", "")).strip_edges().is_empty() \
				or str(entry.get("spot_field", "")).strip_edges() == "runtime_object_manifest_entries":
			continue
		entry_source.append({
			"object_id": str(entry.get("object_id", "")),
			"object_type": str(entry.get("object_type", "")),
			"index": int(entry.get("index", 0)),
			"placement_class": str(entry.get("placement_class", "")),
			"slot_family": str(entry.get("slot_family", entry.get("family", ""))),
			"render_key": str(entry.get("render_key", "")),
			"spot_field": str(entry.get("spot_field", "")),
			"metadata": _dict(entry.get("metadata", {})),
			"active": bool(entry.get("active", true)),
		})
	entry_source.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		return str(_dict(left_value).get("object_id", "")) < str(_dict(right_value).get("object_id", ""))
	)
	return _fingerprint({
		"schema_version": SCHEMA_VERSION,
		"environment_id": str(environment.get("id", "")),
		"archetype_id": str(environment.get("archetype_id", "")),
		"layer_id": str(environment.get("current_layer_id", "")),
		"game_ids": _strings(environment.get("game_ids", [])),
		"event_ids": _strings(environment.get("event_ids", [])),
		"resolved_event_ids": resolved_event_ids,
		"item_offer_ids": offer_ids,
		"service_ids": _strings(environment.get("service_ids", [])),
		"lender_hooks": _strings(environment.get("lender_hooks", [])),
		"object_fixtures": _strings(environment.get("object_fixtures", [])),
		"travel_hooks": _strings(environment.get("travel_hooks", [])),
		"next_archetypes": _strings(environment.get("next_archetypes", [])),
		"layer_transitions": _array(environment.get("layer_transitions", [])),
		"home_container_ids": container_ids,
		"home_lost": bool(environment.get("home_lost", false)),
		"active_entries": entry_source,
		"fixed_objects": _fixed_declarations(surface_map),
		"object_family_ids": _dict(surface_map.get("object_family_ids", {})),
		"fixed_object_slot_ids": _dict(surface_map.get("fixed_object_slot_ids", {})),
		"fixed_category_slot_ids": _dict(surface_map.get("fixed_category_slot_ids", {})),
		"event_object_slot_ids": _dict(surface_map.get("event_object_slot_ids", {})),
		"event_category_slot_ids": _dict(surface_map.get("event_category_slot_ids", {})),
		"scenario_object_slot_ids": _dict(surface_map.get("scenario_object_slot_ids", {})),
		"scenario_category_slot_ids": _dict(surface_map.get("scenario_category_slot_ids", {})),
		"exit_object_slot_ids": _dict(surface_map.get("exit_object_slot_ids", {})),
		"exit_category_slot_ids": _dict(surface_map.get("exit_category_slot_ids", {})),
		"scenario": scenario_source,
	})


static func _manifest_matches(existing: Dictionary, environment: Dictionary, rows: Array, source_digest: String) -> bool:
	if not validate(existing).is_empty():
		return false
	if str(existing.get("environment_id", "")) != str(environment.get("id", environment.get("world_node_id", environment.get("archetype_id", "")))):
		return false
	if str(existing.get("archetype_id", "")) != str(environment.get("archetype_id", "")):
		return false
	if str(existing.get("layer_id", "")) != str(environment.get("current_layer_id", environment.get("layer_id", ""))):
		return false
	if str(existing.get("source_digest", "")) != source_digest:
		return false
	return _fingerprint(existing.get("rows", [])) == _fingerprint(rows)


static func _valid_digest(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return false
	return true


static func _fingerprint(value: Variant) -> String:
	return JSON.stringify(_canonical(value)).sha256_text()


static func _canonical(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var source := value as Dictionary
		var keys := source.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		var result: Dictionary = {}
		for key_value in keys:
			result[str(key_value)] = _canonical(source.get(key_value))
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for item in value as Array:
			result.append(_canonical(item))
		return result
	return value


static func _strings(value: Variant) -> Array:
	var result: Array = []
	for item in _array(value):
		var text := str(item).strip_edges()
		if not text.is_empty() and not result.has(text):
			result.append(text)
	return result


static func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []
