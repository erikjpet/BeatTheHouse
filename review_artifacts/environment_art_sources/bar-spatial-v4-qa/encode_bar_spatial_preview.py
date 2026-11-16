"""Encode an authentic Bar full-app recording using its actual capture clocks.

Explicit phases: plan, prepare, encode, verify. Every actual child belongs to a
fresh admitted E: Job (12% CPU,2GiB). No original frame or capture file is changed.
The only picture transform is the GIF format's256-color palette conversion.
"""
import sys
sys.dont_write_bytecode = True

import argparse
from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import struct

from bth_qa_storage import Layout, plan_layout, prepare_layout, validate_layout
from bth_qa_guarded_run import execute


PHASES = ("prepare", "encode", "verify")
PAGE_BYTES = 10_000_000
TOLERANCE = Decimal("0.05")
FINAL_TICK_CS = 2  # One20ms presentation tick; no repeated terminal picture.
FFMPEG_DEFAULT = "C:/Users/theep/AppData/Local/Microsoft/WinGet/Links/ffmpeg.exe"
FILTER = ("[0:v]split=2[images][stats];"
          "[stats]palettegen=max_colors=256:stats_mode=full[palette];"
          "[images][palette]paletteuse=dither=none[out]")
ERROR_LINE = re.compile(r"(?:SCRIPT ERROR|(?<![A-Z])ERROR):|\[error\]|Error (?:opening|while|initializing)")


def sha(path):
    result = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for data in iter(lambda: handle.read(1024 * 1024), b""):
            result.update(data)
    return result.hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def write_json_new(path, value):
    with Path(path).open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def plain_path(path):
    """Reject source/output links; explicitly selected read-only binaries may resolve links."""
    path = Path(path).absolute()
    for item in (path, *path.parents):
        if item.exists() and (item.is_symlink() or
                getattr(item.lstat(), "st_file_attributes", 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT):
            raise ValueError("Linked source/output path is not admitted: " + str(item))
    return path


def finite_decimal(value, label):
    if isinstance(value, bool) or not isinstance(value, (int, float, str)):
        raise ValueError("Non-numeric " + label)
    number = Decimal(str(value))
    if not number.is_finite():
        raise ValueError("Non-finite " + label)
    return number


def qualified_job(job):
    return (job.get("exit_code") == 0 and job.get("active_at_release") == 0 and
            job.get("assigned_before_execution") and not any(job.get(key) for key in
                ("error", "cleanup_errors", "timed_out", "log_error", "log_truncated")) and
            "storage_gate_before_job" in job and "storage_gate_before_child" in job and
            job.get("limits", {}).get("cpu_rate") == 1200 and
            job.get("limits", {}).get("job_memory_limit_bytes") == 2 * 1024 ** 3)


def source_capture(capture_dir, root):
    directory = plain_path(capture_dir).resolve(strict=True)
    if not directory.is_relative_to(root.resolve(strict=True)):
        raise ValueError("Capture input must remain under the admitted E: root")
    report_path = directory / "animation_capture.json"
    parent = directory.parent
    phase, job = read_json(parent / "phase-result.json"), read_json(parent / "job.json")
    if (phase.get("phase") != "capture" or phase.get("status") != "PASS" or
            not qualified_job(job) or ERROR_LINE.search((parent / "worker.log").read_text(encoding="utf-8")) or
            phase.get("result", {}).get("sha256") != sha(report_path)):
        raise ValueError("Capture must be complete, exact and qualified; an active/partial recording cannot be encoded")
    capture = read_json(report_path)
    frames, inventory = capture.get("frames", []), capture.get("animation_inventory", [])
    ids = [row.get("id") for row in inventory]
    if (capture.get("archetype") != "bar" or not capture.get("pack_active") or
            len(frames) < 2 or capture.get("measured_frame_count") != len(frames) or
            len(ids) != 17 or len(set(ids)) != 17 or not all(isinstance(name, str) and name for name in ids) or
            "no pointer input during capture" not in capture.get("note", "") or
            capture.get("actual_arrival_wait", {}).get("input_during_wait") is not False or
            capture.get("board900_arrival_wait", {}).get("input_during_wait") is not False):
        raise ValueError("Exact Bar17 inventory and authentic no-input recording metadata required")
    clocks = [finite_decimal(row.get("clock"), "capture clock") for row in frames]
    if any(b <= a for a, b in zip(clocks, clocks[1:])):
        raise ValueError("Recording clocks must increase strictly")
    span = clocks[-1] - clocks[0]
    if (abs(span - finite_decimal(capture.get("actual_clock_span"), "declared actual span")) > Decimal("0.00001") or
            not 0 < finite_decimal(capture.get("capture_seconds_requested"), "requested excerpt") <= 20):
        raise ValueError("Capture span or bounded excerpt metadata differs")
    ledger, seen, size = [], set(), None
    for index, row in enumerate(frames):
        name = row.get("file", "")
        if (not isinstance(name, str) or not re.fullmatch(r"[A-Za-z0-9_-]+\.png", name) or name in seen or
                [state.get("id") for state in row.get("animation_states", [])] != ids):
            raise ValueError("Unsafe/repeated frame name or changed17-entry frame state")
        seen.add(name)
        path = plain_path(directory / name)
        with path.open("rb") as handle:
            header = handle.read(24)
        if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
            raise ValueError("Invalid PNG frame header: " + name)
        dimensions = list(struct.unpack(">II", header[16:24]))
        if dimensions != [row.get("width"), row.get("height")] or (size is not None and dimensions != size):
            raise ValueError("Full-app frame dimensions differ: " + name)
        size = dimensions
        normalized = clocks[index] - clocks[0]
        centiseconds = int((normalized * 100).quantize(Decimal(1), rounding=ROUND_HALF_UP))
        if ledger and centiseconds <= ledger[-1]["expected_pts_centiseconds"]:
            raise ValueError("Capture cadence cannot be represented without dropping a frame at GIF centisecond precision")
        duration = clocks[index + 1] - clocks[index] if index + 1 < len(frames) else None
        if duration is not None and duration > Decimal("655.35"):
            raise ValueError("Frame hold exceeds GIF range")
        ledger.append({"index": index, "file": name, "path": str(path), "sha256": sha(path),
            "bytes": path.stat().st_size, "dimensions": dimensions, "source_clock": str(clocks[index]),
            "normalized_seconds": str(normalized), "duration_until_next_seconds": None if duration is None else str(duration),
            "expected_pts_centiseconds": centiseconds, "terminal_display_tick_centiseconds": FINAL_TICK_CS if duration is None else 0})
    return {"schema": "bth.bar_preview_capture/v1", "directory": str(directory),
        "capture_json": str(report_path), "capture_sha256": sha(report_path), "capture_job_sha256": sha(parent / "job.json"),
        "capture_phase_receipt_sha256": sha(parent / "phase-result.json"), "candidate_sha256": phase.get("candidate_sha256"),
        "scenario": capture.get("scenario"), "animation_ids": ids, "no_input_metadata": {
            "note": capture["note"], "actual_arrival_wait": capture["actual_arrival_wait"],
            "board900_arrival_wait": capture["board900_arrival_wait"]},
        "dimensions": size, "frames": ledger, "actual_span_seconds": str(span),
        "cycle_capped": capture.get("cycle_capped"), "max_animation_cycle": capture.get("max_animation_cycle"),
        "sample_fps_metadata_only": capture.get("sample_fps"),
        "timing_source": "Consecutive actual capture clocks; no constant-rate interpretation", "originals_modified": False}


def config(args):
    if (not all(path.is_absolute() for path in (args.workspace, args.qa_root, args.capture_dir, args.gif_output)) or
            args.qa_root.drive.casefold() != "e:"):
        raise ValueError("Explicit absolute E: root/workspace/capture/output paths are required")
    workspace, artifact = plain_path(args.workspace), plain_path(args.gif_output)
    if (not artifact.is_absolute() or artifact.suffix.lower() != ".gif" or
            not artifact.is_relative_to(workspace) or artifact.parent == workspace):
        raise ValueError("Explicit new GIF must be in a strict workspace artifact subdirectory")
    capture = source_capture(args.capture_dir, args.qa_root)
    if artifact.is_relative_to(Path(capture["directory"])):
        raise ValueError("Preview output cannot modify the original capture directory")
    ffmpeg = args.ffmpeg.resolve(strict=True)  # The explicitly selected executable is read-only.
    suggested_probe = args.ffprobe or args.ffmpeg.with_name("ffprobe.exe")
    if args.ffprobe is not None or suggested_probe.is_file():
        ffprobe = suggested_probe.resolve(strict=True)
    else:
        ffprobe = None
    return {"schema": "bth.bar_preview_inputs/v1", "workspace": str(workspace), "qa_root": str(args.qa_root.absolute()),
        "run_prefix": args.run_prefix, "gif_output": str(artifact), "ffmpeg": str(ffmpeg), "ffmpeg_sha256": sha(ffmpeg),
        "ffprobe": None if ffprobe is None else str(ffprobe), "ffprobe_sha256": None if ffprobe is None else sha(ffprobe),
        "adapter_sha256": sha(__file__), "capture": capture, "filter_complex": FILTER,
        "artifacts": {"gif": str(artifact), "concat": str(artifact.with_suffix(".ffconcat")),
            "frames": str(artifact.with_suffix(".frames.json")), "capture": str(artifact.with_suffix(".capture.json"))}}


def config_sha(cfg):
    return hashlib.sha256(json.dumps(cfg, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def verify_source(cfg):
    capture = cfg["capture"]
    if sha(capture["capture_json"]) != capture["capture_sha256"]:
        raise ValueError("Original capture JSON changed")
    for row in capture["frames"]:
        if sha(row["path"]) != row["sha256"]:
            raise ValueError("Original frame changed: " + row["path"])
    for name in ("ffmpeg", "ffprobe"):
        if cfg[name] and sha(cfg[name]) != cfg[name + "_sha256"]:
            raise ValueError("Read-only executable changed: " + name)


def prior(cfg, phase):
    evidence = Path(cfg["qa_root"]) / "runs" / (cfg["run_prefix"] + "-" + phase) / "evidence"
    result, job = read_json(evidence / "phase-result.json"), read_json(evidence / "job.json")
    if (result.get("phase") != phase or result.get("status") != "PASS" or
            result.get("config_sha256") != config_sha(cfg) or not qualified_job(job)):
        raise ValueError("Prior exact guarded phase is not qualified: " + phase)
    return result


def load_worker_layout(cfg):
    evidence = Path(os.environ["BTH_QA_EVIDENCE_DIR"])
    manifest = read_json(evidence / "storage-manifest.json")
    layout = Layout(**{key: Path(value) for key, value in manifest["paths"].items()},
        **{key: manifest[key] for key in ("run_id", "token", "expected_write_bytes", "reserve_bytes", "prepared")})
    if layout.workspace != Path(cfg["workspace"]):
        raise ValueError("Worker workspace differs from the admitted source")
    validate_layout(layout, extra_write_paths=(Path(cfg["gif_output"]).parent,))
    return layout


def prepare_worker(cfg, layout):
    verify_source(cfg)
    paths = {name: Path(path) for name, path in cfg["artifacts"].items()}
    if any(path.exists() for path in paths.values()):
        raise ValueError("Preview artifact identity already exists; retain it and choose a new output")
    paths["gif"].parent.mkdir(parents=True, exist_ok=True)
    lines = ["ffconcat version 1.0"]
    for row in cfg["capture"]["frames"]:
        # No shell is involved. Reject concat metacharacters even in approved roots.
        name = Path(row["path"]).as_posix()
        if any(character in name for character in ("'", "\n", "\r", "\0")):
            raise ValueError("Input frame path cannot be represented safely in ffconcat")
        lines += ["file '" + name + "'", "option framerate 100"]
        if row["duration_until_next_seconds"] is not None:
            lines.append("duration " + row["duration_until_next_seconds"])
    with paths["concat"].open("x", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")
    write_json_new(paths["frames"], cfg["capture"])
    with paths["capture"].open("xb") as handle:
        handle.write(Path(cfg["capture"]["capture_json"]).read_bytes())
    verify_source(cfg)
    return {name: {"path": str(path), "sha256": sha(path), "bytes": path.stat().st_size}
            for name, path in paths.items() if name != "gif"}


def gif_timing(path):
    """Parse raw GCE delays, avoiding viewers' minimum-delay substitutions."""
    data = Path(path).read_bytes()
    if len(data) >= PAGE_BYTES or len(data) < 13 or data[:6] not in (b"GIF87a", b"GIF89a"):
        raise ValueError("GIF is invalid or exceeds the strict10MB Page artifact limit")
    width, height = struct.unpack_from("<HH", data, 6)
    packed = data[10]
    cursor = 13 + (3 * (1 << ((packed & 7) + 1)) if packed & 0x80 else 0)
    frames, delay, terminated = [], None, False

    def need(length):
        if cursor + length > len(data):
            raise ValueError("Truncated GIF structure")

    def subblocks():
        nonlocal cursor
        while True:
            need(1)
            length = data[cursor]
            cursor += 1
            need(length)
            cursor += length
            if length == 0:
                break

    while cursor < len(data):
        tag = data[cursor]
        cursor += 1
        if tag == 0x3B:
            terminated = cursor == len(data)
            break
        if tag == 0x21:
            need(1)
            label = data[cursor]
            cursor += 1
            if label == 0xF9:
                need(6)
                if data[cursor] != 4 or data[cursor + 5] != 0:
                    raise ValueError("Invalid GIF graphic-control extension")
                delay = struct.unpack_from("<H", data, cursor + 2)[0]
                cursor += 6
            else:
                subblocks()
        elif tag == 0x2C:
            need(9)
            left, top, frame_width, frame_height = struct.unpack_from("<HHHH", data, cursor)
            local = data[cursor + 8]
            cursor += 9
            if not frame_width or not frame_height or left + frame_width > width or top + frame_height > height:
                raise ValueError("GIF frame rectangle escapes the unchanged full-app canvas")
            if local & 0x80:
                table_bytes = 3 * (1 << ((local & 7) + 1))
                need(table_bytes)
                cursor += table_bytes
            need(1)
            cursor += 1  # LZW minimum code size; ffprobe performs actual decoding.
            subblocks()
            frames.append({"delay_centiseconds": 0 if delay is None else delay,
                           "rect": [left, top, frame_width, frame_height]})
            delay = None
        else:
            raise ValueError("Unexpected GIF block tag: " + str(tag))
    if not terminated or not frames:
        raise ValueError("GIF trailer/frame sequence is invalid")
    elapsed = 0
    for frame in frames:
        frame["pts_centiseconds"] = elapsed
        elapsed += frame["delay_centiseconds"]
    return {"dimensions": [width, height], "frames": frames,
            "duration_seconds": str(Decimal(elapsed) / 100), "bytes": len(data), "sha256": sha(path)}


def reconcile_frames(raw_frames, source_frames):
    """Allow coalescing only when original PNG identity proves unchanged pixels."""
    matched, omitted, previous = [], [], -1
    for frame in raw_frames:
        when = Decimal(frame["pts_centiseconds"]) / 100
        choices = [index for index in range(previous + 1, len(source_frames))
                   if abs(Decimal(source_frames[index]["normalized_seconds"]) - when) <= TOLERANCE]
        if not choices:
            raise ValueError("Encoded frame PTS cannot be matched to an original capture clock")
        chosen = min(choices, key=lambda index: (abs(Decimal(source_frames[index]["normalized_seconds"]) - when), index))
        skipped = range(previous + 1, chosen)
        if any(previous < 0 or source_frames[index]["sha256"] != source_frames[previous]["sha256"] for index in skipped):
            raise ValueError("Encoder omitted a source frame without identical original PNG/pixel proof")
        omitted.extend(skipped)
        matched.append(chosen)
        previous = chosen
    skipped = range(previous + 1, len(source_frames))
    if any(source_frames[index]["sha256"] != source_frames[previous]["sha256"] for index in skipped):
        raise ValueError("Encoder omitted a distinct terminal source frame")
    omitted.extend(skipped)
    return matched, omitted


def verify_gif(cfg, probe=None):
    verify_source(cfg)
    raw = gif_timing(cfg["gif_output"])
    source = cfg["capture"]
    frames = raw["frames"]
    if raw["dimensions"] != source["dimensions"] or len(frames) > len(source["frames"]):
        raise ValueError("GIF changed canvas dimensions or invented additional frames")
    matched, omitted = reconcile_frames(frames, source["frames"])
    terminal_delay = source["frames"][-1]["expected_pts_centiseconds"] - frames[-1]["pts_centiseconds"] + FINAL_TICK_CS
    if abs(frames[-1]["delay_centiseconds"] - terminal_delay) > 1:
        raise ValueError("GIF terminal delay differs from the source tail plus its single20ms display tick")
    errors = [abs(Decimal(frame["pts_centiseconds"]) / 100 - Decimal(original["normalized_seconds"]))
              for frame, original in zip(frames, (source["frames"][index] for index in matched))]
    duration_error = abs(Decimal(raw["duration_seconds"]) - Decimal(source["actual_span_seconds"]))
    if max(errors) > TOLERANCE or duration_error > TOLERANCE:
        raise ValueError("GIF raw PTS/duration differs from actual capture by more than0.05seconds")
    probe_summary = {"available": probe is not None, "scope": "Raw GCE timing verified independently"}
    if probe is not None:
        decoded = probe.get("frames", [])
        stream = probe.get("streams", [])
        if len(decoded) != len(frames) or len(stream) != 1 or stream[0].get("codec_name") != "gif":
            raise ValueError("ffprobe did not decode exactly the originalGIF frame sequence")
        probe_errors = []
        for frame, original in zip(decoded, (source["frames"][index] for index in matched)):
            pts = frame.get("best_effort_timestamp_time", frame.get("pts_time"))
            if pts is None or [frame.get("width"), frame.get("height")] != source["dimensions"]:
                raise ValueError("ffprobe frame PTS/full-app dimensions missing or changed")
            probe_errors.append(abs(finite_decimal(pts, "ffprobe PTS") - Decimal(original["normalized_seconds"])))
        durations = []
        for value in (probe.get("format", {}).get("duration"), stream[0].get("duration")):
            if value is not None and value != "N/A":
                durations.append(finite_decimal(value, "ffprobe duration"))
        if max(probe_errors) > TOLERANCE or any(abs(value - Decimal(source["actual_span_seconds"])) > TOLERANCE for value in durations):
            raise ValueError("ffprobe PTS/duration differs from actual capture by more than0.05seconds")
        probe_summary = {"available": True, "decoded_frames": len(decoded),
            "maximum_pts_error_seconds": str(max(probe_errors)), "reported_durations_seconds": [str(value) for value in durations],
            "terminal_display_tick_centiseconds": FINAL_TICK_CS,
            "last_encoded_frame_delay_centiseconds": frames[-1]["delay_centiseconds"],
            "demux_options": {"min_delay": 0, "default_delay": 0, "ignore_loop": 1}}
    return {"schema": "bth.bar_preview_verification/v1", "status": "PASS", "gif": cfg["gif_output"],
        "sha256": raw["sha256"], "bytes": raw["bytes"], "page_upload_limit_bytes": PAGE_BYTES,
        "dimensions": raw["dimensions"], "source_frames": len(source["frames"]), "encoded_frames": len(frames),
        "source_first_to_last_clock_span_seconds": source["actual_span_seconds"],
        "encoded_presentation_duration_seconds": raw["duration_seconds"], "duration_error_seconds": str(duration_error),
        "maximum_pts_error_seconds": str(max(errors)), "quantization_tolerance_seconds": str(TOLERANCE),
        "terminal_display_tick_centiseconds": FINAL_TICK_CS, "last_encoded_frame_delay_centiseconds": frames[-1]["delay_centiseconds"],
        "coalesced_source_frame_indices": omitted, "coalescing_proof": "Only byte-identical original PNGs may share an encoded frame; distinct source pictures are never dropped",
        "matched_source_frame_indices": matched, "ffprobe": probe_summary, "raw_gif_timing": frames,
        "original_frames_and_capture_unchanged": True, "picture_transform": "GIF256-color palette only; no crop/scale/interpolation/dither/boost",
        "art_approval": False, "test_updated": False}


def command_for(cfg, phase, worker_arguments):
    if phase == "prepare" or (phase == "verify" and not cfg["ffprobe"]):
        return [sys.executable, "-B", str(Path(__file__).resolve()), phase, *worker_arguments, "--worker"]
    if phase == "encode":
        return [cfg["ffmpeg"], "-hide_banner", "-v", "warning", "-nostdin", "-n",
            "-threads", "1", "-filter_threads", "1", "-filter_complex_threads", "1",
            "-f", "concat", "-safe", "0", "-i", cfg["artifacts"]["concat"],
            "-filter_complex", FILTER, "-map", "[out]", "-an", "-sn", "-dn",
            "-threads", "1", "-fps_mode", "vfr", "-enc_time_base", "1:100",
            "-loop", "0", "-final_delay", str(FINAL_TICK_CS), cfg["gif_output"]]
    return [cfg["ffprobe"], "-hide_banner", "-v", "error", "-threads", "1",
        "-min_delay", "0", "-default_delay", "0", "-ignore_loop", "1", "-f", "gif", "-i", cfg["gif_output"],
        "-select_streams", "v:0", "-show_frames", "-show_streams", "-show_format",
        "-show_entries", "frame=best_effort_timestamp_time,pts_time,pkt_duration_time,duration_time,width,height:stream=codec_name,width,height,time_base,nb_frames,duration:format=duration,size",
        "-of", "json"]


def run_phase(args, cfg, arguments):
    phase = args.phase
    layout = plan_layout(root=args.qa_root, workspace=args.workspace, run_id=args.run_prefix + "-" + phase)
    output_parent = Path(cfg["gif_output"]).parent
    validate_layout(layout, extra_write_paths=(output_parent,))
    if phase != "prepare":
        preparation = prior(cfg, "prepare")
        for details in preparation["artifacts"].values():
            if sha(details["path"]) != details["sha256"]:
                raise ValueError("Prepared source/concat artifact changed")
        if phase == "encode" and Path(cfg["gif_output"]).exists():
            raise ValueError("GIF already exists; inspect the previous outcome, never overwrite")
        if phase == "verify":
            encoded = prior(cfg, "encode")
            if sha(cfg["gif_output"]) != encoded["artifacts"]["sha256"]:
                raise ValueError("Encoded GIF identity changed")
    verify_source(cfg)
    layout = prepare_layout(layout)
    command = command_for(cfg, phase, arguments)
    write_json_new(layout.evidence / "preview-inputs.json", {"config": cfg, "config_sha256": config_sha(cfg), "command": command})
    job = execute(layout, command, timeout=args.timeout, cpu_rate=1200, extra_write_paths=(output_parent,))
    log = (layout.evidence / "worker.log").read_text(encoding="utf-8", errors="replace")
    if not qualified_job(job) or ERROR_LINE.search(log):
        raise ValueError("Preview phase failed; exact Job/log evidence retained: " + str(layout.evidence))
    verify_source(cfg)
    if phase == "prepare":
        artifacts = read_json(layout.evidence / "worker-result.json")
    elif phase == "encode":
        path = Path(cfg["gif_output"])
        if not path.is_file() or path.stat().st_size >= PAGE_BYTES:
            raise ValueError("Preview GIF missing or exceeds10MB; no crop, scale or cadence fallback attempted")
        artifacts = {"path": str(path), "sha256": sha(path), "bytes": path.stat().st_size}
    else:
        if cfg["ffprobe"]:
            probe = json.loads(log)
            write_json_new(layout.evidence / "ffprobe.json", probe)
            artifacts = verify_gif(cfg, probe)
            write_json_new(layout.evidence / "preview-verification.json", artifacts)
        else:
            artifacts = read_json(layout.evidence / "worker-result.json")
    validate_layout(layout, extra_write_paths=(output_parent,))
    result = {"schema": "bth.bar_preview_phase/v1", "phase": phase, "status": "PASS",
        "observed_at": datetime.now(timezone.utc).isoformat(), "config_sha256": config_sha(cfg),
        "job_receipt": str(layout.evidence / "job.json"), "artifacts": artifacts, "art_approval": False, "test_updated": False}
    write_json_new(layout.evidence / "phase-result.json", result)
    print(json.dumps(result, indent=2))


def main(argv=None):
    tokens = list(sys.argv[1:] if argv is None else argv)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("plan", *PHASES))
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--qa-root", type=Path, default=Path("E:/CodexQA/BTH"))
    parser.add_argument("--run-prefix", required=True)
    parser.add_argument("--capture-dir", type=Path, required=True)
    parser.add_argument("--gif-output", type=Path, required=True)
    parser.add_argument("--ffmpeg", type=Path, default=Path(FFMPEG_DEFAULT))
    parser.add_argument("--ffprobe", type=Path)
    parser.add_argument("--timeout", type=int, default=300)
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args(tokens)
    try:
        if not 1 <= args.timeout <= 1200:
            raise ValueError("Bounded phase timeout must be1..1200seconds")
        # Admission precedes every first QA write/subprocess, including workers.
        if args.worker:
            cfg = config(args)
            layout = load_worker_layout(cfg)
            if args.phase == "prepare":
                artifacts = prepare_worker(cfg, layout)
            elif args.phase == "verify" and not cfg["ffprobe"]:
                artifacts = verify_gif(cfg)
            else:
                raise ValueError("Unsupported internal worker phase")
            write_json_new(layout.evidence / "worker-result.json", artifacts)
        elif args.phase == "plan":
            layouts = {phase: plan_layout(root=args.qa_root, workspace=args.workspace,
                       run_id=args.run_prefix + "-" + phase) for phase in PHASES}
            cfg = config(args)
            if any(Path(path).exists() for path in cfg["artifacts"].values()):
                raise ValueError("Plan requires fresh artifact paths; do not retry an uncertain existing result")
            for layout in layouts.values():
                validate_layout(layout, extra_write_paths=(Path(cfg["gif_output"]).parent,))
            print(json.dumps({"status": "READ_ONLY_PREVIEW_PLAN", "config_sha256": config_sha(cfg),
                "capture": {key: value for key, value in cfg["capture"].items() if key != "frames"},
                "frame_count": len(cfg["capture"]["frames"]), "output": cfg["artifacts"],
                "phases": [{"phase": phase, "run_id": layout.run_id,
                    "command": command_for(cfg, phase, tokens[1:])} for phase, layout in layouts.items()],
                "resource_caps": {"cpu_rate": 1200, "memory_bytes": 2 * 1024 ** 3},
                "timing_docs": "https://ffmpeg.org/ffmpeg-formats.html", "executed": False}, indent=2))
        else:
            # Read-only config may inspect inputs; plan_layout/run_phase admits
            # all new output directories before any write or child constructor.
            cfg = config(args)
            run_phase(args, cfg, tokens[1:])
        return 0
    except (OSError, ValueError, KeyError, RuntimeError, TypeError, ArithmeticError) as error:
        print(json.dumps({"status": "PREVIEW_PHASE_STOPPED", "phase": args.phase, "error": str(error),
            "fallback_attempted": False, "original_frames_modified": False, "test_updated": False}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
