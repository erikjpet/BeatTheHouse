# audio06_1 Surface SFX Closeout

Date: 2026-09-03
Independent closeout branch: `codex/audio-closeout`
Integrated starting point: `9e8af74b712ed9c3a2bf69f9a330a57719cb0f85`
Status: **IN_PROGRESS pending the exact Family 1 integration and green cross-system rerun**

## Outcome

The existing shared surface-audio route is manifest-driven for every 0.6
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
hard voice cap.

The independent closeout found and corrected three gaps in the landed pass:

- Native playback previously consumed another idle global player before
  enforcing the requesting profile's cap. The shared deterministic planner now
  enforces same-surface stealing first.
- Web playback enforced the profile cap but did not enforce the ten-source
  global cap. It now performs the same same-surface-then-oldest-global policy as
  native playback.
- Generic cue, state-sync, prewarm, and loop helpers trusted caller-provided
  dictionaries. Foundation now injects a one-time opaque capability when it
  constructs the game canvas; Canvas and SfxPlayer reject missing, foreign, and
  rebound capabilities. Standalone canvases retain a private construction-time
  capability for their internal accepted-input path.

Manifest validation was also closed over entry/profile/loop keys, finite numeric
variation arrays, deterministic salts, safe IDs, counterpart classes, and
non-ambiguous wildcard profiles. These are validation and delivery hardening;
the legacy generic-cue fallback remains unchanged.

## Determinism and platform behavior

`SurfaceSfxManifest.select_event` is a pure seeded selector. Its input is the
run selection seed, profile, public event class, and occurrence index. The
selector has no wall-clock input and avoids adjacent repetition. Native and Web
receive the same selected event, pitch offset, and volume offset; platform code
only delivers that result. Profile palettes use the existing incremental Web
prewarm queue, so no manifest parsing or bulk sound generation occurs per frame.

## Independent verification

- `tools/audio06_1_surface_sfx_audit.gd`: PASS on the closeout candidate — 13
  profiles, 80 complete generated/delivered waveforms with signal, ten seed
  traces, native/Web selection parity, paired hidden-state observers, strict
  negative manifest cases, hostile capability/rebind cases, deterministic
  same/global stealing, bounded native/Web pools, SFX-bus routing, visual/text
  counterparts, and idle-frame no-event/no-load behavior.
- Focused Foundation combined runner: PASS — `music_fx_foundation` (79 ms) and
  `music_stem_director_foundation` (254 ms).
- `tools/roulette_audio_audit.gd`: PASS — 14 events, 254,016 PCM bytes, one
  intentional loop.
- `tools/validate_project.ps1 -Quiet`: PASS twice through the supported harness.
- Godot import: PASS. Non-test GDScript load sweep: PASS.

## Program-level findings still open

- The first Systems attempt placed its report under `docs/`, so the shard
  harness correctly refused a recursive `docs` junction. The retry used
  `.tmp/audio06_1/` as required.
- The broad Systems retry reached the inherited integrated Family 2 tree but
  timed out with broad non-audio game/world/save failures. Audio's two focused
  Foundation checks pass independently. Root is attributing the broad result
  against the untouched integration head before the Family 1 closeout lands.
- The UI-scene compile reached runtime and reported one unrelated Slot fixture-3
  serialize/restore mismatch. No audio/capability failure was reported.

For that reason this row is not archived or marked DONE here. After Family 1 is
integrated, rerun the exact audio audit, focused Foundation checks, UI compile,
full Systems/project validation, and native/Web release gates on the final tree.

The external music delta is recorded in
`docs/plans/audio_engineer_handoff.md`; no production music or music-system
behavior was authored in this row.
