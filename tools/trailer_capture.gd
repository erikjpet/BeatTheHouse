extends SceneTree

# Deterministic Movie Maker driver for the 0.5 gameplay trailer.
# Run one segment at a time so failed or outdated shots can be replaced without
# re-rendering the whole trailer:
#   godot --path . --resolution 1536x864 --fixed-fps 60 \
#     --write-movie .tmp/trailer/raw/slot.avi \
#     --script res://tools/trailer_capture.gd -- --segment=game_slot

const MainScene := preload("res://scenes/main.tscn")
const CAPTURE_SEED := "BEAT-THE-HOUSE-TRAILER-05"
const CAPTURE_FPS := 60
const VISUAL_WARMUP_SECONDS := 2.0
const MUSIC_WARMUP_SECONDS := 8.0

const GAME_ENVIRONMENTS := {
	"blackjack": "small_underground_casino",
	"roulette": "kitty_cat_lounge",
	"slot": "gas_station_casino",
	"scratch_tickets": "gas_station_casino",
	"bar_dice": "bar",
	"baccarat": "grand_casino_high_limit",
	"video_poker": "delta_queen",
	"pull_tabs": "jazz_club",
}

const GAME_ACTIONS := {
	"blackjack": [
		["blackjack_deal"],
		["blackjack_hit"],
		["blackjack_stand"],
	],
	"roulette": [
		["roulette_bet"],
		["roulette_spin"],
	],
	"slot": [
		["slot_spin"],
	],
	"scratch_tickets": [
		["scratch_buy"],
		["scratch_all", "scratch_scrub", "scratch_reveal"],
	],
	"bar_dice": [
		["bar_dice_roll"],
	],
	"baccarat": [
		["baccarat_bet"],
		["baccarat_deal"],
		["baccarat_squeeze_reveal"],
	],
	"video_poker": [
		["video_poker_deal"],
		["video_poker_hold"],
		["video_poker_draw"],
	],
	"pull_tabs": [
		["pull_tab_buy_all", "pull_tab_buy"],
		["pull_tab_reveal_next", "pull_tab_reveal"],
		["pull_tab_file_ticket", "pull_tab_redeem"],
	],
}

var app: Control
var segment := "roadside"
var runtime_dir := ".tmp/trailer/runtime"
var action_failures: Array[String] = []


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--segment="):
			segment = argument.trim_prefix("--segment=").strip_edges()
		elif argument.begins_with("--runtime-dir="):
			runtime_dir = argument.trim_prefix("--runtime-dir=").strip_edges()
	call_deferred("_run")


func _run() -> void:
	_isolate_capture_profile()
	app = MainScene.instantiate()
	app.set("autosave_slot_id", "trailer_capture")
	root.add_child(app)
	await _settle_frames(8)
	var ok := await _capture_segment()
	await _settle_frames(4)
	_cleanup_capture_save()
	if not ok:
		push_error("Trailer segment failed: %s" % segment)
		quit(1)
		return
	if not action_failures.is_empty():
		print("TRAILER_ACTION_WARNINGS %s" % JSON.stringify(action_failures))
	print("TRAILER_CAPTURE_DONE segment=%s" % segment)
	quit(0)


func _capture_segment() -> bool:
	if segment == "music_bed":
		return await _capture_music_bed()
	if segment == "roadside":
		return await _capture_roadside()
	if segment == "world_map":
		return await _capture_world_map()
	if segment == "heat_cheat":
		return await _capture_heat_cheat()
	if segment == "grand_casino":
		return await _capture_grand_casino()
	if segment == "cage_card":
		return await _capture_cage_card()
	if segment == "rourke_call":
		return await _capture_rourke(false)
	if segment == "rourke_duel":
		return await _capture_rourke(true)
	if segment.begins_with("game_"):
		return await _capture_game(segment.trim_prefix("game_"))
	push_error("Unknown trailer segment: %s" % segment)
	return false


func _capture_music_bed() -> bool:
	if not await _prepare_environment("jazz_club"):
		return false
	app.get("run_state").change_drunk(18)
	app.call("_refresh")
	await _hold_seconds(MUSIC_WARMUP_SECONDS)
	print("TRAILER_CAPTURE_ACTIVE segment=music_bed frame=%d" % _movie_frame())
	await _hold_seconds(68.0)
	return true


func _capture_roadside() -> bool:
	if not await _prepare_environment("bar"):
		return false
	await _hold_seconds(VISUAL_WARMUP_SECONDS)
	print("TRAILER_CAPTURE_ACTIVE segment=roadside frame=%d" % _movie_frame())
	await _focus_first_object_with_prefix("game:")
	await _hold_seconds(6.0)
	return true


func _capture_world_map() -> bool:
	if not await _prepare_environment("delta_queen"):
		return false
	var run_state: RunState = app.get("run_state")
	run_state.advance_game_clock_minutes(720)
	app.call("_refresh")
	await _settle_frames(6)
	app.call("open_world_map", true)
	await _settle_frames(10)
	_select_first_world_map_destination()
	await _hold_seconds(VISUAL_WARMUP_SECONDS)
	print("TRAILER_CAPTURE_ACTIVE segment=world_map frame=%d" % _movie_frame())
	await _hold_seconds(5.0)
	return true


func _capture_heat_cheat() -> bool:
	if not await _prepare_environment("delta_queen", "blackjack"):
		return false
	var run_state: RunState = app.get("run_state")
	run_state.bankroll = 260
	run_state.add_item("marked_cards")
	run_state.add_item("side_bet_chart")
	run_state.change_drunk(72)
	run_state.add_suspicion("trailer_heat", 76, "behavior", true)
	app.call("_refresh")
	await _settle_frames(8)
	await _hold_seconds(VISUAL_WARMUP_SECONDS)
	print("TRAILER_CAPTURE_ACTIVE segment=heat_cheat frame=%d" % _movie_frame())
	await _try_surface_actions(["blackjack_deal"])
	await _hold_seconds(1.0)
	await _try_surface_actions(["blackjack_peek"])
	await _hold_seconds(1.0)
	await _try_surface_actions(["blackjack_hit", "blackjack_stand"])
	await _hold_seconds(4.0)
	return true


func _capture_game(game_id: String) -> bool:
	if not GAME_ENVIRONMENTS.has(game_id):
		push_error("No trailer environment mapped for game: %s" % game_id)
		return false
	if not await _prepare_environment(str(GAME_ENVIRONMENTS[game_id]), game_id):
		return false
	var run_state: RunState = app.get("run_state")
	run_state.bankroll = 400
	app.set("selected_stake", 10)
	app.call("_refresh")
	await _settle_frames(8)
	await _hold_seconds(VISUAL_WARMUP_SECONDS)
	print("TRAILER_CAPTURE_ACTIVE segment=game_%s frame=%d" % [game_id, _movie_frame()])
	var action_groups: Array = GAME_ACTIONS.get(game_id, [])
	for group_value in action_groups:
		var candidates: Array = group_value if typeof(group_value) == TYPE_ARRAY else []
		await _try_surface_actions(candidates)
		await _hold_seconds(0.8)
	await _hold_seconds(2.8)
	return true


func _capture_grand_casino() -> bool:
	var environment := _environment_from_archetype("grand_casino")
	if environment.is_empty():
		return false
	var run_state := _fixture_run("TRAILER-GRAND-CASINO", environment)
	run_state.bankroll = 520
	run_state.grand_casino_chips = 85
	run_state.advance_game_clock_minutes(720)
	run_state.add_suspicion("trailer_grand_heat", 54, "behavior", true)
	_record_grand_casino_games(run_state, 4)
	run_state.evaluate_environment_objective_state()
	_set_fixture_run(run_state)
	await _settle_frames(12)
	await _hold_seconds(VISUAL_WARMUP_SECONDS)
	print("TRAILER_CAPTURE_ACTIVE segment=grand_casino frame=%d" % _movie_frame())
	app.call("focus_interactable_object", "casino_fixture:host_desk")
	await _hold_seconds(2.4)
	app.call("focus_interactable_object", "travel:grand_casino_high_limit")
	await _hold_seconds(2.8)
	return true


func _capture_cage_card() -> bool:
	var environment := _environment_from_archetype("grand_casino")
	if environment.is_empty():
		return false
	var run_state := _fixture_run("TRAILER-CAGE-CARD", environment)
	var objective: Dictionary = environment.get("demo_objective", {})
	var target := int(objective.get("high_roller_target_bankroll", objective.get("target_bankroll", 400)))
	var net := int(objective.get("high_roller_net_winnings", 75))
	var min_games := int(objective.get("high_roller_min_grand_casino_games", 5))
	run_state.narrative_flags["grand_casino_players_card_awarded_tier"] = RunState.GRAND_CASINO_PLAYERS_CARD_TIER_SILVER
	run_state.narrative_flags["grand_casino_players_card_tier"] = RunState.GRAND_CASINO_PLAYERS_CARD_TIER_SILVER
	run_state.narrative_flags["grand_casino_players_card_highest_tier"] = RunState.GRAND_CASINO_PLAYERS_CARD_TIER_SILVER
	run_state.narrative_flags["grand_casino_players_card_segment_start_games"] = 0
	run_state.narrative_flags["grand_casino_players_card_segment_start_net_winnings"] = 0
	_record_grand_casino_games(run_state, min_games)
	run_state.bankroll = maxi(target, int(run_state.narrative_flags.get("grand_casino_entry_bankroll", 0)) + net)
	run_state.grand_casino_chips = 120
	run_state.evaluate_environment_objective_state()
	_set_fixture_run(run_state)
	var generator: RunGenerator = app.get("generator")
	if generator == null or not generator.enter_grand_casino_room(run_state, RunState.GRAND_CASINO_CAGE_ARCHETYPE_ID):
		push_error("Trailer could not enter the Grand Casino Cage.")
		return false
	app.call("_refresh")
	await _settle_frames(12)
	if not bool(app.call("_start_linda_cage_services", {"object_id": "casino_fixture:cage_counter"})):
		push_error("Trailer could not open Linda's Cage services.")
		return false
	while not run_state.next_pending_talk_event().is_empty():
		run_state.complete_talk_event_resolution(str(run_state.next_pending_talk_event().get("event_id", "")))
	app.call("_refresh_talk_dock")
	app.call("_complete_cage_players_card_review")
	await _settle_frames(12)
	await _hold_seconds(VISUAL_WARMUP_SECONDS)
	print("TRAILER_CAPTURE_ACTIVE segment=cage_card frame=%d" % _movie_frame())
	await _hold_seconds(5.2)
	return true


func _capture_rourke(enter_duel: bool) -> bool:
	var environment := _environment_from_archetype("grand_casino")
	if environment.is_empty():
		return false
	environment["event_ids"] = [RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID]
	var run_state := _fixture_run("TRAILER-ROURKE", environment)
	run_state.current_environment["turns"] = 0
	var objective: Dictionary = run_state.current_environment.get("demo_objective", {})
	run_state.add_suspicion("trailer_showdown", int(objective.get("showdown_heat_threshold", 70)), "behavior", true)
	run_state.evaluate_environment_objective_state()
	_set_fixture_run(run_state)
	app.call("_set_current_screen", "EVENT")
	app.call("_refresh")
	if not bool(app.call("_show_interactable_event_popup", RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID)):
		push_error("Trailer could not open Rourke's call.")
		return false
	app.call("resolve_event_choice", RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID, "enter_back_room")
	await _settle_frames(3)
	app.call("resolve_event_choice", RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID, "keep_everything")
	await _settle_frames(3)
	app.call("resolve_event_choice", RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID, "face_rourke")
	await _settle_frames(5)
	if enter_duel:
		for _beat in range(3):
			app.call("resolve_event_choice", RunState.GRAND_CASINO_SHOWDOWN_EVENT_ID, "hold_steady")
			await _settle_frames(5)
		await _settle_frames(12)
	await _hold_seconds(VISUAL_WARMUP_SECONDS)
	print("TRAILER_CAPTURE_ACTIVE segment=%s frame=%d" % [segment, _movie_frame()])
	if enter_duel:
		await _try_surface_actions(["blackjack_deal"])
		await _hold_seconds(1.0)
		await _try_surface_actions(["blackjack_hit", "blackjack_stand"])
	await _hold_seconds(5.0)
	return true


func _prepare_environment(archetype_id: String, game_id: String = "") -> bool:
	app.call("start_foundation_run", CAPTURE_SEED, {}, false)
	await _settle_frames(8)
	var environment := _environment_from_archetype(archetype_id)
	if environment.is_empty():
		return false
	var run_state: RunState = app.get("run_state")
	run_state.set_environment(environment)
	app.call("_clear_selected_game_action")
	app.call("_clear_selected_travel")
	app.call("clear_interaction_focus")
	app.call("_refresh")
	await _settle_frames(10)
	if not game_id.is_empty():
		app.call("enter_game", game_id)
		await _settle_frames(12)
		if str(app.get("current_screen")) != "GAME":
			push_error("Trailer could not enter game: %s" % game_id)
			return false
	return true


func _environment_from_archetype(archetype_id: String) -> Dictionary:
	var library: ContentLibrary = app.get("library")
	var run_state: RunState = app.get("run_state")
	if library == null:
		return {}
	var archetype: Dictionary = library.environment_archetype(archetype_id)
	if archetype.is_empty():
		for archetype_value in library.environment_archetypes:
			if typeof(archetype_value) == TYPE_DICTIONARY and str((archetype_value as Dictionary).get("id", "")) == archetype_id:
				archetype = (archetype_value as Dictionary).duplicate(true)
				break
	if archetype.is_empty():
		push_error("Trailer archetype missing: %s" % archetype_id)
		return {}
	if run_state == null:
		return _fixture_environment(archetype)
	var rng: RngStream = run_state.create_rng("trailer_environment:%s" % archetype_id)
	var environment: EnvironmentInstance = EnvironmentInstance.from_archetype(archetype, 1, rng, library, run_state.challenge_config)
	var data := environment.to_dict()
	data["world_node_id"] = archetype_id
	data["layout"] = EnvironmentInstance.ensure_generated_layout(data)
	run_state.save_rng(rng)
	return data


func _fixture_environment(archetype: Dictionary) -> Dictionary:
	var environment := archetype.duplicate(true)
	environment["id"] = "trailer_%s" % str(archetype.get("id", "environment"))
	environment["archetype_id"] = str(archetype.get("id", ""))
	environment["display_name"] = str(archetype.get("display_name", archetype.get("id", "Casino")))
	environment["game_ids"] = (archetype.get("game_pool", []) as Array).duplicate()
	environment["event_ids"] = []
	environment["travel_hooks"] = (archetype.get("travel_hooks", []) as Array).duplicate()
	environment["layout"] = EnvironmentInstance.ensure_generated_layout(environment)
	return environment


func _fixture_run(seed_text: String, environment: Dictionary) -> RunState:
	var run_state := RunState.new()
	run_state.start_new(seed_text)
	run_state.set_environment(environment.duplicate(true))
	return run_state


func _set_fixture_run(run_state: RunState) -> void:
	app.set("run_state", run_state)
	app.set("current_game", null)
	app.call("_set_current_screen", "ENVIRONMENT")
	app.call("_refresh_run_action_service")
	app.call("_refresh_runtime_environment_views")
	app.call("_refresh")


func _record_grand_casino_games(run_state: RunState, count: int) -> void:
	for game_index in range(maxi(0, count)):
		run_state.record_grand_casino_game_result({
			"ok": true,
			"type": "game_action",
			"source_id": "blackjack",
			"game_id": "blackjack",
			"action_id": "trailer_clean_game",
			"action_kind": "legal",
			"stake": 10 + game_index,
			"deltas": {
				"story_log": [{
					"type": "game_action",
					"game_id": "blackjack",
					"stake_cost": 10 + game_index,
				}],
			},
			"message": "A clean Grand Casino result.",
		})


func _try_surface_actions(candidates: Array) -> bool:
	var surface_canvas: Control = app.get("game_surface_canvas")
	if surface_canvas == null or not surface_canvas.visible or not surface_canvas.has_method("current_view_snapshot"):
		action_failures.append("%s:no-visible-game-surface" % segment)
		return false
	var snapshot: Dictionary = surface_canvas.call("current_view_snapshot")
	var hit_actions: Array = snapshot.get("surface_hit_actions", [])
	for candidate_value in candidates:
		var candidate := str(candidate_value)
		for hit_value in hit_actions:
			if typeof(hit_value) != TYPE_DICTIONARY:
				continue
			var hit: Dictionary = hit_value
			if str(hit.get("action", "")) != candidate:
				continue
			app.call("_on_game_surface_action", candidate, int(hit.get("index", 0)), true)
			await _settle_frames(4)
			return true
	var available_actions: Array[String] = []
	for hit_value in hit_actions:
		if typeof(hit_value) != TYPE_DICTIONARY:
			continue
		var action := str((hit_value as Dictionary).get("action", ""))
		if not action.is_empty() and not available_actions.has(action):
			available_actions.append(action)
	action_failures.append("%s:missing-action:%s:available=%s" % [
		segment,
		",".join(candidates),
		",".join(available_actions),
	])
	return false


func _focus_first_object_with_prefix(prefix: String) -> bool:
	var snapshot: Dictionary = app.call("current_spatial_interaction_snapshot")
	var objects: Array = snapshot.get("objects", [])
	for object_value in objects:
		if typeof(object_value) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = object_value
		var object_id := str(object_data.get("object_id", ""))
		if object_id.begins_with(prefix):
			app.call("focus_interactable_object", object_id)
			await _settle_frames(4)
			return true
	return false


func _select_first_world_map_destination() -> void:
	var run_state: RunState = app.get("run_state")
	if run_state == null:
		return
	var map_data: Dictionary = run_state.world_map
	var current_id := str(map_data.get("current_node_id", ""))
	var nodes: Array = map_data.get("nodes", [])
	for node_value in nodes:
		if typeof(node_value) != TYPE_DICTIONARY:
			continue
		var node: Dictionary = node_value
		var node_id := str(node.get("id", ""))
		if node_id.is_empty() or node_id == current_id or str(node.get("state", "hidden")) == "hidden":
			continue
		if bool(app.call("select_world_map_node", node_id)):
			return


func _isolate_capture_profile() -> void:
	var absolute_runtime_dir := ProjectSettings.globalize_path("res://%s" % runtime_dir)
	DirAccess.make_dir_recursive_absolute(absolute_runtime_dir)
	OS.set_environment("BTH_USER_SETTINGS_PATH", "%s/user_settings.json" % absolute_runtime_dir)
	OS.set_environment("BTH_META_COLLECTION_PATH", "%s/meta_collection.json" % absolute_runtime_dir)
	OS.set_environment("BTH_PROFILE_INVENTORY_PATH", "%s/profile_inventory.json" % absolute_runtime_dir)


func _cleanup_capture_save() -> void:
	if app == null:
		return
	var save_service: SaveService = app.get("save_service")
	if save_service != null:
		save_service.clear_run("trailer_capture")


func _movie_frame() -> int:
	return Engine.get_process_frames()


func _hold_seconds(seconds: float) -> void:
	await _settle_frames(maxi(1, int(round(seconds * CAPTURE_FPS))))


func _settle_frames(frames: int) -> void:
	for _frame in range(maxi(0, frames)):
		await process_frame
