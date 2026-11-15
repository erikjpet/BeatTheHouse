extends SceneTree
const Main = preload("res://scenes/main.tscn")
var failures: Array[String] = []
var checks := 0
func _init(): call_deferred("go")
func check(ok: bool, label: String):
 checks += 1
 if not ok: failures.append(label)
func go():
 var app = Main.instantiate()
 root.add_child(app)
 for i in range(4): await process_frame
 app.call("open_environment_test_menu")
 var first: Dictionary = app.call("start_environment_test_session")
 check(first.get("ok",false), "First public Practice spawn succeeds")
 var old_id = app.get("run_state").get_instance_id()
 app.call("_show_environment_action_acknowledgement", "Synthetic previous room result")
 app.call("open_environment_test_menu")
 var second: Dictionary = app.call("start_environment_test_session")
 check(second.get("ok",false), "Second public Practice spawn succeeds")
 check(old_id != app.get("run_state").get_instance_id(), "Second spawn creates new RunState")
 check(app.get("immediate_environment_acknowledgement") == "", "New Practice clears old acknowledgement")
 check(not str(app.call("_environment_result_feedback_view").get("message", "")).contains("Synthetic previous room result"), "Feedback view does not present previous room result")
 check(app.get("last_game_result").is_empty(), "New Practice clears game result")
 app.call("_show_environment_action_acknowledgement", "Preserve current room result")
 var current_id = app.get("run_state").get_instance_id()
 var room_before: Dictionary = app.get("run_state").current_environment.duplicate(true)
 var option: OptionButton = app.get("environment_test_archetype_option")
 app.call("_environment_test_add_option",option,"Invalid synthetic archetype","__invalid_practice_feedback_probe")
 option.select(option.item_count-1)
 var failed: Dictionary = app.call("start_environment_test_session")
 check(not failed.get("ok",true), "Invalid generation fails")
 check(current_id == app.get("run_state").get_instance_id(), "Failed spawn preserves RunState")
 check(room_before == app.get("run_state").current_environment, "Failed spawn preserves room")
 check(app.get("immediate_environment_acknowledgement") == "Preserve current room result", "Failed spawn preserves current acknowledgement")
 print("PRACTICE_FEEDBACK "+JSON.stringify({"checks":checks,"failures":failures,"rejection":failed}))
 app.queue_free()
 await process_frame
 quit(0 if failures.is_empty() else 1)
