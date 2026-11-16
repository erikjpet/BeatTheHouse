#!/usr/bin/env python3
"""Lossless, clock-faithful APNG of the closed V4 native Bar capture.

Run plan, encode, then verify with the same explicit E workspace/run prefix.
Each action launches exactly one fresh capped Job through the maintained guard.
Workers launch no children. No engine, codec executable, network, active asset,
save or TEST path is accessed. Outputs are exclusive-create and never replaced.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
import hashlib
import json
import math
import os
from pathlib import Path
import re
import stat
import struct
import zlib

from bar_spatial_candidate_check import ANIMATION_IDS, decode_png
from bth_qa_guarded_run import execute
from bth_qa_storage import Layout, plan_layout, prepare_layout, validate_layout

ROOT = Path("E:/CodexQA/BTH")
WORKSPACE = ROOT / "workspaces/BTH-ENV-SPATIAL-BARTRIAL-20261116"
CAPTURE = ROOT / "runs/BTH-ENV-SPATIAL-BARTRIAL-20261116-v4-suite-capture/evidence/capture/animation_capture.json"
CAPTURE_SHA256 = "ec3f96e7c3883676e31e32c8406f71f2fd5a13adc922c6104cc524bdeaec28b9"
CANDIDATE_SHA256 = "a870d3652a72d3ebb5067fe9e46b412f3c2a5b938a40e4c3b2cf72e0be7a2408"
NATIVE_IDENTITY = "746733ecaf3b22b9a1269aa916331bb8b09e043dc0bb3a6f1af737894f285a03"
SIZE = (900, 430)
FRAME_COUNT = 152
DENOMINATOR = 10000
LAST_TICKS = 200  # Explicit final 20 ms presentation tick, not another capture.
MAX_BYTES = 10 * 1024 ** 2
SIGNATURE = b"\x89PNG\r\n\x1a\n"
ERROR_LINE = re.compile(r"(?:SCRIPT ERROR|(?<![A-Z])ERROR):")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def same_path(left, right):
    return os.path.normcase(os.path.abspath(left)) == os.path.normcase(os.path.abspath(right))


def ordinary_file(path):
    """Reject reparse files and ancestors before reading immutable inputs."""
    path = Path(path)
    for part in (path, *path.parents):
        info = part.lstat()
        require(not (getattr(info, "st_file_attributes", 0) & 0x400) and not stat.S_ISLNK(info.st_mode),
                "Reparse input forbidden: " + str(part))
    require(path.is_file(), "Missing ordinary input: " + str(path))
    return path


def qualified_job(job):
    limits = job.get("limits", {})
    return (job.get("exit_code") == 0 and job.get("active_at_release") == 0 and
            job.get("assigned_before_execution") is True and
            all(not job.get(key) for key in ("error", "cleanup_errors", "timed_out", "log_error", "log_truncated")) and
            bool(job.get("storage_gate_before_job")) and bool(job.get("storage_gate_before_child")) and
            limits.get("cpu_rate") == 1200 and limits.get("job_memory_limit_bytes") == 2 * 1024 ** 3 and
            limits.get("kill_on_close") is True and limits.get("breakaway_allowed") is False and
            type(job.get("finished_epoch")) in (int, float) and math.isfinite(job["finished_epoch"]))


def timing(clocks):
    values = [Decimal(str(value)) for value in clocks]
    require(len(values) == FRAME_COUNT and all(value.is_finite() for value in values), "Exact finite 152 clocks required")
    differences = [right - left for left, right in zip(values, values[1:])]
    require(all(value > 0 for value in differences), "Capture clocks must strictly increase")
    ticks = [int((delta * DENOMINATOR).quantize(Decimal(1), rounding=ROUND_HALF_UP)) for delta in differences]
    ticks.append(LAST_TICKS)
    require(all(0 < value < 65536 for value in ticks), "APNG delay numerator exceeds positive uint16")
    elapsed = Decimal(0)
    errors = []
    for index, value in enumerate(values):
        errors.append(abs(elapsed - (value - values[0])))
        elapsed += Decimal(ticks[index]) / DENOMINATOR
    span = values[-1] - values[0]
    require(max(errors) <= Decimal("0.05") and abs(elapsed - span - Decimal("0.02")) <= Decimal("0.05"),
            "Rounded frame clock/duration error exceeds 0.05 seconds")
    return ticks, {"first_scene_clock": str(values[0]), "last_scene_clock": str(values[-1]),
        "scene_clock_span_seconds": str(span), "duration_seconds": str(elapsed),
        "maximum_frame_clock_error_seconds": str(max(errors)), "denominator": DENOMINATOR,
        "last_frame_ticks": LAST_TICKS, "last_frame_policy": "Explicit 20 ms presentation tick", "delay_numerators": ticks,
        "loop_boundary": "Infinite playback returns to the captured first frame after the explicit final hold; no interpolated frames."}


def capture_inputs(path):
    require(same_path(path, CAPTURE), "Only the exact closed V4 capture is admitted")
    path = ordinary_file(path)
    evidence = path.parent.parent
    receipt_path, job_path = evidence / "phase-result.json", evidence / "job.json"
    for item in (receipt_path, job_path, evidence / "worker.log", evidence / "suite-inputs.json",
                 evidence / "storage-manifest.json", evidence / "launch-claim.json"):
        ordinary_file(item)
    receipt, job = read_json(receipt_path), read_json(job_path)
    suite = read_json(evidence / "suite-inputs.json")
    identity = suite.get("identity", {})
    identity_payload = {key: value for key, value in identity.items() if key != "identity_sha256"}
    actual_identity = hashlib.sha256(json.dumps(identity_payload, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    require(actual_identity == identity.get("identity_sha256") == NATIVE_IDENTITY and
            identity.get("candidate_sha256") == CANDIDATE_SHA256 and same_path(identity.get("workspace", ""), WORKSPACE) and
            suite.get("phase") == "capture" and job.get("command") == suite.get("command"),
            "Native capture input identity/command differs from its closed receipt")
    storage_path = evidence / "storage-manifest.json"
    claim = read_json(evidence / "launch-claim.json")
    require(same_path(job.get("storage_manifest", ""), storage_path) and
            sha(storage_path) == job.get("storage_manifest_sha256") == claim.get("manifest_sha256"),
            "Source Job/claim actual storage-manifest hashes differ")
    manifest_path = ordinary_file(WORKSPACE / "data/art/environments/bar.json")
    require(sha(manifest_path) == identity.get("production_source_sha256", {}).get("data/art/environments/bar.json") and
            [row.get("id") for row in read_json(manifest_path).get("animations", [])] == list(ANIMATION_IDS),
            "Source native manifest does not retain the exact closed 17-entry inventory")
    require(receipt.get("schema") == "bth.bar_spatial_native_phase/v1" and receipt.get("phase") == "capture" and
            receipt.get("status") == "PASS" and receipt.get("candidate_sha256") == CANDIDATE_SHA256 and
            receipt.get("identity_sha256") == NATIVE_IDENTITY and same_path(receipt.get("job_receipt", ""), job_path),
            "Source phase must be exact closed native capture PASS")
    require(qualified_job(job), "Source capture Job is not closed at zero with exact guarded caps")
    require(not ERROR_LINE.search((evidence / "worker.log").read_text(encoding="utf-8", errors="replace")),
            "Source native log has ERROR/SCRIPT ERROR")
    result = receipt.get("result", {})
    require(same_path(result.get("report", ""), path) and sha(path) == CAPTURE_SHA256 == result.get("sha256") and
            result.get("frames") == FRAME_COUNT and not result.get("findings") and not result.get("failures"),
            "Closed metadata/report hash or exact 152-frame coverage differs")
    metadata = read_json(path)
    frames = metadata.get("frames", [])
    require(metadata.get("archetype") == "bar" and metadata.get("scenario") == "bar_fight_night" and
            metadata.get("pack_active") is True and metadata.get("board900_is_qa_clone") is True and
            metadata.get("board900_size") == list(SIZE) and metadata.get("measured_frame_count") == FRAME_COUNT and
            len(frames) == FRAME_COUNT and metadata.get("reduce_motion", {}).get("active") is True and
            metadata.get("reduce_motion", {}).get("production_art_texture_pixels_stable") is True,
            "Exact active native Bar board clone/Reduce Motion capture required")
    require([row.get("id") for row in metadata.get("animation_inventory", [])] == list(ANIMATION_IDS) and
            all([row.get("id") for row in frame.get("animation_states", [])] == list(ANIMATION_IDS) for frame in frames),
            "All 17 animation IDs must exist in source inventory and every frame")
    equivalence = metadata.get("board900_equivalence", [])
    require(len(equivalence) == FRAME_COUNT and all(row.get("frame") == index and
            all(row.get(key) is True for key in ("actor_route_clock_equal", "animation_clock_equal", "object_layout_equal", "objects_equal"))
            for index, row in enumerate(equivalence)), "All 152 exact clock/layout/object equivalence rows required")
    board_paths = []
    for index, frame in enumerate(frames):
        clock = frame.get("clock")
        require(type(clock) in (int, float) and math.isfinite(clock) and frame.get("board900_clock") == clock,
                "Actual scene and board clocks differ or are invalid")
        for key, prefix in (("file", "frame"), ("board900_file", "board900"), ("board2x_file", "board2x")):
            require(frame.get(key) == f"{prefix}_{index:03d}.png", "Unexpected source frame path")
            ordinary_file(path.parent / frame[key])
        board_paths.append(path.parent / frame["board900_file"])
    ticks, clocks = timing([frame["clock"] for frame in frames])
    require(abs(float(clocks["scene_clock_span_seconds"]) - metadata.get("actual_clock_span", -1)) < 1e-5 and
            abs(metadata["actual_clock_span"] - 20.1192493333333) < 1e-5, "Actual scene clock span differs")
    source_files = sorted(path.parent.glob("*.png"), key=lambda item: item.name)
    require(len(source_files) >= FRAME_COUNT * 3, "Retained full-app/1800-art/900-board originals missing")
    # Include every captured PNG, not only the 152 board inputs, in custody proof.
    sources = {item.name: sha(ordinary_file(item)) for item in source_files}
    controls = {item.name: sha(item) for item in (path, receipt_path, job_path, evidence / "worker.log",
                evidence / "suite-inputs.json", evidence / "storage-manifest.json", evidence / "launch-claim.json", manifest_path)}
    binding = {"capture_json": str(path), "controls_sha256": controls, "source_png_sha256": sources,
        "png_decoder_sha256": sha(ordinary_file(Path(decode_png.__code__.co_filename))),
        "candidate_sha256": CANDIDATE_SHA256, "native_identity_sha256": NATIVE_IDENTITY,
        "board900_source": metadata.get("board900_source"), "canvas_size": list(SIZE),
        "frames": FRAME_COUNT, "animation_ids": list(ANIMATION_IDS), "timing": clocks,
        "source_phase_closed_pass": True, "source_job_active_at_release": 0,
        "all_152_board_clones_clock_layout_object_equal": True}
    return binding, board_paths, ticks


def chunk(kind, payload):
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff)


def rgba_source(path):
    image = decode_png(Path(path).read_bytes())
    require((image.width, image.height) == SIZE, "Source board must remain 900x430: " + str(path))
    require(image.rgba[3::4] == b"\xff" * (SIZE[0] * SIZE[1]), "Source board contains non-opaque RGBA pixels")
    return image


def delta_patch(previous, current):
    """Tight changed-pixel rectangle; unchanged pixels inside are transparent zero."""
    width, height = SIZE
    left, top, right, bottom = width, height, -1, -1
    changed = []
    for y in range(height):
        start, end = y * width * 4, (y + 1) * width * 4
        if previous[start:end] == current[start:end]:
            continue
        for x in range(width):
            offset = start + x * 4
            if previous[offset:offset + 4] != current[offset:offset + 4]:
                changed.append((x, y))
                left, top, right, bottom = min(left, x), min(top, y), max(right, x), max(bottom, y)
    if not changed:
        return (0, 0, 1, 1), bytes(4), 0
    patch_width, patch_height = right - left + 1, bottom - top + 1
    pixels = bytearray(patch_width * patch_height * 4)
    for x, y in changed:
        source = (y * width + x) * 4
        target = ((y - top) * patch_width + x - left) * 4
        pixels[target:target + 4] = current[source:source + 4]
    return (left, top, patch_width, patch_height), bytes(pixels), len(changed)


def deflate_rgba(width, height, pixels):
    require(len(pixels) == width * height * 4, "Invalid encoder patch size")
    # Filter 0 keeps sparse transparent pixels exactly zero; no quantization.
    compressor = zlib.compressobj(9)
    parts = []
    for y in range(height):
        parts.append(compressor.compress(b"\0" + pixels[y * width * 4:(y + 1) * width * 4]))
    parts.append(compressor.flush())
    return b"".join(parts)


def encode_apng(paths, delays):
    width, height = SIZE
    pieces = [SIGNATURE, chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)),
              chunk(b"acTL", struct.pack(">II", len(paths), 0))]
    sequence, previous, rows = 0, None, []
    for index, (path, delay) in enumerate(zip(paths, delays)):
        image = rgba_source(path)
        if index == 0:
            rectangle, pixels, changed = (0, 0, width, height), image.rgba, width * height
        else:
            rectangle, pixels, changed = delta_patch(previous, image.rgba)
        x, y, patch_width, patch_height = rectangle
        control = struct.pack(">IIIIIHHBB", sequence, patch_width, patch_height, x, y, delay, DENOMINATOR, 0, 1)
        pieces.append(chunk(b"fcTL", control))
        sequence += 1
        compressed = deflate_rgba(patch_width, patch_height, pixels)
        if index == 0:
            pieces.append(chunk(b"IDAT", compressed))
        else:
            pieces.append(chunk(b"fdAT", struct.pack(">I", sequence) + compressed))
            sequence += 1
        rows.append({"frame": index, "rectangle": list(rectangle), "changed_opaque_pixels": changed,
                     "delay_numerator": delay, "delay_denominator": DENOMINATOR})
        previous = image.rgba
    pieces.append(chunk(b"IEND", b""))
    encoded = b"".join(pieces)
    require(len(encoded) < MAX_BYTES, "Lossless APNG exceeds the strict 10 MiB Page limit; no fallback attempted")
    return encoded, rows


def parse_apng(data):
    """Independent strict APNG framing/CRC/sequence parser; no encoder records used."""
    require(data[:8] == SIGNATURE and len(data) < MAX_BYTES, "Invalid/oversize APNG")
    offset, sequence, header, animation, frames, ended = 8, 0, None, None, [], False
    while offset < len(data):
        require(offset + 12 <= len(data), "Truncated APNG chunk header")
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4:offset + 8]
        stop = offset + length + 12
        require(stop <= len(data), "Truncated APNG chunk")
        payload = data[offset + 8:stop - 4]
        require(zlib.crc32(kind + payload) & 0xffffffff == struct.unpack_from(">I", data, stop - 4)[0], "APNG CRC differs")
        if header is None:
            require(kind == b"IHDR" and length == 13, "APNG IHDR must be first and unique")
            header = struct.unpack(">IIBBBBB", payload)
            require(header == (*SIZE, 8, 6, 0, 0, 0), "APNG canvas must be untouched 900x430 RGBA8")
        elif kind == b"acTL":
            require(animation is None and not frames and length == 8, "Invalid acTL placement/count")
            animation = struct.unpack(">II", payload)
            require(animation == (FRAME_COUNT, 0), "Exact 152 frames with infinite loop required")
        elif kind == b"fcTL":
            require(animation is not None and length == 26 and (not frames or frames[-1]["compressed"]), "Invalid fcTL placement")
            number, width, height, x, y, delay, denominator, dispose, blend = struct.unpack(">IIIIIHHBB", payload)
            require(number == sequence, "APNG sequence number differs")
            sequence += 1
            require(width > 0 and height > 0 and x + width <= SIZE[0] and y + height <= SIZE[1] and
                    denominator == DENOMINATOR and 0 < delay < 65536 and dispose == 0 and blend == 1,
                    "Invalid frame bounds/delay/disposeNONE/blendOVER")
            require(frames or (x, y, width, height) == (0, 0, *SIZE), "First IDAT frame must cover the entire canvas")
            frames.append({"rectangle": (x, y, width, height), "delay": delay, "compressed": bytearray()})
        elif kind == b"IDAT":
            require(len(frames) == 1 and length > 0, "IDAT allowed only for first full frame")
            frames[-1]["compressed"].extend(payload)
        elif kind == b"fdAT":
            require(len(frames) > 1 and length > 4, "fdAT allowed only after first frame")
            require(struct.unpack_from(">I", payload)[0] == sequence, "APNG fdAT sequence number differs")
            sequence += 1
            frames[-1]["compressed"].extend(payload[4:])
        elif kind == b"IEND":
            require(length == 0 and stop == len(data) and len(frames) == FRAME_COUNT and frames[-1]["compressed"],
                    "APNG missing frames/data or has trailing bytes")
            ended = True
            break
        else:
            raise ValueError("Unexpected APNG chunk: " + repr(kind))
        offset = stop
    require(ended and animation == (len(frames), 0), "APNG missing IEND/acTL or frame count differs")
    return frames


def verify_apng(data, paths, delays):
    parsed = parse_apng(data)
    require(len(paths) == len(delays) == len(parsed) == FRAME_COUNT, "Verification frame count differs")
    canvas = bytearray(SIZE[0] * SIZE[1] * 4)
    previous = None
    proofs = []
    for index, (frame, source_path, delay) in enumerate(zip(parsed, paths, delays)):
        require(frame["delay"] == delay, "Encoded timestamp delay differs at frame " + str(index))
        x0, y0, width, height = frame["rectangle"]
        # Reconstruct a standalone patch PNG, then use the maintained independent
        # filter/deflate decoder; this does not trust the encoder's patch bytes.
        standalone = SIGNATURE + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        patch = decode_png(standalone + chunk(b"IDAT", bytes(frame["compressed"])) + chunk(b"IEND", b""))
        source = rgba_source(source_path)
        changed, xs, ys = 0, [], []
        for y in range(height):
            for x in range(width):
                local = (y * width + x) * 4
                pixel = patch.rgba[local:local + 4]
                target = ((y0 + y) * SIZE[0] + x0 + x) * 4
                require(pixel[3] in (0, 255), "APNG patch has partial alpha")
                if pixel[3] == 0:
                    require(pixel == bytes(4), "Unchanged sparse pixel must be transparent zero")
                else:
                    if index:
                        require(previous[target:target + 4] != source.rgba[target:target + 4],
                                "Delta copied an unchanged pixel")
                    require(pixel == source.rgba[target:target + 4], "Opaque delta pixel differs from actual capture")
                    canvas[target:target + 4] = pixel
                    changed += 1
                    xs.append(x0 + x)
                    ys.append(y0 + y)
        require(bytes(canvas) == source.rgba, "Recomposed APNG differs from actual source frame " + str(index))
        if index:
            expected = (min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1) if changed else (0, 0, 1, 1)
            require(frame["rectangle"] == expected, "Delta bounding rectangle is not tight")
        proofs.append({"frame": index, "exact_rgba": True, "rgba_sha256": hashlib.sha256(source.rgba).hexdigest(),
            "rectangle": list(frame["rectangle"]), "opaque_patch_pixels": changed, "delay_numerator": delay,
            "delay_denominator": DENOMINATOR})
        previous = source.rgba
    return {"all_frames_exact_rgba": True, "frame_count": len(proofs), "canvas_size": list(SIZE),
        "num_plays": 0, "dispose_op": "NONE", "blend_op": "OVER", "all_patch_alphas_zero_or_255": True,
        "all_transparent_pixels_zero_rgba": True, "all_deltas_tight_and_only_changed_opaque_pixels": True,
        "source_frames_opaque": True, "resize_crop_quantization_art_edit": False, "frames": proofs}


def load_layout():
    receipt_path = Path(os.environ["BTH_QA_EVIDENCE_DIR"]) / "storage-manifest.json"
    receipt = read_json(receipt_path)
    layout = Layout(**{key: Path(value) for key, value in receipt["paths"].items()},
        **{key: receipt[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
    validate_layout(layout)
    require(layout.prepared and same_path(layout.workspace, WORKSPACE), "Exact prepared E workspace required")
    return layout


def declared_outputs(layout, phase):
    directory = layout.workspace / "preview_artifacts"
    outputs = [directory]
    if phase == "encode":
        outputs.append(directory / "bar-v4-fight-900.png")
        if not (directory / ".gdignore").exists():
            outputs.append(directory / ".gdignore")
        else:
            ordinary_file(directory / ".gdignore")
    elif phase == "verify":
        outputs.append(directory / "bar-v4-fight-900.proof.json")
    return tuple(outputs)


def write_new(path, payload, layout):
    validate_layout(layout, extra_write_paths=(Path(path).parent,))
    with Path(path).open("x", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
        handle.write("\n")


def phase_paths(prefix, phase):
    evidence = ROOT / "runs" / (prefix + "-" + phase) / "evidence"
    return evidence / "phase-result.json", evidence / "worker-proof.json"


def prior_phase(prefix, phase, binding):
    receipt_path, proof_path = phase_paths(prefix, phase)
    receipt, proof = read_json(ordinary_file(receipt_path)), read_json(ordinary_file(proof_path))
    job = read_json(ordinary_file(receipt_path.parent / "job.json"))
    require(receipt.get("status") == "PASS" and receipt.get("phase") == phase and qualified_job(job) and
            same_path(receipt.get("job_receipt", ""), receipt_path.parent / "job.json") and
            same_path(receipt.get("proof", ""), proof_path) and receipt.get("active_at_release") == 0 and
            receipt.get("proof_sha256") == sha(proof_path) and proof.get("source_binding") == binding and
            proof.get("adapter_sha256") == sha(__file__) and proof.get("source_png_hashes_unchanged") is True and
            not ERROR_LINE.search((receipt_path.parent / "worker.log").read_text(encoding="utf-8", errors="replace")),
            "Prior APNG phase is not exact closed PASS: " + phase)
    return proof


def worker(args):
    layout = load_layout()
    require(layout.run_id == args.run_prefix + "-" + args.phase, "Worker phase/run ownership differs")
    directory = layout.workspace / "preview_artifacts"
    output, final_proof = directory / "bar-v4-fight-900.png", directory / "bar-v4-fight-900.proof.json"
    validate_layout(layout, extra_write_paths=declared_outputs(layout, args.phase))
    admitted = read_json(layout.evidence / "phase-inputs.json")
    binding, paths, delays = capture_inputs(args.capture_json)
    require(admitted["source_binding"] == binding and admitted["adapter_sha256"] == sha(__file__) and
            admitted["phase"] == args.phase, "Inputs changed after supervisor admission")
    proof = {"schema": "bth.bar_spatial_apng_phase/v1", "phase": args.phase, "source_binding": binding,
        "adapter_sha256": sha(__file__), "observed_at": datetime.now(timezone.utc).isoformat(),
        "art_approval": False, "test_updated": False, "child_processes_launched_by_worker": 0}
    if args.phase != "plan":
        prior_phase(args.run_prefix, "plan", binding)
    if args.phase == "encode":
        require(not output.exists() and not final_proof.exists(), "Immutable APNG/proof output already exists")
        encoded, rectangles = encode_apng(paths, delays)
        verification = verify_apng(encoded, paths, delays)
        require(capture_inputs(args.capture_json)[0] == binding, "Original source/control hash changed during encoding")
        validate_layout(layout, extra_write_paths=(directory,))
        directory.mkdir(exist_ok=True)
        if not (directory / ".gdignore").exists():
            with (directory / ".gdignore").open("x", encoding="utf-8") as handle:
                handle.write("# Non-active exact native preview; excluded from game imports.\n")
        require((directory / ".gdignore").is_file(), "Preview .gdignore is not an ordinary file")
        validate_layout(layout, extra_write_paths=(directory,))
        with output.open("xb") as handle:
            handle.write(encoded)
        proof.update({"output": {"path": str(output), "sha256": sha(output), "bytes": output.stat().st_size},
                      "encoding": rectangles, "verification": verification})
    elif args.phase == "verify":
        prior = prior_phase(args.run_prefix, "encode", binding)
        ordinary_file(output)
        require(output.stat().st_size < MAX_BYTES and sha(output) == prior["output"]["sha256"], "Immutable encoded output hash/size differs")
        encoded = output.read_bytes()
        proof.update({"output": prior["output"], "verification": verify_apng(encoded, paths, delays)})
        require(sha(output) == prior["output"]["sha256"], "APNG changed during independent verify")
    after = capture_inputs(args.capture_json)[0]
    require(after == binding, "Source PNG or native control hashes changed during APNG phase")
    proof.update({"source_png_hashes_unchanged": True, "all_source_png_count": len(binding["source_png_sha256"]),
        "source_png_sha256_before": binding["source_png_sha256"], "source_png_sha256_after": after["source_png_sha256"],
        "status": "WORKER_PASS_PENDING_JOB_CLOSE"})
    write_new(layout.evidence / "worker-proof.json", proof, layout)
    print(json.dumps({"status": proof["status"], "phase": args.phase}), flush=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("plan", "encode", "verify"))
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--capture-json", type=Path, required=True)
    parser.add_argument("--run-prefix", required=True)
    parser.add_argument("--timeout", type=int, default=1200)
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args(argv)
    try:
        require(same_path(args.workspace, WORKSPACE) and same_path(args.capture_json, CAPTURE), "Exact E workspace and closed capture paths required")
        require(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,70}", args.run_prefix) is not None and 1 <= args.timeout <= 1200,
                "Run prefix must fit fresh per-phase IDs; timeout must be 1..1200")
        if args.worker:
            worker(args)
            return 0
        # No writes/children before these storage checks. Each action owns one
        # fresh profile/temp/evidence set; all outputs are explicitly admitted.
        layout = plan_layout(root=ROOT, workspace=args.workspace, run_id=args.run_prefix + "-" + args.phase)
        directory = layout.workspace / "preview_artifacts"
        outputs = declared_outputs(layout, args.phase)
        validate_layout(layout, extra_write_paths=outputs)
        binding, _, _ = capture_inputs(args.capture_json)
        if args.phase != "plan":
            prior_phase(args.run_prefix, "plan", binding)
        if args.phase == "encode":
            require(not (directory / "bar-v4-fight-900.png").exists() and not (directory / "bar-v4-fight-900.proof.json").exists(),
                    "Immutable output already exists; preserve it")
        if args.phase == "verify":
            prior_phase(args.run_prefix, "encode", binding)
            require(not (directory / "bar-v4-fight-900.proof.json").exists(), "Final immutable proof already exists")
        layout = prepare_layout(layout)
        write_new(layout.evidence / "phase-inputs.json", {"phase": args.phase, "source_binding": binding,
            "adapter_sha256": sha(__file__), "declared_outputs": [str(path) for path in outputs]}, layout)
        command = [sys.executable, "-B", str(Path(__file__).absolute()), args.phase, "--worker", "--workspace", str(args.workspace),
                   "--capture-json", str(args.capture_json), "--run-prefix", args.run_prefix, "--timeout", str(args.timeout)]
        print(json.dumps({"status": "STARTING_GUARDED_APNG_PHASE", "phase": args.phase, "run_id": layout.run_id}), flush=True)
        job = execute(layout, command, timeout=args.timeout, cpu_rate=1200, extra_write_paths=outputs)
        require(qualified_job(job), "APNG Job failed or did not close at zero; see " + str(layout.evidence / "job.json"))
        require(not ERROR_LINE.search((layout.evidence / "worker.log").read_text(encoding="utf-8", errors="replace")), "APNG worker logged ERROR")
        proof_path = layout.evidence / "worker-proof.json"
        proof = read_json(proof_path)
        require(proof.get("status") == "WORKER_PASS_PENDING_JOB_CLOSE" and proof.get("source_binding") == binding and
                proof.get("source_png_hashes_unchanged") is True and capture_inputs(args.capture_json)[0] == binding,
                "Closed APNG worker proof/source custody differs")
        receipt = {"schema": "bth.bar_spatial_apng_phase/v1", "phase": args.phase, "status": "PASS",
            "job_receipt": str(layout.evidence / "job.json"), "active_at_release": 0,
            "proof": str(proof_path), "proof_sha256": sha(proof_path), "art_approval": False, "test_updated": False}
        if args.phase == "verify":
            require(proof.get("verification", {}).get("all_frames_exact_rgba") is True, "Independent RGBA proof absent")
            final = {**proof, "status": "EXACT_LOSSLESS_APNG_VERIFIED", "closed_verify_receipt": receipt,
                     "scope": "Actual 900x430 diagnostic production-canvas clone; original full-app and 1800-art PNGs retained."}
            write_new(directory / "bar-v4-fight-900.proof.json", final, layout)
            receipt["output"] = proof["output"]
            receipt["final_proof"] = str(directory / "bar-v4-fight-900.proof.json")
        # A phase PASS is emitted only after every declared deliverable exists.
        write_new(layout.evidence / "phase-result.json", receipt, layout)
        print(json.dumps(receipt), flush=True)
        return 0
    except (OSError, ValueError, KeyError, RuntimeError, struct.error, zlib.error) as error:
        print(json.dumps({"status": "APNG_PHASE_STOPPED", "phase": args.phase, "error": str(error),
            "fallback_attempted": False, "original_frames_modified": False, "test_updated": False}), file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
