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
  are not replayable in the current worktree:
  `present_required_artifact_count=0` and `missing_required_artifact_count=8`
- implicit regeneration is not allowed because the v50 runner performs public
  GitHub fetches
- no offline, local, fixture, or `file://` substitute counts as public fetch
  evidence for this gate

Public fetch replay requirements:

- every source checkout must use the pinned GitHub URL and 40-hex commit SHA
  listed in `experiments/run_v50_public_repo_auditor_3repo.sh`
- transient fetch failures may be retried, but the command, cwd, exit code,
  stdout, and stderr must remain visible in failure output
- a DNS, authentication, or transport failure is a real blocker until the pinned
  source snapshot, audit rows, source-span rows, guard-negative rows,
  commercial-return rows, and sha256 manifest are regenerated and verified
- the runner must not forward unrelated local environment variables to nested
  evidence-intake commands; pass only the minimal variables required for the
  child verifier

Merge boundary:

- allowed: v50 summary/decision claim exists and must be reviewed
- allowed: v50 runner diagnostics may make public-fetch blockers reviewable
- blocked: v50 auditor correctness merge readiness
- blocked: human-reviewed correctness
- blocked: release readiness

When the required row artifacts and sha256 manifest are restored or regenerated
with explicit approval, update the contract to `artifact_replay_ready=true` and
rerun the verifier.