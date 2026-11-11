extends SceneTree
const Codec := preload("res://scripts/core/run_save_codec.gd")
const Numeric := preload("res://scripts/core/storage_numeric_json.gd")
func _init():
 var base := "E:/CodexQA/BTH/runs/aud061-aud17-native-private-money-controls-20261111/"
 var raw := FileAccess.get_file_as_string(base+"save_dir/distribution/saves/count_money_prospective.json")
 var parsed := Numeric.parse(Codec.preserve_blackjack_ledger_integer_tokens(raw))
 var actual: Dictionary=Codec.decode(Codec.unpack_from_storage(parsed.get("data",{}).get("run_state",{})))
 var ref=JSON.parse_string(FileAccess.get_file_as_string(base+"appdata/Godot/app_userdata/Beat the House/count-money-expected.json"))
 if not ref is Dictionary or not actual.has("current_environment"):
  print("COUNT_EXPECTATION_DIAGNOSTIC missing current QA input");quit(2);return
 var expected: Dictionary=ref.get("snapshot",{})
 var a: float=actual.get("current_environment",{}).get("layout",{}).get("object_rects",{}).get("home_container:trunk_01",{}).get("h",0)
 var b: float=expected.get("current_environment",{}).get("layout",{}).get("object_rects",{}).get("home_container:trunk_01",{}).get("h",0)
 var protected: Dictionary={}
 for key in ["bankroll","grand_casino_chips","rng_state","run_status","seed_text"]:
  protected[key]={"actual":actual.get(key),"expected":expected.get(key),"same_value":actual.get(key)==expected.get(key)}
 print("COUNT_EXPECTATION_DIAGNOSTIC "+JSON.stringify({"scope":"Read-only selected leaf and financial/identity fields from this run's own exact-source QA save/ordinary-JSON expectation; not a full loss diagnosis","path":"/current_environment/layout/object_rects/home_container:trunk_01/h","actual_17_digits":"%.17f"%a,"expected_17_digits":"%.17f"%b,"actual_bits":PackedFloat64Array([a]).to_byte_array().hex_encode(),"expected_bits":PackedFloat64Array([b]).to_byte_array().hex_encode(),"absolute_delta":abs(a-b),"actual_equals_64_over_430":a==64.0/430.0,"protected":protected,"full_snapshot_test_still_failed":true}))
 quit(0)
