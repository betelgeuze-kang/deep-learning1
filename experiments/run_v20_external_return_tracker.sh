#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v20_external_return_tracker"
TRACKER_ID="${V20_TRACKER_ID:-tracker_001}"
TRACKER_DIR="${V20_TRACKER_DIR:-$RESULTS_DIR/${PREFIX}/$TRACKER_ID}"
BUNDLE_DIR="${V19_BUNDLE_DIR:-$RESULTS_DIR/v19_external_submission_bundle/bundle_001}"
INTAKE_DIR="${V18_INTAKE_DIR:-$RESULTS_DIR/v18_external_evidence_intake/intake_001}"
THIRD_PARTY_DIR="${V20_THIRD_PARTY_RERUN_DIR:-}"
OFFICIAL_BENCHMARK_DIR="${V20_OFFICIAL_BENCHMARK_DIR:-}"
COMMERCIAL_POC_DIR="${V20_COMMERCIAL_POC_DIR:-}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

mkdir -p "$TRACKER_DIR"

"$ROOT_DIR/experiments/run_v19_external_submission_bundle.sh" >/dev/null
V18_THIRD_PARTY_RERUN_DIR="$THIRD_PARTY_DIR" \
V18_OFFICIAL_BENCHMARK_DIR="$OFFICIAL_BENCHMARK_DIR" \
V18_COMMERCIAL_POC_DIR="$COMMERCIAL_POC_DIR" \
"$ROOT_DIR/experiments/run_v18_external_evidence_intake.sh" >/dev/null

python3 - "$ROOT_DIR" "$TRACKER_DIR" "$BUNDLE_DIR" "$INTAKE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$THIRD_PARTY_DIR" "$OFFICIAL_BENCHMARK_DIR" "$COMMERCIAL_POC_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
tracker_dir = Path(sys.argv[2])
bundle_dir = Path(sys.argv[3])
intake_dir = Path(sys.argv[4])
summary_csv = Path(sys.argv[5])
decision_csv = Path(sys.argv[6])
third_party_arg = sys.argv[7]
official_arg = sys.argv[8]
commercial_arg = sys.argv[9]
tracker_dir.mkdir(parents=True, exist_ok=True)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

def bool_int(value):
    return int(str(value).strip().lower() in {"1", "true", "yes", "ready", "pass"})

v19_manifest = read_json(bundle_dir / "submission_manifest.json")
v18_manifest = read_json(intake_dir / "intake_manifest.json")
v18_tracks = {row["track"]: row for row in read_csv(intake_dir / "track_intake_rows.csv")}

track_specs = [
    {
        "track": "third_party_rerun",
        "supplied_dir": third_party_arg,
        "target_flag": "independent_rerun_actual_ready",
        "target_value": bool_int(v18_manifest.get("independent_rerun_actual_ready", 0)),
        "v18_env": "V18_THIRD_PARTY_RERUN_DIR",
        "v20_env": "V20_THIRD_PARTY_RERUN_DIR",
        "next_action": "send third_party_submission to a non-local reviewer, then verify returned files through v18",
        "requirements": [
            ("reviewer_identity.json", "external reviewer identity with conflict disclosure"),
            ("rerun_environment.json", "clean machine or independent environment manifest"),
            ("rerun_commands.csv", "same command, exit code, stdout hash, stderr hash"),
            ("rerun_manifest.json", "frozen query/source snapshot and package hash binding"),
            ("metric_delta_rows.csv", "metric delta tolerance rows"),
            ("review_rows.csv", "pass/fail review rows"),
            ("stdout.txt", "captured stdout"),
            ("stderr.txt", "captured stderr"),
        ],
    },
    {
        "track": "official_benchmark_reconciliation",
        "supplied_dir": official_arg,
        "target_flag": "candidate_external_benchmark_result_ready",
        "target_value": bool_int(v18_manifest.get("candidate_external_benchmark_result_ready", 0)),
        "v18_env": "V18_OFFICIAL_BENCHMARK_DIR",
        "v20_env": "V20_OFFICIAL_BENCHMARK_DIR",
        "next_action": "run a small official RULER or LongBench slice and return source/evaluator/prediction/metric/provenance files",
        "requirements": [
            ("official_source_snapshot.json", "official source snapshot"),
            ("official_evaluator_status.json", "official evaluator or container status"),
            ("raw_predictions.jsonl", "raw predictions before evaluation"),
            ("prediction_lineage.jsonl", "RouteMemory-derived prediction lineage"),
            ("metrics.json", "metrics with no oracle and no raw-input extractor"),
            ("provenance_manifest.json", "provenance with no oracle and no raw-input extractor"),
            ("reproducibility_package_manifest.json", "reproducibility package manifest"),
            ("candidate_result_rows.csv", "candidate external benchmark result rows"),
        ],
    },
    {
        "track": "commercial_local_poc",
        "supplied_dir": commercial_arg,
        "target_flag": "closed_corpus_poc_actual_ready",
        "target_value": bool_int(v18_manifest.get("closed_corpus_poc_actual_ready", 0)),
        "v18_env": "V18_COMMERCIAL_POC_DIR",
        "v20_env": "V20_COMMERCIAL_POC_DIR",
        "next_action": "run a closed-corpus local evidence-bound QA/audit system PoC, preferably codebase QA first",
        "requirements": [
            ("domain_manifest.json", "supported domain manifest"),
            ("corpus_manifest.json", "closed corpus manifest"),
            ("query_set.csv", "query set"),
            ("poc_result_rows.csv", "wrong-answer guard, citations, abstain, and latency rows"),
            ("audit_trail.csv", "query/evidence/prediction/review audit trail"),
            ("resource_envelope.json", "resource envelope"),
            ("privacy_review.json", "privacy review"),
            ("acceptance_review.csv", "acceptance review rows"),
        ],
    },
]

requirement_rows = []
blocker_rows = []
next_action_rows = []
for priority, spec in enumerate(track_specs, start=1):
    supplied_path = Path(spec["supplied_dir"]) if spec["supplied_dir"] else None
    supplied_dir_exists = int(bool(supplied_path and supplied_path.is_dir()))
    track_reason = v18_tracks.get(spec["track"], {}).get("reason", "not checked by v18")
    if not supplied_dir_exists:
        blocker_rows.append(
            {
                "track": spec["track"],
                "target_flag": spec["target_flag"],
                "blocker": "return-directory-missing",
                "detail": f"set {spec['v20_env']} or {spec['v18_env']} to a non-fixture return directory",
            }
        )
    elif spec["target_value"] == 0:
        blocker_rows.append(
            {
                "track": spec["track"],
                "target_flag": spec["target_flag"],
                "blocker": "v18-verifier-not-ready",
                "detail": track_reason,
            }
        )
    for rel, requirement in spec["requirements"]:
        present = int(bool(supplied_dir_exists and (supplied_path / rel).is_file()))
        status = "pass" if spec["target_value"] else ("present-not-ready" if present else "blocked")
        if supplied_dir_exists and not present:
            blocker_rows.append(
                {
                    "track": spec["track"],
                    "target_flag": spec["target_flag"],
                    "blocker": "required-file-missing",
                    "detail": rel,
                }
            )
        requirement_rows.append(
            {
                "track": spec["track"],
                "target_flag": spec["target_flag"],
                "required_file": rel,
                "requirement": requirement,
                "return_dir_supplied": supplied_dir_exists,
                "file_present": present,
                "target_ready": spec["target_value"],
                "status": status,
            }
        )
    next_action_rows.append(
        {
            "priority": priority,
            "track": spec["track"],
            "target_flag": spec["target_flag"],
            "target_ready": spec["target_value"],
            "recommended_next_action": "complete" if spec["target_value"] else spec["next_action"],
            "verification_env": spec["v20_env"],
        }
    )

with (tracker_dir / "return_requirement_rows.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(
        handle,
        fieldnames=[
            "track",
            "target_flag",
            "required_file",
            "requirement",
            "return_dir_supplied",
            "file_present",
            "target_ready",
            "status",
        ],
        lineterminator="\n",
    )
    writer.writeheader()
    writer.writerows(requirement_rows)

with (tracker_dir / "blocker_rows.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["track", "target_flag", "blocker", "detail"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(blocker_rows)

with (tracker_dir / "next_action_rows.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(
        handle,
        fieldnames=["priority", "track", "target_flag", "target_ready", "recommended_next_action", "verification_env"],
        lineterminator="\n",
    )
    writer.writeheader()
    writer.writerows(next_action_rows)

(tracker_dir / "RETURN_TRACKER.md").write_text(
    "\n".join(
        [
            "# v20 External Return Tracker",
            "",
            "This tracker sits above v19 and v18. It does not create external evidence. It records which returned files are still missing and which v18 flags remain blocked.",
            "",
            "Targets:",
            "- `independent_rerun_actual_ready=1` through a third-party clean-machine rerun.",
            "- `candidate_external_benchmark_result_ready=1` through an official source snapshot, official evaluator/container, no oracle, no raw-input extractor, raw predictions, metrics, provenance, and RouteMemory-derived prediction lineage.",
            "- `closed_corpus_poc_actual_ready=1` through a closed-corpus local evidence-bound QA/audit system PoC.",
            "",
            "Run with returned directories:",
            "",
            "```bash",
            "V20_THIRD_PARTY_RERUN_DIR=/path/to/third_party_return \\",
            "V20_OFFICIAL_BENCHMARK_DIR=/path/to/official_return \\",
            "V20_COMMERCIAL_POC_DIR=/path/to/commercial_poc_return \\",
            "experiments/run_v20_external_return_tracker.sh",
            "```",
            "",
            "Recommended first attachment for the commercial track: codebase QA. It is the tightest domain for citation accuracy, abstain behavior, wrong-answer guard, query-to-evidence latency, resource envelope, and audit trail.",
            "",
            "Current blocker rows are in `blocker_rows.csv`; required files are in `return_requirement_rows.csv`; next actions are in `next_action_rows.csv`.",
            "",
        ]
    ),
    encoding="utf-8",
)

external_return_dirs_supplied = sum(1 for spec in track_specs if spec["supplied_dir"] and Path(spec["supplied_dir"]).is_dir())
tracker_ready = 1
real_external_benchmark_verified = bool_int(v18_manifest.get("real_external_benchmark_verified", 0))
real_release_package_ready = bool_int(v18_manifest.get("real_release_package_ready", 0))
manifest = {
    "manifest_scope": "v20-external-return-tracker",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v19_submission_manifest_sha256": sha256(bundle_dir / "submission_manifest.json"),
    "v18_intake_manifest_sha256": sha256(intake_dir / "intake_manifest.json"),
    "tracker_ready": tracker_ready,
    "submission_bundle_ready": bool_int(v19_manifest.get("submission_bundle_ready", 0)),
    "external_return_dirs_supplied": external_return_dirs_supplied,
    "return_requirement_rows": len(requirement_rows),
    "blocker_rows": len(blocker_rows),
    "independent_rerun_actual_ready": bool_int(v18_manifest.get("independent_rerun_actual_ready", 0)),
    "candidate_external_benchmark_result_ready": bool_int(v18_manifest.get("candidate_external_benchmark_result_ready", 0)),
    "closed_corpus_poc_actual_ready": bool_int(v18_manifest.get("closed_corpus_poc_actual_ready", 0)),
    "real_external_benchmark_verified": real_external_benchmark_verified,
    "real_release_package_ready": real_release_package_ready,
    "claim": "external return tracker ready; actual readiness still depends on non-fixture v18 return directories",
}
(tracker_dir / "return_tracker_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "return_requirement_rows.csv",
    "blocker_rows.csv",
    "next_action_rows.csv",
    "RETURN_TRACKER.md",
    "return_tracker_manifest.json",
]
artifact_rows = []
for rel in artifact_rels:
    path = tracker_dir / rel
    artifact_rows.append({"artifact": Path(rel).stem, "path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
with (tracker_dir / "artifact_manifest.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["artifact", "path", "sha256", "bytes"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(artifact_rows)

summary_rows = [
    {
        "tracker_id": tracker_dir.name,
        "tracker_ready": tracker_ready,
        "submission_bundle_ready": bool_int(v19_manifest.get("submission_bundle_ready", 0)),
        "external_return_dirs_supplied": external_return_dirs_supplied,
        "return_requirement_rows": len(requirement_rows),
        "blocker_rows": len(blocker_rows),
        "independent_rerun_actual_ready": bool_int(v18_manifest.get("independent_rerun_actual_ready", 0)),
        "candidate_external_benchmark_result_ready": bool_int(v18_manifest.get("candidate_external_benchmark_result_ready", 0)),
        "closed_corpus_poc_actual_ready": bool_int(v18_manifest.get("closed_corpus_poc_actual_ready", 0)),
        "real_external_benchmark_verified": real_external_benchmark_verified,
        "real_release_package_ready": real_release_package_ready,
        "artifact_rows": len(artifact_rows),
    }
]
with summary_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(summary_rows[0]), lineterminator="\n")
    writer.writeheader()
    writer.writerows(summary_rows)

decision_rows = [
    ("external-return-tracker", "pass", "v19 submission bundle and v18 intake state are tracked"),
    ("third-party-rerun-return", "pass" if bool_int(v18_manifest.get("independent_rerun_actual_ready", 0)) else "blocked", v18_tracks.get("third_party_rerun", {}).get("reason", "not checked")),
    ("official-benchmark-return", "pass" if bool_int(v18_manifest.get("candidate_external_benchmark_result_ready", 0)) else "blocked", v18_tracks.get("official_benchmark_reconciliation", {}).get("reason", "not checked")),
    ("commercial-poc-return", "pass" if bool_int(v18_manifest.get("closed_corpus_poc_actual_ready", 0)) else "blocked", v18_tracks.get("commercial_local_poc", {}).get("reason", "not checked")),
    ("real-external-benchmark", "pass" if real_external_benchmark_verified else "blocked", "requires independent rerun actual plus official benchmark candidate"),
    ("real-release-package", "pass" if real_release_package_ready else "blocked", "requires returned external evidence plus release review"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "v20_external_return_tracker_dir: $TRACKER_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
