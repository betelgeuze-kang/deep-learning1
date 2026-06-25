# v58 blind evaluation packet

Return-side staging utilities for the v58 real blind evaluation. They prepare
blinding and reviewer assignment and compute inter-rater agreement; they do
**not** perform the review and **admit no evidence**.

- Contract / column source of truth: [`v58/blind_eval_real.json`](../v58/blind_eval_real.json)
- Contract notes: [`docs/V58_REAL_BLIND_EVAL_CONTRACT.md`](V58_REAL_BLIND_EVAL_CONTRACT.md)
- Tooling: [`scripts/v58_blind_eval_packet.py`](../scripts/v58_blind_eval_packet.py)

Scale target: 7 systems (A/B/C/D/E/G/H) x 500 responses = 3,500 blind responses;
2 independent reviewers each = 7,000 reviews; every disagreement adjudicated.

## 1. Blind map + blank response template

```bash
python3 scripts/v58_blind_eval_packet.py blind-map \
  --out v58_packet --systems A,B,C,D,E,G,H --queries-per-system 500 [--secret <HEX>]
```

Produces:

- `SECRET_unblinding_key.csv` + `SECRET_hmac_key.txt` - the **secret** HMAC key
  and `source_system_id -> blind_system_id` map. Do **not** share with reviewers
  until adjudication is complete.
- `public_blind_response_template.csv` - one blank row per (blind system, query)
  with **HMAC-derived** `blind_response_id` / `blind_system_id` (unguessable
  without the secret) and `response_text` left for the executor. The public file
  carries **no source identity** (verified fail-closed) and `response_text` must
  carry no model/run identity tokens.

## 2. Reviewer pool registry + assignment

```bash
python3 scripts/v58_blind_eval_packet.py reviewer-registry \
  --out v58_packet --responses v58_packet/public_blind_response_template.csv \
  [--registry your_reviewer_pool_registry.csv]
```

Registry columns: `reviewer_id`, `reviewer_pool_id`, `reviewer_independent`,
`conflict_disclosed`. The registry is **integrity-validated** (unique ids,
boolean fields, conflict disclosed, at least two independent pools) before
assignment; assignment gives every response **two independent reviewers from
distinct pools** and fails closed otherwise.

## 3. Review completeness (after reviews return)

```bash
python3 scripts/v58_blind_eval_packet.py completeness \
  --assignment v58_packet/review_assignment.csv --reviews v58_human_review_rows.csv
```

Fails closed unless every response has **exactly its two assigned reviews**,
every review is bound to an assigned `(blind_response_id, reviewer_id)`, and all
review metric values are in the allowed vocabulary.

## 4. Cohen's kappa report

After human review rows come back (v58-human-review-rows shape):

```bash
python3 scripts/v58_blind_eval_packet.py kappa \
  --reviews v58_human_review_rows.csv --out v58_packet/kappa
```

Produces `inter_rater_kappa_report.csv` (per metric: observed/expected
agreement, Cohen's kappa, disagreement count) over the metrics
`answer_correctness`, `citation_correctness`, `abstain_correctness`,
`source_span_exactness`, `unsupported_abstention_correctness`,
`review_decision`, and `adjudication_queue_rows.csv` listing every disagreement
that needs independent adjudication.

Cohen's kappa: `kappa = (po - pe) / (1 - pe)`, with `po` the observed agreement
and `pe` the chance agreement; `pe = 1` returns `1.0` only when agreement is
perfect.

## Boundary

This tool admits nothing and flips no readiness flag. Real acceptance runs
through `experiments/test_v58c_blind_response_evidence_intake.sh` and
`experiments/test_v58d_blind_review_return_intake.sh`. Fixtures/templates do not
close v58: `real_execution_ready`, `human_blind_review_ready`,
`inter_rater_rows_ready`, and `v58_full_blind_eval_ready` stay decided by those
verifiers after non-fixture responses and human review/adjudication return.
