"""V2 Kitty deck: bounded right clearance plus protected curtain/frame proof.

Root executes this worker after independent code review/tests. No children,
network, generation, color transforms, active art, Git, cleanup or moves.
The failed byte-decoder phase is preserved as failed, not used as a PASS gate.
"""
import sys
sys.dont_write_bytecode=True

import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import struct
import zlib

from bar_spatial_candidate_check import PNGImage, decode_png
from bth_qa_storage import Layout, StorageGuardError, validate_layout
import bth_qa_storage as storage

SOURCE_ROOT=Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers")
QA_ROOT=Path("E:/CodexQA/BTH")
WORKSPACE=QA_ROOT/"workspaces/BTH-ENV-SPATIAL-KITTYTRIAL-20261116"
SOURCE_DIRECTORY="review_artifacts/environment_art_sources/kitty-spatial-r1"
BACKGROUND="assets/art/environments/kitty_cat_lounge/background.png"
MANIFEST="data/art/environments/kitty_cat_lounge.json"
INDEX="data/art/environments/index.json"
BASELINE_SEAL="017faffa1f02256046add9e21c2aae3358e2b9508eec15cbac942050f449cfb2"
INDEX_SHA="11d6a7fe6444c2e3be2091d875cf89c7a6fb3380ac529fde9206363b0e242f24"
RAW_SHA="aa1078eab763def23c3d8a1b7232413384b5fcc26a86d7008866dcbf857526eb"
RAW_BYTES=1852735
B64_SHA="0039b3d7d43eb1079b94bfcd493834a967f115b63879f16502ab9b89f71f1f4f"
PRESERVATION_SHA="a98e9e8c770c2fb50b01c700ea284c8bbf13b303783e06b4710df4f9d6be5642"
PROVENANCE_SHA="0cf13dca5ec824215c8979d8bce9cf977bd1aac8aff4f5cecea797d67d495561"
DECODE_JOB_SHA="f6ed8c6be02af3551fb5ff2794c2419b2cbc9c394fe6a4cd7415fd3881e220ea"
DECODE_LOG_SHA="3ee3a156d37eaf103d924828814e749527932b1270a477c8eb8309f5ad5704db"
DECODE_EVIDENCE=QA_ROOT/"runs/BTH-ENV-SPATIAL-KITTYTRIAL-20261116-rawdecode01/evidence"
AUDIT="docs/testing/kitty_spatial_source_audit_20261116.json"
AUDIT_SHA="be604008600da11d1e012b28a2b6a41b084b291ba90a32566253e283855b13e9"
BRIEF="docs/art/briefs/kitty_spatial_repair_20261116.md"
BRIEF_SHA="b043996590bb53a71a09c9a5c2a316f7198025622587e54e94c4f001bcdb0254"
CONTEXT_EVIDENCE=QA_ROOT/"runs/BTH-ENVART-KITTYTRIAL-20261115-r5-capture-01/evidence"
CONTEXT_SHA="2159cd06068bad11d6741d483c75a98b184ae29adc8d5bb3d2db3bf36203eedf"
OCCLUSION=QA_ROOT/"runs/BTH-ENVART-KITTY-20261115-occlusion-r6-01/evidence/kitty-r6-five-context-occlusion.json"
OCCLUSION_SHA="9d3da051c8e85de1757176b193e51c9f64cc326c79b53ef3f802acf9634e489a"
IGNORE=b"# Non-active Kitty Cat Lounge source and candidates; exclude from Godot discovery.\n"
COUNTER="assets/art/environments/kitty_cat_lounge/counters/kitty_champagne_bar.png"
PACKAGE_NAME="kitty-spatial-r1-assembled-v2"
GEOMETRY_PROPOSAL="docs/testing/kitty_spatial_geometry_v2_source_proposal_20261116.json"
GEOMETRY_PROPOSAL_SHA="506914a88efba30d284ec3f99d1246c0151eec31208101602eb3d7544160e3d9"
HELPER_PINS={
 "tools/assemble_kitty_spatial_candidate.py":"988b5bb4eaf9ba2803ab144a689bf4e2561db1dcce590544b013df9107059954",
 "tools/test_assemble_kitty_spatial_candidate.py":"3be556a5e03012036c0e71aba7ae90cf3ff994bcdc53b37e8719e00c17902b5e",
 "tools/bar_spatial_candidate_check.py":"bb0c9fd70fe4c4941d8d1019c682b691db48e5224606340a7e84e6c48dd3837f",
 "tools/bth_qa_storage.py":"cdc08bcb1ad0bff82bb5fd12f467c576cfc40a998f40870068cf6c684216f837",
 "tools/decode_kitty_spatial_raw.py":"532ca2652b9f88f535a7f1d71a7b2f95ac5f2bd387e3961fc212c4ebfd848636"}
PAYLOAD_PINS={
    "assets/art/environments/kitty_cat_lounge/anim/candle_light_0.png": "d79eddbe02603a5412ab7be088d6790b329d2e04dd817842f8eaf6064fe1a12a",
    "assets/art/environments/kitty_cat_lounge/anim/candle_light_1.png": "545375c389080aefa2f4e0461474452313a6ce5754d6946910e7a38b52698d95",
    "assets/art/environments/kitty_cat_lounge/anim/candle_light_2.png": "d73a331a1e0b2e7aca2b472aa8bd02035453ec120d8303e2e9126b0135fd168f",
    "assets/art/environments/kitty_cat_lounge/anim/candle_light_3.png": "0a563e8293c2d67067ca6cb9988ff4287007abc690c33d09aa6cd48252efec64",
    "assets/art/environments/kitty_cat_lounge/anim/candle_light_4.png": "766debe06cb201c06999bcbacc7ede2dcd7a2d76dbbff435315660268029bda9",
    "assets/art/environments/kitty_cat_lounge/anim/cool_air_0.png": "ebe7ceb580eb4286ed3d03d2c18d2c8423b818e65704049dafec601134cdb5b9",
    "assets/art/environments/kitty_cat_lounge/anim/cool_air_1.png": "048dd38269941db7e74d803ac5c0878ca190c7da6b8a7d714d00fea7c79f006e",
    "assets/art/environments/kitty_cat_lounge/anim/cool_air_2.png": "b5f8e207a2c83a23623feb29034e115fb767cc5b45332ca23444044f61342c03",
    "assets/art/environments/kitty_cat_lounge/anim/cool_air_3.png": "2e4e4699cb2436b7ef3fc6e4b4fd611d760e19d6f2d3edff02346071af4b9302",
    "assets/art/environments/kitty_cat_lounge/anim/cool_air_4.png": "2410d0bd01c2927c264b0d73fca0328341ca04c4cce3d8596cbcdd987dcd55ad",
    "assets/art/environments/kitty_cat_lounge/anim/floor_glint_0.png": "bb4f5c707031c24c8f05cca373ab66cb3fb8ea2a729a2dafd6112be0576bc490",
    "assets/art/environments/kitty_cat_lounge/anim/floor_glint_1.png": "8c3943c4d07602da082a29d49d5d092f1d26dd1726cdf1789cabef2073b1c21a",
    "assets/art/environments/kitty_cat_lounge/anim/floor_glint_2.png": "411d358e941a5867df0c7edc1f58fe72c1c81633c1bc7f1b2c4ed8453156775b",
    "assets/art/environments/kitty_cat_lounge/anim/floor_glint_3.png": "18868f32b541dc3a10c44c3dc109054745b7f1e07953883700b4d27ad0ebfa3d",
    "assets/art/environments/kitty_cat_lounge/anim/floor_glint_4.png": "36cb42a27c9b0588e0130993d78403243e1c11255fce38a0a16097dd4d1d7147",
    "assets/art/environments/kitty_cat_lounge/anim/floor_glint_5.png": "3658013941c5c6b6a3ca7484d9018e893a681aa97eaef8e2f212451a6362ed27",
    "assets/art/environments/kitty_cat_lounge/anim/floor_glint_6.png": "d8f87fdc51b4401fef0d151975fb2963bbd43919625a8e6aec9234087627bb57",
    "assets/art/environments/kitty_cat_lounge/anim/kitty_sign_pulse.png": "30af2beae75ddd29b474b645ff86fb26b6f4e2797761cfbf077e05d988f7901f",
    "assets/art/environments/kitty_cat_lounge/anim/pink_air_0.png": "7884f7f55c0dfcf00fce4442cf4eb742b373a057ef928ae3e2cf996ff0bc09a6",
    "assets/art/environments/kitty_cat_lounge/anim/pink_air_1.png": "54e57decb1b1a83ad10cda5400cb53e85f0cb697d63b80b2e550060df55de1f1",
    "assets/art/environments/kitty_cat_lounge/anim/pink_air_2.png": "741b09243d56c16c0380ac01426b6a9ae5c50f3b226b54c4da56858a52f64d73",
    "assets/art/environments/kitty_cat_lounge/anim/pink_air_3.png": "2ce1065d3eb05218ad8c557879b4f4e47c39ac113d6833863e43a8d3a4deb516",
    "assets/art/environments/kitty_cat_lounge/anim/pink_air_4.png": "b9ae8238f27bf31326147aca81dfc11e16f03f384c007063a5eaf64f00cc9fb4",
    "assets/art/environments/kitty_cat_lounge/anim/warm_sparkle_0.png": "5476a12e98bbfbfa2145403b7d8909f7bf662693f5116926dcd3f08a960dbe13",
    "assets/art/environments/kitty_cat_lounge/anim/warm_sparkle_1.png": "5476a12e98bbfbfa2145403b7d8909f7bf662693f5116926dcd3f08a960dbe13",
    "assets/art/environments/kitty_cat_lounge/anim/warm_sparkle_2.png": "5476a12e98bbfbfa2145403b7d8909f7bf662693f5116926dcd3f08a960dbe13",
    "assets/art/environments/kitty_cat_lounge/anim/warm_sparkle_3.png": "5476a12e98bbfbfa2145403b7d8909f7bf662693f5116926dcd3f08a960dbe13",
    "assets/art/environments/kitty_cat_lounge/background.png": "808cdc6dc571889e288d1db023487f8b776f229592463d0459d07a711e8c06e1",
    "assets/art/environments/kitty_cat_lounge/counters/kitty_champagne_bar.png": "3ad4156cec44de64000f94848f159575b7d8f2f96ed8fb42fffa7b6d84a52497",
    "data/art/environments/kitty_cat_lounge.json": "03da076bad28b512c463bf6d620f9a037e36678545f1c06fb685102da923fd6a"
}

def require(value,message):
    if not value: raise ValueError(message)

def sha(data): return hashlib.sha256(data).hexdigest()

def seal(files): return sha("\n".join(n+" "+h for n,h in sorted(files.items())).encode())

def plain(path):
    path=Path(path)
    require(path.is_absolute() and ".." not in path.parts,"Explicit ordinary absolute path required")
    for item in (path,*path.parents):
        if item.exists():
            info=item.lstat()
            require(not item.is_symlink() and not getattr(info,"st_file_attributes",0)&stat.FILE_ATTRIBUTE_REPARSE_POINT,
                    "Linked/reparse path rejected: "+str(item))
    return path

def read(path): return plain(path).read_bytes()

def read_json(path): return json.loads(read(path))

def inventory(root,expected):
    directories={p.as_posix() for n in expected for p in PurePosixPath(n).parents if str(p)!="."}
    observed={};seen_dirs=set()
    for item in sorted(plain(root).rglob("*")):
        path=plain(item);name=path.relative_to(root).as_posix()
        if path.is_dir():
            require(name in directories,"Unknown/empty output directory: "+name)
            seen_dirs.add(name)
        else:
            require(path.is_file() and name in expected,"Unknown/nonordinary output member: "+name)
            observed[name]=sha(read(path))
    require(observed==expected and seen_dirs==directories,"Exact physical output membership/hash differs")
    return observed

def gate(layout,directories):
    directories=tuple(map(plain,directories))
    require(layout.prepared and layout.root==QA_ROOT and layout.workspace==WORKSPACE and
            layout.expected_write_bytes==4*1024**3 and layout.reserve_bytes==20*1024**3,
            "Exact parent-prepared Kitty E layout and4+20GiB budget required")
    require(all((d.is_relative_to(WORKSPACE) or d.is_relative_to(layout.evidence)) and
                (not d.exists() or d.is_dir()) for d in directories),
            "Write gates admit directories only, never an existing output file")
    return validate_layout(layout,extra_write_paths=directories)

def admitted_layout():
    evidence=plain(os.environ["BTH_QA_EVIDENCE_DIR"])
    record=read_json(evidence/"storage-manifest.json")
    require(record.get("schema")=="bth-qa-storage/v1" and record.get("prepared") is True,"Prepared ordinary manifest required")
    layout=Layout(**{key:Path(value) for key,value in record["paths"].items()},
        **{key:record[key] for key in ("run_id","token","expected_write_bytes","reserve_bytes","prepared")})
    require(layout.evidence==evidence and layout.manifest_path==evidence/"storage-manifest.json","Actual evidence binding differs")
    gate(layout,(WORKSPACE,evidence))
    return layout

def failed_decode_provenance(root):
    """Authenticate exact data preservation, while retaining the original FAIL."""
    receipt=read_json(root/SOURCE_DIRECTORY/"raw-preservation-receipt.json")
    require(sha(read(root/SOURCE_DIRECTORY/"raw-preservation-receipt.json"))==PRESERVATION_SHA and
            receipt["status"]=="EXACT_GENERATED_RAW_PRESERVED_AFTER_POST_WRITE_RECEIPT_GATE_STOP" and
            receipt["PNG_sha256"]==RAW_SHA and receipt["bytes"]==RAW_BYTES and
            receipt["exact_encoded_decoded_and_both_PNG_bytes_equal"] is True and
            receipt["stopped_original_decode_job"]["sha256"]==DECODE_JOB_SHA and
            receipt["stopped_original_decode_job"]["exit_code"]==1 and
            receipt["stopped_original_decode_job"]["own_success_receipt_absent"] is True and
            receipt["stopped_original_decode_job"]["retry_performed"] is False and
            receipt["Library"]["status"]=="succeeded",
            "Exact root raw-preservation receipt required; failed decoder is not PASS")
    require(sha(read(DECODE_EVIDENCE/"job.json"))==DECODE_JOB_SHA and
            sha(read(DECODE_EVIDENCE/"worker.log"))==DECODE_LOG_SHA and
            not (DECODE_EVIDENCE/"kitty-spatial-r1-decode.json").exists(),"Stopped decoder evidence changed")
    job=read_json(DECODE_EVIDENCE/"job.json")
    require(job["exit_code"]==1 and job["active_at_release"]==0 and job["assigned_before_execution"] is True and
            not job["timed_out"] and not job["cleanup_errors"] and not job["error"] and not job["log_error"] and
            not job["log_truncated"] and job["limits"]["cpu_rate"]==1200 and
            job["limits"]["job_memory_limit_bytes"]==2*1024**3 and job["limits"]["kill_on_close"] is True and
            job["limits"]["breakaway_allowed"] is False,"Stopped Job closure/caps differ")
    return {"root_receipt_sha256":PRESERVATION_SHA,"failed_job_sha256":DECODE_JOB_SHA,
            "failed_phase_still_failed":True,"raw_artifact_byte_identity_independently_verified":True,
            "Library":receipt["Library"]}

def inputs(root):
    for name,digest in {**PAYLOAD_PINS,INDEX:INDEX_SHA,BRIEF:BRIEF_SHA,AUDIT:AUDIT_SHA,GEOMETRY_PROPOSAL:GEOMETRY_PROPOSAL_SHA,**HELPER_PINS}.items():
        require(sha(read(root/name))==digest,"Pinned Kitty source/control differs: "+name)
    require(len(PAYLOAD_PINS)==30 and INDEX not in PAYLOAD_PINS and seal(PAYLOAD_PINS)==BASELINE_SEAL,
            "Room-only30 payload contract differs")
    artifact=root/SOURCE_DIRECTORY
    require(sha(read(artifact/"provenance.json"))==PROVENANCE_SHA,"Updated raw provenance changed")
    preservation=failed_decode_provenance(root)
    raw_bytes=read(artifact/"kitty-spatial-r1.png")
    encoded=read(artifact/"kitty-spatial-r1.png.b64")
    require(len(encoded)==2470317 and sha(encoded)==B64_SHA and encoded.count(b"\n")==1 and encoded.endswith(b"\n") and
            base64.b64decode(encoded[:-1],validate=True)==raw_bytes and
            len(raw_bytes)==RAW_BYTES and sha(raw_bytes)==RAW_SHA and
            read(WORKSPACE/"raw_source/kitty-spatial-r1.png")==raw_bytes,"Exact generated D/E/base64 custody differs")
    original,raw=decode_png(read(root/BACKGROUND)),decode_png(raw_bytes)
    require((original.width,original.height)==(1800,860) and (raw.width,raw.height)==(1815,867) and
            set(original.rgba[3::4])==set(raw.rgba[3::4])=={255},"Opaque native master/exact generated raw required")
    manifest=read_json(root/MANIFEST)
    require(len(manifest["animations"])==27 and all(a.get("web_low_detail",True) is True for a in manifest["animations"]) and
            manifest["counters"]=={"kitty_champagne_bar":{"texture":"counters/kitty_champagne_bar.png"}},
            "Complete immutable27/defaultlow27/one-counter contract differs")
    audit=read_json(root/AUDIT)
    context=read_json(CONTEXT_EVIDENCE/"kitty_preart_metadata.json")
    require(sha(read(CONTEXT_EVIDENCE/"kitty_preart_metadata.json"))==CONTEXT_SHA and
            sha(read(OCCLUSION))==OCCLUSION_SHA,"Actual five-context/mask provenance differs")
    masks={n:sha(read(CONTEXT_EVIDENCE/n)) for n in audit["retained_mask_custody"]["files"]}
    mask_record=read_json(OCCLUSION)["mask_hashes"]
    require(len(masks)==186 and masks==audit["retained_mask_custody"]["files"] and
            all(mask_record.get(n)==h for n,h in masks.items()),
            "Actual186 retained typed mask bytes differ")
    return original,raw,audit,{"preservation":preservation,"context_checks":context["checks"],
        "context_report_sha256":CONTEXT_SHA,"typed_mask_files":masks,"typed_mask_count":186,
        "typed_mask_seal":seal(masks),"all30_room_sources":PAYLOAD_PINS,"index_separate_sha256":INDEX_SHA}

def target_rows():
    """2x grid pixel centers inside the approved four-corner deck polygon."""
    result=[]
    for r in range(32):
        left=(6551-18*r+63)//64
        right=(31907+6*r+63)//64
        sy=398+(112*r+31)//62
        sl=(246*56-(sy-398)*66+55)//56
        sr=(954*56+(sy-398)*66)//56+1
        result.append({"part":"deck","board_y":196+r,"board_left":left,"board_right":right,
                       "source_y":sy,"source_left":sl,"source_right":sr})
    for r in range(10):
        result.append({"part":"fascia","board_y":228+r,"board_left":94,"board_right":502,
                       "source_y":456+2*r,"source_left":180,"source_right":1021})
    return result

def source_x(row,x):
    require(row["board_left"]<=x<row["board_right"],"Target pixel outside exact row mask")
    width=row["board_right"]-row["board_left"]
    return row["source_left"]+((2*(x-row["board_left"])+1)*(row["source_right"]-row["source_left"]))//(2*width)

def contains(x,y):
    row=next((r for r in target_rows() if r["board_y"]==y//2),None)
    return row is not None and row["board_left"]<=x//2<row["board_right"]

def pixel(image,x,y):
    pos=(y*image.width+x)*4
    return image.rgba[pos:pos+4]

def material_rows(raw):
    rows=[]
    for row in target_rows():
        sy,left,right=row["source_y"],row["source_left"],row["source_right"]
        colors=[pixel(raw,x,sy) for x in range(left,right)]
        nonwarm=sum(c[0]<c[1] or c[0]<c[2] for c in colors)
        if row["part"]=="deck":
            require(nonwarm==0 and min(c[0] for c in colors)>=31,
                    "Admitted interior deck row has changed material pixels")
        rows.append({**row,"source_interval_rgba_sha256":sha(b"".join(colors)),
            "source_interval_pixels":right-left,"non_R_dominant_pixels":nonwarm,
            "red_min":min(c[0] for c in colors),"red_max":max(c[0] for c in colors),
            "scope":"Conservative traced physical material subset, not a claim to copy full raw outer silhouette."})
    return rows

def assemble(original,raw):
    require((original.width,original.height)==(1800,860) and (raw.width,raw.height)==(1815,867),"Exact source dimensions required")
    output=bytearray(original.rgba);ledger=[]
    for row in target_rows():
        sy=row["source_y"];y=row["board_y"]*2
        for x in range(row["board_left"],row["board_right"]):
            sx=source_x(row,x);color=pixel(raw,sx,sy)
            require(color[3]==255,"Admitted generated material must be opaque")
            tx=x*2
            for dy in (0,1):
                pos=((y+dy)*1800+tx)*4
                output[pos:pos+8]=color*2
            ledger.append({"target_native_2x2":[tx,y],"source_pixel":[sx,sy],"RGBA":list(color),"part":row["part"]})
    return PNGImage(1800,860,bytes(output)),ledger

def verify_pixels(original,candidate,raw,ledger):
    require(len(ledger)==16944,"Exact16,944 board clusters/67,776 native repair pixels required")
    spans={r["board_y"]:r for r in target_rows()};before=hashlib.sha256();after=hashlib.sha256()
    expected={(2*x,2*r["board_y"]) for r in spans.values() for x in range(r["board_left"],r["board_right"])}
    require(len({tuple(c["target_native_2x2"]) for c in ledger})==len(ledger) and
            {tuple(c["target_native_2x2"]) for c in ledger}==expected,"Every exact mask cell needs one donor record")
    for y in range(860):
        row=spans.get(y//2)
        left,right=(row["board_left"]*2,row["board_right"]*2) if row else (0,0)
        a=y*1800*4;b=(y+1)*1800*4
        original_out=original.rgba[a:a+left*4]+original.rgba[a+right*4:b]
        candidate_out=candidate.rgba[a:a+left*4]+candidate.rgba[a+right*4:b]
        require(original_out==candidate_out,"Non-mask source pixels changed")
        before.update(original_out);after.update(candidate_out)
    for cell in ledger:
        x,y=cell["target_native_2x2"];sx,sy=cell["source_pixel"]
        color=bytes(cell["RGBA"])
        row=spans[y//2]
        require(188<=x<1004 and 392<=y<476 and x%2==y%2==0 and color==pixel(raw,sx,sy) and
                (sx,sy)==(source_x(row,x//2),row["source_y"]) and
                all(pixel(candidate,x+dx,y+dy)==color for dx in (0,1) for dy in (0,1)),"Exact NN2x donor cell differs")
    require(candidate.rgba[476*1800*4:]==original.rgba[476*1800*4:],"Original floor/base rows476+ differ")
    return {"outside_exact_mask_RGBA_sha256":before.hexdigest(),"outside_RGBA_equal":before.digest()==after.digest(),
            "all_rows476_onward_RGBA_identical":True,"all67776_mask_pixels_norm2x_and_exact_donors":True,
            "whole_generated_master_resized_or_copied":False,"RGB_color_transforms":False}

def protected_stage_edge(original):
    """Explicit source accents; zero overlap is mandatory before any assembly."""
    protected=[]
    for y in range(390,430):
        for x in range(986,1004):
            color=pixel(original,x,y)
            if color[0]>=60 and color[2]>=15 and color[2]>=2*color[1]+4:
                protected.append((x,y))
    expected={(x,y) for y in range(390,392) for x in range(994,1004)}
    expected|={(x,y) for y in range(392,416) for x in range(1000,1004)}
    expected|={(x,y) for y in range(416,418) for x in range(1002,1004)}
    require(set(protected)==expected and len(protected)==120,"Actual source curtain/frame accent trace changed")
    require(all(not contains(x,y) for x,y in protected),
            "Protected curtain/frame overlaps material mask; never silently carve holes")
    return {"scope":"Conservative high-chroma cloth/inner-frame accents; color alone is not full material identity.",
        "ROI_native":[986,390,18,40],"predicate":"R>=60,B>=15,B>=2G+4",
        "protected_pixel_coordinates":[list(p) for p in protected],"protected_pixels":120,
        "material_mask_overlap":0,"exact_material_mask_has_no_protected_source_holes":True,
        "whole_source_rows390_391_untouched":True,"outer_gold_post_x1004_onward_untouched":True}

def deck_supports_buffer(x,y,protected=(),radius=8):
    """Actual whole-pixel material, never fascia or an abstract quad with holes."""
    if any(x-radius<=px<=x+radius and y-radius<=py<=y+radius for px,py in protected):
        return False
    rows={r["board_y"]:r for r in target_rows() if r["part"]=="deck"}
    for yy in range(y-radius,y+radius+1):
        row=rows.get(yy//2)
        if row is None or x-radius<row["board_left"]*2 or x+radius>=row["board_right"]*2:
            return False
    return True

def contact_proof(audit,protected=()):
    records=[];rows={r["board_y"]:r for r in target_rows() if r["part"]=="deck"}
    for record in audit["bounded_alpha_inspection"]["records"]:
        image=decode_png(read(CONTEXT_EVIDENCE/record["file"]))
        x0,y0,width,height=record["query_native"];points=[]
        for y in range(y0,y0+height):
            for x in range(x0,x0+width):
                if pixel(image,x,y)[3]>=64: points.append((x,y))
        require(len(points)==record["alpha_ge64_pixels"],"Observed stage body alpha count differs")
        bbox=[min(p[0] for p in points),min(p[1] for p in points),
              max(p[0] for p in points)+1,max(p[1] for p in points)+1]
        require(bbox==record["bbox_half_open"],"Measured bounded contact extent differs")
        base=[p for p in points if p[1]>=bbox[3]-12]
        require(base and all(contains(x,y) and y<456 for x,y in base),"Actual last12rows base/shadow paint must lie on deck")
        require(all(deck_supports_buffer(x,y,protected,8) for x,y in base),
                "All actual base/shadow pixels need8native actual material buffer on ALL edges")
        margins={"left":min(x-rows[y//2]["board_left"]*2 for x,y in base),
            "right":min(rows[y//2]["board_right"]*2-x-1 for x,y in base),
            "far":min(y-392 for x,y in base),"near":min(456-y-1 for x,y in base)}
        require(min(margins.values())>=8,"Actual base edge clearance is below8native")
        records.append({"file":record["file"],"bounded_bbox":bbox,"base_last12rows_alpha_pixels":len(base),
            "all_base_pixels_on_horizontal_deck":True,"near_clearance_native":456-bbox[3],
            "minimum_native_edge_margins":margins,"continuous_whole_pixel_material_buffer_native":8,
            "full_17x17_native_neighborhood_per_base_pixel_inside_actual_deck":True,
            "protected_source_pixels_excluded_from_actual_material":True,
            "actual_geometry_or_paint_modified":False,"includes_shadow_not_physical_feet_classification":True})
    require(sum(r["base_last12rows_alpha_pixels"] for r in records)==6064,"Same6064 actual body+shadow base pixels required")
    return records

def counter_proof(root,candidate):
    counter=decode_png(read(root/COUNTER))
    require((counter.width,counter.height)==(536,96) and set(counter.rgba[3::4])=={255},"Original opaque counter differs")
    for y in range(96):
        require(counter.rgba[y*536*4:(y+1)*536*4]==candidate.rgba[((y+380)*1800+1168)*4:((y+380)*1800+1704)*4],
                "Fixed champagne foreground must remain exact final-master crop")
    return {"native_master_crop":[1168,380,536,96],"RGBA_texels":51456,"mismatch":0,"opaque":True,"counter_rewritten":False}

def encode_png(image):
    def chunk(kind,payload):
        return struct.pack(">I",len(payload))+kind+payload+struct.pack(">I",zlib.crc32(kind+payload)&0xffffffff)
    rows=b"".join(b"\0"+image.rgba[y*image.width*4:(y+1)*image.width*4] for y in range(image.height))
    return b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",image.width,image.height,8,6,0,0,0))+chunk(b"IDAT",zlib.compress(rows,9))+chunk(b"IEND",b"")

def write_new(layout,path,data):
    path=plain(path)
    require(not path.exists(),"Never overwrite an existing assembly artifact")
    gate(layout,(path.parent,))
    path.parent.mkdir(parents=True,exist_ok=True)
    gate(layout,(path.parent,))
    with path.open("xb") as handle: handle.write(data)
    require(read(path)==data,"Exclusive write/readback differs")

def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root",type=Path,required=True)
    parser.add_argument("--workspace",type=Path,required=True)
    args=parser.parse_args(argv)
    try:
        root,workspace=plain(args.source_root),plain(args.workspace)
        require(root==SOURCE_ROOT and workspace==WORKSPACE,"Only exact D source/E Kitty workspace allowed")
        layout=admitted_layout()
        original,raw,audit,custody=inputs(root)
        baseline=workspace/"source_baseline";parent=workspace/"candidate_sources";output=parent/PACKAGE_NAME
        proof_path=layout.evidence/"kitty-spatial-r1-assembly-v2.json"
        pixels_path=layout.evidence/"kitty-spatial-r1-pixel-provenance-v2.json"
        require({p.name for p in workspace.iterdir()}=={"raw_source"} and not baseline.exists() and not parent.exists() and
                {p.name for p in (workspace/"raw_source").iterdir()}=={"kitty-spatial-r1.png"} and
                not output.exists() and not proof_path.exists() and not pixels_path.exists(),"Fresh exact Kitty source/candidate/evidence closure required")
        material=material_rows(raw)
        candidate,ledger=assemble(original,raw)
        pixel_proof=verify_pixels(original,candidate,raw,ledger)
        edge=protected_stage_edge(original)
        contacts=contact_proof(audit,edge["protected_pixel_coordinates"]);counter=counter_proof(root,candidate)
        require(all(pixel(original,x,y)==pixel(candidate,x,y) for x,y in edge["protected_pixel_coordinates"]),
                "Protected actual curtain/frame source pixels changed")
        png=encode_png(candidate)
        require(decode_png(png)==candidate,"Encoded candidate lossless readback differs")
        gate(layout,(baseline,parent,output,layout.evidence))
        for name,expected in PAYLOAD_PINS.items():
            source=read(root/name)
            require(sha(source)==expected,"Source changed before baseline copy")
            write_new(layout,baseline/name,source)
            write_new(layout,output/name,png if name==BACKGROUND else source)
        write_new(layout,baseline/".gdignore",IGNORE)
        write_new(layout,parent/".gdignore",IGNORE)
        files={name:sha(read(output/name)) for name in PAYLOAD_PINS}
        require({n for n in files if files[n]!=PAYLOAD_PINS[n]}=={BACKGROUND},"Only background may change")
        inventory(baseline,{**PAYLOAD_PINS,".gdignore":sha(IGNORE)})
        inventory(parent,{**{PACKAGE_NAME+"/"+n:h for n,h in files.items()},".gdignore":sha(IGNORE)})
        _,_,_,after=inputs(root)
        require(after==custody,"Original source/control/mask/raw inputs changed")
        pixels={"schema":"bth.kitty_spatial_pixel_provenance/v2","cluster_size_native":[2,2],
            "clusters":ledger,"native_pixels":len(ledger)*4,"no_interpolation_or_RGB_edits":True}
        write_new(layout,pixels_path,(json.dumps(pixels,separators=(",",":"))+"\n").encode())
        report={"schema":"bth.kitty_spatial_assembly/v2","task_id":"BTH-ENV-SPATIAL-KITTY-001",
            "status":"NON_ACTIVE_CANDIDATE_READY_FOR_INDEPENDENT_AUDIT","observed_at":datetime.now(timezone.utc).isoformat(),
            "recipe_sha256":sha(read(__file__)),"raw_sha256":RAW_SHA,"raw_preservation":custody["preservation"],
            "raw_decode_phase_remains_failed":True,"source_custody":custody,
            "baseline":{"path":str(baseline),"file_count":30,"files":PAYLOAD_PINS,"seal":BASELINE_SEAL,
                "auxiliary":{".gdignore":{"sha256":sha(IGNORE),"bytes":len(IGNORE)}},"physical_file_count":31},
            "output":{"path":str(output),"file_count":30,"files":files,"seal":seal(files)},
            "candidate_parent_auxiliary":{".gdignore":{"sha256":sha(IGNORE),"bytes":len(IGNORE)}},
            "global_index_separate_sha256":INDEX_SHA,"deck_polygon_native":[[206,392],[998,392],[1004,456],[188,456]],
            "mask_max_window_native":[188,390,816,86],"mask_pixel_count":67776,"sampling":"NN raw physical subsets to norm2x board clusters",
            "geometry_revision":{"source_proposal":GEOMETRY_PROPOSAL,"sha256":GEOMETRY_PROPOSAL_SHA,
                "unexecuted_v1_recipe_sha256":HELPER_PINS["tools/assemble_kitty_spatial_candidate.py"],
                "no_v1_candidate_existed":True},"protected_stage_edge":edge,
            "source_material_rows":material,"pixel_proof":pixel_proof,"actual_stage_base_contacts":contacts,"counter":counter,
            "pixel_provenance":{"path":str(pixels_path),"sha256":sha(read(pixels_path))},
            "all27_motion_PNGs_full_manifest_counter_and_index_unchanged":True,
            "native_or_art_approval":False,"production_art_written":False,"TEST_updated":False}
        write_new(layout,proof_path,(json.dumps(report,indent=2)+"\n").encode())
        gate(layout,(baseline,parent,output,layout.evidence))
        print(json.dumps({"status":report["status"],"proof":str(proof_path),"proof_sha256":sha(read(proof_path)),
                          "candidate":str(output),"seal":seal(files),"native_or_art_approval":False}))
        return 0
    except (OSError,ValueError,KeyError,TypeError,StorageGuardError) as error:
        print(json.dumps({"status":"STOPPED","error":str(error),"fallback_attempted":False,"cleanup_or_retry":False}),file=sys.stderr)
        return 1

if __name__=="__main__":
    raise SystemExit(main())
