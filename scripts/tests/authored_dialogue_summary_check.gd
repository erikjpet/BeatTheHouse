extends SceneTree

const Host := preload("res://scripts/ui/foundation_main.gd")
const Dock := preload("res://scripts/ui/talk_dock.gd")

# Synthetic options isolate the shared summary renderer. The captured Silas
# branch below uses the real library, host callbacks, UI and SaveService.
class SummaryHost extends Host:
	var probe_option: Dictionary = {}
	func _dialogue_option_for_entry(entry: Dictionary) -> Dictionary:
		return probe_option.duplicate(true) if not probe_option.is_empty() else super._dialogue_option_for_entry(entry)
	func _eligible_event_option_with_context(event_id: String, context: Dictionary = {}, environment: Dictionary = {}) -> Dictionary:
		return probe_option.duplicate(true) if event_id == "summary_probe" else super._eligible_event_option_with_context(event_id, context, environment)

var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}
var protection_notes: Dictionary = {}

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	var private_root := OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT")
	if not _check(not bundle.is_empty() and private_root.contains("native-private-"), "private copied fixture and distribution root required"):
		_finish(); return
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	var user := ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(saves)
	DirAccess.make_dir_recursive_absolute(user)
	for name in ["foundation_ui_autosave.json", "foundation_ui_autosave.json.bak"]:
		_check(DirAccess.copy_absolute(bundle.path_join(name), saves.path_join(name)) == OK, "copy private save companion")
	_check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"), user.path_join(".crew_host_authority_v1")) == OK, "copy private authority")
	for pair in [["profile_inventory.json", "BTH_PROFILE_INVENTORY_PATH"], ["meta_collection.json", "BTH_META_COLLECTION_PATH"]]:
		for suffix in ["", ".bak"]:
			if FileAccess.file_exists(bundle.path_join(pair[0] + suffix)):
				_check(DirAccess.copy_absolute(bundle.path_join(pair[0] + suffix), OS.get_environment(pair[1]) + suffix) == OK, "copy private profile companion")
	root.size = Vector2i(1280, 720)
	var app := SummaryHost.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "official Continue captured K38"):
		app.queue_free(); await process_frame; _finish(); return
	var run: RunState = app.run_state
	_check(run.bankroll == 284, "actual K38 cash preserved")
	_check(run.pending_talk_event_count() == 0, "captured fixture has no pending conversation")
	var protected_before := _protected(run)
	_check(app.start_dialogue("silas_crow_numbers"), "normal start real Silas dialogue")
	var id := "dialogue:silas_crow_numbers"
	var definition: Dictionary = app.library.dialogue("silas_crow_numbers")
	var greeting := str(app._dialogue_node(definition, "greeting").get("text", ""))
	var answer := str(app._dialogue_node(definition, "bio").get("text", ""))
	_check(not str(run.pending_talk_event(id).get("speaker", {}).get("voice_line", "")).is_empty(), "actual randomized Silas voice exists")
	_check(app.talk_dock.full_body_text == greeting, "authored greeting is retained")
	app._on_talk_dock_choice_requested(id, "ask_about_silas")
	_check(str(run.pending_talk_event(id).get("current_node", "")) == "bio", "real biography response enters authored node")
	_check(app.talk_dock.full_body_text == answer and app.talk_dock.body_label.text == answer, "authored biography reaches actual body label")
	_check(app.talk_dock.option.get("choices", []).size() == 2, "biography choices retained")
	var paused := run.to_save_snapshot().duplicate(true)
	for repeat in range(3): app._refresh_talk_dock()
	_check(run.to_save_snapshot() == paused and app.talk_dock.full_body_text == answer, "repeated presentation is read-only and retains answer")
	_check(_unchanged(run, protected_before, "biography"), "free biography changes no finances, inventory, actions, history or RNG")
	app.save_foundation_run()
	_check(app.return_to_main_menu(), "normal Menu after biography Save")
	await process_frame
	app.save_service = SaveService.new()
	_check(app.load_foundation_run(), "fresh SaveService Continue biography")
	run = app.run_state
	_check(str(run.pending_talk_event(id).get("current_node", "")) == "bio" and app.talk_dock.full_body_text == answer, "restored node and authored answer retained")
	_check(_unchanged(run, protected_before, "restored_biography"), "restored biography preserves protected state")
	app._on_talk_dock_choice_requested(id, "back_to_business")
	_check(app.talk_dock.full_body_text == greeting, "adjacent Talk business returns authored greeting")
	app._on_talk_dock_choice_requested(id, "ask_about_silas")
	app._on_talk_dock_choice_requested(id, "leave_silas")
	_check(run.pending_talk_event(id).is_empty(), "authored Leave ends nested response")
	_check(_unchanged(run, protected_before, "authored_leave"), "authored free Leave has no gameplay effect")
	_check(app.start_dialogue("silas_crow_numbers"), "deliberate Talk can reopen after authored Leave")
	app._on_talk_dock_choice_requested(id, "ask_about_silas")
	app._on_talk_dock_choice_requested(id, Dock.NEUTRAL_CLOSE_CHOICE_ID)
	_check(run.pending_talk_event(id).is_empty(), "neutral Close releases nested conversation")
	var closed := run.to_save_snapshot().duplicate(true)
	app._on_talk_dock_choice_requested(id, Dock.NEUTRAL_CLOSE_CHOICE_ID)
	_check(run.to_save_snapshot() == closed and _unchanged(run, protected_before, "neutral_close"), "repeated Close has no gameplay effect")
	app.save_foundation_run()
	_check(app.return_to_main_menu(), "normal Menu after Close Save")
	await process_frame
	app.save_service = SaveService.new()
	_check(app.load_foundation_run(), "fresh SaveService Continue closed conversation")
	run = app.run_state
	_check(run.pending_talk_event(id).is_empty() and app.talk_dock.entry.is_empty(), "Close remains dismissed without reopening")
	_check(_unchanged(run, protected_before, "restored_close"), "Close cold boundary preserves money, rewards, history and RNG")
	# Reader-only synthetic coverage for the adjacent generic voice fallback,
	# explicit snapshot summaries, guides and loan obligation summaries.
	for row in [
		{"dialogue": "summary_dialogue", "summary": "Authored answer.", "expected": "Authored answer."},
		{"dialogue": "summary_dialogue", "summary": "", "expected": "Voice: \"Generic greeting.\""},
		{"dialogue": "", "summary": "Event introduction.", "expected": "Voice: \"Generic greeting.\""},
		{"dialogue": "summary_dialogue", "summary": "Authored answer.", "override": "Saved exact terms.", "expected": "Saved exact terms."},
		{"dialogue": "summary_dialogue", "summary": "Guide instruction.", "guide": true, "expected": "Guide instruction."},
		{"dialogue": "", "summary": "Loan introduction.", "obligation": "Two deliveries owed.", "expected": "Voice: \"Generic greeting.\"\nLoan introduction.\nTwo deliveries owed."},
	]:
		app.probe_option = {"display_name": "Probe", "summary": row.summary, "authored_guide_dialogue": row.get("guide", false), "choices": [{"id": "continue", "label": "Continue", "enabled": true}]}
		if row.has("obligation"): app.probe_option.choices[0]["loan_terms"] = {"summary": row.obligation}
		var speaker := {"speaking_character_name": "Voice", "voice_line": "Generic greeting."}
		var context := {"summary_override": row.get("override", "")}
		if str(row.dialogue).is_empty():
			_check(run.enqueue_triggered_event("summary_probe", "event_object", context, {"presentation": "talk", "speaker": speaker}), "enqueue adjacent event probe")
		else:
			_check(run.enqueue_dialogue(row.dialogue, "summary_probe", speaker, "node", "event_object", context), "enqueue adjacent dialogue probe")
		var before_reader := run.to_save_snapshot().duplicate(true)
		app._refresh_talk_dock()
		_check(app.talk_dock.full_body_text == str(row.expected), "shared summary policy retains response or established fallback")
		_check(run.to_save_snapshot() == before_reader, "shared summary policy is a pure reader")
		run.complete_talk_event_resolution("summary_probe")
	app.probe_option = {}
	app._refresh_talk_dock()
	facts = {"fixture": "actual unchanged K38", "cash": run.bankroll, "authored_answer": answer, "paid_choices": 0, "scope": "real authored navigation, neutral Close, official save/fresh service; synthetic adjacent renderer cases are separate"}
	facts["protected_difference_paths"] = protection_notes
	app.queue_free()
	for frame in range(3): await process_frame
	_finish()

func _protected(run: RunState) -> Dictionary:
	var snapshot := run.to_dict().duplicate(true)
	# Queue ownership is expected to change. Music transport and the saved UI
	# clock advance with normal presentation; every gameplay field stays exact.
	for key in ["pending_triggered_events", "active_triggered_event", "music_tempo_state", "surface_clock_checkpoint_msec"]:
		snapshot.erase(key)
	if snapshot.get("narrative_flags", {}) is Dictionary:
		snapshot.narrative_flags.erase("neutral_dialogue_dismissals")
	return snapshot

func _unchanged(run: RunState, before: Dictionary, label: String) -> bool:
	var after := _protected(run)
	protection_notes[label] = _difference_paths(before, after)
	return before == after

func _difference_paths(a: Variant, b: Variant, path: String = "") -> Array:
	if a == b: return []
	var paths: Array = []
	if a is Dictionary and b is Dictionary:
		var keys: Array = a.keys()
		for key in b.keys():
			if not keys.has(key): keys.append(key)
		for key in keys:
			paths.append_array(_difference_paths(a.get(key), b.get(key), path + "/" + str(key)))
	elif a is Array and b is Array and a.size() == b.size():
		for index in range(a.size()):
			paths.append_array(_difference_paths(a[index], b[index], path + "/" + str(index)))
	else: paths.append(path)
	return paths

func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok

func _finish() -> void:
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts}, "  "))
		file.close()
	print("AUTHORED_DIALOGUE_SUMMARY checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
