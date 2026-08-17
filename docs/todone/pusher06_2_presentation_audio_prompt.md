Status: DONE
Board row: `pusher06_2` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** 2026-08-17
- **Completion/implementation commits:** `f70bb326..9bbdd037` (dense snapshot-driven presentation, strict presentation seam, audio/tell delivery, native deterministic solver and export support, output-identical shipped-cap performance work, packed-trace regression coverage, and Web-safe trace-row ownership).
- **Verification:** Current-HEAD supported gates all pass: Systems (`.tmp/test_reports/20260817_pusher06_2_postfix_systems_retry/summary.json`, 49 checks/4 shards), UI (`.tmp/test_reports/20260817_pusher06_2_postfix_ui_retry/summary.json`), Contracts (`.tmp/test_reports/20260817_pusher06_2_postfix_contracts_retry/summary.json`, 10/10), and Coin Pusher (`.tmp/test_reports/20260817_pusher06_2_postfix_coin_pusher/summary.json`), each with zero failures/stderr issues. Ten-seed determinism produced 590 byte-identical checkpoints and hash `1022775515`; visual QA passed. Shipped-cap performance report `.tmp/test_reports/20260817_pusher06_2_postfix_performance/foundation_performance_probe_report.json` passes: Drop resolve 15.798 ms, collapse Nudge 14.820 ms, raw native p95 10.276 ms, draw p95 4.249/4.090 ms, frame p95 6.923/6.922 ms, 14 replay frames, zero full snapshots. Exact 200-action Windows/Web release parity passes with input `1941cd44...c992`, outcomes `8826fed6...b9a`, backend `5ea048d3...1af`, final captured frame `a5331a9a...950a`, and 200/200 native actions. Fresh Windows/Web itch exports and package inventories pass with no saves/debug/development material and byte-identical source/output/archive native modules. Seven required feel captures plus five advancing replay sheets and five tell stages pass at `.tmp/pusher06_2_final_feel_captures`; independent visual review says the dense, stacked, hanging field now reads unmistakably as a real coin pusher. Additional global Web diagnostics were preserved without weakening budgets: Grand Casino gameplay scenarios pass but cold startup was 13 ms over its 20 s budget; `l02` also reported unrelated startup/Corner Store/Blackjack baseline misses.
- **Deviations:** Shipped `coin_cap=160` with a 150-coin uneven opening pile, the densest target sustained inside all binding action/draw/frame budgets. An exact transactional native packed core and owned packed-trace rows preserve the synchronous 48-tick/14-frame result while meeting the budget and preventing Web pointer lifetime faults. No outcome, feature, animation, audio, render, replay, or budget reduction; no owner-locked design change.

# Agent Prompt — pusher06_2: Presentation + Audio (the feel pass)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (`mobile` / `gl_compatibility` renderer, GDScript-
drawn 2D surfaces). Binding design contract:
`docs/plans/0.6_coin_pusher_simulation_plan.md` — sections 2 and 5.

## What this task is

`rework06_2` made the machine *true*. This task makes it *look and
sound* true. The physics is already authoritative; nothing here may
change an outcome. This is density, presentation, and sound.

### The specific defect this task exists to fix (owner-verified)

The solver is genuinely simulating: the feel captures print
`PHYSICAL PROOF collisions N moved N topples N` and the numbers are
real. **But the machine does not look like a coin pusher.** Inspected
evidence from `.tmp/rework06_2_feel_captures/`:

- `coin_cap` is **48** across **5 lanes** — roughly ten coins per
  lane. The playfield renders as a sparse scatter of isolated dots
  with large gaps between them.
- Stacking is simulated but **not legible**: you cannot see coins
  resting on coins.
- Edge hangers are tracked but **not visually readable** as coins
  hanging over the ledge.
- The lane grid dominates the composition, so it reads as "tokens in
  columns" rather than a mass of loose change.

The owner's requirement, verbatim: *"it should appear like a row of
coins pushing each other with random placement. it should have
stacked coins, coins hanging off the edge, all represented through a
complex coin pusher simulation."*

The simulation already supports every one of those. **The gap is coin
density and rendering, and closing it is the point of this task.**
A real cabinet shows a packed, overlapping, uneven field of coins —
not a countable set of markers.

## The architectural rule that matters most

**Publish a renderer-agnostic snapshot and consume only that.**

The simulation exposes a pure data snapshot — coin positions, layers,
motion state, and discrete events (impact, slide, ledge-tip, tray
landing, gutter loss, topple, cabinet shake). The 2.5D renderer and
the audio layer consume that snapshot and nothing else. No renderer
code reaches into solver internals; no solver code knows a renderer
exists.

This boundary is what keeps a future 3D presentation a *rendering*
project rather than a gameplay rewrite (plan section 2). Honor it
strictly even where a shortcut would be easier — a violation here
silently forecloses the owner's 3D option.

## Board protocol

1. Before work: set row `pusher06_2` to `IN_PROGRESS` with agent +
   date, append a Work Log line, commit the claim. If not `TODO`,
   stop.
2. Log discoveries/deviations tagged `[pusher06_2]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move to `docs/todone/`; Work Log naming `pusher06_3`
   unblocked.

## Dependencies

`pusher06_1` DONE. Verify the snapshot/event API by code before
building against it; if it does not yet exist as a clean boundary,
establishing it is part of this task.

## Task

### 0. Coin density — do this first, it gates everything else

- Raise `coin_cap` from 48 toward a **visually dense field**. Target
  150–300 coins per cabinet; the exact number is whatever the
  performance budget sustains (see Hard rules). Report the number you
  land on and why.
- Retune the opening pile so a machine the player walks up to is
  **already loaded and uneven** — packed near the pusher, thinning
  toward the ledge, with genuine randomness in placement rather than
  lane-aligned spacing.
- Coins must visually **overlap and touch**. Adjust rendered coin
  radius, playfield scale, and spawn jitter so the field reads as a
  mass of loose change. If coins never touch on screen, the density
  is still wrong regardless of the count.
- De-emphasize the lane grid so it guides aim without dominating the
  composition — the coins are the picture, the lanes are a hint.
- Performance is the constraint that sets the cap. Per the plan, when
  budget is tight the answer is a lower cap with the number reported
  — **never** re-abstracting the pile back into counters.

### 1. The 2.5D render

- Draw the cabinet in perspective: upper shelf, lower field, ledge,
  tray, gutters, glass, and the sweeping plate — with the plate's
  cycle phase unmistakably readable, because drop timing is the core
  skill and the player must be able to read it without a UI meter.
- Render coins from the snapshot with batched drawing (no per-coin
  node overhead). Depth ordering must make stacking legible: the
  player should be able to see that a pile is leaning, that a coin is
  hanging over the ledge, and roughly how deep the pile is.
- Interpolate between fixed solver steps for smooth motion; never let
  interpolation feed back into simulation state.
- Prize riders, feature pucks, and key fragments render as distinct
  physical objects (their variations arrive in `pusher06_3`; render
  support belongs here).
- Idle attract state animates within the animated idle draw budget
  **with its liveness counter present** — a 0.000 idle number without
  the counter is an automatic FAIL in this project.

### 2. The audio layer (load-bearing)

Drive every cue from snapshot events, layered so repetition does not
become a loop:

- **Coin impacts** varying with fall height, stack depth, and whether
  the landing is coin-on-metal or coin-on-coin.
- **Sliding** — the mass of the pile shifting under the plate.
- **Motor loop** tracking the sweep cycle, loaded and unloaded.
- **Tray cascade** — the payout sound that has to feel like winning;
  scale it with how many coins actually fell.
- **Gutter** — a flat, final swallow. Losses should sound like
  losses.
- **Cabinet shake** under a nudge, with the **chirp ladder** escalating
  through the tell stages before an alarm.
- **Alarm** — distinct, loud, and clearly the machine's, not the
  room's.

Register everything through the existing audio bus/manifest systems
(`data/audio/`); no bypass paths. Respect existing mix discipline and
any reduce-motion / accessibility settings the project already
honors.

### 3. Feedback and readability

- Impact particles and restrained camera/cabinet shake, all
  presentation-only.
- Clear affordances for lane selection, drop, and the nudge verb
  (force × direction), readable at 1280×720 and on the supported
  input methods the project already targets.
- The tell ladder must be *visible* as well as audible — the whole
  point is that a careful player can walk the alarm line on purpose.

### 4. Feel verification (acceptance requirement, not garnish)

Re-capture the existing six feel scenarios plus the tell ladder, and
**look at them yourself as a player would**, not as a test author:

1. a drop landing on a packed pile and disturbing it
2. a stack toppling
3. coins falling from the upper shelf onto the lower field
4. a nudge shifting a real pile
5. an edge hanger tipping into the tray
6. the gutter eating a greedy shot
7. the tell ladder escalating to an alarm

The bar is not "the counters incremented." The prior captures already
proved that and still did not look like a coin pusher. The bar is:
**a person shown this image without context calls it a coin pusher.**
It must show a dense, uneven, overlapping field of coins, visible
stacking, and coins hanging over the ledge.

Save to `.tmp/` and reference in your report. **If the captures do
not clear that bar, the task is not done** — report it honestly with
what you think is still missing rather than shipping it.

## Hard rules

- Zero outcome changes. Presentation and audio may not alter what
  pays; prove it with the `pusher06_1` authority test still green and
  unchanged determinism results.
- The snapshot boundary is inviolable (see above).
- Budgets: surface draw p95 ≤ 5.0 ms, idle within budget with
  liveness counter, frame p95 ≤ 16.0 ms, at the shipped coin cap.
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports;
  suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Determinism and the authority test unchanged and green.
2. Snapshot-boundary test: the renderer compiles and runs against a
   synthetic snapshot with no solver present (proves the seam).
3. Perf at the shipped cap, including a full sweep with a loaded
   pile and a nudge-induced collapse.
4. Idle attract animates with liveness counter green.
5. Audio: every event class fires, routes through the existing bus,
   and respects mix/accessibility settings.
6. Feel captures per section 4.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`
- the performance probe at existing budgets

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: the snapshot/event API as published, render approach and
batching, the audio event map, perf numbers, and the feel captures
with your honest verdict on whether it reads as a real machine yet.
On an unfixable gate failure: stop at the last green commit, set
`BLOCKED`, report verbatim.
