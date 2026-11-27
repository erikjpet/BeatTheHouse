#!/usr/bin/env python3
"""Run, compare, or retry player-visible Rourke policies in fresh, capped Godot sessions."""
from __future__ import annotations

import sys

sys.dont_write_bytecode = True

import argparse
from dataclasses import dataclass
import hashlib
from itertools import product
import json
import os
from pathlib import Path
from statistics import mean

from bth_qa_command_paths import command_write_paths
from bth_qa_guarded_run import execute
import bth_qa_storage as storage
from bth_qa_storage import DEFAULT_ROOT, GIB, StorageGuardError, plan_layout, prepare_layout, validate_layout


@dataclass(frozen=True)
class SolverTarget:
    name: str
    schema: str
    script: str
    ending: str | tuple[str, ...]
    ending_target: str
    victory_field: str
    routes: tuple[str, ...]


ROURKE = SolverTarget(
    name="Rourke",
    schema="bth.rourke_solver_campaign/v1",
    script="tests/ending_solvers/rourke_solver/rourke_solver.gd",
    ending="showdown_survived",
    ending_target="rourke_duel",
    victory_field="verified_rourke_victory",
    routes=("baseline", "balanced", "risk_aware", "direct_peek", "profit_trigger", "cool_before_duel"),
)
RESULT_PREFIX = "BTH_SOLVER_RESULT "
STEP_PREFIX = "BTH_SOLVER_STEP "
POLICIES = ("balanced", "baseline", "risk_aware")
ROUTE_MODEL_SCHEMA = "bth.ending_solver_route_model/v1"
LOCAL_GODOT = Path(__file__).resolve().parents[3] / ".tools" / "godot-4.6-stable" / "Godot_v4.6-stable_win64_console.exe"


def _policy_name(value):
    if value not in POLICIES:
        raise argparse.ArgumentTypeError(f"Choose a supported solver policy: {', '.join(POLICIES)}")
    return value


def route_policy(route):
    if route == "reserve_recovery":
        return "baseline"
    if route in POLICIES:
        return route
    return "balanced" if route == "auto" else "risk_aware"


def _admitted_input(path, root, label):
    path = storage._path(path)
    if not storage._inside(root, path):
        raise StorageGuardError("root_escape", path, f"{label} must be strictly below approved root {root}")
    storage._inspect(path.parent)
    if storage._probe(path) != (True, False, False) or storage._key(storage._resolve_path(path)) != storage._key(path):
        raise StorageGuardError("invalid_input_path", path, f"{label} must be an existing plain, non-reparse file")
    return path


def _load_route_model(path, root, target):
    path = _admitted_input(path, root, "route model")
    data = path.read_bytes()
    model = json.loads(data)
    if (not isinstance(model, dict) or model.get("schema") != ROUTE_MODEL_SCHEMA
            or model.get("ending_target") != target.ending_target or model.get("default_policy") not in target.routes
            or not isinstance(model.get("context_policies"), dict)
            or any(not key or route not in target.routes for key, route in model["context_policies"].items())):
        raise ValueError(f"Route model does not describe valid {target.name} routes: {path}")
    return path, hashlib.sha256(data).hexdigest()


def _seed_text(value):
    cleaned = value.strip(" ")
    if not cleaned or any(ord(character) < 32 for character in value):
        raise argparse.ArgumentTypeError("Use a nonempty, single-line Run Setup seed")
    return cleaned


def _trial_id(campaign_id, suffix):
    if len(campaign_id) + len(suffix) <= 80:
        return campaign_id + suffix
    fingerprint = hashlib.sha256(campaign_id.encode("ascii")).hexdigest()[:16]
    return campaign_id[:63 - len(suffix)] + "-" + fingerprint + suffix


def _user_data(layout):
    return layout.appdata / "Godot" / "app_userdata" / "Beat the House"


def _worker_paths(layout, command):
    outputs = (layout.evidence, _user_data(layout), layout.workspace / ".godot",
               layout.workspace / ".godot" / "imported", layout.workspace / ".godot" / "editor")
    return outputs + command_write_paths(layout, command)


def _worker_environment(layout):
    # An inherited development or QA switch must not affect a fresh player run.
    environment = {key: value for key, value in os.environ.items() if not key.upper().startswith("BTH_")}
    environment["BTH_DEVELOPER_PLACEMENT_PATH"] = str(layout.save_dir / "developer_environment_placements.json")
    environment["BTH_DEVELOPER_PLACEMENT_REPORT_PATH"] = str(layout.save_dir / "BeatTheHouse_environment_slot_placement_changes.json")
    return environment


def _plan_worker(layout, engine, *, seed=None, policy=None, native=False, target=ROURKE,
                 route=None, route_model=None, action_budget=None):
    command = [str(engine)]
    if not native or seed is None:
        command.append("--headless")
    command.extend(["--path", str(layout.workspace),
                    "--log-file", str(layout.evidence / "godot.log")])
    if seed is None:
        command.append("--import")
    else:
        command.extend(["--fixed-fps", "60", "--script", f"res://{target.script}", "--", f"--seed={seed}",
                        f"--policy={policy}", f"--expected-user-data={_user_data(layout)}"])
        if route is not None:
            command.append(f"--route={route}")
        if route_model is not None:
            command.append(f"--route-model={route_model}")
        if action_budget is not None:
            command.append(f"--action-budget={action_budget}")
    outputs = _worker_paths(layout, command)
    validate_layout(layout, extra_write_paths=outputs)
    return layout, command, outputs


def _launch_worker(worker, timeout, cpu_rate):
    layout, command, outputs = worker
    validate_layout(layout, extra_write_paths=outputs)
    layout = prepare_layout(layout)
    result = execute(layout, command, timeout=timeout, cpu_rate=cpu_rate,
                     extra_write_paths=outputs, parent_environment=_worker_environment(layout))
    if result.get("storage_error"):
        details = result["storage_error"]
        reason = details["message"].removeprefix(f"{details['error']}: {details['target']}: ")
        raise StorageGuardError(details["error"], details["target"], reason,
                                details["required_bytes"], details["available_bytes"])
    evidence = {"run_id": layout.run_id, "storage_manifest": str(layout.manifest_path),
                "job_receipt": str(layout.evidence / "job.json"),
                "worker_log": str(layout.evidence / "worker.log")}
    return result, evidence


def _job_error(record):
    if record.get("error"):
        return record["error"]
    if record.get("timed_out"):
        return "Worker exceeded its guarded timeout"
    if record.get("cleanup_errors") or record.get("active_at_release") != 0:
        return "Owned worker cleanup could not be verified"
    if record.get("log_error") or record.get("log_truncated"):
        return "Complete bounded worker evidence is unavailable"
    if not record.get("assigned_before_execution") or not record.get("storage_gate_before_child"):
        return "Owned suspended launch evidence is incomplete"
    if record.get("exit_code") != 0:
        return f"Godot exited with code {record.get('exit_code')}"
    return None


def _read_trace(log_path):
    terminal = None
    step_count = 0
    accepted_steps = 0
    with Path(log_path).open(encoding="utf-8") as log:
        for line in log:
            if line.startswith(STEP_PREFIX):
                step = json.loads(line[len(STEP_PREFIX):])
                if not isinstance(step, dict) or type(step.get("accepted")) is not bool:
                    raise ValueError("Solver step evidence must report whether its input was accepted")
                step_count += 1
                accepted_steps += step["accepted"]
            elif line.startswith(RESULT_PREFIX):
                if terminal is not None:
                    raise ValueError("Solver emitted multiple terminal results")
                terminal = json.loads(line[len(RESULT_PREFIX):])
                if not isinstance(terminal, dict):
                    raise ValueError("Solver terminal evidence must be a JSON object")
    return terminal, step_count, accepted_steps


def _read_trial(log_path, seed, policy, target=ROURKE, *, route=None):
    terminal, step_count, accepted_steps = _read_trace(log_path)
    if terminal is None:
        raise ValueError("No usable solver terminal result in worker evidence")
    _validate_result(terminal, seed, policy, target)
    if terminal["actions"] != accepted_steps:
        raise ValueError("Solver action count disagrees with its accepted input trace")
    if route is not None:
        if terminal.get("route") != route:
            raise ValueError("Solver result route disagrees with the requested route")
        selected = terminal.get("selected_route", "")
        if route == "auto" and selected not in target.routes and (selected or terminal["victory"]):
            raise ValueError("Automatic route result does not name a valid selected route")
        if route != "auto" and selected and selected != route:
            raise ValueError("Solver selected a route that differs from the forced route")
    return terminal, step_count


def _validate_result(terminal, seed, policy, target=ROURKE):
    if not isinstance(terminal, dict):
        raise ValueError("Solver terminal evidence must be a JSON object")
    if terminal.get("seed") != seed:
        raise ValueError("Solver result seed disagrees with the requested Run Setup seed")
    if terminal.get("policy") != policy:
        raise ValueError("Solver result policy disagrees with the requested policy")
    if (type(terminal.get("victory")) is not bool or not isinstance(terminal.get("ending"), str)
            or type(terminal.get("actions")) is not int or terminal["actions"] < 0):
        raise ValueError("Solver result must report its ending, victory and action count")
    accepted_endings = (target.ending,) if isinstance(target.ending, str) else target.ending
    if terminal["victory"] and (terminal["ending"] not in accepted_endings or terminal.get("ending_target") != target.ending_target
                                or terminal.get("report_seed") != seed
                                or not isinstance(terminal.get("last_view"), dict)
                                or terminal["last_view"].get("screen") != "VICTORY"):
        raise ValueError(f"Reported victory does not match the visible {target.name} ending and seed")


def _trial(worker, seed, policy, timeout, cpu_rate, target=ROURKE, *, route=None):
    job, evidence = _launch_worker(worker, timeout, cpu_rate)
    trial = dict(evidence, seed=seed, policy=policy)
    trial[target.victory_field] = False
    trial["error"] = _job_error(job)
    try:
        terminal, step_count = _read_trial(evidence["worker_log"], seed, policy, target, route=route)
    except (OSError, ValueError) as error:
        trial["error"] = trial["error"] or str(error)
    else:
        trial["result"] = terminal
        trial["trace_steps"] = step_count
        trial[target.victory_field] = trial["error"] is None and terminal["victory"]
    return trial


def _rank_policies(policies, trials, target=ROURKE):
    rows = []
    for policy in policies:
        attempts = [trial for trial in trials if trial["policy"] == policy]
        wins = [trial["result"]["actions"] for trial in attempts if trial[target.victory_field]]
        rows.append({"policy": policy, "trials": len(attempts), "victories": len(wins),
                     "errors": sum(trial["error"] is not None for trial in attempts),
                     "mean_actions_on_victory": mean(wins) if wins else None})
    return sorted(rows, key=lambda row: (-row["victories"], row["mean_actions_on_victory"] if row["victories"] else 0))


def _load_training(path, target=ROURKE):
    training = json.loads(path.read_text(encoding="utf-8"))
    if (not isinstance(training, dict) or training.get("schema") != target.schema
            or training.get("status") not in ("POLICY_SELECTED", "NO_TRAINING_VICTORIES")
            or training.get("mode") != "train" or not isinstance(training.get("seeds"), list)
            or not training["seeds"] or any(not isinstance(seed, str) or not seed for seed in training["seeds"])
            or len(set(training["seeds"])) != len(training["seeds"])):
        raise ValueError(f"Policy receipt must come from a completed {target.name} training campaign: {path}")
    if training["status"] == "POLICY_SELECTED":
        _policy_name(training.get("selected_policy"))
    elif training.get("selected_policy") is not None:
        raise ValueError(f"Training receipt has a selected policy despite having no victories: {path}")
    return training


def _resume_policies(previous, seeds, policies, target=ROURKE):
    prior_policies = previous.get("policies")
    if (not isinstance(prior_policies, list) or len(prior_policies) < 2
            or any(policy not in POLICIES for policy in prior_policies)
            or len(set(prior_policies)) != len(prior_policies)):
        raise ValueError("Prior training receipt has invalid candidate policies")
    if policies is not None and (len(policies) != len(prior_policies) or set(policies) != set(prior_policies)):
        raise ValueError("Resumed training requires the same candidate policy set as the prior receipt")
    overlap = set(seeds) & set(previous["seeds"])
    if overlap:
        raise ValueError(f"Resumed training requires fresh seeds. Already evaluated: {sorted(overlap)!r}")
    pairs = set(product(previous["seeds"], prior_policies))
    trials = previous.get("trials")
    if not isinstance(trials, list) or len(trials) != len(pairs):
        raise ValueError("Prior training receipt does not contain a complete paired trial matrix")
    for trial in trials:
        if (not isinstance(trial, dict) or not isinstance(trial.get("seed"), str)
                or not isinstance(trial.get("policy"), str) or "error" not in trial or trial["error"] is not None):
            raise ValueError("Prior training receipt contains an invalid or failed trial")
        pair = (trial["seed"], trial["policy"])
        if pair not in pairs:
            raise ValueError(f"Prior training receipt contains an unexpected or duplicate paired trial: {pair!r}")
        pairs.remove(pair)
        result = trial.get("result")
        _validate_result(result, *pair, target)
        if (type(trial.get(target.victory_field)) is not bool
                or trial[target.victory_field] != result["victory"]
                or type(trial.get("trace_steps")) is not int or trial["trace_steps"] < result["actions"]):
            raise ValueError(f"Prior training receipt has inconsistent evidence for {pair!r}")
    ranking = _rank_policies(prior_policies, trials, target)
    best = ranking[0]["policy"] if ranking[0]["victories"] else None
    if previous.get("selected_policy") != best or (best is None) != (previous["status"] == "NO_TRAINING_VICTORIES"):
        raise ValueError("Prior training receipt's selected policy does not match its paired outcomes")
    return policies if policies is not None else prior_policies


def _update_report(stream, report):
    stream.seek(0)
    json.dump(report, stream, indent=2)
    stream.write("\n")
    stream.truncate()
    stream.flush()


def _finish_report(report, policies, won_seeds, target=ROURKE):
    trials = report["trials"]
    if any(trial["error"] for trial in trials):
        report["status"] = "WORKER_FAILURE"
    elif report["mode"] == "train":
        report["policy_ranking"] = ranking = _rank_policies(policies, trials, target)
        if ranking[0]["victories"]:
            report["selected_policy"] = ranking[0]["policy"]
            report["status"] = "POLICY_SELECTED"
        else:
            report["status"] = "NO_TRAINING_VICTORIES"
    elif len(won_seeds) == len(report["seeds"]):
        report["status"] = "ALL_REQUESTED_SEEDS_WON"
    else:
        report["status"] = "REQUESTED_SEEDS_INCOMPLETE"


def _scheduled_trials(trials, route, fallback_trials):
    for worker, seed, policy in trials:
        yield worker, seed, policy, route
        for fallback_worker, fallback_policy, fallback_route in fallback_trials.get(seed, ()):
            yield fallback_worker, seed, fallback_policy, fallback_route


def _run_campaign(args, campaign, report_path, trials, import_worker, policies, training, previous=None, *,
                  target=ROURKE, fallback_trials=None):
    validate_layout(campaign, extra_write_paths=(report_path,))
    campaign = prepare_layout(campaign)
    report = {"schema": target.schema, "mode": args.action, "status": "RUNNING", "run_id": campaign.run_id,
              "storage_manifest": str(campaign.manifest_path), "seeds": args.seed, "policies": policies,
              "display_mode": "native" if args.native else "headless", "selected_policy": None, "trials": []}
    if training is not None:
        report["training_receipt"] = str(Path(args.policy_from).resolve())
        report["training_seed_overlap"] = sorted(set(args.seed) & set(training["seeds"]))
    previous_trials = [] if previous is None else previous["trials"]
    if args.action == "train":
        report["batch_seeds"] = args.seed
    route = getattr(args, "route", None)
    if route is not None:
        report["route"] = route
    fallback_trials = {} if fallback_trials is None else fallback_trials
    if fallback_trials:
        report["fallback_routes"] = args.fallback_route
        report["skipped_fallbacks"] = []
    if getattr(args, "route_model", None) is not None:
        report["route_model"] = str(args.route_model)
        report["route_model_sha256"] = args.route_model_sha256
    if getattr(args, "action_budget", None) is not None:
        report["action_budget"] = args.action_budget
    if previous is not None:
        report["resumed_training_receipt"] = str(args.resume_training.resolve())
        report["seeds"] = previous["seeds"] + args.seed
        report["trials"] = previous_trials.copy()
    won_seeds = {trial["seed"] for trial in previous_trials if trial[target.victory_field]}
    auto_selections = {}
    with report_path.open("x", encoding="utf-8") as stream:
        _update_report(stream, report)
        try:
            if import_worker is not None:
                job, evidence = _launch_worker(import_worker, args.import_timeout, args.cpu_rate)
                report["asset_import"] = dict(evidence, error=_job_error(job))
            if report.get("asset_import", {}).get("error"):
                report["status"] = "IMPORT_FAILURE"
            else:
                for worker, seed, policy, trial_route in _scheduled_trials(trials, route, fallback_trials):
                    if args.action == "solve" and seed in won_seeds:
                        continue
                    if trial_route is not None and auto_selections.get(seed) == trial_route:
                        report["skipped_fallbacks"].append({"seed": seed, "route": trial_route,
                                                            "reason": "already_selected_automatically"})
                        continue
                    trial = _trial(worker, seed, policy, args.timeout, args.cpu_rate, target, route=trial_route)
                    if fallback_trials:
                        trial["route"] = trial_route
                        if trial_route == "auto" and trial["error"] is None:
                            auto_selections[seed] = trial.get("result", {}).get("selected_route")
                    report["trials"].append(trial)
                    if trial[target.victory_field]:
                        won_seeds.add(seed)
                    _update_report(stream, report)
                    if trial["error"]:
                        break
                _finish_report(report, policies, won_seeds, target)
        except (StorageGuardError, OSError, RuntimeError, ValueError) as error:
            report["status"] = "CAMPAIGN_INTERRUPTED"
            report["error"] = error.as_dict() if isinstance(error, StorageGuardError) else str(error)
            raise
        finally:
            report["won_seeds"] = [seed for seed in report["seeds"] if seed in won_seeds]
            _update_report(stream, report)
    print(json.dumps({"status": report["status"], "report": str(report_path),
                      "trials": len(report["trials"]), "batch_trials": len(report["trials"]) - len(previous_trials),
                      "selected_policy": report["selected_policy"],
                      "victories": len(won_seeds)}))
    return 0 if report["status"] in ("POLICY_SELECTED", "ALL_REQUESTED_SEEDS_WON") else 1


def main(argv=None, *, target=ROURKE):
    parser = argparse.ArgumentParser(
        description=f"Run, compare, or retry player-visible {target.name} policies in fresh, capped Godot sessions."
    )
    parser.add_argument("action", choices=("check", "run", "train", "solve"))
    parser.add_argument("--root", default=DEFAULT_ROOT)
    parser.add_argument("--workspace", required=True, help="Godot source workspace under the admitted root")
    parser.add_argument("--run-id", required=True, help="Fresh campaign ID for the evidence and trial profiles")
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", str(LOCAL_GODOT)),
                        help="Absolute path to the existing Godot console executable")
    parser.add_argument("--seed", action="append", type=_seed_text, required=True)
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--policy", type=_policy_name, action="append",
                           help="Choose which policies to try. Solve and train use all three by default.")
    selection.add_argument("--policy-from", type=Path,
                           help="Use a training receipt's selected policy for run or ranking for solve")
    parser.add_argument("--resume-training", type=Path,
                        help="Extend a completed paired training receipt with this disjoint batch of seeds")
    parser.add_argument("--route", choices=(*target.routes, "auto"), help="Force a specific route or use a learned model")
    parser.add_argument("--route-model", type=Path, help="Read an admitted route model and select a route from visible play")
    parser.add_argument("--fallback-route", choices=target.routes, action="append", default=[],
                        help="For solve with a route model, retry this arm on a fresh profile after an unsuccessful attempt")
    parser.add_argument("--action-budget", type=int, help="Override the solver's accepted input budget, 1–3000")
    parser.add_argument("--timeout", type=int, default=180, help="Seconds per trial, maximum 1200")
    parser.add_argument("--cpu-rate", type=int, default=1200, help="Hundredths of a percent, maximum 1500")
    parser.add_argument("--native", action="store_true", help="Run gameplay in the native Godot window")
    parser.add_argument("--import-assets", action="store_true", help="Refresh Godot imports before the trials")
    parser.add_argument("--import-timeout", type=int, default=1200)
    parser.add_argument("--expected-write-gib", type=int, default=4)
    parser.add_argument("--reserve-gib", type=int, default=20)
    args = parser.parse_args(argv)
    try:
        if not 1 <= args.timeout <= 1200 or not 1 <= args.import_timeout <= 1200 or not 1 <= args.cpu_rate <= 1500:
            raise ValueError("Worker timeouts must be 1–1200 seconds and CPU rate must be 1–1500")
        if args.action_budget is not None and not 1 <= args.action_budget <= 3000:
            raise ValueError("Accepted input budget must be 1–3000")
        if len(args.seed) != len(set(args.seed)):
            raise ValueError("Duplicate seeds would count the same scenario more than once")
        if args.route_model is not None:
            if args.route not in (None, "auto"):
                raise ValueError("Use a manual --route or a --route-model with automatic selection")
            args.route = "auto"
        elif args.route == "auto":
            raise ValueError("Automatic route selection requires --route-model")
        if args.fallback_route:
            if args.action not in ("solve", "check") or args.route_model is None:
                raise ValueError("Use --fallback-route with solve or check and --route-model")
            if len(set(args.fallback_route)) != len(args.fallback_route):
                raise ValueError("Specify each fallback route only once")
        training = None
        previous = None
        policies = args.policy or list(POLICIES if args.action in ("train", "solve") else POLICIES[:1])
        if args.route is not None and args.policy is None and args.action != "train":
            policies = [route_policy(args.route)]
        if args.resume_training:
            if args.action != "train" or args.policy_from:
                raise ValueError("Use --resume-training with train and optional explicit candidate policies")
            previous = _load_training(args.resume_training, target)
            policies = _resume_policies(previous, args.seed, args.policy, target)
        if args.policy_from:
            training = _load_training(args.policy_from, target)
            selected = training.get("selected_policy")
            if selected is None and args.action != "solve":
                raise ValueError("A fixed run requires a training receipt with a selected policy")
            if args.action == "solve":
                ranking = training.get("policy_ranking")
                if (not isinstance(ranking, list) or not ranking
                        or any(not isinstance(row, dict) or not isinstance(row.get("policy"), str)
                               for row in ranking)):
                    raise ValueError("Solve requires a training receipt with its policy ranking")
                ranked = [_policy_name(row["policy"]) for row in ranking]
                if (selected is not None and ranked[0] != selected) or len(set(ranked)) != len(ranked):
                    raise ValueError("Training receipt has an inconsistent policy ranking")
                policies = ranked + [policy for policy in POLICIES if policy not in ranked]
            else:
                policies = [selected]
        if args.action == "train" and len(set(policies)) < 2:
            raise ValueError("Training requires two or more different --policy values")
        if len(set(policies)) != len(policies) or (args.action == "run" and len(policies) != 1):
            raise ValueError("Use a single policy for run or distinct policies for train and solve")
        if args.fallback_route and len(policies) != 1:
            raise ValueError("Route fallback requires exactly one automatic trial per seed")

        def plan(run_id):
            return plan_layout(args.root, args.workspace, run_id, args.expected_write_gib * GIB, args.reserve_gib * GIB)

        campaign = plan(args.run_id)
        report_path = campaign.evidence / "solver-campaign.json"
        validate_layout(campaign, extra_write_paths=(report_path,))
        args.route_model_sha256 = None
        if args.route_model is not None:
            args.route_model, args.route_model_sha256 = _load_route_model(args.route_model, campaign.root, target)
        if previous is not None and (previous.get("route") != args.route
                                     or previous.get("route_model_sha256") != args.route_model_sha256):
            raise ValueError("Resumed training requires the same route and route model as the prior receipt")
        if previous is not None and previous.get("action_budget") != args.action_budget:
            raise ValueError("Resumed training requires the same action budget as the prior receipt")
        engine = Path(args.godot)
        if not engine.is_absolute() or not engine.is_file():
            raise ValueError(f"An existing absolute Godot console executable is required: {engine}")
        for relative in ("project.godot", target.script):
            if not (campaign.workspace / relative).is_file():
                raise ValueError(f"Admitted source workspace is missing {campaign.workspace / relative}")
        cache = campaign.workspace / ".godot"
        import_worker = None
        if (args.import_assets or not (cache / "global_script_class_cache.cfg").is_file()
                or not (cache / "imported").is_dir()):
            import_worker = _plan_worker(plan(_trial_id(args.run_id, "-import")), engine)
        trial_index = 0

        def plan_trial(seed, policy, route):
            nonlocal trial_index
            trial_index += 1
            layout = plan(_trial_id(args.run_id, f"-trial-{trial_index}"))
            return _plan_worker(layout, engine, seed=seed, policy=policy, native=args.native, target=target,
                                route=route, route_model=args.route_model if route == "auto" else None,
                                action_budget=args.action_budget)

        trials = []
        fallback_trials = {}
        for seed, policy in product(args.seed, policies):
            trials.append((plan_trial(seed, policy, args.route), seed, policy))
            if args.fallback_route:
                fallback_trials[seed] = [(plan_trial(seed, route_policy(route), route), route_policy(route), route)
                                         for route in args.fallback_route]
        if args.action == "check":
            scheduled = _scheduled_trials(trials, args.route, fallback_trials)
            print(json.dumps({"status": "PREFLIGHT_PASS_NO_WRITES", "campaign_storage": campaign.as_dict(),
                              "report": str(report_path), "asset_import_planned": import_worker is not None,
                              "trials": [worker[0].as_dict() for worker, _, _, _ in scheduled]}))
            return 0
        return _run_campaign(args, campaign, report_path, trials, import_worker, policies, training, previous,
                             target=target, fallback_trials=fallback_trials)
    except StorageGuardError as error:
        print(json.dumps({"status": "STORAGE_OR_LAUNCH_REJECTED", **error.as_dict()}), file=sys.stderr)
    except (argparse.ArgumentTypeError, OSError, RuntimeError, ValueError) as error:
        print(json.dumps({"status": "STORAGE_OR_LAUNCH_REJECTED", "error": str(error)}), file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
