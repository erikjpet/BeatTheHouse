"""High Limit TEST policy contracts; no executable build/served entrypoint.

Pure, versioned checks only: no files, children, network, profiles or saves.
A declaration is NEVER baseline qualification. Runnable integration is deferred
until the delivered Grand immutable baseline and its closed served proof exist.
"""
import sys
sys.dont_write_bytecode = True

from copy import deepcopy
import hashlib
import json
import re


SCHEMA = "bth.high_limit_spatial_test_policy/v1"
APPROVAL_SCHEMA = "bth.high_limit_spatial_test_approval/v1"
BASELINE_SCHEMA = "bth.high_limit_spatial_test_baseline_declaration/v1"
ENVIRONMENT = "grand_casino_high_limit"
TASK_ID = "BTH-ENV-SPATIAL-HL-001"
ART = "assets/art/environments/" + ENVIRONMENT + "/"
HL_JSON = "data/art/environments/" + ENVIRONMENT + ".json"
INDEX_JSON = "data/art/environments/index.json"
BASE_HL_JSON_SHA = "3c2accd38cf268b33853bd3894e53b4def84e2bbf10f240a20de38ccb868fdd2"
HL_JSON_SHA = "d8e8eb4ca4982d2b87c402c8877a6c463b279f3d127c31bfae96be4b5b29c3d0"
PACKAGE_SHA = "481e858ee3c484b06ba6df935983c29979a188e7e59ff5f44eaf22ecdbe020e4"
BAR_SHA = "e001ad4d76344f0bb2e0542a21fa3f4936656c8c2a63ace475a6294cb9ca723e"
UID_SHA = "587514374b37d67f6c0e795cc82d840f1d4a5f9f0b0c2f3c80586ce4eb38b4db"
UID_MAP_SHA = "293bcadacffd15543a5686b5e40cc6cd409495e80628d77bc0e5e62c2eb61b55"
CLASS_SHA = "43ed255c77d8ef9809383d0fef148e952dabddbbf434c69b0276790b6da5816d"
ANIMATION_IDS = tuple(["casino_light_" + str(i) for i in range(5)] + ["casino_sign_pulse"] +
                      ["casino_sparkle_" + str(i) for i in range(3)] + ["floor_glint_" + str(i) for i in range(7)])
LOW_IDS = ("casino_light_1", "casino_light_2", "casino_light_3", "casino_sign_pulse", "floor_glint_0", "floor_glint_1", "floor_glint_2")
PNG_SHAS = {ART + name: value for name, value in {
    "background.png": "25242d74d442bc99b183845c75b5714983db081100b4020780645976e7f7fb50",
    "counters/grand_table_left.png": "0735c552b27d382c9a2b5c8992dae675bf9a5b3bd7ca867dfbc04f1e49213f37",
    "counters/grand_table_right.png": "bf33dc30e834da33afb18efe481d36baa80ab9b3774d4e7ecc3d31908a88e80a",
    "anim/casino_sign_pulse.png": "6136ec81f0addd0cc0afd4a82d4dfc405182e9a58ed62d982b3062912981ce71",
    "anim/casino_light_0.png": "473613f75ffc3efa6152515b258b88026e2595429f88ca09074b6d97d78e1d4c",
    "anim/casino_light_1.png": "c4869428e27196ff62d62d49836aec39857370635788e71fa0f08b3fac24ca04",
    "anim/casino_light_2.png": "2e7f18a18374dd1e7f66f033f9c225b866c0a1a61c10f609cc08f7f0e86c9946",
    "anim/casino_light_3.png": "eae4a508f749b470a2d68ee535bbe0799a0f48ed84b202e5acc78bf129ad9cfb",
    "anim/casino_light_4.png": "689dd52474cd3dfd2df6518a0de2b6253083fdfe26548e25e096ec33141167d3",
}.items()}
IMPORT_SHAS = {ART + name: value for name, value in {
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


def require(ok, message):
    if not ok:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def full_hash(value, length=64):
    require(isinstance(value, str) and re.fullmatch(r"[0-9a-f]{%d}" % length, value) and value != "0" * length,
            "Full nonzero lowercase hash required")
    return value


def same_typed(left, right):
    if type(left) is not type(right):
        return False
    if isinstance(left, dict):
        return left.keys() == right.keys() and all(same_typed(left[key], right[key]) for key in left)
    if isinstance(left, list):
        return len(left) == len(right) and all(same_typed(a, b) for a, b in zip(left, right))
    return left == right


def json_value(raw):
    def object_pairs(pairs):
        value = {}
        for key, item in pairs:
            require(key not in value, "Duplicate JSON key: " + key)
            value[key] = item
        return value
    def invalid_constant(value):
        raise ValueError("Non-finite JSON number: " + value)
    return json.loads(raw.decode("utf-8-sig"), object_pairs_hook=object_pairs, parse_constant=invalid_constant)


def check_json_semantics(original_raw, candidate_raw):
    """Only five named rect.y integer124->8; every other value/type preserved."""
    original = json_value(original_raw)
    expected = deepcopy(original)
    require(original.get("environment_id") == ENVIRONMENT and original.get("board_size") == [900, 430] and
            type(original.get("pixel_scale")) is int and original["pixel_scale"] == 2,
            "Original High Limit board namespace differs")
    rows = expected.get("animations", [])
    require(tuple(row.get("id") for row in rows) == ANIMATION_IDS and
            tuple(row["id"] for row in rows if row.get("web_low_detail") is True) == LOW_IDS,
            "Original High Limit16/seven inventory differs")
    for index in range(5):
        require(rows[index]["rect"] == [250 + index * 100, 124, 52, 8] and
                all(type(value) is int for value in rows[index]["rect"]), "Original lamp geometry/type differs")
        rows[index]["rect"][1] = 8
    candidate = json_value(candidate_raw)
    require(same_typed(expected, candidate), "Only five integer lamp rect.y124->8 deltas are admitted")
    return candidate


def check_json(original_raw, candidate_raw):
    candidate = check_json_semantics(original_raw, candidate_raw)
    require(sha(original_raw) == BASE_HL_JSON_SHA and sha(candidate_raw) == HL_JSON_SHA, "Actual reviewed High Limit JSON bytes differ")
    return candidate


def payload_paths(baseline):
    paths = {name for name in baseline["art_source_files"] if name.startswith(ART)} | {HL_JSON, INDEX_JSON}
    require(len(paths) == 21 and sum(name.endswith(".png") for name in paths) == 19, "Exact19 PNG+JSON+index package required")
    return sorted(paths)


def package_seal(hashes):
    return sha("\n".join(name + " " + hashes[name] for name in sorted(hashes)).encode())


def candidate_hashes(baseline, observed):
    """Observed actual source hashes, not a claim of independent art approval."""
    paths = payload_paths(baseline)
    expected = {name: baseline["art_source_files"][name] for name in paths}
    expected.update(PNG_SHAS)
    expected[HL_JSON] = HL_JSON_SHA
    require(set(observed) == set(paths) and observed == expected and package_seal(observed) == PACKAGE_SHA,
            "Actual High Limit21 payload differs from reviewed R1 source")
    require({name for name in observed if observed[name] != baseline["art_source_files"][name]} == set(PNG_SHAS) | {HL_JSON},
            "Exactly nine PNGs and High Limit JSON must differ")
    return {"schema": SCHEMA, "package_sha256": PACKAGE_SHA, "files": dict(observed), "art_approval": False}


def expected_raw(baseline):
    raw = baseline["art_source_files"]
    require(len(raw) == 421 and len(baseline["compiled_art_sha256"]) == 400 and len(baseline["active_art_packages"]) == 20 and
            len(baseline["active_doorway_packages"]) == 12 and baseline["active_art_packages"]["bar"] == BAR_SHA,
            "Complete runtime inventory or protected Bar seal differs")
    return {**raw, **PNG_SHAS, HL_JSON: HL_JSON_SHA}


def check_source_hashes(baseline, observed):
    require(observed == expected_raw(baseline), "Actual421 source hashes changed outside exact approved HL delta")
    return candidate_hashes(baseline, {name: observed[name] for name in payload_paths(baseline)})


def check_import_hashes(observed):
    require(observed == IMPORT_SHAS, "Actual canonical nine import metadata hashes differ")
    return {"schema": SCHEMA, "canonical_imports_match": True, "files": dict(observed), "art_approval": False}


def check_baseline_declaration(value):
    """Shape/pin check only. Never grants trust to a supplied stage or receipt."""
    require(value.get("schema") == BASELINE_SCHEMA, "Explicit delivered-Grand baseline declaration required")
    for name in ("source_commit", "source_tree"):
        full_hash(value.get(name), 40)
    for name in ("manifest_sha256", "pck_sha256", "grand_approval_sha256", "grand_strict_pck_proof_sha256",
                 "grand_served_proof_sha256", "grand_served_job_sha256"):
        full_hash(value.get(name))
    require(value.get("uid_cache_sha256") == UID_SHA and value.get("uid_map_sha256") == UID_MAP_SHA and
            value.get("class_cache_sha256") == CLASS_SHA and value.get("preserved_bar_seal") == BAR_SHA,
            "Canonical UID/class/Bar bindings differ")
    protected = value.get("protected_room_seals")
    require(isinstance(protected, dict) and len(protected) == 19 and ENVIRONMENT not in protected and
            protected.get("bar") == BAR_SHA and "grand_casino" in protected, "Observed protected19-room map required")
    for item in protected.values():
        full_hash(item)
    for name in ("stage", "grand_approval_path", "grand_strict_pck_proof_path", "grand_served_proof_path"):
        path = value.get(name)
        require(isinstance(path, str) and path.startswith("E:/CodexQA/BTH/") and "\\" not in path and
                ".." not in path.split("/"), "Explicit canonical admitted E baseline evidence required")
    return {"schema": SCHEMA, "baseline_declaration_sha256": sha(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()),
        "baseline_qualified": False, "status": "DECLARATION_ONLY_NOT_BASELINE_QUALIFICATION",
        "remaining_gates": ["Authenticate actual immutable Grand stage and closed served Job/receipt",
            "Recompute frozen Grand strict PCK proof from qualified7b and validate all protected packages",
            "Bind actual source/helper/approval hashes, UID caches and preserved19-room map",
            "Independent final High Limit native/art GO_FOR_TEST_BUILD on exact source/candidate"]}


def check_approval_declaration(value, baseline):
    """Future final-review contract. Static/native-trial approval cannot pass."""
    require((value.get("schema"), value.get("environment_id"), value.get("verdict")) ==
            (APPROVAL_SCHEMA, ENVIRONMENT, "GO_FOR_TEST_BUILD"), "Final independent High Limit TEST approval required")
    require(value.get("approved_png_sha256") == PNG_SHAS and value.get("high_limit_json_sha256") == HL_JSON_SHA and
            value.get("high_limit_package_sha256") == PACKAGE_SHA, "Final approval must bind exact R1 nine PNGs/JSON/21seal")
    check_baseline_declaration(value.get("baseline", {}))
    declared = value["baseline"]
    require((baseline.get("source_commit"), baseline.get("source_tree")) == (declared["source_commit"], declared["source_tree"]) and
            {name: seal for name, seal in baseline["active_art_packages"].items() if name != ENVIRONMENT} == declared["protected_room_seals"],
            "Final approval must preserve actual delivered Grand and other18 rooms")
    require(isinstance(value.get("reviewer"), str) and value["reviewer"].strip() and
            isinstance(value.get("evidence"), list) and value["evidence"] and all(isinstance(item, str) and item.strip() for item in value["evidence"]),
            "Independent final reviewer and concrete native/art evidence required")
    for name in ("source_commit", "source_tree"):
        full_hash(value.get(name), 40)
    for name in ("native_identity_sha256", "native_contexts_sha256", "native_motion_sha256", "native_liveness_sha256", "native_capture_sha256", "final_art_review_sha256"):
        full_hash(value.get(name))
    return {"schema": SCHEMA, "approval_contract_matches": True, "baseline_qualified": False,
        "native_receipts_authenticated": False, "status": "DECLARATION_MATCH_ONLY_NOT_BUILD_AUTHORIZATION"}


def validate_manifest(manifest, baseline, targets):
    """Pure inventory policy atop an independently qualified delivered baseline."""
    require(manifest["art_source_files"] == expected_raw(baseline), "Unapproved raw art/global index/other-room bytes changed")
    active = {**baseline["active_art_packages"], ENVIRONMENT: PACKAGE_SHA}
    require(manifest["active_art_packages"] == active and manifest["active_doorway_packages"] == baseline["active_doorway_packages"] and
            manifest.get("art_package_sha256") == PACKAGE_SHA, "Protected room/doorway activation map changed")
    old, new = baseline["compiled_art_sha256"], manifest["compiled_art_sha256"]
    require(len(targets) == 9 and set(targets).issubset(old) and new.keys() == old.keys() and len(new) == 400, "Exact nine-CTEX/400 inventory required")
    for name, prior in old.items():
        full_hash(new[name])
        require((name in targets) != (new[name] == prior), "Compiled change outside exact nine targets: " + name)
    require(manifest["files"].keys() == baseline["files"].keys(), "Web payload file inventory changed")
    require(manifest.get("channel") == "test", "High Limit package must remain on TEST")
    for name in ("platform", "engine_sha256", "export_presets_sha256", "native_library_path", "native_library_sha256",
                 "template_sha256", "persistence_core_sha256", "test_args", "persistent_paths"):
        require(name in baseline and name in manifest and same_typed(manifest[name], baseline[name]),
                "Protected engine/native/template/persistence pin changed: " + name)
    for name, prior in baseline["files"].items():
        require(name in ("index.html", "index.pck") or manifest["files"][name] == prior,
                "Protected engine/native/template/WebGL payload changed: " + name)


def verify_pck_delta(old, new, baseline, manifest, expected_baseline_pck_sha256):
    """Actual bounded PCK payload policy; does not authenticate baseline custody."""
    import audit_pck_manifest
    from bar_spatial_test_build import pck_entry_bytes, decode_uid_cache
    require(type(old) is bytes and type(new) is bytes and 112 <= len(old) <= 512 * 1024 ** 2 and
            112 <= len(new) <= 512 * 1024 ** 2, "Bounded immutable standalone PCK byte inputs required")
    full_hash(expected_baseline_pck_sha256)
    require(sha(old) == expected_baseline_pck_sha256, "Actual declared baseline PCK bytes differ")
    od, nd = audit_pck_manifest.find_directory(old), audit_pck_manifest.find_directory(new)
    oe, ne = {row["path"]: row for row in od["entries"]}, {row["path"]: row for row in nd["entries"]}
    require(od["pack_offset"] == nd["pack_offset"] == 0 and len(oe) == len(od["entries"]) == len(ne) == len(nd["entries"]) and oe.keys() == ne.keys(),
            "Actual standalone PCK inventory changed")
    read = lambda data, directory, rows, name: pck_entry_bytes(data, directory, rows[name])
    targets = set()
    for source in PNG_SHAS:
        raw = read(old, od, oe, source + ".import")
        found = re.findall(r'^path="res://([^"\n]+\.ctex)"\r?$', raw.decode("utf-8"), re.M)
        require(len(found) == 1, "Original High Limit source has no unique CTEX target")
        targets.add(found[0])
    validate_manifest(manifest, baseline, targets)
    changed = {name for name in oe if read(old, od, oe, name) != read(new, nd, ne, name)}
    require(changed == targets | {HL_JSON, "build_manifest.json"}, "PCK delta is not exactly nine HL textures, JSON and identity")
    old_uid, new_uid = read(old, od, oe, ".godot/uid_cache.bin"), read(new, nd, ne, ".godot/uid_cache.bin")
    uid = decode_uid_cache(old_uid)
    require(old_uid == new_uid and len(uid) == 1605 and sha(old_uid) == UID_SHA and
            sha(json.dumps(uid, sort_keys=True, separators=(",", ":")).encode()) == UID_MAP_SHA and
            sha(read(old, od, oe, ".godot/global_script_class_cache.cfg")) == CLASS_SHA, "Canonical UID/class proof differs")
    check_json(read(old, od, oe, HL_JSON), read(new, nd, ne, HL_JSON))
    for name, expected in manifest["compiled_art_sha256"].items():
        require(sha(read(new, nd, ne, name)) == expected, "Actual compiled art SHA differs from manifest")
    for name, expected in manifest["art_source_files"].items():
        if not name.endswith(".png"):
            require(sha(read(new, nd, ne, name)) == expected, "Actual packed art JSON SHA differs from manifest")
    return {"schema": SCHEMA, "scope": "PCK_DELTA_ONLY_NOT_BASELINE_QUALIFICATION", "baseline_qualified": False,
        "embedded_identity_authenticated": False,
        "baseline_pck_sha256": sha(old), "pck_sha256": sha(new), "changed": sorted(changed), "uid_bindings": 1605,
        "uid_cache_bytes_equal": True, "class_cache_bytes_equal": True, "all_scn_gdc_bytes_equal": True,
        "all_other_room_and_doorway_resources_equal": True}
