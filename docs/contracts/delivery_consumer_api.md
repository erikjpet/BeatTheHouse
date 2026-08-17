# Delivery-run consumer API

Delivery work uses the run's generated world map and the ordinary travel pipeline. It does not own geography, movement, or a separate action economy.

## Starting work

`RunState` exposes four entry points:

- `delivery_begin_package(spec)` — one real target.
- `delivery_begin_multi_stop(spec)` — several real targets, completed in any order.
- `delivery_begin_hold(spec)` — one real venue held across action boundaries.
- `delivery_begin_getaway(spec)` — one real exit target, gated by `enabled` or `delivery_getaway_enabled`.

Targets may be explicit (`targets: [{node_id, label}]`) or selected deterministically from the generated graph with `target_count`. Explicit targets are validated by the same rules. Each selected node must exist, have an archetype and kind, and be reachable through actual graph edges. The job reveals the actual path to an unseen target.

Common spec fields are `run_id`, `job_id`, `deadline_actions`, `cargo_id`, `cargo_label`, `cargo_heat_per_travel`, and `consumer_payload`. The payload has `success` and `failure` dictionaries with `cash`, `heat`, `flags`, and optional `clean_speed_bonus_cash`.

## Reading and acting

- `delivery_has_active_run()` reports whether unresolved work exists.
- `delivery_snapshot()` returns schema-versioned, save-safe non-geographic state.
- `delivery_map_layer()` returns cached-input map annotations: targets, deadline, cargo, and qualitative edge reads. It only consumes the public `sweep_status()` capability, so hidden sweep position is never exposed.
- `delivery_arrival_interaction()` exposes the physical handoff only after normal travel generated the target room.
- `delivery_complete_handoff()` completes the current room's pending handoff.
- `delivery_use_getaway_assist(assist_id)` consumes a getaway assist once.
- `delivery_abandon(reason)` closes an impossible or declined run without blocking travel.

`FoundationMain._travel_to` remains the only movement path. After it pays normal cost, advances time, rolls normal risk, and generates the destination, it calls `delivery_resolve_travel_arrival`. Consumers must not call that arrival hook to simulate travel.

## Resolution and compatibility

Linked crew jobs resolve through the crew job framework. Numbers collection and bribe runs are adapters over the same API. Save data uses `active_delivery_run` schema version 1. Legacy `active_streets_run` data is closed during load, its linked work is made non-blocking, and no board geography is migrated.

When no delivery is active, the map layer is empty and the ordinary travel pipeline does not call any delivery mutation.
