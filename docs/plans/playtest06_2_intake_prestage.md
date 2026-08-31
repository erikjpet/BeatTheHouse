# playtest06_2 Intake Prestage

Status: **UNREVIEWED PRESTAGE — no seed or readiness claim**

Snapshot source: `00ee744f` (the 2026-08-28 fifth-landing quiesced checkpoint).

This document prepares inputs for `playtest06_2`. It does not claim that row,
does not amend `playtest06_1`, and does not change either prompt or the board.
No seed was selected, run, or verified. No product, test, build, package, release,
or remote state was touched.

## Current 29-item program inventory

The parallel-delivery program names 28 core rows: five depth, eight Family 1,
seven Family 2, seven cross-cutting, and the `playtest06_1` terminus. Its ordered
`balance06_1-follow-on`, required after Families 1 and 2, is the twenty-ninth
item represented below. It is not yet materialized as its own board row. This
counting rule is explicit here so `playtest06_2` does not silently invent or
omit a dependency when it later amends `playtest06_1`.

Statuses below are transcribed from the board at the snapshot source. They are
not acceptance judgments by this prestage.

| # | Item | Current status | Current dependency/closure fact |
| ---: | --- | --- | --- |
| 1 | `env06_6` | IN_PROGRESS | Formal acceptance withheld pending serialized Full/audit/determinism/native-Web parity/performance/21-image visual gates and independent visual review. |
| 2 | `env06_7` | TODO | Depends on `env06_6`; closes into `depth06_1`. |
| 3 | `craps06_3` | TODO | Depends on `craps06_1/2` and `env06_6`; closes into `depth06_1`. |
| 4 | `crew06_10` | TODO | Depends on `crew06_2/5/6/9` and `env06_6`; closes into `depth06_1`. |
| 5 | `depth06_1` | TODO | Depends on `env06_7`, `craps06_3`, and `crew06_10`. |
| 6 | `game06_1` | IN_PROGRESS | Contract-first program override active; product implementation remains stopped pending exact contract acceptance and later consumes `craps06_3`. |
| 7 | `game06_2` | TODO | Depends on `game06_1`; feeds `game06_7`. |
| 8 | `game06_3` | TODO | Depends on `game06_1`. |
| 9 | `game06_4` | TODO | Depends on `game06_1`; machine-authority owner decision remains external to this snapshot status. |
| 10 | `game06_5` | TODO | Depends on `game06_1`. |
| 11 | `game06_6` | TODO | Depends on `game06_1` and `craps06_3`. |
| 12 | `game06_7` | TODO | Depends on `game06_1` and `game06_2`. |
| 13 | `game06_8` | TODO | Depends on `game06_2..7` and `depth06_1`; Family 1 closure. |
| 14 | `world06_1` | TODO — CLAIM AUTHORIZED BY OTHER LANE | May implement against frozen `env06_6` head `855a2961`; rebase if rejected. |
| 15 | `world06_2` | TODO | Depends on `world06_1`; feeds `world06_6`. |
| 16 | `world06_3` | TODO | Depends on `world06_1` and `world06_2`. |
| 17 | `world06_4` | TODO | Depends on `world06_1`. |
| 18 | `world06_5` | TODO | Depends on `world06_1` and `game06_1`. |
| 19 | `world06_6` | TODO | Depends on `world06_1`, `world06_2`, and `crew06_10`; feeds `world06_7`. |
| 20 | `world06_7` | TODO | Depends on `world06_2..6`; Family 2 closure. |
| 21 | `meta06_1` | DONE | Accepted source and integration landed; retained timing-only and inherited UI disclosures remain recorded on the board. |
| 22 | `pusherv3_11` | BLOCKED | Needs current-main `fix06_13` closure and the `fix06_8` owner decision; required closure evidence remains pending. |
| 23 | `audio06_1` | TODO | Depends on Families 1 and 2 rituals landed. |
| 24 | `integ06_1` | TODO | Depends on Families 1 and 2 merged; feeds `playtest06_2`. |
| 25 | `perf06_1` | TODO | Depends on Families 1 and 2 merged; feeds `playtest06_2`. |
| 26 | `teach06_2` | TODO | Depends on `depth06_1`, `game06_8`, and `world06_7`. |
| 27 | `playtest06_2` | TODO | Depends on `integ06_1` and `perf06_1`; later amends `playtest06_1`. |
| 28 | `playtest06_1` | TODO | Board still says “ALL other rows DONE (except parked)”; this is the dependency that `playtest06_2` must replace explicitly. |
| 29 | `balance06_1-follow-on` | ORDERED, NOT MATERIALIZED AS A BOARD ROW | Runs after Families 1 and 2; full distributions, 600k pusher EV, findings, and proposals remain outstanding. |

Loose blockers are not silently counted as substitutes for these 29 items.
`fix06_13` is currently PARKED but may unpark; it is a direct blocker of
`pusherv3_11`. The program prompt also names `fix06_18`, but no active
`fix06_18` row exists in the snapshot board. `fix06_3` remains separately
blocked on an owner art/mechanics decision. The final dependency amendment must
resolve these facts from the then-current board rather than copy this snapshot.

## Finding capture schema

One finding is one record. Preserve the owner's wording separately from agent
normalization.

| Field | Required content |
| --- | --- |
| Finding id | Stable intake id; never reused. |
| Reporter text | Verbatim owner note, attachment references, and timestamp. |
| Build identity | Exact played commit, platform/build, save/profile id, and whether the tree/build was clean. |
| Route identity | Session, named seed id, actual seed value, run id, environment/archetype, layer, game, scenario/branch, crew state, and step. |
| What happened | Observable behavior only, including frequency and whether progress remained possible. |
| Expected result | Owner's expected behavior; mark `unstated` rather than infer it. |
| Reproduction | Minimal steps, starting state/save provenance, inputs, repeat count, and reproduction rate. |
| Evidence | Screenshot/video/log/save/report paths and exact timestamps; hidden-state material access-restricted. |
| Impact | Player consequence: crash, corruption, soft-lock, dead interaction, wrong outcome, lost progress, unreadable state, feel, balance, copy, art, audio, or direction. |
| Classification | `UNTRIAGED`, `DEFECT`, `DESIGN_OBJECTION`, `MIXED`, or `QUESTION`. |
| Severity | `P0`, `P1`, `P2`, `P3`, or `UNSET`; assigned using the protocol below. |
| Scope authority | Owning row/system and whether locked design/economy/content authority is implicated. |
| Disposition | `BLOCKING`, `FIX06_CANDIDATE`, `OWNER_DECISION`, `DEFERRED`, `DUPLICATE`, `NOT_REPRODUCED`, or `NEEDS_EVIDENCE`. |
| Decision/evidence needed | The smallest missing fact, reproduction, or owner choice required. |
| Links | Routed `fix06_*` row, roadmap decision id, duplicate id, review head, and closure evidence when available. |

Do not place unrevealed Turn, grievance, rigged-result, scenario, or other hidden
state in a player-facing intake summary. Preserve it only in appropriately
restricted diagnostic evidence.

## Defect-versus-design triage protocol

1. **Normalize without interpreting.** Attach the exact build, route, save, and
   evidence. If expected behavior was not stated, ask for it or mark it
   `unstated`.
2. **Check an accepted contract.** A reproducible departure from accepted
   behavior, data integrity, accessibility, input parity, persistence,
   determinism, performance, or presentation contracts is a `DEFECT`.
3. **Protect locked authority.** A request to change intended rules, odds,
   economy, progression, hidden-information policy, narrative outcome, art
   direction, feel, scope, or authored behavior is a `DESIGN_OBJECTION`. Route
   it to an owner decision in the roadmap; an agent may not convert it into a
   defect merely because implementation would be straightforward.
4. **Split mixed notes.** When an observable defect and a design objection share
   one note, create linked child records. The defect may route independently;
   the design portion waits for owner authority.
5. **Assign severity by impact, not preference.**
   - `P0`: corruption/data loss; security/privacy or hidden-state leak;
     deterministic/native-Web outcome divergence; unrecoverable global
     progress block; duplicate/missing authoritative economy settlement.
   - `P1`: repeatable crash/soft-lock/dead required interaction; major route or
     required content unreachable; save/restore break; sustained performance
     failure that makes play nonviable; accessibility/input path blocks play.
   - `P2`: material wrong or misleading behavior with a viable workaround;
     frequent presentation/performance defect that degrades judgment; optional
     branch blocked.
   - `P3`: localized polish/copy/art/audio issue with no incorrect state or
     blocked progress.
6. **Choose blocking status.** `P0` is blocking. `P1` is blocking when it
   prevents a required route, reliable save/restore, usable build, or trustworthy
   playtest signal. `P2/P3` defer unless they systematically invalidate the
   question the owner is being asked to judge. A design objection blocks only
   when the owner says the disputed direction prevents further useful testing.
7. **Route, do not fix in intake.** Product defects become narrowly scoped
   `fix06_*` candidates with owner, evidence, acceptance, and dependencies.
   Design objections become owner decisions. Harness/evidence defects route to
   the responsible gate/integration row unless player-observable.
8. **Close with exact proof.** Record accepted head, exact-tree verification,
   and disposition. “Could not reproduce” is not “fixed”; retain the original
   note and environment.

`polish06_0` consumes the disposition and severity fields only after the owner
opens that parked program. Intake must not schedule polish or release activity.

## Seed coverage plan — all values unverified

Every value remains `TBD — UNVERIFIED`. Labels below are coverage slots, not
claims that a seed exists or that one seed must cover only one slot. The final
seed list must be verified on the exact build the owner will play and retain
evidence for every claimed route.

| Coverage slot | Required reachability | Seed value | Verification |
| --- | --- | --- | --- |
| ARCHETYPE-01..N | Every current environment archetype, including each Punchline layer where distinct | TBD | UNVERIFIED |
| SCENARIO-REPRESENTATIVE | Owner-defined representative spread across the complete 55-scenario catalog | TBD | UNVERIFIED |
| SCENARIO-BRANCHES | Every included scenario's material branch and aftermath | TBD | UNVERIFIED |
| GAME-01..11 | Each of all eleven shipped games, with complete entry/action/settlement/exit | TBD | UNVERIFIED |
| PUSHER-QUARTER | Quarter Falls machine and its defining route/variation | TBD | UNVERIFIED |
| PUSHER-JACKPOT | Jackpot Ridge machine and its defining route/variation | TBD | UNVERIFIED |
| PUSHER-VAULT | Vault Drop machine and its defining route/variation | TBD | UNVERIFIED |
| CREW-RECRUIT | Full recruitment path through required ranks/`inner_circle` | TBD | UNVERIFIED |
| HEIST-PLAN-A | First production heist plan, success and abort/failure boundary | TBD | UNVERIFIED |
| HEIST-PLAN-B | Second production heist plan, success and abort/failure boundary | TBD | UNVERIFIED |
| TURN-FIRES | A run in which the Turn and confrontation fire | TBD | UNVERIFIED |
| TURN-NO-FIRE | A valid control run in which the Turn does not fire | TBD | UNVERIFIED |
| CASS-END-1 | First authored Cass ending | TBD | UNVERIFIED |
| CASS-END-2 | Second authored Cass ending | TBD | UNVERIFIED |
| CASS-END-3 | Third authored Cass ending | TBD | UNVERIFIED |
| VICTORY-ROUTE-1 | First non-crew victory route through profile handoff | TBD | UNVERIFIED |
| VICTORY-ROUTE-2 | Second non-crew victory route through profile handoff | TBD | UNVERIFIED |
| VICTORY-CREW | Crew victory route through profile handoff | TBD | UNVERIFIED |
| CREW-IGNORING | True no-op control run: no crew side effects or hidden progression | TBD | UNVERIFIED |
| NUMBERS-ROUTES | Fix and past-post routes, including failure/exit behavior | TBD | UNVERIFIED |
| SWEEP | Police Sweep arrival, interaction, escape/exit, and aftermath | TBD | UNVERIFIED |
| DELIVERY | Ordinary, multi-stop, hold, stash/ditch, failure, and revisit paths | TBD | UNVERIFIED |
| SAVE-BOUNDARIES | Mid-heist, mid-delivery, mid-hand, mid-layer, mid-scenario, and terminal round trips | TBD | UNVERIFIED |
| COMPOSITION-MAX | `integ06_1` maximal composition, abandonment orders, and return | TBD | UNVERIFIED |
| FULL-RUN-CONTROLS | Start/mid/late/terminal native-Web paired traces and representative failures | TBD | UNVERIFIED |

For every filled slot, record seed text exactly, source/build, platform, setup,
expected route, actual route, branch choices, evidence, and verification date.
A seed that drifts, requires an undisclosed save edit, or reaches the target only
through a debug-only action is not verified owner-playtest coverage.

## Known-context inputs still missing

### integ06_1

- Accepted final report and exact integration head.
- Provenance-backed 0.5 and mid-0.6 save inventory and per-save migration
  results.
- Actual `integ06_1` maximal-composition manifest, fixture ids, active-system
  counts, precedence, abandonment orders, and per-combination verdicts.
- Native/Web full-run soak seed list and exact outcome traces.
- Determinism, parity, state-growth, orphan, double-consequence, save/revisit,
  and terminal-route results.
- Routed findings, severities, owners, and unresolved blockers.

The partial docs-only inventory at `e3b915bd1102c877540e547af69a33c30d0d0ad3`
is prestage context, not accepted `integ06_1` evidence.

### perf06_1

- Accepted final report and exact measured candidate.
- Complete hardware/build/plugin-hash/seed/warm-up/sample manifests.
- Native, exported-Web, and named low-end per-surface and per-composition matrix.
- Allocation/copy and idle-liveness pairing for every measured idle row.
- Web export size, cold/warm load, first-interactive, memory, and fresh-start
  results.
- Start-to-terminal growth trajectory, defended 0.5 comparisons, exceptions,
  optimizations, and routed findings.

The docs-only prestage at
`567222db63d021f15d30a1179c0c875406956b1a` and qualifying historical checkpoint
`a04fa18b2161113cc7e9b14ac4df1354d76c84e5` do not supply the final matrix.

### Coin Pusher / pusherv3_11

- Accepted `pusherv3_11` closure head and final audit report.
- Current-main `fix06_13` integration and a green locked shipped-Web result.
- The outstanding `fix06_8` owner decision and its implemented/verified effect.
- Required EV, determinism, native/Web parity, lifecycle, performance,
  broad-suite, and visual evidence identified by the rejected closure review.
- Exact current seed/machine reachability evidence for all three cabinets and
  any known limitations the owner should not rediscover.

Until these inputs arrive, the playtest script cannot truthfully state what is
finished, known-rough, blocked, or already proven. Their absence is not a seed
failure and must not be hidden by reusing historical evidence from another
tree.

## Handoff boundary

`playtest06_2` may amend `playtest06_1` only after the dependency set is
reconciled against the then-current board and the required integration,
performance, balance-follow-on, and pusher contexts exist. At that time it must
replace every `TBD — UNVERIFIED` seed with current-build evidence or leave the
readiness work blocked. This prestage authorizes no playtest build and no
release activity.

