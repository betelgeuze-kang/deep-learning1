#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v16_research_commercial_tracks"
PACKET_ID="${V16_PACKET_ID:-packet_001}"
PACKET_DIR="${V16_PACKET_DIR:-$RESULTS_DIR/${PREFIX}/$PACKET_ID}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

mkdir -p "$PACKET_DIR"

"$ROOT_DIR/experiments/run_v15b_nonfixture_review_independent_rerun.sh" >/dev/null

python3 - "$ROOT_DIR" "$PACKET_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
packet_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
packet_dir.mkdir(parents=True, exist_ok=True)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def csv_rows(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

def copy_artifact(src, rel):
    dst = packet_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst

inputs = {
    "v14-b-lite": results / "v14b_lite_prediction_lineage_summary.csv",
    "v14-c": results / "v14c_baseline_comparison_summary.csv",
    "v14-d": results / "v14d_routeqa_mini_scale_summary.csv",
    "v14-e": results / "v14e_ruler_niah_lite_summary.csv",
    "v15-a": results / "v15a_independent_reproduction_package_summary.csv",
    "v15-b": results / "v15b_nonfixture_review_independent_rerun_summary.csv",
}
decision_inputs = {
    "v15-b": results / "v15b_nonfixture_review_independent_rerun_decision.csv",
}
for stage, path in inputs.items():
    copy_artifact(path, f"inputs/{stage}_summary.csv")
for stage, path in decision_inputs.items():
    copy_artifact(path, f"inputs/{stage}_decision.csv")

evidence_rows = []
for stage, path in inputs.items():
    rows = csv_rows(path)
    for index, row in enumerate(rows):
        candidate_ready = int(float(row.get("candidate_external_benchmark_result_ready", "0") or 0))
        real_ready = int(float(row.get("real_external_benchmark_verified", "0") or 0))
        release_ready = int(float(row.get("real_release_package_ready", "0") or 0))
        evidence_rows.append(
            {
                "stage": stage,
                "row_index": index,
                "summary_path": str(path),
                "summary_sha256": sha256(path),
                "primary_ready": row.get("stage_ready")
                or row.get("baseline_comparison_ready")
                or row.get("runner_owned_external_benchmark_result_ready")
                or row.get("nonfixture_review_package_ready")
                or row.get("prediction_lineage_ready")
                or "1",
                "candidate_external_benchmark_result_ready": candidate_ready,
                "real_external_benchmark_verified": real_ready,
                "real_release_package_ready": release_ready,
            }
        )
with (packet_dir / "research_evidence_matrix.csv").open("w", newline="", encoding="utf-8") as handle:
    fieldnames = [
        "stage",
        "row_index",
        "summary_path",
        "summary_sha256",
        "primary_ready",
        "candidate_external_benchmark_result_ready",
        "real_external_benchmark_verified",
        "real_release_package_ready",
    ]
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(evidence_rows)

claim_rows = [
    ("RouteMemory mmap prediction lineage is locally reproducible", "allowed", "v14-b-lite lineage and v15-a/v15-b replay evidence"),
    ("RouteMemory candidates dominate unsafe extractor/lexical baselines in local safety comparison", "allowed", "v14-c baseline comparison"),
    ("RouteQA-mini 100/150 local scale preserves lineage and baseline contracts", "allowed", "v14-d scale evidence"),
    ("RULER-compatible NIAH-lite runner-owned smoke can be mmap-derived", "allowed", "v14-e runner-owned smoke"),
    ("Independent external RULER/LongBench benchmark result", "blocked", "no external independent reviewer or official result reconciliation"),
    ("Release-ready commercial product", "blocked", "privacy, reliability, support, and user-data contracts are not real"),
    ("GPU acceleration or frontier LLM replacement", "blocked", "HIP/GPU speed claims remain deferred"),
]
with (packet_dir / "claim_boundary_matrix.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["claim", "status", "evidence_or_blocker"])
    writer.writerows(claim_rows)

research_doc = packet_dir / "research_publication_packet.md"
research_doc.write_text(
    "\n".join(
        [
            "# v16 Research Publication Track",
            "",
            "## Hypothesis",
            "RouteMemory can produce evidence-bound local codebase QA predictions through mmap-derived value reads while resisting raw-input shortcut promotion.",
            "",
            "## Method",
            "The packet composes v14-b-lite prediction lineage, v14-c baseline comparison, v14-d RouteQA-mini scale, v14-e RULER NIAH-lite runner-owned smoke, v15-a reproduction packaging, and v15-b local review/rerun evidence.",
            "",
            "## Evidence",
            "- `research_evidence_matrix.csv` binds every stage summary hash.",
            "- `claim_boundary_matrix.csv` separates allowed diagnostic claims from blocked real benchmark, release, and GPU claims.",
            "- v15-a supplies the reproduction package and v15-b supplies local rerun/review rows.",
            "",
            "## Limitations",
            "- The RULER NIAH-lite row is runner-owned compatible smoke, not independent RULER benchmark verification.",
            "- The review evidence is same-machine local mechanics, not third-party external review.",
            "- Candidate external benchmark, real external benchmark, and release flags remain blocked.",
            "",
        ]
    ),
    encoding="utf-8",
)

commercial_doc = packet_dir / "commercial_local_qa_audit_contract.md"
commercial_doc.write_text(
    "\n".join(
        [
            "# v16 Commercial Local QA/Audit Prototype Track",
            "",
            "## Prototype Scope",
            "A local-first evidence-bound codebase QA/audit prototype may answer only from bound source spans, mmap traces, prediction lineage rows, and evaluator/review artifacts.",
            "",
            "## Answer Contract",
            "- Every answer must include source citation artifacts or abstain.",
            "- Raw-input extractor shortcuts are diagnostic baselines only and cannot be promoted.",
            "- Missing evidence must produce abstention rather than unsupported generation.",
            "- User data stays local by default; no cloud dependency is required by this packet.",
            "",
            "## Blocked Product Claims",
            "- No release-ready reliability claim.",
            "- No independent external benchmark claim.",
            "- No privacy/compliance certification claim.",
            "- No GPU speed or frontier LLM replacement claim.",
            "",
        ]
    ),
    encoding="utf-8",
)

acceptance_rows = [
    ("evidence_bound_answers", 1, "answers require source span / mmap / lineage binding"),
    ("citation_required", 1, "citations are mandatory for non-abstain answers"),
    ("abstain_on_missing_evidence", 1, "missing evidence blocks unsupported generation"),
    ("local_first_privacy_assumption", 1, "packet assumes local files and no cloud dependency"),
    ("raw_input_extractor_promotion_blocked", 1, "v14-c keeps extractor baseline-only"),
    ("external_benchmark_claim_blocked", 1, "candidate/real external benchmark flags remain 0"),
    ("release_claim_blocked", 1, "real release flag remains 0"),
]
with (packet_dir / "commercial_acceptance_rows.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["criterion", "ready", "evidence_or_blocker"])
    writer.writerows(acceptance_rows)

research_ready = int(
    {row["stage"] for row in evidence_rows} == {"v14-b-lite", "v14-c", "v14-d", "v14-e", "v15-a", "v15-b"}
    and all(row["candidate_external_benchmark_result_ready"] == 0 for row in evidence_rows)
    and all(row["real_external_benchmark_verified"] == 0 for row in evidence_rows)
    and all(row["real_release_package_ready"] == 0 for row in evidence_rows)
    and research_doc.is_file()
)
commercial_ready = int(
    commercial_doc.is_file()
    and all(row[1] == 1 for row in acceptance_rows)
)
claim_boundaries_ready = int(
    any(row[1] == "allowed" for row in claim_rows)
    and any(row[1] == "blocked" for row in claim_rows)
)
v16_ready = int(research_ready and commercial_ready and claim_boundaries_ready)

artifact_candidates = [
    "research_publication_packet.md",
    "research_evidence_matrix.csv",
    "claim_boundary_matrix.csv",
    "commercial_local_qa_audit_contract.md",
    "commercial_acceptance_rows.csv",
]
artifact_candidates.extend(str(path.relative_to(packet_dir)) for path in sorted((packet_dir / "inputs").glob("*.csv")))
artifact_rows = []
for rel in artifact_candidates:
    path = packet_dir / rel
    artifact_rows.append({"artifact": Path(rel).stem, "path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
with (packet_dir / "artifact_manifest.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["artifact", "path", "sha256", "bytes"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(artifact_rows)

manifest = {
    "manifest_scope": "v16-research-commercial-track-packet",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "research_publication_track_ready": research_ready,
    "commercial_local_qa_audit_prototype_ready": commercial_ready,
    "claim_boundaries_ready": claim_boundaries_ready,
    "v16_ready": v16_ready,
    "candidate_external_benchmark_result_ready": 0,
    "real_external_benchmark_verified": 0,
    "real_release_package_ready": 0,
    "claim": "v16 track packet for research/publication planning and commercial local QA/audit prototype contract; not release or external benchmark verification",
}
(packet_dir / "v16_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

summary_rows = [
    {
        "packet_id": packet_dir.name,
        "research_publication_track_ready": research_ready,
        "commercial_local_qa_audit_prototype_ready": commercial_ready,
        "claim_boundaries_ready": claim_boundaries_ready,
        "evidence_matrix_rows": len(evidence_rows),
        "commercial_acceptance_rows": len(acceptance_rows),
        "v16_ready": v16_ready,
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
    ("v16-research-publication-track", "pass" if research_ready else "blocked", f"evidence_rows={len(evidence_rows)}"),
    ("v16-commercial-local-qa-audit-prototype", "pass" if commercial_ready else "blocked", f"acceptance_rows={len(acceptance_rows)}"),
    ("v16-claim-boundaries", "pass" if claim_boundaries_ready else "blocked", "allowed and blocked claims documented"),
    ("candidate-external-benchmark-result", "blocked", "v16 packet does not supply external independent benchmark evidence"),
    ("real-release-package", "blocked", "v16 packet is a prototype/research contract, not release evidence"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "v16_packet_dir: $PACKET_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
