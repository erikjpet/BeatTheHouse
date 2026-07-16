# Agent Prompt — 0.5 Slice 5: Players Card Tiers + Linda, Keeper of the Cage

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). Data-driven content; dialogue
via the talk-dock/dialogue pipeline (`scripts/ui/talk_dock.gd`,
`data/dialogue/dialogues.json`, `data/events/events.json`); UI via
extracted components. This file is self-contained; the binding design
contract is `docs/plans/0.5_grand_casino_rework_plan.md` sections 5-6 —
read it first. Requires slices 1-2 landed (rooms + Cage window); slice 3
recommended first. Re-verify actual code; code reality wins.

## Task

### 1. Card tiers — Bronze / Silver / Gold (data-driven)

- Replace the single clean-route checkpoint with a three-tier ladder,
  thresholds in the Grand Casino `demo_objective` data *(all tunable)*:
  - **Bronze**: first recognition — settled games + small net winnings
    at low heat. Benefits: bar comps, small chip bonus, Linda's
    dialogue opens.
  - **Silver**: sustained clean play — more settled games, higher net
    winnings, heat ceiling held. Benefits: HIGH-LIMIT ROOM ACCESS
    (drive slice 1's `grand_casino_high_limit_access` gate; the cash
    buy-in path remains as the cheater's entrance), improved comps,
    and one "look away" (below).
  - **Gold**: the win — the Gold review at the Cage IS the clean
    victory. Preserve `high_roller_cashout` event/action id and
    `demo_victory_route = "high_roller_cashout"` exactly (canonical
    contract in `docs/plans/grand_casino_endgame_design.md`; update
    that doc's clean-route section in this slice's commit).
- Tier progress tracks per run (flags/counters serialized), shown live
  in the Cage window's card block (slice 2 placeholder becomes real):
  current tier, exact progress to next, benefits list.
- **Cheat evidence = permanently card-ineligible for the run**
  (existing `grand_casino_cheat_evidence` flags gate all tiers). The
  Cage window states ineligibility plainly. This is the two-path split:
  honest players climb; cheaters buy in and live spatially (slice 3).

### 2. Linda — the clean path's boss character

- Linda (canonical name, owner-locked) is the keeper of the Cage and
  the card program — Rourke's mirror. Give her real DIALOGUE SCENES via
  the existing dialogue/talk pipeline: tier-up scenes (Bronze, Silver),
  the Gold review scene, and 2-3 ambient encounter lines on the Main
  Floor. Her tone: warm, professional, invested in the player's clean
  climb.
- **Generosity mechanics** (clean path only, data-tuned):
  - Comps at each tier (free drink tokens, chip bonuses, one suite
    rest that restores like the motel service — reuse existing
    service-effect plumbing).
  - **One "look away" per run at Silver+**: the next small heat gain
    (below a data threshold) is forgiven with a Linda story line —
    implemented as a one-shot flag consumed at the suspicion-apply
    seam, ONLY while card-eligible and evidence-free.
- Promotions list in the Cage window populates from tier benefits.

## Hard rules

- Determinism: tier evaluation at the same action-boundary seams the
  clean-route criteria use today; no new RNG beyond seeded dialogue
  variation if any.
- Zero-copy per-frame; idle liveness untouched; Cage window rebuilds on
  state change only.
- Save compat: tier state serializes; 0.4-style saves (no tier flags)
  derive tier from existing counters on load. Canonical ids preserved.
- Style: tabs, typed GDScript, sparse comments; dialogue copy follows
  `docs/plans/content_style_guide.md`; `.tmp/` reports. Suite timeout =
  max(300s, baseline×1.5).

## QA / Tests

1. Tier ladder: scripted clean play crosses Bronze→Silver→Gold at the
   data thresholds; Gold review completes the clean victory end-to-end.
2. Silver opens the high-limit door; cash buy-in still works
   independently; cheat evidence locks all tiers permanently and the
   window says so.
3. Look-away consumes exactly once, only under its conditions, and
   logs its story line.
4. Save/load mid-ladder preserves tier + benefits; legacy-save tier
   derivation test.
5. Existing showdown route unaffected (regression: full heat-route run
   green).
6. Manual smoke: climb to Silver, read every Cage window state, meet
   Linda's scenes.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`
- `tools/foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100`

## On completion

Commit (logical units), delete this prompt file in the final commit,
push, report tier thresholds chosen, Linda's scene list, and gate
results. On an unfixable gate failure: stop at last green commit, report
verbatim.
