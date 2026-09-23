extends SceneTree

const GameModuleRegistryScript := preload("res://scripts/core/game_module_registry.gd")
const GameModuleScript := preload("res://scripts/core/game_module.gd")
const GameRitualRuntimeScript := preload("res://scripts/core/game_ritual_runtime.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const CardShoeScript := preload("res://scripts/core/card_shoe.gd")
const RngStreamScript := preload("res://scripts/core/rng_stream.gd")
const SLOT_RESOLVER_PATH := "res://scripts/games/slots/slot_resolver.gd"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_static_game_capabilities()
	_check_archetype_index()
	_check_card_copy_boundaries()
	_check_rng_shuffles()
	_check_slot_owned_result_builder()
	if failures.is_empty():
		print("HEALTH06_1_HOT_PATHS PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_static_game_capabilities() -> void:
	var ordinary := {"id": "blackjack", "module_path": "res://scripts/games/blackjack.gd"}
	_expect(not GameModuleRegistryScript.definition_declares_recovery_hook(ordinary), "CH-12: ordinary game reports a recovery-hook capability.")
	_expect(not GameModuleRegistryScript.definition_defers_bankroll_zero(ordinary), "CH-12: ordinary game reports a bankroll-zero capability.")
	var recovery := {"declares_recovery_hook": true, "defers_bankroll_zero": true}
	_expect(GameModuleRegistryScript.definition_declares_recovery_hook(recovery), "CH-12: authored recovery capability is not visible statically.")
	_expect(GameModuleRegistryScript.definition_defers_bankroll_zero(recovery), "CH-12: authored bankroll-zero capability is not visible statically.")


func _check_archetype_index() -> void:
	var library := ContentLibraryScript.new()
	library.environment_archetypes = [{"id": "health_shop", "kind": "shop"}]
	library.rebuild_content_indexes()
	_expect(library.archetype_by_id.has("health_shop"), "CH-12: archetype_by_id was not populated.")
	_expect(str(library.environment_archetype("health_shop").get("kind", "")) == "shop", "CH-12: indexed archetype lookup failed.")
	# Preserve the fixture-supported direct-array replacement behavior.
	library.environment_archetypes = [{"id": "replacement", "kind": "casino"}]
	_expect(str(library.environment_archetype("replacement").get("kind", "")) == "casino", "CH-12: direct fixture replacement did not refresh the explicit index.")
	_expect(library.archetype_by_id.has("replacement"), "CH-12: refreshed explicit archetype index is stale.")


func _check_card_copy_boundaries() -> void:
	var first := {"rank": 14, "suit": 1, "deck": 0}
	var second := {"rank": 10, "suit": 2, "deck": 0}
	var source: Array = [first, second]
	var array_copy := CardShoeScript.card_array(source)
	_expect(array_copy.size() == 2 and is_same(array_copy[0], first), "CH-13: card_array is not a shallow array copy.")
	array_copy.pop_back()
	_expect(source.size() == 2, "CH-13: card_array aliases the source array.")
	var draw := CardShoeScript.draw_cards(source, 1)
	var drawn: Array = draw.get("cards", [])
	var remaining: Array = draw.get("shoe", [])
	_expect(drawn.size() == 1 and not is_same(drawn[0], first), "CH-13: handed-out card was not isolated.")
	_expect(remaining.size() == 1 and is_same(remaining[0], second), "CH-13: an undrawn shoe card was deep-copied.")
	if not drawn.is_empty():
		(drawn[0] as Dictionary)["rank"] = 2
	_expect(int(first.get("rank", 0)) == 14, "CH-13: mutating a handed-out card changed the shoe source.")


func _check_rng_shuffles() -> void:
	var nested := {"id": "nested"}
	var values: Array = [nested, "b", "c", "d"]
	var first_rng := RngStreamScript.new()
	var second_rng := RngStreamScript.new()
	first_rng.configure(407)
	second_rng.configure(407)
	var first_shuffle := first_rng.shuffled(values)
	var second_shuffle := second_rng.shuffled(values)
	_expect(first_shuffle == second_shuffle, "CH-14: seeded shuffle is not deterministic.")
	_expect(first_shuffle.size() == values.size() and first_shuffle.has(nested), "CH-14: shuffle is not a permutation.")
	_expect(values[0] == nested and values[1] == "b", "CH-14: shuffle mutated its input array.")
	var nested_index := first_shuffle.find(nested)
	_expect(nested_index >= 0 and is_same(first_shuffle[nested_index], nested), "CH-14: shuffle deep-copied a nested value.")
	var partial_rng := RngStreamScript.new()
	partial_rng.configure(19)
	var partial := partial_rng.pick_many([nested, "x"], 1)
	if not partial.is_empty() and typeof(partial[0]) == TYPE_DICTIONARY:
		_expect(is_same(partial[0], nested), "CH-14: partial selection deep-copied a nested value.")


func _check_slot_owned_result_builder() -> void:
	var source := FileAccess.get_file_as_string(SLOT_RESOLVER_PATH)
	var function_start := source.find("func _spin_result(")
	var function_end := source.find("\nfunc _message_for_spin(", function_start)
	_expect(function_start >= 0 and function_end > function_start, "CH-13: Slot spin result builder boundary is unavailable.")
	if function_start < 0 or function_end <= function_start:
		return
	var function_source := source.substr(function_start, function_end - function_start)
	_expect(function_source.find("GameModule.build_canonical_owned_action_result(") >= 0, "CH-13: Slot spins do not transfer their fresh canonical deltas to the owned result builder.")
	_expect(function_source.find("GameModule.build_action_result(") < 0, "CH-13: Slot spins still route through the recursively copying result builder.")

	var copied_deltas := _representative_slot_deltas()
	var owned_deltas := _representative_slot_deltas()
	var copied := GameModuleScript.build_action_result(_representative_slot_payload(copied_deltas))
	var owned := GameModuleScript.build_canonical_owned_action_result(_representative_slot_payload(owned_deltas))
	_expect(
		GameRitualRuntimeScript.canonical_json(copied) == GameRitualRuntimeScript.canonical_json(owned),
		"CH-13: canonical owned Slot result construction changed the public result shape."
	)
	var copied_result_deltas: Dictionary = copied.get("deltas", {})
	var owned_result_deltas: Dictionary = owned.get("deltas", {})
	var copied_messages: Array = copied.get("messages", [])
	var copied_delta_messages: Array = copied_result_deltas.get("messages", [])
	var owned_messages: Array = owned.get("messages", [])
	var owned_delta_messages: Array = owned_result_deltas.get("messages", [])
	_expect(not is_same(copied_messages, copied_delta_messages), "CH-13: copying result builder aliases public messages to delta messages.")
	_expect(not is_same(owned_messages, owned_delta_messages), "CH-13: owned result builder aliases public messages to delta messages.")
	if not copied_messages.is_empty():
		copied_messages[0] = "Mutated copied presentation."
	if not owned_messages.is_empty():
		owned_messages[0] = "Mutated owned presentation."
	_expect(copied_delta_messages == ["Slot fixture lost $2."], "CH-13: copying result presentation mutation escaped into delta messages.")
	_expect(owned_delta_messages == ["Slot fixture lost $2."], "CH-13: owned result presentation mutation escaped into delta messages.")
	var copied_story: Array = copied_result_deltas.get("story_log", [])
	var owned_story: Array = owned_result_deltas.get("story_log", [])
	if not copied_story.is_empty() and typeof(copied_story[0]) == TYPE_DICTIONARY:
		(copied_story[0] as Dictionary)["classification"] = "mutated"
	_expect(not owned_story.is_empty() and str((owned_story[0] as Dictionary).get("classification", "")) == "zero_loss", "CH-13: independent owned and copying Slot results share nested story state.")


func _representative_slot_deltas() -> Dictionary:
	var deltas := GameModuleScript.empty_result_deltas()
	deltas["bankroll_delta"] = -2
	deltas["messages"] = ["Slot fixture lost $2."]
	deltas["story_log"] = [{
		"type": "game_action",
		"slot_event": "slot_spin",
		"game_id": "slot",
		"action_id": "spin",
		"classification": "zero_loss",
		"stake_cost": 2,
		"bankroll_delta": -2,
	}]
	return deltas


func _representative_slot_payload(deltas: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"type": "game_action",
		"source_id": "slot",
		"game_id": "slot",
		"action_id": "spin",
		"action_kind": "legal",
		"stake": 2,
		"deltas": deltas,
		"won": false,
		"environment_id": "practice_slot",
		"message": "Slot fixture lost $2.",
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
