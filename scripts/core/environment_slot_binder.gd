class_name EnvironmentSlotBinder
extends RefCounted

const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const EnvironmentObjectManifestScript := preload("res://scripts/core/environment_object_manifest.gd")
const ArtContractsScript := preload("res://scripts/core/art_contracts.gd")

const BOARD_SIZE := Vector2(900.0, 430.0)
const MIN_INTERACTIVE_TARGET := Vector2(44.0, 44.0)
const SMALL_SCREEN_TARGET := Vector2(ArtContractsScript.ENVIRONMENT_OBJECT_HIT_SIZE)
const LABEL_MIN_WIDTH := 48.0
const LABEL_MAX_WIDTH := 126.0
const LABEL_HEIGHT := 15.0
const LABEL_TWO_LINE_HEIGHT := 26.0
const LABEL_GAP := 4.0
const LABEL_MARGIN := 16.0
const SLOT_SCHEMA_VERSION := 2
const SLOT_FAMILIES := ["fixed", "event", "scenario", "exit"]
const PRESENTATION_ROOM := "room"
const PRESENTATION_OVERFLOW := "overflow"
const BASE_BINDING_KEYS := ["identity", "kind", "slot_family", "presentation_mode", "slot_id", "placement_class", "slot"]
const BASE_LAYOUT_AUTHORITY_KEYS := ["slot_schema_version", "slot_map_digest", "slot_binding_digest", "slot_bindings", "slot_overflow_ids", "object_rects"]

# Scenario scene objects may consume generic scenario geometry only when either
# their stable identity or their closed semantic payload names a reviewed
# concrete renderer. Location still comes from a compatible shared scenario
# slot; labels and keyword classification never mint physical authority.
const CONCRETE_SCENARIO_ART_KEYS := [
	"counter_phone", "jammed_machine", "motel_door", "paper_note", "payphone",
	"room_barrier", "room_display", "room_fixture", "room_hazard", "room_refreshment",
	"room_route", "room_seating", "room_signal", "room_storage", "room_surface", "room_trace",
	"room_vehicle", "rowdy_regular", "security_camera", "side_door", "trunk_offer",
]

# These semantic families are action/route explanations even when their label
# mentions a physical noun or an old icon fallback happens to resemble a prop.
# A real prop used by one of these actions must be authored as a separate scene
# object with its own stable id, slot preference, and concrete art key.
const ABSTRACT_SCENARIO_ROLES := [
	"barrier", "decision_route", "exit", "game_lane",
	"ledger", "primary_task", "route",
	"route_hazard", "route_marker", "task_station", "task_zone",
]

# These authored scene-operation roles are controls attached to a tangible
# room host, never independent physical markers. ``game_lane`` deliberately
# remains outside this list because its lane geometry is manually positioned.
const ATTACHED_SCENARIO_CONTROL_ROLES := [
	"decision_route", "task_station", "task_zone",
]

const ABSTRACT_SCENARIO_ID_TOKENS := [
	"barrier", "choice", "ledger", "marker", "route", "seal", "task",
	"trace", "work_zone", "zone",
]

# Base inventory uses the same physical-only presentation rule as scenario
# inventory. These are closed renderer contracts, not guesses from labels,
# roles, ids, placement classes, or general icon names.
# Casino fixtures bind interaction targets to room-native desks, counters, and
# machines that the environment canvas already renders as permanent scenery.
const BASE_ALWAYS_PHYSICAL_TYPES := [
	"casino_fixture", "environment_layer", "game", "home_container", "home_storage", "home_tenure", "item",
	"meta_bag", "meta_pawn_counter", "meta_trade_up", "meta_upgrade", "numbers", "shopkeeper", "numbers_silas",
]
const BASE_PERSON_VISUAL_TYPES := ["actor", "character", "npc"]
const BASE_ALWAYS_PHYSICAL_OBJECT_IDS := [
	"game_hook:pull_tabs:ticket_redeemer",
	"game_hook:scratch_tickets:scratch_ticket_clerk",
	"dialogue:scratch_ticket_scalper",
	"travel:grand_casino",
	"travel:grand_casino_back_room",
	"travel:grand_casino_cage",
	"travel:grand_casino_high_limit",
	"travel:leave",
]
const BASE_ACTION_ONLY_EVENT_IDS := [
	"event:scenario_bringer_show_favor",
	"event:scenario_punchline_high_stakes_table",
	"event:scenario_slow_night_intel",
]
const BASE_EVENT_ART_PROPS := [
	"casino_host", "clerk_counter", "clerk_talk", "counter_phone",
	"jammed_machine", "motel_door", "paper_note", "payphone", "pit_boss",
	"room_display", "room_hazard", "room_refreshment",
	"room_seating", "room_signal", "room_storage", "room_surface",
	"room_vehicle", "rowdy_patron", "security_camera", "security_exit",
	"side_door", "trunk_offer",
]


# Binds the complete generated base inventory to immutable authored slots.
# No coordinate search, displacement, repack, fallback grid, or RNG is used.
static func bind_base_layout(environment: Dictionary, active_entries: Array, shared_occupancy: Dictionary = {}) -> Dictionary:
	var surface_map := EnvironmentPlacementScript.surface_map(environment)
	var family_slots: Dictionary = {}
	var room_slots: Array = []
	for family_value in SLOT_FAMILIES:
		var family := str(family_value)
		var ordered_family_slots := _family_slots(surface_map, family)
		family_slots[family] = ordered_family_slots
		room_slots.append_array(ordered_family_slots)
	var initial_occupancy := shared_occupancy.duplicate(true)
	var occupied := initial_occupancy.duplicate(true)
	var object_rects: Dictionary = {}
	var bindings: Dictionary = {}
	var overflow_ids: Array = []
	var warnings: Array = []
	var errors := _surface_map_errors(surface_map)
	var warning_scope := "environment layout %s" % str(surface_map.get("id", environment.get("archetype_id", "unknown")))
	var scenario_state := _dict(environment.get("scenario_sequence_state", environment.get("scenario_state", {})))
	var scenario_id := str(scenario_state.get("scenario_id", scenario_state.get("id", ""))).strip_edges()
	if not scenario_id.is_empty():
		warning_scope += "/%s" % scenario_id
	var entries := active_entries.duplicate()
	var entry_sort_keys: Dictionary = {}
	for entry_value in entries:
		var sortable_entry := _dict_view(entry_value)
		var sortable_id := str(sortable_entry.get("object_id", ""))
		entry_sort_keys[sortable_id] = {
			"shop_order": _shop_item_order(environment, sortable_id),
			"exact": bool(_slot_preference(surface_map, sortable_entry, sortable_id).get("exact", false)),
		}
	entries.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left := _dict_view(left_value)
		var right := _dict_view(right_value)
		var left_id := str(left.get("object_id", ""))
		var right_id := str(right.get("object_id", ""))
		var left_key := _dict_view(entry_sort_keys.get(left_id, {}))
		var right_key := _dict_view(entry_sort_keys.get(right_id, {}))
		var left_shop_order := int(left_key.get("shop_order", -1))
		var right_shop_order := int(right_key.get("shop_order", -1))
		var left_exact := bool(left_key.get("exact", false))
		var right_exact := bool(right_key.get("exact", false))
		if left_exact != right_exact:
			return left_exact
		if left_shop_order >= 0 and right_shop_order >= 0 and left_shop_order != right_shop_order:
			return left_shop_order < right_shop_order
		return left_id < right_id
	)
	for entry_value in entries:
		var entry := _dict(entry_value)
		var object_id := str(entry.get("object_id", "")).strip_edges()
		if object_id.is_empty() or bindings.has(object_id):
			continue
		var class_override := str(_dict(surface_map.get("class_overrides", {})).get(object_id, ""))
		var manifest_class := str(entry.get("placement_class", "")).strip_edges()
		var placement_class := class_override if class_override in EnvironmentPlacementScript.CLASSES else manifest_class if manifest_class in EnvironmentPlacementScript.CLASSES else EnvironmentPlacementScript.classify(
			entry,
			str(entry.get("object_type", "")),
			object_id,
			str(entry.get("visual_prop", entry.get("prop", "")))
		)
		placement_class = _normalize_base_placement_class(environment, entry, object_id, class_override, placement_class)
		var binding_source_id := str(entry.get("slot_binding_source_id", "")).strip_edges()
		if not binding_source_id.is_empty() and binding_source_id != object_id:
			# This record contributes actions to an already physical room object;
			# it is not a second person or fixture and therefore owns no slot.
			continue
		if not base_record_requires_room_slot(entry):
			# Action-only records are attached to a visible room object by the
			# interaction composer and never enter the physical slot inventory.
			continue
		var slot_family := authored_entry_slot_family(surface_map, entry, object_id)
		if slot_family.is_empty():
			errors.append("%s physical object %s is missing a valid four-family slot assignment." % [warning_scope, object_id])
			continue
		var preference_data := _slot_preference(surface_map, entry, object_id)
		var preference := str(preference_data.get("slot_id", "")).strip_edges()
		# Generated base records are actionable by default. Decorative-only late
		# records bypass this inventory; never serialize an undersized room target.
		var candidate_slots := _candidate_slots_for_preference(
			surface_map,
			slot_family,
			preference_data,
			_array_view(family_slots.get(slot_family, []))
		)
		placement_class = _exit_preference_class(candidate_slots, slot_family, preference, placement_class)
		var slot := _select_slot(candidate_slots, occupied, placement_class, preference, bool(preference_data.get("exact", false)), MIN_INTERACTIVE_TARGET)
		if slot.is_empty():
			_warn_missing_family_slot(warning_scope, object_id, slot_family, placement_class, warnings, errors)
			continue
		var slot_id := str(slot.get("id", ""))
		occupied[slot_id] = object_id
		var binding := _room_binding(object_id, placement_class, slot_family, slot)
		bindings[object_id] = binding
		object_rects[object_id] = _normalized_rect(_slot_rect(slot))
	var guarded := guard_unique_slot_bindings(bindings, {}, initial_occupancy, room_slots, "environment layout")
	bindings = _dict(guarded.get("slot_bindings", bindings))
	occupied = _dict(guarded.get("occupied_slots", occupied))
	for overflow_id_value in _array(guarded.get("overflow_ids", [])):
		if not overflow_ids.has(overflow_id_value):
			overflow_ids.append(overflow_id_value)
	overflow_ids.sort()
	warnings.append_array(_array(guarded.get("warnings", [])))
	errors.append_array(_array(guarded.get("errors", [])))
	object_rects = _object_rects_from_bindings(bindings)
	_replace_dictionary(shared_occupancy, occupied)
	return {
		"ok": errors.is_empty(),
		"slot_schema_version": SLOT_SCHEMA_VERSION,
		"slot_map_digest": slot_map_digest(surface_map),
		"binding_digest": binding_digest(bindings),
		"slot_bindings": bindings,
		"object_rects": object_rects,
		"overflow_ids": overflow_ids,
		"occupied_slot_ids": occupied.keys(),
		"occupied_slots": occupied,
		"warnings": warnings,
		"errors": errors,
	}


# Authenticates the complete persisted base-slot envelope before any caller may
# reuse it, extend it with late records, or derive semantic authority from it.
# Room bindings are immutable authored reservations; only bindings with a live
# object_rect are rendered. Overflow is the one geometry-free presentation.
static func validate_base_layout_authority(
	environment: Dictionary,
	current_records: Array = [],
	allow_unbound_records: bool = false,
	validation_context: Dictionary = {}
) -> Dictionary:
	var errors: Array = []
	var layout_value: Variant = environment.get("layout")
	if typeof(layout_value) != TYPE_DICTIONARY:
		return {"ok": false, "errors": ["Persisted base slot authority has no layout dictionary."]}
	var layout := _dict(layout_value)
	for key in BASE_LAYOUT_AUTHORITY_KEYS:
		if not layout.has(key):
			errors.append("Persisted base slot authority is missing %s." % key)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	if typeof(layout.get("slot_schema_version")) != TYPE_INT or int(layout.get("slot_schema_version", 0)) != SLOT_SCHEMA_VERSION:
		errors.append("Persisted base slot authority has an invalid schema version.")
	var context_surface_value: Variant = validation_context.get("surface_map")
	var surface_map := _dict_view(context_surface_value) \
		if typeof(context_surface_value) == TYPE_DICTIONARY \
		else EnvironmentPlacementScript.surface_map(environment)
	if validation_context.has("surface_errors"):
		errors.append_array(_array_view(validation_context.get("surface_errors", [])))
	else:
		errors.append_array(_surface_map_errors(surface_map))
	var exact_action_host_ids := _dict_view(surface_map.get("scenario_instance_action_host_ids", {}))
	var expected_map_digest := str(validation_context.get("slot_map_digest", ""))
	if expected_map_digest.is_empty():
		expected_map_digest = slot_map_digest(surface_map)
	if typeof(layout.get("slot_map_digest")) != TYPE_STRING or str(layout.get("slot_map_digest", "")) != expected_map_digest:
		errors.append("Persisted base slot authority does not match the authored slot map digest.")
	if typeof(layout.get("slot_bindings")) != TYPE_DICTIONARY:
		errors.append("Persisted base slot authority bindings must be a dictionary.")
	if typeof(layout.get("slot_overflow_ids")) != TYPE_ARRAY:
		errors.append("Persisted base slot authority overflow ids must be an array.")
	if typeof(layout.get("object_rects")) != TYPE_DICTIONARY:
		errors.append("Persisted base slot authority object_rects must be a dictionary.")
	if typeof(layout.get("slot_binding_digest")) != TYPE_STRING:
		errors.append("Persisted base slot authority binding digest must be a string.")
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	var bindings := _dict(layout.get("slot_bindings", {}))
	var object_rects := _dict(layout.get("object_rects", {}))
	var manifest_rows := _validated_manifest_rows_by_presentation(environment, errors)
	var current_records_by_id: Dictionary = {}
	for record_value in current_records:
		var record := _dict(record_value)
		var record_id := str(record.get("object_id", record.get("presentation_object_id", ""))).strip_edges()
		if not record_id.is_empty() and not current_records_by_id.has(record_id):
			current_records_by_id[record_id] = record
	var stored_digest := str(layout.get("slot_binding_digest", ""))
	if stored_digest.is_empty() or stored_digest != binding_digest(bindings):
		errors.append("Persisted base slot authority binding digest is missing or stale.")
	var context_slots_value: Variant = validation_context.get("authored_slots")
	var authored_slots := _dict_view(context_slots_value) \
		if typeof(context_slots_value) == TYPE_DICTIONARY \
		else _slots_by_id(_all_family_slots(surface_map))
	var overflow_ids: Array = []
	var room_ids_by_slot: Dictionary = {}
	var binding_ids := bindings.keys()
	binding_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	for identity_value in binding_ids:
		if typeof(identity_value) != TYPE_STRING:
			errors.append("Persisted base slot authority contains a non-string binding key.")
			continue
		var identity := str(identity_value)
		if identity.is_empty() or identity != identity.strip_edges():
			errors.append("Persisted base slot authority contains a malformed binding key.")
			continue
		var binding_value: Variant = bindings.get(identity_value)
		if typeof(binding_value) != TYPE_DICTIONARY:
			errors.append("Persisted base slot binding %s must be a dictionary." % identity)
			continue
		var binding := _dict(binding_value)
		if not _closed_dictionary(binding, BASE_BINDING_KEYS):
			errors.append("Persisted base slot binding %s is not closed." % identity)
			continue
		var field_types_valid := true
		for string_key in ["identity", "kind", "slot_family", "presentation_mode", "slot_id", "placement_class"]:
			if typeof(binding.get(string_key)) != TYPE_STRING:
				errors.append("Persisted base slot binding %s field %s must be a string." % [identity, string_key])
				field_types_valid = false
		if typeof(binding.get("slot")) != TYPE_DICTIONARY:
			errors.append("Persisted base slot binding %s slot must be a dictionary." % identity)
			field_types_valid = false
		if not field_types_valid:
			continue
		if str(binding.get("identity", "")) != identity:
			errors.append("Persisted base slot binding %s does not match its dictionary key." % identity)
		var slot_family := str(binding.get("slot_family", ""))
		if slot_family not in SLOT_FAMILIES or str(binding.get("kind", "")) != slot_family:
			errors.append("Persisted environment slot binding %s has an invalid or inconsistent slot family." % identity)
		var placement_class := str(binding.get("placement_class", ""))
		if placement_class not in EnvironmentPlacementScript.CLASSES:
			errors.append("Persisted base slot binding %s has an invalid placement class." % identity)
		var mode := str(binding.get("presentation_mode", ""))
		var slot_id := str(binding.get("slot_id", ""))
		var binding_slot := _dict(binding.get("slot", {}))
		if mode == PRESENTATION_OVERFLOW:
			overflow_ids.append(identity)
			if not slot_id.is_empty() or not binding_slot.is_empty() or object_rects.has(identity):
				errors.append("Persisted base overflow binding %s is not geometry-free." % identity)
		elif mode == PRESENTATION_ROOM:
			var authored_slot := _dict_view(authored_slots.get(slot_id, {}))
			var minimum_required := true
			if current_records_by_id.has(identity):
				minimum_required = bool(_dict(current_records_by_id.get(identity, {})).get("interactive", true))
			if slot_id.is_empty() or authored_slot.is_empty() or JSON.stringify(binding_slot) != JSON.stringify(authored_slot):
				errors.append("Persisted base room binding %s does not match its exact authored slot." % identity)
			elif _slot_family(authored_slot) != slot_family or not slot_id.begins_with("%s." % slot_family):
				errors.append("Persisted base room binding %s crosses slot families." % identity)
			elif str(authored_slot.get("footprint_class", "")) != placement_class or minimum_required and not _slot_meets_minimum(authored_slot, MIN_INTERACTIVE_TARGET):
				errors.append("Persisted base room binding %s has an incompatible or undersized authored slot." % identity)
			else:
				if not room_ids_by_slot.has(slot_id): room_ids_by_slot[slot_id] = []
				(room_ids_by_slot[slot_id] as Array).append(identity)
				if object_rects.has(identity) and not _same_normalized_rect(object_rects.get(identity), _normalized_rect(_slot_rect(authored_slot))):
					errors.append("Persisted base room binding %s object_rect does not match its exact authored slot." % identity)
		else:
			errors.append("Persisted base slot binding %s has an invalid presentation mode." % identity)
	for object_id_value in object_rects.keys():
		if typeof(object_id_value) != TYPE_STRING:
			errors.append("Persisted base slot authority contains a non-string object_rect id.")
			continue
		var object_id := str(object_id_value)
		var object_binding := _dict(bindings.get(object_id, {}))
		if object_id.is_empty() or object_id != object_id.strip_edges() or str(object_binding.get("presentation_mode", "")) != PRESENTATION_ROOM:
			errors.append("Persisted base object_rect %s has no exact room binding." % object_id)
	var stored_overflow_value: Variant = layout.get("slot_overflow_ids")
	var stored_overflow: Array = []
	var stored_overflow_valid := true
	var seen_overflow: Dictionary = {}
	for identity_value in stored_overflow_value as Array:
		if typeof(identity_value) != TYPE_STRING:
			stored_overflow_valid = false
			continue
		var identity := str(identity_value)
		if identity.is_empty() or identity != identity.strip_edges() or seen_overflow.has(identity):
			stored_overflow_valid = false
			continue
		seen_overflow[identity] = true
		stored_overflow.append(identity)
	overflow_ids.sort()
	var sorted_stored := stored_overflow.duplicate()
	sorted_stored.sort()
	if not stored_overflow_valid or stored_overflow != sorted_stored or stored_overflow != overflow_ids:
		errors.append("Persisted base slot authority overflow ids are not the exact sorted unique overflow binding set.")
	for record_value in current_records:
		var record := _dict(record_value)
		var object_id := str(record.get("object_id", record.get("presentation_object_id", ""))).strip_edges()
		if object_id.is_empty():
			continue
		var record_binding := _dict(bindings.get(object_id, {}))
		var binding_source_id := str(record.get("slot_binding_source_id", "")).strip_edges()
		var exact_host_id := str(exact_action_host_ids.get(object_id, "")).strip_edges()
		var exact_hosted_action := not exact_host_id.is_empty() \
				and exact_host_id == binding_source_id \
				and exact_host_id != object_id
		if exact_hosted_action:
			# The exact scenario layout proves this action's tangible host, including
			# route actors that never enter the base manifest. It must never own an
			# independent base binding. Aliases without exact action-host authority
			# continue through the replacement path and authenticate their transfer.
			if not record_binding.is_empty():
				errors.append("Current exact hosted action %s owns a base slot binding instead of borrowing %s." % [object_id, exact_host_id])
			continue
		if record_binding.is_empty():
			if not allow_unbound_records:
				errors.append("Current base record %s has no authenticated slot binding." % object_id)
			continue
		# Live production records carry their source class inputs. Durable semantic
		# interactions deliberately keep a closed payload, so replay the same stable
		# type/id classification used by EnvironmentInstance for its base domains.
		# This keeps placement_class out of semantic authority without letting a
		# re-digested wrong-class binding authenticate itself.
		var closed_manifest_row: Dictionary = {}
		if not record.has("placement_class") and not record.has("object_type"):
			closed_manifest_row = _dict(manifest_rows.get(object_id, {}))
		var replay_entry := _base_layout_policy_entry(environment, object_id)
		for replay_key in record.keys():
			replay_entry[replay_key] = record.get(replay_key)
		var expected_family := str(closed_manifest_row.get("family", "")) if not closed_manifest_row.is_empty() else authored_entry_slot_family(surface_map, replay_entry, object_id)
		var expected_class := ""
		var class_override := str(_dict(surface_map.get("class_overrides", {})).get(object_id, ""))
		var exact_exit_class := _exact_authored_exit_class(record_binding, object_id)
		if not closed_manifest_row.is_empty():
			# Closed semantic interactions intentionally omit presentation heuristics.
			# Their canonical manifest row was produced while those inputs were still
			# available, and is independent of the persisted binding being checked.
			expected_class = str(closed_manifest_row.get("placement_class", ""))
		elif not exact_exit_class.is_empty():
			# Exact exit slots describe the room-native navigation affordance (door,
			# ground marker, attendant, and so on), so their authored footprint is
			# canonical even after semantic closure removes presentation-only family
			# and placement fields from the interaction record.
			expected_class = exact_exit_class
		elif expected_family == "exit":
			expected_class = str(record_binding.get("placement_class", ""))
		elif class_override in EnvironmentPlacementScript.CLASSES:
			# Generated layout inputs apply the room's exact class override before
			# binding. Raw live records may retain their generic inferred class, so
			# the authored room override has the same first priority during replay.
			expected_class = class_override
		elif record.has("placement_class"):
			expected_class = EnvironmentPlacementScript.classify(
				record,
				str(record.get("object_type", "")),
				object_id,
				str(record.get("visual_prop", record.get("prop", record.get("icon_key", ""))))
			)
		elif record.has("object_type"):
			expected_class = EnvironmentPlacementScript.classify(
				record,
				str(record.get("object_type", "")),
				object_id,
				str(record.get("visual_prop", record.get("prop", record.get("icon_key", ""))))
			)
		else:
			expected_class = _closed_semantic_placement_class(surface_map, record, object_id)
		if closed_manifest_row.is_empty() and exact_exit_class.is_empty() and expected_family != "exit":
			expected_class = _normalize_base_placement_class(environment, record, object_id, class_override, expected_class)
		if not expected_class.is_empty() and str(record_binding.get("placement_class", "")) != expected_class:
			errors.append("Current base record %s placement class does not match production classification (binding=%s expected=%s record=%s type=%s presentation=%s source=%s/%s/%s visual=%s prop=%s icon=%s)." % [
				object_id,
				str(record_binding.get("placement_class", "")),
				expected_class,
				str(record.get("placement_class", "<closed>")),
				str(record.get("object_type", "<closed>")),
				str(record.get("presentation_object_id", "")),
				str(record.get("source_kind", "")),
				str(record.get("source_field", "")),
				str(record.get("source_record_id", "")),
				str(record.get("visual_prop", "")),
				str(record.get("prop", "")),
				str(record.get("icon_key", "")),
			])
		if expected_family.is_empty() and base_record_requires_room_slot(record):
			errors.append("Current physical record %s is missing four-family slot authority." % object_id)
		elif not expected_family.is_empty() and str(record_binding.get("slot_family", "")) != expected_family:
			errors.append("Current record %s slot family does not match its authenticated binding." % object_id)
	for slot_id_value in room_ids_by_slot.keys():
		var identities := _array(room_ids_by_slot.get(slot_id_value, []))
		if identities.size() <= 1:
			continue
		identities.sort()
		errors.append("Persisted base room slot %s is claimed by multiple live identities: %s." % [str(slot_id_value), JSON.stringify(identities)])
	return {
		"ok": errors.is_empty(),
		"slot_bindings": bindings if errors.is_empty() else {},
		"overflow_ids": overflow_ids if errors.is_empty() else [],
		"object_rects": object_rects if errors.is_empty() else {},
		"slot_map_digest": expected_map_digest,
		"binding_digest": stored_digest,
		"errors": errors,
	}


static func _exact_authored_exit_class(binding: Dictionary, object_id: String) -> String:
	if str(binding.get("slot_family", "")) != "exit" \
			or not (object_id.begins_with("travel:") \
			or object_id.begins_with("environment_layer:") \
			or object_id.begins_with("casino_door:")):
		return ""
	var slot_id := str(binding.get("slot_id", "")).strip_edges()
	var slot := _dict(binding.get("slot", {}))
	if slot_id.is_empty() or not slot_id.begins_with("exit.") \
			or str(slot.get("id", "")) != slot_id \
			or str(slot.get("kind", "")) != "exit":
		return ""
	var footprint_class := str(slot.get("footprint_class", "")).strip_edges()
	return footprint_class if footprint_class in EnvironmentPlacementScript.CLASSES else ""


static func _closed_semantic_placement_class(surface_map: Dictionary, record: Dictionary, object_id: String) -> String:
	if not record.has("presentation_object_id"):
		return ""
	var parts := object_id.split(":", false)
	if parts.size() < 2:
		return ""
	var object_type := str(parts[0])
	# These are the catalog-backed base domains emitted by
	# EnvironmentBaseSemanticRecords.authoritative_interactable_records(). Their
	# generated placement input is exactly type + stable presentation id.
	if object_type not in ["game", "event", "service", "lender", "travel"]:
		return ""
	var class_override := str(_dict(surface_map.get("class_overrides", {})).get(object_id, ""))
	if class_override in EnvironmentPlacementScript.CLASSES:
		return class_override
	return EnvironmentPlacementScript.classify({}, object_type, object_id)


# Positive base-room authority is deliberately structural. Games and shop
# items are owner-approved categories; people require explicit person
# provenance; every other object requires an authored asset or an exact
# procedural renderer contract. Semantic nouns never mint physical geometry.
static func base_record_requires_room_slot(record: Dictionary) -> bool:
	# The generated object manifest is the primary physical authority in slot
	# schema v2. Renderer heuristics remain only for non-manifest action records.
	if record.has("physical") and typeof(record.get("physical")) == TYPE_BOOL:
		return bool(record.get("physical", false))
	var object_type := str(record.get("object_type", "")).strip_edges()
	var visual_type := str(record.get("visual_type", "")).strip_edges()
	var object_id := str(record.get("object_id", "")).strip_edges()
	# These choices are deliberately hosted by another tangible object. Keep
	# that rule ahead of carried/generated family metadata so stale layout data
	# can never turn an action into a duplicate physical marker.
	if object_id in BASE_ACTION_ONLY_EVENT_IDS:
		return false
	if not _entry_slot_family(record).is_empty():
		return true
	if object_type in BASE_ALWAYS_PHYSICAL_TYPES:
		return true
	if object_id in BASE_ALWAYS_PHYSICAL_OBJECT_IDS:
		return true
	if bool(record.get("physical_person", false)) \
			or visual_type in BASE_PERSON_VISUAL_TYPES \
			or not _dict(record.get("character_actor", {})).is_empty():
		return true
	var asset_path := str(record.get("asset_path", "")).strip_edges()
	if asset_path.begins_with("res://assets/art/"):
		return true
	# Destination rows and service verbs are abstract unless their record carries
	# concrete art provenance. Concrete props still qualify through asset_path or
	# the closed renderer contracts below.
	var prop := str(record.get("visual_prop", record.get("prop", ""))).strip_edges()
	if (object_type == "home_sleep" or visual_type == "home_sleep") and prop in ["", "bed"]:
		return true
	if (object_type == "service" or visual_type == "service") and prop == "sand_pile":
		return true
	return (object_type == "event" or visual_type == "event") and prop in BASE_EVENT_ART_PROPS


static func _base_layout_policy_entry(environment: Dictionary, object_id: String) -> Dictionary:
	var parts := object_id.split(":", false)
	if parts.is_empty():
		return {}
	var object_type := str(parts[0])
	if object_type == "cage_gift_item":
		object_type = "item"
	elif object_id == "numbers:silas":
		object_type = "numbers_silas"
	var entry := {"object_id": object_id, "object_type": object_type}
	var layout := _dict(environment.get("layout", {}))
	var hints := _dict(_dict(layout.get("object_placement_hints", {})).get(object_id, {}))
	for key_value in hints.keys():
		entry[key_value] = hints.get(key_value)
	var source_id := object_id.trim_prefix("%s:" % str(parts[0]))
	var address := _base_layout_category_address(environment, object_type, source_id)
	for key_value in address.keys():
		entry[key_value] = address.get(key_value)
	return entry


static func _base_layout_category_address(environment: Dictionary, object_type: String, source_id: String) -> Dictionary:
	var collection_key := ""
	var spot_field := ""
	match object_type:
		"game":
			collection_key = "game_ids"
			spot_field = "game_spots"
		"event":
			collection_key = "event_ids"
			spot_field = "event_spots"
		"service":
			collection_key = "service_ids"
			spot_field = "service_spots"
		"lender":
			collection_key = "lender_hooks"
			spot_field = "lender_spots"
		"item":
			collection_key = "item_offers"
			spot_field = "item_spots"
		"shopkeeper":
			return {"spot_field": "shopkeeper_spots", "index": 0}
		"home_tenure":
			return {"spot_field": "home_tenure_spots", "index": 0}
		"home_sleep":
			return {"spot_field": "home_sleep_spots", "index": 0}
		"home_storage":
			return {"spot_field": "home_storage_spots", "index": 0}
		_:
			return {}
	var index := 0
	for value in _array(environment.get(collection_key, [])):
		var candidate_id := str(_dict(value).get("id", "")) if typeof(value) == TYPE_DICTIONARY else str(value)
		if candidate_id == source_id:
			return {"spot_field": spot_field, "index": index}
		index += 1
	return {}


# Applies the same authority to the complete interaction inventory. Some live
# records (deliveries, transient contacts, and meta controls) are assembled
# after EnvironmentInstance generated its serialized layout. Only records that
# pass the same physical gate consume still-free authored base slots; every
# other record is attached to a visible room object by the interaction composer.
static func bind_base_records(environment: Dictionary, records: Array, existing_bindings: Dictionary = {}, shared_occupancy: Dictionary = {}) -> Dictionary:
	var surface_map := EnvironmentPlacementScript.surface_map(environment)
	var exact_action_host_ids := _dict_view(surface_map.get("scenario_instance_action_host_ids", {}))
	var family_slots: Dictionary = {}
	var room_slots: Array = []
	for family_value in SLOT_FAMILIES:
		var family := str(family_value)
		var ordered_family_slots := _family_slots(surface_map, family)
		family_slots[family] = ordered_family_slots
		room_slots.append_array(ordered_family_slots)
	var layout := _dict(environment.get("layout", {}))
	# bind_base_records consumes the complete current interaction refresh. Build
	# its identity set before authenticating persisted geometry so a rectangle for
	# an already-resolved object can be distinguished from a live unbound object.
	var current_record_ids: Dictionary = {}
	var current_records_by_id: Dictionary = {}
	var initial_occupancy := shared_occupancy.duplicate(true)
	var warnings: Array = []
	var schema_errors := _surface_map_errors(surface_map)
	if not schema_errors.is_empty():
		return {"ok": false, "records": records.duplicate(true), "slot_bindings": {}, "overflow_ids": [], "object_rects": {}, "warnings": warnings, "errors": schema_errors}
	var slot_map_digest_value := slot_map_digest(surface_map)
	var validation_context := {
		"surface_map": surface_map,
		"surface_errors": schema_errors,
		"slot_map_digest": slot_map_digest_value,
		"authored_slots": _slots_by_id(room_slots),
	}
	for record_value in records:
		var current_record := _dict(record_value)
		var current_id := str(current_record.get("object_id", "")).strip_edges()
		if not current_id.is_empty():
			current_record_ids[current_id] = true
			current_records_by_id[current_id] = current_record
	var bindings: Dictionary = {}
	var object_rects: Dictionary = {}
	var has_persisted_authority := _has_any_base_layout_authority(layout)
	if has_persisted_authority or not existing_bindings.is_empty():
		# object_rects is live render membership, unlike dormant authored room
		# reservations. A resolved object can therefore leave behind neither an
		# orphan rectangle nor geometry attached to an overflow row. Remove only
		# that provably dormant geometry before applying the unchanged strict
		# authority validator; live or room-bound inconsistencies still fail closed.
		layout = _without_dormant_orphan_object_rects(layout, current_record_ids)
		var authenticated_environment := environment.duplicate(false)
		authenticated_environment["layout"] = layout.duplicate(true)
		var prior_authority := validate_base_layout_authority(authenticated_environment, records, true, validation_context)
		if not bool(prior_authority.get("ok", false)):
			return {"ok": false, "records": records.duplicate(true), "slot_bindings": {}, "overflow_ids": [], "object_rects": {}, "errors": _array(prior_authority.get("errors", []))}
		bindings = _dict(prior_authority.get("slot_bindings", {}))
		object_rects = _dict(prior_authority.get("object_rects", {}))
		if not existing_bindings.is_empty() and JSON.stringify(existing_bindings) != JSON.stringify(bindings):
			return {"ok": false, "records": records.duplicate(true), "slot_bindings": {}, "overflow_ids": [], "object_rects": {}, "errors": ["Caller base bindings do not match the authenticated persisted authority."]}
	# A presentation alias replaces its physical source; it never becomes a second
	# occupant of the source slot. This is used by meta-home containers and Sal's
	# shelf rows, whose click identity differs from the generated room identity.
	var aliases_by_source: Dictionary = {}
	for record_value in records:
		var alias_record := _dict(record_value)
		var alias_id := str(alias_record.get("object_id", "")).strip_edges()
		var source_id := str(alias_record.get("slot_binding_source_id", "")).strip_edges()
		if alias_id.is_empty() or source_id.is_empty() or alias_id == source_id:
			continue
		if str(exact_action_host_ids.get(alias_id, "")).strip_edges() == source_id:
			continue
		if aliases_by_source.has(source_id) and str(aliases_by_source.get(source_id, "")) != alias_id:
			var alias_warning := "base record binding source %s is claimed by multiple live aliases; each physical source may have only one room identity." % source_id
			warnings.append(alias_warning)
			continue
		aliases_by_source[source_id] = alias_id
	var alias_sources := aliases_by_source.keys()
	alias_sources.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	for source_value in alias_sources:
		var source_id := str(source_value)
		var alias_id := str(aliases_by_source.get(source_value, ""))
		if current_record_ids.has(source_id) or bindings.has(alias_id) or not bindings.has(source_id):
			continue
		var alias_binding := _dict(bindings.get(source_id, {}))
		alias_binding["identity"] = alias_id
		bindings.erase(source_id)
		bindings[alias_id] = alias_binding
		if object_rects.has(source_id):
			object_rects[alias_id] = _dict(object_rects.get(source_id, {}))
			object_rects.erase(source_id)
	# This refresh is the complete live inventory. Drop resolved identities so their
	# slots become available, while preserving existing abstract action rows.
	for binding_id_value in bindings.keys():
		var binding_id := str(binding_id_value)
		if not current_record_ids.has(binding_id):
			bindings.erase(binding_id_value)
			object_rects.erase(binding_id)
			continue
		var current_record := _dict(current_records_by_id.get(binding_id, {}))
		if not str(current_record.get("slot_binding_source_id", "")).strip_edges().is_empty():
			continue
		var existing_binding := _dict(bindings.get(binding_id_value, {}))
		var policy_entry := _base_layout_policy_entry(environment, binding_id)
		var policy_family := authored_entry_slot_family(surface_map, policy_entry, binding_id)
		if not policy_family.is_empty():
			# Closed semantic records omit renderer fields and must not authenticate
			# their own copied slot_family. Rebuild physical membership from the
			# authored object/category policy before deciding whether an existing
			# binding is dormant. Otherwise a category-authorized service/lender is
			# dropped here, while its own shared-occupancy claim remains reserved,
			# and the deterministic replay falsely reports that its exact slot is full.
			policy_entry["slot_family"] = policy_family
		var requires_room := base_record_requires_room_slot(current_record) if current_record.has("visual_type") else base_record_requires_room_slot(policy_entry)
		var existing_mode := str(existing_binding.get("presentation_mode", ""))
		if not requires_room:
			bindings.erase(binding_id_value)
			object_rects.erase(binding_id)
		elif requires_room and existing_mode == PRESENTATION_OVERFLOW:
			bindings.erase(binding_id_value)
			object_rects.erase(binding_id)
	var guarded_existing := guard_unique_slot_bindings(bindings, current_record_ids, initial_occupancy, room_slots, "persisted base layout")
	bindings = _dict(guarded_existing.get("slot_bindings", bindings))
	var occupied := _dict(guarded_existing.get("occupied_slots", initial_occupancy))
	warnings.append_array(_array(guarded_existing.get("warnings", [])))
	var errors := _array(guarded_existing.get("errors", []))
	var ordered: Array = []
	for record_value in records:
		var record := _dict(record_value)
		var object_id := str(record.get("object_id", "")).strip_edges()
		if not object_id.is_empty():
			ordered.append(record)
	var ordered_sort_keys: Dictionary = {}
	for record_value in ordered:
		var sortable_record := _dict_view(record_value)
		var sortable_id := str(sortable_record.get("object_id", ""))
		ordered_sort_keys[sortable_id] = {
			"shop_order": _shop_item_order(environment, sortable_id),
			"exact": bool(_slot_preference(surface_map, sortable_record, sortable_id).get("exact", false)),
		}
	ordered.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left := _dict_view(left_value)
		var right := _dict_view(right_value)
		var left_id := str(left.get("object_id", ""))
		var right_id := str(right.get("object_id", ""))
		var left_key := _dict_view(ordered_sort_keys.get(left_id, {}))
		var right_key := _dict_view(ordered_sort_keys.get(right_id, {}))
		var left_shop_order := int(left_key.get("shop_order", -1))
		var right_shop_order := int(right_key.get("shop_order", -1))
		var left_exact := bool(left_key.get("exact", false))
		var right_exact := bool(right_key.get("exact", false))
		if left_exact != right_exact:
			return left_exact
		if left_shop_order >= 0 and right_shop_order >= 0 and left_shop_order != right_shop_order:
			return left_shop_order < right_shop_order
		return left_id < right_id
	)
	for record_value in ordered:
		var record := _dict(record_value)
		var object_id := str(record.get("object_id", "")).strip_edges()
		var binding_source_id := str(record.get("slot_binding_source_id", "")).strip_edges()
		if not binding_source_id.is_empty() \
				and binding_source_id != object_id \
				and str(exact_action_host_ids.get(object_id, "")).strip_edges() == binding_source_id:
			continue
		if bindings.has(object_id):
			continue
		# Late live records cross this binder after EnvironmentInstance generated its
		# initial object inventory. Apply the same authored room/scenario override
		# that generation and authority validation use, so the new binding cannot be
		# minted from a generic record class and then fail its own sealed replay.
		var class_override := str(_dict(surface_map.get("class_overrides", {})).get(object_id, ""))
		var record_class := str(record.get("placement_class", "")).strip_edges()
		var placement_class := class_override if class_override in EnvironmentPlacementScript.CLASSES else record_class if record_class in EnvironmentPlacementScript.CLASSES else EnvironmentPlacementScript.classify(
			record,
			str(record.get("object_type", "")),
			object_id,
			str(record.get("visual_prop", record.get("prop", record.get("icon_key", ""))))
		)
		placement_class = _normalize_base_placement_class(environment, record, object_id, class_override, placement_class)
		if not base_record_requires_room_slot(record):
			var warning := "base record binding received unattached action-only record %s; attach it to a visible room object before binding." % object_id
			warnings.append(warning)
			errors.append(warning)
			continue
		var binding_entry := _base_layout_policy_entry(environment, object_id)
		for binding_key in record.keys():
			binding_entry[binding_key] = record.get(binding_key)
		var slot_family := authored_entry_slot_family(surface_map, binding_entry, object_id)
		if slot_family.is_empty():
			errors.append("base record binding physical object %s is missing a valid four-family slot assignment." % object_id)
			continue
		var preference_data := _slot_preference(surface_map, binding_entry, object_id)
		var preference := str(preference_data.get("slot_id", "")).strip_edges()
		var minimum_size := MIN_INTERACTIVE_TARGET if bool(record.get("interactive", true)) else Vector2.ZERO
		var candidate_slots := _candidate_slots_for_preference(
			surface_map,
			slot_family,
			preference_data,
			_array_view(family_slots.get(slot_family, []))
		)
		placement_class = _exit_preference_class(candidate_slots, slot_family, preference, placement_class)
		var slot := _select_slot(candidate_slots, occupied, placement_class, preference, bool(preference_data.get("exact", false)), minimum_size)
		if slot.is_empty():
			_warn_missing_family_slot("base record binding", object_id, slot_family, placement_class, warnings, errors)
			continue
		var slot_id := str(slot.get("id", ""))
		occupied[slot_id] = object_id
		bindings[object_id] = _room_binding(object_id, placement_class, slot_family, slot)
	var guarded_final := guard_unique_slot_bindings(bindings, current_record_ids, initial_occupancy, room_slots, "base layout finalization")
	bindings = _dict(guarded_final.get("slot_bindings", bindings))
	occupied = _dict(guarded_final.get("occupied_slots", occupied))
	warnings.append_array(_array(guarded_final.get("warnings", [])))
	errors.append_array(_array(guarded_final.get("errors", [])))
	_replace_dictionary(shared_occupancy, occupied)
	var result_records: Array = []
	var overflow_ids: Array = []
	for original_value in records:
		var record := _dict(original_value)
		var object_id := str(record.get("object_id", "")).strip_edges()
		var binding := _dict(bindings.get(object_id, {}))
		if binding.is_empty():
			result_records.append(record)
			continue
		var mode := str(binding.get("presentation_mode", PRESENTATION_OVERFLOW))
		record["presentation_mode"] = mode
		record["slot_id"] = str(binding.get("slot_id", ""))
		record["slot_family"] = str(binding.get("slot_family", ""))
		record["placement_class"] = str(binding.get("placement_class", ""))
		record["fixed_slot_geometry"] = true
		if mode == PRESENTATION_ROOM:
			var normalized := _normalized_rect(_slot_rect(_dict(binding.get("slot", {}))))
			var label_rect := label_rect_from_binding(binding, str(record.get("label", "")))
			record["normalized_rect"] = normalized.duplicate(true)
			record["focus_rect"] = normalized.duplicate(true)
			record["small_screen_rect"] = _normalized_rect(expanded_rect(_slot_rect(_dict(binding.get("slot", {})))))
			record["label_rect"] = _normalized_rect(label_rect)
			record["small_screen_label_rect"] = _normalized_rect(label_rect)
			var rect := _rect_from_dict(normalized)
			record["focus_point"] = {"x": rect.get_center().x, "y": rect.get_center().y}
		else:
			record["normalized_rect"] = {}
			record["focus_rect"] = {}
			record["small_screen_rect"] = {}
			record["label_rect"] = {}
			record["small_screen_label_rect"] = {}
			record["focus_point"] = {}
		result_records.append(record)
	# Preserve only pre-existing abstract action rows; physical objects never reach
	# this set through collision or capacity handling.
	overflow_ids = []
	var binding_ids := bindings.keys()
	binding_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	for object_id_value in binding_ids:
		var object_id := str(object_id_value)
		if str(_dict(bindings.get(object_id_value, {})).get("presentation_mode", "")) == PRESENTATION_OVERFLOW:
			overflow_ids.append(object_id)
			object_rects.erase(object_id)
	for record_value in result_records:
		var record := _dict(record_value)
		var object_id := str(record.get("object_id", "")).strip_edges()
		if object_id.is_empty():
			continue
		if str(record.get("presentation_mode", "")) == PRESENTATION_ROOM:
			var normalized := _dict(record.get("normalized_rect", {}))
			if not normalized.is_empty(): object_rects[object_id] = normalized
		else:
			object_rects.erase(object_id)
	var binding_digest_value := binding_digest(bindings)
	var candidate_layout := layout.duplicate(true)
	candidate_layout["slot_schema_version"] = SLOT_SCHEMA_VERSION
	candidate_layout["slot_map_digest"] = slot_map_digest_value
	candidate_layout["slot_binding_digest"] = binding_digest_value
	candidate_layout["slot_bindings"] = bindings.duplicate(true)
	candidate_layout["slot_overflow_ids"] = overflow_ids.duplicate(true)
	candidate_layout["object_rects"] = object_rects.duplicate(true)
	var candidate_environment := environment.duplicate(false)
	candidate_environment["layout"] = candidate_layout
	if not errors.is_empty():
		return {"ok": false, "records": records.duplicate(true), "slot_bindings": bindings, "overflow_ids": [], "object_rects": object_rects, "warnings": warnings, "errors": errors}
	var candidate_authority := validate_base_layout_authority(candidate_environment, result_records, false, validation_context)
	if not bool(candidate_authority.get("ok", false)):
		return {"ok": false, "records": records.duplicate(true), "slot_bindings": {}, "overflow_ids": [], "object_rects": {}, "errors": _array(candidate_authority.get("errors", []))}
	var candidate_commit_proof := base_layout_commit_proof(candidate_environment)
	return {
		"ok": true,
		"records": result_records,
		"slot_bindings": bindings,
		"overflow_ids": overflow_ids,
		"object_rects": object_rects,
		"slot_schema_version": SLOT_SCHEMA_VERSION,
		"slot_map_digest": slot_map_digest_value,
		"binding_digest": binding_digest_value,
		"authenticated_prior_layout": layout.duplicate(true),
		"validated_candidate_layout": candidate_layout.duplicate(true),
		"validated_candidate_commit_proof": candidate_commit_proof,
		"occupied_slots": occupied,
		"warnings": warnings,
		"errors": [],
	}


# Binds sequence-owned visuals. Catalog scenario objects use their exact
# scenario-instance slots, while explicitly ambient/runtime event objects use
# the venue's shared event bank. Scenario-local safe exits remain scenario
# doorways; only entries explicitly classified as navigation may use exit slots.
# Route actors reserve two scenario-family endpoints.
static func bind_scenario_visuals(environment: Dictionary, visual_entries: Array, shared_occupancy: Dictionary = {}) -> Dictionary:
	var surface_map := EnvironmentPlacementScript.surface_map(environment)
	var scenario_slots := _family_slots(surface_map, "scenario")
	var event_slots := _family_slots(surface_map, "event")
	var exit_slots := _family_slots(surface_map, "exit")
	var all_slots := scenario_slots + event_slots + exit_slots
	var slots_by_id := _slots_by_id(all_slots)
	var preferences := _dict(surface_map.get("scenario_slot_ids", {}))
	var art_keys := _dict(surface_map.get("scenario_art_keys", {}))
	var position_routes := _dict(surface_map.get("scenario_position_route_ids", {}))
	var routes_by_id := _routes_by_id(_array(surface_map.get("actor_routes", [])))
	var initial_occupancy := shared_occupancy.duplicate(true)
	var occupied := initial_occupancy.duplicate(true)
	var bindings: Dictionary = {}
	var overflow_ids: Array = []
	var errors := _surface_map_errors(surface_map)
	var warnings: Array = []
	_validate_scenario_art_policy(surface_map, art_keys, errors)
	var authored_overflow_ids := _scenario_overflow_policy(surface_map, errors)
	if not authored_overflow_ids.is_empty():
		errors.append("Scenario physical spill is no longer supported; add compatible hand-placed scenario slots instead.")
	if not errors.is_empty():
		return {
			"ok": false,
			"slot_schema_version": SLOT_SCHEMA_VERSION,
			"slot_map_digest": slot_map_digest(surface_map),
			"binding_digest": binding_digest({}),
			"slot_bindings": {},
			"overflow_ids": [],
			"occupied_slot_ids": [],
			"errors": errors,
		}
	var entries := visual_entries.duplicate()
	entries.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		return str(_dict_view(left_value).get("identity", "")) < str(_dict_view(right_value).get("identity", ""))
	)
	# True navigation exits and moving actors reserve first.
	entries.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left := _dict_view(left_value)
		var right := _dict_view(right_value)
		var left_semantic := _dict(left.get("semantic", {}))
		var right_semantic := _dict(right.get("semantic", {}))
		var left_stable := str(left.get("identity", "")).trim_prefix("scenario::")
		var right_stable := str(right.get("identity", "")).trim_prefix("scenario::")
		var left_route := str(left_semantic.get("route_id", "")).strip_edges()
		var right_route := str(right_semantic.get("route_id", "")).strip_edges()
		if left_route.is_empty():
			left_route = str(position_routes.get(scenario_position_key(left_stable, left_semantic), "")).strip_edges()
		if right_route.is_empty():
			right_route = str(position_routes.get(scenario_position_key(right_stable, right_semantic), "")).strip_edges()
		var left_rank := 0 if _entry_slot_family(left, "scenario") == "exit" else 1 if not left_route.is_empty() else 2
		var right_rank := 0 if _entry_slot_family(right, "scenario") == "exit" else 1 if not right_route.is_empty() else 2
		return str(left.get("identity", "")) < str(right.get("identity", "")) if left_rank == right_rank else left_rank < right_rank
	)
	for entry_value in entries:
		var entry := _dict(entry_value)
		var identity := str(entry.get("identity", "")).strip_edges()
		var semantic := _dict(entry.get("semantic", {}))
		if identity.is_empty() or bindings.has(identity) or not bool(semantic.get("present", true)):
			continue
		var stable_id := identity.trim_prefix("scenario::")
		var position_key := scenario_position_key(stable_id, semantic)
		var art_key := scenario_visual_art_key(surface_map, entry)
		if not scenario_visual_requires_room_slot(surface_map, entry):
			# The layout resolver attaches abstract actions to a real actor or
			# fixture before this physical binding pass.
			continue
		if not art_key.is_empty():
			semantic["icon_key"] = art_key
		var slot_family := _entry_slot_family(entry, "scenario")
		if slot_family not in ["event", "scenario", "exit"]:
			errors.append("Scenario visual %s declares forbidden slot family %s." % [identity, slot_family])
			continue
		var placement_class := str(entry.get("placement_class", ""))
		if placement_class not in EnvironmentPlacementScript.CLASSES:
			placement_class = EnvironmentPlacementScript.classify(
				semantic,
				"actor" if bool(entry.get("actor", false)) else "scene_object",
				identity,
				str(semantic.get("prop", semantic.get("icon_key", "")))
			)
		var route_id := str(semantic.get("route_id", "")).strip_edges()
		if route_id.is_empty():
			route_id = str(position_routes.get(position_key, "")).strip_edges()
		var route := _dict(routes_by_id.get(route_id, {}))
		var slot: Dictionary = {}
		if not route_id.is_empty():
			if slot_family != "scenario":
				errors.append("Scenario route visual %s cannot reserve non-scenario slots." % identity)
				continue
			if route.is_empty():
				errors.append("Scenario visual %s route %s has no authored route authority." % [identity, route_id])
				continue
			var start_id := str(route.get("start_slot_id", ""))
			var end_id := str(route.get("end_slot_id", ""))
			var start_slot := _dict(slots_by_id.get(start_id, {}))
			var end_slot := _dict(slots_by_id.get(end_id, {}))
			var lane_ids := _array(route.get("lane_ids", []))
			var route_points := authored_route_points(surface_map, start_slot, end_slot, lane_ids)
			var route_geometry_valid := start_id != end_id and not start_slot.is_empty() and not end_slot.is_empty() \
					and str(start_slot.get("footprint_class", "")) == placement_class \
					and str(end_slot.get("footprint_class", "")) == placement_class \
					and _slot_meets_minimum(start_slot, MIN_INTERACTIVE_TARGET) \
					and _slot_meets_minimum(end_slot, MIN_INTERACTIVE_TARGET) \
					and route_points.size() >= 2
			if route_geometry_valid and not occupied.has(start_id) and not occupied.has(end_id):
				slot = start_slot
				occupied[start_id] = identity
				occupied[end_id] = "route_endpoint::%s" % identity
			elif not route_geometry_valid:
				errors.append("Scenario visual %s route %s has invalid, incompatible, or disconnected authored endpoints." % [identity, route_id])
		else:
			var preference_data := _slot_preference(surface_map, entry, identity, position_key, stable_id)
			var preference := str(preference_data.get("slot_id", "")).strip_edges()
			if bool(preference_data.get("exact", false)):
				var exact_slot := _dict(slots_by_id.get(preference, {}))
				var exact_class := str(exact_slot.get("footprint_class", "")).strip_edges()
				if exact_class in EnvironmentPlacementScript.CLASSES:
					placement_class = exact_class
			if bool(surface_map.get("scenario_layout_scoped", false)) and slot_family == "scenario" \
					and not bool(preference_data.get("exact", false)):
				errors.append("Scenario visual %s has no exact slot instance for position key %s in %s." % [identity, position_key, str(surface_map.get("scenario_layout_id", "scenario layout"))])
				continue
			var candidate_slots := exit_slots if slot_family == "exit" else event_slots if slot_family == "event" else scenario_slots
			placement_class = _exit_preference_class(candidate_slots, slot_family, preference, placement_class)
			# Event/scenario preferences are hints, never hard authority. A stale,
			# occupied, or class-incompatible preferred id falls through to the
			# deterministic (priority, id) order.
			slot = _select_slot(candidate_slots, occupied, placement_class, preference, bool(preference_data.get("exact", false)), MIN_INTERACTIVE_TARGET)
		if slot.is_empty():
			_warn_missing_family_slot("scenario binding", identity, slot_family, placement_class, warnings, errors)
			continue
		var slot_id := str(slot.get("id", ""))
		if not occupied.has(slot_id):
			occupied[slot_id] = identity
		var binding := _room_binding(identity, placement_class, slot_family, slot)
		if not art_key.is_empty():
			binding["scenario_art_key"] = art_key
		if not route.is_empty():
			binding["route"] = route.duplicate(true)
			binding["route_id"] = route_id
		bindings[identity] = binding
	var guarded := guard_unique_slot_bindings(bindings, {}, initial_occupancy, all_slots, "scenario layout finalization")
	bindings = _dict(guarded.get("slot_bindings", bindings))
	occupied = _dict(guarded.get("occupied_slots", occupied))
	warnings.append_array(_array(guarded.get("warnings", [])))
	errors.append_array(_array(guarded.get("errors", [])))
	_replace_dictionary(shared_occupancy, occupied)
	return {
		"ok": errors.is_empty(),
		"slot_schema_version": SLOT_SCHEMA_VERSION,
		"slot_map_digest": slot_map_digest(surface_map),
		"binding_digest": binding_digest(bindings),
		"slot_bindings": bindings,
		"overflow_ids": overflow_ids,
		"occupied_slot_ids": occupied.keys(),
		"occupied_slots": occupied,
		"warnings": warnings,
		"errors": errors,
	}


# True means the entry has closed physical authority and may own an authored
# room slot. False means its actions must attach to a visible room object.
# Positive authority never comes from role/label
# inference.
static func scenario_visual_requires_room_slot(surface_map: Dictionary, entry: Dictionary) -> bool:
	var semantic := _dict(entry.get("semantic", {}))
	if _scenario_semantic_is_attached_control(semantic):
		return false
	if bool(entry.get("actor", false)):
		return true
	if bool(entry.get("navigation_exit", false)) or _entry_slot_family(entry) == "exit":
		return true
	if bool(entry.get("safe_exit", false)):
		return true
	# Catalog scene_ops become physical only after the generated exact scenario
	# layout names their stable/position identity. This lets every authored
	# physical scene object be manually placed without allowing labels, nouns, or
	# attached task controls to mint geometry.
	if _scenario_visual_has_exact_slot(surface_map, entry):
		return true
	return not scenario_visual_art_key(surface_map, entry).is_empty()


static func _scenario_semantic_is_attached_control(semantic: Dictionary) -> bool:
	return str(semantic.get("role", "")).strip_edges().to_lower() in ATTACHED_SCENARIO_CONTROL_ROLES


static func _scenario_visual_has_exact_slot(surface_map: Dictionary, entry: Dictionary) -> bool:
	if not bool(surface_map.get("scenario_layout_scoped", false)):
		return false
	var identity := str(entry.get("identity", "")).strip_edges()
	var semantic := _dict(entry.get("semantic", {}))
	var stable_id := str(semantic.get("stable_object_id", identity.trim_prefix("scenario::"))).strip_edges()
	var position_key := scenario_position_key(stable_id, semantic)
	for field in ["scenario_instance_slot_ids", "scenario_instance_object_slot_ids"]:
		var preferences := _dict(surface_map.get(field, {}))
		for key in [position_key, stable_id, identity]:
			if not str(key).is_empty() and preferences.has(key):
				return true
	return false


static func scenario_visual_art_key(surface_map: Dictionary, entry: Dictionary) -> String:
	if bool(entry.get("actor", false)):
		return ""
	if bool(entry.get("navigation_exit", false)) or _entry_slot_family(entry) == "exit":
		return "side_door"
	if bool(entry.get("safe_exit", false)):
		return "side_door"
	var identity := str(entry.get("identity", "")).strip_edges()
	var semantic := _dict(entry.get("semantic", {}))
	var stable_id := str(semantic.get("stable_object_id", identity.trim_prefix("scenario::"))).strip_edges()
	var position_key := scenario_position_key(stable_id, semantic)
	var instance_art_keys := _dict(surface_map.get("scenario_instance_art_keys", {}))
	var instance_art_key := str(instance_art_keys.get(position_key, "")).strip_edges()
	if instance_art_key in CONCRETE_SCENARIO_ART_KEYS:
		return instance_art_key
	var art_keys := _dict(surface_map.get("scenario_art_keys", {}))
	# A stable-id entry in the surface map is explicit, reviewed physical
	# authority. It must win over broad legacy role/id heuristics (for example a
	# tangible observer rail that happens to carry the old `barrier` role).
	var mapped_art_key := str(art_keys.get(stable_id, art_keys.get(identity, ""))).strip_edges()
	if mapped_art_key in CONCRETE_SCENARIO_ART_KEYS:
		return mapped_art_key
	var authored_payload_key := str(semantic.get("icon_key", "")).strip_edges()
	if authored_payload_key in CONCRETE_SCENARIO_ART_KEYS:
		return authored_payload_key
	if _scenario_semantic_is_abstract(stable_id, semantic):
		return ""
	return ""


static func _scenario_semantic_is_abstract(stable_id: String, semantic: Dictionary) -> bool:
	if str(semantic.get("role", "")).strip_edges().to_lower() in ABSTRACT_SCENARIO_ROLES:
		return true
	var normalized_id := stable_id.strip_edges().to_lower()
	for token_value in ABSTRACT_SCENARIO_ID_TOKENS:
		var token := str(token_value)
		if normalized_id == token or normalized_id.begins_with("%s_" % token) \
				or normalized_id.ends_with("_%s" % token) or normalized_id.contains("_%s_" % token):
			return true
	return false


static func slot_map_digest(surface_map: Dictionary) -> String:
	return JSON.stringify({
		"schema_version": int(surface_map.get("slot_schema_version", 0)),
		"map_id": str(surface_map.get("id", "")),
		"fixed_slots": _array_view(surface_map.get("fixed_slots", [])),
		"event_slots": _array_view(surface_map.get("event_slots", [])),
		"scenario_slots": _array_view(surface_map.get("scenario_slots", [])),
		"exit_slots": _array_view(surface_map.get("exit_slots", [])),
		"walk_lanes": _array_view(surface_map.get("walk_lanes", [])),
		"actor_routes": _array_view(surface_map.get("actor_routes", [])),
		"fixed_object_slot_ids": _dict_view(surface_map.get("fixed_object_slot_ids", {})),
		"event_object_slot_ids": _dict_view(surface_map.get("event_object_slot_ids", {})),
		"scenario_object_slot_ids": _dict_view(surface_map.get("scenario_object_slot_ids", {})),
		"exit_object_slot_ids": _dict_view(surface_map.get("exit_object_slot_ids", {})),
		"fixed_category_slot_ids": _dict_view(surface_map.get("fixed_category_slot_ids", {})),
		"event_category_slot_ids": _dict_view(surface_map.get("event_category_slot_ids", {})),
		"scenario_category_slot_ids": _dict_view(surface_map.get("scenario_category_slot_ids", {})),
		"exit_category_slot_ids": _dict_view(surface_map.get("exit_category_slot_ids", {})),
		"object_family_ids": _dict_view(surface_map.get("object_family_ids", {})),
		"fixed_objects": surface_map.get("fixed_objects", []),
		"class_overrides": _dict_view(surface_map.get("class_overrides", {})),
		"scenario_slot_ids": _dict_view(surface_map.get("scenario_slot_ids", {})),
		"scenario_instance_slot_ids": _dict_view(surface_map.get("scenario_instance_slot_ids", {})),
		"scenario_instance_object_slot_ids": _dict_view(surface_map.get("scenario_instance_object_slot_ids", {})),
		"scenario_instance_object_class_ids": _dict_view(surface_map.get("scenario_instance_object_class_ids", {})),
		"scenario_instance_art_keys": _dict_view(surface_map.get("scenario_instance_art_keys", {})),
		"scenario_instance_action_host_ids": _dict_view(surface_map.get("scenario_instance_action_host_ids", {})),
		"scenario_layout_id": str(surface_map.get("scenario_layout_id", "")),
		"scenario_art_keys": _dict_view(surface_map.get("scenario_art_keys", {})),
		"scenario_overflow_ids": _array_view(surface_map.get("scenario_overflow_ids", [])),
		"scenario_position_route_ids": _dict_view(surface_map.get("scenario_position_route_ids", {})),
	}).sha256_text()


static func validate_slot_map(surface_map: Dictionary) -> Dictionary:
	var errors := _surface_map_errors(surface_map)
	return {"ok": errors.is_empty(), "errors": errors, "digest": slot_map_digest(surface_map)}


static func _validate_scenario_art_policy(surface_map: Dictionary, art_keys: Dictionary, errors: Array) -> void:
	var value: Variant = surface_map.get("scenario_art_keys")
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("Scenario art authority must be an object.")
		return
	for stable_id_value in art_keys.keys():
		var stable_id := str(stable_id_value)
		var art_key_value: Variant = art_keys.get(stable_id_value)
		if typeof(stable_id_value) != TYPE_STRING or stable_id.is_empty() \
				or stable_id != stable_id.strip_edges() or stable_id.begins_with("scenario::") or stable_id.contains("|"):
			errors.append("Scenario art authority contains a malformed stable identity.")
			continue
		if typeof(art_key_value) != TYPE_STRING or str(art_key_value) not in CONCRETE_SCENARIO_ART_KEYS:
			errors.append("Scenario art authority %s names an unsupported concrete renderer." % stable_id)


static func _scenario_overflow_policy(surface_map: Dictionary, errors: Array) -> Dictionary:
	var value: Variant = surface_map.get("scenario_overflow_ids")
	if typeof(value) != TYPE_ARRAY:
		errors.append("Scenario overflow authority must be an array.")
		return {}
	# Validate against map-wide authoring authority rather than the visual entries
	# for the current phase. A legal obstacle may be absent (or hidden) in one
	# phase, while an invented stable identity must still fail closed at runtime.
	var authored_visual_ids := _authored_scenario_visual_ids(surface_map)
	var art_keys := _dict(surface_map.get("scenario_art_keys", {}))
	var result: Dictionary = {}
	for stable_id_value in value as Array:
		if typeof(stable_id_value) != TYPE_STRING:
			errors.append("Scenario overflow authority contains a non-string identity.")
			continue
		var stable_id := str(stable_id_value)
		if stable_id.is_empty() or stable_id != stable_id.strip_edges() or stable_id.begins_with("scenario::"):
			errors.append("Scenario overflow authority contains a malformed stable identity.")
			continue
		if result.has(stable_id):
			errors.append("Scenario overflow authority contains duplicate identity %s." % stable_id)
			continue
		if not authored_visual_ids.has(stable_id):
			errors.append("Scenario overflow authority names unknown authored identity %s." % stable_id)
			continue
		if not art_keys.has(stable_id):
			errors.append("Scenario overflow authority %s is not a concrete physical scene object." % stable_id)
			continue
		result[stable_id] = true
	return result


static func _authored_scenario_visual_ids(surface_map: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var preferences_value: Variant = surface_map.get("scenario_slot_ids")
	if typeof(preferences_value) != TYPE_DICTIONARY:
		return result
	for key_value in (preferences_value as Dictionary).keys():
		if typeof(key_value) != TYPE_STRING:
			continue
		var authored_key := str(key_value).strip_edges().trim_prefix("scenario::")
		var stable_id := authored_key.get_slice("|", 0).strip_edges()
		if not stable_id.is_empty():
			result[stable_id] = true
	return result


static func scenario_position_key(stable_id: String, semantic: Dictionary) -> String:
	return "%s|%s|%s|%s" % [
		stable_id,
		str(semantic.get("anchor_id", "")).strip_edges(),
		str(semantic.get("zone_id", "")).strip_edges(),
		str(semantic.get("authored_position_route_id", "")).strip_edges(),
	]


# Final binding guard shared by generation, live refresh, and scenario passes.
# Existing occupancy always wins; among bindings finalized together, sorted
# identity order is deterministic and every later collision is reassigned to a
# free compatible authored slot.
static func guard_unique_slot_bindings(
	bindings_value: Dictionary,
	live_ids: Dictionary = {},
	occupied_slots: Dictionary = {},
	available_slots: Array = [],
	warning_scope: String = "room layout"
) -> Dictionary:
	var bindings := bindings_value.duplicate(true)
	var occupied := occupied_slots.duplicate(true)
	var available_by_id := _slots_by_id(available_slots)
	var overflow_ids: Array = []
	var warnings: Array = []
	var errors: Array = []
	var identities := bindings.keys()
	identities.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	for identity_value in identities:
		var identity := str(identity_value).strip_edges()
		if identity.is_empty() or not live_ids.is_empty() and not live_ids.has(identity):
			continue
		var binding := _dict(bindings.get(identity_value, {}))
		if str(binding.get("presentation_mode", "")) == PRESENTATION_OVERFLOW:
			_warn_missing_slot(warning_scope, identity, str(binding.get("placement_class", "")), warnings, errors)
			bindings.erase(identity_value)
			continue
		if str(binding.get("presentation_mode", "")) != PRESENTATION_ROOM:
			continue
		var slot_family := str(binding.get("slot_family", binding.get("kind", ""))).strip_edges()
		if slot_family not in SLOT_FAMILIES or str(binding.get("kind", "")) != slot_family:
			errors.append("%s binding %s has an invalid or inconsistent slot family." % [warning_scope, identity])
			bindings.erase(identity_value)
			continue
		var claim_ids: Array = []
		var slot_id := str(binding.get("slot_id", "")).strip_edges()
		var bound_slot := _dict(available_by_id.get(slot_id, {}))
		if slot_id.is_empty() or bound_slot.is_empty() or _slot_family(bound_slot) != slot_family \
				or not slot_id.begins_with("%s." % slot_family):
			errors.append("%s binding %s references a missing or cross-family slot %s." % [warning_scope, identity, slot_id])
			bindings.erase(identity_value)
			continue
		claim_ids.append(slot_id)
		var route := _dict(binding.get("route", {}))
		var route_end_id := str(route.get("end_slot_id", "")).strip_edges()
		if not route_end_id.is_empty():
			var route_end_slot := _dict(available_by_id.get(route_end_id, {}))
			if route_end_slot.is_empty() or _slot_family(route_end_slot) != slot_family:
				errors.append("%s routed binding %s crosses slot families." % [warning_scope, identity])
				bindings.erase(identity_value)
				continue
			if not claim_ids.has(route_end_id):
				claim_ids.append(route_end_id)
		var conflict_slot := ""
		var conflict_holder := ""
		for claim_id_value in claim_ids:
			var claim_id := str(claim_id_value)
			var holder := str(occupied.get(claim_id, "")).strip_edges()
			if not holder.is_empty() and holder != identity:
				conflict_slot = claim_id
				conflict_holder = holder
				break
		if not conflict_slot.is_empty():
			if slot_family in ["fixed", "exit"] or not route.is_empty():
				var exact_warning := "%s exact %s slot %s for %s is already held by %s." % [warning_scope, slot_family, conflict_slot, identity, conflict_holder]
				warnings.append(exact_warning)
				errors.append(exact_warning)
				bindings.erase(identity_value)
				continue
			var replacement := _select_slot(_slots_from_family(available_slots, slot_family), occupied, str(binding.get("placement_class", "")), "", false, MIN_INTERACTIVE_TARGET)
			if replacement.is_empty():
				_warn_missing_family_slot(warning_scope, identity, slot_family, str(binding.get("placement_class", "")), warnings, errors)
				bindings.erase(identity_value)
				continue
			var warning := "%s slot %s is already held by %s; reassigned %s to authored slot %s." % [warning_scope, conflict_slot, conflict_holder, identity, str(replacement.get("id", ""))]
			warnings.append(warning)
			binding["kind"] = slot_family
			binding["slot_family"] = slot_family
			binding["slot_id"] = str(replacement.get("id", ""))
			binding["slot"] = replacement.duplicate(true)
			bindings[identity_value] = binding
			claim_ids = [str(replacement.get("id", ""))]
		for claim_id_value in claim_ids:
			occupied[str(claim_id_value)] = identity
	return {
		"slot_bindings": bindings,
		"overflow_ids": overflow_ids,
		"occupied_slots": occupied,
		"warnings": warnings,
		"errors": errors,
	}


static func _warn_missing_slot(scope: String, identity: String, placement_class: String, warnings: Array, errors: Array) -> void:
	var warning := "%s has no free compatible authored %s slot for %s; add a hand-placed slot in placement_surfaces.json." % [scope, placement_class, identity]
	# Binding is a pure, frequently repeated projection (travel previews and
	# parity checks may invoke it hundreds of times). Keep diagnostics in the
	# returned/layout envelope so callers can surface them once without flooding
	# stderr for the same malformed synthetic or authored room.
	warnings.append(warning)
	errors.append(warning)


static func _warn_missing_family_slot(scope: String, identity: String, slot_family: String, placement_class: String, warnings: Array, errors: Array) -> void:
	var warning := "%s has no free compatible authored %s.%s slot for %s; add a hand-placed %s slot in placement_surfaces.json." % [scope, slot_family, placement_class, identity, slot_family]
	warnings.append(warning)
	errors.append(warning)


static func binding_digest(bindings: Dictionary) -> String:
	var canonical: Array = []
	var identities := bindings.keys()
	identities.sort()
	for identity_value in identities:
		canonical.append(_dict(bindings.get(identity_value, {})))
	return JSON.stringify(canonical).sha256_text()


# Compact handoff proof for a layout that has already passed the full authority
# validator. It lets a synchronous caller commit that exact candidate without
# repeating the expensive map/manifest/geometry validation a second time.
static func base_layout_commit_proof(environment: Dictionary) -> String:
	var layout := _dict(environment.get("layout", {}))
	var bindings := _dict(layout.get("slot_bindings", {}))
	var rects := _dict(layout.get("object_rects", {}))
	var rect_rows: Array = []
	var rect_ids := rects.keys()
	rect_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	for rect_id_value in rect_ids:
		var rect_id := str(rect_id_value)
		rect_rows.append([rect_id, _dict(rects.get(rect_id_value, {}))])
	var overflow_ids := _array(layout.get("slot_overflow_ids", [])).duplicate()
	overflow_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	return JSON.stringify({
		"environment_id": str(environment.get("id", environment.get("world_node_id", environment.get("archetype_id", "")))),
		"archetype_id": str(environment.get("archetype_id", "")),
		"layer_id": str(environment.get("current_layer_id", environment.get("layer_id", ""))),
		"manifest_digest": str(environment.get("object_manifest_digest", _dict(environment.get("object_manifest", {})).get("digest", ""))),
		"manifest_revision": int(environment.get("object_manifest_revision", _dict(environment.get("object_manifest", {})).get("revision", 0))),
		"slot_schema_version": int(layout.get("slot_schema_version", 0)),
		"slot_map_digest": str(layout.get("slot_map_digest", "")),
		"slot_binding_digest": str(layout.get("slot_binding_digest", "")),
		"recomputed_binding_digest": binding_digest(bindings),
		"overflow_ids": overflow_ids,
		"object_rects": rect_rows,
	}).sha256_text()


static func _object_rects_from_bindings(bindings: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for identity_value in bindings.keys():
		var binding := _dict(bindings.get(identity_value, {}))
		if str(binding.get("presentation_mode", "")) == PRESENTATION_ROOM:
			result[str(identity_value)] = _normalized_rect(_slot_rect(_dict(binding.get("slot", {}))))
	return result


static func _replace_dictionary(target: Dictionary, source: Dictionary) -> void:
	target.clear()
	for key_value in source.keys():
		target[key_value] = source.get(key_value)


static func rect_from_binding(binding: Dictionary) -> Rect2:
	return _slot_rect(_dict(binding.get("slot", {})))


static func expanded_rect(rect: Rect2) -> Rect2:
	if not rect.has_area():
		return Rect2()
	var size := Vector2(maxf(rect.size.x, SMALL_SCREEN_TARGET.x), maxf(rect.size.y, SMALL_SCREEN_TARGET.y))
	return _clamp_inside_board(Rect2(rect.get_center() - size * 0.5, size))


static func normalized_rect(rect: Rect2) -> Dictionary:
	return _normalized_rect(rect)


# Persisted label geometry follows the bound object rectangle. The room canvas
# refines this against the final natural-size model and resolves live overlap.
static func label_rect_from_binding(binding: Dictionary, label: String) -> Rect2:
	return label_rect_from_slot(_dict(binding.get("slot", {})), label)


static func label_rect_from_slot(slot: Dictionary, label: String) -> Rect2:
	if label.strip_edges().is_empty():
		return Rect2()
	var object_rect := _slot_rect(slot)
	if not object_rect.has_area():
		return Rect2()
	var raw_width := float(label.strip_edges().length()) * 5.8 + 12.0
	var size := Vector2(
		minf(maxf(LABEL_MIN_WIDTH, raw_width), LABEL_MAX_WIDTH),
		LABEL_TWO_LINE_HEIGHT if raw_width > LABEL_MAX_WIDTH else LABEL_HEIGHT
	)
	var position := Vector2(object_rect.get_center().x - size.x * 0.5, object_rect.position.y - size.y - LABEL_GAP)
	if position.y < LABEL_MARGIN:
		position.y = object_rect.end.y + LABEL_GAP
	position.x = clampf(position.x, LABEL_MARGIN, BOARD_SIZE.x - LABEL_MARGIN - size.x)
	position.y = clampf(position.y, LABEL_MARGIN, BOARD_SIZE.y - LABEL_MARGIN - size.y)
	return Rect2(position, size)


# Returns actor-center points along only the portion of the ordered authored
# lane chain between the two slot contacts. Endpoint-to-lane connectors are
# retained (doorways commonly sit above the public lane), but no unrelated lane
# vertex is visited and no free-space search is performed.
static func authored_route_points(surface_map: Dictionary, start_slot: Dictionary, end_slot: Dictionary, lane_ids: Array) -> Array[Vector2]:
	var start_rect := _slot_rect(start_slot)
	var end_rect := _slot_rect(end_slot)
	if not start_rect.has_area() or not end_rect.has_area() or lane_ids.is_empty():
		return []
	var start_contact := _slot_contact(start_slot, start_rect.get_center())
	var end_contact := _slot_contact(end_slot, end_rect.get_center())
	var lane_points := _authored_lane_polyline(surface_map, lane_ids, start_contact)
	if lane_points.size() < 2:
		return []
	var start_projection := _nearest_polyline_projection(lane_points, start_contact)
	var end_projection := _nearest_polyline_projection(lane_points, end_contact)
	if start_projection.is_empty() or end_projection.is_empty():
		return []
	var projected_start: Vector2 = start_projection.get("point", start_contact)
	var projected_end: Vector2 = end_projection.get("point", end_contact)
	var contact_path := _polyline_slice(
		lane_points,
		projected_start,
		float(start_projection.get("distance_along", 0.0)),
		projected_end,
		float(end_projection.get("distance_along", 0.0))
	)
	if contact_path.is_empty():
		return []
	var center_offset := _moving_center_offset(start_slot, end_slot, start_rect, end_rect, start_contact, end_contact)
	var result: Array[Vector2] = []
	_append_unique_point(result, start_rect.get_center())
	for contact_point in contact_path:
		_append_unique_point(result, contact_point + center_offset)
	_append_unique_point(result, end_rect.get_center())
	return result if result.size() >= 2 else []


static func _entry_slot_family(entry: Dictionary, default_family: String = "") -> String:
	for key in ["slot_family", "family"]:
		if not entry.has(key):
			continue
		var family := str(entry.get(key, "")).strip_edges()
		return family if family in SLOT_FAMILIES else ""
	return default_family if default_family in SLOT_FAMILIES else ""


static func authored_entry_slot_family(
	surface_map: Dictionary,
	entry: Dictionary,
	object_id: String,
	default_family: String = "",
	allow_category: bool = true
) -> String:
	# An active catalog layout is the final owner of every object it maps. This
	# must run before a live record's legacy `event` family, otherwise scenario-
	# conditioned chain/recruitment records silently consume shared event slots.
	if bool(surface_map.get("scenario_layout_scoped", false)):
		var instance_objects := _dict(surface_map.get("scenario_instance_object_slot_ids", {}))
		for key_value in [
			object_id,
			str(entry.get("source_id", "")),
			str(entry.get("presentation_object_id", "")),
			str(entry.get("stable_object_id", "")),
		]:
			var instance_key := str(key_value).strip_edges()
			if not instance_key.is_empty() and instance_objects.has(instance_key):
				return "scenario"
	var explicit := _entry_slot_family(entry)
	if not explicit.is_empty():
		return explicit
	var family_value: Variant = _dict(surface_map.get("object_family_ids", {})).get(object_id, "")
	var object_family := str(_dict(family_value).get("family", "")) if typeof(family_value) == TYPE_DICTIONARY else str(family_value)
	if object_family in SLOT_FAMILIES:
		return object_family
	var preference_keys: Array = [object_id]
	var source_id := str(entry.get("source_id", "")).strip_edges()
	if not source_id.is_empty() and not preference_keys.has(source_id):
		preference_keys.append(source_id)
	var object_candidates: Dictionary = {}
	for family in SLOT_FAMILIES:
		var object_preferences := _dict(surface_map.get("%s_object_slot_ids" % family, {}))
		for preference_key_value in preference_keys:
			if object_preferences.has(str(preference_key_value)):
				object_candidates[family] = true
	if object_candidates.size() == 1:
		return str(object_candidates.keys()[0])
	if object_candidates.size() > 1:
		return ""
	# Category mappings describe capacity for a record that is already known to
	# be physical. They do not make every member of a gameplay list into a new
	# room object (for example, several service verbs may share one bartender).
	if not allow_category:
		return default_family if default_family in SLOT_FAMILIES else ""
	var category_keys: Array = []
	var explicit_category := str(entry.get("slot_category_key", "")).strip_edges()
	if not explicit_category.is_empty():
		category_keys.append(explicit_category)
	var spot_field := str(entry.get("spot_field", entry.get("layout_spot_field", ""))).strip_edges()
	if not spot_field.is_empty():
		category_keys.append("%s:%d" % [spot_field, int(entry.get("index", entry.get("layout_index", 0)))])
	var category_candidates: Dictionary = {}
	for family in SLOT_FAMILIES:
		var category_preferences := _dict(surface_map.get("%s_category_slot_ids" % family, {}))
		for category_key_value in category_keys:
			if category_preferences.has(str(category_key_value)):
				category_candidates[family] = true
	if category_candidates.size() == 1:
		return str(category_candidates.keys()[0])
	return default_family if category_candidates.is_empty() and default_family in SLOT_FAMILIES else ""


static func _family_slots(surface_map: Dictionary, family: String) -> Array:
	var collection := "%s_slots" % family
	return _ordered_slots(_array_view(surface_map.get(collection, []))) if family in SLOT_FAMILIES else []


static func _candidate_slots_for_preference(
	surface_map: Dictionary,
	family: String,
	preference_data: Dictionary,
	ordered_slots: Array = []
) -> Array:
	var slots := ordered_slots if not ordered_slots.is_empty() else _family_slots(surface_map, family)
	if family != "scenario" or not bool(surface_map.get("scenario_layout_scoped", false)) \
			or bool(preference_data.get("exact", false)):
		return slots
	var reserves: Array = []
	for slot_value in slots:
		var slot := _dict_view(slot_value)
		if bool(slot.get("runtime_reserve", false)):
			reserves.append(slot)
	return reserves


static func _all_family_slots(surface_map: Dictionary) -> Array:
	var result: Array = []
	for family in SLOT_FAMILIES:
		result.append_array(_family_slots(surface_map, str(family)))
	return result


static func _slots_from_family(slots: Array, family: String) -> Array:
	var result: Array = []
	for slot_value in slots:
		var slot := _dict_view(slot_value)
		if _slot_family(slot) == family:
			result.append(slot)
	return _ordered_slots(result)


static func _slot_family(slot: Dictionary) -> String:
	var family := str(slot.get("kind", "")).strip_edges()
	var slot_id := str(slot.get("id", "")).strip_edges()
	if family not in SLOT_FAMILIES or not slot_id.begins_with("%s." % family):
		return ""
	return family


static func _slot_preference(
	surface_map: Dictionary,
	entry: Dictionary,
	object_id: String,
	position_key: String = "",
	stable_id: String = ""
) -> Dictionary:
	var family := authored_entry_slot_family(surface_map, entry, object_id)
	if family.is_empty() and object_id.begins_with("scenario::"):
		family = "scenario"
	if family == "scenario" and bool(surface_map.get("scenario_layout_scoped", false)):
		var instance_preferences := _dict_view(surface_map.get("scenario_instance_slot_ids", {}))
		for semantic_key in [position_key, stable_id, object_id]:
			var clean_instance_key := str(semantic_key).strip_edges()
			if not clean_instance_key.is_empty() and instance_preferences.has(clean_instance_key):
				return {"slot_id": str(instance_preferences.get(clean_instance_key, "")).strip_edges(), "exact": true, "source": "scenario_instance_slot_ids"}
		var instance_object_preferences := _dict_view(surface_map.get("scenario_instance_object_slot_ids", {}))
		for object_key in [position_key, stable_id, object_id]:
			var clean_object_key := str(object_key).strip_edges()
			if not clean_object_key.is_empty() and instance_object_preferences.has(clean_object_key):
				return {"slot_id": str(instance_object_preferences.get(clean_object_key, "")).strip_edges(), "exact": true, "source": "scenario_instance_object_slot_ids"}
	var explicit := str(entry.get("exact_slot_id", "")).strip_edges()
	if not explicit.is_empty():
		return {"slot_id": explicit, "exact": family in ["fixed", "exit"] or family == "scenario" and bool(surface_map.get("scenario_layout_scoped", false)), "source": "entry.exact_slot_id"}
	var carried := str(entry.get("slot_id", "")).strip_edges()
	if not carried.is_empty():
		return {"slot_id": carried, "exact": family in ["fixed", "exit"], "source": "entry.slot_id"}
	var object_preferences: Dictionary
	if family == "scenario":
		object_preferences = _dict_view(surface_map.get("scenario_object_slot_ids", {}))
		var semantic_preferences := _dict_view(surface_map.get("scenario_slot_ids", {}))
		for semantic_key in [position_key, stable_id, object_id]:
			var clean_semantic_key := str(semantic_key).strip_edges()
			if not clean_semantic_key.is_empty() and semantic_preferences.has(clean_semantic_key):
				return {"slot_id": str(semantic_preferences.get(clean_semantic_key, "")).strip_edges(), "exact": false, "source": "scenario_slot_ids"}
	else:
		object_preferences = _dict_view(surface_map.get("%s_object_slot_ids" % family, {}))
	for preference_key in [position_key, stable_id, object_id]:
		var clean_key := str(preference_key).strip_edges()
		if clean_key.is_empty() or not object_preferences.has(clean_key):
			continue
		return {
			"slot_id": str(object_preferences.get(clean_key, "")).strip_edges(),
			"exact": family in ["fixed", "exit"],
			"source": "%s_object_slot_ids" % family,
		}
	var category_preferences := _dict_view(surface_map.get("%s_category_slot_ids" % family, {}))
	var category_keys: Array = []
	var explicit_category := str(entry.get("slot_category_key", "")).strip_edges()
	if not explicit_category.is_empty():
		category_keys.append(explicit_category)
	var spot_field := str(entry.get("spot_field", entry.get("layout_spot_field", ""))).strip_edges()
	var spot_index := int(entry.get("index", entry.get("layout_index", 0)))
	if not spot_field.is_empty():
		category_keys.append("%s:%d" % [spot_field, spot_index])
	for category_key_value in category_keys:
		var category_key := str(category_key_value)
		if category_preferences.has(category_key):
			return {"slot_id": str(category_preferences.get(category_key, "")).strip_edges(), "exact": false, "source": "%s_category_slot_ids" % family}
	return {"slot_id": "", "exact": false, "source": "deterministic_family_order"}


static func _surface_map_errors(surface_map: Dictionary) -> Array:
	var errors: Array = []
	var map_id := str(surface_map.get("id", "<unknown>"))
	if int(surface_map.get("slot_schema_version", 0)) != SLOT_SCHEMA_VERSION:
		errors.append("Environment placement map %s must use slot schema version %d." % [map_id, SLOT_SCHEMA_VERSION])
	for legacy_field in ["base_slots", "stage_slots", "object_slot_ids", "category_slot_ids"]:
		if surface_map.has(legacy_field):
			errors.append("Environment placement map %s still contains legacy slot field %s." % [map_id, legacy_field])
	var seen: Dictionary = {}
	var authored_slots: Dictionary = {}
	for family_value in SLOT_FAMILIES:
		var family := str(family_value)
		var collection := "%s_slots" % family
		if typeof(surface_map.get(collection)) != TYPE_ARRAY:
			errors.append("Environment placement map %s must declare %s as an array." % [map_id, collection])
			continue
		for slot_value in _array_view(surface_map.get(collection, [])):
			var slot := _dict_view(slot_value)
			var slot_id := str(slot.get("id", "")).strip_edges()
			if slot_id.is_empty() or not slot_id.begins_with("%s." % family) or str(slot.get("kind", "")) != family:
				errors.append("Environment placement map %s contains a malformed %s slot id/kind." % [map_id, family])
				continue
			if seen.has(slot_id):
				errors.append("Environment placement map %s contains duplicate slot id %s." % [map_id, slot_id])
			seen[slot_id] = true
			authored_slots[slot_id] = slot
			if str(slot.get("footprint_class", "")) not in EnvironmentPlacementScript.CLASSES:
				errors.append("Environment placement slot %s has an invalid footprint class." % slot_id)
			if typeof(slot.get("occupancy_required")) != TYPE_BOOL:
				errors.append("Environment placement slot %s must declare boolean occupancy_required." % slot_id)
		for mapping_field in ["%s_object_slot_ids" % family, "%s_category_slot_ids" % family]:
			var mapping_value: Variant = surface_map.get(mapping_field, {})
			if typeof(mapping_value) != TYPE_DICTIONARY:
				errors.append("Environment placement map %s field %s must be an object." % [map_id, mapping_field])
				continue
			for mapped_slot_value in (mapping_value as Dictionary).values():
				if typeof(mapped_slot_value) != TYPE_STRING or not str(mapped_slot_value).begins_with("%s." % family) or not seen.has(str(mapped_slot_value)):
					errors.append("Environment placement map %s field %s references a missing or cross-family slot." % [map_id, mapping_field])
	var scenario_preferences_value: Variant = surface_map.get("scenario_slot_ids", {})
	if typeof(scenario_preferences_value) != TYPE_DICTIONARY:
		errors.append("Environment placement map %s scenario_slot_ids must be an object." % map_id)
	else:
		for mapped_slot_value in (scenario_preferences_value as Dictionary).values():
			if typeof(mapped_slot_value) != TYPE_STRING or not str(mapped_slot_value).begins_with("scenario.") or not seen.has(str(mapped_slot_value)):
				errors.append("Environment placement map %s scenario_slot_ids references a missing or non-scenario slot." % map_id)
	for instance_field in ["scenario_instance_slot_ids", "scenario_instance_object_slot_ids"]:
		var instance_value: Variant = surface_map.get(instance_field, {})
		if typeof(instance_value) != TYPE_DICTIONARY:
			errors.append("Environment placement map %s %s must be an object." % [map_id, instance_field])
			continue
		for mapped_slot_value in (instance_value as Dictionary).values():
			if typeof(mapped_slot_value) != TYPE_STRING or not str(mapped_slot_value).begins_with("scenario.") or not seen.has(str(mapped_slot_value)):
				errors.append("Environment placement map %s %s references a missing or non-scenario slot." % [map_id, instance_field])
	var instance_object_positions := _dict_view(surface_map.get("scenario_instance_object_slot_ids", {}))
	var instance_object_classes_value: Variant = surface_map.get("scenario_instance_object_class_ids", {})
	if typeof(instance_object_classes_value) != TYPE_DICTIONARY:
		errors.append("Environment placement map %s scenario_instance_object_class_ids must be an object." % map_id)
	else:
		var instance_object_classes := instance_object_classes_value as Dictionary
		var complete_object_classes := instance_object_classes.size() == instance_object_positions.size()
		for object_id_value in instance_object_positions.keys():
			if not instance_object_classes.has(object_id_value):
				complete_object_classes = false
				break
		if not complete_object_classes:
			errors.append("Environment placement map %s exact scenario object class authority is incomplete." % map_id)
		for object_id_value in instance_object_classes.keys():
			var object_id := str(object_id_value).strip_edges()
			var placement_class_value: Variant = instance_object_classes.get(object_id_value)
			var placement_class := str(placement_class_value).strip_edges()
			var slot_id := str(instance_object_positions.get(object_id, "")).strip_edges()
			var target_slot := _dict_view(authored_slots.get(slot_id, {}))
			if typeof(object_id_value) != TYPE_STRING or object_id.is_empty() \
					or typeof(placement_class_value) != TYPE_STRING or placement_class not in EnvironmentPlacementScript.CLASSES:
				errors.append("Environment placement map %s contains malformed exact scenario object class authority." % map_id)
			elif str(target_slot.get("footprint_class", "")) != placement_class:
				errors.append("Environment placement object %s exact class does not match its scenario slot." % object_id)
			elif str(_dict_view(surface_map.get("class_overrides", {})).get(object_id, "")) != placement_class:
				errors.append("Environment placement object %s exact class was not sealed into runtime overrides." % object_id)
	var instance_art_value: Variant = surface_map.get("scenario_instance_art_keys", {})
	if typeof(instance_art_value) != TYPE_DICTIONARY:
		errors.append("Environment placement map %s scenario_instance_art_keys must be an object." % map_id)
	else:
		var instance_positions := _dict_view(surface_map.get("scenario_instance_slot_ids", {}))
		for position_key_value in (instance_art_value as Dictionary).keys():
			var position_key := str(position_key_value).strip_edges()
			var art_key_value: Variant = (instance_art_value as Dictionary).get(position_key_value)
			if typeof(position_key_value) != TYPE_STRING or position_key.is_empty() or not instance_positions.has(position_key):
				errors.append("Environment placement map %s has exact art without an exact scenario position." % map_id)
			elif typeof(art_key_value) != TYPE_STRING or str(art_key_value) not in CONCRETE_SCENARIO_ART_KEYS:
				errors.append("Environment placement map %s exact art position %s names an unsupported concrete renderer." % [map_id, position_key])
	var action_hosts_value: Variant = surface_map.get("scenario_instance_action_host_ids", {})
	if typeof(action_hosts_value) != TYPE_DICTIONARY:
		errors.append("Environment placement map %s scenario_instance_action_host_ids must be an object." % map_id)
	else:
		var exact_object_positions := _dict_view(surface_map.get("scenario_instance_object_slot_ids", {}))
		var exact_host_ids: Dictionary = {}
		for authored_slot_value in authored_slots.values():
			var authored_slot := _dict_view(authored_slot_value)
			for identity_field in ["occupant_ids", "scenario_object_ids"]:
				for host_identity_value in _array_view(authored_slot.get(identity_field, [])):
					var host_identity := str(host_identity_value).strip_edges()
					if not host_identity.is_empty():
						exact_host_ids[host_identity] = true
		for action_id_value in (action_hosts_value as Dictionary).keys():
			var action_id := str(action_id_value).strip_edges()
			var host_id_value: Variant = (action_hosts_value as Dictionary).get(action_id_value)
			var host_id := str(host_id_value).strip_edges()
			if typeof(action_id_value) != TYPE_STRING or action_id.is_empty() or typeof(host_id_value) != TYPE_STRING or host_id.is_empty() or action_id == host_id:
				errors.append("Environment placement map %s contains malformed exact action-host authority." % map_id)
			elif exact_object_positions.has(action_id):
				errors.append("Environment placement action %s cannot own a slot and alias a host." % action_id)
			elif not exact_host_ids.has(host_id):
				errors.append("Environment placement action %s names host %s without placement authority." % [action_id, host_id])
	# An identity may have one lifecycle owner.  A family override takes
	# precedence during binding, so stale exact mappings in another family would
	# otherwise be silently ignored and hide authoring drift until capacity fails.
	var object_mapping_families: Dictionary = {}
	for mapping_family_value in SLOT_FAMILIES:
		var mapping_family := str(mapping_family_value)
		for object_id_value in _dict_view(surface_map.get("%s_object_slot_ids" % mapping_family, {})).keys():
			var object_id := str(object_id_value).strip_edges()
			if typeof(object_id_value) != TYPE_STRING or object_id.is_empty():
				errors.append("Environment placement map %s contains a malformed object-slot identity." % map_id)
				continue
			if object_mapping_families.has(object_id) and str(object_mapping_families.get(object_id, "")) != mapping_family:
				errors.append("Environment placement object %s claims exact slots in multiple families." % object_id)
			else:
				object_mapping_families[object_id] = mapping_family
	var family_overrides_value: Variant = surface_map.get("object_family_ids")
	if typeof(family_overrides_value) != TYPE_DICTIONARY:
		errors.append("Environment placement map %s object_family_ids must be an object." % map_id)
	else:
		for object_id_value in (family_overrides_value as Dictionary).keys():
			var override_value: Variant = (family_overrides_value as Dictionary).get(object_id_value)
			var family := str(_dict_view(override_value).get("family", "")) if typeof(override_value) == TYPE_DICTIONARY else str(override_value)
			if typeof(object_id_value) != TYPE_STRING or str(object_id_value).strip_edges().is_empty() or family not in SLOT_FAMILIES:
				errors.append("Environment placement map %s object_family_ids contains a malformed assignment." % map_id)
			elif object_mapping_families.has(str(object_id_value)) and str(object_mapping_families.get(str(object_id_value), "")) != family:
				errors.append("Environment placement object %s declares %s-family ownership but maps an exact %s-family slot." % [str(object_id_value), family, str(object_mapping_families.get(str(object_id_value), ""))])
	var fixed_objects_value: Variant = surface_map.get("fixed_objects")
	if typeof(fixed_objects_value) != TYPE_ARRAY:
		errors.append("Environment placement map %s fixed_objects must be an array." % map_id)
	else:
		var fixed_instance_ids: Dictionary = {}
		var fixed_presentation_ids: Dictionary = {}
		var fixed_action_owners: Dictionary = {}
		var required_fixed_slots: Dictionary = {}
		for declaration_value in fixed_objects_value as Array:
			var declaration := _dict_view(declaration_value)
			var instance_id := str(declaration.get("instance_object_id", declaration.get("object_id", declaration.get("id", "")))).strip_edges()
			var presentation_id := str(declaration.get("presentation_object_id", declaration.get("presentation_id", instance_id))).strip_edges()
			var exact_slot_id := str(declaration.get("exact_slot_id", declaration.get("slot_id", ""))).strip_edges()
			var placement_class := str(declaration.get("placement_class", "")).strip_edges()
			var exact_slot := _dict_view(authored_slots.get(exact_slot_id, {}))
			if declaration.is_empty() or instance_id.is_empty() or presentation_id.is_empty() \
					or fixed_instance_ids.has(instance_id) or fixed_presentation_ids.has(presentation_id):
				errors.append("Environment placement map %s fixed_objects contains a malformed or duplicate identity." % map_id)
				continue
			fixed_instance_ids[instance_id] = true
			fixed_presentation_ids[presentation_id] = true
			if exact_slot_id.is_empty() or _slot_family(exact_slot) != "fixed":
				errors.append("Environment placement fixed object %s must name an exact fixed-family slot." % instance_id)
			elif placement_class not in EnvironmentPlacementScript.CLASSES or str(exact_slot.get("footprint_class", "")) != placement_class:
				errors.append("Environment placement fixed object %s has an incompatible placement class." % instance_id)
			if typeof(declaration.get("required")) != TYPE_BOOL:
				errors.append("Environment placement fixed object %s must declare boolean required." % instance_id)
			elif bool(declaration.get("required", false)) and not exact_slot_id.is_empty():
				required_fixed_slots[exact_slot_id] = true
			var action_ids_value: Variant = declaration.get("action_ids", [])
			if typeof(action_ids_value) != TYPE_ARRAY:
				errors.append("Environment placement fixed object %s action_ids must be an array." % instance_id)
			else:
				for action_id_value in action_ids_value as Array:
					var action_id := str(action_id_value).strip_edges()
					if typeof(action_id_value) != TYPE_STRING or action_id.is_empty():
						errors.append("Environment placement fixed object %s contains a malformed action id." % instance_id)
						continue
					if fixed_action_owners.has(action_id) and str(fixed_action_owners.get(action_id, "")) != instance_id:
						errors.append("Environment placement action %s is attached to multiple fixed hosts." % action_id)
					else:
						fixed_action_owners[action_id] = instance_id
		for action_id_value in fixed_action_owners.keys():
			var action_id := str(action_id_value)
			var override_value: Variant = _dict_view(surface_map.get("object_family_ids", {})).get(action_id, "")
			var override_family := str(_dict_view(override_value).get("family", "")) if typeof(override_value) == TYPE_DICTIONARY else str(override_value)
			if not override_family.is_empty() and override_family != "fixed":
				errors.append("Environment placement action %s is attached to a fixed host but declares %s-family ownership." % [action_id, override_family])
			for family in SLOT_FAMILIES:
				if family != "fixed" and _dict_view(surface_map.get("%s_object_slot_ids" % family, {})).has(action_id):
					errors.append("Environment placement action %s is attached to a fixed host but claims an independent %s-family slot." % [action_id, family])
		for slot_id_value in authored_slots.keys():
			var slot_id := str(slot_id_value)
			var slot := _dict_view(authored_slots.get(slot_id, {}))
			if typeof(slot.get("occupancy_required")) == TYPE_BOOL \
					and bool(slot.get("occupancy_required", false)) != required_fixed_slots.has(slot_id):
				errors.append("Environment placement slot %s occupancy_required does not match required fixed-object ownership." % slot_id)
	var class_overrides_value: Variant = surface_map.get("class_overrides")
	if typeof(class_overrides_value) != TYPE_DICTIONARY:
		errors.append("Environment placement map %s class_overrides must be an object." % map_id)
	else:
		for object_id_value in (class_overrides_value as Dictionary).keys():
			if typeof(object_id_value) != TYPE_STRING or str(object_id_value).strip_edges().is_empty() \
					or str((class_overrides_value as Dictionary).get(object_id_value, "")) not in EnvironmentPlacementScript.CLASSES:
				errors.append("Environment placement map %s class_overrides contains a malformed assignment." % map_id)
	var lane_ids: Dictionary = {}
	var lanes_value: Variant = surface_map.get("walk_lanes")
	if typeof(lanes_value) != TYPE_ARRAY:
		errors.append("Environment placement map %s walk_lanes must be an array." % map_id)
	else:
		for lane_value in lanes_value as Array:
			var lane := _dict_view(lane_value)
			var lane_id := str(lane.get("id", "")).strip_edges()
			if lane_id.is_empty() or lane_ids.has(lane_id) or typeof(lane.get("points")) != TYPE_ARRAY or _array_view(lane.get("points", [])).size() < 2:
				errors.append("Environment placement map %s contains a malformed or duplicate walk lane." % map_id)
				continue
			lane_ids[lane_id] = true
	var routes_by_id: Dictionary = {}
	var routes_value: Variant = surface_map.get("actor_routes")
	if typeof(routes_value) != TYPE_ARRAY:
		errors.append("Environment placement map %s actor_routes must be an array." % map_id)
	else:
		for route_value in routes_value as Array:
			var route := _dict_view(route_value)
			var route_id := str(route.get("id", "")).strip_edges()
			if route_id.is_empty() or routes_by_id.has(route_id):
				errors.append("Environment placement map %s contains a malformed or duplicate actor route." % map_id)
				continue
			routes_by_id[route_id] = route
			var start_id := str(route.get("start_slot_id", "")).strip_edges()
			var end_id := str(route.get("end_slot_id", "")).strip_edges()
			var start_slot := _dict_view(authored_slots.get(start_id, {}))
			var end_slot := _dict_view(authored_slots.get(end_id, {}))
			var footprint_class := str(route.get("footprint_class", "")).strip_edges()
			if start_id == end_id or _slot_family(start_slot) != "scenario" or _slot_family(end_slot) != "scenario":
				errors.append("Environment placement actor route %s must use two distinct scenario-family endpoints." % route_id)
			elif footprint_class not in EnvironmentPlacementScript.CLASSES \
					or str(start_slot.get("footprint_class", "")) != footprint_class \
					or str(end_slot.get("footprint_class", "")) != footprint_class:
				errors.append("Environment placement actor route %s has incompatible endpoint footprints." % route_id)
			var route_lane_ids_value: Variant = route.get("lane_ids")
			if typeof(route_lane_ids_value) != TYPE_ARRAY or (route_lane_ids_value as Array).is_empty():
				errors.append("Environment placement actor route %s must declare at least one walk lane." % route_id)
			else:
				for lane_id_value in route_lane_ids_value as Array:
					if typeof(lane_id_value) != TYPE_STRING or not lane_ids.has(str(lane_id_value)):
						errors.append("Environment placement actor route %s references a missing walk lane." % route_id)
			var reduced_motion_id := str(route.get("reduced_motion_slot_id", "")).strip_edges()
			if not reduced_motion_id.is_empty() and _slot_family(_dict_view(authored_slots.get(reduced_motion_id, {}))) != "scenario":
				errors.append("Environment placement actor route %s has a missing or non-scenario reduced-motion slot." % route_id)
	var position_routes_value: Variant = surface_map.get("scenario_position_route_ids")
	if typeof(position_routes_value) != TYPE_DICTIONARY:
		errors.append("Environment placement map %s scenario_position_route_ids must be an object." % map_id)
	else:
		for route_id_value in (position_routes_value as Dictionary).values():
			if typeof(route_id_value) != TYPE_STRING or not routes_by_id.has(str(route_id_value)):
				errors.append("Environment placement map %s scenario_position_route_ids references a missing actor route." % map_id)
	return errors


static func _exit_preference_class(slots: Array, family: String, preferred_slot_id: String, fallback: String) -> String:
	if family != "exit" or preferred_slot_id.is_empty():
		return fallback
	for slot_value in slots:
		var slot := _dict(slot_value)
		if str(slot.get("id", "")) != preferred_slot_id:
			continue
		var authored_class := str(slot.get("footprint_class", "")).strip_edges()
		return authored_class if authored_class in EnvironmentPlacementScript.CLASSES else fallback
	return fallback


static func _select_slot(slots: Array, occupied: Dictionary, placement_class: String, preferred_slot_id: String, require_preferred: bool = false, minimum_size: Vector2 = Vector2.ZERO) -> Dictionary:
	if not preferred_slot_id.is_empty():
		for slot_value in slots:
			var preferred := _dict(slot_value)
			if str(preferred.get("id", "")) == preferred_slot_id \
					and str(preferred.get("footprint_class", "")) == placement_class \
					and not occupied.has(preferred_slot_id) \
					and _slot_meets_minimum(preferred, minimum_size):
				return preferred
		if require_preferred:
			return {}
	for slot_value in slots:
		var slot := _dict(slot_value)
		var slot_id := str(slot.get("id", ""))
		if str(slot.get("footprint_class", "")) == placement_class \
				and not occupied.has(slot_id) \
				and _slot_meets_minimum(slot, minimum_size):
			return slot
	return {}


# Returns the player-visible stock order for merchandise. The binder uses this
# order with the priority-sorted shop slots, producing a gap-free row regardless
# of item ids or the order in which other physical object families are emitted.
static func _shop_item_order(environment: Dictionary, object_id: String) -> int:
	if str(environment.get("kind", "")) == "home":
		return -1
	if object_id.begins_with("cage_gift_item:"):
		return int(object_id.get_slice(":", 1))
	if not object_id.begins_with("item:"):
		return -1
	var item_id := object_id.trim_prefix("item:")
	var offers := _array_view(environment.get("item_offers", []))
	for index in range(offers.size()):
		if str(_dict_view(offers[index]).get("id", "")) == item_id:
			return index
	return -1


# Inventory items placed in a home are physical belongings, not merchandise.
# Only records in an environment's offer list (or with an explicit authored
# shop override) may consume the dedicated shop row. Creation, late binding,
# and persisted-authority replay must all apply this exact normalization.
static func _normalize_base_placement_class(environment: Dictionary, entry: Dictionary, object_id: String, class_override: String, placement_class: String) -> String:
	var shop_identity := str(entry.get("slot_binding_source_id", object_id)).strip_edges()
	if shop_identity.is_empty():
		shop_identity = object_id
	if placement_class == "shop_item" and class_override != "shop_item" and _shop_item_order(environment, shop_identity) < 0:
		return "surface_item"
	return placement_class


static func _slot_meets_minimum(slot: Dictionary, minimum_size: Vector2) -> bool:
	if minimum_size == Vector2.ZERO:
		return true
	var rect := _slot_rect(slot)
	return rect.has_area() and rect.size.x >= minimum_size.x and rect.size.y >= minimum_size.y


static func _ordered_slots(values: Array) -> Array:
	var result := values.duplicate()
	result.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left := _dict_view(left_value)
		var right := _dict_view(right_value)
		var left_priority := int(left.get("priority", 0))
		var right_priority := int(right.get("priority", 0))
		return str(left.get("id", "")) < str(right.get("id", "")) if left_priority == right_priority else left_priority < right_priority
	)
	return result


static func _slots_by_id(slots: Array) -> Dictionary:
	var result: Dictionary = {}
	for slot_value in slots:
		var slot := _dict_view(slot_value)
		var slot_id := str(slot.get("id", ""))
		if not slot_id.is_empty():
			result[slot_id] = slot
	return result


static func _routes_by_id(routes: Array) -> Dictionary:
	var result: Dictionary = {}
	for route_value in routes:
		var route := _dict_view(route_value)
		var route_id := str(route.get("id", ""))
		if not route_id.is_empty():
			result[route_id] = route
	return result


static func _room_binding(identity: String, placement_class: String, slot_family: String, slot: Dictionary) -> Dictionary:
	return {
		"identity": identity,
		"kind": slot_family,
		"slot_family": slot_family,
		"presentation_mode": PRESENTATION_ROOM,
		"slot_id": str(slot.get("id", "")),
		"placement_class": placement_class,
		"slot": slot.duplicate(true),
	}


static func _validated_manifest_rows_by_presentation(environment: Dictionary, errors: Array) -> Dictionary:
	var manifest_value: Variant = environment.get("object_manifest")
	if typeof(manifest_value) != TYPE_DICTIONARY or (manifest_value as Dictionary).is_empty():
		return {}
	var manifest := manifest_value as Dictionary
	var manifest_errors := EnvironmentObjectManifestScript.validate(manifest)
	if not manifest_errors.is_empty():
		for error_value in manifest_errors:
			errors.append("Persisted base slot authority has an invalid object manifest: %s" % str(error_value))
		return {}
	var expected_environment_id := str(environment.get("id", environment.get("world_node_id", environment.get("archetype_id", "")))).strip_edges()
	var expected_archetype_id := str(environment.get("archetype_id", "")).strip_edges()
	var expected_layer_id := str(environment.get("current_layer_id", environment.get("layer_id", ""))).strip_edges()
	if str(manifest.get("environment_id", "")) != expected_environment_id \
			or str(manifest.get("archetype_id", "")) != expected_archetype_id \
			or str(manifest.get("layer_id", "")) != expected_layer_id:
		errors.append("Persisted base slot authority object manifest belongs to a different environment or layer.")
		return {}
	var result: Dictionary = {}
	for row_value in _array(manifest.get("rows", [])):
		var row := _dict(row_value)
		if not bool(row.get("active", false)) or not bool(row.get("physical", false)):
			continue
		var presentation_id := str(row.get("presentation_object_id", "")).strip_edges()
		var family := str(row.get("family", ""))
		var placement_class := str(row.get("placement_class", ""))
		if presentation_id.is_empty() or family not in SLOT_FAMILIES or placement_class not in EnvironmentPlacementScript.CLASSES:
			errors.append("Persisted base slot authority object manifest contains malformed physical placement authority.")
			continue
		result[presentation_id] = row
	return result


static func _slot_rect(slot: Dictionary) -> Rect2:
	var values := _array(slot.get("hit_rect", []))
	if values.size() < 4:
		return Rect2()
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


static func _slot_contact(slot: Dictionary, fallback: Vector2) -> Vector2:
	var values := _array(slot.get("pos", []))
	if values.size() < 2:
		return fallback
	return Vector2(float(values[0]), float(values[1]))


static func _moving_center_offset(
	start_slot: Dictionary,
	end_slot: Dictionary,
	start_rect: Rect2,
	end_rect: Rect2,
	start_contact: Vector2,
	end_contact: Vector2
) -> Vector2:
	var start_offset := start_rect.get_center() - start_contact
	var end_offset := end_rect.get_center() - end_contact
	if start_offset.is_equal_approx(end_offset):
		return start_offset
	if str(start_slot.get("footprint_class", "")) == "doorway":
		return end_offset
	if str(end_slot.get("footprint_class", "")) == "doorway":
		return start_offset
	return start_offset


static func _authored_lane_polyline(surface_map: Dictionary, lane_ids: Array, start_contact: Vector2) -> Array[Vector2]:
	var lanes_by_id: Dictionary = {}
	for lane_value in _array(surface_map.get("walk_lanes", [])):
		var lane := _dict(lane_value)
		var lane_id := str(lane.get("id", ""))
		if not lane_id.is_empty():
			lanes_by_id[lane_id] = lane
	var result: Array[Vector2] = []
	for lane_id_value in lane_ids:
		var lane := _dict(lanes_by_id.get(str(lane_id_value), {}))
		var lane_points: Array[Vector2] = []
		for point_value in _array(lane.get("points", [])):
			var parts := _array(point_value)
			if parts.size() >= 2:
				lane_points.append(Vector2(float(parts[0]), float(parts[1])))
		if lane_points.size() < 2:
			return []
		var direction := str(lane.get("direction", "both"))
		if direction == "reverse":
			lane_points.reverse()
		elif direction == "both":
			var approach: Vector2 = start_contact if result.is_empty() else result.back()
			if approach.distance_squared_to(lane_points.back()) < approach.distance_squared_to(lane_points.front()):
				lane_points.reverse()
		if not result.is_empty() and not result.back().is_equal_approx(lane_points.front()):
			return []
		for lane_point in lane_points:
			_append_unique_point(result, lane_point)
	return result


static func _nearest_polyline_projection(points: Array[Vector2], target: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_distance_squared := INF
	var traversed := 0.0
	for index in range(1, points.size()):
		var segment_start := points[index - 1]
		var segment_end := points[index]
		var segment := segment_end - segment_start
		var length_squared := segment.length_squared()
		if length_squared <= 0.000001:
			continue
		var segment_length := sqrt(length_squared)
		var weight := clampf((target - segment_start).dot(segment) / length_squared, 0.0, 1.0)
		var projected := segment_start + segment * weight
		var distance_squared := target.distance_squared_to(projected)
		var distance_along := traversed + segment_length * weight
		if distance_squared < best_distance_squared - 0.000001 \
				or is_equal_approx(distance_squared, best_distance_squared) and (best.is_empty() or distance_along < float(best.get("distance_along", INF))):
			best_distance_squared = distance_squared
			best = {"point": projected, "distance_along": distance_along}
		traversed += segment_length
	return best


static func _polyline_slice(
	points: Array[Vector2],
	start_point: Vector2,
	start_distance: float,
	end_point: Vector2,
	end_distance: float
) -> Array[Vector2]:
	var vertex_distances: Array[float] = [0.0]
	for index in range(1, points.size()):
		vertex_distances.append(float(vertex_distances.back()) + points[index - 1].distance_to(points[index]))
	var result: Array[Vector2] = []
	_append_unique_point(result, start_point)
	if start_distance <= end_distance:
		for index in range(1, points.size() - 1):
			var distance := vertex_distances[index]
			if distance > start_distance + 0.001 and distance < end_distance - 0.001:
				_append_unique_point(result, points[index])
	else:
		for index in range(points.size() - 2, 0, -1):
			var distance := vertex_distances[index]
			if distance < start_distance - 0.001 and distance > end_distance + 0.001:
				_append_unique_point(result, points[index])
	_append_unique_point(result, end_point)
	return result


static func _append_unique_point(points: Array[Vector2], point: Vector2) -> void:
	if points.is_empty() or not points.back().is_equal_approx(point):
		points.append(point)


static func _normalized_rect(rect: Rect2) -> Dictionary:
	if not rect.has_area():
		return {}
	return {
		"x": rect.position.x / BOARD_SIZE.x,
		"y": rect.position.y / BOARD_SIZE.y,
		"w": rect.size.x / BOARD_SIZE.x,
		"h": rect.size.y / BOARD_SIZE.y,
	}


static func _rect_from_dict(value: Variant) -> Rect2:
	if typeof(value) == TYPE_RECT2:
		return value as Rect2
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var data := value as Dictionary
	return Rect2(
		Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0))),
		Vector2(float(data.get("w", 0.0)), float(data.get("h", 0.0)))
	)


static func _clamp_inside_board(rect: Rect2) -> Rect2:
	var size := Vector2(minf(rect.size.x, BOARD_SIZE.x), minf(rect.size.y, BOARD_SIZE.y))
	return Rect2(
		Vector2(clampf(rect.position.x, 0.0, BOARD_SIZE.x - size.x), clampf(rect.position.y, 0.0, BOARD_SIZE.y - size.y)),
		size
	)


static func _without_dormant_orphan_object_rects(layout_value: Dictionary, current_record_ids: Dictionary) -> Dictionary:
	var layout := layout_value.duplicate(true)
	var bindings := _dict(layout.get("slot_bindings", {}))
	var object_rects := _dict(layout.get("object_rects", {}))
	for object_id_value in object_rects.keys():
		# Malformed keys remain intact so the strict validator reports them.
		if typeof(object_id_value) != TYPE_STRING:
			continue
		var object_id := str(object_id_value)
		if object_id.is_empty() or object_id != object_id.strip_edges() or current_record_ids.has(object_id):
			continue
		var binding := _dict(bindings.get(object_id, {}))
		if str(binding.get("presentation_mode", "")) != PRESENTATION_ROOM:
			object_rects.erase(object_id_value)
	layout["object_rects"] = object_rects
	return layout


static func _has_any_base_layout_authority(layout: Dictionary) -> bool:
	# object_rects predates fixed-slot authority and remains a supported legacy
	# input. Any slot-specific field, however, makes the whole envelope mandatory.
	for key in ["slot_schema_version", "slot_map_digest", "slot_binding_digest", "slot_bindings", "slot_overflow_ids"]:
		if layout.has(key):
			return true
	return false


static func _closed_dictionary(value: Dictionary, expected_keys: Array) -> bool:
	if value.size() != expected_keys.size():
		return false
	for key in expected_keys:
		if not value.has(key):
			return false
	return true


static func _same_normalized_rect(left_value: Variant, right_value: Variant) -> bool:
	if typeof(left_value) != TYPE_DICTIONARY or typeof(right_value) != TYPE_DICTIONARY:
		return false
	var left := left_value as Dictionary
	var right := right_value as Dictionary
	if not _closed_dictionary(left, ["x", "y", "w", "h"]) or not _closed_dictionary(right, ["x", "y", "w", "h"]):
		return false
	for key in ["x", "y", "w", "h"]:
		if typeof(left.get(key)) not in [TYPE_INT, TYPE_FLOAT] or typeof(right.get(key)) not in [TYPE_INT, TYPE_FLOAT] \
				or not is_finite(float(left.get(key))) or not is_finite(float(right.get(key))) \
				or not is_equal_approx(float(left.get(key)), float(right.get(key))):
			return false
	return true


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


# Read-only accessors for validated placement authority. The binder keeps the
# copying helpers above at ownership boundaries, but hot scans and comparators
# must not recursively clone the same map for every lookup.
static func _dict_view(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


static func _array_view(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []
