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



class NativeFixedModeCliTests(unittest.TestCase):
    BASE = ['--run-id', 'crew-native-cli-unit', '--expected-commit', 'a'*40,
            '--guards', 'crew-native-guards-unit', '--syntax', 'crew-native-syntax-unit',
            '--controls', 'crew-native-controls-unit', '--root-confirmed-no-duplicate-crew-job']
    MODES = ('travel-back-alley', 'handoff-back-alley', 'wait-recipient')

    def invoke(self, tail, via_main=False):
        import io, sys
        from contextlib import ExitStack, redirect_stderr
        import crew_cj2_native_forward as adapter
        with ExitStack() as stack:
            blocked = [stack.enter_context(patch.object(owner, name,
                       side_effect=AssertionError('CLI touched admission/runtime')))
                       for owner, name in ((adapter.g, 'plan_layout'), (adapter.g, 'prepare_layout'),
                           (adapter.native, 'bootstrap_custody'), (adapter, 'verify_qualification'),
                           (adapter, 'execute'))]
            stack.enter_context(redirect_stderr(io.StringIO()))
            try:
                if via_main:
                    stack.enter_context(patch.object(sys, 'argv', ['native.py'] + self.BASE + tail))
                    return adapter.main()
                return adapter.parse_args(self.BASE + tail)
            finally:
                for mocked in blocked: mocked.assert_not_called()

    def rejects(self, tail, via_main=False):
        with self.assertRaises(SystemExit) as caught: self.invoke(tail, via_main)
        self.assertEqual(caught.exception.code, 2)

    def test_fixed_and_legacy_modes_parse_without_io(self):
        for mode in self.MODES + ('inspect', 'wait', 'interact', 'respond'):
            with self.subTest(mode=mode): self.assertEqual(self.invoke(['--mode', mode]).mode, mode)

    def test_fixed_modes_reject_unrelated_control_overrides(self):
        for mode in self.MODES:
            for flag, value in (('--object-id', 'travel:back_alley'), ('--event-id', 'crew_favor_delivery'), ('--choice-id', 'run_package')):
                with self.subTest(mode=mode, flag=flag): self.rejects(['--mode', mode, flag, value])

    def test_unknown_modes_profile_target_slot_cap_and_seed_overrides_rejected(self):
        for tail in (['--mode', 'travel-anywhere'], ['--mode', 'travel-back-alley', '--target-id', 'back_alley'],
                     ['--mo', 'travel-back-alley'], ['--profile', 'E:/foreign'], ['--autosave-slot', 'FOREIGN'], ['--timeout', '300'], ['--seed', 'picked']):
            with self.subTest(tail=tail): self.rejects(tail)

    def test_duplicate_flags_including_equals_forms_rejected(self):
        for tail in (['--mode', 'inspect', '--mode', 'travel-back-alley'],
                     ['--mode=inspect', '--mode=handoff-back-alley'], ['--run-id', 'crew-native-other']):
            with self.subTest(tail=tail): self.rejects(tail)

    def test_wait_bounds(self):
        for seconds in ('1', '90'): self.assertEqual(self.invoke(['--mode', 'wait-recipient', '--wait-seconds', seconds]).wait_seconds, int(seconds))
        for seconds in ('0', '91', '1.5'): self.rejects(['--mode', 'wait-recipient', '--wait-seconds', seconds])

    def test_invalid_main_rejects_before_any_admission_or_custody(self):
        self.rejects(['--mode', 'handoff-back-alley', '--object-id', 'foreign'], via_main=True)

    def test_full_exact_source_required_without_io(self):
        import crew_cj2_native_forward as adapter
        import io
        from contextlib import redirect_stderr
        for value in ('a'*39, 'a'*41, 'A'*40, 'g'*40):
            tokens = list(self.BASE); tokens[tokens.index('--expected-commit') + 1] = value
            with redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught: adapter.parse_args(tokens)
            self.assertEqual(caught.exception.code, 2)



class NativeContactCompatibilityTests(unittest.TestCase):
    owned_json = NativeUiCompatibilityTests.owned_json
    file_hash = NativeUiCompatibilityTests.file_hash
    plan = NativeUiCompatibilityTests.plan
    rejected = NativeUiCompatibilityTests.rejected
    prepared = NativeUiCompatibilityTests.prepared
    release = NativeUiCompatibilityTests.release
    good_job = NativeUiCompatibilityTests.good_job
    good_campaign = staticmethod(NativeUiCompatibilityTests.good_campaign)
    finish_case = NativeUiCompatibilityTests.finish_case
    origin_documents = NativeUiCompatibilityTests.origin_documents
    read_synthetic_origin = NativeUiCompatibilityTests.read_synthetic_origin
    begin_case = NativeUiCompatibilityTests.begin_case

    def setUp(self):
        NativeUiCompatibilityTests.setUp(self)
        self.contact_digest = 'c' * 64
        patcher = patch.object(n, 'AUDITED_CONTACT_PRODUCT_DIGEST', self.contact_digest)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_failed_custody_cannot_admit_or_bootstrap_on_any_known_build(self):
        record = self.records[g._key(self.custody)]
        record["status"] = "CASE_FAILED"
        original = n.receipt_bytes(record)
        for digest in (n.PRODUCT_DIGEST, self.ui_digest, self.contact_digest):
            self.actual_digest = digest
            self.rejected(self.plan, "native_not_closed")
            self.assertEqual(n.receipt_bytes(record), original)
        self.fs.entries[g._key(self.custody)] = "file"
        with patch.object(n, "_current_head", side_effect=AssertionError("unexpected source read")):
            self.rejected(lambda: n.bootstrap_custody(self.commit), "native_bootstrap_occupied")
        self.assertEqual(n.receipt_bytes(record), original)
        self.assertEqual(self.fs.writes, [])

    def test_three_exact_builds_admit_unknown_or_malformed_reject_without_writes(self):
        for value in (n.PRODUCT_DIGEST, self.ui_digest, self.contact_digest):
            self.actual_digest = value
            self.assertEqual(n._source_ok(self.commit), value)
        for value in ('d'*64, 'c'*63, 'C'*64, 'c'*65, '', None):
            self.actual_digest = value
            self.rejected(lambda: n._source_ok(self.commit), 'native_product_changed')
        self.assertEqual(self.fs.writes, [])

    def test_contact_plan_binds_current_build_without_rewriting_origin_or_history(self):
        old = n.receipt_bytes(self.records[g._key(self.custody)])
        self.actual_digest = self.contact_digest
        layout = self.plan()
        self.assertEqual(layout.native_binding.product_inputs_sha256, self.contact_digest)
        self.assertEqual(layout.native_binding.autosave_slot, n.SLOT)
        self.assertEqual(dict(layout.native_binding.persistent_paths), n._paths())
        self.assertEqual(n.receipt_bytes(self.records[g._key(self.custody)]), old)
        self.assertEqual(self.origin_hashes, n.ORIGIN_HASHES)
        self.assertEqual(self.fs.writes, [])

    def test_all_six_allowed_build_switches_after_plan_reject_before_prepare(self):
        builds = (n.PRODUCT_DIGEST, self.ui_digest, self.contact_digest)
        for i, admitted in enumerate(builds):
            for j, drifted in enumerate(builds):
                if admitted == drifted: continue
                self.actual_digest = admitted
                layout = self.plan('crew-native-contact-plan-%d-%d' % (i, j))
                self.actual_digest = drifted
                self.rejected(lambda: g.prepare_layout(layout), 'native_binding_changed')
        self.assertEqual(self.fs.writes, [])

    def test_all_six_allowed_build_switches_at_close_reject_and_preserve_custody(self):
        builds = (n.PRODUCT_DIGEST, self.ui_digest, self.contact_digest)
        for i, admitted in enumerate(builds):
            for j, drifted in enumerate(builds):
                if admitted == drifted: continue
                self.actual_digest = admitted
                layout, started, job, campaign = self.begin_case('crew-native-contact-close-%d-%d' % (i, j))
                old = n.receipt_bytes(self.records[g._key(self.custody)])
                self.actual_digest = drifted
                self.rejected(lambda: n.close_record(layout.native_binding, started, job, campaign), 'native_product_changed')
                self.assertEqual(n.receipt_bytes(self.records[g._key(self.custody)]), old)
                self.actual_digest = admitted
                self.finish_case(layout, started, job, campaign)

    def test_contact_closes_and_readmits_without_rewriting_archived_predecessor(self):
        original = n.receipt_bytes(self.records[g._key(self.custody)])
        self.actual_digest = self.contact_digest
        layout, started, job, campaign = self.begin_case('crew-native-contact-forward')
        archive = self.records[g._key(layout.evidence / 'native-custody-before.json')]
        self.assertEqual(n.receipt_bytes(archive), original)
        closed = self.finish_case(layout, started, job, campaign)
        self.assertEqual(closed['custody']['product_inputs_sha256'], n.PRODUCT_DIGEST)
        self.assertEqual(closed['state']['product_inputs_sha256'], n.PRODUCT_DIGEST)
        self.assertEqual(job['storage']['native_profile_binding']['product_inputs_sha256'], self.contact_digest)
        self.assertEqual(n.receipt_bytes(archive), original)
        self.assertEqual(self.plan('crew-native-contact-next').native_binding.product_inputs_sha256, self.contact_digest)


if __name__ == "__main__":
    unittest.main()
