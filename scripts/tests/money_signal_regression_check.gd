extends SceneTree

const RunStateScript := preload("res://scripts/core/run_state.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var run := RunStateScript.new()
	run.start_new("MONEY-SIGNAL-REGRESSION")
	var emissions := [0]
	run.money_changed.connect(func(_revision: int) -> void: emissions[0] += 1)
	var revision_before := run.money_revision()
	var bankroll_before := run.bankroll
	run.change_bankroll(7)
	var ok := run.bankroll == bankroll_before + 7 \
		and int(emissions[0]) == 1 \
		and run.money_revision() == revision_before + 1
	if ok:
		print("MONEY SIGNAL CHECK bankroll_delta=7 emissions=1 revision_delta=1 ok=true")
		quit(0)
		return
	printerr("MONEY SIGNAL CHECK bankroll_delta=%d emissions=%d revision_delta=%d ok=false" % [
		run.bankroll - bankroll_before,
		int(emissions[0]),
		run.money_revision() - revision_before,
	])
	quit(1)
