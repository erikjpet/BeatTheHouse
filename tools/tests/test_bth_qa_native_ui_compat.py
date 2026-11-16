"""Exact audited-UI build bridge contracts; in-memory QA metadata only.

Install as tools/tests/test_bth_qa_native_ui_compat.py with the reviewed module
patch. This addendum imports fixture helpers, not the existing TestCase class,
so discovery does not rerun the original native tests under another name.
The stand-in UI digest below is synthetic and never authorizes a real build.
"""
from copy import deepcopy
from unittest.mock import patch
import unittest

import bth_qa_storage as g
import bth_qa_native_forward as n
import test_bth_qa_native_forward as base


class NativeUiCompatibilityTests(unittest.TestCase):
    owned_json = base.NativeForwardTests.owned_json
    file_hash = base.NativeForwardTests.file_hash
    plan = base.NativeForwardTests.plan
    rejected = base.NativeForwardTests.rejected
    prepared = base.NativeForwardTests.prepared
    release = base.NativeForwardTests.release
    good_job = base.NativeForwardTests.good_job
    good_campaign = staticmethod(base.NativeForwardTests.good_campaign)
    finish_case = base.NativeForwardTests.finish_case
    origin_documents = base.NativeForwardTests.origin_documents
    read_synthetic_origin = base.NativeForwardTests.read_synthetic_origin

    def setUp(self):
        base.NativeForwardTests.setUp(self)
        self.ui_digest = "a" * 64
        self.actual_digest = n.PRODUCT_DIGEST
        for name, value in (
            ("AUDITED_UI_PRODUCT_DIGEST", self.ui_digest),
            ("_current_product_digest", lambda: self.actual_digest),
        ):
            patcher = patch.object(n, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)

    def begin_case(self, run="crew-native-unit-01"):
        layout, started, job, campaign = base.NativeForwardTests.begin_case(self, run)
        job["storage"] = layout.as_dict()
        return layout, started, job, campaign

    def test_only_original_or_one_full_exact_ui_digest_is_admitted(self):
        for digest in (n.PRODUCT_DIGEST, self.ui_digest):
            with self.subTest(digest=digest):
                self.actual_digest = digest
                self.assertEqual(n._source_ok(self.commit), digest)
        for digest in ("b" * 64, self.ui_digest[:63], self.ui_digest.upper(),
                       self.ui_digest + "0", "", None):
            with self.subTest(rejected=digest):
                self.actual_digest = digest
                self.rejected(lambda: n._source_ok(self.commit), "native_product_changed")
        self.assertEqual(self.fs.writes, [])

    def test_unqualified_placeholder_cannot_admit_even_if_returned_as_current(self):
        placeholder = "UNQUALIFIED_UI_PRODUCT_DIGEST"
        with patch.object(n, "AUDITED_UI_PRODUCT_DIGEST", placeholder):
            self.actual_digest = placeholder
            self.rejected(lambda: n._source_ok(self.commit), "native_product_changed")
        self.assertEqual(self.fs.writes, [])

    def test_ui_plan_binds_actual_digest_without_rewriting_origin_or_custody(self):
        old_custody = deepcopy(self.records[g._key(self.custody)])
        old_bytes = n.receipt_bytes(old_custody)
        self.actual_digest = self.ui_digest
        layout = self.plan()
        self.assertEqual(layout.native_binding.product_inputs_sha256, self.ui_digest)
        self.assertEqual(layout.as_dict()["native_profile_binding"]["product_inputs_sha256"], self.ui_digest)
        self.assertEqual(n.receipt_bytes(self.records[g._key(self.custody)]), old_bytes)
        self.assertEqual(old_custody["product_inputs_sha256"], n.PRODUCT_DIGEST)
        self.assertEqual(self.origin_hashes, n.ORIGIN_HASHES)
        self.assertEqual(self.fs.writes, [])

    def test_allowed_build_drift_between_plan_and_prepare_still_rejects(self):
        for admitted, drifted in ((n.PRODUCT_DIGEST, self.ui_digest),
                                  (self.ui_digest, n.PRODUCT_DIGEST)):
            with self.subTest(admitted=admitted):
                self.actual_digest = admitted
                layout = self.plan()
                self.actual_digest = drifted
                self.rejected(lambda: g.prepare_layout(layout), "native_binding_changed")
        self.assertEqual(self.fs.writes, [])

    def test_allowed_build_drift_after_prepare_cannot_pass_launch_gate(self):
        layout = self.prepared()
        env = g.child_environment(layout, {})
        self.actual_digest = self.ui_digest
        self.rejected(lambda: g.check_launch(layout, layout.workspace, env), "native_binding_changed")
        self.assertIn(layout.token, n._leases)
        self.actual_digest = n.PRODUCT_DIGEST
        self.release(layout)

    def test_close_rejects_switching_to_either_other_allowed_build(self):
        for index, (admitted, drifted) in enumerate(((n.PRODUCT_DIGEST, self.ui_digest),
                                                    (self.ui_digest, n.PRODUCT_DIGEST))):
            with self.subTest(admitted=admitted):
                self.actual_digest = admitted
                layout, started, job, campaign = self.begin_case("crew-native-compat-close-%d" % index)
                inprogress = n.receipt_bytes(self.records[g._key(self.custody)])
                self.actual_digest = drifted
                self.rejected(lambda: n.close_record(layout.native_binding, started, job, campaign),
                              "native_product_changed")
                self.assertEqual(n.receipt_bytes(self.records[g._key(self.custody)]), inprogress)
                self.actual_digest = admitted
                self.finish_case(layout, started, job, campaign)

    def test_new_build_closes_and_readmits_while_historical_receipts_stay_exact(self):
        original = n.receipt_bytes(self.records[g._key(self.custody)])
        self.actual_digest = self.ui_digest
        layout, started, job, campaign = self.begin_case()
        archived = self.records[g._key(layout.evidence / "native-custody-before.json")]
        self.assertEqual(n.receipt_bytes(archived), original)
        closed = self.finish_case(layout, started, job, campaign)
        # Common persisted fields keep the origin identity. The case's actual
        # admitted digest is represented by its immutable native binding/job.
        self.assertEqual(closed["state"]["product_inputs_sha256"], n.PRODUCT_DIGEST)
        self.assertEqual(closed["custody"]["product_inputs_sha256"], n.PRODUCT_DIGEST)
        self.assertEqual(job["storage"]["native_profile_binding"]["product_inputs_sha256"], self.ui_digest)
        self.assertEqual(n.receipt_bytes(archived), original)
        new_layout = self.plan("crew-native-compat-next")
        self.assertEqual(new_layout.native_binding.product_inputs_sha256, self.ui_digest)
        self.actual_digest = n.PRODUCT_DIGEST
        restored = self.plan("crew-native-compat-original")
        self.assertEqual(restored.native_binding.product_inputs_sha256, n.PRODUCT_DIGEST)
        self.assertEqual(n.receipt_bytes(archived), original)

    def test_new_build_does_not_relax_origin_evidence_or_expected_head_checks(self):
        self.actual_digest = self.ui_digest
        documents = self.origin_documents()
        self.read_synthetic_origin(documents)
        documents["fresh-launch-result.json"]["product_inputs_after_sha256"] = self.ui_digest
        self.rejected(lambda: self.read_synthetic_origin(documents), "native_origin_identity")
        with patch.object(n, "_current_head", return_value="b" * 40):
            self.rejected(self.plan, "native_source_identity")
        self.assertEqual(self.fs.writes, [])


if __name__ == "__main__":
    unittest.main()
