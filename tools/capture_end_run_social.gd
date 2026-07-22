extends SceneTree

# Captures a densely populated, deterministic end-of-run report for social
# feature spotlights. Run windowed so the viewport texture contains the frame.
#
#   Godot --path . --script res://tools/capture_end_run_social.gd -- --out=<absolute png path>

const RunReportScreenScript := preload("res://scripts/ui/run_report_screen.gd")

var out_path := "res://branding/screenshots/19_end_of_run_report.png"


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

	var report: RunReportScreen = RunReportScreenScript.new()
	report.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(report)
	await _settle(4)
	report.set_report(_report_model())
	await _settle(5)
	report.call("_on_timeline_seek", 0.86)
	await _settle(4)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var absolute_path := ProjectSettings.globalize_path(out_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(absolute_path)
	if error != OK:
		push_error("END_RUN_CAPTURE_FAILED %s (%d)" % [absolute_path, error])
		quit(1)
		return
	print("END_RUN_CAPTURE_DONE -> %s" % absolute_path)
	quit(0)


func _report_model() -> Dictionary:
	var route := [
		"old_house", "corner_store", "bar", "motel", "underground",
		"pawn_shop", "grand_casino", "cage",
	]
	var timeline := _timeline(route)
	return {
		"outcome": {
			"title": "Players Card earned",
			"how": "You survived the high-roller showdown and cashed out clean.",
			"where": "The Cage at Grand Casino - Day 2, 10:15 PM",
			"won": true,
			"icon_path": "res://assets/art/run_outcomes/players_card.png",
		},
		"score": {
			"money_put_to_work": 6420,
			"winner_bonus": 3,
			"show_winner_bonus": true,
			"final_score": 19260,
		},
		"money_rows": [
			{"label": "Blackjack tables", "net": 1840},
			{"label": "Roulette", "net": -620},
			{"label": "Video poker", "net": 1325},
			{"label": "Bar dice", "net": 410},
			{"label": "Pawned gear", "net": 275},
			{"label": "Slots", "net": -190},
		],
		"items": {
			"kept": [
				{"label": "High Roller Watch", "count": 1, "fate": "kept", "icon_path": "res://assets/art/items/high_roller_watch.png"},
				{"label": "Lucky Cigarette", "count": 2, "fate": "kept", "icon_path": "res://assets/art/items/lucky_cigarette.png"},
			],
			"pawned": [
				{"label": "Marked Cards", "count": 1, "fate": "redeemed", "icon_path": "res://assets/art/items/marked_cards.png"},
			],
			"sold": [
				{"label": "Broken Cufflinks", "count": 1, "price": 54, "icon_path": "res://assets/art/items/broken_cufflinks.png"},
			],
		},
		"take_home_item_reward": {
			"visible": true,
			"pending": true,
			"choices": [
				{"id": "suitcase", "display_name": "Suitcase", "capacity": 8, "icon_path": "res://assets/art/items/suitcase.png"},
				{"id": "backpack", "display_name": "Backpack", "capacity": 5, "icon_path": "res://assets/art/items/backpack.png"},
			],
		},
		"bag_reward": {
			"visible": true,
			"pending": true,
			"choices": [
				{"marker_id": "spotlight-victory-bag", "display_name": "High Roller Gold Bag", "collection_name": "High Roller", "tier_label": "Gold"},
			],
			"summary_lines": [],
		},
		"meta_reward": {
			"visible": true,
			"title": "CHIPS KEPT - Grand Casino Chips x84",
			"detail": "Face value 84 - Sal offers 51 gold",
		},
		"debts": [
			{"lender": "Sal", "amount": 300, "outcome": "repaid in full", "tone": "settled"},
			{"lender": "Mickey", "amount": 125, "outcome": "redeemed", "tone": "settled"},
			{"lender": "House marker", "amount": 200, "outcome": "cleared", "tone": "settled"},
		],
		"timeline": timeline,
		"map_snapshot": _map_snapshot(route),
		"seed": "FULL-HOUSE-EXTENSIVE-042",
	}


func _map_snapshot(route: Array) -> Dictionary:
	var nodes := [
		_node("old_house", "Old House", 0.12, 0.76, "house"),
		_node("corner_store", "Corner Store", 0.24, 0.52, "corner_store"),
		_node("bar", "Kitty Cat Lounge", 0.35, 0.27, "bar"),
		_node("motel", "Motel", 0.47, 0.66, "motel"),
		_node("underground", "Underground Casino", 0.59, 0.39, "small_underground_casino"),
		_node("pawn_shop", "Sal's Pawn", 0.67, 0.77, "pawn_shop"),
		_node("grand_casino", "Grand Casino", 0.82, 0.32, "grand_casino"),
		_node("cage", "The Cage", 0.91, 0.58, "grand_casino"),
	]
	var edges: Array = []
	for index in range(route.size() - 1):
		edges.append({
			"id": "%s--%s" % [route[index], route[index + 1]],
			"a": route[index],
			"b": route[index + 1],
			"distance": "far" if index in [2, 5] else "near",
		})
	return {
		"nodes": nodes,
		"edges": edges,
		"visited_path": route,
		"map_focus_node_ids": route,
		"current_node_id": "cage",
		"selected_node_id": "",
		"travel_paths": [],
	}


func _node(id: String, display_name: String, x: float, y: float, icon_key: String) -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"label": display_name,
		"position": {"x": x, "y": y},
		"state": "visited",
		"icon_path": "res://assets/art/map_icons/%s.png" % icon_key,
	}


func _timeline(route: Array) -> Dictionary:
	var start_clock := 720
	var end_clock := 2055
	var keyframes: Array = []
	for index in range(route.size()):
		var progress := float(index) / float(route.size() - 1)
		keyframes.append({
			"progress": progress,
			"node_id": route[index],
			"label": str(route[index]).replace("_", " ").capitalize(),
			"game_clock_minutes": roundi(lerpf(start_clock, end_clock, progress)),
		})
	var segments: Array = []
	for index in range(route.size() - 1):
		var start_progress := float(index) / float(route.size() - 1)
		var end_progress := float(index + 1) / float(route.size() - 1)
		segments.append({
			"kind": "travel",
			"from_node_id": route[index],
			"to_node_id": route[index + 1],
			"label": str(route[index + 1]).replace("_", " ").capitalize(),
			"start_progress": start_progress,
			"end_progress": end_progress,
			"start_game_clock_minutes": roundi(lerpf(start_clock, end_clock, start_progress)),
			"end_game_clock_minutes": roundi(lerpf(start_clock, end_clock, end_progress)),
			"leg_index": index,
		})
	var heat_values := [4, 11, 24, 19, 38, 57, 49, 73, 91, 68]
	var heat_samples: Array = []
	for index in range(heat_values.size()):
		heat_samples.append({
			"progress": float(index) / float(heat_values.size() - 1),
			"heat_value": heat_values[index],
		})
	var bands: Array = []
	for index in range(route.size()):
		bands.append({
			"start_progress": float(index) / float(route.size()),
			"end_progress": float(index + 1) / float(route.size()),
			"label": str(route[index]).replace("_", " ").capitalize(),
			"color_index": index,
		})
	return {
		"max_action_index": 126,
		"start_game_clock_minutes": start_clock,
		"end_game_clock_minutes": end_clock,
		"duration_minutes": end_clock - start_clock,
		"heat_samples": heat_samples,
		"environment_bands": bands,
		"travel_keyframes": keyframes,
		"replay_segments": segments,
		"visited_node_ids": route,
		"precomputed": true,
	}


func _settle(frames: int) -> void:
	for _index in range(frames):
		await process_frame
