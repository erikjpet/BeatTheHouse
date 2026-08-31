# game06_7 dependency replay manifest

Status: **UNREVIEWED / docs-only / fail-closed / not a row claim**
Manifest base: `25f16c4efb723db2a0308eec5719b59b497413b7`
Prepared branch: `codex/game06_7-dependency-replay-manifest`

This manifest describes intake and proof for replaying the preserved game06_7
contract-only payload. It does not accept that payload, authorize a product
replay, or modify product/tests. The Integrator owns dependency acceptance,
three-way integration, gates, and landing.

## Fail-closed intake

Replay may begin only when every row below is backed by an exact immutable head,
an independent acceptance verdict, and (where required) a main merge ancestor.
An observed branch head is evidence of existence, not acceptance.

| Authority | Exact requirement | State observed while authoring | Intake rule |
| --- | --- | --- | --- |
| Landed game ritual contract | `a2760d816c781e711ff0923c296f97b786662453` landed through merge `6d8755394c6374ef66364f035e67827fb6e6bf6e`; merge must remain an ancestor of intake main | Satisfied on observed main `9ea919fe9b53ab3ae37e085ed462febaa8ad76f8` | Recheck ancestry at replay time; reject a detached or contract-only base |
| Accepted game06_2 consumer | Owner/Integrator-authorized authority outcome based on the landed contract; must preserve the shared Blackjack settlement path and name the charged/deal authority consumed by the duel | `4dbb83bfe6e235640352a39ec90aa80f7d221b02` is second-rejected and frozen; no third product cycle is authorized | **Blocking on the escalated owner decision.** Intake must record the chosen authority disposition and downstream conditions; never silently treat `4dbb83bf`, bare `a2760d81`, or rejected `2def171d` as accepted |
| Shipped crew ending authority | Landed `crew06_8` heist route and `crew06_9` hidden-resolution contracts remain authoritative for `crew_heist`, outcome bands, neutral storage, clue disclosure, and exactly-once settlement | Historical shipped implementations exist; observed branches include `612c04c6` and `26836504` | Resolve their exact landed ancestry from intake main; do not substitute branch tips or restate their math |
| Accepted crew/world adapter | Integrator-accepted world06_1 must provide a sealed, public-only actor/sequence projection and the hidden-state leak gate | Observed `9d6ff952ab256bb74ec4d26e655cfb9cec3517e5` is explicitly UNREVIEWED-BLOCKED | **Blocking.** No game06_7 surface may read crew hidden authority or raw neutral save state directly |
| Accepted heist/Turn staging authority | Integrator-accepted world06_6, based on accepted world06_1/world06_2 and required crew06_10 clue authority, must define public crew presence and disclosure boundaries | Observed `0814cec1bda9f1574357b77e5f14a1dab03f7994` is not accepted evidence | **Blocking.** Require the exact accepted public projection schema and leak-test verdict |

No “compatible enough” substitution is allowed. Missing hashes, ambiguous
ancestry, unavailable acceptance reports, absent hidden-state paired-observer
proof, or a request to copy whole files fails intake before product application.

## Replay procedure and ownership

1. Create a new implementation branch at the exact accepted game06_2 successor
   after confirming the landed contract merge is an ancestor.
2. Three-way apply the net product/test payload from `a2760d81..25f16c4e` with
   semantic conflict resolution. Never replace accepted files wholesale.
3. Reconcile game06_7 declarations against the accepted game contract and
   Blackjack consumer IDs. `blackjack.gd` remains game06_2-owned: any required
   change is a written dependency request, not a replay edit.
4. Bind crew actors only through the accepted world public projection. Do not
   import `crew_heist_state.x`, `CrewTurnModel`, grievance ledgers, private clue
   flags, alternative members, or pre-disclosure resolution state.
5. Recompute this manifest's source blob inventory on the accepted tree and
   explain every difference before running gates.

Baseline authority blobs at `25f16c4e`:

| Source | Git blob |
| --- | --- |
| `scripts/core/grand_casino_duel_model.gd` | `04e77529123dbeffff0ff353abf5218a91a37a30` |
| `scripts/core/grand_casino_showdown_model.gd` | `14918741dfea8b59d476a52581236f52c0f83b02` |
| `scripts/core/run_state.gd` | `a275c54352f4d68ef5fd1c44e969e62bcab525dc` |
| `data/events/events.json` | `19638ec56596ec19b4c50191c610194de089b5c9` |
| `data/crew/heist.json` | `bb8f86b100de77d4e75cc8866f2712f494ae4d6f` |
| `scripts/core/crew_turn_model.gd` | `82bb26addc2eec44b222ca5ef8ec4487b26a42c8` |
| `scripts/core/crew_heist_model.gd` | `fd9175c93d2cbb43b13775ef4cbaa0557b315fc8` |
| `docs/plans/grand_casino_endgame_design.md` | `7f4f574548d4376ab2bb742ccf5c195dc778daff` |

Changed authority blobs do not automatically reject replay; they require a new
before/after ladder extraction and proof against the accepted tree.

## Exact ladder preservation

Presentation may consume these outcomes but may not calculate, rename, reorder,
or widen them.

| Boundary | Frozen authority and condition | Required projection |
| --- | --- | --- |
| Invitation | `grand_casino_invite`; Players Card and attention routes remain separate inputs to the shipped endgame state machine | No presentation action creates or bypasses an invitation |
| Pat-down clean | no classified items | seating continues without penalty |
| Pat-down minor | exactly one contraband item | shipped confiscation only |
| Pat-down serious | surveillance present or at least two contraband items | shipped 18-stack handicap and forced ante +5 |
| Pat-down blatant | at least three contraband items, or watched cheat plus contraband | immediate `taken_out_back` / `casino_taken_out_back`; no duel staging override |
| Duel length | base ante 20; at most five hands; earlier terminal on either stack reaching zero | staging follows authoritative `hand_index`, `hand_limit`, and stacks; no dramatic timer |
| Rourke edge | 10% base plus 20% per cheat level | display only after the owning contract exposes the edge/call result |
| Edge call | correct swing 18; false-call cost 6 | existing action and receipt only; caller labels cannot set correctness |
| Player cheat | 55% + 5% per aggression + 5% per cheat level; caught cost 18 | existing detection/heat result only; no presentation roll |
| `walk_out_clean` | Rourke stack zero, or final margin `>= 12` | showdown victory through `pit_boss_showdown`; Cage cashes the rack |
| `shown_the_door` | final margin `>= -60` and `< 12` | showdown victory through `pit_boss_showdown`; uncashed chips retained under shipped contract |
| `taken_out_back` | player stack zero, or final margin `< -60` | failure through `casino_taken_out_back` |
| Players Card ending | deliberate Gold review | distinct `high_roller_cashout`; only this route sets the shipped Gold-card Act 2 seam |
| Crew ending | shipped heist result | distinct `crew_heist`; preserve plan, `clean_sweep` / `out_hot` / `somebody_got_pinched` / `closed` band, payout, scar, and Act seam exactly once |

The model fallback `shown_the_door_min=-8` is not the data-backed shipped
threshold. The replay proof must load production event data and assert `-60`.
Tests must cover `-61`, `-60`, `11`, and `12`, plus both stack-zero terminals.

## Authoritative staging phases and save/revisit matrix

The row-local presentation phases remain `approach`, `seating`, `response`,
`commitment`, `reveal`, `phase_break`, `crowd_change`, `outcome_staging`, and
`exit`. They project the shipped showdown's `walk`, pat-down, three saved
interrogation responses, and duel authority; they are not a second lifecycle.

For every phase below, save both immediately after entry and immediately before
its accepted exit, then exit the surface, save/load in a fresh process, revisit,
and continue to the same terminal authority.

| Phase | Authority to preserve | Revisit assertion |
| --- | --- | --- |
| approach | pending event/route and accepted walk response | no repeated call, route switch, item move, or dialogue |
| seating | walk disposition and pat-down result | no second confiscation, handoff, handicap, heat, or failure |
| response | evidence IDs and each accepted answer ordinal | no reselection or repeated answer effect; next unresolved beat remains next |
| commitment | duel terms, hand index, stacks, ante, Blackjack session/receipt | no second charge, deal, RNG consumption, or stranded stake |
| reveal | authoritative hand/edge result receipt | no reroll, repeated transfer, call penalty, heat, audio, or dialogue |
| phase_break | completed hand receipt and next-hand authority | transition enters once; no automatic deal |
| crowd_change | public ladder/room projection | actor/object projection rebuilds without authoritative mutation |
| outcome_staging | exact duel, Players Card, or crew route result receipt | reward, failure, returned handoff, chip handling, scar, and Act seam fire once |
| exit | terminal acknowledgement | revisit cannot reopen or replace the terminal route |

Also cover saves at the four underlying showdown boundaries and between every
duel hand. Malformed/legacy saves must take only the accepted migration/recovery
path and must not synthesize a favorable outcome.

## Hidden-Turn paired observers

Each pair uses identical public run history, public crew presence, duel state,
action trace, seed, accessibility settings, and frame cadence. Only sealed Turn
authority differs. Until the accepted Turn/world contract emits a public
disclosure, compare canonical surface state, scene graph actor/object records,
interaction lists, logs, dialogue/audio cues, capture pixels, and all
surface-visible serialized adapter records byte-for-byte.

| Pair | Private difference | Required equality window |
| --- | --- | --- |
| H0/H1 | no selected member vs a selected member, no witnessed public disclosure | entire duel and ordinary ending staging |
| H2/H3 | two different selected members with identical public crew presence | until the owning confrontation/ending contract names a public consequence |
| H4/H5 | private signal emitted vs not emitted but not witnessed | through every crew-at-rail pose and bark |
| H6/H7 | witnessed-count/hedge eligibility differs but the option is not mounted on this surface | entire game06_7 interaction list |
| H8/H9 | Turn cancelled vs still active behind the same accepted public crew projection | until the owning world sequence publishes distinct ending authority |
| H10/H11 | grievance weights, reroll escalation, or alternative eligible pool differs | always; these values never enter the duel projection |

The raw hidden model is never passed to game06_7 for this proof. A world adapter
that exposes `m`, `w`, `e`, `h`, `c`, `f`, member identity, grievance, or a
secret-correlated actor order fails intake even if labels look neutral. Run the
accepted world leak scanner over saved keys, scene state, captures, logs, and
fixtures; semantic leakage is a P0 even when forbidden words are absent.

## Caller-authority hostile matrix

Every case must reject before mutation, RNG, charge, receipt, one-shot cue, or
projection change:

- caller supplies `walk_out_clean`, `shown_the_door`, `taken_out_back`,
  `high_roller_cashout`, `pit_boss_showdown`, or `crew_heist` without the exact
  owning terminal receipt;
- caller alters margin, stacks, hand index/limit, ante, edge identity,
  correctness, detection, transfer, heat, payout, scar, Act seam, or result ID;
- caller provides a crew actor, pose, ordering, absence, bark, hidden member,
  signal count, grievance, or private ending hint instead of the accepted public
  world projection;
- cross-wire ritual/session/route/plan/hand/item/member IDs; replay or reorder a
  receipt; reuse a request key with changed content; duplicate an outcome ack;
- submit an unknown field, missing field, wrong type, noncanonical ID, forged
  fingerprint, stale expected phase, inaccessible target, or direct script/node
  path;
- request a stage skip, outcome staging before terminal authority, exit before
  consequence receipt, or a second settlement after save/revisit;
- inject wall-clock/frame timing to select a Rourke pose, crowd state, result,
  or one-shot timing.

For each hostile case archive before/after authoritative state digests, RNG
cursor, bankroll/chips/heat, duel stacks/hands, route/ending flags, and receipt
sets. Equality is required on rejection.

## Full gate and capture matrix

No gate is run from this pre-stage branch. The Integrator runs the following on
the exact replay head with its built and hashed native plugin and warm caches.

| Gate family | Required exact evidence |
| --- | --- |
| Intake/ancestry | accepted dependency hashes/verdicts; merge-base proofs; replay diff and ownership scan; native plugin SHA-256 |
| Contract/hostiles | game ritual validator; game06_7 row proof; all paired observers and hostile cases above; zero forbidden private fields |
| Rules/routes | every pat-down tier; threshold points `-61/-60/11/12`; both stack-zero outcomes; five-hand limit; Players Card, showdown, and all four crew bands end to end |
| Blackjack/economy | accepted game06_2 focused suite; full duel/Players Card regressions; no double charge/settle; unchanged odds, ante, transfers, chip/cash handling, rewards, and Act seam |
| Persistence | fresh-process save/load/revisit at every matrix point; legacy migration; exactly-once reward/dialogue/audio/effect receipts |
| Determinism/parity | 10 named seeds, repeated native and Web; canonical semantic hashes identical; frame cadence and wall clock perturbed without result changes |
| Performance/liveness | native and Web timings, bounded actor/object/receipt counts, idle liveness counter-gate, no per-frame deep copy or hidden-state scan |
| Accessibility | keyboard/controller/pointer/reduced-motion equivalence, target selection, small screen, colorblind/non-color cues, no audio-only information |
| Full project | project validation and all owning foundation Systems/Contracts/UI suites on the exact replay tree |

Capture all states on native and Web at the same authoritative boundary and
record image/process hashes:

| Capture set | Required frames |
| --- | --- |
| Duel phases | all nine presentation phases; all four underlying showdown phases; every duel hand index |
| Ladder | each pat-down tier; `walk_out_clean`; `shown_the_door`; `taken_out_back`; every failure rung |
| Endings | Gold Players Card, showdown victory variants, crew `clean_sweep`, `out_hot`, `somebody_got_pinched`, and `closed` |
| Room/actors | Rourke arrival/confidence/pressure/tilt/respect/contempt/suspicion/realizing-loss; early/late/max crowd; staff/security/rail; public crew presence |
| Interaction | edge call success/failure, player cheat clean/caught, max heat, disabled targets, rejected input |
| Accessibility | reduced motion, keyboard focus/target cycle, controller focus/target cycle, small screen, colorblind/non-color labels |
| Privacy | paired H0-H11 captures with equality hashes through each allowed disclosure boundary |

Archive a machine-readable manifest containing exact replay head, dependency
heads, source and plugin hashes, commands, exit codes, durations, seeds,
semantic hashes, capture hashes, and any inherited failures. A missing required
capture, divergent native/Web semantic hash, leaked hidden state, or waived
authority proof rejects the replay.
