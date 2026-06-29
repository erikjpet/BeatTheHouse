class_name PlatformServices
extends RefCounted

# Local no-op adapter for future platform integrations.
# Core gameplay should depend on returned payloads, not platform SDK branches.

var service_name: String = "local"


# Configures the local service label for tests or later adapters.
func setup(p_service_name: String = "local") -> void:
	service_name = p_service_name if not p_service_name.is_empty() else "local"


# Reports local platform availability.
func initialize() -> Dictionary:
	return _local_payload({
		"ok": true,
		"available": true,
	})


# Accepts a score submission without sending it anywhere.
func submit_score(board_id: String, seed_text: String, score: int) -> Dictionary:
	return _local_payload({
		"ok": true,
		"board_id": board_id,
		"seed_text": seed_text,
		"score": score,
		"submitted": false,
	})


# Builds a stable local daily run payload without consulting a platform SDK.
func get_daily_run_id(date_id: String) -> Dictionary:
	var resolved_date_id := date_id if not date_id.is_empty() else "local"
	var daily_id := "daily:%s" % resolved_date_id
	return _local_payload({
		"ok": true,
		"date_id": resolved_date_id,
		"daily_id": daily_id,
		"challenge_config": RunState.daily_challenge(daily_id),
	})


# Accepts a daily score submission without sending it anywhere.
func submit_daily_score(daily_id: String, score: int, challenge_config: Dictionary) -> Dictionary:
	return _local_payload({
		"ok": true,
		"daily_id": daily_id,
		"score": score,
		"challenge_id": challenge_config.get("id", "daily"),
		"challenge_config": challenge_config.duplicate(true),
		"submitted": false,
	})


# Pretends to save cloud run data for future adapter parity.
func save_cloud_run(slot_id: String, run_data: Dictionary) -> Dictionary:
	return _local_payload({
		"ok": true,
		"slot_id": slot_id,
		"bytes": JSON.stringify(run_data).length(),
		"run_data": run_data.duplicate(true),
		"saved": false,
	})


# Reports that no local cloud save exists.
func load_cloud_run(slot_id: String) -> Dictionary:
	return _local_payload({
		"ok": false,
		"slot_id": slot_id,
		"run_data": {},
		"loaded": false,
	})


# Accepts an achievement unlock without sending it anywhere.
func unlock_achievement(achievement_id: String) -> Dictionary:
	return _local_payload({
		"ok": true,
		"achievement_id": achievement_id,
		"unlocked": false,
	})


func _local_payload(payload: Dictionary) -> Dictionary:
	var result := payload.duplicate(true)
	result["service"] = service_name
	result["mode"] = "local_noop"
	return result
