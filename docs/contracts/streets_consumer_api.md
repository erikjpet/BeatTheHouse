# Streets consumer API (0.6)

This is the frozen job/route boundary for `crew06_3`, `crew06_6`, and
`crew06_8`. Consumers call `RunState`; they do not read or mutate the Streets
model's saved dictionary.

Normal WorldMap travel does not call any Streets method. A board exists only
when a job or route explicitly opts in through one of these entry points.

## Multi-stop route

```gdscript
var started := run_state.streets_begin_multi_stop({
	"route_id": "numbers_collection_17",
	"origin_node_id": "back_alley",
	"destination_node_id": "the_punchline",
	"distance": "local",
	"attempt": 0,
	"stops": [
		{"id": "corner_book", "node_id": "corner_store", "label": "Corner book"},
		{"id": "motel_book", "node_id": "motel", "label": "Motel book"},
	],
	"deadline_actions": 18,
	"order_mode": "ordered",
	"cargo_id": "numbers_slips",
	"consumer_payload": {
		"success": {"cash": 35, "heat": 0, "flags": {"numbers_route_paid": true}},
		"failure": {"cash": 0, "heat": 7, "flags": {"numbers_route_failed": true}},
	},
})
```

Required fields are `route_id`, `origin_node_id`, `destination_node_id`, a
non-empty `stops` array, and positive `deadline_actions`.

`order_mode` is `ordered` or `free` and defaults to `ordered`. Stop order in
the array is canonical. A stop requires a stable `id`; `node_id`, `label`, and
an explicit `{x, y}` `position` are optional. Without a position, generation
places the stop reproducibly on the board.

The return value is `{ok, message, snapshot}`. Failure to validate never
mutates the run.

## Other mode entry points

```gdscript
run_state.streets_begin_hold(spec)
run_state.streets_begin_chase(spec)
run_state.streets_begin(spec)
```

`streets_begin_hold` accepts `hold_zone: {x, y}` and
`signal_window: {start, end}`. The zone is generated when omitted.

`streets_begin_chase` starts pursuit hot and accepts `assists: Array[String]`.
It rejects entry until either `spec.enabled` or the run flag
`streets_chase_enabled` is true. Each assist is one use.

The generic entry point requires a valid `mode` (`package`, `multi_stop`,
`hold`, or `chase`) and the same origin/destination identity fields. Prefer the
mode-specific method when one exists.

## Driving and reading a run

```gdscript
var result := run_state.streets_apply_action({
	"verb": "move",
	"direction": {"x": 1, "y": 0},
	"pace": "walk",
})

var snapshot := run_state.streets_snapshot()
var live := run_state.streets_has_active_run()
```

Supported actions are:

- `move` with one cardinal `direction` and `pace` of `walk` or `run`
- `wait`, `duck`, `stash`, `ditch`, or `signal`
- `assist` with an optional `assist_id` (chase only)

`streets_apply_action` returns `{ok, message, resolved, resolution, snapshot}`.
An invalid action returns `ok: false` and does not consume an action boundary.
A valid action consumes exactly one Streets deadline boundary and one town
action boundary.

The public snapshot contains mode/status/outcome, player position, visited
stops, deadline and pursuit counters, current board cells, current patrol
positions/facing, legal actions, and an opaque deterministic board signature.
It intentionally excludes consumer effects, job identity, hidden sweep/heat
generation inputs, and future patrol routes.

## Outcome and save ownership

The Streets framework owns movement, detection, cargo state, and resolution.
The consumer owns its data-authored success/failure effects through
`consumer_payload`. A linked Crew job is resolved once by `job_id`; consumers
must not call `job_resolve` a second time.

Active boards use full mid-run serialization in `RunState.active_streets_run`.
Save/load resumes the exact board, patrol phase, player position, cargo state,
stops, deadline, pursuit, assists, and pending consumer outcome. The public API
remains the only supported way to drive the restored run.
