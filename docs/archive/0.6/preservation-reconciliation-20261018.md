# October 18 preservation reconciliation

The former `D:/Projects/Beat-The-House-preservation` recovery folder was
reconciled into maintained source history and named private evidence cases on
2026-10-21. Its obsolete directory was removed only after all indexed files
had an exact recovery destination. Private profiles, saves, logs, patches and
original evidence stay outside public Git.

## Source disposition

The review covered all four patches, nine held authority files, the held stash,
both raw capture trees, and their relationships to main and consolidated WIP.
The [30-entry disposition table](preservation-code-dispositions-20261018.tsv)
records six changes already on main, eleven superseded alternatives and
thirteen historical diagnostics. There is no remaining justified runtime change
to cherry-pick and no useful incomplete production fix to hide on an unnamed
branch. This reconciliation adds recovery tooling and documentation only.

Accepted work includes the House Calls manual lock (`aeed3a1a`), its separate
third event surface (`0575eb2d`), the slot-exit fix (equivalent patch on
`bfd33933`), promotional captures (`bd0bf164`) and poster assets (`35829f05`).
The retired validator/placement experiments remain historical evidence; their
retirement is documented by `3606ac34` and the existing player-benefit reports.
Replacing current whole JSON layout files with old captures would undo later
accepted layouts and is not part of this reconciliation.

A [supplementary four-entry review](preservation-additional-tree-dispositions-20261018.tsv)
covers three other bundle tree tips. `c72c112a` and `1130e145` add no unique
source/config blobs. `3a8efc36` holds only two unique old audit/test-tool
variants, with no additional gameplay implementation or justified production
transplant. These are explicit historical diagnostics, not a pending merge.

## Named local recovery and WIP refs

These refs are in the original BTH repository's shared object store. They are
local recovery custody, not an instruction to publish old private captures.

| Ref | Exact object | Status |
| --- | --- | --- |
| `refs/preservation/20261018/main-reviewed-3c1eba46` | `3c1eba46610956b0b93dc50b40bd19a0bb1bb4bc` | Reviewed maintained main baseline |
| `refs/preservation/20261018/wip-reviewed-23f6eba4` | `23f6eba4c0c0001aa90f765bbf56b923421729eb` | Consolidated historical WIP; retirement decisions retained |
| `refs/heads/wip/preservation-20261018-authority-placement` | `f2994d1600f970488dd17fc0e2e790b365d54437` | Held original stash, now explicitly indexed; useful production fix already landed |
| `refs/preservation/20261018/capture-3650bbe0` | `3650bbe0d9e1d0dad33420b8e652423246b42544` | Raw tree, not a commit; all reviewed source/config blobs in maintained history |
| `refs/preservation/20261018/capture-6bd51f80` | `6bd51f80c26a0d22cddc53e4aead1e40d21e231d` | Raw tree; unique alternatives reviewed as superseded/diagnostic |
| `refs/preservation/20261018/capture-c72c112a` | `c72c112aaeb756e3ff6f8cbc939b285df142f7d6` | Known retired slot-preview alternative |
| `refs/preservation/20261018/capture-3a8efc36` | `3a8efc3691e1f192f3613deba3f0d16af881ac08` | Two old audit/test-tool alternatives, retained locally |
| `refs/preservation/20261018/capture-1130e145` | `1130e1453374ed3895fbdf1297350736a5d2d7bb` | Historical base; no additional source/config blobs |

The held authority branch has no queued automatic merge. If a new current
player defect makes a historical alternative relevant: reproduce on current
main, compare the individual changed leaf with the accepted manual override,
extract only a justified minimal change, and qualify it with fresh normal-input
evidence. Never merge the entire stash or revive its retired harness blindly.

Three original bundles remain under
`D:/Projects/Beat-The-House/.git/recovery/bundles/20261018/`:
`main-wip-after-b05.bundle`, `all-refs-before-consolidation.bundle`, and
`main-and-wip-after-graduation.bundle`. The original forensic tar and patches
are retained as private evidence, not discarded after importing refs.
The forensic tar's 3,585 regular files were streamed and checked against
`444085caaf5f8b9a8760ce6858923cf7e3f73d5e`, an ancestor of maintained main.
Its file set and every raw Git body match that commit; it contains no extra
unmerged source. The original tar remains intact for forensic provenance.
The final source-extra check also covered 838 raw-unmatched source/config
files: all are CRLF-only copies of retained historical source at the same
paths. Their exact bytes remain private because LF equivalence alone was
never used to delete a file. The forensic CoinPusher extension config matches
the maintained native template after line-ending normalization; original
generated runners and UID/import metadata remain indexed reproduction inputs.

## Private evidence locations

All paths below are relative to `D:/Projects/Beat-The-House/`. The complete
original-path-to-destination inventory, exact SHA256s, file identities,
timestamps and alternate streams are in the private index at
`.tmp/evidence/indexes/20261018-reconciliation/`. No profile or save body is
included in this public document.

| Evidence | Maintained private case |
| --- | --- |
| Release freeze, crew history and promotional originals | `.tmp/evidence/release/0.6-20261018/` |
| Batch04 original input reproduction | `.tmp/evidence/playtests/b04-input-reproduction-20261018/` |
| Lounge failing/passing verification | `.tmp/evidence/playtests/lounge-fix-verification-20261018/` |
| Batch05 normal playtest | `.tmp/evidence/playtests/b05-normal-playtest-20261018/` |
| Held House Calls authority originals | `.tmp/evidence/playtests/house-calls-20261018/` |
| Manual WIP slot session | `.tmp/evidence/playtests/manual-wip-slot-20261018/` |
| Slot exit traces and original profiles | `.tmp/evidence/performance/slot-exit-lag-20261018/` |
| Eleven old contract shard project extras | `.tmp/evidence/contracts/release-0.6-shards-20261018/<shard>/` |
| Retired stability/reset-c-heist extras and reproduction state | `.tmp/evidence/contracts/retired-<lane>-20261018/` |
| Other original investigations | `.tmp/evidence/{playtests,contracts,performance}/<lane>-20261018/` |
| Forensic tar and reset records | `.tmp/evidence/contracts/local-forensics-20261018/` |
| Consolidation records and custody metadata | `.tmp/evidence/release/consolidation-20261018/` |

Each original case keeps its inner profile/log/fixture topology. Eleven copied
stale `.git` markers are retained as inert `.git-pointer.txt` evidence, so they
cannot masquerade as live worktree registrations. Existing active worktrees,
their Git registrations, current/prior NEXT builds and stable 0.6 remain intact.

## Inspect or restore an exact historical copy

The private `manifest.jsonl.gz` contains every original file. For source/media
represented by retained Git, restoration reads the raw blob, without newline
filters. For private evidence, restoration copies the canonical file and its
indexed alternate streams. Both paths verify SHA256 and refuse an existing
output. Omitting `--output` is a dry run.

Run the tracked helper from a current checkout, or its identical installed copy
at the private index, while explicitly selecting the original shared repo:

```powershell
python D:/Projects/Beat-The-House/.tmp/evidence/indexes/20261018-reconciliation/restore_reconciled_copy.py `
  --repo D:/Projects/Beat-The-House `
  --manifest D:/Projects/Beat-The-House/.tmp/evidence/indexes/20261018-reconciliation/manifest.jsonl.gz `
  --original "<exact original_relative from the manifest>"
```

Add `--output C:/chosen/new-file` only when restoring a file. The original
canonical evidence is preserved. Windows long paths and alternate data streams
are supported. No whole historical project needs to be expanded just to inspect
one source file. The index also contains the independently verified raw Git
blob proof, migration journal, directory metadata and completion receipt.

## Verification

128757 original records were reconciled: 90786 exact private files
moved and hash-verified, 37958 existing raw copies replaced with retained Git
recovery, and 13 earlier missing trailer duplicates accounted for
without reclaimed-space credit. The latter had already been proven identical
to retained main/Git bytes before this migration. Recovery covers 3492
distinct retained raw Git blobs, independently read and SHA256-checked.

Certified removed-copy allocation: 7755960592 bytes. Same-volume private moves
preserve their allocation; this number does not count them as freed space or
include unrelated volume changes. The original folder was removed only by
deepest-first empty-directory operations after every file was accounted for.

The recovery helper's eleven disposable fixtures run with
`python tools/tests/restore_reconciled_copy_test.py`; they cover exact Git
bytes, private streams, long paths, corruption, refusal to overwrite, and
failure cleanup before publishing a restored filename. Migration safety was
separately checked with seven disposable C fixtures, including protected-handle
identity/hash verification, private NTFS moves and interrupted journal recovery.
