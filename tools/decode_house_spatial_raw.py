"""Decode the one preserved House source PNG in a prepared capped E Job.

Pure byte materialization only. No pixels are transformed, no child or network
is used, and nothing is removed, moved, retried or activated. The supervising
parent must authenticate its final closed Job. Existing outputs are inspected
read-only and cause a stop; they never become permission to retry or overwrite.
"""
import sys
sys.dont_write_bytecode = True

import argparse
import base64
import binascii
import hashlib
import json
import os
from pathlib import Path
import stat
import struct
import zlib

import bth_qa_storage as storage
from bth_qa_storage import Layout, validate_layout

SOURCE_ROOT = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers")
QA_ROOT = Path("E:/CodexQA/BTH")
WORKSPACE = QA_ROOT / "workspaces/BTH-ENV-SPATIAL-HOUSETRIAL-20261116"
OUTPUT = WORKSPACE / "raw_source/house-spatial-r1.png"
INPUT_RELATIVE = "review_artifacts/environment_art_sources/house-spatial-r1/house-spatial-r1.png.b64"
INPUT_SHA = "1b0ccc11610af34b8f7a72f1cfbb45c2d6835130a24a2cb4561cc9d8923b8306"
INPUT_BYTES = 2171885
PNG_SHA = "76b64ab7d78543c685b6fcecf9bf1f6e4afaf33f1ce3a97e0532a8f13ccb1d19"
PNG_BYTES = 1628912
CABX_SHA = "82ee6efc6b639330f810bb22fd698069f293a01a0b9d71a5fc204428c92840e3"
BACKGROUND = "assets/art/environments/house/background.png"
BACKGROUND_SHA = "ec1049f1ccbae9221cbfdcaa30b676c44c3a6831e0b8347aad656767d5d78b7d"
ROOM_JSON = "data/art/environments/house.json"
INDEX_JSON = "data/art/environments/index.json"
PYTHON_SHA = "3093fcf263029ca1d799fea250a4e032d2c930a516f1513eeca688b343c836b3"
HELPERS = {
    "bth_qa_storage.py": "cdc08bcb1ad0bff82bb5fd12f467c576cfc40a998f40870068cf6c684216f837",
    "bth_qa_guarded_run.py": "7ea6be8366f606995a1f69ddb26d99b4e3c47a0fcce9d968abe17b3dc074ad7e",
    "bth_qa_command_paths.py": "bbc405ac19ae803c2c15d93fee1ca059f25d06176cfee7926b2329b93ca4352b",
    "decode_apartment_spatial_raw.py": "0f55f8083928764c2243e71aa162b35282e45d6fbe3aa4ee44d78fecf52dd376",
    "decode_kitty_spatial_raw.py": "532ca2652b9f88f535a7f1d71a7b2f95ac5f2bd387e3961fc212c4ebfd848636",
}
KITTY_EVIDENCE = QA_ROOT / "runs/BTH-ENV-SPATIAL-KITTYTRIAL-20261116-rawdecode01/evidence"
KITTY_JOB_SHA = "f6ed8c6be02af3551fb5ff2794c2419b2cbc9c394fe6a4cd7415fd3881e220ea"
KITTY_LOG_SHA = "3ee3a156d37eaf103d924828814e749527932b1270a477c8eb8309f5ad5704db"
KITTY_PNG = QA_ROOT / "workspaces/BTH-ENV-SPATIAL-KITTYTRIAL-20261116/raw_source/kitty-spatial-r1.png"
KITTY_PNG_SHA = "aa1078eab763def23c3d8a1b7232413384b5fcc26a86d7008866dcbf857526eb"
KITTY_PNG_BYTES = 1852735


SOURCE_PAYLOAD_PINS = {
    "assets/art/environments/house/anim/central_strip.png": "3d4b9ad369609f37949e0b2d3f60a4a35da12dc3917b64ba3b21d96937df6bbb",
    "assets/art/environments/house/anim/floor_glint_0.png": "bb4f5c707031c24c8f05cca373ab66cb3fb8ea2a729a2dafd6112be0576bc490",
    "assets/art/environments/house/anim/floor_glint_1.png": "8c3943c4d07602da082a29d49d5d092f1d26dd1726cdf1789cabef2073b1c21a",
    "assets/art/environments/house/anim/floor_glint_2.png": "411d358e941a5867df0c7edc1f58fe72c1c81633c1bc7f1b2c4ed8453156775b",
    "assets/art/environments/house/anim/floor_glint_3.png": "18868f32b541dc3a10c44c3dc109054745b7f1e07953883700b4d27ad0ebfa3d",
    "assets/art/environments/house/anim/floor_glint_4.png": "36cb42a27c9b0588e0130993d78403243e1c11255fce38a0a16097dd4d1d7147",
    "assets/art/environments/house/anim/floor_glint_5.png": "3658013941c5c6b6a3ca7484d9018e893a681aa97eaef8e2f212451a6362ed27",
    "assets/art/environments/house/anim/floor_glint_6.png": "d8f87fdc51b4401fef0d151975fb2963bbd43919625a8e6aec9234087627bb57",
    "assets/art/environments/house/anim/right_support_pulse.png": "8c0d2ac71fb6ae93d1c54843e15f08c0cefec25e433935942f0901bd738bb94a",
    "assets/art/environments/house/anim/room_ribbon_0.png": "d6902ddcffe6389b1cb72e9f2cfba11c1fb320b1fc06cd702a3b376140981edf",
    "assets/art/environments/house/anim/room_ribbon_1.png": "21ac8da89a8bf4f3d267d600d122c05dbf332a30e7119a426fe55682614f89f8",
    "assets/art/environments/house/anim/room_ribbon_2.png": "fba82f8246f7aac6e71f2160288c604c41c7246c45d61525acd445b98e11cea2",
    "assets/art/environments/house/anim/room_ribbon_3.png": "0ecb9eb27feba9ed1c345ee3ab97f048e8d95477eb011fd9b11b2ff0dbb4caa1",
    "assets/art/environments/house/anim/room_ribbon_4.png": "afd206e143b62b904b0c6042af282cd11ac6b12c8e455d9ca4179891aa6258a4",
    "assets/art/environments/house/anim/shelf_bob_0.png": "f4dc9d0f8fef41972c8edea2d24570f116c13c5a0a5ebf5bce0e9efc8346127c",
    "assets/art/environments/house/anim/shelf_bob_1.png": "a7340540fa75e4fb2406e2d5fd2d286a15c7ea60756d9ee8e5317118a531e082",
    "assets/art/environments/house/anim/shelf_bob_2.png": "fb2130611aa621029f8002c7b6f6de3902e4054c161e47bf744564c2aa30c178",
    "assets/art/environments/house/anim/shelf_bob_3.png": "bdff9ce3003a37a8efcab212e2c539bccf24200bdec7c2126e1f3490edc8ab44",
    "assets/art/environments/house/anim/shelf_bob_4.png": "91843f9a1a11c4735ff34f21df3872defbbfd6094901e889249976d0f5dc8b2e",
    "assets/art/environments/house/anim/window_glow_0.png": "5f30f04ce6439d256d531dbb2103e3ec981e6e4c438266da691ee9beb68d8160",
    "assets/art/environments/house/anim/window_glow_1.png": "5f30f04ce6439d256d531dbb2103e3ec981e6e4c438266da691ee9beb68d8160",
    "assets/art/environments/house/anim/window_glow_2.png": "5f30f04ce6439d256d531dbb2103e3ec981e6e4c438266da691ee9beb68d8160",
    "assets/art/environments/house/anim/window_glow_3.png": "5f30f04ce6439d256d531dbb2103e3ec981e6e4c438266da691ee9beb68d8160",
    "assets/art/environments/house/anim/window_glow_4.png": "5f30f04ce6439d256d531dbb2103e3ec981e6e4c438266da691ee9beb68d8160",
    "assets/art/environments/house/background.png": "ec1049f1ccbae9221cbfdcaa30b676c44c3a6831e0b8347aad656767d5d78b7d",
    "data/art/environments/house.json": "3872a3d92ecd98168ea569a37d1ad79c670e95ea3f8bff57a6b5f9e94c55c0b0",
    "data/art/environments/index.json": "11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24"
}
SOURCE_PAYLOAD_SEAL = "3a076309f40b5dfad0317d06055fb589d5d91834991dc84016827eb61a477028"
SOURCE_DIRECTORY = "review_artifacts/environment_art_sources/house-spatial-r1"
PROVENANCE_RELATIVE = SOURCE_DIRECTORY + "/provenance.json"
PROMPT_RELATIVE = SOURCE_DIRECTORY + "/prompt.txt"
DATA_URL_SHA = "a93feacf51b79843192865874ea4535c1f05f4f4bfe35f136d2eca05eb8303b9"
SOURCE_CONTROL_PINS = {
    PROVENANCE_RELATIVE: "0612c65b3f68a2c3b8b576e996ca9b3ca8c83bbed1905b1af2268ca19d2c3844",
    PROMPT_RELATIVE: "f18ffed9ca561f1fe0e44b54d807d38a263d0cf3658cba2e9b750136f138df74",
    "docs/art/briefs/house_spatial_repair_20261116.md": "2f78b13b4a5e10a7da9e2bea9c13560575f0cb7d9423d58b3d70681ee1891868",
    "docs/testing/house_spatial_source_audit_20261116.json": "f87e8dfd7a4e001008f1c875eadb838eb7ad4a9e7bd3bf14723463a16934457c",
    "docs/testing/house_r3_native_trial.json": "d41e8ca1329ec77877aa484e1a2555c6a7aa1238eeb4034750a4affbfd176e44",
}

def require(value, message):
    if not value:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def plain(value):
    path = Path(value)
    require(path.is_absolute() and ".." not in path.parts, "Explicit absolute ordinary path required")
    for item in (path, *path.parents):
        try:
            info = item.lstat()
        except FileNotFoundError:
            continue
        require(not stat.S_ISLNK(info.st_mode) and
                not getattr(info, "st_file_attributes", 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT,
                "Linked/reparse path rejected: " + str(item))
        require(stat.S_ISREG(info.st_mode) or stat.S_ISDIR(info.st_mode), "Nonordinary path rejected: " + str(item))
        if item != path:
            require(stat.S_ISDIR(info.st_mode), "Path ancestor is not a directory: " + str(item))
    return path


def read_file(value, limit):
    path = plain(value)
    info = path.lstat()
    require(stat.S_ISREG(info.st_mode) and info.st_size <= limit, "Bounded ordinary input required: " + str(path))
    data = path.read_bytes()
    after = path.lstat()
    require((info.st_size, info.st_mtime_ns, info.st_ino) ==
            (after.st_size, after.st_mtime_ns, after.st_ino) and len(data) == info.st_size,
            "Input changed during read: " + str(path))
    return data


def helper_pins():
    require(plain(storage.__file__) == SOURCE_ROOT / "tools/bth_qa_storage.py", "Exact maintained D storage module required")
    require(sha(read_file(sys.executable, 64 * 1024 ** 2)) == PYTHON_SHA, "Parent-qualified Python binary differs")
    for name, expected in HELPERS.items():
        require(sha(read_file(SOURCE_ROOT / "tools" / name, 1024 ** 2)) == expected, "Frozen helper changed: " + name)
    return {**HELPERS, "decode_house_spatial_raw.py": sha(read_file(__file__, 1024 ** 2))}


def png_structure(data):
    require(len(data) == PNG_BYTES and sha(data) == PNG_SHA and data[:8] == b"\x89PNG\r\n\x1a\n",
            "Exact original PNG length/SHA/signature differs")
    expected = ((b"IHDR", 13), (b"caBX", 23654), (b"IDAT", 1605189), (b"IEND", 0))
    offset, rows = 8, []
    for kind, size in expected:
        require(offset + 12 <= len(data), "Truncated PNG chunk")
        length = struct.unpack_from(">I", data, offset)[0]
        actual_kind = data[offset + 4:offset + 8]
        require((actual_kind, length) == (kind, size) and offset + size + 12 <= len(data),
                "Exact original PNG chunk order/length differs")
        payload = data[offset + 8:offset + 8 + size]
        crc = struct.unpack_from(">I", data, offset + 8 + size)[0]
        require(zlib.crc32(kind + payload) & 0xffffffff == crc, "Original PNG chunk CRC differs")
        if kind == b"IHDR":
            require(struct.unpack(">IIBBBBB", payload) == (1815, 867, 8, 2, 0, 0, 0),
                    "Exact RGB8 non-interlaced1815x867 IHDR differs")
        if kind == b"caBX":
            require(sha(payload) == CABX_SHA, "Original caBX provenance payload differs")
        rows.append({"kind": kind.decode("ascii"), "bytes": size, "payload_sha256": sha(payload), "crc_valid": True})
        offset += size + 12
    require(offset == len(data), "Additional PNG chunk or trailing bytes rejected")
    return {"width": 1815, "height": 867, "bit_depth": 8, "color_type": 2, "opaque_RGB": True,
            "compression": 0, "filter": 0, "interlace": 0, "all_chunk_CRCs_verified": True,
            "caBX_preserved_byte_exact": True, "chunks": rows}


def decode_bytes(encoded):
    require(len(encoded) == INPUT_BYTES and sha(encoded) == INPUT_SHA and
            encoded.endswith(b"\n") and encoded.count(b"\n") == 1 and b"\r" not in encoded,
            "Exact one-line ASCII B64 artifact required")
    require(sha(b"data:image/png;base64,"+encoded[:-1]) == DATA_URL_SHA,
            "Exact returned House data-URL identity differs")
    data = base64.b64decode(encoded[:-1], validate=True)
    return data, png_structure(data)


def artifact_contract():
    folder = plain(SOURCE_ROOT / SOURCE_DIRECTORY)
    members = list(folder.iterdir())
    require({item.name for item in members} == {"house-spatial-r1.png.b64","prompt.txt","provenance.json"} and
            all(stat.S_ISREG(plain(item).lstat().st_mode) for item in members),
            "Exact three frozen House source artifacts required; preserve every other member and stop")
    controls = {name:sha(read_file(SOURCE_ROOT / name, 16 * 1024 ** 2)) for name in SOURCE_CONTROL_PINS}
    require(controls == SOURCE_CONTROL_PINS, "Exact House provenance/prompt/source-direction controls differ")
    record = json.loads(read_file(SOURCE_ROOT / PROVENANCE_RELATIVE, 1024 ** 2))
    raw = record["preserved_raw"]
    require(record["schema"] == "bth.house_spatial_raw_trial/v1" and
            record["status"] == "ONE_NON_ACTIVE_RAW_TRIAL_PRESERVED_NOT_APPROVED" and
            record["generation_counts"] == {"tool_invocations":2,"pre_generation_argument_failures":1,
                "successful_image_generations":1,"competing_or_replacement_generations":0} and
            raw["PNG_sha256"] == PNG_SHA and raw["PNG_bytes"] == PNG_BYTES and
            raw["PNG_dimensions"] == [1815,867] and raw["base64_file_sha256"] == INPUT_SHA and
            raw["base64_file_bytes"] == INPUT_BYTES and raw["exact_data_url_sha256"] == DATA_URL_SHA and
            record["first_look"]["result"] == "NOT_APPROVED_AS_FULL_MASTER_REPLACEMENT" and
            record["first_look"]["active_candidate_assembled"] is False,
            "Actual House raw identity/generation history/first-look limits differ")
    prompt = read_file(SOURCE_ROOT / PROMPT_RELATIVE, 128 * 1024)
    require(prompt == (record["exact_prompt"]["tool_argument"]+"\n").encode("utf-8"),
            "Exact actual tool prompt bytes differ")
    return {"controls":controls,"provenance_schema":record["schema"],
            "successful_generations":1,"first_look":record["first_look"],
            "raw_is_not_an_approved_master":True,"motion_material_questions_remain_OPEN":True}


def source_snapshot():
    """Closed25-PNG art tree plus exact House JSON/index: all27 logical pins."""
    art = plain(SOURCE_ROOT / "assets/art/environments/house")
    files, directories, pending = {}, [], [art]
    while pending:
        directory = pending.pop()
        for item in sorted(directory.iterdir()):
            item = plain(item)
            relative = item.relative_to(SOURCE_ROOT).as_posix()
            mode = item.lstat().st_mode
            if stat.S_ISDIR(mode):
                require(relative == "assets/art/environments/house/anim",
                        "Unknown source directory preserved; stop: "+relative)
                directories.append(relative)
                pending.append(item)
            else:
                require(stat.S_ISREG(mode) and relative in SOURCE_PAYLOAD_PINS and relative.endswith(".png"),
                        "Unknown source art member preserved; stop: "+relative)
                files[relative] = sha(read_file(item, 16 * 1024 ** 2))
    expected_art = {name:value for name,value in SOURCE_PAYLOAD_PINS.items()
                    if name.startswith("assets/art/environments/house/")}
    require(files == expected_art and len(files) == 25 and directories == ["assets/art/environments/house/anim"] and
            files.get(BACKGROUND) == BACKGROUND_SHA, "Exact original House25-PNG source tree differs")
    for name in (ROOM_JSON, INDEX_JSON):
        files[name] = sha(read_file(SOURCE_ROOT / name, 8 * 1024 ** 2))
    require(files == SOURCE_PAYLOAD_PINS and len(files) == 27 and
            sha("\n".join(name+" "+files[name] for name in sorted(files)).encode()) == SOURCE_PAYLOAD_SEAL,
            "Exact House27 logical payload/current-index seal differs")
    controls = artifact_contract()
    return {"logical_files":files,"logical_file_count":27,"room_member_count":26,
            "separate_current_index_member":True,"payload_seal":SOURCE_PAYLOAD_SEAL,
            "payload_seal_law":"Sorted path/SPACE/SHA lines, no finalLF",
            "directories":sorted(directories),"source_artifact_contract":controls}


def kitty_failure_history():
    job_raw = read_file(KITTY_EVIDENCE / "job.json", 1024 ** 2)
    log_raw = read_file(KITTY_EVIDENCE / "worker.log", 1024 ** 2)
    require(sha(job_raw) == KITTY_JOB_SHA and sha(log_raw) == KITTY_LOG_SHA,
            "Preserved original Kitty failure evidence changed")
    job = json.loads(job_raw)
    require(job.get("pid") == 6764 and job.get("exit_code") == 1 and job.get("active_at_release") == 0 and
            b"not_directory" in log_raw, "Original closed post-write Kitty stop differs")
    png = read_file(KITTY_PNG, KITTY_PNG_BYTES)
    require(len(png) == KITTY_PNG_BYTES and sha(png) == KITTY_PNG_SHA,
            "Existing original Kitty PNG differs; do not retry or overwrite it")
    return {"decoder_sha256": HELPERS["decode_kitty_spatial_raw.py"],
            "job": str(KITTY_EVIDENCE / "job.json"), "job_sha256": KITTY_JOB_SHA,
            "log": str(KITTY_EVIDENCE / "worker.log"), "log_sha256": KITTY_LOG_SHA,
            "original_pid": 6764, "original_exit_code": 1, "original_active_at_release": 0,
            "failure": "PNG was already byte-exact; the old post-write receipt gate passed that existing file as a writable directory and raised not_directory.",
            "existing_png": str(KITTY_PNG), "existing_png_sha256": KITTY_PNG_SHA,
            "existing_png_bytes": KITTY_PNG_BYTES, "existing_bytes_verified_read_only": True,
            "old_decoder_reexecuted": False, "old_evidence_or_png_modified": False,
            "retry_cleanup_or_overwrite_performed": False}


def write_gate(layout, *directories):
    paths = tuple(plain(path) for path in directories)
    require(paths and all(not path.exists() or path.is_dir() for path in paths),
            "Only directory parents may enter a write gate")
    validate_layout(layout, extra_write_paths=paths)


def admitted_layout():
    evidence = plain(os.environ["BTH_QA_EVIDENCE_DIR"])
    manifest = plain(evidence / "storage-manifest.json")
    raw = read_file(manifest, 1024 ** 2)
    record = json.loads(raw)
    require(record.get("schema") == "bth-qa-storage/v1" and record.get("prepared") is True,
            "Parent-prepared storage manifest required")
    layout = Layout(**{key: Path(value) for key, value in record["paths"].items()},
        **{key: record[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
    require(layout.root == QA_ROOT and layout.workspace == WORKSPACE and layout.evidence == evidence and
            evidence.name == "evidence" and evidence.parent.parent == QA_ROOT / "runs" and
            layout.manifest_path == manifest and layout.expected_write_bytes == 4 * 1024 ** 3 and
            layout.reserve_bytes == 20 * 1024 ** 3, "Exact House E workspace and4+20GiB admission required")
    claim_path = evidence / "launch-claim.json"
    claim_raw = read_file(claim_path, 1024 ** 2)
    claim = json.loads(claim_raw)
    require(claim.get("schema") == "bth.qa_launch_claim/v1" and claim.get("manifest_sha256") == sha(raw),
            "Actual immediate parent launch claim differs")
    write_gate(layout, OUTPUT.parent.parent, evidence)
    return layout, manifest, sha(raw), sha(claim_raw)


def existing_output_state(output):
    try:
        path = plain(output)
        if not path.exists():
            return {"present": False}
        info = path.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_size > PNG_BYTES:
            return {"present": True, "bytes": info.st_size, "exact_pinned_bytes": False,
                    "scope": "Unknown/nonregular/oversize output preserved without reading or writing"}
        data = read_file(path, PNG_BYTES)
        return {"present": True, "bytes": len(data), "sha256": sha(data),
                "exact_pinned_bytes": len(data) == PNG_BYTES and sha(data) == PNG_SHA,
                "inspection_access": "READ_ONLY_NO_RETRY"}
    except (OSError, ValueError) as error:
        return {"inspection_error": str(error), "inspection_access": "READ_ONLY_NO_RETRY"}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source-root", "workspace", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args(argv)
    output, before, source_before = None, None, None
    try:
        root, workspace, requested = map(plain, (args.source_root, args.workspace, args.output))
        require(root == SOURCE_ROOT and workspace == WORKSPACE and requested == OUTPUT,
                "Only exact D B64 source and fresh declared House E output admitted")
        output = requested
        pins = helper_pins()
        layout, manifest, manifest_sha, claim_sha = admitted_layout()
        path = plain(root / INPUT_RELATIVE)
        before = read_file(path, INPUT_BYTES)
        data, structure = decode_bytes(before)
        source_before = source_snapshot()
        history = kitty_failure_history()
        receipt = plain(layout.evidence / "house-spatial-r1-decode.json")
        require(not output.parent.exists() and not output.exists() and not receipt.exists(),
                "Fresh raw directory/PNG/receipt required; existing bytes are preserved, never retried")
        write_gate(layout, output.parent.parent)
        output.parent.mkdir()
        write_gate(layout, output.parent)
        with output.open("xb") as handle:
            handle.write(data)
        actual = read_file(output, PNG_BYTES)
        require(actual == data and read_file(path, INPUT_BYTES) == before and source_snapshot() == source_before and
                helper_pins() == pins, "Materialized PNG, retained B64, source or helper bytes changed")
        result = {"schema": "bth.house_spatial_raw_decode/v1", "status": "EXACT_GENERATED_RAW_PNG_MATERIALIZED",
            "input": str(path), "input_sha256": INPUT_SHA, "input_bytes": INPUT_BYTES,
            "output": str(output), "output_sha256": PNG_SHA, "output_bytes": PNG_BYTES, "PNG": structure,
            "source_base64_retained_unchanged": True, "active_source_snapshot": source_before,
            "active_source_unchanged": True, "helper_sha256": pins, "python_sha256": PYTHON_SHA,
            "storage_manifest": str(manifest), "storage_manifest_sha256": manifest_sha, "launch_claim_sha256": claim_sha,
            "historical_kitty_postwrite_stop": history,
            "reviewed_parent_directory_gate_predecessor": {
                "path":"tools/decode_apartment_spatial_raw.py",
                "sha256":HELPERS["decode_apartment_spatial_raw.py"],
                "executed_by_this_worker":False},
            "House_raw_first_look_limits":source_before["source_artifact_contract"]["first_look"],
            "full_master_replacement_or_candidate_assembled":False,
            "House_live_anchors_24motions_full_JSON_index_unchanged":True,
            "write_gate_policy": "Directory parents only, immediately before mkdir/PNG/receipt writes; no existing PNG enters validate_layout.",
            "only_byte_decoding": True, "pixel_editing_or_transforms": False, "network_or_children": False,
            "production_art_written": False, "outer_closed_capped_Job_receipt_required": True, "candidate_or_art_approval": False}
        require(read_file(path, INPUT_BYTES) == before and source_snapshot() == source_before,
                "Source changed before the exclusive receipt write")
        write_gate(layout, receipt.parent)
        with receipt.open("x", encoding="utf-8", newline="\n") as handle:
            json.dump(result, handle, indent=2)
            handle.write("\n")
        require(read_file(output, PNG_BYTES) == data and read_file(path, INPUT_BYTES) == before and
                source_snapshot() == source_before, "Source/output custody changed after receipt write")
        print(json.dumps(result))
        return 0
    except (OSError, ValueError, KeyError, TypeError, struct.error, binascii.Error, storage.StorageGuardError) as error:
        report = {"schema": "bth.house_spatial_raw_decode/v1", "status": "STOPPED", "error": str(error),
            "fallback_attempted": False, "retry_cleanup_or_overwrite_performed": False,
            "production_art_written": False, "outer_closed_capped_Job_receipt_required": True}
        if output == OUTPUT:
            report["output_read_only_observation"] = existing_output_state(output)
        if before is not None:
            try:
                report["retained_base64_unchanged"] = read_file(SOURCE_ROOT / INPUT_RELATIVE, INPUT_BYTES) == before
            except (OSError, ValueError) as observed:
                report["base64_observation_error"] = str(observed)
        print(json.dumps(report), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
