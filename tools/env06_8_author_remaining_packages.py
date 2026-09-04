"""Editorial migration for the four remaining env06_7 packages.

The source packages already carry scenario-specific object names, states,
appearances, player verbs, and arrival summaries. This pass preserves those
facts, turns them into object-local room-reading copy, and refuses to invent
mechanical effects that are not in the authored operation graph.
"""

import hashlib
import json
import re
from pathlib import Path


ROOT = Path("data/environments/scenario_sequences")
PACKAGES = [
    "env06_7_roadside_shelter.json",
    "env06_7_bars_road.json",
    "env06_7_underground_lounge.json",
    "env06_7_queen_public.json",
]
GENERIC = (
    "the room advances to a new physical station",
    "beat moves props and actors",
    "station opens around",
    "shared aftermath fixes a distinct",
)
MATERIAL_OPS = {"move", "set_position", "set_state", "set_appearance", "set_pose", "set_behavior", "reveal", "hide", "enable", "disable"}


def words(value):
    return re.sub(r"\s+", " ", str(value or "").replace("_", " ")).strip()


def sentence(value):
    value = words(value)
    if not value:
        return ""
    return value[0].upper() + value[1:].rstrip(". ") + "."


def digest_choice(key, choices):
    return choices[int(hashlib.sha256(key.encode()).hexdigest()[:8], 16) % len(choices)]


def phase_objects(phase):
    rows = []
    for family, payload_key in (("scene_ops", "object"), ("actor_ops", "actor")):
        for op in phase.get(family, []):
            payload = op.get(payload_key, {})
            if payload:
                rows.append((op, payload, family))
    return rows


def operation_value(op):
    for key in ("state", "appearance", "pose", "behavior", "anchor_id", "zone_id"):
        if op.get(key):
            return words(op[key])
    return {"reveal": "visible again", "hide": "out of sight", "enable": "ready for use", "disable": "closed off"}.get(op.get("op"), words(op.get("op")))


def clean_context(value, fallback):
    line = sentence(value)
    if not line or any(marker in line.lower() for marker in GENERIC):
        return sentence(fallback)
    return line


def object_description(scenario_id, label, payload, context, family):
    label_text = words(label)
    state = words(payload.get("state") or payload.get("pose") or payload.get("behavior") or "present")
    appearance = words(payload.get("appearance"))
    role = words(payload.get("role") or ("person" if family == "actor_ops" else "room detail"))
    context_body = context.rstrip(".")
    key = f"{scenario_id}:{label_text}:{state}:{appearance}"
    if family == "actor_ops":
        patterns = [
            f"{label_text} is {state}, their attention making the room's latest work easy to read. {context_body}.",
            f"{label_text} holds a {state} posture beside the active scene. {context_body}.",
            f"{context_body}. {label_text} remains {state}, showing who is still involved.",
        ]
    elif role in ("exit", "route") or "exit" in label_text.lower() or "lane" in label_text.lower():
        patterns = [
            f"{label_text} stays visibly {state}; it is the readable way out while the scene continues.",
            f"The {label_text.lower()} is marked {state}, keeping departure legible beside the room's activity.",
        ]
    elif role in ("evidence", "trace", "record") or any(token in label_text.lower() for token in ("evidence", "record", "mark", "ledger", "ticket", "note")):
        patterns = [
            f"{label_text} remains {state}{' with ' + appearance if appearance else ''}, preserving a visible trace of what happened here. {context_body}.",
            f"{context_body}. The {label_text.lower()} is {state}{' and shows ' + appearance if appearance else ''}, so the room cannot quietly erase the work.",
        ]
    else:
        patterns = [
            f"{label_text} is {state}{' in ' + appearance if appearance else ''}. {context_body}.",
            f"{context_body}. The {label_text.lower()} now reads as {state}{' through ' + appearance if appearance else ''}.",
            f"The {label_text.lower()} carries the room's {state} state{', marked by ' + appearance if appearance else ''}. {context_body}.",
        ]
    return digest_choice(key, patterns)


def variant_description(label, value, context, key):
    label_text = words(label)
    value_text = words(value)
    context_body = context.rstrip(".")
    return digest_choice(key, [
        f"{label_text} is now {value_text}; {context_body[0].lower() + context_body[1:] if context_body else 'the change is visible in the room'}.",
        f"The {label_text.lower()} has shifted to {value_text}. {context_body}.",
        f"{context_body}. The {label_text.lower()} visibly holds at {value_text}.",
    ])


def deliberate_zone(payload, family, ordinal, stable_id, allowed):
    role = words(payload.get("role")).lower()
    label = words(payload.get("label")).lower()
    if role == "exit" or "exit" in label or "gangway" in label or "door lane" in label:
        return "exit_lane" if "exit_lane" in allowed else allowed[ordinal % len(allowed)]
    if role in ("service", "counter", "workstation") or any(token in label for token in ("counter", "bar station", "service station")):
        return "service_lane" if "service_lane" in allowed else allowed[ordinal % len(allowed)]
    if family == "actor_ops":
        choices = [zone for zone in ("background", "left", "right") if zone in allowed] or allowed
        return choices[ordinal % len(choices)]
    if any(token in role + " " + label for token in ("hazard", "obstacle", "warning", "evidence", "trace")):
        choices = [zone for zone in ("foreground", "right") if zone in allowed] or allowed
        return choices[ordinal % len(choices)]
    choices = [zone for zone in ("background", "left", "right", "foreground", "center") if zone in allowed] or allowed
    return choices[ordinal % len(choices)]


def phase_fallback(phase):
    actions = []
    for op in phase.get("interaction_ops", []):
        for action in op.get("interaction", {}).get("available_actions", op.get("available_actions", [])):
            actions.append(words(action.get("label")))
    changes = []
    for family in ("scene_ops", "actor_ops"):
        for op in phase.get(family, []):
            if op.get("op") in MATERIAL_OPS:
                changes.append(f"{words(op.get('stable_object_id'))} {operation_value(op)}")
    if actions:
        return f"The visible setup now supports {actions[0].lower()}"
    if changes:
        return f"The scene now shows {changes[0]}"
    return f"The {words(phase.get('label', 'scene')).lower()} arrangement is visible"


def rewrite_phase_prose(phase):
    fallback = phase_fallback(phase)
    phase["arrival_feedback"] = clean_context(phase.get("arrival_feedback"), fallback)
    for transition in phase.get("transition_ops", []):
        transition["message"] = clean_context(transition.get("message"), fallback)
        if transition.get("op") == "stage" and transition.get("reduced_motion_message"):
            transition["reduced_motion_message"] = clean_context(transition.get("reduced_motion_message"), fallback)


def author_scenario(scenario):
    sequence = scenario["sequence"]
    allowed_zones = [str(zone).rsplit(":", 1)[-1] for zone in sequence.get("declared_targets", {}).get("zones", [])]
    if not allowed_zones:
        raise SystemExit(f"{scenario['scenario_id']} has no declared zones")
    phases = sequence["phase_graph"]["phases"]
    initial_context = clean_context(phases[0].get("arrival_feedback"), phase_fallback(phases[0]))
    contexts = {}
    labels = {}
    variants = {}
    for phase in phases:
        rewrite_phase_prose(phase)
        context = phase["arrival_feedback"]
        for family in ("scene_ops", "actor_ops"):
            for op in phase.get(family, []):
                stable_id = op.get("stable_object_id")
                payload = op.get("object") or op.get("actor")
                if payload:
                    contexts.setdefault(stable_id, context)
                    labels.setdefault(stable_id, payload.get("label", words(stable_id).title()))
                if op.get("op") in MATERIAL_OPS:
                    value = operation_value(op)
                    if value:
                        variants.setdefault(stable_id, {})[str(op.get("state") or op.get("appearance") or op.get("pose") or op.get("behavior") or op.get("anchor_id") or op.get("zone_id") or op.get("op"))] = variant_description(labels.get(stable_id, words(stable_id).title()), value, context, f"{scenario['scenario_id']}:{stable_id}:{value}")
    ordinal = 0
    def visit(value, context):
        nonlocal ordinal
        if isinstance(value, dict):
            family = value.get("family")
            payload = value.get("object") or value.get("actor")
            if family in ("scene_ops", "actor_ops") and payload:
                stable_id = value["stable_object_id"]
                label = payload.get("label", words(stable_id).title())
                local_context = contexts.get(stable_id, context or initial_context)
                payload["description"] = object_description(scenario["scenario_id"], label, payload, local_context, family)
                payload["description_variants"] = variants.get(stable_id, {})
                payload["zone_id"] = deliberate_zone(payload, family, ordinal, stable_id, allowed_zones)
                ordinal += 1
            for nested in value.values():
                visit(nested, context)
        elif isinstance(value, list):
            for nested in value:
                visit(nested, context)
    visit(sequence, initial_context)
    for aftermath in sequence.get("aftermath", {}).values():
        aftermath["revisit_feedback"] = clean_context(aftermath.get("revisit_feedback"), "The room preserves the visible result of the night's choice")


def main():
    for name in PACKAGES:
        path = ROOT / name
        package = json.loads(path.read_text(encoding="utf-8"))
        for scenario in package["scenarios"]:
            author_scenario(scenario)
        path.write_text(json.dumps(package, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"ENV06_8_AUTHORED package={name} scenarios={len(package['scenarios'])}")


if __name__ == "__main__":
    main()
