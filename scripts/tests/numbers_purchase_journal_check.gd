extends SceneTree

# Disposable RunState API fixtures. Corner Store/Draw2 matches the reported
# public terms; its Numbers clock is explicitly advanced before the test. No
# original R05 state, hidden handle, paid replay, renderer or Web path is used.
const Journal := preload("res://scripts/ui/run_journal_view_model.gd")
const Archive := preload("res://scripts/core/run_money_flow_archive.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const PURCHASE := "numbers_slip_purchase"

var checks := 0
var failures: Array[String] = []
var facts := {"purchases": [], "rejections": [], "cold": [], "legacy": {}, "original_profiles_used": false}
var references: Array = []
var private_root := ""
var completed := false


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	if not _private_roots(): _finish(); return
	if OS.get_cmdline_user_args().has("--cold"):
		_cold()
	else:
		var reported := _fixture("reported", "corner_store")
		# Existing public model advancement establishes synthetic Draw2 before
		# buying; this is not a claim of travelling a real player's route.
		reported.numbers_state.advance_to(reported.numbers_state.actions_per_day())
		_buy(reported, "000", 1, "straight", "Corner Store Draw2")
		_check(reported.bankroll == 30 and reported.grand_casino_chips == 25 and reported.numbers_state.slips.size() == 1, "reported terms buy one000 Straight1 for Draw2: cash31 to30 and chips25 unchanged")
		_save(reported, "numbers_purchase_reported", false)
		var motel := _fixture("normalized")
		_buy(motel, " 123 ", 2, " BoX ", "normalized Box")
		var first_id := str(motel.numbers_state.slips.back().get("id", ""))
		_buy(motel, "123", 2, "box", "additional legitimate purchase")
		_check(motel.numbers_state.slips.size() == 2 and str(motel.numbers_state.slips.back().get("id", "")) != first_id and motel.bankroll == 27, "another valid intent purchases a distinct ticket with its own exact debit")
		_check(motel.inventory.count("numbers_slips") == 1, "multiple physical slips retain one canonical inventory marker")
		_save(motel, "numbers_purchase_multiple", false)
		_rejections()
		_legacy()
		var file := FileAccess.open(_reference_path(), FileAccess.WRITE)
		if _check(file != null, "private cold reference opens"):
			file.store_string(JSON.stringify(references, "\t")); file.close()
		completed = true
	_finish()


func _fixture(label: String, venue: String = "motel") -> RunState:
	var run := RunState.new()
	run.start_new("NUMBERS-PURCHASE-JOURNAL-" + label)
	run.bankroll = 31
	run.grand_casino_chips = 25
	var installed := run.set_environment({"id": venue, "archetype_id": venue, "world_node_id": venue, "turns": 0})
	_check(bool(installed.get("ok", false)), label + " production setter installs canonical " + venue)
	return run


func _buy(run: RunState, digits: String, stake: int, play_type: String, label: String) -> void:
	var unchanged := _nonpurchase_state(run)
	var old_cash := run.bankroll
	var slips := run.numbers_state.slips.size()
	var stories := run.story_log.size()
	var rows := _purchase_rows(run).size()
	var result := run.numbers_buy_slip(digits, stake, play_type)
	if not _check(bool(result.get("ok", false)), label + " normal RunState purchase succeeds"): return
	_check(run.bankroll == old_cash - stake and run.grand_casino_chips == 25 and int(result.get("bankroll_delta", 0)) == -stake, label + " exact stake debited from cash once")
	_check(run.numbers_state.slips.size() == slips + 1 and run.numbers_state.open_slip_count() == slips + 1 and run.inventory.count("numbers_slips") == 1, label + " exactly one open slip and canonical carried marker")
	_check(_nonpurchase_state(run) == unchanged, label + " root RNG clocks debt and hidden draw schedule remain unchanged")
	_check(run.story_log.size() == stories + 1 and _purchase_rows(run).size() == rows + 1, label + " exactly one new durable purchase row")
	var slip: Dictionary = result.get("slip", {})
	if _purchase_rows(run).size() == rows + 1: _assert_row(run, _purchase_rows(run).back(), slip, label)
	facts.purchases.append({"label": label, "cash": run.bankroll, "chips": run.grand_casino_chips, "slip_id": slip.get("id", ""), "digits": slip.get("digits", ""), "stake": slip.get("stake", 0), "play_type": slip.get("play_type", ""), "draw": int(slip.get("day", -1)) + 1, "venue": slip.get("venue_id", ""), "purchase_rows": _purchase_rows(run).size()})


func _assert_row(run: RunState, row: Dictionary, slip: Dictionary, label: String) -> void:
	var stake := int(slip.get("stake", 0))
	var venue := run.numbers_state.venue_definition(str(slip.get("venue_id", "")))
	var draw := int(slip.get("day", -1)) + 1
	_check(str(row.get("type", "")) == PURCHASE and str(row.get("currency", "")) == "cash" and int(row.get("currency_delta", 99999)) == -stake and int(row.get("bankroll_delta", 99999)) == -stake, label + " receipt stamps exact cash debit and compatibility alias")
	_check(str(row.get("slip_id", "")) == str(slip.get("id", "")) and str(row.get("digits", "")) == str(slip.get("digits", "")) and int(row.get("stake", 0)) == stake and str(row.get("play_type", "")) == str(slip.get("play_type", "")) and int(row.get("draw", 0)) == draw, label + " receipt retains normalized public ticket terms")
	_check(str(row.get("venue_id", "")) == str(slip.get("venue_id", "")) and str(row.get("environment_id", "")) == str(run.current_environment.get("id", "")) and str(row.get("environment_archetype_id", "")) == str(run.current_environment.get("archetype_id", "")) and str(row.get("environment_name", "")) == str(venue.get("label", "")), label + " receipt identifies actual book and venue label")
	var message := "Bought Numbers slip %s %s for $%d (Draw %d) at %s." % [str(slip.get("digits", "")), str(slip.get("play_type", "")).capitalize(), stake, draw, str(venue.get("label", ""))]
	_check(str(row.get("message", "")) == message and not row.has("game_id") and not row.has("event_id"), label + " public message describes an open purchase rather than an outcome")
	_check(not _has_hidden_keys(row), label + " receipt excludes hidden detection past-post draw and physical authority")
	var before := _full_fingerprint(run)
	_check(Journal._recorded_money_detail_lines(row) == ["Bankroll -%d" % stake], label + " generic journal records one exact Bankroll debit")
	_check(Journal._detail_lines(row, {}).has("Venue: " + str(venue.get("label", ""))), label + " generic journal retains venue detail")
	_check(Archive.money_legs(row) == {"cash": -stake}, label + " money archive interprets cash alias once")
	var archived := Archive.append_evicted_rows({}, 0, [row])
	var buckets: Dictionary = archived.get("sources", {})
	_check(buckets.size() == 1 and int(buckets.values()[0].get("net", 0)) == -stake and str(buckets.values()[0].get("currency", "")) == "cash", label + " evicted receipt contributes one exact cash loss")
	for repeat in range(3): Journal._recorded_money_detail_lines(row); Journal._detail_lines(row, {})
	_check(_full_fingerprint(run) == before, label + " journal and archive readers leave full run unchanged")


func _rejections() -> void:
	var run := _fixture("invalid")
	for spec in [["00", 1, "straight"], ["0a0", 1, "straight"], ["0000", 1, "straight"], ["000", 1, "invalid"], ["000", 0, "straight"], ["000", -1, "straight"], ["000", 21, "straight"]]:
		_reject(run, str(spec[0]), int(spec[1]), str(spec[2]), "invalid %s/%s/%s" % spec)
	var poor := _fixture("insufficient")
	poor.bankroll = 1
	_reject(poor, "000", 2, "straight", "insufficient cash")
	var absent := _fixture("no_book", "back_alley")
	_reject(absent, "000", 1, "straight", "venue without book")
	var closed := _fixture("closed")
	closed.numbers_state.advance_to(closed.numbers_state.close_action("motel", 0))
	_reject(closed, "000", 1, "straight", "authored Motel close boundary")


func _reject(run: RunState, digits: String, stake: int, play_type: String, label: String) -> void:
	var before := _full_fingerprint(run)
	var result := run.numbers_buy_slip(digits, stake, play_type)
	_check(not bool(result.get("ok", false)), label + " is rejected")
	_check(_full_fingerprint(run) == before, label + " rejection preserves full run with no debit slip marker or story")
	facts.rejections.append({"label": label, "message": result.get("message", "")})


func _legacy() -> void:
	var run := _fixture("legacy")
	var result := run.numbers_buy_slip("456", 2, "straight")
	if not _check(bool(result.get("ok", false)), "legacy compatibility fixture first owns a legitimate paid slip"): return
	# Explicit synthetic old-save shape: old releases stored the paid slip and
	# marker without a purchase row. Remove only new purchase rows in this fixture.
	var retained: Array = []
	for row in run.story_log:
		if str(row.get("type", "")) != PURCHASE: retained.append(row)
	run.story_log = retained
	_check(_purchase_rows(run).is_empty() and run.numbers_state.slips.size() == 1 and run.bankroll == 29, "synthetic legacy paid slip has no invented receipt")
	_save(run, "numbers_purchase_legacy", true)
	facts.legacy = {"cash": run.bankroll, "slips": 1, "purchase_rows": 0, "fixture_setup": "normal paid API purchase, then remove only synthetic new purchase row to represent old save shape"}


func _nonpurchase_state(run: RunState) -> Dictionary:
	return {"rng_seed": str(run.rng_seed), "rng": str(run.rng_state), "game_clock": run.game_clock_minutes, "simulation_msec": run.simulation_msec, "surface_clock": run.surface_clock_checkpoint_msec, "numbers_clock": run.numbers_state.action_index, "draws": run.numbers_state.draws_by_day.duplicate(true), "debt": run.debt.duplicate(true)}


func _protected(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "nonpurchase": _nonpurchase_state(run), "history": run.story_log.duplicate(true), "numbers": run.numbers_state.snapshot(), "numbers_seed_exact": str(run.numbers_state.seed_value), "inventory": run.inventory.duplicate(true), "active_item": run.active_item_id}


func _full_fingerprint(run: RunState) -> String: return Runtime.content_fingerprint(run.to_dict())


func _save(run: RunState, slot: String, legacy: bool) -> void:
	var before := _protected(run)
	if not _check(SaveService.new().save_run(run, slot) == OK, "official Save stores " + slot): return
	_check(_protected(run) == before, "Save does not charge or rewrite purchase history: " + slot)
	var loaded: Variant = SaveService.new().load_run(slot)
	if not _check(loaded is RunState, "fresh official SaveService loads " + slot): return
	_check(_persistent_fingerprint(_protected(loaded)) == _persistent_fingerprint(before), "official load preserves full relevant history numbers inventory debt wallets RNG and clocks: " + slot)
	_check(_money_lines(loaded) == _money_lines(run), "official load preserves every journal amount: " + slot)
	_check(_purchase_rows(loaded).size() == _purchase_rows(run).size(), "official load never backfills legacy purchase rows: " + slot)
	references.append({"slot": slot, "legacy": legacy, "protected_json": JSON.stringify(_protected(loaded)), "money_lines": _money_lines(loaded)})


func _cold() -> void:
	if not _check(FileAccess.file_exists(_reference_path()), "producer reference exists for independent cold process"): return
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(_reference_path()))
	if not _check(expected is Array and expected.size() == 3, "reported multiple and legacy official save references exist"): return
	for reference in expected:
		var loaded: Variant = SaveService.new().load_run(str(reference.slot))
		if not _check(loaded is RunState, "independent process officially loads " + str(reference.slot)): continue
		var before := _full_fingerprint(loaded)
		_check(JSON.stringify(_protected(loaded)) == str(reference.protected_json), "cold full relevant state equals producer official load: " + str(reference.slot))
		_check(_money_lines(loaded) == reference.money_lines, "cold journal units and amounts match: " + str(reference.slot))
		if bool(reference.legacy): _check(_purchase_rows(loaded).is_empty(), "cold legacy slip never acquires a backfilled purchase row")
		for row in _purchase_rows(loaded): _assert_row(loaded, row, _slip_by_id(loaded, str(row.get("slip_id", ""))), str(reference.slot))
		for repeat in range(3): _money_lines(loaded); loaded.numbers_recent_slips()
		_check(_full_fingerprint(loaded) == before, "cold readers never add rows debit or change full run: " + str(reference.slot))
		facts.cold.append({"slot": reference.slot, "cash": loaded.bankroll, "chips": loaded.grand_casino_chips, "slips": loaded.numbers_state.slips.size(), "purchase_rows": _purchase_rows(loaded).size(), "money_lines": _money_lines(loaded)})
	completed = true


func _slip_by_id(run: RunState, slip_id: String) -> Dictionary:
	for slip in run.numbers_state.slips:
		if str(slip.get("id", "")) == slip_id: return slip
	return {}


func _purchase_rows(run: RunState) -> Array:
	var rows: Array = []
	for row in run.story_log:
		if str(row.get("type", "")) == PURCHASE: rows.append(row)
	return rows


func _money_lines(run: RunState) -> Array:
	var lines: Array = []
	for row in run.story_log: lines.append(Journal._recorded_money_detail_lines(row))
	return lines


func _has_hidden_keys(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if str(key) in ["detected", "detection_percent", "past_post", "physical", "physical_state", "winning_number", "known_number", "knowledge"] or _has_hidden_keys(value[key]): return true
	elif value is Array:
		for item in value:
			if _has_hidden_keys(item): return true
	return false


func _persistent_fingerprint(value: Variant) -> String:
	# JSON numeric transport normalization only; no field is discarded. Exact
	# full fingerprints remain strict for all same-process rejection/read checks.
	return Runtime.content_fingerprint(JSON.parse_string(JSON.stringify(value)))


func _reference_path() -> String: return private_root.path_join("numbers-purchase-journal-reference.json")


func _private_roots() -> bool:
	private_root = OS.get_environment("BTH_WORLD_REENTRY_ROOT").replace("\\", "/").simplify_path()
	if not _check(private_root.is_absolute_path() and "native-private-" in private_root, "explicit disposable native root required"): return false
	for key in ["APPDATA", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path().to_lower()
		if not _check(path == private_root.to_lower() or path.begins_with(private_root.to_lower() + "/"), "private containment for " + key): return false
	return _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "original player saves and browser profiles are excluded")


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok


func _finish() -> void:
	_check(completed, "requested producer or cold stage reaches final assertion")
	var report := {"id": "BTH-NUMBERS-PURCHASE-JOURNAL-001", "mode": "cold" if OS.get_cmdline_user_args().has("--cold") else "producer", "checks": checks, "failures": failures, "facts": facts, "source_sha256": {"run_state": FileAccess.get_sha256("res://scripts/core/run_state.gd"), "numbers": FileAccess.get_sha256("res://scripts/core/numbers_model.gd"), "journal": FileAccess.get_sha256("res://scripts/ui/run_journal_view_model.gd"), "archive": FileAccess.get_sha256("res://scripts/core/run_money_flow_archive.gd"), "test": FileAccess.get_sha256("res://scripts/tests/numbers_purchase_journal_check.gd")}, "fidelity": "Disposable RunState.start_new/canonical set_environment and normal numbers_buy_slip API. Explicit synthetic Numbers-clock setup for Corner Store Draw2 and closed-book fixture. Official SaveService plus independent cold load and exact old-slip shape; no original R05 profile, hidden draw replay, Host/rendered/Web path or publication claim."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	print("NUMBERS_PURCHASE_JOURNAL_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
