# pusherv3_11 Immutable Replay Manifest Prestage

Status: **UNREVIEWED / BLOCKED / NO CLOSURE CLAIM**

Prestage base: `00ee744fa6269e8a7eb34f67b2659f32d55febaa`.

This docs-only manifest defines what an independent `pusherv3_11` replay must
consume and preserve. It does not claim the row, accept a dependency, run a
gate, rerun a retained result, change physics, or modify product/test/board
state. Every unfilled requirement fails closed.

## Preserved audit provenance

| Record | Exact identity | What it proves | Intake verdict |
| --- | --- | --- | --- |
| Static audit start | `554773c6493d6740fb29034e19abda4b23198a94` | `pusherv3_10` dependency was merged into the historical audit branch; no committed closure report exists in that tree | INCOMPLETE — NOT CLOSURE |
| Rejected claim head | `8541f6432a3e26c4a7fb81028b8ae846874c5f33` | Board/ledger/work-log claim mutation only; independent Review Pool rejection is binding | REJECTED — NOT CLOSURE |
| Preserved uncommitted audit account | Board/work-log record at base | Report was explicitly IN PROGRESS with EV, determinism, parity, lifecycle, performance, broad-suite, and visual work pending | NON-IMMUTABLE POINTER ONLY |

No child-row completion note, historical prompt summary, uncommitted report,
or branch name may replace an immutable exact-head report and raw evidence.

## Hard replay preconditions

The closure replay may start only when all rows below are populated with exact
accepted and landed identities.

| Precondition | Required immutable value | Current value | Verdict |
| --- | --- | --- | --- |
| Closure candidate | Exact clean current-main head containing every accepted dependency | TBD | BLOCKED |
| `pusherv3_10` | Accepted and landed head/tree | TBD in final replay manifest | BLOCKED |
| `fix06_13` accepted implementation | Exact independently accepted current-main integration head | Off-main historical implementation `7ec148e4d9a6096627fa26e1afee508e5b1c0b25` and review/docs `718af3da7176abfaec9f9dbc10884454298a9872` are not landed output | BLOCKED |
| `fix06_13` landed output | Exact main merge plus post-land qualification | TBD | BLOCKED |
| `fix06_13` one locked Web result | Exactly one new locked shipped-Web run from the accepted landed output, pass or red, with all identities | TBD — must not reuse historical red as qualifying output | BLOCKED |
| `fix06_8` tooling evidence | Immutable exact evidence and artifact identities | `1f0595af567494f1c7d69f319a1ee8e4bead26dc` is tooling-only retained red evidence | RED / DECISION REQUIRED |
| `fix06_24` disposition | Accepted owner decision plus authorized implementation/contract result where applicable | Option-neutral packet `d2a860da7f0e9a47830bb37a6986c629cf234c9a` is UNREVIEWED and contains no owner selection | BLOCKED |
| Native identity | Built native source head, backend, DLL hash, Godot hash | TBD for closure candidate | BLOCKED |
| Web identity | Fresh export hash, PCK, WASM/native module, harness/browser/profile identity | TBD for closure candidate | BLOCKED |

`fix06_13` cannot be represented as accepted/landed by transplanting its
historical off-main heads or by citing a descendant that did not independently
review the semantic current-main integration. Its one new locked run is
consumed exactly once and preserved whether green, red, failed, or timed out.

## fix06_8 and fix06_24 fail-closed boundary

Exact `fix06_8` evidence commit
`1f0595af567494f1c7d69f319a1ee8e4bead26dc` is an empty
evidence-preserving commit. Its immutable message binds:

- actual-GL manifest SHA-256
  `AFA40DF473C264D87A69C7D9BD38D3823DCCFC9B2E5E7FDC6A5D0B13D2EC1DF8`;
- native Windows debug DLL SHA-256
  `56B26FF9218EB5BCDB605418AB6FA6CF215CBB741DF8CB346170DA335C34165A`;
- all fixed-trace setup predicates except qualified adjacency passed;
- no qualified adjacent pre-existing platform coin was present at the tracked
  first-support event; and
- movement was not demonstrated; no rerun or search occurred.

This is tooling-only evidence of a retained red, not proof of Plan 9.4 movement
and not a physics acceptance. It may not authorize seed/control/nozzle/timing
search, broaden adjacency, or substitute visible motion for paired exact-body
observation.

The unresolved `fix06_24` owner decision must choose and fully execute one of
the preserved dispositions: authorize a bounded product-physics remediation
that reliably creates qualified topology and proves exact-neighbor movement, or
explicitly revise/cut Plan 9.4 and reconcile every dependent contract and claim.
The UNREVIEWED packet `d2a860da...` selects neither. Until an accepted owner
record and its required downstream work exist, Plan 9.4 and `pusherv3_11`
remain blocked.

## Retained Web performance history

Historical reds remain append-only context. They can never be deleted,
overwritten, renamed green, or used as the required post-land `fix06_13` run.

### First actual shipped-Web red

- measured source: `54e6398a151d0e9a095ebba5ae99d17a7d99f5e9`
- host/browser: `DESKTOP-1950ULQ`, Chrome `151.0.7922.174`, headless
- viewport/profile: 1280×720, DPR 1, CPU throttle 4, cold profile, fresh export,
  single-threaded Web native solver
- export aggregate SHA-256:
  `0EB384022F02D3889EBD2B022F959E3F4223310B901BF21A101501934D29E2F6`
- report SHA-256:
  `F0E0E9B5D3644F7F46EF2AF765130150BA65966A7585FBBE875B7347E389F715`
- summary SHA-256:
  `C37473DAE93DF456E0DACC25E65AB6C3A3F2CD3757CBC2E3454E8D315C7AAC88`
- ready: 20.536s / 20.000s cap
- idle frame/draw: 144.142/53.865ms / 16/5ms caps
- DROP frame/draw/resolve: 144.035/54.550/68.300ms / 22/7/16ms
- carriage frame/draw/resolve: 142.143/52.380/45.390ms
- skill stop frame/draw/resolve: 145.250/52.400/91.355ms
- skill release frame/draw/resolve: 142.577/53.080/54.985ms
- COLLECT/reduced: not executed due retained evidence defects
- verdict: RED, RETAINED

### Sole accepted-head locked historical red

- consumed head: `c914546f0a6e9e2a0728b593c1c51e166c4a16ad`
- report SHA-256:
  `601F1E9FB4E55A8226962BD4504B954B0AFD70FCE76F485DD5B5DCB03F879C25`
- summary SHA-256:
  `64E75F36E5E4730FEE8E6011C8C94D27AA3A1A0F1C11B29C75CDDF0CB2A45E56`
- fresh export SHA-256:
  `4821DE90F7266EBD48FE30345D404AEE00B2B0D879108A05C8898379F7DE627A`
- PCK SHA-256:
  `08AF27F58466F24FD851518B76F7DFA881559220340195A4B369F1B4193A52D9`
- Web native SHA-256:
  `04D41797748BBECD308A761DF3895311CC3A085ABE86580CF1226BAA0ADC2F47`
- server stdout/stderr SHA-256:
  `89CA2C9E0F8BE46B63E6E93DA163B6AEB91A67D7AB7A272C8278629E10FEE83B` /
  `70BEBB6DFCF9E8433EFFF62020097E383BF79207772D8DBD1E631558004AE50A`
- ready: 20.518s
- frame/draw/resolve milliseconds: idle 80.447/35.415/—; DROP
  127.022/31.755/35.705; carriage 84.893/32.415/6.420; stop
  83.048/29.945/6.585; release 90.578/34.300/6.600; COLLECT
  88.555/30.375/10.870; reduced 75.153/29.880/—
- retained evidence reds: idle redraw 7 below floor 8; COLLECT terminal tray
  count/value 2/2 after 1/3; reduced reinstall observed at 296 bodies with zero
  presentation redraw
- verdict: RED, RETAINED; no same-head rerun

### Timeout/setup/error retention ledger

The final replay manifest must import the canonical ledger and work-log entries
for every reproduction, profile, rejected head, disk-full/setup failure,
missing-tool invocation, browser/server lifecycle timeout, orphan-process event,
and locked red. At minimum it must retain:

- `fix06_14` setup `actual_1`, which failed before export/browser because
  `GODOT_BIN` was absent and produced no report;
- the consumed `fix06_14` shipped-Web red(s), including exact report/summary,
  export/Web-native/server hashes and all unchanged `fix06_13` timing reds;
- the 904-second outer-orchestration overrun after a completed report, including
  the exact orphan PID/port disposition, without reclassifying the report or
  the lifecycle defect; and
- the post-land disk-full environmental red and its one corrected retry, both
  with exact source and artifact hashes.

| Historical attempt | Source/head | Artifact hashes | Raw outcome | Classification | Preserved |
| --- | --- | --- | --- | --- | --- |
| First shipped-Web | `54e6398a...` | Bound above | RED | Product performance | REQUIRED |
| Accepted-head locked | `c914546f...` | Bound above | RED | Product performance plus evidence contradictions | REQUIRED |
| Remaining canonical ledger attempts | TBD from accepted ledger import | TBD | RED/FAIL/TIMEOUT as recorded | Must remain exact | BLOCKED |
| Required post-land `fix06_13` locked run | TBD | TBD | Preserve first result | Binding new result | BLOCKED |

No timeout can be silently converted to a gate failure or pass; distinguish
completed inner reports from outer orchestration/lifecycle outcomes.

## Exact native/Web identity schema

Every replay artifact must carry:

| Identity class | Required immutable fields |
| --- | --- |
| Source | closure head/tree, main parent, dependency merge heads, clean status |
| Godot | executable path, version, executable SHA-256, export-template identity |
| Native Windows | native source head/tree, backend id, configuration, DLL path/SHA-256, loader-reported identity |
| Web | fresh export aggregate, PCK, WASM, JavaScript, Web native module and archive SHA-256; export preset hash |
| Browser | name/version/binary hash, headless/headed, viewport/DPR, CPU throttle, profile/cache state, flags |
| Harness | script/tool heads and hashes, command, environment, fixture/schema version, locked caps/sample lengths |
| Host | host id, OS/build, CPU/GPU/RAM, quiescence/process inventory, timestamps/timezone |
| Inputs | exact seed list, 300-origin fixture identity, machine definitions, action/input trace hashes, save provenance |
| Outputs | raw report/summary/stdout/stderr/server logs/captures and SHA-256, exit/timeout/lifecycle status |

Native/Web parity is inadmissible if either side's source, native backend, input
trace, fixture, or output identity is missing or mismatched.

## Hostile caller-authority paired observers

Every authoritative mutation must be observed from two independent surfaces:
the caller-visible command/result/receipt and the host-rooted solver/live-session
state before and after. The pair must bind the same request id, machine id,
action, authoritative tick/phase, source balance, body identities, conservation
channels, and settlement receipt.

| Boundary | Accepted observer pair | Required hostile cases | Fail-closed invariant | Verdict |
| --- | --- | --- | --- | --- |
| Paid DROP | caller result + authoritative queue/live bodies | wrong machine/session, stale/replayed request, unaffordable, malformed action, duplicate dispatch | No charge/body/queue mutation on reject; one charge and one tracked body on accept | BLOCKED |
| Carriage/aim | caller result + authoritative control/phase state | unavailable control, stale phase, out-of-range value, replay | No hidden steering or mutation on reject | BLOCKED |
| Skill stop/release | caller result + authoritative motor/puck/phase state | premature/duplicate/stale request, wrong owner | Exactly one accepted transition; banked lock ruling preserved | BLOCKED |
| Nudge | caller result + authoritative force/aim/timing/tell state | insufficient authority/funds, lockdown, replay, invalid target/timing | No force, charge, tell, alarm, or heat mutation on reject | BLOCKED |
| Alarm/lockdown | caller fact/receipt + authoritative alarm/node-memory/heat state | duplicate threshold event, reload/revisit replay, unauthorized clear | One alarm, one heat spike, persistent node memory, no forced exit | BLOCKED |
| COLLECT | caller payout/receipt + authoritative tray/gutter/collected/cup/bankroll channels | empty tray, duplicate/replay, wrong cabinet/session, interrupted exit | Exact conservation and one payout; no post-window replay | BLOCKED |
| Save/restore | caller save acknowledgement + authoritative settled/transient state | mid-motion save, stale schema, repeated restore, corrupt/mismatched identity | No long settle/freeze, lost stock, duplicated payout, or replayed transient command | BLOCKED |
| Exit/travel/revisit | caller transition + authoritative pile/node/alarm/settlement state | repeated exit, abort during motion, revisit after payout, wrong node | Persistent stock/memory, exactly-once settle, legal return | BLOCKED |

Tests that assert only the caller response or only internal state are not paired
authority evidence. A projection, renderer snapshot, or child note cannot serve
as the authoritative observer.

## Prompt-required closure matrix

Every row requires exact candidate code/data mapping, automated raw evidence,
player-facing capture where applicable, and independent verdict.

| Requirement | Minimum immutable evidence | Verdict |
| --- | --- | --- |
| V3 plan + Amendments 6.1/6.2 | Line-level contract map; geometry/rear-feed implementation and executable proofs | BLOCKED |
| Roadmap Pillar 4 | Universal nudge force/aim/timing, tell ladder, alarm→lockdown/heat/node memory, no forced exit, actual reachability | BLOCKED |
| Three variations | Quarter Falls, Jackpot Ridge, Vault Drop documented mechanics and owner rulings | BLOCKED |
| Banked lock puck | One full 240-tick stroke persistence without motor steering, exact authoritative trace | BLOCKED |
| Plan 9.4 upper-row join | Accepted `fix06_24` disposition and resulting exact proof/contract reconciliation | BLOCKED |
| EV Quarter Falls | 200,000 physical drops; `[0.72, 0.94]`; raw shard/aggregate identities | BLOCKED |
| EV Jackpot Ridge | 200,000 physical drops; `[0.70, 1.08]`; raw shard/aggregate identities | BLOCKED |
| EV Vault Drop | 200,000 physical drops; physical `[0.72, 0.94]`; option value separate | BLOCKED |
| Determinism | 10 seeds, two independent processes, exact checkpoint/combined hashes | BLOCKED |
| Native/Web parity | Exact input and outcome traces for all machines/actions/lifecycle boundaries | BLOCKED |
| Conservation | Drops, nudges, alarms, lockdown, collect, exit-settle, save/restore; paired observers | BLOCKED |
| Transient/settled lifecycle | Mid-play autosave without long settle/freeze; post-drop motion continues | BLOCKED |
| Persistence | Piles, stock, node/alarm memory across save/exit/travel/revisit; no replay/loss | BLOCKED |
| Native performance | Shipped cap, all action windows, raw solver, draw/frame/resolve, liveness/allocation | BLOCKED |
| Shipped-Web performance | Accepted landed `fix06_13` output and its one locked result at unchanged caps | BLOCKED |
| Broad project suites | Project/content validation, Contract, Smoke/Full, Systems, UI, save/accessibility | BLOCKED |
| Visual evidence | All three machines, normal/reduced, opening/contact/exit/nozzle/stack/nudge/alarm/lockdown/collection states; actual GL and independent review | BLOCKED |
| Code health | Dead/superseded/duplicate/orphan/workaround inventory with reference proof; no audit-branch deletion | BLOCKED |
| Board reconciliation | pusher06_2 binding/superseded scope, retired rows, all owner rulings mapped | BLOCKED |

An EV band miss, non-exact parity, unimplemented Pillar 4 requirement, owner
ruling mismatch, unresolved hostile-authority observation, performance red, or
missing identity keeps the row BLOCKED.

## Immutable replay record schema

For each invocation append one record; never edit an earlier attempt:

- monotonically assigned attempt id and purpose;
- exact candidate/dependency/native/Web identities from the schema above;
- pre/post quiescence and process inventory;
- exact command, working directory, environment, timeout, start/end/duration;
- seeds, fixtures, save/profile/cache/warm-up state;
- exit code, timeout and lifecycle status separately;
- raw stdout/stderr/report/summary/capture hashes;
- all observations and failures without filtering;
- locked budget/contract version and any owner decision id;
- independent reviewer and reviewed exact hashes; and
- disposition linking a later attempt without superseding the earlier record.

Reruns require a stated contract reason. “Run until green,” seed searching,
discarding a timeout, changing caps/sample length/fixtures, or replacing a red
artifact is prohibited.

## Current closure state

| Closure input | State |
| --- | --- |
| Accepted/landed `fix06_13` exact output | BLOCKED — ABSENT |
| Its one new locked shipped-Web result | BLOCKED — NOT RUN |
| `fix06_8` Plan 9.4 evidence | RETAINED RED — TOOLING ONLY |
| Accepted `fix06_24` owner decision and consequence | BLOCKED — UNRESOLVED |
| EV/determinism/parity/lifecycle/performance/broad/visual gates | BLOCKED — NOT REPLAYED |
| Hostile caller-authority paired observers | BLOCKED — NOT REPLAYED |
| Exact closure native/Web identities | BLOCKED — CANDIDATE ABSENT |
| Historical reds/timeouts | REQUIRED RETAINED CONTEXT — PARTIAL INVENTORY ABOVE |
| Final `pusherv3_11` verdict | BLOCKED — NO COMPLETION CLAIM |
