extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const NEEDS_GAME := "That active item needs a game surface."
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _run() -> void:
	var app = MainScene.instantiate()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	root.add_child(app)
	for _i in range(3): await process_frame
	app.set_process(false)
	_check(app.start_foundation_run("ACTIVE-ITEM-NEEDS-GAME", {}, false), "Could not start focused host fixture.")
	# Synthetic owned-item fixture. The visible Store purchase/confirmation on
	# Web supplies separate actual-player evidence; do not alter a player save.
	app.run_state.add_item("tab_detector")
	app.run_state.set_active_item("tab_detector")
	app.last_hook_result = {"ok":true,"message":"Bought Tab Detector for 35.","bankroll_delta":-35}
	app._refresh_environment_result_feedback()
	var cash: int = app.run_state.bankroll
	var rng: int = app.run_state.rng_state
	var clock: int = app.run_state.game_clock_minutes
	var inventory: Array = app.run_state.inventory.duplicate(true)
	_check(app.use_active_item_slot(), "Normal active-item control did not open confirmation.")
	_check(app._event_choice_popup_is_visible(), "Use confirmation was not visible.")
	app.confirm_pending_active_item_use()
	_check(not app._event_choice_popup_is_visible() and app.pending_active_item_id.is_empty(), "Rejected confirmation left a stale modal owner.")
	_check(app.message_label.text == NEEDS_GAME, "Missing-surface rejection did not keep its specific explanation.")
	_check(app.environment_result_body_label.text.contains(NEEDS_GAME), "Visible feedback still shows the old purchase after Use rejection.")
	var view: Dictionary = app._environment_result_feedback_view()
	_check(str(view.get("message", "")) == NEEDS_GAME and int(view.get("bankroll_delta", -1)) == 0, "Rejection feedback inherited the old purchase debit.")
	_check(app.run_state.bankroll == cash and app.run_state.rng_state == rng and app.run_state.game_clock_minutes == clock, "Rejected Use changed cash, RNG or action clock.")
	_check(app.run_state.inventory == inventory and app.run_state.active_item_id == "tab_detector" and app.current_game == null, "Rejected Use consumed, unequipped or entered an item/game.")
	_check(str(app.last_hook_result.get("message", "")) == "Bought Tab Detector for 35.", "Informational rejection erased the historical purchase receipt.")
	app._clear_recent_result_feedback()
	app._show_message("Next action.")
	app._refresh_environment_result_feedback()
	_check(app.environment_result_body_label.text.contains("Next action.") and not app.environment_result_body_label.text.contains(NEEDS_GAME), "Rejection acknowledgement leaked into subsequent feedback.")
	if app.save_service != null and app.save_service.async_save_in_flight(): app.save_service.wait_for_async_save()
	for failure in failures: push_error(failure)
	print("Active item missing-surface feedback checks: ", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
