extends SceneTree

# UIENV-PF-003..009 production composition gate. Each scenario is pinned into
# its authored destination and crossed with every membership outcome allowed by
# EnvironmentEventResolver.selection_contract(). Town rumor staff is appended as
# a second legal outcome for its supported venues because that control is added
# after base event selection by RunState's living-world context.

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EnvironmentEventResolverScript := preload("res://scripts/core/environment_event_resolver.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EnvironmentPlacementScript := preload("res://scripts/core/environment_placement.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const ScenarioEngineScript := preload("res://scripts/core/scenario_engine.gd")
const SequenceCatalogScript := preload("res://scripts/core/scenario_sequence_catalog.gd")
const HarnessProductionFidelityScript := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const EnvironmentReadabilityContractScript := preload("res://scripts/tests/foundation/env06_8_environment_readability_contract.gd")

const EXPECTED_SCENARIOS := 55
const EXPECTED_COMPOSITIONS := 415
const EXPECTED_ORDER_VARIANTS := 177
const FIGHT_NIGHT_SCENARIO_ID := "bar_fight_night"
const FIGHT_NIGHT_SAFE_EXIT_ID := "bar_fight_night_safe_exit"
const POST_SELECTION_SCENARIO_ID := "grand_casino_gala_night"
# Production installation seals this contract without overlay/base-occupancy
# overrides. Normal and expanded 44px authority are intrinsic to the resolver;
# viewport_size is not a material layout input and must not force a duplicate seal.
const LAYOUT_CONTEXT := {}
const RUMOR_STAFF_ARCHETYPES := [
	"bar",
	"corner_store",
	"delta_queen",
	"gas_station_casino",
	"grand_casino",
	"jazz_club",
	"kitty_cat_lounge",
	"motel",
	"pawn_shop",
	"small_underground_casino",
]
const EXPECTED_COMPOSITION_MANIFEST := {
	"back_alley_cruiser_parked": {"count": 4, "digest": "8d77849d94b966ea618d14402874f4fdbb6c8dc693ab91bf13eb2fe4de6253ec"},
	"back_alley_fence_night": {"count": 4, "digest": "d66e2ab92324529292ec83d36c537cbaa902b78d6b0a60f9a40c9a95368bf6b6"},
	"back_alley_nothing_moving": {"count": 4, "digest": "e6aa076147de04f0ee660e4786819cded3da540ce10c2775c9c2e29b60a0d3f3"},
	"back_alley_street_craps": {"count": 4, "digest": "ecfe1cec58a8f8ddb3d91e2d0f29e488242b4fc77b4e3b120d58043713b5d06a"},
	"bar_darts_league_night": {"count": 8, "digest": "bc91fc91d300b66043cb481d690bd8c158e406a0608744fb65ec59d473b2474e"},
	"bar_dead_tuesday": {"count": 8, "digest": "ff59cf2defc4ac784b65e0eb1b2939ba082cef555836410143441baf80095758"},
	"bar_fight_night": {"count": 8, "digest": "0e80387143e92a6a8ae2a902b732fd64c90c9d6d4c2dd79de372cfab44c1b209"},
	"bar_live_band": {"count": 8, "digest": "e05844fa780fe92ce3ccc8c7da7840199cb83c88d85ed0eec50cfe12b0ca974d"},
	"bar_lock_in": {"count": 8, "digest": "62ec7a9e2fa3e77e1d0dd50fed4850b80f4b8fdf331af08231f04a46064c3e39"},
	"bar_payday_rush": {"count": 8, "digest": "56373a3d30cdd2263784e6557627f092401774123de7d7ffe7fe9eefaf200cdd"},
	"bar_wake": {"count": 8, "digest": "4f38d9ed1be91624db223835d72bd96731e1e9d2c1f6f13e7b7c5be3c0064971"},
	"beach_bonfire_night": {"count": 1, "digest": "5acef923ee71bc5e25db9887343298cd16c035a802923db872c03dbf8a417caf"},
	"beach_festival_weekend": {"count": 1, "digest": "5acef923ee71bc5e25db9887343298cd16c035a802923db872c03dbf8a417caf"},
	"beach_storm_coming": {"count": 1, "digest": "5acef923ee71bc5e25db9887343298cd16c035a802923db872c03dbf8a417caf"},
	"corner_store_aftermath": {"count": 18, "digest": "a0e5078e2dc49015b77efcd01fb7775fae1898a4a3bd346611e60d89c4f245f5"},
	"corner_store_dead_shift": {"count": 18, "digest": "a9a6a1118f6a9e460ba12bb371a94e4771592203c1702862cc49bc5e257f544b"},
	"corner_store_delivery_day": {"count": 18, "digest": "b3193f6e75886d9cd60ddf22803feaa707cca9d8755e170452c3c318dcda5e76"},
	"corner_store_inventory_night": {"count": 18, "digest": "9821c44bca1a46c91ceda8caefe54fc4c8c27b42b800b6095e93ce2b3baec116"},
	"corner_store_lotto_fever": {"count": 18, "digest": "aa023d6e754338d6d77f3eb394db3a8954fe753137b162d222b047a5a40bb407"},
	"delta_queen_captains_invitational": {"count": 12, "digest": "1a9f099058dd4c4933d8b3dd66bdd1bfa8477119310814402ca39d06080b6bc0"},
	"delta_queen_engine_trouble": {"count": 12, "digest": "3be208cdb050ffa53ae85e3c77280b49785aec84942e97902c9111be011a8d96"},
	"delta_queen_fog_delay": {"count": 12, "digest": "aa147dd46726a8afd837ed0c562b5fd6b8a9ff917ee3b5fdf507559c57ab09a3"},
	"delta_queen_wedding_charter": {"count": 12, "digest": "ed7d861b4408959d7cefad2b09e11848337bcfb9e6036dc6703a163cf6e2f532"},
	"delta_queen_whale_aboard": {"count": 12, "digest": "2407d236bf34190e31d1a349093e85e95de32b082ca005a1353c56b925fdaf35"},
	"gas_station_graveyard_shift": {"count": 8, "digest": "96933cffa0650d8adf03564ba3aa0e330580d31c94b6f4c4d005c2cac7a08b0c"},
	"gas_station_road_crew_payday": {"count": 8, "digest": "f07cb35c9ca571716b3048dde7adb72dbac2c1b1d5946dadeb44a29ea8b3d99e"},
	"gas_station_storm_shelter": {"count": 8, "digest": "a51906c75c04af07b4ce14dce013eaa65be29ee55bcf796de0a837f0c2297d6d"},
	"gas_station_tour_bus_stop": {"count": 8, "digest": "263a887575b5d8e764fe1bcfad96ac5375e0e994e32071ddd54420a1b4289b12"},
	"gas_station_trucker_convoy": {"count": 8, "digest": "9cab0a12368bb9cbe6ab3159d01dc735d4d80b2b78b507e4d700a13a67cbc998"},
	"grand_casino_audit_night": {"count": 8, "digest": "a7cfb97bc1adbf2efa97905f9e66806c6428ee869fd7c5867d134ec52db63510"},
	"grand_casino_convention_crowd": {"count": 8, "digest": "5c4cdaa54b1f45b9297a85f8c8e9a9909af3fcc46df8b332c5dffe66d7ed8505"},
	"grand_casino_gala_night": {"count": 8, "digest": "e8c4ef2f1c0e6ada8f8b4d2c23664f9ef60c7054f3c243d66edb846af9a053ff"},
	"jazz_club_guest_legend": {"count": 2, "digest": "799795fafed6a6acf731eada3b460aff3ce9f5638525ab84e5c258a844509347"},
	"jazz_club_recording_night": {"count": 2, "digest": "1a45f3ef82f26e68e988b78d427afaca78da5d532f0d189119c8d1eb746db7fe"},
	"jazz_club_rent_party": {"count": 2, "digest": "16435e48b685e4cc5d26ad2a993a05059c6786da7de7d446e1d52a272ef4e852"},
	"jazz_club_union_trouble": {"count": 2, "digest": "2fe6c966e2eded589e8cf616a7a96478442facce14ee918468bc93a84f2159ec"},
	"kitty_cat_lounge_amateur_night": {"count": 12, "digest": "58adae34085061469679fc88e1c565690aed264e2543c681024e343cb4cbffa4"},
	"kitty_cat_lounge_bachelorette_storm": {"count": 12, "digest": "fd1e80031278e1c550bd5d6cfc6155eb3e41f520c98cf1e2eba5cb722270cffd"},
	"kitty_cat_lounge_buyout": {"count": 12, "digest": "e71865a243f70c082d57d61d4ae2ede43312f801ac411736c8c06d6ebb35fd58"},
	"kitty_cat_lounge_slow_night": {"count": 12, "digest": "2fc2325a7a0da1d8706bd905d2a7e892b6a847b16885497b8e8c33176ddaf180"},
	"motel_conventioneers": {"count": 6, "digest": "18c654ce3c43b86df4cbae4f5108a2442410f8852d251dfa957910ee75b73973"},
	"motel_stakeout": {"count": 6, "digest": "cc238534e417790c76b6ebca4730a176837f87aea70972e9dbc0606c9c227e99"},
	"motel_wedding_overflow": {"count": 6, "digest": "9205cb4f5558b173629de77c3372521d8349ccd7b6922560def6dce38ba1d61a"},
	"motel_weekly_rates": {"count": 6, "digest": "054da7f0392a10d590ad4a785e358b3575449558d5b37b4eb104e41e88438bbf"},
	"pawn_shop_estate_lot_day": {"count": 6, "digest": "6489ef42b6e99bca790e89fda53882cc98042885958b1a295c5a5170b7dc37b1"},
	"pawn_shop_sals_mood": {"count": 6, "digest": "940977d539c8ccb0c8c90ccb6d79dc1c18d64b8315cad5add6ed417f89b366fe"},
	"pawn_shop_serial_check_day": {"count": 6, "digest": "28285324fe3935b5e28f04dbc336d43becf333c1ad123196afbdc7ed36c567e8"},
	"punchline_bringer_show": {"count": 2, "digest": "71548bffe254243234f7ea94afe588a4d244303660fb3fd1dcbd7070970bc4dd"},
	"punchline_debt_court": {"count": 2, "digest": "71548bffe254243234f7ea94afe588a4d244303660fb3fd1dcbd7070970bc4dd"},
	"punchline_greased_week": {"count": 6, "digest": "20891329130d1d8fe647a47b975c6ddc0114e30b4ebab623a30300160023ebb2"},
	"punchline_headliner_night": {"count": 2, "digest": "71548bffe254243234f7ea94afe588a4d244303660fb3fd1dcbd7070970bc4dd"},
	"punchline_high_stakes_night": {"count": 6, "digest": "ec70e7c799f5859f63833c71d8c14ea8694ab073241bdeb66c5d159fdd888dc8"},
	"punchline_new_muscle": {"count": 6, "digest": "a9db26c7789c5d8e4d258549d7eeba652bf517b1c1b91f889ad3a158336a6f00"},
	"punchline_open_mic_night": {"count": 2, "digest": "71548bffe254243234f7ea94afe588a4d244303660fb3fd1dcbd7070970bc4dd"},
	"punchline_raid_jitters": {"count": 2, "digest": "71548bffe254243234f7ea94afe588a4d244303660fb3fd1dcbd7070970bc4dd"},
}

var failures: Array = []
var checked_compositions := 0
var checked_order_variants := 0
var checked_offered_branches := 0
var covered_order_pairs: Dictionary = {}
var diagnostic_scenario := ""
var diagnostic_membership := ""
var diagnostic_variant := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for raw_arg in OS.get_cmdline_user_args():
		var arg := str(raw_arg).strip_edges()
		if arg.begins_with("--diagnostic-scenario="):
			diagnostic_scenario = arg.get_slice("=", 1).strip_edges()
		elif arg.begins_with("--diagnostic-membership="):
			diagnostic_membership = arg.get_slice("=", 1).strip_edges()
		elif arg.begins_with("--diagnostic-variant="):
			diagnostic_variant = arg.get_slice("=", 1).strip_edges()
	var diagnostic_mode := not diagnostic_scenario.is_empty() or not diagnostic_membership.is_empty() or not diagnostic_variant.is_empty()
	if diagnostic_mode and (diagnostic_scenario.is_empty() or diagnostic_membership.is_empty()):
		printerr("POSTFIX06_2_ENVIRONMENT_COMPOSITION DIAGNOSTIC FAIL scenario and membership are both required")
		quit(1)
		return
	var library = ContentLibraryScript.new()
	library.load()
	for error_value in library.validation_errors:
		failures.append("Content validation failed before environment composition coverage: %s" % str(error_value))
	var definitions := _scenario_definitions(library)
	var planned_compositions := 0
	if EXPECTED_COMPOSITION_MANIFEST.size() != EXPECTED_SCENARIOS:
		failures.append("UIENV-PF-003..009 reviewed composition manifest expected %d scenario rows, got %d." % [EXPECTED_SCENARIOS, EXPECTED_COMPOSITION_MANIFEST.size()])
	if definitions.size() != EXPECTED_SCENARIOS:
		failures.append("UIENV-PF-003..009 composition gate expected %d scenarios, got %d." % [EXPECTED_SCENARIOS, definitions.size()])
	else:
		for definition_value in definitions:
			var definition := _dict(definition_value)
			var scenario_id := str(definition.get("id", "")).strip_edges()
			var archetype_id := str(definition.get("archetype_id", "")).strip_edges()
			var layer_id := str(definition.get("layer_id", "")).strip_edges()
			var source_archetype := _dict(library.environment_archetype(archetype_id))
			if source_archetype.is_empty():
				failures.append("Scenario %s has no authored archetype %s." % [scenario_id, archetype_id])
				continue
			var effective_archetype := EnvironmentInstanceScript._archetype_for_layer(source_archetype, layer_id) if not layer_id.is_empty() else source_archetype.duplicate(true)
			var initial_state := ScenarioEngineScript.initial_state(definition)
			var scenario_archetype := ScenarioEngineScript.apply_to_archetype(effective_archetype, initial_state)
			var compositions := _legal_event_compositions(scenario_archetype, library.events)
			if RUMOR_STAFF_ARCHETYPES.has(archetype_id):
				compositions = _with_town_rumor_outcomes(compositions)
			if compositions.is_empty():
				failures.append("Scenario %s produced no legal base-event composition." % scenario_id)
				continue
			_check_composition_manifest_row(scenario_id, compositions)
			planned_compositions += compositions.size()
			_check_fight_night_authored_safe_exit(definition)
			for composition_value in compositions:
				var composition := _array(composition_value)
				var base_order := _base_event_composition(composition)
				if diagnostic_mode and (scenario_id != diagnostic_scenario or _membership_label(composition) != diagnostic_membership):
					continue
				var canonical := _check_composition(library, definition, composition, base_order, "canonical")
				checked_compositions += 1
				if diagnostic_mode and diagnostic_variant in ["", "canonical"]:
					continue
				for pair_value in _new_order_pairs(scenario_id, base_order):
					var pair := _array(pair_value)
					var pair_label := "pair-swap-%s-%s" % [str(pair[0]), str(pair[1])]
					if diagnostic_mode and diagnostic_variant != pair_label:
						continue
					var swapped_order := base_order.duplicate()
					var left_index := swapped_order.find(str(pair[0]))
					var right_index := swapped_order.find(str(pair[1]))
					if left_index < 0 or right_index < 0:
						failures.append("%s order fixture could not find pair %s in %s." % [scenario_id, JSON.stringify(pair), JSON.stringify(base_order)])
						continue
					var swap_value: Variant = swapped_order[left_index]
					swapped_order[left_index] = swapped_order[right_index]
					swapped_order[right_index] = swap_value
					# Pair variants share the canonical case's seed and membership. Restore
					# its immutable pre-travel source snapshot so each variant still crosses
					# the real travel/install/finalization boundary under the swapped event
					# order without rebuilding an unrelated identical source town.
					var variant := _check_composition(
						library,
						definition,
						composition,
						swapped_order,
						pair_label,
						_dict(canonical.get("source_snapshot", {})),
						true
					)
					_check_opposite_pair_orders(scenario_id, composition, pair, _array(canonical.get("event_ids", [])), _array(variant.get("event_ids", [])))
					covered_order_pairs[_order_pair_key(scenario_id, pair)] = true
					checked_order_variants += 1
	if planned_compositions != EXPECTED_COMPOSITIONS:
		failures.append("UIENV-PF-003..009 composition manifest expected exactly %d legal memberships, got %d." % [EXPECTED_COMPOSITIONS, planned_compositions])
	if diagnostic_mode:
		if checked_compositions != 1:
			failures.append("Diagnostic selector matched %d compositions instead of exactly one." % checked_compositions)
		if diagnostic_variant not in ["", "canonical"] and checked_order_variants != 1:
			failures.append("Diagnostic order selector matched %d pair variants instead of exactly one." % checked_order_variants)
		if failures.is_empty():
			print("POSTFIX06_2_ENVIRONMENT_COMPOSITION DIAGNOSTIC PASS scenario=%s membership=%s variant=%s" % [diagnostic_scenario, diagnostic_membership, "canonical" if diagnostic_variant.is_empty() else diagnostic_variant])
			quit(0)
			return
		for failure in failures:
			printerr("POSTFIX06_2_ENVIRONMENT_COMPOSITION DIAGNOSTIC FAIL %s" % str(failure))
		quit(1)
		return
	if checked_order_variants != EXPECTED_ORDER_VARIANTS or covered_order_pairs.size() != EXPECTED_ORDER_VARIANTS:
		failures.append("UIENV-PF-003..009 bounded order gate expected %d unique legal base-event pairs, executed=%d covered=%d." % [EXPECTED_ORDER_VARIANTS, checked_order_variants, covered_order_pairs.size()])
	_check_post_selection_injectors(library)
	_check_every_offered_destination(library)
	EnvironmentReadabilityContractScript.check_static(library, failures)
	if failures.is_empty():
		print("POSTFIX06_2_ENVIRONMENT_COMPOSITION PASS scenarios=%d compositions=%d order_variants=%d offered_branches=%d destinations=installed injectors=production_path safe_exits=reachable normal_and_expanded=unambiguous physical_supports=validated actionable_base=validated" % [definitions.size(), checked_compositions, checked_order_variants, checked_offered_branches])
		quit(0)
		return
	for failure in failures:
		printerr("POSTFIX06_2_ENVIRONMENT_COMPOSITION FAIL %s" % str(failure))
	printerr("POSTFIX06_2_ENVIRONMENT_COMPOSITION FAIL scenarios=%d compositions=%d order_variants=%d offered_branches=%d failures=%d" % [definitions.size(), checked_compositions, checked_order_variants, checked_offered_branches, failures.size()])
	quit(1)


func _check_composition(library: Variant, definition: Dictionary, composition: Array, forced_base_order: Array, variant_label: String, prepared_source_snapshot: Dictionary = {}, reuse_prepared_source: bool = false) -> Dictionary:
	var case_started_msec := Time.get_ticks_msec()
	var diagnostic_timing := not diagnostic_scenario.is_empty()
	var archetype_id := str(definition.get("archetype_id", "")).strip_edges()
	var scenario_id := str(definition.get("id", "")).strip_edges()
	var layer_id := str(definition.get("layer_id", "")).strip_edges()
	var archetype_ref := _dict(library.environment_archetype(archetype_id))
	var original_archetype := archetype_ref.duplicate(true)
	var original_pool := _array(library.environment_scenarios.get(archetype_id, [])).duplicate(true)
	var original_events := _array(library.events).duplicate()
	var base_composition := _base_event_composition(composition)
	_force_event_composition(archetype_ref, layer_id, base_composition)
	_force_event_definition_order(library, forced_base_order)
	library.environment_scenarios[archetype_id] = [definition.duplicate(true)]

	var label := "%s/%s/events=%s/order=%s" % [archetype_id, scenario_id, _composition_label(composition), variant_label]
	print("POSTFIX06_2_ENVIRONMENT_COMPOSITION CHECK %s" % label)
	var case_failures: Array = []
	var seed := "POSTFIX06_2-COMPOSITION-%s-%s" % [scenario_id, _membership_label(composition)]
	var run_state = RunStateScript.new()
	var generator = RunGeneratorScript.new(library)
	var initial: Dictionary = {}
	var source_snapshot: Dictionary = {}
	if not reuse_prepared_source:
		var case_config := RunStateScript.custom_challenge("postfix06_2_environment_composition", seed, {
			"scenario_pins": {archetype_id: scenario_id},
			"scenario_pins_apply_mutations": true,
		})
		run_state.start_new(seed, case_config)
		if diagnostic_timing:
			print("POSTFIX06_2_ENVIRONMENT_COMPOSITION TIMING phase=start_new elapsed_ms=%d" % (Time.get_ticks_msec() - case_started_msec))
		initial = HarnessProductionFidelityScript.generate_and_finalize(
			generator,
			run_state,
			case_failures,
			"%s initial room" % label,
			"",
			false,
			LAYOUT_CONTEXT
		)
		if bool(initial.get("ok", false)):
			# Freeze once before destination mutation, then restore canonical and
			# swapped variants through the identical persistence boundary. Event
			# definition order is therefore their only deliberate difference.
			source_snapshot = run_state.to_save_snapshot(false).duplicate(true)
			var expected_source_bytes := var_to_bytes(source_snapshot)
			run_state = RunStateScript.new()
			run_state.from_dict(source_snapshot)
			if var_to_bytes(source_snapshot) != expected_source_bytes:
				case_failures.append("%s canonical pre-travel source snapshot was mutated during restore." % label)
			_check_restored_source_identity(source_snapshot, run_state, label, case_failures)
			initial = {
				"ok": not run_state.current_environment.is_empty(),
				"target_id": run_state.current_world_node_id(),
				"environment": run_state.current_environment.duplicate(true),
				"restored_source_snapshot": true,
			}
	else:
		if prepared_source_snapshot.is_empty():
			initial = {"ok": false}
			case_failures.append("%s requested canonical source reuse without a frozen snapshot." % label)
		else:
			# The canonical snapshot is frozen and from_dict() owns its restored data;
			# do not deep-copy or reserialize the full town for every pair permutation.
			source_snapshot = prepared_source_snapshot
			run_state.from_dict(source_snapshot)
			_check_restored_source_identity(source_snapshot, run_state, label, case_failures)
			initial = {
				"ok": not run_state.current_environment.is_empty(),
				"target_id": run_state.current_world_node_id(),
				"environment": run_state.current_environment.duplicate(true),
				"restored_source_snapshot": true,
			}
		if not bool(initial.get("ok", false)) and not prepared_source_snapshot.is_empty():
			case_failures.append("%s could not restore its canonical pre-travel source snapshot." % label)
	if diagnostic_timing:
		print("POSTFIX06_2_ENVIRONMENT_COMPOSITION TIMING phase=initial_finalize elapsed_ms=%d" % (Time.get_ticks_msec() - case_started_msec))
	var target_node := _node_for_archetype(run_state, archetype_id)
	var arrival: Dictionary = {}
	if bool(initial.get("ok", false)) and not target_node.is_empty():
		_configure_rumor_outcome(run_state, target_node, composition.has("town_rumor_staff"), label, case_failures)
		arrival = HarnessProductionFidelityScript.travel_and_finalize(
			generator,
			run_state,
			target_node,
			true,
			library,
			case_failures,
			"%s destination" % label,
			LAYOUT_CONTEXT
		)
		if diagnostic_timing:
			print("POSTFIX06_2_ENVIRONMENT_COMPOSITION TIMING phase=travel_finalize elapsed_ms=%d" % (Time.get_ticks_msec() - case_started_msec))
		if bool(arrival.get("ok", false)) and not layer_id.is_empty() and str(run_state.current_environment.get("current_layer_id", "")) != layer_id:
			run_state.discover_environment_layer(layer_id, "postfix06_2_composition")
			var layer_result: Dictionary = generator.enter_environment_layer(run_state, layer_id, false)
			if not bool(layer_result.get("ok", false)):
				case_failures.append("%s could not install authored layer %s: %s" % [label, layer_id, str(layer_result.get("message", "unknown layer error"))])
				arrival = {"ok": false}
			else:
				arrival = HarnessProductionFidelityScript.finalize_arrival(run_state, library, case_failures, "%s authored layer" % label, LAYOUT_CONTEXT)
	elif target_node.is_empty():
		case_failures.append("%s has no offered destination for archetype %s." % [label, archetype_id])

	var actual_events: Array = []
	if bool(arrival.get("ok", false)):
		var environment := _dict(run_state.current_environment)
		actual_events = _array(environment.get("event_ids", [])).duplicate()
		var expected_events := base_composition.duplicate()
		var exclusive_opportunity := _dict(environment.get("scenario_exclusive_opportunity", {}))
		var exclusive_event_id := str(exclusive_opportunity.get("event_id", "")).strip_edges()
		var exclusive_was_appended := not exclusive_event_id.is_empty() and not base_composition.has(exclusive_event_id)
		if exclusive_was_appended:
			if not actual_events.has(exclusive_event_id):
				case_failures.append("%s scenario exclusive opportunity omitted its post-selection event %s." % [label, exclusive_event_id])
			elif actual_events.find(exclusive_event_id) != base_composition.size():
				case_failures.append("%s scenario exclusive opportunity %s was not appended immediately after base selection: %s." % [label, exclusive_event_id, JSON.stringify(actual_events)])
			expected_events.append(exclusive_event_id)
		var expects_rumor := composition.has("town_rumor_staff")
		var rumors := _array(environment.get("town_rumors", []))
		if expects_rumor:
			if rumors.is_empty():
				case_failures.append("%s requested a real living-world rumor outcome but destination town_rumors is empty." % label)
			if not actual_events.has("town_rumor_staff"):
				case_failures.append("%s real post-selection rumor path omitted town_rumor_staff; actual=%s." % [label, JSON.stringify(actual_events)])
			elif actual_events.find("town_rumor_staff") < base_composition.size():
				case_failures.append("%s town_rumor_staff did not append after base event selection: %s." % [label, JSON.stringify(actual_events)])
			expected_events.append("town_rumor_staff")
		else:
			if not rumors.is_empty() or actual_events.has("town_rumor_staff"):
				case_failures.append("%s heard-all no-rumor outcome still injected rumor content: rumors=%s events=%s." % [label, JSON.stringify(rumors), JSON.stringify(actual_events)])
		var reputation := _dict(environment.get("town_reputation", {}))
		if not _dict(reputation.get("rare_reaction", {})).is_empty():
			expected_events.append("town_reputation_reaction")
			if exclusive_was_appended and actual_events.find(exclusive_event_id) >= actual_events.find("town_reputation_reaction"):
				case_failures.append("%s post-selection order drifted; exclusive opportunity must precede reputation reaction: %s." % [label, JSON.stringify(actual_events)])
		if exclusive_was_appended and expects_rumor and actual_events.find(exclusive_event_id) >= actual_events.find("town_rumor_staff"):
			case_failures.append("%s post-selection order drifted; exclusive opportunity must precede rumor staff: %s." % [label, JSON.stringify(actual_events)])
		for chain_event_value in _array(environment.get("character_chain_event_ids", [])):
			var chain_event := str(chain_event_value)
			if not expected_events.has(chain_event):
				expected_events.append(chain_event)
			if expects_rumor and actual_events.find("town_rumor_staff") >= 0 and actual_events.find(chain_event) >= 0 \
					and actual_events.find("town_rumor_staff") > actual_events.find(chain_event):
				case_failures.append("%s post-selection order drifted; rumor staff must precede CharacterChain event %s: %s." % [label, chain_event, JSON.stringify(actual_events)])
			if exclusive_was_appended and actual_events.find(exclusive_event_id) >= actual_events.find(chain_event):
				case_failures.append("%s post-selection order drifted; exclusive opportunity must precede CharacterChain event %s: %s." % [label, chain_event, JSON.stringify(actual_events)])
		var sorted_actual := actual_events.duplicate()
		var sorted_expected := expected_events.duplicate()
		sorted_actual.sort()
		sorted_expected.sort()
		if sorted_actual != sorted_expected:
			case_failures.append("%s destination event membership drifted from base selection plus declared production injectors; expected=%s actual=%s." % [label, JSON.stringify(sorted_expected), JSON.stringify(sorted_actual)])
		if str(environment.get("scenario_id", "")) != scenario_id:
			case_failures.append("%s installed scenario %s instead of %s." % [label, str(environment.get("scenario_id", "")), scenario_id])
		if not bool(environment.get("scenario_semantic_ready", false)):
			case_failures.append("%s destination installed without sealed scenario semantics." % label)
		var finalized := _dict(arrival.get("finalization", {}))
		var audit := _dict(finalized.get("layout_audit", environment.get("scenario_layout_audit", {})))
		if bool(finalized.get("inactive", false)) or not bool(audit.get("valid", false)):
			case_failures.append("%s did not install an active valid layout: %s" % [label, JSON.stringify(audit)])
		if int(audit.get("normal_overlap_count", -1)) != 0:
			case_failures.append("%s retained ambiguous normal hit authority: %s" % [label, JSON.stringify(audit)])
		if int(audit.get("small_screen_overlap_count", -1)) != 0:
			case_failures.append("%s retained ambiguous expanded 44px hit authority: %s" % [label, JSON.stringify(audit)])
		_check_safe_exit_reachability(finalized, audit, scenario_id, label, case_failures)
		var generated_layout := _dict(environment.get("layout", {}))
		if not _array(generated_layout.get("placement_errors", [])).is_empty():
			case_failures.append("%s base placement failed before scenario composition: %s" % [label, JSON.stringify(generated_layout.get("placement_errors", []))])
			if diagnostic_timing:
				print("POSTFIX06_2_ENVIRONMENT_COMPOSITION DIAGNOSTIC LAYOUT rects=%s classes=%s surfaces=%s adjusted=%s" % [
					JSON.stringify(generated_layout.get("object_rects", {})),
					JSON.stringify(generated_layout.get("placement_classes", {})),
					JSON.stringify(generated_layout.get("placement_surfaces", {})),
					JSON.stringify(generated_layout.get("placement_adjusted_ids", [])),
				])
		if not _array(generated_layout.get("placement_fallback_ids", [])).is_empty():
			case_failures.append("%s base placement escaped its physical class onto generic fallback slots: %s" % [label, JSON.stringify(generated_layout.get("placement_fallback_ids", []))])
		_check_base_physical_authority(environment, label, case_failures)

	_restore_dictionary(archetype_ref, original_archetype)
	library.environment_scenarios[archetype_id] = original_pool
	library.events = original_events
	if not case_failures.is_empty():
		failures.append_array(case_failures)
	if diagnostic_timing:
		print("POSTFIX06_2_ENVIRONMENT_COMPOSITION TIMING phase=complete elapsed_ms=%d failures=%d" % [Time.get_ticks_msec() - case_started_msec, case_failures.size()])
	return {
		"ok": bool(arrival.get("ok", false)) and case_failures.is_empty(),
		"event_ids": actual_events,
		"source_snapshot": source_snapshot if not reuse_prepared_source else {},
	}


func _check_restored_source_identity(snapshot: Dictionary, run_state: Variant, label: String, case_failures: Array) -> void:
	var expected_environment := _dict(snapshot.get("current_environment", {}))
	var expected_identity := {
		"seed_text": str(snapshot.get("seed_text", "")),
		"seed_value": int(snapshot.get("seed_value", 0)),
		"rng_seed": int(snapshot.get("rng_seed", 0)),
		"rng_state": int(snapshot.get("rng_state", 0)),
		"game_clock_minutes": int(snapshot.get("game_clock_minutes", 0)),
		"environment_id": str(expected_environment.get("id", "")),
		"archetype_id": str(expected_environment.get("archetype_id", "")),
		"world_node_id": str(expected_environment.get("world_node_id", expected_environment.get("archetype_id", ""))),
		"scenario_id": str(expected_environment.get("scenario_id", "")),
	}
	var restored_environment: Dictionary = run_state.current_environment
	var restored_identity := {
		"seed_text": str(run_state.seed_text),
		"seed_value": int(run_state.seed_value),
		"rng_seed": int(run_state.rng_seed),
		"rng_state": int(run_state.rng_state),
		"game_clock_minutes": int(run_state.game_clock_minutes),
		"environment_id": str(restored_environment.get("id", "")),
		"archetype_id": str(restored_environment.get("archetype_id", "")),
		"world_node_id": str(run_state.current_world_node_id()),
		"scenario_id": str(restored_environment.get("scenario_id", "")),
	}
	if var_to_bytes(restored_identity) != var_to_bytes(expected_identity):
		case_failures.append("%s restored a different pre-travel source identity: expected=%s actual=%s." % [label, JSON.stringify(expected_identity), JSON.stringify(restored_identity)])


func _check_safe_exit_reachability(finalized: Dictionary, audit: Dictionary, scenario_id: String, label: String, case_failures: Array) -> void:
	var projection := _dict(finalized.get("projection", {}))
	var semantic := _dict(projection.get("semantic_state", {}))
	var interactions := _dict(semantic.get("interactions", {}))
	var reachable := _array(audit.get("reachable_interaction_ids", []))
	var audited_safe := _array(audit.get("safe_exit_ids", []))
	if scenario_id == FIGHT_NIGHT_SCENARIO_ID:
		var fight_identity := "scenario::%s" % FIGHT_NIGHT_SAFE_EXIT_ID
		if not interactions.has(fight_identity):
			case_failures.append("%s is missing required runtime Fight Night safe exit %s." % [label, fight_identity])
		else:
			var fight_exit := _dict(interactions.get(fight_identity, {}))
			if not bool(fight_exit.get("present", false)):
				case_failures.append("%s required Fight Night safe exit %s is not present." % [label, fight_identity])
			if not bool(fight_exit.get("safe_exit", false)):
				case_failures.append("%s required Fight Night safe exit %s lost safe_exit authority." % [label, fight_identity])
			if not bool(fight_exit.get("enabled", false)):
				case_failures.append("%s required Fight Night safe exit %s is disabled." % [label, fight_identity])
			if _array(fight_exit.get("available_actions", [])).is_empty():
				case_failures.append("%s required Fight Night safe exit %s is not actionable." % [label, fight_identity])
			if not reachable.has(fight_identity) or not audited_safe.has(fight_identity):
				case_failures.append("%s required Fight Night safe exit %s is not reachable in normal and expanded geometry." % [label, fight_identity])
	for identity_value in interactions.keys():
		var identity := str(identity_value)
		var interaction := _dict(interactions.get(identity_value, {}))
		if not bool(interaction.get("present", true)) or not bool(interaction.get("safe_exit", false)):
			continue
		if not bool(interaction.get("enabled", false)) or _array(interaction.get("available_actions", [])).is_empty():
			case_failures.append("%s safe exit %s is present but disabled or not actionable." % [label, identity])
			continue
		if not reachable.has(identity) or not audited_safe.has(identity):
			case_failures.append("%s safe exit %s is offered but not reachable in normal and expanded geometry." % [label, identity])


func _check_base_physical_authority(environment: Dictionary, label: String, case_failures: Array) -> void:
	var generated_layout := _dict(environment.get("layout", {}))
	var object_rects := _dict(generated_layout.get("object_rects", {}))
	var placement_classes := _dict(generated_layout.get("placement_classes", {}))
	var placement_surfaces := _dict(generated_layout.get("placement_surfaces", {}))
	var board := Rect2(0.0, 0.0, 900.0, 430.0)
	var object_ids := object_rects.keys()
	object_ids.sort()
	for object_id_value in object_ids:
		var object_id := str(object_id_value)
		var placement_class := str(placement_classes.get(object_id, ""))
		var rect := _normalized_pixel_rect(object_rects.get(object_id, {}))
		if placement_class not in EnvironmentPlacementScript.CLASSES:
			case_failures.append("%s base object %s has no closed physical placement class." % [label, object_id])
		elif not rect.has_area() or not board.encloses(rect):
			case_failures.append("%s base object %s has invalid board geometry %s." % [label, object_id, str(rect)])
		elif str(placement_surfaces.get(object_id, "")) != "developer_free" \
				and not EnvironmentPlacementScript.valid_rect(environment, placement_class, rect):
			case_failures.append("%s base object %s left its %s physical support %s at %s." % [label, object_id, placement_class, str(placement_surfaces.get(object_id, "")), str(rect)])
	for record_value in _array(environment.get("scenario_layout_base_records", [])):
		var record := _dict(record_value)
		if not bool(record.get("interactive", true)):
			continue
		var object_id := str(record.get("object_id", ""))
		if bool(record.get("enabled", false)) and _array(record.get("available_actions", [])).is_empty():
			case_failures.append("%s enabled base control %s has no actionable operation." % [label, object_id])
		if object_rects.has(object_id):
			var layout_rect := _normalized_pixel_rect(object_rects.get(object_id, {}))
			var control_rect := _normalized_pixel_rect(record.get("focus_rect", record.get("normalized_hit_rect", {})))
			if not control_rect.is_equal_approx(layout_rect):
				case_failures.append("%s actionable base control %s drifted from its physical layout rect (%s vs %s)." % [label, object_id, str(control_rect), str(layout_rect)])


func _check_composition_manifest_row(scenario_id: String, compositions: Array) -> void:
	if not EXPECTED_COMPOSITION_MANIFEST.has(scenario_id):
		failures.append("UIENV-PF-003..009 reviewed composition manifest is missing scenario %s." % scenario_id)
		return
	var labels: Array = []
	for composition_value in compositions:
		labels.append(_composition_label(_array(composition_value)))
	labels.sort()
	var actual_digest := JSON.stringify(labels).sha256_text()
	var expected := _dict(EXPECTED_COMPOSITION_MANIFEST.get(scenario_id, {}))
	if compositions.size() != int(expected.get("count", -1)) or actual_digest != str(expected.get("digest", "")):
		failures.append("UIENV-PF-003..009 scenario %s legal-composition manifest drifted: expected count=%d digest=%s, got count=%d digest=%s labels=%s." % [
			scenario_id,
			int(expected.get("count", -1)),
			str(expected.get("digest", "")),
			compositions.size(),
			actual_digest,
			JSON.stringify(labels),
		])


func _check_fight_night_authored_safe_exit(definition: Dictionary) -> void:
	if str(definition.get("id", "")) != FIGHT_NIGHT_SCENARIO_ID:
		return
	var authored := _find_authored_interaction(definition, FIGHT_NIGHT_SAFE_EXIT_ID)
	if authored.is_empty():
		failures.append("UIENV-PF-003 authored Fight Night sequence is missing exact safe exit %s." % FIGHT_NIGHT_SAFE_EXIT_ID)
		return
	if str(authored.get("stable_object_id", "")) != FIGHT_NIGHT_SAFE_EXIT_ID \
			or str(authored.get("owner_namespace", "")) != "scenario" \
			or str(authored.get("presentation_object_id", "")) != "scenario::%s" % FIGHT_NIGHT_SAFE_EXIT_ID \
			or not bool(authored.get("safe_exit", false)) \
			or not bool(authored.get("enabled", false)) \
			or _array(authored.get("available_actions", [])).is_empty():
		failures.append("UIENV-PF-003 authored Fight Night safe exit is not exact, enabled, actionable safe-exit authority: %s" % JSON.stringify(authored))


static func _find_authored_interaction(value: Variant, stable_object_id: String) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		var row := value as Dictionary
		if str(row.get("stable_object_id", "")) == stable_object_id:
			var nested := _dict(row.get("interaction", {}))
			if not nested.is_empty():
				return nested
			if row.has("available_actions") or row.has("safe_exit"):
				return row
		for child in row.values():
			var found := _find_authored_interaction(child, stable_object_id)
			if not found.is_empty():
				return found
	elif typeof(value) == TYPE_ARRAY:
		for child in value as Array:
			var array_found := _find_authored_interaction(child, stable_object_id)
			if not array_found.is_empty():
				return array_found
	return {}


func _configure_rumor_outcome(run_state: Variant, target_node: String, expects_rumor: bool, label: String, case_failures: Array) -> void:
	if run_state == null or run_state.town_state == null or run_state.town_state.living_world == null:
		case_failures.append("%s cannot configure the real living-world rumor outcome without TownNetwork." % label)
		return
	var living_world: Variant = run_state.town_state.living_world
	for node_value in _array(run_state.world_map.get("nodes", [])):
		var node_id := str(_dict(node_value).get("id", "")).strip_edges()
		if not node_id.is_empty():
			living_world.heard_by_node[node_id] = {"id": "postfix06_2:heard:%s" % node_id}
	if not expects_rumor:
		return
	var rumor_target := ""
	for node_value in _array(run_state.world_map.get("nodes", [])):
		var candidate := str(_dict(node_value).get("id", "")).strip_edges()
		if not candidate.is_empty() and candidate != target_node:
			rumor_target = candidate
			break
	if rumor_target.is_empty():
		case_failures.append("%s could not find a distinct live rumor target." % label)
		return
	living_world.heard_by_node.erase(rumor_target)
	if not run_state.register_rumor_fact("pusher_pile", "postfix06_2:composition_rumor", {
		"target_node_id": rumor_target,
		"source_id": "postfix06_2_environment_composition",
		"fact_detail": "a reviewed composition rumor remains live",
	}):
		case_failures.append("%s could not register the live composition rumor fact." % label)


func _check_post_selection_injectors(library: Variant) -> void:
	var case_failures: Array = []
	var seed := "POSTFIX06_2-POST-SELECTION-INJECTORS"
	var run_state = RunStateScript.new()
	# Ordinary situation selection intentionally permits a no-scenario outcome.
	# Pin one reviewed sequence so this fixture proves the late event injectors are
	# included in the production semantic seal and layout audit, rather than asking
	# a correctly inactive room for scenario-only audit evidence.
	run_state.start_new(seed, RunStateScript.custom_challenge("postfix06_2_post_selection_injectors", seed, {
		"scenario_pins": {"grand_casino": POST_SELECTION_SCENARIO_ID},
		"scenario_pins_apply_mutations": true,
	}))
	var generator = RunGeneratorScript.new(library)
	var initial := HarnessProductionFidelityScript.generate_and_finalize(generator, run_state, case_failures, "post-selection injector initial room", "", false, LAYOUT_CONTEXT)
	var grand_node := _node_for_archetype(run_state, "grand_casino")
	if bool(initial.get("ok", false)) and not grand_node.is_empty():
		_configure_rumor_outcome(run_state, grand_node, false, "post-selection injector fixture", case_failures)
		run_state.bankroll = 125
		var rare_action := -1
		for action_index in range(100):
			run_state.town_state.living_world.action_index = action_index
			if not _dict(run_state.town_state.living_world._rare_reaction(grand_node, 3.0)).is_empty():
				rare_action = action_index
				break
		if rare_action < 0:
			case_failures.append("Post-selection injector fixture could not find a bounded deterministic reputation-reaction action index.")
		else:
			run_state.town_state.action_index = rare_action
			run_state.town_state.living_world.action_index = rare_action
			if run_state.record_reputation_incident("thrown_out", grand_node, 1.0, {"source": "postfix06_2"}).is_empty():
				case_failures.append("Post-selection injector fixture could not record a production reputation incident.")
		var arrival := HarnessProductionFidelityScript.travel_and_finalize(generator, run_state, grand_node, true, library, case_failures, "post-selection injector destination", LAYOUT_CONTEXT)
		if bool(arrival.get("ok", false)):
			var environment := _dict(run_state.current_environment)
			var event_ids := _array(environment.get("event_ids", []))
			var chain_ids := _array(environment.get("character_chain_event_ids", []))
			if str(environment.get("scenario_id", "")) != POST_SELECTION_SCENARIO_ID:
				case_failures.append("Post-selection injector fixture installed scenario %s instead of pinned %s." % [str(environment.get("scenario_id", "")), POST_SELECTION_SCENARIO_ID])
			if not event_ids.has("town_reputation_reaction") or _dict(_dict(environment.get("town_reputation", {})).get("rare_reaction", {})).is_empty():
				case_failures.append("Production living-world path did not inject town_reputation_reaction from a live rare reaction: %s" % JSON.stringify(event_ids))
			if not event_ids.has("chain06_rourke_noticed") or not chain_ids.has("chain06_rourke_noticed"):
				case_failures.append("Production living-world path did not inject the eligible CharacterChain event: events=%s chain_ids=%s" % [JSON.stringify(event_ids), JSON.stringify(chain_ids)])
			if event_ids.find("town_reputation_reaction") >= 0 and event_ids.find("chain06_rourke_noticed") >= 0 \
					and event_ids.find("town_reputation_reaction") > event_ids.find("chain06_rourke_noticed"):
				case_failures.append("Production post-selection injector order drifted; reputation must precede CharacterChain projection: %s" % JSON.stringify(event_ids))
			if not _array(environment.get("town_rumors", [])).is_empty() or event_ids.has("town_rumor_staff"):
				case_failures.append("Post-selection injector fixture unexpectedly admitted rumor staff despite heard-all state.")
			var finalized := _dict(arrival.get("finalization", {}))
			var audit := _dict(finalized.get("layout_audit", environment.get("scenario_layout_audit", {})))
			if bool(finalized.get("inactive", false)) or not bool(audit.get("valid", false)) \
					or int(audit.get("normal_overlap_count", -1)) != 0 \
					or int(audit.get("small_screen_overlap_count", -1)) != 0:
				case_failures.append("Production post-selection injectors did not retain a valid unambiguous layout: %s" % JSON.stringify(audit))
			if not _array(_dict(environment.get("layout", {})).get("placement_errors", [])).is_empty():
				case_failures.append("Production post-selection injectors produced base placement errors: %s" % JSON.stringify(_dict(environment.get("layout", {})).get("placement_errors", [])))
			_check_safe_exit_reachability(finalized, audit, str(environment.get("scenario_id", "")), "post-selection injector destination", case_failures)
	else:
		case_failures.append("Post-selection injector fixture could not resolve a Grand Casino destination.")
	if not case_failures.is_empty():
		failures.append_array(case_failures)


func _check_every_offered_destination(library: Variant) -> void:
	var case_failures: Array = []
	var seed := "POSTFIX06_2-EVERY-OFFERED-BRANCH"
	var challenge := RunStateScript.custom_challenge("postfix06_2_every_offered_branch", seed, {})
	var baseline = RunStateScript.new()
	baseline.start_new(seed, challenge)
	var baseline_generator = RunGeneratorScript.new(library)
	var initial := HarnessProductionFidelityScript.generate_and_finalize(baseline_generator, baseline, case_failures, "offered-branch baseline", "", false, LAYOUT_CONTEXT)
	var offered: Array = []
	if bool(initial.get("ok", false)):
		var baseline_source_id := baseline.current_world_node_id()
		for target_value in baseline_generator._world_travel_target_ids(baseline, baseline.world_map, baseline_source_id):
			var target_id := str(target_value)
			if baseline_generator._world_target_is_available(baseline, baseline.world_map, baseline_source_id, target_id):
				offered.append(target_id)
	if offered.is_empty():
		case_failures.append("Every-offered-branch gate found no actionable production travel branches.")
	for target_value in offered:
		var target_id := str(target_value)
		var branch = RunStateScript.new()
		branch.start_new(seed, challenge)
		var generator = RunGeneratorScript.new(library)
		var branch_initial := HarnessProductionFidelityScript.generate_and_finalize(generator, branch, case_failures, "offered branch %s initial room" % target_id, "", false, LAYOUT_CONTEXT)
		if not bool(branch_initial.get("ok", false)):
			continue
		var branch_source_id := branch.current_world_node_id()
		if not generator._world_travel_target_ids(branch, branch.world_map, branch_source_id).has(target_id) \
				or not generator._world_target_is_available(branch, branch.world_map, branch_source_id, target_id):
			case_failures.append("Fresh deterministic branch no longer offers target %s." % target_id)
			continue
		var arrival := HarnessProductionFidelityScript.travel_and_finalize(generator, branch, target_id, false, library, case_failures, "offered branch %s destination" % target_id, LAYOUT_CONTEXT)
		checked_offered_branches += 1
		if bool(arrival.get("ok", false)) and branch.current_world_node_id() != target_id:
			case_failures.append("Offered branch %s completed without installing its requested destination." % target_id)
		elif bool(arrival.get("ok", false)):
			var environment := _dict(branch.current_environment)
			var finalized := _dict(arrival.get("finalization", {}))
			var audit := _dict(finalized.get("layout_audit", environment.get("scenario_layout_audit", {})))
			if not bool(finalized.get("inactive", false)) and (not bool(audit.get("valid", false)) \
					or int(audit.get("normal_overlap_count", -1)) != 0 \
					or int(audit.get("small_screen_overlap_count", -1)) != 0):
				case_failures.append("Offered branch %s installed an ambiguous scenario layout: %s" % [target_id, JSON.stringify(audit)])
			if not _array(_dict(environment.get("layout", {})).get("placement_errors", [])).is_empty():
				case_failures.append("Offered branch %s installed with base placement errors: %s" % [target_id, JSON.stringify(_dict(environment.get("layout", {})).get("placement_errors", []))])
			_check_safe_exit_reachability(finalized, audit, str(environment.get("scenario_id", "")), "offered branch %s" % target_id, case_failures)
	if not case_failures.is_empty():
		failures.append_array(case_failures)


static func _base_event_composition(composition: Array) -> Array:
	var result := composition.duplicate()
	while result.has("town_rumor_staff"):
		result.erase("town_rumor_staff")
	return result


func _new_order_pairs(scenario_id: String, event_ids: Array) -> Array:
	var result: Array = []
	for left_index in range(event_ids.size()):
		for right_index in range(left_index + 1, event_ids.size()):
			var pair := [str(event_ids[left_index]), str(event_ids[right_index])]
			if not covered_order_pairs.has(_order_pair_key(scenario_id, pair)):
				result.append(pair)
	return result


static func _order_pair_key(scenario_id: String, pair: Array) -> String:
	var ids := [str(pair[0]), str(pair[1])]
	ids.sort()
	return "%s|%s|%s" % [scenario_id, ids[0], ids[1]]


func _check_opposite_pair_orders(scenario_id: String, composition: Array, pair: Array, canonical_events: Array, swapped_events: Array) -> void:
	var left := str(pair[0])
	var right := str(pair[1])
	var canonical_left := canonical_events.find(left)
	var canonical_right := canonical_events.find(right)
	var swapped_left := swapped_events.find(left)
	var swapped_right := swapped_events.find(right)
	if canonical_left < 0 or canonical_right < 0 or swapped_left < 0 or swapped_right < 0:
		failures.append("%s order-pair proof lost %s/%s in composition %s: canonical=%s swapped=%s." % [scenario_id, left, right, _composition_label(composition), JSON.stringify(canonical_events), JSON.stringify(swapped_events)])
		return
	if (canonical_left < canonical_right) == (swapped_left < swapped_right):
		failures.append("%s did not exercise both deterministic orders for legal event pair %s/%s in composition %s: canonical=%s swapped=%s." % [scenario_id, left, right, _composition_label(composition), JSON.stringify(canonical_events), JSON.stringify(swapped_events)])


static func _force_event_definition_order(library: Variant, event_order: Array) -> void:
	if library == null or event_order.is_empty():
		return
	var original := _array(library.events)
	var by_id: Dictionary = {}
	for definition_value in original:
		var definition := _dict(definition_value)
		var event_id := str(definition.get("id", ""))
		if not event_id.is_empty():
			by_id[event_id] = definition_value
	var reordered: Array = []
	var moved: Dictionary = {}
	for event_id_value in event_order:
		var event_id := str(event_id_value)
		if by_id.has(event_id) and not moved.has(event_id):
			reordered.append(by_id[event_id])
			moved[event_id] = true
	for definition_value in original:
		var event_id := str(_dict(definition_value).get("id", ""))
		if not moved.has(event_id):
			reordered.append(definition_value)
	library.events = reordered


static func _legal_event_compositions(archetype: Dictionary, event_definitions: Array) -> Array:
	var contract := EnvironmentEventResolverScript.selection_contract(archetype, event_definitions)
	var candidates := _array(contract.get("candidates", []))
	var required := _array(contract.get("required", []))
	var optional: Array = []
	for candidate_value in candidates:
		if not required.has(candidate_value):
			optional.append(candidate_value)
	var result: Array = []
	var seen: Dictionary = {}
	var minimum := int(contract.get("minimum_selected_count", required.size()))
	var maximum := int(contract.get("maximum_selected_count", required.size()))
	for count in range(minimum, maximum + 1):
		var optional_count := count - required.size()
		if optional_count < 0 or optional_count > optional.size():
			continue
		var subsets: Array = []
		_append_combinations(optional, 0, optional_count, [], subsets)
		for subset_value in subsets:
			var membership: Dictionary = {}
			for event_id_value in required:
				membership[str(event_id_value)] = true
			for event_id_value in _array(subset_value):
				membership[str(event_id_value)] = true
			var selected: Array = []
			for candidate_value in candidates:
				if membership.has(str(candidate_value)):
					selected.append(str(candidate_value))
			var filtered := EnvironmentEventResolverScript._filter_unique_event_ids(selected, event_definitions)
			var key := JSON.stringify(filtered)
			if not seen.has(key):
				seen[key] = true
				result.append(filtered)
	if result.is_empty() and minimum == 0:
		result.append([])
	result.sort_custom(func(left_value: Variant, right_value: Variant) -> bool: return _composition_label(_array(left_value)) < _composition_label(_array(right_value)))
	return result


static func _append_combinations(values: Array, start: int, remaining: int, selected: Array, output: Array) -> void:
	if remaining == 0:
		output.append(selected.duplicate())
		return
	for index in range(start, values.size() - remaining + 1):
		var next := selected.duplicate()
		next.append(values[index])
		_append_combinations(values, index + 1, remaining - 1, next, output)


static func _with_town_rumor_outcomes(compositions: Array) -> Array:
	var result := compositions.duplicate(true)
	var seen: Dictionary = {}
	for existing_value in result:
		seen[JSON.stringify(_array(existing_value))] = true
	for composition_value in compositions:
		var with_rumor := _array(composition_value).duplicate()
		if not with_rumor.has("town_rumor_staff"):
			with_rumor.append("town_rumor_staff")
		var key := JSON.stringify(with_rumor)
		if not seen.has(key):
			seen[key] = true
			result.append(with_rumor)
	result.sort_custom(func(left_value: Variant, right_value: Variant) -> bool: return _composition_label(_array(left_value)) < _composition_label(_array(right_value)))
	return result


static func _force_event_composition(archetype: Dictionary, layer_id: String, composition: Array) -> void:
	if layer_id.is_empty():
		archetype["event_pool"] = composition.duplicate()
		archetype["required_event_ids"] = composition.duplicate()
		archetype["event_count"] = composition.size()
		return
	var layers := _dict(archetype.get("layers", {}))
	var layer := _dict(layers.get(layer_id, {}))
	layer["event_pool"] = composition.duplicate()
	layer["required_event_ids"] = composition.duplicate()
	layer["event_count"] = composition.size()
	layers[layer_id] = layer
	archetype["layers"] = layers


static func _restore_dictionary(target: Dictionary, source: Dictionary) -> void:
	target.clear()
	target.merge(source, true)


static func _scenario_definitions(library: Variant) -> Array:
	var result: Array = []
	for pool_value in library.environment_scenarios.values():
		for definition_value in _array(pool_value):
			var definition := SequenceCatalogScript.apply_overlay(_dict(definition_value), library.scenario_sequence_catalog)
			if not _dict(definition.get("sequence", {})).is_empty():
				result.append(definition.duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("id", "")) < str(right.get("id", "")))
	return result


static func _node_for_archetype(run_state: Variant, archetype_id: String) -> String:
	for node_value in _array(run_state.world_map.get("nodes", [])):
		var node := _dict(node_value)
		if str(node.get("archetype_id", "")) == archetype_id:
			return str(node.get("id", ""))
	return ""


static func _composition_label(composition: Array) -> String:
	if composition.is_empty():
		return "none"
	var values := PackedStringArray()
	for value in composition:
		values.append(str(value))
	return "+".join(values)


static func _membership_label(composition: Array) -> String:
	var values := composition.duplicate()
	values.sort()
	return _composition_label(values)


static func _normalized_pixel_rect(value: Variant) -> Rect2:
	var data := _dict(value)
	return Rect2(
		float(data.get("x", 0.0)) * 900.0,
		float(data.get("y", 0.0)) * 430.0,
		float(data.get("w", 0.0)) * 900.0,
		float(data.get("h", 0.0)) * 430.0
	)


static func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


static func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []
