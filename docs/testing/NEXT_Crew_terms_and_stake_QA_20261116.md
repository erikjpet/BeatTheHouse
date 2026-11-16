# Crew terms, recruitment and stake-loss QA

Stable IDs: `BTH-QA-CREW-ENDING-001` / `BTH-QA-CREW-ENDING-001-SIDEBAR-20261116`. Owner: sidebar task `6afa5073-0cb4-8191-82b0-326a14a3e029`.

Source `7f75625cb5ddb5c4576c3c60c276190aa56060b4` differs from product baseline `3cecec33096ea336ecd8d5dd06378c62e2043cc6` only in QA documentation/ledger files. No product, authority validator or storage guard was changed. Coverage uses headless native public host actions and actual Control pressed signals; it does not establish browser/WASM, physical pointer, or human pacing acceptance.

## Ordinary campaign progression

Starting from the preserved Punchline Casino checkpoint with $92, the actual Crew terms offer was declined through Not Now, reopened deliberately, saved while offered and while confirmation was armed, then accepted through the real displayed Confirm button. The first Accept did not settle the loan. Final confirmation granted $70 and two delivery duties, with no monetary debt or interest. Save/Continue retained cash $162, the duties, RNG and valid active room/private companions. A second advance here is disabled until the outstanding duties are completed. This sequence passed 32 checks.

The normal free Club return exposed Knuckles. Keep it simple recruited him through the saved actual response, raising public standing 40 to 70 without a charge. The ordinary free Side Door return exposed Mags; Follow the order recruited her through another saved conversation, raising standing to 100. Both public recruitment states persist as accepted fallback contacts. Normal access opened the Crew Back Room without an injected gate, money, route, recruitment or reputation change.

The actual Job Board offered Low-Roller Stake / Mags: here tonight, 16 actions, $10 / trust +6. The dismissible board popup closes on Continue and reopens normally; recruitment TalkDock conversations retain their pending responses. Reopening and accepting the live enabled job choice added the Crew's $20 stake, cash $162 to $182. Mags changed to job_out and the board no longer offered the same job. A separate-process Continue retained active job mags_low_roller_stake:0001, expiry action 24, stake $20, profit target $12, and session net zero.

## Settlement and alternate loss responses

Three ordinary legal Play Hand actions at $8 each settled naturally as losses. Separate-process boundaries retained exact hand counts 1, 2 and 3, wallet $174, $166 and $158, and job session net -$8, -$16 and -$24. These are the game's normal automatic basic-hand settlements, not individual Hit/Stand gestures or controlled outcomes. The third settlement exposed the actual Crew Money decision. Its pending state survived a normal Back Room layer change and Continue; returning to the casino exposed it again.

Two complete copies of the same intact pending-loss checkpoint exercised the real offered alternatives:

- Repay the stake debited $20 once, leaving $138; the job became resolved / failed, standing became 95 and Mags returned to familiar contact with marker standing.
- Shrug it off debited nothing, leaving $158; the job became resolved / failed with the same public standing/contact changes. Another OS-process Continue retained this branch and valid authority/private companions.

Both responses preserved the separate two delivery duties and rejected a stale repeated response without another debit or change to wallet, run RNG or public job state. No private outcome/grievance data was read to choose an action. The repaid branch also continued normally to the Back Room in a fresh process.

## UI finding for gameplay review

`CREW-STAKE-REPAY-DISCLOSURE-20261116`: The real repayment option is labeled Repay the stake and says Make the crew whole. The loss still costs trust. Its actual consequence summary is Event closes and requires_confirm is false. It does not show the $20 debit that the native action then takes. The earlier board text describes the reward ($10), deadline and venue but not the amount of the Crew stake. The captured live popup, not a fabricated fixture, establishes this bounded missing numeric disclosure. Review the intended amount/cost preview and confirmation behavior before treating this UI as accepted; this QA evidence does not patch it.

Source corroboration: `scripts/core/crew_run_facade.gd:2139` constructs the two response labels/text with only an event hook; `crew_resolve_stake_horse_loss` at line 2149 debits min(bankroll, crew_stake) for repay. Mechanical debit/idempotence and save behavior passed; the UI disclosure observation remains open.

## Preserved next state

Continuing branch: `E:/CodexQA/BTH/runs/crew-sidebar-repaid-backroom-20261116-01`, slot `NEXT-ORDINARY-20261115-O`, Punchline Back Room, $138, zero chips, standing 95, two delivery duties, one earned unopened bag, no modal. Rook leads and Lock The Count are visible ordinary next options. Alternate branch: `crew-sidebar-lowroller-shrug-cold-20261116-01`, casino $158. The original completed Clean Sweep/pending-bag checkpoint and owner saves remain untouched.

This is continued coverage after the earlier terminal diagnostic classification and bag/New Run/route checks in [NEXT_Crew_terminal_classification_20261116.md](NEXT_Crew_terminal_classification_20261116.md). The full historical parent scope/source and browser/WASM acceptance remain open; no bounded passing sequence closes them.

## Evidence

All workers used admitted E: storage, complete verified save_dir/appdata/localappdata copies, manifests and pre-Job/pre-child gates, CPU 12% / 2 GiB memory caps, assignment before execution, and released with zero owned processes. The wrappers reported each input checkpoint tree unchanged.

| Case | Checks | Worker log SHA-256 |
| --- | --- | --- |
| crew-sidebar-terms-progress-20261116-01 | 32/32 | `02950472fce5b63873d793c6dbd6ce216654f1acce57f3cf0757538b4a996ca1` |
| crew-sidebar-recruitment-club-20261116-01 | 7/7 | `109551507bcc7ff75a25ef40129c31379fda7dbb5b3277e6678f521fa1a2f9ee` |
| crew-sidebar-knuckles-open-20261116-01 | 6/6 | `a62030a4bd1ab170060f6e1b360705a05ce52c3c22fa8886f4332e153a648a3b` |
| crew-sidebar-knuckles-recruited-20261116-01 | 7/7 | `1f848d6388d84e588fc3b94776014c9ee827fef63ca21894c6fbea1811c58d8b` |
| crew-sidebar-recruitment-casino-20261116-01 | 6/6 | `7ce1cb17ac66f9a85af906feedee8969e74bc7fb96268c16a04b1d6fad35d830` |
| crew-sidebar-mags-open-20261116-01 | 6/6 | `16c5b3bb545025393043d0cdab37e0096d0916147654c03902a606094d9d0bec` |
| crew-sidebar-mags-recruited-20261116-01 | 6/6 | `24271b662f4f01de5e54b194b35b1cc1cbd037d600f8da408ebf9637bd830143` |
| crew-sidebar-backroom-entry-20261116-01 | 6/6 | `4c95da9a703e6a13c02890730190d3b54564e7715d60e52b6455a020195ed87a` |
| crew-sidebar-jobboard-open-20261116-01 | 6/6 | `1017fc52a2f5e1948e09c498db1950a245896e48a453adde42bc7821479aa8df` |
| crew-sidebar-jobboard-offer-20261116-01 | 6/6 | `eaf6257a033219812ac826e56ea104530bed0be5ab57702503211fb8f86b3a25` |
| crew-sidebar-lowroller-accepted-20261116-01 | 8/8 | `2c6c48dbf2509f6a682dca865827dafb8d6fcd0cc3106a1f2d5b6d09ca5d449b` |
| crew-sidebar-lowroller-casino-20261116-01 | 6/6 | `1915369999219a56ac9a7c2143e1a6754ea10e5910587a5b689c82730e465c95` |
| crew-sidebar-lowroller-blackjack-20261116-01 | 6/6 | `d95ea7efe3de96f53dd4a4a31c228f66f3281bdb47c653f8baf652528af1458e` |
| crew-sidebar-lowroller-hand1-20261116-01 | 10/10 | `41c6b4103653b29abb96330b26f7ed8803d9fbe276a844e952049f2abe13f00c` |
| crew-sidebar-lowroller-hand2-20261116-01 | 10/10 | `ffda4aa700ae7ef4cfdac82b81f5a2d9d8e0c088cd56ccf83e979a18946fcc21` |
| crew-sidebar-lowroller-hand3-20261116-01 | 10/10 | `6a3dc71e780c6e1a3a97191b6bb34bf56ad3e110b38e58a46462c7006688fa81` |
| crew-sidebar-lowroller-loss-backroom-20261116-01 | 6/6 | `81507f97e282057961d3edeba7e284a70767ccc1d09ad6b86b3895487db5ed90` |
| crew-sidebar-lowroller-loss-offer-20261116-01 | 7/7 | `540e6417061a1c189121054021811b4682f89b1cf2819e2f2debeace4c16c55f` |
| crew-sidebar-lowroller-repaid-20261116-01 | 12/12 | `7116497631c3a62b423e93738af32b71392085d3a33a58f7049bd863507f428f` |
| crew-sidebar-lowroller-shrugged-20261116-01 | 12/12 | `71c4005bd2100907b4985f3a17fac3c3ec4050d27585e356c5595d00f2db6248` |
| crew-sidebar-lowroller-shrug-cold-20261116-01 | 5/5 | `04911ce3c56b52c830721198071f5297adf52ca63050865386436837cfbf91e1` |
| crew-sidebar-repaid-backroom-20261116-01 | 6/6 | `64f197dd182fe56f66bdfb903705ff6f7b3de8f81503adedc834acb92b338339` |

Total: 186 passing checks across 22 closed Jobs. Original failed logs and the earlier terminal checkpoint are retained. Browser/WASM and human pointer/pacing acceptance remain open; no product or animation scheduling code changed.
