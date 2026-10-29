extends SceneTree

# Exact stored post-settlement table; render-only reads and official SaveService.
# Never enter a wager, draw, settle, travel or change the original campaign.
const Baccarat := preload("res://scripts/games/baccarat.gd")
const Canvas := preload("res://scripts/ui/game_surface_canvas.gd")
const Runtime := preload("res://scripts/core/game_ritual_runtime.gd")
const SLOT := "baccarat_notice_roundtrip"
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cold := OS.get_environment("BTH_BACCARAT_NOTICE_STAGE") == "cold"
	if not _private_roots() or not cold and not _install_bundle():
		_finish(); return
	var run: Variant = SaveService.new().load_run(SLOT if cold else "foundation_ui_autosave")
	if not check(run is RunState, "official unchanged private captured run loads"):
		_finish(); return
	var environment: Dictionary = run.grand_casino_room_states.get("grand_casino_high_limit", {})
	var table: Dictionary = environment.get("game_states", {}).get("baccarat", {})
	var session: Dictionary = table.get("_blackjack_action_authority", {}).get("session", {})
	if not check(str(session.get("table_notice", "")) == "$5 on BANKER.", "actual stored legacy notice is exact captured dollar literal"):
		_finish(); return
	check(int(session.get("baccarat_bets", {}).get("banker", 0)) == 90, "actual later layout is90, so notice amount must not be inferred from current bets")
	check(run.bankroll == 71 and run.grand_casino_chips == 240, "accepted Banker settlement retains71cash240chips")
	check(str(table.get("last_result", {}).get("currency", "")) == "chips", "recorded table settlement explicitly denominates chips")
	var library := ContentLibrary.new(); library.load(false)
	var game := Baccarat.new(); game.setup(library.game("baccarat"), library)
	var before: Dictionary = run.to_save_snapshot()
	var protected := _protected(run)
	var currency := GameModule.presentation_currency_for_game(run, "baccarat", environment)
	check(currency == "chips", "display denomination comes from the actual recorded Grand table context")
	var now := int(table.get("last_result", {}).get("resolved_at_msec", 0)) + 100000
	# Explicit detached render time after finite presentation, not a game clock
	# assignment or accepted action. Exact saved table and ledger remain intact.
	var ui := {"surface_time_msec": now}
	var state: Dictionary = game.surface_state(run, environment, ui)
	var patch: Dictionary = game.surface_realtime_state_patch(run, environment, ui, state)
	check(str(state.get("table_notice", "")) == "5 chips on BANKER.", "actual full projection formats recorded5 as chips")
	check(str(patch.get("table_notice", "")) == "5 chips on BANKER.", "actual realtime projection agrees")
	check(str(session.get("table_notice", "")) == "$5 on BANKER.", "source literal remains unchanged")
	check(run.to_save_snapshot() == before, "full and realtime projections leave complete saved run unchanged")
	var canvas := Canvas.new()
	var font := canvas.get_theme_default_font()
	check(font.get_string_size(str(state.table_notice), HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x <= 424, "corrected notice fits existing424pixel notice area")
	canvas.free()
	if not cold: _synthetic_controls(game)
	check(_protected(run) == protected, "repeated formatting preserves entire stored table, account, flags, history and RNG")
	check(SaveService.new().save_run(run, SLOT) == OK, "official private normal save succeeds without migrating historical notice")
	var restored: Variant = SaveService.new().load_run(SLOT)
	if check(restored is RunState, "fresh SaveService restores unchanged historical data"):
		check(_protected(restored) == protected, "cold codec preserves full table/ledger, finances, commission, history and RNG")
		var restored_environment: Dictionary = restored.grand_casino_room_states.get("grand_casino_high_limit", {})
		var restored_state: Dictionary = game.surface_state(restored, restored_environment, ui)
		check(str(restored_state.get("table_notice", "")) == "5 chips on BANKER.", "fresh restored reader still displays correct units without editing the saved literal")
	facts = {"stage": "independent_process_cold" if cold else "write", "currency": currency, "saved_literal": session.table_notice, "display": state.table_notice, "later_staged_banker": session.baccarat_bets.banker, "cash": run.bankroll, "chips": run.grand_casino_chips, "protected": protected, "scope": "Actual stored-table projections and SaveService; no normal-player Web or native table-entry claim. Detached cases test only recognized historical grammar."}
	_finish()


func _synthetic_controls(game: Variant) -> void:
	var cases: Array = []
	for target in Baccarat.BET_TARGETS:
		var suffix := " on %s." % str(target.label)
		cases.append({"raw": "$5" + suffix, "display": "5 chips" + suffix})
		cases.append({"raw": "$1" + suffix, "display": "1 chip" + suffix})
		cases.append({"raw": "Following Iris with: $25" + suffix, "display": "Following Iris with: 25 chips" + suffix})
		cases.append({"raw": "Fading Mr $5 against: $7" + suffix, "display": "Fading Mr $5 against: 7 chips" + suffix})
	cases.append_array([
		{"raw": "$5 chip selected.", "display": "5 chips selected."},
		{"raw": "$1 chip selected.", "display": "1 chip selected."},
		{"raw": "$5 selected.", "display": "5 chips selected."},
		{"raw": "$1000 on BANKER.", "display": "1000 chips on BANKER."},
		{"raw": "$9223372036854775807 on BANKER.", "display": "9223372036854775807 chips on BANKER."},
	])
	for row in cases:
		for currency in ["chips", "cash", "", "unknown"]:
			var expected: String = row.display if currency == "chips" else row.raw
			check(game._stored_table_notice_for_currency(row.raw, currency) == expected, "known authored grammar uses only supplied recorded denomination")
		check(game._stored_table_notice_for_currency(row.display, "chips") == row.display, "newer formatted messages remain idempotent")
	for unknown in ["", "Bets cleared.", "Guest offered $5.", "$? on BANKER.", "$5.50 on BANKER.", "$-5 on BANKER.", "$+5 on BANKER.", "$05 on BANKER.", "$9223372036854775808 on BANKER.", "$9999999999999999999999999999 on BANKER.", "$5 on CUSTOM.", "Gift $5 on BANKER.", " $5 on BANKER.", "$5 on BANKER", "Following Iris against: $5 on BANKER."]:
		check(game._stored_table_notice_for_currency(unknown, "chips") == unknown, "unknown/unrelated text or amount is never inferred or rewritten")
	var original := {"table_notice": "$5 on BANKER.", "baccarat_bets": {"banker": 90}}
	var copied := original.duplicate(true)
	check(game._table_notice({}, original, {}, false, false, {}, "chips") == "5 chips on BANKER.", "notice reader formats only returned text")
	check(original == copied, "notice reader preserves exact input dictionaries")
	check(game._table_notice({}, original, {}, true, false, {}, "chips") == "No more bets. Cards are sliding from the shoe.", "active Deal message retains precedence")
	check(game._table_notice({}, original, {"winner": "banker"}, false, true, {}, "chips").contains("settling"), "active payout message retains precedence")


func _protected(run: RunState) -> Dictionary:
	var table: Dictionary = run.grand_casino_room_states.get("grand_casino_high_limit", {}).get("game_states", {}).get("baccarat", {})
	return {"table_sha256": Runtime.canonical_fingerprint(table), "cash": run.bankroll, "chips": run.grand_casino_chips, "history_sha256": Runtime.canonical_fingerprint(run.story_log), "flags_sha256": Runtime.canonical_fingerprint(run.narrative_flags), "debt_sha256": Runtime.canonical_fingerprint(run.debt), "rng_sha256": Runtime.canonical_fingerprint(run.rng_state), "game_clock_minutes": run.game_clock_minutes, "simulation_msec": run.simulation_msec, "spending_score": run.run_spending_score}


func _private_roots() -> bool:
	var distribution := OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").replace("\\", "/").simplify_path()
	if not check(distribution.is_absolute_path() and "native-private-" in distribution, "explicit maintained private persistence root required"): return false
	var prefix := distribution.get_base_dir().to_lower()
	for key in ["BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH", "APPDATA"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path().to_lower()
		if not check(path == prefix or path.begins_with(prefix + "/"), "private containment for " + key): return false
	return true


func _install_bundle() -> bool:
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	if not check(bundle.is_absolute_path(), "unchanged actual private bundle required"): return false
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	var user_dir := ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(saves); DirAccess.make_dir_recursive_absolute(user_dir)
	for name in ["foundation_ui_autosave.json", "foundation_ui_autosave.json.bak"]:
		if FileAccess.file_exists(bundle.path_join(name)) and not check(not FileAccess.file_exists(saves.path_join(name)) and DirAccess.copy_absolute(bundle.path_join(name), saves.path_join(name)) == OK, "copy unchanged private " + name): return false
	if not check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"), user_dir.path_join(".crew_host_authority_v1")) == OK, "copy original authority companion"): return false
	for pair in [["profile_inventory.json", "BTH_PROFILE_INVENTORY_PATH"], ["meta_collection.json", "BTH_META_COLLECTION_PATH"], ["settings.json", "BTH_USER_SETTINGS_PATH"]]:
		for suffix in ["", ".bak"]:
			var original := bundle.path_join(str(pair[0]) + suffix)
			if FileAccess.file_exists(original) and not check(DirAccess.copy_absolute(original, OS.get_environment(pair[1]) + suffix) == OK, "copy private " + str(pair[0]) + suffix): return false
	return true


func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok


func _finish() -> void:
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty(): FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts}, "\t"))
	print("BACCARAT_LEGACY_NOTICE checks=%d failures=%s" % [checks, str(failures)])
	quit(0 if failures.is_empty() else 1)
