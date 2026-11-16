# Earned House Edge Blue Bag: claim, reveal and durable settlement

The Out Hot reward was claimed and opened through the actual native report and Home controls. It granted exactly one **Payout Pamphlet**, a blue House Edge item, instance **6** from bag **5**. Natural reveal, Skip/Continue and a clean process exit before the reel finishes converge on the same committed collection state. The original terminal wallet remains **$1,063 cash / 16 chips**, and the older **Roadside Luck Blue Bag #3** remains unopened. No product regression or product patch is established by this sampled lifecycle.

Stable native batch: `BTH-QA-CREW-ENDING-001-HOUSE-EDGE-BAG-20261116`, parent `BTH-QA-CREW-ENDING-001`; continuing owner `BTH-QA-CREW-ENDING-001-SIDEBAR-20261116`. Actual sidebar task: `6afa5073-0cb4-8191-82b0-326a14a3e029` (Playtest Crew ending). Registered in both ledgers before claiming or opening. Initial source is `77efc4281d380e2241c33c9d55d4505bc01e4873`, with only this task's three QA documentation files dirty. The genuine ending and its original pending entitlement remain preserved at `E:/CodexQA/BTH/runs/crew-sidebar-c2r-261116`; no owner profile or damaged older copy was used.

## Normal claim and Home controls

The terminal report offered exactly one pending House Edge Blue Bag. Home was disabled until the actual enabled Claim button was pressed. That durable claim allocated bag #5, increased the unopened count from one to two and advanced the instance allocator exactly once. Owned item count stayed zero, gold stayed zero, and the earned terminal wallet, heist, Heat, action index and run RNG stayed unchanged. A deliberately repeated stale claim callback did not allocate or reroll. Official Continue and a subsequent OS-process Continue retained the claimed state and unlocked Home.

The real Home report button transitions into the intentional Home meta session without replacing the ending save. Back Alley has one surface slot: with two bags its normal visible object is **Bag Shelf**, `meta_bags:all`. Activating that offered shelf opens the collection popup. Its selected card was explicitly verified as `meta:bag:5` / House Edge Blue Bag before the enabled **Open** button was pressed. The Roadside bag's card was never opened. The production callback consumed only bag #5, allocated item #6 once, retained gold0 and left the older bag byte-equivalent in the collection snapshot.

Opening grants and durably saves the item before showing the cosmetic reel. The reel's committed instance/item and landing definition match item #6 / itemdef2003. The actual item is Payout Pamphlet, `house_edge`, `blue`. The main natural path lets the normal process callback finish without pointer or button input (about4.0seconds after the initial snapshot); **Continue** closes the reel without another grant. A separate copy uses the actual **Skip** then **Continue** buttons and reaches the same state. Another copy exits cleanly while the reel is still spinning, after its durable grant. A fresh process retains the same item, does not replay the reel as a reward and cannot reopen the consumed bag. This is a clean-exit boundary, not a forced-kill or power-loss test.

The three reveal variants are separate, explicitly cloned branches of the same earned pre-open checkpoint `crew-sidebar-b3-261116`; they are not three rewards accumulated into one campaign. No reward seed, item outcome, collection contents or wallet was forced, and the result was not inspected to choose a favorable branch.

## Independent numeric classification and retained diagnostics

All original diagnostics remain hashed in the evidence table; they were not overwritten or silently treated as acceptance passes.

- `crew-sidebar-b1-261116`: the first QA script incorrectly accessed `RunState.heat`, producing three SCRIPT ERRORs and null terminal signatures despite emitting15 checks. Its claim is preserved on its disposable copy, and all15 emitted assertions are excluded from acceptance. The verifier was corrected to the existing `suspicion_level()` and `crew_action_index()` APIs, then the claim was repeated from untouched c2r as b2.
- `crew-sidebar-b4-261116`: a direct `meta_bag:5` object probe stopped before Open (one failure among9 assertions). The authored Back Alley shelf deliberately replaces individual bag objects when multiple bags exceed its one surface slot. Source inspection and the actual offered shelf path independently confirmed the normal access route. This is a harness assumption, not a missing player reward or disabled Open defect.
- `crew-sidebar-b5-261116` / `b6`: the first natural reveal passed26 warm assertions, but its cold verifier used raw17-digit double identity and failed3 of13 assertions. Independent read-only comparison after the actual UI Open found exactly four differences, all in item potency/condition/resonance/usage, maximum absolute delta **3.3306690738754696e-16**. The shared DurableStore's existing JSON writer serializes those values to its ordinary precision. All other fields, arrays, IDs, allocation, RNG, gold and unopened bags match. The item still shows **mint** condition and an identical **25-gold** sale quote. The quote is read-only; no sale was made. This sample establishes no visible condition/economy regression, and no shared persistence rewrite is warranted by these roundoff values. Both receipts are retained but excluded from the final formal acceptance count.

The final verifier does not drop numeric verification: it recursively compares warm and independently read durable stores, permits differences only in those four item channels with absolute delta below1e-14, checks identical canonical JSON representation for the whole store, and separately checks exact sale eligibility/price and displayed condition band. It captures the actual channel values and differences using full-precision JSON in evidence. Fresh OS processes and official Save/Continue then compare the complete canonical store and terminal signature to the prior successful worker's captured result. A separate negative stale consumed-bag service request must reject without mutation; it is explicitly a negative API assertion, not the player opening path.

## Preserved checkpoints and remaining scope

Main natural result: `crew-sidebar-b8-261116`. Skip branch: `crew-sidebar-b10-261116`. Exit-before-reveal branch: `crew-sidebar-b12-261116`. Slot `NEXT-ORDINARY-20261115-O` remains the earned Out Hot ending, cash1063/chips16. Each finished branch has one Payout Pamphlet #6, one unopened Roadside Luck bag #3 and gold0. The main canonical meta-state SHA-256 is `380d872f87656f9ffcf13e4b615db6d892cf41784e35cf10ee2418aa7e2ab106`.

This is headless native gameplay through public host activation and actual Control signals, with isolated profile persistence and normal autonomous reel scheduling. It does not establish physical-pointer rendering, browser startup or WASM gameplay acceptance. The inherited separate-browser-profile control blocker remains unresolved and was not bypassed. No new browser, watcher or duplicate Crew worker was started. The broader Crew objective and sidebar campaign remain Open, including historical full-scope/source reconciliation and browser/WASM acceptance; this bounded bag lifecycle alone does not close them.

Concurrent main commit `1240cebdd15ee294e8997b46d20819762d691923` belongs to another task's Slot wager fix. Its changes to foundation_main are confined to player wager preflight; bag service, reel and durable-store code are unchanged. This task preserves that work when integrating its scoped three-file QA record.


## Evidence

All cases used the admitted E: root, manifests and both launch gates, verified copies of save_dir/appdata/localappdata, CPU12%/2GiB capped Jobs, assignment before execution, and zero owned processes at release. Wrappers reported source checkpoints unchanged. Owner saves and browser profiles were untouched.

| Case | Step | Acceptance checks | Worker SHA-256 |
| --- | --- | --- | --- |
| crew-sidebar-b2-261116 | `claim` | 15/15 | `485abaabbaecdf709ce85c219d014270f053f95334bd297d7964f018ec3a2e1a` |
| crew-sidebar-b3-261116 | `verify:crew-sidebar-b2-261116` | 12/12 | `22831a58777dd4cfc863d6b6e7fd871be43d0e5f5e7c0e42fd54f99e370de9f4` |
| crew-sidebar-b7-261116 | `open:natural` | 30/30 | `6565ac29f053128735495fe065af8ecf63adce5fbc4dbadc93ef6d38dff2d94e` |
| crew-sidebar-b8-261116 | `verify:crew-sidebar-b7-261116` | 13/13 | `b80e9b1af808ac24fab62c30b05de333b9b59363647397669161fad6fc670619` |
| crew-sidebar-b9-261116 | `open:skip` | 30/30 | `8cfec6115f09d44938d28914a6d48a5d204e4fc88c201ab7f6ccbad32fa34006` |
| crew-sidebar-b10-261116 | `verify:crew-sidebar-b9-261116` | 13/13 | `a7b7fa80639a5672b2a9cd0a9784191e47af2830421476d2e74af519a4298f1d` |
| crew-sidebar-b11-261116 | `open:interrupt` | 22/22 | `6d455cfffc866bc6122d09264e1c1f12774c51aef1c1262bf762cf6aefdf5ebb` |
| crew-sidebar-b12-261116 | `verify:crew-sidebar-b11-261116` | 13/13 | `3a43aa5243be35c373d31c011ef5547e211f08c3e10b60b19c50cacc51e1bd83` |
| crew-sidebar-b1-261116 | `claim` | Excluded diagnostic | `0293bbfc693a268465c35e8299d9767f71c258e7d4f921f5d37845471f54ac98` |
| crew-sidebar-b4-261116 | `open:natural` | Excluded diagnostic | `6d1cc6e1f9a3842284030c8d994987848fba02fde2f67ef8efeac6a690756686` |
| crew-sidebar-b5-261116 | `open:natural` | Excluded diagnostic | `05b9c2e62513901c2049d0dc981435dd92b6ac4e071128b7815c9c2532061d3a` |
| crew-sidebar-b6-261116 | `verify:crew-sidebar-b5-261116` | Excluded diagnostic | `7f3ae2b4c03295f018639ff1289928dbfdb36376db494355f0e4408e822aeff9` |

Acceptance total: **148/148** in 8 closed native Jobs. 4 retained diagnostics are excluded. Exact copied scripts, source hashes, input custody, storage and launch receipts are retained beside each worker log. Consolidated receipt: `E:\CodexQA\BTH\runs\crew-bag-record-261116\evidence\cases.json`.
