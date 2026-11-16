"""Read-only fixed GBR baseline regressions; root runs under the storage/Job guard."""
import sys
sys.dont_write_bytecode = True
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import copy
import json
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import grand_back_room_spatial_delivered_baseline as b


class ActualFixture(unittest.TestCase):
    def setUp(self):
        self.delivery = b.read(b.DELIVERY)
        self.manifest = b.read(b.STAGE / "build_manifest.json")
        self.qualification = copy.deepcopy(self.delivery["strict_build"]["qualified_stage"])
        # The pure component fixture is an indexed declaration, NOT independently
        # qualified source. Only the complete load_certificate case authenticates it.
        self.seal = {"all421_source_hashes": dict(self.manifest["art_source_files"]),
                     "native_export_original_code_files_equal": 760}
        self.before = b.read(b.RUNS / (b.PREFIX + "-before") / "evidence/before.json")
        self.report = b.read(b.RUNS / (b.PREFIX + "-served") / "evidence/served.json")

    def validate(self):
        return b.validate_delivery(self.delivery, self.manifest, self.qualification, self.seal)

    def test_actual_delivery_and_manifest_bytes_are_pinned(self):
        self.assertEqual(b.sha(b.DELIVERY), b.DELIVERY_SHA)
        self.assertEqual(b.sha(b.STAGE / "build_manifest.json"), b.MANIFEST_SHA)
        self.validate()

    def test_wrong_delivery_schema_rejected(self):
        self.delivery["schema"] = "bth.high_limit_spatial_test_delivery/v1"
        with self.assertRaises(ValueError): self.validate()

    def test_wrong_delivery_status_rejected(self):
        self.delivery["status"] = "NATIVE_ONLY_PASS"
        with self.assertRaises(ValueError): self.validate()

    def test_wrong_room_rejected(self):
        self.delivery["environment_id"] = "grand_casino_high_limit"
        with self.assertRaises(ValueError): self.validate()

    def test_wrong_source_commit_rejected(self):
        self.delivery["export_identity"]["source_commit"] = b.gbr.delivered.SOURCE
        with self.assertRaises(ValueError): self.validate()

    def test_wrong_tree_rejected(self):
        self.delivery["export_identity"]["source_tree"] = "0" * 40
        with self.assertRaises(ValueError): self.validate()

    def test_borrowed_HL_stage_rejected(self):
        self.delivery["export_identity"]["stage"] = str(b.gbr.delivered.STAGE)
        with self.assertRaises(ValueError): self.validate()

    def test_wrong_manifest_or_pck_pin_rejected(self):
        for name in ("manifest_sha256", "pck_sha256"):
            with self.subTest(name=name):
                old = self.delivery["export_identity"][name]
                self.delivery["export_identity"][name] = "0" * 64
                with self.assertRaises(ValueError): self.validate()
                self.delivery["export_identity"][name] = old

    def test_wrong_package_rejected(self):
        self.delivery["export_identity"]["art_package_21_file_sha256"] = "0" * 64
        with self.assertRaises(ValueError): self.validate()

    def test_dirty_or_wrong_channel_manifest_rejected(self):
        self.manifest["source_dirty"] = True
        with self.assertRaises(ValueError): self.validate()
        self.manifest["source_dirty"] = False
        self.manifest["channel"] = "next"
        with self.assertRaises(ValueError): self.validate()

    def test_other_room_seal_rejected(self):
        self.manifest["active_art_packages"]["bar"] = "0" * 64
        with self.assertRaises(ValueError): self.validate()

    def test_doorway_change_rejected(self):
        self.manifest["active_doorway_packages"]["bar"] = "0" * 64
        with self.assertRaises(ValueError): self.validate()

    def test_full_archive_claim_rejected(self):
        self.delivery["export_identity"]["full_repository_archive"] = True
        with self.assertRaises(ValueError): self.validate()

    def test_selected_scope_relabel_rejected(self):
        self.delivery["export_identity"]["source_scope"] = "FULL_REPOSITORY_ARCHIVE"
        with self.assertRaises(ValueError): self.validate()

    def test_selection_archive_or_attribute_change_rejected(self):
        for name in ("source_selection_sha256", "source_archive_sha256"):
            with self.subTest(name=name):
                old = self.delivery["export_identity"][name]
                self.delivery["export_identity"][name] = "0" * 64
                with self.assertRaises(ValueError): self.validate()
                self.delivery["export_identity"][name] = old
        self.delivery["export_identity"]["actual_attributes_proof"]["source_bytes_substituted"] = True
        with self.assertRaises(ValueError): self.validate()

    def test_missing_raw_or_compiled_source_rejected(self):
        self.manifest["art_source_files"].pop(next(iter(self.manifest["art_source_files"])))
        with self.assertRaises(ValueError): self.validate()
        self.manifest = b.read(b.STAGE / "build_manifest.json")
        self.manifest["compiled_art_sha256"].pop(next(iter(self.manifest["compiled_art_sha256"])))
        with self.assertRaises(ValueError): self.validate()

    def test_rehashed_source_seal_mismatch_rejected(self):
        self.seal["all421_source_hashes"][next(iter(self.seal["all421_source_hashes"]))] = "0" * 64
        with self.assertRaises(ValueError): self.validate()

    def test_original_code_count_not_full_source_count(self):
        self.delivery["native_source_and_export_bridge"]["actual_original_code_files_equal"] = 421
        with self.assertRaises(ValueError): self.validate()

    def test_bridge_bool_count_and_native_source_rejected(self):
        bridge = self.delivery["native_source_and_export_bridge"]
        bridge["approved_changed_sources"] = True
        with self.assertRaises(ValueError): self.validate()
        bridge["approved_changed_sources"] = 10
        bridge["native_source_commit"] = b.SOURCE
        with self.assertRaises(ValueError): self.validate()

    def test_other411_scope_loss_rejected(self):
        self.delivery["native_source_and_export_bridge"]["other411_raw_sources_byte_exact"] = False
        with self.assertRaises(ValueError): self.validate()

    def test_wrong_strict_delta_or_uid_cache_rejected(self):
        self.qualification["grand_back_room_profile"]["strict_pck_delta"]["uid_cache_bytes_equal"] = False
        with self.assertRaises(ValueError): self.validate()

    def test_borrowed_ancestor_certificate_rejected(self):
        self.delivery["strict_build"]["actual_delivered_HL_baseline_certificate_sha256"] = "0" * 64
        with self.assertRaises(ValueError): self.validate()

    def test_changed_indexed_qualification_rejected(self):
        self.delivery["strict_build"]["qualified_stage"]["embedded_pck_identity"]["passed"] = False
        with self.assertRaises(ValueError): self.validate()

    def test_window_uses_actual_lane_clocks(self):
        self.assertNotEqual(self.before["started_utc"], self.before["state"]["started_utc"])
        self.assertNotEqual(self.report["finished_utc"], self.report["state"]["finished_utc"])
        b.validate_historical_window(self.before, self.report, self.delivery)

    def test_worker_clock_substitution_rejected(self):
        window = self.delivery["served_verification"]["actual_publication_observation_window"]
        window["from"] = self.before["started_utc"]
        with self.assertRaises(ValueError): b.validate_historical_window(self.before, self.report, self.delivery)

    def test_wrong_historical_NEXT_or_launcher_rejected(self):
        self.report["next_preservation"]["source_commit"] = "0" * 40
        with self.assertRaises(ValueError): b.validate_historical_window(self.before, self.report, self.delivery)
        self.report = b.read(b.RUNS / (b.PREFIX + "-served") / "evidence/served.json")
        self.report["state"]["test"]["managed_launcher"] = False
        with self.assertRaises(ValueError): b.validate_historical_window(self.before, self.report, self.delivery)

    def test_all15_actual_phase_receipts_authenticate(self):
        cfg = b.read(b.RUNS / (b.PREFIX + "-verify") / "evidence/build-inputs.json")
        self.assertEqual(len(b.builder.PHASES), 15)
        b.authenticate_build_phases(self.delivery["strict_build"]["phase_receipts"], cfg)

    def test_missing_phase_or_changed_config_rejected_before_child(self):
        cfg = b.read(b.RUNS / (b.PREFIX + "-verify") / "evidence/build-inputs.json")
        refs = copy.deepcopy(self.delivery["strict_build"]["phase_receipts"])
        refs.pop("verify")
        with self.assertRaises(ValueError): b.authenticate_build_phases(refs, cfg)
        cfg["source_commit"] = "0" * 40
        with self.assertRaises(ValueError): b.authenticate_build_phases(self.delivery["strict_build"]["phase_receipts"], cfg)

    def test_changed_phase_receipt_or_pid_rejected(self):
        cfg = b.read(b.RUNS / (b.PREFIX + "-verify") / "evidence/build-inputs.json")
        refs = copy.deepcopy(self.delivery["strict_build"]["phase_receipts"])
        refs["source-identity"]["job_sha256"] = "0" * 64
        with self.assertRaises(ValueError): b.authenticate_build_phases(refs, cfg)
        refs = copy.deepcopy(self.delivery["strict_build"]["phase_receipts"])
        refs["source-identity"]["pid"] += 1
        with self.assertRaises(ValueError): b.authenticate_build_phases(refs, cfg)

    def test_actual3_publication_jobs_authenticate(self):
        for phase, record, name in (
            ("publish", self.delivery["publication"]["closed_job"], "publish_environment_art_test.py"),
            ("before", self.delivery["publication"]["before_job"], "verify_grand_back_room_spatial_test_served.py"),
            ("served", self.delivery["served_verification"]["closed_job"], "verify_grand_back_room_spatial_test_served.py")):
            with self.subTest(phase=phase):
                b.authenticate_indexed_job(record, b.RUNS / (b.PREFIX + "-" + phase) / "evidence", name)

    def test_wrong_Job_hash_or_borrowed_evidence_rejected(self):
        e = b.RUNS / (b.PREFIX + "-publish") / "evidence"
        with self.assertRaises(ValueError): b.authenticate_job(e, "0" * 64, "publish_environment_art_test.py")
        with self.assertRaises(ValueError):
            b.authenticate_job(b.gbr.delivered.RUNS / (b.gbr.delivered.PREFIX + "-publish") / "evidence",
                               self.delivery["publication"]["closed_job"]["job_sha256"], "publish_environment_art_test.py")

    def test_wrong_entrypoint_command_and_missing_claim_rejected(self):
        e = b.RUNS / (b.PREFIX + "-publish") / "evidence"
        record = self.delivery["publication"]["closed_job"]
        original_read = b.read
        def changed(path):
            value = original_read(path)
            if Path(path) == e / "job.json": value["command"][2] = str(b.gbr.delivered.WORKSPACE / "tools/publish_environment_art_test.py")
            return value
        with patch.object(b, "read", side_effect=changed):
            with self.assertRaises(ValueError): b.authenticate_job(e, record["job_sha256"], "publish_environment_art_test.py")
        def missing(path):
            return {} if Path(path) == e / "launch-claim.json" else original_read(path)
        with patch.object(b, "read", side_effect=missing):
            with self.assertRaises(ValueError): b.authenticate_job(e, record["job_sha256"], "publish_environment_art_test.py")

    def test_capacity_or_caps_mutation_rejected(self):
        e = b.RUNS / (b.PREFIX + "-publish") / "evidence"
        record = self.delivery["publication"]["closed_job"]
        original_read = b.read
        for filename, mutate in (
            ("storage-manifest.json", lambda x: x.update(reserve_bytes=0)),
            ("job.json", lambda x: x["limits"].update(cpu_rate=10000)),
            ("job.json", lambda x: x.update(active_at_release=1))):
            def changed(path):
                value = original_read(path)
                if Path(path) == e / filename: mutate(value)
                return value
            with self.subTest(filename=filename), patch.object(b, "read", side_effect=changed):
                with self.assertRaises(ValueError): b.authenticate_job(e, record["job_sha256"], "publish_environment_art_test.py")

    def test_default_TLS_stream_rejects_wrong_hash_or_scope(self):
        row = copy.deepcopy(self.report["files"]["index.html"])
        b.validate_stream_record(row, row["bytes"], row["sha256"], row["url"])
        with self.assertRaises(ValueError): b.validate_stream_record(row, row["bytes"], "0" * 64, row["url"])
        with self.assertRaises(ValueError): b.validate_stream_record(row, row["bytes"], row["sha256"], row["url"].replace(b.SOURCE, b.gbr.delivered.SOURCE))
        row["default_tls_validation"] = False
        with self.assertRaises(ValueError): b.validate_stream_record(row, row["bytes"], row["sha256"], row["url"])

    def test_loader_rejects_delivery_hash_before_qualification(self):
        with patch.object(b, "sha", return_value="0" * 64):
            with self.assertRaises(ValueError): b.load_certificate()

    def test_CLI_missing_admission_rejects_without_qualification(self):
        with patch.object(b, "os", SimpleNamespace(environ={})), patch.object(b, "load_certificate") as load, patch.object(b, "print", create=True) as output:
            self.assertEqual(b.main(), 1)
            load.assert_not_called()
            value = json.loads(output.call_args.args[0])
            self.assertFalse(value["baseline_qualified"])
            self.assertFalse(value["fallback_attempted"])
            self.assertEqual(value["status"], "BASELINE_CERTIFICATE_REJECTED")

    def test_no_configurable_baseline_argument(self):
        with self.assertRaises(TypeError): b.load_certificate(b.gbr.delivered.STAGE)

    def test_actual_full_recursive_readonly_certificate(self):
        result = b.load_certificate()
        self.assertEqual(result["source_commit"], b.SOURCE)
        self.assertEqual(result["manifest_sha256"], b.MANIFEST_SHA)
        self.assertTrue(result["baseline_qualified"])
        self.assertEqual(result["ancestor_high_limit_certificate_sha256"], b.HL_CERTIFICATE_SHA)
        self.assertEqual(len(result["room_seals"]), 20)
        self.assertEqual(result["closed_build_phases"], 15)
        self.assertFalse(result["full_repository_archive"])
        self.assertEqual(result["native_export_original_code_files_equal"], 760)
        self.assertEqual(result["browser_acceptance"], "NOT_RUN")
        self.assertIn("current NEXT is not read", result["NEXT_scope"])
        cert = dict(result)
        fingerprint = cert.pop("certificate_sha256")
        self.assertEqual(b.canonical(cert), fingerprint)


if __name__ == "__main__":
    unittest.main(verbosity=2)
