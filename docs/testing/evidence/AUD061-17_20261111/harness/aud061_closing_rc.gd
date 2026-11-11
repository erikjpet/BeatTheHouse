extends "res://scripts/tests/travel_closing_fallback_public_check.gd"
func _private_roots() -> bool:
 private_root=OS.get_environment("BTH_QA_RUN_DIR").replace("\\","/").simplify_path()
 var m: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BTH_QA_EVIDENCE_DIR").path_join("storage-manifest.json")))
 if not _check(private_root.begins_with("E:/CodexQA/BTH/runs/") and m.get("prepared",false) and str(m.get("paths",{}).get("run_root","")).replace("\\","/")==private_root,"Exact current prepared E native root"):return false
 for key in ["APPDATA","LOCALAPPDATA","USERPROFILE","BTH_SAVE_DIR","BTH_DISTRIBUTION_DATA_ROOT","BTH_META_COLLECTION_PATH","BTH_PROFILE_INVENTORY_PATH","BTH_USER_SETTINGS_PATH","BTH_WORLD_REENTRY_ROOT","BTH_TARGET_OUTPUT"]:
  if not _check(OS.get_environment(key).replace("\\","/").simplify_path().begins_with(private_root+"/"),"Private admitted containment "+key):return false
 return _check(OS.get_environment("BTH_CAPTURED_FIXTURE").is_empty() and OS.get_environment("BTH_WEB_STORAGE_PROFILE").is_empty(),"Original player saves and profiles excluded")
