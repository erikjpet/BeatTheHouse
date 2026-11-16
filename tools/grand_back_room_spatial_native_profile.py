"""Exact independently reviewed Grand Back Room V2 native-only policy.

Only exact sentinel files are auxiliary to the logical21 payload. No old
launcher runs. No helper, source, player profile, image or QA storage is written.
"""
import sys
sys.dont_write_bytecode = True

from copy import deepcopy
import json
from pathlib import Path, PurePosixPath
import re
import stat

from bar_spatial_candidate_check import decode_png
from grand_spatial_native_trial import plain, qualified_job, read_json, seal, sha

ROOM = "grand_casino_back_room"
ART = "assets/art/environments/" + ROOM + "/"
MANIFEST = "data/art/environments/" + ROOM + ".json"
BASELINE_SEAL = "065a5f98dfabb2b435bc31af76a0273921a370d1ebb9d9887ce6283c3231fbbb"
INDEX_SHA = "11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24"
RAW_SHA = "91fbde8eb4ebc2c007646eb506dc01bc5b1c8c40cc4baa4d71d088afd7b9ec8d"
IGNORE = b"# Non-active Grand Back Room source/candidates; exclude from Godot discovery.\n"
IGNORE_SHA = "5fc569e3a3c8e2f0ab6bd6d048bb5f87ca6af7b2bb0d8a7b3e39f08346aecf2c"
BASELINE_PROOF = Path("E:/CodexQA/BTH/runs/BTH-ENV-SPATIAL-GBRTRIAL-20261116-assemble01/evidence/grand-back-room-spatial-r1-assembly.json")
BASELINE_PROOF_SHA = "a1d3e98397eba9a9c33119aa5f9103f58dc948abb6f4f57aa5ce1e45599eb206"
BASELINE_JOB_SHA = "49417b4f3dbf2515eaf778411131219d4190eee44b6ad7a3edeaa82107e40c7c"
LEGACY = Path("E:/CodexQA/BTH/workspaces/BTH-ENVART-GRANDBACK-TRIAL-20261115")
HISTORICAL_COMMIT = "94155957c3bdce01d801da013cbcd3eed3289305"
HISTORICAL_TREE = "f85f734dea52e52ec7302e6524858d88308b754e"
# Independent static approval permits an isolated native trial only.
APPROVAL = {"candidate_directory": "grand-back-room-spatial-r1-assembled-v2",
    "package_sha256": "e20695c6715e4156027cc211b6c7291ff2820e3d52d317dbbfc9b6cc5ca931c7",
    "background_sha256": "46492785829f659c5869d91a6510d424ea4977e6921b1ece7de1225aa804e6ca",
    "proof_sha256": "f7663f3a63472499848e490b2c3b844d3a89c2a7d5a33caf4f0b01ae030f3e30",
    "review_sha256": "0e90b08babcd94cc42638154190b63ce49de5f663c138a16df48ceafffd33d9e",
    "recipe_filename": "assemble_grand_back_room_spatial_candidate_v2.py",
    "recipe_sha256": "9ed6c29917c74cdecb044e9639271af631a65e7268ce6015b3b881f50ea6474d",
    "job_sha256": "a0da5fc1e704f4414b0317560e23ce82d5ee7f4f62f1216814f2504d82e5ad89"}
REJECTED_V1 = {"package_sha256": "15d88d5b7438aaebad295dcf6d0748a0a04cf64b3f3f08193be35e1f002b9f04",
    "proof_sha256": "a1d3e98397eba9a9c33119aa5f9103f58dc948abb6f4f57aa5ce1e45599eb206",
    "decision": "ART_NO_GO_DETACHED_OUTER_CORNER_RAIL_STUBS"}
HELPERS = {
    "tools/envart_grandback_preart_metadata.gd": "7f6750153fad8f18ddde9f811ab9cec8946afe96656e23009fa44c7192e4a3c1",
    "tools/envart_grandback_animation_probe.gd": "300dab55f6ca77cb02764dca75e4ec17eb46aac2db7968cd9272e5b4ca5f1e39",
    "tools/envart_grandback_animation_capture.gd": "1831690efa3eee578bcfe4dcfa95ccaf05cab4fb1578e6bf9d7e19cd4a5828f5",
    "tools/environment_art_baseline_capture.gd": "89d7ae812bedd203f49830bf367863bced32d08cfcc5e0327ebaf4450317de8f",
    "tools/environment_layout_screenshots.gd": "eadf8f113aff55113ecf59e764503fd5bc2e4a64d00689573e0b56489b1a78e5",
}
PROVENANCE = {
    "grandback_source_identity.json": "33f53eadd5cdad2b222de01c1a6ef958454b171e75179f23e60281b6a0a5947c",
    "grandback_capture_inputs.json": "98d237141cd6bc1cd1de6de29d57b269677a3eb61943aa1b09b4e984b649ca6e",
    "grandback_trial_package_identity.json": "9718db15092c2655c985b318e41aa0cfa0456d376472f671a3ee3ee1b1b98f0d",
    "grandback_trial_adapter.py": "0141e2d2019d361cdde69b54c8d8810f8679a2577b4f12cd85d7a766da8eb14a",
    "tools/envart_grandback_preart_metadata.gd.uid": "1495f7ce7ad37b071ec37f31119fb7cbd92d622c7101055f02d87aeaf90513df",
    "tools/envart_grandback_animation_probe.gd.uid": "f2fc226a222d877c7f82d68857278a14f9a43998308bb8ef3a4c3bd0dfc29f8c",
    "tools/envart_grandback_animation_capture.gd.uid": "fcebddd90f6587129e9e2dcc752d8dd187d97482c58611291140124110d6267e",
    "tools/environment_art_baseline_capture.gd.uid": "cd3b58fa80239aada2b1e9752d8d3fecda4a0c4d02aa2a9226e1156fd235b7c2",
    "tools/environment_layout_screenshots.gd.uid": "a4e9a7d6067be76eee07ef86e4fb1a37c5fb88096d2626a05ad83057f243cb35",
}
CANONICAL_IMPORTS = {ART + name: digest for name, digest in {
    "background.png.import": "138a8d100071774deba84fbd71b94ea8d6375a90d3d32490961f8378675611b3",
    "counters/grand_table_left.png.import": "c863feaa656cff5af4abe263cbfa8b155da5c47fc7680e6997efea47560bbcf6",
    "counters/grand_table_right.png.import": "3c46ec9761bd521470da4443aea36df4c2d5dac791f9d0705e7f6f0f3fb25128",
    "anim/casino_sign_pulse.png.import": "a600a35652e9bf2dc1c5acc7434491e674b2261f88a6a39e8dd65db51e9fbbc8",
    "anim/casino_light_0.png.import": "8234362944ed95d99618b4a2631b9f835ab6d8fd3caa7848d0eade76932b2010",
    "anim/casino_light_1.png.import": "c502968e1bd999c741d054d97bc1cb1dd22db619374d3f90012aaf9d6afa6e7a",
    "anim/casino_light_2.png.import": "9234fa39a2a93947f77f0f3dc2fd956eceb1c51f3101591fc8ba0fa9f4432d89",
    "anim/casino_light_3.png.import": "2adac9d81a5db5445a4b4f81a7b8c8c07961775d48f59722594b651948dbbe5a",
    "anim/casino_light_4.png.import": "590497f37e8af34d3470f9fb9899646661daa85884410b3dad2c2bd8896f77f6",
}.items()}
ANIMATION_IDS = tuple([f"casino_light_{i}" for i in range(5)] + ["casino_sign_pulse"] +
                      [f"casino_sparkle_{i}" for i in range(3)] + [f"floor_glint_{i}" for i in range(7)])
LOW_IDS = ("casino_light_1", "casino_light_2", "casino_light_3", "casino_sign_pulse", "floor_glint_0", "floor_glint_1", "floor_glint_2")
OBJECT_IDS = {"game:craps", "game:blackjack", "travel:leave"}
COUNTERS = {"grand_table_left": (164, 516, 544, 72), "grand_table_right": (1092, 516, 544, 72)}
MASK_COUNTS = (32, 32, 32, 48, 64, 1632)


def require(ok, message):
    if not ok:
        raise ValueError(message)


def inventory_all(root, expected_names):
    """Exact file/directory closure; no dotfile, cache or metadata exclusions."""
    root = plain(root)
    require(root.is_dir(), "Ordinary source directory required")
    expected_names = set(expected_names)
    allowed_dirs = {parent.as_posix() for name in expected_names for parent in PurePosixPath(name).parents if str(parent) != "."}
    files, directories = {}, set()
    for item in root.rglob("*"):
        path = plain(item)
        name, mode = path.relative_to(root).as_posix(), path.lstat().st_mode
        if stat.S_ISDIR(mode):
            require(name in allowed_dirs, "Unexpected directory: " + name)
            directories.add(name)
        else:
            require(stat.S_ISREG(mode) and name in expected_names, "Unexpected/nonordinary file: " + name)
            files[name] = sha(path)
    require(directories == allowed_dirs and set(files) == expected_names, "Missing/extra exact source paths")
    return files


def baseline_auxiliary(workspace):
    path = plain(workspace / "source_baseline/.gdignore")
    before = path.stat()
    require(stat.S_ISREG(before.st_mode) and before.st_size == len(IGNORE) and path.read_bytes() == IGNORE and sha(path) == IGNORE_SHA,
            "Exact ordinary GBR baseline sentinel required")
    after = path.stat()
    require((before.st_size, before.st_mtime_ns, before.st_ino) == (after.st_size, after.st_mtime_ns, after.st_ino), "Sentinel changed during authentication")
    return {".gdignore": {"path": str(path), "bytes": before.st_size, "sha256": IGNORE_SHA,
        "modified_ns": before.st_mtime_ns, "file_id": before.st_ino, "ordinary_regular_file": True,
        "inspection_access": "read-only", "included_in_art_payload_seal": False, "copied_into_qa_source": False}}


def baseline_state(workspace):
    root = plain(workspace / "source_baseline")
    auxiliary = baseline_auxiliary(workspace)
    for name, expected in {**HELPERS, **PROVENANCE}.items():
        require(sha(LEGACY / name) == expected, "Original observer/provenance changed: " + name)
    old = read_json(LEGACY / "grandback_trial_package_identity.json")["files"]
    expected = {**old, "data/art/environments/index.json": INDEX_SHA}
    job_path = BASELINE_PROOF.parent / "job.json"
    require(sha(BASELINE_PROOF) == BASELINE_PROOF_SHA and sha(job_path) == BASELINE_JOB_SHA and qualified_job(read_json(job_path)),
            "Original closed assembly baseline custody differs; this does not approve its rejected V1 art")
    proof = read_json(BASELINE_PROOF)
    require(len(expected) == 21 and seal(expected) == BASELINE_SEAL and proof["baseline"]["files"] == expected and
            proof["baseline"]["seal"] == BASELINE_SEAL and proof["baseline"]["file_count"] == 21 and plain(proof["baseline"]["path"]) == root,
            "Logical21 baseline membership differs")
    actual = inventory_all(root, {*expected, ".gdignore"})
    require(actual == {**expected, ".gdignore": IGNORE_SHA} and baseline_auxiliary(workspace) == auxiliary,
            "Exact logical21 + authenticated sentinel custody differs")
    return {"payload_files": expected, "payload_file_count": 21, "payload_seal": BASELINE_SEAL,
        "auxiliary_files": auxiliary, "physical_file_count": 22, "all_other_paths_rejected": True}


def baseline_files(workspace):
    return baseline_state(workspace)["payload_files"]


def source_contract(workspace, baseline):
    sources = plain(workspace / "candidate_sources")
    required = {".gdignore", "grand-back-room-spatial-r1.png", "grand-back-room-spatial-r1.png.b64", "prompt.txt", "provenance.json"}
    for name in required:
        path = plain(sources / name)
        require(stat.S_ISREG(path.lstat().st_mode), "Ordinary preserved GBR source required")
    require((sources / ".gdignore").read_bytes() == IGNORE and sha(sources / ".gdignore") == IGNORE_SHA and
            sha(sources / "grand-back-room-spatial-r1.png") == RAW_SHA, "Exact raw/sentinel custody required")
    directories = {parent.as_posix() for name in baseline for parent in PurePosixPath(name).parents if str(parent) != "."}
    packages = []
    for child in sources.iterdir():
        plain(child)
        if child.name in required and child.is_file():
            continue
        require(child.is_dir() and re.fullmatch(r"grand-back-room-spatial-r1-assembled-v[1-9][0-9]*", child.name), "Unexpected quarantined GBR source")
        for path in child.rglob("*"):
            plain(path)
            name = path.relative_to(child).as_posix()
            require((path.is_file() and name in baseline) or (path.is_dir() and name in directories), "Unexpected quarantined package member")
        packages.append(child.name)
    require(required <= {path.name for path in sources.iterdir()}, "Preserved raw/base64/prompt/provenance closure missing")
    return {"baseline_auxiliary": {"source_baseline/.gdignore": IGNORE_SHA},
            "candidate_source_auxiliary": {name: sha(sources / name) for name in sorted(required)}, "quarantined_package_folders": sorted(packages)}


def canonical_imports(root):
    for name, expected in CANONICAL_IMPORTS.items():
        require(sha(root / name) == expected, "Canonical GBR import must already be committed/preserved; no auto-copy: " + name)


def candidate(root, workspace, proof_path, review_path, baseline):
    require(APPROVAL is not None, "WAITING_FOR_FINAL_GBR_STATIC_GO: V1 is rejected; no candidate/native admission")
    admitted = APPROVAL
    root, proof_path, review_path = map(plain, (root, proof_path, review_path))
    proof, review = read_json(proof_path), read_json(review_path)
    require(root == workspace / "candidate_sources" / admitted["candidate_directory"] and sha(proof_path) == admitted["proof_sha256"] and
            sha(review_path) == admitted["review_sha256"] and review.get("native_trial_approved") is True and
            review.get("decision") in ("STATIC_GO_FOR_NATIVE_TRIAL", "GO_FOR_NATIVE_TRIAL_ONLY") and
            review.get("independent_reviewer") == "/root/audit_spatial_handoff" and review.get("package_21_file_sha256") == admitted["package_sha256"] and
            review.get("assembly_proof_sha256") == admitted["proof_sha256"] and review.get("executed_recipe_sha256") == admitted["recipe_sha256"],
            "Exact independent final native-only approval required")
    files = proof["output"]["files"]
    require(proof.get("recipe_sha256") == admitted["recipe_sha256"] and plain(proof["output"]["path"]) == root and
            plain(proof["baseline"]["path"]) == workspace / "source_baseline" and proof["baseline"]["files"] == baseline and
            proof.get("ignore_sentinels_excluded_from_logical_21_file_payload") is True and
            {plain(name) for name in proof.get("auxiliary_ignore_sentinels", [])} == {workspace / "source_baseline/.gdignore", workspace / "candidate_sources/.gdignore"} and
            set(files) == set(baseline) and inventory_all(root, baseline) == files and seal(files) == proof["output"]["seal"] == admitted["package_sha256"] and
            files[ART + "background.png"] == admitted["background_sha256"], "Approved logical21/source/sentinel custody changed")
    require(seal(files) != REJECTED_V1["package_sha256"], "Rejected V1 cannot be admitted")
    job_path, recipe = proof_path.parent / "job.json", Path(__file__).with_name(admitted["recipe_filename"])
    job = read_json(job_path)
    require(sha(job_path) == admitted["job_sha256"] and qualified_job(job) and sha(recipe) == admitted["recipe_sha256"] and
            len(job.get("command", [])) >= 3 and job["command"][1] == "-B" and plain(job["command"][2]) == plain(recipe), "Exact repair recipe and closed guarded assembly required")
    changed_png = {name[:-7] for name in CANONICAL_IMPORTS}
    require({name for name in files if files[name] != baseline[name]} == changed_png | {MANIFEST}, "Only exact nine PNGs + roomJSON may differ")
    old = read_json(workspace / "source_baseline" / MANIFEST)
    spec, expected = read_json(root / MANIFEST), deepcopy(old)
    require([row["id"] for row in old["animations"]] == list(ANIMATION_IDS) and
            expected["animations"][2]["rect"] == [450, 124, 52, 8], "Original16/geometry changed")
    expected["animations"][2]["rect"][0] = 448
    require(type(spec["animations"][2]["rect"][0]) is int and
            json.dumps(spec, sort_keys=True, separators=(",", ":")) == json.dumps(expected, sort_keys=True, separators=(",", ":")),
            "Only lamp2 integer x450->448 admitted; all other geometry/timing/flags frozen")
    require([row["id"] for row in spec["animations"] if row.get("web_low_detail")] == list(LOW_IDS), "Seven low-detail entries changed")
    master = decode_png((root / (ART + "background.png")).read_bytes())
    original = decode_png((workspace / "source_baseline" / (ART + "background.png")).read_bytes())
    require((master.width, master.height) == (1800, 860) and set(master.rgba[3::4]) == {255}, "Opaque1800x860 master required")
    metrics = {}
    for index, entry in enumerate(spec["animations"][:6]):
        name = ART + entry["texture"]
        image, prior_image = (decode_png((parent / name).read_bytes()) for parent in (root, workspace / "source_baseline"))
        bx, by, width, height = entry["rect"]
        require((image.width, image.height) == (width * 2, height * 2), "Pulse mask size changed")
        active = 0
        for y in range(image.height):
            for x in range(image.width):
                at = (y * image.width + x) * 4
                pos = ((by * 2 + y) * 1800 + bx * 2 + x) * 4
                r, g, b, alpha = original.rgba[pos:pos + 4]
                selected = (r >= 150 and b >= 80 and r >= g + 40 and b >= g + 20) if index == 5 else (r >= 70 and g >= 20 and r >= b + 20)
                require(image.rgba[at:at + 3] == prior_image.rgba[at:at + 3] and
                        image.rgba[at + 3] == (prior_image.rgba[at + 3] if selected else 0), "Mask must be exact original-RGB alpha-only material cut")
                if selected:
                    require(alpha == 255 and image.rgba[at + 3] > 0, "Actual trim/subtitle material absent")
                    active += 1
        require(active == MASK_COUNTS[index], "Actual visible mask coverage changed")
        metrics[entry["id"]] = {"rect": entry["rect"], "visible_material_pixels": active, "alpha_cut_only": True}
    crops = {}
    for name, (x, y, width, height) in COUNTERS.items():
        image = decode_png((root / (ART + "counters/" + name + ".png")).read_bytes())
        wanted = b"".join(master.rgba[((y + row) * 1800 + x) * 4:((y + row) * 1800 + x + width) * 4] for row in range(height))
        require((image.width, image.height) == (width, height) and image.rgba == wanted, "Replay crop is not exact master pixels")
        crops[name] = {"native_rect": [x, y, width, height], "exact_master_crop": True}
    return {"files": files, "package_sha256": admitted["package_sha256"], "candidate_root": str(root), "review_sha256": admitted["review_sha256"],
        "candidate_manifest_sha256": admitted["proof_sha256"], "assembly_job_sha256": admitted["job_sha256"],
        "approved_repair_recipe_sha256": admitted["recipe_sha256"], "exact_counter_crops": crops, "visible_practical_masks": metrics,
        "review": review, "production_art_written": False, "test_updated": False}
