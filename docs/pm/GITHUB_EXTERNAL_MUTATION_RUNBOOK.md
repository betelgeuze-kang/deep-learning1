# GitHub External Mutation Runbook

This runbook is for the human-approved phase after the local governance,
readiness, and CI changes have been reviewed. It does not grant approval by
itself. Do not run any mutating command until the human owner explicitly
approves the exact batch.

## 0. Preflight

Run the read-only snapshot refresh first:

```bash
python3 scripts/refresh_github_external_snapshots.py
```

Then run local verification:

```bash
python3 tools/verify_github_governance_commands.py
python3 tools/verify_pr_cleanup_disposition_commands.py
python3 tools/verify_repo_governance.py .
python3 tools/verify_github_external_state.py --mode pending .
tools/verify_ci_workflows.py .
tools/verify_artifact.py typed-readiness readiness/typed_ready.json --pm-ledger results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_ready_semantic_rows.csv
./scripts/ai-verify.sh
```

Default `./scripts/ai-verify.sh` uses `DLE_GITHUB_EXTERNAL_STATE_MODE=pending`.
`DLE_GITHUB_EXTERNAL_STATE_MODE=complete` is expected to fail before approved
external mutations have created labels, issues, PR cleanup comments, final PR
dispositions, repository settings evidence, and security settings evidence.

Review these files before proceeding:

- `docs/pm/EXTERNAL_MUTATION_APPROVAL_PACKET.md`
- `docs/pm/pasted_goal_completion_audit.json`
- `docs/pm/PASTED_GOAL_COMPLETION_AUDIT.md`
- `docs/pm/PR_CLEANUP_DISPOSITION_COMMANDS.md`
- `docs/pm/github_external_state_snapshot.json`
- `docs/pm/github_settings_external_snapshot.json`

## 1. Labels

Create or update the required labels only after explicit human approval.

Generate the reviewable commands:

```bash
python3 tools/verify_github_governance_commands.py
python3 scripts/print_github_governance_commands.py
```

The command verifier checks that every generated issue command uses exactly the labels declared for that issue in `docs/pm/github_issue_drafts.json`, and that each title is paired with its reviewed body file.

Run only the `gh label create` block if the owner approved the label batch.
Afterwards, re-run:

```bash
python3 scripts/refresh_github_external_snapshots.py
```

Expected postcondition:

- `required_labels_missing` in `docs/pm/github_external_state_snapshot.json`
  is empty.
- The `superseded` label exists so PR #5/#10 can use the close-as-superseded
  path when the owner explicitly approves that disposition.

## 2. Evidence Blocker Issues

Create the five epic issues only after explicit human approval:

- `[P0] v53 frozen benchmark canonicalization`
- `[P0] D/E 30B-70B real evidence intake`
- `[P1] v54 real free-running generation`
- `[P1] v58 blind human review execution`
- `[P2] v61 one-token logits parity`

Use the `gh issue create` commands printed by:

```bash
python3 tools/verify_github_governance_commands.py
python3 scripts/print_github_governance_commands.py
```

Expected postcondition:

- The five issues exist in GitHub with the labels from
  `docs/pm/github_issue_drafts.json`.
- Fixture-only status remains explicit in issue bodies.
- `python3 tools/verify_github_external_state.py --mode complete .` confirms
  each issue body still contains the required scope, readiness transition,
  artifact, claim-boundary, blocked-claim, and verification anchors.

## 3. PR #5 and PR #10 Cleanup Comments

Comment on PR #5 and PR #10 only after explicit human approval. Use the
`gh pr comment 5` and `gh pr comment 10` commands printed by:

```bash
python3 tools/verify_github_governance_commands.py
python3 scripts/print_github_governance_commands.py
```

Then decide, manually and separately, whether each PR should be rebased,
cherry-picked, closed, or merged after the durable slice has been handled. Do
not merge either PR merely because the cleanup comment was posted. Leaving a
PR open is still a pending blocker disposition, not a completed cleanup.
If a PR is confirmed superseded by current `main`, apply the `superseded` label
before closing it.

Expected postcondition:

- PR #5 and PR #10 have visible cleanup comments.
- `python3 tools/verify_github_external_state.py --mode complete .` confirms
  cleanup comment anchors are present for both PRs.
- `python3 tools/verify_github_external_state.py --mode complete .` also
  confirms both PRs are no longer long-lived open blockers: each must be
  closed or merged, and `pr_cleanup_disposition_pending` must be empty.
- Any merge/close/rebase action has its own explicit approval.

For the superseded-close path only, review the exact command block in:

```bash
python3 tools/verify_pr_cleanup_disposition_commands.py
cat docs/pm/PR_CLEANUP_DISPOSITION_COMMANDS.md
```

## 4. GitHub Settings

Apply settings manually in GitHub Settings using:

- `docs/pm/github_settings_checklist.json`
- `docs/pm/github_settings_external_snapshot.json`

Recommended order:

1. Keep default `GITHUB_TOKEN` permission at read-only.
2. Enable automatic head-branch deletion after merge.
3. Require full SHA-pinned Actions where the repository Actions policy exposes
   that setting.
4. Prefer one merge method, ideally squash merge for claim-bound slices.
5. Enable available security features such as CodeQL default setup, secret
   scanning, dependency graph, and Dependabot alerts.
6. Configure branch protection when the repository plan allows it.

Known limitation:

- Branch protection currently reports `HTTP 403` with the message
  `Upgrade to GitHub Pro or make this repository public to enable this feature.`
  Do not treat branch protection as complete until GitHub reports it available
  and configured with required pull request reviews, the `AI verify`/PR-safe
  status check, conversation resolution, force-push blocking, and branch-deletion
  blocking.
- SHA-pinning policy, CodeQL default setup, secret scanning, dependency graph,
  vulnerability alerts, and Dependabot alerts are read back into
  `docs/pm/github_settings_external_snapshot.json`. Do not treat settings as
  complete until `python3 tools/verify_github_external_state.py --mode complete .`
  confirms SHA pinning is required and those security features are enabled or
  configured.

## 5. License Decision

The current `LICENSE` intentionally does not grant public reuse. A public reuse
license requires a human policy decision. Do not replace the license as part of
label, issue, PR cleanup, or settings batches unless the owner explicitly
approves that license change.

## 6. Post-Mutation Verification

After any approved external mutation batch, refresh the read-only snapshots and
run the local governance checks:

```bash
python3 scripts/refresh_github_external_snapshots.py
python3 tools/verify_github_governance_commands.py
python3 tools/verify_pr_cleanup_disposition_commands.py
python3 tools/verify_repo_governance.py .
```

For a partial batch, inspect the refreshed snapshots and run partial-mode
verification. `--mode partial` accepts reviewed intermediate states where some
labels, issues, PR dispositions, repository settings, security features, or
license decisions remain intentionally pending.

```bash
python3 tools/verify_github_external_state.py --mode partial .
DLE_GITHUB_EXTERNAL_STATE_MODE=partial ./scripts/ai-verify.sh
```

Only after the final approved batch has completed every external requirement,
run complete-mode verification:

```bash
python3 tools/verify_github_external_state.py --mode complete .
DLE_GITHUB_EXTERNAL_STATE_MODE=complete ./scripts/ai-verify.sh
```

Then update `docs/pm/pasted_goal_completion_audit.json` and
`docs/pm/PASTED_GOAL_COMPLETION_AUDIT.md` only if the refreshed evidence proves
that a requirement advanced. Do not mark the pasted goal complete unless every
requirement is proven complete and no explicit approval item remains.
