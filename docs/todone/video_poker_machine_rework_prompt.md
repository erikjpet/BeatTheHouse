# Agent Prompt — Video Poker Complete Rework (3 Cabinets, Slot-Level Polish)

Copy everything below this line into the worker agent. This is a large,
creative+technical rework; use a capable model.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (900×430 board, immediate-mode canvas, per-game modules,
data-driven, seeded RNG). Video poker (`scripts/games/video_poker.gd`,
~1,700+ lines) is currently boring, unintuitive, off-theme, and its cheat
(the just-landed PALM/SWAP/COVER holdout chain, `HOLDOUT_CHAIN_VERSION 2`)
is bad and confusing. Rework video poker to the POLISH LEVEL OF THE SLOT
MACHINES (study the Buffalo and Pinball slot families for the bar: distinct
cabinet identities, integrated art, custom sounds/displays, satisfying
feel). This supersedes the recent holdout rework.

## Owner-locked design

### Three distinct cabinets (hand count baked into identity)

| Cabinet | Base game | Hands | Identity |
| --- | --- | --- | --- |
| **Jacks or Better** | Jacks or Better (9/6) | 1 | The honest baseline — retro-neon diner cabinet |
| **Double Deuces** | Deuces Wild | 2 | Wilds, electric/flashy cabinet; the "double" plays 2 hands at once |
| **Triple Double Bonus** | Double Double Bonus | 3 | High-variance four-of-a-kind bonuses; premium gold high-roller cabinet; plays 3 hands at once |

Each cabinet is a first-class machine like a slot family: an ENTIRE cabinet
art with a UNIQUE layout, buttons INTEGRATED into the cabinet design (not
generic UI bolted on), custom DISPLAYS (credits/bet/win meters, the paytable,
and a multi-hand display that clearly shows 1 / 2 / 3 stacked hands), custom
SOUNDS, and the mechanics below. Do extensive research into real video
poker before implementing; the rules below are the spec to hit.

### Rules per cabinet (research-backed; tune paytables to a fair RTP band)

- **Jacks or Better (1 hand, 9/6):** Royal Flush, Straight Flush, Four of a
  Kind, Full House (9), Flush (6), Straight, Three of a Kind, Two Pair,
  Jacks-or-Better pair. Classic hold/draw. The clean teaching machine.
- **Double Deuces (Deuces Wild, 2 hands):** all 2s are wild; paytable
  includes Natural Royal, Four Deuces, Wild Royal, Five of a Kind, Straight
  Flush, Four of a Kind, Full House, Flush, Straight, Three of a Kind. The
  player holds from one dealt hand; TWO independent draws resolve from the
  remaining deck, each its own hand — both shown and paid.
- **Triple Double Bonus (Double Double Bonus, 3 hands):** big bonuses for
  four-of-a-kinds, with the kicker bonuses (Four Aces with a 2/3/4 kicker,
  Four 2-4 with an A-4 kicker, etc.); high variance. THREE independent draws
  from one held hand, all shown and paid.
- Multi-hand dealing must be correct and deterministic: the held cards are
  shared, each additional hand draws from its own shuffled remainder (real
  multi-hand video poker), seeded so the same seed + same holds reproduce
  the same hands. Bet scales with hand count. Keep the double-up gamble.
- Per-cabinet paytable + RTP: each cabinet declares its paytable in data and
  lands in an audited RTP band (extend the existing RTP/audit tooling for
  the three cabinets; report measured RTP per cabinet).

### The cheat — reworked, per-cabinet, blunt

Completely rework the cheat. Keep a SKILL-BASED TIMED MINIGAME as the
trigger (the concept is right), but the current chain is bad — replace it
with something intuitive and FUN, and make each cabinet's cheat a
RELATIVELY UNIQUE variant of the SAME underlying skill mechanism (so the
three feel distinct but share a coherent skill). Requirements:

- **Intuitive & fun:** the player immediately understands what to do and it
  feels good to pull off — a clean, readable timed skill beat (or short
  chain) themed to the cabinet, not the confusing PALM/SWAP/COVER sequence.
- **Per-cabinet flavor:** e.g. a palm-and-swap on the retro machine, a
  wild-deuce swap on Double Deuces, a high-stakes hold on Triple Double
  Bonus — same skill core (timing/precision), different dressing.
- **BLUNT, FORWARD FEEDBACK (the core fix):** after the cheat resolves, a
  LOUD, UNMISTAKABLE result beat states EXACTLY what the cheat did — which
  card was swapped in and the resulting hand ("You slipped in the Ace of
  Spades — FOUR ACES"). The player must never be confused about what
  happened or whether the cheat worked. No off-to-the-side ambiguity.
- **Preserve the cheat economy:** the ideal palmed card stays seeded/
  deterministic; performance maps to the existing quality→heat/evidence
  tiers; alcohol widens/shifts the window, contraband sharpens it (reuse
  the existing modifier keys). Determinism: same seed + same inputs → same
  result.
- **Reduce-motion:** a generously-timed single-input fallback, still blunt
  about the outcome.

## Slot-level polish bar

- Each cabinet reads as its own machine: cohesive art, integrated buttons,
  themed meters/paytable, a clear multi-hand display, and per-cabinet custom
  sounds (following the SFX rework's casino-smooth palette — if that pass
  has landed, reuse its synth helpers; otherwise synthesize in-theme).
- Satisfying feel: deal/hold/draw have tactile feedback; wins celebrate at a
  scale matched to the payout; the multi-hand reveal is legible and
  exciting.
- Clear at a glance: bet, credits, the active paytable, holds, and each
  hand's result read instantly at 1280×720 and small-screen.

## Hard rules

- Determinism: seeded deal/draw across all hands; seeded cheat ideal card;
  same seed + same holds/inputs reproduce identical results; the probe stays
  self-consistent. No wall-clock in outcomes; skill windows resolve against
  surface/simulation time like the current holdout timing.
- Zero-copy per-frame; the cabinet surface renders from the module snapshot
  under the allocation-free idle contract; idle-animation liveness
  untouched; add the video poker surface to the performance probe with a
  budget.
- Tokens for chrome; per-cabinet art immediate-mode in the game's pixel
  style. Web-safe. Style: tabs, typed GDScript, sparse comments; captures/
  RTP under `.tmp/`. Suite timeout = max(300s, ceil(baseline × 1.5)).
- Coordination: the writing pass may supply cabinet flavor names/lines; the
  SFX pass owns the sound palette — align with both if they've landed,
  otherwise keep art/sound in-theme and reusable.

## QA / Tests

1. Correctness: hand evaluation per cabinet (incl. wilds on Double Deuces
   and the kicker bonuses on Triple Double Bonus) is correct; multi-hand
   dealing draws each hand from its own remainder; bet scales with hands.
2. Determinism: same seed + same holds → identical hands and payouts across
   all three cabinets and across save/load mid-hand; cheat is deterministic
   given the same inputs.
3. RTP: per-cabinet mass-simulation RTP within declared bands; report the
   table.
4. Cheat: the minigame triggers, resolves to the correct quality tier and
   heat/evidence (matching the preserved economy), and the blunt result beat
   states exactly which card was swapped and the resulting hand; reduce-
   motion fallback works.
5. Auto/collect + double-up flows are clean (no stranded credits).
6. Perf: the cabinet surface within its probe budget; liveness advances.
7. FEEL ACCEPTANCE (manual, report in words): play all three cabinets — each
   feels like a distinct, polished machine on par with the slots; the cheat
   is fun and its outcome is unmistakable; the multi-hand reveals are
   exciting.

## Gates

- `tools\validate_project.ps1`
- `-FoundationSuite games`, `ui`, `systems`, and any video-poker suite
- `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools\foundation_performance_probe.ps1 -RequireGodot`
- `tools\foundation_visual_qa.ps1`
- the video poker RTP audit tool (extend it for the three cabinets)
- `tools\foundation_mouse_playtest.ps1` (strict single run)

## On completion

Only after every gate passes AND you've confirmed all three cabinets + the
cheat in the running game:

1. Commit in logical units (cabinet framework; each cabinet; the reworked
   cheat; RTP/audit).
2. ARCHIVE this prompt (do NOT delete it): move it from `docs/todo/` to
   `docs/todone/`, append an execution record (date, commit hashes, per-
   cabinet RTP, cheat design + windows, gate results), and stage the move.
3. PUSH to the remote.
4. Report: the three cabinets (art/layout/mechanics), the per-cabinet cheat
   design and how blunt feedback works, the RTP table, the feel-acceptance
   in your own words, and gate results.

On an unfixable gate, stop at the last green commit, do NOT push, and report
verbatim.

## Execution record

- Date: 2026-07-28T23:21:01-05:00
- Implementation commit: `fb11116b` (`Rework video poker cabinets and holdout`)
- RTP/test commit: `e05eef11` (`Audit video poker cabinet RTP`)
- Archive commit: this commit
- Deviations: retired Bonus Poker/Joker Poker evaluator data remains available for old save/data tolerance, but generation and the active UI roster are locked to the three owner-approved cabinets. The internal `video_poker_palm` surface action id remains as a compatibility hook; the player-facing cheat has been replaced with LINE UP/COMMIT cabinet-flavored timing.

### Cabinets and RTP audit

| Cabinet | Variant/paytable | Hands | Bet/round | Return | Cost | RTP | Top sampled hit |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Jacks or Better / Neon Jacks | 9/6 full-pay Jacks or Better | 1 | 5 | 14750 | 15000 | 0.9833 | Straight Flush |
| Double Deuces | full-pay Deuces Wild | 2 | 10 | 27640 | 30000 | 0.9213 | Wild Royal |
| Triple Double Bonus | Double Double Bonus-style full-pay | 3 | 15 | 42745 | 45000 | 0.9499 | Four 2-4 + A-4 |

RTP audit command: `tools\video_poker_rtp_audit.ps1 -RoundsPerCabinet 3000`.

### Cheat design and timing windows

- Shared skill core: center-focus two-beat chain, `LINE UP` timing then `COMMIT` target, dressed per cabinet.
- Per-cabinet flavor: Jacks or Better uses `Neon Slip`; Double Deuces uses `Wild Deuce Flash`; Triple Double Bonus uses `High-Roller Hold`.
- Beat timing: beat durations 880ms and 760ms; both targets at 58% of their beat.
- Grade windows: perfect 80ms, good 210ms, close 340ms, with the existing item/alcohol modifiers still applied.
- Reduce motion: one `SAFE COMMIT` input with a 1120ms duration, no continuous realtime redraw.
- Feedback: result text names the exact card and slot, then states `RESULT: <hand>` so the swap and resulting hand are unmistakable.

### Gate results

- `tools\validate_project.ps1`: PASS (`Beat the House foundation architecture validation passed.`)
- `tools\check_godot.ps1 -FoundationSuite video_poker -RequireGodot`: PASS (`foundation_video_poker` 32179ms; report `.tmp\test_reports\20260728_230953_smoke\summary.json`)
- `tools\video_poker_rtp_audit.ps1 -RoundsPerCabinet 3000`: PASS (RTP table above)
- `tools\check_godot.ps1 -FoundationSuite games -RequireGodot`: PASS (`foundation_games` 84876ms; report `.tmp\test_reports\20260728_231146_smoke\summary.json`)
- `tools\check_godot.ps1 -FoundationSuite ui -RequireGodot`: PASS (`ui_scene_compile` 64583ms; report `.tmp\test_reports\20260728_231414_smoke\summary.json`)
- `tools\check_godot.ps1 -FoundationSuite systems -RequireGodot`: PASS (`foundation_systems` 28163ms; report `.tmp\test_reports\20260728_231644_smoke\summary.json`)
- `tools\foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`: PASS (10 seeds, 320 checkpoints, combined hash 3311295357)
- `tools\foundation_performance_probe.ps1 -RequireGodot`: PASS (video poker draw resolve p95 0.992ms; idle video-poker cabinet remains static with documented zero-liveness reason)
- `tools\foundation_visual_qa.ps1`: PASS
- `tools\foundation_mouse_playtest.ps1`: PASS (63 input events; victory and recovery/debt pressure reached via visible mouse controls)

### Manual feel acceptance

Accepted. All three cabinets now read as distinct slot-machine-style video poker units rather than one generic card surface: Neon Jacks is clean/classic, Double Deuces is brighter and wild-card forward, and Triple Double Bonus feels heavier/high-limit with a more dramatic three-hand reveal. The cheat is easy to understand because it is centered, yellow-guided, and ends with blunt card/result text instead of the old PALM/SWAP/COVER abstraction. Multi-hand dealing lands as a cosmetic/presentation boost while preserving seeded outcomes and the existing heat/evidence economy.
