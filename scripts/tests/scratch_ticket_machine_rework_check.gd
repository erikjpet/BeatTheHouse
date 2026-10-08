extends SceneTree

const ScratchGameScript := preload("res://scripts/games/scratch_tickets.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const MachineRendererScript := preload("res://scripts/games/scratch_ticket_machine_renderer.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: ScratchTicketsGame = ScratchGameScript.new()
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	game.setup(library.game("scratch_tickets"), library)
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("SCRATCH-MACHINE-REWORK-CHECK")
	run_state.bankroll = 5000
	var environment := {
		"id": "scratch_machine_rework",
		"world_node_id": "scratch_machine_rework",
		"display_name": "Roadside Gas",
		"archetype_id": "gas_station_casino",
		"kind": "casino",
		"game_ids": ["scratch_tickets"],
		"game_states": {},
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 100},
		"visual_context": {"scene_type": "gas_station_casino"},
	}
	var machine: Dictionary = game.generate_environment_state(run_state, environment, run_state.create_rng("stock"))
	var stock: Array = machine.get("stock", [])
	if stock.is_empty():
		failures.append("Machine generated no scratch stock.")
		_finish()
		return
	(stock[0] as Dictionary)["remaining"] = 5
	machine["stock"] = stock
	machine["scalper_visit_token"] = game.call("_scratch_visit_token", run_state, environment)
	machine["scalper_present"] = false
	environment["game_states"] = {"scratch_tickets": machine}
	run_state.current_environment = environment

	var buy := game.surface_action_command("scratch_buy", 0, false, {}, run_state, environment)
	var pre_purchase_machine: Dictionary = game.call("_ensure_machine_state", run_state, environment, false)
	if int(((pre_purchase_machine.get("stock", []) as Array)[0] as Dictionary).get("remaining", -1)) != 5 or int((buy.get("ui_state", {}) as Dictionary).get("scratch_buy_quantity", -1)) != 1:
		failures.append("Focused purchase fixture drifted before resolution.")
	var purchase_result := game.resolve_with_context("buy_scratch_ticket", int(buy.get("set_stake", 0)), run_state, environment, run_state.create_rng("buy"), buy.get("ui_state", {}))
	machine = (environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	var tray: Array = machine.get("tray_stack", [])
	if tray.size() != 1 or not (machine.get("active_ticket", {}) as Dictionary).is_empty():
		failures.append("Purchase did not stop in the delivery tray: %s" % str(purchase_result.get("message", "unknown result")))
	var restored: RunState = RunStateScript.new()
	restored.from_dict(run_state.to_dict())
	var restored_tray: Array = restored.portable_ticket_state("scratch_tickets", restored.current_environment).get("tray_stack", [])
	if restored_tray.size() != 1:
		failures.append("A delivered, uncollected ticket did not survive save/restore.")
	var surface := game.surface_state(run_state, environment, buy.get("ui_state", {}))
	var events: Array = surface.get("scratch_dispense_events", [])
	var channels: Array = surface.get("surface_animation_channels", [])
	if events.size() != 1 or channels.is_empty() or int((channels[0] as Dictionary).get("duration_msec", 0)) != 1500:
		failures.append("Single-ticket dispense is not exactly 1.5 seconds.")
	var animation_ticket: Dictionary = (events[0] as Dictionary).get("ticket", {}) if not events.is_empty() else {}
	if animation_ticket.has("payout") or animation_ticket.has("outcome") or animation_ticket.has("mechanic_result"):
		failures.append("Dispense presentation leaked a ticket's fixed hidden outcome.")
	var audio: Dictionary = surface.get("surface_audio", {})
	var sync: Dictionary = audio.get("state_sync", {}) if typeof(audio.get("state_sync", {})) == TYPE_DICTIONARY else {}
	if str(sync.get("method", "")) != "scratch_dispense_state":
		failures.append("Machine animation has no synchronized lift/pick/lower audio route.")
	var sample_ticket: Dictionary = tray[0] if not tray.is_empty() else {}
	var triple_events: Array = game.call("_scratch_dispense_events_for_tickets", [sample_ticket, sample_ticket, sample_ticket], 0)
	if triple_events.size() != 3 or int(game.call("_scratch_dispense_duration_msec", triple_events)) != 4500:
		failures.append("Multi-buy does not reserve 1.5 seconds per ticket.")

	var moving_harness := MachineHarness.new()
	moving_harness.animation_active = true
	moving_harness.elapsed = 0.56
	MachineRendererScript.draw(moving_harness, surface, Rect2(18, 13, 278, 404))
	if moving_harness.actions.has("scratch_collect_tray"):
		failures.append("Output tray became collectible before the lift finished.")
	var delivered_harness := MachineHarness.new()
	MachineRendererScript.draw(delivered_harness, surface, Rect2(18, 13, 278, 404))
	if not delivered_harness.actions.has("scratch_collect_tray"):
		failures.append("Delivered ticket tray is not clickable after the animation.")
	var collect := game.surface_action_command("scratch_collect_tray", 0, false, buy.get("ui_state", {}), run_state, environment)
	machine = (environment.get("game_states", {}) as Dictionary).get("scratch_tickets", {})
	if not bool(collect.get("environment_changed", false)) or (machine.get("active_ticket", {}) as Dictionary).is_empty() or not (machine.get("tray_stack", []) as Array).is_empty():
		failures.append("Tray click did not move the delivered ticket to the play area.")
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("SCRATCH_TICKET_MACHINE_REWORK_CHECK_PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


class MachineHarness:
	extends RefCounted

	var animation_active := false
	var elapsed := 0.0
	var actions: Array[String] = []

	func surface_flicker() -> float:
		return 0.5

	func surface_animation_active(_channel_id: String) -> bool:
		return animation_active

	func surface_elapsed(_channel_id: String) -> float:
		return elapsed

	func surface_region_hovered(_action: String, _index: int) -> bool:
		return false

	func surface_add_hit(_rect: Rect2, action: String, _index: int = -1, _expand_touch_hit: bool = true) -> void:
		if not actions.has(action):
			actions.append(action)

	func surface_add_invisible_hit(_rect: Rect2, action: String, _index: int = -1, _expand_touch_hit: bool = true) -> void:
		if not actions.has(action):
			actions.append(action)

	func surface_label(_text: String, _position: Vector2, _font_size: int, _color: Color) -> void:
		pass

	func surface_label_centered(_text: String, _rect: Rect2, _font_size: int, _color: Color) -> void:
		pass

	func draw_rect(_rect: Rect2, _color: Color, _filled: bool = true, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass

	func draw_polygon(_points: PackedVector2Array, _colors: PackedColorArray, _uvs: PackedVector2Array = PackedVector2Array(), _texture: Texture2D = null) -> void:
		pass

	func draw_circle(_position: Vector2, _radius: float, _color: Color, _filled: bool = true, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass

	func draw_line(_from: Vector2, _to: Vector2, _color: Color, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass

	func draw_arc(_center: Vector2, _radius: float, _start_angle: float, _end_angle: float, _point_count: int, _color: Color, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass
