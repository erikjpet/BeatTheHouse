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

## Delivery state

Native regression is complete. Commit/push and existing NEXT watcher identity/served checks follow separately; until recorded, deployment and browser launch/behavior are unverified. The original historical parent scope/source remains unresolved and Open. No stable/itch/audience change or browser-control workaround is part of this fix.
