extends SceneTree

# Synthetic Sal progress uses normal generated Lounge installation. The real
# player reproduction is retained separately; no captured save belongs here.
const Controller := preload("res://scripts/ui/environment_interaction_controller.gd")
const Codec := preload("res://scripts/core/run_save_codec.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var library := ContentLibrary.new()
	library.load(false)
	var generator := RunGenerator.new(library)
	for index in range(1, 4):
		var seed_text := "LOUNGE-SAL-ADDRESS-%d" % index
		var run := RunState.new()
		run.start_new(seed_text, RunState.custom_challenge("lounge_sal_address", seed_text, {
			"scenario_pins": {"kitty_cat_lounge": "kitty_cat_lounge_bachelorette_storm"},
		}))
		run.begin_act(1)
		run.story_flags["chain06_sal_item_taken"] = true
		run.story_flags["chain06_world_anchors_seeded"] = true
		if index > 1: run.story_flags["chain06_sal_trail_one_done"] = true
		if index > 2: run.story_flags["chain06_sal_trail_two_done"] = true
		for target_index in range(1, 4):
			run.story_flags["chain06_sal_target_%d" % target_index] = "kitty_cat_lounge"
		var installed := generator.travel_environment_result(run, "kitty_cat_lounge", true)
		_check(bool(installed.get("ok", false)), "Address %d did not install normally: %s" % [index, str(installed.get("errors", []))])
		var suffix: String = ["one", "two", "three"][index - 1]
		var identity := "event:chain06_sal_trail_%s" % suffix
		_check(run.current_environment.get("event_ids", []).has(identity.trim_prefix("event:")), "Address %d fixture did not produce its normal event." % index)
		var proof := Controller._object_manifest_join_proof(run.current_environment)
		_check(bool(proof.get("ok", false)), "Address %d invalidated room authority: %s" % [index, str(proof.get("errors", []))])
		var bindings: Dictionary = run.current_environment.get("layout", {}).get("slot_bindings", {})
		var binding: Dictionary = bindings.get(identity, {})
		_check(binding.get("slot_id", "") == "event.sal_address_note", "Address %d lost its authored note slot." % index)
		_check(binding.get("placement_class", "") == "surface_item" and binding.get("presentation_mode", "") == "room", "Address %d changed its paper-note role." % index)
		var note_hit: Array = binding.get("slot", {}).get("hit_rect", [])
		var overlaps: Array = []
		if note_hit.size() == 4:
			var note_rect := Rect2(float(note_hit[0]), float(note_hit[1]), float(note_hit[2]), float(note_hit[3]))
			for other_id in bindings:
				if other_id == identity: continue
				var other_hit: Array = bindings[other_id].get("slot", {}).get("hit_rect", [])
				if other_hit.size() == 4 and note_rect.intersects(Rect2(float(other_hit[0]), float(other_hit[1]), float(other_hit[2]), float(other_hit[3]))):
					overlaps.append(other_id)
		_check(note_hit.size() == 4 and overlaps.is_empty(), "Address %d note target overlaps existing objects: %s" % [index, str(overlaps)])
		_check(not run.room_presentation_snapshot().is_empty(), "Address %d has no committed room publication." % index)
		if not bool(proof.get("ok", false)): continue
		var before := [run.bankroll, run.rng_state, run.game_clock_minutes, run.story_flags.duplicate(true)]
		var saved := Codec.pack_for_storage(Codec.encode(run.to_dict()))
		var restored := RunState.new()
		restored.from_dict(Codec.decode(Codec.unpack_from_storage(saved.get("packed", {}))))
		restored.scenario_finalize_installed_environment(library)
		var republished := restored.publish_room_presentation()
		_check(bool(republished.get("ok", false)), "Address %d lost room authority after save round trip: %s" % [index, str(republished.get("errors", []))])
		_check(before == [restored.bankroll, restored.rng_state, restored.game_clock_minutes, restored.story_flags], "Address %d save round trip changed money/RNG/clock/story." % index)
		_check(restored.current_environment.get("layout", {}).get("slot_bindings", {}).get(identity, {}) == binding, "Address %d moved its saved note." % index)
		var damaged := run.current_environment.duplicate(true)
		damaged.layout["slot_binding_digest"] = "0".repeat(64)
		_check(not bool(Controller._object_manifest_join_proof(damaged).get("ok", true)), "Address %d accepted a forged binding digest." % index)
	if failures.is_empty():
		print("LOUNGE_SAL_ADDRESS_PUBLICATION PASS addresses=3 strict_authority=true save_roundtrip=true tamper_rejected=true")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
