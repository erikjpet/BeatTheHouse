# Main Integration Audit — 2026-09-14

## Verdict

The recent game updates are substantial and generally good, and the merged
player path is playable. The project did lose track of its actual state:
completed work remained off `main`, completed prompts still claimed they were
uncommitted or unmerged, `fix06_32` appeared simultaneously as `TODO` and
`DONE`, and the README still described the eight-game 0.5.1 source instead of
the 11-game 0.6 integration line.

This audit reconciles those records and integrates every completed non-placement
branch found in scope. It does not declare the game release-ready. Current room
construction cannot reliably accommodate the expanded object inventory, and
that boundary remains an explicit blocker.

## Integrated and preserved

- Base: remote `main` `d2594eb3`, which already contains the full back-room
  poker tweak stack and the game-prop/Silas rework.
- Playtest repairs: `429079bb` (BUG-01…36 repair payload, with BUG-10/34/37
  intentionally left to placement), `0bdeba56` (repeatable visible-input
  session harness), and `c028ebaf` (deterministic shard-cleanup assertion).
- Game-rework verification: the completed `fix06_32` stack was replayed onto
  current `main` as `6b9752b6` through `485f8a05`. Its two overlaps were
  resolved by retaining both the newer environment-grounding gates and the
  game-rework gates; newer Hold'em personalities/dealer choreography and room
  game props remain present.
- Recent playtest reports and completed task prompts are preserved in
  `docs/plans/agent_playtest/` and `docs/todone/`.

## Explicitly excluded

The placement experiment at historical commit `b182b3c6` was not merged. The
owner rejected this approach because adding many new objects requires a
room-construction rethink rather than extending the current slot-placement
model. Its branch and generated review artifacts were deleted during the
two-branch custody cleanup.

## Verification on the integrated candidate

| Gate | Result | Evidence |
| --- | --- | --- |
| Static architecture validation | PASS | 101.8–102.5 seconds on repeated exact-tree runs |
| Godot import | PASS | 18.5 seconds in `.tmp/f2` |
| GDScript load | PASS | 432 checked, 0 failures, 38.4 seconds |
| Playtest Fixes 01 regressions | PASS | 0 failures, 855 ms |
| Playtest Fixes 02 regressions | PASS | 0 failures, 80 ms |
| Playtest Fixes 03 regressions | PASS | 0 failures, 107 ms |
| Game-rework gate wiring/hostile fixtures | PASS | 7 gate groups; `.tmp/fix06_32_gate_contract_*` |
| Game and Coin Pusher contract shards | PASS | 0 failures |
| Runtime core/events/primitives contract shards | PASS | 0 failures |
| Broad Foundation Contract aggregate | FAIL | 98 failures in `.tmp/f2`; classified below |

The broad Contract red is not waived:

| Shard | Failures | Current classification |
| --- | ---: | --- |
| content core | 9 | 7 placement/finalization, 1 encounter staging, 1 debug banner |
| content scenarios | 3 | generated scenario inventory |
| content semantics | 5 | expanded-layout/finalization semantics |
| Crew | 71 | 60 golden snapshot drift, 5 placement/finalization, 1 route/economy, 5 dependent behavior failures |
| Punchline | 3 | placement/finalization |
| runtime economy | 6 | route/economy and placement-dependent arrivals |
| runtime scenarios | 1 | Grand Casino slot-bank placement |

Two attempted report directories produced harness-only failures before product
assertions: a descriptive path exceeded the legacy Windows 260-character limit
while copying an imported PNG into shard projects, then its aborted shard left
one exact-workspace Godot child that the concurrency guard caught. The orphan
was verified by full command line and stopped; the valid rerun used the short
`.tmp/f2` report root. Future Windows shard reports should use short roots.

## Visible-input playtest rerun

An isolated production-input session on merged `main` completed:

1. start menu → new seeded run;
2. guided dialogue and first pickup;
3. inventory inspection;
4. world-map selection and travel;
5. two merchant purchases;
6. family-loan offer, confirmation, and bankroll credit;
7. second-venue travel;
8. Pull Tabs entry, paid ticket, and advantage actions.

The session produced no script errors or engine warnings. One usability issue
remains: tutorial pointer panels can cover the center of the action they ask the
player to click. An exposed portion remains usable, but this should be corrected
with the room/UI placement redesign. This run is integration evidence, not a
substitute for the full parked `playtest06_2` release gate.

## Required order from here

1. Design and approve a new room-construction/placement model for the expanded
   object set.
2. Integrate it and return the full Contract aggregate to green without
   refreshing goldens merely to hide behavioral drift.
3. Rerun the full playtest gate.
4. Resume performance/platform, polish, packaging, versioning, and release work.

