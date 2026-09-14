class_name SurfaceSfxManifest
extends RefCounted

const MANIFEST_PATH := "res://data/audio/surface_sfx_manifest.json"
const ALLOWED_BUS := "SFX"
const ALLOWED_STEAL_POLICY := "oldest_same_surface_then_oldest_global"
const MAX_VOICES := 10
const ENTRY_KEYS := ["id", "profile"]
const PROFILE_KEYS := [
	"bus", "max_voices", "steal_policy", "hidden_state_policy",
	"selection_seed_salt", "variation_pitch_steps",
	"variation_volume_db_steps", "motor_loop", "event_classes",
	"visual_counterparts",
]
const MOTOR_LOOP_KEYS := ["event_id", "idle_volume_db", "loaded_volume_db", "idle_pitch", "loaded_pitch"]
const FORBIDDEN_HIDDEN_TERMS := [
	"traitor", "grievance", "rigged", "future_draw", "hole_card",
	"unrevealed", "secret_outcome", "hidden_tell", "turn_state",
]


static func load_entries() -> Array:
	var source := FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(source)
	return parsed as Array if typeof(parsed) == TYPE_ARRAY else []


static func profile_map(entries: Array = []) -> Dictionary:
	var source := entries if not entries.is_empty() else load_entries()
	var result: Dictionary = {}
	for entry_value in source:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var profile_id := str(entry.get("id", "")).strip_edges()
		if not profile_id.is_empty() and not result.has(profile_id):
			result[profile_id] = _dict(entry.get("profile", {}))
	return result


static func resolve_profile(profile_id: String, entries: Array = []) -> Dictionary:
	var profiles := profile_map(entries)
	var clean_id := profile_id.strip_edges()
	if profiles.has(clean_id):
		return _dict(profiles.get(clean_id, {}))
	for candidate_value in profiles.keys():
		var candidate := str(candidate_value)
		if candidate.ends_with("*") and clean_id.begins_with(candidate.trim_suffix("*")):
			return _dict(profiles.get(candidate, {}))
	return {}


static func select_event(profile_id: String, event_class: String, selection_seed: int, occurrence: int, last_step: int = -1, entries: Array = []) -> Dictionary:
	var profile := resolve_profile(profile_id, entries)
	if profile.is_empty():
		return {}
	var classes := _dict(profile.get("event_classes", {}))
	var class_id := event_class.strip_edges()
	if not classes.has(class_id):
		return {}
	var event_id := str(classes.get(class_id, "")).strip_edges()
	if event_id.is_empty():
		return {}
	var pitch_steps := _float_array(profile.get("variation_pitch_steps", [0.0]))
	var volume_steps := _float_array(profile.get("variation_volume_db_steps", [0.0]))
	var step_count := maxi(1, maxi(pitch_steps.size(), volume_steps.size()))
	var selection_key := "%d|%s|%s|%s|%d" % [selection_seed, str(profile.get("selection_seed_salt", profile_id)), profile_id, class_id, maxi(0, occurrence)]
	var step := posmod(_stable_text_seed(selection_key), step_count)
	if step_count > 1 and step == last_step:
		step = (step + 1) % step_count
	return {
		"profile_id": profile_id,
		"event_class": class_id,
		"event_id": event_id,
		"occurrence": maxi(0, occurrence),
		"variation_step": step,
		"pitch_offset": pitch_steps[step % pitch_steps.size()] if not pitch_steps.is_empty() else 0.0,
		"volume_db_offset": volume_steps[step % volume_steps.size()] if not volume_steps.is_empty() else 0.0,
		"max_voices": clampi(int(profile.get("max_voices", MAX_VOICES)), 1, MAX_VOICES),
		"steal_policy": str(profile.get("steal_policy", ALLOWED_STEAL_POLICY)),
		"visual_counterpart": str(_dict(profile.get("visual_counterparts", {})).get(class_id, "")),
	}


static func voice_slot_decision(active_voices: Array, profile_id: String, max_voices: int, global_cap: int = MAX_VOICES) -> Dictionary:
	var active: Array[Dictionary] = []
	var same_profile: Array[Dictionary] = []
	for index in range(active_voices.size()):
		if typeof(active_voices[index]) != TYPE_DICTIONARY:
			continue
		var voice := (active_voices[index] as Dictionary).duplicate(false)
		voice["source_index"] = int(voice.get("source_index", index))
		active.append(voice)
		if not profile_id.is_empty() and str(voice.get("profile_id", "")) == profile_id:
			same_profile.append(voice)
	var by_age := func(a: Dictionary, b: Dictionary) -> bool:
		var serial_a := int(a.get("serial", 0))
		var serial_b := int(b.get("serial", 0))
		return serial_a < serial_b if serial_a != serial_b else int(a.get("source_index", 0)) < int(b.get("source_index", 0))
	if not profile_id.is_empty() and same_profile.size() >= clampi(max_voices, 1, maxi(1, global_cap)):
		same_profile.sort_custom(by_age)
		return {"kind": "steal_same_surface", "source_index": int(same_profile[0].get("source_index", -1))}
	if active.size() < maxi(1, global_cap):
		return {"kind": "allocate_idle", "source_index": -1}
	active.sort_custom(by_age)
	return {"kind": "steal_oldest_global", "source_index": int(active[0].get("source_index", -1))}


static func validation_errors(entries: Array = []) -> Array[String]:
	var source := entries if not entries.is_empty() else load_entries()
	var errors: Array[String] = []
	var seen: Dictionary = {}
	var wildcard_ids: Array[String] = []
	for index in range(source.size()):
		if typeof(source[index]) != TYPE_DICTIONARY:
			errors.append("entry %d is not a dictionary" % index)
			continue
		var entry: Dictionary = source[index]
		_append_unknown_key_errors(errors, entry, ENTRY_KEYS, "entry %d" % index)
		var profile_id := str(entry.get("id", "")).strip_edges()
		if profile_id.is_empty():
			errors.append("entry %d has no id" % index)
			continue
		if seen.has(profile_id):
			errors.append("duplicate profile %s" % profile_id)
			continue
		seen[profile_id] = true
		var profile := _dict(entry.get("profile", {}))
		if profile.is_empty():
			errors.append("%s has no profile dictionary" % profile_id)
			continue
		if not _safe_profile_id(profile_id):
			errors.append("%s is not a safe profile id" % profile_id)
		if profile_id.ends_with("*"):
			wildcard_ids.append(profile_id)
		_append_unknown_key_errors(errors, profile, PROFILE_KEYS, profile_id)
		if str(profile.get("bus", "")) != ALLOWED_BUS:
			errors.append("%s must use the SFX bus" % profile_id)
		var max_voices := int(profile.get("max_voices", 0))
		if max_voices < 1 or max_voices > MAX_VOICES:
			errors.append("%s max_voices must be in 1..%d" % [profile_id, MAX_VOICES])
		if str(profile.get("steal_policy", "")) != ALLOWED_STEAL_POLICY:
			errors.append("%s has an unsupported stealing policy" % profile_id)
		if str(profile.get("hidden_state_policy", "")) != "public_fact_or_transition_op_only":
			errors.append("%s must declare the public-only hidden-state policy" % profile_id)
		if str(profile.get("selection_seed_salt", "")).strip_edges().is_empty():
			errors.append("%s has no deterministic selection seed salt" % profile_id)
		var classes := _dict(profile.get("event_classes", {}))
		if classes.is_empty():
			errors.append("%s declares no event classes" % profile_id)
		var counterparts := _dict(profile.get("visual_counterparts", {}))
		for counterpart_value in counterparts.keys():
			if not classes.has(counterpart_value):
				errors.append("%s has unknown visual counterpart class %s" % [profile_id, str(counterpart_value)])
		for class_value in classes.keys():
			var class_id := str(class_value).strip_edges()
			var event_id := str(classes.get(class_value, "")).strip_edges()
			if class_id.is_empty() or event_id.is_empty():
				errors.append("%s contains an empty event class or event id" % profile_id)
				continue
			if not _safe_token(class_id) or not _safe_token(event_id):
				errors.append("%s.%s contains an unsafe class or event id" % [profile_id, class_id])
			if _contains_forbidden_term(class_id) or _contains_forbidden_term(event_id):
				errors.append("%s.%s names hidden state" % [profile_id, class_id])
			if str(counterparts.get(class_id, "")).strip_edges().is_empty():
				errors.append("%s.%s has no visual/text counterpart" % [profile_id, class_id])
		var pitch_value: Variant = profile.get("variation_pitch_steps", [])
		var volume_value: Variant = profile.get("variation_volume_db_steps", [])
		var pitch_steps := _float_array(pitch_value)
		var volume_steps := _float_array(volume_value)
		if pitch_steps.size() < 2 or volume_steps.size() < 2:
			errors.append("%s must declare at least two deterministic variation steps" % profile_id)
		if not _numeric_array(pitch_value) or not _numeric_array(volume_value):
			errors.append("%s variation steps must be finite numbers" % profile_id)
		for step in pitch_steps:
			if step < -0.25 or step > 0.25:
				errors.append("%s has an unsafe pitch variation" % profile_id)
		for step in volume_steps:
			if step < -6.0 or step > 3.0:
				errors.append("%s has an unsafe volume variation" % profile_id)
		var motor := _dict(profile.get("motor_loop", {}))
		if profile.has("motor_loop"):
			_append_unknown_key_errors(errors, motor, MOTOR_LOOP_KEYS, "%s.motor_loop" % profile_id)
			var motor_event := str(motor.get("event_id", "")).strip_edges()
			if motor_event.is_empty() or not _safe_token(motor_event):
				errors.append("%s has an unsafe or undeclared motor loop event" % profile_id)
	for left_index in range(wildcard_ids.size()):
		var left_prefix := wildcard_ids[left_index].trim_suffix("*")
		for right_index in range(left_index + 1, wildcard_ids.size()):
			var right_prefix := wildcard_ids[right_index].trim_suffix("*")
			if left_prefix.begins_with(right_prefix) or right_prefix.begins_with(left_prefix):
				errors.append("ambiguous wildcard profiles %s and %s" % [wildcard_ids[left_index], wildcard_ids[right_index]])
	return errors


static func _append_unknown_key_errors(errors: Array[String], record: Dictionary, allowed: Array, label: String) -> void:
	for key_value in record.keys():
		if not allowed.has(str(key_value)):
			errors.append("%s has unknown key %s" % [label, str(key_value)])


static func _safe_profile_id(value: String) -> bool:
	var clean := value.trim_suffix("*") if value.ends_with("*") else value
	return not clean.is_empty() and _safe_token(clean.trim_suffix(":")) \
		and value.count("*") <= 1 and (not value.contains("*") or value.ends_with("*"))


static func _safe_token(value: String) -> bool:
	if value.is_empty() or value.contains("/") or value.contains("\\") or value.contains("..") or value.contains(":"):
		return false
	for character in value:
		if not (character >= "a" and character <= "z") and not (character >= "0" and character <= "9") and character != "_":
			return false
	return true


static func _numeric_array(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	for entry in value:
		if typeof(entry) != TYPE_INT and typeof(entry) != TYPE_FLOAT:
			return false
		if not is_finite(float(entry)):
			return false
	return true


static func _contains_forbidden_term(value: String) -> bool:
	var normalized := value.to_lower()
	for term in FORBIDDEN_HIDDEN_TERMS:
		if normalized.contains(str(term)):
			return true
	return false


static func _stable_text_seed(value: String) -> int:
	var state := 2166136261
	for byte in value.to_utf8_buffer():
		state = int((state ^ int(byte)) * 16777619) & 0x7fffffff
	return maxi(1, state)


static func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


static func _float_array(value: Variant) -> Array[float]:
	var result: Array[float] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		result.append(float(entry))
	return result
