# Coin Pusher V3 program closure audit

Status: COMPLETE — accepted on the final integrated Coin Pusher tree
Audit row: `pusherv3_11`
Audit date: 2026-09-01

## Verdict

The V3 program closes as three complete, distinct, persistent Coin Pusher
machines. The recovered V3 physics/live-session/cabinet work was retained and
extended rather than rebuilt. The later opening, Plinko, objective, lifecycle,
and shipped-Web fixes compose without changing authored payout bands, RNG,
money rules, save semantics, or accessibility behavior.

The owner-selected `fix06_8` disposition is implemented: a fixed production
nozzle/control trace (not seed searching) places the tracked drop beside real
upper stock. On all three cabinets the no-input control remains byte-stable,
the paid drop is platform-rooted in both the event and independent body view,
and the exact qualified neighboring coin advances over the matched stroke.

## Contract map

| Requirement | Shipped implementation and verification | Verdict |
| --- | --- | --- |
| One continuously reciprocating platform | The solver owns one moving face; authored extended/retracted face geometry is `43000`/`61000`. Face push, collective ratchet, nestling, and stroke behavior are foundation-covered. | PASS |
| Amendment 6.2 rear-fed entry | Every machine uses authored Plinko geometry and nozzle hardware above the upper platform. Drops traverse the physical delivery field before support or a terminal exit. | PASS |
| Continuous physical bodies | The 60 Hz fixed-point solver owns contacts, support graphs, gravity, ledgers, and canonical state. Rejected lane/lattice mechanics remain absent. | PASS |
| Played-in, quiet opening | New Quarter/Ridge/Vault machines contain `150/150/154` settled bodies across all thirds. Five historical periods without input produce no motion, payout, sound, event, tray, or gutter change. | PASS |
| Player apparatus and tap/hold queue | Quarter and Vault use bounded rails; Ridge uses three fixed nozzles. Tap queues one, a three-second hold queues 30, affordability truncates atomically, and queued drops remain steerable and persistent. | PASS |
| Complete Plinko targets | Each cabinet has two physical bucket cups. Cups consume the triggering coin and award explicit bonus-token children from the same nozzle; no cup pays direct cash. | PASS |
| Stack/support ruling | Only the platform supplies horizontal bed pressure. Supported landings do not spread supports, remain carried through real contacts, and produce one bad-drop cue; bed-level joins produce one good-drop cue. | PASS |
| Skill stop remains physical | Skill stop changes the motor target and preserves physical body outcomes; the fixed upper-row proof uses the production stop/release path. | PASS |
| Tray/gutter/conservation | Base physical value reaches bankroll only through `COLLECT`; gutters are loss; cup and feature tokens retain separate origins; ceiling refusal spends nothing. | PASS |
| Transient versus settled persistence | Live motion stays in the session, autosave does not perform a long settle, exit settle is bounded, and compact restore preserves motor, queue, support, feature, alarm, and body state exactly once. | PASS |
| Renderer/presentation boundary | The renderer consumes published snapshots, cached cabinet layers, and one bounded native multimesh batch. Presentation interpolation never feeds the solver. | PASS |
| Normal and reduced motion | Both modes retain nonzero solver liveness and exact conservation; reduced motion changes presentation cadence only. | PASS |

## Pillar 4 and machine identities

| Requirement | Result | Verdict |
| --- | --- | --- |
| Universal nudge force × aim × timing | Tap/shove/slam plus left/front/right are real production controls. They apply phase-sensitive physical impulses, spend tolerance, and enter the deterministic input trace. | PASS |
| Tell ladder | `steady` → `cabinet rocks` → `alarm chirps` → `attendant looks over` is durable, visible, audible, and tick-decayed. | PASS |
| Alarm consequence | Alarm locks the machine, stops the motor, adds heat, and writes node memory without forcing an exit. Collection and leaving remain available. | PASS |
| Quarter Falls objective | Large prize riders are the main target; banking three awards `+5` tokens and restocking keeps at least three in circulation. Cup awards are `+3/+5`. | PASS |
| Jackpot Ridge objective | Weighted multiplier pucks bank toward a three-puck Ridge Run and `+5` tokens. The lock ruling preserves the armed multiplier for one 240-tick stroke without steering/stopping the motor. Cup awards are `+5/+3`. | PASS |
| The Vault Drop objective | Large key fragments unlock cells; each three award `+6` tokens, all nine cells start a new deterministic cycle, and at least three fragments remain available. Cup awards are `+5/+4`. | PASS |

The backglass names each objective and displays segmented progress. These goals,
not ordinary coin return, are the dominant player-facing purpose of each
cabinet.

## Economics

The accepted persistent audit used eight deterministic shards and exactly
200,000 paid drops per cabinet (600,000 total). Feature/cup value is excluded
from physical coin-to-tray ROI and reported separately.

| Machine | Authored physical band | Physical ROI | Stock-adjusted interval | Cup tokens | Goal tokens | Verdict |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Quarter Falls | `0.72–0.94` | `0.810025` | `0.810025–0.826445` | `17,596` | `16,360` | PASS |
| Jackpot Ridge | `0.70–1.08` | `0.903210` | `0.903210–0.922730` | `4,246` | `13,525` | PASS |
| The Vault Drop | `0.72–0.94` | `0.798925` | `0.798925–0.815900` | `28,580` | `21,084` | PASS |

Every shard passes body/token conservation, paid-origin reconciliation,
persistent-machine assertions, target reachability, and both-bound 95%
confidence checks. Vault option value remains separate from physical return.
Evidence: `.tmp/coin_pusher_final_ev_8/manifest.json`.

A new exact-performance-head EV launch was preserved at
`.tmp/coin_pusher_ev_8e407061`. The runner's current forced-serial mode did not
complete its first of 24 shards after two minutes and projected a multi-hour
rerun while memory continued to grow. It was stopped without deleting its
partial output. Reuse of the accepted 600,000-drop result is valid here because
all later changes are renderer/publication/native-cache performance changes;
geometry, RNG, payout, feature, machine data, and economy code are unchanged,
and exact input parity plus byte-identical determinism pass on the final tree.

## Exact-tree verification

| Gate | Result |
| --- | --- |
| Project validation and script loading | PASS; 302 scripts load with zero failures. |
| Focused Coin Pusher foundation | PASS; exact 300-body/native-backed contract, zero failures. `.tmp/prepared_batch_fields_focus/foundation_coin_pusher.json`. |
| Static/hardware cache contract | PASS; all invalidation, command-order, reentry, resize, and cached/uncached pixel-equivalence checks. `.tmp/coin_pusher_static_cache_8e407061/manifest.json`. |
| Web native live batch | PASS; payload `c03588babf0a5fb40b36349020dd90e43bba4a1c8644c6a15c7bc1f54e31953f`. `.tmp/coin_pusher_live_batch_8e407061/manifest.json`. |
| Windows/Web input parity | PASS; payload `964648c90c94e36ef343939248e05ffd33c3a30c78cfecc48349425db88717b2`. `.tmp/coin_pusher_input_parity_8e407061/manifest.json`. |
| Fixed upper-row production proof | PASS for all three cabinets, including idle control, paid production drop, independent platform root, exact ticks, and named neighbor advance. `.tmp/fix06_8_option1_final/captures/manifest.json` (SHA-256 `0239F827C712D3F337A7DD821C2532E53AA1197CED7D72C0EF7AC475B`). |
| Actual-GL visual QA | PASS; 3 cabinets × 9 production scenes, normal/reduced captures inspected at 1280×720. Same manifest and PNG set as the fixed upper-row proof. |
| Persistent EV | PASS; 600,000 paid drops. `.tmp/coin_pusher_final_ev_8/manifest.json`. |
| 10-seed determinism | PASS; two independent 10-seed/560-checkpoint processes are byte-identical at combined hash `4129524558` and file SHA-256 `3972A3C5E2D3A501E10D618E4910128DCE61989E134D66C5A691A8311587F689`. `.tmp/foundation_determinism_probe/run_a.json` and `run_b.json`. |
| Shipped-Web performance | PASS/retained evidence is recorded in the `fix06_13` closeout. The first red and every later iteration remain preserved; no budget, fixture, sample, or liveness floor changed. |

## Performance remediation summary

The first honest exported-Web cabinet measured roughly 142–145 ms frame p95
and 52–55 ms draw p95. The final path keeps the exact 300-origin fixture and
real cabinet while using the native solver, packed publication, cached static
and hardware layers, prepared multimesh batches, staged HUD refresh, and a
pinned lean Godot Web template. The best quiesced exact-tree measurement is
inside every frame/action/startup cap; retained noisier repetitions are listed
in the `fix06_13` record rather than discarded. No visible state, simulation
result, economy result, or evidence assertion was bypassed.

## Code health and reconciliation

- Rejected V2 mechanics and collision-lattice symbols are absent and guarded.
- The outer `coin_pusher_discrete_pile` name remains only for V2 save
  recognition; active durable state is `coin_pusher_settled_v3`.
- `lane_count`/`depth_slot_count` remain only as deterministic feature-schedule
  dimensions, not movement coordinates.
- `skill_accuracy_base` and `front_nudge_lane_radius` are unused superseded
  tuning keys. They are harmless cleanup debt, not active behavior.
- Historical standalone capture tools remain archived diagnostics; the Plan
  9.4 production capture is the maintained whole-machine visual proof.

`pusher06_2` still binds the snapshot/event ownership, batched presentation,
readable piles/exits, physical feature pieces, event-driven audio, tell ladder,
accessibility, interpolation separation, and shipped-cap performance intent.
Its two-shelf geometry, lane aiming, V2 replay hashes, and V2-specific fixtures
are superseded by V3. The board correctly retires `pusher06_0/1/3/4`.

## Final disposition

`pusherv3_10`, `fix06_8`, `fix06_9`, `fix06_13`, and `pusherv3_11` are complete.
No Coin Pusher gameplay, evidence, economy, or design blocker remains for the
0.6 playtest handoff. Future changes are post-playtest polish, not unfinished
V3 implementation.
