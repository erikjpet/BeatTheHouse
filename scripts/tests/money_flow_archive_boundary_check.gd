extends SceneTree

const Archive := preload("res://scripts/core/run_money_flow_archive.gd")
const Report := preload("res://scripts/ui/run_report_view_model.gd")
const Screen := preload("res://scripts/ui/run_report_screen.gd")
const Codec := preload("res://scripts/core/run_save_codec.gd")
var checks := 0
var failures: Array[String] = []
var facts: Array = []
var rules := {"chip_game_ids": RunState.GRAND_CASINO_CHIP_GAME_IDS, "grand_archetype_ids": RunState.GRAND_CASINO_ARCHETYPE_IDS}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	_boundaries()
	_legacy_and_invalid()
	_currency_and_labels()
	await _display()
	var result := {"checks": checks, "failures": failures, "facts": facts, "fidelity": "Pure v1 eviction/retained report model; official codec storage roundtrip and actual report controls. RunState producer persistence/eviction is separately owned and requires integrated qualification. No wallet action or runtime scheduling changes."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty(): FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("MONEY_FLOW_ARCHIVE_BOUNDARY checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _boundaries() -> void:
	var history: Array = []
	for index in range(241):
		history.append({"type": "game_action", "game_id": "blackjack", "bankroll_delta": -3 if index == 0 else 1})
	var before := history.duplicate(true)
	for length in [239, 240, 241]:
		var full := history.slice(0, length)
		var evicted := full.slice(0, maxi(0, length - 240))
		var retained := full.slice(maxi(0, length - 240))
		var archive := Archive.append_evicted_rows({}, 0, evicted, rules)
		var report := Report.build_money_flow(retained, {}, archive, evicted.size())
		check(report.rows == Report.build_money_rows(full), "%d full-run totals agree with unbounded recorded history" % length)
		check(report.coverage.complete and report.coverage.known_entry_count == evicted.size(), "%d complete boundary coverage" % length)
		check(archive.archived_entry_count == maxi(0, length - 240), "%d exactly the newly evicted prefix" % length)
		check(report.rows[0].net == length - 4, "%d retained prefix is counted exactly once" % length)
		var encoded := Codec.encode({"story_money_archive": archive, "story_log_archive_count": evicted.size(), "story_log": retained})
		var stored := Codec.pack_for_storage(encoded)
		check(bool(stored.get("ok", false)), "%d official codec creates stored envelope" % length)
		var cold := Codec.decode(Codec.unpack_from_storage(JSON.parse_string(JSON.stringify(stored.get("packed", {})))))
		var cold_report := Report.build_money_flow(cold.story_log, {}, cold.story_money_archive, int(cold.story_log_archive_count))
		check(cold_report == report, "%d codec/JSON cold reconstruction keeps amounts and coverage" % length)
		check(Report.build_money_flow(retained, {}, archive, evicted.size()) == report, "%d repeated report does not re-fold archive" % length)
		facts.append({"length": length, "archive": archive, "report": report})
	check(history == before, "archive/report/codec leave caller history unchanged")
	var archive := Archive.append_evicted_rows({}, 0, history.slice(0, 1), rules)
	var frozen := archive.duplicate(true)
	var next := Archive.append_evicted_rows(archive, 1, history.slice(1, 4), rules)
	check(archive == frozen, "appending owns a copy of the prior aggregate")
	check(next.archived_entry_count == 4 and next.known_entry_count == 4, "incremental eviction counters advance only new rows")
	check(Report.build_money_rows(history.slice(4), {}, next, 4) == Report.build_money_rows(history), "multiple eviction batches reconcile without duplicated tail")
	var ignored := Archive.append_evicted_rows({}, 0, [{"type": "travel_risk_event", "bankroll_delta": 99}, {"type": "event", "bankroll_delta": 0}, {"type": "room_entry"}], rules)
	check(ignored.known_entry_count == 3 and ignored.sources.is_empty(), "K includes zero/nonmoney/ignored rows without invented money")
	var cancellation := Archive.append_evicted_rows({}, 0, [{"type": "travel", "bankroll_delta": -4}, {"type": "travel", "bankroll_delta": 4}], rules)
	check(cancellation.sources["cash|travel"].net == 0, "genuine zero-net source remains recorded")

func _legacy_and_invalid() -> void:
	var retained := [{"type": "travel", "bankroll_delta": -4}]
	var absent := Report.build_money_flow(retained, {}, {}, 24)
	check(not absent.coverage.complete and absent.coverage.unknown_entry_count == 24, "legacy missing prefix is explicitly unknown")
	check(absent.rows.size() == 1 and absent.rows[0].net == -4, "legacy totals contain only actually retained evidence")
	var continued := Archive.append_evicted_rows({}, 24, [{"type": "item_sale", "sale_price": 7}], rules)
	check(continued.archived_entry_count == 25 and continued.known_entry_count == 1, "later known eviction preserves legacy unknown prefix")
	var combined := Report.build_money_flow(retained, {}, continued, 25)
	check(combined.coverage.unknown_entry_count == 24 and combined.rows.size() == 2, "later legitimate totals do not fill legacy gaps")
	var valid := Archive.append_evicted_rows({}, 0, retained, rules)
	var invalids: Array = [null, [], {"schema": "future"}, valid.merged({"archived_entry_count": 2}, true), valid.merged({"known_entry_count": 2}, true), valid.merged({"known_entry_count": -1}, true), valid.merged({"known_entry_count": 0}, true), valid.merged({"sources": []}, true)]
	var malformed := valid.duplicate(true); malformed.sources["cash|travel"].net = 1.5; invalids.append(malformed)
	malformed = valid.duplicate(true); malformed.sources["cash|travel"].currency = "chips"; invalids.append(malformed)
	for invalid in invalids:
		var normalized := Archive.normalize_archive(invalid, 1)
		check(normalized.known_entry_count == 0 and normalized.sources.is_empty(), "malformed/mismatched aggregate fails to unknown prefix")
	check(Archive.normalize_archive(JSON.parse_string(JSON.stringify(valid)), 1).known_entry_count == 1, "JSON exact integral transport remains valid")

func _currency_and_labels() -> void:
	var entries := [
		{"type": "game_action", "game_id": "blackjack", "environment_archetype_id": "grand_casino", "bankroll_delta": -10},
		{"type": "game_action", "game_id": "blackjack", "environment_archetype_id": "bar", "bankroll_delta": 3},
		{"type": "game_action", "game_id": "blackjack", "environment_archetype_id": "grand_casino", "currency": "cash", "bankroll_delta": 2},
		{"type": "game_action", "game_id": "blackjack", "currency": "chips", "bankroll_delta": -40, "chips_delta": -10},
		{"type": "grand_casino_chip_cashout", "bankroll_delta": 8, "chips_delta": -12},
		{"type": "service_hook", "currency": "mixed", "bankroll_delta": -2, "cash_delta": -1, "chips_delta": 4},
		{"type": "item_purchase", "price": 5}, {"type": "item_sale", "sale_price": 7},
		{"type": "game_action", "game_id": "blackjack", "bankroll_delta": 1},
	]
	var before := entries.duplicate(true)
	var archive := Archive.append_evicted_rows({}, 0, entries, rules)
	check(archive.sources["chips|game:blackjack"].net == -20, "legacy proven Grand alias and explicit chip delta count once")
	check(archive.sources["cash|game:blackjack"].net == 6, "cash room, explicit cash override and room-unknown record remain cash")
	check(archive.sources["cash|grand_casino_chip_cashout"].net == 8 and archive.sources["chips|grand_casino_chip_cashout"].net == -12, "cashout records distinct observed currency legs")
	check(archive.sources["cash|services"].net == -1 and archive.sources["chips|services"].net == 4, "explicit cash delta takes precedence in mixed entry")
	check(archive.sources["cash|items_bought"].net == -5 and archive.sources["cash|items_sold"].net == 7, "existing item fallbacks preserved")
	check(entries == before, "currency classification is read-only")
	check(Archive.money_legs({"type": "game_action", "game_id": "blackjack", "environment_id": "grand_casino_005", "bankroll_delta": -10}, rules) == {"chips": -10}, "early recorded generated Grand room ID identifies chip wager alias")
	for room_id in ["grand_casino_impostor_005", "grand_casino_bad", "bar_005", ""]:
		check(Archive.money_legs({"type": "game_action", "game_id": "blackjack", "environment_id": room_id, "bankroll_delta": -10}, rules) == {"cash": -10}, "unrecognized recorded room does not infer chip currency")
	check(Archive.money_legs({"type": "game_action", "game_id": "blackjack", "environment_id": "grand_casino_005", "environment_archetype_id": "bar", "bankroll_delta": -10}, rules) == {"cash": -10}, "explicit recorded archetype takes precedence over generated ID fallback")
	var first := [{"type": "lender_hook", "id": "note", "label": "Old note", "bankroll_delta": 5}]
	var tail := [{"type": "lender_hook", "id": "note", "label": "Latest note", "bankroll_delta": -2}, {"type": "lender_hook", "id": "note", "label": "Zero label", "bankroll_delta": 0}]
	var labels := Report.build_money_rows(tail, {}, Archive.append_evicted_rows({}, 0, first, rules), 1)
	check(labels[0].label == "Latest note" and labels[0].net == 3, "latest nonzero source label preserved across archive boundary")
	var catalog := {"games": {"blackjack": {"display_name": "June's Blackjack"}}}
	check(Report.build_money_rows([], catalog, archive, entries.size()).filter(func(row): return row.key == "game:blackjack").all(func(row): return row.label == "June's Blackjack"), "archived game sources retain catalog names")
	facts.append({"mixed_currency_archive": archive})

func _display() -> void:
	var screen := Screen.new()
	screen.size = Vector2(1280, 720)
	root.add_child(screen)
	for small in [false, true]:
		screen.size = Vector2(840, 680) if small else Vector2(1280, 720)
		screen.set_small_screen_mode(small)
		for unknown in [0, 24]:
			var rows := [{"key": "game:blackjack", "label": "Blackjack", "currency": "cash", "net": 20}, {"key": "game:blackjack", "label": "Blackjack", "currency": "chips", "net": -10}]
			screen.call("_render_story", rows, {"unknown_entry_count": unknown})
			await process_frame
			await process_frame
			var labels := _labels(screen.story_rows)
			check(labels.has("+$20") and labels.has("-10 chips"), "actual report controls identify each currency")
			check(labels.has("Partial: 24 older entries unknown.") == (unknown > 0), "actual report controls disclose only unknown prefixes")
			for node in screen.story_rows.get_children():
				if node is Label and node.text.begins_with("Partial:"):
					check(node.get_theme_font("font").get_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, node.get_theme_font_size("font_size")).x <= node.size.x, "partial notice fits allocated report width")
				for child in node.get_children():
					if child is Label and (child.text.contains("chips") or child.text.contains("$")):
						check(child.get_theme_font("font").get_string_size(child.text, HORIZONTAL_ALIGNMENT_LEFT, -1, child.get_theme_font_size("font_size")).x <= child.size.x, "amount and currency both fit actual report column")
			var bars: Array = []
			for line in screen.story_rows.get_children():
				for child in line.get_children():
					if child is ProgressBar: bars.append({"value": child.value, "max": child.max_value})
			check(bars.size() == 2 and bars[0].max == 20 and bars[1].max == 10, "bar scales never compare cash against chips")
			facts.append({"small": small, "unknown": unknown, "labels": labels, "bars": bars})
		screen.call("_render_story", [], {"unknown_entry_count": 24})
		check(_labels(screen.story_rows).has("No recorded money moved.") and not _labels(screen.story_rows).has("No money moved."), "unknown prefix cannot claim no money moved in the full run")
	screen.free()

func _labels(node: Node) -> Array:
	var result: Array = []
	if node is Label: result.append(node.text)
	for child in node.get_children(): result.append_array(_labels(child))
	return result

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
