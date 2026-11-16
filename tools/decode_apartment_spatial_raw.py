"""Decode the one preserved Apartment source PNG in a prepared capped E Job.

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
WORKSPACE = QA_ROOT / "workspaces/BTH-ENV-SPATIAL-APARTMENTTRIAL-20261116"
OUTPUT = WORKSPACE / "raw_source/apartment-spatial-r1.png"
INPUT_RELATIVE = "review_artifacts/environment_art_sources/apartment-spatial-r1/apartment-spatial-r1.png.b64"
INPUT_SHA = "68ad91d4f97fd6db31fe5e8b13da5d3b87d113966039362f8d99f96bfc4877c7"
INPUT_BYTES = 2422977
PNG_SHA = "547e61e06a73c0e9e49502280fe5302bbe1243e8920dea3e2d23802f17c9d2a9"
PNG_BYTES = 1817231
CABX_SHA = "0af86106b80def60744efc4ad65f06f4e26c29f8db9ead20d40a16434ae6d57e"
BACKGROUND = "assets/art/environments/apartment/background.png"
BACKGROUND_SHA = "30ef28ec1cde5329b2ac3f6244df850b32d8ef423e77ee23ccdc0943c7fe1f44"
ROOM_JSON = "data/art/environments/apartment.json"
INDEX_JSON = "data/art/environments/index.json"
PYTHON_SHA = "3093fcf263029ca1d799fea250a4e032d2c930a516f1513eeca688b343c836b3"
HELPERS = {
    "bth_qa_storage.py": "cdc08bcb1ad0bff82bb5fd12f467c576cfc40a998f40870068cf6c684216f837",
    "bth_qa_guarded_run.py": "7ea6be8366f606995a1f69ddb26d99b4e3c47a0fcce9d968abe17b3dc074ad7e",
    "bth_qa_command_paths.py": "bbc405ac19ae803c2c15d93fee1ca059f25d06176cfee7926b2329b93ca4352b",
    "decode_kitty_spatial_raw.py": "532ca2652b9f88f535a7f1d71a7b2f95ac5f2bd387e3961fc212c4ebfd848636",
}
KITTY_EVIDENCE = QA_ROOT / "runs/BTH-ENV-SPATIAL-KITTYTRIAL-20261116-rawdecode01/evidence"
KITTY_JOB_SHA = "f6ed8c6be02af3551fb5ff2794c2419b2cbc9c394fe6a4cd7415fd3881e220ea"
KITTY_LOG_SHA = "3ee3a156d37eaf103d924828814e749527932b1270a477c8eb8309f5ad5704db"
KITTY_PNG = QA_ROOT / "workspaces/BTH-ENV-SPATIAL-KITTYTRIAL-20261116/raw_source/kitty-spatial-r1.png"
KITTY_PNG_SHA = "aa1078eab763def23c3d8a1b7232413384b5fcc26a86d7008866dcbf857526eb"
KITTY_PNG_BYTES = 1852735


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
    return {**HELPERS, "decode_apartment_spatial_raw.py": sha(read_file(__file__, 1024 ** 2))}


def png_structure(data):
    require(len(data) == PNG_BYTES and sha(data) == PNG_SHA and data[:8] == b"\x89PNG\r\n\x1a\n",
            "Exact original PNG length/SHA/signature differs")
    expected = ((b"IHDR", 13), (b"caBX", 21881), (b"IDAT", 1795281), (b"IEND", 0))
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
    data = base64.b64decode(encoded[:-1], validate=True)
    return data, png_structure(data)


def source_snapshot():
    art = plain(SOURCE_ROOT / "assets/art/environments/apartment")
    files, directories, pending = {}, [], [art]
    while pending:
        directory = pending.pop()
        for item in sorted(directory.iterdir()):
            item = plain(item)
            relative = item.relative_to(SOURCE_ROOT).as_posix()
            if item.is_dir():
                directories.append(relative)
                pending.append(item)
            else:
                files[relative] = sha(read_file(item, 16 * 1024 ** 2))
    require(sum(name.endswith(".png") for name in files) == 15 and files.get(BACKGROUND) == BACKGROUND_SHA,
            "Current original Apartment15-PNG/master source differs")
    for name in (ROOM_JSON, INDEX_JSON):
        files[name] = sha(read_file(SOURCE_ROOT / name, 8 * 1024 ** 2))
    return {"files": files, "directories": sorted(directories)}


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
            layout.reserve_bytes == 20 * 1024 ** 3, "Exact Apartment E workspace and4+20GiB admission required")
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
                "Only exact D B64 source and fresh declared Apartment E output admitted")
        output = requested
        pins = helper_pins()
        layout, manifest, manifest_sha, claim_sha = admitted_layout()
        path = plain(root / INPUT_RELATIVE)
        before = read_file(path, INPUT_BYTES)
        data, structure = decode_bytes(before)
        source_before = source_snapshot()
        history = kitty_failure_history()
        receipt = plain(layout.evidence / "apartment-spatial-r1-decode.json")
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
        result = {"schema": "bth.apartment_spatial_raw_decode/v1", "status": "EXACT_GENERATED_RAW_PNG_MATERIALIZED",
            "input": str(path), "input_sha256": INPUT_SHA, "input_bytes": INPUT_BYTES,
            "output": str(output), "output_sha256": PNG_SHA, "output_bytes": PNG_BYTES, "PNG": structure,
            "source_base64_retained_unchanged": True, "active_source_snapshot": source_before,
            "active_source_unchanged": True, "helper_sha256": pins, "python_sha256": PYTHON_SHA,
            "storage_manifest": str(manifest), "storage_manifest_sha256": manifest_sha, "launch_claim_sha256": claim_sha,
            "historical_kitty_postwrite_stop": history,
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
        report = {"schema": "bth.apartment_spatial_raw_decode/v1", "status": "STOPPED", "error": str(error),
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
