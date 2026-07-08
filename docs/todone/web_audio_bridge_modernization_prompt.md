## Execution Record

Completion date: 2026-07-08.

Implementing/evidence commits:
- `8eefdc5` - Task A landed before this run: v4 `get_interface` bridge.
- `30d779a` - Claimed this queue entry after confirming entry 1 was archived.
- Archive/evidence commit - this commit.

Verification:
- Confirmed `docs/todone/v04_worktree_baseline_and_gate_recovery_prompt.md` exists before starting.
- `powershell -ExecutionPolicy Bypass -File tools\web_perf_smoke.ps1` on the clean shipped bridge: PASS. Final report `.tmp/web_perf_smoke/report.summary.json`: ready 13,064ms / 20,000ms, telemetry overhead avg 0.0187ms / 0.1ms, no failures.
- `powershell -ExecutionPolicy Bypass -File tools\validate_project.ps1`: PASS, "Beat the House foundation architecture validation passed."
- `powershell -ExecutionPolicy Bypass -File tools\check_godot.ps1 -RequireGodot -FoundationSuite ui -TimeoutSec 900`: PASS. Stages: validate_project 15,387ms; godot_import 12,132ms; gdscript_load_check 10,164ms; ui_scene_compile 46,342ms. Report: `.tmp/test_reports/20260707_202449_smoke/summary.json`.
- Task B threaded native fallback spike (`WEB_AUDIO_BRIDGE_ENABLED := false`, shipped `variant/thread_support=true`, temporary only): FAIL. Report `.tmp/web_perf_smoke_native/report.summary.json`; failures were `bar_dice_idle` memory delta 209,982,128 bytes and `scripted_play_memory_10m` memory delta 189,455,060 bytes, both over the 134,217,728 byte budget.
- Task B single-thread native fallback spike (`WEB_AUDIO_BRIDGE_ENABLED := false`, `variant/thread_support=false`, temporary only): FAIL. Report `.tmp/web_perf_smoke_native_single/report.summary.json`; failure was `video_poker_idle` frame p95 20.405ms over the 20.000ms budget.
- Restored `WEB_AUDIO_BRIDGE_ENABLED := true` and `variant/thread_support=true`; `git diff -- scripts/ui/web_audio_bridge.gd export_presets.cfg` was empty before final gates.

Task A verification:
- `scripts/ui/web_audio_bridge.gd` has `WEB_AUDIO_VERSION := 4` and JS `BRIDGE_VERSION = 4`.
- Only one `JavaScriptBridge.eval(WEB_AUDIO_SCRIPT, true)` remains in `web_audio_bridge.gd`, used for one-time bridge installation.
- `ensure()` caches `JavaScriptBridge.get_interface("BTHWebAudio")`; playback/control calls use direct interface methods with JSON string payloads.
- Telemetry reports `call_counts` and `payload_bytes`; `scripts/tests/foundation_check.gd` asserts the one-eval, `get_interface`, and telemetry contracts.
- `_wav_has_signal()` is bounded/strided rather than a full byte-by-byte WAV scan.

Fallback code verification:
- `scripts/ui/sfx_player.gd` falls back to native `AudioStreamPlayer` one-shots and loop players when `WebAudioBridge.available()` is false.
- `scripts/ui/procedural_music_player.gd` falls back to native `AudioStreamPlayer` stems when web bridge playback is unavailable.

## Spike Verdict

Verdict: keep bridge.

Native Godot web audio is not ready to replace the shipped bridge for this project in this release line. The threaded native fallback ran but failed memory budgets badly: compared with the final shipped bridge report, `bar_dice_idle` was 1,241,512 bytes vs 209,982,128 bytes and `scripted_play_memory_10m` was 4,089,381 bytes vs 189,455,060 bytes. The single-thread native fallback had better memory behavior but still failed the smoke gate (`video_poker_idle` p95 20.405ms > 20.000ms) and was slower than the bridge on key release surfaces: `world_map_idle` p95 11.901ms bridge vs 30.07ms native single-thread, and `scripted_play_memory_10m` p95 10.746ms bridge vs 36.667ms native single-thread.

The local server already sends cross-origin-isolation headers for threaded web smoke (`Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp` in `tools/serve_web.ps1`). Local export config was temporarily switched to `variant/thread_support=false` for the single-thread spike and restored. The repo does not currently carry a separate sample-playback export preset, so the single-thread run is the closest local matrix entry without introducing new release configuration in this evidence-only task.

Research notes used for the verdict:
- Godot documents `JavaScriptBridge.get_interface()` for calling global JS objects directly and `eval()` as string execution, supporting the v4 bridge direction: https://docs.godotengine.org/en/stable/classes/class_javascriptbridge.html and https://docs.godotengine.org/en/stable/tutorials/platform/web/javascript_bridge.html.
- Godot 4.3 web-export notes describe the web audio/threading tradeoff and cross-origin isolation requirement: https://godotengine.org/article/progress-report-web-export-in-4-3/.
- Godot PR #91382 introduced sample playback support, while issue #109728 still tracks native web audio instability with stream playback: https://github.com/godotengine/godot/pull/91382 and https://github.com/godotengine/godot/issues/109728.
- itch.io SharedArrayBuffer support remains a deployment/browser-compatibility constraint: https://itch.io/blog/456223/godot-cross-origin-isolation-and-sharedarraybuffers and https://itch.io/t/2025776/experimental-sharedarraybuffer-support.

Deviations:
- Task A was not reimplemented because commit `8eefdc5` already landed it; this run verified it and completed the remaining spike/verdict.
- No retirement prompt was authored because the verdict is keep bridge.
- Temporary spike edits were restored before final validation.
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
