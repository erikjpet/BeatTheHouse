# Code Health Audit and Remediation Plan

**Baseline commit: `4384378a00d2e81e259aa28ae01ffbbc7cf21fd5`**
(`4384378a` - 2026-09-19 22:53:53 -0500 - "Rework crew deliveries and persist
venue situations")

Audit date: 2026-09-20
Re-verified against the live working tree: 2026-09-20, twice - after
`fixsweep06_1` Waves 1-6, and again after **all nine waves** landed with only
its Final verification row open (see section 0.1).
Change policy: **diagnostic only** - no product code, data or tooling was
modified while producing this report.

---

## 0.1 Re-verification status

Every finding was re-checked against the live working tree after the fix sweep
reached Waves 1-9 `DONE` (Final verification still `TODO`). Results:

| Outcome | Findings |
| --- | --- |
| **Still live, unchanged** | CH-01, 04, 05, 06, 07, 08, 10, 11, 12, 13, 14, 17, 18, 20, 21, 22, 28, 29, 32, 33, 34, 35, 36 |
| **Still live, anchors moved** | CH-02, 09, 16, 19, 23, 24, 26, 27, 30, 31 |
| **Resolved by the sweep** | CH-03 (Wave 6), CH-25 (Wave 3) |
| **Withdrawn - my error** | CH-15 |

Eighteen of the files this report cites are byte-identical to the baseline, so
their findings and line numbers stand exactly as written:
`profile_inventory.gd`, `meta_collection_service.gd`,
`developer_placement_store.gd`, `persistence_paths.gd`,
`world_sequence_package_catalog.gd`, `item_effect.gd`, `environment_hours.gd`,
`run_terminal_evaluator.gd`, `card_shoe.gd`, `rng_stream.gd`,
`collection_item_resolver.gd`, `collection_drop_service.gd`,
`environment_runtime_scheduler.gd`, `platform_services.gd`,
`cage_economy_model.gd`, `tutorial_flow.gd`, `game_ritual_layout.gd`,
`crew_turn_model.gd`.

**The structural census barely moved**, which is the point - the sweep fixed
defects, not structure:

| Measure | Baseline `4384378a` | Live tree after Waves 1-9 |
| --- | --- | --- |
| Production files / lines | 194 / 202,906 | 196 / 204,648 |
| Duplicate function bodies | 68 groups / 201 copies / ~797 lines | **identical** |
| `push_error` + `push_warning`, all production | 21 | 22 |
| `.get("literal")` accesses | 38,171 | 38,288 |
| Doc-commented functions | 785 / 10,405 (7 %) | 7 % |
| Functions with >=6 params | 373 | 374 |
| `foundation_main.gd` lines / member vars | 20,922 / 423 | 21,216 / **429** |
| Dark foundation contracts | 46 of 81 | **46 of 83** |
| Dark root-level sweep contracts | 0 | **5** |

---

## 0. Baseline and reproducibility

Every finding, line number, file size and census figure in this document was
produced against the committed tree at `4384378a`, extracted cleanly with:

```bash
git archive 4384378a | tar -x -C <scratch>
```

Nothing here was measured against a working tree. To reproduce any claim,
extract that commit and re-run the check quoted beside the finding.

**The live working tree has diverged from this baseline** - a separate agent is
executing `docs/todo/fixsweep06_1_extended_playtest_bug_sweep_prompt.md` and had
30 files modified when this report was written. That work is deliberately
excluded from the baseline so this document stays reproducible. Section 2
covers how the two efforts interact.

### Baseline census

| Measure | Value at `4384378a` |
| --- | --- |
| Production files (`scripts/core`, `scripts/ui`, `scripts/games`) | 194 |
| Production lines | 202,906 |
| Production functions | 10,405 |
| ...with return-type annotations | 10,394 (99 %) |
| ...with a preceding doc comment | 785 (7 %) |
| ...returning a bare `Dictionary` | 3,086 |
| ...taking six or more parameters | 373 |
| `.get("literal")` dictionary accesses | 38,171 |
| `push_error` / `push_warning` calls, all production | **21** |
| Exact duplicate function bodies | 68 groups, 201 copies, ~797 redundant lines |
| `scripts/ui/foundation_main.gd` | 20,922 lines, 1,100 funcs, **423 member vars** |
| `scripts/core/run_state.gd` | 17,967 lines, 918 funcs, 101 member vars |
| Foundation contracts reachable from the Contract suite | **35 of 81** |
| `tools/` files | 146 `.gd`, 121 `.ps1`, 18 `.py` |
| ...named after completed task rows | 81 |
| `docs/` markdown files | 427 (`plans` 169, `todone` 232, `todo` 21) |

---

## 1. Method and honest coverage

Two passes produced this report.

1. **Mechanical census over every tracked file** at the baseline commit.
2. **File-by-file reading of `scripts/core`**, followed by a sweep of all 194
   production files against ten defect patterns derived from that reading.

**Every sweep candidate was verified by hand before it was written down.**
Several did not survive; they are recorded in section 4.0 so nobody
re-investigates them.

**What this report does not claim.** `scripts/ui` (73 files) and
`scripts/games` (47 files) were swept mechanically and sampled, but were not
read line by line. Findings naming those directories come from a verified sweep
hit or a targeted read, never an assumption. Section 7 says where to read next.

### Empirical verification performed

Where a claim could be tested rather than argued, it was:

| Claim | Method | Result |
| --- | --- | --- |
| RNG quality | Simulated the exact Park-Miller LCG and the `randi_range` modulo path | Sound - see CH-VERIFIED-1 |
| `fork()` stream independence | 1,600 realistic stream keys x 3 bases; 300 streams x 50 draws | Zero collisions, zero shared values |
| Clock-label minute loss | Parsed every `open_hours` block in `archetypes.json` | Latent only; no live data affected |
| Gate reachability | Transitive `res://` preload walk from the nine Contract entry points | 46 of 81 contracts dark |
| Asset liveness | Filename cross-reference across all code and data | 0 of 258 `assets/` PNGs unreferenced |

---

## 2. Relationship to `fixsweep06_1`

The 58-defect playtest report (`reports/playtest_2026-09-20/`) and its fix sweep
address **player-visible defects**. This report addresses **structural and
durability defects**, and was produced against the same baseline the playtest
report used.

Overlap is deliberate and small:

- **BTH-039** (oversized save reports success) is the run-save half of what
  CH-01 shows is a project-wide durability gap. Wave 1 fixed the run save; this
  plan fixes the other four stores and unifies all five.
- **BTH-048** (audio caches never evict) - Wave 6 closed it, and re-verification
  showed the rest of CH-15 was my own error. CH-15 is withdrawn.
- **BTH-050** (malformed settings silently discarded) - Wave 6 closed it, so
  CH-03 is resolved. **CH-04 is not**, and it is the more dangerous half: the
  recovery path Wave 6 added is still reachable only if the typed assignment on
  `user_settings.gd:157`/`:167` does not fail first.
- **BTH-022/023** (Bar Dice overlaps) - Wave 3 closed it and CH-25 with it. The
  general rule it implies is still unenforced.
- **BTH-057/058** (clock format, plural grammar) - Wave 7 created
  `scripts/ui/player_text.gd`, which **upgrades** CH-09 from a latent
  single-formatter defect to a live divergence between two formatters.

Sequencing is in section 5. The short version: with all nine sweep waves
landed, **every phase except the god-object work (CH-26) is unblocked**; CH-26
waits for the sweep's Final verification row, because it restructures the two
files that verification is most likely to touch.

---

## 3. The improved system

Nine components. Each replaces a repeated ad-hoc pattern with a single owner,
so most individual fixes in section 4 become "call the new component" rather
than "patch this site".

### 3.1 `DurableStore` - one atomic, validated, backed-up JSON store

**New file:** `scripts/core/durable_store.gd`

At the baseline the project has **five** JSON persistence implementations of
four different strengths:

| Store | `get_error()` | Temp validated | Backup kept | Primary safe on failed rename |
| --- | --- | --- | --- | --- |
| `save_service.gd` (run save) | yes, `:60` | **no** | yes, `:74-78` | yes - rotated to `.bak` first |
| `profile_inventory.gd` | **no** | **no** | **no** | **no** |
| `meta_collection_service.gd` | **no** | **no** | **no** | **no** |
| `developer_placement_store.gd` | **no** | **no** | **no** | n/a (no rotation) |
| `user_settings.gd` | **no**, and no `close()` | **no** | **no** | n/a |

The run save is the strongest and, at baseline, still lacked temp-payload
validation - that gap is report finding BTH-039, **which sweep Wave 1 has since
closed**, so the live `save_service.gd` now validates the temp payload before
rotating. The other four stores are unchanged. Build
`DurableStore` as the *union* of the strongest behaviour from each, then delete
the other four implementations.

Reference material at baseline: `save_service.gd:49-88` (`save_run`),
`:196-230` (`_write_payload_atomic`), `:233-248` (`_worker_payload_loadable`),
`:256-277` (`load_run`, primary-then-backup).

Target API:

```gdscript
class_name DurableStore
extends RefCounted

# Result shape shared with every other fallible boundary (see 3.2):
# { ok, error, error_code, outcome, data }

static func write_json(path: String, payload: Dictionary, validator: Callable = Callable()) -> Dictionary
static func read_json(path: String, validator: Callable = Callable()) -> Dictionary
static func backup_path(path: String) -> String
static func status(path: String) -> Dictionary
```

`write_json` must perform, in order:

1. `make_dir_recursive_absolute` on the parent; return on error.
2. Open `<path>.tmp`; return `FileAccess.get_open_error()` on null.
3. `store_string(JSON.stringify(payload))`.
4. **Check `file.get_error()`**, then `close()`. On error remove the temp and
   return `ERR_FILE_CANT_WRITE`.
5. Re-read the temp and run `validator` (default: parses to a Dictionary). On
   failure remove the temp and return `ERR_FILE_CORRUPT` with
   `error_code = "temporary_generation_invalid"`.
6. **Only now**, if a primary exists and is itself valid, rotate it to
   `<path>.bak`. If it exists and is invalid, delete it.
7. `rename_absolute(temp, primary)`.
8. Re-validate the installed primary; on failure report
   `error_code = "installed_generation_invalid"`.

`read_json` tries primary, then `.bak`, reporting which through `outcome`
(`loaded-primary`, `loaded-backup`, `nothing-loadable`), mirroring
`SaveService.last_load_outcome`.

**The invariant:** no code path may delete or overwrite a valid generation
before a replacement exists and has been validated on disk.

### 3.2 `IoResult` - one fallible-boundary contract

**New file:** `scripts/core/io_result.gd`

The `{"ok": ...}` dictionary is already the de facto convention - `"ok"` appears
1,721 times in production, `"message"` 1,189, `"status"` 411, `"reason"` 224,
`"error_code"` 75, `"error"` 95 - but nothing validates it and names drift.

```gdscript
class_name IoResult
extends RefCounted

const KEY_OK := "ok"
const KEY_ERROR := "error"
const KEY_ERROR_CODE := "error_code"
const KEY_MESSAGE := "message"

static func ok(extra: Dictionary = {}) -> Dictionary
static func failed(error: Error, error_code: String, message: String = "", extra: Dictionary = {}) -> Dictionary
static func is_ok(result: Dictionary) -> bool
static func assert_shape(result: Dictionary) -> Array[String]   # debug builds only
```

Adopt at fallible boundaries first - `DurableStore`, `UserSettings.load`,
`RunActionService`, `GameModule.apply_result` - never as a global sweep.

### 3.3 `JsonCoerce` - remove 201 copies of seven helpers

**New file:** `scripts/core/json_coerce.gd`

The baseline holds 68 groups of byte-identical function bodies, 201 copies,
about 797 redundant lines. The largest groups are all the same JSON coercion
helpers:

| Helper | Copies | Representative baseline sites |
| --- | --- | --- |
| `_copy_dict()` | 13 | `baccarat.gd`, `game_module.gd`, `event_module.gd` |
| `_copy_array()` | 11 | `attribute_badges.gd`, `item_effect.gd:206`, `profile_inventory.gd` |
| `_dictionary_array()` | 10 | `blackjack.gd`, `numbers_model.gd`, `town_state.gd` |
| `_string_array()` | 10 | `foundation_main.gd`, `pixel_scene_canvas.gd`, `world_map.gd` |
| `_stable_hash()` | 6 | `bar_dice.gd`, `police_sweep_model.gd` |
| `_valid_sha256()` | 4 | all four `scenario_*` files |
| `_int_array()` | 3 | `baccarat.gd`, `bar_dice.gd`, `pull_tabs.gd` |

Provide canonical `static` versions. Put the game-facing subset on `GameModule`
itself - all eleven games already extend it, so call sites need no import.

Add `coerce_enum`, which exists nowhere today and is the direct fix for CH-04:

```gdscript
static func coerce_enum(value: Variant, allowed: Array, fallback: String) -> String
```

### 3.4 `StaticDataCache` - a bounded, shared, static cache convention

**New file:** `scripts/core/static_data_cache.gd`

31 dictionary caches are written to and never erased. Most are keyed by file
and bounded in practice. Four are keyed by dynamic runtime values and are
genuinely unbounded (CH-15). One that should be static is not:
`collection_item_resolver.gd:44` declares `var _loaded := false` per instance,
so every resolver re-parses a 2,041-line JSON (CH-11).

```gdscript
class_name StaticDataCache
extends RefCounted

func _init(max_entries: int = 64, max_bytes: int = 0) -> void
func get_or_load(key: String, loader: Callable) -> Variant
func evict(key: String) -> void
func clear() -> void
func stats() -> Dictionary   # entries, bytes, hits, misses, evictions
```

`content_library.gd:44-50` already implements this correctly with
`_music_wav_info_cache`, a `_cache_order` array and hit/miss counters. Lift that
implementation rather than inventing one.

### 3.5 `GameModuleRegistry` - stop instantiating games to ask questions

**New file:** `scripts/core/game_module_registry.gd`

Two parts:

1. A registry caching one configured module per `(module_path, definition_id)`.
2. **Static capability queries** so the common questions need no instance:

```gdscript
static func definition_declares_recovery_hook(definition: Dictionary) -> bool
static func definition_defers_bankroll_zero(definition: Dictionary) -> bool
```

Prefer (2) wherever the answer is derivable from `data/games/games.json`; fall
back to (1) only where live run state genuinely matters.
`run_generator.gd` already holds a `_game_module_script_cache`; the registry
should absorb it so there is one owner.

### 3.6 `RunStateSchema` - declarative serialization with an enforced symmetry gate

**New file:** `scripts/core/run_state_schema.gd`

At baseline `RunState.to_dict()` writes 73 fields and `from_dict()` reads 71,
maintained by hand about 250 lines apart, with no schema and no assertion that
they match. Declare the field table once and drive both directions from it,
keeping the hand-written compaction and exact-integer cases as explicitly
registered transforms. Gate in 6.3.

### 3.7 Scoped telemetry instead of duplicated hot paths

Replace the duplicated `_process()` body (CH-16) with a no-op sink so there is
one code path:

```gdscript
# perf_telemetry_overlay is never null; a NullPerfSink records nothing.
perf_telemetry_overlay.begin_foundation_frame()
_timed("layout", _apply_run_screen_layout)
_timed("environment_runtime", _advance_run_game_clock.bind(delta))
```

`_timed` reads the clock only when the sink is live, so the un-profiled path
loses its branch entirely.

### 3.8 Standalone contract runner - restore 57 % of the contract suite

Add to `tools/check_godot.ps1`:

- A `standalone_contracts` stage enumerating `scripts/tests/foundation/*.gd`
  whose first line is `extends SceneTree` and which no split runner preloads,
  running each with `--headless --script`.
- Narrow both exclusions (`check_godot.ps1:831` load check,
  `:1272` exhaustive parse) from a directory prefix to the explicit nine-file
  list named at `:266-275`.

### 3.9 Repository custody conventions

- `tools/archive/<row-id>/` for one-shot, row-scoped probes.
- `docs/archive/<version>/` for completed-row plans and evidence.
- A `.tmp/` retention sweep; the rotation helper at `check_godot.ps1:359`
  already sorts by `LastWriteTimeUtc` and simply never deletes.

---

## 4. Findings and prescribed fixes

Severity: **P1** data loss or player-visible incorrect behaviour ·
**P2** measurable performance or reliability cost ·
**P3** maintainability, clarity or hygiene.

All line numbers are at baseline `4384378a`.

### 4.0 Verified sound - do not spend time here

**CH-VERIFIED-1 - `scripts/core/rng_stream.gd` is statistically sound.**
The Park-Miller LCG (`A=48271`, `M=2^31-1`, `rng_stream.gd:6-7`) was simulated
exactly as `randi_range` consumes it (`:39-46`):

- Coin flips (`randi_range(0,1)`, the generator's weakest low bit): ones at
  0.4991-0.5002 across three seeds; all four serial pair frequencies ~0.25.
- d6 over 600,000 draws: 0.1662-0.1676 against 0.16667 expected.
- Two dice, 36 outcomes over 400,000: 0.0265-0.0288 against 0.0278.
- `derive_seed()` (`:84-91`): 1,600 realistic `fork()` keys against three bases
  produced zero collisions; 300 forked streams x 50 draws produced zero shared
  values.

Modulo bias exists in theory because no span divides `2^31-1`, but it sits
below measurement noise at production sample sizes. **Not a defect. Do not
replace the generator.**

Also verified correct and deliberately left alone:

- `card_shoe.shuffle_cards()` `:26-39` - a correct Fisher-Yates.
- `cage_economy_model.gd` - pure, total, well-factored; the model to copy.
- `environment_hours` overnight wrap and operating-cycle day attribution.
- `crew_turn_model._private_install_key()` - race-aware, unique temp name with
  pid and ticks, refuses to replace a valid key, sets `0600` on POSIX.
- `blackjack.gd:751` clamps `selected_stake` with
  `clampi(selected_stake, effective_floor, effective_stake_ceiling)`.
- `crew_poker_model.split_pot()` `:572-582` guards `winner_ids.is_empty()`
  before dividing.

**Discarded sweep candidates** (checked, false positives): five of six
"never-incremented counters" are assigned normally; the divide-by-`size()`
sweep matched `%d` format specifiers rather than modulo; `crew_turn_model`
never deletes a primary generation.

---

### 4.1 Cluster A - Durable persistence (P1)

> Run first, independently of `fixsweep06_1`. Touches `profile_inventory.gd`,
> `meta_collection_service.gd`, `developer_placement_store.gd`,
> `user_settings.gd`, `persistence_paths.gd` - none of which the sweep names.

#### CH-01 (P1) - All permanent progression is less durable than a single run

**Evidence.** `profile_inventory.gd:65-81` and
`meta_collection_service.gd:102-122` both perform:

```gdscript
var file := FileAccess.open(temp_path, FileAccess.WRITE)
if file == null:
    return FileAccess.get_open_error()
file.store_string(JSON.stringify(to_dict(), "\t"))   # :75 / :116 - error never checked
file.close()                                          # :76 / :117
if FileAccess.file_exists(absolute_path):
    var remove_error := DirAccess.remove_absolute(absolute_path)   # :78 / :119 - deletes the good file
    if remove_error != OK:
        return remove_error
return DirAccess.rename_absolute(temp_path, absolute_path)         # :81 / :122
```

`grep -n "bak\|backup"` returns **nothing** in either file. The run save
rotates its primary to `.bak` (`save_service.gd:74-78`) before deleting it;
these two delete with no backup in existence.

At stake in `user://profile_inventory.json` (`PROFILE_STORAGE_KEYS`,
`profile_inventory.gd:13-19`): `items`, `challenge_completions`, `run_history`,
`daily_runs`, `lifetime_stats`, `act_seam`,
`scratch_ticket_types_discovered`, `tips_seen`, `tutorial_completed`.
In `user://meta_collection.json`: the entire item-collection meta.

A truncated write, or a rename blocked by antivirus, permissions or a full
disk, silently destroys all cross-run progression - a strictly worse outcome
than BTH-039, which only loses one run.

**Fix.** Replace both `save()` bodies with `DurableStore.write_json()` and both
`load()` bodies with `DurableStore.read_json()`. Surface the returned outcome so
the main menu can report a recovered-from-backup load exactly as the run save
already does.

**Regression.** Per store: induced write failure leaves the prior file
byte-identical; induced rename failure leaves it byte-identical; a corrupt
primary loads from `.bak`; a save reported `ok` is re-readable from a fresh
instance. Name the debug hooks after the existing precedent on `RunSaveCodec`
(`debug_force_compression_failure`, `debug_storage_byte_limit_override`).

#### CH-02 (P2) - Five of six production writes never check their error

| File | `store_string` | `close()` | `get_error()` |
| --- | --- | --- | --- |
| `save_service.gd` | `:66`, `:205` | yes | **yes, `:67` / `:206`** |
| `developer_placement_store.gd` | `:156` | yes | no |
| `meta_collection_service.gd` | `:116` | yes | no |
| `profile_inventory.gd` | `:75` | yes | no |
| `user_settings.gd` | `:77` | **no** | no |
| `perf_telemetry_overlay.gd` | `:3481` | yes | no |

`user_settings.save()` (now `:109-114`) returns `OK` without ever closing the file, so
every "saved" confirmation for settings, developer placements and the profile is
unverified.

**Fix.** Route all six through `DurableStore.write_json()`.

#### CH-03 - ~~`UserSettings.load()` reports nothing~~ - RESOLVED by sweep Wave 6

At baseline, `user_settings.gd:61-68` reset to defaults, called `from_dict()`
only for a dictionary root, and returned `void`.

**Re-verified: fixed.** `load()` is now `func load() -> Dictionary` (`:61`) and
routes malformed input through `_recover_invalid_settings_file()` (`:87`) with
`malformed_json` (`:79`) and `invalid_schema` (`:82`) outcomes. That is report
finding BTH-050, closed in Wave 6.

**No work required.** When `DurableStore` lands (Phase 0), fold this existing
recovery path into it rather than rewriting it - it is already the shape
`IoResult` wants.

#### CH-04 (P1) - Malformed settings can hard-fail instead of clamping

**Evidence.** `user_settings.gd:121` and `:131`:

```gdscript
window_mode = data.get("window_mode", window_mode)   # :121, member declared String
text_size   = data.get("text_size",   text_size)     # :131, member declared String
```

Four lines later the sibling field is written defensively:

```gdscript
drunk_effect_mode = str(data.get("drunk_effect_mode", drunk_effect_mode))   # :135
```

so this is an inconsistency, not a house style. A `settings.json` containing a
*number* for either field is expected to hit a typed-assignment failure rather
than the intended clamp-to-default on the following line.

**Fix.** `JsonCoerce.coerce_enum(data.get("window_mode"), WINDOW_MODES, "windowed")`,
same for `text_size` against `TEXT_SIZES`. Audit every other `from_dict` with
the sweep in 6.2.

**Regression.** Load settings containing a number, an array and a null for each
enum field; assert defaults applied, no error, no crash. This is the concrete
test BTH-050 lacked.

#### CH-05 (P3) - Developer placement writes report success unconditionally

`developer_placement_store.gd:155-158` - `store_string`, `close()`,
`return OK`. `save_position()` (`:198-221`) and `clear_position()` (`:223-238`)
build their `{"ok": save_error == OK}` from that unconditional `OK`.

**Fix.** `DurableStore.write_json()`. Behaviour otherwise unchanged.

#### CH-06 (P3) - `PersistencePaths` accepts an unvalidated environment root

`persistence_paths.gd:16-21` - `BTH_DISTRIBUTION_DATA_ROOT` sets the save root
with only `strip_edges()` and `trim_suffix("/")`.

**Fix.** Reject a root that is empty after normalisation, is neither absolute
nor a `user://` path, or contains `..`. Keep the test-isolation capability.

---

### 4.2 Cluster B - Correctness defects

#### CH-07 (P2) - Package validation bounded by an unrelated quantity

`world_sequence_package_catalog.gd:31`:

```gdscript
if typeof(parsed) != TYPE_ARRAY or (parsed as Array).is_empty() \
        or (parsed as Array).size() > PACKAGE_PATHS.size():
    return {}
```

The number of packages permitted in a JSON file is bounded by the size of the
*path map* (currently 10). Adding an eleventh id silently loosens the limit; a
legitimate file with more entries is silently rejected.

Separately, `FileAccess.get_file_as_string()` at `:30` returns `""` on any IO
failure, so `JSON.parse_string("")` yields null and the function returns `{}` -
making a missing or corrupt package file indistinguishable from an unknown id,
with no `push_error`.

**Fix.** Replace the bound with an explicit `MAX_PACKAGES_PER_FILE`, or drop it
and validate `package_id` membership only. Separate "file unreadable" from "id
not found" in the return and `push_error` the former. Reduce the three deep
copies per cold call to one.

#### CH-08 (P2) - Conflicting item-effect types can crash the merge

`item_effect.gd:196`:

```gdscript
target[key] = target.get(key, 0) + value
```

If an earlier source set `target[key]` to a Dictionary or Array - which the
adjacent branches of the same function do - and a later source supplies a number
for that key, this evaluates `Dictionary + int`. Latent, driven entirely by
`data/items/items.json` content.

**Fix.** Guard the accumulate: if the existing value is non-numeric, either
overwrite deliberately or record a validation error. Add the key-type conflict
to `ContentLibrary`'s item validation so bad data fails at load, not at use.

#### CH-09 (P2, upgraded) - Two clock formatters now disagree

**Upgraded on re-verification from P3-latent to P2.** The sweep's Wave 7 work
created `scripts/ui/player_text.gd`, the canonical player-text boundary, whose
`format_time_of_day()` at `:74-80` returns `"%d:%02d %s"` - **it keeps
minutes**. `run_report_view_model.gd:504` and `:1148` now route through it.

`environment_hours.gd:128-135` still returns `"%d %s"` - **it drops minutes** -
and does not reference `PlayerText` at all. It feeds
`status_at().closes_at`/`opens_at` and `travel_status_text()`.

So the project now has two clock formatters with *different behaviour*, one of
which is the newly-established canonical one. That is worse than the single
inconsistent formatter found at baseline.

Still latent in the sense that all six `open_hours` blocks in
`data/environments/archetypes.json` are whole hours, so no live string is wrong
today - but the divergence is now structural.

**Fix.** Route `environment_hours._clock_label()` through
`PlayerText.format_time_of_day()` and delete the local implementation. Add an
assertion that no production file outside `player_text.gd` formats an
AM/PM string.

#### CH-10 (P3) - Two affordability rules for one concept

`run_terminal_evaluator.gd` - `_has_available_travel()` requires
`bankroll - cost > 0`; `_has_available_local_room_travel()` accepts
`cost == 0 or bankroll - cost > 0`. Unreachable today because `bankroll <= 0`
returns earlier, so latent.

**Fix.** One shared `_route_is_affordable(bankroll, cost)` used by both.

---

### 4.3 Cluster C - Hot-path performance (P2)

#### CH-11 (P2) - A 2,041-line JSON is parsed about 16 times on the run-end screen

`collection_item_resolver.gd:44` declares `var _loaded := false` as an
**instance** variable, and `load_definitions()` performs
`FileAccess.get_file_as_string` (`:64`) plus `JSON.parse_string` (`:65`) on
`data/collections/collections.json` (2,041 lines).

`collection_drop_service.gd:438` (`_enriched_marker`) constructs a fresh
resolver on every call, and is invoked inside three loops - `:237`, `:273`,
`:302` - plus from `_roll_bag_marker():352`, which independently constructs
another at `:328`.

A run end with four eligible markers therefore parses that file roughly sixteen
times, on a UI screen. Ten resolver instantiation sites exist project-wide.
`content_library.gd:44-50` and `run_save_codec.gd:520` both use `static var`
caches; this file simply does not.

**Fix.** Make the resolver's definitions a `StaticDataCache` keyed by path, or
at minimum promote `_loaded`, `_root`, `_collections`, `_items_by_itemdef_id`
and `_bags_by_itemdef_id` to `static var`. Hold one resolver in
`collection_drop_service` rather than constructing per call.

#### CH-12 (P2) - Game modules are instantiated to answer booleans

`run_terminal_evaluator.gd:228-241` (`_create_game_module`) does
`load(module_path)` -> `module_script.new()` (`:235`) ->
`game.setup(definition, library)`, and `GameModule.setup()` deep-copies the
definition. It is called per `game_id` from `_has_deferred_bankroll_zero_failure()`
and `_has_game_hook_recovery()` on every terminal evaluation - that is, every
action boundary once bankroll is low or no wager is available. `BlackjackGame`
is 8,636 lines.

`_has_event_recovery()` constructs a fresh `EventModule` per event at `:178`.
`_environment_archetype()` (`:291`) linear-scans
`library.environment_archetypes` and deep-copies the match, with no id index.

**Fix.** `GameModuleRegistry` (3.5), preferring the static capability query so
no instance is built. Add an `archetype_by_id` index to `ContentLibrary`.

#### CH-13 (P2) - The card shoe is deep-copied on every draw

`card_shoe.gd:41-59` (`draw_cards`) calls `.duplicate(true)` per card at `:51`
and `:53`; `card_array()` (`:61-68`) does the same at `:67`. A six-deck
blackjack shoe is 312 cards, so an ordinary draw performs 312 dictionary deep
copies.

**Fix.** Cards are flat `{rank, suit, deck}` records. Copy the array shallowly
and deep-copy only the cards handed out, or treat drawn cards as immutable and
copy neither.

#### CH-14 (P2) - `pick_many()` is an O(n^2) deep-copying shuffle

`rng_stream.gd:55-63` deep-copies the pool at `:56` then calls `remove_at` in a
loop at `:62`. It is used with `count == size`, i.e. as a shuffle, at
`environment_instance.gd:904`, `:982`, `:987` and
`environment_event_resolver.gd:40`.

**Fix.** Add `RngStream.shuffled(values: Array) -> Array` implementing
Fisher-Yates over a shallow copy - the correct implementation already exists at
`card_shoe.gd:26-39`. Keep `pick_many` for genuine partial selection and stop
it deep-copying.

#### CH-15 - ~~Four genuinely unbounded runtime caches~~ - **WITHDRAWN**

This finding does not survive re-verification. Two of the four were fixed by
the sweep; **the other three were my own false positives**, produced by a sweep
that searched only for `.erase(` and `.clear()` and therefore missed three other
ways a cache can be bounded. Recording the detail so nobody re-opens it:

| Cache | Verdict |
| --- | --- |
| `procedural_music_player._feature_stem_cache` | **Fixed** by Wave 6 - `_evict_pcm_cache_key()` (`:514`) with LRU eviction at `:406` and `:506` |
| `web_audio_bridge` `pcmBuffers` | **Fixed** by Wave 6 - `disposePcm` (`:258`) and `clearInactivePcm` (`:272`) |
| `coin_pusher_renderer._delivery_board_cache` | **False positive** - single-entry. Reassigned wholesale at `:1770`, returned at `:1766`/`:1777`. It never grows. |
| `run_state._scenario_sequence_definition_cache` | **False positive** - keyed by the finite 55-scenario catalog and reset with `= {}` at `:494`. My sweep looked for `.clear()`, not `= {}`. |
| `sfx_player._stream_cache` | **False positive** - keyed by *normalized* event ids from `_normalized_event_id()`, a family-mapping over a finite authored vocabulary (95 `.bthsfx` assets). The sibling `_normalized_event_cache` is explicitly bounded at 512 (`:2070`). |

**No work required.** The lesson for 6.2 is real though: a boundedness check
must recognise `= {}` resets, validity flags and finite key vocabularies, not
just `erase`/`clear`. The rule as written in 6.2 would have produced these same
three false positives.

#### CH-16 (P3) - `_process()` is written twice

`foundation_main.gd`, `_process()`. The whole body exists once behind
`if perf_telemetry_overlay == null` (now `:702`, was `:692`) and again with
`Time.get_ticks_usec()` bracketing each of six subsystem calls. The two branches
must be kept in sync by hand, and a divergence is invisible unless profiling is
on. Production contains 398 `Time.get_ticks_usec()` sites.

**Fix.** Section 3.7.

> `foundation_main.gd` is in the sweep's blast radius. Schedule after Waves 4-5.

---

### 4.4 Cluster D - Dead and misleading code (P3)

#### CH-17 - A permanently-zero diagnostic that reads as a health signal

`environment_runtime_scheduler.gd` declares `stale_pop_count` at `:11`, resets
it at `:18`, reports it in `debug_snapshot()` at `:116`, and **never increments
it**. Verified as the only genuine case of six candidates.

**Fix.** Increment it where a stale entry is actually discarded in `take_due()`,
or delete the field and its `debug_snapshot` key. Do not ship a metric that
always reads healthy.

#### CH-18 - Doc comments describing deleted functions

`platform_services.gd:58-59`:

```gdscript
# Pretends to save cloud run data for future adapter parity.
# Reports that no local cloud save exists.
# Accepts an achievement unlock without sending it anywhere.
func unlock_achievement(achievement_id: String) -> Dictionary:   # :61
```

The first two comments document cloud-save functions that were removed; they now
misdescribe `unlock_achievement`.

**Fix.** Delete both lines. Add the orphan-comment rule from 6.2.

#### CH-19 - A dead economic concept surfaced to the UI

`cage_economy_model.gd:10` - `const ORIGINATION_FEE := 0`, never used in any
calculation, yet published as a live field by `run_state.gd:4515` (was `:4475`) and
`scripts/ui/cage_atm_view_model.gd:36`.

**Fix.** Remove the constant and both publications, or implement the fee.

#### CH-20 - Vestigial tutorial API

`tutorial_flow.gd:47` - `apply_caught_transition(run_state, result)` ignores
both arguments and returns `{}` on every path; its guard branch cannot change
the outcome. Still called from production.
`:56` - `repair_legacy_frontier()` is a pure alias for
`repair_legacy_blackjack_count_skip()`, which is save-migration code for "older
builds" that barred the tutorial table.

**Fix.** Delete `apply_caught_transition` and its call sites, keeping the
explanatory comment on whichever type owns the rule. Collapse the alias. Confirm
whether any save in the wild can still reach the legacy migration - 0.5.1 is the
last public release - and delete it if not, recording the decision.

#### CH-21 - Two files written in a different style

`game_ritual_layout.gd` and `crew_turn_model.gd` use single-line
`if cond: statement` bodies throughout, unlike every other file, defeating
line-level diffs and breakpoints.

**Fix.** Reformat to house style in an **isolated commit** so it never hides a
real change.

#### CH-22 - Nineteen orphaned `.gd.uid` files

Untracked and gitignored, left by deleted scripts, including
`scripts/ui/cage_window.gd.uid`, `scripts/core/streets_run_model.gd.uid` and ten
under `tools/`.

**Fix.** Delete. Local-only, zero risk.

---

### 4.5 Cluster E - Test and gate integrity

#### CH-23 (P1) - 46 of 81 contracts never run and are not parse-checked

`tools/check_godot.ps1:266-275` builds the Contract suite from exactly nine
named sources. A transitive walk of `res://scripts/tests/foundation/` preloads
from those nine reaches **37 of 83** files (35 of 81 at baseline). The other
**46 are reachable from nothing** - no suite, no `.ps1` wrapper, not `validate_project.ps1`.

They are not fragments: **45 of the 46 are `extends SceneTree`**, independently
runnable - `world06_4_jobs_model_contract.gd`, `env06_6_full_contract.gd`,
`game06_6_bar_dice_contract.gd`, `craps_full_table_contract.gd` and so on. They
were run once by the task row that authored them, then orphaned.

They are excluded from static checking too: `check_godot.ps1:1272` skips the
`scripts/tests/foundation/` prefix during exhaustive parse, and `:831` passes
`--exclude=res://scripts/tests/foundation` to the load check. Both exclusions
were written for the nine split-runner sources; the blanket prefix also covers
these 46. **They could be syntactically broken right now and no gate would
notice.**

This is the most probable single explanation for how 58 defects reached a
playtest.

**The pattern is still active.** Re-verification found the fix sweep itself
creating five *new* dark contracts while this report was being written, the
fifth arriving with Wave 9:

| New file | Wired into any runner? |
| --- | --- |
| `scripts/tests/fixsweep06_1_accessibility_contract.gd` | **no** |
| `scripts/tests/fixsweep06_1_audio_recovery_contract.gd` | **no** |
| `scripts/tests/fixsweep06_1_lifecycle_contract.gd` | **no** |
| `scripts/tests/fixsweep06_1_packaging_runtime_contract.gd` | **no** |
| `scripts/tests/fixsweep06_1_player_text_contract.gd` | **no** |

`tools/check_godot.ps1` was modified by the sweep (it now isolates
`BTH_DEVELOPER_PLACEMENT_PATH` for gate runs), but neither blanket exclusion was
touched: they now sit at `:837` (load check) and `:1278` (exhaustive parse).

To its credit the same sweep *did* wire its Wave 1-2 work correctly, via
`fixsweep06_1_regressions.gd` preloaded at `check_core_content.gd:37` and
invoked at `:630-631`. So the project knows how to do this - there is simply no
gate that *requires* it, which is exactly the hole this finding names.

**Fix.** Section 3.8. Expect initial failures - several of the 46 were written
against pre-redesign behaviour - and triage each as fix-or-delete rather than
leaving it dark. **Budget real time for that triage; it is the main cost of this
plan.** Include the five new sweep contracts above - 51 dispositions in all.

#### CH-24 (P3) - The test suite is the least maintainable code in the project

Of the 25 longest functions in the repository, 23 are tests:

| Lines | Baseline location |
| --- | --- |
| 4,631 | `scripts/tests/ui_scene/compile_components_and_main_flow.gd:3722` `_run()` |
| 1,501 | `scripts/tests/foundation/check_table_games.gd:3658` `_check_blackjack_surface_contract()` |
| 790 | `scripts/tests/foundation/check_lenders_release_saves.gd:1682` |
| 651 | `scripts/tests/ui_scene/compile_run_menu_and_game_flows.gd:969` |

`failures.append(...)` appears **7,379** times against 236 `_fail(` and 10
`assert(`, so the harness accumulates strings instead of failing at the
assertion site - which is why these functions grew unbounded.

**Fix.** Add `_expect(condition, message, context)` to the shared harness and
split the mega-functions along the `_check_*` boundaries already inside their
bodies. Start with the 4,631-line `_run()`.

#### CH-25 - ~~Table-game collision metadata not exported~~ - RESOLVED by sweep Wave 3

At baseline, `check_table_games.gd:7444-7467` validated `text_panel_rects`
against `patron_safe_rects` while Rail Cups and dealer-station rectangles were
in neither collection - precisely why BTH-022 and BTH-023 shipped.

**Re-verified: fixed.** `bar_dice.gd:3483-3493` now exports
`opponent_panel_rects`, `dealer_station_rects` and a combined
`patron_exclusion_rects`, built by `_bar_dice_opponent_panel_rects()` (`:3507`)
and `_bar_dice_dealer_station_rects()` (`:3514`).

**The general rule still needs recording**, because it is what stops the next
instance: **any rectangle drawn on a game surface must be exported into the
collision metadata the contract tests consume.** Add it to the review checklist
and, ideally, assert it - a game module that draws a panel absent from its
exported rect collections should fail its own contract.

---

### 4.6 Cluster F - Architecture and duplication

#### CH-26 (P2) - Two god objects hold most of the risk

| File | Lines | Functions | Member vars |
| --- | --- | --- | --- |
| `scripts/ui/foundation_main.gd` | 21,216 | 1,121 | **429** |
| `scripts/core/run_state.gd` | 17,995 | 920 | 101 |

Both appear in nearly every finding of the playtest report - arithmetic, not
coincidence.

**The seams are visible in the function names.** `run_state.gd` clusters as
`crew_*` **120**, `grand_*` 62, `scenario_*` 56, `world_*` 32, `delivery_*` 28,
`numbers_*` 12, `sweep_*` 10, `town_*` 7.

**The extraction pattern is already established.** `scripts/core/` contains
seven crew model files - `crew_state_model.gd`, `crew_recruitment_model.gd`,
`crew_heist_model.gd`, `crew_play_model.gd`, `crew_poker_model.gd`,
`crew_turn_model.gd`, `crew_world_sequence_adapter.gd`. The logic already moved
out; only the 120-function facade and its backing fields stayed.
`run_state.gd:8910-8930` is representative - `crew_trust()`, `crew_rank()` and
`crew_add_trust()` are thin delegators over `CrewStateModelScript`.

**Fix, lowest risk first.** Move the `crew_*` facade and its fields into a
`CrewRunFacade` that `RunState` owns and forwards to - a mechanical move of
about 120 functions with no logic change, removing roughly 13 % of the file.
Then `grand_*`, then `delivery_*`. For `foundation_main.gd`, the first cut is
the `sealed_*` cluster (43 functions), already a coherent transaction host.

> **Do this last**, after the sweep lands and its tests are green.

#### CH-27 (P2) - The architecture is stringly typed end to end

38,288 `.get("literal")` accesses; about 3,100 of 10,500 functions return a bare
`Dictionary`; **22** `push_error`/`push_warning` calls in 204,648 lines, so
error paths are overwhelmingly silent returns.

A mistyped key returns the default silently. That is the mechanism behind
several shipped defects, and it means rename refactors and compile-time checking
do nothing across the most important boundaries.

**Fix, incremental.**

1. `IoResult` (3.2) at the `GameModule` / `RunActionService` boundary.
2. Promote the ~40 highest-frequency keys to constants in one `Keys` file so a
   typo becomes a parse error: `id` (1,652 uses), `label` (349),
   `display_name` (313), `archetype_id` (292), `bankroll_delta` (160).
3. Make silent-failure returns `push_warning` in debug builds.

#### CH-28 (P1 risk, P3 effort) - Serialization is hand-mirrored

`run_state.gd` `to_dict()` writes 73 fields; `from_dict()` reads 71, about 250
lines apart, with no schema. Existing tests call
`restored.from_dict(run.to_dict())` - `scripts/tests/collection_meta_check.gd:761`
- but assert on behaviour, never that the field sets match.

**Fix.** Section 3.6 plus the gate in 6.3.

#### CH-29 (P3) - 201 copies of seven helpers

Section 3.3. 68 exact-duplicate groups, ~797 redundant lines. Pure deletion once
`JsonCoerce` exists.

#### CH-30 (P3) - 374 functions take six or more parameters

Worst: `scripts/games/slots/slot_resolver.gd:1689` `_spin_result()` with **17**;
`scripts/core/scenario_layout_resolver.gd:1172` `_authority_record()` with 15;
`scripts/games/slots/slot_renderer.gd:736` with 14;
`scripts/games/blackjack.gd:8308` with 14.

**Fix.** Each is a struct-shaped argument list. Introduce a typed options
dictionary or small value object, starting with the top ten. Removes a whole
class of positional-argument bug.

#### CH-31 (P3) - In-code documentation is inconsistent, not absent

787 of 10,499 production functions (7 %) carry a preceding comment - the ratio
did not move as the sweep added code. The variance is what matters:

| Coverage | File |
| --- | --- |
| 100 % (24/24) | `scripts/core/user_settings.gd` |
| 60 % (28/46) | `scripts/ui/settings_menu.gd` |
| 56 % (66/116) | `scripts/core/game_module.gd` |
| **0 %** (0/155) | `scripts/games/coin_pusher.gd` |
| **0 %** (0/90) | `scripts/games/coin_pusher/coin_pusher_renderer.gd` |
| **0 %** (0/66) | `scripts/core/scenario_host_transaction.gd` |

`user_settings.gd` shows the house style is already defined - one `#` line
stating what the function does.

**Fix.** Require it on public functions in contract-owning files only.
`scenario_host_transaction.gd` at 0/66 is the worst offender given what it
governs. No blanket sweep.

---

### 4.7 Cluster G - Repository and tooling hygiene (P3)

#### CH-32 - `tools/` is an archive of one-shot task artifacts

285 files (146 `.gd`, 121 `.ps1`, 18 `.py`). **81 are named after completed task
rows** - `env06_7_package_a_generate`, `fix06_28_punchline_player_route`,
`game06_3_platform_parity_main`, `integ06_1_*`. 76 `tools/*.gd` have zero
inbound references from any script, wrapper or config.

**Fix.** Move to `tools/archive/<row-id>/`. A move, not a delete - these are
genuine provenance. Leave `check_godot.ps1`, `validate_project.ps1`, the
`foundation_*` probes and the export chain at top level.

#### CH-33 - Documentation and evidence outweigh the product

1,999 of 3,363 tracked files (59 %) are docs or QA evidence: `docs/` 427
markdown files across 1,396 tracked files, `review_artifacts/` 603,
`docs/plans/evidence/` 848, `docs/screenshots/` 119. Product code, data, assets
and scenes together are 923 files. 187 tracked PNGs outside `assets/` are
referenced by nothing.

**Fix.** `docs/archive/<version>/` for completed-row plans and evidence; keep a
small live set.

#### CH-34 - `branding/` is 68 % of the repository by bytes

| Tracked | Size |
| --- | --- |
| `branding/` | **388 MB** (of which `current_in_game_music_playlist` is **327 MB in 46 files**) |
| `review_artifacts/` | 117 MB |
| `assets/` (actual game content) | 63 MB |
| `docs/` | 32 MB |
| `scripts/` | 21 MB |

Tracked `.wav` totals 357 MB across 55 files - uncompressed 12 MB renders, one
per room, of music the game generates procedurally at runtime. The trailer adds
54 MB. `.git` is **816 MB**, and every clone pays for it permanently.

**Fix.** Decide whether reference renders and trailer masters belong in git
versus a release store or Git LFS. At minimum stop committing new revisions of
12 MB WAVs. This is a workflow judgement, not a defect.

#### CH-35 - `.tmp/` has grown 340x with no retention policy

46 GB, against the 136 MB that `docs/plans/dead_code_audit_report.md` recorded on
2026-07-01. Correctly gitignored, so the repo is unaffected, but every gate run,
probe, soak and visual capture writes there and nothing prunes.

**Fix.** A retention sweep keeping the last N runs per stage. The rotation
helper at `check_godot.ps1:359` already sorts by `LastWriteTimeUtc` and simply
never deletes.

#### CH-36 - No linter or formatter configuration exists

No `.editorconfig`, no `gdlint`/`gdformat`, no pre-commit hook - re-verified as
still absent. Style is held by discipline alone, which has worked but does not
scale past one author. (`project.godot` did gain an `[input]` section at `:31`
from sweep Wave 4 / BTH-038, unrelated to this finding.) Related:
preload constant naming is 98 % consistent (1,277 `...Script`, 59 `...Scene`)
with about 20 stragglers (`Kit`, `Model`, `Registry`, `Renderer`, `Catalog`,
`Fidelity`).

**Fix.** Add `gdlint` configuration matching the existing style - tabs, one
blank line between members, two between functions - and wire it into
`validate_project.ps1`. Normalise the stragglers in the same pass.

---

## 5. Execution sequence

| Phase | Work | Findings | Depends on | Risk |
| --- | --- | --- | --- | --- |
| 0 | `DurableStore`, then Cluster A | CH-01, 02, 04, 05, 06 (CH-03 resolved) | none - touches no file the sweep names | Low |
| 1 | Standalone contract runner + narrowed exclusions | CH-23 | none | Low, but triage cost is real |
| 2 | `JsonCoerce` + `StaticDataCache` + dedup | CH-29, CH-11 (CH-15 withdrawn) | Phase 0 | Low |
| 3 | Correctness defects | CH-07..CH-10 | Phase 2 | Low |
| 4 | Hot-path performance | CH-12..CH-14 | Phase 2 | Medium |
| 5 | Dead and misleading code | CH-17..CH-22 | none | None |
| 6 | Declarative serialization + symmetry gate | CH-28 | Phase 2 | Medium |
| 7 | `IoResult` at money boundaries | CH-27 | sweep Wave 1 | Medium |
| 8 | Scoped telemetry | CH-16 | sweep Waves 4-5 | Medium |
| 9 | Test harness split | CH-24 | Phase 1 | Low |
| 10 | God-object extraction: `crew_*`, then `grand_*`, `delivery_*`, `sealed_*` | CH-26 | **entire sweep complete** | High |
| 11 | Hygiene: archives, retention, linter, params, docs | CH-30..CH-36 | none | None |

**Phases 0 and 1 may start immediately. Phase 10 must not start until
`fixsweep06_1` is finished.**

---

## 6. New permanent gates

### 6.1 Durable-store contract

For every store (`run`, `profile`, `collection`, `developer_placements`,
`settings`): induced write failure preserves the prior file byte-for-byte;
induced rename failure preserves it byte-for-byte; a corrupt primary loads from
`.bak`; a save reported `ok` is re-readable from a fresh instance; a failed save
leaves no trusted fingerprint.

### 6.2 Static source rules, added to `validate_project.ps1`

- No `store_string(` without a `get_error()` check within three lines.
- No `remove_absolute(` on a primary path before a validated rename.
- No raw `data.get(` assigned to a typed `String`/`int`/`float`/`bool` member in
  a `from_dict`.
- No `var _loaded` instance flag in a file that also calls `JSON.parse`.
- Cache-boundedness: a dictionary cache must be bounded by an entry budget, a
  `= {}` reset, a validity flag, or a finite authored key vocabulary. **Do not
  check only for `erase`/`clear`** - that formulation produced three false
  positives in this very audit (see withdrawn CH-15).
- No doc-comment block immediately preceding a `func` whose name it does not
  mention (catches CH-18).
- No counter declared and reported in a `debug_snapshot` that is never
  incremented (catches CH-17).

These are the exact sweeps used to produce this report; they need moving into
the validator, not inventing.

### 6.3 Serialization symmetry gate

Assert that the key set written by `RunState.to_dict()` equals the key set
consumed by `from_dict()`, and round-trip a fully populated `RunState` asserting
deep equality. Extend to `UserSettings`, `ProfileInventory` and the meta
collection store.

### 6.4 Standalone contract stage

Section 3.8. Every `extends SceneTree` contract under
`scripts/tests/foundation/` that no split runner preloads must run in the
Contract suite, and the parse/load exclusions must name the nine split-runner
sources explicitly rather than the directory.

---

## 7. Where to read next

`scripts/ui` (73 files, 69,204 lines) and `scripts/games` (47 files, 64,672
lines) were swept mechanically and sampled, not read line by line. Based on
pattern density in `scripts/core`, prioritise:

1. **`scripts/games/*`** - these own money. The wager-intake sweep produced 30
   candidates; the two checked (`blackjack.gd:6839` patron wagers,
   `crew_poker_model.split_pot`) were both properly guarded, but 28 remain
   unverified.
2. **`scripts/ui/procedural_music_player.gd`** (6,428 lines) and
   **`sfx_player.gd`** (3,222) - both hold unbounded caches.
3. **`scripts/ui/pixel_scene_canvas.gd`** (7,190 lines) - the label and
   hit-region owner behind a large share of the playtest findings.
4. **`scripts/games/coin_pusher/coin_pusher_solver.gd`** - 41 lines at six or
   more indent levels, the deepest nesting in the project.

---

## 8. Worker prompt

The executable prompt for this plan is
`docs/todo/health06_1_code_health_remediation_prompt.md`.
