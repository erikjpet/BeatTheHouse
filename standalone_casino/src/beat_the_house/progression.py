from __future__ import annotations

from pathlib import Path
import json
import random

from beat_the_house.models import MetaProgression, RunState, Upgrade

META_PATH = Path("standalone_casino/save_meta.json")


UPGRADE_POOL = {
    "lucky_coin": Upgrade(
        "lucky_coin", "Slots bias toward sevens.", 70, True, lambda state: None
    ),
    "loaded_dice": Upgrade(
        "loaded_dice", "One die is rigged to 6 each roll.", 60, True, lambda state: None
    ),
    "ace_up_sleeve": Upgrade(
        "ace_up_sleeve", "Slight blackjack edge.", 80, False, lambda state: None
    ),
    "insider_tips": Upgrade(
        "insider_tips", "Pull tabs gain extra value but raise heat.", 55, False, lambda state: None
    ),
    "magnet_watch": Upgrade(
        "magnet_watch", "Negate some roulette losses.", 95, False, lambda state: None
    ),
}


class MetaStore:
    def load(self) -> MetaProgression:
        if not META_PATH.exists():
            return MetaProgression()
        raw = json.loads(META_PATH.read_text())
        return MetaProgression(
            total_runs=raw.get("total_runs", 0),
            unlocked_tiers=raw.get("unlocked_tiers", 1),
            max_floor_reached=raw.get("max_floor_reached", 1),
            prestige_tokens=raw.get("prestige_tokens", 0),
            unlocked_upgrades=set(raw.get("unlocked_upgrades", [])),
        )

    def save(self, meta: MetaProgression) -> None:
        META_PATH.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "total_runs": meta.total_runs,
            "unlocked_tiers": meta.unlocked_tiers,
            "max_floor_reached": meta.max_floor_reached,
            "prestige_tokens": meta.prestige_tokens,
            "unlocked_upgrades": sorted(meta.unlocked_upgrades),
        }
        META_PATH.write_text(json.dumps(payload, indent=2))


def offer_shop(state: RunState, meta: MetaProgression) -> list[Upgrade]:
    candidates = [UPGRADE_POOL[name] for name in meta.unlocked_upgrades]
    state.rng.shuffle(candidates)
    return candidates[: min(3, len(candidates))]


def buy_upgrade(state: RunState, upgrade: Upgrade) -> bool:
    if state.bankroll < upgrade.cost:
        return False
    state.update_bankroll(-upgrade.cost)
    if upgrade.permanent:
        state.permanent_upgrades.add(upgrade.name)
    else:
        state.temporary_upgrades.add(upgrade.name)
    upgrade.apply_effect(state)
    return True


def evaluate_meta_unlocks(meta: MetaProgression, completed_floor: int, final_bankroll: int) -> None:
    meta.total_runs += 1
    meta.max_floor_reached = max(meta.max_floor_reached, completed_floor)
    meta.unlocked_tiers = max(meta.unlocked_tiers, min(5, completed_floor))
    meta.prestige_tokens += max(0, completed_floor - 1)

    if final_bankroll >= 120:
        meta.unlocked_upgrades.add("ace_up_sleeve")
    if completed_floor >= 2:
        meta.unlocked_upgrades.add("insider_tips")
    if completed_floor >= 3:
        meta.unlocked_upgrades.add("magnet_watch")


def create_run(meta: MetaProgression, seed: int | None = None) -> RunState:
    if seed is None:
        seed = random.randint(1, 10_000_000)
    return RunState(seed=seed)
