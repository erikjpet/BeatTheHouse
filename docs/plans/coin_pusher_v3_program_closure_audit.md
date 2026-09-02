# Coin Pusher V3 Program Closure Audit

Status: IN PROGRESS — exact-tree measurements pending  
Audit row: `pusherv3_11`  
Audit branch: `codex/land06-pusherv3_11`  
Audit base: `59db0882ab4c2713cd0871bc802cf15752e43050`  
Claim commit: `8541f6432a3e26c4a7fb81028b8ae846874c5f33`

## Scope and provenance

This is a genuine audit of the landed V3/fix tree, not a completion claim
derived from the old cross-cutting branch. The historical source commit
`554773c6493d6740fb29034e19abda4b23198a94` is 14 commits ahead and 62 behind
the audit base, with merge base `a0d2b6ff7155484830909728f3051f587dc5dc4d`.
It contains only a static `HELD` ledger start and no closure report or audit
implementation. Nothing from that entangled branch was merged or transplanted;
it remains intact as provenance.

The audit read the V3 machine rework plan and both amendments, the 0.6
simulation plan, roadmap Pillar 4, all archived `pusherv3_1..10` prompts, the
current board and landing ledger, `pusher06_2`, all named production modules,
the export parity runner, the full Coin Pusher Foundation suite, and the shipped
Coin Pusher data and audio manifest.

## Qualified native runtime

The generated, ignored native addon was supplied before the first gate from
`D:\Projects\Beat-The-House-worktrees\land06-fix06_4-postland\addons\coin_pusher_native`.
Source and destination hashes matched for all four files:

| File | SHA-256 |
| --- | --- |
| `coin_pusher_native.gdextension` | `72EE625D61257DCBD65400E57F39077EADEDD3C265C25C83F68BC2F8EFBC9861` |
| `coin_pusher_native.gdextension.uid` | `F606704CBF202403DE82CBFD19B4160889346206EAD1D96E86C6A452B0C3A06A` |
| `coin_pusher_native.windows.template_debug.x86_64.nothreads.dll` | `1052770B5A96057928F67A72159D8A31B89D5591EAB7A64F07F8FCAE458E83F5` |
| `coin_pusher_native_v3_10.windows.template_debug.x86_64.nothreads.dll` | `1052770B5A96057928F67A72159D8A31B89D5591EAB7A64F07F8FCAE458E83F5` |

Godot 4.6 console SHA-256 was
`FC759F9D296FE54F09AB66D41DF6DDD2D278493B0E71109F6688EF029AD271AE`.
The explicit import passed in 46.580s. Native smoke passed in 3.515s with
`native_backend_available=true`, backend `native_v3`, and production parity
payload SHA-256
`17822461D5D650EF381678F414B19D4A143A3E48B68BAB64CFB168B06F66A1BB`.
Every timing below uses this exact build unless a row explicitly says otherwise.

## Contract map

| Requirement | Shipped implementation and proof | Verdict |
| --- | --- | --- |
| One reciprocating platform; corrected extended/retracted face geometry | Authored faces are `43000`/`61000`; solver applies the one moving face and renderer projects the authored platform. Foundation covers face push, nestling, collective ratchet, and the amended geometry. | PASS |
| Rear-fed drop, visible descent, and upper-platform catchment | Each machine authors a rear `drop_board`, five-position Plinko field/nozzle hardware and platform-rooted landing. Foundation covers board projection, bounce/variance, signed release, production jitter, landing classification and visible terminal falls. | PASS |
| Continuous fixed-point physical bodies, not a lane/counter abstraction | `coin_pusher_solver.gd` owns 60 Hz integer bodies, contacts, supports, gravity, ledgers and canonical digest; API selects the exact native/GDScript contract. Rejected V2 mechanics and lattice symbols are asserted absent. | PASS |
| Full-width, played-in, inert opening stock | Shipped openings are 150/150/154 bodies, full-width and settled; the motor remains stopped until the first accepted drop. Foundation covers thirds, topology, overlap, elevation, five historical idle cycles and later activation. | PASS |
| Player-controlled apparatus and atomic tap/hold FIFO | Quarter Falls and Vault use bounded rails; Ridge uses three fixed holes. Shared pointer paths cover mouse, touch, keyboard and controller-equivalent hold phases, focus cancellation, affordability truncation, and 10 coins/sec FIFO cadence. | PASS |
| Physical cup lifecycle and bounded same-nozzle chains | A triggering body is consumed exactly once; 5X enqueues five children through the trigger nozzle. Depth and child caps are authored and asserted. | PASS |
| Stack ruling: only platform supplies horizontal force; supported landing stays carried without spreading supports | Solver support graphs and unilateral platform roots implement the ruling. Foundation covers irregular supports, no horizontal support spreading, bad supported feedback, good bed feedback, and three support topologies. | PASS |
| Skill stop remains physical | Skill stop changes motor target without directly editing body outcomes; release displacement and phase/topology tests cover the production path. | PASS |
| Tray, gutter, ceiling and exact-once collection | Base physical tray value moves to bankroll only on `COLLECT`; separately authored cup instant rewards remain separately accounted direct rewards. Gutters remain losses, and ceiling refusal consumes no money. Foundation covers conservation and refusal UI. | PASS |
| Snapshot/event boundary and presentation batching | Live session publishes compact bodies/events; renderer consumes the surface snapshot, uses one bounded 600-instance batch, depth sorting, interpolation-only presentation and no per-coin nodes. | PASS |
| Dense readable cabinet, feature bodies and audio events | Authored cabinet identities, pile projection, riders/pucks/fragments, motor/impact/slide/metal/tray/gutter/alarm cues and accessibility sync remain present and Foundation-covered. Current visual evidence is listed below. | PENDING visual gate |
| Transient live state separated from settled persistence | `coin_pusher_live_session.gd` restores/compacts the V3 snapshot; autosave readiness avoids long settle; exit alone uses bounded chunked settle. Foundation covers post-drop live motion, save readiness, compact round trip and re-entry. | PASS |
| V2 migration and unrelated-state preservation | The production module migrates V2 once, preserves all three variations and unrelated game state, and does not replay migration/payout on re-entry or reseed. | PASS |

## Pillar 4 and variation map

| Requirement | Shipped implementation and proof | Verdict |
| --- | --- | --- |
| Universal nudge force × aim × timing | The live `resolve_with_context` path accepts tap/shove/slam and left/right/front, applies physical impulses at the current solver phase, charges tolerance, and records the input trace. It is exposed by the normal cheat action and surface controls. | PASS |
| Tell ladder before alarm | `steady` → `cabinet rocks` → `alarm chirps` → `attendant looks over` is derived from durable tolerance/heat, projected visually and emitted through audio events. Decay is tick-based. | PASS |
| Alarm lockdown, heat spike and node memory | Alarm sets the machine lock, stops the motor through live-session configuration, applies heat, and writes durable node-scoped alarm memory. Foundation covers persistence and rumor/staff-watch integration. | PASS |
| No forced exit | Lockdown leaves the player on the cabinet with free `COLLECT`/navigation behavior; no alarm path invokes exit. | PASS |
| Quarter Falls | Rail aiming, hold FIFO, prize riders, physical cup children, nudge/tell/alarm and `[0.72, 0.94]` physical EV contract are shipped. | PENDING fresh EV |
| Jackpot Ridge | Three holes, authored pucks, same-cycle three-bank Ridge Run at rate 2, and armed multiplier lock preservation for exactly one full 240-tick stroke without motor steering are Foundation-covered. `[0.70, 1.08]` physical EV is authored. | PENDING fresh EV |
| The Vault Drop | Rail/fragment physics, nine hidden cells with exactly one RESET, X-Ray-gated truthful peek, stop/start/open flow, town progressive and tray-only cash are Foundation-covered. `[0.72, 0.94]` physical EV is distinct from vault option value. | PENDING fresh EV |

## Economics, determinism and parity

Fresh audit-tree results will replace the pending cells; historical figures are
context only and are not used as acceptance evidence.

| Machine | Documented physical band | Fresh accepted drops | Physical return | Target/cup return | Child return | Unresolved | Option value | Verdict |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Quarter Falls | `[0.72, 0.94]` | pending | pending | pending | pending | pending | n/a | PENDING |
| Jackpot Ridge | `[0.70, 1.08]` | pending | pending | pending | pending | pending | reported separately | PENDING |
| The Vault Drop | `[0.72, 0.94]` | pending | pending | pending | pending | pending | reported separately | PENDING |

The last complete pre-audit `pusherv3_9` evidence was `0.890210 / 0.926025 /
0.841235`. `pusherv3_10` changed opening stock and cup-origin accounting and
explicitly required this row to rerun the 200k harness, so those figures cannot
close this row.

| Gate | Exact-tree result |
| --- | --- |
| 10-seed determinism | PENDING |
| Windows native repeat | PENDING |
| Web GDScript repeat | PENDING |
| Windows/Web canonical digest equality | PENDING |

## Persistence, lifecycle and performance evidence

| Gate | Result |
| --- | --- |
| Standalone architecture validation | PASS, 47.925s |
| Explicit import | PASS, 46.580s |
| Native smoke | PASS, 3.515s, `native_v3` |
| Focused Coin Pusher Foundation | PASS, exit 0, 266.980s total: validation 48.028s, import 17.612s, load 24.247s, Coin Pusher 176.498s |
| Shipped-cap native performance and idle liveness | PENDING fresh native probe |
| Web shipped-cap frame/draw and idle liveness | BLOCKED on routed `fix06_9`; current parity is 40-body logic evidence, not shipped-cap timing |
| Broad Contract/all-Foundation integration | PENDING |

The first focused-suite shell launch was interrupted by its caller after 5.036s
and produced no test verdict. It is retained as an invocation failure, not
reported as a green or a functional red. The completed run above is the only
focused-suite verdict.

## Visual evidence

The retained exact-tree Plan 9.4 capture is red on `upper_row_join`. All three
accepted drops are platform-rooted and have saved PNGs, but each records
`advanced_existing_body_ids=[]`. A comparison to the pre-`pusherv3_10`
`pusherv3_9_visual_2` manifest shows 68 advanced bodies per machine before
opening stock became full-width, settled and idle, while `_capture_upper_row()`
itself did not change. This is a stale harness fixture, not permission to weaken
the physical-neighbor assertion or refresh a golden. It is routed separately
below. Normal/reduced current-tree visual review remains pending the corrected
harness row.

## Code health

### Confirmed healthy or intentional compatibility

- Rejected mechanics (`_pressurize_full_pile`, `_pusher_face_y`,
  `_hot_apply_pushers`, `MAX_COLLISION_PASSES`, `phase_accuracy`, the old clean
  nudge window and old overlap/lean shortcuts) are absent and guarded by tests.
- The outer `coin_pusher_discrete_pile` wrapper name is retained for V2 save
  recognition; durable physical state is the versioned `coin_pusher_settled_v3`
  schema. This is compatibility, not an active discrete-pile solver.
- `lane_count`/`depth_slot_count` survive only as deterministic feature schedule
  dimensions for Ridge/Vault legacy-shaped variation state; body physics and
  rendering do not consume them as a movement lattice.
- The renderer's cache is bound to exact source-array identity after `fix06_4`,
  preventing cross-session depth-order reuse while retaining bounded sorting.

### Findings

1. **P2 — stale V2 two-shelf player-facing copy (`fix06_7`).** `data/games/games.json`
   says “Two shelves shove a pile somebody else started” and “Read the
   shelves,” while
   `_variation_intro()` says Quarter Falls “shoves two shelves.” The binding V3
   model has one reciprocating platform, and the strings are reachable in the
   authored game intro and generated machine entry. Behavior is correct; copy
   contradicts the owner-approved machine. Route a non-gameplay content fix with
   a regression that forbids the rejected two-shelf description.
2. **P2 — stale Plan 9.4 `upper_row_join` capture fixture (`fix06_8`).** The harness no
   longer prepares a legal phase/nozzle relationship beside settled
   platform-rooted opening stock, so it observes the drop but no named existing
   neighbor within its horizon. Route a tooling-only row that deterministically
   selects/prepares a legal production nozzle and phase, uses the actual
   production drop/live session, records before/landing/after, requires a named
   pre-existing platform-rooted neighbor to advance within at most three cycles,
   and preserves the no-drop idle control in normal and reduced motion. If that
   corrected proof cannot succeed, reclassify it as a product-physics defect.
3. **P3 — superseded tuning keys remain authored.** `skill_accuracy_base` and
   `front_nudge_lane_radius` occur only in `data/games/games.json`; no shipped
   module, solver, renderer or test reads either key. They belong to the
   rejected lane/accuracy model and should be removed in the later cleanup pass,
   with a hostile-data check proving no runtime digest changes. They do not
   alter current behavior.
4. **P3 — historical standalone capture fixtures lack current ownership.**
   `coin_pusher_physics_feel_capture.gd` and
   `coin_pusher_delivery_board_capture.gd` are self-contained manual tools with
   no current wrapper, gate or documentation reference. They still encode useful
   historical diagnostics, so this audit does not delete them; the cleanup pass
   should either mark them archival with their superseding V3 evidence tool or
   give them a maintained wrapper. `coin_pusher_visual_capture.gd` is likewise a
   manually invoked Quarter Falls-only capture, but its normal/reduced snapshot
   proof remains conceptually binding through `pusher06_2`.
5. **P2 — shipped-cap Web performance has no maintained evidence path
   (`fix06_9`).** The native performance probe measures a 300-body live cabinet,
   per-action budgets and idle liveness. The exact Web parity export starts from
   40 bodies and proves canonical logic equality only. `web_perf_smoke.ps1`
   exposes `l02` and `grand_casino` plans, neither of which enters Coin Pusher.
   Therefore no fresh gate currently satisfies this audit's explicit Web
   shipped-cap frame/draw/idle-liveness requirement. A narrow Web performance
   evidence row is required; parity and unrelated scenario timing are not
   waivers.

No product code was deleted or rewritten in this audit. No RTP, EV, payout,
odds, wager, RNG, schema, migration, performance threshold or golden changed.

## `pusher06_2` reconciliation

Still binding after V3: renderer-agnostic snapshot/event ownership; batched
coin presentation; readable density, stacking, hangers, ledge/tray/gutters and
motor phase; distinct physical rider/puck/fragment presentation; interpolation
without solver feedback; idle animation with liveness proof; event-driven
impact/slide/motor/tray/gutter/nudge/alarm audio through the manifest; visible
tell ladder; input/accessibility coverage; and performance at the shipped cap.

Superseded by V3: the V2 two-shelf/lower-field geometry, lane-grid aiming model,
48→160-cap tuning narrative and its packed V2 action/replay representation,
V2-specific feel fixtures, and V2 outcome/parity hashes. V3's one platform,
rear Plinko delivery, 600-body hard ceiling, continuous-coordinate body
snapshot, nozzle queues, cups and amended timing/geometry are authoritative.

The board correctly marks `pusher06_0/1/3/4` SUPERSEDED and non-claimable.
`pusher06_2` remains a completed presentation/audio foundation only to the
extent listed above; it is not the current gameplay/geometry authority.

## Owner rulings

| Ruling | Implementation | Verdict |
| --- | --- | --- |
| One moving platform; corrected extended/retracted geometry | `43000`/`61000`, one solver face | PASS |
| Entry is rear-fed through full Plinko hardware | Authored drop boards, pegs and nozzle queues for all machines | PASS |
| Supported landing never spreads supports; only platform supplies horizontal force; supported is bad, bed-level is good | Support graph/impulse rules and exact feedback tests | PASS |
| Cup consumes trigger; 5X children use same nozzle and bounded chain | Trigger ledger plus nozzle queue/depth caps | PASS |
| Banked Ridge lock preserves armed multiplier for one full 240-tick stroke and never stops/steers motor | Phase-unit expiry and production motor tests | PASS |
| Vault physical coin-to-tray EV is `[0.72, 0.94]`, separate from option value | Authored split and harness reporting contract | PENDING fresh EV |
| Idle opening is settled/full-width and first accepted drop starts motor | Opening/idle/activation Foundation contracts | PASS |

## Disposition

The row is not ready to close while fresh EV, determinism, native/Web parity,
performance and broad integration gates are pending. The three P2 findings must be
routed as independent fix rows; they are not silently absorbed into this audit.
Final board status and prompt archival will be decided only after those results
and independent review of the exact audit head.
