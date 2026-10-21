# No-thread Web autosave ownership and durability

The current Web template has no threads. Godot executes WorkerThreadPool tasks on the caller in that configuration, so the previous nominal asynchronous autosave serialized, compressed, validated and installed the entire save on the main thread. The retained real Web trace measured 178 ms for capture and dispatch.

The Web-only path captures and encodes the generation before yielding. The codec constructs new Dictionary/Array containers and explicitly duplicates packed-array leaves. The encoded artifact is private; later actions cannot mutate the pending generation. Its storage format, exact-integer treatment, definition references and restore logic are unchanged. Native/threaded worker behavior is retained.

There is one in-flight generation. The existing host coalesces later dirty generations. Packing and validated atomic installation each occupy a distinct later process frame; repeated polls cannot collapse both into one frame. This introduces no unbounded queue. Explicit Save, Continue, clear and navigation drain the at-most-two remaining phases synchronously. A generation is acknowledged only after the existing temporary validation, prior-byte check, atomic rotation and installed-byte proof complete. Failures retain the prior generation and remain retryable.

These are main-thread phases, not parallel execution. Capture and encoding still block, and an individual phase can remain slow on large saves or under load. No zero-freeze or benchmark-quality claim follows from this design. A real action/Continue comparison is required before publication.

Focused evidence checks ownership under mutation, distinct process frames, no early success acknowledgement, exact synchronous image/RNG parity, busy rejection, explicit drain/idempotence, compression failure, atomic-install rollback/retry and backup ordering. The mandatory no-pointer animation liveness check also passes. The first mutation probe exposed packed-array sharing and was retained; production encoding now explicitly owns those buffers.

## Focused qualification

The genuine back-alley offer and normal engine reload/Continue passed in the private Web build with the same captured six-file input as the retained b92 control. All six saved files were byte-identical across Continue in each case. RNG, authority, bankroll and one action execution matched. Both cases captured input/action clock923 and saved924. The complete cross-case comparison lists exactly two music transport differences; no fields were silently excluded.

| Observed boundary | Retained control | Candidate |
| --- | ---: | ---: |
| Uninterrupted save capture/dispatch |178.0ms|81.8ms|
| Later pack phase | part of the same task |33.7ms|
| Later validated install | part of the same task |35.5ms|
| Largest recorded post-response browser task |187ms|92ms|
| Input to engine frame submission |254.9ms|307.2ms|
| Save completion observed |633.6ms|647.4ms|

The candidate phases occupied distinct process frames986,987,988. These are contextual observations under a12% aggregate browser Job quota and2GiB memory limit, not an uncontended benchmark: a separate finite native check overlapped18:42:36.600-18:42:55.625UTC. No initial-response speedup is established. Engine frame submission is not confirmed compositor presentation. Initial action work and81.8ms capture/encode still block; this does not meet a zero-freeze goal. Save acknowledgement still follows validated installation, and explicit boundaries drain pending work.

Targeted checks:38 browser byte vectors/real compressed bytes,36 native format/integrity/atomic retry checks,26 ownership/frame/rollback/ordering checks with the real decoded save, and the required no-pointer animation check. The introduced per-scalar ownership-call overhead was measured and corrected before final qualification. No full suite or unchanged gameplay flow was rerun. Private payloads, test profiles and trace artifacts remain local.
