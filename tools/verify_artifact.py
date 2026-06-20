#!/usr/bin/env python3
"""Verify small pipeline and artifact manifests without external dependencies."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCHEMA_ROOT = REPO_ROOT / "schemas"


def schema_required(schema_name: str) -> set[str]:
    schema_path = SCHEMA_ROOT / schema_name
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    return set(schema.get("required", []))


def schema_required_at(schema_name: str, *path_parts: str) -> set[str]:
    schema_path = SCHEMA_ROOT / schema_name
    node: object = json.loads(schema_path.read_text(encoding="utf-8"))
    for part in path_parts:
        if not isinstance(node, dict):
            return set()
        node = node.get(part, {})
    if not isinstance(node, dict):
        return set()
    required = node.get("required", [])
    if not isinstance(required, list):
        return set()
    return set(str(field) for field in required)


def schema_enum_at(schema_name: str, *path_parts: str) -> list[str]:
    schema_path = SCHEMA_ROOT / schema_name
    node: object = json.loads(schema_path.read_text(encoding="utf-8"))
    for part in path_parts:
        if not isinstance(node, dict):
            return []
        node = node.get(part, {})
    if not isinstance(node, dict):
        return []
    enum_values = node.get("enum", [])
    if not isinstance(enum_values, list):
        return []
    return [str(value) for value in enum_values]


def schema_contract(schema_name: str) -> dict[str, object]:
    schema_path = SCHEMA_ROOT / schema_name
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    contract = schema.get("x-contract", {})
    if not isinstance(contract, dict):
        return {}
    return contract


REQUIRED_PIPELINE_KEYS = schema_required("pipeline.schema.json")
REQUIRED_STAGE_KEYS = schema_required_at("pipeline.schema.json", "properties", "stages", "items")
REQUIRED_PR_SPLIT_KEYS = schema_required("pr_split.schema.json")
REQUIRED_PR_SLICE_KEYS = schema_required_at("pr_split.schema.json", "properties", "slices", "items")
REQUIRED_TYPED_READINESS_KEYS = schema_required("typed_readiness.schema.json")
REQUIRED_TYPED_READINESS_ROW_KEYS = schema_required_at("typed_readiness.schema.json", "properties", "rows", "items")
REQUIRED_LEAKAGE_KEYS = schema_required("leakage_contract.schema.json")
REQUIRED_LEAKAGE_POLICY_KEYS = schema_required_at("leakage_contract.schema.json", "properties", "policy")
REQUIRED_LEAKAGE_SURFACE_KEYS = schema_required_at("leakage_contract.schema.json", "properties", "forbidden_surfaces", "items")
REQUIRED_LEAKAGE_STAGE_KEYS = schema_required_at("leakage_contract.schema.json", "properties", "stage_contracts", "items")
OPTIONAL_LEAKAGE_STAGE_KEYS = {
    "forbidden_field_summary",
}
REQUIRED_BASELINE_ADMISSION_KEYS = schema_required("baseline_admission.schema.json")
REQUIRED_BASELINE_LEDGER_KEYS = schema_required_at("baseline_admission.schema.json", "properties", "required_pm_ledgers", "items")
REQUIRED_BASELINE_SYSTEM_KEYS = schema_required_at("baseline_admission.schema.json", "properties", "systems", "items")
REQUIRED_BASELINE_ARTIFACT_KEYS = schema_required_at("baseline_admission.schema.json", "properties", "required_artifacts", "items")
REQUIRED_V52_ADAPTER_GUARD_KEYS = schema_required("v52_adapter_guard.schema.json")
REQUIRED_V52_ARTIFACT_KEYS = schema_required_at("v52_adapter_guard.schema.json", "properties", "required_artifacts", "items")
REQUIRED_V52_REQUIREMENT_KEYS = schema_required_at("v52_adapter_guard.schema.json", "properties", "requirements", "items")
REQUIRED_V50_AUDITOR_KEYS = schema_required("v50_auditor_correctness.schema.json")
REQUIRED_V50_POLICY_KEYS = schema_required_at("v50_auditor_correctness.schema.json", "properties", "policy")
REQUIRED_V50_ARTIFACT_KEYS = schema_required_at("v50_auditor_correctness.schema.json", "properties", "required_artifacts", "items")
REQUIRED_V50_REPLAY_COMMAND_KEYS = schema_required_at("v50_auditor_correctness.schema.json", "properties", "replay_commands")
REQUIRED_V50_BOUNDARY_KEYS = schema_required_at("v50_auditor_correctness.schema.json", "properties", "claim_boundaries", "items")
REQUIRED_V56_REPLAY_KEYS = schema_required("v56_replay.schema.json")
REQUIRED_V56_REPLAY_POLICY_KEYS = schema_required_at("v56_replay.schema.json", "properties", "policy")
REQUIRED_V56_REPLAY_ARTIFACT_KEYS = schema_required_at("v56_replay.schema.json", "properties", "replay_artifacts", "items")
REQUIRED_V56_SEED_DEPENDENCY_KEYS = schema_required_at("v56_replay.schema.json", "properties", "seed_dependency")
REQUIRED_V53_SOURCE_BENCHMARK_KEYS = schema_required("v53_source_benchmark.schema.json")
REQUIRED_V54_GROUNDED_GENERATION_KEYS = schema_required("v54_grounded_generation.schema.json")
REQUIRED_V54_ARTIFACT_KEYS = schema_required_at("v54_grounded_generation.schema.json", "properties", "required_artifacts", "items")
REQUIRED_V53_REQUIREMENT_KEYS = schema_required_at("v53_source_benchmark.schema.json", "properties", "requirements", "items")
REQUIRED_V58_BLIND_EVAL_KEYS = schema_required("v58_blind_eval.schema.json")
REQUIRED_V58_REQUIREMENT_KEYS = schema_required_at("v58_blind_eval.schema.json", "properties", "requirements", "items")
REQUIRED_V58_ARTIFACT_KEYS = schema_required_at("v58_blind_eval.schema.json", "properties", "required_artifacts", "items")
OPTIONAL_V58_ARTIFACT_KEYS = {
    "per_system_min_rows",
}
REQUIRED_REVIEW_RETURN_WORKFLOW_KEYS = schema_required("review_return_workflow.schema.json")
REQUIRED_REVIEW_RETURN_REQUIREMENT_KEYS = schema_required_at("review_return_workflow.schema.json", "properties", "requirements", "items")
REQUIRED_V61_ONE_TOKEN_KEYS = schema_required("v61_one_token_path.schema.json")
REQUIRED_V61_POLICY_KEYS = schema_required_at("v61_one_token_path.schema.json", "properties", "policy")
REQUIRED_V61_MILESTONE_KEYS = schema_required_at("v61_one_token_path.schema.json", "properties", "milestones", "items")
REQUIRED_V61_ARTIFACT_KEYS = schema_required_at("v61_one_token_path.schema.json", "properties", "required_artifacts", "items")
EXPECTED_PR2_SLICE_ORDER = schema_enum_at("pr_split.schema.json", "properties", "slices", "items", "properties", "slice_id")
REQUIRED_PR_MERGE_GATES = {
    "claim-boundary",
    "replay-artifact",
    "blocker-false-positive",
}
REQUIRED_PR2_REWRITE_TERMS = {
    "not mergeable as one unit",
    "v50 artifact schema",
    "sha256 manifest",
    "typed readiness",
    "retrieval leakage",
    "D/E",
    "operator/review-return",
    "mixtral-ssd-tensor-page-read-rows",
    "torch-matvec-parity-rows",
    "real expert FFN forward parity",
    "MoE block forward parity",
    "one-token logits parity",
    "real_model_execution_ready=1",
    "blocked_before_ssd_resident_runtime_claim_count=3",
    "required_real_evidence_field_count=11",
    "missing_real_evidence_field_count=11",
    "latency_memory_excluded_from_quality_score=1",
    "actual generation",
    "release claims remain blocked",
}
REQUIRED_PR2_V61_VERIFICATION_TERMS = {
    "tools/verify_artifact.py v61-one-token v61/one_token_path.json",
    "--v61aa-summary",
    "--v61ab-summary",
    "results/v61aa_hotset_tensor_slice_verifier_summary.csv",
    "results/v61ab_hotset_tensor_tile_quant_probe_summary.csv",
}
REQUIRED_PR2_DOCS_CLEANUP_VERIFICATION_TERMS = {
    "tools/verify_artifact.py typed-readiness readiness/typed_ready.json",
    "--pm-ledger",
    "results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_ready_semantic_rows.csv",
}
REQUIRED_PR2_LEAKAGE_VERIFICATION_TERMS = {
    "tools/verify_artifact.py leakage leakage/retrieval_model_visible.json",
    "--pm-ledger",
    "results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_retrieval_leakage_guard_rows.csv",
}
REQUIRED_PR2_V58_VERIFICATION_TERMS = {
    "tools/verify_artifact.py v58-blind-eval v58/blind_eval_real.json",
    "--readiness-ledger",
    "results/v1_0_pm_pr_claim_slice_gate/gate_001/v58_real_execution_readiness_rows.csv",
    "--artifact-ledger",
    "results/v59e_one_command_pm_foundation_demo/pm_foundation_001/v58_blind_eval_required_artifact_rows.csv",
    "--template-ledger",
    "results/v59e_one_command_pm_foundation_demo/pm_foundation_001/v58_blind_eval_return_template_rows.csv",
}
REQUIRED_PR2_DE_VERIFICATION_TERMS = {
    "tools/verify_artifact.py baseline-admission baselines/de_30b70b_real.json",
    "--measured-registry-ledger",
    "results/v1_0_pm_pr_claim_slice_gate/gate_001/de_measured_registry_exclusion_rows.csv",
    "--acceptance-ledger",
    "results/v1_0_pm_pr_claim_slice_gate/gate_001/de_30b70b_acceptance_evidence_rows.csv",
}
REQUIRED_PR2_V56_VERIFICATION_TERMS = {
    "tools/verify_artifact.py v56-replay v56/replay_contract.json",
    "--summary",
    "results/v56_ruler_longbench_expanded_contract_summary.csv",
    "--blocker-ledger",
    "results/v56_ruler_longbench_expanded_contract/contract_001/v56_seed_dependency_blocker_rows.csv",
    "--artifact-ledger",
    "results/v1_0_pm_pr_claim_slice_gate/gate_001/v56_replay_acceptance_evidence_rows.csv",
}
REQUIRED_PR2_V50_VERIFICATION_TERMS = {
    "tools/verify_artifact.py v50-auditor-correctness audits/v50_public_repo_auditor_correctness.json",
    "--summary",
    "results/v50_public_repo_auditor_3repo_summary.csv",
    "--decision",
    "results/v50_public_repo_auditor_3repo_decision.csv",
}
REQUIRED_PR2_REVIEW_RETURN_VERIFICATION_TERMS = {
    "tools/verify_artifact.py review-return-workflow operations/review_return_workflow.json",
    "--v53s-summary",
    "results/v53s_complete_source_review_return_intake_summary.csv",
    "--v58d-summary",
    "results/v58d_blind_review_return_intake_summary.csv",
    "--v61af-summary",
    "results/v61af_checkpoint_warehouse_operator_bundle_summary.csv",
    "--v61hv-summary",
    "results/v61hv_post_hu_first_real_slice_replacements_to_readiness_no_replay_pipeline_summary.csv",
}
REQUIRED_PR2_V53_SOURCE_BENCHMARK_VERIFICATION_TERMS = {
    "tools/verify_artifact.py v53-source-benchmark benchmarks/v53_source_bound_freeze.json",
    "--v53i-summary",
    "results/v53i_complete_source_query_instantiation_summary.csv",
    "--v53t-summary",
    "results/v53t_complete_source_audit_readiness_gate_summary.csv",
    "--v53ap-summary",
    "results/v53ap_complete_source_abgh_same_query_measured_summary.csv",
    "--v53aq-summary",
    "results/v53aq_complete_source_abgh_real_adapter_measured_summary.csv",
    "--v1-exit-ledger",
    "results/v53t_complete_source_audit_readiness_gate/gate_001/complete_source_v1_exit_criteria_rows.csv",
}
REQUIRED_PR2_V53_PUBLIC_SOURCE_MANIFEST_VERIFICATION_TERMS = {
    "tools/verify_artifact.py v53-public-source-manifest results/v53t_complete_source_audit_readiness_gate_summary.csv",
    "--repo-ledger",
    "results/v53t_complete_source_audit_readiness_gate/gate_001/source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv",
}
REQUIRED_PR2_V54_GROUNDED_GENERATION_VERIFICATION_TERMS = {
    "tools/verify_artifact.py v54-grounded-generation v54/grounded_generation_contract.json",
    "--summary",
    "results/v54c_complete_source_grounded_generation_1000_summary.csv",
}
REQUIRED_PR2_V59_PM_FOUNDATION_VERIFICATION_TERMS = {
    "tools/verify_artifact.py v59-pm-foundation-demo results/v59e_one_command_pm_foundation_demo_summary.csv",
    "--gate-ledger",
    "results/v59e_one_command_pm_foundation_demo/pm_foundation_001/pm_foundation_demo_gate_rows.csv",
    "./experiments/test_v59e_one_command_pm_foundation_demo.sh",
}
EXPECTED_V59_PM_FOUNDATION_SUMMARY = {
    "v59e_one_command_pm_foundation_demo_ready": "1",
    "v59_ready": "0",
    "one_command_entrypoint_ready": "1",
    "challenge_bundle_ready": "1",
    "one_command_replay_preflight_ready": "1",
    "pinned_public_sources_verified": "1",
    "source_snapshot_replay_used": "1",
    "public_source_download_executed": "0",
    "public_source_download_approval_required": "1",
    "full_public_source_download_ready": "0",
    "local_abgh_row_contract_replay_ready": "1",
    "v54c_real_model_generation_ready": "0",
    "v58_full_blind_eval_ready": "0",
    "undocumented_local_state_required": "0",
    "private_fixture_required": "0",
    "manual_postprocessing_required": "0",
    "network_required": "0",
    "blocker_false_positive_closed": "1",
    "real_release_package_ready": "0",
}
EXPECTED_V59_PM_FOUNDATION_GATE_STATUS = {
    "pinned-public-sources-verified": "pass",
    "public-source-replay-policy": "pass",
    "public-source-download-execution": "blocked",
    "local-abgh-row-contract-replay": "pass",
    "evaluator-check": "pass",
    "grounded-generation-outputs": "pass",
    "v58-blind-response-intake": "blocked",
    "v58-blind-review-intake": "blocked",
    "no-hidden-local-state": "pass",
    "blocker-false-positive-closed": "pass",
    "one-command-entrypoint": "pass",
    "challenge-bundle-written": "pass",
    "real-blind-eval": "blocked",
    "full-v59-public-demo": "blocked",
    "real-release-package": "blocked",
    "one-command-replay-preflight": "pass",
}
EXPECTED_V53_PUBLIC_SOURCE_MANIFEST_SUMMARY = {
    "pm_v53_freeze_ready": "1",
    "complete_source_repo_count": "10",
    "foundation_direct_pinned_manifest_ready": "1",
    "foundation_direct_repo_manifest_ready": "1",
    "foundation_direct_content_snapshot_ready": "1",
    "foundation_direct_repo_manifest_rows": "10",
    "foundation_direct_file_manifest_rows": "11266",
    "foundation_direct_content_repo_rows": "10",
    "foundation_direct_content_snapshot_rows": "11266",
    "foundation_direct_query_rows": "1000",
    "foundation_direct_span_rows": "1000",
    "machine_complete_source_surface_ready": "1",
    "review_return_ready": "0",
    "human_review_completed": "0",
    "quality_comparison_claim_ready": "0",
    "v53_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
}
EXPECTED_V53_PUBLIC_REPOS = [
    "pypa/sampleproject",
    "psf/requests",
    "pallets/click",
    "pallets/flask",
    "fastapi/fastapi",
    "django/django",
    "pytest-dev/pytest",
    "pypa/pip",
    "python/cpython",
    "tiangolo/typer",
]
REQUIRED_PR2_ROADMAP_VERIFICATION_TERMS = {
    "tools/verify_artifact.py roadmap-doc docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md",
    "./experiments/test_v1_0_pm_pr_claim_slice_gate.sh",
}
REQUIRED_V1_ROADMAP_TERMS = {
    "# v1.0 Architecture Challenge Roadmap",
    "This roadmap supersedes publishing v0.3 as a broad public claim",
    "source-cited answers",
    "abstention",
    "deterministic lineage",
    "blocked until proven",
    "Transformer replacement",
    "production release readiness",
    "claim boundary",
    "replayable artifacts",
    "false-positive blocker closure rather than by tests alone",
    "The first execution priority is v53",
    "10 pinned public repositories",
    "1000 source-span-bound queries",
    "D/E 30B/70B rows",
    "v58 blind eval",
    "one-command challenge demo",
    "Do not publish comparison language if D or E is missing",
    "Do not call the generator mainline if it answers by copying raw retrieved context",
    "v1.0 can be called an Architecture Challenge release only when all of these are true",
}
REQUIRED_PR2_SPLIT_PLAN_TERMS = {
    "tools/verify_artifact.py pr-split pr_slices/pr2.json",
    "tools/verify_artifact.py typed-readiness readiness/typed_ready.json --pm-ledger results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_ready_semantic_rows.csv",
    "tools/verify_artifact.py leakage leakage/retrieval_model_visible.json --pm-ledger results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_retrieval_leakage_guard_rows.csv",
    "PR2_REWRITE_DRAFT.md",
    "Tests are useful smoke evidence, but tests-only merge conditions are forbidden",
    "readiness/typed_ready.json",
    "leakage/retrieval_model_visible.json",
    "baselines/de_30b70b_real.json",
    "v58/blind_eval_real.json",
    "operations/review_return_workflow.json",
    "v61/one_token_path.json",
    "blocked_before_ssd_resident_runtime_claim_count=3",
    "required_real_evidence_field_count=11",
    "latency_memory_excluded_from_quality_score=1",
    "docs-readme-pr2-cleanup",
}
TESTS_ONLY_MERGE_CONDITIONS = {"tests pass", "test pass", "tests", "test", "ci green"}
TYPED_READINESS_KEYS = {
    *schema_enum_at("typed_readiness.schema.json", "properties", "policy", "properties", "typed_fields", "items"),
}
AMBIGUOUS_READY_FLAGS = set(schema_enum_at("typed_readiness.schema.json", "properties", "policy", "properties", "ambiguous_ready_flags", "items"))
EXPECTED_TYPED_READINESS_ORDER = schema_enum_at("typed_readiness.schema.json", "properties", "rows", "items", "properties", "replacement_flag")
EXPECTED_TYPED_READINESS_CONTRACTS = {
    "pm_foundation_contract_fixture_ready": {
        "scope_id": "pm-foundation-bundle",
        "misleading_ready_flag": "v59_ready",
        "evidence_path": "results/v59e_one_command_pm_foundation_demo_summary.csv",
        "contract_ready": True,
        "fixture_execution_ready": True,
        "real_model_execution_ready": False,
        "heldout_metric_ready": False,
        "human_review_ready": False,
        "independent_reproduction_ready": False,
        "release_ready": False,
    },
    "v53_v54_query_eval_contract_ready": {
        "scope_id": "v53-v54-query-evaluation-pipeline",
        "misleading_ready_flag": "v53_ready",
        "evidence_path": "results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_roadmap_requirement_rows.csv",
        "contract_ready": True,
        "fixture_execution_ready": False,
        "real_model_execution_ready": False,
        "heldout_metric_ready": False,
        "human_review_ready": False,
        "independent_reproduction_ready": False,
        "release_ready": False,
    },
    "v58_blind_eval_protocol_contract_ready": {
        "scope_id": "v58-blind-eval",
        "misleading_ready_flag": "v58_ready",
        "evidence_path": "results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_blocker_required_artifact_rows.csv",
        "contract_ready": True,
        "fixture_execution_ready": False,
        "real_model_execution_ready": False,
        "heldout_metric_ready": False,
        "human_review_ready": False,
        "independent_reproduction_ready": False,
        "release_ready": False,
    },
    "h10_real_label_contract_ready": {
        "scope_id": "h10-scorer-real-label-promotion",
        "misleading_ready_flag": "h10_real_label_promotion_ready",
        "evidence_path": "results/v10_h10_real_label_promotion_readiness_gate/gate_001/pm_h10_real_label_acceptance_rows.csv",
        "contract_ready": True,
        "fixture_execution_ready": False,
        "real_model_execution_ready": False,
        "heldout_metric_ready": False,
        "human_review_ready": False,
        "independent_reproduction_ready": False,
        "release_ready": False,
    },
    "logical_100b_contract_fixture_ready": {
        "scope_id": "v61-ssd-moe-runtime",
        "misleading_ready_flag": "100b_moe_run_ready",
        "evidence_path": "results/v61j_one_command_ssd_resident_demo_summary.csv",
        "contract_ready": True,
        "fixture_execution_ready": True,
        "real_model_execution_ready": False,
        "heldout_metric_ready": False,
        "human_review_ready": False,
        "independent_reproduction_ready": False,
        "release_ready": False,
    },
    "real_100b_inference_ready": {
        "scope_id": "v61-real-100b-inference",
        "misleading_ready_flag": "100b_moe_run_ready",
        "evidence_path": "results/v61j_one_command_ssd_resident_demo_summary.csv",
        "contract_ready": False,
        "fixture_execution_ready": False,
        "real_model_execution_ready": False,
        "heldout_metric_ready": False,
        "human_review_ready": False,
        "independent_reproduction_ready": False,
        "release_ready": False,
    },
    "v61i_logical_100b_contract_fixture_ready": {
        "scope_id": "v61i-logical-100b-fixture",
        "misleading_ready_flag": "v61i_100b_moe_active_sparse_run_ready",
        "evidence_path": "results/v61j_one_command_ssd_resident_demo_summary.csv",
        "contract_ready": True,
        "fixture_execution_ready": True,
        "real_model_execution_ready": False,
        "heldout_metric_ready": False,
        "human_review_ready": False,
        "independent_reproduction_ready": False,
        "release_ready": False,
    },
    "v60_release_contract_ready": {
        "scope_id": "v60-release",
        "misleading_ready_flag": "v60_ready",
        "evidence_path": "results/v60_architecture_challenge_release_contract_summary.csv",
        "contract_ready": True,
        "fixture_execution_ready": False,
        "real_model_execution_ready": False,
        "heldout_metric_ready": False,
        "human_review_ready": False,
        "independent_reproduction_ready": False,
        "release_ready": False,
    },
    "operator_review_return_workflow_contract_ready": {
        "scope_id": "operator-review-return-workflow",
        "misleading_ready_flag": "review_return_ready",
        "evidence_path": "operations/review_return_workflow.json",
        "contract_ready": True,
        "fixture_execution_ready": False,
        "real_model_execution_ready": False,
        "heldout_metric_ready": False,
        "human_review_ready": False,
        "independent_reproduction_ready": False,
        "release_ready": False,
    },
    "pr2_docs_claim_boundary_contract_ready": {
        "scope_id": "docs-readme-pr2-cleanup",
        "misleading_ready_flag": "pr2_ready",
        "evidence_path": "docs/PR2_REWRITE_DRAFT.md",
        "contract_ready": True,
        "fixture_execution_ready": False,
        "real_model_execution_ready": False,
        "heldout_metric_ready": False,
        "human_review_ready": False,
        "independent_reproduction_ready": False,
        "release_ready": False,
    },
}
EXPECTED_LEAKAGE_GUARD_IDS = schema_enum_at("leakage_contract.schema.json", "properties", "forbidden_surfaces", "items", "properties", "guard_id")
FORBIDDEN_MODEL_VISIBLE_FIELDS = set(schema_enum_at("leakage_contract.schema.json", "properties", "forbidden_surfaces", "items", "properties", "field_names", "items"))
ALLOWED_MODEL_VISIBLE_FIELDS = set(schema_enum_at("leakage_contract.schema.json", "properties", "policy", "properties", "allowed_model_visible_fields", "items"))
EXPECTED_LEAKAGE_STAGE_ORDER = schema_enum_at("leakage_contract.schema.json", "properties", "stage_contracts", "items", "properties", "stage_id")
EXPECTED_LEAKAGE_STAGE_CONTRACTS = {
    "v53aq-sanitized-abgh-real-adapter": {
        "surface_kind": "model_or_retriever",
        "summary_path": "results/v53aq_complete_source_abgh_real_adapter_measured_summary.csv",
        "allowed_model_visible_fields": ["sanitized_question"],
        "forbidden_field_summary": "selection_forbidden_fields",
        "must_equal": {
            "selection_question_text_only": "1",
            "selection_sanitized_question_only": "1",
            "source_locator_in_question_removed_rows": "4000",
            "selection_allowed_fields": "sanitized_question",
            "selection_oracle_field_used": "0",
            "source_span_oracle_selection_used": "0",
            "expected_answer_oracle_replay": "0",
            "deterministic_source_span_adapter_execution": "0",
        },
    },
    "v54c-grounded-generation-guard": {
        "surface_kind": "model_or_retriever",
        "summary_path": "results/v54c_complete_source_grounded_generation_1000_summary.csv",
        "allowed_model_visible_fields": ["sanitized_question", "opaque_routehint"],
        "must_equal": {
            "model_visible_leakage_guard_ready": "1",
            "model_visible_input_fields": "sanitized_question,opaque_routehint",
            "model_visible_forbidden_field_used_rows": "0",
            "model_visible_source_locator_rows": "0",
            "compact_routehint_forbidden_alias_rows": "0",
            "raw_prompt_context_appended_rows": "0",
            "real_model_generation_ready": "0",
        },
    },
    "v53ap-source-span-fixture-replay-boundary": {
        "surface_kind": "source_bound_non_model_adapter",
        "summary_path": "results/v53ap_complete_source_abgh_same_query_measured_summary.csv",
        "allowed_model_visible_fields": ["none"],
        "must_equal": {
            "expected_answer_oracle_replay": "0",
            "deterministic_source_span_adapter_execution": "1",
            "actual_adapter_execution_ready": "1",
            "real_system_performance_claim_ready": "0",
            "public_comparison_claim_ready": "0",
        },
    },
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
DEFAULT_DE_MEASURED_REGISTRY_LEDGER = Path(
    "results/v1_0_pm_pr_claim_slice_gate/gate_001/de_measured_registry_exclusion_rows.csv"
)
DEFAULT_DE_ACCEPTANCE_LEDGER = Path(
    "results/v1_0_pm_pr_claim_slice_gate/gate_001/de_30b70b_acceptance_evidence_rows.csv"
)
EXPECTED_DE_PM_LEDGERS = [
    {
        "ledger_id": "de-measured-registry-exclusion",
        "path": str(DEFAULT_DE_MEASURED_REGISTRY_LEDGER),
        "required_for": "fixture_d_e_rows_stay_out_of_measured_registry",
    },
    {
        "ledger_id": "de-acceptance-evidence-blockers",
        "path": str(DEFAULT_DE_ACCEPTANCE_LEDGER),
        "required_for": "real_d_e_acceptance_artifacts_remain_blocked_until_present",
    },
]
EXPECTED_DE_REQUIRED_ARTIFACT_COLUMNS = {
    "model-identity": {
        "system_id",
        "model_id",
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
        "case_id",
        "model_id",
        "predicted_label",
        "prompt_template_sha256",
        "context_budget",
        "retrieval_budget",
        "seed",
        "raw_answer",
        "raw_citation",
        "raw_output_sha256",
        "generation_transcript_sha256",
        "raw_prompt_context_bytes",
        "retrieved_span_rows",
        "prompt_context_sha256",
        "output_sha256",
        "latency_ns",
        "external_api_used",
        "route_memory_store_used",
        "compact_routehint_used",
    },
    "resource-evaluator-manifest": {
        "query_id",
        "model_id",
        "latency_ns",
        "raw_prompt_context_bytes",
        "retrieved_span_rows",
        "peak_memory_mb",
        "evaluator_version",
        "evaluator_artifact_sha256",
        "external_api_used",
    },
}
EXPECTED_DE_REQUIRED_ARTIFACT_KINDS = {
    "model-identity": "json",
    "answer-citation-raw-output": "csv",
    "resource-evaluator-manifest": "csv",
}
EXPECTED_V52_C_ARTIFACT_IDS = [
    "c-answer-rows",
    "c-citation-rows",
    "c-resource-rows",
    "c-retrieval-rows",
    "c-abstain-rows",
    "c-wrong-answer-guard-rows",
    "c-generation-transcript-rows",
    "c-sha256-manifest",
]
EXPECTED_V52_C_ARTIFACT_COLUMNS = {
    "c-answer-rows": [
        "answer_id",
        "system_id",
        "query_id",
        "repo_id",
        "owner_repo",
        "audit_type",
        "expected_answer_sha256",
        "predicted_answer",
        "predicted_answer_sha256",
        "correct",
        "abstained",
        "retrieved_source_span_id",
        "raw_prompt_context_bytes",
        "compact_routehint_bytes",
        "context_or_hint_sha256",
        "latency_ns",
    ],
    "c-citation-rows": [
        "citation_id",
        "answer_id",
        "system_id",
        "query_id",
        "source_span_id",
        "repo_id",
        "owner_repo",
        "path",
        "line_start",
        "line_end",
        "source_file_sha256",
        "evidence_text_sha256",
        "citation_correct",
    ],
    "c-resource-rows": [
        "system_id",
        "query_id",
        "latency_ns",
        "raw_prompt_context_bytes",
        "compact_routehint_bytes",
        "retrieved_span_rows",
        "external_network_used",
        "external_model_used",
        "route_memory_store_used",
        "compact_routehint_used",
        "source_verified_scorer_used",
        "domain_policy_used",
    ],
    "c-retrieval-rows": [
        "system_id",
        "query_id",
        "rank",
        "score",
        "source_span_id",
        "owner_repo",
        "path",
        "line_start",
    ],
    "c-abstain-rows": [
        "system_id",
        "query_id",
        "negative_or_abstain",
        "abstained",
        "abstain_correct",
    ],
    "c-wrong-answer-guard-rows": [
        "system_id",
        "query_id",
        "expected_answer_sha256",
        "predicted_answer_sha256",
        "wrong_answer",
        "guard_triggered",
        "guard_status",
    ],
    "c-generation-transcript-rows": [
        "query_id",
        "prompt_sha256",
        "response_sha256",
        "predicted_answer_sha256",
        "raw_response",
    ],
    "c-sha256-manifest": [
        "path",
        "sha256",
        "bytes",
    ],
}
EXPECTED_V52_C_MIN_ROWS = {
    "c-answer-rows": 1000,
    "c-citation-rows": 1000,
    "c-resource-rows": 1000,
    "c-retrieval-rows": 1000,
    "c-abstain-rows": 1000,
    "c-wrong-answer-guard-rows": 1000,
    "c-generation-transcript-rows": 1000,
    "c-sha256-manifest": 14,
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
EXPECTED_V53_SUMMARY_CHECKS = {
    "pinned-public-repo-manifest": [
        ("v53i", "repo_count", "10"),
        ("v53t", "foundation_direct_pinned_manifest_ready", "1"),
        ("v53t", "foundation_direct_repo_manifest_rows", "10"),
        ("v53t", "foundation_direct_file_manifest_rows", "11266"),
        ("v53t", "foundation_direct_content_snapshot_rows", "11266"),
    ],
    "source-span-bound-1000-query-surface": [
        ("v53i", "complete_source_query_rows", "1000"),
        ("v53i", "complete_source_span_rows", "1000"),
        ("v53i", "missing_query_rows", "0"),
        ("v53t", "foundation_query_span_binding_audit_ready", "1"),
        ("v53t", "foundation_query_span_binding_pass_rows", "1000"),
        ("v53t", "foundation_query_span_binding_blocked_rows", "0"),
    ],
    "negative-unsupported-missing-doc-code-controls": [
        ("v53i", "negative_abstain_rows", "160"),
        ("v53i", "unsupported_control_rows", "100"),
        ("v53i", "missing_specific_abstain_rows", "30"),
        ("v53i", "doc_code_conflict_rows", "140"),
        ("v53t", "v1_exit_negative_control_share_ready", "1"),
    ],
    "answer-citation-resource-separate-evaluator": [
        ("v53ap", "same_evaluator_contract_all_local_systems", "1"),
        ("v53ap", "same_resource_contract_all_local_systems", "1"),
        ("v53aq", "same_evaluator_contract_all_local_systems", "1"),
        ("v53aq", "same_resource_contract_all_local_systems", "1"),
        ("v53t", "foundation_direct_evaluator_separate_rows", "4000"),
    ],
    "abgh-same-query-internal-prebaseline": [
        ("v53ap", "same_query_set_all_local_systems", "1"),
        ("v53aq", "same_query_set_all_local_systems", "1"),
        ("v53t", "v53aq_same_complete_source_query_hash", "1"),
        ("v53aq", "public_comparison_claim_ready", "0"),
        ("v53aq", "required_30b_baseline_ready", "0"),
        ("v53aq", "required_70b_baseline_ready", "0"),
    ],
    "sanitized-question-only-adapter-selection": [
        ("v53aq", "selection_question_text_only", "1"),
        ("v53aq", "selection_sanitized_question_only", "1"),
        ("v53aq", "source_locator_in_question_removed_rows", "4000"),
        ("v53aq", "selection_oracle_field_used", "0"),
        ("v53aq", "source_span_oracle_selection_used", "0"),
        ("v53aq", "expected_answer_oracle_replay", "0"),
    ],
}
DEFAULT_V53_SUMMARY_PATHS = {
    "v53i": Path("results/v53i_complete_source_query_instantiation_summary.csv"),
    "v53t": Path("results/v53t_complete_source_audit_readiness_gate_summary.csv"),
    "v53ap": Path("results/v53ap_complete_source_abgh_same_query_measured_summary.csv"),
    "v53aq": Path("results/v53aq_complete_source_abgh_real_adapter_measured_summary.csv"),
}
EXPECTED_V54_ARTIFACT_IDS = [
    "answer-rows",
    "citation-rows",
    "unsupported-claim-rows",
    "abstain-rows",
    "generator-resource-rows",
    "wrong-answer-guard-rows",
    "generator-input-rows",
    "compact-routehint-rows",
    "sha256-manifest",
    "sha256sums",
]
EXPECTED_V54_ARTIFACT_COLUMNS = {
    "answer-rows": [
        "answer_id", "generation_id", "query_id", "owner_repo", "audit_type",
        "expected_behavior", "generated_answer", "generated_answer_sha256",
        "expected_answer_sha256", "answer_source", "generated_from_source_span",
        "abstained", "source_span_id", "source_v53ap_adapter_trace_id",
        "source_v53ap_evaluator_row_id", "citation_id", "answer_correct",
        "citation_correct", "wrong_answer",
    ],
    "citation-rows": [
        "citation_id", "generation_id", "answer_id", "query_id", "owner_repo",
        "path", "line_start", "line_end", "source_span_id",
        "source_file_sha256", "citation_text_sha256", "citation_correct",
        "source_v53ap_evaluator_row_id",
    ],
    "unsupported-claim-rows": [
        "generation_id", "query_id", "audit_type", "unsupported_claim_type",
        "source_span_id", "expected_output",
    ],
    "abstain-rows": [
        "generation_id", "query_id", "audit_type", "source_span_id",
        "abstain_expected", "abstained", "abstain_correct",
    ],
    "generator-resource-rows": [
        "generator_resource_row_id", "generation_id", "query_id",
        "generator_id", "latency_ms", "compact_routehint_bytes",
        "output_bytes", "external_model_used", "external_network_used",
        "answer_source", "generated_from_source_span",
        "source_v53ap_adapter_trace_id",
        "source_v53ap_adapter_trace_provenance",
        "source_v53ap_evaluator_row_id",
        "source_v53ap_evaluator_contract_id",
        "source_v53ap_evaluator_provenance",
        "source_v53ap_answer_eval_separate",
        "source_v53ap_citation_eval_separate",
        "source_v53ap_resource_eval_separate",
        "source_v53ap_evaluator_resource_row_bound",
        "attention_blocks", "transformer_blocks", "raw_prompt_context_bytes",
        "run_started_at_utc",
    ],
    "wrong-answer-guard-rows": [
        "wrong_answer_guard_id", "generation_id", "query_id",
        "expected_answer_sha256", "generated_answer_sha256",
        "answer_correct", "citation_correct", "abstain_correct",
        "source_v53ap_evaluator_row_id", "source_v53ap_answer_eval_separate",
        "source_v53ap_citation_eval_separate",
        "source_v53ap_resource_eval_separate",
        "source_v53ap_evaluator_resource_row_bound", "wrong_answer",
        "guard_status",
    ],
    "generator-input-rows": [
        "generation_id", "query_id_evaluator_only", "generator_id",
        "compact_routehint_sha256", "compact_routehint_allowed_key_set",
        "compact_routehint_forbidden_alias_used", "model_visible_input_fields",
        "sanitized_question", "sanitized_question_sha256",
        "model_visible_query_id_used", "model_visible_source_span_id_used",
        "model_visible_source_path_used", "model_visible_source_line_used",
        "model_visible_source_file_hash_used",
        "model_visible_expected_behavior_used",
        "model_visible_expected_label_used",
        "compact_routehint_contains_source_locator",
        "source_span_id_evaluator_only", "source_v53ap_adapter_trace_id",
        "source_v53ap_adapter_trace_type",
        "source_v53ap_adapter_trace_provenance",
        "source_v53ap_evaluator_row_id",
        "source_v53ap_evaluator_contract_id",
        "source_v53ap_evaluator_provenance",
        "source_v53ap_answer_eval_separate",
        "source_v53ap_citation_eval_separate",
        "source_v53ap_resource_eval_separate",
        "source_v53ap_evaluator_resource_row_bound",
        "attention_blocks", "transformer_blocks",
        "raw_prompt_context_appended", "raw_prompt_context_bytes",
        "retrieved_text_in_prompt",
        "deterministic_source_span_generation_fixture",
        "real_model_generation_ready",
    ],
    "compact-routehint-rows": [
        "routehint_id", "generation_id", "query_id_evaluator_only",
        "source_span_id_evaluator_only", "compact_routehint_sha256",
        "compact_routehint_bytes", "compact_routehint_allowed_key_set",
        "compact_routehint_forbidden_alias_used", "raw_context_appended",
        "model_visible_routehint", "model_visible_input_fields",
        "model_visible_query_id_used", "model_visible_source_span_id_used",
        "model_visible_source_path_used", "model_visible_source_line_used",
        "model_visible_source_file_hash_used",
        "model_visible_expected_behavior_used",
        "model_visible_expected_label_used", "contains_source_locator",
        "source_v53ap_adapter_trace_id", "source_v53ap_adapter_system_id",
        "source_v53ap_evaluator_row_id",
        "source_v53ap_evaluator_contract_id", "citation_handle",
    ],
    "sha256-manifest": ["path", "sha256", "bytes"],
    "sha256sums": [],
}
EXPECTED_V54_MIN_ROWS = {
    "answer-rows": 1000,
    "citation-rows": 1000,
    "unsupported-claim-rows": 160,
    "abstain-rows": 160,
    "generator-resource-rows": 1000,
    "wrong-answer-guard-rows": 1000,
    "generator-input-rows": 1000,
    "compact-routehint-rows": 1000,
    "sha256-manifest": 10,
    "sha256sums": 1,
}
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
EXPECTED_V50_ARTIFACT_COLUMNS = {
    "source-snapshot-rows": [
        "repo_id",
        "owner_repo",
        "repo_url",
        "requested_ref",
        "head_sha",
        "ref_pinned",
        "file_path",
        "artifact_path",
        "sha256",
        "bytes",
        "line_count",
        "public_repo_snapshot",
    ],
    "audit-case-rows": [
        "case_id",
        "repo_id",
        "owner_repo",
        "repo_url",
        "head_sha",
        "audit_type",
        "detector_method",
        "primary_observed",
        "secondary_observed",
        "expected_label",
        "predicted_label",
        "correct",
        "finding",
        "primary_path",
        "primary_sha256",
        "primary_line",
        "secondary_path",
        "secondary_sha256",
        "secondary_line",
        "source_spans_ready",
        "not_upstream_defect_claim",
    ],
    "source-span-rows": [
        "case_id",
        "repo_id",
        "kind",
        "path",
        "sha256",
        "line",
        "text",
    ],
    "guard-negative-rows": [
        "negative_case_id",
        "guard",
        "expected_block",
        "blocked",
        "wrong_answer_guard_pass",
        "citation_accuracy_pass",
        "abstain_behavior_pass",
        "reason",
    ],
    "commercial-return-query-set": [
        "query_id",
        "question",
        "expected_behavior",
        "source_path",
        "source_sha256",
        "source_line",
    ],
    "commercial-return-poc-results": [
        "query_id",
        "answer",
        "citation_path",
        "citation_sha256",
        "citation_line",
        "citation_text",
        "secondary_citation_path",
        "secondary_citation_sha256",
        "secondary_citation_line",
        "secondary_citation_text",
        "wrong_answer_guard_pass",
        "citation_accuracy_pass",
        "abstain_behavior_pass",
        "query_to_evidence_latency_ready",
        "latency_ms",
        "route_memory_lineage_bound",
        "mmap_or_exact_span_bound",
        "audit_trail_bound",
    ],
    "commercial-return-audit-trail": [
        "event_id",
        "query_id",
        "event",
        "repo_id",
        "verifier_decision",
        "status",
    ],
    "sha256-manifest": [
        "path",
        "sha256",
        "bytes",
    ],
}
EXPECTED_V50_MIN_ROWS = {
    "source-snapshot-rows": 9,
    "audit-case-rows": 9,
    "source-span-rows": 18,
    "guard-negative-rows": 3,
    "commercial-return-query-set": 9,
    "commercial-return-poc-results": 9,
    "commercial-return-audit-trail": 9,
    "sha256-manifest": 7,
}
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
EXPECTED_V56_REPLAY_ARTIFACT_IDS = [
    "v56-contract-summary",
    "v56-contract-artifacts",
    "v56b-scale-summary",
    "v56b-scale-artifacts",
]
EXPECTED_V56_REPLAY_ARTIFACT_KINDS = {
    "v56-contract-summary": "summary-csv",
    "v56-contract-artifacts": "artifact-directory",
    "v56b-scale-summary": "summary-csv",
    "v56b-scale-artifacts": "artifact-directory",
}
EXPECTED_V56_MISSING_SEED_PATHS = [
    "results/v49_ruler_niah_200_500_scale_summary.csv",
    "results/v49_ruler_niah_200_500_scale/scale_001/V49_RULER_NIAH_200_500_BOUNDARY.md",
    "results/v49_ruler_niah_200_500_scale/scale_001/scale_rows.csv",
    "results/v49_ruler_niah_200_500_scale/scale_001/v49_ruler_niah_200_500_scale_manifest.json",
    "results/v49_ruler_niah_200_500_scale/scale_001/sha256_manifest.csv",
    "results/v49_ruler_niah_200_500_scale/scale_001/evidence/expanded_result_rows_200.csv",
    "results/v49_ruler_niah_200_500_scale/scale_001/evidence/expanded_result_rows_500.csv",
    "results/v49_ruler_niah_200_500_scale/scale_001/evidence/candidate_result_rows_200.csv",
    "results/v49_ruler_niah_200_500_scale/scale_001/evidence/candidate_result_rows_500.csv",
    "results/v45_longbench_v2_small_slice/slice_001/V45_LONGBENCH_V2_SMALL_SLICE_BOUNDARY.md",
    "results/v45_longbench_v2_small_slice/slice_001/v45_longbench_v2_small_slice_manifest.json",
    "results/v45_longbench_v2_small_slice/slice_001/sha256_manifest.csv",
    "results/v45_longbench_v2_small_slice/slice_001/official_return/raw_predictions.jsonl",
    "results/v45_longbench_v2_small_slice/slice_001/official_return/prediction_lineage.jsonl",
    "results/v45_longbench_v2_small_slice/slice_001/official_return/metrics.json",
    "results/v45_longbench_v2_small_slice/slice_001/official_return/provenance_manifest.json",
    "results/v45_longbench_v2_small_slice/slice_001/official_return/official_source_snapshot.json",
    "results/v45_longbench_v2_small_slice/slice_001/official_return/official_evaluator_status.json",
    "results/v45_longbench_v2_small_slice/slice_001/official_return/candidate_result_rows.csv",
    "results/v45_longbench_v2_small_slice/slice_001/official_source_snapshot/download_rows.csv",
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
        "blind_response_id",
        "blind_eval_id",
        "query_id",
        "blind_system_id",
        "response_text",
        "citation_source_span_id",
        "abstained",
        "output_sha256",
        "latency_ns",
        "memory_peak_bytes",
        "cost_usd",
        "model_run_id",
        "credential_redacted",
        "resource_trace_sha256",
        "frozen_query_packet_sha256",
        "source_manifest_sha256",
        "context_budget",
        "retrieval_budget",
        "latency_memory_excluded_from_quality_score",
    },
    "v58-run-identity-rows": {
        "blind_system_id",
        "source_system_id",
        "model_or_architecture_id",
        "corpus_id",
        "context_budget",
        "retrieval_budget",
        "prompt_template_sha256",
        "source_manifest_sha256",
        "external_api_used",
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
        "blind_response_id",
        "blind_eval_id",
        "query_id",
        "blind_system_id",
        "latency_ns",
        "memory_peak_bytes",
        "resource_trace_sha256",
        "frozen_query_packet_sha256",
        "source_manifest_sha256",
        "context_budget",
        "retrieval_budget",
        "latency_memory_excluded_from_quality_score",
    },
    "v58-human-review-rows": {
        "blind_response_id",
        "blind_eval_id",
        "blind_system_id",
        "reviewer_id",
        "reviewer_pool_id",
        "reviewer_blinded",
        "reviewer_independent",
        "conflict_disclosed",
        "answer_correctness",
        "citation_correctness",
        "abstain_correctness",
        "source_span_exactness",
        "unsupported_abstention_correctness",
        "unseen_repository_split_id",
        "latency_memory_excluded_from_quality_score",
        "policy_score",
        "review_decision",
        "review_sha256",
    },
    "v58-adjudication-rows": {
        "blind_response_id",
        "blind_eval_id",
        "blind_system_id",
        "reviewer_a_id",
        "reviewer_b_id",
        "reviewer_a_decision",
        "reviewer_b_decision",
        "adjudicated_decision",
        "inter_rater_agree",
        "adjudicator_id",
        "adjudicator_pool_id",
        "adjudicator_independent",
        "adjudication_sha256",
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
EXPECTED_V58_ARTIFACT_MIN_ROWS = {
    "v58-blind-response-rows": 3500,
    "v58-run-identity-rows": 7,
    "v58-query-split-rows": 500,
    "v58-resource-rows": 3500,
    "v58-human-review-rows": 7000,
    "v58-adjudication-rows": 3500,
    "v58d-review-return-intake": 1,
    "v58-sha256-manifest": 10,
}
EXPECTED_V58_PER_SYSTEM_MIN_ROWS = {
    "v58-blind-response-rows": {"A": 500, "B": 500, "C": 500, "D": 500, "E": 500, "G": 500, "H": 500},
    "v58-resource-rows": {"A": 500, "B": 500, "C": 500, "D": 500, "E": 500, "G": 500, "H": 500},
}
V58_REVIEW_FORBIDDEN_RESOURCE_COLUMNS = {
    "latency_ms",
    "latency_ns",
    "memory_mb",
    "memory_peak_bytes",
    "peak_memory_mb",
    "tokens_per_second",
}
V58_REVIEW_FORBIDDEN_IDENTITY_COLUMNS = {
    "system_id",
    "source_system_id",
    "source_system_name",
    "model_or_architecture_id",
    "run_identity",
}
EXPECTED_V58_VALIDATION_COMMANDS = {
    "v58-blind-response-rows": "V58C_BLIND_RESPONSE_EVIDENCE_DIR=<BLIND_RESPONSE_DIR> ./experiments/test_v58c_blind_response_evidence_intake.sh",
    "v58-run-identity-rows": "V58C_BLIND_RESPONSE_EVIDENCE_DIR=<BLIND_RESPONSE_DIR> ./experiments/test_v58c_blind_response_evidence_intake.sh",
    "v58-query-split-rows": "V58C_BLIND_RESPONSE_EVIDENCE_DIR=<BLIND_RESPONSE_DIR> ./experiments/test_v58c_blind_response_evidence_intake.sh",
    "v58-resource-rows": "V58C_BLIND_RESPONSE_EVIDENCE_DIR=<BLIND_RESPONSE_DIR> ./experiments/test_v58c_blind_response_evidence_intake.sh",
    "v58-human-review-rows": "V58D_BLIND_REVIEW_RETURN_DIR=<REVIEW_RETURN_DIR> ./experiments/test_v58d_blind_review_return_intake.sh",
    "v58-adjudication-rows": "V58D_BLIND_REVIEW_RETURN_DIR=<REVIEW_RETURN_DIR> ./experiments/test_v58d_blind_review_return_intake.sh",
    "v58d-review-return-intake": "./experiments/test_v58d_blind_review_return_intake.sh",
    "v58-sha256-manifest": "V58C_BLIND_RESPONSE_EVIDENCE_DIR=<BLIND_RESPONSE_DIR> ./experiments/test_v58c_blind_response_evidence_intake.sh",
}
EXPECTED_REVIEW_RETURN_REQUIREMENT_IDS = [
    "v53-review-return-intake-blocked",
    "v58-blind-review-return-blocked",
    "v61-operator-bundle-logistics-only",
    "v61-first-slice-operator-input-blocked",
]
EXPECTED_REVIEW_RETURN_SUMMARY_CHECKS = {
    "v53-review-return-intake-blocked": [
        ("v53s", "v53s_complete_source_review_return_intake_ready", "1"),
        ("v53s", "review_return_input_supplied", "0"),
        ("v53s", "expected_human_review_rows", "7000"),
        ("v53s", "accepted_human_review_rows", "0"),
        ("v53s", "expected_adjudication_rows", "1000"),
        ("v53s", "accepted_adjudication_rows", "0"),
        ("v53s", "human_review_completed", "0"),
        ("v53s", "adjudication_completed", "0"),
        ("v53s", "review_return_ready", "0"),
    ],
    "v58-blind-review-return-blocked": [
        ("v58d", "v58d_blind_review_return_intake_ready", "1"),
        ("v58d", "v58d_dependency_blocker_ready", "1"),
        ("v58d", "review_dir_supplied", "0"),
        ("v58d", "required_blind_review_ready", "0"),
        ("v58d", "required_adjudication_ready", "0"),
        ("v58d", "human_blind_review_ready", "0"),
        ("v58d", "inter_rater_rows_ready", "0"),
        ("v58d", "v58_full_blind_eval_ready", "0"),
        ("v58d", "real_release_package_ready", "0"),
    ],
    "v61-operator-bundle-logistics-only": [
        ("v61af", "v61af_checkpoint_warehouse_operator_bundle_ready", "1"),
        ("v61af", "operator_command_rows", "62"),
        ("v61af", "download_dry_run_default", "1"),
        ("v61af", "full_hash_dry_run_default", "1"),
        ("v61af", "materialization_admission_ready", "0"),
        ("v61af", "local_checkpoint_materialization_ready", "0"),
        ("v61af", "generation_admitted_rows", "0"),
        ("v61af", "actual_model_generation_ready", "0"),
        ("v61af", "real_release_package_ready", "0"),
    ],
    "v61-first-slice-operator-input-blocked": [
        ("v61hv", "v61hv_post_hu_first_real_slice_replacements_to_readiness_no_replay_pipeline_ready", "1"),
        ("v61hv", "replacements_to_readiness_ready", "1"),
        ("v61hv", "form_values_supplied", "0"),
        ("v61hv", "operator_input_files_ready", "0"),
        ("v61hv", "ack_values_supplied", "0"),
        ("v61hv", "dual_output_roots_ready", "0"),
        ("v61hv", "row_acceptance_ready", "0"),
        ("v61hv", "generation_acceptance_closure_ready", "0"),
        ("v61hv", "actual_model_generation_ready", "0"),
        ("v61hv", "real_release_package_ready", "0"),
    ],
}
V61_SCHEMA_CONTRACT = schema_contract("v61_one_token_path.schema.json")
EXPECTED_V61_MILESTONE_IDS = list(V61_SCHEMA_CONTRACT["milestone_order"])
V61_REQUIRED_BEFORE_RUNTIME_CLAIM = list(V61_SCHEMA_CONTRACT["required_before_runtime_claim"])
EXPECTED_V61_CURRENT_STATUS = dict(V61_SCHEMA_CONTRACT["current_status_by_milestone"])
V61_ARTIFACT_CONTRACTS = {
    row["artifact_id"]: row
    for row in V61_SCHEMA_CONTRACT["artifact_contracts"]
}
V61_BLOCKED_BEFORE_RUNTIME_CLAIM = [
    milestone_id
    for milestone_id in V61_REQUIRED_BEFORE_RUNTIME_CLAIM
    if EXPECTED_V61_CURRENT_STATUS[milestone_id] == "blocked"
]
V61_PASSED_BEFORE_RUNTIME_CLAIM = [
    milestone_id
    for milestone_id in V61_REQUIRED_BEFORE_RUNTIME_CLAIM
    if EXPECTED_V61_CURRENT_STATUS[milestone_id] == "pass"
]
EXPECTED_V61_REQUIRED_ARTIFACT_COLUMNS = {
    artifact_id: list(row["required_columns"])
    for artifact_id, row in V61_ARTIFACT_CONTRACTS.items()
}
EXPECTED_V61_ARTIFACT_IDS = list(V61_ARTIFACT_CONTRACTS)
EXPECTED_V61_REQUIRED_ARTIFACT_PATHS = {
    artifact_id: row["path"]
    for artifact_id, row in V61_ARTIFACT_CONTRACTS.items()
}
EXPECTED_V61_ARTIFACT_MILESTONES = {
    artifact_id: row["linked_milestone_id"]
    for artifact_id, row in V61_ARTIFACT_CONTRACTS.items()
}
EXPECTED_V61_ARTIFACT_PASS_FIELDS = {
    artifact_id: row["pass_field"]
    for artifact_id, row in V61_ARTIFACT_CONTRACTS.items()
}
EXPECTED_V61_ARTIFACT_MIN_ROWS = {
    artifact_id: row["min_rows"]
    for artifact_id, row in V61_ARTIFACT_CONTRACTS.items()
}
EXPECTED_V61_ARTIFACT_VALUE_CHECKS = {
    artifact_id: dict(checks)
    for artifact_id, checks in V61_SCHEMA_CONTRACT["artifact_value_checks"].items()
}
V61_REAL_MODEL_EXECUTION_PASS_MILESTONES = set(V61_SCHEMA_CONTRACT["real_model_execution_pass_milestones"])
V61_BLOCKED_RUNTIME_FORBIDDEN_READY_FIELDS = set(V61_SCHEMA_CONTRACT["blocked_runtime_forbidden_ready_fields"])


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
        else:
            for field, value in typed.items():
                if str(value).strip().lower() in {"1", "true", "ready"}:
                    errors.append(f"{prefix}: typed_readiness.{field} cannot be an untyped literal-ready claim")
        if not stage.get("claim_boundary"):
            errors.append(f"{prefix}: claim_boundary must be non-empty")
        model_visible_inputs = stage.get("model_visible_inputs", [])
        if model_visible_inputs:
            if not isinstance(model_visible_inputs, list):
                errors.append(f"{prefix}: model_visible_inputs must be a list when present")
            else:
                pipeline_forbidden_inputs = FORBIDDEN_MODEL_VISIBLE_FIELDS | {"source_span_fixture", "source_fixture"}
                pipeline_allowed_inputs = ALLOWED_MODEL_VISIBLE_FIELDS | {
                    "natural_language_question",
                    "searchable_corpus",
                    "blind_question",
                    "shared_context_budget",
                }
                leaked_inputs = set(str(item) for item in model_visible_inputs) & pipeline_forbidden_inputs
                if leaked_inputs:
                    errors.append(f"{prefix}: model_visible_inputs contains forbidden evaluator-only field(s): {', '.join(sorted(leaked_inputs))}")
                unknown_visible = set(str(item) for item in model_visible_inputs) - pipeline_allowed_inputs
                if unknown_visible:
                    errors.append(f"{prefix}: model_visible_inputs contains undeclared model-visible field(s): {', '.join(sorted(unknown_visible))}")
                evaluator_only_fields = stage.get("evaluator_only_fields", [])
                if not isinstance(evaluator_only_fields, list):
                    errors.append(f"{prefix}: evaluator_only_fields must be a list when model_visible_inputs are declared")
                elif "query_id" not in set(str(item) for item in evaluator_only_fields):
                    errors.append(f"{prefix}: model-visible stages must declare query_id as evaluator-only")
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
        repo_root = path.parent.parent if path.parent.name == "pr_slices" else Path(".")
        rewrite_draft = repo_root / "docs" / "PR2_REWRITE_DRAFT.md"
        split_plan = repo_root / "docs" / "PR2_SPLIT_PLAN.md"
        if not rewrite_draft.is_file():
            errors.append(f"{path}: docs/PR2_REWRITE_DRAFT.md is required for PR #2 title/body rewrite")
        else:
            draft_text = rewrite_draft.read_text(encoding="utf-8")
            draft_text_lower = " ".join(draft_text.split()).lower()
            if data["recommended_title"] not in draft_text:
                errors.append(f"{rewrite_draft}: missing recommended_title from {path}")
            missing_draft_terms = [
                term
                for term in REQUIRED_PR2_REWRITE_TERMS
                if " ".join(term.split()).lower() not in draft_text_lower
            ]
            if missing_draft_terms:
                errors.append(
                    f"{rewrite_draft}: missing PR #2 rewrite terms: "
                    f"{', '.join(sorted(missing_draft_terms))}"
                )
        if not split_plan.is_file():
            errors.append(f"{path}: docs/PR2_SPLIT_PLAN.md is required for PR #2 split review plan")
        else:
            plan_text = split_plan.read_text(encoding="utf-8")
            plan_text_normalized = " ".join(plan_text.split())
            missing_plan_terms = [
                term
                for term in REQUIRED_PR2_SPLIT_PLAN_TERMS
                if " ".join(term.split()) not in plan_text_normalized
            ]
            if missing_plan_terms:
                errors.append(
                    f"{split_plan}: missing PR #2 split plan terms: "
                    f"{', '.join(sorted(missing_plan_terms))}"
                )
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
    if data["draft_pr"] == "PR #2":
        for doc_path in [
            repo_root / "docs" / "PR2_REWRITE_DRAFT.md",
            repo_root / "docs" / "PR2_SPLIT_PLAN.md",
        ]:
            if not doc_path.is_file():
                continue
            doc_text = doc_path.read_text(encoding="utf-8")
            missing_doc_slices = [
                slice_id for slice_id in EXPECTED_PR2_SLICE_ORDER if slice_id not in doc_text
            ]
            if missing_doc_slices:
                errors.append(f"{doc_path}: missing PR #2 slice ids: {', '.join(missing_doc_slices)}")
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
        if slice_id == "v61-ssd-moe-runtime-roadmap":
            command_text = "\n".join(str(command) for command in row.get("verification_commands", []))
            missing_terms = [term for term in REQUIRED_PR2_V61_VERIFICATION_TERMS if term not in command_text]
            if missing_terms:
                errors.append(
                    f"{prefix}: v61 verification commands missing replay summary terms: "
                    f"{', '.join(sorted(missing_terms))}"
                )
        if slice_id == "docs/v1-roadmap":
            command_text = "\n".join(str(command) for command in row.get("verification_commands", []))
            missing_terms = [
                term for term in REQUIRED_PR2_ROADMAP_VERIFICATION_TERMS if term not in command_text
            ]
            if missing_terms:
                errors.append(
                    f"{prefix}: roadmap verification commands must check v1 claim-boundary wording: "
                    f"{', '.join(sorted(missing_terms))}"
                )
        if slice_id == "docs-readme-pr2-cleanup":
            command_text = "\n".join(str(command) for command in row.get("verification_commands", []))
            missing_terms = [
                term for term in REQUIRED_PR2_DOCS_CLEANUP_VERIFICATION_TERMS if term not in command_text
            ]
            if missing_terms:
                errors.append(
                    f"{prefix}: docs cleanup verification commands must compare typed readiness to the PM ledger: "
                    f"{', '.join(sorted(missing_terms))}"
                )
        if slice_id in {"v53-system-a-b-g-h-measured", "v54-routehint-generation-contract"}:
            command_text = "\n".join(str(command) for command in row.get("verification_commands", []))
            missing_terms = [
                term for term in REQUIRED_PR2_LEAKAGE_VERIFICATION_TERMS if term not in command_text
            ]
            if missing_terms:
                errors.append(
                    f"{prefix}: leakage verification commands must compare the retrieval/model-visible contract to the PM ledger: "
                    f"{', '.join(sorted(missing_terms))}"
                )
        if slice_id in {"v53-query-instantiation-1000", "v53-system-a-b-g-h-measured"}:
            command_text = "\n".join(str(command) for command in row.get("verification_commands", []))
            missing_terms = [
                term for term in REQUIRED_PR2_V53_SOURCE_BENCHMARK_VERIFICATION_TERMS if term not in command_text
            ]
            if missing_terms:
                errors.append(
                    f"{prefix}: v53 verification commands must compare the source-bound benchmark to query, audit, A/B/G/H, and v1 exit ledgers: "
                    f"{', '.join(sorted(missing_terms))}"
                )
        if slice_id == "v53-public-repo-source-manifest":
            command_text = "\n".join(str(command) for command in row.get("verification_commands", []))
            missing_terms = [
                term for term in REQUIRED_PR2_V53_PUBLIC_SOURCE_MANIFEST_VERIFICATION_TERMS if term not in command_text
            ]
            if missing_terms:
                errors.append(
                    f"{prefix}: v53 public source manifest verification commands must compare summary to the pinned repo ledger: "
                    f"{', '.join(sorted(missing_terms))}"
                )
        if slice_id == "v54-routehint-generation-contract":
            command_text = "\n".join(str(command) for command in row.get("verification_commands", []))
            missing_terms = [
                term for term in REQUIRED_PR2_V54_GROUNDED_GENERATION_VERIFICATION_TERMS if term not in command_text
            ]
            if missing_terms:
                errors.append(
                    f"{prefix}: v54 verification commands must compare grounded generation contract to the 1000-row summary: "
                    f"{', '.join(sorted(missing_terms))}"
                )
        if slice_id == "v59-one-command-demo":
            command_text = "\n".join(str(command) for command in row.get("verification_commands", []))
            missing_terms = [
                term for term in REQUIRED_PR2_V59_PM_FOUNDATION_VERIFICATION_TERMS if term not in command_text
            ]
            if missing_terms:
                errors.append(
                    f"{prefix}: v59 verification commands must compare PM foundation replay summary and gate ledger: "
                    f"{', '.join(sorted(missing_terms))}"
                )
        if slice_id == "v58-blind-eval-contract":
            command_text = "\n".join(str(command) for command in row.get("verification_commands", []))
            missing_terms = [
                term for term in REQUIRED_PR2_V58_VERIFICATION_TERMS if term not in command_text
            ]
            if missing_terms:
                errors.append(
                    f"{prefix}: v58 verification commands must compare blind-eval blockers to readiness, artifact, and template ledgers: "
                    f"{', '.join(sorted(missing_terms))}"
                )
        if slice_id == "v52-baseline-registry-contract":
            command_text = "\n".join(str(command) for command in row.get("verification_commands", []))
            missing_terms = [
                term for term in REQUIRED_PR2_DE_VERIFICATION_TERMS if term not in command_text
            ]
            if missing_terms:
                errors.append(
                    f"{prefix}: D/E baseline verification commands must compare measured-registry exclusion and acceptance blocker ledgers: "
                    f"{', '.join(sorted(missing_terms))}"
                )
        if slice_id == "v56-ruler-longbench-expanded":
            command_text = "\n".join(str(command) for command in row.get("verification_commands", []))
            missing_terms = [
                term for term in REQUIRED_PR2_V56_VERIFICATION_TERMS if term not in command_text
            ]
            if missing_terms:
                errors.append(
                    f"{prefix}: v56 verification commands must compare replay contract to summary, seed blocker, and acceptance ledgers: "
                    f"{', '.join(sorted(missing_terms))}"
                )
        if slice_id == "v50-auditor-correctness":
            command_text = "\n".join(str(command) for command in row.get("verification_commands", []))
            missing_terms = [
                term for term in REQUIRED_PR2_V50_VERIFICATION_TERMS if term not in command_text
            ]
            if missing_terms:
                errors.append(
                    f"{prefix}: v50 verification commands must compare auditor contract to summary and decision artifacts: "
                    f"{', '.join(sorted(missing_terms))}"
                )
        if slice_id == "operator-review-return-workflow":
            command_text = "\n".join(str(command) for command in row.get("verification_commands", []))
            missing_terms = [
                term for term in REQUIRED_PR2_REVIEW_RETURN_VERIFICATION_TERMS if term not in command_text
            ]
            if missing_terms:
                errors.append(
                    f"{prefix}: review-return verification commands must compare workflow contract to v53, v58, v61af, and v61hv blocker summaries: "
                    f"{', '.join(sorted(missing_terms))}"
                )
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
    if set(policy.get("ambiguous_ready_flags", [])) != AMBIGUOUS_READY_FLAGS:
        errors.append(f"{path}: policy.ambiguous_ready_flags must be exactly {', '.join(sorted(AMBIGUOUS_READY_FLAGS))}")
    rows = data["rows"]
    if not isinstance(rows, list) or not rows:
        errors.append(f"{path}: rows must be a non-empty list")
        return errors
    scope_ids = [row.get("scope_id", "") for row in rows]
    if len(scope_ids) != len(set(scope_ids)):
        errors.append(f"{path}: duplicate scope_id values are forbidden")
    replacements = [row.get("replacement_flag", "") for row in rows]
    if replacements != EXPECTED_TYPED_READINESS_ORDER:
        errors.append(f"{path}: readiness row order must match the PM typed readiness contract")
    if len(replacements) != len(set(replacements)):
        errors.append(f"{path}: duplicate replacement_flag values are forbidden")
    replacement_set = set(replacements)
    expected_replacements = set(EXPECTED_TYPED_READINESS_ORDER)
    if replacement_set != expected_replacements:
        missing_replacements = expected_replacements - replacement_set
        extra_replacements = replacement_set - expected_replacements
        if missing_replacements:
            errors.append(f"{path}: missing replacement flags: {', '.join(sorted(missing_replacements))}")
        if extra_replacements:
            errors.append(f"{path}: unexpected replacement flags: {', '.join(sorted(extra_replacements))}")
    misleading_set = {row.get("misleading_ready_flag", "") for row in rows}
    if misleading_set != AMBIGUOUS_READY_FLAGS:
        errors.append(f"{path}: rows must cover exactly the ambiguous ready flags: {', '.join(sorted(AMBIGUOUS_READY_FLAGS))}")
    if "logical_100b_contract_fixture_ready" not in replacement_set:
        errors.append(f"{path}: logical_100b_contract_fixture_ready replacement row is required")
    if "v61i_logical_100b_contract_fixture_ready" not in replacement_set:
        errors.append(f"{path}: v61i_logical_100b_contract_fixture_ready replacement row is required")
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
        expected_row = EXPECTED_TYPED_READINESS_CONTRACTS.get(replacement)
        if expected_row is None:
            errors.append(f"{prefix}: unexpected replacement_flag={replacement}")
            expected_row = {}
        for field, expected in expected_row.items():
            if row.get(field) != expected:
                errors.append(f"{prefix}: {field} expected {expected}, got {row.get(field)}")
        if misleading not in AMBIGUOUS_READY_FLAGS:
            errors.append(f"{prefix}: misleading_ready_flag must be declared in policy.ambiguous_ready_flags")
        if misleading == replacement:
            errors.append(f"{prefix}: replacement_flag must differ from misleading_ready_flag")
        if replacement in AMBIGUOUS_READY_FLAGS:
            errors.append(f"{prefix}: replacement_flag cannot be an ambiguous ready flag")
        if row.get("ready_wording_policy") != "typed-ready-only":
            errors.append(f"{prefix}: ready_wording_policy must be typed-ready-only")
        if row.get("pm_ledger_required") is not True:
            errors.append(f"{prefix}: pm_ledger_required must be true")
        if not row.get("evidence_path"):
            errors.append(f"{prefix}: evidence_path must be non-empty")
        if row.get("real_model_execution_ready") is True:
            errors.append(f"{prefix}: current contract must not mark real_model_execution_ready=true")
        if row.get("release_ready") is True:
            errors.append(f"{prefix}: current contract must not mark release_ready=true")
        if replacement in {"logical_100b_contract_fixture_ready", "v61i_logical_100b_contract_fixture_ready"}:
            if row.get("contract_ready") is not True or row.get("fixture_execution_ready") is not True:
                errors.append(f"{prefix}: logical 100B rows must be contract+fixture ready")
            if row.get("real_model_execution_ready") is not False:
                errors.append(f"{prefix}: logical 100B rows must keep real_model_execution_ready=false")
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
            if ledger.get("pm_ledger_required") != "1":
                errors.append(f"{pm_ledger}: {replacement}.pm_ledger_required must be 1")
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
    extra = set(data) - REQUIRED_LEAKAGE_KEYS
    if extra:
        errors.append(f"{path}: unknown leakage keys: {', '.join(sorted(extra))}")
    if data["schema_version"] != "leakage_contract.v1":
        errors.append(f"{path}: unsupported schema_version={data['schema_version']}")
    policy = data["policy"]
    missing_policy = REQUIRED_LEAKAGE_POLICY_KEYS - set(policy)
    if missing_policy:
        errors.append(f"{path}: policy missing keys: {', '.join(sorted(missing_policy))}")
    extra_policy = set(policy) - REQUIRED_LEAKAGE_POLICY_KEYS
    if extra_policy:
        errors.append(f"{path}: policy unknown keys: {', '.join(sorted(extra_policy))}")
    if policy.get("allowed_surface") != "natural_language_question_plus_searchable_corpus":
        errors.append(f"{path}: allowed_surface must be natural_language_question_plus_searchable_corpus")
    if set(policy.get("allowed_model_visible_fields", [])) != ALLOWED_MODEL_VISIBLE_FIELDS:
        errors.append(f"{path}: policy.allowed_model_visible_fields must be exactly {', '.join(sorted(ALLOWED_MODEL_VISIBLE_FIELDS))}")
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
        extra_row = set(row) - REQUIRED_LEAKAGE_SURFACE_KEYS
        if extra_row:
            errors.append(f"{prefix}: unknown keys: {', '.join(sorted(extra_row))}")
        if row.get("evaluator_only_or_absent") is not True:
            errors.append(f"{prefix}: evaluator_only_or_absent must be true")
        if row.get("pm_ledger_required") is not True:
            errors.append(f"{prefix}: pm_ledger_required must be true")
        fields = row.get("field_names", [])
        if not isinstance(fields, list) or not fields:
            errors.append(f"{prefix}: field_names must be a non-empty list")
        declared_forbidden_fields.update(str(field) for field in fields)
    if declared_forbidden_fields != FORBIDDEN_MODEL_VISIBLE_FIELDS:
        missing_fields = FORBIDDEN_MODEL_VISIBLE_FIELDS - declared_forbidden_fields
        extra_fields = declared_forbidden_fields - FORBIDDEN_MODEL_VISIBLE_FIELDS
        if missing_fields:
            errors.append(f"{path}: missing forbidden field coverage: {', '.join(sorted(missing_fields))}")
        if extra_fields:
            errors.append(f"{path}: forbidden field coverage has undeclared verifier aliases: {', '.join(sorted(extra_fields))}")

    stages = data["stage_contracts"]
    if not isinstance(stages, list) or not stages:
        errors.append(f"{path}: stage_contracts must be a non-empty list")
        return errors
    stage_ids = [stage.get("stage_id", "") for stage in stages]
    if stage_ids != EXPECTED_LEAKAGE_STAGE_ORDER:
        errors.append(f"{path}: stage_contract order must match the PM leakage stage contract")
    if len(stage_ids) != len(set(stage_ids)):
        errors.append(f"{path}: duplicate stage_id values are forbidden")
    for index, stage in enumerate(stages, start=1):
        prefix = f"{path}: stage_contract[{index}]"
        missing_stage = REQUIRED_LEAKAGE_STAGE_KEYS - set(stage)
        if missing_stage:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_stage))}")
        extra_stage = set(stage) - REQUIRED_LEAKAGE_STAGE_KEYS - OPTIONAL_LEAKAGE_STAGE_KEYS
        if extra_stage:
            errors.append(f"{prefix}: unknown keys: {', '.join(sorted(extra_stage))}")
        stage_id = stage.get("stage_id", "")
        expected_stage = EXPECTED_LEAKAGE_STAGE_CONTRACTS.get(stage_id)
        if expected_stage is None:
            errors.append(f"{prefix}: unexpected stage_id={stage_id}")
            expected_stage = {}
        surface_kind = stage.get("surface_kind", "model_or_retriever")
        if surface_kind not in {"model_or_retriever", "fixture_or_evaluator_replay", "source_bound_non_model_adapter"}:
            errors.append(f"{prefix}: unsupported surface_kind={surface_kind}")
        if expected_stage.get("surface_kind") and surface_kind != expected_stage["surface_kind"]:
            errors.append(f"{prefix}: surface_kind expected {expected_stage['surface_kind']}, got {surface_kind}")
        if expected_stage.get("summary_path") and stage.get("summary_path") != expected_stage["summary_path"]:
            errors.append(f"{prefix}: summary_path expected {expected_stage['summary_path']}, got {stage.get('summary_path')}")
        allowed = stage.get("allowed_model_visible_fields", [])
        if not isinstance(allowed, list) or not allowed:
            errors.append(f"{prefix}: allowed_model_visible_fields must be non-empty")
        expected_allowed = expected_stage.get("allowed_model_visible_fields")
        if expected_allowed and allowed != expected_allowed:
            errors.append(
                f"{prefix}: allowed_model_visible_fields expected {','.join(expected_allowed)}, got {','.join(str(item) for item in allowed)}"
            )
        leaked = set(allowed) & FORBIDDEN_MODEL_VISIBLE_FIELDS
        if leaked:
            errors.append(f"{prefix}: allowed_model_visible_fields contains forbidden field(s): {', '.join(sorted(leaked))}")
        unknown_allowed = set(allowed) - ALLOWED_MODEL_VISIBLE_FIELDS - {"none"}
        if unknown_allowed:
            errors.append(f"{prefix}: allowed_model_visible_fields outside policy allowlist: {', '.join(sorted(unknown_allowed))}")
        if surface_kind == "model_or_retriever" and not set(allowed).issubset(ALLOWED_MODEL_VISIBLE_FIELDS):
            errors.append(f"{prefix}: model_or_retriever stages must use only policy.allowed_model_visible_fields")
        if surface_kind in {"fixture_or_evaluator_replay", "source_bound_non_model_adapter"} and allowed != ["none"]:
            errors.append(f"{prefix}: non-model-visible stages must use allowed_model_visible_fields=['none']")
        must_equal = stage.get("must_equal", {})
        if not isinstance(must_equal, dict) or not must_equal:
            errors.append(f"{prefix}: must_equal must be a non-empty object")
        expected_must_equal = expected_stage.get("must_equal")
        if expected_must_equal and must_equal != expected_must_equal:
            missing_must_equal = set(expected_must_equal) - set(must_equal)
            extra_must_equal = set(must_equal) - set(expected_must_equal)
            if missing_must_equal:
                errors.append(f"{prefix}: must_equal missing required fields: {', '.join(sorted(missing_must_equal))}")
            if extra_must_equal:
                errors.append(f"{prefix}: must_equal has unexpected fields: {', '.join(sorted(extra_must_equal))}")
            for field, expected in expected_must_equal.items():
                if field in must_equal and must_equal[field] != expected:
                    errors.append(f"{prefix}: must_equal.{field} expected {expected}, got {must_equal[field]}")
        expected_forbidden_summary = expected_stage.get("forbidden_field_summary")
        if expected_forbidden_summary:
            if stage.get("forbidden_field_summary") != expected_forbidden_summary:
                errors.append(
                    f"{prefix}: forbidden_field_summary expected {expected_forbidden_summary}, got {stage.get('forbidden_field_summary')}"
                )
        elif stage.get("forbidden_field_summary"):
            errors.append(f"{prefix}: forbidden_field_summary is not expected for this stage")
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
        extra_guards = set(by_guard) - set(guard_ids)
        if extra_guards:
            errors.append(f"{pm_ledger}: unexpected guard_id values: {', '.join(sorted(extra_guards))}")
        for surface in surfaces:
            guard_id = surface["guard_id"]
            ledger = by_guard.get(guard_id)
            if ledger is None:
                errors.append(f"{pm_ledger}: missing guard_id={guard_id}")
                continue
            ledger_fields = split_semicolon(ledger.get("field_names", "").replace(",", ";"))
            surface_fields = set(str(field) for field in surface.get("field_names", []))
            if ledger_fields != surface_fields:
                errors.append(f"{pm_ledger}: {guard_id}.field_names must match contract aliases: {', '.join(sorted(surface_fields))}")
            if ledger.get("status") != "pass":
                errors.append(f"{pm_ledger}: {guard_id}.status expected pass, got {ledger.get('status')}")
            if ledger.get("adapter_selection_blocked") != "1":
                errors.append(f"{pm_ledger}: {guard_id}.adapter_selection_blocked must be 1")
            if ledger.get("evaluator_only_or_absent") != "1":
                errors.append(f"{pm_ledger}: {guard_id}.evaluator_only_or_absent must be 1")
            if ledger.get("pm_ledger_required") != "1":
                errors.append(f"{pm_ledger}: {guard_id}.pm_ledger_required must be 1")
            if ledger.get("allowed_adapter_surface") != policy["allowed_surface"]:
                errors.append(f"{pm_ledger}: {guard_id}.allowed_adapter_surface mismatch")
            if ledger.get("selection_allowed_fields") != "sanitized_question":
                errors.append(f"{pm_ledger}: {guard_id}.selection_allowed_fields must be sanitized_question")
            if ledger.get("direct_query_source_binding_forbidden") != "1":
                errors.append(f"{pm_ledger}: {guard_id}.direct_query_source_binding_forbidden must be 1")
    return errors


def split_semicolon(value: str) -> set[str]:
    return {part.strip() for part in value.split(";") if part.strip()}


def validation_command_script(command: str) -> Path | None:
    for token in command.split():
        if token.endswith(".sh"):
            return Path(token)
    return None


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
    ledgers = data.get("required_pm_ledgers", [])
    if not isinstance(ledgers, list) or len(ledgers) != len(EXPECTED_DE_PM_LEDGERS):
        errors.append(f"{path}: required_pm_ledgers must list measured-registry and acceptance ledgers")
    else:
        normalized_ledgers = []
        for index, row in enumerate(ledgers, start=1):
            missing_ledger = REQUIRED_BASELINE_LEDGER_KEYS - set(row)
            if missing_ledger:
                errors.append(f"{path}: required_pm_ledger[{index}] missing keys: {', '.join(sorted(missing_ledger))}")
            normalized_ledgers.append(
                {
                    "ledger_id": row.get("ledger_id", ""),
                    "path": row.get("path", ""),
                    "required_for": row.get("required_for", ""),
                }
            )
        if normalized_ledgers != EXPECTED_DE_PM_LEDGERS:
            errors.append(f"{path}: required_pm_ledgers must pin the D/E measured-registry and acceptance blocker ledgers")
    if measured_registry_ledger is None:
        measured_registry_ledger = DEFAULT_DE_MEASURED_REGISTRY_LEDGER
    if acceptance_ledger is None:
        acceptance_ledger = DEFAULT_DE_ACCEPTANCE_LEDGER
    systems = data["systems"]
    if not isinstance(systems, list) or len(systems) != 2:
        errors.append(f"{path}: systems must contain D and E")
        return errors
    by_system = {row.get("system_id", ""): row for row in systems}
    if set(by_system) != {"D", "E"}:
        errors.append(f"{path}: systems must be exactly D and E")
    expected_ranges = {"D": (25, 40, "30b-open-weight-llm-rag"), "E": (65, 80, "70b-open-weight-llm-rag")}
    expected_envs = {"D": "V52D_30B_LLM_RAG_EVIDENCE_DIR", "E": "V52D_70B_LLM_RAG_EVIDENCE_DIR"}
    expected_acceptance_test = (
        "V52D_30B_LLM_RAG_EVIDENCE_DIR=<D_DIR> "
        "V52D_70B_LLM_RAG_EVIDENCE_DIR=<E_DIR> "
        "./experiments/test_v52d_30b70b_llm_rag_evidence_intake.sh"
    )
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
        if row.get("evidence_env") != expected_envs.get(system_id):
            errors.append(f"{prefix}: evidence_env must be {expected_envs.get(system_id)}")
        if row.get("acceptance_test") != expected_acceptance_test:
            errors.append(f"{prefix}: acceptance_test must pin both D/E evidence envs and the v52d evidence intake")

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
        expected_kind = EXPECTED_DE_REQUIRED_ARTIFACT_KINDS.get(row.get("artifact_id", ""))
        if expected_kind is not None and row.get("artifact_kind") != expected_kind:
            errors.append(f"{prefix}: artifact_kind must be {expected_kind}")
        artifact_id = row.get("artifact_id", "")
        expected_columns = EXPECTED_DE_REQUIRED_ARTIFACT_COLUMNS.get(artifact_id)
        required_columns = row.get("required_columns", [])
        if not isinstance(required_columns, list) or not required_columns:
            errors.append(f"{prefix}: required_columns must be a non-empty list")
        elif expected_columns is not None and set(required_columns) != expected_columns:
            errors.append(f"{prefix}: required_columns must be exactly {', '.join(sorted(expected_columns))}")

    if measured_registry_ledger is not None:
        if not measured_registry_ledger.exists():
            errors.append(f"{measured_registry_ledger}: required D/E measured-registry exclusion ledger is missing")
        else:
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
                if row.get("required_real_evidence_field_count") != str(len(REQUIRED_DE_REAL_EVIDENCE_FIELDS)):
                    errors.append(f"{measured_registry_ledger}: {system_id}.required_real_evidence_field_count must be {len(REQUIRED_DE_REAL_EVIDENCE_FIELDS)}")
                if row.get("missing_real_evidence_field_count") != str(len(REQUIRED_DE_REAL_EVIDENCE_FIELDS)):
                    errors.append(f"{measured_registry_ledger}: {system_id}.missing_real_evidence_field_count must be {len(REQUIRED_DE_REAL_EVIDENCE_FIELDS)} while blocked")
                if row.get("all_required_real_evidence_missing") != "1":
                    errors.append(f"{measured_registry_ledger}: {system_id}.all_required_real_evidence_missing must be 1 while blocked")
                if row.get("raw_answer_citation_output_required") != "1":
                    errors.append(f"{measured_registry_ledger}: {system_id}.raw_answer_citation_output_required must be 1")
                if row.get("answer_citation_raw_output_rows") != "0":
                    errors.append(f"{measured_registry_ledger}: {system_id}.answer_citation_raw_output_rows must be 0 while blocked")
                if row.get("resource_row_required") != "1" or row.get("evaluator_version_required") != "1" or row.get("same_query_set_required") != "1":
                    errors.append(f"{measured_registry_ledger}: {system_id}.resource/evaluator/same-query requirements must be 1")
                if row.get("acceptance_evidence_rows") != "3" or row.get("acceptance_ready_rows") != "0":
                    errors.append(f"{measured_registry_ledger}: {system_id}.acceptance evidence must have three blocked rows and zero ready rows")
                if row.get("status") != "blocked":
                    errors.append(f"{measured_registry_ledger}: {system_id}.status must be blocked")

    if acceptance_ledger is not None:
        if not acceptance_ledger.exists():
            errors.append(f"{acceptance_ledger}: required D/E acceptance blocker ledger is missing")
        else:
            acceptance_rows = read_csv_rows(acceptance_ledger)
            by_system = {"D": [], "E": []}
            for row in acceptance_rows:
                system_id = row.get("system_id", "")
                if system_id in by_system:
                    by_system[system_id].append(row)
            for system_id, rows in by_system.items():
                if len(rows) != 3:
                    errors.append(f"{acceptance_ledger}: expected three acceptance rows for {system_id}")
                artifact_ids = {row.get("artifact_id", "") for row in rows}
                expected_artifacts = {
                    f"{system_id.lower()}-model-identity",
                    f"{system_id.lower()}-answer-citation-raw-output",
                    f"{system_id.lower()}-resource-evaluator-manifest",
                }
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
                    observed_signal = row.get("observed_signal", "")
                    for forbidden_ready in [
                        "baseline_ready=1",
                        "supplied_evidence_ready=1",
                        "v52_absorb_ready=1",
                        "v52_ready=1",
                    ]:
                        if forbidden_ready in observed_signal:
                            errors.append(
                                f"{acceptance_ledger}: {system_id}.{row.get('artifact_id')} observed_signal must not promote {forbidden_ready}"
                            )
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

    artifacts = data["required_artifacts"]
    if not isinstance(artifacts, list) or not artifacts:
        errors.append(f"{path}: required_artifacts must be a non-empty list")
        return errors
    artifact_ids = [row.get("artifact_id", "") for row in artifacts]
    if artifact_ids != EXPECTED_V52_C_ARTIFACT_IDS:
        errors.append(f"{path}: required_artifacts order must match the v52 C packet contract")
    if len(artifact_ids) != len(set(artifact_ids)):
        errors.append(f"{path}: duplicate required_artifacts are forbidden")
    for index, row in enumerate(artifacts, start=1):
        prefix = f"{path}: required_artifact[{index}]"
        missing_artifact = REQUIRED_V52_ARTIFACT_KEYS - set(row)
        if missing_artifact:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_artifact))}")
        artifact_id = row.get("artifact_id", "")
        if row.get("artifact_kind") != "csv":
            errors.append(f"{prefix}: artifact_kind must be csv")
        if row.get("required_for_c_packet") is not True:
            errors.append(f"{prefix}: required_for_c_packet must be true")
        required_columns = row.get("required_columns", [])
        expected_columns = EXPECTED_V52_C_ARTIFACT_COLUMNS.get(artifact_id)
        if not isinstance(required_columns, list) or not required_columns:
            errors.append(f"{prefix}: required_columns must be a non-empty list")
        elif expected_columns is not None and required_columns != expected_columns:
            errors.append(f"{prefix}: required_columns must exactly match the v52 C packet header")
        min_rows = row.get("min_rows")
        expected_min_rows = EXPECTED_V52_C_MIN_ROWS.get(artifact_id)
        if not isinstance(min_rows, int) or min_rows < 1:
            errors.append(f"{prefix}: min_rows must be a positive integer")
        elif expected_min_rows is not None and min_rows != expected_min_rows:
            errors.append(f"{prefix}: min_rows expected {expected_min_rows}, got {min_rows}")
        artifact_path = Path(row.get("path", ""))
        if not artifact_path.is_file() or artifact_path.stat().st_size == 0:
            errors.append(f"{prefix}: missing or empty artifact path {artifact_path}")
            continue
        with artifact_path.open(newline="", encoding="utf-8") as handle:
            reader = csv.DictReader(handle)
            fieldnames = reader.fieldnames or []
            if required_columns and fieldnames != required_columns:
                errors.append(f"{artifact_path}: header must match required_columns for {artifact_id}")
            row_count = sum(1 for _ in reader)
        if isinstance(min_rows, int) and row_count < min_rows:
            errors.append(f"{artifact_path}: expected at least {min_rows} data rows, got {row_count}")

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
    missing_policy = REQUIRED_V50_POLICY_KEYS - set(policy)
    if missing_policy:
        errors.append(f"{path}: policy missing keys: {', '.join(sorted(missing_policy))}")
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

    replay = data["replay_commands"]
    missing_replay = REQUIRED_V50_REPLAY_COMMAND_KEYS - set(replay)
    if missing_replay:
        errors.append(f"{path}: replay_commands missing keys: {', '.join(sorted(missing_replay))}")
    else:
        for field in ["runner", "smoke_test"]:
            command_path = Path(replay[field])
            if not command_path.is_file():
                errors.append(f"{path}: replay_commands.{field} missing file: {command_path}")
            elif (command_path.stat().st_mode & 0o111) == 0:
                errors.append(f"{path}: replay_commands.{field} must be executable: {command_path}")
        if not replay["artifact_verifier"].startswith("tools/verify_artifact.py v50-auditor-correctness "):
            errors.append(f"{path}: replay_commands.artifact_verifier must call v50-auditor-correctness")

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
    sha_manifest_path: Path | None = None
    for index, row in enumerate(artifacts, start=1):
        prefix = f"{path}: required_artifact[{index}]"
        missing_row = REQUIRED_V50_ARTIFACT_KEYS - set(row)
        if missing_row:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_row))}")
        artifact_id = row.get("artifact_id", "")
        if row.get("artifact_kind") != "csv":
            errors.append(f"{prefix}: artifact_kind must be csv")
        expected_columns = EXPECTED_V50_ARTIFACT_COLUMNS.get(artifact_id)
        required_columns = row.get("required_columns", [])
        if not isinstance(required_columns, list) or not required_columns:
            errors.append(f"{prefix}: required_columns must be a non-empty list")
        elif expected_columns is not None and required_columns != expected_columns:
            errors.append(f"{prefix}: required_columns must exactly match the v50 runner header")
        min_rows = row.get("min_rows")
        expected_min_rows = EXPECTED_V50_MIN_ROWS.get(artifact_id)
        if not isinstance(min_rows, int) or min_rows < 1:
            errors.append(f"{prefix}: min_rows must be a positive integer")
        elif expected_min_rows is not None and min_rows != expected_min_rows:
            errors.append(f"{prefix}: min_rows expected {expected_min_rows}, got {min_rows}")
        if not isinstance(row.get("sha256_manifest_required"), bool):
            errors.append(f"{prefix}: sha256_manifest_required must be boolean")
        if row.get("required_for_merge") is not True:
            errors.append(f"{prefix}: required_for_merge must be true")
        artifact_path = Path(row.get("path", ""))
        if not artifact_path.is_file() or artifact_path.stat().st_size == 0:
            missing_required_artifacts.append(row.get("artifact_id", ""))
        else:
            if artifact_id == "sha256-manifest":
                sha_manifest_path = artifact_path
            with artifact_path.open(newline="", encoding="utf-8") as handle:
                reader = csv.DictReader(handle)
                fieldnames = reader.fieldnames or []
                if required_columns and fieldnames != required_columns:
                    errors.append(f"{artifact_path}: header must match required_columns for {artifact_id}")
                row_count = sum(1 for _ in reader)
            if isinstance(min_rows, int) and row_count < min_rows:
                errors.append(f"{artifact_path}: expected at least {min_rows} data rows, got {row_count}")
    present_required_artifacts = len(artifacts) - len(missing_required_artifacts)
    if policy.get("required_artifact_count") != len(artifacts):
        errors.append(f"{path}: policy.required_artifact_count expected {len(artifacts)}, got {policy.get('required_artifact_count')}")
    if policy.get("present_required_artifact_count") != present_required_artifacts:
        errors.append(
            f"{path}: policy.present_required_artifact_count expected {present_required_artifacts}, "
            f"got {policy.get('present_required_artifact_count')}"
        )
    if policy.get("missing_required_artifact_count") != len(missing_required_artifacts):
        errors.append(
            f"{path}: policy.missing_required_artifact_count expected {len(missing_required_artifacts)}, "
            f"got {policy.get('missing_required_artifact_count')}"
        )
    if policy.get("missing_required_artifact_ids") != missing_required_artifacts:
        errors.append(
            f"{path}: policy.missing_required_artifact_ids expected {missing_required_artifacts}, "
            f"got {policy.get('missing_required_artifact_ids')}"
        )
    if not missing_required_artifacts:
        errors.append(f"{path}: contract says artifact_replay_ready=false, but all required artifacts are present; update the contract")
    if sha_manifest_path is not None:
        manifest_rows = read_csv_rows(sha_manifest_path)
        by_manifest_path = {row.get("path", ""): row for row in manifest_rows}
        artifact_base = sha_manifest_path.parent
        for row in artifacts:
            if row.get("artifact_id") == "sha256-manifest" or row.get("sha256_manifest_required") is not True:
                continue
            artifact_path = Path(row.get("path", ""))
            try:
                manifest_key = str(artifact_path.relative_to(artifact_base))
            except ValueError:
                manifest_key = artifact_path.name
            manifest_row = by_manifest_path.get(manifest_key)
            if manifest_row is None:
                errors.append(f"{sha_manifest_path}: missing required artifact path {manifest_key}")
                continue
            digest = manifest_row.get("sha256", "")
            if not digest.startswith("sha256:") or len(digest) != 71:
                errors.append(f"{sha_manifest_path}: invalid sha256 digest for {manifest_key}")
            if artifact_path.is_file() and sha256(artifact_path) != digest:
                errors.append(f"{sha_manifest_path}: sha mismatch for {manifest_key}")

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


def _repo_relative_path(value: str) -> str:
    path = Path(value)
    if path.is_absolute():
        try:
            return str(path.relative_to(Path.cwd()))
        except ValueError:
            return value
    return value


def verify_v56_replay_contract(
    path: Path,
    summary_path: Path | None = None,
    blocker_ledger: Path | None = None,
    artifact_ledger: Path | None = None,
) -> list[str]:
    errors: list[str] = []
    data = json.loads(path.read_text(encoding="utf-8"))
    missing = REQUIRED_V56_REPLAY_KEYS - set(data)
    if missing:
        errors.append(f"{path}: missing v56 replay keys: {', '.join(sorted(missing))}")
        return errors
    if data["schema_version"] != "v56_replay_contract.v1":
        errors.append(f"{path}: unsupported schema_version={data['schema_version']}")

    policy = data["policy"]
    missing_policy = REQUIRED_V56_REPLAY_POLICY_KEYS - set(policy)
    if missing_policy:
        errors.append(f"{path}: policy missing keys: {', '.join(sorted(missing_policy))}")
    expected_policy = {
        "replay_artifact_ready": False,
        "v56_contract_ready": False,
        "v56b_scale_ready": False,
        "real_external_benchmark_verified": False,
        "real_release_package_ready": False,
        "required_replay_artifact_count": 4,
        "ready_replay_artifact_count": 0,
        "blocked_replay_artifact_count": 4,
    }
    for field, expected in expected_policy.items():
        if policy.get(field) != expected:
            errors.append(f"{path}: policy.{field} expected {expected}, got {policy.get(field)}")

    artifacts = data["replay_artifacts"]
    if not isinstance(artifacts, list) or not artifacts:
        errors.append(f"{path}: replay_artifacts must be a non-empty list")
        return errors
    artifact_ids = [row.get("artifact_id", "") for row in artifacts]
    if artifact_ids != EXPECTED_V56_REPLAY_ARTIFACT_IDS:
        errors.append(f"{path}: replay_artifacts order must match v56 replay artifact blockers")
    for index, row in enumerate(artifacts, start=1):
        prefix = f"{path}: replay_artifact[{index}]"
        missing_row = REQUIRED_V56_REPLAY_ARTIFACT_KEYS - set(row)
        if missing_row:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_row))}")
        artifact_id = row.get("artifact_id", "")
        expected_kind = EXPECTED_V56_REPLAY_ARTIFACT_KINDS.get(artifact_id)
        if expected_kind is not None and row.get("artifact_kind") != expected_kind:
            errors.append(f"{prefix}: artifact_kind expected {expected_kind}, got {row.get('artifact_kind')}")
        if not row.get("artifact_path_or_env") or not row.get("validation_command") or not row.get("claim_boundary"):
            errors.append(f"{prefix}: artifact_path_or_env, validation_command, and claim_boundary must be non-empty")

    seed = data["seed_dependency"]
    missing_seed_keys = REQUIRED_V56_SEED_DEPENDENCY_KEYS - set(seed)
    if missing_seed_keys:
        errors.append(f"{path}: seed_dependency missing keys: {', '.join(sorted(missing_seed_keys))}")
    expected_seed = {
        "blocker_ready": True,
        "required_seed_artifact_count": 20,
        "missing_seed_artifact_count": 20,
        "missing_v49_seed_artifact_count": 9,
        "missing_v45_seed_artifact_count": 11,
        "implicit_seed_rebuild_allowed": False,
        "seed_rebuild_approval_required": True,
        "network_or_download_approval_required": True,
    }
    for field, expected in expected_seed.items():
        if seed.get(field) != expected:
            errors.append(f"{path}: seed_dependency.{field} expected {expected}, got {seed.get(field)}")
    if seed.get("missing_seed_artifact_paths") != EXPECTED_V56_MISSING_SEED_PATHS:
        errors.append(f"{path}: seed_dependency.missing_seed_artifact_paths must match the fail-closed v56 seed list")

    if summary_path is not None:
        summary = read_first_csv(summary_path)
        expected_summary = {
            "v56_ruler_longbench_expanded_contract_ready": "0",
            "v56_ruler_longbench_expanded_ready": "0",
            "v56_seed_dependency_blocker_ready": "1",
            "missing_seed_artifact_rows": "20",
            "missing_v49_seed_artifact_rows": "9",
            "missing_v45_seed_artifact_rows": "11",
            "implicit_seed_rebuild_allowed": "0",
            "seed_rebuild_approval_required": "1",
            "network_or_download_approval_required": "1",
            "real_external_benchmark_verified": "0",
            "real_release_package_ready": "0",
        }
        for field, expected in expected_summary.items():
            if summary.get(field) != expected:
                errors.append(f"{summary_path}: {field} expected {expected}, got {summary.get(field)}")

    if blocker_ledger is not None:
        rows = read_csv_rows(blocker_ledger)
        if len(rows) != len(EXPECTED_V56_MISSING_SEED_PATHS):
            errors.append(f"{blocker_ledger}: expected {len(EXPECTED_V56_MISSING_SEED_PATHS)} missing seed rows, got {len(rows)}")
        observed_paths = [_repo_relative_path(row.get("missing_seed_artifact", "")) for row in rows]
        if observed_paths != EXPECTED_V56_MISSING_SEED_PATHS:
            errors.append(f"{blocker_ledger}: missing_seed_artifact paths must match the v56 replay contract")
        for row_index, row in enumerate(rows, start=2):
            for field, expected in {
                "implicit_rebuild_allowed": "0",
                "approval_required": "1",
                "fixture_allowed": "0",
                "tests_only_merge_condition": "0",
                "claim_boundary_status": "blocked-until-seed-artifact-present",
            }.items():
                if row.get(field) != expected:
                    errors.append(f"{blocker_ledger}:{row_index}: {field} expected {expected}, got {row.get(field)}")

    if artifact_ledger is not None:
        rows = read_csv_rows(artifact_ledger)
        by_artifact = {row.get("artifact_id", ""): row for row in rows}
        if list(by_artifact) != EXPECTED_V56_REPLAY_ARTIFACT_IDS:
            errors.append(f"{artifact_ledger}: artifact_id order must match v56 replay contract")
        for artifact_id in EXPECTED_V56_REPLAY_ARTIFACT_IDS:
            row = by_artifact.get(artifact_id)
            if row is None:
                errors.append(f"{artifact_ledger}: missing artifact_id={artifact_id}")
                continue
            for field, expected in {
                "claim_boundary_status": "pass",
                "output_artifact_replay_status": "blocked",
                "blocker_false_positive_status": "pass",
                "approval_required": "1",
                "fixture_allowed": "0",
                "tests_only_merge_condition": "0",
                "acceptance_ready": "0",
                "acceptance_status": "blocked",
            }.items():
                if row.get(field) != expected:
                    errors.append(f"{artifact_ledger}: {artifact_id}.{field} expected {expected}, got {row.get(field)}")
    return errors


def verify_v54_grounded_generation(
    path: Path,
    summary_path: Path | None = None,
) -> list[str]:
    errors: list[str] = []
    data = json.loads(path.read_text(encoding="utf-8"))
    missing = REQUIRED_V54_GROUNDED_GENERATION_KEYS - set(data)
    if missing:
        errors.append(f"{path}: missing v54 grounded generation keys: {', '.join(sorted(missing))}")
        return errors
    if data["schema_version"] != "v54_grounded_generation.v1":
        errors.append(f"{path}: unsupported schema_version={data['schema_version']}")
    policy = data["policy"]
    if policy.get("generation_contract_ready") is not True:
        errors.append(f"{path}: generation_contract_ready must be true")
    for field in [
        "real_model_generation_ready",
        "human_review_ready",
        "public_comparison_claim_ready",
        "release_ready",
    ]:
        if policy.get(field) is not False:
            errors.append(f"{path}: {field} must be false")
    if policy.get("raw_prompt_context_allowed") is not False:
        errors.append(f"{path}: raw_prompt_context_allowed must be false")
    if policy.get("allowed_model_visible_fields") != ["sanitized_question", "opaque_routehint"]:
        errors.append(f"{path}: allowed_model_visible_fields must be sanitized_question, opaque_routehint")

    artifacts = data["required_artifacts"]
    if not isinstance(artifacts, list) or not artifacts:
        errors.append(f"{path}: required_artifacts must be a non-empty list")
        return errors
    artifact_ids = [row.get("artifact_id", "") for row in artifacts]
    if artifact_ids != EXPECTED_V54_ARTIFACT_IDS:
        errors.append(f"{path}: required_artifacts order must match the v54 grounded generation contract")
    if len(artifact_ids) != len(set(artifact_ids)):
        errors.append(f"{path}: duplicate required_artifacts are forbidden")

    artifact_rows_by_id: dict[str, list[dict[str, str]]] = {}
    for index, row in enumerate(artifacts, start=1):
        prefix = f"{path}: required_artifact[{index}]"
        missing_artifact = REQUIRED_V54_ARTIFACT_KEYS - set(row)
        if missing_artifact:
            errors.append(f"{prefix}: missing keys: {', '.join(sorted(missing_artifact))}")
        artifact_id = row.get("artifact_id", "")
        artifact_kind = row.get("artifact_kind", "")
        if artifact_kind not in {"csv", "text"}:
            errors.append(f"{prefix}: artifact_kind must be csv or text")
        required_columns = row.get("required_columns", [])
        expected_columns = EXPECTED_V54_ARTIFACT_COLUMNS.get(artifact_id)
        if not isinstance(required_columns, list):
            errors.append(f"{prefix}: required_columns must be a list")
        elif expected_columns is not None and required_columns != expected_columns:
            errors.append(f"{prefix}: required_columns must exactly match the v54 artifact header")
        min_rows = row.get("min_rows")
        expected_min_rows = EXPECTED_V54_MIN_ROWS.get(artifact_id)
        if not isinstance(min_rows, int) or min_rows < 1:
            errors.append(f"{prefix}: min_rows must be a positive integer")
        elif expected_min_rows is not None and min_rows != expected_min_rows:
            errors.append(f"{prefix}: min_rows expected {expected_min_rows}, got {min_rows}")
        if row.get("pm_recommended_output") is not True and artifact_id in {
            "answer-rows",
            "citation-rows",
            "unsupported-claim-rows",
            "abstain-rows",
            "generator-resource-rows",
            "wrong-answer-guard-rows",
            "sha256sums",
        }:
            errors.append(f"{prefix}: PM recommended v54 outputs must set pm_recommended_output=true")
        if row.get("raw_prompt_context_forbidden") is not True:
            errors.append(f"{prefix}: raw_prompt_context_forbidden must be true")
        if row.get("model_visible_leakage_forbidden") is not True:
            errors.append(f"{prefix}: model_visible_leakage_forbidden must be true")
        artifact_path = Path(row.get("path", ""))
        if not artifact_path.is_file() or artifact_path.stat().st_size == 0:
            errors.append(f"{prefix}: missing or empty artifact path {artifact_path}")
            continue
        if artifact_kind == "csv":
            with artifact_path.open(newline="", encoding="utf-8") as handle:
                reader = csv.DictReader(handle)
                fieldnames = reader.fieldnames or []
                if required_columns and fieldnames != required_columns:
                    errors.append(f"{artifact_path}: header must match required_columns for {artifact_id}")
                artifact_rows = list(reader)
                artifact_rows_by_id[artifact_id] = artifact_rows
                row_count = len(artifact_rows)
            if isinstance(min_rows, int) and row_count < min_rows:
                errors.append(f"{artifact_path}: expected at least {min_rows} data rows, got {row_count}")
        elif artifact_kind == "text":
            line_count = len([line for line in artifact_path.read_text(encoding="utf-8").splitlines() if line.strip()])
            if isinstance(min_rows, int) and line_count < min_rows:
                errors.append(f"{artifact_path}: expected at least {min_rows} non-empty lines, got {line_count}")

    def require_all(artifact_id: str, field: str, expected: str) -> None:
        rows = artifact_rows_by_id.get(artifact_id, [])
        bad_rows = sum(1 for artifact_row in rows if artifact_row.get(field) != expected)
        if bad_rows:
            errors.append(f"{path}: {artifact_id}.{field} expected {expected} for all rows; bad_rows={bad_rows}")

    for artifact_id in ["generator-input-rows", "compact-routehint-rows"]:
        require_all(artifact_id, "model_visible_input_fields", "sanitized_question,opaque_routehint")
        require_all(
            artifact_id,
            "compact_routehint_allowed_key_set",
            "input_surface,opaque_routehint,question,raw_context_appended,source_locator_absent",
        )
        require_all(artifact_id, "compact_routehint_forbidden_alias_used", "0")
        for field in [
            "model_visible_query_id_used",
            "model_visible_source_span_id_used",
            "model_visible_source_path_used",
            "model_visible_source_line_used",
            "model_visible_source_file_hash_used",
            "model_visible_expected_behavior_used",
            "model_visible_expected_label_used",
        ]:
            require_all(artifact_id, field, "0")
    for field in ["compact_routehint_contains_source_locator", "raw_prompt_context_appended", "raw_prompt_context_bytes", "retrieved_text_in_prompt", "attention_blocks", "transformer_blocks", "real_model_generation_ready"]:
        require_all("generator-input-rows", field, "0")
    require_all("generator-input-rows", "deterministic_source_span_generation_fixture", "1")
    for field in ["contains_source_locator", "raw_context_appended"]:
        require_all("compact-routehint-rows", field, "0")
    for field in ["external_model_used", "external_network_used", "attention_blocks", "transformer_blocks", "raw_prompt_context_bytes"]:
        require_all("generator-resource-rows", field, "0")
    require_all("generator-resource-rows", "generated_from_source_span", "1")
    require_all("answer-rows", "wrong_answer", "0")
    require_all("wrong-answer-guard-rows", "wrong_answer", "0")
    require_all("wrong-answer-guard-rows", "guard_status", "pass")

    if summary_path is not None:
        summary = read_first_csv(summary_path)
        expected_summary = {
            "v54c_complete_source_grounded_generation_1000_ready": "1",
            "generation_rows": "1000",
            "answer_rows": "1000",
            "citation_rows": "1000",
            "unsupported_claim_rows": "160",
            "abstain_rows": "160",
            "generator_resource_rows": "1000",
            "wrong_answer_guard_rows": "1000",
            "grounded_generation_output_contract_pm_required_rows": "7",
            "grounded_generation_output_contract_pm_required_ready_rows": "7",
            "sha256sums_pm_recommended_csv_ready": "1",
            "v53ap_answer_eval_separate_rows": "1000",
            "v53ap_citation_eval_separate_rows": "1000",
            "v53ap_resource_eval_separate_rows": "1000",
            "raw_prompt_context_appended_rows": "0",
            "model_visible_leakage_guard_ready": "1",
            "model_visible_forbidden_field_used_rows": "0",
            "model_visible_source_locator_rows": "0",
            "compact_routehint_forbidden_alias_rows": "0",
            "deterministic_source_span_generation_fixture_ready": "1",
            "real_model_generation_ready": "0",
            "human_review_ready": "0",
            "real_release_package_ready": "0",
        }
        for field, expected in expected_summary.items():
            if summary.get(field) != expected:
                errors.append(f"{summary_path}: {field} expected {expected}, got {summary.get(field)}")
    return errors


def verify_v59_pm_foundation_demo(path: Path, gate_ledger: Path | None = None) -> list[str]:
    errors: list[str] = []
    summary = read_first_csv(path)
    for field, expected in EXPECTED_V59_PM_FOUNDATION_SUMMARY.items():
        if summary.get(field) != expected:
            errors.append(f"{path}: {field} expected {expected}, got {summary.get(field)}")

    if gate_ledger is not None:
        rows = read_csv_rows(gate_ledger)
        by_gate = {row.get("gate", ""): row for row in rows}
        for gate, expected_status in EXPECTED_V59_PM_FOUNDATION_GATE_STATUS.items():
            row = by_gate.get(gate)
            if row is None:
                errors.append(f"{gate_ledger}: missing gate={gate}")
                continue
            if row.get("status") != expected_status:
                errors.append(
                    f"{gate_ledger}: {gate}.status expected {expected_status}, got {row.get('status')}"
                )
            if not row.get("reason"):
                errors.append(f"{gate_ledger}: {gate}.reason must be non-empty")
    return errors


def verify_v53_public_source_manifest(path: Path, repo_ledger: Path | None = None) -> list[str]:
    errors: list[str] = []
    summary = read_first_csv(path)
    for field, expected in EXPECTED_V53_PUBLIC_SOURCE_MANIFEST_SUMMARY.items():
        if summary.get(field) != expected:
            errors.append(f"{path}: {field} expected {expected}, got {summary.get(field)}")

    if repo_ledger is not None:
        rows = read_csv_rows(repo_ledger)
        if len(rows) != len(EXPECTED_V53_PUBLIC_REPOS):
            errors.append(
                f"{repo_ledger}: expected {len(EXPECTED_V53_PUBLIC_REPOS)} repo rows, got {len(rows)}"
            )
        owner_repos = [row.get("owner_repo", "") for row in rows]
        if owner_repos != EXPECTED_V53_PUBLIC_REPOS:
            errors.append(f"{repo_ledger}: owner_repo order must match the pinned v53 public source manifest")
        seen_slots: set[str] = set()
        for row_index, row in enumerate(rows, start=2):
            prefix = f"{repo_ledger}:{row_index}"
            slot = row.get("repo_slot", "")
            if slot in seen_slots:
                errors.append(f"{prefix}: duplicate repo_slot={slot}")
            seen_slots.add(slot)
            sha = row.get("head_sha", "")
            if len(sha) != 40 or any(char not in "0123456789abcdef" for char in sha):
                errors.append(f"{prefix}: head_sha must be a pinned 40-character lowercase hex commit")
            for field in ["tree_blob_rows", "included_file_rows", "query_eligible_file_rows"]:
                try:
                    value = int(row.get(field, ""))
                except ValueError:
                    errors.append(f"{prefix}: {field} must be an integer")
                    continue
                if value <= 0:
                    errors.append(f"{prefix}: {field} must be positive")
            if row.get("tree_truncated") != "0":
                errors.append(f"{prefix}: tree_truncated must be 0")
            if row.get("complete_source_tree_manifest_ready") != "1":
                errors.append(f"{prefix}: complete_source_tree_manifest_ready must be 1")
    return errors


def verify_roadmap_doc(path: Path) -> list[str]:
    errors: list[str] = []
    text = path.read_text(encoding="utf-8")
    normalized_text = " ".join(text.split())
    missing_terms = [
        term for term in REQUIRED_V1_ROADMAP_TERMS if " ".join(term.split()) not in normalized_text
    ]
    if missing_terms:
        errors.append(f"{path}: roadmap missing required claim-boundary terms: {', '.join(sorted(missing_terms))}")
    if "general LLM replacement" not in text or "Transformer replacement" not in text:
        errors.append(f"{path}: roadmap must keep replacement claims explicitly blocked")
    if "release_ready_claim=0" not in text and "real_release_package_ready" not in text:
        errors.append(f"{path}: roadmap must keep release readiness wording explicitly blocked")
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
    for summary_id, summary_path in DEFAULT_V53_SUMMARY_PATHS.items():
        if summary_id in summaries:
            continue
        if summary_path.is_file() and summary_path.stat().st_size > 0:
            summaries[summary_id] = read_first_csv(summary_path)

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
        if not isinstance(checks, list) or not checks:
            errors.append(f"{prefix}: summary_checks must be a non-empty list")
            continue
        requirement_id = row.get("requirement_id", "")
        actual_checks = [
            (check.get("summary_id", ""), check.get("field", ""), check.get("expected", ""))
            for check in checks
        ]
        expected_checks = EXPECTED_V53_SUMMARY_CHECKS.get(requirement_id)
        if expected_checks is not None and actual_checks != expected_checks:
            errors.append(f"{prefix}: summary_checks must exactly match the v53 source benchmark contract")
        for check in checks:
            summary_id = check.get("summary_id", "")
            summary = summaries.get(summary_id)
            if summary is None:
                expected_path = DEFAULT_V53_SUMMARY_PATHS.get(summary_id)
                errors.append(f"{prefix}: missing summary evidence for {summary_id} at {expected_path}")
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
    for field in [
        "real_execution_ready",
        "human_blind_review_ready",
        "inter_rater_rows_ready",
        "v58_full_blind_eval_ready",
        "release_ready",
    ]:
        if policy.get(field) is not False:
            errors.append(f"{path}: policy.{field} must be false until real blind evidence is supplied")
    if policy.get("required_real_response_systems") != ["A", "B", "C", "D", "E", "G", "H"]:
        errors.append(f"{path}: policy.required_real_response_systems must be A/B/C/D/E/G/H in order")
    if policy.get("required_independent_reviewers_per_response") != 2:
        errors.append(f"{path}: policy.required_independent_reviewers_per_response must be 2")
    for field in [
        "blind_identity_required_until_adjudication",
        "response_text_identity_leakage_forbidden",
        "adjudication_required_for_disagreement",
        "unseen_repository_split_required",
        "source_span_exactness_separate_score",
        "unsupported_abstention_separate_score",
        "latency_memory_quality_separated",
    ]:
        if policy.get(field) is not True:
            errors.append(f"{path}: policy.{field} must be true")
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
        extra_row = set(row) - REQUIRED_V58_ARTIFACT_KEYS - OPTIONAL_V58_ARTIFACT_KEYS
        if extra_row:
            errors.append(f"{prefix}: unknown keys: {', '.join(sorted(extra_row))}")
        if not row.get("artifact_kind") or not row.get("validation_command"):
            errors.append(f"{prefix}: artifact_kind and validation_command must be non-empty")
        artifact_id = row.get("artifact_id", "")
        validation_command = row.get("validation_command", "")
        expected_validation_command = EXPECTED_V58_VALIDATION_COMMANDS.get(artifact_id)
        if expected_validation_command is not None and validation_command != expected_validation_command:
            errors.append(f"{prefix}: validation_command must be {expected_validation_command}")
        script_path = validation_command_script(validation_command)
        if script_path is None:
            errors.append(f"{prefix}: validation_command must reference a runnable test script")
        elif not script_path.exists():
            errors.append(f"{prefix}: validation_command script is missing: {script_path}")
        elif not os.access(script_path, os.X_OK):
            errors.append(f"{prefix}: validation_command script is not executable: {script_path}")
        min_rows = row.get("min_rows")
        expected_min_rows = EXPECTED_V58_ARTIFACT_MIN_ROWS.get(artifact_id)
        if not isinstance(min_rows, int) or min_rows < 1:
            errors.append(f"{prefix}: min_rows must be a positive integer")
        elif expected_min_rows is not None and min_rows != expected_min_rows:
            errors.append(f"{prefix}: min_rows expected {expected_min_rows}, got {min_rows}")
        expected_per_system = EXPECTED_V58_PER_SYSTEM_MIN_ROWS.get(artifact_id)
        per_system_min_rows = row.get("per_system_min_rows")
        if expected_per_system is None:
            if per_system_min_rows is not None:
                errors.append(f"{prefix}: per_system_min_rows is only expected for response/resource rows")
        elif per_system_min_rows != expected_per_system:
            errors.append(f"{prefix}: per_system_min_rows must require 500 rows for each A/B/C/D/E/G/H system")
        elif isinstance(min_rows, int) and sum(per_system_min_rows.values()) != min_rows:
            errors.append(f"{prefix}: per_system_min_rows must sum to min_rows")
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
                leaked_identity_columns = column_set & V58_REVIEW_FORBIDDEN_IDENTITY_COLUMNS
                if leaked_identity_columns:
                    errors.append(f"{prefix}: human review/adjudication rows must not reveal system identity columns: {', '.join(sorted(leaked_identity_columns))}")

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
        "production_latency_claim_ready",
        "near_frontier_claim_ready",
        "quality_comparison_claim_ready",
        "public_comparison_claim_ready",
        "release_ready",
        "fixture_can_close_real_return",
    ]:
        if policy.get(field) is not False:
            errors.append(f"{path}: {field} must be false")
    for field in [
        "accepted_human_review_rows",
        "accepted_adjudication_rows",
        "accepted_operator_return_rows",
    ]:
        if policy.get(field) != 0:
            errors.append(f"{path}: {field} must be 0")

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

    for row in requirements:
        checks = row.get("summary_checks", [])
        if not isinstance(checks, list) or not checks:
            continue
        summary_ids = {check.get("summary_id", "") for check in checks if isinstance(check, dict)}
        if len(summary_ids) != 1:
            continue
        summary_id = next(iter(summary_ids))
        if not summary_id or summary_id in summaries:
            continue
        evidence_path = Path(row.get("evidence_path", ""))
        if evidence_path.is_file() and evidence_path.stat().st_size > 0:
            summaries[summary_id] = read_first_csv(evidence_path)

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
        if not isinstance(checks, list) or not checks:
            errors.append(f"{prefix}: summary_checks must be a non-empty list")
            continue
        requirement_id = row.get("requirement_id", "")
        actual_checks = [
            (check.get("summary_id", ""), check.get("field", ""), check.get("expected", ""))
            for check in checks
        ]
        expected_checks = EXPECTED_REVIEW_RETURN_SUMMARY_CHECKS.get(requirement_id)
        if expected_checks is not None and actual_checks != expected_checks:
            errors.append(f"{prefix}: summary_checks must exactly match the review-return blocker contract")
        for check in checks:
            summary_id = check.get("summary_id", "")
            summary = summaries.get(summary_id)
            if summary is None:
                errors.append(f"{prefix}: missing summary evidence for {summary_id} at {row.get('evidence_path')}")
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
    missing_policy = REQUIRED_V61_POLICY_KEYS - set(policy)
    if missing_policy:
        errors.append(f"{path}: policy missing keys: {', '.join(sorted(missing_policy))}")
    if policy.get("ssd_resident_real_model_runtime_claim_ready") is not False:
        errors.append(f"{path}: SSD-resident real model runtime claim must stay false until milestones 1-6 pass")
    if policy.get("real_model_execution_ready") is not False:
        errors.append(f"{path}: real_model_execution_ready must stay false until one-token evidence exists")
    if policy.get("release_ready") is not False:
        errors.append(f"{path}: release_ready must stay false")
    if policy.get("required_before_ssd_resident_runtime_claim") != V61_REQUIRED_BEFORE_RUNTIME_CLAIM:
        errors.append(f"{path}: required_before_ssd_resident_runtime_claim must be milestones 1-6")
    if policy.get("required_before_ssd_resident_runtime_claim_count") != len(V61_REQUIRED_BEFORE_RUNTIME_CLAIM):
        errors.append(f"{path}: required_before_ssd_resident_runtime_claim_count must be {len(V61_REQUIRED_BEFORE_RUNTIME_CLAIM)}")
    if policy.get("passed_before_ssd_resident_runtime_claim_count") != len(V61_PASSED_BEFORE_RUNTIME_CLAIM):
        errors.append(f"{path}: passed_before_ssd_resident_runtime_claim_count must be {len(V61_PASSED_BEFORE_RUNTIME_CLAIM)}")
    if policy.get("blocked_before_ssd_resident_runtime_claim_count") != len(V61_BLOCKED_BEFORE_RUNTIME_CLAIM):
        errors.append(f"{path}: blocked_before_ssd_resident_runtime_claim_count must be {len(V61_BLOCKED_BEFORE_RUNTIME_CLAIM)}")
    if policy.get("blocked_before_ssd_resident_runtime_claim") != V61_BLOCKED_BEFORE_RUNTIME_CLAIM:
        errors.append(f"{path}: blocked_before_ssd_resident_runtime_claim must list the still-blocked milestones before runtime claim")

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
    summary_evidence_supplied = bool(summaries)

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
                errors.append(f"{prefix}: missing summary evidence for {summary_id} at {row.get('evidence_path')}")
                continue
            field = check.get("field", "")
            expected = check.get("expected", "")
            if summary.get(field) != expected:
                errors.append(f"{prefix}: {summary_id}.{field} expected {expected}, got {summary.get(field)}")

    artifacts = data["required_artifacts"]
    artifact_ids = [row.get("artifact_id", "") for row in artifacts]
    if artifact_ids != EXPECTED_V61_ARTIFACT_IDS:
        errors.append(f"{path}: required_artifacts order must match the v61 one-token replay artifact contract")
    if len(artifact_ids) != len(set(artifact_ids)):
        errors.append(f"{path}: duplicate required_artifacts are forbidden")
    milestone_status = {row.get("milestone_id", ""): row.get("current_status", "") for row in milestones}
    runtime_gate_status = {
        milestone_id: milestone_status.get(milestone_id, "")
        for milestone_id in V61_REQUIRED_BEFORE_RUNTIME_CLAIM
    }
    runtime_gate_passed = [
        milestone_id
        for milestone_id, status in runtime_gate_status.items()
        if status == "pass"
    ]
    runtime_gate_blocked = [
        milestone_id
        for milestone_id, status in runtime_gate_status.items()
        if status == "blocked"
    ]
    if runtime_gate_passed != V61_PASSED_BEFORE_RUNTIME_CLAIM:
        errors.append(f"{path}: milestones 1-6 pass list no longer matches policy")
    if runtime_gate_blocked != V61_BLOCKED_BEFORE_RUNTIME_CLAIM:
        errors.append(f"{path}: milestones 1-6 blocked list no longer matches policy")
    missing_required_artifacts: list[str] = []
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
        elif expected_columns is not None and required_columns != expected_columns:
            errors.append(f"{prefix}: required_columns must exactly match the v61 artifact header order")
        expected_path = EXPECTED_V61_REQUIRED_ARTIFACT_PATHS.get(artifact_id)
        if expected_path is not None and row.get("path") != expected_path:
            errors.append(f"{prefix}: path expected {expected_path}, got {row.get('path')}")
        linked_milestone = row.get("linked_milestone_id", "")
        expected_milestone = EXPECTED_V61_ARTIFACT_MILESTONES.get(artifact_id)
        if expected_milestone is not None and linked_milestone != expected_milestone:
            errors.append(f"{prefix}: linked_milestone_id expected {expected_milestone}, got {linked_milestone}")
        if row.get("required_for_runtime_claim") is not True:
            errors.append(f"{prefix}: required_for_runtime_claim must be true")
        expected_pass_field = EXPECTED_V61_ARTIFACT_PASS_FIELDS.get(artifact_id)
        pass_field = row.get("pass_field", "")
        if expected_pass_field is not None and pass_field != expected_pass_field:
            errors.append(f"{prefix}: pass_field expected {expected_pass_field}, got {pass_field}")
        min_rows = row.get("min_rows")
        expected_min_rows = EXPECTED_V61_ARTIFACT_MIN_ROWS.get(artifact_id)
        if not isinstance(min_rows, int) or min_rows < 1:
            errors.append(f"{prefix}: min_rows must be a positive integer")
        elif expected_min_rows is not None and min_rows != expected_min_rows:
            errors.append(f"{prefix}: min_rows expected {expected_min_rows}, got {min_rows}")

        artifact_path = Path(row.get("path", ""))
        artifact_exists = artifact_path.is_file() and artifact_path.stat().st_size > 0
        if not artifact_exists:
            missing_required_artifacts.append(artifact_id)
        linked_status = milestone_status.get(linked_milestone, "")
        if linked_status == "pass" and summary_evidence_supplied and not artifact_exists:
            errors.append(f"{prefix}: pass milestone requires non-empty artifact path {artifact_path}")
            continue
        if not artifact_exists:
            continue
        with artifact_path.open(newline="", encoding="utf-8") as handle:
            reader = csv.DictReader(handle)
            fieldnames = reader.fieldnames or []
            if required_columns and fieldnames != required_columns:
                errors.append(f"{artifact_path}: header must match required_columns for {artifact_id}")
            rows = list(reader)
        if isinstance(min_rows, int) and len(rows) < min_rows:
            errors.append(f"{artifact_path}: expected at least {min_rows} data rows, got {len(rows)}")
        if pass_field and pass_field not in fieldnames:
            errors.append(f"{artifact_path}: missing pass field {pass_field}")
            continue
        value_checks = EXPECTED_V61_ARTIFACT_VALUE_CHECKS.get(artifact_id, {})
        for row_index, artifact_row in enumerate(rows, start=1):
            for field, expected in value_checks.items():
                if artifact_row.get(field) != expected:
                    errors.append(f"{artifact_path}: row {row_index} {field} expected {expected}, got {artifact_row.get(field)}")
            if (
                artifact_id == "expert-ffn-forward-parity-rows"
                and artifact_row.get(pass_field) == "1"
                and artifact_row.get("real_model_execution_ready") == "1"
            ):
                transformers_hash = artifact_row.get("transformers_expert_output_sha256", "")
                independent_hash = artifact_row.get("independent_runtime_output_sha256", "")
                if not _is_sha256_digest(transformers_hash):
                    errors.append(f"{artifact_path}: row {row_index} real expert_ffn_parity_pass=1 requires transformers_expert_output_sha256")
                if not _is_sha256_digest(independent_hash):
                    errors.append(f"{artifact_path}: row {row_index} real expert_ffn_parity_pass=1 requires independent_runtime_output_sha256")
                if artifact_row.get("candidate_output_sha256") != independent_hash:
                    errors.append(f"{artifact_path}: row {row_index} real expert_ffn_parity_pass=1 requires candidate_output_sha256 to match independent_runtime_output_sha256")
                if artifact_row.get("torch_reference_output_sha256") != transformers_hash:
                    errors.append(f"{artifact_path}: row {row_index} real expert_ffn_parity_pass=1 requires torch_reference_output_sha256 to match transformers_expert_output_sha256")
            if artifact_id == "one-token-logits-parity-rows" and artifact_row.get(pass_field) == "1":
                try:
                    tolerance_value = float(artifact_row.get("tolerance", ""))
                    max_abs_delta_value = float(artifact_row.get("max_abs_delta", ""))
                    mean_abs_delta_value = float(artifact_row.get("mean_abs_delta", ""))
                except ValueError:
                    errors.append(f"{artifact_path}: row {row_index} logits_parity_pass=1 requires numeric max_abs_delta, mean_abs_delta, and tolerance")
                    tolerance_value = math.nan
                    max_abs_delta_value = math.nan
                    mean_abs_delta_value = math.nan
                if artifact_row.get("top1_token_id") != artifact_row.get("reference_top1_token_id"):
                    errors.append(f"{artifact_path}: row {row_index} logits_parity_pass=1 requires top1_token_id to match reference_top1_token_id")
                if artifact_row.get("top_k_token_ranking_match") != "1":
                    errors.append(f"{artifact_path}: row {row_index} logits_parity_pass=1 requires top_k_token_ranking_match=1")
                if not artifact_row.get("token_id"):
                    errors.append(f"{artifact_path}: row {row_index} logits_parity_pass=1 requires token_id")
                parsed_ints: dict[str, int] = {}
                for field in ["token_id", "top1_token_id", "reference_top1_token_id"]:
                    try:
                        parsed = int(artifact_row.get(field, ""))
                    except ValueError:
                        errors.append(f"{artifact_path}: row {row_index} logits_parity_pass=1 requires nonnegative integer {field}")
                        continue
                    if parsed < 0:
                        errors.append(f"{artifact_path}: row {row_index} logits_parity_pass=1 requires nonnegative integer {field}")
                        continue
                    parsed_ints[field] = parsed
                for field in ["router_top_k", "layer_activation_trace_rows", "top_k_token_count", "vocab_size", "logit_count"]:
                    try:
                        parsed = int(artifact_row.get(field, ""))
                    except ValueError:
                        errors.append(f"{artifact_path}: row {row_index} logits_parity_pass=1 requires positive integer {field}")
                        continue
                    if parsed <= 0:
                        errors.append(f"{artifact_path}: row {row_index} logits_parity_pass=1 requires positive integer {field}")
                        continue
                    parsed_ints[field] = parsed
                if parsed_ints.get("vocab_size") != parsed_ints.get("logit_count"):
                    errors.append(f"{artifact_path}: row {row_index} logits_parity_pass=1 requires logit_count to equal vocab_size")
                for field in [
                    "moe_block_artifact_sha256",
                    "tokenizer_input_sha256",
                    "layer_activation_trace_sha256",
                    "route_path_sha256",
                    "final_hidden_sha256",
                    "lm_head_payload_sha256",
                    "candidate_logits_sha256",
                    "torch_reference_logits_sha256",
                ]:
                    if not _is_sha256_digest(artifact_row.get(field, "")):
                        errors.append(f"{artifact_path}: row {row_index} logits_parity_pass=1 requires {field}")
                candidate_top_k = _parse_token_id_list(artifact_row.get("candidate_top_k_token_ids", ""))
                reference_top_k = _parse_token_id_list(artifact_row.get("reference_top_k_token_ids", ""))
                if candidate_top_k is None:
                    errors.append(f"{artifact_path}: row {row_index} logits_parity_pass=1 requires parseable candidate_top_k_token_ids")
                if reference_top_k is None:
                    errors.append(f"{artifact_path}: row {row_index} logits_parity_pass=1 requires parseable reference_top_k_token_ids")
                top_k_token_count = parsed_ints.get("top_k_token_count")
                if candidate_top_k is not None and top_k_token_count is not None and len(candidate_top_k) != top_k_token_count:
                    errors.append(f"{artifact_path}: row {row_index} logits_parity_pass=1 requires candidate_top_k_token_ids length to equal top_k_token_count")
                if reference_top_k is not None and top_k_token_count is not None and len(reference_top_k) != top_k_token_count:
                    errors.append(f"{artifact_path}: row {row_index} logits_parity_pass=1 requires reference_top_k_token_ids length to equal top_k_token_count")
                if candidate_top_k is not None and reference_top_k is not None and candidate_top_k != reference_top_k:
                    errors.append(f"{artifact_path}: row {row_index} logits_parity_pass=1 requires candidate_top_k_token_ids to match reference_top_k_token_ids")
                if not math.isfinite(max_abs_delta_value) or not math.isfinite(mean_abs_delta_value) or not math.isfinite(tolerance_value):
                    errors.append(f"{artifact_path}: row {row_index} logits_parity_pass=1 requires finite max_abs_delta, mean_abs_delta, and tolerance")
                elif max_abs_delta_value > tolerance_value or mean_abs_delta_value > tolerance_value:
                    errors.append(f"{artifact_path}: row {row_index} logits_parity_pass=1 requires max_abs_delta and mean_abs_delta <= tolerance")
        real_pass_rows = [
            artifact_row
            for artifact_row in rows
            if artifact_row.get(pass_field) == "1"
        ]
        if linked_status == "pass" and not real_pass_rows:
            errors.append(f"{artifact_path}: pass milestone {linked_milestone} requires a {pass_field}=1 row")
        real_model_pass_rows = [
            artifact_row
            for artifact_row in real_pass_rows
            if artifact_row.get("real_model_execution_ready") == "1"
        ]
        if linked_milestone in V61_REAL_MODEL_EXECUTION_PASS_MILESTONES and linked_status == "pass" and not real_model_pass_rows:
            errors.append(f"{artifact_path}: pass milestone {linked_milestone} requires a real_model_execution_ready=1 {pass_field}=1 row")
        if linked_status == "blocked" and real_pass_rows:
            errors.append(f"{artifact_path}: blocked milestone {linked_milestone} cannot contain {pass_field}=1 rows")
        if linked_status == "blocked" and linked_milestone in V61_REQUIRED_BEFORE_RUNTIME_CLAIM:
            for row_index, artifact_row in enumerate(rows, start=1):
                for field in sorted(V61_BLOCKED_RUNTIME_FORBIDDEN_READY_FIELDS & set(fieldnames)):
                    if artifact_row.get(field) == "1":
                        errors.append(f"{artifact_path}: row {row_index} blocked milestone {linked_milestone} forbids {field}=1")
    present_required_artifacts = len(artifacts) - len(missing_required_artifacts)
    if policy.get("required_artifact_count") != len(artifacts):
        errors.append(f"{path}: policy.required_artifact_count expected {len(artifacts)}, got {policy.get('required_artifact_count')}")
    if policy.get("present_required_artifact_count") != present_required_artifacts:
        errors.append(
            f"{path}: policy.present_required_artifact_count expected {present_required_artifacts}, "
            f"got {policy.get('present_required_artifact_count')}"
        )
    if policy.get("missing_required_artifact_count") != len(missing_required_artifacts):
        errors.append(
            f"{path}: policy.missing_required_artifact_count expected {len(missing_required_artifacts)}, "
            f"got {policy.get('missing_required_artifact_count')}"
        )
    if policy.get("missing_required_artifact_ids") != missing_required_artifacts:
        errors.append(
            f"{path}: policy.missing_required_artifact_ids expected {missing_required_artifacts}, "
            f"got {policy.get('missing_required_artifact_ids')}"
        )
    return errors


def _parse_finite_float(value: str, label: str, errors: list[str]) -> float:
    try:
        parsed = float(value)
    except ValueError:
        errors.append(f"{label}: expected finite numeric value, got {value!r}")
        return math.nan
    if not math.isfinite(parsed):
        errors.append(f"{label}: expected finite numeric value, got {value!r}")
    return parsed


def _summary_expect(summary_path: Path, summary: dict[str, str], field: str, expected: str, errors: list[str]) -> None:
    actual = summary.get(field)
    if actual != expected:
        errors.append(f"{summary_path}: {field} expected {expected}, got {actual}")


def _is_sha256_digest(value: str) -> bool:
    digest = value.removeprefix("sha256:")
    return (
        value.startswith("sha256:")
        and len(digest) == 64
        and all(character in "0123456789abcdef" for character in digest)
    )


def _parse_token_id_list(value: str) -> list[int] | None:
    if not value:
        return None
    tokens: list[int] = []
    for part in value.split("|"):
        try:
            token_id = int(part)
        except ValueError:
            return None
        if token_id < 0:
            return None
        tokens.append(token_id)
    return tokens


def _compute_v61ab_expert_ffn_readiness(
    row: dict[str, str],
    label: str,
    errors: list[str],
) -> dict[str, int | str]:
    if not row:
        return {
            "contract_ready": 0,
            "fixture_execution_ready": 0,
            "real_model_execution_ready": 0,
            "release_ready": 0,
            "status": "blocked",
        }

    contract_fields = [
        "checkpoint_id",
        "model_revision",
        "layer_index",
        "expert_index",
        "token_id",
        "router_top_k",
        "rmsnorm_tensor_name",
        "router_tensor_name",
        "w1_tensor_name",
        "w2_tensor_name",
        "w3_tensor_name",
    ]
    contract_ready = int(all(row.get(field, "") != "" for field in contract_fields))
    forbidden_zero_fields = [
        "checkpoint_payload_bytes_committed_to_repo",
        "actual_model_generation_ready",
        "route_jump_rows",
        "heldout_metric_ready",
        "human_review_ready",
        "independent_reproduction_ready",
        "release_ready",
    ]
    for field in forbidden_zero_fields:
        if row.get(field, "0") != "0":
            errors.append(f"{label}: {field} must be 0")

    try:
        tolerance = float(row.get("tolerance", ""))
        max_abs_delta = float(row.get("max_abs_delta", ""))
    except ValueError:
        tolerance = math.nan
        max_abs_delta = math.nan
    tolerance_ok = math.isfinite(tolerance) and math.isfinite(max_abs_delta) and max_abs_delta <= tolerance
    independent_hash = row.get("independent_runtime_output_sha256", "")
    candidate_hash = row.get("candidate_output_sha256", "")
    torch_reference_hash = row.get("torch_reference_output_sha256", "")
    transformers_hash = row.get("transformers_expert_output_sha256", "")
    required_fixture_hashes = [
        "config_sha256",
        "shard_index_sha256",
        "full_manifest_sha256",
        "rmsnorm_payload_sha256",
        "router_payload_sha256",
        "w1_payload_sha256",
        "w2_payload_sha256",
        "w3_payload_sha256",
        "residual_input_sha256",
        "residual_output_sha256",
    ]
    fixture_hashes_ready = all(_is_sha256_digest(row.get(field, "")) for field in required_fixture_hashes)
    independent_ready = _is_sha256_digest(independent_hash) and candidate_hash == independent_hash
    torch_reference_ready = _is_sha256_digest(torch_reference_hash)
    fixture_execution_ready = int(contract_ready and tolerance_ok and fixture_hashes_ready and independent_ready and torch_reference_ready)
    real_model_execution_ready = int(
        fixture_execution_ready
        and _is_sha256_digest(transformers_hash)
        and torch_reference_hash == transformers_hash
    )
    if row.get("fixture_execution_ready") == "1" and not fixture_execution_ready:
        errors.append(f"{label}: fixture_execution_ready=1 is not supported by expert FFN raw parity evidence")
    if row.get("real_model_execution_ready") == "1" and not real_model_execution_ready:
        errors.append(f"{label}: real_model_execution_ready=1 is not supported by original Transformers and independent runtime evidence")
    if row.get("expert_ffn_parity_pass") == "1" and not (fixture_execution_ready or real_model_execution_ready):
        errors.append(f"{label}: expert_ffn_parity_pass=1 is not supported by expert FFN raw parity evidence")
    return {
        "contract_ready": contract_ready,
        "fixture_execution_ready": fixture_execution_ready,
        "real_model_execution_ready": real_model_execution_ready,
        "release_ready": 0,
        "status": "pass" if fixture_execution_ready or real_model_execution_ready else "blocked",
    }


def _summary_expect_float(
    summary_path: Path,
    summary: dict[str, str],
    field: str,
    expected: float,
    errors: list[str],
    tolerance: float = 1e-9,
) -> None:
    actual = _parse_finite_float(summary.get(field, ""), f"{summary_path}: {field}", errors)
    if math.isfinite(actual) and not math.isclose(actual, expected, rel_tol=tolerance, abs_tol=tolerance):
        errors.append(f"{summary_path}: {field} expected {expected:.12g}, got {summary.get(field)}")


def _manifest_expect(manifest_path: Path, manifest: dict[str, object], field: str, expected: object, errors: list[str]) -> None:
    actual = manifest.get(field)
    if actual != expected:
        errors.append(f"{manifest_path}: {field} expected {expected}, got {actual}")


def verify_v61ab_tile_probe(summary_path: Path, run_dir: Path | None = None) -> list[str]:
    errors: list[str] = []
    summary = read_first_csv(summary_path)
    if not summary:
        return [f"{summary_path}: missing v61ab summary row"]
    resolved_run_dir = run_dir or summary_path.parent / "v61ab_hotset_tensor_tile_quant_probe" / "probe_001"
    required_paths = {
        "tile": resolved_run_dir / "hotset_tensor_tile_probe_rows.csv",
        "sample": resolved_run_dir / "hotset_tensor_tile_sample_trace_rows.csv",
        "torch": resolved_run_dir / "hotset_tensor_tile_torch_parity_rows.csv",
        "expert": resolved_run_dir / "expert_ffn_forward_parity_rows.csv",
        "metric": resolved_run_dir / "hotset_tensor_tile_quant_metric_rows.csv",
        "manifest": resolved_run_dir / "v61ab_hotset_tensor_tile_quant_probe_manifest.json",
    }
    for label, path in required_paths.items():
        if not path.is_file() or path.stat().st_size == 0:
            errors.append(f"{path}: missing non-empty v61ab {label} artifact")
    if errors:
        return errors

    tile_rows = read_csv_rows(required_paths["tile"])
    sample_rows = read_csv_rows(required_paths["sample"])
    torch_rows = read_csv_rows(required_paths["torch"])
    expert_rows = read_csv_rows(required_paths["expert"])
    metric_rows = read_csv_rows(required_paths["metric"])
    if len(metric_rows) != 1:
        errors.append(f"{required_paths['metric']}: expected exactly one metric row, got {len(metric_rows)}")
        return errors
    metric = metric_rows[0]
    manifest_path = required_paths["manifest"]
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not isinstance(manifest, dict):
        return [f"{manifest_path}: expected JSON object manifest"]

    tile_count = len(tile_rows)
    sample_count = len(sample_rows)
    torch_count = len(torch_rows)
    expert_count = len(expert_rows)
    tile_values = 0
    tile_value_counts: list[int] = []
    moe_tile_rows = 0
    embedding_tile_rows = 0
    finite_baseline_rows = 0
    finite_q8_rows = 0
    finite_q4_rows = 0
    finite_q8_error_rows = 0
    finite_q4_error_rows = 0
    q8_errors: list[float] = []
    q4_errors: list[float] = []
    for index, row in enumerate(tile_rows, start=1):
        prefix = f"{required_paths['tile']}: row {index}"
        try:
            tile_value_count = int(row.get("tile_bf16_values", ""))
            tile_values += tile_value_count
            tile_value_counts.append(tile_value_count)
        except ValueError:
            errors.append(f"{prefix}: tile_bf16_values must be an integer")
        moe_tile_rows += int(row.get("moe_expert_tile") == "1")
        embedding_tile_rows += int(row.get("embedding_tile") == "1")
        finite_baseline_rows += int(row.get("baseline_dot_finite") == "1")
        finite_q8_rows += int(row.get("q8_dot_finite") == "1")
        finite_q4_rows += int(row.get("q4_dot_finite") == "1")
        finite_q8_error_rows += int(row.get("q8_error_finite") == "1")
        finite_q4_error_rows += int(row.get("q4_error_finite") == "1")
        q8_errors.append(_parse_finite_float(row.get("q8_abs_error", ""), f"{prefix}: q8_abs_error", errors))
        q4_errors.append(_parse_finite_float(row.get("q4_abs_error", ""), f"{prefix}: q4_abs_error", errors))
        for field in ["checkpoint_payload_bytes_committed_to_repo", "actual_model_generation_ready", "route_jump_rows"]:
            if row.get(field) != "0":
                errors.append(f"{prefix}: {field} must be 0")
        if row.get("tile_hash_bound_to_remote_page") != "1":
            errors.append(f"{prefix}: tile_hash_bound_to_remote_page must be 1")

    torch_pass_rows = 0
    for index, row in enumerate(torch_rows, start=1):
        prefix = f"{required_paths['torch']}: row {index}"
        torch_pass_rows += int(row.get("torch_matvec_parity_pass") == "1")
        for field in ["real_checkpoint_page_bound"]:
            if row.get(field) != "1":
                errors.append(f"{prefix}: {field} must be 1")
        for field in ["checkpoint_payload_bytes_committed_to_repo", "actual_model_generation_ready", "route_jump_rows"]:
            if row.get(field) != "0":
                errors.append(f"{prefix}: {field} must be 0")

    expert = expert_rows[0] if expert_rows else {}
    expert_readiness = _compute_v61ab_expert_ffn_readiness(
        expert,
        f"{required_paths['expert']}: row 1",
        errors,
    )
    numeric_ready = int(
        tile_count > 0
        and len(tile_value_counts) == tile_count
        and len(set(tile_value_counts)) == 1
        and tile_values == tile_count * tile_value_counts[0]
        and sample_count == tile_count * 3
        and finite_baseline_rows == tile_count
        and finite_q8_rows == tile_count
        and finite_q4_rows == tile_count
        and finite_q8_error_rows == tile_count
        and finite_q4_error_rows == tile_count
        and torch_count == tile_count
        and torch_pass_rows == tile_count
    )
    finite_q8_values = [value for value in q8_errors if math.isfinite(value)]
    finite_q4_values = [value for value in q4_errors if math.isfinite(value)]
    q8_mean = math.fsum(finite_q8_values) / len(finite_q8_values) if finite_q8_values else math.nan
    q4_mean = math.fsum(finite_q4_values) / len(finite_q4_values) if finite_q4_values else math.nan
    q8_max = max(finite_q8_values) if finite_q8_values else math.nan
    q4_max = max(finite_q4_values) if finite_q4_values else math.nan

    expected_summary = {
        "v61ab_hotset_tensor_tile_quant_probe_ready": str(numeric_ready),
        "model_id": "mistralai/Mixtral-8x22B-v0.1",
        "tensor_tile_probe_rows": str(tile_count),
        "moe_tensor_tile_probe_rows": str(moe_tile_rows),
        "embedding_tensor_tile_probe_rows": str(embedding_tile_rows),
        "tile_bf16_value_rows": str(tile_values),
        "tile_sample_trace_rows": str(sample_count),
        "finite_baseline_dot_rows": str(finite_baseline_rows),
        "finite_q8_dot_rows": str(finite_q8_rows),
        "finite_q4_dot_rows": str(finite_q4_rows),
        "finite_q8_error_rows": str(finite_q8_error_rows),
        "finite_q4_error_rows": str(finite_q4_error_rows),
        "torch_matvec_parity_rows": str(torch_count),
        "torch_matvec_parity_pass_rows": str(torch_pass_rows),
        "hotset_numeric_tile_probe_ready": str(numeric_ready),
        "q8_quant_probe_ready": str(numeric_ready),
        "q4_quant_probe_ready": str(numeric_ready),
        "torch_matvec_parity_ready": str(numeric_ready),
        "expert_ffn_parity_rows": str(expert_count),
        "expert_ffn_parity_contract_ready": str(expert_readiness["contract_ready"]),
        "expert_ffn_parity_fixture_execution_ready": str(expert_readiness["fixture_execution_ready"]),
        "expert_ffn_parity_real_model_execution_ready": str(expert_readiness["real_model_execution_ready"]),
        "expert_ffn_parity_release_ready": str(expert_readiness["release_ready"]),
        "expert_ffn_parity_status": str(expert_readiness["status"]),
        "checkpoint_payload_bytes_committed_to_repo": "0",
        "full_checkpoint_materialization_ready": "0",
        "full_safetensors_page_hash_binding_ready": "0",
        "actual_model_generation_ready": "0",
        "near_frontier_claim_ready": "0",
        "production_latency_claim_ready": "0",
        "real_release_package_ready": "0",
        "route_jump_rows": "0",
    }
    for field, expected in expected_summary.items():
        _summary_expect(summary_path, summary, field, expected, errors)
    for field, expected in {
        "q8_abs_error_mean": q8_mean,
        "q4_abs_error_mean": q4_mean,
        "q8_abs_error_max": q8_max,
        "q4_abs_error_max": q4_max,
    }.items():
        _summary_expect_float(summary_path, summary, field, expected, errors)

    expected_metric = {
        "tensor_tile_probe_rows": str(tile_count),
        "moe_tensor_tile_probe_rows": str(moe_tile_rows),
        "embedding_tensor_tile_probe_rows": str(embedding_tile_rows),
        "tile_bf16_value_rows": str(tile_values),
        "tile_sample_trace_rows": str(sample_count),
        "finite_baseline_dot_rows": str(finite_baseline_rows),
        "finite_q8_dot_rows": str(finite_q8_rows),
        "finite_q4_dot_rows": str(finite_q4_rows),
        "finite_q8_error_rows": str(finite_q8_error_rows),
        "finite_q4_error_rows": str(finite_q4_error_rows),
        "torch_matvec_parity_rows": str(torch_count),
        "torch_matvec_parity_pass_rows": str(torch_pass_rows),
        "hotset_numeric_tile_probe_ready": str(numeric_ready),
        "q8_quant_probe_ready": str(numeric_ready),
        "q4_quant_probe_ready": str(numeric_ready),
        "torch_matvec_parity_ready": str(numeric_ready),
        "expert_ffn_parity_contract_ready": str(expert_readiness["contract_ready"]),
        "expert_ffn_parity_fixture_execution_ready": str(expert_readiness["fixture_execution_ready"]),
        "expert_ffn_parity_real_model_execution_ready": str(expert_readiness["real_model_execution_ready"]),
        "expert_ffn_parity_release_ready": str(expert_readiness["release_ready"]),
    }
    for field, expected in expected_metric.items():
        actual = metric.get(field)
        if actual != expected:
            errors.append(f"{required_paths['metric']}: {field} expected {expected}, got {actual}")

    _manifest_expect(manifest_path, manifest, "v61ab_hotset_tensor_tile_quant_probe_ready", numeric_ready, errors)
    _manifest_expect(manifest_path, manifest, "tensor_tile_probe_rows", tile_count, errors)
    _manifest_expect(manifest_path, manifest, "tile_bf16_value_rows", tile_values, errors)
    _manifest_expect(manifest_path, manifest, "torch_matvec_parity_rows", torch_count, errors)
    _manifest_expect(manifest_path, manifest, "torch_matvec_parity_pass_rows", torch_pass_rows, errors)
    _manifest_expect(manifest_path, manifest, "torch_matvec_parity_ready", numeric_ready, errors)
    _manifest_expect(manifest_path, manifest, "expert_ffn_parity_contract_ready", expert_readiness["contract_ready"], errors)
    _manifest_expect(manifest_path, manifest, "expert_ffn_parity_fixture_execution_ready", expert_readiness["fixture_execution_ready"], errors)
    _manifest_expect(manifest_path, manifest, "expert_ffn_parity_real_model_execution_ready", expert_readiness["real_model_execution_ready"], errors)
    _manifest_expect(manifest_path, manifest, "expert_ffn_parity_release_ready", expert_readiness["release_ready"], errors)
    _manifest_expect(manifest_path, manifest, "actual_model_generation_ready", 0, errors)
    _manifest_expect(manifest_path, manifest, "checkpoint_payload_bytes_committed_to_repo", 0, errors)
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
    p_roadmap = sub.add_parser("roadmap-doc")
    p_roadmap.add_argument("paths", nargs="+", type=Path)
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
    p_v56 = sub.add_parser("v56-replay")
    p_v56.add_argument("paths", nargs="+", type=Path)
    p_v56.add_argument("--summary", type=Path, default=None)
    p_v56.add_argument("--blocker-ledger", type=Path, default=None)
    p_v56.add_argument("--artifact-ledger", type=Path, default=None)
    p_v53 = sub.add_parser("v53-source-benchmark")
    p_v53.add_argument("paths", nargs="+", type=Path)
    p_v53.add_argument("--v53i-summary", type=Path, default=None)
    p_v53.add_argument("--v53t-summary", type=Path, default=None)
    p_v53.add_argument("--v53ap-summary", type=Path, default=None)
    p_v53.add_argument("--v53aq-summary", type=Path, default=None)
    p_v53.add_argument("--v1-exit-ledger", type=Path, default=None)
    p_v53_public = sub.add_parser("v53-public-source-manifest")
    p_v53_public.add_argument("paths", nargs="+", type=Path)
    p_v53_public.add_argument("--repo-ledger", type=Path, default=None)
    p_v54 = sub.add_parser("v54-grounded-generation")
    p_v54.add_argument("paths", nargs="+", type=Path)
    p_v54.add_argument("--summary", type=Path, default=None)
    p_v59 = sub.add_parser("v59-pm-foundation-demo")
    p_v59.add_argument("paths", nargs="+", type=Path)
    p_v59.add_argument("--gate-ledger", type=Path, default=None)
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
    p_v61ab = sub.add_parser("v61ab-tile-probe")
    p_v61ab.add_argument("summary", type=Path)
    p_v61ab.add_argument("--run-dir", type=Path, default=None)
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
    elif args.cmd == "roadmap-doc":
        for path in args.paths:
            errors.extend(verify_roadmap_doc(path))
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
    elif args.cmd == "v56-replay":
        for path in args.paths:
            errors.extend(verify_v56_replay_contract(path, args.summary, args.blocker_ledger, args.artifact_ledger))
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
    elif args.cmd == "v53-public-source-manifest":
        for path in args.paths:
            errors.extend(verify_v53_public_source_manifest(path, args.repo_ledger))
    elif args.cmd == "v54-grounded-generation":
        for path in args.paths:
            errors.extend(verify_v54_grounded_generation(path, args.summary))
    elif args.cmd == "v59-pm-foundation-demo":
        for path in args.paths:
            errors.extend(verify_v59_pm_foundation_demo(path, args.gate_ledger))
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
    elif args.cmd == "v61ab-tile-probe":
        errors.extend(verify_v61ab_tile_probe(args.summary, args.run_dir))
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
