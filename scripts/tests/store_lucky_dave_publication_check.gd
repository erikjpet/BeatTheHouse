extends SceneTree

# A synthetic co-presence fixture tests authored capacity for the combination
# found in normal Web play. The captured-save production travel is separate.
const Controller := preload("res://scripts/ui/environment_interaction_controller.gd")
const Codec := preload("res://scripts/core/run_save_codec.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var library := ContentLibrary.new()
	library.load(false)
	var generator := RunGenerator.new(library)
	for stage in range(1):
		var seed_text := "STORE-LUCKY-DAVE-%d" % stage
		var run := RunState.new()
		run.start_new(seed_text, RunState.custom_challenge("store_lucky_dave", seed_text, {
			"scenario_pins": {"corner_store": "corner_store_delivery_day"},
		}))
		run.begin_act(1)
		run.set_world_map({"version": 3, "seed_text": seed_text, "start_node_id": "bar", "current_node_id": "bar", "nodes": [
			{"id": "bar", "archetype_id": "bar", "kind": "casino", "tier": 2, "state": "revealed", "seen": true, "environment": {}},
			{"id": "corner_store", "archetype_id": "corner_store", "kind": "shop", "tier": 2, "state": "revealed", "seen": true, "environment": {}},
		], "edges": [{"a": "bar", "b": "corner_store"}], "visited_path": ["bar"]})
		run.configure_town_world(run.world_map)
		var installed := generator.travel_environment_result(run, "corner_store", true)
		_check(bool(installed.get("ok", false)), "Stage%d normal installation failed: %s" % [stage, str(installed.get("errors", []))])
		var dave_id: String = ["chain06_dave_same_bus", "chain06_dave_last_stop", "chain06_dave_true_stop"][stage]
		var events: Array = run.current_environment.get("event_ids", [])
		# Pin conditional event membership, rather than depending on unrelated
		# recruitment and itinerary choices made by these synthetic seeds.
		for identity in ["recruitment_lucky", dave_id]:
			if not events.has(identity): events.append(identity)
		run.current_environment["event_ids"] = events
		run.current_environment["layout"] = EnvironmentInstanceScript.ensure_generated_layout(run.current_environment, library)
		run.scenario_finalize_installed_environment(library)
		var publication := run.publish_room_presentation()
		_check(bool(publication.get("ok", false)), "Stage%d co-presence failed publication: %s" % [stage, str(publication.get("errors", []))])
		var proof := Controller._object_manifest_join_proof(run.current_environment)
		_check(bool(proof.get("ok", false)), "Stage%d invalid room authority: %s" % [stage, str(proof.get("errors", []))])
		var bindings: Dictionary = run.current_environment.get("layout", {}).get("slot_bindings", {})
		var lucky: Dictionary = bindings.get("event:recruitment_lucky", {})
		_check(lucky.get("slot_id", "") == "event.lucky_recruitment", "Stage%d lost Lucky's reserved position." % stage)
		_check(bindings.get("event:" + dave_id, {}).get("slot_id", "") == "event.standing_person_1", "Stage%d moved Dave from the existing position." % stage)
		var hit: Array = lucky.get("slot", {}).get("hit_rect", [])
		var overlaps: Array = []
		if hit.size() == 4:
			var rect := Rect2(float(hit[0]), float(hit[1]), float(hit[2]), float(hit[3]))
			for identity in bindings:
				if identity == "event:recruitment_lucky": continue
				var other: Array = bindings[identity].get("slot", {}).get("hit_rect", [])
				if other.size() == 4 and rect.intersects(Rect2(float(other[0]), float(other[1]), float(other[2]), float(other[3]))): overlaps.append(identity)
		_check(hit.size() == 4 and overlaps.is_empty(), "Stage%d Lucky target overlaps: %s" % [stage, str(overlaps)])
		_check(not run.room_presentation_snapshot().is_empty(), "Stage%d has no committed publication." % stage)
		if not bool(proof.get("ok", false)): continue
		var before := [run.bankroll, run.rng_state, run.game_clock_minutes, run.story_flags.duplicate(true)]
		var packed := Codec.pack_for_storage(Codec.encode(run.to_dict()))
		var restored := RunState.new()
		restored.from_dict(Codec.decode(Codec.unpack_from_storage(packed.get("packed", {}))))
		restored.scenario_finalize_installed_environment(library)
		var republished := restored.publish_room_presentation()
		_check(bool(republished.get("ok", false)), "Stage%d failed restored publication: %s" % [stage, str(republished.get("errors", []))])
		_check(before == [restored.bankroll, restored.rng_state, restored.game_clock_minutes, restored.story_flags], "Stage%d save changed money/RNG/clock/story." % stage)
		_check(restored.current_environment.get("layout", {}).get("slot_bindings", {}).get("event:recruitment_lucky", {}) == lucky, "Stage%d moved Lucky after restoration." % stage)
		var damaged := run.current_environment.duplicate(true)
		damaged.layout["slot_binding_digest"] = "0".repeat(64)
		_check(not bool(Controller._object_manifest_join_proof(damaged).get("ok", true)), "Stage%d accepted forged binding authority." % stage)
	if failures.is_empty(): print("STORE_LUCKY_DAVE_PUBLICATION PASS checks=%d observed_co_presence=true strict_authority=true save_roundtrip=true tamper_rejected=true" % checks)
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
