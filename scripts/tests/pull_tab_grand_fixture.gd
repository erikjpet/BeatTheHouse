extends RefCounted

# Explicit historical content fixture, never a repair/import of a campaign.
# Grand replaced this machine after 89403f389. Keep the old authored catalog as
# a declared test input so Grand chip funding, scenarios and portable-ticket
# custody remain covered. Production code still generates stock, validates room
# authority and performs every ticket purchase; no seal or result is supplied.
const State := preload("res://scripts/core/run_state.gd")
const Map := preload("res://scripts/core/world_map.gd")
const Generator := preload("res://scripts/core/run_generator.gd")
const Meta := preload("res://scripts/core/meta_collection_service.gd")
const Resolver := preload("res://scripts/core/collection_item_resolver.gd")
const Drops := preload("res://scripts/core/collection_drop_service.gd")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const Placement := preload("res://scripts/core/environment_placement.gd")
const PlacementStore := preload("res://scripts/core/developer_placement_store.gd")
const LegacyLayout := preload("res://scripts/core/grand_coin_pusher_layout_compatibility.gd")
const HISTORICAL_PATH := "res://scripts/tests/fixtures/pull_tab_grand_historical_89403f389.json"
const HISTORICAL_COMMIT := "89403f389a5807e050a450cd27b1bd93b3a4a41e"
const HISTORICAL_NORMALIZED_SHA256 := "ceaaed865572cd7f8cd031230b1188f5640ec6fb9e672e0766e370eea644f820"
static var _historical_content: Dictionary = {}


static func prepare_historical_content(app: Variant) -> Dictionary:
	var errors: Array[String] = []
	if app == null:
		return {"ok": false, "errors": ["Historical fixture requires its own initialized host"]}
	app.call("_ensure_full_content_library_loaded")
	var library: ContentLibrary = app.get("library")
	if library == null:
		return {"ok": false, "errors": ["Historical fixture host has no loaded ContentLibrary"]}
	var owner_id: int = app.get_instance_id()
	if _historical_content.has(owner_id):
		var prior: Dictionary = _historical_content[owner_id]
		if not is_same(library, prior.get("library")) or library.environment_archetype(State.GRAND_CASINO_ARCHETYPE_ID) != prior.get("archetype", {}):
			errors.append("Historical content owner or pinned archetype changed during fixture reuse")
		return {"ok": errors.is_empty(), "facts": prior.get("facts", {}).duplicate(true), "errors": errors}
	var text := FileAccess.get_file_as_string(HISTORICAL_PATH)
	if text.replace("\r\n", "\n").sha256_text() != HISTORICAL_NORMALIZED_SHA256:
		return {"ok": false, "errors": ["Historical Grand content fixture does not match its pinned normalized SHA256"]}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "errors": ["Historical Grand content fixture is not a dictionary"]}
	var pinned: Dictionary = parsed
	var source: Dictionary = pinned.get("source", {})
	var archetype: Dictionary = pinned.get("archetype", {})
	if str(pinned.get("schema", "")) != "bth_test_historical_grand_archetype" or int(pinned.get("version", 0)) != 1 \
			or str(source.get("commit", "")) != HISTORICAL_COMMIT or str(source.get("archetype_blob", "")) != "6d44569ed2af04efba3cb9b7cc7ffc32832203de" \
			or str(archetype.get("id", "")) != State.GRAND_CASINO_ARCHETYPE_ID \
			or not archetype.get("game_pool", []).has("pull_tabs") or archetype.get("game_pool", []).has("coin_pusher"):
		return {"ok": false, "errors": ["Historical Grand fixture identity/membership does not match the declared pre-change catalog"]}
	var current := library.environment_archetype(State.GRAND_CASINO_ARCHETYPE_ID)
	if not current.get("game_pool", []).has("coin_pusher") or current.get("game_pool", []).has("pull_tabs"):
		return {"ok": false, "errors": ["Fresh current Grand catalog must expose its replacement Coin Pusher before historical test setup"]}
	var original_archetypes: Array = library.environment_archetypes
	var replacement := original_archetypes.duplicate(true)
	var grand_index := -1
	for index in range(replacement.size()):
		if str(replacement[index].get("id", "")) == State.GRAND_CASINO_ARCHETYPE_ID:
			grand_index = index
			break
	if grand_index < 0:
		return {"ok": false, "errors": ["Current library has no unique Grand archetype to replace in this historical fixture"]}
	var shipping_hash := FileAccess.get_sha256(ContentLibrary.ENVIRONMENT_ARCHETYPES_PATH)
	replacement[grand_index] = archetype.duplicate(true)
	# This is ContentLibrary's documented fixture seam. Replace this host's
	# public array and rebuild indexes; never patch production files or placement
	# caches. The normal legacy-room compatibility path owns historical geometry.
	library.environment_archetypes = replacement
	library.rebuild_content_indexes()
	if FileAccess.get_sha256(ContentLibrary.ENVIRONMENT_ARCHETYPES_PATH) != shipping_hash:
		errors.append("Historical setup changed the fresh shipping archetype file")
	var facts := {"content_mode": "explicit_historical_grand", "historical_source": source.duplicate(true), "historical_fixture_normalized_sha256": HISTORICAL_NORMALIZED_SHA256, "fresh_current_grand_game_pool": current.get("game_pool", []).duplicate(), "shipping_archetypes_sha256": shipping_hash, "placement_source": "production legacy-room compatibility; no fixture map override"}
	_historical_content[owner_id] = {"library": library, "archetypes": original_archetypes, "archetype": archetype, "facts": facts, "proof": pinned.get("pull_tab_placement_proof", {}).duplicate(true)}
	return {"ok": errors.is_empty(), "facts": facts.duplicate(true), "errors": errors}


static func restore_current_content(app: Variant) -> bool:
	if app == null or not _historical_content.has(app.get_instance_id()):
		return true
	var owner_id: int = app.get_instance_id()
	var prior: Dictionary = _historical_content[owner_id]
	var library: ContentLibrary = prior.get("library")
	library.environment_archetypes = prior.get("archetypes", [])
	library.rebuild_content_indexes()
	_historical_content.erase(owner_id)
	var current := library.environment_archetype(State.GRAND_CASINO_ARCHETYPE_ID)
	return current.get("game_pool", []).has("coin_pusher") and not current.get("game_pool", []).has("pull_tabs") \
			and FileAccess.get_sha256(ContentLibrary.ENVIRONMENT_ARCHETYPES_PATH) == str(prior.get("facts", {}).get("shipping_archetypes_sha256", ""))


static func authority_receipt(run: RunState) -> Dictionary:
	var environment := run.current_environment
	var layout: Dictionary = environment.get("layout", {})
	return {"slot_map_digest": str(layout.get("slot_map_digest", "")), "scenario_semantic_inventory_version": int(environment.get("scenario_semantic_inventory_version", 0)), "scenario_semantic_digest": str(environment.get("scenario_semantic_digest", "")), "scenario_layout_authority_digest": str(environment.get("scenario_layout_authority_digest", ""))}


static func _historical_placement_errors(app: Variant, environment: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var proof: Dictionary = _historical_content.get(app.get_instance_id(), {}).get("proof", {})
	var surface := Placement.surface_map(environment)
	var wanted_slot := str(proof.get("object_slot_id", ""))
	if str(surface.get("fixed_object_slot_ids", {}).get("game:pull_tabs", "")) != wanted_slot \
			or str(surface.get("class_overrides", {}).get("game:pull_tabs", "")) != str(proof.get("class_override", "")) \
			or str(surface.get("object_family_ids", {}).get("game:pull_tabs", "")) != str(proof.get("object_family_id", "")):
		errors.append("Production legacy-room map did not retain the pinned historical Pull Tabs slot authority")
	var actual_slot: Dictionary = {}
	for slot in surface.get("fixed_slots", []):
		if str(slot.get("id", "")) == wanted_slot:
			actual_slot = slot
			break
	# The pinned slot is authored geometry. The approved placement layer has
	# always moved this cabinet rigidly (base/current target [762,157]). Prove
	# raw historical authority separately, then compose that same approved layer
	# for the runtime comparison instead of comparing runtime to unshifted JSON.
	var authored := LegacyLayout.surface_map(Placement._shipping_surface_map(environment), LegacyLayout.profile_id(environment))
	var authored_slot := _fixed_slot(authored, wanted_slot)
	var pinned_slot: Dictionary = proof.get("fixed_slot", {})
	if _transport(authored_slot) != _transport(pinned_slot):
		errors.append("Historical Pull Tabs authored slot differs from the full pinned pre-change slot")
	var expected_slot := _runtime_expected_slot(pinned_slot, wanted_slot, environment)
	if _transport(actual_slot) != _transport(expected_slot):
		var keys: Array = expected_slot.keys()
		for key in actual_slot:
			if not keys.has(key):
				keys.append(key)
		for key in keys:
			if _transport(actual_slot.get(key)) != _transport(expected_slot.get(key)):
				errors.append("Historical Pull Tabs runtime fixed-slot field differs from approved composition: " + str(key))
	_historical_content[app.get_instance_id()]["slot_observation"] = {"pinned_authored_slot": pinned_slot.duplicate(true), "actual_authored_slot": authored_slot.duplicate(true), "expected_runtime_slot": expected_slot.duplicate(true), "actual_runtime_slot": actual_slot.duplicate(true)}
	return errors


static func _fixed_slot(surface: Dictionary, slot_id: String) -> Dictionary:
	for slot in surface.get("fixed_slots", []):
		if str(slot.get("id", "")) == slot_id:
			return slot
	return {}


static func _runtime_expected_slot(pinned: Dictionary, slot_id: String, environment: Dictionary) -> Dictionary:
	var result := pinned.duplicate(true)
	var positions := PlacementStore.slot_overrides(environment, "slot_positions")
	if positions.has(slot_id):
		var target: Array = positions[slot_id]
		var origin: Array = pinned.get("pos", [])
		var dx := float(target[0]) - float(origin[0])
		var dy := float(target[1]) - float(origin[1])
		result["pos"] = [float(target[0]), float(target[1])]
		var hit: Array = pinned.get("hit_rect", []).duplicate()
		hit[0] = float(hit[0]) + dx
		hit[1] = float(hit[1]) + dy
		result["hit_rect"] = hit
		var anchor: Array = pinned.get("label_anchor", []).duplicate()
		anchor[0] = float(anchor[0]) + dx
		anchor[1] = float(anchor[1]) + dy
		result["label_anchor"] = anchor
	var layers := PlacementStore.slot_layer_overrides(environment)
	if layers.has(slot_id):
		result["draw_layer"] = clampi(int(layers[slot_id]), -1, 1)
	var scales := PlacementStore.slot_scale_overrides(environment)
	if scales.has(slot_id):
		result["object_scale"] = clampf(float(scales[slot_id]), PlacementStore.SLOT_SCALE_MIN, PlacementStore.SLOT_SCALE_MAX)
	return result


static func _transport(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


static func create(app: Variant, seed: String, options: Dictionary = {}) -> Dictionary:
	var errors: Array[String] = []
	var requested_scenario := str(options.get("scenario_id", "")).strip_edges()
	var facts: Dictionary = {
		"fidelity": "Independent synthetic initial state using explicit pre-change Grand content pinned to89403f389; no campaign/save, purchased ticket or outcome imported. Current Grand content is not claimed.",
		"seed": seed,
		"initial_cash": 94,
		"initial_chips": 15,
		"initial_heat": 0,
		"starting_state_only": true,
		"requested_scenario_id": requested_scenario,
	}
	if app == null or seed.strip_edges().is_empty():
		errors.append("Fixture requires an initialized host and an explicit independent seed")
		return {"ok": false, "run": null, "facts": facts, "errors": errors}
	var historical := prepare_historical_content(app)
	if not bool(historical.get("ok", false)):
		return {"ok": false, "run": null, "facts": facts, "errors": historical.get("errors", [])}
	facts.merge(historical.get("facts", {}), true)
	var library: ContentLibrary = app.get("library")
	if library == null:
		errors.append("Fixture host has no content library")
		return {"ok": false, "run": null, "facts": facts, "errors": errors}
	if options.has("clock_minutes") and (typeof(options["clock_minutes"]) != TYPE_INT or int(options["clock_minutes"]) < 0):
		errors.append("Fixture initial clock_minutes must be a nonnegative integer")
		return {"ok": false, "run": null, "facts": facts, "errors": errors}
	if not requested_scenario.is_empty():
		var scenario: Dictionary = library.scenario(requested_scenario)
		if scenario.is_empty() or str(scenario.get("archetype_id", "")) != State.GRAND_CASINO_ARCHETYPE_ID:
			errors.append("Fixture scenario pin must name an authored Grand main-floor scenario")
			return {"ok": false, "run": null, "facts": facts, "errors": errors}
	# A newly constructed service owns only this isolated fixture's profile.
	# Save it through the normal boundary so Continue sees the same carried card.
	var meta := Meta.new()
	var card: Dictionary = meta.mint_players_card({
		"tier_reached": "gold", "seed": seed, "route": "high_roller_cashout",
	})
	var carried: Dictionary = meta.ensure_players_card_carried(int(card.get("instance_id", 0)))
	if card.is_empty() or not bool(carried.get("ok", false)) or not bool(carried.get("carried", false)):
		errors.append("Fresh fixture Gold card could not be minted/carried")
		return {"ok": false, "run": null, "facts": facts, "errors": errors}
	var resolver := Resolver.new()
	var card_item: Dictionary = resolver.resolve_run_item(card)
	if card_item.is_empty() or str(card_item.get("meta_collection", {}).get("players_card_tier", "")) != "gold":
		errors.append("Fresh carried Gold card did not resolve through the production item resolver")
		return {"ok": false, "run": null, "facts": facts, "errors": errors}
	if meta.save() != OK:
		errors.append("Fresh fixture meta profile did not save")
		return {"ok": false, "run": null, "facts": facts, "errors": errors}
	app.set("meta_collection_service", meta)
	var modifiers: Dictionary = meta.normal_run_start_modifiers()
	var challenge: Dictionary = State.standard_challenge(seed)
	var challenge_modifiers: Dictionary = challenge.get("modifiers", {}).duplicate(true)
	challenge_modifiers.merge(modifiers, true)
	# Pin authored selection before world priming/generation. Production code
	# applies its complete mutations and seals; no installed room is rewritten.
	if not requested_scenario.is_empty():
		challenge_modifiers["scenario_pins"] = {State.GRAND_CASINO_ARCHETYPE_ID: requested_scenario}
	challenge["modifiers"] = challenge_modifiers
	var run := State.new()
	run.start_new(seed, challenge)
	if options.has("clock_minutes"):
		run.game_clock_minutes = int(options["clock_minutes"])
	var initial_clock := run.game_clock_minutes
	facts["initial_clock_minutes"] = initial_clock
	run.inventory.append(card_item.duplicate(true))
	run.invalidate_inventory_effect_cache()
	run.change_bankroll(94 - run.bankroll, true)
	run.change_grand_casino_chips(15 - run.grand_casino_chips, true)
	var map_data: Dictionary = Map.new(library).build(run, run.create_rng("pull_tab_grand_fixture_world"))
	run.set_world_map(map_data)
	var generator := Generator.new(library)
	var arrival: Dictionary = Fidelity.generate_and_finalize(
		generator, run, errors, "Independent Pull Tabs Grand fixture arrival", State.GRAND_CASINO_ARCHETYPE_ID, true
	)
	if not bool(arrival.get("ok", false)):
		return {"ok": false, "run": run, "facts": facts, "errors": errors}
	if str(run.current_environment.get("archetype_id", "")) != State.GRAND_CASINO_ARCHETYPE_ID:
		errors.append("Production fixture arrival did not install Grand main floor")
	if not requested_scenario.is_empty() and str(run.current_environment.get("scenario_id", "")) != requested_scenario:
		errors.append("Production Grand generation did not honor the requested scenario pin")
	if run.game_clock_minutes != initial_clock:
		errors.append("Fixture generation changed its declared initial clock")
	if not bool(run.validate_room_action_authority().get("ok", false)):
		errors.append("Generated Grand room action authority failed validation")
	if not run.current_environment.get("game_ids", []).has("pull_tabs"):
		errors.append("Generated explicit historical Grand main floor does not expose Pull Tabs")
	if run.current_environment.get("game_ids", []).has("coin_pusher"):
		errors.append("Historical Pull Tabs fixture unexpectedly exposed the current Grand Coin Pusher")
	errors.append_array(_historical_placement_errors(app, run.current_environment))
	facts["historical_pull_tab_slot"] = _historical_content.get(app.get_instance_id(), {}).get("slot_observation", {}).duplicate(true)
	if run.bankroll != 94 or run.grand_casino_chips != 15 or run.suspicion_level() != 0 or run.is_terminal():
		errors.append("Generated fixture did not preserve active94cash15chipsHeat0")
	var bag_definition: Dictionary = resolver.bag_definition(9000)
	if str(bag_definition.get("tier", "")) != "blue":
		errors.append("Production Roadside Luck Blue Bag definition9000 is unavailable")
	else:
		var drop_service := Drops.new()
		var marker: Dictionary = drop_service.marker_from_static_bag(9000, "independent_start", "pull_tabs_grand", seed + "|blue-bag")
		var added: Dictionary = run.add_pending_bag_marker(marker)
		if added.is_empty() or run.pending_bags.size() != 1:
			errors.append("Fixture unclaimed Blue Bag marker was not retained once")
		facts["pending_bag_marker"] = added.duplicate(true)
	var game: GameModule = app.call("_game_module_for_id", "pull_tabs")
	var stock: Dictionary = run.current_environment.get("game_states", {}).get("pull_tabs", {})
	var deals: Array = stock.get("deals", [])
	var two_dollar_index := -1
	for index in range(deals.size()):
		if int(deals[index].get("price", 0)) == 2 and int(deals[index].get("remaining", 0)) > 0:
			two_dollar_index = index
			break
	if game == null or two_dollar_index < 0:
		errors.append("Generated Grand stock has no naturally priced available $2 deal")
	facts.merge({
		"room_id": run.current_environment.get("id", ""),
		"scenario_id": run.current_environment.get("scenario_id", ""),
		"clock_minutes": run.game_clock_minutes,
		"clock_display": run.clock_display_text(),
		"world_node_id": run.current_world_node_id(),
		"card_instance_id": card.get("instance_id", 0),
		"card_item_id": card_item.get("id", ""),
		"card_tier": "gold", "bagdef_id": 9000,
		"two_dollar_deal_index": two_dollar_index,
		"room_authority_valid": bool(run.validate_room_action_authority().get("ok", false)),
		"historical_room_authority": authority_receipt(run),
		"rng": str(run.rng_state),
	}, true)
	return {"ok": errors.is_empty(), "run": run, "facts": facts, "errors": errors}
