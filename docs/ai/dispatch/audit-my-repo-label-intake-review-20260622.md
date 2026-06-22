TASK: Review the new audit-my-repo human label intake slice only.

Context:
- Goal: move audit-my-repo toward design-partner beta candidate from current main.
- Do not merge branches, push, release, download, use network assets, or run GPU/heavy work.
- New slice:
  - scripts/audit_my_repo_label_intake.py
  - schemas/local_repo_audit_label_intake_manifest.schema.json
  - product/negative tests compiling verified label templates plus human decisions into benchmark_labels.jsonl
  - docs/package references

Review focus:
- Does label intake keep template-only rows separate from human-labeled benchmark rows?
- Can synthetic template rows be accidentally promoted to real evidence?
- Do non-overwrite and self-verification failure paths preserve existing user files?
- Does verify-existing reject coordinated tampering of benchmark_labels.jsonl, manifest, and sha manifest?
- Are the compiled labels actually usable by scripts/audit_my_repo_benchmark.py?

Return only:
- Findings with file/line references
- Any failing command and short output
- Suggested minimal patch, if needed
