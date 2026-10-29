class_name EnvironmentHours
extends RefCounted

const PlayerTextScript := preload("res://scripts/ui/player_text.gd")

# Pure venue-hours helpers. All callers pass deterministic clock minutes.

const MINUTES_PER_DAY := 1440
const CLOSING_SOON_MINUTES := 60


static func environment_open_at(archetype: Dictionary, minute_of_day: int) -> bool:
	var hours := _hours_dict(archetype.get("open_hours", null))
	if hours.is_empty():
		return true
	var open_minute := _normalize_minute(int(hours.get("open_minute", 0)))
	var close_minute := _normalize_minute(int(hours.get("close_minute", open_minute)))
	if open_minute == close_minute:
		return true
	var minute := _normalize_minute(minute_of_day)
	if close_minute > open_minute:
		return minute >= open_minute and minute < close_minute
	return minute >= open_minute or minute < close_minute


static func status_at(archetype: Dictionary, minute_of_day: int) -> Dictionary:
	var hours := _hours_dict(archetype.get("open_hours", null))
	var minute := _normalize_minute(minute_of_day)
	if hours.is_empty():
		return {
			"open": true,
			"always_open": true,
			"closing_soon": false,
			"label": "Open 24h",
			"disabled_reason": "",
			"opens_at": "",
			"closes_at": "",
			"minutes_until_open": 0,
			"minutes_until_close": MINUTES_PER_DAY,
		}
	var open_minute := _normalize_minute(int(hours.get("open_minute", 0)))
	var close_minute := _normalize_minute(int(hours.get("close_minute", open_minute)))
	if open_minute == close_minute:
		return status_at({}, minute)
	var is_open := environment_open_at(archetype, minute)
	if is_open:
		var until_close := _minutes_forward(minute, close_minute)
		var soon := until_close <= CLOSING_SOON_MINUTES
		return {
			"open": true,
			"always_open": false,
			"closing_soon": soon,
			"label": "Closing soon" if soon else "Open",
			"disabled_reason": "",
			"opens_at": PlayerTextScript.format_time_of_day(open_minute),
			"closes_at": PlayerTextScript.format_time_of_day(close_minute),
			"minutes_until_open": 0,
			"minutes_until_close": until_close,
		}
	var until_open := _minutes_forward(minute, open_minute)
	var opens_at := PlayerTextScript.format_time_of_day(open_minute)
	return {
		"open": false,
		"always_open": false,
		"closing_soon": false,
		"label": "Closed",
		"disabled_reason": "Closed. Opens at %s." % opens_at,
		"opens_at": opens_at,
		"closes_at": PlayerTextScript.format_time_of_day(close_minute),
		"minutes_until_open": until_open,
		"minutes_until_close": 0,
	}


static func travel_status_text(archetype: Dictionary, minute_of_day: int) -> String:
	var status := status_at(archetype, minute_of_day)
	if bool(status.get("always_open", false)):
		return "Open 24h"
	if bool(status.get("open", false)):
		if bool(status.get("closing_soon", false)):
			return "Closing soon: %s" % str(status.get("closes_at", ""))
		return "Open until %s" % str(status.get("closes_at", ""))
	return str(status.get("disabled_reason", "Closed."))


# Identifies the venue opening whose active session contains this absolute game
# minute. Same-session revisits share an id; crossing a real close/reopen boundary
# changes it. Always-open environments rotate with the game day.
static func operating_cycle_id(archetype: Dictionary, absolute_minutes: int) -> String:
	var safe_minutes := maxi(0, absolute_minutes)
	var day_index := int(floor(float(safe_minutes) / float(MINUTES_PER_DAY)))
	var minute := _normalize_minute(safe_minutes)
	var hours := _hours_dict(archetype.get("open_hours", null))
	if hours.is_empty():
		return "day:%d" % day_index
	var open_minute := _normalize_minute(int(hours.get("open_minute", 0)))
	var close_minute := _normalize_minute(int(hours.get("close_minute", open_minute)))
	if open_minute == close_minute:
		return "day:%d" % day_index
	# An after-midnight portion of an overnight schedule belongs to the opening
	# that began on the previous day.
	var opening_day := day_index - 1 if close_minute < open_minute and minute < close_minute else day_index
	return "open:%d:%d" % [opening_day, open_minute]


# Scenario lifetime is independent of access/closing grace and game-command
# night contexts. A24h venue has no scenario from02:30 through03:59.
static func scenario_cycle_status(archetype: Dictionary, absolute_minutes: int) -> Dictionary:
	var now := maxi(0, absolute_minutes)
	var hours := _hours_dict(archetype.get("open_hours", null))
	var always_open := hours.is_empty() or int(hours.get("open_minute", 0)) == int(hours.get("close_minute", 0))
	var opening := 240 if always_open else _normalize_minute(int(hours.get("open_minute", 0)))
	var closing := 150 if always_open else _normalize_minute(int(hours.get("close_minute", 0)))
	var opening_day := int(floor(float(now - opening) / float(MINUTES_PER_DAY)))
	var opened_at := opening_day * MINUTES_PER_DAY + opening
	var duration := (closing - opening + MINUTES_PER_DAY) % MINUTES_PER_DAY
	var closes_at := opened_at + duration
	return {"schema": "bth.venue_scenario_cycle/v1", "cycle_id": "venue:v1:%d" % opened_at,
		"active": now < closes_at, "always_open": always_open, "opened_at": opened_at,
		"closes_at": closes_at, "next_open_at": opened_at + MINUTES_PER_DAY}


static func _hours_dict(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var hours: Dictionary = value
	if not hours.has("open_minute") or not hours.has("close_minute"):
		return {}
	return hours


static func _normalize_minute(value: int) -> int:
	var minute := value % MINUTES_PER_DAY
	if minute < 0:
		minute += MINUTES_PER_DAY
	return minute


static func _minutes_forward(from_minute: int, to_minute: int) -> int:
	var from_value := _normalize_minute(from_minute)
	var to_value := _normalize_minute(to_minute)
	if to_value >= from_value:
		return to_value - from_value
	return MINUTES_PER_DAY - from_value + to_value
