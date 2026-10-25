extends SceneTree

const Main := preload("res://scripts/ui/foundation_main.gd")
const Run := preload("res://scripts/core/run_state.gd")

# Presence is synthetic; purchase, knowledge, money and snapshot methods remain
# production RunState. No player profile or environment authority is rewritten.
class EncounterRun extends Run:
	var silas_here := true
	func numbers_silas_is_here() -> bool: return silas_here

class EncounterHost extends Main:
	var saves := 0
	var saved_state: Dictionary = {}
	func _refresh() -> void: pass
	func _refresh_talk_dock() -> void: pass
	func _refresh_world_header(_selected_world_object_override: Dictionary = {}) -> void: pass
	func _refresh_embedded_action_hud() -> void: pass
	func _autosave_foundation_run(_status_text: String = "Autosaved.", _force: bool = false) -> bool:
		saves += 1
		saved_state = run_state.to_dict()
		return true

var checks := 0
var failures: Array[String] = []

func _init() -> void: call_deferred("_run")

func _run() -> void:
	var host := EncounterHost.new()
	host.FoundationActionViewModelScript = load("res://scripts/ui/foundation_action_view_model.gd")
	host.TerminalConsequenceViewModelScript = load("res://scripts/ui/terminal_consequence_view_model.gd")
	var run := EncounterRun.new()
	run.start_new("SILAS-DIALOGUE-FEEDBACK")
	host.run_state = run
	host.last_hook_result = {"ok": true, "type": "event", "message": "Previous door event."}
	var before := run.bankroll
	var emissions := [0]
	run.money_changed.connect(func(_revision: int): emissions[0] += 1)
	_check(bool(host._silas_dialogue_choice_status(false).get("enabled", false)), "Fresh route tip is available.")
	_check(not bool(host._silas_dialogue_choice_status(true).get("enabled", true)), "Undiscovered handle stays unavailable.")
	host._resolve_silas_numbers_dialogue_choice(false)
	_check(run.bankroll == before - 12 and emissions[0] == 1, "One dialogue purchase charges exactly twelve once.")
	_check(bool(run.numbers_state.knowledge.get("silas_tip", false)), "Purchase grants the real Numbers knowledge.")
	_check(not bool(host._silas_dialogue_choice_status(false).get("enabled", true)), "Purchased route tip is disabled in dialogue.")
	_check(str(host._silas_dialogue_choice_status(false).get("reason", "")).contains("already"), "Disabled tip explains prior purchase.")
	var feedback := host._environment_result_feedback_view()
	_check(str(feedback.get("message", "")).contains("Silas sells") and int(feedback.get("bankroll_delta", 0)) == -12, "Result replaces the stale door event with the paid exchange.")
	_check(host.last_hook_result.get("source_id") == "silas" and host.last_hook_result.get("action_id") == "buy_route_tip", "Dialogue publishes the existing Numbers result contract.")
	_check(host.saves == 1 and int(host.saved_state.get("bankroll", -1)) == before - 12, "Existing autosave receives the committed purchase.")
	var restored := EncounterRun.new()
	restored.from_dict(host.saved_state)
	host.run_state = restored
	_check(restored.bankroll == before - 12 and bool(restored.numbers_state.knowledge.get("silas_tip", false)), "Snapshot restore preserves cash and owned tip.")
	_check(not bool(host._silas_dialogue_choice_status(false).get("enabled", true)), "Restored tip stays unavailable.")
	host._resolve_silas_numbers_dialogue_choice(false)
	_check(restored.bankroll == before - 12 and host.saves == 1, "Repeated handler intent cannot charge or save a second purchase.")
	_check(not bool(host.last_hook_result.get("ok", true)) and str(host.last_hook_result.get("message", "")).contains("already"), "Rejected duplicate publishes an explanation without stale paid delta.")
	_check(int(host._environment_result_feedback_view().get("bankroll_delta", -1)) == 0, "Rejected intent does not repeat the paid delta.")
	var poor := EncounterRun.new()
	poor.start_new("SILAS-DIALOGUE-LOW-FUNDS")
	poor.change_bankroll(11 - poor.bankroll)
	host.run_state = poor
	_check(not bool(host._silas_dialogue_choice_status(false).get("enabled", true)), "Insufficient funds still disable a fresh tip.")
	host._resolve_silas_numbers_dialogue_choice(false)
	_check(poor.bankroll == 11 and not bool(poor.numbers_state.knowledge.get("silas_tip", false)), "Rejected low-funds intent grants no tip and charges nothing.")
	poor.silas_here = false
	_check(not bool(host._silas_dialogue_choice_status(false).get("enabled", true)), "Missing physical encounter stays disabled.")
	host._resolve_silas_numbers_dialogue_choice(false)
	_check(poor.bankroll == 11 and host.saves == 1, "Missing encounter cannot transact or autosave a purchase.")
	# Synthetic discovery/post setup exercises the adjacent paid-handle branch;
	# the actual purchase and returned number remain owned by NumbersModel.
	var handle_run := EncounterRun.new()
	handle_run.start_new("SILAS-DIALOGUE-HANDLE")
	handle_run.numbers_state.buy_silas_tip(false)
	handle_run.numbers_state.hear_staggered_close_rumor("numbers_stagger:gas_late")
	handle_run.numbers_state.hear_staggered_close_rumor("numbers_stagger:corner_late")
	handle_run.numbers_state.advance_to(handle_run.numbers_state.post_action(0))
	host.run_state = handle_run
	_check(bool(host._silas_dialogue_choice_status(true).get("enabled", false)), "Genuinely discovered, posted handle is available.")
	var handle_before := handle_run.bankroll
	host._resolve_silas_numbers_dialogue_choice(true)
	var number := handle_run.numbers_state.known_number()
	_check(number.length() == 3 and handle_run.bankroll == handle_before - 24, "One discovered handle costs exactly twenty-four.")
	_check(str(host._environment_result_feedback_view().get("message", "")).contains("Today's handle: %s." % number), "Published handle feedback retains the purchased number.")
	_check(not bool(host._silas_dialogue_choice_status(true).get("enabled", true)), "Purchased handle cannot be bought twice.")
	host._resolve_silas_numbers_dialogue_choice(true)
	_check(handle_run.bankroll == handle_before - 24 and host.saves == 2, "Repeated handle intent neither charges nor saves again.")
	host.free()
	print("SILAS_DIALOGUE_FEEDBACK " + JSON.stringify({"checks": checks, "failures": failures, "fixture": "synthetic presence, production Numbers economy and snapshot"}))
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
