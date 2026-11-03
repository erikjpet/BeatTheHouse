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
