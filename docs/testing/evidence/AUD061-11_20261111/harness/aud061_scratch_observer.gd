extends SceneTree
const Codec := preload("res://scripts/core/run_save_codec.gd")
const Numeric := preload("res://scripts/core/storage_numeric_json.gd")
var differences: Array = []
func _init():
 var base := "E:/CodexQA/BTH/runs/aud061-aud11-resume11-final-20261111/"
 var expectations: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes(base+"evidence/resume11-expectations.bin"))
 var raw := FileAccess.get_file_as_string(base+"save_dir/distribution/saves/aud061_rc_scratch_tickets.json")
 var parsed: Dictionary = Numeric.parse(Codec.preserve_blackjack_ledger_integer_tokens(raw))
 var decoded: Dictionary = Codec.decode(Codec.unpack_from_storage(parsed.get("data",{}).get("run_state",{})))
 _diff(expectations.scratch_tickets.states,decoded.get("current_environment",{}).get("game_states",{}),"game_states")
 print("AUD061_SCRATCH_SNAPSHOT_DIFF "+JSON.stringify({"scope":"Read-only warm expectation versus final primary after the cold observer; current-build QA data only, no player files or writes","differences":differences}))
 quit(0)
func _diff(a,b,path: String):
 if differences.size()>30: return
 if a is Dictionary and b is Dictionary:
  var keys: Array = a.keys()
  for key in b.keys():
   if not keys.has(key): keys.append(key)
  for key in keys:
   if not a.has(key) or not b.has(key):differences.append({"path":path+"."+str(key),"before":a.get(key,"<absent>"),"after":b.get(key,"<absent>")})
   else:_diff(a[key],b[key],path+"."+str(key))
 elif a is Array and b is Array:
  if a.size()!=b.size(): differences.append({"path":path,"sizes":[a.size(),b.size()]})
  else:
   for i in range(a.size()): _diff(a[i],b[i],path+"["+str(i)+"]")
 elif a!=b: differences.append({"path":path,"before":a,"after":b})
