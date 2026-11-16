"""Failed-case inspector contracts; only synthetic bytes and admitted scratch.

The real Windows lock tests require an already prepared guarded-run environment.
They never enumerate, read, load, write or copy a campaign/profile directory.
"""
from contextlib import redirect_stderr
from copy import deepcopy
from io import BytesIO, StringIO
import hashlib
import ntpath
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import crew_cj2_failed_inspection as inspection


class ArgumentTests(unittest.TestCase):
    def valid_args(self, mode="qualify"):
        args = [
            "--run-id", "crew-failed-qual-unit" if mode == "qualify" else "crew-failed-inspect-unit",
            "--expected-commit", "a" * 40,
            "--mode", mode,
            "--root-confirmed-no-owned-live-job",
        ]
        if mode == "inspect":
            args += ["--qualification", "crew-failed-qual-unit"]
        return args

    def reject(self, args):
        with redirect_stderr(StringIO()), self.assertRaises(SystemExit) as raised:
            inspection.parse_args(args)
        self.assertEqual(raised.exception.code, 2)

    def replace_value(self, args, flag, value):
        result = list(args)
        result[result.index(flag) + 1] = value
        return result

    def test_qualify_and_inspect_are_pure_and_explicit(self):
        with patch.object(inspection.g, "prepare_layout", side_effect=AssertionError("Unexpected preparation")), \
                patch.object(inspection, "validate_source", side_effect=AssertionError("Unexpected source read")):
            for mode in ("qualify", "inspect"):
                result = inspection.parse_args(self.valid_args(mode))
                self.assertEqual(result.mode, mode)
                self.assertEqual(result.expected_commit, "a" * 40)
                self.assertTrue(result.root_confirmed_no_owned_live_job)
                self.assertEqual(result.qualification, "crew-failed-qual-unit" if mode == "inspect" else "")

    def test_required_flags_and_preflight_attestation_cannot_be_omitted(self):
        valid = self.valid_args()
        for flag in ("--run-id", "--expected-commit", "--mode"):
            index = valid.index(flag)
            self.reject(valid[:index] + valid[index + 2:])
        self.reject([value for value in valid if value != "--root-confirmed-no-owned-live-job"])

    def test_duplicate_flags_including_equals_are_rejected(self):
        for extra in (
            ["--run-id", "crew-failed-second"],
            ["--run-id=crew-failed-second"],
            ["--expected-commit=" + "b" * 40],
            ["--mode=inspect"],
            ["--root-confirmed-no-owned-live-job"],
        ):
            self.reject(self.valid_args() + extra)

    def test_abbreviated_or_unlisted_input_profile_and_recovery_flags_reject(self):
        abbreviated = self.valid_args()
        abbreviated[abbreviated.index("--expected-commit")] = "--expected"
        self.reject(abbreviated)
        for extra in (
            ["--profile", r"E:\synthetic-unadmitted"],
            ["--primary", r"E:\synthetic-unadmitted.json"],
            ["--slot", "OTHER"],
            ["--root", r"E:\synthetic-unadmitted"],
            ["--cpu-rate", "1500"],
            ["--force"],
            ["--recover"],
        ):
            self.reject(self.valid_args() + extra)
        for mode in ("recover", "resume", "handoff", "save"):
            self.reject(self.replace_value(self.valid_args(), "--mode", mode))

    def test_named_run_and_full_lowercase_source_identity_are_required(self):
        for value in ("crew-native-unit", "../escape", "crew-failed-", "CREW-FAILED-unit", "crew-failed-" + "x" * 50):
            self.reject(self.replace_value(self.valid_args(), "--run-id", value))
        for value in ("HEAD", "A" * 40, "a" * 39, "a" * 41, "g" * 40, ""):
            self.reject(self.replace_value(self.valid_args(), "--expected-commit", value))

    def test_qualification_is_required_only_for_inspection_and_cannot_be_foreign(self):
        self.reject(self.valid_args() + ["--qualification", "crew-failed-qual-unit"])
        inspect_args = self.valid_args("inspect")
        index = inspect_args.index("--qualification")
        self.reject(inspect_args[:index])
        for value in ("crew-native-guards14-261116", "../receipt", "crew-failed-qual", "crew-failed-qual-" + "x" * 46):
            self.reject(self.replace_value(inspect_args, "--qualification", value))


class FrozenScopeTests(unittest.TestCase):
    def valid_scope(self):
        # Synthetic receipt metadata only; none of these strings is opened.
        return {
            "schema": "bth.cj2_failed_inspection_scope/v1",
            "case": inspection.FAILED,
            "custody_sha256": inspection.CUSTODY_SHA,
            "product_inputs_sha256": inspection.PRODUCT,
            "profile_contents_read": False,
            "archived_clean_predecessor_validated": True,
            "original_failed_status_preserved": True,
            "directory_identities": {
                name: [1, index + 1]
                for index, name in enumerate(("profile", "save_dir", "appdata", "localappdata", "home", "cache"))
            },
            "metadata_hashes": {"synthetic-proof-%03d" % index: "a" * 64 for index in range(111)},
        }

    def test_valid_scope_is_checked_without_mutation_or_preparation(self):
        scope = self.valid_scope()
        original = deepcopy(scope)
        with patch.object(inspection.g, "prepare_layout", side_effect=AssertionError("Unexpected preparation")):
            self.assertEqual(inspection.validate_scope(scope), original)
        self.assertEqual(scope, original)

    def test_exact_failed_identity_and_historical_status_proofs_cannot_change(self):
        for name, value in (
            ("schema", "bth.unrelated/v1"),
            ("case", "crew-native-unrelated"),
            ("custody_sha256", "0" * 64),
            ("product_inputs_sha256", "0" * 64),
            ("profile_contents_read", True),
            ("profile_contents_read", 0),
            ("archived_clean_predecessor_validated", False),
            ("archived_clean_predecessor_validated", 1),
            ("original_failed_status_preserved", False),
            ("original_failed_status_preserved", "true"),
        ):
            with self.subTest(field=name, value=value):
                scope = self.valid_scope()
                scope[name] = value
                original = deepcopy(scope)
                with self.assertRaises(ValueError):
                    inspection.validate_scope(scope)
                self.assertEqual(scope, original)

    def test_all_original_directories_and_frozen_metadata_coverage_are_required(self):
        for field in ("directory_identities", "metadata_hashes"):
            for mutation in ("missing", "extra", "wrong_type"):
                scope = self.valid_scope()
                if mutation == "missing":
                    del scope[field][next(iter(scope[field]))]
                elif mutation == "extra":
                    scope[field]["synthetic-extra"] = "b" * 64
                else:
                    scope[field] = []
                with self.subTest(field=field, mutation=mutation), self.assertRaises(ValueError):
                    inspection.validate_scope(scope)


class ClosureTests(unittest.TestCase):
    def test_no_child_construction_does_not_need_a_job_receipt(self):
        self.assertTrue(inspection.closure_proven(None, False))

    def test_attempted_construction_requires_an_actual_integer_zero(self):
        for job in (None, {}, [], {"active_at_release": None}, {"active_at_release": False},
                    {"active_at_release": True}, {"active_at_release": 0.0},
                    {"active_at_release": "0"}, {"active_at_release": -1},
                    {"active_at_release": 1}):
            with self.subTest(job=job):
                self.assertFalse(inspection.closure_proven(job, True))
        self.assertTrue(inspection.closure_proven({"active_at_release": 0}, True))


class HashBoundTests(unittest.TestCase):
    def test_empty_and_exact_bound_hash(self):
        for payload in (b"", b"x", b"synthetic-inspection-input\x00\xff" * 97):
            with self.subTest(size=len(payload)):
                self.assertEqual(
                    inspection.hash_stream(BytesIO(payload), len(payload)),
                    hashlib.sha256(payload).hexdigest(),
                )

    def test_one_byte_over_bound_is_rejected(self):
        for limit in (0, 1, 4096):
            with self.subTest(limit=limit):
                with self.assertRaises(ValueError):
                    inspection.hash_stream(BytesIO(b"x" * (limit + 1)), limit)

    def test_short_reads_do_not_truncate_the_hash(self):
        class ShortReader(BytesIO):
            def read(self, size=-1):
                return super().read(3 if size < 0 else min(size, 3))

        payload = bytes(range(256)) * 9
        self.assertEqual(
            inspection.hash_stream(ShortReader(payload), len(payload)),
            hashlib.sha256(payload).hexdigest(),
        )

    def test_reader_error_is_propagated(self):
        class BrokenReader:
            def read(self, size=-1):
                raise OSError("synthetic read failure")

        with self.assertRaisesRegex(OSError, "synthetic read failure"):
            inspection.hash_stream(BrokenReader(), 32)


@unittest.skipUnless(os.name == "nt", "Windows read-sharing qualification")
class ReadLockTests(unittest.TestCase):
    def setUp(self):
        # Reject a missing/default TEMP rather than silently creating C: files.
        expected_root = Path(r"E:\CodexQA\BTH\runs")
        run_text = os.environ.get("BTH_QA_RUN_DIR", "")
        temp_text = os.environ.get("BTH_QA_TEMP_DIR", "")
        self.assertTrue(run_text and temp_text, "A prepared guarded-run environment is required")
        run_root, temp_root = Path(run_text), Path(temp_text)
        self.assertEqual(run_root.parent, expected_root)
        self.assertNotEqual(run_root.name, "crew-fresh-cj2-261116")
        self.assertEqual(temp_root, run_root / "temp")
        self.assertEqual(
            ntpath.normcase(ntpath.normpath(os.environ.get("TEMP", ""))),
            ntpath.normcase(ntpath.normpath(temp_text)),
        )
        self.assertTrue(temp_root.is_dir())
        self.temporary = tempfile.TemporaryDirectory(
            prefix="failed-inspection-lock-unit-", dir=str(temp_root)
        )
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.path = self.directory / "00-synthetic.bin"
        self.payload = b"Synthetic lock qualification. No player/profile content.\x00\xff"
        self.path.write_bytes(self.payload)

    def assert_snapshot(self, snapshots):
        self.assertEqual(set(snapshots), {str(self.path)})
        observed = snapshots[str(self.path)]
        self.assertEqual(set(observed), {"dev", "ino", "size", "sha256"})
        self.assertIs(type(observed["dev"]), int)
        self.assertIs(type(observed["ino"]), int)
        self.assertGreater(observed["ino"], 0)
        self.assertEqual(observed["size"], len(self.payload))
        self.assertEqual(observed["sha256"], hashlib.sha256(self.payload).hexdigest())

    def test_lock_allows_reads_and_denies_write_delete_and_rename(self):
        renamed = self.directory / "renamed.bin"
        with inspection.ReadLocks([self.path]) as locks:
            first = locks.snapshot()
            self.assert_snapshot(first)
            self.assertEqual(self.path.read_bytes(), self.payload)
            with self.assertRaises(PermissionError):
                self.path.write_bytes(b"write must be rejected")
            with self.assertRaises(PermissionError):
                self.path.unlink()
            with self.assertRaises(PermissionError):
                self.path.rename(renamed)
            self.assertFalse(renamed.exists())
            self.assertEqual(locks.snapshot(), first)
        self.assertEqual(self.path.read_bytes(), self.payload)
        # A successful write after exit proves that the lock handle was released.
        self.path.write_bytes(b"Released synthetic handle.")
        self.assertEqual(self.path.read_bytes(), b"Released synthetic handle.")

    def test_body_exception_releases_handles_and_preserves_input(self):
        with self.assertRaisesRegex(RuntimeError, "synthetic body failure"):
            with inspection.ReadLocks([self.path]) as locks:
                self.assert_snapshot(locks.snapshot())
                raise RuntimeError("synthetic body failure")
        self.assertEqual(self.path.read_bytes(), self.payload)
        self.path.write_bytes(b"Released after exception.")

    def test_partial_enter_failure_releases_already_opened_handle(self):
        absent = self.directory / "99-absent.bin"
        with self.assertRaises((ValueError, OSError, RuntimeError)):
            with inspection.ReadLocks([self.path, absent]):
                self.fail("Missing synthetic input must reject before inspection")
        self.assertEqual(self.path.read_bytes(), self.payload)
        self.path.write_bytes(b"Released after partial enter.")
        self.assertFalse(absent.exists())


if __name__ == "__main__":
    unittest.main()
