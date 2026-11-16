"""Kitty native source/art policy. No runtime, source mutation or fallback.

Original five-context assertions remain separate from new QA diagnostics.
Room-only30 excludes the separately authenticated unchanged global art index.
"""
import sys
sys.dont_write_bytecode = True
from collections import Counter
import hashlib
import json
import math
import struct
from pathlib import Path, PurePosixPath
import re
import stat
from bar_spatial_candidate_check import decode_png
from grand_spatial_native_trial import plain, qualified_job, read_json, seal, sha

ROOM = ARCHETYPE = "kitty_cat_lounge"
LAYER = ""
ART = "assets/art/environments/kitty_cat_lounge/"
MANIFEST = "data/art/environments/kitty_cat_lounge.json"
INDEX = "data/art/environments/index.json"
WORKSPACE_NAME = "BTH-ENV-SPATIAL-KITTYTRIAL2-20261116"
QA_WORKSPACE = Path("E:/CodexQA/BTH/workspaces") / WORKSPACE_NAME
RETAINED_INPUT_WORKSPACE = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-KITTYTRIAL-20261116")
LEGACY = Path("E:/CodexQA/BTH/workspaces/BTH-ENVART-KITTY-TRIAL-20261115")
HISTORICAL_COMMIT = "317f252b71fdd8cbe3c2f917d24fc651245190e2"
BASELINE_SEAL = "017faffa1f02256046add9e21c2aae3358e2b9508eec15cbac942050f449cfb2"
INDEX_SHA = "11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24"
RAW_SHA = "aa1078eab763def23c3d8a1b7232413384b5fcc26a86d7008866dcbf857526eb"
IGNORE = b"# Non-active Kitty Cat Lounge source and candidates; exclude from Godot discovery.\n"
IGNORE_SHA = "ee189cc57f37d8990ead0632bfec23a7c13835b94e1dd6c9c4dc3f30cd24bc12"
ASSEMBLY_EVIDENCE = Path("E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-KITTYTRIAL-20261116-v3-assemble01/evidence")
PROOF_NAME = "kitty-spatial-r1-assembly-v3.json"
APPROVAL = {
 "candidate_directory":"kitty-spatial-r1-assembled-v3",
 "package_sha256":"ba8a2c2ab3e812673cb9ad39b84c22a2a9769171282eb3ff7f357ba5f226d06e",
 "background_sha256":"bb1abe93ac133d59e9107c56efc51338af6f99603a9c181219a10a20a24d719b",
 "proof_sha256":"3974ce60951a6e2a8da8655982b20da22317603c6002bf6e16b4ca155b1768cf",
 "review_sha256":"ebb0acf227f15b39842af495a103e92ec9ac990f4887c936c9d7b593c82ceb6e",
 "recipe_filename":"assemble_kitty_spatial_candidate_v3.py",
 "recipe_sha256":"a38a18f1b07a6e42d2b3e1ac8a508dcb7f84bc11fe8160258dcc29ec5f52cf30",
 "job_sha256":"15b1a5cfee7b458e86895ceb16cba0d3a88632fcddfe513015cc0543545bc81e",
 "worker_log_sha256":"e1ff2a75caee330c1a9971db17d245de1090daae715604cfec381882ce45dc3c"
}
ANIMATION_IDS = tuple(["kitty_sign_pulse"]+[f"pink_air_{i}" for i in range(5)]+
 [f"cool_air_{i}" for i in range(5)]+[f"candle_light_{i}" for i in range(5)]+
 [f"warm_sparkle_{i}" for i in range(4)]+[f"floor_glint_{i}" for i in range(7)])
LOW_IDS = ANIMATION_IDS
COUNTERS = {"kitty_champagne_bar":(1168,380,536,96)}
CATALOG = ("__none","kitty_cat_lounge_amateur_night","kitty_cat_lounge_buyout",
 "kitty_cat_lounge_slow_night","kitty_cat_lounge_bachelorette_storm")
CONTEXT_COUNTS = dict(zip(CATALOG,(13,22,20,19,19)))
CANONICAL_IMPORTS = {ART+"background.png.import":"7ecc922f12cf6d819ede3fed493b8bece7a15c43ed523f12d67a3217ef30a54a"}
FRESH_HELPERS = ("tools/envart_kitty_spatial_probe.gd","tools/envart_kitty_spatial_acceptance.gd")
OBSERVER_SOURCE_ROOT = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers")
OBSERVER_PROVENANCE = "review_artifacts/environment_art_sources/kitty-native-observers/provenance.json"
OBSERVER_PROVENANCE_SHA = "c979fa2910b84ca7572a6587e1b8f12d760ab8530a4e1e3c608a87760745d1cd"
OBSERVER_SPECS = {
 "tools/envart_kitty_spatial_probe.gd":{"artifact_relative":"review_artifacts/environment_art_sources/kitty-native-observers/envart_kitty_spatial_probe.gd.txt",
 "sha256":"3fd7922e854e32b267f5dbb0aa9449546de3fcfb9ad2871ff3488e5f7a3501e4","bytes":25250},
 "tools/envart_kitty_spatial_acceptance.gd":{"artifact_relative":"review_artifacts/environment_art_sources/kitty-native-observers/envart_kitty_spatial_acceptance.gd.txt",
 "sha256":"5bd7e0ed72be61d8e7a971b720c509ec9c86cd579ed836733692be045d8e1f9e","bytes":4644}}
HELPERS = {
 "tools/envart_kitty_preart_metadata.gd":"51c191725faffeb4b9467e15dc41b4e0ace14d28d91d04214b952ba10c1c4a38",
 "tools/envart_kitty_animation_probe.gd":"ef4b1b7ab50340543c358bd8d27c383ae1c2c991f6c8015a72307f0de1c32da1",
 "tools/envart_kitty_animation_capture.gd":"b75c8b8f09b0ba6e77a69b9c9a9e6ecaa290582d457667b4d46f2a8c2235abfa",
 "tools/environment_art_baseline_capture.gd":"89d7ae812bedd203f49830bf367863bced32d08cfcc5e0327ebaf4450317de8f",
 "tools/environment_layout_screenshots.gd":"eadf8f113aff55113ecf59e764503fd5bc2e4a64d00689573e0b56489b1a78e5"}
CORE_HELPERS = tuple(HELPERS)
PROVENANCE = {
 "kitty_source_identity.json":"9cfed402bfda6722bd11bb9aacb6a43b84d4ab01f96e9c0386705ba11ff027f5",
 "kitty_capture_inputs.json":"00251d9136c19da5a84a1ef15d56872b98abc2e7fb86007060234a2a8018414c",
 "kitty_trial_package_identity.json":"1d592402e3ec5eeba0ffd72643428da0f053eee99549436a89f971498e38663d",
 "kitty_trial_adapter.py":"92dc41d3ed015f13e6ba6cededd3380c45ef9a1721a3e98bc23fc3e2fc3717aa",
 "tools/envart_kitty_preart_metadata.gd.uid":"aff92bf9b7a98128f6c8c8f7db7851baa4f39c5662a352bdd325d10983177b17",
 "tools/envart_kitty_animation_probe.gd.uid":"60e5e68a4cf7ec4cefde14c9aa0c36c2000713c8f90cf3c2d60037b4dee4027e",
 "tools/envart_kitty_animation_capture.gd.uid":"7d1aef6f555f064a9a1322ebde33042c1e856d1e0eb956ff8dd67c2cc6fded07",
 "tools/environment_art_baseline_capture.gd.uid":"cd3b58fa80239aada2b1e9752d8d3fecda4a0c4d02aa2a9226e1156fd235b7c2",
 "tools/environment_layout_screenshots.gd.uid":"a4e9a7d6067be76eee07ef86e4fb1a37c5fb88096d2626a05ad83057f243cb35"}
ORIGINAL_ACCEPTANCE = {}

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
        require(sha(plain(LEGACY / name)) == value, "Original Kitty observer/provenance changed: " + name)
    return {**HELPERS, **PROVENANCE}


def retained_input_root(workspace):
    """Authenticate the one original source/baseline/candidate campaign, read-only."""
    value = Path(workspace)
    require(value.is_absolute() and ".." not in value.parts, "Explicit ordinary retained input workspace required")
    value = plain(value)
    require(value == RETAINED_INPUT_WORKSPACE and value.is_dir(),
            "Only original KITTYTRIAL retained inputs are admitted")
    require({item.name for item in value.iterdir()} == {"raw_source","source_baseline","candidate_sources"},
            "Original completed/failed campaign root membership changed")
    for item in value.iterdir():
        require(plain(item).is_dir(), "Original campaign members must remain ordinary directories")
    return value

def workspace_roles(qa_workspace, input_workspace):
    """Exact disjoint fresh QA root and retained input root; never migrate either."""
    value = Path(qa_workspace)
    require(value.is_absolute() and ".." not in value.parts, "Explicit absolute fresh Kitty QA workspace required")
    qa = plain(value)
    retained = retained_input_root(input_workspace)
    require(qa == QA_WORKSPACE and qa.parent == Path("E:/CodexQA/BTH/workspaces") and
            qa != retained and not qa.is_relative_to(retained) and not retained.is_relative_to(qa),
            "Exact disjoint KITTYTRIAL2 QA and original KITTYTRIAL input roots required")
    if qa.exists():
        require(qa.is_dir() and {item.name for item in qa.iterdir()} <= {"qa_source"},
                "Unknown fresh-QA campaign root member")
        for item in qa.iterdir():
            require(plain(item).is_dir(), "Fresh QA root members must be ordinary directories")
    return {"qa_workspace": qa, "input_workspace": retained}

def baseline_auxiliary(workspace):
    workspace = retained_input_root(workspace)
    path=plain(workspace/"source_baseline/.gdignore"); before=path.stat()
    require(stat.S_ISREG(before.st_mode) and before.st_size==len(IGNORE)==83 and path.read_bytes()==IGNORE and sha(path)==IGNORE_SHA,
            "Exact ordinary83-byte Kitty baseline sentinel required")
    after=path.stat()
    require((before.st_size,before.st_mtime_ns,before.st_ino)==(after.st_size,after.st_mtime_ns,after.st_ino),"Baseline sentinel changed during read")
    return {".gdignore":{"path":str(path),"bytes":before.st_size,"sha256":IGNORE_SHA,"modified_ns":before.st_mtime_ns,
        "file_id":before.st_ino,"ordinary_regular_file":True,"inspection_access":"read-only","included_in_art_payload_seal":False,"copied_into_qa_source":False}}


def assembly_proof():
    path=ASSEMBLY_EVIDENCE/PROOF_NAME; job_path=ASSEMBLY_EVIDENCE/"job.json"
    require(sha(path)==APPROVAL["proof_sha256"] and sha(job_path)==APPROVAL["job_sha256"] and qualified_job(read_json(job_path)),
            "Exact closed/capped Kitty V2 producer required")
    return read_json(path)


def baseline_state(workspace):
    workspace = retained_input_root(workspace)
    original_observers(); auxiliary=baseline_auxiliary(workspace); proof=assembly_proof()
    expected=proof["baseline"]["files"]; root=plain(workspace/"source_baseline")
    require(len(expected)==30 and INDEX not in expected and seal(expected)==BASELINE_SEAL==proof["baseline"]["seal"] and
        proof["baseline"]["file_count"]==30 and plain(proof["baseline"]["path"])==root and proof["recipe_sha256"]==APPROVAL["recipe_sha256"],
        "Kitty baseline must be room-only30; global index is a separate unchanged control")
    require(inventory_all(root,{*expected,".gdignore"})=={**expected,".gdignore":IGNORE_SHA} and baseline_auxiliary(workspace)==auxiliary,
            "Exact logical30 plus sole83B auxiliary required")
    return {"payload_files":expected,"payload_file_count":30,"payload_seal":BASELINE_SEAL,"auxiliary_files":auxiliary,
            "physical_file_count":31,"global_index_in_payload":False,"all_other_paths_rejected":True}


def baseline_files(workspace):
    return baseline_state(workspace)["payload_files"]


def source_contract(workspace,baseline):
    proof=assembly_proof()
    expected={".gdignore":IGNORE_SHA,**{APPROVAL["candidate_directory"]+"/"+name:digest for name,digest in proof["output"]["files"].items()}}
    require(inventory_all(workspace/"candidate_sources",expected)==expected and
        (workspace/"candidate_sources/.gdignore").read_bytes()==IGNORE and
        inventory_all(workspace/"raw_source",{"kitty-spatial-r1.png"})=={"kitty-spatial-r1.png":RAW_SHA},
        "Exact Kitty retained raw/candidate/sentinel membership changed")
    return {"candidate_source_files":expected,"raw_source_files":{"kitty-spatial-r1.png":RAW_SHA},
        "baseline_auxiliary":{"source_baseline/.gdignore":IGNORE_SHA},"quarantined_package_folders":[APPROVAL["candidate_directory"]],
        "raw_decode_phase_remains_failed":True,"no_auxiliary_copied_to_qa_source":True}

def canonical_imports(root):
    require(sha(plain(root/INDEX))==INDEX_SHA,"Separate unchanged global art index differs")
    for name,digest in CANONICAL_IMPORTS.items():
        require(sha(plain(root/name))==digest,"Root must commit independently audited Kitty background import; no auto-copy: "+name)


def candidate(root,workspace,proof_path,review_path,baseline):
    root,proof_path,review_path=map(plain,(root,proof_path,review_path))
    proof,review=read_json(proof_path),read_json(review_path)
    require(root==workspace/"candidate_sources"/APPROVAL["candidate_directory"] and proof_path==ASSEMBLY_EVIDENCE/PROOF_NAME and
        sha(proof_path)==APPROVAL["proof_sha256"] and sha(review_path)==APPROVAL["review_sha256"] and
        review.get("schema")=="bth.kitty_spatial_static_review/v3" and review.get("decision")=="STATIC_GO_FOR_NATIVE_TRIAL" and
        review.get("native_trial_approved") is True and review.get("independent_reviewer")=="/root/bar_clearance_audit" and
        review.get("package_room30_sha256")==APPROVAL["package_sha256"] and review.get("logical_room_file_count")==30 and
        review["assembly_report"]["sha256"]==APPROVAL["proof_sha256"] and plain(review["candidate_path"])==root,
        "Exact independently reviewed Kitty V3 native-only candidate required")
    files=proof["output"]["files"]
    require(len(files)==30 and INDEX not in files and set(files)==set(baseline) and proof["baseline"]["files"]==baseline and
        inventory_all(root,files)==files and seal(files)==proof["output"]["seal"]==APPROVAL["package_sha256"] and
        files[ART+"background.png"]==APPROVAL["background_sha256"] and proof["recipe_sha256"]==APPROVAL["recipe_sha256"],
        "Exact room-only30 candidate/source binding changed")
    recipe=Path(__file__).with_name(APPROVAL["recipe_filename"])
    job=read_json(proof_path.parent/"job.json")
    require(sha(recipe)==APPROVAL["recipe_sha256"] and qualified_job(job) and job["command"][1]=="-B" and
        plain(job["command"][2])==plain(recipe) and sha(proof_path.parent/"worker.log")==APPROVAL["worker_log_sha256"],
        "Exact executed a38a Kitty recipe and closed producer required")
    require({name for name in files if files[name]!=baseline[name]}=={ART+"background.png"},"Only Kitty background may change")
    spec=read_json(root/MANIFEST)
    require((root/MANIFEST).read_bytes()==(workspace/"source_baseline"/MANIFEST).read_bytes() and
        sha(OBSERVER_SOURCE_ROOT/INDEX)==INDEX_SHA and [r["id"] for r in spec["animations"]]==list(ANIMATION_IDS) and
        all(r.get("web_low_detail",True) is True for r in spec["animations"]) and
        Counter(r["type"] for r in spec["animations"])=={"frames":5,"mover":17,"pulse":5} and
        len({r["texture"] for r in spec["animations"]})==27 and
        spec["counters"]=={"kitty_champagne_bar":{"texture":"counters/kitty_champagne_bar.png"}},
        "Full immutable Kitty27/default-low27/one-counter/separate-index contract changed")
    master=decode_png((root/(ART+"background.png")).read_bytes())
    original=decode_png((workspace/"source_baseline"/(ART+"background.png")).read_bytes())
    front=decode_png((root/(ART+"counters/kitty_champagne_bar.png")).read_bytes())
    require((master.width,master.height)==(1800,860) and set(master.rgba[3::4])=={255} and
        (front.width,front.height)==(536,96) and set(front.rgba[3::4])=={255},"Opaque Kitty master/counter required")
    require(master.rgba[476*1800*4:]==original.rgba[476*1800*4:],"All source floor rows476+ must remain exact")
    for row in range(96):
        require(front.rgba[row*536*4:(row+1)*536*4]==master.rgba[((row+380)*1800+1168)*4:((row+380)*1800+1704)*4],
            "Champagne counter is not exact final master crop")
    return {"files":files,"package_sha256":APPROVAL["package_sha256"],"candidate_root":str(root),"review_sha256":APPROVAL["review_sha256"],
        "candidate_manifest_sha256":APPROVAL["proof_sha256"],"assembly_job_sha256":APPROVAL["job_sha256"],
        "approved_repair_recipe_sha256":APPROVAL["recipe_sha256"],"native_entries":27,"default_low_detail_entries":27,
        "unique_motion_pngs":27,"counters":COUNTERS,"counter_master_crop_exact":True,"global_index_separate_sha256":INDEX_SHA,
        "review":review,"production_art_written":False,"test_updated":False}

def literal_bindings(cfg):
    # Original observers already use res://kitty_capture_inputs.json and
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


def check_clock_proof(proof):
    """Exact binary64 equality; JSON numeric fields remain diagnostics only.

    Actual helper-source and closed native Job qualification remain external.
    This function never changes clock values or treats serialized rounding as
    established causation of a historical failed run.
    """
    require(isinstance(proof, dict) and set(proof) == {"schema", "encoding", "native", "serialized",
        "native_values_equal_raw_replay", "legacy_cross_representation_equal", "json_numeric_values_are_diagnostics"} and
        proof.get("schema") == "bth.kitty_native_clock_proof/v1" and proof.get("encoding") == "IEEE754_BINARY64_LITTLE_ENDIAN" and
        proof.get("native_values_equal_raw_replay") is True and proof.get("json_numeric_values_are_diagnostics") is True and
        type(proof.get("legacy_cross_representation_equal")) is bool, "Exact Kitty native clock proof schema/flags required")
    native, serialized = proof["native"], proof["serialized"]
    require(isinstance(native, dict) and set(native) == {"expected", "a", "control", "b"} and
        isinstance(serialized, dict) and set(serialized) == {"a", "control", "b"}, "Exact expected/a/control/b clock records required")
    decoded = {}
    for frame, pair in native.items():
        require(isinstance(pair, dict) and set(pair) == {"object_clock", "route_clock"}, "Exact native object/route pair required")
        decoded[frame] = {}
        for clock, row in pair.items():
            require(isinstance(row, dict) and set(row) == {"value", "ieee754_hex_le"} and
                type(row["value"]) in (int, float) and math.isfinite(row["value"]) and
                isinstance(row["ieee754_hex_le"], str) and re.fullmatch(r"[0-9a-f]{16}", row["ieee754_hex_le"]),
                "Finite JSON diagnostic value and exact lower-case binary64 hex required")
            value = struct.unpack("<d", bytes.fromhex(row["ieee754_hex_le"]))[0]
            require(math.isfinite(value), "Native binary64 clock must be finite")
            decoded[frame][clock] = value
    for frame in ("a", "control", "b"):
        require(isinstance(serialized[frame], dict) and set(serialized[frame]) == {"object_clock", "route_clock"},
                "Exact serialized object/route pair required")
        for clock in ("object_clock", "route_clock"):
            require(type(serialized[frame][clock]) in (int, float) and math.isfinite(serialized[frame][clock]) and
                native[frame][clock]["ieee754_hex_le"] == native["expected"][clock]["ieee754_hex_le"] and
                decoded[frame][clock] == decoded["expected"][clock] and
                native[frame][clock]["value"] == native["expected"][clock]["value"] == serialized[frame][clock],
                "Actual native clocks must exactly equal raw replay and identical controls; JSON values are diagnostic")
    legacy = all(serialized["a"][clock] == decoded["expected"][clock] and
        serialized["b"][clock] == serialized["a"][clock] and serialized["control"][clock] == serialized["a"][clock]
        for clock in ("object_clock", "route_clock"))
    require(proof["legacy_cross_representation_equal"] is legacy, "Legacy cross-representation diagnostic contradicts actual paired values")
    return True


def report_contract(phase,report,*,source_files=0):
    no_findings(report)
    if phase=="contexts":
        require(report.get("findings")==[] and report["scenarios"]==list(CATALOG) and report["direct_catalog"]==list(CATALOG) and
            set(report["views"])==set(CATALOG) and report["checks"]==2*source_files+734,
            "Original Kitty five-context2N+734 assertion/catalog contract changed")
        total=typed=0
        for scenario,count in CONTEXT_COUNTS.items():
            view=report["views"][scenario]; ids={row["id"] for row in view["actual_view"]["objects"]}
            selected=view["selected_label_evidence"]; paint=view["source_paint"]
            require(len(ids)==count==len(selected)==len(paint["objects"]) and {row["id"] for row in selected}==ids and
                {row["object"]["id"] for row in paint["objects"]}==ids and
                paint["geometry_equal"] is True and view["live_authority"]["ok"] is True,
                "Original Kitty actual object/selected/typed/authority membership changed: "+scenario)
            total+=count; typed+=len(paint["objects"])*2
        require(total==93 and typed==186,"Exact93 initial object/selected occurrences and186 typed PNGs required")
        return {"initial_contexts":5,"object_occurrences":93,"selected_labels":93,"typed_PNGs":186,
                "checks":2*source_files+734,"current_source_files":source_files,"later_lifecycle_work_save_revisit":False}
    if phase=="motion":
        require(report.get("failures")==[] and report["checks"]==55 and [row["id"] for row in report["entries"]]==list(ANIMATION_IDS) and
            all(row["live_visible_change"] is True and row["reduce_motion_stable"] is True for row in report["entries"]),
            "Original Kitty27/native55check fixed-clock motion/RM contract changed")
        return {"native_entries":27,"default_low_detail_entries":27,"checks":55,
                "original_observer_rendered_low_detail":False,"browser_acceptance":False}
    if phase in ("composite","composite-rm","low-detail","depth","placement"):
        require(report.get("schema")=="bth.kitty_spatial_acceptance/v1" and report["mode"]==phase and report["context"]==ROOM and
            report["catalog"]==list(CATALOG) and set(report["cases"])==set(CATALOG) and
            report["all_five_contexts_captured"] is True and report["case_order"]==list(CATALOG) and report.get("findings")==[] and
            report["new_QA_acceptance"] is True and report["original_observers_modified"] is False and
            report["original_checks_are_separate"] is True and report["production_guard_relaxed"] is False and
            report["browser_execution"] is False and report["later_lifecycle_work_save_revisit_coverage"] is False and
            report["checks"]==sum(row["checks"] for row in report["cases"].values()),
            "New QA-only Kitty acceptance must cover the exact five actual initial contexts")
        for scenario,row in report["cases"].items():
            require(row.get("schema")=="bth.kitty_spatial_acceptance_case/v1" and row["case"]==scenario and row["mode"]==phase and
                    row.get("findings")==[] and row["production_snapshot_unchanged"] is True and row["processing_remained_active"] is True and
                    type(row["checks"]) is int and row["checks"]>0 and
                    row["browser_execution"] is False and row["actual_object_count"]==CONTEXT_COUNTS[scenario] and
                    row["counter"]["id"]=="kitty_champagne_bar" and row["counter"]["geometry_equal"] is True and
                    row["counter"]["dimensions_equal"] is True and row["counter"]["master_crop_RGBA_equal"] is True,
                    "Kitty QA clone state/processing/finding differs: "+scenario)
            binding=row["native_target_binding"]
            require(binding.get("source_api")=="PixelSceneCanvas._active_scene_objects" and
                binding["native_object_count"]==binding["expected_object_count"]==CONTEXT_COUNTS[scenario] and
                binding["actual_object_ids"]==row["actual_object_ids"] and len(set(binding["actual_object_ids"]))==CONTEXT_COUNTS[scenario] and
                all(binding.get(key) is True for key in ("all_objects_are_unique_native_dictionaries",
                    "all_position_and_size_are_native_Vector2","native_objects_equal_native_view","native_type_guard_before_json",
                    "serialized_objects_equal_replay")) and binding.get("serialized_objects_used_as_paint_target") is False,
                "Actual native typed Kitty target binding must precede JSON")
            if phase in ("composite","composite-rm"):
                for entry in row["entries"]:
                    check_clock_proof(entry.get("clock_proof"))
                require([item["id"] for item in row["entries"]]==list(ANIMATION_IDS) and
                    all(item["identical_control_pixels"] and item["actual_objects_layout_equal"] and item["object_route_label_clocks_equal"] and
                        item["reduce_motion_composite_stable" if phase=="composite-rm" else "visible_composite_change"] and
                        item["actual_counter_retained"] is True and item["counter_id"]=="kitty_champagne_bar"
                        for item in row["entries"]),"Actual27-entry matched-clock composite/RM failed: "+scenario)
            elif phase=="placement":
                require(row["placement_enabled"] is True and row["geometry_equal"] is True and
                    row["no_saved_override_or_drag"] is True and row["clock_advanced_without_pointer"] is True and
                    row["redraw_advanced_without_pointer"] is True,"Actual Kitty placement liveness/geometry failed")
            elif phase=="depth":
                require(row["depth_uses_native_typed_objects"] is True and row["counter_count"]==1 and row["counter_id"]=="kitty_champagne_bar" and row["geometry_equal"] is True and
                    row["actual_object_count"]==CONTEXT_COUNTS[scenario],"Actual Kitty one-right-counter/objects depth failed")
            else:
                require([item["id"] for item in row["entries"]]==list(ANIMATION_IDS) and row["actual_low_detail_browser_execution"] is False and
                    all(item["web_low_detail"] is True and item["identical_control_pixels"] is True and
                        item["live_visible_change"] is True and item["reduce_motion_stable"] is True and
                        item["native_and_simulated_low_pixels_equal"] is True and item["renderer_present_low_detail_argument"] is True
                        for item in row["entries"]),
                    "Actual simulated low-detail27 pixel proof failed")
        return {"new_QA_probe":True,"mode":phase,"actual_initial_contexts":5,"native_entries":27,
                "scope":"New actual initial-context diagnostics; no later/work/UI-save or browser acceptance",
                "independent_actual_visual_review_still_required":True}
    raise ValueError("No exact Kitty report contract: "+phase)


def original_log_contract(phase,log):
    raise ValueError("No unrelated model callback phase is claimed by Kitty source-art qualification")

def observer_source_boundary(files):
    """Pure negative gate: QA GD/UIDs and external text stay outside051 source."""
    names = set(files)
    forbidden = {name for target in FRESH_HELPERS for name in (target,target+".uid")}
    require(not names.intersection(forbidden),
            "External Kitty QA GD/UID targets must be absent from committed selected source: "+
            str(sorted(names.intersection(forbidden))))
    require(not any(name in names for name in (OBSERVER_PROVENANCE,
            *(row["artifact_relative"] for row in OBSERVER_SPECS.values()))),
            "Observer artifacts are external to051 selected prefixes")
    return {"all2_observer_GD_and_UID_targets_absent":True,
            "review_text_artifacts_outside_selected_archive":True,
            "production_921code_900GD_161toolsGD_guard_unchanged":True}


def observer_inputs():
    """Authenticate committed inert artifacts; no raw GD/UID is used."""
    root=plain(OBSERVER_SOURCE_ROOT); path=plain(root/OBSERVER_PROVENANCE)
    require(sha(path)==OBSERVER_PROVENANCE_SHA,"Exact external Kitty observer provenance changed")
    record=read_json(path)
    require(record.get("schema")=="bth.kitty_external_qa_observers/v1" and record.get("observer_specs")==OBSERVER_SPECS and
        record.get("new_QA_acceptance") is True and record.get("original_observers_modified") is False and
        record.get("production_guard_relaxed") is False and record.get("ignore_workaround") is False and
        record.get("native_clock_capture_before_json") is True and record.get("exact_native_equality_no_tolerance") is True and
        record.get("native_typed_objects_before_json") is True and record.get("serialized_objects_used_as_paint_targets") is False,
        "External Kitty observer provenance boundaries differ")
    values={}
    for target,spec in OBSERVER_SPECS.items():
        relative=PurePosixPath(spec["artifact_relative"])
        require(relative.as_posix()==spec["artifact_relative"] and relative.name==PurePosixPath(target).name+".txt" and
            spec["artifact_relative"].startswith("review_artifacts/environment_art_sources/kitty-native-observers/") and
            ".." not in relative.parts and not relative.is_absolute(),"Exact inert Kitty namespace required")
        artifact=plain(root/spec["artifact_relative"]); info=artifact.stat()
        require(stat.S_ISREG(info.st_mode) and info.st_size==spec["bytes"]<=256*1024 and sha(artifact)==spec["sha256"],
            "External inert Kitty observer bytes differ")
        values[target]={"artifact_path":str(artifact),"artifact_relative":spec["artifact_relative"],"sha256":spec["sha256"],
            "bytes":spec["bytes"],"source_kind":"EXTERNAL_QA_GD_TEXT_OVERLAY","selected_Git_source":False,"production_or_export_source":False}
    require(set(values)==set(FRESH_HELPERS),"Exact two Kitty external observers required")
    return {"schema":"bth.kitty_qa_observer_overlay/v1","provenance_path":str(path),"provenance_sha256":OBSERVER_PROVENANCE_SHA,
        "observers":values,"raw_untracked_GD_files_read_or_required":False,"production_guards_relaxed":False}

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


