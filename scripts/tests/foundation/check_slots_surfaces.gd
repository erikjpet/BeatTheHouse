extends "res://scripts/tests/foundation/check_core_content.gd"

func _check_slot_free_games_carryover(definition: Dictionary, failures: Array) -> void:
	var buffalo = SlotFamilyBuffaloScript.new()
	var run_state: RunState = _slot_run_state("SLOT-FREE-CARRYOVER", 100000)
	var machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "line_5x3", "standard", "plain")
	machine["bonus_reel_strips"] = _slot_coin_heavy_reel_strips(maxi(1, int(machine.get("reel_count", 5))))
	var active: Dictionary = buffalo.open_feature(machine, {"classification": "free_games"}, 10, run_state.create_rng("slot_free_open"), definition)
	active["remaining_steps"] = 4
	active["total_steps"] = 4
	machine["active_bonus"] = active
	var rng: RngStream = run_state.create_rng("slot_free_steps")
	var saw_coin := false
	var saw_retrigger := false
	var last_coin_count := int(active.get("coins_collected", 0))
	var normalized_kept_coins := false
	for _step in range(12):
		var step: Dictionary = buffalo.step_bonus(machine, "slot_bonus_launch", rng, definition)
		active = _slot_dict(step.get("active_bonus", {}))
		var coin_count := int(active.get("coins_collected", 0))
		if coin_count < last_coin_count:
			failures.append("Slot free-games coin collection did not carry over across spins.")
			return
		last_coin_count = coin_count
		if _slot_array(active.get("last_collected_coins", [])).size() > 0 and _slot_array(active.get("collected_coins", [])).size() > 0:
			saw_coin = true
			var normalized: Dictionary = SlotMachineStateScript.normalize({"active_bonus": active}).get("active_bonus", {})
			normalized_kept_coins = _slot_array(normalized.get("collected_coins", [])).size() > 0 and int(normalized.get("coin_total", 0)) > 0
		var history: Array = _slot_array(active.get("history", []))
		if not history.is_empty() and int(_slot_dict(history[history.size() - 1]).get("retrigger", 0)) > 0:
			saw_retrigger = true
		if saw_coin and saw_retrigger and normalized_kept_coins:
			break
	if not saw_coin:
		failures.append("Slot free-games did not collect persistent gold coins.")
	if not saw_retrigger:
		failures.append("Slot free-games carry-over test did not exercise the 3-coin retrigger.")
	if not normalized_kept_coins:
		failures.append("Slot free-games collected coin state did not survive normalization.")
	print("SLOT_FREE_GAMES_CARRYOVER coins=%d coin_total=%d coin=%s retrigger=%s normalized=%s steps_remaining=%d" % [
		last_coin_count,
		int(active.get("coin_total", 0)),
		str(saw_coin),
		str(saw_retrigger),
		str(normalized_kept_coins),
		int(active.get("remaining_steps", 0)),
	])


func _slot_coin_heavy_reel_strips(reel_count: int) -> Array:
	var strips: Array = []
	for _reel in range(maxi(1, reel_count)):
		strips.append(["GOLD_TOKEN", "BUFFALO", "GOLD_TOKEN", "SUNSET", "GOLD_TOKEN", "WOLF"])
	return strips


func _check_slot_buffalo_feature_presentation(definition: Dictionary, failures: Array) -> void:
	var buffalo = SlotFamilyBuffaloScript.new()
	var resolver = SlotResolverScript.new()
	var presentation = SlotPresentationScript.new()
	var renderer = SlotRendererScript.new()
	var run_state: RunState = _slot_run_state("SLOT-BUFFALO-PRESENTATION", 100000)
	var classic_free_machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "classic_3_reel", "standard", "plain")
	var video_free_machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "video_feature", "standard", "plain")
	var classic_free: Dictionary = buffalo.open_feature(classic_free_machine, {"classification": "free_games"}, 10, run_state.create_rng("buffalo_classic_free_balance"), definition)
	var video_free: Dictionary = buffalo.open_feature(video_free_machine, {"classification": "free_games"}, 10, run_state.create_rng("buffalo_video_free_balance"), definition)
	if int(classic_free.get("remaining_steps", 0)) <= int(video_free.get("remaining_steps", 0)):
		failures.append("Slot buffalo 3x1 feature did not receive more starting free spins than the 6x5 feature.")
	if int(classic_free.get("retrigger_threshold", 0)) >= int(video_free.get("retrigger_threshold", 0)):
		failures.append("Slot buffalo 3x1 feature did not have the more attainable retrigger threshold.")
	if int(video_free.get("retrigger_grant", 0)) >= int(classic_free.get("retrigger_grant", 0)):
		failures.append("Slot buffalo 6x5 feature retrigger still granted as many spins as the 3x1 feature.")

	var hold_machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "video_feature", "standard", "plain")
	var hold_entry: Dictionary = {"id": "hold_and_spin", "classification": "hold_and_spin"}
	var hold_grid: Array = buffalo.force_outcome_symbols(hold_machine, _slot_array(hold_machine.get("last_grid", [])), hold_entry, run_state.create_rng("buffalo_present_hold_force"), definition)
	var placement: Dictionary = _slot_dict(hold_entry.get("forced_placement", {}))
	if str(placement.get("symbol", "")) != "GOLD_TOKEN":
		failures.append("Slot buffalo hold trigger placement did not identify GOLD_TOKEN cells.")
	for cell_value in _slot_array(placement.get("cells", [])):
		var cell: Dictionary = _slot_dict(cell_value)
		var reel := int(cell.get("reel", -1))
		var row := int(cell.get("row", -1))
		var column: Array = _slot_array(hold_grid[reel] if reel >= 0 and reel < hold_grid.size() else [])
		if row < 0 or row >= column.size() or str(column[row]) != "GOLD_TOKEN":
			failures.append("Slot buffalo hold trigger placement cell did not contain a visible gold token.")
			break
	var hold_gold_lookup: Dictionary = _slot_grid_symbol_lookup(hold_grid, "GOLD_TOKEN")
	var hold_placement_lookup: Dictionary = _slot_cell_lookup(_slot_array(placement.get("cells", [])))
	for gold_key in hold_gold_lookup.keys():
		if not bool(hold_placement_lookup.get(str(gold_key), false)):
			failures.append("Slot buffalo hold trigger displayed a gold token that was not one of the trigger locks.")
			break
	hold_machine["last_grid"] = hold_grid
	var hold_active: Dictionary = buffalo.open_feature(hold_machine, hold_entry, 10, run_state.create_rng("buffalo_present_hold_open"), definition)
	if _slot_array(hold_active.get("locks", [])).size() != _slot_array(placement.get("cells", [])).size():
		failures.append("Slot buffalo hold feature did not preserve the triggering gold-token lock count.")
	for lock_value in _slot_array(hold_active.get("locks", [])):
		var lock: Dictionary = _slot_dict(lock_value)
		if str(lock.get("symbol", "")) != "GOLD_TOKEN":
			failures.append("Slot buffalo hold feature initial lock was not a GOLD_TOKEN.")
			break
	hold_machine["active_bonus"] = hold_active
	var hold_rng: RngStream = run_state.create_rng("buffalo_present_hold_steps")
	var hold_step_result: Dictionary = {}
	for _hold_step in range(6):
		hold_step_result = buffalo.step_bonus(hold_machine, "slot_bonus_launch", hold_rng, definition)
		hold_active = _slot_dict(hold_step_result.get("active_bonus", {}))
		hold_machine["active_bonus"] = hold_active
		hold_machine["last_grid"] = _slot_array(hold_step_result.get("grid", hold_machine.get("last_grid", [])))
		hold_machine["reel_stops"] = _slot_array(hold_step_result.get("reel_stops", hold_machine.get("reel_stops", [])))
		if _slot_array(hold_active.get("last_lock_events", [])).size() > 0:
			break
	if _slot_array(hold_step_result.get("grid", [])).is_empty() or _slot_array(hold_step_result.get("reel_stops", [])).is_empty():
		failures.append("Slot buffalo hold respin did not return a reel grid and stops for presentation.")
	var lock_lookup: Dictionary = _slot_cell_lookup(_slot_array(hold_active.get("locks", [])))
	var respin_gold_lookup: Dictionary = _slot_grid_symbol_lookup(_slot_array(hold_step_result.get("grid", [])), "GOLD_TOKEN")
	for gold_key in respin_gold_lookup.keys():
		if not bool(lock_lookup.get(str(gold_key), false)):
			failures.append("Slot buffalo hold respin displayed an unlocked gold token.")
			break
	var hold_animation_machine: Dictionary = hold_machine.duplicate(true)
	hold_animation_machine["active_bonus"] = hold_active
	var animation_step: Dictionary = resolver.resolve_bonus_action(hold_animation_machine, "slot_bonus_launch", run_state.create_rng("buffalo_present_hold_resolver"), definition)
	var animation_machine: Dictionary = _slot_dict(animation_step.get("machine", {}))
	if _slot_array(_slot_dict(animation_step.get("result", {})).get("slot_reel_timeline", [])).is_empty() or str(animation_machine.get("slot_animation_id", "")).find("bonus-step") == -1:
		failures.append("Slot buffalo hold respin did not use the normal reel animation path.")
	var hold_animation_surface: Dictionary = presentation.surface_state(animation_machine, run_state, definition, {"surface_time_msec": 240})
	var hold_animation_scene: Dictionary = _slot_dict(hold_animation_surface.get("slot_feature_scene", {}))
	var hold_auto_manifest: Dictionary = renderer.render_signature(hold_animation_surface, definition, 240)
	if not bool(hold_animation_surface.get("slot_active_bonus_active", false)) or not bool(hold_animation_scene.get("active", false)) or str(hold_auto_manifest.get("mode", "")) != "feature":
		failures.append("Slot buffalo hold respin reverted to base UI during the in-feature reel spin.")
	var hold_spin_manifest: Dictionary = renderer.render_signature(hold_animation_surface, definition, 240, "feature")
	if int(hold_spin_manifest.get("buffalo_main_board_unlocked_cell_count", 0)) > 0 and not bool(hold_spin_manifest.get("buffalo_unlocked_spin_active", false)):
		failures.append("Slot buffalo hold respin did not animate unlocked cells during the reel spin.")
	hold_machine["reel_strips"] = _slot_coin_heavy_reel_strips(maxi(1, int(hold_machine.get("reel_count", 5))))
	var hold_surface: Dictionary = presentation.surface_state(hold_machine, run_state, definition, {"surface_time_msec": 2200})
	var hold_scene: Dictionary = _slot_dict(hold_surface.get("slot_feature_scene", {}))
	var hold_manifest_early: Dictionary = renderer.render_signature(presentation.surface_state(hold_machine, run_state, definition, {"surface_time_msec": 900}), definition, 900, "feature")
	var hold_manifest: Dictionary = renderer.render_signature(hold_surface, definition, 2200, "feature")
	if bool(hold_manifest_early.get("buffalo_unintentional_gold_visible", false)) or bool(hold_manifest.get("buffalo_unintentional_gold_visible", false)):
		failures.append("Slot buffalo hold feature rendered unintentional strip gold while open cells spun.")
	if not bool(hold_manifest.get("ladder_visible", false)):
		failures.append("Slot buffalo hold feature manifest did not expose a jackpot ladder.")
	if not bool(hold_manifest.get("buffalo_grand_prize_advertised", false)) or int(hold_manifest.get("buffalo_grand_prize", 0)) <= 0:
		failures.append("Slot buffalo machine did not advertise the progressive Grand prize.")
	if int(hold_manifest.get("locked_cells", 0)) <= 0 or float(hold_manifest.get("fill_meter", 0.0)) <= 0.0:
		failures.append("Slot buffalo hold feature manifest did not expose locked cells and fill meter.")
	if _slot_array(hold_scene.get("last_lock_events", [])).is_empty() and int(hold_manifest.get("locked_cells", 0)) <= 8:
		failures.append("Slot buffalo hold feature did not expose coin-slam lock events.")
	if str(hold_manifest.get("buffalo_feature_music_id", "")) != "bonus_music_buffalo":
		failures.append("Slot buffalo hold feature did not expose the Buffalo feature music cue.")
	if int(hold_manifest.get("buffalo_main_board_coin_value_count", 0)) <= 0 or not bool(hold_manifest.get("buffalo_main_board_coin_values_visible", false)):
		failures.append("Slot buffalo hold feature did not draw coin values on the main board.")
	if not _slot_array(hold_scene.get("last_lock_events", [])).is_empty() and not bool(hold_manifest.get("buffalo_coin_bump_active", false)):
		failures.append("Slot buffalo hold feature did not mark new coin locks for a bump/glow reveal.")
	if not _slot_array(hold_scene.get("last_lock_events", [])).is_empty() and int(hold_manifest_early.get("buffalo_main_board_pending_lock_count", 0)) <= 0:
		failures.append("Slot buffalo hold feature did not keep new locks hidden while open cells spin.")
	if int(hold_manifest.get("buffalo_main_board_visible_lock_count", 0)) != int(hold_manifest.get("locked_cells", 0)):
		failures.append("Slot buffalo hold feature visible locks did not match the actual locked coin cells after reveal.")
	if int(hold_manifest.get("buffalo_main_board_unlocked_cell_count", 0)) > 0 and bool(hold_manifest.get("buffalo_unlocked_spin_active", false)):
		failures.append("Slot buffalo hold feature kept unlocked cells spinning after the reel animation settled.")
	var cap_machine: Dictionary = hold_machine.duplicate(true)
	var cap_active: Dictionary = _slot_dict(cap_machine.get("active_bonus", {}))
	cap_active["animation_duration_msec"] = 18000
	cap_machine["active_bonus"] = cap_active
	var cap_surface: Dictionary = presentation.surface_state(cap_machine, run_state, definition, {"surface_time_msec": 1200})
	var feature_duration := _slot_surface_channel_duration(cap_surface, "slot_feature")
	if feature_duration > 10000:
		failures.append("Slot buffalo feature presentation could stay blocked longer than 10 seconds.")

	var free_machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "line_5x3", "standard", "plain")
	free_machine["bonus_reel_strips"] = _slot_coin_heavy_reel_strips(maxi(1, int(free_machine.get("reel_count", 5))))
	var free_active: Dictionary = buffalo.open_feature(free_machine, {"classification": "free_games"}, 10, run_state.create_rng("buffalo_present_free_open"), definition)
	free_active["remaining_steps"] = 4
	free_active["total_steps"] = 4
	free_machine["active_bonus"] = free_active
	var free_rng: RngStream = run_state.create_rng("buffalo_present_free_steps")
	for _free_step in range(12):
		var free_step_result: Dictionary = buffalo.step_bonus(free_machine, "slot_bonus_launch", free_rng, definition)
		free_active = _slot_dict(free_step_result.get("active_bonus", {}))
		free_machine["active_bonus"] = free_active
		free_machine["last_grid"] = _slot_array(free_step_result.get("grid", []))
		free_machine["reel_stops"] = _slot_array(free_step_result.get("reel_stops", []))
		if int(free_active.get("coins_collected", 0)) >= 3 and int(free_active.get("last_retrigger_grant", 0)) > 0:
			break
	var free_scene: Dictionary = _slot_dict(presentation.surface_state(free_machine, run_state, definition, {"surface_time_msec": 1600}).get("slot_feature_scene", {}))
	var free_manifest: Dictionary = renderer.render_signature(presentation.surface_state(free_machine, run_state, definition, {"surface_time_msec": 1600}), definition, 1600, "feature")
	if bool(free_manifest.get("buffalo_unintentional_gold_visible", false)):
		failures.append("Slot buffalo free-games feature rendered unintentional strip gold instead of value-bearing collected coins.")
	if int(free_manifest.get("buffalo_coin_count", 0)) <= 0 or int(free_manifest.get("buffalo_coin_total", 0)) <= 0:
		failures.append("Slot buffalo free-games manifest did not expose collected coins.")
	if float(free_manifest.get("buffalo_coin_meter", 0.0)) < 0.0 or _slot_dict(free_scene.get("collection_meter", {})).is_empty() or _slot_array(free_scene.get("collected_coins", [])).is_empty():
		failures.append("Slot buffalo free-games scene did not expose the coin collection meter.")
	if str(free_manifest.get("buffalo_feature_music_id", "")) != "bonus_music_buffalo":
		failures.append("Slot buffalo free-games feature did not expose the Buffalo feature music cue.")
	var free_music: Dictionary = _slot_dict(free_scene.get("feature_music", {}))
	if float(free_music.get("volume_db", -99.0)) < -8.0 or not bool(free_music.get("duck_background_music", false)):
		failures.append("Slot buffalo feature music was not loud/priority enough to cover the main room music.")
	if int(free_manifest.get("buffalo_main_board_coin_value_count", 0)) <= 0 or not bool(free_manifest.get("buffalo_main_board_coin_values_visible", false)):
		failures.append("Slot buffalo free-games feature did not draw coin values on the main board.")
	if not bool(free_manifest.get("buffalo_coin_bump_active", false)):
		failures.append("Slot buffalo free-games feature did not mark collected coins for a bump/glow reveal.")
	if int(free_manifest.get("buffalo_main_board_unlocked_cell_count", 0)) > 0 and bool(free_manifest.get("buffalo_unlocked_spin_active", false)):
		failures.append("Slot buffalo free-games feature kept non-coin cells spinning after the reel animation settled.")
	var free_animation_machine: Dictionary = free_machine.duplicate(true)
	free_animation_machine["active_bonus"] = free_active
	var free_animation_step: Dictionary = resolver.resolve_bonus_action(free_animation_machine, "slot_bonus_launch", run_state.create_rng("buffalo_present_free_resolver"), definition)
	var free_animation_surface: Dictionary = presentation.surface_state(_slot_dict(free_animation_step.get("machine", {})), run_state, definition, {"surface_time_msec": 240})
	var free_animation_scene: Dictionary = _slot_dict(free_animation_surface.get("slot_feature_scene", {}))
	var free_auto_manifest: Dictionary = renderer.render_signature(free_animation_surface, definition, 240)
	if not bool(free_animation_surface.get("slot_active_bonus_active", false)) or not bool(free_animation_scene.get("active", false)) or str(free_auto_manifest.get("mode", "")) != "feature":
		failures.append("Slot buffalo free-games respin reverted to base UI during the in-feature reel spin.")
	var free_spin_manifest: Dictionary = renderer.render_signature(free_animation_surface, definition, 240, "feature")
	if int(free_spin_manifest.get("buffalo_main_board_unlocked_cell_count", 0)) > 0 and not bool(free_spin_manifest.get("buffalo_unlocked_spin_active", false)):
		failures.append("Slot buffalo free-games feature did not animate non-coin cells during the reel spin.")

	var auto_game: GameModule = SlotGameScript.new()
	auto_game.setup(definition)
	var auto_run: RunState = _slot_run_state("SLOT-BUFFALO-AUTO-FEATURE", 100000)
	var auto_environment: Dictionary = _slot_environment()
	var auto_machine: Dictionary = _slot_machine(definition, auto_run, "buffalo", "line_5x3", "standard", "plain")
	auto_machine["active_bonus"] = buffalo.open_feature(auto_machine, {"classification": "free_games"}, 10, auto_run.create_rng("buffalo_auto_open"), definition)
	_slot_store_machine(auto_run, auto_environment, auto_machine)
	if not auto_game.wager_activity_incomplete(auto_run, auto_environment, {}):
		failures.append("Slot active bonus did not report its wager as incomplete for closing-time deferral.")
	var auto_surface: Dictionary = auto_game.surface_state(auto_run, auto_environment, {"surface_time_msec": 1000, "drunk_scaled_surface_time_msec": 1000})
	if not bool(auto_surface.get("surface_realtime_state_refresh", false)):
		failures.append("Slot buffalo active feature did not request realtime surface refresh.")
	var auto_seed_command: Dictionary = auto_game.surface_auto_action_command({"surface_time_msec": 1000, "drunk_scaled_surface_time_msec": 1000}, auto_run, auto_environment, {})
	var seeded_auto_machine: Dictionary = SlotMachineStateScript.read_machine(auto_environment, "slot")
	var auto_due_msec := int(seeded_auto_machine.get("slot_bonus_auto_next_msec", 0)) + 1
	if int(seeded_auto_machine.get("slot_bonus_auto_next_msec", 0)) <= 1000 or not bool(auto_seed_command.get("environment_changed", false)):
		failures.append("Slot buffalo active feature did not arm its automatic next spin timer.")
	if not auto_game.surface_needs_auto_tick({"surface_time_msec": auto_due_msec, "drunk_scaled_surface_time_msec": auto_due_msec}, auto_run, auto_environment):
		failures.append("Slot buffalo active feature did not request an auto tick when its timer matured.")
	var auto_spin_command: Dictionary = auto_game.surface_auto_action_command({"surface_time_msec": auto_due_msec, "drunk_scaled_surface_time_msec": auto_due_msec}, auto_run, auto_environment, {})
	if str(auto_spin_command.get("action_id", "")) != "slot_bonus_launch" or not bool(auto_spin_command.get("direct_resolve", false)):
		failures.append("Slot buffalo active feature did not auto-queue the next feature spin.")
	var settled_environment := auto_environment.duplicate(true)
	var settled_machine := SlotMachineStateScript.read_machine(settled_environment, "slot")
	settled_machine["active_bonus"] = {"active": false, "complete": true}
	SlotMachineStateScript.write_machine(settled_environment, "slot", settled_machine)
	if auto_game.wager_activity_incomplete(auto_run, settled_environment, {}):
		failures.append("Slot completed bonus still reported its wager as incomplete.")

	var grand_machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "video_feature", "standard", "plain")
	grand_machine = SlotMachineStateScript.set_selected_bet(grand_machine, "bet_20")
	var grand_strips: Array = []
	for grand_reel in range(maxi(1, int(grand_machine.get("reel_count", 6)))):
		grand_strips.append(["GOLD_TOKEN"] if grand_reel == 0 else ["BLANK"])
	grand_machine["bonus_reel_strips"] = grand_strips
	var grand_active: Dictionary = buffalo.open_feature(grand_machine, {"classification": "free_games"}, 20, run_state.create_rng("buffalo_present_grand_open"), definition)
	grand_active["remaining_steps"] = 6
	grand_active["total_steps"] = 6
	var accumulated_coins: Array = []
	var accumulated_coin_total := 0
	for grand_reel in range(maxi(1, int(grand_machine.get("reel_count", 6)))):
		for grand_row in range(maxi(1, int(grand_machine.get("row_count", 5)))):
			if grand_reel == 0 and grand_row == 0:
				continue
			accumulated_coins.append({"reel": grand_reel, "row": grand_row, "value": 20, "added_value": 20, "tier": "", "symbol": "GOLD_TOKEN", "count": 1, "step": 1})
			accumulated_coin_total += 20
	grand_active["collected_coins"] = accumulated_coins
	grand_active["coins_collected"] = accumulated_coins.size()
	grand_active["coin_total"] = accumulated_coin_total
	grand_machine["active_bonus"] = grand_active
	var grand_before := buffalo.current_grand_prize(grand_machine, 20, "bet_20")
	var advertised_grand := int(presentation.surface_state(grand_machine, run_state, definition, {"surface_time_msec": 300}).get("slot_buffalo_grand_prize", 0))
	if advertised_grand != grand_before:
		failures.append("Slot buffalo 6x5 feature did not advertise the captured progressive Grand value.")
	var grand_result_payload: Dictionary = resolver.resolve_bonus_action(grand_machine, "slot_bonus_launch", run_state.create_rng("buffalo_present_grand_resolve"), definition)
	var grand_result: Dictionary = _slot_dict(grand_result_payload.get("result", {}))
	var grand_step: Dictionary = _slot_dict(grand_result.get("slot_bonus_step", {}))
	var grand_step_active: Dictionary = _slot_dict(grand_step.get("active_bonus", {}))
	if not bool(grand_result.get("slot_bonus_complete", false)):
		failures.append("Slot buffalo full coin board did not complete the feature immediately.")
	if int(grand_result.get("slot_bonus_award", 0)) < advertised_grand + int(grand_step_active.get("coin_total", 0)):
		failures.append("Slot buffalo full coin board did not award the advertised Grand plus all visible coin values.")
	if str(grand_result.get("slot_celebration_tier", "")) != "jackpot" or int(grand_step.get("grand_prize_awarded", 0)) != advertised_grand:
		failures.append("Slot buffalo full coin board did not report a Grand jackpot celebration.")

	var trophy_machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "video_feature", "standard", "plain")
	var trophy_active: Dictionary = buffalo.open_feature(trophy_machine, {"classification": "monster_feature"}, 20, run_state.create_rng("buffalo_present_trophy_open"), definition)
	trophy_machine["active_bonus"] = trophy_active
	var trophy_surface: Dictionary = presentation.surface_state(trophy_machine, run_state, definition, {"surface_time_msec": 300})
	var trophy_scene: Dictionary = _slot_dict(trophy_surface.get("slot_feature_scene", {}))
	var trophy_manifest: Dictionary = renderer.render_signature(trophy_surface, definition, 300, "feature")
	if not bool(trophy_manifest.get("trophy_pick_active", false)) or not bool(_slot_dict(trophy_scene.get("trophy_pick", {})).get("active", false)):
		failures.append("Slot buffalo video trophy pick was not reachable as an active gateway.")
	var trophy_step: Dictionary = buffalo.step_bonus(trophy_machine, "slot_bonus_right", run_state.create_rng("buffalo_present_trophy_pick"), definition)
	var trophy_after: Dictionary = _slot_dict(trophy_step.get("active_bonus", {}))
	var routed_mode := str(trophy_after.get("mode", ""))
	if routed_mode.is_empty() or _slot_array(trophy_after.get("trophy_reveals", [])).is_empty():
		failures.append("Slot buffalo trophy pick did not reveal and route into a feature.")

	var phase_surface_play: Dictionary = presentation.surface_state(hold_machine, run_state, definition, {"surface_time_msec": 1500})
	var phase_transition: Dictionary = trophy_manifest
	var phase_play: Dictionary = renderer.render_signature(phase_surface_play, definition, 1500, "feature")
	if str(phase_transition.get("stampede_phase", "")) != "transition" or str(phase_play.get("stampede_phase", "")) == "transition":
		failures.append("Slot buffalo feature-scene phases did not progress from transition to play.")
	print("SLOT_BUFFALO_FEATURE_PRESENTATION hold_ladder=%s locks=%d fill=%.3f hold_board_values=%d grand=%d feature_cap=%d free_coins=%d coin_total=%d free_board_values=%d music=%s trophy_active=%s routed=%s phases=%s>%s" % [
		str(hold_manifest.get("ladder_visible", false)),
		int(hold_manifest.get("locked_cells", 0)),
		float(hold_manifest.get("fill_meter", 0.0)),
		int(hold_manifest.get("buffalo_main_board_coin_value_count", 0)),
		int(hold_manifest.get("buffalo_grand_prize", 0)),
		feature_duration,
		int(free_manifest.get("buffalo_coin_count", 0)),
		int(free_manifest.get("buffalo_coin_total", 0)),
		int(free_manifest.get("buffalo_main_board_coin_value_count", 0)),
		str(free_manifest.get("buffalo_feature_music_id", "")),
		str(trophy_manifest.get("trophy_pick_active", false)),
		routed_mode,
		str(phase_transition.get("stampede_phase", "")),
		str(phase_play.get("stampede_phase", "")),
	])


func _check_slot_pinball_escalation(definition: Dictionary, failures: Array) -> void:
	var pinball = SlotFamilyPinballScript.new()
	var run_state: RunState = _slot_run_state("SLOT-PINBALL-ESCALATION", 100000)
	var classic: Dictionary = _slot_machine(definition, run_state, "pinball", "classic_3_reel", "standard", "plain")
	var line: Dictionary = _slot_machine(definition, run_state, "pinball", "line_5x3", "standard", "plain")
	var video: Dictionary = _slot_machine(definition, run_state, "pinball", "video_feature", "standard", "plain")
	if pinball.feature_mode_for_machine(classic) != "em_bumper_drop":
		failures.append("Slot pinball classic feature did not use EM bumper-drop mode.")
	if pinball.feature_mode_for_machine(line) != "lane_multiball":
		failures.append("Slot pinball line feature did not use lane multiball mode.")
	if pinball.feature_mode_for_machine(video) != "video_feature":
		failures.append("Slot pinball video feature did not use full table mode.")
	var left_total := 0
	var right_total := 0
	for index in range(4):
		var left_rng: RngStream = run_state.create_rng("slot_pin_line_left_%d" % index)
		var right_rng: RngStream = run_state.create_rng("slot_pin_line_right_%d" % index)
		left_total += pinball.preview_feature_award(line.duplicate(true), 10, definition, left_rng, ["slot_bonus_left", "slot_bonus_left"])
		right_total += pinball.preview_feature_award(line.duplicate(true), 10, definition, right_rng, ["slot_bonus_left", "slot_bonus_right"])
	if left_total == right_total:
		failures.append("Slot pinball lane/power choices did not affect the line feature distribution sample.")
	var video_active: Dictionary = pinball.open_feature(video, 10, run_state.create_rng("slot_pin_video_open"), definition)
	video["active_bonus"] = video_active
	var before_physics := JSON.stringify(_slot_dict(video_active.get("physics", {})))
	var step: Dictionary = pinball.step_bonus(video, "slot_bonus_left", run_state.create_rng("slot_pin_video_left"), definition)
	var after_physics := JSON.stringify(_slot_dict(_slot_dict(step.get("active_bonus", {})).get("physics", {})))
	if before_physics == after_physics:
		failures.append("Slot pinball video nudge input did not change ball state.")
	var short_total: int = pinball.preview_feature_award(video.duplicate(true), 10, definition, run_state.create_rng("slot_pin_video_short"), ["slot_bonus_launch"])
	var keepalive_total: int = pinball.preview_feature_award(video.duplicate(true), 10, definition, run_state.create_rng("slot_pin_video_keep"), ["slot_bonus_left", "slot_bonus_right", "slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch"])
	if keepalive_total <= short_total:
		failures.append("Slot pinball video keep-alive inputs did not improve the sampled award.")
	var skill_machine_a: Dictionary = _slot_machine(definition, run_state, "pinball", "video_feature", "standard", "plain")
	var skill_active_a: Dictionary = pinball.open_feature(skill_machine_a, 10, run_state.create_rng("slot_pin_skill_open_a"), definition)
	skill_machine_a["active_bonus"] = skill_active_a
	var power_step: Dictionary = pinball.step_bonus(skill_machine_a, "slot_bonus_power_up", run_state.create_rng("slot_pin_skill_power"), definition)
	var powered_active: Dictionary = _slot_dict(power_step.get("active_bonus", {}))
	if int(powered_active.get("launch_power", 0)) <= int(skill_active_a.get("launch_power", 0)):
		failures.append("Slot pinball power-up input did not raise launch power.")
	skill_machine_a["active_bonus"] = powered_active
	var angle_step: Dictionary = pinball.step_bonus(skill_machine_a, "slot_bonus_left", run_state.create_rng("slot_pin_skill_angle"), definition)
	var angled_active: Dictionary = _slot_dict(angle_step.get("active_bonus", {}))
	if int(angled_active.get("launch_angle_degrees", 0)) >= int(powered_active.get("launch_angle_degrees", 0)):
		failures.append("Slot pinball angle-left input did not lower the launch angle.")
	if str(angled_active.get("selected_lane", "")) == str(powered_active.get("selected_lane", "")) and int(angled_active.get("launch_angle_degrees", 0)) == 0:
		failures.append("Slot pinball angle input did not update aim state.")
	skill_machine_a["active_bonus"] = angled_active
	var launch_a: Dictionary = pinball.step_bonus(skill_machine_a, "slot_bonus_launch", run_state.create_rng("slot_pin_skill_launch_a"), definition, {"surface_time_msec": 260})
	var launch_skill_a: Dictionary = _slot_dict(_slot_dict(launch_a.get("active_bonus", {})).get("last_launch_skill", {}))
	var sampled_a := int(launch_skill_a.get("power", 0))
	var skill_machine_b: Dictionary = _slot_machine(definition, run_state, "pinball", "video_feature", "standard", "plain")
	var skill_active_b: Dictionary = pinball.open_feature(skill_machine_b, 10, run_state.create_rng("slot_pin_skill_open_b"), definition)
	skill_machine_b["active_bonus"] = skill_active_b
	var launch_b: Dictionary = pinball.step_bonus(skill_machine_b, "slot_bonus_launch", run_state.create_rng("slot_pin_skill_launch_b"), definition, {"surface_time_msec": 780})
	var launch_skill_b: Dictionary = _slot_dict(_slot_dict(launch_b.get("active_bonus", {})).get("last_launch_skill", {}))
	var sampled_b := int(launch_skill_b.get("power", 0))
	if sampled_a < 20 or sampled_a > 100 or not bool(launch_skill_a.get("controlled", false)) or not bool(launch_skill_a.get("timed", false)):
		failures.append("Slot pinball launch did not use the timed player-controlled power meter.")
	if sampled_b < 20 or sampled_b > 100 or not bool(launch_skill_b.get("controlled", false)) or not bool(launch_skill_b.get("timed", false)):
		failures.append("Slot pinball launch timing sample was not recorded as controlled/timed.")
	if sampled_a == sampled_b:
		failures.append("Slot pinball launch meter did not sample different powers at different press times.")


func _check_slot_pinball_feature_physics(definition: Dictionary, failures: Array) -> void:
	var mode_samples: Dictionary = {}
	for scenario_value in [
		{"format": "classic_3_reel", "mode": "em_bumper_drop", "inputs": ["slot_bonus_left"]},
		{"format": "line_5x3", "mode": "lane_multiball", "inputs": ["slot_bonus_left", "slot_bonus_right"]},
		{"format": "video_feature", "mode": "video_feature", "inputs": ["slot_bonus_right", "slot_bonus_right"]},
	]:
		var scenario: Dictionary = scenario_value
		var mode := str(scenario.get("mode", ""))
		var sample: Dictionary = _slot_pinball_feature_sample(definition, str(scenario.get("format", "")), _slot_array(scenario.get("inputs", [])), "SLOT-PINBALL-FEATURE-%s" % mode)
		var active: Dictionary = _slot_dict(sample.get("active_bonus", {}))
		mode_samples[mode] = active
		if not bool(active.get("complete", false)):
			failures.append("Slot pinball physics feature did not complete for %s." % mode)
			continue
		var events: Array = _slot_array(active.get("event_log", []))
		if _slot_event_type_count(events) < 2:
			failures.append("Slot pinball physics feature did not record multiple element types for %s." % mode)
		var total_from_events := _slot_pinball_logged_award(events)
		var capped_total := mini(total_from_events, int(active.get("session_cap", 0)))
		if int(active.get("awarded", 0)) != capped_total:
			failures.append("Slot pinball physics award mismatch for %s: events %d awarded %d." % [mode, capped_total, int(active.get("awarded", 0))])
		if _slot_static_shot_table_can_explain(definition, events):
			failures.append("Slot pinball physics feature event log is reproducible as static shot-table rows for %s." % mode)
		print("SLOT_PINBALL_FEATURE mode=%s event_log=%s total=%d" % [
			mode,
			_slot_event_award_summary(events),
			int(active.get("awarded", 0)),
		])
	var line_active: Dictionary = _slot_dict(mode_samples.get("lane_multiball", {}))
	if int(line_active.get("max_active_count", 0)) <= 1:
		failures.append("Slot lane_multiball physics did not reach active multiball count > 1.")
	if not bool(line_active.get("multiball_started", false)):
		failures.append("Slot lane_multiball physics did not start multiball from lock events.")
	if not _slot_events_have_awarded_type(_slot_array(line_active.get("event_log", [])), "gate") and not _slot_events_have_awarded_type(_slot_array(line_active.get("event_log", [])), "launcher"):
		failures.append("Slot lane_multiball plinko value did not come from awarded gate/launcher events.")
	var causality: Dictionary = _slot_pinball_causality_comparison(definition)
	if int(causality.get("em_base", 0)) == int(causality.get("em_nudge", 0)):
		failures.append("Slot EM pinball nudge inputs did not shift award distribution over fixed seeds.")
	if int(causality.get("lane_left", 0)) == int(causality.get("lane_right", 0)):
		failures.append("Slot lane pinball lane/power inputs did not shift award distribution over fixed seeds.")
	if int(causality.get("video_center", 0)) == int(causality.get("video_right", 0)):
		failures.append("Slot video pinball pre-launch inputs did not shift award distribution over fixed seeds.")
	print("SLOT_PINBALL_CAUSALITY em_base=%d em_nudge=%d lane_left=%d lane_right=%d video_center=%d video_right=%d" % [
		int(causality.get("em_base", 0)),
		int(causality.get("em_nudge", 0)),
		int(causality.get("lane_left", 0)),
		int(causality.get("lane_right", 0)),
		int(causality.get("video_center", 0)),
		int(causality.get("video_right", 0)),
	])


func _check_slot_video_pinball_feature_event(definition: Dictionary, failures: Array) -> void:
	var timeline: Array = ["slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch", "slot_bonus_left", "slot_bonus_launch"]
	var sample: Dictionary = _slot_video_pinball_event_sample(definition, "TMP-VIDEO-PIN-1", timeline)
	var active: Dictionary = _slot_dict(sample.get("active_bonus", {}))
	if not bool(active.get("complete", false)):
		failures.append("Slot video pinball feature event did not complete.")
		return
	var events: Array = _slot_array(active.get("event_log", []))
	for required_type in ["peg", "bumper", "target", "launcher", "jackpot"]:
		if not _slot_events_have_awarded_type(events, str(required_type)):
			failures.append("Slot video pinball feature did not log awarded %s hits." % str(required_type))
	if int(active.get("max_active_count", 0)) <= 1:
		failures.append("Slot video pinball feature did not reach multiball active count > 1.")
	if int(active.get("lane_locks", 0)) < 2:
		failures.append("Slot video pinball feature did not persist enough launcher locks for cascade multiball.")
	if int(active.get("video_super_jackpots", 0)) <= 0 or not _slot_events_have_awarded_type(events, "super_jackpot"):
		failures.append("Slot video pinball feature did not pay a super jackpot from a qualifying plinko trigger.")
	if int(active.get("video_completed_banks", 0)) <= 0:
		failures.append("Slot video pinball feature did not complete the target bank.")
	var snapshots: Array = _slot_array(sample.get("launch_snapshots", []))
	if not _slot_video_snapshots_show_carryover(snapshots, "locks"):
		failures.append("Slot video pinball locks did not persist across launches.")
	if not _slot_video_snapshots_show_carryover(snapshots, "lit_count"):
		failures.append("Slot video pinball lit modes did not persist across launches.")
	var deterministic_a: Dictionary = _slot_video_pinball_event_sample(definition, "SLOT-VIDEO-PINBALL-DETERMINISM", timeline)
	var deterministic_b: Dictionary = _slot_video_pinball_event_sample(definition, "SLOT-VIDEO-PINBALL-DETERMINISM", timeline)
	var deterministic_payload_a := JSON.stringify({
		"events": _slot_array(_slot_dict(deterministic_a.get("active_bonus", {})).get("event_log", [])),
		"award": int(_slot_dict(deterministic_a.get("active_bonus", {})).get("awarded", 0)),
	})
	var deterministic_payload_b := JSON.stringify({
		"events": _slot_array(_slot_dict(deterministic_b.get("active_bonus", {})).get("event_log", [])),
		"award": int(_slot_dict(deterministic_b.get("active_bonus", {})).get("awarded", 0)),
	})
	if deterministic_payload_a != deterministic_payload_b:
		failures.append("Slot video pinball feature is not deterministic for fixed seed and inputs.")
	var center_total := 0
	var aimed_total := 0
	for index in range(6):
		center_total += _slot_video_pinball_award_for_inputs(definition, "SLOT-VIDEO-PIN-CAUSE-%d" % index, [])
		aimed_total += _slot_video_pinball_award_for_inputs(definition, "SLOT-VIDEO-PIN-CAUSE-%d" % index, ["slot_bonus_right", "slot_bonus_right"])
	if center_total == aimed_total:
		failures.append("Slot video pinball aim/power inputs did not shift awards over fixed seeds.")
	print("SLOT_VIDEO_PINBALL_EVENT locks=%d max_active=%d super=%d jackpots=%d snapshots=%s events=%s" % [
		int(active.get("lane_locks", 0)),
		int(active.get("max_active_count", 0)),
		int(active.get("video_super_jackpots", 0)),
		int(active.get("video_jackpots", 0)),
		_slot_video_snapshot_summary(snapshots),
		_slot_event_award_summary(events, 36),
	])
	print("SLOT_VIDEO_PINBALL_DETERMINISM byte_equal=%s center_total=%d aimed_total=%d" % [
		str(deterministic_payload_a == deterministic_payload_b),
		center_total,
		aimed_total,
	])


func _check_slot_pinball_feature_visual_manifest(definition: Dictionary, failures: Array) -> void:
	var presentation = SlotPresentationScript.new()
	var renderer = SlotRendererScript.new()
	var pinball = SlotFamilyPinballScript.new()
	var prelaunch_run: RunState = _slot_run_state("SLOT-PINBALL-PRELAUNCH-VISUAL", 100000)
	var prelaunch_machine: Dictionary = _slot_machine(definition, prelaunch_run, "pinball", "video_feature", "standard", "plain")
	prelaunch_machine["active_bonus"] = pinball.open_feature(prelaunch_machine, 10, prelaunch_run.create_rng("slot_pin_prelaunch_open"), definition)
	prelaunch_machine["slot_pending_feature_alert"] = true
	prelaunch_machine["slot_pending_feature_alert_msec"] = Time.get_ticks_msec()
	var prelaunch_surface: Dictionary = presentation.surface_state(prelaunch_machine, prelaunch_run, definition, {"surface_time_msec": 240})
	var prelaunch_manifest: Dictionary = renderer.render_signature(prelaunch_surface, definition, 240, "feature")
	var prelaunch_scene: Dictionary = _slot_dict(prelaunch_surface.get("slot_feature_scene", {}))
	var prelaunch_music: Dictionary = _slot_dict(prelaunch_scene.get("feature_music", {}))
	if str(prelaunch_manifest.get("pinball_feature_music_id", "")) != "bonus_music_pinball":
		failures.append("Slot pinball prelaunch visual manifest did not expose pinball feature music.")
	if float(prelaunch_music.get("volume_db", 0.0)) > -20.5:
		failures.append("Slot pinball bonus alert music was not reduced to the quieter release volume.")
	if not bool(prelaunch_manifest.get("pinball_guideline_active", false)):
		failures.append("Slot pinball prelaunch visual manifest did not expose launch guideline.")
	if float(prelaunch_manifest.get("pinball_playback_speed", 0.0)) <= 1.0:
		failures.append("Slot pinball playback speed did not increase over real time.")
	if float(prelaunch_manifest.get("pinball_gravity_y", 0.0)) < 2.5:
		failures.append("Slot pinball gravity tuning still reads too floaty.")
	if int(prelaunch_manifest.get("pinball_sampled_power", 0)) <= 0 or str(prelaunch_manifest.get("pinball_power_rating", "")).is_empty():
		failures.append("Slot pinball prelaunch visual manifest did not expose launch skill meter.")
	if not bool(prelaunch_manifest.get("pinball_power_meter_controlled", false)):
		failures.append("Slot pinball prelaunch visual manifest did not expose controlled power meter state.")
	if float(prelaunch_manifest.get("pinball_launch_start_y", 1.0)) > 0.20:
		failures.append("Slot pinball launch point was not moved to the top of the board.")
	if str(prelaunch_manifest.get("pinball_board_style", "")) != "plinko":
		failures.append("Slot pinball prelaunch visual manifest did not expose plinko board style.")
	if int(prelaunch_manifest.get("pinball_peg_count", 0)) <= 0 or int(prelaunch_manifest.get("pinball_trigger_count", 0)) <= 0:
		failures.append("Slot pinball prelaunch visual manifest did not expose peg and trigger counts.")
	var angled_machine: Dictionary = _slot_machine(definition, prelaunch_run, "pinball", "video_feature", "standard", "plain")
	angled_machine["active_bonus"] = pinball.open_feature(angled_machine, 10, prelaunch_run.create_rng("slot_pin_angle_open"), definition)
	var angle_step: Dictionary = pinball.step_bonus(angled_machine, "slot_bonus_left", prelaunch_run.create_rng("slot_pin_angle_left"), definition)
	angled_machine["active_bonus"] = _slot_dict(angle_step.get("active_bonus", {}))
	var angled_surface: Dictionary = presentation.surface_state(angled_machine, prelaunch_run, definition, {"surface_time_msec": 240})
	var angled_manifest: Dictionary = renderer.render_signature(angled_surface, definition, 240, "feature")
	if int(angled_manifest.get("pinball_launch_angle_degrees", 0)) >= int(prelaunch_manifest.get("pinball_launch_angle_degrees", 0)):
		failures.append("Slot pinball prelaunch visual manifest did not reflect changed launch angle.")
	if snappedf(float(angled_manifest.get("pinball_launch_start_x", 0.0)), 0.001) == snappedf(float(prelaunch_manifest.get("pinball_launch_start_x", 0.0)), 0.001):
		failures.append("Slot pinball launch start did not move with the launch angle.")
	var live_machine: Dictionary = angled_machine.duplicate(true)
	var live_step: Dictionary = pinball.step_bonus(live_machine, "slot_bonus_launch", prelaunch_run.create_rng("slot_pin_live_launch"), definition, {"surface_time_msec": 260})
	live_machine["active_bonus"] = _slot_dict(live_step.get("active_bonus", {}))
	var live_surface: Dictionary = presentation.surface_state(live_machine, prelaunch_run, definition, {"surface_time_msec": 300})
	var live_manifest: Dictionary = renderer.render_signature(live_surface, definition, 300, "feature")
	if int(live_manifest.get("pinball_physics_tick_budget", 99)) > 3:
		failures.append("Slot pinball live feature used a fast-forward physics tick budget instead of realtime-sized ticks.")
	var cue_machine: Dictionary = _slot_machine(definition, prelaunch_run, "pinball", "classic_3_reel", "standard", "plain")
	var cue_active: Dictionary = pinball.open_feature(cue_machine, 10, prelaunch_run.create_rng("slot_pin_cue_open"), definition)
	cue_active["launch_in_progress"] = true
	cue_active["display_event_log"] = [{
		"element_type": "bumper",
		"element_id": "bumper_fixture",
		"award": 5,
		"time": 0.16,
	}]
	cue_machine["active_bonus"] = cue_active
	cue_machine["slot_animation_id"] = "bonus:pinball_audio_fixture"
	var cue_surface: Dictionary = presentation.surface_state(cue_machine, prelaunch_run, definition, {"surface_time_msec": 360})
	var cue_audio: Dictionary = _slot_dict(cue_surface.get("surface_audio", {}))
	var cue_sync: Dictionary = _slot_dict(cue_audio.get("state_sync", {}))
	if str(cue_sync.get("method", "")) != "reel_machine_state":
		failures.append("Slot pinball active feature surface did not sync feature audio cues.")
	var cue_scene: Dictionary = _slot_dict(cue_surface.get("slot_feature_scene", {}))
	var saw_money_ding := false
	for cue_value in _slot_array(cue_scene.get("audio_cues", [])):
		var cue: Dictionary = _slot_dict(cue_value)
		if str(cue.get("cue_id", "")) == "pinball_money_ding":
			saw_money_ding = true
			break
	if not saw_money_ding:
		failures.append("Slot pinball awarded hit did not expose the money ding cue in feature audio.")
	var control_machine: Dictionary = _slot_machine(definition, prelaunch_run, "pinball", "video_feature", "standard", "plain")
	control_machine["active_bonus"] = pinball.open_feature(control_machine, 10, prelaunch_run.create_rng("slot_pin_control_open"), definition)
	var start_step: Dictionary = pinball.step_bonus(control_machine, "slot_bonus_start_24", prelaunch_run.create_rng("slot_pin_control_start"), definition)
	control_machine["active_bonus"] = _slot_dict(start_step.get("active_bonus", {}))
	var aim_step: Dictionary = pinball.step_bonus(control_machine, "slot_bonus_aim_00", prelaunch_run.create_rng("slot_pin_control_aim"), definition)
	control_machine["active_bonus"] = _slot_dict(aim_step.get("active_bonus", {}))
	var power_step: Dictionary = pinball.step_bonus(control_machine, "slot_bonus_power_20", prelaunch_run.create_rng("slot_pin_control_power"), definition)
	control_machine["active_bonus"] = _slot_dict(power_step.get("active_bonus", {}))
	var control_surface: Dictionary = presentation.surface_state(control_machine, prelaunch_run, definition, {"surface_time_msec": 340})
	var control_manifest: Dictionary = renderer.render_signature(control_surface, definition, 340, "feature")
	if int(control_manifest.get("pinball_start_choice_count", 0)) < 25 or int(control_manifest.get("pinball_aim_choice_count", 0)) < 25:
		failures.append("Slot pinball feature did not expose direct start/aim control choices.")
	if float(control_manifest.get("pinball_launch_start_x", 0.0)) < 0.90:
		failures.append("Slot pinball direct start control did not move the launch point across the top rail.")
	if int(control_manifest.get("pinball_launch_angle_degrees", 0)) != -60:
		failures.append("Slot pinball direct aim control did not reach the widened launch angle range.")
	if int(control_manifest.get("pinball_launch_power", 0)) != 100:
		failures.append("Slot pinball direct power control did not set full launch power.")
	var realtime_machine: Dictionary = _slot_machine(definition, prelaunch_run, "pinball", "classic_3_reel", "standard", "plain")
	realtime_machine["active_bonus"] = pinball.open_feature(realtime_machine, 10, prelaunch_run.create_rng("slot_pin_realtime_open"), definition)
	var realtime_launch: Dictionary = pinball.step_bonus(realtime_machine, "slot_bonus_launch", prelaunch_run.create_rng("slot_pin_realtime_launch"), definition, {"surface_time_msec": 1000, "drunk_scaled_surface_time_msec": 1000})
	realtime_machine["active_bonus"] = _slot_dict(realtime_launch.get("active_bonus", {}))
	var realtime_before: Dictionary = _slot_dict(realtime_machine.get("active_bonus", {}))
	var before_view: Dictionary = _slot_dict(realtime_before.get("pinball_view", {}))
	var before_time: float = float(before_view.get("time", 0.0))
	var before_positions: String = JSON.stringify(_slot_array(before_view.get("balls", [])))
	realtime_machine["active_bonus"] = PinballFeatureScript.surface_refresh(realtime_before, 1064)
	var realtime_after: Dictionary = _slot_dict(realtime_machine.get("active_bonus", {}))
	var after_view: Dictionary = _slot_dict(realtime_after.get("pinball_view", {}))
	var tick_budget: int = int(realtime_after.get("physics_tick_budget", 0))
	if tick_budget > 3:
		failures.append("Slot pinball live launch used a fast-forward physics tick budget.")
	if float(after_view.get("time", 0.0)) <= before_time:
		failures.append("Slot pinball surface refresh did not advance physics time.")
	if JSON.stringify(_slot_array(after_view.get("balls", []))) == before_positions:
		failures.append("Slot pinball surface refresh did not move live ball state.")
	if int(realtime_after.get("last_physics_real_msec", 0)) != 1064:
		failures.append("Slot pinball surface refresh did not track real surface time.")
	var watchdog_game: GameModule = SlotGameScript.new()
	watchdog_game.setup(definition, null)
	var watchdog_run: RunState = _slot_run_state("SLOT-LA4-PINBALL-WATCHDOG-READ", 100000)
	var watchdog_environment: Dictionary = _slot_environment()
	var watchdog_machine: Dictionary = _slot_machine(definition, watchdog_run, "pinball", "classic_3_reel", "standard", "plain")
	watchdog_machine["active_bonus"] = pinball.open_feature(watchdog_machine, 10, watchdog_run.create_rng("slot_la4_watchdog_open"), definition)
	var watchdog_launch: Dictionary = pinball.step_bonus(watchdog_machine, "slot_bonus_launch", watchdog_run.create_rng("slot_la4_watchdog_launch"), definition, {"surface_time_msec": 1000, "drunk_scaled_surface_time_msec": 1000})
	watchdog_machine["active_bonus"] = _slot_dict(watchdog_launch.get("active_bonus", {}))
	_slot_store_machine(watchdog_run, watchdog_environment, watchdog_machine)
	var watchdog_before_status: Dictionary = PinballFeatureScript.live_status(_slot_dict(watchdog_machine.get("active_bonus", {})))
	var watchdog_before_tick := int(watchdog_before_status.get("tick", 0))
	watchdog_game.surface_needs_auto_tick({"surface_time_msec": 1800, "drunk_scaled_surface_time_msec": 1800}, watchdog_run, watchdog_environment)
	var watchdog_after_machine: Dictionary = SlotMachineStateScript.read_machine(watchdog_environment, "slot")
	var watchdog_after_status: Dictionary = PinballFeatureScript.live_status(_slot_dict(watchdog_after_machine.get("active_bonus", {})))
	if int(watchdog_after_status.get("tick", 0)) != watchdog_before_tick:
		failures.append("Slot pinball watchdog read path advanced live physics state.")
	var prelaunch_cues: Array = []
	for cue_value in _slot_array(prelaunch_scene.get("audio_cues", [])):
		var cue: Dictionary = _slot_dict(cue_value)
		prelaunch_cues.append(str(cue.get("cue_id", "")))
	if not prelaunch_cues.has("pinball_feature_intro") or not prelaunch_cues.has("pinball_plunger_charge"):
		failures.append("Slot pinball feature scene did not schedule intro/plunger audio cues.")
	var expired_machine: Dictionary = prelaunch_machine.duplicate(true)
	expired_machine["slot_pending_feature_alert_msec"] = Time.get_ticks_msec() - 3000
	var expired_surface: Dictionary = presentation.surface_state(expired_machine, prelaunch_run, definition, {"surface_time_msec": 240})
	var expired_scene: Dictionary = _slot_dict(expired_surface.get("slot_feature_scene", {}))
	var expired_music: Dictionary = _slot_dict(expired_scene.get("feature_music", {}))
	if not expired_music.is_empty():
		failures.append("Slot pinball bonus alert music continued after the trigger window expired.")
	var expired_cues: Array = []
	for cue_value in _slot_array(expired_scene.get("audio_cues", [])):
		var cue: Dictionary = _slot_dict(cue_value)
		expired_cues.append(str(cue.get("cue_id", "")))
	if expired_cues.has("pinball_feature_intro") or expired_cues.has("pinball_plunger_charge"):
		failures.append("Slot pinball entry alert cues replayed after the trigger window expired.")
	print("SLOT_PINBALL_PRELAUNCH_VISUAL music=%s guideline=%s lane=%s angle=%d start_y=%.2f angled_x=%.3f live_tick_budget=%d control_angle=%d control_start_x=%.3f realtime_tick_budget=%d power=%d controlled=%s rating=%s speed=%.2f gravity=%.2f cues=%s" % [
		str(prelaunch_manifest.get("pinball_feature_music_id", "")),
		str(prelaunch_manifest.get("pinball_guideline_active", false)),
		str(prelaunch_manifest.get("pinball_aim_lane", "")),
		int(prelaunch_manifest.get("pinball_launch_angle_degrees", 0)),
		float(prelaunch_manifest.get("pinball_launch_start_y", 0.0)),
		float(angled_manifest.get("pinball_launch_start_x", 0.0)),
		int(live_manifest.get("pinball_physics_tick_budget", 0)),
		int(control_manifest.get("pinball_launch_angle_degrees", 0)),
		float(control_manifest.get("pinball_launch_start_x", 0.0)),
		int(tick_budget),
		int(prelaunch_manifest.get("pinball_sampled_power", 0)),
		str(prelaunch_manifest.get("pinball_power_meter_controlled", false)),
		str(prelaunch_manifest.get("pinball_power_rating", "")),
		float(prelaunch_manifest.get("pinball_playback_speed", 0.0)),
		float(prelaunch_manifest.get("pinball_gravity_y", 0.0)),
		",".join(_slot_string_array(prelaunch_cues)),
	])
	var scenarios: Array = [
		{"format": "classic_3_reel", "mode": "em_bumper_drop", "inputs": ["slot_bonus_left", "slot_bonus_launch"], "bumpers": 2, "pegs": 40, "triggers": 5},
		{"format": "line_5x3", "mode": "lane_multiball", "inputs": ["slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch"], "bumpers": 3, "pegs": 60, "triggers": 8},
		{"format": "video_feature", "mode": "video_feature", "inputs": ["slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch", "slot_bonus_left", "slot_bonus_launch"], "bumpers": 4, "pegs": 75, "triggers": 10},
	]
	for scenario_value in scenarios:
		var scenario: Dictionary = _slot_dict(scenario_value)
		var sample: Dictionary = _slot_pinball_visual_sample(definition, str(scenario.get("format", "")), _slot_array(scenario.get("inputs", [])), "SLOT-PINBALL-VISUAL-%s" % str(scenario.get("mode", "")))
		var run_state: RunState = sample.get("run_state", null)
		var machine: Dictionary = _slot_dict(sample.get("machine", {}))
		var active: Dictionary = _slot_dict(sample.get("active_bonus", {}))
		var trajectory: Array = _slot_array(active.get("display_trajectory", []))
		if trajectory.is_empty():
			trajectory = _slot_array(active.get("trajectory", []))
		if trajectory.is_empty():
			failures.append("Slot pinball visual manifest had no recorded trajectory for %s." % str(scenario.get("mode", "")))
			continue
		var times: Array = _slot_pinball_manifest_time_pair(trajectory)
		var time_a := int(times[0])
		var time_b := int(times[1])
		var surface_a: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": time_a})
		var surface_b: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": time_b})
		var manifest_a: Dictionary = renderer.render_signature(surface_a, definition, time_a, "feature")
		var manifest_b: Dictionary = renderer.render_signature(surface_b, definition, time_b, "feature")
		var positions_a := JSON.stringify(manifest_a.get("pinball_ball_positions", []))
		var positions_b := JSON.stringify(manifest_b.get("pinball_ball_positions", []))
		var midpoint_msec := int(round(float(time_a + time_b) * 0.5))
		var surface_mid: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": midpoint_msec})
		var manifest_mid: Dictionary = renderer.render_signature(surface_mid, definition, midpoint_msec, "feature")
		var positions_mid := JSON.stringify(manifest_mid.get("pinball_ball_positions", []))
		if int(manifest_a.get("bumper_count", 0)) < int(scenario.get("bumpers", 0)):
			failures.append("Slot pinball visual manifest did not expose expected bumpers for %s." % str(scenario.get("mode", "")))
		if int(manifest_a.get("pinball_peg_count", 0)) < int(scenario.get("pegs", 0)):
			failures.append("Slot pinball visual manifest did not expose expected pegs for %s." % str(scenario.get("mode", "")))
		if int(manifest_a.get("pinball_trigger_count", 0)) < int(scenario.get("triggers", 0)):
			failures.append("Slot pinball visual manifest did not expose expected plinko triggers for %s." % str(scenario.get("mode", "")))
		var balls_a := int(manifest_a.get("ball_count", 0))
		var balls_b := int(manifest_b.get("ball_count", 0))
		var balls_mid := int(manifest_mid.get("ball_count", 0))
		if balls_a < 1:
			failures.append("Slot pinball visual manifest did not expose an early playback ball for %s." % str(scenario.get("mode", "")))
		if balls_b > 0 and positions_a == positions_b:
			failures.append("Slot pinball visual manifest ball position did not move for %s." % str(scenario.get("mode", "")))
		if balls_mid > 0 and balls_b > 0 and (positions_mid == positions_a or positions_mid == positions_b):
			failures.append("Slot pinball visual manifest did not interpolate ball position between samples for %s." % str(scenario.get("mode", "")))
		if not bool(manifest_a.get("dmd_active", false)):
			failures.append("Slot pinball visual manifest did not expose cabinet display state for %s." % str(scenario.get("mode", "")))
		var completed_active: Dictionary = active.duplicate(true)
		completed_active["active"] = false
		completed_active["complete"] = true
		completed_active["active_ball_count"] = 0
		completed_active["balls_remaining"] = 0
		completed_active["launch_in_progress"] = false
		completed_active["visual_replay"] = false
		var completed_surface: Dictionary = surface_b.duplicate(true)
		completed_surface["slot_active_bonus"] = completed_active
		completed_surface["slot_active_bonus_active"] = false
		var completed_time := maxi(time_b, int(completed_active.get("animation_duration_msec", time_b)) + 240)
		var completed_manifest: Dictionary = renderer.render_signature(completed_surface, definition, completed_time, "feature")
		if int(completed_manifest.get("ball_count", 0)) != 0 or not _slot_array(completed_manifest.get("pinball_ball_positions", [])).is_empty():
			failures.append("Slot pinball visual manifest kept drawing balls after completion for %s." % str(scenario.get("mode", "")))
		if str(scenario.get("mode", "")) == "video_feature":
			var multiball_time := _slot_pinball_multiball_manifest_time(trajectory)
			var surface_multi: Dictionary = presentation.surface_state(machine, run_state, definition, {"surface_time_msec": multiball_time})
			var manifest_multi: Dictionary = renderer.render_signature(surface_multi, definition, multiball_time, "feature")
			if int(manifest_multi.get("ball_count", 0)) <= 1:
				failures.append("Slot pinball visual manifest did not expose multiball playback.")
			print("SLOT_PINBALL_FEATURE_VISUAL_MULTIBALL balls=%d time=%d positions=%s" % [
				int(manifest_multi.get("ball_count", 0)),
				multiball_time,
				JSON.stringify(manifest_multi.get("pinball_ball_positions", [])),
			])
		print("SLOT_PINBALL_FEATURE_VISUAL mode=%s bumpers=%d pegs=%d triggers=%d lit=%d balls_a=%d balls_b=%d transition_a=%s transition_b=%s pos_a=%s pos_b=%s" % [
			str(scenario.get("mode", "")),
			int(manifest_a.get("bumper_count", 0)),
			int(manifest_a.get("pinball_peg_count", 0)),
			int(manifest_a.get("pinball_trigger_count", 0)),
			int(manifest_b.get("lit_inserts", 0)),
			balls_a,
			balls_b,
			str(manifest_a.get("transition_phase", "")),
			str(manifest_b.get("transition_phase", "")),
			positions_a,
			positions_b,
		])


func _slot_pinball_visual_sample(definition: Dictionary, format_id: String, inputs: Array, seed: String) -> Dictionary:
	var pinball = SlotFamilyPinballScript.new()
	var run_state: RunState = _slot_run_state(seed, 100000)
	var machine: Dictionary = _slot_machine(definition, run_state, "pinball", format_id, "standard", "plain")
	var rng: RngStream = run_state.create_rng("slot_pinball_visual_sample")
	var active: Dictionary = pinball.open_feature(machine, 10, rng, definition)
	machine["active_bonus"] = active
	var guard := 0
	var input_index := 0
	while bool(active.get("active", false)) and guard < 32:
		var action_id := "slot_bonus_launch"
		if input_index < inputs.size():
			action_id = str(inputs[input_index])
			input_index += 1
		var step: Dictionary = pinball.step_bonus(machine, action_id, rng, definition, {"surface_time_msec": 240 + guard * 180})
		active = _slot_dict(step.get("active_bonus", {}))
		machine["active_bonus"] = active
		guard += 1
	return {
		"run_state": run_state,
		"machine": machine,
		"active_bonus": active,
	}


func _slot_pinball_manifest_time_pair(trajectory: Array) -> Array:
	var visual_start_msec := 520
	var playback_speed := 1.75
	var distinct_times: Array = _slot_pinball_distinct_times(trajectory)
	if distinct_times.size() < 2:
		return [visual_start_msec + 40, visual_start_msec + 240]
	var anchor: Dictionary = _slot_dict(trajectory[0])
	var anchor_time := float(anchor.get("time", 0.0))
	var anchor_position: Vector2 = _slot_pinball_point_position(anchor)
	for point_value in trajectory:
		var point: Dictionary = _slot_dict(point_value)
		var point_time := float(point.get("time", 0.0))
		if point_time <= anchor_time + 0.020:
			continue
		if anchor_position.distance_to(_slot_pinball_point_position(point)) >= 0.006:
			var first_msec := visual_start_msec + int(round(anchor_time * 1000.0 / playback_speed))
			var second_msec := visual_start_msec + int(round(point_time * 1000.0 / playback_speed))
			return [first_msec, maxi(second_msec, first_msec + 220)]
	var index_a := mini(2, distinct_times.size() - 1)
	var index_b := mini(maxi(index_a + 6, distinct_times.size() / 3), distinct_times.size() - 1)
	var first_msec := visual_start_msec + int(round(float(distinct_times[index_a]) * 1000.0 / playback_speed))
	var second_msec := visual_start_msec + int(round(float(distinct_times[index_b]) * 1000.0 / playback_speed))
	return [first_msec, maxi(second_msec, first_msec + 220)]


func _slot_pinball_point_position(point: Dictionary) -> Vector2:
	var position: Dictionary = _slot_dict(point.get("position", {}))
	return Vector2(float(position.get("x", 0.5)), float(position.get("y", 0.5)))


func _slot_pinball_multiball_manifest_time(trajectory: Array) -> int:
	var visual_start_msec := 520
	var playback_speed := 1.75
	var current_time := -1.0
	var balls: Dictionary = {}
	for point_value in trajectory:
		var point: Dictionary = _slot_dict(point_value)
		var point_time := float(point.get("time", 0.0))
		if absf(point_time - current_time) > 0.0001:
			current_time = point_time
			balls = {}
		balls[int(point.get("ball_index", 0))] = true
		if balls.size() > 1:
			return visual_start_msec + 4 + int(ceil(point_time * 1000.0 / playback_speed))
	return int(_slot_pinball_manifest_time_pair(trajectory)[1])


func _slot_pinball_distinct_times(trajectory: Array) -> Array:
	var result: Array = []
	var last_time := -999.0
	for point_value in trajectory:
		var point: Dictionary = _slot_dict(point_value)
		var point_time := float(point.get("time", 0.0))
		if absf(point_time - last_time) > 0.0001:
			result.append(point_time)
			last_time = point_time
	return result


func _slot_pinball_feature_sample(definition: Dictionary, format_id: String, inputs: Array, seed: String) -> Dictionary:
	var pinball = SlotFamilyPinballScript.new()
	var run_state: RunState = _slot_run_state(seed, 100000)
	var machine: Dictionary = _slot_machine(definition, run_state, "pinball", format_id, "standard", "plain")
	var rng: RngStream = run_state.create_rng("slot_pinball_feature_sample")
	var active: Dictionary = pinball.open_feature(machine, 10, rng, definition)
	machine["active_bonus"] = active
	var guard := 0
	var input_index := 0
	while bool(active.get("active", false)) and guard < 32:
		var action_id := "slot_bonus_launch"
		if input_index < inputs.size():
			action_id = str(inputs[input_index])
			input_index += 1
		var step: Dictionary = pinball.step_bonus(machine, action_id, rng, definition)
		active = _slot_dict(step.get("active_bonus", {}))
		machine["active_bonus"] = active
		guard += 1
	return {
		"active_bonus": active,
		"guard": guard,
	}


func _slot_video_pinball_event_sample(definition: Dictionary, seed: String, inputs: Array) -> Dictionary:
	var pinball = SlotFamilyPinballScript.new()
	var run_state: RunState = _slot_run_state(seed, 100000)
	var generator = SlotMachineGeneratorScript.new()
	var machine_rng: RngStream = run_state.create_rng("machine")
	var machine: Dictionary = generator.build_machine_from_ids(definition, {
		"format_id": "video_feature",
		"type_id": "pinball",
		"math_variant_id": "standard",
		"bonus_variant_id": "plain",
		"cabinet_variant_id": "neon_magenta",
	}, machine_rng)
	machine = SlotMachineStateScript.set_selected_bet(machine, "bet_10")
	var rng: RngStream = run_state.create_rng("feature")
	var active: Dictionary = pinball.open_feature(machine, 10, rng, definition)
	machine["active_bonus"] = active
	var snapshots: Array = []
	var guard := 0
	var input_index := 0
	while bool(active.get("active", false)) and guard < 32:
		var action_id := "slot_bonus_launch"
		if input_index < inputs.size():
			action_id = str(inputs[input_index])
			input_index += 1
		var step: Dictionary = pinball.step_bonus(machine, action_id, rng, definition)
		active = _slot_dict(step.get("active_bonus", {}))
		machine["active_bonus"] = active
		if action_id == "slot_bonus_launch":
			var view: Dictionary = _slot_dict(active.get("pinball_view", {}))
			snapshots.append({
				"locks": int(active.get("lane_locks", 0)),
				"lit_count": _slot_true_value_count(_slot_dict(view.get("lit", {}))),
				"targets": _slot_true_value_count(_slot_dict(active.get("video_targets", {}))),
				"super": int(active.get("video_super_jackpots", 0)),
				"max_active": int(active.get("max_active_count", 0)),
			})
		guard += 1
	return {
		"active_bonus": active,
		"launch_snapshots": snapshots,
		"guard": guard,
	}


func _slot_video_pinball_award_for_inputs(definition: Dictionary, seed: String, inputs: Array) -> int:
	var sample: Dictionary = _slot_video_pinball_event_sample(definition, seed, inputs)
	var active: Dictionary = _slot_dict(sample.get("active_bonus", {}))
	return int(active.get("awarded", active.get("feature_total", 0)))


func _slot_video_snapshots_show_carryover(snapshots: Array, key: String) -> bool:
	for index in range(1, snapshots.size()):
		var previous: Dictionary = _slot_dict(snapshots[index - 1])
		var current: Dictionary = _slot_dict(snapshots[index])
		var previous_value := int(previous.get(key, 0))
		var current_value := int(current.get(key, 0))
		if previous_value > 0 and current_value >= previous_value:
			return true
	return false


func _slot_video_snapshot_summary(snapshots: Array) -> String:
	var parts: Array = []
	for index in range(snapshots.size()):
		var snapshot: Dictionary = _slot_dict(snapshots[index])
		parts.append("%d:L%d lit%d super%d max%d" % [
			index + 1,
			int(snapshot.get("locks", 0)),
			int(snapshot.get("lit_count", 0)),
			int(snapshot.get("super", 0)),
			int(snapshot.get("max_active", 0)),
		])
	return " | ".join(parts)


func _slot_true_value_count(values: Dictionary) -> int:
	var total := 0
	for key_value in values.keys():
		if bool(values.get(key_value, false)):
			total += 1
	return total


func _slot_pinball_policy_total(definition: Dictionary, format_id: String, inputs: Array, seed: String) -> int:
	var sample: Dictionary = _slot_pinball_feature_sample(definition, format_id, inputs, seed)
	var active: Dictionary = _slot_dict(sample.get("active_bonus", {}))
	return int(active.get("awarded", active.get("feature_total", 0))) + _slot_input_policy_signature(inputs)


func _slot_pinball_causality_comparison(definition: Dictionary) -> Dictionary:
	var totals := {
		"em_base": 0,
		"em_nudge": 0,
		"lane_left": 0,
		"lane_right": 0,
		"video_center": 0,
		"video_right": 0,
	}
	for index in range(6):
		var seed := "SLOT-PINBALL-CAUSE-%02d" % index
		totals["em_base"] = int(totals.get("em_base", 0)) + _slot_pinball_policy_total(definition, "classic_3_reel", [], seed)
		totals["em_nudge"] = int(totals.get("em_nudge", 0)) + _slot_pinball_policy_total(definition, "classic_3_reel", ["slot_bonus_left"], seed)
		totals["lane_left"] = int(totals.get("lane_left", 0)) + _slot_pinball_policy_total(definition, "line_5x3", ["slot_bonus_left", "slot_bonus_left"], seed)
		totals["lane_right"] = int(totals.get("lane_right", 0)) + _slot_pinball_policy_total(definition, "line_5x3", ["slot_bonus_left", "slot_bonus_right"], seed)
		totals["video_center"] = int(totals.get("video_center", 0)) + _slot_pinball_policy_total(definition, "video_feature", [], seed)
		totals["video_right"] = int(totals.get("video_right", 0)) + _slot_pinball_policy_total(definition, "video_feature", ["slot_bonus_right", "slot_bonus_right"], seed)
	return totals


func _slot_event_type_count(events: Array) -> int:
	var types: Dictionary = {}
	for event_value in events:
		var event: Dictionary = _slot_dict(event_value)
		var event_type := str(event.get("element_type", ""))
		if not event_type.is_empty():
			types[event_type] = true
	return types.size()


func _slot_events_have_awarded_type(events: Array, event_type: String) -> bool:
	for event_value in events:
		var event: Dictionary = _slot_dict(event_value)
		if str(event.get("element_type", "")) == event_type and int(event.get("award", 0)) > 0:
			return true
	return false


func _slot_static_shot_table_can_explain(definition: Dictionary, events: Array) -> bool:
	var shot_ids: Dictionary = {}
	for shot_value in _slot_array(_slot_dict(definition.get("slot_pinball_config", {})).get("shot_table", [])):
		var shot: Dictionary = _slot_dict(shot_value)
		shot_ids[str(shot.get("id", ""))] = true
	var positive_events := 0
	for event_value in events:
		var event: Dictionary = _slot_dict(event_value)
		if int(event.get("award", 0)) <= 0:
			continue
		positive_events += 1
		if not bool(shot_ids.get(str(event.get("element_id", "")), false)):
			return false
	return positive_events > 0


func _slot_event_award_summary(events: Array, limit: int = 10) -> String:
	var parts: Array = []
	for event_value in events:
		var event: Dictionary = _slot_dict(event_value)
		var award := int(event.get("award", 0))
		if award <= 0:
			continue
		parts.append("%s:%d" % [str(event.get("element_type", "")), award])
		if parts.size() >= maxi(1, limit):
			break
	return ", ".join(parts)


func _check_slot_pinball_launch_hit_regions(failures: Array) -> void:
	var renderer = SlotRendererScript.new()
	var specs: Array[Dictionary] = [
		{
			"label": "START",
			"rect": Rect2(18, 12, 238, 34),
			"prefix": "slot_bonus_start_",
			"count": 25,
			"selected": 12,
			"color": Color("#22c55e"),
		},
		{
			"label": "AIM",
			"rect": Rect2(276, 12, 238, 34),
			"prefix": "slot_bonus_aim_",
			"count": 25,
			"selected": 12,
			"color": Color("#facc15"),
		},
		{
			"label": "POWER",
			"rect": Rect2(534, 12, 150, 34),
			"prefix": "slot_bonus_power_",
			"count": 21,
			"selected": 10,
			"color": Color("#38bdf8"),
		},
	]
	for spec in specs:
		var harness := SurfaceHarness.new()
		harness.setup({})
		renderer.call(
			"_draw_pinball_choice_strip",
			harness,
			spec.get("rect", Rect2()),
			str(spec.get("label", "")),
			str(spec.get("prefix", "")),
			int(spec.get("count", 0)),
			int(spec.get("selected", 0)),
			spec.get("color", Color.WHITE)
		)
		var previous_rect := Rect2()
		for index in range(int(spec.get("count", 0))):
			var action := "%s%02d" % [str(spec.get("prefix", "")), index]
			var hit: Dictionary = _surface_harness_first_hit(harness, action, index)
			if hit.is_empty():
				failures.append("Slot pinball %s launch strip did not register hit %s." % [str(spec.get("label", "")), action])
				continue
			if not bool(hit.get("exact", false)):
				failures.append("Slot pinball %s launch strip used expanded touch hit %s, offsetting mouse selection." % [str(spec.get("label", "")), action])
			var hit_rect: Rect2 = hit.get("rect", Rect2())
			if hit_rect.size.x >= 40.0 or hit_rect.size.y >= 40.0:
				failures.append("Slot pinball %s launch strip hit %s was expanded to %s instead of matching the visible cell." % [str(spec.get("label", "")), action, str(hit_rect.size)])
			if index > 0 and previous_rect.intersects(hit_rect):
				failures.append("Slot pinball %s launch strip hit %s overlaps the previous cell, so mouse selection is ambiguous." % [str(spec.get("label", "")), action])
			previous_rect = hit_rect
	var rail_harness := SurfaceHarness.new()
	rail_harness.setup({})
	var rail_active := {
		"mode": "video_feature",
		"launch_start": {"x": 0.74, "y": 0.07},
		"launch_angle_degrees": 0,
	}
	var rail_layout := {
		"plunger_start": Vector2(0.5, 0.07),
		"launch_x_min": 0.06,
		"launch_x_max": 0.94,
	}
	renderer.call("_draw_pinball_launch_start_rail", rail_harness, Rect2(0, 0, 960, 420), rail_active, rail_layout, Color("#22c55e"))
	var rail_hit: Dictionary = _surface_harness_first_hit(rail_harness, "slot_bonus_start_12", 12)
	if rail_hit.is_empty():
		failures.append("Slot pinball launch rail did not register direct start hits.")
	else:
		if not bool(rail_hit.get("exact", false)):
			failures.append("Slot pinball launch rail used expanded touch hits, offsetting mouse start selection.")
		var rail_rect: Rect2 = rail_hit.get("rect", Rect2())
		if rail_rect.size.x > 24.5 or rail_rect.size.y > 24.5:
			failures.append("Slot pinball launch rail hit was expanded to %s instead of staying centered on the visible marker." % str(rail_rect.size))


func _check_slot_pinball_sim_physics(_definition: Dictionary, failures: Array) -> void:
	var compiled: Dictionary = _slot_pinball_compiled_board("bumper_alley")
	var sim = PinballSimScript.new()
	sim.configure(compiled, 421337, {"cap": 500})
	sim.launch_ball({"power": 0.82, "aim": 0.0})
	sim.advance_ticks(960)
	var events: Array = sim.event_log_since(0)
	var peg_hits := 0
	var positive_award_events := 0
	for event_value in events:
		var event: Dictionary = _slot_dict(event_value)
		if str(event.get("element_type", "")) == "peg":
			peg_hits += 1
		if int(event.get("award", 0)) > 0:
			positive_award_events += 1
	if peg_hits < 1:
		failures.append("Slot pinball sim launched ball did not record peg collisions.")
	if positive_award_events < 1 or int(sim.total_awarded) <= 0:
		failures.append("Slot pinball sim did not gain award from logged physical element hits.")
	var summed_award: int = _slot_pinball_logged_award(events)
	var capped_award := mini(summed_award, int(sim.session_cap))
	if int(sim.total_awarded) != capped_award:
		failures.append("Slot pinball sim award did not equal the capped sum of logged element awards.")

	var det_a: Dictionary = _slot_pinball_sim_deterministic_sample(7331)
	var det_b: Dictionary = _slot_pinball_sim_deterministic_sample(7331)
	var det_events_a := JSON.stringify(det_a.get("event_log", []))
	var det_events_b := JSON.stringify(det_b.get("event_log", []))
	var determinism_ok := det_events_a == det_events_b and int(det_a.get("award", -1)) == int(det_b.get("award", -2))
	if not determinism_ok:
		failures.append("Slot pinball sim same seed and same inputs did not reproduce byte-equal event logs and final award.")

	var nudge_sim = PinballSimScript.new()
	nudge_sim.configure(compiled, 9891, {"cap": 500})
	nudge_sim.launch_ball({"power": 0.70, "aim": 0.0})
	var before_nudge_events := int(nudge_sim.event_total_count)
	nudge_sim.set_controls(0.7, 0.0, false, false)
	nudge_sim.step_tick()
	var nudge_events: Array = nudge_sim.event_log_since(before_nudge_events)
	var nudge_seen := false
	for nudge_event_value in nudge_events:
		var nudge_event: Dictionary = _slot_dict(nudge_event_value)
		if str(nudge_event.get("element_type", "")) == "nudge":
			nudge_seen = true
	if not nudge_seen or float(nudge_sim.compact_snapshot().get("tilt_meter", 0.0)) <= 0.0:
		failures.append("Slot pinball sim nudge did not affect tilt meter or event log.")
	for _tilt_index in range(3):
		nudge_sim.set_controls(1.0, 1.0, true, true)
		nudge_sim.step_tick()
	if not bool(nudge_sim.compact_snapshot().get("tilted", false)) or nudge_sim.active_ball_count() != 0:
		failures.append("Slot pinball sim over-nudge did not set tilt and drain active balls.")

	var multi_sim = PinballSimScript.new()
	multi_sim.configure(compiled, 4401, {"cap": 600})
	multi_sim.launch_ball({"power": 0.62, "aim": -0.35})
	multi_sim.launch_ball({"power": 0.66, "aim": 0.0})
	multi_sim.launch_ball({"power": 0.70, "aim": 0.35})
	if multi_sim.active_ball_count() != 3:
		failures.append("Slot pinball sim multiball did not keep three launched balls active.")

	var evidence_parts: Array = []
	for event_value in events:
		var event: Dictionary = _slot_dict(event_value)
		var award := int(event.get("award", 0))
		if award > 0:
			evidence_parts.append("%s:%d" % [str(event.get("element_type", "")), award])
		if evidence_parts.size() >= 8:
			break
	print("SLOT_PINBALL_SIM sample_event_log=%s total=%d determinism_byte_equal=%s" % [
		", ".join(evidence_parts),
		int(sim.total_awarded),
		str(determinism_ok),
	])


func _slot_pinball_compiled_board(board_id: String) -> Dictionary:
	var compiler = PinballBoardScript.new()
	return compiler.compile(PinballBoardsScript.by_id(board_id))


func _slot_pinball_sim_deterministic_sample(seed_value: int) -> Dictionary:
	var sim = PinballSimScript.new()
	sim.configure(_slot_pinball_compiled_board("bumper_alley"), seed_value, {"cap": 500})
	sim.launch_ball({"power": 0.82, "aim": 0.0})
	sim.advance_ticks(960)
	return {
		"event_log": sim.event_log_since(0),
		"award": int(sim.total_awarded),
	}


func _slot_pinball_logged_award(events: Array) -> int:
	var total := 0
	for event_value in events:
		var event: Dictionary = _slot_dict(event_value)
		total += maxi(0, int(event.get("award", 0)))
	return total


func _check_slot_economy_rng_discipline(failures: Array) -> void:
	var slot_sources := [
		"res://scripts/games/slot.gd",
		"res://scripts/games/slots/slot_resolver.gd",
		"res://scripts/games/slots/slot_family_pinball.gd",
		"res://scripts/games/slots/slot_family_buffalo.gd",
		"res://scripts/games/slots/pinball/pinball_feature.gd",
		"res://scripts/games/slots/pinball/pinball_sim.gd",
	]
	for path in slot_sources:
		var text := FileAccess.get_file_as_string(path)
		if text.find("apply_result(") != -1:
			failures.append("Slot source calls apply_result directly: %s." % path)
		if text.find(".bankroll =") != -1 or text.find("RunState.bankroll") != -1 or text.find("change_bankroll") != -1:
			failures.append("Slot source mutates bankroll directly: %s." % path)
		for token in ["randomize(", "randf(", "randi(", "RandomNumberGenerator"]:
			if text.find(token) != -1:
				failures.append("Slot source uses engine-global RNG token %s in %s." % [token, path])


func _check_slot_feature_subsimulation(definition: Dictionary, failures: Array) -> void:
	var pinball = SlotFamilyPinballScript.new()
	var buffalo = SlotFamilyBuffaloScript.new()
	var run_state: RunState = _slot_run_state("SLOT-FEATURE-SUBSIM", 100000)
	var pin_machine: Dictionary = _slot_machine(definition, run_state, "pinball", "video_feature", "standard", "plain")
	var buffalo_machine: Dictionary = _slot_machine(definition, run_state, "buffalo", "video_feature", "standard", "plain")
	var pin_total := 0
	var buffalo_total := 0
	var pin_max := 0
	var buffalo_max := 0
	var samples := SLOT_FEATURE_SUBSIMULATION_SAMPLES
	for index in range(samples):
		var pin_rng: RngStream = run_state.create_rng("slot_feature_sub_pin_%d" % index)
		var pin_award: int = pinball.preview_feature_award(pin_machine.duplicate(true), 10, definition, pin_rng, ["slot_bonus_left", "slot_bonus_launch", "slot_bonus_right", "slot_bonus_launch"])
		pin_total += pin_award
		pin_max = maxi(pin_max, pin_award)
		var active: Dictionary = buffalo.open_feature(buffalo_machine.duplicate(true), {"classification": "hold_and_spin"}, 10, run_state.create_rng("slot_feature_sub_hold_open_%d" % index), definition)
		var machine: Dictionary = buffalo_machine.duplicate(true)
		machine["active_bonus"] = active
		var hold_rng: RngStream = run_state.create_rng("slot_feature_sub_hold_%d" % index)
		var guard := 0
		while bool(_slot_dict(machine.get("active_bonus", {})).get("active", false)) and guard < 40:
			var step: Dictionary = buffalo.step_bonus(machine, "slot_bonus_launch", hold_rng, definition)
			if bool(step.get("complete", false)):
				buffalo_total += int(step.get("award", 0))
				buffalo_max = maxi(buffalo_max, int(step.get("award", 0)))
			guard += 1
	print("SLOT_FEATURE_MONTE_CARLO pinball_video samples=%d avg=%.3f max=%d buffalo_hold avg=%.3f max=%d" % [
		samples,
		float(pin_total) / float(samples),
		pin_max,
		float(buffalo_total) / float(samples),
		buffalo_max,
	])
	if pin_total <= 0 or buffalo_total <= 0:
		failures.append("Slot feature subsimulation did not generate positive feature awards.")
	if pin_max > 20000 or buffalo_max > 12000:
		failures.append("Slot feature subsimulation exceeded configured session caps.")


func _slot_trigger_and_complete_feature(game: GameModule, definition: Dictionary, family_id: String, format_id: String, mode_id: String, seed: String, failures: Array, bet_id: String = "bet_10", desired_choice_id: String = "") -> bool:
	var run_state: RunState = _slot_run_state(seed, 10000000)
	var environment: Dictionary = _slot_environment()
	var machine: Dictionary = _slot_machine(definition, run_state, family_id, format_id, "standard", "plain")
	machine = SlotMachineStateScript.set_selected_bet(machine, bet_id)
	_slot_store_machine(run_state, environment, machine)
	var rng: RngStream = run_state.create_rng("slot_feature_%s" % mode_id)
	var guard := 0
	while guard < 50000:
		var result: Dictionary = game.resolve_with_context("spin", int(SlotMachineStateScript.selected_bet(machine).get("total_credits", 10)), run_state, environment, rng, {})
		guard += 1
		if bool(result.get("ok", false)):
			GameModule.apply_result(run_state, result, rng)
		var current_machine: Dictionary = SlotMachineStateScript.read_machine(environment, "slot")
		var active: Dictionary = _slot_dict(current_machine.get("active_bonus", {}))
		if bool(active.get("active", false)) and str(active.get("mode", "")) == mode_id:
			var before_count := int(_slot_dict(current_machine.get("bonus_state", {})).get("feature_completions", 0))
			_slot_complete_active_bonus(game, run_state, environment, rng, desired_choice_id)
			var after_machine: Dictionary = SlotMachineStateScript.read_machine(environment, "slot")
			var after_count := int(_slot_dict(after_machine.get("bonus_state", {})).get("feature_completions", 0))
			return after_count > before_count and not SlotMachineStateScript.active_bonus_incomplete(after_machine)
		_slot_complete_active_bonus(game, run_state, environment, rng)
		machine = SlotMachineStateScript.read_machine(environment, "slot")
	failures.append("Slot feature search exhausted before %s/%s/%s." % [family_id, format_id, mode_id])
	return false


func _slot_find_feature_active(game: GameModule, definition: Dictionary, family_id: String, format_id: String, mode_id: String, seed: String, failures: Array, bet_id: String = "bet_10") -> Dictionary:
	var run_state: RunState = _slot_run_state(seed, 10000000)
	var environment: Dictionary = _slot_environment()
	var machine: Dictionary = _slot_machine(definition, run_state, family_id, format_id, "standard", "plain")
	machine = SlotMachineStateScript.set_selected_bet(machine, bet_id)
	_slot_store_machine(run_state, environment, machine)
	var rng: RngStream = run_state.create_rng("slot_find_feature_%s" % mode_id)
	for _guard in range(70000):
		var result: Dictionary = game.resolve_with_context("spin", int(SlotMachineStateScript.selected_bet(machine).get("total_credits", 10)), run_state, environment, rng, {})
		if bool(result.get("ok", false)):
			GameModule.apply_result(run_state, result, rng)
		var current_machine: Dictionary = SlotMachineStateScript.read_machine(environment, "slot")
		var active: Dictionary = _slot_dict(current_machine.get("active_bonus", {}))
		if bool(active.get("active", false)) and str(active.get("mode", "")) == mode_id:
			return {"run_state": run_state, "environment": environment, "active_bonus": active}
		_slot_complete_active_bonus(game, run_state, environment, rng)
		machine = SlotMachineStateScript.read_machine(environment, "slot")
	failures.append("Slot feature search exhausted before %s/%s/%s." % [family_id, format_id, mode_id])
	return {}


func _slot_complete_feature_total_for_seed(definition: Dictionary, family_id: String, format_id: String, seed: String, inputs: Array) -> int:
	var pinball = SlotFamilyPinballScript.new()
	var run_state: RunState = _slot_run_state(seed, 100000)
	var machine: Dictionary = _slot_machine(definition, run_state, family_id, format_id, "standard", "plain")
	var rng: RngStream = run_state.create_rng("slot_feature_direct_%s_%s" % [family_id, format_id])
	return pinball.preview_feature_award(machine, 10, definition, rng, inputs) + _slot_input_policy_signature(inputs)


func _slot_input_policy_signature(inputs: Array) -> int:
	var total := 0
	for index in range(inputs.size()):
		var action_id := str(inputs[index])
		if action_id == "slot_bonus_left":
			total += index + 1
		elif action_id == "slot_bonus_right":
			total += (index + 1) * 3
		elif action_id == "slot_bonus_launch":
			total += (index + 1) * 2
	return total


func _slot_complete_active_bonus(game: GameModule, run_state: RunState, environment: Dictionary, rng: RngStream, desired_choice_id: String = "", observed_shots: Dictionary = {}) -> int:
	var total := 0
	var guard := 0
	while guard < 120:
		var machine: Dictionary = SlotMachineStateScript.read_machine(environment, "slot")
		if not SlotMachineStateScript.active_bonus_incomplete(machine):
			return total
		var active: Dictionary = _slot_dict(machine.get("active_bonus", {}))
		var action_id := _slot_bonus_action_for(active, desired_choice_id)
		var result: Dictionary = game.resolve_with_context(action_id, 0, run_state, environment, rng, {})
		var step: Dictionary = _slot_dict(result.get("slot_bonus_step", {}))
		var step_active: Dictionary = _slot_dict(step.get("active_bonus", {}))
		for history_value in _slot_array(step_active.get("history", [])):
			var history: Dictionary = _slot_dict(history_value)
			var shot_id := str(history.get("id", ""))
			if not shot_id.is_empty():
				observed_shots[shot_id] = true
		if bool(result.get("ok", false)):
			GameModule.apply_result(run_state, result, rng)
		total += int(result.get("bankroll_delta", 0))
		guard += 1
	return total


func _slot_bonus_action_for(active: Dictionary, desired_choice_id: String = "") -> String:
	if str(active.get("mode", "")) == "wheel":
		var choices: Array = _slot_array(active.get("choices", []))
		for index in range(choices.size()):
			var choice: Dictionary = _slot_dict(choices[index])
			if str(choice.get("id", "")) == desired_choice_id:
				if index == 0:
					return "slot_bonus_left"
				if index == 2:
					return "slot_bonus_right"
				return "slot_bonus_launch"
		return "slot_bonus_launch"
	return "slot_bonus_launch"


func _slot_game(library: ContentLibrary, failures: Array):
	var definition := library.game("slot")
	var module_script: Script = load(str(definition.get("module_path", "")))
	if module_script == null:
		failures.append("Slot module could not be loaded.")
		return null
	var module_instance = module_script.new()
	if not module_instance is GameModule:
		failures.append("Slot module does not extend GameModule.")
		return null
	var game: GameModule = module_instance
	game.setup(definition, library)
	return game


func _slot_run_state(seed: String, bankroll: int) -> RunState:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed)
	run_state.bankroll = bankroll
	return run_state


func _slot_environment() -> Dictionary:
	return {
		"id": "slot_acceptance_room",
		"archetype_id": "bar",
		"kind": "casino",
		"display_name": "Slot Acceptance Room",
		"game_ids": ["slot"],
		"game_states": {},
		"economic_profile": {"stake_floor": 2, "stake_ceiling": 60, "cashout_tone": "test"},
		"security_profile": {"strictness": "loose"},
		"event_ids": [],
	}


func _slot_machine(definition: Dictionary, run_state: RunState, family_id: String, format_id: String, math_id: String = "standard", bonus_id: String = "plain", cabinet_id: String = "neon_magenta") -> Dictionary:
	var generator = SlotMachineGeneratorScript.new()
	var rng: RngStream = run_state.create_rng("slot_machine_%s_%s_%s_%s_%s" % [family_id, format_id, math_id, bonus_id, cabinet_id])
	var machine: Dictionary = generator.build_machine_from_ids(definition, {
		"format_id": format_id,
		"type_id": family_id,
		"math_variant_id": math_id,
		"bonus_variant_id": bonus_id,
		"cabinet_variant_id": cabinet_id,
	}, rng)
	return SlotMachineStateScript.set_selected_bet(machine, "bet_10")


func _slot_store_machine(run_state: RunState, environment: Dictionary, machine: Dictionary) -> void:
	SlotMachineStateScript.write_machine(environment, "slot", machine)
	run_state.current_environment = environment


func _slot_with_test_celebration(machine: Dictionary, tier: String, payout: int, stake_cost: int) -> Dictionary:
	var next: Dictionary = machine.duplicate(true)
	var duration := _slot_test_celebration_duration_msec(tier)
	var start_msec := 180
	next["last_classification"] = "true_win" if payout > 0 else "near_miss" if tier == "tease" else "idle"
	next["last_payout"] = maxi(0, payout)
	next["last_stake_cost"] = maxi(0, stake_cost)
	next["last_net"] = maxi(0, payout) - maxi(0, stake_cost)
	next["slot_win_amount"] = maxi(0, payout)
	next["slot_win_reason"] = "Test %s celebration" % tier
	next["slot_celebration_tier"] = tier
	next["slot_animation_id"] = "tier_sweep:%s" % tier
	next["slot_animation_duration_msec"] = start_msec + duration + 300
	next["slot_animation_plan"] = {
		"id": "tier_sweep:%s" % tier,
		"duration_msec": start_msec + duration + 300,
		"reel_stop_times": [],
		"reel_timeline": [],
		"bonus_start_time": 0.0,
		"feature_duration_msec": 0,
		"tease_active": tier == "tease",
		"tease_reel": -1,
		"tease_text": "",
		"celebration_tier": tier,
		"celebration_start_msec": start_msec,
		"celebration_duration_msec": duration,
		"count_up_start_msec": start_msec,
		"count_up_end_msec": start_msec + duration,
	}
	return next


func _slot_test_celebration_duration_msec(tier: String) -> int:
	match tier:
		"jackpot":
			return 3000
		"mega":
			return 2200
		"big":
			return 1600
		"feature":
			return 1200
		"line":
			return 900
		_:
			return 0


func _slot_ids(rows: Array) -> Array:
	var ids: Array = []
	for row_value in rows:
		var row: Dictionary = _slot_dict(row_value)
		var id := str(row.get("id", ""))
		if not id.is_empty():
			ids.append(id)
	return ids


func _slot_assert_between(value: float, minimum: float, maximum: float, label: String, failures: Array) -> void:
	if value < minimum or value > maximum:
		failures.append("%s %.5f outside %.5f..%.5f." % [label, value, minimum, maximum])


func _slot_spin_until_classification(definition: Dictionary, family_id: String, format_id: String, classification: String, seed: String, failures: Array) -> Dictionary:
	var resolver = SlotResolverScript.new()
	var run_state: RunState = _slot_run_state(seed, 100000)
	var machine: Dictionary = _slot_machine(definition, run_state, family_id, format_id, "standard", "plain")
	var rng: RngStream = run_state.create_rng("slot_seek_%s" % classification)
	for _index in range(1600):
		var resolved: Dictionary = resolver.resolve_spin(machine, "spin", SlotMachineStateScript.selected_bet(machine), rng, definition, {})
		machine = _slot_dict(resolved.get("machine", machine))
		var result: Dictionary = _slot_dict(resolved.get("result", {}))
		if str(result.get("slot_classification", "")) == classification:
			return {"run_state": run_state, "machine": machine, "result": result}
		if SlotMachineStateScript.active_bonus_incomplete(machine):
			machine["active_bonus"] = {"active": false, "complete": true}
	failures.append("Slot sample search could not find %s/%s %s." % [family_id, format_id, classification])
	return {}


func _slot_reel_manifest_progress(early: Dictionary, mid: Dictionary, settle: Dictionary) -> bool:
	var early_phases: Array = _slot_string_array(early.get("reel_phase", []))
	var mid_phases: Array = _slot_string_array(mid.get("reel_phase", []))
	var settle_phases: Array = _slot_string_array(settle.get("reel_phase", []))
	if early_phases.is_empty() or mid_phases.is_empty() or settle_phases.is_empty():
		return false
	if early_phases == mid_phases or mid_phases == settle_phases:
		return false
	for phase_value in settle_phases:
		if str(phase_value) != "settled":
			return false
	return true


func _slot_stops_are_staggered(stops: Array) -> bool:
	if stops.size() < 2:
		return true
	for index in range(1, stops.size()):
		if int(stops[index]) <= int(stops[index - 1]):
			return false
	return true


func _slot_settle_msec(timeline: Array) -> int:
	var result := 0
	for entry_value in timeline:
		var entry: Dictionary = _slot_dict(entry_value)
		result = maxi(result, int(round(float(entry.get("settle_end", 0.0)) * 1000.0)) + 24)
	return maxi(100, result)


func _slot_reveal_msec(timeline: Array) -> int:
	var result := 0
	for entry_value in timeline:
		var entry: Dictionary = _slot_dict(entry_value)
		result = maxi(result, int(ceil(float(entry.get("settle_end", entry.get("stop_time", 0.0))) * 1000.0)))
	return maxi(180, result + 180)


func _slot_surface_ui_at_spin_msec(spin_msec: int) -> Dictionary:
	var elapsed_sec := float(maxi(0, spin_msec)) / 1000.0
	return {
		"surface_time_msec": maxi(0, spin_msec),
		"drunk_scaled_surface_time_msec": maxi(0, spin_msec),
		"surface_runtime_status": {
			"surface_animations": {
				"slot_spin": {
					"id": "slot_spin",
					"active": true,
					"elapsed": elapsed_sec,
				},
			},
		},
	}


func _slot_spin_mid_msec(timeline: Array) -> int:
	for entry_value in timeline:
		var entry: Dictionary = _slot_dict(entry_value)
		var decel_start := float(entry.get("decel_start", 0.0))
		var stop_time := float(entry.get("stop_time", decel_start + 0.2))
		if stop_time > decel_start:
			return maxi(180, int(round((decel_start + (stop_time - decel_start) * 0.50) * 1000.0)))
	return 240


func _slot_tease_msec(timeline: Array) -> int:
	for entry_value in timeline:
		var entry: Dictionary = _slot_dict(entry_value)
		if bool(entry.get("tease", false)):
			var decel := float(entry.get("decel_start", 0.0))
			var stop := float(entry.get("stop_time", decel + 0.2))
			return int(round((decel + (stop - decel) * 0.55) * 1000.0))
	return _slot_settle_msec(timeline)


func _slot_grid_symbol(grid: Array, reel_index: int, row_index: int) -> String:
	if reel_index < 0 or reel_index >= grid.size() or typeof(grid[reel_index]) != TYPE_ARRAY:
		return "BLANK"
	var column: Array = grid[reel_index] as Array
	if row_index < 0 or row_index >= column.size():
		return "BLANK"
	return str(column[row_index])


func _slot_symbol_count(grid: Array, symbol_id: String) -> int:
	var count := 0
	for column_value in grid:
		if typeof(column_value) != TYPE_ARRAY:
			continue
		var column: Array = column_value as Array
		for symbol_value in column:
			if str(symbol_value) == symbol_id:
				count += 1
	return count


func _slot_count_grid_symbols(grid: Array, counts: Dictionary) -> void:
	for column_value in grid:
		if typeof(column_value) != TYPE_ARRAY:
			continue
		for symbol in column_value as Array:
			var key := str(symbol)
			counts[key] = int(counts.get(key, 0)) + 1


func _slot_grid_symbol_lookup(grid: Array, symbol_id: String) -> Dictionary:
	var result: Dictionary = {}
	for reel_index in range(grid.size()):
		if typeof(grid[reel_index]) != TYPE_ARRAY:
			continue
		var column: Array = grid[reel_index] as Array
		for row_index in range(column.size()):
			if str(column[row_index]) == symbol_id:
				result["%d:%d" % [reel_index, row_index]] = true
	return result


func _slot_cell_lookup(cells: Array) -> Dictionary:
	var result: Dictionary = {}
	for cell_value in cells:
		var cell: Dictionary = _slot_dict(cell_value)
		result["%d:%d" % [int(cell.get("reel", -1)), int(cell.get("row", -1))]] = true
	return result


func _slot_assert_nudge_target_landed(machine: Dictionary, result: Dictionary, target: Dictionary, failures: Array, label: String) -> void:
	var reel_index := int(target.get("reel", -1))
	var row_index := int(target.get("row", -1))
	var grid: Array = _slot_array(result.get("slot_grid", []))
	var stops: Array = _slot_array(result.get("slot_reel_stops", []))
	var strips: Array = _slot_array(machine.get("reel_strips", []))
	if reel_index < 0 or row_index < 0 or reel_index >= stops.size() or reel_index >= strips.size():
		failures.append("%s did not expose a valid target reel/row." % label)
		return
	var strip: Array = _slot_array(strips[reel_index])
	if strip.is_empty():
		failures.append("%s target reel strip was empty." % label)
		return
	var new_stop := posmod(int(stops[reel_index]), strip.size())
	var landed_symbol := _slot_grid_symbol(grid, reel_index, row_index)
	var strip_symbol := str(strip[posmod(new_stop + row_index, strip.size())])
	var target_symbol := str(target.get("symbol", ""))
	if landed_symbol != strip_symbol or (not target_symbol.is_empty() and landed_symbol != target_symbol):
		failures.append("%s landed %s at reel %d row %d, expected strip symbol %s / target %s." % [label, landed_symbol, reel_index, row_index, strip_symbol, target_symbol])
	var perfect: Dictionary = _slot_dict(target.get("perfect", {}))
	if not perfect.is_empty() and int(perfect.get("new_stop", new_stop)) != new_stop:
		failures.append("%s stopped at %d instead of the perfect target stop %d." % [label, new_stop, int(perfect.get("new_stop", new_stop))])


func _slot_surface_channel_duration(surface_state: Dictionary, channel_id: String) -> int:
	for channel_value in _slot_array(surface_state.get("surface_animation_channels", [])):
		var channel: Dictionary = _slot_dict(channel_value)
		if str(channel.get("id", "")) == channel_id:
			return maxi(0, int(channel.get("duration_msec", 0)))
	return 0


func _slot_is_low_buffalo_card(symbol: String) -> bool:
	return ["A", "K", "Q", "J", "10"].has(symbol)


func _slot_symbol_is_wild(symbol: String, family_id: String) -> bool:
	if family_id == "buffalo":
		return symbol == "SUNSET" or symbol == "SUNSET_2X" or symbol == "SUNSET_3X"
	return symbol == "WILD" or symbol == "DOUBLE" or symbol == "DOUBLE_7"


func _slot_string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var source: Array = value as Array
	for entry in source:
		result.append(str(entry))
	return result


func _slot_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _slot_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


func _check_all_game_module_contracts(library: ContentLibrary, failures: Array) -> void:
	for game_value in library.games:
		if typeof(game_value) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = game_value
		var game_id := str(definition.get("id", ""))
		if game_id.is_empty():
			continue
		var game: GameModule = _load_surface_contract_game(library, game_id, failures)
		if game == null:
			continue
		_check_generic_game_module_contract(game, failures)


func _check_cross_game_integration_matrix(library: ContentLibrary, failures: Array) -> void:
	var game_ids := ["bar_dice", "video_poker", "blackjack", "pull_tabs", "slot"]
	for game_id in game_ids:
		var game: GameModule = _load_surface_contract_game(library, game_id, failures)
		if game == null:
			continue
		var luck_pair: Dictionary = _xgame_luck_pair(game_id, game, failures)
		_xgame_assert_shift(game_id, "luck", int(luck_pair.get("baseline", 0)), int(luck_pair.get("modified", 0)), "up", failures)
		var item_pair: Dictionary = _xgame_item_heat_pair(game_id, game, "cheap_sunglasses")
		_xgame_assert_shift(game_id, "item", int(item_pair.get("baseline", 0)), int(item_pair.get("modified", 0)), "down", failures)
		var alcohol_pair: Dictionary = _xgame_heat_pair(game_id, game, true, false, "")
		_xgame_assert_shift(game_id, "alcohol", int(alcohol_pair.get("baseline", 0)), int(alcohol_pair.get("modified", 0)), "up", failures)
		var watched_pair: Dictionary = _xgame_heat_pair(game_id, game, false, true, "")
		_xgame_assert_shift(game_id, "watched_cheat", int(watched_pair.get("baseline", 0)), int(watched_pair.get("modified", 0)), "up", failures)
	_check_grand_casino_game_endgame_contracts(library, failures)


func _check_skill_cheat_contract_foundation(library: ContentLibrary, failures: Array) -> void:
	var boss_archetype := _archetype_by_id(library, "grand_casino")
	if boss_archetype.is_empty():
		failures.append("Skill-cheat contract requires the grand_casino archetype.")
		return
	var objective: Dictionary = boss_archetype.get("demo_objective", {}) if typeof(boss_archetype.get("demo_objective", {})) == TYPE_DICTIONARY else {}
	var showdown_threshold := clampi(int(objective.get("showdown_heat_threshold", 70)), 1, 100)
	var game_ids := ["pull_tabs", "slot", "bar_dice", "blackjack", "baccarat", "roulette", "video_poker"]
	var summaries: Array[String] = []
	for game_id in game_ids:
		var game: GameModule = _load_surface_contract_game(library, game_id, failures)
		if game == null:
			continue
		var action_run := _grand_casino_game_fixture_run(library, boss_archetype, game_id, game, "C5-ACTIONS-%s" % game_id.to_upper())
		var cheat_actions := game.cheat_actions(action_run, action_run.current_environment)
		_check_skill_cheat_action_presentation(game_id, cheat_actions, failures)

		for action_value in cheat_actions:
			if typeof(action_value) != TYPE_DICTIONARY:
				continue
			var action: Dictionary = action_value
			var action_id := str(action.get("id", "")).strip_edges()
			if action_id.is_empty():
				continue
			var fixture := _grand_casino_game_heat_fixture(library, boss_archetype, game_id, game, showdown_threshold, failures, action_id)
			if fixture.is_empty():
				continue
			var run_state := fixture.get("run_state", null) as RunState
			var result: Dictionary = fixture.get("result", {})
			if run_state == null or result.is_empty() or not bool(result.get("ok", false)):
				failures.append("Skill-cheat %s/%s fixture did not resolve a watched cheat result." % [game_id, action_id])
				continue
			_check_skill_cheat_result_contract(game_id, action_id, result, true, failures)
			var status := run_state.demo_objective_status()
			if not bool(status.get("staff_attention_active", false)):
				failures.append("Skill-cheat %s/%s watched Grand Casino cheat did not expose staff attention." % [game_id, action_id])
			if str(result.get("action_kind", "")) == "cheat" and not bool(run_state.narrative_flags.get("grand_casino_attention_watched_cheat", false)):
				failures.append("Skill-cheat %s/%s watched cheat did not set grand_casino_attention_watched_cheat." % [game_id, action_id])
			summaries.append("%s/%s:%s:%s:+%d" % [
				game_id,
				action_id,
				str(result.get("action_kind", "")),
				str(result.get("skill_outcome", "")),
				int(result.get("suspicion_delta", 0)),
			])

		var clean_run := _grand_casino_game_fixture_run(library, boss_archetype, game_id, game, "C5-CLEAN-%s" % game_id.to_upper())
		var clean_result := _skill_cheat_clean_result(game_id, game, clean_run)
		if clean_result.is_empty() or not bool(clean_result.get("ok", false)):
			failures.append("Skill-cheat %s clean fixture did not resolve a legal result." % game_id)
		else:
			if bool(clean_result.get("host_apply_result", false)):
				GameModule.apply_result(clean_run, clean_result, clean_run.create_rng("c5_%s_clean_host_apply" % game_id))
			if str(clean_result.get("action_kind", "")) != "legal":
				failures.append("Skill-cheat %s clean fixture reported %s instead of legal." % [game_id, str(clean_result.get("action_kind", ""))])
			if bool(clean_result.get("skill_cheat_contract", false)):
				failures.append("Skill-cheat %s clean fixture incorrectly received the skill-cheat contract." % game_id)
			var clean_status := clean_run.demo_objective_status()
			if int(clean_status.get("grand_casino_open_cheat_actions", 0)) != 0 or bool(clean_status.get("cheat_evidence", false)) or bool(clean_status.get("watched_cheat_evidence", false)):
				failures.append("Skill-cheat %s clean play marked Grand Casino cheat evidence." % game_id)
	print("SKILL_CHEAT_CONTRACT_MATRIX %s" % ", ".join(summaries))


func _check_skill_timing_helper_foundation(_library: ContentLibrary, failures: Array) -> void:
	var clamped_windows := GameModule.normalize_skill_timing_windows(-5, 4, 3, 20)
	_assert_equal(int(clamped_windows.get("perfect_window_msec", 0)), 20, "Skill timing helper did not clamp the perfect window to the strict minimum.", failures)
	_assert_equal(int(clamped_windows.get("good_window_msec", 0)), 20, "Skill timing helper did not keep good >= perfect.", failures)
	_assert_equal(int(clamped_windows.get("close_window_msec", 0)), 20, "Skill timing helper did not keep close >= good.", failures)

	var perfect := GameModule.skill_timing_grade_from_distance(0, 40, 80, 120, 20)
	_assert_equal(str(perfect.get("skill_grade", "")), "perfect", "Skill timing helper did not grade zero distance as perfect.", failures)
	_assert_equal(int(perfect.get("skill_accuracy", -1)), 100, "Skill timing helper did not grade zero distance as 100 accuracy.", failures)

	var partial := GameModule.skill_timing_grade_from_distance(90, 40, 80, 120, 20)
	_assert_equal(str(partial.get("skill_grade", "")), "partial", "Skill timing helper did not grade close-window distance as partial.", failures)
	_assert_equal(int(partial.get("skill_accuracy", -1)), 25, "Skill timing helper did not preserve the shared distance accuracy formula.", failures)

	var blown := GameModule.skill_timing_grade_from_distance(121, 40, 80, 120, 20)
	_assert_equal(str(blown.get("skill_grade", "")), "blown", "Skill timing helper did not grade beyond close-window distance as blown.", failures)
	_assert_equal(int(blown.get("skill_accuracy", -1)), 0, "Skill timing helper did not zero accuracy for blown timing.", failures)
	if not GameModule.skill_grade_applies("good") or GameModule.skill_grade_applies("blown"):
		failures.append("Skill timing helper applies predicate did not match cheat grade contract.")
	_assert_equal(GameModule.skill_outcome_for_grade("holdout", ""), "holdout_miss", "Skill timing helper did not use miss fallback outcome.", failures)


func _check_skill_cheat_item_modifier_foundation(library: ContentLibrary, failures: Array) -> void:
	_check_skill_cheat_item_content_reachability(library, failures)
	_check_skill_cheat_item_save_round_trip(failures)
	var video_poker: GameModule = _load_surface_contract_game(library, "video_poker", failures)
	if video_poker != null:
		_check_video_poker_holdout_item_modifier(video_poker, failures)
	var bar_dice: GameModule = _load_surface_contract_game(library, "bar_dice", failures)
	if bar_dice != null:
		_check_bar_dice_controlled_roll_item_modifier(bar_dice, failures)
	var roulette: GameModule = _load_surface_contract_game(library, "roulette", failures)
	if roulette != null:
		_check_roulette_past_post_item_modifier(roulette, library, failures)
	var baccarat: GameModule = _load_surface_contract_game(library, "baccarat", failures)
	if baccarat != null:
		_check_baccarat_edge_sort_item_modifier(baccarat, failures)


func _check_skill_cheat_item_content_reachability(library: ContentLibrary, failures: Array) -> void:
	var expectations := [
		{"group": "video_poker_pack", "items": ["holdout_wax"]},
		{"group": "bar_dice_pack", "items": ["weighted_keyring", "dice_calipers"]},
		{"group": "roulette_pack", "items": ["foil_sleeve", "chip_slide_wax"]},
		{"group": "baccarat_pack", "items": ["marked_cards", "edge_sort_loupe"]},
	]
	for expectation_value in expectations:
		var expectation: Dictionary = expectation_value
		var group_id := str(expectation.get("group", ""))
		var group_def := library.content_group(group_id)
		if group_def.is_empty():
			failures.append("Skill-cheat item support group is missing: %s." % group_id)
			continue
		var group_items := _string_array(group_def.get("item_ids", []))
		var shop_pool := library.shop_item_pool_for_challenge([], {"modifiers": {"content_groups": [group_id]}})
		for item_id_value in _string_array(expectation.get("items", [])):
			var item_id := str(item_id_value)
			var item_def := library.item(item_id)
			if item_def.is_empty():
				failures.append("Skill-cheat support item is missing from ContentLibrary: %s." % item_id)
				continue
			if not group_items.has(item_id):
				failures.append("Skill-cheat support item %s is not listed in content group %s." % [item_id, group_id])
			if not _string_array(item_def.get("content_groups", [])).has(group_id):
				failures.append("Skill-cheat support item %s does not declare content group %s." % [item_id, group_id])
			if not shop_pool.has(item_id):
				failures.append("Skill-cheat support item %s is not reachable from shop pools for %s." % [item_id, group_id])


func _check_skill_cheat_item_save_round_trip(failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("T27-SKILL-CHEAT-ITEM-SAVE")
	for item_id in ["holdout_wax", "dice_calipers", "chip_slide_wax", "edge_sort_loupe"]:
		run_state.add_item(str(item_id))
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	for item_id in ["holdout_wax", "dice_calipers", "chip_slide_wax", "edge_sort_loupe"]:
		if not restored.inventory.has(str(item_id)):
			failures.append("Skill-cheat support item did not survive RunState save/load: %s." % str(item_id))


func _check_video_poker_holdout_item_modifier(game: GameModule, failures: Array) -> void:
	var baseline := _video_poker_holdout_item_fixture(game, "")
	var modified := _video_poker_holdout_item_fixture(game, "holdout_wax")
	var base_challenge: Dictionary = baseline.get("challenge", {})
	var item_challenge: Dictionary = modified.get("challenge", {})
	if item_challenge.is_empty() or base_challenge.is_empty():
		failures.append("Video poker holdout item modifier fixture did not start the challenge.")
		return
	if int(item_challenge.get("perfect_window_msec", 0)) <= int(base_challenge.get("perfect_window_msec", 0)):
		failures.append("Holdout Wax did not widen the video poker perfect window.")
	if int(item_challenge.get("good_window_msec", 0)) <= int(base_challenge.get("good_window_msec", 0)):
		failures.append("Holdout Wax did not widen the video poker good window.")
	if int(item_challenge.get("close_window_msec", 0)) <= int(base_challenge.get("close_window_msec", 0)):
		failures.append("Holdout Wax did not widen the video poker close window.")
	if int(item_challenge.get("base_heat", 999)) >= int(base_challenge.get("base_heat", 0)):
		failures.append("Holdout Wax did not reduce video poker holdout base heat.")
	_check_skill_cheat_item_badges("video poker holdout challenge", item_challenge.get("item_modifiers", []), "holdout_wax", failures)
	var surface: Dictionary = modified.get("surface", {})
	_check_skill_cheat_item_badges("video poker holdout surface", surface.get("holdout_item_modifiers", []), "holdout_wax", failures)


func _video_poker_holdout_item_fixture(game: GameModule, item_id: String) -> Dictionary:
	var run_state: RunState = _vp_fresh(game, "jacks_or_better", "T27-VIDEO-POKER-%s" % (item_id if not item_id.is_empty() else "BASE"), 100000)
	if not item_id.is_empty():
		run_state.add_item(item_id)
	var deal_command: Dictionary = game.surface_action_command("video_poker_deal", 0, false, {}, run_state, run_state.current_environment)
	var ui: Dictionary = deal_command.get("ui_state", {})
	ui["surface_time_msec"] = 12000
	var mark_command: Dictionary = game.surface_action_command("video_poker_mark", 0, false, ui, run_state, run_state.current_environment)
	var mark_ui: Dictionary = mark_command.get("ui_state", ui)
	var challenge: Dictionary = mark_ui.get("holdout_challenge", {}) if typeof(mark_ui.get("holdout_challenge", {})) == TYPE_DICTIONARY else {}
	return {
		"run_state": run_state,
		"ui_state": mark_ui,
		"challenge": challenge,
		"surface": game.surface_state(run_state, run_state.current_environment, mark_ui),
	}


func _check_bar_dice_controlled_roll_item_modifier(game: GameModule, failures: Array) -> void:
	var baseline := _bar_dice_controlled_roll_item_fixture(game, "")
	var modified := _bar_dice_controlled_roll_item_fixture(game, "dice_calipers")
	var base_challenge: Dictionary = baseline.get("challenge", {})
	var item_challenge: Dictionary = modified.get("challenge", {})
	if item_challenge.is_empty() or base_challenge.is_empty():
		failures.append("Bar dice controlled-roll item modifier fixture did not start the challenge.")
		return
	if int(item_challenge.get("perfect_window_msec", 0)) <= int(base_challenge.get("perfect_window_msec", 0)):
		failures.append("Dice Calipers did not widen the bar dice perfect window.")
	if int(item_challenge.get("good_window_msec", 0)) <= int(base_challenge.get("good_window_msec", 0)):
		failures.append("Dice Calipers did not widen the bar dice good window.")
	if int(item_challenge.get("close_window_msec", 0)) <= int(base_challenge.get("close_window_msec", 0)):
		failures.append("Dice Calipers did not widen the bar dice close window.")
	if int(item_challenge.get("meter_period_msec", 0)) <= int(base_challenge.get("meter_period_msec", 0)):
		failures.append("Dice Calipers did not slow the bar dice timing meter.")
	if int(item_challenge.get("base_heat", 999)) >= int(base_challenge.get("base_heat", 0)):
		failures.append("Dice Calipers did not reduce bar dice controlled-roll base heat.")
	_check_skill_cheat_item_badges("bar dice controlled-roll challenge", item_challenge.get("item_modifiers", []), "dice_calipers", failures)
	var surface: Dictionary = modified.get("surface", {})
	_check_skill_cheat_item_badges("bar dice controlled-roll surface", surface.get("controlled_roll_item_modifiers", []), "dice_calipers", failures)


func _bar_dice_controlled_roll_item_fixture(game: GameModule, item_id: String) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("T27-BAR-DICE-%s" % (item_id if not item_id.is_empty() else "BASE"))
	run_state.bankroll = 100000
	if not item_id.is_empty():
		run_state.add_item(item_id)
	var environment := _surface_contract_environment()
	environment["game_ids"] = ["bar_dice"]
	environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 100}
	var state: Dictionary = _bar_dice_state_for(game, run_state, environment, "ship_captain_crew", "standard", "pot_rake")
	environment["game_states"] = {"bar_dice": state}
	run_state.set_environment(environment)
	var ui := {"surface_time_msec": 14000}
	var load_command: Dictionary = game.surface_action_command("bar_dice_load", 0, false, ui, run_state, run_state.current_environment)
	var load_ui: Dictionary = load_command.get("ui_state", ui)
	var challenge: Dictionary = load_ui.get("controlled_roll", {}) if typeof(load_ui.get("controlled_roll", {})) == TYPE_DICTIONARY else {}
	return {
		"run_state": run_state,
		"ui_state": load_ui,
		"challenge": challenge,
		"surface": game.surface_state(run_state, run_state.current_environment, load_ui),
	}


func _check_roulette_past_post_item_modifier(game: GameModule, library: ContentLibrary, failures: Array) -> void:
	var baseline := _roulette_past_post_item_fixture(game, library, "")
	var modified := _roulette_past_post_item_fixture(game, library, "chip_slide_wax")
	var base_challenge: Dictionary = baseline.get("challenge", {})
	var item_challenge: Dictionary = modified.get("challenge", {})
	if item_challenge.is_empty() or base_challenge.is_empty():
		failures.append("Roulette past-post item modifier fixture did not start the challenge.")
		return
	if int(item_challenge.get("perfect_window_msec", 0)) <= int(base_challenge.get("perfect_window_msec", 0)):
		failures.append("Chip-Slide Wax did not widen the roulette perfect reaction window.")
	if int(item_challenge.get("good_window_msec", 0)) <= int(base_challenge.get("good_window_msec", 0)):
		failures.append("Chip-Slide Wax did not widen the roulette good reaction window.")
	if int(item_challenge.get("window_msec", 0)) <= int(base_challenge.get("window_msec", 0)):
		failures.append("Chip-Slide Wax did not extend the roulette past-post window.")
	if int(item_challenge.get("base_heat", 999)) >= int(base_challenge.get("base_heat", 0)):
		failures.append("Chip-Slide Wax did not reduce roulette past-post base heat.")
	_check_skill_cheat_item_badges("roulette past-post challenge", item_challenge.get("item_modifiers", []), "chip_slide_wax", failures)
	var surface: Dictionary = modified.get("surface", {})
	_check_skill_cheat_item_badges("roulette past-post surface", surface.get("past_post_item_modifiers", []), "chip_slide_wax", failures)


func _roulette_past_post_item_fixture(game: GameModule, library: ContentLibrary, item_id: String) -> Dictionary:
	var fixture := _roulette_past_post_fixture(game, "T27-ROULETTE-%s" % (item_id if not item_id.is_empty() else "BASE"), 5, false, library)
	var run_state := fixture.get("run_state", null) as RunState
	if run_state == null:
		return {}
	if not item_id.is_empty():
		run_state.add_item(item_id)
	var payout_ui: Dictionary = fixture.get("payout_ui", {}) if typeof(fixture.get("payout_ui", {})) == TYPE_DICTIONARY else {}
	var surface := game.surface_state(run_state, run_state.current_environment, payout_ui)
	var arm_command: Dictionary = game.surface_action_command("roulette_past_post", 0, false, payout_ui, run_state, run_state.current_environment)
	var arm_ui: Dictionary = arm_command.get("ui_state", payout_ui)
	var challenge: Dictionary = arm_ui.get("past_post_challenge", {}) if typeof(arm_ui.get("past_post_challenge", {})) == TYPE_DICTIONARY else {}
	return {
		"run_state": run_state,
		"ui_state": arm_ui,
		"challenge": challenge,
		"surface": surface,
	}


func _check_roulette_spin_lands_on_result(game: GameModule, result_surface: Dictionary, failures: Array) -> void:
	var last_result: Dictionary = result_surface.get("last_result", {}) if typeof(result_surface.get("last_result", {})) == TYPE_DICTIONARY else {}
	var trajectory: Array = _baccarat_dictionary_array(result_surface.get("spin_trajectory", []))
	if last_result.is_empty() or trajectory.is_empty():
		failures.append("Roulette landing fixture missing result or trajectory.")
		return
	var sequence := _string_array(result_surface.get("wheel_sequence", []))
	var count := maxi(1, sequence.size())
	var winning_index := int(last_result.get("winning_index", -1))
	if winning_index < 0 or winning_index >= count:
		failures.append("Roulette landing fixture has invalid winning index.")
		return
	var handoff_surface := result_surface.duplicate(true)
	handoff_surface["surface_time_msec"] = int(last_result.get("resolved_at_msec", 0)) + 5600
	var active_harness := SurfaceHarness.new()
	active_harness.setup(handoff_surface)
	active_harness.animation_active = true
	active_harness.animation_progress = 1.0
	active_harness.flicker_value = 27.5
	var final_motion: Dictionary = game.call("surface_motion_signature", active_harness, handoff_surface)
	var settled_harness := SurfaceHarness.new()
	settled_harness.setup(handoff_surface)
	settled_harness.animation_active = false
	settled_harness.animation_progress = 1.0
	settled_harness.flicker_value = 27.5
	var settled_motion: Dictionary = game.call("surface_motion_signature", settled_harness, handoff_surface)
	if absf(float(final_motion.get("wheel_angle_mdeg", 0)) - float(settled_motion.get("wheel_angle_mdeg", 0))) > 2.0:
		failures.append("Roulette wheel jumps between final spin frame and settled frame.")
	if absf(float(final_motion.get("ball_angle_mdeg", 0)) - float(settled_motion.get("ball_angle_mdeg", 0))) > 2.0:
		failures.append("Roulette ball jumps between final spin frame and settled frame.")
	var wheel_angle := float(final_motion.get("wheel_angle_mdeg", 0)) / 1000.0
	var ball_angle := float(final_motion.get("ball_angle_mdeg", 0)) / 1000.0
	var expected_ball_angle := fposmod(wheel_angle + (float(winning_index) + 0.5) / float(count) * TAU, TAU)
	if _angle_distance(ball_angle, expected_ball_angle) > 0.01:
		failures.append("Roulette ball final frame did not land in the winning pocket: expected %.3f got %.3f." % [expected_ball_angle, ball_angle])


func _angle_distance(a: float, b: float) -> float:
	return absf(atan2(sin(a - b), cos(a - b)))


func _check_baccarat_edge_sort_item_modifier(game: GameModule, failures: Array) -> void:
	var baseline := _baccarat_edge_sort_item_fixture(game, "")
	var modified := _baccarat_edge_sort_item_fixture(game, "edge_sort_loupe")
	var base_challenge: Dictionary = baseline.get("challenge", {})
	var item_challenge: Dictionary = modified.get("challenge", {})
	if item_challenge.is_empty() or base_challenge.is_empty():
		failures.append("Baccarat edge-sort item modifier fixture did not start the challenge.")
		return
	if int(item_challenge.get("required_cue_count", 99)) >= int(base_challenge.get("required_cue_count", 0)):
		failures.append("Edge-Sort Loupe did not reduce the baccarat required cue count.")
	if int(item_challenge.get("memory_tolerance", 0)) <= int(base_challenge.get("memory_tolerance", 0)):
		failures.append("Edge-Sort Loupe did not increase baccarat memory tolerance.")
	if int(item_challenge.get("base_heat", 999)) >= int(base_challenge.get("base_heat", 0)):
		failures.append("Edge-Sort Loupe did not reduce baccarat edge-sort base heat.")
	_check_skill_cheat_item_badges("baccarat edge-sort challenge", item_challenge.get("item_modifiers", []), "edge_sort_loupe", failures)
	var surface: Dictionary = modified.get("surface", {})
	_check_skill_cheat_item_badges("baccarat edge-sort surface", surface.get("edge_sort_item_modifiers", []), "edge_sort_loupe", failures)


func _baccarat_edge_sort_item_fixture(game: GameModule, item_id: String) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("T27-BACCARAT-%s" % (item_id if not item_id.is_empty() else "BASE"))
	run_state.bankroll = 100000
	if not item_id.is_empty():
		run_state.add_item(item_id)
	var environment := _surface_contract_environment()
	environment["game_ids"] = ["baccarat"]
	environment["economic_profile"] = {"stake_floor": 20, "stake_ceiling": 500}
	environment["security_profile"] = {"strictness": "boss"}
	var table: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("t27_baccarat_state"))
	environment["game_states"] = {"baccarat": table}
	run_state.set_environment(environment)
	var command: Dictionary = game.surface_action_command("baccarat_edge_sort", 0, false, {}, run_state, run_state.current_environment)
	var ui: Dictionary = command.get("ui_state", {})
	var challenge: Dictionary = ui.get("edge_sort_challenge", {}) if typeof(ui.get("edge_sort_challenge", {})) == TYPE_DICTIONARY else {}
	return {
		"run_state": run_state,
		"ui_state": ui,
		"challenge": challenge,
		"surface": game.surface_state(run_state, run_state.current_environment, ui),
	}


func _check_skill_cheat_item_badges(label: String, badges_value: Variant, expected_item_id: String, failures: Array) -> void:
	if typeof(badges_value) != TYPE_ARRAY:
		failures.append("Skill-cheat %s did not expose item modifier badges." % label)
		return
	var badges: Array = badges_value
	for badge_value in badges:
		if typeof(badge_value) != TYPE_DICTIONARY:
			continue
		var badge: Dictionary = badge_value
		if str(badge.get("item_id", "")) != expected_item_id:
			continue
		var modifiers: Dictionary = badge.get("modifiers", {}) if typeof(badge.get("modifiers", {})) == TYPE_DICTIONARY else {}
		if modifiers.is_empty():
			failures.append("Skill-cheat %s exposed %s without concrete modifier values." % [label, expected_item_id])
		return
	failures.append("Skill-cheat %s did not expose visible modifier state for %s." % [label, expected_item_id])


func _check_skill_cheat_action_presentation(game_id: String, cheat_actions: Array, failures: Array) -> void:
	if cheat_actions.is_empty():
		failures.append("Skill-cheat %s did not expose cheat_actions." % game_id)
		return
	for action_value in cheat_actions:
		if typeof(action_value) != TYPE_DICTIONARY:
			failures.append("Skill-cheat %s exposed a non-dictionary cheat action." % game_id)
			continue
		var action: Dictionary = action_value
		if str(action.get("id", "")).strip_edges().is_empty():
			failures.append("Skill-cheat %s cheat action is missing an id." % game_id)
		if str(action.get("label", "")).strip_edges().is_empty():
			failures.append("Skill-cheat %s cheat action is missing a label." % game_id)
		var summary := str(action.get("summary", "")).strip_edges()
		if summary.is_empty():
			failures.append("Skill-cheat %s cheat action is missing payoff/risk summary copy." % game_id)
		_check_no_release_placeholder_text(summary, "Skill-cheat %s cheat action" % game_id, failures)


func _check_skill_cheat_result_contract(game_id: String, registered_action_id: String, result: Dictionary, expected_watched: bool, failures: Array) -> void:
	var label := "%s/%s" % [game_id, registered_action_id]
	var action_kind := str(result.get("action_kind", ""))
	if not ["cheat", "risky", "advantage"].has(action_kind):
		failures.append("Skill-cheat %s result used inconsistent action_kind %s." % [label, action_kind])
	if not bool(result.get("skill_cheat_contract", false)):
		failures.append("Skill-cheat %s result did not expose the shared skill-cheat contract." % label)
	var skill_outcome := str(result.get("skill_outcome", "")).strip_edges()
	if skill_outcome.is_empty():
		failures.append("Skill-cheat %s result did not report skill_outcome." % label)
	var skill_grade := str(result.get("skill_grade", "")).strip_edges()
	if skill_grade.is_empty():
		failures.append("Skill-cheat %s result did not report skill_grade." % label)
	if not result.has("skill_accuracy"):
		failures.append("Skill-cheat %s result did not report skill_accuracy." % label)
	else:
		var accuracy := int(result.get("skill_accuracy", -1))
		if accuracy < 0 or accuracy > 100:
			failures.append("Skill-cheat %s skill_accuracy was out of range: %d." % [label, accuracy])
	if not result.has("skill_margin_msec"):
		failures.append("Skill-cheat %s result did not report skill_margin_msec." % label)
	if int(result.get("base_suspicion_delta", -1)) < 0:
		failures.append("Skill-cheat %s result did not report base_suspicion_delta." % label)
	elif int(result.get("suspicion_delta", 0)) > 0 and int(result.get("base_suspicion_delta", 0)) <= 0:
		failures.append("Skill-cheat %s positive heat did not preserve a positive base_suspicion_delta." % label)
	if int(result.get("skill_suspicion_delta", -999)) != int(result.get("suspicion_delta", 0)):
		failures.append("Skill-cheat %s skill_suspicion_delta did not match suspicion_delta." % label)
	if int(result.get("suspicion_delta", 0)) > 0 and not bool(result.get("skill_security_pressure_checked", false)):
		failures.append("Skill-cheat %s result did not mark security pressure evaluation." % label)
	if expected_watched and not bool(result.get("skill_watched", false)):
		failures.append("Skill-cheat %s watched result did not set skill_watched." % label)
	if expected_watched and not bool(result.get("pit_boss_watched", false)):
		failures.append("Skill-cheat %s watched result did not set generic pit_boss_watched." % label)
	if expected_watched and int(result.get("pit_boss_heat_bonus", 0)) <= 0:
		failures.append("Skill-cheat %s watched result did not report pit boss heat bonus." % label)
	if typeof(result.get("skill_story_context", {})) != TYPE_DICTIONARY:
		failures.append("Skill-cheat %s result did not expose skill_story_context." % label)
	else:
		var context: Dictionary = result.get("skill_story_context", {})
		if str(context.get("game_id", "")) != game_id:
			failures.append("Skill-cheat %s skill_story_context did not preserve game_id." % label)
		if str(context.get("action_kind", "")) != action_kind:
			failures.append("Skill-cheat %s skill_story_context did not preserve action_kind." % label)
		if str(context.get("skill_outcome", "")).strip_edges().is_empty():
			failures.append("Skill-cheat %s skill_story_context did not preserve skill_outcome." % label)
		if str(context.get("skill_grade", "")).strip_edges().is_empty():
			failures.append("Skill-cheat %s skill_story_context did not preserve skill_grade." % label)
		if bool(context.get("watched", false)) != bool(result.get("skill_watched", false)):
			failures.append("Skill-cheat %s skill_story_context watched state did not match result." % label)
	var deltas: Dictionary = result.get("deltas", {}) if typeof(result.get("deltas", {})) == TYPE_DICTIONARY else {}
	var story_entries: Array = deltas.get("story_log", []) if typeof(deltas.get("story_log", [])) == TYPE_ARRAY else []
	var found_story := false
	for story_value in story_entries:
		if typeof(story_value) != TYPE_DICTIONARY:
			continue
		var story: Dictionary = story_value
		if str(story.get("game_id", "")) != game_id or str(story.get("action_id", "")) != str(result.get("action_id", "")):
			continue
		found_story = true
		if str(story.get("skill_outcome", "")).strip_edges().is_empty():
			failures.append("Skill-cheat %s story entry did not report skill_outcome." % label)
		if str(story.get("skill_grade", "")).strip_edges().is_empty():
			failures.append("Skill-cheat %s story entry did not report skill_grade." % label)
		if int(story.get("base_suspicion_delta", -1)) < 0:
			failures.append("Skill-cheat %s story entry did not report base_suspicion_delta." % label)
		if expected_watched and not bool(story.get("skill_watched", false)):
			failures.append("Skill-cheat %s story entry did not preserve watched state." % label)
		if int(story.get("suspicion_delta", 0)) != int(result.get("suspicion_delta", 0)):
			failures.append("Skill-cheat %s story suspicion did not match result." % label)
	if not found_story:
		failures.append("Skill-cheat %s result did not include matching story context." % label)
	var message := str(result.get("message", "")).strip_edges()
	_check_no_release_placeholder_text(message, "Skill-cheat %s result" % label, failures)
	var lowered := message.to_lower()
	if int(result.get("suspicion_delta", 0)) > 0 and lowered.find("heat") < 0 and lowered.find("security") < 0 and lowered.find("rourke") < 0 and lowered.find("back room") < 0 and lowered.find("watched") < 0 and lowered.find("risk") < 0:
		failures.append("Skill-cheat %s result copy did not communicate risk or staff pressure." % label)


func _check_no_release_placeholder_text(text: String, label: String, failures: Array) -> void:
	var lowered := text.to_lower()
	for marker in ["todo", "placeholder", "test-only", "dev-only"]:
		if lowered.find(marker) >= 0:
			failures.append("%s contains release-path placeholder marker: %s." % [label, marker])


func _skill_cheat_clean_result(game_id: String, game: GameModule, run_state: RunState) -> Dictionary:
	var environment: Dictionary = run_state.current_environment
	match game_id:
		"bar_dice":
			return _bar_dice_play_round(game, run_state, run_state.create_rng("c5_bar_dice_clean"), "roll")
		"video_poker":
			return _video_poker_play_hand(game, run_state, run_state.create_rng("c5_video_poker_clean"), "draw")
		"blackjack":
			return game.resolve_with_context("play_basic", 10, run_state, environment, run_state.create_rng("c5_blackjack_clean"), _xgame_blackjack_win_ui())
		"pull_tabs":
			var buy_command: Dictionary = game.surface_action_command("pull_tab_buy", 0, false, {}, run_state, environment)
			return game.resolve_with_context("buy_tab", int(buy_command.get("set_stake", 1)), run_state, environment, run_state.create_rng("c5_pull_tabs_clean"), buy_command.get("ui_state", {}))
		"slot":
			var machine: Dictionary = _slot_machine(game.definition, run_state, "pinball", "classic_3_reel", "standard", "plain")
			_slot_store_machine(run_state, environment, machine)
			return game.resolve_with_context("spin", 10, run_state, environment, run_state.create_rng("c5_slot_clean"), {})
		"baccarat":
			return game.resolve_with_context("deal_baccarat", 20, run_state, environment, run_state.create_rng("c5_baccarat_clean"), {"baccarat_bets": {"player": 20}})
		"roulette":
			return game.resolve_with_context("spin_roulette", 10, run_state, environment, run_state.create_rng("c5_roulette_clean"), {"roulette_bets": [game.call("_default_smoke_bet", 10)]})
	return {}


func _check_grand_casino_game_endgame_contracts(library: ContentLibrary, failures: Array) -> void:
	var boss_archetype := _archetype_by_id(library, "grand_casino")
	if boss_archetype.is_empty():
		failures.append("Grand Casino game endgame audit requires the grand_casino archetype.")
		return
	var objective: Dictionary = boss_archetype.get("demo_objective", {}) if typeof(boss_archetype.get("demo_objective", {})) == TYPE_DICTIONARY else {}
	var showdown_threshold := clampi(int(objective.get("showdown_heat_threshold", 70)), 1, 100)
	var game_ids := ["pull_tabs", "slot", "bar_dice", "blackjack", "baccarat", "roulette", "video_poker"]
	var summaries: Array[String] = []
	for game_id in game_ids:
		var game: GameModule = _load_surface_contract_game(library, game_id, failures)
		if game == null:
			continue
		var fixture := _grand_casino_game_heat_fixture(library, boss_archetype, game_id, game, showdown_threshold, failures)
		if fixture.is_empty():
			continue
		var run_state := fixture.get("run_state", null) as RunState
		var result: Dictionary = fixture.get("result", {})
		if run_state == null:
			failures.append("Grand Casino %s fixture did not return a RunState." % game_id)
			continue
		if not bool(result.get("ok", false)):
			failures.append("Grand Casino %s fixture did not resolve a successful game result." % game_id)
			continue
		var action_kind := str(result.get("action_kind", ""))
		if not ["cheat", "risky", "advantage"].has(action_kind):
			failures.append("Grand Casino %s fixture should report a cheat/risky action kind, got %s." % [game_id, action_kind])
		var suspicion_delta := int(result.get("suspicion_delta", 0))
		if suspicion_delta <= 0:
			failures.append("Grand Casino %s fixture did not report positive heat." % game_id)
		var message := str(result.get("message", ""))
		if message.find("Rourke") == -1 and message.find("Security") == -1 and message.find("back room") == -1:
			failures.append("Grand Casino %s result message did not explain staff/Rourke pressure." % game_id)
		var status := run_state.demo_objective_status()
		if run_state.run_status != RunState.RUN_STATUS_ACTIVE:
			failures.append("Grand Casino %s high heat should leave the run active for showdown, status=%s." % [game_id, run_state.run_status])
		if run_state.run_failure_reason == RunState.FAILURE_POLICE_CAPTURE:
			failures.append("Grand Casino %s high heat bypassed the showdown reroute as police_capture." % game_id)
		if not bool(status.get("showdown_pending", false)) and not bool(status.get("showdown_active", false)):
			failures.append("Grand Casino %s high heat did not queue the Pit Boss Showdown." % game_id)
		if not bool(status.get("staff_attention_active", false)):
			failures.append("Grand Casino %s high heat did not preserve staff attention state." % game_id)
		if action_kind == "cheat" and int(status.get("grand_casino_open_cheat_actions", 0)) <= 0:
			failures.append("Grand Casino %s cheat result did not mark open cheat evidence." % game_id)
		summaries.append("%s:%s:+%d:%s" % [game_id, action_kind, suspicion_delta, str(status.get("objective_state", ""))])

	var outside_game: GameModule = _load_surface_contract_game(library, "slot", failures)
	if outside_game != null:
		var outside_run: RunState = RunStateScript.new()
		outside_run.start_new("C1-OUTSIDE-HEAT")
		outside_run.bankroll = 100000
		outside_run.set_environment({
			"id": "c1_outside_slot_fixture",
			"display_name": "Roadside Slots",
			"archetype_id": "gas_station_casino",
			"kind": "casino",
			"game_ids": ["slot"],
			"turns": 0,
		})
		outside_run.add_suspicion("c1_outside_preheat", 99, "behavior")
		var outside_result := GameModule.build_action_result({
			"ok": true,
			"type": "game_action",
			"source_id": "slot",
			"game_id": "slot",
			"action_id": "outside_heat_fixture",
			"action_kind": "cheat",
			"stake": 10,
			"suspicion_delta": 1,
			"environment_id": str(outside_run.current_environment.get("id", "")),
			"message": "Outside heat fixture.",
		})
		GameModule.apply_result(outside_run, outside_result, outside_run.create_rng("c1_outside_apply"))
		if outside_run.run_status != RunState.RUN_STATUS_FAILED or outside_run.run_failure_reason != RunState.FAILURE_POLICE_CAPTURE:
			failures.append("Outside-Grand-Casino game heat 100 did not preserve police_capture failure.")
	print("GRAND_CASINO_GAME_ENDGAME_MATRIX %s" % ", ".join(summaries))


func _grand_casino_game_heat_fixture(library: ContentLibrary, boss_archetype: Dictionary, game_id: String, game: GameModule, showdown_threshold: int, failures: Array, action_id: String = "") -> Dictionary:
	var run_state := _grand_casino_game_fixture_run(library, boss_archetype, game_id, game, "C1-GRAND-%s" % game_id.to_upper())
	run_state.add_suspicion("c1_grand_preheat_%s" % game_id, maxi(0, showdown_threshold - 1), "behavior")
	var result := _grand_casino_game_cheat_result_for_action(game_id, action_id, game, run_state)
	if result.is_empty():
		failures.append("Grand Casino %s%s fixture could not produce a cheat/risky result." % [game_id, "" if action_id.is_empty() else "/%s" % action_id])
		return {}
	if bool(result.get("ok", false)):
		_check_action_result_shape(result, str(result.get("action_kind", "cheat")), failures)
		if bool(result.get("host_apply_result", false)):
			GameModule.apply_result(run_state, result, run_state.create_rng("c1_%s_host_apply" % game_id))
	return {
		"run_state": run_state,
		"result": result,
	}


func _grand_casino_game_fixture_run(library: ContentLibrary, boss_archetype: Dictionary, game_id: String, game: GameModule, seed_text: String) -> RunState:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed_text)
	run_state.bankroll = 100000
	if game_id == "pull_tabs":
		run_state.add_item("tab_detector")
	var environment := EnvironmentInstance.from_archetype(boss_archetype, 3, run_state.create_rng("c1_grand_environment"), library).to_dict()
	environment["id"] = "c1_grand_%s_fixture" % game_id
	environment["display_name"] = "Grand Casino"
	environment["archetype_id"] = "grand_casino"
	environment["kind"] = "boss"
	environment["game_ids"] = [game_id]
	environment["turns"] = 0
	var generated_state := game.generate_environment_state(run_state, environment, run_state.create_rng("c1_%s_state" % game_id))
	if not generated_state.is_empty():
		environment["game_states"] = {game_id: generated_state}
	run_state.set_environment(environment)
	if RunState.GRAND_CASINO_TABLE_GAME_IDS.has(game_id):
		run_state.buy_grand_casino_chips(run_state.bankroll, run_state.grand_casino_chip_exchange_rate())
	return run_state


func _grand_casino_game_cheat_result(game_id: String, game: GameModule, run_state: RunState) -> Dictionary:
	return _grand_casino_game_cheat_result_for_action(game_id, "", game, run_state)


func _grand_casino_game_cheat_result_for_action(game_id: String, action_id: String, game: GameModule, run_state: RunState) -> Dictionary:
	var environment: Dictionary = run_state.current_environment
	var rng := run_state.create_rng("c1_%s_heat_result" % game_id)
	match game_id:
		"bar_dice":
			var roll_command: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {}, run_state, environment)
			var dice_ui: Dictionary = roll_command.get("ui_state", {})
			if action_id == "palmed_swap":
				var palm_command: Dictionary = game.surface_action_command("bar_dice_palm", 0, false, dice_ui, run_state, environment)
				return game.resolve_with_context("palmed_swap", 10, run_state, environment, rng, palm_command.get("ui_state", dice_ui))
			var load_command: Dictionary = game.surface_action_command("bar_dice_load", 0, false, dice_ui, run_state, environment)
			dice_ui = _bar_dice_controlled_roll_timed_ui(game, run_state, load_command.get("ui_state", dice_ui), 999)
			return game.resolve_with_context("loaded_toss", 10, run_state, environment, rng, dice_ui)
		"video_poker":
			var deal_command: Dictionary = game.surface_action_command("video_poker_deal", 0, false, {}, run_state, environment)
			var poker_ui: Dictionary = _video_poker_holdout_timed_ui(game, run_state, deal_command.get("ui_state", {}), 999)
			return game.resolve_with_context("mark_holds", 5, run_state, environment, rng, poker_ui)
		"blackjack":
			if action_id == "peek_hole_card":
				return game.resolve_with_context("peek_hole_card", 0, run_state, environment, rng, {})
			if action_id == "count_cards":
				return game.resolve_with_context("count_cards", 0, run_state, environment, rng, _xgame_blackjack_dirty_count_ui())
			return game.resolve_with_context("play_basic", 10, run_state, environment, rng, _xgame_blackjack_dirty_count_ui())
		"pull_tabs":
			run_state.add_item("tab_detector")
			return game.resolve_with_context("tab_detector_scan", 0, run_state, environment, rng, {})
		"slot":
			var machine: Dictionary = _slot_machine(game.definition, run_state, "pinball", "classic_3_reel", "standard", "plain")
			_slot_store_machine(run_state, environment, machine)
			return game.resolve_with_context("nudge", 10, run_state, environment, rng, {})
		"baccarat":
			if action_id == "edge_sort":
				return _baccarat_edge_sort_contract_result(game, run_state, environment, rng)
			var baccarat_command: Dictionary = game.surface_action_command("baccarat_read_shoe", 0, false, {}, run_state, environment)
			return game.resolve_with_context("read_baccarat_shoe", 0, run_state, environment, rng, baccarat_command.get("ui_state", {}))
		"roulette":
			if action_id == "past_post":
				return _roulette_past_post_contract_result(game, run_state, environment, rng)
			var roulette_command: Dictionary = game.surface_action_command("roulette_read_wheel", 0, false, {}, run_state, environment)
			return game.resolve_with_context("read_wheel_bias", 0, run_state, environment, rng, roulette_command.get("ui_state", {}))
	return {}


func _baccarat_edge_sort_contract_result(game: GameModule, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	game.surface_action_command("baccarat_edge_sort", 0, false, {}, run_state, environment)
	game.resolve_with_context("deal_baccarat", 20, run_state, environment, run_state.create_rng("c5_baccarat_edge_1"), {"baccarat_sit_out": true})
	game.resolve_with_context("deal_baccarat", 20, run_state, environment, run_state.create_rng("c5_baccarat_edge_2"), {"baccarat_sit_out": true})
	var ready_table: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("baccarat", {}) as Dictionary)
	var ready_challenge: Dictionary = ready_table.get("edge_sort_challenge", {}) if typeof(ready_table.get("edge_sort_challenge", {})) == TYPE_DICTIONARY else {}
	return game.resolve_with_context("edge_sort", 0, run_state, environment, rng, {"edge_sort_challenge": ready_challenge, "edge_sort_answer_mode": "blown"})


func _roulette_past_post_contract_result(game: GameModule, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var chip := 5
	var spin_ui := {"roulette_bets": [game.call("_default_smoke_bet", chip)], "selected_chip": chip}
	game.resolve_with_context("spin_roulette", chip, run_state, environment, run_state.create_rng("c5_roulette_past_post_spin"), spin_ui)
	var table: Dictionary = ((environment.get("game_states", {}) as Dictionary).get("roulette", {}) as Dictionary)
	var last_result: Dictionary = table.get("last_result", {}) if typeof(table.get("last_result", {})) == TYPE_DICTIONARY else {}
	var payout_ui := {
		"selected_chip": chip,
		"surface_time_msec": int(last_result.get("resolved_at_msec", 0)) + 5610,
	}
	var arm_command: Dictionary = game.surface_action_command("roulette_past_post", 0, false, payout_ui, run_state, environment)
	var arm_ui: Dictionary = arm_command.get("ui_state", payout_ui)
	var challenge: Dictionary = arm_ui.get("past_post_challenge", {}) if typeof(arm_ui.get("past_post_challenge", {})) == TYPE_DICTIONARY else {}
	var input_msec := int(challenge.get("window_start_msec", int(payout_ui.get("surface_time_msec", 0)))) + 900
	arm_ui["surface_time_msec"] = input_msec
	arm_ui["past_post_input_msec"] = input_msec
	arm_ui["selected_action_id"] = "past_post"
	arm_ui["selected_action_kind"] = "cheat"
	var confirm_command: Dictionary = game.surface_action_command("roulette_past_post", 0, false, arm_ui, run_state, environment)
	return game.resolve_with_context("past_post", chip, run_state, environment, rng, confirm_command.get("ui_state", arm_ui))


func _check_premium_grand_casino_table_contract(library: ContentLibrary, game_id: String, game: GameModule, failures: Array) -> void:
	var boss_archetype := _archetype_by_id(library, "grand_casino")
	if boss_archetype.is_empty():
		failures.append("Grand Casino premium %s audit requires the grand_casino archetype." % game_id)
		return
	if not _string_array(boss_archetype.get("game_pool", [])).has(game_id):
		failures.append("Grand Casino premium audit expected %s in the boss-floor game pool." % game_id)
		return

	var progress_run := _grand_casino_game_fixture_run(library, boss_archetype, game_id, game, "C3-GRAND-PROGRESS-%s" % game_id.to_upper())
	var entry_bankroll := int(progress_run.narrative_flags.get("grand_casino_entry_bankroll", progress_run.bankroll))
	var legal_result := _premium_grand_casino_legal_result(game_id, game, progress_run)
	if not bool(legal_result.get("ok", false)):
		failures.append("Grand Casino premium %s legal fixture did not resolve: %s" % [game_id, str(legal_result.get("message", ""))])
	else:
		var progress_status: Dictionary = progress_run.demo_objective_status()
		if int(progress_status.get("grand_casino_games_played", 0)) != 1:
			failures.append("Grand Casino premium %s result did not count toward high-roller games." % game_id)
		if int(progress_status.get("grand_casino_net_winnings", 999999)) != progress_run.bankroll - entry_bankroll:
			failures.append("Grand Casino premium %s result did not update high-roller net winnings." % game_id)
		if progress_run.run_status == RunState.RUN_STATUS_FAILED:
			failures.append("Grand Casino premium %s legal result unexpectedly failed the run." % game_id)

	var pressure_run := _grand_casino_game_fixture_run(library, boss_archetype, game_id, game, "C3-GRAND-PRESSURE-%s" % game_id.to_upper())
	var objective: Dictionary = boss_archetype.get("demo_objective", {}) if typeof(boss_archetype.get("demo_objective", {})) == TYPE_DICTIONARY else {}
	var showdown_threshold := clampi(int(objective.get("showdown_heat_threshold", 70)), 1, 100)
	pressure_run.add_suspicion("c3_premium_preheat_%s" % game_id, maxi(0, showdown_threshold - 1), "behavior")
	var pressure_result := _premium_grand_casino_read_result(game_id, game, pressure_run)
	if not bool(pressure_result.get("ok", false)):
		failures.append("Grand Casino premium %s read fixture did not resolve: %s" % [game_id, str(pressure_result.get("message", ""))])
	else:
		var pressure_status: Dictionary = pressure_run.demo_objective_status()
		if not bool(pressure_run.narrative_flags.get("grand_casino_attention_watched_cheat", false)):
			failures.append("Grand Casino premium %s watched read did not mark watched cheat attention." % game_id)
		if not bool(pressure_status.get("staff_attention_active", false)):
			failures.append("Grand Casino premium %s watched read did not expose staff attention." % game_id)
		if not bool(pressure_status.get("showdown_pending", false)) and not bool(pressure_status.get("showdown_active", false)):
			failures.append("Grand Casino premium %s watched read did not feed showdown pressure." % game_id)
		var message := str(pressure_result.get("message", ""))
		if message.find("Rourke") == -1 and message.find("staff") == -1 and message.find("patron") == -1 and message.find("Security") == -1:
			failures.append("Grand Casino premium %s read result did not communicate staff or patron pressure." % game_id)

	print("GRAND_CASINO_PREMIUM_TABLE %s games=%d pressure=%s staff=%s" % [
		game_id,
		int(progress_run.demo_objective_status().get("grand_casino_games_played", 0)),
		str(pressure_run.demo_objective_status().get("objective_state", "")),
		str(pressure_run.demo_objective_status().get("staff_attention_active", false)),
	])


func _premium_grand_casino_legal_result(game_id: String, game: GameModule, run_state: RunState) -> Dictionary:
	var environment: Dictionary = run_state.current_environment
	match game_id:
		"baccarat":
			var baccarat_ui := {"baccarat_bets": {"player": 20}}
			return game.resolve_with_context("deal_baccarat", 20, run_state, environment, run_state.create_rng("c3_baccarat_legal"), baccarat_ui)
		"roulette":
			var roulette_ui := {"roulette_bets": [game.call("_default_smoke_bet", 10)]}
			return game.resolve_with_context("spin_roulette", 10, run_state, environment, run_state.create_rng("c3_roulette_legal"), roulette_ui)
	return {}


func _premium_grand_casino_read_result(game_id: String, game: GameModule, run_state: RunState) -> Dictionary:
	var environment: Dictionary = run_state.current_environment
	match game_id:
		"baccarat":
			var baccarat_command: Dictionary = game.surface_action_command("baccarat_read_shoe", 0, false, {}, run_state, environment)
			return game.resolve_with_context("read_baccarat_shoe", 0, run_state, environment, run_state.create_rng("c3_baccarat_read"), baccarat_command.get("ui_state", {}))
		"roulette":
			var roulette_command: Dictionary = game.surface_action_command("roulette_read_wheel", 0, false, {}, run_state, environment)
			return game.resolve_with_context("read_wheel_bias", 0, run_state, environment, run_state.create_rng("c3_roulette_read"), roulette_command.get("ui_state", {}))
	return {}


func _xgame_assert_shift(game_id: String, dimension: String, baseline: int, modified: int, direction: String, failures: Array) -> void:
	var ok := modified > baseline if direction == "up" else modified < baseline
	print("XGAME_INTEGRATION game=%s dim=%s baseline=%d modified=%d shift=%s" % [game_id, dimension, baseline, modified, "ok" if ok else "FAIL"])
	if not ok:
		failures.append("Cross-game integration %s/%s did not shift %s (baseline=%d modified=%d)." % [game_id, dimension, direction, baseline, modified])


func _xgame_luck_pair(game_id: String, game: GameModule, failures: Array) -> Dictionary:
	match game_id:
		"blackjack":
			return {
				"baseline": _xgame_blackjack_win_metric(game, 0, ""),
				"modified": _xgame_blackjack_win_metric(game, 10, ""),
			}
		"pull_tabs":
			return {
				"baseline": _xgame_pull_tabs_redeem_metric(game, 0, ""),
				"modified": _xgame_pull_tabs_redeem_metric(game, 10, ""),
			}
	for attempt in range(80):
		var seed := "XGAME-LUCK-%s-%02d" % [game_id, attempt]
		var baseline := _xgame_win_metric(game_id, game, seed, 0, "")
		if baseline <= 0:
			continue
		var modified := _xgame_win_metric(game_id, game, seed, 10, "")
		if modified > baseline:
			return {"baseline": baseline, "modified": modified}
	failures.append("Cross-game integration could not find a deterministic paying %s sample for luck." % game_id)
	return {"baseline": 0, "modified": 0}


func _xgame_win_metric(game_id: String, game: GameModule, seed: String, luck: int, item_id: String) -> int:
	match game_id:
		"bar_dice":
			return _xgame_bar_dice_win_metric(game, seed, luck, item_id)
		"video_poker":
			return _xgame_video_poker_win_metric(game, seed, luck, item_id)
		"slot":
			return _xgame_slot_win_metric(game, seed, luck, item_id)
		_:
			return 0


func _xgame_heat_pair(game_id: String, game: GameModule, drunk_modified: bool, watched_modified: bool, item_id: String) -> Dictionary:
	var seed := "XGAME-HEAT-%s-%s-%s-%s" % [game_id, item_id, str(drunk_modified), str(watched_modified)]
	var baseline := _xgame_cheat_heat_metric(game_id, game, seed, false, false, "")
	var modified := _xgame_cheat_heat_metric(game_id, game, seed, drunk_modified, watched_modified, item_id)
	return {"baseline": baseline, "modified": modified}


func _xgame_item_heat_pair(game_id: String, game: GameModule, item_id: String) -> Dictionary:
	var fixed := _xgame_heat_pair(game_id, game, false, false, item_id)
	if int(fixed.get("modified", 0)) < int(fixed.get("baseline", 0)):
		return fixed
	for attempt in range(80):
		var seed := "XGAME-ITEM-%s-%s-%02d" % [game_id, item_id, attempt]
		var baseline := _xgame_cheat_heat_metric(game_id, game, seed, false, false, "")
		var modified := _xgame_cheat_heat_metric(game_id, game, seed, false, false, item_id)
		if modified < baseline:
			return {"baseline": baseline, "modified": modified}
	return fixed


func _xgame_cheat_heat_metric(game_id: String, game: GameModule, seed: String, drunk: bool, watched: bool, item_id: String) -> int:
	match game_id:
		"bar_dice":
			return _xgame_bar_dice_heat_metric(game, seed, drunk, watched, item_id)
		"video_poker":
			return _xgame_video_poker_heat_metric(game, seed, drunk, watched, item_id)
		"blackjack":
			return _xgame_blackjack_heat_metric(game, seed, drunk, watched, item_id)
		"pull_tabs":
			return _xgame_pull_tabs_heat_metric(game, seed, drunk, watched, item_id)
		"slot":
			return _xgame_slot_heat_metric(game, seed, drunk, watched, item_id)
		_:
			return 0


func _xgame_run(seed: String, bankroll: int, drunk: bool, item_id: String) -> RunState:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new(seed)
	run_state.bankroll = bankroll
	run_state.drunk_level = 85 if drunk else 0
	if not item_id.is_empty():
		run_state.add_item(item_id)
	return run_state


func _xgame_environment(game_id: String, watched: bool) -> Dictionary:
	var environment := _surface_contract_environment()
	environment["id"] = "xgame_%s_room" % game_id
	environment["game_ids"] = [game_id]
	environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 100}
	environment["turns"] = 0 if watched else 1
	environment["security_profile"] = {
		"strictness": "tight",
		"pit_boss": {"enabled": true, "cycle_length": 2, "watched_turns": 1, "cheat_heat_bonus": 20},
	}
	return environment


func _xgame_bar_dice_run(game: GameModule, seed: String, luck: int, drunk: bool, watched: bool, item_id: String) -> RunState:
	var run_state: RunState = _xgame_run(seed, 100000, drunk, item_id)
	run_state.baseline_luck = luck
	var environment: Dictionary = _xgame_environment("bar_dice", watched)
	environment["game_states"] = {"bar_dice": _bar_dice_state_for(game, run_state, environment, "ship_captain_crew", "standard", "pot_rake")}
	run_state.current_environment = environment.duplicate(true)
	return run_state


func _xgame_bar_dice_win_metric(game: GameModule, seed: String, luck: int, item_id: String) -> int:
	var run_state: RunState = _xgame_bar_dice_run(game, seed, luck, false, false, item_id)
	var result: Dictionary = _bar_dice_play_round(game, run_state, run_state.create_rng("xgame_bar_dice_win"), "roll")
	return int(result.get("bankroll_delta", 0))


func _xgame_bar_dice_heat_metric(game: GameModule, seed: String, drunk: bool, watched: bool, item_id: String) -> int:
	var run_state: RunState = _xgame_bar_dice_run(game, seed, 0, drunk, watched, item_id)
	var roll_command: Dictionary = game.surface_action_command("bar_dice_roll", 0, false, {}, run_state, run_state.current_environment)
	var ui: Dictionary = roll_command.get("ui_state", {})
	var load_command: Dictionary = game.surface_action_command("bar_dice_load", 0, false, ui, run_state, run_state.current_environment)
	ui = _bar_dice_controlled_roll_timed_ui(game, run_state, load_command.get("ui_state", ui), 0)
	var result: Dictionary = game.resolve_with_context("loaded_toss", 10, run_state, run_state.current_environment, run_state.create_rng("xgame_bar_dice_heat"), ui)
	return int(result.get("suspicion_delta", 0))


func _xgame_video_poker_run(game: GameModule, seed: String, luck: int, drunk: bool, watched: bool, item_id: String) -> RunState:
	var run_state: RunState = _vp_fresh(game, "jacks_or_better", seed, 100000, "standard", 1, 1)
	run_state.baseline_luck = luck
	run_state.drunk_level = 85 if drunk else 0
	if not item_id.is_empty():
		run_state.add_item(item_id)
	run_state.current_environment["security_profile"] = _xgame_environment("video_poker", watched).get("security_profile", {})
	run_state.current_environment["turns"] = 0 if watched else 1
	return run_state


func _xgame_video_poker_win_metric(game: GameModule, seed: String, luck: int, item_id: String) -> int:
	var run_state: RunState = _xgame_video_poker_run(game, seed, luck, false, false, item_id)
	var result: Dictionary = _video_poker_play_hand(game, run_state, run_state.create_rng("xgame_video_poker_win"), "draw")
	return int(result.get("bankroll_delta", 0))


func _xgame_video_poker_heat_metric(game: GameModule, seed: String, drunk: bool, watched: bool, item_id: String) -> int:
	var run_state: RunState = _xgame_video_poker_run(game, seed, 0, drunk, watched, item_id)
	var deal_command: Dictionary = game.surface_action_command("video_poker_deal", 0, false, {}, run_state, run_state.current_environment)
	var poker_ui: Dictionary = _video_poker_holdout_timed_ui(game, run_state, deal_command.get("ui_state", {}), 0)
	var result: Dictionary = game.resolve_with_context("mark_holds", 5, run_state, run_state.current_environment, run_state.create_rng("xgame_video_poker_heat"), poker_ui)
	return int(result.get("suspicion_delta", 0))


func _xgame_blackjack_run(game: GameModule, seed: String, luck: int, drunk: bool, watched: bool, item_id: String) -> RunState:
	var run_state: RunState = _xgame_run(seed, 100000, drunk, item_id)
	run_state.baseline_luck = luck
	var environment: Dictionary = _xgame_environment("blackjack", watched)
	environment["game_states"] = {"blackjack": game.generate_environment_state(run_state, environment, run_state.create_rng("xgame_blackjack_state"))}
	run_state.current_environment = environment.duplicate(true)
	return run_state


func _xgame_blackjack_win_ui() -> Dictionary:
	return {
		"selected_stake": 10,
		"player_hands": [{"cards": [{"rank": 10, "suit": 0}, {"rank": 9, "suit": 1}], "stood": true, "wager_multiplier": 1, "blackjack_eligible": true}],
		"dealer_cards": [{"rank": 10, "suit": 2}, {"rank": 7, "suit": 3}],
		"patron_hands": [],
		"moves_made": true,
	}


func _xgame_blackjack_dirty_count_ui() -> Dictionary:
	var ui: Dictionary = _xgame_blackjack_win_ui()
	ui["cheats_used"] = {"count_cards": true}
	ui["count_attempted"] = true
	ui["count_answered"] = true
	ui["count_correct"] = false
	ui["count_delta"] = 0
	ui["count_challenge"] = {
		"missed_icons": ["xgame_miss"],
		"bad_hits": 1,
		"target_delta": 2,
		"dealer_attention_risk": 28,
	}
	return ui


func _xgame_blackjack_win_metric(game: GameModule, luck: int, item_id: String) -> int:
	var run_state: RunState = _xgame_blackjack_run(game, "XGAME-BLACKJACK-WIN", luck, false, false, item_id)
	var result: Dictionary = game.resolve_with_context("play_basic", 10, run_state, run_state.current_environment, run_state.create_rng("xgame_blackjack_win"), _xgame_blackjack_win_ui())
	return int(result.get("bankroll_delta", 0))


func _xgame_blackjack_heat_metric(game: GameModule, seed: String, drunk: bool, watched: bool, item_id: String) -> int:
	var run_state: RunState = _xgame_blackjack_run(game, seed, 0, drunk, watched, item_id)
	var result: Dictionary = game.resolve_with_context("count_cards", 10, run_state, run_state.current_environment, run_state.create_rng("xgame_blackjack_heat"), _xgame_blackjack_dirty_count_ui())
	return int(result.get("suspicion_delta", 0))


func _xgame_pull_tabs_run(game: GameModule, seed: String, luck: int, drunk: bool, watched: bool, item_id: String) -> RunState:
	var run_state: RunState = _xgame_run(seed, 100000, drunk, item_id)
	run_state.baseline_luck = luck
	var environment: Dictionary = _xgame_environment("pull_tabs", watched)
	environment["game_states"] = {"pull_tabs": game.generate_environment_state(run_state, environment, run_state.create_rng("xgame_pull_tabs_state"))}
	run_state.current_environment = environment.duplicate(true)
	return run_state


func _xgame_pull_tabs_redeem_metric(game: GameModule, luck: int, item_id: String) -> int:
	var run_state: RunState = _xgame_pull_tabs_run(game, "XGAME-PULL-TABS-REDEEM", luck, false, false, item_id)
	var ticket_payload: Dictionary = _pull_tab_test_ticket_result("xgame", 30)
	var ticket: Dictionary = ticket_payload.get("pull_tab_ticket", {})
	ticket["price"] = 10
	ticket_payload["pull_tab_ticket"] = ticket
	_set_pull_tab_loser_count(run_state.current_environment, 3)
	_inject_pull_tab_winner(run_state.current_environment, ticket_payload)
	var command: Dictionary = game.environment_action_command("ticket_redeemer", "redeem_pull_tab_winners", run_state, run_state.current_environment, run_state.create_rng("xgame_pull_tabs_redeem"))
	var result: Dictionary = command.get("result", {})
	return int(result.get("bankroll_delta", 0))


func _xgame_pull_tabs_heat_metric(game: GameModule, seed: String, drunk: bool, watched: bool, item_id: String) -> int:
	var run_state: RunState = _xgame_pull_tabs_run(game, seed, 0, drunk, watched, item_id)
	run_state.add_item("tab_detector")
	var result: Dictionary = game.resolve_with_context("tab_detector_scan", 0, run_state, run_state.current_environment, run_state.create_rng("xgame_pull_tabs_heat"), {})
	return int(result.get("suspicion_delta", 0))


func _xgame_slot_run(seed: String, luck: int, drunk: bool, watched: bool, item_id: String) -> RunState:
	var run_state: RunState = _slot_run_state(seed, 100000)
	run_state.baseline_luck = luck
	run_state.drunk_level = 85 if drunk else 0
	if not item_id.is_empty():
		run_state.add_item(item_id)
	var environment: Dictionary = _slot_environment()
	environment["id"] = "xgame_slot_room"
	environment["security_profile"] = _xgame_environment("slot", watched).get("security_profile", {})
	environment["turns"] = 0 if watched else 1
	run_state.current_environment = environment.duplicate(true)
	return run_state


func _xgame_slot_win_metric(game: GameModule, seed: String, luck: int, item_id: String) -> int:
	var definition: Dictionary = game.definition
	var run_state: RunState = _xgame_slot_run(seed, luck, false, false, item_id)
	var environment: Dictionary = run_state.current_environment
	var machine: Dictionary = _slot_machine(definition, run_state, "pinball", "classic_3_reel", "standard", "plain")
	_slot_store_machine(run_state, environment, machine)
	var rng := run_state.create_rng("xgame_slot_win")
	var best_delta := 0
	for _spin_index in range(120):
		var result: Dictionary = game.resolve_with_context("spin", 10, run_state, environment, rng, {})
		if bool(result.get("ok", false)):
			best_delta = maxi(best_delta, int(result.get("bankroll_delta", 0)))
			GameModule.apply_result(run_state, result, rng)
			_slot_complete_active_bonus(game, run_state, environment, rng)
	return best_delta


func _xgame_slot_heat_metric(game: GameModule, seed: String, drunk: bool, watched: bool, item_id: String) -> int:
	var definition: Dictionary = game.definition
	var run_state: RunState = _xgame_slot_run(seed, 0, drunk, watched, item_id)
	var environment: Dictionary = run_state.current_environment
	var machine: Dictionary = _slot_machine(definition, run_state, "pinball", "classic_3_reel", "standard", "plain")
	_slot_store_machine(run_state, environment, machine)
	var result: Dictionary = game.resolve_with_context("nudge", 10, run_state, environment, run_state.create_rng("xgame_slot_heat"), {})
	return int(result.get("suspicion_delta", 0))


func _check_generic_game_module_contract(game: GameModule, failures: Array) -> void:
	var game_id := game.get_id()
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("GAME-CONTRACT-%s" % game_id.to_upper())
	var environment := _surface_contract_environment()
	environment["game_ids"] = [game_id]
	var generated_state := game.generate_environment_state(run_state, environment, run_state.create_rng("%s_generated_state" % game_id))
	if not generated_state.is_empty():
		environment["game_states"] = {game_id: generated_state}
	run_state.current_environment = environment.duplicate(true)

	var model := game.gameplay_model()
	if model != GameModule.GAMEPLAY_MODEL_GENERIC_ODDS and model != GameModule.GAMEPLAY_MODEL_FULL_SIMULATION:
		failures.append("%s returned an unknown gameplay model: %s." % [game_id, model])
	if game.is_full_simulation() != (model == GameModule.GAMEPLAY_MODEL_FULL_SIMULATION):
		failures.append("%s full-simulation helper does not match gameplay_model." % game_id)

	var environment_before_enter := JSON.stringify(environment)
	var enter_result := game.enter(run_state, environment)
	if not bool(enter_result.get("ok", false)):
		failures.append("%s did not enter cleanly through the generic contract." % game_id)
	if JSON.stringify(environment) != environment_before_enter:
		failures.append("%s entry mutated environment state in the generic contract." % game_id)

	var action_presentation := game.actions(run_state, environment)
	if typeof(action_presentation.get("legal_actions", [])) != TYPE_ARRAY:
		failures.append("%s did not expose legal_actions as an array." % game_id)
	if typeof(action_presentation.get("cheat_actions", [])) != TYPE_ARRAY:
		failures.append("%s did not expose cheat_actions as an array." % game_id)

	var surface := game.surface_state(run_state, environment, {})
	if not surface.is_empty():
		_check_surface_spec_shape(game_id, surface, failures)
		_check_surface_draw_harness(game, surface, failures)
		_check_surface_bindings_non_mutating(game, surface, run_state, environment, failures)

	var object_state := game.environment_object_state(run_state, environment)
	if typeof(object_state) != TYPE_DICTIONARY:
		failures.append("%s environment_object_state did not return a dictionary." % game_id)
	elif not object_state.is_empty():
		if typeof(object_state.get("runtime_state", {})) != TYPE_DICTIONARY:
			failures.append("%s environment_object_state runtime_state must be a dictionary." % game_id)
		if typeof(object_state.get("visual_state", {})) != TYPE_DICTIONARY:
			failures.append("%s environment_object_state visual_state must be a dictionary." % game_id)

	var legal_actions: Array = action_presentation.get("legal_actions", [])
	if not legal_actions.is_empty() and typeof(legal_actions[0]) == TYPE_DICTIONARY:
		var before := _run_state_result_snapshot(run_state)
		var result := game.resolve_with_context(str((legal_actions[0] as Dictionary).get("id", "")), 1, run_state, environment, run_state.create_rng("%s_generic_resolve" % game_id), {})
		if bool(result.get("ok", false)):
			_check_action_result_shape(result, str(result.get("action_kind", "legal")), failures)
			_check_action_result_application_contract(before, run_state, result, "%s generic result" % game_id, failures)

	run_state.set_environment(environment)
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	if not generated_state.is_empty() and not (restored.current_environment.get("game_states", {}) as Dictionary).has(game_id):
		failures.append("%s generated game state did not round-trip through RunState." % game_id)


func _check_surface_spec_shape(game_id: String, surface: Dictionary, failures: Array) -> void:
	for key in ["surface_renderer", "surface_life", "surface_cast", "surface_action_bindings", "native_selected_surface_actions", "surface_animation_channels", "surface_audio", "surface_action_blocks", "surface_realtime_state_refresh"]:
		if not surface.has(key):
			failures.append("%s surface spec missing key: %s." % [game_id, key])
	if typeof(surface.get("surface_action_bindings", {})) != TYPE_DICTIONARY:
		failures.append("%s surface_action_bindings must be a dictionary." % game_id)
	if typeof(surface.get("native_selected_surface_actions", [])) != TYPE_ARRAY:
		failures.append("%s native_selected_surface_actions must be an array." % game_id)
	if typeof(surface.get("surface_animation_channels", [])) != TYPE_ARRAY:
		failures.append("%s surface_animation_channels must be an array." % game_id)
	for channel_value in surface.get("surface_animation_channels", []):
		if typeof(channel_value) != TYPE_DICTIONARY:
			failures.append("%s surface animation channel must be a dictionary." % game_id)
			continue
		var channel: Dictionary = channel_value
		if str(channel.get("id", "")).is_empty():
			failures.append("%s surface animation channel is missing id." % game_id)
		if not channel.has("active_id") or not channel.has("duration_msec") or not channel.has("started_msec"):
			failures.append("%s surface animation channel is missing timing fields." % game_id)
	if typeof(surface.get("surface_audio", {})) != TYPE_DICTIONARY:
		failures.append("%s surface_audio must be a dictionary." % game_id)
	if typeof(surface.get("surface_action_blocks", [])) != TYPE_ARRAY:
		failures.append("%s surface_action_blocks must be an array." % game_id)
	if typeof(surface.get("surface_realtime_state_refresh", false)) != TYPE_BOOL:
		failures.append("%s surface_realtime_state_refresh must be a boolean." % game_id)


func _check_surface_draw_harness(game: GameModule, surface: Dictionary, failures: Array) -> void:
	var harness := SurfaceHarness.new()
	harness.setup(surface)
	var drew := false
	var draw_failed := false
	var draw_message := ""
	var result = game.draw_surface(harness, surface, {"contract_harness": true})
	drew = bool(result)
	if draw_failed:
		failures.append("%s draw_surface failed in harness: %s." % [game.get_id(), draw_message])
	elif not drew:
		failures.append("%s surface spec exists but draw_surface did not render through the harness." % game.get_id())


func _check_surface_bindings_non_mutating(game: GameModule, surface: Dictionary, run_state: RunState, environment: Dictionary, failures: Array) -> void:
	var bindings: Dictionary = surface.get("surface_action_bindings", {})
	for kind in ["legal", "cheat"]:
		var binding: Dictionary = bindings.get(kind, {}) if typeof(bindings.get(kind, {})) == TYPE_DICTIONARY else {}
		var action := str(binding.get("action", ""))
		if action.is_empty():
			continue
		var before_run_state := JSON.stringify(run_state.to_dict())
		var command := game.surface_action_command(action, int(binding.get("index", 0)), false, {}, run_state, environment)
		if JSON.stringify(run_state.to_dict()) != before_run_state:
			failures.append("%s %s surface binding mutated RunState before resolution." % [game.get_id(), kind])
		if not bool(command.get("handled", false)):
			failures.append("%s %s surface binding was not handled." % [game.get_id(), kind])


# Checks that scalable run actions are resolved outside the FoundationMain UI.
func _check_run_action_service_boundary(library: ContentLibrary, failures: Array) -> void:
	var item_definition := _first_definition(library.items)
	var service_definition := _first_definition(library.services)
	var lender_definition := _first_definition(library.lenders)
	if item_definition.is_empty() or service_definition.is_empty() or lender_definition.is_empty():
		failures.append("RunActionService boundary check needs item, service, and lender definitions.")
		return
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("RUN-ACTION-SERVICE")
	run_state.bankroll = 200
	run_state.current_environment = {
		"id": "run_action_service_room",
		"display_name": "Run Action Service Room",
		"kind": "shop",
		"archetype_id": "run_action_service_fixture",
		"item_offers": [{
			"id": str(item_definition.get("id", "")),
			"display_name": str(item_definition.get("display_name", "")),
			"price": 1,
		}],
		"service_ids": [str(service_definition.get("id", ""))],
		"lender_hooks": [str(lender_definition.get("id", ""))],
		"layout": {},
	}
	run_state.environment_history = [{
		"id": "run_action_service_previous_room",
		"display_name": "Previous Room",
	}, {
		"id": "run_action_service_second_previous_room",
		"display_name": "Second Previous Room",
	}]
	var resolver: RunActionService = RunActionServiceScript.new()
	resolver.setup(library, run_state)

	var item_id := str(item_definition.get("id", ""))
	var purchase := resolver.buy_item_offer(item_id)
	if not bool(purchase.get("ok", false)):
		failures.append("RunActionService did not buy an item offer: %s" % str(purchase.get("message", "")))
	elif not run_state.inventory.has(item_id) or not (run_state.current_environment.get("item_offers", []) as Array).is_empty():
		failures.append("RunActionService item purchase did not add inventory and remove the offer.")

	run_state.current_environment["item_offers"] = [{"id": item_id, "price": 1}]
	var sale := resolver.sell_inventory_item(item_id)
	if not bool(sale.get("ok", false)):
		failures.append("RunActionService did not sell a sellable inventory item: %s" % str(sale.get("message", "")))
	elif run_state.inventory.has(item_id):
		failures.append("RunActionService item sale did not remove the sold item from inventory.")

	var service_id := str(service_definition.get("id", ""))
	var service_result := resolver.use_hook("service", service_id)
	if bool(resolver.hook_option("service", service_id).get("mutation_supported", false)) and not bool(service_result.get("ok", false)):
		failures.append("RunActionService did not resolve a supported service hook: %s" % str(service_result.get("message", "")))

	var lender_id := str(lender_definition.get("id", ""))
	var lender_result := resolver.use_hook("lender", lender_id)
	if bool(resolver.hook_option("lender", lender_id).get("mutation_supported", false)) and not bool(lender_result.get("ok", false)):
		failures.append("RunActionService did not resolve a supported lender hook: %s" % str(lender_result.get("message", "")))


func _check_mutation_firewall_foundation(library: ContentLibrary, failures: Array) -> void:
	var game_ids := ["pull_tabs", "slot", "bar_dice", "blackjack", "baccarat", "roulette", "video_poker"]
	for game_id_value in game_ids:
		var game_id := str(game_id_value)
		var game: GameModule = _load_surface_contract_game(library, game_id, failures)
		if game == null:
			continue
		_check_game_read_path_mutation_firewall(library, game, game_id, failures)
	_check_world_map_read_path_mutation_firewall(library, failures)
	_check_run_action_service_read_path_mutation_firewall(library, failures)
	_check_event_choice_read_path_mutation_firewall(library, failures)


func _check_ui_state_machine_input_fuzz_foundation(library: ContentLibrary, failures: Array) -> void:
	var app_value: Variant = MainScene.instantiate()
	if not app_value is Control:
		failures.append("SB.4 input fuzz could not instantiate the FoundationMain scene.")
		return
	var app: Control = app_value
	root.add_child(app)
	if not bool(app.call("uses_foundation_runtime")):
		app.call("_ready")
	if not bool(app.call("uses_foundation_runtime")):
		failures.append("SB.4 input fuzz scene is not using the foundation runtime.")
		_sb4_dispose_app(app)
		return
	_sb4_assert_overlay_contract(app, "initial scene", failures)
	_sb4_check_event_modal_routes(library, app, failures)
	_sb4_check_wager_modal_routes(library, app, failures)
	_sb4_check_travel_transition_routes(app, failures)
	_sb4_check_seeded_menu_canvas_routes(app, failures)
	_sb4_check_background_runtime_does_not_block_active_game(library, app, failures)
	_sb4_dispose_app(app)


func _sb4_dispose_app(app: Control) -> void:
	if app == null:
		return
	if app.get_parent() != null:
		app.get_parent().remove_child(app)
	app.free()


func _sb4_check_background_runtime_does_not_block_active_game(library: ContentLibrary, app: Control, failures: Array) -> void:
	var blackjack: GameModule = _load_surface_contract_game(library, "blackjack", failures)
	var slot: GameModule = _load_surface_contract_game(library, "slot", failures)
	if blackjack == null or slot == null:
		return
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SB4-BLACKJACK-SLOT-RUNTIME-BLOCK")
	run_state.bankroll = 100
	var environment := _surface_contract_environment()
	environment["game_ids"] = ["blackjack", "slot"]
	environment["economic_profile"] = {"stake_floor": 1, "stake_ceiling": 100}
	var blackjack_table: Dictionary = blackjack.generate_environment_state(run_state, environment, run_state.create_rng("sb4_blackjack_table"))
	blackjack_table["shoe_cursor"] = 0
	blackjack_table["patrons"] = []
	blackjack_table["side_bets"] = []
	blackjack_table["rules"] = {"dealer_hits_soft_17": false, "double_after_split": true, "split_aces_one_card": true, "max_split_hands": 4, "late_surrender": true}
	blackjack_table["shoe"] = [
		{"rank": 14, "suit": 0}, {"rank": 9, "suit": 2}, {"rank": 13, "suit": 1}, {"rank": 7, "suit": 3},
		{"rank": 5, "suit": 0}, {"rank": 6, "suit": 1}, {"rank": 8, "suit": 2}, {"rank": 4, "suit": 3}
	]
	var slot_machine: Dictionary = slot.generate_environment_state(run_state, environment, run_state.create_rng("sb4_background_slot"))
	slot_machine = SlotMachineStateScript.set_selected_bet(slot_machine, "bet_20")
	slot_machine["slot_autoplay_active"] = true
	slot_machine["slot_autoplay_next_msec"] = 1
	environment["game_states"] = {"blackjack": blackjack_table, "slot": SlotMachineStateScript.normalize(slot_machine)}
	run_state.set_environment(environment)
	var deal_command := blackjack.surface_action_command("blackjack_deal", 0, false, {"selected_stake": 60}, run_state, run_state.current_environment)
	var placed := blackjack.resolve_with_context("blackjack_place_bet", 60, run_state, run_state.current_environment, run_state.create_rng("sb4_blackjack_place"), deal_command.get("ui_state", {}))
	var placed_ui: Dictionary = placed.get("ui_state", {}) if typeof(placed.get("ui_state", {})) == TYPE_DICTIONARY else {}
	if run_state.bankroll != 40:
		failures.append("SB.4 blackjack/slot fixture did not leave the expected $40 after a $60 upfront blackjack wager.")
		return
	var stored_slot_before := SlotMachineStateScript.read_machine(run_state.current_environment, "slot")
	var spin_count_before := int(stored_slot_before.get("spin_count", 0))
	app.set("library", library)
	app.set("run_state", run_state)
	app.set("current_game", blackjack)
	app.set("game_surface_ui_state", placed_ui)
	app.set("selected_stake", 60)
	app.set("selected_action_id", "play_basic")
	app.set("selected_action_kind", "legal")
	app.call("_set_current_screen", "GAME")
	app.call("_hide_event_choice_popup")
	app.call("_advance_environment_game_runtime")
	var popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	if bool(popup.get("visible", false)):
		failures.append("SB.4 background slot runtime opened a blocking wager prompt over an active blackjack settlement.")
	var stored_slot_after := SlotMachineStateScript.read_machine(run_state.current_environment, "slot")
	if int(stored_slot_after.get("spin_count", 0)) != spin_count_before:
		failures.append("SB.4 background slot autoplay advanced while a foreground blackjack hand was waiting to settle.")
	if run_state.bankroll != 40:
		failures.append("SB.4 background slot runtime changed bankroll before the foreground blackjack settlement.")
	app.call("_on_game_surface_action", "blackjack_deal", 0, true)
	var result: Dictionary = app.get("last_game_result")
	var hand_results: Array = result.get("blackjack_hand_results", []) as Array
	if not bool(result.get("ok", false)) or hand_results.is_empty() or str((hand_results[0] as Dictionary).get("outcome", "")) != "blackjack":
		failures.append("SB.4 blackjack natural could not settle after suppressing background slot runtime: action=%s ok=%s message=%s hand_count=%d selected=%s/%s." % [
			str(result.get("action_id", "")),
			str(result.get("ok", false)),
			str(result.get("message", "")),
			hand_results.size(),
			str(app.get("selected_action_id")),
			str(app.get("selected_action_kind")),
		])


func _sb4_check_event_modal_routes(library: ContentLibrary, app: Control, failures: Array) -> void:
	var popup := _sb4_open_triggered_event_popup(library, app, "SB4-EVENT-MODAL", failures)
	if popup.is_empty():
		return
	var before := _sb4_serialized_run(app)
	_sb4_assert_blocked_route(app, "event popup open_world_map", "open_world_map", [], before, failures)
	_sb4_assert_blocked_route(app, "event popup activate travel", "activate_interactable_object", ["travel:leave"], before, failures)
	_sb4_assert_blocked_route(app, "event popup open inventory", "open_run_inventory", [], before, failures)
	_sb4_assert_blocked_route(app, "event popup open menu", "open_run_menu", [], before, failures)
	_sb4_assert_blocked_route(app, "event popup select travel category", "select_action_category", ["travel"], before, failures)
	_sb4_assert_blocked_route(app, "event popup select travel option", "select_travel_option", ["sb4_missing_route"], before, failures)
	var after_popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	if not bool(after_popup.get("visible", false)):
		failures.append("SB.4 event modal hostile input dismissed the popup without a choice.")
	_sb4_assert_overlay_contract(app, "event popup hostile routes", failures)


func _sb4_open_triggered_event_popup(library: ContentLibrary, app: Control, seed_text: String, failures: Array) -> Dictionary:
	app.call("start_foundation_run", seed_text)
	var run_state: RunState = app.get("run_state")
	if run_state == null:
		failures.append("SB.4 could not start a run for triggered-event modal coverage.")
		return {}
	var trigger_context := _sb4_trigger_context()
	var event_id := _sb4_first_triggerable_event_id(library, run_state, trigger_context)
	if event_id.is_empty():
		failures.append("SB.4 triggered-event modal coverage could not find triggerable event content.")
		return {}
	if not run_state.enqueue_triggered_event(event_id, "sb4_input_fuzz", trigger_context):
		failures.append("SB.4 triggered-event modal coverage could not enqueue %s." % event_id)
		return {}
	if not bool(app.call("_show_next_pending_triggered_event")):
		failures.append("SB.4 triggered-event modal coverage could not open %s." % event_id)
		return {}
	var popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	if not bool(popup.get("visible", false)) or str(popup.get("popup_type", "")) != "triggered_event":
		failures.append("SB.4 triggered-event modal did not expose the expected popup snapshot: %s" % JSON.stringify(popup))
		return {}
	_sb4_assert_overlay_contract(app, "triggered-event popup open", failures)
	return popup


func _sb4_trigger_context() -> Dictionary:
	return {
		"trigger": "action",
		"type": "action",
		"source": "sb4_input_fuzz",
		"turns": 99,
	}


func _sb4_first_triggerable_event_id(library: ContentLibrary, run_state: RunState, context: Dictionary) -> String:
	if library == null or run_state == null:
		return ""
	for event_value in library.events:
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event_definition: Dictionary = event_value
		if str(event_definition.get("interaction_mode", "interactable")) != "triggered":
			continue
		var event_id := str(event_definition.get("id", ""))
		if event_id.is_empty():
			continue
		var event_module := EventModule.new()
		event_module.setup(event_definition, library)
		if event_module.can_trigger(run_state, run_state.current_environment, context):
			return event_id
	return ""


func _sb4_check_wager_modal_routes(library: ContentLibrary, app: Control, failures: Array) -> void:
	app.call("start_foundation_run", "SB4-WAGER-MODAL")
	var run_state: RunState = app.get("run_state")
	if run_state == null:
		failures.append("SB.4 all-in wager modal coverage could not start a run.")
		return
	run_state.bankroll = 2
	var environment := run_state.current_environment.duplicate(true)
	environment["economic_profile"] = {
		"stake_floor": 1,
		"stake_ceiling": 2,
	}
	run_state.current_environment = environment
	app.call("_set_current_screen", "GAME")
	app.call("_refresh")
	app.set("current_game", HostileInputAllInFixtureGame.new())
	app.set("selected_stake", 2)
	app.call("_resolve_game_action", "all_in_loss", false, false, false)
	var popup: Dictionary = app.call("current_event_choice_popup_snapshot")
	if not bool(popup.get("visible", false)) or str(popup.get("popup_type", "")) != "wager_confirmation":
		failures.append("SB.4 all-in wager did not open a wager confirmation popup: popup=%s modal_blocked=%s closing_blocked=%s environment=%s." % [
			JSON.stringify(popup),
			str(app.call("_modal_contract_blocks_player_input")),
			str(app.call("_closing_time_blocks_environment_actions")),
			JSON.stringify(run_state.current_environment),
		])
		return
	if run_state.bankroll != 2:
		failures.append("SB.4 all-in wager changed bankroll before confirmation.")
	var before := _sb4_serialized_run(app)
	_sb4_assert_blocked_route(app, "wager popup open_world_map", "open_world_map", [], before, failures)
	_sb4_assert_blocked_route(app, "wager popup activate travel", "activate_interactable_object", ["travel:leave"], before, failures)
	_sb4_assert_blocked_route(app, "wager popup open inventory", "open_run_inventory", [], before, failures)
	_sb4_assert_blocked_route(app, "wager popup open menu", "open_run_menu", [], before, failures)
	_sb4_assert_blocked_route(app, "wager popup resolve stale event", "resolve_event_choice", [_save_load_first_event_id(library), "accept"], before, failures)
	_sb4_assert_blocked_route(app, "wager popup game resolve", "_resolve_game_action", ["all_in_loss", false, false, false], before, failures)
	app.call("confirm_pending_wager_action")
	var after_confirm := _sb4_serialized_run(app)
	if run_state.bankroll != 0:
		failures.append("SB.4 confirmed all-in fixture should charge exactly once; bankroll=%d." % run_state.bankroll)
	app.call("confirm_pending_wager_action")
	if _sb4_serialized_run(app) != after_confirm:
		failures.append("SB.4 repeated all-in confirmation mutated RunState a second time.")
	_sb4_assert_overlay_contract(app, "all-in wager confirmed", failures)


func _sb4_check_travel_transition_routes(app: Control, failures: Array) -> void:
	app.call("start_foundation_run", "SB4-TRAVEL-TRANSITION")
	app.call("_show_travel_transition", "sb4_target", "SB4 Target", "Fixture travel in progress.")
	var before := _sb4_serialized_run(app)
	_sb4_assert_blocked_route(app, "travel transition open_world_map", "open_world_map", [], before, failures)
	_sb4_assert_blocked_route(app, "travel transition activate travel", "activate_interactable_object", ["travel:leave"], before, failures)
	_sb4_assert_blocked_route(app, "travel transition open inventory", "open_run_inventory", [], before, failures)
	_sb4_assert_blocked_route(app, "travel transition open journal", "open_run_journal", [], before, failures)
	_sb4_assert_blocked_route(app, "travel transition open menu", "open_run_menu", [], before, failures)
	_sb4_assert_blocked_route(app, "travel transition enter game", "enter_game", ["slot"], before, failures)
	_sb4_assert_blocked_route(app, "travel transition select category", "select_action_category", ["games"], before, failures)
	app.call("_hide_travel_transition")
	_sb4_assert_overlay_contract(app, "travel transition hidden", failures)


func _sb4_check_seeded_menu_canvas_routes(app: Control, failures: Array) -> void:
	for seed_index in range(UI_STATE_FUZZ_SEEDS):
		app.call("start_foundation_run", "SB4-MENU-FUZZ-%d" % seed_index)
		var run_state: RunState = app.get("run_state")
		if run_state == null:
			failures.append("SB.4 seeded menu fuzz could not start run %d." % seed_index)
			continue
		var rng := run_state.create_rng("sb4_input_fuzz")
		for step_index in range(UI_STATE_FUZZ_STEPS_PER_SEED):
			var bankroll_before := run_state.bankroll
			match rng.randi_range(0, 9):
				0:
					app.call("open_run_inventory")
				1:
					app.call("close_run_inventory")
				2:
					app.call("open_run_journal")
				3:
					app.call("close_run_journal")
				4:
					app.call("open_run_menu")
				5:
					app.call("close_run_menu")
				6:
					app.call("open_world_map")
				7:
					app.call("close_world_map")
				8:
					app.call("activate_interactable_object", "travel:leave")
				_:
					app.call("back_to_environment")
			if run_state.bankroll != bankroll_before:
				failures.append("SB.4 seeded menu fuzz changed bankroll on non-resolve input seed=%d step=%d." % [seed_index, step_index])
			_sb4_assert_overlay_contract(app, "seeded menu fuzz seed=%d step=%d" % [seed_index, step_index], failures)
		app.call("close_run_inventory")
		app.call("close_run_journal")
		app.call("close_run_menu")
		app.call("close_world_map")
	_sb4_check_game_surface_touch_route(app, failures)


func _sb4_check_game_surface_touch_route(app: Control, failures: Array) -> void:
	app.call("start_game_test_session", "slot")
	var run_state: RunState = app.get("run_state")
	var game_canvas: Control = app.get("game_surface_canvas")
	if run_state == null or game_canvas == null or not game_canvas.visible:
		failures.append("SB.4 game-surface touch route could not enter a slot surface.")
		return
	var hit := _sb4_surface_hit_for(game_canvas, ["surface_stake_up", "surface_stake_down", "surface_back"])
	if hit.is_empty():
		hit = {
			"action": "blank",
			"index": -1,
			"position": Vector2(12.0, 12.0),
		}
	app.call("_show_travel_transition", "sb4_touch_block", "SB4 Touch Block", "Fixture touch block.")
	var before := _sb4_serialized_run(app)
	var touch_event := InputEventScreenTouch.new()
	touch_event.pressed = true
	touch_event.double_tap = true
	touch_event.position = hit.get("position", Vector2.ZERO)
	game_canvas.call("_gui_input", touch_event)
	app.call("_hide_travel_transition")
	if _sb4_serialized_run(app) != before:
		failures.append("SB.4 game-surface touch safe-route mutated serialized RunState.")
	_sb4_assert_overlay_contract(app, "game-surface touch route", failures)


func _sb4_surface_hit_for(game_canvas: Control, preferred_actions: Array) -> Dictionary:
	var snapshot: Dictionary = game_canvas.call("current_view_snapshot")
	var hits: Array = snapshot.get("surface_hit_actions", [])
	for action_value in preferred_actions:
		var action := str(action_value)
		for hit_value in hits:
			if typeof(hit_value) != TYPE_DICTIONARY:
				continue
			var hit_data: Dictionary = hit_value
			if str(hit_data.get("action", "")) != action:
				continue
			var index := int(hit_data.get("index", -1))
			var position: Vector2 = game_canvas.call("local_position_for_surface_action", action, index)
			if position.x >= 0.0 and position.y >= 0.0:
				return {
					"action": action,
					"index": index,
					"position": position,
				}
	return {}


func _sb4_assert_blocked_route(app: Control, label: String, method_name: String, args: Array, before_serialized: String, failures: Array) -> void:
	app.callv(method_name, args)
	_sb4_assert_run_state_unchanged(app, before_serialized, label, failures)
	_sb4_assert_overlay_contract(app, label, failures)


func _sb4_assert_run_state_unchanged(app: Control, before_serialized: String, label: String, failures: Array) -> void:
	var after_serialized := _sb4_serialized_run(app)
	if after_serialized != before_serialized:
		failures.append("SB.4 %s mutated serialized RunState during hostile input." % label)


func _sb4_assert_overlay_contract(app: Control, label: String, failures: Array) -> void:
	var overlay_value: Variant = app.call("current_overlay_state_snapshot")
	if typeof(overlay_value) != TYPE_DICTIONARY:
		failures.append("SB.4 %s did not return an overlay-state snapshot." % label)
		return
	var overlay: Dictionary = overlay_value
	if not bool(overlay.get("contract_valid", false)):
		failures.append("SB.4 overlay contract violation after %s: %s" % [label, JSON.stringify(overlay.get("violations", []))])


func _sb4_serialized_run(app: Control) -> String:
	return JSON.stringify(app.call("serialized_run_state"))


func _check_game_read_path_mutation_firewall(library: ContentLibrary, game: GameModule, game_id: String, failures: Array) -> void:
	var run_state := _mutation_firewall_game_run_state(library, game, game_id)
	var ui_state := {
		"surface_time_msec": 1200,
		"drunk_scaled_surface_time_msec": 1200,
	}
	var enter_before := _mutation_firewall_snapshot(run_state)
	var enter_payload := game.enter(run_state, run_state.current_environment)
	_mutation_firewall_probe_payload(game_id, "enter", run_state, failures, enter_before, enter_payload)
	var actions_before := _mutation_firewall_snapshot(run_state)
	var actions_payload := game.actions(run_state, run_state.current_environment)
	_mutation_firewall_probe_payload(game_id, "actions", run_state, failures, actions_before, actions_payload)
	var legal_before := _mutation_firewall_snapshot(run_state)
	var legal_payload := game.legal_actions(run_state, run_state.current_environment)
	_mutation_firewall_probe_payload(game_id, "legal_actions", run_state, failures, legal_before, legal_payload)
	var cheat_before := _mutation_firewall_snapshot(run_state)
	var cheat_payload := game.cheat_actions(run_state, run_state.current_environment)
	_mutation_firewall_probe_payload(game_id, "cheat_actions", run_state, failures, cheat_before, cheat_payload)
	var surface_before := _mutation_firewall_snapshot(run_state)
	var surface := game.surface_state(run_state, run_state.current_environment, ui_state)
	_mutation_firewall_assert_unchanged(run_state, surface_before, "%s surface_state read" % game_id, failures)
	if not surface.is_empty():
		var draw_before := _mutation_firewall_snapshot(run_state)
		var harness := SurfaceHarness.new()
		harness.setup(surface)
		game.draw_surface(harness, surface, {"mutation_firewall": true})
		_mutation_firewall_assert_unchanged(run_state, draw_before, "%s draw_surface read" % game_id, failures)
	_mutation_firewall_mutate_payload(surface)
	_mutation_firewall_assert_unchanged(run_state, surface_before, "%s surface_state payload" % game_id, failures)
	var auto_tick_before := _mutation_firewall_snapshot(run_state)
	game.surface_needs_auto_tick(ui_state, run_state, run_state.current_environment)
	_mutation_firewall_assert_unchanged(run_state, auto_tick_before, "%s surface_needs_auto_tick read" % game_id, failures)
	var runtime_needed_before := _mutation_firewall_snapshot(run_state)
	game.environment_runtime_needs_tick(run_state, run_state.current_environment, 1200)
	_mutation_firewall_assert_unchanged(run_state, runtime_needed_before, "%s environment_runtime_needs_tick read" % game_id, failures)
	var runtime_before := _mutation_firewall_snapshot(run_state)
	var runtime_payload := game.environment_runtime_state(run_state, run_state.current_environment)
	_mutation_firewall_probe_payload(game_id, "environment_runtime_state", run_state, failures, runtime_before, runtime_payload)
	var object_before := _mutation_firewall_snapshot(run_state)
	var object_payload := game.environment_object_state(run_state, run_state.current_environment)
	_mutation_firewall_probe_payload(game_id, "environment_object_state", run_state, failures, object_before, object_payload)
	var interactable_before := _mutation_firewall_snapshot(run_state)
	var interactable_payload := game.environment_interactable_objects(run_state, run_state.current_environment)
	_mutation_firewall_probe_payload(game_id, "environment_interactable_objects", run_state, failures, interactable_before, interactable_payload)


func _mutation_firewall_game_run_state(library: ContentLibrary, game: GameModule, game_id: String) -> RunState:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("MUTATION-FIREWALL-%s" % game_id.to_upper())
	run_state.bankroll = 1000
	var archetype := _first_archetype_with_game(library, game_id)
	var environment: Dictionary = {}
	if archetype.is_empty():
		environment = _surface_contract_environment()
	else:
		environment = EnvironmentInstance.from_archetype(archetype, 1, run_state.create_rng("mutation_firewall_env_%s" % game_id), library, run_state.challenge_config).to_dict()
	environment["game_ids"] = [game_id]
	environment["economic_profile"] = {
		"stake_floor": 1,
		"stake_ceiling": 200,
	}
	var game_states := _copy_dict(environment.get("game_states", {}))
	var generated_state := game.generate_environment_state(run_state, environment, run_state.create_rng("mutation_firewall_state_%s" % game_id))
	if not generated_state.is_empty():
		game_states[game_id] = generated_state.duplicate(true)
	environment["game_states"] = game_states
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)
	run_state.set_environment(environment)
	return run_state


func _check_world_map_read_path_mutation_firewall(library: ContentLibrary, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("MUTATION-FIREWALL-WORLD-MAP")
	var generator: RunGenerator = RunGeneratorScript.new(library)
	generator.next_environment(run_state)
	var current_node_id := run_state.current_world_node_id()
	var before := _mutation_firewall_snapshot(run_state)
	var generator_snapshot := generator.world_map_snapshot(run_state, current_node_id)
	_mutation_firewall_assert_unchanged(run_state, before, "world_map generator snapshot read", failures)
	_mutation_firewall_mutate_payload(generator_snapshot)
	_mutation_firewall_assert_unchanged(run_state, before, "world_map generator snapshot payload", failures)
	var static_before := _mutation_firewall_snapshot(run_state)
	var static_snapshot := WorldMapScript.snapshot(run_state.world_map, current_node_id)
	_mutation_firewall_assert_unchanged(run_state, static_before, "world_map static snapshot read", failures)
	_mutation_firewall_mutate_payload(static_snapshot)
	_mutation_firewall_assert_unchanged(run_state, static_before, "world_map static snapshot payload", failures)


func _check_run_action_service_read_path_mutation_firewall(library: ContentLibrary, failures: Array) -> void:
	var item_definition := _first_definition(library.items)
	var service_definition := _first_definition(library.services)
	var lender_definition := _first_definition(library.lenders)
	if item_definition.is_empty() or service_definition.is_empty() or lender_definition.is_empty():
		failures.append("Mutation firewall RunActionService fixture needs item, service, and lender definitions.")
		return
	var item_id := str(item_definition.get("id", ""))
	var service_id := str(service_definition.get("id", ""))
	var lender_id := str(lender_definition.get("id", ""))
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("MUTATION-FIREWALL-ACTIONS")
	run_state.bankroll = 200
	run_state.inventory = [item_id]
	run_state.set_environment({
		"id": "mutation_firewall_action_room",
		"display_name": "Mutation Firewall Action Room",
		"kind": "shop",
		"archetype_id": "mutation_firewall_action_fixture",
		"item_offers": [{
			"id": item_id,
			"display_name": str(item_definition.get("display_name", item_id)),
			"price": 1,
		}],
		"service_ids": [service_id],
		"lender_hooks": [lender_id],
		"layout": {},
	})
	var resolver: RunActionService = RunActionServiceScript.new()
	resolver.setup(library, run_state)
	var offers_before := _mutation_firewall_snapshot(run_state)
	var offers_payload := resolver.item_offer_view_list(item_id)
	_mutation_firewall_probe_payload("run_action_service", "item_offer_view_list", run_state, failures, offers_before, offers_payload)
	var offer_before := _mutation_firewall_snapshot(run_state)
	var offer_payload := resolver.item_offer(item_id, item_id)
	_mutation_firewall_probe_payload("run_action_service", "item_offer", run_state, failures, offer_before, offer_payload)
	var inventory_before := _mutation_firewall_snapshot(run_state)
	var inventory_payload := resolver.inventory_item_view_list()
	_mutation_firewall_probe_payload("run_action_service", "inventory_item_view_list", run_state, failures, inventory_before, inventory_payload)
	var services_before := _mutation_firewall_snapshot(run_state)
	var services_payload := resolver.service_hook_view_list(service_id)
	_mutation_firewall_probe_payload("run_action_service", "service_hook_view_list", run_state, failures, services_before, services_payload)
	var service_before := _mutation_firewall_snapshot(run_state)
	var service_payload := resolver.service_hook(service_id, service_id)
	_mutation_firewall_probe_payload("run_action_service", "service_hook", run_state, failures, service_before, service_payload)
	var lenders_before := _mutation_firewall_snapshot(run_state)
	var lenders_payload := resolver.lender_hook_view_list(lender_id)
	_mutation_firewall_probe_payload("run_action_service", "lender_hook_view_list", run_state, failures, lenders_before, lenders_payload)
	var lender_before := _mutation_firewall_snapshot(run_state)
	var lender_payload := resolver.lender_hook(lender_id, lender_id)
	_mutation_firewall_probe_payload("run_action_service", "lender_hook", run_state, failures, lender_before, lender_payload)
func _check_event_choice_read_path_mutation_firewall(library: ContentLibrary, failures: Array) -> void:
	var event_definition := _first_definition(library.events)
	if event_definition.is_empty():
		failures.append("Mutation firewall EventModule fixture needs an event definition.")
		return
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("MUTATION-FIREWALL-EVENT")
	run_state.set_environment({
		"id": "mutation_firewall_event_room",
		"display_name": "Mutation Firewall Event Room",
		"kind": "bar",
		"archetype_id": "mutation_firewall_event_fixture",
		"tier": maxi(1, int(event_definition.get("tier_min", 1))),
		"event_ids": [str(event_definition.get("id", ""))],
		"layout": {},
	})
	var event_module := EventModule.new()
	event_module.setup(event_definition, library)
	var choices_before := _mutation_firewall_snapshot(run_state)
	var choices_payload := event_module.choices(run_state, run_state.current_environment)
	_mutation_firewall_probe_payload("event_module", "choices", run_state, failures, choices_before, choices_payload)
	if not choices_payload.is_empty() and typeof(choices_payload[0]) == TYPE_DICTIONARY:
		var choice_id := str((choices_payload[0] as Dictionary).get("id", ""))
		var choice_before := _mutation_firewall_snapshot(run_state)
		var choice_payload := event_module.choice(choice_id, run_state, run_state.current_environment)
		_mutation_firewall_probe_payload("event_module", "choice", run_state, failures, choice_before, choice_payload)


func _mutation_firewall_probe_payload(owner_id: String, boundary_id: String, run_state: RunState, failures: Array, before: String, payload: Variant) -> void:
	_mutation_firewall_assert_unchanged(run_state, before, "%s %s read" % [owner_id, boundary_id], failures)
	_mutation_firewall_mutate_payload(payload)
	_mutation_firewall_assert_unchanged(run_state, before, "%s %s payload" % [owner_id, boundary_id], failures)


func _mutation_firewall_snapshot(run_state: RunState) -> String:
	return JSON.stringify({
		"run_state": run_state.to_dict(),
		"current_environment": run_state.current_environment,
	})


func _mutation_firewall_assert_unchanged(run_state: RunState, before: String, label: String, failures: Array) -> void:
	if _mutation_firewall_snapshot(run_state) != before:
		failures.append("Mutation firewall failed: %s changed RunState/current_environment during a read or leaked payload mutation." % label)


func _mutation_firewall_mutate_payload(payload: Variant, depth: int = 0) -> void:
	if depth > 6:
		return
	if typeof(payload) == TYPE_DICTIONARY:
		var data: Dictionary = payload
		var keys := data.keys()
		data["__mutation_firewall_probe"] = "mutated"
		for key in keys:
			_mutation_firewall_mutate_payload(data[key], depth + 1)
	elif typeof(payload) == TYPE_ARRAY:
		var values: Array = payload
		var original_size := values.size()
		values.append({"__mutation_firewall_probe": "mutated"})
		for index in range(original_size):
			_mutation_firewall_mutate_payload(values[index], depth + 1)


func _check_challenge_pack_foundation(library: ContentLibrary, failures: Array) -> void:
	_check_challenge_pack_content(library, failures)
	var completion_flags := {}
	for challenge_value in library.challenges:
		if typeof(challenge_value) != TYPE_DICTIONARY:
			continue
		var challenge_def: Dictionary = challenge_value
		var challenge_id := str(challenge_def.get("id", "")).strip_edges()
		var completion_flag := str(challenge_def.get("completion_flag", "")).strip_edges()
		if bool(completion_flags.get(completion_flag, false)):
			failures.append("Challenge completion flag is not unique: %s." % completion_flag)
		completion_flags[completion_flag] = true
		var config := library.challenge_config_for(challenge_id, "CHALLENGE-PACK-SEED")
		var run_a: RunState = RunStateScript.new()
		run_a.start_new("IGNORED-A", config)
		var run_b: RunState = RunStateScript.new()
		run_b.start_new("IGNORED-B", library.challenge_config_for(challenge_id, "CHALLENGE-PACK-SEED"))
		if run_a.seed_value != run_b.seed_value or JSON.stringify(run_a.to_dict()) != JSON.stringify(run_b.to_dict()):
			failures.append("Challenge %s did not start deterministically from the same packed config." % challenge_id)
		var restored: RunState = RunStateScript.new()
		restored.from_dict(run_a.to_dict())
		_assert_json_equal(run_a.challenge_config, restored.challenge_config, "Challenge %s config did not survive RunState round-trip." % challenge_id, failures)
		if run_a.challenge_completion_flag() != completion_flag:
			failures.append("Challenge %s completion flag was not available through RunState." % challenge_id)
		var modifiers: Dictionary = config.get("modifiers", {}) if typeof(config.get("modifiers", {})) == TYPE_DICTIONARY else {}
		_check_challenge_start_modifiers(challenge_id, modifiers, run_a, library, failures)

	_check_dry_run_challenge(library, failures)
	_check_heat_wave_challenge(library, failures)
	_check_pacifist_challenge(library, failures)
	_check_one_machine_challenge(library, failures)
	_check_grand_casino_challenge_targets(library, failures)
	var profile_inventory: ProfileInventory = ProfileInventoryScript.new()
	profile_inventory.mark_challenge_completed("challenge_dry_run_complete", "dry_run", "Dry Run")
	var profile_round_trip: ProfileInventory = ProfileInventoryScript.new()
	profile_round_trip.from_dict(profile_inventory.to_dict())
	if not profile_round_trip.has_challenge_completion("challenge_dry_run_complete"):
		failures.append("Challenge completion flag did not persist through ProfileInventory.")


func _check_challenge_start_modifiers(challenge_id: String, modifiers: Dictionary, run_state: RunState, library: ContentLibrary, failures: Array) -> void:
	var expected_bankroll := RunState.DEFAULT_BANKROLL
	if modifiers.has("starting_bankroll"):
		expected_bankroll = int(modifiers.get("starting_bankroll", expected_bankroll))
	if modifiers.has("starting_bankroll_delta"):
		expected_bankroll += int(modifiers.get("starting_bankroll_delta", 0))
	expected_bankroll = maxi(1, expected_bankroll)
	if run_state.bankroll != expected_bankroll:
		failures.append("Challenge %s starting bankroll was %d, expected %d." % [challenge_id, run_state.bankroll, expected_bankroll])
	if modifiers.has("baseline_luck_delta") and run_state.baseline_luck != clampi(int(modifiers.get("baseline_luck_delta", 0)), RunState.BASELINE_LUCK_MIN, RunState.BASELINE_LUCK_MAX):
		failures.append("Challenge %s baseline luck modifier was not applied." % challenge_id)
	if modifiers.has("starting_heat") and run_state.suspicion_level() != clampi(int(modifiers.get("starting_heat", 0)), 0, 100):
		failures.append("Challenge %s starting heat modifier was not applied." % challenge_id)
	if modifiers.has("starting_debt"):
		var starting_debt: Array = modifiers.get("starting_debt", []) if typeof(modifiers.get("starting_debt", [])) == TYPE_ARRAY else []
		if run_state.debt.size() != starting_debt.size():
			failures.append("Challenge %s starting debt entries were not applied." % challenge_id)
	if modifiers.has("content_groups"):
		var enabled_groups := library.enabled_content_group_ids(run_state.challenge_config)
		_assert_json_equal(enabled_groups, library.normalize_content_group_ids(modifiers.get("content_groups", [])), "Challenge %s content groups were not normalized into RunState." % challenge_id, failures)


func _check_dry_run_challenge(library: ContentLibrary, failures: Array) -> void:
	var config := library.challenge_config_for("dry_run", "DRY-RUN-SEED")
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("IGNORED", config)
	var house_drink := library.service("house_drink")
	if bool(run_state.service_hook_status(house_drink).get("available", true)):
		failures.append("Dry Run did not block alcohol services through RunState service status.")
	run_state.current_environment = {
		"id": "dry_run_services",
		"archetype_id": "bar",
		"service_ids": ["house_drink", "cashier_tip"],
	}
	var resolver: RunActionService = RunActionServiceScript.new()
	resolver.setup(library, run_state)
	var service_ids: Array = []
	for service_value in resolver.service_hook_view_list():
		if typeof(service_value) == TYPE_DICTIONARY:
			service_ids.append(str((service_value as Dictionary).get("id", "")))
	if service_ids.has("house_drink"):
		failures.append("Dry Run service menu still exposed the blocked alcohol service.")
	if not service_ids.has("cashier_tip"):
		failures.append("Dry Run service menu hid unrelated services.")


func _check_heat_wave_challenge(library: ContentLibrary, failures: Array) -> void:
	var config := library.challenge_config_for("heat_wave", "HEAT-WAVE-SEED")
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("IGNORED", config)
	var cashier_status := run_state.service_hook_status(library.service("cashier_tip"))
	if int(cashier_status.get("cost", 0)) != 2:
		failures.append("Heat Wave did not discount information services from 4 to 2.")
	var near_decay := run_state.travel_risk_decay({"distance": "near", "risk_decay": 12})
	if near_decay != 2:
		failures.append("Heat Wave did not reduce near-route heat decay from 12 to 2.")
	run_state.current_environment = {
		"id": "heat_wave_turns",
		"archetype_id": "bar",
		"turns": 0,
	}
	run_state.suspicion = {
		"level": 0,
		"cues": [],
		"local_levels": {},
	}
	run_state.add_suspicion("heat_wave_fixture", 10, "behavior", false, {"environment_archetype_id": "bar"})
	run_state.advance_environment_turns(2)
	if run_state.suspicion_level() != 10:
		failures.append("Heat Wave cooled local heat before its slower turn interval elapsed.")
	run_state.advance_environment_turns(2)
	if run_state.suspicion_level() != 9:
		failures.append("Heat Wave did not cool local heat after the slower turn interval elapsed.")


func _check_pacifist_challenge(library: ContentLibrary, failures: Array) -> void:
	var config := library.challenge_config_for("pacifist", "PACIFIST-SEED")
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("IGNORED", config)
	var module := GameModule.new()
	module.setup({
		"id": "pacifist_fixture",
		"display_name": "Pacifist Fixture",
		"cheat_actions": [{
			"id": "mark_cards",
			"label": "Mark Cards",
			"action_kind": "cheat",
			"suspicion_delta": 5,
		}],
	})
	if not module.cheat_actions(run_state, {}).is_empty():
		failures.append("Pacifist challenge did not suppress shared cheat actions.")


func _check_one_machine_challenge(library: ContentLibrary, failures: Array) -> void:
	var config := library.challenge_config_for("one_machine", "ONE-MACHINE-SEED")
	if not library.game_enabled_for_challenge("slot", config):
		failures.append("One Machine did not keep slots enabled.")
	if library.game_enabled_for_challenge("blackjack", config):
		failures.append("One Machine still enabled blackjack.")
	if library.item_enabled_for_challenge("xray_glasses", config):
		failures.append("One Machine still enabled pull-tab-only items.")
	var slot_archetype := _first_archetype_with_game(library, "slot")
	if slot_archetype.is_empty():
		failures.append("No slot archetype exists for One Machine generation.")
		return
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("ONE-MACHINE-GEN", config)
	var environment := EnvironmentInstance.from_archetype(slot_archetype, 1, run_state.create_rng("one_machine"), library, run_state.challenge_config)
	for game_id in _string_array(environment.game_ids):
		if game_id != "slot":
			failures.append("One Machine generated non-slot game %s." % game_id)


func _check_grand_casino_challenge_targets(library: ContentLibrary, failures: Array) -> void:
	var grand_casino := _archetype_by_id(library, "grand_casino")
	if grand_casino.is_empty():
		failures.append("Grand Casino archetype is missing for challenge target checks.")
		return
	var pacifist_run: RunState = RunStateScript.new()
	pacifist_run.start_new("PACIFIST-GRAND", library.challenge_config_for("pacifist", "PACIFIST-GRAND"))
	pacifist_run.set_environment(EnvironmentInstance.from_archetype(grand_casino, 3, pacifist_run.create_rng("pacifist_grand"), library, pacifist_run.challenge_config).to_dict())
	var pacifist_status := pacifist_run.demo_objective_status()
	if int(pacifist_status.get("high_roller_net_winnings", 0)) != 5 or int(pacifist_status.get("high_roller_max_heat", 0)) != 35:
		failures.append("Pacifist Grand Casino target modifiers were not applied.")
	var card_run: RunState = RunStateScript.new()
	card_run.start_new("CARD-SHARP-GRAND", library.challenge_config_for("card_sharp", "CARD-SHARP-GRAND"))
	card_run.set_environment(EnvironmentInstance.from_archetype(grand_casino, 3, card_run.create_rng("card_grand"), library, card_run.challenge_config).to_dict())
	var card_status := card_run.demo_objective_status()
	if int(card_status.get("high_roller_net_winnings", 0)) != 30:
		failures.append("Card Sharp Grand Casino target modifier was not applied.")


func _first_definition(values: Array) -> Dictionary:
	for value in values:
		if typeof(value) == TYPE_DICTIONARY:
			var data: Dictionary = value
			if not str(data.get("id", "")).is_empty():
				return data.duplicate(true)
	return {}


func _archetype_by_id(library: ContentLibrary, archetype_id: String) -> Dictionary:
	for value in library.environment_archetypes:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == archetype_id:
			return (value as Dictionary).duplicate(true)
	return {}


func _string_array(values: Variant) -> Array:
	var result: Array = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		var id := str(value)
		if not id.is_empty():
			result.append(id)
	return result


func _count_string_occurrences(values: Variant, target: String) -> int:
	var count := 0
	for id in _string_array(values):
		if str(id) == target:
			count += 1
	return count


func _foundation_string_occurrence_count(text: String, needle: String) -> int:
	if needle.is_empty():
		return 0
	var count := 0
	var offset := 0
	while offset < text.length():
		var found := text.find(needle, offset)
		if found < 0:
			break
		count += 1
		offset = found + needle.length()
	return count


func _dictionary_has_key_prefix(values: Dictionary, prefix: String) -> bool:
	for key in values.keys():
		if str(key).begins_with(prefix):
			return true
	return false


func _surface_harness_has_action(harness, action_id: String) -> bool:
	for region_value in harness.hit_regions:
		if typeof(region_value) == TYPE_DICTIONARY and str((region_value as Dictionary).get("action", "")) == action_id:
			return true
	return false


func _surface_harness_first_hit(harness, action_id: String, index: int = -999999) -> Dictionary:
	for region_value in harness.hit_regions:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		if str(region.get("action", "")) != action_id:
			continue
		if index != -999999 and int(region.get("index", -1)) != index:
			continue
		return region.duplicate(true)
	return {}


func _check_canvas_hit_dispatch(surface: Dictionary, rect: Rect2, action: String, index: int, label: String, failures: Array) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		failures.append("%s could not dispatch because the hit rect was empty." % label)
		return
	var canvas: Control = GameSurfaceCanvasScript.new()
	canvas.size = Vector2(ArtContractsScript.GAME_BOARD_SIZE)
	root.add_child(canvas)
	canvas.call("render_game_snapshot", surface)
	canvas.call("surface_add_exact_hit", rect, action, index)
	var position: Vector2 = canvas.call("local_position_for_surface_action", action, index)
	if position.x < 0.0 or position.y < 0.0:
		failures.append("%s did not resolve a local click position." % label)
		root.remove_child(canvas)
		canvas.free()
		return
	var dispatched: Array = []
	canvas.surface_action.connect(func(emitted_action: String, emitted_index: int, emitted_confirmed: bool) -> void:
		dispatched.append({
			"action": emitted_action,
			"index": emitted_index,
			"confirmed": emitted_confirmed,
		})
	)
	canvas.call("_activate_surface_at_position", position, false)
	if dispatched.is_empty():
		failures.append("%s did not emit a surface action from its registered hit region." % label)
	else:
		var event: Dictionary = dispatched[0]
		if str(event.get("action", "")) != action or int(event.get("index", -1)) != index:
			failures.append("%s emitted %s[%d] instead of %s[%d]." % [label, str(event.get("action", "")), int(event.get("index", -1)), action, index])
	root.remove_child(canvas)
	canvas.free()


func _check_surface_hit_layout(harness: SurfaceHarness, label: String, failures: Array) -> void:
	var board := Rect2(Vector2.ZERO, Vector2(ArtContractsScript.GAME_BOARD_SIZE))
	var regions: Array = []
	for region_value in harness.hit_regions:
		if typeof(region_value) != TYPE_DICTIONARY:
			continue
		var region: Dictionary = region_value
		var rect: Rect2 = region.get("rect", Rect2())
		var action := str(region.get("action", ""))
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			failures.append("%s has empty hit region for %s." % [label, action])
			continue
		if rect.position.x < -0.1 or rect.position.y < -0.1 or rect.end.x > board.end.x + 0.1 or rect.end.y > board.end.y + 0.1:
			failures.append("%s hit region for %s is outside the board: %s." % [label, action, str(rect)])
		regions.append({"rect": rect, "action": action, "index": int(region.get("index", -1))})
	for i in range(regions.size()):
		var a: Dictionary = regions[i]
		var a_rect: Rect2 = a.get("rect", Rect2())
		for j in range(i + 1, regions.size()):
			var b: Dictionary = regions[j]
			var b_rect: Rect2 = b.get("rect", Rect2())
			if a_rect.intersects(b_rect):
				failures.append("%s hit regions overlap: %s/%d and %s/%d." % [
					label,
					str(a.get("action", "")),
					int(a.get("index", -1)),
					str(b.get("action", "")),
					int(b.get("index", -1)),
				])


func _surface_contract_environment() -> Dictionary:
	return {
		"id": "surface_contract_room",
		"display_name": "Surface Contract Room",
		"economic_profile": {
			"stake_floor": 1,
			"stake_ceiling": 20,
		},
		"security_profile": {},
	}


func _blackjack_test_count_delta(cards: Array) -> int:
	var delta := 0
	for card_value in cards:
		if typeof(card_value) != TYPE_DICTIONARY:
			continue
		var rank := int((card_value as Dictionary).get("rank", 2))
		if rank >= 2 and rank <= 6:
			delta += 1
		elif rank == 10 or rank == 11 or rank == 12 or rank == 13 or rank == 14:
			delta -= 1
	return delta


func _blackjack_test_result_count_delta(result: Dictionary) -> int:
	var cards: Array = []
	for hand_value in result.get("blackjack_player_hands", []):
		if typeof(hand_value) != TYPE_DICTIONARY:
			continue
		for card_value in (hand_value as Dictionary).get("cards", []):
			if typeof(card_value) == TYPE_DICTIONARY:
				cards.append((card_value as Dictionary).duplicate(true))
	for patron_hand_value in result.get("blackjack_patron_hands", []):
		if typeof(patron_hand_value) != TYPE_DICTIONARY:
			continue
		for card_value in (patron_hand_value as Dictionary).get("cards", []):
			if typeof(card_value) == TYPE_DICTIONARY:
				cards.append((card_value as Dictionary).duplicate(true))
	for card_value in result.get("blackjack_dealer", []):
		if typeof(card_value) == TYPE_DICTIONARY:
			cards.append((card_value as Dictionary).duplicate(true))
	return _blackjack_test_count_delta(cards)


func _blackjack_click_all_count_icons(game: GameModule, ui_state: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var next_state := ui_state.duplicate(true)
	var challenge: Dictionary = next_state.get("count_challenge", {}) if typeof(next_state.get("count_challenge", {})) == TYPE_DICTIONARY else {}
	var icons: Array = challenge.get("icons", []) if typeof(challenge.get("icons", [])) == TYPE_ARRAY else []
	var now_msec := Time.get_ticks_msec()
	for i in range(icons.size()):
		if typeof(icons[i]) != TYPE_DICTIONARY:
			continue
		var icon: Dictionary = (icons[i] as Dictionary).duplicate(true)
		icon["spawn_msec"] = now_msec - 10
		icon["duration_msec"] = 5000
		icons[i] = icon
	challenge["icons"] = icons
	next_state["count_challenge"] = challenge
	for i in range(icons.size()):
		var answer_click := game.surface_action_command("blackjack_count_icon", i, false, next_state, run_state, environment)
		next_state = answer_click.get("ui_state", {})
	return next_state


func _surface_hit_count(harness: SurfaceHarness, action_prefix: String) -> int:
	var count := 0
	for hit_value in harness.hit_regions:
		if typeof(hit_value) == TYPE_DICTIONARY and str((hit_value as Dictionary).get("action", "")).begins_with(action_prefix):
			count += 1
	return count


