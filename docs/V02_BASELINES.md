# v0.2-pre Baselines

Current locked references for the `v0.2-pre` stage. These are the comparison runs for any `v0.2-b` work.

Recommended stage order:

1. Implement `v0.1`.
2. Run `v0.1` smoke tests.
3. Implement `v0.2-pre`.
4. Run counter with `lambda_v = 0`.
5. Run counter `lambda_v` ablation.

## Locked Results

| Run | Start | End | Readout |
| --- | --- | --- | --- |
| `counter_lv0.csv` | `field_margin=-0.008392`, `field_byte_acc=0.007812`, `byte_acc=0.007812` | `field_margin=0.197930`, `field_byte_acc=1.000000`, `byte_acc=0.960938` | Best current correctness gate |
| `counter_lv005.csv` | `field_margin=-0.008392`, `field_byte_acc=0.007812`, `byte_acc=0.101562` | `field_margin=0.276112`, `field_byte_acc=0.281250`, `byte_acc=0.929688` | Ablation reference |
| `counter_lv025.csv` | `field_margin=-0.008392`, `field_byte_acc=0.007812`, `byte_acc=0.070312` | `field_margin=0.695805`, `field_byte_acc=0.343750`, `byte_acc=0.937500` | Ablation reference |
| `text_lv0.csv` | `field_margin=-0.007421`, `field_byte_acc=0.000000`, `byte_acc=0.000000`, `oracle1_acc=0.703125` | `field_margin=3.682054`, `field_byte_acc=0.644531`, `byte_acc=0.484375` | Field signal improves, but text still trails `oracle1_acc` |

## Current Readout

- `counter_lv0` is the cleanest locked baseline for field learning.
- Nonzero `lambda_v` is diagnostic, not a replacement for the `lambda_v = 0` gate.
- `text_lv0` shows meaningful field learning, but `byte_acc` is still below `oracle1_acc`.
- These CSVs are the locked comparison set for any `v0.2-b` evaluation.

See the companion gate checklist in [V02B_CHECKLIST.md](V02B_CHECKLIST.md).
