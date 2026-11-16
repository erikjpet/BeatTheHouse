"""Private-inspection wrapper contracts; synthetic dictionaries only.

No campaign/key file is opened, no child is launched and no storage is prepared.
The public inspector's separately qualified Windows read locks are reused.
"""
from contextlib import redirect_stderr
from copy import deepcopy
from io import StringIO
import json
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import crew_cj2_private_inspection as inspection


CORRELATION_TRUE = (
    "supported_public_receipt_shapes", "closed_checkpoint_absent",
    "commands_absent", "outcomes_absent", "acknowledgements_absent",
    "pending_delivery_work_absent", "matches_inspected_prehandoff_receipts",
)
CORRELATION_FALSE = (
    "historical_observed_handoff_may_be_replayed",
    "economic_authority_proven_by_private_capsule",
)
PRIVATE_SCOPE = (
    "Existing explicit read-only key, current private capsule validation verdict "
    "and public receipt correlation only. No hidden payload, key, capsule or "
    "plaintext emitted; no restore/save/action/admission."
)


def public_fixture():
    owner = dict.fromkeys((
        "commands", "room_outcomes", "room_acknowledgements", "pending_outcomes",
        "owner_results", "registration_acknowledgements",
    ), 0)
    summary = {
        "cash": 151, "standing": 87, "duties": 2, "clock": 1230,
        "rng": "950800549", "action_index": 12, "node": "back_alley",
        "run_status": "active", "owners": [owner],
        "delivery": {
            "status": "active", "cargo_status": "carried",
            "closed_checkpoint_present": False,
        },
    }
    generation = {"binding_ok": True, "loadable_content": True, "summary": summary}
    public = {
        "ok": True, "failures": [], "main_instantiated": False,
        "run_state_instantiated": False, "private_authority_validated": False,
        "custody_recovery_authorized": False, "gameplay_authorized": False,
        "generations": {"primary": deepcopy(generation), "backup": deepcopy(generation)},
    }
    before = {
        str(path): {"dev": 1, "ino": index + 1, "size": 32 if path == inspection.KEY else 128,
                    "sha256": "a" * 64}
        for index, path in enumerate((inspection.KEY, inspection.PRIMARY, inspection.BACKUP))
    }
    preservation = {
        "before": before, "after": deepcopy(before),
        "original_profile_bytes_unchanged": True, "original_evidence_unchanged": True,
        "gameplay_admitted": False, "custody_sha256": inspection.i.CUSTODY_SHA,
        "directory_inventory": {"files": sorted(before), "directories": {}},
    }
    return public, preservation


def verdict_fixture():
    correlation = dict.fromkeys(CORRELATION_TRUE, True)
    correlation.update(dict.fromkeys(CORRELATION_FALSE, False))
    generation = {
        "exists": True, "content_supported": True, "supported": True,
        "valid": True, "error_code": "", "public_correlation": correlation,
    }
    return {
        "schema": "bth.qa_cj2_private_inspection/v1", "mode": "inspect", "ok": True,
        "failures": [], "generations": {"primary": deepcopy(generation), "backup": deepcopy(generation)},
        "main_instantiated": False, "run_state_instantiated": False,
        "key_installer_called": False, "original_handoff_replayed": False,
        "gameplay_authorized": False, "custody_recovery_authorized": False,
        "private_cache_unchanged": True, "scope": PRIVATE_SCOPE,
    }


class ArgumentTests(unittest.TestCase):
    def valid_args(self, mode="qualify"):
        args = ["--run-id", "crew-failed-qual-private-unit" if mode == "qualify" else "crew-failed-inspect-private-unit",
                "--expected-commit", "a" * 40, "--mode", mode,
                "--root-confirmed-no-owned-live-job"]
        if mode == "inspect": args += ["--qualification", "crew-failed-qual-private-unit"]
        return args

    def test_fixed_modes_parse_without_reading_or_preparing_storage(self):
        with patch.object(inspection.i.g, "prepare_layout", side_effect=AssertionError("unexpected preparation")), \
                patch.object(inspection.i, "sha", side_effect=AssertionError("unexpected file read")):
            for mode in ("qualify", "inspect"):
                result = inspection.parse_args(self.valid_args(mode))
                self.assertEqual(result.mode, mode)
                self.assertEqual(result.expected_commit, "a" * 40)
                self.assertTrue(result.root_confirmed_no_owned_live_job)

    def test_public_or_other_purpose_case_prefix_is_rejected(self):
        for mode, wrong in (("qualify", "crew-failed-qual-public-unit"), ("inspect", "crew-failed-inspect-public-unit")):
            args = self.valid_args(mode); args[1] = wrong
            with self.assertRaises(ValueError): inspection.parse_args(args)

    def test_inspection_cannot_consume_public_qualification(self):
        args = self.valid_args("inspect"); args[-1] = "crew-failed-qual-public-unit"
        with self.assertRaises(ValueError): inspection.parse_args(args)

    def test_input_key_profile_and_recovery_flags_remain_unavailable(self):
        for extra in (["--key", "E:/synthetic/key"], ["--primary", "E:/synthetic/run.json"],
                      ["--profile", "E:/synthetic/profile"], ["--recover"], ["--force"]):
            with redirect_stderr(StringIO()), self.assertRaises(SystemExit):
                inspection.parse_args(self.valid_args() + extra)


class PublicEvidenceTests(unittest.TestCase):
    def rejected(self, public, preservation):
        original = deepcopy((public, preservation))
        with self.assertRaises(ValueError): inspection.validate_public(public, preservation)
        self.assertEqual((public, preservation), original)

    def test_exact_synthetic_public_proof_is_read_only(self):
        public, preservation = public_fixture(); original = deepcopy((public, preservation))
        with patch.object(inspection.i, "sha", side_effect=AssertionError("unexpected file read")), \
                patch.object(inspection.i.g, "prepare_layout", side_effect=AssertionError("unexpected preparation")):
            inspection.validate_public(public, preservation)
        self.assertEqual((public, preservation), original)

    def test_inspection_and_preservation_boolean_proofs_are_typed(self):
        for field in ("ok", "main_instantiated", "run_state_instantiated", "private_authority_validated",
                      "custody_recovery_authorized", "gameplay_authorized"):
            for wrong in (None, 0, 1, "false"):
                public, preservation = public_fixture(); public[field] = wrong
                self.rejected(public, preservation)
        for field in ("original_profile_bytes_unchanged", "original_evidence_unchanged", "gameplay_admitted"):
            for wrong in (None, 0, 1, "true"):
                public, preservation = public_fixture(); preservation[field] = wrong
                self.rejected(public, preservation)

    def test_custody_hash_and_before_after_drift_are_rejected(self):
        public, preservation = public_fixture(); preservation["custody_sha256"] = "b" * 64
        self.rejected(public, preservation)
        for field, value in (("sha256", "b" * 64), ("ino", 999), ("size", 999)):
            public, preservation = public_fixture(); preservation["after"][str(inspection.PRIMARY)][field] = value
            self.rejected(public, preservation)

    def test_each_generation_and_its_input_binding_is_required(self):
        for kind in ("primary", "backup"):
            public, preservation = public_fixture(); del public["generations"][kind]
            self.rejected(public, preservation)
            for field in ("binding_ok", "loadable_content"):
                for wrong in (False, None, 0, 1, "true"):
                    public, preservation = public_fixture(); public["generations"][kind][field] = wrong
                    self.rejected(public, preservation)

    def test_public_accounting_clock_action_and_rng_cannot_drift_or_change_type(self):
        for kind in ("primary", "backup"):
            for field in ("cash", "standing", "duties", "clock", "action_index"):
                for wrong in (None, False, "151", 151.0, -1):
                    public, preservation = public_fixture(); public["generations"][kind]["summary"][field] = wrong
                    self.rejected(public, preservation)
            for wrong in (950800549, None, "950800550"):
                public, preservation = public_fixture(); public["generations"][kind]["summary"]["rng"] = wrong
                self.rejected(public, preservation)

    def test_active_carried_unsettled_delivery_and_one_owner_are_required(self):
        for field, wrong in (("status", "resolved"), ("cargo_status", "delivered"),
                             ("closed_checkpoint_present", True), ("closed_checkpoint_present", 0)):
            public, preservation = public_fixture(); public["generations"]["primary"]["summary"]["delivery"][field] = wrong
            self.rejected(public, preservation)
        for owners in ([], None, {}, [dict.fromkeys(("commands",), 0)] * 2):
            public, preservation = public_fixture(); public["generations"]["primary"]["summary"]["owners"] = owners
            self.rejected(public, preservation)

    def test_all_six_journal_counts_require_integer_zero(self):
        for kind in ("primary", "backup"):
            for field in ("commands", "room_outcomes", "room_acknowledgements", "pending_outcomes",
                          "owner_results", "registration_acknowledgements"):
                for wrong in (None, False, 0.0, "0", 1):
                    public, preservation = public_fixture(); public["generations"][kind]["summary"]["owners"][0][field] = wrong
                    self.rejected(public, preservation)

    def test_existing_key_metadata_requires_exact_integer_32_bytes(self):
        for wrong in (None, False, 32.0, "32", 0, 31, 33):
            public, preservation = public_fixture()
            preservation["before"][str(inspection.KEY)]["size"] = wrong
            preservation["after"][str(inspection.KEY)]["size"] = wrong
            self.rejected(public, preservation)
        public, preservation = public_fixture()
        del preservation["before"][str(inspection.KEY)]; del preservation["after"][str(inspection.KEY)]
        self.rejected(public, preservation)


class VerdictContractTests(unittest.TestCase):
    def rejected(self, result):
        original = deepcopy(result)
        with self.assertRaises(ValueError): inspection.verdict_contract(result)
        self.assertEqual(result, original)

    def test_valid_verdict_is_accepted_without_mutation_or_file_reads(self):
        result = verdict_fixture(); original = deepcopy(result)
        with patch.object(inspection.i, "sha", side_effect=AssertionError("unexpected file read")):
            self.assertTrue(inspection.verdict_contract(result))
        self.assertEqual(result, original)

    def test_invalid_or_unsupported_authority_is_a_false_verdict_never_admission(self):
        result = verdict_fixture(); result["generations"]["primary"].update(valid=False, error_code="private_validation_failed")
        self.assertFalse(inspection.verdict_contract(result))
        result = verdict_fixture(); result["generations"]["backup"].update(supported=False, valid=False, error_code="unsupported_private_shape")
        self.assertFalse(inspection.verdict_contract(result))

    def test_result_identity_and_all_no_action_flags_are_exact(self):
        for field, wrong in (("schema", "other/v1"), ("mode", "qualify"), ("ok", 1),
                             ("failures", ["synthetic_failure"]), ("private_cache_unchanged", False),
                             ("private_cache_unchanged", 1)):
            result = verdict_fixture(); result[field] = wrong; self.rejected(result)
        for field in ("main_instantiated", "run_state_instantiated", "key_installer_called",
                      "original_handoff_replayed", "gameplay_authorized", "custody_recovery_authorized"):
            for wrong in (True, 0, 1, None):
                result = verdict_fixture(); result[field] = wrong; self.rejected(result)

    def test_private_payload_or_unknown_fields_cannot_escape_any_level(self):
        result = verdict_fixture(); result["private_payload"] = "SYNTHETIC_DO_NOT_EMIT"; self.rejected(result)
        result = verdict_fixture(); result["generations"]["primary"]["private_payload"] = "SYNTHETIC_DO_NOT_EMIT"; self.rejected(result)
        result = verdict_fixture(); result["generations"]["primary"]["public_correlation"]["private_payload"] = "SYNTHETIC_DO_NOT_EMIT"; self.rejected(result)
        result = verdict_fixture(); result["scope"] = "SYNTHETIC_DO_NOT_EMIT"; self.rejected(result)

    def test_both_generations_and_each_verdict_field_are_required(self):
        for kind in ("primary", "backup"):
            result = verdict_fixture(); del result["generations"][kind]; self.rejected(result)
            for field in ("exists", "content_supported", "supported", "valid", "error_code", "public_correlation"):
                result = verdict_fixture(); del result["generations"][kind][field]; self.rejected(result)
        result = verdict_fixture(); result["generations"]["extra"] = {}; self.rejected(result)

    def test_verdict_booleans_and_error_code_are_not_coerced(self):
        for field in ("exists", "content_supported", "supported", "valid"):
            for wrong in (0, 1, "true", None):
                result = verdict_fixture(); result["generations"]["primary"][field] = wrong; self.rejected(result)
        for wrong in (None, [], 0, "SYNTHETIC_PRIVATE_DETAIL"):
            result = verdict_fixture(); result["generations"]["primary"]["error_code"] = wrong; self.rejected(result)

    def test_public_correlation_is_typed_and_cannot_grant_replay_or_economic_authority(self):
        for field in CORRELATION_TRUE + CORRELATION_FALSE:
            for wrong in (None, 0, 1, "false"):
                result = verdict_fixture(); result["generations"]["primary"]["public_correlation"][field] = wrong; self.rejected(result)
        for field in CORRELATION_FALSE:
            result = verdict_fixture(); result["generations"]["primary"]["public_correlation"][field] = True; self.rejected(result)
        result = verdict_fixture(); result["generations"]["primary"]["public_correlation"] = {}; self.rejected(result)

    def test_unsupported_unreadable_generation_can_return_only_an_empty_correlation(self):
        result = verdict_fixture()
        result["generations"]["backup"].update(exists=False, content_supported=False, supported=False,
                                               valid=False, public_correlation={}, error_code="input_absent")
        self.assertFalse(inspection.verdict_contract(result))

    def test_valid_authority_cannot_have_an_impossible_generation_state(self):
        for field in ("exists", "content_supported", "supported"):
            result = verdict_fixture(); result["generations"]["primary"][field] = False; self.rejected(result)
        result = verdict_fixture(); result["generations"]["primary"]["error_code"] = "private_validation_failed"; self.rejected(result)


class SourceAndEarlyGateTests(unittest.TestCase):
    def test_source_binding_includes_all_three_private_components(self):
        base = {"synthetic_common_guard": "a" * 64}
        with patch.object(inspection.i, "validate_source", return_value=base.copy()) as validate, \
                patch.object(inspection.i, "sha", return_value="b" * 64):
            bound = inspection.source_files("c" * 40)
        validate.assert_called_once_with("c" * 40)
        self.assertEqual(bound, dict(base, **{name: "b" * 64 for name in inspection.EXTRA_SOURCES}))
        self.assertEqual(base, {"synthetic_common_guard": "a" * 64})

    def test_wrong_qualification_purpose_stops_before_any_input_hash_or_mutex(self):
        args = SimpleNamespace(qualification="crew-failed-qual-private-unit")
        with patch.object(inspection.i, "verify_qualification"), \
                patch.object(inspection.i.n, "_owned_json", return_value=({"purpose": "public_inspection"}, "a" * 64)), \
                patch.object(inspection.i, "sha", side_effect=AssertionError("unexpected input read")), \
                patch.object(inspection.i.n, "_mutex_acquire", side_effect=AssertionError("unexpected mutex acquisition")):
            with self.assertRaises(ValueError): inspection.inspect(args, None, {})

    def test_receipt_hash_drift_stops_before_reading_original_inputs_or_taking_mutex(self):
        args = SimpleNamespace(qualification="crew-failed-qual-private-unit")
        with patch.object(inspection.i, "verify_qualification"), \
                patch.object(inspection.i.n, "_owned_json", return_value=({"purpose": "private_authority_verdict_only"}, "a" * 64)), \
                patch.object(inspection.i, "sha", return_value="0" * 64), \
                patch.object(Path, "read_text", side_effect=AssertionError("unexpected input read")), \
                patch.object(inspection.i.n, "_mutex_acquire", side_effect=AssertionError("unexpected mutex acquisition")):
            with self.assertRaises(ValueError): inspection.inspect(args, None, {})

    def test_reused_closure_gate_requires_typed_zero_after_construction(self):
        self.assertTrue(inspection.i.closure_proven(None, False))
        for receipt in (None, {}, {"active_at_release": False}, {"active_at_release": 0.0}, {"active_at_release": 1}):
            self.assertFalse(inspection.i.closure_proven(receipt, True))
        self.assertTrue(inspection.i.closure_proven({"active_at_release": 0}, True))


if __name__ == "__main__":
    unittest.main()
