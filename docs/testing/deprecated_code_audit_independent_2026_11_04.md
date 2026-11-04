# Independent audit outside paused areas

Parent: `BTH061-AUDIT-001`; local phase: `BTH061-AUDIT-INDEPENDENT-001`.
Base: `79ace22c2e508134c3ab4c5698b14426688ab6f6`.

This work uses a separate local `audit-independent` worktree. The sibling
`source` worktree and its tutorial repair at `a1fd98c6` are preserved. No denied
push was retried, no publication was attempted, and no worker or machinery was
stopped or reconfigured. Item/inventory, authored scenarios/sequences, their
implementation/data and active shared APIs are outside the edit scope. No
tutorial repair, guard, validator, native source, export or pipeline is changed.
The parent objective remains Open.

## Confirmed removals

| Task | Removed | Evidence |
| --- | --- | --- |
| `BTH061-AUDIT-UI-LEGACY-002` | `FoundationWidgets.tooltip` and its sole `VisualStyle.TOOLTIP_MAX_WIDTH` constant | `8713068f` removed the only actual caller, `StatusIcon._make_custom_tooltip`, restoring the engine tooltip. Current HUD tooltip text and all retained widget methods remain unchanged. No current receiver, callable/string, test or applicable reflection consumer remains. |
| `BTH061-AUDIT-UI-LEGACY-002` | Two unused WagerConfirmationController signal declarations | Extraction `365022b5` already used the current direct confirm/cancel host callbacks. No controller emission, connection or relevant signal reflection consumes either declaration. Same-named settings/surface members belong to other receivers and remain. |
| `BTH061-AUDIT-TOOL-LEGACY-002` | `edge_scene_layer` | Unused from introduction `e445efc2`. All five supported itch CLI outputs and the gallery update bypass it. It has no registration, dispatcher, importer, documented manual helper API or definition-time effect; its body only returns a local image. The older audit's retention note is not a hold or consumer. |
| `BTH061-AUDIT-TOOL-LEGACY-002` | Twelve unused palette bindings | Seven lost-reader bindings follow removal/replacement of old banner, bokeh and trailer backdrops; five additional declarations have closed CLI/dynamic/import boundaries and pure initializers. Retained generator functions and supported output protocols are unchanged. |
| `BTH061-AUDIT-TOOL-LEGACY-002` | Cabinet capture's unused renderer preload | `b8bba8d7` replaced the projection reader and `557b82d8` removed it. The tool independently keeps Solver API; the live production game loads its renderer. The renderer has no static initializer/variable or script superclass whose setup is lost. |

The change is 40 deleted lines across eight existing files: 13 UI lines and 27
tool lines. No retained function body is changed. All 30 retained UI methods
compare byte-equivalent after newline normalization; all 45 retained Python
function ASTs and CLI entry points match. The capture body is identical except
for its unused preload. No artwork or saved schema is regenerated.

## Review coverage and retained candidates

- Core: 16 generic support modules, 219 top-level functions and 108 constants.
  No deletion is justified. SaveService's apparently retired `_save_payload`
  still has actual reflective callers; cache, RNG, codec, settings, archive and
  schema APIs have current consumers. Shared paused-area consumers are retained.
- UI/games: 128 paths inventoried, with a focused lead review of 28 eligible UI
  files / 856 functions and 44 eligible game files / 2,992 functions. Candidate
  tables distinguish receiver-specific use, interfaces, dynamic dispatch,
  callbacks and paused/shared exclusions. No additional game deletion is
  justified. Enumeration does not imply manual review of every body.
- Tools: 413 paths classified; 66 eligible bodies / 615 function definitions
  screened. Public CLIs, current generators, historical evidence, native/parity,
  tutorial, item/scenario and operational/validator/pipeline boundaries remain.
- Native: 11 paths have the same native-tree identity as the earlier baseline.
  A 70-definition reference screen was checked against registration and API
  boundaries. Eight public methods are bound and used through ClassDB/solver
  dispatch; packed and dictionary render paths both remain active. The sole
  low-token lead, `coin_pusher_native_library_init`, is the explicit template
  `entry_symbol`. No native code change or fresh build/parity claim is made.

These are scoped reference/history and targeted semantic reviews, not an
exhaustive whole-program or all-line proof. In particular, the logo's optional
`random` import/seed is retained: its process-global RNG mutation is observable,
and its output/import-effects equivalence is not established. A prior audit
decision or missing call alone is never a retention/removal authority.

## Qualification

- Normal bounded editor import passes in the independent checkout.
- Existing HUD tooltip check passes 12 assertions; UI design-system check passes.
- Existing Slot wager-confirmation check passes 150 assertions, including direct
  confirmation/cancel, stale inputs, background unaffordability and Save/Continue
  cases. Its first run correctly refused missing test-specific private-root
  inputs before constructing a host; the rerun supplied all required fresh
  contained paths. The guard and test source are unchanged.
- The cabinet capture script passes the pinned Godot parser check.
- Four changed Python modules compile without importing/executing the audited
  generators. Exact deletion-only/module AST and CLI protocol checks pass.
- Every owned native job ends with zero active processes. The known isolated
  certificate-store diagnostic is retained; no TLS behavior is changed.
- `git diff --check` passes. Preserved tutorial file hashes are checked separately.

Actual image-output parity is not run: the available Python 3.10 environment
lacks Pillow, and the registered Store Python 3.12 cannot be launched in this
execution context. No dependency installation or artwork generation was needed
for these unreachable/pure deletions. Structural equivalence is the tooling
evidence; no pixel-parity or live cabinet-capture acceptance is claimed.

Raw inventories, receiver/history evidence, exact patches and private native
receipts remain under the task's `evidence/independent-*-r1/` directories, with
the successful wager rerun in `evidence/independent-wager-20261104-r2/`.
The tutorial hash manifest belongs to the sibling preserved branch. New work is
local-only while publication approval remains pending; the umbrella stays Open.
