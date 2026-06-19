#!/usr/bin/env python3
"""Verify small pipeline and artifact manifests without external dependencies."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
from pathlib import Path


REQUIRED_PIPELINE_KEYS = {"schema_version", "pipeline_id", "claim_boundary", "stages"}
REQUIRED_STAGE_KEYS = {"stage_id", "adapter", "command", "outputs", "ready_fields", "claim_boundary"}
REQUIRED_PR_SPLIT_KEYS = {
    "schema_version",
    "draft_pr",
    "split_required",
    "recommended_title",
    "recommended_body",
    "merge_gate_policy",
    "slices",
}
REQUIRED_PR_SLICE_KEYS = {
    "slice_id",
    "scope",
    "required_artifacts",
    "merge_gates",
    "claim_boundary",
    "verification_commands",
    "current_status",
}
REQUIRED_TYPED_READINESS_KEYS = {
    "schema_version",
    "policy",
    "rows",
}
REQUIRED_TYPED_READINESS_ROW_KEYS = {
    "scope_id",
    "contract_ready",
    "fixture_execution_ready",
    "real_model_execution_ready",
    "heldout_metric_ready",
    "human_review_ready",
    "independent_reproduction_ready",
    "release_ready",
    "misleading_ready_flag",
    "replacement_flag",
    "ready_wording_policy",
    "evidence_path",
}
REQUIRED_LEAKAGE_KEYS = {
    "schema_version",
    "policy",
    "forbidden_surfaces",
    "stage_contracts",
}
REQUIRED_LEAKAGE_SURFACE_KEYS = {
    "guard_id",
    "forbidden_surface",
    "field_names",
    "evaluator_only_or_absent",
}
REQUIRED_LEAKAGE_STAGE_KEYS = {
    "stage_id",
    "summary_path",
    "allowed_model_visible_fields",
    "must_equal",
}
REQUIRED_BASELINE_ADMISSION_KEYS = {
    "schema_version",
    "policy",
    "required_real_evidence_fields",
    "systems",
    "required_artifacts",
}
REQUIRED_BASELINE_SYSTEM_KEYS = {
    "system_id",
    "baseline_class",
    "parameter_count_b_min",
    "parameter_count_b_max",
    "evidence_env",
    "measured_registry_admission_ready",
    "acceptance_test",
}
REQUIRED_BASELINE_ARTIFACT_KEYS = {
    "artifact_id",
    "artifact_kind",
    "required_columns",
}
REQUIRED_V52_ADAPTER_GUARD_KEYS = {
    "schema_version",
    "policy",
    "requirements",
}
REQUIRED_V52_REQUIREMENT_KEYS = {
    "requirement_id",
    "required_evidence",
    "current_status",
    "evidence_path",
    "claim_boundary",
}
REQUIRED_V50_AUDITOR_KEYS = {
    "schema_version",
    "policy",
    "required_artifacts",
    "claim_boundaries",
}
REQUIRED_V50_ARTIFACT_KEYS = {
    "artifact_id",
    "path",
    "required_for_merge",
}
REQUIRED_V50_BOUNDARY_KEYS = {
    "claim_id",
    "allowed",
    "blocked",
}
REQUIRED_V53_SOURCE_BENCHMARK_KEYS = {
    "schema_version",
    "policy",
    "requirements",
}
REQUIRED_V53_REQUIREMENT_KEYS = {
    "requirement_id",
    "required_evidence",
    "current_status",
    "evidence_path",
    "claim_boundary",
}
REQUIRED_V58_BLIND_EVAL_KEYS = {
    "schema_version",
    "policy",
    "required_systems",
    "requirements",
    "required_artifacts",
}
REQUIRED_V58_REQUIREMENT_KEYS = {
    "requirement_id",
    "required_evidence",
}
REQUIRED_V58_ARTIFACT_KEYS = {
    "artifact_id",
    "artifact_kind",
    "validation_command",
}
REQUIRED_REVIEW_RETURN_WORKFLOW_KEYS = {
    "schema_version",
    "policy",
    "requirements",
}
REQUIRED_REVIEW_RETURN_REQUIREMENT_KEYS = {
    "requirement_id",
    "required_evidence",
    "current_status",
    "evidence_path",
    "claim_boundary",
}
REQUIRED_V61_ONE_TOKEN_KEYS = {
    "schema_version",
    "policy",
    "milestones",
    "required_artifacts",
}
REQUIRED_V61_MILESTONE_KEYS = {
    "order",
    "milestone_id",
    "required_evidence",
    "current_status",
    "evidence_path",
    "claim_boundary",
}
REQUIRED_V61_ARTIFACT_KEYS = {
    "artifact_id",
    "artifact_kind",
    "required_columns",
}
EXPECTED_PR2_SLICE_ORDER = [
    "docs/v1-roadmap",
    "v50-auditor-correctness",
    "v52-baseline-registry-contract",
    "v53-public-repo-source-manifest",
    "v53-query-instantiation-1000",
    "v53-system-a-b-g-h-measured",
    "v54-routehint-generation-contract",
    "v56-ruler-longbench-expanded",
    "v58-blind-eval-contract",
    "v59-one-command-demo",
    "v61-ssd-moe-runtime-roadmap",
    "operator-review-return-workflow",
    "docs-readme-pr2-cleanup",
]
REQUIRED_PR_MERGE_GATES = {
    "claim-boundary",
    "replay-artifact",
    "blocker-false-positive",
}
REQUIRED_PR2_REWRITE_TERMS = {
    "not mergeable as one unit",
    "typed readiness",
    "retrieval leakage",
    "D/E",
    "operator/review-return",
    "one-token logits parity",
    "actual generation",
    "release claims remain blocked",
}
TESTS_ONLY_MERGE_CONDITIONS = {"tests pass", "test pass", "tests", "test", "ci green"}
TYPED_READINESS_KEYS = {
    "contract_ready",
    "fixture_execution_ready",
    "real_model_execution_ready",
    "heldout_metric_ready",
    "human_review_ready",
    "independent_reproduction_ready",
    "release_ready",
}
AMBIGUOUS_READY_FLAGS = {
    "100b_moe_run_ready",
    "v53_ready",
    "v58_ready",
    "v59_ready",
    "v60_ready",
    "h10_real_label_promotion_ready",
}
EXPECTED_LEAKAGE_GUARD_IDS = [
    "source-span-id",
    "source-path",
    "source-line",
    "source-file-hash",
    "query-source-direct-binding",
    "expected-behavior",
    "expected-label",
]
FORBIDDEN_MODEL_VISIBLE_FIELDS = {
    "source_span_id",
    "span_id",
    "source_path",
    "source_file_path",
    "path",
    "source_line_start",
    "source_line_end",
    "line_start",
    "line_end",
    "source_file_hash",
    "source_file_sha256",
    "source_git_blob_sha",
    "query_id",
    "source_row_id",
    "source_query_id",
    "query_source_id",
    "source_binding_id",
    "expected_behavior",
    "expected_answer",
    "expected_answer_sha256",
    "expected_output",
    "gold_answer",
    "negative_or_abstain",
    "audit_type",
    "expected_label",
}
REQUIRED_DE_REAL_EVIDENCE_FIELDS = {
    "model_repository_exact_revision",
    "quantization",
    "model_artifact_hash",
    "runtime",
    "prompt_template",
    "context_budget",
    "retrieval_budget",
    "hardware",
    "seed",
    "answer_citation_raw_output",
    "evaluator_version",
}
EXPECTED_DE_REQUIRED_ARTIFACT_COLUMNS = {
    "model-identity": {
        "system_id",
        "baseline_class",
        "model_repository",
        "model_revision",
        "parameter_count_b",
        "quantization",
        "model_artifact_sha256",
        "open_weight_license_uri",
        "runtime",
        "runtime_version",
        "hardware",
        "external_api_used",
        "non_fixture_declared",
    },
    "answer-citation-raw-output": {
        "system_id",
        "query_id",
        "same_query_set_id",
        "prompt_template_sha256",
        "context_budget",
        "retrieval_budget",
        "seed",
        "raw_answer",
        "raw_citation",
        "raw_output_sha256",
        "generation_transcript_sha256",
        "non_fixture_declared",
    },
    "resource-evaluator-manifest": {
        "system_id",
        "query_id",
        "latency_ms",
        "peak_memory_mb",
        "evaluator_version",
        "evaluator_artifact_sha256",
        "same_query_set_id",
        "same_source_manifest_sha256",
        "answer_rows_sha256",
        "citation_rows_sha256",
        "fixture_rows",
        "measured_registry_candidate",
    },
}
EXPECTED_V58_REQUIREMENT_IDS = [
    "ab-cdegh-real-responses",
    "same-corpus-context-budget",
    "blind-identity",
    "two-independent-reviewers",
    "disagreement-adjudication",
    "unseen-repository-split",
    "source-span-exactness",
    "unsupported-abstention",
    "latency-memory-separate",
]
EXPECTED_V53_REQUIREMENT_IDS = [
    "pinned-public-repo-manifest",
    "source-span-bound-1000-query-surface",
    "negative-unsupported-missing-doc-code-controls",
    "answer-citation-resource-separate-evaluator",
    "abgh-same-query-internal-prebaseline",
    "sanitized-question-only-adapter-selection",
]
EXPECTED_V50_ARTIFACT_IDS = [
    "source-snapshot-rows",
    "audit-case-rows",
    "source-span-rows",
    "guard-negative-rows",
    "commercial-return-query-set",
    "commercial-return-poc-results",
    "commercial-return-audit-trail",
    "sha256-manifest",
]
EXPECTED_V50_DECISION_GATES = [
    "v50-public-repo-auditor-3repo",
    "public-repo-count",
    "pinned-repo-refs",
    "source-snapshot",
    "doc-code-conflict",
    "deprecated-usage",
    "config-mismatch",
    "source-citation-audit-trail",
    "guard-negative-controls",
    "v18-intake",
]
EXPECTED_V52_REQUIREMENT_IDS = [
    "c-7b14b-v53e-actual-adapter-packet",
    "c-7b14b-quality-boundary",
    "c-7b14b-intake-default-blocked",
    "de-30b70b-intake-fail-closed",
    "de-measured-registry-blocked",
]
EXPECTED_V53_V1_EXIT_CRITERION_IDS = [
    "repo-count-band-10-30",
    "query-row-band-1000-3000",
    "negative-abstain-and-control-families",
    "answer-citation-separate-evaluator",
    "abgh-same-query-internal-prebaseline",
    "claim-boundary-replay-blocker-gate",
]
EXPECTED_V58_ARTIFACT_IDS = [
    "v58-blind-response-rows",
    "v58-run-identity-rows",
    "v58-query-split-rows",
    "v58-resource-rows",
    "v58-human-review-rows",
    "v58-adjudication-rows",
    "v58d-review-return-intake",
    "v58-sha256-manifest",
]
EXPECTED_V58_ARTIFACT_COLUMNS = {
    "v58-blind-response-rows": {
        "blind_run_id",
        "system_blind_id",
        "query_id",
        "answer_text",
        "citation_text",
        "response_sha256",
    },
    "v58-run-identity-rows": {
        "blind_run_id",
        "system_id",
        "system_blind_id",
        "corpus_id",
        "context_budget",
        "retrieval_budget",
        "prompt_template_sha256",
    },
    "v58-query-split-rows": {
        "query_id",
        "repo_id",
        "split_name",
        "unseen_repository",
        "frozen_query_packet_sha256",
        "source_manifest_sha256",
    },
    "v58-resource-rows": {
        "blind_run_id",
        "system_blind_id",
        "query_id",
        "latency_ms",
        "peak_memory_mb",
        "tokens_per_second",
        "resource_sha256",
    },
    "v58-human-review-rows": {
        "blind_run_id",
        "system_blind_id",
        "query_id",
        "response_sha256",
        "reviewer_id",
        "reviewer_blinded",
        "reviewer_independent",
        "conflict_disclosure_sha256",
        "answer_quality_score",
        "citation_score",
        "source_span_exact",
        "unsupported_abstain_score",
    },
    "v58-adjudication-rows": {
        "blind_run_id",
        "system_blind_id",
        "query_id",
        "response_sha256",
        "reviewer_a_id",
        "reviewer_b_id",
        "disagreement_type",
        "adjudicator_id",
        "adjudicated_answer_quality_score",
        "adjudicated_citation_score",
        "adjudicated_source_span_exact",
        "adjudicated_unsupported_abstain_score",
    },
    "v58d-review-return-intake": {
        "review_dir",
        "accepted_blind_review_rows",
        "accepted_adjudication_rows",
        "inter_rater_rows",
        "review_return_ready",
    },
    "v58-sha256-manifest": {"artifact_path", "sha256", "bytes"},
}
V58_REVIEW_FORBIDDEN_RESOURCE_COLUMNS = {"latency_ms", "memory_mb", "peak_memory_mb", "tokens_per_second"}
EXPECTED_REVIEW_RETURN_REQUIREMENT_IDS = [
    "v53-review-return-intake-blocked",
    "v58-blind-review-return-blocked",
    "v61-operator-bundle-logistics-only",
    "v61-first-slice-operator-input-blocked",
]
EXPECTED_V61_MILESTONE_IDS = [
    "actual-mixtral-ssd-tensor-page-read",
    "actual-tensor-dtype-quant-dequant",
    "torch-matvec-parity",
    "real-expert-ffn-forward-parity",
    "real-moe-block-forward-parity",
    "one-token-logits-parity",
    "sixteen-token-decode",
    "cold-warm-cache-measurement",
    "ssd-bytes-miss-tps-recording",
]
V61_REQUIRED_BEFORE_RUNTIME_CLAIM = EXPECTED_V61_MILESTONE_IDS[:6]
EXPECTED_V61_CURRENT_STATUS = {
    "actual-mixtral-ssd-tensor-page-read": "pass",
    "actual-tensor-dtype-quant-dequant": "pass",
    "torch-matvec-parity": "pass",
    "real-expert-ffn-forward-parity": "blocked",
    "real-moe-block-forward-parity": "blocked",
    "one-token-logits-parity": "blocked",
    "sixteen-token-decode": "blocked",
    "cold-warm-cache-measurement": "blocked",
    "ssd-bytes-miss-tps-recording": "blocked",
}
EXPECTED_V61_REQUIRED_ARTIFACT_COLUMNS = {
    "expert-ffn-forward-parity-rows": {
        "layer_index",
        "expert_index",
        "w1_tensor_name",
        "w2_tensor_name",
        "w3_tensor_name",
        "contract_ready",
        "fixture_execution_ready",
        "real_model_execution_ready",
        "heldout_metric_ready",
        "human_review_ready",
        "independent_reproduction_ready",
        "release_ready",
        "local_checkpoint_root_supplied",
        "checkpoint_payload_bytes_committed_to_repo",
        "actual_model_generation_ready",
        "route_jump_rows",
        "status",
        "reason",
        "w1_shape",
        "w2_shape",
        "w3_shape",
        "w1_payload_sha256",
        "w2_payload_sha256",
        "w3_payload_sha256",
        "input_hidden_size",
        "intermediate_size",
        "output_hidden_size",
        "candidate_output_sha256",
        "torch_reference_output_sha256",
        "max_abs_delta",
        "tolerance",
        "expert_ffn_parity_pass",
    },
    "moe-block-forward-parity-rows": {
        "checkpoint_id",
        "model_revision",
        "layer_index",
        "token_id",
        "contract_ready",
        "fixture_execution_ready",
        "real_model_execution_ready",
        "heldout_metric_ready",
        "human_review_ready",
        "independent_reproduction_ready",
        "release_ready",
        "local_checkpoint_root_supplied",
        "checkpoint_payload_bytes_committed_to_repo",
        "actual_model_generation_ready",
        "route_jump_rows",
        "status",
        "reason",
        "expert_ffn_artifact_sha256",
        "input_hidden_sha256",
        "router_tensor_name",
        "router_payload_sha256",
        "router_logits_sha256",
        "selected_expert_ids",
        "selected_expert_weights",
        "selected_expert_payload_sha256s",
        "expert_output_sha256",
        "moe_block_output_sha256",
        "torch_reference_output_sha256",
        "max_abs_delta",
        "tolerance",
        "moe_block_parity_pass",
    },
    "one-token-logits-parity-rows": {
        "checkpoint_id",
        "model_revision",
        "tokenizer_revision",
        "contract_ready",
        "fixture_execution_ready",
        "real_model_execution_ready",
        "heldout_metric_ready",
        "human_review_ready",
        "independent_reproduction_ready",
        "release_ready",
        "local_checkpoint_root_supplied",
        "checkpoint_payload_bytes_committed_to_repo",
        "actual_model_generation_ready",
        "route_jump_rows",
        "status",
        "reason",
        "moe_block_artifact_sha256",
        "tokenizer_input_sha256",
        "route_path_sha256",
        "final_hidden_sha256",
        "lm_head_tensor_name",
        "lm_head_payload_sha256",
        "vocab_size",
        "logit_count",
        "candidate_logits_sha256",
        "torch_reference_logits_sha256",
        "max_abs_delta",
        "tolerance",
        "top1_token_id",
        "reference_top1_token_id",
        "logits_parity_pass",
    },
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def load_pipeline(path: Path) -> dict:
    # Seed pipeline files are JSON-compatible YAML so we can stay stdlib-only.
    return json.loads(path.read_text(encoding="utf-8"))


def verify_pipeline(path: Path) -> list[str]:
    errors: list[str] = []
    data = load_pipeline(path)
    missing = REQUIRED_PIPELINE_KEYS - set(data)
    if missing:
        errors.append(f"{path}: missing pipeline keys: {', '.join(sorted(missing))}")
        return errors
    if data["schema_version"] != "pipeline.v1":
        errors.append(f"{path}: unsupported schema_version={data['schema_version']}")
    if not isinstance(data["stages"], list) or not data["stages"]:
        errors.append(f"{path}: stages must be a non-empty list")
        return errors
    stage_ids = [stage.get("stage_id", "") for stage in data["stages"]]
    stage_id_set = set(stage_ids)
    stage_index = {stage_id: index for index, stage_id in enumerate(stage_ids)}
    seen = set()
    for index, stage in enumerate(data["stages"], start=1):
        prefix = f"{path}: stage[{index}]"
        missing_stage = REQUIRED_STAGE_KEYS - set(stage)
        if missing_stage:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_stage))}")
        stage_id = stage.get("stage_id", "")
        if not stage_id:
            errors.append(f"{prefix}: empty stage_id")
        if stage_id in seen:
            errors.append(f"{prefix}: duplicate stage_id={stage_id}")
        seen.add(stage_id)
        if stage.get("adapter") != "shell":
            errors.append(f"{prefix}: only shell adapters are supported in the seed runner")
        if not isinstance(stage.get("command"), list) or not stage.get("command"):
            errors.append(f"{prefix}: command must be a non-empty argv list")
        if not isinstance(stage.get("outputs"), list) or not stage.get("outputs"):
            errors.append(f"{prefix}: outputs must be a non-empty list")
        if not isinstance(stage.get("ready_fields"), list) or not stage.get("ready_fields"):
            errors.append(f"{prefix}: ready_fields must be a non-empty list")
        typed = stage.get("typed_readiness", {})
        if set(typed) != TYPED_READINESS_KEYS:
            errors.append(f"{prefix}: typed_readiness keys must be exactly {', '.join(sorted(TYPED_READINESS_KEYS))}")
        if not stage.get("claim_boundary"):
            errors.append(f"{prefix}: claim_boundary must be non-empty")
        requires = stage.get("requires", [])
        if not isinstance(requires, list):
            errors.append(f"{prefix}: requires must be a list when present")
        else:
            for requirement in requires:
                if requirement not in stage_id_set:
                    errors.append(f"{prefix}: unknown requirement={requirement}")
                elif requirement == stage_id:
                    errors.append(f"{prefix}: stage cannot require itself")
                elif stage_index[requirement] >= stage_index[stage_id]:
                    errors.append(f"{prefix}: requirement must appear before dependent stage: {requirement}")
        runtime_overrides = stage.get("runtime_overrides", [])
        if not isinstance(runtime_overrides, list):
            errors.append(f"{prefix}: runtime_overrides must be a list when present")
        if "evidence_boundary" in stage and not stage["evidence_boundary"]:
            errors.append(f"{prefix}: evidence_boundary must be non-empty when present")
    return errors


def verify_pr_split(path: Path) -> list[str]:
    errors: list[str] = []
    data = json.loads(path.read_text(encoding="utf-8"))
    missing = REQUIRED_PR_SPLIT_KEYS - set(data)
    if missing:
        errors.append(f"{path}: missing PR split keys: {', '.join(sorted(missing))}")
        return errors
    if data["schema_version"] != "pr_split.v1":
        errors.append(f"{path}: unsupported schema_version={data['schema_version']}")
    if data["draft_pr"] != "PR #2":
        errors.append(f"{path}: draft_pr must be PR #2")
    if data["split_required"] is not True:
        errors.append(f"{path}: split_required must be true")
    if not data["recommended_title"] or "Split" not in data["recommended_title"]:
        errors.append(f"{path}: recommended_title must describe the split")
    if not isinstance(data["recommended_body"], list) or not data["recommended_body"]:
        errors.append(f"{path}: recommended_body must be a non-empty list")
    if data["draft_pr"] == "PR #2":
        body_text = "\n".join(str(row) for row in data["recommended_body"])
        missing_terms = [term for term in REQUIRED_PR2_REWRITE_TERMS if term not in body_text]
        if missing_terms:
            errors.append(f"{path}: recommended_body missing PR #2 rewrite terms: {', '.join(sorted(missing_terms))}")
    policy = data["merge_gate_policy"]
    if policy.get("forbid_tests_only") is not True:
        errors.append(f"{path}: merge_gate_policy.forbid_tests_only must be true")
    if set(policy.get("required_gates", [])) != REQUIRED_PR_MERGE_GATES:
        errors.append(f"{path}: required_gates must be exactly {', '.join(sorted(REQUIRED_PR_MERGE_GATES))}")
    slices = data["slices"]
    if not isinstance(slices, list) or not slices:
        errors.append(f"{path}: slices must be a non-empty list")
        return errors
    slice_ids = [row.get("slice_id", "") for row in slices]
    if len(slice_ids) != len(set(slice_ids)):
        errors.append(f"{path}: duplicate slice_id values are forbidden")
    if data["draft_pr"] == "PR #2" and slice_ids != EXPECTED_PR2_SLICE_ORDER:
        errors.append(f"{path}: PR #2 slice order must match the PM contract")
    for index, row in enumerate(slices, start=1):
        prefix = f"{path}: slice[{index}]"
        missing_slice = REQUIRED_PR_SLICE_KEYS - set(row)
        if missing_slice:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_slice))}")
        slice_id = row.get("slice_id", "")
        if not slice_id:
            errors.append(f"{prefix}: empty slice_id")
        if not row.get("scope"):
            errors.append(f"{prefix}: scope must be non-empty")
        if set(row.get("merge_gates", [])) != REQUIRED_PR_MERGE_GATES:
            errors.append(f"{prefix}: merge_gates must be exactly {', '.join(sorted(REQUIRED_PR_MERGE_GATES))}")
        if any(gate.strip().lower() in TESTS_ONLY_MERGE_CONDITIONS for gate in row.get("merge_gates", [])):
            errors.append(f"{prefix}: tests-only merge gate is forbidden")
        if not isinstance(row.get("required_artifacts"), list) or not row["required_artifacts"]:
            errors.append(f"{prefix}: required_artifacts must be a non-empty list")
        if not isinstance(row.get("verification_commands"), list) or not row["verification_commands"]:
            errors.append(f"{prefix}: verification_commands must be a non-empty list")
        if any(command.strip().lower() in TESTS_ONLY_MERGE_CONDITIONS for command in row.get("verification_commands", [])):
            errors.append(f"{prefix}: tests-only verification command is forbidden")
        boundary = row.get("claim_boundary", {})
        for field in ["allowed", "blocked", "evidence_path"]:
            if not boundary.get(field):
                errors.append(f"{prefix}: claim_boundary.{field} must be non-empty")
        if boundary.get("allowed", "").strip().lower() in TESTS_ONLY_MERGE_CONDITIONS:
            errors.append(f"{prefix}: claim_boundary.allowed cannot be tests-only")
        if not row.get("current_status"):
            errors.append(f"{prefix}: current_status must be non-empty")
    return errors


def bool_to_csv(value: bool) -> str:
    return "1" if value else "0"


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def verify_typed_readiness(path: Path, pm_ledger: Path | None = None) -> list[str]:
    errors: list[str] = []
    data = json.loads(path.read_text(encoding="utf-8"))
    missing = REQUIRED_TYPED_READINESS_KEYS - set(data)
    if missing:
        errors.append(f"{path}: missing typed readiness keys: {', '.join(sorted(missing))}")
        return errors
    if data["schema_version"] != "typed_readiness.v1":
        errors.append(f"{path}: unsupported schema_version={data['schema_version']}")
    policy = data["policy"]
    if policy.get("forbid_ambiguous_ready_claims") is not True:
        errors.append(f"{path}: policy.forbid_ambiguous_ready_claims must be true")
    if set(policy.get("typed_fields", [])) != TYPED_READINESS_KEYS:
        errors.append(f"{path}: policy.typed_fields must be exactly {', '.join(sorted(TYPED_READINESS_KEYS))}")
    rows = data["rows"]
    if not isinstance(rows, list) or not rows:
        errors.append(f"{path}: rows must be a non-empty list")
        return errors
    scope_ids = [row.get("scope_id", "") for row in rows]
    if len(scope_ids) != len(set(scope_ids)):
        errors.append(f"{path}: duplicate scope_id values are forbidden")
    replacements = [row.get("replacement_flag", "") for row in rows]
    if len(replacements) != len(set(replacements)):
        errors.append(f"{path}: duplicate replacement_flag values are forbidden")
    replacement_set = set(replacements)
    if "logical_100b_contract_fixture_ready" not in replacement_set:
        errors.append(f"{path}: logical_100b_contract_fixture_ready replacement row is required")
    if "real_100b_inference_ready" not in replacement_set:
        errors.append(f"{path}: real_100b_inference_ready replacement row is required")

    for index, row in enumerate(rows, start=1):
        prefix = f"{path}: readiness[{index}]"
        missing_row = REQUIRED_TYPED_READINESS_ROW_KEYS - set(row)
        if missing_row:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_row))}")
        for field in TYPED_READINESS_KEYS:
            if not isinstance(row.get(field), bool):
                errors.append(f"{prefix}: {field} must be boolean")
        misleading = row.get("misleading_ready_flag", "")
        replacement = row.get("replacement_flag", "")
        if not misleading or not replacement:
            errors.append(f"{prefix}: misleading_ready_flag and replacement_flag must be non-empty")
        if misleading == replacement:
            errors.append(f"{prefix}: replacement_flag must differ from misleading_ready_flag")
        if replacement in AMBIGUOUS_READY_FLAGS:
            errors.append(f"{prefix}: replacement_flag cannot be an ambiguous ready flag")
        if row.get("ready_wording_policy") != "typed-ready-only":
            errors.append(f"{prefix}: ready_wording_policy must be typed-ready-only")
        if "pm_ledger_required" in row and not isinstance(row.get("pm_ledger_required"), bool):
            errors.append(f"{prefix}: pm_ledger_required must be boolean when present")
        if not row.get("evidence_path"):
            errors.append(f"{prefix}: evidence_path must be non-empty")
        if row.get("real_model_execution_ready") is True:
            errors.append(f"{prefix}: current contract must not mark real_model_execution_ready=true")
        if row.get("release_ready") is True:
            errors.append(f"{prefix}: current contract must not mark release_ready=true")
        if replacement == "logical_100b_contract_fixture_ready":
            if row.get("contract_ready") is not True or row.get("fixture_execution_ready") is not True:
                errors.append(f"{prefix}: logical 100B row must be contract+fixture ready")
            if row.get("real_model_execution_ready") is not False:
                errors.append(f"{prefix}: logical 100B row must keep real_model_execution_ready=false")
        if replacement == "real_100b_inference_ready":
            if any(row.get(field) is True for field in TYPED_READINESS_KEYS):
                errors.append(f"{prefix}: real_100b_inference_ready row must stay all-false until real inference exists")

    if pm_ledger is not None:
        ledger_rows = read_csv_rows(pm_ledger)
        by_replacement = {row.get("replacement_flag", ""): row for row in ledger_rows}
        for row in rows:
            if row.get("pm_ledger_required") is False:
                continue
            replacement = row["replacement_flag"]
            ledger = by_replacement.get(replacement)
            if ledger is None:
                errors.append(f"{pm_ledger}: missing replacement_flag={replacement}")
                continue
            if ledger.get("scope_id") != row["scope_id"]:
                errors.append(f"{pm_ledger}: scope_id mismatch for {replacement}")
            if ledger.get("misleading_ready_flag") != row["misleading_ready_flag"]:
                errors.append(f"{pm_ledger}: misleading_ready_flag mismatch for {replacement}")
            if ledger.get("ready_wording_policy") != row["ready_wording_policy"]:
                errors.append(f"{pm_ledger}: ready_wording_policy mismatch for {replacement}")
            for field in TYPED_READINESS_KEYS:
                if ledger.get(field) != bool_to_csv(row[field]):
                    errors.append(f"{pm_ledger}: {replacement}.{field} expected {bool_to_csv(row[field])}, got {ledger.get(field)}")
    return errors


def read_first_csv(path: Path) -> dict[str, str]:
    if not path.is_file() or path.stat().st_size == 0:
        return {}
    rows = read_csv_rows(path)
    return rows[0] if rows else {}


def verify_leakage(path: Path, pm_ledger: Path | None = None) -> list[str]:
    errors: list[str] = []
    data = json.loads(path.read_text(encoding="utf-8"))
    missing = REQUIRED_LEAKAGE_KEYS - set(data)
    if missing:
        errors.append(f"{path}: missing leakage keys: {', '.join(sorted(missing))}")
        return errors
    if data["schema_version"] != "leakage_contract.v1":
        errors.append(f"{path}: unsupported schema_version={data['schema_version']}")
    policy = data["policy"]
    if policy.get("allowed_surface") != "natural_language_question_plus_searchable_corpus":
        errors.append(f"{path}: allowed_surface must be natural_language_question_plus_searchable_corpus")
    if policy.get("direct_query_source_binding_forbidden") is not True:
        errors.append(f"{path}: direct_query_source_binding_forbidden must be true")

    surfaces = data["forbidden_surfaces"]
    if not isinstance(surfaces, list) or not surfaces:
        errors.append(f"{path}: forbidden_surfaces must be a non-empty list")
        return errors
    guard_ids = [row.get("guard_id", "") for row in surfaces]
    if guard_ids != EXPECTED_LEAKAGE_GUARD_IDS:
        errors.append(f"{path}: forbidden surface order must match the PM leakage guard contract")
    if len(guard_ids) != len(set(guard_ids)):
        errors.append(f"{path}: duplicate guard_id values are forbidden")
    declared_forbidden_fields: set[str] = set()
    for index, row in enumerate(surfaces, start=1):
        prefix = f"{path}: forbidden_surface[{index}]"
        missing_row = REQUIRED_LEAKAGE_SURFACE_KEYS - set(row)
        if missing_row:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_row))}")
        if row.get("evaluator_only_or_absent") is not True:
            errors.append(f"{prefix}: evaluator_only_or_absent must be true")
        fields = row.get("field_names", [])
        if not isinstance(fields, list) or not fields:
            errors.append(f"{prefix}: field_names must be a non-empty list")
        declared_forbidden_fields.update(str(field) for field in fields)
    if not FORBIDDEN_MODEL_VISIBLE_FIELDS.issubset(declared_forbidden_fields):
        missing_fields = FORBIDDEN_MODEL_VISIBLE_FIELDS - declared_forbidden_fields
        errors.append(f"{path}: missing forbidden field coverage: {', '.join(sorted(missing_fields))}")

    stages = data["stage_contracts"]
    if not isinstance(stages, list) or not stages:
        errors.append(f"{path}: stage_contracts must be a non-empty list")
        return errors
    stage_ids = [stage.get("stage_id", "") for stage in stages]
    if len(stage_ids) != len(set(stage_ids)):
        errors.append(f"{path}: duplicate stage_id values are forbidden")
    for index, stage in enumerate(stages, start=1):
        prefix = f"{path}: stage_contract[{index}]"
        missing_stage = REQUIRED_LEAKAGE_STAGE_KEYS - set(stage)
        if missing_stage:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_stage))}")
        surface_kind = stage.get("surface_kind", "model_or_retriever")
        if surface_kind not in {"model_or_retriever", "fixture_or_evaluator_replay", "source_bound_non_model_adapter"}:
            errors.append(f"{prefix}: unsupported surface_kind={surface_kind}")
        allowed = stage.get("allowed_model_visible_fields", [])
        if not isinstance(allowed, list) or not allowed:
            errors.append(f"{prefix}: allowed_model_visible_fields must be non-empty")
        leaked = set(allowed) & FORBIDDEN_MODEL_VISIBLE_FIELDS
        if leaked:
            errors.append(f"{prefix}: allowed_model_visible_fields contains forbidden field(s): {', '.join(sorted(leaked))}")
        if surface_kind in {"fixture_or_evaluator_replay", "source_bound_non_model_adapter"} and allowed != ["none"]:
            errors.append(f"{prefix}: non-model-visible stages must use allowed_model_visible_fields=['none']")
        must_equal = stage.get("must_equal", {})
        if not isinstance(must_equal, dict) or not must_equal:
            errors.append(f"{prefix}: must_equal must be a non-empty object")
        summary_path = Path(stage.get("summary_path", ""))
        summary = read_first_csv(summary_path)
        if summary:
            if surface_kind == "fixture_or_evaluator_replay":
                if summary.get("actual_adapter_execution_ready") not in {"", None, "0"}:
                    errors.append(f"{summary_path}: {stage.get('stage_id', '')}.actual_adapter_execution_ready must be 0 for fixture/evaluator replay")
                if summary.get("real_system_performance_claim_ready") not in {"", None, "0"}:
                    errors.append(f"{summary_path}: {stage.get('stage_id', '')}.real_system_performance_claim_ready must be 0 for fixture/evaluator replay")
            if surface_kind == "source_bound_non_model_adapter":
                if summary.get("real_system_performance_claim_ready") not in {"", None, "0"}:
                    errors.append(f"{summary_path}: {stage.get('stage_id', '')}.real_system_performance_claim_ready must be 0 for source-bound non-model adapters")
                if summary.get("public_comparison_claim_ready") not in {"", None, "0"}:
                    errors.append(f"{summary_path}: {stage.get('stage_id', '')}.public_comparison_claim_ready must be 0 for source-bound non-model adapters")
            forbidden_field_summary = stage.get("forbidden_field_summary", "")
            if forbidden_field_summary:
                summary_forbidden_fields = set(split_semicolon(summary.get(forbidden_field_summary, "").replace(",", ";")))
                missing_summary_fields = FORBIDDEN_MODEL_VISIBLE_FIELDS - summary_forbidden_fields
                if missing_summary_fields:
                    errors.append(
                        f"{summary_path}: {stage.get('stage_id', '')}.{forbidden_field_summary} missing forbidden alias coverage: "
                        f"{', '.join(sorted(missing_summary_fields))}"
                    )
            for field, expected in must_equal.items():
                if summary.get(field) != expected:
                    errors.append(f"{summary_path}: {stage.get('stage_id', '')}.{field} expected {expected}, got {summary.get(field)}")

    if pm_ledger is not None:
        ledger_rows = read_csv_rows(pm_ledger)
        by_guard = {row.get("guard_id", ""): row for row in ledger_rows}
        for surface in surfaces:
            guard_id = surface["guard_id"]
            ledger = by_guard.get(guard_id)
            if ledger is None:
                errors.append(f"{pm_ledger}: missing guard_id={guard_id}")
                continue
            if ledger.get("status") != "pass":
                errors.append(f"{pm_ledger}: {guard_id}.status expected pass, got {ledger.get('status')}")
            if ledger.get("adapter_selection_blocked") != "1":
                errors.append(f"{pm_ledger}: {guard_id}.adapter_selection_blocked must be 1")
            if ledger.get("evaluator_only_or_absent") != "1":
                errors.append(f"{pm_ledger}: {guard_id}.evaluator_only_or_absent must be 1")
            if ledger.get("allowed_adapter_surface") != policy["allowed_surface"]:
                errors.append(f"{pm_ledger}: {guard_id}.allowed_adapter_surface mismatch")
            if ledger.get("direct_query_source_binding_forbidden") != "1":
                errors.append(f"{pm_ledger}: {guard_id}.direct_query_source_binding_forbidden must be 1")
    return errors


def split_semicolon(value: str) -> set[str]:
    return {part.strip() for part in value.split(";") if part.strip()}


def verify_baseline_admission(
    path: Path,
    measured_registry_ledger: Path | None = None,
    acceptance_ledger: Path | None = None,
) -> list[str]:
    errors: list[str] = []
    data = json.loads(path.read_text(encoding="utf-8"))
    missing = REQUIRED_BASELINE_ADMISSION_KEYS - set(data)
    if missing:
        errors.append(f"{path}: missing baseline admission keys: {', '.join(sorted(missing))}")
        return errors
    if data["schema_version"] != "baseline_admission.v1":
        errors.append(f"{path}: unsupported schema_version={data['schema_version']}")
    policy = data["policy"]
    if policy.get("fixture_schema_test_allowed") is not True:
        errors.append(f"{path}: fixture_schema_test_allowed must be true")
    if policy.get("fixture_rows_in_measured_registry") is not False:
        errors.append(f"{path}: fixture_rows_in_measured_registry must be false")
    if set(policy.get("public_comparison_requires_all_systems", [])) != {"A", "B", "C", "D", "E", "G", "H"}:
        errors.append(f"{path}: public_comparison_requires_all_systems must be A/B/C/D/E/G/H")
    fields = set(data["required_real_evidence_fields"])
    if fields != REQUIRED_DE_REAL_EVIDENCE_FIELDS:
        errors.append(f"{path}: required_real_evidence_fields must be exactly {', '.join(sorted(REQUIRED_DE_REAL_EVIDENCE_FIELDS))}")
    systems = data["systems"]
    if not isinstance(systems, list) or len(systems) != 2:
        errors.append(f"{path}: systems must contain D and E")
        return errors
    by_system = {row.get("system_id", ""): row for row in systems}
    if set(by_system) != {"D", "E"}:
        errors.append(f"{path}: systems must be exactly D and E")
    expected_ranges = {"D": (25, 40, "30b-open-weight-llm-rag"), "E": (65, 80, "70b-open-weight-llm-rag")}
    for system_id, row in by_system.items():
        prefix = f"{path}: system[{system_id}]"
        missing_system = REQUIRED_BASELINE_SYSTEM_KEYS - set(row)
        if missing_system:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_system))}")
        min_b, max_b, baseline_class = expected_ranges.get(system_id, (0, 0, ""))
        if row.get("baseline_class") != baseline_class:
            errors.append(f"{prefix}: baseline_class mismatch")
        if row.get("parameter_count_b_min") != min_b or row.get("parameter_count_b_max") != max_b:
            errors.append(f"{prefix}: parameter count range mismatch")
        if row.get("measured_registry_admission_ready") is not False:
            errors.append(f"{prefix}: measured_registry_admission_ready must be false until real evidence is supplied")
        if not row.get("evidence_env", "").startswith("V52D_"):
            errors.append(f"{prefix}: evidence_env must name the V52D evidence directory variable")
        if "test_v52d_30b70b_llm_rag_evidence_intake.sh" not in row.get("acceptance_test", ""):
            errors.append(f"{prefix}: acceptance_test must use the v52d evidence intake")

    artifacts = data["required_artifacts"]
    artifact_ids = [row.get("artifact_id", "") for row in artifacts]
    if artifact_ids != list(EXPECTED_DE_REQUIRED_ARTIFACT_COLUMNS):
        errors.append(f"{path}: required_artifacts order must be model-identity, answer-citation-raw-output, resource-evaluator-manifest")
    if len(artifact_ids) != len(set(artifact_ids)):
        errors.append(f"{path}: duplicate required_artifacts are forbidden")
    for index, row in enumerate(artifacts, start=1):
        prefix = f"{path}: required_artifact[{index}]"
        missing_artifact = REQUIRED_BASELINE_ARTIFACT_KEYS - set(row)
        if missing_artifact:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_artifact))}")
        if row.get("artifact_kind") != "csv":
            errors.append(f"{prefix}: artifact_kind must be csv")
        artifact_id = row.get("artifact_id", "")
        expected_columns = EXPECTED_DE_REQUIRED_ARTIFACT_COLUMNS.get(artifact_id)
        required_columns = row.get("required_columns", [])
        if not isinstance(required_columns, list) or not required_columns:
            errors.append(f"{prefix}: required_columns must be a non-empty list")
        elif expected_columns is not None and set(required_columns) != expected_columns:
            errors.append(f"{prefix}: required_columns must be exactly {', '.join(sorted(expected_columns))}")

    if measured_registry_ledger is not None:
        ledger_rows = read_csv_rows(measured_registry_ledger)
        ledger_by_system = {row.get("system_id", ""): row for row in ledger_rows}
        for system_id in ["D", "E"]:
            row = ledger_by_system.get(system_id)
            if row is None:
                errors.append(f"{measured_registry_ledger}: missing system_id={system_id}")
                continue
            if row.get("fixture_schema_test_allowed") != "1":
                errors.append(f"{measured_registry_ledger}: {system_id}.fixture_schema_test_allowed must be 1")
            if row.get("fixture_rows_in_measured_registry") != "0":
                errors.append(f"{measured_registry_ledger}: {system_id}.fixture_rows_in_measured_registry must be 0")
            if row.get("measured_registry_admission_ready") != "0":
                errors.append(f"{measured_registry_ledger}: {system_id}.measured_registry_admission_ready must be 0")
            if row.get("fixture_allowed") != "0":
                errors.append(f"{measured_registry_ledger}: {system_id}.fixture_allowed must be 0")
            if row.get("tests_only_merge_condition") != "0":
                errors.append(f"{measured_registry_ledger}: {system_id}.tests_only_merge_condition must be 0")
            ledger_fields = split_semicolon(row.get("required_real_evidence_fields", ""))
            missing_fields = split_semicolon(row.get("missing_real_evidence_fields", ""))
            if ledger_fields != REQUIRED_DE_REAL_EVIDENCE_FIELDS:
                errors.append(f"{measured_registry_ledger}: {system_id}.required_real_evidence_fields mismatch")
            if missing_fields != REQUIRED_DE_REAL_EVIDENCE_FIELDS:
                errors.append(f"{measured_registry_ledger}: {system_id}.missing_real_evidence_fields must list every required field while blocked")
            if row.get("raw_answer_citation_output_required") != "1":
                errors.append(f"{measured_registry_ledger}: {system_id}.raw_answer_citation_output_required must be 1")
            if row.get("answer_citation_raw_output_rows") != "0":
                errors.append(f"{measured_registry_ledger}: {system_id}.answer_citation_raw_output_rows must be 0 while blocked")
            if row.get("resource_row_required") != "1" or row.get("evaluator_version_required") != "1" or row.get("same_query_set_required") != "1":
                errors.append(f"{measured_registry_ledger}: {system_id}.resource/evaluator/same-query requirements must be 1")
            if row.get("status") != "blocked":
                errors.append(f"{measured_registry_ledger}: {system_id}.status must be blocked")

    if acceptance_ledger is not None:
        acceptance_rows = read_csv_rows(acceptance_ledger)
        by_system = {"D": [], "E": []}
        for row in acceptance_rows:
            system_id = row.get("system_id", "")
            if system_id in by_system:
                by_system[system_id].append(row)
        for system_id, rows in by_system.items():
            if len(rows) != 2:
                errors.append(f"{acceptance_ledger}: expected two acceptance rows for {system_id}")
            artifact_ids = {row.get("artifact_id", "") for row in rows}
            expected_artifacts = {f"{system_id.lower()}-model-identity", f"{system_id.lower()}-answer-citation-resource"}
            if artifact_ids != expected_artifacts:
                errors.append(f"{acceptance_ledger}: {system_id} artifact ids mismatch")
            for row in rows:
                if row.get("artifact_present") != "0":
                    errors.append(f"{acceptance_ledger}: {system_id}.{row.get('artifact_id')} artifact_present must be 0")
                if row.get("claim_boundary_status") != "pass":
                    errors.append(f"{acceptance_ledger}: {system_id}.{row.get('artifact_id')} claim_boundary_status must pass")
                if row.get("output_artifact_replay_status") != "blocked":
                    errors.append(f"{acceptance_ledger}: {system_id}.{row.get('artifact_id')} output_artifact_replay_status must be blocked")
                if row.get("blocker_false_positive_status") != "pass":
                    errors.append(f"{acceptance_ledger}: {system_id}.{row.get('artifact_id')} blocker_false_positive_status must pass")
                if row.get("approval_required") != "1" or row.get("fixture_allowed") != "0" or row.get("tests_only_merge_condition") != "0":
                    errors.append(f"{acceptance_ledger}: {system_id}.{row.get('artifact_id')} approval/fixture/tests-only policy mismatch")
                if row.get("acceptance_ready") != "0" or row.get("acceptance_status") != "blocked":
                    errors.append(f"{acceptance_ledger}: {system_id}.{row.get('artifact_id')} must remain blocked")
    return errors


def verify_v52_adapter_guard(
    path: Path,
    v52c_summary: Path | None = None,
    v52d_summary: Path | None = None,
    v52l_summary: Path | None = None,
    v52r_summary: Path | None = None,
    v52y_summary: Path | None = None,
) -> list[str]:
    errors: list[str] = []
    data = json.loads(path.read_text(encoding="utf-8"))
    missing = REQUIRED_V52_ADAPTER_GUARD_KEYS - set(data)
    if missing:
        errors.append(f"{path}: missing v52 adapter guard keys: {', '.join(sorted(missing))}")
        return errors
    if data["schema_version"] != "v52_adapter_guard.v1":
        errors.append(f"{path}: unsupported schema_version={data['schema_version']}")
    policy = data["policy"]
    if policy.get("c_7b14b_actual_adapter_packet_ready") is not True:
        errors.append(f"{path}: c_7b14b_actual_adapter_packet_ready must be true")
    for field in [
        "c_quality_claim_ready",
        "de_measured_registry_admission_ready",
        "public_comparison_claim_ready",
        "release_ready",
    ]:
        if policy.get(field) is not False:
            errors.append(f"{path}: {field} must be false")

    requirements = data["requirements"]
    if not isinstance(requirements, list) or not requirements:
        errors.append(f"{path}: requirements must be a non-empty list")
        return errors
    requirement_ids = [row.get("requirement_id", "") for row in requirements]
    if requirement_ids != EXPECTED_V52_REQUIREMENT_IDS:
        errors.append(f"{path}: requirement order must match the v52 adapter guard contract")
    if len(requirement_ids) != len(set(requirement_ids)):
        errors.append(f"{path}: duplicate requirement_id values are forbidden")

    summaries: dict[str, dict[str, str]] = {}
    if v52c_summary is not None:
        summaries["v52c"] = read_first_csv(v52c_summary)
    if v52d_summary is not None:
        summaries["v52d"] = read_first_csv(v52d_summary)
    if v52l_summary is not None:
        summaries["v52l"] = read_first_csv(v52l_summary)
    if v52r_summary is not None:
        summaries["v52r"] = read_first_csv(v52r_summary)
    if v52y_summary is not None:
        summaries["v52y"] = read_first_csv(v52y_summary)

    for index, row in enumerate(requirements, start=1):
        prefix = f"{path}: requirement[{index}]"
        missing_row = REQUIRED_V52_REQUIREMENT_KEYS - set(row)
        if missing_row:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_row))}")
        if row.get("current_status") != "pass":
            errors.append(f"{prefix}: current_status must be pass")
        if not row.get("required_evidence") or not row.get("evidence_path") or not row.get("claim_boundary"):
            errors.append(f"{prefix}: required_evidence, evidence_path, and claim_boundary must be non-empty")
        checks = row.get("summary_checks", [])
        if checks and not isinstance(checks, list):
            errors.append(f"{prefix}: summary_checks must be a list when present")
            continue
        for check in checks:
            summary_id = check.get("summary_id", "")
            summary = summaries.get(summary_id)
            if summary is None:
                continue
            field = check.get("field", "")
            expected = check.get("expected", "")
            if summary.get(field) != expected:
                errors.append(f"{prefix}: {summary_id}.{field} expected {expected}, got {summary.get(field)}")
    return errors


def verify_v50_auditor_correctness(
    path: Path,
    summary_path: Path | None = None,
    decision_path: Path | None = None,
) -> list[str]:
    errors: list[str] = []
    data = json.loads(path.read_text(encoding="utf-8"))
    missing = REQUIRED_V50_AUDITOR_KEYS - set(data)
    if missing:
        errors.append(f"{path}: missing v50 auditor keys: {', '.join(sorted(missing))}")
        return errors
    if data["schema_version"] != "v50_auditor_correctness.v1":
        errors.append(f"{path}: unsupported schema_version={data['schema_version']}")
    policy = data["policy"]
    if policy.get("summary_ready_claim_present") is not True:
        errors.append(f"{path}: summary_ready_claim_present must be true while the v50 summary has ready=1")
    if policy.get("artifact_replay_ready") is not False:
        errors.append(f"{path}: artifact_replay_ready must remain false until required artifacts exist")
    if policy.get("auditor_correctness_merge_ready") is not False:
        errors.append(f"{path}: auditor_correctness_merge_ready must remain false")
    if policy.get("implicit_public_refresh_allowed") is not False:
        errors.append(f"{path}: implicit_public_refresh_allowed must be false")
    if policy.get("network_required_to_regenerate") is not True:
        errors.append(f"{path}: network_required_to_regenerate must be true for the current v50 runner")

    artifacts = data["required_artifacts"]
    if not isinstance(artifacts, list) or not artifacts:
        errors.append(f"{path}: required_artifacts must be a non-empty list")
        return errors
    artifact_ids = [row.get("artifact_id", "") for row in artifacts]
    if artifact_ids != EXPECTED_V50_ARTIFACT_IDS:
        errors.append(f"{path}: required_artifacts order must match the v50 correctness contract")
    if len(artifact_ids) != len(set(artifact_ids)):
        errors.append(f"{path}: duplicate artifact_id values are forbidden")
    missing_required_artifacts = []
    for index, row in enumerate(artifacts, start=1):
        prefix = f"{path}: required_artifact[{index}]"
        missing_row = REQUIRED_V50_ARTIFACT_KEYS - set(row)
        if missing_row:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_row))}")
        if row.get("required_for_merge") is not True:
            errors.append(f"{prefix}: required_for_merge must be true")
        artifact_path = Path(row.get("path", ""))
        if not artifact_path.is_file() or artifact_path.stat().st_size == 0:
            missing_required_artifacts.append(row.get("artifact_id", ""))
    if not missing_required_artifacts:
        errors.append(f"{path}: contract says artifact_replay_ready=false, but all required artifacts are present; update the contract")

    boundaries = data["claim_boundaries"]
    if not isinstance(boundaries, list) or not boundaries:
        errors.append(f"{path}: claim_boundaries must be a non-empty list")
        return errors
    boundary_ids = [row.get("claim_id", "") for row in boundaries]
    if len(boundary_ids) != len(set(boundary_ids)):
        errors.append(f"{path}: duplicate claim_id values are forbidden")
    for index, row in enumerate(boundaries, start=1):
        prefix = f"{path}: claim_boundary[{index}]"
        missing_boundary = REQUIRED_V50_BOUNDARY_KEYS - set(row)
        if missing_boundary:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_boundary))}")
        if not row.get("allowed") or not row.get("blocked"):
            errors.append(f"{prefix}: allowed and blocked must be non-empty")

    if summary_path is not None:
        summary = read_first_csv(summary_path)
        expected_summary = {
            "v50_public_repo_auditor_3repo_ready": "1",
            "repo_count": "3",
            "repo_refs_pinned": "1",
            "audit_case_rows": "9",
            "audit_type_count": "3",
            "guard_negative_rows": "3",
            "guard_negative_block_rows": "3",
            "source_span_rows": "18",
            "wrong_answer_guard_pass_rows": "9",
            "citation_accuracy_pass_rows": "9",
            "audit_trail_bound_rows": "9",
            "human_review_completed": "0",
            "real_release_package_ready": "0",
        }
        for field, expected in expected_summary.items():
            if summary.get(field) != expected:
                errors.append(f"{summary_path}: {field} expected {expected}, got {summary.get(field)}")
    if decision_path is not None:
        decision_rows = read_csv_rows(decision_path)
        by_gate = {row.get("gate", ""): row for row in decision_rows}
        for gate in EXPECTED_V50_DECISION_GATES:
            row = by_gate.get(gate)
            if row is None:
                errors.append(f"{decision_path}: missing gate={gate}")
                continue
            if row.get("status") != "pass":
                errors.append(f"{decision_path}: {gate}.status expected pass, got {row.get('status')}")
        release = by_gate.get("real-release-package")
        if release is None:
            errors.append(f"{decision_path}: missing gate=real-release-package")
        elif release.get("status") != "blocked":
            errors.append(f"{decision_path}: real-release-package.status expected blocked, got {release.get('status')}")
    return errors


def verify_v53_source_benchmark(
    path: Path,
    v53i_summary: Path | None = None,
    v53t_summary: Path | None = None,
    v53ap_summary: Path | None = None,
    v53aq_summary: Path | None = None,
    v1_exit_ledger: Path | None = None,
) -> list[str]:
    errors: list[str] = []
    data = json.loads(path.read_text(encoding="utf-8"))
    missing = REQUIRED_V53_SOURCE_BENCHMARK_KEYS - set(data)
    if missing:
        errors.append(f"{path}: missing v53 benchmark keys: {', '.join(sorted(missing))}")
        return errors
    if data["schema_version"] != "v53_source_benchmark.v1":
        errors.append(f"{path}: unsupported schema_version={data['schema_version']}")
    policy = data["policy"]
    if policy.get("benchmark_id") != "v53i_complete_source_1000":
        errors.append(f"{path}: policy.benchmark_id must be v53i_complete_source_1000")
    if policy.get("machine_foundation_freeze_ready") is not True:
        errors.append(f"{path}: machine_foundation_freeze_ready must be true for the current freeze")
    if policy.get("human_review_ready") is not False:
        errors.append(f"{path}: human_review_ready must remain false")
    if policy.get("public_comparison_claim_ready") is not False:
        errors.append(f"{path}: public_comparison_claim_ready must remain false")
    if policy.get("release_ready") is not False:
        errors.append(f"{path}: release_ready must remain false")

    requirements = data["requirements"]
    if not isinstance(requirements, list) or not requirements:
        errors.append(f"{path}: requirements must be a non-empty list")
        return errors
    requirement_ids = [row.get("requirement_id", "") for row in requirements]
    if requirement_ids != EXPECTED_V53_REQUIREMENT_IDS:
        errors.append(f"{path}: requirement order must match the v53 source-bound freeze contract")
    if len(requirement_ids) != len(set(requirement_ids)):
        errors.append(f"{path}: duplicate requirement_id values are forbidden")

    summaries: dict[str, dict[str, str]] = {}
    if v53i_summary is not None:
        summaries["v53i"] = read_first_csv(v53i_summary)
    if v53t_summary is not None:
        summaries["v53t"] = read_first_csv(v53t_summary)
    if v53ap_summary is not None:
        summaries["v53ap"] = read_first_csv(v53ap_summary)
    if v53aq_summary is not None:
        summaries["v53aq"] = read_first_csv(v53aq_summary)

    for index, row in enumerate(requirements, start=1):
        prefix = f"{path}: requirement[{index}]"
        missing_row = REQUIRED_V53_REQUIREMENT_KEYS - set(row)
        if missing_row:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_row))}")
        if row.get("current_status") != "pass":
            errors.append(f"{prefix}: current_status must be pass for the machine foundation freeze")
        if not row.get("required_evidence") or not row.get("evidence_path") or not row.get("claim_boundary"):
            errors.append(f"{prefix}: required_evidence, evidence_path, and claim_boundary must be non-empty")
        checks = row.get("summary_checks", [])
        if checks and not isinstance(checks, list):
            errors.append(f"{prefix}: summary_checks must be a list when present")
            continue
        for check in checks:
            summary_id = check.get("summary_id", "")
            summary = summaries.get(summary_id)
            if summary is None:
                continue
            field = check.get("field", "")
            expected = check.get("expected", "")
            if summary.get(field) != expected:
                errors.append(f"{prefix}: {summary_id}.{field} expected {expected}, got {summary.get(field)}")

    if v1_exit_ledger is not None:
        ledger_rows = read_csv_rows(v1_exit_ledger)
        ledger_by_criterion = {row.get("criterion_id", ""): row for row in ledger_rows}
        if list(ledger_by_criterion) != EXPECTED_V53_V1_EXIT_CRITERION_IDS:
            errors.append(f"{v1_exit_ledger}: criterion order must match the v53 v1 exit criteria contract")
        for criterion_id in EXPECTED_V53_V1_EXIT_CRITERION_IDS:
            row = ledger_by_criterion.get(criterion_id)
            if row is None:
                errors.append(f"{v1_exit_ledger}: missing criterion_id={criterion_id}")
                continue
            if row.get("status") != "pass":
                errors.append(f"{v1_exit_ledger}: {criterion_id}.status must be pass")
            if row.get("claim_boundary_status") != "pass":
                errors.append(f"{v1_exit_ledger}: {criterion_id}.claim_boundary_status must be pass")
            if row.get("replay_artifact_status") != "pass":
                errors.append(f"{v1_exit_ledger}: {criterion_id}.replay_artifact_status must be pass")
            if row.get("blocker_false_positive_status") != "pass":
                errors.append(f"{v1_exit_ledger}: {criterion_id}.blocker_false_positive_status must be pass")
            if row.get("tests_only_merge_condition") != "0":
                errors.append(f"{v1_exit_ledger}: {criterion_id}.tests_only_merge_condition must be 0")
            if not row.get("evidence_sha256", "").startswith("sha256:"):
                errors.append(f"{v1_exit_ledger}: {criterion_id}.evidence_sha256 must be sha256-bound")
    return errors


def verify_v58_blind_eval(
    path: Path,
    readiness_ledger: Path | None = None,
    artifact_ledger: Path | None = None,
    template_ledger: Path | None = None,
) -> list[str]:
    errors: list[str] = []
    data = json.loads(path.read_text(encoding="utf-8"))
    missing = REQUIRED_V58_BLIND_EVAL_KEYS - set(data)
    if missing:
        errors.append(f"{path}: missing v58 blind-eval keys: {', '.join(sorted(missing))}")
        return errors
    if data["schema_version"] != "v58_blind_eval.v1":
        errors.append(f"{path}: unsupported schema_version={data['schema_version']}")
    policy = data["policy"]
    if policy.get("fixture_allowed") is not False:
        errors.append(f"{path}: policy.fixture_allowed must be false")
    if policy.get("tests_only_merge_condition") is not False:
        errors.append(f"{path}: policy.tests_only_merge_condition must be false")
    if policy.get("real_execution_ready") is not False:
        errors.append(f"{path}: policy.real_execution_ready must be false until real blind evidence is supplied")
    if set(data.get("required_systems", [])) != {"A", "B", "C", "D", "E", "G", "H"}:
        errors.append(f"{path}: required_systems must be A/B/C/D/E/G/H")

    requirements = data["requirements"]
    requirement_ids = [row.get("requirement_id", "") for row in requirements]
    if requirement_ids != EXPECTED_V58_REQUIREMENT_IDS:
        errors.append(f"{path}: requirement order must match the v58 real-execution contract")
    if len(requirement_ids) != len(set(requirement_ids)):
        errors.append(f"{path}: duplicate requirement_id values are forbidden")
    for index, row in enumerate(requirements, start=1):
        prefix = f"{path}: requirement[{index}]"
        missing_row = REQUIRED_V58_REQUIREMENT_KEYS - set(row)
        if missing_row:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_row))}")
        if not row.get("required_evidence"):
            errors.append(f"{prefix}: required_evidence must be non-empty")

    artifacts = data["required_artifacts"]
    artifact_ids = [row.get("artifact_id", "") for row in artifacts]
    if artifact_ids != EXPECTED_V58_ARTIFACT_IDS:
        errors.append(f"{path}: required_artifacts order must match the v58 artifact contract")
    if len(artifact_ids) != len(set(artifact_ids)):
        errors.append(f"{path}: duplicate artifact_id values are forbidden")
    for index, row in enumerate(artifacts, start=1):
        prefix = f"{path}: required_artifact[{index}]"
        missing_row = REQUIRED_V58_ARTIFACT_KEYS - set(row)
        if missing_row:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_row))}")
        if not row.get("artifact_kind") or not row.get("validation_command"):
            errors.append(f"{prefix}: artifact_kind and validation_command must be non-empty")
        artifact_id = row.get("artifact_id", "")
        required_columns = row.get("required_columns", [])
        if not isinstance(required_columns, list) or not required_columns:
            errors.append(f"{prefix}: required_columns must be a non-empty list")
        else:
            column_set = set(required_columns)
            expected_columns = EXPECTED_V58_ARTIFACT_COLUMNS.get(artifact_id)
            if expected_columns is not None and column_set != expected_columns:
                errors.append(f"{prefix}: required_columns must be exactly {', '.join(sorted(expected_columns))}")
            if artifact_id in {"v58-human-review-rows", "v58-adjudication-rows"}:
                leaked_resource_columns = column_set & V58_REVIEW_FORBIDDEN_RESOURCE_COLUMNS
                if leaked_resource_columns:
                    errors.append(f"{prefix}: human review/adjudication rows must not include resource columns: {', '.join(sorted(leaked_resource_columns))}")
        if artifact_id in {"v58-blind-response-rows", "v58-run-identity-rows", "v58-query-split-rows", "v58-resource-rows", "v58-sha256-manifest"}:
            if "test_v58c_blind_response_evidence_intake.sh" not in row.get("validation_command", ""):
                errors.append(f"{prefix}: response artifacts must validate through v58c intake")

    if readiness_ledger is not None:
        ledger_rows = read_csv_rows(readiness_ledger)
        by_requirement = {row.get("requirement_id", ""): row for row in ledger_rows}
        for requirement_id in EXPECTED_V58_REQUIREMENT_IDS:
            row = by_requirement.get(requirement_id)
            if row is None:
                errors.append(f"{readiness_ledger}: missing requirement_id={requirement_id}")
                continue
            if row.get("required_for_v58_real_execution") != "1":
                errors.append(f"{readiness_ledger}: {requirement_id}.required_for_v58_real_execution must be 1")
            if row.get("contract_ready") != "1":
                errors.append(f"{readiness_ledger}: {requirement_id}.contract_ready must be 1")
            if row.get("real_execution_ready") != "0":
                errors.append(f"{readiness_ledger}: {requirement_id}.real_execution_ready must be 0 while blocked")
            if row.get("fixture_allowed") != "0":
                errors.append(f"{readiness_ledger}: {requirement_id}.fixture_allowed must be 0")
            if row.get("tests_only_merge_condition") != "0":
                errors.append(f"{readiness_ledger}: {requirement_id}.tests_only_merge_condition must be 0")
            if row.get("status") != "blocked":
                errors.append(f"{readiness_ledger}: {requirement_id}.status must be blocked")

    if artifact_ledger is not None:
        artifact_rows = read_csv_rows(artifact_ledger)
        by_artifact = {
            row.get("artifact_id", ""): row
            for row in artifact_rows
            if row.get("blocker_class") == "v58-real-blind-eval-missing"
        }
        for artifact_id in EXPECTED_V58_ARTIFACT_IDS:
            row = by_artifact.get(artifact_id)
            if row is None:
                errors.append(f"{artifact_ledger}: missing artifact_id={artifact_id}")
                continue
            if row.get("fixture_allowed") != "0" or row.get("approval_required") != "1":
                errors.append(f"{artifact_ledger}: {artifact_id}.fixture_allowed must be 0 and approval_required must be 1")
            if not row.get("validation_command") or not row.get("required_shape"):
                errors.append(f"{artifact_ledger}: {artifact_id}.validation_command and required_shape must be non-empty")

    if template_ledger is not None:
        template_rows = read_csv_rows(template_ledger)
        by_template = {
            row.get("artifact_id", ""): row
            for row in template_rows
            if row.get("blocker_class") == "v58-real-blind-eval-missing"
        }
        for artifact_id in EXPECTED_V58_ARTIFACT_IDS:
            row = by_template.get(artifact_id)
            if row is None:
                errors.append(f"{template_ledger}: missing artifact_id={artifact_id}")
                continue
            if row.get("fixture_allowed") != "0" or row.get("approval_required") != "1":
                errors.append(f"{template_ledger}: {artifact_id}.fixture_allowed must be 0 and approval_required must be 1")
            if row.get("template_ready") != "1":
                errors.append(f"{template_ledger}: {artifact_id}.template_ready must be 1")
            if not row.get("template_sha256", "").startswith("sha256:"):
                errors.append(f"{template_ledger}: {artifact_id}.template_sha256 must be sha256-bound")
    return errors


def verify_review_return_workflow(
    path: Path,
    v53s_summary: Path | None = None,
    v58d_summary: Path | None = None,
    v61af_summary: Path | None = None,
    v61hv_summary: Path | None = None,
) -> list[str]:
    errors: list[str] = []
    data = json.loads(path.read_text(encoding="utf-8"))
    missing = REQUIRED_REVIEW_RETURN_WORKFLOW_KEYS - set(data)
    if missing:
        errors.append(f"{path}: missing review-return workflow keys: {', '.join(sorted(missing))}")
        return errors
    if data["schema_version"] != "review_return_workflow.v1":
        errors.append(f"{path}: unsupported schema_version={data['schema_version']}")
    policy = data["policy"]
    if policy.get("workflow_contract_ready") is not True:
        errors.append(f"{path}: workflow_contract_ready must be true")
    for field in [
        "human_review_ready",
        "adjudication_ready",
        "operator_input_files_ready",
        "actual_generation_ready",
        "release_ready",
        "fixture_can_close_real_return",
    ]:
        if policy.get(field) is not False:
            errors.append(f"{path}: {field} must be false")

    requirements = data["requirements"]
    if not isinstance(requirements, list) or not requirements:
        errors.append(f"{path}: requirements must be a non-empty list")
        return errors
    requirement_ids = [row.get("requirement_id", "") for row in requirements]
    if requirement_ids != EXPECTED_REVIEW_RETURN_REQUIREMENT_IDS:
        errors.append(f"{path}: requirement order must match the review-return workflow contract")
    if len(requirement_ids) != len(set(requirement_ids)):
        errors.append(f"{path}: duplicate requirement_id values are forbidden")

    summaries: dict[str, dict[str, str]] = {}
    if v53s_summary is not None:
        summaries["v53s"] = read_first_csv(v53s_summary)
    if v58d_summary is not None:
        summaries["v58d"] = read_first_csv(v58d_summary)
    if v61af_summary is not None:
        summaries["v61af"] = read_first_csv(v61af_summary)
    if v61hv_summary is not None:
        summaries["v61hv"] = read_first_csv(v61hv_summary)

    for index, row in enumerate(requirements, start=1):
        prefix = f"{path}: requirement[{index}]"
        missing_row = REQUIRED_REVIEW_RETURN_REQUIREMENT_KEYS - set(row)
        if missing_row:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_row))}")
        if row.get("current_status") != "pass":
            errors.append(f"{prefix}: current_status must be pass")
        if not row.get("required_evidence") or not row.get("evidence_path") or not row.get("claim_boundary"):
            errors.append(f"{prefix}: required_evidence, evidence_path, and claim_boundary must be non-empty")
        checks = row.get("summary_checks", [])
        if checks and not isinstance(checks, list):
            errors.append(f"{prefix}: summary_checks must be a list when present")
            continue
        for check in checks:
            summary_id = check.get("summary_id", "")
            summary = summaries.get(summary_id)
            if summary is None:
                continue
            field = check.get("field", "")
            expected = check.get("expected", "")
            if summary.get(field) != expected:
                errors.append(f"{prefix}: {summary_id}.{field} expected {expected}, got {summary.get(field)}")
    return errors


def verify_v61_one_token_path(
    path: Path,
    v61aa_summary: Path | None = None,
    v61ab_summary: Path | None = None,
) -> list[str]:
    errors: list[str] = []
    data = json.loads(path.read_text(encoding="utf-8"))
    missing = REQUIRED_V61_ONE_TOKEN_KEYS - set(data)
    if missing:
        errors.append(f"{path}: missing v61 one-token keys: {', '.join(sorted(missing))}")
        return errors
    if data["schema_version"] != "v61_one_token_path.v1":
        errors.append(f"{path}: unsupported schema_version={data['schema_version']}")
    policy = data["policy"]
    if policy.get("ssd_resident_real_model_runtime_claim_ready") is not False:
        errors.append(f"{path}: SSD-resident real model runtime claim must stay false until milestones 1-6 pass")
    if policy.get("real_model_execution_ready") is not False:
        errors.append(f"{path}: real_model_execution_ready must stay false until one-token evidence exists")
    if policy.get("release_ready") is not False:
        errors.append(f"{path}: release_ready must stay false")
    if policy.get("required_before_ssd_resident_runtime_claim") != V61_REQUIRED_BEFORE_RUNTIME_CLAIM:
        errors.append(f"{path}: required_before_ssd_resident_runtime_claim must be milestones 1-6")

    milestones = data["milestones"]
    if not isinstance(milestones, list) or not milestones:
        errors.append(f"{path}: milestones must be a non-empty list")
        return errors
    milestone_ids = [row.get("milestone_id", "") for row in milestones]
    if milestone_ids != EXPECTED_V61_MILESTONE_IDS:
        errors.append(f"{path}: milestone order must match the one-token runtime path")
    if len(milestone_ids) != len(set(milestone_ids)):
        errors.append(f"{path}: duplicate milestone_id values are forbidden")

    summaries: dict[str, dict[str, str]] = {}
    if v61aa_summary is not None:
        summaries["v61aa"] = read_first_csv(v61aa_summary)
    if v61ab_summary is not None:
        summaries["v61ab"] = read_first_csv(v61ab_summary)

    for index, row in enumerate(milestones, start=1):
        prefix = f"{path}: milestone[{index}]"
        missing_row = REQUIRED_V61_MILESTONE_KEYS - set(row)
        if missing_row:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_row))}")
        milestone_id = row.get("milestone_id", "")
        if row.get("order") != index:
            errors.append(f"{prefix}: order must be {index}")
        if not row.get("required_evidence") or not row.get("evidence_path") or not row.get("claim_boundary"):
            errors.append(f"{prefix}: required_evidence, evidence_path, and claim_boundary must be non-empty")
        expected_status = EXPECTED_V61_CURRENT_STATUS.get(milestone_id)
        if expected_status is not None and row.get("current_status") != expected_status:
            errors.append(f"{prefix}: current_status expected {expected_status}, got {row.get('current_status')}")
        if row.get("current_status") not in {"pass", "blocked"}:
            errors.append(f"{prefix}: current_status must be pass or blocked")
        if row.get("current_status") == "blocked":
            blockers = row.get("blocked_by", [])
            if not isinstance(blockers, list) or not blockers:
                errors.append(f"{prefix}: blocked milestones must list blocked_by")
        checks = row.get("summary_checks", [])
        if checks and not isinstance(checks, list):
            errors.append(f"{prefix}: summary_checks must be a list when present")
            continue
        for check in checks:
            summary_id = check.get("summary_id", "")
            summary = summaries.get(summary_id)
            if summary is None:
                continue
            field = check.get("field", "")
            expected = check.get("expected", "")
            if summary.get(field) != expected:
                errors.append(f"{prefix}: {summary_id}.{field} expected {expected}, got {summary.get(field)}")

    artifacts = data["required_artifacts"]
    artifact_ids = [row.get("artifact_id", "") for row in artifacts]
    if artifact_ids != list(EXPECTED_V61_REQUIRED_ARTIFACT_COLUMNS):
        errors.append(f"{path}: required_artifacts order must be expert FFN, MoE block, one-token logits")
    if len(artifact_ids) != len(set(artifact_ids)):
        errors.append(f"{path}: duplicate required_artifacts are forbidden")
    for index, row in enumerate(artifacts, start=1):
        prefix = f"{path}: required_artifact[{index}]"
        missing_artifact = REQUIRED_V61_ARTIFACT_KEYS - set(row)
        if missing_artifact:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_artifact))}")
        if row.get("artifact_kind") != "csv":
            errors.append(f"{prefix}: artifact_kind must be csv")
        artifact_id = row.get("artifact_id", "")
        required_columns = row.get("required_columns", [])
        expected_columns = EXPECTED_V61_REQUIRED_ARTIFACT_COLUMNS.get(artifact_id)
        if not isinstance(required_columns, list) or not required_columns:
            errors.append(f"{prefix}: required_columns must be a non-empty list")
        elif expected_columns is not None and set(required_columns) != expected_columns:
            errors.append(f"{prefix}: required_columns must be exactly {', '.join(sorted(expected_columns))}")
    return errors


def verify_manifest(path: Path, root: Path) -> list[str]:
    errors: list[str] = []
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    for line_no, row in enumerate(rows, start=2):
        rel = row.get("path", "")
        expected = row.get("sha256", "")
        if not rel or not expected:
            errors.append(f"{path}:{line_no}: path and sha256 are required")
            continue
        artifact = root / rel
        if not artifact.is_file():
            errors.append(f"{path}:{line_no}: missing artifact {rel}")
            continue
        actual = sha256(artifact)
        if actual != expected:
            errors.append(f"{path}:{line_no}: sha mismatch for {rel}: expected {expected}, got {actual}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    p_pipeline = sub.add_parser("pipeline")
    p_pipeline.add_argument("paths", nargs="+", type=Path)
    p_pr_split = sub.add_parser("pr-split")
    p_pr_split.add_argument("paths", nargs="+", type=Path)
    p_typed = sub.add_parser("typed-readiness")
    p_typed.add_argument("paths", nargs="+", type=Path)
    p_typed.add_argument("--pm-ledger", type=Path, default=None)
    p_leakage = sub.add_parser("leakage")
    p_leakage.add_argument("paths", nargs="+", type=Path)
    p_leakage.add_argument("--pm-ledger", type=Path, default=None)
    p_baseline = sub.add_parser("baseline-admission")
    p_baseline.add_argument("paths", nargs="+", type=Path)
    p_baseline.add_argument("--measured-registry-ledger", type=Path, default=None)
    p_baseline.add_argument("--acceptance-ledger", type=Path, default=None)
    p_v52 = sub.add_parser("v52-adapter-guard")
    p_v52.add_argument("paths", nargs="+", type=Path)
    p_v52.add_argument("--v52c-summary", type=Path, default=None)
    p_v52.add_argument("--v52d-summary", type=Path, default=None)
    p_v52.add_argument("--v52l-summary", type=Path, default=None)
    p_v52.add_argument("--v52r-summary", type=Path, default=None)
    p_v52.add_argument("--v52y-summary", type=Path, default=None)
    p_v50 = sub.add_parser("v50-auditor-correctness")
    p_v50.add_argument("paths", nargs="+", type=Path)
    p_v50.add_argument("--summary", type=Path, default=None)
    p_v50.add_argument("--decision", type=Path, default=None)
    p_v53 = sub.add_parser("v53-source-benchmark")
    p_v53.add_argument("paths", nargs="+", type=Path)
    p_v53.add_argument("--v53i-summary", type=Path, default=None)
    p_v53.add_argument("--v53t-summary", type=Path, default=None)
    p_v53.add_argument("--v53ap-summary", type=Path, default=None)
    p_v53.add_argument("--v53aq-summary", type=Path, default=None)
    p_v53.add_argument("--v1-exit-ledger", type=Path, default=None)
    p_v58 = sub.add_parser("v58-blind-eval")
    p_v58.add_argument("paths", nargs="+", type=Path)
    p_v58.add_argument("--readiness-ledger", type=Path, default=None)
    p_v58.add_argument("--artifact-ledger", type=Path, default=None)
    p_v58.add_argument("--template-ledger", type=Path, default=None)
    p_review = sub.add_parser("review-return-workflow")
    p_review.add_argument("paths", nargs="+", type=Path)
    p_review.add_argument("--v53s-summary", type=Path, default=None)
    p_review.add_argument("--v58d-summary", type=Path, default=None)
    p_review.add_argument("--v61af-summary", type=Path, default=None)
    p_review.add_argument("--v61hv-summary", type=Path, default=None)
    p_v61 = sub.add_parser("v61-one-token")
    p_v61.add_argument("paths", nargs="+", type=Path)
    p_v61.add_argument("--v61aa-summary", type=Path, default=None)
    p_v61.add_argument("--v61ab-summary", type=Path, default=None)
    p_manifest = sub.add_parser("manifest")
    p_manifest.add_argument("manifest", type=Path)
    p_manifest.add_argument("--root", type=Path, default=None)
    args = parser.parse_args()

    errors: list[str] = []
    if args.cmd == "pipeline":
        for path in args.paths:
            errors.extend(verify_pipeline(path))
    elif args.cmd == "pr-split":
        for path in args.paths:
            errors.extend(verify_pr_split(path))
    elif args.cmd == "typed-readiness":
        for path in args.paths:
            errors.extend(verify_typed_readiness(path, args.pm_ledger))
    elif args.cmd == "leakage":
        for path in args.paths:
            errors.extend(verify_leakage(path, args.pm_ledger))
    elif args.cmd == "baseline-admission":
        for path in args.paths:
            errors.extend(verify_baseline_admission(path, args.measured_registry_ledger, args.acceptance_ledger))
    elif args.cmd == "v52-adapter-guard":
        for path in args.paths:
            errors.extend(
                verify_v52_adapter_guard(
                    path,
                    args.v52c_summary,
                    args.v52d_summary,
                    args.v52l_summary,
                    args.v52r_summary,
                    args.v52y_summary,
                )
            )
    elif args.cmd == "v50-auditor-correctness":
        for path in args.paths:
            errors.extend(verify_v50_auditor_correctness(path, args.summary, args.decision))
    elif args.cmd == "v53-source-benchmark":
        for path in args.paths:
            errors.extend(
                verify_v53_source_benchmark(
                    path,
                    args.v53i_summary,
                    args.v53t_summary,
                    args.v53ap_summary,
                    args.v53aq_summary,
                    args.v1_exit_ledger,
                )
            )
    elif args.cmd == "v58-blind-eval":
        for path in args.paths:
            errors.extend(verify_v58_blind_eval(path, args.readiness_ledger, args.artifact_ledger, args.template_ledger))
    elif args.cmd == "review-return-workflow":
        for path in args.paths:
            errors.extend(
                verify_review_return_workflow(
                    path,
                    args.v53s_summary,
                    args.v58d_summary,
                    args.v61af_summary,
                    args.v61hv_summary,
                )
            )
    elif args.cmd == "v61-one-token":
        for path in args.paths:
            errors.extend(verify_v61_one_token_path(path, args.v61aa_summary, args.v61ab_summary))
    elif args.cmd == "manifest":
        root = args.root if args.root is not None else args.manifest.parent
        errors.extend(verify_manifest(args.manifest, root))
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("verify ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
