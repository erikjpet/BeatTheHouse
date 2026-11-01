# Save numeric precision

Storage uses the existing schema/version, codec 2, five-field
`json-zstd-z85-v1` envelope, Zstd/Z85 and SHA256 over the actual source bytes.
The source-byte limit remains 32 MiB. No float metadata or temporary token is
persisted. Signing canonicalizers, typed integer markers and crypto are unchanged.

The storage writer requests full numeric precision. Godot's ordinary writer
erases the sign of zero before its precision branch, so a storage-only rare
path replaces negative-zero float leaves in an owned projection with unique
temporary strings. Native serialization still owns key ordering, escaping and
unsupported/nonfinite handling. Exact quoted placeholders become standard
`-0.0` before byte hashing/compression. Existing emitted strings and keys are
checked for collisions; an occurrence-count mismatch fails serialization.

The storage reader retains native JSON structural validation and extended
grammar. It lexes number spans outside strings, computes correctly rounded
standard numeric values and substitutes only differing values through unique
in-memory strings followed by the same structural parser. Occupancy checks use
decoded live string values, so escapes and duplicate keys cannot turn a literal
string into a number. There is no object deserialization or executable input.

Scalar rounding uses base-2^26 integer limbs and exact rational comparisons
with binary64 midpoints. Products remain below signed int64 overflow. A checked
native approximation is a starting point, with bounded binary search when its
error is larger. Equality chooses the even significand. An exact raw coefficient
of at most 18 digits and an exact power of ten through exponent +/-22 permit
the existing one-rounding fast path. That path must not ignore leading digits,
trailing zeroes, coefficient representability or the native 18-digit truncation.

All binary64 midpoint decimal coefficients have at most 768 significant digits:
the extreme bound is below `2^54 * 5^1075`. Longer input retains a prefix and a
sticky nonzero tail; the tail resolves equality against a midpoint rather than
being discarded. Exponents saturate relative to token length before arithmetic
so long zero/exponent cancellation remains meaningful and bounded. Caches are
local to one parse, never shared mutable state between save workers.

Real packed loads verify original bytes, counts and source hash first, then
apply existing Blackjack integer-token repair, then numeric interpretation and
the existing decoder/authority validation. The outer SaveService reader also
uses the local helper for supported raw and unpacked legacy payloads. Content
validators and the verified-primary cache retain their existing strict checks;
normalization never supplies a missing content-root proof.

Old recorded decimals are interpreted correctly, even where this corrects an
old parser error. Digits or negative-zero signs erased by an old writer cannot
be recovered. Never reconstruct them from current source or tolerate a signature
mismatch. Never retry an old numeric interpretation to make authentication pass.

Focused native checks, under an independently owned synthetic root and lease:

- `storage_numeric_json_check.gd`: independent generated bit oracles, ties,
  subnormals/extremes, long tails, grammar, strings, collisions, markers and hash.
- `save_float_precision_codec_check.gd`: retained phase/tilt, registry/layer
  values, signing fingerprints and deterministic subsequent physics/RNG.
- `samewire_precision_service_check.gd`: sync, worker and native execution of
  no-thread phases, fresh-service and fresh-process original-root load, resident
  capsule rejection of changed context, including signed zero/extreme values.
- `samewire_precision_atomic_check.gd`: generated old writer spelling and raw/
  schema1/codec1/codec2 readers; unchanged resident authentication; failed size
  and install preservation, retries and invalid-primary backup fallback.
- `samewire_blackjack_receipt_check.gd`: actual synthetic producer, unchanged
  receipt/hash-chain validation, tamper rejection and original sealed delivery
  replay without another debit, RNG advance or history append.
- `samewire_precision_perf_check.gd`: 40,000 mixed values, ownership, real 32 MiB
  rejection and the extra negative-zero sign byte at a source-size boundary.

The numeric fixture is generated with exact integer-rational nearest-even
rounding and independently checked against CPython. Numeric token strings and
expected little-endian bit strings are public synthetic data. The service test's
cross-process metadata preserves every jobs field/type explicitly; integer
counts use decimal strings so the test receipt itself cannot change ints into
floats. Earlier failures and their source snapshots must remain separate.

Native no-thread phase coverage is not browser coverage. Generated old-writer
fixtures are not genuine old-build receipts. Old native JSON can read the
unchanged wire format, but its historical numeric errors remain in that binary.
Combined integration, actual legacy route/UI and Web qualification are separate.
