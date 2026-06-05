#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v18_external_evidence_intake"
INTAKE_ID="${V18_INTAKE_ID:-intake_001}"
INTAKE_DIR="${V18_INTAKE_DIR:-$RESULTS_DIR/${PREFIX}/$INTAKE_ID}"
V17_PACKAGE_DIR="${V17_PACKAGE_DIR:-$RESULTS_DIR/v17_post_v16_externalization_handoff/package_001}"
THIRD_PARTY_DIR="${V18_THIRD_PARTY_RERUN_DIR:-}"
OFFICIAL_BENCHMARK_DIR="${V18_OFFICIAL_BENCHMARK_DIR:-}"
COMMERCIAL_POC_DIR="${V18_COMMERCIAL_POC_DIR:-}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

mkdir -p "$INTAKE_DIR"

"$ROOT_DIR/experiments/run_v17_post_v16_externalization_handoff.sh" >/dev/null

python3 - "$ROOT_DIR" "$INTAKE_DIR" "$V17_PACKAGE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$THIRD_PARTY_DIR" "$OFFICIAL_BENCHMARK_DIR" "$COMMERCIAL_POC_DIR" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
intake_dir = Path(sys.argv[2])
v17_package_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
third_party_arg = sys.argv[6]
official_arg = sys.argv[7]
commercial_arg = sys.argv[8]
intake_dir.mkdir(parents=True, exist_ok=True)

def ensure(path):
    path.mkdir(parents=True, exist_ok=True)
    return path

for folder in ["third_party_rerun", "official_benchmark", "commercial_poc", "evidence_copies"]:
    ensure(intake_dir / folder)

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

def boolish(value):
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, (int, float)):
        return int(value != 0)
    return int(str(value).strip().lower() in {"1", "true", "yes", "ready", "pass"})

def copy_if_exists(src, rel):
    if not src.is_file():
        return None
    dst = intake_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst

baseline_manifest = v17_package_dir / "handoff_manifest.json"
baseline_hash = sha256(baseline_manifest)

def verify_third_party(path_text):
    result = {
        "supplied": 0,
        "ready": 0,
        "reason": "no third-party rerun directory supplied",
        "artifact_rows": 0,
        "metric_delta_rows": 0,
        "metric_delta_pass_rows": 0,
        "external_independent_reviewer": 0,
        "clean_environment": 0,
        "rerun_exit_code": "",
    }
    if not path_text:
        return result
    path = Path(path_text)
    result["supplied"] = int(path.is_dir())
    if not path.is_dir():
        result["reason"] = "third-party rerun directory missing"
        return result
    required = [
        "reviewer_identity.json",
        "rerun_environment.json",
        "rerun_commands.csv",
        "rerun_manifest.json",
        "metric_delta_rows.csv",
        "review_rows.csv",
        "stdout.txt",
        "stderr.txt",
    ]
    missing = [rel for rel in required if not (path / rel).is_file()]
    for rel in required:
        copy_if_exists(path / rel, f"evidence_copies/third_party_rerun/{rel}")
    returned_package_manifest = path / "v15a_package_manifest.json"
    if returned_package_manifest.is_file():
        copy_if_exists(returned_package_manifest, "evidence_copies/third_party_rerun/v15a_package_manifest.json")
    if missing:
        result["reason"] = "missing: " + "|".join(missing)
        return result
    identity = read_json(path / "reviewer_identity.json")
    environment = read_json(path / "rerun_environment.json")
    manifest = read_json(path / "rerun_manifest.json")
    commands = read_csv(path / "rerun_commands.csv")
    metric_rows = read_csv(path / "metric_delta_rows.csv")
    review_rows = read_csv(path / "review_rows.csv")
    stdout_hash_ok = any(row.get("stdout_sha256") == sha256(path / "stdout.txt") for row in commands)
    stderr_hash_ok = any(row.get("stderr_sha256") == sha256(path / "stderr.txt") for row in commands)
    exit_zero = all(str(row.get("exit_code", "")) == "0" for row in commands) and bool(commands)
    metric_pass = metric_rows and all(boolish(row.get("delta_within_tolerance", 0)) == 1 for row in metric_rows)
    review_pass = review_rows and all(row.get("status") == "pass" for row in review_rows)
    expected_package_sha = manifest.get("v15a_package_manifest_sha256", "")
    local_package_manifest = root / "results" / "v15a_independent_reproduction_package" / "package_001" / "package_manifest.json"
    local_package_hash_ok = local_package_manifest.is_file() and expected_package_sha == sha256(local_package_manifest)
    returned_package_hash_ok = returned_package_manifest.is_file() and expected_package_sha == sha256(returned_package_manifest)
    package_hash_ok = local_package_hash_ok or returned_package_hash_ok
    frozen_ok = boolish(manifest.get("frozen_queries_verified", 0)) == 1
    source_ok = boolish(manifest.get("source_snapshot_verified", 0)) == 1
    external_reviewer = boolish(identity.get("external_independent_reviewer", 0))
    clean_env = boolish(environment.get("external_independent_environment", 0)) or boolish(environment.get("clean_machine", 0))
    ready = int(all([stdout_hash_ok, stderr_hash_ok, exit_zero, metric_pass, review_pass, package_hash_ok, frozen_ok, source_ok, external_reviewer, clean_env]))
    result.update(
        {
            "ready": ready,
            "reason": "ready" if ready else "third-party rerun evidence incomplete or local-only",
            "artifact_rows": len(required),
            "metric_delta_rows": len(metric_rows),
            "metric_delta_pass_rows": sum(1 for row in metric_rows if boolish(row.get("delta_within_tolerance", 0)) == 1),
            "external_independent_reviewer": external_reviewer,
            "clean_environment": clean_env,
            "rerun_exit_code": "0" if exit_zero else "nonzero-or-missing",
        }
    )
    return result

def verify_official(path_text):
    result = {
        "supplied": 0,
        "ready": 0,
        "reason": "no official benchmark directory supplied",
        "artifact_rows": 0,
        "candidate_rows": 0,
        "official_evaluator_ready": 0,
        "route_memory_lineage_ready": 0,
    }
    if not path_text:
        return result
    path = Path(path_text)
    result["supplied"] = int(path.is_dir())
    if not path.is_dir():
        result["reason"] = "official benchmark directory missing"
        return result
    required = [
        "official_source_snapshot.json",
        "official_evaluator_status.json",
        "raw_predictions.jsonl",
        "prediction_lineage.jsonl",
        "metrics.json",
        "provenance_manifest.json",
        "reproducibility_package_manifest.json",
        "candidate_result_rows.csv",
    ]
    missing = [rel for rel in required if not (path / rel).is_file()]
    for rel in required:
        copy_if_exists(path / rel, f"evidence_copies/official_benchmark/{rel}")
    if missing:
        result["reason"] = "missing: " + "|".join(missing)
        return result
    source = read_json(path / "official_source_snapshot.json")
    evaluator = read_json(path / "official_evaluator_status.json")
    metrics = read_json(path / "metrics.json")
    provenance = read_json(path / "provenance_manifest.json")
    repro = read_json(path / "reproducibility_package_manifest.json")
    candidate_rows = read_csv(path / "candidate_result_rows.csv")
    official_source_ready = boolish(source.get("official_source_snapshot_ready", 0))
    evaluator_ready = boolish(evaluator.get("official_evaluator_ready", 0))
    no_oracle = boolish(provenance.get("oracle_prediction_used", 1)) == 0 and boolish(metrics.get("oracle_prediction_used", 1)) == 0
    no_extractor = boolish(provenance.get("raw_input_extractor_used", 1)) == 0 and boolish(metrics.get("raw_input_extractor_used", 1)) == 0
    lineage_ready = boolish(provenance.get("route_memory_prediction_lineage_ready", 0))
    raw_ready = boolish(metrics.get("raw_predictions_ready", 0))
    metrics_ready = boolish(metrics.get("metrics_ready", 0))
    repro_ready = boolish(repro.get("reproducibility_package_ready", 0))
    candidate_rows_ready = candidate_rows and all(row.get("candidate_external_benchmark_result_ready") == "1" for row in candidate_rows)
    ready = int(all([official_source_ready, evaluator_ready, no_oracle, no_extractor, lineage_ready, raw_ready, metrics_ready, repro_ready, candidate_rows_ready]))
    result.update(
        {
            "ready": ready,
            "reason": "ready" if ready else "official benchmark reconciliation incomplete",
            "artifact_rows": len(required),
            "candidate_rows": len(candidate_rows),
            "official_evaluator_ready": evaluator_ready,
            "route_memory_lineage_ready": lineage_ready,
        }
    )
    return result

def verify_commercial(path_text):
    result = {
        "supplied": 0,
        "ready": 0,
        "reason": "no commercial PoC directory supplied",
        "artifact_rows": 0,
        "acceptance_rows": 0,
        "privacy_review_ready": 0,
        "wrong_answer_guard_ready": 0,
    }
    if not path_text:
        return result
    path = Path(path_text)
    result["supplied"] = int(path.is_dir())
    if not path.is_dir():
        result["reason"] = "commercial PoC directory missing"
        return result
    required = [
        "domain_manifest.json",
        "corpus_manifest.json",
        "query_set.csv",
        "poc_result_rows.csv",
        "audit_trail.csv",
        "resource_envelope.json",
        "privacy_review.json",
        "acceptance_review.csv",
    ]
    missing = [rel for rel in required if not (path / rel).is_file()]
    for rel in required:
        copy_if_exists(path / rel, f"evidence_copies/commercial_poc/{rel}")
    if missing:
        result["reason"] = "missing: " + "|".join(missing)
        return result
    domain = read_json(path / "domain_manifest.json")
    corpus = read_json(path / "corpus_manifest.json")
    resource = read_json(path / "resource_envelope.json")
    privacy = read_json(path / "privacy_review.json")
    results = read_csv(path / "poc_result_rows.csv")
    audit = read_csv(path / "audit_trail.csv")
    acceptance = read_csv(path / "acceptance_review.csv")
    supported_domain = domain.get("domain") in {"codebase_qa", "internal_docs", "product_manual", "incident_logs"}
    corpus_ready = boolish(corpus.get("closed_corpus_ready", 0))
    privacy_ready = boolish(privacy.get("privacy_review_ready", 0))
    resource_ready = boolish(resource.get("resource_envelope_ready", 0))
    wrong_guard = results and all(boolish(row.get("wrong_answer_guard_pass", 0)) == 1 for row in results)
    citations = results and all(boolish(row.get("citation_accuracy_pass", 0)) == 1 for row in results)
    abstain = results and all(boolish(row.get("abstain_behavior_pass", 0)) == 1 for row in results)
    latency = results and all(boolish(row.get("query_to_evidence_latency_ready", 0)) == 1 for row in results)
    audit_ready = bool(audit) and len(audit) >= len(results)
    acceptance_ready = acceptance and all(row.get("status") == "pass" for row in acceptance)
    ready = int(all([supported_domain, corpus_ready, privacy_ready, resource_ready, wrong_guard, citations, abstain, latency, audit_ready, acceptance_ready]))
    result.update(
        {
            "ready": ready,
            "reason": "ready" if ready else "commercial closed-corpus PoC evidence incomplete",
            "artifact_rows": len(required),
            "acceptance_rows": len(acceptance),
            "privacy_review_ready": privacy_ready,
            "wrong_answer_guard_ready": int(bool(wrong_guard)),
        }
    )
    return result

third_party = verify_third_party(third_party_arg)
official = verify_official(official_arg)
commercial = verify_commercial(commercial_arg)

independent_rerun_actual_ready = third_party["ready"]
candidate_external_benchmark_result_ready = official["ready"]
closed_corpus_poc_actual_ready = commercial["ready"]
real_external_benchmark_verified = int(independent_rerun_actual_ready and candidate_external_benchmark_result_ready)
real_release_package_ready = 0

track_rows = [
    {
        "track": "third_party_rerun",
        "supplied": third_party["supplied"],
        "ready": third_party["ready"],
        "reason": third_party["reason"],
        "artifact_rows": third_party["artifact_rows"],
    },
    {
        "track": "official_benchmark_reconciliation",
        "supplied": official["supplied"],
        "ready": official["ready"],
        "reason": official["reason"],
        "artifact_rows": official["artifact_rows"],
    },
    {
        "track": "commercial_local_poc",
        "supplied": commercial["supplied"],
        "ready": commercial["ready"],
        "reason": commercial["reason"],
        "artifact_rows": commercial["artifact_rows"],
    },
]
with (intake_dir / "track_intake_rows.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["track", "supplied", "ready", "reason", "artifact_rows"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(track_rows)

manifest = {
    "manifest_scope": "v18-external-evidence-intake",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v17_handoff_manifest_sha256": baseline_hash,
    "third_party_rerun": third_party,
    "official_benchmark_reconciliation": official,
    "commercial_local_poc": commercial,
    "independent_rerun_actual_ready": independent_rerun_actual_ready,
    "candidate_external_benchmark_result_ready": candidate_external_benchmark_result_ready,
    "closed_corpus_poc_actual_ready": closed_corpus_poc_actual_ready,
    "real_external_benchmark_verified": real_external_benchmark_verified,
    "real_release_package_ready": real_release_package_ready,
    "claim": "external evidence intake verifier; ready flags require supplied external artifacts",
}
(intake_dir / "intake_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = ["track_intake_rows.csv", "intake_manifest.json"]
artifact_rels.extend(str(path.relative_to(intake_dir)) for path in sorted((intake_dir / "evidence_copies").rglob("*")) if path.is_file())
artifact_rows = []
for rel in artifact_rels:
    path = intake_dir / rel
    artifact_rows.append({"artifact": Path(rel).stem, "path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
with (intake_dir / "artifact_manifest.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["artifact", "path", "sha256", "bytes"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(artifact_rows)

summary_rows = [
    {
        "intake_id": intake_dir.name,
        "third_party_rerun_supplied": third_party["supplied"],
        "independent_rerun_actual_ready": independent_rerun_actual_ready,
        "official_benchmark_supplied": official["supplied"],
        "candidate_external_benchmark_result_ready": candidate_external_benchmark_result_ready,
        "commercial_poc_supplied": commercial["supplied"],
        "closed_corpus_poc_actual_ready": closed_corpus_poc_actual_ready,
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
    ("third-party-rerun-intake", "pass" if third_party["supplied"] else "blocked", third_party["reason"]),
    ("independent-rerun-actual", "pass" if independent_rerun_actual_ready else "blocked", third_party["reason"]),
    ("official-benchmark-intake", "pass" if official["supplied"] else "blocked", official["reason"]),
    ("candidate-external-benchmark-result", "pass" if candidate_external_benchmark_result_ready else "blocked", official["reason"]),
    ("commercial-poc-intake", "pass" if commercial["supplied"] else "blocked", commercial["reason"]),
    ("closed-corpus-poc-actual", "pass" if closed_corpus_poc_actual_ready else "blocked", commercial["reason"]),
    ("real-external-benchmark", "pass" if real_external_benchmark_verified else "blocked", "requires independent rerun actual plus official benchmark candidate"),
    ("real-release-package", "blocked", "release requires external benchmark, commercial PoC, privacy/reliability, and release review"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "v18_intake_dir: $INTAKE_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
