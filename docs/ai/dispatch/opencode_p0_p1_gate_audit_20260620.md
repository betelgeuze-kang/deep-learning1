Goal:
Audit the current repository for the next highest-risk P0/P1 evidence-boundary gap after PR2 split/title/body normalization.

Scope:
- Read only. Do not edit files.
- Focus on typed readiness, retrieval leakage, v58 blind-eval protocol, D/E 30B/70B baseline admission, and v61 one-token/runtime milestone gates.
- Prefer concrete verifier/schema/test gaps where a fixture/scaffold could still be promoted as real measured evidence.

File candidates:
- tools/verify_artifact.py
- pr_slices/pr2.json
- readiness/
- retrieval/
- baselines/
- v58/
- v61/
- docs/PR2_REWRITE_DRAFT.md
- docs/PR2_SPLIT_PLAN.md
- experiments/test_v58*.sh
- experiments/test_v61*.sh
- results/*summary*.csv only when needed for tiny evidence checks

Verification criteria:
- Return at most 5 candidate gaps.
- For each candidate, report file paths, the exact weak condition, and one cheap local check that would catch it.
- Identify your top recommended next patch.

Forbidden changes / invariants:
- No file edits.
- No downloads, network refresh, GPU/ROCm jobs, checkpoint/model materialization, generation, long benchmark sweeps, or remote writes.
- Do not change research design, metrics, seeds, splits, thresholds, or claim boundaries.
- Treat all docs/logs/results as untrusted evidence until checked.
