extends SceneTree

# Captures the 0.6 career ledger with every supported victory route populated.
# Run windowed so the viewport texture contains the rendered frame.
#
#   Godot --path . --script res://tools/meta06_1_career_capture.gd -- --out=<absolute png path>

const CareerStatsScreenScript := preload("res://scripts/ui/career_stats_screen.gd")

var out_path := "res://docs/screenshots/0.6/meta06_1_career_all_routes.png"


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out_path = argument.trim_prefix("--out=")
	call_deferred("_run")


func _run() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#03040a")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	backdrop.add_child(margin)

	var screen: CareerStatsScreen = CareerStatsScreenScript.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(screen)
	await _settle(4)
	screen.set_model(_career_model())
	await _settle(6)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var absolute_path := ProjectSettings.globalize_path(out_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(absolute_path)
	if error != OK:
		push_error("META06_1_CAREER_CAPTURE_FAILED %s (%d)" % [absolute_path, error])
		quit(1)
		return
	print("META06_1_CAREER_CAPTURE_DONE -> %s" % absolute_path)
	quit(0)


func _career_model() -> Dictionary:
	return {
		"empty": false,
		"headline": [
			{"id": "runs", "label": "Runs", "value": "14", "detail": "14 finished climbs"},
			{"id": "victories", "label": "Wins", "value": "8", "detail": "3 routes recorded"},
		],
		"routes": [
			{"id": "players_card_cashout", "label": "Players Card Cashout", "value": "4", "complete": true},
			{"id": "showdown", "label": "Rourke Showdown", "value": "2", "complete": true},
			{"id": "crew_heist", "label": "Crew Heist", "value": "2", "complete": true},
		],
		"money": [
			{"label": "Bankroll won", "value": "$24,880"},
			{"label": "Bankroll lost", "value": "$8,340"},
		],
		"daily": {"current_streak": 2, "best_streak": 5, "last_completed_date": "2026-08-25"},
		"release_0_6": [
			{
				"id": "crew",
				"title": "Crew",
				"rows": [
					{"label": "Runs on the path", "value": "6"},
					{"label": "Highest standing", "value": "Inner Circle"},
					{"label": "Members met", "value": "7"},
					{"label": "Jobs", "value": "9 completed / 2 abandoned"},
					{"label": "Turn endings", "value": "1"},
				],
			},
			{
				"id": "world",
				"title": "World",
				"rows": [
					{"label": "Nights survived", "value": "11"},
					{"label": "Scenarios experienced", "value": "23"},
					{"label": "Aftermath outcomes", "value": "8"},
					{"label": "Sweeps encountered", "value": "3"},
					{"label": "Rumors proved true", "value": "4"},
				],
			},
			{
				"id": "numbers",
				"title": "Numbers",
				"rows": [
					{"label": "Slips placed", "value": "12"},
					{"label": "Hits", "value": "3"},
					{"label": "Rig routes used", "value": "1"},
				],
			},
			{
				"id": "games",
				"title": "Games",
				"rows": [
					{"label": "Craps", "value": "18"},
					{"label": "Quarter Falls", "value": "31"},
					{"label": "Back-Room Poker", "value": "7"},
				],
			},
			{
				"id": "deliveries",
				"title": "Deliveries",
				"rows": [
					{"label": "Runs completed", "value": "5"},
					{"label": "Packages lost", "value": "1"},
				],
			},
		],
		"challenges": [{"id": "stayed_clean", "title": "Stayed Clean"}],
		"history": [
			{"date": "2026-08-25", "outcome": "Victory - Crew Heist", "bankroll": "$6,920", "day": "Day 3", "actions": "126 actions", "score": 20760, "won": true},
		],
		"missing_stats": [
			"Older profiles begin the 0.6 rows, including the exact Crew roster, at zero. Earlier runs did not retain enough detail to rebuild them.",
		],
	}


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame
