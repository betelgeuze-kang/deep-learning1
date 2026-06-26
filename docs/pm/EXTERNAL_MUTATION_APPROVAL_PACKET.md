# External Mutation Approval Packet

No external commands have been executed for the GitHub governance work in this
local changeset. This packet exists so the human owner can review the exact
mutation boundary before labels, issues, PR comments, settings, or license
decisions are applied.

Execution order and postconditions are defined in
`docs/pm/GITHUB_EXTERNAL_MUTATION_RUNBOOK.md`.

## Approval boundary

Only run these actions after explicit human approval:

- Create or update GitHub labels.
- Create GitHub issues.
- Add comments to PR #5 or PR #10.
- Close, label, merge, rebase, or otherwise mutate PR #5 or PR #10.
- Change repository settings, branch rules, workflow permissions, security
  features, or merge policy.
- Replace the conservative `LICENSE` with a public license.

## Approval batches

Approve and execute these batches separately. Do not treat approval for one
batch as approval for any later batch.

| Batch | Mutations allowed after approval | Postcondition evidence |
|---|---|---|
| A | Read-only refresh and local verification only | refreshed `docs/pm/github_external_state_snapshot.json`, `docs/pm/github_settings_external_snapshot.json`, pending-mode verification |
| B | Create/update labels with `gh label create` | `required_labels_missing` is empty after snapshot refresh |
| C | Create the five evidence blocker issues with `gh issue create` | all expected issue titles and body anchors appear after snapshot refresh |
| D | Comment on PR #5 and PR #10 with `gh pr comment` | cleanup comment anchors appear on both PRs after snapshot refresh |
| E | If separately approved, apply only the superseded-close PR disposition packet | PR #5 and PR #10 are closed with the `superseded` label, or an approved merge/rebase path is separately documented |
| F | Change GitHub repository settings manually | complete-mode settings checks pass after snapshot refresh |
| G | Replace `LICENSE` with a public reuse license only if the owner chooses one | license boundary is updated and re-reviewed locally |
| H | Final verification and audit update only | complete-mode external-state verification and `DLE_GITHUB_EXTERNAL_STATE_MODE=complete ./scripts/ai-verify.sh` pass |

Batch D is not PR cleanup completion by itself. Completion for PR #5 and PR
#10 requires Batch E or another explicitly approved final disposition, plus
refreshed evidence that neither PR remains a long-lived open blocker.

## Prepared command generator

The non-mutating helper is:

```bash
python3 tools/verify_github_governance_commands.py
python3 tools/verify_pr_cleanup_disposition_commands.py
python3 scripts/print_github_governance_commands.py
python3 scripts/print_github_governance_commands.py --batch B
python3 scripts/print_github_governance_commands.py --batch C
python3 scripts/print_github_governance_commands.py --batch D
```

The verifier parses the generated commands and confirms only approved `gh`
mutation forms are present. It also confirms that generated issue titles,
labels, and body files match `docs/pm/github_issue_drafts.json` and the
reviewed issue body files. The generator prints reviewable commands and does
not execute them. Its output labels the generated mutation blocks as Batch B
labels, Batch C evidence blocker issues, and Batch D PR cleanup comments, and
states that these batches require separate explicit approval. Expected
generated command families include:

- `gh label create`
- `gh issue create`
- `gh pr comment 5`
- `gh pr comment 10`

The generated commands reference these reviewed local files:

- `.github/labels.yml`
- `docs/pm/GITHUB_EXTERNAL_MUTATION_RUNBOOK.md`
- `docs/pm/PR_CLEANUP_DISPOSITION_COMMANDS.md`
- `docs/pm/github_issue_bodies/p0-v53-frozen-benchmark-canonicalization.md`
- `docs/pm/github_issue_bodies/p0-de-30b70b-real-evidence-intake.md`
- `docs/pm/github_issue_bodies/p1-v54-real-free-running-generation.md`
- `docs/pm/github_issue_bodies/p1-v58-blind-human-review-execution.md`
- `docs/pm/github_issue_bodies/p2-v61-one-token-logits-parity.md`
- `docs/pm/pr_cleanup_comments/pr5-v50-cleanup-comment.md`
- `docs/pm/pr_cleanup_comments/pr10-v56-cleanup-comment.md`

The PR disposition command verifier only allowlists the superseded-close
sequence for PR #5 and PR #10: add the `superseded` label, then close the PR.
It intentionally does not generate merge commands.

## GitHub Settings

Manual GitHub Settings review should use:

- `python3 scripts/refresh_github_external_snapshots.py`
- `docs/pm/github_settings_checklist.json`
- `docs/pm/github_settings_external_snapshot.json`

Known current-state notes:

- Repository default `GITHUB_TOKEN` workflow permission is already read-only.
- Branch protection is unavailable for the private repository under the current
  GitHub plan, based on the recorded read-only snapshot.
- Delete head branches, full SHA-pinned Actions, merge-method simplification,
  and available security feature toggles remain action-pending.
- Complete-mode verification now also requires branch protection with required
  pull request reviews, an `AI verify`/PR-safe status check, conversation
  resolution, force-push blocking, and branch-deletion blocking.
- Complete-mode verification also requires full SHA-pinned Actions, CodeQL
  default setup, secret scanning, dependency graph, vulnerability alerts, and
  Dependabot alerts to be enabled or configured in the refreshed settings
  snapshot.

## Public license decision

The current `LICENSE` intentionally does not grant public reuse. A public
license change is a human policy decision and should not be made by automation.

## Pre-mutation checklist

- Re-run `python3 scripts/refresh_github_external_snapshots.py`.
- Re-run `python3 tools/verify_github_governance_commands.py`.
- Re-run `python3 tools/verify_pr_cleanup_disposition_commands.py`.
- Re-run `python3 tools/verify_github_external_state.py --mode pending .`
  before approval, `python3 tools/verify_github_external_state.py --mode partial .`
  after a partial approved mutation batch, or
  `python3 tools/verify_github_external_state.py --mode complete .` after the
  final approved mutation batch. Complete mode checks issue body anchors and PR
  cleanup comment anchors, plus the final PR #5/#10 disposition. It must not
  pass while either PR remains a long-lived open blocker.
- Re-run `./scripts/ai-verify.sh` before approval, or
  `DLE_GITHUB_EXTERNAL_STATE_MODE=partial ./scripts/ai-verify.sh` after a
  partial batch, or `DLE_GITHUB_EXTERNAL_STATE_MODE=complete ./scripts/ai-verify.sh`
  after final approved external mutations are reflected in refreshed snapshots.
  Complete mode is expected to fail before those mutations are applied.
- Review `docs/pm/GITHUB_EXTERNAL_MUTATION_RUNBOOK.md`.
- Review `docs/pm/pasted_goal_completion_audit.json`.
- Review `docs/pm/PASTED_GOAL_COMPLETION_AUDIT.md`.
- Confirm every command printed by
  `python3 scripts/print_github_governance_commands.py`.
- Confirm explicit human approval for each external mutation batch.
