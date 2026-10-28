extends SceneTree
const Host := preload("res://scripts/ui/foundation_main.gd")
var checks := 0
var failures:Array[String]=[]

func _initialize()->void:
	var app:=Host.new()
	app.library=ContentLibrary.new()
	app.library.load()
	var event_id:="traveler_rumor"
	# Use an actual catalog definition, without resolving it or generating rumors.
	for definition in app.library.events:
		if str(definition.get("display_name","")).contains("Word from Across Town"):
			event_id=str(definition.get("id"));break
	var original:={"type":"event","event_id":event_id}
	var copy:=original.duplicate(true)
	var title:=str(app.library.event(event_id).get("display_name",""))
	_check(not title.is_empty(),"known rumor definition available")
	_check(app._story_entry_label(original)=="Event: "+title,"legacy absent-message event uses readable catalog title")
	_check(original==copy,"label projection does not rewrite historical record")
	_check(app._story_entry_label({"type":"event","event_id":event_id,"message":"The actual stored clue."})=="The actual stored clue.","explicit historical message remains authoritative")
	_check(app._story_entry_label({"type":"event","id":event_id})=="Event: "+title,"legacy id key resolves")
	_check(not app._story_entry_label({"type":"event","event_id":"unknown_rumor_id"}).contains("unknown_rumor_id"),"unknown event falls back to humanized label")
	_check(app._story_entry_label(JSON.parse_string(JSON.stringify(original)))==app._story_entry_label(original),"JSON cold record label stable")
	_check(app._story_entry_label({"type":"item_purchase","item_name":"Roadside Map"})=="Bought Roadside Map","unrelated story labels unchanged")
	app.free()
	print("RESTORED_EVENT_LABEL checks=",checks," failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func _check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures.append(message)
