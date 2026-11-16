"""Byte-only generated PNG materializer inside a parent's prepared capped Job.

No launcher, image transformation, network, child, cleanup, replacement or retry.
Descriptor authority is its explicit pinned D file hash, never an art approval.
The parent must authenticate the actual eventual closed CPU1200/2GiB Job.
"""
import sys
sys.dont_write_bytecode = True
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import struct
import zlib

import bth_qa_storage as storage

SOURCE = Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers")
ARTIFACTS = SOURCE/"review_artifacts/environment_art_sources"
QA = Path("E:/CodexQA/BTH")
SCHEMA = "bth.environment_spatial_raw_materialization/v1"
DESCRIPTOR_SCHEMA = "bth.environment_spatial_raw_descriptor/v1"
PYTHON_SHA = "3093fcf263029ca1d799fea250a4e032d2c930a516f1513eeca688b343c836b3"
HELPERS = {
    "bth_qa_storage.py":"cdc08bcb1ad0bff82bb5fd12f467c576cfc40a998f40870068cf6c684216f837",
    "bth_qa_guarded_run.py":"7ea6be8366f606995a1f69ddb26d99b4e3c47a0fcce9d968abe17b3dc074ad7e",
    "bth_qa_command_paths.py":"bbc405ac19ae803c2c15d93fee1ca059f25d06176cfee7926b2329b93ca4352b",
    "decode_apartment_spatial_raw.py":"0f55f8083928764c2243e71aa162b35282e45d6fbe3aa4ee44d78fecf52dd376",
    "decode_house_spatial_raw.py":"1300f37ccccb23790395641884d703bcf2d642a9a3b2387d812d7a9852f332a4",
    "decode_kitty_spatial_raw.py":"532ca2652b9f88f535a7f1d71a7b2f95ac5f2bd387e3961fc212c4ebfd848636",
}
MAX_PNG = 32*1024**2
MAX_B64 = 48*1024**2
ROOMS = frozenset(("gas_station_casino","corner_store","back_alley","motel","bar","pawn_shop",
    "jazz_club","punchline_club","small_underground_casino","kitty_cat_lounge","punchline_back_room",
    "delta_queen","beach","grand_casino","grand_casino_high_limit","grand_casino_back_room",
    "grand_casino_cage","motel_room","apartment","house"))


def require(value,message):
    if not value:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def full_hash(value):
    require(type(value) is str and re.fullmatch(r"[0-9a-f]{64}",value),"Full lowercase SHA256 required")


def plain(value):
    path=Path(value)
    require(path.is_absolute() and ".." not in path.parts and all(":" not in p for p in path.parts[1:]),
        "Explicit absolute ordinary path without streams required")
    for item in (path,*path.parents):
        try:
            info=item.lstat()
        except FileNotFoundError:
            continue
        require(not stat.S_ISLNK(info.st_mode) and not getattr(info,"st_file_attributes",0)&stat.FILE_ATTRIBUTE_REPARSE_POINT,
            "Linked/reparse path rejected: "+str(item))
        require(stat.S_ISREG(info.st_mode) or stat.S_ISDIR(info.st_mode),"Nonordinary path: "+str(item))
        if item!=path:
            require(stat.S_ISDIR(info.st_mode),"File used as ancestor: "+str(item))
    return path


def read_file(path,limit):
    path=plain(path);before=path.lstat()
    require(stat.S_ISREG(before.st_mode) and 0<=before.st_size<=limit,"Bounded regular input required")
    data=path.read_bytes();after=path.lstat()
    require((before.st_size,before.st_mtime_ns,before.st_ino)==(after.st_size,after.st_mtime_ns,after.st_ino)
        and len(data)==before.st_size,"Input changed during read")
    return data


def json_value(data):
    def unique(pairs):
        result={}
        for key,value in pairs:
            require(key not in result,"Duplicate JSON key")
            result[key]=value
        return result
    def bad_number(value):
        raise ValueError("Nonfinite JSON number: "+value)
    value=json.loads(data,object_pairs_hook=unique,parse_constant=bad_number)
    # The JSON decoder also accepts exponent overflow as inf without calling
    # parse_constant. Validate the parsed value without rewriting source bytes.
    json.dumps(value,allow_nan=False)
    return value


def artifact_ref(ref,directory,limit):
    require(type(ref) is dict and set(ref)=={"path","sha256","bytes"},"Exact path/hash/length reference required")
    path=plain(ref["path"]);full_hash(ref["sha256"])
    require(path.parent==directory and type(ref["bytes"]) is int and 0<ref["bytes"]<=limit,
        "Artifact must be a bounded sibling of its descriptor")
    return path


def descriptor_contract(value,path,workspace,raw_directory):
    require(type(value) is dict and set(value)=={"schema","room","base64","png","prompt","provenance","original_controls","output"}
        and value["schema"]==DESCRIPTOR_SCHEMA and value["room"] in ROOMS,"Exact raw descriptor schema/room required")
    path=plain(path);workspace=plain(workspace);raw_directory=plain(raw_directory)
    require(path.suffix==".json" and path.parent.parent==ARTIFACTS and
        re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,95}",path.parent.name),"Descriptor must be in one intended D artifact folder")
    require(workspace.parent==QA/"workspaces" and re.fullmatch(r"BTH-[A-Za-z0-9_-]{1,100}",workspace.name)
        and raw_directory==workspace/"raw_source","Only explicit admitted E workspace/raw_source allowed")
    output=value["output"]
    require(type(output) is dict and set(output)=={"workspace","png","receipt"} and plain(output["workspace"])==workspace,
        "Descriptor output workspace differs")
    for key,suffix in (("png",".png"),("receipt",".json")):
        leaf=PurePosixPath(output[key])
        require(leaf.as_posix()==output[key] and len(leaf.parts)==2 and leaf.parts[0]=="raw_source"
            and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,100}",leaf.name) and leaf.suffix==suffix,
            "Only one named raw PNG and receipt inside raw_source allowed")
    b64=value["base64"]
    require(type(b64) is dict and set(b64)=={"path","sha256","bytes","data_url_sha256","encoding"}
        and b64["encoding"]=="ASCII_BASE64_ONE_LINE_LF","Exact retained B64 representation required")
    full_hash(b64["data_url_sha256"])
    artifact_ref({k:b64[k] for k in ("path","sha256","bytes")},path.parent,MAX_B64)
    for key in ("prompt","provenance"):
        artifact_ref(value[key],path.parent,1024**2)
    paths=[path,Path(b64["path"]),Path(value["prompt"]["path"]),Path(value["provenance"]["path"])]
    require(len(set(paths))==4,"Descriptor/B64/prompt/provenance must be distinct files")
    png=value["png"]
    require(type(png) is dict and set(png)=={"sha256","bytes","width","height","bit_depth","color_type",
        "compression","filter","interlace","chunks"},"Exact PNG descriptor required")
    full_hash(png["sha256"])
    require(type(png["bytes"]) is int and 57<=png["bytes"]<=MAX_PNG and
        all(type(png[k]) is int and 1<=png[k]<=8192 for k in ("width","height")) and
        all(type(png[k]) is int for k in ("bit_depth","color_type","compression","filter","interlace")),
        "Bounded exact PNG dimensions/header required")
    require(type(png["chunks"]) is list and 3<=len(png["chunks"])<=4096,"Exact bounded PNG chunk ledger required")
    depths={0:{1,2,4,8,16},2:{8,16},3:{1,2,4,8},4:{8,16},6:{8,16}}
    require(png["bit_depth"] in depths.get(png["color_type"],set()) and png["compression"]==png["filter"]==0
        and png["interlace"] in (0,1),"Invalid original PNG header mode")
    controls=value["original_controls"];room=value["room"];prefix="assets/art/environments/"+room+"/"
    required={prefix+"background.png","data/art/environments/"+room+".json","data/art/environments/index.json"}
    require(type(controls) is dict and required<=set(controls) and len(controls)<=256,"Original room BG/JSON/index controls required")
    for name,digest in controls.items():
        posix=PurePosixPath(name)
        require(posix.as_posix()==name and "\\" not in name and ":" not in name and not posix.is_absolute() and ".." not in posix.parts and
            (name in required or name.startswith(prefix) and name.endswith(".png")),"Foreign control path forbidden")
        full_hash(digest)
    return workspace/output["png"],workspace/output["receipt"]


def png_structure(data,pin):
    require(type(data) is bytes and len(data)==pin["bytes"] and sha(data)==pin["sha256"]
        and data[:8]==b"\x89PNG\r\n\x1a\n","Original PNG whole bytes/hash/signature differ")
    offset=8;rows=[]
    for row in pin["chunks"]:
        require(type(row) is dict and set(row)=={"kind","bytes","payload_sha256"} and
            type(row["kind"]) is str and re.fullmatch(r"[A-Za-z]{4}",row["kind"]) and
            type(row["bytes"]) is int and row["bytes"]>=0,"Exact chunk row required")
        full_hash(row["payload_sha256"])
        require(offset+12<=len(data),"Truncated PNG chunk")
        size=struct.unpack_from(">I",data,offset)[0];kind=data[offset+4:offset+8]
        require(size==row["bytes"] and kind==row["kind"].encode("ascii") and offset+12+size<=len(data),
            "Original chunk order/length differs")
        payload=data[offset+8:offset+8+size];crc=struct.unpack_from(">I",data,offset+8+size)[0]
        require(sha(payload)==row["payload_sha256"] and zlib.crc32(kind+payload)&0xffffffff==crc,
            "Original chunk payload/CRC differs")
        rows.append(row);offset+=size+12
    kinds=[row["kind"] for row in rows]
    require(offset==len(data) and kinds[0]=="IHDR" and rows[0]["bytes"]==13 and kinds[-1]=="IEND"
        and rows[-1]["bytes"]==0 and kinds.count("IHDR")==kinds.count("IEND")==1 and "IDAT" in kinds,
        "Complete IHDR/IDAT/IEND PNG with no trailing bytes required")
    expected=tuple(pin[k] for k in ("width","height","bit_depth","color_type","compression","filter","interlace"))
    require(struct.unpack(">IIBBBBB",data[16:29])==expected,"Exact original IHDR differs")
    return {"all_chunk_CRCs_and_payloads_verified":True,"all_original_chunks_preserved":True,
        "caBX_payloads_sha256":[row["payload_sha256"] for row in rows if row["kind"]=="caBX"],
        "chunks":rows,"pixel_decoding_or_transform_performed":False}


def decode_bytes(encoded,value):
    pin=value["base64"]
    require(len(encoded)==pin["bytes"] and sha(encoded)==pin["sha256"] and encoded.endswith(b"\n")
        and encoded.count(b"\n")==1 and b"\r" not in encoded,"Exact one-line LF B64 bytes required")
    require(sha(b"data:image/png;base64,"+encoded[:-1])==pin["data_url_sha256"],"Original data URL identity differs")
    data=base64.b64decode(encoded[:-1],validate=True)
    require(base64.b64encode(data)+b"\n"==encoded,"Noncanonical B64 representation")
    return data,png_structure(data,value["png"])


def inputs_snapshot(value,path,descriptor_sha):
    raw=read_file(path,1024**2);require(sha(raw)==descriptor_sha,"Pinned descriptor changed")
    refs={"descriptor":sha(raw)}
    for key,limit in (("base64",MAX_B64),("prompt",1024**2),("provenance",1024**2)):
        row=value[key];data=read_file(row["path"],limit)
        require(len(data)==row["bytes"] and sha(data)==row["sha256"],"Pinned input changed: "+key)
        refs[key]=sha(data)
    art=plain(SOURCE/"assets/art/environments"/value["room"]);pngs=set();directories=[];pending=[art]
    while pending:
        directory=pending.pop()
        for item in sorted(directory.iterdir()):
            item=plain(item)
            if item.is_dir():
                directories.append(item.relative_to(SOURCE).as_posix());pending.append(item)
            elif item.suffix==".png":
                pngs.add(item.relative_to(SOURCE).as_posix())
    expected={name for name in value["original_controls"] if name.endswith(".png")}
    require(pngs==expected,"Descriptor must bind every original room PNG, no foreign or missing PNG")
    controls={}
    for name,expected in value["original_controls"].items():
        controls[name]=sha(read_file(SOURCE/name,MAX_PNG))
        require(controls[name]==expected,"Original room control changed: "+name)
    return {"artifact_sha256":refs,"original_room_PNG_JSON_index_sha256":controls,"room_directories":sorted(directories)}


def helper_pins():
    require(plain(storage.__file__)==SOURCE/"tools/bth_qa_storage.py" and
        sha(read_file(sys.executable,64*1024**2))==PYTHON_SHA,"Exact D storage/qualified Python required")
    for name,expected in HELPERS.items():
        require(sha(read_file(SOURCE/"tools"/name,1024**2))==expected,"Frozen helper/predecessor changed")
    return {**HELPERS,Path(__file__).name:sha(read_file(__file__,1024**2))}


def write_gate(layout,*parents):
    parents=tuple(plain(p) for p in parents)
    require(parents and all(not p.exists() or p.is_dir() for p in parents),"Write gates accept only directory parents")
    storage.validate_layout(layout,extra_write_paths=parents)


def admitted_layout(args):
    evidence=plain(os.environ["BTH_QA_EVIDENCE_DIR"]);manifest=evidence/"storage-manifest.json"
    raw=read_file(manifest,1024**2);record=json_value(raw)
    require(record.get("schema")=="bth-qa-storage/v1" and record.get("prepared") is True,"Prepared parent Layout required")
    layout=storage.Layout(**{k:Path(v) for k,v in record["paths"].items()},
        **{k:record[k] for k in ("run_id","token","expected_write_bytes","reserve_bytes","prepared")})
    require(layout.root==QA and layout.workspace==plain(args.workspace) and layout.evidence==evidence and
        evidence.parent.parent==QA/"runs" and evidence.name=="evidence" and layout.manifest_path==manifest and
        layout.expected_write_bytes==4*1024**3 and layout.reserve_bytes==20*1024**3,"Exact admitted E Layout and4+20 required")
    claim=read_file(evidence/"launch-claim.json",1024**2);job=json_value(read_file(evidence/"job.json",1024**2))
    require(json_value(claim).get("schema")=="bth.qa_launch_claim/v1" and json_value(claim).get("manifest_sha256")==sha(raw)
        and job.get("status")=="LAUNCH_PENDING" and job.get("schema")=="bth.qa_guarded_run/v1" and
        job.get("storage_manifest_sha256")==sha(raw) and plain(job["storage_manifest"])==manifest,
        "Actual current pending parent Job/claim/manifest required")
    command=job["command"]
    require(len(command)==len(sys.argv)+2 and plain(command[0])==plain(sys.executable) and command[1]=="-B"
        and plain(command[2])==plain(__file__) and command[3:]==sys.argv[1:],"Exact current worker command required")
    storage.check_launch(layout,cwd=Path.cwd(),env=os.environ,extra_write_paths=(plain(args.raw_directory),evidence))
    return layout,{"manifest_sha256":sha(raw),"launch_claim_sha256":sha(claim),
        "pending_parent_command_authenticated":True,"closed_CPU1200_2GiB_Job_must_be_authenticated_by_parent":True}


def existing_output_state(path,expected_sha):
    try:
        path=plain(path)
        if not path.exists():
            return {"present":False}
        info=path.lstat();result={"present":True,"bytes":info.st_size,"inspection_access":"READ_ONLY_STOP_NO_RETRY"}
        if stat.S_ISREG(info.st_mode) and info.st_size<=MAX_PNG:
            data=read_file(path,MAX_PNG);result.update(sha256=sha(data),exact_pinned_bytes=sha(data)==expected_sha)
        else:
            result["byte_inspection"]="Nonregular/oversize object preserved; metadata only"
        return result
    except (OSError,ValueError) as error:
        return {"inspection_error":str(error),"inspection_access":"READ_ONLY_STOP_NO_RETRY"}


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ("descriptor","workspace","raw-directory"):
        parser.add_argument("--"+name,type=Path,required=True)
    parser.add_argument("--descriptor-sha256",required=True)
    args=parser.parse_args(argv);output=receipt=None;value=None
    try:
        full_hash(args.descriptor_sha256);path=plain(args.descriptor)
        raw=read_file(path,1024**2);require(sha(raw)==args.descriptor_sha256,"Explicit descriptor bytes differ")
        value=json_value(raw);output,receipt=descriptor_contract(value,path,args.workspace,args.raw_directory)
        pins=helper_pins();layout,admission=admitted_layout(args)
        require(not plain(args.raw_directory).exists() and not output.exists() and not receipt.exists(),
            "Existing raw directory/PNG/receipt preserved: STOP, no retry or overwrite")
        before=inputs_snapshot(value,path,args.descriptor_sha256)
        data,structure=decode_bytes(read_file(value["base64"]["path"],MAX_B64),value)
        # The only directory creation is this single absent declared raw_source.
        write_gate(layout,output.parent.parent);output.parent.mkdir()
        write_gate(layout,output.parent)
        with output.open("xb") as handle:
            handle.write(data)
        require(read_file(output,MAX_PNG)==data and inputs_snapshot(value,path,args.descriptor_sha256)==before
            and helper_pins()==pins,"Output/input/control/helper byte custody changed")
        result={"schema":SCHEMA,"status":"EXACT_ORIGINAL_GENERATED_PNG_MATERIALIZED","room":value["room"],
            "descriptor":str(path),"descriptor_sha256":args.descriptor_sha256,"output":str(output),
            "output_sha256":sha(data),"output_bytes":len(data),"PNG":structure,"inputs":before,
            "source_and_B64_unchanged":True,"admission":admission,"helpers":pins,
            "pixel_transform_network_child_cleanup_retry_overwrite":False,"production_art_written":False,
            "art_or_candidate_or_release_approval":False,"outer_closed_capped_Job_receipt_required":True}
        write_gate(layout,receipt.parent)
        with receipt.open("x",encoding="utf-8",newline="\n") as handle:
            json.dump(result,handle,indent=2);handle.write("\n")
        require(read_file(output,MAX_PNG)==data and inputs_snapshot(value,path,args.descriptor_sha256)==before
            and helper_pins()==pins,"Byte custody changed after receipt; preserve all outputs and STOP")
        print(json.dumps(result));return 0
    except (OSError,ValueError,KeyError,TypeError,struct.error,storage.StorageGuardError) as error:
        result={"schema":SCHEMA,"status":"STOPPED","error":str(error),"fallback_retry_cleanup_or_overwrite":False,
            "outer_closed_capped_Job_receipt_required":True,"art_or_candidate_or_release_approval":False}
        if output is not None:
            result["existing_PNG_read_only_observation"]=existing_output_state(output,value["png"]["sha256"])
        if receipt is not None:
            result["existing_receipt_read_only_observation"]=existing_output_state(receipt,"")
        print(json.dumps(result),file=sys.stderr);return 1


if __name__=="__main__":
    raise SystemExit(main())
