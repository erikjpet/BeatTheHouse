"""Focused read-only Cage alpha-assembly regressions.

Run later only in the parent's admitted capped test Job. Tests read the exact
source/retained evidence and mutate decoded RGBA only in memory. They never
create PNGs, directories, profiles, Jobs, children, save files or Git state.
"""
import sys
sys.dont_write_bytecode = True

from copy import deepcopy
import hashlib
from io import StringIO
import json
import os
import shutil
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import assemble_cage_spatial_candidate_v2 as cage
import assemble_cage_spatial_candidate as frozen_v1
import bth_qa_storage as maintained_storage


def changed(image,x,y,channel,value):
    pixels=bytearray(image.rgba)
    pixels[(y*image.width+x)*4+channel]=value
    return cage.PNGImage(image.width,image.height,bytes(pixels))


class CagePixelChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.background=cage.decode_png(cage.read(cage.SOURCE_ROOT/cage.BACKGROUND))
        cls.sign=cage.decode_png(cage.read(cage.SOURCE_ROOT/cage.SIGN))
        cls.counter=cage.decode_png(cage.read(cage.SOURCE_ROOT/cage.COUNTER))
        cls.support=cage.glyph_support(cls.background)
        cls.result,cls.proof=cage.cut_alpha(cls.sign,cls.support)

    def test_source_gold_support_is_exact_seven_fixed_letters(self):
        self.assertEqual(len(self.support),5532)
        board={((668+x)//2,(72+y)//2) for x,y in self.support}
        self.assertEqual(len(board),1383)
        self.assertEqual(cage.components(board),cage.COMPONENTS)
        self.assertEqual((min(x for x,y in self.support),min(y for x,y in self.support),
                          max(x for x,y in self.support)+1,max(y for x,y in self.support)+1),(32,16,312,62))
        self.assertFalse(any(92<=y<98 for x,y in self.support))

    def test_exact_alpha_cut_keeps_every_RGB_byte_even_under_transparency(self):
        self.assertEqual(self.sign.rgba[0::4],self.result.rgba[0::4])
        self.assertEqual(self.sign.rgba[1::4],self.result.rgba[1::4])
        self.assertEqual(self.sign.rgba[2::4],self.result.rgba[2::4])
        self.assertEqual(self.result.rgba[3::4].count(46),5532)
        self.assertEqual(self.result.rgba[3::4].count(0),46436)
        self.assertEqual(self.result.rgba[3::4].count(255),0)
        self.assertEqual(self.proof["outside_alpha_cuts"],46436)
        self.assertEqual(cage.pixel(self.sign,16,92)[3],255)
        self.assertEqual(cage.pixel(self.result,16,92)[3],0)

    def test_lossless_encoder_roundtrip_in_memory_only(self):
        encoded=cage.encode_png(self.result)
        self.assertEqual(cage.decode_png(encoded),self.result)
        self.assertNotEqual(cage.sha(encoded),cage.PAYLOAD_PINS[cage.SIGN])

    def test_changed_RGB_is_rejected_inside_or_outside_mask(self):
        retained=min(self.support)
        for x,y in (retained,(0,0)):
            with self.subTest(point=(x,y)),self.assertRaisesRegex(ValueError,"RGB changed"):
                cage.verify_cut(self.sign,changed(self.result,x,y,0,254),self.support)

    def test_alpha_boost_lost_glyph_and_outside_leak_are_rejected(self):
        x,y=min(self.support)
        for point,value in (((x,y),47),((x,y),0),((0,0),1),((16,92),255)):
            with self.subTest(point=point,value=value),self.assertRaises(ValueError):
                cage.verify_cut(self.sign,changed(self.result,*point,3,value),self.support)

    def test_shortened_and_same_count_shifted_masks_are_rejected(self):
        short=set(self.support);short.remove(min(short))
        with self.assertRaises(ValueError):
            cage.cut_alpha(self.sign,short)
        shifted={(x+2,y) for x,y in self.support}
        self.assertEqual(len(shifted),5532)
        with self.assertRaisesRegex(ValueError,"components"):
            cage.cut_alpha(self.sign,shifted)

    def test_a_single_broken_NN2_support_block_is_rejected(self):
        broken=set(self.support);broken.remove(min(broken));broken.add((0,0))
        self.assertEqual(len(broken),5532)
        with self.assertRaises(ValueError):
            cage.support_contract(broken)

    def test_input_sign_wrong_dimensions_or_rgba_census_is_rejected(self):
        with self.assertRaises(ValueError):
            cage.original_sign(cage.PNGImage(462,112,self.sign.rgba))
        with self.assertRaises(ValueError):
            cage.original_sign(changed(self.sign,0,0,3,47))
        with self.assertRaises(ValueError):
            cage.original_sign(changed(self.sign,16,92,3,46))

    def test_transparent_or_nonuniform_background_cannot_define_gold_mask(self):
        x,y=min(self.support);gx,gy=668+x,72+y
        with self.assertRaises(ValueError):
            cage.glyph_support(changed(self.background,gx,gy,3,254))
        # A complete2x2 removal preserves NN2 but must fail the exact5532 census.
        pixels=bytearray(self.background.rgba)
        gx,gy=(gx//2)*2,(gy//2)*2
        for dy in (0,1):
            for dx in (0,1):
                at=((gy+dy)*1800+gx+dx)*4
                pixels[at:at+3]=b"\0\0\0"
        with self.assertRaises(ValueError):
            cage.glyph_support(cage.PNGImage(1800,860,bytes(pixels)))

    def test_unchanged_teller_replay_is_exact_and_opaque(self):
        proof=cage.counter_proof(self.background,self.counter)
        self.assertEqual(proof["native_rect_xyxy"],[520,520,1296,632])
        self.assertEqual(proof["equal_opaque_native_pixels"],86912)
        value=(self.counter.rgba[0]+1)%256
        with self.assertRaises(ValueError):
            cage.counter_proof(self.background,changed(self.counter,0,0,0,value))
        with self.assertRaises(ValueError):
            cage.counter_proof(self.background,changed(self.counter,0,0,3,0))

    def test_all_ten_actual_typed_masks_clear_the_gold_glyphs(self):
        result=cage.typed_proof(self.support)
        self.assertEqual(len(result["ten_actual_masks"]),10)
        self.assertTrue(result["all_glyph_alpha_contacts_zero"])
        self.assertEqual({row["object_id"] for row in result["ten_actual_masks"]},
                         {row["object_id"] for row in cage.MASK_PINS.values()})
        self.assertTrue(all(row["glyph_alpha_gt0"]==row["glyph_alpha_ge64"]==0
                            for row in result["ten_actual_masks"]))

    def test_one_faint_real_typed_mask_contact_is_rejected(self):
        # The fake PNG exists only in memory. Rebind its test pin solely to
        # exercise geometric alpha1 rejection beyond the independent hash gate.
        name=sorted(cage.MASK_PINS)[0]
        path=cage.EVIDENCE/name
        original_read=cage.read
        image=cage.decode_png(original_read(path))
        x,y=min(self.support)
        fake=cage.encode_png(changed(image,668+x,72+y,3,1))
        pins=deepcopy(cage.MASK_PINS)
        pins[name]["sha256"]=cage.sha(fake)
        def memory_read(value):
            return fake if Path(value)==path else original_read(value)
        with patch.object(cage,"MASK_PINS",pins),patch.object(cage,"read",side_effect=memory_read):
            with self.assertRaisesRegex(ValueError,"Gold support intersects"):
                cage.typed_proof(self.support)


class CageSourceIdentityChecks(unittest.TestCase):
    def test_24_payloads_are23_room_members_plus_current_index(self):
        values=cage.inventory(cage.SOURCE_ROOT,cage.PAYLOAD_PINS)
        proof=cage.payload_contract(values)
        self.assertEqual(proof["file_count"],24)
        self.assertEqual(proof["room_file_count"],23)
        self.assertEqual(values[cage.INDEX],"11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24")
        self.assertNotIn(cage.CANONICAL_IMPORT,values)
        self.assertEqual(sum(name.endswith(".png") for name in values),22)

    def test_payload_extra_missing_or_changed_member_is_rejected(self):
        for mode in ("extra","missing","changed"):
            values=dict(cage.PAYLOAD_PINS)
            if mode=="extra":
                values[cage.CANONICAL_IMPORT]=cage.CANONICAL_IMPORT_SHA
            elif mode=="missing":
                values.pop(cage.INDEX)
            else:
                values[cage.BACKGROUND]="0"*64
            with self.subTest(mode=mode),self.assertRaises(ValueError):
                cage.payload_contract(values)

    def test_custody_uses_TAB_and_final_LF_not_other_room_seals(self):
        values={"z":"2"*64,"a":"1"*64}
        expected=hashlib.sha256(("a\t"+"1"*64+"\nz\t"+"2"*64+"\n").encode()).hexdigest()
        self.assertEqual(cage.custody(values),expected)
        other=hashlib.sha256(("a "+"1"*64+"\nz "+"2"*64).encode()).hexdigest()
        self.assertNotEqual(cage.custody(values),other)

    def test_full_manifest_has20native16low_and_one_unchanged_counter(self):
        data=cage.read(cage.SOURCE_ROOT/cage.MANIFEST)
        spec=cage.manifest_contract(data)
        self.assertEqual(len(spec["animations"]),20)
        self.assertEqual(sum(row["web_low_detail"] for row in spec["animations"]),16)
        for mode in ("count","low","counter"):
            value=deepcopy(spec)
            if mode=="count":
                value["animations"].pop()
            elif mode=="low":
                value["animations"][0]["web_low_detail"]=False
            else:
                value["counters"]={}
            with self.subTest(mode=mode),self.assertRaises(ValueError):
                cage.manifest_contract(json.dumps(value).encode())

    def test_applied_canonical_import_and_guarded_receipt_are_pinned(self):
        cage.canonical_contract(cage.read(cage.SOURCE_ROOT/cage.CANONICAL_IMPORT))
        receipt=cage.read(cage.SOURCE_ROOT/cage.METADATA_APPLICATION)
        proof=cage.metadata_application_contract(receipt)
        self.assertEqual(proof["Cage_pair"]["sidecar_sha256"],cage.CANONICAL_IMPORT_SHA)
        self.assertFalse(proof["Cage_pair"]["target"].endswith("background.png.import"))
        with self.assertRaises(ValueError):
            cage.canonical_contract(cage.read(cage.SOURCE_ROOT/cage.CANONICAL_IMPORT)+b"\n")
        with self.assertRaises(ValueError):
            cage.metadata_application_contract(receipt+b"\n")

    def test_original_ee595_draft_is_preserved_byte_exact_without_execution(self):
        proof=cage.checkpoint_contract(cage.read(cage.SOURCE_ROOT/cage.CHECKPOINT_TRANSPORT),
                                       cage.read(cage.SOURCE_ROOT/cage.CHECKPOINT_PROVENANCE))
        self.assertEqual(proof["sha256"],"ee595d1c6f1d66d20648ffd60e223fd7faa13bcae86d3ca8c390c237ddbfa3b3")
        self.assertEqual(proof["bytes"],34120)
        with self.assertRaises(ValueError):
            cage.checkpoint_contract(b"invalid",cage.read(cage.SOURCE_ROOT/cage.CHECKPOINT_PROVENANCE))

    def test_exact_typed_mapping_rejects_wrong_host_and_traversal(self):
        data=json.loads(cage.read(cage.METADATA))
        self.assertEqual(len(cage.typed_mapping(data)),10)
        for mode in ("host","path","geometry"):
            value=deepcopy(data)
            if mode=="host":
                value["source_paint"]["objects"][0]["object"]["id"]="invented"
            elif mode=="path":
                value["source_paint"]["objects"][0]["body_png"]="../outside.png"
            else:
                value["source_paint"]["geometry_equal"]=False
            with self.subTest(mode=mode),self.assertRaises(ValueError):
                cage.typed_mapping(value)


class CageGuardBoundaryChecks(unittest.TestCase):
    @staticmethod
    def tree(names):
        return {"exists":True,"files":sorted(names),"directories":sorted(cage.expected_directories(names))}

    def test_only_exact_root_sentinel_is_auxiliary(self):
        names=set(cage.PAYLOAD_PINS)|{".gdignore"}
        cage.check_membership(self.tree(names),cage.PAYLOAD_PINS,sentinel=True)
        for extra in ("assets/.gdignore","unknown.png",cage.CANONICAL_IMPORT):
            with self.subTest(extra=extra),self.assertRaises(ValueError):
                cage.check_membership(self.tree(names|{extra}),cage.PAYLOAD_PINS,sentinel=True)
        bad=self.tree(names);bad["directories"].append("unused-empty")
        with self.assertRaises(ValueError):
            cage.check_membership(bad,cage.PAYLOAD_PINS,sentinel=True)

    def test_unknown_sentinel_bytes_are_rejected_without_writes(self):
        tree=self.tree(set(cage.PAYLOAD_PINS)|{".gdignore"})
        with patch.object(cage,"physical_tree",return_value=tree),patch.object(cage,"read",return_value=b"unknown"), \
                patch.object(cage,"inventory",return_value=cage.PAYLOAD_PINS):
            with self.assertRaises(ValueError):
                cage.check_tree(cage.WORKSPACE/"source_baseline",cage.PAYLOAD_PINS,sentinel=True)

    def test_missing_payload_and_unknown_existing_empty_baseline_are_rejected(self):
        with self.assertRaises(ValueError):
            cage.check_membership(self.tree(set(cage.PAYLOAD_PINS)-{cage.SIGN}),cage.PAYLOAD_PINS,sentinel=True)
        with self.assertRaises(ValueError):
            cage.check_membership(self.tree(set()),cage.PAYLOAD_PINS,sentinel=True)
        cage.check_membership({"exists":False,"files":[],"directories":[]},cage.PAYLOAD_PINS,absent=True)

    def test_configured_storage_budget_boundary_and_no_C_fallback(self):
        gib=cage.GIB
        self.assertEqual(cage.budget(4*gib,20*gib,100*gib,24*gib)["projected_free_bytes"],20*gib)
        with self.assertRaises(ValueError):
            cage.budget(4*gib,20*gib,100*gib,24*gib-1)
        self.assertEqual(cage.budget(4*gib,20*gib,1000*gib,24*gib)["minimum_projected_headroom_bytes"],20*gib)
        with self.assertRaises(ValueError):
            cage.budget(4*gib,20*gib,1000*gib,24*gib-1)
        self.assertEqual(cage.budget(5*gib,21*gib,1000*gib,26*gib)["required_free_bytes"],26*gib)
        with self.assertRaises(ValueError):
            cage.budget(5*gib,21*gib,1000*gib,26*gib-1)
        for expected,reserve in ((3*gib,20*gib),(4*gib,19*gib),(4*gib-1,20*gib),(4*gib,20*gib-1)):
            with self.subTest(expected=expected,reserve=reserve),self.assertRaises(ValueError):
                cage.budget(expected,reserve,100*gib,99*gib)

    def test_named_outputs_cannot_shift_to_another_campaign_or_drive(self):
        evidence=Path("E:/CodexQA/BTH/runs/READ_ONLY_CAGE_PATH_FIXTURE/evidence")
        layout=SimpleNamespace(workspace=cage.WORKSPACE,evidence=evidence)
        common=dict(source_root=cage.SOURCE_ROOT,workspace=cage.WORKSPACE,
            baseline_root=cage.WORKSPACE/"source_baseline",
            candidate_root=cage.WORKSPACE/"candidate_sources/cage-spatial-r1-alpha-mask",
            report=evidence/"cage-spatial-r1-assembly.json",pixel_proof=evidence/"cage-spatial-r1-glyph-proof.json")
        with patch.object(cage,"ordinary",side_effect=lambda p,**kw:Path(p)), \
                patch.object(cage,"gate",return_value={}),patch.object(Path,"exists",return_value=False), \
                patch.object(Path,"iterdir",return_value=iter(())):
            cage.path_contract(SimpleNamespace(**common),layout)
            for key,value in (("candidate_root",Path("C:/unadmitted/output")),("baseline_root",cage.WORKSPACE/"different")):
                args={**common,key:value}
                with self.subTest(key=key),self.assertRaises(ValueError):
                    cage.path_contract(SimpleNamespace(**args),layout)

    def test_bad_payload_stops_before_any_output_write(self):
        evidence=Path("E:/CodexQA/BTH/runs/READ_ONLY_CAGE_BAD_PAYLOAD/evidence")
        layout=SimpleNamespace(workspace=cage.WORKSPACE,evidence=evidence)
        paths={"source_root":cage.SOURCE_ROOT,"baseline_root":cage.WORKSPACE/"source_baseline",
            "candidate_root":cage.WORKSPACE/"candidate_sources/cage-spatial-r1-alpha-mask",
            "report":evidence/"cage-spatial-r1-assembly.json","pixel_proof":evidence/"cage-spatial-r1-glyph-proof.json"}
        args=[]
        for key,value in {**paths,"workspace":cage.WORKSPACE}.items():
            args+=["--"+key.replace("_","-"),str(value)]
        with patch.object(cage,"admitted_layout",return_value=layout), \
                patch.object(cage,"path_contract",return_value=(paths,cage.WORKSPACE/"candidate_sources")), \
                patch.object(cage,"inventory",return_value={name:"0"*64 for name in cage.PAYLOAD_PINS}), \
                patch.object(cage,"write_fresh") as write,patch("sys.stderr",new_callable=StringIO):
            self.assertEqual(cage.main(args),1)
            write.assert_not_called()



class CageConfiguredStorageRegressionChecks(unittest.TestCase):
    def test_recorded_real_E_capacity_passes_configured_rule_and_rejects_old_rule(self):
        sample=cage.FAILED_CAPACITY
        expected,reserve=sample["configured_expected_write_bytes"],sample["configured_reserve_bytes"]
        total,available=sample["total_bytes"],sample["available_bytes_at_launch"]
        self.assertEqual((total,available),(999649439744,72702087168))
        proof=cage.budget(expected,reserve,total,available)
        self.assertEqual(proof["required_free_bytes"],25769803776)
        self.assertEqual(proof["minimum_projected_headroom_bytes"],21474836480)
        self.assertGreater(available,proof["required_free_bytes"])
        self.assertNotIn("minimum_free_ratio",proof)
        self.assertNotIn("minimum_free_bytes",proof)
        # Pure counterfactual only: never call the old main/launcher or retry it.
        with self.assertRaisesRegex(ValueError,"12percent"):
            frozen_v1.budget(expected,reserve,total,available)
        self.assertEqual(sample["old_unrequested_volume_headroom_bytes"],119957932770)
        self.assertEqual(sample["old_unrequested_required_bytes"],124252900066)
        self.assertLess(available,sample["old_unrequested_required_bytes"])
        boundary=cage.budget(expected,reserve,total,25769803776)
        self.assertEqual(boundary["projected_free_bytes"],reserve)
        with self.assertRaises(ValueError):
            cage.budget(expected,reserve,total,25769803775)

    def test_actual_guarded_test_manifest_passes_maintained_validation_readonly(self):
        # Root must run tests in a prepared guarded E Job. This validates the
        # real current paths, ownership manifest and current available bytes.
        evidence=Path(os.environ["BTH_QA_EVIDENCE_DIR"])
        record=json.loads((evidence/"storage-manifest.json").read_bytes())
        layout=maintained_storage.Layout(**{key:Path(value) for key,value in record["paths"].items()},
            **{key:record[key] for key in ("run_id","token","expected_write_bytes","reserve_bytes","prepared")})
        self.assertTrue(layout.prepared)
        self.assertGreaterEqual(layout.expected_write_bytes,4*cage.GIB)
        self.assertGreaterEqual(layout.reserve_bytes,20*cage.GIB)
        self.assertEqual(layout.manifest_path,evidence/"storage-manifest.json")
        observations=maintained_storage.validate_layout(layout)
        available=min(row["available_bytes"] for row in observations.values())
        total=shutil.disk_usage(layout.root).total
        proof=cage.budget(layout.expected_write_bytes,layout.reserve_bytes,total,available)
        self.assertEqual(proof["required_free_bytes"],layout.expected_write_bytes+layout.reserve_bytes)
        self.assertGreaterEqual(available,proof["required_free_bytes"])
        print("CAGE_V2_READ_ONLY_CONFIGURED_STORAGE_REGRESSION",json.dumps({
            "storage_manifest":str(layout.manifest_path),"total_bytes":total,
            "minimum_observed_available_bytes":available,"configured_required_bytes":proof["required_free_bytes"],
            "maintained_validate_layout":"PASS","new_budget":"PASS","writes_or_children":False},sort_keys=True))

    def test_previous_helpers_failed_job_and_actual_process_caps_remain_preserved(self):
        history=cage.failed_attempt_history()
        self.assertEqual(history["previous_assembler_sha256"],"0a4120d6284e625808a5b9ab6f4a3076ed80121ad435d0465c926d9f5320779f")
        self.assertEqual(history["previous_tests_sha256"],"d665f236e80c26196ccaae7cc0099a060cb2a0da6056cdbfe12cd3dc054c82eb")
        self.assertEqual(cage.sha(cage.read(cage.SOURCE_ROOT/"tools/assemble_cage_spatial_candidate.py")),cage.PREVIOUS_ASSEMBLER_SHA)
        self.assertEqual(cage.sha(cage.read(cage.SOURCE_ROOT/"tools/test_assemble_cage_spatial_candidate.py")),cage.PREVIOUS_TESTS_SHA)
        self.assertEqual(history["failed_job"]["pid"],32548)
        self.assertEqual(history["failed_job"]["exit_code"],1)
        self.assertEqual(history["failed_job"]["active_at_release"],0)
        self.assertEqual(history["failed_job"]["actual_cpu_rate"],1200)
        self.assertEqual(history["failed_job"]["actual_job_memory_limit_bytes"],2147483648)
        self.assertFalse(history["old_launch_retried"])

    def test_capacity_observation_cannot_bypass_maintained_validation(self):
        layout=SimpleNamespace(prepared=True,root=Path("E:/CodexQA/BTH"),workspace=cage.WORKSPACE)
        with patch.object(cage,"validate_layout",side_effect=ValueError("maintained guard denied")), \
                patch.object(cage.shutil,"disk_usage") as usage:
            with self.assertRaisesRegex(ValueError,"maintained guard"):
                cage.gate(layout)
            usage.assert_not_called()

    def test_every_write_still_requires_its_immediate_storage_gate(self):
        with patch.object(cage,"gate",side_effect=ValueError("configured capacity")), \
                patch.object(Path,"mkdir") as mkdir,patch.object(Path,"open") as opened:
            with self.assertRaisesRegex(ValueError,"configured capacity"):
                cage.write_fresh(cage.WORKSPACE/"candidate_sources/not-created",b"not written",object())
            mkdir.assert_not_called()
            opened.assert_not_called()


if __name__ == "__main__":
    unittest.main()
