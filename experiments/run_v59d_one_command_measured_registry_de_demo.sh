#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v59d_one_command_measured_registry_de_demo"
RUN_ID="${V59D_RUN_ID:-measured_registry_de_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
V59D_ALLOW_STAGE_REBUILD="${V59D_ALLOW_STAGE_REBUILD:-0}"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

run_or_reuse() {
  local summary_path="$1"
  shift
  if [[ "${V59D_REUSE_EXISTING:-0}" == "1" && -s "$summary_path" ]]; then
    return 0
  fi
  "$@" >/dev/null
}

if [[ "$V59D_ALLOW_STAGE_REBUILD" == "1" ]]; then
  run_or_reuse "$RESULTS_DIR/v52r_measured_registry_de_absorb_summary.csv" env V52R_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v52r_measured_registry_de_absorb.sh"
  run_or_reuse "$RESULTS_DIR/v53e_canary_query_scale_1000_summary.csv" "$ROOT_DIR/experiments/run_v53e_canary_query_scale_1000.sh"
  run_or_reuse "$RESULTS_DIR/v53f_ah_answer_citation_resource_intake_summary.csv" "$ROOT_DIR/experiments/run_v53f_ah_answer_citation_resource_intake.sh"
  run_or_reuse "$RESULTS_DIR/v54b_routehint_generation_scale_1000_summary.csv" "$ROOT_DIR/experiments/run_v54b_routehint_generation_scale_1000.sh"
  run_or_reuse "$RESULTS_DIR/v55b_local_scaling_law_main_120_summary.csv" "$ROOT_DIR/experiments/run_v55b_local_scaling_law_main_120.sh"
  run_or_reuse "$RESULTS_DIR/v56b_ruler_longbench_expanded_scale_summary.csv" "$ROOT_DIR/experiments/run_v56b_ruler_longbench_expanded_scale.sh"
  run_or_reuse "$RESULTS_DIR/v57b_domain_expert_pack_candidate_1000_summary.csv" "$ROOT_DIR/experiments/run_v57b_domain_expert_pack_candidate_1000.sh"
  run_or_reuse "$RESULTS_DIR/v58b_blind_eval_candidate_500_summary.csv" "$ROOT_DIR/experiments/run_v58b_blind_eval_candidate_500.sh"
  run_or_reuse "$RESULTS_DIR/v58c_blind_response_evidence_intake_summary.csv" "$ROOT_DIR/experiments/run_v58c_blind_response_evidence_intake.sh"
fi

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
        "stage": "v52r",
        "summary": results / "v52r_measured_registry_de_absorb_summary.csv",
        "source_dir": results / "v52r_measured_registry_de_absorb" / "registry_001",
        "ready_field": "v52r_measured_registry_de_absorb_ready",
        "full_ready_field": "v52_ready",
        "artifacts": [
            "measured_baseline_registry.csv",
            "measured_artifact_absorb_rows.csv",
            "V52R_MEASURED_REGISTRY_DE_ABSORB_BOUNDARY.md",
            "v52r_measured_registry_de_absorb_manifest.json",
            "sha256_manifest.csv",
            "source_v52i/frozen_query_rows.csv",
            "source_v52i/source_manifest_rows.csv",
            "source_v52i/abgh_answer_rows.csv",
            "source_v52i/abgh_citation_rows.csv",
            "source_v52i/abgh_abstain_rows.csv",
            "source_v52i/abgh_wrong_answer_guard_rows.csv",
            "source_v52i/abgh_resource_rows.csv",
            "source_v52i/routehint_rows.csv",
            "source_v52l/c_answer_rows.csv",
            "source_v52l/c_citation_rows.csv",
            "source_v52l/c_resource_rows.csv",
            "source_v52l/ollama_generation_transcript_rows.csv",
            "source_v52p/d_answer_rows.csv",
            "source_v52p/d_citation_rows.csv",
            "source_v52p/d_resource_rows.csv",
            "source_v52q/e_answer_rows.csv",
            "source_v52q/e_citation_rows.csv",
            "source_v52q/e_resource_rows.csv",
            "source_v52c/v52c_7b14b_local_model_rag_evidence_intake_summary.csv",
            "source_v52d/v52d_30b70b_llm_rag_evidence_intake_summary.csv",
            "source_v52e/v52e_100b_plus_hosted_llm_rag_optional_intake_summary.csv",
        ],
        "claim": "v52 measured registry with A/B/C/D/E/G/H over the same 1000-query set",
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
    {
        "stage": "v58c",
        "summary": results / "v58c_blind_response_evidence_intake_summary.csv",
        "source_dir": results / "v58c_blind_response_evidence_intake" / "intake_001",
        "ready_field": "v58c_blind_response_evidence_intake_ready",
        "full_ready_field": "v58_ready",
        "artifacts": ["blind_response_required_field_rows.csv", "blind_response_row_template.csv", "run_identity_template_rows.csv", "V58C_BLIND_RESPONSE_EVIDENCE_INTAKE_BOUNDARY.md", "v58c_blind_response_evidence_intake_manifest.json", "sha256_manifest.csv"],
        "claim": "blind response evidence intake",
    },
]

sys.path.insert(0, str(root / "experiments"))
from v59_dependency_blocker import write_dependency_blocker  # noqa: E402

missing_dependency_artifacts = []
for spec in STAGES:
    if not spec["summary"].is_file() or spec["summary"].stat().st_size == 0:
        missing_dependency_artifacts.append(spec["summary"])
    for relpath in spec["artifacts"]:
        artifact = spec["source_dir"] / relpath
        if not artifact.is_file() or artifact.stat().st_size == 0:
            missing_dependency_artifacts.append(artifact)
if missing_dependency_artifacts:
    write_dependency_blocker(
        variant="v59d",
        root=root,
        run_dir=run_dir,
        summary_csv=summary_csv,
        decision_csv=decision_csv,
        missing_artifacts=missing_dependency_artifacts,
    )
    sys.exit(0)


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
    summary_rel = f"source_{spec['stage']}/{spec['summary'].name}"
    copy(spec["summary"], summary_rel)
    artifact_rels.append(summary_rel)
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

write_csv(run_dir / "measured_registry_stage_replay_rows.csv", list(stage_rows[0].keys()), stage_rows)

v52r = read_summary(results / "v52r_measured_registry_de_absorb_summary.csv")
command_rows = [
    {
        "command_id": "v1_0_architecture_challenge_measured_registry_de_demo",
        "command": "./examples/v1_0_architecture_challenge_measured_registry_de_demo.sh",
        "runs_stages": ",".join(spec["stage"] for spec in STAGES),
        "writes_bundle": "results/v59d_one_command_measured_registry_de_demo/measured_registry_de_001",
        "network_required": "0",
        "external_model_required_for_local_registry": "0",
        "real_llm_rows_required_for_full_v1": "1",
        "claim_boundary_required": "1",
    }
]
write_csv(run_dir / "measured_registry_one_command_rows.csv", list(command_rows[0].keys()), command_rows)

gate_rows = [
    ("measured-registry-replay", "pass", "v52r A/B/C/D/E/G/H measured registry is regenerated and copied"),
    ("same-query-source-local-systems", "pass", "A/B/C/D/E/G/H retain shared v53e query IDs and source manifest"),
    ("one-command-measured-registry-entrypoint", "pass", "examples/v1_0_architecture_challenge_measured_registry_de_demo.sh runs v59d"),
    ("measured-registry-bundle-hash-manifest", "pass", "v59d writes sha256_manifest.csv over copied measured artifacts"),
    ("local-only-claim-boundary-preserved", "pass", "local measured rows do not mark full v52/v59 ready"),
    ("7b14b-real-rows", "pass", "v52l C measured packet is absorbed over the shared v53e 1000-row set"),
    ("30b-70b-real-rows", "pass", "externally baked D/E v52p/v52q packets are absorbed into v52r"),
    ("100b-plus-real-row", "blocked", "optional F hosted/API row is missing or deferred"),
    ("complete-source-audit", "blocked", "v53 remains canary-scope, not complete-source 10+ repo audit"),
    ("human-domain-and-blind-review", "blocked", "human expert and blind-review rows are missing"),
    ("v59-full-one-command-demo", "blocked", "v59d is a measured local-registry replay with D/E, not the full challenge demo"),
    ("real-release-package", "blocked", "v59d measured registry packet is not a release package"),
]
decision_rows = [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in gate_rows]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)
write_csv(run_dir / "measured_registry_demo_gate_rows.csv", ["gate", "status", "reason"], decision_rows)

demo = run_dir / "measured_registry_demo.sh"
demo.write_text(
    "#!/usr/bin/env bash\n"
    "set -euo pipefail\n\n"
    "ROOT_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")/../../..\" && pwd)\"\n"
    "\"$ROOT_DIR/examples/v1_0_architecture_challenge_measured_registry_de_demo.sh\"\n",
    encoding="utf-8",
)
demo.chmod(0o755)

(run_dir / "README_RESULT.md").write_text(
    "# v59d One-Command Measured Registry D/E Demo\n\n"
    "Command:\n\n"
    "```bash\n"
    "./examples/v1_0_architecture_challenge_measured_registry_de_demo.sh\n"
    "```\n\n"
    "This bundle promotes the v52r measured registry into the one-command replay path. "
    "It includes A/B/C/D/E/G/H over the same frozen v53e 1000-query set and source manifest. "
    "It does not prove v1.0 performance, blind-eval wins, or release readiness.\n\n"
    "Measured local registry included:\n\n"
    "- local_measured_systems=A/B/C/D/E/G/H\n"
    f"- query_rows={v52r['query_rows']}\n"
    f"- answer_rows={v52r['answer_rows']}\n"
    f"- citation_rows={v52r['citation_rows']}\n"
    f"- abstain_rows={v52r['abstain_rows']}\n"
    f"- wrong_answer_guard_rows={v52r['wrong_answer_guard_rows']}\n"
    f"- resource_rows={v52r['resource_rows']}\n"
    f"- routehint_rows={v52r['routehint_rows']}\n"
    f"- c_strict_exact_label_accuracy={v52r['c_strict_exact_label_accuracy']}\n"
    f"- d_strict_exact_label_accuracy={v52r['d_strict_exact_label_accuracy']}\n"
    f"- e_strict_exact_label_accuracy={v52r['e_strict_exact_label_accuracy']}\n\n"
    "Still blocked: optional 100B+ row or final deferral, complete-source audit rows, human expert review, human blind review, and release review.\n",
    encoding="utf-8",
)

(run_dir / "V59D_ONE_COMMAND_MEASURED_REGISTRY_DE_BOUNDARY.md").write_text(
    "# v59d One-Command Measured Registry D/E Boundary\n\n"
    "This is a one-command replay of the v52r local measured registry plus the current v53-v58 candidate chain. "
    "It is not the completed v1.0 Architecture Challenge demo.\n\n"
    f"- stage_rows={len(stage_rows)}\n"
    f"- candidate_ready_stage_rows={sum(row['candidate_ready'] for row in stage_rows)}\n"
    f"- full_ready_stage_rows={sum(row['full_ready'] for row in stage_rows)}\n"
    "- measured_registry_ready=1\n"
    "- local_measured_systems=A/B/C/D/E/G/H\n"
    f"- query_rows={v52r['query_rows']}\n"
    f"- answer_rows={v52r['answer_rows']}\n"
    f"- citation_rows={v52r['citation_rows']}\n"
    f"- resource_rows={v52r['resource_rows']}\n"
    "- required_7b14b_baseline_ready=1\n"
    "- required_30b_baseline_ready=1\n"
    "- required_70b_baseline_ready=1\n"
    f"- c_strict_exact_label_accuracy={v52r['c_strict_exact_label_accuracy']}\n"
    "- real_30b_70b_rows_ready=1\n"
    "- human_domain_review_ready=0\n"
    "- human_blind_review_ready=0\n\n"
    "Do not publish 30B-150B comparison wins, one-command challenge completion, or v1.0 release claims from this local measured-registry replay.\n",
    encoding="utf-8",
)

summary = {
    "v59d_one_command_measured_registry_de_demo_ready": 1,
    "v59_ready": 0,
    "stage_rows": len(stage_rows),
    "candidate_ready_stage_rows": sum(row["candidate_ready"] for row in stage_rows),
    "full_ready_stage_rows": sum(row["full_ready"] for row in stage_rows),
    "measured_registry_ready": int(v52r["v52r_measured_registry_de_absorb_ready"]),
    "local_measured_systems": v52r["local_measured_systems"],
    "query_rows": int(v52r["query_rows"]),
    "answer_rows": int(v52r["answer_rows"]),
    "citation_rows": int(v52r["citation_rows"]),
    "abstain_rows": int(v52r["abstain_rows"]),
    "wrong_answer_guard_rows": int(v52r["wrong_answer_guard_rows"]),
    "resource_rows": int(v52r["resource_rows"]),
    "routehint_rows": int(v52r["routehint_rows"]),
    "required_7b14b_baseline_ready": int(v52r["required_7b14b_baseline_ready"]),
    "required_30b_baseline_ready": int(v52r["required_30b_baseline_ready"]),
    "required_70b_baseline_ready": int(v52r["required_70b_baseline_ready"]),
    "c_strict_exact_label_accuracy": v52r["c_strict_exact_label_accuracy"],
    "d_strict_exact_label_accuracy": v52r["d_strict_exact_label_accuracy"],
    "e_strict_exact_label_accuracy": v52r["e_strict_exact_label_accuracy"],
    "one_command_measured_registry_entrypoint_ready": 1,
    "measured_registry_bundle_ready": 1,
    "network_required": 0,
    "external_model_required_for_local_registry": 0,
    "real_llm_rows_required_for_full_v1": 1,
    "missing_7b14b_real_rows": 0,
    "missing_real_30b_70b_rows": 0,
    "missing_100b_plus_real_row_or_final_deferral": 1,
    "missing_complete_source_audit": 1,
    "missing_human_domain_review": 1,
    "missing_human_blind_review": 1,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

manifest = {
    "manifest_scope": "v59d-one-command-measured-registry-de-demo",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v59d_one_command_measured_registry_de_demo_ready": 1,
    "v59_ready": 0,
    "one_command": "./examples/v1_0_architecture_challenge_measured_registry_de_demo.sh",
    "stage_order": [spec["stage"] for spec in STAGES],
    "candidate_stage_rows": len(stage_rows),
    "candidate_ready_stage_rows": summary["candidate_ready_stage_rows"],
    "full_ready_stage_rows": summary["full_ready_stage_rows"],
    "local_measured_systems": ["A", "B", "C", "D", "E", "G", "H"],
    "query_rows": summary["query_rows"],
    "answer_rows": summary["answer_rows"],
    "citation_rows": summary["citation_rows"],
    "resource_rows": summary["resource_rows"],
    "real_release_package_ready": 0,
    "source_summary_sha256": {spec["stage"]: sha256(spec["summary"]) for spec in STAGES},
}
(run_dir / "v59d_one_command_measured_registry_de_demo_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels.extend(
    [
        "measured_registry_stage_replay_rows.csv",
        "measured_registry_one_command_rows.csv",
        "measured_registry_demo_gate_rows.csv",
        "measured_registry_demo.sh",
        "README_RESULT.md",
        "V59D_ONE_COMMAND_MEASURED_REGISTRY_DE_BOUNDARY.md",
        "v59d_one_command_measured_registry_de_demo_manifest.json",
    ]
)
artifact_rows = []
for relpath in artifact_rels:
    path = run_dir / relpath
    artifact_rows.append({"path": relpath, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v59d_one_command_measured_registry_de_demo_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
