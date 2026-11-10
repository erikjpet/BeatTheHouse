extends Node

const VideoPokerScript := preload("res://scripts/games/video_poker.gd")
const LibraryScript := preload("res://scripts/core/content_library.gd")
var failures: Array[String] = []
var rows: Array = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var library := LibraryScript.new()
	library.load(false)
	for seed_index in [0, 2, 6]:
		await _case(library, seed_index)
	var report := {"passed": failures.is_empty(), "failures": failures, "rows": rows, "web": OS.has_feature("web"), "fidelity": "production-generated Deal and foreground realtime projection; synthetic module regression, not rendered host input"}
	print("BTH_VP_INCREMENTAL_REPORT " + JSON.stringify(report))
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__bth_vp_incremental_report = JSON.parse(%s);" % JSON.stringify(JSON.stringify(report)), true)
	else:
		get_tree().quit(0 if failures.is_empty() else 1)

func _case(library: ContentLibrary, seed_index: int) -> void:
	var run := RunState.new()
	run.start_new("BTH-PERF-002-PARITY-%d" % seed_index)
	run.bankroll = 10000
	var game := VideoPokerScript.new()
	game.setup(library.game("video_poker"), library)
	game.set_transient_state_key_context("incremental")
	var environment := {"id": "vp_strategy_parity", "archetype_id": "bar", "kind": "casino", "game_ids": ["video_poker"], "game_states": {}}
	var machine := game.generate_environment_state(run, environment, run.create_rng("vp_strategy_parity_machine"))
	environment.game_states = {"video_poker": machine}
	run.set_environment(environment)
	environment = run.current_environment
	game.enter(run, environment)
	var deal := game.surface_action_command("video_poker_deal", 0, false, {}, run, environment)
	var ui: Dictionary = deal.ui_state
	var bare := game.surface_state(run, environment, ui)
	var hand: Array = bare.hand
	run.add_item("freds_poker_hat")
	var before := JSON.stringify(run.to_save_snapshot())
	var start := Time.get_ticks_usec()
	var surface := game.surface_state(run, environment, ui)
	var cold_surface_usec := Time.get_ticks_usec() - start
	if not bool(surface.get("strategy_hint_pending", false)) or not str(surface.recommended_hold_text).begins_with("READING THE HAND") or int(game._strategy_hint_job.get("completed_samples", -1)) != 0:
		failures.append("Cold surface failed to publish pending advice without synchronous completions.")
	var same_frame := game.surface_realtime_state_patch(run, environment, ui, surface)
	if int(game._strategy_hint_job.get("completed_samples", -1)) != 0:
		failures.append("Entry anchor did strategy work before its first rendered frame.")
	var frames := 0
	var max_slice_usec := 0
	while bool(surface.get("strategy_hint_pending", false)) and frames < 1200:
		await get_tree().process_frame
		var before_samples := int(game._strategy_hint_job.get("completed_samples", 0))
		var slice_start := Time.get_ticks_usec()
		surface = game.surface_realtime_state_patch(run, environment, ui, surface)
		max_slice_usec = maxi(max_slice_usec, Time.get_ticks_usec() - slice_start)
		var after_samples := int(game._strategy_hint_job.get("completed_samples", game._strategy_hint_last_completed.get("completed_samples", 0)))
		if after_samples - before_samples > VideoPokerScript.STRATEGY_HINT_MAX_COMPLETIONS_PER_SLICE:
			failures.append("A projection exceeded its hard512-completion work limit.")
		frames += 1
	if bool(surface.get("strategy_hint_pending", false)):
		failures.append("Incremental advice never completed.")
	var variant := game._variant(machine)
	var coin_count := int(bare.coin_count)
	var coin_value := int(bare.coin_value)
	var is_max := int(ui.get("bet_level", 0)) >= VideoPokerScript.MAX_BET_LEVEL
	var key := game._strategy_cache_key(hand, variant, machine, coin_count, coin_value)
	var deck := game._deck_without_cards(game._base_deck(variant), hand)
	var scores: PackedFloat64Array = game._strategy_hint_last_completed.get("scores", PackedFloat64Array())
	if scores.size() != 32:
		failures.append("Missing completed incremental mask evidence.")
	else:
		for mask in range(32):
			var holds: Array = []
			for index in range(5):
				if mask & (1 << index): holds.append(index)
			var expected := game._hold_expected_pay(hand, deck, holds, variant, machine, coin_count, coin_value, is_max, key)
			if scores[mask] != expected:
				failures.append("Incremental EV differs for cabinet %s mask %d." % [machine.cabinet_id, mask])
	var oracle := VideoPokerScript.new()
	var expected_holds := oracle._best_odds_holds(hand, variant, machine, coin_count, coin_value, is_max)
	if surface.get("recommended_holds", []) != expected_holds or not game._strategy_hint_job.is_empty():
		failures.append("Completed incremental recommendation/cache differs.")
	if JSON.stringify(run.to_save_snapshot()) != before:
		failures.append("Incremental work changed the run snapshot.")
	var warm := game.surface_state(run, environment, ui)
	if bool(warm.get("strategy_hint_pending", true)) or warm.get("recommended_holds", []) != expected_holds:
		failures.append("Completed advice was not reused on redraw.")
	# Pending work is canceled at session reset, item removal, and hand replacement.
	game._strategy_hold_cache.clear()
	game._strategy_hold_cache_order.clear()
	surface = game.surface_state(run, environment, ui)
	game._advance_strategy_hint_job(10)
	var samples := int(game._strategy_hint_job.completed_samples)
	var toggle := game.surface_action_command("video_poker_hold", 0, false, ui, run, environment)
	if bool(toggle.get("handled", false)):
		ui = toggle.get("ui_state", ui)
	game.surface_state(run, environment, ui)
	if int(game._strategy_hint_job.get("completed_samples", -1)) != samples:
		failures.append("A hold change restarted unchanged hand advice.")
	game.set_transient_state_key_context("")
	if not game._strategy_hint_job.is_empty(): failures.append("Exit/session reset did not cancel advice.")
	game.set_transient_state_key_context("incremental")
	var resumed := game.surface_state(run, environment, ui)
	var resumed_frames := 0
	while bool(resumed.get("strategy_hint_pending", false)) and resumed_frames < 1200:
		await get_tree().process_frame
		resumed = game.surface_realtime_state_patch(run, environment, ui, resumed)
		resumed_frames += 1
	if bool(resumed.get("strategy_hint_pending", true)) or resumed.get("recommended_holds", []) != expected_holds:
		failures.append("A canceled partial job did not restart and finish the same advice on reentry.")
	game._strategy_hold_cache.clear()
	game._strategy_hold_cache_order.clear()
	game.set_transient_state_key_context("replacement")
	game.surface_state(run, environment, ui)
	var previous_key := str(game._strategy_hint_job.key)
	var previous_owner := str(game._strategy_hint_job.owner)
	var changed_hand := hand.duplicate(true)
	var swap: Variant = changed_hand[0]
	changed_hand[0] = changed_hand[1]
	changed_hand[1] = swap
	game._strategy_hint_projection(changed_hand, variant, machine, coin_count, coin_value, is_max, previous_owner)
	if str(game._strategy_hint_job.key) == previous_key or str(game._strategy_hint_job.owner) != previous_owner:
		failures.append("A true hand-order change did not replace the pending advice job.")
	var replacement := machine.duplicate(true)
	replacement.progressive_meter = int(machine.get("progressive_meter", 400)) + 1
	game._strategy_hint_projection(hand, game._variant(replacement), replacement, coin_count, coin_value, is_max, "new-owner")
	if str(game._strategy_hint_job.key) == previous_key or str(game._strategy_hint_job.owner) != "new-owner": failures.append("Replacement retained stale hand context.")
	game.surface_state(run, environment, {})
	if not game._strategy_hint_job.is_empty(): failures.append("Leaving the hold phase did not cancel advice.")
	game.surface_state(run, environment, ui)
	run.remove_item("freds_poker_hat")
	var removed := game.surface_state(run, environment, ui)
	if not game._strategy_hint_job.is_empty() or bool(removed.get("strategy_hint_pending", false)): failures.append("Removing the hat did not cancel advice.")
	# Report minimal-scene cold/runtime wall timing separately. The hard per-call
	# completion bound is invariant even under CPU-cap suspension/first-use costs.
	# The rendered host regression enforces the actual gameplay slice ceiling.
	rows.append({"cabinet_id": machine.cabinet_id, "cold_surface_usec": cold_surface_usec, "max_projection_slice_usec": max_slice_usec, "frames": frames, "recommended_holds": expected_holds, "mask_checks": scores.size(), "completion_count": game._strategy_hint_last_completed.get("completed_samples", 0)})
