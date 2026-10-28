extends SceneTree

# Actual post-settlement copy plus explicitly synthetic reader controls. No Deal,
# wager, payout, shoe or RNG action is replayed. Run cold in a second private job.
const Host := preload("res://scripts/ui/foundation_main.gd")
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cold := OS.get_environment("BTH_BACCARAT_READER_STAGE") == "cold"
	if not _private_roots() or not cold and not _install_bundle():
		_finish()
		return
	var slot := "baccarat_currency_roundtrip" if cold else "foundation_ui_autosave"
	var reference: Variant = SaveService.new().load_run(slot)
	if not check(reference is RunState, "official private actual Banker save loads"):
		_finish()
		return
	var expected := _protected(reference)
	var recorded := _last_baccarat(reference)
	check(reference.bankroll == 71 and reference.grand_casino_chips == 240, "actual settled copy retains cash71 and chips240")
	check(int(recorded.get("bankroll_delta", 0)) == 85 and int(recorded.get("stake_cost", 0)) == 90, "captured Banker receipt records original stake90 and net85")
	check(not recorded.has("currency") and not recorded.has("currency_delta"), "legacy original has no denomination metadata before readers")
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	app.autosave_slot_id = slot
	if check(app.load_foundation_run(), "ordinary native Host Continue loads actual completed hand"):
		for frame in range(3): await process_frame
		app.set_process(false)
		check(_equal(_protected(app.run_state), expected), "Continue preserves wallet, flags, score, debt, game rows and RNG")
		var before := var_to_bytes(app.run_state.story_log)
		var warm: Dictionary = app.call("_result_from_story_log", [recorded])
		var saved: Dictionary = app.call("_game_result_from_story_log", app.run_state.story_log)
		for result in [warm, saved]:
			check(str(result.get("currency", "")) == "chips" and int(result.get("currency_delta", 0)) == 85, "warm and saved readers retain chip85")
			check(int(result.get("bankroll_delta", -1)) == 0 and int(result.get("chips_delta", 0)) == 85, "display-only result does not alias85 chips to cash")
			check(str(app.call("_environment_result_currency_lead", result, 0)) == "Chip change: +85 chips.", "existing HUD lead reports chip units")
		check(var_to_bytes(app.run_state.story_log) == before, "legacy denomination recovery never rewrites durable history")
		var view: Dictionary = app.call("_environment_result_feedback_view")
		app.call("_refresh_environment_result_feedback")
		check(bool(view.get("visible", false)) and str(view.get("text", "")).contains("+85 chips"), "actual restored Result HUD contains correct amount and units")
		check(not str(view.get("text", "")).contains("$"), "actual chip Result contains no false dollar suffix")
		check(app.environment_result_body_label.text == str(view.get("text", "")), "real builder Label receives the projected unit-aware Result")
		if not cold: _synthetic_reader_controls()
		check(_equal(_protected(app.run_state), expected), "all display readers preserve accepted financial state")
		app.save_service.wait_for_async_save()
		var error: Error = app.save_service.save_run(app.run_state, "baccarat_currency_roundtrip")
		check(error == OK, "official private Save succeeds after display")
		var restored: Variant = SaveService.new().load_run("baccarat_currency_roundtrip") if error == OK else null
		if check(restored is RunState, "fresh SaveService restores private saved state"):
			check(_equal(_protected(restored), expected), "Save/restore preserves accepted balances, receipts, stats and RNG")
			check(not _last_baccarat(restored).has("currency"), "display recovery does not retrofit legacy story metadata")
		facts = {"stage": "independent_process_cold" if cold else "write", "cash": app.run_state.bankroll, "chips": app.run_state.grand_casino_chips, "recorded_net": int(recorded.get("bankroll_delta", 0)), "HUD": view.get("text", ""), "game_rows": expected.game_rows.size(), "scope": "Actual copied already-settled Banker receipt; no wager/settlement replay. Synthetic reader controls are separate; this is native, not Web evidence."}
		app.save_service.wait_for_async_save()
	app.queue_free()
	await process_frame
	_finish()


func _synthetic_reader_controls() -> void:
	var probe := Host.new()
	# This deliberately unmounted reader fixture does not execute Host._ready().
	probe.TerminalConsequenceViewModelScript = preload("res://scripts/ui/terminal_consequence_view_model.gd")
	probe.run_state = RunState.new()
	var cases := [
		{"name": "recorded chip win in current cash venue", "current": "riverboat", "id": "grand_casino_high_limit_004", "delta": 85, "chips": true},
		{"name": "recorded chip loss", "current": "riverboat", "id": "grand_casino_004", "delta": -90, "chips": true},
		{"name": "recorded chip zero", "current": "riverboat", "id": "grand_casino_004", "delta": 0, "chips": true},
		{"name": "cash win in current chip venue", "current": "grand_casino", "id": "riverboat_004", "delta": 85, "chips": false},
		{"name": "cash loss", "current": "grand_casino", "id": "riverboat_004", "delta": -90, "chips": false},
		{"name": "cash zero", "current": "grand_casino", "id": "riverboat_004", "delta": 0, "chips": false},
		{"name": "no source never borrows current room", "current": "grand_casino", "delta": 85, "chips": false},
		{"name": "impostor source is not generated Grand", "current": "grand_casino", "id": "grand_casino_high_limit_impostor", "delta": 85, "chips": false},
		{"name": "explicit cash archetype overrides conflicting id", "current": "grand_casino", "id": "grand_casino_004", "archetype": "riverboat", "delta": 85, "chips": false},
		{"name": "recorded chip archetype needs no generated id", "current": "riverboat", "archetype": "grand_casino_high_limit", "delta": 85, "chips": true},
		{"name": "explicit cash unit overrides venue", "current": "grand_casino", "id": "grand_casino_004", "currency": "cash", "delta": 85, "chips": false},
		{"name": "explicit chip unit survives travel", "current": "riverboat", "id": "riverboat_004", "currency": "chips", "delta": 85, "chips": true},
	]
	for fixture in cases:
		probe.run_state.current_environment = {"id": str(fixture.current) + "_999", "archetype_id": fixture.current}
		var row := {"type": "game_action", "game_id": "baccarat", "action_id": "deal_baccarat", "bankroll_delta": fixture.delta, "suspicion_delta": 0}
		if fixture.has("id"): row["environment_id"] = fixture.id
		if fixture.has("archetype"): row["environment_archetype_id"] = fixture.archetype
		if fixture.has("currency"):
			row["currency"] = fixture.currency
			row["currency_delta"] = fixture.delta
		var before := var_to_bytes(row)
		var result: Dictionary = probe.call("_game_result_from_story_log", [row])
		var uses_chips: bool = str(result.get("currency", "")) == "chips"
		check(uses_chips == bool(fixture.chips), str(fixture.name) + ": units come from recorded source")
		check(int(result.get("bankroll_delta", 0)) == (0 if fixture.chips else int(fixture.delta)), str(fixture.name) + ": cash alias is retained only for cash")
		if fixture.chips:
			check(int(result.get("currency_delta", 1)) == int(fixture.delta) and int(result.get("chips_delta", 1)) == int(fixture.delta), str(fixture.name) + ": zero and signed chip amount preserved")
		check(var_to_bytes(row) == before, str(fixture.name) + ": input history remains immutable")
	# The Baccarat fallback must not weaken the measured-versus-unknown penalty contract.
	for amount in [-10, 0]:
		var witness := {"schema": "bth.applied_currency_settlement/v1", "currency": "chips", "delta": amount, "cash_delta": 0, "chips_delta": amount, "nominal_cash_delta": 0, "nominal_chips_delta": -40}
		var row := {"type": "game_action", "game_id": "blackjack", "action_id": "peek_hole_card", "bankroll_delta": amount, "environment_id": "grand_casino_004", "dealer_caught_cheat": true, "applied_currency_settlement": witness}
		var result: Dictionary = probe.call("_game_result_from_story_log", [row])
		check(not bool(result.get("applied_currency_unknown", false)) and int(result.get("currency_delta", 1)) == amount, "existing Blackjack known amount/zero remains measured")
		check(int(result.get("bankroll_delta", -1)) == 0, "existing measured Blackjack does not gain cash alias")
	var unknown := {"type": "game_action", "game_id": "blackjack", "action_id": "play_basic", "bankroll_delta": -53, "environment_id": "grand_casino_high_limit_004", "dealer_caught_cheat": true}
	var legacy: Dictionary = probe.call("_game_result_from_story_log", [unknown])
	check(bool(legacy.get("applied_currency_unknown", false)) and not legacy.has("currency_delta"), "legacy caught Stand stays unknown, not invented zero")
	check(int(legacy.get("nominal_bankroll_delta", 0)) == -53 and int(legacy.get("bankroll_delta", -1)) == 0, "legacy nominal53 remains distinct from actual cash")
	probe.free()


func _protected(run: RunState) -> Dictionary:
	var rows: Array = []
	for row in run.story_log:
		if typeof(row) == TYPE_DICTIONARY and str(row.get("type", "")) == "game_action": rows.append(row.duplicate(true))
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "rng": str(run.rng_state), "flags": run.narrative_flags.duplicate(true), "spending_score": run.run_spending_score, "debt": run.debt.duplicate(true), "game_rows": rows, "inventory": run.inventory.duplicate(true), "bags": run.pending_bags.duplicate(true), "archive": run.story_money_archive.duplicate(true), "archive_count": run.story_log_archive_count, "status": run.run_status}


func _last_baccarat(run: RunState) -> Dictionary:
	for index in range(run.story_log.size() - 1, -1, -1):
		var row: Variant = run.story_log[index]
		if typeof(row) == TYPE_DICTIONARY and str(row.get("type", "")) == "game_action" and str(row.get("game_id", "")) == "baccarat": return row
	return {}


func _private_roots() -> bool:
	var root_path := OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").replace("\\", "/").simplify_path()
	if not check(root_path.is_absolute_path() and "native-private-" in root_path, "maintained private native persistence root is required"): return false
	var private_root := root_path.get_base_dir().to_lower()
	var private_prefix := private_root + "/"
	for key in ["BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH", "APPDATA"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path()
		if not check(path.is_absolute_path() and (path.to_lower() == private_root or path.to_lower().begins_with(private_prefix)), "isolated " + key + " must remain in this private job"): return false
	return true


func _install_bundle() -> bool:
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	if not check(bundle.is_absolute_path(), "explicit copied actual fixture required"): return false
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	var user_dir := ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(saves)
	DirAccess.make_dir_recursive_absolute(user_dir)
	for name in ["foundation_ui_autosave.json", "foundation_ui_autosave.json.bak"]:
		if FileAccess.file_exists(bundle.path_join(name)) and not check(not FileAccess.file_exists(saves.path_join(name)) and DirAccess.copy_absolute(bundle.path_join(name), saves.path_join(name)) == OK, "install private unchanged " + name): return false
	if not check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"), user_dir.path_join(".crew_host_authority_v1")) == OK, "install copied authority companion"): return false
	for pair in [["profile_inventory.json", "BTH_PROFILE_INVENTORY_PATH"], ["meta_collection.json", "BTH_META_COLLECTION_PATH"], ["settings.json", "BTH_USER_SETTINGS_PATH"]]:
		for suffix in ["", ".bak"]:
			var original := bundle.path_join(str(pair[0]) + suffix)
			if FileAccess.file_exists(original) and not check(DirAccess.copy_absolute(original, OS.get_environment(pair[1]) + suffix) == OK, "install copied private companion"): return false
	return true


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
	print("BACCARAT_RECORDED_CURRENCY checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
