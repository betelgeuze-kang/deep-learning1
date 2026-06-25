# v54 reference training and generation emission

Reference mechanics for turning the v54 contract/replay primitives into an
actual trainable model and a v54f-schema generation writer. Built on the #21
reference scorer/generator.

- Tooling: [`scripts/v54_reference_training.py`](../scripts/v54_reference_training.py)
- Smoke test: [`scripts/test_v54_reference_training.py`](../scripts/test_v54_reference_training.py)
- Generation row schema source of truth:
  [`v54/free_running_generation_evidence_intake_contract.json`](../v54/free_running_generation_evidence_intake_contract.json)

## What it provides

- **External-label loader** (`load_external_labels`): reads a labeled-candidate
  CSV into pairwise training pairs and classifies provenance. Local / `file://`
  / missing-provenance / non-HTTPS labels keep
  `external_label_source_ready=0` (local labels are not real external labels).
- **Scorer training** (`train_pairwise_scorer`, re-exported): fits the linear
  route scorer on the loaded pairs.
- **GRU training loop** (`train_generator`): deterministic, teacher-forced
  training of the tiny non-attention GRU via central-difference numerical
  gradients (correct by construction; demo sizes only).
- **Checkpoint / config hash** (`checkpoint`): serializes scorer + generator +
  config and records a `checkpoint_sha256` for reproducibility.
- **Unseen-repo validation** (`validate_unseen`): evaluates on a supplied
  unseen-repo eval set (e.g. the v53 2-repo / 200-query split); keeps
  `heldout_metric_ready=0` unless a real source is supplied.
- **Generation writer** (`emit_generation_rows` / `emit-generation` CLI): writes
  v54f free-running-generation rows that satisfy the mechanical constraints
  (`free_running_decode=1`, `teacher_forcing_used=0`, `raw_prompt_context_bytes=0`,
  `source_locator_leakage=0`, `external_api_used=0`) and leaves evaluator-only
  fields blank.

```bash
python3 scripts/v54_reference_training.py emit-generation \
  --queries queries.csv --out v54f_generation_rows.csv
```

## Boundary (important)

This is an **untrained-by-default reference scaffold**, not real generation
evidence:

- the GRU is tiny and trained only on caller-supplied fixture sequences; its
  output is not a meaningful answer,
- nothing here writes `results/` admission artifacts, edits a contract, or flips
  `readiness/typed_ready.json`,
- `real_model_generation_ready`, `heldout_metric_ready`, and
  `external_label_source_ready` stay `0`.

v54 closure still requires a **real model**, **verified external labels**, and a
**heldout metric**, ingested through the canonical
`experiments/test_v54f_free_running_generation_evidence_intake.sh`. Feeding the
reference rows through that intake keeps the real flags `0` by design; the
writer is a schema/staging aid, not evidence.
