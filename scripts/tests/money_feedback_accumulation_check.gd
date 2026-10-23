extends SceneTree

const Model := preload("res://scripts/ui/money_feedback_view_model.gd")
const Hud := preload("res://scripts/ui/foundation_hud_bar.gd")
const Host := preload("res://scripts/ui/foundation_main.gd")
const Run := preload("res://scripts/core/run_state.gd")
const Roulette := preload("res://scripts/games/roulette.gd")
const Baccarat := preload("res://scripts/games/baccarat.gd")

class QuietAudio extends Node:
	var signs: Array = []
	func play_money_feedback(amount: int) -> bool:
		signs.append(amount)
		return true

var failures: Array[String] = []
var checks := 0
var hud


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	hud = Hud.new()
	root.add_child(hud)
	await process_frame
	hud.set_process(false)
	for amount in [1, 1, 1, 2]:
		_show("cash", amount)
		hud._process(0.4)
	_check(hud.wallet_delta.text == "+$5", "Visible +1,+1,+1,+2 must accumulate to +$5.")
	_check(hud.wallet_delta_panel.get_parent() == hud.wallet_chip, "Accumulation must reuse the existing panel.")
	hud._process(0.5) # Past the first event's original expiry, within the newest.
	_check(_active() and hud.wallet_delta_panel.modulate.a == 1.0, "An old expiry must not hide the extended popup.")
	hud._process(0.55) # Last 0.15 seconds of the renewed lifetime.
	_check(_active() and hud.wallet_delta_panel.modulate.a < 1.0, "Normal feedback must still fade near its new expiry.")
	_show("cash", -8)
	_check(hud.wallet_delta.text == Model.build({"cash": -3})[0].text and _tone() == "danger", "Opposite signs must sum and switch to loss presentation.")
	_check(hud.wallet_delta_panel.modulate.a == 1.0, "An event during fade must restart fully visible.")
	hud._process(0.2)
	_check(_active() and hud.wallet_delta_panel.modulate.a == 1.0, "The previous fade deadline must not hide a renewed loss.")
	_show("cash", 3)
	_check(hud.wallet_delta.text == "0" and _tone() == "text_muted", "Offsetting visible deltas must show a neutral numeric zero.")
	_check(Model.explicit_push_currency({"ok": true, "settlement": {"currency": "cash", "delta": 0}}).is_empty(), "Accumulated zero must not manufacture a settled game push.")
	_show("cash", 4)
	_check(hud.wallet_delta.text == "+$4" and _tone() == "success", "A gain after zero must remain part of the same popup.")
	hud._process(1.6)
	_check(not _active() and hud.wallet_delta_panel.modulate.a == 0.0, "The exact renewed expiry boundary must hide feedback.")
	_show("cash", 2)
	_check(hud.wallet_delta.text == "+$2", "An event at full expiry must start fresh.")
	_show("gold", 3)
	_show("gold", -1)
	_show("chips", 4)
	_check(hud.wallet_delta.text == "+$2  +2g  " + str(Model.build({"chips": 4})[0].text), "Incompatible units must remain separately summed in one panel.")
	hud.reset_wallet_delta()
	_show("cash", 9)
	_check(hud.wallet_delta.text == "+$9", "Lifecycle reset must clear the previous accumulator.")
	hud.set_reduce_motion(true)
	hud._process(1.5)
	_show("cash", -2)
	hud._process(0.2)
	_check(hud.wallet_delta.text == "+$7" and hud.wallet_delta_panel.modulate.a == 1.0 and _active(), "Reduced motion must retain the renewed amount without fading.")
	hud._process(1.41)
	_check(not _active(), "Reduced-motion feedback must still expire.")
	_check_deferred_game(Roulette.new(), "roulette")
	_check_deferred_game(Baccarat.new(), "baccarat")
	hud.queue_free()
	await process_frame
	print("MONEY_FEEDBACK_ACCUMULATION_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


# Synthetic timing fixture through the unchanged production hold/release/event
# pipeline. Real game animation/settlement paths have their own focused checks.
func _check_deferred_game(game, game_id: String) -> void:
	hud.reset_wallet_delta()
	for definition in JSON.parse_string(FileAccess.get_file_as_string("res://data/games/games.json")):
		if str(definition.get("id", "")) == game_id:
			game.setup(definition)
	var host := Host.new()
	var audio := QuietAudio.new()
	var run := Run.new()
	run.start_new("MONEY-ACCUMULATE-" + game_id)
	run.current_environment = {"id": "money-reveal", "archetype_id": "bar", "game_ids": [game_id]}
	host.run_state = run
	host.current_game = game
	host.current_screen = "GAME"
	host.structured_hud = hud
	host.environment_sfx_player = audio
	host._bind_run_state_presentation_signals()
	run.change_bankroll(3)
	host._flush_money_feedback()
	hud._process(0.8)
	var presentations := int(hud.current_snapshot().wallet_delta_presentations)
	var rng := run.rng_state
	var result := {"ok": true, "hold_money_for_presentation": true, "deltas": {"bankroll_delta": 20}, "settlement": {"currency": "cash", "delta": 20}}
	run.change_bankroll(20)
	host._begin_presented_bankroll_hold(result, run.bankroll - 20, 5)
	host._flush_money_feedback()
	_check(hud.wallet_delta.text == "+$3" and int(hud.current_snapshot().wallet_delta_presentations) == presentations, "%s hidden outcome must not enter or renew visible feedback." % game_id)
	_check(audio.signs == [1], "%s hidden outcome must remain silent." % game_id)
	# Another visible effect may arrive while the result is still hidden.
	run.change_bankroll(1)
	host._flush_money_feedback()
	_check(hud.wallet_delta.text == "+$4", "%s unrelated visible effect must accumulate without the hidden outcome." % game_id)
	host._sync_presented_bankroll_to_actual()
	host._flush_money_feedback()
	_check(hud.wallet_delta.text == "+$24" and not host.presented_bankroll_hold_active, "%s revealed result must join the active popup once." % game_id)
	var count := int(hud.current_snapshot().wallet_delta_presentations)
	host._sync_presented_bankroll_to_actual()
	host._flush_money_feedback()
	_check(int(hud.current_snapshot().wallet_delta_presentations) == count and run.rng_state == rng, "%s repeated release must not replay feedback or change RNG." % game_id)
	# With the old popup expired, a delayed outcome must start a fresh amount.
	result.deltas.bankroll_delta = -6
	result.settlement.delta = -6
	run.change_bankroll(-6)
	host._begin_presented_bankroll_hold(result, run.bankroll + 6, 5)
	host._flush_money_feedback()
	hud._process(1.6)
	host._sync_presented_bankroll_to_actual()
	host._flush_money_feedback()
	_check(hud.wallet_delta.text == Model.build({"cash": -6})[0].text and _tone() == "danger", "%s reveal after expiry must start fresh with the loss sign." % game_id)
	_check(host.money_feedback_push_currency.is_empty(), "%s accumulation must not announce a fabricated push." % game_id)
	host.free()
	audio.free()


func _show(currency: String, amount: int) -> void:
	hud.present_money_feedback(Model.build({currency: amount}))


func _active() -> bool:
	return bool(hud.current_snapshot().wallet_delta_active)


func _tone() -> String:
	return str(hud.current_snapshot().wallet_delta_tone)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
