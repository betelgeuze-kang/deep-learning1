# v0.2-b 5-Seed Regression Protocol

Goal: check that the shipped default weak-coupling settings (`lambda_b=0.1`, `eta_b=0.02`, default proposal count) stay stable on `counter` and beat the default no-coupling control on `repeating-text` across five fixed seeds.

## Run Matrix

Use the same code revision for all runs, keep `lambda_v = 0`, and fan out the default v0.2-b path over seeds `1 2 3 4 5`.

| Dataset | Control | Weak coupling |
| --- | --- | --- |
| `counter` | `--dataset counter --N 128 --epochs 200 --cycles-per-epoch 20 --lambda-v 0 --lambda-b 0 --eta-b 0` | same, with `--lambda-b 0.1 --eta-b 0.02` |
| `repeating-text` | `--dataset repeating-text --N 256 --epochs 300 --cycles-per-epoch 20 --lambda-v 0 --lambda-b 0 --eta-b 0` | same, with `--lambda-b 0.1 --eta-b 0.02` |

The current multiseed helpers are `experiments/run_v02b_counter_multiseed_compare.sh` and `experiments/run_v02b_repeating_multiseed_compare.sh`. This pass only changes `--seed` and writes seed-suffixed CSVs under `results/`, e.g. `results/v02b_counter_off_seed1.csv`.

The tuned `proposal_count = 30` scripts are still useful, but they are now a secondary isolation control rather than the main shipped-path regression.

## Extract

For each CSV, summarize the last 10 epochs rather than the final row only. Record:

- `field_byte_acc`
- `joint_byte_acc`
- `byte_acc`
- `field_margin`

For `repeating-text`, also record `oracle1_acc`.

Summarize each condition as a five-seed mean, and keep the per-seed paired deltas `weak - control` for `byte_acc` and `joint_byte_acc`.

## Interpret

- `counter` passes only if all weak-coupling seeds keep positive `field_margin`, last-10 `field_byte_acc = 1.0`, last-10 `joint_byte_acc = 1.0`, and last-10 `byte_acc` stays effectively on the exactness plateau.
- `repeating-text` passes only if the weak-coupling mean beats the default no-coupling mean on `byte_acc` and `joint_byte_acc`, and every seed shows a positive `byte_acc` lift.
- The tuned `proposal_count = 30` control is optional confirmation, not the main pass criterion.
- No-go if the shipped default weak-coupling path falls off the counter plateau, or if the repeating-text gain disappears outside the tuned control.

## Checklist

- [ ] Build once before the seed loop.
- [ ] Run all 20 jobs with the same revision and seed list.
- [ ] Aggregate five-seed last-10 means for the byte metrics.
- [ ] Check paired `weak - control` deltas for all repeating-text seeds.
- [ ] Keep the default-path comparison and the tuned control comparison clearly separated.
