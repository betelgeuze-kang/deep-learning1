# TASK: pipeline maintenance migration audit

Goal:
Audit the current shell workflow sprawl and identify the highest-leverage migration targets for the new declarative pipeline layer.

Scope:
- Read only unless a tiny doc correction is clearly needed.
- Inspect `experiments/run_*.sh`, `experiments/test_*.sh`, `README.md`, `docs/EXPERIMENTS.md`, and the new `docs/PIPELINE_MIGRATION.md`, `schemas/pipeline.schema.json`, `pipelines/*.yaml`, `tools/run_pipeline.py`, `tools/verify_artifact.py`, `tools/build_manifest.py`.

Questions to answer:
- Which repeated embedded-Python patterns appear most often?
- Which copy-forward summary/hash/CSV helpers should become the first shared Python library functions?
- Which v52-v61 shell adapters should be migrated first to reduce drift risk?
- Which downstream ready=1 propagation patterns are riskiest?
- Does the new pipeline schema miss any field needed to represent claim boundary, typed readiness, model-visible inputs, evaluator-only fields, or blocker evidence?

Return only:
- files inspected
- top 5 repeated patterns with concrete file examples
- top 5 migration targets ordered by risk reduction
- schema gaps, if any
- recommended next PR slice

Forbidden:
- Do not edit experiment semantics, seeds, splits, metrics, baselines, evidence thresholds, generated results, or docs except for a trivial typo.
- Do not run long benchmarks, network, GPU/ROCm, downloads, or remote writes.
