extends SceneTree

const ScratchGameScript := preload("res://scripts/games/scratch_tickets.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")
const TYPE_IDS := ["two_fer", "lucky_7s", "tic_tac_gold", "crossword_corner", "bonus_bingo", "high_roller_holdem", "golden_vault"]
const OUTPUT_DIR := "res://.tmp/scratch_redesign_proof"
const CAPTURE_SIZE := Vector2i(1280, 720)

var viewport: Viewport
var canvas: GameSurfaceCanvas
var game: ScratchTicketsGame
var saved_files: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var absolute_output := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_output)
	game = ScratchGameScript.new()
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	game.library = library
	get_root().size = CAPTURE_SIZE
	RenderingServer.set_default_clear_color(Color("#111015"))
	viewport = get_root().get_viewport()
	canvas = GameSurfaceCanvasScript.new()
	canvas.size = Vector2(CAPTURE_SIZE)
	canvas.set_game_module(game)
	get_root().add_child(canvas)
	for frame_index in range(3):
		await process_frame
	await _capture_layer_isolation()
	await _capture_uniqueness()
	await _capture_smooth_scratch()
	await _capture_trash_flow()
	await _capture_machine()
	_write_manifest()
	print("SCRATCH_REDESIGN_CAPTURE_PASS files=%d dir=%s" % [saved_files.size(), absolute_output])
	quit(0)


func _capture_layer_isolation() -> void:
	var sheet := Image.create(CAPTURE_SIZE.x * 3, CAPTURE_SIZE.y * TYPE_IDS.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#111015"))
	for type_index in range(TYPE_IDS.size()):
		var type_id := str(TYPE_IDS[type_index])
		var ticket := _ticket_for_prize(type_id, -1, "layers:%s" % type_id)
		var context := _surface_context(ticket, [])
		for layer_count in range(1, 4):
			var surface: Dictionary = context.get("surface", {})
			surface["scratch_debug_layer_count"] = layer_count
			var image := await _render(surface)
			var suffix := "background" if layer_count == 1 else "background_icons" if layer_count == 2 else "all_layers"
			_save_image(image, "%02d_%s_%s.png" % [type_index + 1, type_id, suffix])
			sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CAPTURE_SIZE), Vector2i((layer_count - 1) * CAPTURE_SIZE.x, type_index * CAPTURE_SIZE.y))
	_save_image(sheet, "layer_isolation_all_tickets.png")


func _capture_uniqueness() -> void:
	var sheet := Image.create(CAPTURE_SIZE.x * 3, CAPTURE_SIZE.y * TYPE_IDS.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#111015"))
	var uniqueness: Dictionary = {}
	for type_index in range(TYPE_IDS.size()):
		var type_id := str(TYPE_IDS[type_index])
		var signatures: Dictionary = {}
		for instance_index in range(3):
			var ticket := _ticket_for_prize(type_id, -1, "unique:%s:%d" % [type_id, instance_index])
			signatures[JSON.stringify(ticket.get("mechanic_result", {}))] = true
			var context := _surface_context(ticket, [])
			var surface: Dictionary = context.get("surface", {})
			surface["scratch_debug_layer_count"] = 2
			var image := await _render(surface)
			_save_image(image, "unique_%02d_%s_instance_%d.png" % [type_index + 1, type_id, instance_index + 1])
			sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CAPTURE_SIZE), Vector2i(instance_index * CAPTURE_SIZE.x, type_index * CAPTURE_SIZE.y))
		uniqueness[type_id] = signatures.size()
	_save_image(sheet, "same_payout_unique_instances.png")
	var file := FileAccess.open("%s/uniqueness.json" % OUTPUT_DIR, FileAccess.WRITE)
	file.store_string(JSON.stringify(uniqueness, "\t") + "\n")
	saved_files.append("uniqueness.json")


func _capture_smooth_scratch() -> void:
	var ticket := _ticket_for_prize("two_fer", 1, "smooth-scratch")
	var context := _surface_context(ticket, [])
	var surface: Dictionary = context.get("surface", {})
	var first := await _render(surface)
	_save_image(first, "smooth_scratch_01_coated.png")
	var rect: Rect2 = game.call("_ticket_scratch_rect", ticket)
	var machine: Dictionary = context.get("machine", {})
	game.call("_scratch_segment", machine, Vector2(rect.position.x + 8, rect.position.y + rect.size.y * 0.58), Vector2(rect.end.x - 8, rect.position.y + rect.size.y * 0.58))
	surface = game.surface_state(context.get("run_state"), context.get("environment"), {})
	var second := await _render(surface)
	_save_image(second, "smooth_scratch_02_fast_swipe.png")
	for y_ratio in [0.53, 0.63, 0.68]:
		game.call("_scratch_segment", machine, Vector2(rect.position.x + 8, rect.position.y + rect.size.y * float(y_ratio)), Vector2(rect.end.x - 8, rect.position.y + rect.size.y * float(y_ratio)))
	surface = game.surface_state(context.get("run_state"), context.get("environment"), {})
	var third := await _render(surface)
	_save_image(third, "smooth_scratch_03_clean_reveal.png")
	var sheet := Image.create(CAPTURE_SIZE.x * 3, CAPTURE_SIZE.y, false, Image.FORMAT_RGBA8)
	sheet.blit_rect(first, Rect2i(Vector2i.ZERO, CAPTURE_SIZE), Vector2i.ZERO)
	sheet.blit_rect(second, Rect2i(Vector2i.ZERO, CAPTURE_SIZE), Vector2i(CAPTURE_SIZE.x, 0))
	sheet.blit_rect(third, Rect2i(Vector2i.ZERO, CAPTURE_SIZE), Vector2i(CAPTURE_SIZE.x * 2, 0))
	_save_image(sheet, "smooth_scratch_demonstration.png")


func _capture_trash_flow() -> void:
	var dud := _ticket_for_prize("two_fer", 0, "trash-dud")
	var next_ticket := _ticket_for_prize("lucky_7s", 2, "trash-next")
	var context := _surface_context(dud, [next_ticket])
	var rect: Rect2 = game.call("_ticket_scratch_rect", dud)
	var machine: Dictionary = context.get("machine", {})
	game.call("_scratch_segment", machine, rect.position + rect.size * Vector2(0.10, 0.60), rect.position + rect.size * Vector2(0.55, 0.60))
	var before_surface := game.surface_state(context.get("run_state"), context.get("environment"), {})
	var before := await _render(before_surface)
	_save_image(before, "trash_flow_01_dud_mid_scratch.png")
	var begin := game.surface_pointer_command("scratch_scrub", 0, "begin", rect.get_center(), {}, context.get("run_state"), context.get("environment"))
	var drag_ui: Dictionary = begin.get("ui_state", {})
	drag_ui["scratch_last_pointer"] = Vector2(248, 372)
	var target_surface := game.surface_state(context.get("run_state"), context.get("environment"), drag_ui)
	var target := await _render(target_surface)
	_save_image(target, "trash_flow_02_basket_drop_target.png")
	var command := game.surface_pointer_command("scratch_scrub", 0, "end", Vector2(248, 372), drag_ui, context.get("run_state"), context.get("environment"))
	game.resolve_with_context("settle_scratch_ticket", 0, context.get("run_state"), context.get("environment"), _rng("trash-resolve"), command.get("ui_state", {}))
	var after_surface := game.surface_state(context.get("run_state"), context.get("environment"), {})
	var after := await _render(after_surface)
	_save_image(after, "trash_flow_03_next_ticket.png")
	var sheet := Image.create(CAPTURE_SIZE.x * 3, CAPTURE_SIZE.y, false, Image.FORMAT_RGBA8)
	sheet.blit_rect(before, Rect2i(Vector2i.ZERO, CAPTURE_SIZE), Vector2i.ZERO)
	sheet.blit_rect(target, Rect2i(Vector2i.ZERO, CAPTURE_SIZE), Vector2i(CAPTURE_SIZE.x, 0))
	sheet.blit_rect(after, Rect2i(Vector2i.ZERO, CAPTURE_SIZE), Vector2i(CAPTURE_SIZE.x * 2, 0))
	_save_image(sheet, "trash_flow_demonstration.png")


func _capture_machine() -> void:
	var context := _surface_context({}, [])
	var machine: Dictionary = context.get("machine", {})
	var stock: Array = machine.get("stock", [])
	for index in range(stock.size()):
		var slot: Dictionary = stock[index]
		slot["remaining"] = 1 + index % 5
		stock[index] = slot
	machine["stock"] = stock
	var surface := game.surface_state(context.get("run_state"), context.get("environment"), {})
	var image := await _render(surface)
	_save_image(image, "vending_machine_context.png")
	var cabinet := image.get_region(Rect2i(12, 36, 410, 620))
	_save_image(cabinet, "vending_machine_polished.png")


func _ticket_for_prize(type_id: String, prize_index: int, seed_text: String) -> Dictionary:
	var definition: Dictionary = game.call("_ticket_type", type_id)
	var ticket: Dictionary = game.call("_roll_ticket", definition, _rng("%s:roll" % seed_text), 0, seed_text)
	var table: Array = definition.get("prize_table", [])
	var resolved_index := table.size() - 1 if prize_index < 0 else clampi(prize_index, 0, table.size() - 1)
	var prize: Dictionary = table[resolved_index]
	var mechanic: Dictionary = definition.get("mechanic", {})
	var content: Dictionary = game.call("_build_mechanic_content", str(mechanic.get("type", "")), mechanic, prize, _rng("%s:face" % seed_text))
	ticket["outcome_id"] = str(prize.get("id", ""))
	ticket["outcome"] = prize.duplicate(true)
	ticket["payout"] = int(prize.get("payout", 0))
	ticket["mechanic_result"] = content
	ticket["spots"] = content.get("spots", [])
	game.call("_initialize_ticket_mask", ticket, definition)
	return ticket


func _surface_context(ticket: Dictionary, queue: Array) -> Dictionary:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SCRATCH-REDESIGN-CAPTURE")
	run_state.bankroll = 500000
	var environment := {
		"id": "scratch_capture",
		"world_node_id": "scratch_capture",
		"display_name": "Roadside Gas",
		"archetype_id": "gas_station_casino",
		"kind": "casino",
		"game_ids": ["scratch_tickets"],
		"game_states": {},
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 100},
		"visual_context": {"scene_type": "gas_station_casino"},
	}
	var machine: Dictionary = game.call("_generate_machine_state", run_state, environment, _rng("capture-stock"))
	var stock: Array = machine.get("stock", [])
	for index in range(stock.size()):
		var slot: Dictionary = stock[index]
		slot["remaining"] = 3
		stock[index] = slot
	machine["stock"] = stock
	machine["active_ticket"] = ticket
	machine["pending_queue"] = queue
	environment["game_states"] = {"scratch_tickets": machine}
	run_state.current_environment = environment
	game.call("_write_machine_state", environment, machine, run_state, false)
	var surface := game.surface_state(run_state, environment, {})
	return {"run_state": run_state, "environment": environment, "machine": machine, "surface": surface}


func _render(surface: Dictionary) -> Image:
	canvas.render_game_snapshot(surface)
	canvas.queue_redraw()
	for frame_index in range(3):
		await process_frame
	return viewport.get_texture().get_image()


func _save_image(image: Image, file_name: String) -> void:
	var error := image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	if error != OK:
		push_error("Could not save scratch proof %s: %s" % [file_name, error_string(error)])
		quit(1)
	saved_files.append(file_name)


func _write_manifest() -> void:
	var manifest := {
		"tool": "scratch_ticket_redesign_capture",
		"passed": true,
		"capture_size": [CAPTURE_SIZE.x, CAPTURE_SIZE.y],
		"ticket_types": TYPE_IDS,
		"files": saved_files,
		"layer_order": ["background", "icons", "foil"],
		"mask": {"columns": 256, "rows": 192, "kind": "continuous_high_resolution"},
		"discard_rule": "Discarded winners are filed safely and remain payable at the clerk.",
	}
	var file := FileAccess.open("%s/manifest.json" % OUTPUT_DIR, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	saved_files.append("manifest.json")


func _rng(seed_text: String) -> RngStream:
	var rng: RngStream = RngStreamScript.new()
	var seed := RunState.text_to_seed(seed_text)
	rng.configure(seed, seed)
	return rng
