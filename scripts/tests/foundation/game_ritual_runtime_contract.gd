class_name GameRitualRuntimeContract
extends RefCounted

const RuntimeScript := preload("res://scripts/core/game_ritual_runtime.gd")
const SchemaScript := preload("res://scripts/core/game_ritual_schema.gd")
const LayoutScript := preload("res://scripts/core/game_ritual_layout.gd")
const CanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")
const FIXTURE_PATH := "res://scripts/tests/fixtures/game_ritual_vocabulary_v1.json"


static func check(_library, failures: Array) -> void:
	var definition := _fixture(failures)
	if definition.is_empty():
		return
	_check_validation(definition, failures)
	_check_runtime_trace(definition, failures)
	_check_layout_and_canvas(definition, failures)
	_check_neutral_opt_in_seams(failures)


static func _check_validation(definition: Dictionary, failures: Array) -> void:
	var errors := SchemaScript.validate_definition(definition)
	if not errors.is_empty():
		failures.append("Frozen game ritual vocabulary is not accepted by its runtime validator: %s" % JSON.stringify(errors))
	if not LayoutScript.validate_definition(definition).is_empty():
		failures.append("Frozen game ritual vocabulary does not satisfy shared layout validation.")
	var malformed := definition.duplicate(true)
	(malformed["ritual_phases"] as Array).remove_at(1)
	if SchemaScript.validate_definition(malformed).is_empty():
		failures.append("Ritual validator accepted a transition to a removed phase.")
	malformed = definition.duplicate(true)
	((malformed["actors"] as Array)[0] as Dictionary)["behavior_states"] = []
	if SchemaScript.validate_definition(malformed).is_empty():
		failures.append("Ritual validator accepted an actor without behavior states.")
	malformed = definition.duplicate(true)
	((malformed["scene_objects"] as Array)[0] as Dictionary).erase("bounds")
	if SchemaScript.validate_definition(malformed).is_empty():
		failures.append("Ritual validator accepted a scene object without bounds.")
	malformed = definition.duplicate(true)
	var tier: Dictionary = (malformed["energy"] as Dictionary)["tiers"][0]
	tier["object_operations"] = []
	if SchemaScript.validate_definition(malformed).is_empty():
		failures.append("Ritual validator accepted an energy tier that touches only audio/text.")
	malformed = definition.duplicate(true)
	((malformed["pointer_verbs"] as Array)[0] as Dictionary)["equivalents"].erase("controller")
	if SchemaScript.validate_definition(malformed).is_empty():
		failures.append("Ritual validator accepted a pointer verb without controller parity.")


static func _check_runtime_trace(definition: Dictionary, failures: Array) -> void:
	var runtime = RuntimeScript.new()
	var configured: Dictionary = runtime.configure(definition, {"play.primary": Callable(GameRitualRuntimeContract, "_play_handler")})
	if not bool(configured.get("ok", false)):
		failures.append("Ritual runtime rejected the frozen vocabulary: %s" % JSON.stringify(configured))
		return
	var initial := runtime.serialized_state()
	var rejected: Dictionary = runtime.process_action("play.primary", {"commitment_id": "early"}, "trace:reject", {})
	if bool(rejected.get("ok", false)) or str(rejected.get("error_code", "")) != "action_out_of_phase":
		failures.append("Ritual runtime did not reject an out-of-phase authoritative action.")
	var rejected_state := runtime.serialized_state()
	for key in initial.keys():
		if key != "request_cache" and initial[key] != rejected_state.get(key):
			failures.append("Rejected ritual action mutated authoritative field %s." % key)
	var place: Dictionary = runtime.process_action("commit.place", {"item_id": "layout.primary", "amount": 5}, "trace:place", {"available_funds": 20})
	var replay: Dictionary = runtime.process_action("commit.place", {"amount": 5, "item_id": "layout.primary"}, "trace:place", {"available_funds": 20})
	if not bool(place.get("ok", false)) or place != replay:
		failures.append("Ritual request replay was not byte-identical under canonical key ordering.")
	var conflict: Dictionary = runtime.process_action("commit.place", {"item_id": "layout.primary", "amount": 6}, "trace:place", {"available_funds": 20})
	if str(conflict.get("error_code", "")) != "request_conflict":
		failures.append("Ritual request key did not reject different canonical content.")
	var correct: Dictionary = runtime.process_action("commit.correct", {"item_id": "layout.primary", "amount": 7}, "trace:correct", {"available_funds": 20})
	var undo: Dictionary = runtime.process_action("commit.undo", {}, "trace:undo", {"available_funds": 20})
	if not bool(correct.get("ok", false)) or not bool(undo.get("ok", false)) or int((runtime.prepared_projection()["pending_items"] as Dictionary).get("layout.primary", 0)) != 5:
		failures.append("Staged commitment correction/undo did not preserve the pending set.")
	var confirm: Dictionary = runtime.process_action("commit.confirm", {}, "trace:confirm", {"available_funds": 20})
	var confirm_replay: Dictionary = runtime.process_action("commit.confirm", {}, "trace:confirm", {"available_funds": 20})
	if not bool(confirm.get("ok", false)) or confirm != confirm_replay or str(confirm.get("phase_id", "")) != "committed":
		failures.append("Phase-changing commitment confirmation was not exactly-once replayable.")
	var double_commit: Dictionary = runtime.process_action("commit.confirm", {}, "trace:double", {"available_funds": 20})
	if str(double_commit.get("error_code", "")) != "action_out_of_phase":
		failures.append("Phase machine permitted a double commitment.")
	var play: Dictionary = runtime.process_action("play.primary", {"commitment_id": "commitment.one"}, "trace:play", {"seed": 19})
	if not bool(play.get("ok", false)) or str(play.get("phase_id", "")) != "resolving" or (play.get("facts", []) as Array).size() != 1:
		failures.append("Allowlisted rules handler did not advance and publish one action-boundary fact.")
	var saved := runtime.serialized_state()
	var restored = RuntimeScript.new()
	if not bool(restored.configure(definition, {"play.primary": Callable(GameRitualRuntimeContract, "_play_handler")}).get("ok", false)):
		failures.append("Restore proof could not configure a second ritual runtime.")
		return
	var restore_result: Dictionary = restored.restore(saved)
	if not bool(restore_result.get("ok", false)) or not (restore_result.get("replayed_effects", [1]) as Array).is_empty() or restored.serialized_state() != saved:
		failures.append("Ritual restore changed authoritative state or replayed one-shot effects.")
	var acknowledge: Dictionary = restored.process_action("resolution.acknowledge", {}, "trace:ack", {})
	if not bool(acknowledge.get("ok", false)) or str(acknowledge.get("phase_id", "")) != "open":
		failures.append("Resolution acknowledgement did not return to the legal open phase.")
	var energy: Dictionary = restored.set_energy_tier("engaged", "trace_energy")
	var actors: Array = energy.get("projection", {}).get("actors", [])
	if not bool(energy.get("ok", false)) or actors.is_empty() or str((actors[0] as Dictionary).get("state", {}).get("behavior", "")) != "watching":
		failures.append("Energy tier did not project its declared actor operation.")
	if RuntimeScript.canonical_fingerprint({"b": 2, "a": [1, true]}) != RuntimeScript.canonical_fingerprint({"a": [1, true], "b": 2}):
		failures.append("Ritual canonical fingerprint depends on dictionary insertion order.")


static func _check_layout_and_canvas(definition: Dictionary, failures: Array) -> void:
	var hits := LayoutScript.compile_pointer_hits(definition, "open")
	if hits.size() != 1 or str((hits[0] as Dictionary).get("target_region", "")) != "layout.primary":
		failures.append("Ritual layout did not compile the active target-region hit.")
	var canvas = CanvasScript.new()
	canvas.surface_add_ritual_hits(hits)
	if canvas.hit_regions.size() != hits.size() or str((canvas.hit_regions[0] as Dictionary).get("ritual_pointer_id", "")) != "place_primary":
		failures.append("Canvas ritual adapter did not preserve semantic pointer identity.")
	canvas.free()
	var malformed := definition.duplicate(true)
	var bounds: Dictionary = ((malformed["scene_objects"] as Array)[0] as Dictionary)["bounds"]
	bounds["x"] = 880
	if LayoutScript.validate_definition(malformed).is_empty():
		failures.append("Ritual layout accepted an object outside design space.")


static func _check_neutral_opt_in_seams(failures: Array) -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/core/game_ritual_runtime.gd").to_lower()
	var layout_source := FileAccess.get_file_as_string("res://scripts/core/game_ritual_layout.gd").to_lower()
	for forbidden in ["craps", "blackjack", "roulette", "baccarat", "poker", "slots", "pusher"]:
		if runtime_source.contains(forbidden) or layout_source.contains(forbidden):
			failures.append("Shared ritual implementation contains game-specific token %s." % forbidden)
	var canvas_source := FileAccess.get_file_as_string("res://scripts/ui/game_surface_canvas.gd")
	if canvas_source.count("surface_add_ritual_hits(") != 1:
		failures.append("Ritual canvas seam is not opt-in; an existing path invokes it implicitly.")


static func _play_handler(_action_id: String, parameters: Dictionary, _candidate: Dictionary, context: Dictionary) -> Dictionary:
	var result_id := "result.%d.%s" % [int(context.get("seed", 0)), str(parameters.get("commitment_id", ""))]
	return {
		"ok": true,
		"persisted_state": {"authoritative_result_refs": [{"result_id": result_id}]},
		"result": {"result_id": result_id, "net_change": 10},
		"facts": [{"fact_type": "resolution.completed", "payload": {"result_id": result_id, "net_change": 10}}],
		"operations": [],
	}


static func _fixture(failures: Array) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("Frozen ritual vocabulary fixture is not valid JSON.")
		return {}
	return parsed
