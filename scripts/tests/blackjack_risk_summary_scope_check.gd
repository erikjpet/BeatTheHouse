extends SceneTree

const View := preload("res://scripts/ui/environment_interaction_view_model.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	var definitions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/games/games.json"))
	var blackjack: Dictionary = {}
	var slot: Dictionary = {}
	for definition in definitions:
		if str(definition.get("id", "")) == "blackjack": blackjack = definition
		if str(definition.get("id", "")) == "slot": slot = definition
	var before := definitions.duplicate(true)
	var warning := View.game_risk_summary(blackjack)
	check(not blackjack.is_empty() and not slot.is_empty(), "authored game definitions loaded")
	check(warning.contains("Caught Peek can forfeit the hand"), "conditional forfeiture warning")
	check(warning.contains("bar this table"), "conditional table consequence")
	check(warning.contains("total Heat up to %d" % RunState.BLACKJACK_BACKOFF_HEAT), "existing total Heat ceiling, not a static action delta")
	check(warning.contains("dealer attention and modifiers affect risk"), "context dependence is explicit")
	check(not warning.contains("as much as 8") and not warning.contains("as much as 6"), "raw Count/Peek deltas are not advertised maxima")
	check(View.game_risk_summary(blackjack, {"suspicion_delta": 42}) == warning, "Slot preview does not change Blackjack copy")
	var slot_summary := str(slot.cheat_actions[0].summary)
	check(View.game_risk_summary(slot, {"suspicion_delta":42}) == "%s Heat can rise by as much as 42 per nudge with current modifiers." % slot_summary, "watched Slot preview unchanged")
	check(View.game_risk_summary(slot, {"suspicion_delta":0}) == "%s Nudging adds no Heat with current modifiers." % slot_summary, "zero Slot preview unchanged")
	check(View.game_risk_summary(slot).contains("Base Heat can rise by as much as 12 before modifiers."), "Slot fallback unchanged")
	var generic := {"id":"other", "cheat_actions":[{"summary":"A considered risk.","suspicion_delta":7}]}
	check(View.game_risk_summary(generic) == "A considered risk. Heat can rise by as much as 7.", "generic warning unchanged")
	check(View.game_risk_summary({"id":"blackjack"}) == "No cheat action is offered at this game.", "empty-action semantics unchanged")
	check(definitions == before, "warning projection is read-only")
	check(View.game_risk_summary(blackjack) == warning, "repeat projection stable")
	var report := {"checks":checks,"failures":failures,"warning":warning,"fidelity":"Authored-data native presentation contract; no gameplay replay or Web claim."}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
	print("BLACKJACK_RISK_SUMMARY checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
