extends "res://scripts/tests/manual_dialogue_reopen_check.gd"

const ID := "dialogue:linda_cage_services"
const COUNTER := "casino_fixture:cage_counter"
const Codec := preload("res://scripts/core/run_save_codec.gd")
const Fingerprint := preload("res://scripts/core/game_ritual_runtime.gd")

func _run() -> void:
	var mode := OS.get_environment("BTH_CAGE_RETALK_MODE")
	if not _check(mode in ["closed", "cold", "clean", "outside"] and OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-cage-retalk-"), "explicit mode and isolated private root required"): _finish(); return
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
	facts = {"mode": mode, "paid_inputs": 0, "fidelity": "Genuine copied closed/clean checkpoints and actual rendered Inspect callback. Free dialogue navigation/Close only; no service, wager, Rourke acceptance, Card claim or entitlement use."}
	if mode == "outside":
		_check(str(run.current_environment.get("archetype_id", "")) == RunState.GRAND_CASINO_ARCHETYPE_ID, "genuine outside-Cage Main Floor control")
		_check(not app._inspect_casino_fixture({"source_id": "cage_counter", "object_id": COUNTER}), "synthetic unavailable Counter input cannot force Linda outside Cage")
		_check(_same(_guard_snapshot(run), before) and run.pending_talk_event(ID).is_empty(), "outside guard preserves state and creates no Linda dialogue")
	else:
		_check(str(run.current_environment.get("archetype_id", "")) == RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID, "genuine Cage checkpoint")
		if mode == "clean":
			_check(run.bankroll == 71 and run.grand_casino_chips == 165 and bool(run.demo_objective_status().get("players_card_eligible", false)), "clean actual eligible71cash165chips control")
			if run.pending_talk_event(ID).is_empty(): _check(app._start_linda_cage_services({"object_id": COUNTER}), "normal initial free Linda request")
			app._on_talk_dock_choice_requested(ID, Dock.NEUTRAL_CLOSE_CHOICE_ID)
		elif mode == "cold":
			var path := OS.get_environment("BTH_CAGE_RETALK_EXPECTED")
			var expected: Variant = Codec.decode(JSON.parse_string(FileAccess.get_file_as_string(path))) if FileAccess.file_exists(path) else null
			if _check(typeof(expected) == TYPE_DICTIONARY, "emitted prior-process expectation exists"):
				facts["cold_guard_differing_paths"] = _different_paths(before, expected.get("protected", {}))
				facts["cold_layout_roundoff_max"] = 0.0
				_check(_cold_same(before, expected.get("protected", {})), "fresh process preserves all causal fields exactly; only finite object-rectangle JSON roundoff up to1e-9 permitted")
		else:
			_check(run.bankroll == 71 and run.grand_casino_chips == 145 and run.suspicion_level() == 65, "actual closed71cash145chipsHeat65 checkpoint")
			_check(not bool(run.demo_objective_status().get("players_card_eligible", true)), "genuine cheat-closed account remains ineligible")
		_check(run.pending_talk_event(ID).is_empty() and run.neutral_talk_dismissed_at_current_boundary(ID), "actual same-boundary neutral dismissal persists")
		var journal: Dictionary = run.narrative_flags.get("neutral_dialogue_dismissals", {}).duplicate(true)
		_check(not app.start_dialogue("linda_cage_services"), "automatic default request remains suppressed")
		_check(run.pending_talk_event(ID).is_empty() and _same(_guard_snapshot(run), before), "automatic retry cannot enqueue or affect state")
		var queue_before := run.pending_talk_event_count()
		var object_data: Dictionary = app._interactable_object(COUNTER)
		_check(not object_data.is_empty() and str(object_data.get("source_id", "")) == "cage_counter", "published real Cashout Counter exists")
		var card := VBoxContainer.new(); root.add_child(card)
		app._add_context_object_actions(card, object_data)
		var inspect: Button = null
		for child in card.get_children():
			if child is Button and child.text == "Inspect": inspect = child
		if _check(inspect != null and not inspect.disabled, "real context-card exposes enabled Inspect"):
			inspect.pressed.emit()
			for frame in range(6): await process_frame
		var entry: Dictionary = run.pending_talk_event(ID)
		var opened := not entry.is_empty()
		_check(opened, "deliberate rendered Inspect reopens at same dismissed boundary")
		if opened:
			_check(str(entry.get("source", "")) == "event_object" and str(entry.get("context", {}).get("source", "")) == "casino_cage_counter", "manual intent and original context source both retained")
			_check(str(entry.get("context", {}).get("source_object_id", "")) == COUNTER, "original fixture identity retained")
			_check(run.narrative_flags.get("neutral_dialogue_dismissals", {}) == journal, "explicit opening does not erase automatic suppression journal")
			_check(_same(_guard_snapshot(run), before), "opening Inspect applies no service/economy/time/action/paid-history/RNG effect")
			inspect.pressed.emit()
			for frame in range(3): await process_frame
			_check(run.pending_talk_event_count() == queue_before + 1, "duplicate Inspect cannot queue a second Linda conversation")
			app._on_talk_dock_choice_requested(ID, "open_comps")
			for frame in range(3): await process_frame
			_check(str(run.pending_talk_event(ID).get("current_node", "")) == "comps", "free ordinary Comps navigation is reachable")
			var gates: Dictionary = {}
			for choice_id in ["cage_comp_drink", "cage_comp_suite"]:
				var buttons: Array = app.talk_dock.find_children("*", "Button", true, false).filter(func(button): return str(button.get_meta("choice_id", "")) == choice_id)
				if _check(buttons.size() == 1, "one actual comp control " + choice_id):
					var button: Button = buttons[0]
					gates[choice_id] = {"disabled": button.disabled, "reason": button.tooltip_text}
					_check(button.disabled == (mode != "clean"), "unchanged account gate " + choice_id)
					if mode != "clean": _check(button.tooltip_text.to_lower().contains("cheat"), "closed account displays cheat-evidence reason " + choice_id)
			facts["observed_comp_gates"] = gates
			_check(_same(_guard_snapshot(run), before), "free page navigation consumes no comp or other effect")
			app._on_talk_dock_choice_requested(ID, Dock.NEUTRAL_CLOSE_CHOICE_ID)
			_check(run.pending_talk_event(ID).is_empty(), "neutral Close releases reopened Linda")
			var closed := run.to_save_snapshot().duplicate(true)
			app._on_talk_dock_choice_requested(ID, Dock.NEUTRAL_CLOSE_CHOICE_ID)
			_check(_same(run.to_save_snapshot(), closed), "repeated stale Close is a no-op")
			for repeat in range(3):
				app._refresh_talk_dock()
				_check(not app.start_dialogue("linda_cage_services"), "same-boundary automatic refresh remains suppressed")
			_check(run.pending_talk_event(ID).is_empty() and _same(_guard_snapshot(run), before), "no automatic reopen or service replay after Close")
			_check(not run.enqueue_dialogue("linda_cage_services", ID, {}, "main", "automatic", {"source_object_id": COUNTER}), "fixture ID alone does not grant manual intent")
			if mode != "cold":
				app.save_foundation_run(); app.save_service.wait_for_async_save()
				app.save_service = SaveService.new()
				_check(app.load_foundation_run(), "normal Save and fresh-service Continue")
				run = app.run_state
				for frame in range(3): await process_frame
				_check(_same(_guard_snapshot(run), before) and run.pending_talk_event(ID).is_empty(), "Continue preserves protected state and dismissal without replay")
				_check(not app.start_dialogue("linda_cage_services"), "automatic request remains suppressed after Continue")
				_check(app.activate_interactable_object(COUNTER), "ordinary direct Counter activation deliberately reopens after Continue")
				_check(str(run.pending_talk_event(ID).get("source", "")) == "event_object", "restored direct activation retains manual intent")
				app._on_talk_dock_choice_requested(ID, Dock.NEUTRAL_CLOSE_CHOICE_ID)
				_check(_same(_guard_snapshot(run), before), "restored close never replays service/financial consequence")
				_check(app._inspect_casino_fixture({"source_id": "cage", "object_id": "casino_fixture:cage"}), "in-Cage legacy Inspect alias uses the same deliberate-input helper")
				_check(str(run.pending_talk_event(ID).get("context", {}).get("source_object_id", "")) == "casino_fixture:cage", "legacy alias retains its caller identity")
				app._on_talk_dock_choice_requested(ID, Dock.NEUTRAL_CLOSE_CHOICE_ID)
				_check(_same(_guard_snapshot(run), before), "free in-Cage alias has no travel or service consequence")
				app.save_foundation_run(); app.save_service.wait_for_async_save()
				FileAccess.open("user://cage-retalk-expected.json", FileAccess.WRITE).store_string(JSON.stringify(Codec.encode({"protected": before})))
		card.queue_free()
		if mode == "cold":
			app.save_foundation_run(); app.save_service.wait_for_async_save()
	facts["protected_after_fingerprint"] = Fingerprint.canonical_fingerprint(_guard_snapshot(run))
	app.save_service.wait_for_async_save(); app.queue_free()
	for frame in range(3): await process_frame
	_finish()


func _guard_snapshot(run: RunState) -> Dictionary:
	var result := super._protected(run)
	var raw := run.to_dict()
	result["unrelated_pending_events"] = raw.get("pending_triggered_events", []).filter(func(value): return str(value.get("event_id", "")) != ID)
	var active: Dictionary = raw.get("active_triggered_event", {})
	result["unrelated_active_event"] = active if str(active.get("event_id", "")) != ID else {}
	var journal: Dictionary = run.narrative_flags.get("neutral_dialogue_dismissals", {}).duplicate(true)
	journal.erase(ID); result["other_dismissals"] = journal
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


func _different_paths(a: Variant, b: Variant, prefix: String = "") -> Array[String]:
	var result: Array[String] = []
	if _same(a, b): return result
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		for key in a:
			if not b.has(key): result.append(prefix + "/" + str(key) + ":missing")
			else: result.append_array(_different_paths(a[key], b[key], prefix + "/" + str(key)))
		for key in b:
			if not a.has(key): result.append(prefix + "/" + str(key) + ":extra")
	elif typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY and a.size() == b.size():
		for index in range(a.size()): result.append_array(_different_paths(a[index], b[index], prefix + "/" + str(index)))
	else: result.append(prefix)
	return result


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
