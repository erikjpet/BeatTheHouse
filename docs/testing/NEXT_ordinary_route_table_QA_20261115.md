# Ordinary travel and table persistence samples

Source 0cd7adde, runtime unchanged from delivered 8bfa0b8f. New normal seed NEXT-ORDINARY-20261115-J, no scenario, cash, table-rule, card/dice or outcome manipulation. Real Main and surface dispatch, native only. Same-process new Host Continue, not separate-process cold or browser testing.

- Travel chain 33/33: Back Alley to Bar/Fight Night, Corner Store/Aftermath, Gas/Road Crew Payday, Delta Queen. Each arrival auto-completes and retains valid sealed authority, nonempty controls, room ID, wallet and RNG through Continue. Cash 100/97/94/87/67 follows actual travel. At Delta all offered outbound routes are disabled; no forced onward travel or claim about why.
- Roulette 42/42 including repeated journey checks. Naturally offered Delta table minimum 22, available cash 67. Normal RED bet and Spin arm remain uncharged through Continue. One Confirm settles one spin with cash 89, exact net +22 and no sealed pending delivery. No outcome search. This supplements but does not explain original R08 pending failure.
- Blackjack final 42/42 including journey. Bar did not offer Blackjack (first attempt not reached), Delta does. A normal 22-unit wager debits 67 to 45. Unfinished exact player hand, wager, RNG and hand count survive Continue. Stand yields committed play_basic settlement, hands_played 1, no pending delivery, cash 45 (natural loss).
- Bar Dice 17/17 including Bar arrival. Natural five-die first Shake remains unfunded at cash 97, survives Continue with exact dice/RNG/count. Resolve, Throw, Reveal and Call settle one cup with cash 57 and matching result delta. No forced dice/ante, no popup bypass.

## Diagnostic corrections
Blackjack attempt 02 expected action_id stand, but production records finished hand as play_basic. Attempt 03 additionally expected a completed live session to remain; after settlement that session is reset (completed_session_flag false, phase empty) while committed flag true and persistent completed-hand count 1. Final assertion checks accepted canonical result and exactly one increment in the persistent completed-hand counter, zero pending delivery and cash conservation. Failed evidence retained, no product/test suite changed. Bar Dice attempt 01 used a nonexistent game-specific authority preload; it failed before gameplay. Attempt 02 uses the actual shared authority from existing test/source. These are helper errors, not game defects.

All bounded jobs have timeout false, active_at_release 0. Owner saves unchanged. Native callbacks are not physical pointer or visual Web evidence. Original broader acceptance remains open.

## Raw evidence hashes
- `E:\CodexQA\BTH\runs\next-bugfinder-travelchain-20261115-01\evidence\worker.log` SHA256 `0a1a8715d07f8985888110a08ecce29a5436cdee0fa90aadf298342d950591e3`
- `E:\CodexQA\BTH\runs\next-bugfinder-travelchain-20261115-01\evidence\job.json` SHA256 `b85c4d6feee4a26d778c8005a9f561c7ccb8922dfdbbb17345d4907c5aa95bf8`
- `E:\CodexQA\BTH\runs\next-bugfinder-travelchain-20261115-01\evidence\storage-manifest.json` SHA256 `7d380eb2990dfd9f60b2f895355d39db6d971d8e84dc5faf27cae32154bb6ddc`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryroulette-20261115-01\evidence\worker.log` SHA256 `856c359af5b531f1573f88efa6fc00d515c3de3a29db6c845748a040f7351566`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryroulette-20261115-01\evidence\job.json` SHA256 `cc6de3d5ea0f1d303430e436f6fd82c84df118b626e9b83c31da21cd77c18e5c`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryroulette-20261115-01\evidence\storage-manifest.json` SHA256 `b69ae665e6c9a0f4430806da23f417040c7dd174a46c73851627d2324d1dd977`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryblackjack-20261115-01\evidence\worker.log` SHA256 `f914b129a1435218f2ea9786bc39b9fa72110905c6fc7948d0ca2962b1380e0b`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryblackjack-20261115-01\evidence\job.json` SHA256 `b6ce48a82f6dd1017c8b68701d652c28aa59ccbc0f2f29857b3e1ee88ac20b99`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryblackjack-20261115-01\evidence\storage-manifest.json` SHA256 `f546cde141714f23f406106991a784b8589a814d97af13eb13c358f8f638def6`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryblackjack-20261115-02\evidence\worker.log` SHA256 `1fdea08e3693f501e44e1e9a5e7b13f9469ef26abccc161abff9e2c8efafce13`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryblackjack-20261115-02\evidence\job.json` SHA256 `9fdbbc6c47b91b7c0e5a8991cc93c434bb8762a77933e511d3ea42f3e55add31`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryblackjack-20261115-02\evidence\storage-manifest.json` SHA256 `485664411a1fb714fc4bef71b0f0a5826b9e1135d63de47ffab2e13b5bf4ac1b`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryblackjack-20261115-03\evidence\worker.log` SHA256 `d7ceee248d2cc5b94ea365eb993bfb55a081df7e146e338937937f2bf6c691c6`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryblackjack-20261115-03\evidence\job.json` SHA256 `d79d074875dc57b7f25dd2a81a4f3f2b94cca00dfe39a263130e1491a5eff730`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryblackjack-20261115-03\evidence\storage-manifest.json` SHA256 `0e4f70c27ae2c2b5795a9dac5caf6176a708310d2e454529ba2343885086a43a`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryblackjack-20261115-04\evidence\worker.log` SHA256 `efc8cf70e72adc6cf5e751307ed07e5c2944183c12ddadb768daf766059f557b`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryblackjack-20261115-04\evidence\job.json` SHA256 `5414e341f0cc5f6e40988dfc1f6b2d7f7d320198cb0438dd43021f20990201a2`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinaryblackjack-20261115-04\evidence\storage-manifest.json` SHA256 `5340ae0a62c04b7534593063d8a6ebff4f3ae6b2212fc832252d26a23428f5c4`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarybardice-20261115-01\evidence\worker.log` SHA256 `a207533cb2673438b992aca67403a20e2fe0d689cb5f91db2e32fa65853ce67f`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarybardice-20261115-01\evidence\job.json` SHA256 `83f9582ad756433c73d4a50cb8838d65c208d16cbaafb6a6cd6fb087511ad8f6`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarybardice-20261115-01\evidence\storage-manifest.json` SHA256 `bd2bb9949ecb603e46e284d81d4583bb2203fb6b21ca0774a75e929eea945292`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarybardice-20261115-02\evidence\worker.log` SHA256 `74dd7fb8ba7e601a6d5985a4e61e7961b14fde916f62b0ac582155f063a0477b`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarybardice-20261115-02\evidence\job.json` SHA256 `61960b84b2ffeb9d2d7d09da4e1d3d3cd7e31238254d6a86a36eecac2c6426ba`
- `E:\CodexQA\BTH\runs\next-bugfinder-ordinarybardice-20261115-02\evidence\storage-manifest.json` SHA256 `08164c8e52479f61a302359de595e7f1d79c4b11eee5e4297d58920a4a094815`

Reconciliation 24 retains 109 existing findings. Original eleven-game objective still has an unobserved historical owner; no reassignment or closure inferred. Roulette has no reconciliation finding in this checkpoint.

## QA custody limitation discovered later

Where this report uses the retained O campaign, a subsequently identified missing-companion custody limitation applies. Those public comparisons are retained, but intact private Crew authority and full campaign equivalence are not qualified; other named fixtures keep their own scope. See [BTH-NEXT-QA-PROFILE-CUSTODY-001](BTH-NEXT-QA-PROFILE-CUSTODY-001_20261115.md).
