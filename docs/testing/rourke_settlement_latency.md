# Rourke settlement latency

The isolated Web check on `4b043333` completed all five preserved-fixture duel
hands without a Crew package modal, but a screenshot-free fourth-hand probe
recorded a 3,973 ms main-thread task and a 4,074.8 ms frame gap after Stand.
The browser used the supported Playwright `chromium` channel (new headless),
hardware ANGLE/D3D11 on the RTX 4070 Ti, sandboxing, muted output, and the
maintained 12% aggregate CPU / 2 GiB Windows Job limits.

The same fixture through the native Foundation control path took about
1.27–1.32 seconds per settlement. Sealed action resolution accounted for about
0.94 seconds, and delivery preflight about 0.30 seconds. Post-action Crew and
event checks took only a few milliseconds. Full-run authority serialization
repeatedly projected and fingerprinted inactive rooms and the world map.

Rourke now supplies evidence for the current room and every non-world run root,
including narrative, Crew, inventory, balances, RNG, history and terminal state.
Only large `world_map`, `town_state`, and `grand_casino_room_states` storage
are omitted at the source. The proof separately includes room configuration and
the town reputation ledger, type registry, action index and propagation topology:
the taken-out-back ending records a reputation incident. The stored Back Room's
table mirrors the current room already present in the proof. This projection is
never used to save, restore or publish a run. Both executions receive independent
full transaction candidates, including all world models; the ordinary narrow
machine candidate would alias narrative and other collections and is unsuitable.
Scenario-bound and Crew actions retain their full snapshot proof. The room
variant selects the broad Rourke proof even after the last hand clears the
active-duel flags. Canonical serialization and accounting/RNG rules are unchanged.

Focused check:

```powershell
godot --headless --path . --script res://scripts/tests/rourke_authority_evidence_check.gd
```

Set `BTH_DISTRIBUTION_BUILD=1` and an isolated `BTH_DISTRIBUTION_DATA_ROOT` before
running. The check loads the unchanged repository v0.5.1 duel fixture through
SaveService/RunSaveCodec, compares all five hands with the former full-proof
path, compares complete public run snapshots including the world, audits both
executions for unrelated world mutations and exact table mirroring, checks
exactly-once replay and terminal Continue, and injects narrative and reputation
replay mismatches to verify failure atomicity. It uses
real surface intents and the production sealed host, with a verification-only
subclass auditing each proposal. It is native evidence, not Web visual evidence.

The initial isolated native Foundation measurement after the change was about
0.12 seconds per settlement. Final native receipts and the current deployed Web
identity/observations are kept in the task evidence directory. Do not treat the
earlier `4b043333` screenshots as qualification of later user placement changes.
