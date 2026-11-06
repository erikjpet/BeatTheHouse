extends SceneTree

# Ordinary authored DTOs and public configuration only. No commands, host,
# checkpoints, restoration, callbacks, injected handlers or authority issuance.
const SchemaScript := preload("res://scripts/core/game_ritual_schema.gd")
const RuntimeScript := preload("res://scripts/core/game_ritual_runtime.gd")
const FIXTURE := "res://scripts/tests/fixtures/game_ritual_vocabulary_v1.json"
var checks := 0
var failures: Array[String] = []
var observations: Array = []


func _init() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var fixture_before := var_to_bytes(fixture)
	var errors := SchemaScript.validate_definition(fixture)
	_check(errors.is_empty(), "original authored vocabulary fixture validates")
	var baseline = RuntimeScript.new()
	var configured: Dictionary = baseline.configure(fixture)
	_check(bool(configured.get("ok", false)), "original public configure succeeds")
	if not errors.is_empty() or not bool(configured.get("ok", false)):
		observations.append({"case": "original_fixture", "schema_errors": errors, "configuration": configured})
		_finish()
		return
	var original_state: Dictionary = configured["state"]
	observations.append({"case": "original_fixture", "state_hash": RuntimeScript.canonical_fingerprint(original_state), "projection_hash": RuntimeScript.canonical_fingerprint(configured["projection"])})
	var vectors: Array = [
		{"value": "a.b", "valid": true},
		{"value": "example.table", "valid": true},
		{"value": "game_1.table_2", "valid": true},
		{"value": "a".repeat(64) + ".b", "valid": true},
		{"value": "a".repeat(64) + "." + "b".repeat(64) + "." + "c".repeat(62), "valid": true},
		{"value": ".example.table", "valid": false},
		{"value": "example..table", "valid": false},
		{"value": "example.table.", "valid": false},
		{"value": "example...table", "valid": false},
		{"value": "example", "valid": false},
		{"value": "A.table", "valid": false},
		{"value": "1a.table", "valid": false},
		{"value": "a.b-c", "valid": false},
		{"value": "a".repeat(65) + ".b", "valid": false},
		{"value": "a".repeat(64) + "." + "b".repeat(64) + "." + "c".repeat(63), "valid": false},
	]
	for index in range(vectors.size()):
		var vector: Dictionary = vectors[index]
		var value := str(vector["value"])
		var valid := bool(vector["valid"])
		var definition := fixture.duplicate(true)
		definition["ritual_id"] = value
		var before := var_to_bytes(definition)
		var definition_errors := SchemaScript.validate_definition(definition)
		var runtime = RuntimeScript.new()
		var result: Dictionary = runtime.configure(definition)
		var label := "definition vector %d" % index
		_check(definition_errors.is_empty() == valid, label + " schema admission")
		_check(bool(result.get("ok", false)) == valid, label + " configure admission")
		_check(var_to_bytes(definition) == before, label + " input ownership")
		if valid:
			_check(str(result.get("state", {}).get("ritual_id", "")) == value, label + " accepted identity")
		else:
			_check(definition_errors == ["definition.ritual_id is not a canonical qualified id"], label + " exact schema rejection")
			_check(result.get("errors", []) == ["definition.ritual_id is not a canonical qualified id"], label + " exact configuration rejection")
			_check(runtime.definition.is_empty() and runtime.state.is_empty(), label + " no configured state")
		observations.append({"case": "definition", "index": index, "value": value, "expected_valid": valid, "schema_errors": definition_errors, "configured": result.get("ok", false), "configuration_errors": result.get("errors", [])})
		var session_runtime = RuntimeScript.new()
		var session_result: Dictionary = session_runtime.configure(fixture, value)
		label = "session vector %d" % index
		_check(bool(session_result.get("ok", false)) == valid, label + " configure admission")
		if valid:
			_check(str(session_result.get("state", {}).get("session_id", "")) == value, label + " accepted identity")
		else:
			_check(session_result.get("errors", []) == ["retained ritual host session identity is invalid"], label + " exact rejection")
			_check(session_runtime.definition.is_empty() and session_runtime.state.is_empty(), label + " no configured state")
		observations.append({"case": "session", "index": index, "value": value, "expected_valid": valid, "configured": session_result.get("ok", false), "configuration_errors": session_result.get("errors", [])})
	_check(var_to_bytes(fixture) == fixture_before, "grammar controls preserve original authored input")
	_check_positions(fixture, original_state)
	for path in ["res://data/games/bar_dice_game_ritual_v1.json", "res://data/games/showdown_duel_game_ritual_v1.json"]:
		var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var authored_before := var_to_bytes(authored)
		var authored_errors := SchemaScript.validate_definition(authored)
		_check(var_to_bytes(authored) == authored_before, "existing game authoring input remains owned")
		observations.append({"case": "existing_game_definition", "path": path, "definition_hash": RuntimeScript.canonical_fingerprint(authored), "schema_errors": authored_errors, "has_public_projection_schema": authored.has("public_projection_schema")})
	_check(var_to_bytes(fixture) == fixture_before, "all controls preserve original authored input")
	_finish()


func _check_positions(fixture: Dictionary, original_state: Dictionary) -> void:
	var vectors: Array = [
		{"name": "actor canonical", "family": "actor_ops", "verb": "set_position", "arguments": {"anchor_id": "layout.center"}, "expected": "layout.center"},
		{"name": "actor legacy", "family": "actor_ops", "verb": "set_position", "arguments": {"anchor": "layout.center"}, "expected": "layout.center"},
		{"name": "actor both canonical precedence", "family": "actor_ops", "verb": "set_position", "arguments": {"anchor_id": "layout.center", "anchor": "station.primary"}, "expected": "layout.center"},
		{"name": "actor missing preserves prior", "family": "actor_ops", "verb": "set_position", "arguments": {}, "expected": "station.primary"},
		{"name": "scene move canonical", "family": "scene_ops", "verb": "move", "arguments": {"anchor_id": "station.primary", "zone_id": "layout.primary"}, "expected": "station.primary"},
		{"name": "scene move legacy", "family": "scene_ops", "verb": "move", "arguments": {"anchor": "station.primary", "zone_id": "layout.primary"}, "expected": "station.primary"},
		{"name": "scene move both canonical precedence", "family": "scene_ops", "verb": "move", "arguments": {"anchor_id": "station.primary", "anchor": "layout.center", "zone_id": "layout.primary"}, "expected": "station.primary"},
		{"name": "scene position canonical", "family": "scene_ops", "verb": "set_position", "arguments": {"anchor_id": "station.primary"}, "expected": "station.primary"},
		{"name": "scene position legacy", "family": "scene_ops", "verb": "set_position", "arguments": {"anchor": "station.primary"}, "expected": "station.primary"},
		{"name": "scene position both canonical precedence", "family": "scene_ops", "verb": "set_position", "arguments": {"anchor_id": "station.primary", "anchor": "layout.center"}, "expected": "station.primary"},
		{"name": "scene position missing preserves prior", "family": "scene_ops", "verb": "set_position", "arguments": {}, "expected": "layout.center"},
	]
	for vector in vectors:
		var definition := fixture.duplicate(true)
		var phases: Array = definition["ritual_phases"]
		var phase: Dictionary = phases[0]
		var transition: Dictionary = phase["transitions"][0]
		var operation: Dictionary = transition["operations"][0].duplicate(true)
		transition["operations"] = []
		operation["family"] = vector["family"]
		operation["verb"] = vector["verb"]
		var actor := str(vector["family"]) == "actor_ops"
		var target := "staff.primary" if actor else "apparatus.primary"
		var collection := "actor_states" if actor else "object_states"
		operation["target_id"] = target
		operation["arguments"] = vector["arguments"].duplicate(true)
		phase["entry_operations"] = [operation]
		var before := var_to_bytes(definition)
		var errors := SchemaScript.validate_definition(definition)
		var runtime = RuntimeScript.new()
		var result: Dictionary = runtime.configure(definition)
		var label := str(vector["name"])
		_check(errors.is_empty(), label + " ordinary authored DTO validates")
		_check(bool(result.get("ok", false)), label + " public configure succeeds")
		_check(var_to_bytes(definition) == before, label + " input ownership")
		var expected := original_state.duplicate(true)
		expected[collection][target]["anchor"] = vector["expected"]
		var actual: Dictionary = result.get("state", {})
		_check(str(actual.get(collection, {}).get(target, {}).get("anchor", "")) == str(vector["expected"]), label + " configured anchor")
		_check(var_to_bytes(actual) == var_to_bytes(expected), label + " all unrelated state and counters unchanged")
		observations.append({"case": "position", "name": label, "expected_anchor": vector["expected"], "actual_anchor": actual.get(collection, {}).get(target, {}).get("anchor", ""), "schema_errors": errors, "configured": result.get("ok", false), "configuration_errors": result.get("errors", []), "state_hash": RuntimeScript.canonical_fingerprint(actual), "expected_state_hash": RuntimeScript.canonical_fingerprint(expected)})


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _finish() -> void:
	print("RITUAL026_DTO_OBSERVATIONS " + JSON.stringify({"checks": checks, "failures": failures, "observations": observations, "scope": "ordinary authored DTOs/public Schema.validate_definition and Runtime.configure; no commands/host/checkpoint/restore/callbacks/capsules/keys"}))
	quit(0 if failures.is_empty() else 1)
