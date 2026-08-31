Status: IN_PROGRESS — implementation landed with Crossword stock held; owner art/mechanics decision and Family 1 closeout remain open
Board row: `game06_5` in `docs/todo/README_0_6_board.md`

## Executing amendment: Crossword Option C

The program root selected Option C with the historical-save policy
`game06_5-option-c-no-new-supply-existing-issued-valid`:

- the six aligned non-Crossword families remain the active 0.6 offering;
- Crossword art, topology, mechanics, odds, payouts and RTP remain unchanged;
- no new ordinary or practice Crossword stock may be generated, restocked or
  purchased, including through a direct ID, stale UI index or restored raw row;
- an unsold Crossword row already serialized in machine stock is preserved as
  held data, hidden from the purchase surface and never converted or refunded;
- every already-issued/owned Crossword ticket remains visible and retains exact
  scratch, file, save/revisit and winner-redemption behavior.

This amendment resolves Phase 5. It does not authorize art, probability,
prize, stock-weight, topology or refund work.

# Agent Prompt — 0.6 game06_5: Counter Games Depth (Scratch Tickets, Pull Tabs)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This is a depth pass over the
shipped scratch ticket and pull tab implementations, not a prize-structure
rewrite. Read `scripts/games/scratch_tickets.gd`, `scripts/games/pull_tabs.gd`,
the ticket renderers (`scratch_ticket_background_renderer.gd`,
`scratch_ticket_foil_renderer.gd`, `scratch_ticket_icon_renderer.gd`,
`scratch_ticket_machine_renderer.gd`, `scratch_ticket_mask.gd`,
`scratch_ticket_region_model.gd`), `data/games/scratch_tickets.json`,
`data/games/scratch_ticket_regions.json`, and the `game06_1` ritual contract
document under `docs/plans/`.

## Why this rework exists

These two are already the closest thing in the project to tactile play —
`scratch_tickets.gd` is one of only two modules that implements
`surface_pointer_command`, and the mask, foil and region renderers do real work.
What is missing is everything around the ticket. You buy from nobody, you scratch
in a void, and you redeem into a number. The clerk, the rack, the counter and the
person watching you scratch a losing ticket are the whole texture of this
corner of the game, and none of them exist.

## Board and dependencies

Follow the active board protocol. Claim `game06_5`. `game06_1` must be landed
and reviewed; build only on its accepted head. You own
`scripts/games/scratch_tickets.gd`, `scripts/games/pull_tabs.gd`, the ticket
renderers and their tests exclusively. You may not edit the shared runtime or
visual layer; file a runtime request instead.

`scratch_ticket_art_alignment_rca_and_fix_prompt.md` is an open defect prompt on
this surface. Read it. If its finding is still live, fix it as part of this row
and say so explicitly in the handoff.

## 1. The counter is a place

- The clerk is an actor with authored states: idle, serving, watching, bored,
  suspicious, refusing, and paying out. Their attention is how heat becomes
  visible at this surface.
- Selection happens from a real rack, roll or dispenser scene object with stock
  that visibly depletes as tickets are taken, consistent with the shipped
  per-machine stock and scarcity rules.
- Buying is a transaction with a person: money crosses the counter, the ticket
  is handed over, change is given. The purchase and the play are separate beats,
  and a bought ticket is an object you are holding.
- Redemption is a transaction too: the winning ticket goes back across the
  counter, is checked, and is paid. Above a threshold, checking takes longer and
  the clerk looks at you while it happens.

## 2. Play stays tactile and gets a body

- Preserve the shipped scratch mask, foil, region and icon behavior exactly.
  Extend it, do not replace it: scratching remains a bounded pointer verb with
  keyboard, controller and reduced-motion equivalents producing identical
  outcomes and fair timing.
- Pull tabs gain the same treatment: the tab is peeled as a physical verb with
  each window revealed in order, not resolved as a list.
- Where you scratch matters to presentation only. The authoritative result stays
  seeded and rules-owned; no verb may reroll, reorder or alter it, and none may
  read wall-clock time for a result.
- A partially scratched ticket is a persistent object. Save, exit and revisit
  must restore exactly what has been revealed, with no replayed reward, audio or
  one-shot effect, and no re-revealing of a window.
- Losing tickets need somewhere to go — a bin, a pocket, a counter — and the
  accumulated evidence of a bad session should be visible in the scene.

## 3. Cheats and secrecy

- Preserve the x-ray glasses peek, the peel and every landed cheat contract with
  their detection math and heat effects untouched. Integrate them into the
  counter ritual: peeking is something you do at a counter with a clerk who might
  look up, not a detached panel.
- The clerk's suspicion state must be an honest projection of the existing heat
  and detection values, never a second hidden system, and must never reveal
  unrevealed ticket contents.

## 4. Tests and acceptance

- Preserve and extend the full prize-structure, RTP and stock matrices for both
  games. Money conservation asserted exactly across buy, partial play,
  abandonment and redemption.
- Assert no verb path can double-reveal a window, double-redeem a ticket, redeem
  an unfinished ticket incorrectly, or charge for a rejected purchase.
- Partial-scratch persistence across save, exit, revisit, travel away and return,
  and across a run boundary where the shipped rules allow the ticket to survive.
- Clerk attention provably derives from existing heat and detection values, with
  a test that it cannot leak unrevealed contents.
- Assert every energy or attention tier changes at least one actor, object or
  interactable state; music and text alone are a validation failure.
- Visual QA: full rack, depleted rack, empty stock, mid-scratch, fully scratched
  winner and loser, pull tab windows in sequence, redemption, refusal, every
  cheat flow, reduced motion, small screen, colorblind.
- Playtest checklist: a new player can buy a ticket from the clerk, scratch it,
  understand whether they won, and redeem it without outside knowledge.

Run project validation, all relevant foundation suites, 10-seed determinism,
native/Web parity, RTP, performance, accessibility and visual QA. Archive only
with exact evidence for both games, and state the disposition of the open art
alignment defect.
