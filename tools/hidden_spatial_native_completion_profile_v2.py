"""Separate Hidden continuation custody; never upgrades the stopped V4 receipt.

This module reads the exact owned V4 project and old receipts. It performs no
launch, write, observer replacement or approval by importing it.
"""
import sys
sys.dont_write_bytecode = True

import hashlib
import json
import math
from pathlib import Path
import re

import hidden_spatial_native_trial_v4 as base

guard = base.guard
selected = base.selected
original = base.policy
require = original.require

ROOT = Path("E:/CodexQA/BTH")
BASE_PREFIX = "BTH-ENV-SPATIAL-HIDNATIVE-20261116-v4"
RUN_PREFIX = "BTH-ENV-SPATIAL-HIDCOMPLETE-20261116-v2"
PROJECT = original.QA_WORKSPACE / "qa_source"
SOURCE_COMMIT = "8727e4481fd1ca2babe8c803c76d5e210f245f44"
SOURCE_TREE = "9ebe55d48d5ab06cebde73559b5cbf80541ff9ea"
BASE_RUNNER_SHA = "39d04ea4f79edef9bd6c4257c150a0f3a5f56db8fc1fd4df8221ac0d67d2db29"
BASE_POLICY_SHA = "5363ea2df478aec1bb59481964d923d4b325ab82b77f37e78be37b0c4671ac57"
BASE_INPUTS_SHA = "c6fa450ef1b261ad5438e9b4c3411203a1da06dfba7241014ada5bc3cbc24d8f"
BASE_CONFIG_SHA = "5ecb81155171a804b92c9f03a8d0a32b1dc170417f1480fb4a0882e0ec673feb"
IDENTITY_SHA = "a8be9f3ecd7916e0135df6fb6a2729890807389eee634fd445b57d1922d1f12c"
SOURCE_FILES = 4049
BASE_PHASES = ["source-identity","tree","baseline-tree","select","archive","prepare","install","import","identity","contexts","motion","liveness","capture","current-rm","full-composite","full-composite-rm","source-paint","glint-focus","glint-source-paint","counter-replay","floor-wrap","long-wrap"]
BASE_RECEIPTS = {
    "source-identity": "6d0ff33e4a189fb7ea4aad1e29070d4f96589e9f52b9264fffbe48e908859815",
    "tree": "c1cf4d3cd6b6ad6dd8d0af3abb66d8772e85048b6e8d76b712ed5f269e29841b",
    "baseline-tree": "d080a2861b612df38f9b22d5ac59bdb75712894ba3b984a570a2eb8144fbb65a",
    "select": "9363fb80dd7a2cee025d01cd47469fbb2b832be9898ada2bdea2bcb1bf795717",
    "archive": "feca4fb5e09521ed722f98f670894091c1ae4d5bae7d34e6f782c50721435c59",
    "prepare": "cb8f27a6a4314d7b079680560c40f3f41e849105bdb854ef350a04c6d8432970",
    "install": "31f950910b5afecf64885167d2b4f78f9c258110c7395a4678ffec39064abd7b",
    "import": "7bd831e565390d819da253c5280ecd6507f0a3e4c925a557aa947ff8f55186df",
    "identity": "302641186d17d9c7c46d78f071766e3c35272170dcc54329ae6e0cb692cede04",
    "contexts": "e028a11d54ccb87cc671ad49c35a198c5fdd66380da582bc0890c493e95ff720",
    "motion": "718de88d5cc2f121f24a3dfd07e5e72bea0d0a3c03164b6013b6449f1bf3d69f",
    "liveness": "ea6236109e4f265d7124bfb14f03757b5fd76a64a0ad47fd63944487cc66c033",
    "capture": "93104639e6ad25fd1d18c2117c88be5afbf8ef9b2310e7b5bd8c7a4a3e7a1eb0",
    "current-rm": "916242297477d0aafdc1f393a7d6006d28984c2c5cb4859e23a502242aa8c4a5",
    "full-composite": "ba83c9681e3a25bca2eae457b4ab9283c2dc7be6251015f3de0cf0bbe36e5ec6",
    "full-composite-rm": "64bbb490930c2a13260cfa62f247200799a9306a93ab5c7d1258093099e5fdbd",
    "source-paint": "f847ed3015554583db8815d193480ac7d4a0b0c9a4c967e53a9944b74038870f",
    "glint-focus": "9e2d5d20824fa3285f9aa7370ad2832f5873ad14bb07dc9b3923ff29f691b967",
    "glint-source-paint": "646dade4d8e1bdc5df76600c3589dac68c2b3e1141b20db1a312d12483d12d7a",
    "counter-replay": "738a32e0f0d2ae26cc0836cc3aa5561edc89cfc5acde6a306e6d62351bd0c7c6",
    "floor-wrap": "f8a88f0942c7aa49c46fce085a221fa17d0ff31cd1816a2adea421e72b6c41b1",
    "long-wrap": "f189f9b69d160a20c5960c4249a04ef3e0489132eeaef9231d110293b8ba5443"
}
THIN_EVIDENCE = {
    "job.json": "cd77b776b96caef1e7354ceaec057bccfdce7459b6f7128d00086785a877aa14",
    "launch-claim.json": "bd465c05e7172f65a0db400ff436d698bd8cae5e0cce295a1646f7a48cef8826",
    "storage-manifest.json": "cf57b16d86f88bbd46730b16e05c924450e1d9afad00520981000f6c8381685f",
    "thin_bobbing_ribbon_0_after_wrap.png": "f77b447a5bff71f522f39d03b5997503d9d77eb2cc45aa3c303fb5d0da069a62",
    "thin_bobbing_ribbon_0_before_wrap.png": "f77b447a5bff71f522f39d03b5997503d9d77eb2cc45aa3c303fb5d0da069a62",
    "thin_bobbing_ribbon_0_visible_midpoint.png": "d705beba9d4eb9cbafd8751da806cf43824531d3f027f50a0e3b5d44559ef699",
    "thin_bobbing_ribbon_1_after_wrap.png": "f77b447a5bff71f522f39d03b5997503d9d77eb2cc45aa3c303fb5d0da069a62",
    "thin_bobbing_ribbon_1_before_wrap.png": "f77b447a5bff71f522f39d03b5997503d9d77eb2cc45aa3c303fb5d0da069a62",
    "thin_bobbing_ribbon_1_visible_midpoint.png": "b6d4428463203e19d175db20f8bd9803dfb6d42c5ce995c9682b9829e7ccd175",
    "thin_bobbing_ribbon_2_after_wrap.png": "f77b447a5bff71f522f39d03b5997503d9d77eb2cc45aa3c303fb5d0da069a62",
    "thin_bobbing_ribbon_2_before_wrap.png": "f77b447a5bff71f522f39d03b5997503d9d77eb2cc45aa3c303fb5d0da069a62",
    "thin_bobbing_ribbon_2_visible_midpoint.png": "c595b6f414da8ba52461da694a702033ea0346477989acc22d2408c3ba5a6c1f",
    "thin_bobbing_ribbon_3_after_wrap.png": "f77b447a5bff71f522f39d03b5997503d9d77eb2cc45aa3c303fb5d0da069a62",
    "thin_bobbing_ribbon_3_before_wrap.png": "f77b447a5bff71f522f39d03b5997503d9d77eb2cc45aa3c303fb5d0da069a62",
    "thin_bobbing_ribbon_3_visible_midpoint.png": "80d3acd5577c1893afcf85ce02544a8843bdc4dd83b633d20fae97defb9c74b2",
    "thin_bobbing_ribbon_4_after_wrap.png": "f77b447a5bff71f522f39d03b5997503d9d77eb2cc45aa3c303fb5d0da069a62",
    "thin_bobbing_ribbon_4_before_wrap.png": "f77b447a5bff71f522f39d03b5997503d9d77eb2cc45aa3c303fb5d0da069a62",
    "thin_bobbing_ribbon_4_visible_midpoint.png": "6c7a14546bcaf0508fec2ceb9da78c437a58e21da6b40ad0a2791fb6d809b641",
    "thin_wrap_control.png": "f77b447a5bff71f522f39d03b5997503d9d77eb2cc45aa3c303fb5d0da069a62",
    "thin_wrap_probe.json": "6a2d7491042b9a40cf7017876bdac3f25acf617a79b641e9193cc2ab326cddd9",
    "trial-inputs.json": "1ffd08b81bf92c88cb99fff19f19658b69c1b2ed8524760a1a54d870993575b0",
    "worker.log": "ee77ec28bb1b9127c183b9dc25a9f5f126df76cd422864cb13df8d4605d51288"
}
THIN_SOURCE = "tools/envart_hidden_thin_wrap_r2.gd"
THIN_SOURCE_SHA = "92a62c5ca85578c2c99eb877d44f55feddcfd9d7eaaa1b87b5d12364bc50441d"
THIN_JOB_SHA = THIN_EVIDENCE["job.json"]
THIN_REPORT_SHA = THIN_EVIDENCE["thin_wrap_probe.json"]
REMAINING_ENGINE_PHASES = ("work-highstakes", "work-greased", "work-muscle", "effective-hits", "placement")
SCHEMA = "bth.hidden_spatial_native_completion/v2"
PHASE_SCHEMA = "bth.hidden_spatial_native_completion_phase/v2"


def old_evidence(phase):
    require(phase in (*BASE_PHASES, "thin-wrap"), "Exact retained V4 phase required")
    return ROOT / "runs" / (BASE_PREFIX + "-" + phase) / "evidence"


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def thin_contract(report):
    """Keep original family predicates; correct the pinned 10*5+1 observer count.

    The later historical r2c observer had246 checks. It is not the92a6 observer
    that V4 executed; this qualifier never claims that later observer's coverage.
    """
    require(type(report) is dict, "Actual thin report dictionary required")
    original.no_findings(report)
    require(type(report.get("checks")) is int and report["checks"] == 10 * 5 + 1,
            "Pinned original thin observer requires51 checks;246 belongs to a different revision")
    rows = report.get("glints")
    require(type(rows) is list and len(rows) == 5 and all(type(r) is dict for r in rows) and
            [r.get("id") for r in rows] == ["thin_bobbing_ribbon_" + str(i) for i in range(5)],
            "Exact original five thin-ribbon IDs/order required")
    require(report.get("qa_only") is True and report.get("asset_or_manifest_modified") is False and
            report.get("renderer") == "actual EnvironmentArtRenderer", "Original actual renderer/no-asset-change evidence required")
    for i, row in enumerate(rows):
        require(type(row) is dict and row.get("clean_offscreen_wrap") is True and
                row.get("actual_midpoint_pixels_differ") is True and row.get("reduce_motion_hidden") is True,
                "Original clean-wrap/midpoint/RM row predicates failed")
        require(row.get("speed") == 10.0 + 2.0*i and row.get("y") == 87.0 + 18.0*i and
                all(finite(row.get(k)) for k in ("before_clock", "after_clock", "midpoint_clock", "phase", "duration")) and
                row["duration"] > 0 and row["before_clock"] < row["after_clock"],
                "Original thin-ribbon speed/row/finite clock family differs")
    return {"entries": 5, "checks": 51, "original_gd_sha256": THIN_SOURCE_SHA,
            "coverage": "Pinned92a6 observer only; later246-check r2c coverage is not inferred",
            "old_v4_supervisor_status": "FAILED_UNCHANGED", "old_phase_result_absent": True}


def verify_pngs(evidence, recorded):
    actual = base.png_inventory(evidence)
    require(actual == recorded, "Actual retained PNG hashes/dimensions/membership changed")


def authenticate_base():
    require(guard.sha(Path(base.__file__)) == BASE_RUNNER_SHA and
            guard.sha(Path(original.__file__)) == BASE_POLICY_SHA, "Frozen V4 library bytes changed")
    inputs_path = old_evidence("identity") / "trial-inputs.json"
    require(guard.sha(inputs_path) == BASE_INPUTS_SHA, "Exact retained V4 inputs required")
    cfg = guard.read_json(inputs_path)["source_config"]
    require(guard.fingerprint(cfg) == BASE_CONFIG_SHA and cfg["run_prefix"] == BASE_PREFIX and
            cfg["project"] == str(PROJECT) and cfg["source_commit"] == SOURCE_COMMIT and
            cfg["source_tree"] == SOURCE_TREE and cfg["adapter_sha256"] == BASE_RUNNER_SHA,
            "Retained source/config identity changed")
    # Reconstruct through the unmodified frozen API; no config or function patch.
    argv = ["plan"]
    for key in ("workspace", "qa_root", "engine", "git", "git_dir", "baseline_stage",
                "native_extension_descriptor", "editor_native_library", "candidate_root",
                "candidate_manifest", "review", "source_commit", "source_tree", "run_prefix",
                "timeout", "capture_seconds", "position"):
        argv.append("--" + key.replace("_", "-") + "=" + str(cfg[key]))
    require(base.config(base.parse_args(argv)) == cfg, "Current frozen library/input dependencies differ from V4")
    identity = base.verify_identity(cfg)
    require(guard.sha(PROJECT / "hidden_spatial_source_identity.json") == IDENTITY_SHA and
            len(identity["files"]) == SOURCE_FILES, "Exact owned4049-source identity required")
    return cfg


def authenticate_old(cfg):
    """Read and bind all22 qualified observations plus the failed supervisor."""
    records = {}
    for phase in BASE_PHASES:
        evidence = old_evidence(phase)
        require(guard.sha(evidence / "phase-result.json") == BASE_RECEIPTS[phase],
                "Pinned old qualified phase receipt changed: " + phase)
        record = base.previous(cfg, phase)
        if phase in base.REPORT_NAMES:
            report = guard.read_json(evidence / base.REPORT_NAMES[phase])
            if phase == "capture":
                base.capture_contract(report)
            else:
                original.report_contract(phase, report, source_files=SOURCE_FILES)
            verify_pngs(evidence, record["artifacts"]["generated_png_inventory"])
        records[phase] = BASE_RECEIPTS[phase]
    evidence = old_evidence("thin-wrap")
    require_old_failure_absent(evidence)
    require_old_not_run_absent()
    require(original.inventory_all(evidence, THIN_EVIDENCE) == THIN_EVIDENCE,
            "Exact failed-supervisor evidence/artifact custody changed")
    job, inputs = guard.read_json(evidence / "job.json"), guard.read_json(evidence / "trial-inputs.json")
    manifest, claim = (guard.read_json(evidence / n) for n in ("storage-manifest.json", "launch-claim.json"))
    require(selected.qualified_job(job) and job["pid"] == 39284 and
            job["command"] == inputs["command"] == base.command(cfg, "thin-wrap", type("Evidence", (), {"evidence": evidence})()) and
            inputs["source_config"] == cfg and inputs["source_config_sha256"] == BASE_CONFIG_SHA and
            inputs["engine_campaign_admission"] is True and
            job["storage_manifest_sha256"] == claim["manifest_sha256"] == guard.sha(evidence / "storage-manifest.json") and
            manifest["prepared"] is True and manifest["expected_write_bytes"] == 4*1024**3 and
            manifest["reserve_bytes"] == 20*1024**3 and
            selected.same_path(manifest["paths"]["workspace"], PROJECT) and
            selected.same_path(manifest["paths"]["evidence"], evidence) and
            not guard.ERROR_LINE.search((evidence / "worker.log").read_text()),
            "Original thin Job/source/storage/command closure differs")
    require(guard.sha(original.LEGACY / THIN_SOURCE) == THIN_SOURCE_SHA,
            "Original51-check thin observer changed")
    contract = thin_contract(guard.read_json(evidence / "thin_wrap_probe.json"))
    return {"old_pass_receipts": records, "old_supervisor_failure": {
        "phase": "thin-wrap", "job_sha256": THIN_JOB_SHA, "report_sha256": THIN_REPORT_SHA,
        "phase_result_present": False, "original_engine_exit_code": 0, "active_at_release": 0,
        "supervisor_status": "FAILED_UNCHANGED"}, "thin_contract": contract,
        "old_not_run": [*REMAINING_ENGINE_PHASES, "acceptance-summary"]}


def require_old_failure_absent(evidence):
    require(not (evidence / "phase-result.json").exists(), "Stopped V4 supervisor must remain without PASS receipt")


def require_old_not_run_absent():
    require(all(not (ROOT / "runs" / (BASE_PREFIX + "-" + phase)).exists()
                for phase in (*REMAINING_ENGINE_PHASES, "acceptance-summary")),
            "All six original unrun V4 run roots must remain absent")

TRANSPORT_CATALOG_PATH = Path(__file__).with_name("hidden_spatial_native_completion_transports.json")
TRANSPORT_CATALOG_SHA = "658cda3e2e3802f122db431fd1835b05cdc9a44dfe104ab4777b5b9ef46063f9"
MANIFEST_SHA = "bb4dc0bfb830fc9d7ad73179b8d1b9ee0fb7c0e6e59fafc42f9a54aa78bef568"


def transport_catalog():
    require(guard.sha(selected.plain(TRANSPORT_CATALOG_PATH, file=True)) == TRANSPORT_CATALOG_SHA,
            "Exact reviewed transport catalog required")
    value = guard.read_json(TRANSPORT_CATALOG_PATH)
    require(value["schema"] == "bth.hidden_completion_transports/v1" and
            value["project_source_writes"] is False and value["code_and_assertion_edits"] is False and
            set(value["transports"]) == {"thin-strong", "effective-hits"}, "Exact two inert transports required")
    return value


def transported_observer(phase, prefix):
    """Only full quoted input literals change; preserve every other source byte."""
    require(prefix == RUN_PREFIX, "Exact fresh continuation prefix required")
    row = transport_catalog()["transports"][phase]
    path = original.LEGACY / row["source"]
    require(guard.sha(selected.plain(path, file=True)) == row["sha256"], "Authenticated successful observer changed")
    raw = path.read_bytes()
    roles = {
        "retained_v4_contexts": (old_evidence("contexts") / base.REPORT_NAMES["contexts"]).as_posix(),
        "fresh_completion_work_prefix": (ROOT / "runs" / (prefix + "-work-")).as_posix(),
        "fresh_completion_work_suffix": "/evidence/hidden_sequence_live_proof.json",
    }
    operations = []
    for item in row["substitutions"]:
        before, after = item["original_literal"].encode(), roles[item["role"]].encode()
        quoted = b'"' + before + b'"'
        require(raw.count(quoted) == 1 and all(c not in after for c in (b'"', b"\n", b"\r", b"\\", b"\0")),
                "Sole safe complete quoted transport literal required")
        raw = raw.replace(quoted, b'"' + after + b'"')
        operations.append({"original_literal": before.decode(), "active_literal": after.decode(), "occurrences": 1})
    return raw, {"schema": "bth.hidden_completion_observer_transport/v1", "phase": phase,
                 "original_path": str(path), "original_sha256": row["sha256"],
                 "active_sha256": hashlib.sha256(raw).hexdigest(),
                 "catalog_sha256": TRANSPORT_CATALOG_SHA, "operations": operations,
                 "line_endings_preserved": True, "nonliteral_bytes_unchanged": True,
                 "assertions_and_normalization_unchanged": True, "project_source_written": False}



STRONG_THIN_WITNESS = ROOT / "runs/BTH-ENVART-HIDDENR2-20261114-thin-wrap02/evidence/thin_wrap_probe.json"
STRONG_THIN_WITNESS_SHA = "7192ce8120fd59eb7578f1599dd91ce235cf031b3b80abd141bc28541c2e911a"
GODOT_CONSOLE = Path("D:/Projects/Beat-The-House/.tools/godot-4.6-stable/Godot_v4.6-stable_win64_console.exe")


def serialized_thin_witness():
    """Exact same-manifest Godot-serialized witness, not numeric tolerance.

    JSON.stringify in the authenticated865 observer serializes source doubles.
    The7192 witness binds that representation for the unchanged bb4 raw manifest
    and exact pinned Godot build. Native source checks and all246 assertions stay
    in the byte-exact original observer. Nothing rounds or rewrites fresh data.
    """
    require(guard.sha(selected.plain(PROJECT / original.MANIFEST, file=True)) == MANIFEST_SHA,
            "Exact current raw manifest hash required for serialized witness")
    entry = transport_catalog()["transports"]["thin-strong"]
    require(guard.sha(selected.plain(original.LEGACY / entry["source"], file=True)) == entry["sha256"] and
            guard.sha(selected.plain(GODOT_CONSOLE, file=True)) == guard.ENGINE_SHA and
            guard.sha(selected.plain(GODOT_CONSOLE.with_name("Godot_v4.6-stable_win64.exe"), file=True)) == guard.RUNTIME_SHA,
            "Original865 observer and exact Godot build required for serialized witness")
    require(guard.sha(selected.plain(STRONG_THIN_WITNESS, file=True)) == STRONG_THIN_WITNESS_SHA ==
            entry["historical_report_sha256"], "Exact successful serialized7192 witness required")
    report = guard.read_json(STRONG_THIN_WITNESS)
    original.no_findings(report)
    rows = report["glints"]
    require(report["checks"] == 246 and report["source_manifest_sha256"] == MANIFEST_SHA and
            [r["id"] for r in rows] == ["thin_bobbing_ribbon_"+str(i) for i in range(5)],
            "Serialized witness source/count/family differs")
    return {row["id"]:row for row in rows}


def serialized_equal(actual, expected):
    # Preserve numeric values and types exactly as parsed from the two authentic
    # report serializations; no precision/rounding guess or epsilon comparison.
    return json.dumps(actual, sort_keys=True, separators=(",", ":"), allow_nan=False) == json.dumps(
        expected, sort_keys=True, separators=(",", ":"), allow_nan=False)


def strong_thin_contract(report):
    original.no_findings(report)
    require(type(report["checks"]) is int and report["checks"] == 246 and
            report["source_manifest_sha256"] == MANIFEST_SHA and report["qa_only"] is True and
            report["asset_or_manifest_modified"] is False and report["renderer"] == "actual EnvironmentArtRenderer",
            "Successful original246-check thin observer contract required")
    rows = report["glints"]
    require([r["id"] for r in rows] == ["thin_bobbing_ribbon_"+str(i) for i in range(5)],
            "Five complete ordered stronger thin rows required")
    spec = guard.read_json(PROJECT / original.MANIFEST)
    require(guard.sha(PROJECT / original.MANIFEST) == MANIFEST_SHA, "Exact unchanged source manifest required")
    expected = {r["id"]:r for r in spec["animations"]}
    witnesses = serialized_thin_witness()
    pngs = {"thin_wrap_control.png"}
    for i, row in enumerate(rows):
        source, bob = expected[row["id"]], row["bob"]
        canonical = witnesses[row["id"]]
        require(serialized_equal(row["source_manifest_entry"], canonical["source_manifest_entry"]) and
                row["clean_offscreen_wrap"] is True and
                row["actual_midpoint_pixels_differ"] is True and row["reduce_motion_hidden"] is True and
                row["speed"] == 10+2*i and row["y"] == 87+18*i, "Stronger actual source/wrap/RM row failed")
        require(bob["source_frame_count"] == source["frames"] == 8 and
                serialized_equal(bob["source_fps"], canonical["bob"]["source_fps"]) and
                serialized_equal(bob["source_phase"], canonical["bob"]["source_phase"]) and
                finite(bob["support_y_span_pixels"]) and bob["support_y_span_pixels"] > .5 and
                finite(bob["centroid_y_span_pixels"]) and bob["centroid_y_span_pixels"] > .5 and
                len(bob["samples"]) == 8, "All eight actual vertical-bob frames/support required")
        for index, sample in enumerate(bob["samples"]):
            require(sample["native_frame_index"] == index and finite(sample["clock"]) and
                    sample["source_frame_region"] == {"x":index*source["size"][0]*2, "y":0,
                                                       "w":source["size"][0]*2, "h":source["size"][1]*2} and
                    type(sample["rgb_support"]["changed_pixels"]) is int and sample["rgb_support"]["changed_pixels"] > 0 and
                    sample["png"] == row["id"]+"_bob_frame_"+str(index)+".png",
                    "Complete native atlas-frame/RGB support evidence required")
            pngs.add(sample["png"])
        pngs.update(row["id"]+"_"+suffix+".png" for suffix in ("before_wrap", "after_wrap", "visible_midpoint"))
    return {"checks":246, "entries":5, "native_bob_frames":40, "expected_pngs":sorted(pngs),
            "source_manifest_sha256":MANIFEST_SHA, "original_gd_sha256":transport_catalog()["transports"]["thin-strong"]["sha256"]}


def remaining_contract(phase, report):
    value = original.report_contract(phase, report, source_files=SOURCE_FILES)
    if phase == "effective-hits":
        expected = ["__none", *original.CASE_IDS]
        scope = report["batch_scope"]
        require(scope == {"full_catalog_validated": True, "full_context_count": 27, "requested_case": "",
                          "scope":"Full proof", "selected_case_ids":expected} and
                [r["case_id"] for r in report["contexts"]] == expected,
                "Exact unfiltered successful r2b Base+26 ordered context scope required")
        count = 0
        for row in report["contexts"]:
            evidence = row["layout_evidence"]
            require(evidence["post_serialization_differences"] == [] and
                    evidence["current_native_json_normalized_layout"] == evidence["prior_source_normalized_layout"],
                    "Original JSON-roundtrip prior geometry equality required")
            # Historical pre_serialization_differences can be nonempty. They are
            # retained diagnostics, not a new raw-current/prior equality gate.
            require(type(evidence["pre_serialization_differences"]) is list and
                    type(evidence["current_native_pre_serialization_layout"]) is dict and
                    type(evidence["current_native_pre_serialization_variant_text"]) is str,
                    "Original pre-serialization diagnostics must remain intact")
            for sample in row["hit_samples"]:
                require(sample["legacy_hit_ids"] == sample["pack_hit_ids"] and
                        sample["legacy_interactive_hit_ids"] == sample["pack_interactive_hit_ids"] and
                        sample["object_id"] in sample["pack_hit_ids"] and type(sample["reduce_motion"]) is bool,
                        "Original normal/RM ordered hit and membership assertion failed")
                count += 1
        require(count == 4620, "Complete original4620 hit samples required")
        value.update({"hit_samples":count, "original_prior_comparison":"Unchanged original JSON-roundtrip normalization",
                      "raw_current_prior_bitwise_equality_claimed":False})
    return value


def authenticate_successful_history():
    catalog = transport_catalog()
    result = {}
    for phase, item in catalog["transports"].items():
        evidence = ROOT / "runs" / item["historical_evidence"] / "evidence"
        source = evidence / Path(item["source"]).name
        require(guard.sha(source) == item["sha256"] == guard.sha(original.LEGACY / item["source"]) and
                guard.sha(evidence / "job.json") == item["historical_job_sha256"] and
                guard.sha(evidence / item["report"]) == item["historical_report_sha256"],
                "Exact successful historical source/producer/report binding required")
        job = guard.read_json(evidence / "job.json")
        require(selected.qualified_job(job) and
                job["command"][job["command"].index("--script")+1] == "res://"+item["source"],
                "Successful historical Job must name exact retained producer revision")
        report = guard.read_json(evidence / item["report"])
        contract = strong_thin_contract(report) if phase == "thin-strong" else remaining_contract(phase, report)
        result[phase] = {"job_sha256":item["historical_job_sha256"], "report_sha256":item["historical_report_sha256"],
                         "source_sha256":item["sha256"], "contract":contract}
    for phase, suffix in (("work-highstakes","highstakes"), ("work-greased","greased"), ("work-muscle","muscle")):
        path = ROOT/"runs"/("BTH-ENVART-HIDDENR2-20261114-sequence-"+suffix+"-01")/"evidence/hidden_sequence_live_proof.json"
        digest = {"work-highstakes":"e20bfa292ed0342f49f805f54fb416a7d4682c8e2216766cfc17d0b785714726",
                  "work-greased":"5b316d3ea3d7d6f34206812a3769fa7d3419595d2ddd165fb903ac9d189ec8bb",
                  "work-muscle":"67a8ca522b28789115283ddacdc2b3845cefb99cddf0ed309ba0fadcf74c5723"}[phase]
        require(guard.sha(path) == digest, "Exact successful original work report required")
        result[phase] = {"report_sha256":digest, "contract":remaining_contract(phase, guard.read_json(path))}
    path = ROOT/"runs/BTH-ENVART-HIDDENR2-20261114-placement01/evidence/hidden_placement_closing.json"
    require(guard.sha(path) == "4f208faa008afb998f0660e39f6d22cdeef61f5026a0c1385f4f14b1ddc81a33",
            "Exact original placement report required")
    result["placement"] = {"contract":remaining_contract("placement", guard.read_json(path))}
    return result
