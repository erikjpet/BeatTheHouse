# audio06_1 surface SFX pre-stage audit

Status: **UNREVIEWED, docs-only, not a board claim**  
Audit base: `main` at `6d8755394c6374ef66364f035e67827fb6e6bf6e`  
Scope: read-only inventory and an implementation test/capture plan. This document does not modify or approve manifests, assets, runtime, music, or product branches.

## Existing shared path

The shipped declaration path is `GameModule.surface_audio_spec()` -> a game state's `surface_audio` dictionary -> `GameSurfaceCanvas._sync_surface_audio()` / action dispatch -> `SfxPlayer`. `SfxPlayer` reads `data/audio/surface_sfx_manifest.json`, routes players to the `SFX` bus, uses ten reusable one-shot players plus one loop player, and resolves native/Web deliveries below `assets/audio/sfx_native` and `assets/audio/sfx_web`. `UserSettings` applies Master, Music, and SFX bus levels; the Web bridge mirrors those bus levels.

The manifest currently contains one profile, `coin_pusher`. The asset inventory is 41 native `.bthpcm` files and 95 Web `.bthsfx` files. Those unequal totals are an explicit parity gap until every selected event has a matching delivery or a documented platform-neutral fallback. Existing game declarations name profiles that the manifest does not declare, so declaration presence must not be mistaken for manifest coverage.

## Profile coverage and gaps

| Required family | Current declaration/surface evidence | Manifest profile | Existing asset evidence | Implementation gap |
|---|---|---:|---|---|
| Coin pusher | `coin_pusher.gd`, fact/event serial and state sync | Yes: `coin_pusher` | Native/Web coin-pusher deliveries exist, but native set is smaller | Preserve precedent; validate every event-class target on both platforms and audit tell-labelled events for disclosure |
| Craps | No `surface_audio` declaration found in current `craps.gd` | No | No dice/table/call-specific delivery identified | Complete fact-bound profile: cup, offer, throw, contact, settle, call, chips, collect/pay, crowd, street cues |
| Table games | Blackjack, baccarat, roulette declare profiles and cues | No | Web has blackjack/roulette assets; native inventory does not show corresponding sets | Declare profiles; map only authoritative round facts; deliver platform pairs; add shoe/cut/deal/squeeze/wheel/ball/dolly/clear/pay/procedure/shift events |
| Machine games | Slots and video poker declare profiles | No | Native/Web slot-era assets; Web-only video-poker set | Reconcile dynamic slot profile IDs, add credit/feature/hand-pay/tower/attract, and establish parity without changing math or timing |
| Counter games | Pull tabs and scratch tickets declare profiles | No | Web-only paper/pull-tab/scratch assets | Add rack/handoff/scratch/peel/redemption/refusal profiles and native counterparts; unrevealed outcomes must be indistinguishable |
| Bar dice | `bar_dice_table` declaration and tumble sync | No | No dedicated delivery identified | Add shake/slam/lift/reveal/cash cues driven by public ritual facts |
| Back-room poker | `crew_cards` declaration and action cues | No | Generic/card assets are incomplete and largely Web-side | Add chips/cards/public beats; prohibit sound keyed by hidden tell identity or success |
| Crew/world | No shared manifest profiles found | No | No dedicated door/handoff/package/stash/duck/pursuit/sweep/book/slip/draw/confrontation set identified | Bind profiles to accepted world transition ops, with bounded concurrency and observable counterparts |
| Scenario transitions | No manifest profile found | No | No staged-transition set identified | Map accepted `env06_6` transition ops to diegetic events; never derive from frame time or caller labels |

## Authority and validation requirements

The implementation should treat a game fact or accepted transition op as the authority. A caller-provided profile, cue, asset path, volume, pitch, hidden flag, or elapsed time is presentation input only and must not create an event. Profile IDs and event classes must resolve through a closed manifest schema. Unknown profiles/classes, missing platform deliveries, paths outside the delivery roots, absent voice caps, duplicate IDs, and unsupported loop declarations must fail validation.

Selection must be a pure function of the authoritative ordered fact/op trace, run seed, profile, event class, and deterministic occurrence index. Capture the selected event ID, occurrence index, start boundary, loop transition, and steal decision—not wall-clock timestamps. The ten-player global pool is bounded, but audio06_1 still needs an explicit per-surface cap and deterministic stealing policy in each profile or a shared default enforced by validation.

## Exact proof and capture plan

1. **Static manifest gate.** Parse the manifest; reject duplicate/unknown profiles and classes, traversal/absolute paths, missing native or Web assets, undeclared loops, nonpositive/unbounded voice caps, and profiles referenced by a shipped surface but absent from the manifest. Emit a sorted profile/event/delivery matrix.
2. **Boundary trace gate.** For every profile, feed a fixed authoritative game-fact or transition-op trace through the real canvas-to-player path. Record normalized `{fact_or_op_id, profile_id, event_class, selected_event_id, occurrence, lifecycle, stolen_voice}`. A render-only frame advance with no new fact/op must produce no new record.
3. **Determinism/parity gate.** Repeat identical traces for seeds 0-9 twice on native and Web. Event selection, order, lifecycle, and stealing must match byte-for-byte; asset container differences are allowed. Perturb wall clock and frame cadence and require unchanged records.
4. **Mixer gate.** Run every profile at Master/SFX values 1.0, 0.5, and 0.0 and with the SFX bus muted. Confirm native player and Web bridge effective gain follows settings, including loops and stolen voices; Music changes must not affect SFX selection.
5. **Concurrency gate.** Generate maximum legal simultaneous activity per surface plus one event. Assert the declared cap, deterministic victim selection, no unbounded node creation, no per-frame manifest/asset work, and cleanup on surface exit.
6. **Accessibility gate.** For each informational event, capture the authoritative visual/text counterpart ID. Reject any audio-only state transition. Run reduced-motion mode and require the same informational boundary even if visual interpolation differs.
7. **Capture bundle.** Archive manifest hash, native/Web asset hashes, sorted coverage output, ten-seed traces, paired-observer results, hostile-caller results, mixer matrix, concurrency snapshot, and a short native/Web capture for each profile. Label music as out of scope; record the separate handoff delta without changing music behavior.

## Hidden-state paired-observer cases

Each pair uses the same public observation history, accepted actions, seed, and frame schedule; only inaccessible state differs. Up to the contract's reveal boundary, normalized audio traces and rendered waveform/event timing must match.

| Pair | Hidden difference | Required equality boundary |
|---|---|---|
| Craps | controlled/biased resolution metadata versus ordinary throw with the same public dice choreography | Through settle; diverge only at the public call if the call differs |
| Table cards | dealer hole card, shoe remainder, count state, or future draw | Through each public deal/reveal boundary |
| Roulette | selected pocket/rig metadata with identical visible wheel/ball phase | Through public pocket resolution |
| Counter | winning ticket/pull-tab contents versus losing contents | Through peel/scratch reveal of the compared region |
| Back-room poker | tell identity, reliability, traitor state, or opponent private cards | Until the tell contract authorizes the same public beat |
| Crew/world | package contents, stash identity, pursuit target, sweep result, or unrevealed clue | Until an accepted op makes the fact observable |
| Scenario | hidden branch/outcome payload behind identical staged transition ops | Until distinct authoritative public ops are emitted |

The screen-off playtest is intentionally weaker than this automated rule: a listener may recognize that a public action occurred, but may not distinguish which secret caused or will follow it.

## Hostile caller-authority cases

Run each against the real surface binding and assert no unauthorized audio event, stream load, or loop state change:

- Supply a valid cue/profile for the wrong game, wrong run, wrong round, wrong actor, or stale occurrence ID.
- Supply an undeclared profile or class, a direct asset filename, an absolute path, traversal path, native path on Web, or Web path on native.
- Supply volume/pitch extremes, NaN/infinity, negative occurrence/time, forged elapsed time, a frame-timer callback, or a caller-selected RNG result.
- Replay, reorder, duplicate, omit, or mutate a previously accepted fact/op; cross-wire two simultaneous surface IDs.
- Ask to start/stop a loop without the authoritative lifecycle op; request more voices than the profile cap; attempt to protect a hostile voice from stealing.
- Attach hidden outcome/tell/traitor/rigged/clue data to an otherwise valid public event and require the same trace as the clean control.
- Invoke action-cue helpers directly with a syntactically valid cue but no accepted game action. The handler must derive authority from the fact/op boundary, not helper reachability.

## Dependency handoff

Implementation remains blocked on accepted and landed Family 1/2 ritual facts and transition ops as required by the row. When those heads are available, first reconcile their canonical IDs and reveal boundaries with this matrix; do not invent substitute IDs in audio06_1. The music delta belongs only in the established external audio-engineer handoff format and must not alter `music_manifest.json` or music runtime behavior.
