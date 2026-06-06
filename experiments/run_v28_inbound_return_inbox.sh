#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v28_inbound_return_inbox"
INBOX_ID="${V28_INBOX_ID:-inbox_001}"
INBOX_DIR="${V28_INBOX_DIR:-$RESULTS_DIR/${PREFIX}/$INBOX_ID}"
V27_ARCHIVE_DIR="${V27_ARCHIVE_DIR:-$RESULTS_DIR/v27_external_send_archive/archive_001}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

mkdir -p "$INBOX_DIR"

"$ROOT_DIR/experiments/run_v27_external_send_archive.sh" >/dev/null

python3 - "$ROOT_DIR" "$INBOX_DIR" "$V27_ARCHIVE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
inbox_dir = Path(sys.argv[2])
v27_archive_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
inbox_dir.mkdir(parents=True, exist_ok=True)

def ensure(path):
    path.mkdir(parents=True, exist_ok=True)
    return path

for folder in ["returns/third_party_return", "returns/official_return", "returns/commercial_return", "verify", "source_manifests"]:
    ensure(inbox_dir / folder)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def copy(src, rel):
    dst = inbox_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(src.read_bytes())
    return dst

def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

def bool_int(value):
    return int(str(value).strip().lower() in {"1", "true", "yes", "ready", "pass"})

v27_manifest = read_json(v27_archive_dir / "send_archive_manifest.json")
copy(v27_archive_dir / "send_archive_manifest.json", "source_manifests/v27_send_archive_manifest.json")
copy(v27_archive_dir / "archive" / "ARCHIVE_SHA256SUMS.txt", "source_manifests/v27_archive_sha256sums.txt")

track_specs = [
    {
        "track": "third_party_rerun",
        "inbox_rel": "returns/third_party_return",
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
        "inbox_rel": "returns/official_return",
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
        "inbox_rel": "returns/commercial_return",
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

inbox_rows = []
v18_env = {}
for spec in track_specs:
    path = inbox_dir / spec["inbox_rel"]
    present = [rel for rel in spec["required"] if (path / rel).is_file()]
    missing = [rel for rel in spec["required"] if rel not in present]
    any_present = int(bool(present))
    complete = int(len(missing) == 0)
    if any_present:
        v18_env[spec["v18_env"]] = str(path)
    inbox_rows.append(
        {
            "track": spec["track"],
            "inbox_path": str(path.relative_to(root)),
            "v18_env": spec["v18_env"],
            "target_flag": spec["target_flag"],
            "required_files": len(spec["required"]),
            "present_files": len(present),
            "missing_files": "|".join(missing),
            "return_detected": any_present,
            "return_complete": complete,
            "passed_to_v18": any_present,
        }
    )

with (inbox_dir / "inbox_rows.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(
        handle,
        fieldnames=[
            "track",
            "inbox_path",
            "v18_env",
            "target_flag",
            "required_files",
            "present_files",
            "missing_files",
            "return_detected",
            "return_complete",
            "passed_to_v18",
        ],
        lineterminator="\n",
    )
    writer.writeheader()
    writer.writerows(inbox_rows)

(inbox_dir / "INBOUND_RETURN_INBOX.md").write_text(
    "\n".join(
        [
            "# v28 Inbound Return Inbox",
            "",
            "Place returned external evidence directories here:",
            "",
            "- `returns/third_party_return/`",
            "- `returns/official_return/`",
            "- `returns/commercial_return/`",
            "",
            "The verifier only passes a directory to v18 when at least one required return file is present. Empty placeholder directories are not treated as supplied evidence.",
            "",
            "Run:",
            "",
            "```bash",
            "experiments/run_v28_inbound_return_inbox.sh",
            "```",
            "",
            "Direct v18 env mapping:",
            "- `V18_THIRD_PARTY_RERUN_DIR=results/v28_inbound_return_inbox/inbox_001/returns/third_party_return`",
            "- `V18_OFFICIAL_BENCHMARK_DIR=results/v28_inbound_return_inbox/inbox_001/returns/official_return`",
            "- `V18_COMMERCIAL_POC_DIR=results/v28_inbound_return_inbox/inbox_001/returns/commercial_return`",
            "",
        ]
    ),
    encoding="utf-8",
)

verify_script = inbox_dir / "verify" / "VERIFY_INBOX_WITH_V18.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"',
            'cd "$ROOT_DIR"',
            "experiments/run_v28_inbound_return_inbox.sh",
            "cat results/v28_inbound_return_inbox_summary.csv",
            "cat results/v18_external_evidence_intake_summary.csv",
            "",
        ]
    ),
    encoding="utf-8",
)
verify_script.chmod(0o755)

subprocess.run(
    [
        str(root / "experiments" / "run_v18_external_evidence_intake.sh"),
    ],
    check=True,
    env={**os.environ, **v18_env},
    cwd=root,
)

v18_summary_path = root / "results" / "v18_external_evidence_intake_summary.csv"
v18_rows = list(csv.DictReader(v18_summary_path.open(newline="", encoding="utf-8")))
v18_summary = v18_rows[0] if v18_rows else {}
copy(root / "results" / "v18_external_evidence_intake" / "intake_001" / "intake_manifest.json", "source_manifests/v18_latest_intake_manifest.json")
copy(v18_summary_path, "source_manifests/v18_latest_summary.csv")

return_dirs_detected = sum(int(row["return_detected"]) for row in inbox_rows)
complete_return_dirs = sum(int(row["return_complete"]) for row in inbox_rows)
inbound_return_inbox_ready = 1
manifest = {
    "manifest_scope": "v28-inbound-return-inbox",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v27_send_archive_manifest_sha256": sha256(v27_archive_dir / "send_archive_manifest.json"),
    "inbound_return_inbox_ready": inbound_return_inbox_ready,
    "return_dirs_detected": return_dirs_detected,
    "complete_return_dirs": complete_return_dirs,
    "v18_intake_invoked": 1,
    "v18_env_dirs_passed": len(v18_env),
    "independent_rerun_actual_ready": bool_int(v18_summary.get("independent_rerun_actual_ready", 0)),
    "candidate_external_benchmark_result_ready": bool_int(v18_summary.get("candidate_external_benchmark_result_ready", 0)),
    "closed_corpus_poc_actual_ready": bool_int(v18_summary.get("closed_corpus_poc_actual_ready", 0)),
    "real_external_benchmark_verified": bool_int(v18_summary.get("real_external_benchmark_verified", 0)),
    "real_release_package_ready": bool_int(v18_summary.get("real_release_package_ready", 0)),
    "claim": "inbound return inbox ready; actual readiness requires returned files verified by v18",
}
(inbox_dir / "inbound_return_inbox_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "INBOUND_RETURN_INBOX.md",
    "inbox_rows.csv",
    "verify/VERIFY_INBOX_WITH_V18.sh",
    "source_manifests/v27_send_archive_manifest.json",
    "source_manifests/v27_archive_sha256sums.txt",
    "source_manifests/v18_latest_intake_manifest.json",
    "source_manifests/v18_latest_summary.csv",
    "inbound_return_inbox_manifest.json",
]
artifact_rows = []
for rel in artifact_rels:
    path = inbox_dir / rel
    artifact_rows.append({"artifact": Path(rel).stem, "path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
with (inbox_dir / "artifact_manifest.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["artifact", "path", "sha256", "bytes"], lineterminator="\n")
    writer.writeheader()
    writer.writerows(artifact_rows)

summary_rows = [
    {
        "inbox_id": inbox_dir.name,
        "inbound_return_inbox_ready": inbound_return_inbox_ready,
        "return_dirs_detected": return_dirs_detected,
        "complete_return_dirs": complete_return_dirs,
        "v18_intake_invoked": 1,
        "v18_env_dirs_passed": len(v18_env),
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
    ("inbound-return-inbox", "pass", "standard return inbox paths and v18 verifier hook are packaged"),
    ("third-party-rerun-return", "pass" if bool_int(v18_summary.get("independent_rerun_actual_ready", 0)) else "blocked", "requires complete third-party return directory"),
    ("official-benchmark-return", "pass" if bool_int(v18_summary.get("candidate_external_benchmark_result_ready", 0)) else "blocked", "requires complete official benchmark return directory"),
    ("commercial-closed-corpus-poc-return", "pass" if bool_int(v18_summary.get("closed_corpus_poc_actual_ready", 0)) else "blocked", "requires complete commercial PoC return directory"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "v28_inbound_return_inbox_dir: $INBOX_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
