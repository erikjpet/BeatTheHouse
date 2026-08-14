Status: TODO
Board row: `craps06_2` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — 0.6 craps06_2: Street Craps (Back-Alley Variant)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Binding design
contract: `docs/plans/0.6_living_world_roadmap.md` — Pillar 4 "Craps"
(the on-ramp) and Pillar 1's *Street Craps* back-alley scenario.
env06_2 shipped the scenario shell with a `"game_hook": "street_craps"`
seam; craps06_1 shipped the core module. This prompt is self-contained
for rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row
   `craps06_2` to `IN_PROGRESS` with agent + date, append a Work Log
   line, commit the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[craps06_2]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`.

## Dependencies

`craps06_1` + `env06_1` DONE; env06_2's scenario shell landed (verify
the hook seam by code).

## Task

- A street variant of the craps module activated by the *Street
  Craps* back-alley scenario through the env06_2 seam: same dice
  core, radically simplified surface — pass/don't pass only, gutter
  stakes (scenario economic profile), no odds/come/place, cash (never
  chips), circle-of-players presentation instead of a table.
- **Teaching identity**: this is where the game teaches craps. First
  session per run gets diegetic one-line guidance from the circle
  (data-driven lines, street register, skippable, never a tutorial
  overlay).
- **Street rules**: heat/security context of the alley applies — the
  circle disperses if the sweep is adjacent (scenario/sweep flags) or
  on a heat spike, converting unresolved wagers per a fair,
  deterministic settlement rule (document it in data). Cruiser Parked
  + Street Craps co-existence must behave sensibly (verify scenario
  exclusivity or interaction, log the choice).
- Dice setting works (same skill window, no practice gate at gutter
  stakes — the street IS practice: successful street sessions can
  grant `craps_setting_trained` progress per data, coordinating with
  the crew06_6 Practice Rig grant so neither path is required).
- Variant config lives in `data/games/games.json` beside the core
  entry — one module, two presentations; no forked logic.

## Hard rules

- One rules engine: street mode must reuse craps06_1's roll/settle
  core (no duplicated payout code — enforce by structure).
- Determinism, perf, save-compat, voice rules as craps06_1 (street
  register here).
- The alley remains functional when the scenario isn't seeded (no
  street craps = no traces).
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports.
  Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Street mode: only pass/don't available; cash routing; gutter
   stake bounds enforced.
2. Disperse-and-settle rule resolves fairly and deterministically
   under forced sweep-adjacent + heat-spike fixtures; mid-round
   save/load restores.
3. Training progress grants per data; casino setting gate honors
   either source (street progress or Practice Rig).
4. RTP harness: street pass-line matches core pass-line exactly.
5. Manual smoke in the scenario, screenshots to `.tmp/`.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: variant config shape, disperse rule, training-grant tuning,
and gate results. On an unfixable gate failure: stop at last green
commit, set `BLOCKED`, report verbatim.
