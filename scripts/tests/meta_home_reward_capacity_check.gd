extends SceneTree

const Controller := preload("res://scripts/ui/meta_session_controller.gd")
const Meta := preload("res://scripts/core/meta_collection_service.gd")
const Library := preload("res://scripts/core/content_library.gd")
const State := preload("res://scripts/core/run_state.gd")
const Binder := preload("res://scripts/core/environment_slot_binder.gd")

var failures: Array[String] = []
var checks := 0
var cases: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _run() -> void:
	var library := Library.new()
	library.load(false)
	var private_path := OS.get_environment(Meta.STORE_PATH_ENV)
	for tier in ["back_alley", "motel_room", "apartment", "house"]:
		for count in [0, 1, 2, 3, 4, 10]:
			var label := "%s/%d" % [tier, count]
			OS.set_environment(Meta.STORE_PATH_ENV, private_path + "." + label.replace("/", "-"))
			var meta := Meta.new()
			meta.load()
			meta._store["housing_tier"] = tier # Synthetic housing fixture, not a purchase.
			for index in range(count): meta.grant_bag(9012, "reward-%d" % index)
			var controller := Controller.new()
			controller.configure(library, meta)
			var run := State.new()
			run.start_new("META-HOME")
			var environment: Dictionary = controller.build_environment_result("home", run).get("environment", {})
			run.current_environment = environment
			var before := JSON.stringify(meta.snapshot())
			var objects := controller.interactable_object_view_list("home", run, "", "", "")
			var ids: Array = []
			var direct_bags: Array = []
			for object in objects:
				var object_id := str(object.get("object_id", ""))
				ids.append(object_id)
				if object_id.begins_with("meta_bag:"): direct_bags.append(object_id)
			_expect(not objects.is_empty() and ids.has("travel:leave") and ids.has("meta_upgrade:home"), label + " retains Home controls")
			_expect(ids.has("meta_container:meta_bag_01"), label + " retains collection Bag")
			_expect(count == 0 or ids.has("meta_bags:all") or not direct_bags.is_empty(), label + " exposes reward or Bag Shelf")
			_expect(controller.unopened_bag_rows().size() == count, label + " browser retains every unopened reward")
			_expect(JSON.stringify(meta.snapshot()) == before, label + " projection preserves collection and meta RNG")
			if tier == "back_alley" and count > 1:
				_expect(ids.has("meta_bags:all") and direct_bags.is_empty(), label + " aggregates into one authored surface slot")
			if count == 2:
				_expect(meta.save() == OK, label + " copied profile saves")
				var cold := Meta.new()
				cold.load()
				controller.configure(library, cold)
				_expect(controller.interactable_object_view_list("home", run, "", "", "").size() == objects.size(), label + " cold profile retains controls")
				var bag_id := int(cold.unopened_bags()[0].get("instance_id", 0))
				var opened := cold.open_bag(bag_id)
				var after_open := JSON.stringify(cold.snapshot())
				_expect(bool(opened.get("ok", false)) and cold.unopened_bag_count() == 1, label + " one reward opens exactly once")
				_expect(not bool(cold.open_bag(bag_id).get("ok", true)) and JSON.stringify(cold.snapshot()) == after_open, label + " repeated Open preserves item and RNG")
				_expect(not controller.interactable_object_view_list("home", run, "", "", "").is_empty(), label + " opening leaves Home usable")
			# Strict authority is retained; grouping cannot bless a bad envelope.
			controller.invalidate_cache()
			run.current_environment["layout"]["slot_binding_digest"] = "invalid"
			_expect(controller.interactable_object_view_list("home", run, "", "", "").is_empty(), label + " rejects tampered authority")
			cases.append({"housing": tier, "bags": count, "visible_objects": objects.size(), "shelf": ids.has("meta_bags:all")})
	OS.set_environment(Meta.STORE_PATH_ENV, private_path)
	var report := {"checks": checks, "failures": failures, "cases": cases, "fidelity": "Synthetic native housing/reward-count matrix using production controller and strict binder; profile save/cold load and one-time bag opening. No player saves altered."}
	var f := FileAccess.open(OS.get_environment("BTH_TARGET_OUTPUT"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("META_HOME_REWARD_CAPACITY checks=", checks, " failures=", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
