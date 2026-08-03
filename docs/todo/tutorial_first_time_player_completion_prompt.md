# Agent Prompt — Repair and Complete the 0.5 First-Time-Player Tutorial

Last reconciled: 2026-08-03
Release target: 0.5.0
Status: OPEN / P0 REAL-INTERFACE SOFT-LOCK

## Current verdict

**TUTORIAL VISUAL VERIFICATION FAILED.**

An independent player used a fresh Web debug export of the current dirty tree
at 1280x720 with real pointer clicks and screenshots. Both a clean-origin New
Run and Replay Lessons soft-locked in the opening flow. The intended Apartment,
Pal, X-ray, travel, game, Grand Casino, Bronze, and completion experience has
not been proven through the legitimate player interface.

Scripted verification remains necessary but is insufficient. No document,
test, or implementation may call the tutorial complete until the real-interface
matrix and both full-route mouse playthroughs in this prompt pass.

## Binding evidence

Read completely before editing:

- `docs/plans/tutorial_verification.md` — prior 20-point scripted baseline;
- `docs/plans/tutorial_first_time_player_review.md` — TUT-N01 through N17;
- the 2026-08-03 independent real-interface audit incorporated below;
- `data/challenges/challenges.json`, which specifies
  `home_archetype_id=apartment`;
- `scripts/ui/coach_view_model.gd`, which still exposes `DEALER'S ADVICE`.

The audit changed no source files.

## Observed real-interface failures

1. Fresh New Run and Replay Lessons start in **MOTEL ROOM**, not Apartment.
2. Both activate deprecated **DEALER'S ADVICE** coach tips rather than Pal
   dialogue plus nonblocking highlights.
3. Runtime behavior contradicts the Apartment challenge configuration.
4. The initial backpack selection/highlight follows camera focus correctly.
5. Home Storage opens empty; forced X-ray Glasses are absent.
6. Inventory shows zero items, so the required X-ray check is impossible.
7. After inventory, guidance asks for the door while focus stays on backpack.
8. The door is offscreen and the highlight moves over empty/noninteractive
   space near the right object panel.
9. Clicking the visible highlight does nothing: reproducible opening soft-lock.
10. Skip loops back to “Open the backpack” instead of recovering/advancing.
11. Main-menu return leaves the tutorial popup over menu controls.
12. Run Menu is also obscured by the still-active coach overlay.
13. Overlay lifecycle/modal ownership is broken across transitions.
14. Camera focus, rendered target, highlight transform, and hit region drift
    out of sync after focus/layout changes.
15. Visible highlights can point to empty space and cannot be trusted.
16. Intended Pal/smaller-dialogue presentation is never reached.
17. Scene labels and secondary object text are too dark/low-contrast at normal
    resolution.
18. Web launch logs a main-thread blocking warning. Track it under the
    performance prompt; do not attribute the soft-lock to it without proof.
19. All scenes after the opening are not testable through the legitimate path.
20. Prior “tutorial complete” language is historical scripted evidence only.

## Proof status of the player route

Until the final real-interface matrix passes, these remain **UNPROVEN**:

- Apartment/X-ray/inventory completion;
- door and map transition;
- Corner Store purchase, phone loan, and onward travel;
- Path A Gas Casino/pull tabs and Path B skip;
- Underground Blackjack, lookaway, Peek, counting, and Heat;
- high-roller invitation;
- Grand Casino Host, Rourke, Linda, chips, shop, compressed Bronze, and return;
- tutorial ending and normal-run handoff.

## P0A — restore the legitimate opening path

### TUT-N18 — Correct entry configuration

- Make clean-profile New Run and Replay Lessons enter the authored Apartment
  tutorial deterministically.
- Trace why runtime selects Motel despite `home_archetype_id=apartment`.
- Assert the rendered room identity, world node, environment data, and tutorial
  challenge identity before the first lesson appears.

### TUT-N19 — Remove the legacy tutorial chain

- Prevent `DEALER'S ADVICE`, `tip_first_*`, and other deprecated ambient chains
  from activating in the guided tutorial through either entry path.
- Reach Pal dialogue plus the intended nonblocking highlight system in the
  actual UI, not only a scripted harness.
- Confirm legacy tips remain unavailable after save/load, Replay Lessons,
  menu return, and tutorial restart.

### TUT-N20 — Restore authored starting items

- Restore forced X-ray Glasses to the correct Apartment storage/inventory flow.
- Prove storage contains the item, pickup transfers it once, inventory shows
  it with the correct effect/type, and save/load neither loses nor duplicates
  it.
- Keep normal-run home/storage generation byte-identical and unscripted.

### TUT-N21 — Synchronize target, focus, highlight, and hit region

- Bind highlights to the current rendered target screen transform and actual
  hit region after every camera, object, viewport, panel, and layout change.
- Keep the intended target onscreen/selectable before referring to it; reset or
  redirect camera focus when moving from backpack/inventory to door/map.
- Make highlights purely visual and mouse-pass-through.
- A visible highlighted target must be clickable at the highlighted point and
  activate the same object/action the lesson expects.
- Hide/fail safely when the target is unavailable; never point to empty space.

### TUT-N22 — Correct overlay lifecycle and modal ownership

- Suspend/reflow tutorial overlays for Inventory, Run Menu, map, and every
  modal without covering modal controls.
- Clear tutorial overlays and input capture on scene changes and main-menu
  return.
- Restore the correct overlay when returning to the run, if the lesson remains
  active.
- Ensure no stale popup survives profile/run replacement or Replay Lessons.

### TUT-N23 — Safe skip and recovery

- Make Skip/recovery advance to a valid recoverable state instead of looping
  backward.
- Never use Skip as a bypass in final acceptance playthroughs.
- Add recovery tests for missing target, offscreen target, interrupted modal,
  save/load, and menu-return cases.

### TUT-N24 — Actions usable under and after dialogue

- Preserve the contract that requested actions remain usable under/after the
  intended dialogue presentation.
- Performing the requested action must advance/resolve the matching dialogue
  exactly once.
- Unrelated allowed actions remain usable; disallowed actions explain the
  current requirement rather than appearing dead.

## P0B — readability, teaching, and completion blockers (prior review)

### TUT-N01 — Fully readable dialogue

Render real speaker names, complete lines, and responses inside the 1280x720
safe area. Eliminate blank nameplates, two-line clipping, and offscreen choices.

### TUT-N02 — Instruction and target visible together

Position TalkDock/portraits so the complete instruction and actionable target
remain visible and selectable simultaneously.

### TUT-N03 — First-minute mental model

Before leaving Apartment, explain the run goal/failure, Bankroll, Heat, Drunk,
time/open hours, inventory/active items, spending, gambling, travel, debt, and
Players Card purpose. Provide a compact current objective/next action.

### TUT-N04 — Teach Blackjack before testing it

Teach 21, busting, dealer comparison, card values, Hit, Stand, selected wager,
and wager lock before advanced actions. Use a deterministic meaningful hand.

### TUT-N05 — Guaranteed Heat comprehension

Teach Heat and exact cheat risks on perfect and mistake routes, with
avoidance/recovery guidance and contextual follow-up after real Heat gain.

### TUT-N06 — Clear stale Result output

Clear/collapse/expire Result output at travel, game, and guided-conversation
boundaries while retaining optional history elsewhere.

### TUT-N07 — Complete ending and handoff

Fit Linda's content, standardize tier terminology, recap learned systems, and
explain persistence and next steps for a normal run.

## P1 — required comprehension work

- [ ] TUT-N08: show actual item effects and passive/active/equipped/consumable/
  permanent behavior; explain the active-item slot.
- [ ] TUT-N09: show store price, remaining bankroll, loan amount/source, debt
  HUD location, and repayment/cashout order numerically.
- [ ] TUT-N10: show pull-tab stack, target distance, total cost, and distinct
  Buy/Collect/Peel/File/Piles/Leave/Redeem steps; explain fixed-at-purchase.
- [ ] TUT-N11: explain cheat resource source/consumption, information benefit,
  count values, running-count benefit, miss penalty, and caught consequence.
- [ ] TUT-N12: show numerical Bronze progress and a clear return-to-Linda state.
- [ ] TUT-N13: split Linda's cash/chips/shop/debt explanation, state the comp
  reward/storage, and require inspection of one chip-priced offer.

## P2 — polish and resilience

- [ ] TUT-N14: blocked actions state the current requirement and keep the real
  target highlighted.
- [ ] TUT-N15: show travel cost, time, open state, and optional route clearly.
- [ ] TUT-N16: shorten repeated guidance during multi-step interactions.
- [ ] TUT-N17: run at least five cold testers (two without Blackjack
  knowledge); require 5/5 unassisted completion and at least 80% core-concept
  comprehension.
- [ ] TUT-N25: raise scene-label and secondary-object-text contrast to a
  readable level at 1280x720 without losing hierarchy; verify in Web captures.

## Binding real-interface visual acceptance matrix

Run against a fresh Web debug export from the exact candidate source at
1280x720. Use actual UI, real pointer clicks, and screenshots; no scripted state
injection, console mutation, test-only teleport, or skip-based bypass.

| Scene / transition | Entry/state coverage |
| --- | --- |
| Fresh-profile New Run | Clean browser origin through correct Apartment and first Pal lesson |
| Replay Lessons | Existing profile through correct Apartment and reset tutorial state |
| Apartment | Backpack, storage, X-ray pickup, inventory verification |
| Door and map | Focus redirect, target/highlight alignment through camera shifts, click, map open |
| Corner Store | Two inspections, purchase, phone loan, debt display, travel |
| Path A | Gas Casino, X-ray pull-tabs procedure, payout/redemption, rejoin route |
| Path B | Optional skip without error/penalty, rejoin route |
| Underground Blackjack | Basic hand, raised bet, lookaway, Peek, counting, perfect/miss Heat teaching |
| Invitation | Visible item/event, aligned highlight, real acceptance, travel |
| Grand Casino | Host, Rourke, comp, Linda, chips, shop inspection, compressed Bronze, return |
| Tutorial end | Bronze award, recap, overlay cleanup, normal-run handoff |
| Modal/lifecycle sweep | Inventory, Run Menu, map, other modals, scene changes, main-menu return |

For every row, capture at least one normal state and every highlighted-action
state. Prove all of the following:

- target is onscreen and visually identifiable;
- highlight encloses and continuously tracks the rendered target;
- pointer input passes through the highlight to the target's actual hit region;
- the requested action succeeds and advances/resolves the right dialogue once;
- full speaker, instruction, and response text fits;
- dialogue/overlay layering remains readable and selectable;
- unrelated allowed actions remain usable;
- no stale overlay, focus, highlight, or input capture survives navigation;
- current result/objective text matches the current scene.

## Final real-player acceptance

Complete two clean-origin full playthroughs with real mouse input:

1. New Run through the entirety of Path A and tutorial completion.
2. New Run through the Path B optional-route skip and tutorial completion.

Also repeat Replay Lessons through both route choices. The authored Path B
choice is allowed; the generic tutorial Skip/recovery control may not bypass a
broken step. No run may use state injection, hidden test controls, or manual
save editing. Required result: no soft-lock, no dead click, no misleading
highlight, no stale overlay, and no intervention.

## Automated non-regression gates

- project validation and every affected FoundationSuite;
- two-route scripted audit plus 100 alternating traversals;
- normal-run isolation and save/load at every lesson boundary;
- determinism probe (10 seeds) and stuck-state sweep (100 seeds);
- visual QA and strict rendered input tests;
- automated capture assertions for target/highlight/hit alignment, text fit,
  overlay cleanup, and modal ownership.

Automated success cannot substitute for the binding real-interface matrix.

## Deliverable

Create `docs/plans/tutorial_completion_report.md` containing a traceability
table for TUT-N01 through N25, root causes, fixes, captures for every matrix
row, scripted/real-interface results, cold-tester comprehension, and a plain
verdict. Explicitly replace historical “complete” claims with current scope-
qualified language until all acceptance is green.

## Completion and archive

Complete only after every P0 is fixed, all P1 work is complete, accepted P2 is
dispositioned, all later scenes move from UNPROVEN to PASS through the real
interface, both full routes and Replay Lessons pass with real clicks, automated
gates pass, and TUT-N17 passes. Prepend an execution record and archive to
`docs/todone/`. Do not push without user authorization.
