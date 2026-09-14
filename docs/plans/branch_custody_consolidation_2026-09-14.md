# Branch Custody Consolidation — 2026-09-14

## Result

The repository again has exactly two durable branches:

- `main`: accepted, integrated product and documentation;
- `codex/wip-0.6-consolidated`: the sole continuation branch for explicitly
  deferred work.

The canonical launch folder is `D:\Projects\Beat-The-House` on `main`. The sole
worker checkout is
`D:\Projects\Beat-The-House-worktrees\wip-0.6-consolidated`.

No accepted completed product change was discovered outside `main`. The missing
Coin Pusher room cabinet was caused by launching the primary folder while it was
28 commits behind `main`; the cabinet implementation was already integrated at
`d2594eb3`.

## Method

Every one of the 36 local branches and 33 origin refs was checked for ancestry,
ahead/behind counts, patch equivalence, unique commit subjects, touched paths,
current-tree blob differences, worktree status and task-board disposition.
Every dirty worktree was inspected separately. A branch was deleted only after
its content was classified as integrated, superseded, rejected, historical, or
consolidated into the sole WIP branch.

## Local branch dispositions

| Branch or family | Assessment | Disposition |
| --- | --- | --- |
| `main` | Authoritative accepted tree | Kept |
| `codex/wip-0.6-consolidated` | Existing intended sole WIP branch | Kept, refreshed from `main`, validated and pushed |
| `codex/perf06-finish` | 13 useful deferred commits: performance contracts, tooling, report and telemetry support; binding run not complete | Merged into consolidated WIP, then branch deleted |
| `codex/playtest06-final-custody` | Existing custody work was on `main`; two untracked transaction tools were useful and their contract passed | Tools committed and merged into consolidated WIP, then branch deleted |
| `codex/reusable-environment-slots` | Rejected reusable-slot/fixture placement experiment; 65 changed paths and 558 generated review files | Excluded from both active trees; branch and artifacts deleted |
| `codex/fix06_31_solver_extract` | Three extraction-only commits raised the search ceiling and removed authored-placement protection | Rejected as incompatible with the owner’s room-construction decision; deleted |
| `codex/perf06-platform`, `-current`, `-root` | Historical browser-entropy alternative; current main intentionally validates Godot crypto instead | Deleted |
| `codex/env06_8`, `-stacked-backup` | Five unique old environment authoring commits superseded by accepted `env06_8`/`fix06_28` | Deleted |
| `codex/env06_8-presentation` | Head already in main; six dirty presentation files were stale alternate work | Worktree and branch deleted |
| `archive/env06-review-519fe930`, `-966bc69f`, `-9c4120fe`, `codex/closeout06-final` | Explicitly unreviewed/rejected alternate environment contracts and presentation paths | Deleted under the recorded no-port decision |
| `codex/agent-playtest-fixes` | Zero unique patches; both commits patch-equivalent on main | Deleted |
| `codex/backroom-poker-tweaks`, `codex/game-prop-art`, `codex/feat06_1` | Heads are ancestors of main | Deleted |
| `codex/fix06_32` | Six patch-equivalent commits plus two documentation/gate conflicts already resolved in the main replay | Deleted |
| `codex/balance06-pusher-ev-custody`, `codex/balance06-shard-hardening` | Balance tooling already represented on main; apparent unique commits were older teaching content now superseded by the accepted lesson tree | Deleted |
| `codex/depth-closeout` | Three historical closeout-document commits; product already accepted on main | Deleted |
| `codex/game-closeout`, `-acceleration`, `-exact`, `-final`, `-final2`, `-ledger-perf`, `-prefix-base`, `-retention-only` | Incomplete Blackjack probes, invalidated audits, WIP reports and one stale runtime variant; accepted game behavior and stronger replay limits are on main | Deleted |
| `codex/integ06-1-victory-root-pre-main-3c836d18`, `codex/integ06-composition-soak` | Old composition/save experiments and claim documents; current migration fixes are on main and the full soak remains deliberately deferred | Deleted |
| `archive/world-9eb-audit`, `codex/world-closeout` | Ten historical closeout commits; product paths were landed and subsequently superseded on main | Deleted |
| `codex/wip-0.6-consolidated` historical tree | The old branch differed from main by 581 paths, but only two were branch-only: its manifest and handoff; no runtime path existed only there | Preserved as the sole WIP branch and refreshed from current main |

## Uncommitted and untracked dispositions

| Location | Material | Assessment and disposition |
| --- | --- | --- |
| Primary project | 558 rejected spawn-slot captures | Deleted |
| Primary project | Seven `feat06_1` visual review files | Completed evidence already represented by the landed report; deleted |
| Primary project | `maint01` cleanup prompt | This execution record; archived under `docs/todone` |
| `Beat-The-House-env06_8` | Six files, 541 additions/25 deletions | Old presentation alternative covered by the no-port decision; deleted |
| `baseline-single-plane` | Nine-line travel-audit patch | Main already uses the production-capped `travel_target_ids` route with explanatory coverage; deleted |
| `game-closeout-retention-only` | 16-line Blackjack replay-window patch | Main contains the same active replay limit plus safer nested-value isolation and rehash behavior; deleted |
| `perf-baseline-67ab` | Three runtime files plus one authority probe | Main contains the resolved-catalog marker and memo-v2 authority projection in stronger form; deleted |
| `agent-playtest` | Two untracked session-harness files | Identical functionality already integrated on main; deleted |
| `playtest06-final-custody` | Two evidence-transaction tools | Contract passed; committed and retained on consolidated WIP |
| Owner build candidate | Temporary copied source, generated builds/tools and three untracked evidence documents | Temporary candidate was obsolete; registration and residual directory deleted |

The pre-existing external safety archive at
`D:\Projects\Beat-The-House-cleanup-archive` remains outside Git. It is not an
active branch or worktree and was not used as a substitute for integrating good
work.

## Remote cleanup

Thirty-one origin branches were deleted. Remote-only refs were either
patch-equivalent to main or belonged to the same retired balance, environment,
integration, performance, playtest, tutorial, game, or closeout families above.
After a prune, origin exposes only `origin/main` and
`origin/codex/wip-0.6-consolidated`.

## Ongoing rule

Do not leave future work on a durable task branch. A completed change lands on
`main`; a worthwhile unfinished change is consolidated into
`codex/wip-0.6-consolidated`; rejected or superseded work is deleted after
review. The repository must return to two branches at the end of every task.
