# Agent Prompt — Video Poker Cheat Rework: Center-Focus WarioWare Minigame Chain

Copy everything below this line into the worker agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (900×430 board, immediate-mode canvas, per-game modules,
data-driven). This reworks the VIDEO POKER cheat from an easy-to-miss
side prompt into a focused, satisfying WarioWare-style micro-minigame chain,
removes the manual collect step, and adds click guidance. Owner playtest
direction, verbatim intent:

- The cheat (nudge/mark cards) must pop a CENTER-FOCUS popup that pulls the
  player's attention, instead of sitting off to the side.
- Make it more of a MINIGAME — WarioWare-style: several fast micro-beats in
  a row to trigger the cheat.
- REMOVE the collect button; pay out automatically.
- Add a YELLOW BORDER that guides the player where to click.

## What exists (audit first; code reality wins)

`scripts/games/video_poker.gd`: the holdout/mark cheat today is a SINGLE
timed input — `HOLDOUT_PROMPT_BASE_MSEC` (~:62) with perfect/good/close
windows (~:63-65), quality → heat mapping (`HOLDOUT_*_HEAT_*`), the ideal
"palmed" card chosen from a deterministic hash of run seed/state (see the
header comment ~:24-28, `holdout_tell` ~:299), item modifiers
(`HOLDOUT_ITEM_EFFECT_KEYS` ~:71, incl. `skill_cheat_drunk_window_offset_
msec`), and a `collected` UI flag / collect step (`result_collected`,
`ui.get("collected")` ~:314-318) plus a `double_up` phase. The prompt
currently renders off to the side.

Preserve the underlying cheat ECONOMY (seeded ideal card, quality→heat/
evidence tiers, item/alcohol modifiers, determinism). This is an
interaction + presentation rework of the TRIGGER and the payout flow, not
a change to what the cheat is worth or how heat is earned.

## The rework

### 1. Center-focus cheat overlay

When the player initiates the cheat during the draw, take focus with a
CENTER-SCREEN overlay on the game surface (not a corner prompt): a framed
"palm the card" sequence the eye is drawn to, with the rest of the surface
dimmed. It must read as the moment that matters.

### 2. WarioWare-style micro-chain

Replace the single timed input with a short CHAIN of 2-3 fast micro-beats
(each ~0.5-1.0s, tunable), performed in sequence, e.g.:

- **PALM** — tap exactly when a sweeping marker hits the target zone
  (timing).
- **SWAP** — click/flick the correct card into the holdout slot (target
  selection).
- **COVER** — hold briefly and release on cue (release timing).

Design 3 authored micro-beats (data-tunable windows). Each beat:
- shows a **yellow guidance border/highlight** on exactly the control to
  act on, so the player always knows where to click;
- succeeds/fails on its own fast window;
- contributes to an overall performance score.

**Overall performance → the existing quality tiers:** all beats clean =
`perfect`; minor slips = `good`/`close`; a missed beat = `miss`/`blown`.
Map the chain result onto the current holdout quality→heat/evidence tiers
so the cheat's cost/reward is unchanged in spirit. Alcohol widens/shifts
the beat windows and contraband sharpens them, reusing the existing
`HOLDOUT_ITEM_EFFECT_KEYS` / `skill_cheat_drunk_window_offset_msec`.

**Determinism (critical):** the ideal palmed card and the mechanical
outcome stay seeded exactly as today; the minigame measures the player's
inputs, and the SAME inputs on the SAME seed must produce the SAME quality
tier and result. No wall-clock in the resolved outcome — beat windows
resolve against simulation/surface time the way the current holdout timing
does (study it first). Zero-copy per-frame; the overlay animates from the
module snapshot.

**Reduce-motion / accessibility:** collapse the chain to a single
simplified, un-timed-or-generously-timed center input (still yellow-guided,
still center-focus), so the cheat remains performable without fast motor
demands. Document the fallback.

### 3. Remove the collect button — auto-payout

Delete the manual collect step. When a hand resolves, pay out automatically
after a short readable beat (the win reads, then credits land). The
double-up GAMBLE remains an explicit opt-in choice (it is a risk decision,
not a collect chore), but the base payout is never gated behind a collect
click. Update `surface_state` phases (`result_collected`/`collected`,
`showing_result`, `idle_phase` ~:314-320) and any UI/tests that assumed a
collect action.

### 4. Yellow guidance border (pattern)

The yellow "click here" border introduced for the cheat beats should be a
reusable guidance treatment (a shared helper), used here to point at each
beat's control and at the double-up choice. Keep it a token-based color,
reduce-motion safe (no pulse when reduce-motion).

## Hard rules

- Cheat economy unchanged: same seeded ideal card, same quality→heat/
  evidence tiers, same item/alcohol modifiers; only the trigger interaction
  and payout flow change.
- Determinism preserved; zero-copy per-frame; idle-animation liveness
  untouched; tokens not raw literals; tabs, typed GDScript, sparse comments;
  captures under `.tmp/`. Suite timeout = max(300s, ceil(baseline × 1.5)).
- Do not alter other games' cheats (that pass is separate). Working tree may
  hold uncommitted user-owned work; never revert/stage it.

## QA / Tests

1. Determinism: same seed + same scripted inputs → identical quality tier,
   payout, heat, and evidence across replays and save/load mid-cheat.
2. Tier mapping: clean chain → `perfect` outcome; one missed beat →
   `miss`/`blown` with the correct heat/evidence, matching the pre-rework
   economy for equivalent performance.
3. Alcohol/contraband: modifiers shift the beat windows as the old holdout
   modifiers did (assert window changes).
4. Auto-payout: a resolved hand pays with no collect action; double-up
   remains an explicit optional choice; no phase can strand credits.
5. Reduce-motion: the fallback input triggers the cheat without fast timing.
6. FEEL ACCEPTANCE (manual, report in words): the cheat now grabs focus
   center-screen, the chain is quick and satisfying, the yellow border makes
   each click obvious, and payouts land automatically.

## Gates

- `tools\validate_project.ps1`
- `-FoundationSuite games`, `ui`, `systems`, plus any video-poker suite
- `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools\foundation_performance_probe.ps1 -RequireGodot`
- `tools\foundation_visual_qa.ps1`
- `tools\foundation_mouse_playtest.ps1` (strict single run)

## On completion

Only after every gate passes AND you have confirmed the cheat + payout in
the running game:

1. Commit in logical units (center overlay + chain; tier mapping;
   auto-payout; yellow-guidance helper).
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append an execution record (date, commit hashes, tuning
   values, gate results, deviations), and stage the move.
3. PUSH to the remote.
4. Report: the chain design and windows, how the tiers map to the old
   economy, the reduce-motion fallback, the feel-acceptance in your own
   words, and gate results.

On an unfixable gate, stop at the last green commit, do NOT push, and
report verbatim.

---

## Execution record — 2026-07-27 23:29 -05:00

- Implementation commit: `1871b0e1` (`Rework video poker holdout flow`).
- Archive commit: this archival commit.
- Scope completed:
  - Replaced the old single PALM timing check with a center-screen PALM / SWAP / COVER chain.
  - Added a reusable yellow guidance-border helper on the shared surface canvas.
  - Preserved the old holdout economy mapping by feeding the chain aggregate into the existing `perfect`, `good`, `partial`, `miss`, and `blown` tier hooks.
  - Kept seeded target-card selection, item/alcohol timing-window modifiers, heat/evidence tiers, and save-load survival.
  - Removed the manual collect affordance from settled video-poker results; payouts apply at draw resolution and double-up remains explicit opt-in.
  - Added reduce-motion fallback: one generous center input, no realtime timing redraw.
- Tuning values:
  - Standard chain beats: PALM target `0.52`, SWAP target `0.46`, COVER target `0.64` across beat durations `760ms`, `700ms`, `860ms`.
  - First PALM target retains the old seeded offset (`520ms ± 70ms`) and the existing item/alcohol-adjusted windows.
  - Grade windows remain the prior economy windows: perfect `80ms`, good `210ms`, close/partial `340ms`, modified by the existing item/alcohol hooks.
  - Reduce-motion duration: `1120ms`; any completed fallback input resolves as a perfect accessible holdout trigger.
- Gate results:
  - `tools\validate_project.ps1`: PASS.
  - `tools\check_godot.ps1 -FoundationSuite games -TimeoutSec 300`: PASS (`.tmp/test_reports/20260727_231408_smoke/summary.json`).
  - `tools\check_godot.ps1 -FoundationSuite ui -TimeoutSec 300`: PASS (`.tmp/test_reports/20260727_231950_smoke/summary.json`).
  - `tools\check_godot.ps1 -FoundationSuite systems -TimeoutSec 300`: PASS (`.tmp/test_reports/20260727_232235_smoke/summary.json`).
  - `tools\check_godot.ps1 -FoundationSuite video_poker -TimeoutSec 300`: PASS (`.tmp/test_reports/20260727_231728_smoke/summary.json`).
  - `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`: PASS; seeds `10`, checkpoints `320`, combined hash `300794035`.
  - `tools\foundation_performance_probe.ps1 -RequireGodot`: PASS; 62 observations across 8 seeds; liveness guard proof passed.
  - `tools\foundation_visual_qa.ps1`: PASS.
  - `tools\foundation_mouse_playtest.ps1`: PASS; 63 mouse events, visible-control victory and recovery/debt pressure verified.
  - Manual focused probe (`.tmp/manual_video_poker_rework_probe.gd`): PASS; normal PALM/SWAP/COVER completed as perfect, cheat draw resolved with that grade, auto-pay settled phase displayed, reduce-motion collapsed to one input.
- Deviations:
  - An attempted parallel gate launch hit the repo's Godot concurrency guard for UI/systems while the video-poker suite was importing. No result was accepted from those contended attempts; Godot was confirmed quiet and UI/systems were rerun serially before completion.
