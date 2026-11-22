# Visible upward CRT scanline sweeps

Task: BTH061-CRT-SCAN-UP-001, a bounded follow-up to BTH061-CRT-MOUSE-SCAN-001. Fresh authenticated main base: `2e8f337a1fd467087e962457519bcffef27c0422`. Product commit: `1c778496e1fc9097af5b7d368def6f16354cba7b`.

The previous continuous downward roll was only3.5% dark. This changes only CRT luminance: clearer stationary lines with output-pixel-aware spacing, plus an uneven dark band containing several pronounced lines. The band crosses bottom to top over3.4seconds on each visible entry, then remains off for5.6seconds. It moves entirely beyond the glass before the quiet interval. Reduce Motion keeps stationary texture and disables the band. Curvature, UV displacement/input inversion, scheduling, mouse ownership, title/room/game behavior, assets and audio are unchanged.

Erik's references are [The Slow Mo Guys CRT footage](https://www.youtube.com/watch?v=3BJU2drrtCM&t=65s) and the [first-hand upward camera-roll example](https://reduser.net/threads/crt-tv-filming-motion-issue.3831872/#post-3831872). Direct footage/page access was unavailable in this tool session. An accessible [first-hand cinematography discussion](https://cinematography.com/topic/103542-syncing-multiple-crt-tvs-for-a-film-shoot-%E2%80%94-how-to-avoid-flicker/) explains the raster/phosphor behavior separately from dark camera-shutter bands and links the same footage. The rolling band is a deliberate visual interpretation of that camera-like appearance, not lost vertical hold or whole-image motion.

## Focused actual evidence

One fresh guarded D-only native job, `crt-scan-up-visual-20261122-01`, imported the exact source and rendered the real title Games button route. It captured stationary-pointer lower/middle/upper pass frames and a quiet frame, then sent ordinary mouse motion through the production inverse glass transform to Pull Tabs and Blackjack. Both real GUI hit owners and selected IDs matched, exactly two semantic selection events occurred, and hover did not launch. No broad gameplay, Save, audio or Web rerun was performed.

Actual pass-versus-quiet central-glass photometry:

| Entry time | Dark-band centroid Y | Mean darkening near centroid | Maximum row darkening |
| --- | --- | --- | --- |
|0.914s|533.5px|21.8%|39.7%|
|1.712s|352.2px|23.1%|41.5%|
|2.571s|157.5px|20.1%|34.8%|
|4.628s|Quiet: strength0, position-0.18|Band absent|Band absent|

The actual frames were visually inspected: horizontal lines/band are visible, menu text is readable, and the effect remains within curved glass. The compact PNG is actually640x360 under existing native canvas scaling; this is compact readability evidence, not a640x720 mobile/Web layout qualification. Reduced Motion reached the real shader and yielded roll strength0 and zero jitter in two retained frames; these samples were taken during the quiet portion, so they do not independently prove a full would-be active pass under Reduce Motion. The source and shader each explicitly suppress it.

Exact tested product file SHA-256:

- `scripts/ui/crt_practice_menu.gd`: `48cccdccdff74821232b7ac47a7f727840d08e206edb2070195dfccd6cfb40d7`
- `scripts/ui/crt_practice_screen.gdshader`: `add8d94ff7c0b1519765588546602946c0bb1691993392f5850db30ebd99820f`

Native PNGs/proof/logs: `D:/CodexQA/BTH/runs/crt-scan-up-visual-20261122-01/evidence/`. Key frames: `01-sweep-lower.png`, `02-sweep-middle.png`, `03-sweep-upper.png`, `04-quiet.png`, `06-mouse-blackjack.png`, `07-small-actual-size.png`. Private launcher, probe, photometry and terminal receipt: `C:/Users/theep/Documents/Codex/2026-11-18/task/crt-scan-up-qa-20261122/`.

Job exit0, no timeout/errors/cleanup errors, active-at-release0. Maintained guard:10% aggregate CPU,2GiB Job memory,4GiB expected writes plus20GiB reserve, assignment-before-execution. No E access. No owned process remains. `git diff --check` passed; existing ledger JSON parsed. The user-operated ledger reconciliation command was not run.

## NEXT boundary

Trusted TLS readback still resolves the ordinary LAN NEXT URL to immutable `2e8f337a1fd467087e962457519bcffef27c0422`, HTTP200. Existing watcher status is stopped. The playable build and old immutable fallback remain intact.

The current isolated adapter/wrapper/transport are exact-pinned to2e8 and its bundle/tree/native proof; the promotion intake also pins the older80b baseline. They do not admit a new descendant through an ordinary CLI. A reviewed descendant-specific profile must bind the new main commit/tree and complete source input, re-prove unchanged donor/native/toolchain/ABI/exporter equality, and bind promotion to current2e8 fallback. Prior input/claims/provenance must remain unchanged. No export, promotion, watcher restart, hub change, TEST or stable action was attempted for this polish. Native qualification does not claim the changed effect is already on NEXT.
