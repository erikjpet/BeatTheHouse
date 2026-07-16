# Agent Prompt — 0.5 Slice 8: Meta Loop — Players Card Items, Prestige Runs, Pawnable Chips

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). The meta collection system
lives in `scripts/core/meta_collection_service.gd` +
`scripts/core/collection_item_resolver.gd` with a 4-float durability item
schema (`data/collections/collections.json`); the meta home + Sal's Pawn
Shop sell collection items for gold; run loadouts inject meta items into
runs. This file is self-contained; the design contract is
`docs/plans/0.5_grand_casino_rework_plan.md` section 8 — read it first.
Requires slices 5 and 7 landed; re-verify actual code.

## Task

### 1. Players Card mint (clean-route win)

- Gold-review victory MINTS a unique Players Card collection item into
  the meta inventory, stamped with run stats in its instance data:
  seed (respect hidden-seed challenges), final score, days survived,
  tier timeline, route. One card per clean win; each is a distinct
  instance.
- Presentation: the mint is announced at run end. If the run report
  screen (run_end_screen_revamp) has landed, add the card reveal to its
  RESULT section; otherwise announce via the existing victory summary
  and leave a clearly-marked integration hook.

### 2. Card fragility (owner-locked)

- Players Cards pin their durability float to the CRITICAL band
  permanently: they never decay normally, never repair, and are exempt
  from any usage-decay pass (audit the durability handling in the
  collection schema and carve the card class explicitly).
- **Carrying a card into a run that is LOST destroys that card
  forever** — removed from the meta collection at run failure, with a
  story/report line. Run success returns it (plus prestige effects
  below).

### 3. Prestige runs (card carried in)

- Carrying a Players Card in the run loadout makes the run a PRESTIGE
  run, recorded on run state:
  - **Recognition**: Grand Casino entry starts with reduced initial
    attention *(tunable)* — the staff knows you.
  - **Expectations**: the clean-route heat ceiling tightens *(tunable)*
    — recognized players are held to a higher standard.
  - **Reward depth**: run-end collection drops roll at a higher value
    band / deeper subcategory access *(tunable; reuse the existing
    drop-tier machinery — do not build a new tree this slice)*.
- Prestige status and its modifiers surface in the Cage window card
  block and the run report.

### 4. Uncashed chips → pawnable meta item

- Slice 7's "shown the door" ending converts the uncashed chip amount
  into a "Grand Casino Chips" meta item (single stack instance, value =
  chip amount) granted alongside run-end drops.
- Sal's Pawn Shop (meta) prices it for gold at a fenced rate *(tunable,
  propose 60% of face)* — Sal fences what the casino wouldn't cash.
  Reuse the existing meta sale flow end-to-end.

## Hard rules

- Determinism: mint/destroy/prestige effects are deterministic
  consequences of run outcomes; drop-value bonuses draw from the
  existing seeded drop streams.
- Meta gold economy and run cash economy stay fully separate (chips
  item is a meta object sold for gold; it never re-enters a run as
  cash).
- Save/profile compat: card instances follow the existing
  schema-versioned profile persistence (atomic writes already exist);
  a profile without cards loads unchanged.
- Zero-copy per-frame; idle liveness untouched. Style: tabs, typed
  GDScript, sparse comments; `.tmp/` reports. Suite timeout =
  max(300s, baseline×1.5).

## QA / Tests

1. Mint on clean win with correct stamped stats (hidden-seed respected);
   no mint on showdown routes or failures.
2. Fragility: card carried + run lost → gone from profile permanently;
   card carried + run won → retained; durability pinned critical and
   exempt from decay passes.
3. Prestige: carried card applies recognition/expectation modifiers on
   Grand entry and the drop-value bonus at run end; non-prestige runs
   unchanged (regression).
4. Chips item: door ending grants the stack at the right value; Sal
   prices and sells it for gold at the fenced rate; gold/cash
   separation asserted.
5. Profile round-trip: mint → restart app (simulated) → card present →
   carry → lose → absent.
6. Manual smoke: full clean win → find the card at home → carry it →
   lose on purpose → confirm the sting.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI +
  collections/meta
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`

## On completion

Commit (logical units), delete this prompt file in the final commit,
push, report the card instance schema, prestige tunables, and gate
results. On an unfixable gate failure: stop at last green commit, report
verbatim.
