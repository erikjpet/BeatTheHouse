extends SceneTree

const Journal := preload("res://scripts/ui/run_journal_view_model.gd")
const Codec := preload("res://scripts/core/run_save_codec.gd")

var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_matrix()
	await _recorded_round()
	var result := {"id": "GRAND-JOURNAL-CURRENCY-001", "checks": checks, "failures": failures, "facts": facts,
		"fidelity": "Synthetic recorded rows only; no wager, settlement, reward or existing profile is replayed. Codec reconstruction is not official SaveService or actual browser/cold UI acceptance."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("GRAND_JOURNAL_RECORDED_CURRENCY checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _matrix() -> void:
	var cases: Array = [
		[{"type": "game_action", "game_id": "blackjack", "bankroll_delta": -5, "currency": "chips", "currency_delta": -5}, ["Chips -5"]],
		[{"type": "game_action", "bankroll_delta": 0, "currency": "chips", "currency_delta": 0}, ["Chips +0"]],
		[{"type": "game_action", "bankroll_delta": 10, "currency": "cash", "currency_delta": 10}, ["Bankroll +10"]],
		[{"type": "event", "event_id": "eye", "bankroll_delta": 15}, ["Bankroll +15"]],
		[{"type": "item_purchase", "bankroll_delta": -8}, ["Bankroll -8"]],
		[{"type": "game_action", "bankroll_delta": -5, "environment_id": "grand_casino_005"}, ["Recorded change -5 (currency not recorded)"]],
		[{"type": "game_action", "bankroll_delta": -5, "environment_archetype_id": "casino"}, ["Recorded change -5 (currency not recorded)"]],
		[{"game_id": "blackjack", "bankroll_delta": -5}, ["Recorded change -5 (currency not recorded)"]],
		[{"currency": "tokens", "bankroll_delta": -5}, ["Recorded change -5 (currency not recorded)"]],
		[{"currency": "chips", "currency_delta": -5.0, "bankroll_delta": -40}, ["Chips -5"]],
		[{"currency": "chips", "currency_delta": 0, "bankroll_delta": -40}, ["Chips +0"]],
		[{"cash_delta": 15, "chips_delta": -5, "bankroll_delta": -5}, ["Bankroll +15", "Chips -5"]],
		[{"currency": "chips", "cash_delta": 15, "currency_delta": -5, "bankroll_delta": -5}, ["Bankroll +15", "Chips -5"]],
		[{"currency": "cash", "chips_delta": -5, "currency_delta": 15, "bankroll_delta": 15}, ["Chips -5", "Bankroll +15"]],
		[{"currency": "chips", "chips_delta": -5, "currency_delta": -5, "bankroll_delta": -5}, ["Chips -5"]],
		[{"cash_delta": 0, "chips_delta": 0, "bankroll_delta": -40}, ["Bankroll +0", "Chips +0"]],
		[{"currency": "chips", "currency_delta": "-5", "bankroll_delta": -5}, ["Recorded change -5 (currency not recorded)"]],
		[{"currency": "chips", "currency_delta": true, "bankroll_delta": -5}, ["Recorded change -5 (currency not recorded)"]],
		[{"currency": "chips", "currency_delta": -5.5, "bankroll_delta": -5}, ["Recorded change -5 (currency not recorded)"]],
		[{"currency": "chips", "currency_delta": INF, "bankroll_delta": -5}, ["Recorded change -5 (currency not recorded)"]],
		[{"bankroll_delta": 0}, []],
		[{}, []],
	]
	for index in range(cases.size()):
		var entry: Dictionary = cases[index][0]
		var before := var_to_bytes(entry)
		var actual: Array = Journal._recorded_money_detail_lines(entry)
		_check(actual == cases[index][1], "case %d exact recorded units/amounts: %s" % [index, actual])
		_check(var_to_bytes(entry) == before, "case %d read-only row" % index)
		_check(Journal._recorded_money_detail_lines(entry) == actual, "case %d stable repeated render" % index)
	facts["matrix_cases"] = cases.size()


func _recorded_round() -> void:
	var run := RunState.new()
	run.start_new("GRAND-JOURNAL-CURRENCY-001-SYNTHETIC")
	run.bankroll = 111
	run.grand_casino_chips = 20
	# This models an already recorded debit, zero-return settlement and a
	# separate cash event. It does not execute any of those transactions.
	run.story_log = [
		{"type": "game_action", "game_id": "blackjack", "action_id": "blackjack_place_bet", "bankroll_delta": -5, "currency": "chips", "currency_delta": -5},
		{"type": "game_action", "game_id": "blackjack", "action_id": "stand", "bankroll_delta": 0, "currency": "chips", "currency_delta": 0},
		{"type": "event", "event_id": "eye", "bankroll_delta": 15},
	]
	var before := var_to_bytes(run.to_dict())
	var callbacks := {"label_from_id": func(value): return str(value), "game_display_name": func(value): return str(value),
		"story_entry_label": func(_entry): return "Recorded outcome", "player_facing_text": func(value): return str(value)}
	var rows: Array = Journal.entry_view_list(run, callbacks)
	_check(rows.size() == 3, "three original records, no duplicated round or event")
	_check(rows[0].detail_lines == ["Chips -5", "Game: blackjack"], "recorded chip debit never says Bankroll")
	_check(rows[1].detail_lines == ["Chips +0", "Game: blackjack"], "zero settlement is not another debit")
	_check(rows[2].detail_lines == ["Bankroll +15", "Event: eye"], "separate cash Eye keeps wallet label")
	_check(Journal.entry_view_list(run, callbacks) == rows, "reopening journal creates no additional records")
	_check(var_to_bytes(run.to_dict()) == before, "full warm state/history/RNG unchanged by journal")
	var stored := Codec.pack_for_storage(Codec.encode(run.to_dict()))
	_check(bool(stored.get("ok", false)), "official storage codec packs synthetic history")
	if bool(stored.get("ok", false)):
		var cold_data := Codec.decode(Codec.unpack_from_storage(JSON.parse_string(JSON.stringify(stored.get("packed", {})))))
		var cold := RunState.new()
		cold.from_dict(cold_data)
		var cold_before := var_to_bytes(cold.to_dict())
		_check(Journal.entry_view_list(cold, callbacks) == rows, "serialized reconstruction renders the same recorded units")
		facts["cold_diagnostic"] = {"cash": cold.bankroll, "chips": cold.grand_casino_chips, "history": cold.story_log, "warm_history": run.story_log, "history_equal": cold.story_log == run.story_log}
		# The existing JSON reader restores currency_delta as float; RunState
		# normalizes bankroll_delta only. Match these two documented transport
		# types exactly, without normalizing any other row or weakening readers.
		var expected_cold_history := run.story_log.duplicate(true)
		expected_cold_history[0]["currency_delta"] = -5.0
		expected_cold_history[1]["currency_delta"] = 0.0
		_check(cold.bankroll == 111 and cold.grand_casino_chips == 20 and cold.story_log == expected_cold_history, "serialized balances/history exact apart from specified two JSON numeric types")
		facts["cold_expected_transport_changes"] = ["story_log[0].currency_delta int -5 to float -5", "story_log[1].currency_delta int 0 to float 0"]
		_check(var_to_bytes(cold.to_dict()) == cold_before, "cold reader changes no full state/history/RNG")
	for text in ["Chips -5", "Chips +0", "Bankroll +15", "Recorded change -5 (currency not recorded)"]:
		var label := Label.new()
		label.text = text
		label.size = Vector2(340, 70)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(label)
		await process_frame
		_check(label.get_line_count() <= 3 and label.get_minimum_size().y <= label.size.y, "actual Label retains full journal amount/unit: %s" % text)
		label.free()
	facts["rows"] = rows
	facts["balances"] = {"cash": run.bankroll, "chips": run.grand_casino_chips}
	facts["ui_limit"] = "Actual Label shaping only; journal popup layout, official same-profile Save/Continue and browser warm/cold remain separately required."


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
