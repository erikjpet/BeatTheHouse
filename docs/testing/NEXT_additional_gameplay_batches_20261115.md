# Additional bounded native gameplay batches

Source5a846a17; all runtime code unchanged from qualified Crew fix. This is
native/source coverage, not browser testing. Existing owner Chrome save remains
untouched; safe Web isolation remains unverified. Five distinct follow-on batches:

1. Grand chip liquidity:62/62. Seven game types survive zero-cash with valid
   chips; evaluator/read-only protection and terminal boundaries checked.
   Explicit synthetic RunState rooms, not a normal casino journey.
2. Slot legacy pending/autoplay recovery:134/134 warm-mode checks, below/exact
   stake and foreign binding/checkpoint/recovery/action/stake rejection controls.
   Synthetic old uncommitted intent generated through the real Main/surface API;
   no original save import, separate-process cold or Web acceptance claim.
3. Showdown Meta inventory:52/52. Normal Meta producers, authored choices,
   identity/rejection/escrow/once-only return. Explicit base-room setup bypasses
   journey and rendered input. This does not satisfy the still-missing actual
   offered-choice browser case.
4. Blackjack raise tutorial:15/15 coach and wager-state checks. Input intent
   alone does not advance the lesson without a real raised wager. Module/coach
   boundary evidence, not a first-night visible tutorial playthrough.
5. Closing fallback:61/61, generated campaign reconstruction, actual native
   Video Poker hand/closing acknowledgement/public map/Travel. Cash12 to8 after
   stake6/gross2; enabled zero-cost110-minute Walk to House remains reachable
   outside the ordinary route cap. Clock setup/reopening is simulated elapsed
   time, not real-hours wait. Producer mode only; separate cold mode not run.

Closing attempt01 rejected before gameplay because the older diagnostic expects
one umbrella private root while the storage launcher now separately maps its
world-reentry subdirectory. External attempt02 compatibility adapter points only
that diagnostic root variable to the actual admitted BTH_QA_RUN_DIR. All original
containment assertions and launcher resource/storage guards remain unchanged.
No runtime, content or permanent test edits. All five completed runs exit0,
no timeout, owned process count0. No new gameplay defects found in these samples.

Raw evidence stays under E:/CodexQA/BTH/runs:
- next-bugfinder-grandliquidity-20261115-01/evidence/worker.log: `7d7d0f754a05ca2f10c43dd13c59d1fc44073bf599f8867fffb945a17d9b9853`
- next-bugfinder-grandliquidity-20261115-01/evidence/job.json: `4df4228cdae1bf5fbd89c1eedf4f33484f8cfc61220187d82625b3e0c3ea53a2`
- native-private-bth32-next-20261115-01/evidence/worker.log: `758f11c79ee2df0fb8491ee55a1a6e97f648d4d92317db3e954b588e9ce91082`
- native-private-bth32-next-20261115-01/evidence/job.json: `738c535c9192821d42e99c638aeae0e10b74a86d1be874205a55aa4ee097cc64`
- next-bugfinder-showdownmeta-20261115-01/evidence/worker.log: `764c83b94c19e89262e0c4b88a021fefff91cfd119b9b955f42079eff138af87`
- next-bugfinder-showdownmeta-20261115-01/evidence/job.json: `1e1758190473bf0f76c5f2a77c03fa118be5d01fa0fc6c595d60c3fa9fe07b65`
- next-bugfinder-tutorialraise-20261115-01/evidence/worker.log: `91bbc0c4a4518e7a6e2f579b63ba1a988e68390b1d903b7a3627ebfe872ee4a6`
- next-bugfinder-tutorialraise-20261115-01/evidence/job.json: `a70fac7180c6f75ec4b13e32a555746beb2ec12babe76ccdb17ac2164bcf8a5c`
- native-private-next-closing-20261115-01/evidence/worker.log: `4a895e16f6f846543fbbc3d07dc0d165578b0b7c1a26af20a99667ee82143bc0`
- native-private-next-closing-20261115-01/evidence/job.json: `6820039424441092b36883c8901cc0397a87b5d526ced3be346b9a0d3d8a41ae`
- native-private-next-closing-20261115-02/evidence/worker.log: `f24f57291e631de774603f323d108e2370a0c20fa4968985fbfe3ebf883a00ef`
- native-private-next-closing-20261115-02/evidence/job.json: `5291a769c54ed4ca99653660e7a43e472f8b5b71125b87beea7caf30fabdca76`
