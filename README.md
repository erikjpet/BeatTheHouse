# Beat the House

## 1. Project Purpose

Beat the House is a **casino roguelike** focused on player adaptation, risk management, and emergent run stories. The player moves through a chain of procedurally assembled gambling environments, builds a strategy through itemization, and decides whether to win through legitimate play, information advantage, or cheating under pressure.

This document is the **master 1.0 game design document** and defines the product direction for a complete rework from scratch.

---

## 2. Product Thesis

### Core Promise

Every run should feel like a unique gambling journey where the player:

- starts small,
- scales into higher-stakes ecosystems,
- accumulates situational power,
- responds to generated environments and social pressures,
- and tries to stay solvent long enough to rise.

### Design Identity

Beat the House is:

- a **run-based casino strategy game**,
- with **item-driven buildcraft**,
- **procedural environment composition**,
- and **optional stealth/cheating risk paths**.

### What This Game Is Not

- Not a single-minigame simulator.
- Not a fixed linear campaign.
- Not a purely narrative VN-style casino story.
- Not a one-path “must cheat to win” experience.

---

## 3. Vision for 1.0

### 1.0 Goal

Deliver a complete standalone game that is replayable, coherent, and content-rich enough to stand on its own, while architected for post-launch content expansion.

### Soft Victory Definition (Option 1)

The primary soft victory for 1.0 is:

- **Prestige Victory**: acquiring an ultra-high-value status purchase (e.g., a mega yacht).

After Prestige Victory, the run may continue in endless high-tier play.

### Failure Definition

- **Hard run failure** occurs when the player has no way to continue gambling or progressing economically.
- Bankruptcy and inability to recover are terminal run states.

Debt may exist before failure, but debt is pressure—not immunity from loss.

---

## 4. Player Fantasy & Experience Pillars

### Pillar A — “I Can Adapt”

The player should feel smart for adapting their approach to the current environment, available games, and item set.

### Pillar B — “I Choose My Risk”

The player can choose clean play, subtle advantage play, or aggressive cheating routes. The game reacts to those choices.

### Pillar C — “Every Run Tells a Gambling Story”

Generated environments, recurring characters, debt relationships, and event chains create emergent narratives.

### Pillar D — “Scale Feels Real”

Runs begin in low-stakes spaces and can grow toward elite/high-stakes scenes and reputation consequences.

---

## 5. Target Session & Run Shape

- Average intended run experience: **~1 hour** (strategy + luck dependent).
- Baseline run structure target: **~6 environments**, variable by route and risk profile.
- Dwell time in environments is player-driven:
  - cautious players may farm and stabilize,
  - high-risk players may move quickly to avoid detection.

---

## 6. Core Gameplay Loop

### Macro Loop

1. Enter environment (casino ecosystem + attached support location/shop context).
2. Evaluate available games, local rules, and local risks.
3. Gamble to accumulate bankroll and momentum.
4. Acquire items, services, debts, and opportunities.
5. Trigger or avoid events based on behavior and state.
6. Unlock travel path(s) and move to next environment.
7. Repeat with increasing difficulty and stakes.

### Environment Micro Loop

1. Read context (venue type, clientele, security profile, game pool).
2. Build short-term plan (profit, survive, exploit, escape, repay).
3. Execute through game participation + item use + social choices.
4. Resolve consequences (economy, suspicion, debt, opportunities).

---

## 7. Run Progression & Difficulty Scale

### Scale Arc (Conceptual)

- **Early Tier**: bars, roadside venues, small local rooms; lower buy-ins, smaller swings.
- **Mid Tier**: regional casinos and mixed game floors; stronger surveillance, wider game pool.
- **High Tier**: elite houses, private rooms, highly structured security, large bankroll pressure.
- **Endless Prestige Tier**: post-victory high-end ecosystems, compounding complexity.

### Difficulty Drivers

Difficulty increases through combined vectors:

- game odds and volatility,
- bet sizing pressure,
- environment security sophistication,
- debt burden,
- reduced recovery opportunities,
- event hostility,
- and build mismatch (player specialization vs available game pool).

---

## 8. Economy Framework (Design-Level)

> Numeric balancing is intentionally deferred. This section defines structure, not final values.

### Economy Goals

- Reward informed risk, not random spam.
- Preserve comeback potential while keeping ruin real.
- Make travel decisions meaningful.
- Keep high-tier stakes psychologically different from low-tier stakes.

### Economy Components

- **Bankroll**: primary liquid currency.
- **Wager Channels**: game-specific betting interfaces.
- **Travel Costs**: monetary and/or conditional movement gates.
- **Service Costs**: information, cleansing suspicion, medical aid, contacts, etc.
- **Debt Instruments**: emergency liquidity with source-linked consequences.
- **Prestige Purchases**: long-horizon luxury milestones (including mega yacht target).

### Economic States

- Stable
- Growing
- Volatile
- Distressed
- Insolvent

Systems should communicate state shifts through UI and events.

---

## 9. Itemization System (Core of the Game)

Itemization is the strategic backbone of Beat the House.

### Required Item Classes (1.0)

1. **Permanent** — persists through the run.
2. **Temporary** — expires by condition/time/transition.
3. **Contraband** — strong effects with detection risk.
4. **Consumable** — single or limited charges.
5. **Debt/Obligation Artifacts** — power with creditor-linked liability.

### Item Effect Domains

- Global run modifiers
- Environment-type modifiers
- Game-family modifiers
- Event interaction modifiers
- Security/suspicion interaction modifiers

### Design Rules for Items

- Items must create trade-offs, not pure upside.
- Strong game-specific builds must be viable **and** punishable by content mismatch.
- Item text must be clear enough for strategy while preserving hidden system depth.
- Contraband should always have context-sensitive downside potential.

### Synergy Philosophy

- Buildcraft is intentional and central.
- Cross-item interactions should create emergent archetypes.
- No single archetype should be universally dominant across all environment pools.

---

## 10. Gambling Content Architecture

### Content Goal

Grow toward a broad catalog representing “the games you’d find in a casino,” while keeping each game module mechanically distinct and strategically relevant.

### 1.0 Content Structure

Games are organized by family for modular growth:

- Slots / electronic chance games
- Card games (blackjack, poker variants, etc.)
- Table chance games (roulette, craps, etc.)
- Novelty/venue-local games (pull tabs, bar dice, etc.)

### Environment Game Pooling

Each environment pulls from curated pools tied to venue identity, stakes, and narrative context.

Example pattern (conceptual):

- Bar venue: slots + pull tabs + bar dice.
- Mainline casino: slots + blackjack + poker + roulette.
- Underground room: high-stakes poker core + selective side tables.

The objective is high permutation count with coherent thematic assembly.

---

## 11. Procedural Environment Generation

### Design Intent

Environment generation should feel authored in tone but procedural in arrangement.

### Environment Composition Layers

1. **Venue Archetype** (bar, chain casino, private room, resort, etc.)
2. **Security Profile** (casual → strict)
3. **Game Pool** (which game modules spawn)
4. **Economic Profile** (stake floors/ceilings, cost pressure)
5. **Event Pool** (local story and risk opportunities)
6. **Travel Hooks** (how next destinations can unlock)

### Consistency Rule

Randomness must create variety without nonsense combinations. Constraints should protect thematic coherence.

---

## 12. Progression Map & Travel Logic

### Progression Model

Use a **branching, condition-driven map** rather than simplistic A/B/C choice.

### Path Unlock Inputs

Travel routes can be unlocked by combinations of:

- purchases (ticket, vehicle, charter, etc.),
- relationship outcomes,
- debt obligations,
- event outcomes,
- reputation state,
- or discovered opportunities.

### Destination Philosophy

Route choice should feel diegetic and consequential:

- where you can go next depends on what you did, who you know, and what you can afford.

---

## 13. Suspicion, Security, and Cheating Risk

### Visibility Model

Use a **hybrid model**:

- partially visible signals the player can read and manage,
- plus hidden factors that preserve tension and uncertainty.

### Suspicion Triggers

Suspicion should be influenced by realistic vectors:

- abnormal win rates,
- suspicious interaction patterns,
- known contraband possession,
- checkpoint detections (e.g., metal detectors in strict venues),
- and context-specific behavioral anomalies.

### Consequence Ladder

Potential outcomes escalate by environment/security severity:

- increased monitoring,
- reduced opportunities,
- forced checks,
- temporary lockouts,
- social penalties,
- hostile confrontation events,
- boss encounters.

### Choice Integrity

Cheating is an option, not a requirement. Legitimate and information-driven playstyles must remain viable.

---

## 14. Event System & Boss Encounters

### Event Philosophy

Events are the run’s narrative engine and should emerge from system state, not only random chance.

### Event Types

- Opportunistic (profitable but risky)
- Social (contacts, favors, betrayals)
- Security (inspections, surveillance shifts)
- Debt (collection pressure, renegotiation windows)
- Progression (route openings/closures)
- Landmark/Boss events

### Boss Encounter Model

The game supports multiple **contextual boss encounters** rather than a single fixed final boss.

Examples (conceptual):

- Back-room interrogation after high-risk cheating in mob-controlled venues.
- Forced high-stakes showdown tied to debt default.
- Security-led crackdown triggered by pattern-based suspicion.

Boss encounters should test build flexibility, not just raw bankroll.

---

## 15. Debt System & Consequence Design

### Debt Sources (1.0 baseline)

- Formal institutions
- Criminal lenders
- Local personal lenders
- Venue-linked credit

### Debt Design Intent

Debt is a strategic lifeline with asymmetrical risk based on lender identity.

### Consequence Variation

Consequences vary by source and severity:

- Economic: fees, escalating interest, withheld rewards.
- Mechanical: temporary penalties, access restrictions, forced obligations.
- Narrative/Social: recurring character pressure, delayed retaliation, route manipulation.

Debt should create stories, not only punishment.

---

## 16. Narrative Strategy

### Narrative Scope for 1.0

- No strict singular storyline.
- Run-centric emergent storytelling.
- Recurring characters across runs and environments.
- Local environment arcs that can chain into broader themes.

### Narrative Principle

Story should support the systems, and systems should generate story.

---

## 17. UX & Input Principles (Desktop + Mobile)

### Input Standard

Primary design target is **single-pointer interaction** (mouse/touch parity).

### UX Principles

- No critical dependency on keyboard-only actions.
- Clear tap/click affordances for betting, item use, and movement decisions.
- Consistent interaction hierarchy across mini-games.
- High readability for economy, suspicion, debt, and event state.

### Action Bar Option

If extra interactions are needed, use a touch-compatible action/capability bar rather than complex keybinding requirements.

---

## 18. Technical Architecture Principles for Rewrite

> This section defines architecture direction, not implementation detail.

### Required Engineering Principles

1. **Modular Game Interfaces**
   - Each casino game should implement a common interface contract for lifecycle, betting API, and resolution reporting.

2. **Data-Driven Content**
   - Items, environments, events, lenders, and travel routes should be data-authored and extensible without core rewrites.

3. **Deterministic Simulation Boundaries**
   - Core economy/event resolution logic should be testable and deterministic where appropriate.

4. **State Domain Separation**
   - Distinct domains for run state, economy, suspicion, debt, and narrative flags.

5. **Extensibility by Design**
   - 1.1+ additions should slot into existing schemas (new games, new archetypes, new event packs).

6. **Cross-Platform Interaction Layer**
   - Input abstraction should preserve parity between desktop and mobile.

---

## 19. 1.0 Scope Boundaries vs Post-Launch

### Must Be in 1.0

- Complete playable run loop
- Procedural environment progression
- Condition-driven travel map behavior
- Item class framework + meaningful synergies
- Suspicion/security hybrid model
- Debt source/consequence variability
- Multiple event categories including boss landmarks
- Prestige Victory purchase path
- Touch-first UX parity baseline

### Reserved for 1.1+

- Large-scale game catalog expansion packs
- Deep boss archetype libraries
- Extended creditor faction trees
- Additional prestige ladders beyond yacht pathway
- Expanded narrative chain complexity

---

## 20. Content Quality Bar

Any 1.0 system or content addition should pass this check:

- Does it improve adaptation gameplay?
- Does it create meaningful risk/reward tension?
- Does it interact with item builds and environment context?
- Does it preserve run uniqueness?
- Does it support the low-to-high stakes fantasy arc?

If not, it is out of scope for 1.0.

---

## 21. Open Questions (Intentional)

These are intentionally unresolved and should be finalized during implementation planning:

- Exact numeric balance curves
- Exact final prestige purchase pricing and scaling
- Detailed boss event scripting matrices
- Final list and cadence of environment archetypes
- Individual mini-game mechanical specs and tuning

This document defines direction and system intent; production specs can branch from it.

---

## 22. Final Statement

Beat the House 1.0 is a replayable casino roguelike about adaptive strategy under pressure. It combines gambling systems, item buildcraft, conditional progression, social risk, and escalating stakes into an emergent run narrative.

The player’s story is not “beat one scripted ending.”

It is: survive, adapt, ascend, purchase prestige—and then decide how far into the high-stakes world they are willing to go.
