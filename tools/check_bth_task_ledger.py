#!/usr/bin/env python3
"""Manually reconcile the Beat the House task ledger; Python 3.10+, no dependencies.

This program reads files and reports gaps. It does not schedule checks, assign work,
contact owners, fetch Git history, change task states, or publish anything. An open
backlog can correctly produce exit 1. A completed implementation batch never closes
its parent objective. Historical evidence is not a new app-change request.

Exit codes: 0 = no errors (warnings may remain), 1 = actionable findings,
2 = invalid input or inability to read/write a requested file.

Example, from the repository root::

    python tools/check_bth_task_ledger.py --ledger docs/todo/bth_task_ledger.json \
        --owners docs/todo/bth_task_owner_snapshot.json --group current --format json

Owner/blocker freshness uses --max-owner-age-hours (24 by default). ISO timestamps
must include a timezone. --verify-git only runs local ``git cat-file -e SHA^{commit}``;
it never fetches and cannot establish that a commit was deployed or contains a fix.
"""

from __future__ import annotations

import argparse
from collections import Counter
import copy
from datetime import datetime, timedelta, timezone
import html
import json
import math
from pathlib import Path
import re
import subprocess
import sys
from typing import Any


SCHEMA = "bth.task_ledger/v1"
REPORT_SCHEMA = "bth.task_reconciliation/v1"
OWNER_SCHEMA = "bth.owner_snapshot/v1"
SHA = re.compile(r"^[0-9a-fA-F]{40}$")
HOLD = re.compile(
    r"\bintentional[ _-]+holds?\b|\bheld_user_hands_on\b|"
    r"\bhands[ -]+on[ _-]+holds?\b|\bheld[ _-]+for[ _-]+user\b",
    re.IGNORECASE,
)
PORTRAIT = re.compile(r"\bportrait\b|portrait[_-](?:mode|layout)", re.IGNORECASE)


class InputError(ValueError):
    """The input cannot be interpreted safely using the documented schema."""


def timestamp(value: Any, where: str) -> datetime:
    if not isinstance(value, str) or not value.strip():
        raise InputError(f"{where} must be a timezone-qualified ISO timestamp")
    try:
        result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise InputError(f"{where} is not a valid ISO timestamp: {value!r}") from exc
    if result.tzinfo is None:
        raise InputError(f"{where} must include a timezone")
    return result.astimezone(timezone.utc)


def iso(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def nonempty(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def obj(value: Any, where: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise InputError(f"{where} must be an object")
    return value


def array(value: Any, where: str) -> list[Any]:
    if not isinstance(value, list):
        raise InputError(f"{where} must be an array")
    return value


def enum(value: Any, choices: set[str], where: str) -> None:
    if not isinstance(value, str) or value not in choices:
        raise InputError(f"{where} must be one of {', '.join(sorted(choices))}")


def strings(value: Any, where: str) -> list[str]:
    result = array(value, where)
    if not all(nonempty(entry) for entry in result):
        raise InputError(f"{where} must contain nonempty strings")
    return result


def validate_deployment(value: Any, where: str) -> None:
    deployment = obj(value, where)
    if not isinstance(deployment.get("required"), bool):
        raise InputError(f"{where}.required must be boolean")
    enum(deployment.get("state"), {"verified", "pending", "unknown", "not_applicable"}, f"{where}.state")
    strings(deployment.get("evidence", []), f"{where}.evidence")


def validate_commits(value: Any, where: str) -> None:
    for index, entry in enumerate(array(value, where)):
        entry = obj(entry, f"{where}[{index}]")
        if not isinstance(entry.get("sha"), str):
            raise InputError(f"{where}[{index}].sha must be a string")
        strings(entry.get("evidence", []), f"{where}[{index}].evidence")


def validate_ledger(ledger: Any) -> dict[str, Any]:
    ledger = obj(ledger, "ledger")
    if ledger.get("schema") != SCHEMA:
        raise InputError(f"ledger.schema must be {SCHEMA!r}")
    timestamp(ledger.get("updated_at"), "ledger.updated_at")
    policies = obj(ledger.get("policies"), "ledger.policies")
    if "runtime_cleanup_required" in policies and not isinstance(policies["runtime_cleanup_required"], bool):
        raise InputError("ledger.policies.runtime_cleanup_required must be boolean")
    if "user_requested_pauses" in policies:
        for index, pause_policy in enumerate(array(policies["user_requested_pauses"], "ledger.policies.user_requested_pauses")):
            pause_policy = obj(pause_policy, f"ledger.policies.user_requested_pauses[{index}]")
            strings(pause_policy.get("task_ids", []), f"ledger.policies.user_requested_pauses[{index}].task_ids")
    if "metadata" in ledger:
        metadata = obj(ledger["metadata"], "ledger.metadata")
        if "markdown_ledger_section" in metadata and not nonempty(metadata["markdown_ledger_section"]):
            raise InputError("ledger.metadata.markdown_ledger_section must be a nonempty string")
    for index, task in enumerate(array(ledger.get("objectives"), "ledger.objectives")):
        where = f"ledger.objectives[{index}]"
        task = obj(task, where)
        if not nonempty(task.get("id")):
            raise InputError(f"{where}.id must be a nonempty string")
        enum(task.get("kind"), {"objective", "acceptance_check", "observation", "operation"}, f"{where}.kind")
        enum(task.get("group"), {"current", "historical"}, f"{where}.group")
        enum(task.get("state"), {"open", "complete", "superseded"}, f"{where}.state")
        strings(task.get("parent_ids", []), f"{where}.parent_ids")
        strings(task.get("implementation_batches", []), f"{where}.implementation_batches")
        obj(task.get("owner", {}), f"{where}.owner")
        objective = obj(task.get("objective", {}), f"{where}.objective")
        for number, criterion in enumerate(array(objective.get("acceptance", []), f"{where}.objective.acceptance")):
            criterion = obj(criterion, f"{where}.objective.acceptance[{number}]")
            enum(criterion.get("state"), {"pass", "open", "unknown", "unavailable"}, f"{where}.acceptance[{number}].state")
            if not isinstance(criterion.get("required"), bool):
                raise InputError(f"{where}.acceptance[{number}].required must be boolean")
            strings(criterion.get("evidence", []), f"{where}.acceptance[{number}].evidence")
        coverage = obj(objective.get("coverage", {}), f"{where}.objective.coverage")
        for field in ("required", "complete"):
            if not isinstance(coverage.get(field), bool):
                raise InputError(f"{where}.objective.coverage.{field} must be boolean")
        for number, area in enumerate(array(coverage.get("areas", []), f"{where}.objective.coverage.areas")):
            area = obj(area, f"{where}.coverage.areas[{number}]")
            enum(area.get("state"), {"reviewed", "remaining", "unknown"}, f"{where}.coverage.areas[{number}].state")
            strings(area.get("evidence", []), f"{where}.coverage.areas[{number}].evidence")
        validate_commits(task.get("commits", []), f"{where}.commits")
        validate_deployment(task.get("deployment"), f"{where}.deployment")
        blocker = obj(task.get("blocker", {}), f"{where}.blocker")
        enum(blocker.get("state"), {"none", "active", "unknown"}, f"{where}.blocker.state")
        strings(blocker.get("evidence", []), f"{where}.blocker.evidence")
        if blocker.get("observed_at") is not None:
            timestamp(blocker["observed_at"], f"{where}.blocker.observed_at")
        array(task.get("planned_app_changes", []), f"{where}.planned_app_changes")
        timestamp(task.get("updated_at"), f"{where}.updated_at")
    for index, batch in enumerate(array(ledger.get("batches"), "ledger.batches")):
        where = f"ledger.batches[{index}]"
        batch = obj(batch, where)
        if not nonempty(batch.get("id")) or not nonempty(batch.get("parent_id")):
            raise InputError(f"{where}.id and .parent_id must be nonempty strings")
        enum(batch.get("state"), {"open", "complete"}, f"{where}.state")
        strings(batch.get("scope", []), f"{where}.scope")
        validate_commits(batch.get("commits", []), f"{where}.commits")
        validate_deployment(batch.get("deployment"), f"{where}.deployment")
        if "owner" in batch:
            obj(batch["owner"], f"{where}.owner")
        if "blocker" in batch:
            blocker = obj(batch["blocker"], f"{where}.blocker")
            enum(blocker.get("state"), {"none", "active", "unknown"}, f"{where}.blocker.state")
            strings(blocker.get("evidence", []), f"{where}.blocker.evidence")
            if blocker.get("observed_at") is not None:
                timestamp(blocker["observed_at"], f"{where}.blocker.observed_at")
    return ledger


def validate_owners(owners: Any) -> dict[str, Any]:
    owners = obj(owners, "owners")
    if owners.get("schema") != OWNER_SCHEMA:
        raise InputError(f"owners.schema must be {OWNER_SCHEMA!r}")
    timestamp(owners.get("observed_at"), "owners.observed_at")
    seen = set()
    for index, task in enumerate(array(owners.get("tasks"), "owners.tasks")):
        where = f"owners.tasks[{index}]"
        task = obj(task, where)
        if not nonempty(task.get("task_ref")) or task["task_ref"] in seen:
            raise InputError(f"{where}.task_ref must be nonempty and unique")
        seen.add(task["task_ref"])
        enum(task.get("state"), {"active", "idle", "ended", "not_found"}, f"{where}.state")
        timestamp(task.get("observed_at"), f"{where}.observed_at")
    return owners


def original_save_demand(blocker: dict[str, Any]) -> bool:
    """Recognize a demand for unavailable user saves, not retained agent fixtures."""
    kind = str(blocker.get("kind") or "").lower().replace("-", "_")
    if kind in {"exact_user_save", "original_user_save", "user_incident_save"}:
        return True
    description = str(blocker.get("description") or "").lower()
    user = r"(?:user|erik|player)"
    precise_save = r"(?:original|exact)[ -]*(?:incident[ -]*)?save(?:[ -]*(?:check|verification))?s?"
    # Both unavailable identity and an actual dependency are necessary. Merely
    # recording that original user saves are unavailable must not block work.
    request = r"(?:await|waiting|require|need|request|provide|supply|pending|dependent|depend on)"
    for clause in re.split(r"[.;\n]", description):
        if re.search(r"\b(?:no need|no longer|not waiting|do not require|does not require)\b", clause):
            continue
        has_user = re.search(r"\b" + user + r"\b", clause) or blocker.get("requires_user_input") is True
        has_save = re.search(r"\b" + precise_save + r"\b", clause)
        has_request = re.search(r"\b" + request, clause)
        if has_user and has_save and has_request:
            return True
    return False


def markdown_text(value: str) -> str:
    """Normalize inline presentation, retaining the actual displayed cell text."""
    value = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", value)
    value = re.sub(r"<br\s*/?>", " ", value, flags=re.IGNORECASE)
    return " ".join(html.unescape(value.replace("`", "").replace("**", "").replace("\\|", "|")).split())


def supported_user_pause(item: dict[str, Any], policies: dict[str, Any]) -> bool:
    """A row cannot exempt itself: require a matching explicit user policy."""
    pause = item.get("pause")
    if not isinstance(pause, dict) or pause.get("state") != "active" or pause.get("requested_by") != "user":
        return False
    if not nonempty(pause.get("source")) or not nonempty(pause.get("instruction")):
        return False
    for policy in policies.get("user_requested_pauses", []):
        if (isinstance(policy, dict) and policy.get("state") == "active"
                and policy.get("requested_by") == "user" and nonempty(policy.get("source"))
                and isinstance(policy.get("task_ids"), list) and item["id"] in policy["task_ids"]
                and nonempty(policy.get("instruction"))
                and " ".join(policy["instruction"].split()) == " ".join(pause["instruction"].split())):
            return True
    return False


def is_portrait_app_change(change: Any) -> bool:
    """Keep explicitly identified tests/evidence out of the app-change policy."""
    if isinstance(change, dict):
        kind = str(change.get("kind") or change.get("type") or "").lower()
        if kind in {"test", "tests", "regression_test", "verification", "evidence", "screenshot", "acceptance_check"}:
            return False
        text = json.dumps(change, ensure_ascii=False)
    else:
        text = str(change)
    if not PORTRAIT.search(text):
        return False
    # A verification action can mention the app layout without proposing to
    # implement it. Mixed app-change + test descriptions must use separate rows.
    if re.match(r"\s*(?:run|verify|test|check|capture|record|retain|measure|assert)\b", text, re.IGNORECASE):
        return False
    if re.fullmatch(r"\s*portrait[ -]+(?:regression[ -]+)?(?:tests?|evidence|screenshots?|verification)\s*", text, re.IGNORECASE):
        return False
    return True


def has_intentional_hold(status: Any, blocker: dict[str, Any], active_blocker: bool) -> bool:
    """Find an imposed hold, not a policy reminder or a real approval blocker."""
    if active_blocker:
        kind = str(blocker.get("kind") or "").lower().replace("-", "_").replace(" ", "_")
        if kind in {"intentional_hold", "hands_on_hold", "held_user_hands_on", "held_for_user"}:
            return True
    texts = [str(status or "")]
    if active_blocker:
        texts.append(str(blocker.get("description") or ""))
    for text in texts:
        # Keep explicit HELD_USER_HANDS_ON statuses detectable. Only remove
        # negated natural-language policy statements from the free text.
        text = re.sub(r"\b(?:not|no|zero|without)(?:\s+(?:an?|any))?\s+intentional[ _-]+holds?\b", "", text, flags=re.IGNORECASE)
        text = re.sub(r"\b(?:do not|don't|must not|never)\b[^.;\n]{0,100}?intentional[ _-]+holds?\b", "", text, flags=re.IGNORECASE)
        if HOLD.search(text):
            return True
    return False


def markdown_rows(text: str, section: str = "## Named playtest task ledger") -> list[dict[str, str]]:
    """Read the canonical eight-column named ledger, not other plan tables."""
    lines = text.splitlines()
    try:
        start = next(index for index, line in enumerate(lines) if line.strip() == section)
    except StopIteration as exc:
        raise InputError(f"Markdown ledger section is missing: {section}") from exc
    level = len(section) - len(section.lstrip("#"))
    rows = []
    header_seen = False
    expected = ["ID / aliases", "Task", "Parent", "Owner", "Completion",
                "Status / retained scoped result", "Commit(s)", "NEXT / remaining work"]
    for line in lines[start + 1:]:
        heading = re.match(r"^(#{1,6})\s", line)
        if heading and len(heading.group(1)) <= level:
            break
        if not line.strip().startswith("|"):
            continue
        cells = [markdown_text(cell) for cell in re.split(r"(?<!\\)\|", line.strip().strip("|"))]
        if cells == expected:
            header_seen = True
            continue
        if not header_seen or all(re.fullmatch(r"[: -]+", cell) for cell in cells):
            continue
        if len(cells) != 8:
            raise InputError(f"Named Markdown ledger row must have eight cells: {line}")
        match = re.match(r"([A-Za-z][A-Za-z0-9_-]+)", cells[0])
        if not match:
            raise InputError(f"Cannot identify stable ID in Markdown ledger row: {cells[0]!r}")
        rows.append(dict(zip(("id_cell", "name", "parent", "owner", "completion", "status", "commits", "next_action"), cells), id=match.group(1)))
    if not header_seen:
        raise InputError("The named Markdown ledger must contain the documented eight-column table header")
    return rows


def check_ledger(
    ledger: dict[str, Any],
    owners: dict[str, Any] | None = None,
    *,
    now: datetime | None = None,
    max_owner_age_hours: float = 24,
    group: str = "all",
    verify_git: bool = False,
    repo_root: Path | str | None = None,
    markdown: str | None = None,
    markdown_reference: str | None = None,
    runtimes: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Return a deterministic report; never mutate inputs or task state."""
    ledger = validate_ledger(ledger)
    if owners is not None:
        owners = validate_owners(owners)
    if group not in {"current", "historical", "all"}:
        raise InputError("group must be current, historical, or all")
    if not isinstance(max_owner_age_hours, (int, float)) or not math.isfinite(max_owner_age_hours) or not 0 < max_owner_age_hours <= 24 * 36500:
        raise InputError("max-owner-age-hours must be finite and greater than zero (at most 100 years)")
    now = now or datetime.now(timezone.utc)
    if now.tzinfo is None:
        raise InputError("now must include a timezone")
    now = now.astimezone(timezone.utc)
    age_limit = timedelta(hours=max_owner_age_hours)
    findings: list[dict[str, Any]] = []

    def add(code: str, task_id: str | None, message: str, evidence: list[str] | None = None, severity: str = "error") -> None:
        findings.append({"code": code, "severity": severity, "task_id": task_id,
                         "message": message, "evidence": evidence or []})

    def stale(value: str) -> bool:
        return now - timestamp(value, "observation timestamp") > age_limit

    for policy in ("completion_requires_commit", "no_intentional_holds", "no_portrait_app_updates"):
        if ledger["policies"].get(policy) is not True:
            add("REQUIRED_POLICY_MISSING", None, f"Policy {policy} must remain true.")
    all_tasks = {task["id"]: task for task in ledger["objectives"]}
    batches = {batch["id"]: batch for batch in ledger["batches"]}
    selected = [task for task in ledger["objectives"] if group == "all" or task["group"] == group]
    selected_ids = {task["id"] for task in selected}
    selected_batches = [batch for batch in ledger["batches"] if batch["parent_id"] in selected_ids]
    paused_ids = {item["id"] for item in selected + selected_batches if supported_user_pause(item, ledger["policies"])}
    for key, count in Counter([task["id"] for task in ledger["objectives"]] + [batch["id"] for batch in ledger["batches"]]).items():
        if count > 1:
            add("DUPLICATE_ID", key, "A stable ID is used more than once in the ledger.")
    owner_tasks = {task["task_ref"]: task for task in owners["tasks"]} if owners else {}
    if owners is None and any(task["state"] == "open" and task["id"] not in paused_ids for task in selected + selected_batches):
        add("OWNER_SNAPSHOT_NOT_SUPPLIED", None, "Live owner state was not checked; supply a fresh --owners snapshot.", severity="warning")
    elif owners is not None and stale(owners["observed_at"]) and any(task["state"] == "open" and task["id"] not in paused_ids for task in selected + selected_batches):
        add("OWNER_SNAPSHOT_STALE", None, "The owner snapshot is older than the configured freshness limit.", [owners["observed_at"]])

    git_results: dict[str, bool] = {}

    def commits_for(item: dict[str, Any], prefix: str = "") -> list[str]:
        valid = []
        for commit in item.get("commits", []):
            sha = commit["sha"]
            if not SHA.fullmatch(sha):
                add("INVALID_COMMIT_ID", item["id"], "Associated commits must use a full 40-character hexadecimal SHA.", [sha])
                continue
            valid.append(sha.lower())
            verify_commit(sha, item["id"])
        if item["state"] == "complete" and not valid:
            add(prefix + "COMPLETE_WITHOUT_COMMIT", item["id"], "Completed work needs an associated full commit SHA.")
        return valid

    def verify_commit(sha: str, task_id: str) -> None:
        if not verify_git:
            return
        if sha.lower() not in git_results:
            try:
                result = subprocess.run(
                    ["git", "-C", str(repo_root or Path.cwd()), "cat-file", "-e", sha + "^{commit}"],
                    capture_output=True, text=True, check=False, timeout=15,
                )
                git_results[sha.lower()] = result.returncode == 0
            except (OSError, subprocess.TimeoutExpired) as exc:
                raise InputError(f"Cannot run the requested read-only Git verification: {exc}") from exc
        if not git_results[sha.lower()]:
            add("COMMIT_NOT_FOUND", task_id, "The associated commit is absent from the local Git object database; no fetch was attempted.", [sha])

    def deployment_for(item: dict[str, Any]) -> None:
        deployment = item["deployment"]
        if item["state"] == "complete" and deployment["required"] and deployment["state"] != "verified":
            add("COMPLETE_WITHOUT_DEPLOYMENT", item["id"], "Required deployment has not been verified.")
        if deployment["state"] == "verified":
            identity = deployment.get("commit")
            if not isinstance(identity, str) or not SHA.fullmatch(identity):
                add("DEPLOYMENT_IDENTITY_MISSING", item["id"], "Verified deployment needs the full deployed commit identity.")
            else:
                verify_commit(identity, item["id"])
            if not deployment.get("evidence"):
                add("DEPLOYMENT_EVIDENCE_MISSING", item["id"], "Verified deployment needs evidence references for the deployed identity and checks.")

    def workflow_for(item: dict[str, Any]) -> None:
        task_id = item["id"]
        paused = task_id in paused_ids
        pause = item.get("pause")
        if isinstance(pause, dict) and pause.get("state") == "active" and not paused:
            add("UNSUPPORTED_USER_PAUSE", task_id, "Active pause lacks matching user authorization, task scope, instruction or source provenance.")
        if not paused and not (isinstance(pause, dict) and pause.get("state") == "active"):
            if any(policy.get("state") == "active" and policy.get("requested_by") == "user" and task_id in policy.get("task_ids", [])
                   for policy in ledger["policies"].get("user_requested_pauses", [])):
                add("USER_PAUSE_RECORD_MISSING", task_id, "The active user policy names this task, but its matching active pause record is missing.")
        if paused and item["state"] != "open":
            add("USER_PAUSED_TASK_NOT_OPEN", task_id, "An active user-paused item must remain Open; a pause does not complete or supersede the requested work.")
        if item["state"] == "open":
            owner = item.get("owner", {})
            if not nonempty(owner.get("name")):
                add("OWNER_MISSING", task_id, "Open work needs a named owner.")
            task_ref = owner.get("task_ref")
            if not nonempty(task_ref):
                add("OWNER_TASK_REFERENCE_MISSING", task_id, "Open work needs the owner's current task reference.")
            elif owners is not None and not paused:
                observation = owner_tasks.get(task_ref)
                if observation is None:
                    add("OWNER_NOT_IN_SNAPSHOT", task_id, "The current task reference has no observation in the supplied owner snapshot.", [task_ref])
                else:
                    state = observation["state"]
                    if state != "active":
                        code = {"idle": "OWNER_IDLE_WITH_OPEN_WORK", "ended": "OWNER_ENDED_WITH_OPEN_WORK", "not_found": "OWNER_NOT_FOUND"}[state]
                        add(code, task_id, f"Owner task is {state} while requested work remains open.", [task_ref, observation.get("source", "")])
                    if stale(observation["observed_at"]):
                        add("OWNER_OBSERVATION_STALE", task_id, "Owner task observation is older than the configured freshness limit.", [task_ref, observation["observed_at"]])
            action = item.get("next_action")
            if not nonempty(action) or action.strip().lower() in {"tbd", "todo", "none", "pending", "continue", "follow up", "wait", "n/a"}:
                add("NEXT_ACTION_MISSING", task_id, "Open work needs a concrete next action.")
        blocker = item.get("blocker", {})
        active_blocker = blocker.get("state") in {"active", "unknown"} and item["state"] != "superseded"
        if active_blocker:
            if not nonempty(blocker.get("description")):
                add("BLOCKER_DESCRIPTION_MISSING", task_id, "A reported blocker needs a concrete description.")
            if not paused and (not blocker.get("observed_at") or stale(blocker["observed_at"])):
                add("BLOCKER_STALE", task_id, "Revalidate this blocker; its observation is missing or stale.", [blocker.get("observed_at") or "no observation timestamp"])
            if not blocker.get("evidence"):
                add("BLOCKER_EVIDENCE_MISSING", task_id, "A reported blocker needs supporting evidence.")
            if ledger["policies"].get("original_user_incident_saves") == "unavailable" and original_save_demand(blocker):
                add("STALE_USER_SAVE_BLOCKER", task_id, "Original user incident saves are unavailable. Use retained fixtures or reconstructed independent checks; do not wait on the user for those saves.")
        if not paused and item["state"] != "superseded" and has_intentional_hold(item.get("status"), blocker, active_blocker):
            add("INTENTIONAL_HOLD_FORBIDDEN", task_id, "An imposed hold lacks matching explicit user-pause authorization; reconcile the recorded instruction.")
        # Only this dedicated field describes planned app changes. A portrait
        # screenshot, regression test, or historical note elsewhere is evidence.
        for change in item.get("planned_app_changes", []):
            if is_portrait_app_change(change):
                add("PORTRAIT_APP_CHANGE_FORBIDDEN", task_id, "A planned portrait-mode app update conflicts with the user's scope.", [json.dumps(change, ensure_ascii=False)])

    for task in selected:
        task_id = task["id"]
        complete = task["state"] == "complete"
        objective = task.get("objective", {})
        acceptance = objective.get("acceptance", [])
        coverage = objective.get("coverage", {})
        required_criteria = [entry for entry in acceptance if entry["required"]]
        incomplete_criteria = [entry for entry in required_criteria if entry["state"] != "pass" or not entry.get("evidence")]
        remaining_areas = [entry for entry in coverage.get("areas", []) if entry["state"] != "reviewed" or not entry.get("evidence")]
        coverage_gap = coverage.get("required") is True and (
            coverage.get("complete") is not True or not coverage.get("areas") or bool(remaining_areas)
        )
        if task["state"] != "superseded":
            if not nonempty(objective.get("text")) or not nonempty(objective.get("source")):
                add("OBJECTIVE_SOURCE_MISSING", task_id, "Preserve the full requested objective and its source separately from implementation batches.")
            if objective.get("scope_confirmed") is not True:
                add("OBJECTIVE_SCOPE_UNCONFIRMED", task_id, "Full parent scope is not confirmed; keep it open and reconcile the source request.")
            if not required_criteria:
                add("ACCEPTANCE_UNDEFINED", task_id, "At least one required acceptance criterion must describe the requested outcome.")
        workflow_for(task)
        for parent_id in task.get("parent_ids", []):
            if parent_id not in all_tasks:
                add("PARENT_NOT_FOUND", task_id, "A parent reference does not resolve to an objective.", [parent_id])
        for batch_id in task.get("implementation_batches", []):
            batch = batches.get(batch_id)
            if batch is None:
                add("BATCH_NOT_FOUND", task_id, "An implementation batch reference does not resolve.", [batch_id])
            elif batch["parent_id"] != task_id:
                add("BATCH_PARENT_MISMATCH", task_id, "A referenced implementation batch belongs to another parent.", [batch_id, batch["parent_id"]])
        commits_for(task)
        deployment_for(task)
        if complete:
            if any(entry["state"] != "pass" for entry in required_criteria):
                add("COMPLETE_WITH_OPEN_ACCEPTANCE", task_id, "Required acceptance criteria remain open, unknown, or unavailable.", [str(entry.get("id", "unnamed")) for entry in required_criteria if entry["state"] != "pass"])
            if any(entry["state"] == "pass" and not entry.get("evidence") for entry in required_criteria):
                add("COMPLETE_WITHOUT_ACCEPTANCE_EVIDENCE", task_id, "Passing required acceptance needs supporting evidence.")
            if coverage_gap:
                add("COVERAGE_INCOMPLETE", task_id, "Full parent coverage is incomplete or lacks review evidence.", [str(entry.get("id", "unnamed")) for entry in remaining_areas])
            child_gaps = [entry["id"] for entry in ledger["objectives"] if task_id in entry.get("parent_ids", []) and entry["state"] == "open"]
            if child_gaps:
                add("COMPLETE_WITH_OPEN_CHILDREN", task_id, "Required child work is still open.", child_gaps)
            linked_batches = [entry for entry in ledger["batches"] if entry["parent_id"] == task_id]
            done_batches = [entry for entry in linked_batches if entry["state"] == "complete"]
            batch_gaps = [entry["id"] for entry in linked_batches if entry["state"] != "complete"]
            if batch_gaps:
                add("COMPLETE_WITH_OPEN_BATCHES", task_id, "An implementation batch is still open.", batch_gaps)
            if done_batches and (incomplete_criteria or coverage_gap or not required_criteria or objective.get("scope_confirmed") is not True or child_gaps or batch_gaps):
                add("PARENT_BATCH_ONLY_COMPLETION", task_id, "A finished implementation batch is not evidence that the full requested parent objective is complete.", [entry["id"] for entry in done_batches])

    for batch in ledger["batches"]:
        if batch["parent_id"] not in all_tasks:
            add("BATCH_PARENT_NOT_FOUND", batch["id"], "An implementation batch has no parent objective.", [batch["parent_id"]])
        if batch["parent_id"] in selected_ids:
            commits_for(batch, "BATCH_")
            deployment_for(batch)
            workflow_for(batch)
            if batch["id"] not in all_tasks[batch["parent_id"]].get("implementation_batches", []):
                add("BATCH_NOT_LINKED_BY_PARENT", batch["id"], "The parent does not list this implementation batch.", [batch["parent_id"]])

    markdown_row_count = None
    if markdown is not None:
        section = ledger.get("metadata", {}).get("markdown_ledger_section", "## Named playtest task ledger")
        rows = markdown_rows(markdown, section)
        markdown_row_count = len(rows)
        canonical = {row["id"]: row for row in rows}
        source = markdown_reference or "canonical Markdown named task ledger"
        combined = {**all_tasks, **batches}
        selected_union = selected_ids | {batch["id"] for batch in selected_batches}
        for task_id, count in Counter(row["id"] for row in rows).items():
            if count > 1:
                add("MARKDOWN_DUPLICATE_ID", task_id, "The readable named ledger repeats a stable ID.", [source])
        for task_id in canonical.keys() - combined.keys():
            add("MARKDOWN_ID_MISSING_FROM_JSON", task_id, "The readable ledger contains a task missing from the structured ledger.", [source])
        for task_id in selected_union - canonical.keys():
            add("JSON_ID_MISSING_FROM_MARKDOWN", task_id, "A structured task or batch is missing from the readable named ledger.", [source])
        for task_id in sorted(selected_union & canonical.keys()):
            item, row = combined[task_id], canonical[task_id]
            expected_state = {"open": "Open", "complete": "Complete", "superseded": "Superseded"}[item["state"]]
            if row["completion"].casefold() != expected_state.casefold():
                add("MARKDOWN_COMPLETION_DRIFT", task_id, "Readable and structured completion states differ.", [f"Markdown: {row['completion']}; JSON: {item['state']}", source])
            if row["status"] != markdown_text(str(item.get("status") or "")):
                add("MARKDOWN_STATUS_DRIFT", task_id, "Readable and structured exact status text differ.", [f"Markdown: {row['status']}", f"JSON: {item.get('status')}", source])
            if row["owner"] != markdown_text(str(item.get("owner", {}).get("name") or "")):
                add("MARKDOWN_OWNER_DRIFT", task_id, "Readable and structured owner names differ.", [f"Markdown: {row['owner']}; JSON: {item.get('owner', {}).get('name')}", source])
            parent_ids = set(item.get("parent_ids", [])) if task_id in all_tasks else {item["parent_id"]}
            listed_parents = {part.strip() for part in row["parent"].split(",") if part.strip() not in {"", "-", "None"}}
            if listed_parents != parent_ids:
                add("MARKDOWN_PARENT_DRIFT", task_id, "Readable and structured parent references differ.", [f"Markdown: {row['parent']}; JSON: {', '.join(sorted(parent_ids)) or '-'}", source])
            listed_commits = re.findall(r"(?<![0-9a-zA-Z])([0-9a-fA-F]{7,40})(?![0-9a-zA-Z])", row["commits"])
            associated = [entry["sha"].lower() for entry in item.get("commits", []) if SHA.fullmatch(entry["sha"])]
            for reference in listed_commits:
                if not any(sha.startswith(reference.lower()) for sha in associated):
                    add("MARKDOWN_COMMIT_MISSING_FROM_JSON", task_id, "A listed readable-ledger commit has no associated full SHA in the structured ledger.", [reference, source])
            for sha in associated:
                if not any(sha.startswith(reference.lower()) for reference in listed_commits):
                    add("JSON_COMMIT_MISSING_FROM_MARKDOWN", task_id, "An associated structured-ledger commit is absent from the readable ledger's commit cell.", [sha, source])
            if row["completion"].casefold() == "complete" and not listed_commits:
                add("MARKDOWN_COMPLETE_WITHOUT_COMMIT", task_id, "A completed readable-ledger item needs an associated commit in its commit cell.", [row["commits"], source])

    runtime_report = None
    if runtimes is not None:
        from check_bth_runtime_inventory import check_inventory, InputError as RuntimeInputError
        try:
            runtime_report = check_inventory(runtimes, owners=owners, now=now,
                                             max_age_hours=max_owner_age_hours)
        except RuntimeInputError as exc:
            raise InputError(str(exc)) from exc
        findings.extend(runtime_report["findings"])
    elif ledger["policies"].get("runtime_cleanup_required") is True:
        add("RUNTIME_INVENTORY_NOT_SUPPLIED", None,
            "Required runtime cleanup was not reconciled; supply --runtimes with explicit task-owned lifecycle evidence.")

    findings.sort(key=lambda entry: (0 if entry["severity"] == "error" else 1, entry["task_id"] or "", entry["code"]))
    counts = Counter(entry["severity"] for entry in findings)

    def open_work_entry(item: dict[str, Any], parent: dict[str, Any] | None = None) -> dict[str, Any]:
        # Batch progress is explicitly the parent objective's progress. Its
        # bounded scope and associated commits remain the batch's own fields.
        objective_item = parent or item
        objective = objective_item.get("objective", {})
        criteria = objective.get("acceptance", [])
        required = [criterion for criterion in criteria if criterion["required"]]
        coverage = objective.get("coverage", {})
        areas = coverage.get("areas", [])
        owner = item.get("owner", {})
        task_ref = owner.get("task_ref")
        observation = owner_tasks.get(task_ref) if nonempty(task_ref) else None
        if observation is not None:
            observed_state = observation["state"]
        elif not nonempty(task_ref):
            observed_state = "task_reference_missing"
        elif owners is None:
            observed_state = "snapshot_not_supplied"
        else:
            observed_state = "not_in_snapshot"
        return {
            "id": item["id"], "name": item.get("name"), "state": item["state"],
            "item_type": "implementation_batch" if parent else "objective",
            "kind": item.get("kind", "implementation_batch"),
            "parent_ids": [parent["id"]] if parent else copy.deepcopy(item.get("parent_ids", [])),
            "full_objective": {"text": objective.get("text"), "source": objective.get("source"),
                               "scope_confirmed": objective.get("scope_confirmed")},
            "batch_scope": copy.deepcopy(item.get("scope", [])) if parent else [],
            "owner": {"name": owner.get("name"), "task_ref": task_ref,
                      "observed_state": observed_state,
                      "observed_at": observation.get("observed_at") if observation else None,
                      "source": observation.get("source") if observation else None,
                      "observation_stale": stale(observation["observed_at"]) if observation else None},
            "status": item.get("status"),
            "pause": copy.deepcopy(item.get("pause")),
            "pause_supported": item["id"] in paused_ids,
            "commits": copy.deepcopy(item.get("commits", [])),
            "deployment": copy.deepcopy(item["deployment"]),
            "progress_scope_id": objective_item["id"],
            "acceptance": copy.deepcopy(criteria),
            "acceptance_progress": {
                "required_total": len(required),
                "passed_with_evidence": sum(criterion["state"] == "pass" and bool(criterion.get("evidence")) for criterion in required),
                "remaining_ids": [criterion.get("id") for criterion in required if criterion["state"] != "pass" or not criterion.get("evidence")],
            },
            "coverage": copy.deepcopy(coverage),
            "coverage_progress": {
                "required": coverage.get("required"), "declared_complete": coverage.get("complete"),
                "total_areas": len(areas),
                "reviewed_with_evidence": sum(area["state"] == "reviewed" and bool(area.get("evidence")) for area in areas),
                "remaining_ids": [area.get("id") for area in areas if area["state"] != "reviewed" or not area.get("evidence")],
            },
            "next_action": item.get("next_action"),
            "blocker": copy.deepcopy(item.get("blocker", {"state": "none"})),
            "completed_batch_ids": [batch["id"] for batch in ledger["batches"] if batch["parent_id"] == objective_item["id"] and batch["state"] == "complete"],
        }

    open_work = [open_work_entry(task) for task in selected if task["state"] == "open"]
    open_work.extend(open_work_entry(batch, all_tasks[batch["parent_id"]]) for batch in selected_batches if batch["state"] == "open")
    return {
        "schema": REPORT_SCHEMA,
        "checked_at": iso(now),
        "ledger_updated_at": ledger["updated_at"],
        "group": group,
        "owner_snapshot_supplied": owners is not None,
        "runtime_inventory_supplied": runtimes is not None,
        "runtime_summary": runtime_report["summary"] if runtime_report else None,
        "runtime_instances": runtime_report["instances"] if runtime_report else None,
        "runtime_limitations": runtime_report["limitations"] if runtime_report else None,
        "git_verification_requested": verify_git,
        "markdown_checked": markdown is not None,
        "markdown_rows_checked": markdown_row_count,
        "freshness_limit_hours": max_owner_age_hours,
        "user_requested_pauses": copy.deepcopy(ledger["policies"].get("user_requested_pauses", [])),
        "summary": {"objectives_checked": len(selected), "batches_checked": len(selected_batches),
                    "open_objectives": sum(task["state"] == "open" for task in selected),
                    "open_batches": sum(batch["state"] == "open" for batch in selected_batches),
                    "open_work_items": len(open_work),
                    "user_paused_items": len(paused_ids),
                    "complete_objectives": sum(task["state"] == "complete" for task in selected),
                    "errors": counts["error"], "warnings": counts["warning"],
                    "tasks_with_errors": len({entry["task_id"] for entry in findings if entry["severity"] == "error" and entry["task_id"] is not None})},
        "findings": findings,
        "open_work": open_work,
        "limitations": [
            "This manual report does not launch work, change task state, or contact owners.",
            "Evidence references are recorded assertions; inspect the referenced acceptance and deployment evidence.",
            "Git verification, when requested, establishes local commit existence only.",
            "Record app changes and verification as separate entries; test/evidence entries are not portrait-mode app updates.",
        ],
    }


def render_text(report: dict[str, Any]) -> str:
    summary = report["summary"]
    lines = [f"BTH ledger reconciliation at {report['checked_at']} ({report['group']})",
             f"Checked {summary['objectives_checked']} objectives and {summary['batches_checked']} batches: "
             f"{summary['errors']} error(s), {summary['warnings']} warning(s)."]
    if report.get("runtime_inventory_supplied"):
        runtime_summary = report["runtime_summary"]
        lines.append(f"Runtime evidence: {runtime_summary['instances_checked']} explicitly recorded instance(s), "
                     f"{runtime_summary['candidate_orphans']} orphan review candidate(s). No cleanup is authorized.")
    for entry in report["findings"]:
        lines.append(f"[{entry['severity'].upper()}] {entry['code']} {entry['task_id'] or '(ledger)'}: {entry['message']}")
        lines.extend(f"  Evidence: {reference}" for reference in entry["evidence"])
    lines.append(f"Open work: {summary['open_objectives']} objective(s), {summary['open_batches']} implementation batch(es); {summary['user_paused_items']} supported user pause(s).")
    for entry in report["open_work"]:
        owner = entry["owner"]
        acceptance, coverage = entry["acceptance_progress"], entry["coverage_progress"]
        label = "PAUSED BY USER / OPEN" if entry["pause_supported"] else "OPEN"
        lines.append(f"[{label}] {entry['id']} {entry.get('name') or ''} | owner: {owner.get('name') or '(missing)'} "
                     f"({owner['observed_state']}; task: {owner.get('task_ref') or '(missing)'}) | {entry.get('status') or '(no status)'}")
        lines.append(f"  Next: {entry.get('next_action') or '(missing)'}")
        if entry["pause_supported"]:
            lines.append(f"  User pause: {entry['pause']['instruction']} | source: {entry['pause']['source']}")
        progress_scope = f"parent {entry['progress_scope_id']}; " if entry["item_type"] == "implementation_batch" else ""
        lines.append(f"  Progress: {progress_scope}acceptance {acceptance['passed_with_evidence']}/{acceptance['required_total']}; "
                     f"coverage {coverage['reviewed_with_evidence']}/{coverage['total_areas']} areas with evidence; "
                     f"completed batches: {', '.join(entry['completed_batch_ids']) or 'none'}.")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    repo_root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--ledger", type=Path, default=repo_root / "docs/todo/bth_task_ledger.json")
    parser.add_argument("--owners", type=Path, help="Fresh manually captured bth.owner_snapshot/v1 JSON")
    parser.add_argument("--runtimes", type=Path, help="Explicit bth.runtime_inventory/v1 lifecycle snapshot; no live process inspection or cleanup")
    parser.add_argument("--markdown", type=Path, default=repo_root / "docs/plans/0.6.1_stability_release_plan.md",
                        help="Canonical readable named ledger used to detect JSON/Markdown drift")
    parser.add_argument("--no-markdown", action="store_true", help="Explicitly check only JSON, without readable-ledger drift checking")
    parser.add_argument("--group", choices=("current", "historical", "all"), default="all")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    parser.add_argument("--output", type=Path, help="Write the report to this file instead of stdout")
    parser.add_argument("--now", help="Timezone-qualified ISO timestamp for a deterministic check")
    parser.add_argument("--max-owner-age-hours", type=float, default=24)
    parser.add_argument("--verify-git", action="store_true", help="Check full commit IDs in the local Git object database (no fetch)")
    args = parser.parse_args(argv)
    try:
        if args.output:
            output_path = args.output.resolve()
            inputs = [("ledger", args.ledger), ("Markdown ledger", args.markdown)]
            if args.owners:
                inputs.append(("owner snapshot", args.owners))
            if args.runtimes:
                inputs.append(("runtime inventory", args.runtimes))
            for label, input_path in inputs:
                resolved_input = input_path.resolve()
                # resolve() catches symlink aliases and native path equality
                # handles Windows case. samefile() also catches existing hardlinks.
                same_file = output_path == resolved_input
                if not same_file and args.output.exists() and input_path.exists():
                    same_file = args.output.samefile(input_path)
                if same_file:
                    raise InputError(f"--output must not overwrite the {label} input: {input_path}")
        ledger = json.loads(args.ledger.read_text(encoding="utf-8-sig"))
        owners = json.loads(args.owners.read_text(encoding="utf-8-sig")) if args.owners else None
        runtimes = json.loads(args.runtimes.read_text(encoding="utf-8-sig")) if args.runtimes else None
        markdown = None if args.no_markdown else args.markdown.read_text(encoding="utf-8-sig")
        report = check_ledger(ledger, owners, now=timestamp(args.now, "--now") if args.now else None,
                              max_owner_age_hours=args.max_owner_age_hours, group=args.group,
                              verify_git=args.verify_git, repo_root=repo_root, markdown=markdown,
                              markdown_reference=str(args.markdown) if markdown is not None else None,
                              runtimes=runtimes)
        output = json.dumps(report, indent=2, ensure_ascii=False) + "\n" if args.format == "json" else render_text(report)
        if args.output:
            args.output.write_text(output, encoding="utf-8")
        else:
            sys.stdout.write(output)
        return 1 if report["summary"]["errors"] else 0
    except (InputError, OSError, UnicodeError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"Input error: {exc}\n")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
