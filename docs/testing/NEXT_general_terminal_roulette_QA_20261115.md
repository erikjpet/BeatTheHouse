# General NEXT native QA: terminal and cross-game boundaries

Source 5ce535f4; runtime identical to qualified Crew fix ed37dd27 and
served NEXT0b6f18a8. This is independent native coverage, not browser gameplay.
Normal owner Chrome still contains Continue; no supported isolated Web profile
was established, and no owner saves were touched. All test storage is isolated E.

## Results
- Table ending presentation:77/77, including Stand loss, Hit bust, nonterminal
  loss, reduced motion, Baccarat, entry/machine boundary, and interrupted-result
  Save/Continue. Fixed shoes and controlled presentation clocks are explicit
  synthetic fixture inputs; this is not actual pointer/visual playtesting.
- Craps working stakes:16/16. Zero liquid cash does not discard paid bets,
  while historical/NPC/staged unpaid bets do not falsely keep the player solvent.
- Roulette after Blackjack:43/43 with a natural prior Blackjack hand, paced
  normal host callbacks, one RED bet and single CONFIRM. No stranded request.
  The Riverboat cash80/min9 room is explicitly staged before generation, not
  the original R08 campaign or normal travel.
- Additional new-host post-confirm Save/Continue:48/48 total. Cash80, RNG,
  spin_count1 and exact request ledger persist; no replay or pending request.
  The first extension attempt02 incorrectly treated void save_foundation_run
  as bool and raised a script error despite exit0: it is NOT a pass. Corrected
  attempt03 verifies saved slot existence then new-host Continue.

## Shutdown warning, not a demonstrated player leak

Table fixture exits0 with all assertions passing but reports ObjectDB and12
resources still in use. Verbose evidence retains RunState-related scripts and
one suspended GDScriptFunctionState. Adding a one-second post-host cleanup wait
does not remove it. An ordinary three-host title startup/cleanup control has no
ObjectDB/resource warning. This does not establish a growing in-game leak or
justify changing runtime cleanup based only on synthetic terminal teardown.
Keep the warning visible; do not call this a warning-free test pass.

No product code or test assertions changed. Historical Roulette pending-request
case remains unattributed and open; this bounded pass does not close it.

## Evidence
All listed jobs have timed_out=false and active_at_release=0. Raw evidence stays
under E:/CodexQA/BTH/runs; only this summary and hashes enter Git.

- next-bugfinder-tableterminal-20261115-01/evidence/worker.log: `039d0e88c652091b65a5643782e08884deb0d8a6f99b28aae9e5a1ac0f7da88a`
- next-bugfinder-tableterminal-20261115-01/evidence/job.json: `ada846fec85588995c1572506d1b19b1964e62e29ef8b5bc454697cd5029de3f`
- next-bugfinder-tableterminal-20261115-02/evidence/worker.log: `555f1852e8cece17c2f754e8a3227363feda02b9b9107974c5881e929cb954c5`
- next-bugfinder-tableterminal-20261115-02/evidence/job.json: `01789eb67d2ed61403c9877c9d895315010efd985d6a3bfd8d5c2acacfcbd355`
- next-bugfinder-tablecleanup-20261115-01/evidence/worker.log: `e6a669a8362f3d044d4fe89bb9806069d7b8a1aed26a68c709d4e621b7810670`
- next-bugfinder-tablecleanup-20261115-01/evidence/job.json: `f43d1cb28e00a2f47a891e67865794cfee9e7f03348b110c16a48721eb976f7c`
- next-bugfinder-hostcleanup-20261115-01/evidence/worker.log: `f7a3ed4ec46ce99169b8be39ba8ddc9c76b193b77bfced8d4097735f93ca27d9`
- next-bugfinder-hostcleanup-20261115-01/evidence/job.json: `f476218ec0070972e9c407d3d0c4da65b41dc6a7a83e9520ff02f79ac97b9d65`
- next-bugfinder-crapsstakes-20261115-01/evidence/worker.log: `fd1716b9a56d37980752b1a5e96a3553e4d913175951e792b9fb3bd0b52df656`
- next-bugfinder-crapsstakes-20261115-01/evidence/job.json: `397c4c8612ce0bc8fd77909a9cf4f9da6a4d35a30c7e6b9cb25c47d0e444d831`
- native-private-next-roulette-20261115-01/evidence/worker.log: `f32832b887efd833b569b2375e0ec35f2a00e8b03d05cac57d1917be938e263d`
- native-private-next-roulette-20261115-01/evidence/job.json: `38d1fe8faed2645e1e91fa6ece1afb742f6244c6513607477a08f42b820c27b1`
- native-private-next-roulette-20261115-02/evidence/worker.log: `5c54ff51d1af108ac0c960826ea8b92d50ebda843c51bbe84f9c0684ac35c489`
- native-private-next-roulette-20261115-02/evidence/job.json: `aa516f6a8ab1fce7f87dabde4007a7d62349c34b31046d5b0acdbd0d5263b618`
- native-private-next-roulette-20261115-03/evidence/worker.log: `ce6e44a2257e1aaa3651eefe770251adfce5227a5f47fd6c17d21427ac976383`
- native-private-next-roulette-20261115-03/evidence/job.json: `39d2727d4eeca494cb3cfb7dd70e065ecd8d3b33f5dae4739d92b1b69d50031b`
