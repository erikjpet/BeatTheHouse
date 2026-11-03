# BTH061-HUD-001: fixed run information banner

Owner report: variable information grew the top banner, moved the active item
to a second row and reduced the environment. No original player save or browser
capture was supplied. Reproduction and worst-case checks use disposable,
synthetic presentation models; no original profile/save is accessed.

Implementation: `60d8855191bc204a38ac390c1b8af2656f087aca`, integrated on
`c6fef9b0` main. The normal 1280x720 viewport now keeps its 72px information
band independent of content. The primary row is nonwrapping; active-item art
is bounded to 24px. Values have bounded columns, with exact values, every
status and clock explanation available from the touch/focus-accessible Info
or clock panel. Package timing and street actions use the existing scrollable
choice popup. Money feedback is outside row measurement and leaves the current
balance readable, including large-text mode. Its authoritative event delivery,
chip icon and accumulation are preserved. No economy, RNG, save, placement,
viewport or canvas animation policy changes are included.

## Reproduction and checks

Evidence root: `C:/Users/theep/Documents/Codex/2026-11-03/task-12/evidence/`.
Pinned Godot: `4.6.stable.official.89cea1439`. Each owned native job has a 5%
CPU cap, 2GiB aggregate memory cap, explicit deadline, private storage and
kill-on-close containment. Passing job receipts record exit0 and active0.

- Current-main rendered row reproduction uses the production HUD plus the
  original row/margin/height rules from `8d3c5275`: normal72px becomes150px,
  with the active item moving below Menu. See `current-main-row-parity-repro.log`.
  This is a source-based UI fixture, not a captured player route.
- `hud_banner_fixed_layout_check.gd`: **808 checks pass**, four rendered
  production-shell cases (1280x720 and1920x1080, ordinary and maximum
  text/touch settings). Typical and worst-case values, chips,12 statuses,
  pending alcohol, Heat gain, simultaneous money feedback, item icon, clock
  details,6 package actions, missed-delivery receipt and home mode all retain
  the same banner/play rectangles. Checks include full detail text, focus,
  scroll reachability, close/focus restoration, modal input blocking and the
  balance remaining visible under feedback. `release-layout-layout.json`.
- `money_feedback_check.gd`: **46 checks pass**, including event delivery,
  accumulation, transfers, replay suppression, home gold, reduced motion and
  sound behavior. `release-money-feedback.log`.
- `ui05_design_system_check.gd`: **PASS**, including the clock disclosure and
  authoritative HUD snapshots. `release-hud-design.log`.
- `environment_06_input_contract_check.gd`: **251 checks pass**. Fixed1280x720
  logical framing and ordinary mouse/touch/key routing hold at physical375x667,
  390x844,844x390 and1280x720. `release-06-pointer.log`.
- The older `crew_package_windows_check.gd` fixture rejects its favor before
  reaching the HUD: `host could not enqueue favor` / `Event is no longer
  available` in generated `apartment_001`. No package was accepted. Its HUD
  assertions have been adapted to the disclosure; the gameplay-window run is
  **not qualified**. The changed UI is independently covered by the808 checks.
  `release-package-windows.log` preserves the failed attempt.
  Its enclosing terminal session ended without a final owned-job receipt;
  no completion/closure claim is made for that attempt. Other passing checks
  have their own explicit exit0/active0 receipts.

Commands use `run_owned.py <label> <pinned-Godot> --headless --path . --script
res://scripts/tests/<named-check>.gd`. Native logs retain the sandbox host's
root-certificate-store warning; it is not a passing TLS/network check.

## NEXT

Local integration `b31b323d15b0e04f8d4aaed50f48514ca13abba2`, tree
`29f353e8da70b26bd6907a15c986f25a8bdb1752`, includes concurrent main fixes
through `29931ab9`. The exact merged source passes the808 layout checks again
(`merged-main-layout.log`, exit0, active0). Other passing receipts above retain
their original source60d88551 scope; they are not relabeled as new-build runs.

Main publication succeeded at `e641f0c81af36c399d5fea5c1504963455f63cc2`, tree
`2e44862d148cf92ba256aa50daf23e5dd732b71e`. The existing watcher observed it,
built it at22:31:08UTC and promoted it at22:31:13UTC on2026-11-03.
Served NEXT metadata, redirect, REF and VERSION select that exact SHA and
`0.6.0-dev+e641f0c81af3`. Archive SHA256:
`e9c73df7b7f7b9a9e1c571c039c3430f7f5eec73fbff901b34dd79051871249b`.

`next-http.json` verifies ten served files against the actual watcher archive,
including HTML/JS, PCK, engine WASM, engine side module, native Coin Pusher
WASM and metadata. All return200 and match archive SHA256; WASM MIME types are
`application/wasm`. The clean manifest's guarded native source objects equal
the qualified tuple. This is asset/provenance verification, not visual play.
The HTTP check exits0 with owned Job active0. No watcher restart, manual build,
stable/itch publication or audience change was made.

Basic launch and changed-behavior Web acceptance remain **unverified**. The first
isolated browser failed during restricted-account GPU launch, before visiting
the game; its owned Job released with active0. A second fresh-profile desktop
account browser retains the GPU sandbox and the same5%CPU/2GiB/deadline limits;
it fetched the required engine/PCK/native resources with200 responses, but did
not reach startup readiness before its300-second supervisor deadline. Its
GPU sandbox was enabled, page-error list was empty, peak aggregate memory was
1,293,193,216bytes and the owned Job terminated/released with active0.
`next-web-desktop-runtime.json` records timeout=true/exit1; browser state and
logs are retained under `next-web-desktop/`. No screenshots or game actions
were obtained, and no further launch/security relaxation was attempted.
The earlier restricted-account attempt is retained under `next-web/` and
`next-web-runtime.json` (exit1/active0). The timeout is a verification/runtime
blocker, not an attributed product defect. Native layout/pointer checks above
are not relabeled as visual Web gameplay. Keep the task open for exact-build
browser startup and deployed layout acceptance.

## BTH061-HUD-001-WEB-CANVASLAYER correction

Independent task-10 console review on exacte641f0c8 confirmed a product error:
`CanvasLayer` is disabled by the pinned
`native/coin_pusher/godot_web_release_build_profile.json`. Full native Godot
therefore parsed code that the actual Web engine rejected at HUD line746.
The dependent issue is tracked separately and supersedes a startup-only claim
based on seeing a menu/canvas without reviewing Godot console errors.

Correction `8f330c51c858ac6e82f3e307c6009bf330cfcd81` uses an ordinary Control
beside the run screen, outside the clipped HUD hierarchy. It retains viewport
dimensions, draws above TalkDock, moves to the front for pointer ordering, and
releases its external overlay/focus scope during teardown. No engine/profile
or native toolchain change is required.

`web-profile-control-layout.log`: **893 checks pass**, including the existing
layout cases, out-of-HUD overlay ownership, draw order and a new locked-profile
compatibility check for disabled class references. `web-control-money.log`:
**46 pass**; `web-control-hud-design.log`: **PASS**. All three jobs exit0/active0.
Corrected exact Web deployment, startup-console review and actual HUD acceptance
remain pending until the existing NEXT watcher promotes this correction.

## BTH061-HUD-001-WEB-CANVASLAYER integration repair

Current Web acceptance found a blocker after the native qualification: exact
NEXT `92b97d9a3cbc99c166eab164bb72f8e36c237e7d` logs `CanvasLayer` undeclared
at `foundation_hud_bar.gd:746`, followed by a failed HUD script load and null
`rp_child`. The pinned Web template omits that class. A visible start menu is
insufficient qualification; the original raw smoke flag was rejected because
its recorded console contained those script errors. Preserved evidence is
`task-11/evidence/next-92b97d9a3cbc99c166eab164bb72f8e36c237e7d-startup.json`
and its `-startup-review.json`. The local smoke predicate now rejects console
errors as well as page errors.

The scoped repair replaces the unsupported layer with a top-level `Control`
owned directly by the HUD. It stays outside the clipped fixed-height layout,
covers the logical viewport, follows viewport resizing and retains existing
modal shade, focus, scrolling, visibility and disposal behavior. No game rules,
economy, saves, renderer cadence, native code or toolchain changes are involved.

`hud_banner_fixed_layout_check.gd` now passes **848 checks**, adding actual
production GUI corner clicks, complete backdrop bounds, live viewport resize,
HUD hide and disposal to the prior qualification. The table presentation check
also passes **68 checks** with the repaired overlay. Receipts are
`task-11/evidence/hud-web-overlay-layout-typed.json` and
`terminal-web-overlay-integration.json`, each exit 0, deadline not exceeded and
zero owned processes at release. A test-only type inference parse failure in
the first attempt remains preserved in `hud-web-overlay-layout.log`.
Independent source review found no remaining concrete issue. Exact repaired
Web publication and startup remain pending; this subtask stays open until then.

Repair implementation commit: `2041585d42ae5f9f609d351a7aa0bdd48b1ae094`.
The canonical Web blocker row is associated with this commit and remains open
until strict repaired Web startup qualification.

The combined implementation retains the published204 top-level Control topology and local8f lifetime/profile guards. The external-sibling8f layout variant is historical, not the selected overlay owner. Both original native receipts remain scoped to their respective commits; the combined source is checked separately before publication.

Combined source qualification: `combined-web-control-layout.log` passes **933 checks**, including both owners' geometry, real backdrop corner clicks, resize/hide/disposal and the locked Web profile guard. Receipt exit0/active0. It retains the published top-level ownership plus the local validity/lifetime guards; exact new Web validation follows publication.
