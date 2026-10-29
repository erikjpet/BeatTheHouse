extends SceneTree
const Hours := preload("res://scripts/core/environment_hours.gd")
const GeneratorScript := preload("res://scripts/core/run_generator.gd")
const Host := preload("res://scripts/ui/foundation_main.gd")
var checks := 0
var failures: Array = []
func _initialize() -> void:
	for definition in [{}, {"open_hours": null}, {"open_hours": {"open_minute": 0, "close_minute": 0}}]:
		var before := Hours.scenario_cycle_status(definition, 149)
		_check(before.active and before.closes_at == 150, "24h02:29 old cycle")
		for minute in [150, 151, 180, 239]:
			var gap := Hours.scenario_cycle_status(definition, minute)
			_check(not gap.active and gap.cycle_id == before.cycle_id, "24h exact dead zone%d" % minute)
		var after := Hours.scenario_cycle_status(definition, 240)
		_check(after.active and after.opened_at == 240 and after.cycle_id != before.cycle_id, "24h04:00 new cycle")
		_check(Hours.scenario_cycle_status(definition, 1440).cycle_id == after.cycle_id, "24h midnight retains cycle")
		_check(not Hours.scenario_cycle_status(definition, 1590).active, "24h following02:30 closed")
		_check(Hours.scenario_cycle_status(definition, 6000).opened_at == 6000, "24h multiple skipped cycles current only")
	var bar := {"open_hours": {"open_minute": 660, "close_minute": 180}}
	for pair in [[179, true], [180, false], [659, false], [660, true], [1439, true], [1440, true], [1620, false]]:
		_check(Hours.scenario_cycle_status(bar, pair[0]).active == pair[1], "overnight normal boundary%d" % pair[0])
	_check(Hours.scenario_cycle_status(bar, 1439).cycle_id == Hours.scenario_cycle_status(bar, 1440).cycle_id, "overnight cycle retains midnight")
	var pawn := {"open_hours": {"open_minute": 540, "close_minute": 1260}}
	for pair in [[539, false], [540, true], [1259, true], [1260, false], [1980, true]]:
		_check(Hours.scenario_cycle_status(pawn, pair[0]).active == pair[1], "day venue boundary%d" % pair[0])
	_check(Hours.environment_open_at({}, 180), "dead zone does not close24h access")
	_check(Hours.environment_open_at(bar, 179) and not Hours.environment_open_at(bar, 180), "authored access rules unchanged")
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "  ")); file.close()
	print("VENUE_CYCLE_SCHEDULE checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
