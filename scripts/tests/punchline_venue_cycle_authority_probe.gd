extends SceneTree

# Synthetic cycle-boundary diagnosis. Never imports a campaign or resident key.
# Trace hooks delegate to the original RunState methods exactly once.
const MainScene := preload("res://scenes/main.tscn")
const Tutorial := preload("res://scripts/core/tutorial_flow.gd")
const Fidelity := preload("res://scripts/tests/foundation/harness_production_fidelity.gd")
const Binder := preload("res://scripts/core/environment_slot_binder.gd")
const TARGET := "small_underground_casino"
const SLOT := "punchline_venue_cycle_authority_probe"
const OLD_CLOCK := 1575 # Day2 02:15, before the 24h venue's 02:30 boundary.
const NEW_CLOCK := 1770 # Day2 05:30, after its 04:00 reopening.

class TracedRun extends RunState:
	var boundaries: Array = []
	func capture(stage: String) -> void:
		if boundaries.size() >= 40: return
		var layout: Dictionary = current_environment.get("layout", {})
		var bindings: Dictionary = layout.get("slot_bindings", {})
		var proof := Binder.validate_base_layout_authority(current_environment)
		boundaries.append({"stage": stage, "layer": current_environment.get("current_layer_id", ""),
			"scenario": current_environment.get("scenario_id", ""),
			"game_ids": current_environment.get("game_ids", []).duplicate(true),
			"sequence_base_game_ids": current_environment.get("scenario_sequence_base_game_ids", []).duplicate(true),
			"world_map_travel": current_environment.get("world_map_travel", false),
			"bindings": bindings.duplicate(true),
			"cycle": current_environment.get("environment_situation_cycle_id", ""),
			"stored_binding_digest": layout.get("slot_binding_digest", ""),
			"computed_binding_digest": Binder.binding_digest(bindings),
			"binding_count": bindings.size(), "authority_ok": proof.get("ok", false),
			"authority_errors": proof.get("errors", []),
			"placement_errors": layout.get("placement_errors", []),
			"manifest_errors": EnvironmentInstance.object_manifest_errors(current_environment)})
	func reconcile_current_environment_object_manifest(refresh_layout: bool = false) -> Dictionary:
		capture("before_reconcile_layout_" + str(refresh_layout))
		var result := super.reconcile_current_environment_object_manifest(refresh_layout)
		capture("after_reconcile_layout_" + str(refresh_layout))
		return result
	func scenario_finalize_installed_environment(library: ContentLibrary, layout_context: Dictionary = {}) -> Dictionary:
		capture("before_finalize")
		var result := super.scenario_finalize_installed_environment(library, layout_context)
		capture("after_finalize")
		return result

var app: Node
var checks := 0
var failures: Array[String] = []
var facts: Dictionary = {"fidelity": "Fresh authored tutorial generation at Day2 02:15, ordinary clock advance to05:30, real venue-cycle transaction. No original R02 access, no imported save/key, no paid actions."}

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

func _frames(n: int = 4) -> void:
	for _i in range(n): await process_frame

func _protected(run: RunState) -> Dictionary:
	return {"cash": run.bankroll, "chips": run.grand_casino_chips, "heat": run.suspicion_level(),
		"rng": run.rng_state, "story": run.story_log.duplicate(true), "debt": run.debt.duplicate(true),
		"delivery": run.active_delivery_run.duplicate(true)}

func _room_facts(run: RunState) -> Dictionary:
	var proof := run.validate_room_action_authority()
	var layout: Dictionary = run.current_environment.get("layout", {})
	return {"clock": run.game_clock_minutes, "cycle": run.current_environment.get("environment_situation_cycle_id", ""),
		"layer": run.current_environment.get("current_layer_id", ""), "scenario": run.current_environment.get("scenario_id", ""),
		"layer_keys": (run.current_environment.get("layer_states", {}) as Dictionary).keys(),
		"proof_ok": proof.get("ok", false), "errors": proof.get("errors", []), "placement_errors": layout.get("placement_errors", []),
		"stored_layers": _stored_layer_facts(run.current_environment)}

func _stored_layer_facts(environment: Dictionary) -> Array:
	var result: Array = []
	var layers: Dictionary = environment.get("layer_states", {})
	for key in layers:
		var room: Dictionary = layers[key]
		var layout: Dictionary = room.get("layout", {})
		var proof := Binder.validate_base_layout_authority(room)
		result.append({"layer_key": key, "layer_id": room.get("current_layer_id", ""),
			"scenario": room.get("scenario_id", ""), "cycle": room.get("environment_situation_cycle_id", ""),
			"authority_ok": proof.get("ok", false), "errors": proof.get("errors", []),
			"stored_digest": layout.get("slot_binding_digest", ""),
			"computed_digest": Binder.binding_digest(layout.get("slot_bindings", {})),
			"placement_errors": layout.get("placement_errors", [])})
	return result

func _run() -> void:
	var private_root := OS.get_environment("BTH_PUNCHLINE_PRIVATE_ROOT").replace("\\", "/").trim_suffix("/")
	var user_dir := ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not _check(private_root.is_absolute_path() and private_root.contains("/native-private-punchline-cycle-") and user_dir.begins_with(private_root + "/"), "fresh key-local contained root"):
		_finish(); return
	for name in ["APPDATA", "BTH_SAVE_DIR", "BTH_DISTRIBUTION_DATA_ROOT", "BTH_PROFILE_INVENTORY_PATH", "BTH_META_COLLECTION_PATH", "BTH_USER_SETTINGS_PATH"]:
		var value := OS.get_environment(name).replace("\\", "/")
		if not _check(value == private_root or value.begins_with(private_root + "/"), "private containment " + name): _finish(); return
	var mode := OS.get_environment("BTH_PUNCHLINE_PROBE_MODE")
	if not _check(mode in ["cross_warm", "cross_cold"], "finite cycle mode"): _finish(); return
	facts["mode"] = mode
	root.size = Vector2i(1280, 720)
	app = MainScene.instantiate()
	app.continuous_environment_clock_enabled = false
	app.script_prewarm_stopping = true
	app.autosave_slot_id = SLOT
	root.add_child(app)
	await _frames(2)
	app.set_process(false)
	if not _check(app._ensure_run_ui_built(), "ordinary Main dependencies"):
		await _close(); _finish(); return
	app._ensure_full_content_library_loaded()
	if mode == "cross_warm":
		var run := TracedRun.new()
		run.start_new("FIRST-NIGHT-ACE-17", Tutorial.challenge_config(app.library))
		run.game_clock_minutes = OLD_CLOCK
		var generation_errors: Array = []
		Fidelity.generate_and_finalize(app.generator, run, generation_errors, "old-cycle Punchline", TARGET, true)
		facts["generation_errors"] = generation_errors
		if not _check(generation_errors.is_empty(), "canonical old-cycle generation/finalization"):
			facts["boundaries"] = run.boundaries; await _close(); _finish(); return
		var layers: Dictionary = run.current_environment.get("layer_states", {})
		_check((layers.get("club", {}) as Dictionary).get("game_ids", []) == [], "fresh tutorial game override does not leak to the Club")
		_check(run.current_environment.get("game_ids", []) == ["blackjack"], "configured Casino retains its required tutorial table")
		# Recreate the exact old producer policy using a synthetic config without a
		# layer selector, then install only that independently generated idle floor.
		# No campaign state or userdata is copied. The real cycle owns the repair.
		var legacy_config := run.challenge_config.duplicate(true)
		(legacy_config["modifiers"] as Dictionary)["environment_layer_overrides"] = {}
		var legacy_rng := RngStream.new()
		legacy_rng.configure(run.seed_value, run.seed_value)
		var archetype: Dictionary = app.generator._archetype_by_id(TARGET)
		var legacy := EnvironmentInstance.from_archetype_layer(archetype, "club", 0, legacy_rng, app.library, legacy_config).to_dict()
		legacy.erase("layer_states")
		_check(legacy.get("game_ids", []) == ["blackjack"], "old override policy faithfully recreates off-layer Blackjack")
		_check(bool(Binder.validate_base_layout_authority(legacy).get("ok", false)) and EnvironmentInstance.object_manifest_errors(legacy).is_empty(), "legacy synthetic floor has valid incoming strict proofs")
		_check_legacy_guards(run, legacy, EnvironmentInstance._archetype_for_layer(archetype, "club"))
		layers["club"] = legacy
		run.current_environment["layer_states"] = layers
		facts["before_clock"] = _room_facts(run)
		_check(bool(facts.before_clock.proof_ok), "incoming old-cycle room has strict authority")
		var protected_before := _protected(run)
		var clock_result := run.advance_game_clock_minutes(NEW_CLOCK - OLD_CLOCK)
		_check(bool(clock_result.get("ok", false)) and run.game_clock_minutes == NEW_CLOCK, "ordinary clock advance crosses actual cycle boundary")
		_check(_protected(run) == protected_before, "clock crossing has no financial/history/RNG effect")
		facts["before_cycle"] = _room_facts(run)
		_check(bool(facts.before_cycle.proof_ok), "pre-refresh persisted old-cycle authority remains valid")
		var saved: Error = app.save_service.save_run(run, SLOT)
		_check(saved == OK, "official Save preserves pending lazy cycle for same-root cold test")
		run.boundaries.clear()
		var result: Dictionary = app.generator.refresh_current_venue_scenario_cycle(run)
		facts["cycle_result"] = result
		facts["boundaries"] = run.boundaries.duplicate(true)
		facts["after_cycle"] = _room_facts(run)
		_check(bool(result.get("ok", false)), "elapsed-cycle transaction succeeds")
		_check(bool(result.get("changed", false)), "elapsed cycle retires and reopens exactly once")
		_check(bool(facts.after_cycle.proof_ok), "new-cycle strict publication remains valid")
		_check(_protected(run) == protected_before, "cycle refresh preserves financial/history/RNG state")
		if bool(result.get("ok", false)):
			var club: Dictionary = (run.current_environment.get("layer_states", {}) as Dictionary).get("club", {})
			_check(club.get("game_ids", []) == [] and club.get("game_states", {}) == {}, "only the unplayed off-layer table is retired")
			_check((club.get("layout", {}) as Dictionary).get("slot_bindings", {}).has("numbers:book"), "authored Numbers book mounts without displacing a game")
		if bool(result.get("ok", false)):
			var once := run.to_dict()
			var repeat: Dictionary = app.generator.refresh_current_venue_scenario_cycle(run)
			_check(bool(repeat.get("ok", false)) and not bool(repeat.get("changed", true)), "repeat refresh is unchanged")
			_check(run.to_dict() == once, "repeat refresh has no run mutations")
	else:
		_check(app.load_foundation_run(), "ordinary same-root fresh-process Continue")
		facts["immediate_run_present"] = app.run_state != null
		if app.run_state != null: facts["immediate_cold_room"] = _room_facts(app.run_state)
		await _frames()
		_check(app.run_state != null, "Continue retains the active run after queued startup work")
		if app.run_state != null:
			facts["cold_room"] = _room_facts(app.run_state)
			_check(bool(facts.cold_room.proof_ok), "cold Main publication strict proof")
			_check(not app._room_publication_save_blocked(), "cold Main retains usable room and allows Save")
			var enabled := 0
			for row in app._interactable_object_view_list():
				if bool(row.get("enabled", false)) and not bool(row.get("room_geometry_rejected", false)): enabled += 1
			facts["enabled_controls"] = enabled
			_check(enabled > 0, "cold ordinary room controls remain enabled")
	await _close()
	_finish()

func _check_legacy_guards(run: RunState, legacy: Dictionary, flat: Dictionary) -> void:
	var repaired := legacy.duplicate(true)
	var expected := legacy.duplicate(true)
	expected["game_ids"] = []
	var result: Dictionary = app.generator._prepare_legacy_tutorial_layer_for_cycle(run, repaired, flat)
	_check(bool(result.get("ok", false)) and repaired == expected, "legacy repair changes only the exact unused game list")
	var paid := legacy.duplicate(true)
	paid["game_states"] = {"blackjack": {"phase": "player_turn", "bet": 5, "paid_state_guard": true}}
	var paid_before := paid.duplicate(true)
	result = app.generator._prepare_legacy_tutorial_layer_for_cycle(run, paid, flat)
	_check(not bool(result.get("ok", true)) and paid == paid_before, "stored play state is rejected unchanged rather than discarded")
	var malformed := legacy.duplicate(true)
	malformed["game_states"] = "malformed"
	var malformed_before := malformed.duplicate(true)
	result = app.generator._prepare_legacy_tutorial_layer_for_cycle(run, malformed, flat)
	_check(not bool(result.get("ok", true)) and malformed == malformed_before, "malformed stored play state cannot be treated as empty")
	var edited := legacy.duplicate(true)
	(edited["layout"] as Dictionary)["slot_binding_digest"] = "edited"
	var edited_before := edited.duplicate(true)
	result = app.generator._prepare_legacy_tutorial_layer_for_cycle(run, edited, flat)
	_check(not bool(result.get("ok", true)) and edited == edited_before, "edited slot proof is rejected unchanged")
	var target := run.current_environment.duplicate(true)
	var target_before := target.duplicate(true)
	result = app.generator._prepare_legacy_tutorial_layer_for_cycle(run, target, flat)
	_check(bool(result.get("ok", false)) and target == target_before, "configured Casino game availability is unchanged")
	var other := legacy.duplicate(true)
	other["game_ids"] = ["roulette"]
	var other_before := other.duplicate(true)
	result = app.generator._prepare_legacy_tutorial_layer_for_cycle(run, other, flat)
	_check(bool(result.get("ok", false)) and other == other_before, "unmatched historical game lists are not guessed or rewritten")

func _close() -> void:
	if is_instance_valid(app):
		if app.save_service != null: app.save_service.wait_for_async_save()
		app.queue_free()
		await _frames(2)

func _finish() -> void:
	var result := {"finding_id": "BTH-ROOM-PUNCHLINE-COLD-001", "checks": checks, "failures": failures, "facts": facts}
	var output := OS.get_environment("BTH_TARGET_OUTPUT")
	if output.is_absolute_path(): FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("PUNCHLINE_VENUE_CYCLE_AUTHORITY ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
