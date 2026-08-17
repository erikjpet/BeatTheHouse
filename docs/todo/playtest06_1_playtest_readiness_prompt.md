Status: TODO
Board row: `playtest06_1` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** —
- **Completion/implementation commits:** —
- **Verification:** —
- **Deviations:** —

# Agent Prompt — 0.6 playtest06_1: Playtest Readiness & Owner Handoff

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Binding design
contract: `docs/plans/0.6_living_world_roadmap.md`.

**Read this first, because it inverts the usual final-task
assumptions:** this is NOT a release task. 0.6 is roughly half-built
at this point. The owner's own extensive playtest is the next phase,
and it is expected to surface real problems and change direction. Your
job is to make the build *worth playtesting* and then get out of the
way.

**Explicitly OUT of scope — do none of these:**

- No version bump. `project.godot`, README, and CHANGELOG keep their
  current version identity. Do not stamp 0.6.0 anywhere.
- No git tag. No `v0.6.0`, no release branch, no annotated tag.
- No packaging for distribution, no uploads, no itch, no GitHub
  Release, no publish copy, no devlog, no release checklist, no
  screenshots-for-marketing.
- No final balance tuning. Fix only what is *broken*; leave what is
  merely *unbalanced* for the owner to judge in play — their read on
  feel is the input that matters, and pre-tuning it destroys the
  signal.
- No new features, no scope additions, no "while I was in there"
  improvements.

If you find yourself writing publish copy or touching a version
string, you have misread this prompt.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row
   `playtest06_1` to `IN_PROGRESS` with agent + date, append a Work
   Log line, commit the claim. **Precondition: every other row on the
   board is DONE** (all waves plus any `fix06_*` rows), except
   `voice06_1` and `release06_1`, which are intentionally parked for
   the post-playtest polish wave. Verify on the board; if
   content-bearing rows remain open, set `BLOCKED` and stop.
2. Log discoveries/deviations tagged `[playtest06_1]`; owner-only
   questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; final Work Log entry
   handing the board to the owner.

## Task

### 1. Stability verification on one clean commit

Run the complete matrix on the exact source the owner will play — not
a historical report, not a dirty tree:

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` (systems + UI)
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`
- `tools/foundation_visual_qa.ps1`
- the performance/soak suite at existing 0.5 budgets — **idle
  liveness floors unchanged; a 0.000 idle number without its liveness
  counter is an automatic FAIL** (this project's recurring regression)
- save-migration matrix: 0.5-release saves and mid-0.6 dev saves both
  load without loss
- Web + Windows export smoke (they must *run*; you are not packaging
  them for distribution, only proving the exports aren't broken)

Every failure is either fixed (if it is a defect blocking play) or
recorded as a known limitation in the handoff report with a clear
statement of what the owner will see. Never weaken a test, budget,
liveness floor, or assertion to go green.

### 2. Playability sweep — the thing that actually matters

A playtester's time is destroyed by dead ends, not by imperfect
numbers. Drive these end to end (headless where possible, by hand
where not) and fix anything that blocks or wastes play:

- **No dead interactions.** The `fix06_1` class guard must be green:
  every interactable event/object placed in any generated environment
  yields a working interaction. Extend the sweep to the systems that
  landed after that guard (crew jobs, plays, heist beats, chains,
  Numbers, pushers, craps, active delivery map layers and in-room handoffs) — an icon that does
  nothing is the single worst playtest experience and this project
  has already shipped that bug once.
- **No soft-locks.** Sweep travel locks, delivery failures, heist
  aborts, layer transitions, Engine Trouble, sweep encounters, and
  every job/chain failure path for states the player cannot leave.
- **Every major path reachable.** In seeded runs, prove the player
  can actually reach: the crew path to `inner_circle`, both heist
  plans (under their criteria), the Turn and its confrontation, the
  Numbers fix and past-post, all three pushers, craps and street
  craps, back-room poker, all three Punchline layers, and each of the
  three victory routes. Report seeds that reach each — the owner will
  use them.
- **Save/load anywhere.** Mid-heist, mid-delivery, mid-hand, mid-layer.

### 3. Truthful state-of-the-update report

Write `docs/plans/0.6_playtest_handoff.md` — the document the owner
reads before playing. It must be blunt and complete:

- **What is implemented**, feature by feature, in player-facing
  language (what you can now *do* that you could not in 0.5).
- **What is registered but inert** — every seam earlier prompts left
  deliberately unwired, so the owner does not report unbuilt things
  as bugs.
- **What is rough on purpose** — placeholder art (Punchline L1/L3
  reuse the underground raster; note every other art debt logged
  during the waves), unbalanced numbers, unpolished copy, anything
  the waves knowingly deferred.
- **Known limitations and open defects** carried from the matrix.
- **Where to look first**: the seeds and routes that exercise the new
  systems fastest, so the owner can reach the crew path, a heist, a
  sweep, and each new game without grinding for them.
- **What is deliberately unjudged**: balance and voice. State plainly
  that economy tuning and the register pass are deferred to the
  post-playtest polish wave and that the owner's feel notes are the
  intended input.

### 4. Local playable build for the owner (not a release artifact)

Produce a current Windows build (and Web if it builds cleanly) into
the existing local build location, purely so the owner can play
without a toolchain. Record what you built and from which commit in
the handoff doc. Do not name it a release, do not hash-manifest it
for distribution, do not upload it anywhere.

### 5. Defect intake scaffolding

Leave the board ready to receive the owner's findings: a short
"Playtest findings intake" section at the top of the board explaining
that owner notes become `fix06_*` rows via the playtest intake
process, and that direction changes are owner decisions recorded in
the roadmap, never guessed by an agent.

## Hard rules

- Nothing in the OUT-of-scope list, no exceptions, even if it seems
  helpful.
- Fixes in this task are limited to play-blocking defects. Anything
  larger becomes a new `fix06_*` row with a scoped prompt — never a
  drive-by.
- The handoff report must be honest to a fault. Overstating readiness
  wastes the owner's playtest; understating it wastes their time
  chasing known gaps. If something is half-built, say it is
  half-built.
- Style: tabs, typed GDScript where code is touched; `.tmp/` reports;
  suite timeout = max(300s, baseline×1.5).

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report to the owner: the exact commit they should play, the matrix
summary, the reachability seeds, the location of the build and the
handoff doc, and the honest one-paragraph answer to "is this worth
several hours of playtesting yet?" On an unfixable gate failure: stop
at the last green commit, set `BLOCKED`, report verbatim.
