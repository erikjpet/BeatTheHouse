# Scenario inventory seals across native and Web

Qualification dates: 2026-11-10/11. This independently generated compatibility defect is separate from the unavailable original Gas scratcher incident save. It does not establish that incident's cause.

## Candidate identity and scope

Source base: `85d38b96a3c2b1d47020dd6e5a6c4bb12605ca0f`.

- `scripts/core/run_state.gd`: SHA-256 `afb14ac626b82e26f616d655e9a34a535ca1a2e6ad7e228f4e120fab6489efd3`.
- `scripts/core/environment_semantic_inventory.gd`: SHA-256 `d9f3bd5d88205752fe3edc0747d560a5f59072ce488c203de01e51f27948eede`.
- Exact final Web PCK: SHA-256 `dfc34142bfd347d088d209e5d0f791da1d44d56c25b16883ec7baea6b54cf5d5`. Two-file before/after source snapshots are in `gas-cross-platform-candidate2-pack-20261110/evidence/candidate-source.json`.

All evidence paths below are relative to `E:/CodexQA/BTH/runs`. Original synthetic primary/authority companions remain unchanged outside the repository. Tests used disposable storage/profile copies and hash receipts. No save or authority key is included in the change. The original producer recorded an authored scenario pin and explicit already-visited stocked-room inputs before seals; these are not natural-first-visit or original-personal-campaign fixtures.

## Two observed boundaries

1. Day-1 native inventory validates on Web, but rebuilding authored Nell geometry changes normalized x from `0.784444444444445` to `0.784444444444444`. Exact source comparison then rejects an otherwise identical room seal.
2. The native Open / 04:00 inventory has Nell x bytes `705e4d3c2b1ae93f`, full precision `0.7844444444444445`. Windows' historical 15-significant-digit JSON emits `0.784444444444445`; Web emits `0.784444444444444` from the identical stored bits. Consequently the complete old proof itself cannot rehash under Web's default formatter. Day-1 had already stored the unambiguous value (bytes `755e4d3c2b1ae93f`).

The actual native and Web Open hash inputs are both 28101 UTF-8 bytes. Exactly one byte differs at offset 22280: native `5`, Web `4`. Native SHA-256 is `71503ef3357d568bc164c0df566618a6085f6924aff2d33842508557b855d436`; Web is `f84cbe802a22b09785ffe660f6202b4ab63f2b76c47cd95a41701c4bf6e73881`. These are directly captured hash input strings, not numeric reserialization. See `fingerprint-native-hash-inputs-20261110/evidence/originals.json` and `gas-cross-platform-open-canonical-web-r3-20261110/evidence/open-prior-canonical.txt`, its receipt and `native-web-canonical-byte-comparison.json`.

## Bounded correction and integrity

RunState compares only normalized layout-coordinate representation on an integer 10^-12 grid after both complete inventories validate. Rectangle identities, closed shape, finite numeric types and existing normalized bounds remain checked. Other source fields retain their exact comparison and existing narrowly enumerated dynamic-source rules. The grid is 1000 times finer than the existing 10^-9 sealed interaction geometry. It accepts sub-grid representations within the same bin; arbitrary nearby values across a grid boundary are not promised equivalent.

Inventory validation keeps ordinary digest generation unchanged. Only after every normal structural/source/identity check passes may it recognize one of two bounded historical normalized-layout serialization candidates: 15-significant-digit decimal half-up or half-even. The exact complete stored SHA-256 must match. Expected digests must be nonempty 64-character lowercase hex, and empty/unsupported candidates never match. Detached canonical marker substitution preserves every other body field. Unsupported magnitudes and negative-zero fallback decline. Frozen golden bytes cover the observed tie; this is not a general emulation of historical JSON formatters over arbitrary data.

The original complete inventory body, raw numeric bits, version and exact digest are retained. The final expected-reference guard is unchanged. Current RunState persistence retains that authority-bearing body, so these demonstrated saves need no body/reference migration. Historical compact/layer paths without the full body keep their unchanged exact-digest reconstruction requirements and are not newly qualified by this fix.

## Final-source verification

Read-only review found no actionable code blockers on the two hashes above. `git diff --check` passed. These are focused regressions, not a full-suite or deployed-release qualification.

- `fingerprint-legacy-integrated-unit-20261110/evidence`: retained `scenario_inventory_legacy_serialization_check.gd` passes 60 checks, `scenario_cross_platform_geometry_check.gd` passes 20, and adjacent `scenario_event_restore_binding_check.gd` passes 23. Coverage includes frozen native/Web byte strings, usable exact historical proofs, changed geometry, missing/extra authority and identities, bad/empty/uppercase digests, schema/kind types, malformed/nonfinite rectangles, negative zero, unsupported tiny width with empty digest and input preservation. A deliberate NaN case emits the engine's expected JSON warning and remains rejected.
- `fingerprint-candidate2-native-same-platform-20261111/evidence/warm.json`: all four preserved native fixtures Continue normally with valid room publication/action authority and no recovery. Expected cash/clock pairs: close 990/4470; gap-middle 998/4515; Open 980/4560; Day-1 117/990.
- `fingerprint-candidate2-web-native-cold-20261111/evidence/first.json` and `cold.json`: final-source normal native host Continue of the independently Web-generated Day-1 fixture, Leave/map Close, public Save and separate-process cold Continue pass 9 and 14 assertions. Original complete Web proof remains unchanged. Full finalization rejects changed expected digest, stale-digest altered body, a 10^-9 baseline move, a negative 10^-13 baseline and forged event authority.
- `gas-cross-platform-candidate2-web-20261110/evidence/acceptance-summary.json` and `.md`: exact final PCK, strict HTTPS, fresh native Day-1 and Open fixtures, 43 action results and 32 screenshot/primary hash artifacts. Both render full authored rooms on initial Continue, Back, map Close and separate-process cold Continue. Ordinary Web pointer Collect/Clear/File/Back/Leave/map Close/public Save/cold Continue/reopen Scratchers/re-Save succeeds. Day-1 retains one Dud and $117. Open retains one Win, $40 due and $980; no redemption occurs. Browser clocks advance naturally. Key screenshots: Day-1 1/8/11/15/17; Open 22/29/32/36/38.
- `fingerprint-candidate2-day1-roundtrip-20261111/evidence/{web-save,web-cold-save}.json`: normal native SaveService loads final Web Save 13 and cold Save 20. Both preserve the original canonical complete body AND canonical `var_to_bytes`, schema 2 and digest `4db0b2df853cf4a85f456afc9b288ffde7cfe8b1e0f70bfe748f31cdf76557a4`. Cash remains $117; clocks are 1003/1008.
- `fingerprint-candidate2-open-roundtrip-20261111/evidence/{web-save,web-cold-save}.json`: normal native SaveService loads final Web Save 34 and cold Save 41. Both preserve the original canonical complete body AND canonical `var_to_bytes`, schema 2 and native digest `71503ef3357d568bc164c0df566618a6085f6924aff2d33842508557b855d436`. Cash remains $980; clocks are 4574/4578. This verifies actual numeric-bit preservation, not merely equality after 15-digit JSON rendering.

Native commands use pinned `4.6.stable.official.89cea1439` after storage admission, e.g. `Godot_v4.6-stable_win64_console.exe --headless --path E:/CodexQA/BTH/workspaces/fix-cross-platform-fingerprint-20261110 --audio-driver Dummy --script res://scripts/tests/scenario_inventory_legacy_serialization_check.gd`. Each run's `stages.json` preserves its exact command and launch gates. Final completed Jobs record assignment before execution, 5% CPU / 2 GiB limits, exit 0, no timeout/error and zero owned children at release.

The Web proof uses a private candidate-PCK override on the existing official shell/engine, with asserted fulfilled-buffer hashes and observed HTTP 200 responses. It is not exact-commit NEXT deployment proof. Headless Chrome rendering is covered; audio and a physical pointer Buy are not. The paid tickets were created through normal native Buy before capture.

## Earlier attempts retained

The first RunState-only candidate fixed Day-1 but correctly rejected the Open prior hash. It is not the final acceptance source. Diagnostic logging packs did not weaken validation. Bounded harness-only interruptions remain recorded separately: a minimal source fixture omitted a closed authority field, a large CDP response-body hash probe was evicted, a verifier initially declared an existing file as a directory, and Windows reboot/shared-service refusal interrupted diagnostic launches. Corrected runs use fresh private profiles/IDs; final pass receipts above supersede those attempts. No original fixture or expected proof was regenerated to make a test pass.
