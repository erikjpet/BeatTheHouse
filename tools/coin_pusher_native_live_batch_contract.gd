extends Node

const CoinPusherGame := preload("res://scripts/games/coin_pusher.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const Solver := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")

const RESULT_MARKER := "COIN_PUSHER_V3_SMOKE_RESULT="


func _ready() -> void:
	var report := _run_contract()
	print(RESULT_MARKER + JSON.stringify(report))
	get_tree().quit(0 if bool(report.get("ok", false)) else 1)


static func _run_contract() -> Dictionary:
	var failures: Array[String] = []
	if not OS.has_feature("web"):
		failures.append("Native live-batch contract must run in the shipped Web export.")
	if not ClassDB.class_exists("CoinPusherNativeCore"):
		failures.append("Shipped Web export did not load CoinPusherNativeCore.")
		return _report(failures, {})
	var native: Object = ClassDB.instantiate("CoinPusherNativeCore")
	if native == null or not native.has_method("supports_live_batch_capture") or not bool(native.call("supports_live_batch_capture")):
		failures.append("Shipped Web native core did not advertise live-batch capture.")
		return _report(failures, {})

	var library = ContentLibraryScript.new()
	library.load(false)
	var game = CoinPusherGame.new()
	game.setup(library.game("coin_pusher"), library)
	var definition: Dictionary = game.call("_machine_definition", "quarter_falls")
	if definition.is_empty():
		failures.append("Quarter Falls production definition is missing.")
		return _report(failures, {})

	var opening := Solver.create_machine(_rng("LIVE-BATCH-OPENING"), definition, 18)
	var native_state: Dictionary = opening.duplicate(true)
	var reference_state: Dictionary = opening.duplicate(true)
	var previous_reference: Dictionary = opening.duplicate(true)
	var start_tick := int(opening.get("tick", 0))
	var first_trace := [
		{"tick": start_tick, "kind": "carriage", "x": 34000},
		{"tick": start_tick + 1, "kind": "drop", "x": 34000, "density": 1, "provenance": {"contract": "first"}},
		{"tick": start_tick + 2, "kind": "nudge", "x": 700, "y": -900},
		{"tick": start_tick + 3, "kind": "skill_stop", "engaged": true},
	]
	var native_rng := _rng("LIVE-BATCH-FIRST-RNG")
	var reference_rng := _rng("LIVE-BATCH-FIRST-RNG")
	var previous_rng := _rng("LIVE-BATCH-FIRST-RNG")
	var native_result: Dictionary = native.call("step_ticks", native_state, {
		"input_trace": first_trace,
		"rng": native_rng,
		"motor_enabled": true,
		"live_cache_key": "contract:a",
		"live_cache_reset": true,
		"capture_previous_views": true,
		"capture_current_views": true,
	}, 5)
	var reference_result := Solver.step_ticks_reference_for_test(reference_state, {
		"input_trace": first_trace,
		"rng": reference_rng,
		"motor_enabled": true,
	}, 5)
	Solver.step_ticks_reference_for_test(previous_reference, {
		"input_trace": first_trace,
		"rng": previous_rng,
		"motor_enabled": true,
	}, 4)
	_assert_equal("first cached final state", Solver.canonical_digest(native_state), Solver.canonical_digest(reference_state), failures)
	_assert_equal("first cached physics events", _physics_events(native_result.get("events", [])), _physics_events(reference_result.get("events", [])), failures)
	_assert_equal("first cached native insert bookkeeping", _event_kind_count(native_result.get("events", []), "insert"), 1, failures)
	_assert_equal("first cached RNG boundary", native_rng.snapshot(), reference_rng.snapshot(), failures)
	_assert_equal("pre-final presentation bodies", native_result.get("presentation_previous_bodies", []), _presentation_views(previous_reference), failures)
	_assert_equal("pre-final presentation face", int(native_result.get("presentation_previous_face_y", -1)), int(previous_reference.get("face_y", -2)), failures)
	_assert_equal("current presentation bodies", native_result.get("presentation_current_bodies", []), _presentation_views(reference_state), failures)
	_assert_equal("current presentation face", int(native_result.get("presentation_current_face_y", -1)), int(reference_state.get("face_y", -2)), failures)
	var render_config := {
		"world_width": 100000,
		"world_back_y": 78000,
		"coin_height": 950,
		"coin_radius": 2350,
		"board": {"y": 78000, "z_bottom": 3600, "z_top": 24000},
		"body_colors": {"default": "#c9c5b8", "coin": "#d9c167", "rider": "#62c8ef", "puck": "#ec6f66", "fragment": "#a8e078"},
	}
	var dictionary_render: Dictionary = native.call("build_live_render_batch", render_config, native_result.get("presentation_current_bodies", []), native_result.get("presentation_previous_bodies", []), 0.375)
	var packed_render: Dictionary = native.call("build_live_render_batch_packed", render_config, native_result.get("presentation_current_packed", PackedInt64Array()), native_result.get("presentation_previous_packed", PackedInt64Array()), 0.375)
	_assert_equal("packed renderer count", packed_render.get("count", -1), dictionary_render.get("count", -2), failures)
	_assert_equal("packed renderer transform/color buffer", packed_render.get("buffer", PackedFloat32Array()), dictionary_render.get("buffer", PackedFloat32Array()), failures)
	_assert_equal("packed renderer shadows", packed_render.get("shadows", []), dictionary_render.get("shadows", []), failures)
	_assert_equal("packed renderer feature labels", packed_render.get("features", []), dictionary_render.get("features", []), failures)

	# An ordinary production solver call has no live key. It must neither consume
	# nor replace the retained live kernel used by the following continuation.
	var ordinary_state: Dictionary = opening.duplicate(true)
	var ordinary_reference: Dictionary = opening.duplicate(true)
	var ordinary_rng := _rng("LIVE-BATCH-ORDINARY-RNG")
	var ordinary_reference_rng := _rng("LIVE-BATCH-ORDINARY-RNG")
	var ordinary_trace := [{"tick": start_tick, "kind": "drop", "x": 62000, "density": 1, "provenance": {"contract": "ordinary"}}]
	var ordinary_result := Solver.step_ticks(ordinary_state, {"input_trace": ordinary_trace, "rng": ordinary_rng, "motor_enabled": false}, 2)
	var ordinary_reference_result := Solver.step_ticks_reference_for_test(ordinary_reference, {"input_trace": ordinary_trace, "rng": ordinary_reference_rng, "motor_enabled": false}, 2)
	_assert_equal("ordinary solver final state", Solver.canonical_digest(ordinary_state), Solver.canonical_digest(ordinary_reference), failures)
	_assert_equal("ordinary solver physics events", _physics_events(ordinary_result.get("events", [])), _physics_events(ordinary_reference_result.get("events", [])), failures)
	_assert_equal("ordinary native insert bookkeeping", _event_kind_count(ordinary_result.get("events", []), "insert"), 1, failures)
	_assert_equal("ordinary solver RNG boundary", ordinary_rng.snapshot(), ordinary_reference_rng.snapshot(), failures)

	var second_tick := int(native_state.get("tick", 0))
	var second_trace := [
		{"tick": second_tick, "kind": "skill_stop", "engaged": false},
		{"tick": second_tick + 1, "kind": "drop", "x": 36000, "density": 1, "provenance": {"contract": "resume"}},
	]
	var second_native: Dictionary = native.call("step_ticks", native_state, {
		"input_trace": second_trace,
		"rng": native_rng,
		"motor_enabled": true,
		"live_cache_key": "contract:a",
	}, 3)
	var second_reference := Solver.step_ticks_reference_for_test(reference_state, {
		"input_trace": second_trace,
		"rng": reference_rng,
		"motor_enabled": true,
	}, 3)
	_assert_equal("cached continuation after ordinary call", Solver.canonical_digest(native_state), Solver.canonical_digest(reference_state), failures)
	_assert_equal("continuation physics events", _physics_events(second_native.get("events", [])), _physics_events(second_reference.get("events", [])), failures)
	_assert_equal("continuation native insert bookkeeping", _event_kind_count(second_native.get("events", []), "insert"), 1, failures)
	_assert_equal("continuation RNG boundary", native_rng.snapshot(), reference_rng.snapshot(), failures)

	# Switching keys must load the supplied state rather than leak bodies or
	# scalar state from the prior live machine.
	var other_state := Solver.create_machine(_rng("LIVE-BATCH-OTHER-OPENING"), definition, 7)
	var other_reference: Dictionary = other_state.duplicate(true)
	var other_tick := int(other_state.get("tick", 0))
	var other_trace := [{"tick": other_tick, "kind": "nudge", "x": -700, "y": -900}]
	var other_result: Dictionary = native.call("step_ticks", other_state, {
		"input_trace": other_trace,
		"motor_enabled": false,
		"live_cache_key": "contract:b",
	}, 2)
	var other_reference_result := Solver.step_ticks_reference_for_test(other_reference, {"input_trace": other_trace, "motor_enabled": false}, 2)
	_assert_equal("cache key isolation state", Solver.canonical_digest(other_state), Solver.canonical_digest(other_reference), failures)
	_assert_equal("cache key isolation physics events", _physics_events(other_result.get("events", [])), _physics_events(other_reference_result.get("events", [])), failures)

	var third_tick := int(native_state.get("tick", 0))
	var third_trace := [{"tick": third_tick, "kind": "nudge", "x": 500, "y": -500}]
	var third_native: Dictionary = native.call("step_ticks", native_state, {
		"input_trace": third_trace,
		"rng": native_rng,
		"motor_enabled": true,
		"live_cache_key": "contract:a",
	}, 2)
	var third_reference := Solver.step_ticks_reference_for_test(reference_state, {
		"input_trace": third_trace,
		"rng": reference_rng,
		"motor_enabled": true,
	}, 2)
	_assert_equal("key switch reloads exact supplied state", Solver.canonical_digest(native_state), Solver.canonical_digest(reference_state), failures)
	_assert_equal("key switch continuation physics events", _physics_events(third_native.get("events", [])), _physics_events(third_reference.get("events", [])), failures)

	# A deterministic fixture can create a brand-new authority with the same
	# logical cache key. Its explicit reset must discard the retained vector even
	# when body count and tick happen to match the prior machine.
	var replacement := Solver.create_machine(_rng("LIVE-BATCH-REPLACEMENT"), definition, 18)
	var replacement_reference: Dictionary = replacement.duplicate(true)
	var replacement_tick := int(replacement.get("tick", 0))
	var replacement_trace := [{"tick": replacement_tick, "kind": "nudge", "x": -500, "y": -500}]
	var replacement_native: Dictionary = native.call("step_ticks", replacement, {
		"input_trace": replacement_trace,
		"motor_enabled": false,
		"live_cache_key": "contract:a",
		"live_cache_reset": true,
		"capture_current_views": true,
	}, 2)
	var replacement_reference_result := Solver.step_ticks_reference_for_test(replacement_reference, {"input_trace": replacement_trace, "motor_enabled": false}, 2)
	_assert_equal("same-key generation reset state", Solver.canonical_digest(replacement), Solver.canonical_digest(replacement_reference), failures)
	_assert_equal("same-key generation reset physics events", _physics_events(replacement_native.get("events", [])), _physics_events(replacement_reference_result.get("events", [])), failures)
	_assert_equal("same-key generation current presentation", replacement_native.get("presentation_current_bodies", []), _presentation_views(replacement_reference), failures)

	var payload := {
		"native_final": Solver.canonical_digest(native_state),
		"reference_final": Solver.canonical_digest(reference_state),
		"native_rng": native_rng.snapshot(),
		"reference_rng": reference_rng.snapshot(),
		"other_final": Solver.canonical_digest(other_state),
	}
	return _report(failures, payload)


static func _report(failures: Array[String], payload: Dictionary) -> Dictionary:
	return {
		"ok": failures.is_empty(),
		"schema": "coin_pusher_native_live_batch_contract_v1",
		"platform": OS.get_name(),
		"web_feature": OS.has_feature("web"),
		"native_live_batch_supported": Solver.native_live_batch_supported(),
		"parity_payload_sha256": _canonical_json(payload).sha256_text(),
		"failure_count": failures.size(),
		"failures": failures,
	}


static func _assert_equal(label: String, actual: Variant, expected: Variant, failures: Array[String]) -> void:
	if _canonical_json(actual) != _canonical_json(expected):
		failures.append("%s diverged: actual=%s expected=%s" % [label, _canonical_json(actual), _canonical_json(expected)])


static func _physics_events(events_value: Variant) -> Array:
	var result: Array = []
	if typeof(events_value) != TYPE_ARRAY:
		return result
	for event_value in events_value as Array:
		if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("kind", "")) != "insert":
			result.append((event_value as Dictionary).duplicate(true))
	return result


static func _event_kind_count(events_value: Variant, kind: String) -> int:
	var result := 0
	if typeof(events_value) != TYPE_ARRAY:
		return result
	for event_value in events_value as Array:
		if typeof(event_value) == TYPE_DICTIONARY and str((event_value as Dictionary).get("kind", "")) == kind:
			result += 1
	return result


static func _presentation_views(state: Dictionary) -> Array:
	var result: Array = []
	for body_value in state.get("bodies", []):
		var body: Dictionary = body_value
		var support_kind := str(body.get("support_kind", ""))
		result.append({
			"id": str(body.get("id", "")),
			"kind": str(body.get("kind", "coin")),
			"x": int(body.get("x", 0)),
			"y": int(body.get("y", 0)),
			"z": int(body.get("z", 0)),
			"rest_state": str(body.get("rest_state", "falling")),
			"support_kind": support_kind,
			"support_root": "platform" if support_kind == "platform" or (support_kind == "body" and bool(body.get("carried_sleep", false))) else "deck" if not support_kind.is_empty() else "",
		})
	return result


static func _canonical_json(value: Variant) -> String:
	return JSON.stringify(value, "", true)


static func _rng(seed: String) -> RngStream:
	var rng := RngStream.new()
	rng.configure(_stable_hash(seed))
	return rng


static func _stable_hash(value: String) -> int:
	var hash_value := 2166136261
	for byte in value.to_utf8_buffer():
		hash_value = int((hash_value ^ int(byte)) * 16777619) & 0x7fffffff
	return hash_value
