extends SceneTree

# Focused real-loader regression. Run only with ordinary QA storage/guard admission.
# This does not start a campaign, open a browser, or read/write a save.
const LibraryScript := preload("res://scripts/core/content_library.gd")
const GROUPS_PATH := "res://data/content_groups/groups.json"

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	var expected_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(GROUPS_PATH))
	if typeof(expected_value) != TYPE_ARRAY:
		push_error("Content-group fixture must be an array.")
		quit(1)
		return
	var expected_groups: Array = expected_value
	var expected_defaults: Array = []
	for value in expected_groups:
		var group: Dictionary = value
		if bool(group.get("default_enabled", true)):
			expected_defaults.append(str(group.get("id", "")))

	var library := LibraryScript.new()
	var cold: Dictionary = library.load_start_menu()
	_expect(library.content_groups == expected_groups, "Cold loader exposes the authored group catalog.")
	_expect(cold.get("content_groups", []) == expected_groups, "Cold return projection includes the group catalog.")
	_expect(library.default_content_group_ids() == expected_defaults, "Cold defaults retain authored order and values.")
	_expect(library.content_group_options(expected_defaults).size() == expected_groups.size(), "Cold drawer can build every pack option.")
	_expect(library.normalize_content_group_ids(["video_poker_pack"]) == ["video_poker_pack"], "A cold explicit Video Poker selection survives normalization.")
	_expect(not library.is_fully_loaded(), "Menu metadata does not claim a full load.")
	_expect(not library.validation_complete, "Full validation remains deferred.")
	_expect(library.games.is_empty(), "Cold menu leaves games unloaded.")
	_expect(library.items.is_empty(), "Cold menu leaves items unloaded.")
	_expect(library.events.is_empty(), "Cold menu leaves events unloaded.")
	_expect(library.environment_scenarios.is_empty(), "Cold menu leaves scenarios unloaded.")
	var cold_groups: Array = library.content_groups.duplicate(true)
	var cold_options: Array = library.content_group_options(expected_defaults).duplicate(true)
	var cold_challenges: Array = library.challenge_options().duplicate(true)
	var challenge_configs: Dictionary = {}
	for value in cold_challenges:
		var option: Dictionary = value
		var challenge_id := str(option.get("id", ""))
		challenge_configs[challenge_id] = library.challenge_config_for(challenge_id, "COLD-CONTENT-CHECK")

	library.load(false)
	var warm: Dictionary = library.load_start_menu()
	_expect(library.is_fully_loaded(), "Explicit full load retains its normal boundary.")
	_expect(library.content_groups == cold_groups, "Full loading preserves cold group definitions.")
	_expect(warm.get("content_groups", []) == cold_groups, "Already-full return projection includes the same groups.")
	_expect(library.default_content_group_ids() == expected_defaults, "Full loading preserves pack defaults.")
	_expect(library.content_group_options(expected_defaults) == cold_options, "Full loading preserves option order and selection projection.")
	_expect(library.challenge_options() == cold_challenges, "Named challenge menu metadata is unchanged.")
	for challenge_id in challenge_configs:
		_expect(library.challenge_config_for(str(challenge_id), "COLD-CONTENT-CHECK") == challenge_configs[challenge_id], "Named challenge contract survives full load: %s" % challenge_id)
	_expect(not library.games.is_empty(), "Run-only games load at the explicit full boundary.")

	print("BTH_START_MENU_CONTENT_CATALOG_CHECK " + JSON.stringify({
		"checks": checks, "failures": failures, "passed": failures.is_empty(),
		"group_count": cold_groups.size(), "default_count": expected_defaults.size(),
		"fidelity": "real ContentLibrary cold/full metadata APIs; no rendered input"
	}))
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
