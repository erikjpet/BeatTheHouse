# Venue scenario lifecycle

Scenarios follow a location's authored opening hours, independently of travel
access, closing grace and paid game state.

- A scheduled location retires its scenario at closing and starts a selection
  cycle at reopening. Overnight hours belong to the preceding opening.
- An actually 24-hour location retires its scenario at 02:30. It contains no
  location scenario from 02:30 inclusive until 04:00 exclusive. The next
  selection cycle starts at 04:00. Midnight alone is not a turnover.
- Selection retains the ordinary weighted choices, recent-selection rules and
  25% empty outcome. A new cycle does not guarantee a different or nonempty
  scenario. Unseen skipped cycles are not generated or awarded.

The clock boundary and room installation/Continue share one transaction in
`RunGenerator.refresh_current_venue_scenario_cycle`. Visited destinations are
reconciled lazily on installation. Repeated refreshes within a cycle do not
select again, reinitialize objectives or replay accepted outcomes. All floors
of a layered venue share the same cycle.

## Retirement and persistence

Retirement validates the existing causal journal and invokes the definition's
existing cleanup operations. Unfinished objectives record the authored expiry
disposition: failure for `fail`, ignore for `ignore`, cancellation otherwise.
Completed outcomes remain completed. Even an old resumable scenario's visible
material retires at the venue boundary; it does not override the 24-hour gap.

`environment_situation_cycles_by_node` stores selection metadata and historical
retirement records by cycle and floor. Records retain the original accepted
command journal, resolved-event history, outcomes and separately receipted
cleanup. Retired scenario events leave the live resolved-event fallback so
they cannot become immutable base objects in a later scenario. Base events
and unrelated resolutions remain intact.

Earned inventory, rewards, debt, Crew/world-owned sequences, accepted package
obligations, paid machine state and unrelated room controls are preserved.
Turnover neither starts a synthetic visit nor consumes the run RNG. Scenario
selection uses its existing deterministic venue-cycle stream. Authenticated
action origins scope new-cycle UI tokens and idempotency keys, preventing a
prepared action from an earlier occurrence from binding to a later one.

An older save adopts its recorded entry's opening cycle while it is still
current. If a close has elapsed, the saved scenario retires before rendering.
Unknown entry history is adopted once rather than reconstructed. Historical
rewards are never replayed, removed or refunded.

Strict membership, layout and causal validation remain required. A rejected
rollover restores its prior state. A rejected lazy destination restores the
actual source room's context, including its room-scoped Heat. Closing grace
and ordinary venue access rules are unchanged.

A saved destination can still contain its previous opening's scenario after the
town has selected the next opening. Lazy retirement authenticates that saved
room using its own validated catalog definition and keeps the already-selected
new cycle, including a no-scenario selection. A failed destination build never
installs an empty room or evaluates bankruptcy/stranding against it.

## Focused checks

- `scenario_venue_cycle_schedule_check.gd`: exact scheduled/overnight and 24-hour
  boundaries, skipped dates and unchanged access hours.
- `scenario_venue_cycle_captured_check.gd`: genuine copied active/completed
  saves, journals, machines, rewards, RNG, layered floors and Save/Continue;
  `restore_only` continues an emitted private save in a fresh engine process.
- `scenario_venue_cycle_edge_check.gd`: skipped cycles, lazy destination
  installation, strict tamper rollback and accepted delivery preservation on
  a rejected historical destination. This destination-stage check does not
  claim an actual paid UI trip.
- `travel_destination_rejection_check.gd`: the preserved Gas-to-Store revisit
  through the normal map confirmation, one fare/time boundary, old causal
  journal and paid machines, repeated publication, Save/fresh-process Continue,
  synthetic invalid-destination rollback and historical terminal non-revival.

The tests use isolated saves and authority companions. Original QA profiles
and private authority material are not repository test fixtures.
