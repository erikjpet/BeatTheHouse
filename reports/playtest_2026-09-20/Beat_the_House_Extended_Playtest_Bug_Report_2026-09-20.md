<!-- Mechanical text extraction of
     Beat_the_House_Extended_Playtest_Bug_Report_2026-09-20.docx,
     produced 2026-09-20 for agent consumption. The .docx remains the
     authoritative artifact; figures/images are not reproduced here. -->

QUALITY ASSURANCE / PLAYTEST

# BEAT THE HOUSE

Extended Playtest & Root-Cause Bug Report
Source candidate, packaged artifacts, endurance, fuzz, and transaction verification

| 58 CONFIRMED DEFECTS | 7 CRITICAL | 15 SPECIALIST WAVES | 18 / 11 ROOMS / GAMES |
| --- | --- | --- | --- |

| Field | Value |
| --- | --- |
| Test date | 20 September 2026 |
| Source identity | HEAD 4384378a00d2e81e259aa28ae01ffbbc7cf21fd5 plus pre-existing uncommitted worktree changes |
| Runtime | Godot 4.6 stable (89cea1439), Windows 10 (19045), i9-9900K, 64 GB RAM, RTX 4070 Ti |
| Published metadata | 0.5.1; repository notes identify active main-line work as unreleased 0.6 |
| Change policy | Diagnostic only. No gameplay, source, content, or data defect was fixed. |
| Confidence rule | Player-facing bugs required production-path evidence and repeatability; harness-only failures were excluded. |

Prepared for engineering triage. Internal QA evidence paths are repository-relative.

## Executive summary

This multi-wave campaign confirmed 58 distinct actionable defects after independent evidence review, root-cause validation, and deduplication. The set contains 7 Critical, 26 High, 19 Medium, and 6 Low findings. The dominant risk is not game-rule correctness or frame time; it is interaction authority and accessibility. Multiple visible controls claim the same hit area, several route controls overlap, and one scenario audit explicitly suppresses the evidence that should catch those collisions.
The extension added accessibility, controller, persistence-size, package-custody, transaction-isolation, and debt-boundary failures that were not visible in the first report. At the same time, all eleven games completed broad rules and stuck-state coverage, millions of statistical outcomes stayed inside their authored bands, and ordinary SaveService corruption recovery remained reliable. False positives from stale hashes, pre-ready fixtures, missing event authorization, and raw-JSON shortcuts were excluded.
The final audio/feedback wave also confirmed stale procedural compositions across distinct room profiles, presentation clocks advancing behind pause overlays, a nonzero 0% volume setting, silent malformed-settings recovery, and two source-proven Web audio lifecycle/failure-contract defects. Browser-only quantitative memory and fault injection remain explicit limitations rather than inferred measurements.
Three independent 360-minute soaks found no sustained memory, node, resource, cache, or serialized-state growth. They did expose a dynamic-room semantic-proof drift that blocks routes still shown as enabled and a Coin Pusher rollback token that can reject its own recovery contract. A third soak signal—Blackjack wording in Slot and Bar Dice—was merged into the already-counted shared-host text defect rather than double-counted.
Final static sweeps identified missing OS-focus ownership for simulation and captured holds, a Settings cancel-path palette leak, and four player-text defects involving shared game identity, chip-versus-cash wording, clock format, and singular grammar. Absent translation infrastructure is documented as readiness risk but is not counted because the product does not advertise another locale.

| Priority | Triage focus | Why it matters |
| --- | --- | --- |
| 1 | Restore trustworthy collision auditing (UIE-021) | The current scenario audit returns false zeroes in rooms with shipped developer placements, hiding blocking route/action collisions. |
| 2 | Stabilize dynamic-room semantic proofs (EXT-PERF-001) | Mutable live producer context changes an identity digest, so enabled travel fails and later room-game actions can fail closed. |
| 3 | Make money/result transactions atomic (XPE-01; EXT-GAME-001) | A debt boundary can grant an underfunded purchase and end the run; a rejected Blackjack delivery can still duplicate persisted history. |
| 4 | Repair modal and controller authority (A11Y-001/006/007/009) | Hidden controls can activate behind popups, the map clips at the supported floor, and controllers cannot accept or cancel globally. |
| 5 | Reject unencodable saves before rotation (PERSIST-EXT-01) | An oversized save reports success and can remove Continue or silently roll progress back to the prior generation. |
| 6 | Separate route and wagering authority | Core navigation or action controls share pointer space; the selected outcome can depend on draw or insertion order. |
| 7 | Bind and sanitize release artifacts | Packages lack one source identity, internal QA/toolchain files leak into PCKs, and a loose executable omits its native solver DLL. |
| 8 | Correct audio identity and pause ownership | Different room profiles can reuse stale PCM, while hidden game-surface clocks and cues advance behind pause overlays. |

### Release recommendation

Do not treat the current candidate as interaction-complete. At minimum, fix and regression-test the false-clean audit, dynamic-room semantic-proof drift, overlapping route controls, keyboard-inaccessible world map, and accessibility-setting regressions before release qualification. Game-rule and long-run resource baselines are strong enough to support focused remediation rather than a broad gameplay rewrite.

### Severity model

| Level | Definition used in this report | Count |
| --- | --- | --- |
| Critical | Blocks or ambiguously reroutes a core progression/action path, or disables the safety audit intended to catch it. | 7 |
| High | Materially impairs interaction, accessibility, or readability on a repeatable production path. | 26 |
| Medium | Recoverable but confusing, undersized, truncated, or inconsistent behavior with clear player impact. | 19 |
| Low | Limited presentation defect with low functional risk. | 6 |

## Test identity, method, and coverage

The candidate was tested in its existing dirty worktree because those changes were already present when the assignment began. The campaign preserved them and produced only reports and temporary evidence. Runtime-heavy Godot work was serialized to avoid the repository's documented cross-gate interference; static analysis and evidence review proceeded in parallel.

| Area | Coverage executed | Outcome |
| --- | --- | --- |
| Environment/UI | Fresh deterministic captures of all 18 archetypes; direct interaction-rect intersections computed separately from 8 px spacing warnings; current-date Bar scenario frames reviewed. | 16 base-room and 4 scenario hitbox conflicts; 6 additional UI defects. |
| Games | All 11 modules; 4 functional shards / 10 checks; 48 resolve samples per applicable game; active Coin Pusher and Slot paths. | Functional and current performance gates passed; two Bar Dice layout defects. |
| Tutorial/progression | Both tutorial routes; 56 lesson-boundary save/load checkpoints; 100-seed stuck sweep; 1,622 guardrail transitions; 28 systems checks. | One recoverable wrong-order tutorial defect. |
| Persistence/chaos | Two seeds × two disk generations; scenario queue, travel, travel lock, closing, event, challenge, and terminal state. | No product persistence defect; raw-JSON harness failures excluded. |
| Accessibility/input | Twice-run production-class probes for focus, modal cancel, small-screen sizing, dynamic UI scaling, and reduced motion. | Five defects reproduced identically. |
| Packages | Windows distribution start twice, archive integrity, native plugin parity, two 64-scenario sweeps, and Web artifact smoke. | Runtime passed; two release-identity/custody defects confirmed. |
| Extended game fuzz | 3.5M Scratch outcomes, >40M Craps rolls, 60K Slot outcomes, 2K Baccarat hands, 200 Roulette seeds, and 22,800 stuck-state scenarios. | Statistical/rules bands passed; one rejected-transaction history leak confirmed. |
| Extended progression/economy | 55 scenarios, 1,485 pair comparisons, 89 items, 18 services, 5 lenders, 13 Crew jobs, 12 routes, and two-seed transaction controls. | Catalog/finalization passed; one debt-boundary atomicity defect confirmed. |
| Extended persistence | 56 production-codec checks, 16 corruption fallbacks, historical/current fixtures, sync/async oversized saves, and six relaunch cycles. | Ordinary recovery passed; oversized encode failure can be installed as a successful save. |
| Extended package/input | Three PCK manifests, native-backend parity, four responsive sizes, two full 18-room accessibility cycles, and controller InputMap inspection. | Four accessibility and two package-custody defects confirmed. |
| Audio/feedback lifecycle | Two production-scene runs plus static ownership/control-flow review of composition identity, pause overlays, decoded buffers, native/Web mute, malformed settings, and WebAudio failures. | Four defects reproduced 4/4; two additional lifecycle/failure-contract defects confirmed statically. |
| Lifecycle/recovery | Static tracing of focus/minimize notifications, simulation owners, surface capture cancellation, Settings draft/preview state, quit/save boundaries, and main-menu cleanup. | Three non-duplicate lifecycle defects confirmed; close/save and cleanup paths otherwise have explicit recovery. |
| Localization/player text | Static inventory of authority errors, currency-routing copy, game-clock formatters, singular counts, UTF-8, parsing, and truncation sites; packaged text captures cross-checked. | Four current English text defects retained; missing localization infrastructure recorded as an uncounted readiness limitation. |
| Extended endurance/liveness | Three independent 360-minute runs; 6,048 total action attempts, 258 save/load cycles, 1,868 travel attempts, 131 generated runs, cache stress, and instrumented failure classification. | All memory/state/cache gates passed; semantic-proof drift and compact rollback recovery defects confirmed. |

### Validation standard

A visible symptom had to reproduce at least twice or be deterministic across the entire generated sample.
The report distinguishes direct interaction-rectangle intersections from spacing-only footprint warnings.
Root causes were traced to checked-in data, runtime layout/selection code, or shared UI policy with exact source references.
Harness failures were challenged against the actual player path. SaveService/RunSaveCodec evidence overruled a raw-JSON false positive.
No defect was fixed; proposed options are for a later implementation pass.

### Root-cause clusters

| Cluster | Affected findings | Engineering implication |
| --- | --- | --- |
| Exact placement bypass | UIE-002–008, 014, 016, 017 | Checked-in developer coordinates are treated as exact and skip recovery; promotion needs direct-hit validation. |
| Exhausted placement accepted | UIE-001, 009, 011, 015 | When no candidate fits, the colliding rectangle is stored with no placement error. |
| Duplicate route slots | UIE-010, 012, 013, 020 | Independent route categories can author the same doorway coordinate; route authority needs consolidation. |
| Audit suppression | UIE-018–021 | Developer-placement rooms bypass scenario/base collision accounting, producing false clean reports. |
| Fixed surface geometry | UIE-022-A/B | Bar Dice panels, patrons, and dealer widgets are drawn from unrelated fixed-coordinate systems. |
| Text/asset constraints | UIE-023–025 | Hard width caps, destructive prefix fitting, and clipped raster title art reduce legibility. |
| Tutorial dependency/focus ordering | GP-01 | Focus is cleared using the first dependent lesson rather than the final active lesson after out-of-order progress. |
| Accessibility policy fragmentation | A11Y-001–005 | Focusable controls, target sizing, dynamic scaling, modal cancel, and reduced motion are implemented inconsistently. |
| Release provenance | PKG-001/002 | Versioning, staging, and an immutable cross-platform manifest must tie every upload artifact to one source/build identity. |
| Responsive/modal input authority | A11Y-006–009 | Popup focus, supported minimum geometry, large-text layout, and global controller mappings need one shared policy. |
| Save error-contract gap | PERSIST-EXT-01 | Codec packing failure must stop before generation rotation, success bookkeeping, or player-facing confirmation. |
| Transaction isolation | EXT-GAME-001; XPE-01 | Fallible boundaries occur after result construction/application, allowing history or rewards to escape rejected or underfunded operations. |
| Export custody and hygiene | EXT-PKG-003/004 | Packed manifests need development-file exclusions and every executable-looking artifact must retain its required side libraries. |
| Audio identity and lifecycle | EXT-AUDIO-001–006 | Composition keys omit audible profile fields; pause ownership, decoded-buffer eviction, hard mute, recovery, and bridge failure contracts are fragmented. |
| Application lifecycle ownership | LIFE-001–003 | OS focus/minimize events do not pause simulation or cancel captured holds, and Settings cancel does not fully restore committed global palette state. |
| Structured presentation text | EXT-TXT-001–004 | Game identity, authoritative currency, clock convention, and plural grammar are assembled before or outside the final presentation context. |
| Semantic proof and compact recovery | EXT-PERF-001/002 | Live producer context is mixed into immutable scenario identity, while Coin Pusher rollback depends on reference identity surviving the failed transaction. |

## Consolidated bug index

| Report ID | Source ID | Severity | Area | Summary |
| --- | --- | --- | --- | --- |
| BTH-001 | UIE-001 | High | Environment layout | Bar ticket redeemer and slot share hit authority |
| BTH-002 | UIE-002 | High | Environment layout | Corner Store Odds Notebook and Trunk overlap |
| BTH-003 | UIE-003 | High | Environment layout | Corner Store Late Shift Discount and merchant overlap |
| BTH-004 | UIE-004 | Medium | Environment layout | Corner Store Late Shift Discount and Cashier Tip overlap |
| BTH-005 | UIE-005 | High | Environment layout | Corner Store merchant and Cashier Tip overlap |
| BTH-006 | UIE-006 | High | Environment layout | Gas Station Pull Tabs and Scratch Tickets overlap |
| BTH-007 | UIE-007 | High | Environment layout | Gas Station drink and numbers book overlap |
| BTH-008 | UIE-008 | Medium | Environment layout | Gas Station Parking Lot Tip and Side Door overlap |
| BTH-009 | UIE-009 | Medium | Environment layout | Grand Casino slot bank controls overlap |
| BTH-010 | UIE-010 | Critical | Environment layout | Grand Casino Back Room route overlaps Blackjack |
| BTH-011 | UIE-011 | High | Environment layout | Grand Casino Craps overlaps ticket redeemer |
| BTH-012 | UIE-012 | Critical | Environment layout | Grand Casino Cage Main Floor and Leave routes overlap |
| BTH-013 | UIE-013 | Critical | Environment layout | Grand Casino High-Limit Cage and Leave routes almost completely overlap |
| BTH-014 | UIE-014 | High | Environment layout | House Storage Spot and Trunk overlap |
| BTH-015 | UIE-015 | Medium | Environment layout | Jazz Club Cello Round and ticket redeemer overlap |
| BTH-016 | UIE-016 | High | Environment layout | Motel Parking Lot Tip and Malik Stone overlap |
| BTH-017 | UIE-017 | Critical | Scenario layout | Bar Rowdy Regular and Bar Dice overlap under Dead Tuesday |
| BTH-018 | UIE-018 | High | Scenario layout | Coin Pusher and Dead Tuesday Patron Zone overlap |
| BTH-019 | UIE-019 | Critical | Scenario layout | Pull Tabs and Dead Tuesday task control overlap |
| BTH-020 | UIE-020 | Critical | Scenario layout | Leave and Dead Tuesday Safe Exit overlap |

### Consolidated bug index (continued)

| Report ID | Source ID | Severity | Area | Summary |
| --- | --- | --- | --- | --- |
| BTH-021 | UIE-021 | Critical | Scenario layout | Scenario layout audit falsely reports a clean room |
| BTH-022 | UIE-022-A | High | Game surface UI | Bar Dice Rail Cups panels obscure the left patron rail |
| BTH-023 | UIE-022-B | High | Game surface UI | Bar Dice dealer-status widgets cover Iris, the right-center patron |
| BTH-024 | UIE-023 | Medium | Text / presentation | Object labels silently truncate without ellipsis |
| BTH-025 | UIE-024 | Medium | Text / presentation | Grand Casino High-Limit title plate asset is clipped |
| BTH-026 | UIE-025 | Low | Text / presentation | Corner Store resolved label still covers another actionable object |
| BTH-027 | GP-01 | Medium | Tutorial / progression | Wrong-order Corner Store tutorial loses the actionable Buy target |
| BTH-028 | A11Y-001 | High | Accessibility / input | World-map destinations cannot be selected by keyboard |
| BTH-029 | A11Y-002 | Medium | Accessibility / input | Escape does not close the Settings modal |
| BTH-030 | A11Y-003 | High | Accessibility / input | Small-screen environment action targets are only 34 px high |
| BTH-031 | A11Y-004 | High | Accessibility / input | Rebuilt gameplay actions lose large-text and small-screen sizing |
| BTH-032 | A11Y-005 | Medium | Accessibility / input | TalkDock attention motion still runs with Reduce Motion enabled |
| BTH-033 | PKG-001 | High | Release packaging | Unreleased 0.6 packages identify themselves as published Version 0.5.1 and carry no embedded source identity |
| BTH-034 | PKG-002 | High | Release packaging | The Windows upload ZIP, loose itch executable, current Windows folder, and Web folder are different unbound build snapshots |
| BTH-035 | A11Y-006 | High | Accessibility / input | Decision popups leak keyboard focus to obscured controls |
| BTH-036 | A11Y-007 | High | Accessibility / input | World map is clipped at the code-enforced minimum safe window |
| BTH-037 | A11Y-008 | Medium | Accessibility / input | Large-text Settings extends below the minimum safe window |
| BTH-038 | A11Y-009 | High | Accessibility / input | Controller can navigate globally but cannot accept or cancel |

### Consolidated bug index (continued)

| Report ID | Source ID | Severity | Area | Summary |
| --- | --- | --- | --- | --- |
| BTH-039 | PERSIST-EXT-01 | High | Persistence integrity | Oversized save reports success, installs an unloadable primary, and loses or rolls back progress |
| BTH-040 | EXT-PKG-003 | Medium | Release packaging | Production PCKs disclose internal QA reports and native toolchain metadata |
| BTH-041 | EXT-PKG-004 | High | Release packaging | Loose itch Windows executable is missing its required native Coin Pusher DLL |
| BTH-042 | EXT-GAME-001 | Medium | Game authority / history | Rejected Blackjack transaction leaks a completed story record and retry duplicates it |
| BTH-043 | XPE-01 | High | Progression / economy | Debt boundary invalidates affordability, but purchase/service still commits |
| BTH-044 | EXT-PERF-001 | High | State integrity / recovery | Dynamic-room semantic digest drift blocks enabled travel and cascades into game-action rejection |
| BTH-045 | EXT-PERF-002 | Medium | State integrity / recovery | Coin Pusher compact rollback can reject its own token after a failed turn boundary |
| BTH-046 | EXT-AUDIO-001 | Medium | Audio / feedback / recovery | Music cache key reuses stale compositions across distinct scenarios, weather states, and unique jazz rooms |
| BTH-047 | EXT-AUDIO-002 | Medium | Audio / feedback / recovery | Run Menu and in-run Settings do not pause the game-surface clock or timed audio presentation |
| BTH-048 | EXT-AUDIO-003 | Medium | Audio / feedback / recovery | WebAudio and procedural PCM caches retain decoded audio for the entire page/app lifetime |
| BTH-049 | EXT-AUDIO-004 | Low | Audio / feedback / recovery | 0% volume is attenuation, not mute |
| BTH-050 | EXT-AUDIO-005 | Low | Audio / feedback / recovery | Malformed settings silently discard preferences with no player-visible recovery message |
| BTH-051 | EXT-AUDIO-006 | Low | Audio / feedback / recovery | WebAudio SFX delivery failures are ignored, dropping cues without retry or fallback |
| BTH-052 | LIFE-001 | High | Application lifecycle / recovery | Alt-tab or minimization does not suspend time-sensitive gameplay |
| BTH-053 | LIFE-002 | High | Application lifecycle / recovery | OS focus loss can strand or later complete a stale game-surface hold |
| BTH-054 | LIFE-003 | Medium | Application lifecycle / recovery | Settings Back can leak an unsaved High Contrast choice globally |
| BTH-055 | EXT-TXT-001 | Medium | Player text / formatting | Shared authority errors incorrectly identify non-Blackjack games as Blackjack |
| BTH-056 | EXT-TXT-002 | Medium | Player text / formatting | Grand Casino result copy reports dollars or “Bankroll” when the applied balance is chips |
| BTH-057 | EXT-TXT-003 | Low | Player text / formatting | Run outcome card switches to an inconsistent 24-hour clock without a suffix |
| BTH-058 | EXT-TXT-004 | Low | Player text / formatting | Hand-built grammar produces singular-count and sentence-joining errors |

## Representative visual evidence

These production and deterministic-capture frames illustrate the recurring failure modes. Exact pair geometry and source traces appear in the detailed findings.
Figure 1 — Grand Casino High-Limit: two route arrows share the right-side doorway, while the title raster ends at “LIMI”.
Figure 2 — Corner Store: exact promoted placements stack items and cashier/event controls in the same visual and interactive regions.
Figure 3 — Gas Station Casino: Pull Tabs/Scratch Tickets and the Parking Lot Tip/Side Door controls intersect.
Figure 4 — Bar Dead Tuesday: active scenario stations overlap base games, patrons, and exit authority while the audit reports zero collisions.
Figure 5 — Bar Dice: Rail Cups panels obscure left patrons and dealer-status widgets overprint the right-center patron.

## Detailed confirmed findings

### Environment layout

#### BTH-001 / UIE-001 — Bar ticket redeemer and slot share hit authority

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: High
Room/evidence: bar.png; game_hook:pull_tabs:ticket_redeemer ↔ game:slot
Direct intersection: 2,436 px²
Root cause: Bar authored slots are dense (data/environments/placement_surfaces.json:41). The ticket redeemer is automatically moved but the non-manual recovery path accepts the colliding selection after no supported alternative succeeds (environment_instance.gd:715-736).
Fix options: add a valid nonoverlapping behind-counter candidate; move one authored slot; or make unresolved collision a placement error instead of silently accepting it.

#### BTH-002 / UIE-002 — Corner Store Odds Notebook and Trunk overlap

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: High
Evidence: corner_store.png; item:odds_notebook ↔ item:trunk
Direct intersection: 3,360 px²
Root cause: the shipped category override for item_spots:1 places an item at [189,144] (developer_placement_overrides.json:87); manual placement bypasses collision recovery and lands on the trunk.
Fix options: move the notebook/trunk; validate checked-in overrides; reject promotion of overlapping developer placements.

#### BTH-003 / UIE-003 — Corner Store Late Shift Discount and merchant overlap

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: High
Evidence: corner_store.png; event:late_shift_discount ↔ shopkeeper:merchant
Direct intersection: 2,304 px²
Root cause: event_spots:1 and the merchant have conflicting checked-in developer coordinates (developer_placement_overrides.json:75, 113), and manual coordinates bypass recovery.
Fix options: separate the event and cashier counter person; reserve the merchant footprint; gate project overrides with direct-hit validation.

#### BTH-004 / UIE-004 — Corner Store Late Shift Discount and Cashier Tip overlap

Severity: Medium   |   Confidence: High   |   Status: Confirmed
Severity: Medium
Evidence: corner_store.png; event:late_shift_discount ↔ service:cashier_tip
Direct intersection: 228 px²
Root cause: the exact event override is accepted without testing later/generated service authority (environment_instance.gd:703-715).
Fix options: move the event; create a dedicated late-shift service slot; rerun collision packing after all manual and generated entries are assembled.

#### BTH-005 / UIE-005 — Corner Store merchant and Cashier Tip overlap

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: High
Evidence: corner_store.png; shopkeeper:merchant ↔ service:cashier_tip
Direct intersection: 525 px²
Root cause: the merchant's checked-in exact override (developer_placement_overrides.json:113) does not reserve space against the generated service.
Fix options: merge Cashier Tip into the merchant action panel; move its prop; or enforce a project-override collision gate.

#### BTH-006 / UIE-006 — Gas Station Pull Tabs and Scratch Tickets overlap

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: High
Evidence: gas_station_casino.png; game:pull_tabs ↔ game:scratch_tickets
Direct intersection: 994 px²
Root cause: checked-in exact positions [430,126] and [526,127] are closer than the two 110×72 game controls can support (developer_placement_overrides.json:161-168).
Fix options: increase horizontal separation; reduce only the art footprint while preserving 44-pixel minimum targets; fail override promotion on intersection.

#### BTH-007 / UIE-007 — Gas Station drink and numbers book overlap

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: High
Evidence: gas_station_casino.png; service:house_drink ↔ numbers:book
Direct intersection: 378 px²
Root cause: checked-in exact positions [170,186] and [71,183] bypass collision recovery (developer_placement_overrides.json:173-180).
Fix options: move either counter service; combine them into a shared clerk surface; validate direct hit rectangles before shipping.

#### BTH-008 / UIE-008 — Gas Station Parking Lot Tip and Side Door overlap

Severity: Medium   |   Confidence: High   |   Status: Confirmed
Severity: Medium
Evidence: gas_station_casino.png; event:parking_lot_tip ↔ event:side_door
Direct intersection: 63 px²
Root cause: category overrides for successive event slots are placed at [693,344] and [792,345] (developer_placement_overrides.json:127-134); category overrides take precedence over object overrides at environment_instance.gd:699-705.
Fix options: move the side door to its dedicated doorway slot; treat doors as reserved; prevent category overrides from silently superseding a safer object-specific coordinate.

#### BTH-009 / UIE-009 — Grand Casino slot bank controls overlap

Severity: Medium   |   Confidence: High   |   Status: Confirmed
Severity: Medium
Evidence: grand_casino.png; game:slot ↔ game:slot:2
Direct intersection: 144 px²
Root cause: authored slot coordinates are only 126 pixels apart (placement_surfaces.json:381-383) while support correction produces 110-pixel controls plus intended spacing; the fallback path stores a collision without an error.
Fix options: widen the bank spacing; render one bank control for multiple cabinets; surface exhausted placement as a generation error.

#### BTH-010 / UIE-010 — Grand Casino Back Room route overlaps Blackjack

Severity: Critical   |   Confidence: High   |   Status: Confirmed
Severity: Critical
Evidence: grand_casino.png; travel:grand_casino_back_room ↔ game:blackjack
Direct intersection: 128 px²
Impact: a navigation control and a wagering game claim the same pointer area.
Root cause: route [0,176] and blackjack [120,176] are adjacent authored slots (placement_surfaces.json:385-387); support correction and final sizes still intersect, but the resolver records no placement error.
Fix options: reserve a route rail; move blackjack; make route/game intersections fatal in content validation.

#### BTH-011 / UIE-011 — Grand Casino Craps overlaps ticket redeemer

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: High
Evidence: grand_casino.png; game:craps ↔ game_hook:pull_tabs:ticket_redeemer
Direct intersection: 170 px²
Root cause: dense authored positions (placement_surfaces.json:385-386) exhaust available compatible surfaces and the unresolved collision is stored as valid.
Fix options: relocate redeemer to a cashier/fixture zone; add another supported floor surface; report/fail exhausted collision placement.

#### BTH-012 / UIE-012 — Grand Casino Cage Main Floor and Leave routes overlap

Severity: Critical   |   Confidence: High   |   Status: Confirmed
Severity: Critical
Evidence: grand_casino_cage.png; travel:grand_casino ↔ travel:leave
Direct intersection: 1,044 px²
Root cause: Cage authors the local casino door and generic travel spot at the same [824,350] coordinate (archetypes.json:4378-4389).
Fix options: remove redundant Leave in this subroom; give each route a unique slot; display a single route selector when destinations share a doorway.

#### BTH-013 / UIE-013 — Grand Casino High-Limit Cage and Leave routes almost completely overlap

Severity: Critical   |   Confidence: High   |   Status: Confirmed
Severity: Critical
Evidence: grand_casino_high_limit.png; travel:grand_casino_cage ↔ travel:leave
Direct intersection: 5,824 px²
Impact: the two orange arrows are drawn nearly on top of one another, making mouse authority and destination legibility unreliable.
Root cause: High-Limit room authors casino_door_spots[1] and travel_spots[0] both at [808,350] (archetypes.json:3978-3993).
Fix options: remove redundant Leave; split door positions; render a single doorway with explicit destination choices.

#### BTH-014 / UIE-014 — House Storage Spot and Trunk overlap

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: High
Evidence: house.png; home_storage:place ↔ home_container:trunk_01
Direct intersection: 810 px²
Root cause: exact project overrides [320,293] and [231,297] conflict (developer_placement_overrides.json:219-230) and manual placements bypass collision recovery.
Fix options: move the controls; represent Storage Spot as a panel action on the trunk; validate project overrides.

#### BTH-015 / UIE-015 — Jazz Club Cello Round and ticket redeemer overlap

Severity: Medium   |   Confidence: High   |   Status: Confirmed
Severity: Medium
Evidence: jazz_club.png; service:jazz_cello_round ↔ game_hook:pull_tabs:ticket_redeemer
Direct intersection: 252 px²
Root cause: dense authored service/wall placements (placement_surfaces.json:131-132) leave no valid alternative; the automatic path silently accepts a collision (environment_instance.gd:715-736).
Fix options: move the redeemer to the bar; add a dedicated supported wall slot; fail unresolved placement.

#### BTH-016 / UIE-016 — Motel Parking Lot Tip and Malik Stone overlap

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: High
Evidence: motel.png; event:parking_lot_tip ↔ lender:motel_friend
Direct intersection: 936 px²
Root cause: exact project overrides [33,345] and [115,357] conflict (developer_placement_overrides.json:235-254) and bypass recovery.
Fix options: move lender/tip; sequence one through dialogue instead of separate floor props; validate promoted overrides.

### Scenario layout

#### BTH-017 / UIE-017 — Bar Rowdy Regular and Bar Dice overlap under Dead Tuesday

Severity: Critical   |   Confidence: High   |   Status: Confirmed
Severity: Critical
Evidence: .tmp/agent_playtest_24h_ui/0016.png; event:rowdy_regular ↔ game:bar_dice
Direct intersection: 3,920 px²
Root cause: checked-in developer override moves Bar Dice to [65,146], while the base Rowdy Regular remains at [77,178] (developer_placement_overrides.json Bar section; placement_surfaces.json:41). Project developer placement is accepted as authoritative.
Fix options: move Bar Dice back to a machine zone; reserve its footprint against base events; reject intersecting project overrides.

#### BTH-018 / UIE-018 — Coin Pusher and Dead Tuesday Patron Zone overlap

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: High
Evidence: 0016.png; game:coin_pusher ↔ scenario::bar_dead_tuesday_patron_zone
Direct intersection: 1,152 px²
Root cause: scenario slot bar_dead_tuesday_patron_zone:[300,266] conflicts with active base controls (placement_surfaces.json:42); Bar's developer-placement status suppresses normal scenario collision enforcement.
Fix options: provide a scenario fallback slot; reserve all current base hitboxes during scenario layout; never suppress scenario/base validation for project overrides.

#### BTH-019 / UIE-019 — Pull Tabs and Dead Tuesday task control overlap

Severity: Critical   |   Confidence: High   |   Status: Confirmed
Severity: Critical
Evidence: 0016.png; game:pull_tabs ↔ scenario::bar_dead_tuesday_task_0
Direct intersection: 2,916 px²
Root cause: the scenario task is authored at [316,188] while Pull Tabs occupies the same central band (placement_surfaces.json:41-42); developer-room suppression allows the collision.
Fix options: place the task in a dedicated wall slot; relocate base machine while scenario is active; enforce scenario/base interaction disjointness.

#### BTH-020 / UIE-020 — Leave and Dead Tuesday Safe Exit overlap

Severity: Critical   |   Confidence: High   |   Status: Confirmed
Severity: Critical
Evidence: 0016.png/0017.png; travel:leave ↔ scenario::bar_dead_tuesday_safe_exit
Direct intersection: 94 px²
Root cause: both controls target the right exit rail, and checked-in Bar route overrides make the whole room developer-placed. The scenario resolver therefore skips the ambiguous route check.
Fix options: reuse one exit authority instead of drawing two; offset the scenario marker; keep route-vs-route intersections fatal even in developer placement mode.

#### BTH-021 / UIE-021 — Scenario layout audit falsely reports a clean room

Severity: Critical   |   Confidence: High   |   Status: Confirmed
Severity: Critical
Frequency: 100% in the captured Bar Dead Tuesday state
Evidence: 0016.result.json reports room_canvas.object_layout.overlap_count=9, while scenario_layout_audit.normal_overlap_count=0, small_screen_overlap_count=0, collision_adjustment_count=0, and valid=true.
Root cause: _overlap_count returns zero for the entire room when any developer placement exists (scenario_layout_resolver.gd:1620-1643). Related validation loops also skip developer-placed targets/rooms (824-847). Checked-in project overrides therefore disable safety gates in ordinary production content, not merely an editor preview.
Fix options: distinguish temporary user freeform edits from shipped project data; always calculate and report overlaps even if nonfatal; make route and actionable control collisions nonwaivable.

### Game surface UI

#### BTH-022 / UIE-022-A — Bar Dice Rail Cups panels obscure the left patron rail

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: Major / P2 Frequency: 2/2 consecutive production frames Area: Bar Dice, in-game table readability Evidence: .tmp/agent_playtest_24h_ui/0013.png, .tmp/agent_playtest_24h_ui/0014.png
Reproduction
- 1. Enter a Bar Dice table with the normal four-patron production layout.
- 2. Advance to a hand in which opponent cup rows are visible.
- 3. Inspect the left rail around the first patron and the Rail Cups panel stack.
Expected: Opponent dice, patron identity, body-language tell, and character art each occupy readable, non-overlapping regions.
Actual: The Rail Cups stack is painted across the left patron rail. Patron names/tells are clipped or hidden behind the three opaque dice panels, and parts of the character presentation are visually disconnected from their labels.
Measured geometry: The first opponent panel is Rect2(68, 136, 164, 48). Patron 0's declared safe region is Rect2(44, 30, 142, 158). Their intersection is 118 × 48 = 5,664 design-space pixels. The next two opponent rows continue down the same x-range, so the obstruction persists through the remaining left-side identity/tell rows.
Root cause: scripts/games/bar_dice.gd:70-80 hard-codes opponent row origins at x=76 while placing the first patron at x=94. _draw_opponent_dice_rows() constructs 164×48 panels beginning eight pixels left of those origins (scripts/games/bar_dice.gd:3191-3208). Patron safe rectangles are independently derived as 142×158 regions around the hard-coded patron positions (scripts/games/bar_dice.gd:3495-3500). No layout solver or collision check relates these two systems. Draw order makes the defect destructive: patrons are drawn first and dice rows later (scripts/games/bar_dice.gd:552-565), so the opaque row panels cover the patron content.
Why existing tests missed it: scripts/tests/foundation/check_table_games.gd:7444-7467 validates text_panel_rects against patron_safe_rects and patron-safe rectangles against each other. Rail Cups rectangles are not exported into either tested collection.
Fix options (for a later implementation agent):
Move opponent rows to a dedicated rail lane that does not intersect any patron safe rectangle.
Shift the left patron positions right/up and reserve the full Rail Cups stack before seating patrons.
Preferably expose opponent-panel rectangles as layout metadata and add a general pairwise collision assertion against patron safe rectangles. This prevents the same failure from returning when row count or scaling changes.

#### BTH-023 / UIE-022-B — Bar Dice dealer-status widgets cover Iris, the right-center patron

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: Major / P2 Frequency: 2/2 consecutive production frames Area: Bar Dice, attention/tell readability Evidence: .tmp/agent_playtest_24h_ui/0013.png, .tmp/agent_playtest_24h_ui/0014.png
Reproduction
- 1. Enter the same Bar Dice production table.
- 2. Observe the dealer attention meter, danger/gaze meter, and calls cargo/read-window panel at center-right.
- 3. Compare those widgets with Iris's sprite, name, and tell.
Expected: Dealer attention information and the neighboring patron presentation are simultaneously legible.
Actual: The fixed dealer widgets run through Iris's sprite and text. In both observed frames, meter captions and Iris's name/tell are layered into one unreadable block.
Measured geometry: Iris uses patron position (660, 70), giving declared safe region Rect2(610, 16, 142, 158). The shared dealer renderer places widgets at Rect2(566, 92, 118, 9), Rect2(566, 116, 118, 6), and Rect2(566, 130, 122, 22). Those three intersections occupy 666, 444, and 1,716 design-space pixels respectively, or 2,826 pixels total inside Iris's safe region.
Root cause: Bar Dice uses the shared fixed-coordinate draw_dealer_station() without adapting its right-side widget lane to Bar Dice's custom patrons. The station always writes its meters/panel from x=566 through x=688 (scripts/games/table_game_visuals.gd:139-178), while Bar Dice fixes the third patron around x=660 (scripts/games/bar_dice.gd:75-80). As with UIE-022-A, these rectangles are absent from the collision metadata used by the test.
Fix options (for a later implementation agent):
Supply Bar Dice-specific status-widget bounds that fit inside the central dealer station.
Move Iris to a genuinely free right rail position and recompute patron safe rectangles from the final layout.
Make the shared dealer renderer return/export its occupied rectangles, then validate them against each game's patron-safe regions.

### Text / presentation

#### BTH-024 / UIE-023 — Object labels silently truncate without ellipsis

Severity: Medium   |   Confidence: High   |   Status: Confirmed
Severity: Medium
Evidence: fresh gas_station_casino.png shows Gas Station Casino Numbers B; current-date 0017.png shows Bar Dead Tu. The full identities remain different from the visible labels.
Expected: long labels wrap, scale, or show an ellipsis/tooltip so the truncation is perceptible.
Actual: trailing characters disappear, creating ambiguous names.
Root cause: object label width is hard-capped at 126 pixels (pixel_scene_canvas.gd:92, 5059-5068). _fit_draw_text removes one trailing character at a time until the text fits and returns the bare prefix with no ellipsis (3878-3896); _draw_object_label renders it directly (5336-5352).
Fix options: reserve ellipsis width; expose full tooltip/accessibility text; allow a two-line label for long route/source names.

#### BTH-025 / UIE-024 — Grand Casino High-Limit title plate asset is clipped

Severity: Medium   |   Confidence: High   |   Status: Confirmed
Severity: Medium
Frequency: 100%
Evidence: fresh grand_casino_high_limit.png and source asset assets/art/ui/environment_titles/grand_casino_high_limit.png both end at GRAND CASINO HIGH LIMI.
Root cause: the bitmap itself contains clipped text. EnvironmentHeader uses title art by default (scripts/ui/environment_header.gd:28-37) and the High-Limit config does not opt into text mode (data/ui/environment_ui.json). The texture widget preserves aspect rather than generating accessible visible text (environment_header.gd:87-101).
Fix options: regenerate the asset with adequate right padding; use title_mode:text for long titles; add asset-content bounds visual QA.

#### BTH-026 / UIE-025 — Corner Store resolved label still covers another actionable object

Severity: Low   |   Confidence: High   |   Status: Confirmed
Severity: Low
Evidence: fresh report: corner_store.canvas_object_layout.label_layout.resolved_object_overlap_count=1; the resolved label for event:late_shift_discount intersects service:cashier_tip by 15 px².
Root cause: the label resolver removes label-label collisions but cannot fully satisfy the crowded manual object layout; it accepts one label-object collision. The underlying checked-in placements already overlap.
Fix options: resolve the object positions first; permit another label row; hide labels until focus when density exceeds the layout budget.

### Tutorial / progression

#### BTH-027 / GP-01 — Wrong-order Corner Store tutorial loses the actionable Buy target

Severity: Medium   |   Confidence: High   |   Status: Confirmed
Severity: P2 / Medium Frequency: 2/2 dedicated regressions plus one instrumented reproduction Player impact: confusing progression friction and apparent tutorial stall; recoverable only by manually reselecting Coffee Affected flow: first-night tutorial, Corner Store, Coffee/Pencil ordering

#### Reproduction

- 1. Start the first-night tutorial and travel to the Corner Store.
- 2. Inspect Coffee as directed.
- 3. Inspect and buy the Pencil before buying Coffee.
- 4. Return focus to Coffee and allow already-satisfied intermediate lessons to advance.
- 5. Observe the final “buy remaining Coffee” lesson.

#### Expected

Coffee remains selected and the coach ring targets the Coffee Buy action. The player can immediately perform the required action.

#### Actual

The Coffee selection is cleared. The selected-info/action panel is hidden and its action rect is Rect2(0, 0, 0, 0). The coach falls back to the shelf-object rectangle instead of the Buy action. Instrumented state at failure:
Coffee offer exists and is affordable ($8; bankroll $66).
Shelf object is enabled and advertises buy_item.
selected_info.visible == false.
The highlighted rect is the Coffee shelf object (117.58,253.84 120.56x72.33), not the action control.
The run is not permanently dead: clicking/re-focusing the object can recover it. However, the prescribed action is unavailable at the moment the tutorial says to take it, and the visual instruction points to the wrong control.

#### Root cause

FoundationMain._resume_after_completed_tutorial_action() clears stale focus before it resolves the final active lesson (scripts/ui/foundation_main.gd:16381-16392). _clear_stale_focus_before_dependent_tutorial_target() examines only the first directly authored dependent and returns (16395-16411). It does not skip dependents that the player already satisfied out of order, nor compare the selected object with the eventual active lesson.
Once selection is cleared, PixelSceneCanvas only exposes the action rectangle for the selected object (scripts/ui/pixel_scene_canvas.gd:4839-4845). The tutorial target resolver then falls back to the shelf object (scripts/ui/foundation_main.gd:15003-15006). The lesson graph is therefore advanced correctly, but focus state and coach geometry are resolved against different lessons.

#### Fix options

- 1. Resolve/refresh the final active lesson first, then clear selection only if that lesson truly targets a different object.
- 2. When walking dependencies, skip already-complete or currently ineligible lessons before making the focus decision.
- 3. As a defensive UI measure, when an action-target lesson activates for the same object, restore that object's selection before resolving the action rect.
- 4. Keep the wrong-order regression as a required tutorial gate and assert that both selected_info.visible and the buy_item action rect are non-empty.

#### Evidence

.tmp/playtest_2026-09-20/gameplay_progression/tutorial_visible/tutorial_corner_shop_order_check.*
.tmp/playtest_2026-09-20/gameplay_progression/tutorial_repros/tutorial_corner_shop_order_check.*
.tmp/playtest_2026-09-20/gameplay_progression/diagnostics/corner.stdout.log
Regression route: scripts/tests/tutorial_corner_shop_order_check.gd:65-104

### Accessibility / input

#### BTH-028 / A11Y-001 — World-map destinations cannot be selected by keyboard

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: High
Frequency: 100%; reproduced in both probe runs and all generated map-node buttons use the same constructor
Affected input: keyboard, switch input mapped through focus navigation, and assistive technology that depends on focusable controls
Reproduction:
- 1. Open the world map without using a pointer after it appears.
- 2. Attempt to Tab to a destination or use directional navigation to select one.
- 3. Observe that destination nodes never receive focus; only a prior control or ordinary overlay button can participate in focus traversal.
Expected: every revealed destination has a focusable, named target; focus enters the map on open; directional or Tab navigation can select a destination and then reach Travel.
Actual: the destination hit targets have focus_mode=FOCUS_NONE (0) and empty button text. The only label is a pointer tooltip. The controller contains pointer callbacks but no keyboard node-selection route.
Evidence: world_map_nodes[0] records focus_mode:0, text:"", tooltip:"Stop A", and visible:true. The same result was produced twice.
Root cause:
_hit_button creates a flat, empty Button and explicitly assigns Control.FOCUS_NONE (scripts/ui/world_map_overlay_controller.gd:717-731).
Node labels are stored only in tooltip_text (world_map_overlay_controller.gd:527-554, 557-581).
Opening the overlay clears room selection and shows the map but does not place focus inside it (scripts/ui/foundation_main.gd:3785-3804).
The map’s Close button is a local variable, preventing the controller from using it as a deterministic entry focus (foundation_main.gd:10007-10009).
Impact: map travel is a core progression boundary. A keyboard-only player cannot complete it without a pointer.
Fix options:
- 1. Make revealed node buttons focusable, assign accessibility_name/visible text from the node label, and implement roving spatial focus between map nodes.
- 2. Store the Close button and move focus to the nearest revealed node or Close when the overlay opens; restore prior focus when it closes.
- 3. Add a keyboard-accessible destination list synchronized with the visual map if spatial navigation is undesirable.
- 4. Add an automated contract that selects and confirms a destination using only key events.

#### BTH-029 / A11Y-002 — Escape does not close the Settings modal

Severity: Medium   |   Confidence: High   |   Status: Confirmed
Severity: Medium
Frequency: 2/2 direct reproductions
Reproduction:
- 1. Open Settings.
- 2. Press Escape.
- 3. Repeat after closing/reopening Settings.
Expected: Escape cancels or closes the modal and returns focus to the control that opened it.
Actual: Settings remains visible and emits no back_requested signal. The probe recorded visible_after_escape:true and back_signal_count:0 in both iterations.
Root cause:
SettingsMenu._input handles Tab trapping only and contains no ui_cancel branch (scripts/ui/settings_menu.gd:178-196).
The application-level input router only handles web-audio gestures and TalkDock hotkeys (scripts/ui/foundation_main.gd:778-784); it does not route modal cancel.
The existing focus-return implementation runs only after some other path hides Settings (settings_menu.gd:204-219).
Impact: mouse users have a Back button, but keyboard users lose the standard modal cancel path and must traverse the entire Settings focus loop to reach Back.
Fix options:
- 1. Add ui_cancel handling to SettingsMenu that emits back_requested and marks the event handled.
- 2. Prefer a central modal-cancel router with explicit priority so Escape closes only the topmost dismissible overlay.
- 3. Add two tests: Escape after opening from the main menu and Escape after opening from the run menu, both asserting focus restoration.

#### BTH-030 / A11Y-003 — Small-screen environment action targets are only 34 px high

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: High on touch devices; Medium elsewhere
Frequency: 100%; identical in both probe runs
Reproduction:
- 1. Enable “Play on small screen.”
- 2. Focus an environment object with a primary or inline detail action.
- 3. Measure the action hit rectangle.
Expected: interactive controls meet the project’s 52 px small-screen target policy and never fall below the project’s 44 px native minimum.
Actual: both primary and inline action heights are 34 px. The evidence records primary:34, inline:34, minimum_native:44, and small_screen_control_target:52.
Root cause:
The small-screen policy hard-codes ENVIRONMENT_ACTION_HEIGHT and ENVIRONMENT_INLINE_ACTION_HEIGHT to 34 (scripts/ui/small_screen_policy.gd:14-15) even though the same policy defines CONTROL_TOUCH_TARGET_HEIGHT=52 (small_screen_policy.gd:10).
PixelSceneCanvas returns those 34 px constants when small-screen mode is active (scripts/ui/pixel_scene_canvas.gd:3982-3987) and uses them for drawn action rectangles (pixel_scene_canvas.gd:4071-4082, 4436-4443).
Impact: the preference promises larger controls and tap areas, but these gameplay-critical actions remain 18 px smaller than that promise and 10 px smaller than the standard minimum.
Fix options:
- 1. Set both small-screen action heights to at least 52 px and recompute detail-card height/placement.
- 2. If visual rows must remain compact, retain the visual 34 px row but expand each nonoverlapping hit rectangle to 52 px.
- 3. Add a layout audit that enumerates every clickable rect, not only native Buttons, under small-screen mode.

#### BTH-031 / A11Y-004 — Rebuilt gameplay actions lose large-text and small-screen sizing

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: High
Frequency: 2/2 direct reproductions; the helper has 51 call sites
Reproduction:
- 1. Enable Large text, UI Scale 130%, and Play on small screen, then apply.
- 2. Trigger a gameplay refresh that rebuilds an environment/event/numbers action card.
- 3. Inspect the newly created action buttons.
Expected: dynamically created controls inherit the active accessibility font scale and the 52 px small-screen minimum.
Actual: new card buttons are created at the unscaled defaults: 13 px font and 44 px height. Both probe iterations reported font_size:13, height:44, and expected_small_screen_height:52.
Root cause:
Applying settings transforms the existing tree first, then rerenders gameplay snapshots (scripts/ui/foundation_main.gd:16259-16268).
Rerendered cards call _add_card_button, which directly delegates to FoundationWidgets.add_card_button without applying the host’s active accessibility transform (foundation_main.gd:19936-19937).
The shared helper always authors 44 px / 13 px defaults (scripts/ui/foundation_widgets.gd:37-54, 77-83).
The host’s accessible _button path does apply current small-screen sizing (foundation_main.gd:20760-20764), but the dynamic card helper bypasses it.
Impact: settings screens pass their target-size checks while core gameplay actions silently revert after refresh, creating inconsistent text and touch sizes precisely where the player acts.
Fix options:
- 1. Route dynamic action construction through the host’s accessibility-aware _button helper.
- 2. Apply _apply_accessibility_to_node to every newly created subtree before it becomes interactive.
- 3. Reorder settings application so rerender completes before the recursive transform, while still making future dynamic creation accessibility-aware.
- 4. Extend tests to apply settings, rebuild an environment card and an event popup, then assert effective font and target sizes.

#### BTH-032 / A11Y-005 — TalkDock attention motion still runs with Reduce Motion enabled

Severity: Medium   |   Confidence: High   |   Status: Confirmed
Severity: Medium
Frequency: 2/2 direct reproductions
Reproduction:
- 1. Enable Reduce Motion.
- 2. Present a new TalkDock entry.
- 3. Inspect the dock panel and portrait immediately after the entry changes.
Expected: the entry appears in its settled state with no fade or scale tween.
Actual: the panel starts at alpha 0.88, the portrait starts at scale 1.04, and an attention tween is created. Repeating the presentation created a second tween while reduce_motion:true remained active.
Root cause:
Every new TalkDock entry unconditionally calls _play_attention_animation (scripts/ui/talk_dock.gd:324-343).
set_reduce_motion completes the typewriter and updates the portrait idle-animation policy, but does not cancel/normalize attention tweens (talk_dock.gd:535-541).
_play_attention_animation has no reduced-motion guard and always applies alpha/scale offsets plus 0.12/0.18-second tweens (talk_dock.gd:1307-1319).
CoachOverlay implements the missing pattern correctly by returning early when reduced motion is active (scripts/ui/coach_overlay.gd:971-978), confirming the intended policy.
Impact: recurring dialogue produces motion despite an explicit user preference intended to suppress it.
Fix options:
- 1. Return early from _play_attention_animation when reduce_motion is true after normalizing panel alpha and portrait scale.
- 2. When Reduce Motion is enabled mid-animation, kill active attention tweens and settle both controls immediately.
- 3. Add a test that presents two consecutive entries with Reduce Motion enabled and asserts no valid tween and settled transforms.

### Release packaging

#### BTH-033 / PKG-001 — Unreleased 0.6 packages identify themselves as published Version 0.5.1 and carry no embedded source identity

Severity: High   |   Confidence: High   |   Status: Confirmed
Classification: packaging/release identity; do not count as a current-source gameplay bug.
Severity: High / release blocker. If any tested local artifact is handed to a player or uploaded, its visible and operating-system identity collides with an immutable public release while its content is materially newer and different.
Frequency: 100% on all three inspected Windows executables and the tested Web start menu.
Reproduction:
- 1. Inspect the Windows file/product version of builds/windows/BeatTheHouse.exe, the EXE inside the Windows upload ZIP, or the loose itch EXE. Each reports 0.5.1.
- 2. Open builds/web/index.html through the production-compatible local server. The lower-right start-menu copy visibly says Version 0.5.1.
- 3. Compare hashes and sizes with docs/plans/0.5.1_release_checklist.md; neither local upload ZIP matches the immutable published 0.5.1 artifact.
- 4. Search the packages for a commit/tree/candidate manifest. No artifact-owned commit identity is present; performance telemetry accepts a caller-provided bth_perf_source_commit, so it cannot independently prove which source was exported.
Player/operator impact:
Bug reports and saves cannot be reliably attributed to a source boundary.
A local 0.6 playtest build can be mistaken for the published 0.5.1 release in screenshots, Windows Properties, or an upload channel.
Support cannot distinguish the three different Windows binaries because all share the same product/version identity.
Root cause:
project.godot:19 holds config/version="0.5.1" for the unreleased development line.
export_presets.cfg:26-27 stamps the Windows file and product versions as 0.5.1.
scripts/ui/foundation_main.gd:17384-17389 renders that project setting directly as the player-visible version.
tools/export_itch.ps1:46-52,194 reads the same value, and its packaging phase records a console hash but does not place a source/version manifest inside the artifact.
The README says the retained 0.5.1 stamp is intentional until release06_1; the defect arises because runnable/exported 0.6 artifacts exist without an equally visible development identity or a packaging guard.
Fix options (not implemented):
- 1. Stamp playtest exports as 0.6.0-dev+<short-commit> and display that identity in the menu while preserving the published release tag.
- 2. Embed a machine-readable manifest containing version, commit, tree, dirty-state digest, engine hash, export-preset hash, platform, and native-library hash; make telemetry read it rather than trusting a caller string.
- 3. Refuse packaging/upload when the version equals an immutable published tag but the exact source tree and artifact hashes do not match that tag's release record.

#### BTH-034 / PKG-002 — The Windows upload ZIP, loose itch executable, current Windows folder, and Web folder are different unbound build snapshots

Severity: High   |   Confidence: High   |   Status: Confirmed
Classification: package custody/platform skew; do not count as a current-source gameplay bug.
Severity: High / release blocker for distribution, Medium for internal playtesting.
Frequency: 100% of integrity comparisons.
Reproduction:
- 1. Extract builds/itch/BeatTheHouse-windows.zip and hash its executable.
- 2. Hash builds/windows/BeatTheHouse.exe and builds/itch/BeatTheHouse.exe.
- 3. Observe three different sizes and SHA-256 values, even though all claim Version 0.5.1.
- 4. The Web PCK is dated 2026-09-17 while the current Windows executable is dated 2026-09-19. Eighteen commits have commit timestamps after the Web PCK and seven after the current Windows EXE. Because no embedded manifest exists, the exact included boundary cannot be proven.
- 5. The archive's native Coin Pusher DLL does match the current Windows DLL, demonstrating that a matching dependency does not establish a matching game payload.
Player/operator impact:
Uploading BeatTheHouse-windows.zip would not distribute the executable that was just smoke-tested from builds/windows.
Web and Windows test notes may describe different code, including fixes committed between their timestamps (tutorial flow, frozen Pinball/Coin Pusher sessions, travel recovery, casino interactions, Blackjack settlement, scenario-save recovery, and later performance work).
A pass on one platform cannot qualify the other artifact.
Root cause:
builds/ is ignored at .gitignore:19, so multiple opaque products persist outside source control and custody review.
tools/export_itch.ps1:252-258 archives the current output directory but does not require an artifact manifest, compare the resulting archive payload back to a named candidate, or quarantine older loose executables.
Exporting Windows and Web is independent; no common-candidate assertion binds the two directories and ZIPs as a release pair.
Fix options (not implemented):
- 1. Export both platforms into a new versioned staging directory keyed by commit/tree, then package only from that immutable staging root.
- 2. Generate and verify a cross-platform manifest; require the same candidate commit/tree in both products and compare every archived file hash with the staged directory before upload.
- 3. Remove loose ambiguous executables from the upload directory and name internal artifacts with version, platform, and short commit. Keep only one candidate set at a time or quarantine superseded builds.

### Accessibility / input

#### BTH-035 / A11Y-006 — Decision popups leak keyboard focus to obscured controls

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: High
Frequency: 2/2 fresh production-scene repetitions
Affected users: keyboard-only players, controller/switch users routed through focus navigation, screen-reader users, and any player who mixes pointer and keyboard input
Reproduction:
- 1. Put focus on the main-menu Settings button.
- 2. Open a dismissible meta decision popup with a visible Back choice.
- 3. Observe focus after the popup appears.
- 4. Press Escape, then Enter.
- 5. Query the production overlay contract.
Expected: focus moves to a meaningful choice inside the popup, Tab/focus stays within it, Escape closes the dismissible popup, and underlying controls cannot activate.
Actual: focus remains on the obscured Settings button. Escape does not close the popup. Enter activates Settings behind it, leaving both Settings and the decision popup visible. current_overlay_state_snapshot() returns contract_valid:false with decision_popup overlaps settings_visible in both repetitions.
Evidence:
focus_before, focus_after_show, and focus_after_escape are the same Settings button in both iterations.
first_choice_has_focus:false in both iterations even though the Back button exists.
popup_visible_after_escape:true, popup_visible_after_enter:true, and settings_visible_after_enter:true in both iterations.
Root cause:
_show_meta_popup() builds snapshot state, reveals the overlay, moves it to front, and positions it, but never calls grab_focus() or installs a focus trap (scripts/ui/foundation_main.gd:17061-17083).
The same show-without-focus pattern exists in triggered event popups (foundation_main.gd:4854-4904) and wager confirmation (13051-13077), so the defect is structural rather than meta-popup-specific.
Choice buttons are created as ordinary Buttons (foundation_main.gd:13080-13117), but no first-choice reference is focused after creation.
FoundationMain._input() handles web audio and TalkDock only (foundation_main.gd:778-784); it has no topmost-modal ui_cancel route.
_hide_event_choice_popup() clears the popup but does not restore a saved prior focus owner (foundation_main.gd:18975-19005).
Impact: a modal decision is not actually modal to keyboard input. Hidden actions can execute, overlays can stack illegally, and blocking event choices may leave focus on an unrelated background control.
Fix options:
- 1. Create a shared modal focus controller that stores the prior focus owner, focuses the preferred/first enabled choice on open, traps navigation, and restores focus on close.
- 2. Route ui_cancel by explicit topmost-overlay priority, honoring each popup snapshot's dismissible flag and refusing cancel for blocking decisions.
- 3. Guard global/open-overlay actions while a decision popup owns input; do not rely on draw order as an input barrier.
- 4. Add keyboard and controller tests for every event-popup constructor, including background-button activation and contract validity.

#### BTH-036 / A11Y-007 — World map is clipped at the code-enforced minimum safe window

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: High
Frequency: 2/2 static 640×360 presentations and 2/2 live-resize sequences
Affected configurations: small monitors where _safe_window_size() scales the selected 16:9 resolution down, plus any equivalent embedded/small-screen logical viewport
Reproduction:
- 1. Run at a 640×360 logical viewport, the safe-window lower bound.
- 2. Enable small-screen mode and open the world map.
- 3. Repeat by opening the map at 1280×720 and resizing through 960×540, 800×450, and 640×360.
Expected: the entire map panel, Close control, destinations, detail card, and Travel control remain within the visible viewport.
Actual:
At 640×360, the panel rect is x=-110, y=-90, w=860, h=540.
At 800×450, it is x=-30, y=-45, w=860, h=540.
It fits at 1280×720 and exactly vertically at 960×540, then clips identically in both resize repetitions.
Root cause:
The panel has a fixed 860×540 minimum and fixed center offsets of ±430/±270 (scripts/ui/foundation_main.gd:9978-9987).
Its holder and map layer retain 800×430 minimums (foundation_main.gd:10018-10027).
The small-screen accessibility update configures the map controller's target behavior but does not replace or clamp those host panel dimensions.
_safe_window_size() explicitly permits a 640-pixel width (scripts/core/user_settings.gd:264-276), so the window floor and modal minimum contradict each other.
Impact: Close, destinations, and Travel can lie partly or wholly outside the visible frame. This compounds A11Y-001, but it is a separate responsive-layout failure affecting pointer users too.
Fix options:
- 1. Clamp panel size to the viewport minus safe margins and replace fixed offsets with full-rect anchors plus a centered responsive container.
- 2. Scale or scroll the 800×430 map content at narrow sizes while keeping node hit targets at their small-screen minimum.
- 3. Recompute bounded geometry on NOTIFICATION_RESIZED while the overlay is open.
- 4. Add assertions for 1280×720, 960×540, 800×450, and the 640×360 safe-window floor.

#### BTH-037 / A11Y-008 — Large-text Settings extends below the minimum safe window

Severity: Medium   |   Confidence: High   |   Status: Confirmed
Severity: Medium
Frequency: 2/2 repeated minimum-window checks, plus the standalone matrix case
Configuration: 640×360 logical viewport, small-screen mode, Large text, UI scale 130%
Reproduction:
- 1. Present the game at the 640×360 _safe_window_size() floor.
- 2. Enable Play on small screen, Large text, and 130% UI scale.
- 3. Open Settings.
Expected: the outer Settings panel fits inside the viewport; its internal scroll region exposes every setting and the bottom action row.
Actual: the Settings rect is x=88, y=60, w=464, h=447 in a 640×360 logical viewport. Its bottom is at y=507, 147 pixels below the frame. The same geometry was recorded in both resize repetitions.
Boundary result: the same accessibility configuration fits at 960×540 (x=88, y=60, w=784, h=447) and at 1024×768.
Root cause:
The base overlay applies fixed 48-pixel top and bottom margins (scripts/ui/foundation_main.gd:9628-9631).
Small-screen policy changes only the left/right margins to 72 pixels (foundation_main.gd:20596-20603; scripts/ui/small_screen_policy.gd:18). It does not reduce or bound vertical margins.
The Settings list scroll container has a 300-pixel minimum (scripts/ui/settings_menu.gd:82); headings, section spacing, and the action row expand the outer menu beyond the remaining 264 vertical pixels.
Accessibility scaling correctly enlarges content but no outer ScrollContainer or viewport clamp absorbs the expansion.
Impact: the lowest actions can be visually inaccessible on the runtime's own minimum safe-window presentation. Keyboard focus can still move into off-screen controls, which makes focus disappear rather than solving access.
Fix options:
- 1. Make the modal panel height viewport-bounded and keep heading/action controls fixed while only the settings body scrolls.
- 2. Apply responsive vertical margins and remove the 300-pixel scroll minimum when available height is smaller.
- 3. Call ensure_control_visible() on focus changes so keyboard traversal never leaves the focused control off-screen.
- 4. Add 640×360 tests at every text/UI-scale combination, including visibility of Back, Restore Defaults, and Apply.

#### BTH-038 / A11Y-009 — Controller can navigate globally but cannot accept or cancel

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: High
Frequency: Deterministic configuration defect; directional path exercised in all 18 rooms in both cycles
Affected input: controller/gamepad outside the few surfaces with local hard-coded button handling
Reproduction:
- 1. Inspect the production InputMap and use a controller on a room or ordinary Godot Button screen.
- 2. Move selection with D-pad or left stick.
- 3. Press the controller's south/A button to activate, or east/B to cancel.
Expected: controller directions map to ui_left/right/up/down, the south/A button maps to ui_accept, and east/B maps to ui_cancel.
Actual:
Each directional action includes D-pad and left-stick joypad events.
ui_accept includes only Enter, keypad Enter, and Space.
ui_cancel includes only Escape.
Both room sweeps proved the directional selection route changes objects in every applicable room, but the common activation/cancel actions have no joypad event to deliver.
Root cause:
PixelSceneCanvas._gui_input() activates selected actions only through event.is_action_pressed("ui_accept") (scripts/ui/pixel_scene_canvas.gd:803-827).
Inventory/meta modal cancel paths likewise depend on ui_cancel (scripts/ui/run_inventory_screen.gd:675; scripts/ui/meta_item_interaction_screen.gd:288).
The generic InputMap lacks joypad accept/cancel events, while GameSurfaceCanvas locally special-cases JOY_BUTTON_A (scripts/ui/game_surface_canvas.gd:1056-1062). That workaround proves controller confirmation was intended but is isolated to game surfaces.
Impact: controller users can visibly move selection but cannot complete the action, close common screens, or reliably proceed without switching to a keyboard/mouse.
Fix options:
- 1. Add standard joypad A/south and B/east mappings to ui_accept and ui_cancel at the project level.
- 2. Remove per-surface confirmation exceptions after the shared actions are authoritative, or retain them only for hold semantics with duplicate suppression.
- 3. Add a no-keyboard controller smoke path: start run, inspect/activate an object, enter/exit a game, open/close inventory, acknowledge/cancel dismissible overlays, and navigate Settings.

### Persistence integrity

#### BTH-039 / PERSIST-EXT-01 — Oversized save reports success, installs an unloadable primary, and loses or rolls back progress

Severity: High   |   Confidence: High   |   Status: Confirmed

#### Title

Oversized run save reports success, installs an unloadable primary, and loses or rolls back progress

#### Severity and confidence

Severity: P2 / high integrity impact, low expected frequency
Confidence: High
Reproduction: 6/6 across three variants
Player impact: The UI can say the run was saved although the new generation cannot be loaded. A first save produces no resumable run. A later save silently rolls the player back to the previous backup generation.

#### Reproduction variants and observed results

##### A. First save into an empty slot — repeated twice

- 1. Create a valid active RunState.
- 2. Add a valid persisted narrative string large enough to make the encoded state exceed 32 MiB.
- 3. Call production SaveService.save_run.
- 4. Inspect through the same service, then through a fresh service.
Observed on both repetitions:
save_run returned OK (0).
The writing service's trusted fingerprint caused has_run to return true immediately.
A fresh slot_status reported primary_exists=true, primary_corrupt=true, primary_loadable=false, and no loadable backup.
load_run returned null.

##### B. Oversized synchronous replacement — repeated twice

- 1. Save a small valid generation with bankroll 811/812.
- 2. Attempt to save an oversized newer generation with bankroll 911/912.
- 3. Load from a fresh service.
Observed on both repetitions:
Both baseline and oversized save_run calls returned OK.
The new primary was corrupt and the backup was loadable.
Continue loaded bankroll 811/812, silently discarding the new 911/912 generation.

##### C. Oversized asynchronous replacement — repeated twice

- 1. Save a small valid generation with bankroll 1011/1012.
- 2. Call begin_save_run for an oversized newer generation with bankroll 1111/1112.
- 3. Call wait_for_async_save, matching the completion boundary used by the normal autosave machinery.
- 4. Load from a fresh service.
Observed on both repetitions:
begin_save_run returned OK.
wait_for_async_save returned OK.
The primary was corrupt and the backup was loadable.
Continue loaded bankroll 1011/1012 instead of 1111/1112.

#### Expected behavior

If the codec cannot represent a run, the save call and async completion must return a failure. The service must leave the existing primary and backup untouched. The UI must not report “Saved” or update its loadable-generation bookkeeping.

#### Root cause

The fault is an error-contract gap between the codec, save service, and UI:
- 1. RunSaveCodec.pack_for_storage returns an empty dictionary when serialized input is empty, exceeds MAX_STORAGE_BYTES, or compression fails (scripts/core/run_save_codec.gd:104-110).
- 2. The synchronous payload builder places that empty dictionary directly into run_state without checking it (scripts/core/save_service.gd:328-336).
- 3. The async worker does the same (scripts/core/save_service.gd:157-166).
- 4. Both write paths judge success only by filesystem write/rename. A valid primary may first be rotated to backup; the invalid {} generation is then installed as primary (scripts/core/save_service.gd:42-86, 170-202).
- 5. A successful rename fingerprints the invalid primary as trusted, so has_run can temporarily claim it is loadable (scripts/core/save_service.gd:30-38, 84-86, 138-142).
- 6. The reader correctly rejects the empty packed state later (scripts/core/save_service.gd:340-371), but by then the service has already reported success and mutated both generations.
- 7. FoundationMain treats the returned OK as a completed save, advances autosave bookkeeping, and presents success/writing status (scripts/ui/foundation_main.gd:6743-6757).

#### Fix options for a later implementation agent

- 1. Preferred: explicit codec result. Change pack_for_storage to return a structured success/error result, including an oversized/compression failure code. Make both sync and async save paths stop before opening a temp file or rotating any generation.
- 2. Minimum guard: After packing, reject an empty dictionary and return an error such as ERR_OUT_OF_MEMORY, ERR_FILE_TOO_BIG, or a project-specific error before writing.
- 3. Defense in depth: Validate the fully written temporary payload with the same envelope/decompress/hash checks used by _worker_payload_loadable before rotating the primary. Never install or trust a generation that the production reader cannot open.
- 4. Trust correction: Only call _remember_primary_fingerprint after validating the installed generation, rather than treating rename success as save validity.
- 5. UI contract: Ensure synchronous and async error propagation leaves autosave_completed_generation and autosave_loadable_available unchanged and shows “Autosave failed.”

#### Regression tests recommended

Empty-slot oversized sync save must return non-OK and leave both generations absent.
Existing-slot oversized sync save must return non-OK and preserve primary and backup byte-for-byte.
Existing-slot oversized async save must return non-OK from completion and preserve both generations.
Compression failure injection must follow the same preservation rules.
A save reported as OK must pass slot_status.primary_loadable in a fresh service instance.
A failed save must not add a trusted fingerprint.

### Release packaging

#### BTH-040 / EXT-PKG-003 — Production PCKs disclose internal QA reports and native toolchain metadata

Severity: Medium   |   Confidence: High   |   Status: Confirmed
Classification: packaging / information disclosure
Severity: Medium; release blocker unless deliberately accepted
Frequency: 100% in all three inspected current distribution payloads: builds/web/index.pck, the embedded PCK in builds/windows/BeatTheHouse.exe, and the embedded PCK in the executable inside builds/itch/BeatTheHouse-windows.zip
Reproduced twice: yes. The Web PCK was enumerated and a leaked entry was byte-validated; both independent Windows executable payloads were then enumerated and contained the same six entries.

##### Reproduction

- 1. Parse the Godot PCK v3 directory in builds/web/index.pck.
- 2. Observe 1,148 entries, including three reports/ files and three native/coin_pusher/ build-metadata files.
- 3. Read reports/foundation_bar_dice_pre_fix.json from its PCK payload offset. Its SHA-256, 1e917b143986f976f6d2aecb652481d91808a09735ab93726df244d3f9aad695, exactly matches the repository's internal report.
- 4. Parse the embedded PCK directories in the current Windows executable and in the archived Windows executable. Each has 1,076 entries and the identical six leaked files.

##### Leaked package entries

| Entry | Bytes | Exposure |
| --- | --- | --- |
| native/coin_pusher/build_profile.json | 64 | Native build-profile settings |
| native/coin_pusher/godot_web_release_build_profile.json | 1,714 | Web release toolchain profile |
| native/coin_pusher/toolchain.lock.json | 2,742 | Exact compiler versions, upstream commits, archive URLs, and hashes |
| reports/foundation_bar_dice_post_fix.json | 576 | Internal fix-validation record |
| reports/foundation_bar_dice_pre_fix.json | 678 | Historical internal failure details |
| reports/gdscript_load_check_blackjack_web.json | 9,420 | Internal source/test/tool inventory (192 paths) |

The six files total 15,194 bytes per package. No credential, private key, or player data was found, but the reports disclose historical failure details (including Grand Casino persistence and Bar Dice stake-dispatch failures) and the toolchain files expose unnecessary development metadata.

##### Root cause

export_presets.cfg:8 and export_presets.cfg:110 use export_filter="all_resources" for Windows and Web.
The exclusion lists at export_presets.cfg:10 and export_presets.cfg:112 omit reports/*, reports/**, native/*, and native/**.
tools/export_itch.ps1:94-107 checks loose output files only for five player-save filenames. It never audits the packed directory or rejects development-only prefixes.
tools/export_itch.ps1:243-244 runs that narrow clean-output check and the native-library presence check, so a package can pass export validation while still containing internal reports and build metadata.

##### Player/operator impact

Public packages expose internal failure history and implementation/toolchain details that players do not need.
The leaked path inventory makes repository structure and test surface easier to map.
The issue undermines the clean-distribution guarantee even though it does not expose save files.

##### Fix options (not implemented)

- 1. Exclude reports/*, reports/**, and native source/build metadata while explicitly retaining only the compiled native side libraries and the required .gdextension descriptor.
- 2. Add a post-export PCK manifest audit that rejects development-only prefixes and unexpected file types.
- 3. Keep the existing save-file check, but extend the release manifest policy to cover reports, toolchain locks, logs, test outputs, and credentials/secrets.

#### BTH-041 / EXT-PKG-004 — Loose itch Windows executable is missing its required native Coin Pusher DLL

Severity: High   |   Confidence: High   |   Status: Confirmed
Classification: packaging / runtime dependency failure
Severity: High for anyone using the loose executable; Medium repository/release-custody risk because the correct upload ZIP contains the DLL
Frequency: 100%, two complete isolated-profile runs
Affected artifact: builds/itch/BeatTheHouse.exe (171,994,584 bytes; SHA-256 1B3796FF37286B327753CA1134725BB481E3308D8A8521F24186CB44AC033F49)

##### Reproduction

- 1. Launch the loose executable from builds/itch without copying in files from another build folder.
- 2. Run the packaged coin_pusher telemetry plan with a fresh isolated distribution profile.
- 3. Observe four startup errors: two failed dynamic-library opens, GDExtension dynamic library not found, and Error loading extension.
- 4. Observe every Coin Pusher scenario reporting solver_backend="gdscript_v3" instead of the required native_v3.
- 5. Repeat with another isolated profile. The dependency errors and fallback reproduce exactly.

| Artifact/run | Backend | Raw 300-body contract | Raw solver tick p95 |
| --- | --- | --- | --- |
| Current builds/windows package | native_v3 | observed | 4.315 ms |
| Loose itch EXE, run 1 | gdscript_v3 | not observed | 40.265 ms |
| Loose itch EXE, run 2 | gdscript_v3 | not observed | 40.944 ms |

The fallback is approximately 9.4 times slower at this stress boundary. The game remains able to execute the plan, which makes this especially easy to miss: it degrades rather than failing closed. The authored ceiling-refusal contract also reports observed=false in both loose-EXE runs because the required native backend is absent.

##### Root cause

The embedded addons/coin_pusher_native/coin_pusher_native.gdextension descriptor points Windows release builds to the external file res://addons/coin_pusher_native/bin/coin_pusher_native_v3_10.windows.template_release.x86_64.nothreads.dll.
builds/itch contains the loose executable but no adjacent DLL. Godot therefore cannot load CoinPusherNativeCore, and scripts/games/coin_pusher/coin_pusher_solver.gd:460-470,558-564 deliberately falls back to gdscript_v3 when that class is unavailable.
tools/export_itch.ps1:163-179 correctly rejects the current Windows output directory unless exactly one native DLL exists.
However, tools/export_itch.ps1:182-193,251-256 packages from builds/windows into a named ZIP and only replaces that ZIP in builds/itch; it does not clean or quarantine stale loose distribution-like artifacts already in the upload directory.

##### Player/operator impact

Double-clicking or sharing this apparently complete, 0.5.1-labelled executable produces a degraded build with startup errors.
Coin Pusher runs without the required native solver and misses the production performance contract by roughly an order of magnitude under the 300-body fixture.
A tester could unknowingly validate the wrong backend because gameplay falls back instead of stopping with a player-visible dependency failure.

##### Fix options (not implemented)

- 1. Remove or quarantine loose executable residue from builds/itch; allow only the named upload archives (and an explicit manifest) in that directory.
- 2. Add a preflight that audits the distribution directory for executable-looking artifacts not owned by the current package operation.
- 3. If a standalone folder is intentionally produced, copy the executable and DLL together and validate the exact pair by launching the Coin Pusher native-backend contract.
- 4. Make distribution builds fail clearly when a required native extension is absent rather than silently shipping the GDScript fallback.

### Game authority / history

#### BTH-042 / EXT-GAME-001 — Rejected Blackjack transaction leaks a completed story record and retry duplicates it

Severity: Medium   |   Confidence: High   |   Status: Confirmed
Severity: P2 / Medium Frequency: 3/3 focused reproductions Area: Blackjack sealed action authority, transaction rollback, history/analytics integrity Player-visible risk: duplicated result/history entries after a recoverable action-boundary rejection; downstream statistics, achievements, progression, or run summaries may count one hand twice even though the bankroll settles once

##### Reproduction

- 1. Create a deterministic Blackjack authority fixture with a $5 play_basic action.
- 2. Enable the existing debug failure injection for the environment-turn boundary.
- 3. Record the live story_log; it is empty.
- 4. Resolve the action through FoundationMain._sealed_action_host_resolve_intent().
- 5. Observe the returned rejection: ok=false, blackjack_host_committed=false, error_code=forced_turn_rejection.
- 6. Inspect the live run before any retry. It already contains the completed Blackjack game_action record.
- 7. Use the normal canvas-facing blackjack_retry_pending command and replay the exact pending delivery.
- 8. Compare the final save snapshot with a clean control that executes the same delivery once.

##### Expected

A transaction rejected before publication must leave all player-observable and persisted run state unchanged, apart from the durable pending-delivery record intentionally retained for retry. The successful retry should create exactly one story entry, matching the clean control.

##### Actual

Before rejected resolve: story_log.size() == 0.
Immediately after rejected resolve: story_log.size() == 1 and contains the full completed result (game_id=blackjack, action_id=play_basic, bankroll_delta=5, outcome_bankroll_delta=5).
After the native retry: story_log.size() == 2.
Clean single-delivery control: story_log.size() == 1.
The retry response is byte-for-byte canonically equal to the clean response.
Bankroll, chips, RNG, environment-turn state, and the rest of the serialized run match the clean control. The sole final snapshot difference is $.story_log size 2 != 1.
This isolation is important: normal economy assertions can pass while persisted history is already corrupt.

##### Root cause

The sealed host applies result side effects before it crosses the environment-turn boundary that can still reject the overall action. In scripts/ui/foundation_main.gd, GameModule.apply_result(proposed_candidate, ...) runs at line 2579; only afterward does the host call _sealed_action_host_advance_environment_turn(proposed_candidate) and return an uncommitted rejection if that boundary fails.
GameModule.apply_result() appends story entries through RunState.log_story() (scripts/core/game_module.gd:981; scripts/core/run_state.gd:13504-13508). The optimized candidate machinery intentionally uses shallow/read-only aliases for much of the transaction graph and depends on copy-on-write guarantees. The focused failure proves that the story append escapes that proposal boundary in this rejection path. Because publication never occurs, there is no rollback or compensating removal. The retry then correctly applies the result again, producing the duplicate.
The unsafe ordering is therefore the directly verified causal boundary: a state-mutating apply occurs before the final fallible step, while the candidate/alias contract does not fully contain every apply-time mutation.

##### Recommended fix options

- 1. Make the transaction candidate fully own every collection that any GameModule.apply_result() path can mutate, including story/profile/crew/reputation histories, before calling apply_result().
- 2. Prefer staging result-driven history and analytics writes as deltas and publish them only after the environment-turn boundary succeeds.
- 3. Alternatively, move the final fallible environment-turn validation before irreversible result application, provided all action/environment semantics remain deterministic.
- 4. Add a regression that snapshots the entire live RunState immediately before a forced boundary rejection and asserts exact equality afterward except for the explicitly permitted pending-delivery ledger.
- 5. Extend the existing retry contract to compare the complete final save snapshot—not just bankroll, RNG, and response payload—and specifically assert one story record.

##### Evidence

.tmp/playtest_extended/game_rules_fuzz/game06_2_depth_repro2.stdout.log
.tmp/playtest_extended/game_rules_fuzz/game06_2_depth_repro2.stderr.log
.tmp/playtest_extended/game_rules_fuzz/game06_2_retry_diag2.stdout.log
.tmp/playtest_extended/game_rules_fuzz/game06_2_retry_diag3.stdout.log
.tmp/playtest_extended/game_rules_fuzz/game06_2_retry_diagnostic.gd

### Progression / economy

#### BTH-043 / XPE-01 — Debt boundary invalidates affordability, but purchase/service still commits

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: P1 / High Frequency: 4/4 affected cases: 2/2 item purchases and 2/2 paid services; matched no-debt controls passed 4/4 Player impact: unexpected run loss, inconsistent transaction results, and receipt of an item/service that was not fully paid for Affected surfaces: cash item offers and action-priced service/lender hooks that use the ordinary one-action clock boundary

#### Item-purchase reproduction

- 1. Begin an active run with $14.
- 2. Make a $12 Ledger Pencil offer available.
- 3. Add a $30 Street Lender debt with one action remaining and the forced_repayment default consequence.
- 4. Confirm that the offer is quoted affordable at $12.
- 5. Buy the Pencil.

#### Item-purchase expected result

The operation should be atomic. Either the $12 purchase is reserved/committed before the debt clock resolves, or the post-boundary balance should be revalidated and the purchase should be rejected or rolled back. The player must not receive a $12 item after only $10 remains available.

#### Item-purchase actual result

The API returns ok: true.
The action boundary forces a $4 debt payment first, reducing bankroll from $14 to $10 and debt balance from $30 to $26.
The previously built purchase result then applies a $12 delta.
Bankroll reaches a negative intermediate value and is clamped to $0 by terminal handling.
The run ends with run_status: failed and failure_reason: bankroll_zero.
The Ledger Pencil is nevertheless added to inventory and the offer is removed.
Debt remains overdue at $26 and local Heat rises by 4.
Both fixed seeds produced the same state. In each matched no-debt control, the purchase completed normally and the run remained active at $2.

#### Paid-service reproduction

- 1. Begin an active run with $16 in the Punchline/underground venue context.
- 2. Expose the $14 punchline_cover_charge service.
- 3. Add the same $30 Street Lender debt with one action remaining and forced repayment.
- 4. Confirm that the service is enabled and quoted at $14.
- 5. Buy the cover service.

#### Paid-service expected result

The service should either commit against the quoted $16 before the debt payment or fail atomically after the balance changes. Its single-use effect must not be granted when the transaction cannot be funded.

#### Paid-service actual result

The API returns ok: true.
The debt boundary takes $5 first, reducing bankroll from $16 to $11 and debt balance from $30 to $25.
The $14 service result then applies, causing bankroll-zero failure and clamping to $0.
The single-use punchline_headliner_cover_paid flag is still granted.
Debt remains overdue at $25. Heat ends at 2: the default adds 4 and the service effect removes 2.
Both fixed seeds reproduced the same result. Both no-debt controls completed normally and remained active at $2 with the service flag set.

#### Root cause

The item and hook paths validate affordability against the pre-boundary balance, construct an authoritative-looking result, advance the action boundary, and only then apply the result:
RunActionService.buy_item_offer() checks run_state.bankroll < price at scripts/core/run_action_service.gd:237, builds the purchase result at line 248, advances the environment at line 249, and calls GameModule.apply_result() at line 252.
RunActionService.use_hook() builds the result at line 981, advances the hook clock at line 1001, and applies the result at line 1005.
The action boundary reaches _advance_global_boundary_finish() and _advance_debt_clocks() at scripts/core/run_state.gd:14111-14113.
A forced-repayment default deducts one third of the current bankroll at scripts/core/run_state.gd:14630-14648.
GameModule.apply_result() then applies the stale cash delta at scripts/core/game_module.gd:871-873. It does not re-check affordability or stop after change_bankroll() marks the run failed. It continues to add inventory and flags at lines 952-964.
The result is a split transaction with three incompatible snapshots: quote against the old balance, debt payment against the boundary balance, and purchase/service application against the already reduced balance. The special Jazz show_drummer_glasses hook uses an apply-first snapshot-and-rollback path at run_action_service.gd:985-1000, demonstrating that the codebase already has a safer atomic pattern, but ordinary cash hooks do not use it.
The defect is deterministic and does not depend on RNG; the two seeds establish that it is not tied to a particular generated environment.

#### Likely affected scope

Confirmed scope is limited to ordinary cash item offers and paid hooks that advance a one-action boundary before applying their result. Any boundary mutation that reduces spendable cash can trigger the ordering fault; forced repayment is the directly reproduced mechanism.
Source inspection shows a similar boundary-before-result pattern in some hosted gameplay actions, but those paths have additional wager-funding and authority rules. They were not independently reproduced in this pass and are not claimed as confirmed affected surfaces. Travel advances game-clock minutes rather than the debt action clock in the tested path, so travel is also not included in the confirmed scope.

#### Fix options

- 1. Treat quote, cost, boundary, and reward as one transaction. Snapshot the run and environment, reserve or apply the price, advance the boundary, and restore everything if the boundary fails.
- 2. Alternatively, advance the boundary first and then recompute availability/affordability from live state before applying the result. If the quote is invalidated, return a clear cancellation and leave offers, inventory, flags, and story state unchanged.
- 3. Add a transaction helper shared by item offers and hook services so the two paths cannot drift again.
- 4. Stop GameModule.apply_result() from applying non-cash rewards after a cash delta has transitioned the run into failure, unless the result explicitly declares terminal settlement semantics.
- 5. Add a regression matrix for bankroll values immediately below, equal to, and above price + forced_payment, with debt clocks at 0, 1, and 2 actions. Assert API status, final bankroll, run status, debt balance, offer consumption, inventory, flags, Heat, and story log atomically.
- 6. Cover both normal services and the existing Jazz rollback special case to ensure a shared transaction helper preserves intentional behavior.

### State integrity / recovery

#### BTH-044 / EXT-PERF-001 — Dynamic-room semantic digest drift blocks enabled travel and cascades into game-action rejection

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: High Priority: P1 Systems: Dynamic room sequences, scenario semantic inventory, world-map travel, save/load, environment game preflight Player impact: A live run can enter a partially soft-locked state. Routes remain visible and enabled, but confirmation leaves the player in place and displays an internal migration error. Once the proof is invalidated, Coin Pusher and Pull Tabs actions in the affected room can also be rejected. Repeated attempts and save/load cycles do not repair the invalidated proof.

##### Observed behavior

Across the three independent soaks, 382 travel attempts selected a presented destination but did not change the current node. The instrumented diagnostic run captured all 122 of its failures at the production confirmation boundary:
the requested target was present in travel_enabled_node_ids;
the matching travel choice had enabled: true and an empty disabled_reason;
target selection succeeded;
confirm_world_map_travel() returned {ok: false};
the sole error was scenario semantic inventory version or digest changed; explicit migration is required;
current node, run status, and selected-node state showed that the travel did not occur.
Diagnostic route distribution:

| Current node | Enabled target | Count | Confirmation result |
| --- | --- | --- | --- |
| Bar | Back Alley | 57 | Semantic inventory version/digest changed |
| Corner Store | Bar | 45 | Semantic inventory version/digest changed |
| Back Alley | Bar | 16 | Semantic inventory version/digest changed |
| Apartment | Back Alley | 2 | Semantic inventory version/digest changed |
| Apartment | Corner Store | 1 | Semantic inventory version/digest changed |
| Back Alley | Corner Store | 1 | Semantic inventory version/digest changed |

The first instrumented failure occurred in run 7 at action 277. The player was in the Apartment, Corner Store was one of only two enabled destinations, and confirmation failed with the digest-change error.
The invalid state also crossed subsystem boundaries. In run 9, environment bar_003 rejected four later game actions with Dynamic room sequence semantic records are not finalized.:
Coin Pusher drop_quarter at actions 338 and 347;
Pull Tabs buy_tab at actions 346 and 349.
This is not merely a stale map message. Travel finalization invalidates semantic readiness, and subsequent environment-turn/game ingress then fails closed.

##### Reproduction path

- 1. Start or generate runs until a dynamic room sequence is active, such as the Bar fight-night sequence exercised by the soak.
- 2. Preserve the room across normal play while progressing state that affects Numbers venues, Silas presence, or the delivery handoff node.
- 3. Revisit rooms and exercise save/load boundaries so scenario semantics are refreshed.
- 4. Open the world map and select a route that is visibly enabled.
- 5. Confirm travel.
- 6. Observe that the player remains in the same node and receives the internal version/digest migration error.
- 7. Return to a game in the affected scenario room and attempt a normal action.
- 8. Observe that the action may be rejected because dynamic-room semantic records are no longer finalized.
The exact action at which the live producer context changes depends on generated content, so the long deterministic seeds are the most reliable current reproducer. The failure is not timing-only: after invalidation, repeated travel and game attempts consistently fail.

##### Root cause

scripts/core/run_state.gd treats scenario base semantics as an immutable pre-sequence seal, but refresh reconstructs part of that seal from mutable live state:
- 1. _scenario_finalize_trusted_base_semantics() determines that a refresh is in progress.
- 2. At line 2646 it calls _scenario_base_producer_context() again rather than loading the producer context that was stored with the original seal.
- 3. _scenario_base_producer_context() at lines 3171–3183 derives numbers_venue_ids, numbers_silas_present, and delivery_handoff_node_id from current run state.
- 4. The newly derived context is inserted into semantic_environment and used to stamp records and build the semantic inventory/digest.
- 5. At lines 2695–2707, the regenerated version/digest is compared with the stored proof. A legitimate live change to any producer-context input causes the comparison to fail.
- 6. _invalidate_scenario_semantic_proof() at lines 3186–3194 erases readiness, inventory, base interactions/actors/producer context, layout authority, and render snapshot, then stores the lifecycle error.
- 7. Later travel and environment-game preflights correctly fail closed because the proof that refresh itself erased is no longer ready.
The internal comment says trusted records come from an immutable pre-sequence baseline. Recomputing producer context from live Numbers/delivery state contradicts that invariant. The digest is detecting a real difference, but the difference is introduced by the refresh algorithm rather than by an incompatible save migration.

##### Why this is not a harness or dirty-worktree artifact

All 122 diagnostic targets were explicitly marked enabled by the production world-map snapshot.
The failure came from the production confirm_world_map_travel() result, not from the probe's selection logic.
Every diagnostic no-move warning carried the same product error. There were no warnings caused by selecting absent, disabled, closed, or unaffordable routes.
The tracked dirty files were last modified no later than 01:35:37, while the diagnostic process ran from 15:45:13 to 16:04:58. No tracked product/data file changed during the run.
scripts/core/run_state.gd, where the failing digest is computed, was unchanged in the worktree.
The two earlier soaks reproduced the same route-stall family under independent runs before the diagnostic instrumentation was added.

##### Fix options

- 1. Reuse the sealed producer context on refresh. When refresh_attempt is true, read and validate the persisted scenario_base_producer_context associated with the existing semantic inventory. Do not call _scenario_base_producer_context() to regenerate origin identity.
- 2. Bind origin context into durable provenance. Store the exact producer-context fields and digest with source provenance at initial installation. Reconstruct the semantic inventory after load from that immutable record, not from current Numbers/delivery projections.
- 3. Separate identity inputs from live availability. If Numbers presence or delivery handoff availability is intentionally dynamic, exclude it from the immutable identity digest and authorize it through a separately versioned live projection.
- 4. Avoid destructive invalidation for expected live changes. A refresh mismatch should retain the last validated proof until a valid migration/rebuild succeeds. Erasing the only usable proof turns a recoverable inconsistency into a room-wide soft lock.
- 5. Fail the map choice before presentation as defense in depth. If confirm-time semantic preflight cannot succeed, do not present the route as enabled. This improves UX but does not replace digest-stability repair.

##### Regression tests

Install a dynamic-room semantic proof, mutate each producer-context input individually, refresh, and assert that the original identity digest remains valid.
Repeat the above across save/load and environment revisit.
With an active scenario, change Numbers venue availability, Silas presence, and delivery handoff state, then confirm every enabled travel route.
After every failed travel preflight, verify that scenario_semantic_ready, the prior inventory, and authorized game actions remain intact.
Add a deterministic replay using the diagnostic seed prefix and assert zero scenario semantic inventory version or digest changed errors during ordinary gameplay.

#### BTH-045 / EXT-PERF-002 — Coin Pusher compact rollback can reject its own token after a failed turn boundary

Severity: Medium   |   Confidence: High   |   Status: Confirmed
Severity: Medium Priority: P2 Systems: Coin Pusher live simulation, environment-turn transaction recovery Player impact: When an otherwise successful Coin Pusher action cannot commit its environment turn, the game attempts a compact rollback. If rollback rejects its token, the failed action may leave some live machine/session mutation in memory even though the surrounding turn did not commit. The soaks did not prove durable save corruption, but failure of the declared recovery contract makes subsequent outcomes and presentation state unreliable.

##### Observed behavior

Soak A logged four and soak B logged six occurrences of:
Game module failed to restore its declared compact host-action rollback token.
Every occurrence followed this stack:
- 1. foundation_main.gd:_resolve_game_action() line 12365;
- 2. resolve_selected_game_action();
- 3. the soak's ordinary _try_play_environment_game() path.
The two runs independently reproduced the failure with the same workload shape. The diagnostic seed did not reproduce it, establishing that it is schedule/state dependent rather than a constant failure. The error occurs only after a module returned an accepted result but _advance_environment_turns_checked() rejected the turn boundary.

##### Root-cause analysis

Only Slot and Coin Pusher implement compact action rollback. Slot's restore path returns true for every supported snapshot with a non-empty state key and replaces the durable state from a deep copy. Coin Pusher is the practical failing path:
host_action_rollback_snapshot() stores a direct reference to the current live machine in snapshot["machine"].
restore_host_action_rollback() calls _ensure_live_machine() again and requires is_same(snapshot_machine, ensured_machine).
If resolution or the rejected environment-turn path replaces/rebinds the live-machine entry, _ensure_live_machine() returns an equivalent or successor dictionary with a different identity.
The identity guard returns false before shell, simulation motor target, live-session flags, or durable machine state are restored.
foundation_main.gd logs the error and returns; there is no whole-run fallback because the compact snapshot caused the host to skip the full rollback copy.
Thus the recovery scheme depends on object identity surviving precisely the failed transaction it is intended to undo. A replacement-on-write or cache rebind makes the rollback token unusable.
This defect was often reached in the same broad long-session conditions as EXT-PERF-001, because semantic preflight can reject the environment-turn boundary. It remains a separate defect: regardless of why the boundary rejects, a module that declares compact rollback support must be able to restore its token.

##### Fix options

- 1. Store the live-machine cache key and sufficient immutable rollback data; on restore, rebind the saved machine or restore into the currently registered machine instead of requiring reference identity.
- 2. Have _ensure_live_machine() expose a stable generation/token and make rollback validate semantic identity plus generation, not raw dictionary identity.
- 3. If compact restore returns false, execute the full run/environment fallback captured before resolution. This costs more only on an exceptional path and prevents partial mutation.
- 4. Add a debug/result payload identifying the game, action, cache key, and identity generation when rollback fails so future probes can prove the exact replacement boundary.

##### Regression tests

Force _advance_environment_turns_checked() to reject after a Coin Pusher quarter resolves, then compare the complete machine/session/durable projection byte-for-byte with the pre-action state.
Repeat after live-machine cache replacement, environment revisit, and save/load.
Assert that a failed compact restore automatically falls back to a complete rollback.
Run the two reproducing long-soak seed prefixes and require zero rollback-token errors.

### Audio / feedback / recovery

#### BTH-046 / EXT-AUDIO-001 — Music cache key reuses stale compositions across distinct scenarios, weather states, and unique jazz rooms

Severity: Medium   |   Confidence: High   |   Status: Confirmed
Severity: P2 / Medium Frequency: deterministic for same-key, different-profile revisits Area: procedural music, repeated scene changes, environmental telegraphing Confidence: confirmed by two independent production-scene probe processes plus exact key/profile source trace

##### Reproduction

- 1. Visit a procedural-music archetype under one scenario and allow its full stem set to cache—for example a Bar scenario with its authored BPM/ambience/texture override.
- 2. Leave and later enter the same archetype under a different scenario whose music override changes BPM, mode, texture, ambience, or volume.
- 3. Compare the effective environment music_profile and ProceduralMusicPlayer.music_stem_manifest_snapshot_for_environment() cache key.
- 4. Repeat with two independently generated Jazz Club instances. Their saved generated_signature, BPM, mode, root, progression, and motif differ by design.

##### Expected

Every profile change that alters generated PCM or an authored arrangement must select a distinct cached stem set, or explicitly update the active stems so the music matches the current room and weather.

##### Actual

The profile changes, but the base cache key does not. Once a full stem set exists for that key, play_for_environment_state() reuses it. The old PCM can therefore accompany a new scenario/profile, suppressing tension, calm, weather texture, or the Jazz Club’s advertised unique composition.
The production scenario catalog contains 55 distinct music overrides across 12 archetypes. Within every archetype, every override is distinct:

| Archetype | Distinct overrides sharing one base identity |
| --- | --- |
| Corner Store | 5 |
| Back Alley | 4 |
| Motel | 4 |
| Bar | 7 |
| Gas Station Casino | 5 |
| Small Underground Casino | 8 |
| Jazz Club | 4 |
| Kitty Cat Lounge | 4 |
| Delta Queen | 5 |
| Beach | 3 |
| Pawn Shop | 3 |
| Grand Casino | 3 |

Across those overrides, omitted identity fields occur 185 times: ambience 55, BPM 47, mode 6, texture 51, texture rate 2, and volume 24.
The runtime probe confirmed the identity collision in 4/4 pair comparisons. The Bar pair had materially different arrangement durations (65.195 s versus 36.606 s) but the same key, stem:11:bar:local bar:bar:procedural. The two generated Jazz Club rooms had different ids, signatures, BPM, mode, root, motif, texture, and theory output but shared stem:11:jazz_club:classical jazz club:jazz:procedural. Both independent process runs produced the same result.

##### Root cause

_music_profile_from_environment() builds a profile containing environment id, mood, mode, texture, texture seed/rate, BPM, root, safety, ambience, volume, phrase count, adaptive tempo, layer choreography, progression, and motif (scripts/ui/procedural_music_player.gd:2885-2937). _ambient_cache_key() includes only version, archetype, theme, palette, and authored track (2940-2948). The cache reuse path at 463-465 assumes that underspecified key fully identifies the PCM.
The omission conflicts with three production systems:
scenario state deep-merges music_profile_override (scripts/core/scenario_engine.gd:1728-1729);
weather mutates ambience, volume, and texture (scripts/core/run_state.gd:12704-12712);
Jazz Club generation deliberately randomizes mode, texture, BPM, root, progression, motif, arrangement length, and generated_signature per instance (scripts/core/environment_instance.gd:759-796).
_remember_profile() can also overwrite metadata under the colliding key while the old stem set stays cached, so later diagnostics can show a current profile alongside stale PCM.

##### Fix options

- 1. Make the stem-cache identity a stable hash of every PCM-affecting profile field, including generated signature and relevant authored selection state.
- 2. Separate composition identity from live mix identity: include mode/texture/BPM/root/progression/motif/phrase count in the PCM key, while ambience/volume that are genuinely mix-only should update gains without forcing regeneration.
- 3. Add a contract test that generates two same-archetype scenario instances and two Jazz Club instances, asserts distinct profile fingerprints, and requires either distinct stem keys or proven mix-only equivalence.

#### BTH-047 / EXT-AUDIO-002 — Run Menu and in-run Settings do not pause the game-surface clock or timed audio presentation

Severity: Medium   |   Confidence: High   |   Status: Confirmed
Severity: P2 / Medium Frequency: every in-game pause/settings opening Area: pause state, hidden feedback, slots/table presentation Confidence: confirmed by four production game entries across two independent probe processes plus exact pause-ownership source trace

##### Reproduction

- 1. Enter any game surface; the defect is most audible during a Slot spin or another timed sequence.
- 2. Open the HUD Run Menu while the sequence is active.
- 3. Optionally open Settings from the Run Menu and remain there longer than the sequence duration.
- 4. Listen for loop/cue progression and inspect surface_simulation_time_msec before and after the pause interval.
- 5. Resume the game and observe presentation state.

##### Expected

The Run Menu is the product’s simulation pause owner. Game-surface simulation clocks and state-driven timed audio should freeze, or active gameplay SFX should be explicitly paused/ducked and resume from the same presentation point.

##### Actual

Authoritative game progression freezes because _simulation_progression_paused() includes the Run Menu. The game-surface canvas continues processing, advances surface_simulation_clock_msec, and calls _sync_surface_audio() behind the overlays. Timed cues can fire unseen, active reel loops can continue, and the visible animation may be at a later/completed phase when the player resumes.
All four runtime entries reproduced the split: simulation_progression_paused=true, canvas_environment_activity_paused=false, Run Menu visible, Settings visible, and screen still GAME. During each nominal 300 ms wait, Run Menu clock deltas were 302–305 ms and Settings deltas were 303–306 ms. None of the eight samples froze.

##### Root cause

GameSurfaceCanvas.set_environment_activity_paused() owns the pause-safe simulation clock (scripts/ui/game_surface_canvas.gd:127-133, 1257-1282). FoundationMain only calls that method from the Pal tutorial-conversation handler (scripts/ui/foundation_main.gd:9723-9738). Opening or closing the Run Menu and Settings never updates canvas pause state. Settings correctly stacks on the still-visible Run Menu (16221-16255), so the authoritative simulation remains paused while the presentation clock is not.
The canvas calls _sync_surface_audio() before presentation early returns (scripts/ui/game_surface_canvas.gd:1257-1267), which propagates the clock mismatch into audio markers and loops.

##### Fix options

- 1. Centralize canvas pause ownership around _simulation_progression_paused() and update both environment/game canvases whenever modal state changes.
- 2. Give surface SFX an explicit pause/resume contract for loops and scheduled markers; do not merely stop and restart loops from zero.
- 3. Add a production-scene regression: start a timed surface channel, open Run Menu then Settings, advance real time, and assert the surface simulation clock, marker count, and loop phase do not advance.

#### BTH-048 / EXT-AUDIO-003 — WebAudio and procedural PCM caches retain decoded audio for the entire page/app lifetime

Severity: Medium   |   Confidence: High   |   Status: Confirmed
Severity: P2 / Medium Frequency: monotonic with distinct music/SFX keys over long sessions Area: long-session memory, repeated scene changes, Web build Confidence: high static ownership proof; quantitative browser/audio-cache severity unmeasured

##### Reproduction

- 1. On Web, visit distinct environments and exercise multiple game surfaces/features so new music stems and SFX streams are registered.
- 2. Return to the main menu, start another run, and repeat with different rooms.
- 3. Sample the browser audio-buffer registry and Godot resource memory after each batch.
- 4. Call the existing audio debug-stat reset and compare the reported registered count with actual browser memory.

##### Expected

Inactive decoded PCM should be bounded by an LRU/byte budget, or cleared at a documented lifecycle boundary. Debug reset must not imply that resource ownership was reset when it was not.

##### Actual

Every registered WebAudio PCM payload remains in window.BTHWebAudio.pcmBuffers until the page is destroyed. Stopping music/all sources removes active nodes but not buffers. Godot simultaneously retains full/primer/instant/Web-bed stem sets across stop() and run changes. No byte limit or eviction policy exists for those caches. Resetting GDScript debug stats clears only _registered_pcm_keys, so the reported count can fall to zero while JavaScript buffers remain allocated.

##### Root cause

Browser registry creation and insertion: scripts/ui/web_audio_bridge.gd:167-179, 226-247.
stopAll() removes sources only: 454-466.
There is no deletion, size limit, or LRU path for pcmBuffers.
Procedural caches are cleared only in _exit_tree() (scripts/ui/procedural_music_player.gd:330-342); stop() explicitly preserves them (508-575).
_ambient_stream_cache, _ambient_primer_cache, _ambient_instant_cache, and _web_music_bed_cache have no limits. Only the unrelated authored-manifest metadata cache has a 32-entry bound.
At a typical 82 BPM, four 32-step phrases are roughly 47 seconds. Nine mono 44.1 kHz/16-bit playback roles are approximately 37 MB of raw PCM for one full procedural stem set before primer/instant and engine overhead. Retaining many distinct room/selection keys can therefore become material.
The 360-minute headless shared soak traversed diverse environments, but its procedural-music/audio stream and player caches remained at zero; it did not exercise the decoded-audio ownership path and cannot quantify this finding. No browser runtime was available, so the report intentionally does not claim a measured Web memory slope.

##### Fix options

- 1. Add a byte-budgeted LRU for both Godot stem sets and JavaScript AudioBuffers, protecting only active/pending keys.
- 2. Clear run-scoped caches at return-to-menu/new-run boundaries while retaining a small shared hot set.
- 3. Add a real WebAudio disposePcm(keys) / clearInactivePcm() bridge operation and include actual JS buffer count/bytes in diagnostics.
- 4. Make debug reset observational only, or clearly separate “counter reset” from “resource clear.”

#### BTH-049 / EXT-AUDIO-004 — 0% volume is attenuation, not mute

Severity: Low   |   Confidence: High   |   Status: Confirmed
Severity: P3 / Low Frequency: every Master/Music/SFX slider set to 0% Area: settings, accessibility, WebAudio mix Confidence: confirmed by four applications and twelve live engine-bus observations across two independent probe processes

##### Expected

A user-selected 0% volume should guarantee silence for that bus.

##### Actual

Zero writes –80 dB and leaves the bus unmuted. On Web, the bridge converts –80 dB to a nonzero linear gain of 0.0001. Native audio is also attenuated rather than hard-muted.
In both process runs, two applications each produced identical Master, Music, and SFX snapshots: −80 dB, muted=false, and linear_gain=0.0001. That is 12/12 nonzero-gain observations.

##### Root cause

UserSettings._set_volume() maps zero to –80 dB but never calls AudioServer.set_bus_mute() (scripts/core/user_settings.gd:298-305). WebAudioBridge._audio_bus_linear() returns zero only when the bus mute flag is true; otherwise it converts bus dB back to linear (scripts/ui/web_audio_bridge.gd:700-706).

##### Fix options

Set the bus mute flag when the normalized slider is zero and clear it when raised above zero. Preserve the prior nonzero dB value or recompute it from the slider when unmuting. Add native and Web contract assertions that 0% produces exactly zero output gain.

#### BTH-050 / EXT-AUDIO-005 — Malformed settings silently discard preferences with no player-visible recovery message

Severity: Low   |   Confidence: High   |   Status: Confirmed
Severity: P3 / Low Frequency: deterministic when settings.json is malformed or has a non-object root Area: settings persistence, player-visible error recovery Confidence: confirmed by four isolated invalid-file loads across two independent probe processes

##### Expected

The game may safely fall back to defaults, but it should tell the player that preferences could not be read and identify whether defaults were applied. Ideally it should preserve/rename the corrupt file for support and avoid silently overwriting it until the player confirms.

##### Actual

Startup resets every preference to defaults, ignores malformed/wrong-type JSON, and applies those defaults without surfacing any message. The next successful Apply overwrites the only corrupt-file evidence.
Each process tested malformed JSON and a valid array root. All 4/4 loads returned the complete default settings object through a void/no-outcome API. Malformed syntax produced an engine parse line, but neither case returned a status that the UI could use; no player-visible recovery state was created.

##### Root cause

UserSettings.load() resets first and only calls from_dict() for a dictionary root; it returns no status (scripts/core/user_settings.gd:60-69). FoundationMain._initialize_user_settings() immediately applies the result without a load outcome (scripts/ui/foundation_main.gd:8640-8645). This differs from run-save recovery, which exposes corrupt/backup state on the main menu.

##### Fix options

Return a structured load outcome (loaded, missing, recovered_defaults, invalid_schema, io_error), preserve invalid files with a timestamped suffix, and surface a concise main-menu/settings banner.

#### BTH-051 / EXT-AUDIO-006 — WebAudio SFX delivery failures are ignored, dropping cues without retry or fallback

Severity: Low   |   Confidence: High   |   Status: Confirmed
Severity: P3 / Low Frequency: when the bridge is available but payload registration/playback fails Area: Web audio recovery, feedback reliability Confidence: high static control-flow proof; browser fault injection unrun because the serialized slot was native headless only

##### Expected

If the WebAudio bridge rejects a payload or cannot decode/register it, the caller should retry, fall back to the engine player when viable, or expose a recoverable audio warning.

##### Actual

Surface SFX returns immediately whenever the bridge is available, regardless of play_stream()’s boolean result. Reel-loop startup additionally marks _web_surface_loop_active = true after an unverified request. A failed request is therefore treated as successfully active and no fallback plays. Browser decode failures are console-only.

##### Root cause

SfxPlayer._play() ignores the WebAudioBridge.play_stream() result and always returns on Web (scripts/ui/sfx_player.gd:1602-1607). _start_reel_loop() does the same and unconditionally marks the loop active (1561-1569). The bridge can legitimately return false when not ready, when stream payload materialization fails, or when JavaScript registration/playback rejects the request (scripts/ui/web_audio_bridge.gd:515-531).

##### Fix options

Honor the return value. For loops, set the active flag only after success and retain a bounded retry request. For one-shots, use an engine fallback where supported or count/report dropped cues through a player-visible “audio unavailable” status after repeated failures.

### Application lifecycle / recovery

#### BTH-052 / LIFE-001 — Alt-tab or minimization does not suspend time-sensitive gameplay

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: High
Confidence: High (static control-flow proof)
Affected state: any active non-meta run, especially an auto-resolving game or time-sensitive environment
Reproduction:
- 1. Start a run with the continuous environment clock active.
- 2. Enter a game that uses auto ticks or real-time surface state.
- 3. Alt-tab away from the application or minimize its window for a meaningful interval.
- 4. Return and inspect clock, automated actions, and table/environment state.
Expected: losing application visibility/control suspends player-affecting simulation, or the game explicitly warns and obtains consent to continue in the background.
Actual from code: _process() continues to call the run clock, game automation, real-time surface refresh, and environment runtime. None of those paths checks application focus or minimized state.
Root cause:
FoundationMain._process() unconditionally enters progression paths on each process frame (scripts/ui/foundation_main.gd:689-734).
The clock, automation, and real-time guards recognize internal simulation pause state, but not OS lifecycle state (foundation_main.gd:737-746, 2836-2864, 2879-2900).
The root notification handler recognizes resize and WM close only (foundation_main.gd:787-797). A repository-wide search found no application-focus/pause or minimized-window handler.
Player impact: time can elapse and automatic wagers or table transitions can resolve while the player cannot observe or intervene. This can change bankroll, deadlines, and run state merely because the player switched applications.
Fix options:
- 1. Add application focus/visibility as an explicit simulation pause owner and gate clock, automation, real-time game state, and environment runtime with it.
- 2. Handle application focus-out/in and pause/resume notifications centrally, leaving non-gameplay maintenance such as save completion separately controlled.
- 3. If background play is intentional, make it an opt-in setting and surface an unmistakable warning/state indicator.
- 4. Add integration coverage that focuses out/minimizes during continuous clock, autoplay, and a real-time table, asserting no player-affecting state change until focus returns.

#### BTH-053 / LIFE-002 — OS focus loss can strand or later complete a stale game-surface hold

Severity: High   |   Confidence: High   |   Status: Confirmed
Severity: High
Confidence: High (missing lifecycle route; existing cancel contract proves required cleanup)
Affected interactions: drag/hold surfaces such as Coin Pusher charge/carriage input and other games using surface_pointer_action begin/move/end/cancel phases
Reproduction:
- 1. Begin a mouse drag, touch drag, keyboard hold, or controller hold on a game-surface region.
- 2. While still held, alt-tab, minimize, or otherwise deactivate the application window.
- 3. Release the input outside the application, then return.
- 4. Move/click/press on the game surface again.
Expected: application deactivation immediately emits one cancel, clears capture, and prevents any interrupted gesture from placing a wager or retaining charge/drag state.
Actual from code: capture clears on a later ordinary release, a Control-level GUI focus exit, or canvas invisibility. There is no handler for application/window focus loss, pause, or minimization.
Root cause:
Drag capture and keyboard/controller hold capture store persistent action state and emit begin (scripts/ui/game_surface_canvas.gd:1141-1149, 1174-1208).
The explicit safe recovery method emits cancel and clears all capture fields (game_surface_canvas.gd:1219-1231).
_notification() calls it only for NOTIFICATION_FOCUS_EXIT on the Control and visibility loss (game_surface_canvas.gd:1234-1238). OS deactivation is a separate lifecycle event and may preserve the GUI focus owner for restoration.
The existing regression test injects only Control.NOTIFICATION_FOCUS_EXIT, so it does not cover the missing application-focus boundary (scripts/tests/foundation/check_coin_pusher.gd:457-461).
Player impact: an interrupted hold can remain logically active after returning, retain stale charge/drag state, or complete on a later unrelated release. For wager-bearing gestures, this risks an unintended action.
Fix options:
- 1. Route root application focus-out, application pause, and window-hide/minimize events to GameSurfaceCanvas._cancel_captured_surface_pointer().
- 2. Make cancellation idempotent and clear any coalesced move before processing focus-in input.
- 3. Add a lifecycle integration test that begins each input modality, delivers application focus-out without a release, and asserts exactly one cancel plus empty capture state.
- 4. On focus-in, reject orphan release/motion events until a fresh press begins a new gesture.

#### BTH-054 / LIFE-003 — Settings Back can leak an unsaved High Contrast choice globally

Severity: Medium   |   Confidence: High   |   Status: Confirmed
Severity: Medium
Confidence: High (deterministic static state-flow proof)
Reproduction:
- 1. Open Settings with High Contrast disabled.
- 2. Enable High Contrast, but do not select Apply.
- 3. Change Text Size or Play on Small Screen.
- 4. Select Back.
- 5. Open another screen or rebuild controls that consume the global visual palette.
Expected: Back discards every draft setting and restores all live/global presentation to the last committed settings.
Actual from code: changing Text Size or Play on Small Screen calls the preview refresh, which reads the entire draft and publishes its High Contrast value into global VisualStyleScript. Back hides Settings without restoring the committed palette.
Root cause:
Settings explicitly edits a draft copied on open (scripts/ui/settings_menu.gd:60-67).
High Contrast changes the draft, while the Text Size and Small Screen callbacks invoke _apply_accessibility_settings() (settings_menu.gd:394-427).
That method reads the draft's High Contrast value and mutates global visual-style state (settings_menu.gd:474-487).
Back emits only a close request, and both visibility teardown and FoundationMain.close_settings_menu() omit palette rollback (settings_menu.gd:162-164, 211-219; scripts/ui/foundation_main.gd:16242-16256).
Player impact: a setting the player canceled can affect later/rebuilt controls, while disk and live UserSettings still report the old value. The UI can therefore present a mixed or unexpectedly high-contrast palette until another apply/restart path repairs it.
Fix options:
- 1. Keep preview palette state scoped to the Settings subtree; publish global VisualStyle only after Apply commits the draft.
- 2. Alternatively snapshot the committed global palette on open and restore it on every non-Apply close path.
- 3. Give Settings an explicit commit versus cancel close contract instead of treating visibility loss as teardown.
- 4. Add a regression matrix for each draft field followed by Back, asserting UserSettings, global visual-style state, and newly constructed controls all match the pre-open committed state.

### Player text / formatting

#### BTH-055 / EXT-TXT-001 — Shared authority errors incorrectly identify non-Blackjack games as Blackjack

Severity: Medium   |   Confidence: High   |   Status: Confirmed
Severity: P2 / Medium Frequency: deterministic whenever an affected rejection/retry branch is reached Affected games: Bar Dice, Baccarat, Roulette, Slot, and Video Poker; Blackjack wording is correct only for Blackjack itself

##### Reproduction

- 1. Enter any non-Blackjack game that implements sealed_action_authority_contract()—for example Roulette or a Slot cabinet.
- 2. Reach a sealed-host rejection branch such as an invalid/stale delivery, failed proposal replay, missing receipt, late environment-turn rejection, or pending-action conflict.
- 3. Observe the message routed to the player.

##### Expected

The message names the active game, uses a neutral term such as “game action,” or provides a recovery instruction without exposing another game's name.

##### Actual

The generic host returns text including:
Blackjack action intent is unavailable.
Retry or cancel the pending Blackjack action...
Blackjack game proposal failed closed validation.
Blackjack transaction could not cross the environment boundary.
Blackjack replay did not match the canonical committed response.
These strings can appear while the player is at Baccarat, Roulette, Bar Dice, Video Poker, or Slot/Pinball/Buffalo. FoundationMain._resolve_game_action() unconditionally passes result.message to _show_message(), so the incorrect noun is player-visible rather than diagnostic-only.

##### Root cause

The action-authority system originated as a Blackjack host and was generalized to six providers without generalizing its text contract. scripts/ui/foundation_main.gd contains 55 remaining Blackjack references. Many are comments, but numerous literals are returned from shared code paths at lines 1651-1992 and 2288-2641. The active current_game and its display name are available, but none of these error builders use them.
Six modules currently implement the shared authority contract: Bar Dice, Baccarat, Blackjack, Roulette, Slot, and Video Poker.

##### Fix options

- 1. Replace provider-specific shared-host prose with neutral localized keys such as sealed_action.pending, sealed_action.retry_failed, and sealed_action.boundary_failed.
- 2. Pass a trusted game display-name key in the authority contract only when naming the provider improves the message.
- 3. Separate internal diagnostic detail (“proposal fingerprint mismatch”) from concise player recovery copy.
- 4. Add a table-driven test that invokes every rejection code once for every authority provider and asserts that no other game's name appears.

##### Evidence

scripts/ui/foundation_main.gd:1651-1992
scripts/ui/foundation_main.gd:2288-2641
scripts/ui/foundation_main.gd:12220-12330
scripts/ui/foundation_main.gd:12430

#### BTH-056 / EXT-TXT-002 — Grand Casino result copy reports dollars or “Bankroll” when the applied balance is chips

Severity: Medium   |   Confidence: High   |   Status: Confirmed
Severity: P2 / Medium Frequency: common on affected Grand Casino game results Affected games: Blackjack, Baccarat, Roulette, Video Poker, Bar Dice, and potentially any newly routed module that authors cash-centric result prose; Craps already demonstrates the correct explicit-unit pattern

##### Reproduction

- 1. Enter a Grand Casino instance of an affected game, where wagers use casino chips.
- 2. Complete an action that wins, loses, or places a wager.
- 3. Compare the result sentence with the balance that actually changes.

##### Expected

The message should say chips, show a chip icon/label, or use a neutral localized balance-change phrase consistent with the applied account. Dollar signs should be reserved for cash.

##### Actual

Examples authored by the game modules include:
Blackjack: Blackjack wager placed: $N on the felt. and result fragments such as Main +N.
Baccarat: Commission $N and Net +N without identifying chips.
Roulette: Bankroll +N.
Bar Dice: a $N pot, $N rake, then Bankroll +N.
Video Poker: Bankroll +N.
At the Grand Casino, those module bankroll_delta values are converted into chips_delta; the cash bankroll delta is set to zero. The prose can therefore tell the player that cash/bankroll changed when only chips changed.

##### Root cause

Game modules construct final English text before the shared economy layer determines the authoritative currency. GameModule.apply_result() calls RunState.route_grand_casino_game_currency() at scripts/core/game_module.gd:867. The router (scripts/core/run_state.gd:4702-4729) recognizes seven Grand Casino chip games, moves the proposed bankroll_delta into chips_delta, zeroes bankroll_delta, and sets result.currency="chips". It updates numeric result fields but does not rebuild result.message.
Craps already avoids the ambiguity in _roll_message() by choosing cash for Street Craps and chips for the casino table (scripts/games/craps.gd:1171-1182). The other modules do not consistently make that distinction.

##### Fix options

- 1. Build player-facing result copy only after currency routing, using result.currency, bankroll_delta, and chips_delta.
- 2. Carry structured result-message keys and parameters from each module; let the host supply the final currency noun/symbol.
- 3. Use separate formatters for cash, chips, and mixed settlements. Do not use $ as a generic score marker.
- 4. Add Grand Casino and non-casino message assertions for every routable game, checking both the named unit and the balance that actually changes.

##### Evidence

scripts/core/game_module.gd:852-873
scripts/core/run_state.gd:119
scripts/core/run_state.gd:4279-4289
scripts/core/run_state.gd:4702-4729
Packaged production captures: .tmp/playtest_2026-09-20/packaged_platform/windows_l02/report.json and windows_l02_repro/report.json (Bar Dice Bankroll -10, Baccarat unitless Net -20, Roulette Bankroll -1, contrasted with Craps Net -10 chips)
.tmp/playtest_extended/localization_text/static_evidence.md

#### BTH-057 / EXT-TXT-003 — Run outcome card switches to an inconsistent 24-hour clock without a suffix

Severity: Low   |   Confidence: High   |   Status: Confirmed
Severity: P3 / Low Frequency: every completed run; most obvious for times at or after 13:00 Area: run report outcome header

##### Reproduction

- 1. Finish a run at 13:00 game time.
- 2. Compare the outcome-card where line with the in-run HUD and run-report replay clock.

##### Expected

The same game time uses one consistent convention. Under the current English UI, 13:00 should appear as 1:00 PM everywhere.

##### Actual

HUD/replay/schedules: Day N 1:00 PM.
Outcome where line: Day N, 13:00.
The outcome line has neither an AM/PM suffix nor any setting or locale signal that the display intentionally changed to 24-hour time.

##### Root cause

The project has several independent clock formatters. RunState.clock_display_text(), FoundationHudViewModel.clock_model(), Scratch Ticket schedule copy, and RunReportViewModel.format_game_clock() all convert to a 12-hour clock with AM/PM. RunReportViewModel.build_outcome() separately divides total minutes and interpolates raw hour into %02d:%02d (scripts/ui/run_report_view_model.gd:496-507) instead of calling the existing formatter.

##### Fix options

- 1. Route every game-clock display through one locale-aware formatter.
- 2. Make 12/24-hour preference explicit if both styles are intentionally supported.
- 3. Add boundary tests for midnight, noon, 13:00, and day rollover across HUD, schedules, map, report outcome, and replay clock.

#### BTH-058 / EXT-TXT-004 — Hand-built grammar produces singular-count and sentence-joining errors

Severity: Low   |   Confidence: High   |   Status: Confirmed
Severity: P3 / Low Frequency: deterministic at affected count values Area: Scratch Tickets, Pull Tabs, Baccarat, career/crew/action status copy

##### Reproduction examples

Deplete Scratch Ticket stock until one ticket remains in one active row.
Deplete Pull Tabs until one ticket remains.
Display an action-duration record whose duration is one action.
Resolve a Baccarat natural hand.

##### Expected

1 ticket, 1 active row, 1 action, and a visible separator between the natural-hand sentence and the settlement counts.

##### Actual

Templates emit phrases such as:
1 tickets across 1 active rows.
1 tickets remain across four deal rows.
1 actions.
Natural hand.0 won, 1 lost, 0 pushed.

##### Root cause

Grammar is assembled ad hoc. Some files correctly concatenate "" if count == 1 else "s", while other status templates bake in the plural noun. Baccarat separately concatenates natural and bet_text with adjacent %s%s placeholders; the first fragment ends in a period and the second has no leading whitespace. There is no shared count-message or sentence-composition boundary, so correctness depends on each author manually supplying English suffixes and separators.
Confirmed sites include:
scripts/games/scratch_tickets.gd:189
scripts/games/pull_tabs.gd:372
scripts/ui/career_stats_view_model.gd:170
scripts/core/crew_play_model.gd:176,346
scripts/core/run_action_service.gd:1228
scripts/games/baccarat.gd:2872-2895
Production reproduction: .tmp/playtest_2026-09-20/packaged_platform/windows_l02/report.json:14013 and windows_l02_repro/report.json:14011

##### Fix options

- 1. Replace suffix concatenation and baked plural nouns with localized plural messages keyed by count.
- 2. Add zero, one, two, and large-count assertions for every count-bearing status model.
- 3. Keep count numeric values structured until presentation so locales with more than two plural categories can work correctly.

## False positives, exclusions, and passed risk areas

### Persistence false positive rescinded

The broad fuzz harness initially appeared to drop pending dynamic-scenario facts and mutate restores. Independent production-path validation proved the opposite. The harness sent RunState.to_dict() through raw JSON directly into RunState.from_dict(), bypassing RunSaveCodec's exact-integer wrapper. Actual SaveService disk tests preserved queue sizes 2 → 2 → 2 in two seeds across two generations, with byte-identical loaded snapshots and successful post-restore travel. This is a test-maintenance finding, not a player bug.
Relevant production path: scripts/core/save_service.gd:328–371 and scripts/core/run_save_codec.gd:204–216, 274–290, 392–409. Evidence: .tmp/playtest_2026-09-20/persistence_chaos/persistence_probe.json.

| Excluded signal | Reason excluded |
| --- | --- |
| Nine base-room footprint warnings | They violate the desired 8 px spacing margin but their actual interaction rectangles do not intersect. |
| Five additional Bar scenario footprint warnings | Visually crowded but no direct hitbox intersection; retained as diagnostics only. |
| Talk popup / closing-time failures | Fixtures call FoundationMain before the staged UI reaches the production ready boundary. |
| Dialogue effect failures | Fixture event IDs do not match the host-authorized queued event ID; production correctly rejects them. |
| Motel → Jazz Club continuation | Fuzz selector omits the production availability filter and chooses an unavailable destination. |
| Bar Dice pseudo-midstep restore | The fixture discards the local ui_state that defines the controlled-roll midstep. |
| Suite wall-time overrun | All four shards passed; dedicated frame/resolve probes were green. Classified as test-runner telemetry. |
| Old Blackjack/Baccarat/Roulette spikes | Did not reproduce on the current candidate; current measurements are within budget. |
| Oversized 500-seed Blackjack job | Reached its explicit 30-minute cap without an assertion or engine error; replaced by a bounded 120-seed/1,000-hand run that passed. |
| Crew golden-byte drift | Exact hashes target a baseline already modified in the shared worktree; behavioral Crew contracts passed. |
| Jazz invitation assertions | The fixture resolves without enqueueing host authorization; production correctly rejects the event. |
| Jazz fixed-zone assertions | Expectations conflict with current authored anchors and overlap any genuine placement symptoms already covered by the UI report. |
| Performance soak expected refusals | All-in cancellations, unfinished Slot bonuses, unavailable Bar Dice antes, and sold-out Scratch Tickets were valid fail-closed outcomes, not liveness bugs. |
| Shutdown-only ObjectDB warnings | Two runs emitted an exit-only warning, but every in-run retained sample had zero orphan nodes and all processes exited normally. |
| EXT-PERF-003 duplicate | Its 82 runtime wrong-game messages independently confirm EXT-TXT-001's shared-host Blackjack wording root cause; counted once under EXT-TXT-001. |

### Verified passes

| Risk area | Result |
| --- | --- |
| All 11 game modules | Functional contracts passed; no rule/authority/stuck-state defect confirmed. |
| Performance/endurance | Three 360-minute runs passed: zero sampled orphan nodes, maximum serialized state 1,071,562/1,500,000 bytes, bounded caches, and no sustained retained-memory or liveness regression. |
| Tutorial stability | Both routes complete; 100-seed stuck sweep 0 failures; 56 save-boundary and 1,622 guardrail transitions passed. |
| Persistence | Actual disk save generations preserve scenario queue, travel, travel lock, closing, triggered event, and terminal state. |
| Environment loading | All 18 archetypes rendered; no room failed to load. |
| Windows package startup | Fresh-profile start and tutorial entry passed twice with zero content validation errors. |
| Archive integrity | Web zip matches current distributable entries; Windows archive extracts and native solver DLL matches. |
| High-volume game rules | All sampled RTP/rules bands passed: 3.5M Scratch outcomes, >40M Craps rolls, 60K Slot outcomes, 2K Baccarat hands, and 200 Roulette seeds. |
| Cross-game continuations | 22,800 generalized scenario evaluations completed with no stuck state. |
| Progression catalog | 55 scenarios, 1,485 pair comparisons, 11 hostile rejections, 55 dossiers, and one 55-room finalization family passed. |
| Corrupt-save fallback | 16/16 corrupt-primary cases correctly restored the prior atomic generation. |

## Evidence index and handoff

| Evidence set | Path |
| --- | --- |
| UI/environment specialist report | reports/playtest_2026-09-20/ui_environment.md |
| Gameplay/progression specialist report | reports/playtest_2026-09-20/gameplay_progression.md |
| Games/performance specialist report | reports/playtest_2026-09-20/games_performance.md |
| Persistence/chaos specialist report | reports/playtest_2026-09-20/persistence_chaos.md |
| Accessibility/input specialist report | reports/playtest_2026-09-20/accessibility_input.md |
| Packaged-platform specialist report | reports/playtest_2026-09-20/packaged_platform.md |
| Extended accessibility/input report | reports/playtest_2026-09-20/extended_accessibility_input.md |
| Extended persistence/chaos report | reports/playtest_2026-09-20/extended_persistence_chaos.md |
| Extended packaged-platform report | reports/playtest_2026-09-20/extended_packaged_platform.md |
| Extended game-rules/fuzz report | reports/playtest_2026-09-20/extended_game_rules_fuzz.md |
| Extended progression/economy report | reports/playtest_2026-09-20/extended_progression_economy.md |
| Extended audio/feedback report | reports/playtest_2026-09-20/extended_audio_feedback.md |
| Extended lifecycle/recovery report | reports/playtest_2026-09-20/extended_lifecycle_recovery.md |
| Extended localization/player-text report | reports/playtest_2026-09-20/extended_localization_text.md |
| Extended performance/soak report | reports/playtest_2026-09-20/extended_performance_soak.md |
| Three-run soak evidence | .tmp/playtest_extended/performance_soak/foundation_soak_360_{a,b,diagnostic}.json |
| Fresh 18-room layout data | .tmp/playtest_2026-09-20/ui_environment/fresh_layout/layout_report.json |
| Current performance data | .tmp/playtest_2026-09-20/games_performance/performance_current.json |
| Accessibility observations | .tmp/playtest_2026-09-20/accessibility_input/accessibility_probe.json |
| Production SaveService observations | .tmp/playtest_2026-09-20/persistence_chaos/persistence_probe.json |

### Recommended ownership

Environment/layout owner: UIE-001–021 and UIE-025, starting with the false-clean audit and route authority.
Table-game UI owner: UIE-022-A/B, with occupied-rectangle contracts for patrons, dealer widgets, and opponent rows.
UI/art owner: UIE-023/024 and title/label readability tests.
Tutorial owner: GP-01 and the out-of-order lesson focus regression.
Accessibility owner: A11Y-001–005, preferably as one cross-surface policy pass with keyboard-only regression coverage.
Release owner: PKG-001/002 version identity, immutable staging, and cross-platform artifact custody.
Persistence owner: PERSIST-EXT-01 codec failure propagation, atomic generation preservation, and fresh-service loadability checks.
Transaction/authority owners: EXT-GAME-001 and XPE-01, with whole-run snapshot equality on rejection and debt-boundary funding tests.
Release owner: EXT-PKG-003/004 packed-manifest hygiene and executable/native-sidecar custody.
Audio owner: EXT-AUDIO-001–006 cache identity/eviction, pause synchronization, true mute, settings recovery, and WebAudio delivery fallbacks.
Application lifecycle owner: LIFE-001–003 focus/minimize simulation pause, captured-input cancellation, and Settings cancel/preview rollback.
Presentation/localization owner: EXT-TXT-001–004 structured game identity, authoritative currency, shared clock format, and plural grammar.
Run-state and Coin Pusher owners: EXT-PERF-001/002 immutable scenario provenance, non-destructive semantic refresh, and rollback with a complete fallback path.
End of report. No product fixes were made during this assignment.
