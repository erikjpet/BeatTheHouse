extends SceneTree

const Main := preload("res://scripts/ui/foundation_main.gd")
const Text := preload("res://scripts/ui/player_text.gd")
const Drop := preload("res://scripts/core/collection_drop_service.gd")

class RejectedRoom extends RunState:
	func validate_room_action_authority(_require_renderer_proofs: bool = true) -> Dictionary:
		return {"ok":false, "errors":["synthetic rejected room"]}

class RejectedTier extends RunState:
	func demo_objective_status(_environment: Dictionary = {}) -> Dictionary:
		return {"players_card_eligible":true, "players_card_ready_to_claim":true, "players_card_can_claim":true, "players_card_next_tier":"bronze"}
	func _grant_grand_casino_players_card_tier(_target_tier: String, _queue_dialogue: bool) -> bool:
		return false

class IncompleteHeist extends CrewRunFacade:
	func crew_heist_lock(_plan_id: String, _host_capability: Variant = null) -> Dictionary:
		return {"ok":true}

class BusyGame extends GameModule:
	func foundation_save_ready(_run_state: RunState, _environment: Dictionary) -> bool: return false

var checks := 0
var failures: Array[String] = []
var observations: Array = []
const ROOM := "That can't be used right now. Try another action."
const COLLECTION := "Your collection could not be saved. Keep this run open and choose Save to retry."
const REWARD := "Your run's reward couldn't be checked. Keep this run open and choose Save to retry."
const COUNTER := "The counter couldn't complete that action. Nothing was changed; try again."

func _init() -> void: call_deferred("_run")

func _message(label: String, result: Dictionary, original: String, expected: String) -> void:
	observations.append({"case":label, "message":result.get("message", ""), "diagnostic":original, "ok":result.get("ok", false), "error_code":result.get("error_code", "")})
	_check(not bool(result.get("ok", false)), label + " preserves rejection")
	_check(str(result.get("message", "")) == expected, label + " player wording")

func _run() -> void:
	var tier := RejectedTier.new()
	tier.start_new("QOL03-TIER")
	tier.current_environment = {"archetype_id":RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID}
	_message("card_tier", tier.claim_grand_casino_players_card_tier(), "The Players Card tier sequence is invalid.", "Linda can't upgrade this card right now. Keep playing and ask her again later.")

	var meta := MetaCollectionService.new()
	_message("terminal_receipt", meta.commit_terminal_special_outcome("bad", "{}"), "The terminal collection receipt is invalid.", COLLECTION)
	_message("terminal_intent", meta.commit_terminal_special_outcome("terminal-outcome:1", "{}"), "The terminal collection intent is invalid.", COLLECTION)
	_message("terminal_incomplete", meta.commit_terminal_special_outcome("terminal-outcome:1", '{"schema_version":1}'), "The terminal collection intent is incomplete.", COLLECTION)
	var plan := {"schema_version":1, "failed":false, "skip_failure_decay":false, "carried_ids":[], "card_stamp":{}, "chip_stamp":{}, "prestige_result":{}, "prestige":false}
	meta.set("_store", {"terminal_special_outcomes":{"terminal-outcome:1":{"intent_json":"different", "result":{"ok":true}}}})
	_message("terminal_mismatch", meta.commit_terminal_special_outcome("terminal-outcome:1", JSON.stringify(plan)), "The terminal collection receipt does not match its outcome.", COLLECTION)
	_message("reward_missing", meta.commit_terminal_bag_claim("", {}), "The completed run's reward receipt is unavailable.", REWARD)
	meta.set("_store", {"terminal_bag_claims":{"fixture":{}}})
	_message("reward_invalid", meta.commit_terminal_bag_claim("fixture", {}), "The stored reward receipt could not be verified.", REWARD)
	meta = MetaCollectionService.new()
	_message("sal_missing", meta.generate_and_insert_sal_stock(""), "Sal stock needs a run receipt.", "Sal can't update the shelf yet. Choose Save to retry.")

	var run := RunState.new()
	run.start_new("QOL03-CREW")
	run.current_environment = {"id":"qol03_room", "archetype_id":"bar", "active_game_id":"blackjack"}
	var before_cash := run.bankroll
	_message("crew_play", run.crew_play_activate("missing_play", "blackjack", run.current_environment), "The table host rejected an incomplete play transaction.", "The table couldn't finish that play. Try the action again.")
	_check(run.bankroll == before_cash, "rejected Crew play preserves money")

	var heist := IncompleteHeist.new()
	heist.set("_run", run)
	_message("heist_step", heist.crew_heist_event_action({"action":"lock", "plan_id":"the_count"}, heist.heist_host_capability), "The heist receipt could not be committed.", "The crew couldn't finish that step. Try the action again.")
	var ended := RunState.new()
	ended.start_new("QOL03-REWARD")
	ended.challenge_config = {"mode":"standard", "modifiers":{"meta_collection_enabled":true}}
	ended.run_status = RunState.RUN_STATUS_ENDED
	_message("drop_reward_missing", Drop.new().reconcile_terminal_bag_claim(ended, meta), "The completed run's reward receipt is unavailable.", REWARD)

	var app := Main.new()
	app.set("run_state", run)
	app.set("save_service", SaveService.new())
	app.set("current_game", BusyGame.new())
	var saved: bool = app.call("_autosave_foundation_run", "Save.", true)
	_message("busy_save", {"ok":saved, "message":app.get("save_status_message")}, "Save waits for the live machine to settle.", "Finish the current play, then save.")
	app.set("current_game", null)
	app.set("room_publication_generation", 2)
	app.set("room_publication_checked_generation", 1)
	saved = app.call("_write_foundation_run_save", "Save.", true)
	_message("room_save", {"ok":saved, "message":app.get("save_status_message")}, "Room check pending; existing save retained.", "Can't save this room yet. Your last save is safe; try Save again shortly.")

	var rejected := RejectedRoom.new()
	rejected.start_new("QOL03-ROOM")
	rejected.current_environment = {"id":"qol03_room", "archetype_id":"bar"}
	var label := Label.new()
	app.set("message_label", label)
	app.set("run_state", rejected)
	var available: bool = app.call("_room_action_authority_available")
	_message("room_action", {"ok":available, "message":label.text}, "Room object authority is invalid.", ROOM)
	var event := EventModule.new()
	_message("event_room", event.call("_resolve_event_choice", rejected, rejected.current_environment, "fixture"), "Room object authority is invalid.", ROOM)
	label.free()
	app.free()

	var service := RunActionService.new()
	var service_cases := {
		"The pawn quote changed before the transaction could commit.":"The pawn price changed. Ask for a new quote.",
		"The pawn transaction could not settle safely.":"The pawn counter couldn't finish the sale. Nothing was sold; try again.",
		"The pawn transaction was cancelled because its settlement ended the run.":"That sale would end your run, so it was cancelled. Choose another action.",
		"The pawn transaction could not publish its completed state.":"The pawn counter couldn't finish the sale. Nothing was sold; try again.",
		"The service transaction could not settle safely.":COUNTER,
		"The service transaction was cancelled because its settlement ended the run.":"That action would end your run, so it was cancelled. Choose another action.",
		"The transaction could not publish its completed state.":COUNTER,
	}
	for diagnostic in service_cases:
		var result: Dictionary = service.call("_service_error", diagnostic)
		_message("counter", result, diagnostic, service_cases[diagnostic])
		_check(result.get("error_code") == "service_rejected", "counter rejection error code unchanged")
	_message("sealed_action", {"ok":false, "message":Text.resolve("sealed_action.receipt_missing")}, "The action receipt could not be verified. Nothing was changed.", "The previous action couldn't be checked. Nothing was changed; try the action again.")
	print("QOL03_PLAYER_WORDING " + JSON.stringify({"checks":checks, "failures":failures, "observations":observations}))
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error("QOL-03: " + label)
