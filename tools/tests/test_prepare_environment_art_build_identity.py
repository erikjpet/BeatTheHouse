import hashlib
import io
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import prepare_environment_art_build_identity as subject


def identity_manifest():
    return {"schema": subject.SCHEMA, "build_version": "0.6.0-dev+" + "a" * 12,
            "source_commit": "a" * 40, "source_tree": "c" * 40, "source_dirty": False,
            "dirty_state_digest": subject.CLEAN_DIRTY_DIGEST, "engine_sha256": "d" * 64,
            "export_presets_sha256": "e" * 64, "native_library_path": "coin_pusher_native.wasm",
            "native_library_sha256": "f" * 64, "platform": "web", "channel": "test",
            "art_package_sha256": "b" * 64}


def synthetic_pck(entries, *, version=3, flags=0, entry_flags=0):
    """Minimal actual PCK directory/data, following audit_pck_manifest_contract_test."""
    header = bytearray(112 if version == 3 else 100)
    header[:4] = b"GDPC"
    struct.pack_into("<IIIII", header, 4, version, 4, 6, 0, flags)
    if version == 3:
        struct.pack_into("<Q", header, 32, len(header))
    directory = bytearray(struct.pack("<I", len(entries)))
    payload = bytearray()
    for path, content in entries:
        name = path.encode("utf-8") + b"\0"
        directory += struct.pack("<I", len(name)) + name + b"\0" * ((-len(name)) % 4)
        directory += struct.pack("<QQ16sI", len(payload), len(content), hashlib.md5(content).digest(), entry_flags)
        payload += content
    struct.pack_into("<Q", header, 24, len(header) + len(directory))
    return bytes(header + directory + payload)


class TestEmbeddedIdentity(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.snapshot = self.root / "snapshot"
        self.snapshot.mkdir()
        for name in ("project.godot", "export_presets.cfg"):
            (self.snapshot / name).write_bytes(("test " + name).encode())
        self.engine = self.root / "godot.exe"
        self.engine.write_bytes(b"engine bytes")
        self.native = self.root / "coin_pusher_native.wasm"
        self.native.write_bytes(b"native bytes")
        self.package = self.root / "index.pck"
        self.manifest = identity_manifest()

    def prepare(self, **overrides):
        args = dict(snapshot=self.snapshot, source_commit=self.manifest["source_commit"],
                    source_tree=self.manifest["source_tree"], engine=self.engine,
                    native_library=self.native, export_presets=self.snapshot / "export_presets.cfg",
                    art_package_sha256=self.manifest["art_package_sha256"])
        args.update(overrides)
        return subject.prepare_identity(**args)

    def pack(self, manifest=None, **kwargs):
        raw = json.dumps(self.manifest if manifest is None else manifest).encode("utf-8")
        self.package.write_bytes(synthetic_pck([("res://build_manifest.json", raw)], **kwargs))
        return raw

    def test_clean_digest_matches_exporter_canonical(self):
        canonical = b"\ne69de29bb2d1d6434b8b29ae775ad8c2e48c5391\n"
        self.assertEqual(subject.CLEAN_DIRTY_DIGEST, hashlib.sha256(canonical).hexdigest())

    def test_prepare_real_input_hashes_non_circular_utf8(self):
        manifest = self.prepare()
        raw = (self.snapshot / "build_manifest.json").read_bytes()
        self.assertFalse(raw.startswith(b"\xef\xbb\xbf"))
        self.assertNotIn(b"\r", raw)
        self.assertEqual(json.loads(raw), manifest)
        self.assertEqual(manifest["engine_sha256"], hashlib.sha256(self.engine.read_bytes()).hexdigest())
        self.assertEqual(manifest["native_library_sha256"], hashlib.sha256(self.native.read_bytes()).hexdigest())
        self.assertEqual(manifest["export_presets_sha256"], hashlib.sha256((self.snapshot / "export_presets.cfg").read_bytes()).hexdigest())
        self.assertFalse(manifest["source_dirty"])
        self.assertFalse(set(manifest) & set(subject.POST_EXPORT_FIELDS))
        subject.validate_identity(manifest)

    def test_prepare_preserves_existing_manifest(self):
        path = self.snapshot / "build_manifest.json"
        path.write_bytes(b"owner bytes")
        with self.assertRaises(FileExistsError):
            self.prepare()
        self.assertEqual(path.read_bytes(), b"owner bytes")

    def test_prepare_refuses_git_checkout(self):
        (self.snapshot / ".git").write_text("gitdir: elsewhere")
        with self.assertRaisesRegex(ValueError, "git-archive"):
            self.prepare()

    def test_prepare_requires_snapshot_presets(self):
        foreign = self.root / "export_presets.cfg"
        foreign.write_bytes(b"other presets")
        with self.assertRaisesRegex(ValueError, "snapshot's"):
            self.prepare(export_presets=foreign)

    def test_prepare_rejects_invalid_hash_shapes_before_writing(self):
        for field, bad in (("source_commit", "abc"), ("source_commit", None),
                           ("source_tree", "0" * 40), ("art_package_sha256", "B" * 64)):
            with self.subTest(field=field, bad=bad), self.assertRaises(ValueError):
                self.prepare(**{field: bad})
        self.assertFalse((self.snapshot / "build_manifest.json").exists())

    def test_prepare_rejects_missing_or_empty_input(self):
        for field in ("engine", "native_library", "export_presets"):
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.prepare(**{field: self.root / "missing"})
        self.engine.write_bytes(b"")
        with self.assertRaises(ValueError):
            self.prepare()

    def test_verify_valid_v2_v3_pack_and_actual_hashes(self):
        for version in (2, 3):
            with self.subTest(version=version):
                raw = self.pack(version=version)
                result = subject.verify_embedded_identity(self.package, self.manifest)
                self.assertTrue(result["passed"])
                self.assertEqual(result["embedded_manifest_sha256"], hashlib.sha256(raw).hexdigest())
                self.assertEqual(result["embedded_manifest_md5"], hashlib.md5(raw).hexdigest())

    def test_verify_prepared_manifest_round_trip(self):
        self.manifest = self.prepare()
        self.pack()
        result = subject.verify_embedded_identity(self.package, self.manifest)
        external = {**self.manifest, "files": {"index.pck": {}},
                    "embedded_manifest_sha256": result["embedded_manifest_sha256"],
                    "embedded_manifest_md5": result["embedded_manifest_md5"]}
        self.assertTrue(subject.verify_embedded_identity(self.package, external)["passed"])

    def test_cli_prepare_then_verify(self):
        command = ["prepare", "--snapshot", str(self.snapshot), "--source-commit", self.manifest["source_commit"],
                   "--source-tree", self.manifest["source_tree"], "--engine", str(self.engine),
                   "--native-library", str(self.native), "--export-presets", str(self.snapshot / "export_presets.cfg"),
                   "--art-package-sha256", self.manifest["art_package_sha256"], "--build-version", "0.6.1-art-test+aaaaaaaaaaaa"]
        with patch("sys.stdout", new_callable=io.StringIO) as output:
            self.assertEqual(subject.main(command), 0)
            self.manifest = json.loads(output.getvalue())
        self.assertEqual(self.manifest["build_version"], "0.6.1-art-test+aaaaaaaaaaaa")
        self.pack()
        with patch("sys.stdout", new_callable=io.StringIO) as output:
            self.assertEqual(subject.main(["verify", "--package", str(self.package), "--manifest", str(self.snapshot / "build_manifest.json")]), 0)
            self.assertTrue(json.loads(output.getvalue())["passed"])

    def test_verify_missing_embedded_manifest(self):
        self.package.write_bytes(synthetic_pck([("res://project.binary", b"project")]))
        with self.assertRaisesRegex(ValueError, "exactly one embedded"):
            subject.verify_embedded_identity(self.package, self.manifest)

    def test_verify_duplicate_embedded_manifest(self):
        raw = json.dumps(self.manifest).encode()
        self.package.write_bytes(synthetic_pck([("build_manifest.json", raw), ("res://build_manifest.json", raw)]))
        with self.assertRaisesRegex(ValueError, "exactly one embedded"):
            subject.verify_embedded_identity(self.package, self.manifest)

    def test_verify_unbound_or_incomplete_manifest(self):
        for field in subject.IDENTITY_FIELDS:
            with self.subTest(field=field):
                value = dict(self.manifest)
                del value[field]
                self.pack(value)
                with self.assertRaises(ValueError):
                    subject.verify_embedded_identity(self.package, self.manifest)
        self.pack({**self.manifest, "build_version": "UNBOUND-DISTRIBUTION-BUILD"})
        with self.assertRaises(ValueError):
            subject.verify_embedded_identity(self.package, self.manifest)

    def test_verify_identity_mismatch(self):
        for field, replacement in (("source_commit", "1" * 40), ("source_tree", "2" * 40),
                                   ("engine_sha256", "3" * 64), ("art_package_sha256", "4" * 64)):
            with self.subTest(field=field):
                self.pack({**self.manifest, field: replacement})
                with self.assertRaisesRegex(ValueError, "identity mismatch"):
                    subject.verify_embedded_identity(self.package, self.manifest)

    def test_verify_source_must_be_clean(self):
        for extra in ({"source_dirty": True}, {"source_dirty": 0}, {"dirty_state_digest": "1" * 64}):
            self.pack({**self.manifest, **extra})
            with self.assertRaisesRegex(ValueError, "clean archive"):
                subject.verify_embedded_identity(self.package, self.manifest)

    def test_verify_md5_detects_manifest_corruption(self):
        self.pack()
        raw = bytearray(self.package.read_bytes())
        raw[-1] ^= 1
        self.package.write_bytes(raw)
        with self.assertRaisesRegex(ValueError, "PCK MD5"):
            subject.verify_embedded_identity(self.package, self.manifest)

    def test_verify_declared_manifest_hash_mismatch(self):
        self.pack()
        for field, value in (("embedded_manifest_sha256", "1" * 64), ("embedded_manifest_md5", "2" * 32)):
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, field):
                subject.verify_embedded_identity(self.package, {**self.manifest, field: value})

    def test_verify_truncated_payload(self):
        self.pack()
        self.package.write_bytes(self.package.read_bytes()[:-1])
        with self.assertRaisesRegex(ValueError, "outside the PCK"):
            subject.verify_embedded_identity(self.package, self.manifest)

    def test_verify_invalid_json(self):
        self.package.write_bytes(synthetic_pck([("build_manifest.json", b"not JSON")]))
        with self.assertRaisesRegex(ValueError, "UTF-8 JSON"):
            subject.verify_embedded_identity(self.package, self.manifest)

    def test_verify_rejects_encrypted_sparse_and_flagged_entry(self):
        for kwargs in ({"flags": 1}, {"flags": 4}, {"entry_flags": 1}, {"entry_flags": 2}):
            self.pack(**kwargs)
            with self.assertRaises(ValueError):
                subject.verify_embedded_identity(self.package, self.manifest)

    def test_verify_rejects_development_content(self):
        raw = json.dumps(self.manifest).encode()
        self.package.write_bytes(synthetic_pck([("build_manifest.json", raw), ("tools/leak.py", b"private")]))
        with self.assertRaisesRegex(ValueError, "content audit failed"):
            subject.verify_embedded_identity(self.package, self.manifest)

    def test_verify_rejects_manifest_aliases(self):
        raw = json.dumps(self.manifest).encode()
        for name in ("./build_manifest.json", "folder/../build_manifest.json", "/build_manifest.json"):
            self.package.write_bytes(synthetic_pck([("build_manifest.json", raw), (name, raw)]))
            with self.assertRaisesRegex(ValueError, "Noncanonical"):
                subject.verify_embedded_identity(self.package, self.manifest)

    def test_verify_rejects_circular_post_export_fields(self):
        for field in subject.POST_EXPORT_FIELDS:
            self.pack({**self.manifest, field: {}})
            with self.assertRaisesRegex(ValueError, "circular identity"):
                subject.verify_embedded_identity(self.package, self.manifest)


if __name__ == "__main__":
    unittest.main()
