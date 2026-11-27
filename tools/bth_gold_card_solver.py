#!/usr/bin/env python3
"""Guarded campaign entry point for the Gold Player's Card ending."""
import sys

sys.dont_write_bytecode = True

from bth_rourke_solver import SolverTarget, main as run_solver


GOLD_BENCHMARK_ROUTES = ("baseline", "balanced", "risk_aware", "minimum_stakes", "target_stakes", "high_limit")

GOLD_CARD = SolverTarget(
    name="Gold Player's Card",
    schema="bth.gold_card_solver_campaign/v1",
    script="tools/gold_card_solver/gold_card_solver.gd",
    ending="players_card",
    ending_target="gold_card",
    victory_field="verified_gold_card_victory",
    routes=(*GOLD_BENCHMARK_ROUTES, "reserve_recovery"),
)


def main(argv=None):
    return run_solver(argv, target=GOLD_CARD)


if __name__ == "__main__":
    raise SystemExit(main())
