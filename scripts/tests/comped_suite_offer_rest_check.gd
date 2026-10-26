extends SceneTree

const Library := preload("res://scripts/core/content_library.gd")
const State := preload("res://scripts/core/run_state.gd")
const EnvironmentScript := preload("res://scripts/core/environment_instance.gd")
const Event := preload("res://scripts/core/event_module.gd")
const Generator := preload("res://scripts/core/run_generator.gd")
const Game := preload("res://scripts/core/game_module.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_check")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

func fixture(library: ContentLibrary) -> RunState:
	var state := State.new()
	state.start_new("COMPED-SUITE-OFFER")
	var archetype: Dictionary = library.archetype_by_id.get("grand_casino", {})
	var environment := EnvironmentScript.from_archetype(archetype, 3, state.create_rng("suite-environment"), library)
	state.set_environment(environment.to_dict())
	return state

func module(library: ContentLibrary) -> EventModule:
	var event := Event.new()
	event.setup(library.event("comped_suite_offer"), library)
	return event

func run_check() -> void:
	var library := Library.new()
	library.load(false)
	check(library.validation_errors.is_empty(), "Content library must load")
	var state := fixture(library)
	var event := module(library)
	check(event.can_trigger(state, state.current_environment), "Authored generated fixture must offer the comp")
	var cash := state.bankroll
	var before_rng := state.rng_state
	var result := event.resolve(state, state.current_environment, "take_comp")
	check(bool(result.get("ok", false)), "The actual offer must resolve")
	check(state.bankroll == cash + 10, "Existing cash award must remain exactly ten")
	check(state.rng_state == before_rng, "The deterministic comp must preserve the game RNG")
	check(state.drunk_level + state.pending_drunk_absorption_amount() == 8, "Existing alcohol intake must remain eight")
	check(int(state.narrative_flags.get("grand_casino_comp_suite_rests", 0)) == 1, "Taking the suite offer must grant one usable rest")
	var restored := State.new()
	restored.from_dict(state.to_dict())
	check(int(restored.narrative_flags.get("grand_casino_comp_suite_rests", 0)) == 1, "Continue must preserve one credit without granting it again")
	var replay_cash := state.bankroll
	var replay_rng := state.rng_state
	var replay := event.resolve(state, state.current_environment, "take_comp")
	check(not bool(replay.get("ok", true)), "A stale second acceptance must be rejected")
	check(state.bankroll == replay_cash and state.rng_state == replay_rng, "Rejected acceptance must not replay cash or RNG")
	check(int(state.narrative_flags.get("grand_casino_comp_suite_rests", 0)) == 1, "Rejected acceptance must not add another rest")
	var existing := fixture(library)
	existing.narrative_flags["grand_casino_comp_suite_rests"] = 2
	var stacked := module(library).resolve(existing, existing.current_environment, "take_comp")
	check(bool(stacked.get("ok", false)), "Offer with existing Players Card credits must resolve")
	check(int(existing.narrative_flags.get("grand_casino_comp_suite_rests", 0)) == 3, "Offer must add to, not replace, existing credits")
	var declined := fixture(library)
	var declined_cash := declined.bankroll
	var declined_result := module(library).resolve(declined, declined.current_environment, "decline")
	check(bool(declined_result.get("ok", false)), "Decline must remain available")
	var declined_restore := State.new()
	declined_restore.from_dict(declined.to_dict())
	check(int(declined_restore.narrative_flags.get("grand_casino_comp_suite_rests", 0)) == 0, "Decline must not grant a rest on Continue")
	check(declined_restore.bankroll == declined_cash, "Decline compatibility must not grant cash")
	# Synthetic old-save shape; the real accepted Web save is also qualified on
	# an isolated copy through the official load path, outside this fixture.
	var legacy_data := state.to_dict()
	var legacy_flags: Dictionary = (legacy_data["narrative_flags"] as Dictionary).duplicate(true)
	legacy_flags.erase("grand_casino_comp_suite_offer_grants")
	legacy_flags["grand_casino_comp_suite_rests"] = 2
	legacy_data["narrative_flags"] = legacy_flags
	var legacy := State.new()
	legacy.from_dict(legacy_data)
	check(int(legacy.narrative_flags.get("grand_casino_comp_suite_rests", 0)) == 3, "Old acceptance must restore one missing rest while preserving other credits")
	check(legacy.bankroll == state.bankroll and legacy.rng_state == state.rng_state, "Compatibility must not replay cash or RNG")
	check(legacy.drunk_level == state.drunk_level and legacy.pending_drunk_absorption_amount() == state.pending_drunk_absorption_amount(), "Compatibility must not replay alcohol")
	check(legacy.suspicion_level() == state.suspicion_level(), "Compatibility must not replay Heat")
	var legacy_again := State.new()
	legacy_again.from_dict(legacy.to_dict())
	check(int(legacy_again.narrative_flags.get("grand_casino_comp_suite_rests", 0)) == 3, "Repeated Continue must not repeat the compatibility grant")
	var generator := Generator.new(library)
	check(generator.enter_grand_casino_room(restored, State.GRAND_CASINO_CAGE_ARCHETYPE_ID), "The existing Cage service must be reachable")
	var rest := restored.grand_casino_players_card_comp_result("suite_rest")
	check(bool(rest.get("ok", false)), "One offer credit must enable Linda's existing rest service")
	check(int(rest.get("duration_minutes", 0)) == 240, "The existing four-hour rest rule must remain unchanged")
	var cash_before_rest := restored.bankroll
	var rng_before_rest := restored.rng_state
	Game.apply_result(restored, rest)
	check(int(restored.narrative_flags.get("grand_casino_comp_suite_rests", 0)) == 0, "Using the rest must consume exactly one credit")
	check(restored.bankroll == cash_before_rest and restored.rng_state == rng_before_rest, "Rest must not change cash or game RNG")
	check(restored.drunk_level == 0 and restored.pending_drunk_absorption_amount() == 0, "Rest must preserve the existing alcohol recovery")
	var spent := State.new()
	spent.from_dict(restored.to_dict())
	check(int(spent.narrative_flags.get("grand_casino_comp_suite_rests", 0)) == 0, "Continue after use must not replenish the spent offer credit")
	check(not bool(spent.grand_casino_players_card_comp_result("suite_rest").get("ok", true)), "A second rest must remain unavailable")
	print("COMPED_SUITE_REST_CHECK ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
