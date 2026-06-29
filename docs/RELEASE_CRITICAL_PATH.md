# Release Critical Path

This is the single v1.0 path. Treat every other versioned packet as supporting
evidence unless it is named below.

## One Path

```text
minimal local execution
-> real-model heldout metric
-> human blind review/adjudication
-> independent reproduction
-> release packet audit
```

## Current State

| Step | Status | Evidence |
|---|---|---|
| Minimal local execution | closed | `./scripts/run_minimal_demo.sh` runs `dmv02` and writes `results/minimal_demo/minimal_demo_summary.csv` |
| Real-model heldout metric | closed | `scripts/v54_minimal_real_model_smoke.py` writes `results/v54_minimal_real_model_smoke_summary.csv`; `v54-free-running-generation.real_model_execution_ready=1` and `heldout_metric_ready=1` |
| Human blind review/adjudication | open | `scripts/release_review_collection.py` can collect actual returned rows; no actual human rows are supplied in this worktree |
| Independent reproduction | open | `scripts/release_review_collection.py` can collect an actual independent reproduction row; no actual independent reproducer return is supplied in this worktree |
| Release packet audit | open | `release_ready=0` until the two open steps above are real, non-fixture evidence |

## Release Gates That Count

Only these gates are on the v1.0 critical path:

- `v54-free-running-generation`: at least one real local model execution plus a heldout metric.
- `v58-blind-eval`: actual blind human review rows, inter-rater report, and adjudication rows.
- `operator-review-return-workflow`: returned packet integrity, reviewer identity/conflict fields, and no fixture promotion.
- `v60-release`: final release audit after the same artifact set has an independent reproduction packet.

Everything else is non-critical for v1.0 unless it directly feeds one of those
four gates. In particular, v61 real 100B inference, optional 100B+ baseline F,
full external benchmark publication chains, and extra versioned scaffold packets
must not block this release path unless the release scope is explicitly changed.

## Next Required Human Work

No agent should fabricate these rows. The next release-blocking work is actual
collection:

1. Fill the v58 blind response/review packet with real reviewer rows from two
   independent reviewer pools.
2. Run v58 completeness and kappa checks, then adjudicate every disagreement.
3. Give one independent reproducer the exact release candidate command packet.
4. Collect the reproducer's environment, command transcript, output hashes,
   metric rows, and signed/declared independence/conflict fields.
5. Re-run the release audit only after those artifacts exist.

## Collection Command

Create the return inbox:

```bash
python3 scripts/release_review_collection.py template \
  --out /secure/v1_0_human_independent_return
```

After reviewers and an independent reproducer fill the CSVs, collect them:

```bash
python3 scripts/release_review_collection.py collect \
  --input-dir /secure/v1_0_human_independent_return \
  --out results/release_review_collection/collection_001 \
  --summary results/release_review_collection_summary.csv \
  --decision results/release_review_collection_decision.csv
```

The intake rejects template-only, synthetic, example, and test-fixture rows in
actual mode. It hash-binds accepted return files and may set
`actual_collection_ready=1`, but it still keeps `human_review_ready=0`,
`independent_reproduction_ready=0`, and `release_ready=0` until the canonical
v58/operator/v60 promotion gates consume those artifacts.

## User-Facing Demo

Run:

```bash
./scripts/run_minimal_demo.sh
```

Expected outputs:

- `results/minimal_demo/dmv02_counter_smoke.csv`
- `results/v54_minimal_real_model_smoke_summary.csv`
- `results/v54_minimal_real_model_smoke_decision.csv`
- `results/v54_minimal_real_model_smoke/smoke_001/sha256_manifest.csv`

The demo proves local execution and the minimal heldout metric only. It does not
claim human review, independent reproduction, public comparison, or release
readiness.
