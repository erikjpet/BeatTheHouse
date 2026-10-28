extends SceneTree

# Synthetic history receipts exercise the actual RunState eviction/save owner.
# No game settlement, payout or historical profile is replayed by this check.
const Archive := preload("res://scripts/core/run_money_flow_archive.gd")
const Report := preload("res://scripts/ui/run_report_view_model.gd")
var checks := 0
var failures: Array[String] = []
var facts := {}
var rules := {"chip_game_ids": RunState.GRAND_CASINO_CHIP_GAME_IDS, "grand_archetype_ids": RunState.GRAND_CASINO_ARCHETYPE_IDS}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if not check(OS.get_environment("BTH_SAVE_DIR").contains("native-private-money-archive"), "private diagnostic save root required"):
		_finish(); return
	var stage := OS.get_environment("BTH_MONEY_ARCHIVE_STAGE")
	if stage.begins_with("legacy"):
		_legacy_roundtrip(stage == "legacy-write")
	elif stage == "read":
		_cold_read()
	else:
		_write_and_check()
	_finish()

func _write_and_check() -> void:
	var run := RunState.new()
	run.start_new("MONEY-ARCHIVE-PERSISTENCE-20261028")
	var library := ContentLibrary.new()
	library.load(false)
	var generator := RunGenerator.new(library)
	var room := generator.next_environment(run, "gas_station_casino")
	if not check(room != null and not run.current_environment.is_empty(), "ordinary generator establishes a valid synthetic save room"):
		return
	run.crew_change_reputation(0)
	# Start a labelled synthetic history on this newly generated diagnostic run.
	run.story_log = []
	run.story_log_archive_count = 0
	run.story_money_archive = Archive.normalize_archive({}, 0)
	var financial := _financial(run)
	var full: Array = []
	for index in range(481):
		var entry := _entry(index)
		full.append(entry)
		run.log_story(entry)
		if index + 1 in [239, 240, 241, 481]:
			_check_history(run, full, "actual log_story %d" % (index + 1))
	check(_financial(run) == financial, "history aggregation changes no wallet, score, debt, action clock or RNG")
	var before: Dictionary = run.to_save_snapshot()
	var transaction := run._environment_turn_snapshot()
	for index in range(481, 486): run.log_story(_entry(index))
	check(run.story_log_archive_count == 246, "transaction candidate really evicts five further rows")
	run._apply_environment_turn_snapshot(transaction, false)
	check(_equal(run.to_save_snapshot(), before), "transaction rollback restores archive, retained history and all state")
	var candidate := run.detached_host_action_candidate("")
	candidate.log_story(_entry(900))
	check(_equal(run.to_save_snapshot(), before), "discarded host candidate cannot mutate the live archive/history")
	check(candidate.story_log_archive_count == 242 and candidate.story_money_archive.known_entry_count == 242, "detached host candidate owns its newly folded prefix")
	var preview := run.to_travel_preview_snapshot()
	check(preview.story_log.is_empty() and preview.story_log_archive_count == 481, "travel snapshot retains its existing omitted-history shape")
	check(Report.build_money_rows([], {}, preview.story_money_archive, 481) == Report.build_money_rows(full), "travel snapshot owns an equivalent summary without losing omitted rows")
	check(_equal(run.to_save_snapshot(), before), "travel snapshot leaves live archive/history byte-value unchanged")
	check(run.to_action_snapshot_without_world().story_money_archive == run.story_money_archive, "ordinary action snapshot carries the persisted aggregate")
	var service := SaveService.new()
	if check(service.save_run(run, "money_archive") == OK, "official SaveService durably installs aggregate and room"):
		var loaded: Variant = SaveService.new().load_run("money_archive")
		if check(loaded is RunState, "fresh service loads new aggregate"):
			check(_equal(_flow(loaded), _flow(run)), "fresh service preserves amounts, currencies and complete coverage")
			check(_financial(loaded) == financial, "fresh service preserves financial/accounting/RNG state")
			check(_equal(loaded.story_money_archive, run.story_money_archive) and _equal(loaded.story_log, run.story_log), "fresh service retains exact prefix aggregate and tail")
			check(service.save_run(loaded, "money_archive") == OK, "repeat Save installs without refolding retained history")
			FileAccess.open(_expected_path(), FileAccess.WRITE).store_string(JSON.stringify({"flow": _flow(run), "financial": financial, "archive": run.story_money_archive, "story": run.story_log}))
	facts = {"archive": run.story_money_archive, "flow": _flow(run), "financial": financial}
	var probe: Variant = SaveService.new().load_run("money_archive")
	if probe is RunState:
		facts["loaded_archive"] = probe.story_money_archive
		facts["loaded_story"] = probe.story_log
		facts["loaded_flow"] = _flow(probe)

func _cold_read() -> void:
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(_expected_path()))
	if not check(typeof(expected) == TYPE_DICTIONARY, "prior process durable expectation exists"):
		return
	var run: Variant = SaveService.new().load_run("money_archive")
	if not check(run is RunState, "genuinely fresh Godot process restores the new-field save"):
		return
	check(_equal(_flow(run), expected.flow), "fresh process preserves all currency totals and coverage")
	check(_equal(_financial(run), expected.financial), "fresh process preserves financial/accounting/RNG state")
	check(_equal(run.story_money_archive, expected.archive) and _equal(run.story_log, expected.story), "fresh process preserves exact known prefix and retained tail")
	var before: Dictionary = run.to_save_snapshot()
	var repeated := _flow(run)
	check(_flow(run) == repeated and _equal(run.to_save_snapshot(), before), "repeated report is read-only after cold Continue")
	run.log_story(_entry(481))
	var full: Array = []
	for index in range(482): full.append(_entry(index))
	_check_history(run, full, "post-cold next eviction")
	check(SaveService.new().save_run(run, "money_archive") == OK, "post-cold next eviction remains durably saveable")
	facts = {"cold": true, "archive": run.story_money_archive, "flow": _flow(run)}

func _check_history(run: RunState, full: Array, label: String) -> void:
	var overflow := maxi(0, full.size() - 240)
	check(run.story_log.size() == mini(240, full.size()) and run.story_log_archive_count == overflow, label + " bounded history and removed count")
	check(int(run.story_money_archive.known_entry_count) == overflow and int(run.story_money_archive.archived_entry_count) == overflow, label + " exact known prefix counters")
	check(_flow(run).rows == Report.build_money_rows(full), label + " aggregate plus tail equals every actual recorded receipt once")
	check(_flow(run).coverage.complete, label + " complete history coverage")

func _flow(run: RunState) -> Dictionary:
	return Report.build_money_flow(run.story_log, {}, run.story_money_archive, run.story_log_archive_count)

func _financial(run: RunState) -> Dictionary:
	var snapshot := run.to_save_snapshot()
	var result := {}
	for key in ["bankroll", "grand_casino_chips", "rng_state", "run_status", "debt", "suspicion", "game_clock_minutes", "simulation_msec", "run_spending_score", "inventory", "active_delivery_run"]:
		result[key] = snapshot.get(key)
	result["profile_won"] = run.narrative_flags.get("profile_bankroll_won", 0)
	result["profile_lost"] = run.narrative_flags.get("profile_bankroll_lost", 0)
	return result

func _legacy_roundtrip(write: bool) -> void:
	if write and not _install_bundle(): return
	var run: Variant = SaveService.new().load_run("foundation_ui_autosave" if write else "money_archive_legacy")
	if not check(run is RunState, "official legacy save loads in private storage"):
		return
	check(run.bankroll == 57 and run.grand_casino_chips == 125, "actual legacy Gold wallet remains 57 cash/125 chips")
	check(run.story_log_archive_count == 24 and run.story_log.size() == 240, "actual legacy removed prefix remains 24 rows")
	check(_flow(run).coverage.unknown_entry_count == 24 and run.story_money_archive.known_entry_count == 0, "missing legacy prefix remains unknown through persistence")
	var protected := {"financial": _financial(run), "story": run.story_log, "flow": _flow(run), "score": Report.build(Report.snapshot_run(run)).score, "bags": run.pending_bags}
	if write:
		check(SaveService.new().save_run(run, "money_archive_legacy") == OK, "official legacy save persists honest unknown coverage")
		FileAccess.open("user://money-archive-legacy-expected.json", FileAccess.WRITE).store_string(JSON.stringify(protected))
	else:
		var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://money-archive-legacy-expected.json"))
		check(_equal(protected, expected), "fresh Godot process preserves legacy wallet/receipts/RNG/rewards/score and partial report")
		var before: Dictionary = run.to_save_snapshot()
		var again := _flow(run)
		check(again == _flow(run) and _equal(run.to_save_snapshot(), before), "legacy report never reconstructs or mutates lost history")
	facts = protected

func _install_bundle() -> bool:
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	if not check(not bundle.is_empty(), "explicit copied legacy fixture required"): return false
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	var user_dir := ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(saves)
	DirAccess.make_dir_recursive_absolute(user_dir)
	for name in ["foundation_ui_autosave.json", "foundation_ui_autosave.json.bak"]:
		if FileAccess.file_exists(bundle.path_join(name)) and not check(not FileAccess.file_exists(saves.path_join(name)) and DirAccess.copy_absolute(bundle.path_join(name), saves.path_join(name)) == OK, "install unchanged copied " + name): return false
	if not check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"), user_dir.path_join(".crew_host_authority_v1")) == OK, "install copied legacy authority"): return false
	for pair in [["profile_inventory.json", "BTH_PROFILE_INVENTORY_PATH"], ["meta_collection.json", "BTH_META_COLLECTION_PATH"], ["settings.json", "BTH_USER_SETTINGS_PATH"]]:
		for suffix in ["", ".bak"]:
			var original := bundle.path_join(str(pair[0]) + suffix)
			if FileAccess.file_exists(original) and not check(DirAccess.copy_absolute(original, OS.get_environment(pair[1]) + suffix) == OK, "install copied legacy companion"): return false
	return true

func _entry(index: int) -> Dictionary:
	match index % 5:
		0: return {"type": "game_action", "game_id": "blackjack", "environment_id": "grand_casino_005", "bankroll_delta": -3, "label": "Blackjack"}
		1: return {"type": "game_action", "game_id": "craps", "environment_archetype_id": "grand_casino", "currency": "chips", "chips_delta": 7, "bankroll_delta": 7, "label": "Craps"}
		2: return {"type": "travel", "bankroll_delta": -4}
		3: return {"type": "item_sale", "sale_price": 5}
	return {"type": "event", "bankroll_delta": 0}

func _expected_path() -> String: return "user://money-archive-expected.json"

func _equal(left: Variant, right: Variant) -> bool:
	if typeof(left) in [TYPE_INT, TYPE_FLOAT] and typeof(right) in [TYPE_INT, TYPE_FLOAT]: return left == right
	if typeof(left) != typeof(right): return false
	if typeof(left) == TYPE_DICTIONARY:
		if left.size() != right.size(): return false
		for key in left:
			if not right.has(key) or not _equal(left[key], right[key]): return false
		return true
	if typeof(left) == TYPE_ARRAY:
		if left.size() != right.size(): return false
		for index in range(left.size()):
			if not _equal(left[index], right[index]): return false
		return true
	return left == right

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok

func _finish() -> void:
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty(): FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts}, "\t"))
	print("MONEY_FLOW_RUNSTATE_PERSISTENCE checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
