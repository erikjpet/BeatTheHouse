extends SceneTree

# Bounded synthetic settlement and real module/control fixtures. Room content
# comes from the authoritative archetypes and installs through RunState. Forced
# Quarter Falls isolates accounting from Ridge multipliers and random features;
# randomized room/catalog coverage is a separate contract. No Web pixels claimed.
const Game := preload("res://scripts/games/coin_pusher.gd")
const Solver := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")
const Live := preload("res://scripts/games/coin_pusher/coin_pusher_live_session.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const FreshStorage := preload("res://scripts/tests/fixtures/qa_fresh_storage_admission.gd")
const Main := preload("res://scripts/ui/foundation_main.gd")

# Keep the real launcher/host handlers while disabling only optional background
# UI construction. This fixture constructs the run UI synchronously at entry.
class PracticeHost extends Main:
	func _prewarm_run_ui_after_web_start() -> void:
		pass

var library: ContentLibrary
var checks := 0
var failures: Array[String] = []
var facts: Array[Dictionary] = []
var storage_admitted := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _private_roots():
		_finish()
		return
	if not _check(Solver.native_backend_available_for_test(), "pinned native Coin Pusher solver is available; fallback is not accepted"):
		_finish()
		return
	library = ContentLibrary.new()
	library.load(false)
	var shared := Game.new()
	shared.setup(library.game("coin_pusher"), library)
	var main := _fixture("grand_casino", 100, "GRAND-PUSHER-MAIN", shared)
	var high := _fixture("grand_casino_high_limit", 100, "GRAND-PUSHER-HIGH", shared)
	if not main.is_empty() and not high.is_empty():
		_accounting(main, 1)
		_accounting(high, 5)
		_independent_cabinets(main, high)
		_snapshot_and_kernel(shared, 1)
		_snapshot_and_kernel(shared, 5)
		_bonus_semantics(high)
		_labels(shared)
	_cash_limited_hold("grand_casino", 1, 1)
	_cash_limited_hold("grand_casino_high_limit", 5, 9)
	await _practice_control()
	_finish()


func _fixture(room: String, cash: int, seed_text: String, shared: CoinPusherGame = null) -> Dictionary:
	var game := shared
	if game == null:
		game = Game.new()
		game.setup(library.game("coin_pusher"), library)
	var run := RunState.new()
	run.start_new(seed_text)
	run.bankroll = cash
	run.grand_casino_chips = 200
	var rng := RngStream.new()
	rng.configure(JsonCoerce._overflow_stable_hash(seed_text))
	var archetype := library.environment_archetype(room)
	if not _check(not archetype.is_empty(), room + " authoritative archetype exists"):
		return {}
	var environment := EnvironmentInstanceScript.from_archetype(archetype, 0, rng, library).to_dict()
	if room == "grand_casino_high_limit":
		var authored: Dictionary = archetype.get("local_narrative_flags", {})
		var generated: Dictionary = environment.get("local_narrative_flags", {})
		var round_trip := EnvironmentInstanceScript.from_dict(environment).to_dict()
		_check(int(authored.get("coin_pusher_drop_cost", -1)) == 5 and int(authored.get("coin_pusher_coin_value", -1)) == 5, "High Limit authors denomination in persistent room policy")
		_check(generated == authored and round_trip.get("local_narrative_flags", {}) == generated, "High Limit generation and EnvironmentInstance round-trip preserve the exact room policy")
	# Internal casino rooms intentionally share the outward world-map target.
	environment["world_node_id"] = "grand_casino"
	var modifiers: Dictionary = environment.get("scenario_game_modifiers", {}).duplicate(true)
	var pusher: Dictionary = modifiers.get("coin_pusher", {}).duplicate(true)
	pusher["variation_id"] = "quarter_falls"
	modifiers["coin_pusher"] = pusher
	environment["scenario_game_modifiers"] = modifiers
	if not _check(bool(run.set_environment(environment).get("ok", false)), room + " canonical room installation succeeds"):
		return {}
	run.current_environment["game_states"]["coin_pusher"] = game.generate_environment_state(run, run.current_environment, run.create_rng("grand_pusher_accounting"))
	game.enter(run, run.current_environment)
	return {"game": game, "run": run, "room": room}


func _accounting(fixture: Dictionary, value: int) -> void:
	var game: CoinPusherGame = fixture.game
	var run: RunState = fixture.run
	var environment := run.current_environment
	var room := str(fixture.room)
	var machine: Dictionary = game._ensure_live_machine(run, environment)
	_check(game._drop_cost(environment) == value and game._coin_value(environment) == value, room + " unit price and ordinary coin value are correct")
	_check(int(machine.get("drop_cost", 1)) == value and int(machine.get("coin_value", 1)) == value, room + " durable machine retains its denomination with the ordinary dollar fallback")
	var cash := run.bankroll
	var chips := run.grand_casino_chips
	var command := game.surface_action_command("coin_pusher_drop", 0, false, {}, run, environment)
	_check(bool(command.get("direct_resolve", false)) and int(command.get("set_stake", -1)) == value, room + " single coin control quotes the denomination")
	var result := game.resolve_with_context(Game.DROP_ACTION, int(command.get("set_stake", 0)), run, environment, run.create_rng("grand_pusher_drop"), {})
	var applied := GameModule.apply_result(run, result)
	_check(bool(applied.get("ok", false)) and run.bankroll == cash - value and run.grand_casino_chips == chips, room + " real paid action debits cash once and leaves unrelated chips unchanged")
	var batch_cash := run.bankroll
	var before_queue := int(game._queued_drop_count(machine))
	var batch := game.resolve_with_context(Game.DROP_ACTION, 3 * value, run, environment, run.create_rng("grand_pusher_batch"), {})
	var batch_applied := GameModule.apply_result(run, batch)
	_check(bool(batch_applied.get("ok", false)) and run.bankroll == batch_cash - 3 * value and run.grand_casino_chips == chips, room + " three-coin reservation debits the exact batch cash value")
	_check(int(game._queued_drop_count(machine)) == before_queue + 3, room + " paid batch reserves exactly three additional physical coins")
	var view := game.surface_state(run, environment, {})
	_check(int(view.get("coin_pusher_drop_cost", -1)) == value and int(view.get("coin_pusher_coin_value", -1)) == value, room + " surface discloses its configured unit values")
	# Copy a known terminal ledger into an isolated settlement fixture; exercise
	# production crediting and duplicate prevention without forcing a live win.
	var definition: Dictionary = game._machine_definition("quarter_falls", value)
	var simulation := Solver.create_machine(_rng("TRAY-" + room), definition, 0)
	simulation["tray_ledger"] = [{"kind": "coin", "value": value, "item_id": "", "provenance": {}}]
	var settlement_machine := {"variation_id": "quarter_falls", "coin_value": value, "drop_cost": value, "simulation": simulation}
	var before_credit := run.bankroll
	var credited: Dictionary = game._settle_tray_coins(run, environment, settlement_machine)
	var duplicate: Dictionary = game._settle_tray_coins(run, environment, settlement_machine)
	_check(int(credited.get("cash", -1)) == value and int(credited.get("count", -1)) == 1 and run.bankroll == before_credit + value, room + " one ordinary tray coin credits its face value exactly once")
	_check(int(duplicate.get("cash", -1)) == 0 and int(duplicate.get("count", -1)) == 0 and run.grand_casino_chips == chips, room + " an empty repeat settlement adds no money or chips")
	facts.append({"room": room, "unit": value, "single_cash_delta": -value, "normal_tray_credit": credited, "chips": chips})


func _cash_limited_hold(room: String, value: int, cash: int) -> void:
	var fixture := _fixture(room, cash, "GRAND-CASH-LIMIT-" + room)
	if fixture.is_empty():
		return
	var game: CoinPusherGame = fixture.game
	var run: RunState = fixture.run
	var machine: Dictionary = game._ensure_live_machine(run, run.current_environment)
	var ui := {"surface_time_msec": 0}
	var begin := game.surface_pointer_command(Game.DROP_CHARGE_ACTION, 0, "begin", Vector2(576, 374), ui, run, run.current_environment)
	ui = begin.get("ui_state", ui)
	var started_tick := int(ui.get("coin_pusher_drop_charge_started_tick", -1))
	var view := game.surface_state(run, run.current_environment, ui)
	game.surface_realtime_state_patch(run, run.current_environment, ui, view)
	for frame in range(1, 9):
		ui["surface_time_msec"] = frame * 67
		view.merge(game.surface_realtime_state_patch(run, run.current_environment, ui, view), true)
		if int(game._simulation(machine).get("tick", 0)) - started_tick >= 12:
			break
	var moved := game.surface_pointer_command(Game.DROP_CHARGE_ACTION, 0, "move", Vector2(576, 374), ui, run, run.current_environment)
	ui = moved.get("ui_state", ui)
	var quote: Dictionary = moved.get("surface_state_patch", {})
	_check(int(ui.get("coin_pusher_drop_charge_count", 0)) >= 2 and Solver.last_step_backend_for_test() == "native_v3", room + " sustained input requests at least two coins using real native ticks")
	_check(int(quote.get("coin_pusher_drop_payable_count", -1)) == 1 and int(quote.get("coin_pusher_drop_payable_total", -1)) == value, room + " hold quote limits payment to cash despite 200 unrelated chips")
	var chips := run.grand_casino_chips
	var release := game.surface_pointer_command(Game.DROP_CHARGE_ACTION, 0, "end", Vector2(576, 374), ui, run, run.current_environment)
	_check(bool(release.get("direct_resolve", false)) and int(release.get("set_stake", -1)) == value, room + " two requested coins release only one affordable coin")
	if bool(release.get("direct_resolve", false)):
		var paid := game.resolve_with_context(str(release.get("action_id", "")), int(release.get("set_stake", 0)), run, run.current_environment, run.create_rng("cash_limited_release"), release.get("ui_state", {}))
		var applied := GameModule.apply_result(run, paid)
		_check(bool(applied.get("ok", false)) and run.bankroll == cash - value and run.grand_casino_chips == chips, room + " limited hold settles one exact cash debit without chip conversion")
	facts.append({"room": room, "cash_limit_start": cash, "cash_limit_after": run.bankroll, "chips_before": chips, "chips_after": run.grand_casino_chips, "held_quote": quote})


func _independent_cabinets(main: Dictionary, high: Dictionary) -> void:
	var game: CoinPusherGame = main.game
	var main_run: RunState = main.run
	var high_run: RunState = high.run
	var main_key := game._live_key(main_run, main_run.current_environment)
	var high_key := game._live_key(high_run, high_run.current_environment)
	_check(main_key != high_key, "Main and High Limit cabinets have distinct live keys despite sharing the Grand world target")
	var main_machine: Dictionary = game._ensure_live_machine(main_run, main_run.current_environment)
	var high_machine: Dictionary = game._ensure_live_machine(high_run, high_run.current_environment)
	_check(int(main_machine.get("coin_value", 1)) == 1 and int(high_machine.get("coin_value", 1)) == 5, "shared game module retains both cabinet denominations independently")
	_check(game._coin_value(main_run.current_environment) == 1 and game._drop_cost(main_run.current_environment) == 1, "return to Main keeps its original dollar economics")
	var ordinary := {"archetype_id": "bar", "game_states": {}}
	_check(game._drop_cost(ordinary) == 1 and game._coin_value(ordinary) == 1, "Grand High Limit does not change other rooms' ordinary economics")


func _snapshot_and_kernel(game: CoinPusherGame, value: int) -> void:
	var definition: Dictionary = game._machine_definition("quarter_falls", value)
	var simulation := Solver.create_machine(_rng("DENOM-SNAPSHOT-%d" % value), definition, 0)
	var coin := Solver.add_coin(simulation, _rng("DENOM-DROP-%d" % value), 50000)
	_check(int(coin.get("meta", {}).get("value", -1)) == value, "solver insertion gives normal coin face value $%d" % value)
	coin["x"] = 50000
	coin["y"] = 6250
	coin["z"] = 0
	coin["vx"] = 0
	coin["vy"] = 0
	coin["vz"] = 0
	coin["support_kind"] = "deck"
	coin["rest_state"] = "resting"
	var snapshot := Live.make_snapshot(simulation)
	var restored := Live.restore_snapshot(snapshot, definition)
	var bodies: Array = restored.get("bodies", [])
	_check(bodies.size() == 1 and int(bodies[0].get("meta", {}).get("value", -1)) == value, "compact snapshot restores normal coin denomination $%d" % value)
	var reference := restored.duplicate(true)
	var native := restored.duplicate(true)
	for _tick in range(90):
		Solver.step_ticks_reference_for_test(reference, {"motor_enabled": false}, 1)
		Solver.step_ticks(native, {"motor_enabled": false}, 1)
	var reference_tray: Array = reference.get("tray_ledger", [])
	var native_tray: Array = native.get("tray_ledger", [])
	_check(reference_tray.size() == 1 and native_tray.size() == 1 and int(reference_tray[0].get("value", -1)) == value and int(native_tray[0].get("value", -1)) == value, "native and GDScript terminal ledgers retain $%d ordinary coin value" % value)
	_check(JSON.stringify(reference_tray, "", true) == JSON.stringify(native_tray, "", true), "native and GDScript ordinary coin payout ledgers agree at $%d" % value)
	var resaved := Live.make_snapshot(native)
	var reloaded := Live.restore_snapshot(resaved, definition)
	# Compact ordinary tray entries deliberately omit body_id; keep every other
	# field and apply identical JSON number transport to both receipts. Do not
	# round values, discard provenance or compare only a summed payout.
	_check(_compact_tray_receipts(reloaded.get("tray_ledger", [])) == _compact_tray_receipts(native_tray), "compact tray round-trip retains every persisted $%d accounting/provenance field" % value)
	var encoded_again := Live.make_snapshot(reloaded)
	_check(encoded_again.get("tray_count", -1) == resaved.get("tray_count", -2) and encoded_again.get("tray_coin_blob", "missing") == resaved.get("tray_coin_blob", "absent") and encoded_again.get("tray_extras", []) == resaved.get("tray_extras", []), "compact $%d tray round-trip re-encodes identical count value bytes and extras" % value)
	facts.append({"unit": value, "native_tray": native_tray.duplicate(true), "restored_tray": reloaded.get("tray_ledger", []).duplicate(true), "compact_tray_body_identity": "body_id intentionally absent from compact ordinary-coin format", "tray_coin_blob": resaved.get("tray_coin_blob", "")})
	if value == 1:
		var legacy := definition.duplicate(true)
		legacy["coins"].erase("value")
		var legacy_restore := Live.restore_snapshot(snapshot, legacy)
		_check(int(legacy_restore.get("bodies", [])[0].get("meta", {}).get("value", -1)) == 1, "legacy definition without denomination retains the one-dollar fallback")


func _bonus_semantics(fixture: Dictionary) -> void:
	var game: CoinPusherGame = fixture.game
	var run: RunState = fixture.run
	var definition: Dictionary = game._machine_definition("quarter_falls", 5)
	var machine := {"variation_id": "quarter_falls", "coin_value": 5, "drop_cost": 5, "simulation": Solver.create_machine(_rng("HIGH-BONUS"), definition, 0), "riders": [], "drop_queue": [], "variation_state": {}}
	Live.begin(machine, definition, 71)
	var cash := run.bankroll
	var chips := run.grand_casino_chips
	game._consume_physics_events(run, machine, [{"kind": "plinko_cup", "reward": {"kind": "instant_payout", "value": 7}}, {"kind": "plinko_cup", "reward": {"kind": "drop_multiplier", "count": 3}, "metadata": {"provenance": {"chain_depth": 0}}}], _rng("HIGH-BONUS-EVENTS"))
	_check(run.bankroll == cash + 7 and run.grand_casino_chips == chips, "High Limit keeps an authored seven-dollar instant bonus unchanged")
	_check(game._queued_drop_count(machine) == 3 and bool(machine.get("drop_queue", [])[0].get("bonus_origin", false)), "High Limit preserves three free bonus tokens without charging or multiplying their count")
	_check(int(machine.get("total_cost", 0)) == 0, "bonus feeder adds no paid drop cost")
	_check(game._queued_drop_total(machine) == 0, "free bonus feeder contributes no paid batch value")
	var mixed := {"drop_cost": 5, "drop_queue": [{"remaining": 2, "unit_cost": 3, "bonus_origin": false}, {"remaining": 3, "bonus_origin": true}, {"remaining": 1}]}
	_check(game._queued_drop_count(mixed) == 6 and game._queued_drop_total(mixed) == 11, "mixed queue preserves recorded paid unit cost, zero-priced bonus tokens and legacy cabinet fallback")


func _labels(game: CoinPusherGame) -> void:
	var renderer: Variant = game._coin_pusher_renderer()
	for variation in ["quarter_falls", "jackpot_ridge", "vault_drop"]:
		for value in [1, 5]:
			var state := {"coin_pusher_variation_id": variation, "coin_pusher_drop_cost": value, "coin_pusher_coin_value": 1, "coin_pusher_drop_charge_count": 0, "coin_pusher_drop_queue_count": 0, "coin_pusher_drop_queue_total": 0}
			_check(str(renderer._drop_control_label(state)) == "DROP $%d" % value, variation + " idle shows only its configured drop price")
			state["coin_pusher_drop_charge_count"] = 3
			state["coin_pusher_drop_payable_count"] = 2
			state["coin_pusher_drop_payable_total"] = 2 * value
			_check(str(renderer._drop_control_label(state)) == "DROPPING $%d" % (2 * value), variation + " holding shows the affordable live purchase total")
			state["coin_pusher_drop_charge_count"] = 0
			state["coin_pusher_drop_queue_count"] = 3
			state["coin_pusher_drop_queue_total"] = 3 * value
			_check(str(renderer._drop_control_label(state)) == "DROPPING $%d" % (3 * value), variation + " feeder shows actual remaining paid batch value rather than face value or count")
			state["coin_pusher_drop_queue_total"] = 0
			_check(str(renderer._drop_control_label(state)) == "DROPPING $0", variation + " free bonus feeder does not imply another purchase")
			state["coin_pusher_drop_queue_count"] = 0
			_check(str(renderer._drop_control_label(state)) == "DROP $%d" % value, variation + " feeder returns to idle when no coins remain queued")


func _practice_control() -> void:
	# Exercise the unchanged default Practice launcher, not a synthetic practice
	# flag or a replacement archetype. Pure label cases above cover all variants.
	var app := PracticeHost.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	await process_frame
	app.user_settings.coach_tips_enabled = false
	app.open_game_test_menu()
	if not _check(app.game_test_seed_input != null, "ordinary Practice seed control exists"):
		await _close_practice_host(app)
		return
	app.game_test_seed_input.text = "SHARED-PUSHER-PRACTICE-COPY"
	if _check(bool(app.start_game_test_session("coin_pusher").get("ok", false)), "unchanged default Practice launcher opens Coin Pusher"):
		var run: RunState = app.run_state
		var game: CoinPusherGame = app.current_game
		var cost := game._drop_cost(run.current_environment)
		var renderer: Variant = game._coin_pusher_renderer()
		var idle := game.surface_state(run, run.current_environment, {})
		_check(str(renderer._drop_control_label(idle)) == "DROP $%d" % cost, "actual Practice surface uses the shared idle copy")
		var cash := run.bankroll
		var chips := run.grand_casino_chips
		app._on_game_surface_action("coin_pusher_drop", 0, false)
		var active := game.surface_state(run, run.current_environment, {})
		_check(run.bankroll == cash - cost and run.grand_casino_chips == chips and int(active.get("coin_pusher_drop_queue_total", -1)) == cost and str(renderer._drop_control_label(active)) == "DROPPING $%d" % cost, "actual Practice tap preserves its debit and immediately shows the paid batch total")
		facts.append({"route": "unchanged_default_practice", "seed": run.seed_text, "variation": active.get("coin_pusher_variation_id", ""), "unit_cost": cost, "cash_before": cash, "cash_after": run.bankroll, "idle_label": renderer._drop_control_label(idle), "active_label": renderer._drop_control_label(active), "active_paid_total": active.get("coin_pusher_drop_queue_total", -1)})
	await _close_practice_host(app)


func _close_practice_host(app: PracticeHost) -> void:
	app._drain_script_prewarm_requests_for_shutdown()
	app.save_service.wait_for_async_save()
	app.queue_free()
	await process_frame


func _compact_tray_receipts(ledger: Array) -> Array:
	var receipts := ledger.duplicate(true)
	for entry in receipts:
		if typeof(entry) == TYPE_DICTIONARY:
			entry.erase("body_id")
	return JSON.parse_string(JSON.stringify(receipts))


func _rng(label: String) -> RngStream:
	var rng := RngStream.new()
	rng.configure(JsonCoerce._overflow_stable_hash(label))
	return rng


func _private_roots() -> bool:
	var admission := FreshStorage.validate()
	storage_admitted = _check(bool(admission.get("ok", false)), "exact prepared fresh QA storage admission: " + JSON.stringify(admission.get("errors", [])))
	return storage_admitted


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
	return ok


func _finish() -> void:
	var report := {"checks": checks, "failures": failures, "facts": facts, "fidelity": "Disposable authoritative-archetype installations, real paid module/control/native-tick paths, unchanged default Practice launcher/tap, and explicit synthetic terminal/bonus/snapshot fixtures. Shared copy covers all variants; GDScript/native accounting equivalence sampled at $1 and $5. No browser pixels, natural wins or cold-process persistence claimed."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if storage_admitted and not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	print("COIN_PUSHER_GRAND_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
