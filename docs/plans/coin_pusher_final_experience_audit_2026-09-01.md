# Coin Pusher final experience audit — 2026-09-01

## Outcome

The three Coin Pusher cabinets are complete as distinct, persistent machines,
not small cosmetic variations. Existing V3 work was recovered and extended; the
physics machine, live loop, cabinet, delivery board, nozzle queue, and stack
solver were retained rather than rebuilt.

## What changed

- Every new cabinet starts quiet with `150/150/154` settled bodies arranged as
  irregular full-width played-in clusters. Left, center, and right thirds all
  have useful upper/lower stock and contact paths, while deterministic seeds
  produce different silhouettes. No stock, reward, sound, or motor movement
  occurs before the player's first accepted drop.
- Every cabinet has two labeled bucket-shaped Plinko cups that consume the
  triggering coin and award visible bonus tokens from the same nozzle. Quarter
  Falls awards `+3/+5`, Jackpot Ridge `+5/+3`, and Vault Drop `+5/+4`. None pays
  straight money.
- Quarter Falls centers play on large rider prizes: bank three for `+5` tokens.
  At least three riders remain available through deterministic replenishment.
- Jackpot Ridge centers play on weighted multiplier pucks: bank three
  cumulatively for a ridge run and `+5` tokens. At least four pucks remain in the
  machine through deterministic replenishment.
- Vault Drop centers play on large key fragments: each fragment unlocks a vault
  cell and every three award `+6` tokens. At least three fragments remain in the
  machine, and opening all nine cells begins a new deterministic vault cycle.
- Heavy objects retain lower-bed support and saved support anchors. They are not
  attached to the moving upper shelf, do not freeze after save/restore, and do
  not disappear permanently after their original authored schedule.
- The backglass always states the cabinet-specific objective and shows a clear
  segmented progress meter. Cup and heavy-feature hits use dedicated satisfying
  audio events.

## Final evidence

| Gate | Result |
| --- | --- |
| Focused production suite | PASS — validation, import, script loading, and exhaustive Coin Pusher foundation contract; `.tmp/test_reports/coin_pusher_finalize_focus_8/summary.json` |
| Opening/Plinko contract | PASS — 7,680 exhaustive drops, zero stuck; Quarter max cup rates `7.9167%/6.4583%`, Ridge `0.8333%/1.25%`, Vault `0.625%/3.3333%` |
| Exact platform parity | PASS — Windows native repeats exactly, Web reference repeats exactly, payloads identical; `.tmp/coin_pusher_final_parity/manifest.json` |
| Actual-GL delivery QA | PASS — three cabinets, six cup hits, three near misses; `.tmp/coin_pusher_final_delivery_gl_2/manifest.json` |
| Actual-GL feel QA | PASS — three cabinets × nine normal/reduced production scenes; `.tmp/coin_pusher_final_feel_4/manifest.json` |
| Persistent economy audit | PASS — eight shards and 200,000 accepted drops per cabinet; `.tmp/coin_pusher_final_ev_8/manifest.json` |

## Economy and goal reachability

| Cabinet | Physical ROI | Stock-adjusted interval | Cup bonus tokens | Heavy-goal tokens | Completed main goals |
| --- | ---: | ---: | ---: | ---: | ---: |
| Quarter Falls | `0.810025` | `0.810025–0.826445` | `17,596` | `16,360` | `3,272` prize rushes |
| Jackpot Ridge | `0.903210` | `0.903210–0.922730` | `4,246` | `13,525` | `2,705` ridge runs |
| Vault Drop | `0.798925` | `0.798925–0.815900` | `28,580` | `21,084` | `3,514` three-key goals |

All physical-return intervals and both shard-level 95% confidence intervals are
inside their authored bands. Cup and heavy-goal tokens are measured separately
from physical coin-to-tray return. Every shard passes token/body conservation,
origin reconciliation, target reachability, and persistent-machine assertions.

## Release-board disposition

`pusherv3_10`, `fix06_13`, and `pusherv3_11` are DONE and moved to
`docs/todone`. Final implementation `6af645b5` passes focused foundation,
native live-batch, Windows/Web input parity, cache equivalence, and the locked
fresh-export shipped-Web performance gate. The owner-directed exact-head
self-review substitution is recorded without claiming independence or waiving
technical evidence. No further Coin Pusher implementation is identified before
playtest.
