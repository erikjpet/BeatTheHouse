"""Apartment source-only assembly regressions; root runs in a fresh capped Job.

All fixtures are immutable reads or in-memory images/mocks. No child, output,
profile, directory, save, image generation or QA campaign is created by tests.
"""
import sys
sys.dont_write_bytecode = True

from copy import deepcopy
from io import BytesIO
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import assemble_apartment_spatial_candidate as recipe


class ActualApartmentSources(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original,cls.raw,cls.custody = recipe.inputs(recipe.SOURCE_ROOT)
        cls.candidate,cls.ledger = recipe.assemble(cls.original,cls.raw)
        cls.proof = recipe.verify_pixels(cls.original,cls.candidate,cls.raw,cls.ledger)

    def test_exact16_room_sources_and_separate_index(self):
        self.assertEqual(len(recipe.PAYLOAD),16)
        self.assertNotIn(recipe.INDEX,recipe.PAYLOAD)
        self.assertEqual(recipe.seal(recipe.PAYLOAD),recipe.BASELINE_SEAL)
        self.assertEqual(self.custody["index_separate_sha256"],recipe.INDEX_SHA)

    def test_actual_D_E_B64_and_Library_closed_decoder_custody(self):
        raw,custody = recipe.raw_custody(recipe.SOURCE_ROOT)
        self.assertEqual(recipe.sha(raw),recipe.RAW_SHA)
        self.assertEqual(len(raw),1817231)
        self.assertEqual(custody["Library"]["current_version_number"],0)
        self.assertEqual(custody["decoder_job_sha256"],
            "9bd2f9df26c06684b64c3f2e3768b1b90697cd21e211f52ef45bab1e5106ae86")
        self.assertFalse(custody["historical_kitty_failure_relabelled"])

    def test_actual_retained_Base_only14_typed_masks(self):
        self.assertEqual(len(self.custody["retained_masks"]),14)
        self.assertEqual(self.custody["retained_mask_seal"],
            "b80be5f6b0259aef03ca636d75e527e53555d3d5a15d3ab574a29bbf1ad56635")
        self.assertIn("Base only",self.custody["retained_scope"])

    def test_full14_motion_JSON_defaultlow_and_zero_replays_unchanged(self):
        manifest = recipe.read_json(recipe.SOURCE_ROOT/recipe.MANIFEST)
        self.assertEqual(len(manifest["animations"]),14)
        self.assertTrue(all(row["web_low_detail"] is True for row in manifest["animations"]))
        self.assertEqual(manifest["counters"],{})
        self.assertEqual(sum(name.endswith(".png") for name in recipe.PAYLOAD),15)

    def test_original_material_masks_are_actual_runs_not_brick_boxes(self):
        for x,y in ((652,428),(675,443),(1044,442),(1067,443),
                    (1178,430),(1191,431),(1148,432),(1223,451),(1252,428),(1697,451)):
            self.assertTrue(recipe.protected(x,y),(x,y))
        for x,y in ((676,440),(1043,440),(652,444),(1146,448),(1224,448),
                    (1698,450),(1300,452),(700,428),(100,480)):
            self.assertFalse(recipe.protected(x,y),(x,y))

    def test_exact_patch_and_preserved_material_area(self):
        self.assertEqual(len(self.ledger),25538)
        self.assertEqual(self.proof["writable_pixels"],102152)
        self.assertEqual(self.proof["protected_material_pixels"],13048)
        self.assertEqual(102152+13048,1800*64)
        self.assertTrue(self.proof["outside_exact_union_equal"])

    def test_all_original_material_and_contact_solids_are_byte_exact(self):
        for y0,y1,runs in recipe.PROTECTED:
            for y in range(y0,y1):
                for left,right in runs:
                    a=(y*1800+left)*4;b=(y*1800+right)*4
                    self.assertEqual(self.original.rgba[a:b],self.candidate.rgba[a:b])

    def test_all492plus_and_upper_room_original(self):
        self.assertEqual(self.original.rgba[:428*7200],self.candidate.rgba[:428*7200])
        self.assertEqual(self.original.rgba[492*7200:],self.candidate.rgba[492*7200:])
        self.assertTrue(self.proof["all_rows492_onward_identical"])

    def test_each_cell_is_one_exact_opaque_donor_pixel_NN2(self):
        for row in self.ledger:
            x,y=row["target_2x2"];sx,sy=row["source_pixel"]
            source=self.original if row["source"]=="original_floor_join" else self.raw
            color=recipe.pixel(source,sx,sy)
            self.assertEqual(bytes(row["RGBA"]),color)
            self.assertEqual(color[3],255)
            for dx,dy in ((0,0),(1,0),(0,1),(1,1)):
                self.assertEqual(recipe.pixel(self.candidate,x+dx,y+dy),color)

    def test_raw_floor_never_uses_raw_support_tails_or_rug(self):
        floor=[row for row in self.ledger if row["source"]=="raw_floor"]
        self.assertTrue(floor)
        self.assertTrue(all(recipe.raw_floor_eligible(*row["source_pixel"]) for row in floor))
        self.assertTrue(all(448<=row["source_pixel"][1]<494 for row in floor))
        for left,top,width,height in recipe.RAW_SUPPORT_ROIS:
            self.assertFalse(recipe.raw_floor_eligible(left+width//2,448))
        self.assertFalse(recipe.raw_floor_eligible(900,494))

    def test_raw_skirting_uses_actual_quiet_trim_only(self):
        rows=[row for row in self.ledger if row["source"]=="raw_skirting"]
        self.assertTrue(rows)
        self.assertEqual({row["source_pixel"][1] for row in rows},set(recipe.SKIRT_Y))
        self.assertTrue(all(row["source_pixel"][0]<580 or row["source_pixel"][0]>=1730 for row in rows))
        self.assertTrue(all(428<=row["target_2x2"][1]<440 for row in rows))

    def test_floor_donor_rows_preserve_bounded_near_phase(self):
        self.assertEqual(recipe.donor(400,220)[2],448)
        self.assertEqual(recipe.donor(400,245)[2],493)
        ys=[recipe.donor(400,by)[2] for by in range(220,246)]
        self.assertEqual(ys,sorted(ys))
        self.assertLessEqual(max(ys[i+1]-ys[i] for i in range(len(ys)-1)),2)

    def test_narrow_same_column_join_never_pulls_rug_up(self):
        joins=[row for row in self.ledger if row["source"]=="original_floor_join"]
        self.assertEqual(len(joins),526)
        for row in joins:
            x,y=row["target_2x2"]
            self.assertEqual(y,490)
            self.assertTrue(x<520 or x>=1268)
            self.assertEqual(row["source_pixel"],[x,492])
        self.assertEqual(recipe.donor(260,245)[0],"raw_floor")
        self.assertEqual(recipe.donor(633,245)[0],"raw_floor")
        self.assertEqual(recipe.donor(634,245)[0],"original_floor_join")

    def test_closest_same_row_rejection_donor_stays_eligible(self):
        # A displaced raw foot tail is rejected even when original foot ended.
        kind,sx,sy=recipe.donor(330,222)
        self.assertEqual(kind,"raw_floor")
        self.assertTrue(recipe.raw_floor_eligible(sx,sy))
        self.assertFalse(640<=sx<708)
        self.assertEqual(sy,452)

    def test_mask_has_no_outside_or_original_fixture_cells(self):
        for bx,by in ((-1,220),(900,220),(100,213),(100,246),(326,214),(626,225)):
            self.assertFalse(recipe.mask_cell(bx,by))
            with self.assertRaises(ValueError):recipe.donor(bx,by)

    def test_missing_duplicate_wrong_donor_or_outside_pixels_rejected(self):
        with self.assertRaisesRegex(ValueError,"25538"):
            recipe.verify_pixels(self.original,self.candidate,self.raw,self.ledger[:-1])
        bad=deepcopy(self.ledger);bad[-1]=deepcopy(bad[0])
        with self.assertRaisesRegex(ValueError,"unique donor"):
            recipe.verify_pixels(self.original,self.candidate,self.raw,bad)
        bad=deepcopy(self.ledger);bad[0]["RGBA"][0]^=1
        with self.assertRaisesRegex(ValueError,"ledger"):
            recipe.verify_pixels(self.original,self.candidate,self.raw,bad)
        data=bytearray(self.candidate.rgba);data[0]^=1
        with self.assertRaisesRegex(ValueError,"Outside band"):
            recipe.verify_pixels(self.original,recipe.PNGImage(1800,860,bytes(data)),self.raw,self.ledger)

    def test_protected_material_mutation_is_rejected(self):
        data=bytearray(self.candidate.rgba);data[(442*1800+652)*4]^=1
        with self.assertRaisesRegex(ValueError,"MATERIAL"):
            recipe.verify_pixels(self.original,recipe.PNGImage(1800,860,bytes(data)),self.raw,self.ledger)

    def test_exact_candidate_encoding_is_lossless_RAM_only(self):
        encoded=recipe.encode_png(self.candidate)
        self.assertEqual(recipe.decode_png(encoded),self.candidate)

    def test_source_hash_change_rejected_before_assembly(self):
        original_read=recipe.read
        def changed(path,*args,**kwargs):
            data=original_read(path,*args,**kwargs)
            return data+b"x" if Path(path)==recipe.SOURCE_ROOT/recipe.BACKGROUND else data
        with patch.object(recipe,"read",side_effect=changed):
            with self.assertRaisesRegex(ValueError,"Pinned Apartment"):recipe.inputs(recipe.SOURCE_ROOT)

    def test_kitchen_strip_and_room_acceptance_explicitly_open(self):
        plan=recipe.read_json(recipe.SOURCE_ROOT/recipe.ARTIFACT/"assembly-plan.json")
        self.assertIn("OPEN",plan["immutable"]["kitchen_strip_material_disposition"])
        self.assertFalse(plan["native_trial_approved"])
        self.assertFalse(plan["production_activation_approved"])
        self.assertFalse(self.proof["visual_seams_or_native_clearance_approved"])


class StorageAndReceiptContracts(unittest.TestCase):
    @staticmethod
    def layout():
        return SimpleNamespace(prepared=True,root=recipe.QA_ROOT,workspace=recipe.WORKSPACE,
            evidence=recipe.QA_ROOT/"runs/apartment-assembly-unit-fixture/evidence",
            expected_write_bytes=4*1024**3,reserve_bytes=20*1024**3)

    def test_directory_only_gate_and_exact_budget(self):
        layout=self.layout();paths=(recipe.WORKSPACE/"source_baseline",layout.evidence)
        with patch.object(recipe,"validate_layout") as check:
            recipe.gate(layout,paths)
        self.assertEqual(check.call_args.kwargs["extra_write_paths"],paths)
        for name,value in (("prepared",False),("reserve_bytes",0),("expected_write_bytes",3*1024**3)):
            bad=self.layout();setattr(bad,name,value)
            with self.subTest(name=name),self.assertRaises(ValueError):recipe.gate(bad,paths)

    def test_existing_PNG_never_enters_directory_gate(self):
        with patch.object(recipe,"validate_layout") as check:
            with self.assertRaisesRegex(ValueError,"Directory parents"):
                recipe.gate(self.layout(),(recipe.WORKSPACE/"raw_source/apartment-spatial-r1.png",))
        check.assert_not_called()

    def test_C_and_foreign_workspace_rejected(self):
        for path in (Path("C:/CodexQA/fixture"),recipe.QA_ROOT/"workspaces/foreign"):
            with self.subTest(path=str(path)),self.assertRaises(ValueError):recipe.gate(self.layout(),(path,))

    def test_exclusive_file_write_has_immediate_parent_gate(self):
        events=[];data=b"in-memory only"
        class Target:
            parent=object()
            def exists(self):return False
            def open(self,mode):
                events.append("open:"+mode)
                return BytesIO()
        target=Target()
        with patch.object(recipe,"plain",side_effect=lambda x:x), \
             patch.object(recipe,"ensure_parent",side_effect=lambda layout,parent:events.append("parents")), \
             patch.object(recipe,"gate",side_effect=lambda layout,paths:events.append("gate-parent")), \
             patch.object(recipe,"read",return_value=data):
            recipe.write_new(self.layout(),target,data)
        self.assertEqual(events,["parents","gate-parent","open:xb"])

    def test_preexisting_output_is_not_overwritten(self):
        target=SimpleNamespace(exists=lambda:True)
        with patch.object(recipe,"plain",return_value=target),patch.object(recipe,"gate") as check:
            with self.assertRaisesRegex(ValueError,"Never overwrite"):recipe.write_new(self.layout(),target,b"")
        check.assert_not_called()

    def test_actual_closed_decoder_accepts_absent_optional_drain_error(self):
        job=recipe.read_json(recipe.DECODE_EVIDENCE/"job.json")
        self.assertTrue(recipe.qualified_job(job))
        for value in (None,"fixture drain error"):
            altered=deepcopy(job);altered["log_error"]=value
            self.assertEqual(recipe.qualified_job(altered),value is None)

    def test_nonzero_active_caps_or_unassigned_receipt_rejected(self):
        job=recipe.read_json(recipe.DECODE_EVIDENCE/"job.json")
        for name,value in (("exit_code",1),("active_at_release",1),("assigned_before_execution",False)):
            altered=deepcopy(job);altered[name]=value
            with self.subTest(name=name):self.assertFalse(recipe.qualified_job(altered))
        altered=deepcopy(job);altered["limits"]["cpu_rate"]=10000
        self.assertFalse(recipe.qualified_job(altered))


if __name__ == "__main__":
    unittest.main()
