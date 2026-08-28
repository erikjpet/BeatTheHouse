# game06_6 BAR-DICE dependency replay manifest

Status: **UNREVIEWED / PRE-STAGED ONLY**

Purpose: define the exact intake, replay, verification and evidence required to
turn frozen contract-only BAR-DICE head
`348ecd55886fb6c167b9ca2fa8a51e272a9939fb` into a new implementation
candidate after its dependencies are resolved. This document authorizes no
merge, gate, product edit, dependency selection or acceptance verdict.

The frozen source remains `codex/game06_6-contract-only` at `348ecd55`. Never
advance, rewrite, rebase or add a documentation commit to that branch. Perform
the future replay on a newly named branch and worktree.

## 1. Required immutable intake

Do not create the replay branch until every field below has an exact full commit
identity and an Integrator-authored acceptance record.

| Input | Required identity/evidence | Fail-closed condition |
| --- | --- | --- |
| BAR-DICE contract-only source | exact commit `348ecd55886fb6c167b9ca2fa8a51e272a9939fb`; tree identity; clean status; commit list `6251c232..348ecd55` | source ref moved, tree differs, working tree is dirty, or any source commit is unreachable |
| accepted `game06_1` successor | exact immutable product head; independent acceptance verdict; Gate Service report; accepted integration/main commit; proof it supersedes frozen contract `a2760d816c781e711ff0923c296f97b786662453` | only `a2760d81`, rejected `932287ba`, an unreviewed successor, or a head changed after review is supplied |
| owner-resolved `craps06_3` | written owner decision; exact accepted core head; exact accepted environment/package head when the decision retains that slice; independent verdicts and gates; accepted integration/main commit(s) | frozen/rejected core `e8cc589e` or `8ad3dd11`, frozen/rejected environment `872d09a9`, a third ordinary remediation cycle, or an unrecorded owner choice is supplied |
| replay base | exact current `main` commit and tree at replay start; clean dedicated worktree | moving or red main, detached unnamed work, dirty tracked state, or a base other than current accepted main |
| native runtime | canonical Godot identity; built native plugin path, SHA-256, descriptor SHA-256 and native source-tree identity approved by the Integrator | copied/stale/unhashed DLL, binary outside the replay worktree, source/binary mismatch, or native backend not proven loaded |

The owner decision must state which `craps06_3` semantics are authoritative for
BAR-DICE. At minimum the accepted dependency must expose, without BAR-DICE
copying Craps state or logic:

- cash-only teaching/guidance envelope and its one-time progress receipts;
- warning and lookout-pressure facts;
- adjacent-sweep and heat-spike interruption facts;
- pending cash returned uncommitted;
- working stake recovery at the accepted face-value rule;
- persisted dispersal reason and aftermath receipt;
- revisit/inactive behavior and relocation result, if retained by the owner
  decision.

If the owner splits or reduces `craps06_3`, the decision must name the successor
row that owns any missing capability and say whether `game06_6` remains blocked.
Do not infer that a partial slice is sufficient.

## 2. Intake identity record

Before replay, the Integrator records `dependency_intake.json` with:

```text
schema
captured_at_utc
bar_dice_source_commit / tree
game06_1_source_commit / tree / verdict / gate_report
game06_1_integration_commit
craps06_3_owner_decision_id
craps06_3_core_commit / tree / verdict / gate_report
craps06_3_environment_commit / tree / verdict / gate_report (or explicit N/A)
craps06_3_integration_commits
replay_base_main_commit / tree
godot_path / sha256
native_descriptor_path / sha256
native_plugin_path / sha256
native_source_tree
```

Each path must resolve inside the dedicated replay worktree except source
reports intentionally referenced by immutable hash. Hash the record itself and
carry that digest into every later report.

Required read-only checks:

```powershell
git cat-file -e <full-sha>^{commit}
git rev-parse <full-sha>^{tree}
git merge-base --is-ancestor <accepted-integration> <replay-base-main>
git diff --quiet <recorded-head>^{tree} <current-ref>^{tree}
git status --porcelain=v1
Get-FileHash <native-plugin> -Algorithm SHA256
```

Any failed identity check stops replay. Never repair an intake mismatch by
editing the manifest, retagging a head or reviewing a moving branch.

## 3. Replay construction

1. Create a new named worktree and branch directly from recorded current main,
   for example `codex/game06_6-dependency-replay-<date>`.
2. Reconfirm current main and both accepted dependency integrations are exactly
   the identities in `dependency_intake.json`.
3. Apply the net semantic payload of `348ecd55` by three-way replay. Do not
   replace directories wholesale. Preserve current-main versions of shared
   files and resolve overlaps semantically.
4. Verify the replay contains exactly the frozen row-local contract payload:
   - `data/games/bar_dice_game_ritual_v1.json`;
   - `scripts/core/bar_dice_ritual_projection.gd`;
   - `scripts/tests/foundation/game06_6_bar_dice_contract.gd`;
   - `tools/game06_6_bar_dice_platform_probe.gd` and `.tscn`;
   - BAR-DICE plans and evidence.
5. Bind the accepted `game06_1` envelope/runtime without adding a second action,
   receipt, persistence, handler or settlement path.
6. Bind accepted `craps06_3` teaching/dispersal facts through its public seam.
   `scripts/games/craps.gd`, Craps rules/data, environment packages and shared
   runtime remain read-only to the BAR-DICE squad.
7. Implement the depth row only in its assigned product ownership, chiefly
   `scripts/games/bar_dice.gd` and row-local tests/assets explicitly granted by
   the program director. Preserve every shipped rule, probability, payout,
   rake, carry, press, cheat grade, heat and item effect.
8. Commit logical WIP at least every 30 minutes as `UNREVIEWED`. No stash,
   unnamed detached HEAD, uncommitted handoff or unreachable branch is allowed.

The replay must fail closed if a rejected throw charges or advances, if a
presentation phase rolls/scores dice, if actor/tell/onlooker state consumes RNG,
or if BAR-DICE independently decides a street interruption or refund.

## 4. Semantic overlap audit

Before review, compare all three bases and record each overlap:

```text
current main -> game06_1 accepted integration
current main -> craps06_3 accepted integration(s)
current main -> frozen BAR-DICE payload
accepted dependency integrations -> replay candidate
```

For every overlapping path, the audit names the owning row, symbols changed,
resolution chosen and focused proof. The following are never resolved by
wholesale source replacement:

- ritual envelope dispatch, action validation, handler registry, receipts,
  restore and energy-tier APIs;
- Craps teaching, dispersal, warning, interruption, refund and revisit seams;
- Bar Dice wager/resolve/state normalization, RNG consumption, skill graders,
  pot/rake/payout/carry/press, surface input and save/load code;
- shared UI/runtime/assembly files.

The audit must prove `_apply_delivery_resolution()` and environment/world
delivery code are untouched; they are outside this row.

## 5. Required focused correctness gates

Run these on the frozen candidate head after all edits stop:

- project validation and import/load checks;
- frozen `game_ritual/1` vocabulary suite, including all negative fixtures and
  neutrality targets;
- `game06_6_bar_dice_contract.gd`;
- accepted `game06_1` contract/runtime focused suite;
- accepted `craps06_3` focused teaching, dispersal, interruption, recovery,
  persistence and revisit suites;
- Bar Dice full rules/scoring matrix: five dice, at most three shakes, ordered
  6-5-4 acquisition, cargo comparison, ties, no-qualifier and all outcomes;
- exact wager lifecycle and money conservation for accepted, partial, refused,
  interrupted, carried and settled covers;
- stake ladder, participant pot, edge-tier rake, payout, carryover and press;
- controlled roll, palmed swap, grade, item, alcohol, luck, watch and heat paths;
- rejection atomicity and no double throw/settle/out-of-turn/stranded wager;
- save/load, exit and revisit at every seven-phase boundary;
- ten-seed opponent/onlooker/tell determinism and outcome noninterference;
- hidden-state noninterference and future-result nonleakage;
- exact accepted Craps seam reuse with no duplicated consequence.

All failures, reruns and remediation commits remain in the evidence history.
Tests, budgets, baselines, economy and tuning may not be weakened to obtain
green.

## 6. Mandatory platform and broad gates

These are Integrator/Gate Service work on one immutable candidate; the
implementation squad does not self-accept them:

1. Native focused BAR-DICE, `game06_1` and `craps06_3` gates with the approved
   native plugin loaded and reported by identity.
2. Web focused BAR-DICE, `game06_1` and `craps06_3` gates from a fresh export
   built from the same candidate tree.
3. Exact native/Web action, phase, receipt, fact, persistence and visual-state
   parity across ten seeds, including partial/refused cover and interruption.
4. Probability/RTP and payout nonregression against shipped immutable rules;
   exact economy conservation; no tolerance or sample-count reduction.
5. Performance and liveness: action paths, idle life, animation windows,
   disabled-overlay/control probes and low-end Web budgets. Every energy tier
   changes actor plus object/interactable state.
6. Accessibility: keyboard/controller/pointer/reduced-motion equivalence,
   focus, minimum targets, small-screen layout, non-color state labels,
   obstruction and text safety.
7. Relevant Foundation suites at minimum: contracts, bar_dice, games, systems,
   UI scene compile/flow, save/migration, determinism and performance.
8. Complete Smoke, then the program's full gate on the exact candidate head.
   A pre-existing red main or suite red blocks landing and is not attributed to
   BAR-DICE without a clean-parent comparison.

The Integrator decides exact suite command lines and locked durations. Broad or
expensive jobs are never launched from this pre-staging branch.

## 7. Visual and playtest evidence

Capture native and Web from the exact candidate for:

- quiet bar and crowded/tense bar;
- wager proposal, accepted cover, partial cover and refused cover;
- shake, throw, reveal and call;
- win, bad beat, carry and press;
- warning, sweep/heat interruption, returned cash and revisit aftermath;
- cheat/tell presentation without future-result leakage;
- reduced motion, keyboard focus, controller focus, small screen and colorblind
  labels.

Expected artifacts:

```text
dependency_intake.json + sha256
replay_overlap_audit.md
ownership_diffstat.txt
candidate_handoff.json
suite_summary.json
focused_game06_6.json
focused_game06_1.json
focused_craps06_3.json
rules_probability_payout.json
economy_conservation.json
determinism_10_seed_native.json
determinism_10_seed_web.json
native_web_parity.json
performance_liveness.json
accessibility.json
native_report.json / web_report.json
native and Web capture manifests/contact sheets
full_gate_summary.json
artifact_hash_manifest.json
```

Reports under `.tmp/`, `.tools/` and `review_artifacts/` stay untracked. The
handoff references them by absolute path and SHA-256; it never stages owner or
Gate Service artifacts.

## 8. Freeze and handoff protocol

After the final product commit:

1. stop editing and record the full candidate commit and tree;
2. prove tracked clean status and list all untracked/ignored evidence separately;
3. record base-to-head commits and one-sentence purposes;
4. run `git diff --check`, ownership diff-stat and a complete semantic diff;
5. hash every report, capture manifest, contact sheet, native binary and export;
6. give the exact immutable head to an independent reviewer and Integrator;
7. reject any verdict or gate report naming a different commit/tree/binary;
8. if the candidate changes after review, void acceptance and repeat review and
   all affected gates; feature-freeze allows only changes required to make a
   currently red gate pass;
9. the Integrator lands by three-way merge and runs post-land Smoke on exact
   main; no squad merges or advances main.

An eligible handoff explicitly says **accepted-ready** and contains every
identity above. Until then, `game06_6` remains dependency-held and its frozen
contract-only head `348ecd55` remains the only source payload.
