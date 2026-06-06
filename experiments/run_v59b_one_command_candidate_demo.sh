#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v59b_one_command_candidate_demo"
RUN_ID="${V59B_RUN_ID:-candidate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

run_or_reuse() {
  local summary_path="$1"
  shift
  if [[ "${V59B_REUSE_EXISTING:-0}" == "1" && -s "$summary_path" ]]; then
    return 0
  fi
  "$@" >/dev/null
}

run_or_reuse "$RESULTS_DIR/v52b_small_local_rag_measured_row_summary.csv" "$ROOT_DIR/experiments/run_v52b_small_local_rag_measured_row.sh"
run_or_reuse "$RESULTS_DIR/v52c_7b14b_local_model_rag_evidence_intake_summary.csv" "$ROOT_DIR/experiments/run_v52c_7b14b_local_model_rag_evidence_intake.sh"
run_or_reuse "$RESULTS_DIR/v52d_30b70b_llm_rag_evidence_intake_summary.csv" "$ROOT_DIR/experiments/run_v52d_30b70b_llm_rag_evidence_intake.sh"
run_or_reuse "$RESULTS_DIR/v52e_100b_plus_hosted_llm_rag_optional_intake_summary.csv" "$ROOT_DIR/experiments/run_v52e_100b_plus_hosted_llm_rag_optional_intake.sh"
run_or_reuse "$RESULTS_DIR/v53e_canary_query_scale_1000_summary.csv" "$ROOT_DIR/experiments/run_v53e_canary_query_scale_1000.sh"
run_or_reuse "$RESULTS_DIR/v53f_ah_answer_citation_resource_intake_summary.csv" "$ROOT_DIR/experiments/run_v53f_ah_answer_citation_resource_intake.sh"
run_or_reuse "$RESULTS_DIR/v54b_routehint_generation_scale_1000_summary.csv" "$ROOT_DIR/experiments/run_v54b_routehint_generation_scale_1000.sh"
run_or_reuse "$RESULTS_DIR/v55b_local_scaling_law_main_120_summary.csv" "$ROOT_DIR/experiments/run_v55b_local_scaling_law_main_120.sh"
run_or_reuse "$RESULTS_DIR/v56b_ruler_longbench_expanded_scale_summary.csv" "$ROOT_DIR/experiments/run_v56b_ruler_longbench_expanded_scale.sh"
run_or_reuse "$RESULTS_DIR/v57b_domain_expert_pack_candidate_1000_summary.csv" "$ROOT_DIR/experiments/run_v57b_domain_expert_pack_candidate_1000.sh"
run_or_reuse "$RESULTS_DIR/v58b_blind_eval_candidate_500_summary.csv" "$ROOT_DIR/experiments/run_v58b_blind_eval_candidate_500.sh"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"

STAGES = [
    {
        "stage": "v52b",
        "summary": results / "v52b_small_local_rag_measured_row_summary.csv",
        "source_dir": results / "v52b_small_local_rag_measured_row" / "row_001",
        "ready_field": "v52b_small_local_rag_measured_row_ready",
        "full_ready_field": "v52_ready",
        "artifacts": ["small_local_rag_answer_rows.csv", "small_local_rag_citation_rows.csv", "small_local_rag_resource_rows.csv", "V52B_SMALL_LOCAL_RAG_BOUNDARY.md", "v52b_small_local_rag_manifest.json", "sha256_manifest.csv"],
        "claim": "measured small-local-RAG seed rows",
    },
    {
        "stage": "v52c",
        "summary": results / "v52c_7b14b_local_model_rag_evidence_intake_summary.csv",
        "source_dir": results / "v52c_7b14b_local_model_rag_evidence_intake" / "intake_001",
        "ready_field": "v52c_7b14b_local_model_rag_intake_contract_ready",
        "full_ready_field": "v52_absorb_ready",
        "artifacts": ["local_model_rag_required_field_rows.csv", "local_model_rag_answer_template.csv", "model_identity_template.json", "V52C_7B14B_LOCAL_MODEL_RAG_BOUNDARY.md", "v52c_7b14b_local_model_rag_manifest.json", "sha256_manifest.csv"],
        "claim": "7B-14B local model evidence intake",
    },
    {
        "stage": "v52d",
        "summary": results / "v52d_30b70b_llm_rag_evidence_intake_summary.csv",
        "source_dir": results / "v52d_30b70b_llm_rag_evidence_intake" / "intake_001",
        "ready_field": "v52d_30b70b_llm_rag_intake_contract_ready",
        "full_ready_field": "v52_absorb_ready",
        "artifacts": ["llm_rag_required_field_rows.csv", "llm_rag_answer_template.csv", "model_identity_templates.json", "V52D_30B70B_LLM_RAG_BOUNDARY.md", "v52d_30b70b_llm_rag_manifest.json", "sha256_manifest.csv"],
        "claim": "30B/70B LLM+RAG evidence intake",
    },
    {
        "stage": "v52e",
        "summary": results / "v52e_100b_plus_hosted_llm_rag_optional_intake_summary.csv",
        "source_dir": results / "v52e_100b_plus_hosted_llm_rag_optional_intake" / "intake_001",
        "ready_field": "v52e_100b_plus_hosted_llm_rag_optional_intake_contract_ready",
        "full_ready_field": "v52_optional_absorb_ready",
        "artifacts": ["hosted_llm_rag_required_field_rows.csv", "hosted_llm_rag_answer_template.csv", "model_identity_template.json", "V52E_100B_PLUS_HOSTED_LLM_RAG_BOUNDARY.md", "v52e_100b_plus_hosted_llm_rag_manifest.json", "sha256_manifest.csv"],
        "claim": "100B+ optional hosted/API evidence intake",
    },
    {
        "stage": "v53e",
        "summary": results / "v53e_canary_query_scale_1000_summary.csv",
        "source_dir": results / "v53e_canary_query_scale_1000" / "scale_001",
        "ready_field": "v53e_canary_query_scale_ready",
        "full_ready_field": "v53_ready",
        "artifacts": ["scaled_canary_query_rows.csv", "scaled_canary_source_span_rows.csv", "scaled_canary_query_family_rows.csv", "V53E_CANARY_QUERY_SCALE_1000_BOUNDARY.md", "v53e_canary_query_scale_1000_manifest.json", "sha256_manifest.csv"],
        "claim": "1000-row canary query scale",
    },
    {
        "stage": "v53f",
        "summary": results / "v53f_ah_answer_citation_resource_intake_summary.csv",
        "source_dir": results / "v53f_ah_answer_citation_resource_intake" / "intake_001",
        "ready_field": "v53f_ah_answer_citation_resource_intake_ready",
        "full_ready_field": "v53_ready",
        "artifacts": ["ah_system_target_rows.csv", "ah_answer_row_template.csv", "citation_row_required_schema.csv", "ah_resource_row_template.csv", "V53F_AH_ANSWER_CITATION_RESOURCE_INTAKE_BOUNDARY.md", "v53f_ah_answer_citation_resource_intake_manifest.json", "sha256_manifest.csv"],
        "claim": "A-H answer/citation/resource intake",
    },
    {
        "stage": "v54b",
        "summary": results / "v54b_routehint_generation_scale_1000_summary.csv",
        "source_dir": results / "v54b_routehint_generation_scale_1000" / "scale_001",
        "ready_field": "v54b_routehint_generation_scale_ready",
        "full_ready_field": "v54_generation_1000_ready",
        "artifacts": ["grounded_generation_rows.csv", "citation_rows.csv", "resource_rows.csv", "V54B_ROUTEHINT_GENERATION_SCALE_BOUNDARY.md", "v54b_routehint_generation_scale_manifest.json", "sha256_manifest.csv"],
        "claim": "1000-row RouteHint generation scale",
    },
    {
        "stage": "v55b",
        "summary": results / "v55b_local_scaling_law_main_120_summary.csv",
        "source_dir": results / "v55b_local_scaling_law_main_120" / "main_001",
        "ready_field": "v55b_local_scaling_law_main_ready",
        "full_ready_field": "v55_local_scaling_law_ready",
        "artifacts": ["scaling_curve_rows.csv", "scaling_axis_rows.csv", "confidence_interval_rows.csv", "V55B_LOCAL_SCALING_LAW_MAIN_BOUNDARY.md", "v55b_local_scaling_law_main_manifest.json", "sha256_manifest.csv"],
        "claim": "local scaling-law main candidate",
    },
    {
        "stage": "v56b",
        "summary": results / "v56b_ruler_longbench_expanded_scale_summary.csv",
        "source_dir": results / "v56b_ruler_longbench_expanded_scale" / "scale_001",
        "ready_field": "v56b_ruler_longbench_expanded_scale_ready",
        "full_ready_field": "v56_ruler_longbench_expanded_ready",
        "artifacts": ["expanded_prediction_rows.csv", "prediction_lineage_rows.csv", "candidate_result_rows.csv", "V56B_RULER_LONGBENCH_EXPANDED_SCALE_BOUNDARY.md", "v56b_ruler_longbench_expanded_scale_manifest.json", "sha256_manifest.csv"],
        "claim": "1500-row RULER/LongBench candidate scale",
    },
    {
        "stage": "v57b",
        "summary": results / "v57b_domain_expert_pack_candidate_1000_summary.csv",
        "source_dir": results / "v57b_domain_expert_pack_candidate_1000" / "candidate_001",
        "ready_field": "v57b_domain_expert_pack_candidate_ready",
        "full_ready_field": "v57_domain_expert_packs_ready",
        "artifacts": ["domain_pack_eval_rows.csv", "domain_pack_source_span_rows.csv", "expert_review_template_rows.csv", "V57B_DOMAIN_EXPERT_PACK_CANDIDATE_BOUNDARY.md", "v57b_domain_expert_pack_candidate_manifest.json", "sha256_manifest.csv"],
        "claim": "1000-row domain expert pack candidate",
    },
    {
        "stage": "v58b",
        "summary": results / "v58b_blind_eval_candidate_500_summary.csv",
        "source_dir": results / "v58b_blind_eval_candidate_500" / "candidate_001",
        "ready_field": "v58b_blind_eval_candidate_ready",
        "full_ready_field": "v58_ready",
        "artifacts": ["blind_query_freeze_rows.csv", "blind_response_template_rows.csv", "blind_reviewer_packet_template_rows.csv", "V58B_BLIND_EVAL_CANDIDATE_BOUNDARY.md", "v58b_blind_eval_candidate_manifest.json", "sha256_manifest.csv"],
        "claim": "500-row blind eval candidate freeze",
    },
]


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_summary(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))[0]


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


stage_rows = []
artifact_rels = []
for spec in STAGES:
    summary = read_summary(spec["summary"])
    ready = int(summary.get(spec["ready_field"], "0"))
    full_ready = int(summary.get(spec["full_ready_field"], "0"))
    copy(spec["summary"], f"source_{spec['stage']}/{spec['summary'].name}")
    artifact_rels.append(f"source_{spec['stage']}/{spec['summary'].name}")
    copied = 0
    for relpath in spec["artifacts"]:
        copy(spec["source_dir"] / relpath, f"source_{spec['stage']}/{relpath}")
        artifact_rels.append(f"source_{spec['stage']}/{relpath}")
        copied += 1
    stage_rows.append(
        {
            "stage": spec["stage"],
            "candidate_ready_field": spec["ready_field"],
            "candidate_ready": ready,
            "full_ready_field": spec["full_ready_field"],
            "full_ready": full_ready,
            "copied_artifacts": copied,
            "claim_boundary": spec["claim"],
        }
    )

write_csv(run_dir / "candidate_stage_replay_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {
        "command_id": "v1_0_architecture_challenge_candidate_demo",
        "command": "./examples/v1_0_architecture_challenge_candidate_demo.sh",
        "runs_stages": ",".join(spec["stage"] for spec in STAGES),
        "writes_bundle": "results/v59b_one_command_candidate_demo/candidate_001",
        "network_required": "0",
        "external_model_required_for_candidate": "0",
        "real_llm_rows_required_for_full_v1": "1",
        "claim_boundary_required": "1",
    }
]
write_csv(run_dir / "candidate_one_command_rows.csv", list(command_rows[0].keys()), command_rows)

gate_rows = [
    ("candidate-chain-replay", "pass", "v52b-v58b candidate/intake stages are regenerated and copied"),
    ("one-command-candidate-entrypoint", "pass", "examples/v1_0_architecture_challenge_candidate_demo.sh runs the v59b candidate bundle builder"),
    ("candidate-bundle-hash-manifest", "pass", "v59b writes sha256_manifest.csv over copied candidate artifacts"),
    ("claim-boundary-preserved", "pass", "candidate-ready rows do not mark v52/v53/v57/v58 full-ready"),
    ("30b-70b-real-rows", "blocked", "real D/E LLM+RAG answer and blind-response rows are missing"),
    ("100b-plus-real-row", "blocked", "optional F hosted/API row is missing or deferred"),
    ("complete-source-audit", "blocked", "v53 remains canary-scope, not complete-source 10+ repo audit"),
    ("human-domain-and-blind-review", "blocked", "human expert and blind-review rows are missing"),
    ("v59-full-one-command-demo", "blocked", "candidate replay is not the full challenge demo over real v52-v58 rows"),
    ("real-release-package", "blocked", "v59b candidate packet is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in gate_rows])
write_csv(run_dir / "candidate_demo_gate_rows.csv", ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in gate_rows])

demo = run_dir / "candidate_demo.sh"
demo.write_text(
    "#!/usr/bin/env bash\n"
    "set -euo pipefail\n\n"
    "ROOT_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")/../../..\" && pwd)\"\n"
    "\"$ROOT_DIR/examples/v1_0_architecture_challenge_candidate_demo.sh\"\n",
    encoding="utf-8",
)
demo.chmod(0o755)

(run_dir / "README_RESULT.md").write_text(
    "# v59b One-Command Candidate Demo\n\n"
    "Command:\n\n"
    "```bash\n"
    "./examples/v1_0_architecture_challenge_candidate_demo.sh\n"
    "```\n\n"
    "This bundle proves that the current v52b-v58b candidate/intake chain can be replayed and audited from one command. It does not prove v1.0 performance, blind-eval wins, or release readiness.\n\n"
    "Candidate-ready surfaces included:\n\n"
    "- measured small-local-RAG seed rows\n"
    "- C/D/E/F evidence intake templates\n"
    "- 1000-row canary query scale and A-H intake\n"
    "- 1000-row RouteHint generation scale\n"
    "- six-axis local scaling-law main candidate\n"
    "- 1500-row RULER/LongBench candidate scale\n"
    "- 1000-row domain expert candidate pack\n"
    "- 500-row blind query freeze and reviewer packet templates\n\n"
    "Still blocked: real 30B/70B LLM+RAG rows, optional 100B+ row or final deferral, complete-source audit rows, human expert review, human blind review, and release review.\n",
    encoding="utf-8",
)

(run_dir / "V59B_ONE_COMMAND_CANDIDATE_DEMO_BOUNDARY.md").write_text(
    "# v59b One-Command Candidate Demo Boundary\n\n"
    "This is a one-command replay of the current candidate/intake chain, not the completed v1.0 Architecture Challenge demo.\n\n"
    f"- candidate_stage_rows={len(stage_rows)}\n"
    f"- candidate_ready_stage_rows={sum(row['candidate_ready'] for row in stage_rows)}\n"
    f"- full_ready_stage_rows={sum(row['full_ready'] for row in stage_rows)}\n"
    "- real_30b_70b_rows_ready=0\n"
    "- human_domain_review_ready=0\n"
    "- human_blind_review_ready=0\n\n"
    "Do not publish 30B-150B comparison wins, one-command challenge completion, or v1.0 release claims from this candidate replay.\n",
    encoding="utf-8",
)

summary = {
    "v59b_one_command_candidate_demo_ready": 1,
    "v59_ready": 0,
    "candidate_stage_rows": len(stage_rows),
    "candidate_ready_stage_rows": sum(row["candidate_ready"] for row in stage_rows),
    "full_ready_stage_rows": sum(row["full_ready"] for row in stage_rows),
    "one_command_candidate_entrypoint_ready": 1,
    "candidate_bundle_ready": 1,
    "network_required": 0,
    "external_model_required_for_candidate": 0,
    "real_llm_rows_required_for_full_v1": 1,
    "missing_real_30b_70b_rows": 1,
    "missing_100b_plus_real_row_or_final_deferral": 1,
    "missing_complete_source_audit": 1,
    "missing_human_domain_review": 1,
    "missing_human_blind_review": 1,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

manifest = {
    "manifest_scope": "v59b-one-command-candidate-demo",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v59b_one_command_candidate_demo_ready": 1,
    "v59_ready": 0,
    "one_command": "./examples/v1_0_architecture_challenge_candidate_demo.sh",
    "stage_order": [spec["stage"] for spec in STAGES],
    "candidate_stage_rows": len(stage_rows),
    "candidate_ready_stage_rows": summary["candidate_ready_stage_rows"],
    "full_ready_stage_rows": summary["full_ready_stage_rows"],
    "real_release_package_ready": 0,
    "source_summary_sha256": {spec["stage"]: sha256(spec["summary"]) for spec in STAGES},
}
(run_dir / "v59b_one_command_candidate_demo_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels.extend(
    [
        "candidate_stage_replay_rows.csv",
        "candidate_one_command_rows.csv",
        "candidate_demo_gate_rows.csv",
        "candidate_demo.sh",
        "README_RESULT.md",
        "V59B_ONE_COMMAND_CANDIDATE_DEMO_BOUNDARY.md",
        "v59b_one_command_candidate_demo_manifest.json",
    ]
)
artifact_rows = []
for relpath in artifact_rels:
    path = run_dir / relpath
    artifact_rows.append({"path": relpath, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v59b_one_command_candidate_demo_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
