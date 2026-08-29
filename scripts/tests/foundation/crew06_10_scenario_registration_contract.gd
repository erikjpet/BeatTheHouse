extends SceneTree

const CatalogScript := preload("res://scripts/core/scenario_sequence_catalog.gd")
const GameScript := preload("res://scripts/games/crew_draw_poker.gd")

const EXPECTED := {
	"punchline_open_mic_night": "friendly_teaching",
	"punchline_high_stakes_night": "hustle_test",
	"punchline_greased_week": "after_job",
	"punchline_debt_court": "debt_court",
	"punchline_raid_jitters": "raid_jitters",
}


func _init() -> void:
	var failures: Array[String] = []
	var catalog := CatalogScript.load_catalog()
	if not bool(catalog.get("ok", false)):
		failures.append("scenario catalog rejected poker-night registrations: %s" % JSON.stringify(catalog.get("failures", [])))
	else:
		var game := GameScript.new()
		for scenario_id in EXPECTED:
			var overlay := CatalogScript.overlay_for(scenario_id, catalog)
			var authoring: Dictionary = overlay.get("authoring", {}) if typeof(overlay.get("authoring", {})) == TYPE_DICTIONARY else {}
			if str(authoring.get("crew_poker_turn_engine", "")) != "ordered_v1":
				failures.append("%s does not opt into ordered_v1" % scenario_id)
			if str(authoring.get("crew_poker_night_id", "")) != str(EXPECTED[scenario_id]):
				failures.append("%s does not select %s" % [scenario_id, EXPECTED[scenario_id]])
			var environment := {"sequence_authoring": authoring}
			if not bool(game.call("_ordered_engine", environment)) or str(game.call("_night_id", environment)) != str(EXPECTED[scenario_id]):
				failures.append("%s metadata is not consumed by the production game" % scenario_id)
	if failures.is_empty():
		print("CREW06_10_SCENARIO_REGISTRATION PASS scenarios=5 engine=ordered_v1")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
