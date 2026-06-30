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
- [ ] The filled intake sheet itself is stored outside every target repository.
- [ ] `case_id` is a safe identifier (`[A-Za-z0-9][A-Za-z0-9_.-]{0,127}`).
- [ ] Audit will be run with `namespace=real_benchmark` and
  `real_benchmark_namespace_confirmed=true`.
- [ ] No row or optional metadata column affirmatively marks the case as `synthetic`,
  `fixture`, `example`, `placeholder`, or `template_only`.

## Intake table (fill in)

| case_id | repo_path | expected_repo_git_head | clean_worktree | owner_or_maintainer_contact | audit_mode (quick/full) | namespace | real_benchmark_namespace_confirmed | notes |
|---|---|---|---|---|---|---|---|---|
| example-repo-1 | /abs/path/to/repo1 | <git rev-parse HEAD> | true | EXAMPLE-contact | quick | real_benchmark | true | example row — replace with a real repo |

> The example row is a placeholder. Replace it with real repositories. At least
> 10 real rows are required; the example does not count toward the threshold,
> even though it shows the required `real_benchmark` namespace fields. Do not
> leave any `EXAMPLE-*` value in the filled intake sheet.
> Do not leave affirmative `example`, `placeholder`, `synthetic`, `fixture`,
> or `template_only` markers in `notes` or optional metadata columns.

## How HEAD is checked

Before running audits, validate the filled sheet:

```bash
python3 scripts/amr_beta_repo_intake_validate.py <filled-intake.md-or.csv>
```

If the 10 local repositories and maintainer contacts are already known, create
and immediately validate a filled sheet from read-only git metadata:

```bash
python3 scripts/amr_beta_repo_intake_collect.py \
  --repo /abs/path/to/repo1 --contact maintainer-1-contact \
  --repo /abs/path/to/repo2 --contact maintainer-2-contact \
  --confirm-real-benchmark-namespace \
  --out results/amr_beta_repo_intake.md
```

Repeat `--repo` and `--contact` for all 10 repositories. The collector records
the current `git rev-parse HEAD`, declares `clean_worktree=true` only when
`git status --porcelain --untracked-files=all` is empty, writes the
`real_benchmark` namespace fields only with explicit namespace confirmation,
then reuses the validator contract. It refuses placeholder contacts, dirty
repos, too few valid rows, and output paths inside target repositories. It does
not run audits or create benchmark evidence.

The benchmark verifies, per case, that the current HEAD matches
`expected_repo_git_head` and the worktree is clean
(`repo_snapshot_requirement_met`). Dirty repos, non-git directories, HEAD
mismatches, or missing expected HEAD keep the snapshot requirement at 0.
The validator status binds the filled intake file with `input_intake_sha256`,
records `repo_snapshot_lock_rows` plus `repo_snapshot_lock_sha256`, keeps
`runs_audit=0`, and keeps `creates_benchmark_evidence=0`.
Each snapshot lock row also records read-only git check flags:
`repo_git_worktree_confirmed`, `repo_head_readable`, `repo_status_readable`,
and `repo_head_pinned`. A row is not valid unless the repo is a git worktree,
HEAD is readable, `git status --porcelain --untracked-files=all` is readable
and clean, and the recorded `expected_repo_git_head` matches the current HEAD.
When writing optional `--out-json` or `--out-md` status files, keep them outside
every target repository. The validator refuses status outputs inside a listed
repo so a read-only intake check cannot dirty a repo after validating it.
Keep the filled intake sheet itself outside every target repository as well.
The validator also refuses intake files inside a listed repo, including files
hidden by `.gitignore`, because a clean worktree alone does not make the intake
artifact part of the source under review.

## Namespace note

Audits feeding beta evidence must be run in the real_benchmark namespace
(`audit_my_repo.sh <repo> --namespace real_benchmark --confirm-real-benchmark-namespace ...`).
Otherwise `audit_my_repo_label_template.py` marks the rows `synthetic=1`, the
case stays synthetic, and `real_human_label_basis` (and the beta gate) stays 0.
