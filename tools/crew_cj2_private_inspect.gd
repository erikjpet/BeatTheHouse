extends SceneTree

# QA-only, current-format private capsule validation. Original files are opened
# READ only; the parent owns the native mutex, non-write-sharing read locks,
# source/cap/storage gates and before/after complete-profile preservation proof.
# This script neither restores a run nor admits gameplay. In particular it never
# reissues the original CJ2 handoff even when its mutation was not persisted.
const SaveScript := preload("res://scripts/core/save_service.gd")
const CodecScript := preload("res://scripts/core/run_save_codec.gd")
const NumericScript := preload("res://scripts/core/storage_numeric_json.gd")
const TurnScript := preload("res://scripts/core/crew_turn_model.gd")
const CrewScript := preload("res://scripts/core/crew_state_model.gd")
const SLOT := "CREW-FRESH-CJ2-261116"
const PRIMARY := "E:/CodexQA/BTH/runs/crew-fresh-cj2-261116/save_dir/distribution/saves/CREW-FRESH-CJ2-261116.json"
const KEY := "E:/CodexQA/BTH/runs/crew-fresh-cj2-261116/appdata/Godot/app_userdata/Beat the House/.crew_host_authority_v1"
const MAX_FILE_BYTES := 48 * 1024 * 1024
var checks := 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := _arguments(OS.get_cmdline_user_args())
	if not bool(args.get("ok", false)) or not _output_valid(str(args.get("output", ""))):
		print("CREW_CJ2_PRIVATE_INSPECTION_ERROR invalid_arguments_or_output")
		quit(2)
		return
	var result: Dictionary
	if args.mode == "qualify":
		result = _qualify()
	else:
		result = _inspect(args)
	var file := FileAccess.open(str(args.output), FileAccess.WRITE)
	if file == null:
		print("CREW_CJ2_PRIVATE_INSPECTION_ERROR output_open_failed")
		quit(2)
		return
	file.store_string(JSON.stringify(result, "  ") + "\n")
	file.close()
	print("CREW_CJ2_PRIVATE_INSPECTION_RESULT ", JSON.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)

func _arguments(tokens: PackedStringArray) -> Dictionary:
	var mode := ""
	var values: Dictionary = {}
	var index := 0
	while index < tokens.size():
		var flag := str(tokens[index])
		if flag in ["--qualify", "--inspect"]:
			if not mode.is_empty(): return {"ok": false}
			mode = flag.trim_prefix("--"); index += 1
			continue
		if flag not in ["--primary", "--primary-sha256", "--backup", "--backup-sha256", "--key", "--key-sha256", "--output"] or values.has(flag) or index + 1 >= tokens.size(): return {"ok": false}
		values[flag] = str(tokens[index + 1]); index += 2
	if mode.is_empty() or not values.has("--output"): return {"ok": false}
	if mode == "qualify":
		return {"ok": values.size() == 1, "mode": mode, "output": values["--output"]}
	if values.size() != 7: return {"ok": false}
	for pair in [["--primary", PRIMARY], ["--backup", PRIMARY + ".bak"], ["--key", KEY]]:
		if str(values.get(pair[0], "")).replace("\\", "/").to_lower() != str(pair[1]).to_lower(): return {"ok": false}
	for flag in ["--primary-sha256", "--backup-sha256"]:
		if values[flag] != "ABSENT" and not _hash_text(str(values[flag])): return {"ok": false}
	if not _hash_text(str(values["--key-sha256"])): return {"ok": false}
	return {"ok": true, "mode": mode, "output": values["--output"], "primary": values["--primary"], "primary_sha256": values["--primary-sha256"], "backup": values["--backup"], "backup_sha256": values["--backup-sha256"], "key": values["--key"], "key_sha256": values["--key-sha256"]}

func _output_valid(output: String) -> bool:
	var path := output.replace("\\", "/")
	if not path.to_lower().begins_with("e:/codexqa/bth/runs/") or path.contains("//"): return false
	var pieces := path.split("/", false)
	if pieces.size() != 7 or pieces[5].to_lower() != "evidence" or pieces[4].to_lower() == "crew-fresh-cj2-261116": return false
	for index in range(1, pieces.size()):
		var part := str(pieces[index])
		if part in [".", ".."] or part != part.strip_edges() or part.ends_with(".") or part.contains(":"): return false
	return pieces[6].ends_with(".json") and not FileAccess.file_exists(output)

func _hash_text(value: String) -> bool:
	if value.length() != 64: return false
	for index in range(value.length()):
		if value[index] not in "0123456789abcdef": return false
	return true

func _digest(raw: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK: return ""
	context.update(raw)
	return context.finish().hex_encode()

func _read_bound(path: String, expected: String, limit: int) -> Dictionary:
	if expected == "ABSENT": return {"ok": not FileAccess.file_exists(path), "exists": FileAccess.file_exists(path), "raw": PackedByteArray()}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok": false, "exists": FileAccess.file_exists(path), "raw": PackedByteArray()}
	var size := file.get_length()
	if size <= 0 or size > limit:
		file.close()
		return {"ok": false, "exists": true, "raw": PackedByteArray()}
	var raw := file.get_buffer(size)
	if raw.size() != size or _digest(raw) != expected:
		file.close()
		return {"ok": false, "exists": true, "raw": PackedByteArray()}
	file.seek(0)
	var same_size := file.get_length() == size
	var again := file.get_buffer(size) if same_size else PackedByteArray()
	file.close()
	return {"ok": same_size and again.size() == size and _digest(again) == expected, "exists": true, "raw": raw}

func _inspect(args: Dictionary) -> Dictionary:
	var errors: Array = []
	var cache_was_empty := TurnScript._private_key_cache.is_empty()
	if not cache_was_empty: errors.append("unexpected_private_cache")
	var key_input := _read_bound(str(args.key), str(args.key_sha256), 32)
	if not bool(key_input.get("ok", false)) or (key_input.get("raw", PackedByteArray()) as PackedByteArray).size() != 32: errors.append("key_binding")
	var key: PackedByteArray = key_input.get("raw", PackedByteArray())
	var generations: Dictionary = {}
	for name in ["primary", "backup"]:
		var input := _read_bound(str(args[name]), str(args[name + "_sha256"]), MAX_FILE_BYTES)
		if not bool(input.get("ok", false)): errors.append(name + "_binding")
		if not bool(input.get("exists", false)):
			generations[name] = {"exists": false, "content_supported": false, "valid": false, "supported": false, "public_correlation": {}, "error_code": "input_absent"}
			continue
		var decoded := _decode_payload(input.get("raw", PackedByteArray())) if bool(input.get("ok", false)) else {"ok": false}
		if not bool(decoded.get("ok", false)):
			generations[name] = {"exists": true, "content_supported": false, "valid": false, "supported": false, "public_correlation": {}, "error_code": "content_unsupported" if bool(input.get("ok", false)) else "input_binding_failed"}
			continue
		var data: Dictionary = decoded.data
		var verdict := _private_verdict(data, key)
		generations[name] = {"exists": true, "content_supported": true, "supported": verdict.supported, "valid": verdict.valid,
			"public_correlation": _receipt_correlation(data), "error_code": verdict.error_code}
	# Repeat every bound original read after validation. The launcher independently
	# verifies path identities, complete snapshots and held no-write-sharing locks.
	for name in ["primary", "backup", "key"]:
		if not bool(_read_bound(str(args[name]), str(args[name + "_sha256"]), 32 if name == "key" else MAX_FILE_BYTES).get("ok", false)):
			errors.append(name + "_final_binding")
	key.fill(0)
	var cache_still_empty := TurnScript._private_key_cache.is_empty()
	if not cache_still_empty: errors.append("private_cache_changed")
	return {"schema": "bth.qa_cj2_private_inspection/v1", "mode": "inspect", "ok": errors.is_empty(), "failures": errors, "generations": generations,
		"main_instantiated": false, "run_state_instantiated": false, "key_installer_called": false, "original_handoff_replayed": false,
		"gameplay_authorized": false, "custody_recovery_authorized": false, "private_cache_unchanged": cache_was_empty and cache_still_empty,
		"scope": "Existing explicit read-only key, current private capsule validation verdict and public receipt correlation only. No hidden payload, key, capsule or plaintext emitted; no restore/save/action/admission."}

func _decode_payload(raw: PackedByteArray) -> Dictionary:
	if raw.is_empty() or raw.size() > MAX_FILE_BYTES: return {"ok": false}
	var text := raw.get_string_from_utf8()
	if text.to_utf8_buffer() != raw: return {"ok": false}
	var parsed := NumericScript.parse(CodecScript.preserve_blackjack_ledger_integer_tokens(text))
	if int(parsed.get("error", FAILED)) != OK or typeof(parsed.get("data")) != TYPE_DICTIONARY: return {"ok": false}
	var payload: Dictionary = parsed.data
	# This capability intentionally supports the exact current envelope only.
	if payload.get("schema") != SaveScript.SAVE_SCHEMA or typeof(payload.get("slot_id")) != TYPE_STRING or payload.slot_id != SLOT: return {"ok": false}
	if not _number(payload.get("version")) or int(payload.version) != SaveScript.SAVE_VERSION or not SaveScript._payload_dictionary_loadable(payload): return {"ok": false}
	var proof: Dictionary = {}
	var data: Dictionary = SaveScript.new()._run_data_from_payload(payload, proof)
	if typeof(data.get("seed_text")) != TYPE_STRING or typeof(data.get("crew_state")) != TYPE_DICTIONARY: return {"ok": false}
	return {"ok": true, "data": data}

func _number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and floor(value) == value)

func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}

func _array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []

func _same(first: Variant, second: Variant) -> bool:
	return TurnScript.canonical_json(first) == TurnScript.canonical_json(second)

func _current_binding(data: Dictionary) -> Dictionary:
	var crew := _dict(data.get("crew_state"))
	if crew.has("private_authority_error") or not crew.has("a") or not crew.has("z") or typeof(crew.get("a")) != TYPE_STRING or typeof(crew.get("z")) != TYPE_STRING: return {"supported": false}
	var authority_id := str(crew.a)
	if not TurnScript.valid_authority_id(authority_id): return {"supported": false}
	var challenge := _dict(data.get("challenge_config"))
	# Current serialized challenge must already be idempotent under the production
	# normalization. Reject missing/defaulted/legacy shapes rather than minting a
	# replacement challenge or constructing RunState to obtain defaults.
	for key in ["mode", "id", "seed_text", "daily_id"]:
		if typeof(challenge.get(key)) != TYPE_STRING: return {"supported": false}
	if typeof(challenge.get("modifiers")) != TYPE_DICTIONARY or typeof(challenge.get("hidden_seed")) != TYPE_BOOL: return {"supported": false}
	for key in ["tutorial", "exclude_profile_stats"]:
		if challenge.has(key) and typeof(challenge.get(key)) != TYPE_BOOL: return {"supported": false}
	if typeof(crew.get("trust")) != TYPE_DICTIONARY or typeof(crew.get("jobs")) != TYPE_DICTIONARY: return {"supported": false}
	var trust := CrewScript.normalize_trust(crew.trust)
	if not _same(trust, crew.trust): return {"supported": false}
	var jobs := CrewScript.normalize_jobs(crew.jobs)
	for job_id in jobs:
		var job: Dictionary = jobs[job_id]
		var failure := _dict(job.get("failure")).duplicate(true)
		for field in ["grievance_kind", "grievance_weight", "g"]: failure.erase(field)
		job["failure"] = failure
		jobs[job_id] = job
	# Source restore fills only these erased private grievance fields before the
	# same normalize/public projection; exact current public jobs are idempotent.
	if not _same(jobs, crew.jobs): return {"supported": false}
	if crew.has("crew_heist") and typeof(crew.get("crew_heist")) != TYPE_DICTIONARY: return {"supported": false}
	var public_heist := _dict(crew.get("crew_heist")).duplicate(true)
	public_heist.erase("x"); public_heist.erase("z")
	var context := {"challenge_config": challenge.duplicate(true), "member_ids": CrewScript.MEMBER_IDS.duplicate(), "trust": trust, "jobs": jobs, "heist": public_heist}
	# Do not trim/lowercase authority_id: production validation checks a cleaned
	# copy but its binding formats the original identifier verbatim.
	var binding := TurnScript.private_save_binding(authority_id, str(data.get("seed_text", "")), context)
	return {"supported": not binding.is_empty(), "binding": binding}

func _private_payload(data: Dictionary, master_key: PackedByteArray) -> Dictionary:
	var bound := _current_binding(data)
	if not bool(bound.get("supported", false)) or master_key.size() != 32: return {}
	var crew := _dict(data.get("crew_state"))
	var capsule := Marshalls.base64_to_raw(str(crew.z))
	if capsule.size() != TurnScript.PRIVATE_SAVE_BYTES: return {}
	var authenticated := capsule.slice(0, 16 + TurnScript.PRIVATE_SAVE_PLAIN_BYTES)
	var supplied_mac := capsule.slice(16 + TurnScript.PRIVATE_SAVE_PLAIN_BYTES)
	var authentication_key := TurnScript._private_subkey(master_key, "hmac-sha256")
	var expected_mac := TurnScript._private_save_mac(authentication_key, str(bound.binding), authenticated)
	if supplied_mac.size() != expected_mac.size() or not TurnScript._constant_time_equal(supplied_mac, expected_mac): return {}
	var encryption_key := TurnScript._private_subkey(master_key, "aes-cbc")
	var aes := AESContext.new()
	if aes.start(AESContext.MODE_CBC_DECRYPT, encryption_key, authenticated.slice(0, 16)) != OK: return {}
	var plain := aes.update(authenticated.slice(16))
	aes.finish()
	if plain.size() != TurnScript.PRIVATE_SAVE_PLAIN_BYTES: return {}
	var body_size := (int(plain[0]) << 24) | (int(plain[1]) << 16) | (int(plain[2]) << 8) | int(plain[3])
	if body_size <= 0 or body_size + 4 > TurnScript.PRIVATE_SAVE_PLAIN_BYTES: return {}
	# JSON.new avoids logging malformed decrypted text. Keep the production JSON
	# grammar and payload normalizer; only a boolean escapes this internal scope.
	var parser := JSON.new()
	if parser.parse(plain.slice(4, body_size + 4).get_string_from_utf8()) != OK: return {}
	return TurnScript.normalize_private_payload(parser.data, CrewScript.MEMBER_IDS, CrewScript.GRIEVANCE_KINDS)

func _private_verdict(data: Dictionary, master_key: PackedByteArray) -> Dictionary:
	var bound := _current_binding(data)
	if not bool(bound.get("supported", false)): return {"supported": false, "valid": false, "error_code": "unsupported_private_shape"}
	var capsule := Marshalls.base64_to_raw(str(_dict(data.get("crew_state")).get("z", "")))
	if capsule.size() != TurnScript.PRIVATE_SAVE_BYTES: return {"supported": false, "valid": false, "error_code": "unsupported_private_shape"}
	var payload := _private_payload(data, master_key)
	return {"supported": true, "valid": not payload.is_empty(), "error_code": "" if not payload.is_empty() else "private_validation_failed"}

func _receipt_correlation(data: Dictionary) -> Dictionary:
	var shapes_ok := true
	for field in ["active_delivery_run", "world_sequence_registrations", "current_environment"]:
		if typeof(data.get(field)) != TYPE_DICTIONARY: shapes_ok = false
	var delivery := _dict(data.get("active_delivery_run"))
	if delivery.has("closed_checkpoint") and typeof(delivery.get("closed_checkpoint")) != TYPE_DICTIONARY: shapes_ok = false
	var checkpoint := _dict(delivery.get("closed_checkpoint"))
	var registrations := _dict(data.get("world_sequence_registrations"))
	var environment := _dict(data.get("current_environment"))
	if environment.has("world_sequence_instances") and typeof(environment.get("world_sequence_instances")) != TYPE_DICTIONARY: shapes_ok = false
	var instances := _dict(_dict(data.get("current_environment")).get("world_sequence_instances"))
	var no_commands := true
	var no_outcomes := true
	var no_acknowledgements := true
	var no_pending_work := true
	for token in registrations:
		if typeof(registrations[token]) != TYPE_DICTIONARY: shapes_ok = false
		var row := _dict(registrations[token])
		if typeof(row.get("pending_outcomes")) != TYPE_ARRAY: shapes_ok = false
		for field in ["owner_outcome_results", "outcome_acknowledgements"]:
			if typeof(row.get(field)) != TYPE_DICTIONARY: shapes_ok = false
		if row.has("outcome_receipts") and typeof(row.get("outcome_receipts")) != TYPE_DICTIONARY: shapes_ok = false
		if not _array(row.get("pending_outcomes")).is_empty() or not _dict(row.get("owner_outcome_results")).is_empty(): no_pending_work = false
		if not _dict(row.get("outcome_acknowledgements")).is_empty(): no_acknowledgements = false
		if not _dict(row.get("outcome_receipts")).is_empty(): no_outcomes = false
	for token in instances:
		if typeof(instances[token]) != TYPE_DICTIONARY: shapes_ok = false
		var row := _dict(instances[token])
		for field in ["state", "outcome_receipts", "outcome_acknowledgements"]:
			if typeof(row.get(field)) != TYPE_DICTIONARY: shapes_ok = false
		var state := _dict(row.get("state"))
		if typeof(state.get("command_receipts")) != TYPE_ARRAY: shapes_ok = false
		if not _array(_dict(row.get("state")).get("command_receipts")).is_empty(): no_commands = false
		if not _dict(row.get("outcome_receipts")).is_empty(): no_outcomes = false
		if not _dict(row.get("outcome_acknowledgements")).is_empty(): no_acknowledgements = false
	var public_empty := shapes_ok and checkpoint.is_empty() and no_commands and no_outcomes and no_acknowledgements and no_pending_work
	return {"supported_public_receipt_shapes": shapes_ok, "closed_checkpoint_absent": shapes_ok and checkpoint.is_empty(), "commands_absent": shapes_ok and no_commands, "outcomes_absent": shapes_ok and no_outcomes,
		"acknowledgements_absent": shapes_ok and no_acknowledgements, "pending_delivery_work_absent": shapes_ok and no_pending_work,
		"matches_inspected_prehandoff_receipts": public_empty and delivery.get("status", "") == "active" and _dict(_dict(delivery.get("depth_state")).get("cargo")).get("status", "") == "carried",
		"historical_observed_handoff_may_be_replayed": false, "economic_authority_proven_by_private_capsule": false}

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _fixture() -> Dictionary:
	return {"seed_text": "synthetic-private-inspection-only", "challenge_config": {"mode": "custom", "id": "synthetic-private-inspection", "seed_text": "synthetic-private-inspection-only", "daily_id": "", "modifiers": {}, "hidden_seed": false},
		"bankroll": 151, "rng_state": 950800549, "game_clock_minutes": 1230,
		"current_environment": {"id": "synthetic-alley", "archetype_id": "back_alley", "world_node_id": "back_alley", "game_states": {}, "world_sequence_instances": {}},
		"crew_state": {"a": "a".repeat(64), "z": "", "trust": CrewScript.default_trust(), "jobs": {}},
		"active_delivery_run": {"status": "active", "closed_checkpoint": {}, "depth_state": {"cargo": {"status": "carried"}}}, "world_sequence_registrations": {}}

func _pack_synthetic(data: Dictionary, payload: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	var binding := _current_binding(result)
	if not bool(binding.get("supported", false)): return {}
	result["crew_state"]["z"] = TurnScript.pack_private_save(payload, CrewScript.MEMBER_IDS, CrewScript.GRIEVANCE_KINDS, str(binding.binding))
	return result

func _synthetic_job() -> Dictionary:
	var normalized := CrewScript.normalize_jobs({"synthetic-job": {"member_id": "crew_rook", "status": "active", "outcome": "", "kind": "package_delivery"}})
	var row: Dictionary = normalized["synthetic-job"]
	var failure := _dict(row.get("failure"))
	for field in ["grievance_kind", "grievance_weight", "g"]: failure.erase(field)
	row["failure"] = failure
	return row

func _synthetic_raw_capsule(text: String, key: PackedByteArray, binding: String) -> String:
	# Qualification-only issuer for malformed-but-authenticated private bodies.
	# It receives only the fixed synthetic key; it never installs or reads a key.
	var body := text.to_utf8_buffer()
	if body.size() + 4 > TurnScript.PRIVATE_SAVE_PLAIN_BYTES: return ""
	var plain := PackedByteArray(); plain.resize(TurnScript.PRIVATE_SAVE_PLAIN_BYTES); plain.fill(0)
	for offset in range(4): plain[offset] = (body.size() >> ((3 - offset) * 8)) & 255
	for offset in range(body.size()): plain[offset + 4] = body[offset]
	var iv := PackedByteArray(); iv.resize(16); iv.fill(42)
	var aes := AESContext.new()
	if aes.start(AESContext.MODE_CBC_ENCRYPT, TurnScript._private_subkey(key, "aes-cbc"), iv) != OK: return ""
	var encrypted := aes.update(plain); aes.finish()
	var authenticated := iv.duplicate(); authenticated.append_array(encrypted)
	var mac := TurnScript._private_save_mac(TurnScript._private_subkey(key, "hmac-sha256"), binding, authenticated)
	authenticated.append_array(mac)
	return Marshalls.raw_to_base64(authenticated)

func _qualify() -> Dictionary:
	var path := TurnScript.PRIVATE_KEY_PATH
	var absent_before := not FileAccess.file_exists(path)
	var original_cache: PackedByteArray = TurnScript._private_key_cache.duplicate()
	_check(absent_before and original_cache.is_empty(), "qualification starts with no installed key or private cache")
	var key := PackedByteArray(); key.resize(32); key.fill(123)
	# This synthetic cache is confined to this fresh qualification process. The
	# production installer immediately returns it, so pack/unpack parity creates
	# no installation key. Actual inspection never touches this cache or issuer.
	TurnScript._private_key_cache = key.duplicate()
	var payload := {"x": TurnScript.empty_state(), "g": [], "q": 0}
	var data := _pack_synthetic(_fixture(), payload)
	_check(not data.is_empty(), "synthetic current public context is supported")
	var binding := _current_binding(data)
	var production := TurnScript.unpack_private_save(str(_dict(data.get("crew_state")).get("z", "")), CrewScript.MEMBER_IDS, CrewScript.GRIEVANCE_KINDS, str(binding.get("binding", "")))
	_check(not production.is_empty() and _same(production, _private_payload(data, key)), "pure decoder matches production unpack on exact current capsule")
	_check(_private_verdict(data, key).valid, "current private verdict validates exact production capsule")
	var public_result := JSON.stringify(_private_verdict(data, key))
	_check(not public_result.contains(str(data.crew_state.z)) and not public_result.contains(str(data.crew_state.a)) and not public_result.contains("\"g\"") and not public_result.contains("\"x\""), "verdict emits no capsule authority or decrypted fields")
	var wrong_key := key.duplicate(); wrong_key[0] ^= 1
	_check(not _private_verdict(data, wrong_key).valid, "wrong explicit key rejected without fallback")
	for field in ["seed", "challenge", "trust", "jobs", "heist"]:
		var changed := data.duplicate(true)
		match field:
			"seed": changed["seed_text"] += "-tampered"
			"challenge": changed["challenge_config"]["id"] += "-tampered"
			"trust": changed["crew_state"]["trust"]["crew_rook"] = 1
			"jobs": changed["crew_state"]["jobs"] = {"synthetic-job": _synthetic_job()}
			"heist": changed["crew_state"]["crew_heist"] = {"plan_id": "synthetic-tampered-plan"}
		var tampered_verdict := _private_verdict(changed, key)
		_check(tampered_verdict.supported and not tampered_verdict.valid, field + " canonical public context tamper rejected by authentication")
	for byte_index in [0, 31, TurnScript.PRIVATE_SAVE_BYTES - 1]:
		var changed := data.duplicate(true)
		var capsule := Marshalls.base64_to_raw(str(changed.crew_state.z)); capsule[byte_index] ^= 1
		changed["crew_state"]["z"] = Marshalls.raw_to_base64(capsule)
		_check(not _private_verdict(changed, key).valid, "IV ciphertext or MAC corruption rejected")
	for shape in ["missing_a", "missing_z", "private_authority_error", "legacy_capsule", "legacy_challenge"]:
		var changed := data.duplicate(true)
		match shape:
			"missing_a": changed["crew_state"].erase("a")
			"missing_z": changed["crew_state"].erase("z")
			"private_authority_error": changed["crew_state"]["private_authority_error"] = "synthetic"
			"legacy_capsule":
				var legacy := PackedByteArray(); legacy.resize(TurnScript.LEGACY_PRIVATE_SAVE_BYTES)
				changed["crew_state"]["z"] = Marshalls.raw_to_base64(legacy)
			"legacy_challenge": changed["challenge_config"] = {}
		_check(not _private_verdict(changed, key).supported, shape + " explicitly unsupported without migration")
	var exact_id := _fixture(); exact_id["crew_state"]["a"] = " " + "A".repeat(64) + " "
	exact_id = _pack_synthetic(exact_id, payload)
	_check(not exact_id.is_empty() and _private_verdict(exact_id, key).valid, "valid authority ID original case and spaces preserved in binding")
	var altered_id := exact_id.duplicate(true); altered_id["crew_state"]["a"] = str(altered_id["crew_state"]["a"]).strip_edges().to_lower()
	_check(not _private_verdict(altered_id, key).valid, "normalizing authority ID cannot reuse the same authenticated capsule")
	var nonempty_payload := {"x": TurnScript.empty_state(), "g": [[0, 0, 1, 12, "synthetic-entry".to_utf8_buffer().hex_encode(), "synthetic-source".to_utf8_buffer().hex_encode()]], "q": 1}
	var nonempty := _pack_synthetic(_fixture(), nonempty_payload)
	var nonempty_binding := _current_binding(nonempty)
	var nonempty_production := TurnScript.unpack_private_save(str(nonempty.crew_state.z), CrewScript.MEMBER_IDS, CrewScript.GRIEVANCE_KINDS, str(nonempty_binding.binding))
	_check(not nonempty_production.is_empty() and _same(nonempty_production, _private_payload(nonempty, key)), "production parity retains valid packed ledger rows without exposing them")
	_check(_private_verdict(nonempty, key) == _private_verdict(data, key), "different private payloads emit the same valid verdict shape")
	for invalid_body in ["{", JSON.stringify({"x": TurnScript.empty_state(), "g": [], "q": 0, "unexpected": true})]:
		var changed := data.duplicate(true)
		changed["crew_state"]["z"] = _synthetic_raw_capsule(invalid_body, key, str(binding.binding))
		_check(not _private_verdict(changed, key).valid, "authenticated malformed private body rejected without parser logging")
	var changed_cash := data.duplicate(true); changed_cash["bankroll"] = 999
	_check(_private_verdict(changed_cash, key).valid and not _receipt_correlation(changed_cash).economic_authority_proven_by_private_capsule, "private verdict does not pretend to authenticate economic roots")
	var correlation := _receipt_correlation(data)
	_check(correlation.matches_inspected_prehandoff_receipts and not correlation.historical_observed_handoff_may_be_replayed, "empty stored journals never authorize historical handoff replay")
	var pending := data.duplicate(true); pending["world_sequence_registrations"] = {"synthetic-owner": {"pending_outcomes": [{"synthetic": true}]}}
	_check(not _receipt_correlation(pending).pending_delivery_work_absent and not _receipt_correlation(pending).matches_inspected_prehandoff_receipts, "pending owner work prevents prehandoff empty-receipt classification")
	var malformed_receipts := data.duplicate(true); malformed_receipts["world_sequence_registrations"] = {"synthetic-owner": {"pending_outcomes": "invalid"}}
	_check(not _receipt_correlation(malformed_receipts).supported_public_receipt_shapes and not _receipt_correlation(malformed_receipts).matches_inspected_prehandoff_receipts, "malformed journals never masquerade as empty receipts")
	var missing_state := data.duplicate(true); missing_state["current_environment"]["world_sequence_instances"] = {"synthetic-owner": {}}
	_check(not _receipt_correlation(missing_state).supported_public_receipt_shapes and not _receipt_correlation(missing_state).matches_inspected_prehandoff_receipts, "missing owner state and journals are unsupported rather than empty")
	_check(not _output_valid("E:/CodexQA/BTH/runs/CREW-FRESH-CJ2-261116/evidence/never.json"), "Windows case alias cannot target original output")
	_check(not _output_valid("E:/CodexQA/BTH/runs/synthetic-private./evidence/never.json"), "Windows trailing-dot alias cannot target an output")
	var encoded := CodecScript.pack_for_storage(CodecScript.encode(data))
	var envelope := {"schema": SaveScript.SAVE_SCHEMA, "version": SaveScript.SAVE_VERSION, "slot_id": SLOT, "act": 1, "run_state": encoded.get("packed", {})}
	var decoded := _decode_payload(JSON.stringify(envelope).to_utf8_buffer())
	_check(decoded.get("ok", false) and _private_verdict(decoded.get("data", {}), key).valid, "actual storage codec roundtrip preserves authenticated public binding")
	envelope["slot_id"] = "FOREIGN"
	_check(not _decode_payload(JSON.stringify(envelope).to_utf8_buffer()).get("ok", false), "wrong save slot rejected before private validation")
	TurnScript._private_key_cache = original_cache
	key.fill(0)
	var absent_after := not FileAccess.file_exists(path)
	_check(absent_after and TurnScript._private_key_cache.is_empty(), "qualification leaves no installed key and clears synthetic private cache")
	return {"schema": "bth.qa_cj2_private_inspection/v1", "mode": "qualify", "ok": failures.is_empty(), "qualified": failures.is_empty(), "checks": checks, "failures": failures,
		"fresh_key_absent_before": absent_before, "fresh_key_absent_after": absent_after, "production_parity": true,
		"main_instantiated": false, "run_state_instantiated": false, "campaign_files_read": false, "original_private_key_read": false,
		"scope": "Fresh in-memory synthetic cache-seeded production pack/unpack parity; no key installation, original profile or key read, restore, save, handoff or gameplay."}
