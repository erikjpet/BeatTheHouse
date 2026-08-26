# balance06_1 archived evidence

This directory carries the small, reviewable subset of the 65 files that
existed under `.tmp/balance06_1/` at handoff. `SHA256SUMS.txt` preserves hashes
for the complete source set; the README and checksum manifest are not part of
that 65-file source set.

The clean landing deliberately omits the three large raw measurement JSONs
(`determinism_first.json`, `cross_economy_audit_repeat.json`, and
`smoke_retry2.json`). They are supersedable `n=1` point samples totaling roughly
3.5 MB. Exact copies remain at immutable source head
`1c0dec3b1e091939cccc8295b9a218be2aa42b96` and in the retained source
worktree's ignored `.tmp/balance06_1/` directory; their hashes remain below.
Four ignored Godot log files named in the source manifest were likewise never
tracked by the source commit. The landing retains 58 smaller source artifacts,
including the diagnostic stderr and validation summaries. Nothing was
re-derived or deleted for this disposition.

`SHA256SUMS.txt` hashes the precommit `.tmp` bytes, not Git blobs. The immutable
source commit's checkout reproduces 50 of the 58 retained validation-file hashes
directly. Git text normalization changed the checkout byte streams of these
eight JSON files when the source archive was committed:

- `validation/foundation_contracts_1/gdscript_load_check.json`
- `validation/foundation_systems_retry1/gdscript_load_check.json`
- the four `foundation_systems.systems_*.json` shard reports
- the `systems_events_saves` and `systems_world_release`
  `profile_inventory.json` files

The clean landing preserves those source Git blobs exactly rather than
re-deriving or rewriting evidence to make their checkout hashes match. The
manifest continues to identify the retained raw originals in the source
worktree's `.tmp` directory.

The artifacts were produced from tracked base
`3d4a41da0b2caf72324c29bcc2a3a8b9314ce3ea` plus the exact two untracked harness
scripts later committed unchanged as
`e74a57cebbda198cda9c1a95ada1c2081f1bb7c6`. Their embedded build labels are
retained verbatim and must not be rewritten as postcommit measurements.

## Measurement artifacts

The source-provenance artifacts `measurements/determinism_first.json` and
`measurements/cross_economy_audit_repeat.json` were produced by:

```powershell
$env:GODOT_BIN = 'D:\Projects\Beat-The-House\.tools\godot-4.6-stable\Godot_v4.6-stable_win64_console.exe'
powershell -NoProfile -ExecutionPolicy Bypass -File tools/cross_economy_audit.ps1 -SeedsPerPlaystyle 1 -MaxActions 208 -SeedPrefix BALANCE06-1-DETERMINISM -BuildRef WORKTREE-PRECOMMIT -Output res://.tmp/balance06_1/determinism_first.json -VerifyDeterminism
```

The wrapper automatically wrote the repeat artifact. Both files are 1,546,805
bytes and have the same SHA-256,
`f7cf3730922226710244dc49e985a98aaa8d5824f24f78d4b6851252d3cec897`.
They contain one 208-action, right-censored run for each of eight playstyles.

The source-provenance artifact `measurements/smoke_retry2.json` was produced by:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/cross_economy_audit.ps1 -SeedsPerPlaystyle 1 -MaxActions 8 -SeedPrefix BALANCE06-1-SMOKE -BuildRef STATIC-SMOKE -Output res://.tmp/balance06_1/smoke_retry2.json
```

It contains one eight-action smoke row for each playstyle. It is not a balance
distribution.

## Validation artifacts

The archived systems configuration is reproducible with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/check_godot.ps1 -Suite Smoke -FoundationSuite systems -ReportDir .tmp/balance06_1/foundation_systems_retry1
```

`validation/foundation_systems_retry1/summary.json` records a passing 41.382s
four-shard systems stage. It also records the exact resolved validation, import,
and script-load child commands, exit codes, and durations. Per-shard JSON,
stdout, stderr, Godot logs, and isolated user data are preserved beside it.

The archived contracts configuration is reproducible with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/check_godot.ps1 -Suite Smoke -FoundationSuite contracts -ReportDir .tmp/balance06_1/foundation_contracts_1
```

This run is **not a pass**. `summary.json` records a 300.047s timeout. Its stderr
isolates an unrelated existing defect: `BlackjackGame._draw_count_challenge`
calls missing `surface_add_exact_hover_hit` on the `SurfaceHarness` test double.
The stack points to `scripts/games/blackjack.gd:2939`; the missing test-double
method belongs at `scripts/tests/foundation/check_core_content.gd:139`. Ownership
is `fix06_4` on `codex/cross-remediation`. This branch did not patch or rerun it.

The top-level interactive shell command line itself was not separately logged;
the commands above express the exact suite, report directory, and wrapper
configuration embedded in each summary. The summaries are the authority for
resolved child argv and timing.

## Not present

No 64-seed-per-playstyle audit, historical 0.5 numeric distribution, 600k-drop
coin-pusher EV result, or evidence-backed findings/proposals were produced.
Those requirements remain not started.
