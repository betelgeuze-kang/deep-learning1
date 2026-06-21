#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61ge_post_gd_v61_partial_generation_intake_slice"
RUN_DIR="$RESULTS_DIR/$PREFIX/slice_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
SLICE_DIR="$RUN_DIR/v61_partial_generation_intake_slice"

V61GE_REUSE_EXISTING="${V61GE_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61ge_post_gd_v61_partial_generation_intake_slice.sh" >/dev/null

"$SLICE_DIR/VERIFY_V61_PARTIAL_GENERATION_INTAKE_SLICE.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$SLICE_DIR" <<'PY'
import csv
import hashlib
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
slice_dir = Path(sys.argv[4])


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
    "v61ge_post_gd_v61_partial_generation_intake_slice_ready": "1",
    "v61gd_post_gc_v53_partial_external_return_slice_intake_ready": "1",
    "v53r_complete_source_review_packet_ready": "1",
    "v61_return_root_supplied": "0",
    "v61_return_root_exists": "0",
    "v61_generation_result_return_dir_exists": "0",
    "v61_env_real_provenance": "0",
    "v61_marker_supplied": "0",
    "v61_marker_real_provenance": "0",
    "v61_real_provenance_ready": "0",
    "candidate_generation_result_artifacts": "0",
    "candidate_answer_rows": "0",
    "candidate_citation_rows": "0",
    "candidate_abstain_fallback_rows": "0",
    "candidate_latency_rows": "0",
    "candidate_acceptance_summary_ready": "0",
    "candidate_generation_result_accepted_rows": "0",
    "real_generation_result_artifacts": "0",
    "accepted_generation_result_artifacts": "0",
    "generation_result_accepted_rows": "0",
    "accepted_answer_rows": "0",
    "accepted_citation_rows": "0",
    "accepted_latency_rows": "0",
    "partial_real_generation_slice_ready": "0",
    "generation_execution_admission_ready": "0",
    "generation_acceptance_closure_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61ge": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "stage_rows": "7",
    "ready_stage_rows": "2",
    "blocked_stage_rows": "5",
    "source_file_rows": "4",
    "payload_like_slice_package_file_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ge {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "v61_partial_generation_intake_slice_validation_rows.csv",
    "v61_partial_generation_intake_slice_artifact_status_rows.csv",
    "v61_partial_generation_intake_slice_query_acceptance_rows.csv",
    "v61_partial_generation_intake_slice_minimum_template_rows.csv",
    "v61_partial_generation_intake_slice_stage_rows.csv",
    "v61_partial_generation_intake_slice_supplied_file_rows.csv",
    "v61_partial_generation_intake_slice_source_rows.csv",
    "v61_partial_generation_intake_slice_package_file_rows.csv",
    "V61GE_POST_GD_V61_PARTIAL_GENERATION_INTAKE_SLICE_BOUNDARY.md",
    "v61ge_post_gd_v61_partial_generation_intake_slice_manifest.json",
    "v61ge_post_gd_v61_partial_generation_intake_slice_summary.csv",
    "v61ge_post_gd_v61_partial_generation_intake_slice_decision.csv",
    "v61_partial_generation_intake_slice/V61_PARTIAL_GENERATION_INTAKE_SLICE_VALIDATION_ROWS.csv",
    "v61_partial_generation_intake_slice/V61_PARTIAL_GENERATION_INTAKE_SLICE_ARTIFACT_STATUS_ROWS.csv",
    "v61_partial_generation_intake_slice/V61_PARTIAL_GENERATION_INTAKE_SLICE_QUERY_ACCEPTANCE_ROWS.csv",
    "v61_partial_generation_intake_slice/V61_PARTIAL_GENERATION_INTAKE_SLICE_MINIMUM_TEMPLATE_ROWS.csv",
    "v61_partial_generation_intake_slice/V61_PARTIAL_GENERATION_INTAKE_SLICE_STAGE_ROWS.csv",
    "v61_partial_generation_intake_slice/V61_PARTIAL_GENERATION_INTAKE_SLICE_SUPPLIED_FILE_ROWS.csv",
    "v61_partial_generation_intake_slice/V61_PARTIAL_GENERATION_INTAKE_SLICE_MANIFEST.json",
    "v61_partial_generation_intake_slice/V61_PARTIAL_GENERATION_INTAKE_SLICE.md",
    "v61_partial_generation_intake_slice/VERIFY_V61_PARTIAL_GENERATION_INTAKE_SLICE.sh",
    "source_v61gd/v61gd_post_gc_v53_partial_external_return_slice_intake_summary.csv",
    "source_v53r/review_query_packet_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61ge artifact: {rel}")

if not os.access(slice_dir / "VERIFY_V61_PARTIAL_GENERATION_INTAKE_SLICE.sh", os.X_OK):
    raise SystemExit("v61ge verifier must be executable")

templates = read_csv(run_dir / "v61_partial_generation_intake_slice_minimum_template_rows.csv")
if len(templates) != 6:
    raise SystemExit("v61ge expected six minimum template rows")
if not any(row["template_artifact"] == "review_return_provenance/REAL_REVIEW_RETURN_PROVENANCE.json" for row in templates):
    raise SystemExit("v61ge must require provenance marker template")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61gd-ready", "source-v53r-ready", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61ge expected pass decision: {gate}")
for gate in [
    "v61-root-supplied",
    "v61-real-provenance",
    "candidate-generation-result-slice",
    "real-generation-result-artifacts",
    "accepted-generation-result-artifacts",
    "generation-result-row-acceptance",
    "full-1000-generation-result",
    "actual-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61ge expected blocked decision: {gate}")

manifest = json.loads((slice_dir / "V61_PARTIAL_GENERATION_INTAKE_SLICE_MANIFEST.json").read_text(encoding="utf-8"))
if manifest.get("partial_real_generation_slice_ready") != 0:
    raise SystemExit("v61ge default manifest must keep partial real generation slice blocked")
if manifest.get("real_generation_result_artifacts") != 0:
    raise SystemExit("v61ge default manifest must not claim real generation result artifacts")

boundary = (run_dir / "V61GE_POST_GD_V61_PARTIAL_GENERATION_INTAKE_SLICE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61ge_post_gd_v61_partial_generation_intake_slice_ready=1",
    "real_generation_result_artifacts=0",
    "accepted_generation_result_artifacts=0",
    "generation_result_accepted_rows=0",
    "accepted_answer_rows=0",
    "accepted_citation_rows=0",
    "accepted_latency_rows=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61ge boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61ge sha256 mismatch: {rel}")

print("v61ge default no-root generation slice smoke passed")
PY

TMP_ROOT="${TMPDIR:-/tmp}/v61ge_candidate_fixture_root"
rm -rf "$TMP_ROOT"

python3 - "$ROOT_DIR" "$TMP_ROOT" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
tmp_root = Path(sys.argv[2])
gen = tmp_root / "generation_result_return"
prov = tmp_root / "review_return_provenance"
gen.mkdir(parents=True, exist_ok=True)
prov.mkdir(parents=True, exist_ok=True)
results = root / "results"


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def sha_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def sha_file(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


query = read_csv(results / "v53r_complete_source_review_packet" / "review_001" / "review_query_packet_rows.csv")[0]
generation_id = "fixture_v61ge_generation_001"
latency_id = "fixture_v61ge_latency_001"
model_id = "mistralai/Mixtral-8x22B-v0.1"
checkpoint_root = "/fixture/rejected/checkpoint/root"

answer_path = gen / "real_model_generation_answer_rows.csv"
write_csv(answer_path, [
    "generation_id",
    "review_query_packet_id",
    "query_id",
    "source_span_id",
    "model_id",
    "checkpoint_root",
    "answer_text_sha256",
    "generation_status",
    "abstain_decision",
    "fallback_used",
    "latency_row_id",
    "run_transcript_sha256",
], [{
    "generation_id": generation_id,
    "review_query_packet_id": query["review_query_packet_id"],
    "query_id": query["query_id"],
    "source_span_id": query["source_span_id"],
    "model_id": model_id,
    "checkpoint_root": checkpoint_root,
    "answer_text_sha256": sha_text("fixture generation answer"),
    "generation_status": "generated",
    "abstain_decision": "0",
    "fallback_used": "0",
    "latency_row_id": latency_id,
    "run_transcript_sha256": sha_text("fixture transcript"),
}])

citation_path = gen / "real_model_generation_citation_rows.csv"
write_csv(citation_path, [
    "generation_id",
    "query_id",
    "citation_id",
    "source_span_id",
    "source_file_sha256",
    "citation_verified",
], [{
    "generation_id": generation_id,
    "query_id": query["query_id"],
    "citation_id": "fixture_v61ge_citation_001",
    "source_span_id": query["source_span_id"],
    "source_file_sha256": query["source_file_sha256"],
    "citation_verified": "1",
}])

abstain_path = gen / "real_model_generation_abstain_fallback_rows.csv"
write_csv(abstain_path, [
    "generation_id",
    "query_id",
    "expected_behavior",
    "abstain_expected",
    "abstain_observed",
    "fallback_used",
    "fallback_reason",
], [{
    "generation_id": generation_id,
    "query_id": query["query_id"],
    "expected_behavior": query["expected_behavior"],
    "abstain_expected": "0",
    "abstain_observed": "0",
    "fallback_used": "0",
    "fallback_reason": "",
}])

latency_path = gen / "real_model_generation_latency_rows.csv"
write_csv(latency_path, [
    "generation_id",
    "query_id",
    "prompt_tokens",
    "output_tokens",
    "prefill_ms",
    "decode_ms",
    "total_ms",
    "tokens_per_second",
], [{
    "generation_id": generation_id,
    "query_id": query["query_id"],
    "prompt_tokens": "128",
    "output_tokens": "32",
    "prefill_ms": "10.0",
    "decode_ms": "20.0",
    "total_ms": "30.0",
    "tokens_per_second": "1.0667",
}])

acceptance_path = gen / "real_model_generation_acceptance_summary.json"
acceptance_path.write_text(json.dumps({
    "generation_protocol_version": "v61ge-partial-generation-slice",
    "acceptance_decision": "accepted-partial-slice",
    "slice_scope": "partial",
    "accepted_answer_rows": 1,
    "answer_rows_sha256": sha_file(answer_path),
    "accepted_citation_rows": 1,
    "citation_rows_sha256": sha_file(citation_path),
    "accepted_abstain_fallback_rows": 1,
    "abstain_fallback_rows_sha256": sha_file(abstain_path),
    "accepted_latency_rows": 1,
    "latency_rows_sha256": sha_file(latency_path),
}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(prov / "REAL_REVIEW_RETURN_PROVENANCE.json").write_text(json.dumps({
    "provenance": "real-generation-intake-return-bundle",
    "source_class": "external-generation-intake-return",
    "generation_operator_authority_path": "review_return_provenance/operator_attestation/missing_generation_operator_authority_statement.txt",
    "generation_operator_authority_sha256": sha_text("fixture operator authority is intentionally rejected"),
}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

V61GE_RUN_ID="fixture_candidate" \
V61GE_V61_RETURN_ROOT="$TMP_ROOT" \
V61GE_V61_RETURN_PROVENANCE="real-generation-intake-return-bundle" \
V61GE_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61ge_post_gd_v61_partial_generation_intake_slice.sh" >/dev/null

python3 - "$RESULTS_DIR/$PREFIX/fixture_candidate" "$RESULTS_DIR/${PREFIX}_summary.csv" <<'PY'
import csv
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61_return_root_supplied": "1",
    "v61_return_root_exists": "1",
    "v61_generation_result_return_dir_exists": "1",
    "v61_env_real_provenance": "1",
    "v61_marker_supplied": "1",
    "v61_marker_real_provenance": "0",
    "v61_real_provenance_ready": "0",
    "candidate_generation_result_artifacts": "5",
    "candidate_answer_rows": "1",
    "candidate_citation_rows": "1",
    "candidate_abstain_fallback_rows": "1",
    "candidate_latency_rows": "1",
    "candidate_acceptance_summary_ready": "1",
    "candidate_generation_result_accepted_rows": "1",
    "real_generation_result_artifacts": "0",
    "accepted_generation_result_artifacts": "0",
    "generation_result_accepted_rows": "0",
    "accepted_answer_rows": "0",
    "accepted_citation_rows": "0",
    "accepted_latency_rows": "0",
    "partial_real_generation_slice_ready": "0",
    "actual_model_generation_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61ge fixture candidate {field}: expected {value}, got {summary.get(field)}")

decision_rows = {row["gate"]: row for row in read_csv(run_dir / "v61ge_post_gd_v61_partial_generation_intake_slice_decision.csv")}
if decision_rows["candidate-generation-result-slice"]["status"] != "pass":
    raise SystemExit("v61ge fixture candidate should pass candidate generation-result mechanics")
for gate in ["v61-real-provenance", "real-generation-result-artifacts", "accepted-generation-result-artifacts", "generation-result-row-acceptance"]:
    if decision_rows[gate]["status"] != "blocked":
        raise SystemExit(f"v61ge fixture candidate must keep real gate blocked: {gate}")
if "authority-file-missing" not in decision_rows["v61-real-provenance"]["evidence"]:
    raise SystemExit("v61ge fixture candidate must reject external marker without authority file evidence")

print("v61ge fixture candidate rejection smoke passed")
PY

V61GE_RUN_ID="slice_001" \
V61GE_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61ge_post_gd_v61_partial_generation_intake_slice.sh" >/dev/null
