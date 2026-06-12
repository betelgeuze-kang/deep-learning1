#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61bs_ubuntu1_post_receipt_verification_result_intake"
RUN_ID="${V61BS_RUN_ID:-intake_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
SUPPLIED_DIR="${V61BS_VERIFICATION_RESULT_DIR:-}"

if [[ "${V61BS_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61bs_ubuntu1_post_receipt_verification_result_intake_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BR_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61br_ubuntu1_post_receipt_materialization_promotion_gate.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$SUPPLIED_DIR" <<'PY'
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
supplied_arg = sys.argv[5].strip()
results = root / "results"
supplied_dir = Path(supplied_arg).expanduser().resolve() if supplied_arg else None
model_id = "mistralai/Mixtral-8x22B-v0.1"

ARTIFACT_FIELDS = {
    "v61t_local_checkpoint_materialization_verifier_summary.csv": [
        "v61t_local_checkpoint_materialization_verifier_ready",
        "model_id",
        "warehouse_root_override_supplied",
        "checkpoint_shard_rows",
        "ssd_warehouse_path",
        "ssd_warehouse_outside_repo",
        "local_identity_verified_shard_rows",
        "local_checkpoint_materialization_ready",
        "checkpoint_payload_bytes_committed_to_repo",
    ],
    "v61an_checkpoint_full_page_hash_execution_gate_summary.csv": [
        "v61an_checkpoint_full_page_hash_execution_gate_ready",
        "model_id",
        "warehouse_root_override_supplied",
        "checkpoint_shard_rows",
        "required_page_hash_rows",
        "local_identity_verified_shard_rows",
        "local_full_page_hash_verified_rows",
        "full_page_hash_execution_ready",
        "full_safetensors_page_hash_binding_ready",
        "checkpoint_payload_bytes_downloaded_by_v61an",
        "checkpoint_payload_bytes_committed_to_repo",
    ],
    "v61ae_real_generation_admission_gate_summary.csv": [
        "v61ae_real_generation_admission_gate_ready",
        "model_id",
        "complete_source_query_rows",
        "generation_candidate_rows",
        "generation_admitted_rows",
        "local_checkpoint_materialization_ready",
        "full_safetensors_page_hash_binding_ready",
        "real_generation_admission_ready",
        "actual_model_generation_ready",
        "checkpoint_payload_bytes_committed_to_repo",
    ],
}


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def read_optional_summary(name):
    if supplied_dir is None:
        return None, [], False, ""
    path = supplied_dir / name
    if not path.is_file():
        return None, [], False, ""
    rows = read_csv(path)
    fields = rows[0].keys() if rows else []
    return (rows[0] if rows else None), list(fields), True, sha256(path)


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


v61br_dir = results / "v61br_ubuntu1_post_receipt_materialization_promotion_gate" / "gate_001"
v61br_summary_path = results / "v61br_ubuntu1_post_receipt_materialization_promotion_gate_summary.csv"
v61br_summary = read_csv(v61br_summary_path)[0]
if v61br_summary.get("v61br_ubuntu1_post_receipt_materialization_promotion_gate_ready") != "1":
    raise SystemExit("v61bs requires v61br_ubuntu1_post_receipt_materialization_promotion_gate_ready=1")

for src, rel in [
    (v61br_summary_path, "source_v61br/v61br_ubuntu1_post_receipt_materialization_promotion_gate_summary.csv"),
    (results / "v61br_ubuntu1_post_receipt_materialization_promotion_gate_decision.csv", "source_v61br/v61br_ubuntu1_post_receipt_materialization_promotion_gate_decision.csv"),
    (v61br_dir / "ubuntu1_post_receipt_materialization_requirement_rows.csv", "source_v61br/ubuntu1_post_receipt_materialization_requirement_rows.csv"),
    (v61br_dir / "ubuntu1_post_receipt_verification_command_rows.csv", "source_v61br/ubuntu1_post_receipt_verification_command_rows.csv"),
    (v61br_dir / "ubuntu1_post_receipt_materialization_metric_rows.csv", "source_v61br/ubuntu1_post_receipt_materialization_metric_rows.csv"),
    (v61br_dir / "runtime_gap_rows.csv", "source_v61br/runtime_gap_rows.csv"),
    (v61br_dir / "sha256_manifest.csv", "source_v61br/sha256_manifest.csv"),
]:
    copy(src, rel)

target_root = v61br_summary["target_root_path"]
expected_shard_rows = int(v61br_summary["checkpoint_shard_rows"])
required_page_hash_rows = int(v61br_summary["required_page_hash_rows"])
complete_source_review_return_ready = int(v61br_summary["complete_source_review_return_ready"])
expected_generation_candidate_rows = int(v61br_summary["complete_source_query_rows"])

required_field_rows = []
for artifact, fields in ARTIFACT_FIELDS.items():
    for field in fields:
        required_field_rows.append(
            {
                "result_artifact": artifact,
                "field_name": field,
                "requirement_status": "required",
                "purpose": "validate post-receipt verification result promotion",
            }
        )
write_csv(run_dir / "post_receipt_verification_result_required_field_rows.csv", list(required_field_rows[0].keys()), required_field_rows)

template_rows = [
    {
        "result_artifact": "v61t_local_checkpoint_materialization_verifier_summary.csv",
        "example_payload": "v61t ready, warehouse_root_override_supplied=1, local_identity_verified_shard_rows=59, local_checkpoint_materialization_ready=1",
    },
    {
        "result_artifact": "v61an_checkpoint_full_page_hash_execution_gate_summary.csv",
        "example_payload": "v61an ready, local_full_page_hash_verified_rows=134161, full_safetensors_page_hash_binding_ready=1",
    },
    {
        "result_artifact": "v61ae_real_generation_admission_gate_summary.csv",
        "example_payload": "v61ae ready, generation_candidate_rows=1000, generation_admitted_rows=1000 after review return and full hash",
    },
]
write_csv(run_dir / "post_receipt_verification_result_template_rows.csv", list(template_rows[0].keys()), template_rows)

status_rows = []
validation_rows = []
accepted_count = 0
invalid_count = 0
supplied_count = 0
artifact_data = {}

for artifact_name, required_fields in ARTIFACT_FIELDS.items():
    row, fields, supplied, digest = read_optional_summary(artifact_name)
    if supplied:
        supplied_count += 1
        supplied_copy = run_dir / "supplied_post_receipt_verification_results" / artifact_name
        supplied_copy.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(supplied_dir / artifact_name, supplied_copy)
    missing_fields = [field for field in required_fields if field not in fields]
    reasons = []
    accepted = 0
    if not supplied:
        reasons.append("result-artifact-not-supplied")
    elif row is None:
        reasons.append("result-artifact-empty")
    elif missing_fields:
        reasons.append("missing-fields:" + ";".join(missing_fields))
    else:
        if row.get("model_id") != model_id:
            reasons.append("model-id-mismatch")
        if row.get("checkpoint_payload_bytes_committed_to_repo", "0") != "0":
            reasons.append("repo-payload-commit-not-zero")
        if artifact_name.startswith("v61t"):
            if row.get("ssd_warehouse_path") != target_root:
                reasons.append("target-root-mismatch")
            if row.get("ssd_warehouse_outside_repo") != "1":
                reasons.append("target-root-not-outside-repo")
            if row.get("local_identity_verified_shard_rows") != str(expected_shard_rows):
                reasons.append("identity-verified-shard-count-mismatch")
            if row.get("local_checkpoint_materialization_ready") != "1":
                reasons.append("local-materialization-not-ready")
        elif artifact_name.startswith("v61an"):
            if row.get("checkpoint_payload_bytes_downloaded_by_v61an") != "0":
                reasons.append("v61an-download-bytes-not-zero")
            if row.get("required_page_hash_rows") != str(required_page_hash_rows):
                reasons.append("required-page-hash-row-mismatch")
            if row.get("local_full_page_hash_verified_rows") != str(required_page_hash_rows):
                reasons.append("full-page-hash-verified-row-mismatch")
            if row.get("full_page_hash_execution_ready") != "1":
                reasons.append("full-page-hash-execution-not-ready")
            if row.get("full_safetensors_page_hash_binding_ready") != "1":
                reasons.append("full-safetensors-page-hash-binding-not-ready")
        elif artifact_name.startswith("v61ae"):
            if row.get("complete_source_query_rows") != str(expected_generation_candidate_rows):
                reasons.append("complete-source-query-row-mismatch")
            if row.get("generation_candidate_rows") != str(expected_generation_candidate_rows):
                reasons.append("generation-candidate-row-mismatch")
            if row.get("generation_admitted_rows") != str(expected_generation_candidate_rows):
                reasons.append("generation-admitted-row-mismatch")
            if row.get("real_generation_admission_ready") != "1":
                reasons.append("real-generation-admission-not-ready")
            if complete_source_review_return_ready != 1:
                reasons.append("complete-source-review-return-not-ready")
        accepted = int(not reasons)
    accepted_count += accepted
    invalid_count += int(supplied and not accepted)
    artifact_data[artifact_name] = row if accepted else None
    status_rows.append(
        {
            "result_artifact": artifact_name,
            "result_supplied": str(int(supplied)),
            "result_accepted": str(accepted),
            "result_status": "accepted" if accepted else "deferred-with-reason-final",
            "reason": "" if accepted else ";".join(reasons),
            "sha256": digest,
            "checkpoint_payload_bytes_downloaded_by_v61bs": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )
    validation_rows.append(
        {
            "validation_id": artifact_name.replace(".csv", ""),
            "status": "pass" if accepted else "blocked",
            "missing_required_fields": str(len(missing_fields)),
            "sha256": digest,
            "reason": "result artifact accepted" if accepted else ";".join(reasons),
        }
    )

missing_count = len(ARTIFACT_FIELDS) - supplied_count
identity_result_ready = int(artifact_data["v61t_local_checkpoint_materialization_verifier_summary.csv"] is not None)
full_page_hash_result_ready = int(artifact_data["v61an_checkpoint_full_page_hash_execution_gate_summary.csv"] is not None)
generation_admission_result_ready = int(artifact_data["v61ae_real_generation_admission_gate_summary.csv"] is not None)
local_checkpoint_materialization_ready = identity_result_ready
full_safetensors_page_hash_binding_ready = full_page_hash_result_ready
actual_model_generation_ready = 0
post_receipt_verification_result_intake_ready = int(identity_result_ready and full_page_hash_result_ready and generation_admission_result_ready)

write_csv(run_dir / "post_receipt_verification_result_status_rows.csv", list(status_rows[0].keys()), status_rows)
write_csv(run_dir / "post_receipt_verification_result_validation_rows.csv", list(validation_rows[0].keys()), validation_rows)

requirement_rows = [
    {
        "requirement_id": "v61br-promotion-input",
        "status": "pass",
        "required_value": "v61br ready",
        "actual_value": v61br_summary["v61br_ubuntu1_post_receipt_materialization_promotion_gate_ready"],
        "reason": "post-receipt promotion commands are bound",
    },
    {
        "requirement_id": "v61t-identity-verification-result",
        "status": "pass" if identity_result_ready else "blocked",
        "required_value": "59 identity-verified shards",
        "actual_value": "59" if identity_result_ready else "0",
        "reason": "requires accepted v61t summary over ubuntu-1 target root",
    },
    {
        "requirement_id": "v61an-full-page-hash-result",
        "status": "pass" if full_page_hash_result_ready else "blocked",
        "required_value": str(required_page_hash_rows),
        "actual_value": str(required_page_hash_rows if full_page_hash_result_ready else 0),
        "reason": "requires accepted v61an full local page-hash summary",
    },
    {
        "requirement_id": "v53t-complete-source-review-return",
        "status": "pass" if complete_source_review_return_ready else "blocked",
        "required_value": "review_return_ready=1",
        "actual_value": str(complete_source_review_return_ready),
        "reason": "complete-source human review return still gates generation admission",
    },
    {
        "requirement_id": "v61ae-generation-admission-result",
        "status": "pass" if generation_admission_result_ready else "blocked",
        "required_value": str(expected_generation_candidate_rows),
        "actual_value": str(expected_generation_candidate_rows if generation_admission_result_ready else 0),
        "reason": "requires accepted v61ae generation admission summary",
    },
    {
        "requirement_id": "actual-generation-result",
        "status": "blocked",
        "required_value": "source-bound generated answer/citation/abstain rows",
        "actual_value": "0",
        "reason": "v61bs is a verification-result intake, not a generation runner",
    },
]
write_csv(run_dir / "post_receipt_verification_promotion_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61bs_post_receipt_verification_result_intake_metrics",
    "model_id": model_id,
    "v61br_ubuntu1_post_receipt_materialization_promotion_gate_ready": v61br_summary["v61br_ubuntu1_post_receipt_materialization_promotion_gate_ready"],
    "verification_result_input_supplied": str(int(supplied_dir is not None)),
    "expected_verification_result_artifacts": str(len(ARTIFACT_FIELDS)),
    "supplied_verification_result_artifacts": str(supplied_count),
    "accepted_verification_result_artifacts": str(accepted_count),
    "invalid_verification_result_artifacts": str(invalid_count),
    "missing_verification_result_artifacts": str(missing_count),
    "target_root_path": target_root,
    "checkpoint_shard_rows": str(expected_shard_rows),
    "identity_verification_result_ready": str(identity_result_ready),
    "local_checkpoint_materialization_ready": str(local_checkpoint_materialization_ready),
    "required_page_hash_rows": str(required_page_hash_rows),
    "verified_page_hash_rows_from_result": str(required_page_hash_rows if full_page_hash_result_ready else 0),
    "full_page_hash_result_ready": str(full_page_hash_result_ready),
    "full_safetensors_page_hash_binding_ready": str(full_safetensors_page_hash_binding_ready),
    "complete_source_query_rows": str(expected_generation_candidate_rows),
    "complete_source_review_return_ready": str(complete_source_review_return_ready),
    "generation_admission_result_ready": str(generation_admission_result_ready),
    "post_receipt_verification_result_intake_ready": str(post_receipt_verification_result_intake_ready),
    "actual_model_generation_ready": str(actual_model_generation_ready),
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61bs": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "post_receipt_verification_result_metric_rows.csv", list(metric.keys()), [metric])

gap_rows = [
    ("v61br-promotion-input", "ready", "v61br command rows are bound"),
    ("post-receipt-verification-results", "ready" if accepted_count == len(ARTIFACT_FIELDS) else "blocked", f"accepted={accepted_count}/{len(ARTIFACT_FIELDS)}"),
    ("identity-verified-local-shards", "ready" if identity_result_ready else "blocked", f"identity_result_ready={identity_result_ready}"),
    ("full-page-hash-binding", "ready" if full_page_hash_result_ready else "blocked", f"verified_page_hash_rows={required_page_hash_rows if full_page_hash_result_ready else 0}/{required_page_hash_rows}"),
    ("complete-source-review-return", "ready" if complete_source_review_return_ready else "blocked", f"review_return_ready={complete_source_review_return_ready}"),
    ("generation-admission", "ready" if generation_admission_result_ready else "blocked", f"generation_admission_result_ready={generation_admission_result_ready}"),
    ("actual-model-generation", "blocked", "generation rows are not executed by v61bs"),
    ("production-latency", "blocked", "not a decode latency benchmark"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in gap_rows])

summary = {
    "v61bs_ubuntu1_post_receipt_verification_result_intake_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61br-promotion-input", "status": "pass", "reason": "v61br promotion evidence is bound"},
    {"gate": "result-schema-template", "status": "pass", "reason": "required fields and templates emitted"},
    {"gate": "verification-result-artifacts", "status": "pass" if accepted_count == len(ARTIFACT_FIELDS) else "blocked", "reason": f"accepted_verification_result_artifacts={accepted_count}/{len(ARTIFACT_FIELDS)}"},
    {"gate": "identity-verification-result", "status": "pass" if identity_result_ready else "blocked", "reason": f"identity_verification_result_ready={identity_result_ready}"},
    {"gate": "full-page-hash-result", "status": "pass" if full_page_hash_result_ready else "blocked", "reason": f"full_page_hash_result_ready={full_page_hash_result_ready}"},
    {"gate": "complete-source-review-return", "status": "pass" if complete_source_review_return_ready else "blocked", "reason": f"complete_source_review_return_ready={complete_source_review_return_ready}"},
    {"gate": "generation-admission-result", "status": "pass" if generation_admission_result_ready else "blocked", "reason": f"generation_admission_result_ready={generation_admission_result_ready}"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61bs writes metadata only"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not a generation runner"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61bs Ubuntu-1 Post-Receipt Verification Result Intake Boundary

This gate consumes the results of the v61br post-receipt verification commands.
It validates returned v61t/v61an/v61ae summary artifacts, but it does not
execute downloads, full page hashing, or Mixtral generation.

Evidence emitted:

- verification_result_input_supplied={int(supplied_dir is not None)}
- expected_verification_result_artifacts={len(ARTIFACT_FIELDS)}
- supplied_verification_result_artifacts={supplied_count}
- accepted_verification_result_artifacts={accepted_count}
- missing_verification_result_artifacts={missing_count}
- target_root_path={target_root}
- checkpoint_shard_rows={expected_shard_rows}
- identity_verification_result_ready={identity_result_ready}
- local_checkpoint_materialization_ready={local_checkpoint_materialization_ready}
- required_page_hash_rows={required_page_hash_rows}
- verified_page_hash_rows_from_result={required_page_hash_rows if full_page_hash_result_ready else 0}
- full_page_hash_result_ready={full_page_hash_result_ready}
- full_safetensors_page_hash_binding_ready={full_safetensors_page_hash_binding_ready}
- complete_source_review_return_ready={complete_source_review_return_ready}
- generation_admission_result_ready={generation_admission_result_ready}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61bs=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: post-receipt verification result intake for ubuntu-1
materialization/page-hash/generation-admission summaries.
Blocked wording: completed generation, production latency, near-frontier
quality, or release readiness.
"""
(run_dir / "V61BS_UBUNTU1_POST_RECEIPT_VERIFICATION_RESULT_INTAKE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61bs_ubuntu1_post_receipt_verification_result_intake",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61bs_ubuntu1_post_receipt_verification_result_intake_ready": 1,
    "source_v61br_summary_sha256": sha256(v61br_summary_path),
    "verification_result_input_supplied": int(supplied_dir is not None),
    "expected_verification_result_artifacts": len(ARTIFACT_FIELDS),
    "accepted_verification_result_artifacts": accepted_count,
    "identity_verification_result_ready": identity_result_ready,
    "full_page_hash_result_ready": full_page_hash_result_ready,
    "complete_source_review_return_ready": complete_source_review_return_ready,
    "generation_admission_result_ready": generation_admission_result_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61bs": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61bs_ubuntu1_post_receipt_verification_result_intake_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61bs_ubuntu1_post_receipt_verification_result_intake_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
