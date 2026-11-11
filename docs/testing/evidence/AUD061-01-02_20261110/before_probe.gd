extends SceneTree
const MainScene := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/core/durable_store.gd")
func _init() -> void:
 call_deferred("_run")
func _run() -> void:
 var path := "user://aud061_rollback.json"
 for spec in [[true, ".bak.rollback"], [true, ".rollback"], [false, ".bak.rollback"]]:
  for suffix in ["", ".bak", ".rollback", ".bak.rollback"]:
   DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
  if spec[0]:
   Store.write_json(path, {"generation": 1})
   Store.write_json(path, {"generation": 2})
  var stale := FileAccess.open(path + str(spec[1]), FileAccess.WRITE)
  stale.close()
  var result := Store.write_json(path, {"generation": 3})
  print("AUD061-01 BEFORE " + JSON.stringify({"valid_primary": spec[0], "stale": spec[1], "result": result, "stale_remains": FileAccess.file_exists(path + str(spec[1]))}))
 var app: Control = MainScene.instantiate()
 root.add_child(app)
 for i in range(4):
  await process_frame
 var started: bool = app.call("start_foundation_run", "AUD061-EXIT-REPRO", {}, true)
 var saved: bool = app.call("_autosave_foundation_run", "Baseline.", true)
 var run: RunState = app.get("run_state")
 run.change_bankroll(-1, true)
 Store.set_debug_force_write_failure(true)
 var result: bool = app.call("return_to_main_menu")
 var has_dialog := false
 for property in app.get_property_list():
  if property.name == "leave_without_saving_confirmation":
   has_dialog = true
 print("AUD061-02 BEFORE " + JSON.stringify({"started": started, "baseline_saved": saved, "main_menu_return": result, "run_retained": app.get("run_state") == run, "leave_dialog_exists": has_dialog, "last_error": app.get("save_service").last_save_outcome}))
 app.call("exit_game")
 app.notification(Control.NOTIFICATION_WM_CLOSE_REQUEST)
 print("AUD061-02 BEFORE Exit and native close returned; run still open=" + str(app.get("run_state") == run))
 Store.reset_debug_faults()
 app.get("save_service").wait_for_async_save()
 app.queue_free()
 for i in range(3):
  await process_frame
 quit(0)
