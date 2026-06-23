#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v54d_source_verified_route_scorer_calibration"
RUN_ID="${V54D_RUN_ID:-calibration_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from datetime import datetime, timezone
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


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


weights = (1.0, 0.5, -0.25)
positive_score = score_features(weights, (1.0, 0.8, 0.0), bias=0.1)
negative_score = score_features(weights, (0.3, 0.1, 1.0), bias=0.1)
good_loss = pairwise_ranking_loss(positive_score, negative_score, weights=weights)
bad_loss = pairwise_ranking_loss(negative_score, positive_score, weights=weights)
if not good_loss < bad_loss:
    raise SystemExit("pairwise ranking loss must decrease when positive score outranks negative score")

calibration_examples = [
    CalibrationExample("cal-good", (("span-good", 2.0), ("span-wrong", 1.0)), 0.90, True, "span-good", True),
    CalibrationExample("cal-ambiguous-wrong", (("span-wrong", 1.10), ("span-good", 1.05)), 0.90, True, "span-good", True),
    CalibrationExample("cal-weak-wrong", (("span-wrong", 2.0), ("span-good", 1.0)), 0.20, True, "span-good", True),
    CalibrationExample("cal-invalid", (("span-good", 2.0), ("span-wrong", 1.0)), 0.90, False, None, False),
]
thresholds = calibrate_abstention_thresholds(calibration_examples, wrong_cost=5.0, abstain_cost=1.0)
if thresholds.wrong_count != 0:
    raise SystemExit("calibrated abstention should avoid wrong calibration selections")

decision_cases = [
    ("select-clear", (("span-good", 2.0), ("span-wrong", 1.0)), 0.90, True, "selected", "span-good"),
    ("abstain-ambiguous", (("span-good", 1.10), ("span-wrong", 1.09)), 0.90, True, "ambiguous-route", None),
    ("abstain-weak", (("span-good", 2.0), ("span-wrong", 1.0)), 0.10, True, "weak-evidence", None),
    ("abstain-invalid", (("span-good", 2.0), ("span-wrong", 1.0)), 0.90, False, "invalid-provenance", None),
    ("abstain-empty", tuple(), 0.90, True, "no-candidate", None),
]
decision_rows = []
for case_id, candidates, evidence_probability, provenance_valid, expected_reason, expected_selected in decision_cases:
    decision = decide_route(
        candidates,
        evidence_probability,
        provenance_valid,
        thresholds.margin_threshold,
        thresholds.evidence_threshold,
    )
    if decision.reason != expected_reason or decision.selected_candidate != expected_selected:
        raise SystemExit(f"{case_id} decision mismatch: {decision}")
    decision_rows.append(
        {
            "case_id": case_id,
            "candidate_count": len(candidates),
            "evidence_probability": f"{evidence_probability:.6f}",
            "provenance_valid": int(provenance_valid),
            "margin_threshold": f"{thresholds.margin_threshold:.12f}",
            "evidence_threshold": f"{thresholds.evidence_threshold:.12f}",
            "selected_candidate": decision.selected_candidate or "",
            "abstained": int(decision.abstained),
            "reason": decision.reason,
            "margin": f"{decision.margin:.12f}",
        }
    )

readiness = promotion_readiness(
    external_label_source_ready=False,
    source_provenance_ready=True,
    heldout_metric_ready=False,
)
if readiness.promotion_ready:
    raise SystemExit("local scorer calibration must not open promotion without external labels and heldout metrics")

calibration_rows = []
for example in calibration_examples:
    calibration_rows.append(
        {
            "example_id": example.example_id,
            "candidate_count": len(example.candidates),
            "evidence_probability": f"{example.evidence_probability:.6f}",
            "provenance_valid": int(example.provenance_valid),
            "correct_candidate": example.correct_candidate or "",
            "should_answer": int(example.should_answer),
            "calibration_split": "calibration",
        }
    )

loss_rows = [
    {
        "loss_id": "positive-outranks-negative",
        "positive_score": f"{positive_score:.6f}",
        "negative_score": f"{negative_score:.6f}",
        "pairwise_ranking_loss": f"{good_loss:.12f}",
        "comparison_loss": f"{bad_loss:.12f}",
        "loss_order_ready": int(good_loss < bad_loss),
    }
]

threshold_rows = [
    {
        "threshold_id": "calibration-cost-min",
        "margin_threshold": f"{thresholds.margin_threshold:.12f}",
        "evidence_threshold": f"{thresholds.evidence_threshold:.12f}",
        "wrong_cost": "5.000000",
        "abstain_cost": "1.000000",
        "wrong_answer_cost_gt_abstain_cost": 1,
        "total_cost": f"{thresholds.total_cost:.6f}",
        "wrong_count": thresholds.wrong_count,
        "unnecessary_abstain_count": thresholds.unnecessary_abstain_count,
        "correct_abstain_count": thresholds.correct_abstain_count,
    }
]

write_csv(run_dir / "calibration_example_rows.csv", list(calibration_rows[0]), calibration_rows)
write_csv(run_dir / "route_decision_rows.csv", list(decision_rows[0]), decision_rows)
write_csv(run_dir / "pairwise_loss_rows.csv", list(loss_rows[0]), loss_rows)
write_csv(run_dir / "abstention_threshold_rows.csv", list(threshold_rows[0]), threshold_rows)

manifest = {
    "manifest_scope": "v54d-source-verified-route-scorer-calibration",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "route_scorer_contract_source_sha256": sha256(root / "scripts" / "route_scorer_contract.py"),
    "source_verified_pairwise_scorer_contract_ready": 1,
    "calibrated_abstention_ready": 1,
    "calibration_split_ready": 1,
    "external_label_source_ready": 0,
    "source_provenance_ready": 1,
    "heldout_metric_ready": 0,
    "promotion_ready": 0,
    "promotion_blocker_reason": readiness.reason,
    "real_model_generation_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_release_package_ready": 0,
}
write_json(run_dir / "v54d_source_verified_route_scorer_calibration_manifest.json", manifest)
boundary_lines = [
    "# v54d Source-Verified Route Scorer Calibration Boundary",
    "",
    "This packet implements the pairwise scoring and calibrated abstention contract for RouteMemory.",
    "",
    "Ready:",
    "",
    "- source_verified_pairwise_scorer_contract_ready=1",
    "- calibrated_abstention_ready=1",
    "- calibration_split_ready=1",
    "",
    "Blocked:",
    "",
    "- external_label_source_ready=0",
    "- heldout_metric_ready=0",
    "- promotion_ready=0",
    "- real_model_generation_ready=0",
    "- public_comparison_claim_ready=0",
    "- real_release_package_ready=0",
    "",
    "Boundary:",
    "",
    "- This is a deterministic local contract smoke, not a real-model generator promotion.",
    "- Promotion requires external labels, source provenance, and heldout metrics.",
]
(run_dir / "V54D_SOURCE_VERIFIED_ROUTE_SCORER_CALIBRATION_BOUNDARY.md").write_text("\n".join(boundary_lines) + "\n", encoding="utf-8")

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary = {
    "run_id": run_dir.name,
    "v54d_source_verified_route_scorer_calibration_ready": 1,
    "source_verified_pairwise_scorer_contract_ready": 1,
    "calibrated_abstention_ready": 1,
    "calibration_split_ready": 1,
    "calibration_example_rows": len(calibration_rows),
    "decision_rows": len(decision_rows),
    "negative_control_rows": 4,
    "pairwise_loss_order_ready": 1,
    "wrong_answer_cost_gt_abstain_cost": 1,
    "calibration_wrong_count": thresholds.wrong_count,
    "external_label_source_ready": 0,
    "source_provenance_ready": 1,
    "heldout_metric_ready": 0,
    "promotion_ready": 0,
    "real_model_generation_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_release_package_ready": 0,
    "artifact_rows": len(sha_rows),
}
write_csv(summary_csv, list(summary), [summary])

decision_summary_rows = [
    {"gate": "pairwise-ranking-loss", "status": "pass", "reason": "positive/negative gap lowers loss"},
    {"gate": "calibrated-abstention", "status": "pass", "reason": "calibration split minimizes wrong-answer cost before abstain cost"},
    {"gate": "invalid-provenance-negative-control", "status": "pass", "reason": "invalid provenance abstains"},
    {"gate": "weak-evidence-negative-control", "status": "pass", "reason": "weak evidence abstains"},
    {"gate": "ambiguous-route-negative-control", "status": "pass", "reason": "low margin abstains"},
    {"gate": "empty-candidate-negative-control", "status": "pass", "reason": "missing candidates abstain"},
    {"gate": "promotion", "status": "blocked", "reason": readiness.reason},
    {"gate": "real-model-generation", "status": "blocked", "reason": "generator is not implemented or measured here"},
    {"gate": "public-comparison-claim", "status": "blocked", "reason": "external labels and heldout metrics missing"},
    {"gate": "real-release-package", "status": "blocked", "reason": "release evidence missing"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_summary_rows)
PY

echo "v54d_source_verified_route_scorer_calibration_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
