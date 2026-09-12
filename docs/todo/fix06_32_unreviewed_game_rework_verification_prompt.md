Status: TODO — verification row for a week of unreviewed game changes; claimable now
Priority: P0 for section 2.1 (unverified wager math in a gambling game), P1 for the rest
Board row: `fix06_32` in `docs/todo/README_0_6_board.md` (Defects table)
Opened: 2026-09-11 by PM audit of commits `f870dd21`..`c570f2ce`
Scope note: this row **verifies and protects** the 2026-09-09/09-10 game work. It does not redo it.

## Execution Record

_Fill in on completion: date, commit hashes, gate results, deviations._

# Agent Prompt — fix06_32: Verify and Regression-Protect the Unreviewed Game Rework

Copy everything below this line into one agent. It may spawn sub-agents freely.

---

You are working in `D:\Projects\Beat-The-House` on `main` at `c570f2ce` or later.
This prompt is complete on its own.

## 0. What happened

Between 2026-09-09 02:10 and 2026-09-10 17:33, roughly **6,000 inserted lines of
game code and data** landed directly on `main`:

| Commit | Subject | Size |
| --- | --- | --- |
| `f870dd21` | fix: restore all game library launchers | 334 |
| `651f2a9f` | fix(slot): keep sustained autoplay responsive | 675 |
| `4360b380` | fix(slot): preserve autoplay reel cadence | 319 |
| `9971aa2b` | fix(blackjack): model realistic counter surveillance | 706 |
| `f41d6db8` | fix coin pusher stacks cadence and item prizes | 285 |
| `2649d455` | feat(poker): rebuild back-room table as holdem | 990 |
| `55a194a1` | feat(poker): bring crew holdem table to life | 691 |
| `19718c1a` | fix(poker): clarify betting and chip placement | 306 |
| `5f185f2c` | feat(poker): add variable no-limit raises | 286 |
| `c97aa8b0` | feat: rebuild craps as a living full-table game | 1,565 |
| `541f4568` | test: complete craps playtest and visual audit | 736 |
| `28568d12` | Fix venue game placement and tier two travel | 185 |
| `f8a1fe35` | Scope street craps to alley scenario | — |

It touched core systems, not only presentation: `craps_rules.gd`,
`crew_poker_model.gd`, `blackjack_action_authority.gd`, `coin_pusher_solver.gd`,
`slot.gd`, `run_state.gd`, `save_service.gd`, `scenario_sequence_schema.gd`,
`world_map.gd`, `content_library.gd`, `environment_instance.gd`,
`data/games/games.json` and `data/crew/poker.json`.

**None of it has a board row, a work-log entry, an archived prompt or an
independent review.** The work log's last entries are `fix06_29`/`fix06_30` and
the `fix06_31` claim; this week is absent from the record. Every commit message
is a bare subject with no body, so the commits assert no evidence at all.

**This is not a claim that the work is bad.** Real self-verification exists: a
204-check `craps_extensive_playtest` suite passing with zero failures, a
1,000,000-roll-per-bet craps RTP audit passing, and new probes for Hold'em,
slot cadence and blackjack surveillance. That evidence was produced by the
implementing agent, lives in `.tmp/` (never committed), and no second party has
checked it. `fix06_31` is this program's reminder of what a self-graded agent can
miss: it reported "zero floating people" while people stood on walls, because its
own classifier had typed them as furniture.

Your job is to check this week's work independently, close the specific gaps
below, and put it on the record.

## 1. Do not re-do the reworks

The craps rebuild, the Hold'em table and the coin pusher fixes are the owner's
directed work and are presumed wanted. You are not re-designing them. If you
find a defect, fix the defect. Do not rewrite a working system because you would
have built it differently, and do not revert any of these commits.

## 2. Confirmed findings — fix these

### 2.1 Craps: 31 live wager types with no documented and no measured house edge — P0

This is the serious one, and it is arithmetic, not taste.

- `data/games/games.json` → `craps_config.variants.street_craps.allowed_bets`
  lists **40 player-reachable wager types**, including `buy_4..buy_10`,
  `lay_4..lay_10`, `big_6`, `big_8`, `hard_4`, `hard_6`, `hard_8`, `hard_10`,
  `any_seven`, `any_craps`, `horn`, `ce`, `world`, `snake_eyes`, `ace_deuce`,
  `yo` and `boxcars`.
- `craps_config.house_edge_documentation` contains **exactly 9 entries**:
  `pass_line`, `dont_pass`, `come`, `dont_come`, `odds`, `place_4_10`,
  `place_5_9`, `place_6_8`, `field`. Those are the pre-rework bets.
- The RTP audit measured **exactly those 9**. Confirm it yourself in the audit's
  own output; at the time of writing, `.tmp/craps/rtp_audit.json` has 9 rows,
  1,000,000 rolls per bet, all passing.
- `tools/craps_rtp_audit.gd` around lines 213–225 does contain a
  `required_full_table_bets` list naming all 40. **It only asserts those ids are
  present in the street-craps allowed list.** It never measures their return.
  Presence is not correctness.
- The rework added the payout tables that pay them: `hardway_payouts`,
  `lay_odds_payouts`, `commission_percent` and the proposition entries under
  `craps_config.rules`.

So the game currently pays out on hardways, propositions, buy and lay bets whose
house edge nobody has documented or measured. These are the highest-edge bets on
a real craps table, which makes a payout-table error both easy to make and
expensive in both directions: a too-generous table silently drains the house
economy, a too-stingy one robs the player.

**Required:**

1. **Author the documentation.** Extend `house_edge_documentation` to cover every
   bet in every variant's allowed list. Derive each value from standard craps
   mathematics for the payout the table actually offers, and show the derivation
   in the report — the odds, the payout, the resulting return. Do not copy
   numbers from a web search without deriving them against this table's own
   payout entries and its `commission_percent` handling for buy and lay.
2. **Measure every bet.** Extend `tools/craps_rtp_audit.gd` so every documented
   bet gets a real `_audit_line`/`_rtp_row` measurement at the existing
   1,000,000-roll-per-bet floor, against the existing tolerance. The
   `required_full_table_bets` structural check stays; it is not a substitute.
   Cover both variants where their rules differ, and cover the vig path
   explicitly: buy and lay returns depend on when the commission is charged.
3. **Report every disagreement.** Where a measured return does not match the
   correct value for the payout offered, that is a defect. State the bet, the
   measured RTP, the correct RTP, the offending payout entry and the one-line
   correction.
4. **Do not change a payout on your own authority.** Correcting a payout table
   changes player money. Author the documentation and the measurement yourself,
   then bring any payout correction to the owner with the numbers and wait.
   Fixing the audit is yours; changing what the game pays is the owner's.

### 2.2 Eight verification tools wired into nothing — P1

Every probe written to verify this week's work is a one-shot script that no suite
runs. Verified: `craps_extensive_playtest`, `craps_rtp_audit`,
`craps_review_capture`, `crew_holdem_gameplay_audit`,
`crew_holdem_dynamic_table_audit`, `slot_autoplay_cadence_probe`,
`slot_foreground_autoplay_performance_probe` and
`blackjack_counter_surveillance_probe` each return **zero** matches in both
`tools/check_godot.ps1` and `tools/validate_project.ps1`.

A regression in craps settlement, Hold'em betting, slot autoplay cadence or
blackjack surveillance would therefore fail nothing.

**Required:** register the deterministic, headless-capable ones in the
`Audit`/`Full` suites of `tools/check_godot.ps1`, following the
`scenario_room_multiseed_finalization` precedent, and add a `Require-Text`
assertion in `tools/validate_project.ps1` so the wiring cannot be silently
dropped. Respect two limits: **nothing heavy goes into Smoke/contracts**, which
measured 227.786 s against a 230.391 s budget at `fix06_30` and whose budget
needs owner sign-off to raise; and a long RTP audit belongs in `Audit`/`Full`,
with a reduced-roll variant only if you can show the reduced run still fails on a
seeded wrong payout. Prove each newly wired gate fails on a deliberately broken
fixture before you call it a gate.

### 2.3 A content depth gate learned to skip itself — P1

`3f31bf10` ("fix: close Punchline route and contract runner gaps") changed
`scripts/core/scenario_sequence_schema.gd` so that `_validate_phase_graph` and
`_validate_aftermath` now skip their requirements when the scenario declares a
matching `owner_exceptions` row:

- `outcomes.size() < 3` is waived by a `choice_or_failure` exception.
- `aftermaths.size() < 3` and `material_axes.size() < 2` are waived by a
  `material_outcomes` exception.

A recursive scan of `data/**/*.json` finds **10 non-empty `owner_exceptions`
rows, all of them `world_connection`**, which is the pre-existing exception from
the `world06_*` rows. **Nothing in the shipped content uses either new
exception.** So a depth gate was taught to stand down, for no current consumer,
inside a commit whose subject is about routes and a contract runner.

**Required:** find out why it was added. Either (a) name the content that needs
it and record the owner's approval for that specific waiver, or (b) revert the
two new exception paths and keep the gate absolute. Do not leave an unused bypass
in a validator. Whichever you choose, record it in the decision log.

### 2.4 The Hold'em rebuild is unverified by anyone but its author — P1

`crew_draw_poker.gd` still exists and is still referenced by
`career_stats_view_model.gd`, `run_report_view_model.gd`,
`performance_fixture_setup.gd` and `perf_telemetry_overlay.gd`, while the
back-room table is now Hold'em. Three `mid_0_6` custody fixtures also reference
`crew_draw_poker`.

**Required, through the production host, not a unit harness:**

1. Play the back-room table end to end on at least three seeds: blinds, button
   movement, hole cards, all four streets, the variable no-limit raises added in
   `5f185f2c`, showdown and payout. Verify the pot arithmetic by hand on at least
   one full hand and show the arithmetic in the report.
2. Verify save and continue **mid-hand** and mid-session, and verify that the
   three `mid_0_6` fixtures and the 37 `v0_5_1` fixtures still load and round
   trip. A saved run that was inside the old draw-poker table must not fail to
   load.
3. Verify determinism: identical seed, identical hands, identical outcomes,
   across save/reload.
4. Decide what `crew_draw_poker.gd` is now — live game, dead code, or a
   compatibility shim — and say so. If it is dead, that is a finding to route,
   not something to delete in this row.
5. Confirm the career-stats and run-report surfaces report the Hold'em table
   correctly rather than under a stale draw-poker identity.

### 2.5 The week is missing from the record — P2

No board rows, no work-log lines, no archived prompts exist for any of the
commits in section 0.

**Required:** add a single retrospective board row for the 09-09/09-10 game work
under the Defects table, `DONE` or `VERIFIED` as your findings justify, with an
honest note naming what landed, what you verified, and what you routed onward.
Append one work-log line. This is bookkeeping so the next cold agent does not
rediscover a week of undocumented change; it is not an invitation to rewrite
history or restructure the board.

## 3. Also check, briefly, and report rather than fix

- **Coin pusher** (`f41d6db8`): stack cadence and item prizes changed, and the
  solver changed. Confirm the shipped-cap physics still passes its existing
  gates and that prize grants are exactly-once across save/reload.
- **Blackjack surveillance** (`9971aa2b`): confirm it changed detection behavior
  only, and that counting outcomes, payouts and RTP are untouched.
- **Slot autoplay** (`651f2a9f`, `4360b380`): confirm the idle-liveness counter
  is non-zero on the slot surface after both changes. This project has frozen
  idle animation four times; an idle draw cost of 0.000 is a failure, not a pass.
- **Venue game placement** (`28568d12`): it edited `archetypes.json` and
  `environment_instance.gd`, which is exactly the surface `fix06_31` is rewriting
  on `codex/fix06_31`. Do not touch those files. Note any interaction and route
  it to that row.

## 4. Acceptance

1. Every player-reachable craps wager has a derived documented house edge and a
   measured RTP at the 1,000,000-roll floor, with the audit extended to produce
   both. Any mismatch is reported with numbers; no payout is changed without the
   owner's explicit ruling.
2. The verification tools from this week's work run inside a suite, and each
   newly wired gate has been shown to fail on a broken fixture.
3. The `owner_exceptions` relaxation is either justified with a named consumer
   and owner approval, or reverted.
4. The Hold'em table is independently verified for rules, pot arithmetic,
   save/continue, fixture compatibility and determinism, through the production
   host.
5. The four section 3 items are checked and reported.
6. The week is on the board and in the work log.
7. `tools/validate_project.ps1` green on the exact head, and the `Audit` suite
   green.
8. No file that `fix06_31` owns is modified: `scripts/core/environment_*`,
   `scenario_layout_resolver.gd`, `pixel_scene_canvas.gd`,
   `environment_interaction_controller.gd`, `data/environments/*`.

## 5. Hard limits

- **Never weaken a test, budget, liveness floor or deterministic assertion to go
  green.** This row exists because a gate learned to skip itself.
- **No money change without the owner.** No RTP, payout, odds, wager math,
  economy or schema change on your own authority. Measuring is yours; changing
  what the game pays is not.
- **Do not revert this week's features.** Fix defects, do not undo work.
- **Delete nothing:** no branch, worktree, stash, tool or module. A module that
  looks dead is a finding, not a deletion.
- **Never stage owner property:** `.tmp/`, `.tools/`, `review_artifacts/`,
  `builds/`. Evidence lives under `.tmp/` and is cited by path and hash.
- **No release activity:** no version bump, tag, packaging, upload or publish.
- Leave no diagnostics in the tree. Commit at least every 30 minutes on a branch.

## 6. Standards every row inherits

- An idle draw cost of 0.000 is a failure, not a pass. Four recorded regressions.
- No per-frame deep copies. 32.6 ms/frame, once, in the slot bonus watchdog.
- Action boundaries, never wall-clock; everything seeded from run RNG.
- Exactly once: every consequence fires once across save, reload, travel,
  revisit, abort and expiry.
- Hidden state is absolute; a leak is an automatic P0.
- Native/Web parity is a requirement.
- Tab-indented, typed GDScript; PowerShell matching the existing `tools/` style.
- Cheap validation: `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1`.
  Targeted: `tools/check_godot.ps1 -Suite <Smoke|Contract|Audit|Full> [-FoundationSuite <name>]`.
  Godot: `.tools/godot-4.6-stable/Godot_v4.6-stable_win64_console.exe`.

## 7. Reporting

Report in this order, because the first item is the one that can cost the owner
money: the craps wager table — every bet, its documented edge, its measured RTP,
and every disagreement. Then the wired gates and their broken-fixture proofs.
Then the Hold'em verification with the hand you checked by hand. Then the
exception decision, the section 3 notes, and anything you routed onward.

Your terminal condition is that a second party can state, with numbers, that
everything this game pays out is what it is documented to pay out, and that a
regression in any of it would fail a suite rather than reach a player.
