class_name MusicDeliveryIndex
extends RefCounted

# Canonical, allocation-at-import-time parser for authored music deliveries.
# Runtime playback consumes manifest entries produced from this index; it never
# scans music folders in a frame callback.

const DEFAULT_CLASSIFICATION_ALIASES := {
	"Chords": "pad",
	"Bass": "bass",
	"Lead": "lead",
	"DrumsLow": "drums_low",
	"DrumsHigh": "drums_high",
	"Tension": "tension",
	"Texture": "texture",
	"Fill": "fill",
	"Stinger": "stinger",
}


static func parse_filename(filename: String, classification_aliases: Dictionary = {}) -> Dictionary:
	var original := filename.strip_edges()
	if original.is_empty():
		return _failure(original, "filename is empty")
	if not original.to_lower().ends_with(".wav"):
		return _failure(original, "file extension must be .wav (case-insensitive)")
	var basename := original.left(original.length() - 4)
	var parts := basename.split("_", false)
	if parts.size() != 4:
		return _failure(original, "expected Environment_Classification_Instrument_PatternNumber.wav")
	var environment := str(parts[0]).strip_edges()
	var classification := str(parts[1]).strip_edges()
	var instrument := str(parts[2]).strip_edges()
	var pattern_text := str(parts[3]).strip_edges()
	if not _is_stable_token(environment):
		return _failure(original, "Environment must contain only letters and numbers")
	if not _is_stable_token(classification):
		return _failure(original, "Classification must contain only letters and numbers")
	if not _is_stable_token(instrument):
		return _failure(original, "Instrument must be a stable letters-and-numbers ID")
	if not pattern_text.is_valid_int() or int(pattern_text) <= 0:
		return _failure(original, "PatternNumber must be a positive integer")
	var aliases := DEFAULT_CLASSIFICATION_ALIASES.duplicate(true)
	for key_value in classification_aliases.keys():
		aliases[str(key_value)] = str(classification_aliases.get(key_value, "")).strip_edges()
	var canonical_classification := _matching_alias_key(classification, aliases)
	if canonical_classification.is_empty():
		return _failure(original, "unknown Classification '%s'" % classification)
	var role := str(aliases.get(canonical_classification, "")).strip_edges()
	if role.is_empty():
		return _failure(original, "Classification '%s' has an empty role mapping" % classification)
	var pattern_number := int(pattern_text)
	var semantic_id := "%s:%s:%s:%d" % [environment.to_lower(), role, instrument.to_lower(), pattern_number]
	return {
		"ok": true,
		"original_filename": original,
		"environment": environment,
		"classification": canonical_classification,
		"instrument": instrument,
		"pattern_number": pattern_number,
		"role": role,
		"kind": "one_shot" if role == "fill" or role == "stinger" else "loop_stem",
		"semantic_id": semantic_id,
		"variant_id": "%s_%s_%d" % [role, instrument.to_snake_case(), pattern_number],
		"error": "",
	}


static func build_index(track_id: String, declared_environment: String, filenames: Array, classification_aliases: Dictionary = {}) -> Dictionary:
	var entries: Array = []
	var errors: Array[String] = []
	var semantic_ids := {}
	var sorted_files := filenames.duplicate()
	sorted_files.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a).to_lower() < str(b).to_lower())
	for filename_value in sorted_files:
		var parsed := parse_filename(str(filename_value), classification_aliases)
		if not bool(parsed.get("ok", false)):
			errors.append("%s: %s" % [str(filename_value), str(parsed.get("error", "invalid filename"))])
			continue
		if not declared_environment.is_empty() and str(parsed.get("environment", "")).to_lower() != declared_environment.to_lower():
			errors.append("%s declares environment %s, but track %s requires %s" % [str(filename_value), str(parsed.get("environment", "")), track_id, declared_environment])
			continue
		var semantic_id := str(parsed.get("semantic_id", ""))
		if semantic_ids.has(semantic_id):
			errors.append("%s duplicates semantic ID %s already used by %s" % [str(filename_value), semantic_id, str(semantic_ids.get(semantic_id, ""))])
			continue
		semantic_ids[semantic_id] = str(filename_value)
		entries.append(parsed)
	return {
		"track_id": track_id,
		"declared_environment": declared_environment,
		"entries": entries,
		"errors": errors,
		"valid": errors.is_empty(),
		"proposed_manifest_entries": propose_manifest_entries(entries),
	}


static func scan_track_folder(track_id: String, declared_environment: String, root_path: String, classification_aliases: Dictionary = {}) -> Dictionary:
	var folder := root_path.path_join(track_id)
	var filenames: Array = []
	var directory := DirAccess.open(folder)
	if directory == null:
		return {
			"track_id": track_id,
			"declared_environment": declared_environment,
			"entries": [],
			"errors": ["unable to open authored music folder %s" % folder],
			"valid": false,
			"proposed_manifest_entries": [],
		}
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if not directory.current_is_dir() and name.to_lower().ends_with(".wav"):
			filenames.append(name)
		name = directory.get_next()
	directory.list_dir_end()
	return build_index(track_id, declared_environment, filenames, classification_aliases)


static func propose_manifest_entries(entries: Array) -> Array:
	var proposals: Array = []
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		proposals.append({
			"id": str(entry.get("variant_id", "")),
			"file": str(entry.get("original_filename", "")),
			"classification": str(entry.get("classification", "")),
			"role": str(entry.get("role", "")),
			"instrument": str(entry.get("instrument", "")),
			"pattern_number": int(entry.get("pattern_number", 0)),
			"weight": 1.0,
			"tags": [],
			"progression_compatibility": [],
			"harmonic_sections": [],
			"intensity_min": 0.0,
			"intensity_max": 1.0,
			"mutual_exclusion_group": "",
			"dsp_sends": {},
			"loop": str(entry.get("kind", "")) == "loop_stem",
		})
	return proposals


static func _matching_alias_key(classification: String, aliases: Dictionary) -> String:
	for key_value in aliases.keys():
		var key := str(key_value)
		if key.to_lower() == classification.to_lower():
			return key
	return ""


static func _is_stable_token(value: String) -> bool:
	if value.is_empty():
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 65 and code <= 90) and not (code >= 97 and code <= 122):
			return false
	return true


static func _failure(filename: String, reason: String) -> Dictionary:
	return {
		"ok": false,
		"original_filename": filename,
		"error": reason,
	}
