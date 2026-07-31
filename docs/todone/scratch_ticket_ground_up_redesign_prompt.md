# Agent Prompt — Scratch Tickets GROUND-UP REDESIGN (3-Layer, Contained, Polished)

Copy everything below this line into the worker agent. This is a large,
careful rebuild; use a capable model. Multiple prior reworks produced
unprofessional, messy, UNCONTAINED results. This time the architecture is
fixed and non-negotiable: a strict THREE-LAYER model. Keep the current
mechanics and odds; redesign the presentation, generation, and feel from the
ground up to a finished, polished result modeled on the game "Scratchy
Scratchy" (smooth, satisfying).

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (900×430 board, immediate-mode canvas, per-game modules, seeded
RNG). `scripts/games/scratch_tickets.gd` (~3,429 lines) renders tickets
through ~20 tangled, overlapping draw functions (result overlays, slot wells,
plaques, spot boxes, production text, symbol reveals...) and scratches through
a coarse 48×32 grid mask — which is exactly why the result is messy, boxy, and
choppy. The DATA is fine (`data/games/scratch_tickets.json`: 7 tickets with
face/palette, mechanic/legend, sections/rects, prize_table, rtp_band) — keep
the odds and mechanics. Rebuild the RENDERING and FEEL.

## THE CONTAINMENT MANDATE (the whole point)

Delete the tangle of overlapping draw functions and replace ticket rendering
with EXACTLY THREE LAYERS, each a single-responsibility renderer with a clean
interface and NO knowledge of the others. A ticket is drawn as Layer 1, then
Layer 2 on top, then Layer 3 on top. Nothing else. This strict separation is
how we keep it contained — do not reintroduce cross-cutting "overlay/plaque/
well/box" helpers that blur the layers.

Define one region model shared by all three layers: each ticket type declares
its scratch REGIONS (rects) once (from the data `sections`/layout); Layer 1
draws the printed slots for those regions, Layer 2 draws the result icon
centered in each region, Layer 3 draws the foil masked over each region. One
source of truth for region rects.

### Layer 1 — Background (the printed ticket face)

The lowest layer: the ticket's printed appearance. Deterministic per TICKET
TYPE (not per instance). It draws the full ticket artwork — frame, theme,
title, the DEFINED result boxes/slots with their icon locations outlined, and
the RULES printed within the artwork. It is the backdrop everything sits on
and it defines the structure, art design, and rules of the ticket. Each of
the 7 tickets has its own distinct, professional theme (2-fer, Lucky 7s, Tic
Tac Gold, Crossword Corner, Bonus Bingo, High Roller Hold'em, Golden Vault).
Provable: rendered alone (foil/icons off), each ticket reads as a complete,
professional printed ticket with clearly located empty result boxes and
legible rules.

### Layer 2 — Icons (the generated result layer)

The middle layer: the randomly generated result, drawn centered in each
region's box. Rules:
- **Generated per INSTANCE, unique every time, driven by the RESULT.** A
  given payout result (e.g. a 2× winner) is always generated with a valid win
  method per the ticket's rules, but the SPECIFIC icons that reach it are
  freshly, uniquely generated each instance (same outcome, different faces).
  Two 2× winners must look different while both being valid 2× wins.
- **High-fidelity icons — this is a hard requirement.** The icons are far more
  defined than the current ones. PLAYING CARDS must be drawn with the SAME
  card renderer the table games use (blackjack/baccarat/video poker) so a card
  on a ticket is identical in quality to a card in a game — find that renderer
  and reuse it. Numbers, suits, and symbols must be unambiguously identifiable
  as exactly what they are, no guessing.
- **Contrast & color theory.** Each icon is designed for legibility against
  its region within the ticket's theme palette — proper contrast, a coherent
  color scheme per ticket. Icons never blend into the background or each
  other.
Provable: with the foil off, every result icon is instantly identifiable
(card/number/suit/symbol), high-contrast, centered in its box; and repeated
generation of the same payout yields visibly different but valid icon sets.

### Layer 3 — Foil (the scratch layer)

The top layer: a designed, themed foil that covers each result region
completely and is what the player removes by scratching. Rules:
- It is a PLANNED DESIGN that matches the ticket's background theme — NOT a
  single solid grey "foil" blob. It looks like an intentional printed
  scratch-off coating for THIS ticket (theme-matched texture/pattern/sheen).
- It covers the entire result region and sits centered over the Layer-2 icon
  beneath it.
- It clearly signals to the player THIS IS WHERE YOU SCRATCH (a "scratch here"
  affordance in the foil design), without being ugly or generic.
Provable: with icons hidden beneath, the foil reads as a designed, theme-
matched coating over exactly the result regions, obviously scratchable, fully
covering the icons until removed.

## Scratch mechanics — smooth, like Scratchy Scratchy

The current scratch is choppy, boxy, and sometimes drops swipes for no reason.
Rebuild it:
- **Continuous, not grid-boxy.** Replace the coarse 48×32 grid mask with a
  smooth, high-resolution coverage mask so removal follows the pointer
  cleanly with no blocky steps. The foil should come off like DIRT the player
  swipes away — a smooth, continuous clearing under a swiping click-drag.
- **Reliable pointer tracking.** Fix the dysfunctional swipes: interpolate the
  stroke between pointer samples (no gaps on fast swipes), and clear exactly
  where the player drags, every time — never drop a swipe.
- **Satisfying feel.** A soft brush with flakes/dust shedding at the stroke
  (presentational, zero-copy), a smooth reveal of the icon beneath as coverage
  builds, and the existing per-region auto-complete when a region is mostly
  cleared (so no corner-grinding) — but the manual swiping itself must feel
  great, smooth, and responsive. Reduce-motion: instant clear / scratch-all.
Provable: a smooth-swipe demonstration; the mask clears continuously along the
drag path with no boxy steps and no dropped swipes; a ten-ticket hand-scratch
feels smooth and satisfying (report in words).

## Throw tickets away (a waste basket)

Add a WASTE BASKET the player can swipe a ticket into to discard it WITHOUT
finishing the scratch — the moment they know it's a dud, they trash it and the
next queued ticket comes up. Requirements: a clearly drawn basket; swiping/
dragging the ticket to it (or a clear discard control) removes the current
ticket and advances the queue; discarding an unfinished ticket forfeits any
unrevealed value exactly as if it were completed a loser (do not let discard
skip a win — a ticket's outcome is fixed at purchase; discarding a WINNER
still pays it out or clearly warns, your call — state the rule). Provable: buy
several, trash a dud mid-scratch, confirm it's gone and the next appears.

## The vending machine — recreate to match

Rebuild the scratch vending machine to the SAME level of detail and polish as
the redesigned tickets: a complete, professional, themed cabinet (study the
slot machines — `scripts/games/slots/slot_renderer.gd` — for the quality bar)
showing the stocked tickets in their dispenser rows, price labels, a selection
affordance, and a dispensing feel that hands the ticket to the play surface.
It should feel just as finished as the tickets. Provable: a capture of the
machine that reads as a polished, complete cabinet on par with the slots.

## Hard rules

- **Odds & mechanics unchanged:** outcome is fixed by seeded roll AT PURCHASE;
  scratching/discarding is presentation and never changes the result; keep the
  7 tickets, their prize tables, rtp bands, and the multi-buy queue. RTP audit
  must still pass within bands.
- Determinism (result fixed at purchase; per-instance icon generation seeded
  and reproducible; probe self-consistent); zero-copy per-frame (mask, brush
  particles, layers render from the module snapshot; no per-frame
  `duplicate(true)`); idle-animation liveness untouched; web-safe.
- Style: tabs, typed GDScript, sparse comments; captures/RTP under `.tmp/`.
  Suite timeout = max(300s, ceil(recorded baseline × 1.5)).
- The rebuild should SHRINK and clarify the module — three clean layer
  renderers plus the card/icon renderer, mask, and machine, not 20 tangled
  draw helpers. Report the before/after line count and the function map.
- Working tree may contain uncommitted user-owned work; never revert or stage
  it. Stage explicitly.

## Provable deliverables / QA (prove each; report evidence)

1. **Layer isolation:** captures of each ticket rendered with (a) Layer 1 only,
   (b) Layers 1+2, (c) all three — proving clean separation and that each layer
   is complete and professional on its own.
2. **Icon fidelity:** cards match the game card renderer; numbers/suits/symbols
   unambiguous; contrast good per theme — captures per ticket.
3. **Per-instance uniqueness:** same payout generated N times yields visibly
   different, all-valid icon sets (assert + captures).
4. **Foil:** theme-matched designed coating covering regions, obviously
   scratchable (captures).
5. **Smooth scratch:** continuous mask, no boxy steps, no dropped swipes
   (demonstration); reduce-motion path.
6. **Trash:** discard-a-dud flow works and advances the queue.
7. **Machine:** polished cabinet capture, slot-parity.
8. **Determinism + RTP:** outcome fixed at purchase, reproducible; per-ticket
   RTP within bands (table).
9. **Feel acceptance (manual, in words):** buy a stack across tickets — scratch
   feels smooth and satisfying, icons are crisp and clear, foils look designed,
   trashing duds is easy, the machine feels complete.

## Gates

- `tools\validate_project.ps1`
- `-FoundationSuite scratch_tickets`, `games`, `ui`, `systems`
- `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools\foundation_performance_probe.ps1 -RequireGodot`
- `tools\foundation_visual_qa.ps1`
- the scratch RTP audit tool
- `tools\foundation_mouse_playtest.ps1` (strict single run)

## On completion

Only after every gate passes AND every provable deliverable is proven and it
feels smooth and polished:

1. Commit in logical units (region model; Layer 1 background; Layer 2 icons +
   card renderer; Layer 3 foil; scratch mask/feel; waste basket; vending
   machine).
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append an execution record (date, commit hashes, before/
   after line count + function map, the proof captures list, RTP table, gate
   results), and stage the move.
3. PUSH to the remote.
4. Report: the three-layer architecture as built, icon-fidelity and
   uniqueness proof, the scratch-feel result in your own words, the trash
   flow, the machine capture, RTP table, and gate results.

On an unfixable gate or any unproven deliverable, stop at the last green
commit, do NOT push, and report exactly what is not yet finished.

---

## Execution record — 2026-07-31

### Scope and commits

- Branch: `scratch-redesign`
- `bb19e5ea` — shared playing-card renderer used by blackjack, baccarat,
  video poker, and High Roller Hold'em scratch results.
- `b7a3a2bb` — professional raster ticket faces, generated reveal artwork,
  strict three-layer rendering, continuous mask, discard flow, and vending
  machine.
- `16a519fc` — architecture assertions and the 56-file proof recorder.

The prompt remains archived here. The user-owned source copy in the primary
working tree was not deleted or staged.

### Authored art

The seven printed faces are committed raster assets under
`assets/art/scratch_tickets/layers/*_background_pro.png`; the game does not
construct them from procedural vector boxes. They were produced with the
built-in image-generation workflow using the old ticket only as a geometry
reference, with a professional North American lottery/security-print brief:
guilloche and engraved line work, tactile paper and ink, integrated rules,
price/VOID/barcode/serial furniture, exact result wells, and a distinct
illustrated identity for every ticket. The prompt set covered retro vermilion
2-Fer, sapphire jeweled Lucky 7s, treasury-green Tic Tac Gold, newspaper/art
deco Crossword, heritage Bingo Hall, aubergine private-room Hold'em, and an
obsidian engraved Golden Vault.

Generated reveal medallions are committed under
`assets/art/scratch_tickets/reveal_symbols/pro_*.png`. They were generated on
a chroma field and processed with the ImageGen skill's soft-matte/despill
helper before being reduced to 512x512 transparent assets. Dynamic
numbers/letters remain deterministic text, and cards use the exact shared
table-game renderer.

### Contained architecture and function map

`scripts/games/scratch_tickets.gd` fell from 3,429 to 2,020 lines, from 176 to
108 functions, and from 43 to 10 `_draw_*` functions. Its ticket render path
contains exactly these ordered calls:

1. `ScratchTicketBackgroundRenderer.draw`
2. `ScratchTicketIconRenderer.draw`
3. `ScratchTicketFoilRenderer.draw`

The supporting modules are:

| Module | Lines | Public responsibility |
| --- | ---: | --- |
| `scratch_ticket_region_model.gd` | 138 | `build`, `rect_for`, `normalized_rect`; one region source of truth |
| `scratch_ticket_background_renderer.gd` | 22 | `draw`; one authored raster face per ticket type |
| `scratch_ticket_icon_renderer.gd` | 156 | `draw`; result-driven, per-instance icon placement |
| `scratch_ticket_foil_renderer.gd` | 170 | `draw`, `style_id`; themed coating only |
| `scratch_ticket_mask.gd` | 305 | `initialize`, `ensure`, `scratch`, `reveal_all`, `ticket_complete` |
| `scratch_ticket_machine_renderer.gd` | 148 | `draw`, `waste_basket_rect`; cabinet and discard target |
| `playing_card_renderer.gd` | 97 | `draw_card`, `draw_card_back`, `draw_suit`, `card_from_code` |

No renderer knows about or invokes another layer. The background renderer only
draws the preloaded face; the icon renderer only draws resolved result
content; the foil renderer only paints the coating from the shared mask and
regions.

### Proof captures

All proof is under `.tmp/scratch_redesign_proof/`; `manifest.json` reports
`passed: true`, the `background -> icons -> foil` layer order, a 256x192
continuous mask, all seven ticket types, and 56 files.

- Layer isolation: `01_two_fer_{background,background_icons,all_layers}.png`
  through
  `07_golden_vault_{background,background_icons,all_layers}.png`, plus
  `layer_isolation_all_tickets.png`.
- Icon fidelity and uniqueness:
  `unique_01_two_fer_instance_{1,2,3}.png` through
  `unique_07_golden_vault_instance_{1,2,3}.png`,
  `same_payout_unique_instances.png`, and `uniqueness.json`. Three equal-payout
  instances per type are valid but visibly different.
- Scratch:
  `smooth_scratch_01_coated.png`,
  `smooth_scratch_02_fast_swipe.png`,
  `smooth_scratch_03_clean_reveal.png`, and
  `smooth_scratch_demonstration.png`.
- Trash:
  `trash_flow_01_dud_mid_scratch.png`,
  `trash_flow_02_basket_drop_target.png`,
  `trash_flow_03_next_ticket.png`, and
  `trash_flow_demonstration.png`.
- Machine: `vending_machine_context.png` and
  `vending_machine_polished.png`.

The normal-renderer recorder completed with
`SCRATCH_REDESIGN_CAPTURE_PASS files=56`. A dummy/headless viewport is not
used because Godot's dummy renderer cannot read a viewport texture.

### Manual feel acceptance

A live-window mouse run hand-scratched ten tickets across Hold'em, Bonus
Bingo, Golden Vault, and Tic Tac Gold, including single-sample fast jumps,
slow multi-pass strokes, queue advancement, and a mid-scratch discard. The
interpolated stroke left a continuous reveal with no gaps or square grid
steps. Small Bingo cells cleared without corner-grinding; larger card and
ladder wells needed a natural second pass and then snapped clean at the
completion threshold. The generated icons stayed crisp at gameplay scale and
the authored foil read as a designed coating. Discarding was immediate and
the next queued ticket appeared coated. Discarded winners remain payable; the
fixed purchase result cannot be rerolled by scratching or discarding.

### RTP audit

50,000 seeded samples per type:

| Ticket | RTP | Required band | Result |
| --- | ---: | ---: | --- |
| Two-Fer | 3.87602 | 3.800–4.100 | PASS |
| Lucky 7s | 4.01580 | 3.850–4.200 | PASS |
| Tic Tac Gold | 4.04092 | 3.800–4.250 | PASS |
| Crossword Corner | 3.89031 | 3.750–4.200 | PASS |
| Bonus Bingo | 3.98838 | 3.750–4.250 | PASS |
| High Roller Hold'em | 4.28590 | 3.800–4.400 | PASS |
| Golden Vault | 4.10338 | 3.700–4.250 | PASS |

Report: `.tmp/scratch_tickets/rtp_audit.json`.

### Final gate results

- `tools/validate_project.ps1`: PASS.
- Foundation `scratch_tickets`: PASS, 11.971s stage,
  `.tmp/test_reports/20260731_013450_smoke/summary.json`.
- Foundation `systems`: PASS, 28.833s stage,
  `.tmp/test_reports/20260731_012654_smoke/summary.json`.
- Foundation `games`: PASS, 94.224s stage,
  `.tmp/test_reports/20260731_012821_smoke/summary.json`.
- Foundation `ui`: PASS; UI scene compile 72.830s and all integration stages
  green, `.tmp/test_reports/20260731_013132_smoke/summary.json`.
- Determinism: PASS; two 10-seed runs, 320 checkpoints each, identical hash
  `391682297`.
- Performance/zero-copy/liveness: PASS; scratch pointer 60 samples,
  0.09148ms average, 0.097ms p95, 0.125ms max against 0.75/1.5/5.0ms
  budgets; zero full-snapshot calls; scratch idle animation advanced 49 times
  in 120 frames.
- Foundation visual QA: PASS.
- Strict mouse-only playtest: PASS; 58 input events, victory reached, and
  failure/recovery pressure verified. Report:
  `.tmp/foundation_mouse_playtest_final/scratch_redesign_final.json`.
- Scratch RTP audit: PASS for all seven rows above.
- Proof recorder: PASS, 56 files.
