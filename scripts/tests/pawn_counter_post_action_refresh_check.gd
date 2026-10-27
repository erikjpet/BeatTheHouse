extends SceneTree

# Requires a private, byte-for-byte QA H06 save bundle supplied out of tree.
# The optional nonclosing case explicitly changes only its disposable clock.
const Host := preload("res://scripts/ui/foundation_main.gd")
const ITEM := "payout_pamphlet"
const LENDER := "sals_pawn_counter"
var failures: Array[String] = []
var checks := 0
var facts: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var private_paths_ready := true
	for key in ["BTH_DISTRIBUTION_DATA_ROOT", "BTH_META_COLLECTION_PATH", "BTH_PROFILE_INVENTORY_PATH", "BTH_USER_SETTINGS_PATH", "BTH_TARGET_OUTPUT"]:
		if OS.get_environment(key).is_empty():
			private_paths_ready = false
	if not _check(private_paths_ready, "private diagnostic persistence and output roots are required") or not _install_bundle():
		_finish()
		return
	var nonclosing := OS.get_environment("BTH_PAWN_NONCLOSING") == "1"
	facts["case"] = "synthetic nonclosing variation of copied H06" if nonclosing else "unaltered copied H06 closing boundary"
	root.size = Vector2i(1280, 720)
	var app := Host.new()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for _frame in range(3):
		await process_frame
	app.autosave_slot_id = "foundation_ui_autosave"
	if not _check(app.load_foundation_run(), "official host Continue loads copied H06"):
		app.queue_free()
		_finish()
		return
	for _frame in range(3):
		await process_frame
	if nonclosing:
		app.run_state.game_clock_minutes = (app.run_state.game_day() - 1) * 1440 + 720
		app.run_state.clear_closing_time_state()
		app._refresh()
	var before := _finance(app.run_state)
	facts["before"] = before
	_check(int(before.cash) == 76 and app.run_state.inventory.has(ITEM), "copied checkpoint retains cash76 and its one original pamphlet")
	_check(app.activate_interactable_object("staff:pawn_counter_sal"), "normal Sal activation opens Pawn Counter")
	for _frame in range(2):
		await process_frame
	var screen: Variant = app.run_inventory_screen
	if not _check(screen != null and screen.is_open(), "counter is actually visible"):
		app.queue_free()
		_finish()
		return
	screen.select_item(ITEM, "carried")
	_check(screen._summary_label.text.contains("Cash $76"), "pre-pawn rendered cash is76")
	_check(_button(screen, "Pawn for $14") != null, "original quote exposes the normal Pawn14 button")
	# Cancel/close must leave both accounting and the original offer intact.
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	screen._unhandled_input(cancel)
	await process_frame
	_check(not screen.is_open() and _equal(_finance(app.run_state), before), "cancel before Pawn changes no financial state")
	_check(app.open_pawn_counter(LENDER), "counter reopens normally after cancel")
	screen.select_item(ITEM, "carried")
	var pawn := _button(screen, "Pawn for $14")
	if not _check(pawn != null and not pawn.disabled, "normal Pawn14 button remains enabled before one sale"):
		app.queue_free()
		_finish()
		return
	pawn.pressed.emit()
	for _frame in range(3):
		await process_frame
	var after := _finance(app.run_state)
	facts["after_one_pawn"] = after
	facts["rendered_after_one_pawn"] = _rendered(screen)
	_check(int(after.cash) == 90 and not app.run_state.inventory.has(ITEM), "one Pawn pays14 and removes collateral once")
	var tickets := app.run_state.pawn_tickets_for_lender(LENDER)
	_check(tickets.size() == 1 and int(tickets[0].get("payoff_amount", -1)) == 18 and app.run_state.debt.size() == 1 and int(app.run_state.debt[0].get("balance", -1)) == 18, "one debt18 ticket replaces the carried item")
	_check(int(after.receipts) == int(before.receipts) + 1, "one accepted pawn produces exactly one lender receipt")
	_check(screen.is_open() and screen._summary_label.text.contains("Cash $90"), "actual open counter refreshes its rendered cash to90")
	_check(_carried_count(screen._model) == 0 and _ticket_count(screen._model) == 1, "actual retained model replaces carried item with its ticket")
	_check(_button(screen, "Pawn for $14") == null, "already-pawned item has no stale Pawn14 button")
	if not nonclosing:
		_check(app.run_state.closing_time_forced_travel_required(), "actual pawn consumes the preserved final closing grace action")
	# A queued old control callback must still be rejected by unchanged authority.
	screen.pawn_requested.emit(LENDER, ITEM)
	screen.pawn_requested.emit(LENDER, ITEM)
	for _frame in range(2):
		await process_frame
	_check(_equal(_finance(app.run_state), after), "two stale/repeated pawn signals cannot pay or consume another turn/RNG")
	screen._close_button.pressed.emit()
	await process_frame
	_check(not screen.is_open() and _equal(_finance(app.run_state), after), "Close after Pawn has no accounting side effects")
	var reopened := app.open_pawn_counter(LENDER)
	if nonclosing:
		_check(reopened and screen.is_open() and screen._summary_label.text.contains("Cash $90"), "ordinary open shop reopens with current cash")
		_check(_carried_count(screen._model) == 0 and _ticket_count(screen._model) == 1 and _button(screen, "Pawn for $14") == null, "ordinary reopen exposes only the current ticket")
		screen._unhandled_input(cancel)
		await process_frame
	else:
		_check(not reopened and not screen.is_open(), "closing warning prevents fresh reopening without resurrecting stale actions")
	_check(_equal(_finance(app.run_state), after), "reopen/cancel attempts leave the single pawn transaction intact")
	app.save_service.wait_for_async_save()
	_check(app.save_service.save_run(app.run_state, "pawn_post") == OK, "post-Pawn state saves through normal SaveService")
	app.save_service = SaveService.new()
	app.autosave_slot_id = "pawn_post"
	_check(app.load_foundation_run(), "fresh SaveService and normal host Continue restore post-Pawn state")
	for _frame in range(3):
		await process_frame
	facts["after_cold_restore"] = _finance(app.run_state)
	_check(_equal(_finance(app.run_state), after), "cold restore preserves cash/debt/collateral/receipt/RNG exactly")
	var cold_opened := app.open_pawn_counter(LENDER)
	if nonclosing:
		_check(cold_opened and screen._summary_label.text.contains("Cash $90") and _carried_count(screen._model) == 0 and _ticket_count(screen._model) == 1, "cold open shows current cash and one ticket")
		screen._close_button.pressed.emit()
	else:
		_check(not cold_opened and not screen.is_open(), "cold closed-shop Continue retains the closing restriction")
	_check(_equal(_finance(app.run_state), after), "cold inspection cannot replay the pawn")
	app.save_service.wait_for_async_save()
	app.queue_free()
	await process_frame
	_finish()


func _install_bundle() -> bool:
	var bundle := OS.get_environment("BTH_PAWN_CAPTURE_BUNDLE")
	if bundle.is_empty() or not FileAccess.file_exists(bundle.path_join("foundation_ui_autosave.json")):
		return _check(false, "provide a preserved H06 bundle in BTH_PAWN_CAPTURE_BUNDLE")
	var save := SaveService.new()
	var save_dir := ProjectSettings.globalize_path(save.save_dir())
	var user_dir := ProjectSettings.globalize_path("user://")
	DirAccess.make_dir_recursive_absolute(save_dir)
	DirAccess.make_dir_recursive_absolute(user_dir)
	for name in ["foundation_ui_autosave.json", "foundation_ui_autosave.json.bak"]:
		if not _check(not FileAccess.file_exists(save_dir.path_join(name)) and DirAccess.copy_absolute(bundle.path_join(name), save_dir.path_join(name)) == OK, "install unchanged private " + name):
			return false
	if not _check(not FileAccess.file_exists(user_dir.path_join(".crew_host_authority_v1")) and DirAccess.copy_absolute(bundle.path_join(".crew_host_authority_v1"), user_dir.path_join(".crew_host_authority_v1")) == OK, "install unchanged private authority companion"):
		return false
	for pair in [["profile_inventory.json", "BTH_PROFILE_INVENTORY_PATH"], ["meta_collection.json", "BTH_META_COLLECTION_PATH"], ["settings.json", "BTH_USER_SETTINGS_PATH"]]:
		for suffix in ["", ".bak"]:
			var original := bundle.path_join(str(pair[0]) + suffix)
			if FileAccess.file_exists(original):
				if not _check(DirAccess.copy_absolute(original, OS.get_environment(pair[1]) + suffix) == OK, "install unchanged private " + str(pair[0]) + suffix):
					return false
	return true


func _button(node: Node, text: String) -> Button:
	if node is Button and node.is_visible_in_tree() and not node.is_queued_for_deletion() and node.text == text:
		return node as Button
	for child in node.get_children():
		var found := _button(child, text)
		if found != null:
			return found
	return null


func _finance(run: RunState) -> Dictionary:
	var receipts := 0
	for row in run.story_log:
		if typeof(row) == TYPE_DICTIONARY and str(row.get("type", "")) == "lender_hook" and str(row.get("id", "")) == LENDER and int(row.get("bankroll_delta", 0)) == 14:
			receipts += 1
	return {"cash": run.bankroll, "inventory": run.inventory.duplicate(true), "debt": run.debt.duplicate(true), "rng_state": run.rng_state, "receipts": receipts, "turns": run.current_environment.get("turns", 0), "clock": run.game_clock_minutes}


func _carried_count(model: Dictionary) -> int:
	var count := 0
	for row in model.get("items", []):
		if str(row.get("storage_source", "carried")) == "carried":
			count += 1
	return count


func _ticket_count(model: Dictionary) -> int:
	var count := 0
	for row in model.get("items", []):
		if str(row.get("storage_source", "")) == "pawn_ticket":
			count += 1
	return count


func _rendered(screen: Variant) -> Dictionary:
	return {"visible": screen.is_open(), "summary_label": screen._summary_label.text, "carried_rows": _carried_count(screen._model), "ticket_rows": _ticket_count(screen._model), "Pawn14_button_visible": _button(screen, "Pawn for $14") != null}


func _equal(left: Variant, right: Variant) -> bool:
	if typeof(left) in [TYPE_INT, TYPE_FLOAT] and typeof(right) in [TYPE_INT, TYPE_FLOAT]:
		return left == right
	if typeof(left) != typeof(right):
		return false
	if typeof(left) in [TYPE_ARRAY, TYPE_DICTIONARY]:
		if left.size() != right.size():
			return false
		for key in left.keys() if typeof(left) == TYPE_DICTIONARY else range(left.size()):
			if typeof(left) == TYPE_DICTIONARY and not right.has(key):
				return false
			if not _equal(left[key], right[key]):
				return false
		return true
	return left == right


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
	return ok


func _finish() -> void:
	var report := {"checks": checks, "failures": failures, "facts": facts, "fidelity": "Official host Continue of unchanged copied H06 with original companions, native Sal activation and actual enabled Pawn/Close Button signals, cancel handler and queued stale signals; fresh SaveService/host restore in the same engine process. No OS pointer or deployed Web claim. Nonclosing variation is explicitly marked."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("PAWN_COUNTER_REFRESH checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)
