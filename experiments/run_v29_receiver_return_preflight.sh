#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v29_receiver_return_preflight"
PREFLIGHT_ID="${V29_PREFLIGHT_ID:-preflight_001}"
PREFLIGHT_DIR="${V29_PREFLIGHT_DIR:-$RESULTS_DIR/${PREFIX}/$PREFLIGHT_ID}"
V28_INBOX_DIR="${V28_INBOX_DIR:-$RESULTS_DIR/v28_inbound_return_inbox/inbox_001}"
THIRD_PARTY_DIR="${V29_THIRD_PARTY_RETURN_DIR:-$V28_INBOX_DIR/returns/third_party_return}"
OFFICIAL_DIR="${V29_OFFICIAL_RETURN_DIR:-$V28_INBOX_DIR/returns/official_return}"
COMMERCIAL_DIR="${V29_COMMERCIAL_RETURN_DIR:-$V28_INBOX_DIR/returns/commercial_return}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

mkdir -p "$PREFLIGHT_DIR"

"$ROOT_DIR/experiments/run_v28_inbound_return_inbox.sh" >/dev/null

python3 - "$ROOT_DIR" "$PREFLIGHT_DIR" "$V28_INBOX_DIR" "$THIRD_PARTY_DIR" "$OFFICIAL_DIR" "$COMMERCIAL_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
preflight_dir = Path(sys.argv[2])
v28_inbox_dir = Path(sys.argv[3])
third_party_dir = Path(sys.argv[4])
official_dir = Path(sys.argv[5])
commercial_dir = Path(sys.argv[6])
summary_csv = Path(sys.argv[7])
decision_csv = Path(sys.argv[8])
preflight_dir.mkdir(parents=True, exist_ok=True)

def ensure(path):
    path.mkdir(parents=True, exist_ok=True)
    return path

for folder in ["receiver", "verify", "source_manifests"]:
    ensure(preflight_dir / folder)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def copy(src, rel):
    dst = preflight_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(src.read_bytes())
    return dst

def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

v28_manifest = read_json(v28_inbox_dir / "inbound_return_inbox_manifest.json")
copy(v28_inbox_dir / "inbound_return_inbox_manifest.json", "source_manifests/v28_inbound_return_inbox_manifest.json")
copy(v28_inbox_dir / "inbox_rows.csv", "source_manifests/v28_inbox_rows.csv")

track_specs = [
    {
        "track": "third_party_rerun",
        "path": third_party_dir,
        "v18_env": "V18_THIRD_PARTY_RERUN_DIR",
        "target_flag": "independent_rerun_actual_ready",
        "required": [
            "reviewer_identity.json",
            "rerun_environment.json",
            "rerun_commands.csv",
            "rerun_manifest.json",
            "metric_delta_rows.csv",
            "review_rows.csv",
            "stdout.txt",
            "stderr.txt",
        ],
    },
    {
        "track": "official_benchmark_reconciliation",
        "path": official_dir,
        "v18_env": "V18_OFFICIAL_BENCHMARK_DIR",
        "target_flag": "candidate_external_benchmark_result_ready",
        "required": [
            "official_source_snapshot.json",
            "official_evaluator_status.json",
            "raw_predictions.jsonl",
            "prediction_lineage.jsonl",
            "metrics.json",
            "provenance_manifest.json",
            "reproducibility_package_manifest.json",
            "candidate_result_rows.csv",
        ],
    },
    {
        "track": "commercial_closed_corpus_poc",
        "path": commercial_dir,
        "v18_env": "V18_COMMERCIAL_POC_DIR",
        "target_flag": "closed_corpus_poc_actual_ready",
        "required": [
            "domain_manifest.json",
            "corpus_manifest.json",
            "query_set.csv",
            "poc_result_rows.csv",
            "audit_trail.csv",
            "resource_envelope.json",
            "privacy_review.json",
            "acceptance_review.csv",
        ],
    },
]

preflight_rows = []
missing_rows = []
for spec in track_specs:
    directory = Path(spec["path"])
    present = [rel for rel in spec["required"] if (directory / rel).is_file()]
    missing = [rel for rel in spec["required"] if rel not in present]
    complete = int(len(missing) == 0)
    any_present = int(bool(present))
    verify_command = f"{spec['v18_env']}={directory} experiments/run_v18_external_evidence_intake.sh"
    preflight_rows.append(
        {
            "track": spec["track"],
            "return_dir": str(directory),
            "v18_env": spec["v18_env"],
            "target_flag": spec["target_flag"],
            "required_files": len(spec["required"]),
            "present_files": len(present),
            "missing_files": len(missing),
            "return_detected": any_present,
            "return_preflight_complete": complete,
            "verify_command": verify_command,
        }
    )
    for rel in missing:
        missing_rows.append({"track": spec["track"], "return_dir": str(directory), "missing_file": rel})

with (preflight_dir / "receiver" / "preflight_rows.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(
        handle,
        fieldnames=[
            "track",
            "return_dir",
            "v18_env",
            "target_flag",
            "required_files",
            "present_files",
            "missing_files",
            "return_detected",
            "return_preflight_complete",
            "verify_command",
        ],
        lineterminator="\n",
    )
    writer.writeheader()
    writer.writerows(preflight_rows)

with (preflight_dir / "receiver" / "missing_file_rows.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["track", "return_dir", "missing_file"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(missing_rows)

(preflight_dir / "receiver" / "RECEIVER_RETURN_PREFLIGHT.md").write_text(
    "\n".join(
        [
            "# Receiver Return Preflight",
            "",
            "Run this before sending a return directory back to the project owner.",
            "",
            "Default check uses the v28 inbox locations:",
            "",
            "- `results/v28_inbound_return_inbox/inbox_001/returns/third_party_return/`",
            "- `results/v28_inbound_return_inbox/inbox_001/returns/official_return/`",
            "- `results/v28_inbound_return_inbox/inbox_001/returns/commercial_return/`",
            "",
            "```bash",
            "experiments/run_v29_receiver_return_preflight.sh",
            "```",
            "",
            "Custom receiver-side directories:",
            "",
            "```bash",
            "V29_THIRD_PARTY_RETURN_DIR=/path/to/third_party_return \\",
            "V29_OFFICIAL_RETURN_DIR=/path/to/official_return \\",
            "V29_COMMERCIAL_RETURN_DIR=/path/to/commercial_return \\",
            "experiments/run_v29_receiver_return_preflight.sh",
            "```",
            "",
            "A complete preflight does not set readiness by itself. The returned directory must still pass v18 with `V18_THIRD_PARTY_RERUN_DIR`, `V18_OFFICIAL_BENCHMARK_DIR`, or `V18_COMMERCIAL_POC_DIR`.",
            "",
        ]
    ),
    encoding="utf-8",
)

(preflight_dir / "verify" / "VERIFY_AFTER_PREFLIGHT.md").write_text(
    "\n".join(
        [
            "# Verify After Preflight",
            "",
            "When one preflight row reports `return_preflight_complete=1`, verify it with v18:",
            "",
            "```bash",
            "V18_THIRD_PARTY_RERUN_DIR=/path/to/third_party_return experiments/run_v18_external_evidence_intake.sh",
            "V18_OFFICIAL_BENCHMARK_DIR=/path/to/official_return experiments/run_v18_external_evidence_intake.sh",
            "V18_COMMERCIAL_POC_DIR=/path/to/commercial_return experiments/run_v18_external_evidence_intake.sh",
            "```",
            "",
            "The expected target flags are `independent_rerun_actual_ready=1`, `candidate_external_benchmark_result_ready=1`, or `closed_corpus_poc_actual_ready=1`, depending on the returned track.",
            "",
        ]
    ),
    encoding="utf-8",
)

receiver_return_preflight_ready = 1
complete_return_dirs = sum(int(row["return_preflight_complete"]) for row in preflight_rows)
detected_return_dirs = sum(int(row["return_detected"]) for row in preflight_rows)
manifest = {
    "manifest_scope": "v29-receiver-return-preflight",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v28_inbound_return_inbox_manifest_sha256": sha256(v28_inbox_dir / "inbound_return_inbox_manifest.json"),
    "receiver_return_preflight_ready": receiver_return_preflight_ready,
    "preflight_tracks": len(preflight_rows),
    "return_dirs_detected": detected_return_dirs,
    "complete_return_dirs": complete_return_dirs,
    "missing_file_rows": len(missing_rows),
    "v18_verify_instructions_ready": 1,
    "independent_rerun_actual_ready": int(v28_manifest.get("independent_rerun_actual_ready", 0)),
    "candidate_external_benchmark_result_ready": int(v28_manifest.get("candidate_external_benchmark_result_ready", 0)),
    "closed_corpus_poc_actual_ready": int(v28_manifest.get("closed_corpus_poc_actual_ready", 0)),
    "real_external_benchmark_verified": int(v28_manifest.get("real_external_benchmark_verified", 0)),
    "real_release_package_ready": int(v28_manifest.get("real_release_package_ready", 0)),
    "claim": "receiver-side return preflight ready; actual readiness requires v18 verification of returned directories",
}
(preflight_dir / "receiver_return_preflight_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "receiver/RECEIVER_RETURN_PREFLIGHT.md",
    "receiver/preflight_rows.csv",
    "receiver/missing_file_rows.csv",
    "verify/VERIFY_AFTER_PREFLIGHT.md",
    "source_manifests/v28_inbound_return_inbox_manifest.json",
    "source_manifests/v28_inbox_rows.csv",
    "receiver_return_preflight_manifest.json",
]
artifact_rows = []
for rel in artifact_rels:
    path = preflight_dir / rel
    artifact_rows.append({"artifact": Path(rel).stem, "path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
with (preflight_dir / "artifact_manifest.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["artifact", "path", "sha256", "bytes"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(artifact_rows)

summary_rows = [
    {
        "preflight_id": preflight_dir.name,
        "receiver_return_preflight_ready": receiver_return_preflight_ready,
        "preflight_tracks": len(preflight_rows),
        "return_dirs_detected": detected_return_dirs,
        "complete_return_dirs": complete_return_dirs,
        "missing_file_rows": len(missing_rows),
        "v18_verify_instructions_ready": 1,
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
    ("receiver-return-preflight", "pass", "receiver-side return file preflight is packaged"),
    ("third-party-rerun-return-preflight", "pass" if preflight_rows[0]["return_preflight_complete"] == 1 else "blocked", "requires all third-party return files"),
    ("official-benchmark-return-preflight", "pass" if preflight_rows[1]["return_preflight_complete"] == 1 else "blocked", "requires all official benchmark return files"),
    ("commercial-poc-return-preflight", "pass" if preflight_rows[2]["return_preflight_complete"] == 1 else "blocked", "requires all commercial PoC return files"),
    ("v18-actual-readiness", "blocked", "preflight is not v18 verification"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "v29_receiver_return_preflight_dir: $PREFLIGHT_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
