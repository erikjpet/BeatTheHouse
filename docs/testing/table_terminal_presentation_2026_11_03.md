# BTH061-TABLE-ENDING: finish the hand before the run report

Implementation commit: `776a819d0420c8801708b20b5e9376c5fd0d15fe`.
Status: focused and integrated native checks passed; direct main push denied by
automatic approval review, so NEXT publication is blocked.
Owner report: a final table decision immediately opens the ending before the
player can see the losing hand. No original player save was supplied or changed.

## Reproduction and root cause

The isolated native reproduction uses the original `FoundationMain` from main
`8d3c52756d99a315050e62601b5da3531ddef0c4`, a synthetic fixed Blackjack shoe,
normal Deal, all-in confirmation and Stand. The wager leaves a live hand at
zero cash, then Stand settles one hand and immediately removes the game surface
for `FAILURE`. Receipt: `task-11/evidence/terminal-baseline-repro.log` and
`baseline-source-identity.json`; the owned process exited 0 with
`reproduced=true`. This is a production-host action reproduction with synthetic
inputs, not a replay of the reporter's save or a visual Web playtest.

The all-in flag was overwritten by later zero-cost decisions. The terminal
evaluator also cleared the active game before the accepted result's animation
could finish. Autosave preparation can reach this evaluator before the new
surface snapshot has even been published.

## Change

- Retain the confirmed all-in hand's protection through later decisions and
  automatic settlement. Rejected actions cannot clear it. Completed embedded
  results proceed to normal terminal evaluation.
- Keep settlement, RNG and terminal classification authoritative. Defer only
  navigation to the terminal report: publish the accepted result, wait for its
  finite animation/money-reveal boundary, then allow 1200 ms to read the hand.
- Keep ordinary autonomous rendering and realtime presentation running. Block
  new gameplay, Back and automation while a terminal result is being shown.
- Exclude indefinite interactive channels from the report wait. The reading
  interval also covers the final renderer handoff, including reduced motion.
- Bridge Rourke's existing phase-5 profile staging, phase-6 profile processing
  and phase-7 report ownership explicitly. Its action pipeline releases before
  the shared result wait routes the report.
- Reset transient wait state on lifecycle changes. A settled terminal save
  continues directly to its correct report without replaying settlement.

The shared route was source-reviewed for Blackjack, Baccarat, Roulette, Craps,
Bar Dice, Crew Hold'em and Video Poker. They publish result animation channels;
this is not a claim of visual runtime coverage for every game.

## Focused evidence

Commands use the task-private `run_owned.py` wrapper, the pinned Godot 4.6
`89cea1439` runtime, disposable storage, a 5% aggregate CPU hard cap, 2 GiB Job
limit and a finite deadline. Every completed receipt records zero active owned
processes at release. Raw receipts remain in `task-11/evidence/` outside Git.

| Script / receipt label | Result and scope |
| --- | --- |
| `table_terminal_presentation_check.gd` / `terminal-final` | PASS, 68 checks: normal host all-in Blackjack Stand loss, Hit bust, ordinary loss that continues the run, reduced motion, Baccarat all-in loss, blocked extra input/automation/Back, exact animation/read boundary, Save and new-host Continue with unchanged cash/chips/RNG/clock/shoe/outcome and one settled hand. |
| `rourke_phased_interruption_check.gd` / `terminal-rourke` | PASS: terminal parity, shared animation/read interval, automatic report, Main Menu and cold Continue, failed Save/retry, teardown and pending-save auto recovery. Settlement count stays one. |
| `terminal_run_resume_check.gd` / `terminal-resume` | PASS: both failed and successful terminal checkpoints persist and Continue returns to the correct report. |
| `craps_working_stakes_terminal_check.gd` / `terminal-craps` | PASS, 16 checks: working stakes and terminal evaluation retain their financial contract. |
| `animation_liveness_without_pointer_check.gd` / `terminal-liveness` | PASS: autonomous environment, placement-overlay and game animation remain live without pointer input. |

After integration with concurrent native-renderer cleanup and Back Alley fixes,
the exact implementation commit `776a819d` passed the table check again (68
checks, `terminal-integrated`) and the complete Rourke interruption check again
(`terminal-rourke-integrated`). Product files did not change between these
checks and the subsequent task-record update. The terminal-resume, Craps and
liveness receipts above qualify the unchanged contracts tested before that
integration; they are not relabeled as fresh passes on a new build. Independent
source review found no remaining concrete issue in the terminal wait or its
Rourke integration.

Earlier failed exploratory checks are retained rather than overwritten. They
identified the initial all-in hand boundary, the actual accessibility setting,
and the need for a finite-channel query. Godot emitted restricted-environment
certificate-store warnings; the table harness also emitted shutdown resource
warnings. No assertion or script error remains in the passing checks above.

NEXT identity, served artifacts and basic startup are tracked separately after
the scoped commits are pushed. Local native passes alone do not establish
deployment or visual Web gameplay. Stable, itch and hosting audience are outside
this change.

## Publication blocker

Automatic approval review rejected the proposed `git push origin HEAD:main` to
`https://github.com/erikjpet/BeatTheHouse.git`. It considered this an external
commitment to the remote default branch and said the visible authorization for
NEXT did not explicitly authorize that exact destination. The compound command
was rejected before execution; no push occurred. No alternative remote write,
watcher restart or manual deployment was attempted. A subsequent local-only
task-record commit succeeded. Personal-context retrieval was unavailable, so no
additional prior direct-main authorization could be recovered here.

Required next evidence is explicit human authorization for this direct main
push, then one permitted retry of the denied operation and normal watcher/
served-identity/startup verification. The code fix is committed and tested; the
task remains open until publication and NEXT verification finish.
