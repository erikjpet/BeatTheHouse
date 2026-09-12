Status: TODO — owner-directed new mechanic; claimable now
Priority: P2 — additive content, not a defect; must not destabilize the playtest build
Board row: `feat06_1` in `docs/todo/README_0_6_board.md` (Defects table, marked as an owner-directed addition)
Opened: 2026-09-11 from owner direction
Owner's words, verbatim:

> "if a scalper appears after leaving a scratch ticket machine you are able to
> talk to them and there will be an option to give them a tick if you still have
> one un scratched. this will lover hear by 8% and there is a 33% chance that
> they guive you a low tier tiem"
> "in doing this also make it so scalpers sometimes arrive at the time of a
> machine reset"

## Execution Record

_Fill in on completion: date, commit hashes, gate results, deviations._

# Agent Prompt — feat06_1: Give the Scratch Scalper a Ticket

Copy everything below this line into one agent. It may spawn sub-agents freely.

---

You are working in `D:\Projects\Beat-The-House` on `main` at `c570f2ce` or later.
This prompt is complete on its own.

## 0. What already exists — read this before designing anything

**The scalper is already in the game.** Do not build a new character, a new hook
or a new dialogue system. You are adding one conversation option and one arrival
trigger to something that ships today. Everything below is verified in source:

- `scripts/games/scratch_tickets.gd` defines `SCALPER_HOOK_ID :=
  "scratch_ticket_scalper"`, `SCALPER_VISIT_CHANCE_PERCENT := 30` and
  `SCALPER_KNOWS_CHANCE_PERCENT := 50`.
- `_refresh_scalper_for_visit()` (~line 2158) decides per visit whether he is
  there. He is **guaranteed** when the machine has no stock, and otherwise rolls
  the 30% chance. He is suppressed in practice environments and in tutorial runs.
  When present he clears the machine's active stock via `_clear_machine_stock()`.
- He appears as a talk target in the environment object list (~line 573) with
  `object_id "dialogue:scratch_ticket_scalper"`, `visual_key "scalper"`,
  a single `start_dialogue` / "Talk" action.
- Two dialogues exist in `data/dialogue/dialogues.json`:
  `scratch_ticket_scalper_knows` and `scratch_ticket_scalper_oblivious`,
  both speaking as Vince (`vince_ticket_scalper`), each with one node and one
  "leave" choice. Whether he knows the restock schedule is **hidden state**
  chosen by a 50/50 roll, and the oblivious branch must never leak it.
- `_advance_restock_schedule()` (~line 2097) walks 180-minute restock boundaries.
  If a scalper is already present at a boundary, he **intercepts** that restock:
  `scalper_intercepted_restock_count` grows and no stock is added.
- Purchased-but-unscratched tickets live in the machine state, not a global
  inventory: `machine["active_ticket"]` is the one on the surface and
  `machine["pending_queue"]` holds the rest (see `_purchase` around line 690).
- **`_ticket_type_is_held()` is unrelated to the player.** "Held" means a ticket
  family withheld from machine release. Do not confuse it with tickets the
  player is carrying.
- `scripts/tests/foundation/check_scratch_tickets.gd` already gates the scalper:
  the 30% encounter rate, the exact 50/50 dialogue split, the guaranteed
  empty-machine encounter, the informed/oblivious dialogue ids, tutorial
  suppression, and stale-visit handling. **Extend these tests. Never relax one.**

## 1. The mechanic

### 1.1 The gift option

When the scalper is present and the player is carrying at least one unscratched
ticket, his conversation gains one additional choice: give him a ticket.

- **What counts as unscratched:** an entry in `machine["pending_queue"]`, or
  `machine["active_ticket"]` when it has no revealed cells and is not
  `result_ready`. A ticket that has been scratched at all, partially or fully,
  is never eligible. Prefer a queued ticket over the active one so the player
  does not lose the ticket currently on the table.
- **When the option is hidden:** no eligible ticket, practice environment,
  tutorial run, or the gift already used this encounter (see 1.3).
- **The option must state its price in fiction before it is taken.** The player
  is giving away a ticket that might have been a winner.

### 1.2 What the gift does

1. **Heat falls by 8.** Heat in this project is an integer 0–100 meter
   (`RunState.suspicion_level()`, clamped 0–100, `TUTORIAL_HEAT_CEILING` in
   tutorial runs). **This prompt reads the owner's "8%" as 8 points off that
   meter**, applied through `RunState.add_suspicion()` with a negative amount and
   its own cue id, so it lands in heat history and the heat-changed signal like
   every other heat movement. Heat is tracked per location; the reduction applies
   to the current location. If the owner meant 8% of current heat instead, that
   is a one-line change — record the reading you shipped in the board note so it
   can be corrected without an archaeology session.
2. **A 33% chance of a low-tier item**, rolled from run RNG at the action
   boundary, never from wall-clock and never from a fresh unseeded generator.
3. **The ticket is consumed.** It is removed from the queue or the surface. It
   is not refunded, not converted, and does not return on revisit.
4. **Every outcome is visible.** The player sees the heat drop and sees the item
   arrive or sees him pocket the ticket and give nothing back. A silent state
   flip is a defect in this project; `fix06_28` exists because of it.

### 1.3 One gift per encounter — do not skip this

Without a limit, this is a heat-laundering exploit: buy cheap tickets, hand them
over one at a time, walk away at zero heat. **Allow at most one gift per scalper
encounter**, keyed to the existing `machine["scalper_visit_token"]`, and persist
that so it survives save, reload, revisit and travel. After the gift, the option
is gone for that encounter and the conversation says why.

If you believe a different bound is better — per day, per machine, a diminishing
return — implement the per-encounter bound anyway and raise the alternative as a
finding with numbers. Do not quietly ship a looser rule.

### 1.4 "Low tier item" — define it, because the data does not

`data/items/items.json` has 88 items and **no tier or rarity field** on all but
two of them. There is no existing low-tier pool to draw from. Item tiers exist
only in the cross-run meta-collection system.

- **The reward must be a within-run item**, drawn from the ordinary item pool.
  **It must not be a meta-collection drop.** Owner ruling `content06_1`:
  within-run inventory, shelf and sale presentation only; no new cross-run
  progress in 0.6. Granting a collection item here would break that.
- Define "low tier" by an explicit, checked-in rule over existing item data —
  the cheap end of `sale_price` / `price_min` / `price_max` is the obvious
  candidate — and write the rule and the resulting item list into the report.
  The pool must be stable, deterministic and in fiction for a street reseller:
  what he hands over should read like something from his pocket.
- The draw is seeded from run RNG so the same seed yields the same item.

### 1.5 Scalpers arriving at a restock

Today a scalper can only appear when the player arrives at the machine. The
owner wants him to sometimes turn up **at the restock boundary itself**.

- Extend `_advance_restock_schedule()` so that at a boundary where no scalper is
  present, there is a chance one arrives. Seed it from the existing per-boundary
  stream `scratch-restock:<machine>:<minute>` or a clearly named sibling, so the
  same run replays identically. Publish the chance as a named constant beside
  `SCALPER_VISIT_CHANCE_PERCENT` rather than an inline literal.
- **Decide and record one thing:** does a scalper who arrives *at* a boundary
  intercept that same restock, or only later ones? The default this prompt asks
  for is that the restock he arrives for lands in the machine and he intercepts
  from the next boundary onward — a player who never saw that stock should not
  be silently robbed of it. Implement that, and if you disagree, say so with
  reasoning rather than changing it.
- Tutorial and practice suppression still apply. A tutorial run must never get a
  restock-arrival scalper.
- The existing interception behavior for an already-present scalper does not
  change.

### 1.6 People walk in and walk out — they never pop

Owner direction: "make it so when someone comes in they move from the exit to
their location or, if they are leaving move from their location to the exit,
they dont just pop in."

This is a general presentation rule for environment people, not a scalper-only
effect. The scalper is simply its first and most visible consumer: he arrives at
a restock boundary, and he leaves when the encounter ends.

**The machinery already exists — reuse it, do not build a second one.**
`ScenarioLayoutResolver._resolve_visual()` already produces `route_points` and a
`route_stage` carrying `mode` (`to_endpoint` / `ping_pong`), `duration_sec`
(distance / 82.0, clamped 0.75–8.0 s), `reduced_motion_endpoint` and
small-screen start/endpoint pairs. `PixelSceneCanvas._actor_route_position()`
(~line 3962) already interpolates start→endpoint over `actor_route_time`,
returns the endpoint outright under reduced motion, and
`_sync_actor_route_starts()` already tracks per-route start times. An arrival is
that same transit with a doorway as the start; a departure is it reversed.

**Where the door is.** `fix06_31` authors `data/environments/placement_surfaces.json`,
which gives every room a `doorways` list with bounds (`left_exit`/`right_exit`
in the shops, `forecourt_left`/`forecourt_right` at the gas station, and so on)
plus `floor.bands` and `contact_y`. Use the nearest doorway to the person's
settled position, and walk along the floor band. Do not invent a second source of
truth for where a room's door is, and do not hard-code coordinates per room.

Rules:

- **Only mid-visit changes animate.** When the player walks into a room, the
  people who are already there are already in place. Nobody parades in on room
  entry. A transit plays only when someone arrives or leaves while the player is
  in the room.
- **Arrival:** the person appears at the doorway and walks to their settled
  position. **Departure:** they walk from their settled position to the doorway
  and are gone on arrival there.
- **The walk is presentation only.** The object's settled geometry — the rect the
  layout authority sealed, and everything the placement, label, hit-authority,
  walk-lane and finalization validators inspect — stays the settled position
  throughout. A transit must not change what `fix06_27`'s 8 seed families × 55
  scenarios finalization gate sees. If it does, you have built it wrong.
- **Transits are not click targets.** `_board_rect_for_object()` currently moves
  an object's hit rect with its route position, so a walking person would be a
  moving target, made worse by small-screen hit expansion. An arriving person is
  not interactive until they are settled; a departing person stops being
  interactive the moment they start leaving. The player never chases someone
  across the room, and never clicks a person who is already gone.
- **Game state does not wait for the animation.** The scalper is logically
  present the instant the state says so, even if he is still mid-walk. The
  transit never gates, delays or reorders an action boundary, and never holds up
  travel, save or a scenario phase.
- **Save and reload settle instantly.** A transit is never persisted mid-walk.
  On load, revisit or travel-in, everyone is at their settled position.
- **Reduced motion keeps semantic parity.** The existing route code returns the
  endpoint immediately under reduced motion; arrivals and departures do the same —
  the person is simply there, or simply gone. No information is carried only by
  the movement.
- **Paths stay on the floor.** Walk inside the room's `floor.bands`, never
  through a counter, a wall band or a `void` region. A simple two-segment path —
  doorway to the floor lane, then along it to the settled x — is enough; this is
  pixel-art staging, not navigation mesh work.
- **Cost is bounded.** This adds per-frame motion to rooms while `perf06_1` is
  measuring them. No per-frame allocation, no per-frame deep copies, and a cap on
  concurrent transits with a deterministic rule for what happens past the cap
  (settle immediately rather than queue). Report the measured idle and active
  frame cost of a room with a transit playing against the same room without one.
- **This helps the liveness gate, but never fakes it.** A transit is real motion,
  but the idle-liveness counter must still be non-zero in a room with nobody
  walking.

**Sequencing:** this section touches `scripts/ui/pixel_scene_canvas.gd` and reads
`placement_surfaces.json`, both of which `fix06_31` owns and is actively
rewriting. **Do not start section 1.6 until `fix06_31` has merged to
`origin/main`**, then build on its landed surface maps. Sections 1.1–1.5 have no
such dependency and can proceed first. If `fix06_31` is still unlanded when the
rest of this row is done, ship sections 1.1–1.5, say so, and leave 1.6 for a
follow-up rather than duplicating that row's files.

## 2. Where the work goes

- **Game logic:** `scripts/games/scratch_tickets.gd` — eligibility, the gift
  command, ticket consumption, the per-encounter bound, restock arrival.
- **Dialogue:** `data/dialogue/dialogues.json` — a new choice on **both**
  `scratch_ticket_scalper_knows` and `scratch_ticket_scalper_oblivious`. The
  option and its outcome text must read identically in both branches. If the
  gift's wording differs between the informed and oblivious scalper, it leaks
  hidden state and is an automatic P0.
- **Host seam:** `scripts/ui/foundation_main.gd`. `_dialogue_choice_requirement()`
  (~line 5011) supports `requires` on bankroll, heat and story flags — it has no
  concept of "carrying an unscratched ticket", and the dialogue data cannot see
  machine state. `_resolve_dialogue_choice()` (~line 5048) already special-cases
  dialogues that need game state, for `linda_cage_services` and
  `sal_starter_offer`. Follow that established pattern rather than inventing a
  second one, and keep the game rule inside the game module: the host asks the
  scratch module whether the gift is available and tells it when the player
  takes it.
- **Items:** the low-tier pool rule and the grant path through the existing
  within-run item API. Do not add a parallel grant mechanism.
- **Transit animation (section 1.6, after `fix06_31` lands):**
  `scripts/ui/pixel_scene_canvas.gd` for the presentation stage, reading
  doorways and floor bands from `data/environments/placement_surfaces.json`, and
  whichever seam publishes a person's arrival or departure to the canvas. Reuse
  the existing `route_points` / `route_stage` vocabulary rather than adding a
  parallel animation path.

## 3. Constraints

- **Determinism.** Same seed, same encounter, same reward. Both new rolls come
  from run RNG at an action boundary. Prove it with the determinism probe.
- **Exactly once.** The heat drop, the item grant and the ticket consumption fire
  once across save, reload, travel, revisit, abort and expiry. This project has
  repeatedly shipped consequences that re-fired on revisit.
- **Hidden state is absolute.** Nothing about the gift — availability, text,
  odds, reward, timing — may differ by whether the scalper knows the restock
  schedule. Prove it with paired observers: two runs identical but for
  `scalper_knows_schedule` must produce identical gift surfaces.
- **No economy drift beyond the mechanic.** Do not change ticket prices, ticket
  odds, scratch RTP, restock rates, the 30% encounter chance or the 50/50
  dialogue split. The only new numbers are the gift's −8 heat, its 33% reward
  chance, the restock-arrival chance, and the low-tier pool rule.
- **Never weaken an existing test.** `check_scratch_tickets.gd`'s scalper
  assertions stay exactly as strict; you are adding cases, not editing old ones.
- **Save compatibility.** New machine-state fields must default safely on a save
  written before this change. A 0.6 save mid-run must load and behave. No save
  schema bump and no migration without the owner — if one looks unavoidable,
  stop and ask.
- **File ownership.** `fix06_31` owns `scripts/core/environment_*`,
  `scenario_layout_resolver.gd`, `pixel_scene_canvas.gd`,
  `environment_interaction_controller.gd` and `data/environments/*`. Sections
  1.1–1.5 must not touch any of them; if the scalper needs a placement change,
  route it to that row. Section 1.6 necessarily touches
  `pixel_scene_canvas.gd` and reads `placement_surfaces.json`, and is therefore
  gated on `fix06_31` having merged — see the sequencing note at the end of 1.6.
  Take that work on top of its landed result, never in parallel with it.
- If you add a suite stage, coordinate with `fix06_32`, which is also wiring
  gates into `tools/check_godot.ps1` and `tools/validate_project.ps1`. Nothing
  heavy goes into Smoke/contracts: that stage measured 227.786 s against a
  230.391 s budget.

## 4. Acceptance

1. A player at a machine with an unscratched ticket can talk to the scalper, see
   a clearly priced option to hand one over, take it, and watch heat fall by 8.
2. Roughly one gift in three returns an item; prove the rate over a large seeded
   sample against the declared 33%, the way `check_scratch_tickets.gd` already
   proves the 30% and 50% rates.
3. The option is absent with no unscratched ticket, absent in tutorial and
   practice runs, and absent after one gift in the same encounter.
4. The given ticket is gone and does not come back after save, reload or
   revisit; the heat drop and any item grant apply exactly once.
5. Scalpers sometimes arrive at a restock boundary, at a published deterministic
   rate, with the interception question resolved and recorded.
6. Paired-observer proof that nothing about the gift reveals whether the scalper
   knows the schedule.
7. Determinism probe green; identical seeds reproduce identical encounters,
   gifts and rewards.
8. All existing scratch-ticket gates still pass unchanged, plus new cases for
   everything above.
9. `tools/validate_project.ps1` green on the exact head, and the scratch-ticket
   focused suite green.
10. No change to ticket prices, scratch odds, RTP, payouts, restock rates or the
    existing scalper probabilities.
11. Section 1.6: a person who arrives while the player is in the room walks in
    from a doorway to their place, and a person who leaves walks out to a
    doorway. Nobody pops in or out mid-visit, and nobody parades in on room
    entry. Shown with captures or a recording, not asserted in prose.
12. Section 1.6: settled geometry is unchanged during transit — `fix06_27`'s 8
    seed families × 55 scenarios finalization gate stays green, transits are not
    click targets, reduced motion keeps semantic parity, save/reload settles
    instantly, and the measured frame cost of a room with a transit is reported
    against the same room without one.

## 5. Hard limits

- Never weaken a test, budget, liveness floor or deterministic assertion to go
  green.
- An idle draw cost of 0.000 is a failure, not a pass. Four recorded regressions.
- No per-frame deep copies; 32.6 ms/frame once, in the slot bonus watchdog. The
  gift's eligibility check runs at action boundaries, never per frame.
- Action boundaries, never wall-clock.
- Delete nothing; archive rather than remove.
- Never stage owner property: `.tmp/`, `.tools/`, `review_artifacts/`, `builds/`.
- No release activity: no version bump, tag, packaging, upload or publish.
- Leave no diagnostics in the tree. Commit at least every 30 minutes on a branch.

## 6. Standards every row inherits

- Native/Web parity is a requirement.
- Tab-indented, typed GDScript matching the surrounding style; sparse comments
  that state constraints rather than narrate.
- Cheap validation: `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1`.
  Targeted: `tools/check_godot.ps1 -Suite <Smoke|Contract|Audit|Full> [-FoundationSuite scratch_tickets]`.
  Godot: `.tools/godot-4.6-stable/Godot_v4.6-stable_win64_console.exe`.

## 7. Closeout

Claim `feat06_1` on the board before you start, log decisions in the dated
discovery log, and on completion fill the Execution Record, set the row `DONE`
with a one-line summary, `git mv` this file to `docs/todone/`, append a work-log
line, and merge to `main` green with `origin/main` in sync.

## 8. Reporting

Lead with what the player can now do and the two numbers you shipped: the heat
reduction reading (8 points, per section 1.2) and the measured reward rate. Then
the low-tier pool rule and the items it yields, the restock-arrival rate and the
interception decision, the exploit bound, and the hidden-state proof. Name
anything you would tune differently and why, without tuning it yourself.
