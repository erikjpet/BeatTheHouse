extends "res://scripts/tests/terminal_meta_outcome_contract_check.gd"
func _paths() -> bool:
 owned_root=OS.get_environment("BTH_QA_RUN_DIR").replace("\\","/").simplify_path().trim_suffix("/")
 var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("BTH_QA_EVIDENCE_DIR").path_join("storage-manifest.json")))
 var paths: Dictionary = m.get("paths",{})
 if not _check(not OS.has_feature("web") and OS.get_cmdline_user_args().is_empty(),"Fixed native domain script, no process arguments"):return false
 if not _check(owned_root.begins_with("E:/CodexQA/BTH/runs/") and m.get("prepared",false) and str(paths.get("run_root","")).replace("\\","/")==owned_root,"Exact current storage-manifest admitted E root"):return false
 if not _check(original_meta_path.replace("\\","/")==str(paths.get("localappdata","")).replace("\\","/")+"/meta-collection.json","Exact current launcher Meta path"):return false
 if not _check(OS.get_environment("BTH_DISTRIBUTION_DATA_ROOT").replace("\\","/")==str(paths.get("save_dir","")).replace("\\","/")+"/distribution","Exact current launcher distribution path"):return false
 var cases_path: String=owned_root.path_join("cases")
 return _check(DirAccess.dir_exists_absolute(owned_root) and not DirAccess.dir_exists_absolute(cases_path) and not FileAccess.file_exists(cases_path),"No inherited domain case storage") and _check(DirAccess.make_dir_absolute(cases_path)==OK,"Fresh case parent created nonrecursively")
