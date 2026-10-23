extends SceneTree

const Model := preload("res://scripts/ui/money_feedback_view_model.gd")
const Run := preload("res://scripts/core/run_state.gd")
const Meta := preload("res://scripts/core/meta_collection_service.gd")
const Hud := preload("res://scripts/ui/foundation_hud_bar.gd")
const Foundation := preload("res://scripts/ui/foundation_main.gd")
const Sfx := preload("res://scripts/ui/sfx_player.gd")

class QuietAudio:
	extends Node
	var signs: Array = []
	func play_money_feedback(amount: int) -> bool:
		signs.append(amount)
		return true

var failures: Array[String] = []
var checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var pending: Dictionary = {}
	var run := Run.new()
	run.start_new("BTH061-013-MONEY")
	var original_rng := run.rng_state
	run.money_delta_applied.connect(func(currency: String, amount: int) -> void: Model.add_delta(pending, currency, amount))
	run.change_bankroll(-12)
	_check(Model.build(pending)[0].text == "−$12", "A real debit must display only its signed amount.")
	pending.clear()
	run.change_bankroll(12)
	_check(Model.build(pending)[0].text == "+$12", "A real credit must display only its signed amount.")
	pending.clear()
	run.current_environment = {"id": "money-cage", "archetype_id": "grand_casino_cage"}
	_check(bool(run.buy_grand_casino_chips(20).get("ok", false)), "Cage buy-in fixture was rejected.")
	_check(Model.build(pending).is_empty(), "A cash-to-chip transfer must not become a gain or a push.")
	pending.clear()
	_check(bool(run.cash_out_grand_casino_chips(10).get("ok", false)), "Cage cashout fixture was rejected.")
	_check(Model.build(pending).is_empty(), "Chip redemption must not count the same money as fresh income.")
	pending.clear()
	run.change_grand_casino_chips(3)
	_check(Model.build(pending)[0].text == "+◈3", "Chip gains must keep their monetary unit.")
	pending.clear()
	_check(bool(run.borrow_from_grand_casino_atm(50).get("ok", false)), "Loan fixture was rejected.")
	_check(Model.build(pending)[0].text == "+$50", "Loan cash must use the same applied-mutation feedback.")
	pending.clear()
	_check(bool(run.repay_grand_casino_atm_debt(10).get("ok", false)), "Repayment fixture was rejected.")
	_check(Model.build(pending)[0].text == "−$10", "Debt repayment cash must use the same applied-mutation feedback.")
	_check(run.rng_state == original_rng, "Presentation consumed gameplay RNG.")
	_check(not run.to_dict().has("money_feedback_pending"), "Transient presentation entered the save schema.")
	pending.clear()
	var meta := Meta.new()
	meta.gold_delta_applied.connect(func(amount: int) -> void: Model.add_delta(pending, "gold", amount))
	meta.add_gold(1000)
	_check(Model.build(pending)[0].text == "+1000g", "Profile gold requires its own unit.")
	pending.clear()
	var upgrade := meta.next_housing_upgrade()
	_check(bool(meta.purchase_housing_upgrade().get("ok", false)), "Home-purchase fixture was rejected.")
	_check(int(Model.build(pending)[0].delta) == -int(upgrade.get("price", 0)), "Home purchases must report their actual gold debit.")
	_check(Model.build({}).is_empty(), "An empty refresh must never create zero feedback.")
	_check(Model.build({"cash": 5, "chips": -5}, "cash").is_empty(), "A neutral transfer must not be mislabeled as a push.")
	var push := {"ok": true, "settlement": {"currency": "chips", "delta": 0}, "blackjack_hand_results": [{"outcome": "push"}]}
	_check(Model.explicit_push_currency(push) == "chips", "Explicit settled pushes must be recognized.")
	var replayed_push := push.duplicate(true)
	replayed_push["blackjack_host_replay"] = {"version": 1}
	_check(Model.explicit_push_currency(replayed_push).is_empty(), "Cached settlement replay must not present another push.")
	_check(Model.build({}, Model.explicit_push_currency(push))[0].text == "0", "Push feedback must contain only neutral zero.")
	_check(Model.explicit_push_currency({"ok": true, "settlement": {"currency": "cash", "delta": 0}}).is_empty(), "Zero without an explicit push is not a settlement event.")
	_check(Model.explicit_push_currency({"ok": true, "settlement": {"currency": "cash", "delta": 0}, "craps_bet_results": [{"outcome": "refund"}]}).is_empty(), "Refunds must not be described as pushes.")
	_check(Model.explicit_push_currency({"ok": true, "settlement": {"currency": "cash", "delta": 0}, "blackjack_hand_results": [{"outcome": "win"}, {"outcome": "lose"}]}).is_empty(), "Offsetting wins/losses are not a true push.")
	_check(Model.explicit_push_currency({"ok": true, "settlement": {"currency": "cash", "delta": 0}, "blackjack_hand_results": [{"outcome": "push"}], "blackjack_side_bet_results": [{"outcome": "lose"}]}).is_empty(), "A main-hand push with a losing side bet is not a true push.")

	var hud := Hud.new()
	root.add_child(hud)
	await process_frame
	hud.size = Vector2(1280, 76)
	hud.render({"bankroll": 100, "bankroll_delta": 100})
	_check(hud.wallet_delta.text.is_empty(), "Initial render must not replay persisted result deltas.")
	var host := Foundation.new()
	var audio := QuietAudio.new()
	host.run_state = run
	host.structured_hud = hud
	host.environment_sfx_player = audio
	host.current_screen = "ENVIRONMENT"
	host.call("_bind_run_state_presentation_signals")
	run.change_bankroll(7)
	host.call("_flush_money_feedback")
	_check(hud.wallet_delta.text == "+$7" and audio.signs == [1], "Applied events must reach the upgraded component and gain cue once.")
	var presentations := int(hud.current_snapshot().wallet_delta_presentations)
	hud.render({"bankroll": run.bankroll, "bankroll_delta": 7})
	host.call("_flush_money_feedback")
	_check(int(hud.current_snapshot().wallet_delta_presentations) == presentations and audio.signs.size() == 1, "HUD redraw replayed an outcome or sound.")
	run.change_bankroll(7)
	host.call("_flush_money_feedback")
	_check(int(hud.current_snapshot().wallet_delta_presentations) == presentations + 1, "Equal-valued distinct transactions must still be presented.")
	_check(hud.wallet_delta.text == "+$14", "Visible equal-valued transactions must accumulate.")
	run.change_bankroll(-5)
	run.change_bankroll(5)
	var before_rollback := int(hud.current_snapshot().wallet_delta_presentations)
	host.call("_flush_money_feedback")
	_check(int(hud.current_snapshot().wallet_delta_presentations) == before_rollback, "A rolled-back mutation produced phantom feedback.")
	hud.reset_wallet_delta()
	host.call("_queue_settled_push_feedback", push)
	var audio_before_push := audio.signs.size()
	host.call("_flush_money_feedback")
	_check(hud.wallet_delta.text == "0" and audio.signs.size() == audio_before_push, "An explicit push must be neutral and silent.")
	hud.set_reduce_motion(true)
	hud.present_money_feedback(Model.build({"cash": -5}))
	_check(hud.wallet_delta.text == "−$5" and hud.wallet_delta_panel.modulate.a == 1.0, "Reduced-motion feedback must remain apparent and signed.")
	hud.render({"mode": "meta", "gold": 100})
	hud.reset_wallet_delta()
	hud.present_money_feedback(Model.build({"gold": 4}))
	_check(hud.wallet_delta_panel.get_parent() == hud.meta_wallet_chip and hud.wallet_delta.text == "+4g", "Home gold must reuse the same component, not another indicator.")
	hud.call("_process", 2.0)
	_check(not bool(hud.current_snapshot().wallet_delta_active), "Money animation did not end promptly.")
	var restored := Run.new()
	restored.from_dict(run.to_dict())
	host.run_state = restored
	host.call("_bind_run_state_presentation_signals")
	host.call("_flush_money_feedback")
	_check(hud.wallet_delta.text.is_empty(), "Load/bind replayed a saved amount.")
	_check(hud.wallet_delta_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Feedback must never intercept input.")
	_check(hud.get_combined_minimum_size().x <= 1280.0, "The component overflows the existing HUD width.")

	var sfx := Sfx.new()
	root.add_child(sfx)
	sfx.set("_debug_web_delivery_active", true)
	sfx.set("_debug_web_delivery_results", [true, true, true])
	Sfx._last_money_feedback_msec = -1000
	Sfx._last_existing_money_cue_msec = -1000
	_check(sfx.play_money_feedback(1), "A gain should use the existing quiet payout cue.")
	_check(not sfx.play_money_feedback(-1), "Rapid/simultaneous changes must not stack money sounds.")
	_check(sfx.money_feedback_audio_profile(1).event_id == "payout" and float(sfx.money_feedback_audio_profile(1).volume_db) <= -18.0, "Gain cue must reuse the quiet existing payout.")
	_check(sfx.money_feedback_audio_profile(-1).event_id == "coin_pusher_chirp" and float(sfx.money_feedback_audio_profile(-1).volume_db) <= -20.0, "Loss cue must reuse a quiet restrained beep.")
	_check(not sfx.play_money_feedback(0), "Push must never play gain/loss audio.")
	Sfx._last_money_feedback_msec = -1000
	var bus := AudioServer.get_bus_index("SFX")
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "SFX")
	AudioServer.set_bus_mute(bus, true)
	_check(not sfx.play_money_feedback(1), "SFX mute must suppress money audio.")
	AudioServer.set_bus_mute(bus, false)
	AudioServer.set_bus_volume_db(bus, -80.0)
	_check(not sfx.play_money_feedback(-1), "Zero SFX volume must suppress money audio.")
	AudioServer.set_bus_volume_db(bus, 0.0)
	sfx.audio_enabled = false
	_check(not sfx.play_money_feedback(1), "Disabled audio must suppress money cues.")
	host.free()
	audio.free()
	hud.queue_free()
	sfx.queue_free()
	await process_frame
	print("MONEY_FEEDBACK_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
