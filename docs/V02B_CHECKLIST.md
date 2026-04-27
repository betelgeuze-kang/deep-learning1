# v0.2-b Go/No-Go Checklist

No-go unless the `v0.2-pre` baselines in [V02_BASELINES.md](V02_BASELINES.md) stay locked and the new coupling produces a real metric gain on the same benchmarks.

## Gate

- Compare against `counter_lv0.csv`, `counter_lv005.csv`, `counter_lv025.csv`, and `text_lv0.csv`.
- Use the same dataset, seed, `N`, epochs, and cycles-per-epoch when possible.
- Treat the `counter` run with `lambda_v = 0` as the primary yardstick.

## Pass Criteria

- the default weak-coupling 5-seed `counter` run keeps positive `field_margin` on every seed, last-10 `field_byte_acc = 1.0`, last-10 `joint_byte_acc = 1.0`, and last-10 `byte_acc` stays effectively at 1.0
- `v0.2-b` beats the default no-coupling path on the same 5-seed `counter` setup without weakening field exactness
- `counter_lv005` and `counter_lv025` remain diagnostic baselines, not the target to optimize.
- the default weak-coupling 5-seed `repeating-text` run beats the default no-coupling path in average `byte_acc` and `joint_byte_acc`, and every seed shows a positive `byte_acc` lift
- `text_lv0` still moves `field_byte_acc` toward `oracle1_acc` and does not collapse `byte_acc`
- any gain from `B[x, high, low]` is visible in the byte metrics, not only in `H` or dynamics side effects

## No-Go Triggers

- `field_margin` goes non-positive on any weak-coupling `counter` seed
- `field_byte_acc` or `joint_byte_acc` drop off the exactness plateau on the weak-coupling `counter` regression
- `byte_acc` on the weak-coupling `counter` regression no longer stays effectively exact
- text performance improves only cosmetically while `byte_acc` or `joint_byte_acc` stop beating the default no-coupling path
- the new coupling only changes dynamics, not predictive quality

## Decision

- Go: the new coupling improves the locked baselines on the same evaluation setup.
- No-go: keep `v0.2-b` out of the tree and re-debug `v0.2-pre` instead.
