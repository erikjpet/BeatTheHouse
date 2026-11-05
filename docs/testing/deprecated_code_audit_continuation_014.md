# Audit continuation014 — checkpoint draft

Root-reviewed checkpoint at helper commit `5e9e06bd32452758dbc4d3a4a01f77be23b76244`. The whole audit, content timeout, maintained Systems acceptance, schema repair, memo type safety and persistence reduction remain **Open**. No fresh full Systems or whole-content pass is claimed.

The source change at this checkpoint is the two-tool helper commit `5e9e06bd32452758dbc4d3a4a01f77be23b76244`. Owner SHA is `cfe62ffaaf1c7ddb1deae75bc0122e6dcb195003074b60cd9d190008b4a746ce`; test SHA is `8f0021eedd6f969a7fd13897b793b44ae3177613f5496e135bbdbf72c121503b`. Game `.gd` source is unchanged. Canonical Schema remains `780b974bd5c870839fb3620e501e18d528c93c446806ba04136028bfb9187a7c`; temporary RunState and Generator observers were restored to their original bytes. The independent storage analysis verifies all 1,243 expected source pins, including exactly the adopted two-tool delta.

## Closed phase014 receipts

These are five **historical phase014 Jobs**, all finished with `active_at_release=0`, assignment before execution, a 180-second deadline, 12% aggregate CPU, 2 GiB Job memory, kill-on-close and no breakaway. Four exited0. The preserved r1 counterexample attempt failed parsing before tests; it is not counted as a passing diagnostic.

| Native Job | Outcome |
|---|---|
| `schema014-counterexamples-r1` | Preserved parse failure; `script_error=true`, exit field null, active0 |
| `schema014-counterexamples-r2` | Exit 0; 39 expected-counterexample checks; active0 |
| `catalog014-schema-observer-r1` | Exit 0; 831 checks,55 records; active0 |
| `storage014-baseline-r1` | Exit0;612 serialized-report checks /616 final checks; active0 |
| `storage014-profile-r1` | Exit0;609 serialized-report checks /613 final checks; active0 |

A later separate private `catalog015-material-path-differential-r1` also closed with exact180/12%/2GiB guards and active0. It passed1,133 comparisons across55 definitions and13 edge cases. Its production qualification remains Open; the five historical phase014 receipts retain their separate attribution scope. No global process census is claimed.

## Schema attribution and existing memo defect

The completed observer retains all 55 scenarios in original source order. Its 165 canonical/original/observed calls produced identical complete ordered error arrays and unchanged inputs. There are 1,595 trace events in 55 contexts, with all frames closed. Each receiver recorded 55 full validations and zero successful entries or hits: these are unbound definitions using the default empty target inventory, not successful memo-hit measurements.

| Root sibling span | Total seconds |
|---|---:|
| Aftermath | 5.070155 |
| Calculated signature | 0.662007 |
| Phase graph | 0.325438 |
| Executable-string rejection | 0.153427 |
| Shape bounds | 0.144392 |
| Memo key | 0.107854 |

Aftermath is 75.36% of the 6.727572-second observed outer validation frames in this population. The 809 errors per receiver consist of 749 declared-target errors, six cross-reference errors and 54 aftermath errors; all 54 aftermath additions belong to `corner_store_delivery_day`. This identifies the next measured owner, without asserting a production bug or current Systems dominance.

Nested values stay separate: signature-normalization **prefix** 0.453750s is inside calculated signature; Registry identity 0.014784s, handler copies 0.008007s, operation copies 0.000972s and empty-inventory authority projection 0.002065s are inside memo-key preparation. Do not add parents and children. Private Schema copies have separate Script identity and memo pools, and observer logging contributes to enclosing timings. See schema analysis (`evidence/catalog014-schema-observer-proposal/independent-schema-analysis-r1.json`) and independent observer review (`evidence/catalog014-schema-observer-proposal/independent-observer-review-r1.json`).

A separate canonical 39-check diagnostic reproduces **existing successful-memo false acceptance** for StringName (Variant 21) and PackedStringArray (Variant 34). Each colliding alternative is rejected cold, shares the existing JSON memo key with a valid fixture, then returns no errors on a warm hit. Typed `Array[String]` is a valid control. Exit0 means the expected counterexamples were reproduced, not that validation is correct. R1's invalid typed-preload `resource_path` observations and failure receipt remain preserved; additive r2 corrects only those diagnostic observations. Result (`evidence/schema014-counterexamples-r2/result.json`), independent analysis (`evidence/schema014-counterexamples-r2-independent-analysis-r1.json`).

## Bounded owner helper qualification

The committed helper permits only guards-family recipes with exact integer 180 or 330; bool, float and other values reject. Receiver allowlists, runner pinning, native resource guards, closure custody and restoration are unchanged. All 36 original fault methods remain and all 40 tests pass. The actual storage 180 pilot has owner exit0, verified active0 closure, guard qualification, exact RunState/Generator restoration and all 1,243 expected pins matching. Unit receipt (`evidence/own14-unit-r1/result.json`), actual owner receipt (`evidence/storage014-owner-r1/owner.json`).

`BTH061-AUDIT-SOURCE-OWNER-DEADLINE-014` alone is Complete with commit `5e9e06bd32452758dbc4d3a4a01f77be23b76244`,40fault tests and actual180-second restoration evidence. Both ledger views record that bounded result; no parent closes. The utility is manual audit tooling; no game or NEXT delivery is associated with this helper change.

## Storage attribution

The independent `evidence/storage014-independent-analysis-r1/cross-source-and-attribution-r1.json`, SHA `b4fa18d945ecd39fb2c18d30bd4172acb81a4a00d8234cef14da5466bb5b87fd`, confirms full off/on and baseline/profile semantic equality and all 100 shared sidecars byte-identical. Baseline has 101 sidecars/artifacts including its additional checkpoint; profile has 100. Both use checkpoint SHA `58ca2024e4054c686b78269caf30a5eb31b81b3288033948b9fa0b4209ccf9d7` and the same known task-private companion hash. No private contents are reproduced here.

The three-check report-count difference is accounted for: baseline checkpoint mint 2 + export 4 versus profile restore 3. Each final report installation adds four checks after serialization, yielding 612/616 and 609/613. This is not silent assertion loss.

The 1,157 events cover 16 selected projection calls in eight contexts, with 984,110 microseconds inclusive projection time. The direct `(deep_copy=true,preserve_runtime_projection=false)` call is 111,659 microseconds; its sibling work includes copy/filter 3,648, game filter 241, refresh 14,773, semantic stripping 6,360, active binding 5,900 and runtime canonicalization 80,280 microseconds. Opaque layout calls 73,358 microseconds are **included** in runtime canonicalization. The layer store projection 117,590 microseconds contains runtime canonicalization 84,729 microseconds, including opaque layout 76,531 microseconds. World-entry projection 52,975 microseconds sits inside world-enter 55,563, body 66,537 and generator-owner 66,636 microseconds; these are a containment chain, not values to sum.

This is one representative Punchline world/layer fixture, not all prior 149 outside calls or a cold-cache/full Systems result. EnvironmentInstance internals remain opaque. Control/profile timings also differ without instrumentation, so these observations do not establish pure observer cost or a performance repair. The earlier defer-clone projection candidate remains rejected, preserved and unapplied.

## Scope and next work

`BTH061-AUDIT-SCHEMA-VALIDATION-014` and `BTH061-AUDIT-MEMO-TYPE-SAFETY-014` remain Open. The invocation-local material-path fingerprint and memo type-safety candidates are evidence-only prototypes at this checkpoint; no production Schema/performance candidate has been applied, and no benefit or acceptance is included. Later prototype results require a separate additive record.

Maintained Systems remains four shards, 55 registered checks, all 220 profiles, 300-second aggregate, actual 43.712-second suite comparator and 330-second outer supervisor. 43.7115 is nominal baseline arithmetic only. The original-order whole-content diagnostic retains 180 seconds. No guard, call, profile or assertion is removed or reordered to obtain a pass. Layer013's required exact NEXT qualification remains separately owned and untouched.

All eight explicitly paused feature IDs remain unchanged: `BTH-11`, `BTH-SCENARIO-WEDDING-001`, `BTH-SCENARIO-ARRIVAL-002`, `BTH-15`, `BTH-17`, `BTH-15-FACTUAL-HELP-001`, `BTH-17-FACTUAL-HELP-001`, and `LEDGER022`. There is no cleanup; originals, failed runs, traces, sidecars and rejected proposals remain.

Passing local headless runs record the known Windows/Godot “Failed to read the root certificate store” line. It is retained as an environmental diagnostic, not certificate/network acceptance, and is distinct from r1's actual GDScript parse failure.

Continue qualifying narrow candidates with full ordered typed/state/RNG/authority/save compatibility under unchanged limits, and continue the measured storage owners. Parent audit and aggregate acceptance remain Open. Exact source, freeze, independent-proof and receipt hashes are in the accompanying [JSON report](deprecated_code_audit_continuation_014.json).

An additional original-Schema key-cost baseline passed94checks with198keys and32 actual positive validation hits. Raw55 first keys averaged1,550.964 microseconds;110 repeats averaged1,526.109. Positive validation hits averaged777.938 microseconds with1full run/32hits/1entry. This establishes the comparison baseline for the proposed safety repair, without a candidate cost claim. That seventh known owned Job also finished under180/12%/2GiB with active0. Its wrapper bootstrap head label is null; exact source pins, actual Script hash and Job head remain retained and authoritative.

Manual reconciliation reports zero findings for this audit, with78 current /544 all-scope findings and54 runtime findings outside this work. The inventory contains156 records; the prior149 are unchanged. Both ledger views preserve all paused feature entries and Layer013 delivery scope.
