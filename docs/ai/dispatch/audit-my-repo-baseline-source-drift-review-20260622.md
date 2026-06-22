# TASK: audit-my-repo baseline source-drift review

Context:
- Active goal: move `audit-my-repo` toward design-partner beta candidate.
- Scope is local audit product only. No network/GPU/checkpoint/release/push/merge work.
- A probe found a real product bug: `--baseline <old audit output>` failed after the target repository changed, because baseline preflight re-ran full live source verification against the current worktree.

Codex change to review:
- `tools/verify_local_audit.py`
  - Adds `--allow-source-drift`.
  - Default verification remains strict.
  - Source-drift mode verifies artifact/schema/manifest/cache/internal citation linkage, but skips current target file/git/source span rereads.
- `scripts/audit_my_repo.py`
  - Uses `verify_local_audit.py <baseline> --allow-source-drift` only for baseline preflight.
- `experiments/test_audit_my_repo_negative_controls.sh`
  - Adds semantic baseline fixture:
    - old baseline strict verification fails after repo mutation;
    - old baseline with `--allow-source-drift` passes;
    - current audit with `--baseline old` emits `new`, `changed`, and `resolved` rows;
    - identical baseline comparison still emits `unchanged` only.
- `docs/AUDIT_MY_REPO_ALPHA.md`
  - Notes baseline preflight allows source drift for historical comparisons.

Please do:
- Inspect the diff for this slice.
- Run a narrow verification if useful.
- If you find a real defect, make the smallest fix.
- Otherwise leave code unchanged and report acceptance.

Watch for:
- Default `verify_local_audit.py <out>` must remain strict.
- Source-drift mode must not be used for normal `--verify-existing`.
- Readiness flags and benchmark thresholds must remain unchanged.
- Do not weaken artifact hash/schema/cache/reproduce checks.

Report:
- Changed files, if any.
- Tests run and result.
- Residual risks.
