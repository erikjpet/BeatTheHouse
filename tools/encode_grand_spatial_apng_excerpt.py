"""Lossless, explicitly labelled first75-frame excerpt of Grand V4B capture.

The full151-frame capture remains immutable. All source capture/identity/PNG
custody is revalidated by frozen9f6. Only its first75 contiguous native900 frames
are encoded at their actual clock intervals, plus the explicit final20ms hold.
No old module/global is overridden. The frozen validator retains its own full-
capture count internally; this independent parser takes an explicit frame count.
Plan/encode/verify each run in a fresh guarded E: Job; workers start no children.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import zlib
import zipfile

import encode_grand_spatial_apng as original
from bth_qa_guarded_run import execute
from bth_qa_storage import Layout, plan_layout, prepare_layout, validate_layout

ROOT = Path("E:/CodexQA/BTH")
WORKSPACE = ROOT / "workspaces/BTH-ENV-SPATIAL-GRAND-APNG-EXCERPT-20261116"
ORIGINAL_SHA = "9f6c9a51ab5cfdd382e94943feda11b3f1dbe79b878ee68abc71d21df787305a"
CODEC_SHA = "055cb411dd3cc10b36ce9001658d9f4cb5369f4c7e4ae7e31fe86ac921e72329"
CAPTURE_SHA = "3dde0c6269c192dbfb6c69945964c2cb9f4722eb64a4e74e4f55efb7425864c0"
SOURCE_COMMIT = "24b8e34bb228335eb17db403757b9ce6f21c7151"
PACKAGE_SHA = "563ef08fec04e980c9cb2e215b2801f3612a22dd8f8250ba6247293c12f069d4"
SCHEMA = "bth.grand_spatial_apng_excerpt_phase/v1"
FRAME_COUNT = 75
SIZE = (900, 430)
MAX_BYTES = 10 * 1024 ** 2
DENOMINATOR = 10000
require, sha, ordinary_file = original.require, original.sha, original.ordinary_file
read_json, same_path = original.read_json, original.same_path
codec = original.codec


def source_inputs(args):
    require(sha(ordinary_file(Path(original.__file__))) == ORIGINAL_SHA and sha(ordinary_file(Path(codec.__file__))) == CODEC_SHA,
            "Frozen full-capture validator or lossless encoder source changed")
    require(args.capture_json_sha256 == CAPTURE_SHA and args.source_commit == SOURCE_COMMIT and
            args.candidate_package_sha256 == PACKAGE_SHA, "This version accepts only the exact closed V4B151-frame capture")
    full, all_paths, _ = original.capture_inputs(args)
    require(full["frames"] == 151 and full["scenario"] == "grand_casino_gala_night" and len(all_paths) == 151,
            "Exact original151-frame Gala capture required")
    frames = read_json(args.capture_json)["frames"]
    indices = list(range(FRAME_COUNT))
    paths = [all_paths[index] for index in indices]
    clocks = [frames[index]["clock"] for index in indices]
    delays, timing = original.clock_delays(clocks)
    require(len(delays) == FRAME_COUNT and delays[-1] == 200 and all(paths[index] == all_paths[index] for index in indices),
            "Excerpt must retain every contiguous first75 source frame and the20ms terminal hold")
    binding = {"full_original_capture": full, "original_validator_sha256": ORIGINAL_SHA, "lossless_codec_sha256": CODEC_SHA,
        "excerpt": {"explicit_excerpt": True, "complete_original_capture": False, "source_indices_zero_based": indices,
            "selected_frame_count": FRAME_COUNT, "original_frame_count": 151,
            "first_source_file": frames[0]["board900_file"], "last_source_file": frames[FRAME_COUNT - 1]["board900_file"],
            "selection": "Contiguous first75 recorded frames; no dropped or synthetic frame within excerpt",
            "timing": timing, "canvas_size": list(SIZE),
            "presentation": "Actual diagnostic900x430 production-canvas clone; an excerpt, not the complete20-second capture.",
            "full_app_and_native1800_originals_preserved": True}}
    return binding, paths, delays


def parse_apng(data, expected_count):
    """Independent count-parameterized framing/CRC/sequence verifier."""
    require(data[:8] == codec.SIGNATURE and len(data) < MAX_BYTES and expected_count == FRAME_COUNT, "Invalid/oversize excerpt APNG")
    offset, sequence, header, animation, frames, ended = 8, 0, None, None, [], False
    while offset < len(data):
        require(offset + 12 <= len(data), "Truncated APNG header")
        length = struct.unpack_from(">I", data, offset)[0]
        kind, stop = data[offset + 4:offset + 8], offset + length + 12
        require(stop <= len(data), "Truncated APNG payload")
        payload = data[offset + 8:stop - 4]
        require(zlib.crc32(kind + payload) & 0xffffffff == struct.unpack_from(">I", data, stop - 4)[0], "APNG CRC differs")
        if header is None:
            require(kind == b"IHDR" and length == 13, "First unique IHDR required")
            header = struct.unpack(">IIBBBBB", payload)
            require(header == (*SIZE, 8, 6, 0, 0, 0), "Untouched native900x430 RGBA8 required")
        elif kind == b"acTL":
            require(animation is None and not frames and length == 8, "Invalid acTL")
            animation = struct.unpack(">II", payload)
            require(animation == (expected_count, 0), "Exact selected75 frames and infinite loop required")
        elif kind == b"fcTL":
            require(animation is not None and length == 26 and (not frames or frames[-1]["compressed"]), "Invalid fcTL")
            number, width, height, x, y, delay, denominator, dispose, blend = struct.unpack(">IIIIIHHBB", payload)
            require(number == sequence, "APNG frame sequence differs")
            sequence += 1
            require(width > 0 and height > 0 and x + width <= SIZE[0] and y + height <= SIZE[1] and
                denominator == DENOMINATOR and 0 < delay < 65536 and dispose == 0 and blend == 1, "Invalid sparse frame bounds/delay/operation")
            require(frames or (x, y, width, height) == (0, 0, *SIZE), "First frame must cover complete canvas")
            frames.append({"rectangle": (x, y, width, height), "delay": delay, "compressed": bytearray()})
        elif kind == b"IDAT":
            require(len(frames) == 1 and length > 0, "IDAT only in first frame")
            frames[-1]["compressed"].extend(payload)
        elif kind == b"fdAT":
            require(len(frames) > 1 and length > 4 and struct.unpack_from(">I", payload)[0] == sequence, "Invalid fdAT")
            sequence += 1
            frames[-1]["compressed"].extend(payload[4:])
        elif kind == b"IEND":
            require(length == 0 and stop == len(data) and len(frames) == expected_count and frames[-1]["compressed"], "Missing frames or trailing APNG bytes")
            ended = True
            break
        else:
            raise ValueError("Unexpected APNG chunk: " + repr(kind))
        offset = stop
    require(ended and animation == (len(frames), 0), "Missing APNG end/count")
    return frames


def verify_apng(data, paths, delays):
    parsed = parse_apng(data, len(paths))
    require(len(paths) == len(delays) == len(parsed) == FRAME_COUNT, "Excerpt verification count differs")
    canvas = bytearray(SIZE[0] * SIZE[1] * 4)
    previous, proofs = None, []
    for index, (frame, source_path, delay) in enumerate(zip(parsed, paths, delays)):
        require(frame["delay"] == delay, "Encoded actual-clock delay differs")
        x0, y0, width, height = frame["rectangle"]
        standalone = codec.SIGNATURE + codec.chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        patch = codec.decode_png(standalone + codec.chunk(b"IDAT", bytes(frame["compressed"])) + codec.chunk(b"IEND", b""))
        source = codec.rgba_source(source_path)
        changed, xs, ys = 0, [], []
        for y in range(height):
            for x in range(width):
                local = (y * width + x) * 4
                pixel = patch.rgba[local:local + 4]
                target = ((y0 + y) * SIZE[0] + x0 + x) * 4
                require(pixel[3] in (0, 255), "Partial patch alpha is forbidden")
                if pixel[3] == 0:
                    require(pixel == bytes(4), "Unchanged sparse pixel must be transparent zero")
                else:
                    if index:
                        require(previous[target:target + 4] != source.rgba[target:target + 4], "Delta copied unchanged source pixel")
                    require(pixel == source.rgba[target:target + 4], "Patch differs from actual recorded pixel")
                    canvas[target:target + 4] = pixel
                    changed += 1
                    xs.append(x0 + x)
                    ys.append(y0 + y)
        require(bytes(canvas) == source.rgba, "Recomposed excerpt RGBA differs at source index" + str(index))
        if index:
            bounds = (min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1) if changed else (0, 0, 1, 1)
            require(frame["rectangle"] == bounds, "Sparse delta bounds are not tight")
        proofs.append({"excerpt_frame": index, "source_frame_index": index, "exact_rgba": True,
            "rgba_sha256": hashlib.sha256(source.rgba).hexdigest(), "rectangle": list(frame["rectangle"]),
            "delay_numerator": delay, "delay_denominator": DENOMINATOR})
        previous = source.rgba
    return {"all_frames_exact_rgba": True, "selected_frame_count": FRAME_COUNT, "original_frame_count": 151,
        "explicit_excerpt": True, "canvas_size": list(SIZE), "num_plays": 0, "dispose_op": "NONE", "blend_op": "OVER",
        "source_indices_zero_based": list(range(FRAME_COUNT)), "resize_crop_quantization_art_edit": False, "frames": proofs}


def output_paths(layout):
    directory = layout.workspace / "preview_artifacts"
    stem = "grand-spatial-gala-first75-excerpt-" + CAPTURE_SHA[:12] + "-900"
    return directory, directory / (stem + ".png"), directory / (stem + ".proof.json")


def declared_outputs(layout, phase):
    directory, output, final = output_paths(layout)
    paths = [directory]
    if phase == "encode":
        paths.append(output)
        if not (directory / ".gdignore").exists():
            paths.append(directory / ".gdignore")
        else:
            ordinary_file(directory / ".gdignore")
    if phase == "verify":
        paths.append(final)
    return tuple(paths)


def prior_phase(args, phase, binding):
    evidence = ROOT / "runs" / (args.run_prefix + "-" + phase) / "evidence"
    receipt, proof, job = (read_json(evidence / name) for name in ("phase-result.json", "worker-proof.json", "job.json"))
    original.storage_binding(evidence, job)
    require(receipt.get("schema") == SCHEMA and receipt.get("phase") == phase and receipt.get("status") == "PASS" and
        original.qualified_job(job) and same_path(receipt.get("job_receipt", ""), evidence / "job.json") and
        same_path(receipt.get("proof", ""), evidence / "worker-proof.json") and receipt.get("proof_sha256") == sha(evidence / "worker-proof.json") and
        receipt.get("active_at_release") == 0 and proof.get("source_binding") == binding and proof.get("adapter_sha256") == sha(__file__) and
        proof.get("source_png_hashes_unchanged") is True and not original.ERROR_LINE.search((evidence / "worker.log").read_text(encoding="utf-8", errors="replace")),
        "Prior excerpt phase is not exact closed guarded PASS: " + phase)
    return proof


def load_layout(args):
    evidence = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
    record = read_json(evidence / "storage-manifest.json")
    layout = Layout(**{key: Path(value) for key, value in record["paths"].items()},
        **{key: record[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
    validate_layout(layout)
    require(layout.prepared and same_path(layout.workspace, WORKSPACE) and same_path(layout.evidence, evidence) and
        layout.run_id == args.run_prefix + "-" + args.phase, "Exact prepared excerpt worker ownership required")
    return layout


def worker(args):
    layout = load_layout(args)
    binding, paths, delays = source_inputs(args)
    directory, output, final = output_paths(layout)
    validate_layout(layout, extra_write_paths=declared_outputs(layout, args.phase))
    inputs = read_json(layout.evidence / "phase-inputs.json")
    require(inputs.get("source_binding") == binding and inputs.get("adapter_sha256") == sha(__file__) and inputs.get("phase") == args.phase,
        "Source excerpt changed after supervisor admission")
    proof = {"schema": SCHEMA, "phase": args.phase, "source_binding": binding, "adapter_sha256": sha(__file__),
        "observed_at": datetime.now(timezone.utc).isoformat(), "art_approval": False, "test_updated": False,
        "child_processes_launched_by_worker": 0, "explicit_excerpt": True}
    if args.phase != "plan":
        prior_phase(args, "plan", binding)
    if args.phase == "encode":
        require(not output.exists() and not final.exists(), "Immutable excerpt output/proof already exists")
        data, rectangles = codec.encode_apng(paths, delays)  # Pure encoder uses len(paths), never global FRAME_COUNT.
        verification = verify_apng(data, paths, delays)
        require(source_inputs(args)[0] == binding, "Original complete capture changed while encoding excerpt")
        validate_layout(layout, extra_write_paths=(directory,))
        directory.mkdir(exist_ok=True)
        if not (directory / ".gdignore").exists():
            with (directory / ".gdignore").open("x", encoding="utf-8") as handle:
                handle.write("# Non-active faithful Grand first75-frame excerpt; not complete capture.\n")
        ordinary_file(directory / ".gdignore")
        validate_layout(layout, extra_write_paths=(directory,))
        with output.open("xb") as handle:
            handle.write(data)
        proof.update(output={"path": str(output), "sha256": sha(output), "bytes": output.stat().st_size}, encoding=rectangles, verification=verification)
    elif args.phase == "verify":
        previous = prior_phase(args, "encode", binding)
        require(sha(ordinary_file(output)) == previous["output"]["sha256"] and output.stat().st_size < MAX_BYTES, "Excerpt bytes changed/oversize")
        proof.update(output=previous["output"], verification=verify_apng(output.read_bytes(), paths, delays))
        require(sha(output) == previous["output"]["sha256"], "Excerpt changed during independent recomposition")
    require(source_inputs(args)[0] == binding, "Full original PNG/control custody changed during excerpt phase")
    proof.update(source_png_hashes_unchanged=True, status="WORKER_PASS_PENDING_JOB_CLOSE")
    original.write_new(layout.evidence / "worker-proof.json", proof, layout)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("plan", "encode", "verify"))
    for name in ("workspace", "capture-json"):
        parser.add_argument("--" + name, type=Path, required=True)
    for name in ("capture-json-sha256", "source-commit", "candidate-package-sha256", "run-prefix"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--timeout", type=int, default=1200)
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    try:
        require(same_path(args.workspace, WORKSPACE) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,70}", args.run_prefix) and
            1 <= args.timeout <= 1200, "Explicit separate excerpt workspace/fresh prefix/bounded timeout required")
        if args.worker:
            worker(args)
            return 0
        layout = plan_layout(ROOT, args.workspace, args.run_prefix + "-" + args.phase)
        binding, _, _ = source_inputs(args)
        directory, output, final = output_paths(layout)
        outputs = declared_outputs(layout, args.phase)
        validate_layout(layout, extra_write_paths=outputs)
        if args.phase != "plan":
            prior_phase(args, "plan", binding)
        if args.phase == "encode":
            require(not output.exists() and not final.exists(), "No overwriting an excerpt/proof")
        if args.phase == "verify":
            prior_phase(args, "encode", binding)
            require(not final.exists(), "No overwriting an excerpt proof")
        layout = prepare_layout(layout)
        original.write_new(layout.evidence / "phase-inputs.json", {"phase": args.phase, "source_binding": binding,
            "adapter_sha256": sha(__file__), "declared_outputs": [str(path) for path in outputs]}, layout)
        command = [sys.executable, "-B", str(Path(__file__).absolute()), args.phase, "--worker", "--workspace", str(args.workspace),
            "--capture-json", str(args.capture_json), "--capture-json-sha256", args.capture_json_sha256, "--source-commit", args.source_commit,
            "--candidate-package-sha256", args.candidate_package_sha256, "--run-prefix", args.run_prefix, "--timeout", str(args.timeout)]
        job = execute(layout, command, timeout=args.timeout, cpu_rate=1200, extra_write_paths=outputs)
        require(original.qualified_job(job) and not original.ERROR_LINE.search((layout.evidence / "worker.log").read_text(encoding="utf-8", errors="replace")),
            "Excerpt Job failed or did not close cleanly at zero")
        proof_path = layout.evidence / "worker-proof.json"
        proof = read_json(proof_path)
        require(proof.get("status") == "WORKER_PASS_PENDING_JOB_CLOSE" and proof.get("source_binding") == binding and
            proof.get("source_png_hashes_unchanged") is True and source_inputs(args)[0] == binding, "Closed excerpt proof/custody changed")
        receipt = {"schema": SCHEMA, "phase": args.phase, "status": "PASS", "job_receipt": str(layout.evidence / "job.json"),
            "active_at_release": 0, "proof": str(proof_path), "proof_sha256": sha(proof_path), "explicit_excerpt": True,
            "complete_original_capture": False, "art_approval": False, "test_updated": False}
        if args.phase == "verify":
            require(proof.get("verification", {}).get("all_frames_exact_rgba") is True, "Exact excerpt RGBA proof absent")
            original.write_new(final, {**proof, "status": "EXACT_LOSSLESS_GRAND_FIRST75_EXCERPT_VERIFIED", "closed_verify_receipt": receipt,
                "scope": "Explicit contiguous first75-frame actual900x430 diagnostic-clone excerpt; complete151-frame capture remains retained unchanged."}, layout)
            receipt.update(output=proof["output"], final_proof=str(final))
        original.write_new(layout.evidence / "phase-result.json", receipt, layout)
        print(json.dumps(receipt), flush=True)
        return 0
    except (OSError, ValueError, KeyError, TypeError, RuntimeError, IndexError, struct.error, zlib.error, zipfile.BadZipFile) as error:
        print(json.dumps({"status": "GRAND_APNG_EXCERPT_STOPPED", "phase": args.phase, "error": str(error), "fallback_attempted": False,
            "original_frames_modified": False, "test_updated": False}), file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
