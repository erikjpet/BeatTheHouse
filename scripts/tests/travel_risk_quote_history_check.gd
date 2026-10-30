extends "res://scripts/tests/scenario_venue_cycle_captured_check.gd"

# Captured Store11 -> Alley path, never a synthetic cash/risk edit. Use an
# isolated native-private-travel-risk-* data root and a disposable captured
# bundle with both save generations and their original authority companion.
# Run only in the coordinator's runtime window. "cold" runs in a new process
# against the preceding saved private root and BTH_TRAVEL_RISK_EXPECTED receipt.

func _run() -> void:
	if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").contains("native-private-travel-risk-"), "isolated travel-risk data root required"):
		_finish(); return
	var mode := OS.get_environment("BTH_TRAVEL_RISK_MODE")
	facts = {"mode": mode, "fidelity": "Captured pre-Alley Store11; normal host Continue/Map/Travel; no cash, risk, RNG or outcome edits."}
	if mode == "cold":
		var expected_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BTH_TRAVEL_RISK_EXPECTED")))
		if not _check(typeof(expected_value) == TYPE_DICTIONARY, "valid preceding travel-risk receipt required"):
			_finish(); return
		var expected: Dictionary = expected_value
		var cold_restored: RunState = SaveService.new().load_run("foundation_ui_autosave")
		if _check(cold_restored != null, "independent process normal save load"):
			facts["terminal"] = _terminal_facts(cold_restored)
			facts["cold_differences"] = _different_paths(expected.get("facts", {}).get("terminal", {}), facts.terminal)
			_check(facts.cold_differences.is_empty(), "cold Continue retains exact money/terminal/clock/RNG and one copy of each history row")
		_finish(); return
	var bundle := OS.get_environment("BTH_CAPTURED_FIXTURE")
	var original_hashes := _bundle_hashes(bundle)
	facts["input_sha256"] = original_hashes
	_install(bundle)
	if not failures.is_empty(): _finish(); return
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	# Host.new() bypasses Main.tscn's full-rect layout preset. Match the real
	# player scene before asserting global viewport bounds in this native host.
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for frame in range(3): await process_frame
	if not _check(app.load_foundation_run(), "normal host Continue from captured bundle"):
		app.queue_free(); _finish(); return
	var run: RunState = app.run_state
	if mode == "preserved_terminal":
		_check(run.is_terminal() and run.bankroll == 0 and run.run_failure_reason == "bankroll_zero", "historical terminal remains failed with zero cash")
		var original_terminal: RunState = SaveService.new().load_run("foundation_ui_autosave")
		_check(original_terminal != null and _terminal_facts(run) == _terminal_facts(original_terminal), "host Continue does not backfill old history, refund or revive the historical terminal")
	else:
		if _check(run.current_world_node_id() == "corner_store" and run.bankroll == 11 and not run.is_terminal(), "genuine active Store11 before risk"):
			var before := _terminal_facts(run)
			var choice := app._travel_choice("back_alley")
			var route: Dictionary = choice.get("route", {})
			var preview := run.travel_route_risk_preview(route)
			var natural_risk := run.travel_route_risk(route, "back_alley")
			facts["quote"] = {"fare": choice.get("cost"), "minutes": choice.get("travel_minutes"), "risk_preview": preview, "natural_risk": natural_risk}
			_check(bool(choice.get("enabled", false)) and int(choice.get("cost", -1)) == 3, "ordinary quote retains observed three-dollar fare")
			_check(int(route.get("risk_event", {}).get("chance_percent", -1)) == 35 and int(preview.get("bankroll_delta", 0)) == -8, "authored35-percent risk and eight-dollar consequence unchanged")
			_check(bool(natural_risk.get("triggered", false)), "original deterministic risk triggers without forcing a roll")
			if failures.is_empty():
				_check(app.open_world_map() and app.select_world_map_node("back_alley"), "ordinary selected map quote")
				for frame in range(3): await process_frame
				var detail := app.world_map_detail_label.text
				facts["map_detail"] = detail
				_check(detail.contains("Shortcut Shakedown") and detail.contains("%d%% chance" % int(preview.get("chance_percent", 0))) and detail.contains("-8 cash") and detail.contains("heat +4"), "visible quote publishes weather-adjusted chance, risk label and full cash/heat consequence")
				_check(detail.split("\n").size() == 4, "compact name/hours/description/fare card retains its four fields")
				_check_quote_fit(app)
				var result := app.confirm_world_map_travel()
				facts["travel_ok"] = result.get("ok", false)
				_check(bool(result.get("ok", false)), "normal map Travel commits the complete trip")
				_check(run.bankroll == 0 and run.is_terminal() and run.run_failure_reason == "bankroll_zero" and run.current_world_node_id() == "back_alley", "eleven minus three minus eight remains zero-cash terminal Alley arrival")
				var terminal := _terminal_facts(run)
				_check(int(terminal.travel_count) == int(before.travel_count) + 1 and int(terminal.risk_count) == int(before.risk_count) + 1, "exactly one final travel and one final risk row published")
				_check(int(terminal.clock) == int(before.clock) + int(choice.get("travel_minutes", 0)), "quoted travel minutes charged once")
				var travel: Dictionary = terminal.last_travel
				var risk: Dictionary = terminal.last_risk
				_check(int(travel.get("route_cost", -1)) == 3 and int(travel.get("bankroll_delta", 0)) == -11 and int(risk.get("bankroll_delta", 0)) == -8, "history separates three-dollar fare and eight-dollar risk without a second wallet charge")
				_check(int(risk.get("roll", -1)) == int(natural_risk.get("roll", -2)) and int(risk.get("chance_percent", -1)) == int(preview.get("chance_percent", -2)), "persisted risk retains original roll and weather-adjusted chance")
				var settled := run.to_dict()
				var replay := GameModule.apply_result(run, app.last_hook_result)
				_check(not bool(replay.get("ok", true)) and run.to_dict() == settled, "terminal replay rejected before money/history mutation")
				app.save_foundation_run()
				app.save_service.wait_for_async_save()
				var restored: RunState = SaveService.new().load_run("foundation_ui_autosave")
				facts["restore_differences"] = _different_paths(terminal, _terminal_facts(restored)) if restored != null else [{"missing_restore": true}]
				_check(restored != null and facts.restore_differences.is_empty(), "fresh-service Continue retains terminal accounting and exactly-once history")
				facts["terminal"] = terminal
	_check(_bundle_hashes(bundle) == original_hashes, "input save generations and authority companion remain byte-identical")
	app.save_service.wait_for_async_save()
	app.queue_free()
	await process_frame
	_finish()


func _check_quote_fit(app: Host) -> void:
	var label: Label = app.world_map_detail_label
	var popup: PanelContainer = app.world_map_detail_popup
	var button: Button = app.world_map_confirm_button
	var label_local := Rect2(Vector2.ZERO, label.size)
	var shaped_bounds := Rect2()
	var missing_character_bounds: Array = []
	var printable_count := 0
	# Query the actual wrapped/shaped text, rather than inferring fit from an
	# optional line cap or the unwrapped string's font metrics. In particular,
	# max_lines_visible=-1 must still fail if text exceeds its allocated control.
	for index in range(label.text.length()):
		if label.text.substr(index, 1).strip_edges().is_empty(): continue
		printable_count += 1
		var character_bounds := label.get_character_bounds(index)
		if not character_bounds.has_area():
			missing_character_bounds.append(index)
		else:
			shaped_bounds = shaped_bounds.merge(character_bounds) if shaped_bounds.has_area() else character_bounds
	var label_global := label.get_global_rect()
	var popup_global := popup.get_global_rect()
	var button_global := button.get_global_rect()
	var holder_global := app.world_map_holder.get_global_rect()
	var viewport := app.get_viewport().get_visible_rect()
	var all_lines := label.get_line_count()
	var visible_lines := label.get_visible_line_count()
	facts["quote_fit"] = {
		"viewport": _quote_rect(viewport), "holder": _quote_rect(holder_global),
		"popup": _quote_rect(popup_global), "label": _quote_rect(label_global),
		"shaped_local": _quote_rect(shaped_bounds), "button": _quote_rect(button_global),
		"all_lines": all_lines, "visible_lines": visible_lines,
		"max_lines_visible": label.max_lines_visible, "lines_skipped": label.lines_skipped,
		"printable_characters": printable_count, "missing_character_bounds": missing_character_bounds,
	}
	_check(label.is_visible_in_tree() and popup.is_visible_in_tree() and button.is_visible_in_tree() and not button.disabled, "quote and Travel control actually visible and enabled")
	_check(printable_count > 0 and missing_character_bounds.is_empty() and shaped_bounds.has_area(), "every printable quote character has actual shaped bounds")
	_check(all_lines > 0 and visible_lines == all_lines and label.lines_skipped == 0 and (label.visible_characters < 0 or label.visible_characters >= label.text.length()), "every wrapped quote line and character is shown regardless of line-cap setting")
	_check(label_local.has_area() and label_local.grow(1.0).encloses(shaped_bounds), "complete shaped warning/fare height and width fit the allocated label")
	_check(popup_global.has_area() and popup_global.grow(1.0).encloses(label_global) and popup_global.grow(1.0).encloses(button_global), "quote label and Travel button fit inside the actual popup")
	_check(holder_global.has_area() and holder_global.grow(1.0).encloses(popup_global) and viewport.grow(1.0).encloses(popup_global), "actual popup fits both map holder and viewport")
	_check(not label_global.intersects(button_global), "Travel button does not overlap the complete quote label")


func _quote_rect(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}


func _terminal_facts(run: RunState) -> Dictionary:
	var travel: Array = []
	var risks: Array = []
	for row in run.story_log:
		if typeof(row) != TYPE_DICTIONARY: continue
		if str(row.get("type", "")) == "travel": travel.append(row.duplicate(true))
		if str(row.get("type", "")) == "travel_risk_event": risks.append(row.duplicate(true))
	return {
		"cash": run.bankroll, "chips": run.grand_casino_chips, "Heat": run.suspicion_level(),
		"status": run.run_status, "failure": run.run_failure_reason, "node": run.current_world_node_id(),
		"clock": run.game_clock_minutes, "rng": run.rng_state,
		"travel_count": travel.size(), "risk_count": risks.size(),
		"last_travel": travel.back() if not travel.is_empty() else {},
		"last_risk": risks.back() if not risks.is_empty() else {},
	}


func _bundle_hashes(bundle: String) -> Dictionary:
	var result := {}
	for name in ["foundation_ui_autosave.json", "foundation_ui_autosave.json.bak", ".crew_host_authority_v1", "profile_inventory.json", "profile_inventory.json.bak"]:
		if FileAccess.file_exists(bundle.path_join(name)):
			result[name] = FileAccess.get_sha256(bundle.path_join(name))
	return result


func _finish() -> void:
	facts["test_sha256"] = FileAccess.get_sha256("res://scripts/tests/travel_risk_quote_history_check.gd")
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "facts": facts}, "  "))
	print("TRAVEL_RISK_QUOTE_HISTORY checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
