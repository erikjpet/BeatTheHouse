extends SceneTree

# Reconstructed generated campaign, never original R11 or its two-pair hand.
# Setup visits use the maintained production generator/finalization helper.
# The tested departure uses ONLY the real closing talk, public map and Travel.
const Main := preload("res://scripts/ui/foundation_main.gd")
const Map := preload("res://scripts/core/world_map.gd")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const SLOT := "closing_fallback_public"
class OwnedHost extends Main:
	func _prewarm_run_ui_after_web_start() -> void: pass
var app: Variant
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}
var references: Array = []
var private_root := ""
var completed := false
var baseline := false

func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	baseline = OS.get_cmdline_user_args().has("--baseline")
	if not _private_roots(): _finish(); return
	if OS.get_cmdline_user_args().has("--cold"): _cold(); _finish(); return
	root.size = Vector2i(1280, 720)
	app = OwnedHost.new(); app.continuous_environment_clock_enabled = false; app.script_prewarm_stopping = true
	root.add_child(app); app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); app.set_process(false)
	await process_frame
	app.user_settings.coach_tips_enabled = false
	if not _setup(): _finish(); return
	var run: RunState = app.run_state
	if not _check(app.enter_game("video_poker"), "generated Lounge offers normal Video Poker entry"): _finish(); return
	var quoted_stake: int = app._sealed_action_host_preview_wager_cost("draw", app.selected_stake)
	_check(quoted_stake > 0 and quoted_stake <= run.bankroll, "ordinary cabinet quotes an affordable posted stake before payment")
	_check(app._travel_target_ids() == _ordinary_ids() and app._closing_time_walk_fallback_target_id().is_empty(), "open venue retains ordinary capped routes without a closing override")
	var before := _protected(run)
	app._on_game_surface_action("video_poker_deal", 0, false)
	await create_timer(1.3).timeout
	_check(run.bankroll == before.cash and run.grand_casino_chips == before.chips and app._current_wager_activity_incomplete(), "ordinary Deal opens pending natural hand without charging twice")
	var hand: Array = app.game_surface_canvas.state.get("hand", [])
	for index in _holds(hand): app._on_game_surface_action("video_poker_hold", int(index), false)
	var clock_result := run.advance_game_clock_minutes(90)
	_check(bool(clock_result.get("ok", false)) and app._apply_closing_time_clock_boundary() and run.closing_time_active(), "production clock step from04:00 to05:30 starts closing grace with real wager pending")
	_check(not run.closing_time_forced_travel_required() and app._travel_target_ids() == _ordinary_ids(), "pending-wager grace retains ordinary capped routes")
	app._on_game_surface_action("video_poker_draw", 0, false)
	await create_timer(1.5).timeout
	var paid: Dictionary = app.last_game_result.duplicate(true)
	_check(bool(paid.get("ok", false)) and str(paid.get("action_id", "")) == "draw", "one normal Draw accepts its natural paid result")
	_check(int(paid.get("video_poker_bet", 0)) == quoted_stake, "natural hand uses exactly the actual posted stake")
	_check(run.bankroll == int(before.cash) + int(paid.get("bankroll_delta", 0)) and run.grand_casino_chips == before.chips, "natural prior hand pays its exact cash net once")
	_check(run.closing_time_forced_travel_required() and not run.pending_talk_event(app.CLOSING_TIME_TALK_EVENT_ID).is_empty(), "real completed wager consumes grace and queues closing notice")
	facts.merge({"natural_hand": {"stake": paid.get("video_poker_bet", 0), "gross": paid.get("video_poker_gross", 0), "net": paid.get("bankroll_delta", 0)}, "cash_after_hand": run.bankroll, "ordinary_ids": _ordinary_ids(), "original_hand_replayed": false}, true)
	var projection_before := _protected(run)
	app._on_talk_dock_choice_requested(app.CLOSING_TIME_TALK_EVENT_ID, app.CLOSING_TIME_TALK_CHOICE_ID)
	for frame in range(4): await process_frame
	_check(app._world_map_overlay_is_visible() and run.pending_talk_event(app.CLOSING_TIME_TALK_EVENT_ID).is_empty(), "actual Take-the-hint callback opens public departure map")
	var target: String = app._closing_time_walk_fallback_target_id()
	var ordinary := _ordinary_ids()
	_check(not target.is_empty() and ordinary.size() == Map.TRAVEL_TOTAL_TARGET_LIMIT and not ordinary.has(target), "generated visited eligible fallback lies outside the real ordinary three-card cap")
	var choice: Dictionary = app._travel_choice(target)
	var exposed: bool = app._travel_target_ids().has(target) and not choice.is_empty()
	facts.merge({"fallback_id": target, "public_ids": app._travel_target_ids(), "fallback_exposed": exposed, "map_clock": run.game_clock_minutes}, true)
	_check(exposed, "forced closing retains selected fallback in executable public map choices despite ordinary cap")
	_check(_protected(run) == projection_before, "closing acknowledgement and public map projections preserve wallet RNG clock complete history and paid game states")
	if baseline: completed = true; _finish(); return
	if not exposed: _finish(); return
	_save(run, SLOT + "_closed")
	var map_node: Dictionary = {}
	for node in app._world_map_snapshot().get("nodes", []):
		if str(node.get("id", "")) == target: map_node = node; break
	facts["fallback_map_node"] = {"travel_target": map_node.get("travel_target", false), "travel_enabled": map_node.get("travel_enabled", false), "cost": map_node.get("cost", -1), "method": map_node.get("travel_method", ""), "reason": map_node.get("travel_disabled_reason", "")}
	_check(bool(map_node.get("travel_target", false)) and bool(map_node.get("travel_enabled", false)) and int(map_node.get("cost", -1)) == 0 and str(map_node.get("travel_method", "")) == "Walk", "actual enriched map node agrees with enabled zero-cost Walk choice")
	if not _check(app.select_world_map_node(target), "normal public map selects retained fallback"): _finish(); return
	choice = app._travel_choice(target)
	facts["quote"] = {"cost": choice.get("cost", -1), "minutes": choice.get("travel_minutes", 0), "method": choice.get("route", {}).get("travel_method", ""), "enabled": choice.get("enabled", false), "detail": app.world_map_detail_label.text}
	_check(bool(choice.get("enabled", false)) and bool(choice.get("force_walk_fallback", false)) and int(choice.get("cost", -1)) == 0 and str(choice.get("route", {}).get("travel_method", "")) == "Walk", "actual selected public quote is enabled zero-cost Walk")
	_check(app.world_map_detail_label.is_visible_in_tree() and app.world_map_confirm_button.is_visible_in_tree() and not app.world_map_confirm_button.disabled and app.world_map_detail_label.text.contains("Walk"), "real map displays Walk quote and enabled Travel control")
	before = _protected(run)
	var source := run.current_world_node_id()
	var source_games: Dictionary = run.current_environment.get("game_states", {}).duplicate(true)
	var paid_state_key: String = app._environment_active_game_state_key(run.current_environment, "video_poker")
	_check(not source_games.get(paid_state_key, {}).is_empty(), "settled paid Video Poker cabinet state is populated before departure")
	var result: Dictionary = app.confirm_world_map_travel()
	facts["travel"] = {"ok": result.get("ok", false), "errors": result.get("errors", []).duplicate(true)}
	if _check(bool(result.get("ok", false)), "normal public Travel commits the selected fallback once"):
		_check(run.current_world_node_id() == target and run.bankroll == before.cash and run.grand_casino_chips == before.chips and run.game_clock_minutes == int(before.clock) + int(choice.get("travel_minutes", 0)), "arrival charges zero and advances exactly quoted Walk minutes")
		_check(run.story_log.slice(0, before.history.size()) == before.history and _count(run, "travel") == int(before.travel_count) + 1 and _count(run, "game_action") == int(before.game_count), "travel preserves FULL paid history and adds exactly one trip without replaying hand")
		_check(Map.node_by_id(run.world_map, source).get("environment", {}).get("game_states", {}) == source_games, "departure caches exact already-paid source cabinet states")
		var arrived := _protected(run)
		var repeated: Dictionary = app.confirm_world_map_travel()
		_check(not bool(repeated.get("ok", false)) and _protected(run) == arrived, "duplicate public confirmation cannot charge or commit another trip")
		_check(bool(run.validate_room_action_authority().get("ok", false)), "normal arrival retains strict destination room authority")
		_save(run, SLOT + "_arrived")
		_reopening()
		_write(_reference_path(), references)
		completed = true
	_finish()

func _setup() -> bool:
	# Only initial owned state is reconstructed: generated visits, cash12 and
	# nighttime via the production clock API. No route/outcome/authority is made.
	facts["candidate_diagnostics"] = []
	for index in range(4):
		if not _check(app.start_foundation_run("CLOSING-PUBLIC-NATIVE-%d" % index, {}, false), "fresh ordinary campaign generates playable first room"): return false
		var run: RunState = app.run_state
		var errors: Array = []
		for visited_id in ["back_alley", "bar", "jazz_club"]:
			if not _check(bool(Fidelity.generate_and_finalize(app.generator, run, errors, "owned visited stop " + visited_id, visited_id, true).get("ok", false)), "normal generator finalizes visited " + visited_id + ": " + str(errors)): return false
		run.change_bankroll(12 - run.bankroll, true)
		if not _check(bool(run.advance_game_clock_minutes(1680 - run.game_clock_minutes).get("ok", false)), "owned nighttime setup uses ordinary clock progression"): return false
		if not _check(bool(Fidelity.generate_and_finalize(app.generator, run, errors, "owned Lounge arrival", "kitty_cat_lounge", true).get("ok", false)), "normal generator finalizes Lounge: " + str(errors)): return false
		app.current_game = null; app._set_active_game_binding(); app._refresh_runtime_environment_views(); app._set_current_screen("ENVIRONMENT"); app._invalidate_travel_view_cache(); app._refresh()
		var has_video: bool = run.current_environment.get("game_ids", []).has("video_poker")
		var ordinary := _ordinary_ids()
		var eligible_ids: Array = []
		var eligible_inside_ids: Array = []
		for id in Map.visible_node_ids(run.world_map):
			if str(id) == run.current_world_node_id(): continue
			var node := Map.node_metadata_by_id(run.world_map, str(id))
			if str(node.get("state", "")) != Map.STATE_VISITED: continue
			var archetype: Dictionary = app._environment_archetype(str(id))
			if str(archetype.get("kind", "")) == "home" or bool(app._environment_open_status(archetype).get("always_open", false)):
				if app._world_route_for_target(str(id)).is_empty(): continue
				eligible_ids.append(str(id))
				if ordinary.has(id): eligible_inside_ids.append(str(id))
		var rejected_reasons: Array = []
		if not has_video: rejected_reasons.append("generated Lounge lacks Video Poker")
		if ordinary.size() != Map.TRAVEL_TOTAL_TARGET_LIMIT: rejected_reasons.append("ordinary list does not fill normal three-card cap")
		if eligible_ids.is_empty(): rejected_reasons.append("no visited eligible fallback has a production route")
		if not eligible_inside_ids.is_empty(): rejected_reasons.append("eligible fallback still present in ordinary cap")
		facts.candidate_diagnostics.append({"seed": run.seed_text, "cash": run.bankroll, "clock": run.game_clock_minutes, "game_ids": run.current_environment.get("game_ids", []).duplicate(), "has_video_poker": has_video, "ordinary_ids": ordinary, "eligible_ids": eligible_ids, "eligible_inside_ids": eligible_inside_ids, "rejected_reasons": rejected_reasons})
		if rejected_reasons.is_empty():
			facts.merge({"seed": run.seed_text, "setup_candidates": index + 1, "setup": "fresh normal campaign; production-generated Alley/Bar/Jazz/Lounge visits, initial cash12 and production clock advance to04:00", "source_authority_valid": run.validate_room_action_authority().get("ok", false)}, true)
			return _check(bool(run.validate_room_action_authority().get("ok", false)), "generated Lounge has valid production room authority")
	return _check(false, "four generated candidates did not offer Video Poker and an excluded eligible visited fallback")
func _ordinary_ids() -> Array:
	return Map.travel_target_ids(app.run_state.world_map, app.run_state.current_world_node_id(), Map.TRAVEL_NEW_TARGET_LIMIT, Map.TRAVEL_TOTAL_TARGET_LIMIT, app._enabled_world_route_ids(app.run_state.current_world_node_id()))
func _holds(hand: Array) -> Array:
	for a in range(hand.size()):
		for b in range(a + 1, hand.size()):
			if int(hand[a].get("rank", 0)) == int(hand[b].get("rank", 0)): return [a, b]
	return []
func _reopening() -> void:
	# Independent owned branch, never the accepted arrival. Simulated elapsed
	# time crosses the real frame-clock boundary; no claim of hours of wall wait.
	var branch: Variant = SaveService.new().load_run(SLOT + "_closed")
	if not _check(branch is RunState, "separate reopening branch officially loads closed state"): return
	app.run_state = branch; app.current_game = null; app._set_active_game_binding(); app._refresh_runtime_environment_views(); app._set_current_screen("ENVIRONMENT"); app._clear_input_guard_modal_state()
	app.continuous_environment_clock_enabled = true
	app.open_world_map(true)
	var before := _protected(branch)
	app._advance_run_game_clock(60.0)
	var map_paused := _protected(branch) == before
	_check(map_paused, "shown departure map pauses actual production frame clock")
	app.close_world_map()
	var minutes: int = 780 - branch.game_minute_of_day()
	app._advance_run_game_clock(float(minutes) / app.GAME_CLOCK_MINUTES_PER_REAL_SECOND)
	_check(branch.game_minute_of_day() == 780 and not branch.closing_time_active() and not app._closing_time_blocks_environment_actions(), "outside map simulated elapsed production time reaches13:00 and clears closing restriction")
	_check(app._closing_time_walk_fallback_target_id().is_empty() and app._travel_target_ids() == _ordinary_ids(), "reopening clears the stale free-departure override and restores ordinary route caps")
	_check(branch.bankroll == before.cash and branch.grand_casino_chips == before.chips and _count(branch, "game_action") == int(before.game_count), "reopening time step never replays prior paid hand or changes wallets")
	facts["reopening"] = {"map_pauses_time": map_paused, "from_clock": before.clock, "to_clock": branch.game_clock_minutes, "closing_active": branch.closing_time_active(), "rng_unchanged_during_ordinary_time_effects": str(branch.rng_state) == before.rng, "history_rows_added_by_ordinary_time_effects": branch.story_log.size() - before.history.size(), "scope": "simulated elapsed delta through normal frame clock; no real-hours wait"}
	app.continuous_environment_clock_enabled = false
func _count(run: RunState, type: String) -> int:
	var count := 0
	for row in run.story_log:
		if str(row.get("type", "")) == type: count += 1
	return count
func _protected(run: RunState) -> Dictionary:
	var cached_games: Dictionary = {}
	for node in run.world_map.get("nodes", []): cached_games[str(node.get("id", ""))] = node.get("environment", {}).get("game_states", {}).duplicate(true)
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "clock": run.game_clock_minutes, "simulation_msec": run.simulation_msec, "rng_seed": str(run.rng_seed), "rng": str(run.rng_state), "history": run.story_log.duplicate(true), "environment_history": run.environment_history.duplicate(true), "closing": run.closing_time_state.duplicate(true), "node": run.current_world_node_id(), "games": run.current_environment.get("game_states", {}).duplicate(true), "cached_games": cached_games, "travel_count": _count(run, "travel"), "game_count": _count(run, "game_action"), "inventory": run.inventory.duplicate(true), "debt": run.debt.duplicate(true)}
func _save(run: RunState, slot: String) -> void:
	var before := _protected(run)
	if not _check(SaveService.new().save_run(run, slot) == OK, "official private Save: " + slot): return
	_check(_protected(run) == before, "Save changes no prior outcome history wallet RNG or room state")
	var loaded: Variant = SaveService.new().load_run(slot)
	if not _check(loaded is RunState, "fresh official service reloads: " + slot): return
	_check(Runtime.content_fingerprint(JSON.parse_string(JSON.stringify(_protected(loaded)))) == Runtime.content_fingerprint(JSON.parse_string(JSON.stringify(before))), "official load preserves FULL protected source/arrival state")
	references.append({"slot": slot, "protected_json": JSON.stringify(_protected(loaded))})
func _cold() -> void:
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(_reference_path()))
	if not _check(expected is Array and expected.size() == 2, "closed source and accepted arrival references exist"): return
	for reference in expected:
		var loaded: Variant = SaveService.new().load_run(str(reference.slot))
		if not _check(loaded is RunState, "independent cold official load: " + str(reference.slot)): continue
		_check(JSON.stringify(_protected(loaded)) == str(reference.protected_json), "independent cold retains FULL history cached paid outcome wallets clock RNG and exactly-once travel: " + str(reference.slot))
	completed = true
func _reference_path() -> String: return private_root.path_join("closing-fallback-public-reference.json")
func _write(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if _check(file != null, "owned JSON opens"): file.store_string(JSON.stringify(value, "\t")); file.close()
func _private_roots() -> bool:
	private_root = OS.get_environment("BTH_WORLD_REENTRY_ROOT").replace("\\", "/").simplify_path()
	if not _check(private_root.is_absolute_path() and "native-private-" in private_root, "explicit disposable native root required"): return false
	for key in ["APPDATA", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path().to_lower()
		if not _check(path == private_root.to_lower() or path.begins_with(private_root.to_lower() + "/"), "private containment: " + key): return false
	return _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "no original player save/browser profile imported")
func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok
func _finish() -> void:
	_check(completed, "bounded requested phase completes")
	var report := {"id": "BTH-TRAVEL-CLOSING-FALLBACK-R11-1067", "mode": "cold" if OS.get_cmdline_user_args().has("--cold") else "baseline" if baseline else "producer", "checks": checks, "failures": failures, "facts": facts, "fidelity": "Fresh reconstructed native Foundation campaign and production-generated/finalized visits, initial cash12 and production clock setup. One natural actual Host Video Poker hand consumes real closing grace, real TalkDock acknowledgement/public map/selected quote/Travel dispatch. No original R11 save or two-pair replay, handcrafted zero route, authority bypass, pinned old-Web replay, outcome/item/scenario modifications or new native kernel/physics calls. Reopening uses simulated elapsed frame-clock delta, not real-hours wait. Official SaveService and separate cold.", "source_sha256": {"travel_view": FileAccess.get_sha256("res://scripts/ui/foundation_travel_view_model.gd"), "world_map": FileAccess.get_sha256("res://scripts/core/world_map.gd"), "test": FileAccess.get_sha256("res://scripts/tests/travel_closing_fallback_public_check.gd")}}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty(): _write(output, report)
	if app != null:
		app.save_service.wait_for_async_save()
		if app.get_parent() != null: app.get_parent().remove_child(app)
		app.free()
	print("TRAVEL_CLOSING_FALLBACK_PUBLIC_RESULT " + JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
