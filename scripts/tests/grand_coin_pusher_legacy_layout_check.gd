extends SceneTree

const Library := preload("res://scripts/core/content_library.gd")
const Run := preload("res://scripts/core/run_state.gd")
const Generator := preload("res://scripts/core/run_generator.gd")
const Placement := preload("res://scripts/core/environment_placement.gd")
const Compatibility := preload("res://scripts/core/grand_coin_pusher_layout_compatibility.gd")
const Publication := preload("res://scripts/core/room_presentation_publication.gd")
const Save := preload("res://scripts/core/save_service.gd")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const StorageJson := preload("res://scripts/core/storage_numeric_json.gd")
const EnvironmentScript := preload("res://scripts/core/environment_instance.gd")
const Manifest := preload("res://scripts/core/environment_object_manifest.gd")
const ScenarioEngine := preload("res://scripts/core/scenario_engine.gd")
const PINNED := "res://scripts/tests/fixtures/pull_tab_grand_historical_89403f389.json"
const BASELINE := "89403f389a5807e050a450cd27b1bd93b3a4a41e"
var failures: Array[String] = []
var checks := 0
var save_comparisons: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var data_root := OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").replace("\\", "/")
	if not data_root.is_absolute_path() or not data_root.to_upper().begins_with("E:/"):
		push_error("Legacy Grand check requires an explicit disposable E: distribution root.")
		quit(2)
		return
	var pinned: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PINNED))
	if not _check(str(pinned.get("source", {}).get("commit", "")) == BASELINE and str(pinned.get("source", {}).get("archetype_blob", "")) == "6d44569ed2af04efba3cb9b7cc7ffc32832203de", "historical catalog has pinned source provenance"):
		quit(1)
		return
	var library := Library.new()
	library.load(false)
	var shipping := library.environment_archetypes.duplicate(true)
	var historical := shipping.duplicate(true)
	for index in range(historical.size()):
		var room_id := str(historical[index].get("id", ""))
		if room_id == "grand_casino":
			historical[index] = pinned.get("archetype", {}).duplicate(true)
		elif room_id == "grand_casino_high_limit":
			historical[index] = pinned.get("high_limit_archetype", {}).duplicate(true)
	library.environment_archetypes = historical
	library.rebuild_content_indexes()
	var run := Run.new()
	var challenge := Run.standard_challenge("GRAND-LEGACY-LAYOUT-AUDIT")
	var challenge_modifiers: Dictionary = challenge.get("modifiers", {}).duplicate(true)
	challenge_modifiers["scenario_pins"] = {"grand_casino": "grand_casino_audit_night"}
	challenge["modifiers"] = challenge_modifiers
	run.start_new("GRAND-LEGACY-LAYOUT-AUDIT", challenge)
	run.narrative_flags["grand_casino_high_limit_access"] = true
	var generator := Generator.new(library)
	var arrival: Dictionary = Fidelity.generate_and_finalize(generator, run, failures, "pinned historical Audit Main", "grand_casino", true)
	if not _check(bool(arrival.get("ok", false)), "historical catalog generates and seals normally"):
		quit(1)
		return
	_check(str(run.current_environment.get("scenario_id", "")) == "grand_casino_audit_night", "active old Audit scenario is exercised")
	var main := _receipt(run.current_environment)
	var main_source_inputs := _manifest_source_inputs(run.current_environment).duplicate(true)
	var old_main := run.current_environment.duplicate(true)
	_check_legacy_room(old_main, "grand_casino")
	_check(generator.enter_grand_casino_room(run, "grand_casino_high_limit"), "historical High Limit generates through its ordinary door")
	var high := _receipt(run.current_environment)
	var high_source_inputs := _manifest_source_inputs(run.current_environment).duplicate(true)
	var old_high := run.current_environment.duplicate(true)
	_check_legacy_room(old_high, "grand_casino_high_limit")
	# The old definitions are solely declared initial test input. All persistence,
	# return, finalization and fresh generation below use the shipping library.
	library.environment_archetypes = shipping
	library.rebuild_content_indexes()
	_check(library.environment_archetype("grand_casino").get("game_pool", []).has("coin_pusher"), "shipping catalog restored before save/load")
	var wallets := {"cash": run.bankroll, "chips": run.grand_casino_chips, "custody": run.portable_ticket_piles.duplicate(true)}
	var save := Save.new()
	_check(save.save_run(run, "grand_legacy_high") == OK, "save old High Limit with shipping catalog")
	var loaded: RunState = save.load_run("grand_legacy_high")
	if not _check(loaded != null, "cold-normalization path loads old rooms under shipping catalog"):
		quit(1)
		return
	_check(bool(Fidelity.finalize_arrival(loaded, library, failures, "shipping old High reload").get("ok", false)), "old High publication authenticates")
	_check_saved_receipt(_receipt(loaded.current_environment), high, "old High state and immutable seals survive reload", loaded.current_environment, high_source_inputs)
	var restored := Generator.new(library)
	# An ordinary casino return refreshes world-map route choices. Its manifest
	# source includes next_archetypes, although cabinet and immutable scenario
	# authority do not change. Derive that exact expected delta on a detached
	# trusted baseline through the same production route owner, followed by the
	# scenario's materialization of its sealed route projection. Reentry restores
	# travel_hooks from that projection while retaining current next_archetypes.
	# Retain every original machine/slot/semantic/layout proof in the comparison.
	var expected_main_environment := old_main.duplicate(true)
	restored._apply_world_travel_targets(expected_main_environment, loaded, loaded.world_map, "grand_casino")
	ScenarioEngine._materialize_sequence_services_games_routes(expected_main_environment, old_main.get("scenario_sequence_projection", {}))
	var expected_main_inputs := _manifest_source_inputs(expected_main_environment).duplicate(true)
	var expected_main_return := main.duplicate(true)
	expected_main_return["manifest_source_digest"] = Manifest._fingerprint(expected_main_inputs)
	_check(restored.enter_grand_casino_room(loaded, "grand_casino"), "shipping door restores cached historical Main")
	_check_legacy_room(loaded.current_environment, "grand_casino")
	_check_saved_receipt(_receipt(loaded.current_environment), expected_main_return, "old Main ticket machine and Audit seals survive return with canonical world routes", loaded.current_environment, expected_main_inputs)
	var route_projection := {"owners": ["RunGenerator._apply_world_travel_targets", "ScenarioEngine._materialize_sequence_services_games_routes"], "initial_next_archetypes": main_source_inputs.get("next_archetypes", []), "expected_next_archetypes": expected_main_inputs.get("next_archetypes", []), "actual_next_archetypes": loaded.current_environment.get("next_archetypes", []), "initial_travel_hooks": main_source_inputs.get("travel_hooks", []), "expected_travel_hooks": expected_main_inputs.get("travel_hooks", []), "actual_travel_hooks": loaded.current_environment.get("travel_hooks", []), "initial_manifest_source_digest": main.get("manifest_source_digest", ""), "expected_manifest_source_digest": expected_main_return.get("manifest_source_digest", ""), "actual_manifest_source_digest": loaded.current_environment.get("object_manifest", {}).get("source_digest", "")}
	var audit_presave := _receipt(loaded.current_environment)
	var audit_presave_inputs := _manifest_source_inputs(loaded.current_environment).duplicate(true)
	_check(save.save_run(loaded, "grand_legacy_audit") == OK, "save active historical Audit with shipping catalog")
	loaded = save.load_run("grand_legacy_audit")
	if not _check(loaded != null, "active historical Audit reloads"):
		quit(1)
		return
	_check(bool(Fidelity.finalize_arrival(loaded, library, failures, "shipping old Audit reload").get("ok", false)), "old Audit saved proof authenticates without replacement")
	_check_saved_receipt(_receipt(loaded.current_environment), audit_presave, "old Audit machine and immutable proof remain exact across save/reload", loaded.current_environment, audit_presave_inputs)
	_check(loaded.bankroll == int(wallets.cash) and loaded.grand_casino_chips == int(wallets.chips) and loaded.portable_ticket_piles == wallets.custody, "legacy preservation does not spend, award or move ticket custody")
	_check_negative_proofs(loaded, library)
	var fresh := Run.new()
	fresh.start_new("GRAND-CURRENT-AFTER-LEGACY")
	var fresh_generator := Generator.new(library)
	_check(bool(Fidelity.generate_and_finalize(fresh_generator, fresh, failures, "fresh shipping Main", "grand_casino", true).get("ok", false)), "fresh shipping room generates after legacy cache use")
	_check(fresh.current_environment.get("game_ids", []).has("coin_pusher") and not fresh.current_environment.get("game_ids", []).has("pull_tabs"), "fresh shipping Main retains the new catalog")
	var new_digest := str(fresh.current_environment.get("layout", {}).get("slot_map_digest", ""))
	_check(new_digest != str(main.slot_map_digest), "legacy and current slot maps are distinct")
	for repeat in range(2):
		_check(str(Placement.surface_map(old_main).get("fixed_object_slot_ids", {}).get("game:pull_tabs", "")) == "fixed.game_machine_5", "legacy cache retains old slot " + str(repeat))
		_check(str(Placement.surface_map(fresh.current_environment).get("fixed_object_slot_ids", {}).get("game:coin_pusher", "")) == "fixed.game_machine_5", "current cache retains new slot " + str(repeat))
	var hidden := old_main.duplicate(true)
	hidden["game_ids"].erase("pull_tabs")
	_check(Compatibility.profile_id(hidden) == Compatibility.MAIN, "temporarily hidden old machine retains baseline layout profile")
	for flag in ["practice_session", "environment_test_session"]:
		var preview := old_main.duplicate(true)
		preview.get("local_narrative_flags", {})[flag] = true
		_check(Compatibility.profile_id(preview).is_empty(), flag + " stays on current authoring/practice layout")
	for policy in ["scenario_sequence_base_game_modifiers", "local_narrative_flags"]:
		var modern_high := old_high.duplicate(true)
		if policy == "local_narrative_flags":
			modern_high[policy]["coin_pusher_drop_cost"] = 5
			modern_high[policy]["coin_pusher_coin_value"] = 5
		else:
			modern_high[policy] = {"coin_pusher": {"drop_cost": 5, "coin_value": 5}}
		_check(Compatibility.profile_id(modern_high).is_empty(), "modern High cabinet temporarily removed cannot select legacy map: " + str(policy))
	print("GRAND_COIN_PUSHER_LEGACY_LAYOUT_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "baseline": BASELINE, "old_main": _proof_receipt(main), "old_high": _proof_receipt(high), "main_return_route_projection": route_projection, "save_comparisons": save_comparisons, "scope": "Synthetic declared pre-change catalogs; shipping-library save/reload/return; complete state and immutable seals preserved with normal world-route refresh predicted by its production owner; negative finalization controls; no original campaign or rendered Web claim."}))
	quit(0 if failures.is_empty() else 1)


func _receipt(environment: Dictionary) -> Dictionary:
	var stored: Dictionary = Run._environment_for_persistent_storage(environment)
	return {"game_ids": environment.get("game_ids", []).duplicate(), "game_states": stored.get("game_states", {}).duplicate(true), "slot_map_digest": environment.get("layout", {}).get("slot_map_digest", ""), "manifest_source_digest": environment.get("object_manifest", {}).get("source_digest", ""), "semantic_version": environment.get("scenario_semantic_inventory_version", 0), "semantic_digest": environment.get("scenario_semantic_digest", ""), "layout_authority_digest": environment.get("scenario_layout_authority_digest", "")}


func _check_saved_receipt(actual: Dictionary, expected: Dictionary, context: String, actual_environment: Dictionary, expected_source_inputs: Dictionary) -> void:
	# Include the complete receipt and machine state on both sides; the normal
	# JSON integer-to-float representation is the sole comparison boundary.
	var actual_transport := StorageJson.parse(StorageJson.stringify(actual))
	var expected_transport := StorageJson.parse(StorageJson.stringify(expected))
	var actual_text := StorageJson.stringify(actual_transport.get("data"))
	var expected_text := StorageJson.stringify(expected_transport.get("data"))
	var equal_transport := int(actual_transport.get("error", FAILED)) == OK and int(expected_transport.get("error", FAILED)) == OK and actual_text == expected_text
	_check(equal_transport, context)
	var diagnostic := {"context": context, "raw_equal": actual == expected, "canonical_json_equal": equal_transport, "comparison": "complete full-precision storage JSON transport on both inputs", "actual_transport_sha256": actual_text.sha256_text(), "expected_transport_sha256": expected_text.sha256_text()}
	if not equal_transport:
		var changes: Array = []
		_saved_receipt_difference_paths(expected_transport.get("data"), actual_transport.get("data"), "$", changes)
		diagnostic["reported_changes"] = changes
		diagnostic["change_cap"] = 20
		diagnostic["actual_proof"] = _proof_receipt(actual)
		diagnostic["expected_proof"] = _proof_receipt(expected)
		var actual_source_inputs := _manifest_source_inputs(actual_environment)
		var source_changes: Array = []
		var expected_source_transport := StorageJson.parse(StorageJson.stringify(expected_source_inputs))
		var actual_source_transport := StorageJson.parse(StorageJson.stringify(actual_source_inputs))
		_saved_receipt_difference_paths(expected_source_transport.get("data"), actual_source_transport.get("data"), "$source", source_changes)
		diagnostic["source_input_changes"] = source_changes
		diagnostic["expected_source_recomputed"] = Manifest._fingerprint(expected_source_inputs)
		diagnostic["actual_source_recomputed"] = Manifest._fingerprint(actual_source_inputs)
		diagnostic["expected_source_mirror_matches"] = Manifest._fingerprint(expected_source_inputs) == str(expected.get("manifest_source_digest", ""))
		diagnostic["actual_source_mirror_matches"] = Manifest._fingerprint(actual_source_inputs) == str(actual.get("manifest_source_digest", ""))
	save_comparisons.append(diagnostic)


func _saved_receipt_difference_paths(before: Variant, after: Variant, path: String, rows: Array, depth: int = 0) -> void:
	if rows.size() >= 20 or depth > 48 or before == after:
		return
	if typeof(before) == TYPE_DICTIONARY and typeof(after) == TYPE_DICTIONARY:
		var keys: Array = before.keys()
		for key in after.keys():
			if not keys.has(key):
				keys.append(key)
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		for key in keys:
			if rows.size() >= 20:
				return
			var child_path := path + "." + str(key)
			if not before.has(key) or not after.has(key):
				rows.append({"path": child_path, "before_present": before.has(key), "after_present": after.has(key), "before": _saved_receipt_diagnostic_value(before.get(key)), "after": _saved_receipt_diagnostic_value(after.get(key))})
			else:
				_saved_receipt_difference_paths(before[key], after[key], child_path, rows, depth + 1)
		return
	if typeof(before) == TYPE_ARRAY and typeof(after) == TYPE_ARRAY:
		if before.size() != after.size():
			rows.append({"path": path + ".length", "before": before.size(), "after": after.size()})
		for index in range(mini(before.size(), after.size())):
			_saved_receipt_difference_paths(before[index], after[index], "%s[%d]" % [path, index], rows, depth + 1)
		return
	rows.append({"path": path, "before": _saved_receipt_diagnostic_value(before), "after": _saved_receipt_diagnostic_value(after)})


func _saved_receipt_diagnostic_value(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return {"type": "Dictionary", "size": value.size(), "first_keys": value.keys().slice(0, 6)}
	if typeof(value) == TYPE_ARRAY or typeof(value) >= TYPE_PACKED_BYTE_ARRAY:
		return {"type": type_string(typeof(value)), "size": value.size()}
	var text := StorageJson.stringify(value)
	return {"type": type_string(typeof(value)), "value": text.substr(0, 160), "text_length": text.length()}


func _proof_receipt(receipt: Dictionary) -> Dictionary:
	var proof := receipt.duplicate(false)
	proof.erase("game_states")
	proof["machine_state_sha256"] = var_to_bytes(receipt.get("game_states", {})).hex_encode().sha256_text()
	return proof


func _check_legacy_room(environment: Dictionary, room_id: String) -> void:
	_check(str(environment.get("archetype_id", "")) == room_id, "old room identity " + room_id)
	_check(not environment.get("game_ids", []).has("coin_pusher"), room_id + " keeps prior offerings without an added cabinet")
	_check(environment.get("game_ids", []).has("pull_tabs") == (room_id == "grand_casino"), room_id + " keeps its original Pull Tabs selection")
	_check(bool(Publication.validate(environment).get("ok", false)), room_id + " full published authority validates")


func _check_negative_proofs(source: RunState, library: ContentLibrary) -> void:
	for field in ["object_manifest_digest", "slot_binding_digest", "scenario_semantic_digest", "scenario_layout_authority_digest"]:
		var damaged := Run.new()
		damaged.from_dict(source.to_dict())
		damaged.current_environment["scenario_restore_pending_trusted_rebuild"] = true
		if field == "slot_binding_digest":
			damaged.current_environment["layout"][field] = "0".repeat(64)
		else:
			damaged.current_environment[field] = "0".repeat(64)
		var result: Dictionary = damaged.scenario_finalize_installed_environment(library)
		_check(not bool(result.get("ok", false)), "normal finalization rejects damaged legacy " + field)
		var retained: String = damaged.current_environment.get("layout", {}).get(field, "") if field == "slot_binding_digest" else damaged.current_environment.get(field, "")
		_check(retained == "0".repeat(64), "compatibility does not re-sign damaged legacy " + field)


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
	return ok



# Test-only mirror of the complete production manifest source inputs. Recomputed
# fingerprints are reported beside both saved source digests to validate it.
func _manifest_source_inputs(environment: Dictionary) -> Dictionary:
	var surface_map := Placement.surface_map(environment)
	var active_entries := EnvironmentScript._physical_manifest_layout_entries(environment, surface_map)
	var offer_ids: Array = []
	for offer_value in Manifest._array(environment.get("item_offers", [])):
		var offer_id := str(Manifest._dict(offer_value).get("id", "")).strip_edges()
		if not offer_id.is_empty():
			offer_ids.append(offer_id)
	var container_ids: Array = []
	for container_value in Manifest._array(environment.get("home_containers", [])):
		var container_id := str(Manifest._dict(container_value).get("id", "")).strip_edges()
		if not container_id.is_empty():
			container_ids.append(container_id)
	var state := Manifest._dict(environment.get("scenario_state", {}))
	var sequence_state := Manifest._dict(environment.get("scenario_sequence_state", {}))
	var resolved_event_ids := Manifest._strings(environment.get("resolved_event_ids", []))
	resolved_event_ids.sort()
	var semantic := Manifest._dict(sequence_state.get("semantic_state", {}))
	# Manifest rows already seal the concrete scenario presentation. The source
	# digest must use the same durable sequence proof saved by EnvironmentInstance,
	# otherwise a valid save (which intentionally strips rebuilt semantic visuals)
	# looks stale and loses every scenario slot on its first restore.
	var durable_semantic := semantic.duplicate(true)
	for transient_key in [
		"target_inventory", "declared_targets", "base_interactions", "event_choices",
		"scene_objects", "interactions", "actors", "services", "games", "routes",
		"transition_queue", "tombstones",
	]:
		durable_semantic.erase(transient_key)
	var scenario_source := {
		"scenario_id": str(state.get("id", sequence_state.get("scenario_id", environment.get("scenario_id", "")))),
		"phase_index": int(state.get("phase_index", environment.get("scenario_phase_index", 0))),
		# A legacy phase's action counter advances between physical transitions.
		# Hash the phase identity, not that presentation-neutral clock, so ordinary
		# turns cannot invalidate an otherwise unchanged physical inventory.
		"status": str(sequence_state.get("status", "")),
		"phase_id": str(sequence_state.get("phase_id", "")),
		"boundary_serial": int(sequence_state.get("boundary_serial", 0)),
		"durable_semantic": durable_semantic,
	}
	var entry_source: Array = []
	for entry_value in active_entries:
		var entry := Manifest._dict(entry_value)
		# Runtime-owned rows are a live projection of RunState authorities such as
		# Crew residency, delivery position, the Numbers itinerary, and Grand Casino
		# floor movement. Their concrete rows remain sealed by the manifest digest,
		# but they must not invalidate the durable source seal used to retain scenario
		# rows while a saved renderer snapshot is absent. This lets persistence omit
		# offscreen runtime projections and rebuild them on installation without
		# discarding otherwise valid scenario-family inventory.
		if not str(entry.get("runtime_owner", "")).strip_edges().is_empty() \
				or str(entry.get("spot_field", "")).strip_edges() == "runtime_object_manifest_entries":
			continue
		entry_source.append({
			"object_id": str(entry.get("object_id", "")),
			"object_type": str(entry.get("object_type", "")),
			"index": int(entry.get("index", 0)),
			"placement_class": str(entry.get("placement_class", "")),
			"slot_family": str(entry.get("slot_family", entry.get("family", ""))),
			"render_key": str(entry.get("render_key", "")),
			"spot_field": str(entry.get("spot_field", "")),
			"metadata": Manifest._dict(entry.get("metadata", {})),
			"active": bool(entry.get("active", true)),
		})
	entry_source.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		return str(Manifest._dict(left_value).get("object_id", "")) < str(Manifest._dict(right_value).get("object_id", ""))
	)
	return {
		"schema_version": Manifest.SCHEMA_VERSION,
		"environment_id": str(environment.get("id", "")),
		"archetype_id": str(environment.get("archetype_id", "")),
		"layer_id": str(environment.get("current_layer_id", "")),
		"game_ids": Manifest._strings(environment.get("game_ids", [])),
		"event_ids": Manifest._strings(environment.get("event_ids", [])),
		"resolved_event_ids": resolved_event_ids,
		"item_offer_ids": offer_ids,
		"service_ids": Manifest._strings(environment.get("service_ids", [])),
		"lender_hooks": Manifest._strings(environment.get("lender_hooks", [])),
		"object_fixtures": Manifest._strings(environment.get("object_fixtures", [])),
		"travel_hooks": Manifest._strings(environment.get("travel_hooks", [])),
		"next_archetypes": Manifest._strings(environment.get("next_archetypes", [])),
		"layer_transitions": Manifest._array(environment.get("layer_transitions", [])),
		"home_container_ids": container_ids,
		"home_lost": bool(environment.get("home_lost", false)),
		"active_entries": entry_source,
		"fixed_objects": Manifest._fixed_declarations(surface_map),
		"object_family_ids": Manifest._dict(surface_map.get("object_family_ids", {})),
		"fixed_object_slot_ids": Manifest._dict(surface_map.get("fixed_object_slot_ids", {})),
		"fixed_category_slot_ids": Manifest._dict(surface_map.get("fixed_category_slot_ids", {})),
		"event_object_slot_ids": Manifest._dict(surface_map.get("event_object_slot_ids", {})),
		"event_category_slot_ids": Manifest._dict(surface_map.get("event_category_slot_ids", {})),
		"scenario_object_slot_ids": Manifest._dict(surface_map.get("scenario_object_slot_ids", {})),
		"scenario_category_slot_ids": Manifest._dict(surface_map.get("scenario_category_slot_ids", {})),
		"exit_object_slot_ids": Manifest._dict(surface_map.get("exit_object_slot_ids", {})),
		"exit_category_slot_ids": Manifest._dict(surface_map.get("exit_category_slot_ids", {})),
		"scenario": scenario_source,
	}
