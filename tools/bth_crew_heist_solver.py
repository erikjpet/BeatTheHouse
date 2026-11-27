#!/usr/bin/env python3
"""Guarded campaign entry point for The Count."""
import sys

sys.dont_write_bytecode = True

from bth_rourke_solver import SolverTarget, main as run_solver


CREW_HEIST = SolverTarget(
    name="Crew Heist",
    schema="bth.crew_heist_solver_campaign/v1",
    script="tools/crew_heist_solver/crew_heist_solver.gd",
    ending=("heist_clean_sweep", "heist_out_hot", "heist_somebody_got_pinched"),
    ending_target="crew_heist",
    victory_field="verified_crew_heist_victory",
    routes=("the_count",),
)


if __name__ == "__main__":
    raise SystemExit(run_solver(target=CREW_HEIST))
