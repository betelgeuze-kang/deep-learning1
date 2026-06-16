Task:
Implement a repo-scoped helper that converts an already-captured real Ollama non-streaming `/api/generate` response JSON into replacement CSV metric values for the first-real-slice external-return workflow.

Why:
- The live warehouse path is outside OpenCode's allowed directory policy, so this slice must stay inside the repository.
- Codex will inspect the diff and later use or copy the helper against the live workspace.

Files in scope:
- Add one Python helper under `scripts/`, preferably:
  `scripts/v61_first_real_slice_metric_replacements_from_ollama_response.py`
- Optionally add a short docs note under `docs/ai/` if needed.

Files out of scope:
- Do not touch `/mnt/...` or any external directory.
- Do not edit `.env`, `.env.*`, `*.env`, or `*.env.*`.
- Do not edit checkpoint shard files or generated result payloads.
- Do not modify existing validator behavior.
- Do not modify AGENTS.md, README.md, README.ko.md, or docs/ROADMAP.md.

Allowed runtime:
- Local lightweight checks only.
- You may run `python3 -m py_compile` on the new helper.
- You may run the helper against tiny synthetic JSON and CSV fixtures under `/tmp`.

Dataset/checkpoint/network policy:
- Do not download anything.
- Do not call Ollama, curl, model generation, network APIs, or remote hash/download operations.
- The helper must consume an already-existing JSON file supplied by an operator; it must never run generation itself.

Implementation requirements:
- The helper must have `--help`.
- Inputs:
  - `--ollama-response <path>` required.
  - `--replacements <path>` required.
  - `--output <path>` optional.
  - `--in-place` optional. If neither `--output` nor `--in-place` is provided, write `<replacements-stem>.metrics_candidate<suffix>`.
  - `--update-total-ms` optional. If absent, leave `V61HO_TOTAL_MS` unchanged.
- Parse a non-streaming final Ollama JSON object.
- Required Ollama fields for the five blocker metrics:
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
- Do not invent values.
- Do not use byte counts as token counts.
- Do not include placeholder words like `template`, `fixture`, `synthetic`, `sample`, or `example` in generated replacement values.
- Keep implementation dependency-free: Python standard library only.

Acceptance criteria:
- Helper exists and is executable.
- `python3 -m py_compile scripts/v61_first_real_slice_metric_replacements_from_ollama_response.py` passes.
- A `/tmp` smoke with a tiny replacement CSV and a tiny Ollama JSON proves:
  - the five metric fields are populated,
  - human authority/review fields are not touched,
  - `V61HO_TOTAL_MS` is unchanged unless `--update-total-ms` is passed.
- No model generation, downloads, pushes, external mutations, or destructive commands.

Verification allowed:
- `python3 -m py_compile scripts/v61_first_real_slice_metric_replacements_from_ollama_response.py`
- Create/remove small files under `/tmp` for smoke verification.

Forbidden changes:
- Do not run actual model generation.
- Do not fill human/external attestation, reviewer, adjudicator, authority, or conflict fields.
- Do not mark the active goal complete.
- Do not use git push, merge, reset, checkout, or destructive commands.
