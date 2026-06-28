# AMR Beta — Repository Intake Template (blocker 9.1)

Provide **>= 10** real local repositories. The agent does not fabricate or
synthesize repositories; only human-supplied real clones are used.

For each repository, record one row. Keep one case per repository.

## Per-repository checklist

- [ ] Real local clone (not synthetic / not a generated fixture).
- [ ] Clean git worktree (no uncommitted changes): `git status --porcelain` is empty.
- [ ] HEAD pinned and recorded as `expected_repo_git_head`.
- [ ] `case_id` is a safe identifier (`[A-Za-z0-9][A-Za-z0-9_.-]{0,127}`).

## Intake table (fill in)

| case_id | repo_path | expected_repo_git_head | audit_mode (quick/full) | notes |
|---|---|---|---|---|
| example-repo-1 | /abs/path/to/repo1 | <git rev-parse HEAD> | quick | example row — replace with a real repo |

> The example row is a placeholder. Replace it with real repositories. At least
> 10 real rows are required; the example does not count toward the threshold.

## How HEAD is checked

The benchmark verifies, per case, that the current HEAD matches
`expected_repo_git_head` and the worktree is clean
(`repo_snapshot_requirement_met`). Dirty repos, non-git directories, HEAD
mismatches, or missing expected HEAD keep the snapshot requirement at 0.

## Namespace note

Audits feeding beta evidence must be run in the real_benchmark namespace
(`audit_my_repo.sh <repo> --namespace real_benchmark --confirm-real-benchmark-namespace ...`).
Otherwise `audit_my_repo_label_template.py` marks the rows `synthetic=1`, the
case stays synthetic, and `real_human_label_basis` (and the beta gate) stays 0.
