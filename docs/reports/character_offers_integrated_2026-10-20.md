# Nine optional offers: integrated qualification

The qualified first-batch commit `240f0d8681c1004021cb5889154e5e0d225e362c`
(tree `e784898e90d8d5f0f07ebce3beafdf93e59d9def`) was integrated with
June/Sable `4508442d832269dcd3076fe7fb7e9a684f7112d9` and
Ox/Rafi ride `bfe26291191758e92f3ef88ab56482de8e6cd696` onto current main,
including `4080cd832497d73b792c05d8be6d210557f82c62`.

Nine offers decorate eight existing canonical characters. The only textual
integration conflict was resolved by retaining both the qualified controller's
copy-on-write card decoration and the fixed-ride eligibility callback. The
qualified sealed-catalog, signature and background-refresh fixes remain intact.
Fixed rides now participate in those same caches, including invitation, lock,
and target visibility changes without a clock tick. Route checks are memoized
within each visibility stamp; ordinary clock changes that preserve the offer
keep the inexpensive background patch.

The newer VP, slot, Binder, pull-tab, TalkDock and lesson files are byte-identical
to main. Its two later FoundationMain changes (slot catalog lookup and paid
tutorial Continue recovery) are retained, as is the subsequent manifest
canonicalization optimization. No native/export configuration or audience was
changed.

## Native results

Official Windows Godot 4.6 stable `89cea1439`, headless, Dummy audio:

| Focused contract | Result |
| --- | --- |
| `character_offers_check.gd` | 217 assertions, zero failures |
| `character_offers_batch_two_check.gd` | 151 assertions, zero failures |
| `character_offers_roads_and_ride_check.gd` | 61 assertions, zero failures |
| `character_offer_canvas_actions_check.gd` | 118 assertions, zero failures |
| `character_offers_cache_check.gd` | 36 assertions, zero failures |
| `animation_liveness_without_pointer_check.gd` | PASS |

Total: **583 assertions plus the animation gate**, all final commands exit 0.
The first four contracts ran on `7d4a9c9e18b7c03f297dd62d4eb9bd506745dbe2`
(tree `d05a6f5cb73b428bd87372175d307573f83e4ce4`). The final two ran on
`c60e393a2e3849ade343a234aba627b16931fc46`
(tree `8439f0fb9142afa2c8d884e73a2a9fecbcdc2682`); the intervening change
touches only the cache test fixture. Production source is identical.

The first cache attempt failed six of 35 assertions because its new fixture
changed authored route fields after the canonical room installation had sealed
them. The controller correctly rejected that room before publishing Rafi's
card. The fixture now preserves those fields and explicitly requires an
authenticated physical Rafi card. The corrected 36-assertion cache contract
passed; production authority checks were not weakened. Only that contract and
the not-yet-run animation gate were run afterward.

The two actual Jobs lasted 49.125 and 19.281 seconds. Each contained the Node
worker before its first instruction, with inherited Godot processes constrained
by a verified 12% aggregate CPU hard cap, 2 GiB aggregate memory cap, no
breakaway, and kill-on-close. Deadlines included cleanup. Both ended with Job
active count zero, no forced termination/watchdog/errors, and independent OS
checks found every observed PID absent. Two additional launch attempts stopped
at the fresh headroom gate before creating any runtime.

Retained local receipts are under `task-6/merged-offer-qualification/` in
`run-20261020T225627Z` and `run-20261020T230116Z`. Isolated test storage is
excluded from the repository. The existing root-certificate-store warning was
retained; final logs contained no additional unexpected stderr.

This is functional native qualification, not a CPU benchmark or visual Web
proof. NEXT publication is verified separately against the exact promoted
commit through the existing watcher and public build metadata; no duplicate
watcher or browser is launched for this work.
