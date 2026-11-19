# CRT mouse and scanline focused qualification

Task: BTH061-CRT-MOUSE-SCAN-001. Candidate base: `0b60c9e61eacdf914224c9f98d12e7aa8fb84588`, tree `ae3228e8e7c697d6151480af36de9c018f37b816`. Focused qualification is complete; commit and NEXT delivery remain pending at this checkpoint. Existing Baccarat, D5 and other ledger work is preserved.

The exact 13,781-byte preparation patch has SHA-256 `ddb9cc9119798cbb5585fce274dd8970d29ba96688c4ff0096be71f1e08a5b5f`. Only its two product files are replayed. The real-mouse hover path queries the SubViewport's actual GUI owner after the existing inverse glass transform, selects before focus and deduplicates unchanged selections. The shader adds luminance-only scan drift and a broad low-contrast rolling band; it does not change hit geometry. Existing seed controls, practice Leave settlement, accepted chiptune, movement and confirmation cues, and volume routing remain unchanged.

| Product file | Qualified SHA-256 |
| --- | --- |
| scripts/ui/crt_practice_menu.gd | 1672f6c175fe6340c54a5981c0f41daddb257cc4f6f3a53e104f8e338562e904 |
| scripts/ui/crt_practice_screen.gdshader | b5e95ced3edd087b844644ffb909d3eca2f39d206a111a6279ddbf081dc3912d |

## Reused native qualification

`E:/CodexQA/BTH/runs/crtms-native1-20261119/evidence/crt-mouse-scan-native.json`: **66 checks passed**, guard exit 0 and owned processes 0. This is historical qualification on `51dcc3e6183f79eef4663808d02c1e118322d0bf` of the byte-identical scoped product files, rather than a new native pass on the Baccarat base.

The actual headed native flow covered Home TV/Play, silent stationary entry, visible hover and unchanged-ID deduplication, movement within a tile after keyboard selection, mouse seed/Setup/Done, paid Scratch Ticket play, real mouse Leave, retained seed and silent restored focus, re-hover and Exit TV to Home. Separate compact keyboard, controller and touch checks passed; touch did not substitute for mouse Leave. Actual cue counts were 9 movement cues and 2 accepted launches.

Actual final-glass photometry ran over nine seconds at source heights 0.245 and 0.69 with pointer and selection stationary. Measured rolling contrasts were 3.6028% and 3.4123%, with expected-roll correlations 0.996241 and 0.997926. Reduce Motion produced zero contrast at both heights and bit-identical glass frames over nine seconds. Ignored QA-only gray reference swatches sampled the compiled shader and were removed afterward. These measurements establish the moving band at two heights; they are not a generic frame difference that old jitter could satisfy. The tested native test source is SHA-256 `62a9e501a32460c1fc081d4951fc6111d679fed7c4b446ebd365e530423f656b`; the later unrun demodulation variant remains separate and is not claimed as tested.

## Fresh Web qualification

`E:/CodexQA/BTH/runs/crtms-web2-20261119/evidence/result.json`: focused fresh guarded Web run passed and closed with **exit 0 / owned processes 0**. The parent reviewed the actual screenshots and input trace. All flow actions used genuine mouse input; no touch or direct game-state/back-method substitute was used.

| Stage | Actual observed boundary |
| --- | --- |
| 1 `home-tv-crt-entry` | One combined captured boundary records the real Home TV, Play and CRT entry mouse sequence. |
| 2 `mouse-hover-pull-tabs` | Pull Tabs has the visible yellow selector; accepted movement cue count 1. |
| 3 `mouse-seed-and-setup` | Seed reads `CRT-MOUSE-WEB-061`; mouse-operated Setup modal is visible. |
| 4 `mouse-launch-scratch` | Scratch Ticket gameplay opens through mouse launch; movement count 2 and accepted select count 1. |
| 5 `mouse-leave-to-crt` | Real mouse Leave returns to CRT with seed retained and cue counts unchanged. |
| 6 `mouse-rehover-baccarat` | Hover selects Baccarat; movement count 3 and accepted select remains 1. |
| 7 `mouse-exit-tv-home` | Mouse Exit TV restores actual HOUSE, clock 12 and cash 52. |

The raw Web observer reports transport/startup/gesture success; the screenshot and action review establishes the mouse-flow acceptance. It does not claim native Godot hit-owner introspection, audible capture or a new audio-loop proof. Per the narrowed handoff, this successful real Web route plus the already proven band and Reduce Motion evidence is sufficient; no broad CRT regression, duplicate animation pass, audio proof or new video was run.

## Retained prior interruption and delivery boundary

The prior `crtms-web1-20261119` reached ordinary House -> TV -> Play -> CRT with zero accepted move/select calls. The subsequent hover/seed command submission returned `aborted by user after 2.1s`; neither command executed. Its controller left no final result and an incomplete guard receipt. It remains an interrupted input submission, not a reproduced product Leave failure or a completed Web pass. Cleanup and read-only process reconciliation observed no task-owned controller, Node worker or Chromium. That receipt is retained unchanged; the successful fresh run above has independent guarded custody.

Commit/push and exact served NEXT identity are pending at this report's creation. Use the ordinary reviewed main-to-NEXT workflow and exact-input cold-import request for the changed shader, preserving the earlier evidence and the existing watcher. No protected profiles, save-code change, manual ledger reconciliation, TEST/stable/tag/audience change, guard/cap/trust change or unrelated art is included. Record the final commit and served receipt in the delivery handoff after they occur.
