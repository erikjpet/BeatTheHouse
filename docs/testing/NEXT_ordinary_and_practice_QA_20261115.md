# Ordinary campaign sample and Practice feedback diagnostic

Source: 8232ad4e9831b1f72e3a6f5e22b2b6401a3df1bd. Native only, not rendered Web testing.

## Ordinary campaign
Three predeclared NEXT-ORDINARY-20261115-A/B/C seeds, normal start and offered Gas Casino travel, automatic arrival. Final run04: 20/20 checks. B and C naturally offered Video Poker: opening Deal, explicit Save, new Host Continue, reenter and Draw retained cash/RNG and settled exact net (94 to92, net-2;93 to92, net-1). Opening Deal itself did not debit cash. Same-process new Host, not a separate-process cold restart. A offered other games; Video Poker not reached, seed not replaced. No scenario/wallet/RNG/outcome edits. Prior exploration01 could not reach Bar,02 could not reach Slots;03 checked Continue but not final Draw. These are bounded not-reached results, not failures hidden as coverage.

## BTH-FEAT-PRACTICE-FEEDBACK-001
Current synthetic lifecycle probe reconfirms stale acknowledgement survives two successful public start_environment_test_session calls while RunState identity changes and last_game_result becomes empty. It seeds the string through the production acknowledgement setter; it does NOT reproduce original rendered Motel sequence. _environment_result_feedback_view prioritizes that retained string. Successful spawn does not clear immediate_environment_acknowledgement. Failed spawn rollback must remain protected in any fix. No product edits or completion claim; historical triage scope unchanged, parent notified.

All runs guarded with isolated E profiles, timeout false, active_at_release0. No owner saves touched. Raw evidence stays outside repository.

## Evidence hashes
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinary-20261115-04\evidence\worker.log` SHA256 `ca1838000324b406f7a6c93704ca3d338b048f27107edfa12cc35ca8a660e74a`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinary-20261115-04\evidence\job.json` SHA256 `87bd77d496a1ef65cf0a22980bff0fb197c9d215fedb8657b3a0e4ac0f544a1c`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinary-20261115-04\evidence\storage-manifest.json` SHA256 `c10c2a7c7bc40afb6e24d98d191001fb6f51eb5fe0d778427a290318e27ec5ec`
- `E:\CodexQA\BTH\runs\next-bugfinder-practicefeedback-20261115-01\evidence\worker.log` SHA256 `f81818b251386300997d9f5c2c83b2d99e9e8cb49d8e62bed5bdd70ea1d5de56`
- `E:\CodexQA\BTH\runs\next-bugfinder-practicefeedback-20261115-01\evidence\job.json` SHA256 `9fb419f39767046ceb5733b14b9763d54b2a3b44148f3ed8f2ea0d90e222040a`
- `E:\CodexQA\BTH\runs\next-bugfinder-practicefeedback-20261115-01\evidence\storage-manifest.json` SHA256 `ec26b8205f4e0519b8fb5aa9937a9304095a271dcc883ac7c6be76696affe1f7`

## Authorized scoped fix

Parent confirmed current user testing/fixing scope covers correction. Successful Practice commit now clears immediate_environment_acknowledgement; failed generation path remains untouched. Red regression9 checks failed only stale acknowledgement. Green final10/10 includes actual feedback-view message and failed unknown-archetype generation preserving RunState, exact room and acknowledgement. Independent review requested from /root/fix_crew_room_return.
- `E:\CodexQA\BTH\runs\next-bugfinder-practicefeedback-red-20261115-01\evidence\worker.log` SHA256 `1b8df0a8bc0324663653919a5e1ee89fe05d96fd63ab409e02e7fb995f31288c`
- `E:\CodexQA\BTH\runs\next-bugfinder-practicefeedback-red-20261115-01\evidence\job.json` SHA256 `7e7792350c5b6c89f637c542324f356fdc717ba6224cb264e78726ce5a33a185`
- `E:\CodexQA\BTH\runs\next-bugfinder-practicefeedback-red-20261115-01\evidence\storage-manifest.json` SHA256 `67df9a251e10ef33be0e725cb213157951b9683152ad2c3b9effd6cdb0e363b0`
- `E:\CodexQA\BTH\runs\next-bugfinder-practicefeedback-green-20261115-02\evidence\worker.log` SHA256 `cfabe315301526d988977abec3a0a345575fc464b543413da7c5e1b0690486da`
- `E:\CodexQA\BTH\runs\next-bugfinder-practicefeedback-green-20261115-02\evidence\job.json` SHA256 `495026e95f0349078604d9f7a6a903f943acbd2d6fd7d6da7042be9f630e45a7`
- `E:\CodexQA\BTH\runs\next-bugfinder-practicefeedback-green-20261115-02\evidence\storage-manifest.json` SHA256 `a5e36bd0fe0dbb2791d05c3de62e147cd48100ca63a1c8dd181bc54ec11d4b4a`

Adjacent Slot practice12/12 passes strict authority, saved-shape round trip and damaged geometry rejection. Reconciliation18 has109 pre-existing unrelated findings, zero for this item after correcting owner-name drift.
- `E:\CodexQA\BTH\runs\next-bugfinder-practiceadjacent-20261115-01\evidence\worker.log` SHA256 `cd01a13caa2c33bbf075efc1125c2c973727fb97ac3ca27e340996d84aa2e769`
- `E:\CodexQA\BTH\runs\next-bugfinder-ledger-20261115-18\evidence\worker.log` SHA256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- `E:\CodexQA\BTH\runs\next-bugfinder-ledger-20261115-18\evidence\reconciliation.json` SHA256 `79623292d74c4d5905a5b534ad4703d92021bba5323fccb20794edb2f0ed374e`

Independent reviewer /root/fix_crew_room_return approved literal two-line product diff and regression before integration. Existing NEXT watcher is healthy; no extra watcher/build started.

## NEXT delivery

Fix commit8bfa0b8f148b49ee6333c6c04f6f76362a037613, tree2ca755ba928ca6ef680157efa57525506423d629, promoted2026-11-15T19:09Z. Exact /play/dev/ redirect and served BUILD, manifest,REF,VERSION match. PCK HEAD200 length124980824. next.json archive hash0f4ad477baae1e1ca62af81db75b7ef9b4eed528871cdb0e309af5b08193e3b3. Standard TLS trust retained; initial URI property read used WindowsPowerShell property underPowerShell7 and yielded empty, corrected to RequestMessage.RequestUri before successful checks. Basic Web launch and rendered corrected behavior remain unverified; reserved browser has no verified disposable profile. Stable/itch/audience unchanged.
- `E:\CodexQA\BTH\runs\next-bugfinder-practicefeedback-green-20261115-02\evidence\next-delivery.json` SHA256 `fa7ac5dab2dcfb18e406b613db2b4ddcdbdfd31411a88d8715a2bb01bea6eea6`

Reconciliation20:109 existing unrelated findings, zero scoped findings. Earlier19 schema input error (deployment state pass) corrected to verified; no release claim depended on failed reconciliation. Web acceptance remains an explicit open requirement.
