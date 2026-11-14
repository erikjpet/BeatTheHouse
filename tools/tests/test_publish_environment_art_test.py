import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import publish_environment_art_test as subject


class TestPublisher(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.stage = self.root / "stage"
        self.stage.mkdir()
        self.commit = "a" * 40
        self.package = "b" * 64
        config = {"args": ["--", "--bth-art-test"], "persistentPaths": [subject.TEST_MOUNT]}
        (self.stage / "index.html").write_text("const GODOT_CONFIG = " + json.dumps(config) + ";", encoding="utf-8")
        (self.stage / "index.pck").write_bytes(b"fake pack")
        self.manifest = {"source_commit": self.commit, "art_package_sha256": self.package, "channel": "test", "files": {p.name: {"bytes": p.stat().st_size, "sha256": subject.digest(p)} for p in self.stage.iterdir()}}
        self.write_manifest()
        self.target = self.root / "test"

    def write_manifest(self):
        (self.stage / "build_manifest.json").write_text(json.dumps(self.manifest), encoding="utf-8")

    def test_publish_isolated_and_idempotent(self):
        (self.root / "dev").mkdir()
        (self.root / "dev/current").write_text("normal")
        for _ in range(2):
            result = subject.publish(self.stage, self.target, self.commit, self.package, reserve_bytes=0)
            self.assertFalse(result["other_lanes_touched"])
        self.assertEqual((self.root / "dev/current").read_text(), "normal")
        self.assertEqual((self.target / "current").read_text().strip(), self.commit)
        self.assertIn(subject.MARKER, (self.target / "index.html").read_text())

    def test_bad_commit(self):
        with self.assertRaises(ValueError):
            subject.validate_payload(self.stage, "../dev", self.package)

    def test_tamper(self):
        (self.stage / "index.pck").write_bytes(b"bad")
        with self.assertRaises(ValueError):
            subject.validate_payload(self.stage, self.commit, self.package)

    def test_extra_file(self):
        (self.stage / "normal.html").write_text("not isolated")
        with self.assertRaises(ValueError):
            subject.validate_payload(self.stage, self.commit, self.package)

    def test_wrong_channel(self):
        self.manifest["channel"] = "dev"
        self.write_manifest()
        with self.assertRaises(ValueError):
            subject.validate_payload(self.stage, self.commit, self.package)

    def test_path_traversal(self):
        self.manifest["files"]["../outside"] = {"bytes": 0, "sha256": "0" * 64}
        self.write_manifest()
        with self.assertRaises(ValueError):
            subject.validate_payload(self.stage, self.commit, self.package)

    def test_unknown_launcher_preserved(self):
        self.target.mkdir()
        (self.target / "index.html").write_text("owner page")
        with self.assertRaises(ValueError):
            subject.publish(self.stage, self.target, self.commit, self.package, reserve_bytes=0)
        self.assertEqual((self.target / "index.html").read_text(), "owner page")

    def test_unisolated_config_rejected(self):
        (self.stage / "index.html").write_text('const GODOT_CONFIG = {"args":[],"persistentPaths":["/userfs"]};')
        for name, info in self.manifest["files"].items():
            info.update(bytes=(self.stage / name).stat().st_size, sha256=subject.digest(self.stage / name))
        self.write_manifest()
        with self.assertRaises(ValueError):
            subject.validate_payload(self.stage, self.commit, self.package)

    def test_insufficient_space(self):
        with patch.object(subject.shutil, "disk_usage", return_value=SimpleNamespace(free=0)):
            with self.assertRaises(ValueError):
                subject.publish(self.stage, self.target, self.commit, self.package, reserve_bytes=0)
        self.assertFalse(self.target.exists())

    def test_immutable_build_not_overwritten(self):
        subject.publish(self.stage, self.target, self.commit, self.package, reserve_bytes=0)
        (self.target / self.commit / "index.pck").write_bytes(b"tampered")
        with self.assertRaises(ValueError):
            subject.publish(self.stage, self.target, self.commit, self.package, reserve_bytes=0)
        self.assertEqual((self.target / self.commit / "index.pck").read_bytes(), b"tampered")


if __name__ == "__main__":
    unittest.main()
