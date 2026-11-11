# Beat the House 0.6.1 — review of the first worker run and closeout plan

Review date: 2026-11-11
Reviewed: `main` at `2113db415ce3639eb546caaaf58d582782e30bc7` (66 commits after
`06e5492`), the worker's final report, its delivery receipt, and its proof
files under `docs/testing/`.
Method: read the diffs, the proof documents and the raw Smoke evidence the
worker committed. Nothing was run; Godot is not available in the review
environment.

---

## 1. Verdict on the worker's run

**The work is sound and the report is honest.** Use it as a basis.

What I checked and found correct:

- **The code changes match the work orders.** Runtime diff is 25 files,
  +795 / −94. I read the changes for AUD061-01, -02, -08, -09, -10, -14, -15,
  -16 and QOL-01, -02, -03 line by line against what each order specified.
  Examples: the stale-rollback refusal became a cleanup with the
  `stale_rollback_undeletable` code; the three Crew bankroll writes use
  `change_bankroll(delta, true)`; the debug switches are gated on
  `distribution_build()` at their read sites; `save_run` and `clear_run` no
  longer return an older worker's failure.
- **No test was weakened.** 15 new check scripts, additions to 4 existing
  ones, 1,345 lines added and 2 removed (both are moved lines).
- **No game math, item, scenario, pipeline guard or version file was
  touched.**
- **It stopped where it was told to stop.** AUD061-04 hit a real conflict and
  the worker reported it instead of working around it.
- **It distinguishes what it proved from what it did not.** The eight findings
  are each labelled as defect, test discrepancy or coverage gap.

Three things to correct going forward:

1. **Evidence volume.** The run added 2,446 files and 647,000 lines to `main`;
   `docs/testing/` is now 78 MB. Most of it is storage manifests, job records
   and launch receipts. From now on, commit the proof summary and a hash list;
   keep raw evidence in `E:\CodexQA\BTH` and point to it.
2. **"Failed" is the wrong word for AUD061-11 and -17.** Those were test
   runs. They ran and produced findings, which is the job. Their status is
   "done; findings open".
3. **The most important fact is in a footnote.** The Smoke suite fails 7 of
   11 stages on `main`, and did before the worker started. See section 2.

---

## 2. The real gap: the Smoke suite is red on `main`

This was not in my audit because I could not run Godot. The worker ran it,
recorded "4 pass / 7 fail" as its baseline, and correctly left it alone. But it
means **the project's own first gate has not passed for some time**, and every
run since has been measured as "no worse than red". The release-week queue had
a task for exactly this (T6, "Test repair") that was left IN PROGRESS.

From the worker's committed baseline evidence
(`docs/testing/evidence/AUD061-01-02_20261110/aud061-baseline-smoke-20261110/smoke/`),
this is what fails, sorted by what I think it is. **These classifications are
my reading of the failure text, not confirmed.**

### Likely real, and a player would notice

| Failure | Stage | Why it matters |
| --- | --- | --- |
| "The tutorial wager lesson did not accept the real on-felt blackjack chip action." | `foundation_smoke_runtime` | A new player's first Blackjack lesson may not advance |
| "The real Pull Tabs counter result could not satisfy Pal's redemption lesson" | `ui_scene_compile` | Same, for the Pull Tabs lesson |
| "Damaged sealed geometry was published as a room" / "passed strict authority validation" / "did not preserve the previous save" (4 assertions) | `cold_continue_room_projection` | A broken room can be shown instead of rejected |
| Grand Casino layout overlap: `casino_fixture:host_desk` and `staff:grand_casino_host` | `foundation_smoke_content` | Two objects drawn on top of each other |
| Per-frame cost tripwire: `scripts/games/blackjack.gd:1485` (`_draw_blackjack_ritual_layer`), `scripts/ui/game_props/street_craps_circle_prop.gd:89-90` (`_draw_chalk_game`) | `foundation_smoke_content` | Allocation inside a draw call; the project's own performance rule |
| Performance smoke (10 error categories) | `foundation_perf_smoke` | Unknown until read |

The two tutorial lines are the ones to check first, in the actual game, as a
new profile. If the lessons do advance in play, the checks are stale. If they
do not, that is the most serious problem in the build.

### Likely stale tests or stale generated files

| Failure | Stage | Probable fix |
| --- | --- | --- |
| "environment scenario layout breakdown is missing or stale" | `validate_project` | Run `python tools/generate_environment_scenario_layout_breakdown.py` and commit the output |
| Parse error, `scripts/tests/rourke_prepared_surface_route_check.gd:28`: override does not match parent `select_game_action(String, String, bool, bool)` | `gdscript_load_check` | Update the override's signature |
| Parse error, `tools/scenario_presentation_probe.gd:12`: `check()` called with one argument | `gdscript_load_check` | Pass the missing argument |
| 15 "S0.2 Kitty Cat Lounge generated layout overlaps" | `foundation_smoke_content` | Probably checks a generated layout that the accepted hand placements replaced; confirm in the room, then point the check at the placement authority |
| 5 "initial arrival… production room finalization failed: Object manifest is missing" | `foundation_smoke_runtime` | The test harness builds a room without the object manifest the slot system now requires |
| 4 "Talk content migrated event … changed bankroll/heat consequence" | `foundation_smoke_content` | Data changed on purpose since the expectation was pinned; confirm each, then update the expectation |
| "ActionResult leaked UI state key: ui_state" (2); "Foundation UI shell contains game-specific token `pull_tab` / `blackjack_`" (2) | `foundation_smoke_runtime` | Architecture lint; either real leaks added by recent fixes or a rule that needs an allow-list. Read before deciding. |
| "Environment contract did not include debt/lender hooks / suspicion cues / narrative flags" (3); "EventModule returned an unsuccessful result" (2); "missing sealed event presentation authority" | `foundation_smoke_runtime` | Likely downstream of the harness problem above; re-check after it is fixed |

### Text rule

| Failure | Fix |
| --- | --- |
| Lender `the_crew` description is 9 words (limit 8): "Cash for two package deliveries. No repayment or interest." | Shorten by one word |
| Event `crew_favor_delivery` summary is 9 words: "The Crew wants a package delivered. No cash repayment." | Shorten by one word |

**Getting Smoke to green is the main remaining work for 0.6.1.** It is CLOSE-01
in section 4.

---

## 3. Disposition of every unfinished item

"Drop" means: close it in the ledger with the stated reason; no more work.

### AUD061-04 — version stamps (blocked) → **reduced by owner decision; one variable**

The block is real and it is not the worker's fault. The NEXT builder lives in
the site repository (`D:/Projects/site/scripts/build-bth-next-gdscript.ps1`).
To reuse a previously built native export, it pins exact file contents:
`project.godot`, `export_presets.cfg`, and `tools/export_itch.ps1` (plus four
other exporter files). Changing a version number in any of them makes the
fast builder refuse.

**Owner decision (2026-11-11):** the number itself does not matter yet; the
project is mid-revision. What is wanted is **one variable** that can be
switched to 0.6.1 at release. No re-pinning of the builder now.

So the version the player sees moves into a file the builder does not pin:

1. Add `const RELEASE_VERSION := "0.6.0"` to `scripts/core/build_identity.gd`.
   This is the one variable.
2. `display_version()` returns `RELEASE_VERSION` in a source run, and
   `RELEASE_VERSION (short commit)` in an exported build with a valid
   manifest, for example `0.6.0 (2113db415ce3)`. The short commit comes from
   the manifest's `source_commit`.
3. Remove `DEVELOPMENT_VERSION`; nothing else should carry a version literal
   for display.
4. Leave `build_version`, `telemetry_identity()`, `project.godot`,
   `export_presets.cfg` and `tools/export_itch.ps1` untouched. The packaging
   and performance tools key on them and the builder pins them.
5. Update `scripts/tests/fixsweep06_1_packaging_runtime_contract.gd` so it
   asserts the menu shows `BuildIdentity.RELEASE_VERSION`, not a literal.

At release the owner changes that one line to `"0.6.1"` and pushes; NEXT
updates through the normal fast path.

**Known leftover, recorded so it is not a surprise:** the Windows file
properties, the Android and iOS preset versions, the project setting and the
internal `0.6.0-dev+…` build identity will still say 0.6.0 after that switch.
Players do not see them in the game. Bringing them in line needs the builder's
pins updated once, which the owner has chosen not to do now.

### AUD061-12 — Web export failure (not reproduced) → **drop**

Nine full exports under the original 2 GiB cap passed, on current source and
on the two historical commits that failed. NEXT has promoted over sixty builds
since. More attempts will not find it. Close AUD061-12, `BTH-NEXT-ALLOC-001`
and the export half of `BTH-BARDICE-WARM-PROGRESSION-001` as "not
reproducible; reopen on recurrence".

One thing worth keeping from the investigation: the progress marker points at
loading `main.tscn` and `foundation_main.gd`, a 25,000-line script. If the
failure returns, that is where to look, and it is one more reason for STR-01.

### AUD061-11 and AUD061-17 — acceptance and coverage runs → **done; findings below**

### The eight findings

| ID | What it is | Disposition |
| --- | --- | --- |
| `BTH061-RC-BARDICE-COVER-CLIP-001` | **Real, visible.** | **Fix** — CLOSE-02 |
| `BTH061-RC-BARDICE-COLD-001` | Test and popup interaction | **Fix the test** — CLOSE-03 |
| `BTH061-RC-COUNT-EXPECTATION-001` | Test reference rounds a float | **Fix the test** — CLOSE-03 |
| `BTH061-RC-RIVERBOAT-FIXTURE-001` | Test stub never builds the dialogue dock | **Fix the test** — CLOSE-03 |
| `BTH061-RC-SCRATCH-STATE-001` | In-memory difference after Continue, saved bytes identical | **One diagnostic step, then close** — CLOSE-03 |
| `BTH061-RC-ACCEPTANCE-COVERAGE-001` | Coverage gap | **Run it** — CLOSE-06 |
| `BTH061-RC-NATIVE-RETENTION-001` | A measurement could not be taken | **Drop for 0.6.1** |
| `BTH061-RC-PACKAGING-001` | Version stamps plus the final build | **Reduced** — CLOSE-04 and CLOSE-05; stamps other than the menu stay 0.6.0 by owner decision |

Details:

- **Cover clip.** Cause found. `scripts/games/bar_dice.gd:3297` builds
  `"COV … · RISK … · RET …"` and cuts it at 34 characters with `.left(34)`.
  In cash each amount is short (`$6`). In chips each is written out
  (`6 CHIPS`, from `scripts/ui/player_text.gd:121-125`), so the line is about
  44 characters and the RET value is cut off. Line `:3296` has the same
  pattern with `.left(29)`.
- **Bar Dice cold.** The assertion at
  `scripts/tests/bar_dice_reveal_save_restore_check.gd:306-310` checks two
  things in one statement: that the tumble animation has ended after a fixed
  wall-clock wait, and that the account did not change. A Health Inspector
  popup is open at that moment, and an open popup pauses timed surface
  animation, so the animation is still "active" and the combined check fails.
  The account half is probably fine; the test cannot tell.
- **Count expectation.** The stored value is exactly 64/430. The test's
  reference file was written with ordinary JSON number formatting and differs
  in the last bit. Cash, chips, RNG and payout all match.
- **Riverboat.** `scripts/tests/riverboat_closing_departure_check.gd` replaces
  `_ready` with a stub, so the dialogue dock is never built, and the production
  guard correctly refuses a dialogue choice with no dock. The broader closing
  and travel checks pass 83 of 83.
- **Scratch state.** Saved files compare identical leaf by leaf; only a strict
  in-memory comparison differs, and money, RNG and inventory match. This looks
  like the integer-versus-float typing described in STR-03, or a transient
  display field.
- **Native retention.** The probe measures Coin Pusher input-trace memory on
  the native solver, which the QA clone does not have. The plan lists the
  performance measurements as P2 and not release-gating.

### Optional coverage the worker left partial (-003, -004, -008, -011, -009/-010)

**Drop for 0.6.1.** They are the plan's P2 and "coverage pending" rows. They
are better done by a person playing NEXT than by more scripted runs. Keep them
open in the ledger for after release.

---

## 4. Work orders for the closeout

### CLOSE-01 — Bring the Smoke suite to green

**Why.** Section 2. A release cannot be called qualified against a red gate.

**How.** One failure at a time, in this order:

1. The two tutorial lessons. Start a new profile on NEXT and play the first
   night through the Blackjack wager lesson and the Pull Tabs redemption
   lesson. Record whether each advances. That decides whether the product or
   the check is wrong.
2. The three trivial ones: regenerate the layout breakdown; fix the two parse
   errors.
3. The harness "Object manifest is missing" failure, then re-run the runtime
   stage, since several other failures probably fall away with it.
4. Everything else in section 2, each classified as product defect, stale
   expectation or stale harness **with the evidence for the classification
   written down**.

**Rules.** Fix the product when the product is wrong. Update a test only when
it encodes behavior that was deliberately replaced, and say what replaced it.
Never delete or skip a check to get green. The four "damaged sealed geometry"
assertions guard against showing a broken room: if they fail because
validation was loosened, that is a product fix, not a test update. Text edits
to the two over-long lines are permitted.

**Done when** `tools/check_godot.ps1 -Suite Smoke` exits 0 on the candidate,
or every remaining failure has a written owner-accepted reason.

### CLOSE-02 — Bar Dice financial line is cut off in chips

**Change.** In `_draw_bar_room` (`scripts/games/bar_dice.gd:3293-3297`):

1. Stop truncating numeric text. Remove `.left(34)` and `.left(29)` from these
   two labels.
2. Make the chip form fit instead: state the currency once and print bare
   numbers, for example `CHIPS · COV 6 · RISK 6 · RET 0`. Cash stays
   `COV $6 · RISK $6 · RET $0`.
3. Do not change the values, who owns them, or anything in the rules.

**Check.** Extend the existing cover-display check with chip amounts of one,
three and four digits and assert the full RET value is drawn inside the box at
1280×720. Verify on NEXT in Grand Casino practice.

### CLOSE-03 — Four test repairs

1. **Bar Dice cold.** Split the assertion into two checks so each reports on
   its own. Before waiting for the tumble, dismiss any open event popup through
   its normal control. If the account check then fails, stop and report: that
   would be a real defect.
2. **Count.** Write the reference with the same number formatting the game
   uses for saves (`StorageNumericJson`), or compare the float from the save
   bit for bit. Do not round the production value.
3. **Riverboat.** Build the real dialogue dock in the fixture, or drive the
   case through the public path the passing closing checks use. Keep the
   production guard. Then do one rendered Delta Queen closing-time ride on
   NEXT.
4. **Scratch.** Print the first differing leaf with its type on both sides.
   If it is integer versus float, or a field that exists only for display,
   normalize the comparison and record why. If a real value differs, stop and
   report.

### CLOSE-04 — One version variable

As described in section 3 under AUD061-04: `RELEASE_VERSION` in
`scripts/core/build_identity.gd`, shown on the menu with the short commit. No
pinned file changes. Check on NEXT that the footer reads `0.6.0 (<commit>)`,
then confirm in a source run that changing the constant alone changes the
menu text, and change it back.

### CLOSE-06 — Remaining acceptance coverage (owner decision C2)

The owner wants the agent to run the missing acceptance cases, and will
playtest afterwards.

1. **Three rendered flows on NEXT, in the browser, through normal controls:**
   the Crew offer → accept → return to the game in progress
   (`BTH-GAME-RETURN-001`); the expired Jazz Club Crew handoff
   (`BTH061-CREW-EXPIRED-HANDOFF`); and choosing an offered Meta item at the
   showdown (`BTH061-AUDIT-SHOWDOWN-META-CHOICE-FIX-031`).
2. **All eleven games, save and Continue (`BTH061-006`).** For each game:
   enter, place a paid action, save while it is unfinished, reload the page,
   Continue, and finish. Record wallet and inventory before and after and
   confirm the outcome settles exactly once. Include held Video Poker cards,
   working Craps bets, an unopened and a partly opened Scratch ticket, a Pull
   Tabs ticket in the tray, Slot autoplay or bonus, coins on a Coin Pusher
   bed, and a Crew poker hand mid-street.
3. A case that cannot be reached (for example a sold-out ticket slot) is
   recorded as not reached, with what was tried. It is not a pass.
4. A failure is a new finding with its own ID and reproduction. Do not fix it
   inside this task unless it is a one-line regression from this run.

### CLOSE-05 — Final candidate

After CLOSE-01 to -04 and CLOSE-06: freeze `main`, record the commit as the release
candidate, run Smoke, animation liveness and the Python tests on it, build
Windows and Web with `tools/export_itch.ps1`, launch each once, and hand the
owner the paths and SHA-256 hashes. Tagging, renaming and uploading are the
owner's.

---

## 5. Owner decisions (answered 2026-11-11)

| # | Question | Decision |
| --- | --- | --- |
| C1 | Version bump and builder re-pinning | **Decided:** not now. One variable instead (CLOSE-04). |
| C2 | Remaining acceptance coverage | **Decided:** the agent runs it (CLOSE-06); the owner playtests after all work is complete and reports anything further. |
| C3 | Close the Web export failure as not reproducible | **Decided: yes.** |
| C4 | Drop the native retention measurement and the P2 coverage rows for 0.6.1 | **Decided: yes**; they stay open for after release. |
| C5 | Shorten the two over-long lender and event lines | **Decided: yes.** |
| C6 | Keep raw evidence out of the repository from now on | **Decided: yes.** |
