#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "==> ai wrapper shell syntax"
bash -n scripts/ai-dangerous-command-check.sh scripts/ai-cursor-network-check.sh scripts/ai-worker-cursor.sh scripts/ai-worker-opencode.sh scripts/ai-preflight.sh scripts/ai-verify.sh scripts/audit_my_repo.sh scripts/audit_my_repo_pr.sh scripts/run_minimal_demo.sh
if [ -f experiments/test_audit_my_repo_product_entrypoint.sh ]; then
  bash -n experiments/test_audit_my_repo_product_entrypoint.sh
fi
if [ -f experiments/test_audit_my_repo_negative_controls.sh ]; then
  bash -n experiments/test_audit_my_repo_negative_controls.sh
fi
if [ -f experiments/test_pr_split_branch_policy.sh ]; then
  bash -n experiments/test_pr_split_branch_policy.sh
fi
if [ -f experiments/test_v02_causal_next_byte_evaluation.sh ]; then
  bash -n experiments/test_v02_causal_next_byte_evaluation.sh
fi
if [ -f experiments/run_v53u_complete_source_de_open_weight_evidence_intake.sh ]; then
  bash -n experiments/run_v53u_complete_source_de_open_weight_evidence_intake.sh
fi
if [ -f experiments/test_v53u_complete_source_de_open_weight_evidence_intake.sh ]; then
  bash -n experiments/test_v53u_complete_source_de_open_weight_evidence_intake.sh
fi
if [ -f experiments/run_v54d_source_verified_route_scorer_calibration.sh ]; then
  bash -n experiments/run_v54d_source_verified_route_scorer_calibration.sh
fi
if [ -f experiments/test_v54d_source_verified_route_scorer_calibration.sh ]; then
  bash -n experiments/test_v54d_source_verified_route_scorer_calibration.sh
fi
if [ -f experiments/run_v54e_free_running_non_attention_decoder_contract.sh ]; then
  bash -n experiments/run_v54e_free_running_non_attention_decoder_contract.sh
fi
if [ -f experiments/test_v54e_free_running_non_attention_decoder_contract.sh ]; then
  bash -n experiments/test_v54e_free_running_non_attention_decoder_contract.sh
fi
if [ -f experiments/run_v54f_free_running_generation_evidence_intake.sh ]; then
  bash -n experiments/run_v54f_free_running_generation_evidence_intake.sh
fi
if [ -f experiments/test_v54f_free_running_generation_evidence_intake.sh ]; then
  bash -n experiments/test_v54f_free_running_generation_evidence_intake.sh
fi

echo "==> json"
python3 -m json.tool opencode.json >/dev/null
if [ -f schemas/pipeline.schema.json ]; then
  python3 -m json.tool schemas/pipeline.schema.json >/dev/null
fi
if [ -f schemas/pr_split.schema.json ]; then
  python3 -m json.tool schemas/pr_split.schema.json >/dev/null
fi
if [ -f schemas/typed_readiness.schema.json ]; then
  python3 -m json.tool schemas/typed_readiness.schema.json >/dev/null
fi
if [ -f schemas/leakage_contract.schema.json ]; then
  python3 -m json.tool schemas/leakage_contract.schema.json >/dev/null
fi
if [ -f schemas/baseline_admission.schema.json ]; then
  python3 -m json.tool schemas/baseline_admission.schema.json >/dev/null
fi
if [ -f schemas/v52_adapter_guard.schema.json ]; then
  python3 -m json.tool schemas/v52_adapter_guard.schema.json >/dev/null
fi
if [ -f schemas/v50_auditor_correctness.schema.json ]; then
  python3 -m json.tool schemas/v50_auditor_correctness.schema.json >/dev/null
fi
if [ -f schemas/v53_source_benchmark.schema.json ]; then
  python3 -m json.tool schemas/v53_source_benchmark.schema.json >/dev/null
fi
if [ -f schemas/v58_blind_eval.schema.json ]; then
  python3 -m json.tool schemas/v58_blind_eval.schema.json >/dev/null
fi
if [ -f schemas/review_return_workflow.schema.json ]; then
  python3 -m json.tool schemas/review_return_workflow.schema.json >/dev/null
fi
if [ -f schemas/v61_one_token_path.schema.json ]; then
  python3 -m json.tool schemas/v61_one_token_path.schema.json >/dev/null
fi
if [ -f schemas/local_repo_audit_output.schema.json ]; then
  python3 -m json.tool schemas/local_repo_audit_output.schema.json >/dev/null
fi
if [ -f schemas/local_repo_audit_exit_code_contract.schema.json ]; then
  python3 -m json.tool schemas/local_repo_audit_exit_code_contract.schema.json >/dev/null
fi
if [ -f schemas/local_repo_audit_invocation.schema.json ]; then
  python3 -m json.tool schemas/local_repo_audit_invocation.schema.json >/dev/null
fi
if [ -f schemas/local_repo_audit_summary.schema.json ]; then
  python3 -m json.tool schemas/local_repo_audit_summary.schema.json >/dev/null
fi
if [ -f schemas/local_repo_audit_plugin_registry.schema.json ]; then
  python3 -m json.tool schemas/local_repo_audit_plugin_registry.schema.json >/dev/null
fi
if [ -f schemas/local_repo_audit_plugin_rules.schema.json ]; then
  python3 -m json.tool schemas/local_repo_audit_plugin_rules.schema.json >/dev/null
fi
if [ -f schemas/local_repo_audit_resource_envelope.schema.json ]; then
  python3 -m json.tool schemas/local_repo_audit_resource_envelope.schema.json >/dev/null
fi
if [ -f schemas/local_repo_audit_source_snapshot.schema.json ]; then
  python3 -m json.tool schemas/local_repo_audit_source_snapshot.schema.json >/dev/null
fi
if [ -f v54/free_running_generation_evidence_intake_contract.json ]; then
  python3 -m json.tool v54/free_running_generation_evidence_intake_contract.json >/dev/null
fi
if [ -f v54/source_verified_route_scorer_calibration_contract.json ]; then
  python3 -m json.tool v54/source_verified_route_scorer_calibration_contract.json >/dev/null
fi
if [ -f v54/free_running_non_attention_decoder_contract.json ]; then
  python3 -m json.tool v54/free_running_non_attention_decoder_contract.json >/dev/null
fi
for schema_file in schemas/local_repo_audit_*.schema.json; do
  [ -f "$schema_file" ] || continue
  python3 -m json.tool "$schema_file" >/dev/null
done
if [ -f pr_slices/pr2.json ]; then
  python3 -m json.tool pr_slices/pr2.json >/dev/null
fi
if [ -f readiness/typed_ready.json ]; then
  python3 -m json.tool readiness/typed_ready.json >/dev/null
fi
if [ -f leakage/retrieval_model_visible.json ]; then
  python3 -m json.tool leakage/retrieval_model_visible.json >/dev/null
fi
if [ -f baselines/de_30b70b_real.json ]; then
  python3 -m json.tool baselines/de_30b70b_real.json >/dev/null
fi
if [ -f baselines/v53u_de_open_weight_evidence_intake_contract.json ]; then
  python3 -m json.tool baselines/v53u_de_open_weight_evidence_intake_contract.json >/dev/null
fi
if [ -f baselines/v52_adapter_guard.json ]; then
  python3 -m json.tool baselines/v52_adapter_guard.json >/dev/null
fi
if [ -f audits/v50_public_repo_auditor_correctness.json ]; then
  python3 -m json.tool audits/v50_public_repo_auditor_correctness.json >/dev/null
fi
if [ -f benchmarks/v53_source_bound_freeze.json ]; then
  python3 -m json.tool benchmarks/v53_source_bound_freeze.json >/dev/null
fi
if [ -f v58/blind_eval_real.json ]; then
  python3 -m json.tool v58/blind_eval_real.json >/dev/null
fi
if [ -f operations/review_return_workflow.json ]; then
  python3 -m json.tool operations/review_return_workflow.json >/dev/null
fi
if [ -f v61/one_token_path.json ]; then
  python3 -m json.tool v61/one_token_path.json >/dev/null
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
  if [ -x experiments/test_v02_causal_next_byte_evaluation.sh ]; then
    experiments/test_v02_causal_next_byte_evaluation.sh >/dev/null
  fi
fi

echo "==> required orchestration files"
test -f AGENTS.md
test -f .codex/config.toml
test -f opencode.json
test -f docs/ai/GOAL-LOOP-PLAYBOOK.md
test -f docs/ai/profiles/deep-learning-research.md
test -f docs/ai/prompts/deep_learning_research_goal_start.md
test -f docs/ai/prompts/opencode_worker_slice.md
test -f docs/ai/prompts/cursor_worker_slice.md
test -f docs/ai/prompts/internal_subagent_worker_slice.md
test -x scripts/ai-cursor-network-check.sh
test -x scripts/ai-worker-cursor.sh
test -x scripts/ai-worker-opencode.sh

echo "==> ci workflow contract"
if [ -x tools/verify_ci_workflows.py ]; then
  tools/verify_ci_workflows.py . >/dev/null
else
  python3 tools/verify_ci_workflows.py . >/dev/null
fi

if [ -x tools/verify_artifact.py ]; then
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
    if [ -f scripts/test_typed_readiness_pm_ledger_drift.py ]; then
      python3 scripts/test_typed_readiness_pm_ledger_drift.py >/dev/null
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
  if [ -f baselines/v53u_de_open_weight_evidence_intake_contract.json ]; then
    if [ -f results/v53u_complete_source_de_open_weight_evidence_intake_summary.csv ] &&
       [ -f results/v53u_complete_source_de_open_weight_evidence_intake_decision.csv ]; then
      tools/verify_artifact.py v53u-de-open-weight-intake baselines/v53u_de_open_weight_evidence_intake_contract.json \
        --summary results/v53u_complete_source_de_open_weight_evidence_intake_summary.csv \
        --decision results/v53u_complete_source_de_open_weight_evidence_intake_decision.csv >/dev/null
    else
      tools/verify_artifact.py v53u-de-open-weight-intake baselines/v53u_de_open_weight_evidence_intake_contract.json >/dev/null
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
  if [ -f v54/grounded_generation_contract.json ]; then
    if [ -f results/v54c_complete_source_grounded_generation_1000_summary.csv ]; then
      tools/verify_artifact.py v54-grounded-generation v54/grounded_generation_contract.json \
        --summary results/v54c_complete_source_grounded_generation_1000_summary.csv >/dev/null
    else
      tools/verify_artifact.py v54-grounded-generation v54/grounded_generation_contract.json >/dev/null
    fi
  fi
  if [ -f v54/source_verified_route_scorer_calibration_contract.json ]; then
    if [ -f results/v54d_source_verified_route_scorer_calibration_summary.csv ]; then
      tools/verify_artifact.py v54-route-scorer-calibration v54/source_verified_route_scorer_calibration_contract.json \
        --summary results/v54d_source_verified_route_scorer_calibration_summary.csv >/dev/null
    else
      tools/verify_artifact.py v54-route-scorer-calibration v54/source_verified_route_scorer_calibration_contract.json >/dev/null
    fi
  fi
  if [ -f v54/free_running_non_attention_decoder_contract.json ]; then
    if [ -f results/v54e_free_running_non_attention_decoder_contract_summary.csv ] &&
       [ -f results/v54e_free_running_non_attention_decoder_contract_decision.csv ]; then
      tools/verify_artifact.py v54-free-running-decoder v54/free_running_non_attention_decoder_contract.json \
        --summary results/v54e_free_running_non_attention_decoder_contract_summary.csv \
        --decision results/v54e_free_running_non_attention_decoder_contract_decision.csv >/dev/null
    else
      tools/verify_artifact.py v54-free-running-decoder v54/free_running_non_attention_decoder_contract.json >/dev/null
    fi
  fi
  if [ -f v54/free_running_generation_evidence_intake_contract.json ]; then
    v54f_summary="results/v54f_free_running_generation_evidence_intake_summary.csv"
    v54f_decision="results/v54f_free_running_generation_evidence_intake_decision.csv"
    if [ -f "$v54f_summary" ] || [ -f "$v54f_decision" ]; then
      if [ ! -f "$v54f_summary" ] || [ ! -f "$v54f_decision" ]; then
        echo "v54f generation intake has partial summary/decision artifacts" >&2
        exit 1
      fi
      tools/verify_artifact.py v54-generation-intake v54/free_running_generation_evidence_intake_contract.json \
        --summary "$v54f_summary" \
        --decision "$v54f_decision" >/dev/null
    else
      tools/verify_artifact.py v54-generation-intake v54/free_running_generation_evidence_intake_contract.json >/dev/null
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
    else
      tools/verify_artifact.py v61-one-token v61/one_token_path.json >/dev/null
    fi
  fi
  pipeline_files=""
  for pipeline_file in pipelines/v52.yaml pipelines/v53.yaml pipelines/v58.yaml pipelines/v61.yaml; do
    if [ -f "$pipeline_file" ]; then
      pipeline_files="$pipeline_files $pipeline_file"
    fi
  done
  if [ -n "$pipeline_files" ]; then
    # shellcheck disable=SC2086
    tools/verify_artifact.py pipeline $pipeline_files >/dev/null
  fi
fi

if [ -f experiments/test_pr_split_branch_policy.sh ]; then
  bash experiments/test_pr_split_branch_policy.sh >/dev/null
fi
if [ -x experiments/test_v53u_complete_source_de_open_weight_evidence_intake.sh ]; then
  ./experiments/test_v53u_complete_source_de_open_weight_evidence_intake.sh >/dev/null
fi
if [ -x experiments/test_v54d_source_verified_route_scorer_calibration.sh ]; then
  ./experiments/test_v54d_source_verified_route_scorer_calibration.sh >/dev/null
fi
if [ -x experiments/test_v54e_free_running_non_attention_decoder_contract.sh ]; then
  ./experiments/test_v54e_free_running_non_attention_decoder_contract.sh >/dev/null
fi
if [ -x experiments/test_v54f_free_running_generation_evidence_intake.sh ]; then
  ./experiments/test_v54f_free_running_generation_evidence_intake.sh >/dev/null
fi
if [ -f scripts/test_v54_minimal_real_model_smoke.py ]; then
  python3 scripts/test_v54_minimal_real_model_smoke.py >/dev/null
fi
if [ -f scripts/test_release_review_collection.py ]; then
  python3 scripts/test_release_review_collection.py >/dev/null
fi
if [ -f scripts/test_amr_beta_human_input_packet.py ]; then
  python3 scripts/test_amr_beta_human_input_packet.py >/dev/null
fi
if [ -f scripts/test_amr_beta_repo_intake_validate.py ]; then
  python3 scripts/test_amr_beta_repo_intake_validate.py >/dev/null
fi

echo "==> audit-my-repo product smoke"
if [ -x experiments/test_audit_my_repo_product_entrypoint.sh ]; then
  ./experiments/test_audit_my_repo_product_entrypoint.sh >/dev/null
fi
if [ -x experiments/test_audit_my_repo_negative_controls.sh ]; then
  ./experiments/test_audit_my_repo_negative_controls.sh >/dev/null
fi

echo "verify ok"
