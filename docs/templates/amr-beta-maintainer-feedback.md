# AMR Beta — Maintainer Feedback Template (blocker 9.3)

Provide **>= 3** distinct maintainer feedback sources. The agent does not
fabricate feedback; only human-supplied maintainer feedback is used.

Feedback is consumed by
`scripts/audit_my_repo_benchmark.py --feedback <file>` (JSON or JSONL). Raw
feedback text is hashed, not emitted, by the benchmark.

## Per-row fields

- `case_id` (required) — must reference a known benchmark case (a repo from 9.1).
- `maintainer_id` (required) — distinct id per maintainer; needed for the row to count.
- `maintainer_feedback` (required, truthy) — the maintainer's feedback text.
- `feedback_id` (optional) — safe identifier (`[A-Za-z0-9][A-Za-z0-9_.-]{0,127}`).

At least 3 distinct `maintainer_id` values across rows are required
(`MIN_MAINTAINER_FEEDBACK_FOR_BETA=3`).

## Example (JSONL — synthetic placeholders, replace with real feedback)

```jsonl
{"case_id": "example-repo-1", "maintainer_id": "EXAMPLE-maintainer-1", "feedback_id": "EXAMPLE-fb-0001", "maintainer_feedback": "SYNTHETIC EXAMPLE - replace with real maintainer feedback"}
{"case_id": "example-repo-1", "maintainer_id": "EXAMPLE-maintainer-2", "feedback_id": "EXAMPLE-fb-0002", "maintainer_feedback": "SYNTHETIC EXAMPLE - replace with real maintainer feedback"}
{"case_id": "example-repo-2", "maintainer_id": "EXAMPLE-maintainer-3", "feedback_id": "EXAMPLE-fb-0003", "maintainer_feedback": "SYNTHETIC EXAMPLE - replace with real maintainer feedback"}
```

> The example rows are placeholders and do not count as real evidence. Replace
> them with real maintainer feedback bound to real cases from blocker 9.1.
