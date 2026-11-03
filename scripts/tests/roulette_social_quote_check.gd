extends SceneTree

# UX-ROULETTE-SOCIAL-QUOTE-001. Synthetic new tables preserve the reported
# $5 patron / $9 outside-minimum inputs. The final check uses unedited generated
# patrons and ordinary Foundation actions. No fixture spins or funds a wager.
const Roulette := preload("res://scripts/games/roulette.gd")
const Foundation := preload("res://scripts/ui/foundation_main.gd")
const ContractBase := preload("res://scripts/tests/foundation/check_core_content.gd")
const Canvas := preload("res://scripts/ui/game_surface_canvas.gd")

class ClockHost extends Foundation:
	func _environment_simulation_time_msec() -> int:
		return 100000
	func _game_test_stake_floor() -> int:
		return 9
	func _game_test_bankroll() -> int:
		return 76
	func _game_test_archetype() -> Dictionary:
		for value in library.environment_archetypes:
			if str((value as Dictionary).get("id", "")) == "bar":
				return (value as Dictionary).duplicate(true)
		return super._game_test_archetype()

var checks := 0
var failures: Array[String] = []
var facts: Array = []
var library: ContentLibrary

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_absolute_path(), "Explicit private persistence root is required."):
		_finish()
		return
	library = ContentLibrary.new()
	library.load(false)
	if OS.get_cmdline_user_args().has("--baseline"):
		_baseline()
		_finish()
		return
	if OS.get_cmdline_user_args().has("--phase-only"):
		_pending_presentation_quotes()
		_finish()
		return
	for currency in ["cash", "chips"]:
		for fade in [false, true]:
			_quote_case(_fixture({"currency": currency}), {}, fade, 9, true, currency + "/reported-below-minimum")
			_quote_case(_fixture({"currency": currency, "patron_stake": 9}), {}, fade, 9, true, currency + "/equal-minimum")
			_quote_case(_fixture({"currency": currency, "patron_stake": 15}), {}, fade, 15, true, currency + "/above-minimum")
			_quote_case(_fixture({"currency": currency, "patron_stake": 20, "funds": 12}), {}, fade, 12, true, currency + "/bankroll-clipped")
			_quote_case(_fixture({"currency": currency, "patron_stake": 20, "table_max": 12}), {}, fade, 12, true, currency + "/table-clipped")
			_quote_case(_fixture({"currency": currency, "funds": 8}), {}, fade, 0, false, currency + "/cannot-meet-outside-minimum")
			_quote_case(_fixture({"currency": currency, "ceiling": 8}), {}, fade, 0, false, currency + "/room-ceiling-rejection")
		_quote_case(_fixture({"currency": currency, "style": "favorite_17"}), {}, false, 0, false, currency + "/inside-minimum-rejection")
		_quote_case(_fixture({"currency": currency, "style": "favorite_17"}), {}, true, 9, true, currency + "/inside-patron-outside-fade")
		_additive_and_cleanup(currency)
	_pending_presentation_quotes()
	await _ordinary_host_actions()
	_finish()

func _baseline() -> void:
	# This bounded pre-fix reproduction intentionally avoids new product helpers.
	# Missing quotes yield one ordinary contract failure, rather than a parser,
	# missing-method error or a cascade through the post-fix acceptance cases.
	var fixture := _fixture()
	var game: GameModule = fixture.game
	var run: RunState = fixture.run
	var ui := {"focused_patron_index": 0, "surface_time_msec": 100000}
	var before := run.to_save_snapshot().duplicate(true)
	var state: Dictionary = game.surface_state(run, run.current_environment, ui)
	var quote: Dictionary = state.get("patron_wager_quotes", {}).get("fade", {})
	var command: Dictionary = game.surface_action_command("roulette_patron_bet", 100, false, ui, run, run.current_environment)
	var raw_stake := int(state.get("patrons", [])[0].get("visible_bet", {}).get("stake", -1))
	var staged := _pending_total(command.get("ui_state", {}))
	_check(raw_stake == 5, "Baseline retains the reported patron's raw $5 wager")
	_check(staged == 9, "Baseline normal FADE command stages the table's $9 outside minimum")
	_check(_equal(run.to_save_snapshot(), before), "Baseline quotation/staging preserve complete run/table/wallets/RNG without spinning")
	_check(bool(quote.get("ok", false)) and int(quote.get("stake", -1)) == staged, "Player quote must disclose the effective $9 FADE increment before staging")
	facts.append({"case": "pre-fix-reported-inputs", "raw_patron_stake": raw_stake, "player_quote_fields_present": state.has("patron_wager_quotes"), "player_quote": quote, "normal_command_staged": staged, "wallet_rng_table_unchanged": _equal(run.to_save_snapshot(), before)})

func _fixture(options: Dictionary = {}) -> Dictionary:
	var game := Roulette.new()
	game.setup(library.game("roulette"), library)
	var run := RunState.new()
	var currency := str(options.get("currency", "cash"))
	run.start_new("ROULETTE-SOCIAL-QUOTE-" + currency)
	run.bankroll = int(options.get("funds", 76)) if currency == "cash" else 0
	run.grand_casino_chips = int(options.get("funds", 76)) if currency == "chips" else 0
	run.simulation_msec = 100000
	var environment := {
		"id": "roulette_social_quote_synthetic",
		"archetype_id": "grand_casino" if currency == "chips" else "small_underground_casino",
		"kind": "boss" if currency == "chips" else "casino",
		"game_ids": ["roulette"],
		"economic_profile": {"stake_floor": 9, "stake_ceiling": int(options.get("ceiling", 200))},
	}
	var table: Dictionary = game.generate_environment_state(run, environment, run.create_rng("synthetic_table"))
	# Deliberately synthetic setup, entirely before any sealed session exists.
	table["rules"]["table_max"] = int(options.get("table_max", 200))
	table["patrons"] = [{"id": "synthetic_nix", "name": "Nix", "bet_style": str(options.get("style", "columns")), "cosmetic_bet": int(options.get("patron_stake", 5)), "chip_stack": 20, "rapport": 50, "watching": false}]
	environment["game_states"] = {"roulette": table}
	run.current_environment = environment
	return {"game": game, "run": run, "patron_stake": int(options.get("patron_stake", 5)), "currency": currency}

func _quote_case(fixture: Dictionary, input_ui: Dictionary, fade: bool, expected_stake: int, expected_ok: bool, label: String) -> Dictionary:
	var game: GameModule = fixture.game
	var run: RunState = fixture.run
	var ui := input_ui.duplicate(true)
	ui["focused_patron_index"] = 0
	ui["surface_time_msec"] = 100000
	var before := run.to_save_snapshot().duplicate(true)
	var before_ui := ui.duplicate(true)
	var state: Dictionary = game.surface_state(run, run.current_environment, ui)
	var patch: Dictionary = game.surface_realtime_state_patch(run, run.current_environment, ui, state)
	var direction := "fade" if fade else "with"
	var quote: Dictionary = state.get("patron_wager_quotes", {}).get(direction, {})
	_check(not quote.is_empty(), label + "/" + direction + " publishes a player quote")
	_check(bool(quote.get("ok", false)) == expected_ok, label + "/" + direction + " eligibility matches table rules")
	if expected_ok:
		_check(int(quote.get("stake", -1)) == expected_stake, label + "/" + direction + " quotes the added player stake")
	else:
		_check(not str(quote.get("message", "")).is_empty(), label + "/" + direction + " explains its unavailable action")
	_check(_equal(state.get("patron_wager_quotes", {}), patch.get("patron_wager_quotes", {})), label + "/" + direction + " full and lightweight quotes agree")
	var patrons: Array = state.get("patrons", [])
	_check(not patrons.is_empty() and int(patrons[0].get("visible_bet", {}).get("stake", -1)) == int(fixture.patron_stake), label + " retains the patron's actual wager")
	_check(_equal(run.to_save_snapshot(), before) and _equal(ui, before_ui), label + " quote projections preserve complete run/table/RNG and input UI")
	_rendered_quote(game, state, direction, expected_stake, expected_ok, str(fixture.currency), label)
	var command: Dictionary = game.surface_action_command("roulette_patron_bet", 100 if fade else 0, false, ui, run, run.current_environment)
	var next: Dictionary = command.get("ui_state", {})
	var added := _pending_total(next) - _pending_total(ui)
	_check(added == expected_stake if expected_ok else added == 0, label + "/" + direction + " normal command stages exactly its quoted increment")
	if expected_ok:
		_check(int(next.get("table_social_alignment", {}).get("stake", -1)) == expected_stake, label + " social alignment records only the new increment")
	else:
		_check(_equal(next.get("roulette_bets", []), ui.get("roulette_bets", [])), label + " rejected action preserves existing draft")
	_check(_equal(run.to_save_snapshot(), before), label + " staging neither funds/spins nor changes run/table/RNG")
	facts.append({"case": label, "direction": direction, "ok": expected_ok, "quoted_increment": quote.get("stake", 0), "staged_increment": added, "patron_stake": fixture.patron_stake})
	return next

func _rendered_quote(game: GameModule, state: Dictionary, direction: String, stake: int, enabled: bool, currency: String, label: String) -> void:
	var harness := ContractBase.SurfaceHarness.new()
	harness.setup(state)
	game.draw_surface(harness, state, {"contract_harness": true})
	var prefix := "FADE" if direction == "fade" else "WITH"
	var action_index := 100 if direction == "fade" else 0
	var matched: Dictionary = {}
	for value in harness.label_records:
		var record: Dictionary = value
		if str(record.get("text", "")).begins_with(prefix):
			matched = record
			break
	_check(not matched.is_empty(), label + " renders a " + prefix + " control")
	if enabled:
		var text_value := str(matched.get("text", ""))
		_check(text_value.contains(str(stake)), label + " rendered " + prefix + " discloses its exact player amount")
		_check(text_value.contains("$") if currency == "cash" else not text_value.contains("$"), label + " rendered quote uses the correct currency")
	var action_hits := 0
	var card := Rect2(710, 18, 176, 64)
	var leave_rect := _rect(state.get("surface_back_rect", {}))
	for value in harness.hit_regions:
		var hit: Dictionary = value
		if str(hit.get("action", "")) == "roulette_patron_bet" and int(hit.get("index", -1)) == action_index:
			action_hits += 1
			var rect: Rect2 = hit.get("rect", Rect2())
			_check(card.encloses(rect) and not rect.intersects(leave_rect), label + " social control stays within its card and clear of Leave")
	_check(action_hits == (1 if enabled else 0), label + " unavailable controls do not register actionable hits")
	if not matched.is_empty():
		var canvas := Canvas.new()
		var font := canvas.get_theme_default_font()
		var rect: Rect2 = matched.get("rect", Rect2())
		var text_value := str(matched.get("text", ""))
		if _check(rect.has_area(), label + " quote has a bounded text rectangle"):
			var fitted: int = canvas._centered_label_fit_size(font, text_value, rect, int(matched.get("font_size", 8)))
			_check(font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x <= rect.size.x, label + " quoted label fits its rendered control")
		canvas.free()
	var patron_label := false
	for value in harness.labels:
		if str(value).begins_with("PATRON "):
			patron_label = true
	_check(patron_label, label + " labels the patron's wager separately from the player's action")

func _additive_and_cleanup(currency: String) -> void:
	var fixture := _fixture({"currency": currency})
	var game: GameModule = fixture.game
	var run: RunState = fixture.run
	var first := _quote_case(fixture, {}, true, 9, true, currency + "/first-fade")
	var second := _quote_case(fixture, first, true, 9, true, currency + "/duplicate-fade")
	_check(_pending_total(second) == 18 and (second.get("roulette_bets", []) as Array).size() == 1, currency + " duplicate FADE adds to one existing stack")
	var both := _quote_case(fixture, second, false, 9, true, currency + "/add-with")
	_check(_pending_total(both) == 27 and (both.get("roulette_bets", []) as Array).size() == 2, currency + " WITH adds a distinct source target after FADE")
	var before := run.to_save_snapshot().duplicate(true)
	var undo: Dictionary = game.surface_action_command("roulette_undo", 0, false, both, run, run.current_environment)
	_check(_equal(undo.get("ui_state", {}).get("roulette_bets", []), second.get("roulette_bets", [])), currency + " normal Undo removes only the latest quoted increment")
	var clear: Dictionary = game.surface_action_command("roulette_clear", 0, false, undo.get("ui_state", {}), run, run.current_environment)
	_check(_pending_total(clear.get("ui_state", {})) == 0, currency + " normal Clear removes the unfunded draft")
	_check(_equal(run.to_save_snapshot(), before), currency + " Undo/Clear preserve wallets, table, patron and RNG")
	# Capacity is shared with all other draft targets, not just the social stack.
	var limited := _fixture({"currency": currency, "funds": 20, "patron_stake": 15})
	var staged := _quote_case(limited, {}, false, 15, true, currency + "/existing-draft")
	_quote_case(limited, staged, true, 0, false, currency + "/remaining-draft-capacity-rejection")

func _pending_presentation_quotes() -> void:
	var fixture := _fixture()
	var game: GameModule = fixture.game
	var run: RunState = fixture.run
	var table: Dictionary = run.current_environment.get("game_states", {}).get("roulette", {})
	# Author one detached presentation fixture before any authority exists. The
	# normal engine's pure payout calculation supplies a consistent result shape;
	# no action is resolved, money transferred, or RNG consumed by this setup.
	var patron: Dictionary = table.get("patrons", [])[0]
	var bet: Dictionary = game.call("_patron_roulette_wager", patron, table, 0)
	bet["stake"] = 9
	var results: Array = game.call("_settle_roulette_bets", "4", [bet], table)
	table["last_result"] = {
		"spin_id": "synthetic_pending_quote", "payout_animation_id": "synthetic_pending_payout",
		"winning_number": "4", "winning_color": "black", "winning_index": (table.get("wheel_sequence", []) as Array).find("4"),
		"bankroll_delta": 18, "suspicion_delta": 0, "celebration_score": 0,
		"summary": "Synthetic presentation fixture", "bets": [bet], "bet_results": results,
		"resolved_at_msec": 100000, "presentation_patrons": table.get("patrons", []).duplicate(true),
	}
	table["spin_count"] = 1
	var before := run.to_save_snapshot().duplicate(true)
	for elapsed in [0, 5599, 5600, 7399, 7400, 8999, 9000]:
		var ui := {"focused_patron_index": 0, "surface_time_msec": 100000 + elapsed}
		var state: Dictionary = game.surface_state(run, run.current_environment, ui)
		var patch: Dictionary = game.surface_realtime_state_patch(run, run.current_environment, ui, state)
		var intent_patch: Dictionary = game.call("_roulette_in_place_session_surface_patch", ui, run, run.current_environment)
		for channel in [{"name": "full", "data": state}, {"name": "realtime", "data": patch}, {"name": "in-place", "data": intent_patch}]:
			var quotes: Dictionary = (channel.data as Dictionary).get("patron_wager_quotes", {})
			if elapsed < 9000:
				_check(quotes.is_empty(), "%s hides bankroll-dependent quotes before reveal at elapsed %d" % [channel.name, elapsed])
			else:
				_check(bool(quotes.get("fade", {}).get("ok", false)) and int(quotes.get("fade", {}).get("stake", -1)) == 9, "%s restores the validated quote at the settled boundary" % channel.name)
	var pending_ui := {"focused_patron_index": 0, "surface_time_msec": 105600}
	var rejected: Dictionary = game.surface_action_command("roulette_patron_bet", 100, false, pending_ui, run, run.current_environment)
	_check(bool(rejected.get("handled", false)) and not bool(rejected.get("resolve", false)) and _pending_total(rejected.get("ui_state", {})) == 0, "A stale social click during payout is a handled rejection without new chips")
	var rejected_patch: Dictionary = game.call("_roulette_in_place_session_surface_patch", rejected.get("ui_state", {}), run, run.current_environment)
	_check((rejected_patch.get("patron_wager_quotes", {}) as Dictionary).is_empty(), "Handled rejection cannot restore pending-result quotes through its in-place patch")
	var armed: Dictionary = game.surface_action_command("roulette_past_post", 0, false, pending_ui, run, run.current_environment)
	_check(bool(armed.get("handled", false)) and not bool(armed.get("resolve", false)) and bool(armed.get("ui_state", {}).get("past_post_armed", false)), "Ordinary first late-chip click arms the existing payout-window challenge")
	var armed_patch: Dictionary = game.call("_roulette_in_place_session_surface_patch", armed.get("ui_state", {}), run, run.current_environment)
	_check((armed_patch.get("patron_wager_quotes", {}) as Dictionary).is_empty(), "Legitimate late-chip arming cannot expose bankroll-dependent social quotes during payout")
	_check(_equal(run.to_save_snapshot(), before), "Pending presentation projections, rejected staging and late-chip arming preserve complete run/table/wallets/RNG")
	facts.append({"case": "synthetic-pending-presentation", "elapsed_boundaries": [0, 5599, 5600, 7399, 7400, 8999, 9000], "channels": ["full", "realtime", "in-place"], "handled_rejection": true, "legitimate_past_post_arming": true, "actual_spin_or_funding": false})

func _ordinary_host_actions() -> void:
	var app := ClockHost.new()
	app.continuous_environment_clock_enabled = false
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	var started: Dictionary = app.start_game_test_session("roulette")
	if not _check(bool(started.get("ok", false)), "Ordinary host opens an unmodified generated roulette table"):
		app.queue_free()
		return
	# All generated FADE targets are outside bets. Prefer an outside source too;
	# retain the real generated seats if the seed happens to generate straights.
	var state: Dictionary = app.game_surface_canvas.state
	var patrons: Array = state.get("patrons", [])
	var selected := 0
	for index in range(patrons.size()):
		if str(patrons[index].get("bet_style", "")) != "favorite_17":
			selected = index
			break
	var before := _money(app.run_state)
	app._on_game_surface_action("roulette_patron_focus", selected)
	state = app.game_surface_canvas.state
	var quote: Dictionary = state.get("patron_wager_quotes", {}).get("fade", {})
	var old_total := _host_pending_total(app)
	if _check(bool(quote.get("ok", false)) and int(quote.get("stake", 0)) > 0, "Ordinary focused generated patron publishes an affordable FADE quote"):
		app._on_game_surface_action("roulette_patron_bet", selected + 100)
		_check(_host_pending_total(app) - old_total == int(quote.stake), "Ordinary sealed host stages exactly the visible generated patron quote")
		_check(_equal(_money(app.run_state), before), "Ordinary host focus/staging preserves cash/chips/debt/RNG")
		var table: Dictionary = app.run_state.current_environment.get("game_states", {}).get("roulette", {})
		_check(int(table.get("spin_count", -1)) == 0 and (table.get("last_result", {}) as Dictionary).is_empty(), "Ordinary social action neither spins nor settles")
		app._on_game_surface_action("roulette_clear", 0)
		_check(_host_pending_total(app) == 0 and _equal(_money(app.run_state), before), "Ordinary host Clear removes the draft without funding it")
		facts.append({"case": "ordinary-generated-host", "patron": patrons[selected].get("name", ""), "source_style": patrons[selected].get("bet_style", ""), "patron_stake": patrons[selected].get("visible_bet", {}).get("stake", 0), "player_increment": quote.stake, "spins": table.get("spin_count", -1)})
	if app.save_service.async_save_in_flight():
		app.save_service.wait_for_async_save()
	app.queue_free()

func _host_pending_total(app: ClockHost) -> int:
	var table: Dictionary = app.run_state.current_environment.get("game_states", {}).get("roulette", {})
	return _pending_total(table.get("_blackjack_action_authority", {}).get("session", {}))

func _pending_total(ui: Dictionary) -> int:
	var total := 0
	for value in ui.get("roulette_bets", []):
		total += int((value as Dictionary).get("stake", 0))
	return total

func _money(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "debt": run.debt.duplicate(true), "rng": run.rng_state}

func _rect(value: Dictionary) -> Rect2:
	return Rect2(float(value.get("x", 0)), float(value.get("y", 0)), float(value.get("w", value.get("width", 0))), float(value.get("h", value.get("height", 0))))

func _equal(left: Variant, right: Variant) -> bool:
	if typeof(left) in [TYPE_INT, TYPE_FLOAT] and typeof(right) in [TYPE_INT, TYPE_FLOAT]:
		return left == right
	if typeof(left) != typeof(right):
		return false
	if typeof(left) == TYPE_DICTIONARY:
		if left.size() != right.size():
			return false
		for key in left:
			if not right.has(key) or not _equal(left[key], right[key]):
				return false
		return true
	if typeof(left) == TYPE_ARRAY:
		if left.size() != right.size():
			return false
		for index in range(left.size()):
			if not _equal(left[index], right[index]):
				return false
		return true
	return left == right

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
	return ok

func _finish() -> void:
	var mode := "baseline" if OS.get_cmdline_user_args().has("--baseline") else "phase-only" if OS.get_cmdline_user_args().has("--phase-only") else "acceptance"
	var result := {"id": "UX-ROULETTE-SOCIAL-QUOTE-001", "mode": mode, "checks": checks, "failures": failures, "facts": facts, "scope": "Synthetic fresh-table quotes/rendered controls, synthetic pending-result presentation boundaries, and ordinary generated host staging/Clear only; no actual spin, funding, original-save access or deployed Web play."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("ROULETTE_SOCIAL_QUOTE_RESULT " + JSON.stringify(result))
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)
