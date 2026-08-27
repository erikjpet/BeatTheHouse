Status: PARKED - evidence runner accepted; persistent-machine liveness requires owner decision `fix06_12`
Board row: `fix06_10` in `docs/todo/README_0_6_board.md`

# fix06_10 — Coin Pusher EV Evidence Runner OOM

## Purpose

Repair only the evidence runner exposed by the retained `pusherv3_11` EV
failure. This row does not authorize any product, solver, physics, RNG, payout,
odds, wager, EV-band, accounting, machine-definition or performance-cap change.

## Binding failure evidence

The failed run is retained at
`D:\Projects\Beat-The-House-worktrees\land06-pusherv3_11\.tmp\pusherv3_11_ev_200k_v2\`.
At 19:53 on 2026-08-26 the wrapper launched six Quarter Falls shards
concurrently, each targeting 25,000 accepted inserts on one persistent machine.
The controlling shell later timed out while the children remained active. At
approximately 21:07, five workers recorded `std::bad_alloc` or null-allocation
errors, another ended without diagnostics, and none wrote JSON. The fail-open
wrapper then launched Quarter Falls shards 06-07 and Jackpot Ridge shards
00-02 before external task cancellation stopped the run. Those second-wave
banner-only files are interruption evidence, not product or EV verdicts.

The retained files cannot recover exact per-worker accepted/refused counts or
memory growth because the old runner emitted neither. The simultaneous
allocation failures establish aggregate host exhaustion under six long-lived
workers; they do not justify changing the machine or reducing the sample.

## Evidence-runner-only remediation

- Run shards serially and reject an unsafe parallel throttle.
- Parse and validate each shard report before scheduling the next shard.
- Stop scheduling on nonzero exit, missing/malformed/incomplete JSON or identity
  mismatch, while preserving the failure and every unstarted job explicitly.
- Reject any output directory containing a planned output; never delete or
  overwrite retained/owner evidence.
- Stop, wait for and dispose active children on scheduler exception or
  interruption, with a durable recovery report.
- Record shard progress and peak working set, including successful shards.

Initial implementation `9a6c6c9776d79a14abae243f6286c07020561b7e`
was independently rejected because stale JSON could be reused, cleanup was not
durable, malformed JSON was not validated immediately and successful peak
memory was absent from the manifest. Remediation head
`861d2d40a40c27bcde7fe67c0b8e0912c38567f9` closes all four findings.
Reviewer `/root/fix10_review` returned
`ACCEPT exact head 861d2d40a40c27bcde7fe67c0b8e0912c38567f9. No P0–P3 findings.`

## Required verification before closure

1. Use a new unique output directory and the accepted serial runner on the
   exact integration tree with the required native solver supplied and hashed.
2. Complete exactly 200,000 accepted inserts per production machine (eight
   deterministic 25,000-insert shards each): Quarter Falls, Jackpot Ridge and
   Vault Drop. Refused attempts do not reduce the accepted target.
3. Preserve all authored assertions: exact sample, native backend, coverage,
   conservation, origin reconciliation, persistent-machine/no-reset policy,
   separate Ridge credit, separate Vault option value and separate plinko value.
4. Report each documented physical EV band without tuning:
   Quarter Falls `[0.72, 0.94]`, Jackpot Ridge `[0.70, 1.08]`, and Vault Drop
   `[0.72, 0.94]` with option value separate. Any miss remains a failure routed
   to `pusherv3_11`; it is never repaired by this row.
5. Retain every shard stream/report, the final manifest, commands, exact Git and
   native heads/hashes, elapsed time and peak working set. No lucky rerun.
6. Land only after exact-head evidence and independent acceptance. Then perform
   the proportionate post-land runner/static check and record the main head.

This row cannot become DONE until full 200k-per-machine evidence completes, an
accepted payload lands on main, and a post-land record is written. Its final
parking record below prevents further work without an owner ruling. No release,
version, packaging, publication or remote action belongs to this row.

## 2026-08-26 final parking record

The runner-only work is independently accepted at exact fix06_10 head
`861d2d40a40c27bcde7fe67c0b8e0912c38567f9` and exact fix06_11 head
`745051323f90ffcd7839b5dbfab0074f5553b290`. Their accepted integration is
`ab584b0b965301e523b173d477491b19f125d1ac`.

On that exact clean integration, project validation, editor import and native
smoke passed. The smoke used `native_v3`; descriptor, UID and native DLL
SHA-256 values were respectively `72EE625D61257DCBD65400E57F39077EADEDD3C265C25C83F68BC2F8EFBC9861`,
`F606704CBF202403DE82CBFD19B4160889346206EAD1D96E86C6A452B0C3A06A` and
`1052770B5A96057928F67A72159D8A31B89D5591EAB7A64F07F8FCAE458E83F5`.

The one authorized exact run stopped deterministically on Quarter Falls shard
00 after 530 accepted inserts followed by 4,096 consecutive ceiling refusals.
The retained state was active 600, tray 0 and gutter 80 on `native_v3`; direct
worker peak was 575,750,144 bytes. The structured failure is not an EV-band
verdict. All 23 remaining shards are explicitly unstarted and no rerun occurred.
The retained output directory is
`D:\bth-f10\.tmp\fix06_11_integrated_ev_200k_exact_2026-08-26_23-33-19`;
manifest SHA-256 is
`5CD255D329BDDC99A90336C98B8200FD0F8B0DE5C91558EC3D0CF45B329C8791`.

No runner-only change can restore accepted-insert liveness under the locked
persistent/no-reset policy. This row is therefore PARKED, not DONE, and routes
only to the owner decision in `fix06_12_coin_pusher_persistent_liveness_owner_decision_prompt.md`.
