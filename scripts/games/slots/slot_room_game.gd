extends GameModule

# Seeded fixtures and room readouts share the cabinet's state and timing
# without compiling interactive settlement, presentation, or rendering.

const StateScript := preload("res://scripts/games/slots/slot_machine_state.gd")
const DefinitionCacheScript := preload("res://scripts/games/slots/slot_definition_cache.gd")
const CatalogScript := preload("res://scripts/games/slots/slot_catalog.gd")
const GeneratorScript := preload("res://scripts/games/slots/slot_machine_generator.gd")
const HeatScript := preload("res://scripts/games/slots/slot_heat.gd")
const SLOT_BONUS_RECOVERY_PATH := "res://scripts/games/slots/slot_bonus_recovery.gd"
const SLOT_AUTOPLAY_LOSS_HOLD_MSEC := 100
const SLOT_AUTOPLAY_WIN_HOLD_MSEC := 500
const SLOT_RESULT_REVEAL_BEAT_MSEC := 180
const BUFFALO_AUTOPLAY_MAX_DELAY_MSEC := 10000
const SLOT_ENV_PREVIEW_MAX_REELS := 6
const SLOT_ENV_PREVIEW_MAX_ROWS := 4
const SLOT_CONTEXTUAL_ITEM_EFFECT_KEYS := [
	"win_bonus", "payout_delta", "loss_reduction",
	"slot_nudge_perfect_msec_bonus", "slot_nudge_close_msec_bonus",
	"slot_cold_quarter_heat_reduction", "slot_split_reel_note_perfect_msec_bonus",
	"slot_split_reel_note_close_msec_bonus",
]
const SLOT_LEGAL_ITEM_EFFECT_KEYS := [
	"slot_three_reel_loss_refund_percent", "slot_gold_tooth_coin_upgrade_chance",
	"slot_gold_tooth_coin_multiplier", "slot_first_bonus_bonus_percent",
	"slot_first_bonus_bonus_cap", "slot_feature_weight_bonus_percent",
	"slot_reel_win_weight_percent", "slot_pinball_drain_cleaner_uses",
	"slot_pinball_drain_cleaner_floor_percent", "slot_pinball_drain_cleaner_award_percent",
	"slot_pinball_jackpot_magnet_uses", "slot_pinball_jackpot_magnet_award_percent",
	"slot_pinball_jackpot_magnet_progress_bonus", "slot_pinball_splitter_token_uses",
	"slot_pinball_splitter_token_extra_balls", "slot_pinball_return_spring_uses",
	"slot_pinball_return_spring_impulse", "slot_pinball_tilt_dampener_percent",
	"slot_pinball_bumper_battery_hits", "slot_pinball_bumper_battery_award_percent",
	"slot_pinball_bumper_battery_kick_percent", "slot_pinball_bumper_battery_up_impulse",
	"slot_pinball_rubber_pegs", "slot_pinball_magnet_cup_radius_percent",
	"slot_pinball_extra_ball_token", "slot_pinball_plunger_tuner_width_percent",
	"slot_pinball_lock_jammer_uses",
]

var generator
var catalog
var definition_cache
var _bonus_recovery_script: Script


func setup(p_definition: Dictionary, p_library: ContentLibrary = null) -> void:
	super.setup(p_definition, p_library)
	definition_cache = DefinitionCacheScript.new()
	definition_cache.configure(p_definition)
	generator = GeneratorScript.new()
	catalog = CatalogScript.new()


static func requires_playable_module(environment: Dictionary) -> bool:
	var states_value: Variant = environment.get("game_states", {})
	if states_value is not Dictionary:
		return false
	var states: Dictionary = states_value
	for state_key in states:
		if state_key != "slot" and not str(state_key).begins_with("slot:"):
			continue
		var machine := StateScript.peek_machine(environment, str(state_key))
		if bool(machine.get("slot_autoplay_active", false)) or _needs_bonus_authority(machine):
			return true
	return false


static func _needs_bonus_authority(machine: Dictionary) -> bool:
	var active: Variant = machine.get("active_bonus", null)
	return active is Dictionary and (bool(active.get("active", false)) or bool(active.get("visual_replay", false)))


func gameplay_model() -> String:
	return GameModule.GAMEPLAY_MODEL_FULL_SIMULATION


func actions(run_state: RunState, environment: Dictionary) -> Dictionary:
	_ensure_machine_state(run_state, environment, run_state.create_rng("slot_actions") if run_state != null else null)
	var machine: Dictionary = _read_machine(environment)
	var selected: Dictionary = StateScript.selected_bet(machine)
	var ceiling := run_state.wager_stake_ceiling(maxi(20, run_state.wager_capacity_for_game(get_id(), environment))) if run_state != null else 20
	return {
		"ok": true,
		"type": "game_actions",
		"game_id": get_id(),
		"legal_actions": legal_actions(run_state, environment),
		"cheat_actions": cheat_actions(run_state, environment),
		"stake_floor": 2,
		"stake_ceiling": maxi(2, ceiling),
		"base_stake_ceiling": maxi(2, ceiling),
		"economy_stake_ceiling": maxi(2, ceiling),
		"economy_state": run_state.economy() if run_state != null else {},
		"economy_pressure_applied": false,
		"selected_stake": int(selected.get("total_credits", 2)),
	}


func legal_actions(_run_state: RunState, _environment: Dictionary) -> Array:
	if _bonus_recovery_required(_peek_machine(_environment)):
		return []
	return _slot_copy_array(definition.get("legal_actions", []))


func cheat_actions(run_state: RunState, environment: Dictionary) -> Array:
	if _bonus_recovery_required(_peek_machine(environment)):
		return []
	var actions: Array = super.cheat_actions(run_state, environment)
	var machine: Dictionary = _read_machine(environment)
	var nudge_ready := not _slot_copy_dict(machine.get("last_nudge_offer", {})).is_empty()
	for i in range(actions.size()):
		if typeof(actions[i]) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = actions[i]
		if str(action.get("id", "")) == "nudge":
			action["summary"] = "Time the coin chain; heat +%d per nudge." % int(action.get("suspicion_delta", 12)) if nudge_ready else "Watch for a coin-chain tease; heat +%d." % int(action.get("suspicion_delta", 12))
			actions[i] = action
	return actions


func generate_environment_state(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var machine: Dictionary = _generate_seeded_machine(run_state, environment, rng)
	return definition_cache.compact_machine_for_storage(machine)


func _generate_seeded_machine(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var environment_id := str(environment.get("id", "environment"))
	var archetype_id := str(environment.get("archetype_id", environment.get("kind", "archetype")))
	var stream_key := "slot_machine:%s:%s:%s" % [get_id(), environment_id, archetype_id]
	var generation_rng: RngStream = run_state.create_rng(stream_key) if run_state != null else rng.fork(stream_key)
	return generator.generate_machine(generation_rng, definition)


func generate_environment_fixture_states(_run_state: RunState, environment: Dictionary, rng: RngStream, fixture_count: int) -> Dictionary:
	var local_flags: Dictionary = environment.get("local_narrative_flags", {}) if typeof(environment.get("local_narrative_flags", {})) == TYPE_DICTIONARY else {}
	var supported_room := str(environment.get("archetype_id", "")) == RunState.GRAND_CASINO_ARCHETYPE_ID \
			or bool(local_flags.get("practice_session", false))
	if not supported_room or fixture_count <= 0:
		return {}
	var fixture_specs := [
		{"format_id": "classic_3_reel", "type_id": "pinball", "math_variant_id": "steady", "cabinet_variant_id": "neon_magenta", "bonus_variant_id": "plain"},
		{"format_id": "line_5x3", "type_id": "buffalo", "math_variant_id": "standard", "cabinet_variant_id": "cyan_gold", "bonus_variant_id": "retrigger"},
		{"format_id": "video_feature", "type_id": "pinball", "math_variant_id": "volatile", "cabinet_variant_id": "blacklight", "bonus_variant_id": "jackpot_chase"},
		{"format_id": "classic_3_reel", "type_id": "buffalo", "math_variant_id": "steady", "cabinet_variant_id": "cyan_gold", "bonus_variant_id": "plain"},
		{"format_id": "line_5x3", "type_id": "pinball", "math_variant_id": "standard", "cabinet_variant_id": "blacklight", "bonus_variant_id": "retrigger"},
		{"format_id": "video_feature", "type_id": "buffalo", "math_variant_id": "volatile", "cabinet_variant_id": "neon_magenta", "bonus_variant_id": "jackpot_chase"},
	]
	var result: Dictionary = {}
	for fixture_index in range(fixture_count):
		var key := get_id() if fixture_index == 0 else "%s:%d" % [get_id(), fixture_index + 1]
		var spec: Dictionary = fixture_specs[fixture_index % fixture_specs.size()]
		var machine: Dictionary = generator.build_machine_from_ids(definition, spec, rng.fork("grand_casino_slot_fixture:%d" % fixture_index))
		var skin: Dictionary = catalog.skin_for_machine(machine, definition)
		machine["environment_display_name"] = str(skin.get("cabinet_title", "Slot"))
		# Build the immutable family/format view during room generation, outside
		# active play, so the first autoplay spin for a newly unique cabinet cannot
		# pay a one-time strip/cache construction cost.
		definition_cache.view_for_machine(machine)
		result[key] = definition_cache.compact_machine_for_storage(machine)
	return result


func _machine_state_key(environment: Dictionary) -> String:
	var default_key := get_id()
	var transient_key := transient_state_key_context()
	if transient_key == default_key or transient_key.begins_with("%s:" % default_key):
		return transient_key
	var active_keys_value: Variant = environment.get("active_game_state_keys", {})
	if typeof(active_keys_value) != TYPE_DICTIONARY:
		return default_key
	var active_key := str((active_keys_value as Dictionary).get(default_key, default_key)).strip_edges()
	if active_key == default_key or active_key.begins_with("%s:" % default_key):
		return active_key
	return default_key


func _read_machine(environment: Dictionary) -> Dictionary:
	return definition_cache.owned_runtime_machine(StateScript.peek_machine(environment, _machine_state_key(environment)))


func _bonus_recovery_required(machine: Dictionary) -> bool:
	if not _needs_bonus_authority(machine):
		return false
	# Only a recorded bonus needs the Pinball-dependent compatibility rules.
	if _bonus_recovery_script == null:
		_bonus_recovery_script = load(SLOT_BONUS_RECOVERY_PATH) as Script
	var machine_view: Dictionary = _bonus_recovery_script.call("machine_view", machine, definition)
	return bool(_bonus_recovery_script.call("recovery_required", machine_view, definition))


func _peek_machine(environment: Dictionary) -> Dictionary:
	return StateScript.peek_machine(environment, _machine_state_key(environment))


func _write_machine(environment: Dictionary, machine: Dictionary, consume_saved_checkpoint: bool = true) -> void:
	if consume_saved_checkpoint:
		machine.erase("slot_animation_resume_elapsed_msec")
	StateScript.write_runtime_machine(environment, _machine_state_key(environment), machine)


func environment_runtime_enabled() -> bool:
	# The host consults this room source for due times and resolves due spins
	# through the playable Slot module's wager and settlement authority.
	return true


func environment_runtime_needs_tick(_run_state: RunState, environment: Dictionary, now_msec: int) -> bool:
	# Per-frame check: peek (zero-copy, read-only) instead of deep-copying the machine.
	var machine: Dictionary = _peek_machine(environment)
	if machine.is_empty() or not bool(machine.get("slot_autoplay_active", false)):
		return false
	var next_msec := int(machine.get("slot_autoplay_next_msec", 0))
	return next_msec <= 0 or now_msec >= next_msec


func environment_runtime_next_due_msec(_run_state: RunState, environment: Dictionary, now_msec: int) -> int:
	var machine: Dictionary = _peek_machine(environment)
	if machine.is_empty() or not bool(machine.get("slot_autoplay_active", false)):
		return -1
	var next_msec := int(machine.get("slot_autoplay_next_msec", 0))
	return now_msec if next_msec <= 0 else next_msec


func environment_runtime_state(_run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine: Dictionary = _read_machine(environment)
	if machine.is_empty():
		return {}
	return _slot_environment_runtime_state_for_machine(machine)


func environment_object_state(run_state: RunState, environment: Dictionary) -> Dictionary:
	var machine: Dictionary = _read_machine(environment)
	if machine.is_empty():
		return {}
	return _slot_environment_object_state_for_machine(machine, run_state, environment)


func environment_object_state_for_state_key(run_state: RunState, environment: Dictionary, state_key: String) -> Dictionary:
	var machine: Dictionary = StateScript.read_machine(environment, _normalized_fixture_state_key(state_key))
	if machine.is_empty():
		return {}
	return _slot_environment_object_state_for_machine(machine, run_state, environment)


func _slot_environment_object_state_for_machine(machine: Dictionary, run_state: RunState, environment: Dictionary) -> Dictionary:
	var preview := _slot_environment_preview(machine)
	var runtime := _slot_environment_runtime_state_for_machine(machine, preview)
	return {
		"display_name": str(machine.get("environment_display_name", "Slot")),
		"status_summary": str(runtime.get("status_summary", "")),
		"state_badge": str(runtime.get("status_label", "")),
		"nudge_heat_preview": HeatScript.preview_nudge_heat(machine, run_state, definition, environment, _slot_cross_game_item_effects(run_state, machine, true)),
		"runtime_state": runtime,
		"visual_state": _slot_environment_visual_state(machine, preview),
	}


func _normalized_fixture_state_key(state_key: String) -> String:
	var clean_key := state_key.strip_edges()
	if clean_key == get_id() or clean_key.begins_with("%s:" % get_id()):
		return clean_key
	return get_id()


func _slot_environment_runtime_state_for_machine(machine: Dictionary, preview: Dictionary = {}, now_msec: int = -1) -> Dictionary:
	var active_bonus: Dictionary = _slot_copy_dict(machine.get("active_bonus", {}))
	var nudge_offer: Dictionary = _slot_copy_dict(machine.get("last_nudge_offer", {}))
	var bonus_preview: Dictionary = _slot_copy_dict(preview.get("bonus", {}))
	var nudge_preview: Dictionary = _slot_copy_dict(preview.get("nudge_chain", {}))
	var phase := str(preview.get("phase", ""))
	if phase.is_empty():
		if now_msec < 0:
			now_msec = Time.get_ticks_msec()
		phase = _slot_runtime_phase(machine, active_bonus, nudge_offer, now_msec)
	var bonus_active := bool(bonus_preview.get("active", bool(active_bonus.get("active", false)) and not bool(active_bonus.get("complete", false))))
	var nudge_chain_active := bool(nudge_preview.get("active", not nudge_offer.is_empty() and str(nudge_offer.get("type", "")) == "coin_chain"))
	var active := bool(preview.get("active", _slot_preview_active(machine, active_bonus, nudge_offer, phase)))
	var caption := str(preview.get("caption", _slot_preview_caption(phase, machine, active_bonus, nudge_offer)))
	return {
		"active": active,
		"status_label": str(preview.get("status_label", _slot_preview_status_label(phase, machine, active_bonus, nudge_offer))),
		"status_summary": "Slot spins %d, coin in $%d, coin out $%d." % [int(machine.get("spin_count", 0)), int(machine.get("coin_in", 0)), int(machine.get("coin_out", 0))],
		"spin_count": int(machine.get("spin_count", 0)),
		"slot_autoplay_active": bool(machine.get("slot_autoplay_active", false)),
		"slot_bonus_active": bonus_active,
		"slot_pending_feature": bool(preview.get("pending_feature", bonus_active)),
		"slot_pending_feature_alert": bool(machine.get("slot_pending_feature_alert", false)),
		"slot_bonus_family": str(bonus_preview.get("family", active_bonus.get("family", ""))),
		"slot_feature_audio_cue": _slot_feature_audio_cue(machine) if bool(preview.get("pending_feature", bonus_active)) else "",
		"slot_feature_audio_volume_db": _slot_feature_audio_volume_db(machine) if bool(preview.get("pending_feature", bonus_active)) else -1.0,
		"slot_free_spins": int(machine.get("free_spins", 0)),
		"slot_last_payout": int(machine.get("last_payout", 0)),
		"slot_last_classification": str(machine.get("last_classification", "idle")),
		"slot_preview_phase": phase,
		"slot_preview_caption": caption,
		"slot_nudge_chain_active": nudge_chain_active,
	}


func _slot_environment_visual_state(machine: Dictionary, preview: Dictionary = {}) -> Dictionary:
	var skin: Dictionary = {}
	var environment_catalog = catalog
	if environment_catalog == null:
		environment_catalog = CatalogScript.new()
	if environment_catalog != null:
		skin = environment_catalog.skin_for_machine(machine, definition)
	var active_bonus: Dictionary = _slot_copy_dict(machine.get("active_bonus", {}))
	var resolved_preview := preview
	if resolved_preview.is_empty():
		resolved_preview = _slot_environment_preview(machine)
	return {
		"machine_family": str(machine.get("type_id", "slot")),
		"machine_format": str(machine.get("format_id", "")),
		"machine_key": str(machine.get("machine_key", "")),
		"cabinet_variant_id": str(machine.get("cabinet_variant_id", "")),
		"cabinet_identity": str(skin.get("cabinet_identity", "")),
		"cabinet_title": str(skin.get("cabinet_title", "")),
		"cabinet_material": str(skin.get("material", "")),
		"cabinet_topper_style": str(skin.get("topper_style", "")),
		"cabinet_motion_style": str(skin.get("motion_style", "")),
		"cabinet_background_path": str(skin.get("background_path", "")),
		"cabinet_palette": _slot_copy_dict(skin.get("palette", {})),
		"feature_name": str(skin.get("feature_name", "")),
		"pay_model": str(skin.get("pay_model", "")),
		"reel_count": int(skin.get("reel_count", machine.get("reel_count", 3))),
		"row_count": int(skin.get("row_count", machine.get("row_count", 1))),
		"last_classification": str(machine.get("last_classification", "idle")),
		"last_payout": int(machine.get("last_payout", 0)),
		"free_spins": int(machine.get("free_spins", 0)),
		"active_bonus_family": str(active_bonus.get("family", "")),
		"slot_preview": resolved_preview,
	}


func _slot_environment_preview(machine: Dictionary, now_msec: int = -1) -> Dictionary:
	if now_msec < 0:
		now_msec = Time.get_ticks_msec()
	var reel_count := clampi(int(machine.get("reel_count", 3)), 1, SLOT_ENV_PREVIEW_MAX_REELS)
	var row_count := clampi(int(machine.get("row_count", 1)), 1, SLOT_ENV_PREVIEW_MAX_ROWS)
	var active_bonus: Dictionary = _slot_copy_dict(machine.get("active_bonus", {}))
	var nudge_offer: Dictionary = _slot_copy_dict(machine.get("last_nudge_offer", {}))
	var selected_bet: Dictionary = StateScript.selected_bet(machine)
	var spin_plan: Dictionary = _slot_copy_dict(machine.get("slot_animation_plan", {}))
	var autoplay_delay := _slot_autoplay_delay_msec(machine) if bool(machine.get("slot_autoplay_active", false)) else 0
	var phase := _slot_preview_phase(machine, active_bonus, nudge_offer, now_msec, autoplay_delay, spin_plan)
	var autoplay_next := maxi(0, int(machine.get("slot_autoplay_next_msec", 0)))
	var remaining := maxi(0, autoplay_next - now_msec) if autoplay_next > 0 else 0
	var elapsed := maxi(0, autoplay_delay - remaining) if autoplay_delay > 0 else 0
	var preview := {
		"schema_version": 1,
		"active": _slot_preview_active(machine, active_bonus, nudge_offer, phase),
		"phase": phase,
		"status_label": _slot_preview_status_label(phase, machine, active_bonus, nudge_offer),
		"caption": _slot_preview_caption(phase, machine, active_bonus, nudge_offer),
		"family": str(machine.get("type_id", "slot")),
		"format_id": str(machine.get("format_id", "")),
		"machine_key": str(machine.get("machine_key", "")),
		"reel_count": reel_count,
		"row_count": row_count,
		"grid": _slot_preview_grid(machine.get("last_grid", []), reel_count, row_count),
		"previous_grid": _slot_preview_grid(machine.get("last_previous_grid", []), reel_count, row_count),
		"win_cells": _slot_preview_cells(machine.get("slot_win_cells", [])),
		"win_symbol": str(machine.get("slot_win_symbol", "")),
		"win_reason": str(machine.get("slot_win_reason", "")),
		"payout": maxi(0, int(machine.get("last_payout", 0))),
		"net": int(machine.get("last_net", 0)),
		"classification": str(machine.get("last_classification", "idle")),
		"celebration_tier": str(machine.get("slot_celebration_tier", "none")),
		"spin_count": maxi(0, int(machine.get("spin_count", 0))),
		"selected_bet": int(selected_bet.get("total_credits", 2)),
		"autoplay_active": bool(machine.get("slot_autoplay_active", false)),
		"pending_feature": bool(active_bonus.get("active", false)) and not bool(active_bonus.get("complete", false)),
		"pending_feature_alert": bool(machine.get("slot_pending_feature_alert", false)),
		"autoplay_next_msec": autoplay_next,
		"autoplay_delay_msec": autoplay_delay,
		"autoplay_remaining_msec": remaining,
		"preview_elapsed_msec": elapsed,
		"spin": {
			"animation_id": str(machine.get("slot_animation_id", "")),
			"duration_msec": maxi(0, int(machine.get("slot_animation_duration_msec", 0))),
			"timeline": _slot_preview_timeline(machine.get("slot_reel_timeline", spin_plan.get("reel_timeline", []))),
		},
		"bonus": _slot_preview_bonus(machine, active_bonus),
		"nudge_chain": _slot_preview_nudge_chain(nudge_offer),
	}
	return preview


func _slot_runtime_phase(machine: Dictionary, active_bonus: Dictionary, nudge_offer: Dictionary, now_msec: int) -> String:
	if not nudge_offer.is_empty():
		return "nudge_chain" if str(nudge_offer.get("type", "")) == "coin_chain" else "nudge"
	if bool(active_bonus.get("active", false)) and not bool(active_bonus.get("complete", false)):
		return "bonus"
	var classification := str(machine.get("last_classification", "idle"))
	if bool(machine.get("slot_autoplay_active", false)):
		var animation_id := str(machine.get("slot_animation_id", ""))
		var autoplay_next := int(machine.get("slot_autoplay_next_msec", 0))
		var remaining := maxi(0, autoplay_next - now_msec) if autoplay_next > 0 else 0
		if not animation_id.is_empty() and remaining > _slot_autoplay_outcome_hold_msec(machine):
			return "spinning"
	if maxi(0, int(machine.get("last_payout", 0))) > 0:
		return "win"
	if classification == "near_miss":
		return "near_miss"
	if classification == "nudge_chain_break":
		return "miss"
	if classification == "idle":
		return "autoplay_wait" if bool(machine.get("slot_autoplay_active", false)) else "idle"
	return "autoplay_wait" if bool(machine.get("slot_autoplay_active", false)) else "loss"


func _slot_preview_phase(machine: Dictionary, active_bonus: Dictionary, nudge_offer: Dictionary, now_msec: int, autoplay_delay_msec: int = -1, spin_plan: Dictionary = {}) -> String:
	if not nudge_offer.is_empty():
		return "nudge_chain" if str(nudge_offer.get("type", "")) == "coin_chain" else "nudge"
	if bool(active_bonus.get("active", false)) and not bool(active_bonus.get("complete", false)):
		return "bonus"
	var classification := str(machine.get("last_classification", "idle"))
	if bool(machine.get("slot_autoplay_active", false)):
		var plan: Dictionary = spin_plan if not spin_plan.is_empty() else _slot_copy_dict(machine.get("slot_animation_plan", {}))
		var delay := autoplay_delay_msec if autoplay_delay_msec >= 0 else _slot_autoplay_delay_msec(machine)
		var remaining := maxi(0, int(machine.get("slot_autoplay_next_msec", 0)) - now_msec)
		var elapsed := maxi(0, delay - remaining)
		if not str(machine.get("slot_animation_id", "")).is_empty() and elapsed < _slot_spin_reveal_msec(plan):
			return "spinning"
	if maxi(0, int(machine.get("last_payout", 0))) > 0:
		return "win"
	if classification == "near_miss":
		return "near_miss"
	if classification == "nudge_chain_break":
		return "miss"
	if classification == "idle":
		return "autoplay_wait" if bool(machine.get("slot_autoplay_active", false)) else "idle"
	return "autoplay_wait" if bool(machine.get("slot_autoplay_active", false)) else "loss"


func _slot_preview_active(machine: Dictionary, active_bonus: Dictionary, nudge_offer: Dictionary, phase: String) -> bool:
	if bool(machine.get("slot_autoplay_active", false)) or not nudge_offer.is_empty():
		return true
	if bool(active_bonus.get("active", false)) and not bool(active_bonus.get("complete", false)):
		return true
	return ["spinning", "bonus", "nudge_chain"].has(phase)


func _slot_preview_status_label(phase: String, machine: Dictionary, _active_bonus: Dictionary, _nudge_offer: Dictionary) -> String:
	match phase:
		"spinning":
			return "SPIN"
		"nudge_chain", "nudge":
			return "NUDGE"
		"bonus":
			return "BONUS"
		"win":
			return "WIN"
		"near_miss":
			return "CLOSE"
		"miss":
			return "MISS"
		"autoplay_wait":
			return "AUTO" if bool(machine.get("slot_autoplay_active", false)) else ""
		_:
			return ""


func _slot_preview_caption(phase: String, machine: Dictionary, active_bonus: Dictionary, nudge_offer: Dictionary) -> String:
	match phase:
		"spinning":
			return "Reels spinning"
		"nudge_chain":
			return "Coin chain %d/%d bank $%d" % [
				int(nudge_offer.get("collected_count", 0)),
				int(nudge_offer.get("coin_count", _slot_copy_array(nudge_offer.get("coins", [])).size())),
				int(nudge_offer.get("banked_payout", 0)),
			]
		"nudge":
			return "Timed nudge ready"
		"bonus":
			return "%s %d left" % [
				str(active_bonus.get("mode", "bonus")).replace("_", " ").capitalize(),
				int(active_bonus.get("remaining_steps", active_bonus.get("remaining_spins", machine.get("free_spins", 0)))),
			]
		"win":
			return "Won $%d" % maxi(0, int(machine.get("last_payout", 0)))
		"near_miss":
			return "Near miss"
		"miss":
			return "Chain broke"
		"autoplay_wait":
			return "Autoplay waiting"
		_:
			return "Ready"


func _slot_preview_grid(value: Variant, reel_count: int, row_count: int) -> Array:
	var source: Array = _slot_copy_array(value)
	var result: Array = []
	for reel_index in range(reel_count):
		var column_source: Array = []
		if reel_index < source.size() and typeof(source[reel_index]) == TYPE_ARRAY:
			column_source = (source[reel_index] as Array)
		var column: Array = []
		for row_index in range(row_count):
			var symbol := "BLANK"
			if row_index < column_source.size():
				symbol = str(column_source[row_index])
			column.append(symbol)
		result.append(column)
	return result


func _slot_preview_cells(value: Variant) -> Array:
	var result: Array = []
	for cell_value in _slot_copy_array(value):
		var cell: Dictionary = _slot_copy_dict(cell_value)
		result.append({
			"reel": int(cell.get("reel", -1)),
			"row": int(cell.get("row", -1)),
		})
		if result.size() >= 12:
			break
	return result


func _slot_preview_timeline(value: Variant) -> Array:
	var result: Array = []
	var index := 0
	for entry_value in _slot_copy_array(value):
		var entry: Dictionary = _slot_copy_dict(entry_value)
		result.append({
			"reel": int(entry.get("reel", index)),
			"stop_msec": int(round(float(entry.get("stop_time", 0.0)) * 1000.0)),
			"settle_msec": int(round(float(entry.get("settle_end", entry.get("stop_time", 0.0))) * 1000.0)),
			"tease": bool(entry.get("tease", false)),
		})
		index += 1
		if result.size() >= SLOT_ENV_PREVIEW_MAX_REELS:
			break
	return result


func _slot_preview_bonus(machine: Dictionary, active_bonus: Dictionary) -> Dictionary:
	var active := bool(active_bonus.get("active", false)) and not bool(active_bonus.get("complete", false))
	return {
		"active": active,
		"family": str(active_bonus.get("family", machine.get("type_id", ""))),
		"mode": str(active_bonus.get("mode", "")),
		"step_index": int(active_bonus.get("step_index", 0)),
		"total_steps": int(active_bonus.get("total_steps", active_bonus.get("total_spins", 0))),
		"remaining_steps": int(active_bonus.get("remaining_steps", active_bonus.get("remaining_spins", machine.get("free_spins", 0)))),
		"feature_total": int(active_bonus.get("feature_total", active_bonus.get("pending_award", machine.get("last_bonus_total", 0)))),
		"jackpot_tier": str(active_bonus.get("jackpot_tier", "")),
		"free_spins": int(machine.get("free_spins", 0)),
	}


func _slot_preview_nudge_chain(nudge_offer: Dictionary) -> Dictionary:
	var coins: Array = []
	for coin_value in _slot_copy_array(nudge_offer.get("coins", [])):
		var coin: Dictionary = _slot_copy_dict(coin_value)
		coins.append({
			"index": int(coin.get("index", coins.size())),
			"row": int(coin.get("row", coins.size())),
			"side": str(coin.get("side", "left")),
			"collected": bool(coin.get("collected", false)),
			"ready_msec": int(coin.get("ready_msec", -1)),
		})
		if coins.size() >= SLOT_ENV_PREVIEW_MAX_ROWS:
			break
	return {
		"active": not nudge_offer.is_empty(),
		"type": str(nudge_offer.get("type", "")),
		"coin_count": int(nudge_offer.get("coin_count", coins.size())),
		"active_index": int(nudge_offer.get("active_index", 0)),
		"collected_count": int(nudge_offer.get("collected_count", 0)),
		"banked_payout": int(nudge_offer.get("banked_payout", 0)),
		"last_grade": str(nudge_offer.get("last_grade", "")),
		"last_award": int(nudge_offer.get("last_award", 0)),
		"last_spawned": bool(nudge_offer.get("last_spawned", false)),
		"coins": coins,
	}


func _slot_feature_audio_cue(machine: Dictionary) -> String:
	var family := _slot_active_bonus_family(machine)
	if family == "buffalo":
		return "bonus_start_buffalo"
	if family == "pinball":
		return "bonus_start_pinball"
	return "bonus_start"


func _slot_feature_audio_volume_db(machine: Dictionary) -> float:
	return -7.0 if _slot_active_bonus_family(machine) == "pinball" else -1.0


func _ensure_machine_state(run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var machine: Dictionary = _read_machine(environment)
	if machine.is_empty():
		var generation_rng: RngStream = rng
		if generation_rng == null and run_state != null:
			generation_rng = run_state.create_rng("slot_generate")
		if generation_rng == null:
			generation_rng = RngStream.new()
			generation_rng.configure(1)
		machine = _generate_seeded_machine(run_state, environment, generation_rng)
		_write_machine(environment, machine, false)
	elif not _bonus_recovery_required(machine) and int(machine.get("schema_version", 0)) != StateScript.SCHEMA_VERSION:
		machine = StateScript.normalize(machine)
		_write_machine(environment, machine, false)
	return machine


func _slot_autoplay_delay_msec(machine: Dictionary) -> int:
	var plan: Dictionary = _slot_copy_dict(machine.get("slot_animation_plan", {}))
	var delay := 0
	if not StateScript.active_bonus_incomplete(machine) and not str(machine.get("slot_animation_id", "")).begins_with("bonus:") and not _slot_copy_array(plan.get("reel_timeline", [])).is_empty():
		delay = _slot_spin_reveal_msec(plan) + _slot_autoplay_outcome_hold_msec(machine)
	else:
		delay = _slot_legacy_autoplay_delay_msec(machine)
	if _slot_active_bonus_family(machine) == "buffalo" or str(machine.get("type_id", "")) == "buffalo":
		delay = mini(delay, BUFFALO_AUTOPLAY_MAX_DELAY_MSEC)
	return delay


func _slot_legacy_autoplay_delay_msec(machine: Dictionary) -> int:
	var plan: Dictionary = _slot_copy_dict(machine.get("slot_animation_plan", {}))
	var duration := maxi(0, int(machine.get("slot_animation_duration_msec", 0)))
	duration = maxi(duration, int(plan.get("duration_msec", 0)))
	duration = maxi(duration, int(plan.get("feature_duration_msec", 0)))
	duration = maxi(duration, int(plan.get("count_up_end_msec", 0)))
	duration = maxi(duration, int(plan.get("celebration_start_msec", 0)) + int(plan.get("celebration_duration_msec", 0)))
	for entry_value in _slot_copy_array(plan.get("reel_timeline", [])):
		var entry: Dictionary = _slot_copy_dict(entry_value)
		duration = maxi(duration, int(ceil(float(entry.get("settle_end", 0.0)) * 1000.0)))
	return maxi(900, duration + 120)


func _slot_spin_reveal_msec(plan: Dictionary) -> int:
	var reveal_msec := 0
	for entry_value in _slot_copy_array(plan.get("reel_timeline", [])):
		var entry: Dictionary = _slot_copy_dict(entry_value)
		reveal_msec = maxi(reveal_msec, int(ceil(float(entry.get("settle_end", entry.get("stop_time", 0.0))) * 1000.0)))
	return reveal_msec + SLOT_RESULT_REVEAL_BEAT_MSEC


func _slot_autoplay_outcome_hold_msec(machine: Dictionary) -> int:
	if int(machine.get("last_payout", 0)) > 0:
		return SLOT_AUTOPLAY_WIN_HOLD_MSEC
	if str(machine.get("last_classification", "")) == "near_miss":
		return SLOT_AUTOPLAY_WIN_HOLD_MSEC
	if str(machine.get("slot_celebration_tier", "none")) != "none":
		return SLOT_AUTOPLAY_WIN_HOLD_MSEC
	return SLOT_AUTOPLAY_LOSS_HOLD_MSEC


func _slot_active_bonus_family(machine: Dictionary) -> String:
	var active: Dictionary = _slot_copy_dict(machine.get("active_bonus", {}))
	return str(active.get("family", machine.get("type_id", "")))


func _slot_cross_game_item_effects(run_state: RunState, machine: Dictionary, is_cheat: bool) -> Dictionary:
	if run_state == null:
		return {}
	var item_state: Dictionary = _slot_copy_dict(machine.get("slot_item_state", {}))
	var effects := run_state.item_effect_totals(SLOT_LEGAL_ITEM_EFFECT_KEYS, get_family(), "legal")
	var contextual := run_state.item_effect_totals(SLOT_CONTEXTUAL_ITEM_EFFECT_KEYS, get_family(), "cheat" if is_cheat else "legal")
	for key_value in contextual.keys():
		effects[key_value] = contextual[key_value]
	effects["cheat_suspicion_delta"] = run_state.item_effect_total("cheat_suspicion_delta", get_family(), "cheat")
	for override_key in [
		"slot_cold_quarter_heat_reduction",
		"slot_split_reel_note_perfect_msec_bonus",
		"slot_split_reel_note_close_msec_bonus",
	]:
		var state_key: String = override_key.trim_prefix("slot_")
		if item_state.has(state_key):
			effects[override_key] = int(item_state.get(state_key, 0))
	return effects


func _slot_copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


func _slot_copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)
