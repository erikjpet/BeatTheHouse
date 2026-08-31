Status: CLOSED — FALSE PREMISE (owner-side finding, 2026-08-16)

## STOP — do not execute this prompt

**This task was authored on a wrong assumption and its objective was
already satisfied before it was written.** Do not build the renderer
seam it appears to ask for. Read this block, then stop.

Verified against code on 2026-08-16:

1. **No environment in this game renders from a raster.**
   `scripts/ui/pixel_scene_canvas.gd` draws every venue
   procedurally through a `scene_type` dispatch (`_draw_bar`,
   `_draw_underground`, `_draw_jazz_club`, …). There is no
   raster-background load path anywhere in `scripts/ui/`. The
   `visual_context.asset_path` field is metadata the scene canvas
   never consumes.
2. **The Punchline already has three distinct procedural rooms.**
   `_draw_punchline_club()` (line ~1236) and
   `_draw_punchline_back_room()` (line ~1269) exist and are already
   dispatched. The club draws a brick back wall, a stage with mic
   stand and spotlight, a "THE PUNCHLINE" neon, two-drink tables
   with patron silhouettes, and one deliberately unremarkable side
   door — **no gambling signifier**, which was the design point.
3. **Detail is at parity with shipped venues.** Club ≈ 27 lines,
   back room ≈ 22, against `_draw_bar` ≈ 26 and `_draw_underground`
   ≈ 26. It is not a placeholder.

**Therefore the reported blocker is not a defect.** "In-run rendering
uses procedural rooms rather than the registered rasters" describes
the architecture working as designed, for every venue in the game.
The agent was right to refuse to patch the UI seam under this
prompt's ownership rules — that judgment was correct and is the
reason nothing was broken.

**Root cause of the confusion:** `env06_4`'s art-debt note said L1/L3
"reuse the underground raster beneath distinct code-rendered club and
back-room scenes." True but misleading — the reused thing (rasters)
is never rendered, and the thing that is rendered (the code scenes)
was already distinct and complete. This prompt then compounded it by
assuming raster art drives environment visuals. That assumption was
the author's error, not the executing agent's.

**Disposition:**
- Close the board row. No further work.
- `punchline_club.png` and `punchline_back_room.png` are unconsumed
  by the renderer. Keep them: as `visual_context` metadata they are
  strictly more accurate than the previous underground-raster
  pointers, and they are ready if a raster path is ever added. Record
  them as metadata-only so nobody re-litigates this.
- If the procedural Punchline rooms are ever judged visually weak,
  that is a **new, scoped row against the draw functions** — not a
  rendering-architecture change.

## Original prompt below — retained for the record, NOT for execution

---

# Agent Prompt — art06_1: The Punchline's Missing Rooms

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (1280×720, `mobile` / `gl_compatibility` renderer,
2D). Environment art is registered through the art manifest
(`data/art/art_manifest.json`) with archetype `visual_context` entries
in `data/environments/archetypes.json`. Binding design contract:
`docs/plans/0.6_living_world_roadmap.md` — Pillar 3 "The Punchline".

## Why this task exists

`env06_4` shipped the Punchline as a three-layer venue and logged its
own art debt on the board:

> L1 and L3 ship with registered art-manifest slots that currently
> reuse the underground raster beneath distinct code-rendered club
> and back-room scenes. Dedicated final raster art remains an asset
> need.

So the flagship new venue of 0.6 — a comedy club hiding a casino
hiding a crew back room — currently looks like the old underground
casino on two of its three floors. The joke does not land if the
cover does not read as a cover.

## Board protocol

1. Before work: set row `art06_1` to `IN_PROGRESS` with agent + date,
   append a Work Log line, commit the claim. If not `TODO`, stop.
2. Log discoveries/deviations tagged `[art06_1]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`.

## Concurrency

Runs alongside the coin pusher and crew waves. **Ownership:** you own
new asset files and their art-manifest entries, plus the Punchline's
`visual_context` asset paths in `archetypes.json`. You do not change
layer logic, discovery gating, scenario data, layouts, or any game
module. Layer L3's furniture is owned by the crew wave (`crew06_6`) —
you provide the room, not its contents.

## Task

### 1. Layer 1 — the comedy club (street level, public)

The room a stranger sees, and the reason the law walks past. It must
read as a *legitimate, slightly desperate* comedy club — not as a
casino with jokes:

- a small stage with a stool, a mic stand, and a brick-ish back wall
- cheap seating, two-drink-minimum table clutter
- a bar along one side, a door that is obviously just a door
- warm, cheap lighting; the room should feel under-attended

Nothing in this frame may hint at gambling. That is the entire
design point.

### 2. Layer 3 — the back room (crew only)

The one room in town where nobody is watching. Private, lived-in,
and not decorated for guests:

- a planning table with chairs that do not match
- a job board / pinned wall, a counting corner, crates
- low, warm, close lighting — the opposite of the casino's hush
- must accommodate crew06_6's furniture spots (poker table, Numbers
  desk, planning table, Practice Rig) without visually fighting them;
  read the landed layout in `archetypes.json` before composing, and
  leave those spots clear.

### 3. Integration

- Register both through `data/art/art_manifest.json` following the
  conventions the existing environment art uses; replace the
  underground-raster reuse in the Punchline's L1 and L3
  `visual_context` entries.
- Layer 2 (the casino) keeps the existing underground art — it *is*
  the underground. Do not touch it.
- Match the established environment art direction: same perspective
  conventions, same palette discipline, same resolution and framing
  as the shipped venues. Study two or three existing environment
  assets first and match them; a correct-but-off-style room is a
  regression.
- Respect the renderer: `mobile`/`gl_compatibility`, 2D, no new
  shader or lighting systems, no transparency-heavy effects.

## Hard rules

- Assets and manifest/`visual_context` wiring only. No layer logic,
  no layout changes, no scenario data, no game modules.
- The three layers must be visually distinguishable at a glance —
  that is the acceptance test.
- Scenario presentation overlays (palette tint, crowd density,
  signage) still apply on top of your art; compose so those overlays
  read correctly rather than fighting them.
- Style: `.tmp/` reports; suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Art manifest validation green; no missing or dangling asset refs.
2. All three layers render at 1280×720 with no overlap, clipping, or
   layout collision — including with crew06_6's L3 furniture spots
   reserved.
3. L1 contains no gambling signifier (visual audit, stated in report).
4. Scenario overlays (e.g. Open Mic vs Headliner on L1) read
   correctly over the new art.
5. Captures of all three layers side by side in `.tmp/` — the
   glance test.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_visual_qa.ps1`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: assets produced, manifest wiring, the three-layer glance-test
captures, and gate results. If you cannot produce art that matches
the established direction, say so plainly and leave the placeholders
in place rather than shipping a style regression. On an unfixable
gate failure: stop at the last green commit, set `BLOCKED`, report
verbatim.
