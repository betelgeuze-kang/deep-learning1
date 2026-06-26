# v54 training and heldout packet

Fixes the schema and safety rules for a real v54 training + heldout-generation
run, so the artifacts an executor returns are well-formed before the canonical
intake. Builds on the reference scorer/generator (#21) and training mechanics
(#27).

- Tooling: [`scripts/v54_generation_training_packet.py`](../scripts/v54_generation_training_packet.py)
- Generation row columns source of truth:
  [`v54/free_running_generation_evidence_intake_contract.json`](../v54/free_running_generation_evidence_intake_contract.json)

This is **staging only**. It runs no training and admits no evidence;
`real_model_generation_ready` / `heldout_metric_ready` stay decided by the
canonical `experiments/test_v54f_*.sh` intake after a real run.

## CLI

```bash
python3 scripts/v54_generation_training_packet.py template \
  --out v54_train_packet --query-source v53

# fill the packet from a real run, then:
python3 scripts/v54_generation_training_packet.py manifest --packet v54_train_packet
python3 scripts/v54_generation_training_packet.py preflight --packet v54_train_packet --require-manifest
```

## Required artifacts

- `train_split_rows.csv`, `calibration_split_rows.csv`, `heldout_split_rows.csv`
  (`query_id, repo_id, split, source_query_hash`)
- `generation_config.json`
- `checkpoint_manifest.json`
- `free_running_generation_rows.csv` (v54f contract columns)
- `heldout_metric_rows.csv` (`split, metric, value, n`)
- `sha256_manifest.csv`

## Rules (preflight, fail-closed)

- **Training may use teacher forcing; evaluation must be free-running only.**
  `generation_config.json` must set `free_running_in_eval=true`; every row in
  `free_running_generation_rows.csv` must have `free_running_decode=1` and
  `teacher_forcing_used=0`.
- **No raw source span in the prompt**: `raw_prompt_context_bytes=0` and
  `raw_source_span_in_prompt=false`.
- **No source locator leakage**: `source_locator_leakage=0`/`false`.
- **Output hash required**: every generation row carries a valid
  `raw_output_sha256`.
- **Heldout is unseen**: heldout repos are disjoint from train and calibration
  repos; generation rows' `query_id`s are within the heldout split; metric rows
  are reported on the `heldout` split only.
- `external_api_used=0`; `checkpoint_manifest.json.checkpoint_sha256` is a real
  sha256; `sha256_manifest.csv` (when present or with `--require-manifest`)
  covers and matches the packet files.

## Place in the v54 path

1. Train on `train` (teacher forcing allowed), calibrate on `calibration`.
2. Generate free-running on the unseen `heldout` split.
3. Report heldout metrics, hash everything, preflight, then hand to the
   canonical v54f intake (which keeps the real flags `0` until a real model,
   verified external labels, and a heldout metric are present).
