# Back Alley travel and loan acceptance

Tasks: **BTH061-ALLEY-TRAVEL** (alias BTH-MOTEL-BACK-ALLEY-TRAVEL-001)
and **BTH061-ALLEY-LOAN** (alias BTH-BACK-ALLEY-LOAN-SOFTLOCK-001).
Implementation: [`29ba65a8531e3d260574ddb217f72d36b3df98df`](https://github.com/erikjpet/BeatTheHouse/commit/29ba65a8531e3d260574ddb217f72d36b3df98df).

On 2026-11-04 the owner confirmed that the original saves were gone after
continued testing and declined further exact-save checks. Acceptance therefore
uses the already captured R03 fixture, reconstructed warm/cold lender cases and
independent acceptance. No original-save check or owner handoff remains a
requirement for these tasks. Recovery of the owner's exact loan-softlocked save
was never observed and is not claimed.

## Failure and correction

The captured R03 Motel-to-Back-Alley action was rejected before payment because
restored historical events lacked authenticated slot bindings. A detached
historical proof restored consumed frozen events but omitted their rectangle
hints; later world-sequence recomposition rebuilt the manifest without its base
bindings. The fix restores hints only for existing frozen authenticated events
and publishes the composed manifest and bindings together. Expected inventory
digests, fixed-slot authority and tamper rejection remain enforced.

The reported post-loan generic icons and unusable Leave match the renderer's
empty-interactable-catalog fallback. The loan/service publication boundary could
commit cash/debt even when final room publication failed. It now rejects that
candidate before durable aliases are stored. Removing only this guard reproduced
successful loan commitment despite an intentionally rejected final publication;
the fixed path rejects and preserves the complete serialized state.

No viewport, portrait, touch/focus, animation scheduling, loan terms or audience
changes form part of this fix or its acceptance closeout.

## Focused evidence

The retained local receipt is
`C:/Users/theep/Documents/Codex/2026-11-03/task-6/evidence/back-alley-combined-receipt.json`.
Its referenced receipts and custody hashes are retained locally. Saves, profiles
and authority companions are not committed or uploaded.

| Case | Passing assertions | Scope |
| --- | ---: | --- |
| Captured R03 first-attempt travel | 46 | Official Continue, Map, one confirmation, strict room controls, one fare/risk, Save and tamper rejection |
| Captured R03 process-cold Continue | 12 | No repeated travel; cash, Heat, clock, RNG, duties and missed history persist |
| Explicit synthetic suppression sibling | 41 | World-only Mags fallback, room controls and Save; not the unmodified player's state |
| Resolved-event fixture | 26 | Consumed offer, world registration, Save/reentry and tamper rejection |
| Crew / Fence Night | 32 warm + 14 cold | Normal loan interaction and room persistence |
| Street Lender / Fence Night | 32 warm + 14 cold | Normal loan interaction and room persistence |
| Crew / no primary scenario | 39 warm + 14 cold | Authored offer consumed once before loan; room persistence |
| Street Lender / no primary scenario | 39 warm + 14 cold | Authored offer consumed once before loan; room persistence |
| Total | **323** | Focused assertions, not a full-suite qualification |

Loan fixtures use the connected host's Select/Use path and TalkDock's armed,
confirmed acceptance. They check populated renderer/catalog joins, strict room
proof, enabled Leave opening the normal map, exact quoted economy, no replay from
a stale callback, official Save and a separate-process cold Continue. Crew grants
70 cash and two duties without cash debt; Street Lender adds the quoted 25 cash and 28
repayment. Both lenders preserve the complete state when final publication is
forced to reject. Tests use isolated storage and bounded Job ownership; owned
processes were zero at release.

The captured R03 copy settles exactly one quoted 4 fare and its genuine 8
shakedown result, ending at 148 cash / Heat 21 with two duties and no package.
The failed original attempt and missed delivery are not replayed or paid out.
The capture preserved the original closed profile and companions; only disposable
copies were opened. Persistence comparison retains all gameplay values through
the JSON wire representation and production debt normalization. Only the
explicitly modified suppression sibling compares the full private Crew payload
hash instead of its challenge-context-dependent capsule; official Save/Continue
still authenticates the real capsule. The genuine R03 case retains the opaque
capsule comparison.

Reproduction entry points, with the existing isolated wrappers and environment
recorded in the local receipts:

```powershell
.\run_actual_pair.ps1 -Label actual-r03-final-main
.\run_loan_pair.ps1 -Lender the_crew -Scenario back_alley_fence_night -Case crew-fence-final
.\run_loan_pair.ps1 -Lender street_lender -Scenario back_alley_fence_night -Case street-fence-final
.\run_loan_pair.ps1 -Lender the_crew -Scenario __none -Case crew-none-final
.\run_loan_pair.ps1 -Lender street_lender -Scenario __none -Case street-none-final
```

## Deployment evidence

Existing watcher promotion: **2026-11-03 22:20:26 UTC**,
`f3a2f0b1930813a34553054c966c965a5ee13bff`,
tree `8fdcea8b901b75b4045c591f090b074337ae50d3`.
This contains the implementation commit. Exact served BUILD/manifest/provenance,
archive identity, NEXT/current and generated LAN redirect agree. Six payload
HEAD checks pass, including WASM MIME, and the served PCK hash matches provenance.
A fresh disposable browser reaches the menu displaying
`0.6.0-dev+f3a2f0b19308`, with four payloads returning 200 and no page errors.
The expected pre-gesture AudioContext warning is retained. Browser context and
Job close with zero owned processes. Direct LAN TLS was not qualified; local
HTTP and the generated LAN redirect were checked without disabling trust.

These are native changed-behavior checks and exact-build Web startup evidence;
they do not claim visual Web loan acceptance or the unavailable owner's save.
Stable/itch and the existing hosting audience are unchanged.

## Independent closeout

On 2026-11-04 a separate reviewer accepted the frozen implementation/release
evidence, including all 198 loan assertions, the counterfactual, captured-R03
adjacent coverage and exact f3 deployment receipts. No blocking findings remain.
That review did not access a player profile or rerun the frozen fixtures.

A different worker independently ran the existing loan pair on current main
`ecdccee418c2297a0fb864d00c902a4c159dfd5c`. This focused recheck was justified
because subsequent Crew work had changed composed room finalization. The command
was:

```powershell
.\run_loan_pair.ps1 -Lender street_lender -Scenario back_alley_fence_night -Case independent-closure-20261104
```

**32/32 warm and 14/14 cold pass.** Normal rendered host Select/Use and visible
TalkDock arm/Confirm grant exactly 25 cash with principal 25 / payoff 28. The
catalog contains 13 valid controls before, after and cold; Leave works in both
processes, and complete normalized persistence fingerprints match. The rejected
publication preserves the full serialized run. A stale callback cannot replay
the loan. This fixture generated no eligible Back Alley Offer, so no consumption
is claimed for this additional pair. Both existing bounded jobs exit 0, do not
time out, and leave zero owned processes. No source edits or original-profile
access were needed. The receipts are
`evidence/loan-independent-closure-20261104-{warm,cold}-result.json`, with matching
Job `.json` and command/output `.log` files in the established local task root.

This is **46 additional current-source native assertions**, separate from the
323 historical assertions and f3 Web startup. The two stable task IDs are closed
under the owner's revised criteria with the implementation commit associated.
The exact-owner-save limitation remains factual; no outstanding request, hold or
acceptance dependency remains for it.
