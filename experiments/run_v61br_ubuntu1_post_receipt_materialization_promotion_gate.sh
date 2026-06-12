#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61br_ubuntu1_post_receipt_materialization_promotion_gate"
RUN_ID="${V61BR_RUN_ID:-gate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61BR_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61br_ubuntu1_post_receipt_materialization_promotion_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61BQ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61bq_ubuntu1_payload_execution_receipt_intake.sh" >/dev/null
V61R_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61r_full_page_hash_sweep_plan.sh" >/dev/null
V53T_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53t_complete_source_audit_readiness_gate.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
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
results = root / "results"
model_id = "mistralai/Mixtral-8x22B-v0.1"


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


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def outside_repo(path):
    try:
        Path(path).resolve().relative_to(root)
        return 0
    except ValueError:
        return 1


v61bq_dir = results / "v61bq_ubuntu1_payload_execution_receipt_intake" / "intake_001"
v61r_dir = results / "v61r_full_page_hash_sweep_plan" / "plan_001"
v53t_dir = results / "v53t_complete_source_audit_readiness_gate" / "gate_001"

v61bq_summary_path = results / "v61bq_ubuntu1_payload_execution_receipt_intake_summary.csv"
v61r_summary_path = results / "v61r_full_page_hash_sweep_plan_summary.csv"
v53t_summary_path = results / "v53t_complete_source_audit_readiness_gate_summary.csv"
v61bq_summary = read_csv(v61bq_summary_path)[0]
v61r_summary = read_csv(v61r_summary_path)[0]
v53t_summary = read_csv(v53t_summary_path)[0]

if v61bq_summary.get("v61bq_ubuntu1_payload_execution_receipt_intake_ready") != "1":
    raise SystemExit("v61br requires v61bq_ubuntu1_payload_execution_receipt_intake_ready=1")
if v61r_summary.get("v61r_full_page_hash_sweep_plan_ready") != "1":
    raise SystemExit("v61br requires v61r_full_page_hash_sweep_plan_ready=1")
if v53t_summary.get("v53t_complete_source_audit_readiness_gate_ready") != "1":
    raise SystemExit("v61br requires v53t_complete_source_audit_readiness_gate_ready=1")

for src, rel in [
    (v61bq_summary_path, "source_v61bq/v61bq_ubuntu1_payload_execution_receipt_intake_summary.csv"),
    (results / "v61bq_ubuntu1_payload_execution_receipt_intake_decision.csv", "source_v61bq/v61bq_ubuntu1_payload_execution_receipt_intake_decision.csv"),
    (v61bq_dir / "ubuntu1_payload_execution_live_presence_rows.csv", "source_v61bq/ubuntu1_payload_execution_live_presence_rows.csv"),
    (v61bq_dir / "ubuntu1_payload_execution_receipt_status_rows.csv", "source_v61bq/ubuntu1_payload_execution_receipt_status_rows.csv"),
    (v61bq_dir / "ubuntu1_payload_execution_receipt_metric_rows.csv", "source_v61bq/ubuntu1_payload_execution_receipt_metric_rows.csv"),
    (v61bq_dir / "runtime_gap_rows.csv", "source_v61bq/runtime_gap_rows.csv"),
    (v61bq_dir / "sha256_manifest.csv", "source_v61bq/sha256_manifest.csv"),
    (v61r_summary_path, "source_v61r/v61r_full_page_hash_sweep_plan_summary.csv"),
    (v61r_dir / "page_hash_sweep_metric_rows.csv", "source_v61r/page_hash_sweep_metric_rows.csv"),
    (v61r_dir / "shard_page_hash_sweep_status_rows.csv", "source_v61r/shard_page_hash_sweep_status_rows.csv"),
    (v61r_dir / "sha256_manifest.csv", "source_v61r/sha256_manifest.csv"),
    (v53t_summary_path, "source_v53t/v53t_complete_source_audit_readiness_gate_summary.csv"),
    (v53t_dir / "complete_source_audit_readiness_metric_rows.csv", "source_v53t/complete_source_audit_readiness_metric_rows.csv"),
    (v53t_dir / "complete_source_audit_readiness_requirement_rows.csv", "source_v53t/complete_source_audit_readiness_requirement_rows.csv"),
    (v53t_dir / "sha256_manifest.csv", "source_v53t/sha256_manifest.csv"),
]:
    copy(src, rel)

live_rows = read_csv(v61bq_dir / "ubuntu1_payload_execution_live_presence_rows.csv")
receipt_rows = read_csv(v61bq_dir / "ubuntu1_payload_execution_receipt_status_rows.csv")
if len(live_rows) != 59 or len(receipt_rows) != 59:
    raise SystemExit("v61br expects 59 v61bq live/receipt rows")

target_roots = sorted({str(Path(row["target_path"]).parent) for row in live_rows})
target_root = target_roots[0] if len(target_roots) == 1 else ""
target_root_count = len(target_roots)
target_root_outside_repo = outside_repo(target_root) if target_root else 0
tmp_target_rows = sum(1 for row in live_rows if Path(row["target_path"]).as_posix().startswith("/tmp/"))
repo_local_target_rows = sum(1 for row in live_rows if outside_repo(row["target_path"]) == 0)

expected_receipts = int(v61bq_summary["expected_payload_execution_receipt_rows"])
accepted_receipts = int(v61bq_summary["accepted_payload_execution_receipt_rows"])
missing_receipts = int(v61bq_summary["missing_payload_execution_receipt_rows"])
live_existing = int(v61bq_summary["live_existing_shard_rows"])
live_size_match = int(v61bq_summary["live_size_match_shard_rows"])
required_page_hash_rows = int(v61r_summary["page_hash_sweep_plan_rows"])
verified_page_hash_rows = int(v61r_summary["verified_page_hash_rows"])
complete_source_query_rows = int(v53t_summary["complete_source_query_rows"])
core_answer_rows = int(v53t_summary["core_answer_rows"])
human_review_rows = int(v53t_summary["accepted_human_review_rows"])
review_return_ready = int(v53t_summary["review_return_ready"])

receipt_backed_input_ready = int(accepted_receipts == expected_receipts == 59)
live_size_ready = int(live_size_match == expected_receipts == 59)
target_contract_ready = int(target_root_count == 1 and target_root_outside_repo == 1 and tmp_target_rows == 0 and repo_local_target_rows == 0)
identity_verification_execution_ready = int(receipt_backed_input_ready and live_size_ready and target_contract_ready)
full_page_hash_execution_ready = 0
post_receipt_materialization_promotion_ready = 0

requirements = [
    {
        "requirement_id": "v61bq-receipt-intake-input",
        "status": "pass",
        "required_value": "v61bq ready",
        "actual_value": v61bq_summary["v61bq_ubuntu1_payload_execution_receipt_intake_ready"],
        "reason": "receipt intake surface is available",
    },
    {
        "requirement_id": "single-ubuntu1-target-root",
        "status": "pass" if target_root_count == 1 else "blocked",
        "required_value": "1 target root",
        "actual_value": str(target_root_count),
        "reason": target_root,
    },
    {
        "requirement_id": "target-root-outside-repository",
        "status": "pass" if target_root_outside_repo == 1 and repo_local_target_rows == 0 else "blocked",
        "required_value": "outside repository",
        "actual_value": f"outside={target_root_outside_repo}; repo_local_rows={repo_local_target_rows}",
        "reason": "checkpoint payload must remain outside the repository",
    },
    {
        "requirement_id": "no-stale-tmp-targets",
        "status": "pass" if tmp_target_rows == 0 else "blocked",
        "required_value": "0",
        "actual_value": str(tmp_target_rows),
        "reason": "post-receipt promotion must use the ubuntu-1 target, not temporary smoke roots",
    },
    {
        "requirement_id": "accepted-execution-receipts",
        "status": "pass" if receipt_backed_input_ready else "blocked",
        "required_value": "59 accepted receipts",
        "actual_value": str(accepted_receipts),
        "reason": "every v61bp launch row needs an accepted execution receipt",
    },
    {
        "requirement_id": "live-size-match-shards",
        "status": "pass" if live_size_ready else "blocked",
        "required_value": "59 live size-match shards",
        "actual_value": str(live_size_match),
        "reason": "each target shard must exist at its expected size before identity verification",
    },
    {
        "requirement_id": "identity-verification-execution-admission",
        "status": "pass" if identity_verification_execution_ready else "blocked",
        "required_value": "receipt-backed live 59/59 target",
        "actual_value": f"receipts={accepted_receipts}/59; live_size_match={live_size_match}/59",
        "reason": "admits a targeted v61t identity-verification rerun against ubuntu-1",
    },
    {
        "requirement_id": "full-page-hash-execution-admission",
        "status": "blocked",
        "required_value": str(required_page_hash_rows),
        "actual_value": str(verified_page_hash_rows),
        "reason": "v61an local hash execution waits for identity-verified local shards",
    },
    {
        "requirement_id": "complete-source-review-return",
        "status": "pass" if review_return_ready else "blocked",
        "required_value": "7000 accepted human review rows plus adjudication",
        "actual_value": str(human_review_rows),
        "reason": "actual generation over complete-source QA still requires review return evidence",
    },
    {
        "requirement_id": "actual-model-generation-admission",
        "status": "blocked",
        "required_value": "materialization + full page hash + review return",
        "actual_value": "0",
        "reason": "v61br does not execute Mixtral generation",
    },
]
write_csv(run_dir / "ubuntu1_post_receipt_materialization_requirement_rows.csv", list(requirements[0].keys()), requirements)

command_rows = [
    {
        "command_id": "v61br-identity-verification-ubuntu1",
        "command_kind": "post-receipt-identity-verification",
        "command": f"V61T_WAREHOUSE_ROOT={target_root} V61T_REUSE_EXISTING=0 ./experiments/run_v61t_local_checkpoint_materialization_verifier.sh",
        "admission_ready": str(identity_verification_execution_ready),
        "blocked_reason": "" if identity_verification_execution_ready else "requires 59 accepted receipts and 59 live size-match shards",
        "checkpoint_payload_bytes_downloaded_by_v61br": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    },
    {
        "command_id": "v61br-full-page-hash-ubuntu1",
        "command_kind": "post-identity-full-page-hash",
        "command": f"V61AN_WAREHOUSE_ROOT={target_root} V61AN_ENABLE_LOCAL_HASH_EXECUTION=1 V61AN_REUSE_EXISTING=0 ./experiments/run_v61an_checkpoint_full_page_hash_execution_gate.sh",
        "admission_ready": str(full_page_hash_execution_ready),
        "blocked_reason": "requires v61t local_identity_verified_shard_rows=59",
        "checkpoint_payload_bytes_downloaded_by_v61br": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    },
    {
        "command_id": "v61br-real-generation-admission-ubuntu1",
        "command_kind": "post-hash-generation-admission",
        "command": f"V61AE_WAREHOUSE_ROOT={target_root} V61AE_REUSE_EXISTING=0 ./experiments/run_v61ae_real_generation_admission_gate.sh",
        "admission_ready": "0",
        "blocked_reason": "requires full page-hash binding and complete-source human review return",
        "checkpoint_payload_bytes_downloaded_by_v61br": "0",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    },
]
write_csv(run_dir / "ubuntu1_post_receipt_verification_command_rows.csv", list(command_rows[0].keys()), command_rows)

gap_rows = [
    ("v61bq-receipt-intake", "ready", "v61bq receipt intake evidence is bound"),
    ("ubuntu1-target-contract", "ready" if target_contract_ready else "blocked", f"target_root={target_root}"),
    ("accepted-payload-execution-receipts", "ready" if receipt_backed_input_ready else "blocked", f"accepted={accepted_receipts}/59"),
    ("live-size-match-shards", "ready" if live_size_ready else "blocked", f"live_size_match={live_size_match}/59"),
    ("identity-verification-rerun", "ready" if identity_verification_execution_ready else "blocked", "targeted v61t command remains gated"),
    ("full-page-hash-execution", "blocked", f"verified_page_hash_rows={verified_page_hash_rows}/{required_page_hash_rows}"),
    ("complete-source-review-return", "ready" if review_return_ready else "blocked", f"accepted_human_review_rows={human_review_rows}/7000"),
    ("actual-model-generation", "blocked", "materialization, full hash, and review returns are incomplete"),
    ("production-latency", "blocked", "not a decode latency benchmark"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(run_dir / "runtime_gap_rows.csv", ["gap", "status", "reason"], [{"gap": g, "status": s, "reason": r} for g, s, r in gap_rows])

metric = {
    "metric_id": "v61br_ubuntu1_post_receipt_materialization_promotion_metrics",
    "model_id": model_id,
    "v61bq_ubuntu1_payload_execution_receipt_intake_ready": v61bq_summary["v61bq_ubuntu1_payload_execution_receipt_intake_ready"],
    "v61r_full_page_hash_sweep_plan_ready": v61r_summary["v61r_full_page_hash_sweep_plan_ready"],
    "v53t_complete_source_audit_readiness_gate_ready": v53t_summary["v53t_complete_source_audit_readiness_gate_ready"],
    "target_root_count": str(target_root_count),
    "target_root_path": target_root,
    "target_root_outside_repo": str(target_root_outside_repo),
    "tmp_target_rows": str(tmp_target_rows),
    "repo_local_target_rows": str(repo_local_target_rows),
    "checkpoint_shard_rows": str(expected_receipts),
    "expected_payload_execution_receipt_rows": str(expected_receipts),
    "accepted_payload_execution_receipt_rows": str(accepted_receipts),
    "missing_payload_execution_receipt_rows": str(missing_receipts),
    "live_existing_shard_rows": str(live_existing),
    "live_size_match_shard_rows": str(live_size_match),
    "receipt_backed_materialization_input_ready": str(receipt_backed_input_ready),
    "identity_verification_execution_ready": str(identity_verification_execution_ready),
    "local_checkpoint_materialization_ready": "0",
    "required_page_hash_rows": str(required_page_hash_rows),
    "verified_page_hash_rows": str(verified_page_hash_rows),
    "full_page_hash_execution_ready": str(full_page_hash_execution_ready),
    "full_safetensors_page_hash_binding_ready": "0",
    "complete_source_query_rows": str(complete_source_query_rows),
    "core_answer_rows": str(core_answer_rows),
    "accepted_human_review_rows": str(human_review_rows),
    "complete_source_review_return_ready": str(review_return_ready),
    "post_receipt_materialization_promotion_ready": str(post_receipt_materialization_promotion_ready),
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61br": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "ubuntu1_post_receipt_materialization_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61br_ubuntu1_post_receipt_materialization_promotion_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v61bq-receipt-intake-input", "status": "pass", "reason": "v61bq receipt intake evidence is bound"},
    {"gate": "ubuntu1-target-contract", "status": "pass" if target_contract_ready else "blocked", "reason": f"target_root={target_root}"},
    {"gate": "receipt-backed-materialization-input", "status": "pass" if receipt_backed_input_ready else "blocked", "reason": f"accepted_payload_execution_receipt_rows={accepted_receipts}/59"},
    {"gate": "live-size-match-shards", "status": "pass" if live_size_ready else "blocked", "reason": f"live_size_match_shard_rows={live_size_match}/59"},
    {"gate": "identity-verification-execution", "status": "pass" if identity_verification_execution_ready else "blocked", "reason": "targeted v61t rerun against ubuntu-1 waits for receipts/live shards"},
    {"gate": "full-page-hash-execution", "status": "blocked", "reason": f"verified_page_hash_rows={verified_page_hash_rows}/{required_page_hash_rows}"},
    {"gate": "complete-source-review-return", "status": "pass" if review_return_ready else "blocked", "reason": f"accepted_human_review_rows={human_review_rows}/7000"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "generation remains gated"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "v61br writes metadata and command rows only"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not release evidence"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61br Ubuntu-1 Post-Receipt Materialization Promotion Gate Boundary

This gate consumes v61bq receipt intake evidence and converts it into an
explicit post-receipt promotion checklist. It does not execute downloads, does
not hash full checkpoint pages, and does not run Mixtral generation.

Evidence emitted:

- target_root_path={target_root}
- target_root_count={target_root_count}
- target_root_outside_repo={target_root_outside_repo}
- tmp_target_rows={tmp_target_rows}
- expected_payload_execution_receipt_rows={expected_receipts}
- accepted_payload_execution_receipt_rows={accepted_receipts}
- missing_payload_execution_receipt_rows={missing_receipts}
- live_existing_shard_rows={live_existing}
- live_size_match_shard_rows={live_size_match}
- receipt_backed_materialization_input_ready={receipt_backed_input_ready}
- identity_verification_execution_ready={identity_verification_execution_ready}
- required_page_hash_rows={required_page_hash_rows}
- verified_page_hash_rows={verified_page_hash_rows}
- full_page_hash_execution_ready={full_page_hash_execution_ready}
- complete_source_review_return_ready={review_return_ready}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61br=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: post-receipt promotion gate for ubuntu-1 materialization
verification commands.
Blocked wording: completed checkpoint download, completed local checkpoint
materialization, full safetensors page-hash coverage, actual Mixtral
generation, production latency, near-frontier quality, or release readiness.
"""
(run_dir / "V61BR_UBUNTU1_POST_RECEIPT_MATERIALIZATION_PROMOTION_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61br_ubuntu1_post_receipt_materialization_promotion_gate",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "v61br_ubuntu1_post_receipt_materialization_promotion_gate_ready": 1,
    "source_v61bq_summary_sha256": sha256(v61bq_summary_path),
    "source_v61r_summary_sha256": sha256(v61r_summary_path),
    "source_v53t_summary_sha256": sha256(v53t_summary_path),
    "target_root_path": target_root,
    "target_root_outside_repo": target_root_outside_repo,
    "tmp_target_rows": tmp_target_rows,
    "expected_payload_execution_receipt_rows": expected_receipts,
    "accepted_payload_execution_receipt_rows": accepted_receipts,
    "live_size_match_shard_rows": live_size_match,
    "receipt_backed_materialization_input_ready": receipt_backed_input_ready,
    "identity_verification_execution_ready": identity_verification_execution_ready,
    "required_page_hash_rows": required_page_hash_rows,
    "verified_page_hash_rows": verified_page_hash_rows,
    "full_page_hash_execution_ready": full_page_hash_execution_ready,
    "complete_source_review_return_ready": review_return_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61br": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61br_ubuntu1_post_receipt_materialization_promotion_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": path.relative_to(run_dir).as_posix(), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61br_ubuntu1_post_receipt_materialization_promotion_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
