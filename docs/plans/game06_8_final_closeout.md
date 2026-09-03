# game06_8 Family 1 games-depth release gate

Date: 2026-09-03  
Independent closeout lane: `/root/game_closeout`  
Frozen landed game product base: `039e3326d7f09ab911f8903adc03b94c2cc12e4f`
Frozen integrated candidate tree: `d78c3337825c68e416e21aaba4ae8f6af881340e`

## Verdict

`game06_8` is **IN PROGRESS** while the final Blackjack statistical audit, the
Crew depth comparison repair, and the exact-tree aggregate games suite finish.
The `depth06_1` dependency is accepted at `b33a0584`, the game-owned focused
contracts are green on the frozen product tree, and no game implementation has
been rebuilt. This report becomes the final closure record only after the
remaining entries in the gate ledger below are replaced with immutable PASS
evidence.

The audit accounts for all eleven ids in `data/games/games.json` plus the Grand
Casino duel/showdown presentation. Coin Pusher is included as a shipped game,
but its already-accepted V3 program was not reopened. The only source changes
made during this gate are verification-tool updates that route old Blackjack
fixtures through the shipped sealed host. They do not change game rules, odds,
payouts, RNG, economy, save schema, migration, or presentation.

## Exact intake

All recovered product integrations are ancestors of the frozen base:

| Row | Accepted landed implementation | Final evidence source |
| --- | --- | --- |
| `game06_1` | `5a2b1e1a6782a13308585e1a974adeeb86be0647` | `game06_1_final_closeout.md` |
| `game06_2` | `d47feee3`, recovery through `683f5e11`, bounded-authority remediation `73b7a952` | `game06_2_final_closeout.md` |
| `game06_3` | `212475356cedb42056a2677b590e5b69ed0ac8aa` | `game06_3_handoff.md` |
| `game06_4` | `e874d6bc1636ab8094bd88c0c304a5db29902535`, remediation `bd77ac54da2c9a911587802968d66cd589a7a1c9` | `game06_4_final_closeout.md` |
| `game06_5` | `996a98b69a3ab477e8cb4e83109693b730fcb1b3` | archived row prompt and Crossword decision evidence |
| `game06_6` | `d98de5440bec7685f4bb26eace77f2dbb1627f53` | `game06_6_final_closeout.md` |
| `game06_7` | `a6e7be912e8ca9e979d5eb35edefbb4883b49889`, save remediation `45e87257584ff30fd4086f89d49cf1d5ee23bfbe` | `game06_7_final_closeout.md` |
| Coin Pusher V3 | `6af645b56108a758df2cb0264bbbb10ecd3b624e` | `coin_pusher_v3_program_closure_audit.md` |
| `depth06_1` | accepted closeout `b33a05843fb161cd1c2970b4af2a475473beac40` | `depth06_1_final_closeout.md` |

Godot is `4.6.stable.official.89cea1439`; the audited console executable
SHA-256 is
`FC759F9D296FE54F09AB66D41DF6DDD2D278493B0E71109F6688EF029AD271AE`.

## Requirement reconciliation

| Prompt requirement | Exact-tree inspection and evidence | Verdict |
| --- | --- | --- |
| 1. Every shipped surface is a played game | The surface ledger below covers every JSON id plus duel/showdown. Each uses physical/object procedure, staged action or a persistent played object rather than an art/text delay. | PASS |
| 2. Full lifecycle and hostile action ordering | Row contracts exercise commitment/correction, legal transition, rejected verbs, result acknowledgement, repeat/rebet where applicable, safe exit, duplicate delivery, receipt replay and settlement replay. | PASS |
| 3. Input and reduced-motion equivalence | Closed ritual declarations and surface contracts bind pointer/touch regions to the same keyboard/controller action id and semantic target; reduced motion changes presentation travel/cadence only. Hostile or out-of-phase targets reject without charge. | PASS |
| 4. Unlabeled visual identity | Checked-in real-renderer contact sheets cover tables, machines, tickets, the Bar Dice cup, Coin Pusher cabinets and the Rourke room using actor/object/room state. Hash-backed row manifests remain applicable because the frozen tree contains the same product blobs. | PASS |
| 5. Math, RTP and conservation | The table below records the exact accepted samples/figures. Split/double/insurance, commission, multi-bet, direct-bankroll machines, partial tickets, street interruptions and pusher collection remain covered by their focused suites. No math file changed in closeout. | PASS |
| 6. Integration consumers | `game06_2_depth_contract`, full game contracts and the depth spine cover Players Card, authored tutorial predicates, count/heat, Crew plays, heist honesty/detection, and the unchanged duel ladder. | PASS |
| 7. Actor and energy honesty | Each adopting row proves material actor, object or interactable changes at all declared tiers; the visual manifests cover quiet/active/pressure/terminal states. No music/text-only tier is accepted. | PASS |
| 8. Neighbour outcome isolation | Blackjack, Roulette/Baccarat, Bar Dice and showdown row contracts run ten deterministic actor/opponent seeds and compare authoritative player outcomes/bankroll. Crew Poker policies inspect only public/dealt state. | PASS |
| 9. Save/exit/revisit | Focused contracts cover every declared phase, including mid-shoe, squeeze, spin, scratch, feature, street interruption and duel. Receipt and one-shot ledgers prevent a second charge, payout, reward, dialogue or audio event. | PASS |
| 10. Maximal composition | Family 1 consumer checks plus accepted `depth06_1` exercise games at scenario/event/service/traveler/Sweep-capable nodes and preserve ordinary exit behavior. The exact 55-id/1,485-pair audit had zero failures; its reproducible 24-scenario sample and focused authority/visual/RTP checks are green. | PASS |
| 11. Exact performance/liveness | Accepted row reports include native/low-end-Web budgets, zero forbidden full-snapshot calls and nonzero liveness for all touched animated surfaces. Blackjack's authoritative repeat path now retains eight replay boundaries: the exact 25-hand prefix fell from 142.213s to 44.392s while preserving outcome/checkpoint chains and plateauing near 56KB. Coin Pusher's final locked Chrome run remains green at unchanged caps. | PASS BY BINDING CHECKPOINTS |
| 12. Exact-tree complete gates | Game-owned focused contracts pass on this tree. The final Blackjack audit, repaired Crew depth comparison, and aggregate functional games suite remain pending. Native/Web, accessibility, determinism, RTP and visual artifacts are bound to unchanged product blobs above. | PENDING FINAL GATES |

## Complete shipped-surface ledger

“Equivalents” means pointer/touch plus keyboard and controller focus/confirm map
to the same semantic action and target; reduced motion removes travel or shortens
presentation only, never the authoritative timing window or result.

| Surface | Played phases / tactile verbs and equivalents | Actors, objects and material energy | Exact math evidence | Verdict |
| --- | --- | --- | --- | --- |
| Scratch Tickets | browse/buy/select/scratch/reveal/file/redeem/repeat; bounded scratch stroke and focused reveal equivalents | clerk, rack, issued ticket, foil, prize cells; stock/crowd/winner states | seven types, 100,000 samples/type; all authored bands (`3.70` through `4.40` outer configured bounds), Crossword nominal `3.953333...` return/price | PASS |
| Pull Tabs | browse/buy/collect tray/open windows in order/file/redeem/repeat | clerk, dispenser, tray, persistent ticket windows; stock, queue and winner states | 24-machine seeded deal audit and complete authored prize/stock matrix | PASS |
| Slot | approach/commit/spin/feature/settlement/acknowledgement/repeat; chips/buttons, nudge and Pinball controls have semantic equivalents | cabinet, reels/balls/feature objects, neighbours and attendant; idle/active/bonus/lockup/jackpot states | 10,000 spins: Pinball classic `0.95176`, Pinball video `0.97507`, Buffalo line `0.94640`, Buffalo video `0.96964` | PASS |
| Bar Dice | wager/cover/cup/throw/reveal/call/settle; place/correct, shake/throw/keep-reroll and call equivalents | opponent, onlookers, cup/dice/pot; quiet/crowded/tell/pressure/interruption states | 1,000 rounds each: friendly/standard/sharp house edge `0.1106/0.1423/0.1719` | PASS |
| Blackjack | wagering/deal/player decision/dealer procedure/settlement/terminal presentation/rebet; chip place/remove, deal, hit/stand/double/split/surrender, peek/count equivalents | dealer, neighbours, pit, shoe/cards/chips/count bubbles; attention/heat/backoff materially alters table/actors | exact rule/paytable/conservation suite plus current sealed-host 1,000-hand payout audit (final report hash pending) | PENDING AUDIT HASH |
| Baccarat | commitment/deal/squeeze/third-card/reveal/settle/repeat; stack correction and card squeeze equivalents | dealer, neighbours, shoe/cards/stacks; shoe depth, attention and security tiers | 400 advancing-shoe hands: Banker/Player/Tie `0.477/0.440/0.083`, flat Banker delta `+109`; commission exact | PASS |
| Craps | approach/bet correction/come-out/point/working bets/throw/settle/interruption/repeat | stick/dealer/shooter/crowd, dice/table/bet stacks; five profiles and warning/relocation/dispersal states | million-roll wager matrix; core/street pass parity `0.988326`; every documented wager band PASS | PASS |
| Roulette | commitment/correction/spin/ball/drop/settlement/repeat; named-stack placement/removal and spin equivalents | dealer/neighbours, wheel/ball/layout/stacks; crowd and heat tiers | all 157 targets pass hit-region and payout checks; ten sealed spins, 96 trajectory frames each | PASS |
| Crew Draw Poker | idle/ante/deal/before betting/draw/after betting/showdown/cash-out/new night; hold/call/raise/fold/draw equivalents | two or three Crew seats, cards/pot/button, public tells/night scene; ordered action-driven energy | friendly capped-stake pot conservation and five-card evaluation; no casino RTP claim | PASS via `crew06_10` / `depth06_1` |
| Video Poker | approach/commit/deal/hold/draw/settle/double/repeat; chip/stake, five-card hold and Holdout equivalents | cabinet/cards/buttons/meters/security observer; idle/deal/hold/draw/win/double states | declared: Jacks `0.9973`, Deuces `0.8866`, DDB `0.9365`; separate 10,000-round observed `0.9665/0.9261/0.9344` | PASS |
| Coin Pusher | aim/queue/drop/physical travel/nudge or skill-stop/feature/cup/collect/repeat/exit | three distinct cabinets, nozzle/Plinko cups/platform/300-body field/prize objects/attendant; tell ladder and alarm | 600,000 paid drops: Quarter `0.810025`, Ridge `0.903210`, Vault `0.798925` physical ROI; feature tokens separated | PASS |
| Grand Casino duel/showdown | approach/seating/response/commitment/reveal/break/crowd change/outcome staging/exit; respond, place/correct/rebet, edge call, reveal and acknowledgement equivalents | Rourke, player, witnesses, security, public Crew; room/rail/table/cards/stacks change across all nine phases | not an RTP game: unchanged five-hand ladder, 10% + 20%/cheat-level Rourke edge, exact margin terminals `-61/-60/11/12` | PASS |

## Exact-tree gate ledger

| Gate | Result |
| --- | --- |
| `tools/game_ritual_vocabulary_contract_test.ps1` | PASS; `game_ritual/1`, 132 negative fixtures, seven neutrality targets, env vocabulary `749390ce` |
| `game_ritual_runtime_test.gd` | PASS |
| `game06_2_depth_contract.gd` | PASS |
| `game06_2_repeated_reprieve_contract.gd` | PASS; two fresh normalized semantic fixtures plus terminal reprieve mechanics |
| `game06_3_depth_contract.gd` | PASS; Roulette and Baccarat |
| `game06_4_machine_ritual_contract.gd` | PASS |
| `game06_6_bar_dice_contract.gd` | PASS; seven phases, ten seeds |
| `game06_7_showdown_duel_contract.gd` | PASS; nine phases, ten seeds |
| Independent contact-sheet inspection | PASS for checked-in Bar Dice and Rourke matrices: cup/dice/pot/opponent staging and rail/table/stacks/Rourke staging remain distinguishable when title/reward copy is ignored; phase, pressure, crowd and terminal changes are materially visible |
| Project validation during first aggregate attempt | PASS in 109.128s; aggregate did not start because the intentional concurrent-process guard found the still-running Blackjack audit. This setup-only red is retained and will not be called a suite result. |
| `crew06_10_depth_contract.gd` exact integrated rerun | PENDING depth-lane comparison repair integration |
| Clean aggregate `FoundationSuite games` | PENDING; inherited `check_slots_surfaces.gd` parser gap must close first |
| `depth06_1` exact-tree dependency | PASS/DONE at `b33a05843fb161cd1c2970b4af2a475473beac40`; 55 ids, 1,485 pairs, zero failures; two byte-identical 10-seed/560-checkpoint reports, combined hash `1473694648` |

The earlier Blackjack wrapper is retained timing-red under four-lane closeout
load: the functional report has zero failures, while the wrapper exceeded its
historical wall-time allowance. No allowance was raised. The final clean
aggregate run above is the Family 1 binding result.

## Remediation and retained failures

- `754fca1b` updates two verification probes only. The heat/backoff probe starts
  at the documented RunState threshold rather than fabricating a receipt-free
  result past sealed authority. The terminal-presentation probe now verifies
  count bubbles and settlement through the production sealed host. Both pass.
- `tools/blackjack_seed_audit.gd` carries the authoritative environment between
  hands and advances terminal presentation through sealed auto intents. Its
  predecessor's detached repeated-hand path is retained as a failed audit
  attempt, not a product defect or pass.
- Harness commit `47a3a241` repairs two escaped gate defects without changing
  product code. The Blackjack audit now commits sealed placement, drives each
  decision through sealed surface delivery, accepts only settled-hand results,
  carries the current environment, and clears terminal presentation. The shared
  Roulette/Baccarat proposal resolver now lives in the intermediate parent that
  calls it, so the generated table-game leaf compiles with unchanged semantics.
- The first full run of that repaired audit passed 120 generated clean/count
  cases and 769 payout hands, then retained a selection-only `play_basic`
  command as if it were a sealed resolving delivery at the old 16-iteration
  ceiling. Report SHA-256
  `E951F17595B611EE9F8D66F4D7283A9CA529558FB2FA81ACB7C90A391334D175`
  is preserved as RED. Test-only successor `cae8bc6e` distinguishes staged
  public selection from sealed resolution, fails closed on a resolving command
  without delivery, adds an exact two-click regression, and bounds four-split-
  hand action traversal at 64 surface steps. Product authority is unchanged.
- That deterministic regression revealed one real public interaction defect:
  Blackjack's active-hand Deal fallback advertised a second click but discarded
  the host's confirmation flag. Exact integrated commit `039e3326` forwards the
  flag into the existing action command, so the second click now mints its
  ordinary sealed delivery. The focused 1-seed/25-hand audit passed every rule
  fixture plus the new confirmation fixture and all 25 payout hands with zero
  failures/warnings; report SHA-256
  `87DC8DF1D16565CB8EAA358947877A401F4D7A03A69CA0ABDBC282259597693C`.
- `73b7a952` removes the sealed-host repeat-play growth blocker without changing
  outcomes. Historical 128-entry v3 saves remain valid and converge on their
  next commit to eight retained boundaries; retained replay, evicted rejection,
  save/load, caller isolation, hostile receipt/proposal rejection, and exact
  25-hand outcome/checkpoint parity pass. See
  `docs/plans/game06_2_final_closeout.md`.
- A fresh-worktree direct run before Godot imported its class cache printed
  parse errors and is invalid setup evidence. Clean import and reruns pass.
- The first aggregate attempt stopped at the concurrent-Godot guard after
  validation. The guard was not bypassed; the clean rerun is recorded above.

No row requirement, sample count, performance limit or economy band was
weakened. The repeated-reprieve fixture now normalizes only valid fixed-width
randomized Crew `a`/`z` envelope values for semantic identity while preserving
the actual encrypted bytes for save/restore. Two fresh fixtures must agree
before its mechanics run. The complete per-surface routing is recorded in
`docs/plans/game06_8_exact_per_game_gate_inventory.md`.

## Human handoff

After the two pending automated entries close, no Family 1 implementation or
automated acceptance work remains. `playtest06_1` should still ask the owner to
judge learnability, pacing, tactile satisfaction and visual identity across a
fresh game cycle. That human taste check is not misrepresented here as an
automated pass.
