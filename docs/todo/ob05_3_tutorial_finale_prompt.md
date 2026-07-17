# Agent Prompt — Onboarding Slice 3: Tutorial Finale — Easy Grand Casino + the First Card

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). This file is self-contained;
the binding design contract is `docs/plans/0.5_onboarding_tutorial_plan.md`
Part 2 beats 6-7. REQUIRES: onboarding slices 1-2 and the FULL gc05 queue
landed (three casino rooms, chips, Cage window, Linda, card tiers, card
mint from gc05_8). Re-verify actual code; code reality wins.

## Task

### 1. Easy-mode Grand Casino (tutorial-scoped)

- The `tutorial_first_card` challenge config overrides the Grand Casino
  objective data for this run only: tiny net-winnings target, 1-2
  settled games minimum, generous clean-heat ceiling, and
  tutorial-tier progression (the card ladder compresses so the review
  is reachable in one short visit — implement as config overrides on
  the tier thresholds, never global changes).
- Tutorial play stays on the MAIN FLOOR only (high-limit door reads
  locked with teaching copy; back room untouched — Rourke may be
  VISIBLE for flavor but no showdown can trigger in the tutorial:
  gate the heat-route triggers under the tutorial config and prove it
  with a test).

### 2. The guided finale (beats 6-7)

6. **Casino beat**: coach-guided — buy in, notice CHIPS vs cash, play
   1-2 short games, win the small target (seed-auditioned like slice
   2; extend the audition to the full arc), then guided to the Cage.
7. **Linda + the card**: a tutorial variant of Linda's review scene —
   warmer, explanatory ("what the card means") — issuing the win.
   The card MINTS through the real gc05_8 machinery (tutorial runs
   mint a card marked as the starter card in its instance data). The
   run report screen shows the win + the card; the final coach beat
   fires back home: the card is in the collection, carry it for
   recognition, LOSE a run holding it and it is gone forever.

### 3. Post-tutorial handoff

- `tutorial_completed` set on victory; the next run offered is a normal
  run with the card available in the loadout; the first-time prestige
  tip (slice 1's pack, if the casino landed it) covers the carry
  decision.
- If the player somehow FAILS the tutorial run (bankroll zero on a
  hostile path), handle gracefully: brief encouragement copy + offer
  instant replay of the tutorial or a normal start; `tutorial_completed`
  is NOT set on failure unless they decline the replay.

## Hard rules

- All easing lives in the tutorial challenge config; normal-run
  balance, tiers, and mint rules are byte-identical.
- Determinism, zero-copy per-frame, idle liveness, canonical Grand
  Casino ids: binding as everywhere. Copy per the content style guide.
  Style: tabs, typed GDScript, sparse comments; `.tmp/` reports.
  Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Full tutorial arc test: beats 1-7 driven end-to-end → victory →
   starter card present in the profile collection with correct
   instance stamps.
2. Showdown cannot trigger under the tutorial config even at forced
   heat (test the override).
3. Tier compression applies only under the tutorial config (normal-run
   thresholds asserted unchanged).
4. Failure path: tutorial loss → replay offer → replay works; decline →
   normal start, tutorial_completed set.
5. The starter card behaves as a real card afterward: carried into a
   normal run and lost → destroyed (gc05_8 fragility regression).
6. Manual: complete the whole tutorial as a new player would; time it —
   the plan's bar is ~15 minutes guided; report the measured time.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI +
  collections/meta
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`
- `tools/foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100`

## On completion

Commit (config; finale beats; handoff as logical units), delete this
prompt file in the final commit, push, report the measured tutorial
duration, the tier-compression values, and gate results. On an
unfixable gate failure: stop at the last green commit and report
verbatim.
