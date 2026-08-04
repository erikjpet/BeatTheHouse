"""Encode deterministic procedural Web music beds rendered by Godot."""

from __future__ import annotations

import argparse
import gzip
import json
import sys
import wave
from pathlib import Path

import numpy as np


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    root = args.root.resolve()
    sys.path.insert(0, str(root / "tools"))
    from build_web_audio_masters import TARGET_RATE, _decode_pcm, _encode_ima

    source_root = root / ".tmp" / "web_procedural_music_pcm"
    destination_root = root / "assets" / "audio" / "music_web" / "procedural"
    if not source_root.is_dir():
        raise FileNotFoundError(f"missing rendered PCM directory: {source_root}")
    converted = []
    for source in sorted(source_root.glob("*.wav")):
        with wave.open(str(source), "rb") as reader:
            channels = reader.getnchannels()
            sample_width = reader.getsampwidth()
            sample_rate = reader.getframerate()
            frames = reader.getnframes()
            if channels != 1 or sample_width != 2 or sample_rate != TARGET_RATE:
                raise ValueError(
                    f"{source}: expected mono 16-bit {TARGET_RATE} Hz, found "
                    f"{channels}ch/{sample_width * 8}-bit/{sample_rate} Hz"
                )
            samples = _decode_pcm(reader.readframes(frames), sample_width, channels)
        encoded, snr_db = _encode_ima(np.asarray(samples), sample_rate)
        compressed = gzip.compress(encoded, compresslevel=9, mtime=0)
        destination = destination_root / f"{source.stem}.bthadpcm.gz"
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(compressed)
        destination.with_suffix(destination.suffix + ".import").write_text(
            '[remap]\n\nimporter="keep"\n', encoding="utf-8", newline="\n"
        )
        converted.append(
            {
                "archetype_id": source.stem,
                "frames": frames,
                "encoded_bytes": len(compressed),
                "adpcm_bytes": len(encoded),
                "snr_db": round(snr_db, 3),
            }
        )
    print(json.dumps({"count": len(converted), "files": converted}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
