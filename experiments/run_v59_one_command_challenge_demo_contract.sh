#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v59_one_command_challenge_demo_contract"
RUN_ID="${V59_CONTRACT_RUN_ID:-contract_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
V59_ALLOW_STAGE_REBUILD="${V59_ALLOW_STAGE_REBUILD:-0}"
STAGE_REBUILD_EXECUTED=0

required_stage_files=(
  "$RESULTS_DIR/v52_llm_rag_baseline_war_summary.csv"
  "$RESULTS_DIR/v52_llm_rag_baseline_war/baseline_001/baseline_registry.csv"
  "$RESULTS_DIR/v52_llm_rag_baseline_war/baseline_001/evaluation_contract_rows.csv"
  "$RESULTS_DIR/v52_llm_rag_baseline_war/baseline_001/V52_BASELINE_WAR_BOUNDARY.md"
  "$RESULTS_DIR/v52_llm_rag_baseline_war/baseline_001/v52_llm_rag_baseline_war_manifest.json"
  "$RESULTS_DIR/v52_llm_rag_baseline_war/baseline_001/sha256_manifest.csv"
  "$RESULTS_DIR/v53_public_repo_code_doc_audit_summary.csv"
  "$RESULTS_DIR/v53_public_repo_code_doc_audit/audit_001/target_repo_rows.csv"
  "$RESULTS_DIR/v53_public_repo_code_doc_audit/audit_001/query_scale_contract_rows.csv"
  "$RESULTS_DIR/v53_public_repo_code_doc_audit/audit_001/V53_PUBLIC_REPO_CODE_DOC_AUDIT_BOUNDARY.md"
  "$RESULTS_DIR/v53_public_repo_code_doc_audit/audit_001/v53_public_repo_code_doc_audit_manifest.json"
  "$RESULTS_DIR/v53_public_repo_code_doc_audit/audit_001/sha256_manifest.csv"
  "$RESULTS_DIR/v54_routehint_generation_1000_contract_summary.csv"
  "$RESULTS_DIR/v54_routehint_generation_1000_contract/contract_001/domain_generation_target_rows.csv"
  "$RESULTS_DIR/v54_routehint_generation_1000_contract/contract_001/generation_invariant_rows.csv"
  "$RESULTS_DIR/v54_routehint_generation_1000_contract/contract_001/V54_ROUTEHINT_GENERATION_1000_BOUNDARY.md"
  "$RESULTS_DIR/v54_routehint_generation_1000_contract/contract_001/v54_routehint_generation_1000_manifest.json"
  "$RESULTS_DIR/v54_routehint_generation_1000_contract/contract_001/sha256_manifest.csv"
  "$RESULTS_DIR/v55_local_scaling_law_main_contract_summary.csv"
  "$RESULTS_DIR/v55_local_scaling_law_main_contract/contract_001/scaling_axis_target_rows.csv"
  "$RESULTS_DIR/v55_local_scaling_law_main_contract/contract_001/scaling_fit_contract_rows.csv"
  "$RESULTS_DIR/v55_local_scaling_law_main_contract/contract_001/V55_LOCAL_SCALING_LAW_BOUNDARY.md"
  "$RESULTS_DIR/v55_local_scaling_law_main_contract/contract_001/v55_local_scaling_law_manifest.json"
  "$RESULTS_DIR/v55_local_scaling_law_main_contract/contract_001/sha256_manifest.csv"
  "$RESULTS_DIR/v56_ruler_longbench_expanded_contract_summary.csv"
  "$RESULTS_DIR/v56_ruler_longbench_expanded_contract/contract_001/benchmark_family_target_rows.csv"
  "$RESULTS_DIR/v56_ruler_longbench_expanded_contract/contract_001/expanded_benchmark_artifact_contract_rows.csv"
  "$RESULTS_DIR/v56_ruler_longbench_expanded_contract/contract_001/V56_RULER_LONGBENCH_EXPANDED_BOUNDARY.md"
  "$RESULTS_DIR/v56_ruler_longbench_expanded_contract/contract_001/v56_ruler_longbench_expanded_manifest.json"
  "$RESULTS_DIR/v56_ruler_longbench_expanded_contract/contract_001/sha256_manifest.csv"
  "$RESULTS_DIR/v57_domain_expert_packs_contract_summary.csv"
  "$RESULTS_DIR/v57_domain_expert_packs_contract/contract_001/domain_pack_target_rows.csv"
  "$RESULTS_DIR/v57_domain_expert_packs_contract/contract_001/expert_review_contract_rows.csv"
  "$RESULTS_DIR/v57_domain_expert_packs_contract/contract_001/V57_DOMAIN_EXPERT_PACKS_BOUNDARY.md"
  "$RESULTS_DIR/v57_domain_expert_packs_contract/contract_001/v57_domain_expert_packs_manifest.json"
  "$RESULTS_DIR/v57_domain_expert_packs_contract/contract_001/sha256_manifest.csv"
  "$RESULTS_DIR/v58_blind_eval_contract_summary.csv"
  "$RESULTS_DIR/v58_blind_eval_contract/contract_001/blind_system_mapping_rows.csv"
  "$RESULTS_DIR/v58_blind_eval_contract/contract_001/blind_eval_query_contract_rows.csv"
  "$RESULTS_DIR/v58_blind_eval_contract/contract_001/V58_BLIND_EVAL_BOUNDARY.md"
  "$RESULTS_DIR/v58_blind_eval_contract/contract_001/v58_blind_eval_manifest.json"
  "$RESULTS_DIR/v58_blind_eval_contract/contract_001/sha256_manifest.csv"
)

missing_stage_files=()
for required_file in "${required_stage_files[@]}"; do
  if [ ! -s "$required_file" ]; then
    missing_stage_files+=("$required_file")
  fi
done

if [ "${#missing_stage_files[@]}" -gt 0 ]; then
  if [ "$V59_ALLOW_STAGE_REBUILD" != "1" ]; then
    {
      echo "v59 requires existing v52-v58 stage artifacts for offline one-command bundling."
      echo "Refusing implicit stage regeneration because dependencies can reach public source/benchmark refresh paths."
      echo "Set V59_ALLOW_STAGE_REBUILD=1 only with explicit approval to rebuild stage artifacts."
      printf 'missing_stage_artifact=%s\n' "${missing_stage_files[@]}"
    } >&2
    exit 2
  fi
  "$ROOT_DIR/experiments/run_v53_public_repo_code_doc_audit.sh" >/dev/null
  "$ROOT_DIR/experiments/run_v54_routehint_generation_1000_contract.sh" >/dev/null
  "$ROOT_DIR/experiments/run_v55_local_scaling_law_main_contract.sh" >/dev/null
  "$ROOT_DIR/experiments/run_v58_blind_eval_contract.sh" >/dev/null
  STAGE_REBUILD_EXECUTED=1
fi

for required_file in "${required_stage_files[@]}"; do
  if [ ! -s "$required_file" ]; then
    echo "v59 stage artifact still missing after rebuild policy check: $required_file" >&2
    exit 3
  fi
done

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$V59_ALLOW_STAGE_REBUILD" "$STAGE_REBUILD_EXECUTED" <<'PY'
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
stage_rebuild_allowed = int(sys.argv[5] == "1")
stage_rebuild_executed = int(sys.argv[6] == "1")
stage_artifacts_reused = int(not stage_rebuild_executed)
results = root / "results"

summary_files = {
    "v52": results / "v52_llm_rag_baseline_war_summary.csv",
    "v53": results / "v53_public_repo_code_doc_audit_summary.csv",
    "v54": results / "v54_routehint_generation_1000_contract_summary.csv",
    "v55": results / "v55_local_scaling_law_main_contract_summary.csv",
    "v56": results / "v56_ruler_longbench_expanded_contract_summary.csv",
    "v57": results / "v57_domain_expert_packs_contract_summary.csv",
    "v58": results / "v58_blind_eval_contract_summary.csv",
}
summaries = {
    stage: list(csv.DictReader(path.open(newline="", encoding="utf-8")))[0]
    for stage, path in summary_files.items()
}


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


source_dirs = {
    "v52": results / "v52_llm_rag_baseline_war" / "baseline_001",
    "v53": results / "v53_public_repo_code_doc_audit" / "audit_001",
    "v54": results / "v54_routehint_generation_1000_contract" / "contract_001",
    "v55": results / "v55_local_scaling_law_main_contract" / "contract_001",
    "v56": results / "v56_ruler_longbench_expanded_contract" / "contract_001",
    "v57": results / "v57_domain_expert_packs_contract" / "contract_001",
    "v58": results / "v58_blind_eval_contract" / "contract_001",
}
copy_specs = {
    "v52": ["baseline_registry.csv", "evaluation_contract_rows.csv", "V52_BASELINE_WAR_BOUNDARY.md", "v52_llm_rag_baseline_war_manifest.json", "sha256_manifest.csv"],
    "v53": ["target_repo_rows.csv", "query_scale_contract_rows.csv", "V53_PUBLIC_REPO_CODE_DOC_AUDIT_BOUNDARY.md", "v53_public_repo_code_doc_audit_manifest.json", "sha256_manifest.csv"],
    "v54": ["domain_generation_target_rows.csv", "generation_invariant_rows.csv", "V54_ROUTEHINT_GENERATION_1000_BOUNDARY.md", "v54_routehint_generation_1000_manifest.json", "sha256_manifest.csv"],
    "v55": ["scaling_axis_target_rows.csv", "scaling_fit_contract_rows.csv", "V55_LOCAL_SCALING_LAW_BOUNDARY.md", "v55_local_scaling_law_manifest.json", "sha256_manifest.csv"],
    "v56": ["benchmark_family_target_rows.csv", "expanded_benchmark_artifact_contract_rows.csv", "V56_RULER_LONGBENCH_EXPANDED_BOUNDARY.md", "v56_ruler_longbench_expanded_manifest.json", "sha256_manifest.csv"],
    "v57": ["domain_pack_target_rows.csv", "expert_review_contract_rows.csv", "V57_DOMAIN_EXPERT_PACKS_BOUNDARY.md", "v57_domain_expert_packs_manifest.json", "sha256_manifest.csv"],
    "v58": ["blind_system_mapping_rows.csv", "blind_eval_query_contract_rows.csv", "V58_BLIND_EVAL_BOUNDARY.md", "v58_blind_eval_manifest.json", "sha256_manifest.csv"],
}
for stage, rels in copy_specs.items():
    for rel in rels:
        copy(source_dirs[stage] / rel, f"source_{stage}/{rel}")
for stage, path in summary_files.items():
    copy(path, f"source_{stage}/{path.name}")

stage_rows = [
    {
        "stage": "v52",
        "contract_ready_field": "v52_baseline_war_contract_ready",
        "contract_ready": summaries["v52"].get("v52_baseline_war_contract_ready", "0"),
        "full_ready_field": "v52_ready",
        "full_ready": summaries["v52"].get("v52_ready", "0"),
        "missing_reason": "30B/70B LLM+RAG rows missing",
    },
    {
        "stage": "v53",
        "contract_ready_field": "v53_public_repo_code_doc_audit_contract_ready",
        "contract_ready": summaries["v53"].get("v53_public_repo_code_doc_audit_contract_ready", "0"),
        "full_ready_field": "v53_ready",
        "full_ready": summaries["v53"].get("v53_ready", "0"),
        "missing_reason": "10+ repo / 1000+ query audit rows missing",
    },
    {
        "stage": "v54",
        "contract_ready_field": "v54_generation_1000_contract_ready",
        "contract_ready": summaries["v54"].get("v54_generation_1000_contract_ready", "0"),
        "full_ready_field": "v54_generation_1000_ready",
        "full_ready": summaries["v54"].get("v54_generation_1000_ready", "0"),
        "missing_reason": "1000+ generation rows missing",
    },
    {
        "stage": "v55",
        "contract_ready_field": "v55_local_scaling_law_contract_ready",
        "contract_ready": summaries["v55"].get("v55_local_scaling_law_contract_ready", "0"),
        "full_ready_field": "v55_local_scaling_law_ready",
        "full_ready": summaries["v55"].get("v55_local_scaling_law_ready", "0"),
        "missing_reason": "six-axis / 100+ row scaling main run missing",
    },
    {
        "stage": "v56",
        "contract_ready_field": "v56_ruler_longbench_expanded_contract_ready",
        "contract_ready": summaries["v56"].get("v56_ruler_longbench_expanded_contract_ready", "0"),
        "full_ready_field": "v56_ruler_longbench_expanded_ready",
        "full_ready": summaries["v56"].get("v56_ruler_longbench_expanded_ready", "0"),
        "missing_reason": "expanded RULER/LongBench rows missing",
    },
    {
        "stage": "v57",
        "contract_ready_field": "v57_domain_expert_packs_contract_ready",
        "contract_ready": summaries["v57"].get("v57_domain_expert_packs_contract_ready", "0"),
        "full_ready_field": "v57_domain_expert_packs_ready",
        "full_ready": summaries["v57"].get("v57_domain_expert_packs_ready", "0"),
        "missing_reason": "human-reviewed domain pack rows missing",
    },
    {
        "stage": "v58",
        "contract_ready_field": "v58_blind_eval_contract_ready",
        "contract_ready": summaries["v58"].get("v58_blind_eval_contract_ready", "0"),
        "full_ready_field": "v58_ready",
        "full_ready": summaries["v58"].get("v58_ready", "0"),
        "missing_reason": "500+ blind-eval rows and human review missing",
    },
]
write_csv(run_dir / "challenge_stage_contract_rows.csv", list(stage_rows[0].keys()), stage_rows)

command_rows = [
    {
        "command_id": "v1_0_architecture_challenge_demo",
        "command": "./examples/v1_0_architecture_challenge_demo.sh",
        "runs_stages": "v52,v53,v54,v55,v56,v57,v58,v59",
        "writes_bundle": "results/v59_one_command_challenge_demo_contract/contract_001",
        "network_required": "0",
        "external_model_required": "0",
        "external_model_rows_deferred_explicitly": "1",
        "claim_boundary_required": "1",
        "stage_artifacts_reused": str(stage_artifacts_reused),
        "stage_rebuild_allowed": str(stage_rebuild_allowed),
        "stage_rebuild_executed": str(stage_rebuild_executed),
    }
]
write_csv(run_dir / "one_command_demo_rows.csv", list(command_rows[0].keys()), command_rows)

gate_rows = [
    ("v52-v58-contracts", "pass", "all v52-v58 contract scaffolds are produced and copied"),
    ("one-command-entrypoint", "pass", "examples/v1_0_architecture_challenge_demo.sh runs the v59 bundle builder"),
    ("bundle-hash-manifest", "pass", "v59 writes sha256_manifest.csv over copied source artifacts and demo files"),
    ("offline-demo-boundary", "pass", "demo does not require external model credentials or network access"),
    ("stage-rebuild-policy", "pass", f"stage_artifacts_reused={stage_artifacts_reused}; stage_rebuild_allowed={stage_rebuild_allowed}; stage_rebuild_executed={stage_rebuild_executed}"),
    ("30b-70b-real-rows", "blocked", "30B/70B LLM+RAG measured rows are missing"),
    ("public-repo-query-scale", "blocked", "v53 has not reached 10+ repos / 1000+ queries"),
    ("generation-scaling-benchmark-domain-blind-main-runs", "blocked", "v54-v58 remain contract scaffolds, not main evidence rows"),
    ("v59-full-one-command-demo", "blocked", "one-command demo is a contract bundle until v52-v58 real rows exist"),
    ("real-release-package", "blocked", "v59 contract is not a v1.0 release package"),
]
write_csv(
    run_dir / "one_command_demo_gate_rows.csv",
    ["gate", "status", "reason"],
    [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in gate_rows],
)

challenge_demo = run_dir / "challenge_demo.sh"
challenge_demo.write_text(
    "#!/usr/bin/env bash\n"
    "set -euo pipefail\n\n"
    "ROOT_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")/../../..\" && pwd)\"\n"
    "\"$ROOT_DIR/experiments/run_v59_one_command_challenge_demo_contract.sh\"\n",
    encoding="utf-8",
)
challenge_demo.chmod(0o755)

(run_dir / "README_RESULT.md").write_text(
    "# v59 One-Command Challenge Demo Contract\n\n"
    "Command:\n\n"
    "```bash\n"
    "./examples/v1_0_architecture_challenge_demo.sh\n"
    "```\n\n"
    "This bundle proves the one-command entrypoint and artifact contract for the v1.0 Architecture Challenge path. It does not prove v1.0 performance, blind-eval wins, or release readiness.\n\n"
    "Still blocked:\n\n"
    "- real 30B/70B LLM+RAG measured rows\n"
    "- 10+ public repositories and 1000+ code/doc QA rows\n"
    "- 1000+ RouteHint generation rows\n"
    "- six-axis / 100+ row scaling main run\n"
    "- expanded RULER/LongBench main rows\n"
    "- human-reviewed domain packs\n"
    "- 500+ blind-eval rows\n",
    encoding="utf-8",
)

summary = {
    "v59_one_command_challenge_demo_contract_ready": 1,
    "v59_ready": 0,
    "stage_contract_rows": len(stage_rows),
    "contract_ready_stage_rows": sum(int(row["contract_ready"]) for row in stage_rows),
    "full_ready_stage_rows": sum(int(row["full_ready"]) for row in stage_rows),
    "one_command_entrypoint_ready": 1,
    "challenge_bundle_ready": 1,
    "network_required": 0,
    "external_model_required_for_contract": 0,
    "external_model_rows_deferred_explicitly": 1,
    "stage_artifacts_reused": stage_artifacts_reused,
    "stage_rebuild_allowed": stage_rebuild_allowed,
    "stage_rebuild_executed": stage_rebuild_executed,
    "missing_real_30b_70b_rows": 1,
    "missing_public_repo_query_scale": 1,
    "missing_generation_main_rows": 1,
    "missing_scaling_main_rows": 1,
    "missing_expanded_benchmark_rows": 1,
    "missing_domain_expert_pack_rows": 1,
    "missing_blind_eval_rows": 1,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(gate_rows)

(run_dir / "V59_ONE_COMMAND_CHALLENGE_DEMO_BOUNDARY.md").write_text(
    "# v59 One-Command Challenge Demo Boundary\n\n"
    "This is the v59 one-command challenge demo contract scaffold, not the completed v1.0 Architecture Challenge demo.\n\n"
    "Ready:\n\n"
    "- one command entrypoint exists\n"
    "- v52-v58 contract artifacts are assembled into one bundle\n"
    "- demo writes README_RESULT, gate rows, replay manifest, and sha256 manifest\n\n"
    "Refresh policy:\n\n"
    f"- stage_artifacts_reused={stage_artifacts_reused}\n"
    f"- stage_rebuild_allowed={stage_rebuild_allowed}\n"
    f"- stage_rebuild_executed={stage_rebuild_executed}\n"
    "- cached v52-v58 stage artifacts are reused by default; rebuilding requires V59_ALLOW_STAGE_REBUILD=1 and explicit approval\n\n"
    "Still blocked:\n\n"
    "- real 30B/70B/100B+ LLM+RAG rows\n"
    "- full public repo/query scale\n"
    "- generation/scaling/benchmark/domain/blind main rows\n"
    "- release package\n\n"
    "Do not publish one-command challenge or v1.0 release claims from this scaffold.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v59-one-command-challenge-demo-contract",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v59_one_command_challenge_demo_contract_ready": 1,
    "v59_ready": 0,
    "one_command": "./examples/v1_0_architecture_challenge_demo.sh",
    "stage_contract_rows": len(stage_rows),
    "contract_ready_stage_rows": sum(int(row["contract_ready"]) for row in stage_rows),
    "full_ready_stage_rows": sum(int(row["full_ready"]) for row in stage_rows),
    "stage_artifacts_reused": stage_artifacts_reused,
    "stage_rebuild_allowed": stage_rebuild_allowed,
    "stage_rebuild_executed": stage_rebuild_executed,
    "real_release_package_ready": 0,
    "summary_sha256": {stage: sha256(path) for stage, path in summary_files.items()},
}
(run_dir / "v59_one_command_challenge_demo_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "challenge_stage_contract_rows.csv",
    "one_command_demo_rows.csv",
    "one_command_demo_gate_rows.csv",
    "challenge_demo.sh",
    "README_RESULT.md",
    "V59_ONE_COMMAND_CHALLENGE_DEMO_BOUNDARY.md",
    "v59_one_command_challenge_demo_manifest.json",
]
for stage, rels in copy_specs.items():
    artifact_rels.extend([f"source_{stage}/{rel}" for rel in rels])
    artifact_rels.append(f"source_{stage}/{summary_files[stage].name}")

artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v59_one_command_challenge_demo_contract_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
