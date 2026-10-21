# Scratch scalper runtime compatibility

An empty scratch machine can introduce its scalper after the room scenario's
immutable inventory was sealed. The old game-hook projection treated the new
person as durable base inventory. Membership publication succeeded, but a later
semantic refresh rejected the new row because the original baseline had no slot
for it. Filing then rolled back to the cleared ticket and retained Buy feedback.

The exact scratch scalper hook now uses the existing runtime classification.
Its ordinary canonical manifest and authored physical slot remain validated.
Legacy saves authenticate their original manifest, mirrors and slot geometry
before the one-row classification migration. An old initial-scalper inventory is
reconstructed only on a detached proof copy and must match its original complete
version/digest. The expected seal and causal journal are never replaced.

## Focused private checks

Run the following scripts through a finite headless runner with Dummy audio,
12% aggregate kernel CPU, 2 GiB aggregate Job memory, kill-on-close and no
breakaway. Give every cold stage fresh private APPDATA, LOCALAPPDATA and TEMP
directories. They refuse startup unless the actual `user://` directory matches
`BTH_SCRATCH_REPRO_USER_DIR` before accessing any save or authority.

- `gas_scratch_arrival_regression.gd` extends the original one-arrival host
  sequence: normal authored Graveyard room, two sellable tickets before sealing,
  Buy two, Collect, Scratch All, File, Back, another physical room interaction
  and normal host Save. A detached removal check requires the original seal and
  unchanged cash, clock, RNG, tickets and journal.
- `gas_scratch_legacy_fixture_prepare.gd` runs against the pinned prepatch d885
  source and preserves a validated initial-empty/scalper-present factory save
  through the normal save service. Its source hash guard deliberately refuses
  to manufacture that legacy seal using patched projection code.
- `gas_scratch_cold_regression_stage.gd` uses `BTH_SCRATCH_REGRESSION_STAGE`:
  `cold_late`, `cold_legacy`, `cold_resaved`, or `tamper`. Each stage verifies a
  byte-identical private fixture before the real cold Continue path. The late
  case files both tickets, redeems $50 once, repeats redemption, saves, then a
  separate process checks Continue and repeats redemption again. The tamper case
  changes slot geometry and recomputes the binding digest; it must fail raw
  authored-slot validation and the room must remain rejected on Continue.

Set `BTH_SCRATCH_FIXTURE_ROOT` to a private `repro-fixtures` directory beside the
isolated checkout and `BTH_SCRATCH_REPRO_REPORT` to a bounded local result file.
Bundles are `late_arrival`, `legacy_initial`, and generated `resaved_late`, each
with `save.json`, `crew-authority.bin`, optional profile inventory and
`metadata.json` containing the original file hashes and semantic reference.
The fixture preparer uses stage `legacy_prepare`. Preserve its prepatch checkout
while testing the patched checkout. Do not commit or upload generated saves,
profile inventory, or authority bytes.

The five cold stages and detached removal check passed on the paired fix. Both
prepatch save shapes retained their exact expected semantic reference; the $50
payout was neither lost nor duplicated. The tampered copy was rejected.

These synthetic checks establish the scalper/File rollback defect and correction.
They do not establish the separate reported user's empty-room cause; that user's
primary, backup and authority capture remains a separate investigation.
