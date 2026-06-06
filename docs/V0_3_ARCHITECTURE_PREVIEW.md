# v0.3 Architecture Preview

This document defines the public preview surface for the repository. It turns the existing RouteMemory evidence stack into a one-command local codebase audit experience without opening production, replacement-model, or GPU-speedup claims.

## Goal

```text
RouteMemory evidence
-> compact RouteHint
-> tiny non-attention generator
-> grounded answer
-> citation / abstain / audit trail
```

The preview is meant to let a reader clone the repository and run an evidence-bound audit on a local repo. The message is local QA/audit assistance, not Transformer replacement.

## Commands

```bash
./scripts/audit_my_repo.sh /path/to/repo --emit-report --emit-lineage --emit-reproduce
./scripts/run_routehint_generator_mainline.sh /path/to/repo
./examples/local_codebase_intelligence_box.sh /path/to/repo
./experiments/test_v0_3_architecture_preview.sh
```

## Emitted Artifacts

`scripts/audit_my_repo.sh` writes:

- `AUDIT_REPORT.md`
- `audit_findings.jsonl`
- `citation_spans.jsonl`
- `prediction_lineage.jsonl`
- `mmap_read_trace.jsonl`
- `compact_route_hint_rows.csv`
- `grounded_generation_rows.csv`
- `abstain_rows.csv`
- `unsupported_claim_rows.csv`
- `resource_envelope.json`
- `reproduce.sh`
- `sha256sums.txt`

`examples/local_codebase_intelligence_box.sh` writes a showcase bundle with:

- `README_RESULT.md`
- `AUDIT_REPORT.md`
- `BASELINE_COMPARISON.md`
- `LOCAL_SCALING_SUMMARY.md`
- `ARCHITECTURE_TRACE.md`
- lineage, citation, RouteHint, generation, abstain, resource, reproduce, and hash artifacts

`experiments/run_v0_3_architecture_preview.sh` additionally binds the showcase to the existing `v14c` baseline comparison artifacts and emits the preview summary/decision CSVs.

## Passing Criteria

- `v0_3_architecture_preview_ready=1`
- `one_command_repo_audit_ready=1`
- `baseline_war_ready=1`
- `routehint_generator_mainline_ready=1`
- `local_codebase_intelligence_box_ready=1`
- `raw_prompt_context_bytes=0`
- `attention_blocks=0`
- `transformer_blocks=0`
- `oracle_prediction_used=0`
- `raw_input_extractor_used=0`

## Claim Boundary

Allowed wording:

```text
A local evidence-bound RouteMemory QA/audit architecture prototype.
```

Blocked wording:

- Transformer replacement
- frontier local LLM
- production-ready release
- expert replacement
- long-context solved
- GPU acceleration proven

The preview keeps `real_release_package_ready=0` and `gpu_speedup_claim=deferred`.

## Next Research Step

The preview closes the local user-experience surface. The next high-value work is not another internal wrapper; it is real external acceptance or teacher-source authority evidence:

- external/human or buyer PoC acceptance return
- real teacher-source import/review authority package
- human review only when release-ready wording becomes necessary
