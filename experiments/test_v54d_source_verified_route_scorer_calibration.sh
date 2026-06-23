#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v54d_source_verified_route_scorer_calibration/calibration_001"
SUMMARY_CSV="$RESULTS_DIR/v54d_source_verified_route_scorer_calibration_summary.csv"
DECISION_CSV="$RESULTS_DIR/v54d_source_verified_route_scorer_calibration_decision.csv"

"$ROOT_DIR/experiments/run_v54d_source_verified_route_scorer_calibration.sh" >/dev/null

"$ROOT_DIR/tools/verify_artifact.py" v54-route-scorer-calibration \
  "$ROOT_DIR/v54/source_verified_route_scorer_calibration_contract.json" \
  --summary "$SUMMARY_CSV" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
sys.path.insert(0, str(root / "scripts"))

from route_scorer_contract import (  # noqa: E402
    CalibrationExample,
    calibrate_abstention_thresholds,
    decide_route,
    pairwise_ranking_loss,
    promotion_readiness,
    score_features,
)


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v54d_source_verified_route_scorer_calibration_ready": "1",
    "source_verified_pairwise_scorer_contract_ready": "1",
    "calibrated_abstention_ready": "1",
    "calibration_split_ready": "1",
    "calibration_example_rows": "4",
    "decision_rows": "5",
    "negative_control_rows": "4",
    "pairwise_loss_order_ready": "1",
    "wrong_answer_cost_gt_abstain_cost": "1",
    "calibration_wrong_count": "0",
    "external_label_source_ready": "0",
    "source_provenance_ready": "1",
    "heldout_metric_ready": "0",
    "promotion_ready": "0",
    "real_model_generation_ready": "0",
    "public_comparison_claim_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v54d {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "pairwise-ranking-loss",
    "calibrated-abstention",
    "invalid-provenance-negative-control",
    "weak-evidence-negative-control",
    "ambiguous-route-negative-control",
    "empty-candidate-negative-control",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v54d gate should pass: {gate}")
for gate in ["promotion", "real-model-generation", "public-comparison-claim", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v54d gate should remain blocked: {gate}")

required_files = [
    "calibration_example_rows.csv",
    "route_decision_rows.csv",
    "pairwise_loss_rows.csv",
    "abstention_threshold_rows.csv",
    "v54d_source_verified_route_scorer_calibration_manifest.json",
    "V54D_SOURCE_VERIFIED_ROUTE_SCORER_CALIBRATION_BOUNDARY.md",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v54d artifact: {rel}")

manifest = json.loads((run_dir / "v54d_source_verified_route_scorer_calibration_manifest.json").read_text(encoding="utf-8"))
for field in [
    "source_verified_pairwise_scorer_contract_ready",
    "calibrated_abstention_ready",
    "calibration_split_ready",
    "source_provenance_ready",
]:
    if manifest.get(field) != 1:
        raise SystemExit(f"v54d manifest should set {field}=1")
for field in [
    "external_label_source_ready",
    "heldout_metric_ready",
    "promotion_ready",
    "real_model_generation_ready",
    "public_comparison_claim_ready",
    "real_release_package_ready",
]:
    if manifest.get(field) != 0:
        raise SystemExit(f"v54d manifest should keep {field}=0")

threshold = read_csv(run_dir / "abstention_threshold_rows.csv")[0]
if threshold["wrong_answer_cost_gt_abstain_cost"] != "1" or threshold["wrong_count"] != "0":
    raise SystemExit("v54d thresholds should prefer abstention over wrong answers")
if float(threshold["margin_threshold"]) <= 0.0 or float(threshold["evidence_threshold"]) <= 0.0:
    raise SystemExit("v54d calibrated thresholds should be non-zero")

routes = {row["case_id"]: row for row in read_csv(run_dir / "route_decision_rows.csv")}
expected_routes = {
    "select-clear": ("0", "selected", "span-good"),
    "abstain-ambiguous": ("1", "ambiguous-route", ""),
    "abstain-weak": ("1", "weak-evidence", ""),
    "abstain-invalid": ("1", "invalid-provenance", ""),
    "abstain-empty": ("1", "no-candidate", ""),
}
for case_id, (abstained, reason, selected) in expected_routes.items():
    row = routes[case_id]
    if row["abstained"] != abstained or row["reason"] != reason or row["selected_candidate"] != selected:
        raise SystemExit(f"v54d route mismatch for {case_id}: {row}")

loss = read_csv(run_dir / "pairwise_loss_rows.csv")[0]
if loss["loss_order_ready"] != "1" or not float(loss["pairwise_ranking_loss"]) < float(loss["comparison_loss"]):
    raise SystemExit("v54d pairwise loss should reward correct score ordering")

if score_features((1.0, 2.0), (0.5, 0.25)) != 1.0:
    raise SystemExit("score_features dot product regression")
if pairwise_ranking_loss(3.0, 1.0) >= pairwise_ranking_loss(1.0, 3.0):
    raise SystemExit("pairwise ranking loss ordering regression")
if decide_route([], 0.9, True, 0.1, 0.1).reason != "no-candidate":
    raise SystemExit("empty candidates must abstain")
try:
    calibrate_abstention_thresholds(
        [CalibrationExample("bad", (("a", 1.0),), 0.9, True, "a", True)],
        wrong_cost=1.0,
        abstain_cost=1.0,
    )
except ValueError:
    pass
else:
    raise SystemExit("calibration must require wrong_cost > abstain_cost")
if promotion_readiness(external_label_source_ready=False, source_provenance_ready=True, heldout_metric_ready=False).promotion_ready:
    raise SystemExit("promotion must stay false without external labels and heldout metrics")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v54d sha mismatch: {rel}")

boundary = (run_dir / "V54D_SOURCE_VERIFIED_ROUTE_SCORER_CALIBRATION_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "source_verified_pairwise_scorer_contract_ready=1",
    "calibrated_abstention_ready=1",
    "promotion_ready=0",
    "real_model_generation_ready=0",
    "not a real-model generator promotion",
]:
    if snippet not in boundary:
        raise SystemExit(f"v54d boundary missing: {snippet}")
PY

echo "v54d source-verified route scorer calibration smoke passed"
