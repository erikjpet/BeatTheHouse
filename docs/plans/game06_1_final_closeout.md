# game06_1 shared game-ritual runtime final closeout

Date: 2026-09-03  
Recovered product integration: `5a2b1e1a6782a13308585e1a974adeeb86be0647`  
Closeout base: `914e5ac822d8ee3127f210203dc688b182a19c65`

## Verdict

`game06_1` is complete. The landed `game_ritual/1` runtime is the accepted
shared vocabulary used by the seven finished Family 1 game rows. Closeout
started from current `main`, retained the integrated implementation, and did
not replay either rejected historical product head or rebuild shared runtime.

The runtime remains additive and game-neutral: it validates closed phase,
commitment, gesture, actor, object, energy, fact, receipt, handler, layout and
restore records while authoritative rules, wagers, RNG and settlement remain
owned by each game and its sealed Foundation host.

## Requirement reconciliation

| Prompt requirement | Landed implementation and proof | Verdict |
| --- | --- | --- |
| Harvest and generalize the Craps ritual | The classification and consumer/seam matrices in `game06_1_table_machine_ritual_vocabulary.md` separate neutral vocabulary from Craps-owned rules. The shared source neutrality scan covers seven files and rejects Craps terms. | PASS |
| Versioned closed ritual contract | `game_ritual_schema.gd`, fixtures, and the 132-negative vocabulary suite validate every frozen record and `ENV-VOCAB-01` through `ENV-VOCAB-14`. | PASS |
| Structural phase and settlement safety | `game_ritual_runtime.gd` binds expected phase, boundary ordinal, request/receipt/fingerprint and authenticated host action before atomic mutation. Replay is idempotent; conflicts and out-of-phase actions reject. | PASS |
| Staged commitment and correction | The runtime proof places, corrects, removes, undoes and confirms individual pending items while preserving readable pending/at-risk/available totals. | PASS |
| Equivalent tactile verbs | `game_ritual_layout.gd` and `game_surface_canvas.gd` compile semantic pointer targets into the existing exact/drag/hold capture machinery and require keyboard, controller and reduced-motion equivalents. | PASS |
| Actors, objects, energy and layout | `table_game_visuals.gd` draws opt-in semantic actors/objects; layout validates bounds, z-order, text safety, touch size, reachability, small-screen and non-color distinction. Music/text-only energy rejects. | PASS |
| Safe facts, handlers and persistence | Closed typed public facts publish only after committed action boundaries. Handler operation/fact allowlists and authenticated snapshots reject hostile restore, unknown fields, stale authority and replay conflicts. | PASS |
| Opt-in compatibility | Existing games do not invoke ritual APIs implicitly. All seven adopting rows and the untouched compatibility surfaces remain covered by the full game-surface/module contract. | PASS |
| Determinism, platform and performance discipline | The focused runtime repeats ten traces byte-identically for native/Web-equivalent consumers, reads no wall clock for authority and adds no per-frame copy path. Every adopting row's final native/Web and liveness gate is green. | PASS |

## Exact-tree closeout evidence

- `tools/game_ritual_vocabulary_contract_test.ps1`: PASS, 132 negative
  fixtures, seven neutrality targets, accepted env06_6 mapping `749390ce`.
- `scripts/tests/game_ritual_runtime_test.gd`: PASS through Godot 4.6 stable;
  rejection atomicity, phase legality, exactly-once receipts, restore safety,
  layout, equivalent input and ten deterministic traces all passed.
- Project validation: PASS in 80.179 seconds.
- GDScript load census: PASS, 304 runtime/tool scripts in 33.462 seconds with
  zero failures and zero stderr issues.
- The exact-tree Blackjack consumer contract and all later Family 1 row
  contracts pass against this same landed runtime. Their final closeout reports
  supply actual native/Web, performance/liveness, accessibility and visual
  evidence without granting shared code game-specific authority.

The first direct Godot invocation in a fresh worktree ran before its class
cache import and printed missing-class parse errors; it is retained as invalid
setup evidence. A clean editor import completed, and the corrected direct run
passed. No requirement, fixture or budget was weakened.

## Remaining human check

No runtime implementation or automated closeout work remains. The later owner
playtest should judge pacing and feel across the consuming games; that human
experience check is not represented as automated acceptance for this row.
