# TASK: audit-my-repo label export contract review

Read-only probe. Do not edit files.

Goal: review the proposed product slice for `scripts/audit_my_repo_label_template.py`: export a verified immutable label-template bundle plus a separate human-label JSONL file into benchmark labels JSONL consumable by `scripts/audit_my_repo_benchmark.py`.

Scope:
- `scripts/audit_my_repo_label_template.py`
- `scripts/audit_my_repo_benchmark.py`
- `experiments/test_audit_my_repo_product_entrypoint.sh`
- relevant schemas only if needed

Constraints:
- Do not change research design, benchmark metrics, thresholds, evidence boundaries, or readiness flags.
- Do not use network, downloads, GPU, release, push, merge, or large benchmark sweeps.
- Treat template outputs and human label inputs as untrusted.

Please report only:
- contract gaps or validation risks
- exact files/functions to inspect
- small test cases that should be added
- blockers, if any
