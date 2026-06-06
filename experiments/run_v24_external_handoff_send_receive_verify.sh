#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v24_external_handoff_send_receive_verify"
HANDOFF_ID="${V24_HANDOFF_ID:-handoff_001}"
HANDOFF_DIR="${V24_HANDOFF_DIR:-$RESULTS_DIR/${PREFIX}/$HANDOFF_ID}"
V21_DISPATCH_DIR="${V21_DISPATCH_DIR:-$RESULTS_DIR/v21_external_review_dispatch_kit/dispatch_001}"
V22_KIT_DIR="${V22_KIT_DIR:-$RESULTS_DIR/v22_clean_machine_execution_kit/kit_001}"
V18_INTAKE_DIR="${V18_INTAKE_DIR:-$RESULTS_DIR/v18_external_evidence_intake/intake_001}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

mkdir -p "$HANDOFF_DIR"

"$ROOT_DIR/experiments/run_v22_clean_machine_execution_kit.sh" >/dev/null
"$ROOT_DIR/experiments/run_v18_external_evidence_intake.sh" >/dev/null

python3 - "$ROOT_DIR" "$HANDOFF_DIR" "$V21_DISPATCH_DIR" "$V22_KIT_DIR" "$V18_INTAKE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
handoff_dir = Path(sys.argv[2])
v21_dispatch_dir = Path(sys.argv[3])
v22_kit_dir = Path(sys.argv[4])
v18_intake_dir = Path(sys.argv[5])
summary_csv = Path(sys.argv[6])
decision_csv = Path(sys.argv[7])
handoff_dir.mkdir(parents=True, exist_ok=True)

def ensure(path):
    path.mkdir(parents=True, exist_ok=True)
    return path

for folder in ["send", "receive", "verify", "source_manifests"]:
    ensure(handoff_dir / folder)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def copy(src, rel):
    dst = handoff_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst

def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

def bool_int(value):
    return int(str(value).strip().lower() in {"1", "true", "yes", "ready", "pass"})

v21_manifest = read_json(v21_dispatch_dir / "dispatch_manifest.json")
v22_manifest = read_json(v22_kit_dir / "clean_machine_execution_manifest.json")
v18_manifest = read_json(v18_intake_dir / "intake_manifest.json")

copy(v21_dispatch_dir / "dispatch_manifest.json", "source_manifests/v21_dispatch_manifest.json")
copy(v22_kit_dir / "clean_machine_execution_manifest.json", "source_manifests/v22_clean_machine_execution_manifest.json")
copy(v18_intake_dir / "intake_manifest.json", "source_manifests/v18_intake_manifest.json")
copy(v18_intake_dir / "track_intake_rows.csv", "source_manifests/v18_track_intake_rows.csv")

handoff_rows = [
    {
        "track": "third_party_rerun",
        "send_path": "results/v21_external_review_dispatch_kit/dispatch_001 + results/v22_clean_machine_execution_kit/kit_001",
        "return_env": "V18_THIRD_PARTY_RERUN_DIR",
        "target_flag": "independent_rerun_actual_ready",
        "current_value": bool_int(v18_manifest.get("independent_rerun_actual_ready", 0)),
        "return_directory_kind": "third-party rerun return directory",
        "verify_command": "V18_THIRD_PARTY_RERUN_DIR=/path/to/third_party_return experiments/run_v18_external_evidence_intake.sh",
    },
    {
        "track": "official_benchmark_reconciliation",
        "send_path": "results/v21_external_review_dispatch_kit/dispatch_001",
        "return_env": "V18_OFFICIAL_BENCHMARK_DIR",
        "target_flag": "candidate_external_benchmark_result_ready",
        "current_value": bool_int(v18_manifest.get("candidate_external_benchmark_result_ready", 0)),
        "return_directory_kind": "official benchmark return directory",
        "verify_command": "V18_OFFICIAL_BENCHMARK_DIR=/path/to/official_return experiments/run_v18_external_evidence_intake.sh",
    },
    {
        "track": "commercial_closed_corpus_poc",
        "send_path": "results/v21_external_review_dispatch_kit/dispatch_001",
        "return_env": "V18_COMMERCIAL_POC_DIR",
        "target_flag": "closed_corpus_poc_actual_ready",
        "current_value": bool_int(v18_manifest.get("closed_corpus_poc_actual_ready", 0)),
        "return_directory_kind": "commercial closed-corpus PoC return directory",
        "verify_command": "V18_COMMERCIAL_POC_DIR=/path/to/commercial_return experiments/run_v18_external_evidence_intake.sh",
    },
]
with (handoff_dir / "handoff_rows.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(handoff_rows[0]), lineterminator="\n")
    writer.writeheader()
    writer.writerows(handoff_rows)

(handoff_dir / "send" / "SEND_PACKET.md").write_text(
    "\n".join(
        [
            "# Send Packet",
            "",
            "Send these two prepared packets outward:",
            "",
            "1. `results/v21_external_review_dispatch_kit/dispatch_001/`",
            "2. `results/v22_clean_machine_execution_kit/kit_001/`",
            "",
            "Use v21 for reviewer-facing requests, return directory layout, and per-track instructions.",
            "Use v22 for host/container clean-machine execution support and return templates.",
            "",
            "The project still does not claim external validation until one of the return directories is received and verified by v18.",
            "",
        ]
    ),
    encoding="utf-8",
)

(handoff_dir / "receive" / "RETURN_INBOX.md").write_text(
    "\n".join(
        [
            "# Return Inbox",
            "",
            "Expected inbound options:",
            "",
            "- `third_party_return/`: reviewer identity, clean-machine environment, exact command, frozen query/source snapshot verification, metric deltas, stdout/stderr hashes, rerun manifest.",
            "- `official_return/`: official source snapshot, official evaluator/container, raw predictions, metrics, provenance, reproducibility package, RouteMemory prediction lineage.",
            "- `commercial_return/`: codebase QA / internal docs QA / product manual QA / incident-log QA closed-corpus PoC with privacy/reliability review.",
            "",
            "A single returned directory can move one track; all three are not required at the same time.",
            "",
        ]
    ),
    encoding="utf-8",
)

(handoff_dir / "verify" / "VERIFY_WITH_V18.md").write_text(
    "\n".join(
        [
            "# Verify With v18",
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
            "Combined verification:",
            "",
            "```bash",
            "V18_THIRD_PARTY_RERUN_DIR=/path/to/third_party_return \\",
            "V18_OFFICIAL_BENCHMARK_DIR=/path/to/official_return \\",
            "V18_COMMERCIAL_POC_DIR=/path/to/commercial_return \\",
            "experiments/run_v18_external_evidence_intake.sh",
            "```",
            "",
            "Inspect `results/v18_external_evidence_intake_summary.csv` and `results/v18_external_evidence_intake/intake_001/intake_manifest.json` after verification.",
            "",
        ]
    ),
    encoding="utf-8",
)

verify_script = handoff_dir / "verify" / "VERIFY_ANY_RETURN_WITH_V18.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"',
            'cd "$ROOT_DIR"',
            ': "${V18_THIRD_PARTY_RERUN_DIR:=}"',
            ': "${V18_OFFICIAL_BENCHMARK_DIR:=}"',
            ': "${V18_COMMERCIAL_POC_DIR:=}"',
            "experiments/run_v18_external_evidence_intake.sh",
            "cat results/v18_external_evidence_intake_summary.csv",
            "cat results/v18_external_evidence_intake_decision.csv",
            "",
        ]
    ),
    encoding="utf-8",
)
verify_script.chmod(0o755)

(handoff_dir / "CURRENT_BLOCKERS.md").write_text(
    "\n".join(
        [
            "# Current Blockers",
            "",
            "- `independent_rerun_actual_ready=0`: no third-party rerun return directory supplied.",
            "- `candidate_external_benchmark_result_ready=0`: no official benchmark return directory supplied.",
            "- `closed_corpus_poc_actual_ready=0`: no commercial closed-corpus PoC return directory supplied.",
            "",
            "The next real action is external: send v21 + v22, receive at least one return directory, and verify it through v18.",
            "",
        ]
    ),
    encoding="utf-8",
)

handoff_ready = 1
manifest = {
    "manifest_scope": "v24-external-handoff-send-receive-verify",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v21_dispatch_manifest_sha256": sha256(v21_dispatch_dir / "dispatch_manifest.json"),
    "v22_clean_machine_execution_manifest_sha256": sha256(v22_kit_dir / "clean_machine_execution_manifest.json"),
    "v18_intake_manifest_sha256": sha256(v18_intake_dir / "intake_manifest.json"),
    "handoff_ready": handoff_ready,
    "send_packet_ready": bool_int(v21_manifest.get("dispatch_packet_ready", 0)) and bool_int(v22_manifest.get("clean_machine_execution_kit_ready", 0)),
    "return_inbox_ready": 1,
    "v18_verification_commands_ready": 1,
    "handoff_rows": len(handoff_rows),
    "independent_rerun_actual_ready": bool_int(v18_manifest.get("independent_rerun_actual_ready", 0)),
    "candidate_external_benchmark_result_ready": bool_int(v18_manifest.get("candidate_external_benchmark_result_ready", 0)),
    "closed_corpus_poc_actual_ready": bool_int(v18_manifest.get("closed_corpus_poc_actual_ready", 0)),
    "real_external_benchmark_verified": bool_int(v18_manifest.get("real_external_benchmark_verified", 0)),
    "real_release_package_ready": bool_int(v18_manifest.get("real_release_package_ready", 0)),
    "claim": "send/receive/verify handoff ready; actual readiness requires returned external directories verified by v18",
}
(handoff_dir / "handoff_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "send/SEND_PACKET.md",
    "receive/RETURN_INBOX.md",
    "verify/VERIFY_WITH_V18.md",
    "verify/VERIFY_ANY_RETURN_WITH_V18.sh",
    "CURRENT_BLOCKERS.md",
    "handoff_rows.csv",
    "source_manifests/v21_dispatch_manifest.json",
    "source_manifests/v22_clean_machine_execution_manifest.json",
    "source_manifests/v18_intake_manifest.json",
    "source_manifests/v18_track_intake_rows.csv",
    "handoff_manifest.json",
]
artifact_rows = []
for rel in artifact_rels:
    path = handoff_dir / rel
    artifact_rows.append({"artifact": Path(rel).stem, "path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
with (handoff_dir / "artifact_manifest.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["artifact", "path", "sha256", "bytes"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(artifact_rows)

summary_rows = [
    {
        "handoff_id": handoff_dir.name,
        "handoff_ready": handoff_ready,
        "send_packet_ready": manifest["send_packet_ready"],
        "return_inbox_ready": 1,
        "v18_verification_commands_ready": 1,
        "handoff_rows": len(handoff_rows),
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
    ("send-receive-verify-handoff", "pass", "v21 and v22 send packet plus v18 return verification commands are packaged"),
    ("third-party-rerun-return", "blocked", "requires returned third-party rerun directory"),
    ("official-benchmark-return", "blocked", "requires returned official benchmark directory"),
    ("commercial-closed-corpus-poc-return", "blocked", "requires returned commercial PoC directory"),
    ("real-release-package", "blocked", "handoff is not returned external evidence"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "v24_external_handoff_dir: $HANDOFF_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
