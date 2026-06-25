# D/E open-weight baseline execution packet

How to produce the real 30B (D) and 70B (E) open-weight LLM+RAG baseline
evidence that the D/E systems are currently blocked on.

- Column source of truth: [`baselines/de_30b70b_real.json`](../baselines/de_30b70b_real.json)
- Intake contract: [`baselines/v53u_de_open_weight_evidence_intake_contract.json`](../baselines/v53u_de_open_weight_evidence_intake_contract.json)
- Tooling: [`scripts/de_execution_packet.py`](../scripts/de_execution_packet.py)

This packet/preflight tool is a **return-side staging helper**. It admits no
evidence, writes nothing to the measured registry, and flips no readiness flag.
Canonical admission still runs through
`experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh` and the
baseline-admission / v53u intake verifiers.

## 1. Generate the blank template

```bash
# canary (100 queries per system)
python3 scripts/de_execution_packet.py template --out de_packet_canary --systems D,E --rows-per-system 100
# full (1000 queries per system)
python3 scripts/de_execution_packet.py template --out de_packet_full --systems D,E --rows-per-system 1000
```

Produces `model_identity.csv`, `answer_citation_raw_output.csv`,
`resource_evaluator_manifest.csv`, a `de_required_field_rows.csv` field
dictionary, and `EXECUTION_PACKET_README.md`.

## 2. Fill from a REAL local run

- No external API (`external_api_used` must be `0`).
- No fixtures (`non_fixture_declared` must be `true`).
- All `*_sha256` columns must be real sha256 hashes of the corresponding bytes.
- Same query set, source manifest, context budget, and retrieval budget across
  all systems being compared.

Key fields per artifact (full list in the generated field dictionary):

- `model_identity.csv`: `model_repository`, `model_revision`, `quantization`,
  `model_artifact_sha256`, `runtime`, `runtime_version`, `hardware`,
  `open_weight_license_uri`, `external_api_used`, `non_fixture_declared`.
- `answer_citation_raw_output.csv`: `raw_answer`, `raw_citation`,
  `prompt_template_sha256`, `raw_output_sha256`, `generation_transcript_sha256`,
  `prompt_context_sha256`, `output_sha256`, `seed`, `context_budget`,
  `retrieval_budget`, `latency_ns`.
- `resource_evaluator_manifest.csv`: `latency_ns`, `peak_memory_mb`,
  `evaluator_version`, `evaluator_artifact_sha256`.

## 3. Recommended run order (canary first)

1. D 30B 100-query canary
2. D 30B 1000-query full
3. E 70B 100-query canary
4. E 70B 1000-query full
5. Re-evaluate A/B/C/D/E/G/H with the same evaluator on the same query set

Running a 100-query canary before the full 1000 keeps the cost of a
misconfiguration low.

## 4. Preflight before returning

```bash
python3 scripts/de_execution_packet.py preflight --packet de_packet_canary --systems D,E --rows-per-system 100
```

Preflight checks column match, non-empty required fields, sha256 formatting,
`external_api_used=0`, `non_fixture_declared=true`, numeric fields, and row
counts. A green preflight means the packet is well-formed for the canonical
intake; it does not by itself make any baseline claim.

## Exit criteria (unchanged by this tool)

`required_30b_baseline_ready`, `required_70b_baseline_ready`, `same_query_set`,
`same_source_manifest`, `same_context_budget`, `same_retrieval_budget`, and
`fixture_rows_in_measured_registry == 0` are decided only by the project's
intake/admission verifiers after real evidence is supplied.
