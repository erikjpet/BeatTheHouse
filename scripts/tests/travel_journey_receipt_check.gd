extends SceneTree

const ReceiptScript := preload("res://scripts/core/travel_journey_receipt.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const SchemaScript := preload("res://scripts/core/run_state_schema.gd")
const CodecScript := preload("res://scripts/core/run_save_codec.gd")
const SaveServiceScript := preload("res://scripts/core/save_service.gd")

var failures: Array[String] = []
var checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := RunStateScript.new()
	state.start_new("TRAVEL-RECEIPT-CHECK")
	state.game_clock_minutes = 640
	state.environment_history_archive_count = 3
	var origin := {"id": "alley_instance_1", "archetype_id": "back_alley", "world_node_id": "alley_node", "display_name": "Back Alley", "departed_game_clock_minutes": 620}
	var destination := {"id": "bar_instance_1", "archetype_id": "bar", "world_node_id": "bar_node", "display_name": "The Crooked Glass"}
	var route := {"id": "alley_to_bar", "travel_method_kind": "bus", "travel_method": "Bus ticket", "distance": "local", "distance_blocks": 6, "world_path": ["alley_node", "corner_node", "bar_node"], "travel_minutes": 20, "cost": 30, "departed_game_clock_minutes": 620, "arrived_game_clock_minutes": 640}
	var quote := {"cost": 7}
	var risk := {"id": "old_risk", "label": "Missed connection", "triggered": false, "chance_percent": 15, "roll": 42, "bankroll_delta": 0, "suspicion_delta": 0, "message": ""}
	var travel_result := {"message": "Traveled to the Bar. Route cost 7, 20 min."}
	var state_before := JSON.stringify(state.to_dict())
	var route_before := JSON.stringify([origin, destination, route, quote, risk, travel_result])
	seed(12345)
	var expected_global_rng := randi()
	seed(12345)
	var receipt := ReceiptScript.build(state, origin, destination, "bar_node", route, quote, risk, travel_result)
	_check(randi() == expected_global_rng, "build consumed global RNG")
	_check(JSON.stringify(state.to_dict()) == state_before, "build mutated RunState/RNG/clock/economy")
	_check(JSON.stringify([origin, destination, route, quote, risk, travel_result]) == route_before, "build mutated an input")
	_check(receipt == ReceiptScript.build(state, origin, destination, "bar_node", route, quote, risk, travel_result), "same committed identity was not deterministic")
	_check(receipt.get("quoted_departure_fare") == 7, "fare was re-quoted from the authored route")
	_check(receipt.get("travel_method_kind") == "bus" and receipt.get("travel_method_label") == "Bus ticket", "actual bus mode was not retained")
	_check(receipt.get("departed_game_clock_minutes") == 620 and receipt.get("arrived_game_clock_minutes") == 640 and receipt.get("base_minutes") == 20 and receipt.get("extra_minutes") == 0, "frozen time was incorrect")
	_check(receipt.get("world_path") == route.world_path and receipt.get("distance_blocks") == 6, "route path/distance was lost")
	_check(receipt.get("origin_environment_id") == "alley_instance_1" and receipt.get("intended_destination_id") == "bar_node" and receipt.get("effective_destination_environment_id") == "bar_instance_1", "journey identity fields were lost")
	_check(receipt.get("receipt_text") == travel_result.message and receipt.get("outcome_label") == "Uneventful travel", "frozen text/normal outcome was lost")
	_check(receipt.get("presentation_key") == ReceiptScript.PRESENTATION_KEY and receipt.get("receipt_pending") == true, "typical pending presentation was not selected")
	state.environment_history_archive_count += 1
	_check(receipt.journey_id != ReceiptScript.build(state, origin, destination, "bar_node", route, quote, risk, travel_result).journey_id, "different travel count reused journey identity")
	state.environment_history_archive_count -= 1
	for mode in ["walk", "bus", "taxi", "night_cab"]:
		var actual_route := route.duplicate(true)
		actual_route["travel_method_kind"] = mode
		var actual := ReceiptScript.build(state, origin, destination, "bar_node", actual_route, quote, risk, travel_result)
		_check(actual.get("travel_method_kind") == mode and actual.get("presentation_key") == ReceiptScript.PRESENTATION_KEY, "mode %s changed the typical scene or was mislabeled" % mode)
	_check(receipt.get("schema_version") == ReceiptScript.SCHEMA_VERSION and receipt.get("origin_label") == "Back Alley" and receipt.get("destination_label") == "The Crooked Glass", "new receipt lost frozen installed labels/schema")
	var generic_origin := origin.duplicate(true)
	generic_origin["archetype_id"] = "corner_store"
	_check(ReceiptScript.build(state, generic_origin, destination, "bar_node", route, quote, risk, travel_result).get("presentation_key") == ReceiptScript.STANDARD_PRESENTATION_KEY, "generic world origin did not select shared presentation")
	_check(ReceiptScript.build(state, destination, origin, "alley_node", route, quote, risk, travel_result).get("presentation_key") == ReceiptScript.STANDARD_PRESENTATION_KEY, "reverse world journey did not select shared presentation")
	_check(ReceiptScript.build(state, origin, destination, "bar_node", route, quote, risk, {"ok": false, "message": "Rejected"}).is_empty(), "failed transaction created receipt")
	quote["cost"] = 99
	route.world_path.append("later_mutation")
	risk["label"] = "Changed risk"
	travel_result["message"] = "Changed result"
	_check(receipt.quoted_departure_fare == 7 and receipt.world_path.size() == 3 and receipt.route_risk.label == "Missed connection" and receipt.receipt_text != travel_result.message, "receipt retained mutable input aliases")
	var triggered_risk := {"triggered": true, "label": "Existing route event", "roll": 3, "chance_percent": 15, "bankroll_delta": -4, "suspicion_delta": 2, "message": "Existing route event happened."}
	var triggered := ReceiptScript.build(state, origin, destination, "bar_node", route, quote, triggered_risk, travel_result)
	_check(triggered.outcome_label == "Existing route event" and triggered.route_risk.bankroll_delta == -4 and triggered.presentation_key == ReceiptScript.STATIC_PRESENTATION_KEY, "triggered route risk was rerolled, lost, or claimed an uneventful animation")
	_check(JSON.stringify(state.to_dict()) == state_before, "risk snapshot applied gameplay effects")
	_check(ReceiptScript.normalize(JSON.parse_string(JSON.stringify(receipt))) == receipt, "receipt JSON normalization did not round-trip")
	_check(ReceiptScript.normalize(ReceiptScript.normalize(receipt)) == receipt, "normalization is not idempotent")
	_check(SchemaScript.serialized_keys().has("travel_journey_receipt"), "canonical schema omitted receipt")
	state.travel_journey_receipt = receipt.duplicate(true)
	var payload := state.to_dict()
	_check(payload.travel_journey_receipt == receipt, "save boundary dropped receipt")
	for snapshot in [state.to_save_snapshot(), state.to_save_snapshot(false), state.to_save_snapshot_for_encoding()]:
		_check(snapshot.get("travel_journey_receipt", {}) == receipt, "optimized save snapshot dropped receipt")
		var captured_receipt: Dictionary = snapshot.get("travel_journey_receipt", {})
		captured_receipt["receipt_pending"] = false
		captured_receipt["world_path"] = ["snapshot mutation"]
		_check(state.travel_journey_receipt == receipt, "optimized save snapshot aliases live receipt")
	_check(state.to_travel_preview_snapshot().get("travel_journey_receipt", {}) == {}, "travel preview retained irrelevant receipt")
	_check_save_service(state, receipt)
	var packed := CodecScript.pack_for_storage(CodecScript.encode(payload))
	var unpacked := CodecScript.decode(CodecScript.unpack_from_storage(JSON.parse_string(JSON.stringify(packed.get("packed", {})))))
	_check(bool(packed.get("ok", false)) and ReceiptScript.normalize(unpacked.get("travel_journey_receipt")) == receipt, "production packed-save codec lost receipt")
	var restored := RunStateScript.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(payload)))
	_check(restored.travel_journey_receipt == receipt, "restore dropped or recomputed frozen receipt")
	_check(restored.bankroll == state.bankroll and restored.rng_state == state.rng_state and restored.game_clock_minutes == state.game_clock_minutes, "receipt restore changed effects/RNG/clock")
	var restored_before := JSON.stringify(restored.to_dict())
	_check(not restored.acknowledge_travel_journey_receipt("stale_id") and JSON.stringify(restored.to_dict()) == restored_before, "stale acknowledgment mutated state")
	_check(restored.acknowledge_travel_journey_receipt(receipt.journey_id) and not restored.travel_journey_receipt.receipt_pending, "acknowledgment did not clear pending")
	_check(restored.acknowledge_travel_journey_receipt(receipt.journey_id), "acknowledgment was not idempotent")
	var acknowledged := RunStateScript.new()
	acknowledged.from_dict(JSON.parse_string(JSON.stringify(restored.to_dict())))
	_check(not acknowledged.travel_journey_receipt.receipt_pending and acknowledged.travel_journey_receipt.receipt_text == receipt.receipt_text, "acknowledgment did not persist")
	_check(acknowledged.bankroll == state.bankroll and acknowledged.rng_state == state.rng_state and acknowledged.game_clock_minutes == state.game_clock_minutes, "acknowledgment replayed effects")
	var candidate := state.detached_host_action_candidate()
	_check(candidate.travel_journey_receipt == receipt, "ordinary turn candidate dropped receipt")
	candidate.travel_journey_receipt["receipt_pending"] = false
	_check(state.travel_journey_receipt.receipt_pending, "ordinary turn candidate aliases receipt")
	var legacy := payload.duplicate(true)
	legacy.erase("travel_journey_receipt")
	restored.from_dict(legacy)
	_check(restored.travel_journey_receipt.is_empty(), "old save did not clear stale receipt")
	restored.travel_journey_receipt = receipt.duplicate(true)
	restored.start_new("NEW-RUN")
	_check(restored.travel_journey_receipt.is_empty(), "new run retained old receipt")
	_check_legacy_receipt(receipt)
	_check_fallbacks(receipt, payload)
	if failures.is_empty():
		print("TRAVEL_JOURNEY_RECEIPT_CHECK PASS (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("TRAVEL_JOURNEY_RECEIPT_CHECK FAIL (%d/%d)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _check_save_service(state: RunState, receipt: Dictionary) -> void:
	# This test writes only into the explicit profile admitted by the QA guard.
	# Never fall back to the editor's real user:// saves when run without it.
	var admitted_root := OS.get_environment("BTH_QA_RUN_DIR").replace("\\", "/").trim_suffix("/")
	var service := SaveServiceScript.new()
	var actual_root := ProjectSettings.globalize_path(service.save_dir()).replace("\\", "/")
	var guarded := not admitted_root.is_empty() and not admitted_root.to_lower().begins_with("c:") \
			and actual_root.to_lower().begins_with(admitted_root.to_lower() + "/")
	_check(guarded, "actual save service test requires an admitted non-C QA profile")
	if not guarded:
		return
	var before := JSON.stringify(state.to_dict())
	var started := service.begin_save_run(state, "travel_receipt_async")
	_check(started == OK, "SaveService.begin_save_run rejected receipt generation")
	if started != OK:
		return
	# The worker owns the generation even if dismissal/new presentation changes
	# the live receipt immediately after the main-thread snapshot is captured.
	state.travel_journey_receipt["receipt_pending"] = false
	state.travel_journey_receipt["receipt_text"] = "A later live presentation"
	_check(service.wait_for_async_save() == OK, "async receipt save did not install")
	state.travel_journey_receipt = receipt.duplicate(true)
	var cold_service := SaveServiceScript.new()
	var loaded: Variant = cold_service.load_run("travel_receipt_async")
	_check(loaded is RunState, "cold SaveService load rejected installed receipt save")
	if loaded is RunState:
		_check(loaded.travel_journey_receipt == receipt, "actual async saved generation lost frozen pending receipt")
		_check(loaded.bankroll == state.bankroll and loaded.rng_state == state.rng_state and loaded.game_clock_minutes == state.game_clock_minutes, "actual async restore replayed travel effects")
		_check(loaded.acknowledge_travel_journey_receipt(receipt.journey_id), "loaded receipt could not acknowledge")
		_check(cold_service.begin_save_run(loaded, "travel_receipt_async") == OK and cold_service.wait_for_async_save() == OK, "acknowledged receipt did not save through actual async path")
		var acknowledged: Variant = SaveServiceScript.new().load_run("travel_receipt_async")
		_check(acknowledged is RunState and acknowledged.travel_journey_receipt.get("receipt_pending", true) == false and acknowledged.travel_journey_receipt.get("receipt_text") == receipt.receipt_text, "actual cold load lost acknowledgment/frozen text")
	_check(service.save_run(state, "travel_receipt_sync") == OK, "synchronous receipt save failed")
	var sync_loaded: Variant = SaveServiceScript.new().load_run("travel_receipt_sync")
	_check(sync_loaded is RunState and sync_loaded.travel_journey_receipt == receipt, "synchronous optimized save dropped receipt")
	_check(JSON.stringify(state.to_dict()) == before, "actual save/load mutated live travel state")


func _check_legacy_receipt(receipt: Dictionary) -> void:
	var legacy := receipt.duplicate(true)
	legacy["schema_version"] = ReceiptScript.LEGACY_SCHEMA_VERSION
	legacy.erase("origin_label")
	legacy.erase("destination_label")
	_check(ReceiptScript.normalize(legacy) == legacy, "v1 save receipt shape/animation did not survive")
	var state := RunStateScript.new()
	state.start_new("LEGACY-TRAVEL-RECEIPT")
	state.travel_journey_receipt = legacy.duplicate(true)
	var restored := RunStateScript.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	_check(restored.travel_journey_receipt == legacy, "v1 receipt did not survive run-state save/load")
	_check(restored.acknowledge_travel_journey_receipt(legacy.journey_id) and not restored.travel_journey_receipt.receipt_pending, "v1 receipt lost once-only acknowledgment")
	legacy["route_risk"]["triggered"] = true
	var risk_receipt := ReceiptScript.normalize(legacy)
	_check(risk_receipt.route_risk.triggered and risk_receipt.presentation_key == ReceiptScript.STATIC_PRESENTATION_KEY, "v1 triggered risk was lost or advertised as uneventful")
	_check(ReceiptScript.normalize(risk_receipt) == risk_receipt, "v1 risk fallback was not idempotent")
	legacy["origin_archetype_id"] = "motel"
	_check(ReceiptScript.normalize(legacy).is_empty(), "v1 eligibility was silently reinterpreted as generic v2")


func _check_fallbacks(receipt: Dictionary, payload: Dictionary) -> void:
	var future := receipt.duplicate(true)
	future["schema_version"] = 99
	future["base_minutes"] = {"execute": "never"}
	var normalized := ReceiptScript.normalize(future)
	_check(normalized.get("presentation_key") == ReceiptScript.STATIC_PRESENTATION_KEY and normalized.get("receipt_text") == receipt.receipt_text, "unknown schema discarded frozen text instead of static fallback")
	_check(not normalized.has("base_minutes") and ReceiptScript.normalize(normalized) == normalized, "unknown schema was interpreted or fallback was unstable")
	var unknown_visual := receipt.duplicate(true)
	unknown_visual["presentation_key"] = "missing_scene_v7"
	_check(ReceiptScript.normalize(unknown_visual).presentation_key == ReceiptScript.STATIC_PRESENTATION_KEY and ReceiptScript.normalize(unknown_visual).receipt_text == receipt.receipt_text, "unknown presentation failed static fallback")
	for invalid in [null, [], "receipt", 1, true, {}, {"receipt_text": "not committed"}]:
		_check(ReceiptScript.normalize(invalid).is_empty(), "malformed root/header was trusted")
	for field in ["schema_version", "journey_id", "receipt_text", "commit_status", "origin_archetype_id", "effective_destination_archetype_id"]:
		var malformed := receipt.duplicate(true)
		malformed[field] = {"malformed": true}
		_check(ReceiptScript.normalize(malformed).is_empty(), "malformed required field %s was trusted" % field)
	var bounded := receipt.duplicate(true)
	bounded["receipt_text"] = "x".repeat(ReceiptScript.MAX_TEXT_LENGTH + 500)
	bounded["receipt_pending"] = "true"
	bounded["quoted_departure_fare"] = INF
	bounded["base_minutes"] = "20"
	bounded["extra_minutes"] = 500
	bounded["travel_method_kind"] = "spaceship"
	bounded["world_path"] = [{"nested": true}, "valid", 42]
	bounded["route_risk"] = {"triggered": "true", "bankroll_delta": [], "message": RefCounted.new()}
	bounded["effects"] = {"bankroll_delta": 1000000}
	normalized = ReceiptScript.normalize(bounded)
	_check(normalized.receipt_text.length() == ReceiptScript.MAX_TEXT_LENGTH and not normalized.receipt_pending, "text bounds or strict pending Boolean failed")
	_check(normalized.quoted_departure_fare == 0 and normalized.base_minutes == 0 and normalized.extra_minutes == 0, "malformed numbers supplied effects/timing")
	_check(normalized.presentation_key == ReceiptScript.STATIC_PRESENTATION_KEY and normalized.travel_method_kind == "unknown", "unknown transport claimed a known visual")
	_check(normalized.world_path == ["valid"] and not normalized.route_risk.triggered and normalized.route_risk.bankroll_delta == 0 and not normalized.has("effects"), "malformed nested payload escaped whitelist")
	for field in ["travel_count", "departed_game_clock_minutes", "arrived_game_clock_minutes", "base_minutes", "extra_minutes", "quoted_departure_fare", "distance_blocks", "world_path", "distance", "travel_method_kind", "travel_method_label", "route_risk", "presentation_key", "receipt_pending", "origin_label", "destination_label"]:
		for bad_value in [null, [], {}, "not a number", INF, NAN, true, -10, RefCounted.new()]:
			var malformed := receipt.duplicate(true)
			malformed[field] = bad_value
			var safe := ReceiptScript.normalize(malformed)
			_check(not safe.is_empty() and ReceiptScript.normalize(safe) == safe, "malformed optional %s did not normalize safely/idempotently" % field)
	var too_many_stops := receipt.duplicate(true)
	too_many_stops["world_path"] = []
	for _index in range(100):
		too_many_stops.world_path.append("node")
	_check(ReceiptScript.normalize(too_many_stops).world_path.size() == ReceiptScript.MAX_PATH_STOPS, "route path was not bounded")
	var malformed_payload := payload.duplicate(true)
	malformed_payload["travel_journey_receipt"] = ["wrong type"]
	var state := RunStateScript.new()
	state.from_dict(malformed_payload)
	_check(state.travel_journey_receipt.is_empty(), "restore accepted malformed field")
	# Both lifecycle snapshot mechanisms must include this ordinary script field.
	var property_found := false
	for property in state.get_property_list():
		if property.get("name") == "travel_journey_receipt" and (int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			property_found = true
	_check(property_found and RunStateScript.TURN_TRANSACTION_COLLECTION_FIELDS.has("travel_journey_receipt"), "runtime lifecycle/turn snapshot coverage omitted receipt")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
