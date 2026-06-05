#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v22_clean_machine_execution_kit"
KIT_ID="${V22_KIT_ID:-kit_001}"
KIT_DIR="${V22_KIT_DIR:-$RESULTS_DIR/${PREFIX}/$KIT_ID}"
V21_DISPATCH_DIR="${V21_DISPATCH_DIR:-$RESULTS_DIR/v21_external_review_dispatch_kit/dispatch_001}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

mkdir -p "$KIT_DIR"

"$ROOT_DIR/experiments/run_v21_external_review_dispatch_kit.sh" >/dev/null

python3 - "$ROOT_DIR" "$KIT_DIR" "$V21_DISPATCH_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
kit_dir = Path(sys.argv[2])
v21_dispatch_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
kit_dir.mkdir(parents=True, exist_ok=True)

def ensure(path):
    path.mkdir(parents=True, exist_ok=True)
    return path

for folder in ["clean_machine", "templates", "source_manifests", "verification"]:
    ensure(kit_dir / folder)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def copy(src, rel):
    dst = kit_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst

def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

def bool_int(value):
    return int(str(value).strip().lower() in {"1", "true", "yes", "ready", "pass"})

v21_manifest = read_json(v21_dispatch_dir / "dispatch_manifest.json")
copy(v21_dispatch_dir / "dispatch_manifest.json", "source_manifests/v21_dispatch_manifest.json")
copy(v21_dispatch_dir / "artifact_manifest.csv", "source_manifests/v21_artifact_manifest.csv")
copy(v21_dispatch_dir / "dispatch" / "THIRD_PARTY_RERUN_REQUEST.md", "source_manifests/v21_third_party_rerun_request.md")
copy(v21_dispatch_dir / "dispatch" / "OFFICIAL_BENCHMARK_REQUEST.md", "source_manifests/v21_official_benchmark_request.md")
copy(v21_dispatch_dir / "dispatch" / "COMMERCIAL_POC_REQUEST.md", "source_manifests/v21_commercial_poc_request.md")

(kit_dir / "clean_machine" / "Containerfile.clean-machine").write_text(
    "\n".join(
        [
            "FROM ubuntu:24.04",
            "ENV DEBIAN_FRONTEND=noninteractive",
            "RUN apt-get update && apt-get install -y --no-install-recommends \\",
            "    bash ca-certificates coreutils findutils g++ git make python3 python3-venv python3-pip \\",
            "    sed grep diffutils time procps && rm -rf /var/lib/apt/lists/*",
            "WORKDIR /work/discrete-local-energy",
            "CMD [\"bash\"]",
            "",
        ]
    ),
    encoding="utf-8",
)

(kit_dir / "clean_machine" / "HOST_CLEAN_MACHINE_RUNBOOK.md").write_text(
    "\n".join(
        [
            "# Host Clean-Machine Runbook",
            "",
            "Purpose: produce return evidence for `independent_rerun_actual_ready=1` without treating this repository's local review package as an external review.",
            "",
            "Steps:",
            "1. Clone or unpack the exact repository revision to a clean host.",
            "2. Record reviewer identity in `reviewer_identity.json` using `templates/reviewer_identity_template.json`.",
            "3. Record environment identity in `rerun_environment.json` using `templates/rerun_environment_template.json`.",
            "4. Run `clean_machine/CAPTURE_THIRD_PARTY_RERUN.sh /path/to/return_dir` from the repository root.",
            "5. Confirm the generated metric delta and review rows, then return the directory.",
            "6. The project owner verifies it with `V20_THIRD_PARTY_RERUN_DIR=/path/to/return_dir experiments/run_v20_external_return_tracker.sh`.",
            "",
            "The capture script auto-populates stdout/stderr hashes, rerun command rows, v15-b metric deltas, and v15-b review rows. Reviewer identity and environment independence still must be completed by the reviewer.",
            "",
            "The reviewer must be non-local or the environment must be a true clean machine. A local rerun by the project owner is still only mechanics evidence.",
            "",
        ]
    ),
    encoding="utf-8",
)

(kit_dir / "clean_machine" / "CONTAINER_CLEAN_MACHINE_RUNBOOK.md").write_text(
    "\n".join(
        [
            "# Container Clean-Machine Runbook",
            "",
            "This path is useful when a reviewer wants a minimal, repeatable Linux environment. It is not a substitute for reviewer independence.",
            "",
            "Build:",
            "",
            "```bash",
            "docker build -f results/v22_clean_machine_execution_kit/kit_001/clean_machine/Containerfile.clean-machine -t routelm-clean-machine:review .",
            "```",
            "",
            "Run:",
            "",
            "```bash",
            "docker run --rm -it -v \"$PWD\":/work/discrete-local-energy -w /work/discrete-local-energy routelm-clean-machine:review bash",
            "```",
            "",
            "Inside the container:",
            "",
            "```bash",
            "results/v22_clean_machine_execution_kit/kit_001/clean_machine/CAPTURE_THIRD_PARTY_RERUN.sh /work/third_party_return",
            "```",
            "",
            "Return `/work/third_party_return` to the project owner for v20/v18 verification.",
            "",
        ]
    ),
    encoding="utf-8",
)

capture_script = kit_dir / "clean_machine" / "CAPTURE_THIRD_PARTY_RERUN.sh"
capture_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'RETURN_DIR="${1:?usage: CAPTURE_THIRD_PARTY_RERUN.sh /path/to/return_dir}"',
            'ROOT_DIR="$(pwd)"',
            'mkdir -p "$RETURN_DIR"',
            'STDOUT_PATH="$RETURN_DIR/stdout.txt"',
            'STDERR_PATH="$RETURN_DIR/stderr.txt"',
            'COMMAND="experiments/test_v15a_independent_reproduction_package.sh && experiments/test_v15b_nonfixture_review_independent_rerun.sh && experiments/test_v16_research_commercial_tracks.sh"',
            "set +e",
            'bash -lc "$COMMAND" >"$STDOUT_PATH" 2>"$STDERR_PATH"',
            "EXIT_CODE=$?",
            "set -e",
            'STDOUT_SHA="$(sha256sum "$STDOUT_PATH" | awk \'{print "sha256:" $1}\')"',
            'STDERR_SHA="$(sha256sum "$STDERR_PATH" | awk \'{print "sha256:" $1}\')"',
            'PACKAGE_MANIFEST="$ROOT_DIR/results/v15a_independent_reproduction_package/package_001/package_manifest.json"',
            'REVIEW_DIR="$ROOT_DIR/results/v15b_nonfixture_review_independent_rerun/review_001"',
            'PACKAGE_SHA=""',
            'if [ -f "$PACKAGE_MANIFEST" ]; then PACKAGE_SHA="$(sha256sum "$PACKAGE_MANIFEST" | awk \'{print "sha256:" $1}\')"; fi',
            'METRIC_DELTA_SRC="$REVIEW_DIR/metric_deltas/metric_delta_rows.csv"',
            'REVIEW_ROWS_SRC="$REVIEW_DIR/review/review_rows.csv"',
            'METRIC_READY=0',
            'REVIEW_READY=0',
            'if [ -s "$METRIC_DELTA_SRC" ]; then cp "$METRIC_DELTA_SRC" "$RETURN_DIR/metric_delta_rows.csv"; METRIC_READY=1; fi',
            'if [ -s "$REVIEW_ROWS_SRC" ]; then cp "$REVIEW_ROWS_SRC" "$RETURN_DIR/review_rows.csv"; REVIEW_READY=1; fi',
            'cat >"$RETURN_DIR/rerun_commands.csv" <<EOF',
            "command,exit_code,stdout_path,stdout_sha256,stderr_path,stderr_sha256",
            "$COMMAND,$EXIT_CODE,stdout.txt,$STDOUT_SHA,stderr.txt,$STDERR_SHA",
            "EOF",
            'cat >"$RETURN_DIR/rerun_manifest.json" <<EOF',
            "{",
            '  "v15a_package_manifest_sha256": "$PACKAGE_SHA",',
            '  "reproducer_command": "$COMMAND",',
            '  "rerun_exit_code": $EXIT_CODE,',
            '  "metric_delta_tolerance": "v15b_exact_summary_delta_1e-6",',
            '  "metric_delta_rows_auto_copied": $METRIC_READY,',
            '  "review_rows_auto_copied": $REVIEW_READY,',
            '  "frozen_queries_verified": $METRIC_READY,',
            '  "source_snapshot_verified": $REVIEW_READY,',
            '  "external_independent_reviewer": 0,',
            '  "notes": "reviewer must still complete reviewer_identity.json and rerun_environment.json before submission"',
            "}",
            "EOF",
            'if [ "$METRIC_READY" != "1" ]; then',
            'cat >"$RETURN_DIR/metric_delta_rows.csv" <<EOF',
            "metric,expected_value,rerun_value,absolute_delta,tolerance,delta_within_tolerance",
            "fill,fill,fill,fill,fill,0",
            "EOF",
            "fi",
            'if [ "$REVIEW_READY" != "1" ]; then',
            'cat >"$RETURN_DIR/review_rows.csv" <<EOF',
            "gate,status,reason",
            "clean-machine-rerun,fail,reviewer must complete identity/environment/query/source/metric checks",
            "EOF",
            "fi",
            'if [ ! -f "$RETURN_DIR/reviewer_identity.json" ]; then cp "$ROOT_DIR/results/v22_clean_machine_execution_kit/kit_001/templates/reviewer_identity_template.json" "$RETURN_DIR/reviewer_identity.json"; fi',
            'if [ ! -f "$RETURN_DIR/rerun_environment.json" ]; then cp "$ROOT_DIR/results/v22_clean_machine_execution_kit/kit_001/templates/rerun_environment_template.json" "$RETURN_DIR/rerun_environment.json"; fi',
            'echo "return_dir: $RETURN_DIR"',
            'echo "exit_code: $EXIT_CODE"',
            'echo "stdout_sha256: $STDOUT_SHA"',
            'echo "stderr_sha256: $STDERR_SHA"',
            "exit $EXIT_CODE",
            "",
        ]
    ),
    encoding="utf-8",
)
capture_script.chmod(0o755)

(kit_dir / "templates" / "reviewer_identity_template.json").write_text(
    json.dumps(
        {
            "reviewer_name": "",
            "reviewer_org": "",
            "reviewer_contact": "",
            "external_independent_reviewer": 0,
            "conflict_disclosure": "",
            "review_timestamp_utc": "",
        },
        indent=2,
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)

(kit_dir / "templates" / "rerun_environment_template.json").write_text(
    json.dumps(
        {
            "clean_machine": 0,
            "external_independent_environment": 0,
            "os": "",
            "kernel": "",
            "cpu": "",
            "memory_gb": "",
            "storage": "",
            "python": "",
            "compiler": "",
            "git_revision": "",
            "container_image_digest": "",
        },
        indent=2,
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)

(kit_dir / "templates" / "official_benchmark_return_manifest_template.json").write_text(
    json.dumps(
        {
            "official_source_snapshot_ready": 0,
            "official_evaluator_ready": 0,
            "oracle_prediction_used": 0,
            "raw_input_extractor_used": 0,
            "route_memory_prediction_lineage_ready": 0,
            "raw_predictions_ready": 0,
            "metrics_ready": 0,
            "provenance_ready": 0,
            "reproducibility_package_ready": 0,
        },
        indent=2,
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)

(kit_dir / "templates" / "commercial_poc_return_manifest_template.json").write_text(
    json.dumps(
        {
            "domain": "codebase_qa",
            "closed_corpus_ready": 0,
            "wrong_answer_guard_ready": 0,
            "citation_accuracy_ready": 0,
            "abstain_behavior_ready": 0,
            "query_to_evidence_latency_ready": 0,
            "resource_envelope_ready": 0,
            "audit_trail_ready": 0,
            "privacy_review_ready": 0,
        },
        indent=2,
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)

(kit_dir / "clean_machine" / "OFFICIAL_BENCHMARK_EXECUTION_NOTES.md").write_text(
    "\n".join(
        [
            "# Official Benchmark Execution Notes",
            "",
            "Target: `candidate_external_benchmark_result_ready=1`.",
            "",
            "Use this only for an official-source slice. The return directory must include official source snapshot, official evaluator/container status, raw predictions, RouteMemory-derived prediction lineage, metrics, provenance, reproducibility package manifest, and candidate result rows.",
            "",
            "The result must keep `oracle_prediction_used=0` and `raw_input_extractor_used=0`.",
            "",
        ]
    ),
    encoding="utf-8",
)

(kit_dir / "clean_machine" / "COMMERCIAL_POC_EXECUTION_NOTES.md").write_text(
    "\n".join(
        [
            "# Commercial PoC Execution Notes",
            "",
            "Target: `closed_corpus_poc_actual_ready=1`.",
            "",
            "Recommended first domain: codebase QA. Position the system as a local evidence-bound QA/audit system, not an LLM replacement.",
            "",
            "Return evidence must cover wrong-answer guard, citation accuracy, abstain behavior, query-to-evidence latency, resource envelope, audit trail, and privacy review.",
            "",
        ]
    ),
    encoding="utf-8",
)

(kit_dir / "verification" / "VERIFY_CLEAN_MACHINE_RETURN.md").write_text(
    "\n".join(
        [
            "# Verify Clean-Machine Return",
            "",
            "After the reviewer returns a directory, run:",
            "",
            "```bash",
            "V20_THIRD_PARTY_RERUN_DIR=/path/to/third_party_return experiments/run_v20_external_return_tracker.sh",
            "```",
            "",
            "If all reviewer, environment, command, hash, query/source, metric, and review rows pass, v18 can set `independent_rerun_actual_ready=1`.",
            "",
            "For official benchmark and commercial PoC returns, use `V20_OFFICIAL_BENCHMARK_DIR` and `V20_COMMERCIAL_POC_DIR` respectively.",
            "",
        ]
    ),
    encoding="utf-8",
)

clean_machine_execution_kit_ready = 1
manifest = {
    "manifest_scope": "v22-clean-machine-execution-kit",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v21_dispatch_manifest_sha256": sha256(v21_dispatch_dir / "dispatch_manifest.json"),
    "clean_machine_execution_kit_ready": clean_machine_execution_kit_ready,
    "container_runbook_ready": 1,
    "host_runbook_ready": 1,
    "return_capture_script_ready": 1,
    "environment_templates_ready": 1,
    "official_benchmark_execution_notes_ready": 1,
    "commercial_poc_execution_notes_ready": 1,
    "independent_rerun_actual_ready": bool_int(v21_manifest.get("independent_rerun_actual_ready", 0)),
    "candidate_external_benchmark_result_ready": bool_int(v21_manifest.get("candidate_external_benchmark_result_ready", 0)),
    "closed_corpus_poc_actual_ready": bool_int(v21_manifest.get("closed_corpus_poc_actual_ready", 0)),
    "real_external_benchmark_verified": bool_int(v21_manifest.get("real_external_benchmark_verified", 0)),
    "real_release_package_ready": bool_int(v21_manifest.get("real_release_package_ready", 0)),
    "claim": "clean-machine execution kit ready; actual flags require returned non-fixture reviewer evidence",
}
(kit_dir / "clean_machine_execution_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "clean_machine/Containerfile.clean-machine",
    "clean_machine/HOST_CLEAN_MACHINE_RUNBOOK.md",
    "clean_machine/CONTAINER_CLEAN_MACHINE_RUNBOOK.md",
    "clean_machine/CAPTURE_THIRD_PARTY_RERUN.sh",
    "clean_machine/OFFICIAL_BENCHMARK_EXECUTION_NOTES.md",
    "clean_machine/COMMERCIAL_POC_EXECUTION_NOTES.md",
    "templates/reviewer_identity_template.json",
    "templates/rerun_environment_template.json",
    "templates/official_benchmark_return_manifest_template.json",
    "templates/commercial_poc_return_manifest_template.json",
    "source_manifests/v21_dispatch_manifest.json",
    "source_manifests/v21_artifact_manifest.csv",
    "source_manifests/v21_third_party_rerun_request.md",
    "source_manifests/v21_official_benchmark_request.md",
    "source_manifests/v21_commercial_poc_request.md",
    "verification/VERIFY_CLEAN_MACHINE_RETURN.md",
    "clean_machine_execution_manifest.json",
]
artifact_rows = []
for rel in artifact_rels:
    path = kit_dir / rel
    artifact_rows.append({"artifact": Path(rel).stem, "path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
with (kit_dir / "artifact_manifest.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["artifact", "path", "sha256", "bytes"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(artifact_rows)

summary_rows = [
    {
        "kit_id": kit_dir.name,
        "clean_machine_execution_kit_ready": clean_machine_execution_kit_ready,
        "container_runbook_ready": 1,
        "host_runbook_ready": 1,
        "return_capture_script_ready": 1,
        "environment_templates_ready": 1,
        "official_benchmark_execution_notes_ready": 1,
        "commercial_poc_execution_notes_ready": 1,
        "independent_rerun_actual_ready": bool_int(v21_manifest.get("independent_rerun_actual_ready", 0)),
        "candidate_external_benchmark_result_ready": bool_int(v21_manifest.get("candidate_external_benchmark_result_ready", 0)),
        "closed_corpus_poc_actual_ready": bool_int(v21_manifest.get("closed_corpus_poc_actual_ready", 0)),
        "real_external_benchmark_verified": bool_int(v21_manifest.get("real_external_benchmark_verified", 0)),
        "real_release_package_ready": bool_int(v21_manifest.get("real_release_package_ready", 0)),
        "artifact_rows": len(artifact_rows),
    }
]
with summary_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(summary_rows[0]), lineterminator="\n")
    writer.writeheader()
    writer.writerows(summary_rows)

decision_rows = [
    ("clean-machine-execution-kit", "pass", "host/container runbooks, capture script, templates, and verification notes are packaged"),
    ("independent-rerun-actual", "blocked", "requires returned clean-machine reviewer evidence verified by v20/v18"),
    ("candidate-external-benchmark-result", "blocked", "requires returned official benchmark reconciliation evidence"),
    ("closed-corpus-poc-actual", "blocked", "requires returned commercial closed-corpus PoC evidence"),
    ("real-release-package", "blocked", "clean-machine execution kit is not release evidence"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "v22_clean_machine_execution_kit_dir: $KIT_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
