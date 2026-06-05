#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v15a_independent_reproduction_package"
PACKAGE_ID="${V15A_PACKAGE_ID:-package_001}"
PACKAGE_DIR="${V15A_PACKAGE_DIR:-$RESULTS_DIR/${PREFIX}/$PACKAGE_ID}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

mkdir -p "$PACKAGE_DIR"

"$ROOT_DIR/experiments/run_v14b_lite_prediction_lineage.sh" >/dev/null
"$ROOT_DIR/experiments/run_v14c_baseline_comparison.sh" >/dev/null
"$ROOT_DIR/experiments/run_v14d_routeqa_mini_scale.sh" >/dev/null
"$ROOT_DIR/experiments/run_v14e_ruler_niah_lite.sh" >/dev/null

python3 - "$ROOT_DIR" "$PACKAGE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import platform
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
package_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"

stages = [
    {
        "stage": "v14-b-lite",
        "summary": results / "v14b_lite_prediction_lineage_summary.csv",
        "decision": results / "v14b_lite_prediction_lineage_decision.csv",
        "run_dirs": [results / "v14b_lite_prediction_lineage_runs" / "lite_001"],
        "expected_dataset_rows": [50],
    },
    {
        "stage": "v14-c",
        "summary": results / "v14c_baseline_comparison_summary.csv",
        "decision": results / "v14c_baseline_comparison_decision.csv",
        "run_dirs": [results / "v14c_baseline_comparison_runs" / "comparison_001"],
        "expected_dataset_rows": [50],
    },
    {
        "stage": "v14-d",
        "summary": results / "v14d_routeqa_mini_scale_summary.csv",
        "decision": results / "v14d_routeqa_mini_scale_decision.csv",
        "run_dirs": [
            results / "v14d_routeqa_mini_scale_runs" / "scale_100",
            results / "v14d_routeqa_mini_scale_runs" / "scale_150",
        ],
        "expected_dataset_rows": [100, 150],
    },
    {
        "stage": "v14-e",
        "summary": results / "v14e_ruler_niah_lite_summary.csv",
        "decision": results / "v14e_ruler_niah_lite_decision.csv",
        "run_dirs": [results / "v14e_ruler_niah_lite_runs" / "niah_lite_001"],
        "expected_dataset_rows": [100],
    },
]

def ensure_dir(path):
    path.mkdir(parents=True, exist_ok=True)
    return path

for name in [
    "expected_summaries",
    "expected_decisions",
    "frozen_queries",
    "source_snapshots",
    "resource_envelopes",
    "run_manifests",
    "docs",
]:
    ensure_dir(package_dir / name)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def rel_to_package(path):
    return str(path.relative_to(package_dir))

artifact_rows = []
stage_rows = []
decision_rows = []

def copy_artifact(src, dst_rel, artifact_id, stage):
    dst = package_dir / dst_rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    artifact_rows.append(
        {
            "artifact_id": artifact_id,
            "stage": stage,
            "path": rel_to_package(dst),
            "source_path": str(src),
            "sha256": sha256(dst),
            "bytes": dst.stat().st_size,
        }
    )
    return dst

def csv_rows(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

for spec in stages:
    stage = spec["stage"]
    summary_copy = copy_artifact(spec["summary"], f"expected_summaries/{stage}_summary.csv", "expected_summary", stage)
    decision_copy = copy_artifact(spec["decision"], f"expected_decisions/{stage}_decision.csv", "expected_decision", stage)
    summary_rows = csv_rows(summary_copy)
    decisions = csv_rows(decision_copy)
    dataset_rows = [int(float(row.get("dataset_rows", "0") or 0)) for row in summary_rows]
    real_release_blocked = all(int(float(row.get("real_release_package_ready", "0") or 0)) == 0 for row in summary_rows)
    real_external_blocked = all(int(float(row.get("real_external_benchmark_verified", "0") or 0)) == 0 for row in summary_rows)
    candidate_blocked = all(int(float(row.get("candidate_external_benchmark_result_ready", "0") or 0)) == 0 for row in summary_rows)
    stage_ready = int(
        dataset_rows == spec["expected_dataset_rows"]
        and real_release_blocked
        and real_external_blocked
        and candidate_blocked
        and all(row.get("status") in {"pass", "blocked"} for row in decisions)
    )
    stage_rows.append(
        {
            "stage": stage,
            "summary_rows": len(summary_rows),
            "dataset_rows": "|".join(str(value) for value in dataset_rows),
            "expected_dataset_rows": "|".join(str(value) for value in spec["expected_dataset_rows"]),
            "candidate_external_benchmark_result_ready": int(not candidate_blocked),
            "real_external_benchmark_verified": int(not real_external_blocked),
            "real_release_package_ready": int(not real_release_blocked),
            "stage_ready": stage_ready,
        }
    )
    for run_dir in spec["run_dirs"]:
        run_id = run_dir.name
        for src_rel, dst_name, artifact_id in [
            ("dataset/queries.jsonl", f"{run_id}_queries.jsonl", "frozen_queries"),
            ("source/source_snapshot_rows.csv", f"{run_id}_source_snapshot_rows.csv", "source_snapshot_rows"),
            ("source/source_snapshot_manifest.json", f"{run_id}_source_snapshot_manifest.json", "source_snapshot_manifest"),
            ("resource/resource_envelope.json", f"{run_id}_resource_envelope.json", "resource_envelope"),
            ("sha256sums.txt", f"{run_id}_sha256sums.txt", "run_sha256_manifest"),
            ("run_summary.csv", f"{run_id}_run_summary.csv", "run_summary"),
        ]:
            src = run_dir / src_rel
            if src.is_file():
                folder = {
                    "frozen_queries": "frozen_queries",
                    "source_snapshot_rows": "source_snapshots",
                    "source_snapshot_manifest": "source_snapshots",
                    "resource_envelope": "resource_envelopes",
                    "run_sha256_manifest": "run_manifests",
                    "run_summary": "run_manifests",
                }[artifact_id]
                copy_artifact(src, f"{folder}/{stage}_{dst_name}", artifact_id, stage)
        niah_dataset = run_dir / "benchmark" / "ruler_synthetic" / "niah_dataset.jsonl"
        if niah_dataset.is_file():
            copy_artifact(niah_dataset, f"frozen_queries/{stage}_{run_id}_ruler_niah_dataset.jsonl", "ruler_niah_dataset", stage)

reproduce = package_dir / "REPRODUCE.sh"
reproduce.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"',
            'cd "$ROOT_DIR"',
            "experiments/test_v14b_lite_prediction_lineage.sh",
            "experiments/test_v14c_baseline_comparison.sh",
            "experiments/test_v14d_routeqa_mini_scale.sh",
            "experiments/test_v14e_ruler_niah_lite.sh",
            "",
        ]
    ),
    encoding="utf-8",
)
reproduce.chmod(0o755)
artifact_rows.append(
    {
        "artifact_id": "one_command_reproducer",
        "stage": "v15-a",
        "path": rel_to_package(reproduce),
        "source_path": "",
        "sha256": sha256(reproduce),
        "bytes": reproduce.stat().st_size,
    }
)

failure_modes = package_dir / "docs" / "FAILURE_MODES.md"
failure_modes.write_text(
    "\n".join(
        [
            "# Failure Modes",
            "",
            "- A summary row count mismatch means the package is not reproducing the frozen v14 boundary.",
            "- A sha256 mismatch means at least one copied artifact no longer matches the packaged manifest.",
            "- Any candidate, real external benchmark, or release flag set to 1 is a package failure.",
            "- RULER NIAH-lite in this package is runner-owned smoke evidence, not independent benchmark evidence.",
            "- HIP/GPU speed claims remain deferred unless same-run CPU/HIP timing evidence is supplied.",
            "",
        ]
    ),
    encoding="utf-8",
)
non_claims = package_dir / "docs" / "WHAT_THIS_DOES_NOT_CLAIM.md"
non_claims.write_text(
    "\n".join(
        [
            "# What This Does Not Claim",
            "",
            "- It does not claim independent RULER, LongBench, or external benchmark verification.",
            "- It does not claim a release-ready commercial product.",
            "- It does not claim GPU acceleration, Transformer replacement, or frontier LLM quality.",
            "- It does not claim the runner-owned NIAH-lite smoke is a publishable benchmark result.",
            "- It does not promote input-extractor baselines beyond diagnostic comparison.",
            "",
        ]
    ),
    encoding="utf-8",
)
for doc_path, artifact_id in [(failure_modes, "failure_modes"), (non_claims, "non_claim_notes")]:
    artifact_rows.append(
        {
            "artifact_id": artifact_id,
            "stage": "v15-a",
            "path": rel_to_package(doc_path),
            "source_path": "",
            "sha256": sha256(doc_path),
            "bytes": doc_path.stat().st_size,
        }
    )

env_manifest = {
    "manifest_scope": "v15-a-independent-reproduction-environment",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "python": sys.version,
    "platform": platform.platform(),
    "machine": platform.machine(),
    "processor": platform.processor(),
    "git_head": subprocess.run(["git", "rev-parse", "HEAD"], cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False).stdout.strip(),
    "git_status_short_hash": "sha256:" + hashlib.sha256(subprocess.run(["git", "status", "--short"], cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False).stdout.encode("utf-8")).hexdigest(),
}
env_path = package_dir / "environment_manifest.json"
env_path.write_text(json.dumps(env_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
artifact_rows.append(
    {
        "artifact_id": "environment_manifest",
        "stage": "v15-a",
        "path": rel_to_package(env_path),
        "source_path": "",
        "sha256": sha256(env_path),
        "bytes": env_path.stat().st_size,
    }
)

write_csv_fields = ["stage", "summary_rows", "dataset_rows", "expected_dataset_rows", "candidate_external_benchmark_result_ready", "real_external_benchmark_verified", "real_release_package_ready", "stage_ready"]
with summary_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=write_csv_fields, lineterminator="\n")
    writer.writeheader()
    writer.writerows(stage_rows)

all_stages_ready = all(row["stage_ready"] == 1 for row in stage_rows)
artifact_manifest_ready = int(bool(artifact_rows))
one_command_ready = int(reproduce.is_file() and reproduce.stat().st_size > 0)
non_claims_ready = int(failure_modes.is_file() and non_claims.is_file())
package_ready = int(all_stages_ready and artifact_manifest_ready and one_command_ready and non_claims_ready)
decision_rows = [
    ("v15-a-stage-summaries", "pass" if all_stages_ready else "blocked", f"ready={sum(row['stage_ready'] for row in stage_rows)}/{len(stage_rows)}"),
    ("v15-a-one-command-reproducer", "pass" if one_command_ready else "blocked", "REPRODUCE.sh runs v14-b/v14-c/v14-d/v14-e tests"),
    ("v15-a-artifact-manifest", "pass" if artifact_manifest_ready else "blocked", f"artifacts={len(artifact_rows)}"),
    ("v15-a-non-claim-docs", "pass" if non_claims_ready else "blocked", "failure modes and non-claim notes present"),
    ("v15-a-independent-reproduction-package", "pass" if package_ready else "blocked", f"ready={package_ready}"),
    ("candidate-external-benchmark-result", "blocked", "package preserves candidate_external_benchmark_result_ready=0"),
    ("real-release-package", "blocked", "package preserves real_release_package_ready=0"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)

artifact_manifest = package_dir / "artifact_manifest.csv"
with artifact_manifest.open("w", newline="", encoding="utf-8") as handle:
    fieldnames = ["artifact_id", "stage", "path", "source_path", "sha256", "bytes"]
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(artifact_rows)
artifact_rows.append(
    {
        "artifact_id": "artifact_manifest",
        "stage": "v15-a",
        "path": rel_to_package(artifact_manifest),
        "source_path": "",
        "sha256": sha256(artifact_manifest),
        "bytes": artifact_manifest.stat().st_size,
    }
)
with artifact_manifest.open("w", newline="", encoding="utf-8") as handle:
    fieldnames = ["artifact_id", "stage", "path", "source_path", "sha256", "bytes"]
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(artifact_rows)

package_manifest = {
    "manifest_scope": "v15-a-independent-reproduction-package",
    "package_ready": package_ready,
    "stages": stage_rows,
    "artifact_rows": len(artifact_rows),
    "one_command": "REPRODUCE.sh",
    "summary_csv": str(summary_csv),
    "decision_csv": str(decision_csv),
    "artifact_manifest": "artifact_manifest.csv",
    "candidate_external_benchmark_result_ready": 0,
    "real_external_benchmark_verified": 0,
    "real_release_package_ready": 0,
    "claim": "independent reproduction mechanics package for runner-owned v14 evidence; not independent benchmark verification",
}
manifest_path = package_dir / "package_manifest.json"
manifest_path.write_text(json.dumps(package_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

echo "v15a_package_dir: $PACKAGE_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
