# v0.2-b Results

Current `v0.2-b` readout: weak coupling now works under the default run settings because the stage includes a block-local coupled proposal path. The tuned `proposal_count = 30` control is still useful for isolating coupling from proposal coverage, but it is no longer required just to keep `counter` healthy.

## Setup

Core coupling knobs:

- `lambda_b`
- `eta_b`

Current weak coupling:

- `lambda_b = 0.1`
- `eta_b = 0.02`

Current tuned control:

- `proposal_count = 30`

## 1. Default Dynamics

Weak coupling, same default dynamics:

- `results/v02b_counter_lv0_lb010_eb002.csv`
- `results/v02b_text_lv0_lb010_eb002.csv`

Readout:

- `counter`: `field_byte_acc = 1.000000`, `joint_byte_acc = 1.000000`, `byte_acc = 1.000000`
- `text`: `field_byte_acc = 0.687500`, `joint_byte_acc = 0.687500`, `byte_acc = 0.687500`

Interpretation:

- the default weak-coupling run now clears both the `counter` gate and the text improvement check
- the pair proposal path fixed the old relaxed-dynamics failure without changing the uncoupled path
- the default weak-coupling text run now matches the tuned weak-coupling endpoint

## 2. 5-Seed Default Regression

Main scripts:

- `experiments/run_v02b_counter_multiseed_compare.sh`
- `experiments/run_v02b_repeating_multiseed_compare.sh`

Counter, default proposal count, last-10 means over seeds `1..5`:

| Mode | byte_acc | field_byte_acc | joint_byte_acc | final field_margin |
| --- | --- | --- | --- | --- |
| control | `0.934375` | `1.000000` | `1.000000` | `0.199143` |
| weak coupling | `0.999688` | `1.000000` | `1.000000` | `0.042216` |

Repeating-text, default proposal count, last-10 means over seeds `1..5`:

| Mode | byte_acc | field_byte_acc | joint_byte_acc | final field_margin |
| --- | --- | --- | --- | --- |
| control | `0.508047` | `0.659453` | `0.659453` | `3.672140` |
| weak coupling | `0.685625` | `0.681094` | `0.685703` | `0.070575` |

Average seed-paired lift on repeating text:

- `byte_acc`: `+0.177578`
- `joint_byte_acc`: `+0.026250`

Interpretation:

- the shipped default weak-coupling path now clears the `counter` gate across five seeds
- the same shipped path improves repeating text across all five seeds, not just a single lucky run
- the default no-coupling path is no longer the right headline stage candidate; it is the comparison point that weak coupling beats

## 3. Proposal Tuning

Two targeted counter repairs were tested before the pair proposal was added:

- `results/v02b_counter_lv0_lb010_eb002_t40.csv`
- `results/v02b_counter_lv0_lb010_eb002_pc30.csv`

Both recover:

- `field_byte_acc = 1.000000`
- `joint_byte_acc = 1.000000`
- `byte_acc = 1.000000`

The cleaner repair is:

- `proposal_count = 30`

This is now best viewed as the tuned control used for the coupling comparison, not as the only stable `v0.2-b` setting.

## 4. Tuned Control vs Coupling

To isolate coupling from proposal tuning:

- no coupling, tuned proposals: `results/v02b_text_off_pc30.csv`
- weak coupling, tuned proposals: `results/v02b_text_lv0_lb010_eb002_pc30.csv`

End-of-run comparison:

| Run | field_byte_acc | joint_byte_acc | byte_acc |
| --- | --- | --- | --- |
| `text_off_pc30` | `0.597656` | `0.597656` | `0.597656` |
| `text_lv0_lb010_eb002_pc30` | `0.687500` | `0.687500` | `0.687500` |

Oracle reference:

- `oracle1_acc = 0.703125`

Interpretation:

- the tuned control is still the right isolation baseline for `v0.2-b`
- coupling adds a real gain on top of that tuned control
- the same text endpoint now also appears in the default weak-coupling run because the pair proposal path fixes the old search bottleneck

## Current Takeaway

`v0.2-b` now looks strong enough to treat as the next live stage.

- uncoupled exactness is preserved
- default weak coupling clears a 5-seed `counter` regression with average last-10 `byte_acc = 0.999688`
- default weak coupling improves 5-seed repeating text to average last-10 `byte_acc = 0.685625`
- the tuned control-vs-coupling comparison remains the cleanest way to isolate what coupling itself is buying
