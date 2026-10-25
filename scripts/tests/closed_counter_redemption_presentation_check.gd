extends SceneTree

const View := preload("res://scripts/ui/environment_interaction_view_model.gd")
const Controller := preload("res://scripts/ui/environment_interaction_controller.gd")
var checks := 0
var failures: Array[String] = []

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _hook(game: String, hook: String, action: String) -> Dictionary:
	return {"object_id":"game_hook:%s:%s" % [game,hook], "object_type":"game_hook", "parent_id":game, "source_id":hook, "enabled":true, "interactive":true, "slot_binding_source_id":"shopkeeper:merchant", "confirm_action_id":action, "available_actions":[{"id":action,"parent_id":game,"source_id":hook,"object_type":"game_hook"}]}

func _initialize() -> void:
	# Synthetic presentation records, using the exact host/hook identities in
	# the captured Jazz Web save. Actual normal-control Web evidence is separate.
	var pull := _hook("pull_tabs", "ticket_redeemer", "redeem_pull_tab_winners")
	var scratch := _hook("scratch_tickets", "scratch_ticket_clerk", "redeem_scratch_winners")
	var host := {"object_id":"shopkeeper:merchant", "object_type":"shopkeeper", "enabled":true, "interactive":true, "manifest_physical":true, "available_actions":[{"id":"open_shop"}], "confirm_action_id":"open_shop"}
	var wager := {"object_id":"game:pull_tabs", "object_type":"game", "enabled":true, "manifest_physical":true, "available_actions":[{"id":"buy_tab"}], "confirm_action_id":"buy_tab"}
	var travel := {"object_id":"travel:leave", "object_type":"travel", "enabled":true, "manifest_physical":true, "available_actions":[{"id":"open_map"}]}
	var inputs := [host,pull,scratch,wager,travel]
	var original := inputs.duplicate(true)
	var closed := View.objects_with_closing_time_lock(inputs, "Closed. Choose a route out.")
	_check(inputs == original, "Closing filter mutated its input catalog.")
	_check(bool(closed[1].enabled) and closed[1].available_actions == pull.available_actions, "Closed room hides issued Pull Tabs cashout.")
	_check(bool(closed[2].enabled) and closed[2].available_actions == scratch.available_actions, "Closed room hides issued Scratch Tickets cashout.")
	_check(not bool(closed[0].enabled) and closed[0].available_actions.is_empty(), "Closing filter reopened ordinary shop purchases.")
	_check(not bool(closed[3].enabled) and closed[3].available_actions.is_empty(), "Closing filter reopened wagering.")
	_check(closed[4] == travel, "Closing filter changed the route out.")
	var attached := Controller._attach_action_only_records(closed)
	var counter: Dictionary = attached[0]
	var actions: Array = counter.get("attached_room_actions", [])
	_check(actions.size() == 2, "Cashout actions did not attach to their authored visible counter.")
	for action in actions:
		_check(bool(action.get("enabled", false)), "Attached cashout is disabled by the closed shop host.")
		_check(str(action.record.get("slot_binding_source_id", "")) == "shopkeeper:merchant", "Cashout lost its exact counter binding.")
	var disabled := pull.duplicate(true); disabled.enabled = false; disabled.available_actions = []; disabled.confirm_action_id = ""
	_check(not bool(View.objects_with_closing_time_lock([disabled], "Closed")[0].enabled), "Existing failure/authority rejection was reenabled.")
	var wrong_game := _hook("roulette", "ticket_redeemer", "redeem_pull_tab_winners")
	var wrong_hook := _hook("pull_tabs", "clerk_chat", "redeem_pull_tab_winners")
	var ordinary := _hook("pull_tabs", "ticket_redeemer", "buy_tab")
	for record in [wrong_game,wrong_hook,ordinary]:
		_check(not bool(View.objects_with_closing_time_lock([record], "Closed")[0].enabled), "Non-redemption action escaped the closing lock.")
	for failure in failures: push_error(failure)
	print("Closed counter redemption presentation checks: ", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
