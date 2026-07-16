class_name GameModule
extends RefCounted

# Base contract for foundation gambling modules.

const RESULT_CONTINUE := "continue"
const RESULT_ENDED := "ended"
const GAMEPLAY_MODEL_GENERIC_ODDS := "generic_odds"
const GAMEPLAY_MODEL_FULL_SIMULATION := "full_simulation"
const TABLE_ROUND_START_DELAY_MSEC := 20000
const TABLE_ROUND_WARNING_MSEC := 5000

var definition: Dictionary = {}
var library: ContentLibrary


# Stores the game definition used by this module.
func setup(p_definition: Dictionary, p_library: ContentLibrary = null) -> void:
	definition = p_definition.duplicate(true)
	library = p_library


# Returns this game id.
func get_id() -> String:
	return str(definition.get("id", ""))


# Returns the player-facing game name.
func get_display_name() -> String:
	return str(definition.get("display_name", get_id()))


# Returns the game family used by item modifiers.
func get_family() -> String:
	return str(definition.get("family", ""))


# Distinguishes simple data-authored odds games from modules that own their
# full subgame state and rules.
func gameplay_model() -> String:
	if bool(definition.get("full_simulation", false)):
		return GAMEPLAY_MODEL_FULL_SIMULATION
	var model := str(definition.get("gameplay_model", GAMEPLAY_MODEL_GENERIC_ODDS))
	return GAMEPLAY_MODEL_FULL_SIMULATION if model == GAMEPLAY_MODEL_FULL_SIMULATION else GAMEPLAY_MODEL_GENERIC_ODDS


func is_full_simulation() -> bool:
	return gameplay_model() == GAMEPLAY_MODEL_FULL_SIMULATION


# Creates the entry message shown when a player enters the game.
func enter(_run_state: RunState, environment: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"type": "game_enter",
		"game_id": get_id(),
		"environment_id": environment.get("id", ""),
		"message": str(definition.get("intro", "You sit down to play.")),
	}


# Returns legal actions from the game definition.
func legal_actions(_run_state: RunState, _environment: Dictionary) -> Array:
	return _copy_array(definition.get("legal_actions", []))


# Returns cheat actions from the game definition.
func cheat_actions(run_state: RunState, environment: Dictionary) -> Array:
	if run_state != null and run_state.challenge_cheat_actions_disabled():
		return []
	var actions := _copy_array(definition.get("cheat_actions", []))
	var result: Array = []
	var security_bonus := run_state.security_risk_bonus("cheat") if run_state != null else 0
	var pit_boss_status := run_state.pit_boss_watch_status(environment) if run_state != null else {}
	var pit_boss_bonus := int(pit_boss_status.get("cheat_heat_bonus", 0)) if bool(pit_boss_status.get("active", false)) else 0
	for action in actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var action_data := (action as Dictionary).duplicate(true)
		var base_delta := int(action_data.get("suspicion_delta", 0))
		action_data["base_suspicion_delta"] = base_delta
		action_data["suspicion_delta"] = maxi(0, base_delta + security_bonus + pit_boss_bonus)
		action_data["security_pressure_bonus"] = security_bonus
		action_data["pit_boss_heat_bonus"] = pit_boss_bonus
		action_data["pit_boss_watched"] = bool(pit_boss_status.get("watched", false))
		if run_state != null:
			action_data["security_pressure"] = run_state.security_pressure_label()
			action_data["security_pressure_summary"] = run_state.security_pressure_summary()
			if bool(pit_boss_status.get("active", false)):
				var pit_summary := str(pit_boss_status.get("summary", ""))
				if not pit_summary.is_empty():
					action_data["security_pressure_summary"] = "%s %s" % [action_data["security_pressure_summary"], pit_summary]
		result.append(action_data)
	return result


# Packages all actions and stake bounds for the UI.
func actions(run_state: RunState, environment: Dictionary) -> Dictionary:
	var economic_profile: Dictionary = environment.get("economic_profile", {})
	var base_stake_ceiling := stake_ceiling_for_game(environment, get_id(), run_state.wager_capacity_for_game(get_id(), environment))
	var economy_stake_ceiling := run_state.economy_stake_ceiling(base_stake_ceiling)
	var wager_stake_ceiling := run_state.wager_stake_ceiling(base_stake_ceiling)
	return {
		"ok": true,
		"type": "game_actions",
		"game_id": get_id(),
		"legal_actions": legal_actions(run_state, environment),
		"cheat_actions": cheat_actions(run_state, environment),
		"stake_floor": int(economic_profile.get("stake_floor", 1)),
		"stake_ceiling": wager_stake_ceiling,
		"base_stake_ceiling": base_stake_ceiling,
		"economy_stake_ceiling": economy_stake_ceiling,
		"economy_state": run_state.economy(),
		"economy_pressure_applied": economy_stake_ceiling < wager_stake_ceiling,
	}


# Returns the room stake ceiling, optionally overridden per game id.
static func stake_ceiling_for_game(environment: Dictionary, game_id: String, fallback_ceiling: int = 1) -> int:
	var economic_profile: Dictionary = environment.get("economic_profile", {}) if typeof(environment.get("economic_profile", {})) == TYPE_DICTIONARY else {}
	var ceiling := int(economic_profile.get("stake_ceiling", fallback_ceiling))
	var overrides: Dictionary = economic_profile.get("game_stake_ceiling_overrides", {}) if typeof(economic_profile.get("game_stake_ceiling_overrides", {})) == TYPE_DICTIONARY else {}
	var normalized_game_id := game_id.strip_edges()
	if not normalized_game_id.is_empty() and overrides.has(normalized_game_id):
		ceiling = int(overrides.get(normalized_game_id, ceiling))
	return maxi(0, ceiling)


# Optional game-specific surface presentation. Returned data is display/input
# state only; simulation changes still happen through resolve/apply_result.
func surface_state(_run_state: RunState, _environment: Dictionary, _ui_state: Dictionary = {}) -> Dictionary:
	return {}


# Reports whether a wager that already started still needs player/automatic
# actions before its outcome is final. Venue closing may block a new wager, but
# must never strand one of these in-progress activities.
func wager_activity_incomplete(_run_state: RunState, _environment: Dictionary, _ui_state: Dictionary = {}) -> bool:
	return false


# Optional game-owned renderer for the active surface. The shared UI canvas
# passes itself in only as a draw/hit host; game-specific scene composition must
# stay in the concrete game module.
func draw_surface(_surface_canvas, _surface_state: Dictionary, _render_context: Dictionary = {}) -> bool:
	return false


# Optional game-specific state generated with an environment before the UI sees
# it. This lets involved games own machine/table state without mutating on
# selection or entry.
func generate_environment_state(_run_state: RunState, _environment: Dictionary, _rng: RngStream) -> Dictionary:
	return {}


# Optional translation layer for visible game-surface clicks. Modules can
# update UI-local state or nominate an existing legal/cheat action to resolve.
func surface_action_command(_surface_action: String, _index: int, _confirm_requested: bool, _ui_state: Dictionary, _run_state: RunState, _environment: Dictionary) -> Dictionary:
	return {"handled": false}


# Optional per-frame game-surface automation hook. The foundation UI provides
# only UI-local state, the current environment, and a surface snapshot; modules
# decide whether to request a resolved action.
func surface_needs_auto_tick(_ui_state: Dictionary, _run_state: RunState, _environment: Dictionary) -> bool:
	return false


func surface_auto_tick_state_keys() -> Array:
	return []


func surface_auto_action_command(_ui_state: Dictionary, _run_state: RunState, _environment: Dictionary, _surface_status: Dictionary = {}) -> Dictionary:
	return {"handled": false}


# Optional hook for stopping repeating surface actions before the shared UI opens
# a blocking decision popup such as an all-in wager confirmation.
func surface_pause_repeating_action_for_confirmation(_ui_state: Dictionary, _run_state: RunState, _environment: Dictionary) -> Dictionary:
	return {"handled": false}


# Optional environment-level runtime state. Games use this for persistent
# machine/table activity that should continue while the detailed surface is
# closed, such as an autoplaying slot cabinet.
func environment_runtime_state(_run_state: RunState, _environment: Dictionary) -> Dictionary:
	return {}


func environment_runtime_needs_tick(_run_state: RunState, _environment: Dictionary, _now_msec: int) -> bool:
	return false


func environment_runtime_tick(_run_state: RunState, _environment: Dictionary, _rng: RngStream, _now_msec: int) -> Dictionary:
	return {"handled": false}


# Optional game-authored presentation payload for the room sprite/object.
# Foundation UI merges this with the data definition and runtime state.
func environment_object_state(_run_state: RunState, _environment: Dictionary) -> Dictionary:
	return {}


# Optional game-authored room objects, such as a cashier or attendant attached
# to a specific machine. Foundation UI renders and activates these generically.
func environment_interactable_objects(_run_state: RunState, _environment: Dictionary) -> Array:
	return []


# Optional action resolver for game-authored room objects.
func environment_action_command(_hook_id: String, _action_id: String, _run_state: RunState, _environment: Dictionary, _rng: RngStream) -> Dictionary:
	return {"handled": false}


# Optional action resolver for active inventory items used against the current
# game surface or environment.
func active_item_command(_item_id: String, _run_state: RunState, _environment: Dictionary, _rng: RngStream) -> Dictionary:
	return {"handled": false}


# Optional resolve entry point that receives UI-local surface context. The
# default preserves the existing foundation GameModule behavior.
func resolve_with_context(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream, _ui_state: Dictionary = {}) -> Dictionary:
	return resolve(action_id, stake, run_state, environment, rng)


# Returns the bankroll at risk for a selected action before the result is known.
# Concrete games can override this when free plays or fixed-price tickets apply.
func wager_cost_for_context(_action_id: String, stake: int, _run_state: RunState, _environment: Dictionary, _ui_state: Dictionary = {}) -> int:
	return maxi(0, stake)


# Returns cash guaranteed to be credited back even in the action's worst
# possible bankroll outcome. Games can override this for refund effects.
func minimum_wager_return_for_context(_action_id: String, _stake: int, _wager_cost: int, _run_state: RunState, _environment: Dictionary, _ui_state: Dictionary = {}) -> int:
	return 0


# Returns the shared result-delta shape used by foundation modules.
static func empty_result_deltas() -> Dictionary:
	return {
		"bankroll_delta": 0,
		"chips_delta": 0,
		"suspicion_delta": 0,
		"alcohol_intake": 0,
		"drunk_delta": 0,
		"pending_drunk_absorption_delta": 0,
		"drunk_distortion_suppression_turns": 0,
		"heat_cooldown_actions": 0,
		"heat_cooldown_per_action": 0,
		"alcoholic_delta": 0,
		"baseline_luck_delta": 0,
		"debt_changes": [],
		"inventory_add": [],
		"inventory_remove": [],
		"flags_set": {},
		"story_flags_set": {},
		"travel_hooks_add": [],
		"travel_changes": {},
		"story_log": [],
		"messages": [],
		"pending_bags": [],
		"ended": false,
		"item_hooks": [],
		"event_hooks": [],
		"demo_finale": {},
	}


# Builds the shared game-surface state shape. Concrete modules can still add
# any renderer-specific fields; these keys are the reusable host contract.
static func surface_spec(payload: Dictionary = {}) -> Dictionary:
	var spec := payload.duplicate(true)
	spec["surface_renderer"] = str(spec.get("surface_renderer", spec.get("renderer", "result")))
	spec["surface_life"] = str(spec.get("surface_life", spec.get("surface_renderer", "result")))
	spec["surface_cast"] = str(spec.get("surface_cast", "none"))
	spec["surface_controls_native"] = bool(spec.get("surface_controls_native", false))
	spec["surface_fixed_price_actions"] = bool(spec.get("surface_fixed_price_actions", false))
	spec["surface_stake_controls_required"] = bool(spec.get("surface_stake_controls_required", true))
	spec["surface_animates_idle"] = bool(spec.get("surface_animates_idle", false))
	spec["surface_realtime_state_refresh"] = bool(spec.get("surface_realtime_state_refresh", false))
	spec["surface_embeds_outcomes"] = bool(spec.get("surface_embeds_outcomes", false))
	spec["surface_suppresses_game_result_burst"] = bool(spec.get("surface_suppresses_game_result_burst", false))
	spec["surface_action_bindings"] = _copy_dict(spec.get("surface_action_bindings", {}))
	spec["native_selected_surface_actions"] = _copy_array(spec.get("native_selected_surface_actions", []))
	spec["surface_animation_channels"] = _normalize_surface_animation_channels(spec.get("surface_animation_channels", []))
	spec["surface_audio"] = _copy_dict(spec.get("surface_audio", {}))
	spec["surface_action_blocks"] = _copy_array(spec.get("surface_action_blocks", []))
	spec["surface_state_labels"] = _copy_array(spec.get("surface_state_labels", []))
	spec["surface_result_display"] = _copy_dict(spec.get("surface_result_display", {}))
	spec["surface_ui_preference_keys"] = _copy_array(spec.get("surface_ui_preference_keys", []))
	return spec


# Declares one reusable animation channel for GameSurfaceCanvas. The module owns
# the ids and timing; the canvas only tracks elapsed time.
static func surface_animation_channel(channel_id: String, active_id: String = "", duration_msec: int = 0, started_msec: int = 0, payload: Dictionary = {}) -> Dictionary:
	var channel := payload.duplicate(true)
	channel["id"] = channel_id
	channel["active_id"] = active_id
	channel["duration_msec"] = maxi(0, duration_msec)
	channel["started_msec"] = maxi(0, started_msec)
	if not channel.has("active"):
		channel["active"] = not active_id.is_empty()
	if not channel.has("restart_on_active_id_change"):
		channel["restart_on_active_id_change"] = true
	if not channel.has("metadata"):
		channel["metadata"] = {}
	return channel


static func surface_audio_spec(payload: Dictionary = {}) -> Dictionary:
	var spec := payload.duplicate(true)
	spec["profile_id"] = str(spec.get("profile_id", "default"))
	spec["action_cues"] = _copy_dict(spec.get("action_cues", {}))
	spec["state_sync"] = _copy_dict(spec.get("state_sync", {}))
	return spec


static func table_round_timer_status(table: Dictionary, now_msec: int, label: String = "Next round", duration_msec: int = TABLE_ROUND_START_DELAY_MSEC, auto_start: bool = true) -> Dictionary:
	return _table_round_timer_status_impl(table, now_msec, label, duration_msec, auto_start, true)


static func table_round_timer_status_peek(table: Dictionary, now_msec: int, label: String = "Next round", duration_msec: int = TABLE_ROUND_START_DELAY_MSEC, auto_start: bool = true) -> Dictionary:
	return _table_round_timer_status_impl(table, now_msec, label, duration_msec, auto_start, false)


static func _table_round_timer_status_impl(table: Dictionary, now_msec: int, label: String, duration_msec: int, auto_start: bool, mutate_start: bool) -> Dictionary:
	var safe_duration := maxi(1000, duration_msec)
	var started := int(table.get("table_round_timer_started_msec", 0))
	if auto_start and mutate_start and started == 0:
		started = now_msec
		table["table_round_timer_started_msec"] = started
	var elapsed := maxi(0, now_msec - started) if started != 0 else 0
	var remaining := maxi(0, safe_duration - elapsed)
	return {
		"active": started != 0,
		"label": label,
		"started_msec": started,
		"duration_msec": safe_duration,
		"elapsed_msec": elapsed,
		"remaining_msec": remaining,
		"remaining_seconds": int(ceil(float(remaining) / 1000.0)),
		"progress": clampf(float(elapsed) / float(safe_duration), 0.0, 1.0),
		"due": started != 0 and elapsed >= safe_duration,
		"warning": remaining <= TABLE_ROUND_WARNING_MSEC,
	}


static func reset_table_round_timer(table: Dictionary, now_msec: int = 0) -> void:
	if now_msec > 0:
		table["table_round_timer_started_msec"] = now_msec
	else:
		table["table_round_timer_started_msec"] = 0


static func deterministic_time_msec(run_state: RunState, ui_state: Dictionary = {}) -> int:
	if ui_state.has("surface_time_msec"):
		return maxi(1, int(ui_state.get("surface_time_msec", 0)))
	if run_state != null:
		return maxi(1, run_state.simulation_time_msec())
	return 1


static func _is_skill_action_kind(action_kind: String) -> bool:
	return action_kind == "cheat" or action_kind == "risky" or action_kind == "advantage"


# Normalizes UI-local command responses from surface click handlers.
static func surface_command(payload: Dictionary = {}) -> Dictionary:
	var command := payload.duplicate(true)
	command["handled"] = bool(command.get("handled", true))
	command["ui_state"] = _copy_dict(command.get("ui_state", {}))
	command["selected_index"] = int(command.get("selected_index", -1))
	command["action_id"] = str(command.get("action_id", ""))
	command["action_kind"] = str(command.get("action_kind", ""))
	command["resolve"] = bool(command.get("resolve", false))
	command["direct_resolve"] = bool(command.get("direct_resolve", false))
	command["skip_stake_validation"] = bool(command.get("skip_stake_validation", false))
	command["preserve_surface_ui_state"] = bool(command.get("preserve_surface_ui_state", false))
	if command.has("set_stake"):
		command["set_stake"] = int(command.get("set_stake", 0))
	if command.has("stake_multiplier"):
		command["stake_multiplier"] = int(command.get("stake_multiplier", 1))
	command["message"] = str(command.get("message", ""))
	return command


static func surface_animation_status(surface_status: Dictionary, channel_id: String) -> Dictionary:
	var animations := _copy_dict(surface_status.get("surface_animations", surface_status.get("surface_animation_status", {})))
	var status := _copy_dict(animations.get(channel_id, {}))
	if status.is_empty():
		var channels := _copy_array(surface_status.get("surface_animation_channels", []))
		for channel_value in channels:
			if typeof(channel_value) != TYPE_DICTIONARY:
				continue
			var channel: Dictionary = channel_value
			if str(channel.get("id", "")) == channel_id:
				return channel.duplicate(true)
	return status


static func normalize_skill_timing_windows(perfect_msec: int, good_msec: int, close_msec: int, min_perfect_msec: int = 1) -> Dictionary:
	var perfect := maxi(maxi(1, min_perfect_msec), perfect_msec)
	var good := maxi(perfect, good_msec)
	var close := maxi(good, close_msec)
	return {
		"perfect_window_msec": perfect,
		"good_window_msec": good,
		"close_window_msec": close,
	}


static func skill_timing_grade_from_distance(distance_msec: int, perfect_msec: int, good_msec: int, close_msec: int, min_perfect_msec: int = 1) -> Dictionary:
	var windows := normalize_skill_timing_windows(perfect_msec, good_msec, close_msec, min_perfect_msec)
	var distance := maxi(0, distance_msec)
	var perfect := int(windows.get("perfect_window_msec", 1))
	var good := int(windows.get("good_window_msec", perfect))
	var close := int(windows.get("close_window_msec", good))
	var grade := "blown"
	if distance <= perfect:
		grade = "perfect"
	elif distance <= good:
		grade = "good"
	elif distance <= close:
		grade = "partial"
	var accuracy := 0
	if grade != "blown":
		accuracy = clampi(100 - int(round(float(distance) / float(close) * 100.0)), 0, 100)
	return {
		"skill_grade": grade,
		"skill_accuracy": accuracy,
		"skill_distance_msec": distance,
		"windows": windows,
	}


static func skill_grade_applies(grade: String) -> bool:
	return grade == "perfect" or grade == "good" or grade == "partial"


static func skill_outcome_for_grade(prefix: String, grade: String, fallback_grade: String = "miss") -> String:
	var resolved_grade := grade if not grade.is_empty() else fallback_grade
	return "%s_%s" % [prefix, resolved_grade]


# Builds a normalized ActionResult dictionary from module payload data.
static func build_action_result(payload: Dictionary = {}) -> Dictionary:
	var source_deltas := _copy_dict(payload.get("deltas", {}))
	for key in ["bankroll_delta", "suspicion_delta", "alcohol_intake", "drunk_delta", "pending_drunk_absorption_delta", "drunk_distortion_suppression_turns", "heat_cooldown_actions", "heat_cooldown_per_action", "alcoholic_delta", "baseline_luck_delta", "ended"]:
		if payload.has(key) and not source_deltas.has(key):
			source_deltas[key] = payload[key]
	if payload.has("messages") and not source_deltas.has("messages"):
		source_deltas["messages"] = _copy_array(payload.get("messages", []))
	var deltas := _normalize_result_deltas(source_deltas)
	var message := str(payload.get("message", ""))
	if message.is_empty() and not deltas["messages"].is_empty():
		message = str(deltas["messages"][0])
	if not message.is_empty() and deltas["messages"].is_empty():
		deltas["messages"] = [message]
	var ended := bool(deltas.get("ended", false))
	var result := {
		"ok": bool(payload.get("ok", true)),
		"type": str(payload.get("type", "action_result")),
		"source_id": str(payload.get("source_id", "")),
		"game_id": str(payload.get("game_id", "")),
		"action_id": str(payload.get("action_id", "")),
		"action_kind": str(payload.get("action_kind", "unknown")),
		"stake": int(payload.get("stake", 0)),
		"bankroll_delta": int(deltas.get("bankroll_delta", 0)),
		"suspicion_delta": int(deltas.get("suspicion_delta", 0)),
		"deltas": deltas,
		"won": bool(payload.get("won", false)),
		"ended": ended,
		"state": RESULT_ENDED if ended else RESULT_CONTINUE,
		"environment_id": str(payload.get("environment_id", "")),
		"environment_archetype_id": str(payload.get("environment_archetype_id", "")),
		"message": message,
		"messages": _copy_array(deltas.get("messages", [])),
	}
	return normalize_skill_cheat_contract(result, payload)


# Adds the cross-game skill-cheat contract to cheat/risky/advantage results.
# Game-specific modules still own their rules; this keeps shared systems from
# chasing blackjack_*, slot_*, roulette_*, etc. variants for the same facts.
static func normalize_skill_cheat_contract(result: Dictionary, payload: Dictionary = {}) -> Dictionary:
	var action_kind := str(result.get("action_kind", ""))
	if not _is_skill_action_kind(action_kind):
		return result
	var deltas := _normalize_result_deltas(result.get("deltas", {}))
	var story_entries := _copy_array(deltas.get("story_log", []))
	var story_context := _matching_story_entry(story_entries, result)
	var suspicion_delta := int(result.get("suspicion_delta", deltas.get("suspicion_delta", 0)))
	var bankroll_delta := int(result.get("bankroll_delta", deltas.get("bankroll_delta", 0)))
	var watched := _skill_bool_value("pit_boss_watched", result, payload, story_context, false)
	var pit_boss_heat_bonus := _skill_int_value("pit_boss_heat_bonus", result, payload, story_context, 0)
	var pressure_checked_default := true
	var pressure_checked := _skill_bool_value("skill_security_pressure_checked", result, payload, story_context, pressure_checked_default)
	var skill_outcome := _skill_string_value("skill_outcome", result, payload, story_context, "")
	if skill_outcome.is_empty():
		skill_outcome = _default_skill_outcome(action_kind, bool(result.get("won", false)), suspicion_delta, bankroll_delta)
	var skill_grade := _skill_string_value("skill_grade", result, payload, story_context, "")
	if skill_grade.is_empty():
		skill_grade = _default_skill_grade(skill_outcome, action_kind, bool(result.get("won", false)), suspicion_delta, bankroll_delta)
	var skill_accuracy := clampi(_skill_int_value("skill_accuracy", result, payload, story_context, _default_skill_accuracy(skill_grade, action_kind, bool(result.get("won", false)), suspicion_delta, bankroll_delta)), 0, 100)
	var skill_margin_msec := maxi(0, _skill_int_value("skill_margin_msec", result, payload, story_context, 0))
	var base_suspicion_delta := _skill_int_value("base_suspicion_delta", result, payload, story_context, -1)
	if base_suspicion_delta < 0 and deltas.has("base_suspicion_delta"):
		base_suspicion_delta = int(deltas.get("base_suspicion_delta", -1))
	if base_suspicion_delta < 0:
		base_suspicion_delta = _skill_int_value("base_heat", result, payload, story_context, -1)
	if base_suspicion_delta < 0:
		base_suspicion_delta = _skill_int_value("tab_detector_base_heat", result, payload, story_context, -1)
	if base_suspicion_delta < 0:
		base_suspicion_delta = suspicion_delta
	base_suspicion_delta = maxi(0, base_suspicion_delta)
	var security_message := _skill_string_value("security_message", result, payload, story_context, "")
	var skill_context := _copy_dict(payload.get("skill_story_context", story_context.get("skill_story_context", {})))
	if skill_context.is_empty():
		skill_context = {
			"game_id": str(result.get("game_id", "")),
			"action_id": str(result.get("action_id", "")),
			"action_kind": action_kind,
			"environment_id": str(result.get("environment_id", "")),
		}
	skill_context["skill_outcome"] = skill_outcome
	skill_context["skill_grade"] = skill_grade
	skill_context["skill_accuracy"] = skill_accuracy
	skill_context["skill_margin_msec"] = skill_margin_msec
	skill_context["suspicion_delta"] = suspicion_delta
	skill_context["base_suspicion_delta"] = base_suspicion_delta
	skill_context["bankroll_delta"] = bankroll_delta
	skill_context["watched"] = watched
	skill_context["pit_boss_heat_bonus"] = pit_boss_heat_bonus
	skill_context["security_pressure_checked"] = pressure_checked

	result["skill_cheat_contract"] = true
	result["skill_outcome"] = skill_outcome
	result["skill_grade"] = skill_grade
	result["skill_accuracy"] = skill_accuracy
	result["skill_margin_msec"] = skill_margin_msec
	result["skill_watched"] = watched
	result["watched"] = watched
	result["pit_boss_watched"] = watched
	result["pit_boss_heat_bonus"] = pit_boss_heat_bonus
	result["skill_suspicion_delta"] = suspicion_delta
	result["base_suspicion_delta"] = base_suspicion_delta
	result["skill_payoff_delta"] = bankroll_delta
	result["skill_security_pressure_checked"] = pressure_checked
	result["skill_story_context"] = skill_context.duplicate(true)
	if not security_message.is_empty():
		result["security_message"] = security_message

	var normalized_story: Array = []
	for story_value in story_entries:
		if typeof(story_value) != TYPE_DICTIONARY:
			normalized_story.append(story_value)
			continue
		var entry: Dictionary = (story_value as Dictionary).duplicate(true)
		if _story_entry_matches_result(entry, result):
			entry["action_kind"] = str(entry.get("action_kind", action_kind))
			entry["skill_outcome"] = skill_outcome
			entry["skill_grade"] = skill_grade
			entry["skill_accuracy"] = skill_accuracy
			entry["skill_margin_msec"] = skill_margin_msec
			entry["suspicion_delta"] = suspicion_delta
			entry["base_suspicion_delta"] = base_suspicion_delta
			entry["bankroll_delta"] = bankroll_delta
			entry["skill_watched"] = watched
			entry["watched"] = watched
			entry["pit_boss_watched"] = watched
			entry["pit_boss_heat_bonus"] = pit_boss_heat_bonus
			entry["skill_security_pressure_checked"] = pressure_checked
			entry["skill_story_context"] = skill_context.duplicate(true)
			if not security_message.is_empty():
				entry["security_message"] = security_message
		normalized_story.append(entry)
	deltas["story_log"] = normalized_story
	result["deltas"] = deltas
	return result


# Keeps top-level and delta messages synchronized when a module decorates output.
static func set_result_message(result: Dictionary, message: String) -> Dictionary:
	var updated := result.duplicate(true)
	var deltas := _normalize_result_deltas(updated.get("deltas", {}))
	updated["message"] = message
	deltas["messages"] = [] if message.is_empty() else [message]
	updated["deltas"] = deltas
	updated["messages"] = _copy_array(deltas["messages"])
	return updated


static func patrons_with_talk_focus(patrons: Array, focused_speaker_value: Variant) -> Array:
	var focused_speaker := _copy_dict(focused_speaker_value)
	if focused_speaker.is_empty() or str(focused_speaker.get("role", "")) != "patron":
		return patrons.duplicate(true)
	var focused_index := int(focused_speaker.get("patron_index", -1))
	var focused_name := str(focused_speaker.get("name", "")).strip_edges()
	var result: Array = []
	for index in range(patrons.size()):
		var patron_value: Variant = patrons[index]
		if typeof(patron_value) != TYPE_DICTIONARY:
			result.append(patron_value)
			continue
		var patron: Dictionary = (patron_value as Dictionary).duplicate(true)
		var matches_index := focused_index >= 0 and index == focused_index
		var matches_name := not focused_name.is_empty() and str(patron.get("name", "")).strip_edges() == focused_name
		if matches_index or matches_name:
			patron["watching_player"] = true
			patron["tell_active"] = true
			if str(patron.get("behavior", "")).strip_edges().is_empty():
				patron["behavior"] = "speaking"
		result.append(patron)
	return result


# Applies structured module changes through RunState.
static func apply_result(run_state: RunState, result: Dictionary, rng: RngStream = null) -> void:
	if run_state == null:
		return
	if not bool(result.get("ok", false)):
		run_state.clear_deferred_bankroll_zero_resolution()
		return
	normalize_skill_cheat_contract(result)
	var deltas := _normalize_result_deltas(result.get("deltas", {}))
	run_state.record_score_spending_from_result(result, deltas)
	deltas = run_state.route_grand_casino_game_currency(result, deltas)
	var defer_bankroll_zero := bool(result.get("defer_bankroll_zero_failure", false)) or run_state.defer_next_bankroll_zero_failure
	if defer_bankroll_zero:
		result["defer_bankroll_zero_failure"] = true
	var bankroll_delta := int(deltas.get("bankroll_delta", 0))
	if bankroll_delta != 0:
		run_state.change_bankroll(bankroll_delta, defer_bankroll_zero)
	var chips_delta := int(deltas.get("chips_delta", 0))
	if chips_delta != 0:
		run_state.change_grand_casino_chips(chips_delta, defer_bankroll_zero)
	var suspicion_delta := int(deltas.get("suspicion_delta", 0))
	if suspicion_delta != 0:
		var suspicion_context := {
			"environment_id": result.get("environment_id", ""),
			"action_kind": str(result.get("action_kind", "")),
			"source_id": str(result.get("source_id", "")),
		}
		if result.has("environment_archetype_id"):
			suspicion_context["environment_archetype_id"] = result.get("environment_archetype_id", "")
		var applied_suspicion_delta := run_state.add_suspicion(
			"%s:%s" % [result.get("source_id", ""), result.get("action_id", "")],
			suspicion_delta,
			"behavior",
			false,
			suspicion_context,
			defer_bankroll_zero
		)
		if applied_suspicion_delta != suspicion_delta:
			deltas["base_suspicion_delta"] = suspicion_delta
			deltas["suspicion_delta"] = applied_suspicion_delta
			result["suspicion_delta"] = applied_suspicion_delta
			result["deltas"] = deltas
			normalize_skill_cheat_contract(result)
		if applied_suspicion_delta > 0 and run_state.suspicion_level() >= 100 and not run_state.handle_grand_casino_heat_reroute("game_result"):
			run_state.fail_run(RunState.FAILURE_POLICE_CAPTURE, RunState.POLICE_CAPTURE_FAILURE_MESSAGE)
	var alcohol_intake := int(deltas.get("alcohol_intake", 0))
	if alcohol_intake != 0:
		run_state.drink_alcohol(alcohol_intake)
	var pending_drunk_absorption_delta := int(deltas.get("pending_drunk_absorption_delta", 0))
	if pending_drunk_absorption_delta != 0:
		run_state.change_pending_drunk_absorption(pending_drunk_absorption_delta)
	var drunk_delta := int(deltas.get("drunk_delta", 0))
	if drunk_delta != 0:
		run_state.change_drunk(drunk_delta)
	var drunk_distortion_suppression_turns := int(deltas.get("drunk_distortion_suppression_turns", 0))
	if drunk_distortion_suppression_turns > 0:
		run_state.suppress_drunk_distortion(drunk_distortion_suppression_turns)
	var heat_cooldown_actions := int(deltas.get("heat_cooldown_actions", 0))
	var heat_cooldown_per_action := int(deltas.get("heat_cooldown_per_action", 0))
	if heat_cooldown_actions > 0 and heat_cooldown_per_action > 0:
		run_state.start_heat_cooldown(heat_cooldown_actions, heat_cooldown_per_action)
	var alcoholic_delta := int(deltas.get("alcoholic_delta", 0))
	if alcoholic_delta != 0:
		run_state.change_alcoholic(alcoholic_delta)
	var baseline_luck_delta := int(deltas.get("baseline_luck_delta", 0))
	if baseline_luck_delta != 0:
		run_state.change_baseline_luck(baseline_luck_delta)
	for debt_change in deltas.get("debt_changes", []):
		if typeof(debt_change) == TYPE_DICTIONARY:
			run_state.add_debt(debt_change)
	for item_id in deltas.get("inventory_add", []):
		run_state.add_item(str(item_id))
	for item_id in deltas.get("inventory_remove", []):
		run_state.remove_item(str(item_id))
	for bag_marker_value in deltas.get("pending_bags", []):
		if typeof(bag_marker_value) == TYPE_DICTIONARY:
			run_state.add_pending_bag_marker(bag_marker_value)
	var flags := _copy_dict(deltas.get("flags_set", {}))
	for key in flags.keys():
		run_state.narrative_flags[str(key)] = flags[key]
	var story_flags := _copy_dict(deltas.get("story_flags_set", {}))
	for key in story_flags.keys():
		run_state.set_story_flag(str(key), story_flags[key])
	var travel_hooks := _copy_array(deltas.get("travel_hooks_add", []))
	if not travel_hooks.is_empty():
		run_state.add_next_archetypes(travel_hooks)
	var travel_changes := _copy_dict(deltas.get("travel_changes", {}))
	if travel_changes.has("set_next_archetypes"):
		run_state.set_next_archetypes(_copy_array(travel_changes.get("set_next_archetypes", [])))
	if travel_changes.has("add_next_archetypes"):
		run_state.add_next_archetypes(_copy_array(travel_changes.get("add_next_archetypes", [])))
	for story_entry in deltas.get("story_log", []):
		if typeof(story_entry) == TYPE_DICTIONARY:
			run_state.log_story(story_entry)
	run_state.sync_grand_casino_entry_bankroll_after_travel_result(result)
	var demo_finale := _copy_dict(deltas.get("demo_finale", {}))
	if not demo_finale.is_empty():
		run_state.apply_demo_finale_result(demo_finale)
	run_state.record_profile_game_result(result)
	run_state.record_grand_casino_game_result(result)
	if bool(deltas.get("ended", false)) and bool(run_state.narrative_flags.get("demo_victory", false)):
		run_state.run_status = RESULT_ENDED
		run_state.run_failure_reason = RunState.FAILURE_NONE
		run_state.run_failure_message = ""
	else:
		run_state.evaluate_immediate_terminal_state(defer_bankroll_zero)
		if run_state.run_status != RunState.RUN_STATUS_FAILED:
			run_state.evaluate_environment_objective_state()
			if bool(run_state.narrative_flags.get("demo_victory", false)):
				deltas["ended"] = true
				result["deltas"] = deltas
				result["ended"] = true
				result["state"] = RESULT_ENDED
				var victory_message := run_state.current_demo_victory_message()
				var messages := _copy_array(deltas.get("messages", []))
				if not victory_message.is_empty() and not messages.has(victory_message):
					messages.append(victory_message)
					deltas["messages"] = messages
					result["deltas"] = deltas
					result["messages"] = messages
					result["message"] = "%s %s" % [str(result.get("message", "")).strip_edges(), victory_message]
					result["message"] = str(result.get("message", "")).strip_edges()
		if bool(deltas.get("ended", false)) and run_state.run_status != RunState.RUN_STATUS_FAILED:
			run_state.run_status = RESULT_ENDED
	if not demo_finale.is_empty() and run_state.is_terminal():
		deltas["ended"] = true
		result["deltas"] = deltas
		result["ended"] = true
		result["state"] = RESULT_ENDED
	if rng != null:
		run_state.save_rng(rng)
	run_state.clear_deferred_bankroll_zero_resolution()


# Resolves one action with data-driven odds and item modifiers.
#
# `payout_mult` is the gross casino payout, including the returned wager. A
# 2x payout therefore nets +1 stake on a win and -1 stake on a loss. This keeps
# the generic game contract aligned with slot and pull-tab modules, where the
# wager is always paid before any winnings are awarded.
func resolve(action_id: String, stake: int, run_state: RunState, environment: Dictionary, rng: RngStream) -> Dictionary:
	var action := _action(action_id)
	if action.is_empty():
		return _empty_result(action_id, stake, environment, "Action is not available.")

	var is_cheat := _is_cheat_action(action_id)
	var economic_profile: Dictionary = environment.get("economic_profile", {})
	var stake_floor := int(economic_profile.get("stake_floor", 1))
	var stake_ceiling := run_state.wager_stake_ceiling(stake_ceiling_for_game(environment, get_id(), run_state.bankroll))
	if stake_ceiling < stake_floor or stake_ceiling <= 0:
		return _empty_result(action_id, stake, environment, "Economy pressure leaves no valid stake.")
	var adjusted_stake := clampi(stake, stake_floor, stake_ceiling)
	adjusted_stake = mini(adjusted_stake, maxi(0, run_state.bankroll))
	if adjusted_stake <= 0:
		return _empty_result(action_id, stake, environment, "You do not have enough bankroll to act.")

	var luck_modifier := run_state.luck_win_chance_bonus()
	var chance := clampi(int(action.get("win_chance", 45)) + _item_bonus("win_chance", run_state, is_cheat) + luck_modifier, 5, 95)
	var won := rng.randi_range(1, 100) <= chance
	var payout := int(action.get("payout_mult", 2))
	var stake_cost := adjusted_stake
	var gross_payout := adjusted_stake * payout if won else 0
	var bankroll_delta := gross_payout - stake_cost
	var luck_payout_bonus := run_state.luck_payout_bonus(adjusted_stake, won)
	if won:
		bankroll_delta = maxi(1, bankroll_delta + luck_payout_bonus)
		bankroll_delta += _item_bonus("win_bonus", run_state, is_cheat)
	else:
		bankroll_delta = mini(0, bankroll_delta + _item_bonus("loss_reduction", run_state, is_cheat))

	var suspicion_delta := int(action.get("suspicion_delta", 0))
	var pit_boss_status := run_state.pit_boss_watch_status(environment) if is_cheat else {}
	var pit_boss_bonus := int(pit_boss_status.get("cheat_heat_bonus", 0)) if bool(pit_boss_status.get("active", false)) else 0
	if is_cheat:
		suspicion_delta = maxi(0, suspicion_delta + _item_bonus("cheat_suspicion_delta", run_state, true) + run_state.security_risk_bonus("cheat") + pit_boss_bonus)
	var security_summary := run_state.security_pressure_summary() if is_cheat and run_state.security_risk_bonus("cheat") > 0 else ""
	var pit_boss_summary := str(pit_boss_status.get("summary", "")) if bool(pit_boss_status.get("active", false)) else ""
	if is_cheat and not pit_boss_summary.is_empty():
		security_summary = "%s %s" % [security_summary, pit_boss_summary]
	var security_pressure := run_state.security_action_pressure("cheat", adjusted_stake, run_state.suspicion_level() + suspicion_delta) if is_cheat else {}
	var security_bankroll_delta := int(security_pressure.get("bankroll_delta", 0))
	var security_message := str(security_pressure.get("message", ""))
	if security_bankroll_delta != 0:
		bankroll_delta += security_bankroll_delta
	var message := _result_message(action, won, bankroll_delta, suspicion_delta, security_summary)
	if not security_message.is_empty():
		message = "%s %s" % [message, security_message]
	var story_entry := {
		"type": "game_action",
		"game_id": get_id(),
		"action_id": action_id,
		"won": won,
		"payout": gross_payout,
		"stake_cost": stake_cost,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"luck_modifier": luck_modifier,
		"luck_payout_bonus": luck_payout_bonus,
		"environment_id": environment.get("id", ""),
		"security_pressure": run_state.security_pressure_label() if is_cheat else "",
		"security_bankroll_delta": security_bankroll_delta,
		"security_message": security_message,
		"pit_boss_watched": bool(pit_boss_status.get("watched", false)),
		"pit_boss_heat_bonus": pit_boss_bonus,
		"pit_boss_summary": pit_boss_summary,
	}
	var deltas := empty_result_deltas()
	deltas["bankroll_delta"] = bankroll_delta
	deltas["suspicion_delta"] = suspicion_delta
	deltas["story_log"] = [story_entry]
	deltas["messages"] = [message]
	deltas["ended"] = bool(security_pressure.get("ended", false))
	var result := build_action_result({
		"ok": true,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": "cheat" if is_cheat else "legal",
		"stake": adjusted_stake,
		"bankroll_delta": bankroll_delta,
		"suspicion_delta": suspicion_delta,
		"deltas": deltas,
		"won": won,
		"environment_id": environment.get("id", ""),
		"message": message,
	})
	apply_result(run_state, result, rng)
	return result


# Returns a no-op result when an action cannot run.
func _empty_result(action_id: String, stake: int, environment: Dictionary, text: String) -> Dictionary:
	return build_action_result({
		"ok": false,
		"type": "game_action",
		"source_id": get_id(),
		"game_id": get_id(),
		"action_id": action_id,
		"action_kind": "unknown",
		"stake": stake,
		"won": false,
		"environment_id": environment.get("id", ""),
		"message": text,
	})


# Finds an action definition across legal and cheat actions.
func _action(action_id: String) -> Dictionary:
	for action in definition.get("legal_actions", []):
		if action.get("id", "") == action_id:
			return action.duplicate(true)
	for action in definition.get("cheat_actions", []):
		if action.get("id", "") == action_id:
			return action.duplicate(true)
	return {}


# Checks whether an action is a cheat or advantage action.
func _is_cheat_action(action_id: String) -> bool:
	for action in definition.get("cheat_actions", []):
		if action.get("id", "") == action_id:
			return true
	return false


# Sums matching item bonuses for this game context.
func _item_bonus(key: String, run_state: RunState, is_cheat: bool) -> int:
	if run_state == null or library == null:
		return 0
	if run_state.has_method("item_effect_total"):
		var action_kind := "cheat" if is_cheat else "legal"
		return int(run_state.item_effect_total(key, get_family(), action_kind))
	var total := 0
	for inventory_entry in run_state.inventory:
		var item_id := _inventory_item_id(inventory_entry)
		if item_id.is_empty():
			continue
		var item := library.item(item_id)
		if item.is_empty():
			continue
		var effect := _copy_dict(item.get("effect", {}))
		total += int(effect.get(key, 0))
		if is_cheat:
			total += int(effect.get("cheat_%s" % key, 0))
		else:
			total += int(effect.get("legal_%s" % key, 0))
		var families := _copy_dict(effect.get("families", {}))
		var family_effect := _copy_dict(families.get(get_family(), {}))
		total += int(family_effect.get(key, 0))
	return total


# Returns UI-ready item badges for skill-cheat modifiers on the current game.
func skill_item_modifier_badges(run_state: RunState, effect_keys: Array) -> Array:
	if run_state == null or library == null:
		return []
	var wanted := {}
	for key_value in effect_keys:
		var key := str(key_value).strip_edges()
		if not key.is_empty():
			wanted[key] = true
	if wanted.is_empty():
		return []
	var badges: Array = []
	for inventory_entry in run_state.inventory:
		var item_id := _inventory_item_id(inventory_entry).strip_edges()
		if item_id.is_empty():
			continue
		var item := library.item(item_id)
		if item.is_empty():
			continue
		var effect := _copy_dict(item.get("effect", {}))
		var modifiers := _skill_item_modifier_values(effect, wanted, get_family())
		if modifiers.is_empty():
			continue
		badges.append({
			"item_id": item_id,
			"label": str(item.get("display_name", item_id)),
			"icon_key": str(item.get("icon_key", item_id)),
			"item_class": str(item.get("class", "")),
			"modifiers": modifiers,
		})
	return badges


func _skill_item_modifier_values(effect: Dictionary, wanted: Dictionary, family_id: String) -> Dictionary:
	var values := {}
	_merge_skill_item_modifier_values(values, effect, wanted)
	var families := _copy_dict(effect.get("families", {}))
	var family_effect := _copy_dict(families.get(family_id, {}))
	_merge_skill_item_modifier_values(values, family_effect, wanted)
	return values


func _merge_skill_item_modifier_values(target: Dictionary, source: Dictionary, wanted: Dictionary) -> void:
	if source.is_empty():
		return
	for key_value in wanted.keys():
		var key := str(key_value)
		var value := _numeric_item_modifier_value(source.get(key, 0))
		if value == 0:
			continue
		target[key] = int(target.get(key, 0)) + value


func _numeric_item_modifier_value(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT:
		return int(round(float(value)))
	return 0


# Builds the player-facing result message.
func _result_message(action: Dictionary, won: bool, bankroll_delta: int, suspicion_delta: int, security_summary: String = "") -> String:
	var outcome := "won" if won else "lost"
	var suspicion_text := "" if suspicion_delta <= 0 else " Suspicion pressure rises."
	if not security_summary.is_empty():
		suspicion_text += " %s" % security_summary
	return "%s %s. Bankroll %+d.%s" % [
		action.get("label", action.get("id", "Action")),
		outcome,
		bankroll_delta,
		suspicion_text,
	]


# Returns an item id from the foundation string form or a future-safe dictionary.
func _inventory_item_id(entry: Variant) -> String:
	if typeof(entry) == TYPE_DICTIONARY:
		return str((entry as Dictionary).get("id", ""))
	return str(entry)


# Safely duplicates array content.
static func _copy_array(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	return (value as Array).duplicate(true)


# Safely duplicates dictionary content.
static func _copy_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)


static func _normalize_surface_animation_channels(value: Variant) -> Array:
	var entries: Array = []
	if typeof(value) == TYPE_DICTIONARY:
		var channels: Dictionary = value
		for key in channels.keys():
			var channel := _copy_dict(channels.get(key, {}))
			if channel.is_empty():
				continue
			if not channel.has("id"):
				channel["id"] = str(key)
			entries.append(channel)
	elif typeof(value) == TYPE_ARRAY:
		for entry in value:
			if typeof(entry) == TYPE_DICTIONARY:
				entries.append((entry as Dictionary).duplicate(true))

	var result: Array = []
	for entry in entries:
		var channel: Dictionary = entry
		var channel_id := str(channel.get("id", ""))
		if channel_id.is_empty():
			continue
		var active_id := str(channel.get("active_id", ""))
		var normalized := channel.duplicate(true)
		normalized["id"] = channel_id
		normalized["active_id"] = active_id
		normalized["started_msec"] = maxi(0, int(channel.get("started_msec", 0)))
		normalized["duration_msec"] = maxi(0, int(channel.get("duration_msec", 0)))
		normalized["active"] = bool(channel.get("active", not active_id.is_empty()))
		normalized["restart_on_active_id_change"] = bool(channel.get("restart_on_active_id_change", true))
		normalized["metadata"] = _copy_dict(channel.get("metadata", {}))
		result.append(normalized)
	return result


static func _matching_story_entry(story_entries: Array, result: Dictionary) -> Dictionary:
	for story_value in story_entries:
		if typeof(story_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = story_value
		if _story_entry_matches_result(entry, result):
			return entry
	for story_value in story_entries:
		if typeof(story_value) == TYPE_DICTIONARY:
			return story_value
	return {}


static func _story_entry_matches_result(entry: Dictionary, result: Dictionary) -> bool:
	var story_game_id := str(entry.get("game_id", ""))
	var result_game_id := str(result.get("game_id", ""))
	if not story_game_id.is_empty() and not result_game_id.is_empty() and story_game_id != result_game_id:
		return false
	var story_action_id := str(entry.get("action_id", ""))
	var result_action_id := str(result.get("action_id", ""))
	if not story_action_id.is_empty() and not result_action_id.is_empty() and story_action_id != result_action_id:
		return false
	return true


static func _skill_bool_value(base_key: String, result: Dictionary, payload: Dictionary, story: Dictionary, default_value: bool) -> bool:
	if payload.has(base_key):
		return bool(payload.get(base_key, default_value))
	if result.has(base_key):
		return bool(result.get(base_key, default_value))
	if story.has(base_key):
		return bool(story.get(base_key, default_value))
	var suffix := "_%s" % base_key
	for key in result.keys():
		if str(key).ends_with(suffix):
			return bool(result.get(key, default_value))
	for key in story.keys():
		if str(key).ends_with(suffix):
			return bool(story.get(key, default_value))
	return default_value


static func _skill_int_value(base_key: String, result: Dictionary, payload: Dictionary, story: Dictionary, default_value: int) -> int:
	if payload.has(base_key):
		return int(payload.get(base_key, default_value))
	if result.has(base_key):
		return int(result.get(base_key, default_value))
	if story.has(base_key):
		return int(story.get(base_key, default_value))
	var suffix := "_%s" % base_key
	for key in result.keys():
		if str(key).ends_with(suffix):
			return int(result.get(key, default_value))
	for key in story.keys():
		if str(key).ends_with(suffix):
			return int(story.get(key, default_value))
	return default_value


static func _skill_string_value(base_key: String, result: Dictionary, payload: Dictionary, story: Dictionary, default_value: String) -> String:
	if payload.has(base_key):
		return str(payload.get(base_key, default_value))
	if result.has(base_key):
		return str(result.get(base_key, default_value))
	if story.has(base_key):
		return str(story.get(base_key, default_value))
	var suffix := "_%s" % base_key
	for key in result.keys():
		if str(key).ends_with(suffix):
			return str(result.get(key, default_value))
	for key in story.keys():
		if str(key).ends_with(suffix):
			return str(story.get(key, default_value))
	return default_value


static func _default_skill_outcome(action_kind: String, won: bool, suspicion_delta: int, bankroll_delta: int) -> String:
	if action_kind == "advantage":
		return "edge_found"
	if action_kind == "risky":
		return "risk_taken"
	if won or bankroll_delta > 0:
		return "cheat_paid"
	if suspicion_delta > 0:
		return "heat_taken"
	return "cheat_resolved"


static func _default_skill_grade(skill_outcome: String, action_kind: String, won: bool, suspicion_delta: int, bankroll_delta: int) -> String:
	var outcome := skill_outcome.to_lower()
	if outcome.find("perfect") >= 0:
		return "perfect"
	if outcome.find("good") >= 0:
		return "good"
	if outcome.find("partial") >= 0 or outcome.find("close") >= 0:
		return "partial"
	if outcome.find("blown") >= 0 or outcome.find("caught") >= 0:
		return "blown"
	if outcome.find("miss") >= 0:
		return "miss"
	if action_kind == "advantage":
		return "edge"
	if action_kind == "risky":
		return "risk"
	if won or bankroll_delta > 0:
		return "success"
	if suspicion_delta > 0:
		return "heat"
	return "resolved"


static func _default_skill_accuracy(skill_grade: String, action_kind: String, won: bool, suspicion_delta: int, bankroll_delta: int) -> int:
	match skill_grade:
		"perfect":
			return 100
		"good", "success", "edge":
			return 75
		"partial", "close", "risk":
			return 50
		"miss", "blown", "clean_miss":
			return 0
	if won or bankroll_delta > 0:
		return 75
	if action_kind == "advantage":
		return 75
	if suspicion_delta > 0:
		return 25
	return 50


# Normalizes legacy or partial result-delta dictionaries into the shared shape.
static func _normalize_result_deltas(value: Variant) -> Dictionary:
	var source := _copy_dict(value)
	if source.has("bankroll") and not source.has("bankroll_delta"):
		source["bankroll_delta"] = source["bankroll"]
	if source.has("suspicion") and not source.has("suspicion_delta"):
		source["suspicion_delta"] = source["suspicion"]
	if source.has("alcohol") and not source.has("alcohol_intake"):
		source["alcohol_intake"] = source["alcohol"]
	if source.has("drunk") and not source.has("drunk_delta"):
		source["drunk_delta"] = source["drunk"]
	if source.has("alcoholic") and not source.has("alcoholic_delta"):
		source["alcoholic_delta"] = source["alcoholic"]
	if source.has("luck") and not source.has("baseline_luck_delta"):
		source["baseline_luck_delta"] = source["luck"]
	if source.has("flags") and not source.has("flags_set"):
		source["flags_set"] = source["flags"]
	if source.has("add_next_archetypes") or source.has("set_next_archetypes"):
		var travel_changes := _copy_dict(source.get("travel_changes", {}))
		if source.has("add_next_archetypes") and not travel_changes.has("add_next_archetypes"):
			travel_changes["add_next_archetypes"] = _copy_array(source.get("add_next_archetypes", []))
		if source.has("set_next_archetypes") and not travel_changes.has("set_next_archetypes"):
			travel_changes["set_next_archetypes"] = _copy_array(source.get("set_next_archetypes", []))
		source["travel_changes"] = travel_changes

	var result := empty_result_deltas()
	for key in result.keys():
		if not source.has(key):
			continue
		if key == "bankroll_delta" or key == "chips_delta" or key == "suspicion_delta" or key == "alcohol_intake" or key == "drunk_delta" or key == "pending_drunk_absorption_delta" or key == "drunk_distortion_suppression_turns" or key == "heat_cooldown_actions" or key == "heat_cooldown_per_action" or key == "alcoholic_delta" or key == "baseline_luck_delta":
			result[key] = int(source[key])
		elif key == "ended":
			result[key] = bool(source[key])
		elif key == "flags_set" or key == "story_flags_set" or key == "travel_changes" or key == "demo_finale":
			result[key] = _copy_dict(source[key])
		else:
			result[key] = _copy_array(source[key])
	return result
