extends "res://scripts/tests/manual_dialogue_reopen_check.gd"

const GOLD := "dialogue:linda_gold_review"
const CAGE := "dialogue:linda_cage_services"
const COUNTER := "casino_fixture:cage_counter"
const Codec := preload("res://scripts/core/run_save_codec.gd")
const Fingerprint := preload("res://scripts/core/game_ritual_runtime.gd")

# Synthetic dispatch-only controls. No eligibility, acceptance, reward or
# tutorial-campaign coverage is inferred from these stubs.
class ReviewBranchRun extends RunState:
	var tutorial := false
	func is_tutorial_run() -> bool: return tutorial
	func claim_grand_casino_players_card_tier() -> Dictionary:
		return {"ok": true, "review_required": true, "tier": "gold"}

class ReviewBranchHost extends Host:
	var observed: Array[Dictionary] = []
	func start_dialogue(id: String, context: Dictionary = {}, manual: bool = false) -> bool:
		observed.append({"id": id, "context": context.duplicate(true), "manual": manual})
		return true

func _run() -> void:
	var mode := OS.get_environment("BTH_GOLD_RETALK_MODE")
	if not _check(mode in ["retry", "cold", "first", "ineligible"] and OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-gold-retalk-"), "explicit mode and isolated private root required"): _finish(); return
	if mode != "cold": _install(OS.get_environment("BTH_CAPTURED_FIXTURE"))
	if not failures.is_empty(): _finish(); return
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "official Continue of unchanged genuine copy"): app.queue_free(); await process_frame; _finish(); return
	for frame in range(3): await process_frame
	var run: RunState = app.run_state
	var before := _guard_snapshot(run)
	facts = {"mode": mode, "Gold_acceptances": 0, "paid_inputs": 0, "fidelity": "Genuine captured Gold-ready or ineligible copy; real rendered Inspect/Card/Claim callbacks and neutral Close only. Synthetic ordinary/tutorial selector controls are reported separately."}
	_check(str(run.current_environment.get("archetype_id", "")) == RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID, "genuine Cage room")
	if mode == "ineligible":
		_check(not bool(run.demo_objective_status().get("players_card_eligible", true)), "actual cheat-closed account remains ineligible")
		app._complete_cage_players_card_review()
		_check(run.pending_talk_event(GOLD).is_empty(), "rejected backend review cannot open Gold")
		_check(_same(_guard_snapshot(run), before), "eligibility rejection preserves all causal fields")
	else:
		_check(run.bankroll == 71 and run.grand_casino_chips == 165 and run.suspicion_level() == 0, "actual71cash165chipsHeat0 Gold-ready control")
		_check(str(run.demo_objective_status().get("players_card_tier", "")) == "silver" and bool(run.demo_objective_status().get("players_card_ready_to_claim", false)), "earned Silver remains ready; no automatic Gold award")
		if mode == "cold":
			var expected_path := OS.get_environment("BTH_GOLD_RETALK_EXPECTED")
			var expected: Variant = Codec.decode(JSON.parse_string(FileAccess.get_file_as_string(expected_path))) if FileAccess.file_exists(expected_path) else null
			facts["cold_layout_roundoff_max"] = 0.0
			if _check(typeof(expected) == TYPE_DICTIONARY, "emitted previous-process expectation exists"):
				_check(_cold_same(before, expected.get("protected", {})), "fresh process preserves every causal field; only finite object-rectangle JSON roundoff<=1e-9 allowed")
		if mode != "first":
			_check(run.pending_talk_event(GOLD).is_empty() and run.neutral_talk_dismissed_at_current_boundary(GOLD), "actual persisted neutral Gold dismissal at this boundary")
			_check(not app.start_dialogue("linda_gold_review"), "automatic Gold producer still suppressed")
		_check(await _open_review(app), "deliberate rendered Claim opens separate Gold review")
		_check_review(app, before)
		var opened := run.to_save_snapshot().duplicate(true)
		app._on_talk_dock_choice_requested(CAGE, "cage_claim_card")
		_check(_same(run.to_save_snapshot(), opened), "stale completed service Claim cannot enqueue, award or duplicate review")
		app._on_talk_dock_choice_requested(GOLD, Dock.NEUTRAL_CLOSE_CHOICE_ID)
		_check(run.pending_talk_event(GOLD).is_empty(), "neutral Close removes review without accepting")
		var closed := run.to_save_snapshot().duplicate(true)
		app._on_talk_dock_choice_requested(GOLD, Dock.NEUTRAL_CLOSE_CHOICE_ID)
		_check(_same(run.to_save_snapshot(), closed), "stale repeated Close is a no-op")
		for repeat in range(3):
			app._refresh_talk_dock()
			_check(not app.start_dialogue("linda_gold_review"), "automatic review retry remains suppressed after neutral Close")
		_check(_same(_guard_snapshot(run), before), "free preview/Close has no financial, action, history, paid-authority or RNG effect")
		_check(await _open_review(app), "second deliberate warm Claim reopens review at same boundary")
		_check_review(app, before)
		app._on_talk_dock_choice_requested(GOLD, Dock.NEUTRAL_CLOSE_CHOICE_ID)
		_check(_same(_guard_snapshot(run), before), "second preview and neutral Close do not award Gold")
		if mode != "cold":
			app.save_foundation_run(); app.save_service.wait_for_async_save()
			app.save_service = SaveService.new()
			_check(app.load_foundation_run(), "official normal Save and fresh-service Continue")
			run = app.run_state
			for frame in range(3): await process_frame
			_check(_same(_guard_snapshot(run), before) and run.pending_talk_event(GOLD).is_empty(), "Continue retains closed review and all causal fields")
			_check(not app.start_dialogue("linda_gold_review"), "automatic review stays suppressed on Continue")
			_check(await _open_review(app), "deliberate Claim remains reachable after Continue")
			_check_review(app, before)
			app._on_talk_dock_choice_requested(GOLD, Dock.NEUTRAL_CLOSE_CHOICE_ID)
			_check(_same(_guard_snapshot(run), before), "restored preview/Close never replays award or financial effect")
		app.save_foundation_run(); app.save_service.wait_for_async_save()
		FileAccess.open("user://gold-retalk-expected.json", FileAccess.WRITE).store_string(JSON.stringify(Codec.encode({"protected": before})))
		_dispatch_selector_controls(app.library)
	facts["protected_after_fingerprint"] = Fingerprint.canonical_fingerprint(_guard_snapshot(run))
	app.save_service.wait_for_async_save(); app.queue_free()
	for frame in range(3): await process_frame
	_finish()

func _open_review(app) -> bool:
	if app.run_state.pending_talk_event(CAGE).is_empty():
		var object_data: Dictionary = app._interactable_object(COUNTER)
		if not _check(not object_data.is_empty(), "published real Cashout Counter exists"): return false
		var card := VBoxContainer.new(); root.add_child(card)
		app._add_context_object_actions(card, object_data)
		var inspect: Button = null
		for child in card.get_children():
			if child is Button and child.text == "Inspect": inspect = child
		if not _check(inspect != null and not inspect.disabled, "enabled rendered Counter Inspect exists"): card.queue_free(); return false
		inspect.pressed.emit()
		for frame in range(4): await process_frame
		card.queue_free()
	if str(app.run_state.pending_talk_event(CAGE).get("current_node", "")) != "card":
		if not _press(app, CAGE, "open_card"): return false
		for frame in range(4): await process_frame
	if not _press(app, CAGE, "cage_claim_card"): return false
	for frame in range(6): await process_frame
	return not app.run_state.pending_talk_event(GOLD).is_empty()

func _press(app, event_id: String, choice_id: String) -> bool:
	var buttons: Array = app.talk_dock.find_children("*", "Button", true, false).filter(func(button): return str(button.get_meta("event_id", "")) == event_id and str(button.get_meta("choice_id", "")) == choice_id)
	if not _check(buttons.size() == 1 and not buttons[0].disabled, "one enabled actual choice " + choice_id): return false
	buttons[0].pressed.emit()
	return true

func _check_review(app, before: Dictionary) -> void:
	var entry: Dictionary = app.run_state.pending_talk_event(GOLD)
	_check(not entry.is_empty() and app.run_state.pending_talk_event(CAGE).is_empty(), "review replaces services with one distinct Gold conversation")
	_check(str(entry.get("source", "")) == "event_object" and str(entry.get("context", {}).get("source", "")) == "cage_gold_review", "manual queue intent and original Gold source retained")
	_check(str(entry.get("context", {}).get("source_object_id", "")) == COUNTER, "Gold review keeps Counter identity")
	_check(_same(_guard_snapshot(app.run_state), before), "preview preserves full protected state and leaves final acceptance separate")
	_check(str(app.run_state.demo_objective_status().get("players_card_tier", "")) == "silver" and not bool(app.run_state.narrative_flags.get("demo_victory", false)), "review alone cannot grant Gold or finish run")

func _dispatch_selector_controls(content: ContentLibrary) -> void:
	for tutorial in [false, true]:
		var stub := ReviewBranchRun.new(); stub.tutorial = tutorial
		var host := ReviewBranchHost.new(); host.run_state = stub; host.library = content
		var before := stub.to_dict()
		host._complete_cage_players_card_review()
		_check(host.observed.size() == 1, "synthetic selector calls exactly one review")
		if host.observed.size() == 1:
			var call: Dictionary = host.observed[0]
			_check(call.id == ("tutorial_linda_gold_review" if tutorial else "linda_gold_review"), "synthetic ordinary/tutorial Gold ID selection unchanged")
			_check(call.manual and call.context == {"source": "cage_gold_review", "source_object_id": COUNTER}, "both computed review IDs carry explicit intent with unchanged context")
		_check(_same(stub.to_dict(), before), "dispatch-only synthetic selector performs no state mutation")
		host.free()
	facts["tutorial_scope"] = "Synthetic dispatch contract only; no genuine tutorial fixture, Bronze resume or Gold acceptance was exercised."

func _guard_snapshot(run: RunState) -> Dictionary:
	var result := super._protected(run)
	var raw := run.to_dict()
	result["unrelated_pending_events"] = raw.get("pending_triggered_events", []).filter(func(value): return str(value.get("event_id", "")) not in [GOLD, CAGE])
	var active: Dictionary = raw.get("active_triggered_event", {})
	result["unrelated_active_event"] = active if str(active.get("event_id", "")) not in [GOLD, CAGE] else {}
	var journal: Dictionary = run.narrative_flags.get("neutral_dialogue_dismissals", {}).duplicate(true)
	journal.erase(GOLD); journal.erase(CAGE); result["other_dismissals"] = journal
	return result

func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		if typeof(a) != typeof(b) and (absf(float(a)) > 9007199254740991.0 or absf(float(b)) > 9007199254740991.0): return false
		return a == b
	if typeof(a) != typeof(b): return false
	if typeof(a) == TYPE_DICTIONARY:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _same(a[key], b[key]): return false
		return true
	if typeof(a) == TYPE_ARRAY:
		if a.size() != b.size(): return false
		for index in range(a.size()):
			if not _same(a[index], b[index]): return false
		return true
	return a == b

func _cold_same(a: Variant, b: Variant, prefix: String = "") -> bool:
	if _same(a, b): return true
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _cold_same(a[key], b[key], prefix + "/" + str(key)): return false
		return true
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY and a.size() == b.size():
		for index in range(a.size()):
			if not _cold_same(a[index], b[index], prefix + "/" + str(index)): return false
		return true
	if prefix.contains("/layout/object_rects/") and prefix.get_slice("/", prefix.get_slice_count("/") - 1) in ["x", "y", "w", "h"] and typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		var delta := absf(float(a) - float(b))
		facts["cold_layout_roundoff_max"] = maxf(float(facts.get("cold_layout_roundoff_max", 0.0)), delta)
		return is_finite(float(a)) and is_finite(float(b)) and delta <= 1e-9
	return false
