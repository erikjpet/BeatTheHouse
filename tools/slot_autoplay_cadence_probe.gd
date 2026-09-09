extends SceneTree

# Production-host cadence gate for foreground Slot autoplay. This intentionally
# crosses FoundationMain's sealed action boundary twice: a module-only timer test
# cannot detect a retained authority session whose raw clock advances while its
# scaled presentation clock stays frozen.

const MainScene := preload("res://scenes/main.tscn")
const SlotState := preload("res://scripts/games/slots/slot_machine_state.gd")
const SlotGenerator := preload("res://scripts/games/slots/slot_machine_generator.gd")
const BuffaloFamily := preload("res://scripts/games/slots/slot_family_buffalo.gd")
const ActionAuthority := preload("res://scripts/core/blackjack_action_authority.gd")
const SAVE_SLOT := "slot_autoplay_cadence_probe"
const SIMULATED_TIME_LEAD_MSEC := 1000000

var app: Control
var failures: Array[String] = []
var evidence := {
	"ordinary": {},
	"buffalo": {},
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	app = MainScene.instantiate()
	app.set("continuous_environment_clock_enabled", false)
	app.set("autosave_slot_id", SAVE_SLOT)
	root.add_child(app)
	await _settle(3)
	if not app.call("start_foundation_run", "SLOT-AUTOPLAY-CADENCE"):
		_fail("Could not start the Slot autoplay cadence run.")
		_finish()
		return
	await _settle(3)
	var run_state: RunState = app.get("run_state")
	run_state.bankroll = 1000000
	_install_slot_room(run_state)
	app.call("_refresh_run_action_service")
	app.call("_refresh")
	if not bool(app.call("enter_game", "slot", "slot")):
		_fail("Could not enter the Slot autoplay cadence fixture.")
		_finish()
		return
	await _settle(4)
	await _check_ordinary_autoplay(run_state)
	await _check_buffalo_bonus_autoplay(run_state)
	print(JSON.stringify({
		"tool": "slot_autoplay_cadence_probe",
		"passed": failures.is_empty(),
		"failures": failures,
		"evidence": evidence,
	}, "\t"))
	_finish()


func _check_ordinary_autoplay(run_state: RunState) -> void:
	var game: GameModule = app.call("_game_module_for_id", "slot")
	var machine := _build_machine(game, run_state, "pinball", "line_5x3", "ordinary")
	machine["slot_autoplay_active"] = true
	machine["slot_autoplay_next_msec"] = 1
	_store_fresh_machine(run_state, machine)
	var first_boundary := int(app.call("_environment_simulation_time_msec")) + SIMULATED_TIME_LEAD_MSEC
	var first_command: Dictionary = app.call("_sealed_action_host_auto_intent", first_boundary)
	if str(first_command.get("action_id", "")) != "spin" or not bool(first_command.get("direct_resolve", false)):
		_fail("Ordinary autoplay did not issue its first sealed spin at the due boundary.")
		return
	_assert_command_clock("Ordinary first spin", first_command, first_boundary)
	app.call("_apply_game_surface_automation_command", first_command, _timing_state(first_boundary))
	await _settle(2)
	var first_machine := SlotState.peek_machine(run_state.current_environment, "slot")
	if int(first_machine.get("spin_count", 0)) != 1:
		_fail("Ordinary autoplay did not settle exactly one first spin.")
		return
	if bool(first_machine.get("active_bonus", {}).get("active", false)):
		_fail("Ordinary cadence fixture unexpectedly entered a feature; use a non-feature seed.")
		return
	var first_delay := int(game.call("_slot_autoplay_delay_msec", first_machine))
	var first_next := int(first_machine.get("slot_autoplay_next_msec", 0))
	var first_animation_id := str(first_machine.get("slot_animation_id", ""))
	if first_animation_id.is_empty() or first_delay < 900:
		_fail("Ordinary autoplay did not publish a normal-duration reel animation.")
	if first_next != first_boundary + first_delay:
		_fail("Ordinary autoplay scheduled its second spin from a stale clock (%d, expected %d)." % [first_next, first_boundary + first_delay])
		return
	if bool(app.call("_sealed_action_host_needs_auto_tick", first_next - 1)):
		_fail("Ordinary autoplay became due before its reel animation cadence completed.")
		return
	var early_command: Dictionary = game.surface_auto_action_command(_timing_state(first_next - 1), run_state, run_state.current_environment, {})
	if bool(early_command.get("handled", false)):
		_fail("Ordinary Slot accepted an autoplay spin before its own reel deadline.")
		return
	if not bool(app.call("_sealed_action_host_needs_auto_tick", first_next)):
		_fail("Ordinary autoplay did not become due at its complete reel cadence boundary.")
		return
	var second_command: Dictionary = app.call("_sealed_action_host_auto_intent", first_next)
	if str(second_command.get("action_id", "")) != "spin" or not bool(second_command.get("direct_resolve", false)):
		_fail("Ordinary autoplay lost its second spin because the sealed host retained an old presentation clock.")
		return
	_assert_command_clock("Ordinary second spin", second_command, first_next)
	app.call("_apply_game_surface_automation_command", second_command, _timing_state(first_next))
	await _settle(2)
	var second_machine := SlotState.peek_machine(run_state.current_environment, "slot")
	var second_delay := int(game.call("_slot_autoplay_delay_msec", second_machine))
	var second_next := int(second_machine.get("slot_autoplay_next_msec", 0))
	var second_animation_id := str(second_machine.get("slot_animation_id", ""))
	if int(second_machine.get("spin_count", 0)) != 2:
		_fail("Ordinary autoplay did not settle exactly one second spin.")
	if second_animation_id.is_empty() or second_animation_id == first_animation_id:
		_fail("Ordinary autoplay did not hand off a distinct second reel animation.")
	if second_next != first_next + second_delay:
		_fail("Ordinary autoplay did not rebase its third deadline from the second action boundary.")
	evidence["ordinary"] = {
		"first_boundary_msec": first_boundary,
		"first_delay_msec": first_delay,
		"first_next_msec": first_next,
		"second_delay_msec": second_delay,
		"second_next_msec": second_next,
		"first_animation_id": first_animation_id,
		"second_animation_id": second_animation_id,
	}


func _check_buffalo_bonus_autoplay(run_state: RunState) -> void:
	var game: GameModule = app.call("_game_module_for_id", "slot")
	var definition: Dictionary = game.get("definition")
	var machine := _build_machine(game, run_state, "buffalo", "line_5x3", "buffalo")
	var first_boundary := int(app.call("_environment_simulation_time_msec")) + SIMULATED_TIME_LEAD_MSEC * 2
	var buffalo = BuffaloFamily.new()
	var trigger := {
		"classification": "free_games",
		"forced_placement": {
			"cells": [{"reel": 0, "row": 0}, {"reel": 1, "row": 0}, {"reel": 2, "row": 0}],
		},
	}
	machine["active_bonus"] = buffalo.open_feature(machine, trigger, 10, run_state.create_rng("slot_cadence_buffalo_open"), definition)
	machine["slot_autoplay_active"] = false
	machine["slot_autoplay_next_msec"] = 0
	machine["slot_bonus_auto_next_msec"] = first_boundary
	_store_fresh_machine(run_state, machine)
	var first_command: Dictionary = app.call("_sealed_action_host_auto_intent", first_boundary)
	if str(first_command.get("action_id", "")) != "slot_bonus_launch" or not bool(first_command.get("direct_resolve", false)):
		_fail("Buffalo autoplay did not issue its first automatic feature spin.")
		return
	_assert_command_clock("Buffalo first spin", first_command, first_boundary)
	app.call("_apply_game_surface_automation_command", first_command, _timing_state(first_boundary))
	await _settle(2)
	var first_machine := SlotState.peek_machine(run_state.current_environment, "slot")
	var first_active: Dictionary = first_machine.get("active_bonus", {})
	var first_step := int(first_active.get("step_index", 0))
	var first_delay := int(game.call("_slot_bonus_auto_delay_msec", first_machine))
	var first_next := int(first_machine.get("slot_bonus_auto_next_msec", 0))
	var first_animation_id := str(first_machine.get("slot_animation_id", ""))
	if first_step != 1:
		_fail("Buffalo autoplay advanced %d feature steps instead of exactly one." % first_step)
		return
	if first_animation_id.is_empty() or first_delay < 900:
		_fail("Buffalo autoplay did not publish a normal-duration feature reel animation.")
	if first_next != first_boundary + first_delay:
		_fail("Buffalo autoplay scheduled its second feature spin from a stale clock (%d, expected %d)." % [first_next, first_boundary + first_delay])
		return
	if bool(app.call("_sealed_action_host_needs_auto_tick", first_next - 1)):
		_fail("Buffalo autoplay became due before its feature reel animation completed.")
		return
	if not bool(app.call("_sealed_action_host_needs_auto_tick", first_next)):
		_fail("Buffalo autoplay did not become due at its feature cadence boundary.")
		return
	var second_command: Dictionary = app.call("_sealed_action_host_auto_intent", first_next)
	if str(second_command.get("action_id", "")) != "slot_bonus_launch" or not bool(second_command.get("direct_resolve", false)):
		_fail("Buffalo autoplay lost its second feature spin because the sealed host retained an old presentation clock.")
		return
	_assert_command_clock("Buffalo second spin", second_command, first_next)
	app.call("_apply_game_surface_automation_command", second_command, _timing_state(first_next))
	await _settle(2)
	var second_machine := SlotState.peek_machine(run_state.current_environment, "slot")
	var second_active: Dictionary = second_machine.get("active_bonus", {})
	var second_step := int(second_active.get("step_index", 0))
	var second_delay := int(game.call("_slot_bonus_auto_delay_msec", second_machine))
	var second_next := int(second_machine.get("slot_bonus_auto_next_msec", 0))
	var second_animation_id := str(second_machine.get("slot_animation_id", ""))
	if second_step != first_step + 1:
		_fail("Buffalo autoplay did not advance exactly one second feature step (%d -> %d)." % [first_step, second_step])
	if second_animation_id.is_empty() or second_animation_id == first_animation_id:
		_fail("Buffalo autoplay did not hand off a distinct second feature animation.")
	if second_next != first_next + second_delay:
		_fail("Buffalo autoplay did not rebase its third feature deadline from the second action boundary.")
	evidence["buffalo"] = {
		"first_boundary_msec": first_boundary,
		"first_step": first_step,
		"first_delay_msec": first_delay,
		"first_next_msec": first_next,
		"second_step": second_step,
		"second_delay_msec": second_delay,
		"second_next_msec": second_next,
		"first_animation_id": first_animation_id,
		"second_animation_id": second_animation_id,
	}


func _install_slot_room(run_state: RunState) -> void:
	var game: GameModule = app.call("_game_module_for_id", "slot")
	var environment := {
		"id": "slot_autoplay_cadence_room",
		"archetype_id": "grand_casino",
		"display_name": "Slot Autoplay Cadence",
		"kind": "casino",
		"tier": 3,
		"turns": 0,
		"game_ids": ["slot"],
		"event_ids": [],
		"resolved_event_ids": [],
		"item_offers": [],
		"service_ids": [],
		"lender_hooks": [],
		"travel_hooks": [],
		"next_archetypes": [],
		"object_fixtures": [],
		"layout": {"game_fixture_counts": {"slot": 1}},
		"game_states": {},
	}
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)
	environment["game_states"] = game.generate_environment_fixture_states(
		run_state,
		environment,
		run_state.create_rng("slot_autoplay_cadence_fixture"),
		1
	)
	run_state.set_environment(environment)


func _build_machine(game: GameModule, run_state: RunState, family_id: String, format_id: String, salt: String) -> Dictionary:
	var definition: Dictionary = game.get("definition")
	var generator = SlotGenerator.new()
	var machine: Dictionary = generator.build_machine_from_ids(definition, {
		"format_id": format_id,
		"type_id": family_id,
		"math_variant_id": "standard",
		"bonus_variant_id": "plain",
		"cabinet_variant_id": "neon_magenta",
	}, run_state.create_rng("slot_autoplay_cadence_%s" % salt))
	return SlotState.set_selected_bet(machine, "bet_2")


func _store_fresh_machine(run_state: RunState, machine: Dictionary) -> void:
	machine.erase(ActionAuthority.LEDGER_KEY)
	machine.erase(ActionAuthority.PENDING_APPLY_RECEIPT_KEY)
	SlotState.write_machine(run_state.current_environment, "slot", machine)


func _timing_state(surface_time_msec: int) -> Dictionary:
	return {
		"surface_time_msec": surface_time_msec,
		"drunk_scaled_surface_time_msec": surface_time_msec,
	}


func _assert_command_clock(label: String, command: Dictionary, expected_msec: int) -> void:
	var ui_state: Dictionary = command.get("ui_state", {}) if typeof(command.get("ui_state", {})) == TYPE_DICTIONARY else {}
	if int(ui_state.get("surface_time_msec", -1)) != expected_msec \
			or int(ui_state.get("drunk_scaled_surface_time_msec", -1)) != expected_msec:
		_fail("%s did not receive one fresh unified host clock." % label)


func _settle(frame_count: int) -> void:
	for _index in range(maxi(0, frame_count)):
		await process_frame


func _fail(message: String) -> void:
	failures.append(message)


func _finish() -> void:
	if app != null:
		var save_service: SaveService = app.get("save_service")
		if save_service != null:
			save_service.clear_run(SAVE_SLOT)
		app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
