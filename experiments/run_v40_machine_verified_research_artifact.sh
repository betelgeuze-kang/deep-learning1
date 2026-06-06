#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v40_machine_verified_research_artifact"
ARTIFACT_ID="${V40_ARTIFACT_ID:-artifact_001}"
ARTIFACT_DIR="${V40_ARTIFACT_DIR:-$RESULTS_DIR/${PREFIX}/$ARTIFACT_ID}"
DEFAULT_V36_PACKET_DIR="$RESULTS_DIR/v36_release_claim_audit_packet/packet_001"
DEFAULT_V37_INTAKE_DIR="$RESULTS_DIR/v37_human_review_intake/intake_001"
DEFAULT_V38_BUNDLE_DIR="$RESULTS_DIR/v38_human_review_dispatch_bundle/bundle_001"
DEFAULT_V39_ARCHIVE_DIR="$RESULTS_DIR/v39_human_review_dispatch_archive/archive_001"
V36_PACKET_DIR="${V40_V36_PACKET_DIR:-$DEFAULT_V36_PACKET_DIR}"
V37_INTAKE_DIR="${V40_V37_INTAKE_DIR:-$DEFAULT_V37_INTAKE_DIR}"
V38_BUNDLE_DIR="${V40_V38_BUNDLE_DIR:-$DEFAULT_V38_BUNDLE_DIR}"
V39_ARCHIVE_DIR="${V40_V39_ARCHIVE_DIR:-$DEFAULT_V39_ARCHIVE_DIR}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [ ! -f "$V39_ARCHIVE_DIR/human_review_dispatch_archive_manifest.json" ]; then
  "$ROOT_DIR/experiments/run_v39_human_review_dispatch_archive.sh" >/dev/null
fi

mkdir -p "$ARTIFACT_DIR"

python3 - "$ROOT_DIR" "$ARTIFACT_DIR" "$V36_PACKET_DIR" "$V37_INTAKE_DIR" "$V38_BUNDLE_DIR" "$V39_ARCHIVE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
artifact_dir = Path(sys.argv[2])
v36_packet_dir = Path(sys.argv[3])
v37_intake_dir = Path(sys.argv[4])
v38_bundle_dir = Path(sys.argv[5])
v39_archive_dir = Path(sys.argv[6])
summary_csv = Path(sys.argv[7])
decision_csv = Path(sys.argv[8])
results_dir = root / "results"

if artifact_dir.exists():
    shutil.rmtree(artifact_dir)
artifact_dir.mkdir(parents=True)
evidence_dir = artifact_dir / "evidence"
evidence_dir.mkdir(parents=True)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

def read_csv_one(path):
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 1:
        raise SystemExit(f"expected one row in {path}, got {len(rows)}")
    return rows[0]

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

def rel(path):
    return str(path.relative_to(root))

def copy_file(src, dst):
    if not src.is_file():
        raise SystemExit(f"missing required source file: {src}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst

required_inputs = {
    "v36/RELEASE_CLAIM_AUDIT.md": v36_packet_dir / "RELEASE_CLAIM_AUDIT.md",
    "v36/claim_matrix.csv": v36_packet_dir / "claim_matrix.csv",
    "v36/release_decision_rows.csv": v36_packet_dir / "release_decision_rows.csv",
    "v36/evidence_input_rows.csv": v36_packet_dir / "evidence_input_rows.csv",
    "v36/v36_release_claim_audit_manifest.json": v36_packet_dir / "v36_release_claim_audit_manifest.json",
    "v36/summary.csv": results_dir / "v36_release_claim_audit_packet_summary.csv",
    "v36/decision.csv": results_dir / "v36_release_claim_audit_packet_decision.csv",
    "support/v33_summary.csv": results_dir / "v33_evidence_closure_packet_summary.csv",
    "support/v34_summary.csv": results_dir / "v34_official_benchmark_expansion_packet_summary.csv",
    "support/v35_summary.csv": results_dir / "v35_commercial_pilot_packet_summary.csv",
    "v37/human_review_intake_manifest.json": v37_intake_dir / "human_review_intake_manifest.json",
    "v37/missing_review_rows.csv": v37_intake_dir / "missing_review_rows.csv",
    "v37/summary.csv": results_dir / "v37_human_review_intake_summary.csv",
    "v37/decision.csv": results_dir / "v37_human_review_intake_decision.csv",
    "v38/HUMAN_REVIEW_DISPATCH_README.md": v38_bundle_dir / "HUMAN_REVIEW_DISPATCH_README.md",
    "v38/human_review_dispatch_manifest.json": v38_bundle_dir / "human_review_dispatch_manifest.json",
    "v38/summary.csv": results_dir / "v38_human_review_dispatch_bundle_summary.csv",
    "v38/decision.csv": results_dir / "v38_human_review_dispatch_bundle_decision.csv",
    "v39/SEND_ARCHIVE_README.md": v39_archive_dir / "SEND_ARCHIVE_README.md",
    "v39/human_review_dispatch_archive_manifest.json": v39_archive_dir / "human_review_dispatch_archive_manifest.json",
    "v39/artifact_manifest.csv": v39_archive_dir / "artifact_manifest.csv",
    "v39/summary.csv": results_dir / "v39_human_review_dispatch_archive_summary.csv",
    "v39/decision.csv": results_dir / "v39_human_review_dispatch_archive_decision.csv",
}
for dst_rel, src in required_inputs.items():
    copy_file(src, evidence_dir / dst_rel)

v36_manifest = read_json(v36_packet_dir / "v36_release_claim_audit_manifest.json")
v37_manifest = read_json(v37_intake_dir / "human_review_intake_manifest.json")
v38_manifest = read_json(v38_bundle_dir / "human_review_dispatch_manifest.json")
v39_manifest = read_json(v39_archive_dir / "human_review_dispatch_archive_manifest.json")
v36_summary = read_csv_one(results_dir / "v36_release_claim_audit_packet_summary.csv")
v37_summary = read_csv_one(results_dir / "v37_human_review_intake_summary.csv")
v38_summary = read_csv_one(results_dir / "v38_human_review_dispatch_bundle_summary.csv")
v39_summary = read_csv_one(results_dir / "v39_human_review_dispatch_archive_summary.csv")
v33_summary = read_csv_one(results_dir / "v33_evidence_closure_packet_summary.csv")
v34_summary = read_csv_one(results_dir / "v34_official_benchmark_expansion_packet_summary.csv")
v35_summary = read_csv_one(results_dir / "v35_commercial_pilot_packet_summary.csv")

v36_ready = int(v36_summary.get("v36_release_claim_audit_packet_ready") == "1" and v36_manifest.get("maximum_allowed_claim_decided") == 1)
v37_ready = int(v37_summary.get("v37_human_review_intake_ready") == "1" and v37_manifest.get("v36_release_claim_audit_packet_ready") == 1)
v38_ready = int(v38_summary.get("v38_human_review_dispatch_bundle_ready") == "1" and v38_manifest.get("human_review_dispatch_bundle_ready") == 1)
v39_ready = int(v39_summary.get("v39_human_review_dispatch_archive_ready") == "1" and v39_manifest.get("human_review_dispatch_archive_ready") == 1)
human_review_completed = int(v37_summary.get("human_review_completed", "0") == "1")
real_release_package_ready = 0
human_review_required_for_public_release = 1
automated_research_artifact_ready = int(v36_ready and v37_ready and v38_ready and v39_ready and not human_review_completed)
machine_verified_prototype_ready = automated_research_artifact_ready

allowed_claim = "local evidence-bound QA/audit architecture with deterministic provenance, source-cited answers, conservative abstention, and externally reproducible evidence packets"
notice = "This artifact is machine-verified and externally reproducible through the v18 evidence-intake path, but it is not a human-reviewed release package."

source_claim_rows = read_csv(v36_packet_dir / "claim_matrix.csv")
blocked_claim_ids = [
    "human-reviewed-release",
    "production-ready-product",
    "release-ready-product",
    "general-llm-replacement",
    "transformer-replacement",
    "frontier-local-llm",
    "frontier-long-context-solved",
    "gpu-acceleration-proven",
    "full-commercial-deployment-ready",
]
blocked_rows = []
for claim_id in blocked_claim_ids:
    source = next((row for row in source_claim_rows if row.get("claim_id") == claim_id), None)
    blocked_rows.append(
        {
            "claim_id": claim_id,
            "allowed": 0,
            "status": "blocked",
            "source_gate": "v36" if source else "v40",
            "reason": (source or {}).get("reason", "not supported without completed human review and release-readiness evidence"),
        }
    )
write_csv(artifact_dir / "blocked_claim_rows.csv", ["claim_id", "allowed", "status", "source_gate", "reason"], blocked_rows)

allowed_rows = [
    {
        "claim_id": "machine-verified-research-artifact",
        "allowed": 1,
        "status": "allowed_limited",
        "public_wording": "machine-verified research artifact for local evidence-bound QA/audit",
        "reason": "v33-v39 evidence chain is present and hash-manifested while human review remains incomplete",
    },
    {
        "claim_id": "bounded-local-qa-audit-architecture",
        "allowed": 1,
        "status": "allowed_limited",
        "public_wording": allowed_claim,
        "reason": "inherits the maximum allowed v36 wording",
    },
]
write_csv(artifact_dir / "allowed_claim_rows.csv", ["claim_id", "allowed", "status", "public_wording", "reason"], allowed_rows)

machine_verification_rows = [
    {
        "support_id": "github-actions-clean-runner-rerun",
        "ready": int(v33_summary.get("independent_rerun_actual_ready") == "1"),
        "source": "v33_evidence_closure_packet_summary.csv",
        "evidence_field": "independent_rerun_actual_ready",
        "claim_scope": "CI-clean-runner reproducible evidence packet",
    },
    {
        "support_id": "v18-external-evidence-intake",
        "ready": int(v33_summary.get("real_external_benchmark_verified") == "1"),
        "source": "v33_evidence_closure_packet_summary.csv",
        "evidence_field": "real_external_benchmark_verified",
        "claim_scope": "v18 external evidence intake verified",
    },
    {
        "support_id": "routememory-prediction-lineage",
        "ready": int(v34_summary.get("route_memory_prediction_lineage_ready") == "1"),
        "source": "v34_official_benchmark_expansion_packet_summary.csv",
        "evidence_field": "route_memory_prediction_lineage_ready",
        "claim_scope": "RouteMemory-derived prediction lineage included",
    },
    {
        "support_id": "no-oracle-no-extractor-contract",
        "ready": int(v34_summary.get("oracle_prediction_used") == "0" and v34_summary.get("raw_input_extractor_used") == "0"),
        "source": "v34_official_benchmark_expansion_packet_summary.csv",
        "evidence_field": "oracle_prediction_used=0;raw_input_extractor_used=0",
        "claim_scope": "no-oracle / no-raw-input-extractor contract included",
    },
    {
        "support_id": "commercial-poc-preview",
        "ready": int(v35_summary.get("closed_corpus_poc_actual_ready") == "1" and v35_summary.get("acceptance_rows", "0").isdigit() and int(v35_summary.get("acceptance_rows", "0")) > 0),
        "source": "v35_commercial_pilot_packet_summary.csv",
        "evidence_field": "closed_corpus_poc_actual_ready;acceptance_rows",
        "claim_scope": "private/commercial closed-corpus QA/audit PoC preview",
    },
]
write_csv(artifact_dir / "machine_verification_rows.csv", ["support_id", "ready", "source", "evidence_field", "claim_scope"], machine_verification_rows)
machine_verification_ready = int(all(row["ready"] == 1 for row in machine_verification_rows))
automated_research_artifact_ready = int(automated_research_artifact_ready and machine_verification_ready)
machine_verified_prototype_ready = automated_research_artifact_ready

release_mode_rows = [
    {
        "release_mode": "machine_verified_research_artifact",
        "automated_research_artifact_ready": automated_research_artifact_ready,
        "machine_verified_prototype_ready": machine_verified_prototype_ready,
        "human_review_completed": human_review_completed,
        "human_review_required_for_public_release": human_review_required_for_public_release,
        "real_release_package_ready": real_release_package_ready,
        "allowed_claim": allowed_claim,
        "notice": notice,
    }
]
write_csv(
    artifact_dir / "release_mode_rows.csv",
    [
        "release_mode",
        "automated_research_artifact_ready",
        "machine_verified_prototype_ready",
        "human_review_completed",
        "human_review_required_for_public_release",
        "real_release_package_ready",
        "allowed_claim",
        "notice",
    ],
    release_mode_rows,
)

evidence_rows = [
    {
        "evidence_id": "v33-evidence-closure",
        "path": "results/v33_evidence_closure_packet/packet_001",
        "ready": int(v33_summary.get("v33_evidence_closure_packet_ready") == "1"),
        "role": "GitHub Actions clean-runner return plus v18 evidence intake closure",
    },
    {
        "evidence_id": "v34-official-benchmark-expansion",
        "path": "results/v34_official_benchmark_expansion_packet/packet_001",
        "ready": int(v34_summary.get("v34_official_benchmark_expansion_packet_ready") == "1"),
        "role": "RouteMemory lineage and no-oracle/no-extractor official benchmark expansion",
    },
    {
        "evidence_id": "v35-commercial-pilot",
        "path": "results/v35_commercial_pilot_packet/packet_001",
        "ready": int(v35_summary.get("v35_commercial_pilot_packet_ready") == "1"),
        "role": "closed-corpus commercial QA/audit preview evidence",
    },
    {
        "evidence_id": "v36-release-claim-audit",
        "path": rel(v36_packet_dir),
        "ready": v36_ready,
        "role": "maximum allowed claim and blocked claim matrix",
    },
    {
        "evidence_id": "v37-human-review-intake",
        "path": rel(v37_intake_dir),
        "ready": v37_ready,
        "role": "default no-return human review intake state",
    },
    {
        "evidence_id": "v38-human-review-dispatch-bundle",
        "path": rel(v38_bundle_dir),
        "ready": v38_ready,
        "role": "optional human review dispatch bundle",
    },
    {
        "evidence_id": "v39-human-review-dispatch-archive",
        "path": rel(v39_archive_dir),
        "ready": v39_ready,
        "role": "optional human review transfer archive",
    },
]
write_csv(artifact_dir / "evidence_index.csv", ["evidence_id", "path", "ready", "role"], evidence_rows)

readme = artifact_dir / "MACHINE_VERIFIED_RESEARCH_ARTIFACT.md"
readme.write_text(
    "\n".join(
        [
            "# v40 Machine-Verified Research Artifact",
            "",
            notice,
            "",
            "Allowed public wording:",
            "",
            f"- {allowed_claim}.",
            "- Machine-verified research artifact for local evidence-bound QA/audit.",
            "- CI-clean-runner reproducible, v18 evidence-intake verified, RouteMemory-lineage bound, and no-oracle/no-extractor bounded evidence packet.",
            "",
            "Required boundary:",
            "",
            "- `automated_research_artifact_ready=1` is allowed.",
            "- `human_review_completed=0` remains explicit.",
            "- `real_release_package_ready=0` remains explicit.",
            "- Human review remains available through the v39 archive and v37 intake verifier.",
            "",
            "Forbidden wording:",
            "",
            "- Human-reviewed release.",
            "- Production-ready or real release package.",
            "- Transformer replacement or general LLM replacement.",
            "- Frontier local LLM or frontier long-context solved.",
            "- GPU acceleration proven.",
            "- Full commercial deployment readiness.",
            "",
            "Verification:",
            "",
            "```bash",
            "experiments/test_v40_machine_verified_research_artifact.sh",
            "```",
            "",
            "If an external reviewer later returns `human_review_rows.csv`, verify it through v37 before changing any release wording.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v40-machine-verified-research-artifact",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "artifact_id": artifact_dir.name,
    "v36_packet_dir": rel(v36_packet_dir),
    "v37_intake_dir": rel(v37_intake_dir),
    "v38_bundle_dir": rel(v38_bundle_dir),
    "v39_archive_dir": rel(v39_archive_dir),
    "v36_release_claim_audit_packet_ready": v36_ready,
    "v37_human_review_intake_ready": v37_ready,
    "v38_human_review_dispatch_bundle_ready": v38_ready,
    "v39_human_review_dispatch_archive_ready": v39_ready,
    "machine_verification_ready": machine_verification_ready,
    "automated_research_artifact_ready": automated_research_artifact_ready,
    "machine_verified_prototype_ready": machine_verified_prototype_ready,
    "human_review_completed": human_review_completed,
    "human_review_required_for_public_release": human_review_required_for_public_release,
    "real_release_package_ready": real_release_package_ready,
    "allowed_claim": allowed_claim,
    "notice": notice,
}
write_json(artifact_dir / "v40_machine_verified_research_artifact_manifest.json", manifest)

artifact_rows = []
for artifact in [
    readme,
    artifact_dir / "release_mode_rows.csv",
    artifact_dir / "allowed_claim_rows.csv",
    artifact_dir / "blocked_claim_rows.csv",
    artifact_dir / "machine_verification_rows.csv",
    artifact_dir / "evidence_index.csv",
    artifact_dir / "v40_machine_verified_research_artifact_manifest.json",
]:
    artifact_rows.append({"artifact": artifact.stem, "path": rel(artifact), "sha256": sha256(artifact), "bytes": artifact.stat().st_size})
write_csv(artifact_dir / "artifact_manifest.csv", ["artifact", "path", "sha256", "bytes"], artifact_rows)

sha_rows = []
for path in sorted(artifact_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(artifact_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(artifact_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary_rows = [
    {
        "artifact_id": artifact_dir.name,
        "v40_machine_verified_research_artifact_ready": automated_research_artifact_ready,
        "automated_research_artifact_ready": automated_research_artifact_ready,
        "machine_verified_prototype_ready": machine_verified_prototype_ready,
        "v36_release_claim_audit_packet_ready": v36_ready,
        "v37_human_review_intake_ready": v37_ready,
        "v38_human_review_dispatch_bundle_ready": v38_ready,
        "v39_human_review_dispatch_archive_ready": v39_ready,
        "machine_verification_ready": machine_verification_ready,
        "human_review_completed": human_review_completed,
        "human_review_required_for_public_release": human_review_required_for_public_release,
        "real_release_package_ready": real_release_package_ready,
        "allowed_claim_rows": len(allowed_rows),
        "blocked_claim_rows": len(blocked_rows),
        "machine_verification_rows": len(machine_verification_rows),
        "artifact_rows": len(sha_rows),
    }
]
write_csv(summary_csv, list(summary_rows[0]), summary_rows)

def status(ok):
    return "pass" if ok else "blocked"

decision_rows = [
    {"gate": "v40-machine-verified-research-artifact", "status": status(automated_research_artifact_ready), "reason": "automated evidence mode is ready" if automated_research_artifact_ready else "one or more evidence gates are incomplete"},
    {"gate": "v36-release-claim-audit", "status": status(v36_ready), "reason": "bounded claim audit is ready"},
    {"gate": "v37-human-review-intake", "status": status(v37_ready), "reason": "human review intake verifier is ready"},
    {"gate": "v38-dispatch-bundle", "status": status(v38_ready), "reason": "optional human review dispatch bundle is ready"},
    {"gate": "v39-dispatch-archive", "status": status(v39_ready), "reason": "optional human review transfer archive is ready"},
    {"gate": "machine-verification-support", "status": status(machine_verification_ready), "reason": "clean-runner, v18, lineage, no-oracle, and PoC preview support rows are ready"},
    {"gate": "automated-research-artifact", "status": status(automated_research_artifact_ready), "reason": "machine-verifiable research artifact may be shared with bounded wording"},
    {"gate": "human-reviewed-release", "status": "blocked", "reason": "human_review_completed remains 0"},
    {"gate": "real-release-package", "status": "blocked", "reason": "real_release_package_ready remains 0"},
    {"gate": "production-readiness", "status": "blocked", "reason": "production and full commercial deployment claims remain out of scope"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)
PY

echo "v40_machine_verified_research_artifact_dir: $ARTIFACT_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
