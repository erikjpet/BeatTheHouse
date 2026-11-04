class_name SlotBonusRecovery
extends RefCounted

# Read-only compatibility projection. A repaired view owns only its two changed
# dictionaries; it never writes a save, advances physics, or consumes an RNG.
const PinballFeatureScript := preload("res://scripts/games/slots/pinball/pinball_feature.gd")

const PINBALL_BOARDS := {
	"em_bumper_drop": "bumper_alley",
	"lane_multiball": "lock_cascade",
	"video_feature": "jackpot_works",
}
const BUFFALO_MODES := ["free_games", "hold_and_spin", "wheel"]
const BUFFALO_WHEEL_ROUTES := ["free_games", "hold_and_spin", "jackpot_boost"]
const PROGRESS_INTEGERS := ["remaining_steps", "total_steps", "step_index", "pending_award", "feature_total", "awarded"]


static func machine_view(machine: Dictionary, definition: Dictionary) -> Dictionary:
	var active_value: Variant = machine.get("active_bonus", null)
	if typeof(active_value) != TYPE_DICTIONARY:
		return machine
	var active: Dictionary = active_value as Dictionary
	if not _incomplete(active):
		return machine
	var family := _admitted_family(machine, active, definition)
	if family.is_empty() or str(active.get("family", "")) == family:
		return machine
	var owned_active := active.duplicate(false)
	owned_active["family"] = family
	var owned_machine := machine.duplicate(false)
	owned_machine["active_bonus"] = owned_active
	return owned_machine


static func recovery_required(machine: Dictionary, definition: Dictionary) -> bool:
	var active_value: Variant = machine.get("active_bonus", null)
	if typeof(active_value) != TYPE_DICTIONARY:
		return false
	var active: Dictionary = active_value as Dictionary
	# Visual replay is a transient presentation projection, never an authored
	# active machine state. Keep contradictory terminal/visual state intact and
	# noninteractive rather than letting it masquerade as another bonus family.
	if bool(active.get("visual_replay", false)) or (bool(active.get("active", false)) and bool(active.get("complete", false))):
		return true
	return _incomplete(active) and _admitted_family(machine, active, definition).is_empty()


static func recovery_message() -> String:
	return "This saved feature needs recovery. Its progress and awards are preserved."


static func _incomplete(active: Dictionary) -> bool:
	return bool(active.get("active", false)) and not bool(active.get("complete", false))


static func _admitted_family(machine: Dictionary, active: Dictionary, definition: Dictionary) -> String:
	var recorded_family := str(active.get("family", ""))
	var mode_family := _mode_family(str(active.get("mode", "")))
	if not recorded_family.is_empty():
		# Preserve the canonical scalar/save API and per-frame fast path. Strict
		# tag-loss authority checks below do not redefine an explicit valid tag.
		if recorded_family != mode_family:
			return ""
		if machine.has("type_id") and str(machine["type_id"]) != recorded_family:
			return ""
		return recorded_family
	# Inspect recorded input before any State.normalize call can invent defaults.
	var family := str(machine.get("type_id", ""))
	var format_id := str(machine.get("format_id", ""))
	if family.is_empty() or family != mode_family \
			or not _declared_id(definition.get("slot_types", null), family) \
			or not _declared_id(definition.get("slot_formats", null), format_id):
		return ""
	if not _recorded_progress(active):
		return ""
	if family == "pinball":
		return family if _pinball_authority(active) else ""
	if family == "buffalo":
		return family if _buffalo_authority(machine, active) else ""
	return ""


static func _mode_family(mode: String) -> String:
	if PINBALL_BOARDS.has(mode):
		return "pinball"
	if BUFFALO_MODES.has(mode):
		return "buffalo"
	return ""


static func _declared_id(value: Variant, identifier: String) -> bool:
	if identifier.is_empty() or typeof(value) != TYPE_ARRAY:
		return false
	for entry in value as Array:
		if typeof(entry) == TYPE_DICTIONARY and str((entry as Dictionary).get("id", "")) == identifier:
			return true
	return false


static func _recorded_progress(active: Dictionary) -> bool:
	for key in PROGRESS_INTEGERS:
		if not _recorded_integer(active, key, 0):
			return false
	return int(active["total_steps"]) > 0


static func _pinball_authority(active: Dictionary) -> bool:
	var mode := str(active.get("mode", ""))
	if str(active.get("board_id", "")) != str(PINBALL_BOARDS.get(mode, "")) \
			or typeof(active.get("runtime_session_id", null)) != TYPE_STRING \
			or str(active.get("runtime_session_id", "")).is_empty() \
			or not _recorded_integer(active, "runtime_seed", 1) \
			or int(active["runtime_seed"]) > 2140000000 \
			or not _recorded_integer(active, "session_cap", 1) \
			or typeof(active.get("pinball_item_effects", null)) != TYPE_DICTIONARY \
			or not _recorded_integer(active, "balls_remaining", 0) \
			or int(active["balls_remaining"]) > int(active["total_steps"]):
		return false
	if active.has(PinballFeatureScript.DURABLE_RUNTIME_KEY):
		# A present but invalid capsule cannot silently fall back to fresh physics.
		return _durable_pinball_authority(active)
	# Accepted actions erase stale durable capsules while their exact live
	# runtime remains authoritative. live_status only observes that cache.
	if bool(PinballFeatureScript.live_status(active).get("runtime_active", false)):
		return true
	# Keep the existing cold scalar-progress path for recorded between-launch
	# state. Missing no-live markers are not evidence of an empty playfield.
	return typeof(active.get("launch_in_progress", null)) == TYPE_BOOL \
		and not bool(active["launch_in_progress"]) \
		and _recorded_integer(active, "active_ball_count", 0) \
		and int(active["active_ball_count"]) == 0 \
		and int(active["remaining_steps"]) == int(active["balls_remaining"])


static func _durable_pinball_authority(active: Dictionary) -> bool:
	var durable_value: Variant = active.get(PinballFeatureScript.DURABLE_RUNTIME_KEY, null)
	if typeof(durable_value) != TYPE_DICTIONARY:
		return false
	return PinballFeatureScript.complete_durable_runtime_checkpoint_valid(active, durable_value as Dictionary)


static func _buffalo_authority(machine: Dictionary, active: Dictionary) -> bool:
	if not _recorded_integer(active, "stake", 1) \
			or not _recorded_integer(active, "session_cap", 1) \
			or typeof(active.get("bet_id", null)) != TYPE_STRING \
			or str(active.get("bet_id", "")).is_empty() \
			or not _dictionary_array(active.get("history", null)):
		return false
	match str(active["mode"]):
		"wheel":
			if not _dictionary_array(active.get("choices", null)) \
					or (active["choices"] as Array).is_empty() \
					or not _recorded_integer(active, "wheel_angle", 0):
				return false
			for choice in active["choices"]:
				if str(choice.get("id", "")).is_empty() \
						or not BUFFALO_WHEEL_ROUTES.has(str(choice.get("route", ""))):
					return false
			return true
		"hold_and_spin":
			if not _recorded_integer(active, "max_cells", 1) \
					or not _dictionary_array(active.get("locks", null)):
				return false
			if active.has("respins_remaining") and not _recorded_integer(active, "respins_remaining", 0):
				return false
			var rows_value: Variant = active.get("row_count", machine.get("row_count", null))
			if not _integer_number(rows_value) or int(rows_value) <= 0:
				return false
			var occupied: Dictionary = {}
			for lock in active["locks"]:
				if not _recorded_integer(lock, "cell", 0) or int(lock["cell"]) >= int(active["max_cells"]) \
						or not _recorded_integer(lock, "value", 0) or occupied.has(int(lock["cell"])):
					return false
				occupied[int(lock["cell"])] = true
				if lock.has("reel") and (not _recorded_integer(lock, "reel", 0) or int(lock["reel"]) != int(int(lock["cell"]) / int(rows_value))):
					return false
				if lock.has("row") and (not _recorded_integer(lock, "row", 0) or int(lock["row"]) != int(lock["cell"]) % int(rows_value)):
					return false
			return true
		"free_games":
			if not _dictionary_array(active.get("collected_coins", null)):
				return false
			for key in ["coins_collected", "coins_since_retrigger", "coin_total"]:
				if not _recorded_integer(active, key, 0):
					return false
			if active.has("spin_win_total") and not _recorded_integer(active, "spin_win_total", 0):
				return false
			for coin in active["collected_coins"]:
				if not _recorded_integer(coin, "reel", 0) or not _recorded_integer(coin, "row", 0) or not _recorded_integer(coin, "value", 0):
					return false
			return true
	return false


static func _dictionary_array(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	for entry in value as Array:
		if typeof(entry) != TYPE_DICTIONARY:
			return false
	return true


static func _recorded_integer(value: Dictionary, key: String, minimum: int) -> bool:
	return value.has(key) and _integer_number(value[key]) and int(value[key]) >= minimum


static func _integer_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(float(value)) and float(value) == floor(float(value))


