class_name CrewTurnModel
extends RefCounted

# Hidden, deterministic heist-fracture rules. Persisted state uses neutral keys
# because raw saves are a player-visible surface.

const STATE_VERSION := 2
const LEGACY_STATE_VERSION := 1
const TOMBSTONE_LIMIT := 16
const MEMBER_ROOK := "crew_rook"
const SIGNAL_PATTERN := "p"
const SIGNAL_ROUTE := "r"
const SIGNAL_PAYMENT := "e"
const SIGNAL_IDS := [SIGNAL_PATTERN, SIGNAL_ROUTE, SIGNAL_PAYMENT]
const PRIVATE_SAVE_PLAIN_BYTES := 65536
const PRIVATE_SAVE_BYTES := 16 + PRIVATE_SAVE_PLAIN_BYTES + 32
const PRIVATE_SAVE_FORMAT := 2
const LEGACY_PRIVATE_SAVE_BYTES := 512
const LEGACY_PRIVATE_SAVE_PLAIN_BYTES := 464
const LEGACY_PRIVATE_SAVE_FORMAT := 1
const PRIVATE_GRIEVANCE_LIMIT := 256
const PRIVATE_TEXT_BYTE_LIMIT := 128
const PRIVATE_SEQUENCE_LIMIT := 1000000000
const PRIVATE_KEY_PATH := "user://.crew_host_authority_v1"

static var _private_key_cache := PackedByteArray()


static func empty_state() -> Dictionary:
	return {"v": STATE_VERSION, "m": "", "w": [], "e": [], "h": false, "c": false, "f": 0, "t": []}


static func normalize_state(value: Variant, member_ids: Array) -> Dictionary:
	var source: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var member_id := str(source.get("m", ""))
	if not member_ids.has(member_id):
		member_id = ""
	return {
		"v": STATE_VERSION,
		"m": member_id,
		"w": _signal_array(source.get("w", [])),
		"e": _signal_array(source.get("e", [])),
		"h": bool(source.get("h", false)),
		"c": bool(source.get("c", false)),
		"f": maxi(0, int(source.get("f", 0))),
		"t": _tombstone_array(source.get("t", [])),
	}


static func restore_state(value: Variant, member_ids: Array) -> Dictionary:
	if not can_restore_state(value, member_ids):
		return empty_state()
	var source: Dictionary = value
	return normalize_state(source, member_ids)


static func can_restore_state(value: Variant, member_ids: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).is_empty(): return false
	var source: Dictionary = value
	var version := int(source.get("v", 0))
	var legacy_keys := ["c", "e", "f", "h", "m", "v", "w"]
	var current_keys := legacy_keys.duplicate(); current_keys.append("t")
	if version not in [LEGACY_STATE_VERSION, STATE_VERSION] or not _exact_keys(source, legacy_keys if version == LEGACY_STATE_VERSION else current_keys) \
			or typeof(source.get("w")) != TYPE_ARRAY or typeof(source.get("e")) != TYPE_ARRAY \
			or (version == STATE_VERSION and (typeof(source.get("t")) != TYPE_ARRAY or (source.get("t") as Array).size() > TOMBSTONE_LIMIT)):
		return false
	if not str(source.get("m", "")).is_empty() and not member_ids.has(str(source.get("m", ""))): return false
	if _signal_array(source.get("w", [])).size() != (source.get("w") as Array).size() \
			or _signal_array(source.get("e", [])).size() != (source.get("e") as Array).size(): return false
	return version != STATE_VERSION or _tombstone_array(source.get("t", [])).size() == (source.get("t") as Array).size()


static func record_tombstone(state_value: Variant, boundary: int, code: int, member_ids: Array) -> Dictionary:
	var state := normalize_state(state_value, member_ids)
	var row := {"b": maxi(0, boundary), "q": clampi(code, 1, 99)}
	var rows := _tombstone_array(state.get("t", []))
	if rows.has(row): return state
	rows.append(row)
	while rows.size() > TOMBSTONE_LIMIT: rows.pop_front()
	state["t"] = rows
	return state


static func private_save_fingerprint(payload_value: Variant, member_ids: Array, grievance_kinds: Array, binding: String) -> String:
	var payload := normalize_private_payload(payload_value, member_ids, grievance_kinds)
	return "" if payload.is_empty() else (binding + "\n" + canonical_json(payload)).sha256_text()


# The run save carries only a fixed-size authenticated capsule. Its key is a
# random per-install host secret stored outside the run save; there is no
# shipped key or deterministic ciphertext for an offline save observer to use
# as a clean/turned classifier.
static func pack_private_save(payload_value: Variant, member_ids: Array, grievance_kinds: Array, binding: String) -> String:
	var payload := normalize_private_payload(payload_value, member_ids, grievance_kinds)
	if payload.is_empty(): return ""
	var master_key := _private_install_key()
	if master_key.size() != 32: return ""
	var encryption_key := _private_subkey(master_key, "aes-cbc")
	var authentication_key := _private_subkey(master_key, "hmac-sha256")
	var body := canonical_json(payload).to_utf8_buffer()
	if body.size() + 4 > PRIVATE_SAVE_PLAIN_BYTES: return ""
	var plain := Crypto.new().generate_random_bytes(PRIVATE_SAVE_PLAIN_BYTES)
	plain[0] = (body.size() >> 24) & 0xff
	plain[1] = (body.size() >> 16) & 0xff
	plain[2] = (body.size() >> 8) & 0xff
	plain[3] = body.size() & 0xff
	for index in range(body.size()): plain[index + 4] = body[index]
	var iv := Crypto.new().generate_random_bytes(16)
	var aes := AESContext.new()
	if aes.start(AESContext.MODE_CBC_ENCRYPT, encryption_key, iv) != OK: return ""
	var encrypted := aes.update(plain)
	aes.finish()
	if encrypted.size() != PRIVATE_SAVE_PLAIN_BYTES: return ""
	var authenticated := PackedByteArray()
	authenticated.append_array(iv)
	authenticated.append_array(encrypted)
	var mac := _private_save_mac(authentication_key, binding, authenticated)
	if mac.size() != 32: return ""
	authenticated.append_array(mac)
	return Marshalls.raw_to_base64(authenticated) if authenticated.size() == PRIVATE_SAVE_BYTES else ""


static func unpack_private_save(encoded: String, member_ids: Array, grievance_kinds: Array, binding: String) -> Dictionary:
	var master_key := _private_install_key()
	var capsule := Marshalls.base64_to_raw(encoded)
	if master_key.size() != 32 or capsule.size() != PRIVATE_SAVE_BYTES: return {}
	var encryption_key := _private_subkey(master_key, "aes-cbc")
	var authentication_key := _private_subkey(master_key, "hmac-sha256")
	var authenticated := capsule.slice(0, 16 + PRIVATE_SAVE_PLAIN_BYTES)
	var supplied_mac := capsule.slice(16 + PRIVATE_SAVE_PLAIN_BYTES)
	var expected_mac := _private_save_mac(authentication_key, binding, authenticated)
	if supplied_mac.size() != expected_mac.size() or not _constant_time_equal(supplied_mac, expected_mac): return {}
	var aes := AESContext.new()
	if aes.start(AESContext.MODE_CBC_DECRYPT, encryption_key, authenticated.slice(0, 16)) != OK: return {}
	var plain := aes.update(authenticated.slice(16))
	aes.finish()
	if plain.size() != PRIVATE_SAVE_PLAIN_BYTES: return {}
	var body_size := (int(plain[0]) << 24) | (int(plain[1]) << 16) | (int(plain[2]) << 8) | int(plain[3])
	if body_size <= 0 or body_size + 4 > PRIVATE_SAVE_PLAIN_BYTES: return {}
	var parsed: Variant = JSON.parse_string(plain.slice(4, body_size + 4).get_string_from_utf8())
	return normalize_private_payload(parsed, member_ids, grievance_kinds)


static func unpack_legacy_private_save(encoded: String, member_ids: Array, binding: String) -> Dictionary:
	var master_key := _private_install_key()
	var capsule := Marshalls.base64_to_raw(encoded)
	if master_key.size() != 32 or capsule.size() != LEGACY_PRIVATE_SAVE_BYTES: return {}
	var encryption_key := _private_subkey(master_key, "aes-cbc")
	var authentication_key := _private_subkey(master_key, "hmac-sha256")
	var authenticated := capsule.slice(0, 16 + LEGACY_PRIVATE_SAVE_PLAIN_BYTES)
	var supplied_mac := capsule.slice(16 + LEGACY_PRIVATE_SAVE_PLAIN_BYTES)
	var expected_mac := _private_save_mac(authentication_key, binding, authenticated)
	if supplied_mac.size() != expected_mac.size() or not _constant_time_equal(supplied_mac, expected_mac): return {}
	var aes := AESContext.new()
	if aes.start(AESContext.MODE_CBC_DECRYPT, encryption_key, authenticated.slice(0, 16)) != OK: return {}
	var plain := aes.update(authenticated.slice(16))
	aes.finish()
	if plain.size() != LEGACY_PRIVATE_SAVE_PLAIN_BYTES: return {}
	var body_size := (int(plain[0]) << 24) | (int(plain[1]) << 16) | (int(plain[2]) << 8) | int(plain[3])
	if body_size <= 0 or body_size + 4 > LEGACY_PRIVATE_SAVE_PLAIN_BYTES: return {}
	var parsed: Variant = JSON.parse_string(plain.slice(4, body_size + 4).get_string_from_utf8())
	return restore_state(parsed, member_ids) if can_restore_state(parsed, member_ids) else {}


static func private_save_binding(authority_id: String, seed_text: String, public_context: Dictionary) -> String:
	if not valid_authority_id(authority_id): return ""
	return "%d\n%s\n%s\n%s" % [PRIVATE_SAVE_FORMAT, authority_id, seed_text, canonical_json(public_context).sha256_text()]


static func legacy_private_save_binding(seed_text: String, plan_id: String, locked_action: int) -> String:
	return "%d\n%s\n%s\n%d" % [LEGACY_PRIVATE_SAVE_FORMAT, seed_text, plan_id, maxi(0, locked_action)]


# Retained only to prove and support migration from the shipped 512-byte
# heist-local capsule. New saves must use pack_private_save().
static func pack_legacy_private_save(state_value: Variant, member_ids: Array, binding: String) -> String:
	var state := normalize_state(state_value, member_ids)
	if not can_restore_state(state, member_ids): return ""
	var master_key := _private_install_key()
	if master_key.size() != 32: return ""
	var body := canonical_json(state).to_utf8_buffer()
	if body.size() + 4 > LEGACY_PRIVATE_SAVE_PLAIN_BYTES: return ""
	var plain := Crypto.new().generate_random_bytes(LEGACY_PRIVATE_SAVE_PLAIN_BYTES)
	plain[0] = (body.size() >> 24) & 0xff
	plain[1] = (body.size() >> 16) & 0xff
	plain[2] = (body.size() >> 8) & 0xff
	plain[3] = body.size() & 0xff
	for index in range(body.size()): plain[index + 4] = body[index]
	var iv := Crypto.new().generate_random_bytes(16)
	var aes := AESContext.new()
	if aes.start(AESContext.MODE_CBC_ENCRYPT, _private_subkey(master_key, "aes-cbc"), iv) != OK: return ""
	var encrypted := aes.update(plain)
	aes.finish()
	if encrypted.size() != LEGACY_PRIVATE_SAVE_PLAIN_BYTES: return ""
	var authenticated := PackedByteArray()
	authenticated.append_array(iv)
	authenticated.append_array(encrypted)
	var mac := _private_save_mac(_private_subkey(master_key, "hmac-sha256"), binding, authenticated)
	if mac.size() != 32: return ""
	authenticated.append_array(mac)
	return Marshalls.raw_to_base64(authenticated) if authenticated.size() == LEGACY_PRIVATE_SAVE_BYTES else ""


static func new_authority_id() -> String:
	var value := Crypto.new().generate_random_bytes(32).hex_encode()
	return value if valid_authority_id(value) else ""


static func valid_authority_id(value: String) -> bool:
	var clean := value.strip_edges().to_lower()
	if clean.length() != 64: return false
	for code in clean.to_ascii_buffer():
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102): return false
	return true


# Stable, install-private join key for hidden consequences whose public carrier
# intentionally omits its original source identifier. The label is retained for
# host diagnostics; the identifying suffix cannot be recomputed from a run save.
static func private_reference(label: String, context: String) -> String:
	var master_key := _private_install_key()
	if master_key.size() != 32 or label.strip_edges().is_empty(): return ""
	var hmac := HMACContext.new()
	if hmac.start(HashingContext.HASH_SHA256, master_key) != OK: return ""
	if hmac.update(("bth06:private-reference:" + label + ":" + context).to_utf8_buffer()) != OK: return ""
	return "%s:%s" % [label, hmac.finish().hex_encode()]


static func normalize_private_payload(value: Variant, member_ids: Array, grievance_kinds: Array) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY: return {}
	var source: Dictionary = value
	if not _exact_keys(source, ["g", "q", "x"]): return {}
	var private_state := restore_state(source.get("x", {}), member_ids)
	if not can_restore_state(source.get("x", {}), member_ids): return {}
	var ledger_value: Variant = source.get("g", [])
	if typeof(ledger_value) != TYPE_ARRAY or (ledger_value as Array).size() > PRIVATE_GRIEVANCE_LIMIT: return {}
	var ledger: Array = []
	for row_value in ledger_value as Array:
		if typeof(row_value) != TYPE_ARRAY: return {}
		var row: Array = row_value
		if row.size() != 6: return {}
		var member_index := int(row[0])
		var kind_index := int(row[1])
		var weight := int(row[2])
		var turn_recorded := int(row[3])
		var id_hex := str(row[4])
		var source_hex := str(row[5])
		if member_index < 0 or member_index >= member_ids.size() or kind_index < 0 or kind_index >= grievance_kinds.size() \
				or weight < 1 or weight > PRIVATE_SEQUENCE_LIMIT or turn_recorded < 0 or turn_recorded > PRIVATE_SEQUENCE_LIMIT \
				or id_hex.is_empty() or not _bounded_hex_text(id_hex) or not _bounded_hex_text(source_hex):
			return {}
		ledger.append([member_index, kind_index, weight, turn_recorded, id_hex, source_hex])
	var sequence := int(source.get("q", -1))
	if sequence < ledger.size() or sequence > PRIVATE_SEQUENCE_LIMIT: return {}
	return {"x": private_state, "g": ledger, "q": sequence}


static func canonical_json(value: Variant) -> String:
	return JSON.stringify(_canonical(value))


static func _canonical(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY:
		var source: Dictionary = value
		var keys := source.keys(); keys.sort()
		var result: Dictionary = {}
		for key in keys: result[str(key)] = _canonical(source.get(key))
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for entry in value as Array: result.append(_canonical(entry))
		return result
	return value


static func _bounded_hex_text(value: String) -> bool:
	if value.length() % 2 != 0 or value.length() > PRIVATE_TEXT_BYTE_LIMIT * 2: return false
	for code in value.to_ascii_buffer():
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102): return false
	var decoded := value.hex_decode()
	return decoded.size() <= PRIVATE_TEXT_BYTE_LIMIT and decoded.get_string_from_utf8().to_utf8_buffer() == decoded


static func _private_subkey(master_key: PackedByteArray, label: String) -> PackedByteArray:
	var context := HMACContext.new()
	if context.start(HashingContext.HASH_SHA256, master_key) != OK: return PackedByteArray()
	if context.update(("bth06:crew-turn:kdf:" + label).to_utf8_buffer()) != OK: return PackedByteArray()
	return context.finish()


static func _private_save_mac(authentication_key: PackedByteArray, binding: String, authenticated: PackedByteArray) -> PackedByteArray:
	var context := HMACContext.new()
	if context.start(HashingContext.HASH_SHA256, authentication_key) != OK: return PackedByteArray()
	if context.update((binding + "\n").to_utf8_buffer()) != OK: return PackedByteArray()
	if context.update(authenticated) != OK: return PackedByteArray()
	return context.finish()


static func _constant_time_equal(first: PackedByteArray, second: PackedByteArray) -> bool:
	if first.size() != second.size(): return false
	var difference := 0
	for index in range(first.size()): difference |= int(first[index]) ^ int(second[index])
	return difference == 0


static func _private_install_key() -> PackedByteArray:
	if _private_key_cache.size() == 32: return _private_key_cache
	var absolute_path := ProjectSettings.globalize_path(PRIVATE_KEY_PATH)
	if FileAccess.file_exists(PRIVATE_KEY_PATH):
		var existing := FileAccess.get_file_as_bytes(PRIVATE_KEY_PATH)
		if existing.size() == 32:
			_private_key_cache = existing
			return _private_key_cache
	var generated := Crypto.new().generate_random_bytes(32)
	if generated.size() != 32: return PackedByteArray()
	var temporary_path := "%s.%d.%d.tmp" % [absolute_path, OS.get_process_id(), Time.get_ticks_usec()]
	var temporary := FileAccess.open(temporary_path, FileAccess.WRITE)
	if temporary == null: return PackedByteArray()
	temporary.store_buffer(generated)
	temporary.flush()
	temporary = null
	# Another process may win first creation. Never replace a valid host key.
	if FileAccess.file_exists(PRIVATE_KEY_PATH):
		DirAccess.remove_absolute(temporary_path)
		var raced := FileAccess.get_file_as_bytes(PRIVATE_KEY_PATH)
		if raced.size() != 32: return PackedByteArray()
		_private_key_cache = raced
		return _private_key_cache
	if DirAccess.rename_absolute(temporary_path, absolute_path) != OK:
		DirAccess.remove_absolute(temporary_path)
		return PackedByteArray()
	if OS.get_name() not in ["Windows", "Web"]:
		FileAccess.set_unix_permissions(absolute_path, 384)
	_private_key_cache = generated
	return _private_key_cache


static func eligible_members(plan_definition: Dictionary, met_members: Array, member_ids: Array) -> Array:
	var architects := _string_array(plan_definition.get("architects", []))
	var result: Array = []
	for member_value in met_members:
		var member_id := str(member_value)
		if member_ids.has(member_id) and member_id != MEMBER_ROOK and not architects.has(member_id) and not result.has(member_id):
			result.append(member_id)
	result.sort()
	return result


static func resolve(plan_definition: Dictionary, met_members: Array, ledgers: Array, member_ids: Array, tuning: Dictionary, rng: RngStream, escalation: int = 0) -> Dictionary:
	var state := empty_state()
	state["f"] = maxi(0, escalation)
	var eligible := eligible_members(plan_definition, met_members, member_ids)
	var weights := {}
	var total_weight := 0
	for member_id in eligible:
		var weight := 0
		for entry_value in ledgers:
			if typeof(entry_value) == TYPE_DICTIONARY and str((entry_value as Dictionary).get("member_id", "")) == member_id:
				weight += maxi(1, int((entry_value as Dictionary).get("weight", 1)))
		if weight > 0:
			weights[member_id] = weight
			total_weight += weight
	# Hidden guarantee: no eligible debt means no roll and no selected member.
	if total_weight <= 0:
		return state
	var per_weight := maxi(1, int(tuning.get("chance_percent_per_weight", 12)))
	var escalation_step := maxi(0, int(tuning.get("wrong_choice_chance_percent", 18)))
	var cap := clampi(int(tuning.get("chance_percent_cap", 72)), 1, 100)
	var chance := mini(cap, total_weight * per_weight + escalation * escalation_step)
	if rng.randi_range(1, 100) > chance:
		return state
	var roll := rng.randi_range(1, total_weight)
	var cursor := 0
	var ids: Array = weights.keys()
	ids.sort()
	for member_id in ids:
		cursor += int(weights.get(member_id, 0))
		if roll <= cursor:
			state["m"] = member_id
			break
	return state


static func witnessed_count(state_value: Variant, member_ids: Array) -> int:
	return _signal_array(normalize_state(state_value, member_ids).get("w", [])).size()


static func active_member(state_value: Variant, member_ids: Array) -> String:
	var state := normalize_state(state_value, member_ids)
	return "" if bool(state.get("c", false)) else str(state.get("m", ""))


static func mark_emitted(state_value: Variant, signal_id: String, witnessed: bool, member_ids: Array) -> Dictionary:
	var state := normalize_state(state_value, member_ids)
	if not SIGNAL_IDS.has(signal_id) or str(state.get("m", "")).is_empty() or bool(state.get("c", false)):
		return state
	var emitted := _signal_array(state.get("e", []))
	if not emitted.has(signal_id):
		emitted.append(signal_id)
	state["e"] = emitted
	if witnessed:
		var witnessed_ids := _signal_array(state.get("w", []))
		if not witnessed_ids.has(signal_id):
			witnessed_ids.append(signal_id)
		state["w"] = witnessed_ids
	return state


static func validate_tuning(tuning: Dictionary) -> Array:
	var failures: Array = []
	for key in ["chance_percent_per_weight", "chance_percent_cap", "wrong_choice_chance_percent", "crew_trust_cost", "hedge_trust_cost", "payment_shortfall_percent"]:
		if int(tuning.get(key, 0)) <= 0:
			failures.append("Hidden heist tuning %s must be positive." % key)
	var partial := _int_array(tuning.get("partial_haul_percent_band", []))
	if partial.size() != 2 or partial[0] <= 0 or partial[1] < partial[0] or partial[1] >= 100:
		failures.append("Hidden heist partial-haul band must contain two ascending percentages below 100.")
	return failures


static func _signal_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry_value in value:
		var signal_id := str(entry_value)
		if SIGNAL_IDS.has(signal_id) and not result.has(signal_id):
			result.append(signal_id)
	return result


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry_value in value:
			var text := str(entry_value).strip_edges()
			if not text.is_empty():
				result.append(text)
	return result


static func _int_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) == TYPE_ARRAY:
		for entry_value in value:
			result.append(int(entry_value))
	return result


static func _tombstone_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY: return result
	for row_value in value:
		if typeof(row_value) != TYPE_DICTIONARY: continue
		var row: Dictionary = row_value
		if not _exact_keys(row, ["b", "q"]) or int(row.get("b", -1)) < 0 or int(row.get("q", 0)) < 1 or int(row.get("q", 0)) > 99: continue
		result.append({"b": int(row.get("b", 0)), "q": int(row.get("q", 0))})
	while result.size() > TOMBSTONE_LIMIT: result.pop_front()
	return result


static func _exact_keys(value: Dictionary, expected: Array) -> bool:
	var keys := value.keys(); keys.sort()
	var exact := expected.duplicate(); exact.sort()
	return keys == exact


# WORLD06_6_PUBLIC_SURFACE_BEGIN
# These projections contain authored presentation only. The model cannot verify
# a live host observation or apply any resulting consequence at this boundary.
const PUBLIC_SURFACE_VERSION := 1
const PUBLIC_AUTHORITY_GAP := "host_observation_authority_unavailable"
const PUBLIC_PLAN_IDS := ["the_count", "the_whale_game"]


static func observable_signal_proposal(signal_id: String) -> Dictionary:
	var authored := {
		SIGNAL_PATTERN: {"surface_id": "table_rhythm_shift", "place_role": "table", "line": "A familiar rhythm lands wrong in the room."},
		SIGNAL_ROUTE: {"surface_id": "route_detail_shift", "place_role": "planning_table", "line": "A route detail does not match what the room remembers."},
		SIGNAL_PAYMENT: {"surface_id": "envelope_shortfall", "place_role": "planning_table", "line": "The envelope feels light against the posted figure."},
	}
	if not authored.has(signal_id):
		return {}
	var presentation: Dictionary = (authored.get(signal_id, {}) as Dictionary).duplicate(true)
	presentation["actor_roles"] = ["player", "crew_voice"]
	presentation["public_verbs"] = ["notice", "look", "continue"]
	return _public_proposal(presentation)


static func confrontation_surface_proposal(plan_id: String) -> Dictionary:
	if not PUBLIC_PLAN_IDS.has(plan_id):
		return {}
	return _public_proposal({
		"surface_id": "quiet_table_question",
		"place_role": "planning_table",
		"actor_roles": ["player", "crew_voice"],
		"line": "The room goes quiet enough for one careful question.",
		"public_verbs": ["press", "step_back", "change_role"],
	})


static func confrontation_aftermath_proposal(public_beat: String) -> Dictionary:
	var authored := {
		"right": {"beat_id": "crew_tightens", "line": "The answer comes clean. The crew closes ranks and carries a small edge forward.", "public_effect": "one_play_edge_pending_host"},
		"wrong": {"beat_id": "room_darkens", "line": "The question lands badly. The table goes cold around you.", "public_effect": "trust_cost_pending_host"},
		"hedge": {"beat_id": "role_shift", "line": "You quietly change your place in the plan and keep an exit within reach.", "public_effect": "partial_exit_pending_host"},
	}
	if not authored.has(public_beat):
		return {}
	return _public_proposal(authored.get(public_beat, {}))


static func plan_failure_beat_proposal(plan_id: String, failure_kind: String) -> Dictionary:
	var authored := {
		"the_count": {
			"fracture": {"beat_id": "corridor_break", "place_role": "corridor", "line": "The corridor folds before the exit opens."},
			"mechanical": {"beat_id": "floor_pressure", "place_role": "casino_floor", "line": "The floor play comes apart under the house's pressure."},
		},
		"the_whale_game": {
			"fracture": {"beat_id": "rig_exposure", "place_role": "high_limit_table", "line": "The house points at the rig before the cage clears."},
			"mechanical": {"beat_id": "name_break", "place_role": "cage_interview", "line": "The borrowed name breaks under the cage lights."},
		},
	}
	if not authored.has(plan_id) or not (authored.get(plan_id, {}) as Dictionary).has(failure_kind):
		return {}
	return _public_proposal((authored.get(plan_id, {}) as Dictionary).get(failure_kind, {}))


static func _public_proposal(authored_value: Variant) -> Dictionary:
	var authored: Dictionary = authored_value if typeof(authored_value) == TYPE_DICTIONARY else {}
	if authored.is_empty():
		return {}
	return {
		"schema_version": PUBLIC_SURFACE_VERSION,
		"authoritative": false,
		"proposal_only": true,
		"can_mutate": false,
		"authority_gap": PUBLIC_AUTHORITY_GAP,
		"presentation": authored.duplicate(true),
	}
