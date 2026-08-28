# fix06_9 closure replay intake

Status: **UNREVIEWED / BLOCKED**
Purpose: pre-stage the evidence intake for the one permitted closure replay. This document is not a review verdict, gate result, Web run, acceptance claim, or completion claim.

## 1. Frozen custody and lineage

The replay must preserve these immutable identities:

| Role | Commit | Tree / relationship | Status |
| --- | --- | --- | --- |
| Green main base for this intake | `00ee744fa6269e8a7eb34f67b2659f32d55febaa` | tree `8ae1554fd50fba705246bbe4da21ef28adead8af` | VERIFIED identity only |
| Accepted fix06_9 evidence head | `f6a06d5feeb8c132fa69cc7e19a3732b7c85be3c` | tree `86085f88e95602aa5a68240f82ac77b8a06a23a3`; parent `1b1c509cda1bb24c734f1888595c4322fd70823e` | VERIFIED identity only |
| fix06_9 landed merge | `112cb02d56da87bfc35dac79ce98ea376d3f4624` | tree `86085f88e95602aa5a68240f82ac77b8a06a23a3`; parents `87f8622229bdc54c8a11dd7940fb426ae33fa5b7` and `f6a06d5feeb8c132fa69cc7e19a3732b7c85be3c` | VERIFIED: landed unchanged by identical tree |
| Preserved first shipped-Web red source | `54e6398a151d0e9a095ebba5ae99d17a7d99f5e9` | tree `5ed9e2de8fab02999b331680b43db729170d08dc`; parent `b80fe9e10be5d63cdce514c564b08691f0b3d4df` | VERIFIED identity; RED result retained |
| Retained fix06_13 locked red source | `c914546f0a6e9e2a0728b593c1c51e166c4a16ad` | tree `bf4bac4319a7c1233fbf3634f889be18cddb9831`; parent `1f879107b813bfa8014036a9c077fce77f27c033` | VERIFIED identity; RED result retained |
| Accepted fix06_13 implementation ancestor | `7ec148e4d9a6096627fa26e1afee508e5b1c0b25` | integrated by the semantic integration below | VERIFIED identity only |
| fix06_13 review handoff | `718af3da7176abfaec9f9dbc10884454298a9872` | second parent of the integration below | VERIFIED identity only |
| fix06_13 current-main semantic integration | `62d45c2e390be815cc94b732b9930b37ff9a543c` | tree `9b6a79948fd07b54e9f17c92e7f76e74c474a8a7`; parents `00ee744fa6269e8a7eb34f67b2659f32d55febaa` and `718af3da7176abfaec9f9dbc10884454298a9872` | UNVERIFIED pending Integrator acceptance and required gates |

The accepted-to-landed tree equality proves only that the accepted fix06_9 payload landed unchanged. It does not make a later replay green and does not discharge any closure criterion.

The accepted evidence history is preserved as:

1. `11deb5f331851970cb916e249ddac05156d25fee` — claim row.
2. `5936c58a11d6497a242012f9befe679fc9626046` — add shipped-cap probe.
3. `b80fe9e10be5d63cdce514c564b08691f0b3d4df` — fail closed.
4. `54e6398a151d0e9a095ebba5ae99d17a7d99f5e9` — seed authoritative pusher session.
5. `1b1c509cda1bb24c734f1888595c4322fd70823e` — make Web evidence authoritative.
6. `f6a06d5feeb8c132fa69cc7e19a3732b7c85be3c` — route shipped Web performance red.
7. `112cb02d56da87bfc35dac79ce98ea376d3f4624` — land the accepted tree unchanged.

## 2. First shipped-Web red: immutable evidence

This result remains red. It must not be overwritten, relabeled, or discarded.

### Execution identity

- Source: `54e6398a151d0e9a095ebba5ae99d17a7d99f5e9`.
- Host: `DESKTOP-1950ULQ`.
- Browser: Chrome `151.0.7922.174`, headless.
- Viewport: 1280 x 720, device-pixel ratio 1.
- CPU throttle: 4.
- Profile: cold.
- Export: fresh Web export.
- Solver: single-threaded Web native solver.
- Export aggregate SHA-256: `0EB384022F02D3889EBD2B022F959E3F4223310B901BF21A101501934D29E2F6`.
- Raw report: `.tmp/fix06_9_runtime_54e6398a/web_coin_pusher_first_actual.json`.
- Raw report SHA-256: `F0E0E9B5D3644F7F46EF2AF765130150BA65966A7585FBBE875B7347E389F715`.
- Summary SHA-256: `C37473DAE93DF456E0DACC25E65AB6C3A3F2CD3757CBC2E3454E8D315C7AAC88`.
- Ready time: 20,536 ms against a 20,000 ms limit.

### Measurements in milliseconds

| Phase | Frame p95 | Draw p95 | Synchronous resolve |
| --- | ---: | ---: | ---: |
| Settled idle | 144.142 | 53.865 | n/a |
| DROP | 144.035 | 54.550 | 68.300 |
| Carriage / hole | 142.143 | 52.380 | 45.390 |
| Skill stop | 145.250 | 52.400 | 91.355 |
| Skill release | 142.577 | 53.080 | 54.985 |

COLLECT and reduced behavior did not execute because of two evidence defects. The accepted remediation at `1b1c509cda1bb24c734f1888595c4322fd70823e` reinstalls authoritative exact 300-origin fixtures and adds conservation checks. Its console policy permits only the known AudioContext autoplay warning and rejects hostile or unclassified messages. That remediation did not authorize erasing or rerunning the first result.

## 3. Retained fix06_13 locked red: immutable evidence

This locked result also remains red and must remain separately attributable.

### Execution and artifact identity

- Source: `c914546f0a6e9e2a0728b593c1c51e166c4a16ad`.
- Evidence directory: `.tmp/fix06_13_locked_c914546f_actual_1`.
- Ready time: 20.518 s.
- Report SHA-256: `601F1E9FB4E55A8226962BD4504B954B0AFD70FCE76F485DD5B5DCB03F879C25`.
- Summary SHA-256: `64E75F36E5E4730FEE8E6011C8C94D27AA3A1A0F1C11B29C75CDDF0CB2A45E56`.
- Fresh export SHA-256: `4821DE90F7266EBD48FE30345D404AEE00B2B0D879108A05C8898379F7DE627A`.
- PCK SHA-256: `08AF27F58466F24FD851518B76F7DFA881559220340195A4B369F1B4193A52D9`.
- Web native component SHA-256: `04D41797748BBECD308A761DF3895311CC3A085ABE86580CF1226BAA0ADC2F47`.
- Server stdout SHA-256: `89CA2C9E0F8BE46B63E6E93DA163B6AEB91A67D7AB7A272C8278629E10FEE83B`.
- Server stderr SHA-256: `70BEBB6DFCF9E8433EFFF62020097E383BF79207772D8DBD1E631558004AE50A`.

### Measurements in milliseconds

| Phase | Frame p95 | Draw p95 | Synchronous resolve |
| --- | ---: | ---: | ---: |
| Settled idle | 80.447 | 35.415 | n/a |
| DROP | 127.022 | 31.755 | 35.705 |
| Carriage / hole | 84.893 | 32.415 | 6.420 |
| Skill stop | 83.048 | 29.945 | 6.585 |
| Skill release | 90.578 | 34.300 | 6.600 |
| COLLECT | 88.555 | 30.375 | 10.870 |
| Reduced behavior | 75.153 | 29.880 | n/a |

Additional retained failures:

- Idle redraw count was 7, below the floor of 8.
- COLLECT tray count/value was 2/2 after a starting count/value of 1/3.
- Reduced-mode reinstall produced 296 bodies with zero presentation redraw.
- No same-head rerun is permitted.

## 4. Canonical native and Web identity requirements

The historical accepted native supply identity is:

- Backend: `native_v3`.
- `.gdextension` SHA-256: `72EE625D61257DCBD65400E57F39077EADEDD3C265C25C83F68BC2F8EFBC9861`.
- UID SHA-256: `F606704CBF202403DE82CBFD19B4160889346206EAD1D96E86C6A452B0C3A06A`.
- Each Windows debug DLL name SHA-256: `1052770B5A96057928F67A72159D8A31B89D5591EAB7A64F07F8FCAE458E83F5`.

These historical values establish custody; they must not be assumed to be the identity of a future build. Before the one permitted replay, the Integrator must record and independently verify the exact current:

- source commit and tree;
- native backend and platform;
- native addon binary paths, names, sizes, and SHA-256 values;
- `.gdextension` and UID paths and SHA-256 values;
- fresh Web export aggregate SHA-256;
- PCK SHA-256;
- Web native component / module SHA-256;
- export inventory and all shipped native-component identities;
- host, browser/version, mode, viewport, DPR, CPU throttle, profile, fixture seed, and fixture-body source;
- raw report, summary, server stdout, and server stderr paths and SHA-256 values.

The first Web run's export aggregate is known, but an individual Web module hash was not recorded in its accepted prompt. This intake does not invent one. The new replay must supply exact component hashes from the actual fresh export.

## 5. Exactly-one closure replay rule

The fix06_13 integration `62d45c2e390be815cc94b732b9930b37ff9a543c` has not, by this intake, been reviewed, gated, accepted, or landed. Its pending locked result is not yet evidence.

Exactly one new locked Web run may be consumed only after all prerequisite decisions are affirmatively recorded by the Integrator:

1. The accepted fix06_13 candidate has been semantically integrated onto current main.
2. The exact integration head has passed the required current-main gates.
3. Independent review has accepted that exact integration head.
4. fix06_14 has landed first.
5. fix06_16 has landed before the new run.
6. The canonical native and Web identities in section 4 have been captured for that exact build/export.

Until then, replay status is **BLOCKED**. The run must not be consumed early, repeated after a red result, substituted with a same-head rerun, or silently replaced. If the one run is red, preserve every artifact and route the red result without rerun unless a separately accepted change or cap decision explicitly authorizes a later run.

## 6. Exact closure criteria

Closure requires all of the following on the exact accepted integration and exact fresh export:

1. A maintained fail-closed Web evidence path in the existing telemetry and Web-smoke architecture.
2. Deterministic installation of the same 300-body production fixture used by native evidence, or an exactly equivalent shipped cap, on the real cabinet.
3. A settled-idle sample recording frame p95 and draw p95 with strictly increasing liveness.
4. Accepted and evidenced DROP, carriage/hole, skill-stop, skill-release, and COLLECT transitions.
5. Frame and draw p95 for each required transition, plus synchronous resolve time where that operation owns synchronous resolution.
6. Body count, backend, platform, fixture seed, fixture source commit, export identity, and all required component hashes.
7. Normal and reduced behavior evidenced without a frozen simulation.
8. Idle frame p95 at or below 16 ms and idle draw p95 at or below 5 ms.
9. Active frame p95 at or below 22 ms and active draw p95 at or below 7 ms.
10. Synchronous resolve at or below 16 ms.
11. A zero idle draw result is acceptable only with nonzero, strictly increasing liveness; `0.000` idle draw without that proof is red.
12. Every first result, host, browser, artifact, and hash is preserved. There is no rerun until a green-making change or an explicit cap raise has been accepted.
13. Evidence-only scope: no gameplay, solver, renderer, tuning, RTP, EV, payout, odds, wager, RNG, schema, migration, golden, or cap changes.
14. Validation, the focused tool/unit proof, native performance nonregression, fresh Web export and inventory, and the supported Chrome new plan are green.
15. Exact native/Web parity is proven for the required fixture and operations.
16. Native-addon supply and hash verification is complete.
17. Implementation and evidence receive independent review.
18. The accepted net payload lands before `pusherv3_11` continues.

Any missing field, noncanonical build identity, hostile or unclassified console output, absent operation, absent liveness proof, missing artifact, threshold miss, conservation failure, or dependency failure is red or blocked; it is not an invitation to reinterpret the criterion.

## 7. Intake verdict matrix

| Item | Current intake verdict | Required transition |
| --- | --- | --- |
| Accepted fix06_9 evidence identity | VERIFIED identity only | Preserve unchanged |
| Accepted fix06_9 payload landed unchanged | VERIFIED by identical tree | Preserve custody |
| First shipped-Web result | RED | Preserve; do not rerun/overwrite |
| Retained fix06_13 locked result | RED | Preserve; do not same-head rerun |
| fix06_13 semantic integration `62d45c2e` | UNVERIFIED | Integrator review and exact-head gates |
| fix06_14 dependency | BLOCKED / UNVERIFIED | Record landed identity |
| fix06_16 dependency | BLOCKED / UNVERIFIED | Record landed identity before replay |
| Current canonical native supply | UNVERIFIED | Build/supply/hash exact artifacts |
| Current canonical Web export | UNVERIFIED | Fresh export/inventory/hash exact artifacts |
| Exactly-one locked replay | BLOCKED / NOT RUN | Consume only after every prerequisite |
| Web performance closure | BLOCKED / UNVERIFIED | Meet every criterion in section 6 |
| `pusherv3_11` continuation | BLOCKED | Accepted net payload must land first |

No line in this document grants acceptance, authorizes a gate or Web execution, changes a cap, closes fix06_9, or claims program progress.
