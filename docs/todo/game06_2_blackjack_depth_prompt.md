Status: IN_PROGRESS — implementation landed on `main`; Family 1 release-gate closeout remains open
Board row: `game06_2` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 game06_2: Blackjack Table Depth

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This is a depth pass over the
shipped blackjack implementation, not a rules rewrite. `scripts/games/blackjack.gd`
is roughly 7000 lines and is the most-integrated game in the project. Read it in
full, read the `game06_1` ritual contract document under `docs/plans/`, and read
the landed `craps06_3` table for the house pattern before editing.

## Why this rework exists

Blackjack is the game the player spends the most time in and the one the whole
economy, tutorial and crew path lean on. It currently resolves as a control
panel: choose a stake, click deal, click hit or stand, read a result line. The
dealer is a station, the neighbours are badges, and heat is a number. The target
is a played table where money is placed, procedure is performed, other players
exist, and the pit's attention is something you can see arriving.

## Board and dependencies

Follow the active board protocol. Claim `game06_2`. `game06_1` must be landed
and reviewed; build only on its accepted head. You own `scripts/games/blackjack.gd`
and its tests exclusively. You may not edit `game_module.gd`,
`table_game_visuals.gd` or `game_surface_canvas.gd` — if you need a change
there, file a runtime request with exact evidence and let the integrator decide.

## 1. Consumer audit before any edit

Blackjack's settled fields are read by systems that will silently break. Produce
a written map, with paths and symbols, of every consumer before touching the
settlement path. At minimum: the Players Card route; tutorial lessons
(`tutorial_blackjack_clean_deal`, `_clean_finish`, `_raise`, `_raised_deal`,
`_heat_precheck` and any others in `data/tutorial/lessons.json`); the count
challenge and its heat backoffs; `crew_play_model` spotter and big player
integration; heist honesty and detection derivation from normalized action kind
and game-specific settled fields; and every foundation test asserting on them.

Any field a consumer reads must keep its exact meaning, or the change must be
landed together with every consumer and proven by their tests.

## 2. Money as a placed thing

- Chip denomination selection, place, add, remove one wager, undo, clear, repeat
  last and rebet resolved — over a pending set, per the `game06_1` staged
  commitment vocabulary. Correcting one mistake must never require clearing all.
- Show available cash and chips, total new stake, at-risk stake, payout, returned
  stake and per-hand resolution with no accounting ambiguity. Split and double
  stakes must be individually readable.
- Insurance, split, double and surrender availability must be visible on the
  table with the reason a disabled action is disabled, and must not rely on
  color alone.

## 3. Dealer procedure and table phases

- Implement explicit presentation phases: `betting → deal → player decisions →
  dealer procedure → settlement → betting`. Authoritative outcomes stay seeded
  and rules-owned; presentation may never reroll or alter them.
- Stage the procedure with real beats: shoe and cut card, burn, the deal in
  order around the table, the hole card, the check, hits drawn one at a time,
  the sweep and the pay. Settlement must be readable before the next action
  without becoming slow on repeated play; allow safe acceleration.
- Card handling gets a tactile verb where it belongs — cut the shoe, wave a
  stand, tap a hit — with keyboard, controller and reduced-motion equivalents
  producing identical outcomes.
- Reject incomplete or invalid input gently, returning to the same phase without
  charging or advancing.

## 4. The table is populated

- Neighbours are actors with their own hands, decisions and reactions. They must
  never consume or generate player money, and their play must be seeded and
  deterministic. A neighbour who plays badly and busts is part of the room; a
  neighbour who changes your odds is a rules change and is forbidden.
- The dealer is an actor with authored states for shuffle, deal, check, draw,
  bust, pay, sweep, shift change, suspicion and idle.
- Pit and heat presence becomes visible: attention arriving, someone watching a
  shoe, the pit standing closer as the count challenge escalates. Heat must
  remain the same number underneath — this changes how it is shown, not what it
  is.
- Table energy must change actors, objects or interactables. Music and a patron
  line alone are a validation failure.

## 5. Cheating and crew integration

- The count challenge, its heat backoffs and its hover counting must survive
  exactly. Integrate them into the ritual so a count read happens at the table
  rather than in a detached panel, without changing detection math.
- Crew spotter and big player plays must present as crew presence at the table
  using the `game06_1` actor vocabulary, with their landed availability, cost,
  window, detection and heat contracts untouched.
- Nonterminal cheat setup actions must keep carrying bounded pending dishonesty
  and detection into the later settled hand, exactly as the heist scoring path
  requires today.

## 6. Tests and acceptance

- Preserve and extend the full rules and RTP matrix. Money conservation across
  splits, doubles, insurance and surrender must be asserted exactly.
- Phase-machine assertions: no input can double-deal, double-settle, act out of
  turn, strand a wager, or charge on a rejected verb.
- Every consumer from section 1 re-proved by its own test after the change.
- Neighbour determinism across 10 seeds; neighbours provably cannot affect
  player outcome or bankroll.
- Assert every energy and heat tier changes at least one actor, object or
  interactable state, and settles correctly when it falls.
- Save, exit and revisit mid-shoe, mid-hand, mid-split, during dealer procedure
  and at settlement, with no lost or double-settled wager and no replayed
  reward, dialogue, audio or one-shot effect.
- Visual QA: empty table, full table, split and double states, insurance offer,
  every cheat flow, maximum heat presence, reduced motion, small screen, and
  colorblind settings.
- Playtest checklist: a new player can place a bet, understand the dealer's
  procedure, act on a hand, read the payout and leave safely without outside
  rules knowledge.

Run project validation, all relevant foundation suites, 10-seed determinism,
native/Web parity, RTP, performance, accessibility and visual QA. Archive only
with exact evidence and no waived consumer re-proof.
