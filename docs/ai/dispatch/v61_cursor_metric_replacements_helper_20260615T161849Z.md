Task:
Implement one repo-scoped Python helper for converting an already-captured Ollama non-streaming `/api/generate` response JSON into first-real-slice replacement CSV metric values.

Implement exactly this file:
- `scripts/v61_first_real_slice_metric_replacements_from_ollama_response.py`

Do not touch any other repo file except this helper.

Required behavior:
- Standard library only.
- Executable script with `#!/usr/bin/env python3`.
- CLI arguments:
  - `--ollama-response <path>` required
  - `--replacements <path>` required
  - `--output <path>` optional
  - `--in-place` optional
  - `--update-total-ms` optional
- If neither `--output` nor `--in-place` is passed, write a candidate CSV next to the replacements file named `<stem>.metrics_candidate<suffix>`.
- Read a CSV with columns like `env_name,field_path,replacement_value,required_action`.
- Preserve all rows/columns and update only:
  - `V61HO_PROMPT_TOKENS`
  - `V61HO_OUTPUT_TOKENS`
  - `V61HO_PREFILL_MS`
  - `V61HO_DECODE_MS`
  - `V61HO_TOKENS_PER_SECOND`
- If `--update-total-ms` is passed, also update `V61HO_TOTAL_MS`.
- Parse Ollama JSON fields:
  - `prompt_eval_count` -> prompt tokens
  - `eval_count` -> output tokens
  - `prompt_eval_duration` ns -> prefill ms
  - `eval_duration` ns -> decode ms
  - `eval_count / (eval_duration / 1e9)` -> tokens per second
  - with `--update-total-ms`, `total_duration` ns -> total ms
- Fail closed with a clear error when required fields are missing, non-numeric, zero, or negative.
- Do not invent values. Do not use byte counts as token counts.
- Do not include placeholder words like `template`, `fixture`, `synthetic`, `sample`, or `example` in generated replacement values.
- Print the output path and the updated env names on success.

Allowed verification:
- `python3 -m py_compile scripts/v61_first_real_slice_metric_replacements_from_ollama_response.py`
- Tiny temporary smoke files under `/tmp`.

Forbidden:
- Do not run model generation.
- Do not call Ollama, curl, or network APIs.
- Do not read or write `.env`, `.env.*`, `*.env`, or `*.env.*`.
- Do not edit `/mnt`.
- Do not use git push, merge, reset, checkout, or destructive commands.
