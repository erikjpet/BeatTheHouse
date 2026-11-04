#!/usr/bin/env python3
"""Reconcile explicit BTH runtime records without inspecting or changing the host.

This module never discovers processes, kills processes, closes tabs, deletes profiles,
or executes cleanup commands. A candidate orphan is a review finding, not authority to
stop anything. Input evidence is asserted by its collector and is not independently
verified here. Python 3.10+, standard library only.
"""

from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timedelta, timezone
import json
import math
from pathlib import Path
import sys
from typing import Any


SCHEMA = "bth.runtime_inventory/v1"
REPORT_SCHEMA = "bth.runtime_reconciliation/v1"
OWNER_SCHEMA = "bth.owner_snapshot/v1"
CLEANUP_EVENTS = ("success", "failure", "timeout", "interruption")
FUTURE_TOLERANCE = timedelta(minutes=5)


class InputError(ValueError):
    """A supplied lifecycle record cannot be safely interpreted."""


def timestamp(value: Any, where: str) -> datetime:
    if not isinstance(value, str) or not value.strip():
        raise InputError(f"{where} must be a timezone-qualified ISO timestamp")
    try:
        result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise InputError(f"{where} must be a valid ISO timestamp") from exc
    if result.tzinfo is None:
        raise InputError(f"{where} must include a timezone")
    return result.astimezone(timezone.utc)


def iso(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def obj(value: Any, where: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise InputError(f"{where} must be an object")
    return value


def fields(value: dict[str, Any], required: tuple[str, ...], where: str) -> None:
    missing = [key for key in required if key not in value]
    if missing:
        raise InputError(f"{where} is missing required fields: {', '.join(missing)}")


def text(value: Any, where: str, *, nullable: bool = False) -> str | None:
    if nullable and value is None:
        return None
    if not isinstance(value, str) or not value.strip():
        raise InputError(f"{where} must be a nonempty string")
    return value


def evidence(value: Any, where: str) -> list[str]:
    if not isinstance(value, list):
        raise InputError(f"{where} must be an array of nonempty strings")
    for item in value:
        text(item, where)
    return value


def choice(value: Any, values: set[str], where: str) -> None:
    if not isinstance(value, str) or value not in values:
        raise InputError(f"{where} must be one of {', '.join(sorted(values))}")


def optional_time(value: Any, where: str) -> None:
    if value is not None:
        timestamp(value, where)


def validate_inventory(value: Any) -> dict[str, Any]:
    inventory = obj(value, "inventory")
    if inventory.get("schema") != SCHEMA:
        raise InputError(f"inventory.schema must be {SCHEMA!r}")
    timestamp(inventory.get("observed_at"), "inventory.observed_at")
    scope = obj(inventory.get("scope"), "inventory.scope")
    text(scope.get("description"), "inventory.scope.description")
    if not isinstance(scope.get("complete"), bool):
        raise InputError("inventory.scope.complete must be boolean")
    evidence(scope.get("evidence"), "inventory.scope.evidence")
    if not isinstance(inventory.get("instances"), list):
        raise InputError("inventory.instances must be an array")
    seen = set()
    for index, instance in enumerate(inventory["instances"]):
        where = f"inventory.instances[{index}]"
        instance = obj(instance, where)
        instance_id = text(instance.get("instance_id"), f"{where}.instance_id")
        if instance_id in seen:
            raise InputError(f"Duplicate stable instance_id: {instance_id}")
        seen.add(instance_id)
        text(instance.get("task_id"), f"{where}.task_id")
        text(instance.get("owner_task_ref"), f"{where}.owner_task_ref", nullable=True)
        choice(instance.get("kind"), {"game", "browser", "profile", "temporary_server", "export", "test_job"}, f"{where}.kind")
        choice(instance.get("ownership"), {"task_owned", "user", "shared_service", "unknown"}, f"{where}.ownership")
        choice(instance.get("state"), {"active", "idle", "ended", "superseded", "unknown"}, f"{where}.state")
        launch = obj(instance.get("launch_identity"), f"{where}.launch_identity")
        fields(launch, ("nonce", "key", "started_at", "evidence"), f"{where}.launch_identity")
        for field in ("nonce", "key"):
            text(launch.get(field), f"{where}.launch_identity.{field}", nullable=True)
        optional_time(launch.get("started_at"), f"{where}.launch_identity.started_at")
        evidence(launch.get("evidence"), f"{where}.launch_identity.evidence")
        current = obj(instance.get("current_identity"), f"{where}.current_identity")
        fields(current, ("state", "observed_at", "key", "evidence"), f"{where}.current_identity")
        choice(current.get("state"), {"match", "mismatch", "absent", "unknown"}, f"{where}.current_identity.state")
        timestamp(current.get("observed_at"), f"{where}.current_identity.observed_at")
        text(current.get("key"), f"{where}.current_identity.key", nullable=True)
        evidence(current.get("evidence"), f"{where}.current_identity.evidence")
        activity = obj(instance.get("activity"), f"{where}.activity")
        fields(activity, ("state", "observed_at", "lease_until", "evidence"), f"{where}.activity")
        choice(activity.get("state"), {"active", "idle", "unknown"}, f"{where}.activity.state")
        timestamp(activity.get("observed_at"), f"{where}.activity.observed_at")
        optional_time(activity.get("lease_until"), f"{where}.activity.lease_until")
        evidence(activity.get("evidence"), f"{where}.activity.evidence")
        protected = obj(instance.get("protected"), f"{where}.protected")
        for field in ("saves", "shared_resources"):
            if not isinstance(protected.get(field), bool):
                raise InputError(f"{where}.protected.{field} must be boolean")
        cleanup = obj(instance.get("cleanup"), f"{where}.cleanup")
        fields(cleanup, ("contract", "receipt"), f"{where}.cleanup")
        contract = obj(cleanup.get("contract"), f"{where}.cleanup.contract")
        for event in CLEANUP_EVENTS:
            evidence(contract.get(event, []), f"{where}.cleanup.contract.{event}")
        receipt = cleanup.get("receipt")
        if receipt is not None:
            receipt = obj(receipt, f"{where}.cleanup.receipt")
            fields(receipt, ("observed_at", "outcome", "identity_nonce", "remaining_count", "evidence"), f"{where}.cleanup.receipt")
            timestamp(receipt.get("observed_at"), f"{where}.cleanup.receipt.observed_at")
            choice(receipt.get("outcome"), {"verified_empty", "verified_closed", "failed", "pending", "uncertain", "not_attempted"}, f"{where}.cleanup.receipt.outcome")
            text(receipt.get("identity_nonce"), f"{where}.cleanup.receipt.identity_nonce", nullable=True)
            remaining = receipt.get("remaining_count")
            if remaining is not None and (isinstance(remaining, bool) or not isinstance(remaining, int) or remaining < 0):
                raise InputError(f"{where}.cleanup.receipt.remaining_count must be null or a nonnegative integer")
            evidence(receipt.get("evidence"), f"{where}.cleanup.receipt.evidence")
    return inventory


def validate_owners(value: Any) -> dict[str, Any]:
    owners = obj(value, "owners")
    if owners.get("schema") != OWNER_SCHEMA:
        raise InputError(f"owners.schema must be {OWNER_SCHEMA!r}")
    timestamp(owners.get("observed_at"), "owners.observed_at")
    if not isinstance(owners.get("tasks"), list):
        raise InputError("owners.tasks must be an array")
    seen = set()
    for index, task in enumerate(owners["tasks"]):
        where = f"owners.tasks[{index}]"
        task = obj(task, where)
        ref = text(task.get("task_ref"), f"{where}.task_ref")
        if ref in seen:
            raise InputError(f"Duplicate owner task_ref: {ref}")
        seen.add(ref)
        choice(task.get("state"), {"active", "idle", "ended", "not_found"}, f"{where}.state")
        timestamp(task.get("observed_at"), f"{where}.observed_at")
    return owners


def check_inventory(
    inventory: dict[str, Any],
    owners: dict[str, Any] | None = None,
    *,
    now: datetime | None = None,
    max_age_hours: float = 24,
) -> dict[str, Any]:
    """Report lifecycle evidence gaps; never authorize or perform resource cleanup."""
    inventory = validate_inventory(inventory)
    owners = validate_owners(owners) if owners is not None else None
    if isinstance(max_age_hours, bool) or not isinstance(max_age_hours, (int, float)) or not math.isfinite(max_age_hours) or not 0 < max_age_hours <= 24 * 36500:
        raise InputError("max_age_hours must be finite and greater than zero (at most 100 years)")
    now = now or datetime.now(timezone.utc)
    if now.tzinfo is None:
        raise InputError("now must include a timezone")
    now = now.astimezone(timezone.utc)
    age_limit = timedelta(hours=max_age_hours)
    findings = []
    decisions = []

    def add(code: str, item: dict[str, Any] | None, message: str, references: list[str] | None = None, severity: str = "error") -> None:
        findings.append({"code": code, "severity": severity,
                         "task_id": item["task_id"] if item else "BTH-RUNTIME-CLEANUP-001",
                         "instance_id": item["instance_id"] if item else None,
                         "message": message, "evidence": references or []})

    def fresh(value: str) -> bool:
        age = now - timestamp(value, "observation timestamp")
        return -FUTURE_TOLERANCE <= age <= age_limit

    def observation(value: str, item: dict[str, Any] | None, label: str) -> bool:
        at = timestamp(value, label)
        if at > now + FUTURE_TOLERANCE:
            add("RUNTIME_FUTURE_OBSERVATION", item, f"{label} is in the future; it cannot prove current use or identity.", [value])
            return False
        if now - at > age_limit:
            add("RUNTIME_STALE_OBSERVATION", item, f"{label} is stale; revalidate through the permitted owner lifecycle.", [value])
            return False
        return True

    inventory_fresh = observation(inventory["observed_at"], None, "Inventory snapshot")
    if not inventory["scope"]["complete"] or not inventory["scope"]["evidence"]:
        add("RUNTIME_COVERAGE_INCOMPLETE", None, "Inventory covers only explicitly recorded resources; missing ownership must remain open.", inventory["scope"]["evidence"])
    owner_map = {task["task_ref"]: task for task in owners["tasks"]} if owners else {}
    owner_snapshot_fresh = observation(owners["observed_at"], None, "Owner snapshot") if owners else False
    if owners is None:
        add("RUNTIME_OWNER_SNAPSHOT_MISSING", None, "Supply a fresh lifecycle owner snapshot; no cleanup candidate is confirmed.")

    for item in inventory["instances"]:
        launch, current, activity = item["launch_identity"], item["current_identity"], item["activity"]
        receipt = item["cleanup"]["receipt"]
        decision = {"instance_id": item["instance_id"], "task_id": item["task_id"],
                    "disposition": "review_required", "cleanup_authorized": False}
        decisions.append(decision)
        launched = timestamp(launch["started_at"], "launch.started_at") if launch["started_at"] else None
        complete_launch = bool(launch["nonce"] and launch["key"] and launched and launch["evidence"])
        if not complete_launch:
            add("RUNTIME_LAUNCH_IDENTITY_UNKNOWN", item, "Exact nonce-bound launch/start identity is incomplete. A PID or port alone never identifies a cleanup target.", launch["evidence"])
        elif launched > now + FUTURE_TOLERANCE:
            add("RUNTIME_FUTURE_LAUNCH", item, "Launch identity is future-dated and cannot identify an existing instance.", [launch["started_at"]])
            complete_launch = False

        current_fresh = observation(current["observed_at"], item, "Current identity")
        activity_fresh = observation(activity["observed_at"], item, "Activity observation")
        for label, value in (("Current identity", current["observed_at"]), ("Activity observation", activity["observed_at"])):
            if launched and timestamp(value, label) < launched:
                add("RUNTIME_PRELAUNCH_OBSERVATION", item, f"{label} predates this launch and cannot establish its current state.", [value, launch["started_at"]])
                if label == "Current identity":
                    current_fresh = False
                else:
                    activity_fresh = False

        identity_match = complete_launch and current_fresh and current["state"] == "match" and current["key"] == launch["key"] and bool(current["evidence"])
        identity_absent = complete_launch and current_fresh and current["state"] == "absent" and bool(current["evidence"])
        if current["state"] == "mismatch" or (current["state"] == "match" and current["key"] != launch["key"]):
            add("RUNTIME_IDENTITY_MISMATCH", item, "Current identity differs from the recorded launch. A reused PID must remain untouched.", current["evidence"])
        elif current["state"] == "unknown" or not current["evidence"]:
            add("RUNTIME_CURRENT_IDENTITY_UNKNOWN", item, "Current existence and identity are unverified; do not infer an orphan from an old launch record.", current["evidence"])

        owner = owner_map.get(item["owner_task_ref"])
        owner_fresh = bool(owner and owner_snapshot_fresh and observation(owner["observed_at"], item, "Owner state"))
        if owner is None:
            add("RUNTIME_OWNER_UNKNOWN", item, "Resource owner is absent from the explicit owner snapshot; preserve it pending reconciliation.")
        active_owner = bool(owner and owner_fresh and owner["state"] == "active")
        ended_owner = bool(owner and owner_fresh and owner["state"] == "ended")
        live_lease = bool(activity["lease_until"] and timestamp(activity["lease_until"], "activity.lease_until") > now and activity_fresh and activity["evidence"])
        active_activity = activity["state"] == "active" and activity_fresh and bool(activity["evidence"])

        missing_events = [event for event in CLEANUP_EVENTS if not item["cleanup"]["contract"].get(event)]
        if item["ownership"] == "task_owned" and item["kind"] != "profile" and missing_events:
            add("RUNTIME_CLEANUP_CONTRACT_INCOMPLETE", item, "Cleanup-on-finish/failure/timeout/interruption lacks verified contract evidence.", missing_events)
        receipt_verified = False
        if receipt:
            receipt_time = timestamp(receipt["observed_at"], "cleanup.receipt.observed_at")
            receipt_identity = complete_launch and receipt["identity_nonce"] == launch["nonce"] and bool(receipt["evidence"]) and receipt_time <= now + FUTURE_TOLERANCE and bool(launched and receipt_time >= launched)
            receipt_verified = receipt_identity and receipt["outcome"] in {"verified_empty", "verified_closed"} and receipt["remaining_count"] == 0
            if receipt["outcome"] in {"verified_empty", "verified_closed"} and not receipt_verified:
                add("RUNTIME_CLEANUP_RECEIPT_UNVERIFIED", item, "A clean receipt needs this launch nonce, supporting evidence, a postlaunch timestamp and zero remaining resources.", receipt["evidence"])
            if receipt["remaining_count"] not in (None, 0):
                add("RUNTIME_RESOURCES_REMAIN", item, "Cleanup receipt records resources still present.", receipt["evidence"])
            if receipt["outcome"] in {"failed", "uncertain", "pending"}:
                add("RUNTIME_CLEANUP_" + receipt["outcome"].upper(), item, "Cleanup is not confirmed. Preserve the exact target and uncertain outcome; check before retrying.", receipt["evidence"])
            if receipt_time > now + FUTURE_TOLERANCE:
                add("RUNTIME_FUTURE_OBSERVATION", item, "Cleanup receipt is future-dated and cannot prove cleanup.", [receipt["observed_at"]])
            if receipt_verified and identity_match and timestamp(current["observed_at"], "current identity") >= receipt_time:
                add("RUNTIME_CLEANUP_CONTRADICTED", item, "A later identity observation reports this cleaned launch still present; reconcile before closing the item.", current["evidence"] + receipt["evidence"])
                receipt_verified = False

        if item["ownership"] == "unknown":
            add("RUNTIME_OWNERSHIP_UNKNOWN", item, "Ownership is unproven; preserve the instance.")
        if item["ownership"] == "task_owned" and item["kind"] != "profile" and item["state"] in {"ended", "superseded"} and not receipt_verified and not identity_absent:
            add("RUNTIME_ENDED_WITHOUT_CLEANUP", item, "Ended or superseded task instance lacks a verified empty/closed receipt or fresh exact-identity absence evidence.", [item["state"]])
        if item["ownership"] in {"user", "shared_service"} or item["protected"]["saves"] or item["protected"]["shared_resources"] or item["kind"] == "profile":
            decision["disposition"] = "preserve_protected_resource"
            continue
        if item["ownership"] == "unknown":
            decision["disposition"] = "preserve_unknown_ownership"
            continue
        if receipt_verified:
            decision["disposition"] = "historical_cleanup_verified"
            continue
        if identity_absent:
            decision["disposition"] = "recorded_launch_absent"
            continue
        if active_owner or live_lease or active_activity:
            decision["disposition"] = "preserve_active_use"
            continue
        if ended_owner and identity_match and inventory_fresh and activity_fresh and activity["state"] == "idle" and activity["evidence"] and item["state"] in {"ended", "superseded", "idle"}:
            add("RUNTIME_ORPHAN_CANDIDATE", item, "Fresh ended-owner and matching launch evidence suggest an orphan. Review through its permitted lifecycle; this report does not authorize termination.", current["evidence"] + activity["evidence"])
            decision["disposition"] = "candidate_orphan_review_required"
        else:
            add("RUNTIME_USE_UNCERTAIN", item, "Current use or abandonment is unproven. Keep the instance protected until its owner lifecycle can establish a safe outcome.", activity["evidence"])

    findings.sort(key=lambda entry: (entry["task_id"], entry["instance_id"] or "", entry["code"]))
    counts = Counter(entry["severity"] for entry in findings)
    return {"schema": REPORT_SCHEMA, "checked_at": iso(now), "inventory_observed_at": inventory["observed_at"],
            "summary": {"instances_checked": len(decisions), "errors": counts["error"], "warnings": counts["warning"],
                        "candidate_orphans": sum(item["disposition"] == "candidate_orphan_review_required" for item in decisions),
                        "historical_cleanup_verified": sum(item["disposition"] == "historical_cleanup_verified" for item in decisions)},
            "findings": findings, "instances": decisions,
            "limitations": ["Explicit records only: no host-wide process, browser or listener inspection was performed.",
                            "Input evidence is asserted by the collector; historical cleanup does not prove global current absence.",
                            "No cleanup is authorized or executed by this report; preserve active work, saves, profiles and shared services."]}


def render_text(report: dict[str, Any]) -> str:
    summary = report["summary"]
    lines = [f"BTH runtime reconciliation at {report['checked_at']}",
             f"Checked {summary['instances_checked']} explicit instances: {summary['errors']} error(s); {summary['candidate_orphans']} orphan candidate(s)."]
    for finding in report["findings"]:
        lines.append(f"[{finding['severity'].upper()}] {finding['code']} {finding['task_id']} {finding['instance_id'] or '(inventory)'}: {finding['message']}")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", required=True, type=Path)
    parser.add_argument("--owners", type=Path)
    parser.add_argument("--now")
    parser.add_argument("--max-age-hours", type=float, default=24)
    parser.add_argument("--format", choices=("text", "json"), default="text")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.output:
            output_path = args.output.resolve()
            inputs = [("runtime inventory", args.inventory)]
            if args.owners:
                inputs.append(("owner snapshot", args.owners))
            for label, input_path in inputs:
                same_file = output_path == input_path.resolve()
                if not same_file and args.output.exists() and input_path.exists():
                    same_file = args.output.samefile(input_path)
                if same_file:
                    raise InputError(f"--output must not overwrite the {label} input: {input_path}")
        inventory = json.loads(args.inventory.read_text(encoding="utf-8-sig"))
        owners = json.loads(args.owners.read_text(encoding="utf-8-sig")) if args.owners else None
        report = check_inventory(inventory, owners, now=timestamp(args.now, "--now") if args.now else None, max_age_hours=args.max_age_hours)
        result = json.dumps(report, indent=2) + "\n" if args.format == "json" else render_text(report)
        if args.output:
            args.output.write_text(result, encoding="utf-8")
        else:
            sys.stdout.write(result)
        return 1 if report["summary"]["errors"] else 0
    except (InputError, OSError, UnicodeError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"Input error: {exc}\n")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
