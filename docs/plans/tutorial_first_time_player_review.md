# Guided tutorial first-time-player review

Date: 2026-08-01

## Plain verdict

The tutorial is mechanically complete, but it is **not yet complete as a first-time-player tutorial**.

I can follow its forced route because each beat eventually points at one permitted action. I would not leave it understanding the whole game well enough to begin a normal run confidently. The tutorial currently teaches a sequence of clicks more reliably than it teaches the reasons, systems, and consequences behind those clicks.

The route itself is much better than the old ambient-tip structure. Pal and Vivienne give the run personality, the optional gas-casino branch is meaningful, the tutorial uses real game mechanics, and Bronze is a sensible first-night endpoint. The largest remaining problems are presentation and comprehension: dialogue is visibly clipped, speaker nameplates render blank, the dialogue panel often covers the control being taught, old result text survives across unrelated rooms, and several important systems are named without being explained.

## Review method and limitation

I launched the current project in an isolated tutorial profile and attempted to control the live Godot window as a new player. The Windows capture helper could identify the exact `Beat the House (DEBUG)` window but could not attach its visual capture surface (`SetIsBorderRequired failed`). I therefore did not claim a successful mouse-driven manual run.

This review uses the closest reproducible player-facing evidence available:

- all 18 current production-scene tutorial captures under `.tmp/tut_verify/captures/`;
- the complete ordered lesson and dialogue data;
- both real-mechanics route logs in `.tmp/tut_verify/tutorial_guided_run_audit.json`;
- the verified 1280×720 production layout;
- direct inspection of TalkDock layout behavior, including its hard two-line dialogue-body limit.

Findings labelled **observed** are visible in the production captures. Findings labelled **structural** are demonstrated by the shipped lesson/data/UI configuration. A final human mouse session should be performed after the changes below, but the visible blockers do not depend on subjective mouse feel.

## First-time-player impression

### What worked

1. **The run has a clear personality.** Pal feels like a guide rather than a floating help box. Vivienne taking over at the Grand Casino creates a memorable change in status and tone. Rourke establishes the danger of cheating efficiently.
2. **The route has momentum.** Apartment → store → optional roadside win → underground table → invitation → Grand Casino is a good escalation. Each location changes the type of activity and raises the stakes.
3. **The tutorial uses the actual game.** The player buys a real item, takes real debt, plays real pull tabs, uses the real Blackjack lookaway and count systems, buys real chips, and earns a real Bronze card. This is much more credible than a simulated tutorial screen.
4. **The optional Path A is good design.** It rewards the X-ray Glasses immediately and gives a struggling player extra money without making the branch mandatory.
5. **Highlights provide directional help.** The map destination, invitation, Host desk, and major room targets are visually distinguishable when they are not occluded.
6. **The tutorial ends on a useful medium-term goal.** Bronze is an achievable reward and the Gold/Golden Card aspiration points toward continued play.
7. **The one-action gating prevents most soft-locks.** A player cannot casually wander away from a required beat. The underlying route is robust across both branches.

### What did not work

#### A. Dialogue presentation is a blocking UX defect

- **Observed:** the speaker-name plate is an empty magenta-outlined rectangle in Pal, Vivienne, Rourke, and Linda captures. The player must infer who is talking from the portrait or stale result text.
- **Observed:** longer lines are cut off. Vivienne's Players Card explanation ends visibly at “one velvet rope at”; Linda's final Bronze explanation and response extend below the viewport.
- **Structural:** `TalkDock.body_label.max_lines_visible = 2`, while many tutorial lines require three or more rendered lines at 1280×720.
- **Observed:** the large portrait and dialogue panel cover the lower-left chips, count controls, Peek/hand controls, and sometimes the highlighted target. The instruction frequently obscures the thing it asks the player to use.
- **Observed:** some yellow highlight rectangles appear on or behind the dialogue response area rather than clearly framing the room object.

This is the single most important issue. A tutorial cannot be considered complete if the instructions, speaker identity, or target control are not fully readable.

#### B. The game never states its overall loop

Pal begins with “a real roof comes with a little edge” and immediately asks for the X-ray Glasses. A new player is never plainly told:

- what the player is trying to achieve during a run;
- that cash funds travel and ordinary purchases while Grand Casino chips fund Grand tables and its shop;
- what ends or fails a run;
- why Heat, Drunk, time, debt, items, events, and Players Card standing matter;
- how this guided first night relates to a normal run.

The player is given local instructions without a mental model to attach them to.

#### C. The HUD is introduced by implication, not taught

The top bar presents Bankroll, Heat, Drunk, time, inventory, an active-item slot, and several icons immediately. Only Heat receives a conditional explanation, and that explanation may never fire for a player who completes every count bubble successfully.

The family-loan line says to watch debt follow onto the HUD, but the capture does not make the debt amount or location visually obvious. The persistent `Use Item: Empty` control is never explained. Drunk and time are never explained at all.

#### D. The X-ray Glasses are verified, but their function is not explained in inventory

The inventory capture confirms the item is carried, but its “WHAT IT DOES” section says only “Read before you move or equip it,” followed by the flavor line “Cheap frames. Expensive secrets.” A novice cannot tell whether the glasses are passive, must be equipped, are consumed, or what they reveal.

Pal later explains their pull-tab use, but the inventory lesson should establish the general item model: passive versus active, where effects are listed, and whether an item is currently active.

#### E. The Corner Store teaches ordering, but not consequences

It correctly requires inspecting both shelf items before buying one. However:

- “read the shelf, compare the hooks” assumes the player understands item hooks;
- the purchase lesson does not explain price, remaining bankroll, passive/active behavior, or how to compare value;
- the family loan is forced without showing amount, repayment timing, interest/marker behavior, or the practical consequence of debt;
- The Crew warning has good tone but does not explain what a lender relationship or favor changes mechanically.

The player learns “click these objects,” not “how to evaluate money and debt.”

#### F. The pull-tab lesson is flavorful but operationally ambiguous

The X-ray capture contains a small mark near the bottom of one stack, four stack choices, a `TICKET PILE 1/10` area, and several machine controls. “Buy down to that marked tab” does not tell a novice:

- which row/stack control to press;
- how many losing tabs must be bought first;
- the total cost of reaching the winner;
- the difference between buying, collecting the tray, opening/peeling, filing, winner/loser piles, and redeeming;
- why the result is fixed and what X-ray has actually changed.

The branch succeeds mechanically, but it needs a small, persistent step counter such as `Marked winner: stack 1, 3 tickets away — cost $3` and separate highlights for Buy → Collect → Peel → File → Leave → Clerk.

#### G. Blackjack assumes the player already knows Blackjack

“Read the cards, then finish the hand normally” is not sufficient for a player with no game experience. The tutorial never states:

- the goal is to get closer to 21 than the dealer without going over;
- number cards, face cards, and aces have different values;
- what Hit, Stand, Double, Split, Insurance, or Blackjack mean;
- when a bet is committed or what a win/loss pays.

The forced first hand should teach only Hit/Stand and the 21/bust/dealer objective. Advanced buttons can remain disabled or muted until their meaning is relevant.

#### H. Betting, lookaway, and counting are visually overloaded

- **Observed:** Pal's panel and portrait cover much of the “on-felt” chip rack while telling the player to use it.
- Drink Pass and Chip Spill are named without explaining whether they are items, free table actions, consumables, or why they are available.
- Peek is taught as an input window, but the benefit of seeing the dealer hole card is not explained.
- Counting is presented as clicking every `+1/-1` bubble, but the tutorial does not explain what those values mean, how they affect the running count, or what benefit a correct count provides.
- The count-miss proof shows Heat jumping to 70. Even if that is an artificial proof state, the player-facing warning supplies no exact consequence, recovery option, or safe way to practise.

The tutorial teaches timing challenges before it teaches the strategy those challenges represent.

#### I. Heat teaching is conditional and can be skipped by success

`tutorial_heat_warning` triggers only after `run.heat_gain_count >= 1`. A careful player who clears every count bubble can finish the tutorial without receiving the only explicit explanation of the Heat meter. A core game concept must not depend on making a mistake.

Heat should be explained before the first cheat, then receive a short contextual follow-up if the player actually gains it.

#### J. Result feedback becomes stale and misleading

**Observed:** `Lottery Clerk pays $100 for 1 winning tab` remains in the Result area throughout Underground Blackjack, the invitation, Vivienne's introduction, Rourke's warning, the comp, and Linda's Bronze scene.

For a new player, this makes the Result panel look disconnected from current actions and competes with the tutorial dialogue. Results should clear or collapse on room travel, game entry, and new tutorial dialogue, or expire after a readable interval.

#### K. Grand Casino concepts are too abstract

Vivienne's “standing opens the house one velvet rope at a time” has good voice but does not state the actual loop. “Play until Bronze lights up” does not show a novice a numeric requirement or progress state. The tutorial-compressed requirement is effectively one table-game completion, but the player is not told that.

The comp is forced but not defined: the player does not learn what was received or where it appears. Linda's cash/chips/debt-first explanation is one of the stronger mechanical lines, yet it delivers three concepts at once and is subject to the two-line clipping defect. The gift shop is pointed out, but inspecting an offer is not required, so the player may not learn how chip-priced goods differ from cash-priced store goods.

#### L. The ending is visually broken and too abrupt

Linda's Bronze line and `Aim for the Golden Card` response are clipped below the viewport in the current capture. The wording alternates among `Gold`, `Golden Card`, and `Golden Players Card`. There is no final recap of what the player learned, what persists, or what to do when starting a normal run.

## Concept-comprehension matrix

| Concept | Current tutorial result | Novice verdict | Required improvement |
|---|---|---|---|
| Overall run loop | Not directly stated | Not understood | One short opening summary plus persistent first-night checklist |
| Bankroll | Visible and changes | Partially understood | Explain spending, winnings, travel, and bankroll-zero risk |
| Cash vs chips | Linda explains late | Partially understood | Side-by-side conversion example and persistent currency labels |
| Heat | Conditional warning only | Unreliable | Guaranteed pre-cheat explanation; contextual gain/recovery follow-up |
| Drunk | HUD only | Not understood | One-sentence HUD explanation or hide until relevant |
| Time/open hours | Clock only | Not understood | Explain travel advances time and locations can close |
| Inventory/items | X-ray is picked up | Partially understood | Explicit passive/active/equipped/consumed status and actual effect text |
| Shopping | Inspect two, buy one | Operational only | Explain price, comparison, item effect, and remaining cash |
| Debt/lenders | Forced loan and warning | Partially understood | Show amount, source, repayment/cashout order, and lender consequence |
| Events | Parking note and invitation | Understood | Keep; add a consistent event visual legend |
| Travel/routes | Map and optional branch | Mostly understood | Add cost/time/open-status callout and recommended-route badge |
| Pull tabs/X-ray | Real winner path | Partially understood | Persistent stack, distance, cost, and Buy/Peel/File/Redeem steps |
| Blackjack basics | Assumed | Not understood | Teach 21, bust, dealer comparison, card values, Hit and Stand |
| Betting | Raise is required | Partially understood | Keep chips visible; show selected wager and when it locks |
| Cheating/lookaway | Real mechanic | Operational only | Explain resource source, information gained, exact risk, and recovery |
| Counting | Bubble reflex task | Not understood | Explain `+1/-1`, running count, benefit, miss penalty, and safe practice |
| Players Card | Flavor + Bronze | Partially understood | Numeric Bronze progress and consistent tier terminology |
| Comps | Forced event | Not understood | State exactly what the comp grants and where it is recorded |
| Grand shop | Pointed out | Partially understood | Require inspection of one chip-priced offer |
| Tutorial completion | Bronze dialogue | Visually broken | Full-screen completion recap and clear transition to normal play |

## Required tutorial changelog

### P0 — must be fixed before calling the tutorial complete

#### TUT-N01 — Make every tutorial line readable

- Replace the hard two-line TalkDock body limit with content-aware height, pagination, or a minimum of four readable lines.
- Keep the entire panel and every response inside the 1280×720 safe area.
- Render the actual speaker name/title in the nameplate for Pal, Vivienne, Rourke, and Linda.
- Add automated capture assertions for non-empty speaker text, full body text, and visible response controls.

Acceptance: all 48 tutorial lessons capture at 1280×720 with no clipped text, blank speaker plate, or off-screen response.

#### TUT-N02 — Stop the tutorial from covering its target

- Reposition or compact TalkDock based on the active anchor.
- Keep the highlighted room object or surface control unobscured.
- Move Pal's portrait away from the chip rack and Blackjack action areas.
- Ensure the highlight outlines the actual actionable control, not the dialogue response.

Acceptance: each lesson capture shows the complete instruction and complete target simultaneously; a strict mouse test can activate every target without hiding the dialogue first.

#### TUT-N03 — Add the missing first-minute mental model

- Before the X-ray pickup, state the run loop in plain language: explore, spend cash, gamble, manage Heat/debt/time, and pursue the Players Card.
- Sequentially identify Bankroll, Heat, Drunk, clock, Inventory, and active-item slot.
- Add a compact `Tonight's plan` tracker showing the current objective and next required action.
- Explain what ends a run and that this tutorial ends at Bronze before normal play begins.

Acceptance: a cold player can answer “What am I trying to do?”, “What can make me fail?”, and “What do the top meters mean?” before leaving the apartment.

#### TUT-N04 — Teach Blackjack before testing Blackjack

- Add a short table overlay for the goal of 21, busting, dealer comparison, card values, Hit, and Stand.
- Keep advanced actions visually secondary until their lesson.
- Show the selected bet directly beside Deal and state when it locks.
- Use a deterministic first hand that demonstrates one meaningful Hit/Stand decision without risking tutorial failure.

Acceptance: a tester who has never played Blackjack can correctly finish the clean hand and explain why.

#### TUT-N05 — Guarantee Heat comprehension without requiring failure

- Explain Heat and the meter before the first lookaway action.
- State the exact risk of Drink Pass, Peek, and missed count bubbles.
- Preserve the contextual warning after an actual Heat gain, including how Heat can be reduced or avoided.
- Do not require a deliberate severe Heat spike merely to teach the system.

Acceptance: both a perfect route and a mistake route receive a Heat lesson; only the mistake route receives the contextual consequence branch.

#### TUT-N06 — Clear stale results at context boundaries

- Clear, collapse, or expire the Result message on travel, game entry/exit, and the start of a new guided conversation.
- Preserve a short history in a menu if needed, but do not let a roadside payout remain active in the Grand Casino.

Acceptance: every tutorial capture's Result panel is empty or describes the current room/action.

#### TUT-N07 — Repair and expand the tutorial ending

- Ensure Linda's complete Bronze/Gold explanation and response fit on screen.
- Standardize one term: `Gold Players Card` or `Golden Players Card`.
- Add a completion summary covering cash/chips, debt, Heat, items, events, travel, table play, and Players Card progress.
- State what happens next and provide a clear transition to starting a normal run.

Acceptance: a cold player can describe the normal-run goal and the difference between Bronze and Gold after the final screen.

### P1 — required comprehension improvements

#### TUT-N08 — Make item effects explicit

- Replace the X-ray inventory placeholder with its actual passive effect.
- Label items as passive, active, equipped, consumable, or permanent in plain language.
- Explain the top-bar active-item slot and why X-ray does not appear there.

#### TUT-N09 — Teach money and debt with numbers

- Show store price, remaining bankroll, loan amount, lender/source, and repayment rule during the relevant beats.
- After accepting the family loan, display a clear debt receipt and highlight the exact debt HUD location.
- Explain that Grand Casino cashout services debt before returning cash.

#### TUT-N10 — Turn the pull-tab branch into a visible procedure

- Show `stack`, `tickets until target`, and `total cost` beside the X-ray marker.
- Use separate anchored steps for Buy, Collect, Peel/Open, File, Winner pile, Leave, and Redeem.
- Explain that purchase fixes the outcome and scratching/opening only reveals it.

#### TUT-N11 — Explain cheating resources and benefits

- Identify where Drink Pass and Chip Spill come from and whether they are consumed.
- Explain what seeing the hole card changes.
- Explain count bubble values, the running count, the gameplay benefit, and the miss penalty before starting the timed interaction.

#### TUT-N12 — Make Bronze progress concrete

- Replace “until Bronze lights up” with the compressed requirement in player language.
- Show visible progress such as `Grand table games: 0/1` and `Bronze ready — return to Linda`.
- Keep the objective tracker visible without competing with dialogue.

#### TUT-N13 — Split Linda's lesson into digestible steps

- Page 1: cash → chips.
- Page 2: chips fund Grand tables and the shop.
- Page 3: cashout pays house debt first.
- Require inspection of one shop offer, but do not require a purchase.
- Display the exact comp reward and where it is stored before entering the Cage.

### P2 — polish and resilience

#### TUT-N14 — Improve blocked-action feedback

- When tutorial gating blocks an action, say what is currently required and keep the target highlighted.
- Never make an unrelated click look unresponsive.

#### TUT-N15 — Clarify travel information

- Point out route cost, travel time, open/closed state, and the recommended Path A badge.
- Preserve the ability to skip Path A without presenting the skip as a mistake.

#### TUT-N16 — Reduce repeated dialogue

- Avoid replaying identical Pal lines for opening the map and selecting a destination, or for inspecting both store items.
- Use short continuation text for repeated mechanical steps.

#### TUT-N17 — Add a true novice usability gate

- Run at least five cold testers who have not played the project and at least two who do not know Blackjack.
- Record wrong clicks, time per beat, requests for help, and comprehension answers.
- Require 5/5 tutorial completion without intervention and 80%+ correct answers on the core concept checklist.

## Definition of “tutorial complete” after this review

The tutorial should not be declared complete merely because both routes can reach Bronze. It is complete when:

1. every instruction, speaker name, response, and target is simultaneously readable at the supported minimum viewport;
2. a player with no Blackjack knowledge can finish the required hands for the right reasons;
3. perfect and mistake routes both teach Heat;
4. the player can explain Bankroll, chips, debt, Heat, items, events, travel, and Players Card progress;
5. no stale result contradicts the current context;
6. the ending recaps the systems and clearly hands the player into normal play;
7. five cold-player sessions complete without intervention and meet the comprehension threshold.

No tutorial implementation was changed during this review. This document is the requested diagnosis and proposed changelog.
