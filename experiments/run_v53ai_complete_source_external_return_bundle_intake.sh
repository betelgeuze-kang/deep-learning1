#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53ai_complete_source_external_return_bundle_intake"
RUN_ID="${V53AI_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

RETURN_BUNDLE_DIR="${V53AI_RETURN_BUNDLE_DIR:-}"
DISPATCH_RECEIPT_DIR="${V53AI_DISPATCH_RECEIPT_DIR:-}"
REVIEW_CHUNK_RETURN_DIR="${V53AI_REVIEW_CHUNK_RETURN_DIR:-}"
REVIEW_RETURN_DIR="${V53AI_REVIEW_RETURN_DIR:-}"
GENERATION_RESULT_DIR="${V53AI_GENERATION_RESULT_DIR:-}"

if [[ -n "$RETURN_BUNDLE_DIR" ]]; then
  [[ -z "$DISPATCH_RECEIPT_DIR" ]] && DISPATCH_RECEIPT_DIR="$RETURN_BUNDLE_DIR"
  [[ -z "$REVIEW_CHUNK_RETURN_DIR" ]] && REVIEW_CHUNK_RETURN_DIR="$RETURN_BUNDLE_DIR/review_chunk_returns"
  [[ -z "$REVIEW_RETURN_DIR" ]] && REVIEW_RETURN_DIR="$RETURN_BUNDLE_DIR/aggregate_review_return"
  [[ -z "$GENERATION_RESULT_DIR" ]] && GENERATION_RESULT_DIR="$RETURN_BUNDLE_DIR/generation_result_return"
fi

if [[ "${V53AI_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53ai_complete_source_external_return_bundle_intake_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53AH_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53ah_complete_source_external_review_send_bundle.sh" >/dev/null

env_args=()
[[ -n "$DISPATCH_RECEIPT_DIR" ]] && env_args+=("V53AE_DISPATCH_RECEIPT_DIR=$DISPATCH_RECEIPT_DIR")
[[ -n "$REVIEW_CHUNK_RETURN_DIR" ]] && env_args+=("V53AE_REVIEW_CHUNK_RETURN_DIR=$REVIEW_CHUNK_RETURN_DIR")
[[ -n "$REVIEW_RETURN_DIR" ]] && env_args+=("V53AE_REVIEW_RETURN_DIR=$REVIEW_RETURN_DIR")
[[ -n "$GENERATION_RESULT_DIR" ]] && env_args+=("V53AE_GENERATION_RESULT_DIR=$GENERATION_RESULT_DIR")
env "${env_args[@]}" V53AE_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v53ae_complete_source_review_return_generation_rendezvous_gate.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RETURN_BUNDLE_DIR" "$DISPATCH_RECEIPT_DIR" "$REVIEW_CHUNK_RETURN_DIR" "$REVIEW_RETURN_DIR" "$GENERATION_RESULT_DIR" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
return_bundle_arg = sys.argv[5]
dispatch_arg = sys.argv[6]
chunk_arg = sys.argv[7]
review_arg = sys.argv[8]
generation_arg = sys.argv[9]
results = root / "results"

return_bundle_dir = Path(return_bundle_arg).expanduser().resolve() if return_bundle_arg else None
dispatch_dir = Path(dispatch_arg).expanduser().resolve() if dispatch_arg else None
chunk_dir = Path(chunk_arg).expanduser().resolve() if chunk_arg else None
review_dir = Path(review_arg).expanduser().resolve() if review_arg else None
generation_dir = Path(generation_arg).expanduser().resolve() if generation_arg else None


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def as_int(row, key):
    return int(row.get(key, "0") or "0")


v53ah_summary_path = results / "v53ah_complete_source_external_review_send_bundle_summary.csv"
v53ah_decision_path = results / "v53ah_complete_source_external_review_send_bundle_decision.csv"
v53ah_dir = results / "v53ah_complete_source_external_review_send_bundle" / "bundle_001"
v53ae_summary_path = results / "v53ae_complete_source_review_return_generation_rendezvous_gate_summary.csv"
v53ae_decision_path = results / "v53ae_complete_source_review_return_generation_rendezvous_gate_decision.csv"
v53ae_dir = results / "v53ae_complete_source_review_return_generation_rendezvous_gate" / "gate_001"
v53af_dir = results / "v53af_external_return_inbox_scaffold" / "scaffold_001"
v53af_summary_path = results / "v53af_external_return_inbox_scaffold_summary.csv"

v53ah = read_csv(v53ah_summary_path)[0]
v53ae = read_csv(v53ae_summary_path)[0]
v53af = read_csv(v53af_summary_path)[0]
if v53ah["v53ah_complete_source_external_review_send_bundle_ready"] != "1":
    raise SystemExit("v53ai requires v53ah send bundle readiness")
if v53ae["v53ae_complete_source_review_return_generation_rendezvous_gate_ready"] != "1":
    raise SystemExit("v53ai requires v53ae rendezvous gate readiness")
if v53af["v53af_external_return_inbox_scaffold_ready"] != "1":
    raise SystemExit("v53ai requires v53af return inbox scaffold readiness")

for src, rel in [
    (v53ah_summary_path, "source_v53ah/v53ah_complete_source_external_review_send_bundle_summary.csv"),
    (v53ah_decision_path, "source_v53ah/v53ah_complete_source_external_review_send_bundle_decision.csv"),
    (v53ah_dir / "complete_source_external_review_send_bundle_file_rows.csv", "source_v53ah/complete_source_external_review_send_bundle_file_rows.csv"),
    (v53ah_dir / "complete_source_external_review_send_bundle_nested_member_rows.csv", "source_v53ah/complete_source_external_review_send_bundle_nested_member_rows.csv"),
    (v53ae_summary_path, "source_v53ae/v53ae_complete_source_review_return_generation_rendezvous_gate_summary.csv"),
    (v53ae_decision_path, "source_v53ae/v53ae_complete_source_review_return_generation_rendezvous_gate_decision.csv"),
    (v53ae_dir / "review_return_generation_rendezvous_stage_rows.csv", "source_v53ae/review_return_generation_rendezvous_stage_rows.csv"),
    (v53ae_dir / "review_return_generation_next_action_rows.csv", "source_v53ae/review_return_generation_next_action_rows.csv"),
    (v53ae_dir / "review_return_generation_rendezvous_command_rows.csv", "source_v53ae/review_return_generation_rendezvous_command_rows.csv"),
    (v53af_summary_path, "source_v53af/v53af_external_return_inbox_scaffold_summary.csv"),
    (v53af_dir / "external_return_required_artifact_index_rows.csv", "source_v53af/external_return_required_artifact_index_rows.csv"),
]:
    copy(src, rel)

family_dirs = {
    "dispatch-receipt": dispatch_dir,
    "review-chunk-return": chunk_dir,
    "aggregate-review-return": review_dir,
    "generation-result-return": generation_dir,
}
family_envs = {
    "dispatch-receipt": "V53AE_DISPATCH_RECEIPT_DIR",
    "review-chunk-return": "V53AE_REVIEW_CHUNK_RETURN_DIR",
    "aggregate-review-return": "V53AE_REVIEW_RETURN_DIR",
    "generation-result-return": "V53AE_GENERATION_RESULT_DIR",
}

required_rows = read_csv(v53af_dir / "external_return_required_artifact_index_rows.csv")
artifact_rows = []
family_counts = {}
supplied_return_artifact_rows = 0
missing_return_artifact_rows = 0
template_named_supplied_rows = 0
for row in required_rows:
    family = row["return_family"]
    base = family_dirs[family]
    expected_rel = row["expected_final_artifact"]
    supplied_path = base / expected_rel if base else None
    supplied = int(supplied_path is not None and supplied_path.is_file())
    if supplied:
        supplied_return_artifact_rows += 1
    else:
        missing_return_artifact_rows += 1
    template_named = int(supplied_path is not None and supplied_path.name.endswith(".template"))
    template_named_supplied_rows += template_named
    family_counts.setdefault(family, {"expected": 0, "supplied": 0, "missing": 0})
    family_counts[family]["expected"] += 1
    family_counts[family]["supplied"] += supplied
    family_counts[family]["missing"] += int(not supplied)
    artifact_rows.append(
        {
            "return_family": family,
            "target_env_var": family_envs[family],
            "expected_final_artifact": expected_rel,
            "expected_rows": row["expected_rows"],
            "return_base_dir_supplied": str(int(base is not None)),
            "return_base_dir_exists": str(int(base is not None and base.is_dir())),
            "resolved_return_artifact_path": str(supplied_path) if supplied_path else "",
            "return_artifact_supplied": str(supplied),
            "template_named_supplied": str(template_named),
            "artifact_sha256": sha256(supplied_path) if supplied else "",
            "accepted_by_v53ai": "0",
            "accepted_by_default": row["accepted_by_default"],
            "route_jump_rows": "0",
        }
    )
write_csv(run_dir / "external_return_bundle_artifact_mapping_rows.csv", list(artifact_rows[0].keys()), artifact_rows)

family_rows = []
for family in ["dispatch-receipt", "review-chunk-return", "aggregate-review-return", "generation-result-return"]:
    counts = family_counts[family]
    base = family_dirs[family]
    family_rows.append(
        {
            "return_family": family,
            "target_env_var": family_envs[family],
            "return_base_dir": str(base) if base else "",
            "return_base_dir_supplied": str(int(base is not None)),
            "return_base_dir_exists": str(int(base is not None and base.is_dir())),
            "expected_artifact_rows": str(counts["expected"]),
            "supplied_artifact_rows": str(counts["supplied"]),
            "missing_artifact_rows": str(counts["missing"]),
            "family_complete_by_presence": str(int(counts["expected"] == counts["supplied"])),
        }
    )
write_csv(run_dir / "external_return_bundle_family_rows.csv", list(family_rows[0].keys()), family_rows)

operator_readme = run_dir / "RECEIVE_EXTERNAL_RETURN_BUNDLE.md"
operator_readme.write_text(
    "\n".join(
        [
            "# v53ai External Return Bundle Intake",
            "",
            "Place returned artifacts under one bundle root with this shape:",
            "",
            "- `dispatch_receipts/`",
            "- `review_chunk_returns/chunks/...`",
            "- `aggregate_review_return/`",
            "- `generation_result_return/`",
            "",
            "Then run:",
            "",
            "```bash",
            "V53AI_RETURN_BUNDLE_DIR=/path/to/final_return_bundle \\",
            "V53AI_REUSE_EXISTING=0 \\",
            "./experiments/run_v53ai_complete_source_external_return_bundle_intake.sh",
            "```",
            "",
            "This gate maps returned files into the v53ae/v61de chain. It does not accept templates as evidence and does not create review or generation claims by itself.",
            "",
        ]
    ),
    encoding="utf-8",
)

return_bundle_dir_supplied = int(return_bundle_dir is not None)
return_bundle_dir_exists = int(return_bundle_dir is not None and return_bundle_dir.is_dir())
dispatch_receipt_dir_supplied = int(dispatch_dir is not None)
dispatch_receipt_dir_exists = int(dispatch_dir is not None and dispatch_dir.is_dir())
review_chunk_return_dir_supplied = int(chunk_dir is not None)
review_chunk_return_dir_exists = int(chunk_dir is not None and chunk_dir.is_dir())
review_return_dir_supplied = int(review_dir is not None)
review_return_dir_exists = int(review_dir is not None and review_dir.is_dir())
generation_result_dir_supplied = int(generation_dir is not None)
generation_result_dir_exists = int(generation_dir is not None and generation_dir.is_dir())
required_return_artifact_rows = len(required_rows)
return_bundle_mapping_ready = int(required_return_artifact_rows == as_int(v53af, "required_return_artifact_rows"))
all_return_artifacts_present = int(supplied_return_artifact_rows == required_return_artifact_rows and template_named_supplied_rows == 0)
v53ai_ready = int(
    as_int(v53ah, "send_bundle_ready")
    and return_bundle_mapping_ready
    and template_named_supplied_rows == 0
    and as_int(v53ae, "v53ae_complete_source_review_return_generation_rendezvous_gate_ready")
)

requirement_rows = [
    {"requirement_id": "v53ah-send-bundle-input", "status": "pass", "required_value": "1", "actual_value": v53ah["v53ah_complete_source_external_review_send_bundle_ready"], "reason": "send bundle is ready"},
    {"requirement_id": "v53af-required-artifact-index", "status": "pass" if return_bundle_mapping_ready else "blocked", "required_value": v53af["required_return_artifact_rows"], "actual_value": str(required_return_artifact_rows), "reason": "required return artifact index is available"},
    {"requirement_id": "return-bundle-directory", "status": "pass" if return_bundle_dir_exists else "blocked", "required_value": "existing return bundle directory", "actual_value": str(return_bundle_dir) if return_bundle_dir else "", "reason": "external return bundle has not been supplied in default smoke"},
    {"requirement_id": "all-return-artifacts-present", "status": "pass" if all_return_artifacts_present else "blocked", "required_value": str(required_return_artifact_rows), "actual_value": str(supplied_return_artifact_rows), "reason": "all final returned artifacts must be present before downstream acceptance can pass"},
    {"requirement_id": "template-files-not-accepted", "status": "pass" if template_named_supplied_rows == 0 else "blocked", "required_value": "0", "actual_value": str(template_named_supplied_rows), "reason": "template files are not accepted evidence"},
    {"requirement_id": "v53ae-rendezvous-refresh", "status": "pass", "required_value": "1", "actual_value": v53ae["v53ae_complete_source_review_return_generation_rendezvous_gate_ready"], "reason": "v53ae refreshed with supplied dirs if any"},
    {"requirement_id": "review-return-accepted", "status": "blocked", "required_value": "7000", "actual_value": v53ae["answer_review_accepted_rows"], "reason": "review return acceptance remains downstream"},
    {"requirement_id": "generation-execution-admitted", "status": "blocked", "required_value": "1000", "actual_value": v53ae["generation_execution_admitted_rows"], "reason": "generation execution remains downstream"},
    {"requirement_id": "generation-result-accepted", "status": "blocked", "required_value": "5", "actual_value": v53ae["accepted_generation_result_artifacts"], "reason": "generation result acceptance remains downstream"},
    {"requirement_id": "actual-generation", "status": "blocked", "required_value": "1", "actual_value": v53ae["actual_model_generation_ready"], "reason": "actual generation remains unproven"},
]
write_csv(run_dir / "external_return_bundle_intake_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gap_rows = [
    {"gap": "return-bundle-intake-surface", "status": "ready" if v53ai_ready else "blocked", "reason": f"return_bundle_mapping_ready={return_bundle_mapping_ready}; template_named_supplied_rows={template_named_supplied_rows}"},
    {"gap": "return-bundle-directory", "status": "ready" if return_bundle_dir_exists else "blocked", "reason": f"return_bundle_dir_supplied={return_bundle_dir_supplied}; return_bundle_dir_exists={return_bundle_dir_exists}"},
    {"gap": "all-return-artifacts-present", "status": "ready" if all_return_artifacts_present else "blocked", "reason": f"supplied_return_artifact_rows={supplied_return_artifact_rows}/{required_return_artifact_rows}"},
    {"gap": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53ae['answer_review_accepted_rows']}/7000"},
    {"gap": "generation-execution-admitted", "status": "blocked", "reason": f"generation_execution_admitted_rows={v53ae['generation_execution_admitted_rows']}/1000"},
    {"gap": "generation-result-accepted", "status": "blocked", "reason": f"accepted_generation_result_artifacts={v53ae['accepted_generation_result_artifacts']}/5"},
    {"gap": "actual-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v53ae['actual_model_generation_ready']}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

metric = {
    "metric_id": "v53ai_complete_source_external_return_bundle_intake_metrics",
    "v53ah_complete_source_external_review_send_bundle_ready": v53ah["v53ah_complete_source_external_review_send_bundle_ready"],
    "v53ae_complete_source_review_return_generation_rendezvous_gate_ready": v53ae["v53ae_complete_source_review_return_generation_rendezvous_gate_ready"],
    "return_bundle_dir_supplied": str(return_bundle_dir_supplied),
    "return_bundle_dir_exists": str(return_bundle_dir_exists),
    "dispatch_receipt_dir_supplied": str(dispatch_receipt_dir_supplied),
    "dispatch_receipt_dir_exists": str(dispatch_receipt_dir_exists),
    "review_chunk_return_dir_supplied": str(review_chunk_return_dir_supplied),
    "review_chunk_return_dir_exists": str(review_chunk_return_dir_exists),
    "review_return_dir_supplied": str(review_return_dir_supplied),
    "review_return_dir_exists": str(review_return_dir_exists),
    "generation_result_dir_supplied": str(generation_result_dir_supplied),
    "generation_result_dir_exists": str(generation_result_dir_exists),
    "standard_return_family_rows": str(len(family_rows)),
    "required_return_artifact_rows": str(required_return_artifact_rows),
    "supplied_return_artifact_rows": str(supplied_return_artifact_rows),
    "missing_return_artifact_rows": str(missing_return_artifact_rows),
    "template_named_supplied_rows": str(template_named_supplied_rows),
    "accepted_by_v53ai_rows": "0",
    "return_bundle_mapping_ready": str(return_bundle_mapping_ready),
    "all_return_artifacts_present": str(all_return_artifacts_present),
    "send_bundle_ready": v53ah["send_bundle_ready"],
    "send_bundle_archive_files": v53ah["send_bundle_archive_files"],
    "nested_payload_like_archive_member_rows": v53ah["nested_payload_like_archive_member_rows"],
    "return_inbox_final_evidence_named_archive_member_rows": v53ah["return_inbox_final_evidence_named_archive_member_rows"],
    "rendezvous_stage_rows": v53ae["rendezvous_stage_rows"],
    "ready_rendezvous_stage_rows": v53ae["ready_rendezvous_stage_rows"],
    "blocked_rendezvous_stage_rows": v53ae["blocked_rendezvous_stage_rows"],
    "accepted_dispatch_receipt_rows": v53ae["accepted_dispatch_receipt_rows"],
    "accepted_chunk_return_artifact_rows": v53ae["accepted_chunk_return_artifact_rows"],
    "answer_review_accepted_rows": v53ae["answer_review_accepted_rows"],
    "generation_execution_admitted_rows": v53ae["generation_execution_admitted_rows"],
    "accepted_generation_result_artifacts": v53ae["accepted_generation_result_artifacts"],
    "generation_result_accepted_rows": v53ae["generation_result_accepted_rows"],
    "actual_model_generation_ready": v53ae["actual_model_generation_ready"],
    "full_shard_prerequisites_closed": v53ae["full_shard_prerequisites_closed"],
    "runtime_admission_accepted_rows": v53ae["runtime_admission_accepted_rows"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v53ai": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "external_return_bundle_intake_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53ai_complete_source_external_return_bundle_intake_ready": str(v53ai_ready),
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v53ah-send-bundle-input", "status": "pass", "reason": "v53ah send bundle is ready"},
    {"gate": "required-artifact-index", "status": "pass" if return_bundle_mapping_ready else "blocked", "reason": f"required_return_artifact_rows={required_return_artifact_rows}/{v53af['required_return_artifact_rows']}"},
    {"gate": "return-bundle-directory", "status": "pass" if return_bundle_dir_exists else "blocked", "reason": f"return_bundle_dir_exists={return_bundle_dir_exists}"},
    {"gate": "template-files-not-accepted", "status": "pass" if template_named_supplied_rows == 0 else "blocked", "reason": f"template_named_supplied_rows={template_named_supplied_rows}"},
    {"gate": "v53ae-rendezvous-refresh", "status": "pass", "reason": "v53ae refreshed"},
    {"gate": "all-return-artifacts-present", "status": "pass" if all_return_artifacts_present else "blocked", "reason": f"supplied_return_artifact_rows={supplied_return_artifact_rows}/{required_return_artifact_rows}"},
    {"gate": "review-return-accepted", "status": "blocked", "reason": f"answer_review_accepted_rows={v53ae['answer_review_accepted_rows']}/7000"},
    {"gate": "generation-execution-admitted", "status": "blocked", "reason": f"generation_execution_admitted_rows={v53ae['generation_execution_admitted_rows']}/1000"},
    {"gate": "generation-result-accepted", "status": "blocked", "reason": f"accepted_generation_result_artifacts={v53ae['accepted_generation_result_artifacts']}/5"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v53ae['actual_model_generation_ready']}"},
    {"gate": "real-release-package", "status": "blocked", "reason": "return bundle intake is not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v53ai Complete-Source External Return Bundle Intake Boundary

This artifact maps a returned external bundle into the v53ae/v61de refresh
chain. It defines the one-root return bundle layout and records which final
artifacts are present. It does not accept templates as evidence, and it does
not create review judgments, generation execution, generation result
acceptance, actual model generation, production latency evidence, near-frontier
quality evidence, or release readiness.

Evidence emitted:

- return_bundle_dir_supplied={return_bundle_dir_supplied}
- return_bundle_dir_exists={return_bundle_dir_exists}
- standard_return_family_rows={len(family_rows)}
- required_return_artifact_rows={required_return_artifact_rows}
- supplied_return_artifact_rows={supplied_return_artifact_rows}
- missing_return_artifact_rows={missing_return_artifact_rows}
- template_named_supplied_rows={template_named_supplied_rows}
- accepted_by_v53ai_rows=0
- return_bundle_mapping_ready={return_bundle_mapping_ready}
- all_return_artifacts_present={all_return_artifacts_present}
- send_bundle_ready={v53ah['send_bundle_ready']}
- send_bundle_archive_files={v53ah['send_bundle_archive_files']}
- nested_payload_like_archive_member_rows={v53ah['nested_payload_like_archive_member_rows']}
- return_inbox_final_evidence_named_archive_member_rows={v53ah['return_inbox_final_evidence_named_archive_member_rows']}
- rendezvous_stage_rows={v53ae['rendezvous_stage_rows']}
- ready_rendezvous_stage_rows={v53ae['ready_rendezvous_stage_rows']}
- blocked_rendezvous_stage_rows={v53ae['blocked_rendezvous_stage_rows']}
- accepted_dispatch_receipt_rows={v53ae['accepted_dispatch_receipt_rows']}
- accepted_chunk_return_artifact_rows={v53ae['accepted_chunk_return_artifact_rows']}
- answer_review_accepted_rows={v53ae['answer_review_accepted_rows']}
- generation_execution_admitted_rows={v53ae['generation_execution_admitted_rows']}
- accepted_generation_result_artifacts={v53ae['accepted_generation_result_artifacts']}
- actual_model_generation_ready={v53ae['actual_model_generation_ready']}
- full_shard_prerequisites_closed={v53ae['full_shard_prerequisites_closed']}
- runtime_admission_accepted_rows={v53ae['runtime_admission_accepted_rows']}
- checkpoint_payload_bytes_downloaded_by_v53ai=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: the external return bundle intake surface is ready.
Blocked wording: accepted review return, generation execution, generation
result acceptance, actual generation, production latency, near-frontier quality,
or release readiness.
"""
(run_dir / "V53AI_COMPLETE_SOURCE_EXTERNAL_RETURN_BUNDLE_INTAKE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53ai-complete-source-external-return-bundle-intake",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53ai_complete_source_external_return_bundle_intake_ready": v53ai_ready,
    "return_bundle_dir_supplied": return_bundle_dir_supplied,
    "return_bundle_dir_exists": return_bundle_dir_exists,
    "required_return_artifact_rows": required_return_artifact_rows,
    "supplied_return_artifact_rows": supplied_return_artifact_rows,
    "missing_return_artifact_rows": missing_return_artifact_rows,
    "template_named_supplied_rows": template_named_supplied_rows,
    "accepted_by_v53ai_rows": 0,
    "return_bundle_mapping_ready": return_bundle_mapping_ready,
    "all_return_artifacts_present": all_return_artifacts_present,
    "send_bundle_ready": int(v53ah["send_bundle_ready"]),
    "answer_review_accepted_rows": int(v53ae["answer_review_accepted_rows"]),
    "generation_execution_admitted_rows": int(v53ae["generation_execution_admitted_rows"]),
    "accepted_generation_result_artifacts": int(v53ae["accepted_generation_result_artifacts"]),
    "actual_model_generation_ready": int(v53ae["actual_model_generation_ready"]),
    "full_shard_prerequisites_closed": int(v53ae["full_shard_prerequisites_closed"]),
    "runtime_admission_accepted_rows": int(v53ae["runtime_admission_accepted_rows"]),
    "checkpoint_payload_bytes_downloaded_by_v53ai": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
write_json(run_dir / "v53ai_complete_source_external_return_bundle_intake_manifest.json", manifest)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53ai_complete_source_external_return_bundle_intake_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
