extends SceneTree

# Synthetic fixture: ordinary Host startup and production room generation with
# an explicit authored scenario; normal connected lender controls thereafter.
# No captured save, browser profile or transferred authority material is used.
const Host := preload("res://scripts/ui/foundation_main.gd")
const Runtime := preload("res://scripts/core/scenario_sequence_runtime.gd")
const SLOT := "synthetic_back_alley_loan_publication"
const EXPECTED := "user://synthetic_back_alley_loan_expectation.json"
const REJECTION := "synthetic final loan publication rejected"

class Observer extends Host:
	var notices: Array[String] = []
	func _autosave_foundation_run(_status_text: String = "Autosaved.", _force: bool = false) -> bool:
		return true
	func _queue_pending_autosave(_status_text: String, _defer_frames: int, _debounce_override_msec: int = -1, _max_defer_override_msec: int = -1) -> void:
		pass
	func _show_message(text: String) -> void:
		notices.append(text)
		super._show_message(text)

# Reject only after the loan's cash is present on the detached candidate.
# Earlier turn/room proof publication keeps its production implementation.
class RejectSettledPublication extends RunState:
	func publish_room_presentation() -> Dictionary:
		if narrative_flags.has("synthetic_loan_reject_above") and bankroll > int(narrative_flags["synthetic_loan_reject_above"]):
			return {"ok": false, "errors": ["synthetic final loan publication rejected"]}
		return super.publish_room_presentation()

var app: Observer
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {}
var lender_id := ""
var scenario_id := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var mode := OS.get_environment("BTH_ALLEY_LOAN_MODE")
	var private_root := OS.get_environment("BTH_ALLEY_LOAN_ROOT").replace("\\", "/").to_lower().trim_suffix("/")
	var resident := ProjectSettings.globalize_path("user://").replace("\\", "/").to_lower()
	if not _check(mode in ["warm", "cold"] and not private_root.is_empty() and resident.begins_with(private_root + "/"), "explicit mode and disposable resident user root required"):
		_finish(); return
	if not _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(), "synthetic check excludes captured/browser inputs"):
		_finish(); return
	lender_id = OS.get_environment("BTH_ALLEY_LOAN_LENDER")
	if lender_id.is_empty(): lender_id = "the_crew"
	scenario_id = OS.get_environment("BTH_ALLEY_LOAN_SCENARIO")
	if scenario_id.is_empty(): scenario_id = "back_alley_fence_night"
	if not _check(lender_id in ["the_crew", "street_lender"] and scenario_id in ["back_alley_fence_night", "__none"], "scoped authored scenario and lender combination required"):
		_finish(); return
	root.size = Vector2i(1280, 720)
	app = Observer.new()
	app.autosave_slot_id = SLOT
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(3)
	facts["mode"] = mode
	facts["scenario"] = scenario_id
	facts["lender"] = lender_id
	facts["cold_normalizer_scope"] = "Every public guard field is retained. Debt entries use the existing RunState._normalize_debt_entries on a detached copy to match official load (including source_location_ids); cold comparison canonicalizes the complete guard through the JSON wire representation before Runtime.content_fingerprint. Exact in-process rejection still compares the complete raw to_dict bytes."
	if mode == "warm":
		if await _prepare_fixture():
			_rejection_control()
			await _accept_loan()
	else:
		await _cold()
	facts["notices"] = app.notices.duplicate()
	if app.save_service != null: app.save_service.wait_for_async_save()
	app.queue_free()
	await _frames(2)
	_finish()

func _prepare_fixture() -> bool:
	var seed_text := "SYNTHETIC-BACK-ALLEY-LOAN-" + scenario_id + "-" + lender_id
	if not _check(app.start_foundation_run(seed_text, {"modifiers": {"home_archetype_id": "back_alley"}}, false), "normal disposable Back Alley Host start"):
		return false
	var run: RunState = app.run_state
	var generated: Dictionary = {}
	for attempt in range(12):
		var rng := run.create_rng("synthetic_alley_loan_fixture:%d" % attempt)
		generated = app.generator._world_environment_data_for_node(run, run.world_map, {"id": "back_alley"}, rng, {"scenario_id": scenario_id, "depth": 0})
		if generated.get("lender_hooks", []).has(lender_id):
			run.save_rng(rng)
			facts["fixture_generation_attempt"] = attempt
			break
	if not _check(not generated.is_empty() and generated.get("lender_hooks", []).has(lender_id), "production generation selected requested authored lender"):
		return false
	# This synthetic fixture deliberately replaces the situation selected by the
	# ordinary first-room start. Keep its normal node selector record coherent
	# with the explicit production-generation request before trusted installation.
	run.remember_environment_situation_cycle("back_alley", str(generated.get("environment_situation_cycle_id", "")), "" if scenario_id == "__none" else scenario_id)
	var installed: Dictionary = app.generator._install_environment(run, generated)
	if not _check(bool(installed.get("ok", false)), "explicit authored fixture installs through production trusted boundary"):
		facts["install_errors"] = installed.get("errors", [])
		return false
	if not _check(str(run.current_environment.get("scenario_id", "")) == ("" if scenario_id == "__none" else scenario_id), "installed scenario identity matches synthetic request"):
		return false
	app._refresh_run_action_service()
	app._set_current_screen(app.SCREEN_ENVIRONMENT)
	app._refresh()
	await _frames(4)
	_room_check("before loan")
	if OS.get_environment("BTH_ALLEY_LOAN_CONSUME") == "1":
		var offer: Dictionary = app._eligible_event_option("back_alley_offer")
		facts["consume_offer_available"] = not offer.is_empty()
		if not offer.is_empty():
			if not _check(app.activate_event_choice_action("back_alley_offer", "take_cash"), "consume existing Back Alley Offer once through normal Host event action"):
				return false
			await _frames(4)
			app._finish_conclusion_animation()
			app._refresh()
			await _frames(2)
			if not _check(run.current_environment.get("resolved_event_ids", []).has("back_alley_offer"), "ordinary Back Alley Offer resolution is recorded before loan"):
				return false
			_room_check("after consumed offer")
		else:
			facts["consume_offer_scope"] = "No eligible authored offer was generated; no event membership was injected."
	facts["initial"] = _public_guard(run)
	return _check(not app._interactable_object("lender:" + lender_id).is_empty(), "published requested lender is available")

func _rejection_control() -> void:
	var rejected := RejectSettledPublication.new()
	rejected._apply_environment_turn_snapshot(app.run_state._environment_turn_snapshot(), false)
	rejected.narrative_flags["synthetic_loan_reject_above"] = rejected.bankroll
	var service := RunActionService.new()
	service.setup(app.library, rejected)
	var before := var_to_bytes(rejected.to_dict())
	var result := service.use_hook("lender", lender_id)
	_check(not bool(result.get("ok", true)) and str(result.get("message", "")) == REJECTION, "final publication failure reaches lender rejection")
	_check(var_to_bytes(rejected.to_dict()) == before, "rejected loan preserves complete serialized run state including cash/debt/clock/RNG/room aliases")
	facts["rejection"] = {"ok": result.get("ok"), "message": result.get("message"), "unchanged": var_to_bytes(rejected.to_dict()) == before}

func _accept_loan() -> void:
	var run: RunState = app.run_state
	var before := _public_guard(run)
	var quoted_terms: Dictionary = app._lender_hook(lender_id).get("loan_terms", {}).duplicate(true)
	facts["loan_quote"] = quoted_terms
	if not _check(app.select_lender_hook(lender_id) and app.confirm_selected_lender_hook(), "normal connected lender Select and Use open offer"):
		return
	await _frames(4)
	var event_id := "lender_conversation:borrow:" + lender_id
	var button := _accept_button(event_id)
	if not _check(button != null and not button.disabled and button.is_visible_in_tree(), "visible TalkDock Accept Offer exists"):
		return
	button.pressed.emit()
	await _frames(2)
	_check(_public_guard(run) == before, "arming loan confirmation changes no cash/debt/clock/RNG")
	button = _accept_button(event_id)
	if not _check(button != null and button.text.begins_with("Confirm:") and not button.disabled, "actual second confirmation is required"):
		return
	button.pressed.emit()
	await _frames(7)
	app._finish_conclusion_animation()
	app._refresh()
	await _frames(3)
	_check(run.bankroll > int(before.get("cash", 0)), "one confirmed loan publishes its cash grant")
	if lender_id == "the_crew":
		_check(run.bankroll == int(before.cash) + 70 and run.crew_delivery_obligation_count() == int(before.duties) + 2 and run.debt.size() == int(before.debt_count) and RunState._normalize_debt_entries(run.debt) == before.debt, "Crew loan grants70, adds exactly two delivery duties, and creates no cash debt")
	else:
		var street_note: Dictionary = {}
		for entry in run.debt:
			if typeof(entry) == TYPE_DICTIONARY and str(entry.get("lender_id", "")) == "street_lender":
				street_note = entry
		_check(run.bankroll == int(before.cash) + 25 and run.crew_delivery_obligation_count() == int(before.duties) and run.debt.size() == int(before.debt_count) + 1 and str(street_note.get("debt_kind", "")) == "cash" and int(street_note.get("principal", -1)) == 25 and int(quoted_terms.get("principal", -1)) == 25 and int(street_note.get("balance", -1)) == int(quoted_terms.get("repayment_total", -2)), "Street Lender grants25 and creates one cash debt at its exact quoted principal/payoff without Crew duties")
	_check(run.pending_talk_event(event_id).is_empty(), "accepted offer retires its dialogue")
	_room_check("after loan")
	var settled := _public_guard(run)
	app._on_talk_dock_choice_requested(event_id, "accept")
	_check(_public_guard(run) == settled, "stale accepted-loan callback cannot duplicate settlement")
	if not _check(SaveService.new().save_run(run, SLOT) == OK, "official SaveService persists accepted synthetic loan"):
		return
	var file := FileAccess.open(EXPECTED, FileAccess.WRITE)
	if not _check(file != null, "public cold expectation created in resident root"):
		return
	file.store_string(JSON.stringify({"guard": settled, "lender": lender_id, "scenario": scenario_id}))
	file.close()
	facts["settled"] = settled
	_exit_check("warm")

func _cold() -> void:
	if not _check(FileAccess.file_exists(EXPECTED), "warm expectation exists in same resident root"):
		return
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(EXPECTED))
	if not _check(typeof(expected) == TYPE_DICTIONARY and str(expected.get("lender", "")) == lender_id and str(expected.get("scenario", "")) == scenario_id, "cold input matches this synthetic case"):
		return
	if not _check(app.load_foundation_run(), "normal Host cold Continue loads official accepted-loan slot"):
		return
	await _frames(5)
	var restored := _public_guard(app.run_state)
	var expected_fingerprint := _guard_fingerprint(expected.get("guard", {}))
	var restored_fingerprint := _guard_fingerprint(restored)
	facts["cold_guard_fingerprints"] = {"expected": expected_fingerprint, "restored": restored_fingerprint}
	_check(restored_fingerprint == expected_fingerprint, "cold Continue preserves every normalized public guard field without loan replay")
	_room_check("cold accepted loan")
	_exit_check("cold")
	facts["restored"] = _public_guard(app.run_state)

func _room_check(label: String) -> void:
	var proof: Dictionary = app.run_state.validate_room_action_authority()
	_check(bool(proof.get("ok", false)), label + " strict room action authority")
	_check(not app.run_state.room_presentation_snapshot().is_empty(), label + " owns nonempty published presentation")
	var records := {}
	for row in app.room_catalog_snapshot(): records[str(row.get("object_id", ""))] = row
	_check(not records.is_empty(), label + " retains populated interaction catalog")
	var leave: Dictionary = records.get("travel:leave", {})
	_check(not leave.is_empty() and bool(leave.get("enabled", false)) and str(leave.get("short_description", "")) == "Open city map.", label + " Leave retains actual metadata and enabled map action")
	var orphan_ids: Array = []
	for object_data in app.environment_canvas.foundation_scene_objects:
		var id := str(object_data.get("id", ""))
		if not records.has(id): orphan_ids.append(id)
	_check(orphan_ids.is_empty(), label + " every rendered placement has a published interaction record")
	facts[label] = {"catalog_size": records.size(), "orphan_ids": orphan_ids, "proof_errors": proof.get("errors", []), "scenario": app.run_state.current_environment.get("scenario_id", "")}

func _exit_check(label: String) -> void:
	var before := _public_guard(app.run_state)
	_check(app.activate_interactable_object("travel:leave") and app.world_map_overlay != null and app.world_map_overlay.visible, label + " actual public Leave activation opens city map")
	_check(_public_guard(app.run_state) == before, label + " opening Leave map has no settlement/time/RNG effect")

func _accept_button(event_id: String) -> Button:
	var buttons: Array = app.talk_dock.find_children("*", "Button", true, false).filter(func(button): return str(button.get_meta("event_id", "")) == event_id and str(button.get_meta("choice_id", "")) == "accept")
	return buttons[0] as Button if buttons.size() == 1 else null

func _public_guard(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "heat": run.suspicion_level(), "debt_count": run.debt.size(), "debt": RunState._normalize_debt_entries(run.debt), "duties": run.crew_delivery_obligation_count(), "clock": run.game_clock_minutes, "rng_seed": str(run.rng_seed), "rng_state": str(run.rng_state), "story_log": run.story_log.duplicate(true), "story_archive": run.story_log_archive_count, "environment_id": str(run.current_environment.get("id", "")), "scenario_id": str(run.current_environment.get("scenario_id", ""))}

func _guard_fingerprint(value: Variant) -> String:
	return Runtime.content_fingerprint(JSON.parse_string(JSON.stringify(value)))

func _frames(count: int) -> void:
	for frame in range(count): await process_frame

func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition: failures.append(message)
	return condition

func _finish() -> void:
	print("BACK_ALLEY_LOAN_PUBLICATION_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "facts": facts, "scope": "Synthetic authored production-generator fixture; connected native lender controls/public Leave; no actual user save or visual Web qualification."}))
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
