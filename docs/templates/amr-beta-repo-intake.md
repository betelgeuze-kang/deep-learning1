# AMR Beta — Repository Intake Template (blocker 9.1)

Provide **>= 10** real local repositories. The agent does not fabricate or
synthesize repositories; only human-supplied real clones are used.

For each repository, record one row. Keep one case per repository.

## Per-repository checklist

- [ ] Real local clone (not synthetic / not a generated fixture).
- [ ] Clean git worktree (no uncommitted changes): `git status --porcelain` is empty.
- [ ] HEAD pinned and recorded as `expected_repo_git_head`.
- [ ] Owner or maintainer contact recorded for follow-up and feedback intake.
  Reserved placeholder contacts such as `*.invalid`, `EXAMPLE-*`,
  `placeholder`, `synthetic`, or `fixture` values do not count.
- [ ] `case_id` is a safe identifier (`[A-Za-z0-9][A-Za-z0-9_.-]{0,127}`).
- [ ] Audit will be run with `namespace=real_benchmark` and
  `real_benchmark_namespace_confirmed=true`.
- [ ] No row or optional metadata column marks the case as `synthetic`,
  `fixture`, `example`, `placeholder`, or `template_only`.

## Intake table (fill in)

| case_id | repo_path | expected_repo_git_head | clean_worktree | owner_or_maintainer_contact | audit_mode (quick/full) | namespace | real_benchmark_namespace_confirmed | notes |
|---|---|---|---|---|---|---|---|---|
| example-repo-1 | /abs/path/to/repo1 | <git rev-parse HEAD> | true | EXAMPLE-contact | quick | real_benchmark | true | example row — replace with a real repo |

> The example row is a placeholder. Replace it with real repositories. At least
> 10 real rows are required; the example does not count toward the threshold,
> even though it shows the required `real_benchmark` namespace fields. Do not
> leave any `EXAMPLE-*` value in the filled intake sheet.
> Do not leave `example`, `placeholder`, `synthetic`, `fixture`, or
> `template_only` markers in `notes` or optional metadata columns.

## How HEAD is checked

Before running audits, validate the filled sheet:

```bash
python3 scripts/amr_beta_repo_intake_validate.py <filled-intake.md-or.csv>
```

The benchmark verifies, per case, that the current HEAD matches
`expected_repo_git_head` and the worktree is clean
(`repo_snapshot_requirement_met`). Dirty repos, non-git directories, HEAD
mismatches, or missing expected HEAD keep the snapshot requirement at 0.
The validator status binds the filled intake file with `input_intake_sha256`,
keeps `runs_audit=0`, and keeps `creates_benchmark_evidence=0`.

## Namespace note

Audits feeding beta evidence must be run in the real_benchmark namespace
(`audit_my_repo.sh <repo> --namespace real_benchmark --confirm-real-benchmark-namespace ...`).
Otherwise `audit_my_repo_label_template.py` marks the rows `synthetic=1`, the
case stays synthetic, and `real_human_label_basis` (and the beta gate) stays 0.
