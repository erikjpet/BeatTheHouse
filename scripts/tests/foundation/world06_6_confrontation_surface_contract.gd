extends SceneTree

const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const Model := preload("res://scripts/core/crew_turn_model.gd")
const MODEL_PATH := "res://scripts/core/crew_turn_model.gd"
const MARKER := "# WORLD06_6_PUBLIC_SURFACE_BEGIN"
const EXPECTED_GOVERNING_PREFIX_SHA256 := "70214500f527c1d4f94a3e40d653b9561b70cf52e27bc3c8d36423016f820965"


func _initialize() -> void:
	var failures: Array = []
	_check_governing_prefix(failures)
	_check_observable_beats(failures)
	_check_quiet_table_surface(failures)
	_check_aftermath_beats(failures)
	_check_plan_failure_beats(failures)
	_check_public_boundary(failures)
	if failures.is_empty():
		print("world06_6 confrontation surface contract passed authority=proposal_only gap=host_observation_authority_unavailable")
		quit(0)
		return
	for failure in failures:
		push_error(str(failure))
	quit(1)


func _check_governing_prefix(failures: Array) -> void:
	var source := FileAccess.get_file_as_string(MODEL_PATH)
	var marker_at := source.find(MARKER)
	if marker_at < 0 or source.substr(0, marker_at).replace("\r\n", "\n").sha256_text() != EXPECTED_GOVERNING_PREFIX_SHA256:
		failures.append("The landed governing implementation changed.")
	var state := Model.empty_state()
	var keys := state.keys(); keys.sort()
	if keys != ["c", "e", "f", "h", "m", "v", "w"] or int(state.get("v", 0)) != 1:
		failures.append("The neutral storage shape changed.")


func _check_observable_beats(failures: Array) -> void:
	var surfaces: Array = []
	for token in Model.SIGNAL_IDS:
		var proposal := Model.observable_signal_proposal(str(token))
		if not _safe_envelope(proposal): failures.append("An observable beat lacked the safe proposal envelope.")
		surfaces.append(_presentation(proposal))
	if surfaces.size() != 3 or str((surfaces[0] as Dictionary).get("surface_id", "")) == str((surfaces[1] as Dictionary).get("surface_id", "")) \
			or str((surfaces[1] as Dictionary).get("surface_id", "")) == str((surfaces[2] as Dictionary).get("surface_id", "")):
		failures.append("Observable beats were not distinct and complete.")
	if not Model.observable_signal_proposal("unknown").is_empty(): failures.append("An unknown observation produced a surface.")


func _check_quiet_table_surface(failures: Array) -> void:
	var first := Model.confrontation_surface_proposal("the_count")
	var second := Model.confrontation_surface_proposal("the_whale_game")
	if not _safe_envelope(first) or JSON.stringify(first) != JSON.stringify(second):
		failures.append("The quiet table surface varied with private plan state.")
	var presentation := _presentation(first)
	if presentation.get("public_verbs", []) != ["press", "step_back", "change_role"] or presentation.has("available"):
		failures.append("The quiet table surface advertised unavailable private state.")
	if not Model.confrontation_surface_proposal("unknown").is_empty(): failures.append("An unknown plan produced a table surface.")


func _check_aftermath_beats(failures: Array) -> void:
	var beat_ids: Array = []
	for public_beat in ["right", "wrong", "hedge"]:
		var proposal := Model.confrontation_aftermath_proposal(public_beat)
		if not _safe_envelope(proposal): failures.append("A public aftermath lacked the safe proposal envelope.")
		beat_ids.append(str(_presentation(proposal).get("beat_id", "")))
	var unique: Array = []
	for beat_id in beat_ids:
		if not unique.has(beat_id): unique.append(beat_id)
	if unique.size() != 3: failures.append("The three public aftermath beats were not distinct.")
	if not Model.confrontation_aftermath_proposal("unknown").is_empty(): failures.append("An unknown aftermath produced a surface.")


func _check_plan_failure_beats(failures: Array) -> void:
	var beat_ids: Array = []
	for plan_id in ["the_count", "the_whale_game"]:
		for kind in ["fracture", "mechanical"]:
			var proposal := Model.plan_failure_beat_proposal(plan_id, kind)
			if not _safe_envelope(proposal): failures.append("A plan failure beat lacked the safe proposal envelope.")
			beat_ids.append(str(_presentation(proposal).get("beat_id", "")))
	var unique: Array = []
	for beat_id in beat_ids:
		if not unique.has(beat_id): unique.append(beat_id)
	if unique.size() != 4: failures.append("The four public plan failure beats were not distinct.")


func _check_public_boundary(failures: Array) -> void:
	var surfaces: Array = []
	for token in Model.SIGNAL_IDS: surfaces.append(Model.observable_signal_proposal(str(token)))
	for public_beat in ["right", "wrong", "hedge"]: surfaces.append(Model.confrontation_aftermath_proposal(public_beat))
	for plan_id in ["the_count", "the_whale_game"]:
		surfaces.append(Model.confrontation_surface_proposal(plan_id))
		for kind in ["fracture", "mechanical"]: surfaces.append(Model.plan_failure_beat_proposal(plan_id, kind))
	var public_text := JSON.stringify(surfaces).to_lower()
	for blocked in _blocked_terms():
		if public_text.contains(blocked): failures.append("A private term crossed the public boundary.")
	var source := FileAccess.get_file_as_string(MODEL_PATH)
	var added_source := source.substr(source.find(MARKER)).to_lower()
	for blocked in _blocked_terms():
		if added_source.contains(blocked): failures.append("The added surface vocabulary names a private mechanism.")


func _safe_envelope(value: Dictionary) -> bool:
	var keys := value.keys(); keys.sort()
	return keys == ["authoritative", "authority_gap", "can_mutate", "presentation", "proposal_only", "schema_version"] \
		and not bool(value.get("authoritative", true)) and bool(value.get("proposal_only", false)) and not bool(value.get("can_mutate", true)) \
		and str(value.get("authority_gap", "")) == "host_observation_authority_unavailable" and typeof(value.get("presentation")) == TYPE_DICTIONARY


func _presentation(value: Dictionary) -> Dictionary:
	return (value.get("presentation", {}) as Dictionary).duplicate(true) if typeof(value.get("presentation", {})) == TYPE_DICTIONARY else {}


func _blocked_terms() -> Array:
	return ["tra" + "itor", "cl" + "ue", "betra" + "yal", "the_" + "turn", "grie" + "vance", "wei" + "ght", "resol" + "ution", "elig" + "ible", "wit" + "ness", "member_" + "id", "signal_" + "count"]
