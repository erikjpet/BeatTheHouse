extends SceneTree

const Host := preload("res://scripts/ui/foundation_main.gd")
const Dock := preload("res://scripts/ui/talk_dock.gd")

var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	if not _check(not bundle.is_empty() and OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-"), "private captured fixture required"):
		_finish(); return
	_install(bundle)
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "official Continue completed402 K290"):
		app.queue_free(); await process_frame; _finish(); return
	var run: RunState = app.run_state
	var id := "dialogue:silas_crow_numbers"
	_check(run.bankroll == 290 and run.suspicion_level() == 0, "actual completed402 balance and Heat")
	_check(run.pending_talk_event(id).is_empty() and run.neutral_talk_dismissed_at_current_boundary(id), "genuine saved neutral dismissal owns same action boundary")
	var before := _protected(run)
	var journal: Dictionary = run.narrative_flags.get("neutral_dialogue_dismissals", {}).duplicate(true)
	_check(not app.start_dialogue("silas_crow_numbers"), "automatic default start stays suppressed before deliberate input")
	_check(run.pending_talk_event(id).is_empty(), "automatic start creates no dialogue")
	var object_data: Dictionary = app._interactable_object("numbers:silas")
	_check(not object_data.is_empty() and str(object_data.get("object_type")) == app.CONTEXT_MODE_DIALOGUE and bool(object_data.get("enabled", false)), "actual present Silas has enabled dialogue object")
	# Exercise the same enabled button builder/callback as the mouse context card.
	var card := VBoxContainer.new()
	root.add_child(card)
	app._add_context_object_actions(card, object_data)
	var talk: Button = null
	for child in card.get_children():
		if child is Button and child.text == "Talk": talk = child
	if _check(talk != null and not talk.disabled, "real context-card builder exposes enabled Talk"):
		talk.pressed.emit()
		for frame in range(6): await process_frame
	var opened := not run.pending_talk_event(id).is_empty()
	_check(opened, "deliberate enabled Talk reopens neutral dismissal at same boundary")
	if not opened:
		facts = {"stage": "baseline manual callback rejected", "cash": run.bankroll, "gameplay_unchanged": _protected(run) == before}
		card.queue_free(); app.queue_free(); await process_frame; _finish(); return
	var entry: Dictionary = run.pending_talk_event(id)
	_check(str(entry.get("source", "")) == "event_object", "manual queue source is tagged at explicit room input boundary")
	_check(str(entry.get("context", {}).get("source", "")) == str(object_data.get("source", "dialogue")), "original context source is retained")
	_check(run.narrative_flags.get("neutral_dialogue_dismissals", {}) == journal, "manual open does not erase automatic suppression journal")
	_check(_protected(run) == before, "manual open preserves all gameplay fields and accepted Marco receipt")
	talk.pressed.emit()
	for frame in range(3): await process_frame
	_check(run.pending_talk_event_count() == 1, "duplicate manual Talk cannot enqueue second conversation")
	app._on_talk_dock_choice_requested(id, "ask_about_silas")
	_check(str(run.pending_talk_event(id).get("current_node", "")) == "bio", "reopened free biography is actionable")
	_check(app.talk_dock.full_body_text.contains("pays before asking twice"), "reopening retains authored biography fix")
	app._on_talk_dock_choice_requested(id, Dock.NEUTRAL_CLOSE_CHOICE_ID)
	_check(run.pending_talk_event(id).is_empty(), "neutral Close releases reopened dialogue")
	var closed := run.to_save_snapshot().duplicate(true)
	app._on_talk_dock_choice_requested(id, Dock.NEUTRAL_CLOSE_CHOICE_ID)
	_check(run.to_save_snapshot() == closed, "stale duplicate Close remains no-op")
	for repeat in range(3):
		app._refresh_talk_dock()
		_check(not app.start_dialogue("silas_crow_numbers"), "same-boundary automatic retry stays blocked after manual Close")
	_check(run.pending_talk_event(id).is_empty() and app.talk_dock.entry.is_empty(), "no automatic prompt loop after refresh")
	_check(_protected(run) == before, "responses and suppression consume no funds/actions/time/RNG/reward")
	# The direct object activation route shares the manual intent boundary.
	for frame in range(3): await process_frame
	_check(app.activate_interactable_object("numbers:silas"), "direct room activation can deliberately reopen")
	_check(not run.pending_talk_event(id).is_empty(), "direct activation queues one dialogue")
	app._on_talk_dock_choice_requested(id, "leave_silas")
	_check(run.pending_talk_event(id).is_empty(), "authored Leave after deliberate reopen works")
	_check(not app.start_dialogue("silas_crow_numbers"), "authored Leave does not erase prior neutral automatic suppression")
	_check(_protected(run) == before, "direct input and authored Leave preserve protected gameplay")
	app.save_foundation_run()
	_check(app.return_to_main_menu(), "normal Main Menu after saved dismissal")
	await process_frame
	app.save_service = SaveService.new()
	_check(app.load_foundation_run(), "fresh SaveService Continue same boundary")
	run = app.run_state
	_check(run.pending_talk_event(id).is_empty() and run.neutral_talk_dismissed_at_current_boundary(id), "Continue retains dismissal without automatic reopen")
	_check(not app.start_dialogue("silas_crow_numbers"), "automatic default remains suppressed after Continue")
	_check(_protected(run) == before, "Continue preserves accepted history and exact causal state")
	for frame in range(3): await process_frame
	_check(app.activate_interactable_object("numbers:silas"), "deliberate room activation reopens after Continue")
	_check(str(run.pending_talk_event(id).get("source", "")) == "event_object", "restored manual input keeps explicit source")
	app._on_talk_dock_choice_requested(id, Dock.NEUTRAL_CLOSE_CHOICE_ID)
	_check(run.pending_talk_event(id).is_empty() and _protected(run) == before, "restored manual Close stays effect-free")
	# Core guard controls remain unmodified: a different conversation can use
	# the queue, while source_object_id alone is never sufficient manual intent.
	_check(not run.enqueue_dialogue("silas_crow_numbers", id, {}, "greeting", "automatic", {"source_object_id": "numbers:silas"}), "automatic object identity is not mistaken for manual input")
	_check(run.enqueue_dialogue("chatty_clerk", "manual_reopen_other", {}, "greeting", "automatic"), "different eligible dialogue can use released queue")
	run.complete_talk_event_resolution("manual_reopen_other")
	_check(_protected(run) == before, "adjacent queue controls preserve gameplay")
	facts = {"fixture": "unchanged genuine completed402", "cash": run.bankroll, "Heat": run.suspicion_level(), "paid_inputs": 0, "automatic_journal_retained": run.neutral_talk_dismissed_at_current_boundary(id), "scope": "actual Silas context Talk callback + direct room activation, authored reply/Leave, neutral Close, official Save/fresh service; no Marco response or purchase"}
	card.queue_free(); app.queue_free()
	for frame in range(3): await process_frame
	_finish()

func _protected(run: RunState) -> Dictionary:
	var snapshot := run.to_dict().duplicate(true)
	for key in ["pending_triggered_events", "active_triggered_event", "music_tempo_state", "surface_clock_checkpoint_msec"]: snapshot.erase(key)
	snapshot.narrative_flags.erase("neutral_dialogue_dismissals")
	return snapshot

func _install(bundle: String) -> void:
	var user := ProjectSettings.globalize_path("user://")
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	DirAccess.make_dir_recursive_absolute(user); DirAccess.make_dir_recursive_absolute(saves)
	for name in ["foundation_ui_autosave.json", "foundation_ui_autosave.json.bak"]:
		_check(DirAccess.copy_absolute(bundle.path_join(name), saves.path_join(name)) == OK, "copy private save")
	_check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"), user.path_join(".crew_host_authority_v1")) == OK, "copy private authority")
	for pair in [["profile_inventory.json", "BTH_PROFILE_INVENTORY_PATH"], ["meta_collection.json", "BTH_META_COLLECTION_PATH"]]:
		for suffix in ["", ".bak"]:
			if FileAccess.file_exists(bundle.path_join(pair[0] + suffix)):
				_check(DirAccess.copy_absolute(bundle.path_join(pair[0] + suffix), OS.get_environment(pair[1]) + suffix) == OK, "copy private profile")

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok

func _finish() -> void:
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts}, "  ")); file.close()
	print("MANUAL_DIALOGUE_REOPEN checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
