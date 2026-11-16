"""Read-only actual-archive observer contract gate; never launches or admits QA.

Run the CLI only in a parent-owned bounded worker. There are no directory/file
writes, child processes, native engine calls, schema repairs or validator patches.
JSON shape is reported separately from native type/runtime proof.
"""
import sys
sys.dont_write_bytecode = True
import argparse
from copy import deepcopy
import hashlib
import importlib
import inspect
import json
from pathlib import Path
import re

import grand_spatial_native_trial as guard
import bth_qa_selected_source_v2 as selected

SOURCE_ROOT=Path("D:/Projects/Beat-The-House/.tmp/environment-art-layers")
QA_ROOT=Path("E:/CodexQA/BTH")
SCHEMA="bth.environment_spatial_observer_preflight/v1"
CATALOG_SCHEMA="bth.environment_spatial_observer_catalog/v1"
FROZEN_GUARD_SHA="650e14dfd71197bd55021553e3ec9adfe1f67533ea3e7c930a456e05bcd3ac6a"
FROZEN_SELECTED_SHA="051ae002c310602175b89b2db624ca7777651ce69ee89057dbcff2f540e53625"

def require(value,message):
    if not value:
        raise ValueError(message)

def canonical(value):
    return json.dumps(value,sort_keys=True,separators=(",",":"),allow_nan=False)

def read_ref(ref):
    """Explicit ordinary artifact bytes only; never profile/save/browser state."""
    require(isinstance(ref,dict) and set(ref)=={"path","sha256"} and
        isinstance(ref["sha256"],str) and re.fullmatch(r"[0-9a-f]{64}",ref["sha256"]),"Exact artifact path/SHA256 reference required")
    path=selected.plain(ref["path"],file=True)
    require(path.is_absolute() and (path.is_relative_to(SOURCE_ROOT) or path.is_relative_to(QA_ROOT/"runs") or
        path.is_relative_to(QA_ROOT/"workspaces")) and not any(part.lower() in
        {"profile","save_dir","localappdata","appdata","home","cache","pycache"} for part in path.parts),
        "Only explicit source/evidence artifacts are admitted; no profiles or other drives")
    require(path.stat().st_size<=16*1024**2,"Preflight artifact exceeds16MiB read bound")
    data=path.read_bytes()
    require(hashlib.sha256(data).hexdigest()==ref["sha256"],"Pinned actual artifact changed: "+str(path))
    return data

def values_at(value,path):
    """Explicit JSON paths with * over actual dict/array members; no coercion."""
    require(isinstance(path,list) and all(isinstance(part,(str,int)) and type(part) is not bool for part in path),
        "Explicit JSON path tokens required")
    current=[value]
    for token in path:
        result=[]
        for item in current:
            if token=="*":
                require(isinstance(item,(dict,list)) and len(item)>0,"Wildcard requires nonempty actual JSON container")
                result.extend(item.values() if isinstance(item,dict) else item)
            elif isinstance(item,dict) and isinstance(token,str):
                require(token in item,"Required actual JSON field absent: "+str(path))
                result.append(item[token])
            elif isinstance(item,list) and type(token) is int and 0<=token<len(item):
                result.append(item[token])
            else:
                raise ValueError("Actual JSON shape differs at: "+str(path))
        current=result
    return current

def shape_contract(report,rules):
    types={"string":lambda x:type(x) is str,"array":lambda x:type(x) is list,
        "object":lambda x:type(x) is dict,"boolean":lambda x:type(x) is bool,
        "number":lambda x:type(x) in (int,float)}
    observed=[]
    for rule in rules:
        require(set(rule)=={"path","type","count","representation"} and rule["type"] in types and
            type(rule["count"]) is int and rule["count"]>0 and rule["representation"] in
            {"SERIALIZED_JSON_ONLY","NATIVE_WITNESS_DECLARATION_CHECKED_BY_ROOM_VALIDATOR"},"Exact JSON shape rule required")
        values=values_at(report,rule["path"])
        require(len(values)==rule["count"] and all(types[rule["type"]](x) for x in values),
            "Actual serialized shape/count differs: "+str(rule["path"]))
        observed.append({**rule,"observed_count":len(values),"native_type_inferred_from_JSON":False})
    return observed

def assert_validator(spec,validator):
    require(callable(validator) and inspect.isfunction(validator),"Unmodified room-validator function required")
    path=Path(inspect.getsourcefile(validator) or "").resolve()
    require(path==selected.plain(spec["source"]["path"],file=True) and path.parent==SOURCE_ROOT/"tools" and
        validator.__name__==spec["function"] and
        getattr(sys.modules.get(validator.__module__),spec["function"],None) is validator,
        "Validator callable must be the exact named original source function")
    read_ref(spec["source"])

def serialized_contract(spec,report,validator):
    before=canonical(report)
    result=validator(*spec["validator"].get("args_before_report",[]),report,**spec["validator"].get("kwargs",{}))
    require(canonical(report)==before,"Room validator mutated its actual positive input")
    for rule in spec.get("exact_values",[]):
        require(set(rule)=={"path","value"},"Exact serialized field declaration required")
        values=values_at(report,rule["path"])
        require(len(values)==1 and canonical(values[0])==canonical(rule["value"]),"Declared actual serialized field/count differs")
    observed=shape_contract(report,spec.get("serialized_shapes",[]))
    return result,observed

def preflight_case(spec,validator):
    """Authenticate full actual positive first; never duplicates its predicates."""
    require(spec.get("status")=="PINNED_ACTUAL_ARCHIVE" and spec.get("fixture") is False,
        "Actual positive archive is not produced/pinned; fixtures cannot authorize this gate")
    require(guard.sha(Path(guard.__file__))==FROZEN_GUARD_SHA and
        guard.sha(Path(selected.__file__))==FROZEN_SELECTED_SHA,"Frozen guard/selection helper changed")
    refs={name:spec[name] for name in ("report","producer","job","log")}
    refs["validator"]=spec["validator"]["source"]
    refs.update({"provenance:"+name:ref for name,ref in spec.get("provenance",{}).items()})
    payloads={name:read_ref(ref) for name,ref in refs.items()}
    report=json.loads(payloads["report"])
    require(isinstance(report,dict),"Actual report must be a JSON object")
    write_witness=spec["producer_write_witness"]
    require(isinstance(write_witness,str) and len(write_witness)<=1024 and
        spec["actual_written_filename"] in write_witness and write_witness.encode() in payloads["producer"] and
        Path(spec["report"]["path"]).name==spec["actual_written_filename"],
        "Actual producer WRITE filename differs; no alias or report rename")
    expected=spec["actual_schema"]
    require(("schema" not in report) if expected is None else report.get("schema")==expected,
        "Actual schema presence/value differs; absent schema is not an invented schema")
    job=json.loads(payloads["job"])
    require(guard.qualified_job(job) and not guard.ERROR_LINE.search(payloads["log"].decode("utf-8",errors="strict")),
        "Actual producer Job must be closed/capped/zero with a clean complete log")
    command=job.get("command",[])
    require(command.count(spec["producer_script_argument"])==1 and spec["producer_script_argument"].startswith("res://tools/") and
        Path(spec["producer"]["path"]).name==spec["producer_script_argument"].split("/")[-1],
        "Actual Job script does not bind this producer")
    require(command.count("--path")==command.count("--script")==1 and
        command.index("--path")+1<len(command) and command.index("--script")+1<len(command) and
        command[command.index("--script")+1]==spec["producer_script_argument"],
        "Exact unique original engine --path/--script arguments required")
    project=selected.plain(command[command.index("--path")+1])
    require(selected.plain(project/spec["producer_script_argument"][6:],file=True)==
        selected.plain(spec["producer"]["path"],file=True),"Actual Job project does not contain this exact producer")
    assert_validator(spec["validator"],validator)
    # All original room assertions execute before supplemental shape reporting.
    result,observed=serialized_contract(spec,report,validator)
    for name,ref in refs.items():
        require(read_ref(ref)==payloads[name],"Actual archive/source changed during preflight: "+name)
    return {"schema":SCHEMA,"case_id":spec["case_id"],"room":spec["room"],"status":"SERIALIZED_CONTRACT_POSITIVE_PASS",
        "artifact_sha256":{name:ref["sha256"] for name,ref in refs.items()},
        "actual_written_filename":spec["actual_written_filename"],"actual_schema":expected,
        "unmodified_room_validator_result":result,"serialized_shapes":observed,
        "validator_ran_before_supplemental_shape_checks":True,"all_input_bytes_unchanged":True,
        "native_type_or_cross_representation_float_identity_inferred":False,
        "native_runtime_executed":False,"engine_admission_granted":False,
        "fresh_campaign_acceptance_or_art_or_TEST_approval":False,"scope":spec["scope"]}

def positive_then_controls(spec,validator,controls):
    """Same law on explicit in-memory negatives, only after authentic positive.

    This never writes modified JSON or presents controls as native observations.
    """
    positive=preflight_case(spec,validator)
    report=json.loads(read_ref(spec["report"]))
    require(type(controls) is list and 0<len(controls)<=64,"Explicit bounded negative controls required")
    results=[]
    for control in controls:
        require(set(control)=={"name","path","value"} and type(control["name"]) is str and
            control["name"] and type(control["path"]) is list and control["path"] and "*" not in control["path"],
            "Exact named single-path control required")
        changed=deepcopy(report)
        parent=values_at(changed,control["path"][:-1])
        require(len(parent)==1,"One control parent required")
        key=control["path"][-1]
        values_at(changed,control["path"])
        parent[0][key]=deepcopy(control["value"])
        require(canonical(changed)!=canonical(report),"Negative control is a no-op")
        try:
            serialized_contract(spec,changed,validator)
        except (ValueError,KeyError,TypeError,IndexError):
            results.append({"name":control["name"],"rejected":True})
        else:
            raise ValueError("Negative control was accepted: "+control["name"])
    return {"positive":positive,"negative_controls":results,"controls_are_in_memory_fixtures_not_native_evidence":True}

def validator_from_catalog(spec):
    """Read-only normal import; no frozen module globals are replaced."""
    source=spec["validator"]["source"]
    read_ref(source)
    path=selected.plain(source["path"],file=True)
    require(path.parent==SOURCE_ROOT/"tools" and re.fullmatch(r"[a-z_][a-z_0-9]*",path.stem),"Exact tool validator module required")
    module=importlib.import_module(path.stem)
    value=getattr(module,spec["validator"]["function"])
    assert_validator(spec["validator"],value)
    return value

def preflight_room(catalog,room,case_ids=None):
    require(catalog.get("schema")==CATALOG_SCHEMA and type(catalog.get("cases")) is list,
        "Exact observer catalog schema required")
    cases=[row for row in catalog["cases"] if row["room"]==room]
    require(cases and len({row["case_id"] for row in cases})==len(cases),"Room cases must exist and be unique")
    requested=set(case_ids) if case_ids is not None else {row["case_id"] for row in cases}
    require(requested and requested<={row["case_id"] for row in cases} and
        (case_ids is None or len(case_ids)==len(requested)),"Explicit case scope must be unique and belong to this room")
    results=[]; waiting=[]
    for spec in cases:
        if spec["case_id"] not in requested:
            if spec["status"]!="PINNED_ACTUAL_ARCHIVE":
                waiting.append({"case_id":spec["case_id"],"status":spec["status"],"reason":spec["reason"],"requested":False})
            continue
        if spec["status"]!="PINNED_ACTUAL_ARCHIVE":
            waiting.append({"case_id":spec["case_id"],"status":spec["status"],"reason":spec["reason"],"requested":True})
            continue
        results.append(preflight_case(spec,validator_from_catalog(spec)))
    return {"schema":SCHEMA,"room":room,"status":"REQUESTED_ARCHIVE_POSITIVES_PASS" if results and not any(row["requested"] for row in waiting) else "INCOMPLETE_SCOPE",
        "requested_cases":sorted(requested),"entire_catalog_room_scope_requested":case_ids is None,
        "positive_cases":results,"unproved_cases":waiting,"native_execution_or_engine_admission":False,
        "missing_cases_do_not_inherit_another_room_or_revision":True}

def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog",type=Path,required=True)
    parser.add_argument("--catalog-sha256",required=True)
    parser.add_argument("--room",required=True)
    parser.add_argument("--case",action="append",dest="case_ids",help="Explicit actual-positive subset; omitted cases remain unproved, never waived")
    args=parser.parse_args(argv)
    try:
        payload=read_ref({"path":str(args.catalog),"sha256":args.catalog_sha256})
        record=preflight_room(json.loads(payload),args.room,args.case_ids)
        require(read_ref({"path":str(args.catalog),"sha256":args.catalog_sha256})==payload,"Catalog changed during preflight")
        print(json.dumps(record,sort_keys=True,indent=2,allow_nan=False))
        return 0 if record["status"]=="REQUESTED_ARCHIVE_POSITIVES_PASS" else 2
    except (OSError,ValueError,KeyError,TypeError,RuntimeError,ImportError,AttributeError) as error:
        print(json.dumps({"status":"OBSERVER_PREFLIGHT_STOPPED","error":str(error),"fallback_attempted":False}),file=sys.stderr)
        return 1

if __name__=="__main__":
    raise SystemExit(main())
