extends SceneTree

const Archive := preload("res://scripts/core/run_money_flow_archive.gd")
const Report := preload("res://scripts/ui/run_report_view_model.gd")
var checks := 0
var failures: Array[String] = []
var facts := {}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if _install_bundle():
		var loaded: Variant = SaveService.new().load_run("foundation_ui_autosave")
		if check(loaded is RunState, "official SaveService restores private historical Gold save"):
			_check_run(loaded)
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty(): FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts, "fidelity": "Official legacy SaveService load in a fresh bounded process; read-only report projection. Full prefix reconciliation uses separately preserved already-executed public history on a detached report dictionary, never repairs or resaves historical authority. New aggregate RunState persistence requires primary-owned integration."}, "\t"))
	print("MONEY_FLOW_ARCHIVE_CAPTURED_LEGACY checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check_run(run: RunState) -> void:
	var before := run.to_save_snapshot()
	var snapshot := Report.snapshot_run(run)
	var report := Report.build(snapshot)
	check(int(snapshot.story_log_archive_count) == 24 and snapshot.story_log.size() == 240, "captured 264-row run has exact 24/240 boundary")
	check(report.money_coverage.unknown_entry_count == 24 and not report.money_coverage.complete, "legacy missing archive remains unknown rather than reconstructed")
	check(_net(report.money_rows, "blackjack", "chips") == 0 and _net(report.money_rows, "craps", "chips") == 50, "actual retained game receipts remain 0/+50 chips")
	check(run.bankroll == 57 and run.grand_casino_chips == 125, "preserved actual Gold wallet stays $57/125 chips")
	check(int(report.score.final_score) == 114, "Gold terminal score remains 114")
	var early: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BTH_MONEY_FLOW_EARLY")))
	if check(typeof(early) == TYPE_DICTIONARY and early.get("story_log", []).size() == 227 and int(early.get("story_log_archive_count", 0)) == 0, "earlier copied public checkpoint has complete 227-row history"):
		var overlap_ok := true
		for index in range(24, 227):
			if not _equal(early.story_log[index], snapshot.story_log[index - 24]): overlap_ok = false
		check(overlap_ok, "all 203 overlapping public history rows agree exactly in value")
		var rules := {"chip_game_ids": RunState.GRAND_CASINO_CHIP_GAME_IDS, "grand_archetype_ids": RunState.GRAND_CASINO_ARCHETYPE_IDS}
		var prefix := Archive.append_evicted_rows({}, 0, early.story_log.slice(0, 24), rules)
		var detached := snapshot.duplicate(true)
		detached.story_money_archive = prefix
		var full := Report.build(detached)
		check(full.money_coverage.complete and full.money_coverage.known_entry_count == 24, "legitimately recorded detached prefix makes full-run coverage complete")
		check(_net(full.money_rows, "blackjack", "chips") == -10 and _net(full.money_rows, "craps", "chips") == 70, "actual full-run -10/+70 chip totals survive the display-history cap")
		check(_net(full.money_rows, "blackjack", "cash") == 0 and _net(full.money_rows, "craps", "cash") == 0, "Grand alias amounts are not duplicated as cash")
		var unbounded: Array = early.story_log.slice(0, 24)
		unbounded.append_array(snapshot.story_log)
		check(full.money_rows == Report.build_money_rows(unbounded), "archived + retained reconciliation equals all 264 recorded rows once")
		check(Report.build(detached) == full, "repeated report does not mutate or duplicate archived totals")
		check(full.score == report.score and full.bag_reward == report.bag_reward and full.meta_reward == report.meta_reward, "archive affects no score/bag/card reward or claim state")
		facts["recorded_prefix"] = prefix
		facts["full_rows"] = full.money_rows
	var repeated: Variant = SaveService.new().load_run("foundation_ui_autosave")
	check(repeated is RunState and Report.build(Report.snapshot_run(repeated)).money_rows == report.money_rows, "fresh service reload preserves honest legacy partial report")
	check(run.to_save_snapshot() == before, "all report projections preserve complete wallet/ledger/rewards/RNG snapshot")
	facts.merge({"legacy_rows": report.money_rows, "legacy_coverage": report.money_coverage, "wallet": {"cash": run.bankroll, "chips": run.grand_casino_chips}, "score": report.score, "bag_reward": report.bag_reward, "meta_reward": report.meta_reward, "rng": run.rng_state})

func _net(rows: Array, game_id: String, currency: String) -> int:
	for row in rows:
		if row.key == "game:" + game_id and row.currency == currency: return int(row.net)
	return 0

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

func _install_bundle() -> bool:
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	var user_dir := ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(saves)
	DirAccess.make_dir_recursive_absolute(user_dir)
	for name in ["foundation_ui_autosave.json", "foundation_ui_autosave.json.bak"]:
		if FileAccess.file_exists(bundle.path_join(name)) and not check(not FileAccess.file_exists(saves.path_join(name)) and DirAccess.copy_absolute(bundle.path_join(name), saves.path_join(name)) == OK, "install private unchanged " + name): return false
	if not check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"), user_dir.path_join(".crew_host_authority_v1")) == OK, "install copied authority key"): return false
	for pair in [["profile_inventory.json", "BTH_PROFILE_INVENTORY_PATH"], ["meta_collection.json", "BTH_META_COLLECTION_PATH"], ["settings.json", "BTH_USER_SETTINGS_PATH"]]:
		for suffix in ["", ".bak"]:
			var original := bundle.path_join(str(pair[0]) + suffix)
			if FileAccess.file_exists(original) and not check(DirAccess.copy_absolute(original, OS.get_environment(pair[1]) + suffix) == OK, "install private copied companion"): return false
	return true

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok
