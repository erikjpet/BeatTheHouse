"""Build bounded 22.05 kHz / 16-bit Web copies of authored WAV masters."""

from __future__ import annotations

import argparse
import gzip
import json
import struct
import wave
from pathlib import Path

import numpy as np


SOURCE_RATE = 44_100
TARGET_RATE = 22_050
FIR_TAPS = 63
IMA_INDEX_TABLE = (-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8)
IMA_STEP_TABLE = (
    7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41,
    45, 50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190,
    209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724,
    796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272,
    2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132,
    7845, 8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350,
    22385, 24623, 27086, 29794, 32767,
)


def _decode_pcm(raw: bytes, sample_width: int, channels: int) -> np.ndarray:
    if sample_width == 2:
        values = np.frombuffer(raw, dtype="<i2").astype(np.float64)
        scale = 32768.0
    elif sample_width == 3:
        packed = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3)
        values = (
            packed[:, 0].astype(np.int32)
            | (packed[:, 1].astype(np.int32) << 8)
            | (packed[:, 2].astype(np.int32) << 16)
        )
        values = np.where(values & 0x800000, values - 0x1000000, values).astype(np.float64)
        scale = 8_388_608.0
    else:
        raise ValueError(f"unsupported PCM width: {sample_width * 8} bits")
    return (values / scale).reshape(-1, channels)


def _decimate_by_two(samples: np.ndarray) -> np.ndarray:
    center = (FIR_TAPS - 1) / 2.0
    indices = np.arange(FIR_TAPS, dtype=np.float64) - center
    cutoff_cycles_per_sample = 0.225
    kernel = 2.0 * cutoff_cycles_per_sample * np.sinc(2.0 * cutoff_cycles_per_sample * indices)
    kernel *= np.hamming(FIR_TAPS)
    kernel /= np.sum(kernel)
    filtered = np.empty_like(samples)
    for channel in range(samples.shape[1]):
        filtered[:, channel] = np.convolve(samples[:, channel], kernel, mode="same")
    return filtered[::2]


def _ima_code(sample: int, predictor: int, index: int) -> tuple[int, int, int]:
    step = IMA_STEP_TABLE[index]
    difference = sample - predictor
    code = 8 if difference < 0 else 0
    difference = abs(difference)
    delta = step >> 3
    if difference >= step:
        code |= 4
        difference -= step
        delta += step
    if difference >= step >> 1:
        code |= 2
        difference -= step >> 1
        delta += step >> 1
    if difference >= step >> 2:
        code |= 1
        delta += step >> 2
    predictor += -delta if code & 8 else delta
    predictor = max(-32768, min(32767, predictor))
    index = max(0, min(88, index + IMA_INDEX_TABLE[code]))
    return code, predictor, index


def _encode_ima(samples: np.ndarray, sample_rate: int = TARGET_RATE) -> tuple[bytes, float]:
    pcm = np.clip(np.rint(samples * 32767.0), -32768, 32767).astype(np.int16)
    frames, channels = pcm.shape
    predictors = [int(pcm[0, channel]) for channel in range(channels)]
    indices = [0] * channels
    header = bytearray(b"BTHA")
    header.extend(struct.pack("<BBHII", 1, channels, 0, sample_rate, frames))
    for channel in range(channels):
        header.extend(struct.pack("<hB", predictors[channel], indices[channel]))
    nibbles: list[int] = []
    decoded = np.empty_like(pcm)
    decoded[0] = pcm[0]
    for frame in range(1, frames):
        for channel in range(channels):
            code, predictors[channel], indices[channel] = _ima_code(
                int(pcm[frame, channel]), predictors[channel], indices[channel]
            )
            nibbles.append(code)
            decoded[frame, channel] = predictors[channel]
    encoded = bytearray((len(nibbles) + 1) // 2)
    for offset, code in enumerate(nibbles):
        encoded[offset // 2] |= code << (4 if offset & 1 else 0)
    error = pcm.astype(np.float64) - decoded.astype(np.float64)
    signal_power = float(np.mean(np.square(pcm.astype(np.float64))))
    noise_power = max(float(np.mean(np.square(error))), 1e-12)
    snr_db = 10.0 * float(np.log10(max(signal_power, 1e-12) / noise_power))
    return bytes(header + encoded), snr_db


def _convert(source: Path, destination: Path) -> dict[str, int | float | str]:
    with wave.open(str(source), "rb") as reader:
        channels = reader.getnchannels()
        sample_width = reader.getsampwidth()
        sample_rate = reader.getframerate()
        source_frames = reader.getnframes()
        if sample_rate != SOURCE_RATE:
            raise ValueError(f"{source}: expected {SOURCE_RATE} Hz, found {sample_rate} Hz")
        samples = _decode_pcm(reader.readframes(source_frames), sample_width, channels)
    converted = _decimate_by_two(samples)
    encoded, snr_db = _encode_ima(converted)
    compressed = gzip.compress(encoded, compresslevel=9, mtime=0)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(compressed)
    destination.with_suffix(destination.suffix + ".import").write_text(
        '[remap]\n\nimporter="keep"\n', encoding="utf-8", newline="\n"
    )
    return {
        "source": str(source),
        "destination": str(destination),
        "source_frames": source_frames,
        "destination_frames": int(converted.shape[0]),
        "channels": channels,
        "source_bits": sample_width * 8,
        "destination_codec": "bth_ima_adpcm4",
        "adpcm_bytes": len(encoded),
        "encoded_bytes": len(compressed),
        "snr_db": round(snr_db, 3),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    source_root = args.root / "assets" / "audio" / "music"
    destination_root = args.root / "assets" / "audio" / "music_web"
    if destination_root.exists():
        for old_file in list(destination_root.rglob("*.wav")) + list(destination_root.rglob("*.bthadpcm")):
            old_file.unlink()
        for old_import in list(destination_root.rglob("*.wav.import")) + list(destination_root.rglob("*.bthadpcm.import")):
            old_import.unlink()
    converted = []
    for source in sorted(source_root.rglob("*.wav")):
        relative = source.relative_to(source_root).with_suffix(".bthadpcm.gz")
        converted.append(_convert(source, destination_root / relative))
    print(json.dumps({"count": len(converted), "files": converted}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
