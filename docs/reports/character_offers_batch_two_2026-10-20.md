# June and Sable optional offers

The approved second-batch delta adds June's $5, 15-minute Pocket Watch sale at
the Motel (25% per game day), and Sable's free, 45-minute Broken Cufflinks repair
at the hidden Punchline casino or Delta Queen (20% per shared game day). Ox is
unchanged. Generic item grant/recipe fields extend the existing offer layer;
there are no character-specific core branches or home-storage mutations.

June requires enough cash and no carried Pocket Watch. Sable requires one
available carried Broken Cufflinks and no carried repaired pair; her current
venue must remain open for the repair. Reserved entries and collateral cannot
supply its input. Both use canonical item, clock, save and detached transaction
APIs, including deadlines, home rollover and interest. Existing first-batch
contracts are retained and made compatible with the larger offer catalog.

## Native qualification

Command: `godot --headless --path . --script res://scripts/tests/character_offers_batch_two_check.gd`

Engine: official Windows Godot 4.6 stable, `89cea1439`.

Final result: **152 assertions, zero failures, exit 0**, elapsed **6.862 seconds**.
The process ran with a 45-second watchdog and isolated test storage; no rendered
game or browser was launched. The console launcher used below-normal priority
and verified one-processor affinity. Its process metrics do not measure the
engine child's CPU/RSS and are not a performance qualification.

Coverage: both probabilities and stored misses; no rerolls on review/reload;
carried ownership including dictionary/reserved entries; exact cash/time/item
effects; zero-cash Sable and exact-price June; no invented action turns; one
shared Sable claim across venues; Delta closing window; saved claims, snapshot
isolation and stale responses; canonical day rollover, deadlines and interest;
and full rollback of charge, item removal/grant, time, claim and story when clock
or scenario settlement rejects.

The first bounded attempt exited 1 in 8.281 seconds: 147 assertions, 26 failures.
Twenty-four were strict integer-versus-JSON-float record comparisons; one used
a minimal public Punchline fixture that correctly lost Sable on canonical
membership rebuild; one delivery fixture omitted its required origin and was
empty. Corrected fixtures compare the exact integral roll while preserving all
other fields, use the Delta base map through restore/day rebuild, and assert a
valid active delivery with origin/carried cargo before advancing time. Injected
rejection cases also assert eligibility before testing rollback. No production
behavior was changed to make those assertions pass.

Godot printed an environment warning about reading the Windows root certificate
store on both attempts. The contract requires no external network access. The
warning remained visible in the retained logs and did not affect the final
native result.

Source syntax parsing and `git diff --check` also passed. This delta is based on
`b82b84b9dec4a0a158a6ef6e758540c49ce56afd`, before the cloud-qualified first-batch
cache/signature patch. Integrate only the separate second-batch commit onto the
qualified first-batch line, preserving its fixture corrections and cache fixes.
The combined rendered-card/cache behavior still needs the appropriate focused
integration check. Headless qualification is not visual Web proof, and this
record does not claim main/NEXT publication.
