extends SceneTree

# BTH061-ROULETTE-SEALED-PENDING-001. Independent explicitly staged cash fixture.
# This is not normal travel, Practice, the original R08 run, or an outcome search.
# Only fixture inputs are configured before source generation/installation. The
# actual MainScene retains its production input, clock, publication and authority.
const MainScene := preload("res://scenes/main.tscn")
const Authority := preload("res://scripts/core/blackjack_action_authority.gd")
const SEED := "BTH061-ROULETTE-SEALED-PENDING-001-A"
const WEB_SEED_B := "BTH061-ROULETTE-SEALED-PENDING-001-B"
const STAKE := 9

var fixture_seed := SEED
var private_root := ""
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {"seed": fixture_seed, "fixture": "Explicit staged generated Riverboat cash80/min9, Roulette only; no normal-travel claim", "original_state_used": false, "practice_used": false, "outcome_selection": false, "retry_or_cancel_used": false, "boundaries": []}
var completed := false
var paced := false
var after_blackjack := false
var prepare_web := false
var prepare_web_b := false
var observe_blackjack := false


func _initialize() -> void:
	prepare_web_b = OS.get_cmdline_user_args().has("--prepare-web-b")
	prepare_web = prepare_web_b or OS.get_cmdline_user_args().has("--prepare-web")
	fixture_seed = WEB_SEED_B if prepare_web_b else SEED
	facts["seed"] = fixture_seed
	after_blackjack = OS.get_cmdline_user_args().has("--after-blackjack")
	observe_blackjack = OS.get_cmdline_user_args().has("--observe-blackjack")
	paced = after_blackjack or OS.get_cmdline_user_args().has("--paced")
	facts["mode"] = "observe-blackjack-counts" if observe_blackjack else "prepare-web-b-prepaid-floor" if prepare_web_b else "prepare-web-prepaid-floor" if prepare_web else "after-blackjack-frame-paced" if after_blackjack else "frame-paced" if paced else "immediate"
	if observe_blackjack:
		facts["fixture"] = "New own staged generated Riverboat cash80/min9 with shipped three-game set; one declared Blackjack Deal then count-only observation, no Stand or Roulette input"
	elif prepare_web:
		facts["fixture"] = "New own staged generated Riverboat cash80/min9 with shipped three-game set; prepaid floor only, no game input or normal-travel claim"
	elif after_blackjack:
		facts["fixture"] = "Explicit staged generated Riverboat initial cash80/min9, shipped Blackjack/Roulette/VideoPoker game set; one natural Blackjack hand then paced Roulette with actual remaining wallet/RNG, no normal-travel claim"
	private_root = OS.get_environment("BTH_R08_ROULETTE_PRIVATE_ROOT").replace("\\", "/").simplify_path().trim_suffix("/")
	if not _private_paths():
		_finish()
		return
	if prepare_web_b and (observe_blackjack or after_blackjack or paced):
		_check(false, "Predeclared Web seed B preparation must run separately from gameplay/observation modes")
		_finish()
		return
	if observe_blackjack and not _check(not (prepare_web or after_blackjack or paced), "Count-only Blackjack observation must run separately from all other diagnostic modes"):
		_finish()
		return
	call_deferred("_run")


func _inside(path: String) -> bool:
	var normalized := path.replace("\\", "/").simplify_path().trim_suffix("/").to_lower()
	return not private_root.is_empty() and (normalized == private_root.to_lower() or normalized.begins_with(private_root.to_lower() + "/"))


func _private_paths() -> bool:
	if not _check(private_root.is_absolute_path() and "native-private-" in private_root and not OS.has_feature("web"), "Native diagnostic requires an explicit disposable BTH_R08_ROULETTE_PRIVATE_ROOT"):
		return false
	if not _check(_inside(ProjectSettings.globalize_path("user://")), "Actual user:// must be inside the explicit private root before host/services initialize"):
		return false
	for key in ["APPDATA", "LOCALAPPDATA", "USERPROFILE", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_SAVE_DIR", "BTH_USER_SETTINGS_PATH", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH"]:
		var path := OS.get_environment(key)
		if not _check(not path.is_empty() and _inside(ProjectSettings.globalize_path(path)), "Private incoming persistence containment: " + key):
			return false
	for key in ["BTH_DEVELOPER_PLACEMENT_PATH", "BTH_DEVELOPER_PLACEMENT_REPORT_PATH"]:
		var path := OS.get_environment(key)
		if not _check(path.is_empty() or _inside(ProjectSettings.globalize_path(path)), "Private optional placement persistence containment: " + key):
			return false
	return _check(OS.get_environment("BTH_PROJECT_PLACEMENT_PATH").is_empty() and OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "Shipped placement and no original fixture/browser inputs required")


func _run() -> void:
	await _case()
	completed = true
	_finish()


func _case() -> void:
	var app: Control = MainScene.instantiate()
	root.add_child(app)
	for _frame in range(4):
		await process_frame
	var service: SaveService = app.get("save_service")
	var slot := "foundation_ui_autosave" if prepare_web else "roulette-sealed-pending"
	if not _check(service != null and _inside(ProjectSettings.globalize_path(service.run_save_path(slot))), "Actual SaveService path must remain inside the private root"):
		await _close(app)
		return
	if not _check(not FileAccess.file_exists(service.run_save_path(slot)), "Independent case requires an unused diagnostic save slot"):
		await _close(app)
		return
	app.set("autosave_slot_id", slot)
	app.get("user_settings").coach_tips_enabled = false
	app.call("_ensure_full_content_library_loaded")
	if not _check(bool(app.call("_ensure_run_ui_built")), "Actual Foundation run interface builds"):
		await _close(app)
		return
	var library: ContentLibrary = app.get("library")
	var run := RunState.new()
	run.start_new(fixture_seed)
	run.begin_act(1)
	run.bankroll = 80
	run.grand_casino_chips = 0
	var archetype: Dictionary = library.environment_archetype("delta_queen").duplicate(true)
	if not _check(not archetype.is_empty(), "Shipped flat Riverboat cash archetype is available"):
		await _close(app)
		return
	# Explicit independent input configuration, entirely before table generation.
	# Retain the shipped Riverboat room/slots/content; no scenario or wheel is set.
	if not after_blackjack and not prepare_web and not observe_blackjack:
		archetype["game_pool"] = ["roulette"]
		archetype["required_game_ids"] = ["roulette"]
		archetype["game_count"] = [1, 1]
	var economy: Dictionary = archetype.get("economic_profile", {}).duplicate(true)
	economy["stake_floor"] = STAKE
	economy["stake_ceiling"] = 100
	economy["game_stake_floor_overrides"] = {"roulette": STAKE, "blackjack": STAKE} if after_blackjack or prepare_web or observe_blackjack else {"roulette": STAKE}
	economy["game_stake_ceiling_overrides"] = {"roulette": 100}
	archetype["economic_profile"] = economy
	var generator := RunGenerator.new(library)
	var generation_rng := run.create_rng("r08_roulette_independent_fixture")
	var environment: Dictionary = EnvironmentInstance.from_archetype(archetype, 0, generation_rng, library, run.challenge_config).to_dict()
	environment["game_states"] = generator._generated_game_states(run, environment, generation_rng)
	# Source-equivalent finalization of this freshly generated destination only:
	# RunGenerator._world_environment_data_for_node performs this after game hooks.
	for key in ["object_manifest", "object_manifest_digest", "object_manifest_revision"]:
		environment.erase(key)
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment, library)
	var installed: Dictionary = generator._install_environment(run, environment)
	if not _check(bool(installed.get("ok", false)), "Trusted generated environment installation: " + JSON.stringify(installed.get("errors", []))):
		await _close(app)
		return
	app.set("run_state", run)
	app.set("generator", generator)
	app.call("_bind_run_state_presentation_signals")
	app.call("_configure_coach_for_run")
	app.call("_refresh_run_action_service")
	app.call("_sync_presented_bankroll_to_actual")
	app.call("_queue_room_publication_check")
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_refresh")
	for _frame in range(12):
		await process_frame
		if int(app.get("room_publication_checked_generation")) >= int(app.get("room_publication_generation")):
			break
	var proof := run.validate_room_action_authority()
	facts["fixture_authority"] = {"ok": proof.get("ok", false), "errors": proof.get("errors", []), "publication_checked": app.get("room_publication_checked_generation"), "publication_generation": app.get("room_publication_generation"), "continuous_clock_enabled": app.get("continuous_environment_clock_enabled")}
	if not _check(bool(proof.get("ok", false)) and int(app.get("room_publication_checked_generation")) >= int(app.get("room_publication_generation")), "Fixture must have real published room/action authority before input"):
		await _close(app)
		return
	if not _check(not run.is_tutorial_run() and not bool(app.get("dev_game_test_mode")) and not bool(app.get("dev_environment_test_mode")) and not bool(app.call("_is_environment_test_session")) and not run.grand_casino_game_uses_chips("roulette", run.current_environment), "Fixture is cash and has no tutorial or Practice authority"):
		await _close(app)
		return
	if not _check(bool(app.get("continuous_environment_clock_enabled")) and app.is_processing(), "Normal host processing and continuous clock remain enabled"):
		await _close(app)
		return
	if observe_blackjack:
		await _observe_blackjack(app)
		await _close(app)
		return
	if prepare_web:
		_prepare_web_fixture(app)
		await _close(app)
		return
	if after_blackjack and not (await _blackjack_before_roulette(app)):
		await _close(app)
		return
	var roulette_initial_cash := run.bankroll
	facts["roulette_initial_cash"] = roulette_initial_cash
	if not _check(bool(app.call("enter_game", "roulette")), "Normal production Roulette entry succeeds"):
		facts["entry_message"] = _message(app)
		await _close(app)
		return
	if not _check(str(app.get("current_game_state_key")) == "roulette" and str((app.get("current_game") as GameModule).get_id()) == "roulette" and str(run.current_environment.get("active_game_id", "")) == "roulette", "Normal entry binds the real Roulette module and installed table state key"):
		await _close(app)
		return
	var table := _table(run)
	facts["generated_table"] = {"name": table.get("table_name", ""), "outside_minimum": table.get("rules", {}).get("outside_min_each", -1), "spin_count": table.get("spin_count", -1), "cash": run.bankroll, "chips": run.grand_casino_chips}
	var denoms: Array = table.get("chip_denominations", [])
	if not _check(denoms.has(STAKE) and int(table.get("rules", {}).get("outside_min_each", -1)) == STAKE and run.bankroll == roulette_initial_cash and roulette_initial_cash >= STAKE and int(table.get("spin_count", -1)) == 0, "Source-generated fixture retains min9, actual affordable cash and no prior Roulette spin"):
		await _close(app)
		return
	var canvas: Control = app.get("game_surface_canvas")
	var surface: Dictionary = canvas.call("realtime_surface_state")
	var targets: Array = surface.get("bet_targets", [])
	var red := -1
	for index in range(targets.size()):
		if str((targets[index] as Dictionary).get("type", "")) == "red":
			red = index
	if not _check(red >= 0, "Actual rendered table exposes the normal RED target"):
		await _close(app)
		return
	var initial_rng := run.rng_state
	var initial_clock := run.game_clock_minutes
	app.call("_on_game_surface_action", "roulette_chip", denoms.find(STAKE))
	if paced and not (await _pace(app, "chip-to-red", 0.4)):
		await _close(app)
		return
	var before_bet_rng := run.rng_state
	var before_bet_clock := run.game_clock_minutes
	app.call("_on_game_surface_action", "roulette_bet", red)
	facts.boundaries.append(_boundary(app, "one-red-bet", initial_rng))
	if not _check(_pending_total(run) == STAKE and run.bankroll == roulette_initial_cash and run.rng_state == before_bet_rng and run.game_clock_minutes == before_bet_clock, "One ordinary RED callback stages exactly9 without synchronous debit/RNG/action-clock advance"):
		await _close(app)
		return
	if paced and not (await _pace(app, "red-to-spin", 0.4)):
		await _close(app)
		return
	app.call("_on_game_surface_action", "roulette_spin", 0)
	facts.boundaries.append(_boundary(app, "spin-arms", initial_rng))
	if not _check(bool(_session(run).get("roulette_spin_armed", false)) and not _has_pending(run) and int(_table(run).get("spin_count", 0)) == 0 and run.bankroll == roulette_initial_cash and run.rng_state == initial_rng, "First normal SPIN arms without sealing or settling"):
		await _close(app)
		return
	if paced and not (await _pace(app, "armed-spin-to-confirm", 1.0)):
		await _close(app)
		return
	# Native roulette.gd draws CONFIRM with exactly the same roulette_spin action.
	# One callback traverses _handle_module_surface_action, command application,
	# _resolve_game_action and the real sealed host. Never retry/cancel afterward.
	var before_confirm_result := _result_summary(app)
	facts["preconfirm_clock"] = _clocks(app)
	facts["passive_game_minutes_before_confirm"] = run.game_clock_minutes - initial_clock
	facts["before_confirm_stake_ranges"] = _stake_ranges(app)
	app.call("_on_game_surface_action", "roulette_spin", 0)
	facts.boundaries.append(_boundary(app, "single-native-confirm-immediate", initial_rng))
	facts["after_confirm_stake_ranges"] = _stake_ranges(app)
	facts["last_result_changed_on_confirm"] = _result_summary(app) != before_confirm_result
	var result: Dictionary = app.get("last_game_result")
	var accepted := bool(result.get("ok", false)) and str(result.get("game_id", "")) == "roulette" and str(result.get("action_id", "")) == "spin_roulette" and bool(result.get(Authority.HOST_COMMITTED_KEY, false))
	_check(accepted and not _has_pending(run), "Single native CONFIRM must accept its sealed spin without stranded pending; see immediate boundary diagnostics")
	if accepted and not _has_pending(run):
		_check(int(_table(run).get("spin_count", 0)) == 1 and _pending_total(run) == 0 and int(result.get("roulette_total_wager", -1)) == STAKE and (_table(run).get(Authority.LEDGER_KEY, {}).get("request_order", []) as Array).size() == 1, "Exactly one confirmed nine-unit spin/request consumes the draft")
		var deltas: Dictionary = result.get("deltas", {})
		_check(run.bankroll == roulette_initial_cash + int(result.get("bankroll_delta", deltas.get("bankroll_delta", 0))) and run.grand_casino_chips == 0, "Natural result conserves the cash wager exactly once without chip conversion")
		_check(not (result.get(Authority.HOST_APPLY_RECEIPT_KEY, {}) as Dictionary).is_empty(), "Accepted action carries its real host receipt")
	# Stop at the first Confirm, whether accepted, refused or left pending.
	await _close(app)


func _prepare_web_fixture(app: Control) -> void:
	var run: RunState = app.get("run_state")
	var service: SaveService = app.get("save_service")
	var table := _table(run)
	var before_rng := run.rng_state
	var before_clock := run.game_clock_minutes
	if not _check(str(app.get("current_screen")) == "ENVIRONMENT" and app.get("current_game") == null and run.bankroll == 80 and run.grand_casino_chips == 0 and int(table.get("spin_count", -1)) == 0 and int(table.get("rules", {}).get("outside_min_each", -1)) == STAKE and not _has_pending(run) and _pending_total(run) == 0, "Web preparation stops on the new prepaid cash80/min9 floor before every game input"):
		return
	# Official synchronous Save forces durable completion; do not encode/edit a
	# save or companion in this helper, and never read any earlier fixture root.
	if not _check(service.save_run(run, "foundation_ui_autosave") == OK, "Official synchronous Save prepares the production Continue slot"):
		return
	if not _check(int(app.get("meta_collection_service").save()) == OK and int(app.get("user_settings").save()) == OK and int(app.get("profile_inventory").save()) == OK, "Official services persist this new fixture's own meta/settings/profile"):
		return
	if not _check(bool(app.call("load_foundation_run")), "Normal official Continue accepts the newly prepared fixture and companions"):
		return
	var loaded: RunState = app.get("run_state")
	var proof := loaded.validate_room_action_authority()
	var loaded_table := _table(loaded)
	if not _check(loaded != run and loaded.seed_text == fixture_seed and loaded.bankroll == 80 and loaded.grand_casino_chips == 0 and loaded.rng_state == before_rng and loaded.game_clock_minutes == before_clock and int(loaded_table.get("spin_count", -1)) == 0 and int(loaded_table.get("rules", {}).get("outside_min_each", -1)) == STAKE and not _has_pending(loaded) and _pending_total(loaded) == 0 and bool(proof.get("ok", false)), "Official Continue preserves prepaid wallet/RNG/clock/min9/spin0 and full room authority"):
		return
	var runtime_root := "/userfs/godot/app_userdata/Beat the House"
	var specifications := [
		["qa-run.json", service.run_save_path("foundation_ui_autosave"), "/distribution/web_0_6_1/saves/foundation_ui_autosave.json"],
		["qa-meta.json", OS.get_environment("BTH_META_COLLECTION_PATH"), "/distribution/web_0_6_1/meta_collection.json"],
		["qa-settings.json", OS.get_environment("BTH_USER_SETTINGS_PATH"), "/distribution/web_0_6_1/settings.json"],
		["qa-profile.json", OS.get_environment("BTH_PROFILE_INVENTORY_PATH"), "/distribution/web_0_6_1/profile_inventory.json"],
		["qa-authority.bin", "user://.crew_host_authority_v1", "/.crew_host_authority_v1"],
	]
	var files: Array = []
	for specification in specifications:
		var path := ProjectSettings.globalize_path(str(specification[1]))
		if not _check(_inside(path) and FileAccess.file_exists(path), "New own prepared file exists inside the validated root: " + str(specification[0])):
			return
		var file := FileAccess.open(path, FileAccess.READ)
		if not _check(file != null, "Prepared own file can be sized: " + str(specification[0])):
			return
		var size := file.get_length()
		file.close()
		files.append({"url": specification[0], "source_path": path, "runtime_path": runtime_root + str(specification[2]), "bytes": size, "sha256": FileAccess.get_sha256(path)})
	facts["web_fixture_manifest"] = {"task_id": "BTH061-ROULETTE-SEALED-PENDING-001", "original_campaign_accessed": false, "prepaid_fixture": true, "native_continue_validated": true, "runtime_source_commit": "f3058b6daab820e9d747c4c4aabc2d983e9ae32e", "runtime_compatibility_tested": false, "facts": {"seed": fixture_seed, "cash": loaded.bankroll, "outside_minimum": STAKE, "spin_count": 0, "room_authority_valid": true, "generated_table_name": loaded_table.get("table_name", ""), "game_inputs": 0}, "files": files}
	facts["preparation_limit"] = "Own new files remain in the native private root; no bundle copy, asset export, Web launch or f305 Continue claim. Root stages only these files after validating this job."


func _observe_blackjack(app: Control) -> void:
	var run: RunState = app.get("run_state")
	var game_ids: Array = run.current_environment.get("game_ids", [])
	if not _check(game_ids.size() == 3 and game_ids.has("blackjack") and game_ids.has("roulette") and game_ids.has("video_poker") and run.bankroll == 80 and run.grand_casino_chips == 0, "Count observation starts in the new prepaid three-game fixture"):
		return
	if not _check(bool(app.call("enter_game", "blackjack")) and str(app.get("current_game_state_key")) == "blackjack", "Count observation uses normal Blackjack entry and binding"):
		return
	if not _check(bool(app.call("set_selected_stake", STAKE)), "Count observation selects its predeclared nine-unit wager"):
		return
	var rows: Array = []
	facts["blackjack_count_observation"] = rows
	facts["blackjack_observation_scope"] = "One declared native Deal only; then ordinary process frames without Deal, Stand, other game input or forced refresh. Counts and guards are diagnostic evidence, not prior-Blackjack/Roulette acceptance."
	var before := _blackjack_count_snapshot(app, "before-single-deal")
	rows.append(before)
	if not _check(not bool(before.get("pending_delivery", false)) and int(before.get("committed_request_count", -1)) == 0 and not bool((before.get("ledger_session", {}) as Dictionary).get("dealt", true)), "Fresh count observation has no prior hand or delivery before its single Deal"):
		return
	facts["blackjack_observation_dispatch"] = {"action": "blackjack_deal", "index": 0, "confirm_requested": false}
	app.call("_on_game_surface_action", "blackjack_deal", 0, false)
	var immediate := _blackjack_count_snapshot(app, "single-deal-immediate")
	rows.append(immediate)
	var opening: Dictionary = app.get("last_game_result")
	_check(bool(opening.get("ok", false)) and bool(opening.get(Authority.HOST_COMMITTED_KEY, false)) and str(opening.get("action_id", "")) == "blackjack_place_bet" and run.bankroll == 80 - STAKE and not bool(immediate.get("pending_delivery", true)) and int(immediate.get("committed_request_count", -1)) == 1, "The declared Deal records exactly one opening debit/request before count-only observation")
	# No further gameplay callback occurs in this mode. Keep the ordinary host
	# and canvas processing live; the samples only observe real frame boundaries.
	for elapsed_frames in range(1, 9):
		await process_frame
		if elapsed_frames in [1, 3, 8]:
			rows.append(_blackjack_count_snapshot(app, "after-%d-real-frames" % elapsed_frames))
	_check(rows.size() == 5, "Count observation retains before/immediate and 1/3/8-frame samples")


func _blackjack_hand_counts(source: Dictionary) -> Dictionary:
	var hands_value: Variant = source.get("player_hands", [])
	var hands: Array = hands_value as Array if typeof(hands_value) == TYPE_ARRAY else []
	var hand_card_counts: Array[int] = []
	for hand_value in hands:
		var hand: Dictionary = hand_value as Dictionary if typeof(hand_value) == TYPE_DICTIONARY else {}
		var cards_value: Variant = hand.get("cards", [])
		hand_card_counts.append((cards_value as Array).size() if typeof(cards_value) == TYPE_ARRAY else 0)
	var dealer_value: Variant = source.get("dealer_cards", [])
	var dealer_count := (dealer_value as Array).size() if typeof(dealer_value) == TYPE_ARRAY else 0
	var sit_out := bool(source.get("blackjack_sit_out", false))
	return {"player_hand_count": hands.size(), "player_card_counts": hand_card_counts, "dealer_card_count": dealer_count, "cards_consumed": int(source.get("cards_consumed", 0)), "dealt": dealer_count > 0 and (not hands.is_empty() or sit_out), "blackjack_sit_out": sit_out, "bankroll_wager_debited": bool(source.get("bankroll_wager_debited", false)), "wager_debited": int(source.get("wager_debited", 0)), "phase": str(source.get("phase", "")), "round_terminal": bool(source.get("round_terminal", false)), "settlement_pending": bool(source.get("settlement_pending", false))}


func _blackjack_count_snapshot(app: Control, label: String) -> Dictionary:
	var run: RunState = app.get("run_state")
	var table: Dictionary = run.current_environment.get("game_states", {}).get("blackjack", {})
	var ledger: Dictionary = table.get(Authority.LEDGER_KEY, {})
	var session: Dictionary = ledger.get("session", {})
	var result: Dictionary = app.get("last_game_result")
	var result_ui: Dictionary = result.get("ui_state", {}) if typeof(result.get("ui_state", {})) == TYPE_DICTIONARY else {}
	var canvas: Control = app.get("game_surface_canvas")
	var surface: Dictionary = canvas.call("realtime_surface_state")
	var projection: Dictionary = surface.get("ritual_projection", {})
	var states: Dictionary = projection.get("action_states", {})
	var refresh_pending := bool(app.get("deferred_embedded_refresh_pending"))
	var game: GameModule = app.get("current_game")
	return {
		"label": label, "process_frame": Engine.get_process_frames(), "clocks": _clocks(app), "cash": run.bankroll, "chips": run.grand_casino_chips,
		"pending_delivery": not (ledger.get("pending_delivery", {}) as Dictionary).is_empty(), "committed_request_count": (ledger.get("request_order", []) as Array).size(),
		"ledger_session": _blackjack_hand_counts(session), "last_game_result_ui": _blackjack_hand_counts(result_ui), "canvas_counts": _blackjack_hand_counts(surface),
		"result": {"ok": bool(result.get("ok", false)), "action_id": str(result.get("action_id", "")), "committed": bool(result.get(Authority.HOST_COMMITTED_KEY, false))},
		"public_readiness": {"phase": str(surface.get("phase", "")), "ritual_phase": str(projection.get("phase_id", "")), "can_deal": bool(surface.get("can_deal", false)), "can_stand": bool(surface.get("can_stand", false)), "deal_enabled": bool((states.get("blackjack_deal", {}) as Dictionary).get("enabled", false)), "stand_enabled": bool((states.get("blackjack_stand", {}) as Dictionary).get("enabled", false)), "deal_animation_active": bool(canvas.call("surface_animation_active", "blackjack_deal"))},
		"deferred_refresh": {"pending": refresh_pending, "generation": int(app.get("deferred_embedded_refresh_generation")), "scheduled": int(app.get("deferred_embedded_refresh_schedule_count")), "executed": int(app.get("deferred_embedded_refresh_execution_count")), "stale": int(app.get("deferred_embedded_refresh_stale_count")), "blocked_input": int(app.get("deferred_embedded_refresh_blocked_surface_input_count")), "identity_checked": refresh_pending, "identity_current": bool(app.call("_deferred_embedded_action_refresh_identity_is_current")) if refresh_pending else false},
		"binding": {"screen": str(app.get("current_screen")), "module_id": game.get_id() if game != null else "", "state_key": str(app.get("current_game_state_key")), "active_game_id": str(run.current_environment.get("active_game_id", ""))},
		"processing": {"host": app.is_processing(), "canvas": canvas.is_processing(), "canvas_visible": canvas.is_visible_in_tree(), "tree_paused": paused, "lifecycle": app.call("application_lifecycle_snapshot")},
		"modal_message": str(app.call("_blocking_modal_message")),
	}


func _blackjack_before_roulette(app: Control) -> bool:
	var run: RunState = app.get("run_state")
	var game_ids: Array = run.current_environment.get("game_ids", [])
	if not _check(game_ids.size() == 3 and game_ids.has("blackjack") and game_ids.has("roulette") and game_ids.has("video_poker") and run.game_day() == 1 and run.suspicion_level() == 0, "Cross-game case retains fresh Day1/Heat0 and the shipped three-game Riverboat set"):
		return false
	if not _check(bool(app.call("enter_game", "blackjack")) and str(app.get("current_game_state_key")) == "blackjack", "Normal Blackjack entry binds its own table before Roulette"):
		return false
	if not _check(bool(app.call("set_selected_stake", STAKE)), "Normal Blackjack wager selector accepts9"):
		return false
	var before_cash := run.bankroll
	var before_rng := run.rng_state
	var rows: Array = []
	facts["prior_blackjack"] = rows
	var count_rows: Array = []
	facts["prior_blackjack_counts"] = count_rows
	facts["prior_blackjack_dispatch_counts"] = {"deal": 1, "stand": 0}
	rows.append(_blackjack_boundary(app, "before-one-deal", before_rng))
	app.call("_on_game_surface_action", "blackjack_deal", 0, false)
	rows.append(_blackjack_boundary(app, "one-deal-immediate", before_rng))
	var opening: Dictionary = app.get("last_game_result")
	if not _check(bool(opening.get("ok", false)) and bool(opening.get(Authority.HOST_COMMITTED_KEY, false)) and str(opening.get("action_id", "")) == "blackjack_place_bet" and run.bankroll == before_cash - STAKE, "One normal Blackjack Deal commits exactly the nine-unit opening debit"):
		facts["fixture_limit"] = "The single normal Blackjack Deal did not accept; no financial input repeated"
		return false
	var wait_started_msec := Time.get_ticks_msec()
	var deadline := wait_started_msec + 20000
	var stood := false
	var settled := false
	var recorded_first_clear := false
	var recorded_one_second := false
	var recorded_five_seconds := false
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var table: Dictionary = run.current_environment.get("game_states", {}).get("blackjack", {})
		var ledger: Dictionary = table.get(Authority.LEDGER_KEY, {})
		var current_result: Dictionary = app.get("last_game_result")
		if not bool(current_result.get("ok", false)):
			rows.append(_blackjack_boundary(app, "first-rejection-stop", before_rng))
			count_rows.append(_blackjack_count_snapshot(app, "prior-hand-first-rejection-stop"))
			facts["fixture_limit"] = "Prior Blackjack returned its first rejection; no gameplay input repeated"
			return _check(false, "Prior Blackjack must retain an accepted action state before further input")
		if not (ledger.get("pending_delivery", {}) as Dictionary).is_empty():
			rows.append(_blackjack_boundary(app, "pending-stop", before_rng))
			count_rows.append(_blackjack_count_snapshot(app, "prior-hand-pending-stop"))
			facts["fixture_limit"] = "Prior Blackjack left pending; no Retry/Cancel or repeated financial input"
			return _check(false, "Prior Blackjack must not leave pending authority before Roulette")
		var elapsed_msec := Time.get_ticks_msec() - wait_started_msec
		if not recorded_one_second and elapsed_msec >= 1000:
			recorded_one_second = true
			count_rows.append(_blackjack_count_snapshot(app, "prior-hand-after-one-second"))
		if not recorded_five_seconds and elapsed_msec >= 5000:
			recorded_five_seconds = true
			count_rows.append(_blackjack_count_snapshot(app, "prior-hand-after-five-seconds"))
		var refresh_pending := bool(app.get("deferred_embedded_refresh_pending"))
		if not recorded_first_clear and not refresh_pending:
			recorded_first_clear = true
			count_rows.append(_blackjack_count_snapshot(app, "prior-hand-first-deferred-clear"))
		if int(table.get("hands_played", 0)) == 1 and not refresh_pending:
			settled = true
			break
		var canvas: Control = app.get("game_surface_canvas")
		var surface: Dictionary = canvas.call("realtime_surface_state")
		# Match the actual native Stand button. The retained ritual projection is
		# diagnostic only; its initial-deal phase need not tick with the canvas clock.
		if not stood and not refresh_pending and bool(surface.get("can_stand", false)) and not bool(canvas.call("surface_animation_active", "blackjack_deal")):
			stood = true
			facts["prior_blackjack_dispatch_counts"] = {"deal": 1, "stand": 1}
			var game: GameModule = app.get("current_game")
			var session: Dictionary = ledger.get("session", {})
			var complete_before := bool(game.call("_all_hands_complete", session))
			var result_before := _result_summary(app)
			app.call("_on_game_surface_action", "blackjack_stand", 0, false)
			rows.append(_blackjack_boundary(app, "single-stand-immediate", before_rng))
			count_rows.append(_blackjack_count_snapshot(app, "prior-hand-single-stand-immediate"))
			var stood_result: Dictionary = app.get("last_game_result")
			var stood_table: Dictionary = run.current_environment.get("game_states", {}).get("blackjack", {})
			var stood_ledger: Dictionary = stood_table.get(Authority.LEDGER_KEY, {})
			var complete_after := bool(game.call("_all_hands_complete", stood_ledger.get("session", {})))
			var result_changed := _result_summary(app) != result_before
			var returned_rejection := result_changed and not bool(stood_result.get("ok", false))
			var pending_after := not (stood_ledger.get("pending_delivery", {}) as Dictionary).is_empty()
			var fresh_committed_result := result_changed and bool(stood_result.get("ok", false)) and bool(stood_result.get(Authority.HOST_COMMITTED_KEY, false)) and str(stood_result.get("action_id", "")) != "blackjack_place_bet"
			var phase_progressed := not complete_before and complete_after
			facts["prior_blackjack_single_stand"] = {"all_hands_complete_before": complete_before, "all_hands_complete_after": complete_after, "result_changed": result_changed, "returned_rejection": returned_rejection, "pending_after": pending_after, "fresh_committed_result": fresh_committed_result, "canonical_phase_progressed": phase_progressed}
			if not _check(not returned_rejection and not pending_after and (fresh_committed_result or phase_progressed), "One native-ready Stand must produce an accepted result or canonical completed-hand progression"):
				facts["fixture_limit"] = "The single native-ready Stand was rejected or made no accepted phase progression; no gameplay input repeated"
				return false
		await create_timer(0.05).timeout
	rows.append(_blackjack_boundary(app, "prior-hand-finished-or-limit", before_rng))
	count_rows.append(_blackjack_count_snapshot(app, "prior-hand-settled" if settled else "prior-hand-time-limit"))
	if not _check(settled, "One natural Blackjack hand must settle through the native Stand gate or normal automatic terminal settlement within20s"):
		facts["fixture_limit"] = "Prior-Blackjack native readiness/settlement did not complete within20s; no repeated Deal or Stand"
		return false
	var settled_result: Dictionary = app.get("last_game_result")
	if not _check(bool(settled_result.get("ok", false)) and bool(settled_result.get(Authority.HOST_COMMITTED_KEY, false)) and not (settled_result.get("blackjack_hand_results", []) as Array).is_empty() and run.grand_casino_chips == 0 and run.bankroll >= STAKE, "Prior natural hand has a committed result and leaves an affordable cash Roulette wager"):
		return false
	var leave_cash := run.bankroll
	var leave_rng := run.rng_state
	app.call("_on_game_surface_action", "surface_back", 0)
	if not _check(str(app.get("current_screen")) == "ENVIRONMENT" and app.get("current_game") == null and run.bankroll == leave_cash and run.rng_state == leave_rng, "Normal Blackjack Leave preserves actual wallet/RNG and returns to the floor"):
		return false
	for _frame in range(12):
		await process_frame
		if int(app.get("room_publication_checked_generation")) >= int(app.get("room_publication_generation")):
			break
	var proof := run.validate_room_action_authority()
	facts["after_blackjack_floor"] = {"cash": run.bankroll, "chips": run.grand_casino_chips, "clock": run.game_clock_minutes, "heat": run.suspicion_level(), "authority_ok": proof.get("ok", false), "rng_unchanged_since_leave": run.rng_state == leave_rng, "stand_used": stood, "deal_dispatches": 1, "stand_dispatches": 1 if stood else 0, "automatic_terminal_settlement": not stood}
	return _check(bool(proof.get("ok", false)) and int(app.get("room_publication_checked_generation")) >= int(app.get("room_publication_generation")) and run.bankroll == leave_cash and run.rng_state == leave_rng, "Normal floor publication retains the accepted prior hand before Roulette entry")


func _blackjack_boundary(app: Control, label: String, before_rng: int) -> Dictionary:
	var run: RunState = app.get("run_state")
	var result: Dictionary = app.get("last_game_result")
	var table: Dictionary = run.current_environment.get("game_states", {}).get("blackjack", {})
	var ledger: Dictionary = table.get(Authority.LEDGER_KEY, {})
	var session: Dictionary = ledger.get("session", {})
	var canvas: Control = app.get("game_surface_canvas")
	var surface: Dictionary = canvas.call("realtime_surface_state")
	var projection: Dictionary = surface.get("ritual_projection", {})
	var states: Dictionary = projection.get("action_states", {})
	var readiness := {"phase": surface.get("phase", ""), "ritual_phase": projection.get("phase_id", ""), "can_deal": surface.get("can_deal", false), "can_stand": surface.get("can_stand", false), "deal_enabled": (states.get("blackjack_deal", {}) as Dictionary).get("enabled", false), "stand_enabled": (states.get("blackjack_stand", {}) as Dictionary).get("enabled", false), "public_player_hand_count": (surface.get("player_hands", []) as Array).size(), "deal_animation_active": canvas.call("surface_animation_active", "blackjack_deal"), "session_wager_debited": session.get("wager_debited", 0)}
	return {"label": label, "cash": run.bankroll, "chips": run.grand_casino_chips, "clock": run.game_clock_minutes, "rng_changed_from_before_deal": run.rng_state != before_rng, "hands_played": table.get("hands_played", 0), "pending": not (ledger.get("pending_delivery", {}) as Dictionary).is_empty(), "committed_request_count": (ledger.get("request_order", []) as Array).size(), "bankroll_delta": result.get("bankroll_delta", 0), "round_net_delta": result.get("round_net_delta", null), "wager_debited": result.get("wager_debited", 0), "public_readiness": readiness, "message": _message(app), "result": _result_summary(app)}


func _clocks(app: Control) -> Dictionary:
	var run: RunState = app.get("run_state")
	var canvas: Control = app.get("game_surface_canvas")
	var surface: Dictionary = canvas.call("realtime_surface_state")
	return {"process_frame": Engine.get_process_frames(), "run_action_simulation_msec": run.simulation_msec, "game_clock_minutes": run.game_clock_minutes, "host_simulation_msec": app.call("_environment_simulation_time_msec"), "input_time_msec": app.call("_current_game_surface_input_time_msec"), "canvas_simulation_msec": canvas.call("surface_simulation_time_msec"), "canvas_presentation_msec": canvas.call("surface_presentation_time_msec"), "rendered_raw_msec": surface.get("surface_time_msec", -1), "rendered_presentation_msec": surface.get("surface_presentation_time_msec", -1), "rendered_drunk_scaled_msec": surface.get("drunk_scaled_surface_time_msec", -1)}


func _pace(app: Control, label: String, seconds: float) -> bool:
	var before := _clocks(app)
	# Real native timers/frames only. Do not modify clocks, epochs, processing,
	# canvas scheduling or the run's action-derived simulation_msec counter.
	await create_timer(seconds).timeout
	await process_frame
	await process_frame
	var after := _clocks(app)
	var progressed := int(after.process_frame) > int(before.process_frame) and int(after.host_simulation_msec) > int(before.host_simulation_msec) and int(after.canvas_simulation_msec) > int(before.canvas_simulation_msec)
	var rows: Array = facts.get("paced_intervals", [])
	rows.append({"label": label, "requested_timer_seconds": seconds, "before": before, "after": after, "observed_progression": progressed})
	facts["paced_intervals"] = rows
	if not progressed:
		facts["fixture_limit"] = "Native process frames and host/canvas simulation clocks did not all progress during " + label
	return _check(progressed, "Paced fixture must observe real host/canvas clock progression: " + label)


func _table(run: RunState) -> Dictionary:
	return run.current_environment.get("game_states", {}).get("roulette", {})


func _session(run: RunState) -> Dictionary:
	return _table(run).get(Authority.LEDGER_KEY, {}).get("session", {})


func _has_pending(run: RunState) -> bool:
	return not (_table(run).get(Authority.LEDGER_KEY, {}).get("pending_delivery", {}) as Dictionary).is_empty()


func _pending_total(run: RunState) -> int:
	var total := 0
	for bet in _session(run).get("roulette_bets", []):
		total += int(bet.get("stake", 0))
	return total


func _message(app: Control) -> String:
	var label: Variant = app.get("message_label")
	return str(label.text) if label != null else ""


func _result_summary(app: Control) -> Dictionary:
	var result: Dictionary = app.get("last_game_result")
	return {"ok": result.get("ok", false), "game_id": result.get("game_id", ""), "action_id": result.get("action_id", ""), "error_code": result.get("error_code", ""), "message": result.get("message", ""), "diagnostic_detail": result.get("diagnostic_detail", ""), "committed": result.get(Authority.HOST_COMMITTED_KEY, false), "has_request_identity": not str(result.get(Authority.HOST_REQUEST_KEY, "")).is_empty(), "has_apply_receipt": not (result.get(Authority.HOST_APPLY_RECEIPT_KEY, {}) as Dictionary).is_empty()}


func _stake_ranges(app: Control) -> Dictionary:
	var canvas: Control = app.get("game_surface_canvas")
	var surface: Dictionary = canvas.call("realtime_surface_state")
	var rendered_view: Dictionary = surface.get("surface_action_stake_view", {})
	return {"raw_host_selected_stake": app.get("selected_stake"), "rendered_selected_stake": surface.get("selected_stake", -1), "rendered_min": surface.get("stake_min", -1), "rendered_max": surface.get("stake_max", -1), "rendered_has_valid": surface.get("has_valid_stake", false), "resolver_range": app.call("_stake_range", rendered_view), "fresh_range": app.call("_stake_range")}


func _boundary(app: Control, label: String, initial_rng: int) -> Dictionary:
	var run: RunState = app.get("run_state")
	var ledger: Dictionary = _table(run).get(Authority.LEDGER_KEY, {})
	var pending: Dictionary = ledger.get("pending_delivery", {})
	return {"label": label, "screen": app.get("current_screen"), "cash": run.bankroll, "chips": run.grand_casino_chips, "heat": run.suspicion_level(), "clock": run.game_clock_minutes, "simulation_msec": run.simulation_msec, "clock_tuple": _clocks(app), "rng_unchanged_from_prebet": run.rng_state == initial_rng, "bet_total": _pending_total(run), "armed": _session(run).get("roulette_spin_armed", false), "pending": not pending.is_empty(), "pending_action": pending.get("action_id", ""), "pending_stake": pending.get("stake", -1), "pending_boundary_ordinal": pending.get("boundary_ordinal", -1), "committed_request_count": (ledger.get("request_order", []) as Array).size(), "spin_count": _table(run).get("spin_count", 0), "selected_action_id": app.get("selected_action_id"), "message": _message(app), "blocking_modal": app.call("_blocking_modal_message"), "result": _result_summary(app)}


func _close(app: Control) -> void:
	var service: SaveService = app.get("save_service")
	if service != null:
		service.wait_for_async_save()
	app.queue_free()
	await process_frame


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
	return ok


func _finish() -> void:
	var fidelity := "Independent explicitly staged trusted generated Riverboat initial cash80/min9 fixture; actual MainScene callbacks through full Foundation dispatch. Default immediate, --paced, or --after-blackjack (one natural hand in shipped three-game set, normal Leave, actual remaining wallet/RNG retained). Paced modes measure normal native host/canvas progression. One RED bet, SPIN arm, single native CONFIRM then stop. No Practice, normal-travel claim, Day3/Heat1 reconstruction, outcome filtering, original R08 state, wheel forcing, Retry/Cancel, Save/Continue or deployed acceptance."
	if observe_blackjack:
		fidelity = "New own staged generated three-game Riverboat fixture. --observe-blackjack enters normally, selects9, dispatches one declared Deal, then records only hand/card counts, wager flags, public readiness and host/presentation guards before/immediately/after1/3/8 real process frames. No further Deal/Stand/gameplay, forced refresh, raw card/shoe/RNG/key data, prior-Blackjack/Roulette acceptance, original state or product change. Earlier diagnostic modes and their limits remain separate."
	elif prepare_web:
		fidelity = "New own explicitly staged generated Riverboat prepaid cash80/min9 floor with shipped three-game set. Official synchronous production-slot Save, own official companion saves, and native normal Continue proof only. Zero game inputs. Reports new private source paths/sizes/hashes for root staging; no asset export, fixture copy, old private fixture access, Web launch, f305 compatibility or deployed acceptance claim."
	var report := {"id": "BTH061-ROULETTE-SEALED-PENDING-001", "checks": checks, "failures": failures, "completed": completed, "facts": facts, "source_sha256": {"test": FileAccess.get_sha256("res://scripts/tests/roulette_sealed_pending_check.gd"), "foundation": FileAccess.get_sha256("res://scripts/ui/foundation_main.gd"), "roulette": FileAccess.get_sha256("res://scripts/games/roulette.gd"), "host": FileAccess.get_sha256("res://scripts/ui/sealed_action_host.gd")}, "fidelity": fidelity}
	print("ROULETTE_SEALED_PENDING_RESULT " + JSON.stringify(report))
	quit(0 if completed and failures.is_empty() else 1)
