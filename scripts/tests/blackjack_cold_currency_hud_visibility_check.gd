extends SceneTree

# Run against the owner's HUD-prefix candidate, with one unchanged POST-catch
# bundle per private job. This never deals, peeks, settles or changes finance.
const Host := preload("res://scripts/ui/foundation_main.gd")
var checks := 0
var failures: Array[String] = []
var facts: Array = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if not _install_bundle():
		_finish()
		return
	var reference: Variant = SaveService.new().load_run("foundation_ui_autosave")
	if not check(reference is RunState, "official private POST-catch save loads"):
		_finish()
		return
	var expected := _protected(reference)
	var peek := _peek(reference)
	var measured := GameModule.applied_currency_settlement(peek)
	var case_name := "legacy" if measured.is_empty() else "zero" if int(measured.delta) == 0 else "ten"
	var wanted := {"ten": {"cash": 78, "lost": 50, "net": -50, "marker": "-10 chips"}, "zero": {"cash": 128, "lost": 273, "net": -280, "marker": "+0 chips"}, "legacy": {"cash": 78, "lost": 80, "net": -50, "marker": "unknown"}}
	check(expected.cash == wanted[case_name].cash and expected.chips == 0 and expected.lost == wanted[case_name].lost and expected.net == wanted[case_name].net, "actual protected fixture has declared wallet/profile/net")
	check(expected.peek_count == 1, "exactly one accepted catch exists before inspection")
	if case_name != "legacy":
		check(int(measured.delta) == (-10 if case_name == "ten" else 0), "known applied amount is explicit, including zero")
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for frame in range(3): await process_frame
	app.autosave_slot_id = "foundation_ui_autosave"
	if check(app.load_foundation_run(), "normal cold Continue loads same accepted catch"):
		for frame in range(3): await process_frame
		app.set_process(false)
		check(_equal(_protected(app.run_state), expected), "Continue preserves historical finance and game-action rows")
		for small in [false, true]:
			for text_size in UserSettings.TEXT_SIZES:
				app.user_settings.play_on_small_screen = small
				app.user_settings.ui_scale = 1.0
				app.user_settings.text_size = text_size
				app.call("_apply_accessibility_settings")
				var before := var_to_bytes(app.run_state.story_log)
				var rng_before: int = app.run_state.rng_state
				var view: Dictionary = app.call("_environment_result_feedback_view")
				app.call("_refresh_environment_result_feedback")
				check(var_to_bytes(app.run_state.story_log) == before and app.run_state.rng_state == rng_before, "synchronous HUD readers preserve history and RNG")
				for frame in range(3): await process_frame
				await _visible_prefix(app, view, str(wanted[case_name].marker), case_name, text_size, small)
				check(_equal(_protected(app.run_state), expected), "display mode preserves funds/debt/profile/net/receipts")
		await _generic_controls(app)
		check(_equal(_protected(app.run_state), expected), "generic display controls cannot alter accepted history")
		app.save_service.wait_for_async_save()
		var saved: Error = app.save_service.save_run(app.run_state, "cold_hud_after_readers")
		check(saved == OK, "official private Save accepts same post-catch state")
		var restored: Variant = SaveService.new().load_run("cold_hud_after_readers") if saved == OK else null
		check(restored is RunState, "fresh service restores same receipt after display")
		if restored is RunState:
			check(_equal(_protected(restored), expected), "save/restore keeps one catch, wallet, old metrics and nominal/applied history")
			check(_equal(GameModule.applied_currency_settlement(_peek(restored)), measured), "explicit zero or absent legacy witness survives save unchanged")
		app.save_service.wait_for_async_save()
	app.queue_free()
	await process_frame
	_finish()

func _visible_prefix(app: Variant, view: Dictionary, marker: String, case_name: String, text_size: String, small: bool) -> void:
	var panel: PanelContainer = app.environment_result_panel
	var body: Label = app.environment_result_body_label
	check(bool(view.get("visible", false)) and panel.is_visible_in_tree(), "ordinary environment Result HUD is visible")
	check(panel.custom_minimum_size == Vector2(340, 72) and body.max_lines_visible == 3, "existing bounded Result geometry is retained")
	check(body.text == str(view.get("text", "")), "actual builder Label receives full projected message")
	var prefix := body.text.get_slice("\n", 0)
	check(prefix.contains(marker), "first bounded HUD section contains actual amount/units or explicit unknown")
	check(not prefix.contains("$"), "chip receipt does not claim a cash debit")
	if case_name == "legacy":
		check(prefix.contains("40 chips") and not prefix.contains("+0 chips"), "legacy nominal penalty remains separate from unknown applied loss")
	else:
		var witness := GameModule.applied_currency_settlement(view.get("result", {}))
		check(not witness.is_empty() and int(witness.delta) == (-10 if case_name == "ten" else 0), "visible result retains authoritative measured amount")
	# Shape only the leading section through an actual Label using the exact
	# allocated width/font/wrapping of the production body. If this fits before
	# the body's visible-line cap, the amount cannot be hidden after narrative.
	var prefix_label := Label.new()
	prefix_label.autowrap_mode = body.autowrap_mode
	prefix_label.add_theme_font_override("font", body.get_theme_font("font"))
	prefix_label.add_theme_font_size_override("font_size", body.get_theme_font_size("font_size"))
	prefix_label.add_theme_constant_override("line_spacing", body.get_theme_constant("line_spacing"))
	prefix_label.size = Vector2(body.size.x, body.size.y)
	prefix_label.text = prefix
	root.add_child(prefix_label)
	for frame in range(2): await process_frame
	var prefix_lines := prefix_label.get_line_count()
	check(body.size.x > 0 and prefix_lines > 0 and prefix_lines <= body.get_visible_line_count(), "all leading amount/provenance lines fit actual three-line body")
	var line_height := body.get_theme_font("font").get_height(body.get_theme_font_size("font_size"))
	var leading_height := prefix_lines * line_height + maxi(0, prefix_lines - 1) * body.get_theme_constant("line_spacing")
	check(body.global_position.y + leading_height <= panel.get_global_rect().end.y + 1.0, "leading amount stays inside the real Result panel bottom")
	for button in [app.top_menu_button, app.top_settings_button, app.top_inventory_button]:
		if button != null and button.is_visible_in_tree():
			check(not panel.get_global_rect().intersects(button.get_global_rect()), "Result box does not cover ordinary top HUD controls")
	facts.append({"case": case_name, "text_size": text_size, "small_policy": small, "full_text": body.text, "prefix": prefix, "prefix_lines": prefix_lines, "body_lines": body.get_line_count(), "visible_lines": body.get_visible_line_count(), "font_size": body.get_theme_font_size("font_size"), "panel_rect": str(panel.get_global_rect()), "body_rect": str(body.get_global_rect())})
	prefix_label.queue_free()
	await process_frame

func _generic_controls(app: Variant) -> void:
	var saved := {"game": app.last_game_result, "item": app.last_item_result, "hook": app.last_hook_result, "runtime": app.last_environment_runtime_result, "ack": app.immediate_environment_acknowledgement}
	app.last_item_result = {}; app.last_hook_result = {}; app.last_environment_runtime_result = {}; app.immediate_environment_acknowledgement = ""
	for control in [{"currency": "cash", "bankroll_delta": -7, "message": "Seven dollars spent."}, {"currency": "mixed", "bankroll_delta": -3, "chips_delta": 5, "message": "Mixed receipt."}, {"currency": "chips", "currency_delta": 20, "bankroll_delta": 0, "message": "A positive chip return."}]:
		app.last_game_result = control.duplicate(true)
		var before := var_to_bytes(app.last_game_result)
		var view: Dictionary = app.call("_environment_result_feedback_view")
		if control.currency == "chips":
			check(str(view.get("text", "")).get_slice("\n", 0).contains("+20 chips"), "ordinary positive chip result retains units and amount")
		else:
			check(str(view.get("text", "")).begins_with(control.message) and int(view.get("bankroll_delta", 0)) == int(control.bankroll_delta), "ordinary cash/mixed message and cash amount unchanged")
		check(var_to_bytes(app.last_game_result) == before, "generic reader preserves caller result dictionary")
	app.last_game_result = saved.game; app.last_item_result = saved.item; app.last_hook_result = saved.hook; app.last_environment_runtime_result = saved.runtime; app.immediate_environment_acknowledgement = saved.ack
	app.call("_refresh_environment_result_feedback")
	await process_frame

func _peek(run: RunState) -> Dictionary:
	var result := {}
	for row in run.story_log:
		if str(row.get("type", "")) == "game_action" and str(row.get("game_id", "")) == "blackjack" and str(row.get("action_id", "")) == "peek_hole_card": result = row
	return result

func _protected(run: RunState) -> Dictionary:
	var rows: Array = []
	var peek_count := 0
	for row in run.story_log:
		if str(row.get("type", "")) == "game_action": rows.append(row.duplicate(true))
		if str(row.get("game_id", "")) == "blackjack" and str(row.get("action_id", "")) == "peek_hole_card": peek_count += 1
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "lost": int(run.narrative_flags.get("profile_bankroll_lost", 0)), "net": int(run.narrative_flags.get("grand_casino_net_winnings", 0)), "debt": run.debt.duplicate(true), "game_rows": rows, "peek_count": peek_count, "inventory": run.inventory.duplicate(true), "bags": run.pending_bags.duplicate(true)}

func _install_bundle() -> bool:
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	if not check(not bundle.is_empty() and OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").is_absolute_path(), "explicit private fixture and persistence roots required"): return false
	var saves := ProjectSettings.globalize_path(SaveService.new().save_dir())
	var user_dir := ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(saves); DirAccess.make_dir_recursive_absolute(user_dir)
	for name in ["foundation_ui_autosave.json", "foundation_ui_autosave.json.bak"]:
		if FileAccess.file_exists(bundle.path_join(name)) and not check(not FileAccess.file_exists(saves.path_join(name)) and DirAccess.copy_absolute(bundle.path_join(name), saves.path_join(name)) == OK, "install private unchanged " + name): return false
	if not check(DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"), user_dir.path_join(".crew_host_authority_v1")) == OK, "install copied authority key"): return false
	for pair in [["profile_inventory.json", "BTH_PROFILE_INVENTORY_PATH"], ["meta_collection.json", "BTH_META_COLLECTION_PATH"], ["settings.json", "BTH_USER_SETTINGS_PATH"]]:
		for suffix in ["", ".bak"]:
			var original := bundle.path_join(str(pair[0]) + suffix)
			if FileAccess.file_exists(original) and not check(DirAccess.copy_absolute(original, OS.get_environment(pair[1]) + suffix) == OK, "install private companion"): return false
	return true

func _equal(left: Variant, right: Variant) -> bool:
	if typeof(left) in [TYPE_INT, TYPE_FLOAT] and typeof(right) in [TYPE_INT, TYPE_FLOAT]: return left == right
	if typeof(left) != typeof(right): return false
	if typeof(left) == TYPE_DICTIONARY:
		if left.size() != right.size(): return false
		for key in left:
			if not right.has(key) or not _equal(left[key], right[key]): return false
		return true
	if typeof(left) == TYPE_ARRAY:
		if left.size() != right.size(): return false
		for index in range(left.size()):
			if not _equal(left[index], right[index]): return false
		return true
	return left == right

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures.append(message)
	return ok

func _finish() -> void:
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty(): FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts, "scope": "Actual copied POST-catch Save/Continue and ordinary Result Label; display readers only, no financial input. Native owner evidence, not deployed browser acceptance. No blanket live-world RNG comparison."}, "\t"))
	print("BLACKJACK_COLD_CURRENCY_HUD checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
