class_name CharacterRoster
extends RefCounted

# Resolves authored character pools into compact, save-safe speaker snapshots.
# Selection uses the run seed plus a stable crew/encounter identity, so UI
# refreshes and unrelated RNG consumption cannot reshuffle a known group.


static func resolve_speaker(
	speaker_value: Dictionary,
	library: ContentLibrary,
	run_state: RunState,
	encounter_id: String,
	fallback_line_key: String = ""
) -> Dictionary:
	var speaker := speaker_value.duplicate(true)
	if library == null:
		return speaker
	var pool_id := str(speaker.get("character_pool_id", "")).strip_edges()
	var direct_character_id := str(speaker.get("character_id", "")).strip_edges()
	var member_ids: Array = []
	var lineup_size := 1
	if not pool_id.is_empty():
		var pool := library.character_pool(pool_id)
		if pool.is_empty():
			return speaker
		member_ids = _string_array(pool.get("member_ids", []))
		lineup_size = clampi(int(pool.get("lineup_size", 1)), 1, member_ids.size())
	elif not direct_character_id.is_empty():
		if library.character(direct_character_id).is_empty():
			return speaker
		member_ids = [direct_character_id]
	else:
		return speaker
	var identity_key := str(speaker.get("character_identity_key", encounter_id)).strip_edges()
	if identity_key.is_empty():
		identity_key = pool_id if not pool_id.is_empty() else direct_character_id
	var roster_key := pool_id if not pool_id.is_empty() else direct_character_id
	var roster_stream := (
		"character_pool:%s:%s" % [roster_key, identity_key]
		if not pool_id.is_empty()
		else "character_direct:%s:%s" % [roster_key, identity_key]
	)
	var roster_rng := _stable_run_rng(run_state, roster_stream)
	var selected_ids := roster_rng.pick_many(member_ids, lineup_size)
	var members: Array = []
	for character_id_value in selected_ids:
		var character_id := str(character_id_value)
		var character := library.character(character_id)
		if character.is_empty():
			continue
		members.append(_member_snapshot(character))
	if members.is_empty():
		return speaker
	var line_key := str(speaker.get("voice_line_key", "")).strip_edges()
	if line_key.is_empty():
		line_key = fallback_line_key.strip_edges()
	var lead: Dictionary = members[0]
	var lead_definition := library.character(str(lead.get("character_id", "")))
	var voice_line := _voice_line(
		lead_definition,
		line_key,
		_stable_run_rng(run_state, "character_voice:%s:%s:%s" % [roster_key, identity_key, line_key])
	)
	speaker["character_pool_id"] = pool_id
	speaker["character_id"] = direct_character_id
	speaker["character_identity_key"] = identity_key
	speaker["members"] = members
	speaker["portrait_count"] = members.size()
	speaker["speaking_character_id"] = str(lead.get("character_id", ""))
	speaker["speaking_character_name"] = str(lead.get("display_name", ""))
	speaker["speaking_character_title"] = str(lead.get("title", ""))
	speaker["voice_line_key"] = line_key
	speaker["voice_line"] = voice_line
	speaker["encounter"] = _encounter_snapshot(lead_definition, line_key)
	speaker["lender_terms"] = _lender_terms_snapshot(lead_definition, library)
	return speaker


static func _member_snapshot(character: Dictionary) -> Dictionary:
	var model: Dictionary = character.get("model", {}) if typeof(character.get("model", {})) == TYPE_DICTIONARY else {}
	return {
		"character_id": str(character.get("id", "")).strip_edges(),
		"display_name": str(character.get("display_name", "")).strip_edges(),
		"title": str(character.get("title", "")).strip_edges(),
		"role": str(character.get("role", "character")).strip_edges(),
		"lender_id": str(character.get("lender_id", "")).strip_edges(),
		"model": {
			"skin_color": str(model.get("skin_color", "")).strip_edges(),
			"hair_color": str(model.get("hair_color", "")).strip_edges(),
			"jacket_color": str(model.get("jacket_color", "")).strip_edges(),
			"accent_color": str(model.get("accent_color", "")).strip_edges(),
			"silhouette": str(model.get("silhouette", "coat")).strip_edges(),
			"scale": clampf(float(model.get("scale", 1.0)), 0.75, 1.25),
		},
	}


static func _lender_terms_snapshot(character: Dictionary, library: ContentLibrary) -> Dictionary:
	var lender_id := str(character.get("lender_id", "")).strip_edges()
	if lender_id.is_empty() or library == null:
		return {}
	var lender := library.lender(lender_id)
	if lender.is_empty():
		return {}
	var profile: Dictionary = lender.get("debt_profile", {}) if typeof(lender.get("debt_profile", {})) == TYPE_DICTIONARY else {}
	return {
		"lender_id": lender_id,
		"display_name": str(lender.get("display_name", "")).strip_edges(),
		"loan_amount": int(profile.get("loan_amount", profile.get("principal_min", 0))),
		"principal_min": int(profile.get("principal_min", 0)),
		"principal_max": int(profile.get("principal_max", 0)),
		"interest_rate": float(profile.get("interest_rate", 0.0)),
		"deadline_turns": int(profile.get("deadline_turns", 0)),
		"favor_count": int(profile.get("favor_count", 0)),
		"default_consequence": str(profile.get("default_consequence", "")).strip_edges(),
	}


static func _voice_line(character: Dictionary, line_key: String, rng: RngStream) -> String:
	if character.is_empty() or line_key.is_empty():
		return ""
	var voice: Dictionary = character.get("voice", {}) if typeof(character.get("voice", {})) == TYPE_DICTIONARY else {}
	var lines: Dictionary = voice.get("lines", {}) if typeof(voice.get("lines", {})) == TYPE_DICTIONARY else {}
	var candidates := _string_array(lines.get(line_key, []))
	return str(rng.pick(candidates, "")) if not candidates.is_empty() else ""


static func _encounter_snapshot(character: Dictionary, context: String) -> Dictionary:
	if character.is_empty() or context.is_empty():
		return {}
	var encounters: Array = character.get("encounters", []) if typeof(character.get("encounters", [])) == TYPE_ARRAY else []
	for encounter_value in encounters:
		if typeof(encounter_value) != TYPE_DICTIONARY:
			continue
		var encounter: Dictionary = encounter_value
		if str(encounter.get("context", "")).strip_edges() == context:
			return encounter.duplicate(true)
	return {}


static func _stable_run_rng(run_state: RunState, stream_key: String) -> RngStream:
	var root := RngStream.new()
	var stable_seed := run_state.rng_seed if run_state != null else 1
	root.configure(stable_seed, stable_seed)
	return root.fork(stream_key)


static func _string_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var result: Array = []
	for entry_value in value as Array:
		var text := str(entry_value).strip_edges()
		if not text.is_empty():
			result.append(text)
	return result
