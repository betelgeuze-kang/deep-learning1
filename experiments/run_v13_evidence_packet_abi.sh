#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

MODE="standard"
if [[ "${1:-}" == "--smoke" ]]; then
  MODE="smoke"
elif [[ "${1:-}" == "--full" ]]; then
  MODE="full"
elif [[ "${1:-}" != "" ]]; then
  echo "usage: $0 [--smoke|--full]" >&2
  exit 2
fi

mkdir -p "$RESULTS_DIR"

PREFIX="v13_evidence_packet_abi"
BINDER_PREFIX="v13_real_run_binder_manifest"
READER_PREFIX="v13_routelm_mmap_reader"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v13_evidence_packet_abi_smoke"
  BINDER_PREFIX="v13_real_run_binder_manifest_smoke"
  READER_PREFIX="v13_routelm_mmap_reader_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v13_evidence_packet_abi_full"
  BINDER_PREFIX="v13_real_run_binder_manifest_full"
  READER_PREFIX="v13_routelm_mmap_reader_full"
  RUN_ARGS=(--full)
fi

RUN_ID="${V13_REAL_RUN_ID:-run_001}"
RUN_DIR="${V13_EVIDENCE_PACKET_RUN_DIR:-$RESULTS_DIR/${BINDER_PREFIX}_runs/$RUN_ID}"
RUN_SOURCE="generated-diagnostic-run"
if [[ -n "${V13_EVIDENCE_PACKET_RUN_DIR:-}" ]]; then
  RUN_SOURCE="provided-run-dir"
fi

PACKET_DIR="$RESULTS_DIR/${PREFIX}_packet/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
READER_SUMMARY_CSV="$RESULTS_DIR/${READER_PREFIX}_summary.csv"

verify_hash_manifest() {
  local dir="$1"
  local manifest="$dir/sha256sums.txt"

  if [[ ! -f "$manifest" ]]; then
    printf '0,0\n'
    return 0
  fi
  (
    cd "$dir"
    awk '
      NF >= 2 {
        entries++
        expected = $1
        file = $2
        command = "sha256sum \"" file "\" 2>/dev/null"
        command | getline line
        close(command)
        split(line, parts, " ")
        if (parts[1] == expected) verified++
      }
      END {
        printf "%d,%d\n", entries + 0, verified + 0
      }
    ' sha256sums.txt
  )
}

if [[ "$RUN_SOURCE" == "generated-diagnostic-run" ]]; then
  "$ROOT_DIR/experiments/run_v13_routelm_mmap_reader.sh" "${RUN_ARGS[@]}" >/dev/null
else
  V13_ROUTELM_MMAP_READER_RUN_DIR="$RUN_DIR" \
    "$ROOT_DIR/experiments/run_v13_routelm_mmap_reader.sh" "${RUN_ARGS[@]}" >/dev/null
fi

IFS=, read -r run_hash_entries run_hash_verified <<<"$(verify_hash_manifest "$RUN_DIR")"
run_hash_manifest_ready=0
if [[ "$run_hash_entries" -gt 0 && "$run_hash_entries" -eq "$run_hash_verified" ]]; then
  run_hash_manifest_ready=1
fi

IFS=, read -r store_hash_entries store_hash_verified <<<"$(verify_hash_manifest "$RUN_DIR/store")"
store_hash_manifest_ready=0
if [[ "$store_hash_entries" -gt 0 && "$store_hash_entries" -eq "$store_hash_verified" ]]; then
  store_hash_manifest_ready=1
fi

packet_metrics="$(
  python3 - "$RUN_DIR" "$READER_SUMMARY_CSV" "$PACKET_DIR" "$RUN_SOURCE" "$run_hash_manifest_ready" "$store_hash_manifest_ready" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
reader_summary_csv = Path(sys.argv[2])
packet_dir = Path(sys.argv[3])
run_source = sys.argv[4]
run_hash_manifest_ready = int(sys.argv[5])
store_hash_manifest_ready = int(sys.argv[6])

packet_dir.mkdir(parents=True, exist_ok=True)

def first_row(path):
    if not path.is_file():
        return {}
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    return rows[0] if rows else {}

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def as_int(row, field, default=0):
    try:
        return int(float(row.get(field, default) or default))
    except ValueError:
        return default

h11c = first_row(run_dir / "evidence" / "h11c.csv")
h11d = first_row(run_dir / "evidence" / "h11d.csv")
h9h = first_row(run_dir / "evidence" / "h9h.csv")
v08_run = first_row(run_dir / "evidence" / "v08_run.csv")
h10s = first_row(run_dir / "evidence" / "h10s.csv")
v12_input = first_row(run_dir / "evidence" / "v12_input.csv")
v13_manifest = first_row(run_dir / "evidence" / "v13_run_manifest.csv")
reader = first_row(reader_summary_csv)

reader_ready = as_int(reader, "routelm_mmap_reader_ready")
h11c_ready = as_int(h11c, "route_memory_artifact_chain_verified")
h11d_ready = as_int(h11d, "pc_routelm_nlg_smoke_ready")
h9h_ready = as_int(h9h, "diagnostic_workload_speed_ready")
v08_ready = as_int(v08_run, "codebase_run_evaluator_trace_ready")
h10s_student_ready = as_int(h10s, "student_only_eval_ready")
h10s_source_ready = as_int(h10s, "source_verified_learned_chunk_scorer_eval_ready")
v12_diag_ready = as_int(v12_input, "diagnostic_release_package_ready")
v12_real_ready = as_int(v12_input, "real_release_package_ready")

h11c_real = as_int(h11c, "real_pc_routelm_artifact_verified")
h11d_real = as_int(h11d, "real_pc_routelm_nlg_verified")
h9h_real = as_int(h9h, "real_workload_speed_evidence_ready")
v08_real = as_int(v08_run, "real_external_benchmark_verified")

routing = "0.000000"
active_jump = "0.000000"
gpu_speedup_claim = h9h.get("gpu_speedup_claim", "deferred") or "deferred"

artifact_specs = [
    ("run_manifest", "run_manifest.json", "run-metadata", "run-binding", 1, 0),
    ("v13_run_manifest", "evidence/v13_run_manifest.csv", "run-index", "run-binding", 1, 0),
    ("h11c_store_summary", "evidence/h11c.csv", "store-summary", "route-memory-store", h11c_ready, h11c_real),
    ("h11d_nlg_summary", "evidence/h11d.csv", "nlg-summary", "diagnostic-nlg", h11d_ready, h11d_real),
    ("h9h_resource_summary", "evidence/h9h.csv", "resource-summary", "resource-envelope", h9h_ready, h9h_real),
    ("v08_run_trace_summary", "evidence/v08_run.csv", "benchmark-summary", "external-trace-binding", v08_ready, v08_real),
    ("h10s_scorer_eval_summary", "evidence/h10s.csv", "scorer-summary", "learned-ranking", h10s_student_ready and h10s_source_ready, h10s_source_ready),
    ("v12_claim_audit_input", "evidence/v12_input.csv", "claim-audit-summary", "claim-matrix", v12_diag_ready, v12_real_ready),
    ("nlg_transcript", "nlg/transcript.jsonl", "raw-transcript", "diagnostic-nlg", h11d_ready, h11d_real),
    ("nlg_result_summary", "nlg/result_summary.json", "nlg-result", "diagnostic-nlg", h11d_ready, h11d_real),
    ("speed_workload", "speed/workload.csv", "resource-rows", "resource-envelope", h9h_ready, h9h_real),
    ("benchmark_runner_manifest", "benchmark/runner_manifest.json", "benchmark-runner", "external-trace-binding", v08_ready, v08_real),
    ("benchmark_evaluator_manifest", "benchmark/evaluator_manifest.json", "benchmark-evaluator", "external-trace-binding", v08_ready, v08_real),
    ("benchmark_query_trace", "benchmark/query_trace.csv", "raw-trace", "external-trace-binding", v08_ready, v08_real),
    ("benchmark_evaluator_output", "benchmark/evaluator_output.csv", "evaluator-output", "external-trace-binding", v08_ready, v08_real),
    ("benchmark_metrics_recomputed", "benchmark/metrics_recomputed.csv", "metric-report", "external-trace-binding", v08_ready, v08_real),
    ("store_manifest", "store/manifest.json", "store-metadata", "route-memory-store", reader_ready, h11c_real),
    ("store_route_index", "store/route_index.bin", "route-index", "route-memory-store", reader_ready, h11c_real),
    ("store_page_table", "store/page_table.bin", "page-table", "route-memory-store", reader_ready, h11c_real),
    ("store_chunk_offsets", "store/chunk_offsets.bin", "chunk-offsets", "route-memory-store", reader_ready, h11c_real),
    ("store_chunk_pages", "store/chunk_pages.bin", "chunk-pages", "route-memory-store", reader_ready, h11c_real),
]

packet_rows = []
for source_id, rel_path, kind, claim_scope, diagnostic_ready, real_verified in artifact_specs:
    path = run_dir / rel_path
    exists = path.is_file()
    packet_rows.append({
        "packet_abi": "v13-c-evidence-packet-abi",
        "run_id": v13_manifest.get("run_id", run_dir.name),
        "source_id": source_id,
        "relative_path": rel_path,
        "artifact_sha256": sha256(path) if exists else "MISSING",
        "artifact_bytes": path.stat().st_size if exists else 0,
        "evidence_kind": kind,
        "claim_scope": claim_scope,
        "diagnostic_ready": int(bool(diagnostic_ready)),
        "real_verified": int(bool(real_verified)),
        "fixture_or_generated_declared": v13_manifest.get("fixture_or_generated_declared", "1"),
    })

reader_exists = reader_summary_csv.is_file()
packet_rows.append({
    "packet_abi": "v13-c-evidence-packet-abi",
    "run_id": v13_manifest.get("run_id", run_dir.name),
    "source_id": "v13b_reader_summary",
    "relative_path": str(reader_summary_csv),
    "artifact_sha256": sha256(reader_summary_csv) if reader_exists else "MISSING",
    "artifact_bytes": reader_summary_csv.stat().st_size if reader_exists else 0,
    "evidence_kind": "mmap-reader-summary",
    "claim_scope": "route-memory-store",
    "diagnostic_ready": reader_ready,
    "real_verified": as_int(reader, "real_pc_routelm_artifact_verified"),
    "fixture_or_generated_declared": v13_manifest.get("fixture_or_generated_declared", "1"),
})

packet_csv = packet_dir / "evidence_packet.csv"
with packet_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(packet_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(packet_rows)

claim_rows = [
    {
        "claim_id": "route_memory_store_mmap_readable",
        "claim_scope": "route-memory-store",
        "required_sources": "h11c_store_summary|store_manifest|store_route_index|store_page_table|store_chunk_offsets|store_chunk_pages|v13b_reader_summary",
        "diagnostic_ready": int(h11c_ready == 1 and reader_ready == 1),
        "real_verified": h11c_real,
        "claim_state": "diagnostic-only" if h11c_ready == 1 and reader_ready == 1 and h11c_real == 0 else "blocked",
    },
    {
        "claim_id": "pc_routelm_nlg_transcript_bound",
        "claim_scope": "diagnostic-nlg",
        "required_sources": "h11d_nlg_summary|nlg_transcript|nlg_result_summary",
        "diagnostic_ready": h11d_ready,
        "real_verified": h11d_real,
        "claim_state": "diagnostic-only" if h11d_ready == 1 and h11d_real == 0 else "blocked",
    },
    {
        "claim_id": "external_benchmark_trace_bound",
        "claim_scope": "external-trace-binding",
        "required_sources": "v08_run_trace_summary|benchmark_runner_manifest|benchmark_evaluator_manifest|benchmark_query_trace|benchmark_evaluator_output|benchmark_metrics_recomputed",
        "diagnostic_ready": v08_ready,
        "real_verified": v08_real,
        "claim_state": "diagnostic-only" if v08_ready == 1 and v08_real == 0 else "blocked",
    },
    {
        "claim_id": "resource_envelope_bound",
        "claim_scope": "resource-envelope",
        "required_sources": "h9h_resource_summary|speed_workload",
        "diagnostic_ready": h9h_ready,
        "real_verified": h9h_real,
        "claim_state": "diagnostic-only" if h9h_ready == 1 and h9h_real == 0 else "blocked",
    },
    {
        "claim_id": "learned_chunk_ranking_source_verified",
        "claim_scope": "learned-ranking",
        "required_sources": "h10s_scorer_eval_summary",
        "diagnostic_ready": int(h10s_student_ready == 1 and h10s_source_ready == 1),
        "real_verified": h10s_source_ready,
        "claim_state": "blocked",
    },
    {
        "claim_id": "v12_release_claim_matrix_bound",
        "claim_scope": "claim-matrix",
        "required_sources": "v12_claim_audit_input|v13_run_manifest",
        "diagnostic_ready": v12_diag_ready,
        "real_verified": v12_real_ready,
        "claim_state": "diagnostic-only" if v12_diag_ready == 1 and v12_real_ready == 0 else "blocked",
    },
    {
        "claim_id": "gpu_speedup_claim",
        "claim_scope": "resource-envelope",
        "required_sources": "h9h_resource_summary|speed_workload",
        "diagnostic_ready": h9h_ready,
        "real_verified": h9h_real,
        "claim_state": "deferred" if gpu_speedup_claim == "deferred" else "review-required",
    },
]

claim_csv = packet_dir / "claim_matrix_input.csv"
with claim_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(claim_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(claim_rows)

source_ids = {row["source_id"] for row in packet_rows}
claim_refs_resolved = 0
for row in claim_rows:
    required = [item for item in row["required_sources"].split("|") if item]
    if all(item in source_ids for item in required):
        claim_refs_resolved += 1

artifact_files_found = sum(1 for row in packet_rows if row["artifact_sha256"] != "MISSING")
artifact_sha_ready = int(artifact_files_found == len(packet_rows))

manifest = {
    "artifact_scope": "v13-c-evidence-packet-abi",
    "run_source": run_source,
    "run_dir": str(run_dir),
    "packet_rows": len(packet_rows),
    "claim_rows": len(claim_rows),
    "claim_refs_resolved": claim_refs_resolved,
    "claim": "normalizes bound raw trace, evaluator, store, NLG, workload, scorer, and v12 inputs into evidence rows; diagnostic packet only",
}
(packet_dir / "packet_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

if reader_exists:
    artifact_copy_dir = packet_dir / "artifacts"
    artifact_copy_dir.mkdir(exist_ok=True)
    shutil.copy2(reader_summary_csv, artifact_copy_dir / "v13b_reader_summary.csv")

with (packet_dir / "sha256sums.txt").open("w", encoding="utf-8") as handle:
    for path in sorted(packet_dir.rglob("*")):
        if path.is_file() and path.name != "sha256sums.txt":
            handle.write(f"{sha256(path)}  {path.relative_to(packet_dir)}\n")

packet_hash_entries = 0
packet_hash_verified = 0
with (packet_dir / "sha256sums.txt").open(encoding="utf-8") as handle:
    for line in handle:
        expected, rel = line.strip().split("  ", 1)
        actual = sha256(packet_dir / rel)
        packet_hash_entries += 1
        if actual == expected:
            packet_hash_verified += 1

packet_hash_manifest_ready = int(packet_hash_entries > 0 and packet_hash_entries == packet_hash_verified)
claim_matrix_input_ready = int(len(claim_rows) == 7 and claim_refs_resolved == 7)
diagnostic_store_read_claim_ready = int(h11c_ready == 1 and reader_ready == 1)
diagnostic_nlg_claim_ready = h11d_ready
diagnostic_external_trace_claim_ready = v08_ready
diagnostic_workload_claim_ready = h9h_ready
learned_chunk_ranking_claim_ready = int(h10s_student_ready == 1 and h10s_source_ready == 1)

evidence_packet_abi_ready = int(
    run_hash_manifest_ready == 1
    and store_hash_manifest_ready == 1
    and reader_ready == 1
    and artifact_sha_ready == 1
    and packet_hash_manifest_ready == 1
    and claim_matrix_input_ready == 1
)

action = "v13-evidence-packet-ready-await-nonfixture-runner"
if run_hash_manifest_ready != 1:
    action = "v13-evidence-packet-run-hash-mismatch"
elif store_hash_manifest_ready != 1:
    action = "v13-evidence-packet-store-hash-mismatch"
elif reader_ready != 1:
    action = "v13-evidence-packet-reader-not-ready"
elif artifact_sha_ready != 1:
    action = "v13-evidence-packet-required-artifact-missing"
elif claim_matrix_input_ready != 1:
    action = "v13-evidence-packet-claim-matrix-invalid"

actual_nonfixture = 0 if v13_manifest.get("fixture_or_generated_declared", "1") == "1" else 1

values = {
    "packet_rows": len(packet_rows),
    "claim_rows": len(claim_rows),
    "claim_refs_resolved": claim_refs_resolved,
    "required_artifact_rows": len(packet_rows),
    "artifact_files_found": artifact_files_found,
    "artifact_sha_ready": artifact_sha_ready,
    "packet_hash_entries": packet_hash_entries,
    "packet_hash_verified": packet_hash_verified,
    "packet_hash_manifest_ready": packet_hash_manifest_ready,
    "routelm_mmap_reader_ready": reader_ready,
    "diagnostic_store_read_claim_ready": diagnostic_store_read_claim_ready,
    "diagnostic_nlg_claim_ready": diagnostic_nlg_claim_ready,
    "diagnostic_external_trace_claim_ready": diagnostic_external_trace_claim_ready,
    "diagnostic_workload_claim_ready": diagnostic_workload_claim_ready,
    "learned_chunk_ranking_claim_ready": learned_chunk_ranking_claim_ready,
    "v12_diagnostic_release_ready": v12_diag_ready,
    "v12_real_release_ready": v12_real_ready,
    "claim_matrix_input_ready": claim_matrix_input_ready,
    "evidence_packet_abi_ready": evidence_packet_abi_ready,
    "actual_nonfixture_run_verified": actual_nonfixture if actual_nonfixture and evidence_packet_abi_ready else 0,
    "real_pc_routelm_artifact_verified": h11c_real,
    "real_pc_routelm_nlg_verified": h11d_real,
    "real_external_benchmark_verified": v08_real,
    "real_workload_speed_evidence_ready": h9h_real,
    "real_release_package_ready": v12_real_ready,
    "gpu_speedup_claim": gpu_speedup_claim,
    "action": action,
    "routing_trigger_rate": routing,
    "active_jump_rate": active_jump,
}
for key, value in values.items():
    print(f"{key}={value}")
PY
)"

eval "$packet_metrics"

{
  echo "evidence_scope,run_source,run_id,run_dir,packet_dir,required_artifact_rows,artifact_files_found,artifact_sha_ready,packet_rows,claim_rows,claim_refs_resolved,run_hash_entries,run_hash_verified,run_hash_manifest_ready,store_hash_entries,store_hash_verified,store_hash_manifest_ready,packet_hash_entries,packet_hash_verified,packet_hash_manifest_ready,routelm_mmap_reader_ready,diagnostic_store_read_claim_ready,diagnostic_nlg_claim_ready,diagnostic_external_trace_claim_ready,diagnostic_workload_claim_ready,learned_chunk_ranking_claim_ready,v12_diagnostic_release_ready,v12_real_release_ready,claim_matrix_input_ready,evidence_packet_abi_ready,actual_nonfixture_run_verified,real_pc_routelm_artifact_verified,real_pc_routelm_nlg_verified,real_external_benchmark_verified,real_workload_speed_evidence_ready,real_release_package_ready,gpu_speedup_claim,action,routing_trigger_rate,active_jump_rate"
  printf "v13-c-evidence-packet-abi,%s,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s,%s\n" \
    "$RUN_SOURCE" \
    "$RUN_ID" \
    "$RUN_DIR" \
    "$PACKET_DIR" \
    "$required_artifact_rows" \
    "$artifact_files_found" \
    "$artifact_sha_ready" \
    "$packet_rows" \
    "$claim_rows" \
    "$claim_refs_resolved" \
    "$run_hash_entries" \
    "$run_hash_verified" \
    "$run_hash_manifest_ready" \
    "$store_hash_entries" \
    "$store_hash_verified" \
    "$store_hash_manifest_ready" \
    "$packet_hash_entries" \
    "$packet_hash_verified" \
    "$packet_hash_manifest_ready" \
    "$routelm_mmap_reader_ready" \
    "$diagnostic_store_read_claim_ready" \
    "$diagnostic_nlg_claim_ready" \
    "$diagnostic_external_trace_claim_ready" \
    "$diagnostic_workload_claim_ready" \
    "$learned_chunk_ranking_claim_ready" \
    "$v12_diagnostic_release_ready" \
    "$v12_real_release_ready" \
    "$claim_matrix_input_ready" \
    "$evidence_packet_abi_ready" \
    "$actual_nonfixture_run_verified" \
    "$real_pc_routelm_artifact_verified" \
    "$real_pc_routelm_nlg_verified" \
    "$real_external_benchmark_verified" \
    "$real_workload_speed_evidence_ready" \
    "$real_release_package_ready" \
    "$gpu_speedup_claim" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

run_hash_status=blocked
[[ "$run_hash_manifest_ready" == "1" ]] && run_hash_status=pass
store_hash_status=blocked
[[ "$store_hash_manifest_ready" == "1" ]] && store_hash_status=pass
artifact_status=blocked
[[ "$artifact_sha_ready" == "1" ]] && artifact_status=pass
packet_hash_status=blocked
[[ "$packet_hash_manifest_ready" == "1" ]] && packet_hash_status=pass
reader_status=blocked
[[ "$routelm_mmap_reader_ready" == "1" ]] && reader_status=pass
claim_matrix_status=blocked
[[ "$claim_matrix_input_ready" == "1" ]] && claim_matrix_status=pass
diagnostic_claims_status=blocked
if [[ "$diagnostic_store_read_claim_ready" == "1" &&
      "$diagnostic_nlg_claim_ready" == "1" &&
      "$diagnostic_external_trace_claim_ready" == "1" &&
      "$diagnostic_workload_claim_ready" == "1" &&
      "$v12_diagnostic_release_ready" == "1" ]]; then
  diagnostic_claims_status=pass
fi
ready_status=blocked
[[ "$evidence_packet_abi_ready" == "1" ]] && ready_status=pass

{
  echo "gate,status,reason"
  printf "run-hash-manifest,%s,verified=%d/%d\n" \
    "$run_hash_status" "$run_hash_verified" "$run_hash_entries"
  printf "store-hash-manifest,%s,verified=%d/%d\n" \
    "$store_hash_status" "$store_hash_verified" "$store_hash_entries"
  printf "artifact-rows,%s,files=%d/%d sha_ready=%d\n" \
    "$artifact_status" "$artifact_files_found" "$required_artifact_rows" "$artifact_sha_ready"
  printf "packet-hash-manifest,%s,verified=%d/%d\n" \
    "$packet_hash_status" "$packet_hash_verified" "$packet_hash_entries"
  printf "routelm-mmap-reader,%s,ready=%d\n" \
    "$reader_status" "$routelm_mmap_reader_ready"
  printf "claim-matrix-input,%s,rows=%d refs=%d/%d\n" \
    "$claim_matrix_status" "$claim_rows" "$claim_refs_resolved" "$claim_rows"
  printf "diagnostic-claims,%s,store=%d nlg=%d trace=%d workload=%d v12=%d\n" \
    "$diagnostic_claims_status" "$diagnostic_store_read_claim_ready" "$diagnostic_nlg_claim_ready" "$diagnostic_external_trace_claim_ready" "$diagnostic_workload_claim_ready" "$v12_diagnostic_release_ready"
  printf "learned-ranking-claim,blocked,source_verified=%d\n" \
    "$learned_chunk_ranking_claim_ready"
  printf "real-run-claims,blocked,actual_nonfixture=%d real_artifact=%d real_nlg=%d real_external=%d real_speed=%d real_release=%d gpu=%s\n" \
    "$actual_nonfixture_run_verified" "$real_pc_routelm_artifact_verified" "$real_pc_routelm_nlg_verified" "$real_external_benchmark_verified" "$real_workload_speed_evidence_ready" "$real_release_package_ready" "$gpu_speedup_claim"
  printf "evidence-packet-abi,%s,ready=%d action=%s\n" \
    "$ready_status" "$evidence_packet_abi_ready" "$action"
} >"$DECISION_CSV"

echo "packet_dir: $PACKET_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
