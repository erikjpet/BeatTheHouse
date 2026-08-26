extends RefCounted

# Opening a game is navigation. Every production activation presentation must
# be observational; persistent changes belong to a resolved player action.

const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const GameSurfaceCanvasScript := preload("res://scripts/ui/game_surface_canvas.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")

const SEED_COUNT := 10
const ACTIVATION_METHODS := [
	"environment_runtime_state",
	"environment_object_state",
	"environment_interactable_objects",
	"enter",
	"actions",
	"surface_state",
	"coach_state",
]


class MutatingActivationFixture:
	extends GameModule

	var mutating_method := ""

	func _mutate(run_state: RunState, method: String) -> void:
		if mutating_method == method:
			run_state.narrative_flags["game_activation_fixture_%s" % method] = true

	func environment_runtime_state(run_state: RunState, environment: Dictionary) -> Dictionary:
		_mutate(run_state, "environment_runtime_state")
		return super.environment_runtime_state(run_state, environment)

	func environment_object_state(run_state: RunState, environment: Dictionary) -> Dictionary:
		_mutate(run_state, "environment_object_state")
		return super.environment_object_state(run_state, environment)

	func environment_interactable_objects(run_state: RunState, environment: Dictionary) -> Array:
		_mutate(run_state, "environment_interactable_objects")
		return super.environment_interactable_objects(run_state, environment)

	func enter(run_state: RunState, environment: Dictionary) -> Dictionary:
		_mutate(run_state, "enter")
		return super.enter(run_state, environment)

	func actions(run_state: RunState, environment: Dictionary) -> Dictionary:
		_mutate(run_state, "actions")
		return super.actions(run_state, environment)

	func surface_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
		_mutate(run_state, "surface_state")
		return super.surface_state(run_state, environment, ui_state)

	func coach_state(run_state: RunState, environment: Dictionary, ui_state: Dictionary = {}) -> Dictionary:
		_mutate(run_state, "coach_state")
		return super.coach_state(run_state, environment, ui_state)


class MaskingActivationFixture:
	extends GameModule

	func environment_runtime_state(run_state: RunState, environment: Dictionary) -> Dictionary:
		# This cache is intentionally absent from RunState serialization. Sharing a
		# live fixture across hooks would carry it into the next assertion.
		run_state.set_meta("activation_mask", true)
		return super.environment_runtime_state(run_state, environment)

	func environment_object_state(run_state: RunState, environment: Dictionary) -> Dictionary:
		if not run_state.has_meta("activation_mask"):
			run_state.narrative_flags["game_activation_fixture_masked_object"] = true
		return super.environment_object_state(run_state, environment)


class ByteRepresentationActivationFixture:
	extends GameModule

	func environment_object_state(run_state: RunState, environment: Dictionary) -> Dictionary:
		if run_state.narrative_flags.has("game_activation_numeric_representation"):
			# GDScript considers 0.0 == 0, while JSON emits float 0.0 and integer 0
			# distinctly. Recursive semantic equality therefore misses this mutation.
			run_state.narrative_flags["game_activation_numeric_representation"] = 0
		return super.environment_object_state(run_state, environment)


class SourceAliasProbeFixture:
	extends GameModule

	func environment_object_state(run_state: RunState, environment: Dictionary) -> Dictionary:
		var payload_value: Variant = run_state.narrative_flags.get("game_activation_source_alias_probe", {})
		if typeof(payload_value) == TYPE_DICTIONARY:
			var nested_value: Variant = (payload_value as Dictionary).get("entries", [])
			if typeof(nested_value) == TYPE_ARRAY and not (nested_value as Array).is_empty() and typeof((nested_value as Array)[0]) == TYPE_DICTIONARY:
				((nested_value as Array)[0] as Dictionary)["value"] = "mutated-through-alias"
		# Restore the live serialized graph exactly. If from_dict received the
		# canonical dictionary directly, only that source retains the hostile write.
		run_state.narrative_flags["game_activation_source_alias_probe"] = {
			"entries": [{"value": "original"}],
		}
		return super.environment_object_state(run_state, environment)


static func check(library: ContentLibrary, failures: Array) -> void:
	var covered_game_ids := {}
	var checked_contexts := {}
	_check_generated_environment_sweep(library, covered_game_ids, checked_contexts, failures)
	_check_catalog_coverage(library, covered_game_ids, failures)
	_check_portable_ticket_readonly_isolation(library, failures)
	_check_saved_slot_checkpoint_activation(library, failures)
	_check_staff_rollover_presentation(library, failures)
	_check_reintroduced_defect_fixture(failures)


static func _check_generated_environment_sweep(library: ContentLibrary, covered_game_ids: Dictionary, checked_contexts: Dictionary, failures: Array) -> void:
	var generator := RunGeneratorScript.new(library)
	var repeated_coin_pusher_states := {}
	for seed_index in range(SEED_COUNT):
		for archetype_value in library.environment_archetypes:
			if typeof(archetype_value) != TYPE_DICTIONARY:
				continue
			var archetype := archetype_value as Dictionary
			var archetype_id := str(archetype.get("id", "")).strip_edges()
			var scenarios: Array = [{}]
			if seed_index == 0:
				scenarios.append_array(library.scenarios_for_archetype(archetype_id))
			for scenario_value in scenarios:
				var scenario := _dict(scenario_value)
				var scenario_id := str(scenario.get("id", "baseline"))
				var run_state := RunStateScript.new()
				run_state.start_new("GAME-ACTIVATION-%02d-%s-%s" % [seed_index, archetype_id, scenario_id])
				var environment := EnvironmentInstanceScript.from_archetype(
					archetype,
					int(archetype.get("tier", 1)),
					run_state.create_rng("generated_environment"),
					library,
					{},
					scenario
				).to_dict()
				environment["game_states"] = _generated_game_states_for_activation_guard(
					generator,
					run_state,
					environment,
					run_state.create_rng("generated_game_states"),
					repeated_coin_pusher_states,
					seed_index > 0,
					scenario_id
				)
				run_state.set_environment(environment)
				var fixture_label := "%s/%s/seed-%02d" % [archetype_id, scenario_id, seed_index]
				var parsed_snapshot := _json_round_trip_snapshot(run_state, fixture_label, failures)
				if parsed_snapshot.is_empty():
					continue
				var parsed_environment := _dict(parsed_snapshot.get("current_environment", {}))
				_record_environment_catalog_coverage(parsed_environment, covered_game_ids)
				var layered := int(parsed_environment.get("environment_layer_schema_version", 0)) > 0 and not str(parsed_environment.get("current_layer_id", "")).strip_edges().is_empty()
				# Repeated seed fixtures still cross the JSON codec and contribute catalog
				# coverage. If they add no game/state-key context and have no layers to
				# traverse, constructing a live RunState cannot add another assertion.
				if not layered and not _environment_has_unchecked_context(parsed_environment, scenario_id, checked_contexts):
					continue
				var restored_run := _run_state_from_parsed_snapshot(parsed_snapshot)
				if restored_run == null:
					failures.append("Game activation class guard could not restore %s." % fixture_label)
					continue
				run_state = restored_run
				_check_environment(library, run_state, scenario_id, covered_game_ids, checked_contexts, failures)
				if run_state.is_layered_environment():
					_enter_and_check_remaining_layers(library, generator, run_state, scenario_id, covered_game_ids, checked_contexts, failures)


static func _generated_game_states_for_activation_guard(generator: RunGenerator, run_state: RunState, environment: Dictionary, rng: RngStream, repeated_coin_pusher_states: Dictionary, allow_reuse: bool, scenario_id: String) -> Dictionary:
	var game_ids := _string_array(environment.get("game_ids", []))
	if not game_ids.has("coin_pusher"):
		return generator._generated_game_states(run_state, environment, rng)
	var fixture_counts := _dict(_dict(environment.get("layout", {})).get("game_fixture_counts", {}))
	var cache_key := "%s|%s|%s|%d" % [
		str(environment.get("archetype_id", "")),
		str(environment.get("current_layer_id", "base")),
		scenario_id,
		maxi(1, int(fixture_counts.get("coin_pusher", 1))),
	]
	if allow_reuse and repeated_coin_pusher_states.has(cache_key):
		# Repeated seeds still construct and JSON-round-trip all 235 generated
		# environment contexts. Once this exact archetype/layer/scenario fixture has
		# covered Coin Pusher, reuse only its immutable generated state so physical
		# opening settlement is not redundantly recomputed nine more times. Other
		# games retain their seed-specific production generation and every checked
		# activation hook still receives an independent cold RunState.
		var generation_environment := environment.duplicate(true)
		var remaining_game_ids := game_ids.duplicate()
		remaining_game_ids.erase("coin_pusher")
		generation_environment["game_ids"] = remaining_game_ids
		var reused_states: Dictionary = generator._generated_game_states(run_state, generation_environment, rng)
		for state_key in _dict(repeated_coin_pusher_states[cache_key]):
			reused_states[state_key] = _dict(repeated_coin_pusher_states[cache_key])[state_key].duplicate(true)
		return reused_states
	var generated_states: Dictionary = generator._generated_game_states(run_state, environment, rng)
	var coin_pusher_states := {}
	for state_key_value in generated_states:
		var state_key := str(state_key_value)
		if state_key == "coin_pusher" or state_key.begins_with("coin_pusher:"):
			coin_pusher_states[state_key] = _dict(generated_states[state_key]).duplicate(true)
	if not coin_pusher_states.is_empty():
		repeated_coin_pusher_states[cache_key] = coin_pusher_states
	return generated_states


static func _enter_and_check_remaining_layers(library: ContentLibrary, generator: RunGenerator, run_state: RunState, scenario_id: String, covered_game_ids: Dictionary, checked_contexts: Dictionary, failures: Array) -> void:
	var remaining := _string_array(run_state.current_environment.get("layer_ids", []))
	remaining.erase(str(run_state.current_environment.get("current_layer_id", "")))
	while not remaining.is_empty():
		var entered := false
		for transition_value in _array(run_state.current_environment.get("layer_transitions", [])):
			if typeof(transition_value) != TYPE_DICTIONARY:
				continue
			var target_layer_id := str((transition_value as Dictionary).get("target_layer_id", "")).strip_edges()
			if not remaining.has(target_layer_id):
				continue
			run_state.discover_environment_layer(target_layer_id, "game_activation_class_guard")
			var result := generator.enter_environment_layer(run_state, target_layer_id, false)
			if not bool(result.get("ok", false)):
				failures.append("Game activation class guard could not enter layer %s: %s" % [target_layer_id, str(result.get("message", "unknown failure"))])
				return
			var restored_run := _json_round_trip_run_state(run_state, "%s/%s" % [scenario_id, target_layer_id], failures)
			if restored_run == null:
				return
			run_state = restored_run
			remaining.erase(target_layer_id)
			entered = true
			_check_environment(library, run_state, scenario_id, covered_game_ids, checked_contexts, failures)
			break
		if not entered:
			failures.append("Game activation class guard could not reach generated layers %s." % JSON.stringify(remaining))
			return


static func _check_environment(library: ContentLibrary, source_run: RunState, scenario_id: String, covered_game_ids: Dictionary, checked_contexts: Dictionary, failures: Array) -> void:
	var environment := source_run.current_environment
	var archetype_id := str(environment.get("archetype_id", ""))
	var layer_id := str(environment.get("current_layer_id", "base"))
	# Every checked context in this environment starts from the same cold-restored
	# run. Build its canonical representation lazily: most later seed contexts are
	# already covered, so eagerly encoding them would add work without assertions.
	var source_snapshot: Dictionary = {}
	var source_text := ""
	var cold_source: Dictionary = {}
	var cold_source_text := ""
	for game_id_value in _string_array(environment.get("game_ids", [])):
		var game_id := str(game_id_value)
		covered_game_ids[game_id] = true
		for state_key_value in _generated_state_keys(environment, game_id):
			var state_key := str(state_key_value)
			var context_key := "%s|%s|%s|%s|%s" % [game_id, state_key, archetype_id, layer_id, scenario_id]
			if checked_contexts.has(context_key):
				continue
			checked_contexts[context_key] = true
			if source_snapshot.is_empty():
				source_snapshot = source_run.to_dict()
				source_text = JSON.stringify(source_snapshot)
				var parsed_source: Variant = JSON.parse_string(source_text)
				if typeof(parsed_source) == TYPE_DICTIONARY:
					cold_source = parsed_source as Dictionary
					cold_source_text = JSON.stringify(cold_source)
			var game := _load_game(library, game_id, failures)
			if game == null:
				continue
			# This is the same transient seam used by FoundationMain when a player
			# opens a non-default generated fixture. It must select presentation
			# without recording that selection in the serialized environment.
			game.set_transient_state_key_context(state_key)
			var violation := _activation_violation(game, source_run, source_snapshot, source_text, cold_source, cold_source_text)
			game.set_transient_state_key_context("")
			if not violation.is_empty():
				failures.append("Game activation mutated serialized RunState for %s (%s) in %s/%s/%s: %s" % [game_id, state_key, archetype_id, layer_id, scenario_id, violation])


static func _record_environment_catalog_coverage(environment: Dictionary, covered_game_ids: Dictionary) -> void:
	for game_id_value in _string_array(environment.get("game_ids", [])):
		covered_game_ids[str(game_id_value)] = true


static func _environment_has_unchecked_context(environment: Dictionary, scenario_id: String, checked_contexts: Dictionary) -> bool:
	var archetype_id := str(environment.get("archetype_id", ""))
	var layer_id := str(environment.get("current_layer_id", "base"))
	for game_id_value in _string_array(environment.get("game_ids", [])):
		var game_id := str(game_id_value)
		for state_key_value in _generated_state_keys(environment, game_id):
			var context_key := "%s|%s|%s|%s|%s" % [game_id, str(state_key_value), archetype_id, layer_id, scenario_id]
			if not checked_contexts.has(context_key):
				return true
	return false


static func _check_catalog_coverage(library: ContentLibrary, covered_game_ids: Dictionary, failures: Array) -> void:
	for definition_value in library.games:
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition := definition_value as Dictionary
		var game_id := str(definition.get("id", "")).strip_edges()
		var module_path := str(definition.get("module_path", "")).strip_edges()
		if game_id.is_empty() or module_path.is_empty() or module_path.ends_with("_ui.gd") or module_path.begins_with("res://data/runtime/"):
			continue
		if not covered_game_ids.has(game_id):
			failures.append("Game activation class guard never reached production game %s in generated environments." % game_id)


static func _check_portable_ticket_readonly_isolation(library: ContentLibrary, failures: Array) -> void:
	var scratch_game := _load_game(library, "scratch_tickets", failures)
	if scratch_game != null:
		var scratch_run := RunStateScript.new()
		scratch_run.start_new("GAME-ACTIVATION-STALE-SCRATCH")
		var scratch_environment := {
			"id": "activation_stale_scratch",
			"world_node_id": "activation_stale_scratch_node",
			"archetype_id": "gas_station_casino",
			"display_name": "Stale Scratch Fixture",
			"kind": "casino",
			"tier": 1,
			"game_ids": ["scratch_tickets"],
			"game_states": {},
		}
		scratch_environment["game_states"] = {
			"scratch_tickets": scratch_game.generate_environment_state(
				scratch_run,
				scratch_environment,
				scratch_run.create_rng("stale_scratch_machine")
			),
		}
		scratch_run.set_environment(scratch_environment)
		var stale_ticket: Dictionary = scratch_game.call(
			"_roll_ticket",
			scratch_game.call("_ticket_type", "two_fer"),
			scratch_run.create_rng("stale_scratch_ticket"),
			0,
			"stale",
			false
		)
		stale_ticket["region_layout_version"] = 0
		stale_ticket["scratch_regions"] = []
		stale_ticket["latex_mask"] = []
		scratch_run.remember_portable_ticket_state("scratch_tickets", scratch_run.current_environment, {"active_ticket": stale_ticket})
		scratch_run = _json_round_trip_run_state(scratch_run, "hostile stale scratch active-ticket fixture", failures)
		if scratch_run != null:
			var scratch_before := JSON.stringify(scratch_run.to_dict())
			var scratch_violation := _activation_violation(scratch_game, scratch_run)
			if not scratch_violation.is_empty() or JSON.stringify(scratch_run.to_dict()) != scratch_before:
				failures.append("Scratch Tickets passive normalization aliased its cold-restored portable active ticket: %s" % scratch_violation)

	var pull_game := _load_game(library, "pull_tabs", failures)
	if pull_game != null:
		var pull_run := RunStateScript.new()
		pull_run.start_new("GAME-ACTIVATION-PORTABLE-PULL-TABS")
		var pull_environment := {
			"id": "activation_portable_pull_tabs",
			"world_node_id": "activation_portable_pull_tabs_node",
			"archetype_id": "jazz_club",
			"display_name": "Portable Pull Tab Fixture",
			"kind": "bar",
			"tier": 1,
			"game_ids": ["pull_tabs"],
			"game_states": {},
		}
		pull_environment["game_states"] = {
			"pull_tabs": pull_game.generate_environment_state(
				pull_run,
				pull_environment,
				pull_run.create_rng("portable_pull_machine")
			),
		}
		pull_run.set_environment(pull_environment)
		pull_run.remember_portable_ticket_state("pull_tabs", pull_run.current_environment, {
			"ticket_stack": [{"id": "hostile-portable-tab", "windows": [{"revealed": false}]}],
		})
		pull_run = _json_round_trip_run_state(pull_run, "hostile portable pull-tab fixture", failures)
		if pull_run != null:
			var pull_before := JSON.stringify(pull_run.to_dict())
			var preview: Dictionary = pull_game.call("_ensure_machine_state", pull_run, pull_run.current_environment, false)
			var preview_stack_value: Variant = preview.get("ticket_stack", [])
			var preview_stack: Array = preview_stack_value as Array if typeof(preview_stack_value) == TYPE_ARRAY else []
			if not preview_stack.is_empty() and typeof(preview_stack[0]) == TYPE_DICTIONARY:
				(preview_stack[0] as Dictionary)["hostile_preview_mutation"] = true
			if JSON.stringify(pull_run.to_dict()) != pull_before:
				failures.append("Pull Tabs passive merge exposed live portable ticket dictionaries to its preview copy.")


static func _check_saved_slot_checkpoint_activation(library: ContentLibrary, failures: Array) -> void:
	var slot_game := _load_game(library, "slot", failures)
	if slot_game == null:
		return
	var run_state := RunStateScript.new()
	run_state.start_new("GAME-ACTIVATION-SAVED-SLOT-CHECKPOINT")
	run_state.bankroll = 1000
	var environment := {
		"id": "activation_saved_slot_checkpoint",
		"world_node_id": "activation_saved_slot_checkpoint_node",
		"archetype_id": RunState.GRAND_CASINO_ARCHETYPE_ID,
		"display_name": "Saved Slot Checkpoint Fixture",
		"kind": "boss",
		"tier": 3,
		"game_ids": ["slot"],
		"game_states": {},
	}
	var states: Dictionary = slot_game.generate_environment_fixture_states(
		run_state,
		environment,
		run_state.create_rng("saved_slot_checkpoint_fixtures"),
		3
	)
	var state_key := "slot:2"
	var machine := _dict(states.get(state_key, {}))
	if machine.is_empty():
		failures.append("Game activation saved-slot guard did not generate non-default fixture slot:2.")
		return
	machine["slot_animation_id"] = "saved-slot-checkpoint"
	machine["slot_animation_duration_msec"] = 3000
	machine["slot_animation_started_msec"] = 0
	machine["slot_animation_resume_elapsed_msec"] = 1250
	machine["slot_animation_plan"] = {
		"id": "saved-slot-checkpoint",
		"duration_msec": 3000,
		"reel_timeline": [{"reel": 0, "stop_time": 1.0}],
	}
	states[state_key] = machine
	environment["game_states"] = states
	run_state.set_environment(environment)
	run_state = _json_round_trip_run_state(run_state, "saved non-default slot checkpoint fixture", failures)
	if run_state == null:
		return
	slot_game.set_transient_state_key_context(state_key)
	var source_text := JSON.stringify(run_state.to_dict())
	var violation := _activation_violation(slot_game, run_state)
	if not violation.is_empty() or JSON.stringify(run_state.to_dict()) != source_text:
		failures.append("Saved non-default slot checkpoint changed during passive activation: %s" % violation)
	var surface := slot_game.surface_state(run_state, run_state.current_environment, {
		"surface_time_msec": 10000,
		"drunk_scaled_surface_time_msec": 10000,
	})
	var spin_channel := _animation_channel(surface, "slot_spin")
	if int(spin_channel.get("elapsed_offset_msec", -1)) != 1250 \
			or int(spin_channel.get("started_msec", -1)) != 0:
		failures.append("Saved non-default slot checkpoint did not project its resume offset into transient surface state.")
	if JSON.stringify(run_state.to_dict()) != source_text:
		failures.append("Saved non-default slot checkpoint surface projection mutated durable RunState.")

	var opened := RunStateScript.new()
	opened.from_dict(run_state.to_dict().duplicate(true))
	var direct := RunStateScript.new()
	direct.from_dict(run_state.to_dict().duplicate(true))
	var opened_before := JSON.stringify(opened.to_dict())
	slot_game.enter(opened, opened.current_environment)
	if JSON.stringify(opened.to_dict()) != opened_before:
		failures.append("Saved non-default slot checkpoint enter was not byte-exact before play.")
	var opened_surface := slot_game.surface_state(opened, opened.current_environment, {
		"surface_time_msec": 10000,
		"drunk_scaled_surface_time_msec": 10000,
	})
	var opened_canvas: Control = GameSurfaceCanvasScript.new()
	opened_canvas.call("render_game_snapshot", opened_surface)
	opened_canvas.call("surface_runtime_status")
	opened_canvas.free()
	if JSON.stringify(opened.to_dict()) != opened_before:
		failures.append("Saved non-default slot checkpoint open-and-render was not byte-exact before play.")
	var action_ui := {"surface_time_msec": 12000, "drunk_scaled_surface_time_msec": 12000}
	var opened_result := slot_game.resolve_with_context("spin", 0, opened, opened.current_environment, opened.create_rng("saved_slot_open_play"), action_ui)
	var direct_result := slot_game.resolve_with_context("spin", 0, direct, direct.current_environment, direct.create_rng("saved_slot_open_play"), action_ui)
	if JSON.stringify(opened_result) != JSON.stringify(direct_result) \
			or JSON.stringify(opened.to_dict()) != JSON.stringify(direct.to_dict()):
		failures.append("Saved non-default slot checkpoint open-then-play diverged from direct play.")
	slot_game.set_transient_state_key_context("")


static func _animation_channel(surface: Dictionary, channel_id: String) -> Dictionary:
	for channel_value in _array(surface.get("surface_animation_channels", [])):
		if typeof(channel_value) == TYPE_DICTIONARY and str((channel_value as Dictionary).get("id", "")) == channel_id:
			return (channel_value as Dictionary).duplicate(true)
	return {}


static func _check_staff_rollover_presentation(library: ContentLibrary, failures: Array) -> void:
	var archetype := library.environment_archetype("grand_casino")
	if archetype.is_empty():
		failures.append("Game activation class guard could not resolve the Grand Casino rollover fixture.")
		return
	var run_state := RunStateScript.new()
	run_state.start_new("GAME-ACTIVATION-STAFF-ROLLOVER")
	var environment := EnvironmentInstanceScript.from_archetype(
		archetype,
		int(archetype.get("tier", 3)),
		run_state.create_rng("staff_rollover_environment"),
		library
	).to_dict()
	var generator := RunGeneratorScript.new(library)
	environment["game_states"] = generator._generated_game_states(
		run_state,
		environment,
		run_state.create_rng("staff_rollover_game_states")
	)
	run_state.set_environment(environment)
	run_state = _json_round_trip_run_state(run_state, "Grand Casino staff rollover fixture", failures)
	if run_state == null:
		return
	run_state.advance_game_clock_minutes(1440)
	# Keep each action-boundary proof comfortably funded; this fixture is about
	# staff persistence, not wager rejection.
	run_state.bankroll = 1000
	run_state.grand_casino_chips = 1000
	var staffing := run_state.grand_casino_staffing_snapshot()
	var rollover_day := run_state.game_day()
	if int(staffing.get("day", 0)) != rollover_day:
		failures.append("Grand Casino staffing did not advance to the real game-clock rollover day.")
	var assignments := _dict(staffing.get("assignments", {}))
	for role in ["blackjack", "baccarat", "roulette", "bartender"]:
		if not assignments.has(role):
			failures.append("Grand Casino %s staffing assignment was missing after the real rollover." % role)
			continue
		var assignment := _dict(assignments.get(role, {}))
		if int(assignment.get("day", 0)) != rollover_day:
			failures.append("Grand Casino %s staffing assignment did not retain the real rollover day." % role)

	var rollover_snapshot := run_state.to_dict()
	for game_id in ["blackjack", "roulette", "bar_dice", "baccarat"]:
		var game := _load_game(library, game_id, failures)
		if game == null:
			continue
		var method_run := RunStateScript.new()
		method_run.from_dict(rollover_snapshot.duplicate(true))
		# from_dict() canonicalizes derived economy/rival fields. As in the main
		# activation sweep, that restored representation is the byte baseline.
		var passive_before := method_run.to_dict()
		var passive_before_text := JSON.stringify(passive_before)
		game.environment_object_state(method_run, method_run.current_environment)
		if JSON.stringify(method_run.to_dict()) != passive_before_text:
			var paths: Array = []
			_collect_changed_paths(passive_before, method_run.to_dict(), "", paths)
			failures.append("Grand Casino %s passive presentation mutated serialized state after a real staff rollover: %s" % [game_id, ", ".join(paths)])
			continue
		_commit_staff_action_boundary(game_id, game, method_run)
		var role_id: String = "bartender" if game_id == "bar_dice" else game_id
		var expected_assignment := _dict(assignments.get(role_id, {}))
		var game_states := _dict(method_run.current_environment.get("game_states", {}))
		var persisted_table := _dict(game_states.get(game_id, {}))
		if persisted_table.is_empty():
			failures.append("Grand Casino %s real action boundary did not retain its generated game state." % game_id)
			continue
		if int(persisted_table.get("staff_assignment_day", 0)) != rollover_day \
				or str(persisted_table.get("staff_assignment_id", "")) != str(expected_assignment.get("id", "")):
			failures.append("Grand Casino %s real action boundary did not persist rollover staff %s on day %d." % [game_id, str(expected_assignment.get("id", "")), rollover_day])


static func _commit_staff_action_boundary(game_id: String, game: GameModule, run_state: RunState) -> void:
	var environment := run_state.current_environment
	var rng := run_state.create_rng("staff_rollover_action:%s" % game_id)
	match game_id:
		"blackjack":
			game.resolve_with_context("blackjack_place_bet", 10, run_state, environment, rng, {})
		"roulette":
			game.resolve_with_context("spin_roulette", 10, run_state, environment, rng, {"roulette_bets": [game.call("_default_smoke_bet", 10)]})
		"bar_dice":
			var roll_command := game.surface_action_command("bar_dice_roll", 0, false, {}, run_state, environment)
			game.resolve_with_context("roll", 10, run_state, environment, rng, _dict(roll_command.get("ui_state", {})))
		"baccarat":
			game.resolve_with_context("deal_baccarat", 20, run_state, environment, rng, {"baccarat_bets": {"player": 20}})


static func _check_reintroduced_defect_fixture(failures: Array) -> void:
	var environment := {
		"id": "game_activation_fixture_environment",
		"archetype_id": "fixture",
		"kind": "casino",
		"tier": 1,
		"game_ids": ["game_activation_fixture"],
		"game_states": {},
	}
	var clean_run := RunStateScript.new()
	clean_run.start_new("GAME-ACTIVATION-CLEAN-FIXTURE")
	clean_run.set_environment(environment)
	clean_run = _json_round_trip_run_state(clean_run, "clean negative-control fixture", failures)
	if clean_run == null:
		return
	var clean_game := GameModule.new()
	clean_game.setup({"id": "game_activation_fixture", "display_name": "Activation Fixture", "legal_actions": [], "cheat_actions": []})
	var clean_violation := _activation_violation(clean_game, clean_run)
	if not clean_violation.is_empty():
		failures.append("Clean game activation fixture unexpectedly mutated RunState: %s" % clean_violation)

	for method in ACTIVATION_METHODS:
		var broken_run := RunStateScript.new()
		broken_run.start_new("GAME-ACTIVATION-BROKEN-%s-FIXTURE" % method)
		broken_run.set_environment(environment)
		broken_run = _json_round_trip_run_state(broken_run, "%s negative fixture" % method, failures)
		if broken_run == null:
			continue
		var broken_game := MutatingActivationFixture.new()
		broken_game.mutating_method = method
		broken_game.setup({"id": "game_activation_fixture", "display_name": "Activation Fixture", "legal_actions": [], "cheat_actions": []})
		var defect_violation := _activation_violation(broken_game, broken_run)
		var expected_path := "narrative_flags.game_activation_fixture_%s" % method
		if defect_violation.find("%s changed" % method) == -1 or defect_violation.find(expected_path) == -1:
			failures.append("Game activation class guard did not detect the reintroduced mutate-on-%s fixture: %s" % [method, defect_violation])

	var masking_run := RunStateScript.new()
	masking_run.start_new("GAME-ACTIVATION-NONSERIALIZED-MASK-FIXTURE")
	masking_run.set_environment(environment)
	masking_run = _json_round_trip_run_state(masking_run, "nonserialized masking negative fixture", failures)
	if masking_run != null:
		var masking_game := MaskingActivationFixture.new()
		masking_game.setup({"id": "game_activation_fixture", "display_name": "Activation Fixture", "legal_actions": [], "cheat_actions": []})
		var masking_violation := _activation_violation(masking_game, masking_run)
		if masking_violation.find("environment_object_state changed") == -1 or masking_violation.find("narrative_flags.game_activation_fixture_masked_object") == -1:
			failures.append("Game activation class guard let nonserialized state from one hook mask a later mutation: %s" % masking_violation)

	var byte_representation_run := RunStateScript.new()
	byte_representation_run.start_new("GAME-ACTIVATION-BYTE-REPRESENTATION-FIXTURE")
	byte_representation_run.set_environment(environment)
	byte_representation_run.narrative_flags["game_activation_numeric_representation"] = 0.0
	byte_representation_run = _json_round_trip_run_state(byte_representation_run, "numeric byte-representation negative fixture", failures)
	if byte_representation_run != null:
		var cold_numeric_value: Variant = byte_representation_run.narrative_flags.get("game_activation_numeric_representation")
		var cold_numeric_text := JSON.stringify({"value": cold_numeric_value})
		if typeof(cold_numeric_value) != TYPE_FLOAT or cold_numeric_text != "{\"value\":0.0}":
			failures.append("Game activation byte-representation fixture did not survive cold restore as canonical float 0.0: %s" % cold_numeric_text)
		else:
			var byte_representation_game := ByteRepresentationActivationFixture.new()
			byte_representation_game.setup({"id": "game_activation_fixture", "display_name": "Activation Fixture", "legal_actions": [], "cheat_actions": []})
			var byte_representation_violation := _activation_violation(byte_representation_game, byte_representation_run)
			if byte_representation_violation.find("environment_object_state changed canonical byte order/type changed") == -1:
				failures.append("Game activation class guard did not detect a semantic-equal JSON-byte representation mutation: %s" % byte_representation_violation)

	var source_alias_run := RunStateScript.new()
	source_alias_run.start_new("GAME-ACTIVATION-SOURCE-ALIAS-FIXTURE")
	source_alias_run.set_environment(environment)
	source_alias_run.narrative_flags["game_activation_source_alias_probe"] = {
		"entries": [{"value": "original"}],
	}
	source_alias_run = _json_round_trip_run_state(source_alias_run, "source-alias isolation fixture", failures)
	if source_alias_run != null:
		var source_alias_game := SourceAliasProbeFixture.new()
		source_alias_game.setup({"id": "game_activation_fixture", "display_name": "Activation Fixture", "legal_actions": [], "cheat_actions": []})
		var source_alias_violation := _activation_violation(source_alias_game, source_alias_run)
		if not source_alias_violation.is_empty():
			failures.append("Game activation class guard did not isolate its immutable parsed source from live hook state: %s" % source_alias_violation)


static func _activation_violation(game: GameModule, run_state: RunState, cached_source_snapshot: Dictionary = {}, cached_source_text: String = "", cached_cold_source: Dictionary = {}, cached_cold_source_text: String = "") -> String:
	var source_snapshot := cached_source_snapshot if not cached_source_snapshot.is_empty() else run_state.to_dict()
	var source_text := cached_source_text if not cached_source_text.is_empty() else JSON.stringify(source_snapshot)
	# Parse the canonical bytes once. Every hook restores from this immutable
	# dictionary, so hooks remain isolated without seven repeated JSON parses.
	var cold_source := cached_cold_source
	if cold_source.is_empty():
		var cold_source_value: Variant = JSON.parse_string(source_text)
		if typeof(cold_source_value) != TYPE_DICTIONARY:
			return "could not parse canonical activation fixture"
		cold_source = cold_source_value as Dictionary
	# JSON parsing may normalize representation details that RunState.to_dict()
	# later canonicalizes back to source_text. Preserve the parser's own exact
	# baseline solely for detecting retained-reference writes into cold_source.
	var cold_source_text := cached_cold_source_text if not cached_cold_source_text.is_empty() else JSON.stringify(cold_source)
	# Validate one pristine cold clone exactly. RunState.from_dict retains some
	# nested references, so every live fixture receives its own deep source copy;
	# hooks never share state with each other or with the canonical dictionary.
	var first_method_run := RunStateScript.new()
	first_method_run.from_dict(cold_source.duplicate(true))
	var canonical_snapshot := first_method_run.to_dict()
	var canonical_text := JSON.stringify(canonical_snapshot)
	if canonical_text != source_text:
		return "%s could not cold-clone its canonical activation fixture" % str(ACTIVATION_METHODS[0])
	var first_method_available := true
	for method in ACTIVATION_METHODS:
		var method_run: RunState
		if first_method_available:
			method_run = first_method_run
			first_method_available = false
		else:
			method_run = RunStateScript.new()
			method_run.from_dict(cold_source.duplicate(true))
		match method:
			"environment_runtime_state":
				game.environment_runtime_state(method_run, method_run.current_environment)
			"environment_object_state":
				game.environment_object_state(method_run, method_run.current_environment)
			"environment_interactable_objects":
				game.environment_interactable_objects(method_run, method_run.current_environment)
			"enter":
				game.enter(method_run, method_run.current_environment)
			"actions":
				game.actions(method_run, method_run.current_environment)
			"surface_state":
				game.surface_state(method_run, method_run.current_environment, {})
			"coach_state":
				game.coach_state(method_run, method_run.current_environment, {})
		var after := method_run.to_dict()
		var after_text := JSON.stringify(after)
		# Exact canonical bytes remain the invariant after every individual hook.
		if after_text != source_text:
			var paths: Array = []
			_collect_changed_paths(canonical_snapshot, after, "", paths)
			var change_summary := ", ".join(paths)
			if change_summary.is_empty():
				change_summary = "canonical byte order/type changed"
			return "%s changed %s" % [method, change_summary]
	# The sentinel proves cold_source -> from_dict -> to_dict is byte-canonical;
	# every hook proves its post-state has those same bytes. A redundant eighth
	# restore cannot strengthen that transitive proof, so retain only both source
	# immutability checks here.
	if JSON.stringify(cold_source) != cold_source_text:
		return "activation hooks mutated their parsed cold source fixture"
	if JSON.stringify(source_snapshot) != source_text:
		return "cold activation clones mutated their canonical source fixture"
	return ""


static func _generated_state_keys(environment: Dictionary, game_id: String) -> Array:
	var result: Array = []
	var game_states_value: Variant = environment.get("game_states", {})
	if typeof(game_states_value) == TYPE_DICTIONARY:
		for state_key_value in (game_states_value as Dictionary).keys():
			var state_key := str(state_key_value).strip_edges()
			if state_key == game_id or state_key.begins_with("%s:" % game_id):
				result.append(state_key)
	if not result.has(game_id):
		result.append(game_id)
	result.sort()
	return result


static func _json_round_trip_run_state(run_state: RunState, label: String, failures: Array) -> RunState:
	var parsed_snapshot := _json_round_trip_snapshot(run_state, label, failures)
	if parsed_snapshot.is_empty():
		return null
	var restored := _run_state_from_parsed_snapshot(parsed_snapshot)
	# from_dict() intentionally normalizes legacy/default fields. The restored
	# representation, not the pre-codec in-memory dictionary, is the activation
	# baseline used below.
	return restored


static func _json_round_trip_snapshot(run_state: RunState, label: String, failures: Array) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(run_state.to_dict()))
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("Game activation class guard could not JSON-roundtrip %s." % label)
		return {}
	return parsed as Dictionary


static func _run_state_from_parsed_snapshot(snapshot: Dictionary) -> RunState:
	var restored := RunStateScript.new()
	restored.from_dict(snapshot)
	return restored


static func _load_game(library: ContentLibrary, game_id: String, failures: Array) -> GameModule:
	var definition := library.game(game_id)
	var module_path := str(definition.get("module_path", "")).strip_edges()
	if definition.is_empty() or module_path.is_empty():
		failures.append("Game activation class guard could not resolve module %s." % game_id)
		return null
	var module_script: Script = load(module_path)
	if module_script == null:
		failures.append("Game activation class guard could not load %s for %s." % [module_path, game_id])
		return null
	var instance = module_script.new()
	if not instance is GameModule:
		failures.append("Game activation class guard found a non-GameModule at %s." % module_path)
		return null
	var game := instance as GameModule
	game.setup(definition, library)
	return game


static func _collect_changed_paths(before: Variant, after: Variant, path: String, paths: Array) -> void:
	if paths.size() >= 12:
		return
	if typeof(before) != typeof(after):
		# Numerically equal int/float values are a representation-only mutation.
		# Leave the path list empty so the exact-byte fallback reports it clearly.
		if before == after:
			return
		paths.append(path if not path.is_empty() else "<root>")
		return
	if typeof(before) == TYPE_DICTIONARY:
		var before_dict := before as Dictionary
		var after_dict := after as Dictionary
		var keys: Array = []
		for key_value in before_dict.keys():
			var key := str(key_value)
			if not keys.has(key):
				keys.append(key)
		for key_value in after_dict.keys():
			var key := str(key_value)
			if not keys.has(key):
				keys.append(key)
		keys.sort()
		for key_value in keys:
			var key := str(key_value)
			var child_path := key if path.is_empty() else "%s.%s" % [path, key]
			if not before_dict.has(key) or not after_dict.has(key):
				paths.append(child_path)
			elif JSON.stringify(before_dict.get(key)) != JSON.stringify(after_dict.get(key)):
				_collect_changed_paths(before_dict.get(key), after_dict.get(key), child_path, paths)
			if paths.size() >= 12:
				return
		return
	if typeof(before) == TYPE_ARRAY:
		var before_array := before as Array
		var after_array := after as Array
		if before_array.size() != after_array.size():
			paths.append("%s.size" % path)
			return
		for index in range(before_array.size()):
			if JSON.stringify(before_array[index]) != JSON.stringify(after_array[index]):
				_collect_changed_paths(before_array[index], after_array[index], "%s[%d]" % [path, index], paths)
			if paths.size() >= 12:
				return
		return
	if before != after:
		paths.append(path if not path.is_empty() else "<root>")


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if typeof(value) == TYPE_ARRAY else []


static func _string_array(value: Variant) -> Array:
	var result: Array = []
	for entry_value in _array(value):
		var entry := str(entry_value).strip_edges()
		if not entry.is_empty():
			result.append(entry)
	return result
