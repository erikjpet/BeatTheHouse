# Cold Continue regression fixture

Captured from the production Web UI during independent 0.6 release verification
on 2026-10-18. The normal Run Setup used seed `RUN-20261018-024200-003`, started
in the Back Alley, traveled to the Gas Station Casino, and saved during the
naturally selected Storm Shelter scenario. No scenario or outcome was injected.

The save contains valid durable geometry and scenario state. As designed, it
omits the renderer snapshot, layout audit, and semantic projection. A fresh
Continue previously rejected those missing derived caches before the trusted
finalizer could reconstruct them, leaving the entire room invisible. The same
save reproduced the problem in both Chromium and the pinned Linux runtime.

The regression loads this pre-fix save through the real cold Continue path,
checks essential physical objects and unchanged economy/RNG/time, and verifies
that a damaged durable authority digest still fails closed.
