"""Offline proof-boundary checks; does not read retained QA campaign evidence."""
from pathlib import Path
import ast
import sys
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import bth_qa_storage as guard
import bth_qa_closed_inspection as closed
import bth_qa_crash_inspection as crash
import bth_qa_paid_trip_inspection as trip

POLICIES=(closed,crash,trip)

class RecoveryPolicyTests(unittest.TestCase):
    def scope(self,policy):
        return [policy.APPROVED_ROOT,policy.ROOT,policy.NEXT,
                policy.ROOT/"qa-resident-profiles"/policy.CAMPAIGN,
                policy.ROOT/"evidence"/(policy.CAMPAIGN+"-custody.json"),
                policy.CAMPAIGN,policy.ORIGIN,policy.COMMIT,policy.POLICY]

    def test_scope_accepts_only_each_exact_frozen_identity(self):
        for policy in POLICIES:
            args=self.scope(policy);policy.validate_scope(*args)
            for index in range(len(args)):
                bad=list(args);bad[index]=str(bad[index])+"-different"
                with self.subTest(policy=policy.POLICY,field=index):
                    with self.assertRaises(guard.StorageGuardError):policy.validate_scope(*bad)

    def test_fingerprint_changes_and_missing_evidence_fail_closed(self):
        for policy in POLICIES:
            pins=dict(getattr(policy,"FINGERPRINTS",getattr(policy,"EXPECTED",{})))
            policy.verify_fingerprints(pins)
            for altered in ({},dict(pins,**{next(iter(pins)):"0"*64})):
                with self.subTest(policy=policy.POLICY):
                    with self.assertRaises(guard.StorageGuardError):policy.verify_fingerprints(altered)

    def test_recovery_commands_close_once_and_never_contain_a_paid_intent(self):
        for policy in POLICIES:
            command=policy.recovery_command()
            self.assertEqual(command["intent"],"checkpoint_close")
            self.assertEqual(command["actions"][-1],{"type":"close"})
            self.assertEqual(sum(a["type"]=="close" for a in command["actions"]),1)

    def test_wrong_controller_seams_or_pinned_source_reject(self):
        for policy in POLICIES:
            with self.subTest(policy=policy.POLICY):
                with self.assertRaises(guard.StorageGuardError):policy.constrain_controller("unrelated controller")
        with self.assertRaises(guard.StorageGuardError):
            trip.constrain_controller("const state={}; function validate(c){}")

    def test_closed_controller_inserts_single_early_command_gate(self):
        source="const state={}; function validate(c){}"
        for policy in (closed,crash):
            result=policy.constrain_controller(source)
            self.assertIn("RECOVERY_SINGLE_EARLY_COMMAND_ONLY",result)
            self.assertIn("RECOVERY_EXACT_COLD_CLOSE_ONLY",result)
            self.assertIn(policy.POLICY,result)

    def test_paid_trip_screenshot_read_remains_bounded_after_stat(self):
        tree=ast.parse(Path(trip.__file__).read_text(encoding="utf-8"))
        review=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=="review_success")
        reads=[n for n in ast.walk(review) if isinstance(n,ast.Call) and isinstance(n.func,ast.Attribute) and n.func.attr=="read"]
        self.assertEqual(len(reads),1)
        self.assertEqual(ast.dump(reads[0].args[0]),ast.dump(ast.parse("8*1024**2+1",mode="eval").body))
        self.assertFalse(any(isinstance(n,ast.Call) and isinstance(n.func,ast.Attribute) and n.func.attr=="read_bytes" for n in ast.walk(review)))

if __name__=="__main__":unittest.main()
