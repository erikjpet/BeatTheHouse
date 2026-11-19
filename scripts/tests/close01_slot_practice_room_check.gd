extends SceneTree
const Main=preload("res://scenes/main.tscn")
const Placement=preload("res://scripts/core/environment_placement.gd")
const Binder=preload("res://scripts/core/environment_slot_binder.gd")
var failures:Array=[]
var checks:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label)
func _init():call_deferred("_run")
func _run():
 var ordinary={"archetype_id":"grand_casino"}
 var before=Binder.slot_map_digest(Placement.surface_map(ordinary))
 var app=Main.instantiate()
 app.set("continuous_environment_clock_enabled",false)
 root.add_child(app)
 await process_frame
 await process_frame
 var result:Dictionary=app.call("start_game_test_session","slot")
 check(bool(result.get("ok",false)),"Public Slot practice opens")
 var state:RunState=app.get("run_state")
 check(bool(state.validate_room_action_authority().get("ok",false)),"Six-cabinet room passes unchanged strict authority")
 # Inspect the practice room while it is installed. Leave now returns to the
 # CRT selector and deliberately parks no practice RunState on the host.
 var spatial:Dictionary=app.call("current_spatial_interaction_snapshot")
 var ids:Array=[]
 for value in spatial.get("objects",[]):ids.append(str(value.get("object_id","")))
 for index in range(6):
  var identity="game:slot" if index==0 else "game:slot:%d"%(index+1)
  check(ids.has(identity),"Room publishes "+identity)
 var after=Binder.slot_map_digest(Placement.surface_map(ordinary))
 check(before==after,"Practice leaves ordinary Grand Casino authority unchanged")
 check(before!=Binder.slot_map_digest(Placement.surface_map(state.current_environment)),"Practice has its own authority/cache identity")
 var saved:Dictionary=state.to_dict()
 var restored=RunState.new()
 restored.from_dict(saved)
 check(bool(restored.validate_room_action_authority(false).get("ok",false)),"Practice profile survives a host save-shaped round trip")
 var damaged=restored.current_environment.duplicate(true)
 damaged.layout.object_rects["game:slot"]["x"]+=0.01
 check(not bool(Binder.validate_base_layout_authority(damaged).get("ok",false)),"Edited practice geometry still fails strict validation")
 var practice_seed=state.seed_text
 var practice_digest=Binder.slot_map_digest(Placement.surface_map(state.current_environment))
 var selector:Control=app.get("game_test_menu")
 app.call("back_to_environment")
 for _frame in range(4):await process_frame
 check(selector!=null and selector.is_visible_in_tree(),"Slot Leave returns to the retained CRT selector")
 check(app.get("current_game")==null and app.get("run_state")==null,"CRT selector releases its isolated practice session")
 var repeated:Dictionary=app.call("start_game_test_session","slot")
 check(bool(repeated.get("ok",false)),"Retained CRT selector launches Slot again")
 var repeated_state:RunState=app.get("run_state")
 if repeated_state!=null:
  check(repeated_state!=state and repeated_state.seed_text==practice_seed,"Repeat launch uses a fresh practice RunState with the same seed")
  check(bool(repeated_state.validate_room_action_authority().get("ok",false)),"Repeat six-cabinet room retains strict authority")
  check(Binder.slot_map_digest(Placement.surface_map(repeated_state.current_environment))==practice_digest,"Repeat launch retains the same practice placement authority")
 app.call("back_to_environment")
 for _frame in range(4):await process_frame
 app.call("close_game_test_menu")
 check(str(app.get("current_screen"))=="START" and not bool(app.call("_crt_practice_active")),"Exit CRT returns the title origin")
 app.queue_free()
 await process_frame
 print("CLOSE01_SLOT_PRACTICE "+JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
