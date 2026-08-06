# Agent Prompt — Inventory Screen Rework + Item Description Redo

Last reconciled: 2026-08-05
Release target: 0.5.0
Status: **OPEN / PROMISED SPLIT FEATURE NOT YET EXECUTED**

## Execution record — 2026-08-05

Status: **COMPLETE**

- Design choices: the recommended responsive card grid, voiced-line detail
  depth, and one shared item-card presentation contract for run inventory and
  meta-home storage were used.
- Implementation: `item_card_view_model.gd` is the shared source of item-card
  title/voice/glyph/badge/affinity/stack presentation; run and meta inventory
  use the same pooled grouped-card surface; `risk_tier` is excluded at badge
  selection; ticket/pile quantities summarize instead of flooding the grid;
  hover/selection exposes the `+N` stack without mechanical prose.
- Voice: all 67 run-item descriptions and 40 collection flavor lines were
  reconciled with the narration rollout and audited for distinct, nonnumeric
  neo-noir copy.
- Commits: `0845c7fc`, `a0b9290a`, `39c56a31`.
- Captures: `.tmp/inventory_card_redesign/after/run_inventory_desktop.png`,
  `run_inventory_small.png`, `meta_inventory_desktop.png`, and
  `meta_inventory_small.png` (before captures are in the sibling `before/`
  directory).
- Gates: exact-source UI integration and design-system checks passed in
  `.tmp/v05_ui_decision_final/summary.json`; determinism matched hash
  `2820946917`; visual QA reported no warnings; the final Full matrix passed
  in `.tmp/v05_release_candidate_green/summary.json`.

The 2026-08-05 pre-release audit confirmed that later work supplied useful
prerequisites but did not close this prompt. Run and meta inventory now share
the spatial `InventoryContainerSurface`, item affinity badges exist, and the
in-progress narration rollout edits many item descriptions. The promised
scannable item-card/detail contract is still absent, this prompt has no
execution record, and it has never been archived.

Treat the current narration changes as owner-owned input. Reconcile and reuse
their item descriptions; do not overwrite them with an independent second
voice pass. Entry also requires the release-gate truth/regression prompt to be
green so this task cannot archive against false-positive gates.

Copy everything below the line into the worker agent. This is one of two
feature prompts split out of the tutorial playtest pass
(`tutorial_playtest_fixes_prompt.md`, note 1) because it needs real design
depth, not a tweak. The contained interaction bugs (highlight both shelf
items, first-click focus, "+N" hover count, tooltip de-dupe) stay in that
sibling pass — coordinate, don't overlap.

## Decisions to confirm at kickoff (owner may answer inline; else use the
## recommended default)

1. **Layout:** grid of item cards (recommended) vs. a vertical list.
2. **Detail depth:** on select/hover, show name + one voiced line + attribute
   badges + game-affinity glyph + stack count (recommended). More/less?
3. **Unify with the meta home?** The meta-home item storage was reorganized in
   the meta-home UI pass. Recommended: share the SAME item-card renderer/view
   model between the run inventory and the home storage so they read as one
   system. Confirm or keep them separate.

Proceed on the recommended defaults if not told otherwise; note the choices in
your report.

---

You are in `D:\Projects\Beat-The-House`, Godot 4.6 GDScript casino roguelike.
Systems: `scripts/ui/run_inventory_screen.gd` /
`scripts/ui/run_inventory_view_model.gd` (the run inventory), plus
`scripts/ui/meta_item_interaction_screen.gd` /
`meta_item_interaction_view_model.gd`, `item_found_popup.gd`, and
`attribute_badge_row.gd` for item presentation. Item data lives in the
collections/items content (`data/collections/collections.json` and the item
content library); attribute glyphs in `data/art/attribute_glyphs.json`.

## Part 1 — Screen rework

The run inventory screen reads poorly. Rework its layout for clarity:
- A clean, scannable set of item cards (recommended grid): each card shows the
  class glyph, item name, a one-line voiced description, its attribute badges,
  and its stack/quantity.
- A detail state on select/hover: the voiced description, full attribute
  badges, the game-affinity glyph, and the buff **stack count ("+N")**.
- **Do NOT show the `risk_tier` attribute** in item badges (matches E-1 in the
  sibling pass — hide it at the badge-selection level, not by masking text).
- Responsive: works at small-screen sizes (`small_screen_policy.gd`); no
  clipping or overlap; tickets/piles summarize rather than flooding the grid.
- If unifying with meta-home storage (decision 3), extract a shared item-card
  renderer/view-model both screens use, rather than duplicating layout.

## Part 2 — Description redo (voice)

Rewrite every item description in the neo-noir voice of
`docs/plans/0.5_voice_bible.md`: one short, characterful line that conveys what
the thing *is to you*, not a spec. The glyphs/badges carry the numbers — prose
must not restate effect values ("+2 luck for 3 turns" as words is banned).
Every item gets a distinct line; no mechanical dumps, no duplicated phrasing
across items. Cover the full item roster, not just the tutorial items.

## Acceptance

- Inventory screen is clearly organized and readable at desktop and small
  screen; item cards show glyph + name + one voiced line + badges + stack.
- Detail/hover shows the "+N" stack count and full badges; risk never renders.
- Every item description is one voiced line in the bible's tone, no effect
  numbers as prose, no repeats. Before/after captures under `.tmp/`.
- If unified: a single shared item-card component drives both run inventory and
  home storage.

## Hard rules

- Root cause and real design, not a reskin. Determinism preserved (seeded;
  no per-frame allocation in the card/list draw — zero-copy hot paths). Idle
  liveness untouched. Tabs, typed GDScript, sparse comments. Copy follows the
  voice bible. Captures under `.tmp/`. Never revert or stage unrelated
  user-owned work.
- Commit in logical units (screen rework; shared component if any; description
  content).

## Gates (all must pass)

- `tools\validate_project.ps1`
- every supported `-FoundationSuite` (systems + ui)
- `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools\foundation_visual_qa.ps1`

## On completion

Only after every gate passes and the reworked screen is confirmed clean at both
sizes: commit per unit, then ARCHIVE this prompt (git mv `docs/todo/` →
`docs/todone/`) with an execution record (date, commit hashes, before/after
captures, the design choices taken, gate results), and report. If blocked, stop
at the last green commit, do NOT push, and report what remains.
