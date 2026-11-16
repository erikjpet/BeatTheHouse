"""Read-only/in-memory Kitty assembly regressions; root runs in capped Job.

No test creates files, children, QA layouts, profiles, images or temporary paths.
Actual PNGs and immutable failed-decode evidence are read-only test fixtures.
"""
import sys
sys.dont_write_bytecode=True

from copy import deepcopy
import hashlib
from io import BytesIO
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import assemble_kitty_spatial_candidate as recipe


class ActualSourceAndGeometry(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original,cls.raw,cls.audit,cls.custody=recipe.inputs(recipe.SOURCE_ROOT)
        cls.candidate,cls.ledger=recipe.assemble(cls.original,cls.raw)
        cls.rows=recipe.target_rows()
        cls.proof=recipe.verify_pixels(cls.original,cls.candidate,cls.raw,cls.ledger)

    def test_actual30_room_files_exclude_separate_global_index(self):
        self.assertEqual(len(recipe.PAYLOAD_PINS),30)
        self.assertNotIn(recipe.INDEX,recipe.PAYLOAD_PINS)
        self.assertEqual(recipe.seal(recipe.PAYLOAD_PINS),recipe.BASELINE_SEAL)
        self.assertEqual(self.custody["index_separate_sha256"],recipe.INDEX_SHA)

    def test_actual_generated_D_E_base64_identity_is_authenticated(self):
        raw=recipe.read(recipe.SOURCE_ROOT/recipe.SOURCE_DIRECTORY/"kitty-spatial-r1.png")
        self.assertEqual(len(raw),1852735)
        self.assertEqual(recipe.sha(raw),recipe.RAW_SHA)
        self.assertEqual((self.raw.width,self.raw.height),(1815,867))
        self.assertEqual(set(self.raw.rgba[3::4]),{255})

    def test_original_failed_decode_remains_failed_and_zero(self):
        record=self.custody["preservation"]
        self.assertTrue(record["failed_phase_still_failed"])
        self.assertTrue(record["raw_artifact_byte_identity_independently_verified"])
        self.assertEqual(record["failed_job_sha256"],recipe.DECODE_JOB_SHA)

    def test_all186_retained_body_and_adornment_files_are_bound(self):
        self.assertEqual(self.custody["typed_mask_count"],186)
        self.assertEqual(self.custody["typed_mask_seal"],"9a125f44e622152f5f3b2adc9b27d354dd6854ed9b516f672efde34f69188372")
        self.assertEqual(self.custody["context_checks"],15164)

    def test_mask_has_exact_norm2x_area_and_accepted_boundary_rows(self):
        self.assertEqual(len(self.rows),42)
        self.assertEqual(len(self.ledger),16848)
        self.assertEqual(len(self.ledger)*4,67392)
        deck=[r for r in self.rows if r["part"]=="deck"]
        self.assertEqual((deck[0]["board_y"],deck[0]["board_left"],deck[0]["board_right"]),(196,103,493))
        self.assertEqual((deck[-1]["board_y"],deck[-1]["board_left"],deck[-1]["board_right"]),(227,94,502))
        self.assertEqual({r["board_y"] for r in self.rows if r["part"]=="fascia"},set(range(228,238)))

    def test_all_deck_cell_centers_lie_inside_approved_trapezoid(self):
        for row in self.rows:
            if row["part"]!="deck":
                continue
            y=row["board_y"]+.5
            left=103-9*(y-196)/32
            right=493+9*(y-196)/32
            self.assertGreaterEqual(row["board_left"]+.5,left)
            self.assertLess(row["board_right"]-.5,right)
            self.assertLess(row["board_left"]-.5,left)
            self.assertGreaterEqual(row["board_right"]+.5,right)

    def test_exact_union_preserves_nonstage_and_all_rows476_onward(self):
        self.assertTrue(self.proof["outside_RGBA_equal"])
        self.assertTrue(self.proof["all_rows476_onward_RGBA_identical"])
        self.assertEqual(self.original.rgba[476*1800*4:],self.candidate.rgba[476*1800*4:])
        for x,y in ((187,454),(1004,454),(205,392),(986,392),(188,390),(700,476),(1168,380)):
            self.assertFalse(recipe.contains(x,y))
            self.assertEqual(recipe.pixel(self.original,x,y),recipe.pixel(self.candidate,x,y))

    def test_each_target2x2_cell_is_exact_opaque_original_raw_pixel(self):
        self.assertTrue(self.proof["all67392_mask_pixels_norm2x_and_exact_donors"])
        for cell in self.ledger:
            x,y=cell["target_native_2x2"];sx,sy=cell["source_pixel"]
            color=recipe.pixel(self.raw,sx,sy)
            self.assertEqual(bytes(cell["RGBA"]),color)
            self.assertEqual(color[3],255)
            for dx,dy in ((0,0),(1,0),(0,1),(1,1)):
                self.assertEqual(recipe.pixel(self.candidate,x+dx,y+dy),color)

    def test_source_donors_are_local_conservative_physical_rows(self):
        material=recipe.material_rows(self.raw)
        deck=[r for r in material if r["part"]=="deck"]
        fascia=[r for r in material if r["part"]=="fascia"]
        self.assertEqual(len(deck),32);self.assertEqual(len(fascia),10)
        self.assertEqual((deck[0]["source_y"],deck[0]["source_left"],deck[0]["source_right"]),(398,246,955))
        self.assertEqual((deck[-1]["source_y"],deck[-1]["source_left"],deck[-1]["source_right"]),(454,180,1021))
        self.assertTrue(all(r["non_R_dominant_pixels"]==0 and r["red_min"]>=31 for r in deck))
        self.assertEqual([r["source_y"] for r in fascia],list(range(456,476,2)))
        self.assertEqual([r["non_R_dominant_pixels"] for r in fascia],[1,0,0,0,0,0,0,0,0,0])
        self.assertTrue(all(398<=c["source_pixel"][1]<=474 and 180<=c["source_pixel"][0]<1021 for c in self.ledger))

    def test_NN_columns_remain_inside_each_exact_source_interval(self):
        for row in self.rows:
            values=[recipe.source_x(row,x) for x in range(row["board_left"],row["board_right"])]
            self.assertEqual(values,sorted(values))
            self.assertGreaterEqual(min(values),row["source_left"])
            self.assertLess(max(values),row["source_right"])
            for bad in (row["board_left"]-1,row["board_right"]):
                with self.assertRaises(ValueError):
                    recipe.source_x(row,bad)

    def test_actual_stage_bases_and_near8px_margin_are_required(self):
        records=recipe.contact_proof(self.audit)
        self.assertEqual(len(records),4)
        self.assertEqual({r["file"]:r["near_clearance_native"] for r in records},{
            "kitty_cat_lounge_amateur_night_host_17_body.png":16,
            "kitty_cat_lounge_slow_night_host_15_body.png":8,
            "kitty_cat_lounge_amateur_night_host_13_body.png":28,
            "kitty_cat_lounge_slow_night_host_14_body.png":16})
        self.assertTrue(all(r["all_base_pixels_on_horizontal_deck"] for r in records))

    def test_rack_true_base_rightedge_fits_actual_row_slope(self):
        row=next(r for r in self.rows if r["board_y"]==213)
        self.assertEqual(row["board_right"]*2,996)
        self.assertTrue(recipe.contains(991,425))
        self.assertTrue(recipe.contains(967,427))
        self.assertFalse(recipe.contains(996,427))

    def test_shortened_or_narrowed_mask_cannot_claim_actual_support(self):
        real_contains=recipe.contains
        with patch.object(recipe,"contains",side_effect=lambda x,y:real_contains(x,y) and y<440):
            with self.assertRaisesRegex(ValueError,"base/shadow"):
                recipe.contact_proof(self.audit)
        with patch.object(recipe,"contains",side_effect=lambda x,y:real_contains(x,y) and not (y>=416 and x>=988)):
            with self.assertRaisesRegex(ValueError,"base/shadow"):
                recipe.contact_proof(self.audit)

    def test_typed_paint_count_change_is_rejected_without_weakening_original_masks(self):
        audit=deepcopy(self.audit)
        audit["bounded_alpha_inspection"]["records"][0]["alpha_ge64_pixels"]-=1
        with self.assertRaisesRegex(ValueError,"alpha count"):
            recipe.contact_proof(audit)

    def test_champagne_counter_is_unchanged_exact_final_master_crop(self):
        proof=recipe.counter_proof(recipe.SOURCE_ROOT,self.candidate)
        self.assertEqual(proof["RGBA_texels"],51456)
        self.assertEqual(proof["mismatch"],0)
        self.assertTrue(proof["opaque"])
        self.assertFalse(proof["counter_rewritten"])

    def test_full_manifest27_motions_and_all_other_payloads_stay_frozen(self):
        manifest=recipe.read_json(recipe.SOURCE_ROOT/recipe.MANIFEST)
        self.assertEqual(len(manifest["animations"]),27)
        self.assertEqual(sum(a.get("web_low_detail",True) is True for a in manifest["animations"]),27)
        self.assertEqual(sum(a["type"]=="mover" for a in manifest["animations"]),17)
        self.assertEqual(sum(a["type"]=="pulse" for a in manifest["animations"]),5)
        self.assertEqual(sum(a["type"]=="frames" for a in manifest["animations"]),5)
        self.assertEqual(self.custody["all30_room_sources"],recipe.PAYLOAD_PINS)

    def test_candidate_PNG_encoding_is_lossless_in_memory_only(self):
        encoded=recipe.encode_png(self.candidate)
        self.assertEqual(recipe.decode_png(encoded),self.candidate)
        self.assertEqual(set(self.candidate.rgba[3::4]),{255})
        self.assertFalse(self.proof["whole_generated_master_resized_or_copied"])
        self.assertFalse(self.proof["RGB_color_transforms"])

    def test_pixel_proof_rejects_outside_change_or_wrong_donor(self):
        bad=bytearray(self.candidate.rgba);bad[0]^=1
        with self.assertRaisesRegex(ValueError,"Non-mask"):
            recipe.verify_pixels(self.original,recipe.PNGImage(1800,860,bytes(bad)),self.raw,self.ledger)
        bad=deepcopy(self.ledger);bad[0]["RGBA"][0]^=1
        with self.assertRaisesRegex(ValueError,"donor cell"):
            recipe.verify_pixels(self.original,self.candidate,self.raw,bad)
        bad=deepcopy(self.ledger);bad[-1]=deepcopy(bad[0])
        with self.assertRaisesRegex(ValueError,"one donor record"):
            recipe.verify_pixels(self.original,self.candidate,self.raw,bad)

    def test_exact_source_hash_and_failed_job_status_cannot_be_rebound(self):
        real_read=recipe.read
        with patch.object(recipe,"read",side_effect=lambda p:real_read(p)+b"x" if Path(p)==recipe.SOURCE_ROOT/recipe.BACKGROUND else real_read(p)):
            with self.assertRaisesRegex(ValueError,"Pinned Kitty"):
                recipe.inputs(recipe.SOURCE_ROOT)
        real_json=recipe.read_json
        def fake(path):
            value=real_json(path)
            if Path(path)==recipe.DECODE_EVIDENCE/"job.json":
                value=deepcopy(value);value["exit_code"]=0
            return value
        with patch.object(recipe,"read_json",side_effect=fake):
            with self.assertRaisesRegex(ValueError,"Stopped Job"):
                recipe.failed_decode_provenance(recipe.SOURCE_ROOT)


class StorageWriteContracts(unittest.TestCase):
    @staticmethod
    def layout():
        return SimpleNamespace(prepared=True,root=recipe.QA_ROOT,workspace=recipe.WORKSPACE,
            evidence=recipe.QA_ROOT/"runs/kitty-assembly-unit-fixture/evidence",
            expected_write_bytes=4*1024**3,reserve_bytes=20*1024**3)

    def test_gate_passes_only_declared_directories_and_exact_budget(self):
        layout=self.layout()
        paths=(recipe.WORKSPACE/"source_baseline",recipe.WORKSPACE/"candidate_sources",layout.evidence)
        with patch.object(recipe,"validate_layout",return_value={"fixture":True}) as observed:
            recipe.gate(layout,paths)
        self.assertEqual(observed.call_args.kwargs["extra_write_paths"],paths)
        for field,value in (("prepared",False),("expected_write_bytes",3*1024**3),("reserve_bytes",19*1024**3)):
            bad=self.layout();setattr(bad,field,value)
            with self.subTest(field=field),self.assertRaises(ValueError):
                recipe.gate(bad,paths)

    def test_existing_output_file_is_never_declared_as_write_directory(self):
        existing=recipe.WORKSPACE/"raw_source/kitty-spatial-r1.png"
        self.assertTrue(existing.is_file())
        with patch.object(recipe,"validate_layout") as observed:
            with self.assertRaisesRegex(ValueError,"directories only"):
                recipe.gate(self.layout(),(existing,))
        observed.assert_not_called()

    def test_C_or_other_workspace_directory_cannot_enter_gate(self):
        for path in (Path("C:/CodexQA/fixture"),recipe.QA_ROOT/"workspaces/other-campaign"):
            with self.subTest(path=path),self.assertRaises(ValueError):
                recipe.gate(self.layout(),(path,))

    def test_exclusive_write_gates_parent_before_mkdir_and_immediately_before_open(self):
        events=[];data=b"only an in-memory artifact"
        class Directory:
            def mkdir(self,**kwargs): events.append("mkdir")
        parent=Directory()
        class Target:
            def exists(self): return False
            def open(self,mode):
                self.mode=mode;events.append("open:"+mode)
                return BytesIO()
        target=Target();target.parent=parent
        def gated(layout,paths):
            self.assertEqual(paths,(parent,))
            events.append("gate-directory")
        with patch.object(recipe,"plain",side_effect=lambda x:x),patch.object(recipe,"gate",side_effect=gated), \
                patch.object(recipe,"read",return_value=data):
            recipe.write_new(self.layout(),target,data)
        self.assertEqual(events,["gate-directory","mkdir","gate-directory","open:xb"])
        self.assertEqual(target.mode,"xb")


if __name__=="__main__":
    unittest.main()
