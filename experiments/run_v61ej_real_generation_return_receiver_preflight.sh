#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ej_real_generation_return_receiver_preflight"
RUN_ID="${V61EJ_RUN_ID:-preflight_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
SUPPLIED_DIR="${V61EJ_GENERATION_RESULT_DIR:-}"

if [[ "${V61EJ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61ej_real_generation_return_receiver_preflight_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61EH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61eh_real_generation_result_return_packet.sh" >/dev/null
V53R_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53r_complete_source_review_packet.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$SUPPLIED_DIR" <<'PY'
import csv
import hashlib
import json
import re
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
SHA_RE = re.compile(r"^sha256:[0-9a-f]{64}$")


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
    return dst


def status(flag):
    return "pass" if flag else "blocked"


v61eh_summary_path = results / "v61eh_real_generation_result_return_packet_summary.csv"
v61eh_decision_path = results / "v61eh_real_generation_result_return_packet_decision.csv"
v61eh_dir = results / "v61eh_real_generation_result_return_packet" / "packet_001"
v53r_summary_path = results / "v53r_complete_source_review_packet_summary.csv"
v53r_dir = results / "v53r_complete_source_review_packet" / "review_001"

for src, rel in [
    (v61eh_summary_path, "source_v61eh/v61eh_real_generation_result_return_packet_summary.csv"),
    (v61eh_decision_path, "source_v61eh/v61eh_real_generation_result_return_packet_decision.csv"),
    (v61eh_dir / "real_generation_required_artifact_rows.csv", "source_v61eh/real_generation_required_artifact_rows.csv"),
    (v61eh_dir / "real_prerequisite_binding_contract_rows.csv", "source_v61eh/real_prerequisite_binding_contract_rows.csv"),
    (v61eh_dir / "real_generation_result_return_packet/REQUIRED_FIELD_ROWS.csv", "source_v61eh/REQUIRED_FIELD_ROWS.csv"),
    (v61eh_dir / "real_generation_result_return_packet/REQUIRED_GENERATION_RESULT_ARTIFACTS.csv", "source_v61eh/REQUIRED_GENERATION_RESULT_ARTIFACTS.csv"),
    (v53r_summary_path, "source_v53r/v53r_complete_source_review_packet_summary.csv"),
    (v53r_dir / "review_query_packet_rows.csv", "source_v53r/review_query_packet_rows.csv"),
]:
    if not src.is_file():
        raise SystemExit(f"missing v61ej source artifact: {src}")
    copy(src, rel)

v61eh = read_csv(v61eh_summary_path)[0]
v53r = read_csv(v53r_summary_path)[0]
if v61eh.get("v61eh_real_generation_result_return_packet_ready") != "1":
    raise SystemExit("v61ej requires v61eh_real_generation_result_return_packet_ready=1")
if v53r.get("v53r_complete_source_review_packet_ready") != "1":
    raise SystemExit("v61ej requires v53r_complete_source_review_packet_ready=1")

required_artifact_rows = read_csv(v61eh_dir / "real_generation_required_artifact_rows.csv")
required_field_rows = read_csv(v61eh_dir / "real_generation_result_return_packet/REQUIRED_FIELD_ROWS.csv")
query_rows = read_csv(v53r_dir / "review_query_packet_rows.csv")
expected_query_ids = {row["query_id"] for row in query_rows}
expected_review_packet_ids = {row["review_query_packet_id"] for row in query_rows}
query_by_id = {row["query_id"]: row for row in query_rows}
expected_rows = len(query_rows)

fields_by_artifact = {}
for row in required_field_rows:
    fields_by_artifact.setdefault(row["result_artifact"], []).append(row["field_name"])
expected_rows_by_artifact = {row["result_artifact"]: int(row["expected_rows"]) for row in required_artifact_rows}
all_artifacts = [row["result_artifact"] for row in required_artifact_rows]

generation_result_dir_supplied = int(supplied_dir is not None)
generation_result_dir_exists = int(supplied_dir is not None and supplied_dir.is_dir())

csv_rows_by_artifact = {}
artifact_sha = {}
artifact_status_rows = []
supplied_artifacts = 0
preflight_pass_artifacts = 0
invalid_artifacts = 0
missing_artifacts = 0
field_pass_rows = 0
field_missing_rows = 0

for artifact in all_artifacts:
    required_fields = fields_by_artifact[artifact]
    path = supplied_dir / artifact if supplied_dir is not None else None
    supplied = bool(path and path.is_file())
    supplied_artifacts += int(supplied)
    missing_artifacts += int(not supplied)
    digest = sha256(path) if supplied else ""
    artifact_sha[artifact] = digest
    reasons = []
    rows = []
    fields = []
    if not supplied:
        reasons.append("result-artifact-not-supplied")
        field_missing_rows += len(required_fields)
    elif artifact.endswith(".csv"):
        with path.open(newline="", encoding="utf-8") as handle:
            reader = csv.DictReader(handle)
            fields = reader.fieldnames or []
            rows = list(reader)
        csv_rows_by_artifact[artifact] = rows
        missing_fields = [field for field in required_fields if field not in fields]
        field_pass_rows += len(required_fields) - len(missing_fields)
        field_missing_rows += len(missing_fields)
        if missing_fields:
            reasons.append("missing-fields:" + ";".join(missing_fields))
        if len(rows) != expected_rows_by_artifact[artifact]:
            reasons.append(f"row-count-mismatch:{len(rows)}")
        row_query_ids = {row.get("query_id", "") for row in rows}
        if row_query_ids != expected_query_ids:
            reasons.append("query-id-set-mismatch")
        if artifact == "real_model_generation_answer_rows.csv":
            row_packet_ids = {row.get("review_query_packet_id", "") for row in rows}
            if row_packet_ids != expected_review_packet_ids:
                reasons.append("review-query-packet-id-set-mismatch")
            if any(row.get("model_id") != model_id for row in rows):
                reasons.append("model-id-mismatch")
            if any(row.get("generation_status") not in {"generated", "abstained", "fallback"} for row in rows):
                reasons.append("generation-status-invalid")
            if any(not SHA_RE.match(row.get("answer_text_sha256", "")) for row in rows):
                reasons.append("answer-text-sha256-invalid")
            if any(not SHA_RE.match(row.get("run_transcript_sha256", "")) for row in rows):
                reasons.append("run-transcript-sha256-invalid")
        if artifact == "real_model_generation_citation_rows.csv":
            if any(row.get("citation_verified") != "1" for row in rows):
                reasons.append("citation-not-verified")
            for row in rows:
                query = query_by_id.get(row.get("query_id", ""))
                if query and row.get("source_file_sha256") != query.get("source_file_sha256"):
                    reasons.append("citation-source-hash-mismatch")
                    break
        if artifact == "real_model_generation_latency_rows.csv":
            for row in rows:
                try:
                    if float(row.get("total_ms", "0")) <= 0 or float(row.get("tokens_per_second", "0")) <= 0:
                        reasons.append("latency-non-positive")
                        break
                except ValueError:
                    reasons.append("latency-not-numeric")
                    break
        if supplied:
            copy(path, f"supplied_generation_result_return/{artifact}")
    else:
        if supplied:
            field_pass_rows += len(required_fields)
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                data = {}
                reasons.append("json-decode-error")
            missing_fields = [field for field in required_fields if field not in data]
            field_pass_rows -= len(missing_fields)
            field_missing_rows += len(missing_fields)
            if missing_fields:
                reasons.append("missing-fields:" + ";".join(missing_fields))
            if data.get("acceptance_decision") != "accepted":
                reasons.append("acceptance-decision-not-accepted")
            for key in ["expected_generation_rows", "accepted_answer_rows", "accepted_citation_rows", "accepted_latency_rows"]:
                if str(data.get(key)) != str(expected_rows):
                    reasons.append(f"{key}-mismatch")
            for key, target_artifact in [
                ("answer_rows_sha256", "real_model_generation_answer_rows.csv"),
                ("citation_rows_sha256", "real_model_generation_citation_rows.csv"),
                ("latency_rows_sha256", "real_model_generation_latency_rows.csv"),
            ]:
                if data.get(key) != artifact_sha.get(target_artifact, ""):
                    reasons.append(f"{key}-mismatch")
            copy(path, f"supplied_generation_result_return/{artifact}")
        else:
            field_missing_rows += len(required_fields)

    passed = int(not reasons)
    preflight_pass_artifacts += passed
    invalid_artifacts += int(supplied and not passed)
    artifact_status_rows.append(
        {
            "result_artifact": artifact,
            "artifact_supplied": str(int(supplied)),
            "artifact_preflight_pass": str(passed),
            "artifact_preflight_status": "pass" if passed else "blocked",
            "expected_rows": str(expected_rows_by_artifact[artifact]),
            "sha256": digest,
            "reason": "" if passed else ";".join(reasons),
            "counts_as_real_generation_result": "0",
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )

write_csv(run_dir / "receiver_preflight_artifact_rows.csv", list(artifact_status_rows[0].keys()), artifact_status_rows)

query_preflight_rows = []
answer_by_query = {
    row.get("query_id", ""): row
    for row in csv_rows_by_artifact.get("real_model_generation_answer_rows.csv", [])
}
for index, query in enumerate(query_rows):
    answer = answer_by_query.get(query["query_id"])
    supplied = int(answer is not None)
    query_preflight_rows.append(
        {
            "receiver_preflight_query_id": f"v61ej-query-{index:04d}",
            "review_query_packet_id": query["review_query_packet_id"],
            "query_id": query["query_id"],
            "source_span_id": query["source_span_id"],
            "result_supplied": str(supplied),
            "result_preflight_pass": str(int(supplied and preflight_pass_artifacts == len(all_artifacts))),
            "actual_model_generation_ready": "0",
        }
    )
write_csv(run_dir / "receiver_preflight_query_rows.csv", list(query_preflight_rows[0].keys()), query_preflight_rows)

preflight_ready = int(preflight_pass_artifacts == len(all_artifacts))
preflight_query_pass_rows = sum(int(row["result_preflight_pass"]) for row in query_preflight_rows)

requirement_rows = [
    {"requirement_id": "v61eh-return-packet-input", "status": "pass", "required_value": "1", "actual_value": v61eh["v61eh_real_generation_result_return_packet_ready"], "reason": "v61eh packet schema is bound"},
    {"requirement_id": "generation-result-dir-supplied", "status": status(generation_result_dir_supplied), "required_value": "1", "actual_value": str(generation_result_dir_supplied), "reason": "receiver preflight needs a returned generation-result directory"},
    {"requirement_id": "generation-result-dir-exists", "status": status(generation_result_dir_exists), "required_value": "1", "actual_value": str(generation_result_dir_exists), "reason": "supplied directory must exist"},
    {"requirement_id": "generation-result-artifact-preflight", "status": status(preflight_ready), "required_value": str(len(all_artifacts)), "actual_value": str(preflight_pass_artifacts), "reason": "all five artifacts must pass schema/hash/row preflight"},
    {"requirement_id": "actual-model-generation", "status": "blocked", "required_value": "accepted v61bt/v61de rows", "actual_value": "0", "reason": "v61ej is receiver preflight, not generation acceptance"},
]
write_csv(run_dir / "receiver_preflight_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61ej_real_generation_return_receiver_preflight_metrics",
    "v61eh_real_generation_result_return_packet_ready": v61eh["v61eh_real_generation_result_return_packet_ready"],
    "generation_result_dir_supplied": str(generation_result_dir_supplied),
    "generation_result_dir_exists": str(generation_result_dir_exists),
    "expected_generation_result_artifacts": str(len(all_artifacts)),
    "supplied_generation_result_artifacts": str(supplied_artifacts),
    "preflight_pass_generation_result_artifacts": str(preflight_pass_artifacts),
    "invalid_generation_result_artifacts": str(invalid_artifacts),
    "missing_generation_result_artifacts": str(missing_artifacts),
    "required_generation_result_field_rows": str(len(required_field_rows)),
    "preflight_field_pass_rows": str(field_pass_rows),
    "preflight_field_missing_rows": str(field_missing_rows),
    "expected_generation_rows": str(expected_rows),
    "receiver_preflight_query_rows": str(len(query_preflight_rows)),
    "receiver_preflight_query_pass_rows": str(preflight_query_pass_rows),
    "generation_result_receiver_preflight_ready": str(preflight_ready),
    "real_generation_result_artifacts": "0",
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ej": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "receiver_preflight_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61ej_real_generation_return_receiver_preflight_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

runtime_gap_rows = [
    {"gap": "v61eh-return-packet-input", "status": "ready", "reason": "v61eh packet is bound"},
    {"gap": "generation-result-dir", "status": "ready" if generation_result_dir_exists else "blocked", "reason": f"supplied={generation_result_dir_supplied}; exists={generation_result_dir_exists}"},
    {"gap": "generation-result-artifact-preflight", "status": "ready" if preflight_ready else "blocked", "reason": f"preflight_pass={preflight_pass_artifacts}/{len(all_artifacts)}"},
    {"gap": "actual-model-generation", "status": "blocked", "reason": "preflight is not v61bt/v61de acceptance"},
    {"gap": "latency-quality-release", "status": "blocked", "reason": "no accepted actual-generation evidence"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

decision_rows = [
    {"gate": "v61eh-return-packet-input", "status": "pass", "reason": "v61eh packet is bound"},
    {"gate": "generation-result-dir", "status": "pass" if generation_result_dir_exists else "blocked", "reason": f"supplied={generation_result_dir_supplied}; exists={generation_result_dir_exists}"},
    {"gate": "generation-result-artifact-preflight", "status": "pass" if preflight_ready else "blocked", "reason": f"preflight_pass={preflight_pass_artifacts}/{len(all_artifacts)}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "not an acceptance gate"},
    {"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata/result hashes only"},
]
write_csv(decision_csv, list(decision_rows[0].keys()), decision_rows)

boundary = f"""# v61ej Real Generation Return Receiver Preflight Boundary

This gate validates the receiver-side shape of a returned generation-result
directory before v61bt/v61de acceptance. It can prove schema/hash/row preflight
for supplied artifacts, but it never counts those artifacts as real generation
evidence and never opens actual-generation claims.

- generation_result_dir_supplied={generation_result_dir_supplied}
- generation_result_dir_exists={generation_result_dir_exists}
- expected_generation_result_artifacts={len(all_artifacts)}
- supplied_generation_result_artifacts={supplied_artifacts}
- preflight_pass_generation_result_artifacts={preflight_pass_artifacts}
- required_generation_result_field_rows={len(required_field_rows)}
- preflight_field_pass_rows={field_pass_rows}
- receiver_preflight_query_pass_rows={preflight_query_pass_rows}/{len(query_preflight_rows)}
- generation_result_receiver_preflight_ready={preflight_ready}
- real_generation_result_artifacts=0
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61ej=0
- checkpoint_payload_bytes_committed_to_repo=0

Allowed wording: receiver-side preflight for returned generation-result files.
Blocked wording: actual Mixtral generation, production latency, near-frontier
quality, or release readiness.
"""
(run_dir / "V61EJ_REAL_GENERATION_RETURN_RECEIVER_PREFLIGHT_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "artifact": "v61ej_real_generation_return_receiver_preflight",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "v61ej_real_generation_return_receiver_preflight_ready": 1,
    "generation_result_dir_supplied": generation_result_dir_supplied,
    "generation_result_dir_exists": generation_result_dir_exists,
    "preflight_pass_generation_result_artifacts": preflight_pass_artifacts,
    "generation_result_receiver_preflight_ready": preflight_ready,
    "real_generation_result_artifacts": 0,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61ej": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61ej_real_generation_return_receiver_preflight_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61ej_real_generation_return_receiver_preflight_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
