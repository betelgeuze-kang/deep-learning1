Goal:
Probe the current audit_my_repo benchmark harness for the smallest executable change that improves design-partner beta label quality without network downloads or external repos.

Scope:
- Read only these files unless you need one nearby schema/test reference:
  - scripts/audit_my_repo_benchmark.py
  - experiments/test_audit_my_repo_negative_controls.sh
  - schemas/local_repo_audit_benchmark_summary.schema.json
  - schemas/local_repo_audit_benchmark_manifest.schema.json
  - docs/AUDIT_MY_REPO_ALPHA.md

File candidates:
- No edits are required for this probe.
- If you do edit despite the probe scope, keep it tiny and report the exact diff.

Verification criteria:
- Identify whether real_benchmark readiness can currently be calculated from labels that are too broad, contradictory, duplicate, or not citation-bound.
- Propose a concrete minimal product/test change that records label quality separately and keeps release/public/model readiness false.
- Mention exact test assertions that should be added.

Forbidden changes / invariants:
- Do not merge or cherry-pick branches.
- Do not download anything or use network/GPU/checkpoints.
- Do not change beta thresholds, benchmark metric definitions, evidence boundaries, or readiness false flags.
- Do not run long tests; syntax-only or grep/read-only checks are enough.
