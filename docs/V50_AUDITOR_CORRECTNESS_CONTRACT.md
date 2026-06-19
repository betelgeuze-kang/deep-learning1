# v50 Auditor Correctness Contract

`audits/v50_public_repo_auditor_correctness.json` separates the current v50
summary claim from replayable auditor correctness evidence.

Verify the contract with:

```bash
tools/verify_artifact.py v50-auditor-correctness audits/v50_public_repo_auditor_correctness.json \
  --summary results/v50_public_repo_auditor_3repo_summary.csv \
  --decision results/v50_public_repo_auditor_3repo_decision.csv
```

Current state:

- the summary and decision files contain a `ready=1` v50 claim
- required row artifacts under `results/v50_public_repo_auditor_3repo/audit_001/`
  are not replayable in the current worktree
- implicit regeneration is not allowed because the v50 runner performs public
  GitHub fetches

Merge boundary:

- allowed: v50 summary/decision claim exists and must be reviewed
- blocked: v50 auditor correctness merge readiness
- blocked: human-reviewed correctness
- blocked: release readiness

When the required row artifacts and sha256 manifest are restored or regenerated
with explicit approval, update the contract to `artifact_replay_ready=true` and
rerun the verifier.
