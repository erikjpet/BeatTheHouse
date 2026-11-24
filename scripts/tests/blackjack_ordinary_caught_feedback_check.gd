extends SceneTree

# Synthetic source-level check for ordinary Grand caught feedback.
# Compile the production formatter, its pure helpers and payout label as-is.
# This never instantiates BlackjackGame, MainScene, a run, or save services.
var checks := 0
var failures: Array = []
var cases: Array = []
var production_source_sha256 := ""
var extracted_source_sha256 := ""
var evidence_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _function_source(source: String, function_name: String) -> String:
	var marker := "\nfunc %s(" % function_name
	if source.count(marker) != 1:
		return ""
	var start := source.find(marker) + 1
	var end := source.find("\nfunc ", start + 1)
	if end < 0:
		end = source.length()
	return source.substr(start, end - start).strip_edges()


func _constant_source(source: String, constant_name: String) -> String:
	var found: Array = []
	for line in source.split("\n"):
		if line.begins_with("const %s " % constant_name):
			found.append(line)
	return str(found[0]) if found.size() == 1 else ""


func _check(formatter: RefCounted, id: String, hands: Array, sides: Array, main_delta: int, side_delta: int, cheat: Dictionary, item: Dictionary, security: String, expected: String) -> void:
	var before := {
		"hand_results": hands.duplicate(true),
		"side_results": sides.duplicate(true),
		"cheat": cheat.duplicate(true),
		"item_adjustment": item.duplicate(true),
		"main_delta": main_delta,
		"side_delta": side_delta,
		"security_message": security,
	}
	var actual := str(formatter.call("_blackjack_result_message", hands, sides, main_delta, side_delta, cheat, item, security))
	checks += 1
	if actual != expected:
		failures.append(id + ".message")
	var unchanged: bool = hands == before["hand_results"] and sides == before["side_results"] and cheat == before["cheat"] and item == before["item_adjustment"]
	checks += 1
	if not unchanged:
		failures.append(id + ".input_mutation")
	cases.append({"id": id, "inputs": before, "expected": expected, "actual": actual, "message_matched": actual == expected, "inputs_unchanged": unchanged})


func _finish(setup_ok: bool, setup_error: String = "") -> void:
	var record := {
		"bug_id": "BTH-QA-GRAND-LEGAL-CAUGHT-FEEDBACK-001",
		"setup_ok": setup_ok,
		"setup_error": setup_error,
		"ok": setup_ok and failures.is_empty(),
		"checks": checks,
		"failures": failures,
		"cases": cases,
		"production_source_sha256": production_source_sha256,
		"extracted_source_sha256": extracted_source_sha256,
		"fidelity": "Synthetic production formatter/helper source execution in a minimal headless host; no live Game, RNG, economy, save or deployed-build claim.",
	}
	if evidence_dir.is_empty():
		push_error("An admitted E: QA evidence directory is required.")
		quit(2)
		return
	var output := FileAccess.open(evidence_dir.path_join("formatter-check-result.json"), FileAccess.WRITE)
	if output == null:
		push_error("Could not create the declared QA result.")
		quit(2)
		return
	output.store_string(JSON.stringify(record, "\t") + "\n")
	output.close()
	print(JSON.stringify({"setup_ok": setup_ok, "ok": record["ok"], "checks": checks, "failures": failures, "setup_error": setup_error}))
	quit(0 if bool(record["ok"]) else (1 if setup_ok else 2))


func _run() -> void:
	evidence_dir = OS.get_environment("BTH_QA_EVIDENCE_DIR")
	if not evidence_dir.replace("\\", "/").begins_with("E:/CodexQA/BTH/runs/"):
		evidence_dir = ""
		_finish(false, "Official guarded E: evidence is required.")
		return
	var source_path := OS.get_environment("BTH_BLACKJACK_FORMATTER_SOURCE")
	if source_path.is_empty() or not FileAccess.file_exists(source_path):
		_finish(false, "An explicit existing production blackjack source file is required.")
		return
	var source := FileAccess.get_file_as_string(source_path)
	production_source_sha256 = FileAccess.get_sha256(source_path)
	var constant := _constant_source(source, "BLACKJACK_PAYOUT_LABEL")
	var functions: Array = []
	for name in ["_blackjack_result_message", "_blackjack_hand_result_detail", "_blackjack_side_result_detail"]:
		var function := _function_source(source, name)
		if function.is_empty():
			_finish(false, "Could not extract exactly one production function: " + name)
			return
		functions.append(function)
	if constant.is_empty():
		_finish(false, "Could not extract the production payout label.")
		return
	var extracted := "extends RefCounted\n\n" + constant + "\n\n" + "\n\n".join(functions) + "\n"
	extracted_source_sha256 = extracted.sha256_text()
	var script := GDScript.new()
	script.source_code = extracted
	if script.reload() != OK:
		_finish(false, "Extracted production formatter did not parse.")
		return
	var formatter: RefCounted = script.new()
	var hands: Array = [{"outcome": "win", "player_total": 21, "dealer_total": 17, "wager": 5, "bankroll_delta": 5}]
	var sides: Array = [{"label": "Test side", "detail": "wins", "bankroll_delta": 4}]
	var prefix := "Dealer 17. H1 21 beats 17 (+5). Main +5. Side +4 (Test side wins +4)"
	var suffix := " Gear bonus +2. Security watches."
	var matrix: Array = [
		{"id": "ordinary_caught", "cheat": {"caught": true, "ordinary_strategy_count": 1, "used_peek": false, "used_count": false, "advantage_play": false, "suspicion_delta": 1}, "risk": ". Your play draws scrutiny; heat rises."},
		{"id": "legacy_caught_unknown", "cheat": {"caught": true}, "risk": ". Caught cheating; heat spikes."},
		{"id": "ordinary_count_zero_caught", "cheat": {"caught": true, "ordinary_strategy_count": 0}, "risk": ". Caught cheating; heat spikes."},
		{"id": "ordinary_count_negative_caught", "cheat": {"caught": true, "ordinary_strategy_count": -1}, "risk": ". Caught cheating; heat spikes."},
		{"id": "peek_caught", "cheat": {"caught": true, "ordinary_strategy_count": 1, "used_peek": true}, "risk": ". Caught cheating; heat spikes."},
		{"id": "count_caught", "cheat": {"caught": true, "ordinary_strategy_count": 1, "used_count": true}, "risk": ". Caught cheating; heat spikes."},
		{"id": "advantage_caught", "cheat": {"caught": true, "ordinary_strategy_count": 1, "advantage_play": true}, "risk": ". Caught cheating; heat spikes."},
		{"id": "mixed_cheats_caught", "cheat": {"caught": true, "ordinary_strategy_count": 1, "used_peek": true, "used_count": true, "advantage_play": true}, "risk": ". Caught cheating; heat spikes."},
		{"id": "confronted_over_ordinary", "cheat": {"strategy_confronted": true, "caught": true, "ordinary_strategy_count": 1}, "risk": ". Dealer challenges the off-book line."},
		{"id": "confronted_over_cheats", "cheat": {"strategy_confronted": true, "caught": true, "ordinary_strategy_count": 1, "used_peek": true, "used_count": true, "advantage_play": true}, "risk": ". Dealer challenges the off-book line."},
		{"id": "confronted_without_caught", "cheat": {"strategy_confronted": true, "caught": false}, "risk": ". Dealer challenges the off-book line."},
		{"id": "ordinary_uncaught_risk", "cheat": {"caught": false, "ordinary_strategy_count": 1, "suspicion_delta": 1}, "risk": ". Risky play adds heat."},
		{"id": "peek_uncaught_risk", "cheat": {"caught": false, "used_peek": true, "suspicion_delta": 2}, "risk": ". Risky play adds heat."},
		{"id": "count_uncaught_risk", "cheat": {"caught": false, "used_count": true, "suspicion_delta": 3}, "risk": ". Risky play adds heat."},
		{"id": "unknown_uncaught_risk", "cheat": {"suspicion_delta": 1}, "risk": ". Risky play adds heat."},
		{"id": "quiet_ordinary", "cheat": {"caught": false, "ordinary_strategy_count": 1, "suspicion_delta": 0}, "risk": ""},
		{"id": "empty_cheat", "cheat": {}, "risk": ""},
	]
	for value in matrix:
		_check(formatter, str(value["id"]), hands, sides, 5, 4, value["cheat"], {"summary": "Gear bonus +2."}, "Security watches.", prefix + str(value["risk"]) + suffix)
	var payouts: Array = [
		{"id": "payout_blackjack", "hand": {"outcome": "blackjack", "player_total": 21, "dealer_total": 20, "wager": 10, "bankroll_delta": 15}, "delta": 15, "expected": "Dealer 20. H1 blackjack pays 3:2 on $10 (+15). Main +15"},
		{"id": "payout_push", "hand": {"outcome": "push", "player_total": 17, "dealer_total": 17, "wager": 5, "bankroll_delta": 0}, "delta": 0, "expected": "Dealer 17. H1 push 17-17 (+0). Main +0"},
		{"id": "payout_lose", "hand": {"outcome": "lose", "player_total": 17, "dealer_total": 20, "wager": 5, "bankroll_delta": -5}, "delta": -5, "expected": "Dealer 20. H1 17 loses to 20 (-5). Main -5"},
		{"id": "payout_bust", "hand": {"outcome": "bust", "player_total": 22, "dealer_total": 20, "wager": 5, "bankroll_delta": -5}, "delta": -5, "expected": "Dealer 20. H1 busts at 22 (-5). Main -5"},
		{"id": "payout_surrender", "hand": {"outcome": "surrender", "player_total": 16, "dealer_total": 20, "wager": 5, "bankroll_delta": -3}, "delta": -3, "expected": "Dealer 20. H1 late surrender returns half of $5 (-3). Main -3"},
	]
	for value in payouts:
		_check(formatter, str(value["id"]), [value["hand"]], [], int(value["delta"]), 0, {}, {}, "", str(value["expected"]))
	_check(formatter, "no_player_wager", [], [], 0, 0, {}, {}, "", "No player wager. Main +0")
	_finish(true)
