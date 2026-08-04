"""Compress generated Web SFX PCM masters into browser-decoded IMA ADPCM."""

from __future__ import annotations

import argparse
import base64
from pathlib import Path

import numpy as np

from build_web_audio_masters import _encode_ima


def main() -> int:
	parser = argparse.ArgumentParser()
	parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
	args = parser.parse_args()
	delivery_root = args.root / "assets" / "audio" / "sfx_web"
	total_bytes = 0
	count = 0
	min_snr = float("inf")
	for path in sorted(delivery_root.glob("*.bthsfx")):
		header, encoded = path.read_text(encoding="utf-8").split("\n", 1)
		parts = header.split("|")
		if len(parts) != 5 or parts[0] != "BTHS" or parts[1] != "1":
			raise ValueError(f"invalid generated SFX master header: {path}")
		sample_rate = int(parts[2])
		frames = int(parts[3])
		loop_flag = parts[4]
		pcm = np.frombuffer(base64.b64decode(encoded), dtype="<i2")
		if pcm.size != frames:
			raise ValueError(f"frame count mismatch in {path}")
		adpcm, snr_db = _encode_ima((pcm.astype(np.float64) / 32768.0).reshape(-1, 1), sample_rate)
		payload = f"BTHA64|1|{loop_flag}\n{base64.b64encode(adpcm).decode('ascii')}"
		path.write_text(payload, encoding="utf-8", newline="\n")
		total_bytes += len(payload.encode("utf-8"))
		count += 1
		min_snr = min(min_snr, snr_db)
	print({"count": count, "bytes": total_bytes, "min_snr_db": round(min_snr, 3)})
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
