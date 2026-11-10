# Crew deployed Web acceptance, 10 November 2026

Both assigned objectives are complete on exact immutable NEXT
`85d38b96a3c2b1d47020dd6e5a6c4bb12605ca0f`:
`BTH061-CREW-EXPIRED-HANDOFF` and `BTH-GAME-RETURN-001`.

The existing fixes `b29d9b3985b5676aac2439f2f08aae359729a3e3` and
`4355f5611f0f77f546d898e39524f6b8e974c161` are verified ancestors. No production
source, game rules, settlement authority, audience or deployment setting changed.
This closeout records acceptance only.

## Qualifying Web behavior

Normal HTTPS, the delivered 85d38b96 footer, full native game surfaces and actual
pointer presses were used in an isolated fresh Chromium 1243 profile. The eight
flows, commands, screenshots and hashes are in the [JSON companion](crew_web_acceptance_20261110.json).

- Jazz expiry: the synthetic before-expiry Continue reaches closing time 1050.
  Missed delivery records cash 66 and heat 9. Stale Handoff disappears while
  Recording Night's authored room remains. The room keeps responding. A browser
  process cold Continue retains exactly the same 137308-byte primary, SHA256
  `00fd1155ecf90b419d269bf84d3f3fae713ee5cd126b9bbf188f48bddd634d56`.
  Leave and Open Map work afterward. No settlement replay is observed.
- Roulette acceptance: a paid $1 RED spin debits 1000 to 999 and opens Mags'
  Crew offer over full Neon Wheel. Two normal confirmation presses accept the
  package and return to that wheel. The 32 red result settles to 1001, with one
  active carried package and no early 22 Crew payment. Cold Continue and normal
  game re-entry retain 1001, the same delivery run ID, one package and original
  32 history. A later ordinary unfunded sit-out 12 advances history, so the
  Roulette primary and RNG are not claimed byte-identical. Only expected clock
  boundary fields change in the delivery record.
- Roulette neutral Close: a separate reset reaches a visibly pending Crew offer
  during a paid spin. Close returns to full Neon Wheel. The 32 red result settles
  to 1001 without accepting a delivery. An earlier automated trial clicked too
  soon and had no Crew offer; it is excluded from acceptance.
- Coin Pusher acceptance: a paid Drop debits 1000 to 999 and opens Bishop's offer
  over full Quarter Falls. Accepting returns to the live board at 999, with
  exactly one active carried package and no early 22 payment. Cold browser
  Continue and normal game re-entry retain 999 and an identical delivery record.
  The 103027-byte primary is byte-identical, SHA256
  `485f5647283dfd854c8d6b9e5f3b9008522877ef5d9cb1839a61d52be227277c`.
- Coin Pusher neutral Close: a separate paid Drop/offer/Close returns to full
  Quarter Falls at 999 with no delivery accepted. Another normal Drop works,
  showing 998 while the full board keeps rendering and advancing. This extra
  liveness Drop is not cold-save proof: its immediate IDB capture still has the
  prior 999 primary before teardown. The accepted-Drop cold case above supplies
  the separately qualified persistence evidence.

Representative captures: [Jazz cold](crew_web_20261110/jazz_cold.png),
[Jazz map](crew_web_20261110/jazz_map.png),
[Roulette accepted](crew_web_20261110/roulette_accepted.png),
[Roulette closed](crew_web_20261110/roulette_closed.png),
[Coin Pusher accepted](crew_web_20261110/coin_accepted.png), and
[Coin Pusher closed](crew_web_20261110/coin_closed.png).

## Fidelity and retained evidence

These are recreated synthetic fixtures, not Erik's unavailable original save.
Jazz uses the authored event, generated town, arrival and world sequence APIs
with an explicitly pinned target. Game captures use synthetic practice rooms,
real native modules, a generated map, two explicit delivery obligations and
Crew trust 50. New production-API saves set clock 750, last-attempt hour 12 and
solicitation RNG 48. Normal entry precedes the first eligible next-hour roll;
the paid game action then opens the authored offer. No private game-method calls
or direct live-state edits substitute for the browser interactions.

The clean fixture producer uses the retained cf781901 checkout and production
Save APIs. Initial clock-779 construction was unused in qualifying Web tests;
the clock-750 successor provides safe entry time. Both Jobs exit 0 without
script errors and release 0 owned processes. The existing 594 native checks in
[the earlier closeout](crew_closeout_20261110.md) retain their 2e3b881 source and
scope. They were not rerun or relabeled as Web gameplay or original-save proof.
Private saves, authority companions, profiles, adapters and raw dumps remain
uncommitted. Only sanitized evidence and screenshots are added.

## Runtime and qualification limits

Storage admission reserves 4 GiB expected writes plus 20 GiB headroom on the
approved E: volume. Every test Job is assigned before execution with the existing
5% CPU / 2 GiB kill-on-close containment. The final browser run exits 0 without
timeout or cleanup errors and releases 0 owned processes. Its 88 command
envelopes include setup and exploration, not 88 gameplay assertions. No action
errors, JavaScript page errors or GDScript errors are observed.

Prior failures remain retained: branded Chrome rejected remote debugging for
its default-directory policy despite the isolated path; an early full Chromium
attempt was stopped during startup; one bounded diagnostic timed out. Read-only
process inspection identified a busy AudioService while the renderer was idle.
The ordinary `--disable-audio-output` QA argument lets full Chromium reach Godot
readiness in 16 seconds. It changes no certificate, security setting or process
isolation. Audio quality is outside this test's scope. The separately authorized CA trust setup was already complete. This test used normal
HTTPS without warnings, certificate exceptions or bypass.

Generic HTTP 404 resource console messages are retained without attributing an
unrecorded URL or claiming a perfectly clean console. They did not stop the
exercised game flows. This is focused behavior acceptance, not a full suite,
statistical performance test, audio qualification or unexercised-platform claim.


## Reconciliation and document checks

The manual current-ledger check with local Git verification and retained global
owner/runtime snapshots has no findings for either assigned Crew ID. Its 889
findings outside this scope remain unresolved; the snapshots are not a fresh
global inventory. The focused task-ledger checker unit tests pass all 36 tests
in an isolated Job, exit 0 and owned 0. JSON parsing and `git diff --check` pass.
