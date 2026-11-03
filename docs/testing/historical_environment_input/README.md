# Superseded environment input checks

These five checks are preserved byte for byte from main `38defb7271e0cedb006f8e0ca3424cb7d1a80fb2`.
They qualified the post-0.6 room gesture and arrival-quarantine implementation,
which the game creator explicitly requested reverting to v0.6.0.

They are archived as `.gd.txt` because their assertions require the removed
gesture APIs, and one subclass overrides the removed two-argument activation
signature. They are historical evidence, not acceptance checks for the restored
implementation. No maintained check runner referenced these scripts.

The replacement is `scripts/tests/environment_06_input_contract_check.gd`.
The reference is stable `v0.6.0`, commit
`a095414b20cdb3570e06b367c621be43e0256109`.

The mobile viewport checks remain in `scripts/tests` because the coach/dialogue
fixtures reuse their helpers. Their full-portrait assertions describe the
superseded BTH-31 design and must not be used to qualify the restored 16:9 policy.
The restoration leaves those helpers and independent coach/modal ownership fixes
available without changing the authored aspect ratio.
