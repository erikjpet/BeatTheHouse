Status: TODO
Board row: `world06_3` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 world06_3: The Numbers — Book, Desk, Routes and Rigging

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This is a depth pass over the
shipped Numbers racket, not a redesign of its draw math or economy. Read
`scripts/core/numbers_model.gd` in full (`tuning`, `reset`, `snapshot`,
`restore`, `advance_to`, `status` and the rest), `data/crew/numbers.json`, the
archived `crew06_3_numbers_prompt.md`, the `world06_1` adapter contract under
`docs/plans/`, and the landed rumor system in `data/town/rumors.json`.

## Why this rework exists

The Numbers is the most texture-rich idea in the crew path: a daily draw, slips
as objects, venue books with staggered closes, runner routes, a crew fix with a
bribe and a camouflage spread, and a solo past-post cheat with a discovery chain
and a street-debt consequence. All of it currently resolves through choice
lists. Placing a bet with a bookmaker, which should be the most characterful
transaction in the game, is a menu item.

## Board and dependencies

Follow the active board protocol. Claim `world06_3`. `world06_1` must be landed
and reviewed; build only on its accepted head. You own
`scripts/core/numbers_model.gd`, `data/crew/numbers.json`, their surfaces and
their tests exclusively. Delivery-based runner routes belong to `world06_2`;
consume its API rather than reimplementing routing.

## 1. The book is a place

- Each venue's book becomes a real location within its environment: a desk, a
  corner, a back table, with a bookmaker actor who has authored states for open,
  busy, closing, closed, friendly, wary and suspicious.
- Staggered close times become visible and readable before they matter. A player
  should be able to see that a book is about to close and decide to hurry.
- Placing a slip is a transaction with a person: the number is chosen, the money
  crosses, the slip is written and handed over. Keep the landed bet limits,
  odds, payouts and tuning exactly.
- The slip is a carried object. It can be lost, shown, hidden or handed to
  someone, consistent with the shipped `numbers_slips` item contract.

## 2. The draw is an occasion

- The daily seeded draw stays at its action boundary with its exact landed math
  and timing. Presentation may never alter, preview or reroll it.
- Give the draw a staged moment where the player can be present: the number
  coming in, the room reacting, winners and losers visible. Being elsewhere when
  it lands must remain fully supported and must not disadvantage the player.
- Collecting a win is a transaction with the bookmaker, and a large win changes
  their state and the room's attention. Payout values stay exactly as landed.

## 3. Runner routes

- Runner mode routes become played sequences using the `world06_2` delivery API,
  with the book's close times as real deadlines and the collected slips as
  carried objects.
- Each stop is a distinct place with its own bookmaker and its own state. A
  route that arrives after a close must fail honestly and consistently.
- Keep the landed route economics, trust rewards and grievance contracts exactly.

## 4. Both rig routes, staged

- **The crew fix** — the bribe run, the camouflage spread and the player cut —
  becomes a sequence of real transactions with real people at real places. The
  camouflage spread in particular must be something the player performs and can
  perform badly, not a parameter.
- **Solo past-posting** — the discovery chain, the travel-speed exploit and the
  street-debt consequence — becomes physically staged: the player must be
  somewhere, do something observable, and be seen or not seen. Keep the landed
  discovery conditions, detection math and consequences exactly.
- Tells for both routes must be observable and derived from authoritative state.
  A rigged draw's leak into rumors keeps its landed contract; the rumor must
  remain truthful about what actually happened.
- Nothing in the staging may reveal the draw before its boundary, and nothing
  may leak the fix to a player who has not earned the information.

## 5. Persistence and honesty

- Every consequence fires exactly once across save, exit, travel, revisit and
  expiry. Slips, wins, debts and grievances must survive exactly.
- Aftermath persists: a bookmaker who remembers a past-post, a book that closes
  early to you, a venue whose crowd changed after a big hit. A global flag alone
  is not aftermath.
- A run that ignores the crew path and simply plays the numbers as a punter must
  work completely and cost nothing extra.

## 6. Tests and acceptance

- Draw math, timing, odds and payouts unchanged, asserted against the landed
  figures across 10 seeds.
- Full lifecycle played: place, hold, draw present, draw absent, collect, miss a
  close, lose a slip, and every terminal case.
- Runner routes end to end through the `world06_2` API, including late arrival.
- Both rig routes end to end, including discovery, failure, detection and the
  street-debt consequence, with exactly-once assertions on every effect.
- Leak and privacy tests: the draw cannot be previewed, the fix cannot be
  inferred by an unqualified player, and rumor emission stays truthful.
- Exactly-once assertions across save, reload, revisit and expiry for every
  reward, debt, trust change and grievance.
- Crew-ignoring runs unaffected; extend the golden probe.
- 10-seed determinism, native/Web parity, performance with the idle liveness
  counter-gate, accessibility for every new interaction.
- Visual QA: book open, busy, closing, closed, slip placed, slip carried, draw
  moment present and absent, collection, large win, refusal, both rig routes,
  discovery, reduced motion, small screen.

Run project validation, all relevant foundation suites, 10-seed determinism,
native/Web parity, performance, accessibility and visual QA. Archive only with
exact evidence and with the unchanged-math table attached.
