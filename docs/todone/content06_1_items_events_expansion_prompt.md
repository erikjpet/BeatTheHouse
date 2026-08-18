Status: TODO
Board row: `content06_1` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** 2026-08-18
- **Completion/implementation commits:** `48807695`, `6279395e`, `4f91777b`, `1253e3b1`
- **Verification:** PM verbatim scope/design review and production-path manual smoke; combined Systems, Contracts, UI, 10-seed determinism, and canonical visual QA PASS on the integrated tree. All scenario souvenirs reach within-run inventory/shelf/sale presentation, and all five Mags outputs have real consumers.
- **Deviations:** Owner ruled souvenir collection integration is within-run only; no new cross-run collection persistence was authorized. Economy audit values remain playtest inputs and were not tuned.

# Agent Prompt — 0.6 content06_1: Items, Services, Events Depth Pass

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Binding design
contract: `docs/plans/0.6_living_world_roadmap.md` — Pillar 6. This is
the depth-and-connective-tissue content pass over the landed 0.6
systems. Voice: both voice bibles. This prompt is self-contained for
rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row
   `content06_1` to `IN_PROGRESS` with agent + date, append a Work Log
   line, commit the claim. If the row is not `TODO`, stop.
2. Log discoveries/deviations tagged `[content06_1]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`.

## Dependencies

`env06_2`, `env06_3`, `crew06_6` DONE (scenario + crew surfaces to
fill). Audit every seam earlier prompts logged as "content06_1 fills"
on the board's Discovery Log before starting — that list is part of
your scope; code reality wins.

## Task

### 1. Scenario souvenirs (items as memories of nights)

- Author ~12–16 scenario-keyed items in `data/items/items.json`:
  wedding favor, wake matchbook, fight-night betting slip, festival
  trinkets, estate-lot one-offs (the Sal-chain item among them —
  verify chain06_1's hook if landed), convoy/tour-bus finds. Each:
  a small real effect or collection value (never dead flavor), scenario
  acquisition path, collections-shelf integration per the shipped
  collections schema.

### 2. Crew gear tier (Mags' bench catalog)

- Fill crew06_6's bench seam: 4–6 Mags-crafted upgrades of shipped
  cheat items — loaded dice (craps06_1's data hook), tuned loupe,
  nudge dampener (push06_2's hook), lined sleeve — each crew-gated
  (rank + cash + sometimes a component), each with documented risk
  deltas in the cheat systems they feed. No new cheat mechanics —
  power flows through existing hooks.

### 3. Event + service fill

- Sweep every launch scenario for its 1–3 exclusive-event budget;
  fill gaps so no ★ scenario ships thin (coordinate against env06_2/3
  landed data).
- Scenario services promised by data but unbuilt (open bar, cover
  charge, private table, two-drink minimum variants) — implement via
  the existing services schema.
- L3 services completeness: Rook's ride tiers, bench UI polish, job
  board flavor rotation.

### 4. Economy + collections audit

- One pass over all new 0.6 sinks/sources (Numbers, pusher EV, crew
  cuts, heist bands, souvenirs) against the run economy: document the
  intended earn/spend curves in the data files; flag imbalances as
  board Discoveries with proposed tunings (release06_1 does final
  balance — you provide the map).
- Collections: every new collectible registered; shelf presentation
  verified.

## Hard rules

- Data + content only; generic code changes require a board Discovery
  entry with rationale.
- Every item effect routes through existing effect systems; no
  special-cased item logic.
- Voice registers per source (house services courteous, street items
  blunt).
- Determinism/perf/save/style as other prompts. Suite timeout =
  max(300s, baseline×1.5).

## QA / Tests

1. Content checks green across items/services/events (extend where
   new ids need validation).
2. Every souvenir acquirable via its scenario path in a seeded run
   fixture; collections registration complete.
3. Bench upgrades: gate matrix (rank/cash/component), effect deltas
   land in their cheat systems.
4. No ★ scenario below its exclusive-event budget (automated sweep).
5. Manual smoke: buy/craft/earn a sample across all categories;
   screenshots to `.tmp/`.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: item/service/event inventory added, bench catalog, economy
audit summary (with flagged imbalances), and gate results. On an
unfixable gate failure: stop at last green commit, set `BLOCKED`,
report verbatim.
