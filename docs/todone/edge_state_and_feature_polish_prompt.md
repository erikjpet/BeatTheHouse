# Agent Prompt — Edge-State & New-Feature Polish Pass

Copy everything below this line into the worker agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike preparing 0.5. This file is self-contained. Two goals: (1) make
every empty / first-run / edge state look INTENTIONAL, and (2) make the new
0.5 systems POLISHED, clear, and intuitive for a first-time player. A new
player must always understand what's going on.

## Part A — Edge & empty states look intentional

Drive the game into each of these states and confirm it looks designed,
not broken; fix the ones that don't. At minimum:

- **Fresh profile** — zero collection, zero run history, no housing
  upgrades, no cards, no tips seen. The start screen, career/stats surface,
  meta home, and collection display must all read as inviting, not empty/
  broken.
- **First run / first loss / first win** — the very first time a player
  hits each screen (run report, drops, home) with no prior context.
- **Top housing tier** — no further upgrade; the meta-home HUD and housing
  UI show a clean "top tier" state, not a broken next-cost.
- **Out-of-stock scratch machine** — the machine with few/no tickets
  stocked reads intentionally, not empty.
- **Zero gold / zero bankroll / empty inventory / no unopened bags** —
  each shows a clean empty state with guidance, never a blank or a crash.
- **No world-map routes / all-closed venues at a given time** — the map
  and travel UI handle it gracefully.

For each: the empty state has a clear message and (where useful) a nudge
toward the action that fills it. Use tokens; small-screen and reduce-motion
clean.

## Part B — New-feature clarity & polish

The 0.5 systems are powerful but dense for a newcomer. Make each clear and
intuitive on first encounter, extending the existing coach / first-time-tip
system where a gap exists (do not build a new tutorial system — use the
lesson/coach engine):

- **Chips vs cash + the Cage** — a first-timer must grasp that Grand
  Casino tables use chips, that the Cage cashes them, and the ATM/debt/
  card interactions. Clear first-time guidance and readable affordances.
- **Players Card tiers** — Bronze/Silver/Gold progress and how to claim at
  Linda must be legible; the player should understand why a claim is
  blocked (debt, threshold not met).
- **The Rourke showdown/duel** — the four-phase flow and the duel must be
  understandable in the moment, not confusing.
- **Scratch tickets, cheating, prestige cards** — each reads clearly the
  first time; the player knows what they're doing and what happened.

For each system: confirm the flow is smooth (clean transitions, clear
feedback on every action, obvious next step), and that a first-time tip or
in-context cue exists where a newcomer would otherwise be lost. Fix
rough/unclear affordances in place.

## Rules

- Presentation, clarity, and empty-state handling — NOT new mechanics or
  balance changes. If you find a genuine bug or a system that needs a
  design change, fix obvious bugs in place and REPORT anything larger as a
  follow-up prompt in `docs/todo/`.
- Use the design tokens + coach/tip engine; register any new/changed UI
  files in the UI05 coverage/token gates so they stay green.
- Zero-copy per-frame; idle-animation liveness untouched; determinism
  unaffected. Tokens only, no raw literals. Tabs, typed GDScript, sparse
  comments; captures under `.tmp/`. Suite timeout = max(300s, ceil(baseline
  × 1.5)).
- Working tree may contain uncommitted user-owned work; never revert/stage
  it.

## QA

1. Edge-state matrix: a scripted/manual pass through every state in Part A,
   with a capture each, confirming it reads intentionally.
2. New-user flow: play each Part-B system as a first-timer (fresh profile,
   tips on) and confirm you're never lost; list the tips/cues added.
3. UI gates green with new/changed files accounted; small-screen and
   reduce-motion verified.
4. No regression to existing flows; no gameplay/balance change.

## Gates

- `tools\validate_project.ps1`
- `-FoundationSuite ui`, `systems`, plus collections/meta and any tutorial
  suite
- `tools\foundation_visual_qa.ps1`
- `tools\foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100`
- all four `tools\ui05_*_check.ps1`

## On completion

Only after every gate passes AND you've confirmed the states/flows in the
running game:

1. Commit in logical units (edge states; per-system clarity).
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append an execution record (date, commit hashes, the
   edge-state matrix results, tips/cues added, gate results), and stage the
   move.
3. PUSH to the remote.
4. Report: the edge-state matrix, the new-user clarity changes per system,
   any follow-up prompt you wrote, and gate results.

On an unfixable gate, stop at the last green commit, do NOT push, report
verbatim.

---

## Execution record - 2026-07-29

Commits:
- `6ce2c3d2fa02c756064119d8189739b00cc5b76a` - edge/empty-state presentation polish.
- `e3e43adb52709bfa301e2051e55fea1b3b388be1` - new-feature onboarding clarity cues.

Edge-state matrix capture:
- Capture artifact: `.tmp/edge_state_matrix/edge_state_matrix.json` generated by a throwaway Godot run with isolated profile/meta stores.
- Fresh profile / career stats: PASS - no-run career state is visible and inviting.
- Fresh profile / meta home: PASS - Back Alley, 0 gold, and next-tier goal are explicit.
- Fresh profile / empty collection storage: PASS - empty shelves nudge toward winning a route.
- First loss / run report: PASS - report names the loss and provides replay/home choices.
- First win / run report: PASS - report shows score/replay/reward sections without prior context.
- No unopened bags: PASS - bags view states no bags and points to standard-run wins.
- Top housing tier: PASS - HUD reports Top tier instead of a broken next price.
- No world-map routes: PASS - map/travel detail says no open route leaves here.
- Out-of-stock scratch machine: PASS - rules/status call out sold out/restock.
- Chips/Cage/Card clarity: PASS - Cage text explains chips-first spending, cashout, marker payoff, and card progress.
- Cheat/prestige/showdown cues: PASS - existing heat/debt/chips/card/prestige tips plus objective copy cover risk, Rourke, and carried cards.

Tips/cues added or revised:
- No new coach lesson entries were added because the contract requires exactly nine first-time tips after the starter-card handoff.
- Revised existing first-time tips for heat, debt/ATM markers, routes/closed venues, chips/Cage, and Players Card tiers.
- Added in-context Cage/ATM/card wording, scratch sold-out messaging, route-empty messaging, empty collection/bag/storage nudges, and career no-run copy.

Gate results:
- `tools\validate_project.ps1`: PASS.
- `tools\check_godot.ps1 -RequireGodot -FoundationSuite contracts -TimeoutSec 300`: PASS.
- `tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 300`: PASS.
- `tools\check_godot.ps1 -RequireGodot -FoundationSuite systems -TimeoutSec 300`: PASS.
- `tools\collection_meta_check.ps1`: PASS.
- `tools\foundation_visual_qa.ps1`: PASS.
- `tools\foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100`: PASS.
- `tools\ui05_asset_pipeline_check.ps1`: PASS.
- `tools\ui05_popup_fit_check.ps1`: PASS.
- `tools\ui05_surface_coverage_check.ps1`: PASS.
- `tools\ui05_token_adoption_check.ps1`: PASS.

Deviations:
- The prompt file was untracked in `docs/todo`, so archival used a filesystem move plus explicit staging rather than `git mv`.
- Broader mechanical/design changes were not made; no follow-up prompt was needed.
