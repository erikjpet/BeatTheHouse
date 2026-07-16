# Agent Prompt — 0.5 Slice 6: Showdown Rework Phases 1-3 (The Walk, the Pat-Down, the Interrogation)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). Seeded RNG via `RngStream`
forks; dialogue via the talk/dialogue pipeline; the Grand Casino endgame
state machine lives in `scripts/core/run_state.gd` under the canonical
contract in `docs/plans/grand_casino_endgame_design.md` (ids
`the_house_calls`, `casino_taken_out_back`, and the flag families are
BINDING). This file is self-contained; the design contract is
`docs/plans/0.5_grand_casino_rework_plan.md` section 7 (phases 1-3) —
read both first. Requires slices 1-3 and 5 landed; re-verify actual code.

## Task

Rework the showdown's front half. The trigger conditions and
`showdown-pending` state stay as-is; what happens after the player
answers `the_house_calls` becomes three authored phases. The old
single-roll Beat 2/Beat 3 resolution is REPLACED (slice 7 lands the
finale; this slice must leave a functioning intermediate resolution —
keep the legacy final check as the temporary phase-4 stand-in wired to
the new phase outputs, clearly marked for slice 7 replacement).

### Phase 1 — The Walk (ditch exactly one item)

Between answering the call and the back-room door: one screen/dialog
offering AT MOST ONE ditch action, options data-authored and
availability-gated:
- **Hand off to the Crew** — available ONLY if the player interacted
  with The Crew this run (audit which crew flags prove interaction:
  crew loans, favors, deliveries — pick the provable set). Item is
  SAVED: removed now, returned to inventory after the encounter
  resolves (any outcome except taken-out-back, where it is returned to
  the meta side per slice 8 — for now: returned on survival, lost on
  failure, documented).
- **Trash it** (bin/planter/toilet — flavor variants): item LOST; small
  seeded chance of being seen (heat sting + story line).
- **Keep everything**: proceed.
Enforce the one-ditch maximum in state, not UI.

### Phase 2 — The Pat-Down (contraband punishment tiers)

Classify what the player carries into the back room. Build a
data-driven contraband classification (the item classes already exist —
the current showdown item-modifier table in the design lock names the
contraband and surveillance sets; convert that table into data):
- **Clean**: no contraband/surveillance items → no penalty.
- **Minor**: exactly one contraband-class item → confiscated (removed),
  noted in story log.
- **Serious**: multiple contraband OR any surveillance gear →
  confiscated + a heavy handicap term recorded for the finale.
- **Blatant** *(tunable threshold: 3+ contraband items, or
  watched-cheat evidence combined with any contraband)*: IMMEDIATE
  `casino_taken_out_back` failure — no interrogation, no duel. Blatant
  cheating forfeits the encounter; the failure message says so.

### Phase 3 — The Interrogation (three beats)

Three dialogue beats. Each beat Rourke presents REAL evidence from THIS
run, selected deterministically from the tracked state: watched-cheat
flags, attention sources, open debts, drunk level, prior cameo
encounters (slice 3), card ineligibility. The player counters with 2-3
choices per beat whose strength derives from run facts (clean-play
history, held items, Linda standing, crew ties). Convert the old hidden
formula modifiers (evidence penalty, clean-play modifier, item modifier,
alcohol/debt penalty, prior-boss modifiers — exact tables in the design
lock) into VISIBLE beat stakes.

Output of phases 1-3 is a serialized `grand_casino_duel_terms` dict:
starting stacks/handicaps, Rourke aggression/cheat level, and margin
thresholds — consumed by slice 7's duel. Until slice 7 lands, feed the
legacy check from these terms so the encounter remains winnable and
losable.

## Hard rules

- Determinism: evidence selection, seen-chance, and any variation from
  named seeded forks at action boundaries.
- Canonical ids/flags preserved; new state serializes; a save mid-phase
  restores to the correct phase.
- Zero-copy per-frame; idle liveness untouched. Style: tabs, typed
  GDScript, sparse comments; dialogue per
  `docs/plans/content_style_guide.md`; `.tmp/` reports. Suite timeout =
  max(300s, baseline×1.5).

## QA / Tests

1. One-ditch enforcement; crew handoff availability derived from real
   crew flags; trash seen-chance deterministic per seed.
2. Pat-down tier table: each tier from scripted inventories, including
   the blatant instant-fail path with its distinct message.
3. Interrogation beats select evidence matching scripted run states;
   choice strength reflects run facts; `grand_casino_duel_terms` output
   matches expectations per scenario.
4. Full showdown route still completable and failable via the temporary
   phase-4 stand-in; save/load at each phase boundary.
5. Manual smoke: play the three phases with a dirty inventory and a
   clean one; confirm both read like scenes, not menus.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`
- `tools/foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100`

## On completion

Commit (logical units), delete this prompt file in the final commit,
push, report the contraband data classification, the duel_terms schema,
and gate results. On an unfixable gate failure: stop at last green
commit, report verbatim.
