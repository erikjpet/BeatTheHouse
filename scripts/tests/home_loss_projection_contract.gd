extends SceneTree

const ContentLibraryScript := preload("res://scripts/core/content_library.gd")
const RunStateScript := preload("res://scripts/core/run_state.gd")
const EnvironmentInstanceScript := preload("res://scripts/core/environment_instance.gd")
const SaveCodecScript := preload("res://scripts/core/run_save_codec.gd")
const WorldMapScript := preload("res://scripts/core/world_map.gd")

var failures: Array[String] = []
var library: Variant


func _init() -> void:
	library = ContentLibraryScript.new()
	library.load(true)
	_check_loss("motel_room", {"type": "stay", "prepaid_days": 1}, "stay_expired")
	_check_loss("apartment", {"type": "rent", "first_due_in_days": 0, "grace_days": 0}, "evicted")
	_check_no_loss()
	_check_away_loss()
	if failures.is_empty():
		print("HOME_LOSS_PROJECTION PASS sleep_expiry=true rent_eviction=true native_codec_restore=true storage_rejected=true controls=true")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _fixture(archetype_id: String, tenure: Dictionary) -> RunState:
	var run := RunStateScript.new()
	var seed_text := "HOME-LOSS-PROJECTION-" + archetype_id
	var config := RunStateScript.standard_challenge(seed_text)
	config["modifiers"] = {"home_archetype_id": archetype_id}
	run.start_new(seed_text, config)
	run.game_clock_minutes = 1430
	var archetype: Dictionary = library.environment_archetype(archetype_id)
	run.initialize_home_from_profile(archetype, archetype_id, {"tenure": tenure})
	var environment := EnvironmentInstanceScript.from_archetype(archetype, 0, run.create_rng("home_loss_fixture"), library).to_dict()
	environment["world_node_id"] = archetype_id
	environment["home_lost"] = false
	run.current_environment = environment
	# Use the normal full topology so restored traveler schedules never fall back
	# to placing every town traveler at a synthetic one-node home.
	run.world_map = WorldMapScript.new(library).build(run, run.create_rng("home_loss_world"))
	run.town_state.living_world.configure_world(run.world_map)
	run.enter_world_node(archetype_id, environment)
	for item_id in ["bag", "marked_cards", "lucky_bar_napkin"]:
		_expect(not library.item(item_id).is_empty(), "Fixture item exists in the current catalog: " + item_id)
	run.inventory = ["bag", "marked_cards", "lucky_bar_napkin"]
	var placement := run.place_home_container("bag", "Test Bag", 3)
	_expect(bool(placement.get("ok", false)), "Normal home container placement succeeds.")
	var storage := run.transfer_item_to_home_container(str(placement.get("container_id", "")), "marked_cards")
	_expect(bool(storage.get("ok", false)), "Normal storage transfer succeeds.")
	_expect(run.is_current_home_environment() and run.current_home_containers().size() == 1, "Fixture is the active physical home with one container.")
	return run


func _check_loss(archetype_id: String, tenure: Dictionary, reason: String) -> void:
	var run := _fixture(archetype_id, tenure)
	var carried := run.inventory.duplicate()
	var before_cash := run.bankroll
	var container_id := str(run.current_home_containers()[0].get("id", ""))
	var slept := run.sleep_at_home()
	_expect(bool(slept.get("ok", false)) and run.game_day() == 2, "%s sleep crosses the ordinary midnight boundary: %s" % [archetype_id, JSON.stringify(slept)])
	_expect(not run.home_is_active() and str(run.home_state.get("lost_reason", "")) == reason, "%s loses home through its normal tenure producer." % archetype_id)
	_check_empty_lost_home(run, archetype_id)
	_expect(run.inventory == carried and run.bankroll == before_cash, "Loss destroys stored items without returning them or charging cash.")
	var before_second_loss := run.to_dict()
	_expect(not bool(run.lose_home(reason).get("ok", false)) and run.to_dict() == before_second_loss, "Repeated home loss is inert.")
	# Native data serialization and restore, not an original-player save or UI Continue.
	var restored := RunStateScript.new()
	var encoded := SaveCodecScript.encode(run.to_dict())
	restored.from_dict(SaveCodecScript.decode(bytes_to_var(var_to_bytes(encoded))))
	# Match Continue: rebuild derived geometry with the current trusted catalog.
	restored.reconcile_current_environment_object_manifest()
	restored.current_environment["layout"] = EnvironmentInstanceScript.ensure_generated_layout(restored.current_environment, library)
	var publication := restored.prepare_current_environment_object_membership_for_publication()
	_expect(bool(publication.get("ok", false)), "Restored home crosses the normal room-publication boundary: %s" % JSON.stringify(publication.get("errors", [])))
	_check_empty_lost_home(restored, "restored " + archetype_id)
	_expect(restored.inventory == carried and restored.bankroll == before_cash, "Serialized restore preserves carried ownership and cash.")
	_expect(not bool(restored.transfer_item_from_home_container(container_id, "marked_cards").get("ok", false)), "Lost storage cannot be retrieved after restore.")
	_expect(bool(WorldMapScript.node_by_id(restored.world_map, archetype_id).get("home_lost", false)), "Lost home remains inaccessible on the world map.")


func _check_empty_lost_home(run: RunState, label: String) -> void:
	_expect(bool(run.current_environment.get("home_lost", false)), label + " marks the current room lost.")
	_expect(run.current_home_containers().is_empty(), label + " removes stored container data.")
	var home_node_id := str(run.home_state.get("home_node_id", ""))
	var stored: Dictionary = WorldMapScript.node_by_id(run.world_map, home_node_id).get("environment", {})
	_expect((stored.get("home_containers", []) as Array).is_empty(), label + " removes containers from the stored world room.")
	_expect(not WorldMapScript.travel_target_ids(run.world_map, "corner_store").has(home_node_id), label + " excludes the lost home from reentry routes.")
	for row in EnvironmentInstanceScript.active_object_manifest_rows(run.current_environment):
		_expect(not str(row.get("object_id", "")).begins_with("home_container:"), label + " removes physical home-container manifest rows.")
	_expect(bool(run.publish_room_presentation().get("ok", false)), label + " retains valid room authority.")


func _check_no_loss() -> void:
	var run := _fixture("motel_room", {"type": "stay", "prepaid_days": 3})
	var containers := run.current_home_containers()
	_expect(bool(run.sleep_at_home().get("ok", false)) and run.home_is_active(), "A paid-up home survives sleep.")
	_expect(run.current_home_containers() == containers and not bool(run.current_environment.get("home_lost", false)), "Non-loss preserves stored containers and items.")


func _check_away_loss() -> void:
	var run := _fixture("motel_room", {"type": "stay", "prepaid_days": 1})
	run.current_environment = EnvironmentInstanceScript.from_archetype(library.environment_archetype("corner_store"), 0, run.create_rng("away_fixture"), library).to_dict()
	var before_environment := var_to_bytes(run.current_environment)
	_expect(bool(run.lose_home("stay_expired").get("ok", false)), "Home can expire while away.")
	_expect(var_to_bytes(run.current_environment) == before_environment, "Losing home while away does not clear another room.")
	_expect(bool(WorldMapScript.node_by_id(run.world_map, "motel_room").get("home_lost", false)), "Away loss marks the home world node lost.")
	_expect((WorldMapScript.node_by_id(run.world_map, "motel_room").get("environment", {}) as Dictionary).is_empty(), "Away loss clears the stored home environment.")


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
