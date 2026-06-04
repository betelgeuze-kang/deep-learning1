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

PREFIX="v13_real_nlg_transcript"
BINDER_PREFIX="v13_real_run_binder_manifest"
PACKET_PREFIX="v13_evidence_packet_abi"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v13_real_nlg_transcript_smoke"
  BINDER_PREFIX="v13_real_run_binder_manifest_smoke"
  PACKET_PREFIX="v13_evidence_packet_abi_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v13_real_nlg_transcript_full"
  BINDER_PREFIX="v13_real_run_binder_manifest_full"
  PACKET_PREFIX="v13_evidence_packet_abi_full"
  RUN_ARGS=(--full)
fi

RUN_ID="${V13_REAL_RUN_ID:-run_001}"
RUN_DIR="${V13_REAL_NLG_TRANSCRIPT_RUN_DIR:-$RESULTS_DIR/${BINDER_PREFIX}_runs/$RUN_ID}"
RUN_SOURCE="generated-diagnostic-run"
if [[ -n "${V13_REAL_NLG_TRANSCRIPT_RUN_DIR:-}" ]]; then
  RUN_SOURCE="provided-run-dir"
fi

TRANSCRIPT_PACKET_DIR="$RESULTS_DIR/${PREFIX}_packet/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PACKET_SUMMARY_CSV="$RESULTS_DIR/${PACKET_PREFIX}_summary.csv"
EVIDENCE_PACKET_DIR="$RESULTS_DIR/${PACKET_PREFIX}_packet/$RUN_ID"

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
  "$ROOT_DIR/experiments/run_v13_evidence_packet_abi.sh" "${RUN_ARGS[@]}" >/dev/null
else
  V13_EVIDENCE_PACKET_RUN_DIR="$RUN_DIR" \
    "$ROOT_DIR/experiments/run_v13_evidence_packet_abi.sh" "${RUN_ARGS[@]}" >/dev/null
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

transcript_metrics="$(
  python3 - "$RUN_DIR" "$PACKET_SUMMARY_CSV" "$EVIDENCE_PACKET_DIR" "$TRANSCRIPT_PACKET_DIR" "$RUN_SOURCE" "$run_hash_manifest_ready" "$store_hash_manifest_ready" <<'PY'
import csv
import hashlib
import json
import mmap
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
packet_summary_csv = Path(sys.argv[2])
evidence_packet_dir = Path(sys.argv[3])
transcript_packet_dir = Path(sys.argv[4])
run_source = sys.argv[5]
run_hash_manifest_ready = int(sys.argv[6])
store_hash_manifest_ready = int(sys.argv[7])

transcript_packet_dir.mkdir(parents=True, exist_ok=True)

def first_row(path):
    if not path.is_file():
        return {}
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    return rows[0] if rows else {}

def read_csv(path):
    if not path.is_file():
        return []
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

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

packet_summary = first_row(packet_summary_csv)
packet_hash_entries = 0
packet_hash_verified = 0
packet_manifest = evidence_packet_dir / "sha256sums.txt"
if packet_manifest.is_file():
    with packet_manifest.open(encoding="utf-8") as handle:
        for line in handle:
            if "  " not in line:
                continue
            expected, rel = line.rstrip("\n").split("  ", 1)
            packet_hash_entries += 1
            path = evidence_packet_dir / rel
            if path.is_file() and sha256(path) == expected:
                packet_hash_verified += 1
packet_hash_manifest_ready = int(packet_hash_entries > 0 and packet_hash_entries == packet_hash_verified)
evidence_packet_abi_ready = as_int(packet_summary, "evidence_packet_abi_ready")

transcript_jsonl = run_dir / "nlg" / "transcript.jsonl"
result_json_path = run_dir / "nlg" / "result_summary.json"
route_index_path = run_dir / "store" / "route_index.bin"
chunk_pages_path = run_dir / "store" / "chunk_pages.bin"
v13_manifest = first_row(run_dir / "evidence" / "v13_run_manifest.csv")
h11d = first_row(run_dir / "evidence" / "h11d.csv")
v12_input = first_row(run_dir / "evidence" / "v12_input.csv")

transcript_rows = []
transcript_json_valid = 0
try:
    with transcript_jsonl.open(encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                transcript_rows.append(json.loads(line))
    transcript_json_valid = 1
except Exception:
    transcript_rows = []

result = {}
result_json_valid = 0
try:
    with result_json_path.open(encoding="utf-8") as handle:
        result = json.load(handle)
    result_json_valid = 1
except Exception:
    result = {}

route_rows = read_csv(route_index_path)
route_by_query = {row.get("query_id", ""): row for row in route_rows}

route_index_rows = len(route_rows)
present_route_rows = sum(1 for row in route_rows if row.get("abstain") == "0")
missing_route_rows = sum(1 for row in route_rows if row.get("abstain") == "1")

teacher_off_rows = 0
retrieved_chunk_matches = 0
evidence_span_matches = 0
span_byte_matches = 0
answer_grounded_matches = 0
citation_matches = 0
missing_abstain_matches = 0
binding_rows = []

try:
    with chunk_pages_path.open("rb") as handle:
        with mmap.mmap(handle.fileno(), 0, access=mmap.ACCESS_READ) as mm:
            for row in transcript_rows:
                query_id = str(row.get("query_id", ""))
                route = route_by_query.get(query_id, {})
                route_abstain = route.get("abstain") == "1"
                evidence_span = str(row.get("evidence_span", ""))
                answer = str(row.get("answer", ""))
                citation = str(row.get("citation", ""))
                retrieved_chunk_id = str(row.get("retrieved_chunk_id", ""))
                expected_span = "ABSTAIN" if route_abstain else str(route.get("expected_span", ""))

                teacher_off = 1 if row.get("teacher_off_inference") is True else 0
                if teacher_off:
                    teacher_off_rows += 1

                chunk_match = 0
                span_match = 0
                byte_match = 0
                grounded = 0
                citation_match = 0
                missing_match = 0

                if route:
                    if route_abstain:
                        chunk_match = 1 if retrieved_chunk_id == "ABSTAIN" else 0
                        span_match = 1 if evidence_span == "ABSTAIN" else 0
                        byte_match = 1
                        grounded = 1 if answer == "ABSTAIN" else 0
                        citation_match = 1 if citation == "ABSTAIN" else 0
                        missing_match = 1 if chunk_match and span_match and grounded and citation_match else 0
                    else:
                        chunk_match = 1 if retrieved_chunk_id == route.get("chunk_id") else 0
                        span_match = 1 if evidence_span == route.get("expected_span") else 0
                        start = int(route.get("span_offset", "0"))
                        length = int(route.get("span_len", "0"))
                        actual = mm[start:start + length].decode("utf-8")
                        byte_match = 1 if actual == route.get("expected_span") and evidence_span == actual else 0
                        grounded = 1 if evidence_span and evidence_span in answer else 0
                        citation_match = 1 if evidence_span and citation == evidence_span else 0

                retrieved_chunk_matches += chunk_match
                evidence_span_matches += span_match
                span_byte_matches += byte_match
                answer_grounded_matches += grounded
                citation_matches += citation_match
                missing_abstain_matches += missing_match

                binding_rows.append({
                    "query_id": query_id,
                    "route_key": str(row.get("route_key", "")),
                    "retrieved_chunk_id": retrieved_chunk_id,
                    "evidence_span": evidence_span,
                    "expected_span": expected_span,
                    "answer": answer,
                    "citation": citation,
                    "teacher_off_inference": teacher_off,
                    "route_index_match": chunk_match,
                    "evidence_span_match": span_match,
                    "span_byte_match": byte_match,
                    "answer_grounded": grounded,
                    "citation_match": citation_match,
                    "missing_abstain_match": missing_match,
                })
except Exception:
    binding_rows = []

binding_csv = transcript_packet_dir / "transcript_binding.csv"
fieldnames = [
    "query_id",
    "route_key",
    "retrieved_chunk_id",
    "evidence_span",
    "expected_span",
    "answer",
    "citation",
    "teacher_off_inference",
    "route_index_match",
    "evidence_span_match",
    "span_byte_match",
    "answer_grounded",
    "citation_match",
    "missing_abstain_match",
]
with binding_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(binding_rows)

manifest = {
    "artifact_scope": "v13-d-real-nlg-transcript",
    "run_source": run_source,
    "run_dir": str(run_dir),
    "transcript_jsonl": "nlg/transcript.jsonl",
    "result_json": "nlg/result_summary.json",
    "binding_rows": len(binding_rows),
    "claim": "binds NLG transcript rows to RouteMemory spans; diagnostic until nonfixture generator evidence exists",
}
(transcript_packet_dir / "transcript_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

with (transcript_packet_dir / "sha256sums.txt").open("w", encoding="utf-8") as handle:
    for path in sorted(transcript_packet_dir.rglob("*")):
        if path.is_file() and path.name != "sha256sums.txt":
            handle.write(f"{sha256(path)}  {path.relative_to(transcript_packet_dir)}\n")

transcript_hash_entries = 0
transcript_hash_verified = 0
with (transcript_packet_dir / "sha256sums.txt").open(encoding="utf-8") as handle:
    for line in handle:
        expected, rel = line.rstrip("\n").split("  ", 1)
        transcript_hash_entries += 1
        if sha256(transcript_packet_dir / rel) == expected:
            transcript_hash_verified += 1
transcript_packet_hash_ready = int(transcript_hash_entries > 0 and transcript_hash_entries == transcript_hash_verified)

result_teacher_off = 1 if result.get("teacher_off_inference") is True else 0
result_retrieved = 1 if result.get("retrieved_evidence_used") is True else 0
result_grounding_declared = 1 if float(result.get("answer_grounded_rate", 0.0) or 0.0) >= 1.0 else 0
result_citation_declared = 1 if float(result.get("span_citation_accuracy", 0.0) or 0.0) >= 1.0 else 0

transcript_count = len(transcript_rows)
transcript_binding_ready = int(
    transcript_json_valid == 1
    and result_json_valid == 1
    and transcript_count > 0
    and len(binding_rows) == transcript_count
    and teacher_off_rows == transcript_count
    and retrieved_chunk_matches == transcript_count
    and evidence_span_matches == transcript_count
    and span_byte_matches == transcript_count
    and answer_grounded_matches == transcript_count
    and citation_matches == transcript_count
    and missing_abstain_matches == missing_route_rows
    and result_teacher_off == 1
    and result_retrieved == 1
    and result_grounding_declared == 1
    and result_citation_declared == 1
)

v12_real_ready = as_int(v12_input, "real_release_package_ready")
h11d_real = as_int(h11d, "real_pc_routelm_nlg_verified")
fixture_declared = v13_manifest.get("fixture_or_generated_declared", "1")
actual_nonfixture = 0 if fixture_declared == "1" else 1

real_nlg_transcript_ready = int(
    transcript_binding_ready == 1
    and evidence_packet_abi_ready == 1
    and h11d_real == 1
    and actual_nonfixture == 1
)

v13_real_nlg_transcript_ready = int(
    run_hash_manifest_ready == 1
    and store_hash_manifest_ready == 1
    and packet_hash_manifest_ready == 1
    and evidence_packet_abi_ready == 1
    and transcript_packet_hash_ready == 1
    and transcript_binding_ready == 1
)

action = "v13-real-nlg-transcript-bound-await-nonfixture-generator"
if run_hash_manifest_ready != 1:
    action = "v13-real-nlg-transcript-run-hash-mismatch"
elif store_hash_manifest_ready != 1:
    action = "v13-real-nlg-transcript-store-hash-mismatch"
elif packet_hash_manifest_ready != 1 or evidence_packet_abi_ready != 1:
    action = "v13-real-nlg-transcript-evidence-packet-not-ready"
elif transcript_json_valid != 1:
    action = "v13-real-nlg-transcript-jsonl-invalid"
elif result_json_valid != 1:
    action = "v13-real-nlg-result-json-invalid"
elif teacher_off_rows != transcript_count:
    action = "v13-real-nlg-teacher-off-missing"
elif retrieved_chunk_matches != transcript_count:
    action = "v13-real-nlg-route-index-mismatch"
elif evidence_span_matches != transcript_count or span_byte_matches != transcript_count:
    action = "v13-real-nlg-evidence-span-mismatch"
elif answer_grounded_matches != transcript_count:
    action = "v13-real-nlg-answer-grounding-mismatch"
elif citation_matches != transcript_count:
    action = "v13-real-nlg-citation-mismatch"
elif missing_abstain_matches != missing_route_rows:
    action = "v13-real-nlg-missing-abstain-mismatch"
elif result_teacher_off != 1 or result_retrieved != 1 or result_grounding_declared != 1 or result_citation_declared != 1:
    action = "v13-real-nlg-result-summary-mismatch"
elif transcript_packet_hash_ready != 1:
    action = "v13-real-nlg-transcript-packet-hash-mismatch"
elif real_nlg_transcript_ready == 1:
    action = "v13-real-nlg-transcript-real-ready"

values = {
    "packet_hash_entries": packet_hash_entries,
    "packet_hash_verified": packet_hash_verified,
    "packet_hash_manifest_ready": packet_hash_manifest_ready,
    "evidence_packet_abi_ready": evidence_packet_abi_ready,
    "transcript_rows": transcript_count,
    "transcript_json_valid": transcript_json_valid,
    "result_json_valid": result_json_valid,
    "route_index_rows": route_index_rows,
    "present_route_rows": present_route_rows,
    "missing_route_rows": missing_route_rows,
    "teacher_off_rows": teacher_off_rows,
    "retrieved_chunk_matches": retrieved_chunk_matches,
    "evidence_span_matches": evidence_span_matches,
    "span_byte_matches": span_byte_matches,
    "answer_grounded_matches": answer_grounded_matches,
    "citation_matches": citation_matches,
    "missing_abstain_matches": missing_abstain_matches,
    "result_teacher_off": result_teacher_off,
    "result_retrieved_evidence_used": result_retrieved,
    "result_grounding_declared": result_grounding_declared,
    "result_citation_declared": result_citation_declared,
    "transcript_hash_entries": transcript_hash_entries,
    "transcript_hash_verified": transcript_hash_verified,
    "transcript_packet_hash_ready": transcript_packet_hash_ready,
    "transcript_binding_rows": len(binding_rows),
    "transcript_binding_ready": transcript_binding_ready,
    "v13_real_nlg_transcript_ready": v13_real_nlg_transcript_ready,
    "real_nlg_transcript_ready": real_nlg_transcript_ready,
    "actual_nonfixture_run_verified": actual_nonfixture if real_nlg_transcript_ready else 0,
    "real_pc_routelm_nlg_verified": h11d_real if real_nlg_transcript_ready else 0,
    "real_external_benchmark_verified": 0,
    "real_release_package_ready": v12_real_ready if real_nlg_transcript_ready else 0,
    "action": action,
    "routing_trigger_rate": "0.000000",
    "active_jump_rate": "0.000000",
}
for key, value in values.items():
    print(f"{key}={value}")
PY
)"

eval "$transcript_metrics"

{
  echo "transcript_scope,run_source,run_id,run_dir,evidence_packet_dir,transcript_packet_dir,run_hash_entries,run_hash_verified,run_hash_manifest_ready,store_hash_entries,store_hash_verified,store_hash_manifest_ready,packet_hash_entries,packet_hash_verified,packet_hash_manifest_ready,evidence_packet_abi_ready,transcript_rows,transcript_json_valid,result_json_valid,route_index_rows,present_route_rows,missing_route_rows,teacher_off_rows,retrieved_chunk_matches,evidence_span_matches,span_byte_matches,answer_grounded_matches,citation_matches,missing_abstain_matches,result_teacher_off,result_retrieved_evidence_used,result_grounding_declared,result_citation_declared,transcript_hash_entries,transcript_hash_verified,transcript_packet_hash_ready,transcript_binding_rows,transcript_binding_ready,v13_real_nlg_transcript_ready,real_nlg_transcript_ready,actual_nonfixture_run_verified,real_pc_routelm_nlg_verified,real_external_benchmark_verified,real_release_package_ready,action,routing_trigger_rate,active_jump_rate"
  printf "v13-d-real-nlg-transcript,%s,%s,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s,%s\n" \
    "$RUN_SOURCE" \
    "$RUN_ID" \
    "$RUN_DIR" \
    "$EVIDENCE_PACKET_DIR" \
    "$TRANSCRIPT_PACKET_DIR" \
    "$run_hash_entries" \
    "$run_hash_verified" \
    "$run_hash_manifest_ready" \
    "$store_hash_entries" \
    "$store_hash_verified" \
    "$store_hash_manifest_ready" \
    "$packet_hash_entries" \
    "$packet_hash_verified" \
    "$packet_hash_manifest_ready" \
    "$evidence_packet_abi_ready" \
    "$transcript_rows" \
    "$transcript_json_valid" \
    "$result_json_valid" \
    "$route_index_rows" \
    "$present_route_rows" \
    "$missing_route_rows" \
    "$teacher_off_rows" \
    "$retrieved_chunk_matches" \
    "$evidence_span_matches" \
    "$span_byte_matches" \
    "$answer_grounded_matches" \
    "$citation_matches" \
    "$missing_abstain_matches" \
    "$result_teacher_off" \
    "$result_retrieved_evidence_used" \
    "$result_grounding_declared" \
    "$result_citation_declared" \
    "$transcript_hash_entries" \
    "$transcript_hash_verified" \
    "$transcript_packet_hash_ready" \
    "$transcript_binding_rows" \
    "$transcript_binding_ready" \
    "$v13_real_nlg_transcript_ready" \
    "$real_nlg_transcript_ready" \
    "$actual_nonfixture_run_verified" \
    "$real_pc_routelm_nlg_verified" \
    "$real_external_benchmark_verified" \
    "$real_release_package_ready" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

run_hash_status=blocked
[[ "$run_hash_manifest_ready" == "1" ]] && run_hash_status=pass
store_hash_status=blocked
[[ "$store_hash_manifest_ready" == "1" ]] && store_hash_status=pass
packet_status=blocked
[[ "$packet_hash_manifest_ready" == "1" && "$evidence_packet_abi_ready" == "1" ]] && packet_status=pass
json_status=blocked
[[ "$transcript_json_valid" == "1" && "$result_json_valid" == "1" ]] && json_status=pass
route_status=blocked
[[ "$retrieved_chunk_matches" == "$transcript_rows" && "$missing_abstain_matches" == "$missing_route_rows" ]] && route_status=pass
span_status=blocked
[[ "$evidence_span_matches" == "$transcript_rows" && "$span_byte_matches" == "$transcript_rows" ]] && span_status=pass
ground_status=blocked
[[ "$answer_grounded_matches" == "$transcript_rows" && "$citation_matches" == "$transcript_rows" ]] && ground_status=pass
result_status=blocked
[[ "$result_teacher_off" == "1" && "$result_retrieved_evidence_used" == "1" && "$result_grounding_declared" == "1" && "$result_citation_declared" == "1" ]] && result_status=pass
transcript_hash_status=blocked
[[ "$transcript_packet_hash_ready" == "1" ]] && transcript_hash_status=pass
ready_status=blocked
[[ "$v13_real_nlg_transcript_ready" == "1" ]] && ready_status=pass

{
  echo "gate,status,reason"
  printf "run-hash-manifest,%s,verified=%d/%d\n" \
    "$run_hash_status" "$run_hash_verified" "$run_hash_entries"
  printf "store-hash-manifest,%s,verified=%d/%d\n" \
    "$store_hash_status" "$store_hash_verified" "$store_hash_entries"
  printf "evidence-packet,%s,ready=%d packet_hash=%d/%d\n" \
    "$packet_status" "$evidence_packet_abi_ready" "$packet_hash_verified" "$packet_hash_entries"
  printf "transcript-json,%s,transcript=%d result=%d rows=%d\n" \
    "$json_status" "$transcript_json_valid" "$result_json_valid" "$transcript_rows"
  printf "route-index-binding,%s,chunk=%d/%d missing=%d/%d\n" \
    "$route_status" "$retrieved_chunk_matches" "$transcript_rows" "$missing_abstain_matches" "$missing_route_rows"
  printf "span-byte-binding,%s,span=%d/%d byte=%d/%d\n" \
    "$span_status" "$evidence_span_matches" "$transcript_rows" "$span_byte_matches" "$transcript_rows"
  printf "grounded-answer,%s,answer=%d/%d citation=%d/%d\n" \
    "$ground_status" "$answer_grounded_matches" "$transcript_rows" "$citation_matches" "$transcript_rows"
  printf "result-summary,%s,teacher_off=%d retrieved=%d grounding=%d citation=%d\n" \
    "$result_status" "$result_teacher_off" "$result_retrieved_evidence_used" "$result_grounding_declared" "$result_citation_declared"
  printf "transcript-packet-hash,%s,verified=%d/%d\n" \
    "$transcript_hash_status" "$transcript_hash_verified" "$transcript_hash_entries"
  printf "real-nlg-transcript,%s,real_ready=%d actual_nonfixture=%d real_nlg=%d\n" \
    "$([[ "$real_nlg_transcript_ready" == "1" ]] && echo pass || echo blocked)" "$real_nlg_transcript_ready" "$actual_nonfixture_run_verified" "$real_pc_routelm_nlg_verified"
  printf "v13-real-nlg-transcript,%s,ready=%d action=%s\n" \
    "$ready_status" "$v13_real_nlg_transcript_ready" "$action"
} >"$DECISION_CSV"

echo "transcript_packet_dir: $TRANSCRIPT_PACKET_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
