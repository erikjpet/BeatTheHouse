Status: TODO
Board row: `teach06_2` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 teach06_2: Teaching Pass Two

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This row brings the teaching
layer up to what 0.6 actually became. Read `data/tutorial/lessons.json` in full,
`scripts/core/tutorial_flow.gd`, `scripts/ui/coach_overlay.gd`,
`scripts/ui/coach_view_model.gd`, the archived `teach06_1_onboarding_prompt.md`
and its accepted rules, `scripts/tests/foundation/onboarding_06_contract.gd`, and
the tutorial defect checks under `scripts/tests/`.

## Why this row exists

`teach06_1` shipped seven once-only public-surface lessons for 0.6:
`tip06_craps_pass_line`, `tip06_coin_pusher`, `tip06_numbers_book`,
`tip06_crew_standing` and three siblings. Since then the update grew a Crew path
with a trust ladder, deliveries and holds, a Police Sweep, back-room poker,
scenario objectives, rumors, and — through the depth programs — a different way
of physically operating craps, the coin pusher, and every other game.

Two problems follow. Systems a player must understand have no teaching at all.
And some shipped tips now describe an interaction that no longer exists, which is
worse than silence.

## Board and dependencies

Follow the active board protocol. Claim `teach06_2`. This row requires
`depth06_1`, `game06_8` and `world06_7` to be DONE — teaching written against a
surface that is still being reworked will be wrong by the time it lands. You own
`data/tutorial/lessons.json`, the coach surfaces and their tests.

## 1. Audit all 63 existing lessons first

- Play or trace every shipped lesson against the current build. Classify each as
  correct, stale (describes an interaction that changed), redundant (the reworked
  surface now teaches it diegetically), or broken (trigger no longer fires,
  pointer target no longer exists, or placement now overlaps).
- Stale and broken lessons are fixed or retired in this row. A tutorial that
  lies is a defect, not a content gap.
- Redundant lessons should be retired rather than kept out of caution. The depth
  programs were meant to make some teaching unnecessary; keeping it anyway
  wastes the player's attention and the once-only budget.
- Report the classification table before writing a single new lesson.

## 2. Fill the gaps

Add once-only public-surface lessons, under `teach06_1`'s accepted rules, for
the systems that currently have none. At minimum, cover:

- back-room poker: how a session works and what a tell is;
- the trust ladder: what standing is and how it moves;
- deliveries and lookout holds: what you are carrying and what ends a run badly;
- the Police Sweep: how to read it before it reaches you;
- scenario objectives: that a night has something happening in it and that it
  can be acted on;
- rumors: that they truthfully describe other places, and how to use one;
- any reworked game interaction whose new verb is not self-evident.

Each lesson must obey the landed rules: once only, public surface, guided prefix,
non-consuming handoff, double-notify at the end, clickable pointer-safe
placement, secrecy discipline, and no lesson that reveals hidden state.

## 3. Discipline

- Teach at the moment of need, not on arrival. A lesson that fires before the
  player has a reason to care is noise.
- Never teach a hidden system. Nothing here may reveal Turn state, traitor
  eligibility, grievance weighting, a rigged draw the player has not discovered,
  or an unrevealed ticket.
- Voice obeys the Voice Bible register — the coach speaks in the register of
  wherever the player is standing.
- Determinism: triggers fire at action boundaries, never on wall-clock time.
- Respect the once-only budget as a whole. If adding a lesson pushes total
  density past what `teach06_1` established as tolerable, retire a weaker one
  rather than accepting more interruption.

## 4. Tests and acceptance

- The full classification table from section 1, with the disposition of every one
  of the existing lessons.
- Trigger tests for every new and every modified lesson, including the negative
  case that it does not fire for a player who does not reach that system.
- Once-only, non-consuming handoff and double-notify assertions preserved for the
  whole set.
- Pointer placement and overlap checks at 1280×720, small screen and reduced
  motion, extending the existing tutorial placement checks rather than adding a
  parallel one.
- Secrecy assertions: no lesson exposes hidden state, on any path.
- A cold first-run playthrough with every lesson active, confirming order,
  density and that no lesson describes something that is not on screen.
- The crew-ignoring run: lessons for crew systems must never fire in it.

Run project validation, `onboarding_06_contract.gd`, the tutorial checks,
relevant foundation suites, determinism, native/Web parity, accessibility and
visual QA. Archive with the classification table and the cold-run evidence
attached.
