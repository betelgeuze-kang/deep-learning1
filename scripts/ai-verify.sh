#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "==> ai wrapper shell syntax"
bash -n scripts/ai-dangerous-command-check.sh scripts/ai-worker-cursor.sh scripts/ai-worker-opencode.sh scripts/ai-preflight.sh scripts/ai-verify.sh
if [ -f tools/check_tracked_results_policy.sh ]; then
  bash -n tools/check_tracked_results_policy.sh
fi
if [ -f experiments/run_v50_public_repo_auditor_3repo.sh ]; then
  bash -n experiments/run_v50_public_repo_auditor_3repo.sh
fi
if [ -f experiments/test_v1_0_pm_pr_claim_slice_gate.sh ]; then
  bash -n experiments/test_v1_0_pm_pr_claim_slice_gate.sh
fi
if [ -f experiments/test_p0_ci_workflow_negative_controls.sh ]; then
  bash -n experiments/test_p0_ci_workflow_negative_controls.sh
fi
if [ -f experiments/test_p0_pipeline_contract_negative_controls.sh ]; then
  bash -n experiments/test_p0_pipeline_contract_negative_controls.sh
fi
if [ -f experiments/test_p0_pr2_split_negative_controls.sh ]; then
  bash -n experiments/test_p0_pr2_split_negative_controls.sh
fi
if [ -f experiments/test_p0_readme_cleanup_negative_controls.sh ]; then
  bash -n experiments/test_p0_readme_cleanup_negative_controls.sh
fi
if [ -f experiments/test_p0_schema_validation_negative_controls.sh ]; then
  bash -n experiments/test_p0_schema_validation_negative_controls.sh
fi
if [ -f experiments/test_p0_v61ab_computed_readiness_negative_controls.sh ]; then
  bash -n experiments/test_p0_v61ab_computed_readiness_negative_controls.sh
fi
if [ -f experiments/test_p0_ready_leakage_negative_controls.sh ]; then
  bash -n experiments/test_p0_ready_leakage_negative_controls.sh
fi
if [ -f experiments/test_p0_v50_auditor_negative_controls.sh ]; then
  bash -n experiments/test_p0_v50_auditor_negative_controls.sh
fi
if [ -f experiments/test_p0_v52_adapter_guard_negative_controls.sh ]; then
  bash -n experiments/test_p0_v52_adapter_guard_negative_controls.sh
fi
if [ -f experiments/test_p0_v56_replay_negative_controls.sh ]; then
  bash -n experiments/test_p0_v56_replay_negative_controls.sh
fi
if [ -f experiments/test_p0_v53_v54_pipeline_negative_controls.sh ]; then
  bash -n experiments/test_p0_v53_v54_pipeline_negative_controls.sh
fi
if [ -f experiments/test_p0_review_return_workflow_negative_controls.sh ]; then
  bash -n experiments/test_p0_review_return_workflow_negative_controls.sh
fi
if [ -f experiments/test_p1_baseline_v58_negative_controls.sh ]; then
  bash -n experiments/test_p1_baseline_v58_negative_controls.sh
fi
if [ -f experiments/test_p1_atomic_run_dir_contract.sh ]; then
  bash -n experiments/test_p1_atomic_run_dir_contract.sh
fi
if [ -f experiments/test_p1_content_addressed_cache_contract.sh ]; then
  bash -n experiments/test_p1_content_addressed_cache_contract.sh
fi
if [ -f experiments/test_p1_fixture_real_namespace_contract.sh ]; then
  bash -n experiments/test_p1_fixture_real_namespace_contract.sh
fi
if [ -f experiments/test_p1_results_storage_negative_controls.sh ]; then
  bash -n experiments/test_p1_results_storage_negative_controls.sh
fi
if [ -f experiments/test_p1_v02_typed_config_contract.sh ]; then
  bash -n experiments/test_p1_v02_typed_config_contract.sh
fi
if [ -f experiments/test_p1_v02_energy_core_contract.sh ]; then
  bash -n experiments/test_p1_v02_energy_core_contract.sh
fi
if [ -f experiments/test_p1_v02_route_core_contract.sh ]; then
  bash -n experiments/test_p1_v02_route_core_contract.sh
fi
if [ -f experiments/test_p1_v02_credit_core_contract.sh ]; then
  bash -n experiments/test_p1_v02_credit_core_contract.sh
fi
if [ -f experiments/test_p1_v02_evaluator_core_contract.sh ]; then
  bash -n experiments/test_p1_v02_evaluator_core_contract.sh
fi
if [ -f experiments/test_p1_v02_key_signature_core_contract.sh ]; then
  bash -n experiments/test_p1_v02_key_signature_core_contract.sh
fi
if [ -f experiments/test_p1_v02_dataset_span_core_contract.sh ]; then
  bash -n experiments/test_p1_v02_dataset_span_core_contract.sh
fi
if [ -f experiments/test_v61aa_hotset_tensor_slice_verifier.sh ]; then
  bash -n experiments/test_v61aa_hotset_tensor_slice_verifier.sh
fi
if [ -f experiments/test_v61ab_hotset_tensor_tile_quant_probe.sh ]; then
  bash -n experiments/test_v61ab_hotset_tensor_tile_quant_probe.sh
fi
if [ -f experiments/test_v61er_real_generation_intake_dispatch_receipt_preflight.sh ]; then
  bash -n experiments/test_v61er_real_generation_intake_dispatch_receipt_preflight.sh
fi
if [ -f experiments/test_v61et_real_generation_intake_return_bundle_preflight.sh ]; then
  bash -n experiments/test_v61et_real_generation_intake_return_bundle_preflight.sh
fi
if [ -f experiments/test_v61_one_token_path_contract.sh ]; then
  bash -n experiments/test_v61_one_token_path_contract.sh
fi

echo "==> json"
json_files="$(git ls-files '*.json' ':(exclude)results/**' ':(exclude)build/**')"
if [ -n "$json_files" ]; then
  while IFS= read -r json_file; do
    [ -n "$json_file" ] || continue
    python3 -m json.tool "$json_file" >/dev/null
  done <<EOF
$json_files
EOF
fi
if [ -x tools/validate_json_schemas.py ]; then
  tools/validate_json_schemas.py >/dev/null
fi

echo "==> python syntax"
python_files="$(find . \
  -path './.git' -prune -o \
  -path './build' -prune -o \
  -path './results' -prune -o \
  -path './.cache' -prune -o \
  -path './.venv' -prune -o \
  -path './venv' -prune -o \
  -path './env' -prune -o \
  -path './node_modules' -prune -o \
  -path './.mypy_cache' -prune -o \
  -path './.pytest_cache' -prune -o \
  -path './__pycache__' -prune -o \
  -type f -name '*.py' -print)"
if [ -n "$python_files" ]; then
  while IFS= read -r py_file; do
    [ -n "$py_file" ] || continue
    python3 -m py_compile "$py_file"
  done <<EOF
$python_files
EOF
else
  echo "no python files detected outside ignored generated dirs"
fi

echo "==> tracked results storage policy"
test -f ci/tracked_results_allowlist.txt
test -x tools/check_tracked_results_policy.sh
tools/check_tracked_results_policy.sh ci/tracked_results_allowlist.txt >/dev/null

echo "==> cmake configure/build smoke"
if [ -f CMakeLists.txt ]; then
  DLE_VERIFY_ENABLE_HIP="${DLE_VERIFY_ENABLE_HIP:-OFF}"
  AI_VERIFY_JOBS="${AI_VERIFY_JOBS:-2}"
  cmake -S . -B build -DDLE_ENABLE_HIP="$DLE_VERIFY_ENABLE_HIP" >/dev/null
  cmake --build build -j "$AI_VERIFY_JOBS" >/dev/null

  mkdir -p results
  if [ -x build/dmv01 ]; then
    build/dmv01 --N 32 --cycles 5 --seed 1 --csv results/ai_verify_v01_smoke.csv >/dev/null
    test -s results/ai_verify_v01_smoke.csv
  fi
  if [ -x build/dmv02 ]; then
    build/dmv02 --dataset counter --N 32 --epochs 1 --cycles-per-epoch 2 --seed 1 --csv results/ai_verify_v02_smoke.csv >/dev/null
    test -s results/ai_verify_v02_smoke.csv
  fi
fi

echo "==> required orchestration files"
test -f AGENTS.md
test -f .codex/config.toml
test -f opencode.json
test -f docs/ai/profiles/deep-learning-research.md
test -f docs/ai/prompts/opencode_worker_slice.md
test -f docs/ai/prompts/cursor_worker_slice.md
test -x scripts/ai-worker-cursor.sh
test -x scripts/ai-worker-opencode.sh

echo "==> CI workflow contract"
workflow_files="$(find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sort || true)"
if [ -n "$workflow_files" ]; then
  while IFS= read -r workflow_file; do
    [ -n "$workflow_file" ] || continue
    if grep -En "runs-on:.*(ubuntu|windows|macos)" "$workflow_file" >/dev/null; then
      echo "workflow must not use GitHub-hosted runners: $workflow_file" >&2
      exit 1
    fi
    if grep -F "actions/cache@" "$workflow_file" >/dev/null; then
      echo "workflow must not use GitHub artifact/cache storage by default: $workflow_file" >&2
      exit 1
    fi
    if grep -F "actions/upload-artifact@" "$workflow_file" >/dev/null; then
      grep -F "upload_artifact:" "$workflow_file" >/dev/null || {
        echo "workflow artifact upload must be manual opt-in: $workflow_file" >&2
        exit 1
      }
      grep -F "if: \${{ inputs.upload_artifact == 'true' }}" "$workflow_file" >/dev/null || {
        echo "workflow artifact upload must require upload_artifact=true: $workflow_file" >&2
        exit 1
      }
      grep -Fx "          retention-days: 1" "$workflow_file" >/dev/null || {
        echo "workflow artifact upload retention must stay at 1 day: $workflow_file" >&2
        exit 1
      }
    fi
  done <<EOF
$workflow_files
EOF
fi
if [ -f ci/ai_verify_toolchain.lock.json ]; then
  python3 -m json.tool ci/ai_verify_toolchain.lock.json >/dev/null
  grep -F '"schema_version": "ai_verify_toolchain_lock.v1"' ci/ai_verify_toolchain.lock.json >/dev/null
  grep -F '"github_actions_runner": "self-hosted-linux-x64"' ci/ai_verify_toolchain.lock.json >/dev/null
  grep -F '"container_image_digest": ""' ci/ai_verify_toolchain.lock.json >/dev/null
  grep -F '"required_env": "DLE_VERIFY_ENABLE_HIP=OFF"' ci/ai_verify_toolchain.lock.json >/dev/null
  grep -F '"version_command": "python3 --version"' ci/ai_verify_toolchain.lock.json >/dev/null
  grep -F '"version_command": "g++ --version"' ci/ai_verify_toolchain.lock.json >/dev/null
  grep -F '"version_command": "cmake --version"' ci/ai_verify_toolchain.lock.json >/dev/null
fi
if [ -f .github/workflows/ai-verify.yml ]; then
  grep -F "pull_request:" .github/workflows/ai-verify.yml >/dev/null
  grep -F "push:" .github/workflows/ai-verify.yml >/dev/null
  if grep -A10 -F "push:" .github/workflows/ai-verify.yml | grep -F "branches:" >/dev/null; then
    echo "ai-verify workflow push trigger must not be branch-limited" >&2
    exit 1
  fi
  grep -F "workflow_dispatch:" .github/workflows/ai-verify.yml >/dev/null
  grep -F "runs-on: [self-hosted, linux, x64]" .github/workflows/ai-verify.yml >/dev/null
  grep -F "name: ai-verify.sh" .github/workflows/ai-verify.yml >/dev/null
  grep -F "run: ./scripts/ai-verify.sh" .github/workflows/ai-verify.yml >/dev/null
  grep -F "DLE_VERIFY_ENABLE_HIP: \"OFF\"" .github/workflows/ai-verify.yml >/dev/null
fi
if [ -f .github/workflows/third-party-rerun.yml ]; then
  grep -F "workflow_dispatch:" .github/workflows/third-party-rerun.yml >/dev/null
  grep -F "name: third-party-rerun-return-manual" .github/workflows/third-party-rerun.yml >/dev/null
  grep -F "runs-on: [self-hosted, linux, x64]" .github/workflows/third-party-rerun.yml >/dev/null
  grep -F "upload_artifact:" .github/workflows/third-party-rerun.yml >/dev/null
  grep -F "if: \${{ inputs.upload_artifact == 'true' }}" .github/workflows/third-party-rerun.yml >/dev/null
  if grep -F "pull_request:" .github/workflows/third-party-rerun.yml >/dev/null; then
    echo "third-party rerun workflow must stay manual-only" >&2
    exit 1
  fi
  if grep -F "push:" .github/workflows/third-party-rerun.yml >/dev/null; then
    echo "third-party rerun workflow must stay manual-only" >&2
    exit 1
  fi
  if grep -F "schedule:" .github/workflows/third-party-rerun.yml >/dev/null; then
    echo "third-party rerun workflow must stay manual-only" >&2
    exit 1
  fi
  if grep -F "repository_dispatch:" .github/workflows/third-party-rerun.yml >/dev/null; then
    echo "third-party rerun workflow must stay manual-only" >&2
    exit 1
  fi
  if grep -F "workflow_run:" .github/workflows/third-party-rerun.yml >/dev/null; then
    echo "third-party rerun workflow must stay manual-only" >&2
    exit 1
  fi
  if grep -F "workflow_call:" .github/workflows/third-party-rerun.yml >/dev/null; then
    echo "third-party rerun workflow must stay manual-only" >&2
    exit 1
  fi
  grep -F "V18_THIRD_PARTY_RERUN_DIR=" .github/workflows/third-party-rerun.yml >/dev/null
  grep -F "actions/upload-artifact@v4" .github/workflows/third-party-rerun.yml >/dev/null
  grep -Fx "          retention-days: 1" .github/workflows/third-party-rerun.yml >/dev/null
fi

echo "==> PM claim and evidence-boundary gate"
if [ -x experiments/test_v1_0_pm_pr_claim_slice_gate.sh ]; then
  ./experiments/test_v1_0_pm_pr_claim_slice_gate.sh >/dev/null
fi
if [ -x experiments/test_p0_ci_workflow_negative_controls.sh ]; then
  ./experiments/test_p0_ci_workflow_negative_controls.sh >/dev/null
fi
if [ -x experiments/test_p0_pipeline_contract_negative_controls.sh ]; then
  ./experiments/test_p0_pipeline_contract_negative_controls.sh >/dev/null
fi
if [ -x experiments/test_p0_pr2_split_negative_controls.sh ]; then
  ./experiments/test_p0_pr2_split_negative_controls.sh >/dev/null
fi
if [ -x experiments/test_p0_readme_cleanup_negative_controls.sh ]; then
  ./experiments/test_p0_readme_cleanup_negative_controls.sh >/dev/null
fi
if [ -x experiments/test_p0_schema_validation_negative_controls.sh ]; then
  ./experiments/test_p0_schema_validation_negative_controls.sh >/dev/null
fi
if [ -x experiments/test_p0_v61ab_computed_readiness_negative_controls.sh ]; then
  ./experiments/test_p0_v61ab_computed_readiness_negative_controls.sh >/dev/null
fi
if [ -x experiments/test_p0_ready_leakage_negative_controls.sh ]; then
  ./experiments/test_p0_ready_leakage_negative_controls.sh >/dev/null
fi
if [ -x experiments/test_p0_v50_auditor_negative_controls.sh ]; then
  ./experiments/test_p0_v50_auditor_negative_controls.sh >/dev/null
fi
if [ -x experiments/test_p0_v52_adapter_guard_negative_controls.sh ]; then
  ./experiments/test_p0_v52_adapter_guard_negative_controls.sh >/dev/null
fi
if [ -x experiments/test_p0_v56_replay_negative_controls.sh ]; then
  ./experiments/test_p0_v56_replay_negative_controls.sh >/dev/null
fi
if [ -x experiments/test_p0_v53_v54_pipeline_negative_controls.sh ]; then
  ./experiments/test_p0_v53_v54_pipeline_negative_controls.sh >/dev/null
fi
if [ -x experiments/test_p0_review_return_workflow_negative_controls.sh ]; then
  ./experiments/test_p0_review_return_workflow_negative_controls.sh >/dev/null
fi
if [ -x experiments/test_p1_baseline_v58_negative_controls.sh ]; then
  ./experiments/test_p1_baseline_v58_negative_controls.sh >/dev/null
fi
if [ -x experiments/test_p1_atomic_run_dir_contract.sh ]; then
  ./experiments/test_p1_atomic_run_dir_contract.sh >/dev/null
fi
if [ -x experiments/test_p1_content_addressed_cache_contract.sh ]; then
  ./experiments/test_p1_content_addressed_cache_contract.sh >/dev/null
fi
if [ -x experiments/test_p1_fixture_real_namespace_contract.sh ]; then
  ./experiments/test_p1_fixture_real_namespace_contract.sh >/dev/null
fi
if [ -x experiments/test_p1_results_storage_negative_controls.sh ]; then
  ./experiments/test_p1_results_storage_negative_controls.sh >/dev/null
fi
if [ -x experiments/test_p1_v02_typed_config_contract.sh ]; then
  ./experiments/test_p1_v02_typed_config_contract.sh >/dev/null
fi
if [ -x experiments/test_p1_v02_energy_core_contract.sh ]; then
  ./experiments/test_p1_v02_energy_core_contract.sh >/dev/null
fi
if [ -x experiments/test_p1_v02_route_core_contract.sh ]; then
  ./experiments/test_p1_v02_route_core_contract.sh >/dev/null
fi
if [ -x experiments/test_p1_v02_credit_core_contract.sh ]; then
  ./experiments/test_p1_v02_credit_core_contract.sh >/dev/null
fi
if [ -x experiments/test_p1_v02_evaluator_core_contract.sh ]; then
  ./experiments/test_p1_v02_evaluator_core_contract.sh >/dev/null
fi
if [ -x experiments/test_p1_v02_key_signature_core_contract.sh ]; then
  ./experiments/test_p1_v02_key_signature_core_contract.sh >/dev/null
fi
if [ -x experiments/test_p1_v02_dataset_span_core_contract.sh ]; then
  ./experiments/test_p1_v02_dataset_span_core_contract.sh >/dev/null
fi
if [ -x experiments/test_v61_one_token_path_contract.sh ]; then
  ./experiments/test_v61_one_token_path_contract.sh >/dev/null
fi
if [ -x experiments/test_v61er_real_generation_intake_dispatch_receipt_preflight.sh ]; then
  ./experiments/test_v61er_real_generation_intake_dispatch_receipt_preflight.sh >/dev/null
fi
if [ -x experiments/test_v61et_real_generation_intake_return_bundle_preflight.sh ]; then
  ./experiments/test_v61et_real_generation_intake_return_bundle_preflight.sh >/dev/null
fi

if [ -x tools/verify_artifact.py ]; then
  if [ -f docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md ]; then
    tools/verify_artifact.py roadmap-doc docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md >/dev/null
  fi
  if [ -f pr_slices/pr2.json ]; then
    tools/verify_artifact.py pr-split pr_slices/pr2.json >/dev/null
  fi
  if [ -f readiness/typed_ready.json ]; then
    if [ -f results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_ready_semantic_rows.csv ]; then
      tools/verify_artifact.py typed-readiness readiness/typed_ready.json \
        --pm-ledger results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_ready_semantic_rows.csv >/dev/null
    else
      tools/verify_artifact.py typed-readiness readiness/typed_ready.json >/dev/null
    fi
  fi
  if [ -f leakage/retrieval_model_visible.json ]; then
    if [ -f results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_retrieval_leakage_guard_rows.csv ]; then
      tools/verify_artifact.py leakage leakage/retrieval_model_visible.json \
        --pm-ledger results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_retrieval_leakage_guard_rows.csv >/dev/null
    else
      tools/verify_artifact.py leakage leakage/retrieval_model_visible.json >/dev/null
    fi
  fi
  if [ -f baselines/de_30b70b_real.json ]; then
    if [ -f results/v1_0_pm_pr_claim_slice_gate/gate_001/de_measured_registry_exclusion_rows.csv ] &&
       [ -f results/v1_0_pm_pr_claim_slice_gate/gate_001/de_30b70b_acceptance_evidence_rows.csv ]; then
      tools/verify_artifact.py baseline-admission baselines/de_30b70b_real.json \
        --measured-registry-ledger results/v1_0_pm_pr_claim_slice_gate/gate_001/de_measured_registry_exclusion_rows.csv \
        --acceptance-ledger results/v1_0_pm_pr_claim_slice_gate/gate_001/de_30b70b_acceptance_evidence_rows.csv >/dev/null
    else
      tools/verify_artifact.py baseline-admission baselines/de_30b70b_real.json >/dev/null
    fi
  fi
  if [ -f baselines/v52_adapter_guard.json ]; then
    if [ -f results/v52c_7b14b_local_model_rag_evidence_intake_summary.csv ] &&
       [ -f results/v52d_30b70b_llm_rag_evidence_intake_summary.csv ] &&
       [ -f results/v52l_7b14b_local_model_rag_v53e_1000_summary.csv ] &&
       [ -f results/v52r_measured_registry_de_absorb_summary.csv ] &&
       [ -f results/v52y_f_optional_final_policy_summary.csv ]; then
      tools/verify_artifact.py v52-adapter-guard baselines/v52_adapter_guard.json \
        --v52c-summary results/v52c_7b14b_local_model_rag_evidence_intake_summary.csv \
        --v52d-summary results/v52d_30b70b_llm_rag_evidence_intake_summary.csv \
        --v52l-summary results/v52l_7b14b_local_model_rag_v53e_1000_summary.csv \
        --v52r-summary results/v52r_measured_registry_de_absorb_summary.csv \
        --v52y-summary results/v52y_f_optional_final_policy_summary.csv >/dev/null
    else
      tools/verify_artifact.py v52-adapter-guard baselines/v52_adapter_guard.json >/dev/null
    fi
  fi
  if [ -f audits/v50_public_repo_auditor_correctness.json ]; then
    if [ -f results/v50_public_repo_auditor_3repo_summary.csv ] &&
       [ -f results/v50_public_repo_auditor_3repo_decision.csv ]; then
      tools/verify_artifact.py v50-auditor-correctness audits/v50_public_repo_auditor_correctness.json \
        --summary results/v50_public_repo_auditor_3repo_summary.csv \
        --decision results/v50_public_repo_auditor_3repo_decision.csv >/dev/null
    else
      tools/verify_artifact.py v50-auditor-correctness audits/v50_public_repo_auditor_correctness.json >/dev/null
    fi
  fi
  if [ -f v56/replay_contract.json ]; then
    if [ -f results/v56_ruler_longbench_expanded_contract_summary.csv ] &&
       [ -f results/v56_ruler_longbench_expanded_contract/contract_001/v56_seed_dependency_blocker_rows.csv ] &&
       [ -f results/v1_0_pm_pr_claim_slice_gate/gate_001/v56_replay_acceptance_evidence_rows.csv ]; then
      tools/verify_artifact.py v56-replay v56/replay_contract.json \
        --summary results/v56_ruler_longbench_expanded_contract_summary.csv \
        --blocker-ledger results/v56_ruler_longbench_expanded_contract/contract_001/v56_seed_dependency_blocker_rows.csv \
        --artifact-ledger results/v1_0_pm_pr_claim_slice_gate/gate_001/v56_replay_acceptance_evidence_rows.csv >/dev/null
    else
      tools/verify_artifact.py v56-replay v56/replay_contract.json >/dev/null
    fi
  fi
  if [ -f benchmarks/v53_source_bound_freeze.json ]; then
    if [ -f results/v53i_complete_source_query_instantiation_summary.csv ] &&
       [ -f results/v53t_complete_source_audit_readiness_gate_summary.csv ] &&
       [ -f results/v53ap_complete_source_abgh_same_query_measured_summary.csv ] &&
       [ -f results/v53aq_complete_source_abgh_real_adapter_measured_summary.csv ] &&
       [ -f results/v53t_complete_source_audit_readiness_gate/gate_001/complete_source_v1_exit_criteria_rows.csv ]; then
      tools/verify_artifact.py v53-source-benchmark benchmarks/v53_source_bound_freeze.json \
        --v53i-summary results/v53i_complete_source_query_instantiation_summary.csv \
        --v53t-summary results/v53t_complete_source_audit_readiness_gate_summary.csv \
        --v53ap-summary results/v53ap_complete_source_abgh_same_query_measured_summary.csv \
        --v53aq-summary results/v53aq_complete_source_abgh_real_adapter_measured_summary.csv \
        --v1-exit-ledger results/v53t_complete_source_audit_readiness_gate/gate_001/complete_source_v1_exit_criteria_rows.csv >/dev/null
    else
      tools/verify_artifact.py v53-source-benchmark benchmarks/v53_source_bound_freeze.json >/dev/null
    fi
  fi
  if [ -f results/v53t_complete_source_audit_readiness_gate_summary.csv ]; then
    if [ -f results/v53t_complete_source_audit_readiness_gate/gate_001/source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv ]; then
      tools/verify_artifact.py v53-public-source-manifest results/v53t_complete_source_audit_readiness_gate_summary.csv \
        --repo-ledger results/v53t_complete_source_audit_readiness_gate/gate_001/source_v53i/source_v53h/source_v53g/complete_source_repo_coverage_rows.csv >/dev/null
    else
      tools/verify_artifact.py v53-public-source-manifest results/v53t_complete_source_audit_readiness_gate_summary.csv >/dev/null
    fi
  fi
  if [ -f v54/grounded_generation_contract.json ]; then
    if [ -f results/v54c_complete_source_grounded_generation_1000_summary.csv ]; then
      tools/verify_artifact.py v54-grounded-generation v54/grounded_generation_contract.json \
        --summary results/v54c_complete_source_grounded_generation_1000_summary.csv >/dev/null
    else
      tools/verify_artifact.py v54-grounded-generation v54/grounded_generation_contract.json >/dev/null
    fi
  fi
  if [ -f results/v59e_one_command_pm_foundation_demo_summary.csv ]; then
    if [ -f results/v59e_one_command_pm_foundation_demo/pm_foundation_001/pm_foundation_demo_gate_rows.csv ]; then
      tools/verify_artifact.py v59-pm-foundation-demo results/v59e_one_command_pm_foundation_demo_summary.csv \
        --gate-ledger results/v59e_one_command_pm_foundation_demo/pm_foundation_001/pm_foundation_demo_gate_rows.csv >/dev/null
    else
      tools/verify_artifact.py v59-pm-foundation-demo results/v59e_one_command_pm_foundation_demo_summary.csv >/dev/null
    fi
  fi
  if [ -f v58/blind_eval_real.json ]; then
    if [ -f results/v1_0_pm_pr_claim_slice_gate/gate_001/v58_real_execution_readiness_rows.csv ] &&
       [ -f results/v59e_one_command_pm_foundation_demo/pm_foundation_001/v58_blind_eval_required_artifact_rows.csv ] &&
       [ -f results/v59e_one_command_pm_foundation_demo/pm_foundation_001/v58_blind_eval_return_template_rows.csv ]; then
      tools/verify_artifact.py v58-blind-eval v58/blind_eval_real.json \
        --readiness-ledger results/v1_0_pm_pr_claim_slice_gate/gate_001/v58_real_execution_readiness_rows.csv \
        --artifact-ledger results/v59e_one_command_pm_foundation_demo/pm_foundation_001/v58_blind_eval_required_artifact_rows.csv \
        --template-ledger results/v59e_one_command_pm_foundation_demo/pm_foundation_001/v58_blind_eval_return_template_rows.csv >/dev/null
    else
      tools/verify_artifact.py v58-blind-eval v58/blind_eval_real.json >/dev/null
    fi
  fi
  if [ -f operations/review_return_workflow.json ]; then
    if [ -f results/v53s_complete_source_review_return_intake_summary.csv ] &&
       [ -f results/v58d_blind_review_return_intake_summary.csv ] &&
       [ -f results/v61af_checkpoint_warehouse_operator_bundle_summary.csv ] &&
       [ -f results/v61hv_post_hu_first_real_slice_replacements_to_readiness_no_replay_pipeline_summary.csv ]; then
      tools/verify_artifact.py review-return-workflow operations/review_return_workflow.json \
        --v53s-summary results/v53s_complete_source_review_return_intake_summary.csv \
        --v58d-summary results/v58d_blind_review_return_intake_summary.csv \
        --v61af-summary results/v61af_checkpoint_warehouse_operator_bundle_summary.csv \
        --v61hv-summary results/v61hv_post_hu_first_real_slice_replacements_to_readiness_no_replay_pipeline_summary.csv >/dev/null
    else
      tools/verify_artifact.py review-return-workflow operations/review_return_workflow.json >/dev/null
    fi
  fi
  if [ -f v61/one_token_path.json ]; then
    if [ -f results/v61aa_hotset_tensor_slice_verifier_summary.csv ] &&
       [ -f results/v61ab_hotset_tensor_tile_quant_probe_summary.csv ]; then
      tools/verify_artifact.py v61-one-token v61/one_token_path.json \
        --v61aa-summary results/v61aa_hotset_tensor_slice_verifier_summary.csv \
        --v61ab-summary results/v61ab_hotset_tensor_tile_quant_probe_summary.csv >/dev/null
      if [ -d results/v61ab_hotset_tensor_tile_quant_probe/probe_001 ]; then
        tools/verify_artifact.py v61ab-tile-probe \
          results/v61ab_hotset_tensor_tile_quant_probe_summary.csv \
          --run-dir results/v61ab_hotset_tensor_tile_quant_probe/probe_001 >/dev/null
      fi
    else
      tools/verify_artifact.py v61-one-token v61/one_token_path.json >/dev/null
    fi
  fi
  pipeline_files=""
  for pipeline_file in pipelines/v52.yaml pipelines/v53.yaml pipelines/v54.yaml pipelines/v58.yaml pipelines/v61.yaml; do
    if [ -f "$pipeline_file" ]; then
      pipeline_files="$pipeline_files $pipeline_file"
    fi
  done
  if [ -n "$pipeline_files" ]; then
    # shellcheck disable=SC2086
    tools/verify_artifact.py pipeline $pipeline_files >/dev/null
  fi
fi

echo "verify ok"
