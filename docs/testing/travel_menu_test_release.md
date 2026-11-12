# Travel-menu TEST candidate

## Scope

This revision keeps the approved eight-second shared travel presentation for
all 15 exterior destinations and the four canonical modes: walk, bus, taxi and
night cab. The existing shared character, locomotion blending, gentle irregular
vehicle suspension, measured doors/interiors and Delta Queen perspective remain
unchanged from `3cd4fc214c5cc7fb0193f5023f3f2751e6fe52cd`.

Only an explicit world-trip confirmation through the Travel menu opts in.
`_confirm_selected_travel_with_lifecycle_snapshot` and
`confirm_world_map_travel` mark a detached submitted choice. Neither a stale
screen nor a cached route supplies permission to animate. The existing retry
path retains the same submitted choice.

Internal Motel doors, Grand Casino rooms, Punchline layers, event/duel room
changes, private-room recovery and meta Home/Sal movement retain their normal
unanimated behavior. Direct offered rides, forced relocations and other
nonmenu world transfers also keep their ordinary result flow. Their committed
world receipt is acknowledged immediately, so it cannot surprise the player
with a pending cutscene after a reload.

The v1/v2 receipt schemas, synchronous travel transaction, route selection,
fare/clock/risk settlement and destination preparation are unchanged. Animated
journeys now enter the destination automatically after natural completion or
Skip. No new random incident variants or gameplay routes are added.
Triggered risks, accessibility, missing art, terminal outcomes and saved pending
receipts retain their existing safe presentation behavior. A catalog preview
combination does not establish that a route/method exists in a generated town.

The two door/vehicle renderers retain their white polygon color arrays instead
of allocating them in `_draw`; changing panel tints are prepared with the draw
plan. Geometry, tint formulas and autonomous redraw scheduling are unchanged.
All 552 matching decoded frames from six destinations are pixel-identical before
and after this optimization.

## Automatic arrival follow-up

The shared overlay defers its existing acknowledgment after the eight-second
cinematic finishes or the player selects Skip. The host's existing completion
path drains unfinished destination preparation, reuses its single published
canvas, acknowledges the settled receipt and restores normal focus/Coach
ownership. It never invokes travel again. A presentation-generation guard drops
callbacks belonging to cancelled or replaced presentations, including a new
presentation of the same journey ID.

Only an actual moving cinematic auto-completes. Reduced motion, missing art,
triggered risks, unsupported/legacy summary content and pending reload receipts
remain readable until manually acknowledged. Terminal outcomes keep their
existing flow. Menu-only eligibility, internal/direct travel exclusions,
receipt schemas, fares, clocks, RNG and autonomous redraw are unchanged.

Focused follow-up verification passed **11 bounded Jobs**, with **31,165
reported assertions**, the standalone no-input liveness/strict Coach lifecycle
checks and the established **571-file GDScript load check**. Coverage includes
all sixty shared presentation profiles, all four actual legal gameplay modes,
sixteen menu/exclusion path families, immediate and repeated Skip/Continue,
same-ID replacement, pending and acknowledged save/reload, visible current
destination canvas reuse, focus restoration and Coach foreground return.

Both fixed-30-FPS graphical playback and normal-delta graphical playback enter
automatically at 8.0 cinematic seconds. In the four normal-delta observations,
entry occurred 7.881-8.011 seconds after synchronous departure returned. The
separate unchanged departure work took 0.342-2.491 seconds. Each arrival reused
one canvas publication; early Skip drained unfinished preparation once. Cash,
time, destination, travel count, event state and RNG remained settled once.

The long taxi Continue label's 60px text minimum reproduced identically on the
prior and new overlay. Tests now check exact live bounds against the authored
box plus the current text minimum before comparing the shared authored layout.
No runtime layout change was made.

All counted Jobs were assigned before execution under 12% CPU/2 GiB limits and
released with zero active processes. The isolated Coach adapter passed its
behavioral checks but reported one leaked `GDScriptFunctionState` (reference
count 1) at exit; that adapter warning is not claimed resolved. The source-only
pixel checks emitted their existing thirty image-file/export warnings. No
runtime/parse errors occurred in the final passing Jobs. Initial diagnostic
runs and an incorrectly unrestricted aggregate-fragment loader are excluded.

Follow-up summary SHA-256:
`cab0ca4ce893ef1a456bf99dc0326a984a53a59cd9d6dcfb27ec65d768ad56c7`.
Raw Jobs, profiles and images remain outside Git. The full sixteen-fixture
destination replay, broad visual recapture, browser/WASM testing, export and
deployment were not repeated for this follow-up. The original qualification
and unrelated Smoke limitations below remain separate historical evidence.

## Export custody

`build_native_solver.ps1` accepts a validated `-Jobs` value and defaults to one
compiler job. This permits the pinned native dependencies to be built within
the required resource cap without changing solver source or ABI.

TEST uses an immutable branch-commit export and a separate additive site entry.
It must not merge the travel branch into main, change the NEXT watcher/pointer,
replace existing release payloads or alter the site's audience. Export identity,
native dependencies, browser verification and guarded evidence must be bound to
the exact candidate before publication.

Pinned dependency rebuilds used the unchanged current solver source and lock:

- Web release: 340,278 bytes, SHA-256
  `ffab741f9e431eb7056e09b668dddf28b8c95f941526ba185b67e27e33abc60a`.
- Windows debug: 909,824 bytes, SHA-256
  `528f8428b73fb3196b67dd145dba8e49fe2053ff19a7fac1c3be2c85c957d9ec`.
- Locked Web engine template SHA-256:
  `cf371f607aa9cb18e690bd595976c1baaf00c8cec24078e4a307fd515ad07913`.

Both native build Jobs completed successfully with zero active processes at
release. Rebuilt binaries and toolchain installations are ignored local outputs,
not committed source. An archived binary with a different solver blob was not
reused.

The PCK auditor now recognizes Godot's legitimate `.gdshader` resource suffix.
Its focused contract passes two allowed shader cases and thirteen rejected
development/private/credential or misleading-suffix cases; existing rejection
gates are unchanged. Runtime/art qualification is unaffected by this tooling-only
correction, and the final export must still pass a fresh PCK audit.

TEST packaging must isolate persistence from existing releases. The supported
loader contract is `persistentPaths = ["/userfs/bth-test-travel-v1"]` and an
external `override.cfg`, preloaded before engine `callMain`, setting
`application/config/use_custom_user_dir = true` and
`application/config/custom_user_dir_name = "bth-test-travel-v1"`. This maps the
unchanged Web distribution save root to
`/userfs/bth-test-travel-v1/distribution/web_0_6_1` in its own IndexedDB database.
The ordinary `/userfs` database must never be opened by TEST. A failed override
preload must stop startup rather than fall back to production storage. Actual
same-origin sentinel and reload verification is required before deployment;
user saves must not be copied, migrated or deleted.

## Verification status

Native qualification passed **24 focused Jobs**, with **122,974 reported
assertions plus the standalone no-input liveness check**:

- Standard integration 711; initial prototype integration 118.
- Destination integration 60,750 over 16 real legal-route fixtures, covering
  all fifteen destinations and all four actual methods.
- Menu scope 334 headless and 334 graphical checks across sixteen path families.
  These include public menu confirmations, internal doors/rooms/layers/meta,
  direct and forced travel, Rafi's actual offered ride, malformed opt-in values,
  stale screen state, and save/reload. Exact integer RNG and settlement guards
  remain independent of the JSON representation of nested event rectangles.
- Seven visual suites in headless and graphical modes; destination preparation
  in both modes; current receipt compatibility and animation liveness.
- All sixty catalog combinations advanced naturally for 270 fixed-FPS frames
  each, including the eight-second scene and one-second hold. Captured 1,380
  keyframes; reviewed 300 across all sixty cases, plus full-size door/ramp views.
  These are explicitly visual-only combinations, not fabricated gameplay trips.

All counted Jobs exited successfully, were assigned before resume and released
with zero active processes. Each used admitted E: storage, 12% CPU and 2 GiB
limits. Final native summary SHA-256:
`72fde3cba056877ef1bbad3422c64db32553a21655ad8c945781ba1eedda4f7a`.
Source hash-list SHA-256:
`5287f267f85d1e5538072304963b47b5133adaf438af1cc0de936cd377c916bf`.

Broader Smoke is **not fully green**. The initial exact eight-stage census had
four passing and four failing stages. Every original failure reproduced, in the
same order, on all 3,871 verified files of committed baseline `3cd4fc2`:
content 29, runtime 7, first UI Coach gate, and three functional perf assertions.
The six travel allocation findings and stale independent fare fixture are now
fixed, leaving the same 22 unrelated content failures. The Coach test now
strictly checks cinematic ownership and actual Skip/Continue foreground return;
it passes, then encounters a later Pull Tabs Pal lesson failure that also
reproduces against baseline runtime. UI checks after that abort remain unproven.
The four passing Smoke stages were cold Continue, all eleven game launchers,
Dave's bus encounter and roulette audio. Import and all 571 GDScript loads passed.

Baseline comparison SHA-256:
`92cd961a5b51e45a49cd0e386604fdf38d5d811d8556be2bf42644224f8665ae`.
Later UI baseline comparison SHA-256:
`bc17c9b206ec09f654e6d378ca1bbe358f572c5689c10207b7ff383d1b3d1512`.
The legacy aggregate wrapper was not run. `validate_project.ps1` remains unrun
because its ungated child launches, shared lease census and unowned-process
logic cannot meet this isolated task's execution requirements. Special duel
and recovery exclusions were source-reviewed, not all dynamically replayed.

Export, actual-browser and served-site custody are separate acceptance records
bound to the exact clean source commit and packaged file hashes. Native forced-
Web branch coverage is not browser evidence. This document does not claim a
full aggregate regression pass or a threaded/hitch-free destination load.

Raw profiles, captures, logs and build outputs remain outside the repository;
only concise verification summaries and file identities belong here.
