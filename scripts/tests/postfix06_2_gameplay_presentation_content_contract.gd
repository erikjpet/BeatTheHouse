extends SceneTree

const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const GameModuleScript := preload("res://scripts/core/game_module.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const PlayerTextScript := preload("res://scripts/ui/player_text.gd")
const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const CrewStateModelScript := preload("res://scripts/core/crew_state_model.gd")
const DeliveryRunModelScript := preload("res://scripts/core/delivery_run_model.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const WorldMapCanvasScript := preload("res://scripts/ui/world_map_canvas.gd")
const BlackjackScript := preload("res://scripts/games/blackjack.gd")
const BaccaratScript := preload("res://scripts/games/baccarat.gd")
const RouletteScript := preload("res://scripts/games/roulette.gd")
const BarDiceScript := preload("res://scripts/games/bar_dice.gd")
const SlotScript := preload("res://scripts/games/slot.gd")
const VideoPokerScript := preload("res://scripts/games/video_poker.gd")
const VideoPokerRendererScript := preload("res://scripts/games/video_poker_renderer.gd")
const PullTabsScript := preload("res://scripts/games/pull_tabs.gd")
const CrapsScript := preload("res://scripts/games/craps.gd")

const SEALED_PROVIDERS := [
	{"id": "blackjack", "script": BlackjackScript},
	{"id": "baccarat", "script": BaccaratScript},
	{"id": "roulette", "script": RouletteScript},
	{"id": "slot", "script": SlotScript},
	{"id": "video_poker", "script": VideoPokerScript},
]
const SETTLEMENT_GAMES := [
	"roulette", "bar_dice", "video_poker", "pull_tabs", "baccarat", "blackjack", "craps",
]
const SETTLEMENT_DELTAS := [-7, 0, 1, 12]
const ACTION_COUNTS := [0, 1, 2, 1001]


class LabelCaptureSurface:
	extends RefCounted

	var labels: Array[String] = []
	var active_animation_channels: Dictionary = {}
	var animation_elapsed_seconds := 1.0

	func draw_rect(_rect: Rect2, _color: Color, _filled: bool = true, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass

	func draw_polygon(_points: PackedVector2Array, _colors: PackedColorArray, _uvs: PackedVector2Array = PackedVector2Array(), _texture: Texture2D = null) -> void:
		pass

	func draw_line(_from: Vector2, _to: Vector2, _color: Color, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass

	func draw_circle(_position: Vector2, _radius: float, _color: Color, _filled: bool = true, _width: float = -1.0, _antialiased: bool = false) -> void:
		pass

	func surface_label(text: String, _position: Vector2, _font_size: int, _color: Color) -> void:
		labels.append(text)

	func surface_label_centered(text: String, _rect: Rect2, _font_size: int, _color: Color) -> void:
		labels.append(text)

	func surface_region_hovered(_action: String, _index: int = 0) -> bool:
		return false

	func surface_add_exact_hit(_rect: Rect2, _action: String, _index: int = 0) -> void:
		pass

	func surface_add_invisible_hit(_rect: Rect2, _action: String, _index: int = 0) -> void:
		pass

	func surface_add_hit(_rect: Rect2, _action: String, _index: int = 0) -> void:
		pass

	func surface_add_hold_hit(_rect: Rect2, _action: String, _index: int = 0) -> void:
		pass

	func surface_add_drag_hit(_rect: Rect2, _action: String, _index: int = 0) -> void:
		pass

	func surface_animation_active(channel: String) -> bool:
		return bool(active_animation_channels.get(channel, false))

	func surface_elapsed(_channel: String) -> float:
		return animation_elapsed_seconds

var failures: Array[String] = []
var game_definitions: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_load_game_definitions()
	_check_shared_sealed_action_copy()
	_check_structured_currency_settlements()
	_check_rejected_apply_does_not_publish_settlement()
	_check_embedded_currency_surfaces()
	_check_signed_chip_grammar()
	_check_action_count_consumers()
	_check_nested_item_references_and_loaded_dice()
	if failures.is_empty():
		print("POSTFIX06_2_GAMEPLAY_PRESENTATION_CONTENT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _load_game_definitions() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/games/games.json"))
	for value in parsed if typeof(parsed) == TYPE_ARRAY else []:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var definition := value as Dictionary
		game_definitions[str(definition.get("id", ""))] = definition


# GP-PF-003: stage a real pending authority delivery for every shared provider,
# then exercise the provider's real retry and cancel commands. The separate
# mismatch assertion keeps Foundation's pre-host identity check on the same
# neutral/provider-aware player-text boundary.
func _check_shared_sealed_action_copy() -> void:
	for provider_value in SEALED_PROVIDERS:
		var provider := provider_value as Dictionary
		var provider_id := str(provider.get("id", ""))
		var provider_script: Script = provider.get("script") as Script
		var game = provider_script.new()
		var definition: Dictionary = game_definitions.get(provider_id, {})
		if definition.is_empty():
			failures.append("GP-PF-003: missing %s fixture definition." % provider_id)
			continue
		game.setup(definition)
		var run := RunStateScript.new()
		run.start_new("POSTFIX06-2-SEALED-%s" % provider_id.to_upper())
		run.bankroll = 500
		run.grand_casino_chips = 500
		var environment := {
			"id": "postfix06_2_sealed_%s" % provider_id,
			"archetype_id": "grand_casino",
			"kind": "boss",
			"game_ids": [provider_id],
			"game_states": {},
			"economic_profile": {"stake_floor": 1, "stake_ceiling": 1000},
			"security_profile": {"strictness": "high"},
		}
		run.current_environment = environment
		var state: Dictionary = game.generate_environment_state(run, environment, run.create_rng("sealed_%s" % provider_id))
		(environment["game_states"] as Dictionary)[provider_id] = state
		run.current_environment = environment
		var host = FoundationMainScript.new()
		host.set("current_game", game)
		host.set("game_module_cache", {provider_id: game})
		host.set("run_state", run)
		host.set("selected_stake", 5)
		var prepared: Dictionary = host.call("_sealed_action_host_prepare_delivery", "postfix_fixture_action", 5, {})
		if not bool(prepared.get("ok", false)) or (prepared.get("delivery", {}) as Dictionary).is_empty():
			failures.append("GP-PF-003: %s could not stage an authentic pending delivery: %s" % [provider_id, JSON.stringify(prepared)])
			host.free()
			continue
		var contract: Dictionary = game.sealed_action_authority_contract()
		var retry_actions: Array = contract.get("retry_surface_actions", []) if typeof(contract.get("retry_surface_actions", [])) == TYPE_ARRAY else []
		var cancel_actions: Array = contract.get("cancel_surface_actions", []) if typeof(contract.get("cancel_surface_actions", [])) == TYPE_ARRAY else []
		if retry_actions.is_empty() or cancel_actions.is_empty():
			failures.append("GP-PF-003: %s lost its retry/cancel authority commands." % provider_id)
			host.free()
			continue
		var retry: Dictionary = host.call("_sealed_action_host_surface_intent", str(retry_actions[0]), 0, false, run.simulation_time_msec())
		_assert_sealed_provider_copy(provider_id, game.get_display_name(), "retry", str(retry.get("message", "")))
		var cancelled: Dictionary = host.call("_sealed_action_host_surface_intent", str(cancel_actions[0]), 0, false, run.simulation_time_msec())
		if not bool(cancelled.get("handled", false)):
			failures.append("GP-PF-003: %s authentic pending cancellation was not handled: %s" % [provider_id, JSON.stringify(cancelled)])
		_assert_sealed_provider_copy(provider_id, game.get_display_name(), "cancel", str(cancelled.get("message", "")))
		var mismatch_copy := PlayerTextScript.resolve("sealed_action.mismatch", {"provider_label": game.get_display_name()})
		_assert_sealed_provider_copy(provider_id, game.get_display_name(), "mismatch", mismatch_copy)
		host.free()
	var foundation_source := FileAccess.get_file_as_string("res://scripts/ui/foundation_main.gd")
	var mismatch_segment := _function_source(foundation_source, "_resolve_game_action")
	if mismatch_segment.findn("blackjack replay") >= 0:
		failures.append("GP-PF-003: Foundation's shared delivery/action mismatch branch still authors Blackjack-specific player copy.")
	if mismatch_segment.find("sealed_action.mismatch") < 0 and mismatch_segment.find("_sealed_action_mismatch") < 0:
		failures.append("GP-PF-003: Foundation's delivery/action mismatch branch does not use the shared sealed-action player-text boundary.")


func _assert_sealed_provider_copy(provider_id: String, provider_label: String, operation: String, message: String) -> void:
	var normalized := message.strip_edges().to_lower()
	var label := provider_label.strip_edges().to_lower()
	if normalized.is_empty() or (normalized.find("sealed action") < 0 and (label.is_empty() or normalized.find(label) < 0)):
		failures.append("GP-PF-003: %s %s copy is neither neutral nor provider-aware: %s" % [provider_id, operation, message])
	if provider_id != "blackjack" and normalized.find("blackjack") >= 0:
		failures.append("GP-PF-003: %s %s copy identifies the action as Blackjack: %s" % [provider_id, operation, message])


# GP-PF-004: the routing boundary must create one authoritative structured
# settlement and synchronize both the transient result and the module's durable
# last-result record before either surface formats it. The matrix deliberately
# includes zero-net pushes, multi-instance state keys, and a save/load round trip.
func _check_structured_currency_settlements() -> void:
	var module := GameModuleScript.new()
	if not module.has_method("finalize_routed_settlement"):
		failures.append("GP-PF-004: GameModule has no structured transient-and-persisted settlement boundary.")
		return
	for game_id in SETTLEMENT_GAMES:
		for casino in [false, true]:
			for delta in SETTLEMENT_DELTAS:
				_check_one_structured_settlement(module, game_id, casino, delta)


func _check_one_structured_settlement(module, game_id: String, casino: bool, delta: int) -> void:
	var run := RunStateScript.new()
	run.start_new("POSTFIX06-2-SETTLEMENT-%s-%s-%d" % [game_id.to_upper(), "CHIPS" if casino else "CASH", delta])
	run.bankroll = 100
	run.grand_casino_chips = 100
	var environment_id := "grand_casino_postfix_fixture" if casino else "bar_postfix_fixture"
	var archetype_id := "grand_casino" if casino else "bar"
	var state_key := "%s:postfix_fixture" % game_id
	var decoy_state_key := "%s:other_fixture" % game_id
	var authored := "Fixture %s. Bankroll %+d." % [_settlement_outcome(delta), delta]
	if casino and delta == 1:
		authored = "Fixture win. Chip change: +1 chip."
	var persisted := {
		"message": "Bankroll %+d." % delta,
		"summary": "Bankroll %+d." % delta,
		"bankroll_delta": delta,
		"outcome": _settlement_outcome(delta),
	}
	var environment := {
		"id": environment_id,
		"archetype_id": archetype_id,
		"kind": "boss" if casino else "casino",
		"game_ids": [game_id],
		"active_game_state_keys": {game_id: state_key},
		"game_states": {
			state_key: {"last_result": persisted},
			decoy_state_key: {"last_result": {"message": "Unrelated fixture result.", "bankroll_delta": 404}},
		},
	}
	run.current_environment = environment
	var result := GameModuleScript.build_action_result({
		"ok": true,
		"source_id": game_id,
		"game_id": game_id,
		"action_id": "postfix_settlement",
		"action_kind": "legal",
		"environment_id": environment_id,
		"environment_archetype_id": archetype_id,
		"bankroll_delta": delta,
		"message": authored,
		"won": delta > 0,
		"messages": [authored, "Auxiliary fixture notice."],
	})
	var routed: Dictionary = run.route_grand_casino_game_currency(result, result.get("deltas", {}))
	module.call("finalize_routed_settlement", run, result, routed)
	var expected_currency := "chips" if casino else "cash"
	var expected_delta := int(routed.get("chips_delta", 0)) if casino else int(routed.get("bankroll_delta", 0))
	_assert_settlement_record("GP-PF-004 %s %s %s transient" % [game_id, expected_currency, _settlement_outcome(delta)], result, expected_currency, expected_delta)
	var stored := _stored_last_result(run, state_key)
	_assert_settlement_record("GP-PF-004 %s %s %s persisted" % [game_id, expected_currency, _settlement_outcome(delta)], stored, expected_currency, expected_delta)
	var restored := RunStateScript.new()
	restored.from_dict(run.to_dict())
	var restored_stored := _stored_last_result(restored, state_key)
	_assert_settlement_record("GP-PF-004 %s %s %s restored" % [game_id, expected_currency, _settlement_outcome(delta)], restored_stored, expected_currency, expected_delta)
	var routed_messages: Array = result.get("messages", []) if typeof(result.get("messages", [])) == TYPE_ARRAY else []
	if not routed_messages.has("Auxiliary fixture notice."):
		failures.append("GP-PF-004: %s %s settlement discarded an unrelated authored auxiliary message: %s" % [game_id, expected_currency, JSON.stringify(routed_messages)])
	if _occurrences("\n".join(routed_messages).to_lower(), str((result.get("settlement", {}) as Dictionary).get("message", "")).to_lower()) > 1:
		failures.append("AIF-004: %s %s settlement duplicated its canonical currency message: %s" % [game_id, expected_currency, JSON.stringify(routed_messages)])
	var decoy := _stored_last_result(run, decoy_state_key)
	if decoy.has("settlement") or str(decoy.get("message", "")) != "Unrelated fixture result.":
		failures.append("GP-PF-004: %s settlement contaminated another same-game state: %s" % [game_id, JSON.stringify(decoy)])
	if casino and delta == 1 and _occurrences(str(result.get("message", "")).to_lower(), "chip change:") != 1:
		failures.append("AIF-004: an already-authored one-chip settlement was duplicated: %s" % str(result.get("message", "")))


func _check_rejected_apply_does_not_publish_settlement() -> void:
	var run := RunStateScript.new()
	run.start_new("POSTFIX06-2-REJECTED-SETTLEMENT")
	run.bankroll = 5
	var original_last_result := {
		"message": "Rejected fixture. Bankroll -10.",
		"summary": "Rejected fixture. Bankroll -10.",
		"bankroll_delta": -10,
	}
	run.current_environment = {
		"id": "bar_postfix_rejected_settlement",
		"archetype_id": "bar",
		"kind": "casino",
		"game_ids": ["roulette"],
		"game_states": {"roulette": {"last_result": original_last_result.duplicate(true)}},
	}
	var deltas := GameModuleScript.empty_result_deltas()
	deltas["bankroll_delta"] = -10
	var result := GameModuleScript.build_action_result({
		"ok": true,
		"source_id": "roulette",
		"game_id": "roulette",
		"action_id": "postfix_rejected_settlement",
		"action_kind": "legal",
		"environment_id": "bar_postfix_rejected_settlement",
		"environment_archetype_id": "bar",
		"bankroll_delta": -10,
		"deltas": deltas,
		"message": "Rejected fixture. Bankroll -10.",
	})
	var applied: Dictionary = GameModuleScript.apply_result(run, result)
	if bool(applied.get("ok", true)) or str(applied.get("error_code", "")) != "terminal_settlement_rejected":
		failures.append("GP-PF-004: rejected-settlement fixture did not reach the terminal rejection boundary: %s" % JSON.stringify(applied))
	var stored := _stored_last_result(run, "roulette")
	if stored.has("settlement") or str(stored.get("message", "")) != str(original_last_result.get("message", "")):
		failures.append("GP-PF-004: rejected apply_result published presentation state before acceptance: %s" % JSON.stringify(stored))


# GP-PF-004 rendered/view-model evidence for every concrete surface named in
# the finding. Both fixtures expose exactly 100 spendable units, but only one
# owns chips; this prevents an accidentally sourced cash meter from passing.
func _check_embedded_currency_surfaces() -> void:
	_check_video_poker_currency_surfaces()
	_check_pull_tabs_currency_surfaces()
	_check_bar_dice_currency_surfaces()
	_check_roulette_result_projection()
	_check_blackjack_currency_surfaces()
	_check_baccarat_currency_surfaces()
	_check_craps_currency_surfaces()


func _check_video_poker_currency_surfaces() -> void:
	var game = VideoPokerScript.new()
	game.setup(game_definitions.get("video_poker", {}))
	var renderer = VideoPokerRendererScript.new()
	for uses_chips in [false, true]:
		var fixture := _currency_surface_fixture("video_poker", uses_chips)
		var run = fixture.get("run")
		var environment: Dictionary = fixture.get("environment", {})
		var table: Dictionary = game.generate_environment_state(run, environment, run.create_rng("postfix_video_poker_surface_%s" % str(uses_chips)))
		table["last_result"] = {
			"summary": "Video Poker fixture. Bankroll +12.",
			"message": "Video Poker fixture. Bankroll +12.",
			"bankroll_delta": 12,
			"outcome": "win",
			"win_credits": 12,
			"pay_key": "jacks_or_better",
			"pay_label": "Jacks or Better",
			"pay_mult": 1,
			"hand": [],
			"hands": [],
			"hand_results": [],
		}
		environment["game_states"] = {"video_poker": table}
		run.current_environment = environment
		_route_fixture_settlement(run, environment, "video_poker", 12)
		var state: Dictionary = game.surface_state(run, environment, {})
		var currency := "chips" if uses_chips else "cash"
		if str(state.get("wager_currency", "")) != currency:
			failures.append("GP-PF-004: Video Poker surface omits its %s account identity: %s" % [currency, JSON.stringify(state)])
		var capture := LabelCaptureSurface.new()
		renderer.call("_draw_controls", capture, state, {
			"button": Color("#19d6ff"),
			"secondary": Color("#ff4fd8"),
			"trim": Color("#f7ef75"),
		})
		var wager := int(state.get("bet_credits", 0))
		var coins := int(state.get("coin_count", 1))
		var expected_account := "CHIPS 100    WIN 12 CHIPS" if uses_chips else "CASH $100    WIN $12"
		var expected_bet := "BET %s (%d COIN/HAND)" % [_currency_amount_text(currency, wager, true), coins]
		if not capture.labels.has(expected_account) or not capture.labels.has(expected_bet):
			failures.append("GP-PF-004: Video Poker %s capacity/bet meters were not exact account-aware labels (%s / %s): %s" % [currency, expected_account, expected_bet, JSON.stringify(capture.labels)])
		var outcome := str(state.get("outcome_headline", ""))
		var expected_paid := "PAID %s" % _currency_amount_text(currency, 12, true)
		if outcome.find(expected_paid) < 0:
			failures.append("GP-PF-004: Video Poker %s embedded outcome did not label its payout as %s: %s" % [currency, expected_paid, outcome])
		if uses_chips and ("\n".join(capture.labels).find("$") >= 0 or outcome.find("$") >= 0 or outcome.findn("cash") >= 0):
			failures.append("GP-PF-004: Video Poker chip surface still exposes cash/dollar wording: %s / %s" % [JSON.stringify(capture.labels), outcome])


func _check_pull_tabs_currency_surfaces() -> void:
	var game = PullTabsScript.new()
	game.setup(game_definitions.get("pull_tabs", {}))
	for uses_chips in [false, true]:
		var fixture := _currency_surface_fixture("pull_tabs", uses_chips)
		var run = fixture.get("run")
		var environment: Dictionary = fixture.get("environment", {})
		var machine: Dictionary = game.call("_generate_machine_state", run, environment)
		machine["winner_pile"] = [{
			"id": "postfix_currency_winner",
			"ticket_number": "PF-0001",
			"price": 1,
			"payout": 25,
			"rows": [],
			"palette": {},
			"fully_revealed": true,
		}]
		environment["game_states"] = {"pull_tabs": machine}
		run.current_environment = environment
		var state: Dictionary = game.surface_state(run, environment, {})
		var runtime: Dictionary = game.environment_runtime_state(run, environment)
		var object_state: Dictionary = game.environment_object_state(run, environment)
		var interactables: Array = game.environment_interactable_objects(run, environment)
		var currency := "chips" if uses_chips else "cash"
		if str(state.get("wager_currency", "")) != currency:
			failures.append("GP-PF-004: Pull Tabs surface omits its %s account identity: %s" % [currency, JSON.stringify(state)])
		var expected_badge := "CHIPS 25" if uses_chips else "CASH $25"
		var expected_runtime_summary := "Pending pull-tabs: 0 tray, 0 in play, 25 chips to redeem." if uses_chips else "Pending pull-tabs: 0 tray, 0 in play, $25 to redeem."
		var expected_effect := "Pending payout 25 chips; 0 tray tickets; 0 in play." if uses_chips else "Pending payout $25; 0 tray tickets; 0 in play."
		if str(runtime.get("status_label", "")) != expected_badge or str(runtime.get("status_summary", "")) != expected_runtime_summary:
			failures.append("GP-PF-004: Pull Tabs %s runtime label/summary were not account-aware: %s" % [currency, JSON.stringify(runtime)])
		if str(object_state.get("state_badge", "")) != expected_badge or str(object_state.get("effect_summary", "")) != expected_effect:
			failures.append("GP-PF-004: Pull Tabs %s object label/summary were not account-aware: %s" % [currency, JSON.stringify(object_state)])
		var redeem_object := _choice_by_id(interactables, "ticket_redeemer")
		var expected_action := "Redeem 1 winner for 25 chips." if uses_chips else "Redeem 1 winner for $25."
		var expected_interactable_effect := "Pending payout 25 chips." if uses_chips else "Pending payout $25."
		if str(redeem_object.get("action_summary", "")) != expected_action or str(redeem_object.get("effect_summary", "")) != expected_interactable_effect:
			failures.append("GP-PF-004: Pull Tabs %s redeem object was not account-aware: %s" % [currency, JSON.stringify(redeem_object)])
		var capture := LabelCaptureSurface.new()
		game.call(
			"_draw_pull_tab_stack_panel",
			capture,
			Rect2(430, 18, 448, 394),
			state,
			state.get("pull_tab_stack", []),
			[],
			[]
		)
		if not capture.labels.has(expected_badge):
			failures.append("GP-PF-004: Pull Tabs %s stack panel omitted exact payout label %s: %s" % [currency, expected_badge, JSON.stringify(capture.labels)])
		var visible_copy := "%s %s %s %s %s %s %s" % [
			str(runtime.get("status_label", "")),
			str(runtime.get("status_summary", "")),
			str(object_state.get("state_badge", "")),
			str(object_state.get("effect_summary", "")),
			str(redeem_object.get("short_description", "")),
			str(redeem_object.get("action_summary", "")),
			"\n".join(capture.labels),
		]
		if uses_chips and (visible_copy.find("$") >= 0 or visible_copy.findn("cash") >= 0 or visible_copy.findn("bankroll") >= 0):
			failures.append("GP-PF-004: Pull Tabs chip runtime/object/stack still exposes cash wording: %s" % visible_copy)


func _check_bar_dice_currency_surfaces() -> void:
	var game = BarDiceScript.new()
	game.setup(game_definitions.get("bar_dice", {}))
	for uses_chips in [false, true]:
		var fixture := _currency_surface_fixture("bar_dice", uses_chips)
		var run = fixture.get("run")
		var environment: Dictionary = fixture.get("environment", {})
		var table: Dictionary = game.generate_environment_state(run, environment, run.create_rng("postfix_bar_dice_surface_%s" % str(uses_chips)))
		table["last_result"] = {
			"summary": "Bar Dice fixture. Bankroll +12.",
			"message": "Bar Dice fixture. Bankroll +12.",
			"bankroll_delta": 12,
			"suspicion_delta": 0,
			"outcome": "win",
			"gross_payout": 17,
			"player_dice": [6, 5, 4, 3, 2],
			"winning_opponent_dice": [6, 5, 4, 2, 1],
			"player_score": {},
			"winning_opponent_score": {},
		}
		environment["game_states"] = {"bar_dice": table}
		run.current_environment = environment
		_route_fixture_settlement(run, environment, "bar_dice", 12)
		var state: Dictionary = game.surface_state(run, environment, {})
		var currency := "chips" if uses_chips else "cash"
		if str(state.get("wager_currency", "")) != currency:
			failures.append("GP-PF-004: Bar Dice surface omits its %s account identity: %s" % [currency, JSON.stringify(state)])
		_assert_embedded_result_currency("Bar Dice", currency, _stored_last_result(run, "bar_dice"), str(state.get("result_message", "")))
		var console_state := state.duplicate(true)
		console_state["stake_ladder"] = []
		console_state["bar_dice_action_buttons"] = []
		var capture := LabelCaptureSurface.new()
		game.call("_draw_console", capture, console_state)
		var expected_hud := "%s  Heat +0" % PlayerTextScript.format_settlement_delta(currency, 12)
		if not capture.labels.has(expected_hud):
			failures.append("GP-PF-004: Bar Dice %s settled HUD omitted exact structured settlement label %s: %s" % [currency, expected_hud, JSON.stringify(capture.labels)])
		if uses_chips and "\n".join(capture.labels).findn("bankroll") >= 0:
			failures.append("GP-PF-004: Bar Dice chip settled HUD still says Bankroll: %s" % JSON.stringify(capture.labels))


func _check_roulette_result_projection() -> void:
	var game = RouletteScript.new()
	game.setup(game_definitions.get("roulette", {}))
	for uses_chips in [false, true]:
		var fixture := _currency_surface_fixture("roulette", uses_chips)
		var run = fixture.get("run")
		var environment: Dictionary = fixture.get("environment", {})
		var table: Dictionary = game.generate_environment_state(run, environment, run.create_rng("postfix_roulette_surface_%s" % str(uses_chips)))
		table["last_result"] = {
			"spin_id": "postfix_currency_spin",
			"payout_animation_id": "postfix_currency_payout",
			"winning_number": "17",
			"winning_color": "black",
			"resolved_at_msec": 0,
			"summary": "Roulette fixture. Bankroll +12.",
			"message": "Roulette fixture. Bankroll +12.",
			"bankroll_delta": 12,
			"suspicion_delta": 0,
			"bets": [],
			"bet_results": [],
			"trajectory": [],
		}
		environment["game_states"] = {"roulette": table}
		run.current_environment = environment
		_route_fixture_settlement(run, environment, "roulette", 12)
		var state: Dictionary = game.surface_state(run, environment, {"surface_time_msec": 100000})
		var currency := "chips" if uses_chips else "cash"
		_assert_embedded_result_currency("Roulette", currency, state.get("last_result", {}), str(state.get("result_message", "")))


func _check_blackjack_currency_surfaces() -> void:
	var game = BlackjackScript.new()
	game.setup(game_definitions.get("blackjack", {}))
	for uses_chips in [false, true]:
		for delta in [-7, 0, 12]:
			var fixture := _currency_surface_fixture("blackjack", uses_chips)
			var run = fixture.get("run")
			var environment: Dictionary = fixture.get("environment", {})
			var table: Dictionary = game.generate_environment_state(run, environment, run.create_rng("postfix_blackjack_surface_%s_%d" % [str(uses_chips), delta]))
			table["last_result"] = {
				"action_id": "postfix_surface_settlement",
				"headline": _settlement_outcome(delta).to_upper(),
				"summary": "Blackjack fixture. Bankroll %+d." % delta,
				"message": "Blackjack fixture. Bankroll %+d." % delta,
				"bankroll_delta": delta,
				"round_net_delta": delta,
				"main_delta": delta,
				"side_delta": 0,
				"suspicion_delta": 0,
				"dealer_total": 18,
				"dealer_cards": [],
				"player_hands": [],
				"hand_results": [{"player_total": 18, "outcome": _settlement_outcome(delta), "bankroll_delta": delta, "wager": 7}],
				"side_bet_results": [],
				"payout_animation_id": "postfix_blackjack_payout_%s_%d" % [str(uses_chips), delta],
				"resolved_at_msec": 1,
			}
			environment["game_states"] = {"blackjack": table}
			run.current_environment = environment
			_route_fixture_settlement(run, environment, "blackjack", delta)
			var currency := "chips" if uses_chips else "cash"
			var state: Dictionary = game.surface_state(run, run.current_environment, {"surface_time_msec": 100000, "surface_presentation_time_msec": 100000})
			_assert_table_result_projection("Blackjack", "blackjack", currency, delta, run, game, state)
			_assert_blackjack_rendered_currency(game, state, currency, delta, "live")

			var restored := RunStateScript.new()
			restored.from_dict(run.to_dict())
			var restored_state: Dictionary = game.surface_state(restored, restored.current_environment, {"surface_time_msec": 100000, "surface_presentation_time_msec": 100000})
			_assert_table_result_projection("Blackjack restored", "blackjack", currency, delta, restored, game, restored_state)
			_assert_blackjack_rendered_currency(game, restored_state, currency, delta, "restored")


func _assert_blackjack_rendered_currency(game, state: Dictionary, currency: String, delta: int, phase: String) -> void:
	if str(state.get("wager_currency", "")) != currency:
		failures.append("GP-PF-004: Blackjack %s %s surface omitted its account identity: %s" % [phase, currency, JSON.stringify(state)])
	var board_capture := LabelCaptureSurface.new()
	game.call("_draw_blackjack_result_board", board_capture, state)
	var expected_board := _signed_currency_amount_text(currency, delta)
	if not board_capture.labels.has(expected_board):
		failures.append("GP-PF-004: Blackjack %s %s result board omitted %s: %s" % [phase, currency, expected_board, JSON.stringify(board_capture.labels)])
	if currency == "chips" and "\n".join(board_capture.labels).find("$") >= 0:
		failures.append("GP-PF-004: Blackjack %s chip result board still exposes dollars: %s" % [phase, JSON.stringify(board_capture.labels)])

	var payout_capture := LabelCaptureSurface.new()
	payout_capture.active_animation_channels["blackjack_payout"] = true
	game.call("_draw_chip_payout_animation", payout_capture, state)
	var expected_payout := _blackjack_payout_label(currency, delta)
	if not payout_capture.labels.has(expected_payout):
		failures.append("GP-PF-004: Blackjack %s %s payout overlay omitted %s: %s" % [phase, currency, expected_payout, JSON.stringify(payout_capture.labels)])

	var ritual_capture := LabelCaptureSurface.new()
	game.call("_draw_blackjack_ritual_layer", ritual_capture, state)
	var ritual_money := _first_label_with_prefix(ritual_capture.labels, "AVAILABLE ")
	if ritual_money.is_empty():
		failures.append("GP-PF-004: Blackjack %s %s ritual surface omitted its account totals." % [phase, currency])
	elif currency == "chips" and (ritual_money.find("$") >= 0 or ritual_money.findn("chip") < 0):
		failures.append("GP-PF-004: Blackjack %s chip ritual totals still expose cash formatting: %s" % [phase, ritual_money])
	elif currency == "cash" and ritual_money.find("$") < 0:
		failures.append("GP-PF-004: Blackjack %s cash ritual totals lost dollar formatting: %s" % [phase, ritual_money])


func _check_baccarat_currency_surfaces() -> void:
	var game = BaccaratScript.new()
	game.setup(game_definitions.get("baccarat", {}))
	for uses_chips in [false, true]:
		for delta in [-7, 0, 12]:
			var fixture := _currency_surface_fixture("baccarat", uses_chips)
			var run = fixture.get("run")
			var environment: Dictionary = fixture.get("environment", {})
			var table: Dictionary = game.generate_environment_state(run, environment, run.create_rng("postfix_baccarat_surface_%s_%d" % [str(uses_chips), delta]))
			var bet_result := {
				"id": "player",
				"label": "Player",
				"stake": 7,
				"payout": 12 if delta > 0 else 0,
				"won": delta > 0,
				"push": delta == 0,
			}
			var hand := {
				"hand_id": "postfix_baccarat_%s_%d" % [str(uses_chips), delta],
				"winner": "player" if delta > 0 else "banker" if delta < 0 else "tie",
				"player_total": 8 if delta >= 0 else 5,
				"banker_total": 6 if delta > 0 else 8 if delta < 0 else 7,
				"natural": false,
				"animation_events": [],
				"shoe_remaining_after": int(table.get("shoe_remaining", 0)),
				"reshuffle_pending": false,
			}
			var settlement := {
				"bankroll_delta": delta,
				"commission": 1 if delta > 0 else 0,
				"bet_results": [bet_result],
			}
			game.call("_update_table_after_hand", table, {"player": 7}, hand, settlement, delta, run.create_rng("postfix_baccarat_persist_%s_%d" % [str(uses_chips), delta]), 1)
			var persisted: Dictionary = table.get("last_result", {})
			persisted["action_id"] = "postfix_surface_settlement"
			table["last_result"] = persisted
			environment["game_states"] = {"baccarat": table}
			run.current_environment = environment
			_route_fixture_settlement(run, environment, "baccarat", delta)
			var currency := "chips" if uses_chips else "cash"
			var state: Dictionary = game.surface_state(run, run.current_environment, {"surface_time_msec": 100000})
			_assert_table_result_projection("Baccarat", "baccarat", currency, delta, run, game, state)
			_assert_baccarat_rendered_currency(game, state, currency, delta, "live")

			var restored := RunStateScript.new()
			restored.from_dict(run.to_dict())
			var restored_state: Dictionary = game.surface_state(restored, restored.current_environment, {"surface_time_msec": 100000})
			_assert_table_result_projection("Baccarat restored", "baccarat", currency, delta, restored, game, restored_state)
			_assert_baccarat_rendered_currency(game, restored_state, currency, delta, "restored")


func _assert_baccarat_rendered_currency(game, state: Dictionary, currency: String, delta: int, phase: String) -> void:
	if str(state.get("wager_currency", "")) != currency:
		failures.append("GP-PF-004: Baccarat %s %s surface omitted its account identity: %s" % [phase, currency, JSON.stringify(state)])
	var explainer: Dictionary = state.get("baccarat_explainer", {}) if typeof(state.get("baccarat_explainer", {})) == TYPE_DICTIONARY else {}
	var bet_summary := str(explainer.get("bet_summary", ""))
	_assert_visible_currency("Baccarat %s explainer" % phase, currency, delta, bet_summary)
	var explainer_capture := LabelCaptureSurface.new()
	game.call("_draw_hand_explainer", explainer_capture, state)
	var captured_copy := "\n".join(explainer_capture.labels)
	_assert_visible_currency("Baccarat %s rendered explainer" % phase, currency, delta, captured_copy)

	var console_capture := LabelCaptureSurface.new()
	game.call("_draw_action_console", console_capture, state)
	var minimum := int(state.get("table_minimum", 0))
	var maximum := int(state.get("table_maximum", 0))
	var wager := int(state.get("total_wager_cost", 0))
	var commission := int(state.get("commission_owed", 0))
	var expected_range := "MIN %s  MAX %s" % [_currency_amount_text(currency, minimum, true), _currency_amount_text(currency, maximum, true)]
	var expected_wager := "WAGER %s" % _currency_amount_text(currency, wager, true)
	var expected_commission := "COMM %s" % _currency_amount_text(currency, commission, true)
	for expected in [expected_range, expected_wager, expected_commission]:
		if not console_capture.labels.has(expected):
			failures.append("GP-PF-004: Baccarat %s %s console omitted %s: %s" % [phase, currency, expected, JSON.stringify(console_capture.labels)])
	if currency == "chips" and "\n".join(console_capture.labels).find("$") >= 0:
		failures.append("GP-PF-004: Baccarat %s chip result console still exposes dollars: %s" % [phase, JSON.stringify(console_capture.labels)])


func _check_craps_currency_surfaces() -> void:
	var game = CrapsScript.new()
	game.setup(game_definitions.get("craps", {}))
	for uses_chips in [false, true]:
		for delta in [-7, 0, 12]:
			var fixture := _currency_surface_fixture("craps", uses_chips)
			var run = fixture.get("run")
			var environment: Dictionary = fixture.get("environment", {})
			var table: Dictionary = game.generate_environment_state(run, environment, run.create_rng("postfix_craps_surface_%s_%d" % [str(uses_chips), delta]))
			var settlement := {
				"point_before": 0,
				"point_after": 0,
				"point_made": false,
				"seven_out": false,
				"bet_results": [{"label": "Pass Line", "stake": 7, "profit": delta, "outcome": _settlement_outcome(delta)}],
			}
			var roll := {"total": 7, "dice": [3, 4]}
			var message := str(game.call("_roll_message", roll, settlement, delta, table))
			table["last_result"] = {
				"action_id": "postfix_surface_settlement",
				"message": message,
				"summary": message,
				"bankroll_delta": delta,
				"bet_results": settlement.get("bet_results", []),
			}
			environment["game_states"] = {"craps": table}
			run.current_environment = environment
			_route_fixture_settlement(run, environment, "craps", delta)
			var currency := "chips" if uses_chips else "cash"
			var state: Dictionary = game.surface_state(run, run.current_environment, {"surface_time_msec": 100000})
			_assert_table_result_projection("Craps", "craps", currency, delta, run, game, state)
			var expected_wager_label := "%d %s" % [int(state.get("total_wager_cost", 0)), currency]
			if not _surface_state_label_has(state, "New wagers", expected_wager_label):
				failures.append("GP-PF-004: Craps %s surface wager label lost its account identity: %s" % [currency, JSON.stringify(state.get("surface_state_labels", []))])

			var restored := RunStateScript.new()
			restored.from_dict(run.to_dict())
			var restored_state: Dictionary = game.surface_state(restored, restored.current_environment, {"surface_time_msec": 100000})
			_assert_table_result_projection("Craps restored", "craps", currency, delta, restored, game, restored_state)


func _assert_table_result_projection(surface_name: String, game_id: String, currency: String, delta: int, run, _game, state: Dictionary) -> void:
	var record := _stored_last_result(run, game_id)
	_assert_embedded_result_currency(surface_name, currency, record, str(state.get("result_message", "")), delta)
	var state_record: Dictionary = state.get("last_result", {}) if typeof(state.get("last_result", {})) == TYPE_DICTIONARY else {}
	_assert_embedded_result_currency("%s state" % surface_name, currency, state_record, str(state.get("result_message", "")), delta)


func _assert_visible_currency(label: String, currency: String, delta: int, visible: String) -> void:
	if currency == "chips":
		if visible.findn("chip") < 0 or visible.findn("cash") >= 0 or visible.findn("bankroll") >= 0 or visible.find("$") >= 0:
			failures.append("GP-PF-004: %s exposes cash wording instead of chips for %+d: %s" % [label, delta, visible])
	elif visible.find("$") < 0 and visible.findn("cash") < 0:
		failures.append("GP-PF-004: %s lost cash semantics for %+d: %s" % [label, delta, visible])


func _blackjack_payout_label(currency: String, delta: int) -> String:
	if delta > 0:
		return "DEALER PAYS %s" % _signed_currency_amount_text(currency, delta)
	if delta < 0:
		return "DEALER COLLECTS %s" % _currency_amount_text(currency, absi(delta), true)
	return "PUSH: %s RETURN" % PlayerTextScript.currency_account_label(currency)


func _signed_currency_amount_text(currency: String, amount: int) -> String:
	if currency == "chips":
		var noun := "CHIP" if absi(amount) == 1 else "CHIPS"
		return "%+d %s" % [amount, noun]
	return "$%+d" % amount


func _first_label_with_prefix(labels: Array[String], prefix: String) -> String:
	for label in labels:
		if label.begins_with(prefix):
			return label
	return ""


func _surface_state_label_has(state: Dictionary, label: String, value: String) -> bool:
	for entry_value in state.get("surface_state_labels", []):
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry := entry_value as Dictionary
		if str(entry.get("label", "")) == label and str(entry.get("value", "")) == value:
			return true
	return false


func _currency_surface_fixture(game_id: String, uses_chips: bool) -> Dictionary:
	var run := RunStateScript.new()
	run.start_new("POSTFIX06-2-SURFACE-%s-%s" % [game_id.to_upper(), "CHIPS" if uses_chips else "CASH"])
	run.bankroll = 0 if uses_chips else 100
	run.grand_casino_chips = 100 if uses_chips else 0
	var environment := {
		"id": "grand_casino_postfix_surface_%s" % game_id if uses_chips else "bar_postfix_surface_%s" % game_id,
		"archetype_id": "grand_casino" if uses_chips else "bar",
		"kind": "boss" if uses_chips else "casino",
		"game_ids": [game_id],
		"game_states": {},
		"economic_profile": {"stake_floor": 1, "stake_ceiling": 100},
		"security_profile": {"strictness": "standard"},
	}
	if game_id == "craps" and not uses_chips:
		environment["scenario_game_modifiers"] = {"game_hook": "street_craps"}
	run.current_environment = environment
	return {"run": run, "environment": environment}


func _route_fixture_settlement(run, environment: Dictionary, game_id: String, delta: int) -> Dictionary:
	var result := GameModuleScript.build_action_result({
		"ok": true,
		"source_id": game_id,
		"game_id": game_id,
		"action_id": "postfix_surface_settlement",
		"action_kind": "legal",
		"environment_id": str(environment.get("id", "")),
		"environment_archetype_id": str(environment.get("archetype_id", "")),
		"bankroll_delta": delta,
		"message": "%s fixture. Bankroll %+d." % [game_id, delta],
		"won": delta > 0,
	})
	var routed: Dictionary = run.route_grand_casino_game_currency(result, result.get("deltas", {}))
	GameModuleScript.new().call("finalize_routed_settlement", run, result, routed)
	return result


func _currency_amount_text(currency: String, amount: int, uppercase_noun: bool = false) -> String:
	if currency == "chips":
		var noun := "CHIP" if absi(amount) == 1 else "CHIPS"
		return "%d %s" % [amount, noun if uppercase_noun else noun.to_lower()]
	return "$%d" % amount


func _assert_embedded_result_currency(surface_name: String, currency: String, record_value: Variant, visible: String, expected_delta: int = 12) -> void:
	var record: Dictionary = record_value if typeof(record_value) == TYPE_DICTIONARY else {}
	var settlement: Dictionary = record.get("settlement", {}) if typeof(record.get("settlement", {})) == TYPE_DICTIONARY else {}
	if str(settlement.get("currency", "")) != currency or int(settlement.get("delta", 999999)) != expected_delta:
		failures.append("GP-PF-004: %s real surface lost the %s structured settlement: %s" % [surface_name, currency, JSON.stringify(record)])
		return
	if currency == "chips" and (visible.findn("chip") < 0 or visible.findn("cash") >= 0 or visible.findn("bankroll") >= 0 or visible.find("$") >= 0):
		failures.append("GP-PF-004: %s real chip result projection exposes cash wording: %s" % [surface_name, visible])
	elif currency == "cash" and visible.findn("cash") < 0:
		failures.append("GP-PF-004: %s real cash result projection lost cash semantics: %s" % [surface_name, visible])


func _assert_settlement_record(label: String, record: Dictionary, currency: String, delta: int) -> void:
	var settlement: Dictionary = record.get("settlement", {}) if typeof(record.get("settlement", {})) == TYPE_DICTIONARY else {}
	if str(settlement.get("currency", "")) != currency or int(settlement.get("delta", 999999)) != delta:
		failures.append("%s lacks the authoritative structured settlement: %s" % [label, JSON.stringify(record)])
		return
	var settlement_message := str(settlement.get("message", ""))
	var visible := str(record.get("message", record.get("summary", "")))
	var combined := "%s %s" % [visible, settlement_message]
	if currency == "chips":
		if combined.findn("chip") < 0 or visible.findn("bankroll") >= 0 or visible.findn("cash") >= 0 or visible.find("$") >= 0:
			failures.append("%s exposes cash wording instead of chips: %s" % [label, JSON.stringify(record)])
	else:
		if combined.findn("cash") < 0 or visible.findn("chip") >= 0:
			failures.append("%s does not retain cash semantics: %s" % [label, JSON.stringify(record)])


func _stored_last_result(run, state_key: String) -> Dictionary:
	var states: Dictionary = run.current_environment.get("game_states", {}) if typeof(run.current_environment.get("game_states", {})) == TYPE_DICTIONARY else {}
	var state: Dictionary = states.get(state_key, {}) if typeof(states.get(state_key, {})) == TYPE_DICTIONARY else {}
	return state.get("last_result", {}) if typeof(state.get("last_result", {})) == TYPE_DICTIONARY else {}


func _settlement_outcome(delta: int) -> String:
	return "win" if delta > 0 else "loss" if delta < 0 else "push"


# AIF-004: signed one-chip values use the singular noun, zero and other
# magnitudes use the plural, and compatibility composition names settlement once.
func _check_signed_chip_grammar() -> void:
	var formatter := PlayerTextScript.new()
	if not formatter.has_method("format_settlement_delta"):
		failures.append("AIF-004: PlayerText has no currency-aware signed settlement formatter for zero-net results.")
		return
	for delta in [-12, -2, -1, 0, 1, 2, 12]:
		var text := str(formatter.call("format_settlement_delta", "chips", delta))
		var noun := "chip" if absi(delta) == 1 else "chips"
		var expected := "Chip change: %+d %s." % [delta, noun]
		if text != expected:
			failures.append("AIF-004: signed chip grammar for %+d was %s; expected %s" % [delta, text, expected])
	var negative_one := PlayerTextScript.format_currency_settlement(0, -1)
	var positive_one := PlayerTextScript.format_currency_settlement(0, 1)
	if negative_one != "Chip change: -1 chip." or positive_one != "Chip change: +1 chip.":
		failures.append("AIF-004: compatibility formatter still pluralizes a signed one-chip settlement: %s / %s" % [negative_one, positive_one])


# GP-PF-005: verify the reachable consumer output, not only count_text().
func _check_action_count_consumers() -> void:
	_check_courier_action_counts()
	_check_crew_job_action_counts()
	_check_shift_rookie_action_counts()


func _check_courier_action_counts() -> void:
	var app := FoundationMainScript.new()
	var run := RunStateScript.new()
	run.start_new("POSTFIX06-2-COURIER-COUNTS")
	var content_library := ContentLibraryScript.new()
	var loaded: Dictionary = content_library.load(false)
	if not bool(loaded.get("ok", true)) or not content_library.validation_errors.is_empty():
		failures.append("GP-PF-005: courier detail fixture could not load production content: %s" % JSON.stringify(loaded))
		app.free()
		return
	app.set("library", content_library)
	app.set("generator", RunGeneratorScript.new(content_library))
	if not bool(app.call("_ensure_run_ui_stage_scripts", 10)):
		failures.append("GP-PF-005: courier detail fixture could not load the production world-map view/controller stage.")
		app.free()
		return
	app.set("run_state", run)
	var detail_label := Label.new()
	var map_canvas := WorldMapCanvasScript.new()
	app.set("world_map_detail_label", detail_label)
	app.set("selected_world_map_node_id", "fixture_stop")
	run.world_map = {
		"version": 3,
		"seed_text": run.seed_text,
		"start_node_id": "fixture_stop",
		"current_node_id": "fixture_stop",
		"revision": 0,
		"nodes": [{
			"id": "fixture_stop",
			"archetype_id": "fixture_stop",
			"label": "Fixture Stop",
			"kind": "street",
			"state": "visited",
			"seen": true,
			"position": {"x": 0.5, "y": 0.5},
			"flavor": "Fixture delivery target.",
		}],
		"edges": [],
		"visited_path": ["fixture_stop"],
	}
	for count in ACTION_COUNTS:
		var delivery := DeliveryRunModelScript.begin({
			"mode": "package",
			"run_id": "postfix_count_%d" % count,
			"deadline_actions": maxi(1, count),
			"start_node_id": "fixture_stop",
			"current_node_id": "fixture_stop",
			"initial_cargo_state": DeliveryRunModelScript.CARGO_CARRIED,
			"targets": [{"node_id": "fixture_stop", "label": "Fixture Stop", "contact_label": "Fixture Contact"}],
		}, 0)
		delivery["deadline_total"] = maxi(1, count)
		delivery["deadline_remaining"] = count
		run.active_delivery_run = delivery
		var title := str(app.call("_world_map_title_text", "Fixture"))
		var expected := PlayerTextScript.count_text("action", count)
		var expected_title_suffix := " | Courier: %s" % expected
		if not title.ends_with(expected_title_suffix) or _occurrences(title, expected) != 1:
			failures.append("GP-PF-005: courier title count %d did not render the exact shared count text: %s" % [count, title])
		app.call("_refresh_world_map_detail")
		var detail_text := detail_label.text
		var expected_detail_line := "Courier target · %s · pending" % expected
		if not detail_text.split("\n").has(expected_detail_line) or _occurrences(detail_text, expected) != 1:
			failures.append("GP-PF-005: courier target detail count %d did not render the exact shared count text: %s" % [count, detail_text])
		map_canvas.set_map_snapshot({
			"courier_layer": {
				"active": true,
				"cargo": {"label": "Fixture Cargo"},
				"deadline_remaining": count,
			},
		})
		var canvas_header := str(map_canvas.get("courier_header_text"))
		var expected_canvas_header := "FIXTURE CARGO · CONTRABAND · %s" % expected.to_upper()
		if canvas_header != expected_canvas_header or _occurrences(canvas_header, expected.to_upper()) != 1:
			failures.append("GP-PF-005: rendered courier map header count %d bypassed the shared count text: %s" % [count, canvas_header])
	app.set("world_map_detail_label", null)
	detail_label.free()
	map_canvas.free()
	app.free()


func _check_crew_job_action_counts() -> void:
	var original_cache: Dictionary = CrewStateModelScript._job_cache.duplicate(true)
	var fixture_cache := {}
	for count in ACTION_COUNTS:
		var job_id := "postfix_count_%d" % count
		fixture_cache[job_id] = {
			"id": job_id,
			"label": "Count %d" % count,
			"member_id": "crew_rook",
			"min_rank": "associate",
			"kind": "package_run",
			"expiry_in_actions": count,
			"rewards": {"cash": 10, "trust": 1},
			"failure": {"trust": -1},
		}
	CrewStateModelScript._job_cache = fixture_cache
	var run := RunStateScript.new()
	run.start_new("POSTFIX06-2-CREW-JOB-COUNTS")
	run.crew_trust_by_member["crew_rook"] = CrewStateModelScript.rank_threshold("associate")
	run.current_environment = {
		"id": "postfix_crew_board",
		"archetype_id": "small_underground_casino",
		"crew_presence": [{"member_id": "crew_rook"}],
	}
	var rows := run.crew_job_board_choices()
	for count in ACTION_COUNTS:
		var row := _choice_by_id(rows, "accept_postfix_count_%d" % count)
		var expected := PlayerTextScript.count_text("action", count)
		var row_text := str(row.get("text", ""))
		var expected_expiry_segment := " · %s · " % expected
		if row.is_empty() or row_text.find(expected_expiry_segment) < 0 or _occurrences(row_text, expected) != 1:
			failures.append("GP-PF-005: Crew job count %d did not render through count_text(): %s" % [count, JSON.stringify(row)])
	CrewStateModelScript._job_cache = original_cache


func _check_shift_rookie_action_counts() -> void:
	var run := RunStateScript.new()
	run.start_new("POSTFIX06-2-SHIFT-COUNTS")
	run.rourke_current_room = "grand_casino"
	run.rourke_off_floor_actions = 0
	var environment := {
		"id": "grand_casino_postfix_shift",
		"archetype_id": "grand_casino",
		"turns": 0,
		"security_profile": {
			"pit_boss": {
				"enabled": true,
				"label": "Rourke",
				"cheat_heat_bonus": 25,
				"cycle_length": 4,
				"watched_turns": 2,
				"watched_text": "Rourke is watching.",
				"clear_text": "Rourke is turned away.",
			},
		},
	}
	run.narrative_flags["shift_change_rookie_actions"] = 0
	var baseline_status := run.pit_boss_watch_status(environment)
	var baseline_summary := str(baseline_status.get("summary", ""))
	for count in ACTION_COUNTS:
		run.narrative_flags["shift_change_rookie_actions"] = count
		var status := run.pit_boss_watch_status(environment)
		var summary := str(status.get("summary", ""))
		if count == 0:
			if summary != baseline_summary or int(status.get("remaining_actions", -1)) != 0 or not str(status.get("temporary_modifier", "")).is_empty():
				failures.append("GP-PF-005: inactive rookie shift did not retain the exact zero-action status: %s" % JSON.stringify(status))
		else:
			var expected := PlayerTextScript.count_text("action", count)
			var expected_summary := "%s A rookie is on handoff; cheat heat is softened for %s." % [baseline_summary, expected]
			if summary != expected_summary or _occurrences(summary, expected) != 1 or int(status.get("remaining_actions", -1)) != count or str(status.get("temporary_modifier", "")) != "shift_change":
				failures.append("GP-PF-005: rookie shift count %d did not render through count_text(): %s" % [count, JSON.stringify(status)])


# CR-PF-001: unknown item identities must fail even when buried in game-specific
# arrays/objects. Every surviving loaded-dice identity must retain its reciprocal
# content-group membership, an executable acquisition path, and exactly its
# configured bonus while the neither-owned control does not.
func _check_nested_item_references_and_loaded_dice() -> void:
	var library := ContentLibraryScript.new()
	library.load(false)
	var craps_definition: Dictionary = game_definitions.get("craps", {})
	if craps_definition.is_empty():
		failures.append("CR-PF-001: Craps definition is missing.")
		return
	var switching: Dictionary = (craps_definition.get("craps_config", {}) as Dictionary).get("switching", {})
	var loaded_ids: Array = switching.get("loaded_dice_item_ids", []) if typeof(switching.get("loaded_dice_item_ids", [])) == TYPE_ARRAY else []
	if loaded_ids.has("precision_loaded_dice"):
		failures.append("CR-PF-001: obsolete precision_loaded_dice remains in the Craps configuration.")
	if loaded_ids != ["mags_loaded_dice"]:
		failures.append("CR-PF-001: Craps loaded-dice identities are not the canonical reachable set: %s" % JSON.stringify(loaded_ids))
	for item_id_value in loaded_ids:
		var item_id := str(item_id_value)
		if library.item(item_id).is_empty():
			failures.append("CR-PF-001: configured loaded-dice item is absent from the catalog: %s" % item_id)
			continue
		_check_loaded_dice_acquisition_path(library, item_id)
	_check_nested_item_reference_validation(library, craps_definition)
	_check_loaded_dice_bonus(library, craps_definition, switching, loaded_ids)


func _check_loaded_dice_acquisition_path(library, item_id: String) -> void:
	var item: Dictionary = library.item(item_id)
	var item_groups: Array = item.get("content_groups", []) if typeof(item.get("content_groups", [])) == TYPE_ARRAY else []
	var reciprocal_groups: Array[String] = []
	for group_id_value in item_groups:
		var group_id := str(group_id_value)
		var group: Dictionary = library.content_group(group_id)
		var grouped_items: Array = group.get("item_ids", []) if typeof(group.get("item_ids", [])) == TYPE_ARRAY else []
		if grouped_items.has(item_id):
			reciprocal_groups.append(group_id)
	if reciprocal_groups.is_empty():
		failures.append("CR-PF-001: configured loaded-dice item has no reciprocal content-group path: %s" % item_id)

	# The surviving identity is crew-built rather than sold in ordinary shop
	# bands. Keep its item tag, group catalog, recipe, and live event consequence
	# path joined so a data-only definition cannot masquerade as acquisition.
	if item_id != "mags_loaded_dice":
		failures.append("CR-PF-001: configured loaded-dice item has no focused acquisition-path proof: %s" % item_id)
		return
	var crew_gear: Dictionary = library.content_group("crew_gear")
	var crew_gear_items: Array = crew_gear.get("item_ids", []) if typeof(crew_gear.get("item_ids", [])) == TYPE_ARRAY else []
	if not item_groups.has("crew_gear") or not crew_gear_items.has(item_id) or not reciprocal_groups.has("crew_gear"):
		failures.append("CR-PF-001: Mags' loaded dice lost its reciprocal crew_gear content-group membership.")
	var bench_definition: Dictionary = library.event("crew_mags_bench")
	var payload: Dictionary = bench_definition.get("payload", {}) if typeof(bench_definition.get("payload", {})) == TYPE_DICTIONARY else {}
	if str(payload.get("kind", "")) != "crew_mags_bench":
		failures.append("CR-PF-001: Mags' bench acquisition event is missing or no longer routes through the production bench path.")
		return
	var catalog: Array = payload.get("catalog", []) if typeof(payload.get("catalog", [])) == TYPE_ARRAY else []
	var matching_recipes: Array[Dictionary] = []
	for recipe_value in catalog:
		if typeof(recipe_value) == TYPE_DICTIONARY and str((recipe_value as Dictionary).get("output_item", "")) == item_id:
			matching_recipes.append((recipe_value as Dictionary).duplicate(true))
	if matching_recipes.size() != 1:
		failures.append("CR-PF-001: Mags' bench must expose exactly one %s recipe; found %d." % [item_id, matching_recipes.size()])
		return
	var recipe := matching_recipes[0]
	var recipe_id := str(recipe.get("id", ""))
	var cash_cost := int(recipe.get("cash_cost", 0))
	var minimum_rank := str(recipe.get("min_member_rank", ""))
	var required_items: Array = recipe.get("requires_items", []) if typeof(recipe.get("requires_items", [])) == TYPE_ARRAY else []
	if recipe_id != "craft_loaded_dice" or cash_cost <= 0 or minimum_rank.is_empty() or required_items.is_empty():
		failures.append("CR-PF-001: Mags' loaded-dice recipe lost its authored id, price, rank, or component gate: %s" % JSON.stringify(recipe))
		return
	for component_value in required_items:
		if library.item(str(component_value)).is_empty():
			failures.append("CR-PF-001: Mags' loaded-dice recipe requires an undefined component: %s" % str(component_value))

	var run := RunStateScript.new()
	run.start_new("POSTFIX06-2-CRAPS-MAGS-ACQUISITION")
	# Leave one cash unit after the purchase so this acquisition-path proof does
	# not intentionally cross the unrelated bankroll-zero terminal boundary.
	run.bankroll = cash_cost + 1
	run.current_environment = {
		"id": "postfix06_2_mags_bench",
		"archetype_id": "small_underground_casino",
		"kind": "crew",
		"event_ids": ["crew_mags_bench"],
		"resolved_event_ids": [],
	}
	run.crew_add_trust("crew_mags", CrewStateModelScript.rank_threshold(minimum_rank), "postfix06_2_acquisition_fixture")
	for component_value in required_items:
		run.add_item(str(component_value))
	var event_module := EventModuleScript.new()
	event_module.setup(bench_definition, library)
	var recipe_available := false
	for choice_value in event_module.choices(run, run.current_environment):
		if typeof(choice_value) == TYPE_DICTIONARY and str((choice_value as Dictionary).get("id", "")) == recipe_id:
			recipe_available = true
			break
	if not recipe_available:
		failures.append("CR-PF-001: the production Mags bench does not offer its loaded-dice recipe at the authored gates.")
		return
	var result: Dictionary = event_module.resolve(run, run.current_environment, recipe_id)
	var components_consumed := true
	for component_value in required_items:
		components_consumed = components_consumed and not run.inventory.has(str(component_value))
	# EventModule.resolve owns the production apply boundary. A second direct
	# GameModule.apply_result call would be a duplicate settlement, not proof of
	# the actual acquisition path.
	if not bool(result.get("ok", false)) or not run.inventory.has(item_id) or not components_consumed or run.bankroll != 1:
		failures.append("CR-PF-001: the production Mags bench did not consume its price/components and acquire %s: %s" % [item_id, JSON.stringify(result)])


func _check_nested_item_reference_validation(library, craps_definition: Dictionary) -> void:
	var fixture := craps_definition.duplicate(true)
	fixture["postfix_nested_reference_fixture"] = {
		"required_item_ids": ["dice_calipers", "postfix_unknown_required_item"],
		"nested": [{
			"practice_item_ids": ["postfix_unknown_practice_item"],
			"loaded_dice_item_ids": ["postfix_unknown_loaded_item"],
			"reward_item_id": "postfix_unknown_single_item",
		}],
	}
	library.games = [fixture]
	library.validation_errors = []
	library.call("_validate_game_definitions")
	var errors := "\n".join(library.validation_errors)
	for unknown_id in [
		"postfix_unknown_required_item",
		"postfix_unknown_practice_item",
		"postfix_unknown_loaded_item",
		"postfix_unknown_single_item",
	]:
		if errors.find(unknown_id) < 0:
			failures.append("CR-PF-001: nested game item-reference validation accepted %s. Errors: %s" % [unknown_id, errors])


func _check_loaded_dice_bonus(library, craps_definition: Dictionary, switching: Dictionary, loaded_ids: Array) -> void:
	var craps := CrapsScript.new()
	craps.setup(craps_definition, library)
	var environment := {
		"id": "postfix_craps_switching",
		"archetype_id": "grand_casino",
		"kind": "boss",
		"security_profile": {"strictness": "standard"},
	}
	var without_loaded := RunStateScript.new()
	without_loaded.start_new("POSTFIX06-2-CRAPS-NO-LOADED")
	for item_id_value in switching.get("required_item_ids", []):
		without_loaded.add_item(str(item_id_value))
	var ui_state := {"craps_switching_challenge": {"skill_grade": "perfect", "skill_margin_msec": 0}}
	var table := {"table_minimum": 5}
	var ordinary: Dictionary = craps.call("_cheat_context", "dice_switching", ui_state, without_loaded, environment, table)
	var bonus := int(switching.get("loaded_dice_bias_bonus_permille", 0))
	var grades: Dictionary = switching.get("grades", {}) if typeof(switching.get("grades", {})) == TYPE_DICTIONARY else {}
	var perfect: Dictionary = grades.get("perfect", {}) if typeof(grades.get("perfect", {})) == TYPE_DICTIONARY else {}
	var expected_ordinary_bias := int(perfect.get("bias_permille", 0))
	if not bool(ordinary.get("ok", false)) or int(ordinary.get("bias_permille", -1)) != expected_ordinary_bias:
		failures.append("CR-PF-001: the neither-owned control did not retain the unbonused perfect-grade bias: %s" % JSON.stringify(ordinary))
		return
	for loaded_id_value in loaded_ids:
		var loaded_id := str(loaded_id_value)
		var with_loaded := RunStateScript.new()
		with_loaded.start_new("POSTFIX06-2-CRAPS-WITH-%s" % loaded_id.to_upper())
		for required_id_value in switching.get("required_item_ids", []):
			with_loaded.add_item(str(required_id_value))
		with_loaded.add_item(loaded_id)
		var loaded: Dictionary = craps.call("_cheat_context", "dice_switching", ui_state, with_loaded, environment, table)
		if not bool(loaded.get("ok", false)):
			failures.append("CR-PF-001: %s did not reach a successful switching context." % loaded_id)
		elif int(loaded.get("bias_permille", 0)) - int(ordinary.get("bias_permille", 0)) != bonus:
			failures.append("CR-PF-001: %s did not add exactly %d permille over the neither-owned control: %s / %s" % [loaded_id, bonus, JSON.stringify(ordinary), JSON.stringify(loaded)])


func _choice_by_id(rows: Array, choice_id: String) -> Dictionary:
	for value in rows:
		if typeof(value) == TYPE_DICTIONARY and str((value as Dictionary).get("id", "")) == choice_id:
			return value as Dictionary
	return {}


func _occurrences(text: String, needle: String) -> int:
	if needle.is_empty():
		return 0
	var count := 0
	var offset := 0
	while true:
		var found := text.find(needle, offset)
		if found < 0:
			return count
		count += 1
		offset = found + needle.length()
	return count


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var finish := source.find("\nfunc ", start + 6)
	return source.substr(start) if finish < 0 else source.substr(start, finish - start)
