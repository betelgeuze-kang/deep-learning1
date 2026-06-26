# audit-my-repo design-partner review intake

How to collect human finding-review labels through GitHub and normalize them
into JSONL decision rows for the audit-my-repo beta evidence channel.

- Issue form: `.github/ISSUE_TEMPLATE/design-partner-finding-review.yml`
- Converter: [`scripts/audit_review_to_jsonl.py`](../scripts/audit_review_to_jsonl.py)

This is a **normalization/aggregation aid only**. It admits no evidence and
flips no readiness flag; `design_partner_beta_candidate_ready` stays decided by
the project verifier after real labels are supplied. The `summarize` numbers are
candidate aggregates, not a readiness claim.

## Beta targets

10 repositories, 300+ human labels, 3+ maintainers, precision >= 0.80,
P0/P1 precision >= 0.90, citation validity == 100%, on clean pinned HEADs.

## Collect (GitHub, web)

1. Reviewers file one **Design Partner Finding Review** issue per finding.
2. Suggested project board labels: `beta-label-needed`, `reviewed`, `accepted`,
   `disputed` (board/labels are managed in the GitHub UI).
3. Export the reviewed issues to JSON, e.g.:
   ```bash
   gh issue list --label human-review --state all --json number,author,createdAt,body > issues.json
   ```

## Normalize -> validate -> summarize

```bash
python3 scripts/audit_review_to_jsonl.py convert --issues issues.json --out decisions.jsonl
python3 scripts/audit_review_to_jsonl.py validate --decisions decisions.jsonl
python3 scripts/audit_review_to_jsonl.py summarize --decisions decisions.jsonl
```

`convert` also accepts a directory of `*.md` issue bodies (filename stem becomes
`issue_ref`).

### Decision row (JSONL)

`issue_ref`, `reviewer`, `created_at`, `repo_head_sha`, `finding_id`,
`finding_validity` (present/absent/ambiguous), `priority`
(P0/P1/P2/informational), `citation_correct`
(correct/incorrect/partial/not-applicable), `expected_source_span`,
`reviewer_independence`, `notes`, `valid`, `validation_errors`.

### Aggregates (`summarize`)

- `distinct_repos`, `distinct_reviewers`, `total_labels`
- `precision = present / (present + absent)`
- `p0_p1_precision` over P0/P1 findings
- `citation_validity = correct / total`
- `targets_met` compares each to the beta targets above.

Examples of valid issue-form values are in
[`examples/v58/`](../examples/v58/) for v58; for audit reviews the allowed values
are listed in the issue form itself.
