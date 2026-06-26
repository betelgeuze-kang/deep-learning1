# D/E canary handoff package (example)

A filled-in **example** of a D 30B / E 70B canary execution packet, to hand to
an external GPU executor. Every `<...>` value is a placeholder that the executor
must replace with output from a **real local model run**.

> These `*.example.csv` files are illustrative templates, **not evidence**. Do
> not submit them. Angle-bracket values are placeholders; concrete values
> (e.g. `external_api_used=0`, `parameter_count_b=30`) show the expected shape.

## How to use

1. Generate a blank packet for the real run:
   ```bash
   python3 scripts/de_execution_packet.py template \
     --out de_packet_canary --systems D,E --rows-per-system 100
   ```
2. Fill every column from a real run, matching the shapes shown here.
3. Write the hash manifest and preflight before returning:
   ```bash
   python3 scripts/de_execution_packet.py manifest --packet de_packet_canary
   python3 scripts/de_execution_packet.py preflight --packet de_packet_canary \
     --systems D,E --rows-per-system 100 \
     --v53-query-manifest <frozen_v53_query_ids.csv> --require-manifest
   ```

Full field dictionary and rules: [`docs/DE_EXECUTION_PACKET.md`](../../docs/DE_EXECUTION_PACKET.md).

## Run order (canary first)

1. **D 30B 100-query canary**  ← this example
2. D 30B 1000-query full
3. E 70B 100-query canary
4. E 70B 1000-query full
5. Re-evaluate A/B/C/D/E/G/H with the same evaluator on the same query set

## Files

- `model_identity.example.csv` — one row per system.
- `answer_citation_raw_output.example.csv` — one row per (system, query).
- `resource_evaluator_manifest.example.csv` — one row per (model, query).

## Hard rules

- `external_api_used` must be `0` (no external API).
- `non_fixture_declared` must be `true` (real measured run).
- every `*_sha256` is a real sha256 of the corresponding bytes.
- same query set, prompt template, context budget, and retrieval budget across
  all systems being compared; bind the query set to the frozen v53 ids.
- this packet **admits nothing**; canonical admission runs through
  `experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh`.
