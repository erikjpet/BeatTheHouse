# playtest06_2 Candidate Seed Prestage

Status: **PRESTAGE ONLY — no owner build, final seed, route, or readiness claim**

Prepared from landed main `9b52c27ada01b0048bd938908b9bcae701d93ec6`,
the accepted teaching closeout, the existing
`playtest06_2_intake_prestage.md`, and recovered partial integration evidence.
This document does not claim `playtest06_2`, amend `playtest06_1`, change the
board, select a release candidate, or authorize build/package/release work.

## What was recovered

The repository already had a complete intake schema, triage protocol, and
coverage-slot inventory. It also had production probes and historical fixture
seeds worth preserving. Rebuilding either would risk losing their authority
boundaries, so this prestage adds only the missing executable contract and a
single-process catalog-discovery helper.

| Recovered input | Safe present use | What it does **not** prove |
| --- | --- | --- |
| `WAVE-B-COMPOSITION-08` | Re-run the maximal Bar/Punchline composition probe after final freeze. | A natural player route, exhaustive composition matrix, terminal route, or final-tree result. |
| `FIRST-NIGHT-ACE-17` | Candidate owner-orientation tutorial seed. | Either non-crew victory, the crew victory, or broad 0.6 reachability. |
| `CREW-IGNORED-GOLDEN-A/B` | Preserve independent no-crew control candidates from the accepted fixture lineage. | That their historical golden still matches main, or that either is a usable owner route. |
| `INTEG06-1-FINAL-SOAK` | Preserve the strict integration producer's seed prefix. | A completed soak or a single player-followable seed. |
| `SCENARIO-AUDIT` | Baseline for deterministic scenario/catalog discovery. | Natural travel, prerequisites, branch outcomes, or player reachability. |
| `PLAYTEST-CATALOG-01` | Current-main diagnostic candidate: 13 generated archetypes, eight game ids, Vault Drop, and twelve scenario assignments. | Natural travel or completion of any game, machine goal, scenario branch, or major route. |

The structured form is
`tools/playtest06_2_candidate_seeds.json`. Every row is deliberately
`CANDIDATE`, even where an earlier branch recorded a pass, because the owner
must play one later frozen tree.

The one seed that can be verified without the environment, performance, or
integration finalizations is `FIRST-NIGHT-ACE-17`, and only for the narrow
accepted guided-tutorial/orientation claim already proven by `teach06_2`.
That makes it immediately useful for the first owner session, but it cannot be
promoted as evidence for any major victory, Crew, pusher, scenario-branch, or
terminal coverage slot. Every other recovered seed depends on at least one
unfinished release-gate lane or is diagnostic-only.

## Executable promotion contract

Run:

```powershell
powershell -NoProfile -File tools/playtest06_2_seed_manifest_contract.ps1
```

In `PRESTAGE` this checks schema, Git provenance, unique seed identity, catalog
references, route-authority labels, and the rule that only public production
actions may be owner-playtest eligible. It passes while clearly reporting that
it proves structure, not reachability.

Finalization must change the manifest to `FINAL` and run:

```powershell
powershell -NoProfile -File tools/playtest06_2_seed_manifest_contract.ps1 `
  -RequireFinal -ExpectedTestedCommit <frozen-owner-build-commit>
```

That mode fails closed unless verified public-action seeds collectively name
every current archetype, all eleven games, all three pusher machines, every
required major route/control slot, the chosen representative scenarios, and
their material branches. Every verified seed must bind its commit and tree,
platform, setup, expected/actual route, evidence, and verification date. A
diagnostic seed can stay in the file for provenance, but it cannot satisfy a
final slot.

## Catalog-discovery helper

`tools/playtest06_2_seed_catalog_probe.gd` extends the already-landed
`scenario_seed_audit.gd` pattern rather than replacing it. It loads content
once, generates a map for each seed, records first-visit archetype/game/scenario
assignments and pusher variations, and selects a greedy subset that maximizes
scenario discovery.

Example:

```powershell
Godot_v4.6-stable_win64_console.exe --headless --path . `
  --script res://tools/playtest06_2_seed_catalog_probe.gd -- `
  --seeds=PLAYTEST-CATALOG-01,PLAYTEST-CATALOG-02,SCENARIO-AUDIT `
  --out=res://.tmp/playtest06_2/catalog_probe.json
```

The helper deliberately uses prevalidated node travel so it can inspect the
catalog without grinding. Its report stamps
`DIAGNOSTIC_PREVALIDATED_TRAVEL` and `owner_playtest_eligible=false`. Final seed
selection must reproduce every claimed route using visible public actions.
The current-main two-seed smoke covered 22 of 55 first-visit scenario
assignments and found a Vault Drop cabinet; the retained report is
`.tmp/playtest06_2/catalog_probe_smoke.json` with SHA-256
`CC665A3F8BE64A620BC0120237B8ABD2B718A86F28A3E3F263297FA75A480CC3`.
Those are discovery results, not playtest passes.

## Dependency/status snapshot at current main

This is a transcription of the active board at main
`9b52c27ada01b0048bd938908b9bcae701d93ec6`, not an acceptance decision by this
prestage lane.

| Dependency or gate | Board state at `9b52c27a` | What current main establishes | What still blocks final seed promotion |
| --- | --- | --- | --- |
| `depth06_1` | DONE | 55 scenario identities and the depth release gate are accepted. | `env06_8` is changing their owner-reported presentation consequences. |
| `game06_8` | DONE | All eleven games and Showdown are accounted for with the recorded exact-tree gate. | Natural named player routes still need final-tree verification. |
| `world06_7` | DONE | Crew/world depth gate is accepted. | End-to-end Crew/heist/Turn/victory routes remain integration/playtest work. |
| `audio06_1` | DONE | Shared surface SFX route is accepted; production music is explicitly absent. | Handoff must disclose the absent production music. |
| `pusherv3_11` | DONE | Pusher program has no recorded product blocker before human playtest. | Three defining machine routes still need named final-build player seeds; perf must retain native solver proof. |
| `teach06_2` | DONE | `FIRST-NIGHT-ACE-17` is accepted for the guided tutorial/orientation claim. | TUT-N17 and broad owner comprehension remain human-only; tutorial evidence is not major-route evidence. |
| `env06_8` | IN_PROGRESS | Owner regression is claimed and isolated to the parallel environment lane. | Final scenario/archetype seed expectations cannot freeze before its landed evidence. |
| `balance06_1` | DONE (partial accepted scope) | The original opt-in cross-system harness is landed. | Ordered follow-on distributions/600k pusher EV/findings are still unreviewed outside main and must be accepted or explicitly dispositioned. |
| `integ06_1` | TODO on board; substantial branch work is PARTIAL | Historical 0.5 migration and one maximal composition run are recoverable from its branch. | Mid-0.6 saves, exhaustive composition, strict native/Web terminal soaks, failures, all victories, and final-tree broad suite. |
| `perf06_1` | IN_PROGRESS | Aggregate/platform tooling and fail-closed pusher backend checks are on main. | Binding final matrix waits for `integ06_1`, `env06_8`, and a quiesced candidate. |
| `playtest06_2` | TODO | Intake prestage exists. | Dependency rewrite, final named seeds, playtest script, and exact-build evidence. |
| `playtest06_1` | TODO | Original hard rules remain authoritative. | Must wait for explicit refreshed dependencies and every final gate; only then build and hand off locally. |

Consequently, no seed presently qualifies as a final owner-route seed.
`FIRST-NIGHT-ACE-17` is usable now only under its narrower already-accepted
tutorial/orientation claim. That is the only named seed whose stated purpose
does not depend on environment, performance, or integration finalization.

## Freeze-time requirements matrix

| Requirement | Recovered candidate/evidence | Freeze-time action | Current state |
| --- | --- | --- | --- |
| Every archetype | Catalog probe enumerates generated nodes. | Prove natural player reachability and record route per archetype. | PENDING |
| Representative scenarios and branches | Catalog probe can minimize discovery seeds; env06_8 owns final authored scenario presentation. | Owner defines the representative set after env freeze; exercise each material branch and aftermath publicly. | PENDING ENV FREEZE |
| All eleven games | Manifest contract derives the live game catalog. | Enter, act, settle, and exit each game on the exact owner build. | PENDING |
| Three pusher machines | Catalog probe reads generated `variation_id`; performance lane now rejects fallback backends. | Prove Quarter Falls, Jackpot Ridge, and Vault Drop through their defining public goals on the frozen native/Web candidate. | PENDING PERF/PUSHER FREEZE |
| Crew recruitment through `inner_circle` | Integration branch contains production selectors and eligibility probes. | Produce a short public route and replay it without hidden-state injection. | PENDING INTEG FREEZE |
| Both heist plans | Integration terminal producer is recovered but partial. | Prove each plan's entry, success, abort/failure, cleanup, and save boundary. | PENDING INTEG FREEZE |
| Turn fires/no-fire | Strict integration producer retains hidden authority. | Supply paired public-action seeds without exposing hidden state in the owner script. | PENDING INTEG FREEZE |
| Three Cass endings | No final current-tree owner routes recovered. | Verify three named public routes and terminal profile handoff. | PENDING INTEG/BALANCE FREEZE |
| Two non-crew victories plus crew victory | Terminal producer exists; partial report says runtime matrix remains. | Run native/Web terminal soak and translate each proof into a player-followable route. | PENDING INTEG FREEZE |
| Crew-ignoring control | Historical A/B candidates recovered. | Re-prove exact no-op authority on final tree, then select one public owner route. | PENDING INTEG FREEZE |
| Numbers, Sweep, delivery | Maximal composition covers one real Sweep/delivery composition only. | Add ordinary/failure/revisit routes and all required Numbers/delivery branches. | PENDING INTEG FREEZE |
| Save boundaries | Maximal composition proves one earlier L3/delivery round trip. | Re-run mid-heist, mid-delivery, mid-hand, mid-layer, mid-scenario, and terminal on exact tree. | PENDING INTEG FREEZE |
| Performance and liveness context | Current main contains the aggregate performance gate work. | Consume the final accepted report; do not substitute this prestage for a platform measurement. | PENDING PERF ACCEPTANCE |
| Balance context | `balance06_1` work is explicitly unreviewed. | Wait for accepted findings/freeze; record known-rough outcomes without tuning in playtest closeout. | PENDING BALANCE ACCEPTANCE |

## Handoff boundary

The final playtest lane may promote this work only after environment,
integration, performance, pusher, and balance inputs freeze. It must preserve
the distinction between three kinds of evidence:

1. **Catalog discovery** says what a deterministic generated world contains.
2. **Headless production-action proof** says a system can traverse a route
   without state injection.
3. **Verified owner route** says a person can follow the documented visible
   actions on the exact build they receive.

Only the third can satisfy the final named-seed handoff. Until then, all rows
remain candidates and both playtest board rows remain open.
