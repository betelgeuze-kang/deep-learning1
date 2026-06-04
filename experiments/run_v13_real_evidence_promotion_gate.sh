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

PREFIX="v13_real_evidence_promotion_gate"
BINDER_PREFIX="v13_real_run_binder_manifest"
EVIDENCE_PREFIX="v13_evidence_packet_abi"
TRANSCRIPT_PREFIX="v13_real_nlg_transcript"
ROUTEQA_PREFIX="v13_public_codebase_routeqa"
RESOURCE_PREFIX="v13_resource_envelope"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v13_real_evidence_promotion_gate_smoke"
  BINDER_PREFIX="v13_real_run_binder_manifest_smoke"
  EVIDENCE_PREFIX="v13_evidence_packet_abi_smoke"
  TRANSCRIPT_PREFIX="v13_real_nlg_transcript_smoke"
  ROUTEQA_PREFIX="v13_public_codebase_routeqa_smoke"
  RESOURCE_PREFIX="v13_resource_envelope_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v13_real_evidence_promotion_gate_full"
  BINDER_PREFIX="v13_real_run_binder_manifest_full"
  EVIDENCE_PREFIX="v13_evidence_packet_abi_full"
  TRANSCRIPT_PREFIX="v13_real_nlg_transcript_full"
  ROUTEQA_PREFIX="v13_public_codebase_routeqa_full"
  RESOURCE_PREFIX="v13_resource_envelope_full"
  RUN_ARGS=(--full)
fi

RUN_ID="${V13_REAL_RUN_ID:-run_001}"
RUN_DIR="${V13_REAL_EVIDENCE_PROMOTION_RUN_DIR:-$RESULTS_DIR/${BINDER_PREFIX}_runs/$RUN_ID}"
RUN_SOURCE="generated-diagnostic-run"
if [[ -n "${V13_REAL_EVIDENCE_PROMOTION_RUN_DIR:-}" ]]; then
  RUN_SOURCE="provided-run-dir"
fi

PACKET_DIR="$RESULTS_DIR/${PREFIX}_packet/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EVIDENCE_SUMMARY_CSV="$RESULTS_DIR/${EVIDENCE_PREFIX}_summary.csv"
TRANSCRIPT_SUMMARY_CSV="$RESULTS_DIR/${TRANSCRIPT_PREFIX}_summary.csv"
ROUTEQA_SUMMARY_CSV="$RESULTS_DIR/${ROUTEQA_PREFIX}_summary.csv"
RESOURCE_SUMMARY_CSV="$RESULTS_DIR/${RESOURCE_PREFIX}_summary.csv"
EVIDENCE_PACKET_DIR="$RESULTS_DIR/${EVIDENCE_PREFIX}_packet/$RUN_ID"
TRANSCRIPT_PACKET_DIR="$RESULTS_DIR/${TRANSCRIPT_PREFIX}_packet/$RUN_ID"
ROUTEQA_PACKET_DIR="$RESULTS_DIR/${ROUTEQA_PREFIX}_packet/$RUN_ID"
RESOURCE_PACKET_DIR="$RESULTS_DIR/${RESOURCE_PREFIX}_packet/$RUN_ID"

if [[ "$RUN_SOURCE" == "generated-diagnostic-run" ]]; then
  "$ROOT_DIR/experiments/run_v13_resource_envelope.sh" "${RUN_ARGS[@]}" >/dev/null
else
  V13_RESOURCE_ENVELOPE_RUN_DIR="$RUN_DIR" \
    "$ROOT_DIR/experiments/run_v13_resource_envelope.sh" "${RUN_ARGS[@]}" >/dev/null
fi

python3 - \
  "$RUN_DIR" \
  "$RUN_SOURCE" \
  "$PACKET_DIR" \
  "$SUMMARY_CSV" \
  "$DECISION_CSV" \
  "$EVIDENCE_SUMMARY_CSV" \
  "$TRANSCRIPT_SUMMARY_CSV" \
  "$ROUTEQA_SUMMARY_CSV" \
  "$RESOURCE_SUMMARY_CSV" \
  "$EVIDENCE_PACKET_DIR" \
  "$TRANSCRIPT_PACKET_DIR" \
  "$ROUTEQA_PACKET_DIR" \
  "$RESOURCE_PACKET_DIR" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
run_source = sys.argv[2]
packet_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
evidence_summary_csv = Path(sys.argv[6])
transcript_summary_csv = Path(sys.argv[7])
routeqa_summary_csv = Path(sys.argv[8])
resource_summary_csv = Path(sys.argv[9])
evidence_packet_dir = Path(sys.argv[10])
transcript_packet_dir = Path(sys.argv[11])
routeqa_packet_dir = Path(sys.argv[12])
resource_packet_dir = Path(sys.argv[13])

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def verify_manifest(base_dir):
    manifest = base_dir / "sha256sums.txt"
    entries = 0
    verified = 0
    if not manifest.is_file():
        return entries, verified
    with manifest.open(encoding="utf-8") as handle:
        for line in handle:
            if "  " not in line:
                continue
            expected, rel = line.rstrip("\n").split("  ", 1)
            path = base_dir / rel
            entries += 1
            if path.is_file() and sha256(path) == expected:
                verified += 1
    return entries, verified

def first_row(path):
    if not path.is_file():
        return {}
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    return rows[0] if rows else {}

def as_int(row, field, default=0):
    try:
        return int(float(row.get(field, default) or default))
    except ValueError:
        return default

def as_float(row, field, default=0.0):
    try:
        return float(row.get(field, default) or default)
    except ValueError:
        return default

run_hash_entries, run_hash_verified = verify_manifest(run_dir)
run_hash_manifest_ready = int(run_hash_entries > 0 and run_hash_entries == run_hash_verified)

evidence = first_row(evidence_summary_csv)
transcript = first_row(transcript_summary_csv)
routeqa = first_row(routeqa_summary_csv)
resource = first_row(resource_summary_csv)
h10s = first_row(run_dir / "evidence" / "h10s.csv")
v08_run = first_row(run_dir / "evidence" / "v08_run.csv")
h9h = first_row(run_dir / "evidence" / "h9h.csv")
h11d = first_row(run_dir / "evidence" / "h11d.csv")
v13_manifest = first_row(run_dir / "evidence" / "v13_run_manifest.csv")

packet_manifests = {
    "evidence": verify_manifest(evidence_packet_dir),
    "transcript": verify_manifest(transcript_packet_dir),
    "routeqa": verify_manifest(routeqa_packet_dir),
    "resource": verify_manifest(resource_packet_dir),
}
packet_ready = {
    name: int(entries > 0 and entries == verified)
    for name, (entries, verified) in packet_manifests.items()
}

evidence_packet_abi_ready = as_int(evidence, "evidence_packet_abi_ready")
v13_real_nlg_transcript_ready = as_int(transcript, "v13_real_nlg_transcript_ready")
public_codebase_routeqa_ready = as_int(routeqa, "public_codebase_routeqa_ready")
resource_envelope_ready = as_int(resource, "resource_envelope_ready")

diagnostic_binding_ready = int(
    run_hash_manifest_ready == 1
    and evidence_packet_abi_ready == 1
    and v13_real_nlg_transcript_ready == 1
    and public_codebase_routeqa_ready == 1
    and resource_envelope_ready == 1
    and all(packet_ready.values())
)

source_verified_learned_chunk_scorer_eval_ready = as_int(h10s, "source_verified_learned_chunk_scorer_eval_ready")
real_teacher_source_verified = as_int(h10s, "real_teacher_source_verified")
metric_improvement_ready = as_int(h10s, "metric_improvement_ready")
real_external_benchmark_verified = int(
    as_int(v08_run, "real_external_benchmark_verified") == 1
    and as_int(routeqa, "real_external_benchmark_verified") == 1
    and as_int(routeqa, "independent_external_routeqa_verified") == 1
)
real_pc_routelm_nlg_verified = int(
    as_int(h11d, "real_pc_routelm_nlg_verified") == 1
    and as_int(transcript, "real_pc_routelm_nlg_verified") == 1
    and as_int(transcript, "real_nlg_transcript_ready") == 1
)
real_workload_speed_evidence_ready = int(
    as_int(h9h, "real_workload_speed_evidence_ready") == 1
    and as_int(resource, "real_workload_speed_evidence_ready") == 1
)
gpu_speedup_claim = resource.get("gpu_speedup_claim") or h9h.get("gpu_speedup_claim") or "deferred"
actual_nonfixture_run_verified = int(
    as_int(evidence, "actual_nonfixture_run_verified") == 1
    and as_int(transcript, "actual_nonfixture_run_verified") == 1
    and as_int(routeqa, "actual_nonfixture_run_verified") == 1
    and as_int(resource, "actual_nonfixture_run_verified") == 1
    and v13_manifest.get("fixture_or_generated_declared", "1") == "0"
    and run_source == "provided-run-dir"
)

learned_chunk_ranking_real_ready = int(
    source_verified_learned_chunk_scorer_eval_ready == 1
    and real_teacher_source_verified == 1
    and metric_improvement_ready == 1
)

external_benchmark_blocker = int(real_external_benchmark_verified != 1)
learned_chunk_ranking_blocker = int(learned_chunk_ranking_real_ready != 1)
gpu_speedup_blocker = int(real_workload_speed_evidence_ready != 1 or gpu_speedup_claim == "deferred")
real_nlg_blocker = int(real_pc_routelm_nlg_verified != 1)
nonfixture_run_blocker = int(actual_nonfixture_run_verified != 1)

real_evidence_promotion_ready = int(
    diagnostic_binding_ready == 1
    and external_benchmark_blocker == 0
    and learned_chunk_ranking_blocker == 0
    and gpu_speedup_blocker == 0
    and real_nlg_blocker == 0
    and nonfixture_run_blocker == 0
)

action = "v13-real-evidence-promotion-await-real-evidence"
if run_hash_manifest_ready != 1:
    action = "v13-real-evidence-promotion-run-hash-mismatch"
elif evidence_packet_abi_ready != 1 or packet_ready["evidence"] != 1:
    action = "v13-real-evidence-promotion-evidence-packet-not-ready"
elif v13_real_nlg_transcript_ready != 1 or packet_ready["transcript"] != 1:
    action = "v13-real-evidence-promotion-transcript-binding-not-ready"
elif public_codebase_routeqa_ready != 1 or packet_ready["routeqa"] != 1:
    action = "v13-real-evidence-promotion-routeqa-not-ready"
elif resource_envelope_ready != 1 or packet_ready["resource"] != 1:
    action = "v13-real-evidence-promotion-resource-envelope-not-ready"
elif real_external_benchmark_verified != 1:
    action = "v13-real-evidence-promotion-external-benchmark-missing"
elif learned_chunk_ranking_real_ready != 1:
    action = "v13-real-evidence-promotion-learned-scorer-real-source-missing"
elif real_pc_routelm_nlg_verified != 1:
    action = "v13-real-evidence-promotion-real-nlg-missing"
elif real_workload_speed_evidence_ready != 1 or gpu_speedup_claim == "deferred":
    action = "v13-real-evidence-promotion-real-gpu-speed-missing"
elif actual_nonfixture_run_verified != 1:
    action = "v13-real-evidence-promotion-nonfixture-run-missing"
elif real_evidence_promotion_ready == 1:
    action = "v13-real-evidence-promotion-ready"

if packet_dir.exists():
    shutil.rmtree(packet_dir)
packet_dir.mkdir(parents=True)

weakness_rows = [
    {
        "weakness_id": "external_benchmark",
        "diagnostic_binding_ready": diagnostic_binding_ready,
        "real_evidence_verified": int(real_external_benchmark_verified == 1),
        "required_evidence": "independent non-local public benchmark source/result/evaluator/attestation bound to the v13 run",
        "observed_evidence": f"v08_real={as_int(v08_run, 'real_external_benchmark_verified')} routeqa_real={as_int(routeqa, 'real_external_benchmark_verified')} independent_routeqa={as_int(routeqa, 'independent_external_routeqa_verified')}",
        "blocker": external_benchmark_blocker,
    },
    {
        "weakness_id": "learned_chunk_ranking",
        "diagnostic_binding_ready": diagnostic_binding_ready,
        "real_evidence_verified": learned_chunk_ranking_real_ready,
        "required_evidence": "source-verified teacher labels plus learned scorer evaluation with metric improvement",
        "observed_evidence": f"source_verified_eval={source_verified_learned_chunk_scorer_eval_ready} real_teacher_source={real_teacher_source_verified} metric_improvement={metric_improvement_ready}",
        "blocker": learned_chunk_ranking_blocker,
    },
    {
        "weakness_id": "gpu_speedup",
        "diagnostic_binding_ready": diagnostic_binding_ready,
        "real_evidence_verified": int(real_workload_speed_evidence_ready == 1 and gpu_speedup_claim != "deferred"),
        "required_evidence": "real HIP/NVMe nonfixture PC RouteLM workload timing with positive speedup",
        "observed_evidence": f"h9h_real={as_int(h9h, 'real_workload_speed_evidence_ready')} resource_real={as_int(resource, 'real_workload_speed_evidence_ready')} claim={gpu_speedup_claim}",
        "blocker": gpu_speedup_blocker,
    },
    {
        "weakness_id": "real_nlg",
        "diagnostic_binding_ready": diagnostic_binding_ready,
        "real_evidence_verified": real_pc_routelm_nlg_verified,
        "required_evidence": "nonfixture PC RouteLM generator transcript/result bound to retrieved evidence spans",
        "observed_evidence": f"h11d_real={as_int(h11d, 'real_pc_routelm_nlg_verified')} transcript_real={as_int(transcript, 'real_pc_routelm_nlg_verified')} real_transcript={as_int(transcript, 'real_nlg_transcript_ready')}",
        "blocker": real_nlg_blocker,
    },
]

weakness_csv = packet_dir / "promotion_rows.csv"
with weakness_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(weakness_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(weakness_rows)

manifest = {
    "artifact_scope": "v13-g-real-evidence-promotion-gate",
    "run_source": run_source,
    "run_dir": str(run_dir),
    "evidence_packet_dir": str(evidence_packet_dir),
    "transcript_packet_dir": str(transcript_packet_dir),
    "routeqa_packet_dir": str(routeqa_packet_dir),
    "resource_packet_dir": str(resource_packet_dir),
    "claim": "audits whether the diagnostically bound v13 run can be promoted to real evidence across benchmark, learned scorer, NLG, and GPU speed claims",
}
(packet_dir / "promotion_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

with (packet_dir / "sha256sums.txt").open("w", encoding="utf-8") as handle:
    for path in sorted(packet_dir.rglob("*")):
        if path.is_file() and path.name != "sha256sums.txt":
            handle.write(f"{sha256(path)}  {path.relative_to(packet_dir)}\n")

promotion_packet_hash_entries, promotion_packet_hash_verified = verify_manifest(packet_dir)
promotion_packet_hash_ready = int(
    promotion_packet_hash_entries > 0 and promotion_packet_hash_entries == promotion_packet_hash_verified
)
real_evidence_promotion_ready = int(real_evidence_promotion_ready == 1 and promotion_packet_hash_ready == 1)

summary_fields = [
    "promotion_scope",
    "run_source",
    "run_id",
    "run_dir",
    "promotion_packet_dir",
    "run_hash_entries",
    "run_hash_verified",
    "run_hash_manifest_ready",
    "evidence_packet_hash_ready",
    "transcript_packet_hash_ready",
    "routeqa_packet_hash_ready",
    "resource_packet_hash_ready",
    "promotion_packet_hash_entries",
    "promotion_packet_hash_verified",
    "promotion_packet_hash_ready",
    "evidence_packet_abi_ready",
    "v13_real_nlg_transcript_ready",
    "public_codebase_routeqa_ready",
    "resource_envelope_ready",
    "diagnostic_binding_ready",
    "real_external_benchmark_verified",
    "independent_external_routeqa_verified",
    "source_verified_learned_chunk_scorer_eval_ready",
    "real_teacher_source_verified",
    "metric_improvement_ready",
    "learned_chunk_ranking_real_ready",
    "real_pc_routelm_nlg_verified",
    "real_nlg_transcript_ready",
    "real_workload_speed_evidence_ready",
    "gpu_speedup_claim",
    "actual_nonfixture_run_verified",
    "external_benchmark_blocker",
    "learned_chunk_ranking_blocker",
    "gpu_speedup_blocker",
    "real_nlg_blocker",
    "nonfixture_run_blocker",
    "real_evidence_promotion_ready",
    "real_release_package_ready",
    "action",
    "routing_trigger_rate",
    "active_jump_rate",
]
summary_row = {
    "promotion_scope": "v13-g-real-evidence-promotion-gate",
    "run_source": run_source,
    "run_id": run_dir.name,
    "run_dir": str(run_dir),
    "promotion_packet_dir": str(packet_dir),
    "run_hash_entries": run_hash_entries,
    "run_hash_verified": run_hash_verified,
    "run_hash_manifest_ready": run_hash_manifest_ready,
    "evidence_packet_hash_ready": packet_ready["evidence"],
    "transcript_packet_hash_ready": packet_ready["transcript"],
    "routeqa_packet_hash_ready": packet_ready["routeqa"],
    "resource_packet_hash_ready": packet_ready["resource"],
    "promotion_packet_hash_entries": promotion_packet_hash_entries,
    "promotion_packet_hash_verified": promotion_packet_hash_verified,
    "promotion_packet_hash_ready": promotion_packet_hash_ready,
    "evidence_packet_abi_ready": evidence_packet_abi_ready,
    "v13_real_nlg_transcript_ready": v13_real_nlg_transcript_ready,
    "public_codebase_routeqa_ready": public_codebase_routeqa_ready,
    "resource_envelope_ready": resource_envelope_ready,
    "diagnostic_binding_ready": diagnostic_binding_ready,
    "real_external_benchmark_verified": real_external_benchmark_verified,
    "independent_external_routeqa_verified": as_int(routeqa, "independent_external_routeqa_verified"),
    "source_verified_learned_chunk_scorer_eval_ready": source_verified_learned_chunk_scorer_eval_ready,
    "real_teacher_source_verified": real_teacher_source_verified,
    "metric_improvement_ready": metric_improvement_ready,
    "learned_chunk_ranking_real_ready": learned_chunk_ranking_real_ready,
    "real_pc_routelm_nlg_verified": real_pc_routelm_nlg_verified,
    "real_nlg_transcript_ready": as_int(transcript, "real_nlg_transcript_ready"),
    "real_workload_speed_evidence_ready": real_workload_speed_evidence_ready,
    "gpu_speedup_claim": gpu_speedup_claim,
    "actual_nonfixture_run_verified": actual_nonfixture_run_verified,
    "external_benchmark_blocker": external_benchmark_blocker,
    "learned_chunk_ranking_blocker": learned_chunk_ranking_blocker,
    "gpu_speedup_blocker": gpu_speedup_blocker,
    "real_nlg_blocker": real_nlg_blocker,
    "nonfixture_run_blocker": nonfixture_run_blocker,
    "real_evidence_promotion_ready": real_evidence_promotion_ready,
    "real_release_package_ready": 1 if real_evidence_promotion_ready else 0,
    "action": action,
    "routing_trigger_rate": f"{as_float(evidence, 'routing_trigger_rate') + as_float(transcript, 'routing_trigger_rate') + as_float(routeqa, 'routing_trigger_rate') + as_float(resource, 'routing_trigger_rate'):.6f}",
    "active_jump_rate": f"{as_float(evidence, 'active_jump_rate') + as_float(transcript, 'active_jump_rate') + as_float(routeqa, 'active_jump_rate') + as_float(resource, 'active_jump_rate'):.6f}",
}
with summary_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=summary_fields, lineterminator="\n")
    writer.writeheader()
    writer.writerow(summary_row)

def status(condition):
    return "pass" if condition else "blocked"

decision_rows = [
    ("diagnostic-binding", status(diagnostic_binding_ready == 1), f"evidence={evidence_packet_abi_ready} transcript={v13_real_nlg_transcript_ready} routeqa={public_codebase_routeqa_ready} resource={resource_envelope_ready}"),
    ("external-benchmark", status(real_external_benchmark_verified == 1), weakness_rows[0]["observed_evidence"]),
    ("learned-chunk-ranking", status(learned_chunk_ranking_real_ready == 1), weakness_rows[1]["observed_evidence"]),
    ("real-nlg", status(real_pc_routelm_nlg_verified == 1), weakness_rows[3]["observed_evidence"]),
    ("gpu-speedup", status(gpu_speedup_blocker == 0), weakness_rows[2]["observed_evidence"]),
    ("nonfixture-run", status(actual_nonfixture_run_verified == 1), f"run_source={run_source} fixture_or_generated={v13_manifest.get('fixture_or_generated_declared', '1')}"),
    ("promotion-packet-hash", status(promotion_packet_hash_ready == 1), f"verified={promotion_packet_hash_verified}/{promotion_packet_hash_entries}"),
    ("v13-real-evidence-promotion", status(real_evidence_promotion_ready == 1), f"ready={real_evidence_promotion_ready} action={action}"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "promotion_packet_dir: $PACKET_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
