extends SceneTree

const RunStateScript := preload("res://scripts/core/run_state.gd")
const RunStateSchemaScript := preload("res://scripts/core/run_state_schema.gd")
const UserSettingsScript := preload("res://scripts/core/user_settings.gd")
const ProfileInventoryScript := preload("res://scripts/core/profile_inventory.gd")
const MetaCollectionServiceScript := preload("res://scripts/core/meta_collection_service.gd")

var _failures: Array[String] = []


func _init() -> void:
	_check_run_state()
	_check_user_settings()
	_check_profile_inventory()
	_check_meta_collection()
	if _failures.is_empty():
		print("HEALTH06_1_SERIALIZATION PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check_run_state() -> void:
	_expect(RunStateSchemaScript.serialized_keys() == RunStateSchemaScript.consumed_keys(), "CH-28: RunState serialized and consumed key sets differ.")
	var source: RunState = RunStateScript.new()
	source.start_new("HEALTH06-1-SERIALIZATION")
	source.bankroll = 321
	source.grand_casino_chips = 17
	source.baseline_luck = 4
	source.drunk_level = 2
	source.run_spending_score = 19
	source.narrative_flags["health06_1"] = {"nested": [1, 2, 3]}
	source.story_flags["health06_1_story"] = true
	var encoded := source.to_dict()
	_expect(_sorted_keys(encoded) == RunStateSchemaScript.serialized_keys(), "CH-28: RunState.to_dict did not emit the complete canonical schema.")
	var restored: RunState = RunStateScript.new()
	restored.from_dict(encoded)
	var stable_once := restored.to_dict()
	var restored_again: RunState = RunStateScript.new()
	restored_again.from_dict(stable_once)
	_expect(stable_once == restored_again.to_dict(), "CH-28: RunState did not stabilize after a full schema round trip.")


func _check_user_settings() -> void:
	var source: UserSettings = UserSettingsScript.new()
	source.resolution = Vector2i(1920, 1080)
	source.window_mode = "borderless"
	source.vsync_enabled = false
	source.master_volume = 0.25
	source.music_volume = 0.5
	source.sfx_volume = 0.75
	source.audio_calm = true
	source.ui_scale = 1.2
	source.text_size = "large"
	source.reduce_motion = true
	source.drunk_effect_mode = "classic"
	source.high_contrast = true
	source.play_on_small_screen = true
	source.coach_tips_enabled = false
	source.selected_home_type_id = "apartment"
	source.developer_placement_mode = true
	var restored: UserSettings = UserSettingsScript.new()
	restored.from_dict(source.to_dict())
	_expect(source.to_dict() == restored.to_dict(), "CH-28: UserSettings round trip is asymmetric.")
	_expect(_sorted_keys(source.to_dict()) == UserSettingsScript.storage_keys(), "CH-28: UserSettings declared keys differ from its payload.")


func _check_profile_inventory() -> void:
	var source := {
		"schema_version": ProfileInventoryScript.SCHEMA_VERSION,
		"act": 1,
		"items": [{"id": "health_token", "display_name": "Health Token", "description": "fixture", "icon_key": "token", "quantity": 2}],
		"challenge_completions": {"standard": 2},
		"run_history": [],
		"daily_runs": {},
		"lifetime_stats": {"runs_started": 3},
		"act_seam": {},
		"scratch_ticket_types_discovered": ["two_fer"],
		"scratch_ticket_collection_acknowledged": false,
		"tips_seen": {"tip": true},
		"tutorial_completed": true,
		"future_field": {"preserved": true},
	}
	var profile: ProfileInventory = ProfileInventoryScript.new()
	profile.from_dict(source)
	var encoded := profile.to_dict()
	var restored: ProfileInventory = ProfileInventoryScript.new()
	restored.from_dict(encoded)
	_expect(encoded == restored.to_dict(), "CH-28: ProfileInventory round trip is asymmetric.")
	_expect(bool(encoded.get("future_field", {}).get("preserved", false)), "CH-28: ProfileInventory lost an unknown forward-compatible field.")


func _check_meta_collection() -> void:
	var service: MetaCollectionService = MetaCollectionServiceScript.new()
	service.add_gold(37)
	var snapshot := service.snapshot()
	var normalized: Dictionary = service.call("_normalize_store", snapshot)
	_expect(snapshot == normalized, "CH-28: meta collection snapshot is not stable under its declared normalization.")
	_expect(_sorted_keys(snapshot) == MetaCollectionServiceScript.store_storage_keys(), "CH-28: meta collection declared keys differ from its payload.")


func _sorted_keys(data: Dictionary) -> Array:
	var keys: Array = data.keys()
	keys.sort()
	return keys


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
