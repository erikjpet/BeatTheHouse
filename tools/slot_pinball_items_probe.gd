extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const BoardsScript := preload("res://scripts/games/slots/pinball/pinball_boards.gd")
const BoardScript := preload("res://scripts/games/slots/pinball/pinball_board.gd")
const SimScript := preload("res://scripts/games/slots/pinball/pinball_sim.gd")
const FeatureScript := preload("res://scripts/games/slots/pinball/pinball_feature.gd")
const SequencerScript := preload("res://scripts/games/slots/pinball/pinball_sequencer.gd")
const ItemsScript := preload("res://scripts/games/slots/pinball/pinball_items.gd")

const EXISTING_ITEM_IDS := [
	"drain_cleaner",
	"jackpot_magnet",
	"splitter_token",
	"return_spring",
	"tilt_dampener",
	"bumper_battery",
]

const NEW_ITEM_IDS := [
	"rubber_pegs",
	"magnet_cup",
	"extra_ball_token",
	"plunger_tuner",
	"lock_jammer",
]


func _init() -> void:
	var failures: Array = []
	var effects := _all_effects()
	_run_data_audit(effects, failures)
	_run_compile_modifier_audit(effects, failures)
	_run_feature_open_audit(effects, failures)
	_run_runtime_hook_audit(effects, failures)
	if failures.is_empty():
		print("PINBALL_ITEMS_OVERALL status=PASS failures=0")
		quit(0)
		return
	print("PINBALL_ITEMS_OVERALL status=FAIL failures=%d details=%s" % [failures.size(), JSON.stringify(failures)])
	quit(1)


func _run_data_audit(effects: Dictionary, failures: Array) -> void:
	var library: ContentLibrary = ContentLibraryScript.new()
	library.load()
	var checked: Array = []
	for item_id_value in EXISTING_ITEM_IDS + NEW_ITEM_IDS:
		var item_id := str(item_id_value)
		checked.append(item_id)
		var item: Dictionary = library.item(item_id)
		if item.is_empty():
			failures.append("missing pinball item data %s" % item_id)
			continue
		if not _string_array(item.get("content_groups", [])).has("slot_pack"):
			failures.append("pinball item %s is not in slot_pack" % item_id)
		var asset_path := str(item.get("asset_path", ""))
		if asset_path.is_empty() or not FileAccess.file_exists(asset_path):
			failures.append("pinball item %s asset missing at %s" % [item_id, asset_path])
	var registry_keys: Array = ItemsScript.verified_item_keys()
	for key_value in registry_keys:
		var key := str(key_value)
		if not effects.has(key):
			failures.append("pinball item effect fixture is missing registry key %s" % key)
	print("PINBALL_ITEMS_DATA existing=%s new=%s registry_keys=%s" % [
		JSON.stringify(EXISTING_ITEM_IDS),
		JSON.stringify(NEW_ITEM_IDS),
		JSON.stringify(registry_keys),
	])


func _run_compile_modifier_audit(effects: Dictionary, failures: Array) -> void:
	var compiler := BoardScript.new()
	var base: Dictionary = compiler.compile(BoardsScript.by_id("jackpot_works"))
	var modified: Dictionary = compiler.compile(BoardsScript.by_id("jackpot_works"), ItemsScript.compile_modifiers(effects))
	var base_restitution: PackedFloat32Array = base.get("peg_restitution", PackedFloat32Array())
	var modified_restitution: PackedFloat32Array = modified.get("peg_restitution", PackedFloat32Array())
	if modified_restitution.is_empty() or base_restitution.is_empty() or float(modified_restitution[0]) <= float(base_restitution[0]):
		failures.append("rubber pegs did not increase peg restitution")
	if float(modified.get("tilt_per_nudge", 1.0)) >= float(base.get("tilt_per_nudge", 1.0)):
		failures.append("tilt dampener did not reduce tilt gain")
	if _max_rect_area(modified) <= _max_rect_area(base):
		failures.append("magnet cup/jackpot magnet did not widen a cup rect")
	if int(modified.get("bumper_battery_hits", 0)) <= 0:
		failures.append("bumper battery compile params missing")
	if int(modified.get("return_spring_uses", 0)) <= 0:
		failures.append("return spring compile params missing")
	print("PINBALL_ITEMS_COMPILE rubber_rest=%.3f->%.3f tilt=%.3f->%.3f max_rect_area=%.4f->%.4f bumper_hits=%d return_uses=%d" % [
		float(base_restitution[0]) if not base_restitution.is_empty() else 0.0,
		float(modified_restitution[0]) if not modified_restitution.is_empty() else 0.0,
		float(base.get("tilt_per_nudge", 0.0)),
		float(modified.get("tilt_per_nudge", 0.0)),
		_max_rect_area(base),
		_max_rect_area(modified),
		int(modified.get("bumper_battery_hits", 0)),
		int(modified.get("return_spring_uses", 0)),
	])


func _run_feature_open_audit(effects: Dictionary, failures: Array) -> void:
	var run_state: RunState = RunStateScript.new()
	run_state.start_new("PINBALL-ITEM-FEATURE")
	var feature := FeatureScript.new()
	var active: Dictionary = feature.open({"format_id": "classic_3_reel"}, "em_bumper_drop", 10, run_state.create_rng("feature"), {
		"ball_budget": 3,
		"cap": 500,
		"item_effects": effects,
	})
	if int(active.get("balls_remaining", 0)) != 4:
		failures.append("extra ball token did not add one feature ball")
	if int(active.get("skill_power_width", 0)) < 6:
		failures.append("plunger tuner did not widen the skill sweet band")
	if not _dict(active.get("pinball_item_effects", {})).has("slot_pinball_extra_ball_token"):
		failures.append("pinball adapter did not preserve item effects")
	print("PINBALL_ITEMS_FEATURE_OPEN balls=%d skill_width=%d item_effect_count=%d" % [
		int(active.get("balls_remaining", 0)),
		int(active.get("skill_power_width", 0)),
		_dict(active.get("pinball_item_effects", {})).size(),
	])


func _run_runtime_hook_audit(effects: Dictionary, failures: Array) -> void:
	var compiler := BoardScript.new()
	var board: Dictionary = compiler.compile(BoardsScript.by_id("bumper_alley"), ItemsScript.compile_modifiers(effects))
	var drain_sim := SimScript.new()
	drain_sim.configure(board, 50201, {"cap": 500})
	var active := {"stake": 10, "session_cap": 500, "pinball_item_effects": effects, "pinball_item_hooks": []}
	ItemsScript.apply_drain_cleaner(active, drain_sim)
	var drain_hooks := _hook_names(_array(active.get("pinball_item_hooks", [])))
	if not drain_hooks.has("slot_pinball_drain_cleaner"):
		failures.append("drain cleaner hook did not fire")

	var spring_sim := SimScript.new()
	spring_sim.configure(board, 50202, {"cap": 500})
	var spring_ball := spring_sim.launch_ball({"power": 0.40, "aim": 0.0, "position": Vector2(0.45, 0.790)})
	spring_sim.positions[spring_ball] = Vector2(0.45, 0.790)
	spring_sim.velocities[spring_ball] = Vector2(0.02, 0.15)
	var before_spring_events := int(spring_sim.event_total_count)
	spring_sim.step_tick()
	if not _events_have_type(spring_sim.event_log_since(before_spring_events), "launcher") or int(spring_sim.compact_snapshot().get("return_spring_remaining", 1)) != 0:
		failures.append("return spring did not relaunch a low-energy lower-board ball")

	var bumper_sim := SimScript.new()
	bumper_sim.configure(board, 50203, {"cap": 500})
	var bumper_ball := bumper_sim.launch_ball({"power": 0.40, "aim": 0.0, "position": Vector2(0.34, 0.475)})
	bumper_sim.positions[bumper_ball] = Vector2(0.34, 0.475)
	bumper_sim.velocities[bumper_ball] = Vector2(0.0, -0.20)
	bumper_sim.step_tick()
	if int(bumper_sim.compact_snapshot().get("bumper_battery_hits_remaining", 99)) >= int(board.get("bumper_battery_hits", 0)):
		failures.append("bumper battery did not consume a charged bumper hit")

	var seq := SequencerScript.new()
	var lock_board: Dictionary = compiler.compile(BoardsScript.by_id("lock_cascade"), ItemsScript.compile_modifiers(effects))
	var seq_sim := SimScript.new()
	seq_sim.configure(lock_board, 50204, {"cap": 1000})
	var seq_active := {
		"stake": 10,
		"session_cap": 1000,
		"board_id": "lock_cascade",
		"pinball_item_effects": effects,
		"pinball_item_hooks": [],
		"sequencer_state": seq.initial_state("lock_cascade", "lane_multiball"),
	}
	seq.apply(seq_active, seq_sim, "lane_multiball", _events(["launcher", "launcher", "skill_shot", "pocket"]))
	ItemsScript.apply_event_hooks(seq_active, seq_sim, "lane_multiball", _events(["launcher", "launcher", "skill_shot", "pocket"]))
	var hook_names := _hook_names(_array(seq_active.get("pinball_item_hooks", [])))
	for required in ["slot_pinball_lock_jammer", "slot_pinball_splitter_token", "slot_pinball_jackpot_magnet"]:
		if not hook_names.has(required):
			failures.append("%s hook did not fire" % required)
	print("PINBALL_ITEMS_RUNTIME drain_total=%d drain_hooks=%s return_remaining=%d bumper_remaining=%d sequence_hooks=%s active_balls=%d" % [
		int(drain_sim.total_awarded),
		JSON.stringify(drain_hooks),
		int(spring_sim.compact_snapshot().get("return_spring_remaining", -1)),
		int(bumper_sim.compact_snapshot().get("bumper_battery_hits_remaining", -1)),
		JSON.stringify(hook_names),
		seq_sim.active_ball_count(),
	])


func _all_effects() -> Dictionary:
	return {
		"slot_pinball_drain_cleaner_uses": 1,
		"slot_pinball_drain_cleaner_floor_percent": 200,
		"slot_pinball_drain_cleaner_award_percent": 100,
		"slot_pinball_jackpot_magnet_uses": 4,
		"slot_pinball_jackpot_magnet_award_percent": 35,
		"slot_pinball_jackpot_magnet_progress_bonus": 1,
		"slot_pinball_splitter_token_uses": 1,
		"slot_pinball_splitter_token_extra_balls": 1,
		"slot_pinball_return_spring_uses": 1,
		"slot_pinball_return_spring_impulse": 170,
		"slot_pinball_tilt_dampener_percent": 45,
		"slot_pinball_bumper_battery_hits": 3,
		"slot_pinball_bumper_battery_award_percent": 40,
		"slot_pinball_bumper_battery_kick_percent": 130,
		"slot_pinball_bumper_battery_up_impulse": 18,
		"slot_pinball_rubber_pegs": 1,
		"slot_pinball_magnet_cup_radius_percent": 18,
		"slot_pinball_extra_ball_token": 1,
		"slot_pinball_plunger_tuner_width_percent": 200,
		"slot_pinball_lock_jammer_uses": 1,
	}


func _events(types: Array) -> Array:
	var result: Array = []
	for index in range(types.size()):
		result.append({"element_type": str(types[index]), "element_id": "%s_%d" % [str(types[index]), index], "award": 0, "ball_index": 0, "time": float(index) * 0.1})
	return result


func _hook_names(hooks: Array) -> Array:
	var result: Array = []
	for hook_value in hooks:
		var hook: Dictionary = _dict(hook_value)
		var item := str(hook.get("item", ""))
		if not item.is_empty() and not result.has(item):
			result.append(item)
	return result


func _events_have_type(events: Array, event_type: String) -> bool:
	for event_value in events:
		var event: Dictionary = _dict(event_value)
		if str(event.get("element_type", "")) == event_type:
			return true
	return false


func _max_rect_area(board: Dictionary) -> float:
	var sizes: PackedVector2Array = board.get("rect_sizes", PackedVector2Array())
	var max_area := 0.0
	for rect_size in sizes:
		max_area = maxf(max_area, rect_size.x * rect_size.y)
	return max_area


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		result.append(str(entry))
	return result


func _array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []


func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}
