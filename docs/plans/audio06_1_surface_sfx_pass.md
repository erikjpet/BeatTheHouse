# audio06_1 Surface SFX Closeout

Date: 2026-09-03
Working branch: `codex/closeout06-final`

## Outcome

The existing shared surface-audio route is now manifest-driven for every 0.6
ritual family. This extends the shipped Coin Pusher precedent; it does not add
a parallel sound system and does not change music behavior.

| Coverage | Profiles | Boundary source |
| --- | ---: | --- |
| Coin Pusher | 1 | Public cabinet contact/action facts |
| Craps and casino tables | 4 | Game actions and authored presentation channels |
| Slots, Video Poker, counter games | 4 | Sealed game actions and public result states |
| Bar Dice and Crew cards | 2 | Public tumble/card/tell presentation facts |
| Crew/world and scenario sequences | 2 | Public world facts and host-authored transition ops |

The thirteen profiles declare 80 unique procedural or delivered sound events.
Every event class declares a visible/text counterpart, uses the shipped SFX
bus, and carries the public-fact-only hidden-state policy. Each profile has a
hard voice cap. Native and Web both replace the oldest voice on the same
surface first, then the oldest global voice.

## Determinism and platform behavior

`SurfaceSfxManifest.select_event` is a pure seeded selector. Its input is the
run selection seed, profile, public event class, and occurrence index. The
selector has no wall-clock input and avoids adjacent repetition. Native and Web
receive the same selected event, pitch offset, and volume offset; platform code
only delivers that result. Profile palettes use the existing incremental Web
prewarm queue, so no manifest parsing or bulk sound generation occurs per frame.

## Verification to date

- `tools/audio06_1_surface_sfx_audit.gd`: PASS — 13 profiles, 80 streams, ten
  deterministic seed traces, visual counterpart/hidden-state policy, native/Web
  voice bounds, mixer/settings route, and transition-boundary checks.
- `tools/validate_project.ps1 -Quiet`: PASS after implementation.

Final repository-wide foundation, determinism, performance, accessibility, and
native/Web gates will be recorded here when the Family 1 and Family 2 closeout
branches have landed into the exact integration tree.

The external music delta is recorded in
`docs/plans/audio_engineer_handoff.md`; no production music or music-system
behavior was authored in this row.
