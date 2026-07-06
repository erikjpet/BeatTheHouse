# Agent Prompt — Web Audio Bridge Modernization (eval → get_interface, native-audio spike)

Copy everything below this line into the agent.

---

You are working in `D:\Projects\Beat-The-House`, a Godot 4.6 GDScript casino
roguelike (`config/features=PackedStringArray("4.6")` in project.godot; web
export preset has `variant/thread_support=true` in export_presets.cfg). All
audio is procedurally generated at runtime into 16-bit `AudioStreamWAV` PCM by
`scripts/ui/procedural_music_player.gd` (music stems) and
`scripts/ui/sfx_player.gd` (SFX cues).

## Current architecture and why it exists

On web exports, the game **bypasses Godot's audio server entirely**. Both
players route through `scripts/ui/web_audio_bridge.gd` (`WebAudioBridge`),
which installs a hand-built Web Audio API graph into the page and plays all
PCM through it. This was introduced in commit `6ae682b` ("Fix web audio
playback in exports") because native Godot web audio playback was broken for
this project's runtime-generated streams, and was later hardened by the LA.6
audio audit (see `docs/plans/0.3.2_low_end_web_cleanup_board.md`), which cut
music `_process` cost from ~1373µs to ~63µs.

The JS graph applies mastering desktop never gets: master 0.72 × output 0.92
gain, 38 Hz highpass, dynamics compressor (−6 dB threshold, 3:1 ratio, 180 ms
release), SFX gain clamp 1.25, pitch clamp 0.35–2.5, music-mix updates
throttled to ≥140 ms apart and smoothed with `setTargetAtTime` τ=0.08 s. These
values are asserted by `mix_contract_snapshot()` (web_audio_bridge.gd:534) and
covered by foundation checks — they are intentional product decisions, not
accidents.

## The structural defect you are fixing (Task A, mandatory)

Every interop call crosses via `JavaScriptBridge.eval` with **string-built JS
source**:

- `WebAudioBridge.play_stream` builds a JSON payload, string-formats it into
  JS source, and evals it (web_audio_bridge.gd:374-385). First-time
  registration of each unique sound embeds the full PCM as base64 (+33% size)
  inside that source string, so megabytes of audio data are run through the
  browser's JS *parser* on the main thread.
- Same pattern for `play_music_stems` (web_audio_bridge.gd:400-449),
  `set_music_mix` (:452-478), `stop_music` (:485-506), `stop_loop` (:388-397),
  `unlock` (:364-371).
- The `_eval_counts`/`_eval_bytes` telemetry (web_audio_bridge.gd:618-620,
  read by perf_telemetry_overlay.gd:386-401 as `la6_web_audio_bridge_stats`)
  exists precisely because this path was identified as the risk.

Godot documents that `eval` "performs poorly and is also very limited" and
provides `JavaScriptBridge.get_interface()`, which wraps a global JS object as
a `JavaScriptObject` whose methods you call directly with auto-converted
primitive arguments (int/float/String/bool) — no source parsing per call.
References:
- https://docs.godotengine.org/en/stable/classes/class_javascriptbridge.html
- https://docs.godotengine.org/en/stable/tutorials/platform/web/javascript_bridge.html
- https://godotengine.org/article/godot-web-progress-report-9/

**Required change:** keep exactly one `eval` — the one-time installation of
`WEB_AUDIO_SCRIPT` in `ensure()` (this is a legitimate use; the script defines
`window.BTHWebAudio`). After installation, acquire the interface once
(`JavaScriptBridge.get_interface("BTHWebAudio")`), cache it, and convert every
other call site to direct method calls. Payloads that are currently
`JSON.stringify`-ed into source strings should be passed as a single JSON
`String` argument and `JSON.parse`-d inside the bridge methods (add that
parsing to the JS side, bump `WEB_AUDIO_VERSION`/`BRIDGE_VERSION` to 4 so the
version guard replaces stale bridges). Base64 PCM still crosses as a string
argument — that is fine; the win is eliminating per-call JS parsing of source
that *contains* the data, not eliminating marshalling.

Constraints for Task A:

1. Preserve the public GDScript API of `WebAudioBridge` (static funcs and
   signatures) so `sfx_player.gd` (:132-133, :978-1013) and
   `procedural_music_player.gd` (~20 call sites; grep `WebAudioBridgeScript`)
   do not change behavior. Internal implementation changes only, unless a
   call-site change is strictly required.
2. Keep the telemetry contract: `debug_stats()` must still report call counts
   and payload bytes (rename fields honestly if they no longer measure eval
   bytes — e.g. `call_counts`/`payload_bytes` — and update
   `perf_telemetry_overlay.gd` and any foundation check that reads them).
3. `mix_contract_snapshot()` asserts substrings of `WEB_AUDIO_SCRIPT`
   (web_audio_bridge.gd:549-559). If you touch the script text, update these
   assertions to match the new intended text — do not weaken them to always
   true.
4. `get_interface` returns a `JavaScriptObject` only on web; all new code
   must stay behind `available()` so desktop/headless paths are untouched.
5. While you are in the file: `_wav_has_signal` (web_audio_bridge.gd:610-615)
   scans a `PackedByteArray` byte-by-byte in GDScript; its worst case (a truly
   silent stem) is a full scan of the WAV on the main thread. Make the scan
   cheap (e.g. stride-sample the buffer, or check a bounded prefix/suffix plus
   strided interior). It must stay allocation-free.
6. Per-frame paths must stay zero-copy — no `duplicate(true)` of live state
   per frame (this codebase shipped a 32.6 ms/frame regression from exactly
   that; see slot.gd watchdog history).

## Task B (evidence-gated spike, no retirement in this task)

Determine whether the bridge is still necessary on Godot 4.6, and write down
the verdict. Research facts to verify against, not assume:

- Since Godot 4.3, web exports default to **Sample playback** via Web Audio
  buffer nodes: low latency, works single-threaded, but **no AudioEffect
  support and no procedural audio**, and it has had ongoing stabilization
  bugs through 4.4/4.5 (e.g. godotengine/godot#109728, unhandled WASM error
  with stream-type playback). Sources:
  https://github.com/godotengine/godot/pull/91382 ,
  https://godotengine.org/article/progress-report-web-export-in-4-3/ ,
  https://github.com/godotengine/godot/issues/109728
- The threads variant uses an AudioWorklet driver with the full mixer, but
  requires a cross-origin-isolated host. itch.io's "SharedArrayBuffer
  support" embed option uses `COEP: credentialless`, which is Chrome-centric
  (not Safari; historically not Firefox for Android) — a real product
  constraint for a web release. Sources:
  https://itch.io/blog/456223/godot-cross-origin-isolation-and-sharedarraybuffers ,
  https://itch.io/t/2025776/experimental-sharedarraybuffer-support ,
  https://www.rafa.ee/articles/deploying-godot-4-html-exports/
- This project's music/SFX are runtime-generated `AudioStreamWAV` — samples,
  not `AudioStreamGenerator` — so Sample mode *may* now handle them; whether
  runtime-registered samples work reliably in 4.6 is exactly what the spike
  must establish.

Spike protocol:

1. Build a web export with `WEB_AUDIO_BRIDGE_ENABLED := false`
   (web_audio_bridge.gd:20) so the players fall back to native Godot audio
   paths. Verify first in code that a native fallback actually exists in
   `sfx_player.gd`/`procedural_music_player.gd` when the bridge reports
   unavailable — if audio is bridge-only on web, note that as a finding and
   test what actually happens.
2. Test matrix: (a) single-threaded export in Sample playback mode,
   (b) threads export served with cross-origin-isolation headers
   (`tools/web_perf_smoke.ps1` infrastructure can serve/drive Chrome headless;
   check whether its server sends COOP/COEP and extend it if trivial).
   Exercise: SFX one-shots, looping SFX, multi-stem music start/mix/stop,
   pause/resume, and the first-gesture unlock path.
3. Record results (working/broken/crackling, latency notes, console errors)
   in the verdict section below, restore `WEB_AUDIO_BRIDGE_ENABLED := true`,
   and leave the shipped configuration exactly as it was.
4. Write the verdict into this file under `## Spike Verdict` when moving it
   to docs/todone: **keep bridge** (native path still broken or
   browser-support cost too high) or **retirement viable** (native works;
   include the browser matrix and what mastering parity would require). If
   retirement is viable, author a new prompt in `docs/todo/` for it; do not
   retire anything in this task.

## Verification gates (run at the end, not iteratively)

1. `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`
2. `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 900`
   plus any foundation check you had to update for the telemetry/contract
   renames (grep `mix_contract_snapshot` and `la6_web_audio_bridge_stats` in
   scripts/tests/foundation_check.gd first so you know what is asserted).
3. `powershell -ExecutionPolicy Bypass -File tools\web_perf_smoke.ps1` — the
   LD.1/LD.2 budgets must still pass; compare the bridge call/byte telemetry
   before and after Task A and record the delta as evidence.
4. Match existing code style: tab indentation, typed GDScript, sparse
   comments stating constraints only.
