extends SceneTree

# Synthetic presentation/command regression for the Slot COLLECT/Nudge defect.
# This does not open a player profile, resolve a wager, exercise OS input, or
# qualify Save/cold Continue. Run only through the maintained isolated runner.

const SlotRendererScript := preload("res://scripts/games/slots/slot_renderer.gd")
const SlotGameScript := preload("res://scripts/games/slot.gd")
const SlotPresentationScript := preload("res://scripts/games/slots/slot_presentation.gd")
const SlotMachineGeneratorScript := preload("res://scripts/games/slots/slot_machine_generator.gd")
const SlotMachineStateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")


class RecordingSurface:
	extends RefCounted

	var labels: Array = []
	var hits: Array = []

	func draw_rect(_rect: Rect2, _color: Color, _filled: bool = true, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass

	func surface_label(text: String, position: Vector2, _font_size: int, _color: Color) -> void:
		labels.append({"text": text, "position": position})

	func surface_label_centered(text: String, rect: Rect2, _font_size: int, _color: Color) -> void:
		labels.append({"text": text, "position": rect.get_center()})

	func surface_region_hovered(_action: String, _index: int = -1) -> bool:
		return false

	func surface_add_hit(rect: Rect2, action: String, index: int = -1) -> void:
		hits.append({"rect": rect, "action": action, "index": index})

	func all_text() -> String:
		var result := ""
		for entry in labels:
			result += str(entry.get("text", "")) + "\n"
		return result.to_upper()

	func text_inside(rect: Rect2) -> String:
		var result := ""
		for entry in labels:
			if rect.has_point(entry.get("position", Vector2.ZERO)):
				result += str(entry.get("text", "")) + "\n"
		return result.to_upper()

	func hits_for(action: String) -> Array:
		var result: Array = []
		for hit in hits:
			if str(hit.get("action", "")) == action:
				result.append(hit)
		return result


var failures: Array = []
var receipts: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var renderer = SlotRendererScript.new()
	_check_rendered_offer(renderer, true)
	_check_rendered_offer(renderer, false)
	_check_normal_controls(renderer)
	_check_commands_and_bindings()
	print(JSON.stringify({
		"test": "slot_nudge_label_contract",
		"scope": "synthetic renderer and module command contract; no gameplay resolution, OS input or persistence qualification",
		"passed": failures.is_empty(),
		"failures": failures,
		"receipts": receipts,
	}))
	quit(0 if failures.is_empty() else 1)


func _skin() -> Dictionary:
	return {
		"controls": {"x": 84, "y": 430, "w": 790, "h": 76},
		"tease_panel": {"x": 34, "y": 146, "w": 184, "h": 222},
		"feature_panel": {"x": 740, "y": 146, "w": 184, "h": 222},
		"feature_name": "PINBALL",
	}


func _render_controls(renderer, state: Dictionary) -> RecordingSurface:
	var surface := RecordingSurface.new()
	renderer.call("_draw_controls", surface, state, _skin(), Color.PINK, Color.WHITE, Color.YELLOW)
	return surface


func _base_surface_state() -> Dictionary:
	return {
		"bankroll": 92,
		"suspicion_level": 0,
		"slot_selected_bet": 2,
		"slot_selected_bet_id": "bet_2",
		"slot_bet_options": SlotMachineStateScript.BET_OPTIONS,
		"slot_active_bonus_active": false,
		"slot_autoplay_active": false,
		"slot_nudge_available": false,
	}


func _check_rendered_offer(renderer, chain: bool) -> void:
	var state := _base_surface_state()
	state["slot_nudge_available"] = true
	state["slot_nudge_chain_active"] = chain
	state["slot_nudge_chain_coins"] = [{"index": 0}]
	state["slot_nudge_chain_collected_count"] = 0
	state["slot_nudge_chain_banked_payout"] = 0
	var label := "coin_chain" if chain else "legacy_nudge"
	var surface := _render_controls(renderer, state)
	var nudge_hits := surface.hits_for("slot_nudge")
	_check(nudge_hits.size() == 1, "%s: expected exactly one Nudge hit region." % label)
	if nudge_hits.size() == 1:
		var nudge_rect: Rect2 = nudge_hits[0].get("rect", Rect2())
		var nudge_text := surface.text_inside(nudge_rect)
		_check(nudge_text.contains("NUDGE"), "%s: Nudge hit region has no visible NUDGE label." % label)
		_check(nudge_text.contains("CHEAT"), "%s: Nudge hit region has no visible CHEAT marker." % label)
		_check(not nudge_text.contains("COLLECT"), "%s: a displayed COLLECT still invokes slot_nudge." % label)
		for hit in surface.hits:
			if str(hit.get("action", "")) != "slot_nudge":
				var other_rect: Rect2 = hit.get("rect", Rect2())
				_check(not nudge_rect.intersects(other_rect), "%s: Nudge overlaps another control (%s)." % [label, str(hit.get("action", ""))])
	_check(not surface.all_text().contains("COLLECT"), "%s: ordinary controls still display the misleading COLLECT alias." % label)
	var status := RecordingSurface.new()
	renderer.call("_draw_status_panel", status, state, _skin(), Color.PINK, Color.WHITE, Color.YELLOW)
	var warning := status.all_text()
	_check(warning.contains("HEAT"), "%s: status panel does not mention Heat." % label)
	_check(warning.contains("CARD") and warning.contains("CLOSE"), "%s: status panel does not disclose Card closure." % label)
	receipts.append({"case": label, "controls": surface.all_text(), "status": warning})


func _check_normal_controls(renderer) -> void:
	var state := _base_surface_state()
	var surface := _render_controls(renderer, state)
	_check(surface.hits_for("slot_nudge").is_empty(), "No-offer controls unexpectedly expose Nudge.")
	_check(surface.hits_for("slot_spin").size() == 1, "Normal Spin control is missing or duplicated.")
	_check(surface.hits_for("slot_bet").size() == SlotMachineStateScript.BET_OPTIONS.size(), "Bet controls changed.")
	_check(surface.hits_for("slot_auto_toggle").size() == 1, "Auto control is missing or duplicated.")
	state["ritual_projection"] = {"acknowledgement_available": true}
	var handpay := _render_controls(renderer, state)
	_check(handpay.hits_for("slot_handpay_acknowledge").size() == 1, "Legal handpay acknowledgement control changed.")
	_check(handpay.hits_for("slot_nudge").is_empty(), "Handpay acknowledgement exposes a Nudge control.")
	_check(handpay.all_text().contains("CALL ATTENDANT"), "Legal handpay acknowledgement label changed.")


func _check_commands_and_bindings() -> void:
	var definitions: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/games/games.json"))
	var definition: Dictionary = {}
	if typeof(definitions) == TYPE_ARRAY:
		for entry in definitions:
			if typeof(entry) == TYPE_DICTIONARY and str(entry.get("id", "")) == "slot":
				definition = entry
	_check(not definition.is_empty(), "Slot production definition could not be loaded.")
	if definition.is_empty():
		return
	var run = RunStateScript.new()
	run.start_new("SYNTHETIC-SLOT-NUDGE-LABEL-CONTRACT")
	run.bankroll = 92
	var generator = SlotMachineGeneratorScript.new()
	var machine: Dictionary = generator.build_machine_from_ids(definition, {
		"format_id": "classic_3_reel", "type_id": "pinball",
		"math_variant_id": "standard", "bonus_variant_id": "plain",
		"cabinet_variant_id": "neon_magenta",
	}, run.create_rng("synthetic_machine"))
	machine["last_payout"] = 0
	machine["last_net"] = -2
	machine["last_classification"] = "near_miss"
	# Deliberately fabricated offer: sufficient for presentation/command routing,
	# never submitted to resolution or described as the original failing save.
	machine["last_nudge_offer"] = {"type": "coin_chain", "coin_count": 1, "coins": [{"index": 0, "ready_msec": 340}], "banked_payout": 0}
	var environment := {"id": "synthetic_slot_room", "archetype_id": "bar", "kind": "casino", "game_ids": ["slot"], "game_states": {}}
	SlotMachineStateScript.write_machine(environment, "slot", machine)
	run.current_environment = environment
	var game = SlotGameScript.new()
	game.setup(definition)
	var presentation = SlotPresentationScript.new()
	var state: Dictionary = presentation.surface_state(machine, run, definition, {})
	var bindings: Dictionary = state.get("surface_action_bindings", {})
	_check(str((bindings.get("legal", {}) as Dictionary).get("action", "")) == "slot_spin", "Legal binding no longer points only to Spin.")
	_check(str((bindings.get("cheat", {}) as Dictionary).get("action", "")) == "slot_nudge", "Cheat binding no longer names Nudge.")
	for action in ["collect", "slot_collect"]:
		var command: Dictionary = game.surface_action_command(action, 0, false, {}, run, environment)
		_check(not bool(command.get("handled", false)), "%s is unexpectedly accepted as a Slot action." % action)
		_check(str(command.get("action_id", "")) != "nudge" and not bool(command.get("resolve", false)) and not bool(command.get("direct_resolve", false)), "%s can resolve the Nudge cheat." % action)
	var spin: Dictionary = game.surface_action_command("slot_spin", 0, false, {}, run, environment)
	_check(str(spin.get("action_id", "")) == "spin" and str(spin.get("action_kind", "")) == "legal", "Post-loss Spin was remapped to a cheat.")
	var nudge: Dictionary = game.surface_action_command("slot_nudge", 0, false, {}, run, environment)
	_check(str(nudge.get("action_id", "")) == "nudge" and str(nudge.get("action_kind", "")) == "cheat", "Explicit Nudge lost its cheat classification.")
	_check(run.bankroll == 92 and run.suspicion_level() == 0, "Presentation/command checks unexpectedly changed cash or Heat.")
	receipts.append({"case": "synthetic_command_bindings", "spin_action": spin.get("action_id", ""), "nudge_action": nudge.get("action_id", ""), "nudge_kind": nudge.get("action_kind", ""), "nudge_message": nudge.get("message", "")})


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
