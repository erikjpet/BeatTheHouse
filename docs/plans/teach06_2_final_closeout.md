# teach06_2 final closeout

Status: **DONE**  
Date: 2026-09-04  
Product head: `c1cc6df82acfde2404012470f9709202e9ad7b78`

## Verdict

The 0.6 teaching pass is complete for agent-verifiable work. It recovered the
existing guided tutorial and classification, repaired every stale contextual
tip, and added only the missing just-in-time system teaching. No game rule,
economy, payout, RNG, save schema, environment authoring, or hidden-state surface
changed. `TUT-N17` is not claimed: it remains an owner/human playtest gate.

## What shipped

- The 56 guided lessons remain unchanged and in their frozen order.
- `tip06_tonight_changes_rooms` now teaches the active scenario objective and no
  longer promises a rumor merely because a scenario exists.
- `tip06_delivery_route` truthfully covers moving packages and stationary
  lookout holds at their shared active-job boundary.
- Coin Pusher teaches carriage drag, charged drop, bonus-token cups, and heavy
  feature goals; Craps teaches its current grab/drag/release throw.
- Three new once-only lessons cover back-room Poker/tells, confirmed true-rumor
  use, and Police Sweep reading at an action boundary.
- The final catalog is 66 lessons: 56 guided and ten contextual.

## Requirement evidence

| Requirement | Result |
| --- | --- |
| Classify all original lessons before authoring | PASS — 59 correct, four stale, zero redundant, zero broken; full 63-row table retained in `teach06_2_dependency_complete_lesson_classification.md`. |
| Repair stale/broken teaching | PASS — all four stale tips repaired; no broken lesson existed. |
| Missing systems | PASS — Poker/tells, trust/standing, package and lookout work, Police Sweep, scenario objectives, true rumors, Coin Pusher, and physical Craps are covered. |
| Once-only and negative triggers | PASS — every contextual lesson has positive, seen, preference-off, tutorial-run, and never-reached negatives. |
| Handoff and double-notify | PASS — every contextual lesson is dismissible, non-modal, non-consuming, and remains completed after a duplicate notification. |
| Placement/accessibility | PASS — every contextual anchor and bubble is checked at 1280x720 and 854x480, with reduced motion off/on; no target overlap or viewport escape. |
| Secrecy | PASS — discovery-blocker vocabulary and never-reached paths expose no Turn, traitor, grievance, rigged draw, or unrevealed ticket state. Poker copy names only verified public behavior. |
| Crew-ignoring run | PASS — delivery, standing, Poker, rumor, and Sweep lessons all remain inactive. |
| Guided cold run/save boundaries | PASS — both routes reach Bronze; 100/100 alternating seeds complete; all 56 guided lesson boundaries survive save/load. |
| Normal-run isolation/determinism | PASS — both audits retain normal-start hash `1024435150` and normal-stock hash `2121162340`. |

## Exact gates

- `tools/validate_project.ps1`: PASS.
- Focused Foundation `content`: PASS, zero failures, report SHA-256
  `F0A6CA3659E286766AE5ECB528D0F40DEA9753B0F142DA8C80CC41BB49B071FD`.
- Focused Foundation `coach_engine_foundation,onboarding_tutorial_arc`: PASS,
  2/2, zero failures, report SHA-256
  `C007C75F66D6B4E161C31466D70B6CA6C4CB3AC3E6CF3182731BB81D87A15AAD`.
- Guided audit A: PASS in `148123.894ms`, SHA-256
  `DE5D25E90AEF3DCDD427D4F4B6F0A196EF31D062393D5F5467B0259D36B4929C`.
- Guided audit B: PASS in `154014.529ms`, SHA-256
  `ED48193D55CCF1D3199123BE56C2D611C621F3CE9F34E6B280B484C025A74DC7`.

The first broad smoke attempt is retained honestly. It rejected six lesson
summaries over the existing 120-character cap; those were fixed and the final
content and tutorial gates pass. Its additional `Second foundation
EnvironmentInstance should leave home into the world` failure is outside this
row and was not represented as a tutorial pass or altered here.

## Human handoff

`TUT-N17` requires five cold players, including two without Blackjack knowledge,
5/5 unassisted completion, and at least 80% aggregate comprehension. That work
belongs to the owner build in `playtest06_1`; no automated result substitutes for
it.
