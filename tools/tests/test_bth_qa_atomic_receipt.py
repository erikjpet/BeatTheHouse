"""Synthetic admitted-temp receipts only; never edits campaign or profile data."""
from pathlib import Path
import json
import sys
import tempfile
import unittest
from unittest.mock import Mock
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import bth_qa_atomic_receipt as atomic

TOKEN="a"*32

def win_error(code):
    error=OSError("synthetic Windows receipt failure")
    error.winerror=code
    return error

class AtomicReceiptTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix="atomic-receipt-unit-")
        self.addCleanup(self.temp.cleanup)
        self.path=Path(self.temp.name)/"receipt.json"

    def pending(self):
        return list(self.path.parent.glob("*.pending"))

    def test_atomic_install_and_replace_leave_valid_json_and_no_pending(self):
        atomic.atomic_json(self.path,{"first":True},TOKEN)
        atomic.atomic_json(self.path,{"second":[1,2]},TOKEN)
        self.assertEqual(json.loads(self.path.read_text()),{"second":[1,2]})
        self.assertEqual(self.pending(),[])

    def test_invalid_contract_rejects_before_writes(self):
        for path,token,timeout in [(self.path,"bad",.75),(self.path.with_suffix(".txt"),TOKEN,.75),
                                   (self.path,TOKEN,0),(self.path,TOKEN,2)]:
            with self.subTest(path=path,token=token,timeout=timeout):
                with self.assertRaises(ValueError):atomic.atomic_json(path,{},token,timeout_seconds=timeout)
                self.assertEqual(list(self.path.parent.iterdir()),[])
        with self.assertRaises(ValueError):atomic.atomic_json(self.path,{"large":"x"*atomic.MAX_BYTES},TOKEN)
        self.assertEqual(list(self.path.parent.iterdir()),[])

    def test_transient_sharing_violation_retries_same_pending_file(self):
        original=atomic.os.replace
        calls=[]
        def replace(source,target):
            calls.append((source,target))
            if len(calls)==1:raise win_error(32)
            original(source,target)
        atomic.atomic_json(self.path,{"valid":True},TOKEN,_replace=replace,_sleep=lambda n:None)
        self.assertEqual(len(calls),2)
        self.assertEqual(calls[0],calls[1])
        self.assertTrue(json.loads(self.path.read_text())["valid"])

    def test_other_errors_preserve_previous_receipt_and_pending_diagnostic(self):
        self.path.write_text('{"previous":true}')
        for code in (2,87):
            with self.subTest(code=code):
                replace=Mock(side_effect=win_error(code))
                with self.assertRaises(OSError) as caught:
                    atomic.atomic_json(self.path,{"new":True},TOKEN,_replace=replace)
                self.assertEqual(replace.call_count,1)
                self.assertTrue(Path(caught.exception.qa_pending_path).is_file())
                self.assertEqual(json.loads(self.path.read_text()),{"previous":True})

    def test_access_denial_with_failed_probe_is_never_retried(self):
        self.path.write_text("{}")
        replace=Mock(side_effect=win_error(5))
        with self.assertRaises(OSError):
            atomic.atomic_json(self.path,{},TOKEN,_replace=replace,_probe=lambda p:5)
        self.assertEqual(replace.call_count,1)

    def test_readonly_receipt_is_never_retried(self):
        self.path.write_text("{}")
        self.path.chmod(0o444)
        try:
            replace=Mock(side_effect=win_error(5));probe=Mock(return_value=0)
            with self.assertRaises(OSError):
                atomic.atomic_json(self.path,{},TOKEN,_replace=replace,_probe=probe)
            self.assertEqual(replace.call_count,1);probe.assert_not_called()
        finally:self.path.chmod(0o666)

    def test_transient_access_denial_requires_all_permission_probes(self):
        self.path.write_text("{}")
        original=atomic.os.replace;replace=Mock(side_effect=[win_error(5),None])
        def attempt(source,target):
            if replace.call_count==0:return replace(source,target)
            replace(source,target);original(source,target)
        probe=Mock(return_value=0)
        atomic.atomic_json(self.path,{"done":True},TOKEN,_replace=attempt,_probe=probe,_sleep=lambda n:None)
        self.assertEqual(probe.call_count,3)
        self.assertEqual(json.loads(self.path.read_text()),{"done":True})

    def test_attempt_count_remains_bounded_even_with_frozen_clock(self):
        replace=Mock(side_effect=win_error(33))
        with self.assertRaises(OSError):
            atomic.atomic_json(self.path,{},TOKEN,_replace=replace,_now=lambda:0,_sleep=lambda n:None)
        self.assertEqual(replace.call_count,32)
        self.assertEqual(len(self.pending()),1)

    def test_deadline_stops_retry_without_modifying_previous_receipt(self):
        self.path.write_text("{}")
        replace=Mock(side_effect=win_error(32))
        with self.assertRaises(OSError):
            atomic.atomic_json(self.path,{},TOKEN,_replace=replace,_now=Mock(side_effect=[0,1]))
        self.assertEqual(replace.call_count,1)
        self.assertEqual(self.path.read_text(),"{}")

if __name__=="__main__":unittest.main()
