extends SceneTree

# Exact, read-only CJ2 storage inspection. No Main or RunState construction,
# restoration, saving, private authority access, projection hydration or action.
# The parent launcher owns campaign mutex + read locks, source admission/caps,
# and before/after campaign/custody fingerprints. This script never admits play.
const SaveScript := preload("res://scripts/core/save_service.gd")
const CodecScript := preload("res://scripts/core/run_save_codec.gd")
const NumericScript := preload("res://scripts/core/storage_numeric_json.gd")
const DeliveryScript := preload("res://scripts/core/delivery_run_model.gd")
const SLOT := "CREW-FRESH-CJ2-261116"
const PRIMARY := "E:/CodexQA/BTH/runs/crew-fresh-cj2-261116/save_dir/distribution/saves/CREW-FRESH-CJ2-261116.json"
const MAX_FILE_BYTES := 48 * 1024 * 1024
const MAX_ROWS := 512
var checks := 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := _arguments(OS.get_cmdline_user_args())
	if not bool(args.get("ok", false)):
		print("CREW_CJ2_FAILED_INSPECTION_ERROR invalid_arguments")
		quit(2)
		return
	var output := str(args.output)
	if not _output_valid(output):
		print("CREW_CJ2_FAILED_INSPECTION_ERROR invalid_output")
		quit(2)
		return
	var result: Dictionary
	if args.mode == "qualify":
		result = _qualify()
	else:
		var primary := _read_bound(args.primary, args.primary_sha256)
		var backup := _read_bound(args.backup, args.backup_sha256)
		var binding_failures: Array = []
		if not bool(primary.get("binding_ok", false)): binding_failures.append("primary_binding")
		if not bool(backup.get("binding_ok", false)): binding_failures.append("backup_binding")
		result = {"schema": "bth.qa_cj2_failed_inspection/v1", "mode": "inspect", "slot": SLOT, "failures": binding_failures,
			"ok": bool(primary.get("binding_ok", false)) and bool(backup.get("binding_ok", false)),
			"generations": {"primary": primary, "backup": backup}, "main_instantiated": false,
			"run_state_instantiated": false, "private_authority_validated": false,
			"custody_recovery_authorized": false, "gameplay_authorized": false,
			"scope": "Stored public bytes decoded only; no restore, private-key read, mutation, save or action. Valid envelope does not prove trusted Continue authority."}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		print("CREW_CJ2_FAILED_INSPECTION_ERROR output_open_failed")
		quit(2)
		return
	file.store_string(JSON.stringify(result, "  ") + "\n")
	file.close()
	print("CREW_CJ2_FAILED_INSPECTION_RESULT ", JSON.stringify(result))
	quit(0 if bool(result.get("ok", false)) else 1)

func _output_valid(output: String) -> bool:
	# Validate the exact new scratch namespace before any campaign input read.
	var normalized := output.replace("\\", "/")
	if not normalized.to_lower().begins_with("e:/codexqa/bth/runs/") or normalized.contains("//"): return false
	var pieces := normalized.split("/", false)
	if pieces.size() != 7 or pieces[5] != "evidence" or pieces[4] == "crew-fresh-cj2-261116": return false
	for index in range(1, pieces.size()):
		var part := str(pieces[index])
		if part in [".", ".."] or part != part.strip_edges() or part.contains(":"): return false
	if not pieces[6].ends_with(".json"): return false
	return not FileAccess.file_exists(output)

func _arguments(tokens: PackedStringArray) -> Dictionary:
	var values: Dictionary = {}
	var mode := ""
	var index := 0
	while index < tokens.size():
		var key := str(tokens[index])
		if key in ["--qualify", "--inspect"]:
			if not mode.is_empty(): return {"ok": false}
			mode = key.trim_prefix("--")
			index += 1
			continue
		if key not in ["--primary", "--primary-sha256", "--backup", "--backup-sha256", "--output"] or values.has(key) or index + 1 >= tokens.size(): return {"ok": false}
		values[key] = str(tokens[index + 1])
		index += 2
	if mode.is_empty() or not values.has("--output"): return {"ok": false}
	if mode == "qualify":
		if values.size() != 1: return {"ok": false}
		return {"ok": true, "mode": mode, "output": values["--output"]}
	if values.size() != 5: return {"ok": false}
	if str(values.get("--primary", "")).replace("\\", "/").to_lower() != PRIMARY.to_lower() or str(values.get("--backup", "")).replace("\\", "/").to_lower() != (PRIMARY + ".bak").to_lower(): return {"ok": false}
	for key in ["--primary-sha256", "--backup-sha256"]:
		if values[key] != "ABSENT" and not _hash_text(str(values[key])): return {"ok": false}
	return {"ok": true, "mode": mode, "output": values["--output"], "primary": values["--primary"], "backup": values["--backup"], "primary_sha256": values["--primary-sha256"], "backup_sha256": values["--backup-sha256"]}

func _hash_text(value: String) -> bool:
	if value.length() != 64: return false
	for index in range(value.length()):
		if value[index] not in "0123456789abcdef": return false
	return true

func _digest(raw: PackedByteArray) -> String:
	var hash := HashingContext.new()
	if hash.start(HashingContext.HASH_SHA256) != OK: return ""
	hash.update(raw)
	return hash.finish().hex_encode()

func _read_bound(path: String, expected: String) -> Dictionary:
	if expected == "ABSENT":
		return {"exists": FileAccess.file_exists(path), "binding_ok": not FileAccess.file_exists(path), "expected_sha256": expected, "loadable_content": false}
	if not FileAccess.file_exists(path): return {"exists": false, "binding_ok": false, "error": "input_missing"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"exists": true, "binding_ok": false, "error": "input_open_failed"}
	var size := file.get_length()
	if size <= 0 or size > MAX_FILE_BYTES:
		file.close()
		return {"exists": true, "binding_ok": false, "error": "input_size_bound"}
	var raw := file.get_buffer(size)
	if raw.size() != size or _digest(raw) != expected:
		file.close()
		return {"exists": true, "binding_ok": false, "error": "input_hash_before"}
	var result := _analyze_bytes(raw)
	file.seek(0)
	var same_size := file.get_length() == size
	var after := file.get_buffer(size) if same_size else PackedByteArray()
	file.close()
	if not same_size or after.size() != size or _digest(after) != expected: return {"exists": true, "binding_ok": false, "error": "input_hash_after"}
	result["exists"] = true
	result["binding_ok"] = true
	result["sha256"] = expected
	result["bytes"] = size
	return result

func _analyze_bytes(raw: PackedByteArray) -> Dictionary:
	if raw.is_empty() or raw.size() > MAX_FILE_BYTES: return _invalid("input_size_bound")
	var text := raw.get_string_from_utf8()
	if text.to_utf8_buffer() != raw: return _invalid("invalid_utf8")
	var parsed := NumericScript.parse(CodecScript.preserve_blackjack_ledger_integer_tokens(text))
	if int(parsed.get("error", FAILED)) != OK or typeof(parsed.get("data")) != TYPE_DICTIONARY: return _invalid("invalid_json_root")
	var payload: Dictionary = parsed.data
	var envelope := payload.has("schema")
	if envelope:
		if payload.get("schema") != SaveScript.SAVE_SCHEMA or not _number(payload.get("version")) or int(payload.get("version", -1)) != SaveScript.SAVE_VERSION: return _invalid("unsupported_envelope")
		if typeof(payload.get("slot_id")) != TYPE_STRING or payload.slot_id != SLOT: return _invalid("wrong_slot")
	if not SaveScript._payload_dictionary_loadable(payload): return _invalid("content_or_storage_invalid")
	# This helper decodes dictionaries only. Never call _read_run_state_from_path,
	# load_run, from_dict or a private capsule helper: those cross restore/IO.
	var proof: Dictionary = {}
	var data: Dictionary = SaveScript.new()._run_data_from_payload(payload, proof)
	if not _roots_valid(data):
		var unsupported := _invalid("unsupported_public_roots")
		unsupported["save_service_content_valid"] = true
		return unsupported
	return {"loadable_content": true, "format": "envelope_v2" if envelope else "legacy_raw",
		"save_service_content_valid": true, "private_authority_validated": false, "summary": _summary(data)}

func _invalid(code: String) -> Dictionary:
	return {"loadable_content": false, "error": code}

func _roots_valid(data: Dictionary) -> bool:
	if typeof(data.get("seed_text")) != TYPE_STRING or typeof(data.get("current_environment")) != TYPE_DICTIONARY: return false
	if not _number(data.get("bankroll")) or not _number(data.get("game_clock_minutes")) or not _number(data.get("rng_state")): return false
	for key in ["challenge_config", "narrative_flags", "crew_state", "event_cadence", "active_delivery_run", "world_sequence_registrations", "suspicion"]:
		if data.has(key) and typeof(data.get(key)) != TYPE_DICTIONARY: return false
	for pair in [["narrative_flags", "crew_reputation"], ["narrative_flags", "crew_delivery_obligations"], ["event_cadence", "action_index"], ["suspicion", "level"], ["active_delivery_run", "deadline_game_clock_minutes"]]:
		var source := _dict(data.get(pair[0]))
		if source.has(pair[1]) and not _number(source.get(pair[1])): return false
	var environment: Dictionary = data.current_environment
	if environment.has("world_sequence_instances") and typeof(environment.get("world_sequence_instances")) != TYPE_DICTIONARY: return false
	return true

func _number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and floor(value) == value)

func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}

func _array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []

func _identity_hash(value: Variant) -> String:
	return str(value).sha256_text() if typeof(value) == TYPE_STRING and not str(value).is_empty() else ""

func _count(value: Variant) -> int:
	return value.size() if typeof(value) in [TYPE_ARRAY, TYPE_DICTIONARY] else 0

func _status(value: Variant) -> String:
	return str(value) if typeof(value) == TYPE_STRING and str(value) in ["", "active", "resolved", "success", "failed", "delivered", "carried", "pickup_pending", "stashed", "confiscated", "abandoned", "expired", "pending", "cleanup_pending", "cleaned", "mounted", "eligible", "completed", "in_progress", "won", "lost"] else "other_or_missing"

func _summary(data: Dictionary) -> Dictionary:
	var flags := _dict(data.get("narrative_flags"))
	var environment := _dict(data.current_environment)
	var delivery := _dict(data.get("active_delivery_run"))
	var checkpoint := _dict(delivery.get("closed_checkpoint"))
	var receipt := _dict(delivery.get("receipt"))
	var resolution := _dict(delivery.get("resolution"))
	var owner_token := str(checkpoint.get("owner_token", ""))
	var registry := _dict(data.get("world_sequence_registrations"))
	var owners: Array = []
	var too_many_owners := registry.size() > MAX_ROWS
	var tokens := registry.keys(); tokens.sort()
	for token_value in tokens.slice(0, MAX_ROWS):
		var token := str(token_value)
		var registration := _dict(registry.get(token_value))
		var entry := _dict(_dict(environment.get("world_sequence_instances")).get(token))
		var state := _dict(entry.get("state"))
		owners.append({"owner_sha256": _identity_hash(token), "matches_closed_checkpoint": not owner_token.is_empty() and token == owner_token,
			"registration_lifecycle": _status(registration.get("lifecycle")), "room_lifecycle": _status(entry.get("lifecycle")),
			"pending_outcomes": _count(registration.get("pending_outcomes")), "owner_results": _count(registration.get("owner_outcome_results")),
			"registration_acknowledgements": _count(registration.get("outcome_acknowledgements")),
			"room_outcomes": _count(entry.get("outcome_receipts")), "room_acknowledgements": _count(entry.get("outcome_acknowledgements")),
			"commands": _count(state.get("command_receipts"))})
	var checkpoint_errors: Array = []
	if not checkpoint.is_empty(): checkpoint_errors = DeliveryScript.closed_checkpoint_errors(delivery)
	var cadence := _dict(data.get("event_cadence"))
	var node := str(environment.get("world_node_id", environment.get("archetype_id", "")))
	var rng: Variant = data.get("rng_state")
	var rng_safe := typeof(rng) == TYPE_INT or absf(float(rng)) <= 9007199254740992.0
	var jobs := _dict(_dict(data.get("crew_state")).get("jobs"))
	var job_id := str(delivery.get("job_id", ""))
	var target_statuses: Array = []
	for value in _array(delivery.get("targets")).slice(0, MAX_ROWS): target_statuses.append(_status(_dict(value).get("status")))
	return {"cash": int(data.bankroll), "clock": int(data.game_clock_minutes), "rng": str(int(rng)) if rng_safe else "UNSAFE_LEGACY_NUMERIC_PRECISION",
		"rng_exact_numeric_range": rng_safe, "action_index": int(cadence.get("action_index", 0)),
		"node": node if node in ["back_alley", "bar", "grand_casino", "grand_casino_cage", "punchline", "pawn_shop"] else "other_node", "node_sha256": _identity_hash(node),
		"run_status": _status(data.get("run_status")), "standing_flag_present": flags.has("crew_reputation"),
		"standing": int(flags.get("crew_reputation", -1)), "duties": int(flags.get("crew_delivery_obligations", -1)),
		"heat": int(_dict(data.get("suspicion")).get("level", 0)),
		"delivery": {"present": not delivery.is_empty(), "status": _status(delivery.get("status")), "job_sha256": _identity_hash(job_id),
			"job_status": _status(_dict(jobs.get(job_id)).get("status")), "cargo_status": _status(_dict(_dict(delivery.get("depth_state")).get("cargo")).get("status")),
			"target_statuses": target_statuses, "deadline": int(delivery.get("deadline_game_clock_minutes", 0)), "world_applied": delivery.get("world_applied", false) == true,
			"resolution_outcome": _status(resolution.get("outcome")), "receipt_status": _status(receipt.get("status", receipt.get("outcome", ""))),
			"closed_checkpoint_present": not checkpoint.is_empty(), "closed_checkpoint_internal_valid": not checkpoint.is_empty() and checkpoint_errors.is_empty(),
			"closed_checkpoint_error_count": checkpoint_errors.size(), "owner_sha256": _identity_hash(owner_token),
			"outcome_receipt_sha256": _identity_hash(checkpoint.get("outcome_receipt_id")),
			"public_result_fingerprint_sha256": _identity_hash(checkpoint.get("public_result_fingerprint"))},
		"owners": owners, "owner_summary_truncated": too_many_owners}

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _fixture() -> Dictionary:
	return {"seed_text": "synthetic-inspection-only", "rng_state": 950800549, "bankroll": 173, "game_clock_minutes": 1230,
		"challenge_config": {}, "current_environment": {"id": "synthetic-back-alley", "game_states": {}, "world_node_id": "back_alley", "archetype_id": "back_alley", "world_sequence_instances": {}},
		"narrative_flags": {"crew_reputation": 100, "crew_delivery_obligations": 1}, "event_cadence": {"action_index": 12},
		"crew_state": {"a": "DO_NOT_EMIT_AUTHORITY", "z": "DO_NOT_EMIT_CAPSULE", "p": ["DO_NOT_EMIT_HIDDEN"], "jobs": {}}, "active_delivery_run": {}, "world_sequence_registrations": {}, "run_status": "active"}

func _bytes(value: Dictionary) -> PackedByteArray:
	return JSON.stringify(value).to_utf8_buffer()

func _qualify() -> Dictionary:
	var fixture := _fixture()
	var before := JSON.stringify(fixture)
	var encoded := CodecScript.encode(fixture)
	var packed := CodecScript.pack_for_storage(encoded)
	_check(bool(packed.get("ok", false)), "current synthetic storage pack succeeds")
	var payload := {"schema": SaveScript.SAVE_SCHEMA, "version": SaveScript.SAVE_VERSION, "slot_id": SLOT, "act": 1, "run_state": packed.get("packed", {})}
	var good := _analyze_bytes(_bytes(payload))
	_check(good.get("loadable_content", false), "current envelope validates without restore")
	_check(good.get("summary", {}).get("cash") == 173 and good.get("summary", {}).get("clock") == 1230, "decoded public cash and clock retained")
	_check(good.get("summary", {}).get("rng") == "950800549" and good.get("summary", {}).get("action_index") == 12, "decoded RNG and action retained")
	_check(good.get("summary", {}).get("standing") == 100 and good.get("summary", {}).get("duties") == 1, "decoded public standing and obligations retained")
	_check(good.get("summary", {}).get("node") == "back_alley" and encoded.get("environment_registry", {}).size() == 1, "environment registry reference decodes to public room")
	_check(JSON.stringify(fixture) == before, "encode and inspector leave fixture unchanged")
	var public_text := JSON.stringify(good)
	for secret in ["DO_NOT_EMIT_AUTHORITY", "DO_NOT_EMIT_CAPSULE", "DO_NOT_EMIT_HIDDEN"]: _check(not public_text.contains(secret), "private synthetic sentinel omitted")
	var legacy := _analyze_bytes(_bytes(fixture))
	_check(legacy.get("loadable_content", false) and legacy.get("format") == "legacy_raw", "legacy raw dictionary decodes without normalization")
	_check(legacy.get("summary", {}).get("cash") == good.get("summary", {}).get("cash"), "current and legacy public cash match")
	var wrong := payload.duplicate(true); wrong["slot_id"] = "FOREIGN"
	_check(_analyze_bytes(_bytes(wrong)).get("error") == "wrong_slot", "wrong envelope slot rejected")
	wrong = payload.duplicate(true); wrong["version"] = 999
	_check(_analyze_bytes(_bytes(wrong)).get("error") == "unsupported_envelope", "unknown envelope version rejected")
	wrong = payload.duplicate(true); wrong["run_state"]["sha256"] = "f".repeat(64)
	_check(not _analyze_bytes(_bytes(wrong)).get("loadable_content", false), "compressed content hash corruption rejected")
	wrong = payload.duplicate(true); wrong["run_state"]["data"] = "?" + str(wrong["run_state"]["data"]).substr(1)
	_check(not _analyze_bytes(_bytes(wrong)).get("loadable_content", false), "compressed payload corruption rejected")
	wrong = payload.duplicate(true); wrong["run_state"]["uncompressed_bytes"] = CodecScript.MAX_STORAGE_BYTES + 1
	_check(not _analyze_bytes(_bytes(wrong)).get("loadable_content", false), "codec decoded byte bound retained")
	for mutation in ["current_environment", "narrative_flags", "active_delivery_run", "world_sequence_registrations", "bankroll", "rng_state"]:
		wrong = fixture.duplicate(true); wrong[mutation] = "hostile_shape"
		_check(not _analyze_bytes(_bytes(wrong)).get("loadable_content", false), mutation + " malformed public root rejected")
	_check(not _analyze_bytes("[]".to_utf8_buffer()).get("loadable_content", false), "array root rejected")
	_check(not _analyze_bytes("{".to_utf8_buffer()).get("loadable_content", false), "invalid JSON rejected")
	_check(not _analyze_bytes(PackedByteArray([255])).get("loadable_content", false), "invalid UTF8 rejected")
	_check(_arguments(PackedStringArray(["--qualify", "--output", "E:/CodexQA/BTH/runs/synthetic/evidence/result.json"])).get("ok", false), "pure qualification accepts only output")
	_check(not _arguments(PackedStringArray(["--qualify", "--inspect", "--output", "x"])).get("ok", false), "mixed modes rejected")
	_check(not _arguments(PackedStringArray(["--qualify", "--output", "x", "--output", "y"])).get("ok", false), "duplicate arguments rejected")
	return {"schema": "bth.qa_cj2_failed_inspection/v1", "mode": "qualify", "ok": failures.is_empty(), "qualified": failures.is_empty(), "checks": checks, "failures": failures,
		"main_instantiated": false, "run_state_instantiated": false, "campaign_files_read": false, "private_keys_read": false,
		"scope": "Pure in-memory synthetic codec/envelope/public-summary cases; no campaign profile, RunState or Main, save, private authority or gameplay."}
