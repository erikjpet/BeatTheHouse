# Agent Prompt - Jazz-First Audio Meeting Notes Execution

Copy everything below this line into the implementing agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript
casino roguelike. Implement the audio engineer's meeting notes as a native
Steam/mobile-first system. Do not reject, defer, or replace a requirement
because it is unusually ambitious. The web build may retain a reduced
fallback; it does not define the native music design.

## Read first

Read these files completely before changing code:

1. `docs/plans/music_system_rework_plan.md`
2. `docs/plans/audio_engineer_delivery_contract.md`
3. `data/audio/music_manifest.json`
4. `scripts/core/content_library.gd`
5. `scripts/ui/music_arrangement_selector.gd`
6. `scripts/ui/procedural_music_player.gd`
7. The six numbered prompts listed below.

Code reality wins for names and seams, but the musical behavior in these
prompts is binding. Preserve the current synchronized-stem director,
independent DSP sends, one-shot cues, four-musical-bar big-win envelope, and
phrase/fill transition work.

## Execution order

Execute these prompts in order. Complete and verify each slice before the
next one because every later slice uses contracts introduced earlier:

1. `docs/todo/audio_jazz_01_delivery_and_ingestion_prompt.md`
2. `docs/todo/audio_jazz_02_harmony_safe_arrangement_prompt.md`
3. `docs/todo/audio_jazz_03_native_adaptive_tempo_prompt.md`
4. `docs/todo/audio_jazz_04_phrase_fill_layer_choreography_prompt.md`
5. `docs/todo/audio_jazz_05_beat_synced_outcome_music_prompt.md`
6. `docs/todo/dave_bus_encounter_prompt.md`

Jazz Club is the vertical slice. Build every shared contract generically,
but do not spread unfinished content across every venue. Other environments
should keep their current behavior until their own authored profiles arrive.

The production recordings may not be present yet. Do not block on that.
Create the importer, manifest schema, deterministic fixtures, test WAVs, and
runtime paths needed for the engineer's files to drop in later. Never invent
or present generated fixture audio as the engineer's final music.

## Meeting-note authority

- Delivery filenames follow
  `Environment_Classification_Instrument_PatternNumber.wav`, for example
  `JazzClub_Lead_Trumpet_1.wav`.
- Looping stems are 8 or 16 bars. Jazz Club is first.
- Accept and correctly process 24-bit PCM WAV masters at native quality.
- Chords are the harmonic authority. Bass patterns are selected only from
  the same progression compatibility set and follow its root movement.
- Arrangement recipes must create deliberate forms such as AABA and AACA,
  including scheduled instrument changes, not random compatible-looking
  combinations.
- Heat subtly and gradually changes true playback tempo inside a per-venue
  BPM range. Preserve pitch and phase alignment on native builds.
- The director knows upcoming sections. It can remove loop drums two bars
  early, play a transition fill, and land all intended parts together on the
  next section.
- Time spent in a room drives a composed layer arc: gradual entrances,
  fuller peaks, and gradual exits/rebuilds.
- Wins and losses become beat-synchronized musical events. Reverb is a
  short controlled pulse, never an accumulating wash over the song.
- Bus travel can trigger a one-time meeting with Dave, who says:
  "Seek out the cruel and unusual."

## Cross-slice completion requirements

- All musical selection remains deterministic for the same run seed and
  event history.
- No allocation-heavy manifest parsing, bank selection, or bus discovery in
  per-frame paths.
- Save/load restores arrangement position, section, layer arc, tempo target,
  and pending musical events closely enough to resume deterministically.
- Missing production stems fall back safely without breaking a run.
- Headless snapshots expose each new state machine and scheduled transition.
- Update the engineer delivery contract to match the final implementation in
  plain language.
- Preserve unrelated dirty work. Use focused commits only when safe.

## Final gates

Run the focused gates named in every slice, then at minimum:

1. `powershell -ExecutionPolicy Bypass -File tools/validate_project.ps1`
2. `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -NoImport -FoundationSuite systems -TimeoutSec 300`
3. `powershell -ExecutionPolicy Bypass -File tools/check_godot.ps1 -RequireGodot -NoImport -FoundationSuite ui -TimeoutSec 300`
4. The current determinism probe covering music/event state.
5. Native Jazz Club listening QA at low, rising, high, and falling heat.

After each numbered prompt is implemented and verified, archive it under
`docs/todone/` with the execution record required by
`docs/todone/RULES.md`. Archive this orchestration prompt only after all six
slices are complete.
