# Local Changeset PR Draft

## Scope

This PR aligns repository-visible governance, readiness wording, and CI safety
with the pasted 2026-06-24 goal. It keeps all readiness claims typed and
evidence-bounded, and it does not promote fixture-only or locally replayed
results into real external evidence.

Primary local changes:

- Split the old `v53-v54-query-evaluation-pipeline` central readiness row into
  `v53-benchmark-foundation` and `v54-free-running-generation`.
- Shrink `README.md` and `README.ko.md` into current readiness dashboards and
  move historical material to `docs/archive/IMPLEMENTATION_HISTORY.md`.
- Add issue/PR governance templates, labels, epic issue drafts, PR cleanup
  drafts, CODEOWNERS, contribution/security/license boundaries, and GitHub
  settings checklist files.
- Harden GitHub Actions security for PR-safe verification and third-party rerun
  capture.
- Add `tools/verify_repo_governance.py` and wire it into
  `./scripts/ai-verify.sh`.

## Readiness transition

Readiness transition:

- `v53-benchmark-foundation`: `contract_ready=true`,
  `fixture_execution_ready=true`, real/heldout/human/independent/release remain
  false.
- `v54-free-running-generation`: `contract_ready=true`,
  `fixture_execution_ready=true`, real/heldout/human/independent/release remain
  false.
- D/E baselines, v58, and v61 remain blocked at their documented typed
  readiness boundaries.

Canonical files:

- `readiness/typed_ready.json`
- `schemas/typed_readiness.schema.json`
- `benchmarks/v53_source_bound_freeze.json`
- `v54/free_running_generation_evidence_intake_contract.json`
- `results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_ready_semantic_rows.csv`

## Claim boundary

Allowed claim:

- v53 benchmark foundation is frozen as a machine-verifiable fixture foundation
  with the evidence path recorded in central readiness.
- v54 free-running generation has fixture-ready intake contract coverage.
- Governance artifacts are locally present and machine-verified.
- GitHub external actions are prepared, not executed.

Blocked claims:

- Real D/E 30B-70B evidence has not been ingested.
- v54 has not run real free-running model generation.
- v58 blind human review has not been executed.
- v61 one-token logits parity has not been proven with real checkpoint
  payloads.
- GitHub labels, issues, PR comments, settings, or branch protections are not
  changed by this local PR draft.

## Evidence

Evidence paths:

- `readiness/typed_ready.json`
- `benchmarks/v53_source_bound_freeze.json`
- `docs/pm/EVIDENCE_BACKLOG.md`
- `docs/pm/github_issue_drafts.json`
- `docs/pm/github_external_state_snapshot.json`
- `docs/pm/github_settings_external_snapshot.json`
- `docs/pm/GITHUB_EXTERNAL_MUTATION_RUNBOOK.md`
- `docs/pm/pasted_goal_completion_audit.json`
- `docs/pm/PASTED_GOAL_COMPLETION_AUDIT.md`

Artifact and governance contracts:

- `tools/verify_artifact.py`
- `tools/verify_ci_workflows.py`
- `tools/verify_repo_governance.py`
- `scripts/print_github_governance_commands.py`

## GitHub Actions security

The workflow changes are intended to keep PR execution on GitHub-hosted
infrastructure with read-only permissions and SHA-pinned third-party actions.
The trusted self-hosted path is limited to non-PR events. The third-party rerun
workflow passes `return_id` through an environment variable, validates it with a
strict regex, rejects `..`, and records self-hosted replay evidence as local,
non-independent, and not clean-machine evidence.

## Verification

Required verification before opening or updating the PR:

```bash
python3 scripts/refresh_github_external_snapshots.py
python3 -m py_compile tools/verify_github_governance_commands.py tools/verify_pr_cleanup_disposition_commands.py tools/verify_repo_governance.py scripts/print_github_governance_commands.py tools/verify_ci_workflows.py tools/verify_artifact.py
python3 tools/verify_github_governance_commands.py
python3 tools/verify_pr_cleanup_disposition_commands.py
python3 tools/verify_repo_governance.py .
python3 tools/verify_github_external_state.py --mode pending .
python3 tools/verify_github_external_state.py --mode partial .
tools/verify_ci_workflows.py .
tools/verify_artifact.py typed-readiness readiness/typed_ready.json --pm-ledger results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_ready_semantic_rows.csv
git diff --check
./scripts/ai-verify.sh
```

The default verification mode is pending. After partial approved external
mutations, use `DLE_GITHUB_EXTERNAL_STATE_MODE=partial ./scripts/ai-verify.sh`;
after the final approved mutation batch, use
`DLE_GITHUB_EXTERNAL_STATE_MODE=complete ./scripts/ai-verify.sh` with refreshed
snapshots.

## External pending

External pending actions require explicit human approval and are deliberately
not executed by this PR draft:

- Create labels from `.github/labels.yml`.
- Create the five epic evidence-blocker issues.
- Comment on or otherwise mutate PR #5 and PR #10.
- Apply repository settings from `docs/pm/github_settings_checklist.json`.
- Decide whether to replace the conservative `LICENSE` boundary with a public
  reuse license.

The approved execution order is documented in
`docs/pm/GITHUB_EXTERNAL_MUTATION_RUNBOOK.md`.
After approved external mutations, `tools/verify_github_external_state.py
--mode complete` must prove the GitHub issue body anchors and PR cleanup
comment anchors, and must prove PR #5/#10 are closed or merged rather than
left as long-lived open blockers. It must also prove settings/security features
such as CodeQL default setup, secret scanning, dependency graph, vulnerability
alerts, and Dependabot alerts are enabled or configured before the completion
audit can advance.
