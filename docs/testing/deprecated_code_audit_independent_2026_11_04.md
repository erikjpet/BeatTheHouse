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
  boundaries. Eight public methods are bound; the solver uses ClassDB/string
  dispatch and both packed and dictionary render paths. The sole
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

## Commit custody and remaining acceptance

| Task | Associated local commit | State |
| --- | --- | --- |
| `BTH061-AUDIT-CORE-SUPPORT-002` | `e0cb231b12bd99da8c6093509b235339024ccc19` | Bounded read-only review complete; no source removal justified. |
| `BTH061-AUDIT-NATIVE-BOUNDARY-002` | `e0cb231b12bd99da8c6093509b235339024ccc19` | Bounded registration/reference review complete; no source removal justified. |
| `BTH061-AUDIT-UI-LEGACY-002` | `8ba8ba8aee4d75e099d77dc554e20740473bb563` | Qualified locally; publication and NEXT acceptance pending. |
| `BTH061-AUDIT-TOOL-LEGACY-002` | `88cb119bfb1ede48525a7015fe6619f1215a9e2c` | Qualified locally within the structural/parser scope above; publication and NEXT acceptance pending. |

The final custody receipt, `evidence/independent-final-custody-r1.json`, links the
tested UI diff fingerprint and exact tool hashes to these commits. The sibling
`source` checkout remains clean at
`a1fd98c647fc34139e7b20879cf1bb533d7ab878`; both preserved tutorial test hashes
still match `evidence/preserved_tutorial_manifest_20261104_r1.json`.

The earlier aggregate-validator run `host-r5` remains a failed full acceptance:
its source/tool stages and inner 40 plus independent 11 checks passed, but the
unchanged machine-global process census rejected six external identities.
Four were the recorded task-14 process chain; the other two cannot be attributed
to a workspace from safe recorded evidence. Four subsequent acceptance checks
were not reached. This independent deletion phase does not resolve or waive
that result; no other worker was stopped and no validation guard was weakened.

Automatic approval review rejected the earlier tutorial-branch push before it
executed because publication to shared `main` requires approval. The parent
directed that approval is pending and forbids retry. Neither this local branch
nor the preserved tutorial branch was published during this phase. Exact NEXT
acceptance for these new commits is therefore pending, not denied or claimed.
