TASK: Review the label template/intake evidence-boundary change only.

Context:
- Goal: audit-my-repo design-partner beta candidate progress from current main.
- Do not merge, push, release, download, use network assets, or run GPU/heavy work.
- This slice changes fixture/synthetic label templates so they compile to synthetic/non-real benchmark labels.

Review focus:
- scripts/audit_my_repo_label_template.py: build_template_rows should emit synthetic=0 only when the source audit namespace is confirmed real_benchmark.
- schemas/local_repo_audit_label_template_manifest.schema.json should bind the source real_benchmark confirmation field.
- scripts/audit_my_repo_label_intake.py should preserve the template row synthetic value into benchmark_labels.jsonl and manifest synthetic_label_rows.
- Tests should catch fixture-derived templates or intake labels becoming non-synthetic.

Return only:
- Findings with file/line references
- Any failing command and short output
- Suggested minimal patch, if needed
