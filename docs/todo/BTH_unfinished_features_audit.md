# Beat the House — unfinished and unimplemented player-facing work

Audit date: 2026-11-11
Audited source: `main` at `06e5492116b2f4aac78ffbc3d41ed15be64833a9`
Companion to: `docs/todo/BTH_0.6.1_audit_work_orders.md` (the stability audit)

This is the second audit. The first one covered safety and release hygiene and
changes almost nothing a player sees. This one answers a different question:
**what was planned, promised or half-built that a player would notice is
missing?** It is written as a queue for a worker agent to pick up after the
first audit's work is finished. It changes nothing in the repository.

---

## 0. How to use this document

### Owner decisions (2026-11-12) — these override the text below

| Item | Decision |
| --- | --- |
| FEAT-01 item effects (all parts, including Lucky Penny and Ledger Pencil) | **Not now.** Wait for a full reassessment of all item effects. Moved to the 0.6.2 queue. |
| FEAT-02 The Whale Game, and FEAT-07 Count route length | **Investigate and report.** Deliver the current state and the remaining work. Ship nothing. |
| FEAT-03 Daily Challenge seed | **Fix.** Every calendar day gets its own seed, including across years. The day changes at **local** midnight. |
| FEAT-03 sharing results | **Not now.** An in-game leaderboard is wanted eventually; no online work. |
| FEAT-04 collection sort and filter | **Not wanted.** Players are meant to hold only a few items. Closed. |
| FEAT-08 voice pass | **Done by hand by the owner.** Moved to the 0.6.2 queue; not a worker task. |
| FEAT-09 the two concrete scenario defects | **Fix.** |
| FEAT-09 `BTH-11` scenario polish | **Stay open, no work.** 0.6.2. |
| FEAT-11 item packs | **Fix.** A player must not need to enable anything to receive these items. |
| QOL-06 to QOL-10 | **None for now.** |


### What was searched

- `docs/todo/` and `docs/todo/deferred_0_6_1/` — every prompt, board and queue.
- `docs/plans/0.6.1_backlog.md` — the project's own list of everything
  deliberately deferred from 0.6.0. This is the spine of this audit.
- `docs/current_game_state.md`, `README.md`, `docs/plans/act_two_seam.md`,
  `docs/plans/0.6_post_playtest_program.md`, the rw06 release-week queue and
  the 0.6 board.
- `docs/item-audit/` — the 153-item behavior audit of 2026-10-27.
- The 0.6.1 ledger's paused item and scenario entries.
- The code and data, to check each planned item against what is actually
  there: `scripts/core`, `scripts/games`, `scripts/ui`, `data/`.

### What "verified" means here

Each item below carries one of these labels. Read them literally.

| Label | Meaning |
| --- | --- |
| **Verified in code** | I read the code or data at the audited commit and it shows the gap. |
| **From the plan, not verified** | The project's own documents say it is unfinished. I did not confirm it in code or in play. |
| **Stale — appears done** | A plan still lists it as open, but the code or a later document shows it was finished. Close the entry. |
| **Needs play to confirm** | Only visible by running the game. |

**Nothing was run.** Godot could not be executed in the audit environment.
Every "verified" is from reading, not from play. The worker reproduces before
acting, exactly as in the first audit.

### Three things block most of this queue

Most of the genuinely player-noticeable work is not blocked by engineering. It
is blocked by decisions only the owner can make. They are collected in
section 1 so they can be answered once.

1. **Item and scenario work is under a user-requested pause** (2026-11-04).
   Four of the most visible items here (FEAT-01, FEAT-05, FEAT-09, and part of
   FEAT-02) are item or scenario work.
2. **Several items need art** that does not exist (FEAT-06).
3. **Several items are platform or human-only** (section 6): Steam, mobile
   signing, online leaderboards, the five-person tutorial test, Act 2 design.

### Rules the worker must follow

Same as the first audit: `AGENTS.md` wins over this document; register each ID
in both ledger views before starting; reproduce before fixing; never change
payout tables, odds, RTP or EV (the project's standing rule is that depth and
presentation work preserve rules and math); never suppress idle animation;
deliver through the existing NEXT pipeline.

### Index

| ID | What the player notices | Status | Type | Ready for a worker? |
| --- | --- | --- | --- | --- |
| FEAT-01 | Eleven items promise an effect that does nothing | Verified in code (3 of 5 causes) | Code + text | **Parked** — 0.6.2, after the item reassessment |
| FEAT-02 | Only one of the two Crew heists can be played; the Crew arc is shortened | Verified in code | Content enablement | **In this queue** — investigation and report only |
| FEAT-03 | Daily Challenge repeats every year and its result goes nowhere | Verified in code | Code | **In this queue** — seed fix only |
| FEAT-04 | The home collection cannot be sorted or filtered | Verified in code | Code | **Closed** — not wanted |
| FEAT-05 | Scenario characters teleport between positions instead of walking | From the plan, not verified | Scenario presentation | No — paused, and needs a design pass |
| FEAT-06 | Some rooms share art; two scenario props have no visual | From the plan, not verified | Art | No — needs art |
| FEAT-07 | The Count heist takes longer than intended | From the plan, not verified | Pacing | **In this queue** — measured with FEAT-02 |
| FEAT-08 | Text added in 0.6 never had its voice and copy pass | From the plan | Text only | **Owner, by hand** — 0.6.2 |
| FEAT-09 | Three known scenario defects are parked | From the ledger | Scenario | **In this queue** — the two concrete defects |
| FEAT-10 | Three older bugs were held and never rechecked | From the plan | Needs play | Recheck task |
| FEAT-11 | Two item packs must be switched on by the player | Verified in data | Data + check | **In this queue** |
| QOL-06…10 | Controls page, rebet, faster tables, save slots, localisation | Verified in code (first audit) | Code | **Not wanted now** |
| — | Section 6: owner, platform and human-only items | — | — | Not worker tasks |
| — | Section 7: deferred qualification campaigns | — | Test runs | Procedure exists |
| — | Section 8: stale plan entries to close | Stale — appears done | Docs | **Yes** |

---

## 1. Decisions for the owner

All answered on 2026-11-12; see the table at the top of section 0. Two
follow-up questions arise from those answers and are noted where they apply:
which items the pack change exposes (FEAT-11), and what the heist report
recommends (FEAT-02).

---

## 2. Built, but not delivering what the player is told

These are the highest-value items: the work is mostly done and the player is
already being shown something that does not happen.

## FEAT-01 — Eleven items promise an effect that does nothing

> **Owner decision 2026-11-12:** **parked.** No item effect is to be changed until all item effects have been reassessed. This whole section, including Lucky Penny and Ledger Pencil, moves to the 0.6.2 queue (section 9). It stays here as the starting evidence for that reassessment. Do not implement any part of it.

**Status:** Verified in code for parts A, C and D; from the item audit for B
and E. **Blocked by:** D1 (item pause), D2, D3.
**Source:** `docs/item-audit/beat_the_house_item_audit_categorized.csv`
(snapshot `9adf460d`, 2026-10-27), rows whose assessment begins "Confirmed
effect/path discrepancy or unused setting"; ledger `BTH-15`, `BTH-17`.

### What the player notices

They buy, earn or equip an item for a stated benefit and that benefit never
applies. There is no error; the number just does not move.

### Part A — Slot odds that Slots ignore (2 items)

| Item | Data | What happens |
| --- | --- | --- |
| Foil Sleeve (`foil_sleeve`) | effect includes `families.slots.win_chance` | Roulette part works; Slot part has no reader |
| Mags' Lined Sleeve (`mags_lined_sleeve`) | `"slots": {"win_chance": 7}` (`data/items/items.json:2018`) | Same |

**Evidence.** Slots explicitly discard win-chance and luck modifiers; the
resolver stamps `slot_luck_win_chance_ignored: true` on its results
(`scripts/games/slots/slot_resolver.gd:307`, `:485`, `:1874`). Other games add
item `win_chance` in `scripts/core/game_module.gd:1419-1420`.

**Change (recommended, pending D2).** Remove the `slots` family from both
items' effect data, and remove any Slot wording from what the item card shows.
Do not make Slots read the bonus: slot outcomes come from fixed reel strips
and a bonus would change RTP, which the project forbids without an explicit
math decision.

**Check first.** Open both item cards in game and record exactly what text
the player sees about Slots. If the card never mentions Slots, this part is
data hygiene only and can be done silently.

### Part B — Souvenirs granted by a scene do not apply their luck (2 items)

| Item | Advertised | What happens |
| --- | --- | --- |
| Wedding Ribbon Favor (`wedding_ribbon_favor`) | +1 baseline luck | Scene adds it to inventory; luck unchanged |
| Rent-Party Hat Pin (`rent_party_hat_pin`) | +1 baseline luck | Same |

**Evidence (from the item audit; not re-traced).** Baseline luck is a one-time
change applied when an item's effect is processed on acquisition
(`scripts/core/item_effect.gd:142` builds `baseline_luck_delta`;
`scripts/core/run_state.gd:6844-6845` applies it). A merchant purchase goes
through that path. A scenario or event reward adds the item to inventory
without it.

**Change.** Find the reward path that grants these two items (search the
scenario sequences and `scripts/core/run_action_service.gd` for their ids)
and make it apply the item's acquisition effect exactly once, the same way a
purchase does. "Exactly once" must hold across save, reload, travel and
revisit — the project has been burned by double-firing rewards. Then check
whether **every** scenario-granted souvenir has the same gap; the audit lists
13 scenario-reward items and only traced these two.

### Part C — Collection items equipped from home do not apply baseline luck (4 items)

| Item | Unconnected field |
| --- | --- |
| Creased Luck Card (`creased_luck_card_meta`) | baseline luck |
| Lucky Keychain (`lucky_keychain_meta`) | rolled baseline luck |
| Rabbit's Foot (`rabbits_foot_meta`) | baseline luck |
| Golden Motel Token (`golden_motel_token_meta`) | baseline luck |

**Evidence.** The loadout is copied straight into the run's inventory with no
acquisition step:

```gdscript
# foundation_main.gd:19237-19250 (current code), _apply_meta_collection_loadout_to_run
if not run_state.inventory.has(item):
    run_state.inventory.append(item.duplicate(true))
run_state.invalidate_inventory_effect_cache()
```

Their other effects (odds help, payout bonus) are read from inventory each
time and do work. Only the one-time baseline-luck part is skipped.
`scripts/core/collection_item_resolver.gd:29` shows `baseline_luck_delta` is a
recognised collection field.

**Change.** When the loadout is applied at run start, also apply each item's
resolved `baseline_luck_delta` once, through `RunState.change_baseline_luck`
(`run_state.gd:7276`). Guard against applying it again on Continue: the
loadout function also runs paths after load, so key the application to run
creation, not to inventory presence. Add a check that starts a run with one
of these equipped and asserts the luck value, then saves, loads and asserts
it is unchanged.

**Balance note.** These items have never applied this bonus, so turning it on
makes them stronger than players have experienced. It is still a bug fix
(the item says it does this), but tell the owner the potency ranges
(1–3, 1–3, 3–7, 5–10) before shipping.

### Part D — Collection Cooler's Cufflinks do not shield a failed peek (1 item)

**Evidence.** Blackjack checks one hard-coded id:

```gdscript
# blackjack.gd:59 (current code)
const COOLERS_CUFFLINKS_ITEM_ID := "coolers_cufflinks"
```

The collection version is `coolers_cufflinks_meta`
(`data/collections/collections.json:1910`), so
`_coolers_cufflinks_absorbed_failed_peek` (`blackjack.gd:2699`) never matches
it. Its advertised failed-peek Heat absorb has no reader.

**Change.** Decide with the owner whether the collection copy should shield
(then match both ids, and decide whether it "breaks" like the ordinary one
does) or should not (then remove the claim from its text). Do not guess; the
ordinary item is consumed into `broken_cufflinks` and a persistent collection
item being destroyed is a design question.

### Part E — Two items flagged for full rework, one unused setting

- **Lucky Penny (`lucky_penny`, ledger `BTH-15`)** and **Ledger Pencil
  (ledger `BTH-17`, `LEDGER022`)**: the owner flagged both for a full effect
  and description rework; the replacement is undecided (D3). Lucky Penny
  currently only makes scratch coating clear slightly sooner. Not worker-ready
  until the owner says what each should do.
- **Bumper Battery (`bumper_battery`)**: its extra-upward-impulse setting has
  no reader after collection. The item otherwise works. Either connect the
  setting in the Pinball feature or delete it from data. Low priority.

### Acceptance for FEAT-01

For each item: a check that fails before and passes after, showing the
advertised effect applies exactly once and survives save and Continue, or that
the claim is gone from every player-visible text. No payout, odds or RTP table
changes.

---

## FEAT-02 — Only one of the two Crew heists can be played

> **Owner decision 2026-11-12:** **investigate and report.** Do step 1, and FEAT-07's measurement, and deliver one report on the current state and the remaining work. Steps 3 and 4 are not authorized. Nothing that exposes The Whale Game is pushed.

**Status:** Verified in code. **Blocked by:** D4.
**Source:** `docs/plans/0.6.1_backlog.md`, "Endings and experience";
rw06 final queue task T1.

### What the player notices

The Crew campaign builds toward a heist. There is one: The Count, with Bishop.
A second, The Whale Game, with Velvet and Mags, is fully written but cannot be
reached. The trust climb that was meant to lead to the heists was also cut
short.

### Evidence

- Both plans exist in the model and in data:
  `scripts/core/crew_heist_model.gd:16-18` (`PLAN_COUNT`, `PLAN_WHALE`), plan
  phases at `:200-233`, plan row `the_whale_game` in `data/crew/heist.json`,
  and authored setup sequences in
  `data/crew/world06_6_heist_sequences.json` (`world06_6_whale_setup`).
- Release is limited by one data field, `release_plan_ids`, read at
  `crew_heist_model.gd:48-54`.
- Content validation refuses anything else:

  ```gdscript
  # crew_heist_model.gd:382-383 (current code)
  if release_plan_ids() != [PLAN_COUNT]:
      failures.append("The 0.6.0 release must expose only The Count heist plan.")
  ```

### What was cut, per the backlog (not re-verified)

- The Whale Game plan.
- Bishop's trust arc from 30 to 90 and the Made / Inner Circle tiers:
  recruiting Bishop at Associate now opens planning directly.
- The Count's setup: three qualifying identity sessions reduced to one; two
  schedule-hold boundaries reduced to one.

### Why it was cut

Task T1 of the release-week queue was "reach the Crew heist win screen through
normal play… narrow to one plan or fewer recruits if needed; log the cuts."
The second plan was not shown to be completable by a normal player in the time
available. That is the risk in turning it back on.

### Change required

This is an investigation before it is an implementation.

1. **Establish whether The Whale Game is completable.** In a development
   build, add `the_whale_game` to `release_plan_ids`, relax the validation
   line, and attempt the plan from a fresh run through normal controls. Record
   where it stops. Do not ship this state.
2. **Report to the owner** with what works, what does not, and an estimate.
   D4 is answered with that in hand.
3. **If approved:** fix what step 1 found; change the validation to accept the
   approved set instead of deleting it; restore the trust arc and setup counts
   only if the owner asks for them (they affect run length; see FEAT-07).
4. Hidden-state rules are absolute here: nothing about the Turn, the traitor
   or grievances may leak through scene data, save keys, captures or audio.
   The crew-ignoring run must stay a true no-op.

### Acceptance

A fresh-profile player reaches The Whale Game ending through visible controls,
with a screenshot; the existing Count route, the crew-ignoring golden probe
and the hidden-state checks still pass.

---

## FEAT-03 — Daily Challenge repeats every year and its result goes nowhere

**Status:** Verified in code.

### What the player notices

The main menu offers DAILY CHALLENGE, "today's hidden-seed challenge". Two
things are off:

1. **The same date gives the same run every year, and the seed is not
   hidden in any real sense.**

   ```gdscript
   # foundation_main.gd:1369-1372 (current code)
   func _daily_challenge_seed_for_date(day: int, month: int) -> String:
       ...
       return "%d/%d" % [safe_day * 32, safe_month * 2]
   ```

   The seed is the day times 32 and the month times 2. The year is not used.
   It also reads the device's local clock (`:1356`), so changing the date
   replays or previews any day.
2. **The result is only stored locally.** Streaks and the best result are
   kept (`scripts/core/profile_inventory.gd:360-384`) and shown in Career
   Stats (`scripts/ui/career_stats_view_model.gd:46-49`). But the challenge is
   tagged `leaderboard_scope: "daily"` (`scripts/core/run_state.gd:16105`) and
   nothing ever submits a score: `submit_daily_score`, `submit_score` and
   `unlock_achievement` in `scripts/core/platform_services.gd` have no callers
   and return `"submitted": false`.

### Change required (owner decision 2026-11-12)

1. **Every calendar day gets its own seed, including across years.** Build
   the seed from the full local date, year included, and pass it through a
   hash so it cannot be read off the date: for example the first 12 hex
   characters of the SHA-256 of `"BTH-DAILY|<yyyy>-<mm>-<dd>"`.
2. **The day changes at local midnight.** Keep using the device's local date,
   as the code does now (`Time.get_datetime_dict_from_system()`,
   `foundation_main.gd:1356`). Do not switch to UTC.
3. `_daily_challenge_id_for_datetime` (`foundation_main.gd:1375-1381`) already
   includes the year (`yyyy-mm-dd`) and is what streak tracking keys on. Leave
   its format alone; change only `_daily_challenge_seed_for_date`, which must
   now receive the year.
4. A daily run already in progress keeps the seed it started with; the new
   scheme applies to runs started after the change.
5. Add a check: the same date in two different years gives different seeds;
   the same local date always gives the same seed; two consecutive days
   differ; the seed text does not contain the date.

**Not in this queue.** Sharing or comparing results. The owner wants an
in-game leaderboard eventually and no online functionality now. Do not add a
share line, a results panel or any platform call. `leaderboard_scope` and the
unused `submit_*` functions stay as they are.

**Do not** try to prevent clock changes. Without a server it cannot be done.

---

## FEAT-04 — The home collection cannot be sorted or filtered

> **Owner decision 2026-11-12:** **closed, not wanted.** The design goal is that players hold only a few items, so the collection should not need browsing tools. Do not build this.

**Status:** Verified in code.
**Source:** `docs/plans/0.6.1_backlog.md` "Meta and platform features";
`docs/current_game_state.md` ("dedicated player sort/filter controls… remain
deferred"); `README.md:558`.

### What the player notices

The collection at home groups items by collection and shows tier and float
detail, but with 28 collectible entries, bags and duplicates there is no way
to sort by tier, condition or value, or to filter to one kind.

### Evidence

The in-run inventory already has both controls: `_filter_option` and
`_sort_option` in `scripts/ui/run_inventory_screen.gd:50-68`, built at
`:313-325`. The home collection screens
(`scripts/ui/meta_session_controller.gd`,
`scripts/ui/meta_item_interaction_screen.gd`,
`scripts/ui/inventory_container_surface.gd`) contain no sort or filter
control. `scripts/ui/meta_collection_view_model.gd:5` describes its rows as
"filter-ready", so the data side was prepared for it.

### Change required

1. Add a filter and a sort control to the home collection browser, reusing
   the pattern, sizing and focus handling from `run_inventory_screen.gd`.
2. Sort keys: name, tier, condition (float), sale value, newest. Filter: all,
   by collection, bags only, equipped/packed.
3. Do the sorting in the view model, not in the persistent store; the store's
   order must not change.
4. Keep keyboard and touch parity, and the 1280×720 fixed layout. The
   selection must survive a re-sort.
5. Reset both controls when the screen closes, as the in-run screen does
   (`run_inventory_screen.gd:155-164`).

### Acceptance

Sorting and filtering change only what is displayed; the saved collection
bytes are identical before and after; focus traversal and Escape still work.

---

## 3. Planned content and presentation that was not built

## FEAT-05 — Scenario characters teleport instead of walking

**Status:** From the plan, not verified. **Blocked by:** scenario pause; needs
design. **Source:** `docs/plans/0.6.1_backlog.md`, "Animate scenario
`set_position` receipts between fixed slots".

When a scenario phase moves a character, the character snaps to the new slot.
The original design had them walk. The backlog names 45 scenarios where walks
were removed for the release-week layout, and separately says the Delta
Queen's captain, guard, crowd and wedding party were made stationary. The
`set_position` actor operation is in
`scripts/core/scenario_operation_registry.gd:28`, `:617-620`.

This is not a small task: a walk has to reserve the old slot, sweep a body
through the room without crossing other occupants or the player's access
lane, and never block an exit. It needs its own plan and the scenario pause
lifted. Listed so it is not lost; do not start it from this document.

## FEAT-06 — Shared room art and two props with no visual

**Status:** From the plan, not verified. **Blocked by:** art.
**Source:** `docs/plans/0.6.1_backlog.md`, "Rooms and placement".

- The Motel lobby reads partly as a bedroom, and the Punchline's club, casino
  and back-room layers share art, so the layers look alike.
- The Delta Queen wedding ceremony rope and the Grand Casino convention table
  blockade were given no drawn object because nothing fit the walkable lane.

A worker cannot produce these. They need backgrounds and props from an
artist, then a placement pass. Check them in play first; later placement work
may have changed how they look.

## FEAT-07 — The Count heist takes longer than intended

**Status:** From the plan, not verified.
**Source:** `docs/plans/0.6.1_backlog.md`; rw06 final queue T4.

The owner accepted the route at 389 bridge actions (164 gameplay actions)
against a target of 150–350. The backlog suggests consolidating presentation
waits or one remaining setup revisit. Constraints: keep Audit Roster, schedule
hold, cart handoff, all three Hold → Sit → Dock blackjack hands and the marked
getaway; change no blackjack rule, odds or payout.

First step is measurement: replay the route, record where the actions go, and
propose specific cuts to the owner. Do it together with FEAT-02, since
restoring the trust arc pulls the other way.

## FEAT-08 — The 0.6 text never had its voice and copy pass

> **Owner decision 2026-11-12:** **the owner will do this by hand.** Not a worker task. Listed in the 0.6.2 queue.

**Status:** From the plan. **Blocked by:** D7 (timing).
**Source:** `docs/todo/deferred_0_6_1/voice06_1_voice_pass_prompt.md`
(status PARKED).

Everything written for 0.6 — 55 scenarios, Crew, heist, new characters — has
not been through the register and brevity pass that 0.5's text got. The
player-visible symptoms are uneven tone and over-long lines. QOL-03 in the
first audit (internal wording shown to players) is the same class.

The prompt in the repository is complete and self-contained: inventory every
string added since `v0.5.0`, classify house-side or street-side, apply the
brevity rule, check character consistency, and make string-only edits with
zero mechanical change. Use it as written, with two updates: its board
protocol refers to the old 0.6 board, so register the work in the current
ledger instead; and it should run after FEAT-01 and FEAT-02 settle their
text.

## FEAT-09 — Three known scenario defects are parked

> **Owner decision 2026-11-12:** **fix the two concrete defects** (`BTH-SCENARIO-WEDDING-001`, `BTH-SCENARIO-ARRIVAL-002`). `BTH-11` stays open with no work; it is a 0.6.2 item.

**Status:** From the ledger. **Blocked by:** D5 (scenario pause).

| Ledger ID | Defect |
| --- | --- |
| `BTH-SCENARIO-WEDDING-001` | Delta Queen Wedding Charter: a delayed initial arrival selects failure |
| `BTH-SCENARIO-ARRIVAL-002` | Punchline Bringer Show: layer-arrival ordering |
| `BTH-11` | "Scenario polish" — scope needs restating before anyone starts |

The first two are concrete player-facing defects with existing evidence in
the ledger. They resume from their recorded next actions when the pause is
lifted; this document adds nothing to their diagnosis.

## FEAT-10 — Three older bugs were held and never rechecked

**Status:** From the plan; needs play.
**Source:** `docs/plans/agent_playtest/agent_playtest_report_2026-09-12.md`
and `…_postfix_06_claim_audit_2026-09-13.md`.

| Bug | Report |
| --- | --- |
| BUG-10 | Punchline back room: Vic Mercer enabled but not drawn and not clickable |
| BUG-34 | Venue-derived Numbers Book labels overflow their width (Gas Station) |
| BUG-37 | A scenario object can cover the base safe-exit label on a Tier-2 arrival |

All three were held in September because room placement was being rebuilt.
The slot system has since been replaced and the owner accepted the placements
on 2026-10-18, so they may already be gone. The task is a recheck in play at
1280×720, then either close with evidence or open a fresh, reproduced item.

## FEAT-11 — Two item packs must be switched on by the player

**Status:** Verified in data. **Owner decision 2026-11-12: fix.** A player
must not need to enable anything to receive these items.

### What the player notices

`data/content_groups/groups.json` has sixteen groups. Fourteen have
`"default_enabled": true`. Two do not, so their items never reach a player who
has not opened Run Setup and switched the pack on:

| Group | Display name | Items |
| --- | --- | --- |
| `scenario_souvenirs` | Scenario Souvenirs | `wedding_ribbon_favor`, `wake_matchbook`, `fight_night_betting_slip`, `festival_brass_token`, `estate_map_clasp`, `convoy_cb_tag`, `tour_bus_luggage_tag`, `lock_in_door_chit`, `delivery_twine`, `lotto_queue_number`, `boarded_window_nail`, `rent_party_hat_pin`, `recording_room_tape` |
| `crew_gear` | Mags' Bench Gear | `mags_loaded_dice`, `mags_tuned_loupe`, `mags_lined_sleeve`, `mags_nudge_dampener`, `mags_shim_kit`, `crew_package` |

The souvenirs are rewards from scenario nights; the bench gear is crafted at
Mags' bench. Neither is ordinary shop stock, so with the packs off a player
can finish the scenario or reach the bench and get nothing.

### Find out first

What exactly does "off" block today? Check in the running game, with both
packs off: does a scenario still hand over its souvenir; does Mags' bench
still offer its gear; does a Crew delivery still create `crew_package`? The
group defaults are read at `scripts/core/content_library.gd:935` and `:978`.
Record the answers; they decide how much this change alters play.

### Change required

1. Set `"default_enabled": true` for both groups in
   `data/content_groups/groups.json`.
2. Check that an existing profile which never touched Run Setup now gets the
   packs, and that a profile which deliberately switched a pack off keeps its
   choice. If stored settings record the old default as an explicit "off",
   say so and ask before overriding anyone's saved choice.
3. Decide nothing about the Run Setup toggles themselves. They can stay; the
   requirement is only that the default is on.
4. **Do not change any of these items' effects, prices or text.** Item
   effects are under reassessment for 0.6.2.
5. Confirm these items do not enter ordinary merchant stock as a side effect.
   They should arrive only by their intended route (scenario reward, bench
   crafting, delivery).

### Tell the owner before shipping

Two of the souvenirs (`wedding_ribbon_favor`, `rent_party_hat_pin`) advertise
+1 luck that is not applied when a scene grants them, and `mags_lined_sleeve`
carries a Slot odds bonus that Slots ignore (FEAT-01 parts A and B, parked).
Turning the packs on puts those items in front of every player before they
are fixed. That is the owner's call and has been made; report it so it is not
a surprise.

### Acceptance

On NEXT, with a fresh profile and no visit to Run Setup: one scenario night
awards its souvenir, and Mags' bench offers its gear. Shop stock is unchanged.

---

## QOL-06 to QOL-10 — carried over from the first audit

> **Owner decision 2026-11-12:** **none wanted now.** Leave them recorded; do not plan or build any.

Unchanged from `BTH_0.6.1_audit_work_orders.md`, Part F: a controls reference
page (and later rebinding), rebet in more games, a faster-table option, more
than one save slot, and a localisation layer. Each needs a short plan before
work; D8 sets the order. `AUD061-03` (the performance harness reachable from
a URL) is also still open from that audit.

---

## 4. A defect found while auditing (not from any plan)

Covered above as part of FEAT-03: the Daily Challenge seed ignores the year
and is trivially derivable from the date. Listed here because no plan in the
repository mentions it.

---

## 5. Order for the worker (after the owner's decisions)

1. **Section 8** — close the stale plan entries, and close FEAT-04 as not
   wanted.
2. **FEAT-03** — daily seed fix.
3. **FEAT-11** — both item packs on by default.
4. **FEAT-10** — recheck BUG-10, BUG-34 and BUG-37 in play.
5. **FEAT-09** — the two scenario defects.
6. **FEAT-02 and FEAT-07** — one investigation, one report, nothing shipped.
7. **Section 9** — record the 0.6.2 queue in the ledger so it is not lost.

Not for the worker in this queue: FEAT-01, FEAT-04, FEAT-05, FEAT-06, FEAT-08,
`BTH-11`, QOL-06 to QOL-10, and everything in sections 6 and 7.

---

## 6. Owner, platform and human-only items

Listed so the queue is complete. None is a worker task.

| Item | Why it is not a worker task | Source |
| --- | --- | --- |
| Tutorial human gate (TUT-N17): five cold players, two without Blackjack knowledge, 5/5 unassisted completion and 80% comprehension | Requires people | `docs/todo/deferred_0_6_1/tutorial_first_time_player_completion_prompt.md` |
| Online leaderboards and achievements | Needs a platform service; the adapter is a local stub by design | `scripts/core/platform_services.gd` |
| Steam Inventory and community-market integration | Platform account and SDK | `docs/plans/0.6.1_backlog.md` |
| Android and iOS builds | Signing and team credentials; presets exist but are stale | `docs/current_game_state.md` |
| Act 2 | The hand-off data from Act 1 is implemented and written at victory; nothing consumes it. Act 2 has no rooms, economy or story. It needs design. | `docs/plans/act_two_seam.md` |
| Trailer, devlog, publish copy | Templates exist, parked | `docs/todo/release06_1_*_template.md` |
| Lucky Penny and Ledger Pencil redesign | Owner design (D3) | Ledger `BTH-15`, `BTH-17` |
| New room art | Artist | FEAT-06 |

---

## 7. Deferred qualification campaigns

These are not features, but they are how unknown player-facing problems get
found, and all are still parked. Each has a written procedure.

| Campaign | What it covers | Source |
| --- | --- | --- |
| Full named 11-game campaign | All eleven games, all three Coin Pusher machines, Turn on and off, all three Cass endings, both victory routes plus the Crew route, a crew-ignoring run | `docs/todone/playtest06_2_playtest_gate_refresh_prompt.md` |
| Binding cross-economy audit | 8 playstyles × 64 seeds × 208 actions, plus 600k Coin Pusher EV | `docs/todo/deferred_0_6_1/balance06_1_follow_on_cross_system_economy_audit_prompt.md` |
| Performance and platform qualification | Low-end matrix on a quiet, witnessed host | `docs/todo/deferred_0_6_1/perf06_1_*` |
| Feature-music soaks B and C | Long-run audio stability | `docs/todone/postfix06_2_post_fix_remediation_ledger.md` |
| Post-playtest triage and cleanup | Process for turning playtest findings into fixes | `docs/todo/deferred_0_6_1/triage06_1_*`, `cleanup06_1_*` |

The first audit's AUD061-17 covers the 0.6.1 subset of the first row. The
cross-economy audit is the one to run before any balance or item change in
this queue ships, because FEAT-01 part C makes four items stronger.

---

## 8. Stale plan entries to close

A plan still lists each of these as open. The code or a later document shows
it is done, or the owner has since closed it. Leaving them open sends people
after finished work.

| Plan entry | Where it is listed | What shows it is finished |
| --- | --- | --- |
| env06_9 "visual consequences and object identity (127 failures across 53/55 scenarios)" | `docs/plans/0.6.1_backlog.md` | The prompt's own header: "DONE — absorbed and completed by `fix06_28` on 2026-09-07" (`docs/todone/env06_9_…_prompt.md`) |
| Room-density restorations: Bar, Back Alley, Gas Station, Underground, Kitty Cat, Jazz Club, Beach, Delta Queen, Motel aftermath; "later-work and aftermath props in More room actions" | `docs/plans/0.6.1_backlog.md`, "Rooms and placement" | Slot schema v2 (rw06 task T10, DONE) reports 722 slots with zero overflow; every `scenario_overflow_ids` list in `data/environments/placement_surfaces.json` is empty; no "More room actions" text remains in `scripts/ui`; the owner accepted placements on 2026-10-18. **Confirm in play before closing**, room by room. |
| Crossword Corner "held from new sale" | `docs/item-audit/…csv`; `docs/plans/game06_5_option_c_owner_decision.md` | `crossword_corner` is in `ACTIVE_TICKET_TYPE_IDS` (`scripts/games/scratch_tickets.gd:64`); the decision document is marked superseded |
| Web audio memory leak (T8); Coin Pusher slow and UI leaking into other rooms (T9) | `docs/todo/rw06_final_queue.md` | Both rows are DONE in that same table |
| Mid-0.6 save migration fixtures | `docs/plans/0.6.1_backlog.md` | Closed by the owner's decision of 2026-11-11 that save data need not be preserved |
| Skill-based cheating methods; dynamic music rework | `docs/plans/skill_based_cheating_methods_plan.md`, `music_system_rework_plan.md` | Both documents are headed "IMPLEMENTED… active in the current 0.6 source" |

Change: add a dated "closed, see …" line to each entry in the document that
lists it. Do not delete the entries; the history is useful.

---

## 9. The 0.6.2 queue

Set aside by the owner on 2026-11-12. Record each in the ledger as open with
no work authorized. None is started from this document.

| Item | What it is | Who |
| --- | --- | --- |
| Item-effect reassessment | A full review of what every item does, before any effect is changed. FEAT-01 parts A–E and `docs/item-audit/` are the starting evidence. Lucky Penny (`BTH-15`) and Ledger Pencil (`BTH-17`, `LEDGER022`) are part of it. | Owner first, then worker |
| Scenario polish (`BTH-11`) | Scope to be stated by the owner | Owner first |
| Voice and copy pass (FEAT-08) | All text added in 0.6 | Owner, by hand |
| In-game leaderboard for the Daily Challenge | Local, in the game; no online service | Needs a design |
| The Whale Game and the Crew trust arc | Depends on the FEAT-02 report | Owner decides after the report |

---

## Appendix — What I could not determine

- Whether any of the **From the plan, not verified** items still look the way
  the plan describes. The plans are six to ten weeks old and placement,
  scenarios and performance have all moved since.
- Whether the other eleven scenario-reward souvenirs have the same gap as the
  two in FEAT-01 part B.
- Whether The Whale Game is close to working or far from it.
- Anything about feel: pacing, difficulty, readability, audio mix. Those need
  a person playing the build.
