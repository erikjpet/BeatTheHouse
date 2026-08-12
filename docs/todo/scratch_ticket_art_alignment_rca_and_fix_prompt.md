# Scratch Ticket Art Alignment — Root Cause Analysis + Fix Prompt

**Status:** analysed 2026-08-11, NOT fixed. Everything below is diagnosis and a
plan; no gameplay code was changed. The only file added was the read-only
diagnostic `tools/scratch_ticket_alignment_audit.py`.

**Symptom (owner report):** the reveal icons/numbers are not inside the circles
and boxes printed on the ticket. Confirmed on Bonus Bingo in-game; reproduced
offline on **all seven** ticket types.

---

## Part 1 — Root Cause Analysis

### 1.0 How a ticket is drawn

`scripts/games/scratch_tickets.gd:1613-1626` draws three layers into one shared
`render_rect`:

```gdscript
var render_rect := active_ticket_rect
BackgroundRendererScript.draw(surface, ticket, render_rect)   # printed face (PNG)
IconRendererScript.draw(surface, ticket, render_rect)          # result icons
FoilRendererScript.draw(surface, ticket, render_rect, state)   # scratch coating
```

- **Layer 1** is a single raster: `ScratchTicketBackgroundRenderer.draw()` does
  `surface.draw_texture_rect(background, ticket_rect, false)`. The circles and
  boxes the player sees are **pixels baked into that PNG**.
- **Layers 2 and 3** position themselves from `ScratchTicketRegionModel.build()`
  — a table of **hand-typed normalized rects** in
  `scripts/games/scratch_ticket_region_model.gd:11-69`.
- `render_rect` comes from `_ticket_rect_for_size()`
  (`scratch_tickets.gd:2299-2306`), one of four fixed pixel sizes.

So the printed geometry lives in a PNG and the interactive geometry lives in
GDScript literals, and **nothing connects them**.

### 1.1 RC-1 (primary) — there is no source of truth linking art to rects

The shipped backgrounds `*_background_pro.png` were committed in `b7a3a2bb`
("Rebuild scratch tickets as a professional three-layer experience") as 2.4–3.3 MB
externally-authored raster images. **No generator in the repo produces them.**

The repo does contain `tools/generate_scratch_ticket_art.py`, whose docstring
states the contract explicitly:

> "The layout constants below mirror ScratchTickets._ticket_art_regions. If those
> GDScript regions change, update this file in the same commit so the artwork and
> mechanics continue to agree 1:1."

That contract is dead three ways over:

1. It writes `{id}_background_v2.png`; the game loads `{id}_background_pro.png`
   (`scratch_ticket_background_renderer.gd:5-11`). The tool's output is unused.
2. `ScratchTickets._ticket_art_regions` no longer exists — it was deleted in the
   same rebuild that added the `_pro` art.
3. Its rect table and the GDScript rect table **disagree with each other**, and
   both disagree with the shipped art. Lucky 7s "YOUR" column pitch:

   | source | pitch |
   |---|---|
   | `tools/generate_scratch_ticket_art.py:293` | `0.180` |
   | `scratch_ticket_region_model.gd:23` | `0.205` |
   | measured on `lucky_7s_background_pro.png` | `0.2103`, then `0.2237` |

`LAYOUT_VERSION := 8` (`scratch_ticket_region_model.gd:4`) is the tell: eight
rounds of eyeball-tuning constants against a picture nobody measured.

### 1.2 RC-2 — uniform-pitch formulas against non-uniform painted art

Every region is generated as `origin + index * pitch`. The `_pro` art was not
laid out by a machine, so its printed wells are **not** evenly spaced. Measured
column pitch of the 12 Bonus Bingo caller circles:

```
0.0554  0.0563  0.0557  0.0560  0.0560  0.0567  0.0563  0.0608  0.0567  0.0560  0.0522
```

The code uses a single `0.058`. **No single pitch value can fit this** — the art
itself is irregular (note the 0.0608 and 0.0522 outliers). Any fix that keeps a
formula will still be wrong at some wells. Same story on Lucky 7s (0.2103 then
0.2237) and Tic Tac Gold (printed cell widths 0.1462 / 0.1519 / 0.1548 — the
three columns are not even the same size).

### 1.3 RC-3 — the art is anisotropically stretched into the ticket rect

`draw_texture_rect` does not preserve aspect ratio, and three ticket types are
drawn into a rect whose aspect does not match their art:

| ticket | art px | art AR | on-screen rect | screen AR | horizontal stretch |
|---|---|---|---|---|---|
| two_fer | 1872×840 | 2.2286 | 500×224 | 2.2321 | 1.002× |
| **lucky_7s** | 1053×1494 | 0.7048 | 354×356 | 0.9944 | **1.411×** |
| **tic_tac_gold** | 1053×1494 | 0.7048 | 354×356 | 0.9944 | **1.411×** |
| crossword_corner | 1556×1011 | 1.5391 | 548×356 | 1.5393 | 1.000× |
| bonus_bingo | 1553×1013 | 1.5331 | 548×356 | 1.5393 | 1.004× |
| high_roller_holdem | 1122×1402 | 0.8003 | 292×366 | 0.7978 | 0.997× |
| **golden_vault** | 1000×1573 | 0.6357 | 292×366 | 0.7978 | **1.255×** |

Normalized coordinates survive a linear stretch, so this alone does not
translate a rect. It does three other damaging things:

- **(a)** Printed circles become **ellipses** on screen. A Lucky 7s well is a
  true 145×145-art-pixel circle that reaches the player as 48.7 × 35.0 px.
- **(b)** It breaks icon sizing. `_paint_symbol_texture` sizes an icon by
  `minf(rect.size.x, rect.size.y)`; after a 1.41× x-stretch the short side is
  always vertical, so the icon collapses to the well's *height* and under-fills
  its *width*. Lucky 7s: a 33.6 px square icon inside a 48.7 px-wide printed
  oval — **69 % coverage**, which reads as "the number isn't in the circle".
- **(c)** It makes eyeball-tuning unreliable, which is how the rects drifted in
  the first place.

### 1.4 RC-4 — icons are drawn as offset squares, not as the region

`scratch_ticket_icon_renderer.gd:169-175`:

```gdscript
var side := minf(rect.size.x, rect.size.y) * scale
var center := rect.get_center() + Vector2(0, rect.size.y * y_offset_ratio)
surface.draw_texture_rect(texture, Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), false)
```

Three problems compound:

- **forced square** regardless of the printed well's shape;
- a **hard-coded vertical offset** that deliberately moves the icon off the
  region centre: `-0.05` (two_fer, line 88), `-0.04` / `-0.12` (lucky_7s, line
  96), `-0.02` (tic_miss, line 115);
- magic `scale` values from `0.74` to `1.04` with no relationship to the
  printed well.

The `1.04` case is the one in the owner's screenshot. Bonus Bingo:
`_paint_bingo_number` (line 132) draws `bingo_ball` at
`min(20.8, 17.8) * 1.04 = 18.5 px` over a printed circle that is **14.1 px**.
The drawn ball is **31 % larger than the print** and eclipses it; where the rect
has also drifted, the printed ring survives as a crescent on one side. That
crescent is exactly what is visible on the caller row in the screenshot.

### 1.5 RC-5 — text is centred in sub-rects, not on the well

`_paint_lucky_number` (`scratch_ticket_icon_renderer.gd:97-102`) for any spot
carrying a `prize` (i.e. every "YOUR" number) does:

```gdscript
var number_rect := Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.72))
surface.surface_label_centered(str(number), number_rect, ...)
```

The digit is centred in the **top 72 %** of the region, so its centre sits at
36 % of the region height — **≈5.2 px above the printed oval's centre in a
35 px-tall oval (≈15 %)**. The prize text below it starts at `y + 0.69h` with
height `0.28h`, reaching 97 % of the region, i.e. past the printed rim.
`_paint_tic_mark` (line 116) does the same thing with a `0.74h` band.

This stacks on top of the RC-2 rect drift; the two are independent.

### 1.6 RC-6 — measured error, per ticket

Centre error and size error, converted to **on-screen pixels** at the real
ticket rect. `printed W×H` is the size of the well the player actually sees;
`icon sq` is the square `_paint_symbol_texture` would paint into it.

**bonus_bingo** — 548×356 ticket, printed caller circle 14.1 × 14.1 px:

| region | ΔcX px | ΔcY px | ΔW px | ΔH px | icon sq |
|---|---|---|---|---|---|
| CALL 1 | +0.82 | −1.00 | +6.69 | +3.70 | 16.0 |
| CALL 6 | +6.58 | −1.00 | +6.69 | +3.70 | 16.0 |
| CALL 9 | +6.69 | −1.00 | +6.69 | +3.70 | 16.0 |
| **CALL 12** | **+11.67** | −1.00 | +6.69 | +3.70 | 16.0 |

The drift accumulates left-to-right and reaches **11.7 px — 83 % of a circle
diameter** — by the twelfth column. Row 2 is identical. The region box is also
47 % too wide and 25 % too tall.

**lucky_7s** — 354×356 ticket, printed oval ≈48.6 × 35.1 px:

| region | ΔcX px | ΔcY px | ΔW px | ΔH px | icon sq |
|---|---|---|---|---|---|
| WIN 1 | +3.66 | −1.92 | +2.58 | +2.35 | 33.6 |
| YOUR 1 | +1.70 | −1.00 | +2.90 | +2.35 | 33.6 |
| YOUR 2 | −0.19 | −0.87 | +2.58 | +2.60 | 33.6 |
| **YOUR 3** | **−6.80** | −1.00 | +2.90 | +2.35 | 33.6 |
| BONUS | +2.07 | +2.99 | +0.04 | **+12.67** | 41.7 |

The third column is 6.8 px left of its printed oval, and the BONUS region is
12.7 px taller than the printed well. On top of that, the digit is drawn a
further ~5.2 px high (RC-5) and the coin is 69 % of the oval's width (RC-3b).

**tic_tac_gold** — 354×356 ticket, printed cell ≈53 × 32 px:

| region | ΔcX px | ΔcY px | ΔW px | ΔH px |
|---|---|---|---|---|
| GRID 1 | +1.95 | +2.71 | +11.97 | +5.20 |
| GRID 5 | +2.92 | +3.03 | +9.95 | +5.20 |
| GRID 9 | +3.04 | +3.45 | +8.92 | +4.98 |

Every region is 9–12 px too wide and ~5 px too tall, and sits 2–3 px down-right.
The printed columns are not even equal width (0.1462 / 0.1519 / 0.1548), which
the single `0.18` in code cannot express.

**golden_vault** — 292×366 ticket, printed rung 13.7 px tall:

| region | ΔcX px | ΔcY px | ΔW px | ΔH px |
|---|---|---|---|---|
| RUNG 1 | +0.44 | +0.71 | +11.39 | +1.79 |
| RUNG 3 | +0.44 | +2.84 | +11.39 | +2.01 |
| **RUNG 5** | +0.44 | **+5.07** | +11.39 | +2.01 |

Vertical drift reaches **5.07 px on a 13.7 px rung — 37 % of a rung height**,
so the bottom rung's text lands in the gap between two printed rungs.

**high_roller_holdem** is the best of the set (worst centre error 2.18 px) but
still 7–9 px too wide and 5–7 px too tall per card.

**two_fer** centres are close (worst ≈6.3 px on SPOT 3; printed pitch 0.2818 vs
coded 0.292), but the symbol square is `min(112.5, 50.4) × 0.8 = 40 px` inside a
105 × 47 px printed well — it floats in the middle of a wide box.

**crossword_corner** is the worst case and is not merely misaligned. The
GDScript grid `(0.06, 0.32, 0.50, 0.48)` and bank `(0.585, 0.42, 0.378, 0.37)`
disagree with the python tool's `(0.06, 0.35, 0.50, 0.50)` / `(0.62, 0.38, 0.31,
0.44)` **and** with the printed grid, whose lines land roughly half a cell away.
Worse, the cream "word" cells painted into the art do **not** correspond to
`CROSSWORD_ENTRIES` (`generate_scratch_ticket_art.py:47-55`). The printed puzzle
and the mechanical puzzle are different puzzles. Aligning rects will not fix
this one; see Phase 5.

### 1.7 RC-7 — the one guard in CI asserts the wrong invariant

`scratch_ticket_region_model.gd:104` stores `"art_rect": rect.duplicate(false)`
— a slot for "where the printed art actually is", initialised to a copy of the
mechanic rect. `scripts/tests/foundation/check_scratch_tickets.gd:391-393` then
**fails the build if they ever differ**:

```gdscript
var art_rect: Array = (regions[region_index] as Dictionary).get("art_rect", [])
if JSON.stringify(art_rect) != JSON.stringify(values):
    failures.append("Scratch %s region/art rectangle drifted at box %d." % [type_id, region_index])
```

That check is backwards. It locks the art rect to the mechanic rect, which is
precisely the decoupling a fix needs. Of the **157 assertions** in that suite,
**none** compares any region against the background texture — the check at line
178 verifies the layer *names* are `["background", "icons", "foil"]` and nothing
about where those layers land. The drift is therefore invisible to CI, which is
why eight `LAYOUT_VERSION` bumps never converged.

### 1.8 RC-8 — the same rects also misplace the foil and the hit-testing

The bug is not cosmetic-only. `ScratchTicketFoilRenderer._paint_region_mask`
(`scratch_ticket_foil_renderer.gd:39-46`) and `ScratchTicketMask` rasterize from
the **same** `region["rect"]`. Consequences:

- The coating covers the wrong area: the player scratches paper where there is
  no printed well, and a crescent of the printed well stays coated.
- `_sample_inside_region` (`scratch_ticket_mask.gd:301-313`) only applies an
  ellipse mask when `mask_shape == "ellipse"`, which the region model sets for
  **lucky_7s only** (`region_model.gd:20,23`). Bonus Bingo's printed circles are
  built as `"rect"`, so a square foil patch sits over a round print.
- The mask is a uniform 256×192 grid over the ticket rect
  (`scratch_ticket_mask.gd:5-6`), so foil edges quantize to ~2.1 × 1.9 px on a
  548×356 ticket — a further ±2 px on top of the drift. Minor, but it means
  "pixel-perfect" is not achievable without accounting for it.
- `_paint_validation_result` (`icon_renderer.gd:54-57`) uses yet another
  hard-coded rect `(0.31, 0.902, 0.38, 0.068)` unrelated to any art feature. On
  Bonus Bingo the "NOT A WINNER" stamp lands across the printed rules band —
  visible in the owner's screenshot.

### 1.9 Causal summary

```
externally-authored _pro art (no generator, irregular hand/AI layout)
        │
        ├── nothing measures it ──────────────► RC-1 no source of truth
        │                                        └─ RC-7 CI asserts art_rect == rect
        │                                           (locks the two together)
        │
        ├── rects re-derived as origin+i*pitch ► RC-2 drift accumulates
        │                                        (11.7 px on bingo, 5.1 px on vault)
        │
        └── stretched to a mismatched aspect ──► RC-3 circles become ellipses
                                                 └─ RC-3b min()-sized icons under-fill
                                                    └─ RC-4 square icons + magic y-offsets
                                                       └─ RC-5 text in 72 %/74 % sub-rects
                                                          └─ RC-6 icon larger than the print
```

The visible defect is the **sum** of five independent errors, each a few pixels.
Fixing only the rects will improve it and still look wrong.

---

## Part 2 — Fix Prompt (for the executing agent)

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (900×430 board, immediate-mode canvas surfaces, seeded RNG). Read
Part 1 above in full before writing any code. Do not skim it — every phase below
targets a specific numbered root cause and the acceptance gates reference the
measurements in §1.6.

**Ground rules**
- Do not commit or push, ever, unless the owner explicitly asks in this session.
  Prepare every change on disk and report what you changed. This is a hard rule.
- This prompt is self-contained. There is no queue, no claim/archive ceremony,
  and no CLAUDE.md. Everything you need is in this file or in the repo.
- Do not regenerate or repaint `*_background_pro.png`. The art is the fixed
  reference; the code moves to meet it. (Exception: Phase 5, crossword only,
  and only after checking in.)
- `tools/generate_scratch_ticket_art.py` is dead code for the shipped art. Do
  not "fix" its constants — either delete it or clearly mark it as producing the
  unused `_v2` set. Decide and say which.
- Preserve odds, payouts, RTP and all mechanics. This is a geometry fix only.
- `python tools/scratch_ticket_alignment_audit.py` is a read-only diagnostic
  already in the repo. Use it throughout; extend it as needed.

### Phase 1 — Make the printed geometry the source of truth

Replace the formula-generated rects with a **measured, per-well table**. A
formula cannot work (RC-2: the printed pitch is irregular by construction).

1. Extend `tools/scratch_ticket_alignment_audit.py` into a **generator** that
   detects every printed well in each `_pro` PNG and emits
   `data/games/scratch_ticket_regions.json`:

   ```json
   {
     "layout_version": 9,
     "source_art": {"lucky_7s": {"file": "lucky_7s_background_pro.png", "w": 1053, "h": 1494, "sha256": "..."}},
     "regions": {
       "lucky_7s": [
         {"id": "winning_numbers_00", "shape": "ellipse", "art_rect": [0.0883, 0.4337, 0.1377, 0.0984]}
       ]
     }
   }
   ```

   `art_rect` is the measured **printed well**, normalized to the art's own
   pixel dimensions. Record the art `sha256` so a later art swap invalidates the
   table loudly instead of silently.
2. The detectors in `DETECT` are tuned for five ticket types. You must tune
   `two_fer` and `crossword_corner` as well, and hand-verify all seven against
   the overlays. Where a detector cannot isolate a well reliably, measure it by
   hand and record it — a correct hand-measured number beats a clever detector.
3. `ScratchTicketRegionModel.build()` becomes a **loader**: read the table, pair
   each entry with its spot by index, and drop every hardcoded rect literal and
   every `CROSSWORD_*` constant from the script. Keep `build()`'s signature and
   the returned dictionary's keys so `ScratchTicketMask` and the renderers are
   unaffected. Bump `LAYOUT_VERSION` to 9 — `ScratchTicketMask.ensure()` already
   rebuilds masks on a version change and preserves per-region progress
   (`scratch_ticket_mask.gd:40-60`), so in-flight saves migrate for free.
   **Verify that migration path explicitly**, it is the one save-compat risk here.

**Gate:** no numeric rect literal remains in
`scripts/games/scratch_ticket_region_model.gd`.

### Phase 2 — Give all three layers one undistorted coordinate space

Fixes RC-3. Do **not** change `_ticket_rect_for_size`'s four sizes (they are
asserted in `check_scratch_tickets.gd:739-741` and drive board layout).

Add a contain-fit helper — art aspect preserved, centred inside the ticket rect:

```gdscript
static func art_frame(ticket_rect: Rect2, art_size: Vector2) -> Rect2:
    var scale := minf(ticket_rect.size.x / art_size.x, ticket_rect.size.y / art_size.y)
    var fitted := art_size * scale
    return Rect2(ticket_rect.get_center() - fitted * 0.5, fitted)
```

Compute it **once** at `scratch_tickets.gd:1613` and pass the same frame to all
three renderers (they already share `render_rect`, so this is a one-line change
at the call site plus the helper). Route `ScratchTicketMask`'s rasterization and
the pointer hit-testing (`scratch_tickets.gd:438`, `:1631`) through the same
frame — otherwise scratching lands where the art no longer is.

Note the frame is smaller than the ticket rect for lucky_7s / tic_tac_gold
(354×356 → 251×356) and golden_vault (292×366 → 233×366). Confirm the ticket
still reads well at that size and that the surrounding board furniture (discard
basket, "CLICK TO FILE" badge, `_paint_validation_result` stamp) still lines up;
adjust the badge/stamp anchors to the frame, not the ticket rect.

**Gate:** for every ticket, `art_frame` aspect equals the source PNG aspect to
within 0.5 %. Printed circles are circles on screen.

### Phase 3 — Draw icons as the region, not as an offset square

Fixes RC-4, RC-5, RC-6.

1. Rewrite `_paint_symbol_texture` to fill the region rect honouring the
   texture's own aspect, with **no `y_offset_ratio` parameter**. Once the rect
   *is* the printed well, every offset must be zero by construction. Delete the
   `-0.05` / `-0.04` / `-0.12` / `-0.02` call sites.
2. Replace the magic `scale` values with **one** constant inset (the printed
   well already includes its own padding; ~0.92 of the well is a reasonable
   start) and justify whatever you pick in a comment.
3. Cap every icon at the printed well: a drawn icon must never exceed its
   `art_rect`. The `1.04` values at `icon_renderer.gd:132,153,163,166` currently
   violate this and produce the Bonus Bingo crescent.
4. `_paint_lucky_number` and `_paint_tic_mark` must centre their primary glyph
   on the **region centre**. If a well genuinely has a two-line print (number
   above, prize below), encode that split as two sub-rects **in the data table**
   measured from the art — never as a `0.72` literal in the renderer.
5. Fix `_paint_validation_result`'s hard-coded `(0.31, 0.902, 0.38, 0.068)`:
   anchor it to the art frame, or measure a printed stamp area into the table.

### Phase 4 — Match the foil to the printed well shape

Fixes RC-8. Carry `shape` from the table into `region["mask_shape"]` so Bonus
Bingo's 24 caller circles and any other round well get `"ellipse"`, not just
lucky_7s. `_sample_inside_region` already handles it
(`scratch_ticket_mask.gd:301-313`) — it is only ever fed `"rect"`. Verify the
foil fully covers each printed well before scratching and leaves no residue ring
after, at the 256×192 mask granularity (~2 px). If a 2 px residue is visible,
grow the foil rect by one mask cell relative to `art_rect` — the foil may
over-cover, the icon may not.

### Phase 5 — crossword_corner (check in with the owner first)

Alignment alone cannot fix this one: the printed word cells do not correspond to
`CROSSWORD_ENTRIES`, so the printed puzzle and the mechanical puzzle differ
(§1.6). Present the owner with the options and their cost before doing any work:

- **(a)** Read the printed grid out of the art and rebuild `CROSSWORD_ENTRIES`
  and the word list to match what is drawn. Keeps the art; changes the puzzle
  content and needs an RTP re-check.
- **(b)** Repaint only `crossword_corner_background_pro.png` from the mechanical
  grid. Keeps the puzzle; needs art work matching the other six tickets' quality.
- **(c)** Ship the other six aligned and hold crossword.

Do not choose unilaterally.

### Phase 6 — Make the alignment testable so it cannot regress again

Fixes RC-7. This is the phase that decides whether this is fixed for good or for
one more `LAYOUT_VERSION`.

1. **Delete or invert the check at `check_scratch_tickets.gd:391-393.`** It
   currently fails when `art_rect != rect`, which forbids the entire fix.
   Replace it with: every region's `rect` derives from its `art_rect` by a
   declared, bounded inset/outset.
2. Add a GDScript foundation check that loads
   `data/games/scratch_ticket_regions.json`, verifies each entry's `source_art`
   sha256 against the actual texture, and fails if the art changed without the
   table being regenerated. This is the guard that makes the source-of-truth real.
3. Add a python audit mode `--verify` that recomputes printed-well geometry from
   the art and fails non-zero if any region centre is more than **1.0 px**
   (on-screen) from its printed well or any region's size differs by more than
   **5 %**. Wire it into whatever runs `tools/*.ps1` locally.
4. Regenerate the three-state review sheet
   (`docs/screenshots/scratch_ticket_three_state_review/`) and check every
   ticket by eye at 1× — the numbers can pass while the result still reads wrong.

### How to validate

Godot 4.6 GDScript, Windows, PowerShell. The scratch suite is the tight loop;
run it after every phase:

```bash
pwsh -File tools/check_godot.ps1 -Suite Contract -FoundationSuite scratch_tickets -RequireGodot
```

Before reporting done, run the full gate — this fix touches the mask, the
renderers and the hit-testing, so a green scratch suite alone is not enough:

```bash
pwsh -File tools/check_godot.ps1 -Suite Full -RequireGodot
```

The python diagnostic needs `pillow`, `numpy`, `scipy`:

```bash
python tools/scratch_ticket_alignment_audit.py --overlay --measure
```

Known-red baseline you did **not** cause and must not chase: the
`foundation_performance_probe` slot-autoplay failures are long-standing. If a
suite is already red on a clean checkout, say so and carry on; do not "fix" it
inside this task. Report any test you could not run and why.

### Acceptance

- `python tools/scratch_ticket_alignment_audit.py --verify` exits 0 for all
  seven types (or six, if the owner picks 5c).
- Worst-case centre error drops from **11.67 px → ≤1.0 px** (bonus_bingo CALL 12),
  and every figure in the §1.6 tables is re-measured and reported after the fix.
- Overlay images show magenta region boxes concentric with the printed wells and
  cyan icon boxes filling them.
- Foil fully covers each printed well pre-scratch, no residue post-scratch.
- `scripts/tests/foundation/check_scratch_tickets.gd` passes, with the
  `art_rect == rect` assertion replaced rather than deleted-and-forgotten.
- A ticket in flight across the `LAYOUT_VERSION` 8→9 bump migrates without
  losing scratch progress or changing its outcome.
- Report the measured before/after table in your summary. Do not report "looks
  better" — report pixels.

### Files in scope

| file | why |
|---|---|
| `scripts/games/scratch_ticket_region_model.gd` | rect literals → data loader (Phase 1) |
| `scripts/games/scratch_tickets.gd:1613-1631, 2299-2306` | art frame, hit-testing (Phase 2) |
| `scripts/games/scratch_ticket_background_renderer.gd` | draw into the art frame (Phase 2) |
| `scripts/games/scratch_ticket_icon_renderer.gd` | icon geometry, text rects, stamp (Phase 3) |
| `scripts/games/scratch_ticket_foil_renderer.gd` | foil follows region shape (Phase 4) |
| `scripts/games/scratch_ticket_mask.gd` | rasterize in art frame, ellipse shapes (Phase 2/4) |
| `scripts/tests/foundation/check_scratch_tickets.gd:391-393` | invert the backwards guard (Phase 6) |
| `tools/scratch_ticket_alignment_audit.py` | extend to generator + `--verify` (Phase 1/6) |
| `data/games/scratch_ticket_regions.json` | **new** — the source of truth (Phase 1) |
| `tools/generate_scratch_ticket_art.py` | dead for `_pro` art — delete or mark |

### Reference artifacts

Overlay images for all seven tickets (magenta = region rect, cyan = icon square,
rendered at the exact on-screen ticket size, 3× nearest-neighbour):
`.tmp/scratch_alignment_audit/overlay_*.png`. Regenerate with:

```bash
python tools/scratch_ticket_alignment_audit.py --overlay --measure
```
