extends SceneTree

# Disposable native module fixtures; no original R07 profile or Web/pixel
# acceptance claim. Hardware labels are captured from the actual renderer's
# draw callback and fitted with the existing real GameSurfaceCanvas font helper.
const Game := preload("res://scripts/games/coin_pusher.gd")
const Solver := preload("res://scripts/games/coin_pusher/coin_pusher_solver_api.gd")
const Canvas := preload("res://scripts/ui/game_surface_canvas.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const PRICE_KEYS := ["coin_pusher_drop_cost", "coin_pusher_drop_payable_count", "coin_pusher_drop_payable_total"]
const LABEL_RECT := Rect2(538, 391, 76, 9)

class LabelCanvas extends Canvas:
	var renderer: Variant
	var fixture_state: Dictionary = {}
	var captured: Dictionary = {}
	func _draw() -> void:
		if renderer == null: return
		hit_regions.clear()
		surface_begin_design_space(Vector2(900, 430))
		renderer._configure_projection(fixture_state)
		renderer._draw_hardware(self, fixture_state, renderer._colors(renderer._cabinet(fixture_state)))
		surface_end_design_space()
	func surface_label_centered_plain(text: String, rect: Rect2, font_size: int, color: Color) -> void:
		if rect == Rect2(538, 391, 76, 9):
			var font := get_theme_default_font()
			var fitted := _centered_label_fit_size(font, text, rect, font_size)
			captured = {"label": text, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "requested_font": font_size, "fitted_font": fitted, "width": font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x, "height": font.get_ascent(fitted) + font.get_descent(fitted)}
		super.surface_label_centered_plain(text, rect, font_size, color)

var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {"baseline": {}, "labels": [], "pricing": [], "actions": [], "cold": []}
var private_root := ""
var library: ContentLibrary
var references: Array = []
var completed := false


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	if not _private_roots(): _finish(); return
	if not _check(Solver.native_backend_available_for_test(), "exact pinned native Coin Pusher solver is available; fallback is not accepted"): _finish(); return
	library = ContentLibrary.new()
	library.load(false)
	root.size = Vector2i(900, 430)
	if OS.get_cmdline_user_args().has("--cold"):
		_cold()
	else:
		await _baseline()
		if not OS.get_cmdline_user_args().has("--baseline"):
			if not _check(Game.new().has_method("_drop_price_view"), "production price projection helper exists"): _finish(); return
			for variation in ["quarter_falls", "jackpot_ridge", "vault_drop"]:
				await _projection_cases(variation)
			await _paid_controls()
			var file := FileAccess.open(_reference_path(), FileAccess.WRITE)
			if _check(file != null, "private official-save reference opens"):
				file.store_string(JSON.stringify(references, "\t")); file.close()
	completed = true
	_finish()


func _fixture(variation: String, authored_cost: int, cash: int = 54) -> Dictionary:
	var definition := library.game("coin_pusher").duplicate(true)
	var tuning: Dictionary = definition.get("coin_pusher_tuning", {}).duplicate(true)
	tuning["drop_cost"] = authored_cost
	definition["coin_pusher_tuning"] = tuning
	var game := Game.new()
	game.setup(definition, library)
	var run := RunState.new()
	run.start_new("COIN-PUSHER-DROP-PRICE-" + variation)
	run.bankroll = cash
	run.grand_casino_chips = 25
	var environment := {"id": "drop_price_" + variation, "archetype_id": "bar", "world_node_id": "bar", "game_ids": ["coin_pusher"], "scenario_game_modifiers": {"coin_pusher": {"variation_id": variation}}, "game_states": {}}
	var installed := run.set_environment(environment)
	if not _check(bool(installed.get("ok", false)), variation + " canonical environment installs"): return {}
	run.current_environment["game_states"] = {"coin_pusher": game.generate_environment_state(run, run.current_environment, run.create_rng("drop_price_machine"))}
	game.enter(run, run.current_environment)
	return {"game": game, "run": run, "cost": maxi(1, authored_cost), "variation": variation}


func _baseline() -> void:
	var fixture := _fixture("quarter_falls", 1)
	if fixture.is_empty(): return
	var game: CoinPusherGame = fixture.game
	var run: RunState = fixture.run
	var before := _fingerprint(run)
	var view := game.surface_state(run, run.current_environment, {})
	var renderer: Variant = game._coin_pusher_renderer()
	var captured := await _capture(renderer, view)
	_check(int(view.get("coin_pusher_drop_cost", -1)) == 1 and int(view.get("coin_pusher_drop_payable_count", -1)) == 0 and int(view.get("coin_pusher_drop_payable_total", -1)) == 0, "ordinary current full view publishes canonical idle unit price and zero held total")
	_check(str(captured.get("label", "")) == "DROP/HOLD $1", "actual hardware draw identifies the one-dollar price before purchase")
	_check(str(view.get("surface_action_bindings", {}).get("coin_pusher_drop", {}).get("label", "")).contains("$1"), "ordinary drop binding label identifies its price")
	_check(_fingerprint(run) == before, "full price view and actual hardware label draw are read-only")
	facts.baseline = {"cash": run.bankroll, "fields": _prices(view), "drawn_label": captured, "solver_native": Solver.native_backend_available_for_test()}


func _capture(renderer: Variant, view: Dictionary) -> Dictionary:
	var canvas := LabelCanvas.new()
	canvas.renderer = renderer
	canvas.fixture_state = view
	canvas.size = Vector2(900, 430)
	root.add_child(canvas)
	canvas.queue_redraw()
	for frame in range(3): await process_frame
	var captured := canvas.captured.duplicate(true)
	_check(not captured.is_empty(), "actual hardware renderer publishes price label at existing rectangle")
	var drop_hits: Array = []
	for region in canvas.hit_regions:
		if str(region.get("action", "")) == Game.DROP_CHARGE_ACTION:
			var rect: Rect2 = region.get("rect", Rect2())
			drop_hits.append([rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	captured["drop_hits"] = drop_hits
	canvas.free()
	return captured


func _projection_cases(variation: String) -> void:
	var fixture := _fixture(variation, 1, 200)
	if fixture.is_empty(): return
	var game: CoinPusherGame = fixture.game
	var run: RunState = fixture.run
	var renderer: Variant = game._coin_pusher_renderer()
	for authored in [1, 3, 0]:
		game.definition["coin_pusher_tuning"]["drop_cost"] = authored
		var cost := maxi(1, authored)
		var before := _fingerprint(run)
		for held in [0, 1, 60, 99]:
			var count := 0 if held == 0 else mini(clampi(held, 1, 60), run.wager_capacity_for_game("coin_pusher", run.current_environment) / cost)
			var projected: Dictionary = game.call("_drop_price_view", run, run.current_environment, held)
			_assert_prices(projected, cost, count, variation + " authored%d held%d pure quote" % [authored, held])
		var full := game.surface_state(run, run.current_environment, {"coin_pusher_drop_charge_count": 3})
		_assert_prices(full, cost, 3, variation + " full held quote")
		_check(str(full.get("surface_action_bindings", {}).get("coin_pusher_drop", {}).get("label", "")).contains("$%d" % cost) and str(full.get("surface_action_bindings", {}).get(Game.DROP_CHARGE_ACTION, {}).get("label", "")).contains("$%d" % cost), variation + " both binding labels disclose current unit cost")
		_check(_fingerprint(run) == before, variation + " every pure/full price quote leaves complete run unchanged")
		if authored in [1, 3]: _save(run, game, "pusher_price_%s_%d" % [variation, cost], authored)
		facts.pricing.append({"variation": variation, "authored_cost": authored, "canonical_cost": cost, "cash": run.bankroll, "full": _prices(full)})
	game.definition["coin_pusher_tuning"]["drop_cost"] = 3
	for spec in [{"cash": 200, "held": 0, "label": "DROP/HOLD $3"}, {"cash": 200, "held": 3, "label": "HOLD 3 $9"}, {"cash": 200, "held": 60, "label": "HOLD 60 $180"}, {"cash": 10, "held": 60, "label": "HOLD 3 $9"}, {"cash": 2, "held": 3, "label": "NEED $3"}]:
		run.bankroll = int(spec.cash)
		var full := game.surface_state(run, run.current_environment, {"coin_pusher_drop_charge_count": int(spec.held)})
		await _assert_label(renderer, full, str(spec.label), variation)
	var cached := game.surface_state(run, run.current_environment, {})
	var signature := str(renderer._hardware_cache_signature(cached, "", 0))
	for key in PRICE_KEYS:
		var changed := cached.duplicate(false)
		changed[key] = int(cached.get(key, 0)) + 1
		_check(str(renderer._hardware_cache_signature(changed, "", 0)) != signature, variation + " hardware cache invalidates on " + key)


func _assert_label(renderer: Variant, view: Dictionary, expected: String, label: String) -> void:
	var capture := await _capture(renderer, view)
	_check(str(capture.get("label", "")) == expected, label + " actual drawn label: " + expected)
	_check(int(capture.get("requested_font", 0)) == 8 and int(capture.get("fitted_font", 0)) in [6, 7, 8] and float(capture.get("width", 9999)) <= LABEL_RECT.size.x and float(capture.get("height", 9999)) <= LABEL_RECT.size.y, label + " actual production font helper fits unchanged76x9 price label")
	_check(capture.get("drop_hits", []) == [[540.0, 352.0, 72.0, 48.0]], label + " existing paid-drop hold hitbox remains exact")
	facts.labels.append({"variation": label, "expected": expected, "actual": capture})


func _paid_controls() -> void:
	var fixture := _fixture("quarter_falls", 3)
	if fixture.is_empty(): return
	var game: CoinPusherGame = fixture.game
	var run: RunState = fixture.run
	var renderer: Variant = game._coin_pusher_renderer()
	var ui: Dictionary = {"surface_time_msec": 0}
	var tap := game.surface_action_command("coin_pusher_drop", 0, false, ui, run, run.current_environment)
	_check(bool(tap.get("direct_resolve", false)) and int(tap.get("set_stake", 0)) == 3, "ordinary tap quotes current three-dollar drop")
	_apply_drop(game, run, int(tap.get("set_stake", 0)), 1, "ordinary tap")
	var begin := game.surface_pointer_command(Game.DROP_CHARGE_ACTION, 0, "begin", Vector2(576, 374), ui, run, run.current_environment)
	ui = begin.get("ui_state", {})
	_assert_prices(begin.get("surface_state_patch", {}), 3, 1, "immediate Hold begin quote")
	var view := game.surface_state(run, run.current_environment, ui)
	game.surface_realtime_state_patch(run, run.current_environment, ui, view)
	# Five bounded67ms callbacks advance the real native solver by20ticks.
	# Clock setup is synthetic; no hidden particle or outcome is overwritten.
	for frame in range(1, 6):
		ui["surface_time_msec"] = frame * 67
		var patch := game.surface_realtime_state_patch(run, run.current_environment, ui, view)
		view.merge(patch, true)
	_check(Solver.last_step_backend_for_test() == "native_v3", "Hold time progresses through the actual native solver")
	facts["native_backend"] = Solver.last_step_backend_for_test()
	var moved := game.surface_pointer_command(Game.DROP_CHARGE_ACTION, 0, "move", Vector2(576, 374), ui, run, run.current_environment)
	ui = moved.get("ui_state", ui)
	_assert_prices(moved.get("surface_state_patch", {}), 3, 3, "immediate Hold move quote after native ticks")
	_assert_prices(view, 3, 3, "realtime Hold quote after native ticks")
	var held_view := view.duplicate(false)
	_generic_patch_guards(game, run, renderer, held_view)
	var released := game.surface_pointer_command(Game.DROP_CHARGE_ACTION, 0, "end", Vector2(576, 374), ui, run, run.current_environment)
	_check(bool(released.get("direct_resolve", false)) and int(released.get("set_stake", 0)) == 9, "ordinary Hold release resolves displayed three drops for9")
	var paid_result := _apply_drop(game, run, int(released.get("set_stake", 0)), 3, "ordinary Hold release")
	held_view.merge(paid_result.get("surface_action_view_patch", {}), true)
	var live: Dictionary = game._ensure_live_machine(run, run.current_environment)
	var paid_queue := int(game._queued_drop_count(live))
	_check(int(held_view.get("coin_pusher_drop_charge_count", -1)) == 0 and int(held_view.get("coin_pusher_drop_queue_count", -1)) == paid_queue, "merged paid result patch immediately clears held gesture and publishes exact paid queue")
	_assert_prices(held_view, 3, 0, "merged paid Hold result quote")
	_check(str(renderer._drop_control_label(held_view)) == "PAID %d; DROP $3" % paid_queue, "direct-resolution merged view immediately labels paid queue rather than NEED")
	facts["paid_hold_merged_view"] = {"raw_charge": held_view.get("coin_pusher_drop_charge_count", -1), "queue": paid_queue, "price": _prices(held_view), "label": renderer._drop_control_label(held_view)}
	var before_cancel := _fingerprint(run)
	var cancel_start := game.surface_pointer_command(Game.DROP_CHARGE_ACTION, 0, "begin", Vector2(576, 374), {}, run, run.current_environment)
	var cancelled := game.surface_pointer_command(Game.DROP_CHARGE_ACTION, 0, "cancel", Vector2(576, 374), cancel_start.get("ui_state", {}), run, run.current_environment)
	_check(not bool(cancelled.get("direct_resolve", false)) and _fingerprint(run) == before_cancel, "cancelled Hold never charges or queues another drop")
	_assert_prices(cancelled.get("surface_state_patch", {}), 3, 0, "immediate cancelled Hold quote")
	var poor_fixture := _fixture("vault_drop", 3, 2)
	var poor_game: CoinPusherGame = poor_fixture.game
	var poor: RunState = poor_fixture.run
	var before_poor := _fingerprint(poor)
	var poor_begin := poor_game.surface_pointer_command(Game.DROP_CHARGE_ACTION, 0, "begin", Vector2(576, 374), {}, poor, poor.current_environment)
	var poor_end := poor_game.surface_pointer_command(Game.DROP_CHARGE_ACTION, 0, "end", Vector2(576, 374), poor_begin.get("ui_state", {}), poor, poor.current_environment)
	_check(not bool(poor_end.get("direct_resolve", false)) and _fingerprint(poor) == before_poor, "insufficient Hold release never pays or queues")
	_assert_prices(poor_begin.get("surface_state_patch", {}), 3, 0, "insufficient immediate quote")
	# Use a fresh unadvanced live cabinet to make the already-paid count exact.
	var paid_fixture := _fixture("jackpot_ridge", 3)
	var paid_game: CoinPusherGame = paid_fixture.game
	var paid: RunState = paid_fixture.run
	_apply_drop(paid_game, paid, 15, 5, "five-drop paid reservation")
	var paid_view := paid_game.surface_state(paid, paid.current_environment, {})
	await _assert_label(paid_game._coin_pusher_renderer(), paid_view, "PAID 5; DROP $3", "already-paid queue")
	_check(paid.bankroll == 39 and int(paid_view.get("coin_pusher_drop_queue_count", 0)) == 5, "paid queue count stays separate from next unit price")


func _generic_patch_guards(game: CoinPusherGame, run: RunState, renderer: Variant, held_view: Dictionary) -> void:
	var before := _fingerprint(run)
	var machine: Dictionary = game._ensure_live_machine(run, run.current_environment)
	var generic: Dictionary = game._surface_action_view_patch(machine, run, run.current_environment, {})
	_check(not generic.has("coin_pusher_drop_charge_count"), "generic action patch without gesture context omits raw Hold count")
	for key in PRICE_KEYS: _check(not generic.has(key), "generic action patch without gesture context omits " + key)
	var retained := held_view.duplicate(false)
	retained.merge(generic, true)
	_check(int(retained.get("coin_pusher_drop_charge_count", -1)) == int(held_view.get("coin_pusher_drop_charge_count", -2)) and _prices(retained) == _prices(held_view) and str(renderer._drop_control_label(retained)) == "HOLD 3 $9", "merging context-free generic patch preserves coherent existing Hold quote")
	var explicit_clear: Dictionary = game._surface_action_view_patch(machine, run, run.current_environment, {"coin_pusher_drop_charge_count": 0})
	var cleared := held_view.duplicate(false)
	cleared.merge(explicit_clear, true)
	_check(explicit_clear.has("coin_pusher_drop_charge_count") and int(cleared.get("coin_pusher_drop_charge_count", -1)) == 0, "generic patch with explicit cleared gesture immediately resets old raw Hold count")
	_assert_prices(cleared, 3, 0, "generic explicit-clear merged quote")
	var clear_label := str(renderer._drop_control_label(cleared))
	_check(not clear_label.begins_with("HOLD") and not clear_label.begins_with("NEED"), "explicit-clear merged quote cannot retain Hold or create a false NEED label")
	_check(_fingerprint(run) == before, "both generic patch projections preserve full run without payment or physics mutation")
	facts["generic_patch_boundary"] = {"retained_label": renderer._drop_control_label(retained), "retained_price": _prices(retained), "clear_label": clear_label, "clear_price": _prices(cleared)}


func _apply_drop(game: CoinPusherGame, run: RunState, stake: int, count: int, label: String) -> Dictionary:
	var before := _protected(run)
	var machine: Dictionary = game._ensure_live_machine(run, run.current_environment)
	var previous_count := int(machine.get("action_count", 0))
	var previous_cost := int(machine.get("total_cost", 0))
	var queued := int(game._queued_drop_count(machine))
	var result := game.resolve_with_context(Game.DROP_ACTION, stake, run, run.current_environment, run.create_rng(), {})
	var applied := GameModule.apply_result(run, result)
	_check(bool(result.get("ok", false)) and bool(applied.get("ok", false)), label + " real module resolution and one apply succeed")
	_assert_prices(result.get("surface_action_view_patch", {}), game._drop_cost(), 0, label + " immediate paid action quote")
	_check(run.bankroll == int(before.cash) - count * game._drop_cost() and run.grand_casino_chips == int(before.chips), label + " exact quoted debit is applied once to cash")
	_check(int(machine.get("action_count", 0)) == previous_count + count and int(machine.get("total_cost", 0)) == previous_cost + stake and int(game._queued_drop_count(machine)) == queued + count, label + " paid queue action count and total cost increase exactly once")
	_check(str(run.rng_state) == str(before.rng) and run.game_clock_minutes == int(before.clock), label + " payment leaves root RNG and game clock unchanged")
	facts.actions.append({"label": label, "cash_before": before.cash, "cash_after": run.bankroll, "unit_cost": game._drop_cost(), "paid_count": count, "paid_total": stake, "queued": game._queued_drop_count(machine)})
	return result


func _assert_prices(view: Dictionary, cost: int, count: int, label: String) -> void:
	_check(int(view.get(PRICE_KEYS[0], -1)) == cost and int(view.get(PRICE_KEYS[1], -1)) == count and int(view.get(PRICE_KEYS[2], -1)) == count * cost, label + " publishes exact unit payable count and total")


func _protected(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "rng_seed": str(run.rng_seed), "rng": str(run.rng_state), "clock": run.game_clock_minutes, "simulation_msec": run.simulation_msec, "history": run.story_log.duplicate(true), "machine": run.current_environment.get("game_states", {}).get("coin_pusher", {}).duplicate(true)}


func _save(run: RunState, game: CoinPusherGame, slot: String, authored_cost: int) -> void:
	var before := _protected(run)
	if not _check(SaveService.new().save_run(run, slot) == OK, "official Save stores idle/pre-payment " + slot): return
	_check(_protected(run) == before, "Save never charges or changes durable idle machine: " + slot)
	var loaded: Variant = SaveService.new().load_run(slot)
	if not _check(loaded is RunState, "fresh official SaveService loads " + slot): return
	_check(_persistent(_protected(loaded)) == _persistent(before), "official load preserves full durable machine wallets history RNG and clocks: " + slot)
	var quoted: Dictionary = game.call("_drop_price_view", loaded, loaded.current_environment, 3)
	_assert_prices(quoted, maxi(1, authored_cost), 3, "official loaded pre-payment Hold quote")
	references.append({"slot": slot, "authored_cost": authored_cost, "protected_json": JSON.stringify(_protected(loaded)), "price": quoted})


func _cold() -> void:
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(_reference_path()))
	if not _check(expected is Array and expected.size() == 6, "six idle/pre-payment producer save references exist"): return
	for reference in expected:
		var loaded: Variant = SaveService.new().load_run(str(reference.slot))
		if not _check(loaded is RunState, "independent process officially loads " + str(reference.slot)): continue
		var before := _fingerprint(loaded)
		_check(JSON.stringify(_protected(loaded)) == str(reference.protected_json), "cold complete durable machine wallets RNG clocks history equal producer load: " + str(reference.slot))
		var definition := library.game("coin_pusher").duplicate(true)
		definition["coin_pusher_tuning"]["drop_cost"] = int(reference.authored_cost)
		var game := Game.new()
		game.setup(definition, library)
		var view := game.surface_state(loaded, loaded.current_environment, {"coin_pusher_drop_charge_count": 3})
		# The reference crossed JSON.parse_string, which represents numbers as
		# floats. Normalize numeric transport on both complete price dictionaries;
		# missing keys, different values and extra fields remain unequal.
		_check(_persistent(_prices(view)) == _persistent(reference.price), "cold pre-payment view keeps identical authored unit count and total: " + str(reference.slot))
		_check(_fingerprint(loaded) == before, "cold quote never inserts pays resumes or changes machine: " + str(reference.slot))
		facts.cold.append({"slot": reference.slot, "cash": loaded.bankroll, "price": _prices(view), "paid_inputs": 0})


func _persistent(value: Variant) -> String: return Runtime.content_fingerprint(JSON.parse_string(JSON.stringify(value)))


func _prices(view: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in PRICE_KEYS: result[key] = view.get(key, null)
	return result


func _fingerprint(run: RunState) -> String: return Runtime.content_fingerprint(run.to_dict())
func _reference_path() -> String: return private_root.path_join("coin-pusher-drop-price-reference.json")


func _private_roots() -> bool:
	private_root = OS.get_environment("BTH_WORLD_REENTRY_ROOT").replace("\\", "/").simplify_path()
	if not _check(private_root.is_absolute_path() and "native-private-" in private_root, "explicit disposable native root required"): return false
	for key in ["APPDATA", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path().to_lower()
		if not _check(path == private_root.to_lower() or path.begins_with(private_root.to_lower() + "/"), "private containment for " + key): return false
	return _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "no original player save or browser profile is accepted")


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok


func _finish() -> void:
	_check(completed, "requested producer or cold stage reaches final assertion")
	var report := {"id": "BTH-COINPUSHER-DROP-PRICE-001", "checks": checks, "failures": failures, "facts": facts, "source_sha256": {"game": FileAccess.get_sha256("res://scripts/games/coin_pusher.gd"), "renderer": FileAccess.get_sha256("res://scripts/games/coin_pusher/coin_pusher_renderer.gd"), "test": FileAccess.get_sha256("res://scripts/tests/coin_pusher_drop_price_check.gd")}, "fidelity": "Disposable synthetic module/native-solver fixtures. Hardware label observed from actual renderer draw callback and real Canvas font fitting; no original R07 profile, screenshot/pixel or Web acceptance claim."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(report, "\t")); file.close()
	print("COIN_PUSHER_DROP_PRICE_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
