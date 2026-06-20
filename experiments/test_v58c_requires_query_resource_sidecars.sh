#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
V58B_DIR="$RESULTS_DIR/v58b_blind_eval_candidate_500/candidate_001"
V58B_SUMMARY="$RESULTS_DIR/v58b_blind_eval_candidate_500_summary.csv"
EVIDENCE_DIR="$(mktemp -d)"
CREATED_V58B=0

cleanup() {
  rm -rf "$EVIDENCE_DIR"
  if [ "$CREATED_V58B" = "1" ]; then
    rm -rf "$RESULTS_DIR/v58b_blind_eval_candidate_500"
    rm -f "$V58B_SUMMARY" "$RESULTS_DIR/v58b_blind_eval_candidate_500_decision.csv"
  fi
}
trap cleanup EXIT

if [ ! -s "$V58B_SUMMARY" ] || [ ! -s "$V58B_DIR/blind_query_freeze_rows.csv" ]; then
  CREATED_V58B=1
  rm -rf "$V58B_DIR"
  mkdir -p "$V58B_DIR"
  python3 - "$V58B_DIR" "$V58B_SUMMARY" "$RESULTS_DIR/v58b_blind_eval_candidate_500_decision.csv" <<'PY'
import csv
import json
import sys
from pathlib import Path

v58b_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
systems = [("blind_A", "D"), ("blind_B", "E"), ("blind_C", "F"), ("blind_D", "G"), ("blind_E", "H")]

def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

query_rows = [{"blind_eval_id": f"v58b_{i:04d}", "domain_pack": "synthetic"} for i in range(1, 501)]
response_rows = []
for query in query_rows:
    for blind_system_id, source_system_id in systems:
        response_rows.append({
            "blind_response_id": f"{query['blind_eval_id']}_{blind_system_id}",
            "blind_eval_id": query["blind_eval_id"],
            "blind_system_id": blind_system_id,
            "source_system_id": source_system_id,
        })
identity_rows = [
    {
        "blind_system_id": blind_system_id,
        "source_system_id": source_system_id,
        "source_system_name": f"synthetic-{source_system_id}",
        "sealed_until_scoring_complete": "1",
        "identity_hidden_from_reviewer": "1",
    }
    for blind_system_id, source_system_id in systems
]
write_csv(v58b_dir / "blind_query_freeze_rows.csv", list(query_rows[0]), query_rows)
write_csv(v58b_dir / "blind_response_template_rows.csv", list(response_rows[0]), response_rows)
write_csv(v58b_dir / "sealed_identity_key_rows.csv", list(identity_rows[0]), identity_rows)
for name, fields in {
    "sealed_answer_key_rows.csv": ["blind_eval_id"],
    "blind_reviewer_packet_template_rows.csv": ["blind_response_id"],
    "blind_adjudication_template_rows.csv": ["blind_response_id"],
    "blind_evidence_budget_rows.csv": ["blind_system_id"],
    "V58B_BLIND_EVAL_CANDIDATE_BOUNDARY.md": None,
    "v58b_blind_eval_candidate_manifest.json": None,
    "sha256_manifest.csv": ["path", "sha256", "bytes"],
}.items():
    path = v58b_dir / name
    if fields is None:
        if name.endswith(".json"):
            path.write_text(json.dumps({"synthetic": True}) + "\n", encoding="utf-8")
        else:
            path.write_text("synthetic v58b fixture for v58c sidecar guard\n", encoding="utf-8")
    else:
        write_csv(path, fields, [{field: "synthetic" for field in fields}])
write_csv(summary_csv, ["v58b_blind_eval_candidate_ready"], [{"v58b_blind_eval_candidate_ready": "1"}])
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": "synthetic", "status": "pass", "reason": "sidecar guard fixture"}])
PY
fi

python3 - "$V58B_DIR" "$EVIDENCE_DIR" <<'PY'
import csv
import hashlib
import sys
from pathlib import Path

v58b_dir = Path(sys.argv[1])
evidence_dir = Path(sys.argv[2])

def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()

def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

with (v58b_dir / "blind_response_template_rows.csv").open(newline="", encoding="utf-8") as handle:
    templates = list(csv.DictReader(handle))
response_rows = []
for template in templates:
    answer = f"synthetic answer for {template['blind_response_id']}"
    response_rows.append({
        "blind_response_id": template["blind_response_id"],
        "blind_eval_id": template["blind_eval_id"],
        "blind_system_id": template["blind_system_id"],
        "response_text": answer,
        "citation_source_span_id": "synthetic-span",
        "abstained": "0",
        "output_sha256": sha256_text(answer),
        "latency_ns": "1",
        "memory_peak_bytes": "0",
        "cost_usd": "0",
        "model_run_id": "synthetic-run",
        "credential_redacted": "1",
        "resource_trace_sha256": "",
    })
identity_rows = []
for source_system_id in ["A", "B", "C", "D", "E", "F", "G", "H"]:
    identity_rows.append({
        "blind_system_id": f"blind_{source_system_id}",
        "source_system_id": source_system_id,
        "model_or_architecture_id": f"synthetic-{source_system_id}",
        "corpus_id": "synthetic-corpus",
        "context_budget": "4096",
        "retrieval_budget": "8",
        "prompt_template_sha256": "sha256:" + "1" * 64,
        "source_manifest_sha256": "sha256:" + "2" * 64,
        "model_size_class": "synthetic",
        "external_api_used": "1" if source_system_id == "F" else "0",
        "credential_redacted": "1",
        "run_metadata_sha256": "sha256:" + "3" * 64,
    })
write_csv(evidence_dir / "blind_response_rows.csv", list(response_rows[0]), response_rows)
write_csv(evidence_dir / "run_identity_rows.csv", list(identity_rows[0]), identity_rows)
PY

V58C_BLIND_RESPONSE_EVIDENCE_DIR="$EVIDENCE_DIR" \
V58C_REUSE_EXISTING=1 \
"$ROOT_DIR/experiments/run_v58c_blind_response_evidence_intake.sh" >/dev/null

python3 - "$RESULTS_DIR/v58c_blind_response_evidence_intake_summary.csv" \
  "$RESULTS_DIR/v58c_blind_response_evidence_intake/intake_001/blind_response_validation_rows.csv" <<'PY'
import csv
import sys
from pathlib import Path

summary_path = Path(sys.argv[1])
validation_path = Path(sys.argv[2])
with summary_path.open(newline="", encoding="utf-8") as handle:
    summary = next(csv.DictReader(handle))
if summary["query_split_ready"] != "0":
    raise SystemExit("v58c accepted missing query_split_rows.csv")
if summary["resource_rows_ready"] != "0":
    raise SystemExit("v58c accepted missing resource_rows.csv")
if summary["required_blind_response_ready"] != "0":
    raise SystemExit("v58c accepted response evidence without query/resource sidecars")
with validation_path.open(newline="", encoding="utf-8") as handle:
    reasons = "\n".join(row["reason"] for row in csv.DictReader(handle))
if "query-split-rows-missing" not in reasons:
    raise SystemExit("v58c did not report missing query split sidecar")
if "resource-rows-missing" not in reasons:
    raise SystemExit("v58c did not report missing resource sidecar")
PY

echo "v58c query/resource sidecar guard smoke passed"
