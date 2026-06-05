#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v25_outbound_send_manifest"
PACKET_ID="${V25_PACKET_ID:-packet_001}"
PACKET_DIR="${V25_PACKET_DIR:-$RESULTS_DIR/${PREFIX}/$PACKET_ID}"
V21_DISPATCH_DIR="${V21_DISPATCH_DIR:-$RESULTS_DIR/v21_external_review_dispatch_kit/dispatch_001}"
V22_KIT_DIR="${V22_KIT_DIR:-$RESULTS_DIR/v22_clean_machine_execution_kit/kit_001}"
V24_HANDOFF_DIR="${V24_HANDOFF_DIR:-$RESULTS_DIR/v24_external_handoff_send_receive_verify/handoff_001}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

mkdir -p "$PACKET_DIR"

"$ROOT_DIR/experiments/run_v24_external_handoff_send_receive_verify.sh" >/dev/null

python3 - "$ROOT_DIR" "$PACKET_DIR" "$V21_DISPATCH_DIR" "$V22_KIT_DIR" "$V24_HANDOFF_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
packet_dir = Path(sys.argv[2])
v21_dispatch_dir = Path(sys.argv[3])
v22_kit_dir = Path(sys.argv[4])
v24_handoff_dir = Path(sys.argv[5])
summary_csv = Path(sys.argv[6])
decision_csv = Path(sys.argv[7])
packet_dir.mkdir(parents=True, exist_ok=True)

def ensure(path):
    path.mkdir(parents=True, exist_ok=True)
    return path

for folder in ["outbound", "receiver", "verify", "source_manifests"]:
    ensure(packet_dir / folder)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def copy(src, rel):
    dst = packet_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst

def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

def bool_int(value):
    return int(str(value).strip().lower() in {"1", "true", "yes", "ready", "pass"})

v21_manifest = read_json(v21_dispatch_dir / "dispatch_manifest.json")
v22_manifest = read_json(v22_kit_dir / "clean_machine_execution_manifest.json")
v24_manifest = read_json(v24_handoff_dir / "handoff_manifest.json")

copy(v21_dispatch_dir / "dispatch_manifest.json", "source_manifests/v21_dispatch_manifest.json")
copy(v22_kit_dir / "clean_machine_execution_manifest.json", "source_manifests/v22_clean_machine_execution_manifest.json")
copy(v24_handoff_dir / "handoff_manifest.json", "source_manifests/v24_handoff_manifest.json")
copy(v24_handoff_dir / "handoff_rows.csv", "source_manifests/v24_handoff_rows.csv")

send_roots = [
    ("v21_dispatch_kit", v21_dispatch_dir),
    ("v22_clean_machine_execution_kit", v22_kit_dir),
]
outbound_rows = []
for packet_name, source_dir in send_roots:
    for path in sorted(source_dir.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(root)
        outbound_rows.append(
            {
                "packet": packet_name,
                "path": str(rel),
                "sha256": sha256(path),
                "bytes": path.stat().st_size,
            }
        )

with (packet_dir / "outbound" / "OUTBOUND_FILE_MANIFEST.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["packet", "path", "sha256", "bytes"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(outbound_rows)

with (packet_dir / "outbound" / "OUTBOUND_SHA256SUMS.txt").open("w", encoding="utf-8") as handle:
    for row in outbound_rows:
        handle.write(f"{row['sha256'].replace('sha256:', '')}  {row['path']}\n")

(packet_dir / "outbound" / "SEND_INSTRUCTIONS.md").write_text(
    "\n".join(
        [
            "# Outbound Send Instructions",
            "",
            "Send these directories to the external reviewer, benchmark runner, or PoC owner:",
            "",
            "- `results/v21_external_review_dispatch_kit/dispatch_001/`",
            "- `results/v22_clean_machine_execution_kit/kit_001/`",
            "",
            "Include this v25 outbound manifest so the receiver can verify that the packet arrived intact.",
            "",
            "Receiver-side integrity check:",
            "",
            "```bash",
            "sha256sum -c results/v25_outbound_send_manifest/packet_001/outbound/OUTBOUND_SHA256SUMS.txt",
            "```",
            "",
            "The send packet does not claim external validation. It only prepares the outward handoff.",
            "",
        ]
    ),
    encoding="utf-8",
)

(packet_dir / "receiver" / "RECEIVER_ACK_TEMPLATE.csv").write_text(
    "\n".join(
        [
            "receiver_name,receiver_org,receiver_contact,received_v21_dispatch_kit,received_v22_clean_machine_execution_kit,sha256_manifest_checked,ack_timestamp_utc,notes",
            ",,,0,0,0,,",
        ]
    ),
    encoding="utf-8",
)

(packet_dir / "receiver" / "RETURN_OPTIONS.md").write_text(
    "\n".join(
        [
            "# Return Options",
            "",
            "Return one or more of the following directories:",
            "",
            "1. `third_party_return/` for `independent_rerun_actual_ready=1`.",
            "2. `official_return/` for `candidate_external_benchmark_result_ready=1` candidate evidence.",
            "3. `commercial_return/` for `closed_corpus_poc_actual_ready=1` candidate evidence.",
            "",
            "A single valid return directory is useful. All three do not need to arrive together.",
            "",
        ]
    ),
    encoding="utf-8",
)

(packet_dir / "verify" / "VERIFY_RETURN_WITH_V18.md").write_text(
    "\n".join(
        [
            "# Verify Return With v18",
            "",
            "Third-party rerun:",
            "",
            "```bash",
            "V18_THIRD_PARTY_RERUN_DIR=/path/to/third_party_return experiments/run_v18_external_evidence_intake.sh",
            "```",
            "",
            "Official benchmark reconciliation:",
            "",
            "```bash",
            "V18_OFFICIAL_BENCHMARK_DIR=/path/to/official_return experiments/run_v18_external_evidence_intake.sh",
            "```",
            "",
            "Commercial closed-corpus PoC:",
            "",
            "```bash",
            "V18_COMMERCIAL_POC_DIR=/path/to/commercial_return experiments/run_v18_external_evidence_intake.sh",
            "```",
            "",
            "Combined:",
            "",
            "```bash",
            "V18_THIRD_PARTY_RERUN_DIR=/path/to/third_party_return \\",
            "V18_OFFICIAL_BENCHMARK_DIR=/path/to/official_return \\",
            "V18_COMMERCIAL_POC_DIR=/path/to/commercial_return \\",
            "experiments/run_v18_external_evidence_intake.sh",
            "```",
            "",
        ]
    ),
    encoding="utf-8",
)

outbound_send_manifest_ready = 1
manifest = {
    "manifest_scope": "v25-outbound-send-manifest",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v21_dispatch_manifest_sha256": sha256(v21_dispatch_dir / "dispatch_manifest.json"),
    "v22_clean_machine_execution_manifest_sha256": sha256(v22_kit_dir / "clean_machine_execution_manifest.json"),
    "v24_handoff_manifest_sha256": sha256(v24_handoff_dir / "handoff_manifest.json"),
    "outbound_send_manifest_ready": outbound_send_manifest_ready,
    "receiver_ack_template_ready": 1,
    "return_options_ready": 1,
    "v18_verify_instructions_ready": 1,
    "outbound_file_rows": len(outbound_rows),
    "send_packet_ready": bool_int(v24_manifest.get("send_packet_ready", 0)),
    "independent_rerun_actual_ready": bool_int(v24_manifest.get("independent_rerun_actual_ready", 0)),
    "candidate_external_benchmark_result_ready": bool_int(v24_manifest.get("candidate_external_benchmark_result_ready", 0)),
    "closed_corpus_poc_actual_ready": bool_int(v24_manifest.get("closed_corpus_poc_actual_ready", 0)),
    "real_external_benchmark_verified": bool_int(v24_manifest.get("real_external_benchmark_verified", 0)),
    "real_release_package_ready": bool_int(v24_manifest.get("real_release_package_ready", 0)),
    "claim": "outbound send manifest ready; actual readiness requires returned external directories verified by v18",
}
(packet_dir / "outbound_send_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "outbound/OUTBOUND_FILE_MANIFEST.csv",
    "outbound/OUTBOUND_SHA256SUMS.txt",
    "outbound/SEND_INSTRUCTIONS.md",
    "receiver/RECEIVER_ACK_TEMPLATE.csv",
    "receiver/RETURN_OPTIONS.md",
    "verify/VERIFY_RETURN_WITH_V18.md",
    "source_manifests/v21_dispatch_manifest.json",
    "source_manifests/v22_clean_machine_execution_manifest.json",
    "source_manifests/v24_handoff_manifest.json",
    "source_manifests/v24_handoff_rows.csv",
    "outbound_send_manifest.json",
]
artifact_rows = []
for rel in artifact_rels:
    path = packet_dir / rel
    artifact_rows.append({"artifact": Path(rel).stem, "path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
with (packet_dir / "artifact_manifest.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["artifact", "path", "sha256", "bytes"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(artifact_rows)

summary_rows = [
    {
        "packet_id": packet_dir.name,
        "outbound_send_manifest_ready": outbound_send_manifest_ready,
        "receiver_ack_template_ready": 1,
        "return_options_ready": 1,
        "v18_verify_instructions_ready": 1,
        "outbound_file_rows": len(outbound_rows),
        "send_packet_ready": manifest["send_packet_ready"],
        "independent_rerun_actual_ready": manifest["independent_rerun_actual_ready"],
        "candidate_external_benchmark_result_ready": manifest["candidate_external_benchmark_result_ready"],
        "closed_corpus_poc_actual_ready": manifest["closed_corpus_poc_actual_ready"],
        "real_external_benchmark_verified": manifest["real_external_benchmark_verified"],
        "real_release_package_ready": manifest["real_release_package_ready"],
        "artifact_rows": len(artifact_rows),
    }
]
with summary_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(summary_rows[0]), lineterminator="\n")
    writer.writeheader()
    writer.writerows(summary_rows)

decision_rows = [
    ("outbound-send-manifest", "pass", "v21 and v22 outbound files are hash-manifested for sending"),
    ("receiver-ack-template", "pass", "receiver acknowledgement template is packaged"),
    ("return-verification-instructions", "pass", "direct v18 return verification instructions are packaged"),
    ("third-party-rerun-return", "blocked", "requires returned third-party rerun directory"),
    ("official-benchmark-return", "blocked", "requires returned official benchmark directory"),
    ("commercial-closed-corpus-poc-return", "blocked", "requires returned commercial PoC directory"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "v25_outbound_send_manifest_dir: $PACKET_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
