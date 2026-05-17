# v0.3 Routing Probe Scaffold

This is not the real sparse-routing stage yet.

Current status:

The active jump-neighbor line remains no-go/default-off/diagnostic-only. The
later successful nonlocal path is not this probe and not remote-neighbor
replacement. It is:

```text
candidate value_pos -> value byte read -> proposal hint
```

As of h7-a, route-quality and symbolic span route-memory diagnostics are
covered by [V03_ROUTE_HINT_ORACLE.md](V03_ROUTE_HINT_ORACLE.md),
[V06_ROUTE_MEMORY.md](V06_ROUTE_MEMORY.md), and [V07_GOAL.md](V07_GOAL.md).
This document remains the historical read-only routing-probe record.

Current scope:

- add an O(1)-candidate `RoutingTable` keyed by a fixed per-epoch route source
- add trigger-based routing diagnostics to the CSV
- keep the existing `v0.2-b` dynamics and learning path unchanged

Current CLI surface:

- `--K-jump`
- `--route-source`
- `--route-reservoir-threshold`

Current routing sources:

- `none`
- `input-byte`
- `joint-code`

Probe helper:

- `experiments/run_v03_routing_probe.sh`
- `experiments/run_v03_routing_fixture_compare.sh`
- `data/routing_probe_fixture.txt`

Latest `repeating-text` probe readout, weak coupling, seed `1`, `80` epochs:

| Run | byte_acc | field_byte_acc | joint_byte_acc | routing_trigger_rate | mean_jump_candidates | routing_hit_rate |
| --- | --- | --- | --- | --- | --- | --- |
| `v03_routing_probe_off.csv` | `0.687500` | `0.687500` | `0.687500` | `0.000000` | `0.000000` | `0.000000` |
| `v03_routing_probe_input_byte.csv` | `0.687500` | `0.687500` | `0.687500` | `1.000000` | `1.781250` | `1.000000` |
| `v03_routing_probe_joint_code.csv` | `0.687500` | `0.687500` | `0.687500` | `1.000000` | `1.859375` | `1.000000` |

Latest fixture probe readout on `data/routing_probe_fixture.txt`, weak coupling, seed `1`, `80` epochs:

| Run | byte_acc | field_byte_acc | joint_byte_acc | routing_trigger_rate | mean_jump_candidates | routing_hit_rate |
| --- | --- | --- | --- | --- | --- | --- |
| `v03_routing_fixture_off.csv` | `0.242188` | `0.210938` | `0.253906` | `0.000000` | `0.000000` | `0.000000` |
| `v03_routing_fixture_input_byte.csv` | `0.242188` | `0.210938` | `0.253906` | `0.996094` | `1.800000` | `0.992157` |
| `v03_routing_fixture_joint_code.csv` | `0.242188` | `0.210938` | `0.253906` | `0.996094` | `1.886275` | `0.996078` |

Interpretation:

- the scaffold exposes O(1)-candidate routing diagnostics without perturbing the current dynamics
- this is a read-only candidate probe, not a jump-edge update rule
- `joint-code` is still a per-epoch fixed candidate source, not routing plasticity
- on both `repeating-text` and the committed fixture, `joint-code` gives slightly denser candidate coverage than `input-byte` without changing predictive metrics
- no sparse-routing quality claim should be made from this result alone

Constraints that still hold:

- do not claim long-context retrieval yet
- do not claim chunk/token routing yet
- do not enable real jump-edge dynamics until meaningful codes exist beyond the current raw-byte stage

See [V03_STATIC_ROUTING.md](V03_STATIC_ROUTING.md) for the separate default-off active jump-neighbor slice.
