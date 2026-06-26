# PR #5 Cleanup Comment Draft

This PR should not remain a long-lived blocker-only PR.

Recommended path:

1. Rebase or cherry-pick only the still-needed durable contract/schema/test
   changes onto current `main`.
2. Keep pinned public-fetch artifacts, external auditor correctness evidence,
   and real replay readiness blocked until they are regenerated and
   sha256-bound.
3. Convert missing public-fetch/external evidence into an evidence blocker issue
   using the repository issue template.
4. Close this PR after the durable contract slice is either merged or confirmed
   superseded by current `main`.

Do not merge wording that implies real auditor correctness readiness before the
required non-fixture replay artifacts exist.
