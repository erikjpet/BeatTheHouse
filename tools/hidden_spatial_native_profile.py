"""Exact Hidden native-only policy; original assertions and case code retained.

The core five-GD observer closure is distinct from fourteen additional original
acceptance/dependency observers. Only documented quoted historical input paths
may translate; current-source hash metadata is explicitly rebound and reported.
No helper launch, file mutation, art activation or metadata auto-copy occurs here.
"""
import sys
sys.dont_write_bytecode = True

from copy import deepcopy
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat

from bar_spatial_candidate_check import decode_png
from grand_spatial_native_trial import plain, qualified_job, read_json, seal, sha

ROOM = "small_underground_casino"
ART = "assets/art/environments/" + ROOM + "/"
MANIFEST = "data/art/environments/" + ROOM + ".json"
WORKSPACE_NAME = "BTH-ENV-SPATIAL-HIDDENTRIAL-20261116"
LEGACY = Path("E:/CodexQA/BTH/workspaces/BTH-ENVART-INTEGRATION-20261114")
LEGACY_CANVAS = Path("E:/CodexQA/BTH/workspaces/BTH-ENVART-HIDDEN-BASELINE-20261114/scripts/ui/pixel_scene_canvas.gd")
LEGACY_CANVAS_SHA = "87f2f0f723e6f4098ffb4dc37baf608e523e3707f7610f6b78c7b688b08e3cb9"
HISTORICAL_COMMIT = "74c85e44577b34eaf7e9c1f857e62b2c999c1fbc"
BASELINE_SEAL = "4c43fd48d180010a801f511c885d44b983c67c2fbb7fb4eac25c94fbdab027ff"
INDEX_SHA = "11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24"
RAW_SHA = "8a46e49c462f741b75c79099bf6480092fb11a498bd138fc5e9498be5a3bee99"
IGNORE = b"# Non-active Hidden source/baseline/candidates; exclude from Godot discovery.\n"
IGNORE_SHA = "de8596593fe700a21cd4015d5e6f0a9f27630963e9b7ecf65446d1f0d3b90206"
ASSEMBLY_EVIDENCE = Path("E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-HIDDENTRIAL-20261116-assemble01/evidence")
APPROVAL = {
    "candidate_directory": "hidden-spatial-r1-assembled-v1",
    "package_sha256": "508b106419ef299aad27d92f4d54c5c4d1f7e6cf353dff546848ed290a273509",
    "background_sha256": "ab8460c410c07e1ad13ed6bd8ea10db091ff2e3528861f15c06543d2e6199060",
    "proof_sha256": "ad79d829e991cefc0f3d8daebd1d4c98a282a1dce5f013de5e09cd1b69d1f7c3",
    "review_sha256": "09af35c34796e320e872bbe07dd833ae0073c511b08c438f1d44897145b8e05e",
    "recipe_filename": "assemble_hidden_spatial_candidate.py",
    "recipe_sha256": "2a195a32e6ff03e0f1a7a134448455e24676597e3c595fe9c32cdf4ab620268f",
    "job_sha256": "c28f74d8f65fd18fb0eab0efef3fc0994ce12bf0c8989f126378d73ef9230902",
}
COUNTERS = {"punchline_right_table": (876, 284, 572, 196)}
ANIMATION_IDS = tuple([f"string_core_{i}" for i in range(10)] +
    [f"long_pink_drift_{i}" for i in range(6)] + [f"thin_bobbing_ribbon_{i}" for i in range(5)] +
    [f"teal_material_glint_{i}" for i in range(3)] + [f"floor_glint_{i}" for i in range(7)])
LOW_IDS = ANIMATION_IDS
CONTEXT_COUNTS = {"__none": 12, "punchline_high_stakes_night": 20, "punchline_greased_week": 20, "punchline_new_muscle": 19}
BATCH_SCENARIOS = {"work-highstakes": "punchline_high_stakes_night", "work-greased": "punchline_greased_week", "work-muscle": "punchline_new_muscle"}
BATCH_CHECKS = {"work-highstakes": 964, "work-greased": 1097, "work-muscle": 1061}
CATALOG_PATH = "tools/envart_hidden_sequence_cases.json"
CATALOG_SOURCE_SHA = "3951bd2688f373e07fda9c4a17da39105a818e872bdf01ec0b30cf89d4c582f1"
HELPERS = {
    "tools/envart_hidden_initial_r2.gd": "6242a77d0c13bf2279ee7bff0ab66ea02b3a0f260e31ce450c6829bb496aba7e",
    "tools/envart_hidden_animation_probe_r2.gd": "3bebcb3935fa6da0042c5444c8b843eb94a20cc73d36544ad8dbaaaba8b5ae74",
    "tools/envart_hidden_animation_capture_r2.gd": "747c81ab0328bdda44ebbbd0a08aa101db991be81fa26685cf99b08fdb9412bc",
    "tools/environment_art_baseline_capture.gd": "89d7ae812bedd203f49830bf367863bced32d08cfcc5e0327ebaf4450317de8f",
    "tools/environment_layout_screenshots.gd": "eadf8f113aff55113ecf59e764503fd5bc2e4a64d00689573e0b56489b1a78e5",
    "tools/envart_hidden_current_rm_r2.gd": "f3e0af9b3ec0674f3c1bd426f8a5df079c3dcb9c11f87c936668a70936719a80",
    "tools/envart_hidden_full_composite_r2.gd": "cd04377ca200b4b1a0f9de7f66e07fe7993df4a65d29696bb280d041dab29795",
    "tools/envart_hidden_full_composite_rm_r2.gd": "fe98cf94b03f6b6db481a41c39f1cab2fa735b23776d72a9015343da876b45b6",
    "tools/envart_hidden_source_paint_r2.gd": "6564cb67933aa652b9a8685be3315611c3881a99f62a95aac5ac3a4a08404268",
    "tools/envart_hidden_counter_replay_r2.gd": "13c967cc7303eb1db87a6f2ce55c4df8e90b262f50999e4139be60988b8e492a",
    "tools/envart_hidden_floor_wrap_r2.gd": "6cbd49b04183f21a53f378a26494a9ae3555bd1facf090d8984bdd3f7d4eb552",
    "tools/envart_hidden_long_wrap_r2.gd": "72832ff1d98f3803ffbd8f148157ee39322bae6f82e97d03b8a107c847b3e4b8",
    "tools/envart_hidden_thin_wrap_r2.gd": "92a62c5ca85578c2c99eb877d44f55feddcfd9d7eaaa1b87b5d12364bc50441d",
    "tools/envart_hidden_sequence_proof_r2.gd": "ddfeea5fe92cdab79839ca1c2870f09751b4f544e42ce8fb219688fce61f4225",
    "tools/envart_back_settled_r3.gd": "f2ef6277a5b3ace0e889e93fb6cf48bad43bb692cc4175ff9e5e9a32854c0f8b",
    "tools/envart_hidden_effective_hits_r2.gd": "57f075bfa4ce558690708b065ef26b572ab18dc291425045961a63c9c1dc9a58",
    "tools/envart_hidden_placement_closing_r2.gd": "4a1abbf6a3bda75ee7e036da04306c8e36a9c243fe5f781affe432bc404f412b",
    "tools/envart_hidden_glint_focus_r2.gd": "8a9a0e00f7940868f378b951ddfdea72e049ea493f0886060643807703c50d2c",
    "tools/envart_hidden_glint_source_paint_r2.gd": "d272f6711e50dd1e18ea5585d9ee138752750bc57d870aefba6eb456c0596571"
}
PROVENANCE = {
    "tools/environment_art_baseline_capture.gd.uid": "708afdcec3ca03146dfe23f9dd510da5864d36cd14140586dde7dbb554975269",
    "tools/environment_layout_screenshots.gd.uid": "a4e9a7d6067be76eee07ef86e4fb1a37c5fb88096d2626a05ad83057f243cb35",
    "tools/envart_back_settled_r3.gd.uid": "4c3d99d31226c3522f42333a1a572b192c57e34d72b8a77f9e4fee3cce04a152",
    "hidden_r2_trial_identity.json": "37bee66a5b0b232f3d199d7a15c7ccfd75ec4094d446b18102a4395694f86cd6",
    "hidden_r2_initial_inputs.json": "5177124ab61b6fc5c736bc3b230201218a8a90f85d04862c9199d39ee18c14dd",
    "tools/envart_hidden_sequence_cases.json": "b11dd32c354037e96fb2cc1ca7911ec674b494b3f11cf976a658f8ca248c4c7f"
}
CANONICAL_IMPORTS = {
    "assets/art/environments/small_underground_casino/background.png.import": "773f6f18b28586db955960b2adddd9231295e5ad660430606bfd0c7cb2816ca6",
    "assets/art/environments/small_underground_casino/counters/punchline_right_table.png.import": "e3f8d3f8d8b4364c12004bde4152b86248deda796b42eb0da87e3e8d63f01f77"
}
SOURCE_AUX = {
    ".gdignore": "de8596593fe700a21cd4015d5e6f0a9f27630963e9b7ecf65446d1f0d3b90206",
    "hidden-r2-source.zip": "6ed40caf03d5a694bbef49f338dd26f5e4f4f61341a9166c04121312632c938f",
    "hidden-spatial-r1.png": "8a46e49c462f741b75c79099bf6480092fb11a498bd138fc5e9498be5a3bee99",
    "hidden-spatial-r1.png.b64": "8a3543591309ef2cbd4b6c35e7edf7f0ffee95f0124e79a6b4d74dce3023a6f3",
    "prompt.txt": "e72e6eaf13d4ccc49bf89907c4218693c4bac3b2d1aa3d493d1ed6dcffdf338e",
    "provenance.json": "519953d96b4dea2e6931a876a5dfb56689a16d2db0189de63637ddae5881a6e3"
}
CASE_IDS = [
    "punchline_high_stakes_night__active_phase_arrival",
    "punchline_high_stakes_night__active_phase_work_1",
    "punchline_high_stakes_night__active_phase_work_2",
    "punchline_high_stakes_night__active_phase_work_3",
    "punchline_high_stakes_night__aftermath_floor_remains_protected",
    "punchline_high_stakes_night__aftermath_service_refused",
    "punchline_high_stakes_night__aftermath_session_interrupted",
    "punchline_high_stakes_night__aftermath_public_lane_restored",
    "punchline_greased_week__active_phase_arrival",
    "punchline_greased_week__active_phase_work_1",
    "punchline_greased_week__active_phase_work_2",
    "punchline_greased_week__active_phase_work_3",
    "punchline_greased_week__active_phase_work_4",
    "punchline_greased_week__aftermath_payoff_maintained",
    "punchline_greased_week__aftermath_route_refused",
    "punchline_greased_week__aftermath_inspection_interrupted",
    "punchline_greased_week__aftermath_chain_exposed",
    "punchline_new_muscle__active_phase_arrival",
    "punchline_new_muscle__active_phase_work_1",
    "punchline_new_muscle__active_phase_work_2",
    "punchline_new_muscle__active_phase_work_3",
    "punchline_new_muscle__active_phase_work_4",
    "punchline_new_muscle__aftermath_checkpoint_entrenched",
    "punchline_new_muscle__aftermath_test_refused",
    "punchline_new_muscle__aftermath_checkpoint_interrupted",
    "punchline_new_muscle__aftermath_posts_reassigned"
]

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


def original_observers():
    for name, value in {**HELPERS, **PROVENANCE}.items():
        require(sha(plain(LEGACY / name)) == value, "Original observer/provenance changed: " + name)
    require(sha(plain(LEGACY_CANVAS)) == LEGACY_CANVAS_SHA, "Original strict canvas changed")
    return {**HELPERS, **PROVENANCE, str(LEGACY_CANVAS): LEGACY_CANVAS_SHA}


def baseline_auxiliary(workspace):
    path = plain(workspace / "source_baseline/.gdignore")
    before = path.stat()
    require(stat.S_ISREG(before.st_mode) and before.st_size == len(IGNORE) == 78 and
            path.read_bytes() == IGNORE and sha(path) == IGNORE_SHA, "Exact ordinary78-byte Hidden sentinel required")
    after = path.stat()
    require((before.st_size, before.st_mtime_ns, before.st_ino) == (after.st_size, after.st_mtime_ns, after.st_ino),
            "External baseline sentinel changed during read")
    return {".gdignore": {"path": str(path), "bytes": before.st_size, "sha256": IGNORE_SHA,
        "modified_ns": before.st_mtime_ns, "file_id": before.st_ino, "ordinary_regular_file": True,
        "inspection_access": "read-only", "included_in_art_payload_seal": False, "copied_into_qa_source": False}}


def assembly_proof():
    path, job_path = ASSEMBLY_EVIDENCE / "hidden-spatial-r1-assembly.json", ASSEMBLY_EVIDENCE / "job.json"
    require(sha(path) == APPROVAL["proof_sha256"] and sha(job_path) == APPROVAL["job_sha256"] and qualified_job(read_json(job_path)),
            "Exact closed guarded Hidden assembly proof/Job required")
    return read_json(path)


def baseline_state(workspace):
    original_observers()
    auxiliary = baseline_auxiliary(workspace)
    proof = assembly_proof()
    expected = proof["baseline"]["files"]
    root = plain(workspace / "source_baseline")
    require(len(expected) == 30 and seal(expected) == BASELINE_SEAL == proof["baseline"]["seal"] and
            proof["baseline"]["file_count"] == 30 and plain(proof["baseline"]["path"]) == root and
            proof["recipe_sha256"] == APPROVAL["recipe_sha256"], "Exact logical30 Hidden baseline binding required")
    require(inventory_all(root, {*expected, ".gdignore"}) == {**expected, ".gdignore": IGNORE_SHA} and
            baseline_auxiliary(workspace) == auxiliary, "Logical30 plus exact sole sentinel custody differs")
    return {"payload_files": expected, "payload_file_count": 30, "payload_seal": BASELINE_SEAL,
            "auxiliary_files": auxiliary, "physical_file_count": 31, "all_other_paths_rejected": True}


def baseline_files(workspace):
    return baseline_state(workspace)["payload_files"]


def source_contract(workspace, baseline):
    proof = assembly_proof()
    root = plain(workspace / "candidate_sources")
    expected = {**SOURCE_AUX, **{APPROVAL["candidate_directory"] + "/" + name: value for name, value in proof["output"]["files"].items()}}
    require(inventory_all(root, expected) == expected, "Exact sole Hidden source/candidate physical closure changed")
    require((root / ".gdignore").read_bytes() == IGNORE, "Candidate-parent sentinel changed")
    return {"candidate_source_files": expected, "baseline_auxiliary": {"source_baseline/.gdignore": IGNORE_SHA},
            "quarantined_package_folders": [APPROVAL["candidate_directory"]], "no_auxiliary_copied_to_qa_source": True}


def canonical_imports(root):
    for name, expected in CANONICAL_IMPORTS.items():
        require(sha(plain(root / name)) == expected, "Root must commit exact canonical Hidden import; no auto-copy: " + name)


def candidate(root, workspace, proof_path, review_path, baseline):
    root, proof_path, review_path = map(plain, (root, proof_path, review_path))
    proof, review = read_json(proof_path), read_json(review_path)
    require(root == workspace / "candidate_sources" / APPROVAL["candidate_directory"] and
            proof_path == ASSEMBLY_EVIDENCE / "hidden-spatial-r1-assembly.json" and
            sha(proof_path) == APPROVAL["proof_sha256"] and sha(review_path) == APPROVAL["review_sha256"] and
            review.get("decision") == "STATIC_GO_FOR_NATIVE_TRIAL" and review.get("native_trial_approved") is True and
            review.get("independent_reviewer") == "/root/audit_spatial_handoff" and
            review.get("package_30_file_sha256") == APPROVAL["package_sha256"] and
            review.get("assembly_proof_sha256") == APPROVAL["proof_sha256"] and
            review.get("executed_recipe_sha256") == APPROVAL["recipe_sha256"], "Exact Hidden native-only static review required")
    files = proof["output"]["files"]
    require(len(files) == 30 and set(files) == set(baseline) and proof["baseline"]["files"] == baseline and
            inventory_all(root, files) == files and seal(files) == proof["output"]["seal"] == APPROVAL["package_sha256"] and
            files[ART + "background.png"] == APPROVAL["background_sha256"] and proof["recipe_sha256"] == APPROVAL["recipe_sha256"],
            "Reviewed Hidden candidate/source binding changed")
    recipe = Path(__file__).with_name(APPROVAL["recipe_filename"])
    job = read_json(proof_path.parent / "job.json")
    require(sha(recipe) == APPROVAL["recipe_sha256"] and qualified_job(job) and
            len(job["command"]) >= 3 and job["command"][1] == "-B" and plain(job["command"][2]) == plain(recipe),
            "Exact executed Hidden recipe/closed producer required")
    expected_changes = {name[:-7] for name in CANONICAL_IMPORTS}
    require({name for name in files if files[name] != baseline[name]} == expected_changes, "Only background/right-front PNGs may differ")
    spec = read_json(root / MANIFEST)
    require((root / MANIFEST).read_bytes() == (workspace / "source_baseline" / MANIFEST).read_bytes() and
            (root / "data/art/environments/index.json").read_bytes() == (workspace / "source_baseline/data/art/environments/index.json").read_bytes(),
            "Full manifest/index must remain byte-exact")
    require([r["id"] for r in spec["animations"]] == list(ANIMATION_IDS) and
            all(r.get("web_low_detail", True) is True for r in spec["animations"]) and
            len({r["texture"] for r in spec["animations"]}) == 26 and set(spec["counters"]) == set(COUNTERS),
            "Hidden native31/default-low31/unique26/right-only contract differs")
    master = decode_png((root / (ART + "background.png")).read_bytes())
    require((master.width, master.height) == (1800, 860) and set(master.rgba[3::4]) == {255}, "Opaque native1800x860 required")
    crops = {}
    for name, (x, y, width, height) in COUNTERS.items():
        front = decode_png((root / (ART + "counters/" + name + ".png")).read_bytes())
        wanted = b"".join(master.rgba[((y+r)*1800+x)*4:((y+r)*1800+x+width)*4] for r in range(height))
        require((front.width, front.height) == (width, height) and front.rgba == wanted, "Right front must be exact opaque final-master crop")
        crops[name] = {"native_rect": [x,y,width,height], "exact_master_crop": True}
    return {"files": files, "package_sha256": APPROVAL["package_sha256"], "candidate_root": str(root),
        "review_sha256": APPROVAL["review_sha256"], "candidate_manifest_sha256": APPROVAL["proof_sha256"],
        "assembly_job_sha256": APPROVAL["job_sha256"], "approved_repair_recipe_sha256": APPROVAL["recipe_sha256"],
        "exact_counter_crops": crops, "native_entries":31, "default_low_detail_entries":31, "unique_motion_pngs":26,
        "review": review, "production_art_written":False, "test_updated":False}


def literal_bindings(cfg):
    evidence = lambda phase: (Path(cfg["qa_root"]) / "runs" / (cfg["run_prefix"] + "-" + phase) / "evidence").as_posix()
    old = "E:/CodexQA/BTH/runs/BTH-ENVART-HIDDENR2-20261114-"
    initial = {str(LEGACY.as_posix()) + "/hidden_r2_initial_inputs.json": "res://hidden_capture_inputs.json"}
    return {
        "tools/envart_hidden_initial_r2.gd": initial,
        "tools/envart_hidden_current_rm_r2.gd": initial,
        "tools/envart_hidden_source_paint_r2.gd": {old+"composite01/evidence/hidden_full_composite.json": evidence("full-composite")+"/hidden_full_composite.json"},
        "tools/envart_hidden_glint_source_paint_r2.gd": {old+"glint-focus01/evidence/hidden_glint_focus.json": evidence("glint-focus")+"/hidden_glint_focus.json"},
        "tools/envart_hidden_effective_hits_r2.gd": {
            old+"current4-01/evidence/hidden_r2_initial_metadata.json": evidence("contexts")+"/hidden_r2_initial_metadata.json",
            old+"sequence-": (Path(cfg["qa_root"])/"runs"/(cfg["run_prefix"]+"-work-")).as_posix(),
            "-01/evidence/hidden_sequence_live_proof.json": "/evidence/hidden_sequence_live_proof.json"},
    }


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


def rebind_catalog(original, source_hashes, workspace):
    value = deepcopy(original)
    require(original.get("counts") == {"scenarios":3,"active_phase_cases":14,"aftermath_cases":12,
            "primary_cases":26,"base_initial_additional":1,"source_branch_edges":76} and
            case_ids(original) == CASE_IDS and original["source_sha256"] == CATALOG_SOURCE_SHA,
            "Exact original Hidden26-case catalog required")
    require(set(source_hashes) == set(original["source_files_sha256"]) and
            all(type(value) is str and re.fullmatch(r"[0-9a-f]{64}", value) for value in source_hashes.values()) and
            source_hashes[original["source"]] == CATALOG_SOURCE_SHA, "Fresh actual source bindings cannot change declared case facts")
    value["source_files_sha256"] = dict(source_hashes)
    value["source_workspace"] = str(workspace)
    require({k:v for k,v in value.items() if k not in ("source_files_sha256","source_workspace")} ==
            {k:v for k,v in original.items() if k not in ("source_files_sha256","source_workspace")},
            "Only explicitly allowed current-source metadata may rebind")
    return value


def case_ids(catalog):
    return [r["scenario_id"]+"__"+r["kind"]+"_"+r.get("outcome",r.get("phase","")) for r in catalog["cases"]]


def no_findings(report):
    require(not report.get("findings") and not report.get("failures"), "Original native assertions reported findings/failures")


def report_contract(phase, report, *, source_files=0):
    """Room-specific assertions; original observers retain their own full gates."""
    no_findings(report)
    if phase in ("contexts","current-rm"):
        require(set(report["views"]) == set(CONTEXT_COUNTS), "Exactly four Hidden initial contexts required")
        total = 0
        for scenario, count in CONTEXT_COUNTS.items():
            view = report["views"][scenario]
            ids = {r["id"] for r in view["actual_view"]["objects"]}
            labels = {r["id"] for r in view["selected_label_evidence"]}
            require(len(ids) == count and ids == labels and len(view["selected_label_evidence"]) == count,
                    "Actual object/selected-label membership differs: "+scenario)
            total += count
        expected = 2 * source_files + (609 if phase == "contexts" else 400)
        require(report["checks"] == expected, "Original2N+609/2N+400 source assertions changed")
        return {"initial_objects":total, "selected_labels":total, "typed_pairs_in_this_report":0}
    if phase == "motion":
        rows = report["entries"]
        require(report["checks"] == 63 and [r["id"] for r in rows] == list(ANIMATION_IDS) and
                all(r["live_visible_change"] is True and r["reduce_motion_stable"] is True for r in rows),
                "Original31-entry/63-check native renderer contract changed")
        return {"native_entries":31,"default_low_detail_membership":31,"unique_motion_pngs":26,
                "low_detail_scope":"All31 manifest flags defaulttrue; no invented separate16/7 pixel run."}
    if phase in ("source-paint","glint-source-paint"):
        rows = report["contexts"]
        require({r["scenario"] for r in rows} == set(CONTEXT_COUNTS), "All four typed-paint contexts required")
        for row in rows:
            require(row["geometry_equal"] is True and len(row["objects"]) == CONTEXT_COUNTS[row["scenario"]],
                    "Typed source-paint membership/geometry differs")
        require(sum(len(r["objects"]) for r in rows) == 71, "Separate71 typed object pairs required")
        return {"typed_object_pairs":71,"typed_pngs":142,"initial_union_is_a_different_report":True}
    if phase in BATCH_SCENARIOS:
        scenario = BATCH_SCENARIOS[phase]
        expected = [name for name in CASE_IDS if name.startswith(scenario+"__")]
        require(report["checks"] == BATCH_CHECKS[phase] and report["completed"] == expected and
                report["batch_scope"]["selected_case_ids"] == expected and
                report["batch_scope"]["explicitly_skipped_case_ids"] == [] and
                report["batch_scope"]["full_catalog_count"] == 26 and
                all(report["views"][name]["case_passed"] is True and not report["views"][name]["case_findings"] for name in expected),
                "Exact source-derived Hidden primary case batch/assertions changed")
        return {"primary_cases":len(expected),"case_ids":expected,"actual_transactions_and_publication":True}
    if phase in ("full-composite","full-composite-rm","glint-focus"):
        rows = report["scenarios"]
        ids = ["teal_material_glint_1"] if phase=="glint-focus" else list(ANIMATION_IDS)
        require(report["checks"] == {"full-composite":435,"full-composite-rm":528,"glint-focus":45}[phase] and
                {r["scenario"] for r in rows} == set(CONTEXT_COUNTS), "Original four-context composite assertions changed")
        for row in rows:
            require(row["processing_remained_active"] is True and [r["id"] for r in row["entries"]] == ids,
                    "Original complete composite roster/processing changed")
            for item in row["entries"]:
                require(item["actual_objects_layout_equal"] is True and item["identical_control_pixels"] is True and
                        item["object_route_label_clocks_equal"] is True and
                        item["reduce_motion_composite_stable" if phase=="full-composite-rm" else "visible_composite_change"] is True,
                        "Actual composite motion/control/geometry assertion failed")
        return {"contexts":4,"entries_per_context":len(ids),"checks":report["checks"]}
    if phase in ("floor-wrap","long-wrap","thin-wrap"):
        expected = {"floor-wrap":(7,71,"floor_glint_"),"long-wrap":(6,61,"long_pink_drift_"),"thin-wrap":(5,246,"thin_bobbing_ribbon_")}[phase]
        require(report["checks"] == expected[1] and [r["id"] for r in report["glints"]] == [expected[2]+str(i) for i in range(expected[0])] and
                all(r["clean_offscreen_wrap"] is True and r["actual_midpoint_pixels_differ"] is True for r in report["glints"]),
                "Original distinct air/floor family wrap contract failed")
        return {"entries":expected[0],"checks":expected[1]}
    if phase == "counter-replay":
        require(report["ok"] is True and report["production_objects_moved"] is False and len(report["cases"])==1 and
                report["cases"][0]["counter_id"]=="punchline_right_table" and
                report["cases"][0]["counter_pixel_mismatches"]==0 and report["cases"][0]["upper_person_unchanged"] is True,
                "Exact right-only opaque replay/body-depth contract failed")
        return {"right_front_exact":True,"no_left_front_added":True}
    if phase == "effective-hits":
        require(report["checks"] == 9461 and len(report["contexts"]) == 27 and
                {r["case_id"] for r in report["contexts"]} == {"__none",*CASE_IDS} and
                all(r["normal_layout_equal"] is True and r["RM_layout_equal"] is True and r["prior_layout_equal"] is True
                    for r in report["contexts"]), "Original Base+26 ordered-hit/normal/RM geometry contract changed")
        return {"contexts":27,"checks":9461}
    if phase == "placement":
        require(report["checks"]==9 and report["source_open_hours_raw"] is None and report["open_hours"]=={} and
                report["closing_triggered"] is False, "Original always-open placement/no-closing semantics changed")
        return {"checks":9,"always_open":True,"invented_closing_test":False}
    raise ValueError("No Hidden report contract for phase: "+phase)
