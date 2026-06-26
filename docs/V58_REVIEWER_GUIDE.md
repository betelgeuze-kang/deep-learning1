# v58 reviewer guide

How to run the v58 blind human evaluation with the merged tooling. The blinding,
reviewer-assignment, completeness, and kappa mechanics already exist in
[`scripts/v58_blind_eval_packet.py`](../scripts/v58_blind_eval_packet.py); this
guide is the operating procedure plus example files.

Examples: [`examples/v58/`](../examples/v58/).
Packet reference: [`docs/V58_BLIND_EVAL_PACKET.md`](V58_BLIND_EVAL_PACKET.md).

## Scale target

7 systems (A/B/C/D/E/G/H) x 500 responses = **3,500 blind responses**;
**2 independent reviewers** from distinct pools each = **7,000 reviews**; every
disagreement adjudicated.

## Roles

- **Organizer** (holds the secret): runs blinding, assignment, completeness, and
  kappa; keeps the unblinding key until adjudication finishes.
- **Reviewers**: see only the public blinded responses; never the source system
  identity or the secret key.
- **Adjudicator**: resolves every disagreement flagged by the kappa step.

## Procedure

### 1. Blind (organizer, secret)

```bash
python3 scripts/v58_blind_eval_packet.py blind-map \
  --out v58_packet --systems A,B,C,D,E,G,H --queries-per-system 500
```

- `SECRET_unblinding_key.csv` + `SECRET_hmac_key.txt` are the **secret** files
  (HMAC-derived blind ids). Do **not** share with reviewers until adjudication
  is complete.
- `public_blind_response_template.csv` is the only file the executor/reviewers
  see. Blind ids are HMAC-based (unguessable without the secret); the public
  file is fail-closed checked to carry no source identity. Response text must
  contain no model/run identity tokens.

### 2. Reviewer registry + assignment (organizer)

```bash
python3 scripts/v58_blind_eval_packet.py reviewer-registry \
  --out v58_packet --responses v58_packet/public_blind_response_template.csv \
  --registry your_reviewer_pool_registry.csv
```

Registry columns: `reviewer_id, reviewer_pool_id, reviewer_independent,
conflict_disclosed` (see `examples/v58/reviewer_registry.example.csv`). It is
integrity-validated (unique ids, boolean fields, conflict disclosed, >= 2
independent pools) and assigns two independent reviewers from distinct pools per
response, fail-closed.

### 3. Reviewers fill human-review rows

One row per (response, reviewer); see
`examples/v58/human_review_rows.example.csv`. Allowed values per metric:

| metric | allowed values |
|---|---|
| `answer_correctness` | correct, incorrect, partial, not_applicable |
| `citation_correctness` | correct, incorrect, partial, not_applicable |
| `abstain_correctness` | correct, incorrect, not_applicable |
| `source_span_exactness` | exact, partial, wrong, not_applicable |
| `unsupported_abstention_correctness` | correct, incorrect, not_applicable |
| `review_decision` | accept, reject, revise |

### 4. Completeness (organizer, fail-closed)

```bash
python3 scripts/v58_blind_eval_packet.py completeness \
  --assignment v58_packet/review_assignment.csv --reviews human_review_rows.csv
```

Fails unless every response has exactly its two assigned reviews, each review is
bound to an assigned `(blind_response_id, reviewer_id)`, and all metric values
are in the allowed vocabulary.

### 5. Cohen's kappa + adjudication

```bash
python3 scripts/v58_blind_eval_packet.py kappa \
  --reviews human_review_rows.csv --out v58_packet/kappa
```

Produces `inter_rater_kappa_report.csv` and `adjudication_queue_rows.csv` (every
disagreement). The adjudicator resolves each into an
`adjudication_rows.csv` (see `examples/v58/adjudication_rows.example.csv`,
which adds `adjudicated_value` and `adjudicator_id`).

## Boundary

These tools admit no evidence and flip no readiness flag. Real acceptance still
runs through `experiments/test_v58c_*.sh` / `experiments/test_v58d_*.sh`. Keep
latency/memory separate from quality, and do not share the unblinding key with
reviewers until adjudication is complete.
