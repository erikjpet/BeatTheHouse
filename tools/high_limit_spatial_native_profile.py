"""Immutable High Limit R1 native-only policy. No children or writes."""
import sys
sys.dont_write_bytecode = True

from copy import deepcopy
import json
from pathlib import Path

from bar_spatial_candidate_check import decode_png
from grand_spatial_native_trial import plain, qualified_job, read_json, scan, seal, sha

ROOM = "grand_casino_high_limit"
ART = "assets/art/environments/" + ROOM + "/"
MANIFEST = "data/art/environments/" + ROOM + ".json"
BASELINE_SEAL = "69c7023d0dae2468f73dc4c836d055d29592443c42cb72060901ef1390c97c93"
PACKAGE_SEAL = "481e858ee3c484b06ba6df935983c29979a188e7e59ff5f44eaf22ecdbe020e4"
BACKGROUND_SHA = "25242d74d442bc99b183845c75b5714983db081100b4020780645976e7f7fb50"
RAW_SHA = "ad4bfe68a0444cecd1914ba75ae2986cb1b797509eb6347f5df42f3231492911"
RECIPE_SHA = "5fe162da9488e47aef545d7e60ae00908f1bd3f9899451a8ad791218ee516855"
REVIEW_SHA = "fc22fc88981f495136b85e66853b127ccd35e836460c0a54247284969ba86ae1"
PROOF_SHA = "7c6d9bb22051150f57637b03bf4870396e6f111f4b5c008807631d253036ce77"
ASSEMBLY_JOB_SHA = "b7c46c204b9a984b87d7b4be631b440048d722ddf857b21177249f87e54e06d4"
LEGACY = Path("E:/CodexQA/BTH/workspaces/BTH-ENVART-HIGHLIMIT-TRIAL-20261115")
HISTORICAL_COMMIT = "d0bb57dcd98ab11d0c5e57f28a36f2c88b1a07f6"
HELPERS = {
    "tools/envart_highlimit_preart_metadata.gd": "b6a43a9b9a62e447c06c544c1c2eef49039226350bd0da7af0455036070f769f",
    "tools/envart_highlimit_animation_probe.gd": "b5d1ee7d9a9598545e8b0c50fa98901cf1c24b7f955f0ac5a47ecd048254e30b",
    "tools/envart_highlimit_animation_capture.gd": "7770ec597d1909281d6707804d6cc7b4b4434d15cb8dab0107ec1e4a5f98b9df",
    "tools/environment_art_baseline_capture.gd": "89d7ae812bedd203f49830bf367863bced32d08cfcc5e0327ebaf4450317de8f",
    "tools/environment_layout_screenshots.gd": "eadf8f113aff55113ecf59e764503fd5bc2e4a64d00689573e0b56489b1a78e5",
}
PROVENANCE = {
    "highlimit_source_identity.json": "9318206129e866c945d8cb997a86e0e2b7e0ffa0f3d511ea8dab84a11322c8fd",
    "highlimit_capture_inputs.json": "0c8a9d6da6e625406951f44569c81072ced65b2796401fe606ec18f46ac07d41",
    "highlimit_trial_package_identity.json": "13fe7160853c874a700fc1cac56e93f1f0222dc0e67a592517d73fcd6b57b0c6",
    "highlimit_trial_adapter.py": "03cafe12a4f63160d289c3ce417f0c7d724dfbdfb6be77c52c4a68472b0fa875",
    "tools/envart_highlimit_preart_metadata.gd.uid": "02b03896514f119ebbecdb78ab75c4f22a20213edf4ddfc424c58919a2206d77",
    "tools/envart_highlimit_animation_probe.gd.uid": "cb49c8d047e9c078b53162a61e422b07bc4fb415ba7d52438d2cc2b38fa4582e",
    "tools/envart_highlimit_animation_capture.gd.uid": "c8b982be844be80c45adaf1c3b787b561d7cf3d46b1bebef1bce9790e19b792e",
    "tools/environment_art_baseline_capture.gd.uid": "cd3b58fa80239aada2b1e9752d8d3fecda4a0c4d02aa2a9226e1156fd235b7c2",
    "tools/environment_layout_screenshots.gd.uid": "a4e9a7d6067be76eee07ef86e4fb1a37c5fb88096d2626a05ad83057f243cb35",
}
CANONICAL_IMPORTS = {ART + name: digest for name, digest in {
    "background.png.import": "3eb75df43db90787afaca1535a4340dd3015bd44479cf5447e7c9c32ead1d85f",
    "counters/grand_table_left.png.import": "b4d7afde654e06a397da8745199622702ce78545e985132b8157f67644210ff3",
    "counters/grand_table_right.png.import": "20f68ccd13a009f291192222d3ae4fbd3f1f8a0457b3aaec0c43860b7a63d68a",
    "anim/casino_sign_pulse.png.import": "85fe4f9b3d0e314e67c887e3ea96850531cf98f94eadb18c059410de4e3922af",
    "anim/casino_light_0.png.import": "3b969fdc38d29ae22686ce2710564171f5c3df8fa4c59fc2c1b4bea3f28f37d2",
    "anim/casino_light_1.png.import": "44c2477c2b5606235424c7106b54535d470869083a575a85092e4be34598c111",
    "anim/casino_light_2.png.import": "60de85902b42be3c28be0a654d7f94dba75fb3e31373353ca57da0fa8c34d09a",
    "anim/casino_light_3.png.import": "62ac745a8c075dcdeac15708244495b3fb96b1de19db5b7d571d380e3fb25c3e",
    "anim/casino_light_4.png.import": "1c9016b1aa839ddaf29e2313662c039fc625842e42d6f780ee0f42979998b4db",
}.items()}
ANIMATION_IDS = tuple([f"casino_light_{i}" for i in range(5)] + ["casino_sign_pulse"] +
                      [f"casino_sparkle_{i}" for i in range(3)] + [f"floor_glint_{i}" for i in range(7)])
LOW_IDS = ("casino_light_1", "casino_light_2", "casino_light_3", "casino_sign_pulse", "floor_glint_0", "floor_glint_1", "floor_glint_2")
OBJECT_IDS = {"travel:grand_casino_cage", "game:roulette", "game:blackjack", "game:baccarat", "game:craps",
              "travel:grand_casino", "grand_living:rival:rival_cheater_d1_1", "grand_living:rival:rival_cheater_d1_2", "travel:leave"}
COUNTERS = {"grand_table_left": (164, 516, 544, 72), "grand_table_right": (1092, 516, 544, 72)}
MASK_COUNTS = (176, 176, 208, 200, 164, 1804)
IGNORE = b"# Non-active High Limit source/candidates; exclude from Godot discovery.\n"


def require(ok, message):
    if not ok:
        raise ValueError(message)


def baseline_files(workspace):
    files = scan(workspace / "source_baseline")
    require(len(files) == 21 and seal(files) == BASELINE_SEAL, "Exact pinned current High Limit21 baseline required")
    for name, expected in {**HELPERS, **PROVENANCE}.items():
        require(sha(LEGACY / name) == expected, "Original observer/provenance changed: " + name)
    return files


def canonical_imports(root):
    for name, expected in CANONICAL_IMPORTS.items():
        require(sha(root / name) == expected, "Canonical HL import must already be committed/preserved; no auto-copy: " + name)


def candidate(root, workspace, proof_path, review_path, baseline):
    root, proof_path, review_path = map(plain, (root, proof_path, review_path))
    require(root == workspace / "candidate_sources/high-limit-spatial-r1-assembled-v1", "Exact reviewed non-active HL V1 directory required")
    proof, review = read_json(proof_path), read_json(review_path)
    require(sha(proof_path) == PROOF_SHA and sha(review_path) == REVIEW_SHA and
            review.get("decision") == "STATIC_GO_FOR_NATIVE_TRIAL" and review.get("native_trial_approved") is True and
            review.get("independent_reviewer") == "/root/audit_spatial_handoff" and
            review.get("package_21_file_sha256") == PACKAGE_SEAL and review.get("assembly_proof_sha256") == PROOF_SHA and
            review.get("executed_recipe_sha256") == RECIPE_SHA, "Pinned independent native-only staticGO proof required")
    files = proof["output"]["files"]
    require(proof.get("recipe_sha256") == RECIPE_SHA and plain(proof["output"]["path"]) == root and
            proof["baseline"]["files"] == baseline and set(files) == set(baseline) and scan(root) == files and
            seal(files) == proof["output"]["seal"] == PACKAGE_SEAL and files[ART + "background.png"] == BACKGROUND_SHA,
            "Approved21-file candidate/source custody changed")
    job_path = proof_path.parent / "job.json"
    job = read_json(job_path)
    recipe = Path(__file__).with_name("assemble_high_limit_spatial_candidate.py")
    require(sha(job_path) == ASSEMBLY_JOB_SHA and qualified_job(job) and sha(recipe) == RECIPE_SHA and
            len(job.get("command", [])) >= 3 and job["command"][1] == "-B" and plain(job["command"][2]) == plain(recipe),
            "Exact reviewed recipe and closed guarded assembly Job required")
    changed_png = {name[:-7] for name in CANONICAL_IMPORTS}
    require({name for name in files if files[name] != baseline[name]} == changed_png | {MANIFEST},
            "Only exact nine PNGs and five-lamp-Y JSON may differ")
    old = read_json(workspace / "source_baseline" / MANIFEST)
    spec, expected = read_json(root / MANIFEST), deepcopy(old)
    require([row["id"] for row in old["animations"]] == list(ANIMATION_IDS), "Original16-entry inventory changed")
    for index in range(5):
        require(expected["animations"][index]["rect"] == [250 + index * 100, 124, 52, 8], "Original lamp geometry changed")
        expected["animations"][index]["rect"][1] = 8
        require(type(spec["animations"][index]["rect"][1]) is int, "Lamp Y must remain integer")
    require(json.dumps(spec, sort_keys=True, separators=(",", ":")) == json.dumps(expected, sort_keys=True, separators=(",", ":")),
            "Only five integer lamp rect.y124->8 changes admitted; all other geometry/timing/flags frozen")
    require([row["id"] for row in spec["animations"] if row.get("web_low_detail")] == list(LOW_IDS), "Seven low-detail entries changed")
    master = decode_png((root / (ART + "background.png")).read_bytes())
    require((master.width, master.height) == (1800, 860) and set(master.rgba[3::4]) == {255}, "Opaque1800x860 master required")
    original = decode_png((workspace / "source_baseline" / (ART + "background.png")).read_bytes())
    metrics = {}
    for index, entry in enumerate(spec["animations"][:6]):
        name = ART + entry["texture"]
        image = decode_png((root / name).read_bytes())
        prior_image = decode_png((workspace / "source_baseline" / name).read_bytes())
        bx, by, width, height = entry["rect"]
        require((image.width, image.height) == (width * 2, height * 2), "Mask size changed")
        count = 0
        for y in range(image.height):
            for x in range(image.width):
                r, g, b, alpha = original.rgba[((by * 2 + y) * 1800 + bx * 2 + x) * 4:((by * 2 + y) * 1800 + bx * 2 + x) * 4 + 4]
                selected = (g >= 100 and b >= 100 and g >= r + 40 and b >= r + 40) if index == 5 else (r >= 90 and g >= 60 and r >= b + 20 and g >= b)
                at = (y * image.width + x) * 4
                require(image.rgba[at:at + 3] == prior_image.rgba[at:at + 3] and
                        image.rgba[at + 3] == (prior_image.rgba[at + 3] if selected else 0), "Mask is not exact original-RGB alpha-only material cut")
                if selected:
                    require(alpha == 255 and image.rgba[at + 3] > 0, "Visible warm soffit/cyan glyph material absent")
                    count += 1
        require(count == MASK_COUNTS[index], "Actual visible practical mask coverage changed")
        metrics[entry["id"]] = {"rect": entry["rect"], "visible_material_pixels": count,
            "material": "PRIVATE TABLES cyan subtitle" if index == 5 else "original gold soffit", "alpha_cut_only": True}
    crops = {}
    for name, (x, y, width, height) in COUNTERS.items():
        image = decode_png((root / (ART + "counters/" + name + ".png")).read_bytes())
        wanted = b"".join(master.rgba[((y + row) * 1800 + x) * 4:((y + row) * 1800 + x + width) * 4] for row in range(height))
        require((image.width, image.height) == (width, height) and image.rgba == wanted, "Replay crop not exact master pixels: " + name)
        crops[name] = {"native_rect": [x, y, width, height], "exact_master_crop": True}
    return {"files": files, "package_sha256": PACKAGE_SEAL, "candidate_root": str(root), "review_sha256": REVIEW_SHA,
            "candidate_manifest_sha256": PROOF_SHA, "assembly_job_sha256": ASSEMBLY_JOB_SHA,
            "approved_repair_recipe_sha256": RECIPE_SHA, "exact_counter_crops": crops, "visible_practical_masks": metrics,
            "review": review, "production_art_written": False, "test_updated": False}
