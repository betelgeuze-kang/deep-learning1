#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v52x_de_external_measured_bake_import/import_001"
SUMMARY_CSV="$RESULTS_DIR/v52x_de_external_measured_bake_import_summary.csv"
DECISION_CSV="$RESULTS_DIR/v52x_de_external_measured_bake_import_decision.csv"
V52P_DIR="$RESULTS_DIR/v52p_30b_open_weight_llm_rag_v53e_1000/measured_001"
V52Q_DIR="$RESULTS_DIR/v52q_70b_open_weight_llm_rag_v53e_1000/measured_001"

V52X_REUSE_EXISTING="${V52X_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v52x_de_external_measured_bake_import.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$V52P_DIR" "$V52Q_DIR" <<'PY'
import csv
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
v52p_dir = Path(sys.argv[4])
v52q_dir = Path(sys.argv[5])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v52x_de_external_measured_bake_import_ready": "1",
    "d_external_bake_staged": "1",
    "e_external_bake_staged": "1",
    "d_v53e_absorb_ready": "1",
    "e_v53e_absorb_ready": "1",
    "required_30b_baseline_ready": "0",
    "required_70b_baseline_ready": "0",
    "v52_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v52x {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "external-bake-dir-resolved",
    "d-external-bake-staged",
    "e-external-bake-staged",
    "v52-de-absorb-ready",
    "local-monolithic-ollama-bypassed",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v52x gate should pass: {gate}")
if decisions.get("30b-70b-release-baseline-ready") != "blocked":
    raise SystemExit("v52x should keep PM/release D/E readiness blocked")

for prefix_dir, system_id, prefix, manifest_name in [
    (v52p_dir, "D", "d", "v52p_30b_open_weight_llm_rag_v53e_1000_manifest.json"),
    (v52q_dir, "E", "e", "v52q_70b_open_weight_llm_rag_v53e_1000_manifest.json"),
]:
    answers = read_csv(prefix_dir / f"{prefix}_answer_rows.csv")
    if len(answers) != 1000 or {row["system_id"] for row in answers} != {system_id}:
        raise SystemExit(f"v52x staged {system_id} answer rows mismatch")
    manifest = json.loads((prefix_dir / manifest_name).read_text(encoding="utf-8"))
    if manifest.get("external_bake_import") != 1:
        raise SystemExit(f"v52x staged {system_id} manifest should mark external_bake_import=1")
    identity = json.loads((prefix_dir / "model_identity.json").read_text(encoding="utf-8"))
    if identity.get("system_id") != system_id or identity.get("runner") != "external-bake-import":
        raise SystemExit(f"v52x staged {system_id} identity mismatch")

boundary = (run_dir / "V52X_DE_EXTERNAL_MEASURED_BAKE_IMPORT_BOUNDARY.md").read_text(encoding="utf-8")
if "d_v53e_absorb_ready=1" not in boundary or "e_v53e_absorb_ready=1" not in boundary:
    raise SystemExit("v52x boundary missing absorb readiness")
PY

echo "v52x D/E external measured bake import smoke passed"
