extends SceneTree

const Baccarat := preload("res://scripts/games/baccarat.gd")
const Host := preload("res://scripts/ui/foundation_main.gd")
const Canvas := preload("res://scripts/ui/game_surface_canvas.gd")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
var checks := 0
var failures: Array[String] = []
var facts: Array = []
var library: ContentLibrary

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if not check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_absolute_path(), "explicit private persistence root required"):
		_finish()
		return
	library = ContentLibrary.new(); library.load(false)
	var selected := OS.get_environment("BTH_BACCARAT_CASE")
	for currency in ["chips", "cash"]:
		if not selected.is_empty() and selected != currency: continue
		_readiness(currency)
		_staged_commands(currency)
		_skill_story_metadata(currency)
		for outcome in ["win", "loss", "push"]: _settlement(currency, outcome)
	_finish()

func _fixture(currency: String) -> Dictionary:
	var game := Baccarat.new(); game.setup(library.game("baccarat"), library)
	var run := RunState.new(); run.start_new("BACCARAT-DISPLAY-" + currency)
	run.crew_change_reputation(0)
	run.bankroll = 71 if currency == "chips" else 1000
	run.grand_casino_chips = 155 if currency == "chips" else 0
	run.simulation_msec = 1000000
	var environment := {"id": "baccarat_display_synthetic", "archetype_id": "grand_casino_high_limit" if currency == "chips" else "small_underground_casino", "kind": "boss" if currency == "chips" else "casino", "game_ids": ["baccarat"], "economic_profile": {"stake_floor": 90, "stake_ceiling": 500}, "security_profile": {"strictness": "high"}}
	var table: Dictionary = game.generate_environment_state(run, environment, run.create_rng("table"))
	# Explicit synthetic minimum; no QA profile, physical rule or wager is edited.
	table["table_minimum"] = 90
	environment["game_states"] = {"baccarat": table}
	run.current_environment = environment
	return {"game": game, "run": run, "table": table}

func _readiness(currency: String) -> void:
	var fixture := _fixture(currency)
	var game: GameModule = fixture.game
	var run: RunState = fixture.run
	for amount in [0, 5, 85, 89, 90, 95]:
		var ui := {"baccarat_bets": {} if amount == 0 else {"banker": amount}, "surface_time_msec": run.simulation_msec}
		var before := run.to_save_snapshot()
		var state: Dictionary = game.surface_state(run, run.current_environment, ui)
		var patch: Dictionary = game.surface_realtime_state_patch(run, run.current_environment, ui, state)
		var ready: bool = amount == 0 or amount >= 90
		check(bool(state.can_deal) == ready and bool(patch.can_deal) == ready, currency + " existing full/realtime Deal eligibility preserved at " + str(amount))
		check(state.baccarat_explainer == patch.baccarat_explainer, currency + " full/realtime explainer agrees")
		if amount == 0:
			check(str(state.baccarat_explainer.title) == "HOW BACCARAT WORKS", currency + " zero stake remains guide/sit-out state")
		elif amount < 90:
			check(str(state.baccarat_explainer.title) == "MINIMUM NOT MET", currency + " below-minimum stake cannot claim READY")
			check(str(state.baccarat_explainer.secondary).contains("90 chips" if currency == "chips" else "$90"), currency + " actual minimum and units shown")
			_explainer_label_fit(state.baccarat_explainer, currency)
		else:
			check(str(state.baccarat_explainer.title) == "READY TO DEAL", currency + " exact/above minimum is ready")
		check(run.to_save_snapshot() == before, currency + " read-only readiness preserves complete state/RNG")
		facts.append({"kind": "readiness", "currency": currency, "staged": amount, "can_deal": state.can_deal, "explainer": state.baccarat_explainer})

func _explainer_label_fit(explainer: Dictionary, currency: String) -> void:
	var canvas := Canvas.new()
	var font := canvas.get_theme_default_font()
	# Actual renderer uses 176px-wide centered title and secondary rows.
	for row in [{"text": explainer.title, "size": 11, "height": 13, "cap": 24}, {"text": explainer.secondary, "size": 7, "height": 10, "cap": 44}]:
		var text_value := str(row.text)
		var rect := Rect2(0, 0, 176, row.height)
		var fitted: int = canvas._centered_label_fit_size(font, text_value, rect, row.size)
		check(text_value.length() <= int(row.cap) and font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x <= rect.size.x, currency + " readiness and actual minimum fit existing drawn label width/cap")
	canvas.free()

func _staged_commands(currency: String) -> void:
	var fixture := _fixture(currency)
	var game: GameModule = fixture.game
	var run: RunState = fixture.run
	var before := _protected(run)
	var entered: Dictionary = game.enter(run, run.current_environment)
	check(str(entered.message).contains("90 chips" if currency == "chips" else "$90"), currency + " entry minimum has correct denomination")
	var selected: Dictionary = game.surface_action_command("baccarat_chip", 0, false, {}, run, run.current_environment)
	var ui: Dictionary = selected.get("ui_state", {})
	check(str(ui.get("table_notice", "")).contains("5 chips" if currency == "chips" else "$5"), currency + " selected denomination labelled correctly")
	var placed: Dictionary = game.surface_action_command("baccarat_bet", 4, false, ui, run, run.current_environment)
	ui = placed.get("ui_state", {})
	check(int(ui.get("baccarat_bets", {}).get("banker", 0)) == 5, currency + " ordinary felt command stages five")
	check(str(ui.get("table_notice", "")).contains("5 chips" if currency == "chips" else "$5"), currency + " staged amount labelled correctly")
	var rejected: Dictionary = game.surface_action_command("baccarat_deal", 0, true, ui, run, run.current_environment)
	check(str(rejected.get("message", "")).contains("90 chips" if currency == "chips" else "$90"), currency + " actual rejected Deal explains minimum with correct units")
	check(str(rejected.get("action_id", "")).is_empty() and not bool(rejected.get("resolve", false)) and _equal(_protected(run), before), currency + " staging and rejected Deal charge/draw nothing")
	var cleared: Dictionary = game.surface_action_command("baccarat_clear", 0, false, ui, run, run.current_environment)
	ui = cleared.get("ui_state", {})
	check(ui.get("baccarat_bets", {}).is_empty() and _equal(_protected(run), before), currency + " normal Clear preserves financial/RNG state")
	var maximum: Dictionary = game.surface_action_command("baccarat_max_bet", 0, false, ui, run, run.current_environment)
	check(str(maximum.get("message", "")).contains("chips" if currency == "chips" else "$"), currency + " MAX denomination labelled correctly")
	var followed: Dictionary = game.surface_action_command("baccarat_patron_bet", 0, false, ui, run, run.current_environment)
	var follow_notice := str(followed.get("ui_state", {}).get("table_notice", ""))
	check(follow_notice.contains("chips" if currency == "chips" else "$"), currency + " patron staging notice has correct denomination")
	check(_equal(_protected(run), before), currency + " all staging controls preserve wallets/debt/history/RNG")
	if currency == "chips":
		for message in [str(entered.message), str(placed.get("ui_state", {}).get("table_notice", "")), str(maximum.get("message", "")), follow_notice]: check(not message.contains("$"), "chip staging never labels its amounts as cash")

func _skill_story_metadata(currency: String) -> void:
	for action in ["read_baccarat_shoe", "edge_sort"]:
		var fixture := _fixture(currency)
		var game = fixture.game
		var run: RunState = fixture.run
		var table: Dictionary = fixture.table
		# Explicit synthetic challenge inputs exercise the other two story owners.
		var ui := {"shoe_read_challenge": {"challenge_id": "synthetic_read", "shoe_id": table.shoe_id, "cue_sequence": ["neutral"], "hidden_answer": "neutral", "answer": "neutral", "input_msec": 2000, "started_msec": 0}}
		if action == "edge_sort":
			ui = {"edge_sort_challenge": {"challenge_id": "synthetic_edge", "shoe_id": table.shoe_id, "hidden_answer": ["high", "low", "neutral"], "observed_hand_indexes": [0, 1, 2], "min_hands": 1, "required_cue_count": 3}, "edge_sort_answers": ["high", "low", "neutral"]}
		var before := _protected(run)
		var result: Dictionary = game._resolve_baccarat_proposal_core(action, 90, run, run.current_environment, run.create_rng("proposal"), ui)
		var rows: Array = result.get("deltas", {}).get("story_log", [])
		check(rows.size() == 1, currency + "/" + action + " existing story producer returns one row")
		if rows.size() == 1:
			var row: Dictionary = rows[0]
			check(str(row.get("currency", "")) == currency and int(row.get("currency_delta", 999)) == int(result.get("bankroll_delta", 998)), currency + "/" + action + " story preserves original nominal net and routed denomination")
		check(not result.has("currency") and not result.has("currency_delta") and not result.has("applied_currency_settlement"), currency + "/" + action + " metadata does not pre-stamp routing or fabricate applied witness")
		check(_equal(_protected(run), before), currency + "/" + action + " proposal story annotation does not debit or advance root RNG")

func _settlement(currency: String, outcome: String) -> void:
	var fixture := _fixture(currency)
	var game = fixture.game
	var run: RunState = fixture.run
	var table: Dictionary = fixture.table
	# Controlled NEW synthetic shoes cover result display boundaries, following
	# the existing Baccarat presentation test. Never mutate a campaign shoe.
	var ranks: Array = {"win": [4, 4, 4, 5], "loss": [4, 1, 4, 2], "push": [3, 2, 3, 4]}[outcome]
	var shoe: Array = []
	for rank in ranks: shoe.append({"rank": rank, "suit": shoe.size() % 4, "deck": shoe.size()})
	while shoe.size() < 80: shoe.append({"rank": 2, "suit": shoe.size() % 4, "deck": shoe.size()})
	table["shoe"] = shoe; table["shoe_remaining"] = shoe.size(); table["cut_card_remaining"] = 4; table["reshuffle_pending"] = false
	var binding := "baccarat:%s:%s" % [run.current_environment.id, run.current_environment.archetype_id]
	table[Authority.LEDGER_KEY] = Authority.stage_session(Authority.default_ledger(binding, run.action_authority_checkpoint_fingerprint()), {"selected_chip": 5, "baccarat_bets": {"banker": 90}})
	game._update_environment_table(run.current_environment, table)
	game.enter(run, run.current_environment)
	var host := Host.new()
	host.current_game = game; host.game_module_cache = {"baccarat": game}; host.run_state = run; host.selected_stake = 90
	var canvas := Canvas.new(); host.game_surface_canvas = canvas
	var before := _protected(run)
	var result: Dictionary = host._sealed_action_host_resolve_intent("deal_baccarat", 90, {})
	if not check(bool(result.get("blackjack_host_committed", false)), currency + "/" + outcome + " normal sealed Deal commits once"):
		host.free(); canvas.free(); return
	var expected := int({"win": 85, "loss": -90, "push": 0}[outcome])
	check(int(result.get("currency_delta", 999)) == expected and str(result.get("currency", "")) == currency, currency + "/" + outcome + " routed monetary result unchanged")
	check(run.bankroll == int(before.cash) + (expected if currency == "cash" else 0) and run.grand_casino_chips == int(before.chips) + (expected if currency == "chips" else 0), currency + "/" + outcome + " exact wallet transfer unchanged")
	table = game._table_state_preview(run, run.current_environment)
	check(int(table.get("last_result", {}).get("commission", 0)) == (5 if outcome == "win" else 0), currency + "/" + outcome + " existing Banker commission unchanged")
	var entry := _latest_baccarat_story(run)
	check(str(entry.get("game_id", "")) == "baccarat" and str(entry.get("currency", "")) == currency and int(entry.get("currency_delta", 999)) == expected and int(entry.get("bankroll_delta", 999)) == expected, currency + "/" + outcome + " durable row carries denomination and same recorded net")
	check(not entry.has("applied_currency_settlement"), "Baccarat denomination metadata never fabricates a measured-loss witness")
	var after := _protected(run)
	var committed_snapshot := run.to_save_snapshot()
	var replay: Dictionary = host._sealed_action_host_resolve_intent("deal_baccarat", 90, result.get("blackjack_host_delivery", {}))
	check(typeof(replay.get("blackjack_host_replay", null)) == TYPE_DICTIONARY and run.to_save_snapshot() == committed_snapshot, currency + "/" + outcome + " duplicate delivery preserves complete authority/shoe/state")
	var slot := "baccarat_display_%s_%s" % [currency, outcome]
	check(SaveService.new().save_run(run, slot) == OK, currency + "/" + outcome + " official private Save accepts metadata")
	var restored: Variant = SaveService.new().load_run(slot)
	check(restored is RunState, currency + "/" + outcome + " fresh service restores result")
	if restored is RunState:
		check(_equal(_protected(restored), after), currency + "/" + outcome + " Save/cold data preserves money/history/RNG")
		var saved_table: Dictionary = game._table_state_preview(restored, restored.current_environment)
		check(_equal(saved_table.get("shoe", []), table.get("shoe", [])) and _equal(saved_table.get("last_hand", {}), table.get("last_hand", {})), currency + "/" + outcome + " Save/cold retains settled hand and remaining shoe")
		var saved_entry := _latest_baccarat_story(restored)
		check(str(saved_entry.get("currency", "")) == currency and int(saved_entry.get("currency_delta", 999)) == expected, currency + "/" + outcome + " explicit zero/loss/win currency survives codec")
	facts.append({"kind": "synthetic_sealed_result", "currency": currency, "outcome": outcome, "net": expected, "commission": table.get("last_result", {}).get("commission", 0), "story": entry})
	host.free(); canvas.free()

func _latest_baccarat_story(run: RunState) -> Dictionary:
	for index in range(run.story_log.size() - 1, -1, -1):
		var row: Dictionary = run.story_log[index]
		if str(row.get("type", "")) == "game_action" and str(row.get("game_id", "")) == "baccarat" and str(row.get("action_id", "")) == "deal_baccarat": return row
	return {}

func _protected(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "debt": run.debt.duplicate(true), "story": run.story_log.duplicate(true), "inventory": run.inventory.duplicate(true), "flags": run.narrative_flags.duplicate(true), "rng": run.rng_state, "action": run.numbers_state.action_index}

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
	if not output.is_empty(): FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts, "scope": "Synthetic owner readiness/staging and real sealed-action result/Save contracts only. Controlled new finite shoes; no campaign or hidden future shoe modified. Historical warm/cold readers and actual QA profile acceptance are primary-owned."}, "\t"))
	print("BACCARAT_READINESS_CURRENCY checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
