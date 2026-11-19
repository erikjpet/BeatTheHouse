extends SceneTree

const Library := preload("res://scripts/core/content_library.gd")
const Run := preload("res://scripts/core/run_state.gd")
const Generator := preload("res://scripts/core/run_generator.gd")
const EnvironmentScript := preload("res://scripts/core/environment_instance.gd")
const Slots := preload("res://scripts/core/environment_slot_binder.gd")
const Semantics := preload("res://scripts/core/environment_base_semantic_records.gd")
const Save := preload("res://scripts/core/save_service.gd")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const StorageJson := preload("res://scripts/core/storage_numeric_json.gd")

var failures: Array[String] = []
var checks := 0
var cases: Array = []
var reload_diagnostics: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# SaveService writes only to the disposable profile admitted by the QA launcher.
	var data_root := OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").replace("\\", "/")
	if not data_root.is_absolute_path() or not data_root.to_upper().begins_with("E:/"):
		push_error("Grand pusher room check requires an explicit disposable E: distribution root.")
		quit(2)
		return
	var library := Library.new()
	library.load(false)
	var first_generated: Dictionary = {}
	var seeds := ["GRAND-PUSHER-ROOM-A", "GRAND-PUSHER-ROOM-B", "GRAND-PUSHER-ROOM-C", "GRAND-PUSHER-ROOM-A"]
	for index in range(seeds.size()):
		var seed := str(seeds[index])
		var run := Run.new()
		run.start_new(seed)
		# Synthetic initial access only; production generation, room doors, state
		# storage, save codec and restoration own everything after this point.
		run.narrative_flags["grand_casino_high_limit_access"] = true
		var generator := Generator.new(library)
		var arrival: Dictionary = Fidelity.generate_and_finalize(generator, run, failures, seed + " Main arrival", "grand_casino", true)
		if not _check(bool(arrival.get("ok", false)), seed + " normal Main generation/finalization"):
			continue
		_check_room(run.current_environment, library, "grand_casino", seed + " generated Main")
		var main := _machine(run.current_environment).duplicate(true)
		if not _check(generator.enter_grand_casino_room(run, "grand_casino_high_limit"), seed + " ordinary High Limit room entry"):
			continue
		_check_room(run.current_environment, library, "grand_casino_high_limit", seed + " generated High Limit")
		var high := _machine(run.current_environment).duplicate(true)
		var generated := {"main": main, "high": high}
		if index == 0:
			first_generated = generated.duplicate(true)
		elif index == seeds.size() - 1:
			_check(generated == first_generated, seed + " repeat seed preserves both generated machines")
		var wallets := {"cash": run.bankroll, "chips": run.grand_casino_chips}
		for repeat in range(2):
			if not _check(generator.enter_grand_casino_room(run, "grand_casino"), seed + " return Main " + str(repeat)):
				break
			_check_room(run.current_environment, library, "grand_casino", seed + " returned Main")
			_check(_machine(run.current_environment) == main, seed + " Main retains its own machine state")
			if not _check(generator.enter_grand_casino_room(run, "grand_casino_high_limit"), seed + " return High Limit " + str(repeat)):
				break
			_check_room(run.current_environment, library, "grand_casino_high_limit", seed + " returned High Limit")
			_check(_machine(run.current_environment) == high, seed + " High Limit retains its own machine state")
		var save := Save.new()
		var slot := "grand_coin_pusher_rooms_" + str(index)
		if not _check(save.save_run(run, slot) == OK, seed + " ordinary generated-room save"):
			continue
		var loaded: RunState = save.load_run(slot)
		if not _check(loaded != null, seed + " ordinary generated-room reload"):
			continue
		var restored_generator := Generator.new(library)
		var finalized: Dictionary = Fidelity.finalize_arrival(loaded, library, failures, seed + " reload finalization")
		if not _check(bool(finalized.get("ok", false)), seed + " reload finalizes"):
			continue
		_check_room(loaded.current_environment, library, "grand_casino_high_limit", seed + " reloaded High Limit")
		_check_machine_reload(_machine(loaded.current_environment), high, seed + " reload preserves High Limit state")
		if _check(restored_generator.enter_grand_casino_room(loaded, "grand_casino"), seed + " reloaded return Main"):
			_check_room(loaded.current_environment, library, "grand_casino", seed + " reloaded Main")
			_check_machine_reload(_machine(loaded.current_environment), main, seed + " reload preserves cached Main state")
		_check(loaded.bankroll == int(wallets.cash) and loaded.grand_casino_chips == int(wallets.chips), seed + " census/reentry/reload leaves both wallets unchanged")
		cases.append({"seed": seed, "main_variation": main.get("variation_id", ""), "high_variation": high.get("variation_id", ""), "saved_slot": slot})
	print("GRAND_COIN_PUSHER_ROOM_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "cases": cases, "reload_diagnostics": reload_diagnostics, "scope": "Fresh canonical seeded Grand rooms, repeated room return and normal save/reload; no pre-change room-catalog migration, original save, rendered Web or engine parity claim."}))
	quit(0 if failures.is_empty() else 1)


func _check_room(environment: Dictionary, library: ContentLibrary, room_id: String, context: String) -> void:
	_check(str(environment.get("archetype_id", "")) == room_id, context + " exact room identity")
	var games: Array = environment.get("game_ids", [])
	_check(games.count("coin_pusher") == 1, context + " one selected Coin Pusher")
	_check(not games.has("pull_tabs"), context + " no stale Main Pull Tabs game")
	var manifest_count := 0
	for row in environment.get("object_manifest", {}).get("rows", []):
		if str(row.get("presentation_object_id", "")) == "game:coin_pusher" and bool(row.get("active", false)) and bool(row.get("physical", false)):
			manifest_count += 1
		_check(str(row.get("presentation_object_id", "")) != "game:pull_tabs", context + " no Pull Tabs manifest row")
	_check(manifest_count == 1, context + " exactly one physical pusher in authoritative manifest")
	var authority: Dictionary = Slots.validate_base_layout_authority(environment)
	_check(bool(authority.get("ok", false)), context + " valid slot authority: " + JSON.stringify(authority.get("errors", [])))
	_check(EnvironmentScript.object_manifest_errors(environment).is_empty(), context + " valid physical manifest")
	var bindings: Dictionary = environment.get("layout", {}).get("slot_bindings", {})
	var slot := "fixed.game_machine_5" if room_id == "grand_casino" else "fixed.game_coin_pusher"
	_check(str(bindings.get("game:coin_pusher", {}).get("slot_id", "")) == slot, context + " uses reviewed cabinet slot")
	_check(not bindings.has("game:pull_tabs") and not bindings.has("game:coin_pusher:2"), context + " no legacy or duplicate cabinet binding")
	var records: Dictionary = Semantics.authoritative_interactable_records(environment, library)
	_check(bool(records.get("ok", false)), context + " canonical semantic production: " + JSON.stringify(records.get("errors", [])))
	var semantic_count := 0
	for record in records.get("records", []):
		if str(record.get("object_id", "")) == "game:coin_pusher":
			semantic_count += 1
		_check(str(record.get("object_id", "")) != "game:pull_tabs", context + " no stale semantic Pull Tabs control")
	_check(semantic_count == 1, context + " exactly one pusher semantic control")
	var machine := _machine(environment)
	_check(str(machine.get("schema", "")) == "coin_pusher_discrete_pile", context + " normally generated persistent machine state")
	_check(str(machine.get("variation_id", "")) in ["quarter_falls", "jackpot_ridge", "vault_drop"], context + " normal variation distribution")
	var denomination := 1 if room_id == "grand_casino" else 5
	var flags: Dictionary = environment.get("local_narrative_flags", {})
	_check(int(flags.get("coin_pusher_drop_cost", 1)) == denomination and int(flags.get("coin_pusher_coin_value", 1)) == denomination, context + " persistent authored ordinary coin denomination")
	_check(int(machine.get("drop_cost", 1)) == denomination and int(machine.get("coin_value", 1)) == denomination, context + " generated machine retains configured denomination")


func _machine(environment: Dictionary) -> Dictionary:
	return environment.get("game_states", {}).get("coin_pusher", {})


func _check_machine_reload(actual: Dictionary, expected: Dictionary, context: String) -> void:
	# SaveService restores JSON numbers as floats. Compare every state field
	# after the same full-precision storage transport on both complete inputs;
	# retain the original raw result as diagnostic evidence, without tolerances.
	var raw_equal := actual == expected
	var expected_text := StorageJson.stringify(expected)
	var actual_text := StorageJson.stringify(actual)
	var expected_transport := StorageJson.parse(expected_text)
	var actual_transport := StorageJson.parse(actual_text)
	var normalized_expected: Variant = expected_transport.get("data")
	var normalized_actual: Variant = actual_transport.get("data")
	var transport_equal := int(expected_transport.get("error", FAILED)) == OK and int(actual_transport.get("error", FAILED)) == OK and StorageJson.stringify(normalized_expected) == StorageJson.stringify(normalized_actual)
	_check(transport_equal, context)
	if raw_equal:
		return
	var changes: Array = []
	_machine_difference_paths(expected, actual, "$", changes, false)
	var value_change_rows := changes.size()
	_machine_difference_paths(expected, actual, "$", changes, true)
	reload_diagnostics.append({"context": context, "raw_equal": raw_equal, "json_normalized_equal": normalized_expected == normalized_actual, "canonical_json_equal": transport_equal, "comparison": "complete full-precision storage JSON transport on both inputs", "expected_json_sha256": expected_text.sha256_text(), "actual_json_sha256": actual_text.sha256_text(), "value_change_rows": value_change_rows, "reported_changes": changes, "change_cap": 20})


func _machine_difference_paths(before: Variant, after: Variant, path: String, rows: Array, type_only: bool, depth: int = 0) -> void:
	if rows.size() >= 20 or depth > 48:
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
				if not type_only:
					rows.append({"path": child_path, "key_type": type_string(typeof(key)), "before_present": before.has(key), "after_present": after.has(key), "before": _machine_diagnostic_value(before.get(key)), "after": _machine_diagnostic_value(after.get(key))})
			else:
				_machine_difference_paths(before[key], after[key], child_path, rows, type_only, depth + 1)
		return
	if typeof(before) == TYPE_ARRAY and typeof(after) == TYPE_ARRAY:
		if before.size() != after.size() and not type_only:
			rows.append({"path": path + ".length", "before": before.size(), "after": after.size()})
		for index in range(mini(before.size(), after.size())):
			_machine_difference_paths(before[index], after[index], "%s[%d]" % [path, index], rows, type_only, depth + 1)
		return
	var equal_value: bool = before == after
	if not type_only and not equal_value or type_only and equal_value and typeof(before) != typeof(after):
		rows.append({"path": path, "kind": "type_only" if type_only else "value", "before": _machine_diagnostic_value(before), "after": _machine_diagnostic_value(after)})


func _machine_diagnostic_value(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return {"type": "Dictionary", "size": value.size(), "first_keys": value.keys().slice(0, 6)}
	if typeof(value) == TYPE_ARRAY or typeof(value) >= TYPE_PACKED_BYTE_ARRAY:
		return {"type": type_string(typeof(value)), "size": value.size()}
	var text := JSON.stringify(value, "", true, true)
	return {"type": type_string(typeof(value)), "value": text.substr(0, 160), "text_length": text.length()}


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
	return ok
