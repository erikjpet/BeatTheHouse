"""GBR diagnostic-custody contracts. No visual, native-suite or release authority.

All future candidate inputs must exist and be explicitly pinned before admission.
This module writes nothing and starts no children. Frozen R1/R2 laws stay intact.
"""
import sys
sys.dont_write_bytecode = True

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re

import bth_qa_selected_source_v2 as selected
from bar_spatial_candidate_check import decode_png
import grand_back_room_spatial_native_profile as original

ROOT = Path("E:/CodexQA/BTH")
PROJECT = Path(__file__).absolute().parents[1]
ROOM = "grand_casino_back_room"
ART = "assets/art/environments/"+ROOM+"/"
MANIFEST = "data/art/environments/"+ROOM+".json"
INDEX = "data/art/environments/index.json"
TASK = "BTH-ENV-SPATIAL-GBR-001"
SCHEMA = "bth.gbr_composition_preview_custody/v1"
BASE_SOURCE = "ea66f879a6a340fba2716d27e27b777a58bb200e"
BASE_TREE = "f0a6f3c8a5bd890784b4aca77e6886c91aae0c64"
BASE_SEAL = "e20695c6715e4156027cc211b6c7291ff2820e3d52d317dbbfc9b6cc5ca931c7"
DESCRIPTOR = PROJECT/"review_artifacts/environment_art_sources/grand-back-room-composition-r3/raw-materialization-descriptor.json"
DESCRIPTOR_SHA = "4644a1a159b98d11d869d0854e96a12bb6899b2b204eac08accf255e82e4279a"
RAW_PRESERVATION = PROJECT/"docs/testing/grand_back_room_composition_r3_raw_preservation_20261116.json"
RAW_PRESERVATION_SHA = "2cbb06d143203c8e492ada9ec476cff71ebe88fb3b10fb7a0e557db3bd990ecb"
FIXED_SOURCE = ROOT/"workspaces/BTH-ENV-SPATIAL-GBRBUILD-20261116/qa_source"
FIXED_MANIFEST = FIXED_SOURCE/".tmp/web-release-e07ca928/stage/build_manifest.json"
FIXED_MANIFEST_SHA = "00e1251b4e4580429fb57a764831ab8a7d7ad224f81a06b671c75415e467a215"
RUNTIME_COUNT = 1986
RUNTIME_SHA = "74e34e7948a8fda390259ce61f3b3358ab6efc173e89b2bf14f573bcb4521cba"
CONTEXT_EVIDENCE = ROOT/"runs/BTH-ENV-SPATIAL-GBRNATIVE-20261116-v3-contexts/evidence"
CONTEXT_SHA = "6a7a6717c948b8e5dcd4d8a78bbbfacaf12d0303496531f7df7c98bde08b9870"
OLD_IDENTITY = ROOT/"workspaces/BTH-ENV-SPATIAL-GBRTRIAL-20261116/qa_source/grandback_spatial_source_identity.json"
OLD_IDENTITY_SHA = "2794328aaef0818cd7ccee0774343eab50642f43ea17ad93afed9c05a9506c4d"
CAPTURE = ROOT/"runs/BTH-ENV-SPATIAL-GBRNATIVE-20261116-v3-capture/evidence/capture/animation_capture.json"
CAPTURE_SHA = "3342ed79ece4a408f567cfae8afbdab01bd1612d441a623e24ed2086e8908afd"
PAINT_PINS = {
    "__none_host_0_body.png":"00796388634d8a17b03db46d2f1eb1c3bf3fd1916b9058b056e28ff3abc999e2",
    "__none_host_0_adorn.png":"ce3346ab23b7c7c964eb9610cba8e57000bece61e0eeb3fe4a243d9b530c8a20",
    "__none_host_1_body.png":"9f4dac08430771743a540d112b014616c13fa06d968a75840eae41a2f40a88a9",
    "__none_host_1_adorn.png":"0c1361b7664e6d1b28d32169d9befd23c7cdd340241f2e7f86ac780274f6836f",
    "__none_host_2_body.png":"9e48e21dc14348a228fe4dac02a90453c45769df952f76f0b558f43649efc439",
    "__none_host_2_adorn.png":"8dc5d8c5c33d86604d6226a735ecbf73004c5f0c5e846047e8e079a10f422ce5"}
PAINT_HOSTS = {"game:craps":"__none_host_0","game:blackjack":"__none_host_1","travel:leave":"__none_host_2"}
PROTECTED_CONTROLS = ("data/environments/placement_surfaces.json","data/environments/developer_placement_overrides.json",
    "scripts/ui/pixel_scene_canvas.gd","scripts/ui/environment_art_renderer.gd","scripts/ui/environment_art_pack.gd",
    "scripts/core/environment_placement.gd","scripts/ui/game_props/craps_room_prop.gd","scripts/ui/game_props/game_prop_kit.gd")
RAW_RECTS = {"grand_table_left":[82,258,272,36],"grand_table_right":[546,258,272,36]}
ANIMATION_IDS = tuple(original.ANIMATION_IDS)
LOW_IDS = tuple(original.LOW_IDS)
OBJECT_IDS = {"game:craps","game:blackjack","travel:leave"}
EXTERNAL_GDS = tuple(n for n in original.HELPERS if n.startswith("tools/envart_grandback_"))
PNG_CHANGES = {ART+"background.png",*(ART+"counters/"+n+".png" for n in RAW_RECTS)}
LIMITS = {"visual_acceptance":False,"formal_native_acceptance":False,"release_approval":False,
    "TEST_updated":False,"browser_acceptance":"NOT_RUN","scope":"GBR_BASE_COMPOSITION_ONLY"}


def require(value,message):
    if not value: raise ValueError(message)


def sha(path):
    return selected.file_sha(path)


def full_hash(value,length=64):
    require(isinstance(value,str) and re.fullmatch("[0-9a-f]{%d}"%length,value) and set(value)!={"0"},"Full nonzero hash required")


def same_typed(a,b):
    return type(a) is type(b) and (set(a)==set(b) and all(same_typed(a[k],b[k]) for k in a) if isinstance(a,dict) else
        len(a)==len(b) and all(same_typed(x,y) for x,y in zip(a,b)) if isinstance(a,list) else a==b)


def parse_json(raw):
    def pairs(rows):
        result={}
        for k,v in rows:
            require(k not in result,"Duplicate JSON key: "+k);result[k]=v
        return result
    value=json.loads(raw,object_pairs_hook=pairs,parse_constant=lambda v:(_ for _ in ()).throw(ValueError("Nonfinite JSON")))
    # Numeric overflow such as1e999 bypasses parse_constant. Validate finiteness
    # recursively without replacing or reserializing the input artifact bytes.
    json.dumps(value,allow_nan=False)
    return value


def read(path,limit=64*1024**2):
    path=selected.plain(path,file=True)
    require(path.stat().st_size<=limit,"Bounded evidence file required")
    return parse_json(path.read_bytes())


def read_ref(ref):
    require(isinstance(ref,dict),"Actual reference required")
    full_hash(ref.get("sha256"));path=selected.plain(ref["path"],file=True)
    require(sha(path)==ref["sha256"],"Referenced bytes differ: "+str(path))
    return path


def seal(files):
    return hashlib.sha256("\n".join(n+" "+files[n] for n in sorted(files)).encode()).hexdigest()


def descriptor_controls():
    require(sha(DESCRIPTOR)==DESCRIPTOR_SHA,"Exact original raw descriptor required")
    value=read(DESCRIPTOR);files=value["original_controls"]
    require(len(files)==21 and seal(files)==BASE_SEAL and MANIFEST in files and INDEX in files,"Actual current21 baseline required")
    return value,files


def exact_inventory(root,expected,auxiliary=None):
    root=selected.plain(root);expected={**expected,**(auxiliary or {})}
    allowed_dirs={p.as_posix() for n in expected for p in Path(n).parents if str(p)!="."}
    observed={};pending=[root]
    while pending:
        parent=pending.pop()
        for child in parent.iterdir():
            name=child.relative_to(root).as_posix()
            require(name in expected or name in allowed_dirs,"Unexpected physical member before descent: "+name)
            child=selected.plain(child)
            if child.is_dir():
                require(name in allowed_dirs,"Unexpected directory");pending.append(child)
            else:
                selected.plain(child,file=True);require(name in expected,"Unexpected file");observed[name]=sha(child)
    require(observed==expected,"Exact physical candidate/source membership differs")
    return observed


def check_custody_declaration(value):
    require(value.get("schema")==SCHEMA and value.get("task_id")==TASK and value.get("room")==ROOM and
        value.get("verdict")=="ADMIT_DIAGNOSTIC_RENDER_ONLY" and value.get("authority")=="/root" and
        same_typed(value.get("limits"),LIMITS),"Explicit root diagnostic custody; no art/release GO required")
    require(value.get("source_base")=={"commit":BASE_SOURCE,"tree":BASE_TREE},"Only chosen ea66/f0a6 base admitted")
    for group in ("assembly_proof","assembly_job","assembler","recipe","material_review","raw_preservation"):
        require(isinstance(value.get(group),dict) and set(value[group])>={"path","sha256"},"Missing actual input: "+group)
        full_hash(value[group]["sha256"])
    candidate=value.get("candidate")
    require(isinstance(candidate,dict) and set(candidate)>={"root","files","seal"},"Actual assembled candidate required")
    full_hash(candidate["seal"])
    require(isinstance(value.get("assembly_command"),list) and value["assembly_command"],"Exact actual assembly argv required")
    require(isinstance(value.get("driver_helpers"),dict) and value["driver_helpers"],"Exact new driver source pins required")
    return {**LIMITS,"custody_shape_only":True}


def check_manifest(original_value,candidate):
    require(original_value.get("environment_id")==ROOM and len(original_value.get("animations",[]))==16 and
        [v["id"] for v in original_value["animations"]]==list(ANIMATION_IDS) and
        [v["id"] for v in original_value["animations"] if v.get("web_low_detail",True)]==list(LOW_IDS),"Original16/7 manifest required")
    require(set(original_value["counters"])==set(candidate.get("counters",{}))==set(RAW_RECTS),"Exactly two existing counter IDs required")
    expected=deepcopy(original_value);rectangles={}
    for key,raw in RAW_RECTS.items():
        entry=candidate["counters"][key];bleed=entry.get("bleed")
        require(type(bleed) is list and len(bleed)==4 and all(type(n) is int and n>=0 for n in bleed),"Four nonnegative integer art bleeds required")
        expected["counters"][key]["bleed"]=bleed
        x,y,w,h=raw;l,t,r,b=bleed;grown=[x-l,y-t,w+l+r,h+t+b];native=[2*v for v in grown]
        require(native[0]>=0 and native[1]>=0 and native[0]+native[2]<=1800 and native[1]+native[3]<=860,"Entire grown artwork must be inside master")
        rectangles[key]={"raw_rect_board":raw,"bleed_board":bleed,"grown_rect_board":grown,"grown_rect_native":native}
    require(same_typed(candidate,expected),"Only the two bleed additions may change parsed manifest")
    return rectangles


def row_mask(value):
    require(set(value)=={"schema","canvas","coordinates","runs"} and value["schema"]=="bth.native_row_runs/v1" and
        value["canvas"]==[1800,860] and value["coordinates"]=="absolute_native_xy" and type(value["runs"]) is list,"Canonical native row-runs required")
    mask=bytearray(1800*860);last=None
    for row in value["runs"]:
        require(type(row) is list and len(row)==3 and all(type(v) is int for v in row),"Integer row-run triples required")
        y,x0,x1=row;require(0<=y<860 and 0<=x0<x1<=1800,"Mask outside native canvas")
        require(last is None or y>last[0] or y==last[0] and x0>last[2],"Rows must be sorted, disjoint and maximally merged")
        mask[y*1800+x0:y*1800+x1]=b"\1"*(x1-x0);last=row
    return mask


def mask_ref(ref,allow_empty=False):
    path=read_ref(ref);mask=row_mask(read(path));count=sum(mask)
    require(allow_empty or count>0,"Required semantic mask cannot be empty")
    expected=ref.get("pixels",ref.get("solid_pixels"))
    require(type(expected) is int and expected==count,"Actual mask count differs")
    return mask


def check_master(original_image,master,edit_mask):
    require((original_image.width,original_image.height)==(master.width,master.height)==(1800,860) and
        len(original_image.rgba)==len(master.rgba)==1800*860*4 and len(edit_mask)==1800*860 and
        set(edit_mask)<={0,1} and set(master.rgba[3::4])=={255},"Opaque1800 master and exact edit mask required")
    changed=0
    for at in range(1800*860):
        p=at*4
        if original_image.rgba[p:p+4]!=master.rgba[p:p+4]:
            require(edit_mask[at]==1,"Master changed outside approved edit union");changed+=1
    require(changed>0,"New composition must change actual master pixels")
    return {"changed_pixels":changed,"outside_edit_union_exact":True}


def check_replay_rgba(master,image,counter_id,bleed,physical,negative):
    require(counter_id in RAW_RECTS and type(bleed) is list and len(bleed)==4 and
        all(type(v) is int and v>=0 for v in bleed),"Existing counter and integer bleed required")
    raw=RAW_RECTS[counter_id];x,y,w,h=raw;l,t,r,b=bleed
    x,y,w,h=[2*v for v in (x-l,y-t,w+l+r,h+t+b)]
    require(x>=0 and y>=0 and x+w<=1800 and y+h<=860 and (image.width,image.height)==(w,h) and
        (master.width,master.height)==(1800,860) and len(master.rgba)==1800*860*4 and len(image.rgba)==w*h*4 and
        len(physical)==1800*860 and set(physical)<={0,1} and set(negative)=={"floor","under_table","office"},"Replay registration/masks differ")
    for yy in range(0,860,2):
        a=physical[yy*1800:(yy+1)*1800];bb=physical[(yy+1)*1800:(yy+2)*1800]
        require(a==bb and a[::2]==a[1::2],"Physical alpha must be exact native2x2 blocks")
    require(all(len(m)==1800*860 and sum(m)>0 for m in negative.values()),"Explicit nonempty global semantic negatives required")
    solid=0;intersections={k:0 for k in negative};overlap={k:0 for k in negative}
    for yy in range(860):
        for xx in range(1800):
            at=yy*1800+xx
            if not(x<=xx<x+w and y<=yy<y+h):
                require(not physical[at],"Physical component cropped outside replay");continue
            p=((yy-y)*w+xx-x)*4;alpha=image.rgba[p+3]
            require(alpha in (0,255) and (alpha==255)==bool(physical[at]),"Actual alpha differs from reviewed furniture mask")
            if alpha:
                require(image.rgba[p:p+4]==master.rgba[at*4:at*4+4],"Solid replay RGB differs from registered master")
                solid+=1
            else:require(image.rgba[p:p+4]==b"\0\0\0\0","Transparent RGBA must be canonical zero")
            for key,mask in negative.items():
                if mask[at]:
                    intersections[key]+=1;overlap[key]+=int(bool(alpha));require(alpha==0,"Opaque furniture copied into semantic negative: "+key)
    require(solid>0 and solid<w*h and intersections["floor"]>0 and intersections["under_table"]>0,"Furniture needs real body and exposed-floor holes")
    return {"solid_pixels":solid,"transparent_pixels":w*h-solid,"grown_rect_native":[x,y,w,h],
        "negative_intersections":intersections,"negative_opaque_pixels":overlap,"rgb_matches_master":True,"nn2_exact":True}


def check_material_contract(material,baseline_layout):
    """Pure structural contract; load_admission separately authenticates artifacts."""
    require(same_typed(material.get("coordinate_system"),{"board":[900,430],"native":[1800,860],"pixel_scale":2}) and
        set(material.get("counters",{}))==set(RAW_RECTS),"Full material coordinate/two-counter contract required")
    band=material["floor_band"];require(same_typed(band.get("native_y"),[604,616]) and
        band.get("outside_approved_union_exact") is True and band.get("source_material_rows"),"Explicit silver-band/provenance contract required")
    master=material["master"]
    require(master.get("opaque") is True and master.get("outside_edit_union_exact") is True and master.get("every_change_sourced") is True and
        type(master.get("changed_pixels")) is int and master["changed_pixels"]>0,"Actual changed-master/exterior/donor contract required")
    contacts=material["paint_contacts"]
    require(contacts.get("controls_unchanged") is True and same_typed(contacts.get("native_layout"),baseline_layout) and
        set(contacts.get("typed_paint_masks",{}))==OBJECT_IDS and
        set(contacts.get("support_required_masks",{}))==set(contacts.get("support_surface_masks",{}))=={"game:blackjack","game:craps"},
        "Exact actual layout/three typed pairs/two support proofs required")
    for pair in contacts["typed_paint_masks"].values():
        require(set(pair)=={"body","adorn"},"Exact typed body/adornment provenance required")
    motion=material["motion_controls"]
    require(type(motion.get("native_count")) is int and motion["native_count"]==16 and type(motion.get("low_count")) is int and motion["low_count"]==7 and
        motion.get("ordered_ids")==list(ANIMATION_IDS) and motion.get("original_rows_equal") is True and motion.get("animation_pngs_equal") is True,
        "Original16/7/motion rows and textures required")
    protected=material["protected_controls"]
    require(protected.get("all_equal") is True and type(protected.get("files")) is list and protected["files"] and
        len(set(protected["files"]))==len(protected["files"]) and set(protected["files"])==set(protected["before"]) and
        same_typed(protected["before"],protected["after"]),"Protected control file equality required")
    return {**LIMITS,"material_contract_declaration_only":True}


def check_contact_masks(support,surface,body_rgba,physical,contact_native,master_rgba=None):
    require(len(support)==len(surface)==len(physical)==1800*860 and len(body_rgba)==1800*860*4 and
        all(set(m)<={0,1} and sum(m)>0 for m in (support,surface,physical)),"Nonempty exact native support masks required")
    for i,v in enumerate(support):
        require(bool(v)==(body_rgba[i*4+3]==255),"Support selection must include every actual opaque body pixel, without adding shadows")
        if v:require(surface[i],"Actual opaque game paint lacks felt support")
    require(all(not v or physical[i] for i,v in enumerate(surface)),"Candidate support surface lies outside real furniture")
    if master_rgba is not None:
        require(len(master_rgba)==1800*860*4,"Actual native master required for green-felt predicate")
        for i,v in enumerate(surface):
            r,g,b,a=master_rgba[i*4:i*4+4]
            require(bool(v)==bool(physical[i] and a==255 and g>25 and 4*g>5*r and 20*g>21*b),
                "Support surface must equal actual registered green felt, not a declared rectangle")
    x,y=contact_native
    require(type(x) is int and type(y) is int and 0<=x<1800 and 0<=y<860 and surface[y*1800+x],"Actual saved game contact lacks supported surface")
    return {"support_pixels":sum(support),"surface_pixels":sum(surface),"actual_contact_supported":True,
        "all_actual_opaque_body_pixels_selected":True,"felt_predicate_recomputed":master_rgba is not None,
        "scope":"All retained body alpha255 pixels; translucent shadows/adornments and other clocks remain separate"}


def check_floor_masks(original_image,master,physical,office,band_masks):
    """Independent Office preservation and actual furniture-band intersections."""
    require(set(physical)==set(band_masks)==set(RAW_RECTS) and len(office)==1800*860 and
        set(office)<={0,1} and sum(office)>0 and len(original_image.rgba)==len(master.rgba)==1800*860*4,
        "Actual Office/furniture/floor-band witnesses required")
    for i,v in enumerate(office):
        if v:
            require(original_image.rgba[i*4:i*4+4]==master.rgba[i*4:i*4+4] and
                all(not m[i] for m in physical.values()),"Original Office physical pixels changed or were replay-masked")
    counts={}
    for key in RAW_RECTS:
        mask=band_masks[key]
        require(len(mask)==1800*860 and set(mask)<={0,1} and
            all(bool(v)==bool(physical[key][i] and 604<=i//1800<616) for i,v in enumerate(mask)),
            "Silver-band intersection must equal actual furniture pixels at y604..616")
        counts[key]=sum(mask)
    return {"office_original_pixels":sum(office),"office_rgb_exact":True,"band_solid_pixels":counts,
        "exposed_floor_alpha_checked_separately":True,"floor_616_join_visual_acceptance":False}


def check_donor_ledger(ledger,raw,original_image,master,edit):
    """Replay an explicit pixel ledger, without deriving the recipe transforms."""
    require(ledger.get("schema")=="bth.native_block_donors/v1" and same_typed(ledger.get("block"),[2,2]) and
        ledger.get("ordered_last_write_wins") is True and ledger.get("columns")==
        ["target_x","target_y","width","height","source","source_x","source_y","component"] and
        (raw.width,raw.height)==(1815,867) and len(raw.rgba)==1815*867*4 and
        (original_image.width,original_image.height)==(master.width,master.height)==(1800,860) and
        len(edit)==1800*860 and type(ledger.get("rows")) is list and 0<len(ledger["rows"])<=1800*860,
        "Exact bounded raw-to-native block ledger required")
    out=bytearray(original_image.rgba);coverage=bytearray(1800*860)
    for row in ledger["rows"]:
        require(type(row) is list and len(row)==8 and all(type(row[i]) is int for i in (0,1,2,3,5,6)),"Typed block donor row required")
        x,y,w,h,source,sx,sy,component=row
        require(w==h==2 and x%2==y%2==0 and 0<=x<1799 and 0<=y<859 and source=="raw" and
            0<=sx<1815 and 0<=sy<867 and isinstance(component,str),"Block donor source/target registration differs")
        require(component.startswith("furniture:") or component=="clean_floor_corridor","Unreviewed donor component")
        if component=="clean_floor_corridor":
            require(4<=x<1796 and 330<=y<616 and 754<=sx<1060 and 366<=sy<640,"Floor donor left actual clean corridor")
        pixel=raw.rgba[(sy*1815+sx)*4:(sy*1815+sx+1)*4]
        for yy in (y,y+1):
            at=yy*1800+x;out[at*4:(at+2)*4]=pixel*2;coverage[at:at+2]=b"\1\1"
    require(coverage==edit and out==master.rgba,"Actual master/edit mask does not equal final last-write-wins raw donor ledger")
    return {"rows":len(ledger["rows"]),"donor_covered_pixels":sum(coverage),"actual_RGBA_recomposed":True,
        "recipe_transform_independently_rederived":False}


def runtime_path(name):
    if name in EXTERNAL_GDS or name.endswith(".uid") and name[:-4] in EXTERNAL_GDS:return False
    return (name.startswith(("scripts/","scenes/","native/")) or
        name.startswith("data/") and not name.startswith("data/art/environments/") or
        name.startswith("tools/") and name.endswith((".gd",".gd.uid")) or name in ("project.godot","export_presets.cfg","default_bus_layout.tres"))


def runtime_controls(root):
    root=selected.plain(root);result={};pending=[root]
    while pending:
        parent=pending.pop()
        for child in parent.iterdir():
            n=child.relative_to(root).as_posix()
            if child.name in (".godot",".git",".tmp","qa_reference"):continue
            child=selected.plain(child)
            if child.is_dir():pending.append(child)
            elif runtime_path(n):result[n]=sha(selected.plain(child,file=True))
    return result


def validate_runtime(root):
    expected=runtime_controls(FIXED_SOURCE)
    require(len(expected)==RUNTIME_COUNT and selected.digest(expected)==RUNTIME_SHA,"Immutable delivered runtime-control source changed")
    require(runtime_controls(root)==expected,"Production data/code/900GD/assertion controls differ")
    return {"files":RUNTIME_COUNT,"sha256":RUNTIME_SHA,"all900_production_GD_preserved":True}


def fixed_art():
    require(sha(FIXED_MANIFEST)==FIXED_MANIFEST_SHA,"Fixed421raw manifest changed")
    value=read(FIXED_MANIFEST);require(len(value["art_source_files"])==421,"Fixed421 raw inventory required")
    return value["art_source_files"]


def validate_project(root,candidate_files=None):
    runtime=validate_runtime(root);expected={**fixed_art(),**(candidate_files or {})}
    require(all(sha(Path(root)/n)==h for n,h in expected.items()),"Source changes outside exact composition overlay")
    return {"runtime_controls":runtime,"all421_art_sources_verified":True,"overlay_files":candidate_files or {}}


def check_context_report(report,source_files):
    require(type(source_files) is int and source_files>0 and not report.get("findings") and not report.get("failures") and
        report.get("checks")==2*source_files+41 and report.get("direct_catalog")==["__none"] and set(report.get("views",{}))=={"__none"},
        "Unchanged original complete Base context report required")
    view=report["views"]["__none"];ids={r["id"] for r in view["actual_view"]["objects"]}
    require(len(view["actual_view"]["objects"])==3 and ids=={r["id"] for r in view["selected_label_evidence"]}==
        {r["object"]["id"] for r in view["source_paint"]["objects"]}==OBJECT_IDS and
        len(view["selected_label_evidence"])==len(view["source_paint"]["objects"])==3 and
        view["source_paint"]["geometry_equal"] is True and view["arrival"]["remaining_person_transits"]==0,
        "Actual three populated objects/native paint/selections/arrival differ")
    require(sha(CONTEXT_EVIDENCE/"grand_casino_back_room_preart_metadata.json")==CONTEXT_SHA,"Pinned old layout evidence changed")
    old=read(CONTEXT_EVIDENCE/"grand_casino_back_room_preart_metadata.json")["views"]["__none"]
    require(same_typed(view["actual_view"]["object_layout"],old["actual_view"]["object_layout"]),"Actual resolved anchors/layout/hit/labels moved")
    stable=("id","type","position","size","fixed_slot_geometry","slot_id")
    for current_rows,old_rows in ((view["actual_view"]["objects"],old["actual_view"]["objects"]),
        ([r["object"] for r in view["source_paint"]["objects"]],[r["object"] for r in old["source_paint"]["objects"]])):
        require([r["id"] for r in current_rows]==[r["id"] for r in old_rows],"Actual/native-paint stable order differs")
        for current,prior in zip(current_rows,old_rows):
            require(all(same_typed(current.get(k),prior.get(k)) for k in stable),"Stable diagnostic position/size/type differs; never parse or promote serialized geometry")
    return {**LIMITS,"populated_objects":3,"checks":report["checks"],"resolved_layout_equal":True,
        "stable_serialized_diagnostics_equal":True,"serialized_diagnostics_are_native_Vector2_proof":False}


def archived_context_control():
    require(sha(OLD_IDENTITY)==OLD_IDENTITY_SHA,"Actual archived source-count identity differs")
    identity=read(OLD_IDENTITY)
    require(identity["source_commit"]=="a9c02a9557abfd644b27f36be392d354fc70c6ef" and
        identity["source_tree"]=="edcf685c282567daa2bb82a6ba49d818e5950ed6","Archived report must use its own actual source cohort")
    report=read(CONTEXT_EVIDENCE/"grand_casino_back_room_preart_metadata.json")
    value=check_context_report(report,len(identity["files"]))
    return {"report_sha256":CONTEXT_SHA,"identity_sha256":OLD_IDENTITY_SHA,"source_files":len(identity["files"]),
        "checks":value["checks"],"positive_control_only":True,**LIMITS}


def load_admission(path,expected_sha):
    path=selected.plain(path,file=True);full_hash(expected_sha)
    require(path.is_relative_to(PROJECT/"docs/testing") and sha(path)==expected_sha,"Exact root custody document required")
    value=read(path);check_custody_declaration(value)
    controls={str(path):expected_sha,str(DESCRIPTOR):DESCRIPTOR_SHA}
    descriptor,baseline=descriptor_controls()
    refs={k:read_ref(value[k]) for k in ("assembly_proof","assembly_job","assembler","recipe","material_review","raw_preservation")}
    require(refs["raw_preservation"]==RAW_PRESERVATION and sha(RAW_PRESERVATION)==RAW_PRESERVATION_SHA,"Actual closed raw-preservation index required")
    proof=read(refs["assembly_proof"]);job=read(refs["assembly_job"]);recipe=read(refs["recipe"])
    require(selected.qualified_job(job) and job["command"]==value["assembly_command"] and len(job["command"])>=3 and
        job["command"][1]=="-B" and selected.same_path(job["command"][2],refs["assembler"]) and
        refs["assembly_job"].parent==refs["assembly_proof"].parent and refs["assembly_proof"].is_relative_to(ROOT/"runs"),"Exact closed guarded assembly producer required")
    manifest_path=selected.plain(job["storage_manifest"],file=True);storage=read(manifest_path);claim_path=refs["assembly_job"].parent/"launch-claim.json";claim=read(claim_path)
    require(storage["schema"]=="bth-qa-storage/v1" and storage["prepared"] is True and storage["expected_write_bytes"]==4*1024**3 and
        storage["reserve_bytes"]==20*1024**3 and selected.same_path(storage["paths"]["evidence"],refs["assembly_job"].parent) and
        claim["schema"]=="bth.qa_launch_claim/v1" and job["storage_manifest_sha256"]==claim["manifest_sha256"]==sha(manifest_path),"Assembly storage/claim custody differs")
    expected_base={**value["source_base"],"package_seal":BASE_SEAL}
    require(proof["schema"]=="bth.gbr_composition_assembly/v1" and proof["room"]==ROOM and type(proof["assembly_version"]) is int and proof["assembly_version"]==3 and
        proof["source_base"]==recipe["source_base"]==expected_base and proof["recipe_sha256"]==value["recipe"]["sha256"] and
        proof["assembler_sha256"]==value["assembler"]["sha256"],"Actual new assembly proof/source/recipe differs")
    require(proof["source_baseline"]["files"]==baseline and proof["source_baseline"]["seal"]==BASE_SEAL and
        proof["source_baseline"]["room_file_count"]==20 and proof["source_baseline"]["index_control_count"]==1,"Current21 baseline differs")
    candidate=selected.plain(value["candidate"]["root"]);base=selected.plain(proof["source_baseline"]["path"])
    require(candidate.is_relative_to(ROOT/"workspaces") and base.is_relative_to(ROOT/"workspaces") and candidate!=base and not candidate.is_relative_to(base) and not base.is_relative_to(candidate) and
        selected.same_path(proof["output"]["path"],candidate) and proof["output"]["files"]==value["candidate"]["files"] and
        set(value["candidate"]["files"])==set(baseline) and seal(value["candidate"]["files"])==proof["output"]["seal"]==value["candidate"]["seal"],"Actual disjoint sealed overlay differs")
    files=value["candidate"]["files"]
    require({n for n in files if files[n]!=baseline[n]}==PNG_CHANGES|{MANIFEST},"Only BG/two replays/bleed JSON may change")
    auxiliary=proof["source_baseline"].get("auxiliary_files",{})
    require(auxiliary=={".gdignore":hashlib.sha256(b"# Non-active GBR composition R3 source/candidates; exclude from Godot discovery.\n").hexdigest()},
        "Exact declared baseline ignore sentinel required")
    exact_inventory(base,baseline,auxiliary);exact_inventory(candidate,files)
    old_json=read(base/MANIFEST);new_json=read(candidate/MANIFEST);rects=check_manifest(old_json,new_json)
    master=decode_png((candidate/(ART+"background.png")).read_bytes());old_master=decode_png((base/(ART+"background.png")).read_bytes())
    material=proof["material_proof"]
    archived=read(CONTEXT_EVIDENCE/"grand_casino_back_room_preart_metadata.json")
    require(sha(CONTEXT_EVIDENCE/"grand_casino_back_room_preart_metadata.json")==CONTEXT_SHA,"Pinned actual contact layout changed")
    check_material_contract(material,archived["views"]["__none"]["actual_view"]["object_layout"])
    mm=material["master"]
    require(selected.same_path(mm["path"],candidate/(ART+"background.png")) and mm["sha256"]==files[ART+"background.png"] and
        same_typed(mm["dimensions"],[1800,860]),"Master proof must bind actual candidate background")
    edit=mask_ref(material["master"]["edit_union"]);metrics={"master":check_master(old_master,master,edit),"counters":{}}
    require(mm["changed_pixels"]==metrics["master"]["changed_pixels"],"Actual changed pixel count differs")
    physical_masks={};office_masks={}
    for key,geometry in rects.items():
        row=material["counters"][key];texture=ART+new_json["counters"][key]["texture"]
        require(all(same_typed(row[n],v) for n,v in geometry.items()) and row["texture_rel"]==texture and row["texture_sha256"]==files[texture],"Material geometry/source registration differs")
        require(recipe["counters"][key]["raw_rect_board"]==geometry["raw_rect_board"] and
            same_typed(recipe["counters"][key]["bleed_board"],geometry["bleed_board"]) and row["rgb_matches_master"] is True,
            "Actual replay must use the reviewed recipe registration")
        physical=mask_ref(row["physical_mask"]);negative={n:mask_ref(row["negative_space"][n]) for n in ("floor","under_table","office")}
        physical_masks[key]=physical;office_masks[key]=negative["office"]
        result=check_replay_rgba(master,decode_png((candidate/texture).read_bytes()),key,row["bleed_board"],physical,negative)
        pm=row["physical_mask"]
        require(pm["format"]=="bth.native_row_runs/v1" and same_typed(pm["dimensions"],[1800,860]) and same_typed(pm["alpha_values"],[0,255]) and
            pm["nn2_exact"] is True and type(pm["solid_pixels"]) is int and type(pm["transparent_pixels"]) is int and
            pm["solid_pixels"]==result["solid_pixels"] and pm["transparent_pixels"]==result["transparent_pixels"],"Computed actual replay pixel counts differ")
        components=row["component_masks"]
        require(isinstance(components,dict) and set(components)==set(recipe["counters"][key]["source_components"]) and
            {"top_and_rail","apron","front_leg_left","front_leg_right","foot_left","foot_right"}<=set(components),
            "Reviewed complete body/support component masks required")
        union=bytearray(1800*860)
        for name,spec in components.items():
            mask=mask_ref(spec);require(all(not v or physical[i] for i,v in enumerate(mask)),"Clipped/nonfurniture component")
            if name in ("foot_left","foot_right"):
                require(any(mask[697*1800:]),"Actual registered foot was compressed above retained contact extent")
            union=bytearray(a|b for a,b in zip(union,mask))
        require(union==physical,"Complete reviewed body/legs/feet must equal physical silhouette")
        metrics["counters"][key]=result
    band=material["floor_band"];office=mask_ref(band["protected_mask"])
    require(all(m==office for m in office_masks.values()),"Office exclusion masks must share exact protected silhouette")
    band_masks={k:mask_ref(v,allow_empty=True) for k,v in band["solid_intersections"].items()}
    metrics["floor"]=check_floor_masks(old_master,master,physical_masks,office,band_masks)
    contacts=material["paint_contacts"]
    require(selected.same_path(read_ref(contacts["baseline_capture"]),CAPTURE) and contacts["baseline_capture"]["sha256"]==CAPTURE_SHA and
        selected.same_path(read_ref(contacts["baseline_context_report"]),CONTEXT_EVIDENCE/"grand_casino_back_room_preart_metadata.json") and
        contacts["baseline_context_report"]["sha256"]==CONTEXT_SHA and
        contacts["felt_predicate"]=="a==255 and g>25 and 4*g>5*r and 20*g>21*b","Actual retained contact cohort/predicate required")
    require(set(contacts["typed_paint_alpha_masks"])==set(PAINT_PINS),"All actual retained body/adornment alpha masks required")
    metrics["paint_contacts"]={}
    for object_id,host in PAINT_HOSTS.items():
        for kind in ("body","adorn"):
            name=host+"_"+kind+".png";ref=contacts["typed_paint_masks"][object_id][kind]
            p=read_ref(ref)
            require(selected.same_path(p,CONTEXT_EVIDENCE/name) and ref["sha256"]==PAINT_PINS[name],"Borrowed or altered actual native paint witness")
            image=decode_png(p.read_bytes());require((image.width,image.height)==(1800,860),"Actual native typed paint dimensions required")
            mask=mask_ref(contacts["typed_paint_alpha_masks"][name],allow_empty=True)
            require(all(bool(v)==(image.rgba[i*4+3]>0) for i,v in enumerate(mask)),"Recorded typed alpha mask differs from actual native PNG")
            if kind=="body" and object_id!="travel:leave":
                key="grand_table_left" if object_id=="game:blackjack" else "grand_table_right"
                contact=[428,496] if object_id=="game:blackjack" else [1360,494]
                support=mask_ref(contacts["support_required_masks"][object_id]);surface=mask_ref(contacts["support_surface_masks"][object_id])
                metrics["paint_contacts"][object_id]=check_contact_masks(support,surface,image.rgba,physical_masks[key],contact,master.rgba)
    review=read(refs["material_review"])
    require(review.get("schema")=="bth.gbr_composition_mask_review/v1" and review.get("verdict")=="ADMIT_PHYSICAL_MASK_CUSTODY_ONLY" and
        review.get("assembly_proof_sha256")==value["assembly_proof"]["sha256"] and review.get("recipe_sha256")==value["recipe"]["sha256"] and
        review.get("candidate_seal")==value["candidate"]["seal"] and review.get("visual_acceptance") is False and
        isinstance(review.get("reviewer"),str) and review["reviewer"].strip(),"Actual independent material/source review required; not visual GO")
    require(proof["custody"]["input_before"]==proof["custody"]["input_after"]==baseline and
        proof["custody"]["helper_hashes_before"]==proof["custody"]["helper_hashes_after"] and
        proof["custody"]["exact_physical_membership"] is True and
        proof["custody"]["active_files_written"] is False and proof["custody"]["children_launched"] is False,"Assembly protected/motion/input custody differs")
    for p,h in proof["custody"]["helper_hashes_before"].items():
        require(sha(selected.plain(p,file=True))==h,"Actual assembly source/helper witness changed");controls[str(Path(p))]=h
    protected=material["protected_controls"]
    require(protected["files"]==list(PROTECTED_CONTROLS),"Exact original placement/render/prop controls required")
    bridges={}
    for name in PROTECTED_CONTROLS:
        source=selected.plain(PROJECT/name,file=True);fixed=selected.plain(FIXED_SOURCE/name,file=True)
        require(sha(source)==protected["before"][name],"Actual read-only assembly source control changed")
        a,b=source.read_bytes(),fixed.read_bytes();normalized=False
        if a!=b:
            require(name.endswith(".gd") and a.replace(b"\r\n",b"\n")==b.replace(b"\r\n",b"\n") and
                b"\r" not in a.replace(b"\r\n",b"\n") and b"\r" not in b.replace(b"\r\n",b"\n"),
                "Assembly controls differ beyond explicit CRLF/LF-only bridge")
            normalized=True
        bridges[name]={"actual_D_sha256":sha(source),"immutable_E_sha256":sha(fixed),"CRLF_LF_only_equivalence":normalized}
        controls[str(source)]=sha(source);controls[str(fixed)]=sha(fixed)
    metrics["assembly_source_control_bridge"]=bridges
    raw=proof["raw_source"];raw_path=read_ref(raw)
    require(raw["sha256"]==descriptor["png"]["sha256"] and same_typed(raw["dimensions"],[descriptor["png"]["width"],descriptor["png"]["height"]]) and
        raw["prompt_sha256"]==descriptor["prompt"]["sha256"] and
        raw["provenance_sha256"]==descriptor["provenance"]["sha256"],"Actual materialized raw identity differs")
    ledger_path=read_ref({"path":mm["donor_ledger"],"sha256":mm["donor_ledger_sha256"]});ledger=read(ledger_path)
    require(ledger.get("sources")=={"raw":raw["sha256"]},"Ledger must bind the single actual raw source")
    metrics["donors"]=check_donor_ledger(ledger,decode_png(raw_path.read_bytes()),old_master,master,edit)
    controls[str(raw_path)]=raw["sha256"];controls[str(ledger_path)]=mm["donor_ledger_sha256"]
    for p in [*refs.values(),manifest_path,claim_path]:controls[str(p)]=sha(p)
    # Bind every referenced mask/ledger/contact/control artifact recursively; no
    # declaration-only mask may silently change after admission.
    def collect(v):
        if isinstance(v,dict):
            if {"path","sha256"}<=set(v):
                p=read_ref(v);controls[str(p)]=v["sha256"]
            for x in v.values():collect(x)
        elif isinstance(v,list):
            for x in v:collect(x)
    collect(material);collect(recipe);collect(descriptor);collect(review)
    return {"custody":value,"custody_path":str(path),"custody_sha256":expected_sha,"baseline_files":baseline,
        "candidate_root":str(candidate),"candidate_files":files,"source_baseline":str(base),"material_metrics":metrics,
        "control_sha256":controls,**LIMITS,"custody_authenticated_for_preview_only":True}
