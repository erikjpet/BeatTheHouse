from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable
import random


@dataclass
class Upgrade:
    name: str
    description: str
    cost: int
    permanent: bool
    apply_effect: Callable[["RunState"], None]


@dataclass
class MetaProgression:
    total_runs: int = 0
    unlocked_tiers: int = 1
    max_floor_reached: int = 1
    prestige_tokens: int = 0
    unlocked_upgrades: set[str] = field(default_factory=lambda: {"lucky_coin", "loaded_dice"})


@dataclass
class RunState:
    seed: int
    floor: int = 1
    day_actions_left: int = 8
    bankroll: int = 20
    heat: int = 0
    suspicion_limit: int = 100
    temporary_upgrades: set[str] = field(default_factory=set)
    permanent_upgrades: set[str] = field(default_factory=set)
    rng: random.Random = field(init=False)

    def __post_init__(self) -> None:
        self.rng = random.Random(self.seed)

    @property
    def all_upgrades(self) -> set[str]:
        return self.temporary_upgrades | self.permanent_upgrades

    def spend_action(self) -> None:
        self.day_actions_left = max(0, self.day_actions_left - 1)

    def update_bankroll(self, amount: int) -> None:
        self.bankroll = max(0, self.bankroll + amount)

    def add_heat(self, amount: int) -> None:
        self.heat = min(self.suspicion_limit, self.heat + amount)

    def busted(self) -> bool:
        return self.heat >= self.suspicion_limit or self.bankroll <= 0
