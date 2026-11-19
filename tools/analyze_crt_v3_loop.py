"""Verify an actual CRT v3 output capture against its trusted looping master.

Run only inside the maintained QA guard. Uses NumPy and the standard library;
does not play audio, launch children, install packages, or repair a capture.
"""
from __future__ import annotations

import sys
sys.dont_write_bytecode = True

import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import struct
import wave

import numpy as np

MASTER_SHA256 = "2412bb82073f500b68cd9a1f95988da970af141282f1dbe15cb077c67ff30028"
MASTER_RATE = 44100
MASTER_FRAMES = 1512000
PERIOD = MASTER_FRAMES / MASTER_RATE
ANALYSIS_RATE = 6000
MAX_CAPTURE_SECONDS = 90
SCHEMA = "bth.crt_v3_actual_loop_analysis/v1"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def normalized(path: Path) -> str:
    return str(path).replace("\\", "/").casefold()


def guarded_paths(args):
    admitted = os.environ.get("BTH_QA_EVIDENCE_DIR", "")
    if not admitted:
        raise ValueError("BTH_QA_EVIDENCE_DIR must be supplied by the existing QA guard")
    output = args.output_dir.resolve(strict=True)
    expected = Path(admitted).resolve(strict=True)
    if not output.is_dir() or output != expected:
        raise ValueError("--output-dir must exactly match the existing admitted QA evidence directory")
    if not normalized(output).startswith("e:/codexqa/bth/runs/"):
        raise ValueError("Output must remain in the approved E: QA runs root")
    for name in ("capture_wav", "master", "metadata"):
        value = getattr(args, name)
        if value is None:
            continue
        resolved = value.resolve(strict=True)
        if not resolved.is_file() or not normalized(resolved).startswith("e:/codexqa/bth/"):
            raise ValueError(f"{name} must be an explicit existing file under the approved E: QA root")
        setattr(args, name, resolved)
    for filename in ("crt_v3_loop_analysis.json", "crt_v3_boundary_capture.wav"):
        target = output / filename
        if target.exists() or target.is_symlink():
            raise ValueError(f"Refusing to replace prior evidence: {target}")
    return output


def read_wav(path: Path):
    """Read RIFF PCM16 or IEEE float32, including their extensible subtypes."""
    size = path.stat().st_size
    if size > 160 * 1024 * 1024:
        raise ValueError("Capture/master exceeds the bounded 160 MiB WAV input limit")
    fmt = None
    data_location = None
    with path.open("rb") as stream:
        header = stream.read(12)
        if len(header) != 12 or header[:4] != b"RIFF" or header[8:] != b"WAVE":
            raise ValueError("Expected a little-endian RIFF WAVE file")
        declared_end = struct.unpack_from("<I", header, 4)[0] + 8
        if declared_end > size:
            raise ValueError("WAV RIFF length exceeds the actual file")
        while stream.tell() + 8 <= min(size, declared_end):
            chunk_id, chunk_size = struct.unpack("<4sI", stream.read(8))
            start = stream.tell()
            if start + chunk_size > min(size, declared_end):
                raise ValueError("WAV contains a truncated chunk")
            if chunk_id == b"fmt ":
                if chunk_size < 16 or chunk_size > 65536:
                    raise ValueError("Unsupported WAV format chunk size")
                fmt = stream.read(chunk_size)
            elif chunk_id == b"data":
                if data_location is not None:
                    raise ValueError("Multiple WAV data chunks have ambiguous timing")
                data_location = (start, chunk_size)
            stream.seek(start + chunk_size + (chunk_size & 1))
        if fmt is None or data_location is None:
            raise ValueError("WAV requires fmt and data chunks")
        tag, channels, rate, byte_rate, block_align, bits = struct.unpack_from("<HHIIHH", fmt)
        original_tag = tag
        if tag == 0xFFFE:
            if len(fmt) < 40 or struct.unpack_from("<H", fmt, 16)[0] < 22:
                raise ValueError("Truncated WAVE_FORMAT_EXTENSIBLE format")
            subtype = fmt[24:40]
            if subtype[4:] != bytes.fromhex("00001000800000aa00389b71"):
                raise ValueError("Unsupported extensible WAV subtype GUID")
            tag = struct.unpack_from("<I", subtype)[0]
            if struct.unpack_from("<H", fmt, 18)[0] not in (0, bits):
                raise ValueError("Packed/extensible valid-bit conversion is unsupported")
        if channels != 2:
            raise ValueError("The actual capture and master must retain two channels")
        if not 8000 <= rate <= 192000:
            raise ValueError("Unsupported WAV sample rate")
        if (tag, bits) not in ((1, 16), (3, 32)):
            raise ValueError("Only PCM16 and IEEE float32 capture formats are admitted")
        if block_align != channels * (bits // 8) or byte_rate != rate * block_align:
            raise ValueError("WAV block alignment/byte rate is inconsistent")
        offset, byte_count = data_location
        if not byte_count or byte_count % block_align:
            raise ValueError("WAV data is empty or ends in a partial audio frame")
        frames = byte_count // block_align
        if frames / rate > MAX_CAPTURE_SECONDS:
            raise ValueError("Audio duration exceeds the bounded 90-second analysis limit")
        stream.seek(offset)
        raw = stream.read(byte_count)
    dtype = "<i2" if tag == 1 else "<f4"
    samples = np.frombuffer(raw, dtype=dtype).reshape(frames, channels).astype(np.float64)
    if tag == 1:
        samples /= 32768.0
    if not np.isfinite(samples).all():
        raise ValueError("Audio contains NaN or infinite samples")
    return samples, {
        "path": str(path), "sha256": sha256(path), "format_tag": tag,
        "original_format_tag": original_tag, "bits": bits, "channels": channels,
        "sample_rate": rate, "frames": frames, "seconds": frames / rate,
        "peak": np.max(np.abs(samples), axis=0).tolist(),
        "rms": np.sqrt(np.mean(samples * samples, axis=0)).tolist(),
        "clipped_sample_fraction": float(np.mean(np.abs(samples) >= 0.9999)),
    }


def linear(samples, times, rate, periodic=False):
    locations = np.asarray(times, dtype=np.float64) * rate
    if periodic:
        locations %= len(samples)
    elif len(locations) and (float(np.min(locations)) < -1e-6 or float(np.max(locations)) > len(samples) - 1 + 1e-6):
        raise ValueError("Requested waveform comparison exceeds actual capture samples")
    locations = np.clip(locations, 0, len(samples) - 1) if not periodic else locations
    left = np.floor(locations).astype(np.int64)
    weight = (locations - left)[:, None]
    right = (left + 1) % len(samples) if periodic else np.minimum(left + 1, len(samples) - 1)
    return samples[left] * (1.0 - weight) + samples[right] * weight


def lowpass(samples, rate, cutoff):
    # Symmetric, odd-length FIR has no group-delay shift. Convolution is bounded
    # time-domain work; the only alignment FFT runs at about 6 kHz, never 48 kHz.
    taps = 161
    index = np.arange(taps) - (taps - 1) / 2
    kernel = 2.0 * cutoff / rate * np.sinc(2.0 * cutoff / rate * index) * np.hamming(taps)
    kernel /= np.sum(kernel)
    return np.column_stack([np.convolve(samples[:, channel], kernel, mode="same") for channel in range(2)])


def correlation(a, b):
    ac = a - np.mean(a, axis=0)
    bc = b - np.mean(b, axis=0)
    denominator = np.sqrt(np.sum(ac * ac, axis=0) * np.sum(bc * bc, axis=0))
    return np.divide(np.sum(ac * bc, axis=0), denominator, out=np.zeros_like(denominator), where=denominator > 1e-20)


def fit(reference, observed):
    xm = np.mean(reference, axis=0)
    ym = np.mean(observed, axis=0)
    x = reference - xm
    y = observed - ym
    denominator = np.sum(x * x, axis=0)
    gain = np.divide(np.sum(x * y, axis=0), denominator, out=np.zeros(2), where=denominator > 1e-20)
    offset = ym - gain * xm
    residual = observed - (reference * gain + offset)
    rms = np.sqrt(np.mean(y * y, axis=0))
    nrmse = np.sqrt(np.mean(residual * residual, axis=0)) / np.maximum(rms, 1e-12)
    return {"gain": gain.tolist(), "dc_offset": offset.tolist(), "correlation": correlation(reference, observed).tolist(), "normalized_rmse": nrmse.tolist()}


def best_offset(reference_at, times, observed, center=0.0, radius=0.006, step=1 / 6000):
    offsets = center + np.arange(-math.ceil(radius / step), math.ceil(radius / step) + 1) * step
    scores = np.array([float(np.mean(correlation(reference_at(times + offset), observed))) for offset in offsets])
    best = int(np.argmax(scores))
    coarse = float(offsets[best])
    fine = coarse + np.linspace(-step, step, 17)
    fine_scores = np.array([float(np.mean(correlation(reference_at(times + offset), observed))) for offset in fine])
    chosen = int(np.argmax(fine_scores))
    offset = float(fine[chosen])
    return {
        "offset_sec": offset, "correlation_mean": float(fine_scores[chosen]),
        "search_center_sec": center, "search_radius_sec": radius,
        "at_search_edge": best in (0, len(offsets) - 1), "samples": len(times),
        "fit": fit(reference_at(times + offset), observed),
    }


def first_signal(samples, rate):
    block = max(1, round(rate * 0.02))
    usable = samples[:len(samples) // block * block]
    levels = np.sqrt(np.mean(usable.reshape(-1, block, 2) ** 2, axis=(1, 2)))
    threshold = max(float(np.max(levels)) * 0.015, 1e-6)
    active = levels >= threshold
    for index in range(max(0, len(active) - 2)):
        if np.all(active[index:index + 3]):
            return index * block / rate
    raise ValueError("Capture has no sustained nonzero stereo signal")


def write_actual_clip(path, samples, rate, start, end):
    first = max(0, round(start * rate))
    last = min(len(samples), round(end * rate))
    actual = samples[first:last]
    pcm = np.round(np.clip(actual, -1.0, 32767 / 32768) * 32768).astype("<i2")
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(2)
        stream.setsampwidth(2)
        stream.setframerate(rate)
        stream.writeframes(pcm.tobytes())
    return {"path": str(path), "sha256": sha256(path), "start_sec": first / rate, "end_sec": last / rate,
            "frames": len(actual), "sample_rate": rate, "origin": "actual capture samples, float32 converted only for playable PCM16 clip"}


def residual_metrics(capture, capture_rate, master, gain, offset, phase_origin, wrap):
    def window(center, seconds=0.02):
        lo = round((center - seconds / 2) * capture_rate)
        count = round(seconds * capture_rate)
        if lo < 0 or lo + count >= len(capture):
            return None
        times = (lo + np.arange(count)) / capture_rate
        expected = linear(master, times + phase_origin, MASTER_RATE, True) * gain + offset
        residual = capture[lo:lo + count] - expected
        derivative = np.diff(residual, axis=0)
        return np.array([np.sqrt(np.mean(residual ** 2)), np.sqrt(np.mean(derivative ** 2)), np.max(np.abs(derivative))])

    ordinary = []
    # Evaluate actual raw-rate residuals too, so a short click cannot disappear
    # into the low-pass/downsampled alignment signal.
    for center in np.arange(0.6, len(capture) / capture_rate - 0.05, 0.04):
        if abs(center - wrap) > 0.12:
            metrics = window(float(center))
            if metrics is not None:
                ordinary.append(metrics)
    if not ordinary:
        raise ValueError("Insufficient ordinary waveform windows for click comparison")
    baseline = np.asarray(ordinary)
    ordinary_q99 = np.quantile(baseline, 0.99, axis=0)
    # Slightly overlapping windows cover the inferred seam even when its phase
    # estimate is between capture samples.
    seam = np.asarray([window(wrap + delta) for delta in (-0.01, 0.0, 0.01)])
    seam_worst = np.max(seam, axis=0)
    signal_rms = float(np.sqrt(np.mean(capture ** 2)))
    floors = signal_rms * np.array([0.12, 0.08, 0.50])
    limits = np.maximum(ordinary_q99 * 4.0, floors)
    return {
        "metric_order": ["residual_rms", "residual_derivative_rms", "residual_derivative_peak"],
        "window_sec": 0.02, "ordinary_window_count": len(ordinary),
        "ordinary_q99": ordinary_q99.tolist(), "seam_worst": seam_worst.tolist(),
        "seam_to_ordinary_q99": (seam_worst / np.maximum(ordinary_q99, 1e-12)).tolist(),
        "limits": limits.tolist(), "unexpected_residual_or_click_energy": bool(np.any(seam_worst > limits)),
    }


def analyze(args, output):
    report = {"schema": SCHEMA, "checked_at": datetime.now(timezone.utc).isoformat(),
              "passed": False, "status": "unverified", "facts": [], "errors": [],
              "evidence_class": "actual captured waveform versus exact trusted source; not a seam-metadata test"}
    errors = report["errors"]

    def require(condition, message):
        if condition:
            report["facts"].append(message)
        else:
            errors.append(message)

    try:
        master, master_info = read_wav(args.master)
        capture, capture_info = read_wav(args.capture_wav)
        report.update(master=master_info, capture=capture_info)
        require(master_info["sha256"] == MASTER_SHA256, "Master WAV has the exact reviewed v3 SHA-256.")
        require(master_info["sample_rate"] == MASTER_RATE and master_info["frames"] == MASTER_FRAMES and master_info["format_tag"] == 1,
                "Master is the exact 44.1 kHz stereo PCM16, 1,512,000-frame loop.")
        if errors:
            raise ValueError("Trusted-master identity/dimensions failed; alignment was not attempted")
        require(capture_info["seconds"] >= PERIOD + 2, "Actual capture duration is at least one full source period plus two seconds.")
        require(min(capture_info["rms"]) > 1e-6, "Both recorded channels contain finite nonzero audio.")
        require(capture_info["clipped_sample_fraction"] < 0.001, "Actual capture has no material sample clipping.")
        if args.metadata is not None:
            metadata = json.loads(args.metadata.read_text(encoding="utf-8-sig"))
            report["metadata"] = {"path": str(args.metadata), "sha256": sha256(args.metadata), "content": metadata,
                                  "scope": "context only; does not establish waveform pass"}
        else:
            metadata = {}
        platform_text = str(metadata.get("platform", metadata.get("capture_kind", ""))).lower() if isinstance(metadata, dict) else ""
        web = capture_info["format_tag"] == 3 or "web" in platform_text or "browser" in platform_text
        limits = {"master_correlation": 0.90 if web else 0.97, "self_correlation": 0.97 if web else 0.985,
                  "timing_sec": 0.001 if web else 0.0005, "stereo_side_correlation": 0.65}
        report["thresholds"] = limits
        report["dsp_classification"] = "web/static output DSP allowed" if web else "native/near-linear output expected"
        onset = first_signal(capture, capture_info["sample_rate"])
        require(capture_info["seconds"] - onset > PERIOD, "A complete source period exists after the actual first signal.")
        if errors:
            raise ValueError("Capture validation failed; no loop proof was attempted")
        grid_frames = round(PERIOD * ANALYSIS_RATE)
        grid_rate = grid_frames / PERIOD
        cutoff = grid_rate * 0.40
        filtered_master = lowpass(master, MASTER_RATE, cutoff)
        reference = linear(filtered_master, np.arange(grid_frames) / grid_rate, MASTER_RATE, True)
        del filtered_master
        filtered_capture = lowpass(capture, capture_info["sample_rate"], cutoff)
        capture_grid = linear(filtered_capture, np.arange(math.floor((len(capture) - 1) / capture_info["sample_rate"] * grid_rate)) / grid_rate,
                              capture_info["sample_rate"])
        del filtered_capture
        times = onset + np.arange(grid_frames) / grid_rate
        observed = linear(capture_grid, times, grid_rate)
        ref_centered = reference - np.mean(reference, axis=0)
        obs_centered = observed - np.mean(observed, axis=0)
        cross = np.fft.irfft(np.sum(np.fft.rfft(ref_centered, axis=0) * np.conj(np.fft.rfft(obs_centered, axis=0)), axis=1), n=grid_frames)
        peak = int(np.argmax(cross))
        competitor = cross.copy()
        distance = np.minimum((np.arange(grid_frames) - peak) % grid_frames, (peak - np.arange(grid_frames)) % grid_frames)
        competitor[distance < round(0.25 * grid_rate)] = -np.inf
        next_peak = float(np.max(competitor))
        ambiguity_ratio = next_peak / max(float(cross[peak]), 1e-20)
        coarse_phase = peak / grid_rate
        reference_at = lambda absolute: linear(reference, absolute - onset + coarse_phase, grid_rate, True)
        phase_refinement = best_offset(reference_at, times[::2], observed[::2], radius=1.5 / grid_rate, step=1 / grid_rate / 8)
        phase = (coarse_phase + phase_refinement["offset_sec"]) % PERIOD
        phase_origin = phase - onset
        reference_at = lambda absolute: linear(reference, absolute + phase_origin, grid_rate, True)
        aligned_reference = reference_at(times)
        alignment_fit = fit(aligned_reference, observed)
        report["alignment"] = {"method": "one complete period, summed stereo circular FFT; positive reference phase; fine fractional interpolation",
                               "antialias_fir_taps": 161, "antialias_cutoff_hz": cutoff,
                               "grid_frames": grid_frames, "grid_rate": grid_rate, "first_signal_sec": onset,
                               "phase_at_first_signal_sec": phase, "phase_origin_sec": phase_origin,
                               "next_separated_peak_ratio": ambiguity_ratio, "refinement": phase_refinement, "fit": alignment_fit}
        require(ambiguity_ratio < 0.997, "Whole-period alignment has a distinct peak rather than an ambiguous repeated hook.")
        require(min(alignment_fit["correlation"]) >= limits["master_correlation"], "Both recorded channels correlate with the exact resampled master above the declared threshold.")
        require(min(alignment_fit["gain"]) > 0, "Master-to-capture channel gains are positive.")
        gains = np.asarray(alignment_fit["gain"])
        calibrated = observed / np.maximum(gains, 1e-12)
        reference_side = (aligned_reference[:, 0] - aligned_reference[:, 1])[:, None]
        capture_side = (calibrated[:, 0] - calibrated[:, 1])[:, None]
        side_corr = float(correlation(reference_side, capture_side)[0])
        report["stereo"] = {"calibrated_side_correlation": side_corr,
                            "reference_side_rms": float(np.sqrt(np.mean(reference_side ** 2))),
                            "capture_side_rms": float(np.sqrt(np.mean(capture_side ** 2)))}
        require(side_corr >= limits["stereo_side_correlation"], "Actual stereo difference follows the master's stereo content; two channels alone are not treated as proof.")

        overlap_start = onset + 0.35  # excludes the initial output attack/fade
        overlap_end = (len(capture_grid) - 1) / grid_rate - PERIOD - 0.015
        overlap_seconds = overlap_end - overlap_start
        report["capture_overlap_seconds"] = overlap_seconds
        require(overlap_seconds >= 1.5, "At least 1.5 seconds of actual recorded material repeats after one fractional source period.")
        if overlap_seconds < 1.5:
            raise ValueError("Insufficient actual repeated overlap to prove the physical loop")
        overlap_times = np.arange(overlap_start, overlap_end, 1 / grid_rate)
        left = linear(capture_grid, overlap_times, grid_rate)
        capture_after_period = lambda absolute: linear(capture_grid, absolute + PERIOD, grid_rate)
        repetition = best_offset(capture_after_period, overlap_times, left, radius=0.006, step=1 / grid_rate)
        report["actual_period_repetition"] = repetition
        require(min(repetition["fit"]["correlation"]) >= limits["self_correlation"], "Actual captured waveform repeats across the fractional loop period above the declared correlation threshold.")
        require(not repetition["at_search_edge"] and abs(repetition["offset_sec"]) <= limits["timing_sec"], "The actual repeated waveform has no unexpected period gap, duplication, or restart offset.")
        local_periods = []
        width = min(0.75, overlap_seconds / 3)
        for center in np.linspace(overlap_start + width / 2, overlap_end - width / 2, 3):
            local_times = np.arange(center - width / 2, center + width / 2, 1 / grid_rate)
            local = best_offset(capture_after_period, local_times, linear(capture_grid, local_times, grid_rate), radius=0.006, step=1 / grid_rate)
            local["capture_center_sec"] = float(center)
            local_periods.append(local)
        report["local_period_checks"] = local_periods
        require(all(not item["at_search_edge"] and abs(item["offset_sec"]) <= limits["timing_sec"] and
                    min(item["fit"]["correlation"]) >= limits["self_correlation"] for item in local_periods),
                "Separate actual overlap windows agree on the physical source period.")

        first_wrap = (-phase_origin) % PERIOD
        all_wraps = list(np.arange(first_wrap, capture_info["seconds"], PERIOD))
        eligible = [float(value) for value in all_wraps if value >= max(2.0, onset + 0.35) and value + 2.0 <= capture_info["seconds"]]
        report["inferred_wrap_times_sec"] = [float(value) for value in all_wraps]
        require(bool(eligible), "A physical source wrap exists with two seconds of actual captured audio on each side.")
        if not eligible:
            raise ValueError("Cannot extract the required actual capture boundary clip")
        wrap = eligible[0]
        before_times = np.arange(wrap - 1.5, wrap - 0.25, 1 / grid_rate)
        after_times = np.arange(wrap + 0.25, wrap + 1.5, 1 / grid_rate)
        before = best_offset(reference_at, before_times, linear(capture_grid, before_times, grid_rate), radius=0.006, step=1 / grid_rate)
        after = best_offset(reference_at, after_times, linear(capture_grid, after_times, grid_rate), radius=0.006, step=1 / grid_rate)
        timing_step = after["offset_sec"] - before["offset_sec"]
        report["wrap_timing"] = {"wrap_sec": wrap, "before": before, "after": after,
                                 "alignment_step_sec": timing_step,
                                 "sign_convention": "positive offset advances the reference waveform relative to the capture"}
        require(not before["at_search_edge"] and not after["at_search_edge"] and abs(timing_step) <= limits["timing_sec"],
                "Master-aligned timing is continuous before and after the recorded wrap.")
        require(min(before["fit"]["correlation"] + after["fit"]["correlation"]) >= limits["master_correlation"],
                "Local waveform on each side of the physical wrap remains consistent with the master.")
        report["boundary_capture_clip"] = write_actual_clip(output / "crt_v3_boundary_capture.wav", capture, capture_info["sample_rate"], wrap - 2, wrap + 2)
        residual = residual_metrics(capture, capture_info["sample_rate"], master, gains,
                                    np.asarray(alignment_fit["dc_offset"]), phase_origin, wrap)
        report["wrap_residual_click_comparison"] = residual
        require(not residual["unexpected_residual_or_click_energy"], "Raw-rate residual/click energy across the recorded wrap is not an unexpected outlier against ordinary captured windows.")
        report["limitations"] = ["A waveform pass applies to this actual capture, output path, exact master and observed wrap only.",
                                 "Timing and click claims are bounded by the explicitly reported correlation, lag and residual thresholds; sub-threshold differences are not excluded.",
                                 "This does not prove subjective musical quality or every device/browser; insufficient DSP correlation remains unverified."]
        report["passed"] = not errors
        report["status"] = "verified_actual_waveform_loop" if not errors else "unverified_waveform_loop"
    except Exception as exc:
        errors.append(f"{type(exc).__name__}: {exc}")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture-wav", required=True, type=Path)
    parser.add_argument("--master", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--metadata", type=Path)
    args = parser.parse_args()
    try:
        output = guarded_paths(args)
    except Exception as exc:
        print(json.dumps({"schema": SCHEMA, "passed": False, "status": "guard_rejected", "errors": [str(exc)]}))
        return 2
    report = analyze(args, output)
    (output / "crt_v3_loop_analysis.json").write_text(json.dumps(report, indent=2, allow_nan=False), encoding="utf-8")
    print(json.dumps(report, allow_nan=False))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
