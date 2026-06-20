# v52 Adapter And D/E Guard Contract

`baselines/v52_adapter_guard.json` binds two separate v52 facts:

- System C has a replayable 1000-row local 7B-14B response packet over v53e.
- Required D/E 30B/70B measured registry admission remains blocked until real
  pinned evidence directories validate.

Verify the contract with:

```bash
tools/verify_artifact.py v52-adapter-guard baselines/v52_adapter_guard.json \
  --v52c-summary results/v52c_7b14b_local_model_rag_evidence_intake_summary.csv \
  --v52d-summary results/v52d_30b70b_llm_rag_evidence_intake_summary.csv \
  --v52l-summary results/v52l_7b14b_local_model_rag_v53e_1000_summary.csv \
  --v52r-summary results/v52r_measured_registry_de_absorb_summary.csv \
  --v52y-summary results/v52y_f_optional_final_policy_summary.csv
```

Allowed wording:

- C emits a local 7B-14B actual response/resource/transcript packet.
- C is a schema pressure test and same-surface response packet.
- D/E intake guards and measured registry blockers are explicit.

Blocked wording:

- C quality improvement or public comparison.
- D/E 30B/70B measured baseline readiness.
- F optional baseline replacing D/E.
- v52 final readiness or release readiness.
