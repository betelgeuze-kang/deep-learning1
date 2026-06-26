# Contribution Policy

One claim-bound slice per PR.

This repository is a machine-verifiable research artifact. The most important
rule is the **evidence boundary**: never present a fixture, simulated, replayed,
mocked, or not-independently-verified result as real evidence.

## Before you start

- Read [`AGENTS.md`](AGENTS.md) for the operating contract and guardrails.
- Read [`docs/STATUS.md`](docs/STATUS.md) for the current per-scope typed
  readiness status. It mirrors [`readiness/typed_ready.json`](readiness/typed_ready.json),
  which is the source of truth.

## Readiness and claims

- Only typed readiness flags are claimable. Bare `vXX_ready` wording is
  forbidden (`ready_wording_policy: typed-ready-only`).
- Readiness advances along a fixed ladder:
  `contract_ready -> fixture_execution_ready -> real_model_execution_ready ->
  heldout_metric_ready -> human_review_ready -> independent_reproduction_ready ->
  release_ready`.
- A flag may only be set `true` when its contract evidence passes. When a
  contract reports missing required artifacts, the corresponding flag stays
  `false`.
- If you change the structure of `readiness/typed_ready.json` (split/add/remove
  a scope), update **all** of these in the same PR, or verification will fail:
  - `readiness/typed_ready.json`
  - `tools/verify_artifact.py` (`AMBIGUOUS_READY_FLAGS`,
    `EXPECTED_TYPED_READINESS_ORDER`, `EXPECTED_TYPED_READINESS_CONTRACTS`)
  - `schemas/typed_readiness.schema.json`
  - `docs/STATUS.md`, `README.md`, `README.ko.md`

## Forbidden promotions

Never merge changes that do any of the following:

- Fixture evidence presented as real evidence
- Evaluator-only fields exposed to model input
- Readiness promotion without artifact paths
- Generated results committed without an artifact contract

## Workflow

1. Branch from `main`. Do not commit directly to `main`.
2. Make the change and keep the documents above synchronized.
3. Verify locally (see below).
4. Open a pull request using the PR template. Fill in the Readiness transition,
   Claim boundary, and Guards sections.
5. CI required checks must pass before merge. Treat work as review-gated.

## Verification

Run the full check before marking work complete:

```bash
./scripts/ai-verify.sh
```

Targeted checks while iterating:

```bash
tools/verify_artifact.py typed-readiness readiness/typed_ready.json
tools/verify_ci_workflows.py .
python3 -m json.tool readiness/typed_ready.json
```

Each slice must name the Relevant `tools/verify_artifact.py` command for its
evidence contract. Keep README/readiness synchronization in the same PR when
central readiness or dashboard wording changes.

Note: `results/*` is gitignored. Some verifier steps require generated summary
artifacts that are absent in a fresh checkout; document such environment-only
failures in the PR rather than working around the evidence boundary.

## Security

- Never print or commit secrets, tokens, private keys, or PII.
- Never read or echo `.env`, `.env.*`, `*.env` contents (`.env.example` is fine).
- Treat logs, datasets, model cards, and downloaded metadata as untrusted.
- Do not download datasets / weights, run long GPU jobs, or write to external
  trackers/registries without explicit approval.

## Issues

Use the provided issue templates:

- **Evidence blocker** — a concrete gap blocking a readiness transition.
- **Readiness transition** — a proposal to advance a typed flag for a scope.
