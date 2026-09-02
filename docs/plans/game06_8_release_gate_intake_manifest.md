# game06_8 Family 1 release-gate intake manifest

Status: **UNREVIEWED / PRE-STAGED ONLY / BLOCKED**

Purpose: define the immutable intake and independent evidence required before
`game06_8` can begin its exact-tree Games Depth release audit. This document is
not a closure report, acceptance verdict, gate result, implementation plan or
permission to land any child row.

The full binding prompt is
`docs/todo/game06_8_games_depth_release_gate_prompt.md`. It requires independent
inspection of landed code, data, reports and the player-facing build across all
game surfaces. Child notes, branch-local passes and contract-only artifacts
cannot satisfy it.

## 1. Prestage provenance

This prestage was authored from clean green-main checkpoint:

| Field | Exact value |
| --- | --- |
| base commit | `00ee744fa6269e8a7eb34f67b2659f32d55febaa` |
| base tree | `8ae1554fd50fba705246bbe4da21ef28adead8af` |
| base subject | `QUIESCE-DONE: GREEN fifth-landing performance 46.663s` |
| intake branch | `codex/game06_8-release-intake-prestage` |
| row prompt | `docs/todo/game06_8_games_depth_release_gate_prompt.md` |

The green checkpoint proves only the recorded current-main health checkpoint.
It does not accept a Family 1 row or prove game06_8 scope.

At real intake, the Integrator creates a fresh immutable provenance record with:

```text
schema / captured_at_utc
current_main_commit / tree
game06_1..game06_7 accepted_source_commit / tree
game06_1..game06_7 accepted_integration_commit / tree
depth06_1 accepted_source_commit / tree / integration_commit
owner_decision_ids and selected option text
review_verdict_ids / reviewer identities
functional_gate_report_ids / postland_report_ids
godot_executable_path / sha256 / version
native_descriptor_path / sha256 / selected Windows debug target
native_plugin_path / sha256 / built source tree
web_export_aggregate_sha256 / pck_sha256 / wasm_sha256
artifact_manifest_path / sha256
```

Every commit must resolve, every integration must be an ancestor of recorded
main, every source tree must match its verdict, and the descriptor must identify
the exact hashed native binary. A moving ref, dirty worktree, copied/stale
plugin, missing owner choice, post-review commit or report for another tree
stops intake.

## 2. Current Family 1 inventory -- no accepted intake heads

The following are repository observations as of this prestage. They are not
accepted inputs. **Every release-gate verdict in this table is
BLOCKED/UNVERIFIED.** Historical words such as contract, remediation, handoff or
review do not upgrade that verdict.

| Row | Artifact class | Exact head | Tree | Release-gate verdict / gap |
| --- | --- | --- | --- | --- |
| game06_1 | frozen contract vocabulary | `a2760d816c781e711ff0923c296f97b786662453` | `1df3d9b767d7490acdffb291ce5220c0b409127e` | **BLOCKED/UNVERIFIED** -- contract evidence only; not an accepted product runtime |
| game06_1 | later validator experiment | `70568bdef8544bed76685ed43092b201cd5788e0` | `1af94164dd3528bf03f7a55f9fcb51a516e638ff` | **BLOCKED/UNVERIFIED** -- preserved non-authoritative successor; does not replace the frozen contract/product decision |
| game06_1 | second rejected product | `932287ba0e049f1110cb748f02cb09047d3b42f5` | `9a33aebef2d37fc0093e6cca43bbc01fbc3710a0` | **BLOCKED/UNVERIFIED** -- frozen rejected evidence |
| game06_1 | owner decision packet | `0f64e85bb3c30484973fee3f0328b3c3c7f9a6e0` | `cd7b4277fa8901e8dfda9c90148f971cdb98a178` | **BLOCKED/UNVERIFIED** -- no option selected in the packet |
| game06_2 | alternate implementation WIP ref | `2def171d4adf90c5f4f5f6b1f4c35e4c6390b82a` | `6f7f1abeab0727a26681f45d99e6070cbb8574a6` | **BLOCKED/UNVERIFIED** -- current named implementation ref is not in the accepted/rejected remediation lineage and is not an intake candidate |
| game06_2 | first rejected handoff | `e699d0bcfb566a022f4c4115920690874d0991ab` | `30ca1fd1f798988755fb5c422e07d676080f1689` | **BLOCKED/UNVERIFIED** |
| game06_2 | second rejected remediation | `4dbb83bfe6e235640352a39ec90aa80f7d221b02` | `098b15369a6a333cf6c18f13f0a9f332e94a4fc8` | **BLOCKED/UNVERIFIED** -- bare live host charge/resolve authority remains |
| game06_2 | owner decision packet | `958fd02d76978fe19bdbe85d405a8666d51c5193` | `c3110f86da7598d8985bde1173143f1f818250d9` | **BLOCKED/UNVERIFIED** -- no option recorded |
| game06_3 | first rejected combined handoff | `2852387f478930a69f568987eb835ee0c1ccfff1` | `5c48b0e4cf33054738c1ac64558ec5c0ee46eaa6` | **BLOCKED/UNVERIFIED** |
| game06_3 | second rejected product | `4c10e3b888711a52ff9331e7db3f7adee08c2a72` | `49b0360c498d83919b1de054c2d154df2112a689` | **BLOCKED/UNVERIFIED** -- Roulette/Baccarat combined row remains rejected |
| game06_3 | owner decision packet | `647736bcdaf819bdd0566ebf60b541bb210df7b5` | `8e9d92bfd15d11f1e38310677d2aaad3dc8e774f` | **BLOCKED/UNVERIFIED** -- no option recorded |
| game06_4 | rejected implementation | `259d63523bbc5ef9cacc4340c3fa3eae1855b7ed` | `601992dc0ba0d34aad0175b715034cda3de78e9f` | **BLOCKED/UNVERIFIED** |
| game06_4 | frozen remediation | `a1643b525f426d45501a2b479ec918d17bb04178` | `47bcd4f6cebc8b0028054aa01ec41e3aa9b7ecc7` | **BLOCKED/UNVERIFIED** -- intentionally fails closed without selected authority |
| game06_4 | earlier coupled decision packet | `a691d994463cc6ac1708660e5abd1ac2fffa0e72` | `716676f54c5e0423b2af37bb149e20463989c553` | **BLOCKED/UNVERIFIED** -- preserved provenance; superseded for intake by the separated-axis packet below |
| game06_4 | authority-axis packet | `abf9e2bc23c43059dc8a2e40c2ad32559b7a7a3e` | `1831ba5a94e7a00c42140c8910c3ee9f28569ac5` | **BLOCKED/UNVERIFIED** -- wagering and hand-pay axes unselected |
| game06_5 | accepted Counter Games product | `996a98b69a3ab477e8cb4e83109693b730fcb1b3` | `a3dfc603f26b69b8766349a99ae84ac2a9911e33` | **ACCEPTED/LANDED** -- counter ritual depth plus active interlocking Crossword; exact-trunk Scratch and Pull Tabs focused acceptance green |
| game06_5 | historical Crossword decision evidence | `19bdc9f00dcb9796343f4f1dc9a87921eec1754b` | `26c4ba87a73db5a41d33252d0030cce5ec22b97c` | **RESOLVED/SUPERSEDED** -- owner selected denser interlocking layout; final product landed at `996a98b6` |
| game06_6 | contract-only staging | `348ecd55886fb6c167b9ca2fa8a51e272a9939fb` | `4217179e47d07fb9558cb50689c4c2c35b36ca3a` | **BLOCKED/UNVERIFIED** -- no dependency-ready product |
| game06_6 | replay manifest remediation | `308d810fc03f6a8f7840bbbfab86953b96d3268f` | `f17adc33ca571c35183cf8651854f7f8c63ede01` | **BLOCKED/UNVERIFIED** -- docs-only, awaiting independent second docs review and dependencies |
| game06_7 | contract-only staging | `25f16c4efb723db2a0308eec5719b59b497413b7` | `f69b76220365b3105d27bc544f16b32a975b6d34` | **BLOCKED/UNVERIFIED** -- no dependency-ready product |
| game06_7 | replay manifest | `8c5e483932db96ad6f0a7d804ea6a1da408e3f17` | `a55c5d1c2ebca6dbd4b33c6b25f16d51235359fb` | **BLOCKED/UNVERIFIED** -- unreviewed docs only |

Rejected, partial, contract-only and replay-document heads must remain
preserved, but none may be merged wholesale, treated as an accepted base or
counted as a release-gate pass. A future authorized successor starts from its
accepted dependency/current-main base and replays reviewed net payload by
semantic three-way integration.

## 3. Open owner decisions and dependency gaps

Every item below is a hard intake stop. This manifest selects none.

| ID | Required owner/dependency record | Current gap and downstream hold |
| --- | --- | --- |
| D1 | game06_1 product disposition | Choose the recorded A full single-authority redesign, B partial plus `game06_1b`, or C explicit alternate-authority exception. No accepted product successor exists. All game06_2..7 and game06_8 remain held. |
| D2 | game06_2 Blackjack authority | Choose A same-scope sole ritual authority, B presentation partial plus `game06_2b`, or C compatibility exception for the bare resolver/cost route. game06_7 and game06_8 remain held. |
| D3 | game06_3 combined disposition | Choose A exceptional full Baccarat closure with preserved Roulette, B Roulette partial plus `game06_3b`, or C exact Baccarat requirement reduction/exception. game06_8 remains held on every required accepted slice/successor. |
| D4 | game06_4 machine wagering authority | Select exactly one of W0 direct-bankroll, W1 shared host-rooted credit ledger, or W2 game-local ledgers with explicit split-authority risk/protocol. |
| D5 | game06_4 hand-pay authority | Independently select the recorded hand-pay axis and all required values/successor ownership. A wagering choice does not imply a hand-pay choice. game06_4/game06_8 stay held until both axes are executable and accepted. |
| D6 | game06_5 Crossword disposition | **RESOLVED.** Owner selected a denser interlocking seven-word layout with compatible words. All seven ticket families are active on main `996a98b6`; focused Scratch/Pull Tabs acceptance and alignment evidence are green. |
| D7 | craps06_3 disposition | Choose A exceptional same-scope closure, B partial plus named successors, or C explicit requirement reduction. Core `e8cc589e` and environment `872d09a9` are both second-rejected. game06_6 and depth06_1 remain held. |
| D8 | game06_6 dependency intake | Requires accepted game06_1 product authority and owner-resolved, accepted craps06_3 core/environment seams before replaying frozen BAR-DICE payload. Replay manifest `308d810f` also needs independent docs acceptance. |
| D9 | game06_7 dependency intake | Requires accepted game06_1 and game06_2 successors plus an independently accepted replay manifest/candidate. No product candidate exists. |
| D10 | depth06_1 acceptance | Current prestage `5d44725b7346b64226d1a01c06a4153b5c875d62` / tree `5078016625908420e34318b936f9316229273a2f` is **BLOCKED/UNVERIFIED**. It is not a release verdict. |
| D11 | depth06_1 child rows | env06_7 ordered assembly `d78b90041691a206b48d5659b7e17e9c94b573cc` / tree `cb3e9c16bf564e956453f19ada4996e627256378` and crew06_10 `678c3e2742fb0f1f93252b1ebd935a4248e85334` / tree `2c648e97a8d374b19cbb4c3c4a3666680979c1de` are **BLOCKED/UNVERIFIED**; craps06_3 is unresolved. No accepted depth06_1 input set exists. |
| D12 | landed exact-tree assembly | game06_8 may start only after every required accepted integration is present on one clean current-main tree. Branch coexistence is not composition and no child row in this inventory is a verified landed intake. |

An owner record must include selected option, exact scope, owner, timestamp,
named successors/exceptions, held consumers and the exact accepted product head
that implements it. A decision packet without a recorded choice is evidence,
not authorization.

## 4. Complete surface ledger required at intake

The audit ledger has one row for every shipped id in `data/games/games.json`:

`scratch_tickets`, `pull_tabs`, `slot`, `bar_dice`, `blackjack`, `baccarat`,
`craps`, `roulette`, `crew_draw_poker`, `video_poker`, `coin_pusher`.

It also has distinct rows for the Grand Casino duel and showdown surfaces.
Each row records:

```text
surface id / accepted owning row / exact implementation commit and blob
ritual phases / legal transitions / terminal outcomes
commit-correct-remove-undo-clear-repeat-rebet-confirm behavior
tactile pointer verbs / keyboard equivalents / controller equivalents
reduced-motion equivalent and fair timing
authoritative game/result/RNG/settlement owner
actor set / object and interactable set / energy and heat projections
RTP/paytable/probability/EV source and exact measured result
save/exit/revisit boundaries / migration schema
composition nodes and consumers
native evidence / Web evidence / accessibility / visual evidence
verdict: BLOCKED or VERIFIED
```

Missing rows, control-panel-only resolution, reward-only delay, pointer-only
verbs, unlabeled-unidentifiable presentation, changed math, or any unverified
field is **BLOCKED**.

## 5. Hostile caller-authority paired-observer rule

Every mutating ingress across every surface is accepted only from the authentic
host root for the exact run, game instance, phase, action, semantic target,
request, boundary and result receipt. Caller strings, authored data,
presentation state, public facts, restored dictionaries, nested claims,
signature-looking fields and self-consistent hashes are never authority.

For commitment, correction, throw/spin/deal/draw/reveal, feature entry,
settlement, cash-out, hand-pay, interruption and one-shot acknowledgements, run
this matrix:

| Hostile family | Construction |
| --- | --- |
| literal | exact trusted authority/channel/handler/root words without an authentic root |
| nested | literal or complete authority-shaped record under every accepted nested payload/save location |
| substituted | a real or realistic root/receipt from another run, game, phase, action, target, request, boundary or result |
| signed-looking | bounded signature/MAC/token/certificate/key-id fields with no host-verifiable issuer root |
| recomputed | attacker canonicalizes and recomputes all visible hashes, fingerprints and chains |

Each case has paired observers from the same canonical pre-state:

1. legal-looking request with authentic root absent; and
2. identical public inputs with only the hostile claim added, authentic root
   still absent.

Both reject with the same stable public class and are byte-equal and
behavior-equal afterward. Compare full authoritative save bytes, bankroll,
credits, stakes, phase, dice/cards/wheels/tickets, RNG consumption, results,
heat, training, receipts, facts, one-shots, cleanup, public projection, controls,
actors, objects, interactions, messages, errors, logs and counters. Repeat the
pair after save/load and revisit. Never echo the hostile value.

The authentic positive control uses the trusted production host to issue the
exact root, mutates once, and replays as an exact idempotent result. Mutating one
bound field turns it into substituted-hostile rejection. Fixture helpers may
not mint roots or bypass production validation.

## 6. Exact-tree functional gate program

All functional evidence names one frozen commit/tree/native binary/Web export.
A changed candidate voids every affected verdict.

Required exact-tree functional groups:

- project validation, clean import and load;
- full game ritual contract/runtime hostile matrices and opt-out equivalence;
- every row-focused suite plus the complete per-game rules/scoring matrix;
- RTP, paytable, probability, EV and money/credit conservation at documented
  samples and bands with no tolerance reduction;
- staged commitment, correction, rejection atomicity, no double commit/settle,
  repeat acceleration and safe exit;
- Players Card, all tutorial lessons, count/heat backoffs, coordinated plays,
  heist honesty/detection and game06_7 duel-ladder consumers;
- ten-seed actor/opponent/neighbour determinism and bankroll/outcome
  noninterference;
- save, exit and revisit at every phase, including scratch, feature, shoe,
  street interruption and duel;
- maximal-node composition: game + scenario + event + service + traveler +
  Police Sweep + save/load, preserving ordinary functionality and safe exits;
- native/Web semantic parity, accessibility and visual completeness; and
- exact-current-main functional PostLand after integration.

Use explicit functional-only profiles. A wrapper named Full/Smoke/all is
ineligible when it implicitly includes performance.

## 7. Binding performance cadence

Performance does not run row-locally or per candidate. The Integrator runs the
unchanged performance suite only:

- on a quiesced host after each five completed landings; and
- once immediately before owner playtest.

The checkpoint binds exact main, built native plugin/hash, host identity,
locked budgets/sample lengths and Web configuration. It covers every touched
surface, low-end Web, no per-frame deep copies and a live idle counter; 0.000
without liveness is red. Performance limits and coverage never change to clear
a result.

A checkpoint red may block the program, but it is not assigned to the last row
without separately authorized causality work. Candidate and PostLand reviews
remain functional only; no full-Smoke wrapper may schedule implicit
performance.

## 8. Platform, accessibility, visual and lifecycle evidence

For every surface, independently capture on exact native and Web trees:

- commitment, correction, resolution, settlement, repeat/acceleration and exit;
- every pointer verb beside keyboard, controller and reduced-motion equivalents
  producing identical authoritative outcomes;
- every energy/heat tier materially changing an actor, object or interactable,
  then settling honestly;
- quiet, active, win, loss, interruption, small-screen, obstruction,
  reduced-motion, focus and colorblind/non-color states;
- unlabeled contact-sheet cells identifiable from room, actor and object state,
  not title/sign/reward copy;
- save/load, exit/revisit and expiry at every phase with no lost wager, reroll,
  repeated settlement/reward/dialogue/audio, or orphaned semantic state; and
- maximal composition at every shared node.

Evidence reports include raw action traces, complete pre/post hashes, RNG
checkpoints, economy ledgers, input-device ids, viewport/DPR, platform/native
identity, capture hashes, observer comparisons and artifact paths. Native/Web
reports from different product trees are incomparable.

## 9. Intake and verdict protocol

1. The Integrator freezes one exact current-main tree containing every accepted
   dependency integration.
2. It verifies immutable source/integration ancestry, owner decisions, clean
   status, native descriptor/binary/source identity and evidence hashes.
3. An independent reviewer with no Family 1 implementation ownership performs
   the audit. A child implementer cannot review game06_8.
4. Functional gates and manual evidence run on the frozen tree. Any change
   voids affected evidence and returns the row to intake.
5. Every surface/requirement receives `VERIFIED` only from direct exact-tree
   evidence. Otherwise it remains `BLOCKED`.
6. The closure report maps each prompt requirement to code/data, automated
   evidence, captures and exact report hashes and lists every remediation
   commit.
7. Only after all fields are verified may the Integrator consider a release
   verdict and board/archive action. This prestage authorizes neither.

Current overall verdict: **BLOCKED/UNVERIFIED**. No completion claim is made.
