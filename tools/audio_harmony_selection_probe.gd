extends SceneTree

const Selector := preload("res://scripts/ui/music_arrangement_selector.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const PlayerScript := preload("res://scripts/ui/procedural_music_player.gd")
const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const MANIFEST_PATH := "res://data/audio/music_manifest.json"
const TRACK_ID := "jazz_club_delivery_fixture_8_bar"
const SEED_COUNT := 10
const SELECTIONS_PER_SEED := 500


func _initialize() -> void:
	var failures: Array[String] = []
	var entry := _track_entry()
	if entry.is_empty():
		failures.append("Jazz harmony fixture is missing.")
		_finish(failures, {})
		return
	var recipe := Selector.recipe_definition(entry)
	var sections: Array = recipe.get("sections", []) as Array
	var expected := ["A", "A", "B", "A", "A", "A", "C", "A"]
	if sections != expected:
		failures.append("Recipe does not encode AABA then AACA exactly.")
	_check_incompatible_fixture(entry, failures)
	var canonical := {"seeds": [], "selection_count": 0, "set_counts": {}, "variant_counts": {}}
	for seed_index in range(SEED_COUNT):
		var run := RunStateScript.new()
		run.start_new("AUDIO-HARMONY-%02d" % seed_index)
		run.set_environment({"id": "jazz_probe", "archetype_id": "jazz_club", "music_profile": {"authored_track_id": TRACK_ID}})
		run.ensure_music_arrangement_state(TRACK_ID, str(recipe.get("id", "")), "A")
		var seed_sections: Array[String] = []
		var first_a_pad := ""
		var retained_a_pad := ""
		var changed_a_pad := ""
		var last_a_pad := ""
		var transcript: Array = []
		for selection_index in range(SELECTIONS_PER_SEED):
			var state := run.music_arrangement_state.duplicate(true)
			if selection_index > 0:
				var phrase_index := selection_index - 1
				state = run.advance_music_arrangement_phrase(TRACK_ID, str(recipe.get("id", "")), sections, {"phrase_event_index": phrase_index, "event_token": "%d:%d" % [seed_index, phrase_index]}, recipe.get("role_policies", {}) as Dictionary)
				if not bool(state.get("event_accepted", false)):
					failures.append("Ordered phrase event was rejected at seed %d selection %d." % [seed_index, selection_index])
					break
			if selection_index < 8:
				seed_sections.append(str(state.get("harmonic_section", "")))
			var selection := Selector.select(entry, {"environment_id": "jazz_probe"}, {"run_seed": run.seed_value, "music_visit_id": str(state.get("visit_id", "")), "music_arrangement_state": state, "heat": (selection_index * 17) % 101})
			_validate_selection(selection, failures, seed_index, selection_index)
			var set_id := str(selection.get("compatibility_set_id", ""))
			canonical["set_counts"][set_id] = int(canonical["set_counts"].get(set_id, 0)) + 1
			var selected_variants: Dictionary = selection.get("selected_variants", {}) as Dictionary
			var selected_pad_id := str((selected_variants.get("pad", {}) as Dictionary).get("id", ""))
			transcript.append({
				"section": str(state.get("harmonic_section", "")),
				"set": set_id,
				"progression": str(selection.get("progression_id", "")),
				"roles": _selected_role_ids(selected_variants),
				"cursor": int(state.get("cursor", -1)),
				"event_index": int(state.get("last_phrase_event_index", -1)),
			})
			if set_id == "jazz_c_instrument_contrast" and (last_a_pad.is_empty() or selected_pad_id == last_a_pad):
				failures.append("C did not contrast with the immediately preceding A pad at seed %d selection %d." % [seed_index, selection_index])
			if set_id == "jazz_a_1":
				last_a_pad = selected_pad_id
			for role_value in selected_variants.keys():
				var variant_id := str((selected_variants.get(role_value, {}) as Dictionary).get("id", ""))
				canonical["variant_counts"][variant_id] = int(canonical["variant_counts"].get(variant_id, 0)) + 1
			if seed_index == 0 and set_id == "jazz_a_1":
				var pad_id := str((selected_variants.get("pad", {}) as Dictionary).get("id", ""))
				if selection_index == 0:
					first_a_pad = pad_id
				elif selection_index == 1:
					retained_a_pad = pad_id
				elif selection_index == 4:
					changed_a_pad = pad_id
			run.remember_music_arrangement_selection(TRACK_ID, selection.get("selection_memory_ids", {}) as Dictionary, selection.get("selection_memory_epochs", {}) as Dictionary)
			canonical["selection_count"] = int(canonical.get("selection_count", 0)) + 1
		if seed_sections != expected:
			failures.append("Seed %d phrase events produced %s, expected %s." % [seed_index, seed_sections, expected])
		if seed_index == 0 and (first_a_pad.is_empty() or retained_a_pad != first_a_pad or changed_a_pad == first_a_pad):
			failures.append("Pad retention/change epoch contract failed: %s/%s/%s." % [first_a_pad, retained_a_pad, changed_a_pad])
		var restored := RunStateScript.new()
		restored.from_dict(run.to_dict())
		if JSON.stringify(restored.music_arrangement_state) != JSON.stringify(run.music_arrangement_state):
			failures.append("Music arrangement state did not survive RunState round-trip for seed %d." % seed_index)
		var transcript_json := JSON.stringify(transcript)
		canonical["seeds"].append({
			"seed": seed_index,
			"cursor": int(run.music_arrangement_state.get("cursor", -1)),
			"section": str(run.music_arrangement_state.get("harmonic_section", "")),
			"transcript": transcript,
			"transcript_digest": transcript_json.sha256_text(),
		})
	_check_event_idempotence(entry, recipe, failures)
	_check_mid_cycle_resume(entry, recipe, failures)
	_check_integrated_foundation_save_restore(entry, recipe, failures)
	_check_tag_exclusion_contracts(failures)
	_check_mix_normalization(failures)
	await _check_player_phrase_timing(recipe, failures)
	_finish(failures, canonical)


func _selected_role_ids(selected_variants: Dictionary) -> Dictionary:
	var ids := {}
	var roles := selected_variants.keys()
	roles.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for role_value in roles:
		ids[str(role_value)] = str((selected_variants.get(role_value, {}) as Dictionary).get("id", ""))
	return ids


func _check_incompatible_fixture(entry: Dictionary, failures: Array[String]) -> void:
	var bass_bank: Dictionary = (entry.get("stem_banks", {}) as Dictionary).get("bass", {}) as Dictionary
	var incompatible_file := ""
	for variant_value in bass_bank.get("variants", []) as Array:
		if typeof(variant_value) == TYPE_DICTIONARY and str((variant_value as Dictionary).get("id", "")) == "jazz_bass_incompatible":
			incompatible_file = str((variant_value as Dictionary).get("file", ""))
			break
	if incompatible_file != "JazzClub_Bass_UprightBass_3.wav":
		failures.append("Intentionally incompatible bass is not isolated in its own Pattern 3 fixture.")
		return
	var root := "res://assets/audio/music/%s" % TRACK_ID
	var incompatible_bytes := FileAccess.get_file_as_bytes("%s/%s" % [root, incompatible_file])
	var a_bytes := FileAccess.get_file_as_bytes("%s/JazzClub_Bass_UprightBass_1.wav" % root)
	var b_bytes := FileAccess.get_file_as_bytes("%s/JazzClub_Bass_UprightBass_2.wav" % root)
	if incompatible_bytes.is_empty() or incompatible_bytes == a_bytes or incompatible_bytes == b_bytes:
		failures.append("Pattern 3 incompatible bass fixture is missing or duplicates a compatible synchronized bass file.")


func _validate_selection(selection: Dictionary, failures: Array[String], seed_index: int, selection_index: int) -> void:
	if not bool(selection.get("valid", false)):
		failures.append("Invalid selection at seed %d selection %d: %s" % [seed_index, selection_index, str(selection.get("failure_reason", ""))])
		return
	var variants: Dictionary = selection.get("selected_variants", {}) as Dictionary
	for role in ["pad", "bass"]:
		if not variants.has(role):
			failures.append("Required role %s missing at seed %d selection %d." % [role, seed_index, selection_index])
	var bass_id := str((variants.get("bass", {}) as Dictionary).get("id", ""))
	if bass_id == "jazz_bass_incompatible":
		failures.append("Incompatible bass was selected at seed %d selection %d." % [seed_index, selection_index])
	for role_value in (selection.get("stems", {}) as Dictionary).keys():
		var stem_id := str(((selection.get("stems", {}) as Dictionary).get(role_value, {}) as Dictionary).get("id", ""))
		if ["jazz_chords_piano_1", "jazz_bass_upright_1", "jazz_lead_trumpet_1", "jazz_drums_high_brush_1"].has(stem_id):
			failures.append("Base stem bypassed compatibility set at seed %d selection %d." % [seed_index, selection_index])
	var progression_id := str(selection.get("progression_id", ""))
	for role in ["pad", "bass"]:
		var selected_stem: Dictionary = (selection.get("stems", {}) as Dictionary).get(role, {}) as Dictionary
		if not (selected_stem.get("progression_compatibility", []) as Array).has(progression_id):
			failures.append("Selected %s does not match progression %s." % [role, progression_id])
	if str(selection.get("compatibility_set_id", "")) == "jazz_c_instrument_contrast" and (progression_id != "jazz_a_1" or bass_id != "jazz_bass_a"):
		failures.append("C contrast did not preserve A progression/root bass.")
	if str(selection.get("compatibility_set_id", "")) == "jazz_a_1":
		var found_incompatible_reason := false
		for exclusion_value in selection.get("excluded_candidates", []) as Array:
			var exclusion: Dictionary = exclusion_value as Dictionary
			if str(exclusion.get("id", "")) == "jazz_bass_incompatible" and (exclusion.get("reasons", []) as Array).has("progression_incompatible"):
				found_incompatible_reason = true
		if not found_incompatible_reason:
			failures.append("Diagnostics did not explain exclusion of the incompatible bass.")


func _check_event_idempotence(entry: Dictionary, recipe: Dictionary, failures: Array[String]) -> void:
	var state := Selector.initial_recipe_state(entry, 7, "visit")
	state = Selector.advance_recipe_state(entry, state, {"phrase_event_index": 0, "event_token": "zero"})
	var duplicate := Selector.advance_recipe_state(entry, state, {"phrase_event_index": 0, "event_token": "zero"})
	var skipped := Selector.advance_recipe_state(entry, state, {"phrase_event_index": 2, "event_token": "two"})
	if bool(duplicate.get("event_accepted", true)) or bool(skipped.get("event_accepted", true)) or int(duplicate.get("cursor", -2)) != int(state.get("cursor", -1)) or int(skipped.get("cursor", -2)) != int(state.get("cursor", -1)):
		failures.append("Duplicate/out-of-order phrase events were not idempotent.")
	var run := RunStateScript.new()
	run.start_new("IDEMPOTENCE")
	run.set_environment({"id": "jazz_probe"})
	run.ensure_music_arrangement_state(TRACK_ID, str(recipe.get("id", "")), "A")
	var accepted := run.advance_music_arrangement_phrase(TRACK_ID, str(recipe.get("id", "")), recipe.get("sections", []) as Array, {"phrase_event_index": 0, "event_token": "zero"}, recipe.get("role_policies", {}) as Dictionary)
	var run_duplicate := run.advance_music_arrangement_phrase(TRACK_ID, str(recipe.get("id", "")), recipe.get("sections", []) as Array, {"phrase_event_index": 0, "event_token": "zero"}, recipe.get("role_policies", {}) as Dictionary)
	var run_skipped := run.advance_music_arrangement_phrase(TRACK_ID, str(recipe.get("id", "")), recipe.get("sections", []) as Array, {"phrase_event_index": 2, "event_token": "two"}, recipe.get("role_policies", {}) as Dictionary)
	if not bool(accepted.get("event_accepted", false)) or bool(run_duplicate.get("event_accepted", true)) or bool(run_skipped.get("event_accepted", true)) or int(run.music_arrangement_state.get("cursor", -1)) != 1:
		failures.append("RunState duplicate/out-of-order phrase events were not idempotent.")


func _check_mid_cycle_resume(entry: Dictionary, recipe: Dictionary, failures: Array[String]) -> void:
	var uninterrupted := RunStateScript.new()
	uninterrupted.start_new("MID-CYCLE")
	uninterrupted.set_environment({"id": "jazz_probe"})
	uninterrupted.ensure_music_arrangement_state(TRACK_ID, str(recipe.get("id", "")), "A")
	for event_index in range(4):
		var state := uninterrupted.advance_music_arrangement_phrase(TRACK_ID, str(recipe.get("id", "")), recipe.get("sections", []) as Array, {"phrase_event_index": event_index, "event_token": "mid:%d" % event_index}, recipe.get("role_policies", {}) as Dictionary)
		var selection := Selector.select(entry, {"environment_id": "jazz_probe"}, {"run_seed": uninterrupted.seed_value, "music_visit_id": str(state.get("visit_id", "")), "music_arrangement_state": state})
		uninterrupted.remember_music_arrangement_selection(TRACK_ID, selection.get("selection_memory_ids", {}) as Dictionary, selection.get("selection_memory_epochs", {}) as Dictionary)
	var restored := RunStateScript.new()
	restored.from_dict(uninterrupted.to_dict())
	var next_event := {"phrase_event_index": 4, "event_token": "mid:4"}
	var uninterrupted_state := uninterrupted.advance_music_arrangement_phrase(TRACK_ID, str(recipe.get("id", "")), recipe.get("sections", []) as Array, next_event, recipe.get("role_policies", {}) as Dictionary)
	var restored_state := restored.advance_music_arrangement_phrase(TRACK_ID, str(recipe.get("id", "")), recipe.get("sections", []) as Array, next_event, recipe.get("role_policies", {}) as Dictionary)
	var uninterrupted_selection := Selector.select(entry, {"environment_id": "jazz_probe"}, {"run_seed": uninterrupted.seed_value, "music_visit_id": str(uninterrupted_state.get("visit_id", "")), "music_arrangement_state": uninterrupted_state})
	var restored_selection := Selector.select(entry, {"environment_id": "jazz_probe"}, {"run_seed": restored.seed_value, "music_visit_id": str(restored_state.get("visit_id", "")), "music_arrangement_state": restored_state})
	if str(uninterrupted_state.get("harmonic_section", "")) != str(restored_state.get("harmonic_section", "")) or JSON.stringify(uninterrupted_selection.get("selected_variants", {})) != JSON.stringify(restored_selection.get("selected_variants", {})):
		failures.append("Mid-cycle save/load did not resume with the same next phrase and selected variants.")


func _check_integrated_foundation_save_restore(entry: Dictionary, recipe: Dictionary, failures: Array[String]) -> void:
	var environment := {"id": "jazz_integrated", "archetype_id": "jazz_club", "music_profile": {"authored_track_id": TRACK_ID}}
	var uninterrupted := RunStateScript.new()
	uninterrupted.start_new("FOUNDATION-SAVE-RESTORE")
	uninterrupted.set_environment(environment)
	uninterrupted.ensure_music_arrangement_state(TRACK_ID, str(recipe.get("id", "")), "A")
	var uninterrupted_session := _foundation_session(entry, uninterrupted)
	var uninterrupted_foundation: Object = uninterrupted_session.get("foundation")
	var uninterrupted_player: Object = uninterrupted_session.get("player")
	uninterrupted_player.call("music_stem_manifest_snapshot_for_environment", environment, 0, uninterrupted_foundation.call("music_fx_state_snapshot"))
	for event_index in range(5):
		uninterrupted_player.emit_signal("authored_phrase_event", {
			"track_id": TRACK_ID,
			"recipe_id": str(recipe.get("id", "")),
			"phrase_event_index": event_index,
			"event_token": "integrated:%d" % event_index,
			"phrase_slot": event_index + 1,
			"current_bar": (event_index + 1) * int(recipe.get("phrase_bars", 4)),
		})
		# Headless playback intentionally does not start audio, so ask the public
		# manifest surface for the phrase contract; its selection signal is the
		# same one Foundation uses to persist compact role memory.
		uninterrupted_player.call("music_stem_manifest_snapshot_for_environment", environment, 0, uninterrupted_foundation.call("music_fx_state_snapshot"))
	var saved_state := uninterrupted.music_arrangement_state.duplicate(true)
	var saved_a_pad := str((saved_state.get("selected_variant_ids", {}) as Dictionary).get("jazz_a_1:pad", ""))
	if int(saved_state.get("cursor", -1)) != 5 or int(saved_state.get("phrase_slot", -1)) != 5 or saved_a_pad.is_empty():
		failures.append("Integrated Foundation setup was not saved immediately before C with phrase slot and A instrument memory intact.")
	var serialized := JSON.stringify(uninterrupted.to_dict())
	var parsed: Variant = JSON.parse_string(serialized)
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("Integrated RunState JSON serialization did not produce a dictionary.")
		_free_foundation_session(uninterrupted_session)
		return
	var restored := RunStateScript.new()
	restored.from_dict(parsed as Dictionary)
	if JSON.stringify(restored.music_arrangement_state) != JSON.stringify(saved_state):
		failures.append("Integrated RunState JSON restore lost selection memory or phrase-slot state before C: saved=%s restored=%s." % [JSON.stringify(saved_state), JSON.stringify(restored.music_arrangement_state)])
	var restored_session := _foundation_session(entry, restored)
	var restored_foundation: Object = restored_session.get("foundation")
	var restored_player: Object = restored_session.get("player")
	restored_player.call("sync_authored_arrangement_state", restored.music_arrangement_state)
	if JSON.stringify(restored_player.get("_pending_authored_arrangement_restore")) != JSON.stringify(restored.music_arrangement_state):
		failures.append("Player sync did not receive the exact restored Foundation arrangement state.")
	var next_event := {
		"track_id": TRACK_ID,
		"recipe_id": str(recipe.get("id", "")),
		"phrase_event_index": 5,
		"event_token": "integrated:5",
		"phrase_slot": 6,
		"current_bar": 6 * int(recipe.get("phrase_bars", 4)),
	}
	uninterrupted_player.emit_signal("authored_phrase_event", next_event)
	restored_player.emit_signal("authored_phrase_event", next_event)
	var uninterrupted_manifest: Dictionary = uninterrupted_player.call("music_stem_manifest_snapshot_for_environment", environment, 0, uninterrupted_foundation.call("music_fx_state_snapshot"))
	var restored_manifest: Dictionary = restored_player.call("music_stem_manifest_snapshot_for_environment", environment, 0, restored_foundation.call("music_fx_state_snapshot"))
	var uninterrupted_variants := uninterrupted_manifest.get("selected_variants", {}) as Dictionary
	var restored_variants := restored_manifest.get("selected_variants", {}) as Dictionary
	var restored_c_pad := str((restored_variants.get("pad", {}) as Dictionary).get("id", ""))
	if str(restored.music_arrangement_state.get("harmonic_section", "")) != "C" or int(restored.music_arrangement_state.get("phrase_slot", -1)) != 6:
		failures.append("Integrated Foundation/player restore did not advance to the saved run's next C phrase and slot.")
	if JSON.stringify(uninterrupted.music_arrangement_state) != JSON.stringify(restored.music_arrangement_state) or JSON.stringify(uninterrupted_variants) != JSON.stringify(restored_variants):
		failures.append("Integrated Foundation/player restore diverged from uninterrupted C continuation: live_state=%s restored_state=%s live_variants=%s restored_variants=%s." % [JSON.stringify(uninterrupted.music_arrangement_state), JSON.stringify(restored.music_arrangement_state), JSON.stringify(uninterrupted_variants), JSON.stringify(restored_variants)])
	if restored_c_pad.is_empty() or restored_c_pad == saved_a_pad:
		failures.append("Restored C continuation did not force the authored pad-instrument contrast against the saved A memory.")
	if str(restored_manifest.get("compatibility_set_id", "")) != "jazz_c_instrument_contrast" or str(restored_manifest.get("progression_id", "")) != "jazz_a_1":
		failures.append("Integrated restored snapshot did not expose the C compatibility set and preserved A progression.")
	if str(restored_manifest.get("recipe_id", "")) != str(recipe.get("id", "")) or int(restored_manifest.get("cycle_index", -1)) != 0 or int(restored_manifest.get("phrase_index", -1)) != 6 or restored_variants.is_empty() or (restored_manifest.get("excluded_candidates", []) as Array).is_empty():
		failures.append("Public music stem manifest snapshot did not expose recipe, cycle, phrase, chosen variants, and exclusions together.")
	_free_foundation_session(uninterrupted_session)
	_free_foundation_session(restored_session)


func _foundation_session(entry: Dictionary, run: Object) -> Dictionary:
	var library := ContentLibraryScript.new()
	library.music_tracks = [entry.duplicate(true)]
	library.call("_rebuild_indexes")
	var player := PlayerScript.new()
	var foundation := FoundationMainScript.new()
	foundation.set("library", library)
	foundation.set("run_state", run)
	foundation.set("procedural_music_player", player)
	foundation.set("current_screen", "ENVIRONMENT")
	player.authored_phrase_event.connect(Callable(foundation, "_on_authored_music_phrase_event"))
	player.authored_arrangement_selected.connect(Callable(foundation, "_on_authored_music_arrangement_selected"))
	return {"foundation": foundation, "player": player, "library": library}


func _free_foundation_session(session: Dictionary) -> void:
	var player: Object = session.get("player")
	var foundation: Object = session.get("foundation")
	if player != null:
		player.free()
	if foundation != null:
		foundation.free()


func _check_tag_exclusion_contracts(failures: Array[String]) -> void:
	var progression := "tag_progression"
	var banks := {
		"bass": {"variants": [{"id": "bass_anchor", "weight": 1, "tags": ["anchor"], "mutual_exclusion_group": "shared_voice", "harmonic_sections": ["A"], "progression_compatibility": [progression]}]},
		"lead": {"variants": [
			{"id": "lead_missing_tag", "weight": 99, "requires_tags": ["never_present"], "harmonic_sections": ["A"], "progression_compatibility": [progression]},
			{"id": "lead_requires_anchor", "weight": 1, "requires_tags": ["anchor"], "harmonic_sections": ["A"], "progression_compatibility": [progression]},
		]},
		"pad": {"variants": [
			{"id": "pad_excluded_id", "weight": 99, "exclude_ids": ["bass_anchor"], "harmonic_sections": ["A"], "progression_compatibility": [progression]},
			{"id": "pad_allowed", "weight": 1, "harmonic_sections": ["A"], "progression_compatibility": [progression]},
		]},
		"tension": {"variants": [
			{"id": "tension_excluded_tag", "weight": 99, "exclude_tags": ["anchor"], "harmonic_sections": ["A"], "progression_compatibility": [progression]},
			{"id": "tension_allowed", "weight": 1, "harmonic_sections": ["A"], "progression_compatibility": [progression]},
		]},
		"texture": {"variants": [
			{"id": "texture_mutual_block", "weight": 99, "mutual_exclusion_group": "shared_voice", "harmonic_sections": ["A"], "progression_compatibility": [progression]},
			{"id": "texture_allowed", "weight": 1, "harmonic_sections": ["A"], "progression_compatibility": [progression]},
		]},
	}
	var role_ids := {
		"bass": ["bass_anchor"],
		"lead": ["lead_missing_tag", "lead_requires_anchor"],
		"pad": ["pad_excluded_id", "pad_allowed"],
		"tension": ["tension_excluded_tag", "tension_allowed"],
		"texture": ["texture_mutual_block", "texture_allowed"],
	}
	var compatibility_entry := {
		"id": "compatibility_tag_probe",
		"arrangement_recipes": [{"id": "tag_recipe", "sections": ["A"], "phrase_bars": 4}],
		"compatibility_required_roles": ["bass", "lead", "pad", "tension", "texture"],
		"compatibility_sets": [{"id": "tag_set", "progression_id": progression, "key": "C_major", "harmonic_sections": ["A"], "roles": role_ids}],
		"stem_banks": banks,
	}
	var state := Selector.initial_recipe_state(compatibility_entry, "TAG-SEED", "tag-visit")
	var compatibility := Selector.select(compatibility_entry, {"environment_id": "tag_probe"}, {"run_seed": "TAG-SEED", "music_visit_id": "tag-visit", "music_arrangement_state": state})
	_assert_tag_selection("compatibility", compatibility, failures)
	for expected in [
		{"id": "lead_missing_tag", "reason": "missing_tag:never_present"},
		{"id": "pad_excluded_id", "reason": "excluded_id:bass_anchor"},
		{"id": "tension_excluded_tag", "reason": "excluded_tag:anchor"},
		{"id": "texture_mutual_block", "reason": "mutual_exclusion_group:shared_voice"},
	]:
		if not _exclusion_has(compatibility.get("excluded_candidates", []) as Array, str(expected.get("id", "")), str(expected.get("reason", ""))):
			failures.append("Compatibility selector diagnostics missed %s for %s." % [str(expected.get("reason", "")), str(expected.get("id", ""))])
	var legacy_entry := {"id": "legacy_tag_probe", "arrangement": ["A"], "stems": {}, "stem_banks": banks}
	var legacy := Selector.select(legacy_entry, {"environment_id": "tag_probe"}, {"harmonic_section": "A"})
	_assert_tag_selection("legacy", legacy, failures)


func _assert_tag_selection(path_name: String, selection: Dictionary, failures: Array[String]) -> void:
	var actual := _selected_role_ids(selection.get("selected_variants", {}) as Dictionary)
	var expected := {"bass": "bass_anchor", "lead": "lead_requires_anchor", "pad": "pad_allowed", "tension": "tension_allowed", "texture": "texture_allowed"}
	if JSON.stringify(actual) != JSON.stringify(expected):
		failures.append("%s selector did not preserve requires_tags, ID/tag exclusions, and mutual exclusion: %s." % [path_name, JSON.stringify(actual)])


func _exclusion_has(exclusions: Array, candidate_id: String, reason: String) -> bool:
	for exclusion_value in exclusions:
		if typeof(exclusion_value) != TYPE_DICTIONARY:
			continue
		var exclusion := exclusion_value as Dictionary
		if str(exclusion.get("id", "")) == candidate_id and (exclusion.get("reasons", []) as Array).has(reason):
			return true
	return false


func _check_mix_normalization(failures: Array[String]) -> void:
	var player := PlayerScript.new()
	var arrangement := {"recipe_id": "jazz_aaba_aaca", "cursor": 6, "selected_variant_ids": {"jazz_a_1:pad": "jazz_chords_a_guitar"}}
	var normalized: Dictionary = player.call("_normalize_music_mix_input", {"run_seed": 9, "music_visit_id": "visit", "music_arrangement_state": arrangement})
	if str(normalized.get("run_seed", "")) != "9" or str(normalized.get("music_visit_id", "")) != "visit" or JSON.stringify(normalized.get("music_arrangement_state", {})) != JSON.stringify(arrangement):
		failures.append("Music mix normalization dropped recipe/save fields.")
	player.free()


func _check_player_phrase_timing(recipe: Dictionary, failures: Array[String]) -> void:
	var player := PlayerScript.new()
	root.add_child(player)
	# AudioStreamPlayer playback is only valid after the owning director has
	# completed one scene-tree frame. Waiting here keeps this acceptance probe
	# aligned with real runtime startup and prevents false engine errors.
	await process_frame
	var stem_player := AudioStreamPlayer.new()
	player.add_child(stem_player)
	player.set("_stem_players", {"pad": stem_player})
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = PackedByteArray([0, 0, 0, 0])
	var boundary_contract: Dictionary = player.call("_stem_set_contract", "authored", {"pad": wav}, 120.0, 8, 705600, "timing", {}, "full")
	boundary_contract["track_id"] = TRACK_ID
	boundary_contract["selection_key"] = "B"
	boundary_contract["sample_rate"] = 44100
	boundary_contract["harmony_recipe_id"] = str(recipe.get("id", ""))
	boundary_contract["harmony_phrase_bars"] = 4
	boundary_contract["harmony_recipe_length"] = 8
	boundary_contract["harmony_visit_id"] = "timing_visit"
	boundary_contract["harmony_last_phrase_event_index"] = -1
	var events: Array = []
	player.authored_phrase_event.connect(func(event: Dictionary) -> void:
		events.append(event.duplicate(true))
		if int(event.get("phrase_event_index", -1)) == 1:
			player.call("_accept_authored_boundary_stem_set", "selection:B", boundary_contract)
	)
	player.set("_current_stem_set", boundary_contract.duplicate(true))
	player.sync_authored_arrangement_state({"track_id": TRACK_ID, "visit_id": "timing_visit", "last_phrase_event_index": -1})
	for ignored_frame in range(100):
		player.call("_emit_harmony_phrase_boundaries", TRACK_ID, 0, 0)
	if not events.is_empty():
		failures.append("Repeated frames at the same musical position emitted phrase events.")
	player.call("_emit_harmony_phrase_boundaries", TRACK_ID, 1, 4)
	player.call("_emit_harmony_phrase_boundaries", TRACK_ID, 0, 0)
	if events.size() != 2 or int((events[0] as Dictionary).get("phrase_event_index", -1)) != 0 or int((events[1] as Dictionary).get("phrase_event_index", -1)) != 1:
		failures.append("Player phrase timing did not emit one ordered event per crossed boundary.")
	else:
		var state := Selector.initial_recipe_state({"id": TRACK_ID, "arrangement_recipes": [recipe]}, 1, "timing_visit")
		state = Selector.advance_recipe_state({"id": TRACK_ID, "arrangement_recipes": [recipe]}, state, events[0] as Dictionary)
		state = Selector.advance_recipe_state({"id": TRACK_ID, "arrangement_recipes": [recipe]}, state, events[1] as Dictionary)
		if str(state.get("harmonic_section", "")) != "B":
			failures.append("Player boundary timing introduced an extra A before B.")
	if str(player.debug_soak_snapshot().get("last_authored_boundary_applied_cache_key", "")) != "selection:B":
		failures.append("Player did not apply the B selection at the boundary that emitted it.")
	if str(player.get("_current_cache_key")) != "selection:B" or str((player.get("_current_stem_set") as Dictionary).get("selection_key", "")) != "B" or not is_equal_approx(float((player.get("_current_stem_set") as Dictionary).get("started_position", -1.0)), 0.0):
		failures.append("Boundary application did not actually replace current cache/stem state at the exact boundary position.")
	events.clear()
	player.sync_authored_arrangement_state({"track_id": TRACK_ID, "visit_id": "timing_visit", "last_phrase_event_index": 5, "phrase_slot": 1})
	var restore_contract := boundary_contract.duplicate(true)
	if not is_equal_approx(float(player.call("_phrase_slot_music_position", restore_contract, 1)), 8.0):
		failures.append("Pure phrase-slot restore position did not resolve to the exact 8-second boundary.")
	player.call("_apply_pending_authored_arrangement_restore", "restored", restore_contract)
	var restored_stem_set: Dictionary = player.get("_current_stem_set") as Dictionary
	if str(player.get("_current_cache_key")) != "restored" or str(restored_stem_set.get("track_id", "")) != TRACK_ID or not is_equal_approx(float(restored_stem_set.get("started_position", -1.0)), 8.0):
		failures.append("Player load restore did not actually resume the matching authored stem set at the exact saved phrase boundary.")
	player.call("_emit_harmony_phrase_boundaries", TRACK_ID, 1, 4)
	if not events.is_empty():
		failures.append("Player load resync emitted a phantom phrase event at the current slot.")
	player.call("_emit_harmony_phrase_boundaries", TRACK_ID, 0, 0)
	if events.size() != 1 or int((events[0] as Dictionary).get("phrase_event_index", -1)) != 6:
		failures.append("Player load resync did not continue at restored next event index 6.")
	for cache_index in range(64):
		player.call("_store_authored_manifest_cache", "probe:%d" % cache_index, {"selection_key": "probe:%d" % cache_index})
	var debug := player.debug_soak_snapshot()
	if int(debug.get("authored_manifest_cache_size", 999)) > int(debug.get("authored_manifest_cache_limit", 0)) or int(debug.get("authored_manifest_cache_size", 0)) != 32:
		failures.append("Authored audible cache exceeded or misreported its hard bound.")
	player.queue_free()
	await process_frame


func _track_entry() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		return {}
	for value in parsed as Array:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == TRACK_ID:
			return (value as Dictionary).duplicate(true)
	return {}


func _finish(failures: Array[String], canonical: Dictionary) -> void:
	if int(canonical.get("selection_count", 0)) != SEED_COUNT * SELECTIONS_PER_SEED:
		failures.append("Selection probe did not execute exactly %d selections." % (SEED_COUNT * SELECTIONS_PER_SEED))
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("AUDIO_HARMONY_SELECTION_CANONICAL %s" % JSON.stringify(canonical))
	quit(0)
