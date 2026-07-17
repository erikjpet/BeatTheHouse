# Agent Prompt — Onboarding Slice 2: The First Card Tutorial Arc (Beats 1-5)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (Web/itch.io + Windows, 1280×720). This file is self-contained;
the binding design contract is `docs/plans/0.5_onboarding_tutorial_plan.md`
Part 2 — read it first. REQUIRES: onboarding slice 1 (Coach engine) and
the gc05 Grand Casino queue landed (invite gate, chips, Linda exist).
Re-verify actual code; code reality wins.

## Task

### 1. Entry + lifecycle

- A fresh profile (no run history, no collection, `tutorial_completed`
  unset) auto-starts the tutorial when the player first starts a run —
  framed as "First night in town", not as a menu mode.
- `tutorial_first_card` challenge config in `data/challenges/
  challenges.json`: fixed tutorial seed, tutorial-scoped objective
  overrides (slice 3 consumes them), excluded from daily/challenge
  stats and completion records (verify how challenge completions are
  recorded and exclude this id).
- Skippable at any time via a confirm ("Skip the lessons?"):
  skipping sets `tutorial_completed`, and converts the run in place to
  a normal run OR exits to menu (implement whichever the run/challenge
  machinery supports cleanly WITHOUT hacks; if in-place conversion is
  dirty, end-and-return-to-menu is the correct choice — state your
  choice and why). Replayable from the start screen ("Replay the
  lessons") on any profile.

### 2. Beats 1-5 (authored, seed-verified)

Author the guided arc as gating Coach lessons + scripted events on the
tutorial seed. AUDITION THE SEED FIRST: play the intended path and
verify each beat is reachable and winnable naturally; iterate seeds
until the path holds; record the audition evidence in `.tmp/`.

1. **Home**: walk, inspect a container, view the empty loadout, leave
   via the map (venue hours pointed out on the map popup).
2. **Corner store**: buy one cheap item with starting cash.
3. **Bar**: guided low-stakes blackjack — wager, actions, result
   presentation; heat introduced by watching the meter move; one-step
   count-challenge taste with a safety note.
4. **Talk/event**: one scripted friendly talk-dock event teaching
   choices (author a tutorial-scoped event; `blocked_by_flags` keeps it
   out of normal runs).
5. **The invitation**: a scripted tutorial event grants
   `grand_casino_invite` directly with framing copy (teaching the gate
   exists without the tier-2 climb).

Gating rules: each beat's gating lesson restricts interactables to the
intended path but never soft-locks — the "skip lessons" escape is
always reachable, and the stuck-state sweep must stay green on the
tutorial config.

## Hard rules

- Determinism: the tutorial is a real seeded run; beats derive from the
  seed + scripted events, not from forced RNG. Normal-run behavior is
  byte-identical (every tutorial-only element is gated by the challenge
  id or one-shot flags).
- Zero-copy per-frame; idle liveness untouched; copy per
  `docs/plans/content_style_guide.md`. Style: tabs, typed GDScript,
  sparse comments; `.tmp/` reports. Suite timeout = max(300s,
  baseline×1.5).

## QA / Tests

1. Fresh profile auto-starts the tutorial; completed/skipped profiles
   never see it; replay entry works.
2. Beat progression: scripted playthrough of beats 1-5 in a test
   (drive the interactions, assert lesson sequence and gate states).
3. Skip at each beat: converts/exits cleanly, zero coach residue,
   normal runs unaffected after.
4. Stats exclusion: tutorial completion records no daily/challenge
   completion and pollutes no lifetime stats (verify which stats exist
   and assert).
5. Stuck-state sweep green including the tutorial config.
6. Manual: full playthrough beats 1-5 on the audition seed; skip-path
   smoke.

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`
- `tools/foundation_stuck_state_sweep.ps1 -RequireGodot -SeedCount 100`

## On completion

Commit (challenge config; beats; lifecycle as logical units), delete
this prompt file in the final commit, push, report the chosen seed +
audition evidence, the skip-path design chosen, and gate results. On an
unfixable gate failure: stop at the last green commit and report
verbatim.
