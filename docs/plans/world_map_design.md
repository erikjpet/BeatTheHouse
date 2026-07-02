# World Map Design Lock

T4.8 replaces per-room destination props with a persistent seeded world map. This
document is the implementation contract for the Act 1 map; it intentionally
leaves no open design questions.

## Graph Shape

- Each run owns one world graph for its full lifetime.
- Node identity is persistent and stable. Node ids are the destination
  archetype ids (`corner_store`, `bar`, `grand_casino`, etc.) so existing travel
  route ids, route unlocks, and story logs remain compatible.
- Standard Act 1 runs include one node for every enabled environment archetype:
  the start-capable tier-1 shops, tier-1 casino rooms, tier-2 venues, the jazz
  club, and one `grand_casino` node.
- Content groups and challenge config can remove games/items inside nodes, but
  Act 1 environment archetype nodes remain present unless future data explicitly
  disables an archetype.
- The start node is selected from start-capable shop archetypes using the run RNG
  and is marked visited immediately. Its adjacent nodes are revealed.

## Layout

- Node positions are generated in normalized 0..1 map space from the run seed.
- Layout uses distance rings: tier-1 nodes near the left and center, tier-2
  nodes farther right, and the Grand Casino on the farthest right ring.
- The selected start node is biased near the left edge. Nodes receive seeded
  angular jitter inside their tier ring, then a deterministic spacing pass nudges
  overlapping markers apart.
- Layout is deterministic for a fixed seed and challenge config. Different seeds
  should visibly differ.

## Distance And Cost

- Edge numeric distance is derived from geometric distance in map space and
  quantized into four bands:
  - near: 1-3 blocks
  - local: 4-6 blocks
  - far: 7-10 blocks
  - remote: 11+ blocks
- Edge cost starts from the destination route's authored base cost and scales by
  band (`near` x1.0, `local` x1.35, `far` x1.75, `remote` x2.25), rounded up.
- The legacy `distance` strings in `data/travel/routes.json` are treated as
  fallback display/risk metadata only. Map edges supply the active distance band,
  numeric distance, and cost.

## Edges

- Every node connects to two or three nearest neighbors, with at least one
  same-tier or adjacent-tier connection when possible.
- Tier-progression guarantees add reachable steps from any start node through
  tier 1, tier 2, and the Grand Casino within six hops.
- The old underground-to-Grand-Casino risky shortcut remains guaranteed as a
  direct edge from `small_underground_casino` to `grand_casino`.
- Edge metadata is built by merging the destination route definition with
  generated distance/cost. Route risk, unlock requirements, availability windows,
  and condition text stay authoritative.

## Visibility And Scouting

- Node states are `hidden`, `revealed`, or `visited`.
- Only `revealed` and `visited` nodes are drawn. Hidden nodes are absent from map
  snapshots and visuals.
- Visiting a node marks it visited and reveals its neighbors.
- Revealed nodes show name, distance, locked state, and partial T4.6 preview.
- Full scouting from travel items/services upgrades revealed-node detail to full
  preview without marking the node visited.
- The map stores node `scouted` flags so future scouting can persist.

## Revisit Semantics

- First visit generates an environment from the node archetype with the existing
  `EnvironmentInstance.from_archetype` and per-game `generate_environment_state`
  flow.
- Leaving a node stores the current environment snapshot on that node.
- Returning to a visited node restores the stored environment snapshot, including
  game state, depleted pull-tab deals, resolved local events, travel locks, item
  offers, local flags, and layout.
- Shops do not automatically restock on revisit in Act 1. Future restock events
  may explicitly mutate a node's stored environment.
- `environment_history` remains the story/log audit trail, but world node state
  is the source of truth for revisits.

## UI Contract

- Rooms expose one travel object: `travel:leave`, labeled Leave. Destination
  travel objects are removed from room scenes.
- Clicking Leave opens a modal map overlay. Close/Cancel returns to the room at
  no cost.
- Current and visited nodes are filled markers. Revealed unvisited nodes are
  outlined markers. Locked edges use dashed/dim styling. The visited path is
  drawn as a breadcrumb polyline.
- Selecting a reachable node populates a side panel with distance, cost, risk,
  unlock state, preview lines, and a Travel button.
- If the current room is travel-locked, the overlay shows the lock reason and no
  Travel button until the lock expires.
- Confirming travel uses the existing `FoundationMain._travel_to` and
  `RunState.travel_route_status/travel_route_risk` result path with the selected
  edge route data.
