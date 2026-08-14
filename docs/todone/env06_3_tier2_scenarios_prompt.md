Status: DONE
Board row: `env06_3` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** 2026-08-14
- **Completion/implementation commits:** `31edc627`, `4e9dd723`, `36db8c5c`, `246fe093`; PM integration `6a4355b2`
- **Verification:** PM scope/design review PASS; integrated validation, Foundation systems + UI, 10-seed/320-checkpoint determinism (`3558257132`), visual QA, 25/25 content and selector contracts, Grand Casino clean/showdown regressions, and 14/14 zero-overlap scenario captures PASS.
- **Deviations:** None. Generic structured debt-settlement deltas and resale-shelf offer mutations were required production seams within prompt scope; Grand Casino scenarios remain limited to presentation/crowd/comps/heat and inert hook flags.

# Agent Prompt — 0.6 env06_3: Tier-2 + Grand Casino Scenario Set

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Content authoring
on the env06_1 engine, sibling of env06_2 (read its landed data as the
house style for scenario authoring). Binding design contract:
`docs/plans/0.6_living_world_roadmap.md` — Pillar 1 catalog (★ launch
cut). Voice: `docs/plans/0.5_voice_bible.md` +
`docs/plans/0.6_voice_bible_world_register.md`. This prompt is
self-contained for rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `env06_3`
   to `IN_PROGRESS` with agent + date, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop and pick other work.
2. Log discoveries/deviations tagged `[env06_3]`; owner-only questions
   under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log line noting
   crew06_5 / crew06_8 progress toward claimable.

## Dependencies

`env06_1` DONE. `env06_4` (Punchline 3-layer rework) DONE for the
Punchline scenarios — its layer model defines where L1/L2 scenarios
attach; verify the landed layer API by code. If env06_4 is not DONE,
author every other venue and mark the Punchline block as a follow-up
in the board log (do not block the whole task).

## Task

Author the ★ launch scenarios — ~25 in
`data/environments/scenarios.json`:

- **The Punchline** — layer 1 (3): Open Mic Night, Headliner Night,
  Bringer Show; layer 2 (3): High-Stakes Night, Greased Week, Debt
  Court. Layer scoping per env06_4's model. Debt Court must integrate
  the existing Collector/debt systems (settle active markers at a
  discount via an exclusive service/event; witness beat when the
  player has no debt).
- **jazz_club (3):** Guest Legend, Rent Party, Recording Night — these
  layer **above** the shipped set-arc system (sparse→build→peak→
  release stays untouched; scenarios recolor tips, favors, staff
  attention, and exclusive encounters around it).
- **kitty_cat_lounge (3):** Amateur Night, The Buyout (Velvet
  recruitment anchor; rope-gated sub-area with a whale inside —
  entry requires a name/flag, deny path is content too), Slow Night.
- **delta_queen (4):** Wedding Charter, Whale Aboard (heist Plan B
  vouch anchor flag), Fog Delay (phase-based stakes drift), Engine
  Trouble (travel-locked phases — reuse the existing travel-lock
  mechanics; never soft-lock: the lock must expire by phase).
- **beach (3):** Bonfire Night, Storm Coming, Festival Weekend
  (Lucky recruitment anchor flag).
- **pawn_shop (3):** Estate Lot Day (unique one-off resale-shelf
  items — coordinate schema with the shipped resale shelf; chain06_1
  and heist Plan B source components here, flag-anchored), Serial-Check
  Day (selling hot goods risk; sets strict alarm-tolerance band
  nearby), Sal's Mood (paired micro-variants).
- **grand_casino (3):** Gala Night, Convention Crowd, Audit Night
  (heist Plan A criteria flag). Grand Casino scenarios tune texture,
  crowd, comps, and heat only — **the boss duel, invite gate, chips
  economy, and Players Card flows are untouchable**; prove no
  interference with a full clean-route + showdown regression.

Completeness bar per scenario is identical to env06_2 (≥3 mutation
axes, 1–3 exclusive events, hook flags, presentation, phases where the
design says so). Recruitment/heist anchors are inert flags until
crew06_5 / crew06_8.

## Hard rules

- env06_2's rules apply verbatim (determinism, content check, voice
  register, tutorial pinning, no new art — log art wishes as
  Discoveries).
- Jazz set-arc and Grand Casino boss structures are read-only.
- Engine Trouble/Fog Delay locks always expire deterministically.
- Style: tabs, typed GDScript where touched; `.tmp/` reports. Suite
  timeout = max(300s, baseline×1.5).

## QA / Tests

1. Content check green over the full set.
2. Seed-audit sweep (20 seeds) reaches every scenario.
3. Grand Casino regression: clean-route victory AND showdown route both
   complete under each of the three casino scenarios.
4. Engine Trouble: travel lock engages and expires by phase; no
   soft-lock under save/load mid-lock.
5. Jazz set arc timing identical to baseline under all three scenarios.
6. Debt Court settles a real marker at the configured discount; no-debt
   visit gets the witness beat.
7. Manual smoke with screenshots to `.tmp/`: two scenarios per venue.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: scenario list, anchors placed (Buyout/Whale Aboard/Audit
Night/Festival/Estate Lot), regression evidence, gate results. On an
unfixable gate failure: stop at last green commit, set `BLOCKED`,
report verbatim.
