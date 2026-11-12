extends SceneTree

const Host := preload("res://scripts/ui/foundation_main.gd")
var _checks := 0
var _failures := 0
var _seed_arg_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(passed: bool, message: String) -> void:
	_checks += 1
	if not passed:
		_failures += 1
		push_error(message)


# Exercise the old two-argument function as well, so the before run reports
# the calendar collision rather than failing at an incompatible call.
func _seed_for(host: Node, day: int, month: int, year: int) -> String:
	var args: Array = [day, month]
	if _seed_arg_count == 3:
		args.append(year)
	return str(host.callv("_daily_challenge_seed_for_date", args))


func _run() -> void:
	var host := Host.new()
	for method in host.get_method_list():
		if str(method.get("name", "")) == "_daily_challenge_seed_for_date":
			_seed_arg_count = method.get("args", []).size()
	_check(_seed_arg_count == 3, "Daily seed must receive the full local date, including year.")
	var seed := _seed_for(host, 12, 11, 2026)
	_check(seed == _seed_for(host, 12, 11, 2026), "The same local date changed its daily seed.")
	_check(seed != _seed_for(host, 12, 11, 2027), "The same calendar date repeated across years.")
	_check(seed != _seed_for(host, 13, 11, 2026), "Consecutive local days repeated a seed.")
	_check(_seed_for(host, 31, 12, 2026) != _seed_for(host, 1, 1, 2027), "The local year boundary repeated a seed.")
	_check(_seed_for(host, 28, 2, 2028) != _seed_for(host, 29, 2, 2028), "Leap day repeated the preceding seed.")
	_check(_seed_for(host, 29, 2, 2028) != _seed_for(host, 1, 3, 2028), "The day after leap day repeated a seed.")
	_check(seed.length() == 12 and seed.is_valid_hex_number(false), "Daily seed must be a short opaque hexadecimal hash.")
	_check(seed == "BTH-DAILY|2026-11-12".sha256_text().left(12), "Daily seed did not hash the full local date with its domain.")
	_check(not seed.contains("2026") and not seed.contains("11-12") and not seed.contains("12/11"), "Daily seed exposed its date as plain text.")

	var before_midnight := {"year": 2026, "month": 11, "day": 12, "hour": 23, "minute": 59, "second": 59}
	var same_day := before_midnight.duplicate()
	same_day["hour"] = 0
	var after_midnight := {"year": 2026, "month": 11, "day": 13, "hour": 0, "minute": 0, "second": 0}
	var day_id := str(host.call("_daily_challenge_id_for_datetime", before_midnight))
	_check(day_id == "2026-11-12", "Daily streak identifier format changed.")
	_check(day_id == str(host.call("_daily_challenge_id_for_datetime", same_day)), "Clock time changed the local daily identifier.")
	_check(str(host.call("_daily_challenge_id_for_datetime", after_midnight)) == "2026-11-13", "Local midnight did not advance the identifier.")

	# A legacy daily run is restored from its saved values, never re-seeded by
	# today's formula. No save or complete run-state data is written or logged.
	var legacy_seed := "384/22"
	var run := RunState.new()
	run.start_new(legacy_seed, RunState.daily_challenge(day_id, legacy_seed, true))
	var restored := RunState.new()
	restored.from_dict(run.to_dict())
	_check(restored.seed_text == legacy_seed, "Continue changed an in-progress legacy Daily seed.")
	_check(str(restored.challenge_config.get("seed_text", "")) == legacy_seed, "Continue changed the saved Daily challenge seed.")
	_check(str(restored.challenge_config.get("daily_id", "")) == day_id, "Continue changed the saved Daily date.")
	_check(restored.seed_is_hidden(), "Continue exposed the Daily seed.")
	_check(restored.rng_state == run.rng_state and restored.rng_seed == run.rng_seed, "Continue reset the in-progress Daily RNG.")
	host.free()
	print("Daily local-date seed checks: %d passed / %d failed (%d total)." % [_checks - _failures, _failures, _checks])
	quit(1 if _failures else 0)
