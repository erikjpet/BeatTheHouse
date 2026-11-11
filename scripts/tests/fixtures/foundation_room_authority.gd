extends RefCounted
# An authored, isolated map for the foundation's synthetic model-only catalog.
# The old fixture predated required slot authority. It is not a shipping room;
# use the real manifest/binder/publication path, never stamp a successful seal.
const Placement := preload("res://scripts/core/environment_placement.gd")
const Binder := preload("res://scripts/core/environment_slot_binder.gd")
static func install(failures: Array) -> void:
 Placement.surface_map({"archetype_id":"bar"})
 var map := {
  "id":"fixture_environment","slot_schema_version":2,
  "fixed_slots":[],"event_slots":[],"scenario_slots":[],"exit_slots":[],
  "object_family_ids":{},"fixed_objects":[],"class_overrides":{},
  "fixed_object_slot_ids":{},"event_object_slot_ids":{},"exit_object_slot_ids":{},
  "walk_lanes":[],"actor_routes":[],"scenario_position_route_ids":{},
 }
 var rows := [
  ["game:fixture_game","fixed","surface_item",80.0,180.0],
  ["item:fixture_item","fixed","shop_item",200.0,180.0],
  ["shopkeeper:merchant","fixed","behind_counter_person",320.0,180.0],
  ["event:fixture_event","event","surface_item",440.0,180.0],
  ["service:fixture_service","event","surface_item",560.0,180.0],
  ["lender:fixture_lender","event","surface_item",680.0,180.0],
  ["travel:leave","exit","doorway",800.0,340.0],
  ["travel:fixture_route","exit","doorway",80.0,340.0],
 ]
 for index in range(rows.size()):
  var row:Array=rows[index]
  var identity:String=row[0];var family:String=row[1];var kind:String=row[2]
  var slot_id:="%s.fixture_%d"%[family,index]
  (map[family+"_slots"] as Array).append({"id":slot_id,"kind":family,"footprint_class":kind,"occupancy_required":false,"pos":[row[3],row[4]],"hit_rect":[float(row[3])-32.0,float(row[4])-64.0,64.0,64.0]})
  map[family+"_object_slot_ids"][identity]=slot_id
  map["object_family_ids"][identity]=family
  map["class_overrides"][identity]=kind
 var errors:=Binder._surface_map_errors(map)
 if not errors.is_empty():
  failures.append("Foundation synthetic slot map is invalid: "+JSON.stringify(errors));return
 Placement._surface_maps["fixture_environment"]=map
 Placement._effective_surface_maps.erase("fixture_environment::base")
 Placement._runtime_surface_maps.clear()
