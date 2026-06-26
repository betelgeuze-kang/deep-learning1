# PR #10 Cleanup Comment Draft

This PR should not remain a long-lived blocker-only PR.

Recommended path:

1. Rebase or cherry-pick only the still-needed durable v56 replay contract and
   fail-closed smoke tests onto current `main`.
2. Keep official source/evaluator hashes, raw prediction/result rows, replay
   manifests, and independent verification evidence blocked until real
   artifacts are supplied.
3. Convert missing expanded replay evidence into an evidence blocker issue using
   the repository issue template.
4. Close this PR after the durable contract slice is either merged or confirmed
   superseded by current `main`.

Do not merge leaderboard, expanded benchmark readiness, or public comparison
claims before real replay artifacts exist.
