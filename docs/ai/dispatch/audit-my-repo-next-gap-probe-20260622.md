# TASK: audit-my-repo next product gap probe

Context:
- Active goal: move `audit-my-repo` from internal alpha toward design-partner beta candidate.
- Scope is only the local code/doc/config audit product. Do not touch SSD-MoE, v61, model, checkpoint, GPU, or external network work.
- Current worktree already has large audit-product changes: atomic publish, split quick/full budgets, parser-bound deprecated API checks, unsupported-claim negation controls, allowlist/suppression, benchmark harness, first-report smoke, package manifest, PR wrapper, SARIF/JSON/dashboard/baseline/diagnostics.
- Codex wants one more small execution-code improvement, not documentation-only work.

Please do:
- Inspect current files and identify 2-4 remaining gaps that are both:
  1. directly relevant to the active goal or acceptance list, and
  2. feasible as a small product/test slice.
- Prefer gaps where current tests might pass but a product integrity requirement is still weak.
- Do not edit files.
- Do not run network, downloads, GPU, release, push, merge, or long benchmarks.

Good places to inspect:
- `scripts/audit_my_repo.py`
- `tools/verify_local_audit.py`
- `scripts/audit_my_repo_benchmark.py`
- `scripts/audit_my_repo_first_report_smoke.py`
- `scripts/audit_my_repo_package.py`
- `experiments/test_audit_my_repo_negative_controls.sh`
- `experiments/test_audit_my_repo_product_entrypoint.sh`
- `docs/AUDIT_MY_REPO_ALPHA.md`

Report format:
- Top recommendation: file(s), exact weakness, why it matters, suggested test.
- Other candidates: one short paragraph each.
- Any “do not touch now” risks.

Do not:
- Make code changes.
- Propose broad refactors unless they close a concrete acceptance gap.
- Reclassify fixture/synthetic evidence as real evidence.
