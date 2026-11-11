extends SceneTree

# Synthetic settlement controls never replay a historical heist. Captured
# terminal modes only load/read/save the already accepted outcome.
const Archive := preload("res://scripts/core/run_money_flow_archive.gd")
const Report := preload("res://scripts/ui/run_report_view_model.gd")
const Screen := preload("res://scripts/ui/run_report_screen.gd")
const Heist := preload("res://scripts/core/crew_heist_model.gd")
const EXPECTATION_PATH := "user://count-money-expected.bin"
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if not check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "explicit disposable diagnostic root required"):
		_finish(); return
	var mode := OS.get_environment("BTH_COUNT_MONEY_CASE")
	if mode == "synthetic":
		_legacy_guards()
		_synthetic_settlements()
		await _display()
	elif mode in ["terminal", "before", "cold"]:
		if _install_bundle(): await _captured(mode)
	elif mode == "prospective_write":
		_prospective_write()
	elif mode == "prospective_read":
		_prospective_read()
	else:
		check(false, "explicit synthetic/captured/prospective mode required")
	_finish()

func _legacy_fixture(payout: Variant = 720) -> Dictionary:
	return {
		"run_status": "ended", "crew_state": {"crew_heist": {"status": "completed", "plan_id": "the_count", "outcome": "somebody_got_pinched", "payout": payout}},
		"narrative_flags": {"demo_victory": true, "crew_heist_outcome": "somebody_got_pinched", "crew_heist_plan_id": "the_count"},
		"story_log": [{"type": "demo_victory", "objective_id": "crew_heist", "finale_event_id": "heist_finale", "finale_branch": "somebody_got_pinched", "demo_victory_route": "crew_heist", "ended": true}],
	}

func _project(data: Dictionary) -> Dictionary:
	var rows: Array = Report._money_story_with_recorded_heist_payout(data, data.story_log)
	return Report.build_money_flow(rows, {}, data.get("story_money_archive", {}), int(data.get("story_log_archive_count", 0)))

func _legacy_guards() -> void:
	var legacy := _legacy_fixture()
	var before := legacy.duplicate(true)
	check(_net(_project(legacy).rows) == 720, "legacy projection uses explicit committed payout")
	check(_project(legacy) == _project(legacy) and legacy == before, "repeated legacy report never writes history or pays again")
	legacy.bankroll = 999999
	check(_net(_project(legacy).rows) == 720, "legacy amount never comes from current cash")
	for amount in [0, 13, 720]:
		var explicit := _legacy_fixture()
		explicit.story_log[0].merge({"currency": "cash", "bankroll_delta": amount, "currency_delta": amount})
		check(_net(_project(explicit).rows) == amount, "explicit financial row, including zero, wins over legacy state")
	for amount in [null, "720", -1, 1.5, INF]:
		check(_net(_project(_legacy_fixture(amount)).rows) == 0, "invalid legacy payout does not invent money")
	var changed := _legacy_fixture(); changed.run_status = "active"
	check(_net(_project(changed).rows) == 0, "unfinished run cannot acquire a payout from report")
	changed = _legacy_fixture(); changed.crew_state.crew_heist.status = "getaway"
	check(_net(_project(changed).rows) == 0, "unfinished heist has no historical payout fallback")
	changed = _legacy_fixture(); changed.narrative_flags.crew_heist_outcome = "clean_sweep"
	check(_net(_project(changed).rows) == 0, "mismatched saved ending is not treated as an award")
	changed = _legacy_fixture(); changed.story_log[0].finale_branch = "out_hot"
	check(_net(_project(changed).rows) == 0, "mismatched victory row is not treated as an award")
	changed = _legacy_fixture(); changed.story_log.append(changed.story_log[0].duplicate(true))
	check(_net(_project(changed).rows) == 0, "ambiguous duplicate legacy endings fail closed")
	changed = _legacy_fixture(); changed.story_log_archive_count = 1
	check(_net(_project(changed).rows) == 0 and not _project(changed).coverage.complete, "unknown archived prefix is not filled from an ending")
	var receipt: Dictionary = _legacy_fixture().story_log[0].duplicate(true)
	receipt.merge({"currency": "cash", "bankroll_delta": 720, "label": "Heist payout"})
	changed = _legacy_fixture(); changed.story_log_archive_count = 1
	changed.story_money_archive = Archive.append_evicted_rows({}, 0, [receipt])
	check(_net(_project(changed).rows) == 720, "already archived payout is never added again from legacy state")
	var archive := Archive.append_evicted_rows({}, 0, [receipt])
	check(_net(Report.build_money_rows([], {}, archive, 1)) == 720, "prospective receipt survives history eviction exactly once")
	check(_net(Report.build_money_rows([receipt])) == 720, "prospective receipt needs no full-run fallback")
	check(Archive.money_legs(receipt) == {"cash": 720}, "payout is cash even at a Grand table")
	facts["legacy_control"] = _project(before)

func _new_synthetic(plan_id: String, score: int) -> RunState:
	var run := RunState.new()
	run.start_new("COUNT-MONEY-SYNTHETIC-%s-%d" % [plan_id, score])
	run.crew_change_reputation(0)
	run.bankroll = 135; run.grand_casino_chips = 41
	run.crew_heist_state = Heist.begin(plan_id, 0)
	run.crew_heist_state.status = Heist.STATUS_GETAWAY
	run.crew_heist_state.play = {"round": 3, "score": score, "decisions": {}, "pot": 650}
	return run

func _synthetic_settlements() -> void:
	for case in [{"score": 100, "success": true}, {"score": 80, "success": false}, {"score": 68, "success": false}]:
		var run := _new_synthetic(Heist.PLAN_COUNT, case.score)
		var rng_before := run.rng_state
		var expected := Heist.payout_for(run.crew_heist_state, Heist.ladder(case.score, case.success))
		check(run._crew_heist_apply_delivery_resolution("heist:the_count:getaway", case.success, {"outcome": "success" if case.success else "failed"}), "synthetic Count settlement accepts existing internal boundary")
		_check_settled(run, expected, 41)
		check(run.rng_state == rng_before, "receipt emission does not draw additional RNG")
		var settled := run.to_save_snapshot()
		check(run._crew_heist_apply_delivery_resolution("heist:the_count:getaway", case.success, {}), "already completed delivery returns without replay")
		check(run.to_save_snapshot() == settled, "repeat terminal callback changes neither funds nor history")
	for hedged in [false, true]:
		var run := _new_synthetic(Heist.PLAN_WHALE, 100)
		var result := run._crew_heist_finish_whale_exposure(run.crew_heist_state, 1, {"h": hedged})
		check(bool(result.get("ok", false)), "adjacent existing Whale exposure settlement completes")
		_check_settled(run, int(result.get("payout", 0)), 0)

func _check_settled(run: RunState, expected: int, chips: int) -> void:
	check(run.bankroll == 135 + expected and run.grand_casino_chips == chips, "existing exact award and chip consequence are unchanged")
	check(run.run_status == RunState.RUN_STATUS_ENDED and int(run.crew_heist_state.payout) == expected, "saved ending owns same committed payout")
	var endings := run.story_log.filter(func(row): return row.get("type") == "demo_victory")
	check(endings.size() == 1, "one existing victory row owns financial receipt")
	if endings.size() == 1:
		check(int(endings[0].get("bankroll_delta", -1)) == expected and endings[0].get("currency") == "cash", "victory row records actual cash award, including zero")
	var snapshot := Report.snapshot_run(run)
	var report := Report.build(snapshot)
	check(_net(report.money_rows) == expected, "terminal report includes payout once")
	check(Report.build(snapshot) == report, "repeated terminal report is stable")

func _captured(mode: String) -> void:
	var run: Variant = SaveService.new().load_run("foundation_ui_autosave")
	if not check(run is RunState, "official captured Count save loads without authority edits"): return
	var before: Dictionary = run.to_save_snapshot()
	var snapshot := Report.snapshot_run(run)
	var report := Report.build(snapshot)
	var terminal := mode != "before"
	check(run.bankroll == (855 if terminal else 135) and run.grand_casino_chips == 41, "genuine ending wallet identity")
	check(_net(report.money_rows) == (720 if terminal else 0), "genuine explicit saved payout appears only after completed ending")
	check(_net(report.money_rows, "game:blackjack", "chips") == 17, "separate actual Blackjack chip history is unchanged")
	check(_net(report.money_rows, "travel", "cash") == -141, "separate actual travel history is unchanged")
	check(Report.build(Report.snapshot_run(run)) == report and run.to_save_snapshot() == before, "actual report leaves full ending/history/paid state/RNG unchanged")
	check(run.story_log.all(func(row): return row.get("type") != "demo_victory" or not row.has("bankroll_delta")), "legacy financial row is not retrospectively written")
	await _display(report.money_rows)
	facts["captured"] = {"case": mode, "money_rows": report.money_rows, "coverage": report.money_coverage}

func _prospective_write() -> void:
	var run := _new_synthetic(Heist.PLAN_COUNT, 68)
	var synthetic_heist := run.crew_heist_state.duplicate(true)
	# Establish the ordinary starting room before arming a synthetic getaway;
	# an active heist intentionally restricts generation/travel destinations.
	run.crew_heist_state = {}
	var library := ContentLibrary.new(); library.load(false)
	var generator := RunGenerator.new(library)
	var room := generator.next_environment(run)
	if not check(room != null and not str(run.current_environment.get("id", "")).is_empty(), "normal generated room makes synthetic save authoritative"): return
	check(bool(run.validate_room_action_authority().get("ok", false)), "synthetic starting room has actual valid room authority")
	# Initialize normal save defaults before the synthetic award. This avoids
	# comparing a never-loaded new-run shape with existing restore defaults.
	if not check(SaveService.new().save_run(run, "count_money_synthetic_base") == OK, "synthetic baseline saves through official service"): return
	var baseline: Variant = SaveService.new().load_run("count_money_synthetic_base")
	if not check(baseline is RunState, "synthetic baseline receives normal restore defaults"): return
	run = baseline
	run.bankroll = 135; run.grand_casino_chips = 41
	run.crew_heist_state = synthetic_heist
	check(run._crew_heist_apply_delivery_resolution("heist:the_count:getaway", false, {"outcome": "failed"}), "new synthetic settlement commits")
	_check_settled(run, 720, 41)
	# Move the real synthetic receipt through the actual bounded-history owner.
	for index in range(241): run.log_story({"type": "synthetic_nonfinancial", "id": str(index)})
	check(_net(Report.build(Report.snapshot_run(run)).money_rows) == 720, "actual compaction preserves exactly one payout")
	if check(SaveService.new().save_run(run, "count_money_prospective") == OK, "official Save persists prospective payout and archive"):
		# Ordinary JSON.stringify rounds some layout/map/audio doubles. Keep an
		# independent, lossless test reference rather than rounding production
		# state or relaxing the exact ending/receipt/RNG comparison below.
		var expected := {"snapshot": _comparison_snapshot(run), "rows": Report.build(Report.snapshot_run(run)).money_rows}
		var reference := FileAccess.open(EXPECTATION_PATH, FileAccess.WRITE)
		if not check(reference != null, "binary expectation opens for writing"): return
		reference.store_var(expected, false)
		var write_error := reference.get_error()
		reference.close()
		if not check(write_error == OK, "lossless expectation writes successfully"): return
		var round_trip := FileAccess.open(EXPECTATION_PATH, FileAccess.READ)
		if not check(round_trip != null, "binary expectation opens for readback"): return
		var persisted: Variant = round_trip.get_var(false)
		round_trip.close()
		check(_equal(expected, persisted), "test reference preserves every original snapshot number exactly")
		check(not _equal(0.14883720930232558, 0.148837209302326), "exact comparison still rejects ordinary-JSON float rounding")
		_prospective_read()

func _prospective_read() -> void:
	var reference := FileAccess.open(EXPECTATION_PATH, FileAccess.READ)
	if not check(reference != null, "previous synthetic binary expectation exists"): return
	var expected: Variant = reference.get_var(false)
	reference.close()
	if not check(typeof(expected) == TYPE_DICTIONARY, "previous synthetic save expectation exists"): return
	var run: Variant = SaveService.new().load_run("count_money_prospective")
	if not check(run is RunState, "fresh SaveService loads prospective synthetic ending"): return
	facts["restore_differences"] = _differences(_comparison_snapshot(run), expected.snapshot)
	check(_equal(_comparison_snapshot(run), expected.snapshot), "official restore preserves full ending/receipts/RNG state")
	check(_equal(Report.build(Report.snapshot_run(run)).money_rows, expected.rows), "cold archived payout remains exactly once")
	var before: Dictionary = run.to_save_snapshot()
	check(run._crew_heist_apply_delivery_resolution("heist:the_count:getaway", false, {}), "cold duplicate callback is already completed")
	check(run.to_save_snapshot() == before, "cold duplicate never rewards or logs again")

func _comparison_snapshot(run: RunState) -> Dictionary:
	var snapshot := run.to_save_snapshot()
	# A newly generated room may be represented by a persistent base reference
	# before Save and expanded after load. Compare its actual owner data on both
	# sides, retaining all fields, paid machines and authority rather than comparing
	# two different storage representations of that same room.
	snapshot["current_environment"] = run.current_environment.duplicate(true)
	return snapshot

func _display(rows: Array = [{"key": "crew_heist", "label": "Heist payout", "currency": "cash", "net": 720}]) -> void:
	var screen := Screen.new(); screen.size = Vector2(1280, 720); root.add_child(screen)
	for small in [false, true]:
		screen.size = Vector2(840, 680) if small else Vector2(1280, 720)
		screen.set_small_screen_mode(small)
		screen.call("_render_story", rows, {})
		await process_frame; await process_frame
		var labels := _labels(screen.story_rows)
		if _net(rows) > 0:
			check(labels.has("Heist payout") and labels.has("+$720"), "actual ordinary/small report controls show named cash payout")
			for line in screen.story_rows.get_children():
				for child in line.get_children():
					if child is Label and child.text == "+$720":
						check(child.get_theme_font("font").get_string_size(child.text, HORIZONTAL_ALIGNMENT_LEFT, -1, child.get_theme_font_size("font_size")).x <= child.size.x, "payout and currency fit actual report amount column")
	screen.queue_free(); await process_frame

func _install_bundle() -> bool:
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	if not check(not bundle.is_empty(), "explicit unchanged custody bundle required"): return false
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	var user_dir := ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(saves); DirAccess.make_dir_recursive_absolute(user_dir)
	for name in ["foundation_ui_autosave.json", "foundation_ui_autosave.json.bak"]:
		if not check(not FileAccess.file_exists(saves.path_join(name)) and DirAccess.copy_absolute(bundle.path_join(name), saves.path_join(name)) == OK, "install private captured " + name): return false
	if not check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"), user_dir.path_join(".crew_host_authority_v1")) == OK, "install private authority companion"): return false
	for pair in [["profile_inventory.json", "BTH_PROFILE_INVENTORY_PATH"], ["meta_collection.json", "BTH_META_COLLECTION_PATH"]]:
		for suffix in ["", ".bak"]:
			if FileAccess.file_exists(bundle.path_join(str(pair[0]) + suffix)):
				if not check(DirAccess.copy_absolute(bundle.path_join(str(pair[0]) + suffix), OS.get_environment(pair[1]) + suffix) == OK, "install private profile companion"): return false
	return true

func _net(rows: Array, key: String = "crew_heist", currency: String = "cash") -> int:
	var total := 0
	for row in rows:
		if row.key == key and row.currency == currency: total += int(row.net)
	return total

func _labels(node: Node) -> Array:
	var result: Array = [node.text] if node is Label else []
	for child in node.get_children(): result.append_array(_labels(child))
	return result

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

func _differences(left: Variant, right: Variant, prefix: String = "") -> Array:
	if _equal(left, right): return []
	var result: Array = []
	if typeof(left) == TYPE_DICTIONARY and typeof(right) == TYPE_DICTIONARY:
		for key in left:
			if not right.has(key): result.append({"path": prefix + "/" + str(key), "kind": "missing expected key"})
			else: result.append_array(_differences(left[key], right[key], prefix + "/" + str(key)))
		for key in right:
			if not left.has(key): result.append({"path": prefix + "/" + str(key), "kind": "missing restored key"})
	elif typeof(left) == TYPE_ARRAY and typeof(right) == TYPE_ARRAY and left.size() == right.size():
		for index in range(left.size()): result.append_array(_differences(left[index], right[index], prefix + "/" + str(index)))
	else:
		result.append({"path": prefix, "restored": left if typeof(left) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_NIL] else JSON.stringify(left).sha256_text(), "expected": right if typeof(right) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_NIL] else JSON.stringify(right).sha256_text()})
	return result.slice(0, 40)

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

func _finish() -> void:
	facts["scope"] = "Synthetic new-run settlements and report guard controls; captured modes never replay the historical award. Prospective read in a separate process is required for fresh-process acceptance. No historical saves are repaired or resaved."
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty(): FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts}, "  "))
	print("COUNT_HEIST_MONEY_FLOW checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
