extends SceneTree

const PullTabsScript := preload("res://scripts/games/pull_tabs.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const FoundationActionViewModelFixtureScript := preload("res://scripts/ui/foundation_action_view_model.gd")

const MIN_INTERVAL_MSEC := 25000
const MAX_INTERVAL_MSEC := 35000
const VISIBLE_MSEC := 1100
const YELLOW := Color("#ffe45c")
const SCHEDULE_KEYS := [
	"pull_tab_glimmer_initialized",
	"pull_tab_glimmer_enabled",
	"pull_tab_glimmer_session_ordinal",
	"pull_tab_glimmer_event_ordinal",
	"pull_tab_glimmer_next_due_msec",
	"pull_tab_glimmer_hide_due_msec",
]
const FORBIDDEN_PUBLIC_FRAGMENTS := [
	"target", "fingerprint", "prize", "payout", "value", "tier", "rank", "symbol", "contents",
]


class DrawHarness:
	extends RefCounted

	var state: Dictionary = {}
	var flicker := 0.0
	var rects: Array = []
	var labels: Array = []

	func setup(surface_state: Dictionary, flicker_value: float) -> void:
		state = surface_state.duplicate(true)
		flicker = flicker_value
		rects = []
		labels = []

	func surface_begin_design_space(_size: Vector2) -> void:
		pass

	func surface_flicker() -> float:
		return flicker

	func surface_animation_active(_channel_id: String) -> bool:
		return false

	func surface_animation_active_id(_channel_id: String) -> String:
		return ""

	func surface_animation_progress(_channel_id: String) -> float:
		return 1.0

	func surface_elapsed(_channel_id: String) -> float:
		return 99.0

	func surface_region_hovered(_action: String, _index: int = -1) -> bool:
		return false

	func surface_native_action_selected(action: String) -> bool:
		return (state.get("native_selected_surface_actions", []) as Array).has(action)

	func surface_add_hit(_rect: Rect2, _action: String, _index: int = -1, _expand_touch_hit: bool = true) -> void:
		pass

	func surface_add_invisible_hit(_rect: Rect2, _action: String, _index: int = -1, _expand_touch_hit: bool = true) -> void:
		pass

	func surface_add_exact_invisible_hit(_rect: Rect2, _action: String, _index: int = -1) -> void:
		pass

	func surface_draw_ready_badge(_rect: Rect2, _label: String) -> void:
		pass

	func surface_label(text: String, position: Vector2, _font_size: int, color: Color) -> void:
		labels.append({"text": text, "position": position, "color": color})

	func surface_label_centered(text: String, rect: Rect2, _font_size: int, color: Color) -> void:
		labels.append({"text": text, "position": rect.position, "color": color})

	func draw_rect(rect: Rect2, color: Color, filled: bool = true, width: float = -1.0, _antialiased: bool = false) -> void:
		rects.append({"rect": rect, "color": color, "filled": filled, "width": width})

	func draw_circle(_position: Vector2, _radius: float, _color: Color, _filled: bool = true, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass

	func draw_line(_from: Vector2, _to: Vector2, _color: Color, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass

	func draw_polygon(_points: Array, _colors: Array, _uvs: Array = [], _texture: Texture2D = null) -> void:
		pass


var failures: Array[String] = []
var pull_tabs_definition: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	pull_tabs_definition = _load_pull_tabs_definition()
	if pull_tabs_definition.is_empty():
		failures.append("RW06_6 fixture could not load the shipped pull-tabs definition.")
		_finish()
		return
	var guard_game = PullTabsScript.new()
	guard_game.setup(pull_tabs_definition)
	if not guard_game.has_method("_pull_tab_glimmer_candidate_pool"):
		failures.append("RW06_6_PRODUCT_RED: pull-tabs has no production glimmer candidate/scheduler path.")
		_finish()
		return
	_check_schedule_selection_draw_and_integrity()
	_check_exact_candidate_pool_with_cutoff_tie()
	_check_unscaled_pause_safe_clock()
	_check_missing_init_due_auto_coexistence()
	_check_preference_preservation_after_result()
	_check_small_and_empty_candidate_sets()
	_check_private_identity_revalidation()
	_check_close_reopen_and_save_continue()
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("RW06_6_PULL_TAB_GLIMMER PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_schedule_selection_draw_and_integrity() -> void:
	var fixture := _new_fixture("PRIMARY")
	var game = fixture.get("game")
	var run = fixture.get("run")
	var environment: Dictionary = fixture.get("environment", {})
	var machine_before := JSON.stringify(_machine(environment))
	var run_before := JSON.stringify(run.to_dict())
	var rng_before := "%d:%d" % [run.rng_seed, run.rng_state]
	var now_msec := 1000
	var initialized := _initialize_scheduler(game, run, environment, now_msec, "primary")
	if initialized.is_empty():
		return
	var due_msec := int(initialized.get("pull_tab_glimmer_next_due_msec", 0))
	var early_state := _at_time(initialized, now_msec + MIN_INTERVAL_MSEC - 1)
	if bool(_projection(game.surface_state(run, environment, early_state)).get("visible", true)):
		failures.append("RW06_6 showed a pull-tab hint before 25 seconds.")
	var just_before_due := _at_time(initialized, due_msec - 1)
	if game.surface_needs_auto_tick(just_before_due, run, environment):
		failures.append("RW06_6 requested glimmer work before the sampled deadline.")
	var due_state := _at_time(initialized, due_msec)
	if not game.surface_needs_auto_tick(due_state, run, environment):
		failures.append("RW06_6 did not request work at the sampled glimmer deadline.")
	var event_command: Dictionary = game.surface_auto_action_command(due_state, run, environment, {})
	var event_state := _dict(event_command.get("ui_state", {}))
	var surface: Dictionary = game.surface_state(run, environment, event_state)
	var projection := _projection(surface)
	if not bool(event_command.get("handled", false)) or not bool(event_command.get("surface_transient", false)):
		failures.append("RW06_6 due event did not stay in the UI-local transient command seam.")
	if not bool(projection.get("visible", false)):
		failures.append("RW06_6 did not show an eligible hint by its <=35 second sampled deadline.")
	else:
		_assert_projection_in_independent_top_set(_machine(environment), projection, 16, "primary")
	_assert_public_shape(surface, event_state, "primary")
	var hide_due := int(event_state.get("pull_tab_glimmer_hide_due_msec", 0))
	if hide_due != due_msec + VISIBLE_MSEC:
		failures.append("RW06_6 hint lifetime was not the bounded 1.1 second window.")
	if not bool(_projection(game.surface_state(run, environment, _at_time(event_state, hide_due - 1))).get("visible", false)):
		failures.append("RW06_6 hint disappeared before its hide deadline.")
	if bool(_projection(game.surface_state(run, environment, _at_time(event_state, hide_due))).get("visible", true)):
		failures.append("RW06_6 hint remained public at or after its hide deadline.")
	var next_due := int(event_state.get("pull_tab_glimmer_next_due_msec", 0))
	if next_due < due_msec + MIN_INTERVAL_MSEC or next_due > due_msec + MAX_INTERVAL_MSEC:
		failures.append("RW06_6 did not independently resample the next 25-35 second interval.")
	if bool(projection.get("visible", false)):
		_check_draw_highlight(game, run, environment, event_state, surface, _machine(environment), projection)
	if JSON.stringify(_machine(environment)) != machine_before:
		failures.append("RW06_6 scheduling or drawing changed ticket generation, sleeve, prize, odds, payout, or inventory bytes.")
	if JSON.stringify(run.to_dict()) != run_before:
		failures.append("RW06_6 scheduling or drawing changed RunState/economy bytes.")
	if "%d:%d" % [run.rng_seed, run.rng_state] != rng_before:
		failures.append("RW06_6 presentation selection advanced gameplay RNG state.")


func _check_small_and_empty_candidate_sets() -> void:
	var small := _new_fixture("SMALL")
	var small_environment: Dictionary = small.get("environment", {})
	var small_machine := _machine(small_environment).duplicate(true)
	_limit_to_last_winner(small_machine)
	_store_machine(small.get("run"), small_environment, small_machine)
	var small_state := _initialize_scheduler(small.get("game"), small.get("run"), small_environment, 2000, "small")
	var small_due := int(small_state.get("pull_tab_glimmer_next_due_msec", 0))
	var small_command: Dictionary = small.get("game").surface_auto_action_command(_at_time(small_state, small_due), small.get("run"), small_environment, {})
	var small_projection := _projection(small.get("game").surface_state(small.get("run"), small_environment, _dict(small_command.get("ui_state", {}))))
	var small_top := _independent_top_candidates(_machine(small_environment), 16)
	if small_top.size() != 1 or not bool(small_projection.get("visible", false)):
		failures.append("RW06_6 did not select from all eligible tickets when fewer than 16 (one) remained.")
	else:
		_assert_projection_in_independent_top_set(_machine(small_environment), small_projection, 16, "fewer-than-16")

	var empty := _new_fixture("EMPTY")
	var empty_environment: Dictionary = empty.get("environment", {})
	var empty_machine := _machine(empty_environment).duplicate(true)
	_consume_all_sleeves(empty_machine)
	_store_machine(empty.get("run"), empty_environment, empty_machine)
	var empty_before := JSON.stringify(_machine(empty_environment))
	var empty_state := _initialize_scheduler(empty.get("game"), empty.get("run"), empty_environment, 3000, "empty")
	var empty_due := int(empty_state.get("pull_tab_glimmer_next_due_msec", 0))
	var empty_command: Dictionary = empty.get("game").surface_auto_action_command(_at_time(empty_state, empty_due), empty.get("run"), empty_environment, {})
	var empty_event_state := _dict(empty_command.get("ui_state", {}))
	var empty_projection := _projection(empty.get("game").surface_state(empty.get("run"), empty_environment, empty_event_state))
	if bool(empty_projection.get("visible", true)) or int(empty_event_state.get("pull_tab_glimmer_hide_due_msec", -1)) != 0:
		failures.append("RW06_6 empty eligible set did not remain stable and hidden.")
	if JSON.stringify(_machine(empty_environment)) != empty_before:
		failures.append("RW06_6 empty-set scheduling mutated the exhausted production sleeve fixture.")


func _check_exact_candidate_pool_with_cutoff_tie() -> void:
	for attempt in range(32):
		var fixture := _new_fixture("POOL-TIE-%02d" % attempt)
		var machine := _machine(fixture.get("environment", {}))
		var all_candidates := _independent_top_candidates(machine, 0)
		if all_candidates.size() <= 16 or int(_dict(all_candidates[15]).get("payout", -1)) != int(_dict(all_candidates[16]).get("payout", -2)):
			continue
		var expected := all_candidates.slice(0, 16)
		var production_value: Variant = fixture.get("game").call("_pull_tab_glimmer_candidate_pool", machine)
		var production: Array = production_value as Array if typeof(production_value) == TYPE_ARRAY else []
		if _candidate_pool_signature(production, true) != _candidate_pool_signature(expected, false):
			failures.append("RW06_6 production candidate pool identity/order/size diverged from the independent stable top-16 at a payout cutoff tie.")
			return
		return
	failures.append("RW06_6 could not obtain a production-generated >16-winner fixture with a payout tie across the top-16 cutoff.")


func _check_unscaled_pause_safe_clock() -> void:
	var fixture := _new_fixture("CLOCK")
	var game = fixture.get("game")
	var run = fixture.get("run")
	var environment: Dictionary = fixture.get("environment", {})
	var raw_start := 10000
	var scaled_start := 3300
	var initial_clock := _at_divergent_time({}, raw_start, scaled_start)
	var initialized_command: Dictionary = game.surface_auto_action_command(initial_clock, run, environment, {})
	var initialized := _dict(initialized_command.get("ui_state", {}))
	var due := int(initialized.get("pull_tab_glimmer_next_due_msec", 0))
	if due < raw_start + MIN_INTERVAL_MSEC or due > raw_start + MAX_INTERVAL_MSEC:
		failures.append("RW06_6 glimmer initialization used drunk-scaled time instead of raw pause-safe surface time.")
		return
	var hostile_scaled_early := _at_divergent_time(initialized, due - 1, due + 100000)
	if game.surface_needs_auto_tick(hostile_scaled_early, run, environment) or bool(_projection(game.surface_state(run, environment, hostile_scaled_early)).get("visible", true)):
		failures.append("RW06_6 glimmer became due from the divergent drunk-scaled clock before raw surface time.")
	var raw_due := _at_divergent_time(initialized, due, scaled_start)
	if not game.surface_needs_auto_tick(raw_due, run, environment):
		failures.append("RW06_6 glimmer did not become due on raw pause-safe surface time when scaled time lagged.")
		return
	var event: Dictionary = game.surface_auto_action_command(raw_due, run, environment, {})
	var event_state := _dict(event.get("ui_state", {}))
	var hide_due := int(event_state.get("pull_tab_glimmer_hide_due_msec", 0))
	var hostile_scaled_visible := _at_divergent_time(event_state, hide_due - 1, hide_due + 100000)
	if not bool(_projection(game.surface_state(run, environment, hostile_scaled_visible)).get("visible", false)):
		failures.append("RW06_6 drunk-scaled clock prematurely expired the bounded glimmer.")
	var raw_hidden := _at_divergent_time(event_state, hide_due, scaled_start)
	if bool(_projection(game.surface_state(run, environment, raw_hidden)).get("visible", true)):
		failures.append("RW06_6 glimmer hide deadline did not expire on raw pause-safe surface time.")


func _check_missing_init_due_auto_coexistence() -> void:
	var fixture := _new_fixture("AUTO-INIT")
	var game = fixture.get("game")
	var run = fixture.get("run")
	var environment: Dictionary = fixture.get("environment", {})
	var deal := _dict(_array(_machine(environment).get("deals", []))[0])
	var purchase: Dictionary = game.resolve_with_context("buy_tab", int(deal.get("price", 1)), run, environment, run.create_rng("rw06_6_auto_init_purchase"), {"pull_tab_deal_index": 0})
	game.surface_action_command("pull_tab_collect_tray", 0, false, {}, run, environment)
	if not bool(purchase.get("ok", false)):
		failures.append("RW06_6 Auto Open coexistence fixture could not purchase a real ticket.")
		return
	var due_time := 50000
	var missing_init_due_auto := _at_divergent_time({
		"pull_tab_auto_open_active": true,
		"pull_tab_auto_open_next_msec": due_time,
	}, due_time, due_time)
	var initialization: Dictionary = game.surface_auto_action_command(missing_init_due_auto, run, environment, {})
	var initialized := _dict(initialization.get("ui_state", {}))
	if (
		not bool(initialized.get("pull_tab_glimmer_initialized", false))
		or int(initialized.get("pull_tab_glimmer_event_ordinal", -1)) != 0
		or not bool(initialized.get("pull_tab_auto_open_active", false))
		or int(initialized.get("pull_tab_auto_open_next_msec", -1)) != due_time
	):
		failures.append("RW06_6 missing scheduler initialization did not run first while preserving an already-due Auto Open click.")
		return
	var auto_frame: Dictionary = game.surface_auto_action_command(initialized, run, environment, {})
	var auto_frame_state := _dict(auto_frame.get("ui_state", {}))
	if not bool(auto_frame.get("handled", false)) or int(auto_frame_state.get("pull_tab_auto_open_next_msec", 0)) <= due_time or _dict(auto_frame_state.get("pull_tab_reveals", {})).is_empty():
		failures.append("RW06_6 already-due Auto Open click did not run on the frame after glimmer initialization.")


func _check_private_identity_revalidation() -> void:
	var fixture := _new_fixture("REVALIDATE")
	var game = fixture.get("game")
	var run = fixture.get("run")
	var environment: Dictionary = fixture.get("environment", {})
	var ui_state := _initialize_scheduler(game, run, environment, 4000, "revalidation")
	var projection: Dictionary = {}
	for attempt in range(64):
		var due := int(ui_state.get("pull_tab_glimmer_next_due_msec", 0))
		var event: Dictionary = game.surface_auto_action_command(_at_time(ui_state, due), run, environment, {})
		ui_state = _dict(event.get("ui_state", {}))
		projection = _projection(game.surface_state(run, environment, ui_state))
		if bool(projection.get("visible", false)) and int(projection.get("offset", -1)) > 0:
			break
		var hide_due := int(ui_state.get("pull_tab_glimmer_hide_due_msec", 0))
		if hide_due > 0:
			ui_state = _dict(game.surface_auto_action_command(_at_time(ui_state, hide_due), run, environment, {}).get("ui_state", {}))
	if not bool(projection.get("visible", false)) or int(projection.get("offset", -1)) <= 0:
		failures.append("RW06_6 fixture could not sample a production target with a purchase ahead of it.")
		return
	var target_deal_index := int(projection.get("deal_index", -1))
	var target_offset := int(projection.get("offset", -1))
	var machine := _machine(environment)
	var deal := _dict(_array(machine.get("deals", []))[target_deal_index])
	var target_deal_id := str(deal.get("id", ""))
	var target_serial := str(deal.get("serial", ""))
	var target_number := _deal_cursor(deal) + target_offset + 1
	var target_prize_index := int(_array(deal.get("ticket_sleeve", []))[target_offset])
	var target_identity := {
		"deal_index": target_deal_index,
		"deal_id": target_deal_id,
		"serial": target_serial,
		"ticket_number": target_number,
		"prize_index": target_prize_index,
	}
	var target_key := _candidate_key(target_identity)

	var stale_environment := environment.duplicate(true)
	var stale_machine := _machine(stale_environment)
	var stale_deals := _array(stale_machine.get("deals", []))
	var stale_deal := _dict(stale_deals[target_deal_index]).duplicate(true)
	stale_deal["serial"] = "%s-STALE" % str(stale_deal.get("serial", ""))
	stale_deals[target_deal_index] = stale_deal
	stale_machine["deals"] = stale_deals
	(stale_environment.get("game_states", {}) as Dictionary)["pull_tabs"] = stale_machine
	if bool(_projection(game.surface_state(run, stale_environment, ui_state)).get("visible", true)):
		failures.append("RW06_6 accepted a stale deal serial for its private target identity.")
	if not bool(_projection(game.surface_state(run, environment, ui_state)).get("visible", false)):
		failures.append("RW06_6 stale-machine probe damaged the valid current-machine target.")

	var other_run = RunStateScript.new()
	other_run.start_new("RW06_6-OTHER-MACHINE")
	other_run.bankroll = 1000000
	var other_environment := _environment("rw06_6_other_machine")
	other_environment["game_states"] = {"pull_tabs": game.generate_environment_state(other_run, other_environment, other_run.create_rng("other_machine"))}
	if bool(_projection(game.surface_state(other_run, other_environment, ui_state)).get("visible", true)):
		failures.append("RW06_6 accepted its private target against another machine.")

	var first_price := int(deal.get("price", 1))
	game.resolve_with_context("buy_tab", first_price, run, environment, run.create_rng("glimmer_purchase_ahead_0"), {"pull_tab_deal_index": target_deal_index})
	var moved_projection := _projection(game.surface_state(run, environment, ui_state))
	if (
		not bool(moved_projection.get("visible", false))
		or int(moved_projection.get("deal_index", -1)) != target_deal_index
		or int(moved_projection.get("offset", -1)) != target_offset - 1
	):
		failures.append("RW06_6 did not move the same absolute target one visible depth after a purchase ahead.")
	else:
		var moved_deal := _dict(_array(_machine(environment).get("deals", []))[target_deal_index])
		var moved_offset := int(moved_projection.get("offset", -1))
		if _deal_cursor(moved_deal) + moved_offset + 1 != target_number or int(_array(moved_deal.get("ticket_sleeve", []))[moved_offset]) != target_prize_index:
			failures.append("RW06_6 silently retargeted a different ticket after a purchase ahead.")
	for purchase_index in range(target_offset):
		var current_deal := _dict(_array(_machine(environment).get("deals", []))[target_deal_index])
		game.resolve_with_context("buy_tab", int(current_deal.get("price", 1)), run, environment, run.create_rng("glimmer_purchase_to_target_%d" % purchase_index), {"pull_tab_deal_index": target_deal_index})
	var removed_projection := _projection(game.surface_state(run, environment, ui_state))
	if bool(removed_projection.get("visible", true)):
		failures.append("RW06_6 kept a removed/consumed target visible or silently retargeted its old offset.")
	if _production_pool_contains_key(game, _machine(environment), target_key):
		failures.append("RW06_6 production candidate pool retained the exact target after its real sleeve purchase/removal.")
	var collect: Dictionary = game.surface_action_command("pull_tab_collect_tray", 0, false, ui_state, run, environment)
	var reveal: Dictionary = game.surface_action_command("pull_tab_reveal_next", 0, false, _dict(collect.get("ui_state", {})), run, environment)
	var reveal_state := _dict(reveal.get("ui_state", {}))
	game.checkpoint_surface_ui_state(reveal_state, run, environment)
	var revealed_ticket := _find_ticket_in_collection(_array(_machine(environment).get("ticket_stack", [])), target_deal_id, target_serial, target_number)
	if revealed_ticket.is_empty() or not bool(revealed_ticket.get("fully_revealed", false)) or int(revealed_ticket.get("revealed_count", 0)) < _array(revealed_ticket.get("rows", [])).size():
		failures.append("RW06_6 real reveal lifecycle did not fully reveal the exact purchased target before exclusion was checked.")
	if _production_pool_contains_key(game, _machine(environment), target_key):
		failures.append("RW06_6 production candidate pool accepted the exact target after its real reveal completion.")
	if bool(_projection(game.surface_state(run, environment, reveal_state)).get("visible", true)):
		failures.append("RW06_6 accepted the purchased target after its real reveal path.")
	var file_command: Dictionary = game.surface_action_command("pull_tab_file_ticket", 0, false, reveal_state, run, environment)
	var file_result: Dictionary = game.resolve_with_context("sort_tab_ticket", 0, run, environment, run.create_rng("glimmer_consume_target"), _dict(file_command.get("ui_state", {})))
	var filed_machine := _machine(environment)
	var filed_ticket := _find_ticket_in_collection(_array(filed_machine.get("winner_pile", [])), target_deal_id, target_serial, target_number)
	if filed_ticket.is_empty():
		filed_ticket = _find_ticket_in_collection(_array(filed_machine.get("loser_pile", [])), target_deal_id, target_serial, target_number)
	if not bool(file_result.get("ok", false)) or filed_ticket.is_empty() or not bool(filed_ticket.get("sorted", false)) or not bool(filed_ticket.get("fully_revealed", false)):
		failures.append("RW06_6 real file/consume lifecycle did not resolve the exact revealed target into a terminal ticket pile.")
	if _production_pool_contains_key(game, filed_machine, target_key):
		failures.append("RW06_6 production candidate pool accepted the exact target after terminal file/consume.")
	if bool(_projection(game.surface_state(run, environment, reveal_state)).get("visible", true)):
		failures.append("RW06_6 accepted the target after its real consume/file path.")


func _check_close_reopen_and_save_continue() -> void:
	var fixture := _new_fixture("TRANSIENT")
	var game = fixture.get("game")
	var run = fixture.get("run")
	var environment: Dictionary = fixture.get("environment", {})
	var state := _initialize_scheduler(game, run, environment, 5000, "transient")
	var due := int(state.get("pull_tab_glimmer_next_due_msec", 0))
	var event: Dictionary = game.surface_auto_action_command(_at_time(state, due), run, environment, {})
	var event_state := _dict(event.get("ui_state", {}))
	if not bool(_projection(game.surface_state(run, environment, event_state)).get("visible", false)):
		failures.append("RW06_6 transient fixture did not produce an active hint before close/save checks.")
	game.checkpoint_surface_ui_state_for_save(event_state, run, environment)
	var saved_dict: Dictionary = run.to_dict()
	var saved_text := JSON.stringify(saved_dict).to_lower()
	var forbidden_save_fragments: Array = SCHEDULE_KEYS.duplicate()
	forbidden_save_fragments.append_array([
		"pull_tab_glimmer",
		"_pull_tab_glimmer_target",
		"pull_tab_glimmer_target",
		"glimmer_target",
		"glimmer_machine_fingerprint",
		"pull_tab_glimmer_machine_fingerprint",
		"glimmer_deal_id",
		"glimmer_serial",
		"glimmer_ticket_number",
		"glimmer_prize_index",
		"glimmer_payout",
		"glimmer_tier",
		"glimmer_rank",
		"glimmer_symbols",
		"glimmer_contents",
	])
	for forbidden_save_fragment_value in forbidden_save_fragments:
		var forbidden_save_fragment := str(forbidden_save_fragment_value).to_lower()
		if forbidden_save_fragment in saved_text.to_lower():
			failures.append("RW06_6 Save/Continue serialized private glimmer data: %s." % forbidden_save_fragment)

	game.enter(run, environment)
	if bool(_projection(game.surface_state(run, environment, event_state)).get("visible", true)) or not game.surface_needs_auto_tick(event_state, run, environment):
		failures.append("RW06_6 close/reopen did not clear the private target and invalidate the old session schedule.")
	var reopened := _initialize_scheduler(game, run, environment, 90000, "reopen")
	var reopened_due := int(reopened.get("pull_tab_glimmer_next_due_msec", 0))
	if reopened_due < 90000 + MIN_INTERVAL_MSEC or reopened_due > 90000 + MAX_INTERVAL_MSEC:
		failures.append("RW06_6 reopen did not start a fresh interval from the new surface clock.")

	var restored_run = RunStateScript.new()
	restored_run.from_dict(saved_dict)
	var restored_game = PullTabsScript.new()
	restored_game.setup(pull_tabs_definition)
	restored_game.enter(restored_run, restored_run.current_environment)
	if bool(_projection(restored_game.surface_state(restored_run, restored_run.current_environment, {})).get("visible", true)):
		failures.append("RW06_6 Save/Continue restored a transient hint.")
	var restored := _initialize_scheduler(restored_game, restored_run, restored_run.current_environment, 120000, "restore")
	var restored_due := int(restored.get("pull_tab_glimmer_next_due_msec", 0))
	if restored_due < 120000 + MIN_INTERVAL_MSEC or restored_due > 120000 + MAX_INTERVAL_MSEC:
		failures.append("RW06_6 Save/Continue did not start a fresh interval from restored open time.")


func _check_draw_highlight(game, run, environment: Dictionary, ui_state: Dictionary, surface: Dictionary, machine: Dictionary, projection: Dictionary) -> void:
	var expected_rect := _expected_glow_rect(machine, projection)
	var normal_a := DrawHarness.new()
	normal_a.setup(surface, 0.07)
	var normal_b := DrawHarness.new()
	normal_b.setup(surface, 0.83)
	if not game.draw_surface(normal_a, surface, {"contract_harness": true}) or not game.draw_surface(normal_b, surface, {"contract_harness": true}):
		failures.append("RW06_6 production draw path did not render the pull-tab cabinet.")
		return
	var alpha_a := _yellow_outline_alpha(normal_a.rects, expected_rect)
	var alpha_b := _yellow_outline_alpha(normal_b.rects, expected_rect)
	if alpha_a < 0.0 or alpha_b < 0.0 or is_equal_approx(alpha_a, alpha_b):
		failures.append("RW06_6 normal-motion yellow location glimmer did not use the cabinet depth geometry and pulse.")
	var forbidden_label_position := expected_rect.position + Vector2(4, 8)
	for label_value in normal_a.labels:
		var label := _dict(label_value)
		if (label.get("position", Vector2.ZERO) as Vector2).is_equal_approx(forbidden_label_position):
			failures.append("RW06_6 location-only glimmer drew a hidden-value label.")
			break
	var reduced_ui_state := ui_state.duplicate(true)
	reduced_ui_state["reduce_motion"] = true
	var reduced_surface: Dictionary = game.surface_state(run, environment, reduced_ui_state)
	if _projection(reduced_surface) != projection or not bool(reduced_surface.get("reduce_motion", false)):
		failures.append("RW06_6 production surface rebuild lost the active location hint or reduced-motion preference.")
	var reduced_a := DrawHarness.new()
	reduced_a.setup(reduced_surface, 0.11)
	var reduced_b := DrawHarness.new()
	reduced_b.setup(reduced_surface, 1.37)
	game.draw_surface(reduced_a, reduced_surface, {"contract_harness": true})
	game.draw_surface(reduced_b, reduced_surface, {"contract_harness": true})
	var reduced_alpha_a := _yellow_outline_alpha(reduced_a.rects, expected_rect)
	var reduced_alpha_b := _yellow_outline_alpha(reduced_b.rects, expected_rect)
	if reduced_alpha_a < 0.0 or reduced_alpha_b < 0.0 or not is_equal_approx(reduced_alpha_a, reduced_alpha_b):
		failures.append("RW06_6 reduced-motion highlight pulsed, flashed, moved, or disappeared across phases.")


func _check_preference_preservation_after_result() -> void:
	var fixture := _new_fixture("PREFERENCE")
	var game = fixture.get("game")
	var run = fixture.get("run")
	var environment: Dictionary = fixture.get("environment", {})
	var state := _initialize_scheduler(game, run, environment, 6500, "preference")
	if state.is_empty():
		return
	var hostile_ui := state.duplicate(true)
	hostile_ui["pull_tab_reveals"] = {"forbidden-ticket": 3}
	hostile_ui["pull_tab_glimmer"] = {"visible": true, "deal_index": 0, "offset": 0}
	hostile_ui["pull_tab_glimmer_target"] = {"ticket_number": 7, "prize_index": 2}
	hostile_ui["pull_tab_glimmer_machine_fingerprint"] = "forbidden"
	var machine := _machine(environment)
	var first_deal := _dict(_array(machine.get("deals", []))[0])
	var result: Dictionary = game.resolve_with_context(
		"buy_tab",
		int(first_deal.get("price", 1)),
		run,
		environment,
		run.create_rng("rw06_6_preference_purchase"),
		{"pull_tab_deal_index": 0}
	)
	if not bool(result.get("ok", false)):
		failures.append("RW06_6 preference lifecycle fixture could not complete a real successful pull-tab purchase.")
		return
	var host = FoundationMainScript.new()
	host.set("FoundationActionViewModelScript", FoundationActionViewModelFixtureScript)
	host.set("current_game", game)
	host.set("run_state", run)
	var preserved: Dictionary = host.call("_preserved_game_surface_preference_state", hostile_ui)
	host.free()
	var preserved_keys := preserved.keys()
	preserved_keys.sort()
	var expected_keys: Array = SCHEDULE_KEYS.duplicate()
	expected_keys.sort()
	if preserved_keys != expected_keys:
		failures.append("RW06_6 FoundationActionViewModel did not preserve exactly the six schedule scalars after a successful purchase/result: %s." % JSON.stringify(preserved_keys))
	for key_value in SCHEDULE_KEYS:
		var key := str(key_value)
		if not preserved.has(key) or preserved.get(key) != hostile_ui.get(key):
			failures.append("RW06_6 FoundationActionViewModel changed or dropped schedule scalar %s after a successful result." % key)
	for forbidden_key in ["pull_tab_reveals", "pull_tab_glimmer", "pull_tab_glimmer_target", "pull_tab_glimmer_machine_fingerprint"]:
		if preserved.has(forbidden_key):
			failures.append("RW06_6 FoundationActionViewModel retained forbidden transient/private field %s." % forbidden_key)


func _initialize_scheduler(game, run, environment: Dictionary, now_msec: int, label: String) -> Dictionary:
	var empty_state := _at_time({}, now_msec)
	if not game.surface_auto_tick_may_be_active({}) or not game.surface_needs_auto_tick(empty_state, run, environment):
		failures.append("RW06_6 %s scheduler was not available from empty retained UI state." % label)
		return {}
	var command: Dictionary = game.surface_auto_action_command(empty_state, run, environment, {})
	var state := _dict(command.get("ui_state", {}))
	var due := int(state.get("pull_tab_glimmer_next_due_msec", 0))
	if (
		not bool(command.get("handled", false))
		or not bool(command.get("surface_transient", false))
		or not bool(state.get("pull_tab_glimmer_initialized", false))
		or not bool(state.get("pull_tab_glimmer_enabled", false))
		or due < now_msec + MIN_INTERVAL_MSEC
		or due > now_msec + MAX_INTERVAL_MSEC
		or int(state.get("pull_tab_glimmer_hide_due_msec", -1)) != 0
	):
		failures.append("RW06_6 %s scheduler did not initialize 25-35 seconds ahead." % label)
		return {}
	return state


func _assert_public_shape(surface: Dictionary, ui_state: Dictionary, label: String) -> void:
	var projection := _projection(surface)
	var projection_keys := projection.keys()
	projection_keys.sort()
	if projection_keys != ["deal_index", "offset", "visible"]:
		failures.append("RW06_6 %s public projection was not exactly {visible, deal_index, offset}." % label)
	var preference_keys := _array(surface.get("surface_ui_preference_keys", []))
	if preference_keys != SCHEDULE_KEYS:
		failures.append("RW06_6 %s preference seam did not contain exactly the six non-sensitive schedule scalars." % label)
	var ui_glimmer_keys: Array = []
	for key_value in ui_state.keys():
		var key := str(key_value)
		if key.begins_with("pull_tab_glimmer_"):
			ui_glimmer_keys.append(key)
	ui_glimmer_keys.sort()
	var expected_glimmer_keys: Array = SCHEDULE_KEYS.duplicate()
	expected_glimmer_keys.sort()
	if ui_glimmer_keys != expected_glimmer_keys:
		failures.append("RW06_6 %s UI-local state did not contain exactly the six schedule fields: %s." % [label, JSON.stringify(ui_glimmer_keys)])
	var schedule_values := {}
	for schedule_key_value in SCHEDULE_KEYS:
		var schedule_key := str(schedule_key_value)
		schedule_values[schedule_key] = ui_state.get(schedule_key)
	var expected_schedule_types := {
		"pull_tab_glimmer_initialized": TYPE_BOOL,
		"pull_tab_glimmer_enabled": TYPE_BOOL,
		"pull_tab_glimmer_session_ordinal": TYPE_INT,
		"pull_tab_glimmer_event_ordinal": TYPE_INT,
		"pull_tab_glimmer_next_due_msec": TYPE_INT,
		"pull_tab_glimmer_hide_due_msec": TYPE_INT,
	}
	for schedule_key_value in expected_schedule_types.keys():
		var schedule_key := str(schedule_key_value)
		if typeof(schedule_values.get(schedule_key)) != int(expected_schedule_types.get(schedule_key, TYPE_NIL)):
			failures.append("RW06_6 %s retained schedule value %s was not the required scalar type." % [label, schedule_key])
	var public_glimmer_text := JSON.stringify({"projection": projection, "schedule": schedule_values}).to_lower()
	for fragment in FORBIDDEN_PUBLIC_FRAGMENTS:
		if fragment in public_glimmer_text:
			failures.append("RW06_6 %s public glimmer state leaked private %s data." % [label, fragment])
			break
	if preference_keys.has("pull_tab_reveals"):
		failures.append("RW06_6 %s preference seam retained bulky reveal state." % label)


func _assert_projection_in_independent_top_set(machine: Dictionary, projection: Dictionary, limit: int, label: String) -> void:
	var candidate := _candidate_at_projection(machine, projection)
	var allowed := _independent_top_candidates(machine, limit)
	var key := _candidate_key(candidate)
	var allowed_keys: Array = []
	for allowed_value in allowed:
		allowed_keys.append(_candidate_key(_dict(allowed_value)))
	if key.is_empty() or not allowed_keys.has(key):
		failures.append("RW06_6 %s target was outside the independently derived top-%d eligible remaining winner set." % [label, limit])


func _independent_top_candidates(machine: Dictionary, limit: int) -> Array:
	var result: Array = []
	var order := 0
	var deals := _array(machine.get("deals", []))
	for deal_index in range(deals.size()):
		var deal := _dict(deals[deal_index])
		var sleeve := _array(deal.get("ticket_sleeve", []))
		var prizes := _array(deal.get("prizes", []))
		for offset in range(sleeve.size()):
			var prize_index := int(sleeve[offset])
			var payout := int(_dict(prizes[prize_index]).get("payout", 0)) if prize_index >= 0 and prize_index < prizes.size() else 0
			if payout > 0:
				result.append({
					"deal_index": deal_index,
					"deal_id": str(deal.get("id", "")),
					"serial": str(deal.get("serial", "")),
					"ticket_number": _deal_cursor(deal) + offset + 1,
					"prize_index": prize_index,
					"payout": payout,
					"order": order,
				})
			order += 1
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_payout := int(left.get("payout", 0))
		var right_payout := int(right.get("payout", 0))
		return left_payout > right_payout if left_payout != right_payout else int(left.get("order", 0)) < int(right.get("order", 0))
	)
	if limit > 0 and result.size() > limit:
		result.resize(limit)
	return result


func _candidate_pool_signature(candidates: Array, production_shape: bool) -> String:
	var result: Array = []
	for value in candidates:
		var candidate := _dict(value)
		result.append({
			"deal_index": int(candidate.get("deal_index", -1)),
			"deal_id": str(candidate.get("deal_id", "")),
			"serial": str(candidate.get("serial", "")),
			"ticket_number": int(candidate.get("ticket_number", -1)),
			"prize_index": int(candidate.get("prize_index", -1)),
			"payout": int(candidate.get("payout", 0)),
			"stable_order": int(candidate.get("stable_order" if production_shape else "order", -1)),
		})
	return JSON.stringify(result)


func _candidate_at_projection(machine: Dictionary, projection: Dictionary) -> Dictionary:
	var deal_index := int(projection.get("deal_index", -1))
	var offset := int(projection.get("offset", -1))
	var deals := _array(machine.get("deals", []))
	if deal_index < 0 or deal_index >= deals.size():
		return {}
	var deal := _dict(deals[deal_index])
	var sleeve := _array(deal.get("ticket_sleeve", []))
	var prizes := _array(deal.get("prizes", []))
	if offset < 0 or offset >= sleeve.size():
		return {}
	var prize_index := int(sleeve[offset])
	if prize_index < 0 or prize_index >= prizes.size():
		return {}
	return {
		"deal_index": deal_index,
		"deal_id": str(deal.get("id", "")),
		"serial": str(deal.get("serial", "")),
		"ticket_number": _deal_cursor(deal) + offset + 1,
		"prize_index": prize_index,
	}


func _candidate_key(candidate: Dictionary) -> String:
	if candidate.is_empty():
		return ""
	return "%d|%s|%s|%d|%d" % [
		int(candidate.get("deal_index", -1)),
		str(candidate.get("deal_id", "")),
		str(candidate.get("serial", "")),
		int(candidate.get("ticket_number", -1)),
		int(candidate.get("prize_index", -1)),
	]


func _production_pool_contains_key(game, machine: Dictionary, target_key: String) -> bool:
	var pool_value: Variant = game.call("_pull_tab_glimmer_candidate_pool", machine)
	var pool: Array = pool_value as Array if typeof(pool_value) == TYPE_ARRAY else []
	for value in pool:
		if _candidate_key(_dict(value)) == target_key:
			return true
	return false


func _find_ticket_in_collection(tickets: Array, deal_id: String, serial: String, ticket_number: int) -> Dictionary:
	for value in tickets:
		var ticket := _dict(value)
		var number := int(ticket.get("ticket_number_value", 0))
		if number <= 0:
			number = int(str(ticket.get("ticket_number", "")).replace("#", ""))
		if str(ticket.get("deal_id", "")) == deal_id and str(ticket.get("serial", "")) == serial and number == ticket_number:
			return ticket
	return {}


func _expected_glow_rect(machine: Dictionary, projection: Dictionary) -> Rect2:
	var deal_index := int(projection.get("deal_index", 0))
	var deal := _dict(_array(machine.get("deals", []))[deal_index])
	var count := maxi(1, int(deal.get("ticket_count", 150)))
	var remaining := clampi(int(deal.get("remaining", count)), 0, count)
	var stack_height := maxf(18.0 if remaining > 0 else 0.0, 134.0 * clampf(float(remaining) / float(count), 0.0, 1.0))
	var stack_rect := Rect2(Vector2(68.0 + float(deal_index) * 52.0, 240.0 - stack_height), Vector2(38.0, stack_height))
	var depth_ratio := clampf((float(int(projection.get("offset", 0))) + 0.5) / float(maxi(1, remaining)), 0.0, 1.0)
	var target_y := stack_rect.end.y - stack_rect.size.y * depth_ratio
	return Rect2(Vector2(stack_rect.position.x + 1.0, target_y - 5.0), Vector2(stack_rect.size.x - 2.0, 10.0))


func _yellow_outline_alpha(records: Array, expected_rect: Rect2) -> float:
	for value in records:
		var record := _dict(value)
		var rect: Rect2 = record.get("rect", Rect2())
		var color: Color = record.get("color", Color.TRANSPARENT)
		if rect == expected_rect and not bool(record.get("filled", true)) and is_equal_approx(float(record.get("width", 0.0)), 2.0) and is_equal_approx(color.r, YELLOW.r) and is_equal_approx(color.g, YELLOW.g) and is_equal_approx(color.b, YELLOW.b):
			return color.a
	return -1.0


func _limit_to_last_winner(machine: Dictionary) -> void:
	var deals := _array(machine.get("deals", []))
	var kept := false
	for deal_index in range(deals.size() - 1, -1, -1):
		var deal := _dict(deals[deal_index]).duplicate(true)
		var sleeve := _array(deal.get("ticket_sleeve", []))
		var prizes := _array(deal.get("prizes", []))
		var keep_from := -1
		if not kept:
			for offset in range(sleeve.size() - 1, -1, -1):
				var prize_index := int(sleeve[offset])
				if prize_index >= 0 and prize_index < prizes.size() and int(_dict(prizes[prize_index]).get("payout", 0)) > 0:
					keep_from = offset
					kept = true
					break
		if keep_from >= 0:
			deal["unit_cursor"] = _deal_cursor(deal) + keep_from
			deal["ticket_sleeve"] = sleeve.slice(keep_from)
		else:
			deal["unit_cursor"] = _deal_cursor(deal) + sleeve.size()
			deal["ticket_sleeve"] = []
		deal["remaining"] = (deal.get("ticket_sleeve", []) as Array).size()
		deals[deal_index] = deal
	machine["deals"] = deals


func _consume_all_sleeves(machine: Dictionary) -> void:
	var deals := _array(machine.get("deals", []))
	for index in range(deals.size()):
		var deal := _dict(deals[index]).duplicate(true)
		var sleeve := _array(deal.get("ticket_sleeve", []))
		deal["unit_cursor"] = _deal_cursor(deal) + sleeve.size()
		deal["ticket_sleeve"] = []
		deal["remaining"] = 0
		deals[index] = deal
	machine["deals"] = deals


func _new_fixture(label: String) -> Dictionary:
	var game = PullTabsScript.new()
	game.setup(pull_tabs_definition)
	var run = RunStateScript.new()
	run.start_new("RW06_6-%s" % label)
	run.bankroll = 1000000
	var environment := _environment("rw06_6_%s" % label.to_lower())
	var machine: Dictionary = game.generate_environment_state(run, environment, run.create_rng("rw06_6_machine_%s" % label.to_lower()))
	environment["game_states"] = {"pull_tabs": machine}
	run.set_environment(environment)
	environment = run.current_environment
	game.enter(run, environment)
	return {"game": game, "run": run, "environment": environment}


func _environment(id: String) -> Dictionary:
	return {
		"id": id,
		"display_name": "RW06_6 Pull-Tab Room",
		"archetype_id": "bar",
		"kind": "venue",
		"game_ids": ["pull_tabs"],
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 1000000},
		"security_profile": {},
	}


func _load_pull_tabs_definition() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/games/games.json"))
	for value in parsed if typeof(parsed) == TYPE_ARRAY else []:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == "pull_tabs":
			return (value as Dictionary).duplicate(true)
	return {}


func _store_machine(run, environment: Dictionary, machine: Dictionary) -> void:
	var states := _dict(environment.get("game_states", {})).duplicate(true)
	states["pull_tabs"] = machine
	environment["game_states"] = states
	run.current_environment = environment


func _machine(environment: Dictionary) -> Dictionary:
	return _dict(_dict(environment.get("game_states", {})).get("pull_tabs", {}))


func _projection(surface: Dictionary) -> Dictionary:
	return _dict(surface.get("pull_tab_glimmer", {}))


func _deal_cursor(deal: Dictionary) -> int:
	return int(deal.get("unit_cursor", int(deal.get("initial_removed_count", 0))))


func _at_time(ui_state: Dictionary, time_msec: int) -> Dictionary:
	var result := ui_state.duplicate(true)
	result["surface_time_msec"] = time_msec
	result["drunk_scaled_surface_time_msec"] = time_msec
	return result


func _at_divergent_time(ui_state: Dictionary, surface_time_msec: int, drunk_scaled_time_msec: int) -> Dictionary:
	var result := ui_state.duplicate(true)
	result["surface_time_msec"] = surface_time_msec
	result["drunk_scaled_surface_time_msec"] = drunk_scaled_time_msec
	return result


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []
