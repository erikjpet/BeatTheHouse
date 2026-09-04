import json
import re
from pathlib import Path


ROOT = Path("data/environments/scenario_sequences")
ITEMS = ["lucky_bar_napkin", "instant_coffee", "ledger_pencil", "cashout_envelope", "cheap_sunglasses"]
CUES = ["shop_bell", "crate_latch", "appraisal_stamp", "record_stamp", "dice_curb"]
NEGATIVE = ("ignore", "refuse", "leave", "sabotage", "fail", "close wrong", "abandon")


def words(value):
    return re.sub(r"\s+", " ", str(value or "").replace("_", " ")).strip()


def message(action, phase):
    label = words(action.get("label", action.get("id")))
    context = words(phase.get("arrival_feedback", "The room changes in plain view")).rstrip(".")
    return f"You {label[0].lower() + label[1:]}. {context}."


def main():
    reward_slot = 0
    cash_slot = 0
    for package_index, path in enumerate(sorted(ROOT.glob("*.json"))):
        package = json.loads(path.read_text(encoding="utf-8"))
        for scenario in package["scenarios"]:
            changed_this_scenario = False
            def has_scene_change(value):
                if isinstance(value, dict):
                    if value.get("handler") == "change_scene_object":
                        return True
                    return any(has_scene_change(nested) for nested in value.values())
                if isinstance(value, list):
                    return any(has_scene_change(nested) for nested in value)
                return False
            changed_this_scenario = has_scene_change(scenario["sequence"])
            scene_ids = {
                str(value).split("::", 1)[-1]
                for value in scenario["sequence"].get("declared_targets", {}).get("scene_objects", [])
            }
            def collect_scene_ids(value):
                if isinstance(value, dict):
                    if value.get("family") == "scene_ops" and value.get("object"):
                        scene_ids.add(value.get("stable_object_id", ""))
                    for nested in value.values():
                        collect_scene_ids(nested)
                elif isinstance(value, list):
                    for nested in value:
                        collect_scene_ids(nested)
            collect_scene_ids(scenario["sequence"])
            for phase in scenario["sequence"]["phase_graph"]["phases"]:
                for op in phase.get("interaction_ops", []):
                    actions = op.get("interaction", {}).get("available_actions", op.get("available_actions", []))
                    for action in actions:
                        if action.get("handler"):
                            continue
                        line = message(action, phase)
                        positive = not any(token in words(action.get("label")).lower() for token in NEGATIVE)
                        target = op.get("stable_object_id", "")
                        if positive and reward_slot == package_index:
                            action["handler"] = "grant_item"
                            action["inputs"] = {"item_id": ITEMS[package_index], "message": line}
                            reward_slot += 1
                        elif positive and cash_slot == package_index:
                            action["handler"] = "grant_cash"
                            action["inputs"] = {"amount": 3 + package_index, "message": line}
                            cash_slot += 1
                        elif positive and not changed_this_scenario and target in scene_ids:
                            action["handler"] = "change_scene_object"
                            action["inputs"] = {"owner_namespace": "scenario", "stable_object_id": target, "state": f"changed_by_{action['id']}", "message": line}
                            changed_this_scenario = True
                        elif positive and sum(ord(char) for char in action["id"]) % 5 == 0:
                            action["handler"] = "play_cue"
                            action["inputs"] = {"cue_id": CUES[package_index], "message": line}
                        else:
                            action["handler"] = "publish_feedback"
                            action["inputs"] = {"message": line}
            if not changed_this_scenario:
                changed_target = ""
                changed_state = ""
                changed_message = ""
                for phase in scenario["sequence"]["phase_graph"]["phases"]:
                    for op in phase.get("interaction_ops", []):
                        target = op.get("stable_object_id", "")
                        if target not in scene_ids:
                            continue
                        for action in op.get("interaction", {}).get("available_actions", op.get("available_actions", [])):
                            if action.get("handler") != "publish_feedback" or not str(action.get("inputs", {}).get("message", "")).startswith("You "):
                                continue
                            if any(token in words(action.get("label")).lower() for token in NEGATIVE):
                                continue
                            changed_target = target
                            changed_state = f"changed_by_{action['id']}"
                            changed_message = action["inputs"]["message"]
                            action["handler"] = "change_scene_object"
                            action["inputs"] = {"owner_namespace": "scenario", "stable_object_id": target, "state": changed_state, "message": changed_message}
                            changed_this_scenario = True
                            break
                        if changed_this_scenario:
                            break
                    if changed_this_scenario:
                        break
                if changed_this_scenario:
                    def add_variant(value):
                        if isinstance(value, dict):
                            payload = value.get("object") or value.get("actor")
                            if value.get("stable_object_id") == changed_target and payload:
                                payload.setdefault("description_variants", {})[changed_state] = changed_message
                            for nested in value.values():
                                add_variant(nested)
                        elif isinstance(value, list):
                            for nested in value:
                                add_variant(nested)
                    add_variant(scenario["sequence"])
        path.write_text(json.dumps(package, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"ENV06_8_CONSEQUENCES package={path.name}")


if __name__ == "__main__":
    main()
