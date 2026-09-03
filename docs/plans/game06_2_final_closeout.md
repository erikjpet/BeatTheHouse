# game06_2 Blackjack final closeout

Date: 2026-09-03
Recovered depth integration: `d47feee3`
Post-land authority recovery: `b091bc43`, `d3018288`, `9053c4b3`, `831f15ee`, `f0f68746`, `cb878b21`, `6f6c010e`, `683f5e11`
Final bounded-authority remediation: `73b7a9523116712be266240397b3901e17476f4a`
Audited product tree: `8964fc29e38d7c3b2d5704ae089952a56a4cdbf4`

## Verdict

`game06_2` is functionally complete on the exact product tree above. The
substantial played-table implementation was recovered from the landed lineage;
it was not rebuilt. Blackjack retains its shipped rules, paytable, seeded shoe,
detection, heat, Crew costs, tutorial meanings, and single money authority while
presenting placed chips, explicit table procedure, populated actors, tactile
actions, terminal settlement, and safe repeat play.

Closeout found a release-blocking repeat-play performance defect in the sealed
receipt ledger. Every new boundary repeatedly validated, serialized, and deeply
copied the complete 128-response history, causing a deterministic 25-hand prefix
to grow from 0.898 seconds at hand one to 142.213 seconds total. The final
remediation keeps the historical 128-entry validation ceiling for old saves,
converges new commits to the most recent eight replayable boundaries, carries
one already-validated ledger through the synchronous host transaction, and
resolves the game against a replay-validated compact proposal before reattaching
the exact host-retained history. No caller-supplied flag, trust marker, receipt,
or proposal bypasses validation.

The exact 25-hand outcome fingerprint remains
`75dedc3ce90d7c598eb655f41293152a223991fb75f06c3257f81aa2317619b7` and
the checkpoint fingerprint remains
`63b6c3d9c053712fef452e815224b273a0c1976ea0cdb4f5e77f64ac5d8a98c8`.
Runtime fell to 44.392 seconds and the authority ledger plateaued near 56 KB by
hand five instead of reaching 351 KB and continuing to grow. A retention-only
comparison passed the same exact chains in 57.530 seconds, proving that both the
bounded window and removal of redundant transaction-local work contribute
materially.

## Requirement reconciliation

| Prompt requirement | Landed implementation and exact evidence | Verdict |
| --- | --- | --- |
| Consumer audit first | `docs/plans/game06_2_blackjack_consumer_audit.md` maps Players Card, tutorial, Count/heat, Crew, heist, patron, persistence, audit, and settlement consumers. The final depth contract re-proves those stable fields. | PASS |
| Money as a placed thing | Staged denomination/place/add/remove/undo/clear/repeat/rebet controls derive available, pending, at-risk, returned, payout, and net values from the one authoritative settlement. Split, double, insurance, and surrender records remain itemized and conserved. | PASS |
| Dealer procedure and phases | The shipped projection covers wagering, initial deal, player decision, dealer procedure, settlement, and return to wagering, including shoe/cut/burn/deal/check/draw/sweep/pay beats and bounded acceleration. | PASS |
| Populated table and energy | Dealer, bounded neighbours, pit attention, shoe/cards/chips/count objects, and interactive targets change materially across phase, population, and heat tiers. Neighbours are seeded visual actors and do not affect player money or outcome. | PASS |
| Cheats, Count, Crew, and heist | Count bubbles, hover selection, heat backoff, Spotter/Big Player presence, pending dishonesty, detection, normalized action kind, and terminal settled fields retain their existing owners and meanings. | PASS |
| Input and accessibility | Pointer/touch, keyboard/controller, reduced-motion, non-color labels, and tactile place/cut/wave/tap semantics map to the same action ids. Wrong-phase and malformed input reject without charge, RNG advance, or settlement. | PASS |
| Persistence and exactly-once | Mid-action authority, pending delivery, settlement, save/load replay, duplicate delivery, receipt consumption, retry, cancellation, and terminal presentation are covered. Duplicate apply and duplicate post-result consumers remain inert. | PASS |
| Authority and hidden state | Public validation returns deep-isolated data. Compact proposal helpers are pure; the host independently replays the proposal, validates closed ledger shapes and fingerprints, restores exact history, and rejects forged/transplanted/stale inputs. Crew private `a`/`z` never enter public receipt identity. | PASS |
| Rules, math, and RTP | Rule/paytable fixtures, natural/split/double/surrender/insurance conservation, seeded outcome chains, and the 1,000-hand payout sample remain binding. No odds, payout, RNG, economy, schema, or migration changed in closeout. | PASS pending final report hash |

## Exact automated evidence

- `game06_2_depth_contract.gd`: PASS in 34.9 seconds on the final product
  candidate. It includes phase projection, accounting, gesture equivalence,
  ten-seed neighbour isolation, Crew and cheat consumers, exact replay,
  save/restore, hostile delivery/receipt/proposal rejection, post-RNG and
  post-turn retry atomicity, and mixed-rate funding rejection.
- The same contract now constructs a valid historical 128-entry v3 ledger,
  proves public nested isolation, saves and restores it through `RunState`,
  commits the next real host action, and proves convergence to eight entries.
  The newest retained delivery replays, an evicted delivery rejects, and the
  caller-owned historical dictionary remains byte-identical.
- `game06_2_repeated_reprieve_contract.gd`: PASS in 29.6 seconds. The fixture
  keeps its actual encrypted Crew bytes for restore while normalizing only
  valid fixed-width `crew_state.a`/`z` values for semantic identity. Two fresh
  constructions prove the same normalized fingerprint
  `e3e82af65d31d22658612772fe4c0296c85f0d7ad920850bc2501c90a118a922`
  and zero heat before the terminal reprieve mechanics execute.
- `crew06_10_scenario_registration_contract.gd`: PASS; five ordered scenarios.
- Deterministic 25-hand performance qualification: PASS, exact accepted outcome
  and checkpoint chains. Milestones were 0.928s / 7.170s / 15.930s / 44.392s
  at hands 1 / 5 / 10 / 25. Ledger sizes were 14,241 / 56,967 / 56,113 /
  56,048 bytes and cache/journal size remained eight after convergence.
- Checked-in real-renderer Blackjack evidence under
  `review_artifacts/blackjack_table_cleanup/` shows idle, dealing, and dealt
  table states. The checked-in terminal audit has zero failures and covers eight
  generated tables, every rule fixture, count/peek/patron/side-bet paths, and a
  1,000-hand payout sample at edge `-0.0505069`.
- The final exact-root `blackjack_seed_audit.gd` run is in progress from harness
  commit `47a3a241c8edd782cf1621938689990b5adcbf3d` against unchanged game product
  commit/tree `73b7a952` / `8964fc29`. Its immutable result path is
  `.tmp/game06_closeout/blackjack_seed_final_47a3a241.json`. This report becomes
  archive-ready when that row is replaced by the final PASS metrics and hash.

## Retained non-green evidence

- The earlier exact 1,000-hand audit on pre-remediation tree `cbd65df3` was
  preserved after reaching 300 hands in 8,666.304 seconds. It demonstrated the
  superlinear repeat-play defect and was retired only after the exact-chain
  optimized replacement was proven and landed. It is not reported as a gate.
- A pre-remediation 25-hand baseline passed exact outcomes/checkpoints but took
  142.213 seconds and grew the ledger to 351,301 bytes. Retention-only and
  combined results above are retained as comparisons; no budget was raised.
- The first exact-root post-remediation audit retained all 120 generated-table
  checks but stopped after one payout hand. Its stale harness kept a
  pre-commit environment dictionary, did not advance terminal presentation,
  and failed to update handled decision UI. It is retained as RED, not a
  product verdict. Harness commit `47a3a241` now uses sealed placement and
  surface deliveries, carries the authoritative environment, accepts only a
  real settled-hand result, advances terminal presentation, and emits exact
  failure detail. A 25-hand qualification passed before restoring the binding
  count to 1,000.
- The first repeated-reprieve rerun failed because the fixture pinned an old
  whole `games.json` hash; after refreshing content provenance it exposed a
  nondeterministic whole-save fingerprint caused solely by the intentionally
  randomized valid Crew capsule. The repaired fixture preserves real restore
  bytes and normalizes only valid fixed-width private envelope values, then
  passes two independent fresh constructions and the gameplay contract.
- The initial `check_table_games.gd` load found that its intermediate parent
  called a resolver declared only in the child. Harness commit `47a3a241` moves
  the unchanged resolver implementation into the parent; both parent and child
  parse/load checks pass. The intermediate is not a standalone suite entrypoint;
  the generated leaf aggregate still must pass before `game06_8` closes.

## Remaining human check

No Blackjack implementation work remains after the exact statistical audit
finishes. The owner playtest still needs to judge whether a new player can place
and correct a bet, follow dealer procedure, choose an action, read itemized
settlement, recognize heat/Crew presence, safely repeat, and leave without
outside rules knowledge. That experiential judgment belongs to
`playtest06_1`; it is not represented here as automated acceptance.
