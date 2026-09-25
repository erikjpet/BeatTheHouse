class_name EnvironmentSlotBinder
extends RefCounted

const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const ArtContractsScript := preload("res://scripts/core/art_contracts.gd")

const BOARD_SIZE := Vector2(900.0, 430.0)
const MIN_INTERACTIVE_TARGET := Vector2(44.0, 44.0)
const SMALL_SCREEN_TARGET := Vector2(ArtContractsScript.ENVIRONMENT_OBJECT_HIT_SIZE)
const LABEL_MIN_WIDTH := 48.0
const LABEL_MAX_WIDTH := 126.0
const LABEL_HEIGHT := 15.0
const LABEL_TWO_LINE_HEIGHT := 26.0
const SLOT_SCHEMA_VERSION := 1
const PRESENTATION_ROOM := "room"
const PRESENTATION_OVERFLOW := "overflow"
const BASE_BINDING_KEYS := ["identity", "kind", "presentation_mode", "slot_id", "placement_class", "slot"]
const BASE_LAYOUT_AUTHORITY_KEYS := ["slot_schema_version", "slot_map_digest", "slot_binding_digest", "slot_bindings", "slot_overflow_ids", "object_rects"]

# Scenario scene objects may consume geometry only when two independent,
# reviewed authorities agree: scenario_slot_ids names the exact stable object
# and scenario_art_keys names a renderer that draws a concrete prop. Labels,
# roles, and keyword classification are never positive physical authority.
const CONCRETE_SCENARIO_ART_KEYS := [
	"counter_phone", "jammed_machine", "motel_door", "paper_note", "payphone",
	"room_display", "room_hazard", "room_refreshment",
	"room_seating", "room_signal", "room_storage", "room_surface",
	"room_vehicle", "security_camera", "side_door", "trunk_offer",
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

const ABSTRACT_SCENARIO_ID_TOKENS := [
	"barrier", "choice", "ledger", "marker", "route", "seal", "task",
	"trace", "work_zone", "zone",
]

# Base inventory uses the same physical-only presentation rule as scenario
# inventory. These are closed renderer contracts, not guesses from labels,
# roles, ids, placement classes, or general icon names.
# Casino fixtures bind interaction targets to room-native desks, counters, and
# machines that the environment canvas already renders as permanent scenery.
const BASE_ALWAYS_PHYSICAL_TYPES := ["casino_fixture", "game", "item", "shopkeeper", "numbers_silas"]
const BASE_PERSON_VISUAL_TYPES := ["actor", "character", "npc"]
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
static func bind_base_layout(environment: Dictionary, active_entries: Array) -> Dictionary:
	var surface_map := EnvironmentPlacementScript.surface_map(environment)
	var slots := _ordered_slots(_array(surface_map.get("base_slots", [])))
	var object_preferences := _dict(surface_map.get("object_slot_ids", {}))
	var category_preferences := _dict(surface_map.get("category_slot_ids", {}))
	var occupied: Dictionary = {}
	var object_rects: Dictionary = {}
	var bindings: Dictionary = {}
	var overflow_ids: Array = []
	var entries := active_entries.duplicate(true)
	entries.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left := _dict(left_value)
		var right := _dict(right_value)
		return str(left.get("object_id", "")) < str(right.get("object_id", ""))
	)
	for entry_value in entries:
		var entry := _dict(entry_value)
		var object_id := str(entry.get("object_id", "")).strip_edges()
		if object_id.is_empty() or bindings.has(object_id):
			continue
		var placement_class := EnvironmentPlacementScript.classify(
			entry,
			str(entry.get("object_type", "")),
			object_id,
			str(entry.get("visual_prop", entry.get("prop", "")))
		)
		if not base_record_requires_room_slot(entry):
			bindings[object_id] = _overflow_binding(object_id, placement_class, "base")
			overflow_ids.append(object_id)
			continue
		var preference := str(object_preferences.get(object_id, "")).strip_edges()
		if preference.is_empty():
			var category_key := "%s:%d" % [str(entry.get("spot_field", "")), int(entry.get("index", 0))]
			preference = str(category_preferences.get(category_key, "")).strip_edges()
		# Generated base records are actionable by default. Decorative-only late
		# records bypass this inventory; never serialize an undersized room target.
		var slot := _select_slot(slots, occupied, placement_class, preference, false, MIN_INTERACTIVE_TARGET)
		if slot.is_empty():
			bindings[object_id] = _overflow_binding(object_id, placement_class, "base")
			overflow_ids.append(object_id)
			continue
		var slot_id := str(slot.get("id", ""))
		occupied[slot_id] = object_id
		var binding := _room_binding(object_id, placement_class, "base", slot)
		bindings[object_id] = binding
		object_rects[object_id] = _normalized_rect(_slot_rect(slot))
	return {
		"ok": true,
		"slot_schema_version": SLOT_SCHEMA_VERSION,
		"slot_map_digest": slot_map_digest(surface_map),
		"binding_digest": binding_digest(bindings),
		"slot_bindings": bindings,
		"object_rects": object_rects,
		"overflow_ids": overflow_ids,
		"occupied_slot_ids": occupied.keys(),
		"errors": [],
	}


# Authenticates the complete persisted base-slot envelope before any caller may
# reuse it, extend it with late records, or derive semantic authority from it.
# Room bindings are immutable authored reservations; only bindings with a live
# object_rect are rendered. Overflow is the one geometry-free presentation.
static func validate_base_layout_authority(environment: Dictionary, current_records: Array = [], allow_unbound_records: bool = false) -> Dictionary:
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
	var surface_map := EnvironmentPlacementScript.surface_map(environment)
	var expected_map_digest := slot_map_digest(surface_map)
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
	var current_records_by_id: Dictionary = {}
	for record_value in current_records:
		var record := _dict(record_value)
		var record_id := str(record.get("object_id", record.get("presentation_object_id", ""))).strip_edges()
		if not record_id.is_empty() and not current_records_by_id.has(record_id):
			current_records_by_id[record_id] = record
	var stored_digest := str(layout.get("slot_binding_digest", ""))
	if stored_digest.is_empty() or stored_digest != binding_digest(bindings):
		errors.append("Persisted base slot authority binding digest is missing or stale.")
	var authored_slots := _slots_by_id(_array(surface_map.get("base_slots", [])))
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
		for string_key in ["identity", "kind", "presentation_mode", "slot_id", "placement_class"]:
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
		if str(binding.get("kind", "")) != "base":
			errors.append("Persisted base slot binding %s does not have base kind." % identity)
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
			var authored_slot := _dict(authored_slots.get(slot_id, {}))
			var minimum_required := true
			if current_records_by_id.has(identity):
				minimum_required = bool(_dict(current_records_by_id.get(identity, {})).get("interactive", true))
			if slot_id.is_empty() or authored_slot.is_empty() or JSON.stringify(binding_slot) != JSON.stringify(authored_slot):
				errors.append("Persisted base room binding %s does not match its exact authored slot." % identity)
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
	var aliases: Dictionary = {}
	for record_value in current_records:
		var record := _dict(record_value)
		var object_id := str(record.get("object_id", record.get("presentation_object_id", ""))).strip_edges()
		var source_id := str(record.get("slot_binding_source_id", "")).strip_edges()
		if object_id.is_empty():
			continue
		var record_binding := _dict(bindings.get(object_id, {}))
		if record_binding.is_empty():
			if not allow_unbound_records:
				errors.append("Current base record %s has no authenticated slot binding." % object_id)
			continue
		# Live production records carry their source class inputs. Durable semantic
		# interactions deliberately keep a closed payload, so replay the same stable
		# type/id classification used by EnvironmentInstance for its base domains.
		# This keeps placement_class out of semantic authority without letting a
		# re-digested wrong-class binding authenticate itself.
		var expected_class := ""
		var class_override := str(_dict(surface_map.get("class_overrides", {})).get(object_id, ""))
		if class_override in EnvironmentPlacementScript.CLASSES:
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
		if source_id.is_empty():
			continue
		if aliases.has(object_id) and str(aliases.get(object_id, "")) != source_id:
			errors.append("Current base record %s declares conflicting slot-binding aliases." % object_id)
		else:
			aliases[object_id] = source_id
	for slot_id_value in room_ids_by_slot.keys():
		var identities := _array(room_ids_by_slot.get(slot_id_value, []))
		if identities.size() <= 1:
			continue
		identities.sort()
		var roots: Array = []
		for identity_value in identities:
			var identity := str(identity_value)
			var source_id := str(aliases.get(identity, ""))
			if source_id.is_empty():
				roots.append(identity)
			elif source_id == identity or not identities.has(source_id):
				errors.append("Persisted base room binding %s duplicates slot %s without an explicit current source alias." % [identity, str(slot_id_value)])
		if roots.size() != 1:
			errors.append("Persisted base room slot %s has duplicate bindings without exactly one unaliased source." % str(slot_id_value))
	return {
		"ok": errors.is_empty(),
		"slot_bindings": bindings if errors.is_empty() else {},
		"overflow_ids": overflow_ids if errors.is_empty() else [],
		"object_rects": object_rects if errors.is_empty() else {},
		"slot_map_digest": expected_map_digest,
		"binding_digest": stored_digest,
		"errors": errors,
	}


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
	var object_type := str(record.get("object_type", "")).strip_edges()
	var visual_type := str(record.get("visual_type", "")).strip_edges()
	if object_type in BASE_ALWAYS_PHYSICAL_TYPES:
		return true
	if bool(record.get("physical_person", false)) \
			or visual_type in BASE_PERSON_VISUAL_TYPES \
			or not _dict(record.get("character_actor", {})).is_empty():
		return true
	var asset_path := str(record.get("asset_path", "")).strip_edges()
	if asset_path.begins_with("res://assets/art/"):
		return true
	if object_type == "travel" or visual_type == "travel" or visual_type == "drink":
		return true
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
	return entry


# Applies the same authority to the complete interaction inventory. Some live
# records (deliveries, transient contacts, and meta controls) are assembled
# after EnvironmentInstance generated its serialized layout. Only records that
# pass the same physical gate consume still-free authored base slots; every
# other record remains fully actionable in the room action list.
static func bind_base_records(environment: Dictionary, records: Array, existing_bindings: Dictionary = {}) -> Dictionary:
	var surface_map := EnvironmentPlacementScript.surface_map(environment)
	var slots := _ordered_slots(_array(surface_map.get("base_slots", [])))
	var object_preferences := _dict(surface_map.get("object_slot_ids", {}))
	var category_preferences := _dict(surface_map.get("category_slot_ids", {}))
	var layout := _dict(environment.get("layout", {}))
	# bind_base_records consumes the complete current interaction refresh. Build
	# its identity set before authenticating persisted geometry so a rectangle for
	# an already-resolved object can be distinguished from a live unbound object.
	var current_record_ids: Dictionary = {}
	var current_records_by_id: Dictionary = {}
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
		var authenticated_environment := environment.duplicate(true)
		authenticated_environment["layout"] = layout.duplicate(true)
		var prior_authority := validate_base_layout_authority(authenticated_environment, records, true)
		if not bool(prior_authority.get("ok", false)):
			return {"ok": false, "records": records.duplicate(true), "slot_bindings": {}, "overflow_ids": [], "object_rects": {}, "errors": _array(prior_authority.get("errors", []))}
		bindings = _dict(prior_authority.get("slot_bindings", {}))
		object_rects = _dict(prior_authority.get("object_rects", {}))
		if not existing_bindings.is_empty() and JSON.stringify(existing_bindings) != JSON.stringify(bindings):
			return {"ok": false, "records": records.duplicate(true), "slot_bindings": {}, "overflow_ids": [], "object_rects": {}, "errors": ["Caller base bindings do not match the authenticated persisted authority."]}
	# A prior
	# room reservation may remain intentionally dormant, but geometry-free overflow
	# has no physical reservation and must retain live membership to persist.
	# Reconcile legacy/generated authority before calculating occupancy. Live UI
	# records carry visual_type; the deliberately stripped catalog records used by
	# semantic sealing do not, and must consume the already-authenticated result
	# rather than accidentally reclassify it from incomplete presentation data.
	for binding_id_value in bindings.keys():
		var binding_id := str(binding_id_value)
		var current_record := _dict(current_records_by_id.get(binding_id, {}))
		# A live alias is another action surface for its authenticated source
		# object, not an independent claim that a semantic control is physical.
		# Synchronize aliases after their source bindings have been reconciled.
		if not current_record.is_empty() \
				and not str(current_record.get("slot_binding_source_id", "")).strip_edges().is_empty():
			continue
		var policy_record: Dictionary = {}
		if not current_record.is_empty() and current_record.has("visual_type"):
			policy_record = current_record
		elif current_record.is_empty():
			policy_record = _base_layout_policy_entry(environment, binding_id)
		if policy_record.is_empty():
			continue
		var existing_binding := _dict(bindings.get(binding_id_value, {}))
		var existing_mode := str(existing_binding.get("presentation_mode", ""))
		var requires_room := base_record_requires_room_slot(policy_record)
		if not requires_room and existing_mode == PRESENTATION_ROOM:
			bindings[binding_id_value] = _overflow_binding(
				binding_id,
				str(existing_binding.get("placement_class", "floor_fixture")),
				str(existing_binding.get("kind", "base"))
			)
			object_rects.erase(binding_id)
		elif requires_room and existing_mode == PRESENTATION_OVERFLOW and not current_record.is_empty():
			# A newly visible person or newly authored asset may promote an old
			# overflow row. Remove it so the normal deterministic slot pass below
			# can claim only a still-free authored slot.
			bindings.erase(binding_id_value)
			object_rects.erase(binding_id)
	for current_id_value in current_records_by_id.keys():
		var current_id := str(current_id_value)
		var alias_record := _dict(current_records_by_id.get(current_id_value, {}))
		var source_id := str(alias_record.get("slot_binding_source_id", "")).strip_edges()
		if source_id.is_empty() or not bindings.has(current_id) or not bindings.has(source_id):
			continue
		var source_binding := _dict(bindings.get(source_id, {}))
		source_binding["identity"] = current_id
		bindings[current_id] = source_binding
		if str(source_binding.get("presentation_mode", "")) == PRESENTATION_OVERFLOW:
			object_rects.erase(current_id)
	for binding_id_value in bindings.keys():
		var binding_id := str(binding_id_value)
		if current_record_ids.has(binding_id):
			continue
		if str(_dict(bindings.get(binding_id_value, {})).get("presentation_mode", "")) == PRESENTATION_OVERFLOW:
			bindings.erase(binding_id_value)
		# A dormant room binding reserves its authored slot, but it cannot keep live
		# render geometry after the complete interaction refresh omits its identity.
		object_rects.erase(binding_id)
	var occupied: Dictionary = {}
	for existing_value in bindings.values():
		var existing := _dict(existing_value)
		if str(existing.get("presentation_mode", "")) != PRESENTATION_ROOM:
			continue
		var existing_slot_id := str(existing.get("slot_id", "")).strip_edges()
		if not existing_slot_id.is_empty():
			occupied[existing_slot_id] = str(existing.get("identity", ""))
	var ordered: Array = []
	for record_value in records:
		var record := _dict(record_value)
		var object_id := str(record.get("object_id", "")).strip_edges()
		if not object_id.is_empty():
			ordered.append(record)
	ordered.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		return str(_dict(left_value).get("object_id", "")) < str(_dict(right_value).get("object_id", ""))
	)
	for record_value in ordered:
		var record := _dict(record_value)
		var object_id := str(record.get("object_id", "")).strip_edges()
		if bindings.has(object_id):
			continue
		# Late live records cross this binder after EnvironmentInstance generated its
		# initial object inventory. Apply the same authored room/scenario override
		# that generation and authority validation use, so the new binding cannot be
		# minted from a generic record class and then fail its own sealed replay.
		var class_override := str(_dict(surface_map.get("class_overrides", {})).get(object_id, ""))
		var placement_class := class_override if class_override in EnvironmentPlacementScript.CLASSES else EnvironmentPlacementScript.classify(
			record,
			str(record.get("object_type", "")),
			object_id,
			str(record.get("visual_prop", record.get("prop", record.get("icon_key", ""))))
		)
		# A late interaction can be the actionable representation of an object
		# already present in the generated base inventory. Reuse that immutable
		# binding instead of consuming a second slot for the same physical prop.
		var binding_source_id := str(record.get("slot_binding_source_id", "")).strip_edges()
		var shared_binding := _dict(bindings.get(binding_source_id, {}))
		if not binding_source_id.is_empty() \
				and binding_source_id != object_id \
				and not shared_binding.is_empty() \
				and str(shared_binding.get("placement_class", "")) == placement_class:
			shared_binding["identity"] = object_id
			bindings[object_id] = shared_binding
			continue
		if not base_record_requires_room_slot(record):
			bindings[object_id] = _overflow_binding(object_id, placement_class, "base")
			continue
		var preference := str(object_preferences.get(object_id, "")).strip_edges()
		if preference.is_empty():
			var spot_field := str(record.get("layout_spot_field", "")).strip_edges()
			var category_key := "%s:%d" % [spot_field, int(record.get("layout_index", 0))]
			preference = str(category_preferences.get(category_key, "")).strip_edges()
		var minimum_size := MIN_INTERACTIVE_TARGET if bool(record.get("interactive", true)) else Vector2.ZERO
		var slot := _select_slot(slots, occupied, placement_class, preference, false, minimum_size)
		if slot.is_empty():
			bindings[object_id] = _overflow_binding(object_id, placement_class, "base")
			continue
		var slot_id := str(slot.get("id", ""))
		occupied[slot_id] = object_id
		bindings[object_id] = _room_binding(object_id, placement_class, "base", slot)
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
	# Report the complete binding authority, including persisted/generated
	# overflow identities that were not part of this particular record refresh.
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
	candidate_layout["slot_map_digest"] = slot_map_digest(surface_map)
	candidate_layout["slot_binding_digest"] = binding_digest_value
	candidate_layout["slot_bindings"] = bindings.duplicate(true)
	candidate_layout["slot_overflow_ids"] = overflow_ids.duplicate(true)
	candidate_layout["object_rects"] = object_rects.duplicate(true)
	var candidate_environment := environment.duplicate(true)
	candidate_environment["layout"] = candidate_layout
	var candidate_authority := validate_base_layout_authority(candidate_environment, result_records)
	if not bool(candidate_authority.get("ok", false)):
		return {"ok": false, "records": records.duplicate(true), "slot_bindings": {}, "overflow_ids": [], "object_rects": {}, "errors": _array(candidate_authority.get("errors", []))}
	return {
		"ok": true,
		"records": result_records,
		"slot_bindings": bindings,
		"overflow_ids": overflow_ids,
		"object_rects": object_rects,
		"slot_schema_version": SLOT_SCHEMA_VERSION,
		"slot_map_digest": slot_map_digest(surface_map),
		"binding_digest": binding_digest_value,
		"authenticated_prior_layout": layout.duplicate(true),
		"errors": [],
	}


# Binds scenario-owned visuals. Required safe exits use exit slots; all other
# visuals use stage slots. Route actors reserve both authored endpoints.
static func bind_scenario_visuals(environment: Dictionary, visual_entries: Array) -> Dictionary:
	var surface_map := EnvironmentPlacementScript.surface_map(environment)
	var stage_slots := _ordered_slots(_array(surface_map.get("stage_slots", [])))
	var exit_slots := _ordered_slots(_array(surface_map.get("exit_slots", [])))
	var all_slots := stage_slots + exit_slots
	var slots_by_id := _slots_by_id(all_slots)
	var preferences := _dict(surface_map.get("scenario_slot_ids", {}))
	var art_keys := _dict(surface_map.get("scenario_art_keys", {}))
	var position_routes := _dict(surface_map.get("scenario_position_route_ids", {}))
	var routes_by_id := _routes_by_id(_array(surface_map.get("actor_routes", [])))
	var occupied: Dictionary = {}
	var bindings: Dictionary = {}
	var overflow_ids: Array = []
	var errors: Array = []
	_validate_scenario_art_policy(surface_map, art_keys, errors)
	var authored_overflow_ids := _scenario_overflow_policy(surface_map, errors)
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
	var entries := visual_entries.duplicate(true)
	entries.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		return str(_dict(left_value).get("identity", "")) < str(_dict(right_value).get("identity", ""))
	)
	# Physical exits and moving actors reserve first. Semantic exit controls and
	# routes are authenticated overflow rows and consume no room geometry.
	entries.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left := _dict(left_value)
		var right := _dict(right_value)
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
		var left_rank := 0 if bool(left.get("safe_exit", false)) else 1 if not left_route.is_empty() else 2
		var right_rank := 0 if bool(right.get("safe_exit", false)) else 1 if not right_route.is_empty() else 2
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
			bindings[identity] = _overflow_binding(
				identity,
				"",
				"exit" if bool(entry.get("safe_exit", false)) else "stage",
				"action_list_authored"
			)
			overflow_ids.append(identity)
			continue
		if not art_key.is_empty():
			semantic["icon_key"] = art_key
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
		if authored_overflow_ids.has(stable_id):
			if not identity.begins_with("scenario::") or bool(entry.get("safe_exit", false)) or not route_id.is_empty():
				errors.append("Authored scenario overflow %s must be a non-routed, non-exit scenario-owned visual." % identity)
				continue
			bindings[identity] = _overflow_binding(identity, placement_class, "stage", "physical_spill")
			overflow_ids.append(identity)
			continue
		var route := _dict(routes_by_id.get(route_id, {}))
		var slot: Dictionary = {}
		if not route_id.is_empty():
			if route.is_empty():
				errors.append("Scenario visual %s route %s has no authored route authority." % [identity, route_id])
				bindings[identity] = _overflow_binding(identity, placement_class, "stage", "invalid_physical_route")
				overflow_ids.append(identity)
				continue
			var start_id := str(route.get("start_slot_id", ""))
			var end_id := str(route.get("end_slot_id", ""))
			var start_slot := _dict(slots_by_id.get(start_id, {}))
			var end_slot := _dict(slots_by_id.get(end_id, {}))
			var lane_ids := _array(route.get("lane_ids", []))
			var route_points := authored_route_points(surface_map, start_slot, end_slot, lane_ids)
			if start_id != end_id and not start_slot.is_empty() and not end_slot.is_empty() \
					and str(start_slot.get("footprint_class", "")) == placement_class \
					and str(end_slot.get("footprint_class", "")) == placement_class \
					and _slot_meets_minimum(start_slot, MIN_INTERACTIVE_TARGET) \
					and _slot_meets_minimum(end_slot, MIN_INTERACTIVE_TARGET) \
					and not occupied.has(start_id) and not occupied.has(end_id) \
					and route_points.size() >= 2:
				slot = start_slot
				occupied[start_id] = identity
				occupied[end_id] = "route_endpoint::%s" % identity
			else:
				errors.append("Scenario visual %s route %s has invalid, incompatible, occupied, or disconnected authored endpoints." % [identity, route_id])
		elif bool(entry.get("safe_exit", false)):
			var preference := str(preferences.get(position_key, preferences.get(stable_id, preferences.get(identity, "")))).strip_edges()
			slot = _select_slot(exit_slots, occupied, placement_class, preference, not preference.is_empty(), MIN_INTERACTIVE_TARGET)
			if slot.is_empty():
				errors.append("Required safe exit %s has no free compatible authored exit slot%s." % [identity, " for preferred slot %s" % preference if not preference.is_empty() else ""])
		else:
			var preference := str(preferences.get(position_key, preferences.get(stable_id, preferences.get(identity, "")))).strip_edges()
			# Ordinary stage preferences are hints, never hard authority. A stale,
			# occupied, or class-incompatible preferred id falls through to the
			# deterministic (priority, id) order before overflow.
			slot = _select_slot(stage_slots, occupied, placement_class, preference, false, MIN_INTERACTIVE_TARGET)
		if slot.is_empty():
			errors.append("Physical scenario visual %s has no slot; add an authored slot or list the stable id in scenario_overflow_ids." % identity)
			bindings[identity] = _overflow_binding(
				identity,
				placement_class,
				"exit" if bool(entry.get("safe_exit", false)) else "stage",
				"unapproved_physical_spill"
			)
			overflow_ids.append(identity)
			continue
		var slot_id := str(slot.get("id", ""))
		if not occupied.has(slot_id):
			occupied[slot_id] = identity
		var binding := _room_binding(identity, placement_class, "exit" if bool(entry.get("safe_exit", false)) else "stage", slot)
		if not art_key.is_empty():
			binding["scenario_art_key"] = art_key
		if not route.is_empty():
			binding["route"] = route.duplicate(true)
			binding["route_id"] = route_id
		bindings[identity] = binding
	return {
		"ok": errors.is_empty(),
		"slot_schema_version": SLOT_SCHEMA_VERSION,
		"slot_map_digest": slot_map_digest(surface_map),
		"binding_digest": binding_digest(bindings),
		"slot_bindings": bindings,
		"overflow_ids": overflow_ids,
		"occupied_slot_ids": occupied.keys(),
		"errors": errors,
	}


# True means the entry has closed physical authority and may own an authored
# room slot. False means it remains reachable through the geometry-free More
# room actions presentation. Positive authority never comes from role/label
# inference.
static func scenario_visual_requires_room_slot(surface_map: Dictionary, entry: Dictionary) -> bool:
	if bool(entry.get("actor", false)):
		return true
	if bool(entry.get("safe_exit", false)):
		return true
	return not scenario_visual_art_key(surface_map, entry).is_empty()


static func scenario_visual_art_key(surface_map: Dictionary, entry: Dictionary) -> String:
	if bool(entry.get("actor", false)):
		return ""
	if bool(entry.get("safe_exit", false)):
		return "side_door"
	var identity := str(entry.get("identity", "")).strip_edges()
	var semantic := _dict(entry.get("semantic", {}))
	var stable_id := str(semantic.get("stable_object_id", identity.trim_prefix("scenario::"))).strip_edges()
	if _scenario_semantic_is_abstract(stable_id, semantic):
		return ""
	var position_key := scenario_position_key(stable_id, semantic)
	var preferences := _dict(surface_map.get("scenario_slot_ids", {}))
	var has_slot_preference := preferences.has(position_key) or preferences.has(stable_id) or preferences.has(identity)
	if not has_slot_preference:
		# A stable object can have several reviewed, position-specific bindings.
		# The concrete-art authority is object-wide, so any exact stable-id
		# composite proves the independent slot half of that authority even when
		# the caller is inspecting the semantic before a position is selected.
		for preference_key_value in preferences.keys():
			if typeof(preference_key_value) == TYPE_STRING \
					and str(preference_key_value).begins_with("%s|" % stable_id):
				has_slot_preference = true
				break
	if not has_slot_preference:
		return ""
	var art_keys := _dict(surface_map.get("scenario_art_keys", {}))
	var art_key := str(art_keys.get(stable_id, art_keys.get(identity, ""))).strip_edges()
	return art_key if art_key in CONCRETE_SCENARIO_ART_KEYS else ""


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
		"base_slots": _array(surface_map.get("base_slots", [])),
		"stage_slots": _array(surface_map.get("stage_slots", [])),
		"exit_slots": _array(surface_map.get("exit_slots", [])),
		"walk_lanes": _array(surface_map.get("walk_lanes", [])),
		"actor_routes": _array(surface_map.get("actor_routes", [])),
		"object_slot_ids": _dict(surface_map.get("object_slot_ids", {})),
		"category_slot_ids": _dict(surface_map.get("category_slot_ids", {})),
		"scenario_slot_ids": _dict(surface_map.get("scenario_slot_ids", {})),
		"scenario_art_keys": _dict(surface_map.get("scenario_art_keys", {})),
		"scenario_overflow_ids": _array(surface_map.get("scenario_overflow_ids", [])),
		"scenario_position_route_ids": _dict(surface_map.get("scenario_position_route_ids", {})),
	}).sha256_text()


static func _validate_scenario_art_policy(surface_map: Dictionary, art_keys: Dictionary, errors: Array) -> void:
	var value: Variant = surface_map.get("scenario_art_keys")
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("Scenario art authority must be an object.")
		return
	var authored_visual_ids := _authored_scenario_visual_ids(surface_map)
	var preferences := _dict(surface_map.get("scenario_slot_ids", {}))
	for stable_id_value in art_keys.keys():
		var stable_id := str(stable_id_value)
		var art_key_value: Variant = art_keys.get(stable_id_value)
		if typeof(stable_id_value) != TYPE_STRING or stable_id.is_empty() \
				or stable_id != stable_id.strip_edges() or stable_id.begins_with("scenario::") or stable_id.contains("|"):
			errors.append("Scenario art authority contains a malformed stable identity.")
			continue
		if typeof(art_key_value) != TYPE_STRING or str(art_key_value) not in CONCRETE_SCENARIO_ART_KEYS:
			errors.append("Scenario art authority %s names an unsupported concrete renderer." % stable_id)
		if not authored_visual_ids.has(stable_id):
			errors.append("Scenario art authority contains unknown authored identity %s." % stable_id)
		var has_slot_preference := preferences.has(stable_id) or preferences.has("scenario::%s" % stable_id)
		if not has_slot_preference:
			for preference_key_value in preferences.keys():
				if str(preference_key_value).begins_with("%s|" % stable_id):
					has_slot_preference = true
					break
		if not has_slot_preference:
			errors.append("Scenario art authority %s has no exact authored slot preference." % stable_id)


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


static func binding_digest(bindings: Dictionary) -> String:
	var canonical: Array = []
	var identities := bindings.keys()
	identities.sort()
	for identity_value in identities:
		canonical.append(_dict(bindings.get(identity_value, {})))
	return JSON.stringify(canonical).sha256_text()


static func rect_from_binding(binding: Dictionary) -> Rect2:
	return _slot_rect(_dict(binding.get("slot", {})))


static func expanded_rect(rect: Rect2) -> Rect2:
	if not rect.has_area():
		return Rect2()
	var size := Vector2(maxf(rect.size.x, SMALL_SCREEN_TARGET.x), maxf(rect.size.y, SMALL_SCREEN_TARGET.y))
	return _clamp_inside_board(Rect2(rect.get_center() - size * 0.5, size))


static func normalized_rect(rect: Rect2) -> Dictionary:
	return _normalized_rect(rect)


# The slot's authored label anchor is the bottom-center of the exact renderer
# rectangle. Text determines only its bounded size; runtime never searches an
# alternate position.
static func label_rect_from_binding(binding: Dictionary, label: String) -> Rect2:
	return label_rect_from_slot(_dict(binding.get("slot", {})), label)


static func label_rect_from_slot(slot: Dictionary, label: String) -> Rect2:
	if label.strip_edges().is_empty():
		return Rect2()
	var anchor_values := _array(slot.get("label_anchor", []))
	if anchor_values.size() < 2:
		return Rect2()
	var anchor := Vector2(float(anchor_values[0]), float(anchor_values[1]))
	var raw_width := float(label.strip_edges().length()) * 5.8 + 12.0
	var size := Vector2(
		minf(maxf(LABEL_MIN_WIDTH, raw_width), LABEL_MAX_WIDTH),
		LABEL_TWO_LINE_HEIGHT if raw_width > LABEL_MAX_WIDTH else LABEL_HEIGHT
	)
	return _clamp_inside_board(Rect2(anchor - Vector2(size.x * 0.5, size.y), size))


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


static func _slot_meets_minimum(slot: Dictionary, minimum_size: Vector2) -> bool:
	if minimum_size == Vector2.ZERO:
		return true
	var rect := _slot_rect(slot)
	return rect.has_area() and rect.size.x >= minimum_size.x and rect.size.y >= minimum_size.y


static func _ordered_slots(values: Array) -> Array:
	var result := values.duplicate(true)
	result.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left := _dict(left_value)
		var right := _dict(right_value)
		var left_priority := int(left.get("priority", 0))
		var right_priority := int(right.get("priority", 0))
		return str(left.get("id", "")) < str(right.get("id", "")) if left_priority == right_priority else left_priority < right_priority
	)
	return result


static func _slots_by_id(slots: Array) -> Dictionary:
	var result: Dictionary = {}
	for slot_value in slots:
		var slot := _dict(slot_value)
		var slot_id := str(slot.get("id", ""))
		if not slot_id.is_empty():
			result[slot_id] = slot
	return result


static func _routes_by_id(routes: Array) -> Dictionary:
	var result: Dictionary = {}
	for route_value in routes:
		var route := _dict(route_value)
		var route_id := str(route.get("id", ""))
		if not route_id.is_empty():
			result[route_id] = route
	return result


static func _room_binding(identity: String, placement_class: String, kind: String, slot: Dictionary) -> Dictionary:
	return {
		"identity": identity,
		"kind": kind,
		"presentation_mode": PRESENTATION_ROOM,
		"slot_id": str(slot.get("id", "")),
		"placement_class": placement_class,
		"slot": slot.duplicate(true),
	}


static func _overflow_binding(identity: String, placement_class: String, kind: String, overflow_reason: String = "") -> Dictionary:
	var binding := {
		"identity": identity,
		"kind": kind,
		"presentation_mode": PRESENTATION_OVERFLOW,
		"slot_id": "",
		"placement_class": placement_class,
		"slot": {},
	}
	if not overflow_reason.is_empty():
		binding["overflow_reason"] = overflow_reason
	return binding


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
