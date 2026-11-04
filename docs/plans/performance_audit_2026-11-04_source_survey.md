# Whole-game performance audit: source survey, 2026-11-04

Parent objective: `BTH-PERF-20261104`. This is an initial source survey, not a completed audit, runtime qualification or release receipt. The parent objective remains open after individual findings are fixed.

Initial source reviewed: `398546e319b391cdf25b65e3b4888d83d7c74bb5`, which was the stale primary checkout's main. The audit owner subsequently established current NEXT source as `dc15b7d369f435d50fbf16e37af33952a4c58760` and updated the isolated clone. The survey was reconciled against that source; line references below refer to `dc15b7d`. Review owner: the whole-game source survey worker under the performance audit owner. No game, browser, native workload, export, save operation or dependency build was run by this survey. Runtime latency, memory retention and before/after measurements are **unmeasured**. No large leak is confirmed by this document.

## Baseline reconciliation

Exact function-text comparisons between the initial source and `dc15b7d` found Video Poker `_best_odds_holds`, `_hold_expected_pay`, `_strategy_completion_pay`, `_strategy_hand_pay`, `_evaluate_natural`, `_evaluate_wild`, `_deal_deck` and `_opening_hand` unchanged. The hint activation at `video_poker.gd:569` and strategy constants remain present, so candidate `BTH-PERF-20261104-002` and the standard-deck operation counts still apply. The surrounding Video Poker presentation did change; this is not a whole-file equality claim.

Crew Hold'em, world-map canvas, procedural music, SFX, telemetry overlay and the named existing performance probes had no tracked source diff between those two revisions. Other sampled game modules, the host, shared canvas, room canvas and save service did change and were not labeled unchanged. Rechecked boundaries retain the observations below, while the current no-thread save explicitly adds separate bytes/hash and JSON validation phases before install. Any eventual timing result must bind the actual tested source rather than the stale checkout.

## Scope and evidence rules

The requested audit concerns substantial slowdowns, large leaks and avoidable expensive paths during typical play across the game. The Web Coin Pusher nozzle/physics symptom is the first reproduction and does not bound the audit. Actual native runtime gameplay/performance evidence and actual Web gameplay/performance evidence are both required; a source survey, synthetic helper or historical test count cannot substitute for either.

This survey sampled the source boundaries listed below. It did not exhaustively read every renderer, game rule, scenario, save codec or item interaction. Source observations identify what to measure; they do not prove the absence of leaks, establish frame budgets or qualify unexercised gameplay. Dated evidence in older performance documents remains historical evidence only.

## Sampled game coverage

All rows below are source samples. Native runtime and Web runtime coverage remain pending for every row.

| Game | Sampled current source | Observation and remaining runtime sampling |
| --- | --- | --- |
| Coin Pusher | `scripts/games/coin_pusher.gd:331,483,803`; shared captured-pointer dispatch | Carriage and charge pointer commands enter live machine/session handling; realtime presentation has a separate patch path. Root audit owns the reported nozzle symptom. Compare identical stationary and moving-pointer dispensing windows, fixed ticks per wall second, accumulated simulation time, input work, native step time and frame/draw timing without assuming the cause. |
| Scratch Tickets | `scripts/games/scratch_tickets.gd:194,436` | Scrub moves process a scratch segment and return pointer patches; sub-threshold moves have an early return. Measure continuous normal scrubbing, reveal, discard and repeated ticket cycles with input and audio active. Segment cost is unmeasured. |
| Pull Tabs | `scripts/games/pull_tabs.gd:150,786,925,3503` | Surface builds ticket, tray and receipt-pile projections; one sampled retained history is capped at 24. That cap does not prove all ticket-state retention is bounded. Measure buying/peeling/redeeming and normal pile growth across repeated sessions. |
| Slots and features | `scripts/games/slot.gd:425,632,1090,1255`; `scripts/games/slots/slot_renderer.gd:16-18,2808`; `scripts/games/slots/pinball/pinball_feature.gd:801,816` | Realtime presentation uses a patch instead of rebuilding the whole machine each frame. Sampled renderer caches and Pinball template/session caches have caps. Measure manual play, foreground autoplay, background cabinets, major family bonuses and Pinball, including repeat entry/exit. A capped cache may still have excessive working-set or eviction cost. |
| Bar Dice | `scripts/games/bar_dice.gd:361,645`; `tools/bar_dice_late_run_performance_probe.gd` | Surface preparation constructs patrons, timer state and challenge views; the timer path deep-copies preview state. Existing probe targets aged-run click-to-result cost. This does not establish a material regression; measure normal roll/selection and aged-run actions before changing copies or authority. |
| Craps | `scripts/games/craps.gd:122,337,501,669,1430,1828` | Surface preparation validates enabled betting targets and constructs ritual/challenge views. Sampled roll/action histories have explicit limits. Measure ordinary chip placement, roll/payout, street-table state and repeated entry/exit; do not infer leak freedom from these caps. |
| Blackjack | `scripts/games/blackjack.gd:696,1648,1721,1756,7111` | Surface preparation projects hands, side bets and patrons. One sampled settled history is capped at 12. Measure deal/hit/stand/split, side bets, patron action and ordinary late-run reentry; table-state and authority copies must retain their ownership guarantees. |
| Baccarat | `scripts/games/baccarat.gd:215,421,1304,1313` | Realtime ceremony borrows the immutable last result; sampled result/shoe histories are capped at 72. Measure normal chip placement, deal/reveal/payout and optional squeeze/read interaction, with continued no-input animation. |
| Roulette | `scripts/games/roulette.gd:288,512,3773` | Realtime patch projects phase, history, bets and optional read/past-post state. Sampled settled history is capped at 12. Measure normal betting and full spin/payout, including transitions and normal optional interaction. |
| Video Poker | `scripts/games/video_poker.gd:516,569,2884-2961`; `tools/video_poker_draw_performance_probe.gd` | The strategy-hint item exposes the strongest additional cold-action candidate, `BTH-PERF-20261104-002`, below. Also measure ordinary deal/hold/draw/double-up and multi-hand play without the item. |
| Crew Hold'em | `scripts/games/crew_draw_poker.gd:321,334,397,1265,1546` | Dormant/player-turn automation uses an in-place peek and lightweight tick state; animation patch is separate. Sampled action histories have limits of 12 or 40. Measure full player/NPC turns and multi-opponent pots rather than treating a dormant poll as representative of active play. |

## Candidate BTH-PERF-20261104-002: Video Poker cold strategy hint

Status: **unconfirmed performance candidate; measurement pending**. Owner: performance audit. No fix, regression verdict, commit or deployment is associated with this candidate yet.

At `video_poker.gd:569`, `surface_state()` calls `_best_odds_holds()` synchronously when the player is in the hold phase and has the `video_poker_strategy_hint` item effect. `_best_odds_holds()` at line 2884 checks a bounded 128-entry cache, then evaluates all 32 hold masks on a cold dealt-hand key. One- and two-card draws enumerate completions; draws of three or more use `STRATEGY_SAMPLE_CAP = 1024`.

For a standard 47-card remaining deck, source control flow implies **27,430 completed-hand evaluations** for a cold hint:

`5 * 47 + 10 * C(47, 2) + 16 * 1024 + 1 = 27,430`.

The 16 sampled masks duplicate their deck pool on every sample at line 2939, implying **16,384 pool duplications** for that standard cold hint. Completion and hand-evaluation helpers also construct arrays and dictionaries. These are derived operation counts, not measured allocation bytes or timings. Other cabinet deck definitions can change the exact count.

The cache avoids repeating the calculation for an identical key, but a new dealt hand normally misses. A substantial Web deal hitch is plausible; its existence and size must be measured. Existing `tools/video_poker_draw_performance_probe.gd` measures aged-run DRAW/double-up and does not equip the strategy-hint item, so it does not qualify this candidate.

Required reproduction and evidence:

1. Use disposable native and Web profiles. Reach the real Video Poker player path in a supported cabinet, first without the hint effect and then with it, keeping the seed, cabinet/paytable and normal workload comparable.
2. Separate cold new-hand calculation from warm repeat projection. Record source/build identity, equipped effect, cabinet, hand, key/cache status, action latency, maximum and percentile frame time, strategy calculation time and an honest allocation/copy metric.
3. Repeat enough comparable cold hands to distinguish a consistent large hitch from startup, audio or save work. Include a wild and a natural cabinet if either exposes materially different work.
4. If material cost is confirmed, preserve exact recommendation, deterministic sample sequence, tie breaking, RNG/economy and paytable behavior. Do not lower advice quality or alter sampling merely to obtain a faster number. Recheck normal deal/hold/draw, warm interaction and the item effect on native and Web.

Prepared attribution tool: `tools/video_poker_hat_timing_probe.gd`. It has **not been executed or engine-parsed by the survey worker**. The audit owner can run it through the maintained bounded native runner using `--headless --path <isolated source> --script res://tools/video_poker_hat_timing_probe.gd`, with `BTH_PERF_SOURCE_SHA` set to the exact tested source and optional `BTH_VP_HAT_SAMPLES` (default 3, maximum 6). The script only loads production content and uses transient generated RunStates/cabinets; it does not invoke SaveService or user/profile settings. Generated Deal commands supply the hands. It reports direct cold/warm strategy helper microseconds, unassisted surface time, warm equipped-hat surface time, generated cabinet/hand identities, recommendation/cache consistency and read-only state checks to stdout as `BTH_VP_HAT_TIMING_REPORT`. No artificial timing pass threshold is applied. Direct native helper measurements remain synthetic attribution; they do not establish rendered native action latency, a normal full-game route, Web frame behavior, memory allocation totals or a leak verdict.

## Shared systems sampled

| System | Current source evidence | Implication and unmeasured target |
| --- | --- | --- |
| Frame host and game surface | `scripts/ui/foundation_main.gd:809,2640`; `scripts/ui/game_surface_canvas.gd:1341` | Existing subsystem timers distinguish layout, automation, realtime patches, environment work and autosave. Captured pointer moves flush separately from presentation clocks. Measure both frame timing and simulation progress; smooth presentation alone is not acceptable physics evidence. |
| Background cabinet scheduling | `scripts/ui/foundation_main.gd:2772,2804` | Due scheduler, quiet frames and one settlement per pass already avoid an unconditional whole-room resolve loop. Profile ordinary watched play with active background cabinets and preserve offscreen outcomes. |
| Rooms and actor lifecycle | `scripts/ui/pixel_scene_canvas.gd:1931,3802,3894,6932,7582,9016,9022,9187` | Sampled text/phase/actor/character caches have bounds or pruning. Scheduled draws still reconstruct room art and actors. Crowded-room redraw and camera/focus transitions remain potentially material measurement targets, not confirmed defects. |
| Travel map | `scripts/ui/world_map_canvas.gd:70,90,729` | Snapshot signature serialization happens at snapshot replacement; steady layout uses a size-based dirty check. Measure map entry, zoom/drag/focus and normal travel/revisit transitions rather than assuming full signature work every frame. |
| Saves and Continue | `scripts/core/save_service.gd:86,123,140,194` | Threaded saves own a snapshot; no-thread Web encode, pack, bytes/hash validation, JSON-root validation and validated install remain synchronous phases distributed across frames. Profile each phase during typical aged-run saves and active play. Generation ownership, atomic validation and primary/backup compatibility are required behavior. |
| Audio and run boundaries | `scripts/ui/procedural_music_player.gd:316,334,353,401`; `scripts/ui/sfx_player.gd:290,1293` | PCM accounting/budget, eviction, run-cache clearing and debug counts already exist. Headless audio stops processing and cannot stand in for rendered audio-on lifetime evidence. Sample room/music changes, one-shots, features, run end and new run in a single browser lifetime. |
| Shared UI lifecycle | `scripts/ui/foundation_main.gd:15359` and sampled queue-free/tween sites | Existing diagnostics expose cache sizes, child counts, tweens and signal connections. Track retention after comparable settled states across inventory/journal/map/dialogue/result cycles; source presence of `queue_free()` does not prove leak freedom. |

The no-thread save phase and crowded room renderer are additional **unconfirmed material profiling targets**. They have not been assigned new finding IDs here because no separate defect has yet been established. Convert a reproducible substantial issue into its own finding record with owner, evidence, measurements and commit before claiming a fix.

## Existing tooling to reuse carefully

- `scripts/ui/perf_telemetry_overlay.gd` records frame/physics, memory, subsystem timing and explicit copy-source events. Current system categories include rooms, scenarios, Crew, world, dialogue, report, inventory, audio, save/restore, maximal composition and run trajectory. Its scripted setups are distinct from normal player route evidence.
- `tools/foundation_performance_probe.gd` contains game/room idle and active checks with paired liveness requirements. Do not call old budget results a fresh pass. Its PowerShell wrapper can build native dependencies and run imports; inspect current resource ownership and containment before invoking it.
- `tools/foundation_soak_probe.gd` records post-warmup retained memory, object/resource/node counts, serialized state and gameplay coverage, with repeat save/load/travel/run rotation. Its default 180 minutes are **simulated minutes**, not a three-hour wall-clock soak. Its older wrapper is not an automatic substitute for the maintained bounded workload runner.
- Focused probes already exist for Bar Dice late-run actions, Video Poker draw/double-up, slot foreground autoplay, run-history transactions and profile-history load. Reuse relevant paths without broadening every small fix into a full suite.

## Remaining coverage and closure limits

The audit still requires current-build native gameplay and Web gameplay across all eleven games, representative slot families/features, ordinary rooms and crowded late-game rooms, normal scenario/dialogue/item/service/lender/crew/travel interactions, Save and cold Continue, menus/meta/home/report flows, and repeated lifecycle transitions with audio enabled. Collect retained-memory slopes after warmup and comparable return states, distinguishing allocator high-water from monotonic retained growth. Typical play comes first; synthetic stress must be labeled separately.

For each substantial confirmed finding, retain baseline reproduction, source/build identity, measurement method and samples, scoped fix, focused functional and liveness regressions, before/after measurements and associated commit. Native and Web results must be separately labeled. Follow the authorized main-to-NEXT pipeline and record actual promoted/served identity and changed behavior where feasible.

Preserve saves and trusted authority boundaries, RNG/economy, normal behavior, fixed 16:9, touch/focus and autonomous animation. After performance/canvas changes run the required animation-liveness check. No open scope, todo, finding or parent objective is closed by this survey, by a historical test count, or by one delivered fix.
