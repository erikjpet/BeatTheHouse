"""Encode deterministic slot feature stems for hitch-free runtime delivery."""

from __future__ import annotations

import argparse
import json
import struct
import wave
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    root = args.root.resolve()

    source_root = root / ".tmp" / "slot_feature_music_pcm"
    destination_root = root / "assets" / "audio" / "music_features"
    if not source_root.is_dir():
        raise FileNotFoundError(f"missing rendered feature PCM directory: {source_root}")

    converted = []
    roles = ("pad", "bass", "lead", "drums_low", "drums_high", "tension", "texture")
    for style_root in sorted(path for path in source_root.iterdir() if path.is_dir()):
        pcm_by_role = []
        sample_rate = 0
        frames = 0
        for role in roles:
            source = style_root / f"{role}.wav"
            with wave.open(str(source), "rb") as reader:
                channels = reader.getnchannels()
                sample_width = reader.getsampwidth()
                role_rate = reader.getframerate()
                role_frames = reader.getnframes()
                if channels != 1 or sample_width != 2:
                    raise ValueError(f"{source}: expected mono 16-bit PCM")
                if sample_rate and (role_rate != sample_rate or role_frames != frames):
                    raise ValueError(f"{source}: feature stem timing mismatch")
                sample_rate = role_rate
                frames = role_frames
                pcm_by_role.append(reader.readframes(role_frames))
        destination = destination_root / f"{style_root.name}.bthstems"
        encoded = b"BTHM" + struct.pack("<BBBBII", 1, 1, len(roles), 0, sample_rate, frames) + b"".join(pcm_by_role)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(encoded)
        destination.with_suffix(destination.suffix + ".import").write_text(
            '[remap]\n\nimporter="keep"\n', encoding="utf-8", newline="\n"
        )
        converted.append({
            "style": style_root.name,
            "destination": str(destination),
            "frames": frames,
            "sample_rate": sample_rate,
            "encoded_bytes": len(encoded),
            "codec": "pcm_s16le",
            "roles": list(roles),
        })
    print(json.dumps({"count": len(converted), "files": converted}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
