Task:
Add a safe operator helper for the first-real-slice external-return workspace that converts an already-captured real Ollama non-streaming `/api/generate` response JSON into replacement CSV values for the five measured generation metric fields only.

Context:
- Codex owns research design and evidence boundaries.
- The active goal is to fill and validate the first real-slice external return form under:
  `/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse/first_real_slice_operator_workspace_20260614`
- Current replacement CSV exists at:
  `/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse/first_real_slice_operator_workspace_20260614/external_return_form/FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv`
- The current metric blockers are:
  `V61HO_PROMPT_TOKENS`, `V61HO_OUTPUT_TOKENS`, `V61HO_PREFILL_MS`, `V61HO_DECODE_MS`, `V61HO_TOKENS_PER_SECOND`.
- `V61HO_TOTAL_MS` is already filled from v53m evidence, but the helper may update it only when a real Ollama `total_duration` is present and the caller explicitly asks for update.

Files in scope:
- Add one executable Python helper under:
  `/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse/first_real_slice_operator_workspace_20260614/external_return_form/`
- Add or update one small README/worksheet under the same `external_return_form/` directory explaining how to use the helper.

Files out of scope:
- Do not edit repo files except this dispatch prompt.
- Do not edit `.env`, `.env.*`, `*.env`, or `*.env.*`.
- Do not edit checkpoint shard files or large generated artifacts.
- Do not modify existing validator behavior.
- Do not modify AGENTS.md or docs/ROADMAP.md.

Allowed runtime:
- Local lightweight checks only.
- You may run `python3 -m py_compile` on the new helper.
- You may run the new helper against a small synthetic temporary JSON fixture that you create under `/tmp` and then remove, or use process substitution if convenient.

Dataset/checkpoint/network policy:
- Do not download anything.
- Do not call Ollama, curl, model generation, network APIs, or remote hash/download operations.
- The helper must consume an already-existing JSON file supplied by the operator; it must never run generation itself.

Implementation requirements:
- Helper name should be clear, e.g. `BUILD_FIRST_REAL_SLICE_METRIC_REPLACEMENTS_FROM_OLLAMA_RESPONSE.py`.
- Inputs:
  - `--ollama-response <path>` required.
  - `--replacements <path>` defaulting to `FIRST_REAL_SLICE_VALUES_REPLACEMENTS.csv` in the same directory.
  - `--output <path>` optional; default should overwrite the replacements file only with an explicit `--in-place` flag. Without `--in-place`, write a sibling candidate CSV such as `FIRST_REAL_SLICE_VALUES_REPLACEMENTS.metrics_candidate.csv`.
  - Optional `--update-total-ms` flag. If absent, leave `V61HO_TOTAL_MS` unchanged.
- Parse a non-streaming final Ollama JSON object.
- Required Ollama fields for the five blockers:
  - `prompt_eval_count` -> `V61HO_PROMPT_TOKENS`
  - `eval_count` -> `V61HO_OUTPUT_TOKENS`
  - `prompt_eval_duration` nanoseconds -> `V61HO_PREFILL_MS`
  - `eval_duration` nanoseconds -> `V61HO_DECODE_MS`
  - compute `V61HO_TOKENS_PER_SECOND = eval_count / (eval_duration / 1e9)`
- If `--update-total-ms` is present:
  - `total_duration` nanoseconds -> `V61HO_TOTAL_MS`
- Validate all derived values are positive.
- Preserve all CSV columns and all existing replacement values except the metric fields being updated.
- Fail closed with a clear message when required fields are missing, non-numeric, zero, or negative.
- Do not invent values. Do not use byte counts as token counts.
- Do not include placeholder words like `template`, `fixture`, `synthetic`, `sample`, or `example` in the generated replacement values.

Acceptance criteria:
- The helper exists, is executable, and has a useful `--help`.
- The helper compiles with `python3 -m py_compile`.
- A local synthetic JSON smoke proves it writes the expected five metric replacement values into a candidate CSV without touching human authority/review rows.
- Running the existing replacement validator on the candidate CSV should reduce metric blockers but still block human authority/review rows if they remain empty.
- No model generation, no downloads, no pushes, no external mutation.

Verification allowed:
- `python3 -m py_compile <new-helper>`
- Run the helper with a temporary synthetic JSON file in `/tmp`
- Run:
  `/mnt/193005ba-8531-4d0b-87c2-43c01ee2ce25/deep_learning_v61_mixtral_8x22b_warehouse/first_real_slice_operator_workspace_20260614/external_return_form/RUN_VALIDATE_FIRST_REAL_SLICE_VALUES_REPLACEMENTS.sh`
  only against a candidate file via `V61HV_REPLACEMENTS_FILE=<candidate>`, not against live in-place output unless the helper was explicitly run with `--in-place` by the operator.

Forbidden changes:
- Do not run actual model generation.
- Do not fill human/external attestation, reviewer, adjudicator, authority, or conflict fields.
- Do not mark the active goal complete.
- Do not use git push, merge, reset, checkout, or destructive commands.
