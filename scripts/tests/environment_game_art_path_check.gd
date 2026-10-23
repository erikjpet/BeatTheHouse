extends SceneTree

const CanvasScript := preload("res://scripts/ui/pixel_scene_canvas.gd")
const PROPS := ["machine", "coin_pusher_room", "scratch_ticket_room", "street_craps_circle", "craps_room", "bar_dice_room", "video_poker_machine", "baccarat_table", "roulette_table", "card_table"]

class ArtPathProbe:
	extends CanvasScript
	var web_room := true
	var focused := false
	var legacy_calls := 0
	var visited: Array[String] = []

	func _grand_casino_web_low_detail() -> bool:
		return web_room

	func _draw_low_detail_game_prop(_rect: Rect2, _object: Dictionary, _accent: Color, _disabled: bool = false) -> void:
		legacy_calls += 1

	func _draw_game_runtime_badge(_rect: Rect2, object: Dictionary, _accent: Color) -> void:
		visited.append(str(object.prop))

	func _draw() -> void:
		for prop in PROPS:
			_draw_game_prop(Rect2(100, 100, 220, 160), {"id": prop, "prop": prop, "source_id": "slot"}, focused)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# These public fallback entry points had no other callers. Keep their removal
	# covered as well as the runtime dispatch, so a future detail budget cannot
	# silently reconnect the obsolete Web-only art.
	var painters := [CanvasScript]
	for family in ["bar_dice", "coin_pusher", "craps", "scratch_ticket", "street_craps_circle"]:
		var file_name: String = family + ("_prop" if family == "street_craps_circle" else "_room_prop")
		painters.append(load("res://scripts/ui/game_props/%s.gd" % file_name))
	for painter in painters:
		for method in painter.get_script_method_list():
			if str(method.name) in ["draw_low_detail", "_draw_low_detail_game_prop"]:
				push_error("Obsolete room game-art entry point remains: %s" % painter.resource_path)
				quit(1)
				return
	var canvas := ArtPathProbe.new()
	canvas.size = Vector2(900, 400)
	root.add_child(canvas)
	for web_room in [true, false]:
		for focused in [false, true, false]:
			canvas.web_room = web_room
			canvas.focused = focused
			canvas.visited.clear()
			canvas.queue_redraw()
			await process_frame
			await process_frame
			if canvas.visited.size() < PROPS.size():
				push_error("Game prop render pass did not exercise every family.")
				quit(1)
				return
	if canvas.legacy_calls != 0:
		push_error("Idle Web game art diverged from the current painter: %d legacy calls" % canvas.legacy_calls)
		quit(1)
		return
	print("ENVIRONMENT_GAME_ART_PATH_CHECK PASS: all 10 families, Web/native idle-focus-leave")
	quit(0)
