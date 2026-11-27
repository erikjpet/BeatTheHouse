extends SceneTree

const BlackjackPolicy := preload("res://tests/ending_solvers/gold_card_solver/gold_blackjack_policy.gd")


func _initialize() -> void:
	var drawdown := {"segment_net": -42, "net_remaining": 72, "hands_remaining": 0}
	if BlackjackPolicy._wager_target(5, 40, 160, drawdown, "reserve_recovery") != 10:
		push_error("Gold recovery should size to the tier goal without chasing the drawdown.")
		quit(1)
		return
	drawdown["marker_balance"] = 50
	if BlackjackPolicy._wager_target(5, 40, 90, drawdown, "reserve_recovery") != 5:
		push_error("Borrowed chips should not increase the Gold recovery stake.")
		quit(1)
		return
	quit(0)
