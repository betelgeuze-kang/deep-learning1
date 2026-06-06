#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v15b_nonfixture_review_independent_rerun"
REVIEW_ID="${V15B_REVIEW_ID:-review_001}"
REVIEW_DIR="${V15B_REVIEW_DIR:-$RESULTS_DIR/${PREFIX}/$REVIEW_ID}"
V15A_PACKAGE_DIR="${V15A_PACKAGE_DIR:-$RESULTS_DIR/v15a_independent_reproduction_package/package_001}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

mkdir -p "$REVIEW_DIR"

"$ROOT_DIR/experiments/run_v15a_independent_reproduction_package.sh" >/dev/null

python3 - "$ROOT_DIR" "$REVIEW_DIR" "$V15A_PACKAGE_DIR" <<'PY'
import json
import platform
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
review_dir = Path(sys.argv[2])
package_dir = Path(sys.argv[3])
review_dir.mkdir(parents=True, exist_ok=True)
identity = {
    "reviewer_id": "local-runner-v15b",
    "reviewer_kind": "runner-owned-local-review",
    "external_independent_reviewer": 0,
    "independent_rerun_mechanics_declared": 1,
    "nonfixture_review_declared": 1,
    "conflict_disclosure": "same-machine-runner-owned-review; not third-party external review",
    "created_at_utc": datetime.now(timezone.utc).isoformat(),
}
environment = {
    "environment_id": "local-v15b-rerun-environment",
    "platform": platform.platform(),
    "machine": platform.machine(),
    "python": sys.version,
    "package_dir": str(package_dir),
    "git_head": subprocess.run(["git", "rev-parse", "HEAD"], cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False).stdout.strip(),
    "external_independent_environment": 0,
}
(review_dir / "reviewer_identity.json").write_text(json.dumps(identity, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(review_dir / "rerun_environment.json").write_text(json.dumps(environment, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

set +e
bash "$V15A_PACKAGE_DIR/REPRODUCE.sh" >"$REVIEW_DIR/rerun_stdout.txt" 2>"$REVIEW_DIR/rerun_stderr.txt"
RERUN_STATUS=$?
set -e

python3 - "$ROOT_DIR" "$REVIEW_DIR" "$V15A_PACKAGE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RERUN_STATUS" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1])
review_dir = Path(sys.argv[2])
package_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
rerun_status = int(sys.argv[6])
results = root / "results"

stages = [
    ("v14-b-lite", package_dir / "expected_summaries" / "v14-b-lite_summary.csv", results / "v14b_lite_prediction_lineage_summary.csv"),
    ("v14-c", package_dir / "expected_summaries" / "v14-c_summary.csv", results / "v14c_baseline_comparison_summary.csv"),
    ("v14-d", package_dir / "expected_summaries" / "v14-d_summary.csv", results / "v14d_routeqa_mini_scale_summary.csv"),
    ("v14-e", package_dir / "expected_summaries" / "v14-e_summary.csv", results / "v14e_ruler_niah_lite_summary.csv"),
]

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

def numeric(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None

for folder in ["rerun_summaries", "package_hashes", "metric_deltas", "review"]:
    (review_dir / folder).mkdir(parents=True, exist_ok=True)

package_manifest = package_dir / "package_manifest.json"
package_artifact_manifest = package_dir / "artifact_manifest.csv"
package_hash_rows = [
    {"artifact": "v15a_package_manifest", "path": str(package_manifest), "sha256": sha256(package_manifest), "bytes": package_manifest.stat().st_size},
    {"artifact": "v15a_artifact_manifest", "path": str(package_artifact_manifest), "sha256": sha256(package_artifact_manifest), "bytes": package_artifact_manifest.stat().st_size},
    {"artifact": "v15a_reproducer", "path": str(package_dir / "REPRODUCE.sh"), "sha256": sha256(package_dir / "REPRODUCE.sh"), "bytes": (package_dir / "REPRODUCE.sh").stat().st_size},
]
with (review_dir / "package_hashes" / "package_hash_rows.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["artifact", "path", "sha256", "bytes"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(package_hash_rows)

command_rows = [
    {
        "command_id": "v15a_reproduce",
        "command": str(package_dir / "REPRODUCE.sh"),
        "exit_code": rerun_status,
        "stdout_path": "rerun_stdout.txt",
        "stderr_path": "rerun_stderr.txt",
        "stdout_sha256": sha256(review_dir / "rerun_stdout.txt"),
        "stderr_sha256": sha256(review_dir / "rerun_stderr.txt"),
    }
]
with (review_dir / "rerun_commands.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(command_rows[0]), lineterminator="\n")
    writer.writeheader()
    writer.writerows(command_rows)

metric_delta_rows = []
summary_match_rows = 0
for stage, expected_path, actual_path in stages:
    expected_copy = review_dir / "rerun_summaries" / f"{stage}_expected_summary.csv"
    actual_copy = review_dir / "rerun_summaries" / f"{stage}_rerun_summary.csv"
    shutil.copy2(expected_path, expected_copy)
    shutil.copy2(actual_path, actual_copy)
    expected_rows = read_csv(expected_copy)
    actual_rows = read_csv(actual_copy)
    stage_match = int(expected_rows == actual_rows)
    summary_match_rows += stage_match
    comparable_fields = sorted(set(expected_rows[0]) & set(actual_rows[0])) if expected_rows and actual_rows else []
    for row_index, (expected, actual) in enumerate(zip(expected_rows, actual_rows)):
        for field in comparable_fields:
            expected_num = numeric(expected.get(field))
            actual_num = numeric(actual.get(field))
            if expected_num is None or actual_num is None:
                if expected.get(field) != actual.get(field):
                    metric_delta_rows.append(
                        {
                            "stage": stage,
                            "row_index": row_index,
                            "field": field,
                            "expected": expected.get(field, ""),
                            "actual": actual.get(field, ""),
                            "delta": "",
                            "delta_within_tolerance": 0,
                        }
                    )
                continue
            delta = actual_num - expected_num
            metric_delta_rows.append(
                {
                    "stage": stage,
                    "row_index": row_index,
                    "field": field,
                    "expected": expected.get(field, ""),
                    "actual": actual.get(field, ""),
                    "delta": f"{delta:.6f}",
                    "delta_within_tolerance": int(abs(delta) <= 0.000001),
                }
            )

with (review_dir / "metric_deltas" / "metric_delta_rows.csv").open("w", newline="", encoding="utf-8") as handle:
    fieldnames = ["stage", "row_index", "field", "expected", "actual", "delta", "delta_within_tolerance"]
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(metric_delta_rows)

identity = json.loads((review_dir / "reviewer_identity.json").read_text(encoding="utf-8"))
environment = json.loads((review_dir / "rerun_environment.json").read_text(encoding="utf-8"))
metric_delta_pass_rows = sum(int(row["delta_within_tolerance"]) for row in metric_delta_rows)
metric_delta_ready = int(bool(metric_delta_rows) and metric_delta_pass_rows == len(metric_delta_rows))
package_hash_bound = int(all(row["sha256"].startswith("sha256:") and Path(row["path"]).is_file() for row in package_hash_rows))
reviewer_identity_bound = int(identity.get("independent_rerun_mechanics_declared") == 1 and identity.get("nonfixture_review_declared") == 1)
rerun_environment_bound = int(bool(environment.get("environment_id")) and bool(environment.get("git_head")))
review_rows = [
    ("v15a_package_hash_bound", "pass" if package_hash_bound else "blocked", f"artifacts={len(package_hash_rows)}"),
    ("reviewer_identity_bound", "pass" if reviewer_identity_bound else "blocked", identity.get("reviewer_kind", "")),
    ("rerun_environment_bound", "pass" if rerun_environment_bound else "blocked", environment.get("environment_id", "")),
    ("reproduce_command_exit_zero", "pass" if rerun_status == 0 else "blocked", f"exit_code={rerun_status}"),
    ("summary_exact_match", "pass" if summary_match_rows == len(stages) else "blocked", f"matches={summary_match_rows}/{len(stages)}"),
    ("metric_delta_within_tolerance", "pass" if metric_delta_ready else "blocked", f"pass={metric_delta_pass_rows}/{len(metric_delta_rows)}"),
    ("candidate_external_benchmark_blocked", "pass", "candidate_external_benchmark_result_ready remains 0"),
    ("real_release_blocked", "pass", "real_release_package_ready remains 0"),
]
with (review_dir / "review" / "review_rows.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(review_rows)

nonfixture_review_package_ready = int(
    package_hash_bound
    and reviewer_identity_bound
    and rerun_environment_bound
    and rerun_status == 0
    and summary_match_rows == len(stages)
    and metric_delta_ready
)
summary_rows = [
    {
        "review_id": review_dir.name,
        "review_rows": len(review_rows),
        "pass_review_rows": sum(1 for _, status, _ in review_rows if status == "pass"),
        "metric_delta_rows": len(metric_delta_rows),
        "metric_delta_pass_rows": metric_delta_pass_rows,
        "package_hash_bound": package_hash_bound,
        "reviewer_identity_bound": reviewer_identity_bound,
        "rerun_environment_bound": rerun_environment_bound,
        "rerun_exit_code": rerun_status,
        "summary_match_rows": summary_match_rows,
        "independent_rerun_mechanics_ready": nonfixture_review_package_ready,
        "nonfixture_review_package_ready": nonfixture_review_package_ready,
        "external_independent_reviewer": int(identity.get("external_independent_reviewer", 0)),
        "candidate_external_benchmark_result_ready": 0,
        "real_external_benchmark_verified": 0,
        "real_release_package_ready": 0,
    }
]
with summary_csv.open("w", newline="", encoding="utf-8") as handle:
    fieldnames = list(summary_rows[0])
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(summary_rows)

decision_rows = [
    ("v15-b-package-hash-bound", "pass" if package_hash_bound else "blocked", f"artifacts={len(package_hash_rows)}"),
    ("v15-b-reviewer-identity", "pass" if reviewer_identity_bound else "blocked", identity.get("reviewer_kind", "")),
    ("v15-b-rerun-environment", "pass" if rerun_environment_bound else "blocked", environment.get("environment_id", "")),
    ("v15-b-rerun-command", "pass" if rerun_status == 0 else "blocked", f"exit_code={rerun_status}"),
    ("v15-b-metric-delta", "pass" if metric_delta_ready else "blocked", f"pass={metric_delta_pass_rows}/{len(metric_delta_rows)}"),
    ("v15-b-nonfixture-review-independent-rerun", "pass" if nonfixture_review_package_ready else "blocked", f"ready={nonfixture_review_package_ready}"),
    ("candidate-external-benchmark-result", "blocked", "local v15-b review does not set candidate external benchmark evidence"),
    ("real-external-benchmark", "blocked", "local v15-b review is not external independent verification"),
    ("real-release-package", "blocked", "release remains blocked"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)

artifact_candidates = [
    "reviewer_identity.json",
    "rerun_environment.json",
    "rerun_stdout.txt",
    "rerun_stderr.txt",
    "rerun_commands.csv",
    "package_hashes/package_hash_rows.csv",
    "metric_deltas/metric_delta_rows.csv",
    "review/review_rows.csv",
]
artifact_candidates.extend(str(path.relative_to(review_dir)) for path in sorted((review_dir / "rerun_summaries").glob("*.csv")))
artifact_rows = []
for rel in artifact_candidates:
    path = review_dir / rel
    artifact_rows.append({"artifact": Path(rel).stem, "path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
artifact_manifest = review_dir / "artifact_manifest.csv"
with artifact_manifest.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["artifact", "path", "sha256", "bytes"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(artifact_rows)

manifest = {
    "manifest_scope": "v15-b-nonfixture-review-independent-rerun-evidence",
    "review_ready": nonfixture_review_package_ready,
    "v15a_package_dir": str(package_dir),
    "v15a_package_manifest_sha256": sha256(package_manifest),
    "reviewer_identity_bound": reviewer_identity_bound,
    "rerun_environment_bound": rerun_environment_bound,
    "metric_delta_ready": metric_delta_ready,
    "external_independent_reviewer": int(identity.get("external_independent_reviewer", 0)),
    "candidate_external_benchmark_result_ready": 0,
    "real_external_benchmark_verified": 0,
    "real_release_package_ready": 0,
    "claim": "local nonfixture review and rerun evidence mechanics for v15-a; not third-party independent benchmark verification",
}
(review_dir / "review_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

echo "v15b_review_dir: $REVIEW_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
