# Crew dynamic choice UI fixes

Owner: sidebar task `6afa5073-0cb4-8191-82b0-326a14a3e029`. Fix IDs: `CREW-NOAUDIT-ENABLED-LOCK-20261116` and `CREW-STAKE-REPAY-DISCLOSURE-20261116`, bounded batches of `BTH-QA-CREW-ENDING-001`.

## Problem and change

The captured no-audit campaign displayed an enabled Lock The Count even though the planning provider marked it disabled; the real action correctly rejected it. EventModule.choice_views unconditionally overwrote dynamic providers with enabled=true and an empty reason. It now retains authored disabled and enabled=false, preserves an authored reason, and otherwise uses the visible provider text or a neutral unavailable message. Ordinary responses retain their enabled default. The authoritative event/heist guards are unchanged.

The captured Crew Money response debited $20 but only displayed Event closes as its consequence, with no numeric cost in its prose. The provider now says Repay $20, publishes the matching Bankroll -20 consequence and supplies the existing positive-cost confirmation hint. Projection and settlement share the same min(bankroll, stake) calculation. Actual popup response selection remains the normal final decision; no new custom confirmation flow, second cash effect or economy rule was added. Low-wallet quotes show the actual capped debit, including $7 and $0.

Original failed assertion, independent safe rejection and complete checkpoint custody remain in [NEXT_Crew_terms_and_stake_QA_20261116.md](NEXT_Crew_terms_and_stake_QA_20261116.md). Neither old evidence nor validator results were rewritten.

## Focused regression

Base source: `a3845c2ebb039b5edaeb2d24b3a7e75aaf2d1d5e`. Candidate product files and the committed focused test are identified below by SHA-256. Fresh guarded native import passed; no native binary, canvas scheduling or performance code changed.

`scripts/tests/crew_dynamic_ui_check.gd` has explicit modes. Contract is synthetic read-only provider/price projection coverage. Other modes load complete copies of the real ordinary campaign through official Continue, use live popup models and actual rendered Button signals, and retain Save/Continue boundaries. They do not force game states, outcomes, balances, trust or authority.

- Contract: authored unavailable reason, unavailable text/fallback, explicit enabled=false, ordinary enabled behavior, read-only views and $0/$7/$20 capped price cases: 23/23.
- No-audit captured campaign: actual disabled Lock button and missing-star reason, enabled Leave, authoritative stale rejection without mutation and Save/Continue: 14/14.
- Captured pending stake loss: visible $20 quote charges nothing until the actual response is selected; exactly one debit leaves $138, two delivery duties persist, job resolves once and stale repeat is rejected; open terms and settled state survive Continue: 20/20.
- Separate-process settled Continue: no second repayment, exact public state and intact private companions: 9/9.
- Captured alternate Shrug response: zero debit leaves $158, original job resolves once, duties persist and stale repeat/Save/Continue remain correct: 20/20.

Each actual worker command is retained in its job.json. The adapter command was `python -B .tmp/crew_ui_resume.py --checkpoint <closed Crew checkpoint> --run-id <case> --script .tmp/crew_dynamic_ui_check.gd --step <mode>`. Its external GD bytes match the repository test exactly. Every case records all three copied directories, source hashes, admitted E: storage and pre-Job/pre-child gates; CPU 12%, memory 2 GiB, assignment before execution and zero owned processes at release. Input checkpoint tree hashes stayed unchanged. Owner saves and browser profiles were never opened.

| Mode / case | Checks | Worker log SHA-256 |
| --- | --- | --- |
| contract / crew-sidebar-uic-261116-01 | 23/23 | `4e4d4c13e7bf8cad1c439c87beb7354626b7c732f39539f52fbf287ee078e9a2` |
| noaudit / crew-sidebar-uin-261116-01 | 14/14 | `57abbe44cd64a510b92a29b437b634145d9cc2a8feb2e257cf15e7bc92938c27` |
| repay / crew-sidebar-uir-261116-01 | 20/20 | `191c23a74fe536730fadca3a169fe3aa8d8a87ae7b31c8142eedf3813ea0e472` |
| settled / crew-sidebar-uird-261116-01 | 9/9 | `bf9affb974b4e5a3bc6adf11af9b8e380e4283c44b5738a9c58681a716e19fae` |
| shrug / crew-sidebar-uis-261116-01 | 20/20 | `acebbcc44ed5d15adefeeb5400b373d237070a1cbc6a13e1996e553d4bf2a06d` |

Total: 86/86. Product/test SHA-256:

- `scripts/core/event_module.gd`: `7a8406893e377a2c2c17020fb2a1768172fc625b421e833e0931e9a8845cdcc9`
- `scripts/core/crew_run_facade.gd`: `ccc108c81b19136c518f3e0ab3a865ad843a68401cd16ee0fbc1432b16524b05`
- `scripts/tests/crew_dynamic_ui_check.gd`: `544fe52482f7f1a01837942fe43b7c3222cd32818938c68ebc171190f8f43e9a`

## NEXT delivery

Fix commit `a0bae07dc17420e8b41b10cbea1742dcc319a6bb`, tree `0438340652f03f2b28bb0f8d8cce78a8b52bb3cb`, was pushed to GitHub main and its remote ref verified. The existing watcher detected, built and promoted this exact source at `2026-11-16T03:10:10Z`. No second watcher or substitute build was started. The source build was clean, passed the maintained PCK audit (1,296 files) and Web GL-handle verification.

Trusted private-LAN HTTPS metadata returned 200 at `https://192.168.0.36:8443/p/beat-the-house/play/next.json`, confirming the same full SHA. The maintained localhost NEXT entry resolves to `/p/beat-the-house/play/dev/a0bae07dc17420e8b41b10cbea1742dcc319a6bb/`. Served next.json, next-status.json, BUILD.json, build_manifest.json, REF, VERSION and the local Git tree agree on the source/version. Version: `0.6.0-dev+a0bae07dc174`.

Archive SHA-256: `808eaba119ca13ccc30f509b4270547854e1a23c9eb5cb39a2d9f1312d435e40`. Five served assets were streamed once and matched the maintained pipeline stage manifest's exact byte counts, SHA-256 and MIME. This checks the changed GDScript PCK as well as engine/native payload identity.

| Asset | Bytes | SHA-256 |
| --- | --- | --- |
| index.js | 2828608 | `0c8aacc2bab394c10845a65d3b6624df7f4678a1aea87f80612a554b28d04c8c` |
| index.wasm | 1508237 | `58263765a7f63d873211210ba389dce0b7bb45c0e50a67e978ea081ec9f1e8e8` |
| index.side.wasm | 21802358 | `f344425186abd04d042ee9fe50439a27bb71936fb7c439ed79a3d827c2cfc5f0` |
| index.pck | 124982056 | `91fbbff0ccf3bf26445b24fbb475b23d443ef8ab8e0e0246bbd87355bdcf55ef` |
| coin_pusher_native_v3_10.web.template_release.wasm32.nothreads.wasm | 340415 | `4b5a9cee1c912a5f19fcf62eb4c590a7936afa5828620d325a225faff8916b9c` |

Receipts: `E:\CodexQA\BTH\runs\crew-ui-next-probe-261116-03\evidence\next-probe.json` and `E:\CodexQA\BTH\runs\crew-ui-next-assets-261116\evidence\assets.json`. The asset verifier ran in its own admitted capped Job and released with zero owned processes. HTTP bytes and native regressions do not establish browser startup, physical pointer input or visual Web behavior. Those remain unverified under the inherited isolated-browser control limitation; no browser denial was bypassed. Stable/itch/audience settings were unchanged.

## Continued ordinary campaign and corrected interpretation

The earlier phrase that this campaign could not start another Count "in this season" was too strong. The missing-star message reflected unlearned Audit knowledge. Subsequent ordinary travel to the Grand found an actual Audit Roster. This correction changes the interpretation, not the preserved original failure: an enabled response was still misleading while the plan was unavailable.

After the fix, the real campaign continued from the intact no-knowledge checkpoint. Posted $15 travel reached Kitty Cat Lounge ($138 to $123). Its actual High Roller Invitation / Take the invite granted the advertised $50 comp and Grand route ($173). The offered free Grand trip arrived with the same cash. The ordinary host Enter the floor response was completed before selecting the actual Read the shift card, whose public terms show Heat +3 and route/story changes. That action learned Audit knowledge and made The Count live with no missing stars after Continue.

Bishop's real two-stage conversation used Wait by the window, Save/Continue, then Keep the appointment. Standing reached 100. The posted $10 return restored Punchline Back Room with $163 and observed standing 97; the two separate delivery duties remained. The actual planning popup now says The stars line up, has an enabled Lock The Count, and the ordinary lock action succeeds. This provides a genuine positive availability control after the negative saved no-knowledge case. No seed, audit, money, trust, route, recruitment or authority was injected.

Latest checkpoint: `E:/CodexQA/BTH/runs/crew-sidebar-uip14-261116`, slot `NEXT-ORDINARY-20261115-O`. Punchline Back Room, $163, zero chips, standing 97, two delivery duties, Count setup locked at action 22 with identity=true; no active delivery yet and no modal. The next offered setup lead is Watch the schedule. Original terminal, alternate Dump ending and pre-fix diagnostic checkpoints remain untouched.

These are exploratory normal-player native actions after the focused fix qualification, not an assertion of coverage for every Crew ending or all game saves. Each complete three-directory input copy remained unchanged, and all 14 bounded Jobs closed with zero owned processes.

| Continued case | Checks | Worker log SHA-256 |
| --- | --- | --- |
| crew-sidebar-uip1-261116 | 9/9 | `6d7f1b4b36336803d090b483be923b8f7a68dcd70d732fd93aab03bf4841c2e4` |
| crew-sidebar-uip2-261116 | 6/6 | `8152c22a787041ae9749ad3ca14e8fe01beb193024549829d242eb8819f2ed95` |
| crew-sidebar-uip3-261116 | 8/8 | `615ac4367435586d8d321f336f3ba72fd2eb21faa2312a84ba46a26aa2a664d9` |
| crew-sidebar-uip4-261116 | 9/9 | `1c03715cb49791c3293ec3e59dab1541d98d3c39ac0670573fd48a7f3e6d1a1d` |
| crew-sidebar-uip5-261116 | 6/6 | `1e7f9b6d8240c212ae67aa4e51c363aa51232cfec4956464aad8b6e294a68d30` |
| crew-sidebar-uip6-261116 | 6/6 | `368b8884aa22388ea04809f940ac86981eee85bcc9b5921f4dfc93e2ea412c87` |
| crew-sidebar-uip7-261116 | 7/7 | `bba627918c31e68530667a3f3fc410ac64cfb22a6c6085609a451526512e42a1` |
| crew-sidebar-uip8-261116 | 6/6 | `4bafc56495948d29d0ee206033687b69fe13781baa8a6e6d470916b945a096bb` |
| crew-sidebar-uip9-261116 | 6/6 | `51f662b94a14be1c3aa2782e3a9f2657540217c33197bcbce40a0fbd2abade6f` |
| crew-sidebar-uip10-261116 | 6/6 | `ce186cf51eede702fcde24798df74c128035dbb3fd9418c05278dffa6ecbd03b` |
| crew-sidebar-uip11-261116 | 6/6 | `79a1617f33d22d65538d5ad83ffdecefcb1a7a197dbd011c153aecd2f2809646` |
| crew-sidebar-uip12-261116 | 9/9 | `1254c08e5c515f50ec5aa73bed73e732521347efa1f19485e18fef18dad96760` |
| crew-sidebar-uip13-261116 | 6/6 | `6274a3f860d55120c20539de22dfc28146a257e2cc744e2feafe9e2657750f24` |
| crew-sidebar-uip14-261116 | 8/8 | `2169bfe86b04403f5bfc538473220e2cb8783186282901e118b097e1192910ff` |

Post-fix exploration: 98/98 across 14 Jobs, separate from the 86 focused regression checks. The two scoped fix batches are delivered; the continuous Crew parent and browser acceptance remain Open. Historical parent scope/source gaps remain explicit.

Final manual reconciliation: `E:\CodexQA\BTH\runs\crew-ui-final-reconcile-261116\evidence\reconciliation.json`. Runtime snapshot covers the 19 explicit native regression/exploration Jobs and one HTTP asset verification Job, all closed; it is not a host-wide inventory. The existing parent scope/source gaps remain Open.
