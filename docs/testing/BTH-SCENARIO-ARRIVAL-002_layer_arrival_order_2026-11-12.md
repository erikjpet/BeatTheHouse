# BTH-SCENARIO-ARRIVAL-002 — settle a layer arrival before accepting room commands

Date: 2026-11-12
Starting commit: babc66ea8e89d1d5efc62f6dc32dc1bca255fc5e.
Scope: owner-authorized FEAT-09 exception; other scenario/item work remains paused.

## Before: confirmed product defect

The ledger's old synthetic missing-exit experiment is not revived. A fresh
standard seed UF061-BRINGER-8 follows the real Parking Lot Tip, pays the
displayed $7 Punchline fare, takes Side Door / Try the word into Casino, and
uses the ordinary Comedy Club return. Initial Club, cached Club, Casino and
returned Club all have valid slot authority and base Leave bindings.

A real Club return queues travel_arrived but returns control before consuming
it. Open First Crowd Rope is a zero-turn command. Buying the ordinary $8
Two-Drink Minimum afterward flushes the old arrival against work_1 and selects
hostile_pitch. Returning during an already accepted work_1 task also delays
the authored pressure result until a later action.

The focused before check reports 25 checks, 21 pass / 4 fail. The rendered
browser reproduction on served 070fc937ad69de8d152b0dddae769f5206704821
shows $100 -> $93 after fare, the first rope accepted after the layer return,
then $85 and Open Pitch Card / empty chairs after the $8 service. This is a
product defect, classified before the runtime edit. No unexplained account
change was observed.

One exploratory helper initially attempted to enter Casino twice: Try the word
already enters it. That failed expectation was a stale helper assumption,
corrected in ignored QA code only. Both versions and the classification remain
external. The production regression retains the real automatic transition.

## Change

RunGenerator.enter_environment_layer now flushes admitted arrival facts while
the installed destination phase still owns that transition, before returning
control or storing the final world room. A rejected flush restores the existing
full transaction snapshot and exposes the error. Inactive sequences remain
accepted. No room/seal validation, scenario data, authored pressure branch,
game rule, item effect, price, text, payout or RNG rule was changed.

## After and focused boundaries

The original 25 assertions pass. The extended native Host regression passes
57/57, including partial and completed Save/Continue; the projected four-step
success path; rejection of duplicate completed action; normal layer departure
and revisit; refusal and Continue; and a synthetic rejected arrival restoring
the full durable source snapshot, money, clock, RNG and authenticated room.

This Bringer branch is nonfinancial: success and refusal must invent no reward.
The test checks account/inventory/RNG and receipt preservation; it does not
claim a positive souvenir grant. A return during actual work_1 still produces
the authored immediate hostile-pitch failure. The prior-arrival case remains
work_1 after the $8 service and can complete.

Animation liveness without pointer input: PASS (exit 0).
Full Smoke on the changed candidate: PASS, 11/11 stages, exit 0.\nLoader 833 loaded / 0 failed (baseline 831; Daily and Bringer add two scripts).\nValidation includes Python 10 + 25 + 10 tests, all passed.\nNo failed check was removed, skipped, loosened or reclassified to get this result.
Baseline: initial fresh setup 9/11 stages; corrected native setup isolated perf
passed; FEAT-03 full run 10/11, with its separate unchanged validator retry
passing. These distinct runs are retained, not relabelled as a green full gate.

## NEXT and remaining acceptance

Existing NEXT is still 070fc937. The README-only import-input difference is
held for the prepared normal cold-import qualification of origin/main 114aa355.
No pipeline workaround or guard change was made. Changed-behavior Web
acceptance is pending delivery of this fix; the browser evidence above is
strictly the before reproduction. Commit/proof delivery remains pending.

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: uf061-bringer-route-guide, uf061-bringer-layer-public, uf061-bringer-faithful-layers, uf061-bringer-autotransition-harness-correction, uf061-bringer-faithful-layers2, uf061-bringer-order-before, uf061-bringer-defect-classification, uf061-bringer-visible-before, uf061-bringer-order-after, uf061-native-private-bringer-boundaries, uf061-bringer-liveness.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\uf061-bringer-proof-raw-index\evidence\raw-evidence-index.json | 5ee9994551a8f606472c4a02a9caa1112c21ce663985f86756a5a402ae610137 |
| E:\CodexQA\BTH\runs\uf061-bringer-defect-classification\evidence\classification.json | cc9973e24488a8b44d32dc4ebd83f44652bd0399ed1a9ebd08961474bbc144c8 |
| E:\CodexQA\BTH\runs\uf061-bringer-route-guide\evidence\worker.log | 9fed75cac710411d41e577d7ecb4a4568182f669d06ee6c7078de2b229e6ebf6 |
| E:\CodexQA\BTH\runs\uf061-bringer-layer-public\evidence\worker.log | 78bcd83806e3171e0b9a17c381781e3bae6a9495583f5ae445b60febdaa932c0 |
| E:\CodexQA\BTH\runs\uf061-bringer-faithful-layers\evidence\worker.log | 97dc1afeff33a47dadb95f605f11b27c358fba1ac21a916d87e6de29f8b83030 |
| E:\CodexQA\BTH\runs\uf061-bringer-autotransition-harness-correction\evidence\worker.log | 44a1e14ca2ed22ad1962fb02371c8879e517da001989cb6cbf514ab195952fd6 |
| E:\CodexQA\BTH\runs\uf061-bringer-faithful-layers2\evidence\worker.log | 653db28c9475def2a7ae0c762600a6d96fe8b176a485df1bd649aa3abf326e92 |
| E:\CodexQA\BTH\runs\uf061-bringer-order-before\evidence\worker.log | 20a761d937b733f0b697fb4f700b9dd4b7669b35e6c871f1d40ef2b9e9c1fc4b |
| E:\CodexQA\BTH\runs\uf061-bringer-defect-classification\evidence\worker.log | 4835767214788e109b0d2dbd365c11468f8d121ef6eea72a646fe7fcf757d25a |
| E:\CodexQA\BTH\runs\uf061-bringer-visible-before\evidence\worker.log | 79dcd741834b16a051b36ca85279d1a55e8ebd79dae226e2f48ddabc06a13324 |
| E:\CodexQA\BTH\runs\uf061-bringer-order-after\evidence\worker.log | dfd5d111caeeea8c2d40c6b38afcbf2a232ae3a06c7363ca8accab5a87f6168b |
| E:\CodexQA\BTH\runs\uf061-native-private-bringer-boundaries\evidence\worker.log | 43ea256478996dc817d5bb0503a80ccec466b0a183c9989522b72dcf65ee3860 |
| E:\CodexQA\BTH\runs\uf061-bringer-liveness\evidence\worker.log | e29852b691121d700756c634d444d153d5c55c48fcf9fa04bec6ee71adb85e6b |
| E:\CodexQA\BTH\runs\uf061-bringer-visible-before\evidence\017-stale-arrival-fails-after-drink.png | a75e7fbd8e5da3cbdddde87d0e2a67a659532c01feb5b079330cd42ead10f271 |
| E:\CodexQA\BTH\runs\uf061-bringer-visible-before\evidence\018-hostile-pitch-aftermath.png | e23e452565221e04a785a59a8849737af2c46e0ecc6c59dc9f24c88d5dbde197 |

## Raw evidence paths and hashes

Raw files remain outside the repository. The external index lists every file/path/size/SHA256 from these runs: uf061-bringer-smoke.

| Absolute path | SHA-256 |
| --- | --- |
| E:\CodexQA\BTH\runs\uf061-bringer-commit-fix\evidence\raw-evidence-index.json | 56e2fbb1784cd7f92237088014a8e940396bd3dec673ef1a6688172e4305c5f8 |
| E:\CodexQA\BTH\runs\uf061-bringer-smoke\evidence\smoke\summary.json | 2661daef507dd449bc173f3803c02d9f73719757c5b9f29101efc041fc225228 |
| E:\CodexQA\BTH\runs\uf061-bringer-smoke\evidence\smoke\validate_project.stderr.txt | 607474dd0a029260048874edc0018890663b291551ec5068086b68b89892ef64 |
