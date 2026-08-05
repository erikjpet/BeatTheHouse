# Agent Prompt — Tutorial Playtest Fix Pass (Mike's playthrough)

Copy everything below the line into the worker agent. This is a follow-up
polish pass on the guided first-run tutorial, driven by a real playtest. It
builds on the in-flight tutorial rework (`tutorial_guided_run_rework_prompt.md`,
`tutorial_verify_and_complete_prompt.md`) and the selection-stability fix
(`tutorial_selection_flash_and_object_teleport_fix_prompt.md`) — do NOT
re-solve the flash/teleport bug here; assume that lands separately.

Every fix below has a stable ID, the observed symptom, the change, the system
to touch, and an acceptance check. A traceability table at the end maps all 28
playtest notes — 25 handled here, 3 split into two sibling feature prompts
(`tutorial_inventory_rework_prompt.md`, `tutorial_meaningful_decisions_prompt.md`).

## Fundamental-fix standard (read first)

Each item is one of three kinds — treat it accordingly, never with a bandaid:

- **Bug (has a root cause):** find and fix the cause; a symptom patch is a
  fail. Several root causes are already confirmed below — do not re-diagnose
  them away:
  - **B-4 soft-lock:** `scripts/core/tutorial_flow.gd` has NO caught/fail/abort
    branch (only a `tutorial_completed` check). The flow literally has no next
    state after a caught outcome. The fix ADDS a caught→continue transition to
    the flow state machine; do not just suppress the caught event.
  - **E-1 risk in overlay:** "risk" is a real registry entry — the `risk_tier`
    glyph in `data/art/attribute_glyphs.json`, selected by
    `attribute_badge_row.gd`. Remove it from the object-overlay attribute set
    at the registry/selection level, not by masking a string.
  - **E-2 progression→discovery:** events carry structured class badges
    (`class_badges.event.progression`, `class_badges.service.discovery` already
    exist in `attribute_glyphs.json`) plus `events.json` copy. Reframe at the
    data level (badge/class + copy together), not wording alone.
  - **H-2 / H-3 map:** `scripts/core/world_map.gd` already models node state
    (seen / visited / reachable — see `world_map_canvas_route_visibility_check`).
    Extend that STATE MODEL (persist "seen", allow travel to visited nodes with
    a live route); do not fake persistence in `world_map_canvas.gd` drawing.
  - **D-5 tooltip repeats:** find WHY text duplicates (a tooltip composed from
    an overlapping name/description/effect field, or a glyph label repeated as
    prose) and remove the overlapping source; do not string-dedupe the output.
  - **D-3 first-click focus:** the missed first-click focus lives in the
    interaction-focus path (`environment_interaction_view_model.gd` /
    `foundation_main.gd`) and is likely the same seam as the deferred
    selection-stability fix — coordinate, fix the focus contract, don't add a
    priming double-click.
- **Design decisions handled in separate prompts — NOT in scope here:** the
  inventory rework and the meaningful-destination-decision feature (the
  gas-station-vs-underground branch plus making the route choice matter) need
  their own depth and are split into `tutorial_inventory_rework_prompt.md` and
  `tutorial_meaningful_decisions_prompt.md`. Do not attempt them in this pass;
  this pass is bugs + presentational polish only.
- **Presentational-by-nature (the tweak IS the fix, no deeper cause):**
  **A-2** spacing, **F-3** bigger cards, **G-1** label rename, **G-2** count,
  **D-4** stack number. Do these cleanly; there is no "root cause" to chase.

---

You are in `D:\Projects\Beat-The-House`, Godot 4.6 GDScript. Relevant systems:
tutorial engine `scripts/core/tutorial_flow.gd` + `data/tutorial/lessons.json`
+ `scripts/ui/coach_overlay.gd` / `coach_view_model.gd`; environment focus
`scripts/ui/environment_interaction_view_model.gd` /
`environment_interaction_controller.gd` / `foundation_main.gd`; inventory
`scripts/ui/run_inventory_screen.gd` / `run_inventory_view_model.gd` /
`meta_item_interaction_screen.gd`; attribute overlay `attribute_badge_row.gd`;
blackjack `scripts/games/blackjack.gd` / `table_game_visuals.gd` /
`playing_card_renderer.gd`; conversations `scripts/ui/talk_dock.gd`; map/travel
`scripts/ui/world_map_canvas.gd` / `world_map_overlay_controller.gd` /
`foundation_travel_view_model.gd`; collection feedback `pull_tabs.gd` /
`scratch_tickets.gd`.

## Workstream A — Coach overlay presentation

- **A-1 · Highlight must not dim the rest of the screen.** *Symptom:* the
  highlight darkens everything else. *Fix:* in `coach_overlay.gd` remove/replace
  the full-screen dim (the 0.40/0.10 alpha scrim). Draw only a positive
  emphasis on the target (glow/outline/pulse ring), leaving the rest of the
  screen at full brightness. *Accept:* highlighted step is legible with the
  surrounding UI un-dimmed.
- **A-2 · More space between coach text and the highlighted control, and a
  clear "what this does" layout.** *Symptom:* text crowds the button. *Fix:*
  restructure the coach bubble so the explanatory text sits ABOVE, with a
  larger gap, and the action button (or the pointer to the real control) sits
  at the BOTTOM of the box. Text describes what the button does; the button is
  visually separated. *Accept:* every coach step shows description-above /
  action-below with comfortable spacing; nothing overlaps.

## Workstream B — Tutorial flow & pacing (`tutorial_flow.gd`, `lessons.json`)

- **B-1 · Do not close venues/locations during the tutorial.** *Symptom:*
  locations close mid-tutorial. *Fix:* while the tutorial is active, force all
  relevant venues OPEN (bypass open-hours gating) so the player is never blocked
  by closing time. *Accept:* no venue is unavailable due to hours during the
  guided run.
- **B-3 · Pause the environment during conversations.** *Symptom:* the world
  keeps animating/acting while a conversation is open. *Fix:* when a
  conversation/talk dock is active, pause ambient environment activity
  (patron/dealer motion, timers, background events) and resume on close. Must
  stay deterministic (freeze at an action boundary, not wall-clock). *Accept:*
  opening a conversation visibly halts environment activity until dismissed.
- **B-4 · Getting caught must never soft-lock.** *Symptom:* being caught during
  the tutorial dead-ends the player with no way forward. *Fix:* root-cause the
  soft-lock; guarantee a recovery path (a caught outcome that continues the
  tutorial, or a guarded retry) so the run always proceeds. *Accept:* trigger a
  caught state during the tutorial and confirm the player can always continue.
- **B-5 · Add a drinking beat.** *Symptom:* no coaching around alcohol. *Fix:*
  add a tutorial conversation/coach point that introduces buying/drinking and
  what Drunk does. *Accept:* the drinking beat fires once in the guided run.
- **B-6 · Tell the player to collect tickets from the tray.** *Symptom:* players
  don't know to collect. *Fix:* add a coach/tutorial instruction at the
  pull-tab/scratch step directing the player to collect tickets from the tray.
  *Accept:* the instruction appears at the right step.

## Workstream C — Conversation system (`talk_dock.gd`)

- **C-1 · The phone call must be back-and-forth dialogue.** *Symptom:* the call
  is one-directional. *Fix:* make the call a real exchange — alternating
  caller/player lines with player responses — using the talk-dock multi-line
  system, not a single block. *Accept:* the call plays as a turn-taking
  conversation.
- (B-3 pause is enforced here too.)

## Workstream D — Inventory & item interaction

(The full inventory-screen rework + description redo is its own feature —
`tutorial_inventory_rework_prompt.md`. The items below are the contained
interaction/tooltip bugs only.)

- **D-2 · Highlight BOTH tutorial shelf items.** *Symptom:* only one item is
  highlighted. *Fix:* the tutorial shelf step highlights both items the player
  should inspect. *Accept:* both shelf items are emphasized simultaneously.
- **D-3 · First item click must focus the item on the shelf.** *Symptom:* the
  first click doesn't focus the shelf item. *Fix:* root-cause the missed focus
  on first selection (the focus/interaction path in
  `environment_interaction_view_model.gd` / `foundation_main.gd`); the first
  click focuses reliably. *Accept:* clicking an item the first time focuses it.
- **D-4 · Hover display: show the buff stack count ("+N additions").** *Symptom:*
  hover is good but doesn't show how many are added. *Fix:* in the item hover/
  overlay, show the numeric count of additions the buff grants. *Accept:* hover
  shows the "+N" contribution.
- **D-5 · No repeated text in tooltip popups.** *Symptom:* tooltips repeat the
  same text. *Fix:* de-duplicate tooltip/popup content so a line never appears
  twice in the same popup. *Accept:* no popup shows duplicated text.

## Workstream E — Attribute overlay & event-risk copy

- **E-1 · Do not show the "risk" attribute in the object overlay.** *Symptom:*
  risk attribute is shown in the overlay. *Fix:* hide the risk attribute from
  the object/attribute overlay (`attribute_badge_row.gd` / the glyph set),
  keeping other attributes. *Accept:* risk no longer renders in the overlay.
- **E-2 · Reframe event risk as progression → discovery; rework box copy.**
  *Symptom:* the "risk" framing on events reads wrong; box text is weak.
  *Fix:* change the event-risk framing to a progression/discovery framing and
  rewrite the descriptions and in-box text accordingly (voice bible). *Accept:*
  event boxes present discovery/progression language, not raw "risk."

## Workstream F — Blackjack (`blackjack.gd`, `table_game_visuals.gd`,
## `playing_card_renderer.gd`)

- **F-1 · Show animated patrons and dealer during the tutorial before the
  deal.** *Symptom:* they don't appear until dealt. *Fix:* render/animate the
  seated patrons and dealer at the table from the moment the surface opens in
  the tutorial, not only after the first deal. Respect idle-liveness (no frozen
  0.000 idle). *Accept:* patrons + dealer are visibly present pre-deal.
- **F-2 · Fix the box drawn over patron 2.** *Symptom:* a stray box overlaps
  patron 2. *Fix:* correct the layout/z-order so no UI box covers patron 2.
  *Accept:* patron 2 renders unobstructed.
- **F-3 · Enlarge the player's cards.** *Symptom:* the player's cards are too
  small. *Fix:* increase the player's hand card size for readability without
  breaking table layout. *Accept:* player cards are clearly larger and fit.
- **F-4 · Automatic payout.** *Symptom:* payout requires manual steps. *Fix:*
  settle and pay winning hands automatically at resolution (no extra click).
  *Accept:* a win pays out on its own.
- **F-5 · Play the hand out before ending on a loss.** *Symptom:* a loss ends
  the hand early. *Fix:* resolve the full hand (dealer plays out) before
  reporting a loss/closing. *Accept:* on a losing hand the dealer completes
  before the result shows.

## Workstream G — Collection / winnings feedback

- **G-1 · "Cashes" → "Cash In".** *Symptom:* label reads "Cashes." *Fix:* find
  the collect/cash label (pull-tab/scratch flow) and change it to "Cash In".
  *Accept:* the control reads "Cash In".
- **G-2 · Show the count of wins in the winners pile.** *Symptom:* the winners
  pile has no count. *Fix:* display the number of winners in the pile. *Accept:*
  the winners pile shows its count.
- (F-facing collect instruction is B-6.)

## Workstream H — World map & travel (`world_map_canvas.gd`,
## `world_map_overlay_controller.gd`, `foundation_travel_view_model.gd`)

- **H-1 · Hovering a map location focuses it.** *Symptom:* hover does nothing.
  *Fix:* on hover, focus/emphasize that location (highlight + detail). *Accept:*
  hovering any node focuses it.
- **H-2 · Seen locations persist on the map.** *Symptom:* locations vanish when
  not travelable. *Fix:* once a location has been seen, keep it visible on the
  map for reference even if it can't currently be traveled to (shown as
  known/locked). *Accept:* previously seen nodes remain on the map.
- **H-3 · Always allow travel back to visited places when a route exists.**
  *Symptom:* backtracking is blocked. *Fix:* if a return route is available,
  offer travel back to any visited location. *Accept:* visited, route-connected
  locations are travelable again.
- **H-4 · Map navigable by scrolling.** *Symptom:* can't scroll the map. *Fix:*
  add scroll navigation (pan) so the whole map (including off-frame nodes like
  the pawn shop) is reachable. *Accept:* the map scrolls to reveal all nodes.

(Making the destination choice itself more impactful is its own feature —
`tutorial_meaningful_decisions_prompt.md` — not part of this pass.)

## Hard rules

- Root cause, not symptom. Determinism preserved (seeded; freeze/pause at
  action boundaries, never wall-clock). Zero-copy per-frame; idle-liveness never
  gamed (F-1 especially — no accepting a 0.000 idle). Tabs, typed GDScript,
  sparse comments. Player-facing copy follows `docs/plans/0.5_voice_bible.md`.
  Captures under `.tmp/`. Never revert or stage unrelated user-owned work.
- Commit in logical units per workstream with clear messages. Keep the
  stuck-state sweep and visual QA green.

## Gates (all must pass)

- `tools\validate_project.ps1`
- every supported `-FoundationSuite` (systems + ui)
- `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools\foundation_mouse_batch_playtest.ps1` (strict — no soft-locks)
- `tools\foundation_visual_qa.ps1`

## On completion

Only after every gate passes and a full guided tutorial run is confirmed
soft-lock-free end to end: commit per workstream, then ARCHIVE this prompt
(git mv `docs/todo/` → `docs/todone/`) with an execution record (date, commit
hashes, per-fix proof captures, gate results), and report. If any item can't be
completed, stop at the last green commit, do NOT push, and report exactly which
IDs remain and why.

## Traceability — all 28 playtest notes → fix ID

1. inventory screen rework + descriptions redo → **split → `tutorial_inventory_rework_prompt.md`**
2. highlight both items in tutorial shelf → **D-2**
3. first item click doesn't focus item on shelf → **D-3**
4. hover display good, add # of additions for buff → **D-4**
5. don't repeat text in tooltip popups → **D-5**
6. call should be back-and-forth dialogue → **C-1**
7. progression → discovery on event risk; rework box text → **E-2**
8. larger gap between text and highlighted button; button at bottom, text above
   → **A-2**
9. don't close locations during tutorial → **B-1**
10. choose gas casino or go straight underground → **split → `tutorial_meaningful_decisions_prompt.md`**
11. don't show risk attribute in overlay → **E-1**
12. tell user to collect tickets from tray → **B-6**
13. "cashes" → "cash in" → **G-1**
14. add number of wins in winners pile → **G-2**
15. add tutorial conversation point for drinking → **B-5**
16. animated patrons/dealer don't show before dealt → **F-1**
17. blackjack has box over patron 2 → **F-2**
18. make your blackjack cards larger → **F-3**
19. blackjack should automatically payout → **F-4**
20. highlight shouldn't darken the rest of screen → **A-1**
21. pause environment during conversation → **B-3**
22. getting caught soft-locks the player → **B-4**
23. hover over map locations should focus onto it → **H-1**
24. seen map locations persist for reference → **H-2**
25. always allow travel back if route available → **H-3**
26. make where-you-go decisions more impactful → **split → `tutorial_meaningful_decisions_prompt.md`**
27. map navigable through scrolls → **H-4**
28. play out hand before ending on blackjack loss → **F-5**

---

## Execution record — 2026-08-05

Status: **complete**. All 25 in-scope fix IDs were implemented at their owning
state/data/interaction seam. The three split notes remain in their named sibling
prompts and were not folded into this pass.

### Workstream commits

- `36e00fe6864118246a086d657bdd3ad20fe47632` — coach presentation, tutorial
  flow/pacing, conversation, item interaction, and discovery feedback (A–E).
- `78d94e1094384b2d2dcab34ac55bd6696672f1b4` — blackjack completion and
  collection/winnings feedback (F–G).
- `b8a10fef0165519205324ceec6afe548f19447df` — persisted map knowledge,
  route-connected backtracking, hover focus, and scroll navigation (H).
- Archive and this execution record are committed by the enclosing archival
  commit.

### Per-fix proof

All visual captures are under `.tmp/tutorial_playtest_fixes/captures/`. Behavioral
proof is in the final Systems/UI reports and guided audit listed below.

| Fix | Proof capture/check |
|---|---|
| A-1 | `01_dialogue_highlight_apartment_pal.png`: positive target rings with no screen scrim; final UI suite. |
| A-2 | `01_dialogue_highlight_apartment_pal.png`: explanation above, separated action at bubble bottom. |
| B-1 | Systems regression for tutorial hours override; both guided routes completed. |
| B-3 | Final UI suite conversation-active pause/input contract; captures `01` and `03c` show live TalkDock states. |
| B-4 | Guided audit caught-transition/stuck sweep; `11_path_b_count_miss_heat_warning.png`. |
| B-5 | `07a_underground_drink_intro.png`. |
| B-6 | `06_path_a_xray_winner_near_bottom.png` (“Buy and collect” tray instruction). |
| C-1 | `03c_family_phone_turn_taking.png` (caller line plus player responses); Systems dialogue-node regression. |
| D-2 | `03a_corner_shelf_both_items_highlighted.png`. |
| D-3 | `03b_first_click_item_focus_addition_count.png`; final UI first-click focus regression. |
| D-4 | `03b_first_click_item_focus_addition_count.png` (`+3 additions`). |
| D-5 | Systems tooltip-source regression and final UI info-card fit/content checks. |
| E-1 | Systems source-selection regression removes `risk_tier`; final UI event card check. |
| E-2 | Systems data-class regression plus final UI `Discovery:` event-card check. |
| F-1 | `07b_path_b_predeal_patrons_and_dealer.png`; blackjack pre-deal cast/idle regression. |
| F-2 | `07b_path_b_predeal_patrons_and_dealer.png` (patron 2 unobstructed). |
| F-3 | `08_path_b_raised_bet_chips.png` and `09_path_b_real_lookaway_peek.png`. |
| F-4 | Systems blackjack auto-settlement/payout regression. |
| F-5 | Systems blackjack dealer-playthrough regression. |
| G-1 | Systems pull-tab and scratch-ticket `Cash In` label regressions. |
| G-2 | `06_path_a_xray_winner_near_bottom.png` (`WINNERS x0`) and Systems nonzero winner-count regression. |
| H-1 | Final UI hover-focus contract. |
| H-2 | `05_parking_tip_opens_path_a_and_b.png`; final UI seen/locked persistence checks. |
| H-3 | Guided Path A/Path B audit and final UI visited-return-route checks. |
| H-4 | `WORLD_MAP_CANVAS_ROUTE_VISIBILITY_CHECK PASS` scroll-pan regression; final UI map checks. |

### Gate results

- `tools/validate_project.ps1` — **PASS** (final standalone run).
- `-FoundationSuite systems` — **PASS**:
  `.tmp/test_reports/20260805_002117_smoke/summary.json`.
- `-FoundationSuite ui` — **PASS**:
  `.tmp/test_reports/20260805_002328_smoke/summary.json`.
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10` —
  **PASS**, 10 seeds, 320 checkpoints, matching hash `578175084` in
  `.tmp/foundation_determinism_probe/run_a.json` and `run_b.json`.
- `tools/foundation_mouse_batch_playtest.ps1` (strict) — **PASS**, 2/2
  playable loops, 2/2 victories, zero true failures:
  `.tmp/tutorial_playtest_fixes/mouse_batch/aggregate_summary.json`.
- `tools/foundation_visual_qa.ps1 -RequireGodot` — **PASS**.
- `scripts/tests/world_map_canvas_route_visibility_check.gd` — **PASS**.
- Full guided tutorial audit — **PASS**: Path A and Path B reached Bronze and
  ended; 100-state stuck sweep and lesson-boundary save/load checks passed:
  `.tmp/tutorial_playtest_fixes/guided_audit/tutorial_guided_run_audit.json`.
- Windowed guided proof capture — **PASS**, 23 PNGs under
  `.tmp/tutorial_playtest_fixes/captures/`.
