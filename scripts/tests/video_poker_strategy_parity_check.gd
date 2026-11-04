extends SceneTree

# Run from scripts/tests after the audit owner installs this file and its
# reference sibling. No save/profile IO; direct strategy attribution, not a
# rendered gameplay or Web qualification. No performance threshold is imposed.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const VideoPokerScript := preload("res://scripts/games/video_poker.gd")
const ReferenceScript := preload("res://scripts/tests/video_poker_strategy_reference.gd")
const JsonCoerceScript := preload("res://scripts/core/json_coerce.gd")

var failures: Array[String] = []
var payout_checks := 0
var mask_checks := 0
var generated_cases: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load(false)
	var game: GameModule = VideoPokerScript.new()
	game.setup(library.game("video_poker"), library)
	var reference: GameModule = ReferenceScript.new()
	reference.setup(library.game("video_poker"), library)
	if library.game("video_poker").is_empty() or not library.validation_errors.is_empty():
		failures.append("Production content did not load: %s" % str(library.validation_errors))
	else:
		_check_payout_categories(game, reference)
		_check_generated_masks(library, game, reference)
	print("BTH_VP_STRATEGY_PARITY_REPORT " + JSON.stringify({
		"source_sha_reported_by_runner": OS.get_environment("BTH_PERF_SOURCE_SHA"),
		"reference_source": "dc15b7d369f435d50fbf16e37af33952a4c58760",
		"method": "exact old payout/category oracle and old deterministic completion loop",
		"payout_checks": payout_checks,
		"mask_checks": mask_checks,
		"generated_cases": generated_cases,
		"passed": failures.is_empty(),
		"failures": failures,
	}))
	quit(0 if failures.is_empty() else 1)


func _check_payout_categories(game: GameModule, reference: GameModule) -> void:
	var hands := [
		_hand([10, 11, 12, 13, 14], [0, 0, 0, 0, 0]),
		_hand([14, 13, 12, 11, 10], [0, 0, 0, 0, 0]),
		_hand([5, 6, 7, 8, 9], [1, 1, 1, 1, 1]),
		_hand([14, 2, 3, 4, 5]),
		_hand([2, 3, 4, 5, 6]),
		_hand([14, 14, 14, 14, 4]),
		_hand([2, 2, 2, 2, 14]),
		_hand([3, 3, 3, 3, 13]),
		_hand([3, 3, 3, 11, 11]),
		_hand([2, 4, 6, 9, 14], [2, 2, 2, 2, 2]),
		_hand([11, 11, 11, 5, 6]),
		_hand([2, 2, 14, 14, 13]),
		_hand([11, 11, 3, 6, 8]),
		_hand([4, 4, 7, 10, 14]),
		_hand([2, 5, 8, 10, 13]),
		_hand([2, 11, 12, 13, 14], [0, 0, 0, 0, 0]),
		_hand([2, 2, 14, 14, 13]),
		_hand([0, 10, 11, 12, 13], [4, 0, 0, 0, 0]),
	]
	for variant_id in VideoPokerScript.VARIANTS:
		for tier_id in VideoPokerScript.PAYTABLE_TIERS:
			var state := {"variant_id": variant_id, "paytable_tier_id": tier_id, "progressive_meter": 777}
			var variant: Dictionary = game.call("_variant", state)
			for hand in hands:
				for coin_count in [1, 5]:
					for coin_value in [1, 3]:
						_check_pay(game, reference, hand, variant, state, coin_count, coin_value, coin_count == 5)
	# Preserve first-row lookup and no-pay semantics even for unusual supplied
	# row lists: a missing royal must not accidentally gain progressive bonuses.
	var state := {"variant_id": "jacks_or_better", "paytable_tier_id": "full_pay", "progressive_meter": 777}
	var variant: Dictionary = game.call("_variant", state)
	var royal: Array = hands[0]
	var duplicate: Dictionary = variant.duplicate(true)
	var rows: Array = duplicate.get("rows", [])
	if not rows.is_empty():
		var extra: Dictionary = (rows[0] as Dictionary).duplicate(true)
		extra["mult"] = 99999
		extra["max_mult"] = 99999
		rows.append(extra)
	_check_pay(game, reference, royal, duplicate, state, 5, 3, true)
	var missing: Dictionary = variant.duplicate(true)
	var retained: Array = []
	for row_value in missing.get("rows", []):
		if str((row_value as Dictionary).get("key", "")) != "royal_flush":
			retained.append(row_value)
	missing["rows"] = retained
	_check_pay(game, reference, royal, missing, state, 5, 3, true)
	_check_pay(game, reference, royal, {"id": "jacks_or_better", "rows": []}, state, 5, 3, true)


func _check_pay(game: GameModule, reference: GameModule, hand: Array, variant: Dictionary, state: Dictionary, coin_count: int, coin_value: int, is_max_bet: bool) -> void:
	var before := JSON.stringify([hand, variant, state])
	var wild_ranks: Array = game.call("_wild_ranks", variant)
	var old_descriptor: Dictionary = reference.call("_reference_evaluate", hand, wild_ranks)
	var live_descriptor: Dictionary = game.call("_evaluate", hand, wild_ranks)
	if live_descriptor != old_descriptor or not live_descriptor.has("scoring_indices"):
		failures.append("Default settlement/display evaluator descriptor changed.")
	var expected := int(reference.call("_strategy_hand_pay", hand, variant, state, coin_count, coin_value, is_max_bet))
	var actual := int(game.call("_strategy_hand_pay", hand, variant, state, coin_count, coin_value, is_max_bet))
	payout_checks += 1
	if actual != expected:
		failures.append("Payout differs: variant=%s tier=%s hand=%s coins=%d value=%d max=%s expected=%d actual=%d" % [str(variant.get("id", "")), str(variant.get("paytable_tier_id", "")), JSON.stringify(hand), coin_count, coin_value, str(is_max_bet), expected, actual])
	if JSON.stringify([hand, variant, state]) != before:
		failures.append("Payout projection mutated its inputs.")


func _check_generated_masks(library: ContentLibrary, game: GameModule, reference: GameModule) -> void:
	var seen: Dictionary = {}
	for seed_index in range(64):
		var run: RunState = RunStateScript.new()
		run.start_new("BTH-PERF-002-PARITY-%d" % seed_index)
		run.bankroll = 10000
		var environment := {"id": "vp_strategy_parity", "archetype_id": "bar", "kind": "casino", "game_ids": ["video_poker"], "game_states": {}}
		var machine: Dictionary = game.generate_environment_state(run, environment, run.create_rng("vp_strategy_parity_machine"))
		var cabinet_id := str(machine.get("cabinet_id", ""))
		if seen.has(cabinet_id):
			continue
		seen[cabinet_id] = true
		environment["game_states"] = {"video_poker": machine}
		run.set_environment(environment)
		environment = run.current_environment
		game.enter(run, environment)
		var deal: Dictionary = game.surface_action_command("video_poker_deal", 0, false, {}, run, environment)
		var ui: Dictionary = deal.get("ui_state", {})
		var surface: Dictionary = game.surface_state(run, environment, ui)
		var hand: Array = surface.get("hand", [])
		if str(surface.get("phase", "")) != "hold" or hand.size() != VideoPokerScript.HAND_SIZE:
			failures.append("Generated cabinet %s did not reach the ordinary hold phase." % cabinet_id)
			continue
		var variant: Dictionary = game.call("_variant", machine)
		var coin_count := int(surface.get("coin_count", 1))
		var coin_value := int(surface.get("coin_value", 1))
		var is_max_bet := int(ui.get("bet_level", 0)) >= VideoPokerScript.MAX_BET_LEVEL
		var key := "%s|%s|%d|%d|%d|%d" % [str(variant.get("id", "")), str(variant.get("paytable_tier_id", "")), coin_count, coin_value, int(machine.get("progressive_meter", VideoPokerScript.PROGRESSIVE_BASE)), JsonCoerceScript._stable_hash(str(game.call("_hand_signature", hand)))]
		var base_deck: Array = game.call("_base_deck", variant)
		var deck: Array = game.call("_deck_without_cards", base_deck, hand)
		var before := JSON.stringify([hand, deck, variant, machine])
		var expected_holds: Array = []
		var best_average := -1.0
		for mask in range(1 << VideoPokerScript.HAND_SIZE):
			var holds: Array = []
			for card_index in range(VideoPokerScript.HAND_SIZE):
				if (mask & (1 << card_index)) != 0:
					holds.append(card_index)
			var expected := float(reference.call("_hold_expected_pay", hand, deck, holds, variant, machine, coin_count, coin_value, is_max_bet, key))
			var actual := float(game.call("_hold_expected_pay", hand, deck, holds, variant, machine, coin_count, coin_value, is_max_bet, key))
			mask_checks += 1
			if actual != expected:
				failures.append("Exact EV differs for cabinet=%s mask=%d expected=%.17f actual=%.17f" % [cabinet_id, mask, expected, actual])
			if expected > best_average + 0.000001 or (is_equal_approx(expected, best_average) and holds.size() > expected_holds.size()):
				best_average = expected
				expected_holds = holds
		var cache: Dictionary = game.get("_strategy_hold_cache")
		cache.clear()
		var cache_order: Array = game.get("_strategy_hold_cache_order")
		cache_order.clear()
		var cold: Array = game.call("_best_odds_holds", hand, variant, machine, coin_count, coin_value, is_max_bet)
		var warm: Array = game.call("_best_odds_holds", hand, variant, machine, coin_count, coin_value, is_max_bet)
		if cold != expected_holds or warm != expected_holds or cache.size() != 1:
			failures.append("Cold/warm best holds or cache differ for cabinet %s." % cabinet_id)
		cold.clear()
		var hostile_repeat: Array = game.call("_best_odds_holds", hand, variant, machine, coin_count, coin_value, is_max_bet)
		if hostile_repeat != expected_holds:
			failures.append("A caller-mutated return changed the cached recommendation.")
		if JSON.stringify([hand, deck, variant, machine]) != before:
			failures.append("Generated mask evaluation mutated its inputs.")
		generated_cases.append({"seed": run.seed_text, "cabinet_id": cabinet_id, "hand": hand, "expected_holds": expected_holds, "mask_count": 32})
		if seen.size() == VideoPokerScript.CABINET_ORDER.size():
			break
	if generated_cases.size() != VideoPokerScript.CABINET_ORDER.size():
		failures.append("Parity did not cover every generated cabinet: %s" % JSON.stringify(seen.keys()))


func _hand(ranks: Array, suits: Array = []) -> Array:
	var hand: Array = []
	for index in range(ranks.size()):
		var card := {"rank": int(ranks[index]), "suit": int(suits[index]) if index < suits.size() else index % 4, "deck": 0}
		if int(ranks[index]) == 0:
			card["joker"] = true
		hand.append(card)
	return hand
