# Back Alley cutscene defects

Owner report: "Nighttime text to the back alley yielded a frozen cutscene issue with unexpected text on the bottom. Also in back alley cutscenes the players head clips the overhang of the alley"

Task: BTH-TRAVEL-BACK-ALLEY-002. Base source: 49594c29c42803f60e89f84c226801f5995910cb.

No original save or screenshot was provided. Source investigation finds that a triggered route incident produces a static receipt with frozen scenery, bottom summary and manual Continue. This matches the symptom shape but does not establish the exact personal incident. Back Alley uses the generic outdoor walk-away scale without fitting its low passage.

Plan: preserve committed receipts and incident consequences; auto-complete fresh non-reduced fallback presentations without a one-frame receipt footer. Keep explicit recovery and reduced-motion summaries manual. Fit alley depth continuously to measured passage clearance. No art changes, new incidents, route changes or gameplay settlement changes.

## Fix and behavior

Fresh non-reduced travel fallbacks now acknowledge once outside the input/draw callback and reveal the already-prepared destination. No misleading receipt footer flashes at the end of an ordinary animation. An incident remains a truthful static fallback, not a fabricated uneventful scene. Its full incident explanation, label, fare, loss and Heat consequences remain in the persistent, dismissible destination Result panel and journal. No consequence is applied again. Explicit recovery, reduced-motion and legacy text-only summaries still wait for Continue.

The alley contract supplies measured low-passage clearance. Its approach now uses the existing continuous dock-style depth mechanism, reaching scale 0.4215 at the far point, instead of keeping full adult height until the overhang and only then receding to the generic 0.58 scale. The actual canonical avatar and original art bytes are unchanged.

## Evidence

- Base source 49594c29; normal assets imported with pinned Godot 4.6. Exact-source native Windows DLL SHA256 4cdeadde615a8ee0039b120553d8d3c9029260c947c97c6072f9beaeb906ee71 was reused after verifying unchanged native source inputs.
- Accurate original-source 27-check overlay reproduction fails fresh fallback completion and all four measured-clearance cases. The first cached-asset setup attempt lacked textures; that harness failure is retained separately and was followed by a normal import, not attributed to the product.
- Real menu transaction from generated BACK-ALLEY-NIGHT-1 apartment state with explicit synthetic clock 1300 naturally chooses an enabled taxi route to Back Alley and triggers its own 41% shakedown roll 25. No graph, fare, mode, risk chance or RNG override. Original source fails automatic arrival, acknowledgment and full incident narrative checks. Fixed graphical host passes 9 checks: cash/clock/RNG and travel-log count stay unchanged after the already-settled trip, receipt acknowledges once and the actual persistent Result panel contains the full message. Normal startup advice was dismissed through its actual Skip tip button before pixel inspection.
- Fixed graphical overlay 27 checks cover maximum-size capped avatars across walk, bus, taxi and night cab;801 samples per mode keep even the conservative full-avatar bound below the measured ceiling. Native rendered entry frames were inspected. Reduction, replacement, cancellation and recovered-summary cases pass.
- Existing standard overlay, cinematic overlay 1115, destination preparation 152 and no-pointer liveness checks pass in capped isolated Jobs. The initial existing lifecycle assertion requiring fresh fallbacks to stay manual was updated for the requested corrected behavior; manual reduced/recovery/legacy coverage is retained.
- Independent scoped static review found no actionable issues. No full suite, personal-save or browser/WASM gameplay claim. Every owned Job has a nonce-bound zero-remaining closure receipt; failed pre-fix and setup evidence is preserved.

Detailed commands, logs, PNGs and guard receipts remain in the named E:/CodexQA/BTH/runs/back-alley-* evidence directories. The compact committed receipt lists exact passing Job hashes.

Status: scoped fix complete; native graphical behavior and exact NEXT delivery verified. Existing stable/itch, audience, user saves, dirty developer checkout and audit worker remain unchanged.

Scoped fix commit: 791af903b74fca270e44f4c6aa527e080d39215a. Rebased onto documentation-only main ed0f945a0e3aca11f9cc2e99b92a82266a983696; all tested runtime, data and asset bytes remain identical. Required reconciliation is run with the actual active task and owned-zero Job snapshots; unrelated global backlog findings remain outside this fix.

Manual reconciliation (back-alley-ledger-verified-20261112) reports zero findings for BTH-TRAVEL-BACK-ALLEY-002 and 93 unrelated current/global findings. Cleanup contracts were verified by source review of the maintained supervisor and kill-on-close Job; successful and failing test Job closures were observed. No new timeout/interruption fault-injection run is claimed.

## Exact NEXT delivery

The existing watcher promoted main 37c11a33d36a4352fc3faef7114bb22842cc7420 at 2026-11-12 17:34:11 UTC after its ordinary exact-input cold import, native Web build, export and PCK audit. This uses tree 176001ee7a1f82e3f9fd0f4aca38e8ceb19145fe, version 0.6.0-dev+37c11a33d36a and archive SHA256 f1ff607d7164b60e91f46e7329a02e5c7c5dc0e93e387759c0b70f1391f347ca.

At 17:34:23 UTC, the real NEXT entry redirected to that immutable directory. Served next.json, next-status.json, BUILD.json, build_manifest.json, REF and VERSION agree. Six HTML/JS/engine/PCK/native assets return HTTP 200 with matching installed lengths and correct WASM MIME; current engine/native hashes match the exact-build manifests. The served 124,979,752-byte PCK hashes to 684493124fa02b91ec5d5501848b090c40acbb19bbfb97069ec670ba6b94e984, identical to the promoted installed package. The guarded verifier exits 0 with zero owned processes. GitHub reports no check runs or status contexts for this commit; no CI-green claim is made.

Browser/WASM startup and changed-behavior playback remain unverified. HTTP/package identity and native graphical play are separate evidence classes. Stable, itch, audience, original state, the dirty checkout and other owners remain unchanged. Any subsequent documentation-only ledger commit preserves these tested runtime bytes and this explicit delivery receipt; it does not manufacture a new browser qualification.
