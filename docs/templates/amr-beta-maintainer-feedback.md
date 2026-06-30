# AMR Beta — Maintainer Feedback Template (blocker 9.3)

Provide **>= 3** distinct maintainer feedback sources. The agent does not
fabricate feedback; only human-supplied maintainer feedback is used.

Feedback is consumed by
`scripts/audit_my_repo_benchmark.py --feedback <file>` (JSON or JSONL). Raw
feedback text is hashed, not emitted, by the benchmark.
The local feedback request packet reports returned raw `feedback_text` only as
`feedback_text_sha256_status`.

## Per-row fields

- `case_id` (required) — must reference a known benchmark case (a repo from 9.1).
- `maintainer_id` (required) — safe, non-placeholder distinct id per
  maintainer; needed for the row to count.
- `feedback_text` (required) — the maintainer's raw feedback text. It is hashed
  (`feedback_text_sha256`), not emitted. A row must include `feedback_text` or a
  precomputed `feedback_text_sha256`. If both are supplied, the digest must be
  a valid `sha256:<64 hex>` value that matches `feedback_text`.
- `human_feedback` (required, truthy) — boolean flag that the feedback is human
  (`maintainer_feedback: true` is an accepted alias for this flag; it is NOT the
  text field).
- `synthetic` must be absent/false and the referenced case must be a real
  (non-synthetic) `real_benchmark` case, or the row will not count
  (`counts_for_beta`).
- `feedback_id` (optional) — safe identifier (`[A-Za-z0-9][A-Za-z0-9_.-]{0,127}`).

At least 3 distinct `maintainer_id` values across rows are required
(`MIN_MAINTAINER_FEEDBACK_FOR_BETA=3`).

## Example (JSONL — synthetic placeholders, replace with real feedback)

```jsonl
{"case_id": "example-repo-1", "maintainer_id": "EXAMPLE-maintainer-1", "feedback_id": "EXAMPLE-fb-0001", "human_feedback": true, "feedback_text": "SYNTHETIC EXAMPLE - replace with real maintainer feedback"}
{"case_id": "example-repo-1", "maintainer_id": "EXAMPLE-maintainer-2", "feedback_id": "EXAMPLE-fb-0002", "human_feedback": true, "feedback_text": "SYNTHETIC EXAMPLE - replace with real maintainer feedback"}
{"case_id": "example-repo-2", "maintainer_id": "EXAMPLE-maintainer-3", "feedback_id": "EXAMPLE-fb-0003", "human_feedback": true, "feedback_text": "SYNTHETIC EXAMPLE - replace with real maintainer feedback"}
```

> The example rows are placeholders and do not count as real evidence. Replace
> them with real maintainer feedback bound to real cases from blocker 9.1, and
> ensure those cases were audited in the `real_benchmark` namespace (otherwise
> the feedback row will not count toward beta).
