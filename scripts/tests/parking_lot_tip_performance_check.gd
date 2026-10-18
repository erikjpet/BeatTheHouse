extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const EnvironmentSlotBinderScript := preload("res://scripts/core/environment_slot_binder.gd")
const EventModuleScript := preload("res://scripts/core/event_module.gd")
const FoundationMainScript := preload("res://scripts/ui/foundation_main.gd")
const RunGeneratorScript := preload("res://scripts/core/run_generator.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library := ContentLibraryScript.new()
	library.load()
	_check(library.validation_errors.is_empty(), "Content must load for the parking-lot tip check.")
	var run_state := RunStateScript.new()
	run_state.start_new("PARKING-LOT-TIP-PERFORMANCE")
	var generator := RunGeneratorScript.new(library)
	var arrival := generator.next_environment(run_state)
	_check(arrival != null and not run_state.current_environment.is_empty(), "The parking-lot tip fixture must install a generated room.")
	if not failures.is_empty():
		_finish()
		return
	# Build the note as real selected room content so its manifest row and slot
	# binding exist before pickup; injecting it after generation would not exercise
	# the player-facing removal path.
	var corner_archetype := library.environment_archetype("corner_store").duplicate(true)
	corner_archetype["event_pool"] = ["parking_lot_tip"]
	corner_archetype["required_event_ids"] = ["parking_lot_tip"]
	corner_archetype["event_count"] = [1, 1]
	var parking_environment := EnvironmentInstanceScript.from_archetype(
		corner_archetype,
		1,
		run_state.create_rng("parking_lot_tip_performance_room"),
		library
	).to_dict()
	parking_environment["world_node_id"] = "corner_store"
	parking_environment["world_map_travel"] = true
	var installed := run_state.set_environment(parking_environment)
	_check(bool(installed.get("ok", false)), "The parking-lot note fixture must install through the normal environment boundary.")
	run_state.enter_world_node("corner_store", run_state.current_environment)
	run_state.narrative_flags.erase("underground_tip")
	var bindings_before: Dictionary = run_state.current_environment.get("layout", {}).get("slot_bindings", {}).duplicate(true)
	_check(bindings_before.has("event:parking_lot_tip"), "The parking-lot note fixture must begin with an authenticated room slot.")
	var revision_before := int(run_state.world_map.get("revision", 0))
	var stage_probe := RunStateScript.new()
	stage_probe.from_dict(run_state.to_dict())
	var turn_started_usec := Time.get_ticks_usec()
	var turn_probe_result: Dictionary = stage_probe.advance_environment_turns(1, true)
	var turn_elapsed_usec := Time.get_ticks_usec() - turn_started_usec
	var unlock_started_usec := Time.get_ticks_usec()
	stage_probe.add_next_archetypes([WorldMapScript.UNDERGROUND_SHORTCUT_ID])
	var unlock_elapsed_usec := Time.get_ticks_usec() - unlock_started_usec
	_check(bool(turn_probe_result.get("ok", false)), "The parking-lot tip turn boundary must remain valid.")
	var host := FoundationMainScript.new()
	host.run_state = run_state
	var snapshot_started_usec := Time.get_ticks_usec()
	var rollback_snapshot: Dictionary = host.call("_foundation_lifecycle_snapshot")
	var snapshot_elapsed_usec := Time.get_ticks_usec() - snapshot_started_usec
	_check(not rollback_snapshot.is_empty(), "The player-facing event must own one complete rollback snapshot.")
	host.free()
	var event_module := EventModuleScript.new()
	event_module.setup(library.event("parking_lot_tip"), library)
	_check(event_module.can_trigger(run_state, run_state.current_environment), "Parking Lot Tip must be live before its route is unlocked.")
	var started_usec := Time.get_ticks_usec()
	# Foundation owns the lifecycle rollback for a player-facing response.
	var result := event_module.resolve(run_state, run_state.current_environment, "follow_tip", true, true)
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	_check(bool(result.get("ok", false)), "Following the parking-lot tip must resolve successfully.")
	_check(bool(run_state.narrative_flags.get("underground_tip", false)), "Following the note must set its progression flag.")
	_check(WorldMapScript.visible_node_ids(run_state.world_map).has(WorldMapScript.UNDERGROUND_SHORTCUT_ID), "Following the note must reveal the underground destination.")
	# Only the route reveal changes the live world map. The consumed room is the
	# authoritative current environment and is persisted into its revisit cache at
	# the existing departure boundary rather than being cloned on the pickup frame.
	_check(int(run_state.world_map.get("revision", 0)) == revision_before + 1, "The note must publish one route reveal and defer its redundant room-cache copy until departure.")
	var bindings_after: Dictionary = run_state.current_environment.get("layout", {}).get("slot_bindings", {})
	_check(not bindings_after.has("event:parking_lot_tip"), "The consumed parking-lot note must release its room slot immediately.")
	bindings_before.erase("event:parking_lot_tip")
	for prior_binding_id in bindings_before.keys():
		_check(bindings_after.has(prior_binding_id), "Resolving the note must retain unrelated room binding %s." % str(prior_binding_id))
	_check(EnvironmentInstanceScript.object_manifest_errors(run_state.current_environment).is_empty(), "The resolved note must leave a valid object manifest.")
	var layout_authority := EnvironmentSlotBinderScript.validate_base_layout_authority(run_state.current_environment)
	_check(bool(layout_authority.get("ok", false)), "The resolved note must retain valid base slot authority.")
	print("PARKING_LOT_TIP_ROLLBACK_MSEC=%.3f" % (float(snapshot_elapsed_usec) / 1000.0))
	print("PARKING_LOT_TIP_TURN_MSEC=%.3f" % (float(turn_elapsed_usec) / 1000.0))
	print("PARKING_LOT_TIP_UNLOCK_MSEC=%.3f" % (float(unlock_elapsed_usec) / 1000.0))
	print("PARKING_LOT_TIP_STAGES_USEC=" + JSON.stringify(result.get("debug_event_resolve_usec", {})))
	print("PARKING_LOT_TIP_MEMBERSHIP_USEC=" + JSON.stringify(result.get("debug_event_membership_usec", {})))
	print("PARKING_LOT_TIP_RESOLVE_MSEC=%.3f" % (float(elapsed_usec) / 1000.0))
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PARKING_LOT_TIP_PERFORMANCE_CHECK PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
