#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v21_external_review_dispatch_kit"
DISPATCH_ID="${V21_DISPATCH_ID:-dispatch_001}"
DISPATCH_DIR="${V21_DISPATCH_DIR:-$RESULTS_DIR/${PREFIX}/$DISPATCH_ID}"
V19_BUNDLE_DIR="${V19_BUNDLE_DIR:-$RESULTS_DIR/v19_external_submission_bundle/bundle_001}"
V20_TRACKER_DIR="${V20_TRACKER_DIR:-$RESULTS_DIR/v20_external_return_tracker/tracker_001}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

mkdir -p "$DISPATCH_DIR"

"$ROOT_DIR/experiments/run_v20_external_return_tracker.sh" >/dev/null

python3 - "$ROOT_DIR" "$DISPATCH_DIR" "$V19_BUNDLE_DIR" "$V20_TRACKER_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
dispatch_dir = Path(sys.argv[2])
v19_bundle_dir = Path(sys.argv[3])
v20_tracker_dir = Path(sys.argv[4])
summary_csv = Path(sys.argv[5])
decision_csv = Path(sys.argv[6])
dispatch_dir.mkdir(parents=True, exist_ok=True)

def ensure(path):
    path.mkdir(parents=True, exist_ok=True)
    return path

for folder in ["dispatch", "source_manifests", "return_templates", "verification"]:
    ensure(dispatch_dir / folder)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def copy(src, rel):
    dst = dispatch_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst

def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

def bool_int(value):
    return int(str(value).strip().lower() in {"1", "true", "yes", "ready", "pass"})

v19_manifest = read_json(v19_bundle_dir / "submission_manifest.json")
v20_manifest = read_json(v20_tracker_dir / "return_tracker_manifest.json")
requirements = read_csv(v20_tracker_dir / "return_requirement_rows.csv")
blockers = read_csv(v20_tracker_dir / "blocker_rows.csv")
next_actions = read_csv(v20_tracker_dir / "next_action_rows.csv")

copy(v19_bundle_dir / "submission_manifest.json", "source_manifests/v19_submission_manifest.json")
copy(v19_bundle_dir / "track_rows.csv", "source_manifests/v19_track_rows.csv")
copy(v20_tracker_dir / "return_tracker_manifest.json", "source_manifests/v20_return_tracker_manifest.json")
copy(v20_tracker_dir / "return_requirement_rows.csv", "source_manifests/v20_return_requirement_rows.csv")
copy(v20_tracker_dir / "blocker_rows.csv", "source_manifests/v20_blocker_rows.csv")
copy(v20_tracker_dir / "next_action_rows.csv", "source_manifests/v20_next_action_rows.csv")
copy(v19_bundle_dir / "third_party_submission" / "REQUIRED_RETURN_FILES.csv", "return_templates/third_party_required_return_files.csv")
copy(v19_bundle_dir / "official_benchmark_submission" / "OFFICIAL_SLICE_REQUIREMENTS.csv", "return_templates/official_benchmark_required_return_files.csv")
copy(v19_bundle_dir / "commercial_poc_submission" / "POC_ACCEPTANCE_CRITERIA.csv", "return_templates/commercial_poc_acceptance_criteria.csv")
copy(v19_bundle_dir / "commercial_poc_submission" / "DOMAIN_INTAKE_TEMPLATE.csv", "return_templates/commercial_poc_domain_intake_template.csv")

with (dispatch_dir / "dispatch" / "REVIEWER_PACKET_INDEX.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["packet", "audience", "purpose", "primary_return_env", "target_flag"])
    writer.writerows(
        [
            ("THIRD_PARTY_RERUN_REQUEST.md", "external reviewer / clean-machine operator", "rerun exact package and return command/hash/metric/reviewer evidence", "V20_THIRD_PARTY_RERUN_DIR", "independent_rerun_actual_ready"),
            ("OFFICIAL_BENCHMARK_REQUEST.md", "official benchmark runner / reconciliation reviewer", "run official-source slice with official evaluator and return predictions/metrics/provenance", "V20_OFFICIAL_BENCHMARK_DIR", "candidate_external_benchmark_result_ready"),
            ("COMMERCIAL_POC_REQUEST.md", "domain owner / commercial PoC reviewer", "run closed-corpus local evidence-bound QA/audit PoC", "V20_COMMERCIAL_POC_DIR", "closed_corpus_poc_actual_ready"),
        ]
    )

(dispatch_dir / "dispatch" / "README_FOR_EXTERNAL_REVIEWERS.md").write_text(
    "\n".join(
        [
            "# External Review Dispatch Kit",
            "",
            "This dispatch kit is the handoff packet for the next research boundary. It is designed to be read and acted on by a non-local reviewer, benchmark runner, or domain PoC owner.",
            "",
            "It does not claim that external validation is complete. Its purpose is to make the missing external evidence concrete, portable, and verifiable.",
            "",
            "Current target flags:",
            "- `independent_rerun_actual_ready=1` after a third-party clean-machine rerun.",
            "- `candidate_external_benchmark_result_ready=1` after an official RULER/LongBench-style slice with official source/evaluator evidence.",
            "- `closed_corpus_poc_actual_ready=1` after a closed-corpus local evidence-bound QA/audit PoC.",
            "",
            "Recommended commercial first domain: codebase QA. It is the tightest audit surface for wrong-answer guard, citation accuracy, abstain behavior, query-to-evidence latency, resource envelope, and audit trail.",
            "",
            "Return directories should be verified with `verification/VERIFY_RETURN_COMMANDS.sh` or the equivalent `experiments/run_v20_external_return_tracker.sh` command.",
            "",
        ]
    ),
    encoding="utf-8",
)

(dispatch_dir / "dispatch" / "THIRD_PARTY_RERUN_REQUEST.md").write_text(
    "\n".join(
        [
            "# Third-Party Rerun Request",
            "",
            "Target: `independent_rerun_actual_ready=1`.",
            "",
            "Please run the exact reproduction path on a clean machine or another non-local environment controlled by an independent reviewer.",
            "",
            "Required return evidence:",
            "- reviewer identity and conflict disclosure",
            "- clean-machine or independent environment manifest",
            "- identical command and exit code",
            "- frozen query/source snapshot verification",
            "- metric delta tolerance rows",
            "- stdout/stderr files plus sha256 hashes",
            "- rerun manifest and review rows",
            "",
            "Validation command after return:",
            "",
            "```bash",
            "V20_THIRD_PARTY_RERUN_DIR=/path/to/third_party_return experiments/run_v20_external_return_tracker.sh",
            "```",
            "",
        ]
    ),
    encoding="utf-8",
)

(dispatch_dir / "dispatch" / "OFFICIAL_BENCHMARK_REQUEST.md").write_text(
    "\n".join(
        [
            "# Official Benchmark Reconciliation Request",
            "",
            "Target: `candidate_external_benchmark_result_ready=1`.",
            "",
            "Please run or reconcile an official-source benchmark slice. A small RULER NIAH or LongBench v2 official slice is acceptable if it preserves the official source snapshot and official evaluator/container.",
            "",
            "Required return evidence:",
            "- official source snapshot",
            "- official evaluator/container status",
            "- no oracle prediction path",
            "- no raw-input extractor prediction path",
            "- RouteMemory-derived prediction lineage",
            "- raw predictions",
            "- metrics",
            "- provenance",
            "- reproducibility package",
            "",
            "Validation command after return:",
            "",
            "```bash",
            "V20_OFFICIAL_BENCHMARK_DIR=/path/to/official_return experiments/run_v20_external_return_tracker.sh",
            "```",
            "",
        ]
    ),
    encoding="utf-8",
)

(dispatch_dir / "dispatch" / "COMMERCIAL_POC_REQUEST.md").write_text(
    "\n".join(
        [
            "# Commercial Local QA/Audit PoC Request",
            "",
            "Target: `closed_corpus_poc_actual_ready=1`.",
            "",
            "Positioning: local evidence-bound QA/audit system, not an LLM replacement.",
            "",
            "Recommended domain order:",
            "1. Codebase QA.",
            "2. Internal document QA.",
            "3. Product manual QA.",
            "4. Log or incident root-cause evidence QA.",
            "",
            "Required acceptance dimensions:",
            "- wrong-answer guard",
            "- citation accuracy",
            "- abstain behavior",
            "- query-to-evidence latency",
            "- resource envelope",
            "- audit trail",
            "- privacy review",
            "",
            "Validation command after return:",
            "",
            "```bash",
            "V20_COMMERCIAL_POC_DIR=/path/to/commercial_return experiments/run_v20_external_return_tracker.sh",
            "```",
            "",
        ]
    ),
    encoding="utf-8",
)

(dispatch_dir / "dispatch" / "RETURN_DIRECTORY_LAYOUT.md").write_text(
    "\n".join(
        [
            "# Return Directory Layout",
            "",
            "The v20 tracker accepts one directory per track. Each directory must contain exactly the required files for that track.",
            "",
            "Third-party rerun:",
            "- `reviewer_identity.json`",
            "- `rerun_environment.json`",
            "- `rerun_commands.csv`",
            "- `rerun_manifest.json`",
            "- `metric_delta_rows.csv`",
            "- `review_rows.csv`",
            "- `stdout.txt`",
            "- `stderr.txt`",
            "",
            "Official benchmark:",
            "- `official_source_snapshot.json`",
            "- `official_evaluator_status.json`",
            "- `raw_predictions.jsonl`",
            "- `prediction_lineage.jsonl`",
            "- `metrics.json`",
            "- `provenance_manifest.json`",
            "- `reproducibility_package_manifest.json`",
            "- `candidate_result_rows.csv`",
            "",
            "Commercial PoC:",
            "- `domain_manifest.json`",
            "- `corpus_manifest.json`",
            "- `query_set.csv`",
            "- `poc_result_rows.csv`",
            "- `audit_trail.csv`",
            "- `resource_envelope.json`",
            "- `privacy_review.json`",
            "- `acceptance_review.csv`",
            "",
        ]
    ),
    encoding="utf-8",
)

verify_script = dispatch_dir / "verification" / "VERIFY_RETURN_COMMANDS.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"',
            'cd "$ROOT_DIR"',
            ': "${V20_THIRD_PARTY_RERUN_DIR:=}"',
            ': "${V20_OFFICIAL_BENCHMARK_DIR:=}"',
            ': "${V20_COMMERCIAL_POC_DIR:=}"',
            "experiments/run_v20_external_return_tracker.sh",
            "cat results/v20_external_return_tracker_summary.csv",
            "cat results/v20_external_return_tracker/tracker_001/blocker_rows.csv",
            "",
        ]
    ),
    encoding="utf-8",
)
verify_script.chmod(0o755)

with (dispatch_dir / "dispatch" / "TRACKER_SUMMARY.md").open("w", encoding="utf-8") as handle:
    handle.write("# Current Tracker Summary\n\n")
    handle.write("The v20 tracker currently reports:\n\n")
    handle.write(f"- tracker_ready={v20_manifest.get('tracker_ready')}\n")
    handle.write(f"- external_return_dirs_supplied={v20_manifest.get('external_return_dirs_supplied')}\n")
    handle.write(f"- return_requirement_rows={v20_manifest.get('return_requirement_rows')}\n")
    handle.write(f"- blocker_rows={v20_manifest.get('blocker_rows')}\n")
    handle.write(f"- independent_rerun_actual_ready={v20_manifest.get('independent_rerun_actual_ready')}\n")
    handle.write(f"- candidate_external_benchmark_result_ready={v20_manifest.get('candidate_external_benchmark_result_ready')}\n")
    handle.write(f"- closed_corpus_poc_actual_ready={v20_manifest.get('closed_corpus_poc_actual_ready')}\n")
    handle.write(f"- real_external_benchmark_verified={v20_manifest.get('real_external_benchmark_verified')}\n")
    handle.write(f"- real_release_package_ready={v20_manifest.get('real_release_package_ready')}\n\n")
    handle.write("Open blockers:\n\n")
    for row in blockers:
        handle.write(f"- {row['track']}: {row['blocker']} ({row['detail']})\n")
    handle.write("\nNext actions:\n\n")
    for row in next_actions:
        handle.write(f"- {row['priority']}. {row['track']}: {row['recommended_next_action']}\n")

dispatch_packet_ready = 1
manifest = {
    "manifest_scope": "v21-external-review-dispatch-kit",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v19_submission_manifest_sha256": sha256(v19_bundle_dir / "submission_manifest.json"),
    "v20_return_tracker_manifest_sha256": sha256(v20_tracker_dir / "return_tracker_manifest.json"),
    "dispatch_packet_ready": dispatch_packet_ready,
    "reviewer_packet_index_ready": 1,
    "return_layout_ready": 1,
    "verify_return_commands_ready": 1,
    "return_requirement_rows": len(requirements),
    "blocker_rows": len(blockers),
    "independent_rerun_actual_ready": bool_int(v20_manifest.get("independent_rerun_actual_ready", 0)),
    "candidate_external_benchmark_result_ready": bool_int(v20_manifest.get("candidate_external_benchmark_result_ready", 0)),
    "closed_corpus_poc_actual_ready": bool_int(v20_manifest.get("closed_corpus_poc_actual_ready", 0)),
    "real_external_benchmark_verified": bool_int(v20_manifest.get("real_external_benchmark_verified", 0)),
    "real_release_package_ready": bool_int(v20_manifest.get("real_release_package_ready", 0)),
    "claim": "external reviewer dispatch kit ready; actual readiness still requires returned non-fixture evidence",
}
(dispatch_dir / "dispatch_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "dispatch/README_FOR_EXTERNAL_REVIEWERS.md",
    "dispatch/REVIEWER_PACKET_INDEX.csv",
    "dispatch/THIRD_PARTY_RERUN_REQUEST.md",
    "dispatch/OFFICIAL_BENCHMARK_REQUEST.md",
    "dispatch/COMMERCIAL_POC_REQUEST.md",
    "dispatch/RETURN_DIRECTORY_LAYOUT.md",
    "dispatch/TRACKER_SUMMARY.md",
    "source_manifests/v19_submission_manifest.json",
    "source_manifests/v19_track_rows.csv",
    "source_manifests/v20_return_tracker_manifest.json",
    "source_manifests/v20_return_requirement_rows.csv",
    "source_manifests/v20_blocker_rows.csv",
    "source_manifests/v20_next_action_rows.csv",
    "return_templates/third_party_required_return_files.csv",
    "return_templates/official_benchmark_required_return_files.csv",
    "return_templates/commercial_poc_acceptance_criteria.csv",
    "return_templates/commercial_poc_domain_intake_template.csv",
    "verification/VERIFY_RETURN_COMMANDS.sh",
    "dispatch_manifest.json",
]
artifact_rows = []
for rel in artifact_rels:
    path = dispatch_dir / rel
    artifact_rows.append({"artifact": Path(rel).stem, "path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
with (dispatch_dir / "artifact_manifest.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["artifact", "path", "sha256", "bytes"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(artifact_rows)

summary_rows = [
    {
        "dispatch_id": dispatch_dir.name,
        "dispatch_packet_ready": dispatch_packet_ready,
        "reviewer_packet_index_ready": 1,
        "return_layout_ready": 1,
        "verify_return_commands_ready": 1,
        "return_requirement_rows": len(requirements),
        "blocker_rows": len(blockers),
        "independent_rerun_actual_ready": bool_int(v20_manifest.get("independent_rerun_actual_ready", 0)),
        "candidate_external_benchmark_result_ready": bool_int(v20_manifest.get("candidate_external_benchmark_result_ready", 0)),
        "closed_corpus_poc_actual_ready": bool_int(v20_manifest.get("closed_corpus_poc_actual_ready", 0)),
        "real_external_benchmark_verified": bool_int(v20_manifest.get("real_external_benchmark_verified", 0)),
        "real_release_package_ready": bool_int(v20_manifest.get("real_release_package_ready", 0)),
        "artifact_rows": len(artifact_rows),
    }
]
with summary_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(summary_rows[0]), lineterminator="\n")
    writer.writeheader()
    writer.writerows(summary_rows)

decision_rows = [
    ("external-review-dispatch-kit", "pass", "reviewer-facing requests, return layout, and verification commands are packaged"),
    ("third-party-rerun-actual", "blocked", "requires returned clean-machine reviewer evidence"),
    ("candidate-external-benchmark-result", "blocked", "requires returned official benchmark reconciliation evidence"),
    ("closed-corpus-poc-actual", "blocked", "requires returned commercial closed-corpus PoC evidence"),
    ("real-release-package", "blocked", "dispatch kit is not release evidence"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "v21_external_review_dispatch_kit_dir: $DISPATCH_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
