extends SceneTree

const Main := preload("res://scripts/ui/foundation_main.gd")
const Text := preload("res://scripts/ui/player_text.gd")
const IDS := ["scratch_tickets","pull_tabs","slot","bar_dice","blackjack","baccarat","craps","roulette","crew_draw_poker","video_poker","coin_pusher"]

class Labels extends "res://scripts/ui/game_surface_canvas.gd":
	var latest: Array[String] = []
	var draws := 0
	func _draw() -> void:
		draws += 1
		super._draw()
	func surface_label(text: String, pos: Vector2, font_size: int, color: Color) -> void:
		if not latest.has(text): latest.append(text)
		super.surface_label(text,pos,font_size,color)
	func surface_label_plain(text: String, pos: Vector2, font_size: int, color: Color) -> void:
		if not latest.has(text): latest.append(text)
		super.surface_label_plain(text,pos,font_size,color)
	func surface_label_centered(text: String, rect: Rect2, font_size: int, color: Color) -> void:
		if not latest.has(text): latest.append(text)
		super.surface_label_centered(text,rect,font_size,color)
	func surface_label_centered_plain(text: String, rect: Rect2, font_size: int, color: Color) -> void:
		if not latest.has(text): latest.append(text)
		super.surface_label_centered_plain(text,rect,font_size,color)

class SqueezeLabels extends RefCounted:
	var values: Array[String] = []
	func draw_rect(_rect,_color,_filled=true,_width=-1.0):pass
	func draw_polygon(_points,_colors):pass
	func surface_label_centered_plain(text,_rect,_size,_color):values.append(text)

var checks := 0
var failures: Array[String] = []
var observations: Array = []

func _init() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _frames(n: int) -> void:
	for i in range(n): await process_frame

func _run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1280,720)
	var app := Main.new()
	app.set("GameSurfaceCanvasScript",Labels)
	app.autosave_slot_id = "qol04_display"
	root.add_child(app)
	await _frames(8)
	app._settle_script_prewarm_before_runtime()
	var decimal := RegEx.new()
	decimal.compile("(^|[^0-9.])[0-9]+[.]0($|[^0-9])")
	for id in IDS:
		var started: Dictionary = app.start_game_test_session(id)
		_check(bool(started.get("ok",false)),id+" entered through ordinary practice host")
		if not bool(started.get("ok",false)):continue
		await _frames(5)
		app.autosave_slot_id = "qol04_"+id
		var cash: int = app.run_state.bankroll
		var chips: int = app.run_state.grand_casino_chips
		var rng: int = app.run_state.rng_state
		_check(app.save_service.save_run(app.run_state,app.autosave_slot_id)==OK,id+" real save")
		app.game_surface_canvas.latest.clear()
		_check(app.load_foundation_run(),id+" real Continue")
		_check(app.run_state.bankroll==cash and app.run_state.grand_casino_chips==chips and app.run_state.rng_state==rng,id+" load preserves wallet/RNG")
		_check(app.enter_game(id),id+" reopens after Continue")
		await _frames(8)
		var canvas: Control = app.game_surface_canvas
		var labels: Array = canvas.latest.duplicate()
		for row in canvas.state.get("surface_state_labels",[]):labels.append(str(row.get("value","")))
		var decimal_labels: Array = []
		for text_value in labels:
			var text := str(text_value)
			# Explicit subsecond countdowns retain their designed precision.
			if text.begins_with("PEEK ") and text.ends_with("s"):continue
			if decimal.search(text)!=null:decimal_labels.append(text)
		_check(int(canvas.draws)>0 and not labels.is_empty(),id+" production renderer produced text")
		_check(decimal_labels.is_empty(),id+" loaded whole-number labels: "+JSON.stringify(decimal_labels))
		observations.append({"game":id,"render_draws":canvas.draws,"label_count":labels.size(),"labels":labels,"decimal_labels":decimal_labels})
		print("QOL04_GAME "+JSON.stringify(observations[-1]))
		app.return_to_main_menu()
		await _frames(2)
	var baccarat := preload("res://scripts/games/baccarat.gd").new()
	var card: Dictionary = JSON.parse_string('{"rank":2,"suit":1}')
	var before := card.duplicate(true)
	var probe := SqueezeLabels.new()
	baccarat._draw_squeezed_card(probe,card,Vector2.ZERO,0.5)
	_check(probe.values==["21"],"Loaded squeezed-card rank: "+str(probe.values))
	_check(card==before,"Squeeze drawing preserves saved card")
	print("QOL04_SQUEEZE "+JSON.stringify(probe.values))
	_check(Text.new().has_method("whole_number"),"Shared whole-number formatter exists")
	if Text.new().has_method("whole_number"):
		for pair in [[2,"2"],[2.0,"2"],[0.0,"0"],[-3.0,"-3"],[1.25,"1.25"],["A","A"],["00","00"],[9223372036854775807,"9223372036854775807"]]:
			_check(Text.new().call("whole_number",pair[0])==pair[1],"formatter "+str(pair))
	print("QOL04_WHOLE_NUMBER "+JSON.stringify({"checks":checks,"failures":failures,"games":observations.size()}))
	app.queue_free()
	await _frames(3)
	quit(0 if failures.is_empty() else 1)
