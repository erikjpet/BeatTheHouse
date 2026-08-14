Status: DONE
Board row: `crew06_1` in `docs/todo/README_0_6_board.md`

## Execution Record (fill on completion)

- **Completed:** 2026-08-14
- **Completion/implementation commits:** `2b3f91da`
- **Verification:** PM scope/design review; lender/favor compatibility, hidden ledger/jobs, save migration, integrated systems/UI/all-foundation, 10-seed determinism (`38535979`), and Wave A coexistence probe all PASS.
- **Deviations:** None. No Crew trust, grievance, or job state is exposed in UI or logs.

# Agent Prompt — 0.6 crew06_1: Crew Trust Core (Ladder, Ledger, Jobs)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike (Web/itch.io + Windows, 1280×720). Run logic in
`scripts/core/run_state.gd`; the Crew exists today as lender
`the_crew` in `data/debt/lenders.json` with the favor flow
(`crew_favor_due`, `crew_favor_delivery`,
`narrative_flags["crew_favor_pending"]`) and 7 crew characters in
`data/characters/characters.json`. Binding design contract:
`docs/plans/0.6_living_world_roadmap.md` — read Pillar 3 (trust ladder,
jobs, The Turn's ledger) and Guardrails first. This prompt is
self-contained for rules and scope.

## Board protocol

1. Before work: in `docs/todo/README_0_6_board.md`, set row `crew06_1`
   to `IN_PROGRESS` with agent + date, append a Work Log line, commit
   the claim. If the row is not `TODO`, stop and pick other work.
2. Log discoveries/deviations in the Discovery & Decision Log (tagged
   `[crew06_1]`); owner-only questions under Owner Questions.
3. If blocked: row → `BLOCKED` + reason, log, stop.
4. On completion: row → `DONE` + verification note; fill Execution
   Record; move this file to `docs/todone/`; Work Log line naming
   unblocked rows (streets06_1, crew06_2/3/5/6/7/8/9).

## Dependencies

None (Wave A). This is a state-model slice: **no new UI screens, no
content** — it ships the typed model + API that every crew prompt
consumes. Keep the API boring and stable.

## Task

### 1. Trust model

- Add to `RunState` (typed, serialized, reset per run): per-member
  trust for the 7 crew ids (`crew_rook`, `crew_velvet`,
  `crew_knuckles`, `crew_switch`, `crew_mags`, `crew_bishop`,
  `crew_lucky`) plus derived crew-wide standing.
- Rank ladder (data-tuned thresholds in a new `data/crew/crew.json`):
  `stranger → marker → associate → made → inner_circle`.
  Rank is per-member; crew standing gates shared unlocks (layer-3
  access at first `made`, heist eligibility per plan requirements —
  consumed later, defined here).
- **Retcon, zero behavior change:** taking the existing crew loan sets
  Rook (and pool members involved) to `marker`. The shipped lender
  flow, favor scheduling, and cash-conversion behavior stay
  byte-identical — trust is written alongside, never instead.

### 2. Grievance ledger (The Turn's fuel — model only this slice)

- Per-member ledger of typed grievance entries:
  `{id, member_id, kind, weight, turn_recorded, source_ref}`.
  Ship the kind taxonomy from the roadmap: `job_abandoned`,
  `stake_horse_loss_shrugged`, `distraction_heat_dumped`,
  `wrong_accusation`, `favor_converted_unpaid`,
  `numbers_past_posting_in_colors`. Writers for most kinds arrive in
  later prompts; this slice wires `favor_converted_unpaid` (the
  existing crew cash-conversion path) as the proof writer.
- Ledger is hidden: no UI anywhere. Read API exists for crew06_9 only.

### 3. Job framework

- Generic job lifecycle in RunState: `offer → accepted → active →
  resolved(success|failed|abandoned)` with typed job defs
  (`data/crew/jobs.json` schema: id, member_id, kind, payload,
  expiry_in_actions, rewards {cash, trust}, failure {trust, grievance
  kind}). Expiry counts **action boundaries, never wall-clock**.
- Ship one end-to-end proof job: reframe the existing
  `crew_favor_delivery` event resolution to route through the job
  framework (same player-visible behavior today; streets06_1 later
  replaces its resolution with real gameplay — leave a marked seam).
- API for later prompts: `crew_trust(member)`, `crew_rank(member)`,
  `crew_add_trust(member, amount, reason)`, `grievance_add(entry)`,
  `job_offer/accept/resolve`, `crew_standing()`. Document each in the
  script header.

### 4. Persistence

- Full serialization of trust, ledger, jobs; schema-versioned;
  pre-0.6 saves load with all members at `stranger` (or `marker` if
  the legacy crew-debt flags indicate an active/converted crew loan —
  derive, don't guess).

## Hard rules

- Zero visible behavior change to the shipped crew lender/favor flow —
  covered by regression test against current behavior.
- Determinism: nothing here rolls RNG; all timing is action-boundary.
- Hidden means hidden: no ledger or trust numbers in any UI/log string
  this slice (story log may record diegetic lines only where the
  existing favor flow already logs).
- Style: tabs, typed GDScript, sparse comments; `.tmp/` reports only.
  Suite timeout = max(300s, baseline×1.5).

## QA / Tests

1. Regression: full existing crew loan → favor → conversion sequence is
   behavior-identical (drive it end-to-end in a test, compare flags,
   debts, messages).
2. Loan sets `marker`; thresholds promote ranks per data; standing
   derives correctly.
3. Cash-conversion writes `favor_converted_unpaid` grievance; repaying
   before conversion writes none.
4. Job lifecycle: offer → expiry at exactly N action boundaries →
   `abandoned` + configured failure effects; success pays cash + trust.
5. Save/load round-trips trust/ledger/jobs; pre-0.6 save derives ranks
   correctly from legacy flags.
6. Content check validates `crew.json` + `jobs.json` (member ids,
   kinds, thresholds monotone).

## Gates

- `tools/validate_project.ps1`
- every supported `-FoundationSuite` covering systems + UI
- `tools/foundation_determinism_probe.ps1 -RequireGodot -SeedCount 10`

## On completion

Commit in logical units, push, complete Board protocol step 4, and
report: model shapes, API surface, retcon proof (regression evidence),
and gate results. On an unfixable gate failure: stop at last green
commit, set `BLOCKED`, report verbatim.
