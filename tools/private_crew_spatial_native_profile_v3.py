"""Version3 Private policy: typed native Lucky target and disjoint retained inputs.

Five original core GD observers and two additional original lifecycle observers
are authenticated unchanged; new art acceptance probes are separately declared.
No helper launch, auto-copy, source/art/profile write or coverage inflation.
"""
import sys
sys.dont_write_bytecode = True

import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat

from bar_spatial_candidate_check import decode_png
from grand_spatial_native_trial import plain, qualified_job, read_json, seal, sha

ROOM = "punchline_back_room"
ARCHETYPE = "small_underground_casino"
LAYER = "back_room"
ART = "assets/art/environments/" + ROOM + "/"
MANIFEST = "data/art/environments/" + ROOM + ".json"
WORKSPACE_NAME = "BTH-ENV-SPATIAL-PRIVATETRIAL2-20261116"
QA_WORKSPACE = Path("E:/CodexQA/BTH/workspaces") / WORKSPACE_NAME
RETAINED_INPUT_WORKSPACE = Path("E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-PRIVATETRIAL-20261116")
LEGACY = Path("E:/CodexQA/BTH/workspaces/BTH-ENVART-PRIVATE-TRIAL-20261115")
HISTORICAL_COMMIT = "74c85e44577b34eaf7e9c1f857e62b2c999c1fbc"
BASELINE_SEAL = "ce147a7e45f5252460d3a19dbe180b71ef0863fc9201097b8e3f9e20bd5ebb13"
ROOM9_SEAL = "c8882f6f7fee3d1514b94f3a3834e04f47bbf4e10413ce0ef53b27fc824dd733"
INDEX_SHA = "11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24"
RAW_SHA = "ac34392a170633b5fd8bebb987c2b81de9adc007c7a951fe41c008d5053b34aa"
IGNORE = b"# Non-active Private Crew source/candidates; exclude from Godot discovery.\n"
IGNORE_SHA = "54714887b3bf3c9dfe99a8ff1646708048b7e552b43956212345d561455298ca"
ASSEMBLY_EVIDENCE = Path("E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-PRIVATETRIAL-20261116-v2-01/evidence")
PROOF_NAME = "private-crew-spatial-r1-assembly-v2.json"
APPROVAL = {
    "candidate_directory": "private-crew-spatial-r1-assembled-v2",
    "package_sha256": "11fb1cb50971100bd21404fdb73a0ca3550f487f656aa694874f4159c15dcfe4",
    "background_sha256": "1939afd50bc5df04524c45965e9a895d6cb2f9fd17b30dc1824df9671892242b",
    "proof_sha256": "9c87d8cbacb1203e73bfdd31dfc87ac9322e5b0de391d8d94c910081a362e6cf",
    "review_sha256": "cd0ba14d82ea8317436d9983ded0b34b53cf72212fe5dfa796a5c4a104385395",
    "recipe_filename": "assemble_private_crew_spatial_candidate_v2.py",
    "recipe_sha256": "79152deff996fbbd0e8f8759524ec87d1228b03952e50038170caacb2e75fe22",
    "job_sha256": "d14c8d3ed96d93fbddf6bf78812a4a9b5e6171d06f28c5147a562bfc09063bb0",
}
ANIMATION_IDS = tuple("floor_glint_" + str(i) for i in range(7))
LOW_IDS = ANIMATION_IDS
COUNTERS = {}
CONTEXT_COUNTS = {"__none": 10}
LIFECYCLE_COUNTS = {"C1_marker":15,"C2_associate_0":14,"C2_associate_2":13,"C2_associate_5":13,"C4_silas":15}
LIFECYCLE_TYPED_COUNTS = {"C1_marker":4,"C2_associate_0":4,"C2_associate_2":3,"C2_associate_5":3,"C4_silas":5}
CANONICAL_IMPORTS = {ART + "background.png.import": "42bfe5f50cd92e5116a82180ad0735e284d8ae75fb8c630d508a34919766bc14"}
FRESH_HELPERS = ("tools/envart_private_spatial_probe.gd","tools/envart_private_spatial_base_acceptance.gd",
                 "tools/envart_private_spatial_lucky_acceptance.gd")
OBSERVER_SOURCE_ROOT = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers")
OBSERVER_PROVENANCE = "review_artifacts/environment_art_sources/private-crew-native-observers-v3/provenance.json"
OBSERVER_PROVENANCE_SHA = "764f23828994b577ab59dc9d6c66d9377d6badd641f1e72d30d64e097a5f7a8e"
FROZEN_POLICY_V1_SHA = "c59ecac37ac281b37341963253a55048d57c701be8fb66e6531f587935d3f0b6"
FROZEN_RUNNER_V1_SHA = "736949f2ba20687e6ca07e35d193c061166cfccf42d43bc19d77cd67d88764b7"
OBSERVER_SPECS = {'tools/envart_private_spatial_probe.gd': {'artifact_relative': 'review_artifacts/environment_art_sources/private-crew-native-observers-v3/envart_private_spatial_probe.gd.txt',
                                           'sha256': '134f5442b6c27e8e79cfd936c5d56011094d1fddf4ff524eb37bde3faa35c774',
                                           'bytes': 16453},
 'tools/envart_private_spatial_base_acceptance.gd': {'artifact_relative': 'review_artifacts/environment_art_sources/private-crew-native-observers-v3/envart_private_spatial_base_acceptance.gd.txt',
                                                     'sha256': '457a176440f9b75a11f461292d005f9b670d24c5cb3363a5426230ab127c07b0',
                                                     'bytes': 980},
 'tools/envart_private_spatial_lucky_acceptance.gd': {'artifact_relative': 'review_artifacts/environment_art_sources/private-crew-native-observers-v3/envart_private_spatial_lucky_acceptance.gd.txt',
                                                      'sha256': 'f85e382f0d33db68af9972948b3777a0e355d50d08a5f7900a645861c9d3f822',
                                                      'bytes': 1242}}
FROZEN_V2 = {'observer_provenance': '0530f500c0c5ec365e5934eaec52e76fcb71d3e6110ec322916918deb44f1580',
 'policy': '8b7abee3c85f30d1b4dc2e33b6eb0581eec02b95aee10443960a723bf5bb493e',
 'runner': '961a5b9c7c5bcb87a5fe6227053673732b2c5461fabdf958c2c38c9ab5645661',
 'tests': '64aecfbfaf2c4bb2b8c5ef44d878feebb856ed895e411805ed27ca72044c6507'}
V2_OBSERVER_SPECS = {'tools/envart_private_spatial_probe.gd': {'artifact_relative': 'review_artifacts/environment_art_sources/private-crew-native-observers/envart_private_spatial_probe.gd.txt',
                                           'sha256': '14d56c5c344c215d9baa64c67c3366c92fd41e66d068ce0934db3f8ea1c5dd54',
                                           'bytes': 13481},
 'tools/envart_private_spatial_base_acceptance.gd': {'artifact_relative': 'review_artifacts/environment_art_sources/private-crew-native-observers/envart_private_spatial_base_acceptance.gd.txt',
                                                     'sha256': '457a176440f9b75a11f461292d005f9b670d24c5cb3363a5426230ab127c07b0',
                                                     'bytes': 980},
 'tools/envart_private_spatial_lucky_acceptance.gd': {'artifact_relative': 'review_artifacts/environment_art_sources/private-crew-native-observers/envart_private_spatial_lucky_acceptance.gd.txt',
                                                      'sha256': 'f85e382f0d33db68af9972948b3777a0e355d50d08a5f7900a645861c9d3f822',
                                                      'bytes': 1242}}
HELPERS = {
    "tools/envart_private_preart_metadata.gd": "c62fbab8f33ef8b154cf1394c6038f71ee09eeef8ca6b0d140e16b30708dc3a9",
    "tools/envart_private_animation_probe.gd": "c40dc236d40b5e603575836a4d1b60a7635cd2c12d8e167daca16270c76468d6",
    "tools/envart_private_animation_capture.gd": "51bce8acf94cccefc0b4e84977b7720a7c7e26dad04607bdcabe1416591254ed",
    "tools/environment_art_baseline_capture.gd": "89d7ae812bedd203f49830bf367863bced32d08cfcc5e0327ebaf4450317de8f",
    "tools/environment_layout_screenshots.gd": "eadf8f113aff55113ecf59e764503fd5bc2e4a64d00689573e0b56489b1a78e5",
    "tools/envart_private_lifecycle_recovery.gd": "8358ee2d079159d07e2342ac00c87c5598e48b04b8bee544119a970f2c49294e",
    "tools/envart_private_lifecycle_detail_recovery.gd": "991510be842e41b6f1aa10e4a30ac5cf76b18835902114d9f5ce5b9475511453"
}
PROVENANCE = {
    "private_source_identity.json": "2b7a99d5495788d1111f22d5d3afbfda18c7473d5ec77b85e4494132fe4bee44",
    "private_capture_inputs.json": "b6bbe3791b602789cf824e5d54b060402cfd496600d4a266b8d34d84dc045fc3",
    "private_trial_package_identity.json": "b031ca88e54b4ced5e5d093ff59319af2d7ffd81c2ac37361741e40a88c85ea8",
    "private_trial_adapter.py": "c29907adacbe045d0856fe354e008f8fa7ab6c31e1d8a5526d00532aff91958f",
    "tools/envart_private_preart_closure.py": "3283741f2514ec449de96ffd84d15cb4521e5cd7689a9d1c1a410ac8d40f3b7c",
    "tools/envart_private_preart_union.py": "35e0d89608c33e34f6826cc195e9f1af1d487358417ccff092aed7608b5dfef9",
    "tools/envart_private_animation_capture.gd.uid": "351bfa43495ae9f61a9b5ac7849b1750860f72dd0c3c0b026c1688be5ba10e1c",
    "tools/envart_private_animation_probe.gd.uid": "a4804bbc044e47d66c2720234d1bbccc1bbbecffa9981ac0fd4f074d44d834b9",
    "tools/envart_private_lifecycle_detail_recovery.gd.uid": "d16d4cff7c8578997f80937ff3aa81ffbe7092375f829d5a2fa4f060879697a2",
    "tools/envart_private_lifecycle_recovery.gd.uid": "d4e29b28af026f19791872910562e72632757b66e818373effdeeab3b578eba6",
    "tools/envart_private_preart_metadata.gd.uid": "6ea027b8d5a71816fb4ae56b2f83cc98c8477973a5a3240bc42246e59eaca758",
    "tools/environment_art_baseline_capture.gd.uid": "cd3b58fa80239aada2b1e9752d8d3fecda4a0c4d02aa2a9226e1156fd235b7c2",
    "tools/environment_layout_screenshots.gd.uid": "a4e9a7d6067be76eee07ef86e4fb1a37c5fb88096d2626a05ad83057f243cb35"
}
CORE_HELPERS = tuple(list(HELPERS)[:5])
SOURCE_AUX = {
    ".gdignore": IGNORE_SHA,
    "private-crew-spatial-r1.png": RAW_SHA,
    "private-crew-spatial-r1.png.b64": "0223177475b84ea6c165010eddf4453da4239cf3e4b88427899fd58b2bd82af6",
    "prompt.txt": "da997f23a22ec21a5b403fff31fe76dea920fcdf89308f0476dd5e63c1ae7751",
    "provenance.json": "b567eb8c0efb997e0a9691fb1bd04b98adac7588623b93eab2a5c52ffd2e2ca1",
}


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
        require(sha(plain(LEGACY / name)) == value, "Original Private observer/provenance changed: " + name)
    return {**HELPERS, **PROVENANCE}


def retained_input_root(workspace):
    """Authenticate the one original source/baseline/candidate campaign, read-only."""
    value = Path(workspace)
    require(value.is_absolute() and ".." not in value.parts, "Explicit ordinary retained input workspace required")
    value = plain(value)
    require(value == RETAINED_INPUT_WORKSPACE and value.is_dir(),
            "Only original PRIVATETRIAL retained inputs are admitted")
    require({item.name for item in value.iterdir()} == {"source_baseline","candidate_sources","qa_source"},
            "Original completed/failed campaign root membership changed")
    for item in value.iterdir():
        require(plain(item).is_dir(), "Original campaign members must remain ordinary directories")
    return value

def workspace_roles(qa_workspace, input_workspace):
    """Exact disjoint fresh QA root and retained input root; never migrate either."""
    value = Path(qa_workspace)
    require(value.is_absolute() and ".." not in value.parts, "Explicit absolute fresh Private QA workspace required")
    qa = plain(value)
    retained = retained_input_root(input_workspace)
    require(qa == QA_WORKSPACE and qa.parent == Path("E:/CodexQA/BTH/workspaces") and
            qa != retained and not qa.is_relative_to(retained) and not retained.is_relative_to(qa),
            "Exact disjoint PRIVATETRIAL2 QA and original PRIVATETRIAL input roots required")
    if qa.exists():
        require(qa.is_dir() and {item.name for item in qa.iterdir()} <= {"qa_source"},
                "Unknown fresh-QA campaign root member")
        for item in qa.iterdir():
            require(plain(item).is_dir(), "Fresh QA root members must be ordinary directories")
    return {"qa_workspace": qa, "input_workspace": retained}

def baseline_auxiliary(workspace):
    workspace = retained_input_root(workspace)
    path = plain(workspace / "source_baseline/.gdignore")
    before = path.stat()
    require(stat.S_ISREG(before.st_mode) and before.st_size == len(IGNORE) == 75 and
            path.read_bytes() == IGNORE and sha(path) == IGNORE_SHA, "Exact ordinary75-byte Private sentinel required")
    after = path.stat()
    require((before.st_size,before.st_mtime_ns,before.st_ino) == (after.st_size,after.st_mtime_ns,after.st_ino),
            "External baseline sentinel changed during read")
    return {".gdignore":{"path":str(path),"bytes":before.st_size,"sha256":IGNORE_SHA,
            "modified_ns":before.st_mtime_ns,"file_id":before.st_ino,"ordinary_regular_file":True,
            "inspection_access":"read-only","included_in_art_payload_seal":False,"copied_into_qa_source":False}}


def assembly_proof():
    path, job_path = ASSEMBLY_EVIDENCE / PROOF_NAME, ASSEMBLY_EVIDENCE / "job.json"
    require(sha(path) == APPROVAL["proof_sha256"] and sha(job_path) == APPROVAL["job_sha256"] and
            qualified_job(read_json(job_path)), "Exact closed guarded Private V2 producer required")
    return read_json(path)


def baseline_state(workspace):
    workspace = retained_input_root(workspace)
    original_observers()
    auxiliary, proof = baseline_auxiliary(workspace), assembly_proof()
    expected, root = proof["baseline"]["files"], plain(workspace / "source_baseline")
    require(len(expected) == 10 and seal(expected) == BASELINE_SEAL ==
            proof["baseline"]["payload10_with_index_seal"] and proof["baseline"]["room9_seal"] == ROOM9_SEAL and
            plain(proof["baseline"]["path"]) == root and proof["recipe_sha256"] == APPROVAL["recipe_sha256"],
            "Exact9room+index10 baseline binding required")
    require(inventory_all(root,{*expected,".gdignore"}) == {**expected,".gdignore":IGNORE_SHA} and
            baseline_auxiliary(workspace) == auxiliary, "Logical10 plus exact sole sentinel custody differs")
    return {"payload_files":expected,"payload_file_count":10,"room_file_count":9,"payload_seal":BASELINE_SEAL,
            "auxiliary_files":auxiliary,"physical_file_count":11,"all_other_paths_rejected":True}


def baseline_files(workspace):
    return baseline_state(workspace)["payload_files"]


def source_contract(workspace, baseline):
    workspace = retained_input_root(workspace)
    proof, root = assembly_proof(), plain(workspace / "candidate_sources")
    v1_files = dict(baseline)
    v1_files[ART+"background.png"] = "d35b56c23d411ee46c3648d761abe047b67c11549d8edef50309b875d40531ea"
    expected = {**SOURCE_AUX,
        **{"private-crew-spatial-r1-assembled-v1/"+name:value for name,value in v1_files.items()},
        **{APPROVAL["candidate_directory"]+"/"+name:value for name,value in proof["output"]["files"].items()}}
    require(inventory_all(root,expected) == expected and (root/".gdignore").read_bytes() == IGNORE,
            "Exact original raw/V1/V2 quarantine closure changed")
    return {"candidate_source_files":expected,"baseline_auxiliary":{"source_baseline/.gdignore":IGNORE_SHA},
            "quarantined_package_folders":["private-crew-spatial-r1-assembled-v1",APPROVAL["candidate_directory"]],
            "V1_stays_rejected_immutable":True,"no_auxiliary_copied_to_qa_source":True}


def canonical_imports(root):
    for name, value in CANONICAL_IMPORTS.items():
        require(sha(plain(root/name)) == value, "Root must commit audited canonical Private background import; no auto-copy: "+name)


def candidate(root, workspace, proof_path, review_path, baseline):
    workspace = retained_input_root(workspace)
    root, proof_path, review_path = map(plain,(root,proof_path,review_path))
    proof, review = read_json(proof_path), read_json(review_path)
    require(root == workspace/"candidate_sources"/APPROVAL["candidate_directory"] and
            proof_path == ASSEMBLY_EVIDENCE/PROOF_NAME and sha(proof_path) == APPROVAL["proof_sha256"] and
            sha(review_path) == APPROVAL["review_sha256"] and
            review.get("schema") == "bth.private_crew_spatial_static_review/v2" and
            review.get("decision") == "STATIC_GO_FOR_NATIVE_TRIAL" and review.get("native_trial_approved") is True and
            review.get("independent_reviewer") == "/root/audit_spatial_handoff" and
            review.get("package_10_file_sha256") == APPROVAL["package_sha256"] and
            review.get("assembly_proof_sha256") == APPROVAL["proof_sha256"] and
            review.get("executed_recipe_sha256") == APPROVAL["recipe_sha256"] and
            review.get("logical_file_count") == 10 and review.get("room_file_count") == 9 and
            plain(review["candidate_path"]) == root, "Exact actual Private V2 native-only static review required")
    files = proof["output"]["files"]
    require(len(files) == 10 and set(files) == set(baseline) and proof["baseline"]["files"] == baseline and
            inventory_all(root,files) == files and seal(files) == proof["output"]["seal"] == APPROVAL["package_sha256"] and
            files[ART+"background.png"] == APPROVAL["background_sha256"] and
            proof["recipe_sha256"] == APPROVAL["recipe_sha256"], "Reviewed Private candidate/source binding changed")
    recipe = Path(__file__).with_name(APPROVAL["recipe_filename"])
    job = read_json(proof_path.parent/"job.json")
    require(sha(recipe) == APPROVAL["recipe_sha256"] and qualified_job(job) and job["command"][1] == "-B" and
            plain(job["command"][2]) == plain(recipe), "Exact executed79152 recipe/closed producer required")
    require({name for name in files if files[name] != baseline[name]} == {ART+"background.png"},
            "Only Private background PNG may change")
    spec = read_json(root/MANIFEST)
    require((root/MANIFEST).read_bytes() == (workspace/"source_baseline"/MANIFEST).read_bytes() and
            files["data/art/environments/index.json"] == INDEX_SHA and
            [r["id"] for r in spec["animations"]] == list(ANIMATION_IDS) and
            all(r["type"] == "mover" and r.get("web_low_detail",True) is True for r in spec["animations"]) and
            len({r["texture"] for r in spec["animations"]}) == 7 and spec["counters"] == {},
            "Private7native/defaultlow7/zero-counter full JSON/index contract changed")
    master = decode_png((root/(ART+"background.png")).read_bytes())
    require((master.width,master.height) == (1800,860) and set(master.rgba[3::4]) == {255},
            "Opaque1800x860 Private master required")
    return {"files":files,"package_sha256":APPROVAL["package_sha256"],"candidate_root":str(root),
            "review_sha256":APPROVAL["review_sha256"],"candidate_manifest_sha256":APPROVAL["proof_sha256"],
            "assembly_job_sha256":APPROVAL["job_sha256"],"approved_repair_recipe_sha256":APPROVAL["recipe_sha256"],
            "native_entries":7,"default_low_detail_entries":7,"unique_motion_pngs":7,"zero_counters_and_replays":True,
            "review":review,"production_art_written":False,"test_updated":False}


def literal_bindings(cfg):
    # Original observers already use res://private_capture_inputs.json and
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

def report_contract(phase, report, *, source_files=0):
    no_findings(report)
    if phase == "contexts":
        require(report["scenarios"] == ["__none"] and report["direct_private_catalog"] == ["__none"] and
                set(report["views"]) == {"__none"} and report["checks"] == 2*source_files+90,
                "Original Base-only2N+90 Private assertions changed")
        view = report["views"]["__none"]
        ids = {r["id"] for r in view["actual_view"]["objects"]}
        require(len(ids) == len(view["selected_label_evidence"]) == 10 and
                ids == {r["id"] for r in view["selected_label_evidence"]} and
                view["source_paint"]["geometry_equal"] is True and len(view["source_paint"]["objects"]) == 6,
                "Original10Base objects/selected cards/six host-paint pairs changed")
        return {"initial_contexts":1,"initial_objects":10,"selected_labels":10,"typed_host_pairs":6,
                "direct_private_scenarios":0,"work_outcome_coverage":False}
    if phase == "motion":
        require(report["checks"] == 15 and [r["id"] for r in report["entries"]] == list(ANIMATION_IDS) and
                all(r["live_visible_change"] is True and r["reduce_motion_stable"] is True for r in report["entries"]),
                "Original7entry/15check Private motion contract changed")
        return {"native_entries":7,"default_low_detail_entries":7,"unique_motion_pngs":7,"checks":15}
    if phase == "lifecycle":
        rows = report["cases"]
        require(report["checks"] == 246 and [r["name"] for r in rows] == list(LIFECYCLE_COUNTS) and
                report["silas_reached"] is True and "NOT REACHED" in report["C3"],
                "Original five constructed lifecycle cases/246 checks/C3 scope changed")
        for row in rows:
            name = row["name"]
            ids = {o["id"] for o in row["view"]["objects"]}
            paint = row["source_character_paint"]
            require(len(ids) == LIFECYCLE_COUNTS[name] and len(row["selected"]) == len(ids) and
                    {r["id"] for r in row["selected"]} == ids and paint["geometry_equal"] is True and
                    len(paint["objects"]) == LIFECYCLE_TYPED_COUNTS[name] and row["authority"]["ok"] is True,
                    "Exact lifecycle object/selected/typed source membership changed: "+name)
        return {"constructed_cases":5,"objects_and_selected":70,"typed_character_pairs":19,
                "Base_plus_lifecycle_typed_PNGs":50,"C3":report["C3"],"UI_earned_work_save_revisit":False}
    if phase in ("composite","composite-rm","depth","placement","lucky-glyph"):
        require(report.get("schema") == "bth.private_spatial_acceptance/v1" and report["mode"] == phase and
                report["context"] == "small_underground_casino:back_room" and
                report["case"] == ("C1_marker" if phase=="lucky-glyph" else "__none") and
                report["production_snapshot_unchanged"] is True and report["processing_remained_active"] is True,
                "Fresh actual Private Base acceptance identity/processing changed")
        if phase in ("composite","composite-rm"):
            require([r["id"] for r in report["entries"]] == list(ANIMATION_IDS) and
                    all(r["identical_control_pixels"] and r["actual_objects_layout_equal"] and
                        r["object_route_label_clocks_equal"] and
                        r["reduce_motion_composite_stable" if phase=="composite-rm" else "visible_composite_change"]
                        for r in report["entries"]), "Private actual7entry composite/control/RM failure")
        elif phase == "depth":
            require(report["zero_counters_and_replays"] is True and report["actual_object_count"] == 10 and
                    report["geometry_equal"] is True, "Private background-only actual10 depth failure")
        elif phase == "placement":
            require(report["placement_enabled"] is True and report["geometry_equal"] is True and
                    report["no_saved_override_or_drag"] is True and report["clock_advanced_without_pointer"] is True,
                    "Private placement overlay scheduling/geometry failure")
        else:
            binding = report.get("native_target_binding", {})
            require(binding.get("native_source_api") == "PixelSceneCanvas._active_scene_objects" and
                binding.get("native_position_type") == "Vector2" and binding.get("stable_id_unique") is True and
                binding.get("expected_json_equal") is True and binding.get("production_layout_equal") is True and
                binding.get("coordinates_reconstructed") is False,
                "Lucky actual native stable-ID/Vector2/unchanged-geometry binding required")
            require(report["lucky_id"] == "event:recruitment_lucky" and report["actual_glyph_alpha_pixels"] > 0 and
                    report["actual_label_alpha_ge64_pixels"] > 0 and
                    0 <= report["actual_label_alpha_ge64_bright_master_pixels"] <= report["actual_label_alpha_ge64_pixels"] and
                    report["glyph_geometry_equal"] is True and report["actual_native_glyph_png"] and
                    report["fixture"] == "CONSTRUCTED_PREGEN_MARKER_TRUST_PRIVATE_BASE_RECRUITMENT" and
                    report["clean_Base10_claim"] is False,
                    "Fresh explicitly eligible recruitment Base actual glyph diagnostic required")
        return {"new_probe":True,"mode":phase,"case":report["case"],"checks":report["checks"],
                "independent_actual_visual_review_still_required":True}
    raise ValueError("No Private report contract for phase: "+phase)



def observer_source_boundary(files):
    """Pure negative gate: QA GD/UIDs and external text stay outside051 source."""
    names = set(files)
    forbidden = {name for target in FRESH_HELPERS for name in (target,target+".uid")}
    require(not names.intersection(forbidden),
            "External Private QA GD/UID targets must be absent from committed selected source: "+
            str(sorted(names.intersection(forbidden))))
    require(not any(name in names for name in (OBSERVER_PROVENANCE,
            *(row["artifact_relative"] for row in OBSERVER_SPECS.values()))),
            "Observer artifacts are external to051 selected prefixes")
    return {"all3_observer_GD_and_UID_targets_absent":True,
            "review_text_artifacts_outside_selected_archive":True,
            "production_921code_900GD_161toolsGD_guard_unchanged":True}


def observer_inputs():
    """Authenticate only committed inert artifacts; raw untracked GDs are unused."""
    for name,key in (("private_crew_spatial_native_profile_v2.py","policy"),
                     ("private_crew_spatial_native_trial_v2.py","runner"),
                     ("test_private_crew_spatial_native_trial_v2.py","tests")):
        require(sha(Path(__file__).with_name(name)) == FROZEN_V2[key], "Frozen Private V2 predecessor changed: "+name)
    require(sha(OBSERVER_SOURCE_ROOT/"review_artifacts/environment_art_sources/private-crew-native-observers/provenance.json") == FROZEN_V2["observer_provenance"], "Frozen Private V2 provenance changed")
    for row in V2_OBSERVER_SPECS.values():
        require(sha(OBSERVER_SOURCE_ROOT/row["artifact_relative"]) == row["sha256"], "Frozen Private V2 inert observer changed")
    root = plain(OBSERVER_SOURCE_ROOT)
    path = plain(root/OBSERVER_PROVENANCE)
    require(sha(path) == OBSERVER_PROVENANCE_SHA,"Exact external observer provenance changed")
    record = read_json(path)
    require(record.get("schema") == "bth.private_crew_external_qa_observers/v3" and
            record.get("observer_specs") == OBSERVER_SPECS and
            record.get("functional_change") is True and record.get("qa_only_typed_target_recovery") is True and
            record.get("frozen_v2") == FROZEN_V2 and record.get("v2_observer_specs") == V2_OBSERVER_SPECS and record.get("production_guard_relaxed") is False and
            record.get("ignore_workaround") is False and
            record["frozen_predecessors"]["policy"] == FROZEN_POLICY_V1_SHA and
            record["frozen_predecessors"]["runner"] == FROZEN_RUNNER_V1_SHA,
            "External observer provenance scope/source bindings differ")
    values = {}
    for target,spec in OBSERVER_SPECS.items():
        relative = PurePosixPath(spec["artifact_relative"])
        require(relative.as_posix() == spec["artifact_relative"] and
                spec["artifact_relative"].startswith("review_artifacts/environment_art_sources/private-crew-native-observers-v3/") and
                relative.name == PurePosixPath(target).name+".txt" and relative.suffix == ".txt" and
                ".." not in relative.parts and not relative.is_absolute(),"Inert observer path escaped exact namespace")
        artifact = plain(root/spec["artifact_relative"])
        info = artifact.stat()
        require(stat.S_ISREG(info.st_mode) and info.st_size == spec["bytes"] <= 256*1024 and
                sha(artifact) == spec["sha256"],"External inert observer bytes differ: "+target)
        values[target] = {"artifact_path":str(artifact),"artifact_relative":spec["artifact_relative"],
                "sha256":spec["sha256"],"bytes":spec["bytes"],"source_kind":"EXTERNAL_QA_GD_TEXT_OVERLAY",
                "selected_Git_source":False,"production_or_export_source":False}
    require(set(values) == set(FRESH_HELPERS),"Exact three external QA observers required")
    return {"schema":"bth.private_crew_qa_observer_overlay/v3","provenance_path":str(path),
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
            "three_GD_texts_and_provenance_bound_to_current_commit":True,
            "raw_GD_targets_archived":False}
