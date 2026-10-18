# Beat the House — Extended Audio, Feedback, Pause, and Recovery Playtest Report

**Date:** 2026-09-20  
**Scope owner:** extended audio/feedback playtester  
**Disposition:** investigation and documentation only; no product source or data changed  
**Evidence root:** `.tmp/playtest_extended/audio_feedback/`

## Executive summary

This wave audited audio behavior, consequence telegraphing, pause/settings state, repeated scene changes, long-session audio resource ownership, and player-visible recovery. The strongest defect is a cache-identity error in procedural music: production scenarios, weather, and intentionally unique jazz-club instances can produce different music profiles that share one cache key, causing later scenes to replay the first cached composition. The content impact is broad—55 distinct scenario overrides across 12 archetypes use profile axes omitted from the key.

After the serialized runtime became available, the production-scene probe was run in **two independent Godot processes**. Both exited 0 with no probe failures. Across the two runs, all four cache-pair comparisons collided despite different profiles and theory, all four Run Menu/Settings sequences advanced the supposedly paused surface clock, all twelve zero-volume bus observations remained unmuted at −80 dB, and all four invalid-settings loads silently produced defaults. EXT-AUDIO-003 and EXT-AUDIO-006 remain source-proven lifecycle/control-flow defects; browser buffer quantification and WebAudio fault injection were not available in this native headless window.

The in-run menu has a separate pause split: it freezes authoritative game progression but never freezes the game-surface clock. Timed presentation and `_sync_surface_audio()` continue behind the menu and Settings overlay. This can finish or advance hidden animations and their audio cues while the player reasonably believes the game is paused.

Long-session ownership also warrants correction. Both Godot-side procedural PCM caches and the browser `AudioBuffer` registry retain all distinct audio until process/page teardown, with no eviction. The browser diagnostic registry can be reset independently of the actual JavaScript cache, masking retained memory during a soak.

Three lower-severity recovery/controls defects were also traced: volume sliders at 0% attenuate to –80 dB rather than muting, malformed settings silently discard all preferences, and WebAudio SFX callers ignore bridge delivery failures. Visual heat feedback itself has a sound reduced-motion fallback: the large flash is suppressed while the HUD’s numeric `+Heat` badge remains active, so that behavior is not reported as a defect.

## Coverage and method

- Read-only trace of `FoundationMain`, `GameSurfaceCanvas`, settings persistence, the procedural music player, surface SFX player, WebAudio bridge, heat feedback overlay/HUD, scenario application, weather music modifiers, and generated environment music.
- Production-data inventory of all scenario music overrides.
- Review of lifecycle/reset behavior for one-shot pools, loop ownership, marker dictionaries, PCM caches, and browser audio nodes.
- Executed the isolated production-scene probe at `.tmp/playtest_extended/audio_feedback/audio_feedback_probe.gd` exactly twice after the performance worker explicitly released the shared runtime; both processes exited 0 in 17.997 s and 17.682 s with an empty probe `failures` array.
- Existing test/probe review to distinguish harness limitations from product behavior.

The SFX one-shot pool is bounded at ten players, surface selection trace is capped at 256 records, normalized-event cache clears above 512 entries, and timed markers are cleared at animation/profile boundaries. Those were investigated and excluded as leaks.

## Runtime validation summary

| Candidate | Independent runtime result | Disposition |
|---|---|---|
| EXT-AUDIO-001 | 4/4 production pair comparisons (Bar and Jazz Club in each process) had `same_cache_key=true`, `different_profiles=true`, and `different_theory=true` | Confirmed |
| EXT-AUDIO-002 | 4/4 production game entries reported authoritative progression paused while `canvas_environment_activity_paused=false`; all 8 timed menu/settings samples advanced 302–306 ms during a nominal 300 ms wait | Confirmed |
| EXT-AUDIO-003 | Shared soak A traversed diverse environments, but headless procedural-audio caches stayed at zero; browser/decoded-audio growth was therefore not measured | Retained on static ownership proof; quantitative Web severity unmeasured |
| EXT-AUDIO-004 | 12/12 bus observations (Master/Music/SFX across four applications) were −80 dB, unmuted, and `0.0001` linear | Confirmed |
| EXT-AUDIO-005 | 4/4 invalid loads (two malformed JSON, two wrong-root arrays) returned complete defaults through a void/no-outcome contract | Confirmed |
| EXT-AUDIO-006 | Native headless runtime cannot activate or fault-inject the WebAudio bridge | Retained on static control-flow proof; browser fault injection unrun |

The intentional malformed-JSON fixture produced one expected engine parse error per process. Each probe also emitted identical ObjectDB/one-resource exit diagnostics because the evidence harness quits immediately without freeing its instantiated production scene; those teardown-only lines were classified as harness artifacts, not extra product defects.

## Findings

### EXT-AUDIO-001 — Music cache key reuses stale compositions across distinct scenarios, weather states, and unique jazz rooms

**Severity:** P2 / Medium  
**Frequency:** deterministic for same-key, different-profile revisits  
**Area:** procedural music, repeated scene changes, environmental telegraphing  
**Confidence:** confirmed by two independent production-scene probe processes plus exact key/profile source trace

#### Reproduction

1. Visit a procedural-music archetype under one scenario and allow its full stem set to cache—for example a Bar scenario with its authored BPM/ambience/texture override.
2. Leave and later enter the same archetype under a different scenario whose music override changes BPM, mode, texture, ambience, or volume.
3. Compare the effective environment `music_profile` and `ProceduralMusicPlayer.music_stem_manifest_snapshot_for_environment()` cache key.
4. Repeat with two independently generated Jazz Club instances. Their saved `generated_signature`, BPM, mode, root, progression, and motif differ by design.

#### Expected

Every profile change that alters generated PCM or an authored arrangement must select a distinct cached stem set, or explicitly update the active stems so the music matches the current room and weather.

#### Actual

The profile changes, but the base cache key does not. Once a full stem set exists for that key, `play_for_environment_state()` reuses it. The old PCM can therefore accompany a new scenario/profile, suppressing tension, calm, weather texture, or the Jazz Club’s advertised unique composition.

The production scenario catalog contains **55 distinct music overrides across 12 archetypes**. Within every archetype, every override is distinct:

| Archetype | Distinct overrides sharing one base identity |
|---|---:|
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

The runtime probe confirmed the identity collision in 4/4 pair comparisons. The Bar pair had materially different arrangement durations (65.195 s versus 36.606 s) but the same key, `stem:11:bar:local bar:bar:procedural`. The two generated Jazz Club rooms had different ids, signatures, BPM, mode, root, motif, texture, and theory output but shared `stem:11:jazz_club:classical jazz club:jazz:procedural`. Both independent process runs produced the same result.

#### Root cause

`_music_profile_from_environment()` builds a profile containing environment id, mood, mode, texture, texture seed/rate, BPM, root, safety, ambience, volume, phrase count, adaptive tempo, layer choreography, progression, and motif (`scripts/ui/procedural_music_player.gd:2885-2937`). `_ambient_cache_key()` includes only version, archetype, theme, palette, and authored track (`2940-2948`). The cache reuse path at `463-465` assumes that underspecified key fully identifies the PCM.

The omission conflicts with three production systems:

- scenario state deep-merges `music_profile_override` (`scripts/core/scenario_engine.gd:1728-1729`);
- weather mutates ambience, volume, and texture (`scripts/core/run_state.gd:12704-12712`);
- Jazz Club generation deliberately randomizes mode, texture, BPM, root, progression, motif, arrangement length, and `generated_signature` per instance (`scripts/core/environment_instance.gd:759-796`).

`_remember_profile()` can also overwrite metadata under the colliding key while the old stem set stays cached, so later diagnostics can show a current profile alongside stale PCM.

#### Fix options

1. Make the stem-cache identity a stable hash of every PCM-affecting profile field, including generated signature and relevant authored selection state.
2. Separate composition identity from live mix identity: include mode/texture/BPM/root/progression/motif/phrase count in the PCM key, while ambience/volume that are genuinely mix-only should update gains without forcing regeneration.
3. Add a contract test that generates two same-archetype scenario instances and two Jazz Club instances, asserts distinct profile fingerprints, and requires either distinct stem keys or proven mix-only equivalence.

---

### EXT-AUDIO-002 — Run Menu and in-run Settings do not pause the game-surface clock or timed audio presentation

**Severity:** P2 / Medium  
**Frequency:** every in-game pause/settings opening  
**Area:** pause state, hidden feedback, slots/table presentation  
**Confidence:** confirmed by four production game entries across two independent probe processes plus exact pause-ownership source trace

#### Reproduction

1. Enter any game surface; the defect is most audible during a Slot spin or another timed sequence.
2. Open the HUD Run Menu while the sequence is active.
3. Optionally open Settings from the Run Menu and remain there longer than the sequence duration.
4. Listen for loop/cue progression and inspect `surface_simulation_time_msec` before and after the pause interval.
5. Resume the game and observe presentation state.

#### Expected

The Run Menu is the product’s simulation pause owner. Game-surface simulation clocks and state-driven timed audio should freeze, or active gameplay SFX should be explicitly paused/ducked and resume from the same presentation point.

#### Actual

Authoritative game progression freezes because `_simulation_progression_paused()` includes the Run Menu. The game-surface canvas continues processing, advances `surface_simulation_clock_msec`, and calls `_sync_surface_audio()` behind the overlays. Timed cues can fire unseen, active reel loops can continue, and the visible animation may be at a later/completed phase when the player resumes.

All four runtime entries reproduced the split: `simulation_progression_paused=true`, `canvas_environment_activity_paused=false`, Run Menu visible, Settings visible, and screen still `GAME`. During each nominal 300 ms wait, Run Menu clock deltas were 302–305 ms and Settings deltas were 303–306 ms. None of the eight samples froze.

#### Root cause

`GameSurfaceCanvas.set_environment_activity_paused()` owns the pause-safe simulation clock (`scripts/ui/game_surface_canvas.gd:127-133`, `1257-1282`). `FoundationMain` only calls that method from the Pal tutorial-conversation handler (`scripts/ui/foundation_main.gd:9723-9738`). Opening or closing the Run Menu and Settings never updates canvas pause state. Settings correctly stacks on the still-visible Run Menu (`16221-16255`), so the authoritative simulation remains paused while the presentation clock is not.

The canvas calls `_sync_surface_audio()` before presentation early returns (`scripts/ui/game_surface_canvas.gd:1257-1267`), which propagates the clock mismatch into audio markers and loops.

#### Fix options

1. Centralize canvas pause ownership around `_simulation_progression_paused()` and update both environment/game canvases whenever modal state changes.
2. Give surface SFX an explicit pause/resume contract for loops and scheduled markers; do not merely stop and restart loops from zero.
3. Add a production-scene regression: start a timed surface channel, open Run Menu then Settings, advance real time, and assert the surface simulation clock, marker count, and loop phase do not advance.

---

### EXT-AUDIO-003 — WebAudio and procedural PCM caches retain decoded audio for the entire page/app lifetime

**Severity:** P2 / Medium  
**Frequency:** monotonic with distinct music/SFX keys over long sessions  
**Area:** long-session memory, repeated scene changes, Web build  
**Confidence:** high static ownership proof; quantitative browser/audio-cache severity unmeasured

#### Reproduction

1. On Web, visit distinct environments and exercise multiple game surfaces/features so new music stems and SFX streams are registered.
2. Return to the main menu, start another run, and repeat with different rooms.
3. Sample the browser audio-buffer registry and Godot resource memory after each batch.
4. Call the existing audio debug-stat reset and compare the reported registered count with actual browser memory.

#### Expected

Inactive decoded PCM should be bounded by an LRU/byte budget, or cleared at a documented lifecycle boundary. Debug reset must not imply that resource ownership was reset when it was not.

#### Actual

Every registered WebAudio PCM payload remains in `window.BTHWebAudio.pcmBuffers` until the page is destroyed. Stopping music/all sources removes active nodes but not buffers. Godot simultaneously retains full/primer/instant/Web-bed stem sets across `stop()` and run changes. No byte limit or eviction policy exists for those caches. Resetting GDScript debug stats clears only `_registered_pcm_keys`, so the reported count can fall to zero while JavaScript buffers remain allocated.

#### Root cause

- Browser registry creation and insertion: `scripts/ui/web_audio_bridge.gd:167-179`, `226-247`.
- `stopAll()` removes sources only: `454-466`.
- There is no deletion, size limit, or LRU path for `pcmBuffers`.
- Procedural caches are cleared only in `_exit_tree()` (`scripts/ui/procedural_music_player.gd:330-342`); `stop()` explicitly preserves them (`508-575`).
- `_ambient_stream_cache`, `_ambient_primer_cache`, `_ambient_instant_cache`, and `_web_music_bed_cache` have no limits. Only the unrelated authored-manifest metadata cache has a 32-entry bound.

At a typical 82 BPM, four 32-step phrases are roughly 47 seconds. Nine mono 44.1 kHz/16-bit playback roles are approximately 37 MB of raw PCM for one full procedural stem set before primer/instant and engine overhead. Retaining many distinct room/selection keys can therefore become material.

The 360-minute headless shared soak traversed diverse environments, but its procedural-music/audio stream and player caches remained at zero; it did not exercise the decoded-audio ownership path and cannot quantify this finding. No browser runtime was available, so the report intentionally does not claim a measured Web memory slope.

#### Fix options

1. Add a byte-budgeted LRU for both Godot stem sets and JavaScript `AudioBuffer`s, protecting only active/pending keys.
2. Clear run-scoped caches at return-to-menu/new-run boundaries while retaining a small shared hot set.
3. Add a real WebAudio `disposePcm(keys)` / `clearInactivePcm()` bridge operation and include actual JS buffer count/bytes in diagnostics.
4. Make debug reset observational only, or clearly separate “counter reset” from “resource clear.”

---

### EXT-AUDIO-004 — 0% volume is attenuation, not mute

**Severity:** P3 / Low  
**Frequency:** every Master/Music/SFX slider set to 0%  
**Area:** settings, accessibility, WebAudio mix  
**Confidence:** confirmed by four applications and twelve live engine-bus observations across two independent probe processes

#### Expected

A user-selected 0% volume should guarantee silence for that bus.

#### Actual

Zero writes –80 dB and leaves the bus unmuted. On Web, the bridge converts –80 dB to a nonzero linear gain of `0.0001`. Native audio is also attenuated rather than hard-muted.

In both process runs, two applications each produced identical Master, Music, and SFX snapshots: −80 dB, `muted=false`, and `linear_gain=0.0001`. That is 12/12 nonzero-gain observations.

#### Root cause

`UserSettings._set_volume()` maps zero to –80 dB but never calls `AudioServer.set_bus_mute()` (`scripts/core/user_settings.gd:298-305`). `WebAudioBridge._audio_bus_linear()` returns zero only when the bus mute flag is true; otherwise it converts bus dB back to linear (`scripts/ui/web_audio_bridge.gd:700-706`).

#### Fix options

Set the bus mute flag when the normalized slider is zero and clear it when raised above zero. Preserve the prior nonzero dB value or recompute it from the slider when unmuting. Add native and Web contract assertions that 0% produces exactly zero output gain.

---

### EXT-AUDIO-005 — Malformed settings silently discard preferences with no player-visible recovery message

**Severity:** P3 / Low  
**Frequency:** deterministic when `settings.json` is malformed or has a non-object root  
**Area:** settings persistence, player-visible error recovery  
**Confidence:** confirmed by four isolated invalid-file loads across two independent probe processes

#### Expected

The game may safely fall back to defaults, but it should tell the player that preferences could not be read and identify whether defaults were applied. Ideally it should preserve/rename the corrupt file for support and avoid silently overwriting it until the player confirms.

#### Actual

Startup resets every preference to defaults, ignores malformed/wrong-type JSON, and applies those defaults without surfacing any message. The next successful Apply overwrites the only corrupt-file evidence.

Each process tested malformed JSON and a valid array root. All 4/4 loads returned the complete default settings object through a void/no-outcome API. Malformed syntax produced an engine parse line, but neither case returned a status that the UI could use; no player-visible recovery state was created.

#### Root cause

`UserSettings.load()` resets first and only calls `from_dict()` for a dictionary root; it returns no status (`scripts/core/user_settings.gd:60-69`). `FoundationMain._initialize_user_settings()` immediately applies the result without a load outcome (`scripts/ui/foundation_main.gd:8640-8645`). This differs from run-save recovery, which exposes corrupt/backup state on the main menu.

#### Fix options

Return a structured load outcome (`loaded`, `missing`, `recovered_defaults`, `invalid_schema`, `io_error`), preserve invalid files with a timestamped suffix, and surface a concise main-menu/settings banner.

---

### EXT-AUDIO-006 — WebAudio SFX delivery failures are ignored, dropping cues without retry or fallback

**Severity:** P3 / Low  
**Frequency:** when the bridge is available but payload registration/playback fails  
**Area:** Web audio recovery, feedback reliability  
**Confidence:** high static control-flow proof; browser fault injection unrun because the serialized slot was native headless only

#### Expected

If the WebAudio bridge rejects a payload or cannot decode/register it, the caller should retry, fall back to the engine player when viable, or expose a recoverable audio warning.

#### Actual

Surface SFX returns immediately whenever the bridge is available, regardless of `play_stream()`’s boolean result. Reel-loop startup additionally marks `_web_surface_loop_active = true` after an unverified request. A failed request is therefore treated as successfully active and no fallback plays. Browser decode failures are console-only.

#### Root cause

`SfxPlayer._play()` ignores the `WebAudioBridge.play_stream()` result and always returns on Web (`scripts/ui/sfx_player.gd:1602-1607`). `_start_reel_loop()` does the same and unconditionally marks the loop active (`1561-1569`). The bridge can legitimately return false when not ready, when stream payload materialization fails, or when JavaScript registration/playback rejects the request (`scripts/ui/web_audio_bridge.gd:515-531`).

#### Fix options

Honor the return value. For loops, set the active flag only after success and retain a bounded retry request. For one-shots, use an engine fallback where supported or count/report dropped cues through a player-visible “audio unavailable” status after repeated failures.

## Exclusions and non-bugs

- The surface one-shot player count is bounded at ten and uses deterministic voice stealing; it is not an unbounded node leak.
- Timed marker dictionaries are cleared on animation/profile changes; targeted prefixes are removed for Blackjack, Roulette, Baccarat, and Coin Pusher. They are not the long-session growth source first suspected.
- Surface selection trace is capped at 256 entries, and normalized-event cache clears above 512.
- Reduced Motion intentionally hides the full-screen heat flash, but the HUD preserves a numeric `+N` heat badge and static meter pulse while audio still plays. Consequence information is therefore retained without motion.
- Settings Back discards the unsaved draft on next open; this matches the explicit Apply/Back model and was not counted as a defect.

## Evidence index

- `.tmp/playtest_extended/audio_feedback/static_audit.md` — exact static traces, data counts, and ownership findings.
- `.tmp/playtest_extended/audio_feedback/audio_feedback_probe.gd` — isolated production-scene probe prepared for the serialized runtime window.
- `.tmp/playtest_extended/audio_feedback/audio_feedback_probe_run_1.json` — first independent process output.
- `.tmp/playtest_extended/audio_feedback/audio_feedback_probe_run_2.json` — second independent process output.
- `.tmp/playtest_extended/audio_feedback/audio_feedback_probe.json` — second-run convenience copy produced by the probe.
- `.tmp/playtest_extended/audio_feedback/audio_feedback_probe_run_1.stdout.log` / `.stderr.log` — first process logs.
- `.tmp/playtest_extended/audio_feedback/audio_feedback_probe_run_2.stdout.log` / `.stderr.log` — second process logs.

## Recommended triage order

1. Fix cache identity (`EXT-AUDIO-001`) because it defeats authored environmental music variation across a large share of production content.
2. Unify pause ownership (`EXT-AUDIO-002`) so hidden animation/audio cannot advance behind Settings.
3. Bound decoded PCM ownership and expose truthful diagnostics (`EXT-AUDIO-003`) before long Web sessions ship.
4. Correct hard mute and settings recovery (`EXT-AUDIO-004`, `005`).
5. Harden bridge delivery failure handling (`EXT-AUDIO-006`).
