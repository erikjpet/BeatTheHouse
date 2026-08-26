Status: TODO
Board row: `meta06_1` in `docs/todo/README_0_6_board.md`

# Agent Prompt — 0.6 meta06_1: Career, Run Report and Meta Surfacing of 0.6

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`. This row makes 0.6 visible in
the between-run surfaces. It adds reporting, not progression. Read
`scripts/ui/career_stats_view_model.gd`, `scripts/ui/career_stats_screen.gd`,
`scripts/ui/run_report_view_model.gd`, `scripts/core/profile_inventory.gd`
(`_record_lifetime_stats`, `_normalize_lifetime_stats` and the run history path),
`scripts/core/run_terminal_evaluator.gd`, and roadmap owner decision #1 in
`docs/plans/0.6_living_world_roadmap.md`.

## The finding this row exists for

`career_stats_view_model.gd` builds its `routes` list from two hardcoded entries:
`players_card_cashout` and `showdown`. `profile_inventory.gd` records victories
generically — `victories[route] = ...` keyed on whatever route string the run
entry carries — so the `crew_heist` victory route added by `crew06_8` is counted
in the profile dictionary and displayed nowhere. A player can finish 0.6's
flagship path and see no evidence of it on the career screen.

The rest follows from the same gap. Lifetime stats track total runs, victories
per route, biggest single win, bankroll won and lost, and games played. They
track nothing about crew standing, the Numbers, scenarios seen, nights survived,
deliveries, sweeps or the coin pusher. The run report references the heist and
almost nothing else from the update. An entire release is invisible the moment a
run ends.

## Board and dependencies

Follow the active board protocol. Claim `meta06_1`. This row has no dependency on
the depth programs and can start immediately. You own the career and run-report
view models and screens, and the profile stats path, plus their tests.

## 1. Roadmap constraint — read before designing

Owner decision #1 makes the Players Card the only cross-run system in 0.6, and
the `content06_1` ruling confirmed no new cross-run progress may be added. This
row therefore adds **reporting of things that already happened**. It must not
add cross-run unlocks, currencies, collections, prestige or any progression that
changes a future run. If a display would create an incentive to grind, it is out
of scope for this row.

## 2. Victory routes

- Drive the route list from the routes the game can actually produce, rather than
  a hardcoded pair. Include the `crew_heist` seam route with correct copy.
- Audit `run_terminal_evaluator.gd` and the seam route path for every route
  string a finished run can carry, including failure reasons, and confirm each
  maps to a display the screen can render.
- Historical profiles that already contain a counted-but-undisplayed route must
  render correctly without migration loss. A player who won by heist before this
  row landed must see it afterwards.

## 3. What 0.6 did, in the report and the ledger

Extend the end-of-run report and lifetime stats with the update's actual
content, keeping every existing field's meaning intact:

- Crew: whether the path was walked, standing reached, members met, jobs
  completed and abandoned, and how the Turn resolved — the last only in terms
  the Turn's contract permits after resolution.
- World: nights and scenarios experienced, notable outcomes carried into
  aftermath, sweeps encountered, rumors that proved true.
- Numbers: slips placed, hits, and whether a rig route was used.
- Games: per-game activity including craps, the coin pusher and back-room poker,
  using the generic `games_played` tallies already recorded rather than a new
  parallel system where possible.
- Deliveries: runs completed, packages lost.

Keep the `missing_stats` honesty note current — if something still is not
recorded, say so there rather than implying coverage.

## 4. Discipline

- No hidden state may surface. Turn information appears only as its contract
  permits after resolution, and never for an unresolved or abandoned run.
- Do not add per-frame or per-action work to record any of this. Aggregate at the
  boundaries that already exist.
- Save compatibility: profiles from 0.5 and from mid-0.6 must load, display
  correctly with absent fields, and never lose an existing counter.
- Copy obeys the Voice Bible register and brevity rule. The career screen is a
  ledger, not a trophy case.

## 5. Tests and acceptance

- A `crew_heist` victory recorded and displayed end to end, plus a profile
  fixture that already contains the undisplayed route rendering correctly.
- Every route string a finished run can produce, mapped and rendered.
- Round-trip tests for the extended lifetime stats: absent fields, legacy
  profiles, and no loss of any existing counter.
- Hidden-state assertion: no Turn or heist secret is reachable through any new
  display, including for abandoned and failed runs.
- UI tests for the career screen and run report at 1280×720, small screen,
  reduced motion and colorblind settings, with no text overlap and no
  truncation of a value the player needs.
- Confirm no new cross-run progression was introduced — an explicit assertion
  that the added fields are read-only reporting.

Run project validation, the relevant foundation suites including
`check_lenders_release_saves.gd` and the core content save coverage, UI scene
compile checks, determinism, native/Web parity and visual QA. Archive with exact
evidence and a screenshot of a career screen showing all three victory routes.
