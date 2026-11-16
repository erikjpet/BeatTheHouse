"""Exact Cage native policy; original counts and explicit alpha-only candidate.

Original5coreGD+stock fixture code is retained. New actual Base probes are inert
text outside selected source, installed only into QA. No launch/write/activation.
"""
import sys
sys.dont_write_bytecode = True

import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat

import assemble_cage_spatial_candidate_v2 as alpha
import cage_spatial_visibility as visibility
from bar_spatial_candidate_check import decode_png
from grand_spatial_native_trial import plain, qualified_job, read_json, sha

ROOM = "grand_casino_cage"
ARCHETYPE = ROOM
LAYER = ""
ART = "assets/art/environments/" + ROOM + "/"
MANIFEST = "data/art/environments/" + ROOM + ".json"
WORKSPACE_NAME = "BTH-ENV-SPATIAL-CAGETRIAL-20261116"
LEGACY = Path("E:/CodexQA/BTH/workspaces/BTH-ENVART-CAGE-TRIAL-20261115")
HISTORICAL_COMMIT = "d43772d5151c9079cd2d4c1982290272f9839bff"
HISTORICAL_TREE = "65955c7b64f363cc677e4f2611136c6679adf7f7"
BASELINE_SEAL = "dcd9781169080f546281b942773a18f106965d9811b360cc86fe432d0ac62584"
CUSTODY_SCHEMA = alpha.CUSTODY_SCHEMA
INDEX_SHA = "11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24"
IGNORE = b"# Non-active Cage source/baseline/candidates; exclude from Godot discovery.\n"
IGNORE_SHA = "94523ea6e2eea6103447c9a641aeeadb30afa7a2c988970e7064f1392f65595c"
ASSEMBLY_EVIDENCE = Path("E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-CAGETRIAL-20261116-v2-assemble01/evidence")
PROOF_NAME = "cage-spatial-r1-assembly.json"
APPROVAL = {
    "candidate_directory":"cage-spatial-r1-alpha-mask",
    "package_sha256":"29610fee672359f3002f31cbf90767c9d5e89ce1f9a9bdbc603dd394e1e66f1a",
    "room23_sha256":"ea7ca10a1f5fd9790f9f9635987ea6adfac833d194e532a6a21257d90e0ed31a",
    "sign_sha256":"f9e0c563b34546dc31f67bc5a963b1d098509ba5f6608388ab959596d59dd661",
    "proof_sha256":"ec0f828136789a39dfd7f2adb50e188abc85e23f2849b89050945a7f32e9627b",
    "glyph_proof_sha256":"65e52250ec04852072c2cf2ab9d084360906f94c9d198d0d09e78009504c2370",
    "review_sha256":"517a8fceef63df6f70c36126f2d100cb128159ba7f5c670a949d1762def536fa",
    "recipe_filename":"assemble_cage_spatial_candidate_v2.py",
    "recipe_sha256":"3a361d004a2aada85ca4f2feab339ae1404db06d42664582a5d9d84df160894e",
    "job_sha256":"60fcd05750c5440d0dd8de3275461dfa692db364dc0bc3ab528a1811acb1d784",
    "log_sha256":"15cdd4eba4bfb82b4af2a716e323c8779546f2b3e18ba31d4879498858b687fc",
}
FROZEN_ALPHA_SHA = APPROVAL["recipe_sha256"]
FROZEN_VISIBILITY_SHA = "8d9501395141df927306c1508ee669a1b1adf520dce25a3ede1d987486e500ca"
ANIMATION_IDS = alpha.MOTION_IDS
LOW_IDS = ANIMATION_IDS[:16]
COUNTERS = {"grand_cage_teller_counter":(520,520,776,112)}
CONTEXT_COUNTS = {"__none":5}
HOST_IDS = ("staff:grand_casino_linda","casino_fixture:cage_atm","casino_fixture:cage_counter","travel:grand_casino","travel:leave")
CANONICAL_IMPORTS = {alpha.CANONICAL_IMPORT:alpha.CANONICAL_IMPORT_SHA}
EMPTY_TEST = "scripts/tests/environment_art_cage_empty_label_check.gd"
EMPTY_TEST_SHA = "82fcc9ed97e359d48c47ac60f964bc635f1aacfdaf54fc6577872d68025bf31a"
EMPTY_TEST_LF_SHA = "b5997e178fb3267652036c76fd89d4550d79569684e9d3acdfcadb05d60f685d"
COMPARISON_REFERENCE = Path("E:/CodexQA/BTH/runs/BTH-ENVART-CAGETRIAL-20261115-r2-contexts-01/evidence/grand_casino_cage_preart_metadata.json")
COMPARISON_REFERENCE_SHA = "3ac74bc68b340451de566e0036ab49895d07b22be5b57243f87b548eeccf3917"
OBSERVER_SOURCE_ROOT = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers")
OBSERVER_PROVENANCE = "review_artifacts/environment_art_sources/cage-native-observers/provenance.json"
OBSERVER_PROVENANCE_SHA = "865cd8d4ef1dd085db3da159cefa62fe8f65ff1cc0740d31b4fb02cade354db6"
HELPERS = {
    "tools/envart_cage_preart_metadata.gd": "b55cb09928731bf6934230412ea2cbb766eb4fb08f99e674ab60395394ede325",
    "tools/envart_cage_animation_probe.gd": "37547f23d23ef2ecb6490799ef5d64e3dbe8e191f92549d08f803c45ddece634",
    "tools/envart_cage_animation_capture.gd": "c71b30d00974d3373b2492cb9ffb4a63c1482471a27905745aabc1ee62a0d456",
    "tools/environment_art_baseline_capture.gd": "89d7ae812bedd203f49830bf367863bced32d08cfcc5e0327ebaf4450317de8f",
    "tools/environment_layout_screenshots.gd": "eadf8f113aff55113ecf59e764503fd5bc2e4a64d00689573e0b56489b1a78e5",
    "tools/envart_cage_stock_states.gd": "4905aeb312ab0eaa16d5d550ba95a3d97c5f819a0d47d33c42042edc75b6dc10"
}
PROVENANCE = {
    "cage_source_identity.json": "819ccf7f7001a2f650fcb7d45e4814e75179f7c8fbbcb13b21ba71214e6d2642",
    "cage_capture_inputs.json": "f68090a3c223298a2fd497d01fdbee6fd02a0cf3b4d977b6205cf50c34b5b8db",
    "cage_trial_package_identity.json": "0abc8a365d42d0a3cf8fffceae97c51624e8d7d5e36f63a61fdb3372aa3dd06f",
    "cage_trial_adapter.py": "d545c0a98d988fb722795dba37a1ff0127e1a74dd54e75728124d41462aed6c3",
    "compare_cage_r2.py": "1738b08501f4837dc192f69e68c84a291fe55c6b94ee16cdabb236d8124f3133",
    "tools/envart_cage_animation_capture.gd.uid": "463e208b056da5234f1d953f4bceeef757019fb92f730e15b3185dc5c43ba272",
    "tools/envart_cage_animation_probe.gd.uid": "7a0ad5b4489aef4a1bf6ea03d7f08c4c89501d6b19d4af5796942beb4844a89b",
    "tools/envart_cage_preart_metadata.gd.uid": "31e403dfe4eebbc448575fb640e45501ce0e66643a95e717641f595a6cf850f8",
    "tools/envart_cage_stock_states.gd.uid": "069b462d8615915302f3e036fd18f759e3b5c91628df444e0b8631100b039e87",
    "tools/environment_art_baseline_capture.gd.uid": "cd3b58fa80239aada2b1e9752d8d3fecda4a0c4d02aa2a9226e1156fd235b7c2",
    "tools/environment_layout_screenshots.gd.uid": "a4e9a7d6067be76eee07ef86e4fb1a37c5fb88096d2626a05ad83057f243cb35"
}
OBSERVER_SPECS = {
    "tools/envart_cage_spatial_acceptance.gd": {
        "artifact_relative": "review_artifacts/environment_art_sources/cage-native-observers/envart_cage_spatial_acceptance.gd.txt",
        "sha256": "cb10e67b3d9ea5e0481b3d4cf7178fd59ee5cf22e2a401ed3b125fa48ab71c9b",
        "bytes": 2131
    },
    "tools/envart_cage_spatial_probe.gd": {
        "artifact_relative": "review_artifacts/environment_art_sources/cage-native-observers/envart_cage_spatial_probe.gd.txt",
        "sha256": "7c161bf0e9cb67930d27634707f30427a7fc4a19b66a5d729679815fb0334511",
        "bytes": 15971
    }
}
FRESH_HELPERS = tuple(OBSERVER_SPECS)
CORE_HELPERS = tuple(list(HELPERS)[:5])

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

def seal(values):
    return alpha.custody(values)


def original_observers():
    require(sha(plain(alpha.__file__)) == FROZEN_ALPHA_SHA and sha(plain(visibility.__file__)) == FROZEN_VISIBILITY_SHA,
            "Frozen Cage alpha/visibility helper source changed")
    for name,value in {**HELPERS,**PROVENANCE}.items():
        require(sha(plain(LEGACY/name)) == value,"Original Cage observer/provenance changed: "+name)
    require(sha(COMPARISON_REFERENCE) == COMPARISON_REFERENCE_SHA,"Retained R2 Base reference changed")
    return {**HELPERS,**PROVENANCE,str(COMPARISON_REFERENCE):COMPARISON_REFERENCE_SHA,
            str(Path(alpha.__file__)):FROZEN_ALPHA_SHA,str(Path(visibility.__file__)):FROZEN_VISIBILITY_SHA}


def baseline_auxiliary(workspace):
    path=plain(workspace/"source_baseline/.gdignore")
    before=path.stat()
    require(stat.S_ISREG(before.st_mode) and before.st_size == len(IGNORE) == 76 and
            path.read_bytes() == IGNORE and sha(path) == IGNORE_SHA,"Exact ordinary76-byte Cage sentinel required")
    after=path.stat()
    require((before.st_size,before.st_mtime_ns,before.st_ino)==(after.st_size,after.st_mtime_ns,after.st_ino),
            "Cage external sentinel changed during read")
    return {".gdignore":{"path":str(path),"bytes":76,"sha256":IGNORE_SHA,"modified_ns":before.st_mtime_ns,
            "file_id":before.st_ino,"ordinary_regular_file":True,"inspection_access":"read-only",
            "included_in_art_payload_seal":False,"copied_into_qa_source":False}}


def assembly_proof():
    path,job_path=ASSEMBLY_EVIDENCE/PROOF_NAME,ASSEMBLY_EVIDENCE/"job.json"
    require(sha(path)==APPROVAL["proof_sha256"] and sha(job_path)==APPROVAL["job_sha256"] and
            sha(ASSEMBLY_EVIDENCE/"worker.log")==APPROVAL["log_sha256"] and qualified_job(read_json(job_path)),
            "Exact closed fresh Cage alpha producer required")
    proof=read_json(path)
    require(proof["schema"]=="bth.cage_spatial_assembly/v2" and proof["recipe_sha256"]==FROZEN_ALPHA_SHA,
            "Actual version2 alpha assembly schema/recipe required")
    return proof


def baseline_state(workspace):
    original_observers()
    auxiliary,proof=baseline_auxiliary(workspace),assembly_proof()
    root=plain(workspace/"source_baseline")
    expected=proof["baseline"]["files"]
    require(expected==alpha.PAYLOAD_PINS and len(expected)==24 and seal(expected)==BASELINE_SEAL==
            proof["baseline"]["seal"] and plain(proof["baseline"]["path"])==root,
            "Exact current24TAB+LF/23room+separate index baseline required")
    require(inventory_all(root,{*expected,".gdignore"})=={**expected,".gdignore":IGNORE_SHA} and
            baseline_auxiliary(workspace)==auxiliary,"Exact24payload+sole76Bauxiliary differs")
    return {"payload_files":expected,"payload_file_count":24,"room_file_count":23,"payload_seal":BASELINE_SEAL,
            "custody_schema":CUSTODY_SCHEMA,"auxiliary_files":auxiliary,"physical_file_count":25,"all_other_paths_rejected":True}


def baseline_files(workspace):
    return baseline_state(workspace)["payload_files"]


def source_contract(workspace,baseline):
    root=plain(workspace/"candidate_sources")
    proof=assembly_proof()
    expected={".gdignore":IGNORE_SHA,**{APPROVAL["candidate_directory"]+"/"+name:value for name,value in proof["output"]["files"].items()}}
    require(inventory_all(root,expected)==expected and (root/".gdignore").read_bytes()==IGNORE,
            "Exact sole quarantined Cage alpha package/source sentinel changed")
    return {"candidate_source_files":expected,"quarantined_package_folders":[APPROVAL["candidate_directory"]],
            "no_auxiliary_copied_to_qa_source":True,"no_generated_room_source":True}


def canonical_imports(root):
    for name,value in CANONICAL_IMPORTS.items():
        require(sha(plain(root/name))==value,"Root must commit canonical Cage sign import; no auto-copy: "+name)


def empty_test_contract(root):
    """Authenticate unchanged tracked code across checkout CRLF/Git LF bytes.

    This only reads. It never substitutes a historical test or changes its UID.
    Both exact representations have the same normalized source bytes.
    """
    path=plain(root/EMPTY_TEST)
    raw=path.read_bytes()
    require(hashlib.sha256(raw).hexdigest() in (EMPTY_TEST_SHA,EMPTY_TEST_LF_SHA) and
            hashlib.sha256(raw.replace(b"\r\n",b"\n")).hexdigest()==EMPTY_TEST_LF_SHA,
            "Current tracked EMPTY source differs beyond exact LF/CRLF representation")
    return {"path":EMPTY_TEST,"sha256":hashlib.sha256(raw).hexdigest(),
            "canonical_LF_sha256":EMPTY_TEST_LF_SHA,"source_replaced":False,"UID_replaced":False}


def candidate(root,workspace,proof_path,review_path,baseline):
    root,proof_path,review_path=map(plain,(root,proof_path,review_path))
    proof,review=read_json(proof_path),read_json(review_path)
    require(root==workspace/"candidate_sources"/APPROVAL["candidate_directory"] and proof_path==ASSEMBLY_EVIDENCE/PROOF_NAME and
            sha(proof_path)==APPROVAL["proof_sha256"] and sha(review_path)==APPROVAL["review_sha256"] and
            review.get("schema")=="bth.cage_spatial_static_review/v2" and review.get("decision")=="STATIC_GO_FOR_NATIVE_TRIAL" and
            review.get("native_trial_approved") is True and
            review.get("independent_reviewer")=="/root/bar_clearance_audit/dark_feet_source_audit" and
            review.get("package_24_file_sha256")==APPROVAL["package_sha256"] and
            review.get("package_room23_sha256")==APPROVAL["room23_sha256"] and
            review.get("logical_file_count")==24 and review.get("logical_room_file_count")==23 and
            plain(review["candidate_path"])==root and review["producer_recipe"]["sha256"]==FROZEN_ALPHA_SHA and
            review["assembly_report"]["sha256"]==APPROVAL["proof_sha256"],"Exact actual Cage native-only review required")
    require(assembly_proof()==proof and sha(ASSEMBLY_EVIDENCE/"cage-spatial-r1-glyph-proof.json")==APPROVAL["glyph_proof_sha256"],
            "Exact closed producer/glyph proof changed")
    files=proof["output"]["files"]
    require(set(files)==set(baseline) and len(files)==24 and inventory_all(root,files)==files and
            seal(files)==proof["output"]["seal"]==APPROVAL["package_sha256"] and
            seal({name:value for name,value in files.items() if name!=alpha.INDEX})==APPROVAL["room23_sha256"] and
            files[alpha.SIGN]==APPROVAL["sign_sha256"] and
            {name for name in files if files[name]!=baseline[name]}=={alpha.SIGN},
            "Only the exact Cage sign PNG may change in24member package")
    spec=alpha.manifest_contract((root/MANIFEST).read_bytes())
    require((root/MANIFEST).read_bytes()==(workspace/"source_baseline"/MANIFEST).read_bytes() and
            files[alpha.INDEX]==INDEX_SHA,"Full Cage20/16 JSON/currentindex byte custody changed")
    master=decode_png((root/alpha.BACKGROUND).read_bytes())
    sign=decode_png((root/alpha.SIGN).read_bytes())
    original=decode_png((workspace/"source_baseline"/alpha.SIGN).read_bytes())
    support=alpha.glyph_support(master)
    cut=alpha.verify_cut(original,sign,support)
    replay=alpha.counter_proof(master,decode_png((root/alpha.COUNTER).read_bytes()))
    return {"files":files,"package_sha256":APPROVAL["package_sha256"],"candidate_root":str(root),
            "review_sha256":APPROVAL["review_sha256"],"candidate_manifest_sha256":APPROVAL["proof_sha256"],
            "assembly_job_sha256":APPROVAL["job_sha256"],"approved_repair_recipe_sha256":FROZEN_ALPHA_SHA,
            "alpha_cut":cut,"exact_counter_crop":replay,"native_entries":20,"default_low_detail_entries":16,
            "custody_schema":CUSTODY_SCHEMA,"review":review,"production_art_written":False,"test_updated":False}


def literal_bindings(cfg):
    fresh=(Path(cfg["qa_root"])/"runs"/(cfg["run_prefix"]+"-contexts")/"evidence/grand_casino_cage_preart_metadata.json").as_posix()
    return {"tools/envart_cage_stock_states.gd":{
        "E:/CodexQA/BTH/runs/BTH-ENVART-CAGETRIAL-20261115-r2-contexts-01/evidence/grand_casino_cage_preart_metadata.json":fresh}}


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

def comparison_contract(report):
    require(sha(COMPARISON_REFERENCE)==COMPARISON_REFERENCE_SHA,"Retained accepted R2 Base changed")
    original=read_json(COMPARISON_REFERENCE)
    no_findings(report)
    require(set(report["views"])=={"__none"},"Historical comparison covers exactly actual Base")
    before,after=original["views"]["__none"],report["views"]["__none"]
    row={"context":"__none","layout_equal":before["actual_view"]["object_layout"]==after["actual_view"]["object_layout"],
         "objects_equal":before["actual_view"]["objects"]==after["actual_view"]["objects"],
         "published_equal":before["snapshot"]["interactable_objects"]==after["snapshot"]["interactable_objects"]}
    require(all(value for key,value in row.items() if key!="context"),"Actual Base historical layout/object/publication changed")
    return {"status":"PASS","checks":3,"baseline":str(COMPARISON_REFERENCE),"baseline_sha256":COMPARISON_REFERENCE_SHA,
            "rows":[row],"scope":"Historical accepted R2 Base comparison only, not new lifecycle/reached shop acceptance.",
            "original_comparison_source_sha256":PROVENANCE["compare_cage_r2.py"]}


def report_contract(phase,report,*,source_files=0):
    no_findings(report)
    if phase=="contexts":
        require(report["checks"]==2*source_files+54 and report["scenarios"]==["__none"] and
                report["direct_catalog"]==["__none"] and set(report["views"])=={"__none"},"Original Base-only2N+54 checks changed")
        view=report["views"]["__none"]
        require([row["id"] for row in view["actual_view"]["objects"]]==list(HOST_IDS) and
                {row["id"] for row in view["selected_label_evidence"]}==set(HOST_IDS) and
                len(view["selected_label_evidence"])==5,"Actual Cage5objects/5selected labels changed")
        require(len(visibility.typed_mapping({"source_paint":view["source_paint"],"actual_view":view["actual_view"]}))==10,
                "Exact ten fresh typed masks required")
        return {"initial_contexts":1,"objects":5,"selected_labels":5,"typed_pairs":5,"typed_PNGs":10,
                "source_mode2_fronts":1,"reached_stock_or_lifecycle":False}
    if phase=="motion":
        visibility.motion_contract(report)
        return {"checks":82,"native_entries":20,"actual_renderer_low_membership":16,
                "normal_and_low_RM_stable":True,"browser_execution":False}
    if phase=="stock-states":
        require(report["checks"]==12 and len(report["rows"])==4,"Original four stock canvases/12checks required")
        require([(row["packed"],row["state"]) for row in report["rows"]]==
                [(False,"empty"),(False,"available"),(True,"empty"),(True,"available")],"Exact stock fixture matrix required")
        for row in report["rows"]:
            require(len(row["labels"])==(1 if row["state"]=="empty" else 0) and len(row["objects"])==5 and
                    {value["id"] for value in row["objects"]}==set(HOST_IDS),"Original EMPTY/live5 fixture contract failed")
        return {"checks":12,"composed_stock_canvases":4,"semantic_dummy_stock_only":True,
                "naturally_reached_stock_transactions_or_lifecycle":False}
    if phase=="empty-compat":
        require(report["checks"]==52 and len(report["cases"])==14 and
                {(row["case"],row["packed"]) for row in report["cases"]}==
                {(name,packed) for name in ("missing","empty","all_sold","populated","malformed_entries","missing_sold_flag","malformed_shop") for packed in (False,True)} and
                [row["mode"] for row in report["rendered_label_pixels"]]==["reference","empty","populated"],
                "Original52checks/seven×two EMPTY compatibility fixtures required")
        return {"checks":52,"semantic_fixture_cases":7,"draw_branches":2,"label_PNGs":3,"reached_shop_claim":False}
    if phase in ("composite","composite-rm","low-detail","depth-glyph"):
        require(report["schema"]=="bth.cage_spatial_acceptance/v1" and report["context"]==ROOM and
                report["case"]=="__none" and report["mode"]==phase and
                report["production_snapshot_unchanged"] is True and report["processing_remained_active"] is True,
                "Actual matched Base Cage source/processing changed")
        glyph=report["glyph_contact"]
        require(glyph["selected_alpha46_texels"]==5532 and glyph["other_nonzero_alpha_values"]==0 and
                glyph["all_ten_source_contacts_zero"] is True and len(glyph["fresh_typed_masks"])==10 and
                {(r["id"],r["kind"]) for r in glyph["fresh_typed_masks"]}==
                {(name,kind) for name in HOST_IDS for kind in ("body","adorn")} and
                all(r["alpha_gt0"]==r["alpha_ge64"]==0 for r in glyph["fresh_typed_masks"]),
                "Compiled5532glyph/fresh ten actual alpha contacts changed")
        if phase=="depth-glyph":
            depth=report["depth"]
            require(depth["actual_command_order_valid"] is True and depth["Linda_before_counter"] is True and
                    depth["body_count"]==depth["adornment_count"]==5 and depth["actual_geometry_equal"] is True,
                    "Actual LindaBehind/replay/Standard/adornment depth changed")
        else:
            require([r["id"] for r in report["entries"]]==list(ANIMATION_IDS) and report["low_membership_count"]==16,
                    "Fresh complete20entry/16low composite roster changed")
            for row in report["entries"]:
                expected=phase!="composite-rm" and (phase!="low-detail" or row["id"] in LOW_IDS)
                require(row["identical_control_pixels"] is True and row["actual_objects_layout_equal"] is True and
                        row["object_route_label_clocks_equal"] is True and row["visible_composite_change"] is expected and
                        row["expected_change"] is expected,"Fresh matched object/route/control/membership failure")
        return {"new_actual_probe":True,"mode":phase,"Base_objects":5,"glyph_alpha_texels":5532,
                "fresh_typed_masks":10,"source_objects_labels_unchanged":True,"browser_execution":False}
    raise ValueError("No Cage report contract for phase: "+phase)


def observer_source_boundary(files):
    """Pure negative gate: QA GD/UIDs and external text stay outside051 source."""
    names = set(files)
    forbidden = {name for target in FRESH_HELPERS for name in (target,target+".uid")}
    require(not names.intersection(forbidden),
            "External Cage QA GD/UID targets must be absent from committed selected source: "+
            str(sorted(names.intersection(forbidden))))
    require(not any(name in names for name in (OBSERVER_PROVENANCE,
            *(row["artifact_relative"] for row in OBSERVER_SPECS.values()))),
            "Observer artifacts are external to051 selected prefixes")
    return {"all2_observer_GD_and_UID_targets_absent":True,
            "review_text_artifacts_outside_selected_archive":True,
            "production_921code_900GD_161toolsGD_guard_unchanged":True}

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

def observer_inputs():
    root=plain(OBSERVER_SOURCE_ROOT)
    path=plain(root/OBSERVER_PROVENANCE)
    require(sha(path)==OBSERVER_PROVENANCE_SHA,"Exact inert Cage observer provenance changed")
    record=read_json(path)
    require(record["schema"]=="bth.cage_external_qa_observers/v1" and record["observer_specs"]==OBSERVER_SPECS and
            record["original_assertions_modified"] is False and record["production_guard_relaxed"] is False and
            record["raw_GD_files_created"] is False and record["normal_entries"]==20 and record["low_entries"]==16,
            "Inert Cage observer source/scope changed")
    values={}
    for target,spec in OBSERVER_SPECS.items():
        relative=PurePosixPath(spec["artifact_relative"])
        require(relative.name==PurePosixPath(target).name+".txt" and relative.suffix==".txt" and
                spec["artifact_relative"].startswith("review_artifacts/environment_art_sources/cage-native-observers/") and
                ".." not in relative.parts and not relative.is_absolute(),"Inert Cage text path escaped namespace")
        artifact=plain(root/spec["artifact_relative"])
        info=artifact.stat()
        require(stat.S_ISREG(info.st_mode) and info.st_size==spec["bytes"]<=256*1024 and sha(artifact)==spec["sha256"],
                "Inert Cage exact observer bytes differ")
        values[target]={"artifact_path":str(artifact),"artifact_relative":spec["artifact_relative"],"sha256":spec["sha256"],
            "bytes":spec["bytes"],"source_kind":"EXTERNAL_QA_GD_TEXT_OVERLAY","selected_Git_source":False,"production_or_export_source":False}
    require(len(values)==2 and set(values)==set(FRESH_HELPERS),"Exactly two inert Cage observers required")
    return {"schema":"bth.cage_qa_observer_overlay/v1","provenance_path":str(path),"provenance_sha256":OBSERVER_PROVENANCE_SHA,
            "observers":values,"raw_untracked_GD_files_read_or_required":False,"production_guards_relaxed":False}
