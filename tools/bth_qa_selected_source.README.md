# Selected source archives for BTH QA

This helper prepares a smaller, explicitly partial Git source snapshot for an
environment/native/TEST QA campaign. It keeps runtime resources, native pins,
GDScript discovery inputs, tests and maintained QA tools. It does not modify a
working tree, thin an existing campaign or replace a qualified baseline.

## Fixed selection

The admitted pathspec has exactly these 21 entries:

```text
.gdlintrc
.gitattributes
.gitignore
AGENTS.md
CHANGELOG.md
README.md
assets
data
default_bus_layout.tres
docs/.gdignore
docs/plans/world06_1_crew_sequence_adapter_contract.md
docs/archive/0.5/plans/0.5_voice_bible.md
docs/todo/environment_slot_family_manifest_legacy_mapping.json
docs/todo/environment_slot_consolidation_disposition.json
export_presets.cfg
icon.svg
native
project.godot
scenes
scripts
tools
```

All descendants of the six selected directories are retained. The plan binds
each selected file to the actual Git tree record, including its mode, blob OID
and byte length. It also binds the full 40-character source commit and tree and
the canonical selected-file inventory digest. A matching commit alone is not a
proof that a partial archive contains the required selection.

The world-sequence specification and voice bible are read by retained GDScript
assertions. The two slot-migration ledgers support retained Python regression
tests. `docs/.gdignore` keeps these document fixtures outside Godot discovery.

## Import and runtime closure

Preserve all selected resources and their tracked UID/import sidecars. The Web
export excludes `tools/` and `scripts/tests/`, but Godot imports those directories
before export. Removing their GDScripts, scenes or sidecars can change the UID
cache and compiled resources. Do not add `tools/.gdignore`, move QA GDScripts into
the selected roots, regenerate canonical metadata or relax the baseline gates to
make a smaller snapshot pass.

Qualification must prove the selected snapshot against the immutable qualified
Bar baseline, including the complete 1,605-entry UID map, 224 global script
classes, 421 raw files (400 environment/doorway PNGs and 21 JSON files) and 400
imported textures. The native
extension descriptor is an explicit, hash-bound overlay from the qualified
baseline; it is not an omitted Git file reconstructed from a guessed library.
Source/resource closure checks supplement archive verification. They do not
replace native behavior, motion, no-pointer animation liveness or strict TEST
PCK-delta gates.

Godot-native import/export and the existing Grand candidate approval remain
separate guarded operations. A selected-source receipt is not candidate
approval, art acceptance, a successful build, publication or browser acceptance.

## Archive and extraction proof

The archive is labelled `PARTIAL_SELECTED_PATH_ARCHIVE`. Preserve its selection
plan, archive SHA-256 and per-file Git/blob and SHA-256 verification. The archive
must have the pinned Git PAX commit comment and exactly the planned regular
files and ancestor directories. Reject unexpected or missing members, duplicate
or case-aliased names, links, special entries, unsafe paths and differing modes,
lengths or Git blob identities.

Extraction is into a fresh, absent destination on admitted E: storage. It checks
the storage layout before writes, creates no file over an existing file and does
not use unchecked `extractall`. Verification of the extracted tree is strict:
no omitted files, extra files, extra directories, links or altered bytes. POSIX
executable bits can be checked directly; Windows extraction must retain the
verified Git modes in its extraction receipt rather than infer executable bits
from Windows permission reporting.

Retain the complete plan and extraction proof. A reduced archive changes the
native source inventory and inventory-derived assertion count. A fresh campaign
must bind its actual selected source; it must not reuse an older full-tree source
receipt or silently lower the fixed semantic assertion requirements.

## Guarded execution

`plan` prints the configuration and commands without launching a child or
writing outputs. The guarded execution order is `source-identity`, `tree`,
`baseline-tree`, `select`, `archive`, `verify-tar`, `extract`, `verify-extracted`.
Each subprocess belongs to a fresh bounded worker through
`bth_qa_guarded_run.execute`. Internal file workers do not create subprocesses.
Use the existing assignment-before-resume, kill-on-close Job and cleanup and
reconciliation behavior, with the maintained CPU and memory caps.

Before the first directory, write or child launch, admit the complete layout
through `bth_qa_storage.py`. Use explicit workspace, profile, temp, evidence and
declared output paths under `E:/CodexQA/BTH`; reserve the configured write budget
plus headroom (defaults: 4 GiB expected writes and 20 GiB reserve). Revalidate
immediately before every child launch and before extraction writes. Record the
storage manifest and actual launch gate. A storage rejection stops that
operation with its exact error. There is no C: fallback or security-setting
change. Existing saves, profiles and active campaigns are not migrated.

The selection also has a conservative write bound: two payload copies, bounded
tar/header overhead and 32 MiB for evidence must fit the admitted expected-write
budget. This is checked before selection proof writes, archive preparation and
the first extraction write; it does not reduce the separate capacity reserve.

The in-memory contract tests are source-only until a parent runs them through an
admitted bounded worker. They must not create temporary fixture trees, import
Godot, start subprocesses or contact a network service.

## Read-only plan example and integration

The following example, run from the art worktree, only requests a read-only
plan. It names the retained S24 source and immutable qualified Bar baseline.
Choose a fresh workspace and run prefix before any execution; the CLI's first
`source-identity` phase requires an absent or empty workspace. Do not point it at
an existing Grand campaign. The C: Git and Python paths below are read-only
executable inputs, not QA output or profile locations.

```powershell
$selectedArgs = @(
  '--workspace', 'E:/CodexQA/BTH/workspaces/BTH-SELECTED-SOURCE-EXAMPLE',
  '--archive', 'E:/CodexQA/BTH/workspaces/BTH-SELECTED-SOURCE-EXAMPLE/source.tar',
  '--destination', 'E:/CodexQA/BTH/workspaces/BTH-SELECTED-SOURCE-EXAMPLE/source',
  '--git', 'C:/Program Files/Git/cmd/git.exe',
  '--git-dir', 'D:/Projects/Beat-The-House/.git/worktrees/environment-art-layers',
  '--source-commit', '24b8e34bb228335eb17db403757b9ce6f21c7151',
  '--source-tree', '3ab6b78b6cb04b0d6553ec5dd8e55f6bb53c5505',
  '--baseline-stage', 'E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-BARBUILD2-20261116/.tmp/web-release-7b284648/stage',
  '--overlay-descriptor', 'E:/CodexQA/BTH/workspaces/BTH-ENV-SPATIAL-BARBUILD2-20261116/addons/coin_pusher_native/coin_pusher_native.gdextension',
  '--run-prefix', 'BTH-SELECTED-SOURCE-EXAMPLE',
  '--timeout', '1200'
)
& 'C:/Users/theep/AppData/Local/Programs/Python/Python310/python.exe' -B tools/bth_qa_selected_source.py plan @selectedArgs
```

The baseline manifest SHA-256 is
`5855381ff2137ece43c2b097b169c70c50b658f1caa6d86e1461b42b22bbe447`;
the PCK SHA-256 is
`a84ed267a7d664ada937d441be1d053419fe78df5e6725e217c99d60b0bc4ba1`.
The helper authenticates these actual files and the explicit descriptor before
claiming baseline source closure. A successful `plan` does not perform that
closure proof; the guarded `select` worker does.

An integrating native adapter may call the pure planner/verifiers and use its
own already admitted campaign `Layout` for extraction. It must preserve this
helper's proofs and all existing native and candidate identity checks. Its Git
archive child must retain the exact selected `PATHS` and include
`-c tar.umask=0022` before `archive`; otherwise Git's default mask can produce
`0664` files instead of the authenticated `0644`/`0755` mode policy. That child
still needs the full capped-Job launch gates and a declared absent archive path.

## Scope and external inputs

This snapshot supports the declared environment/native/TEST scope. It is not a
complete repository checkout. In particular, repository-wide historical hygiene
and Git/index checks require additional data and repository semantics. The
historical documentation hygiene manifest alone requires 739 destinations,
including 697 PNGs. Keeping those test scripts does not claim that their complete
historical fixture set is included.

Grand's original observer/provenance files remain explicit external inputs from
the qualified `BTH-ENVART-GRAND-TRIAL-20261115` donor. The selected archive does not
replace or weaken their hashes. Bar reconstruction workflows separately require
`review_artifacts/environment_art_sources/bar-v1-r4/bar-v1-r4-qa-source.zip`;
Grand raw-trial rematerialization separately requires
`review_artifacts/environment_art_sources/grand-spatial-r1/grand-spatial-r1.png.b64`.
Neither is needed merely to retain the active runtime source and must not be
silently synthesized when a workflow requests it.

Additional documentation contracts, source-art custody audits, archived authoring
tools and media-generation tools need their own explicitly bound fixtures. Run
those checks against their complete admitted source or prepare a separately
reviewed scope. Do not edit frozen observers, build adapters, export exclusions
or baseline allowlists to make this selection appear to be a full checkout.
