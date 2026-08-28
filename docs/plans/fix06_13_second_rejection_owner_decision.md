# fix06_13 second-rejection owner decision

Status: **UNREVIEWED / OPTION-NEUTRAL / OWNER SELECTION REQUIRED**

This packet records the second rejected remediation cycle for `fix06_13` and
presents three dispositions. It does not select, rank, or recommend one. It
changes no board row, product/native code, test, assertion, gate, budget, cap,
artifact, or locked Web evidence.

## Exact frozen provenance

The current-main integration head is
`62d45c2e390be815cc94b732b9930b37ff9a543c` (tree
`9b6a79948fd07b54e9f17c92e7f76e74c474a8a7`; parents green main
`00ee744fa6269e8a7eb34f67b2659f32d55febaa` and accepted integration
`718af3da7176abfaec9f9dbc10884454298a9872`). Its functional qualification
passed validation, import, load, and every Coin Pusher assertion, then failed
strict terminal stderr qualification because the native live cache retained a
per-call `RngStream`/ObjectDB resource at exit:

- validation: exit 0, 55.988 seconds;
- import: exit 0, 45.836 seconds;
- GDScript load: exit 0, 25.556 seconds;
- focused Coin Pusher: assertions 0 failures, process classified exit 127 after
  173.107 seconds because stderr contained `ObjectDB instances leaked at exit`
  and `1 resources still in use at exit`;
- qualification summary SHA-256:
  `4E47F6B445096C6EC9700571984E0C8566DCF400C43908F3AFC75D55BC4E13AE`;
- focused stderr SHA-256:
  `080BF1742607F9828802E36E8B122E9E8796B0160C16C4D911B384F3C9F5E1E6`;
- retained verbose stdout SHA-256:
  `4B30A486C1110F53C79C83595B19B96FE44DCF5A8B107B19439256A803EA62C9`;
- retained verbose stderr SHA-256:
  `E7FBE335C489102928054AAE441A32D995D8FB9BDEA3914402FF8FF0EA7CB542`;
- exact native debug DLL SHA-256 on that qualification worktree:
  `090289431C51B8F7F610C18676B81EA64C65E11EBD5B8E5F5D5440A935004EEC`.

The first remediation head is
`fc05b8ee8f644c2c5143bbcf808d8da97aa2f3cd` (tree
`f6fd4bfe1293e1f4afbf739c7e6792d11c81646b`, parent `62d45c2e...`). It added
native call-context release plus one ownership negative. Independent review
rejected it because `Dictionary.clear()` could clear the caller-shared config,
so fixing retention could mutate caller-owned bytes. That is the first review
rejection; it remains preserved and is not an acceptable implementation head.

The second remediation/review head is
`0414cefcb6b2409b7b18711c210fd9c95073cd4c` (tree
`2d37dcde5bd743ba7adda5322559c9407075b223`, parent `fc05b8ee...`). It replaced
the cached dictionary reference without clearing caller storage and expanded
the negative to cover both cache reset/new and cache reuse paths. For both
paths it asserts caller keys/value bytes/RNG identity remain unchanged and the
per-call `RngStream` is released after the caller releases its references.
Independent second review accepted that exact semantic head.

The Integrator then built the native plugin for `0414cefc...` in 418.7 seconds.
The resulting Windows template-debug, x86_64, no-threads DLL SHA-256 is
`619FB31AA3773DFBEA194ADDB942F1E88B2082F156A0AD2494FD462A0203ECAD`.
On that exact head and plugin, validation/import/load passed in
52.338/45.590/25.569 seconds. The focused Coin Pusher gate terminated before
any assertion ran because warnings are errors and these two new locals inferred
`Variant` from `weakref(...)`:

```gdscript
var reset_rng_weak := weakref(reset_rng)
var reuse_rng_weak := weakref(reuse_rng)
```

The focused stage exited 1 after 8.076 seconds with two identical
`The variable type is being inferred from a Variant value` parse diagnostics,
at generated split-runner lines 33035 and 33056, followed by failure to load the
generated runner. The terminal evidence is frozen at:

- functional summary SHA-256:
  `9ACA4736A256E531430AB848C174C299B6A1D4D4D76AF7C5CA85A93F4C434C24`;
- focused stderr SHA-256:
  `E338F3F32E43C131308FD905250FB85D41D694267D7EFDAD0C163CF9441DD457`;
- focused stdout SHA-256:
  `8851BBE6309477B42336A7A66906B18CF14A957F6C7C5475A6A376061710C7DE`;
- load report SHA-256:
  `F5E786A435A086E550B8AD01D9B5EA8BB7285C160F4EA6233CF7C2C9AD6E405F`;
- import stdout SHA-256:
  `87AA4568E7439B94EDF55D5B2A496EEE9E2A7135073A33969E4D9F5A2C9322EC`.

The raw terminal artifacts remain in their preserved owner custody path
`.tmp/integrator_fix06_13_functional_rerun_0414cefc/` in the named remediation
worktree. They are not committed by this packet and must not be overwritten.

This functional parse red is the second remediation rejection. Review
acceptance of `0414cefc...` does not override it. There is no third cycle and no
new functional qualification until the owner selects A or B. Selection C parks
or reshapes the row as stated below.

## Locked Web remains unconsumed

No shipped-Web export, browser run, timing result, or locked fix06_13 Web
evidence was consumed on `62d45c2e...`, `fc05b8ee...`, or `0414cefc...`.
Historical shipped-Web reds, including locked `c914546f...`, remain immutable
provenance only. The one permitted locked output run remains **NOT RUN /
UNCONSUMED**. None of A, B, or C authorizes it before an accepted and landed
functional fix06_13 head exists and the Integrator opens that exact downstream
stage.

## Frozen requirements for every option

Until the owner records A, B, or C:

- do not edit, rebuild, rerun, or search for a favorable result;
- do not run or consume the locked Web attempt;
- do not weaken, delete, skip, invert, or make conditional the strict stderr
  policy, leak negative, caller-byte checks, RNG-identity checks, or RNG-release
  checks;
- do not change caps, assertions, warnings-as-errors, budgets, timeouts,
  baselines, native behavior, product behavior, cache semantics, RNG, save,
  schema, migration, performance tuning, or Web tooling;
- do not reinterpret zero executed assertions as a pass; and
- do not claim `fix06_13`, `fix06_9`, or `pusherv3_11` closure.

Both executable options retain the four required proof surfaces: reset/new
caller bytes and identity unchanged; reset/new RNG released after caller
release; reuse caller bytes and identity unchanged; reuse RNG released after
caller release. No option may replace exact ownership proof with a comment,
static search, relaxed stderr, or a test that never reaches both paths.

## Option A — authorize exactly two explicit `WeakRef` annotations

Authorize a syntax-only successor to `0414cefc...` that changes exactly these
two declarations in `scripts/tests/foundation/check_coin_pusher.gd`:

```gdscript
var reset_rng_weak: WeakRef = weakref(reset_rng)
var reuse_rng_weak: WeakRef = weakref(reuse_rng)
```

No other tracked byte may change. In particular, Option A authorizes no native,
product, assertion, helper, policy, cap, budget, timeout, Web, or evidence-tool
change. The existing caller-byte/RNG-release assertions and reset/new plus reuse
coverage remain byte-for-byte unchanged except for those two type annotations.

Consequences of A:

- the successor receives exceptional independent review against
  `0414cefc...`, explicitly proving the diff is exactly the two annotations;
- the native plugin may be rebuilt and re-hashed only as needed to qualify the
  exact successor checkout; because no native source change is authorized, any
  unexpected DLL identity change must be explained and fail closed;
- after review acceptance, the Integrator may perform exactly one new
  exact-head functional qualification covering validation, import, load, and
  the focused Coin Pusher gate with strict stderr;
- no retry follows a red. A further red returns to the owner; and
- a functional green makes the head eligible for normal Integrator landing but
  does not itself authorize or consume the locked Web run.

## Option B — authorize a different bounded test-only proof rewrite

Authorize a successor to `0414cefc...` limited exclusively to the
`_check_pusher_v3_native_live_cache_ownership` negative and a directly owned
test-only helper, if required, in
`scripts/tests/foundation/check_coin_pusher.gd`. The rewrite must avoid Variant
inference without using the two explicit `WeakRef` annotations from A. It must
still execute reset/new and reuse and retain all four caller-byte/RNG-release
proof surfaces verbatim in meaning and failure behavior.

No native or product file, cache behavior, assertion strength, cap, warning
policy, gate wrapper, budget, timeout, baseline, Web tool, RNG, save, schema, or
migration may change. The worker must publish the exact proposed test-only diff
before implementation review; scope beyond that named function/helper returns
to the owner.

Consequences of B:

- the bounded test-only rewrite receives exceptional independent semantic
  review proving both paths execute and all four ownership assertions remain;
- the native plugin may be rebuilt and re-hashed only as needed for exact-head
  qualification, with no native source change authorized;
- after review acceptance, the Integrator may perform exactly one new
  exact-head functional qualification with the same validation/import/load/
  focused strict-stderr boundary;
- no retry follows a red. A further red returns to the owner; and
- a functional green makes the head eligible for normal Integrator landing but
  does not itself authorize or consume the locked Web run.

## Option C — park or reshape the ownership negative/row

Do not authorize another implementation cycle on the present acceptance
contract. Park `fix06_13`, or provide a separately explicit owner-approved
reshape of the ownership negative/row. A reshape must state the replacement
requirement, why it still proves caller-byte preservation and per-call RNG
release on both reset/new and reuse, which exact assertions change, and how all
dependent contracts are reconciled. It cannot silently weaken or delete the
current negative.

Consequences of C:

- no tracked edit, rebuild, functional qualification, or locked Web run is
  authorized by this packet;
- `62d45c2e...` remains the functional leak red and `0414cefc...` remains the
  accepted-review but functional-parse-red head;
- `fix06_13` remains BLOCKED and unlanded;
- `fix06_9` remains BLOCKED on accepted and landed `fix06_13` plus its exact
  locked-output protocol;
- `pusherv3_11` remains BLOCKED on `fix06_13`, `fix06_9`, and every other open
  closure dependency; and
- the locked fix06_13 shipped-Web result remains NOT RUN / UNCONSUMED.

## Owner record required

Record exactly `A`, `B`, or `C`, owner, and timestamp.

- For A, confirm the exact two annotation-only diff and exceptional
  review/one-functional-qualification authority.
- For B, confirm the bounded test-only ownership-negative surface and
  exceptional review/one-functional-qualification authority.
- For C, state `PARK` or provide the full replacement contract and dependent
  reconciliation before any implementation row is created.

No selection may be inferred from this packet, the small size of A, the prior
review acceptance, the native build, or the terminal parse red. Until the owner
records a selection, no third remediation cycle, qualification, landing, or
locked Web run is authorized.
