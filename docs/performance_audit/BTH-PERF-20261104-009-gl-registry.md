# BTH-PERF-20261104-009: Web GL registry accumulation

Owner: performance audit. Parent objective **BTH-PERF-20261104 remains OPEN**. This batch implements and measures the four confirmed hot GL namespaces; main/NEXT release follow-through remains open.

During ordinary Coin Pusher play, the pinned generated Emscripten GL allocator advanced one global counter and padded each resource table. Deletion cleared entries without reusing their IDs. Real idle and moving-input runs retained growing arrays of unused slots.

The Web export now replaces the exact original allocator/deletion definitions before WASM imports bind. Buffers, textures, VAOs and syncs reuse only their own previously issued, deleted IDs. New peaks and other namespaces retain the original global allocator. Bounded ownership/free sets prevent duplicate reuse; bookkeeping faults disable recycling and qualification rejects any fault or fallback. Original delete side effects, PBO binding resets, error paths, program/shader namespace and uniform mappings are preserved.

Fresh owned exports archive original JS outside the packaged stage and create a deterministic public receipt. Exact JS, engine WASM, Godot/Emscripten/template, source-policy and build-profile pins fail closed. SkipExport, registered immutable reuse and packaging reverify the current policy. Windows returns before Node/tool resolution. Global templates, native binaries, game scheduling, saves, layout, touch and focus code are unchanged.

## Measured current-main Web comparison

Source `f876fe41cb8df993d79de4cd02b21f34b7c21dbf`, tree `774ae99a05202e81b91ee59b0972685077bd0823`. Main was still this head at 12:50 UTC on 2026-11-04. Each fresh actual Library Quarter Falls PRACTICE cabinet opened with 153 bodies, aged naturally 120 seconds, then received six normal paid drops and six 10-second matched held-input segments. One run per cell; 12% aggregate CPU and 2 GiB owned Job; fixed 1280 x 720. The PCK and all WASM, HTML, audio and images were byte-identical. Only candidate JS and its receipt differed.

| Input | Original hot slots after teardown | Patched hot slots | Original post-GC JS heap | Patched post-GC JS heap |
|---|---:|---:|---:|---:|
| Stationary, fed | 749,313 | 7,716 | 21.936 MB | 18.262 MB |
| Moving nozzle, fed | 1,596,133 | 7,716 | 27.153 MB | 18.338 MB |

All four gameplay runs completed, accepted all 24 paid drops, preserved conservation, showed physics/presentation/carriage progression, exited normally, released live machines, and preserved the task primary save hash before/after/independent cleanup. Candidate tables stayed flat from entry through both 120-second age and 60-second input phases, with zero allocator faults/fallbacks. Their size rose only for the normal return-to-menu peak.

Requested 60 Hz mouse motion produced 57.73â€“58.66 Hz trusted DOM delivery in the original and 58.30â€“59.43 Hz in the candidate. This does not establish strict 60 Hz backend acceptance. Overall fed-play authority was 47.63 versus 47.61 ticks/s stationary and 47.70 versus 47.66 moving. No physics scheduling improvement is claimed. The unscaled Web 48 Hz/144 drawn frames/s backlog remains 001/005 and needs separate work.

WASM capacity stayed 379,781,120 bytes. Warm logical PCM cache was one 2,646,000-byte entry. Renderer logical allocation counters were recorded; they varied and do not establish physical VRAM or driver-memory clearance. Whole-Job identity-checked memory recorded 781 complete samples; process totals are not game-only memory or endpoint leak slopes. Original moving-input stress/teardown scans exceeded the 262,144-slot/table cap: exact lengths remain valid, full live/unused counts are NULL.

## Validation and native coverage

- Fourteen allocator/export-policy Node cases and the PowerShell export contract passed. The gate rejects forged receipts, changed engine assets/source policy and unknown JS fingerprints, and prevents custody/registration after rejection.
- Nine real WebGL cases passed for both original and candidate through 39 captured production WASM import forwarders, including core/prefixed/OES aliases, resource reuse, PBO resets, FBO readback, VAOs, fences, shared shader/program names and uniforms. Context-loss/multiple-context coverage remains open.
- Current-main cold import, parser canary, required no-pointer animation liveness, all 1,172 PCK body MD 5 s, UID/source mappings, exact embedded identity and outside-owner restoration passed.
- Actual native source/debug NVIDIA 4070 Ti/OpenGL 3.3 gameplay passed both stationary and held-input 120-second age+six 10-second segments, with six paid drops per arm, `native_v3` stepping, conservation, changing native body presentation and normal teardown. Fed-play authority stayed 59.86â€“60.08 ticks/s. Held input delivered 3,575 synthetic application mouse events at 59.47â€“59.58 Hz.
- Native private HDESK/window/PID/TID identity and cleanup passed (192/193 positive samples), input desktop stayed unchanged, worker never took foreground focus, and fresh task-profile primary/backup remained absent after process exit. This is actual GPU gameplay using `Input.parse_input_event`, not OS-input qualification. Dummy audio, source/debug runtime and historically qualified DLL reuse are explicit limits; Windows release, real audio and loaded campaign-save qualification remain open.

Failed validation attempts are retained: the first cold-import UID guard rejected the legitimate pinned extension UID; one Web launch aborted a PCK request before boot; one six-poll readiness sequence missed current publication; one native probe incorrectly hashed the empty packed array despite a populated body array. Corrected attempts used new labels and kept the equality/scan/Job/save/desktop gates. No failed whole attempt was relabeled as a pass.

## Reproduction and evidence

Run `node --test tools/web_gl_handles.test.mjs` with `BTH_WEB_GL_ENGINE_FIXTURE` pointing to the exact original 8 cf 4 engine JS beside its matching engine WASM files and `BTH_WEB_GL_TEST_ROOT` pointing to a fresh owned fixture directory. Run `powershell -NoProfile -File tools/web_gl_handles_export_contract_test.ps1` and the repository-required `godot --headless --path . --script res://scripts/tests/animation_liveness_without_pointer_check.gd`. Tests retain fixtures.

Engine JS input SHA `8cf4a21cded9270718a67c6f1aab3d794eca91e3903ad866532c925565dd1fc4`; patched SHA `0c8aacc2bab394c10845a65d3b6624df7f4678a1aea87f80612a554b28d04c8c`. Private comparison PCK SHA `5820e7f53210b1643d33227af08d670d06abad9333a30bbcf69762dab7bac8e2` is diagnostic and must not be deployed.

Retained evidence root: `E:/CodexTaskStorage/BTH-PERF-20261104-task18-01/audit-009-mitigation-r1`. Web comparison `aged-web-comparison-r1.json` SHA `6a69b9e319eedbe3adf0317b77413096cd7dcdd84053755b76b3216f70533549`; native comparison `native-runtime-comparison-r1.json` SHA `eac2e44b29d780cec56c48981482eb97bf7d704ff427c7f7326d4a81c51cd907`. Both enumerate raw owner/report/log pins and scope.

## Release and remaining audit work

This is a tested local batch. No external publication, merge or deployment was attempted. Keep 009 release-open until the tested commit is integrated through the authorized main-to-NEXT process and the deployed source, receipt and served patched-JS bytes are verified. The external watcher consumer must enforce receipt/output identity; a PCK/source-head match alone cannot prove this mitigation.

The full-game audit remains open:001/005 Web authority cadence/aged and strict-input coverage;006 broader memory/other games/ordinary campaign/native release;008 intermittent menu text. Items 002 and 004 remain paused. PR 30 merge and 007 publication denials remain untouched.
