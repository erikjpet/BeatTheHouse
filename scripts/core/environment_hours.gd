class_name EnvironmentHours
extends RefCounted

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
			"opens_at": _clock_label(open_minute),
			"closes_at": _clock_label(close_minute),
			"minutes_until_open": 0,
			"minutes_until_close": until_close,
		}
	var until_open := _minutes_forward(minute, open_minute)
	var opens_at := _clock_label(open_minute)
	return {
		"open": false,
		"always_open": false,
		"closing_soon": false,
		"label": "Closed",
		"disabled_reason": "Closed. Opens at %s." % opens_at,
		"opens_at": opens_at,
		"closes_at": _clock_label(close_minute),
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


static func _clock_label(minute_of_day: int) -> String:
	var minute := _normalize_minute(minute_of_day)
	var hour_24 := int(floor(float(minute) / 60.0)) % 24
	var hour_12 := hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	var suffix := "AM" if hour_24 < 12 else "PM"
	return "%d %s" % [hour_12, suffix]
