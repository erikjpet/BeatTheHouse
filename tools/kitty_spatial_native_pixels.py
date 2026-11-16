"""Pure read-only Kitty pixel diagnostics; no child, image write or Pillow import.

Conservative ordering and >0 predicate are retained from the original06c7
observer. over() implements Pillow10.3's seven-bit integer alpha composite,
including its divide-by255 rounding, from the tagged upstream specification:
https://github.com/python-pillow/Pillow/blob/10.3.0/src/libImaging/AlphaComposite.c
https://github.com/python-pillow/Pillow/blob/10.3.0/src/libImaging/ImagingUtils.h
Actual historical135 parity is required before any fresh occlusion acceptance.
This proves surviving changed pixels, not visibility prominence or actual timing.
"""
import sys
sys.dont_write_bytecode = True
from pathlib import Path
import hashlib
import argparse
import json
import os

from bar_spatial_candidate_check import decode_png
from grand_spatial_native_trial import plain, read_json, sha

CATALOG = ("__none","kitty_cat_lounge_amateur_night","kitty_cat_lounge_buyout",
           "kitty_cat_lounge_slow_night","kitty_cat_lounge_bachelorette_storm")
HISTORICAL_CONTEXT = Path("E:/CodexQA/BTH/runs/BTH-ENVART-KITTYTRIAL-20261115-r5-capture-01/evidence")
HISTORICAL_MOTION = Path("E:/CodexQA/BTH/runs/BTH-ENVART-KITTYTRIAL-20261115-r6-motion-01/evidence")
HISTORICAL_OCCLUSION = Path("E:/CodexQA/BTH/runs/BTH-ENVART-KITTY-20261115-occlusion-r6-01/evidence/kitty-r6-five-context-occlusion.json")
HISTORICAL_CONTEXT_SHA = "2159cd06068bad11d6741d483c75a98b184ae29adc8d5bb3d2db3bf36203eedf"
HISTORICAL_MOTION_SHA = "d336eaae07a2d7e414032250c5e68c210d5a265f9e6d76c552774147a9a20565"
HISTORICAL_OCCLUSION_SHA = "9d3da051c8e85de1757176b193e51c9f64cc326c79b53ef3f802acf9634e489a"
ORIGINAL_OBSERVER = Path("E:/CodexQA/BTH/workspaces/BTH-ENVART-AUDIT-20261115/check_kitty_r6_occlusion.py")
ORIGINAL_OBSERVER_SHA = "06c7661e7e968259e5198b94b80f4b3d7bee9f9b30256b571a5b780cd6c5ca6c"
NONZERO = bytes([0]+[1]*255)
ZERO = (0,0,0,0)

def require(value,message):
    if not value:
        raise ValueError(message)

def source_custody():
    """All original producers and current decoder/guard/pixel source, read-only."""
    directory=Path(__file__).parent
    current={
        "bar_spatial_candidate_check.py":"bb0c9fd70fe4c4941d8d1019c682b691db48e5224606340a7e84e6c48dd3837f",
        "grand_spatial_native_trial.py":"650e14dfd71197bd55021553e3ec9adfe1f67533ea3e7c930a456e05bcd3ac6a",
        "bar_spatial_native_suite.py":"2bbb359859449141118f1ce21ba08d698bd1abf4d6c5e16fa1da8defde55eea4",
        "bth_qa_storage.py":"cdc08bcb1ad0bff82bb5fd12f467c576cfc40a998f40870068cf6c684216f837",
        "bth_qa_guarded_run.py":"7ea6be8366f606995a1f69ddb26d99b4e3c47a0fcce9d968abe17b3dc074ad7e",
        "bth_qa_command_paths.py":"bbc405ac19ae803c2c15d93fee1ca059f25d06176cfee7926b2329b93ca4352b"}
    original={
        "envart_kitty_preart_metadata.gd":"51c191725faffeb4b9467e15dc41b4e0ace14d28d91d04214b952ba10c1c4a38",
        "envart_kitty_animation_probe.gd":"ef4b1b7ab50340543c358bd8d27c383ae1c2c991f6c8015a72307f0de1c32da1",
        "envart_kitty_animation_capture.gd":"b75c8b8f09b0ba6e77a69b9c9a9e6ecaa290582d457667b4d46f2a8c2235abfa",
        "environment_art_baseline_capture.gd":"89d7ae812bedd203f49830bf367863bced32d08cfcc5e0327ebaf4450317de8f",
        "environment_layout_screenshots.gd":"eadf8f113aff55113ecf59e764503fd5bc2e4a64d00689573e0b56489b1a78e5"}
    legacy=Path("E:/CodexQA/BTH/workspaces/BTH-ENVART-KITTY-TRIAL-20261115/tools")
    expected={**{directory/name:digest for name,digest in current.items()},
        **{legacy/name:digest for name,digest in original.items()},Path(__file__):sha(plain(__file__))}
    result={}
    for path,digest in expected.items():
        path=plain(path)
        require(path.is_file() and sha(path)==digest,"Historical/current source custody changed: "+str(path))
        result[str(path)]={"sha256":digest,"bytes":path.stat().st_size}
    return result

def over(destination,source):
    """Exact RGBA8 source-over; all rounding matches tagged Pillow10.3."""
    alpha=source[3]
    if not alpha:
        return tuple(destination)
    blend=destination[3]*(255-alpha)
    out_alpha=alpha*255+blend
    source_weight=alpha*255*255*128//out_alpha
    destination_weight=255*128-source_weight
    rgb=[]
    for channel in range(3):
        rounded=source[channel]*source_weight+destination[channel]*destination_weight+128*128
        rgb.append((((rounded>>8)+rounded)>>8)>>7)
    rounded_alpha=out_alpha+128
    return (*rgb,((rounded_alpha>>8)+rounded_alpha)>>8)

def inside(root,name):
    require(isinstance(name,str) and name and "\\" not in name and not Path(name).is_absolute() and
            all(part not in ("",".","..") for part in name.split("/")),"Unsafe relative PNG path")
    path=plain(root/name)
    require(path.is_file() and path.is_relative_to(plain(root)),"Ordinary PNG escaped evidence")
    return path

def image(root,name,ledger):
    path=inside(root,name)
    digest=sha(path)
    require(name not in ledger or ledger[name]["sha256"]==digest,"PNG changed during read")
    data=path.read_bytes()
    require(hashlib.sha256(data).hexdigest()==digest,"PNG changed during bounded read")
    value=decode_png(data)
    require((value.width,value.height)==(1800,860),"Native1800x860 diagnostic required")
    ledger[name]={"sha256":digest,"bytes":len(data),"dimensions":[1800,860]}
    return value

def sparse_pixels(rgba):
    flags=rgba[3::4].translate(NONZERO)
    offset=flags.find(b"\1")
    while offset!=-1:
        start=offset*4
        yield offset,tuple(rgba[start:start+4])
        offset=flags.find(b"\1",offset+1)

def changed_pairs(a,b):
    require(len(a)==len(b) and len(a)%4==0,"Matching RGBA images required")
    # XOR and zero-map are exact C-level byte operations; no pixel transform.
    changes=(int.from_bytes(a,"little")^int.from_bytes(b,"little")).to_bytes(len(a),"little").translate(NONZERO)
    offset=changes.find(b"\1")
    while offset!=-1:
        index=offset//4
        start=index*4
        yield index,tuple(a[start:start+4]),tuple(b[start:start+4])
        offset=changes.find(b"\1",start+4)

def motion_pairs(root,report,ids,ledger):
    require([entry["id"] for entry in report["entries"]]==list(ids),"Exact motion27 order required")
    pairs={}
    for entry in report["entries"]:
        name=entry["id"]
        a=image(root,name+"_live_a.png",ledger)
        b=image(root,name+"_live_b.png",ledger)
        pairs[name]=list(changed_pairs(a.rgba,b.rgba))
        require(pairs[name],"Original motion pair has no pixel change: "+name)
    return pairs

def occlusion(context_root,motion_root,contexts,motion,ids):
    """Exact original counter, sorted body, sorted adorn alpha ordering."""
    require(contexts["scenarios"]==list(CATALOG) and set(contexts["views"])==set(CATALOG),"Exact Kitty5 contexts required")
    mask_ledger,motion_ledger={},{}
    pairs=motion_pairs(motion_root,motion,ids,motion_ledger)
    rows=[]
    for context in CATALOG:
        view=contexts["views"][context]
        source=[r["png"] for r in view["source_background"]["records"] if r["mode"]==2 and r["clock"]==0]
        require(len(source)==1,"Exact original source-mode2 clock0 required")
        paint=view["source_paint"]["objects"]
        names=source+sorted(r["body_png"] for r in paint)+sorted(r["adorn_png"] for r in paint)
        require(len(names)==1+len(paint)*2 and len(set(names))==len(names),"Unique actual typed masks required")
        overlay={}
        for name in names:
            rgba=image(context_root,name,mask_ledger).rgba
            for index,pixel in sparse_pixels(rgba):
                overlay[index]=over(overlay.get(index,ZERO),pixel)
        for name in ids:
            changed=maximum=0
            for index,a,b in pairs[name]:
                layer=overlay.get(index,ZERO)
                aa,bb=over(a,layer),over(b,layer)
                delta=max(abs(aa[c]-bb[c]) for c in range(3))
                if delta:
                    changed+=1
                    maximum=max(maximum,delta)
            rows.append({"context":context,"id":name,"surviving_changed_pixels":changed,
                "maximum_channel_delta":maximum,"visible_pixel_change_under_conservative_overlay":changed>0})
    require(len(rows)==135 and all(row["visible_pixel_change_under_conservative_overlay"] for row in rows),
            "Original135 conservative surviving-pixel predicate failed")
    for root,ledger in ((context_root,mask_ledger),(motion_root,motion_ledger)):
        for name,row in ledger.items():
            require(sha(inside(root,name))==row["sha256"],"Original pixel input changed after calculation")
    return {"status":"PASS","checks":135,"rows":rows,"mask_hashes":{n:r["sha256"] for n,r in mask_ledger.items()},
        "mask_png_ledger":mask_ledger,"motion_png_ledger":motion_ledger,
        "algorithm":"Pillow10.3 exact7-bit RGBA8 source-over; >0 max RGB delta; original sorted layer order",
        "scope":"Conservative under-all-source-layers surviving pixel change; no timing/perceptual/actual-composite inference"}

def historical_parity(ids):
    """Read-only all135 regression; never runs the legacy Python/Pillow helper."""
    sources_before=source_custody()
    for path,digest in ((ORIGINAL_OBSERVER,ORIGINAL_OBSERVER_SHA),
            (HISTORICAL_CONTEXT/"kitty_preart_metadata.json",HISTORICAL_CONTEXT_SHA),
            (HISTORICAL_MOTION/"kitty_animation_probe.json",HISTORICAL_MOTION_SHA),
            (HISTORICAL_OCCLUSION,HISTORICAL_OCCLUSION_SHA)):
        require(sha(plain(path))==digest,"Pinned original135 observer/evidence changed")
    expected=read_json(HISTORICAL_OCCLUSION)
    result=occlusion(HISTORICAL_CONTEXT,HISTORICAL_MOTION,
        read_json(HISTORICAL_CONTEXT/"kitty_preart_metadata.json"),
        read_json(HISTORICAL_MOTION/"kitty_animation_probe.json"),ids)
    require(expected["status"]=="PASS" and expected["checks"]==135 and result["rows"]==expected["rows"] and
            result["mask_hashes"]==expected["mask_hashes"],"Exact original135 changed-count/maxdelta/mask parity failed")
    for path,digest in ((ORIGINAL_OBSERVER,ORIGINAL_OBSERVER_SHA),
            (HISTORICAL_CONTEXT/"kitty_preart_metadata.json",HISTORICAL_CONTEXT_SHA),
            (HISTORICAL_MOTION/"kitty_animation_probe.json",HISTORICAL_MOTION_SHA),
            (HISTORICAL_OCCLUSION,HISTORICAL_OCCLUSION_SHA)):
        require(sha(plain(path))==digest,"Historical reference changed after exact135 calculation")
    require(source_custody()==sources_before,"Historical/current pixel source changed during parity")
    return {"status":"EXACT_ALL135_PARITY_PASS","historical_report_sha256":HISTORICAL_OCCLUSION_SHA,
        "historical_context_report_sha256":HISTORICAL_CONTEXT_SHA,"historical_motion_report_sha256":HISTORICAL_MOTION_SHA,
        "original_observer_sha256":ORIGINAL_OBSERVER_SHA,"rows":135,"all_changed_counts_and_maximum_deltas_equal":True,
        "all191_source_mask_hashes_equal":True,"Pillow_installed_or_executed":False,
        "reproduced_rows":result["rows"],"mask_png_ledger":result["mask_png_ledger"],
        "motion_png_ledger":result["motion_png_ledger"],"historical_control_files_unchanged_before_after":True,
        "source_files_before_and_after":sources_before,"all_source_files_unchanged":True}

def deck_rows():
    return {196+r:((6551-18*r+63)//64,(31907+6*r+63)//64) for r in range(32)}

def deck_material(x,y,protected):
    row=y//2-196
    return 0<=row<32 and ((6551-18*row+63)//64)*2<=x<((31907+6*row+63)//64)*2 and (x,y) not in protected

def contact_pixels(rgba,width,height):
    """Alpha>=64 body AND contact shadow; fullpaint bottom12 rows, no shrink."""
    require(width==1800 and height==860 and len(rgba)==width*height*4,"Native typed source paint required")
    alpha=rgba[3::4]
    strong=alpha.translate(bytes(0 if value<64 else 1 for value in range(256)))
    end=strong.rfind(b"\1")
    require(end!=-1,"Actual stage target body has no strong source paint")
    bottom=end//width+1
    points=[]
    for y in range(max(0,bottom-12),bottom):
        start=y*width
        offset=strong.find(b"\1",start,start+width)
        while offset!=-1:
            points.append((offset%width,y))
            offset=strong.find(b"\1",offset+1,start+width)
    require(points,"Actual stage base has no alpha>=64 points")
    return points,bottom

def verify_contact(points,protected):
    failed=[]
    for x,y in points:
        if any(not deck_material(xx,yy,protected) for yy in range(y-8,y+9) for xx in range(x-8,x+9)):
            failed.append([x,y])
    require(not failed,"Actual stage body/shadow base lacks full8px horizontal material buffer: "+str(failed[:4]))
    return {"base_last12rows_alpha_pixels":len(points),"continuous_whole_pixel_material_buffer_native":8,
        "full_17x17_native_neighborhood_per_base_pixel_inside_actual_deck":True,
        "includes_shadow_not_physical_feet_classification":True,"actual_geometry_or_paint_modified":False}

def verify_installed_material(master,original,raw,proof):
    """Reconstruct each actual source donor cell; check entire outside mask."""
    require((master.width,master.height)==(original.width,original.height)==(1800,860) and
        (raw.width,raw.height)==(1815,867),"Pinned native/raw dimensions required")
    rows=[]
    for r in range(32):
        sy=398+(112*r+31)//62
        rows.append((196+r,(6551-18*r+63)//64,(31907+6*r+63)//64,sy,
            (246*56-(sy-398)*66+55)//56,(954*56+(sy-398)*66)//56+1))
    rows.extend((228+r,94,502,456+2*r,180,1021) for r in range(10))
    spans={row[0]:row for row in rows}
    clusters=0
    for y in range(860):
        row=spans.get(y//2)
        left,right=(row[1]*2,row[2]*2) if row else (0,0)
        start,end=y*1800*4,(y+1)*1800*4
        require(master.rgba[start:start+left*4]+master.rgba[start+right*4:end]==
                original.rgba[start:start+left*4]+original.rgba[start+right*4:end],"Installed pixels outside exact material union differ")
    for by,left,right,sy,sl,sr in rows:
        if by<228:
            colors=[raw.rgba[(sy*raw.width+x)*4:(sy*raw.width+x)*4+4] for x in range(sl,sr)]
            require(all(c[3]==255 and c[0]>=31 and c[0]>=max(c[1],c[2]) for c in colors),
                "Actual admitted horizontal-deck material differs")
        for bx in range(left,right):
            sx=sl+((2*(bx-left)+1)*(sr-sl))//(2*(right-left))
            color=raw.rgba[(sy*raw.width+sx)*4:(sy*raw.width+sx)*4+4]
            require(color[3]==255,"Opaque actual raw material required")
            for dy in (0,1):
                offset=((by*2+dy)*1800+bx*2)*4
                require(master.rgba[offset:offset+8]==color*2,"Installed norm2x/raw donor cell differs")
            clusters+=1
    protected=set()
    for y in range(390,430):
        for x in range(986,1004):
            color=original.rgba[(y*1800+x)*4:(y*1800+x)*4+4]
            if color[0]>=60 and color[2]>=15 and color[2]>=2*color[1]+4:
                protected.add((x,y))
                offset=(y*1800+x)*4
                require(master.rgba[offset:offset+4]==color and not deck_material(x,y,()),"Actual preserved source curtain/frame overlaps deck")
    require(clusters==16944 and len(protected)==120 and
        protected=={tuple(row) for row in proof["protected_stage_edge"]["protected_pixel_coordinates"]} and
        master.rgba[476*1800*4:]==original.rgba[476*1800*4:],"Exact16944cells/protected120/source-floor custody differs")
    return {"installed_native_donor_pixels":clusters*4,"norm2x_clusters":clusters,"all_donors_RGBA_exact":True,
        "all_outside_material_and_rows476plus_equal_source":True,"protected_original_curtain_frame_pixels":120,
        "horizontal_deck_contains_no_protected_source_hole":True,"whole_generated_master_used":False,
        "RGBA_transforms_or_resize":False}


def parse_args(argv=None):
    parser=argparse.ArgumentParser(description="Historical reference-only135 parity worker; launch with maintained guarded_run.")
    parser.add_argument("--historical-reference-only",action="store_true",required=True)
    for name in ("root","workspace","profile","temp","evidence","out"):
        parser.add_argument("--"+name,type=Path,required=True)
    return parser.parse_args(argv)


def historical_worker(args):
    """Only an already-prepared, claimed, capped-by-parent file worker may write.

    No fresh candidate/current-QA inputs, directory creation or child launch.
    The parent must still qualify the eventual closed-zero Job/log receipt.
    """
    from bth_qa_storage import Layout, validate_layout, check_launch
    root,workspace,profile,temp,evidence,out=(plain(getattr(args,name)) for name in
        ("root","workspace","profile","temp","evidence","out"))
    require(root==Path("E:/CodexQA/BTH") and
        workspace==root/"workspaces/BTH-ENV-SPATIAL-KITTYPARITY-20261116" and
        evidence.parent.parent==root/"runs" and evidence.name=="evidence" and
        out==evidence/"historical-parity.json" and not out.exists(),
        "Exact fresh historical-only E workspace/evidence/output required")
    manifest_path=plain(evidence/"storage-manifest.json")
    manifest=read_json(manifest_path)
    require(manifest.get("schema")=="bth-qa-storage/v1" and manifest.get("prepared") is True,
        "Prepared nonresident storage manifest required")
    layout=Layout(**{name:Path(value) for name,value in manifest["paths"].items()},
        **{name:manifest[name] for name in ("run_id","token","expected_write_bytes","reserve_bytes","prepared")})
    require((layout.root,layout.workspace,layout.profile,layout.temp,layout.evidence)==(root,workspace,profile,temp,evidence) and
        layout.expected_write_bytes==4*1024**3 and layout.reserve_bytes==20*1024**3,
        "Explicit paths and4GiB+20GiB admitted budget must match manifest")
    gate=check_launch(layout,cwd=Path.cwd(),env=os.environ,extra_write_paths=(evidence,))
    manifest_sha=sha(manifest_path)
    claim_path=plain(evidence/"launch-claim.json"); claim=read_json(claim_path)
    pending=read_json(plain(evidence/"job.json")); command=pending.get("command",[])
    require(claim.get("schema")=="bth.qa_launch_claim/v1" and claim.get("manifest_sha256")==manifest_sha and
        pending.get("schema")=="bth.qa_guarded_run/v1" and pending.get("status")=="LAUNCH_PENDING" and
        pending.get("storage_manifest_sha256")==manifest_sha and len(command)>=4 and command[1]=="-B" and
        plain(command[0])==plain(sys.executable) and plain(command[2])==plain(__file__) and command[3:]==sys.argv[1:] and
        sha(plain(sys.executable))=="3093fcf263029ca1d799fea250a4e032d2c930a516f1513eeca688b343c836b3",
        "Exact claimed maintained parent Job/command/canonicalPython required")
    claim_sha=sha(claim_path); helper_sha=sha(plain(__file__))
    source=read_json(HISTORICAL_MOTION/"kitty_animation_probe.json")
    ids=tuple(row["id"] for row in source["entries"])
    require(len(ids)==len(set(ids))==27,"Pinned original27 historical motion IDs required")
    result=historical_parity(ids)
    require(sha(manifest_path)==manifest_sha and sha(claim_path)==claim_sha and sha(plain(__file__))==helper_sha,
        "Parity worker/storage/claim changed during calculation")
    validate_layout(layout,extra_write_paths=(evidence,))
    require(not out.exists(),"Historical parity output cannot overwrite")
    record={"schema":"bth.kitty_historical_occlusion_parity/v1",**result,
        "worker_sha256":helper_sha,"python_sha256":sha(plain(sys.executable)),
        "storage_manifest_sha256":manifest_sha,"launch_claim_sha256":claim_sha,
        "storage_gate":gate,"historical_reference_only":True,"fresh_candidate_or_QA_inputs_read":False,
        "requires_parent_closed_capped_job_qualification":True,"art_or_native_or_TEST_approval":False}
    payload=(json.dumps(record,sort_keys=True,indent=2)+"\n").encode()
    with out.open("xb") as output:
        output.write(payload)
    validate_layout(layout,extra_write_paths=(evidence,))
    require(out.read_bytes()==payload,"New historical parity receipt changed after exclusive write")
    return {"status":result["status"],"path":str(out),"sha256":sha(out),"checks":135,
        "closed_capped_parent_qualification_still_required":True}


def main(argv=None):
    args=parse_args(argv)
    try:
        print(json.dumps(historical_worker(args),sort_keys=True))
        return 0
    except (OSError,ValueError,KeyError,RuntimeError,TypeError) as error:
        print(json.dumps({"status":"KITTY_HISTORICAL_PARITY_STOPPED","error":str(error),"fallback_attempted":False}),file=sys.stderr)
        return 1


if __name__=="__main__":
    raise SystemExit(main())


