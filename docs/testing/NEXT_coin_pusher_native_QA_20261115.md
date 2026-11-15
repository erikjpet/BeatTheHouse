# Coin Pusher native follow-on QA

Source d2dae5b8 (runtime identical to delivered8bfa0b8f). Current isolated checkout exposes native_v3 successfully; earlier missing-solver reports do not describe this run. No runtime changes.

- Continuous input passes: synthetic60Hz production module pointer/realtime calls, populated cabinet. Continuous drag180frames gives180authority ticks,180nozzle updates,0backlog, maximum publication age16ms; conservation/energy pass.24 reserved drops,18emitted and6pending at final sampled boundary. Call timings are diagnostic under CPU cap, not rendered FPS.
- Retention passes using actual native_v3, empty valid cabinet and synthetic clock:30,000 inputs/500simulated seconds,0pending/0backlog. Retained history1000,780,290 at1000/10000/30000 checkpoints; static memory growth623200,493188,184152bytes. Diagnostic trace release leaves5408bytes growth. This is bounded retained-state attribution, not typical play or a whole-game leak assertion.
- Compaction passes: pending suffix/order, exactly-once consumption/no replay, authored tick, legacy total count, rejected-drop rollback and exit settlement preserved.

No actual browser pointer/FPS, full-host frame pacing or user-save coverage. Historical deferred release coverage stays deferred; this supplemental resumed general-QA evidence does not close those objectives. All guarded runs timeoutfalse,active_at_release0; owner saves untouched.

## Evidence hashes
- `E:\CodexQA\BTH\runs\next-bugfinder-pusherinput-20261115-01\evidence\worker.log` SHA256 `60ba225afd6f91a936cee5d2d1986e66348651fdd4407d0931d98d754056683e`
- `E:\CodexQA\BTH\runs\next-bugfinder-pusherinput-20261115-01\evidence\job.json` SHA256 `d0d376af7bfeb7d81cbeb3b66dfc6a0bf3385f6014796c91ceeabdcf3d62f69b`
- `E:\CodexQA\BTH\runs\next-bugfinder-pusherinput-20261115-01\evidence\storage-manifest.json` SHA256 `305100e6ee327be03e4c0352178862101b211371e7dc572273bf3e48294e6408`
- `E:\CodexQA\BTH\runs\next-bugfinder-pusherretention-20261115-01\evidence\worker.log` SHA256 `60bfb508583a8c8e8d00a4bbb9e24de36508ab3a79cebfdf933e9c3434e0a80b`
- `E:\CodexQA\BTH\runs\next-bugfinder-pusherretention-20261115-01\evidence\job.json` SHA256 `25d3a0f44255a95aa28c82a56b8a9539e271f989cf502ae27f8c0190176fd391`
- `E:\CodexQA\BTH\runs\next-bugfinder-pusherretention-20261115-01\evidence\storage-manifest.json` SHA256 `f673fc422d61396fda58bdf0e1a1791be4ac4c18f611639f61fc4a633861d6e1`
- `E:\CodexQA\BTH\runs\next-bugfinder-pushercompaction-20261115-01\evidence\worker.log` SHA256 `4773ddb7301cb9e9d158e60c0081e0bd0abe653fb9bce58c3f258ad08e4d1de1`
- `E:\CodexQA\BTH\runs\next-bugfinder-pushercompaction-20261115-01\evidence\job.json` SHA256 `d1edf5d873e18719912a7132131a5632fd0e1edd09de63e09d8358dc924d352c`
- `E:\CodexQA\BTH\runs\next-bugfinder-pushercompaction-20261115-01\evidence\storage-manifest.json` SHA256 `fd577773a17a82dd7b07ed130df935a15e0698fc25095bbbea404505320111d4`

Ledger reconciliation21 retains109 existing findings, including unknown historical performance-worker owner for the two parent objectives. These supplemental checks do not reassign or close that work. No new scoped Practice-fix finding.
