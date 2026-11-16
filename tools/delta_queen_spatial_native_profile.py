"""Exact Delta Queen V2 native policy; original six contexts and new QA are separate.

No runtime, source/art mutation, fallback or baseline migration. All29 room
members exclude the global index, which is authenticated as a separate control.
New observers are inert committed text, copied only as explicit QA overlays.
"""
import sys
sys.dont_write_bytecode = True

from collections import Counter
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat

from bar_spatial_candidate_check import decode_png
from grand_spatial_native_trial import plain, qualified_job, read_json, seal, sha

ROOM = ARCHETYPE = "delta_queen"
LAYER = ""
ART = "assets/art/environments/delta_queen/"
MANIFEST = "data/art/environments/delta_queen.json"
INDEX = "data/art/environments/index.json"
WORKSPACE_NAME = "BTH-ENV-SPATIAL-DELTATRIAL-20261116"
LEGACY = Path("E:/CodexQA/BTH/workspaces/BTH-ENVART-DELTA-TRIAL-20261115")
HISTORICAL_COMMIT = "6400dad73a1fdab0c63387683b2937495ac9c57c"
BASELINE_SEAL = "ca8ecad1e0d4205f4921765aabe099321509116196684c4e459c77a9d9fca41e"
INDEX_SHA = "11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24"
RAW_SHA = "a4b3b127e2194c5fe24a9636e1f608277ee9b5d9b0caac53a6c02a2a0176c61d"
IGNORE = b"# Non-active Delta Queen source/baseline/candidates; exclude from Godot discovery.\n"
IGNORE_SHA = "ce15181c032ba4cc0d94ab3e0e4598f93b1c08290cf661fff11212eff3a47369"
ASSEMBLY_EVIDENCE = Path("E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-DELTATRIAL-20261116-v2-01/evidence")
PROOF_NAME = "delta-queen-spatial-r1-assembly-v2.json"
APPROVAL = {
    "candidate_directory":"delta-queen-spatial-r1-assembled-v2",
    "package_sha256":"bcab84b0ebf42baf06d470ff9edfc847a11fe20f58ee0506461f8a1def61ace2",
    "background_sha256":"70eb1b890d1cca16dbdccd116331c5ed841f5df91236edbdc4b4a00977e2487b",
    "proof_sha256":"ecc192e029489fd6997adf60d937db557f94ef57f58266e3dc11df7814a1dd4d",
    "review_sha256":"c59dd3fbd32ed1f79e4f7118ac62082005c1dc1a9eac81bbc4243efb2ad37312",
    "recipe_filename":"assemble_delta_queen_spatial_candidate_v2.py",
    "recipe_sha256":"3075bf8de1ad78ca5005e2ab2c050723eb250eaa7d4d048cb7a9087fe31091e0",
    "job_sha256":"e1f225ce05a0ff0abd49c222afce20400c1a33811185810651f1519a8868fbf0"
}
V1_BG_SHA = "c1ce98996e9ba0fd86b102ccd075eef3dc15df49bc797b44d1bc55a92b432577"
ANIMATION_IDS = tuple([f"background_river_reflection_{i}" for i in range(7)]+
    [f"scene_life_river_reflection_{i}" for i in range(7)]+["delta_sign_pulse","dock_light_and_stem"]+
    [f"window_sparkle_{i}" for i in range(3)]+[f"floor_glint_{i}" for i in range(7)])
LOW_IDS = ANIMATION_IDS
COUNTERS = {"delta_right_table":(660,340,540,184)}
CATALOG = ("__none","delta_queen_wedding_charter","delta_queen_whale_aboard","delta_queen_fog_delay",
           "delta_queen_engine_trouble","delta_queen_captains_invitational")
CONTEXT_COUNTS = dict(zip(CATALOG,(15,19,21,20,21,20)))
CANONICAL_IMPORTS = {ART+"background.png.import":"9d0c2fab76f459ed47cfce65f38c25b825b7f6aa8022dc7c861d41d84284d550"}
FRESH_HELPERS = ("tools/envart_delta_spatial_probe.gd","tools/envart_delta_spatial_acceptance.gd")
OBSERVER_SOURCE_ROOT = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers")
OBSERVER_PROVENANCE = "review_artifacts/environment_art_sources/delta-queen-native-observers/provenance.json"
OBSERVER_PROVENANCE_SHA = "75a5a73aa1eea670a339f2ef65bf4a5c14cec19139081b5eae5e153ecfe207fb"
OBSERVER_SPECS = {
    "tools/envart_delta_spatial_probe.gd":{"artifact_relative":"review_artifacts/environment_art_sources/delta-queen-native-observers/envart_delta_spatial_probe.gd.txt",
        "sha256":"5ad32e0307053799de23df8aa17edba93ac5d008cbe00477f62322618f9b9b8d","bytes":18604},
    "tools/envart_delta_spatial_acceptance.gd":{"artifact_relative":"review_artifacts/environment_art_sources/delta-queen-native-observers/envart_delta_spatial_acceptance.gd.txt",
        "sha256":"ab0f7037115e0c7116970c2b843b138a9858b528c516157a35c44d1a42fbbc64","bytes":4571}
}
HELPERS = {
    "tools/envart_delta_preart_metadata.gd":"74f555bb6307abaaebb05b591e689877240801f3b66bf56c0049f69f38688f15",
    "tools/envart_delta_six_context_trace.gd":"ef5be47124bdf336a65e33fc278d18a67a86d436b7d3f97bf69fa5efe72e33e6",
    "tools/envart_delta_animation_probe.gd":"b83d37a87af482ebaebfba27622109cfbbb26f406ed655416cb53e7cb60f3cbc",
    "tools/envart_delta_animation_capture.gd":"feb3d8bf8f510a66bcca49f68de067f67f7be3c4c02b0e5a31592e0e911b80dd",
    "tools/environment_art_baseline_capture.gd":"89d7ae812bedd203f49830bf367863bced32d08cfcc5e0327ebaf4450317de8f",
    "tools/environment_layout_screenshots.gd":"eadf8f113aff55113ecf59e764503fd5bc2e4a64d00689573e0b56489b1a78e5",
    "tools/envart_delta_transition_trace.gd":"80525b8479173b55d7492b2cbcd55398d4f6daa5732666e1a4f1ab40c1949d65",
    "tools/envart_delta_full_transition_trace.gd":"569e0d729e0e172e61989f3f69f715cedfc7be88c3fcbcaf55a2d072e0832858",
    "tools/envart_delta_single_context.gd":"5a8742235911c59b2dd5b9d079fd8e6e72a6bafb14e8766d15bf75f872b581ab"
}
CORE_HELPERS = ("tools/envart_delta_six_context_trace.gd","tools/envart_delta_animation_probe.gd",
    "tools/envart_delta_animation_capture.gd","tools/environment_art_baseline_capture.gd","tools/environment_layout_screenshots.gd")
PROVENANCE = {
    "delta_source_identity.json":"59ca046dfd3414108d428c9b1470806001e02e7bd819ab500b597c590df7e572",
    "delta_capture_inputs.json":"e7cd9026b6bb4323f601e0ed8ea548d3c9c2468678a787b4903339a95b473d0f",
    "delta_trial_package_identity.json":"4313906aa900392a93c96616b814f74829cf40acb253f8e7d685e74dda32ae20",
    "delta_trial_adapter.py":"c45b5900941f90ee78e501960d7bc9d8c4fa907edfdc521d4b228706f092abf2",
    "tools/envart_delta_preart_metadata.gd.uid":"4370e9e7c14b056bb5cb1d0266bf0aa11b2cf65e485f7f4699e51717c3331f80",
    "tools/envart_delta_animation_probe.gd.uid":"1a8ee95878cafc06a39cf349d0e3f7898bae6a6229f2fbe68a992d08cf9674f2",
    "tools/envart_delta_animation_capture.gd.uid":"ddddc2f3a72553c576b151304f09e072c0839b67379dc1f6b3370d47a4b712af",
    "tools/environment_art_baseline_capture.gd.uid":"cd3b58fa80239aada2b1e9752d8d3fecda4a0c4d02aa2a9226e1156fd235b7c2",
    "tools/environment_layout_screenshots.gd.uid":"a4e9a7d6067be76eee07ef86e4fb1a37c5fb88096d2626a05ad83057f243cb35"
}
ORIGINAL_ACCEPTANCE = {
    "closing-departure":{"script":"scripts/tests/riverboat_closing_departure_check.gd",
        "sha256":"47c7ec0347a1468bd18b15d0590170f22b79fbbe357e855097f6b165528d03a7","checks":30,
        "marker":r"Riverboat closing departure checks: (\d+) failures=0",
        "scope":"Synthetic callback boundary, injected checked turns/save/map. No rendered Delta or real Web-save state."},
    "roads-ride":{"script":"scripts/tests/character_offers_roads_and_ride_check.gd",
        "sha256":"b7c2e16d8d7c667eecb4572cae83d00e842bbb7fcb91296d18b9c2ea3d188369","checks":61,
        "marker":r"CHARACTER OFFERS ROADS AND RIDE CHECK assertions=(\d+) failures=0 ok=true",
        "scope":"Model/callback Ox scouting at Delta and Rafi Bar-to-Grand ride; no rendered Delta closing ride or UI work."}
}
SOURCE_AUX = {
  ".gdignore": "ce15181c032ba4cc0d94ab3e0e4598f93b1c08290cf661fff11212eff3a47369",
  "assemble_delta_v1r3.py.txt": "29f8d1506549efc0d6d0187fdae0825c392aa8c989fcdde8e1c228fe26fe10d7",
  "delta-original-r3-source.png": "9f54bb4d2b79ea469087de9f62abbae5ba11384f897fd499d93a9515c634d1a3",
  "delta-original-title-source.png": "229105f65570187f7c15a66dfbef3120ed73db66a0a77697e9fec8e99027756b",
  "delta-queen-spatial-r1.png": "a4b3b127e2194c5fe24a9636e1f608277ee9b5d9b0caac53a6c02a2a0176c61d",
  "delta-queen-spatial-r1.png.b64": "a3ca51f10e452e1ad8ed6fa784fcf789e5cda4ff1bbe3c5df2e9678afc51a116",
  "prompt.txt": "7355122b0b57564d5ea4a7591ebeff4e589b1f8acb49ac6d0089c8b4c9a97511",
  "provenance.json": "42f59da09305dbae5144910c7eea35f52b5afe3a8033f2f887bf2265e5057cda"}

def require(value, message):
    if not value:
        raise ValueError(message)

def inventory_all(root, expected_names):
    """Inspect each ordinary member before descending; exact physical closure."""
    root = plain(root)
    require(root.is_dir(), "Ordinary source directory required")
    expected_names = set(expected_names)
    directories = {p.as_posix() for name in expected_names for p in PurePosixPath(name).parents if str(p) != "."}
    files, observed_dirs, pending = {}, set(), [root]
    while pending:
        directory = pending.pop()
        for item in sorted(directory.iterdir()):
            path = plain(item)
            name, mode = path.relative_to(root).as_posix(), path.lstat().st_mode
            if stat.S_ISDIR(mode):
                require(name in directories, "Unknown/empty source directory: " + name)
                observed_dirs.add(name)
                pending.append(path)
            else:
                require(stat.S_ISREG(mode) and name in expected_names, "Unknown/nonordinary source member: " + name)
                files[name] = sha(path)
    require(observed_dirs == directories and set(files) == expected_names, "Exact source file/directory membership differs")
    return files

def original_observers():
    for name, value in {**HELPERS, **PROVENANCE}.items():
        require(sha(plain(LEGACY / name)) == value, "Original Delta observer/provenance changed: " + name)
    return {**HELPERS, **PROVENANCE}


def baseline_auxiliary(workspace):
    path=plain(workspace/"source_baseline/.gdignore"); before=path.stat()
    require(stat.S_ISREG(before.st_mode) and before.st_size==len(IGNORE)==83 and path.read_bytes()==IGNORE and sha(path)==IGNORE_SHA,
            "Exact ordinary83-byte Delta baseline sentinel required")
    after=path.stat()
    require((before.st_size,before.st_mtime_ns,before.st_ino)==(after.st_size,after.st_mtime_ns,after.st_ino),"Baseline sentinel changed during read")
    return {".gdignore":{"path":str(path),"bytes":before.st_size,"sha256":IGNORE_SHA,"modified_ns":before.st_mtime_ns,
        "file_id":before.st_ino,"ordinary_regular_file":True,"inspection_access":"read-only","included_in_art_payload_seal":False,"copied_into_qa_source":False}}


def assembly_proof():
    path=ASSEMBLY_EVIDENCE/PROOF_NAME; job_path=ASSEMBLY_EVIDENCE/"job.json"
    require(sha(path)==APPROVAL["proof_sha256"] and sha(job_path)==APPROVAL["job_sha256"] and qualified_job(read_json(job_path)),
            "Exact closed/capped Delta V2 producer required")
    return read_json(path)


def baseline_state(workspace):
    original_observers(); auxiliary=baseline_auxiliary(workspace); proof=assembly_proof()
    expected=proof["baseline"]["files"]; root=plain(workspace/"source_baseline")
    require(len(expected)==29 and INDEX not in expected and seal(expected)==BASELINE_SEAL==proof["baseline"]["seal"] and
        proof["baseline"]["file_count"]==29 and plain(proof["baseline"]["path"])==root and proof["recipe_sha256"]==APPROVAL["recipe_sha256"],
        "Delta baseline must be room-only29; global index is a separate unchanged control")
    require(inventory_all(root,{*expected,".gdignore"})=={**expected,".gdignore":IGNORE_SHA} and baseline_auxiliary(workspace)==auxiliary,
            "Exact logical29 plus sole83B auxiliary required")
    return {"payload_files":expected,"payload_file_count":29,"payload_seal":BASELINE_SEAL,"auxiliary_files":auxiliary,
            "physical_file_count":30,"global_index_in_payload":False,"all_other_paths_rejected":True}


def baseline_files(workspace):
    return baseline_state(workspace)["payload_files"]


def source_contract(workspace,baseline):
    proof=assembly_proof(); root=plain(workspace/"candidate_sources")
    previous=dict(baseline); previous[ART+"background.png"]=V1_BG_SHA
    expected={**SOURCE_AUX,**{"delta-queen-spatial-r1-assembled-v1/"+name:digest for name,digest in previous.items()},
        **{APPROVAL["candidate_directory"]+"/"+name:digest for name,digest in proof["output"]["files"].items()}}
    require(inventory_all(root,expected)==expected and (root/".gdignore").read_bytes()==IGNORE,"Exact Delta raw/V1/V2 quarantine closure changed")
    return {"candidate_source_files":expected,"baseline_auxiliary":{"source_baseline/.gdignore":IGNORE_SHA},
        "quarantined_package_folders":["delta-queen-spatial-r1-assembled-v1",APPROVAL["candidate_directory"]],
        "V1_stays_rejected_immutable":True,"no_auxiliary_copied_to_qa_source":True}


def canonical_imports(root):
    require(sha(plain(root/INDEX))==INDEX_SHA,"Separate unchanged global art index differs")
    for name,digest in CANONICAL_IMPORTS.items():
        require(sha(plain(root/name))==digest,"Root must commit independently audited Delta background import; no auto-copy: "+name)


def candidate(root,workspace,proof_path,review_path,baseline):
    root,proof_path,review_path=map(plain,(root,proof_path,review_path)); proof,review=read_json(proof_path),read_json(review_path)
    require(root==workspace/"candidate_sources"/APPROVAL["candidate_directory"] and proof_path==ASSEMBLY_EVIDENCE/PROOF_NAME and
        sha(proof_path)==APPROVAL["proof_sha256"] and sha(review_path)==APPROVAL["review_sha256"] and
        review.get("schema")=="bth.delta_queen_spatial_static_review/v2" and review.get("decision")=="STATIC_GO_FOR_NATIVE_TRIAL" and
        review.get("native_trial_approved") is True and review.get("independent_reviewer")=="/root/audit_spatial_handoff" and
        review.get("package_29_file_sha256")==APPROVAL["package_sha256"] and review.get("logical_room_file_count")==29 and
        review["assembly_proof"]["sha256"]==APPROVAL["proof_sha256"] and review.get("recipe_sha256")==APPROVAL["recipe_sha256"] and
        plain(review["candidate_path"])==root,"Exact independently reviewed Delta V2 native-only candidate required")
    files=proof["output"]["files"]
    require(len(files)==29 and INDEX not in files and set(files)==set(baseline) and proof["baseline"]["files"]==baseline and
        inventory_all(root,files)==files and seal(files)==proof["output"]["seal"]==APPROVAL["package_sha256"] and
        files[ART+"background.png"]==APPROVAL["background_sha256"] and proof["recipe_sha256"]==APPROVAL["recipe_sha256"],
        "Exact room-only29 candidate/source binding changed")
    recipe=Path(__file__).with_name(APPROVAL["recipe_filename"]); job=read_json(proof_path.parent/"job.json")
    require(sha(recipe)==APPROVAL["recipe_sha256"] and qualified_job(job) and job["command"][1]=="-B" and
        plain(job["command"][2])==plain(recipe),"Exact executed Delta3075 recipe and closed producer required")
    require({name for name in files if files[name]!=baseline[name]}=={ART+"background.png"},"Only Delta background may change")
    spec=read_json(root/MANIFEST)
    require((root/MANIFEST).read_bytes()==(workspace/"source_baseline"/MANIFEST).read_bytes() and
        sha(OBSERVER_SOURCE_ROOT/INDEX)==INDEX_SHA and [r["id"] for r in spec["animations"]]==list(ANIMATION_IDS) and
        all(r.get("web_low_detail",True) is True for r in spec["animations"]) and
        Counter(r["type"] for r in spec["animations"])=={"frames":14,"mover":8,"pulse":4} and
        len({r["texture"] for r in spec["animations"]})==26 and
        spec["counters"]=={"delta_right_table":{"texture":"counters/delta_right_table.png"}},
        "Full immutable Delta26/default-low26/one-right-counter/separate-index contract changed")
    master=decode_png((root/(ART+"background.png")).read_bytes())
    original=decode_png((workspace/"source_baseline"/(ART+"background.png")).read_bytes())
    front=decode_png((root/(ART+"counters/delta_right_table.png")).read_bytes())
    require((master.width,master.height)==(1800,860) and set(master.rgba[3::4])=={255} and
        (front.width,front.height)==(540,184) and set(front.rgba[3::4])=={255},"Exact opaque Delta master/right counter required")
    for row in range(860):
        require(master.rgba[(row*1800+660)*4:(row+1)*1800*4]==original.rgba[(row*1800+660)*4:(row+1)*1800*4],
                "Unchanged right master x660 onward differs")
    for row in range(184):
        require(front.rgba[row*540*4:(row+1)*540*4]==master.rgba[((row+340)*1800+660)*4:((row+340)*1800+1200)*4],
                "Actual right foreground is not exact final master crop")
    return {"files":files,"package_sha256":APPROVAL["package_sha256"],"candidate_root":str(root),"review_sha256":APPROVAL["review_sha256"],
        "candidate_manifest_sha256":APPROVAL["proof_sha256"],"assembly_job_sha256":APPROVAL["job_sha256"],
        "approved_repair_recipe_sha256":APPROVAL["recipe_sha256"],"native_entries":26,"default_low_detail_entries":26,
        "unique_motion_pngs":26,"counters":COUNTERS,"right_counter_master_crop_exact":True,"global_index_separate_sha256":INDEX_SHA,
        "review":review,"production_art_written":False,"test_updated":False}


def literal_bindings(cfg):
    # Original observers already use res://delta_capture_inputs.json and
    # admitted evidence env/CLI paths. No historical source path needs changing.
    return {}


def transport_bytes(name, original, bindings):
    require(hashlib.sha256(original).hexdigest() == HELPERS[name], "Original GD bytes differ")
    active = original.replace(b"\r\n", b"\n")
    operations = []
    for before, after in bindings.get(name, {}).items():
        old, new = before.encode(), after.encode()
        # Match only a complete quoted string literal; never replace code,
        # guards, predicates, expected counts, case commands or data values.
        quoted = b'"' + old + b'"'
        require(active.count(quoted) == 1 and all(c not in new for c in (b'"', b"\n", b"\r", b"\\", b"\0")),
                "Exact sole safe quoted historical input required")
        active = active.replace(quoted, b'"' + new + b'"')
        operations.append({"original_literal":before, "active_literal":after, "occurrences":1})
    return active, operations

def no_findings(report):
    require(not report.get("findings") and not report.get("failures"), "Original native assertions reported findings/failures")

def report_contract(phase,report,*,source_files=0):
    no_findings(report)
    if phase=="contexts":
        require(report.get("findings")==[] and report["scenarios"]==list(CATALOG) and report["direct_catalog"]==list(CATALOG) and
            set(report["views"])==set(CATALOG) and report["checks"]==2*source_files+911,
            "Original Delta six-context2N+911 assertion/catalog contract changed")
        total=typed=0
        for scenario,count in CONTEXT_COUNTS.items():
            view=report["views"][scenario]; ids={row["id"] for row in view["actual_view"]["objects"]}
            selected=view["selected_label_evidence"]; paint=view["source_paint"]
            require(len(ids)==count==len(selected)==len(paint["objects"]) and {row["id"] for row in selected}==ids and
                {row["object"]["id"] for row in paint["objects"]}==ids and
                paint["geometry_equal"] is True and view["live_authority"]["ok"] is True,
                "Original Delta actual object/selected/typed/authority membership changed: "+scenario)
            total+=count; typed+=len(paint["objects"])*2
        require(total==116 and typed==232,"Exact116 initial object/selected occurrences and232 typed PNGs required")
        return {"initial_contexts":6,"object_occurrences":116,"selected_labels":116,"typed_PNGs":232,
                "checks":2*source_files+911,"current_source_files":source_files,"later_lifecycle_work_save_revisit":False}
    if phase=="motion":
        require(report.get("failures")==[] and report["checks"]==53 and [row["id"] for row in report["entries"]]==list(ANIMATION_IDS) and
            all(row["live_visible_change"] is True and row["reduce_motion_stable"] is True for row in report["entries"]),
            "Original Delta26/native53check fixed-clock motion/RM contract changed")
        return {"native_entries":26,"default_low_detail_entries":26,"checks":53,
                "original_observer_rendered_low_detail":False,"browser_acceptance":False}
    if phase in ("composite","composite-rm","low-detail","depth","placement"):
        require(report.get("schema")=="bth.delta_spatial_acceptance/v1" and report["mode"]==phase and report["context"]==ROOM and
            report["catalog"]==list(CATALOG) and set(report["cases"])==set(CATALOG) and
            report["all_six_contexts_captured"] is True and report["case_order"]==list(CATALOG) and report.get("findings")==[] and
            report["new_QA_acceptance"] is True and report["original_observers_modified"] is False and
            report["original_checks_are_separate"] is True and report["production_guard_relaxed"] is False and
            report["browser_execution"] is False and report["closing_ride_work_save_revisit_coverage"] is False and
            report["checks"]==sum(row["checks"] for row in report["cases"].values()),
            "New QA-only Delta acceptance must cover the exact six actual initial contexts")
        for scenario,row in report["cases"].items():
            require(row.get("schema")=="bth.delta_spatial_acceptance_case/v1" and row["case"]==scenario and row["mode"]==phase and
                    row.get("findings")==[] and row["production_snapshot_unchanged"] is True and row["processing_remained_active"] is True and
                    type(row["checks"]) is int and row["checks"]>0 and
                    row["browser_execution"] is False and row["actual_object_count"]==CONTEXT_COUNTS[scenario] and
                    row["counter"]["id"]=="delta_right_table" and row["counter"]["geometry_equal"] is True and
                    row["counter"]["dimensions_equal"] is True and row["counter"]["master_crop_RGBA_equal"] is True,
                    "Delta QA clone state/processing/finding differs: "+scenario)
            if phase in ("composite","composite-rm"):
                require([item["id"] for item in row["entries"]]==list(ANIMATION_IDS) and
                    all(item["identical_control_pixels"] and item["actual_objects_layout_equal"] and item["object_route_label_clocks_equal"] and
                        item["reduce_motion_composite_stable" if phase=="composite-rm" else "visible_composite_change"] and
                        item["actual_counter_retained"] is True and item["counter_id"]=="delta_right_table"
                        for item in row["entries"]),"Actual26-entry matched-clock composite/RM failed: "+scenario)
            elif phase=="placement":
                require(row["placement_enabled"] is True and row["geometry_equal"] is True and
                    row["no_saved_override_or_drag"] is True and row["clock_advanced_without_pointer"] is True and
                    row["redraw_advanced_without_pointer"] is True,"Actual Delta placement liveness/geometry failed")
            elif phase=="depth":
                require(row["counter_count"]==1 and row["counter_id"]=="delta_right_table" and row["geometry_equal"] is True and
                    row["actual_object_count"]==CONTEXT_COUNTS[scenario],"Actual Delta one-right-counter/objects depth failed")
            else:
                require([item["id"] for item in row["entries"]]==list(ANIMATION_IDS) and row["actual_low_detail_browser_execution"] is False and
                    all(item["web_low_detail"] is True and item["identical_control_pixels"] is True and
                        item["live_visible_change"] is True and item["reduce_motion_stable"] is True and
                        item["native_and_simulated_low_pixels_equal"] is True and item["renderer_present_low_detail_argument"] is True
                        for item in row["entries"]),
                    "Actual simulated low-detail26 pixel proof failed")
        return {"new_QA_probe":True,"mode":phase,"actual_initial_contexts":6,"native_entries":26,
                "scope":"New actual initial-context diagnostics; no later/work/UI-save or browser acceptance",
                "independent_actual_visual_review_still_required":True}
    raise ValueError("No exact Delta report contract: "+phase)


def original_log_contract(phase,log):
    spec=ORIGINAL_ACCEPTANCE[phase]
    matches=re.findall(spec["marker"],log)
    require(len(matches)==1 and int(matches[0])==spec["checks"],"Original Delta-related callback/model assertion marker/count differs")
    return {"original_script":spec["script"],"source_sha256":spec["sha256"],"checks":spec["checks"],
        "no_failures":True,"scope":spec["scope"],"actual_Delta_rendered_work_or_UI_save":False}


def observer_source_boundary(files):
    """Pure negative gate: QA GD/UIDs and external text stay outside051 source."""
    names = set(files)
    forbidden = {name for target in FRESH_HELPERS for name in (target,target+".uid")}
    require(not names.intersection(forbidden),
            "External Delta QA GD/UID targets must be absent from committed selected source: "+
            str(sorted(names.intersection(forbidden))))
    require(not any(name in names for name in (OBSERVER_PROVENANCE,
            *(row["artifact_relative"] for row in OBSERVER_SPECS.values()))),
            "Observer artifacts are external to051 selected prefixes")
    return {"all2_observer_GD_and_UID_targets_absent":True,
            "review_text_artifacts_outside_selected_archive":True,
            "production_921code_900GD_161toolsGD_guard_unchanged":True}


def observer_inputs():
    """Authenticate only committed inert artifacts; raw untracked GDs are unused."""
    require(OBSERVER_PROVENANCE_SHA != "0"*64, "WAITING_FOR_REVIEWED_DELTA_QA_OBSERVER_TEXTS")
    root = plain(OBSERVER_SOURCE_ROOT)
    path = plain(root/OBSERVER_PROVENANCE)
    require(sha(path) == OBSERVER_PROVENANCE_SHA,"Exact external observer provenance changed")
    record = read_json(path)
    require(record.get("schema") == "bth.delta_queen_external_qa_observers/v1" and
            record.get("observer_specs") == OBSERVER_SPECS and
            record.get("new_QA_acceptance") is True and record.get("original_observers_modified") is False and
            record.get("production_guard_relaxed") is False and record.get("ignore_workaround") is False,
            "External observer provenance scope/source bindings differ")
    values = {}
    for target,spec in OBSERVER_SPECS.items():
        relative = PurePosixPath(spec["artifact_relative"])
        require(relative.as_posix() == spec["artifact_relative"] and
                spec["artifact_relative"].startswith("review_artifacts/environment_art_sources/delta-queen-native-observers/") and
                relative.name == PurePosixPath(target).name+".txt" and relative.suffix == ".txt" and
                ".." not in relative.parts and not relative.is_absolute(),"Inert observer path escaped exact namespace")
        artifact = plain(root/spec["artifact_relative"])
        info = artifact.stat()
        require(stat.S_ISREG(info.st_mode) and info.st_size == spec["bytes"] <= 256*1024 and
                sha(artifact) == spec["sha256"],"External inert observer bytes differ: "+target)
        values[target] = {"artifact_path":str(artifact),"artifact_relative":spec["artifact_relative"],
                "sha256":spec["sha256"],"bytes":spec["bytes"],"source_kind":"EXTERNAL_QA_GD_TEXT_OVERLAY",
                "selected_Git_source":False,"production_or_export_source":False}
    require(set(values) == set(FRESH_HELPERS),"Exact two external QA observers required")
    return {"schema":"bth.delta_queen_qa_observer_overlay/v1","provenance_path":str(path),
            "provenance_sha256":OBSERVER_PROVENANCE_SHA,"observers":values,
            "raw_untracked_GD_files_read_or_required":False,"production_guards_relaxed":False}


def observer_bytes(inputs):
    require(observer_inputs() == inputs,"External observer custody changed after configuration")
    result = {}
    for target,row in inputs["observers"].items():
        data = plain(row["artifact_path"]).read_bytes()
        require(len(data) == row["bytes"] and hashlib.sha256(data).hexdigest() == row["sha256"],
                "External observer changed during bounded read: "+target)
        result[target] = data
    return result


def observer_git_binding(records,inputs):
    """Bind external artifact bytes to the exact closed full-Git-tree records."""
    payloads = {row["artifact_relative"]:data for target,data in observer_bytes(inputs).items()
                for row in (inputs["observers"][target],)}
    provenance = plain(inputs["provenance_path"]).read_bytes()
    require(hashlib.sha256(provenance).hexdigest() == OBSERVER_PROVENANCE_SHA,
            "Observer provenance changed during Git binding")
    payloads[OBSERVER_PROVENANCE] = provenance
    result = {}
    for name,data in payloads.items():
        expected = {"mode":"100644","oid":hashlib.sha1(b"blob "+str(len(data)).encode()+b"\0"+data).hexdigest(),
                    "bytes":len(data)}
        require(records.get(name) == expected,"External observer artifact is not exact committed Git blob: "+name)
        result[name] = {**expected,"sha256":hashlib.sha256(data).hexdigest()}
    return {"scope":"FULL_TREE_RECORD_BINDING_ONLY_EXTERNAL_PAYLOAD_NOT_ARCHIVED","files":result,
            "two_GD_texts_and_provenance_bound_to_current_commit":True,
            "raw_GD_targets_archived":False}
