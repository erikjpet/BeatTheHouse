# Generated profile cleanup for 0.6.0

Before the official 0.6.0 tag, 25 generated saves/profile files under
`validation/foundation_systems_retry1/user_data/` were removed from the release
source. They are historical test output, not required build inputs or regression
fixtures. Their former entries were removed from `SHA256SUMS.txt`.

The original captures and checksum list remain in Git history at `611ba3f`.
Intentional regression fixtures live under `scripts/tests/fixtures` and are
excluded from runnable builds. Game code, placements and runtime assets are
unchanged by this cleanup.
