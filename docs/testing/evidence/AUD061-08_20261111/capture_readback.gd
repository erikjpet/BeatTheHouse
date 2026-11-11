extends SceneTree
const Codec := preload("res://scripts/core/run_save_codec.gd")
var checks:=0
var failures:Array[String]=[]
var facts:Array=[]
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func _init()->void:
	var args:=OS.get_cmdline_user_args()
	_check(args.size()==3,"Two captured primary files and exact expected commit supplied")
	if args.size()!=3:
		_finish()
		return
	for index in range(2):
		var path:=str(args[index]).replace("\\","/")
		var admitted:=path.to_lower().begins_with("e:/codexqa/bth/runs/") and path.contains("/evidence/capture-") and path.ends_with("-primary.json")
		_check(admitted,"Read only owned QA capture "+str(index))
		if not admitted:continue
		_check(FileAccess.file_exists(path),"Captured primary exists "+str(index))
		if not FileAccess.file_exists(path):continue
		var result_path:=path.get_base_dir()+"/result.json"
		var report:Variant=JSON.parse_string(FileAccess.get_file_as_string(result_path))
		_check(report is Dictionary and str(report.get("sha",""))==args[2],"Capture belongs to exact NEXT commit "+str(index))
		var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(value is Dictionary,"Captured envelope parses "+str(index))
		if not value is Dictionary:continue
		var storage:Dictionary=value.get("run_state",{})
		var unpacked:=Codec.unpack_from_storage(storage)
		_check(not unpacked.is_empty(),"Actual codec validates captured compressed bytes/hash "+str(index))
		if unpacked.is_empty():continue
		var decoded:=Codec.decode(unpacked)
		var sleep_entries:Array=[]
		for entry in decoded.get("story_log",[]):
			if entry is Dictionary and str(entry.get("type",""))=="home_sleep":
				sleep_entries.append({"hours":int(entry.get("hours",0)),"minutes":int(entry.get("minutes",0)),"clock":int(entry.get("game_clock_minutes",-1))})
		_check(sleep_entries.size()==1,"Actual ordinary Sleep action recorded exactly once "+str(index))
		var clock:=int(decoded.get("game_clock_minutes",-1))
		if sleep_entries.size()==1:
			var sleep:Dictionary=sleep_entries[0]
			_check(int(sleep["hours"])>=4 and int(sleep["hours"])<=8 and int(sleep["minutes"])==int(sleep["hours"])*60,"Recorded sleep is actual four-to-eight-hour action "+str(index))
			_check(clock>=int(sleep["clock"]) and int(sleep["clock"])>=960,"Current clock includes actual sleep "+str(index))
		facts.append({"file":path.get_file(),"sha256":FileAccess.get_sha256(path),"game_clock_minutes":clock,"bankroll":int(decoded.get("bankroll",-1)),"sleep_entries":sleep_entries})
	if facts.size()==2:
		_check(facts[0]["sha256"]==facts[1]["sha256"],"Reload restores exact hidden-boundary primary bytes")
		_check(facts[0]["game_clock_minutes"]==facts[1]["game_clock_minutes"],"Reload preserves exact post-action clock")
	_finish()
func _finish()->void:
	print("AUD061_08_WEB_CAPTURE_READBACK "+JSON.stringify({"checks":checks,"failures":failures,"facts":facts,"scope":"Read-only current-candidate QA byte captures, actual production codec validation/decode. No profile migration, save write, schema/version check or game state override; emits only requested action/clock/wallet/hash facts."}))
	quit(0 if failures.is_empty() else 1)
