# Agent Prompt — 0.5 UI Full Redesign Overhaul (Final-State UI)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720 baseline; a small-screen play
mode exists). UI is code-built (no scenes beyond main): `VisualStyle`
palette + `FoundationWidgets` helpers + extracted components under
`scripts/ui/`, driven by view models. The game already has an
artist-editable PNG asset pipeline under `assets/art/` (environments,
game scenes, items, inventory containers) — extend that pipeline for UI
art in this task.

This file is SELF-CONTAINED: every rule you need is in here. The design
philosophy in `docs/plans/0.5_ui_overhaul_brief.md` is binding
background reading (identity preserved, hierarchy over chrome, readable
at both sizes, zero performance tax) — read it first. This prompt
SUPERSEDES `docs/todo/ui05_0_audit_design_system_prompt.md`; delete that
file in your final commit alongside this one.

**Ordering guard (owner-locked):** the UI overhaul runs LAST in 0.5. If
any OTHER prompt file remains in `docs/todo/` (for example
`inventory_item_interaction_ui_renovation_prompt.md` or any gc05/ob05/
audio/scratch prompt), STOP immediately, report which prompts remain,
and do no work. The overhaul skins a finished game, not a moving one.

## Mission

Bring every player-facing UI surface to a FINALIZED, ship-quality state.
This is not a reskin-in-place: per-surface layout REDESIGNS are
explicitly allowed (owner decision) wherever hierarchy demands it, as
long as ALL existing functionality remains reachable and no elements
overlap. The bar for done: a brand-new player, with zero explanation,
should understand what everything is and what they can do purely from
looking at the screen. Raw text dumps, debug-style bracket tags
(`[HEAT]`, `[$]`, `[GOAL]`), ASCII meters (`[##---]`), and
paragraph-length explanations of mechanics are all defects to be
eliminated everywhere they appear.

Work through the phases below IN ORDER. Each phase ends with a green
gate run and its own commit(s). Do not start a phase with the previous
one red.

---

## Phase A — Design system foundation + UI art pipeline

Everything later consumes this; build it first.

1. **Token system.** Extend `scripts/ui/visual_style.gd` into a real
   token system: spacing scale, named type-scale steps (not raw sizes),
   color ROLES (surface, panel, accent-primary/danger/success/warning,
   text-primary/muted, meter-heat, meter-drunk), radii, border widths,
   and interaction states (idle/hover/press/focus/disabled). This
   codifies the existing neon-pixel identity — it does not restyle it.
2. **Widget kit.** Extend `scripts/ui/foundation_widgets.gd` with:
   panel, heading, label, button variants (primary/secondary/danger/
   ghost/icon), segmented meter bar (see Phase B), stat chip, icon+label
   row, tab bar, tooltip. Every widget: built from tokens only, all
   interaction states implemented, safe in small-screen mode, hover and
   press feedback that reads as physical (the dealer's-table feel).
3. **Pixel-art UI asset pipeline.** Create `assets/art/ui/icons/` and
   `assets/art/ui/environment_titles/` following the existing item-art
   pattern: hand-authorable PNG files at fixed, documented sizes that
   an artist can open and repaint WITHOUT touching code. You will
   author the initial pixel art yourself (see art quality bar below);
   the deliverable is that every one of these files is swappable.
   - Write an asset manifest `docs/plans/0.5_ui_art_manifest.md`
     listing every UI art file, its exact pixel dimensions, palette
     notes, and what it represents — this is the artist's handoff doc.
   - Loading must go through a single helper with a code-drawn fallback
     if a PNG is missing (game must never break on a missing/replaced
     asset).
4. **Pixel-art icon quality bar (applies to ALL icons in this task).**
   Icons are carefully designed sprites, not rough code-drawn glyphs:
   consistent canvas size per icon class, shared palette from the token
   colors, 1px outline discipline, readable silhouette at actual
   render size, and an obvious real-world metaphor (an eye means
   watched; a flame means heat; a martini glass means drink; a coin
   stack means money). If you cannot name the metaphor in two words,
   redesign the icon. Icons must support a highlighted/active state
   (brightened or glowing variant) without a surrounding text box.
5. **Migration rule.** From Phase B onward, no new raw color/size
   literals outside the token system. Add a scripted check (see QA)
   that enforces this on every file you touch.

## Phase B — Top-of-screen HUD rework

Replace the current raw-text status strip (built from
`scripts/ui/foundation_hud_view_model.gd` `run_status_model`, rendered
in `scripts/ui/foundation_main.gd`) with a designed HUD bar. Keep the
view model as the data source (extend it with structured fields; the
existing text fields may remain for tests/telemetry) but the PLAYER
sees only the following, laid out as one coherent bar with clear
grouping and zero overlapping elements:

1. **Wallet.** A wallet/cash widget showing current money with a coin/
   bill pixel icon — the dominant, most readable element on the bar.
   Gain/loss deltas animate briefly (count-up/down or floating +/-
   chip, reduce-motion: instant swap). In the Grand Casino, chips
   display alongside cash as a visually distinct chip stack, matching
   the existing cash-vs-chips rule.
2. **Heat bar (0–100).** A segmented meter with color bands (cool →
   caution → danger) and tick marks at the thresholds that matter
   (pit-boss/showdown pressure). One glance must answer "how much room
   do I have to cheat?" — the remaining-room portion must be visually
   obvious, not inferred. Delta pulses on change; the bar itself, not a
   number, carries the meaning (exact value on hover/tooltip only).
3. **Drunk bar (0–100).** Same meter language as heat, its own color
   ramp. Pending-drink absorption shows as a ghosted preview segment on
   the bar. Luck and time-scale side effects surface as small icons
   next to the bar (tooltip for exact numbers), never as inline prose.
4. **Status icon tray.** A row of pixel-art status icons that appear
   only when relevant, each with a tooltip: eyes-on-you / pit boss
   watching (from `pit_boss_watch`), high pressure / distressed run
   state, debt active/due, home rent due/overdue, pending drink,
   autosave state. Active icons may pulse gently (reduce-motion:
   static highlighted variant). No icon → nothing is wrong; this is
   how the player reads the room.
5. **Interactive time display.** Replace the raw `[TIME]` text with a
   drawn day/night widget: a sun/moon arc or clock face showing time of
   day visually, plus a compact day indicator (pips or "Day N" chip).
   No raw hour/level numbers by default; hovering or clicking it
   expands the exact time and day plus the drunk time-scale effect if
   active. It advances live with the game clock.

The HUD must hold at 1280×720 and in small-screen mode without
truncating any of the five elements into unreadability (compact
variants allowed; dropping information is not).

## Phase C — Environment header + goal/options section

Rework the environment identity area (currently `[ENV] name / kind`
text plus the `[GOAL] … | …` objective dump):

1. **Environment title graphics.** Each environment gets a unique title
   plate: its icon plus its name rendered in a distinct art/lettering
   style that fits the venue (grimy stencil for the back alley, neon
   script for the jazz club, gaudy gold for the Grand Casino, etc.).
   These are PNG assets at
   `assets/art/ui/environment_titles/<archetype_id>.png` — one per
   environment archetype (enumerate them all from
   `data/`/`RunState`; cover every archetype including rooms like the
   Cage). Artist-swappable per the Phase A pipeline; code-drawn
   fallback renders the name in a styled plate if the PNG is absent.
2. **Environment blurb + options strip.** Replace the goal/todo text
   dump with a compact section that shows (a) a one-line flavor
   description of where you are, and (b) the things you can do here as
   a few-words-each option list (e.g. "Play blackjack · Talk to Marla
   · Buy a drink"), NOT mechanical explanations. Content is
   data-driven per environment (JSON under `data/`, keyed by archetype
   id) so writing can be tuned without code changes. Objective/
   pressure guidance that the current `objective_text` carried must
   remain reachable — distill it to a single short goal line with an
   expandable detail (tooltip or tap-to-expand), environment-aware.

## Phase D — In-environment interaction chrome + cheat dock

1. **Every interactive element** in the environment/game view gets the
   Phase A treatment: clear button shapes with real states, icon
   support, and labels short enough to scan. It must be visually
   obvious what is clickable versus decorative.
2. **Dedicated cheat/distract dock.** Cheat and distraction actions
   move into ONE distinct, consistently-placed UI region with its own
   visual identity (shadier styling than legitimate actions is
   encouraged) so the player always knows: "to cheat or distract, I go
   there." Availability, cooldown, and risk states are visible on the
   dock itself. Shifting or resizing the game environment layout to
   make room is allowed and expected — the hard constraints are: all
   existing actions and functionality remain reachable, nothing
   overlaps, and both screen sizes hold.
3. Wagering, game-surface action buttons, and the talk dock
   (`scripts/ui/talk_dock.gd`) adopt the same system so the whole play
   view reads as one designed screen.

## Phase E — Selection/information popups

Rework every selection popup (events, item offers, services, lenders,
travel, wager confirmation, item-found, etc. — sweep
`scripts/ui/foundation_main.gd`, `environment_interaction_controller.gd`,
`item_found_popup.gd`, `wager_confirmation_controller.gd` and enumerate
the rest from code):

1. **Tight fit.** Panels size themselves to their content: minimal
   empty space, no fixed oversized boxes around three lines of text,
   no overflow/clipping either. Add a shared auto-sizing panel helper
   in the widget kit and use it everywhere.
2. **Decision-grade information only.** Show what the player needs to
   choose — stakes, costs, who's asking, visible risk cues — without
   spelling out the mechanical outcome of each choice. Cut restated
   mechanics and redundant labels.
3. **Icon rework.** Every icon in these popups becomes a designed
   pixel-art sprite per the Phase A quality bar, replacing any rough
   code-drawn icon whose meaning isn't instantly readable. Icons are
   highlightable (hover/selected variant) rather than boxed with text.
4. Consistent popup anatomy across all of them: title zone, content
   zone, choice zone — so every popup is instantly parseable even when
   its content is unique.

## Phase F — Conversation/event popup rework

The conversation/event UI (currently a box of boxes with buttons) is
rebuilt as a living pixel-art conversation:

1. **Conversation frame.** A designed pixel-art dialogue panel with a
   speaker identity zone — pixel portrait or silhouette + name plate
   for the speaker (Rourke, Linda, the Host, patrons, generic staff).
   Author portraits as artist-swappable PNGs
   (`assets/art/ui/portraits/`, in the manifest) with a styled
   fallback for characters without art.
2. **Animated speech.** Dialogue renders with a typewriter/animated
   text reveal so information arrives as speech, not a wall of text.
   Click/tap skips to full text instantly; reduce-motion shows text
   instantly; the reveal is purely presentational and must not affect
   game state, timing-dependent logic, or determinism (action-boundary
   rules unchanged). Long content is broken into sequential beats
   ("next" advances) rather than one dump.
3. **Contextual choice presentation.** Options are styled to the
   conversation — replies/actions phrased and rendered as things you'd
   say or do in that moment, visually distinct by flavor (risky/
   defiant vs. safe/compliant options read differently), NOT a uniform
   stack of grey buttons. The Rourke showdown, patron approaches, and
   ordinary environment events should each feel distinct while sharing
   the same underlying frame.

## Phase G — Menus and remaining screens

Every remaining menu and popup gets a finalized pass — unique,
streamlined to its purpose, self-explanatory to a first-time player:

- **Main menu / start screen:** designed title treatment, clear
  primary action (continue/new run), settings and secondary entries
  quiet. First screen a new player sees — it sets the identity.
- **Sale/pawn window:** not a box of items — a showcase. Selected item
  displayed large with its art, and the offered price presented as a
  visible breakdown (base value, condition/usage wear, dealer's cut or
  environment modifier) so the player SEES why the price is what it
  is, without prose paragraphs.
- **Settings, run inventory, containers/bag reel, world map overlay,
  journal, run report, meta home screens, collection browser, coach
  bubbles:** migrate each to the design system with a layout pass —
  keep what already works (run report tabs precedent), fix hierarchy,
  spacing, iconography, and fit everywhere else. Enumerate every
  surface from `scripts/ui/` and check each off in your report; none
  may ship untouched-and-inconsistent.

## Hard rules (all phases)

- **Identity preserved.** After the overhaul the game reads as "the
  same game, finished" — same neon-pixel brand the store page trades
  on. Before/after captures required for every major surface.
- **Zero gameplay-behavior change.** All changes are presentation and
  layout. Game logic, odds, economy, event outcomes, save format, and
  determinism are untouched. View models may gain structured fields
  but existing outputs/semantics stay intact.
- **All functionality reachable, nothing overlaps.** Layout shifts are
  fine; losing an action or occluding an element is a defect. Verify
  at 1280×720 AND small-screen mode for every surface you touch.
- **Performance.** Zero-copy per-frame rules hold: no per-frame deep
  copies or allocations in HUD/meter/typewriter updates. Idle table
  animations must stay alive — never accept a 0.000 idle-draw number
  without the liveness counter check (this exact regression shipped 4
  times; the guard is mandatory). Perf probe surfaces stay within
  recorded budgets; HUD animations must be dirty-flagged, not
  redraw-everything.
- **Reduce-motion strips motion, never information.** Every animation
  added in this task needs its reduce-motion behavior implemented at
  the same time, not deferred.
- **Web export safe.** No features unavailable in the web build; test
  the web export path if any asset-loading changes are made.
- **Style:** tabs, typed GDScript, sparse comments matching existing
  density. Working captures and scratch output under `.tmp/`; repo
  deliverables (manifest, report) under `docs/plans/`.
- **Suite timeout** = max(300s, ceil(recorded baseline × 1.5)).

## QA / Tests

1. **Suites green** after every phase: every supported
   `-FoundationSuite`, with UI-scene suites extended to cover the new
   widgets (meter bands/thresholds, tooltip content, icon-tray
   visibility rules, typewriter skip + reduce-motion instant path,
   popup auto-size fit, cheat-dock availability states).
2. **Scripted token-adoption check:** files touched by this task
   contain no raw color/size literals outside the token system.
3. **Scripted popup-fit check:** for a representative set of popup
   contents, assert panel size tracks content within a small tolerance
   (no >15% dead space in either axis, no clipping).
4. **Asset pipeline check:** delete (in a temp copy) one environment
   title PNG and one icon PNG; game must fall back cleanly. Manifest
   lists every shipped UI art file (scripted cross-check).
5. **HUD readability check:** at heat 0/35/70/100 and drunk
   0/40/pending states, capture the HUD and verify band colors,
   threshold ticks, and icon-tray contents match expectations
   (scripted where possible, captures for the rest).
6. **Determinism:** run the deterministic replay/QA route before and
   after — identical outcomes. Typewriter and HUD animation must not
   perturb it.
7. **Visual QA route pass** plus before/after capture pairs for: HUD,
   environment header (every environment's title plate), cheat dock,
   one selection popup, conversation popup (mid-typewriter and
   complete), main menu, sale window, and each Phase G screen. Store
   under `.tmp/ui05_captures/`.
8. **Small-screen + reduce-motion pass** across every touched surface.
9. **Cold-look test:** write a one-line "what would a first-time
   player think this is?" note per surface in the report; any surface
   you cannot justify gets another pass before completion.

## Gates (run after every phase; all green before the phase commit)

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_visual_qa.ps1`
- `tools/foundation_performance_probe.ps1 -RequireGodot`

## Deliverables

- All code/asset changes, committed in logical units per phase.
- `docs/plans/0.5_ui_art_manifest.md` — artist handoff for every UI
  art asset (path, dimensions, palette, meaning, swap instructions).
- `docs/plans/0.5_ui_redesign_report.md` — surface-by-surface
  checklist (every surface in `scripts/ui/` accounted for), the
  cold-look notes, capture index, gate results per phase, and any
  intentionally-deferred items with reasons.

## On completion

Delete this prompt file AND
`docs/todo/ui05_0_audit_design_system_prompt.md` in the final commit,
push, and report: per-phase summary, gate results, the report and
manifest paths, and the top remaining polish items (if any) you would
queue next. On an unfixable gate failure: stop at the last green
commit and report the failure verbatim — do not push a red state.
