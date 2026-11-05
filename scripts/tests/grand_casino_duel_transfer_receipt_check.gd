extends SceneTree

const Model := preload("res://scripts/core/grand_casino_duel_model.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _run() -> void:
	for row in [
		{"player": 14, "house": 169, "requested": -20, "penalty": 0, "actual": -14},
		{"player": 169, "house": 14, "requested": 20, "penalty": 0, "actual": 14},
		{"player": 14, "house": 169, "requested": -20, "penalty": 18, "actual": -14},
		{"player": 100, "house": 100, "requested": -20, "penalty": 18, "actual": -38},
		{"player": 100, "house": 100, "requested": 20, "penalty": 18, "actual": 2},
		{"player": 100, "house": 100, "requested": 0, "penalty": 0, "actual": 0},
	]:
		var state := {"status": "active", "player_stack": row.player, "rourke_stack": row.house, "hands": [], "hand_index": 0, "hand_limit": 5}
		var before := JSON.stringify(state)
		var result := Model.apply_hand(state, {"transfer": row.requested, "caught_penalty": row.penalty}, {})
		var next: Dictionary = result.get("state", {})
		var hands: Array = next.get("hands", [])
		_expect(bool(result.get("ok", false)), "valid hand is accepted")
		_expect(int(next.get("player_stack", -1)) == row.player + row.actual and int(next.get("rourke_stack", -1)) == row.house - row.actual, "actual settlement stays unchanged")
		_expect(int(next.get("player_stack", -1)) + int(next.get("rourke_stack", -1)) == row.player + row.house, "chips remain conserved")
		_expect(int(result.get("transfer", -999)) == row.actual and hands.size() == 1 and int(hands[0].get("transfer", -999)) == row.actual, "receipt and return match actual movement")
		_expect(int(hands[0].get("caught_penalty", -1)) == row.penalty, "configured caught penalty evidence stays unchanged")
		_expect(JSON.stringify(state) == before, "prior state snapshot is not modified")
		if str(next.get("status", "")) == "complete":
			var repeat := Model.apply_hand(next, {"transfer": row.requested}, {})
			_expect(not bool(repeat.get("ok", true)) and repeat.get("state") == next, "completed hand cannot transfer again")
	_check_callout_receipts()
	var report := {"checks": checks, "failures": failures, "fidelity": "Synthetic native model comparisons of requested/actual transfers with unchanged settlement, conservation, penalty evidence and completed-repeat rejection. Actual saved H2 UI separately qualified."}
	var f := FileAccess.open(OS.get_environment("BTH_TARGET_OUTPUT"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("DUEL_TRANSFER_RECEIPT checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
func _authored_callout_terms() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/events/events.json"))
	_expect(typeof(parsed) == TYPE_ARRAY, "callout terms: authored event array loads")
	if typeof(parsed) != TYPE_ARRAY:
		return {}
	for event_value in parsed as Array:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		if str(event.get("id", "")) != "the_house_calls":
			continue
		var payload: Variant = event.get("payload", {})
		if typeof(payload) != TYPE_DICTIONARY:
			_expect(false, "callout terms: showdown payload is a dictionary")
			return {}
		var authored: Variant = (payload as Dictionary).get("duel_terms", {})
		if typeof(authored) != TYPE_DICTIONARY:
			_expect(false, "callout terms: authored duel terms are a dictionary")
			return {}
		var terms: Dictionary = (authored as Dictionary).duplicate(true)
		var rules: Variant = terms.get("rules", {})
		if typeof(rules) != TYPE_DICTIONARY:
			_expect(false, "callout terms: authored rules are a dictionary")
			return {}
		var actual_rules: Dictionary = rules
		var current_rules := int(actual_rules.get("correct_call_swing", -1)) == 18 and int(actual_rules.get("false_call_cost", -1)) == 6 and int(actual_rules.get("hand_limit", -1)) == 5 and int(actual_rules.get("base_ante", -1)) == 20 and int(terms.get("base_stack", -1)) == 100
		_expect(current_rules, "callout terms: current authored 18/6 swing, five hands, ante20 and neutral stack100")
		if not current_rules:
			return {}
		# Neutral normalized terms; no player-history modifiers or UI seed claim.
		terms["starting_stacks"] = {"player": 100, "rourke": 100}
		return terms
	_expect(false, "callout terms: the_house_calls event exists")
	return {}


func _check_callout_receipts() -> void:
	print("DUEL_CALLOUT_SCOPE existing hand cases retained; added synthetic model and public RunState/facade boundaries, not a seeded UI playthrough")
	var terms := _authored_callout_terms()
	if terms.is_empty():
		return
	for row in [
		{"label": "normal correct", "player": 100, "house": 100, "correct": true, "actual": 18, "complete": false},
		{"label": "normal false", "player": 100, "house": 100, "correct": false, "actual": -6, "complete": false},
		{"label": "exact correct", "player": 100, "house": 18, "correct": true, "actual": 18, "complete": true},
		{"label": "exact false", "player": 6, "house": 100, "correct": false, "actual": -6, "complete": true},
		{"label": "clipped correct", "player": 100, "house": 2, "correct": true, "actual": 2, "complete": true},
		{"label": "clipped false", "player": 2, "house": 100, "correct": false, "actual": -2, "complete": true},
	]:
		var label := str(row.label)
		var state := Model.initialize(terms, null)
		state["player_stack"] = row.player
		state["rourke_stack"] = row.house
		state["margin"] = int(row.player) - int(row.house)
		var schedule: Array = state.get("edge_schedule", [])
		var edge: Dictionary = schedule[0]
		edge["id"] = "deck_stack"
		edge["active"] = row.correct
		var before := JSON.stringify(state)
		var terms_before := JSON.stringify(terms)
		var result := Model.call_out(state, "deck_stack", terms)
		var next: Dictionary = result.get("state", {})
		var actual := int(next.get("player_stack", -999)) - int(row.player)
		_expect(bool(result.get("ok", false)) and bool(result.get("correct", false)) == bool(row.correct), label + ": accepted call preserves correct/false classification")
		_expect(actual == int(row.actual) and int(next.get("rourke_stack", -999)) == int(row.house) - int(row.actual), label + ": settlement applies available-stack cap")
		_expect(int(next.get("player_stack", -1)) + int(next.get("rourke_stack", -1)) == int(row.player) + int(row.house), label + ": call conserves duel chips")
		_expect(int(result.get("swing", -999)) == actual, label + ": returned swing equals actual player-stack movement")
		var result_edge: Dictionary = result.get("edge", {})
		_expect(bool(result_edge.get("called", false)) and bool(result_edge.get("stripped", false)) == bool(row.correct), label + ": called/stripped evidence preserved")
		_expect((str(next.get("status", "")) == "complete") == bool(row.complete), label + ": terminal policy unchanged")
		_expect(int(next.get("hand_index", -1)) == 0 and (next.get("hands", []) as Array).is_empty(), label + ": call does not record or advance a hand")
		_expect(JSON.stringify(state) == before and JSON.stringify(terms) == terms_before, label + ": original state and terms remain unchanged")
		var next_before := JSON.stringify(next)
		var repeat := Model.call_out(next, "deck_stack", terms)
		_expect(not bool(repeat.get("ok", true)) and repeat.get("state") == next and JSON.stringify(next) == next_before, label + ": repeated call cannot move chips or mutate prior result")
	_check_public_short_stack_callout(terms)


func _check_public_short_stack_callout(terms: Dictionary) -> void:
	var run: RunState = RunStateScript.new()
	run.start_new("DUEL-CALLOUT-RECEIPT-022")
	run.narrative_flags["grand_casino_duel_terms"] = terms.duplicate(true)
	# Null RNG gives inactive edges: valid false calls without inventing an
	# authored seed or bypassing the production call-out/settlement methods.
	run.narrative_flags["grand_casino_duel_state"] = Model.initialize(terms, null)
	run.narrative_flags["grand_casino_showdown_active"] = true
	run.narrative_flags["grand_casino_showdown_step"] = RunStateScript.GRAND_CASINO_SHOWDOWN_STEP_DUEL
	var wallet_before := [run.bankroll, run.grand_casino_chips]
	var rng_before := [run.rng_seed, run.rng_state]
	var terms_before := JSON.stringify(run.narrative_flags["grand_casino_duel_terms"])
	for hand_index in range(4):
		if hand_index < 3:
			var prior_call_state: Dictionary = run.narrative_flags["grand_casino_duel_state"]
			var prior_call_json := JSON.stringify(prior_call_state)
			var call := run.grand_casino_duel_call_out("deck_stack")
			_expect(bool(call.get("ok", false)) and not bool(call.get("correct", true)) and int(call.get("swing", 0)) == -6, "public path: nonclipped false call retains authored cost6")
			_expect(JSON.stringify(prior_call_state) == prior_call_json, "public path: committed call preserves retained previous state")
		var prior_hand_state: Dictionary = run.narrative_flags["grand_casino_duel_state"]
		var prior_hand_json := JSON.stringify(prior_hand_state)
		var hand := run.apply_grand_casino_duel_hand({"transfer": -20, "caught_penalty": 0})
		_expect(bool(hand.get("ok", false)) and int(hand.get("transfer", 0)) == -20, "public path: each of four losses retains actual20 hand receipt")
		_expect(JSON.stringify(prior_hand_state) == prior_hand_json, "public path: hand commit preserves retained previous state")
	var before: Dictionary = run.narrative_flags["grand_casino_duel_state"]
	_expect(str(before.get("status", "")) == "active" and int(before.get("hand_index", -1)) == 4 and int(before.get("player_stack", -1)) == 2 and int(before.get("rourke_stack", -1)) == 198, "public path: three false calls and four losses reach active fifth hand with2/198")
	var before_json := JSON.stringify(before)
	var called := run.grand_casino_duel_call_out("deck_stack")
	var after := run.grand_casino_duel_status()
	var actual := int(after.get("player_stack", -999)) - int(before.get("player_stack", 0))
	_expect(bool(called.get("ok", false)) and not bool(called.get("correct", true)) and actual == -2, "public path: fifth false call caps actual movement at remaining2")
	_expect(int(called.get("swing", -999)) == actual, "public path: clipped returned swing equals actual movement")
	_expect(int(after.get("player_stack", -1)) == 0 and int(after.get("rourke_stack", -1)) == 200, "public path: final call conserves the original200 duel chips")
	_expect(str(after.get("status", "")) == "complete" and str(after.get("outcome", "")) == Model.OUTCOME_TAKEN_OUT_BACK and run.is_terminal(), "public path: depleted-stack terminal outcome still finalizes")
	_expect(JSON.stringify(before) == before_json and JSON.stringify(run.narrative_flags["grand_casino_duel_terms"]) == terms_before, "public path: previous state and terms remain unchanged")
	_expect([run.bankroll, run.grand_casino_chips] == wallet_before and [run.rng_seed, run.rng_state] == rng_before, "public path: duel call/settlement do not change external wallet or run RNG")
	var call_rows: Array = []
	for story_value in run.story_log:
		if typeof(story_value) == TYPE_DICTIONARY and str((story_value as Dictionary).get("type", "")) == "grand_casino_duel_callout":
			call_rows.append(story_value)
	_expect(call_rows.size() == 4, "public path: four accepted calls produce four original story receipts")
	if call_rows.size() == 4:
		var last: Dictionary = call_rows.back()
		_expect(int(last.get("stack_swing", -999)) == actual and int(last.get("hand", -1)) == 5 and not bool(last.get("correct", true)), "public path: fifth-hand story stack_swing equals actual movement")
	var story_before_repeat := JSON.stringify(run.story_log)
	var after_before_repeat := JSON.stringify(after)
	var repeated := run.grand_casino_duel_call_out("deck_stack")
	_expect(not bool(repeated.get("ok", true)) and JSON.stringify(run.grand_casino_duel_status()) == after_before_repeat and JSON.stringify(run.story_log) == story_before_repeat, "public path: completed repeated call adds no chips or story receipt")
