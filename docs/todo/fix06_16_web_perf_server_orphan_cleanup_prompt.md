Status: IN_PROGRESS — rejected heads `239ead2a`, `e92fab10` and `672cdd25` remediated; independent exact-head re-review pending
Board row: `fix06_16` in `docs/todo/README_0_6_board.md`

# Agent Prompt — fix06_16: Web performance server orphan cleanup

Work from exact current `main` after `fix06_14` lands. This row owns only the
Web performance wrapper/server lifecycle defect exposed by the consumed
`fix06_14` qualification. It does not own shipped-Web performance or any
Coin Pusher gameplay/evidence contract.

## Retained reproduction

At exact source `dba07c1a5c675e07cb9a3dc2956889d67086df2a`, the sole fresh
Chrome 151 CPU-4 qualification wrote its complete report and summary, then the
outer orchestration remained alive until 904 seconds. `serve_web.ps1` had left
orphan Python PID 39916 listening on port 18117 after the wrapper's server
process cleanup. The PM stopped only PID 39916 and verified both process and
listener absent. The measurement is immutable and must not be rerun or replaced
for this row.

## Required work

1. Reproduce the process-tree lifecycle defect without consuming a Coin Pusher
   Web timing run.
2. Attribute wrapper, PowerShell child and Python server ownership/termination.
3. Implement the smallest deterministic cleanup that terminates the exact
   launched server tree on success, assertion failure, probe failure and host
   interruption while preserving report/summary output already written.
4. Add hostile lifecycle tests proving no unrelated process/ref can be killed,
   cleanup cannot silently succeed while the owned listener remains, and a
   missing/already-exited child is handled deterministically.
5. Run static validation and focused non-Web lifecycle tests, then obtain
   independent exact-head review before landing.

## Locked boundaries

- Do not alter Web performance caps, fixtures, sample lengths, actions,
  throttling, scenario coverage, evidence schemas or console policy.
- Do not rerun or replace any retained `fix06_14` Web result.
- No gameplay, simulation, RNG, payout, odds, wager, economy, geometry, tuning,
  schema, migration, version, packaging, release or remote change.
- Never terminate by broad process name, wildcard or port alone. Track and
  verify the exact launched process tree and fail closed if ownership cannot be
  established.

Preserve every lifecycle artifact and exact process/port identity. Commit
logically, self-review, obtain independent review, and land before the next
locked `fix06_13` shipped-Web run.

## Implementation record — 2026-08-27

- Exact base: `f0637b8c1dcb4dbc9d979d0f89a1ee811865a90a` on
  `codex/land06-fix06_16` in `D:\bth-f14-int`.
- Bounded non-Web reproduction used the retained existing local export only as
  static server content. Stopping exact wrapper PID 2380 left its direct Python
  child PID 12964 alive and listening on loopback port 64488. The test then
  stopped only those exact PIDs and verified the listener absent. No browser,
  export, Coin Pusher plan or Web timing ran.
- Attribution: the old wrapper retained only the `serve_web.ps1` PowerShell
  handle. That script piped source into Python, so force-stopping the wrapper
  did not terminate or identify the Python listener.
- Remediation: `serve_web.ps1` now explicitly launches the extracted
  isolation-header server, records a nonce-bound wrapper/server PID, UTC start
  identity, direct-parent relation, exact script, root and port atomically, and
  owns its child in `finally`. `web_perf_smoke.ps1` uses the shared lifecycle
  helper to re-read and verify that record, require the exact child to own the
  expected listener, stop child before wrapper on every unwind, and fail if the
  exact PID or its listener remains. Port is verification context only; no
  process is selected or terminated by port, wildcard or broad process name.
- Hostile focused coverage proves success, assertion-failure, probe-failure and
  host-interruption cleanup; deterministic already-exited-child handling;
  unrelated process survival; cached-record tampering cannot redirect cleanup;
  and mocked termination failure reports both the surviving exact process and
  listener. The suite passed twice, most recently in 16.8s. Static foundation
  architecture validation passed in the same invocation (61.9s total).
- Retained test artifacts are under ignored
  `.tmp/fix06_16_lifecycle_test_<nonce>/` paths. The immutable `fix06_14`
  qualification, its report/summary and all earlier evidence remain untouched.
- Locked Web caps, fixtures, samples, actions, throttling, scenarios, schema,
  console policy and product behavior are byte-identical to the exact base.
  No gameplay, RNG, payout, odds, wager, economy, geometry, tuning, migration,
  version, package, release or remote operation occurred.

## Independent rejection and remediation — 2026-08-27

- Independent review rejected exact head
  `239ead2a854ecd46a2ac70fa4f192da4439b6ba2` at P2 because both native
  `Start-Process` boundaries passed unquoted argument arrays. Windows
  PowerShell joins those arrays into a command line, so spaces in the workspace,
  server-script, serve-root or ownership paths could split valid arguments and
  defeat deterministic launch/cleanup. The lifecycle design and locked-scope
  compliance otherwise remained accepted.
- The remediation applies Windows `CommandLineToArgvW`-compatible quoting at
  both boundaries, including empty arguments, embedded quotes and terminal
  backslashes. It does not change server behavior, evidence or cleanup policy.
- The hostile non-Web suite now runs a copied Python executable from `python
  runtime with spaces`, copies the real PowerShell wrapper and Python server
  under `tool scripts with spaces`, serves `served root with spaces`,
  and writes its ownership record plus stdout/stderr under `ownership and logs
  with spaces`. It proves the exact fixture content and both required isolation
  headers, ownership publication, exact process/listener cleanup and unrelated
  process survival. Two intermediate harness attempts failed before launching
  that server: 17.0s exposed an undefined copy-source variable, then 17.2s
  proved the Windows App Execution Alias is intentionally non-copyable. The
  harness now discovers a real installed Python executable deterministically;
  the complete expanded suite passed in 18.6s. All four PowerShell files parsed
  with zero errors and final static validation passed in 48.7s. No browser,
  export or Web timing ran. After escaping wildcard metacharacters in the exact
  server-script command-line matcher, the final combined hostile/static rerun
  passed in 64.9s.

## Expected-shutdown classification rejection and remediation — 2026-08-27

- Independent re-review rejected exact head
  `e92fab108f5c4e7128f2ff9340d064ac6fb40a72` at P2. The outer helper
  intentionally terminated the exact Python child, but `serve_web.ps1` could
  classify that expected cleanup as spontaneous failure and emit `Local Web
  server exited with code .` because no shutdown intent crossed the process
  boundary. Unexpected child failure handling otherwise remained fail-closed.
- Cleanup now publishes the launch nonce atomically to the exact ownership
  record's shutdown path before terminating the verified child. The wrapper
  accepts only that matching nonce as expected shutdown; any child exit without
  it throws an explicit unexpected-exit error, including a concrete exit-code
  identity. Cleanup gives the wrapper five bounded seconds to consume the marker
  and exit normally before exact-PID fallback termination.
- Production-path hostile assertions require success, assertion failure, probe
  failure, host interruption and a shutdown-requested already-exited child to
  leave no lifecycle stderr. The one real HTTP request permits only its exact
  loopback `GET /` 200 access-log line. A separate unrequested child termination
  must put `Local Web server exited unexpectedly with code ...` in wrapper
  stderr. The first expanded assertion run reached all cases but rejected the
  normal HTTP access line in 24.8s; after narrowing that explicit allowance, the
  complete suite passed in 24.6s. Final parser coverage passed 4/4 and static
  validation passed in 48.6s. No browser, export or Web timing ran.
- Exact-diff self-review then closed a shutdown-ordering race: a new shutdown
  marker now requires the verified child to still be alive, so cleanup cannot
  retroactively excuse a spontaneous exit between ownership reads. Only an
  already-present matching marker permits deterministic cleanup after the child
  exits. The unexpected-exit test now requires both wrapper stderr failure and
  cleanup failure; the full hostile suite passed again in 24.8s.
  Final parser coverage passed 4/4 and static validation passed in 48.2s.

## Child acknowledgement and fallback identity rejection — 2026-08-27

- Independent re-review rejected exact head
  `672cdd25b65ed715e2fd0528d1771c1a7997e384` with two lifecycle findings.
  P1: the exact child could die after parent identity verification but before
  request-marker publication, letting a one-way marker misclassify that
  spontaneous exit as expected. P1: wrapper identity was checked before its
  five-second graceful wait but not immediately before fallback termination,
  leaving a PID-reuse window. P3: unavailable exit identity could still render
  ambiguously and must be the literal `unknown`, not claimed as concrete.
- The server now receives the nonce-bound request and acknowledgement paths.
  Its exact live Python process polls the request and atomically writes the
  matching acknowledgement. Cleanup will not terminate until it observes that
  child-authored acknowledgement and revalidates the child PID/start identity.
  The wrapper classifies shutdown as expected only when both exact request and
  acknowledgement match. A deterministic hook kills the child after the first
  identity check but before publication; no acknowledgement appears, wrapper
  stderr remains unexpected-exit failure and cleanup also fails closed.
- After the bounded wrapper wait, cleanup resolves the PID again and immediately
  compares UTC start ticks before fallback termination. The hostile resolver
  injects an unrelated live process as a reused identity; cleanup refuses the
  stop and proves that unrelated process survives. Unexpected-exit assertions
  accept only an integer exit code or the explicit literal `unknown`.
- PowerShell parsing passed 4/4, Python compilation passed and the complete
  hostile suite passed in the 21.2s combined invocation. Static validation
  passed in 48.5s. After final PID+start-tick comparison hardening, the complete
  hostile/static rerun passed in 69.6s; parser 4/4 and Python compilation passed,
  with zero residual lifecycle processes. No browser, export, Web timing or
  locked-scope change ran.
- Exact-head self-review bound the acknowledgement payload itself to both nonce
  and child PID; parent and wrapper reject any other writer/identity. The final
  complete hostile/static rerun passed in 68.9s.
