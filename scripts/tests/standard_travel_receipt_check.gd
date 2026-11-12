extends SceneTree

const Receipt := preload("res://scripts/core/travel_journey_receipt.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const World := preload("res://scripts/core/world_map.gd")
const SaveServiceScript := preload("res://scripts/core/save_service.gd")

var failures: Array[String] = []
var checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := RunStateScript.new()
	state.start_new("STANDARD-RECEIPT-CHECK")
	state.game_clock_minutes = 740
	var state_before := var_to_bytes(state.to_dict())
	var environments := [
		_environment("corner_store", "All-Night Market"),
		_environment("motel", "Vacancy Motel"),
		_environment("bar", "Low Tide Bar"),
		_environment("beach", "The Beach"),
		_environment("delta_queen", "The River Queen"),
		_environment("grand_casino", "Grand Casino Main Floor"),
		_environment("grand_casino_high_limit", "The Gilded Room", "grand_casino"),
	]
	var last_receipt: Dictionary = {}
	for origin in environments:
		for destination in environments:
			if origin.world_node_id == destination.world_node_id:
				continue
			for mode in Receipt.STANDARD_METHOD_KINDS:
				var route := _route(mode, origin.world_node_id, destination.world_node_id)
				var inputs_before := var_to_bytes([origin, destination, route])
				seed(7825)
				var expected_rng := randi()
				seed(7825)
				var receipt := _build(state, origin, destination, route)
				_expect(randi() == expected_rng, "build must not consume RNG")
				_expect(not receipt.is_empty() and receipt.get("presentation_key") == Receipt.STANDARD_PRESENTATION_KEY, "all standard world pairs use shared presentation")
				_expect(receipt.get("travel_method_kind") == mode and receipt.get("travel_method_label") == World.travel_method_label(mode), "receipt preserves actual canonical mode")
				_expect(receipt.get("origin_label") == origin.display_name and receipt.get("destination_label") == destination.display_name, "receipt freezes installed display names")
				_expect(receipt.get("origin_archetype_id") == origin.archetype_id and receipt.get("effective_destination_archetype_id") == destination.archetype_id, "receipt preserves actual archetypes including Grand subrooms")
				_expect(receipt.get("origin_node_id") == origin.world_node_id and receipt.get("effective_destination_node_id") == destination.world_node_id and receipt.get("intended_destination_id") == destination.world_node_id, "receipt distinguishes world and installed environment identity")
				_expect(receipt.get("quoted_departure_fare") == 3 and receipt.get("base_minutes") == 20 and receipt.get("extra_minutes") == 0, "receipt preserves committed quote/time")
				_expect(var_to_bytes([origin, destination, route]) == inputs_before and var_to_bytes(state.to_dict()) == state_before, "build does not mutate state or input")
				_expect(Receipt.normalize(JSON.parse_string(JSON.stringify(receipt))) == receipt and Receipt.normalize(receipt) == receipt, "generic receipts round-trip idempotently")
				last_receipt = receipt
	_check_local_exclusions(state)
	_check_transport_fallbacks(state)
	_check_frozen_labels(state)
	_check_generic_save(state, last_receipt)
	if failures.is_empty():
		print("STANDARD_TRAVEL_RECEIPT_CHECK PASS (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("STANDARD_TRAVEL_RECEIPT_CHECK FAIL (%d/%d)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _check_local_exclusions(state: RunState) -> void:
	var origin := _environment("motel_room", "Your Motel Room")
	var destination := _environment("motel", "Vacancy Motel")
	for local_label in ["Door", "Inside", "Begin", " door ", "INSIDE"]:
		for field in ["travel_method", "method", "travel_method_kind"]:
			var route := _route("walk", origin.world_node_id, destination.world_node_id)
			route[field] = local_label
			_expect(_build(state, origin, destination, route).is_empty(), "local/meta label must precede canonical walk fallback")
	for flag in ["local_casino_room", "local_door", "local_child_area_transition"]:
		var route := _route("walk", origin.world_node_id, destination.world_node_id)
		route[flag] = true
		_expect(_build(state, origin, destination, route).is_empty(), "explicit local route flag cannot become a world animation")
	var excluded_by_host := _route("walk", origin.world_node_id, destination.world_node_id)
	excluded_by_host["presentation_world_travel"] = false
	_expect(_build(state, origin, destination, excluded_by_host).is_empty(), "host raw local classification survives canonical mode overwrite")
	for invalid_scope in [null, "true", 1, {}, []]:
		excluded_by_host["presentation_world_travel"] = invalid_scope
		_expect(_build(state, origin, destination, excluded_by_host).is_empty(), "malformed explicit host scope must not enable a world animation")
	var grand_main := _environment("grand_casino", "Grand Casino Main Floor")
	var grand_room := _environment("grand_casino_high_limit", "The Gilded Room", "grand_casino")
	var same_node := _route("walk", "grand_casino", "grand_casino")
	_expect(_build(state, grand_main, grand_room, same_node).is_empty(), "Grand room movement shares one world node, even without Inside label")
	var legacy_room := grand_room.duplicate(true)
	legacy_room.world_node_id = "grand_casino_high_limit"
	var inside_route := same_node.duplicate(true)
	inside_route["travel_method"] = "Inside"
	inside_route["target_node_id"] = "grand_casino"
	_expect(_build(state, grand_main, legacy_room, inside_route).is_empty(), "legacy Grand room identity must still honor Inside scope")
	for field in ["world_node_id", "archetype_id", "id"]:
		var invalid := origin.duplicate(true)
		invalid.erase(field)
		_expect(_build(state, invalid, destination, _route("bus", "motel_room", "motel")).is_empty(), "missing installed identity cannot prove world travel")
	var meta := destination.duplicate(true)
	meta["kind"] = "meta"
	_expect(_build(state, origin, meta, _route("walk", "motel_room", "motel")).is_empty(), "meta environment cannot become a run journey")
	for invalid_result in [{"ok": false, "message": "Rejected"}, {"ok": "true", "message": "Malformed"}, {"message": ""}]:
		_expect(Receipt.build(state, origin, destination, "motel", _route("bus", "motel_room", "motel"), {"cost": 3}, {}, invalid_result).is_empty(), "failed/rejected transaction cannot create pending receipt")


func _check_transport_fallbacks(state: RunState) -> void:
	var origin := _environment("corner_store", "Night Market")
	var destination := _environment("bar", "Low Tide Bar")
	for mode in Receipt.STANDARD_METHOD_KINDS:
		var legacy := _route(mode, "corner_store", "bar")
		legacy.erase("travel_method_kind")
		_expect(_build(state, origin, destination, legacy).get("travel_method_kind") == mode, "known legacy mode copy remains supported")
	for unknown in ["spaceship", "", "unsupported ride"]:
		for distance in ["near", "remote", "unrecognized", ""]:
			var route := _route("taxi", "corner_store", "bar")
			route.travel_method_kind = unknown
			route.distance = distance
			var receipt := _build(state, origin, destination, route)
			_expect(receipt.get("travel_method_kind") == "unknown" and receipt.get("presentation_key") == Receipt.STATIC_PRESENTATION_KEY, "unknown explicit mode cannot inherit a known mode from label/distance")
	var unknown_route := {"id": "bar", "travel_method": "Unrecognized conveyance", "distance": "remote"}
	var unknown_receipt := _build(state, origin, destination, unknown_route)
	_expect(unknown_receipt.get("travel_method_kind") == "unknown" and unknown_receipt.get("presentation_key") == Receipt.STATIC_PRESENTATION_KEY, "unrecognized legacy mode must not default to night cab")
	var risk := {"triggered": true, "id": "travel_shakedown", "label": "Shortcut Shakedown", "roll": 8, "chance_percent": 35, "bankroll_delta": -8, "suspicion_delta": 4, "message": "The existing shakedown happened."}
	var before := var_to_bytes(state.to_dict())
	var triggered := _build(state, origin, destination, _route("bus", "corner_store", "bar"), risk)
	_expect(triggered.route_risk == risk and triggered.outcome_label == risk.label and triggered.presentation_key == Receipt.STATIC_PRESENTATION_KEY, "triggered risk keeps accurate frozen outcome with static presentation")
	_expect(Receipt.normalize(triggered) == triggered and var_to_bytes(state.to_dict()) == before, "risk fallback must be idempotent and never apply consequences")
	var future := triggered.duplicate(true)
	future.schema_version = Receipt.SCHEMA_VERSION + 1
	future["origin_label"] = "Future field with unknown semantics"
	var safe := Receipt.normalize(future)
	_expect(safe.get("receipt_text") == triggered.receipt_text and safe.get("presentation_key") == Receipt.STATIC_PRESENTATION_KEY and not safe.has("origin_label") and not safe.has("route_risk"), "future schemas preserve only trusted text envelope")


func _check_frozen_labels(state: RunState) -> void:
	var origin := _environment("corner_store", "The Actual Corner Shop")
	var destination := _environment("bar", "The Actual Generated Bar")
	var route := _route("bus", "corner_store", "bar")
	route["label"] = "Authored Roadside Bar"
	var receipt := _build(state, origin, destination, route)
	origin.display_name = "Changed origin"
	destination.display_name = "Changed destination"
	_expect(receipt.origin_label == "The Actual Corner Shop" and receipt.destination_label == "The Actual Generated Bar", "labels must come from installed environments and never retain mutable aliases")
	var oversized := receipt.duplicate(true)
	oversized.origin_label = "x".repeat(Receipt.MAX_LABEL_LENGTH + 100)
	oversized.destination_label = {"execute": "never"}
	var bounded := Receipt.normalize(oversized)
	_expect(bounded.origin_label.length() == Receipt.MAX_LABEL_LENGTH and bounded.destination_label == "Bar" and Receipt.normalize(bounded) == bounded, "label fields must be bounded, whitelisted and idempotent")


func _check_generic_save(state: RunState, receipt: Dictionary) -> void:
	state.travel_journey_receipt = receipt.duplicate(true)
	var admitted_root := OS.get_environment("BTH_QA_RUN_DIR").replace("\\", "/").trim_suffix("/")
	var service := SaveServiceScript.new()
	var actual_root := ProjectSettings.globalize_path(service.save_dir()).replace("\\", "/")
	var guarded := not admitted_root.is_empty() and not admitted_root.to_lower().begins_with("c:") \
			and actual_root.to_lower().begins_with(admitted_root.to_lower() + "/")
	_expect(guarded, "generic save check requires admitted non-C profile")
	if not guarded:
		return
	var before := var_to_bytes(state.to_dict())
	_expect(service.begin_save_run(state, "standard_receipt") == OK and service.wait_for_async_save() == OK, "generic receipt commits through actual async save")
	var cold: Variant = SaveServiceScript.new().load_run("standard_receipt")
	_expect(cold is RunState, "generic receipt cold load succeeds")
	if cold is RunState:
		_expect(cold.travel_journey_receipt == receipt, "generic receipt preserves frozen identity, labels, mode, risk and timing on disk")
		_expect(not cold.acknowledge_travel_journey_receipt("old-id") and cold.acknowledge_travel_journey_receipt(receipt.journey_id) and cold.acknowledge_travel_journey_receipt(receipt.journey_id), "generic receipt acknowledgment is scoped and idempotent")
		_expect(service.save_run(cold, "standard_receipt") == OK, "acknowledged generic receipt saves")
		var acknowledged: Variant = SaveServiceScript.new().load_run("standard_receipt")
		_expect(acknowledged is RunState and not acknowledged.travel_journey_receipt.receipt_pending and acknowledged.travel_journey_receipt.destination_label == receipt.destination_label, "generic acknowledgment and labels persist")
		_expect(cold.bankroll == state.bankroll and cold.rng_state == state.rng_state and cold.game_clock_minutes == state.game_clock_minutes, "generic restore/ack must not replay gameplay")
	_expect(var_to_bytes(state.to_dict()) == before, "generic save must not mutate live state")


func _environment(archetype: String, label: String, world_node: String = "") -> Dictionary:
	return {"id": archetype + "_instance", "archetype_id": archetype, "world_node_id": world_node if not world_node.is_empty() else archetype, "display_name": label}


func _route(mode: String, origin: String, destination: String) -> Dictionary:
	return {"id": destination, "target_node_id": destination, "travel_method_kind": mode, "travel_method": World.travel_method_label(mode), "distance": "far", "distance_blocks": 10, "world_path": [origin, destination], "travel_minutes": 20, "departed_game_clock_minutes": 720, "arrived_game_clock_minutes": 740, "cost": 99}


func _build(state: RunState, origin: Dictionary, destination: Dictionary, route: Dictionary, risk: Dictionary = {}) -> Dictionary:
	return Receipt.build(state, origin, destination, destination.world_node_id, route, {"cost": 3}, risk, {"message": "Committed journey to " + destination.display_name + "."})


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
