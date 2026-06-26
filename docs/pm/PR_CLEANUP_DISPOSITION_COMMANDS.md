# PR Cleanup Disposition Commands

These commands are prepared for the human-approved phase only. They are not a
request to run them. Do not execute any command below until the owner explicitly
approves the exact PR number and disposition.

## Batch E: Superseded-Close PR Disposition

This file belongs only to Batch E from
`docs/pm/EXTERNAL_MUTATION_APPROVAL_PACKET.md`. Approval for labels, issues, or
PR cleanup comments does not approve these close commands.

## Superseded-Close Path

Use this path only after the durable contract slice is confirmed to be already
present on current `main` or intentionally replaced by a newer claim-bound
slice.

```bash
gh pr edit 5 --repo betelgeuze-kang/deep-learning1 --add-label superseded
gh pr close 5 --repo betelgeuze-kang/deep-learning1
gh pr edit 10 --repo betelgeuze-kang/deep-learning1 --add-label superseded
gh pr close 10 --repo betelgeuze-kang/deep-learning1
```

## Merge Path

No pre-approved merge command is generated here. Merging PR #5 or PR #10
requires a separate review of the durable changed files, CI status, branch
state, and claim boundaries. Do not use this superseded-close command block for
a merge disposition.

## Verification

After an approved disposition batch:

```bash
python3 scripts/refresh_github_external_snapshots.py
python3 tools/verify_github_external_state.py --mode complete .
DLE_GITHUB_EXTERNAL_STATE_MODE=complete ./scripts/ai-verify.sh
```

Complete mode must prove that closed cleanup PRs carry the `superseded` label,
or that merged cleanup PRs are reported as merged.
The expected Batch E postcondition is that PR #5 and PR #10 are closed with the
`superseded` label, and `pr_cleanup_disposition_pending` is empty after snapshot
refresh.
