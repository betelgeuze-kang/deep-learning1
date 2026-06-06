#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v38_human_review_dispatch_bundle"
BUNDLE_ID="${V38_BUNDLE_ID:-bundle_001}"
BUNDLE_DIR="${V38_BUNDLE_DIR:-$RESULTS_DIR/${PREFIX}/$BUNDLE_ID}"
DEFAULT_V36_PACKET_DIR="$RESULTS_DIR/v36_release_claim_audit_packet/packet_001"
DEFAULT_V37_INTAKE_DIR="$RESULTS_DIR/v37_human_review_intake/intake_001"
V36_PACKET_DIR="${V38_V36_PACKET_DIR:-$DEFAULT_V36_PACKET_DIR}"
V37_INTAKE_DIR="${V38_V37_INTAKE_DIR:-$DEFAULT_V37_INTAKE_DIR}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [ ! -f "$V37_INTAKE_DIR/human_review_intake_manifest.json" ]; then
  "$ROOT_DIR/experiments/run_v37_human_review_intake.sh" >/dev/null
fi

mkdir -p "$BUNDLE_DIR"

python3 - "$ROOT_DIR" "$BUNDLE_DIR" "$V36_PACKET_DIR" "$V37_INTAKE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
bundle_dir = Path(sys.argv[2])
v36_packet_dir = Path(sys.argv[3])
v37_intake_dir = Path(sys.argv[4])
summary_csv = Path(sys.argv[5])
decision_csv = Path(sys.argv[6])

if bundle_dir.exists():
    shutil.rmtree(bundle_dir)
bundle_dir.mkdir(parents=True)
review_packet = bundle_dir / "review_packet"
return_dir = bundle_dir / "return"
verify_dir = bundle_dir / "verify"
for folder in [review_packet, return_dir, verify_dir]:
    folder.mkdir(parents=True, exist_ok=True)

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

def rel(path):
    return str(path.relative_to(root))

def copy_file(src, dst):
    if not src.is_file():
        raise SystemExit(f"missing required source file: {src}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst

required_sources = {
    "HUMAN_REVIEW_REQUEST.md": v36_packet_dir / "human_review" / "HUMAN_REVIEW_REQUEST.md",
    "human_review_template.csv": v36_packet_dir / "human_review" / "human_review_template.csv",
    "RELEASE_CLAIM_AUDIT.md": v36_packet_dir / "RELEASE_CLAIM_AUDIT.md",
    "claim_matrix.csv": v36_packet_dir / "claim_matrix.csv",
    "release_decision_rows.csv": v36_packet_dir / "release_decision_rows.csv",
    "evidence_input_rows.csv": v36_packet_dir / "evidence_input_rows.csv",
    "v36_release_claim_audit_manifest.json": v36_packet_dir / "v36_release_claim_audit_manifest.json",
    "v37_human_review_intake_manifest.json": v37_intake_dir / "human_review_intake_manifest.json",
    "v37_missing_review_rows.csv": v37_intake_dir / "missing_review_rows.csv",
}
for name, src in required_sources.items():
    copy_file(src, review_packet / name)

template_src = required_sources["human_review_template.csv"]
copy_file(template_src, return_dir / "human_review_rows.csv")

verify_script = verify_dir / "VERIFY_RETURN.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"',
            'RETURN_ROWS="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/return/human_review_rows.csv}"',
            'V37_HUMAN_REVIEW_ROWS="$RETURN_ROWS" "$ROOT_DIR/experiments/run_v37_human_review_intake.sh"',
            "",
        ]
    ),
    encoding="utf-8",
)
verify_script.chmod(0o755)

readme = bundle_dir / "HUMAN_REVIEW_DISPATCH_README.md"
readme.write_text(
    "\n".join(
        [
            "# v38 Human Review Dispatch Bundle",
            "",
            "Send `review_packet/` to the reviewer.",
            "",
            "Reviewer return:",
            "",
            "- Fill `return/human_review_rows.csv` using `review_packet/human_review_template.csv`.",
            "- Every required row must include `status`, `reason`, `reviewer`, and `review_timestamp_utc`.",
            "- Use `pass` to accept the current evidence set, or `requires-non-github-rerun` / `rerun-required` if a non-GitHub independent rerun is required.",
            "",
            "Local verification:",
            "",
            "```bash",
            "results/v38_human_review_dispatch_bundle/bundle_001/verify/VERIFY_RETURN.sh",
            "```",
            "",
            "This bundle does not set `human_review_completed=1`; only a returned review file accepted by v37 can do that.",
            "",
        ]
    ),
    encoding="utf-8",
)

v36_manifest = read_json(v36_packet_dir / "v36_release_claim_audit_manifest.json")
v37_manifest = read_json(v37_intake_dir / "human_review_intake_manifest.json")
v37_summary = read_csv_one(root / "results" / "v37_human_review_intake_summary.csv")
review_packet_files = sum(1 for path in review_packet.rglob("*") if path.is_file())
return_template_ready = int((return_dir / "human_review_rows.csv").is_file())
verify_script_ready = int(verify_script.is_file())
dispatch_ready = int(
    v36_manifest.get("human_review_request_ready") == 1
    and v37_manifest.get("v36_release_claim_audit_packet_ready") == 1
    and v37_summary.get("v37_human_review_intake_ready") == "1"
    and review_packet_files >= len(required_sources)
    and return_template_ready
    and verify_script_ready
)

dispatch_rows = [
    {"artifact": "review-request", "path": "review_packet/HUMAN_REVIEW_REQUEST.md", "purpose": "reviewer instructions"},
    {"artifact": "review-template", "path": "review_packet/human_review_template.csv", "purpose": "required return schema"},
    {"artifact": "release-audit", "path": "review_packet/RELEASE_CLAIM_AUDIT.md", "purpose": "bounded claim and blocked claims"},
    {"artifact": "claim-matrix", "path": "review_packet/claim_matrix.csv", "purpose": "claim status table"},
    {"artifact": "verify-return", "path": "verify/VERIFY_RETURN.sh", "purpose": "run v37 against returned review rows"},
]
write_csv(bundle_dir / "dispatch_rows.csv", ["artifact", "path", "purpose"], dispatch_rows)

manifest = {
    "manifest_scope": "v38-human-review-dispatch-bundle",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "bundle_id": bundle_dir.name,
    "v36_packet_dir": rel(v36_packet_dir),
    "v37_intake_dir": rel(v37_intake_dir),
    "review_packet_files": review_packet_files,
    "return_template_ready": return_template_ready,
    "verify_script_ready": verify_script_ready,
    "human_review_dispatch_bundle_ready": dispatch_ready,
    "human_review_completed": 0,
    "real_release_package_ready": 0,
}
write_json(bundle_dir / "human_review_dispatch_manifest.json", manifest)

sha_rows = []
for path in sorted(bundle_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(bundle_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(bundle_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary_rows = [
    {
        "bundle_id": bundle_dir.name,
        "v38_human_review_dispatch_bundle_ready": dispatch_ready,
        "review_packet_files": review_packet_files,
        "return_template_ready": return_template_ready,
        "verify_script_ready": verify_script_ready,
        "v37_human_review_intake_ready": v37_summary.get("v37_human_review_intake_ready", "0"),
        "human_review_completed": 0,
        "real_release_package_ready": 0,
        "artifact_rows": len(sha_rows),
    }
]
write_csv(summary_csv, list(summary_rows[0]), summary_rows)

def status(ok):
    return "pass" if ok else "blocked"

decision_rows = [
    {"gate": "v38-human-review-dispatch-bundle", "status": status(dispatch_ready), "reason": "review packet, return template, and verifier are ready" if dispatch_ready else "dispatch bundle incomplete"},
    {"gate": "review-packet", "status": status(review_packet_files >= len(required_sources)), "reason": f"{review_packet_files} review packet files"},
    {"gate": "return-template", "status": status(return_template_ready), "reason": "return/human_review_rows.csv template prepared"},
    {"gate": "verify-return-script", "status": status(verify_script_ready), "reason": "VERIFY_RETURN.sh prepared"},
    {"gate": "human-review", "status": "blocked", "reason": "dispatch is ready, but no returned human review has been accepted by v37"},
    {"gate": "real-release-package", "status": "blocked", "reason": "release remains blocked until returned human review and any requested rerun"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)
PY

echo "v38_human_review_dispatch_bundle_dir: $BUNDLE_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
